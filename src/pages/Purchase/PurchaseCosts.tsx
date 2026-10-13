import { useMemo, useState } from 'react';
import { Plus, X, Percent, Ship, Receipt, Euro, ArrowRightLeft, Tags } from 'lucide-react';
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';
import { Switch } from '@/components/ui/Switch';
import { usePurchaseStore, type PurchaseCostsInput } from '@/store/purchaseStore';
import { formatCurrency } from '@/lib/utils';
import { summarizePurchaseFees, purchaseFeesTotal, purchaseGrandTotal } from '@/lib/purchaseCosts';
import { toast } from '@/components/ui/Toast';
import type { Purchase } from '@/types';

export const emptyCosts = (): PurchaseCostsInput => ({
  tvaEnabled: false,
  tvaRate: 19,
  customsFees: 0,
  transitFees: 0,
  extraFees: [],
  euroAmount: null,
  exchangeRate: null,
});

export const costsFromPurchase = (p: Purchase): PurchaseCostsInput => ({
  tvaEnabled: !!p.tvaEnabled,
  tvaRate: p.tvaRate ?? 19,
  customsFees: p.customsFees ?? 0,
  transitFees: p.transitFees ?? 0,
  extraFees: (p.extraFees ?? []).map((f) => ({ categoryId: f.categoryId, categoryName: f.categoryName, amount: f.amount })),
  euroAmount: p.euroAmount ?? null,
  exchangeRate: p.exchangeRate ?? null,
});

export function computeCosts(ht: number, c: PurchaseCostsInput) {
  const tva = c.tvaEnabled ? Math.round(ht * (Number(c.tvaRate) || 0)) / 100 : 0;
  const ttc = ht + tva;
  const extra = c.extraFees.reduce((s, f) => s + (Number(f.amount) || 0), 0);
  const fees = (Number(c.customsFees) || 0) + (Number(c.transitFees) || 0) + extra;
  return { tva, ttc, extra, fees, grand: ttc + fees };
}

/* --------------------------------------------------------------------------
 * Convertisseur euro → dinar : taux de change × montant en euro.
 * ------------------------------------------------------------------------ */
export function EuroConverter({
  euro, rate, onChange, onUseAmount, compact = false,
}: {
  euro: number | null | undefined;
  rate: number | null | undefined;
  onChange: (euro: number | null, rate: number | null) => void;
  /** Bouton facultatif : reporter le montant en dinar ailleurs. */
  onUseAmount?: (dinar: number) => void;
  compact?: boolean;
}) {
  const dinar = (Number(euro) || 0) * (Number(rate) || 0);
  return (
    <div className={`rounded-xl border border-gold/20 bg-gradient-card ${compact ? 'p-3' : 'p-4'}`}>
      <p className="text-[11px] font-bold uppercase tracking-wider text-text-muted mb-2.5 flex items-center gap-1.5">
        <ArrowRightLeft size={12} className="text-gold" /> Convertisseur euro → dinar
      </p>
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 items-end">
        <Input
          label="Taux de change (1 € = ? DA)"
          type="number" step="any" min={0}
          value={rate ?? ''}
          onChange={(e) => onChange(euro ?? null, e.target.value === '' ? null : Number(e.target.value))}
          placeholder="Ex : 250"
        />
        <Input
          label="Montant en euro (€)"
          icon={<Euro size={16} />}
          type="number" step="any" min={0}
          value={euro ?? ''}
          onChange={(e) => onChange(e.target.value === '' ? null : Number(e.target.value), rate ?? null)}
          placeholder="0"
        />
        <div>
          <p className="text-xs text-text-muted">Montant en dinar</p>
          <p className="text-xl font-bold tabular text-gold-dark">{formatCurrency(dinar)}</p>
        </div>
      </div>
      {onUseAmount && dinar > 0 && (
        <div className="mt-2 flex justify-end">
          <Button variant="secondary" size="sm" onClick={() => onUseAmount(dinar)}>
            Utiliser {formatCurrency(dinar)}
          </Button>
        </div>
      )}
    </div>
  );
}

