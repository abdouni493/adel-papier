// ============================================================================
//  SAUVEGARDE EXCEL (.xlsx)
// ----------------------------------------------------------------------------
//  Exporte les données de l'application dans un classeur Excel : une ou
//  plusieurs FEUILLES par partie de l'application. Chaque enregistrement
//  devient une ligne ; ses listes internes (lignes d'un achat, paiements d'une
//  vente, matières d'une fiche…) partent dans une feuille de détail reliée à
//  leur parent par la colonne « Parent ».
//
//  Les données sont relues depuis la base juste avant l'export : le fichier
//  reflète toujours l'état réel, pas un écran resté ouvert.
// ============================================================================
import { useStockStore } from '@/store/stockStore';
import { useSupplierStore } from '@/store/supplierStore';
import { useClientStore } from '@/store/clientStore';
import { useClientDebtStore } from '@/store/clientDebtStore';
import { usePurchaseStore } from '@/store/purchaseStore';
import { useSalesStore } from '@/store/salesStore';
import { useCommandStore } from '@/store/commandStore';
import { useProductionStore } from '@/store/productionStore';
import { useFicheTechnicStore } from '@/store/ficheTechnicStore';
import { useComptoirStore } from '@/store/comptoirStore';
import { useWorkerStore } from '@/store/workerStore';
import { useAttendanceStore } from '@/store/attendanceStore';
import { useExpenseStore } from '@/store/expenseStore';
import { useCaisseStore } from '@/store/caisseStore';
import { useCaisseReportStore } from '@/store/caisseReportStore';
import { useFreeInvoiceStore } from '@/store/freeInvoiceStore';
import { useWebsiteStore } from '@/store/websiteStore';
import { useSettingsStore } from '@/store/settingsStore';
import { todayISO } from './utils';

type Rec = Record<string, unknown>;

interface SheetDef {
  name: string;
  rows: () => unknown[] | Promise<unknown[]>;
}

export interface BackupSection {
  id: string;
  label: string;
  description: string;
  load: () => Promise<unknown>;
  sheets: SheetDef[];
}

const noop = async () => undefined;

