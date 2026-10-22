import { useEffect, useMemo, useState } from 'react';
import { Box, PackageCheck, AlertTriangle, Factory } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { useStockStore } from '@/store/stockStore';
import { db } from '@/lib/db';
import type { BoxCapacity } from '@/types';
import type { ReadyVariant } from '@/lib/readyStock';

const r3 = (n: number) => Math.round((n || 0) * 1000) / 1000;

/** Une ligne de l'opération pour laquelle une boîte peut être demandée. */
export interface BoxRequest {
  key: string;
  productName: string;
  unit?: string;
  /** Produit (fiche technique) — deux lignes du même produit partagent son stock prêt. */
  ficheId?: string;
  /** Quantité demandée sur la ligne. */
  quantity: number;
  /** Variantes (boîtes) du stock prêt disponibles pour ce produit. */
  variants: ReadyVariant[];
}

export interface BoxChoice {
  /** Variante du stock prêt dans laquelle prendre ('' = sans boîte) ; absent si rien n'est prêt. */
  readyBoxId?: string;
  /** Quantité qui sera produite (après le stock prêt de la variante choisie). */
  toProduce: number;
  /** Boîte du stock pour la production ('' = sans boîte) et nombre de boîtes. */
  boxProductId: string;
  boxQuantity: number;
  /** Contenance de la boîte pour ce produit (mémorisée par la base). */
  boxCapacity?: number;
}

interface Props {
  open: boolean;
  title?: string;
  /** Texte d'introduction (production, livraison, caisse…). */
  intro?: string;
  requests: BoxRequest[];
  confirmLabel?: string;
  busy?: boolean;
  onCancel: () => void;
  onConfirm: (choices: Record<string, BoxChoice>) => void;
}

/**
 * Avant de créer une production, un bon de livraison ou une vente :
 *  · si le produit est prêt dans PLUSIEURS boîtes, l'utilisateur choisit
 *    laquelle prendre ;
 *  · si une quantité doit être produite, il choisit la boîte du stock (ou
 *    « sans boîte ») et le nombre de boîtes — elles seront déduites du stock.
 */