/** Convertisseur autonome (page principale des achats) — garde ses propres valeurs. */
export function StandaloneEuroConverter() {
  const [euro, setEuro] = useState<number | null>(null);
  const [rate, setRate] = useState<number | null>(() => {
    try { const v = localStorage.getItem('purchase.eurRate'); return v ? Number(v) : null; } catch { return null; }
  });
  return (
    <EuroConverter
      euro={euro}
      rate={rate}
      compact
      onChange={(e, r) => {
        setEuro(e); setRate(r);
        try { if (r) localStorage.setItem('purchase.eurRate', String(r)); } catch { /* ignore */ }
      }}
    />
  );
}

/* --------------------------------------------------------------------------
 * Section du formulaire d'achat : TVA, douane, transitaire, frais
 * supplémentaires par catégorie, conversion euro et totaux finaux.
 * ------------------------------------------------------------------------ */
export function PurchaseCostsSection({
  totalHt, value, onChange,
}: {
  totalHt: number;
  value: PurchaseCostsInput;
  onChange: (v: PurchaseCostsInput) => void;
}) {
  const feeCategories = usePurchaseStore((s) => s.feeCategories);
  const addFeeCategory = usePurchaseStore((s) => s.addFeeCategory);
  const [newCat, setNewCat] = useState('');
  const set = (patch: Partial<PurchaseCostsInput>) => onChange({ ...value, ...patch });
  const t = useMemo(() => computeCosts(totalHt, value), [totalHt, value]);

  const updateFee = (i: number, patch: Partial<PurchaseCostsInput['extraFees'][number]>) =>
    set({ extraFees: value.extraFees.map((f, k) => (k === i ? { ...f, ...patch } : f)) });

  const createCategory = async () => {
    const name = newCat.trim();
    if (!name) return;
    try {
      const cat = await addFeeCategory(name);
      set({ extraFees: [...value.extraFees, { categoryId: cat.id, categoryName: cat.name, amount: 0 }] });
      setNewCat('');
      toast.success(`Catégorie « ${cat.name} » créée`);
    } catch { /* message déjà affiché */ }
  };

  return (
    <section className="bg-vanilla/30 rounded-2xl p-4 border border-gold/15 space-y-4">
      <h3 className="font-display font-semibold text-text-primary flex items-center gap-2 text-sm">
        <Receipt size={16} className="text-gold" /> 3. TVA, frais &amp; devise
        <span className="text-[11px] font-medium text-text-muted">(facultatif)</span>
      </h3>

      {/* TVA */}
      <div className="flex flex-wrap items-end gap-3">
        <Switch checked={value.tvaEnabled} onChange={(v) => set({ tvaEnabled: v })} label="Appliquer la TVA" />
        {value.tvaEnabled && (
          <>
            <Input
              label="Taux TVA (%)"
              icon={<Percent size={16} />}
              type="number" step="any" min={0}
              value={value.tvaRate}
              onChange={(e) => set({ tvaRate: Number(e.target.value) })}
              className="max-w-[140px]"
            />
            <p className="text-sm text-text-secondary">
              TVA : <b className="tabular text-gold-dark">{formatCurrency(t.tva)}</b>
            </p>
          </>
        )}
      </div>

      {/* Douane & transitaire */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
        <Input
          label="Frais de douane (DA)"
          icon={<Ship size={16} />}
          type="number" step="any" min={0}
          value={value.customsFees || ''}
          onChange={(e) => set({ customsFees: Number(e.target.value) })}
          placeholder="0"
        />
        <Input
          label="Frais transitaire (DA)"
          icon={<Ship size={16} />}
          type="number" step="any" min={0}
          value={value.transitFees || ''}
          onChange={(e) => set({ transitFees: Number(e.target.value) })}
          placeholder="0"
        />
      </div>

      {/* Frais supplémentaires */}
      <div className="rounded-xl border border-gold/15 p-3 space-y-2.5">
        <p className="text-[11px] font-bold uppercase tracking-wider text-text-muted flex items-center gap-1.5">
          <Tags size={12} className="text-gold" /> Frais supplémentaires
        </p>
        {value.extraFees.map((f, i) => (
          <div key={i} className="flex flex-wrap items-center gap-2">
            <select
              value={f.categoryId ?? ''}
              onChange={(e) => {
                const cat = feeCategories.find((c) => c.id === e.target.value);
                updateFee(i, { categoryId: cat?.id, categoryName: cat?.name ?? '' });
              }}
              className="h-10 flex-1 min-w-[180px] rounded-xl border border-gold/20 bg-[--surface-dropdown] px-3 text-sm text-text-primary"
            >
              <option value="">— Catégorie —</option>
              {feeCategories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
            <Input
              type="number" step="any" min={0}
              value={f.amount || ''}
              onChange={(e) => updateFee(i, { amount: Number(e.target.value) })}
              placeholder="Montant (DA)"
              className="max-w-[170px]"
            />
            <button
              type="button"
              onClick={() => set({ extraFees: value.extraFees.filter((_, k) => k !== i) })}
              className="text-rose-deep p-1 rounded-lg hover:bg-rose-deep/10"
            >
              <X size={16} />
            </button>
          </div>
        ))}
        <div className="flex flex-wrap items-center gap-2">
          <Button
            variant="secondary" size="sm"
            onClick={() => set({ extraFees: [...value.extraFees, { categoryName: '', amount: 0 }] })}
          >
            <Plus size={14} /> Ajouter un frais
          </Button>
          <Input
            value={newCat}
            onChange={(e) => setNewCat(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); createCategory(); } }}
            placeholder="Nouvelle catégorie…"
            className="max-w-[200px] h-9"
          />
          <Button variant="secondary" size="sm" onClick={createCategory} disabled={!newCat.trim()}>
            <Plus size={14} /> Créer la catégorie
          </Button>
        </div>
      </div>

      {/* Conversion euro */}
      <EuroConverter
        euro={value.euroAmount}
        rate={value.exchangeRate}
        onChange={(euroAmount, exchangeRate) => set({ euroAmount, exchangeRate })}
      />

      {/* Totaux */}
      <div className="rounded-xl border-2 border-gold/30 bg-gold/5 p-3 grid grid-cols-2 sm:grid-cols-4 gap-3 text-sm">
        <div><p className="text-xs text-text-muted">Total H.T</p><p className="font-bold tabular">{formatCurrency(totalHt)}</p></div>
        <div><p className="text-xs text-text-muted">Total après TVA</p><p className="font-bold tabular text-gold-dark">{formatCurrency(t.ttc)}</p></div>
        <div><p className="text-xs text-text-muted">Total des frais</p><p className="font-bold tabular text-caramel">{formatCurrency(t.fees)}</p></div>
        <div><p className="text-xs text-text-muted">Coût total final</p><p className="text-lg font-bold tabular text-rose-deep">{formatCurrency(t.grand)}</p></div>
      </div>
    </section>
  );
}

