import type { Purchase } from '@/types';

/** Total des frais payés à des tiers : douane + transitaire + supplémentaires. */
export const purchaseFeesTotal = (p: Purchase) =>
  (p.customsFees ?? 0) + (p.transitFees ?? 0) + (p.extraFeesTotal ?? 0);

/** Coût complet d'un achat : TTC fournisseur + tous les frais. */
export const purchaseGrandTotal = (p: Purchase) => p.totalAmount + purchaseFeesTotal(p);

export interface PurchaseFeesSummary {
  tva: number;
  customs: number;
  transit: number;
  extra: number;
  /** Frais supplémentaires additionnés par catégorie, du plus gros au plus petit. */
  byCategory: { name: string; amount: number; count: number }[];
  total: number;
}

/** Ventilation des TVA / frais d'une liste d'achats (caisse, rapports). */
export function summarizePurchaseFees(purchases: Purchase[]): PurchaseFeesSummary {
  const cats = new Map<string, { name: string; amount: number; count: number }>();
  let tva = 0, customs = 0, transit = 0, extra = 0;
  for (const p of purchases) {
    tva += p.tvaAmount ?? 0;
    customs += p.customsFees ?? 0;
    transit += p.transitFees ?? 0;
    for (const f of p.extraFees ?? []) {
      extra += f.amount;
      const key = f.categoryName.trim().toLowerCase();
      const c = cats.get(key) ?? { name: f.categoryName, amount: 0, count: 0 };
      c.amount += f.amount;
      c.count += 1;
      cats.set(key, c);
    }
  }
  return {
    tva, customs, transit, extra,
    byCategory: [...cats.values()].sort((a, b) => b.amount - a.amount),
    total: customs + transit + extra,
  };
}

export const hasPurchaseCosts = (p: Purchase) =>
  !!p.tvaEnabled || purchaseFeesTotal(p) > 0 || (p.euroAmount ?? 0) > 0;
