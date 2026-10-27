import { create } from 'zustand';
import type { Production, UsedProduct, Category } from '@/types';
import { db, rpc } from '@/lib/db';
import { save } from '@/lib/persist';
import { useStockStore } from './stockStore';
import { useComptoirStore } from './comptoirStore';
import { stable } from '@/lib/stable';

export interface AddProductionInput {
  name: string;
  description: string;
  date: string;
  hour: string;
  categoryId?: string;
  categoryName?: string;
  /** Fiche technique produite : la quantité rejoint son stock prêt. */
  ficheTechnicId?: string;
  usedProducts: UsedProduct[];
  outputQuantity: number;
  unitPrice: number;
  sellByUnit?: boolean;
  sellUnit?: string;
  hasLoss?: boolean;
  expectedQuantity?: number;
  lossQuantity?: number;
  lossDescription?: string;
  lossValue?: number;
  /** Boîte du stock dans laquelle le lot est conditionné (déduite du stock). */
  boxProductId?: string;
  boxQuantity?: number;
  /** Contenance de la boîte pour ce produit (mémorisée pour la prochaine fois). */
  boxCapacity?: number;
}

interface ProductionState {
  productions: Production[];
  categories: Category[];
  load: () => Promise<void>;
  addProduction: (data: AddProductionInput) => Promise<Production>;
  updateProduction: (id: string, data: Partial<Production>) => Promise<void>;
  /**
   * Modifie un lot existant : la nouvelle quantité redose ses matières
   * (l'écart est rendu au stock ou déduit), le reste est recopié tel quel.
   */
  rescaleProduction: (id: string, outputQuantity: number,
    data?: Partial<Pick<Production, 'description' | 'date' | 'hour' | 'unitPrice' | 'lossDescription'>>) => Promise<void>;
  /** Modification complète d'un lot (même saisie que la création) : ses matières sont remplacées. */
  editProduction: (id: string, data: AddProductionInput) => Promise<void>;
  deleteProduction: (id: string) => Promise<void>;
  transferToComptoir: (id: string, qty: number) => Promise<void>;
  addCategory: (name: string) => Promise<Category>;
  deleteCategory: (id: string) => Promise<void>;
}

