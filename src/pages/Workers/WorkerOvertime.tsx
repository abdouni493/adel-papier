import { useMemo, useState } from 'react';
import { Clock, Plus, Pencil, Trash2, Printer, CheckCircle2, Timer, Coins, EyeOff, Eye, Fingerprint, RefreshCw } from 'lucide-react';
import { Input, Textarea } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { EmptyState } from '@/components/ui/EmptyState';
import { useWorkerStore, overtimeHours } from '@/store/workerStore';
import { useSettingsStore } from '@/store/settingsStore';
import { useAttendanceStore } from '@/store/attendanceStore';
import { useAttendanceSync } from '@/hooks/useAttendanceSync';
import { formatCurrency, formatDate, todayISO } from '@/lib/utils';
import { printOvertimeReceipt } from '@/lib/documents';
import { toast } from '@/components/ui/Toast';
import type { Worker, WorkerOvertime as Overtime } from '@/types';

const pad = (n: number) => String(n).padStart(2, '0');

/** Splits "HH:mm" into hours and minutes. */
function parseTime(v: string): { h: number; m: number } {
  const [h, m] = v.split(':').map((x) => Number(x) || 0);
  return { h: h || 0, m: m || 0 };
}

/**
 * Heures supplémentaires d'un employé.
 *
 * L'utilisateur saisit l'heure de fin du travail normal et l'heure de fin des
 * heures supplémentaires : la durée puis le montant à payer sont calculés
 * automatiquement (durée × taux horaire), avec possibilité de corriger le
 * total à la main.
 *
 * Les heures sup. de la pointeuse sont créées automatiquement : elles
 * commencent à la fin du travail + le délai des paramètres (16:00 → 16:20).
 */