export const BACKUP_SECTIONS: BackupSection[] = [
  {
    id: 'stock', label: 'Gestion de stock', description: 'Produits, unités, catégories, marques',
    load: () => useStockStore.getState().load(),
    sheets: [
      { name: 'Produits', rows: () => useStockStore.getState().products },
      { name: 'Unités', rows: () => useStockStore.getState().units },
      { name: 'Catégories stock', rows: () => useStockStore.getState().categories },
      { name: 'Marques', rows: () => useStockStore.getState().marques },
    ],
  },
  {
    id: 'suppliers', label: 'Fournisseurs', description: 'Fiches, versements, anciennes dettes, remboursements',
    load: () => useSupplierStore.getState().load(),
    sheets: [
      { name: 'Fournisseurs', rows: () => useSupplierStore.getState().suppliers },
      { name: 'Versements fournisseurs', rows: () => useSupplierStore.getState().payments },
      { name: 'Anc. dettes fournisseurs', rows: () => useSupplierStore.getState().oldDebts },
      { name: 'Rembours. fournisseurs', rows: () => useSupplierStore.getState().refunds },
    ],
  },
  {
    id: 'clients', label: 'Clients', description: 'Fiches, versements, anciennes dettes, remboursements, dettes',
    load: () => Promise.all([useClientStore.getState().load(), useClientDebtStore.getState().load().catch(noop)]),
    sheets: [
      { name: 'Clients', rows: () => useClientStore.getState().clients },
      { name: 'Versements clients', rows: () => useClientStore.getState().payments },
      { name: 'Anc. dettes clients', rows: () => useClientStore.getState().oldDebts },
      { name: 'Rembours. clients', rows: () => useClientStore.getState().refunds },
      { name: 'Dettes clients', rows: () => useClientDebtStore.getState().debts },
    ],
  },
  {
    id: 'purchases', label: 'Achats', description: 'Factures d\'achat, lignes, paiements, frais, retours',
    load: () => usePurchaseStore.getState().load(),
    sheets: [
      { name: 'Achats', rows: () => usePurchaseStore.getState().purchases },
      { name: 'Retours achat', rows: () => usePurchaseStore.getState().returns },
      { name: 'Catégories frais', rows: () => usePurchaseStore.getState().feeCategories },
    ],
  },
  {
    id: 'sales', label: 'Ventes (point de vente)', description: 'Factures de vente, lignes, paiements',
    load: () => useSalesStore.getState().load(),
    sheets: [{ name: 'Ventes', rows: () => useSalesStore.getState().sales }],
  },
  {
    id: 'commands', label: 'Commandes & livraisons', description: 'Commandes, bons de livraison, ajustements, récupérations',
    load: () => useCommandStore.getState().load(),
    sheets: [
      { name: 'Commandes', rows: () => useCommandStore.getState().commands },
      { name: 'Bons de livraison', rows: () => useCommandStore.getState().deliveries },
      { name: 'Ajustements commande', rows: () => useCommandStore.getState().adjustments },
      { name: 'Récupérations', rows: () => useCommandStore.getState().recoveries },
    ],
  },
  {
    id: 'production', label: 'Production', description: 'Lots produits, matières consommées, catégories',
    load: () => useProductionStore.getState().load(),
    sheets: [
      { name: 'Productions', rows: () => useProductionStore.getState().productions },
      { name: 'Catégories production', rows: () => useProductionStore.getState().categories },
    ],
  },
  {
    id: 'fiches', label: 'Fiches techniques', description: 'Recettes, dosages, coûts, catégories',
    load: () => useFicheTechnicStore.getState().load(),
    sheets: [
      { name: 'Fiches techniques', rows: () => useFicheTechnicStore.getState().ficheTechnics },
      { name: 'Catégories fiches', rows: () => useFicheTechnicStore.getState().categories },
    ],
  },
  {
    id: 'comptoir', label: 'Comptoir', description: 'Articles au comptoir, destructions',
    load: () => useComptoirStore.getState().load(),
    sheets: [
      { name: 'Comptoir', rows: () => useComptoirStore.getState().items },
      { name: 'Destructions', rows: () => useComptoirStore.getState().destructions },
    ],
  },
  {
    id: 'workers', label: 'Employés & paie', description: 'Employés, acomptes, absences, paiements, heures sup., retards, rôles',
    load: () => useWorkerStore.getState().load(),
    sheets: [
      { name: 'Employés', rows: () => useWorkerStore.getState().workers },
      { name: 'Rôles', rows: () => useWorkerStore.getState().roles },
    ],
  },
  {
    id: 'attendance', label: 'Pointeuse', description: 'Pointages, appareils',
    load: () => useAttendanceStore.getState().loadMeta(),
    sheets: [
      { name: 'Pointages', rows: () => useAttendanceStore.getState().fetchPunches('2000-01-01', todayISO()).catch(() => []) },
      { name: 'Appareils pointeuse', rows: () => useAttendanceStore.getState().devices },
    ],
  },
  {
    id: 'expenses', label: 'Dépenses', description: 'Dépenses, catégories, bons de commande',
    load: () => useExpenseStore.getState().load(),
    sheets: [
      { name: 'Dépenses', rows: () => useExpenseStore.getState().expenses },
      { name: 'Catégories dépenses', rows: () => useExpenseStore.getState().categories },
      { name: 'Bons de commande', rows: () => useExpenseStore.getState().orders },
    ],
  },
  {
    id: 'caisse', label: 'Caisse', description: 'Mouvements de caisse, catégories, rapports',
    load: () => Promise.all([useCaisseStore.getState().load(), useCaisseReportStore.getState().load()]),
    sheets: [
      { name: 'Caisse', rows: () => useCaisseStore.getState().transactions },
      { name: 'Catégories caisse', rows: () => useCaisseStore.getState().categories },
      { name: 'Rapports caisse', rows: () => useCaisseReportStore.getState().reports },
    ],
  },
  {
    id: 'freeInvoices', label: 'Factures non comptabilisées', description: 'Factures, BL et proformas libres',
    load: () => useFreeInvoiceStore.getState().load(),
    sheets: [{ name: 'Factures libres', rows: () => useFreeInvoiceStore.getState().invoices }],
  },
  {
    id: 'website', label: 'Site web', description: 'Textes et commandes du site',
    load: () => useWebsiteStore.getState().load(),
    sheets: [
      { name: 'Commandes site', rows: () => useWebsiteStore.getState().orders },
      { name: 'Textes site', rows: () => useWebsiteStore.getState().texts },
    ],
  },
  {
    id: 'settings', label: 'Paramètres', description: 'Informations de l\'entreprise',
    load: () => useSettingsStore.getState().load(),
    sheets: [{ name: 'Paramètres', rows: () => [useSettingsStore.getState().settings] }],
  },
];

/** Champs jamais exportés (secrets). */
const SECRET = /password|pwd|token|secret/i;

const isPlainObject = (v: unknown): v is Rec => !!v && typeof v === 'object' && !Array.isArray(v);

