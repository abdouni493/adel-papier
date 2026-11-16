import { useEffect, useState } from 'react';
import { Pencil, Trash2 } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import type { ActionItem } from '@/components/ui/ActionMenu';
import { useWorkerStore, overtimeHours } from '@/store/workerStore';
import { usePermissions } from '@/hooks/usePermissions';
import { formatCurrency } from '@/lib/utils';
import { toast } from '@/components/ui/Toast';
import type { Acompte, Absence, WorkerPaymentRecord, WorkerOvertime } from '@/types';

/* ============================================================================
 *  MODIFIER / SUPPRIMER une ligne de l'historique d'un employé
 * ----------------------------------------------------------------------------
 *  Acomptes, absences, paiements et heures sup. partagent la même fenêtre
 *  d'édition et la même confirmation de suppression. La caisse suit
 *  automatiquement (triggers SQL sur insert / update / delete).
 * ========================================================================== */

export type WorkerEntry =
  | { kind: 'acompte'; row: Acompte }
  | { kind: 'absence'; row: Absence }
  | { kind: 'payment'; row: WorkerPaymentRecord }
  | { kind: 'overtime'; row: WorkerOvertime };

const LABEL: Record<WorkerEntry['kind'], string> = {
  acompte: "l'acompte",
  absence: "l'absence",
  payment: 'le paiement',
  overtime: 'les heures supplémentaires',
};

const pad = (n: number) => String(n).padStart(2, '0');
const toHM = (t: string) => {
  const [h, m] = (t || '0:0').split(':').map(Number);
  return { h: h || 0, m: m || 0 };
};

/** Une ligne d'heures sup. issue de la pointeuse ou déjà payée n'est pas modifiable ici. */
export const isEditable = (e: WorkerEntry) =>
  e.kind !== 'overtime' || (!e.row.isPaid && e.row.source !== 'device');

/**
 * Gère l'état « modifier » / « supprimer » d'une liste d'entrées et fournit
 * les actions du menu trois points de chaque ligne.
 */
export function useWorkerEntryActions(workerId: string) {
  const { can } = usePermissions();
  const [editing, setEditing] = useState<WorkerEntry | null>(null);
  const [deleting, setDeleting] = useState<WorkerEntry | null>(null);

  const actions = (e: WorkerEntry): ActionItem[] => [
    {
      label: 'Modifier', icon: <Pencil size={15} />,
      hidden: !can('workers', 'edit') || !isEditable(e),
      onClick: () => setEditing(e),
    },
    {
      label: 'Supprimer', icon: <Trash2 size={15} />, danger: true,
      hidden: !can('workers', 'delete') || (e.kind === 'overtime' && e.row.source === 'device' && !e.row.isPaid),
      onClick: () => setDeleting(e),
    },
  ];

  const dialogs = (
    <>
      <WorkerEntryEditModal entry={editing} workerId={workerId} onClose={() => setEditing(null)} />
      <WorkerEntryDeleteDialog entry={deleting} workerId={workerId} onClose={() => setDeleting(null)} />
    </>
  );

  return { actions, dialogs };
}

function WorkerEntryDeleteDialog({ entry, workerId, onClose }: {
  entry: WorkerEntry | null; workerId: string; onClose: () => void;
}) {
  const { deleteAcompte, deleteAbsence, deletePayment, deleteOvertime } = useWorkerStore();

  const confirm = async () => {
    if (!entry) return;
    try {
      if (entry.kind === 'acompte') await deleteAcompte(workerId, entry.row.id);
      if (entry.kind === 'absence') await deleteAbsence(workerId, entry.row.id);
      if (entry.kind === 'payment') await deletePayment(workerId, entry.row.id);
      if (entry.kind === 'overtime') await deleteOvertime(workerId, entry.row.id);
      toast.success('Entrée supprimée');
    } catch { /* le store affiche déjà l'erreur */ }
  };

  const message = !entry ? '' : entry.kind === 'payment'
    ? 'Le paiement sera retiré de la caisse. Les heures sup. et retards qu’il réglait redeviennent « à régler ».'
    : entry.kind === 'acompte'
      ? "L'acompte sera retiré de la caisse."
      : `Supprimer définitivement ${LABEL[entry.kind]} ?`;

  return (
    <ConfirmDialog
      open={!!entry}
      onClose={onClose}
      onConfirm={() => void confirm()}
      title={entry ? `Supprimer ${LABEL[entry.kind]}` : ''}
      message={message}
    />
  );
}