export function WorkerOvertime({ worker }: { worker: Worker }) {
  const workers = useWorkerStore((s) => s.workers);
  const { addOvertime, updateOvertime, deleteOvertime, setOvertimeExcluded } = useWorkerStore();
  const { syncing, resync } = useAttendanceSync(worker.id);
  const graceMin = useAttendanceStore((s) => s.settings.minOvertimeMin);
  const settings = useSettingsStore((s) => s.settings);
  const current = workers.find((w) => w.id === worker.id) || worker;
  const overtimes = useMemo(
    () => [...(current.overtimes ?? [])].sort((a, b) => b.date.localeCompare(a.date)),
    [current.overtimes]
  );

  const [editingId, setEditingId] = useState<string | null>(null);
  const [date, setDate] = useState(todayISO());
  const [workEnd, setWorkEnd] = useState('17:00');
  const [overtimeEnd, setOvertimeEnd] = useState('20:00');
  const [rate, setRate] = useState<number>(0);
  const [amount, setAmount] = useState<number>(0);
  const [amountEdited, setAmountEdited] = useState(false);
  const [description, setDescription] = useState('');
  const [saving, setSaving] = useState(false);
  const [deleteId, setDeleteId] = useState<string | null>(null);

  const a = parseTime(workEnd);
  const b = parseTime(overtimeEnd);
  const hours = overtimeHours(a.h, a.m, b.h, b.m);
  const computedAmount = Math.round(hours * (Number(rate) || 0) * 100) / 100;
  const effectiveAmount = amountEdited ? Number(amount) || 0 : computedAmount;

  const totals = useMemo(() => {
    const active = overtimes.filter((o) => !o.excluded);
    const unpaid = active.filter((o) => !o.isPaid);
    return {
      hours: active.reduce((s, o) => s + o.hours, 0),
      amount: active.reduce((s, o) => s + o.amount, 0),
      unpaidHours: unpaid.reduce((s, o) => s + o.hours, 0),
      unpaidAmount: unpaid.reduce((s, o) => s + o.amount, 0),
      unpaidCount: unpaid.length,
    };
  }, [overtimes]);

  const resetForm = () => {
    setEditingId(null); setDate(todayISO()); setWorkEnd('17:00'); setOvertimeEnd('20:00');
    setRate(0); setAmount(0); setAmountEdited(false); setDescription('');
  };

  const startEdit = (o: Overtime) => {
    setEditingId(o.id);
    setDate(o.date);
    setWorkEnd(`${pad(o.workEndHour)}:${pad(o.workEndMinute)}`);
    setOvertimeEnd(`${pad(o.overtimeEndHour)}:${pad(o.overtimeEndMinute)}`);
    setRate(o.hourlyRate);
    setAmount(o.amount);
    setAmountEdited(true);
    setDescription(o.description || '');
  };

  const handleSave = async () => {
    if (hours <= 0) { toast.error("La fin des heures supplémentaires doit être après la fin du travail"); return; }
    if (effectiveAmount <= 0) { toast.error('Le montant à payer doit être supérieur à 0'); return; }
    setSaving(true);
    try {
      const payload = {
        workerId: worker.id,
        date,
        workEndHour: a.h, workEndMinute: a.m,
        overtimeEndHour: b.h, overtimeEndMinute: b.m,
        hours: Math.round(hours * 100) / 100,
        hourlyRate: Number(rate) || 0,
        amount: effectiveAmount,
        description,
      };
      if (editingId) {
        await updateOvertime(editingId, payload);
        toast.success('Heures supplémentaires modifiées');
      } else {
        await addOvertime(payload);
        toast.success('Heures supplémentaires enregistrées — à régler depuis « Paie »');
      }
      resetForm();
    } catch {
      /* store already showed the error */
    } finally {
      setSaving(false);
    }
  };

  const printOne = (o: Overtime) => {
    printOvertimeReceipt(
      {
        workerName: current.fullName,
        paidAt: o.paidAt || new Date().toISOString(),
        amount: o.amount,
        lines: [{
          date: o.date,
          from: `${pad(o.workEndHour)}:${pad(o.workEndMinute)}`,
          to: `${pad(o.overtimeEndHour)}:${pad(o.overtimeEndMinute)}`,
          hours: o.hours,
          rate: o.hourlyRate,
          amount: o.amount,
          description: o.description,
        }],
      },
      settings
    );
  };

  return (
    <div className="space-y-5">
      {/* Summary */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <Tile label="Heures totales" value={`${totals.hours.toFixed(2)} h`} icon={<Timer size={15} />} />
        <Tile label="Montant total" value={formatCurrency(totals.amount)} color="text-gold-dark" icon={<Coins size={15} />} />
        <Tile label="Heures non payées" value={`${totals.unpaidHours.toFixed(2)} h`} color="text-caramel" icon={<Clock size={15} />} />
        <Tile label="Reste à payer" value={formatCurrency(totals.unpaidAmount)} color="text-rose-deep" icon={<Coins size={15} />} />
      </div>

      <div className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-pistachio/25 bg-pistachio/5 px-3 py-2 text-xs text-text-secondary">
        <span className="flex items-center gap-1.5">
          <Fingerprint size={13} className="text-pistachio" />
          {current.badgePin
            ? `Calcul automatique depuis la pointeuse : heures sup. comptées après la fin du travail + ${graceMin} min.`
            : "Sans N° pointeuse : seules les heures saisies à la main sont comptées."}
        </span>
        {current.badgePin && (
          <Button size="sm" variant="ghost" onClick={() => void resync()} disabled={syncing}>
            <RefreshCw size={13} className={syncing ? 'animate-spin' : ''} /> Recalculer
          </Button>
        )}
      </div>

      {/* Form */}
      <div className="rounded-2xl border border-gold/20 bg-vanilla/30 p-4 space-y-3">
        <h4 className="font-display font-semibold text-text-primary text-sm flex items-center gap-2">
          <Plus size={16} className="text-gold" />
          {editingId ? 'Modifier les heures supplémentaires' : 'Nouvelles heures supplémentaires'}
        </h4>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <Input label="Date" type="date" value={date} onChange={(e) => setDate(e.target.value)} />
          <Input
            label="Heure de fin du travail" type="time"
            value={workEnd} onChange={(e) => setWorkEnd(e.target.value)}
          />
          <Input
            label="Heure de fin des heures sup." type="time"
            value={overtimeEnd} onChange={(e) => setOvertimeEnd(e.target.value)}
          />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div className="rounded-xl border border-gold/15 bg-gradient-card px-3.5 py-2.5">
            <p className="text-[10px] uppercase tracking-wide text-text-muted">Durée calculée</p>
            <p className="text-lg font-bold tabular text-gold-dark">{hours.toFixed(2)} h</p>
          </div>
          <Input
            label="Prix d'une heure (DA)" type="number" step="any" min={0}
            value={rate}
            onChange={(e) => { setRate(Number(e.target.value)); setAmountEdited(false); }}
          />
          <div>
            <Input
              label="Total à payer (DA)" type="number" step="any" min={0}
              value={effectiveAmount}
              onChange={(e) => { setAmount(Number(e.target.value)); setAmountEdited(true); }}
            />
            {amountEdited && computedAmount > 0 && Math.abs(effectiveAmount - computedAmount) > 0.001 && (
              <button
                type="button"
                onClick={() => setAmountEdited(false)}
                className="text-[10px] text-gold-dark hover:underline mt-1"
              >
                Revenir au calcul automatique ({formatCurrency(computedAmount)})
              </button>
            )}
          </div>
        </div>

        <Textarea
          label="Motif / description (optionnel)"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Ex : coulage de dalle urgent, chargement camion…"
          rows={2}
        />

        <div className="flex items-center justify-between rounded-xl border border-gold/25 bg-gold/5 px-4 py-2.5">
          <span className="text-xs text-text-muted">
            {hours.toFixed(2)} h × {formatCurrency(Number(rate) || 0)}
          </span>
          <span className="text-lg font-bold tabular text-gold-dark">{formatCurrency(effectiveAmount)}</span>
        </div>

        <div className="flex justify-end gap-2">
          {editingId && <Button variant="secondary" onClick={resetForm}>Annuler la modification</Button>}
          <Button variant="gold" onClick={handleSave} disabled={saving}>
            {saving ? 'Enregistrement…' : editingId ? 'Mettre à jour' : 'Enregistrer'}
          </Button>
        </div>
      </div>

      {/* History */}
      <div>
        <h4 className="text-sm font-semibold text-text-secondary mb-2 flex items-center gap-2">
          <Clock size={15} className="text-gold" /> Historique ({overtimes.length})
        </h4>
        {overtimes.length === 0 ? (
          <EmptyState message="Aucune heure supplémentaire enregistrée" icon={<Clock size={28} />} />
        ) : (
          <div className="overflow-x-auto rounded-xl border border-gold/15">
            <table className="w-full text-sm">
              <thead className="bg-vanilla/60 text-text-secondary">
                <tr>
                  <th className="text-left px-3 py-2">Date</th>
                  <th className="text-center px-3 py-2">Horaire</th>
                  <th className="text-center px-3 py-2">Durée</th>
                  <th className="text-right px-3 py-2">Taux</th>
                  <th className="text-right px-3 py-2">Montant</th>
                  <th className="text-center px-3 py-2">Statut</th>
                  <th className="text-center px-3 py-2">Actions</th>
                </tr>
              </thead>
              <tbody>
                {overtimes.map((o) => (
                  <tr key={o.id} className={`border-t border-gold/10 ${o.excluded ? 'opacity-50' : ''}`}>
                    <td className="px-3 py-2 text-xs">
                      {formatDate(o.date)}
                      {o.source === 'device' && <Fingerprint size={11} className="inline ml-1 text-pistachio" aria-label="Pointeuse" />}
                    </td>
                    <td className="px-3 py-2 text-center text-xs tabular">
                      {pad(o.workEndHour)}:{pad(o.workEndMinute)} → {pad(o.overtimeEndHour)}:{pad(o.overtimeEndMinute)}
                    </td>
                    <td className="px-3 py-2 text-center tabular font-semibold">{o.hours.toFixed(2)} h</td>
                    <td className="px-3 py-2 text-right tabular text-text-muted">{formatCurrency(o.hourlyRate)}</td>
                    <td className="px-3 py-2 text-right tabular font-bold text-gold-dark">{formatCurrency(o.amount)}</td>
                    <td className="px-3 py-2 text-center">
                      {o.isPaid ? (
                        <Badge variant="success" className="gap-1"><CheckCircle2 size={10} /> Payée</Badge>
                      ) : o.excluded ? (
                        <Badge variant="neutral">Exclue</Badge>
                      ) : (
                        <Badge variant="warning">Non payée</Badge>
                      )}
                    </td>
                    <td className="px-3 py-2">
                      <div className="flex items-center justify-center gap-1">
                        <Button size="icon" variant="ghost" title="Imprimer" onClick={() => printOne(o)}>
                          <Printer size={14} />
                        </Button>
                        {!o.isPaid && (
                          <>
                            <Button
                              size="icon" variant="ghost"
                              title={o.excluded ? 'Réactiver (compter dans la paie)' : 'Exclure des calculs'}
                              onClick={() => void setOvertimeExcluded(o.id, !o.excluded)}
                            >
                              {o.excluded ? <Eye size={14} className="text-pistachio" /> : <EyeOff size={14} />}
                            </Button>
                            <Button size="icon" variant="ghost" title="Modifier" onClick={() => startEdit(o)}>
                              <Pencil size={14} />
                            </Button>
                            {/* une ligne de la pointeuse serait recréée : on l'exclut au lieu de la supprimer */}
                            {o.source !== 'device' && (
                              <Button size="icon" variant="ghost" title="Supprimer" onClick={() => setDeleteId(o.id)}>
                                <Trash2 size={14} className="text-rose-deep" />
                              </Button>
                            )}
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {totals.unpaidCount > 0 && (
          <p className="text-xs text-caramel mt-2.5 flex items-center gap-1.5">
            <Clock size={13} />
            {totals.unpaidCount} entrée(s) non payée(s) — {formatCurrency(totals.unpaidAmount)} à régler depuis
            le bouton « Paie » de la fiche employé.
          </p>
        )}
      </div>

      <ConfirmDialog
        open={!!deleteId}
        onClose={() => setDeleteId(null)}
        onConfirm={() => {
          if (deleteId) void deleteOvertime(worker.id, deleteId).then(() => toast.success('Entrée supprimée'));
        }}
        title="Supprimer les heures supplémentaires"
      />
    </div>
  );
}

function Tile({ label, value, color = 'text-text-primary', icon }: {
  label: string; value: string; color?: string; icon?: React.ReactNode;
}) {
  return (
    <div className="rounded-xl border border-gold/15 bg-vanilla/40 px-3 py-2.5">
      <p className="text-[10px] uppercase tracking-wide text-text-muted flex items-center gap-1">{icon}{label}</p>
      <p className={`text-sm font-bold tabular ${color} mt-0.5`}>{value}</p>
    </div>
  );
}