function cellValue(v: unknown): string | number | boolean | null {
  if (v === null || v === undefined) return null;
  if (typeof v === 'number' || typeof v === 'boolean') return v;
  if (typeof v === 'string') return v.length > 32000 ? v.slice(0, 32000) : v;
  if (Array.isArray(v)) return v.map((x) => (isPlainObject(x) ? JSON.stringify(x) : String(x))).join(', ');
  return JSON.stringify(v);
}

function parentLabel(r: Rec): string {
  return String(r.reference ?? r.name ?? r.label ?? r.id ?? '');
}

/**
 * Aplatie une liste d'enregistrements : les champs simples restent sur la
 * feuille principale, chaque liste d'objets part sur une feuille de détail.
 */
function flatten(name: string, records: unknown[], out: Map<string, Rec[]>, depth = 0): void {
  const rows: Rec[] = out.get(name) ?? [];
  out.set(name, rows);
  records.forEach((raw) => {
    if (!isPlainObject(raw)) { rows.push({ valeur: cellValue(raw) }); return; }
    const row: Rec = {};
    Object.entries(raw).forEach(([k, v]) => {
      if (SECRET.test(k) || typeof v === 'function') return;
      if (Array.isArray(v) && v.some(isPlainObject) && depth < 2) {
        const parent = parentLabel(raw);
        flatten(`${name} › ${k}`, v.map((x) => (isPlainObject(x) ? { Parent: parent, ...x } : { Parent: parent, valeur: x })), out, depth + 1);
        row[k] = `${v.length} ligne(s)`;
        return;
      }
      row[k] = cellValue(v);
    });
    rows.push(row);
  });
}

/** Nom de feuille Excel valide (31 car. max, sans caractères interdits, unique). */
function sheetName(raw: string, used: Set<string>): string {
  const base = raw.replace(/[\\/?*[\]:]/g, '-').slice(0, 31) || 'Feuille';
  let n = base;
  let i = 2;
  while (used.has(n.toLowerCase())) { const s = ` (${i++})`; n = base.slice(0, 31 - s.length) + s; }
  used.add(n.toLowerCase());
  return n;
}

/**
 * Construit et télécharge le classeur des parties choisies. Retourne le nombre
 * de feuilles écrites et les parties qui n'ont pas pu être relues.
 */
export async function exportExcelBackup(sectionIds: string[]): Promise<{ sheets: number; failed: string[] }> {
  const XLSX = await import('xlsx');
  const sections = BACKUP_SECTIONS.filter((s) => sectionIds.includes(s.id));
  const failed: string[] = [];

  await Promise.all(sections.map(async (s) => {
    try { await s.load(); } catch { failed.push(s.label); }
  }));

  const wb = XLSX.utils.book_new();
  const used = new Set<string>();

  const summary: Rec[] = [];
  for (const section of sections) {
    for (const sheet of section.sheets) {
      let records: unknown[] = [];
      try { records = (await sheet.rows()) ?? []; } catch { records = []; }
      const out = new Map<string, Rec[]>();
      flatten(sheet.name, records, out);
      out.forEach((rows, name) => {
        const finalName = sheetName(name, used);
        const ws = rows.length
          ? XLSX.utils.json_to_sheet(rows)
          : XLSX.utils.aoa_to_sheet([['Aucune donnée']]);
        // largeur des colonnes d'après l'en-tête et le contenu
        const keys = rows.length ? Array.from(new Set(rows.flatMap((r) => Object.keys(r)))) : ['Aucune donnée'];
        ws['!cols'] = keys.map((k) => ({
          wch: Math.min(50, Math.max(k.length, ...rows.slice(0, 200).map((r) => String(r[k] ?? '').length)) + 2),
        }));
        XLSX.utils.book_append_sheet(wb, ws, finalName);
        summary.push({ Partie: section.label, Feuille: finalName, Lignes: rows.length });
      });
    }
  }

  const info = XLSX.utils.json_to_sheet([
    { Partie: 'Sauvegarde', Feuille: `Créée le ${new Date().toLocaleString('fr-FR')}`, Lignes: null },
    ...summary,
  ]);
  info['!cols'] = [{ wch: 32 }, { wch: 40 }, { wch: 10 }];
  XLSX.utils.book_append_sheet(wb, info, sheetName('Sommaire', used));
  // le sommaire en premier
  wb.SheetNames = [wb.SheetNames[wb.SheetNames.length - 1], ...wb.SheetNames.slice(0, -1)];

  const stamp = new Date().toTimeString().slice(0, 5).replace(':', 'h');
  XLSX.writeFile(wb, `sauvegarde-${todayISO()}-${stamp}.xlsx`);
  return { sheets: summary.length, failed };
}