function WorkerEntryEditModal({ entry, workerId, onClose }: {
  entry: WorkerEntry | null; workerId: string; onClose: () => void;
}) {
  const { updateAcompte, updateAbsence, updatePayment, updateOvertime } = useWorkerStore();
  const [date, setDate] = useState('');
  const [amount, setAmount] = useState(0);
  const [description, setDescription] = useState('');
  const [period, setPeriod] = useState('');
  const [from, setFrom] = useState('17:00');
  const [to, setTo] = useState('20:00');
  const [rate, setRate] = useState(0);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!entry) return;
    setDate(entry.row.date.slice(0, 10));
    setDescription(entry.row.description || '');
    if (entry.kind === 'acompte') setAmount(entry.row.amount);
    if (entry.kind === 'absence') setAmount(entry.row.cost);
    if (entry.kind === 'payment') { setAmount(entry.row.amount); setPeriod(entry.row.period || ''); }
    if (entry.kind === 'overtime') {
      const o = entry.row;
      setFrom(`${pad(o.workEndHour)}:${pad(o.workEndMinute)}`);
      setTo(`${pad(o.overtimeEndHour)}:${pad(o.overtimeEndMinute)}`);
      setRate(o.hourlyRate);
      setAmount(o.amount);
    }
  }, [entry]);

  const a = toHM(from);
  const b = toHM(to);
  const otHours = overtimeHours(a.h, a.m, b.h, b.m);
  // le montant des heures sup. se recalcule quand l'horaire ou le taux change
  const recalcOvertime = (f: string, t: string, r: number) => {
    const x = toHM(f); const y = toHM(t);
    setAmount(Math.round(overtimeHours(x.h, x.m, y.h, y.m) * (Number(r) || 0) * 100) / 100);
  };

  const lockedAmount = entry?.kind === 'payment' && entry.row.kind === 'overtime';

  const submit = async () => {
    if (!entry) return;
    if (!date) { toast.error('Date obligatoire'); return; }
    if (entry.kind !== 'absence' && !(amount > 0)) { toast.error('Montant invalide'); return; }
    if (entry.kind === 'absence' && amount < 0) { toast.error('Coût invalide'); return; }
    if (entry.kind === 'overtime' && otHours <= 0) {
      toast.error('La fin des heures supplémentaires doit être après la fin du travail'); return;
    }
    setSaving(true);
    try {
      if (entry.kind === 'acompte') await updateAcompte(entry.row.id, { date, amount, description });
      if (entry.kind === 'absence') await updateAbsence(entry.row.id, { date, cost: amount, description });
      if (entry.kind === 'payment') {
        await updatePayment(entry.row.id, lockedAmount
          ? { date, period, description }
          : { date, amount, period, description });
      }
      if (entry.kind === 'overtime') {
        await updateOvertime(entry.row.id, {
          workerId, date,
          workEndHour: a.h, workEndMinute: a.m, overtimeEndHour: b.h, overtimeEndMinute: b.m,
          hours: Math.round(otHours * 100) / 100, hourlyRate: Number(rate) || 0, amount, description,
        });
      }
      toast.success('Modification enregistrée');
      onClose();
    } catch { /* le store affiche déjà l'erreur */ } finally {
      setSaving(false);
    }
  };

  return (
    <Modal open={!!entry} onClose={onClose} title={entry ? `Modifier ${LABEL[entry.kind]}` : ''} size="sm">
      {entry && (
        <div className="space-y-3">
          <Input label="Date" type="date" value={date} onChange={(e) => setDate(e.target.value)} />

          {entry.kind === 'overtime' && (
            <div className="grid grid-cols-2 gap-3">
              <Input label="Fin du travail" type="time" value={from}
                onChange={(e) => { setFrom(e.target.value); recalcOvertime(e.target.value, to, rate); }} />
              <Input label="Fin des heures sup." type="time" value={to}
                onChange={(e) => { setTo(e.target.value); recalcOvertime(from, e.target.value, rate); }} />
              <Input label="Taux horaire (DA)" type="number" value={rate}
                onChange={(e) => { const r = Number(e.target.value); setRate(r); recalcOvertime(from, to, r); }} />
              <div className="rounded-lg border border-gold/15 bg-vanilla/40 px-3 py-2 text-sm">
                <p className="text-xs text-text-muted">Durée</p>
                <p className="font-bold tabular">{otHours.toFixed(2)} h</p>
              </div>
            </div>
          )}

          {entry.kind === 'payment' && (
            <Input label="Période" value={period} onChange={(e) => setPeriod(e.target.value)} />
          )}

          <Input
            label={entry.kind === 'absence' ? 'Coût (DA)' : 'Montant (DA)'}
            type="number"
            value={amount}
            disabled={lockedAmount}
            onChange={(e) => setAmount(Number(e.target.value))}
          />
          {lockedAmount && (
            <p className="text-xs text-text-muted">
              Montant d'un paiement d'heures sup. : supprimez-le puis réglez à nouveau pour le changer.
            </p>
          )}

          <Input
            label={entry.kind === 'absence' ? 'Motif' : 'Description'}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />

          {(entry.kind === 'acompte' || entry.kind === 'payment') && (
            <p className="text-xs text-text-muted">
              La caisse est mise à jour automatiquement ({formatCurrency(amount)}).
            </p>
          )}

          <div className="flex gap-2 pt-1">
            <Button variant="secondary" className="flex-1" onClick={onClose}>Annuler</Button>
            <Button variant="gold" className="flex-1" disabled={saving} onClick={() => void submit()}>{saving ? "Enregistrement…" : "Enregistrer"}</Button>
          </div>
        </div>
      )}
    </Modal>
  );
}