export const useProductionStore = create<ProductionState>()(stable((set, get) => ({
  productions: [],
  categories: [],

  load: async () => {
    const [productions, categories] = await Promise.all([
      db.productions.list(), db.productionCategories.list(),
    ]);
    set({ productions, categories });
  },

  addProduction: async (data) => {
    const {
      name, description, date, hour, categoryId, categoryName, ficheTechnicId, usedProducts,
      outputQuantity, unitPrice, sellByUnit, sellUnit,
      hasLoss, expectedQuantity, lossQuantity, lossDescription, lossValue, boxProductId, boxQuantity, boxCapacity,
    } = data;

    // create_production() writes the batch, its ingredients and consumes the stock
    const row = await save('productions.create', () =>
      rpc.createProduction({
        name, description, date, hour,
        category_id: categoryId ?? null,
        category_name: categoryName ?? null,
        fiche_technic_id: ficheTechnicId ?? null,
        output_quantity: outputQuantity,
        unit_price: unitPrice,
        sell_by_unit: sellByUnit ?? false,
        sell_unit: sellUnit ?? null,
        has_loss: hasLoss ?? false,
        expected_quantity: expectedQuantity ?? null,
        loss_quantity: lossQuantity ?? 0,
        loss_description: lossDescription ?? null,
        loss_value: lossValue ?? 0,
        box_product_id: boxProductId || null,
        box_quantity: boxProductId ? boxQuantity ?? 0 : 0,
        box_capacity: boxProductId ? boxCapacity ?? null : null,
        used_products: usedProducts.map((u) => ({
          product_id: u.productId,
          product_name: u.productName,
          quantity_used: u.quantityUsed,
          source_type: u.sourceType ?? 'stock',
          unit: u.unit ?? null,
          unit_cost: u.unitCost ?? 0,
          line_cost: u.lineCost ?? 0,
        })),
      })
    );

    // ingredients left the stock → both screens reload from the database
    const [productions] = await Promise.all([db.productions.list(), useStockStore.getState().load()]);
    set({ productions });
    return productions.find((p) => p.id === row.id) as Production;
  },

  updateProduction: async (id, data) => {
    await save('productions.update', () =>
      db.productions.update(id, {
        name: data.name,
        description: data.description,
        date: data.date,
        hour: data.hour,
        output_quantity: data.outputQuantity,
        unit_price: data.unitPrice,
        total_value:
          (data.outputQuantity ?? 0) * (data.unitPrice ?? 0) || undefined,
        sell_by_unit: data.sellByUnit,
        sell_unit: data.sellUnit ?? null,
      })
    );
    set({ productions: await db.productions.list() });
  },

  rescaleProduction: async (id, outputQuantity, data = {}) => {
    const prod = get().productions.find((p) => p.id === id);
    if (!prod) return;
    if (outputQuantity <= 0) throw new Error('La quantité doit être supérieure à 0');
    if (outputQuantity < (prod.sentToComptoir ?? 0)) {
      throw new Error(`Déjà ${prod.sentToComptoir} envoyé(s) au comptoir : la quantité ne peut pas descendre en dessous`);
    }
    const factor = prod.outputQuantity > 0 ? outputQuantity / prod.outputQuantity : 1;
    const materials = prod.usedProducts.filter((u) => !u.isBox);
    const box = prod.usedProducts.filter((u) => u.isBox);
    const lines = materials.map((u) => {
      const quantity = Number((u.quantityUsed * factor).toFixed(4));
      return {
        product_id: u.productId || null,
        product_name: u.productName,
        quantity_used: quantity,
        source_type: u.sourceType ?? 'stock',
        unit: u.unit ?? null,
        unit_cost: u.unitCost ?? 0,
        line_cost: Number((quantity * (u.unitCost ?? 0)).toFixed(2)),
      };
    });

    // ce qui sort en plus du stock doit y être
    const stock = useStockStore.getState().products;
    lines.forEach((l, i) => {
      const extra = l.quantity_used - materials[i].quantityUsed;
      if (l.source_type !== 'stock' || !l.product_id || extra <= 0) return;
      const p = stock.find((x) => x.id === l.product_id);
      if (p && extra > p.currentQuantity + 0.0005) {
        throw new Error(`Stock insuffisant pour « ${p.name} » : ${p.currentQuantity} disponible(s), ${Number(extra.toFixed(4))} requis`);
      }
    });

    const unitPrice = data.unitPrice ?? prod.unitPrice;
    const totalCost = lines.reduce((s, l) => s + l.line_cost, 0) + box.reduce((s, u) => s + (u.lineCost ?? 0), 0);
    await save('productions.rescale', async () => {
      if (factor !== 1) await db.productions.replaceUsedProducts(id, lines);
      await db.productions.update(id, {
        description: data.description ?? prod.description,
        date: data.date ?? prod.date,
        hour: data.hour ?? prod.hour,
        output_quantity: outputQuantity,
        unit_price: unitPrice,
        total_value: Number((outputQuantity * unitPrice).toFixed(2)),
        total_cost: Number(totalCost.toFixed(2)),
        ...(prod.hasLoss ? {
          expected_quantity: prod.expectedQuantity != null ? Number((prod.expectedQuantity * factor).toFixed(4)) : null,
          loss_quantity: Number(((prod.lossQuantity ?? 0) * factor).toFixed(4)),
          loss_value: Number(((prod.lossValue ?? 0) * factor).toFixed(2)),
          loss_description: data.lossDescription ?? prod.lossDescription ?? null,
        } : {}),
      });
    });
    const [productions] = await Promise.all([db.productions.list(), useStockStore.getState().load()]);
    set({ productions });
  },

  editProduction: async (id, data) => {
    const prod = get().productions.find((p) => p.id === id);
    if (!prod) return;
    if (data.outputQuantity < (prod.sentToComptoir ?? 0)) {
      throw new Error(`Déjà ${prod.sentToComptoir} envoyé(s) au comptoir : la quantité ne peut pas descendre en dessous`);
    }
    const lines = data.usedProducts.map((u) => ({
      product_id: u.productId || null,
      product_name: u.productName,
      quantity_used: u.quantityUsed,
      source_type: u.sourceType ?? 'stock',
      unit: u.unit ?? null,
      unit_cost: u.unitCost ?? 0,
      line_cost: u.lineCost ?? 0,
    }));
    const boxCost = prod.usedProducts.filter((u) => u.isBox).reduce((s, u) => s + (u.lineCost ?? 0), 0);
    const totalCost = lines.reduce((s, l) => s + l.line_cost, 0) + boxCost;
    await save('productions.edit', async () => {
      await db.productions.replaceUsedProducts(id, lines);
      await db.productions.update(id, {
        name: data.name,
        description: data.description,
        date: data.date,
        hour: data.hour,
        fiche_technic_id: data.ficheTechnicId ?? null,
        category_id: data.categoryId ?? null,
        category_name: data.categoryName ?? null,
        output_quantity: data.outputQuantity,
        unit_price: data.unitPrice,
        total_value: Number((data.outputQuantity * data.unitPrice).toFixed(2)),
        total_cost: Number(totalCost.toFixed(2)),
        sell_by_unit: data.sellByUnit ?? false,
        sell_unit: data.sellUnit ?? null,
        has_loss: data.hasLoss ?? false,
        expected_quantity: data.expectedQuantity ?? null,
        loss_quantity: data.lossQuantity ?? 0,
        loss_description: data.lossDescription ?? null,
        loss_value: data.lossValue ?? 0,
      });
    });
    const [productions] = await Promise.all([db.productions.list(), useStockStore.getState().load()]);
    set({ productions });
  },

  deleteProduction: async (id) => {
    await save('productions.delete', () => db.productions.remove(id));
    set({ productions: get().productions.filter((p) => p.id !== id) });
  },

  transferToComptoir: async (id, qty) => {
    const prod = get().productions.find((p) => p.id === id);
    if (!prod) return;
    if ((prod.sentToComptoir ?? 0) + qty > prod.outputQuantity) {
      throw new Error('La quantité dépasse le reste en stock de production');
    }
    await save('productions.transferToComptoir', () => rpc.transferToComptoir(id, qty));
    const [productions] = await Promise.all([
      db.productions.list(), useComptoirStore.getState().load(),
    ]);
    set({ productions });
  },

  addCategory: async (name) => {
    const existing = get().categories.find((c) => c.name.toLowerCase() === name.toLowerCase());
    if (existing) return existing;
    const row = await save('productionCategories.create', () => db.productionCategories.create(name));
    set({ categories: [...get().categories, row] });
    return row;
  },

  deleteCategory: async (id) => {
    await save('productionCategories.delete', () => db.productionCategories.remove(id));
    set({ categories: get().categories.filter((c) => c.id !== id) });
  },
})));