/* --------------------------------------------------------------------------
 * Affichage en lecture seule (détail d'un achat).
 * ------------------------------------------------------------------------ */
export function PurchaseCostsDetails({ purchase: p }: { purchase: Purchase }) {
  const fees = purchaseFeesTotal(p);
  const row = (label: string, value: string, cls = '') => (
    <div className="flex justify-between gap-3 py-1 border-b border-gold/10 last:border-0">
      <span className="text-text-muted">{label}</span><span className={`font-semibold tabular ${cls}`}>{value}</span>
    </div>
  );
  return (
    <div className="rounded-xl border border-gold/15 p-3 text-sm">
      <p className="text-[11px] font-bold uppercase tracking-wider text-text-muted mb-2">TVA, frais &amp; devise</p>
      {row('Total H.T', formatCurrency(p.totalHt ?? p.totalAmount))}
      {p.tvaEnabled && row(`TVA (${p.tvaRate ?? 0} %)`, formatCurrency(p.tvaAmount ?? 0))}
      {row(p.tvaEnabled ? 'Total T.T.C (fournisseur)' : 'Total fournisseur', formatCurrency(p.totalAmount), 'text-gold-dark')}
      {(p.customsFees ?? 0) > 0 && row('Frais de douane', formatCurrency(p.customsFees ?? 0))}
      {(p.transitFees ?? 0) > 0 && row('Frais transitaire', formatCurrency(p.transitFees ?? 0))}
      {(p.extraFees ?? []).map((f, i) => row(`Frais supp. — ${f.categoryName}`, formatCurrency(f.amount)))}
      {fees > 0 && row('Total des frais', formatCurrency(fees), 'text-caramel')}
      {row('Coût total final', formatCurrency(purchaseGrandTotal(p)), 'text-rose-deep')}
      {(p.euroAmount ?? 0) > 0 && row(
        'Montant en euro',
        `${(p.euroAmount ?? 0).toLocaleString('fr-FR')} € × ${p.exchangeRate ?? 0} = ${formatCurrency((p.euroAmount ?? 0) * (p.exchangeRate ?? 0))}`
      )}
    </div>
  );
}

