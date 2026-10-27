// ============================================================================
//  HISTORIQUE D'UN PRODUIT
// ----------------------------------------------------------------------------
//  Deux sortes de produits :
//   · produit de STOCK (matière première) — achats, retours, quantités
//     consommées (productions, bons de livraison) et ventes qui l'ont emporté
//     (point de vente, bons de livraison) ;
//   · produit de PRODUCTION (fiche technique) — lots produits, matières
//     consommées, ventes au point de vente, bons de livraison, récupérations.
//  Chaque partie a sa carte de totaux et son tableau ; l'impression laisse
//  choisir les parties à imprimer.
// ============================================================================
import { useMemo, useState } from 'react';
import {
  Printer, ShoppingCart, Factory, Receipt, CheckSquare, Square, CalendarRange, ChevronDown, Package,
} from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { Input } from '@/components/ui/Input';
import { usePurchaseStore } from '@/store/purchaseStore';
import { useSalesStore } from '@/store/salesStore';
import { useCommandStore } from '@/store/commandStore';
import { useProductionStore } from '@/store/productionStore';
import { useFicheTechnicStore, type FicheTechnic } from '@/store/ficheTechnicStore';
import { useStockStore } from '@/store/stockStore';
import { useSupplierStore } from '@/store/supplierStore';
import { useClientStore } from '@/store/clientStore';
import { useSettingsStore } from '@/store/settingsStore';
import { stockRequirementsForDelivery } from '@/lib/ficheStock';
import { printDetailedReport, type PrintTableSection, type PrintKpi } from '@/lib/reportPrint';
import { formatCurrency, formatDate, matchesDateFilter, dayOf, type DateFilter } from '@/lib/utils';
import type { Product } from '@/types';

export type HistoryTarget =
  | { kind: 'stock'; product: Product }
  | { kind: 'fiche'; fiche: FicheTechnic };

type Group = 'in' | 'used' | 'sales';

interface HistRow { date: string; cells: string[]; amount: number; qty: number }
interface HistSection {
  id: string;
  group: Group;
  title: string;
  icon: string;
  cols: { label: string; align?: 'left' | 'right' | 'center' }[];
  rows: HistRow[];
  /** Petites informations de la carte de totaux. */
  details: { label: string; value: string }[];
  qtyLabel: string;
  amountLabel: string;
  /** Signe appliqué aux totaux (retours, récupérations). */
  negative?: boolean;
}

/** Couleurs de chaque partie : texte, fond teinté, bordure et pastille d'icône. */
interface Tone { text: string; soft: string; border: string; chip: string; ring: string }
const GROUPS: { id: Group; label: (k: HistoryTarget['kind']) => string; icon: typeof Factory; tone: Tone }[] = [
  { id: 'in', label: (k) => (k === 'stock' ? 'Achats' : 'Production'), icon: ShoppingCart,
    tone: { text: 'text-gold-dark dark:text-gold-light', soft: 'bg-gold/[0.06] dark:bg-gold/10', border: 'border-gold/30', chip: 'bg-gold/15 text-gold-dark dark:text-gold-light', ring: 'ring-gold/50' } },
  { id: 'used', label: (k) => (k === 'stock' ? 'Quantités utilisées' : 'Matières consommées'), icon: Factory,
    tone: { text: 'text-caramel', soft: 'bg-caramel/[0.06] dark:bg-caramel/10', border: 'border-caramel/30', chip: 'bg-caramel/15 text-caramel', ring: 'ring-caramel/50' } },
  { id: 'sales', label: () => 'Ventes', icon: Receipt,
    tone: { text: 'text-pistachio', soft: 'bg-pistachio/[0.06] dark:bg-pistachio/10', border: 'border-pistachio/30', chip: 'bg-pistachio/15 text-pistachio', ring: 'ring-pistachio/50' } },
];

const norm = (s?: string) => (s ?? '').trim().toLowerCase();
const qty = (n: number, unit?: string) => `${Math.round(n * 1000) / 1000}${unit ? ` ${unit}` : ''}`;
const ORIGIN: Record<string, string> = { manual: 'Manuelle', pos: 'Point de vente', delivery: 'Bon de livraison' };