export function BoxChoiceDialog({
  open, title = 'Boîtes', intro, requests, confirmLabel = 'Confirmer', busy, onCancel, onConfirm,
}: Props) {
  const products = useStockStore((s) => s.products);
  const boxes = useMemo(
    () => products.filter((p) => p.isBox).sort((a, b) => a.name.localeCompare(b.name)),
    [products]
  );

  const [ready, setReady] = useState<Record<string, string | undefined>>({});
  const [box, setBox] = useState<Record<string, string>>({});
  const [qty, setQty] = useState<Record<string, string>>({});
  /** Contenance saisie (unités du produit par boîte). */
  const [cap, setCap] = useState<Record<string, string>>({});
  /** Contenances mémorisées, la plus récente d'abord. */
  const [saved, setSaved] = useState<BoxCapacity[]>([]);

  const savedCap = (ficheId: string | undefined, boxId: string) =>
    saved.find((c) => c.ficheTechnicId === ficheId && c.boxProductId === boxId)?.capacity;

  // à chaque ouverture : variante la plus fournie ; boîte et contenance de la
  // dernière opération du produit
  useEffect(() => {
    if (!open) return;
    const r: Record<string, string | undefined> = {};
    requests.forEach((q) => { r[q.key] = q.variants[0]?.boxId; });
    setReady(r);
    setBox({});
    setQty({});
    setCap({});
    let alive = true;
    db.boxCapacities.list().then((rows) => {
      if (!alive) return;
      setSaved(rows);
      const b: Record<string, string> = {};
      const c: Record<string, string> = {};
      requests.forEach((q) => {
        const last = rows.find((x) => x.ficheTechnicId === q.ficheId && boxes.some((p) => p.id === x.boxProductId));
        if (!last) return;
        b[q.key] = last.boxProductId;
        c[q.key] = String(last.capacity);
      });
      setBox((cur) => ({ ...b, ...cur }));
      setCap((cur) => ({ ...c, ...cur }));
    }).catch(() => undefined);
    return () => { alive = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  /** Nombre de boîtes : saisi, sinon quantité ÷ contenance (arrondi au supérieur). */
  const boxCount = (key: string, toProduce: number) => {
    if (qty[key] !== undefined && qty[key] !== '') return Math.max(0, Number(qty[key]) || 0);
    const c = Number(cap[key]) || 0;
    return c > 0 && toProduce > 0 ? Math.ceil(toProduce / c - 1e-9) : 0;
  };

  const chooseBox = (q: BoxRequest, id: string) => {
    setBox((b) => ({ ...b, [q.key]: id }));
    const c = id ? savedCap(q.ficheId, id) : undefined;
    setCap((x) => ({ ...x, [q.key]: c ? String(c) : '' }));
    setQty((x) => ({ ...x, [q.key]: '' }));
  };

  /** Quantité produite par ligne, comme la base : stock prêt de la variante d'abord. */
  const plan = useMemo(() => {
    const used = new Map<string, number>();
    return requests.map((q) => {
      const vid = ready[q.key];
      const variant = q.variants.find((v) => v.boxId === vid);
      const vkey = `${q.ficheId ?? q.key}:${vid ?? ''}`;
      const avail = variant ? Math.max(0, variant.ready - (used.get(vkey) ?? 0)) : 0;
      const fromReady = r3(Math.min(q.quantity, avail));
      used.set(vkey, (used.get(vkey) ?? 0) + fromReady);
      return { q, fromReady, toProduce: r3(q.quantity - fromReady) };
    });
  }, [requests, ready]);

  /** Boîtes demandées au total, par boîte (plusieurs lignes peuvent prendre la même). */
  const boxShortage = useMemo(() => {
    const need = new Map<string, number>();
    plan.forEach(({ q, toProduce }) => {
      const b = box[q.key];
      if (!b || toProduce <= 0.0005) return;
      need.set(b, (need.get(b) ?? 0) + boxCount(q.key, toProduce));
    });
    const short: string[] = [];
    need.forEach((n, id) => {
      const p = boxes.find((x) => x.id === id);
      if (p && n > p.currentQuantity + 0.0005) short.push(`${p.name} (stock ${p.currentQuantity}, demandé ${n})`);
    });
    return short;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [plan, box, qty, cap, boxes]);

  const missingQty = plan.some(({ q, toProduce }) => toProduce > 0.0005 && box[q.key] && !(boxCount(q.key, toProduce) > 0));

  const confirm = () => {
    const out: Record<string, BoxChoice> = {};
    plan.forEach(({ q, toProduce }) => {
      const b = toProduce > 0.0005 ? box[q.key] ?? '' : '';
      out[q.key] = {
        readyBoxId: ready[q.key],
        toProduce,
        boxProductId: b,
        boxQuantity: b ? boxCount(q.key, toProduce) : 0,
        boxCapacity: b && Number(cap[q.key]) > 0 ? Number(cap[q.key]) : undefined,
      };
    });
    onConfirm(out);
  };

  return (
    <Modal
      open={open}
      onClose={busy ? () => {} : onCancel}
      title={title}
      size="md"
      footer={
        <div className="flex justify-end gap-3">
          <Button variant="secondary" onClick={onCancel} disabled={busy}>Annuler</Button>
          <Button variant="gold" onClick={confirm} disabled={busy || boxShortage.length > 0 || missingQty}>
            {busy ? 'Enregistrement…' : confirmLabel}
          </Button>
        </div>
      }
    >
      <div className="space-y-4">
        {intro && <p className="text-sm text-text-secondary">{intro}</p>}

        {plan.map(({ q, fromReady, toProduce }) => {
          const u = q.unit ? ` ${q.unit}` : '';
          const selectedBox = box[q.key] ?? '';
          const boxProduct = boxes.find((b) => b.id === selectedBox);
          const count = boxCount(q.key, toProduce);
          const manual = qty[q.key] !== undefined && qty[q.key] !== '';
          return (
            <section key={q.key} className="rounded-2xl border border-gold/15 bg-vanilla/30 p-4 space-y-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h4 className="font-display font-semibold text-text-primary text-sm">{q.productName}</h4>
                <span className="text-xs font-bold tabular text-gold-dark">{q.quantity}{u}</span>
              </div>

              {/* Stock prêt dans plusieurs boîtes : choisir laquelle */}
              {q.variants.length > 1 && (
                <div className="space-y-2">
                  <p className="flex items-center gap-1.5 text-xs font-semibold text-caramel">
                    <AlertTriangle size={14} /> Ce produit est prêt dans plusieurs boîtes : choisissez laquelle livrer / vendre.
                  </p>
                  <div className="grid gap-2 sm:grid-cols-2">
                    {q.variants.map((v) => (
                      <label
                        key={v.boxId || 'none'}
                        className={`flex cursor-pointer items-center justify-between gap-2 rounded-xl border px-3 py-2 text-sm transition-colors ${
                          ready[q.key] === v.boxId ? 'border-gold bg-gold/10' : 'border-gold/15 hover:border-gold/40'
                        }`}
                      >
                        <span className="flex items-center gap-2">
                          <input
                            type="radio"
                            name={`ready-${q.key}`}
                            checked={ready[q.key] === v.boxId}
                            onChange={() => setReady((r) => ({ ...r, [q.key]: v.boxId }))}
                          />
                          <Box size={14} className="text-gold" /> {v.boxName}
                        </span>
                        <span className="tabular text-xs text-pistachio font-bold">{v.ready}{u} prêt</span>
                      </label>
                    ))}
                  </div>
                </div>
              )}
              {q.variants.length === 1 && (
                <p className="flex items-center gap-1.5 text-xs text-text-muted">
                  <PackageCheck size={14} className="text-pistachio" />
                  Stock prêt : {q.variants[0].ready}{u} — {q.variants[0].boxName}
                </p>
              )}
              {fromReady > 0 && (
                <p className="text-xs text-pistachio">{fromReady}{u} sortiront du stock prêt.</p>
              )}

              {/* Quantité à produire : boîte du stock */}
              {toProduce > 0.0005 ? (
                <div className="space-y-2 rounded-xl border border-gold/15 bg-gradient-card p-3">
                  <p className="flex items-center gap-1.5 text-xs font-semibold text-text-secondary">
                    <Factory size={14} className="text-gold" /> {toProduce}{u} seront produits — dans quelle boîte ?
                  </p>
                  <div className="grid gap-2">
                    <select
                      value={selectedBox}
                      onChange={(e) => chooseBox(q, e.target.value)}
                      className="h-10 w-full rounded-xl border border-[--border-input] bg-[--surface-input] px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-gold/40"
                    >
                      <option value="">Sans boîte</option>
                      {boxes.map((b) => (
                        <option key={b.id} value={b.id} disabled={b.currentQuantity <= 0}>
                          {b.name} — stock {b.currentQuantity}{b.unit ? ` ${b.unit}` : ''}
                        </option>
                      ))}
                    </select>
                    {selectedBox && (
                      <div className="grid gap-2 sm:grid-cols-2">
                        <label className="space-y-1 text-[11px] font-semibold text-text-secondary">
                          <span>Contenance : {q.unit || 'unités'} par boîte</span>
                          <Input
                            type="number" step="any" min={0}
                            placeholder="ex. 12"
                            value={cap[q.key] ?? ''}
                            onChange={(e) => {
                              setCap((x) => ({ ...x, [q.key]: e.target.value }));
                              setQty((x) => ({ ...x, [q.key]: '' }));
                            }}
                          />
                        </label>
                        <label className="space-y-1 text-[11px] font-semibold text-text-secondary">
                          <span>Nombre de boîtes {manual ? '(modifié)' : '(automatique)'}</span>
                          <Input
                            type="number" step="any" min={0}
                            placeholder="Nb de boîtes"
                            value={manual ? qty[q.key] : count ? String(count) : ''}
                            onChange={(e) => setQty((x) => ({ ...x, [q.key]: e.target.value }))}
                          />
                        </label>
                      </div>
                    )}
                  </div>
                  {selectedBox && Number(cap[q.key]) > 0 && (
                    <p className="text-[11px] text-text-muted">
                      {toProduce}{u} ÷ {Number(cap[q.key])} par boîte = {Math.ceil(toProduce / Number(cap[q.key]) - 1e-9)} boîte(s)
                      {savedCap(q.ficheId, selectedBox) === Number(cap[q.key]) ? ' · contenance mémorisée' : ' · sera mémorisée'}
                      {manual && (
                        <button type="button" className="ml-2 text-gold-dark hover:underline" onClick={() => setQty((x) => ({ ...x, [q.key]: '' }))}>
                          recalculer
                        </button>
                      )}
                    </p>
                  )}
                  {boxes.length === 0 && (
                    <p className="text-[11px] text-text-muted">
                      Aucune boîte dans la gestion de stock : activez « Ce produit est une boîte » sur un produit.
                    </p>
                  )}
                  {boxProduct && count > boxProduct.currentQuantity && (
                    <p className="text-[11px] font-semibold text-rose-deep">Stock de boîtes insuffisant.</p>
                  )}
                </div>
              ) : (
                q.variants.length === 0 && <p className="text-xs text-text-muted">Rien à produire.</p>
              )}
            </section>
          );
        })}

        {boxShortage.length > 0 && (
          <div className="rounded-xl border border-rose-deep/25 bg-rose-deep/10 p-3 text-xs text-rose-deep">
            Stock de boîtes insuffisant : {boxShortage.join(' · ')}
          </div>
        )}
        {missingQty && (
          <p className="text-xs font-semibold text-rose-deep">Indiquez la contenance ou le nombre de boîtes pour chaque boîte choisie.</p>
        )}
      </div>
    </Modal>
  );
}