/* --------------------------------------------------------------------------
 * Bloc récapitulatif pour la caisse et les rapports : TVA, douane,
 * transitaire et frais supplémentaires totalisés par catégorie.
 * ------------------------------------------------------------------------ */
export function PurchaseFeesSummaryCard({ purchases, title = "Frais d'achat" }: { purchases: Purchase[]; title?: string }) {
  const s = useMemo(() => summarizePurchaseFees(purchases), [purchases]);
  const withFees = purchases.filter((p) => purchaseFeesTotal(p) > 0 || p.tvaEnabled);
  const tile = (label: string, v: number, cls = 'text-text-primary') => (
    <div className="rounded-xl border border-gold/15 bg-gradient-card p-3">
      <p className="text-xs text-text-muted">{label}</p>
      <p className={`text-lg font-bold tabular ${cls}`}>{formatCurrency(v)}</p>
    </div>
  );
  return (
    <div className="rounded-2xl border border-gold/20 p-4 space-y-3">
      <h3 className="font-display font-semibold text-text-primary flex items-center gap-2">
        <Receipt size={16} className="text-gold" /> {title}
      </h3>
      <div className="grid grid-cols-2 md:grid-cols-5 gap-2.5">
        {tile('TVA sur achats', s.tva)}
        {tile('Frais de douane', s.customs)}
        {tile('Frais transitaire', s.transit)}
        {tile('Frais supplémentaires', s.extra)}
        {tile('Total des frais', s.total, 'text-rose-deep')}
      </div>
      <div>
        <p className="text-[11px] font-bold uppercase tracking-wider text-text-muted mb-1.5">Frais supplémentaires par catégorie</p>
        {s.byCategory.length === 0 ? (
          <p className="text-sm text-text-muted">Aucun frais supplémentaire sur la période.</p>
        ) : (
          <table className="w-full text-sm">
            <thead><tr className="text-left text-xs text-text-muted"><th className="py-1">Catégorie</th><th>Nb</th><th className="text-right">Total</th></tr></thead>
            <tbody>
              {s.byCategory.map((c) => (
                <tr key={c.name} className="border-t border-gold/10">
                  <td className="py-1.5 font-medium">{c.name}</td>
                  <td className="tabular">{c.count}</td>
                  <td className="text-right font-bold tabular text-gold-dark">{formatCurrency(c.amount)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      {withFees.length > 0 && (
        <details className="text-sm">
          <summary className="cursor-pointer text-xs font-semibold text-text-secondary">
            Détail par facture ({withFees.length})
          </summary>
          <table className="w-full mt-2 text-xs">
            <thead>
              <tr className="text-left text-text-muted">
                <th className="py-1">Facture</th><th>Date</th><th className="text-right">TVA</th><th className="text-right">Douane</th>
                <th className="text-right">Transit.</th><th className="text-right">Supp.</th><th className="text-right">Coût final</th>
              </tr>
            </thead>
            <tbody>
              {withFees.map((p) => (
                <tr key={p.id} className="border-t border-gold/10">
                  <td className="py-1 font-medium">
                    {p.reference}
                    {(p.extraFees ?? []).length > 0 && (
                      <span className="block text-[10px] text-text-muted">
                        {(p.extraFees ?? []).map((f) => `${f.categoryName} ${formatCurrency(f.amount)}`).join(' · ')}
                      </span>
                    )}
                  </td>
                  <td>{p.date.slice(0, 10)}</td>
                  <td className="text-right tabular">{formatCurrency(p.tvaAmount ?? 0)}</td>
                  <td className="text-right tabular">{formatCurrency(p.customsFees ?? 0)}</td>
                  <td className="text-right tabular">{formatCurrency(p.transitFees ?? 0)}</td>
                  <td className="text-right tabular">{formatCurrency(p.extraFeesTotal ?? 0)}</td>
                  <td className="text-right tabular font-bold">{formatCurrency(purchaseGrandTotal(p))}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      )}
    </div>
  );
}