export function ProductHistory({ target, onClose }: { target: HistoryTarget | null; onClose: () => void }) {
  return (
    <Modal
      open={!!target}
      onClose={onClose}
      size="xl"
      title={target ? `Historique — ${target.kind === 'stock' ? target.product.name : target.fiche.name}` : ''}
    >
      {target && <HistoryBody target={target} />}
    </Modal>
  );
}

function HistoryBody({ target }: { target: HistoryTarget }) {
  const purchases = usePurchaseStore((s) => s.purchases);
  const returns = usePurchaseStore((s) => s.returns);
  const sales = useSalesStore((s) => s.sales);
  const commands = useCommandStore((s) => s.commands);
  const deliveries = useCommandStore((s) => s.deliveries);
  const recoveries = useCommandStore((s) => s.recoveries);
  const productions = useProductionStore((s) => s.productions);
  const fiches = useFicheTechnicStore((s) => s.ficheTechnics);
  const products = useStockStore((s) => s.products);
  const suppliers = useSupplierStore((s) => s.suppliers);
  const clients = useClientStore((s) => s.clients);
  const settings = useSettingsStore((s) => s.settings);

  const [period, setPeriod] = useState<DateFilter>('all');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [printOpen, setPrintOpen] = useState(false);
  const [printGroups, setPrintGroups] = useState<Group[]>(['in', 'used', 'sales']);
  const [activeGroup, setActiveGroup] = useState<Group>('in');
  /** Sections repliées à la main (les sections vides le sont d'office). */
  const [folded, setFolded] = useState<Record<string, boolean>>({});

  const inPeriod = (d: string) => !!d && matchesDateFilter(dayOf(d), period, from, to);
  const supplierName = (id?: string) => suppliers.find((s) => s.id === id)?.name ?? '—';
  const clientName = (id?: string | null) => (id ? clients.find((c) => c.id === id)?.name ?? '—' : 'Comptoir');
  const commandOf = (id?: string) => commands.find((c) => c.id === id);

  const sections = useMemo<HistSection[]>(() => {
    const keep = (rows: HistRow[]) => rows.filter((r) => inPeriod(r.date)).sort((a, b) => b.date.localeCompare(a.date));

    if (target.kind === 'stock') {
      const p = target.product;
      const unit = p.unit;
      const isMe = (id?: string, name?: string) => (id ? id === p.id : false) || (!id && norm(name) === norm(p.name));
      const ficheContains = (ficheId?: string, n = 1) =>
        ficheId ? stockRequirementsForDelivery([{ ficheTechnicId: ficheId, productName: '', quantity: n }], fiches, products)
          .filter((r) => r.productId === p.id || norm(r.productName) === norm(p.name))
          .reduce((s, r) => s + r.quantity, 0) : 0;

      // ---- Achats
      const buyRows: HistRow[] = [];
      purchases.forEach((pu) => pu.products.forEach((l) => {
        if (!isMe(l.productId, l.productName)) return;
        const amount = l.quantity * l.purchasePrice;
        buyRows.push({
          date: pu.date, qty: l.quantity, amount,
          cells: [formatDate(pu.date), pu.reference, supplierName(pu.supplierId), pu.bonNumber || '—',
            qty(l.quantity, l.unit ?? unit), formatCurrency(l.purchasePrice), formatCurrency(amount),
            pu.isHistorical ? 'Ancien achat' : pu.restAmount > 0 ? 'Dette' : 'Réglé'],
        });
      }));
      const retRows: HistRow[] = [];
      returns.forEach((r) => r.items.forEach((it) => {
        if (!isMe(it.productId, it.productName)) return;
        retRows.push({
          date: r.date, qty: it.quantity, amount: it.amount,
          cells: [formatDate(r.date), r.reference, supplierName(r.supplierId), qty(it.quantity, it.unit ?? unit),
            formatCurrency(it.unitPrice), formatCurrency(it.amount), r.reason || '—'],
        });
      }));

      // ---- Quantités utilisées
      const prodRows: HistRow[] = [];
      productions.forEach((pr) => pr.usedProducts.forEach((u) => {
        if (u.sourceType === 'fiche' || !isMe(u.productId, u.productName)) return;
        const cost = u.lineCost ?? u.quantityUsed * (u.unitCost ?? 0);
        prodRows.push({
          date: pr.date, qty: u.quantityUsed, amount: cost,
          cells: [formatDate(pr.date), pr.name, ORIGIN[pr.origin ?? 'manual'] + (pr.saleReference ? ` · ${pr.saleReference}` : ''),
            qty(pr.outputQuantity, pr.sellByUnit ? pr.sellUnit : undefined), qty(u.quantityUsed, u.unit ?? unit),
            formatCurrency(u.unitCost ?? 0), formatCurrency(cost)],
        });
      }));
      const blUseRows: HistRow[] = [];
      deliveries.forEach((d) => (d.consumptions ?? []).forEach((c) => {
        if (!isMe(c.productId, c.productName)) return;
        blUseRows.push({
          date: d.date, qty: c.quantity, amount: c.lineCost,
          cells: [formatDate(d.date), d.reference, commandOf(d.commandId)?.clientName ?? '—',
            qty(c.deliveredQuantity), qty(c.quantity, c.unit ?? unit), formatCurrency(c.unitCost), formatCurrency(c.lineCost)],
        });
      }));

      // ---- Ventes (point de vente + bons de livraison) contenant le produit
      const posRows: HistRow[] = [];
      sales.forEach((s) => {
        if (s.deliveryId) return; // facture d'un BL : comptée avec les bons
        s.products.forEach((l) => {
          const contained = l.ficheTechnicId ? ficheContains(l.ficheTechnicId, l.quantity) : isMe(l.productId, l.productName) ? l.quantity : 0;
          if (contained <= 0) return;
          const amount = l.quantity * l.sellingPrice;
          posRows.push({
            date: s.date, qty: contained, amount,
            cells: [formatDate(s.date), s.reference, clientName(s.clientId), l.productName || '—',
              qty(l.quantity, l.sellByUnit ? l.unit : undefined), qty(contained, unit), formatCurrency(l.sellingPrice), formatCurrency(amount)],
          });
        });
      });
      const blRows: HistRow[] = [];
      deliveries.forEach((d) => {
        const cmd = commandOf(d.commandId);
        d.items.forEach((it) => {
          const contained = it.ficheTechnicId ? ficheContains(it.ficheTechnicId, it.quantity) : norm(it.productName) === norm(p.name) ? it.quantity : 0;
          if (contained <= 0) return;
          const price = cmd?.items.find((ci) => ci.id === it.commandItemId)?.unitPrice ?? 0;
          blRows.push({
            date: d.date, qty: contained, amount: price * it.quantity,
            cells: [formatDate(d.date), d.reference, cmd?.clientName ?? '—', it.productName,
              qty(it.quantity, it.sellUnit), qty(contained, unit), formatCurrency(price), formatCurrency(price * it.quantity)],
          });
        });
      });

      const qtyCol = { label: 'Quantité', align: 'right' as const };
      return [
        {
          id: 'buy', group: 'in', title: 'Achats', icon: '🛒', qtyLabel: 'Quantité achetée', amountLabel: 'Montant',
          cols: [{ label: 'Date' }, { label: 'Réf.' }, { label: 'Fournisseur' }, { label: 'N° BL' }, qtyCol,
            { label: 'Prix achat', align: 'right' }, { label: 'Montant', align: 'right' }, { label: 'État' }],
          rows: keep(buyRows), details: [],
        },
        {
          id: 'ret', group: 'in', title: 'Retours aux fournisseurs', icon: '↩️', qtyLabel: 'Quantité rendue', amountLabel: 'Valeur', negative: true,
          cols: [{ label: 'Date' }, { label: 'Réf.' }, { label: 'Fournisseur' }, qtyCol,
            { label: 'Prix', align: 'right' }, { label: 'Montant', align: 'right' }, { label: 'Motif' }],
          rows: keep(retRows), details: [],
        },
        {
          id: 'prod', group: 'used', title: 'Utilisé en production', icon: '🏭', qtyLabel: 'Quantité utilisée', amountLabel: 'Coût',
          cols: [{ label: 'Date' }, { label: 'Production' }, { label: 'Origine' }, { label: 'Produit fabriqué', align: 'right' },
            { label: 'Qté utilisée', align: 'right' }, { label: 'Coût unit.', align: 'right' }, { label: 'Coût', align: 'right' }],
          rows: keep(prodRows), details: [],
        },
        {
          id: 'bluse', group: 'used', title: 'Retiré par les bons de livraison', icon: '🚚', qtyLabel: 'Quantité retirée', amountLabel: 'Coût',
          cols: [{ label: 'Date' }, { label: 'Bon' }, { label: 'Client' }, { label: 'Qté livrée', align: 'right' },
            { label: 'Qté retirée', align: 'right' }, { label: 'Coût unit.', align: 'right' }, { label: 'Coût', align: 'right' }],
          rows: keep(blUseRows), details: [],
        },
        {
          id: 'pos', group: 'sales', title: 'Ventes au point de vente', icon: '🧾', qtyLabel: 'Quantité contenue', amountLabel: 'Montant vendu',
          cols: [{ label: 'Date' }, { label: 'Facture' }, { label: 'Client' }, { label: 'Article vendu' }, { label: 'Qté vendue', align: 'right' },
            { label: 'Dont ce produit', align: 'right' }, { label: 'Prix', align: 'right' }, { label: 'Montant', align: 'right' }],
          rows: keep(posRows), details: [],
        },
        {
          id: 'bl', group: 'sales', title: 'Ventes par bon de livraison', icon: '🚚', qtyLabel: 'Quantité contenue', amountLabel: 'Montant vendu',
          cols: [{ label: 'Date' }, { label: 'Bon' }, { label: 'Client' }, { label: 'Article livré' }, { label: 'Qté livrée', align: 'right' },
            { label: 'Dont ce produit', align: 'right' }, { label: 'Prix', align: 'right' }, { label: 'Montant', align: 'right' }],
          rows: keep(blRows), details: [],
        },
      ];
    }

    // ================= produit de production (fiche technique)
    const f = target.fiche;
    const unit = f.sellByUnit ? f.sellUnit : undefined;
    const isMe = (ficheId?: string, name?: string) => (ficheId ? ficheId === f.id : norm(name) === norm(f.name));

    const lots = productions.filter((pr) => isMe(pr.ficheTechnicId, pr.name));
    const lotRows: HistRow[] = lots.map((pr) => ({
      date: pr.date, qty: pr.outputQuantity, amount: pr.totalCost ?? 0,
      cells: [formatDate(pr.date), pr.hour || '—', ORIGIN[pr.origin ?? 'manual'] + (pr.saleReference ? ` · ${pr.saleReference}` : ''),
        qty(pr.outputQuantity, unit), pr.hasLoss ? qty(pr.lossQuantity ?? 0, unit) : '—',
        formatCurrency(pr.totalCost ?? 0), formatCurrency(pr.totalValue), pr.createdBy || '—'],
    }));

    // matières consommées, regroupées par matière
    const mat = new Map<string, { name: string; unit?: string; q: number; c: number; n: number; last: string }>();
    lots.filter((pr) => inPeriod(pr.date)).forEach((pr) => pr.usedProducts.forEach((u) => {
      const k = norm(u.productName);
      const cur = mat.get(k) ?? { name: u.productName, unit: u.unit, q: 0, c: 0, n: 0, last: '' };
      cur.q += u.quantityUsed;
      cur.c += u.lineCost ?? u.quantityUsed * (u.unitCost ?? 0);
      cur.n += 1;
      if (pr.date > cur.last) cur.last = pr.date;
      mat.set(k, cur);
    }));
    const matRows: HistRow[] = [...mat.values()].sort((a, b) => b.c - a.c).map((m) => ({
      date: m.last, qty: m.q, amount: m.c,
      cells: [m.name, String(m.n), qty(m.q, m.unit), formatCurrency(m.q ? m.c / m.q : 0), formatCurrency(m.c), formatDate(m.last)],
    }));

    const posRows: HistRow[] = [];
    sales.forEach((s) => {
      if (s.deliveryId) return;
      s.products.forEach((l) => {
        if (!isMe(l.ficheTechnicId, l.productName)) return;
        const amount = l.quantity * l.sellingPrice;
        posRows.push({
          date: s.date, qty: l.quantity, amount,
          cells: [formatDate(s.date), s.reference, clientName(s.clientId), qty(l.quantity, l.sellByUnit ? l.unit : unit),
            formatCurrency(l.sellingPrice), formatCurrency(amount), s.isHistorical ? 'Ancienne' : s.status === 'paid' ? 'Payée' : 'Dette'],
        });
      });
    });

    const blRows: HistRow[] = [];
    deliveries.forEach((d) => {
      const cmd = commandOf(d.commandId);
      d.items.forEach((it) => {
        if (!isMe(it.ficheTechnicId, it.productName)) return;
        const price = cmd?.items.find((ci) => ci.id === it.commandItemId)?.unitPrice ?? 0;
        blRows.push({
          date: d.date, qty: it.quantity, amount: price * it.quantity,
          cells: [formatDate(d.date), d.reference, cmd?.clientName ?? '—', qty(it.quantity, it.sellUnit ?? unit),
            qty(it.fromReady ?? 0), qty(it.producedQuantity ?? 0), formatCurrency(price), formatCurrency(price * it.quantity),
            formatCurrency(it.costAmount ?? 0)],
        });
      });
    });

    const recRows: HistRow[] = [];
    recoveries.forEach((r) => r.items.forEach((it) => {
      if (!isMe(it.ficheTechnicId, it.productName)) return;
      recRows.push({
        date: r.date, qty: it.quantity, amount: it.amount,
        cells: [formatDate(r.date), r.reference, r.clientName || '—', qty(it.quantity, it.unit ?? unit),
          formatCurrency(it.unitPrice), formatCurrency(it.amount), r.reason || '—'],
      });
    }));

    return [
      {
        id: 'lots', group: 'in', title: 'Lots produits', icon: '🏭', qtyLabel: 'Quantité produite', amountLabel: 'Coût de revient',
        cols: [{ label: 'Date' }, { label: 'Heure' }, { label: 'Origine' }, { label: 'Produit', align: 'right' }, { label: 'Perte', align: 'right' },
          { label: 'Coût', align: 'right' }, { label: 'Valeur', align: 'right' }, { label: 'Par' }],
        rows: keep(lotRows),
        details: [{ label: 'Valeur de vente', value: formatCurrency(lots.filter((x) => inPeriod(x.date)).reduce((s, x) => s + x.totalValue, 0)) },
          { label: 'Pertes', value: qty(lots.filter((x) => inPeriod(x.date)).reduce((s, x) => s + (x.lossQuantity ?? 0), 0), unit) }],
      },
      {
        id: 'mat', group: 'used', title: 'Matières consommées', icon: '🧪', qtyLabel: '', amountLabel: 'Coût total',
        cols: [{ label: 'Matière' }, { label: 'Lots', align: 'center' }, { label: 'Quantité', align: 'right' },
          { label: 'Coût moyen', align: 'right' }, { label: 'Coût', align: 'right' }, { label: 'Dernière utilisation' }],
        rows: matRows, details: [{ label: 'Matières différentes', value: String(matRows.length) }],
      },
      {
        id: 'pos', group: 'sales', title: 'Ventes au point de vente', icon: '🧾', qtyLabel: 'Quantité vendue', amountLabel: 'Montant',
        cols: [{ label: 'Date' }, { label: 'Facture' }, { label: 'Client' }, { label: 'Quantité', align: 'right' },
          { label: 'Prix', align: 'right' }, { label: 'Montant', align: 'right' }, { label: 'État' }],
        rows: keep(posRows), details: [],
      },
      {
        id: 'bl', group: 'sales', title: 'Ventes par bon de livraison', icon: '🚚', qtyLabel: 'Quantité livrée', amountLabel: 'Montant',
        cols: [{ label: 'Date' }, { label: 'Bon' }, { label: 'Client' }, { label: 'Livré', align: 'right' }, { label: 'Du stock prêt', align: 'right' },
          { label: 'Produit auto.', align: 'right' }, { label: 'Prix', align: 'right' }, { label: 'Montant', align: 'right' }, { label: 'Coût', align: 'right' }],
        rows: keep(blRows), details: [],
      },
      {
        id: 'rec', group: 'sales', title: 'Récupérations (retours clients)', icon: '↩️', qtyLabel: 'Quantité récupérée', amountLabel: 'Montant', negative: true,
        cols: [{ label: 'Date' }, { label: 'Réf.' }, { label: 'Client' }, { label: 'Quantité', align: 'right' },
          { label: 'Prix', align: 'right' }, { label: 'Montant', align: 'right' }, { label: 'Motif' }],
        rows: keep(recRows), details: [],
      },
    ];
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target, period, from, to, purchases, returns, sales, commands, deliveries, recoveries, productions, fiches, products, suppliers, clients]);

  const unit = target.kind === 'stock' ? target.product.unit : target.fiche.sellByUnit ? target.fiche.sellUnit : undefined;
  const sum = (s: HistSection) => ({
    q: s.rows.reduce((a, r) => a + r.qty, 0),
    a: s.rows.reduce((a, r) => a + r.amount, 0),
  });

  const periodLabel =
    period === 'all' ? 'Toutes les périodes'
      : period === 'today' ? "Aujourd'hui"
        : period === 'week' ? '7 derniers jours'
          : period === 'month' ? 'Ce mois'
            : from && to ? `Du ${formatDate(from)} au ${formatDate(to)}` : 'Période personnalisée';

  const groupTotals = (g: Group) => sections.filter((s) => s.group === g).reduce(
    (acc, s) => { const t = sum(s); const k = s.negative ? -1 : 1; return { q: acc.q + k * t.q, a: acc.a + k * t.a, n: acc.n + s.rows.length }; },
    { q: 0, a: 0, n: 0 }
  );

  const handlePrint = () => {
    const name = target.kind === 'stock' ? target.product.name : target.fiche.name;
    const chosen = sections.filter((s) => printGroups.includes(s.group));
    const kpis: PrintKpi[] = GROUPS.filter((g) => printGroups.includes(g.id)).flatMap((g): PrintKpi[] => {
      const t = groupTotals(g.id);
      const label = g.label(target.kind);
      return g.id === 'used' && target.kind === 'fiche'
        ? [{ label: `${label} — coût`, value: formatCurrency(t.a), tone: 'neg' as const }]
        : [{ label: `${label} — quantité`, value: qty(t.q, unit) }, { label: `${label} — montant`, value: formatCurrency(t.a), tone: g.id === 'sales' ? 'pos' as const : 'accent' as const }];
    });
    const printSections: PrintTableSection[] = chosen.map((s) => {
      const t = sum(s);
      return {
        title: s.title,
        icon: s.icon,
        headerTotal: `${s.rows.length} opération(s)${s.qtyLabel ? ` · ${qty(t.q, unit)}` : ''} · ${formatCurrency(t.a)}`,
        cols: s.cols,
        rows: [
          ...s.rows.map((r) => ({ cells: r.cells, variant: 'detail' as const })),
          ...(s.rows.length ? [{ cells: ['TOTAL', ...Array(s.cols.length - 2).fill(''), formatCurrency(t.a)], variant: 'total' as const }] : []),
        ],
        emptyLabel: 'Aucune opération sur la période',
      };
    });
    printDetailedReport({
      docTitle: `Historique ${name}`,
      headTitle: target.kind === 'stock' ? 'HISTORIQUE DU PRODUIT' : 'HISTORIQUE DU PRODUIT FINI',
      subtitle: periodLabel,
      meta: [
        { label: 'Produit', value: name },
        { label: 'Type', value: target.kind === 'stock' ? 'Produit de stock' : `Produit de production — ${target.fiche.categoryName || ''}` },
        ...(target.kind === 'stock'
          ? [{ label: 'Stock actuel', value: qty(target.product.currentQuantity, unit) }, { label: "Prix d'achat", value: formatCurrency(target.product.purchasePrice) }]
          : [{ label: 'Prix de vente', value: formatCurrency(target.fiche.unitPrice) }, { label: 'Coût / unité', value: formatCurrency(target.fiche.costPerUnit) }]),
        { label: 'Parties imprimées', value: GROUPS.filter((g) => printGroups.includes(g.id)).map((g) => g.label(target.kind)).join(' · ') },
      ],
      kpis,
      sections: printSections,
    }, settings);
    setPrintOpen(false);
  };

  const active = GROUPS.find((g) => g.id === activeGroup) ?? GROUPS[0];
  const activeSections = sections.filter((s) => s.group === active.id);

  return (
    <div className="space-y-5">
      {/* Résumé du produit + période + impression */}
      <div className="rounded-2xl border border-black/[0.07] dark:border-white/[0.08] bg-vanilla/50 p-4 flex flex-wrap items-center gap-4">
        <div className="flex items-center gap-3 min-w-0">
          <span className="h-11 w-11 shrink-0 rounded-xl bg-gold/15 text-gold-dark dark:text-gold-light flex items-center justify-center">
            <Package size={20} />
          </span>
          <div className="min-w-0">
            <p className="text-[11px] uppercase tracking-wide text-text-muted">
              {target.kind === 'stock' ? 'Produit de stock' : `Produit de production${target.fiche.categoryName ? ` · ${target.fiche.categoryName}` : ''}`}
            </p>
            <p className="text-sm text-text-secondary">
              {target.kind === 'stock' ? (
                <>Stock actuel <b className="tabular text-text-primary">{qty(target.product.currentQuantity, unit)}</b> · Prix d'achat <b className="tabular text-text-primary">{formatCurrency(target.product.purchasePrice)}</b></>
              ) : (
                <>Prix de vente <b className="tabular text-text-primary">{formatCurrency(target.fiche.unitPrice)}</b> · Coût / unité <b className="tabular text-text-primary">{formatCurrency(target.fiche.costPerUnit)}</b></>
              )}
            </p>
          </div>
        </div>
        <div className="ml-auto flex flex-wrap items-end gap-2">
          <div className="flex items-center gap-1.5 self-center text-text-secondary text-xs font-semibold"><CalendarRange size={16} className="text-gold" /> Période</div>
          <Select
            value={period}
            onChange={(e) => setPeriod(e.target.value as DateFilter)}
            options={[
              { value: 'all', label: 'Toutes les périodes' },
              { value: 'today', label: "Aujourd'hui" },
              { value: 'week', label: '7 derniers jours' },
              { value: 'month', label: 'Ce mois' },
              { value: 'custom', label: 'Personnalisée' },
            ]}
            className="w-[180px]"
          />
          {period === 'custom' && (
            <>
              <Input type="date" value={from} onChange={(e) => setFrom(e.target.value)} className="w-[150px]" />
              <Input type="date" value={to} onChange={(e) => setTo(e.target.value)} className="w-[150px]" />
            </>
          )}
          <Button variant="gold" onClick={() => setPrintOpen(true)}><Printer size={16} /> Imprimer</Button>
        </div>
      </div>

      {/* Une carte par partie : elle sert aussi d'onglet */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {GROUPS.map((g) => {
          const t = groupTotals(g.id);
          const Icon = g.icon;
          const on = g.id === activeGroup;
          return (
            <button
              key={g.id}
              type="button"
              onClick={() => setActiveGroup(g.id)}
              className={`text-left rounded-2xl border p-4 transition-all ${g.tone.soft} ${
                on ? `${g.tone.border} ring-2 ${g.tone.ring} shadow-card` : 'border-black/[0.06] dark:border-white/[0.07] opacity-80 hover:opacity-100'
              }`}
            >
              <div className="flex items-center gap-2.5">
                <span className={`h-9 w-9 rounded-xl flex items-center justify-center ${g.tone.chip}`}><Icon size={18} /></span>
                <div className="min-w-0">
                  <p className="font-display font-semibold text-text-primary leading-tight">{g.label(target.kind)}</p>
                  <p className="text-[11px] text-text-muted">{t.n} opération(s)</p>
                </div>
              </div>
              <div className="mt-3 flex items-end justify-between gap-2">
                {!(g.id === 'used' && target.kind === 'fiche')
                  ? <p className="text-xl font-extrabold tabular text-text-primary leading-none">{qty(t.q, unit)}</p>
                  : <span />}
                <p className={`text-sm font-bold tabular ${g.tone.text}`}>{formatCurrency(t.a)}</p>
              </div>
            </button>
          );
        })}
      </div>

      {/* Détail de la partie choisie */}
      <div className="space-y-3">
        {activeSections.map((s) => {
          const t = sum(s);
          const isFolded = folded[s.id] ?? s.rows.length === 0;
          return (
            <div key={s.id} className={`rounded-2xl border overflow-hidden bg-[--surface-dropdown] ${s.rows.length ? active.tone.border : 'border-black/[0.06] dark:border-white/[0.07]'}`}>
              <button
                type="button"
                onClick={() => setFolded((f) => ({ ...f, [s.id]: !isFolded }))}
                className={`w-full flex flex-wrap items-center gap-x-3 gap-y-1 px-4 py-3 text-left ${s.rows.length ? active.tone.soft : ''}`}
              >
                <span className="text-sm font-semibold text-text-primary">{s.icon} {s.title}</span>
                <span className={`rounded-full px-2 py-0.5 text-[10px] font-bold ${s.rows.length ? active.tone.chip : 'bg-black/[0.05] dark:bg-white/[0.06] text-text-muted'}`}>
                  {s.rows.length}
                </span>
                <span className="ml-auto flex items-center gap-3 text-xs tabular text-text-secondary">
                  {s.rows.length > 0 && (
                    <>
                      {s.qtyLabel && <span>{s.qtyLabel} : <b className="text-text-primary">{s.negative ? '−' : ''}{qty(t.q, unit)}</b></span>}
                      <span>{s.amountLabel} : <b className={active.tone.text}>{s.negative ? '−' : ''}{formatCurrency(t.a)}</b></span>
                    </>
                  )}
                  {s.rows.length === 0 && <span className="text-text-muted">Aucune opération sur la période</span>}
                  <ChevronDown size={16} className={`text-text-muted transition-transform ${isFolded ? '' : 'rotate-180'}`} />
                </span>
              </button>
              {!isFolded && s.rows.length > 0 && (
                <div className="overflow-x-auto max-h-80 border-t border-black/[0.06] dark:border-white/[0.07]">
                  <table className="w-full text-xs">
                    <thead className="sticky top-0 z-10 bg-vanilla text-text-muted">
                      <tr>{s.cols.map((c) => (
                        <th key={c.label} className={`px-3 py-2 text-[10px] font-bold uppercase tracking-wide whitespace-nowrap text-${c.align ?? 'left'}`}>{c.label}</th>
                      ))}</tr>
                    </thead>
                    <tbody>
                      {s.rows.map((r, i) => (
                        <tr key={i} className="border-t border-black/[0.05] dark:border-white/[0.05] odd:bg-black/[0.015] dark:odd:bg-white/[0.02] hover:bg-gold/5">
                          {r.cells.map((c, j) => (
                            <td key={j} className={`px-3 py-2 tabular whitespace-nowrap text-text-secondary text-${s.cols[j]?.align ?? 'left'} ${j === r.cells.length - 1 || s.cols[j]?.label === 'Montant' ? 'font-semibold text-text-primary' : ''}`}>{c}</td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              {!isFolded && s.details.length > 0 && (
                <div className="flex flex-wrap gap-x-5 gap-y-1 px-4 py-2 border-t border-black/[0.06] dark:border-white/[0.07] text-[11px]">
                  {s.details.map((d) => (
                    <span key={d.label} className="text-text-muted">{d.label} : <b className="tabular text-text-secondary">{d.value}</b></span>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Choix des parties à imprimer */}
      <Modal open={printOpen} onClose={() => setPrintOpen(false)} title="Imprimer l'historique" size="sm">
        <div className="space-y-3">
          <p className="text-sm text-text-muted">Choisissez les parties à imprimer ({periodLabel}) :</p>
          {GROUPS.map((g) => {
            const on = printGroups.includes(g.id);
            return (
              <button
                key={g.id}
                type="button"
                onClick={() => setPrintGroups((p) => (on ? p.filter((x) => x !== g.id) : [...p, g.id]))}
                className={`w-full flex items-center gap-2.5 rounded-xl border px-3 py-2.5 text-left ${on ? 'border-pistachio/40 bg-pistachio/8' : 'border-gold/15'}`}
              >
                {on ? <CheckSquare size={18} className="text-pistachio" /> : <Square size={18} className="text-text-muted" />}
                <span className="text-sm font-semibold">{g.label(target.kind)}</span>
              </button>
            );
          })}
          <div className="flex gap-2 text-xs">
            <button type="button" className="text-gold-dark hover:underline" onClick={() => setPrintGroups(['in', 'used', 'sales'])}>Tout</button>
            <button type="button" className="text-gold-dark hover:underline" onClick={() => setPrintGroups(['in', 'sales'])}>
              {target.kind === 'stock' ? 'Achats + ventes' : 'Production + ventes'}
            </button>
          </div>
          <Button variant="gold" className="w-full" disabled={printGroups.length === 0} onClick={handlePrint}>
            <Printer size={16} /> Imprimer
          </Button>
        </div>
      </Modal>
    </div>
  );
}
