import type { StateCreator } from 'zustand';

/* ============================================================================
 *  RELECTURES SANS RE-RENDU
 * ----------------------------------------------------------------------------
 *  Chaque relecture de la base (démarrage, retour sur l'onglet, après une
 *  écriture) renvoie des objets NEUFS, même quand rien n'a changé : tous les
 *  écrans et tous leurs calculs (useMemo) repartaient de zéro.
 *
 *  `stable()` garde l'ancien objet d'une ligne identique et l'ancienne liste
 *  quand aucune ligne n'a changé : les écrans ne se redessinent que pour ce qui
 *  a réellement bougé.
 * ========================================================================== */

type Row = { id?: unknown };

const sameJson = (a: unknown, b: unknown) => {
  try { return JSON.stringify(a) === JSON.stringify(b); } catch { return false; }
};

function reconcileList(prev: unknown, next: unknown[]): unknown[] {
  if (!Array.isArray(prev) || prev.length === 0) return next;
  const byId = new Map<unknown, unknown>();
  prev.forEach((r) => { if (r && typeof r === 'object' && (r as Row).id !== undefined) byId.set((r as Row).id, r); });
  if (byId.size === 0) return sameJson(prev, next) ? prev : next;
  let changed = prev.length !== next.length;
  const out = next.map((r, i) => {
    const id = r && typeof r === 'object' ? (r as Row).id : undefined;
    const old = id !== undefined ? byId.get(id) : undefined;
    if (old !== undefined && sameJson(old, r)) {
      if (prev[i] !== old) changed = true;
      return old;
    }
    changed = true;
    return r;
  });
  return changed ? out : prev;
}

function reconcile<T extends object>(prev: T, patch: Partial<T>): Partial<T> {
  const out: Record<string, unknown> = {};
  Object.entries(patch).forEach(([k, v]) => {
    const old = (prev as Record<string, unknown>)[k];
    if (Array.isArray(v)) out[k] = reconcileList(old, v);
    else if (v && typeof v === 'object' && old && typeof old === 'object' && sameJson(old, v)) out[k] = old;
    else out[k] = v;
  });
  return out as Partial<T>;
}

/** Middleware zustand : `create<S>()(stable((set, get) => ({ ... })))`. */
export const stable = <S extends object>(init: StateCreator<S, [], []>): StateCreator<S, [], []> =>
  (set, get, api) => {
    const stableSet = ((partial: S | Partial<S> | ((s: S) => S | Partial<S>), replace?: boolean) => {
      const prev = get();
      const patch = typeof partial === 'function' ? (partial as (s: S) => Partial<S>)(prev) : partial;
      if (replace) return (set as (p: S, r: true) => void)(patch as S, true);
      const next = reconcile(prev, patch as Partial<S>);
      // rien n'a changé : aucun abonné n'est réveillé
      if (Object.entries(next).every(([k, v]) => (prev as Record<string, unknown>)[k] === v)) return;
      set(next);
    }) as typeof set;
    return init(stableSet, get, api);
  };
