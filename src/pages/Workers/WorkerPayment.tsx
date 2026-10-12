import { useEffect, useMemo, useState } from 'react';
import { Banknote, Clock, Printer, CheckCircle2, Trash2, Fingerprint, EyeOff, AlertTriangle } from 'lucide-react';
import { Select } from '@/components/ui/Select';
import { useAttendanceStore } from '@/store/attendanceStore';
import { useAttendanceSync } from '@/hooks/useAttendanceSync';
import {
  computeMonth, attendancePay, currentMonth, lastMonths, monthRange, monthLabel, fmtMin,
} from '@/lib/attendance';
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { Checkbox } from '@/components/ui/Switch';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { useWorkerStore } from '@/store/workerStore';
import { useSettingsStore } from '@/store/settingsStore';
import { useLanguage } from '@/hooks/useLanguage';
import { formatCurrency, formatDate, todayISO } from '@/lib/utils';
import { printOvertimeReceipt } from '@/lib/documents';
import { toast } from '@/components/ui/Toast';
import type { AttendancePunch, Worker } from '@/types';

const pad = (n: number) => String(n).padStart(2, '0');

/**
 * Paiement d'un employé.
 *  · onglet « Salaire » : salaire de base − acomptes − absences − retards
 *    cochés + heures sup. cochées (calculées depuis la pointeuse) ; chaque
 *    ligne peut être laissée pour plus tard ou exclue définitivement
 *    (réactivable depuis l'historique),
 *  · onglet « Heures supplémentaires » : liste des heures NON PAYÉES ; une fois
 *    réglées elles disparaissent de cet écran et apparaissent dans l'historique.
 */
export function WorkerPayment({ worker, onClose }: { worker: Worker; onClose: () => void }) {
  const { t, language } = useLanguage();
  const { paySalary, deletePayment, payOvertimes, setOvertimeExcluded, setLateStatus } = useWorkerStore();
  const { syncing } = useAttendanceSync(worker.id);
  const workers = useWorkerStore((s) => s.workers);
  const settings = useSettingsStore((s) => s.settings);
  const current = workers.find((w) => w.id === worker.id) || worker;

  const [tab, setTab] = useState<'salary' | 'overtime'>('salary');

  // ---- pointeuse ----
  const { settings: attSettings, ready: attReady, loadMeta, fetchPunches } = useAttendanceStore();
  const [attMonth, setAttMonth] = useState(currentMonth());
  const [useAtt, setUseAtt] = useState(!!current.badgePin);
  const [punches, setPunches] = useState<AttendancePunch[]>([]);
  useEffect(() => { void loadMeta(); }, [loadMeta]);
  useEffect(() => {
    if (!useAtt) return;
    const { from, to } = monthRange(attMonth);
    void fetchPunches(from, to, worker.id).then(setPunches).catch(() => setPunches([]));
  }, [useAtt, attMonth, worker.id, fetchPunches]);
  const attSum = useMemo(() => computeMonth(attMonth, punches, current, attSettings), [attMonth, punches, current, attSettings]);
  const attPay = useMemo(() => attendancePay(current, attSum, attSettings), [current, attSum, attSettings]);
  const applyAtt = useAtt && attReady;

  // ---- salary ----
  const base = applyAtt ? attPay.base : current.paymentAmount;
  const attDeduction = applyAtt ? attPay.absenceDeduction : 0;
  const totalAcomptes = useMemo(() => current.acomptes.reduce((s, a) => s + a.amount, 0), [current]);
  const totalAbsences = useMemo(() => current.absences.reduce((s, a) => s + a.cost, 0), [current]);

  // ---- heures sup. non payées / retards non réglés (pointeuse + saisies) ----
  const unpaidOvertimes = useMemo(
    () => (current.overtimes ?? []).filter((o) => !o.isPaid && !o.excluded).sort((a, b) => a.date.localeCompare(b.date)),
    [current.overtimes]
  );
  const pendingLates = useMemo(
    () => (current.lates ?? []).filter((l) => l.status === 'pending').sort((a, b) => a.date.localeCompare(b.date)),
    [current.lates]
  );
  const [otOn, setOtOn] = useState<Record<string, boolean>>({});
  const [lateOn, setLateOn] = useState<Record<string, boolean>>({});
  const otIncluded = unpaidOvertimes.filter((o) => otOn[o.id] ?? true);
  const lateIncluded = pendingLates.filter((l) => lateOn[l.id] ?? attSettings.deductLate);
  const otIncludedTotal = otIncluded.reduce((s, o) => s + o.amount, 0);
  const lateIncludedTotal = lateIncluded.reduce((s, l) => s + l.amount, 0);
  const lateIncludedMin = lateIncluded.reduce((s, l) => s + l.minutes, 0);

  const computed = Math.max(0, base - totalAcomptes - totalAbsences - attDeduction - lateIncludedTotal + otIncludedTotal);

  const [period, setPeriod] = useState('');
  const [net, setNet] = useState<number>(computed);
  // le net suit le calcul (mois de pointage, cases cochées…) ; reste modifiable ensuite
  useEffect(() => { setNet(computed); }, [computed]);
  const [date, setDate] = useState(todayISO());
  const [description, setDescription] = useState('');
  const [saving, setSaving] = useState(false);
  const [deletePaymentId, setDeletePaymentId] = useState<string | null>(null);

  // ---- overtime ----
  const [selected, setSelected] = useState<string[]>([]);
  const [otDate, setOtDate] = useState(todayISO());
  const selectedList = unpaidOvertimes.filter((o) => selected.includes(o.id));
  const selectedTotal = selectedList.reduce((s, o) => s + o.amount, 0);
  const selectedHours = selectedList.reduce((s, o) => s + o.hours, 0);

  const handlePaySalary = async () => {
    if (net <= 0) { toast.error('Montant invalide'); return; }
    setSaving(true);
    try {
      await paySalary(worker.id, {
        date,
        period: period || (applyAtt ? monthLabel(attMonth) : formatDate(date, language)),
        amount: Number(net),
        description: [
          description,
          applyAtt ? `Pointage ${monthLabel(attMonth)} : ${attSum.presentDays}/${attSum.workingDays} j présents, ${attSum.absentDays} absence(s)` : '',
          lateIncluded.length ? `Retards déduits : ${fmtMin(lateIncludedMin)} (${formatCurrency(lateIncludedTotal)})` : '',
          otIncluded.length ? `Heures sup. incluses : ${formatCurrency(otIncludedTotal)}` : '',
        ].filter(Boolean).join(' — '),
        kind: 'salary',
      }, { overtimeIds: otIncluded.map((o) => o.id), lateIds: lateIncluded.map((l) => l.id) });
      toast.success('Salaire payé — sortie de caisse enregistrée');
      onClose();
    } finally {
      setSaving(false);
    }
  };

  const handlePayOvertime = async () => {
    if (selected.length === 0) { toast.error('Sélectionnez au moins une ligne'); return; }
    setSaving(true);
    try {
      const snapshot = selectedList;
      await payOvertimes(worker.id, selected, otDate, `Heures supplémentaires — ${current.fullName}`);
      toast.success('Heures supplémentaires payées');
      // offer the receipt right away
      printOvertimeReceipt(
        {
          workerName: current.fullName,
          paidAt: new Date(otDate).toISOString(),
          amount: snapshot.reduce((s, o) => s + o.amount, 0),
          lines: snapshot.map((o) => ({
            date: o.date,
            from: `${pad(o.workEndHour)}:${pad(o.workEndMinute)}`,
            to: `${pad(o.overtimeEndHour)}:${pad(o.overtimeEndMinute)}`,
            hours: o.hours,
            rate: o.hourlyRate,
            amount: o.amount,
            description: o.description,
          })),
        },
        settings
      );
      setSelected([]);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="bg-vanilla/50 rounded-xl p-3 text-sm border border-gold/15 flex items-center justify-between">
        <div>
          <p className="font-semibold text-text-primary">{current.fullName}</p>
          <p className="text-text-muted text-xs">
            {current.paymentType === 'monthly' ? 'Salaire mensuel' : 'Salaire journalier'} ·{' '}
            {formatCurrency(current.paymentAmount)}
          </p>
        </div>
        {unpaidOvertimes.length > 0 && (
          <Badge variant="warning" className="gap-1">
            <Clock size={11} /> {unpaidOvertimes.length} h. sup. à payer
          </Badge>
        )}
      </div>

      {/* Tabs */}
      <div className="flex gap-2 border-b border-gold/15">
        {([
          ['salary', 'Salaire'],
          ['overtime', `Heures supplémentaires (${unpaidOvertimes.length})`],
        ] as const).map(([key, label]) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`pb-2 px-3 text-sm font-semibold border-b-2 transition-all ${
              tab === key ? 'border-gold text-gold-dark' : 'border-transparent text-text-muted'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === 'salary' ? (
        <div className="space-y-4">
          {/* Pointeuse */}
          <div className="rounded-xl border border-gold/20 bg-vanilla/40 p-3 space-y-2">
            <div className="flex flex-wrap items-end gap-3">
              <Checkbox
                checked={useAtt}
                onChange={setUseAtt}
                label="Calculer avec la pointeuse"
              />
              {useAtt && (
                <Select
                  value={attMonth}
                  onChange={(e) => { setAttMonth(e.target.value); setPeriod(monthLabel(e.target.value)); }}
                  options={lastMonths(12)}
                  className="max-w-[190px]"
                />
              )}
            </div>
            {useAtt && !attReady && (
              <p className="text-xs text-caramel">Exécutez supabase/parts/10_pointeuse.sql pour activer la pointeuse.</p>
            )}
            {applyAtt && (
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
                <Mini2 label="Présent" value={`${attSum.presentDays} / ${attSum.workingDays} j`} />
                <Mini2 label="Absences non justifiées" value={String(attSum.absentDays)} />
                <Mini2 label="Retards" value={`${attSum.lateCount} · ${fmtMin(attSum.lateMin)}`} />
                <Mini2 label="Heures sup. pointées" value={fmtMin(attSum.overtimeMin)} />
              </div>
            )}
            {applyAtt && !current.badgePin && (
              <p className="text-xs text-caramel flex items-center gap-1">
                <Fingerprint size={12} /> Cet employé n'a pas de N° pointeuse : tous les jours compteront comme absences.
              </p>
            )}
          </div>

          {syncing && <p className="text-[11px] text-text-muted">Calcul des heures sup. et retards depuis la pointeuse…</p>}

          {/* heures sup. non payées */}
          <PendingList
            title="Heures supplémentaires non payées"
            icon={<Clock size={14} className="text-pistachio" />}
            empty="Aucune heure supplémentaire en attente"
            hint={`Comptées à partir de la fin du travail + ${attSettings.minOvertimeMin} min. Cochées = ajoutées à ce paiement.`}
            rows={unpaidOvertimes.map((o) => ({
              id: o.id,
              on: otOn[o.id] ?? true,
              date: formatDate(o.date, language),
              detail: `${pad(o.workEndHour)}:${pad(o.workEndMinute)} → ${pad(o.overtimeEndHour)}:${pad(o.overtimeEndMinute)} · ${o.hours.toFixed(2)} h${o.source === 'device' ? ' · pointeuse' : ''}`,
              amount: `+ ${formatCurrency(o.amount)}`,
              tone: 'text-pistachio',
            }))}
            onToggle={(id, v) => setOtOn((m) => ({ ...m, [id]: v }))}
            onAll={(v) => setOtOn(Object.fromEntries(unpaidOvertimes.map((o) => [o.id, v])))}
            onExclude={(id) => void setOvertimeExcluded(id, true).then(() => toast.success("Exclue — réactivable depuis l'historique"))}
          />

          {/* retards non réglés */}
          <PendingList
            title="Retards non réglés"
            icon={<AlertTriangle size={14} className="text-caramel" />}
            empty="Aucun retard en attente"
            hint={`Calculés depuis l'heure de début de travail (tolérance ${attSettings.lateToleranceMin} min). Cochés = déduits de ce paiement.`}
            rows={pendingLates.map((l) => ({
              id: l.id,
              on: lateOn[l.id] ?? attSettings.deductLate,
              date: formatDate(l.date, language),
              detail: `prévu ${l.scheduleStart} · arrivé ${l.entryTime} · ${fmtMin(l.minutes)}`,
              amount: `- ${formatCurrency(l.amount)}`,
              tone: 'text-rose-deep',
            }))}
            onToggle={(id, v) => setLateOn((m) => ({ ...m, [id]: v }))}
            onAll={(v) => setLateOn(Object.fromEntries(pendingLates.map((l) => [l.id, v])))}
            onExclude={(id) => void setLateStatus(id, 'excluded').then(() => toast.success("Exclu — réactivable depuis l'historique"))}
          />

          <Input label="Période" value={period} onChange={(e) => setPeriod(e.target.value)} placeholder="Ex : Juin 2026" />

          <div className="rounded-xl border border-gold/15 bg-gradient-card p-4 space-y-2 text-sm">
            <Row
              label={applyAtt && current.paymentType === 'daily'
                ? `Salaire (${attSum.presentDays} j × ${formatCurrency(current.paymentAmount)})`
                : 'Salaire de base'}
              value={formatCurrency(base)}
            />
            <Row label="Acomptes déduits" value={`- ${formatCurrency(totalAcomptes)}`} color="text-caramel" />
            <Row label="Absences déduites" value={`- ${formatCurrency(totalAbsences)}`} color="text-rose-deep" />
            {applyAtt && current.paymentType !== 'daily' && (
              <Row
                label={`Absences pointeuse (${attSum.absentDays} j × ${formatCurrency(Math.round(attPay.dailyRate))})`}
                value={`- ${formatCurrency(attPay.absenceDeduction)}`} color="text-rose-deep"
              />
            )}
            {lateIncluded.length > 0 && (
              <Row
                label={`Retards déduits (${lateIncluded.length} · ${fmtMin(lateIncludedMin)})`}
                value={`- ${formatCurrency(lateIncludedTotal)}`} color="text-rose-deep"
              />
            )}
            {otIncluded.length > 0 && (
              <Row
                label={`Heures sup. incluses (${otIncluded.length} · ${otIncluded.reduce((s, o) => s + o.hours, 0).toFixed(2)} h)`}
                value={`+ ${formatCurrency(otIncludedTotal)}`} color="text-pistachio"
              />
            )}
            <div className="border-t border-gold/15 pt-2 flex justify-between font-bold">
              <span>Net à payer</span>
              <span className="tabular text-pistachio text-lg">{formatCurrency(computed)}</span>
            </div>
          </div>

          <Input
            label="Net à payer (modifiable)" type="number" step="any"
            value={net} onChange={(e) => setNet(Number(e.target.value))}
          />
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <Input label="Date" type="date" value={date} onChange={(e) => setDate(e.target.value)} />
            <Input label="Description" value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Optionnel" />
          </div>

          <div className="flex justify-end gap-3">
            <Button variant="secondary" onClick={onClose} disabled={saving}>Annuler</Button>
            <Button variant="gold" onClick={handlePaySalary} disabled={saving}>
              <Banknote size={16} /> {saving ? 'Enregistrement…' : 'Payer le salaire'}
            </Button>
          </div>
        </div>
      ) : (
        <div className="space-y-4">
          {unpaidOvertimes.length === 0 ? (
            <div className="rounded-2xl border border-pistachio/30 bg-pistachio/10 px-4 py-6 text-center">
              <CheckCircle2 size={30} className="text-pistachio mx-auto mb-2" />
              <p className="text-sm font-semibold text-pistachio">
                Toutes les heures supplémentaires de cet employé sont réglées.
              </p>
            </div>
          ) : (
            <>
              <div className="flex items-center justify-between">
                <p className="text-xs text-text-muted">
                  Sélectionnez les heures à régler — une fois payées elles n'apparaîtront plus ici.
                </p>
                <Button
                  size="sm" variant="secondary"
                  onClick={() =>
                    setSelected(selected.length === unpaidOvertimes.length ? [] : unpaidOvertimes.map((o) => o.id))
                  }
                >
                  {selected.length === unpaidOvertimes.length ? 'Tout désélectionner' : 'Tout sélectionner'}
                </Button>
              </div>

              <div className="overflow-x-auto rounded-xl border border-gold/15">
                <table className="w-full text-sm">
                  <thead className="bg-vanilla/60 text-text-secondary">
                    <tr>
                      <th className="px-3 py-2 w-10"></th>
                      <th className="text-left px-3 py-2">Date</th>
                      <th className="text-center px-3 py-2">Horaire</th>
                      <th className="text-center px-3 py-2">Durée</th>
                      <th className="text-right px-3 py-2">Taux</th>
                      <th className="text-right px-3 py-2">Montant</th>
                    </tr>
                  </thead>
                  <tbody>
                    {unpaidOvertimes.map((o) => (
                      <tr key={o.id} className="border-t border-gold/10">
                        <td className="px-3 py-2">
                          <Checkbox
                            checked={selected.includes(o.id)}
                            onChange={(v) =>
                              setSelected((prev) => (v ? [...prev, o.id] : prev.filter((x) => x !== o.id)))
                            }
                          />
                        </td>
                        <td className="px-3 py-2 text-xs">{formatDate(o.date, language)}</td>
                        <td className="px-3 py-2 text-center text-xs tabular">
                          {pad(o.workEndHour)}:{pad(o.workEndMinute)} → {pad(o.overtimeEndHour)}:{pad(o.overtimeEndMinute)}
                        </td>
                        <td className="px-3 py-2 text-center tabular">{o.hours.toFixed(2)} h</td>
                        <td className="px-3 py-2 text-right tabular text-text-muted">{formatCurrency(o.hourlyRate)}</td>
                        <td className="px-3 py-2 text-right tabular font-bold text-gold-dark">{formatCurrency(o.amount)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <Input label="Date du paiement" type="date" value={otDate} onChange={(e) => setOtDate(e.target.value)} className="max-w-[220px]" />

              <div className="flex items-center justify-between rounded-2xl border border-gold/25 bg-gold/5 px-4 py-3">
                <span className="text-xs text-text-muted">
                  {selected.length} ligne(s) · {selectedHours.toFixed(2)} h
                </span>
                <span className="text-xl font-bold tabular text-gold-dark">{formatCurrency(selectedTotal)}</span>
              </div>

              <div className="flex justify-end gap-3">
                <Button variant="secondary" onClick={onClose} disabled={saving}>Fermer</Button>
                <Button variant="gold" onClick={handlePayOvertime} disabled={saving || selected.length === 0}>
                  <Printer size={16} /> {saving ? 'Enregistrement…' : 'Payer & imprimer le reçu'}
                </Button>
              </div>
            </>
          )}
        </div>
      )}

      {/* Payment history */}
      {current.payments.length > 0 && (
        <div>
          <h4 className="text-sm font-semibold text-text-secondary mb-2">Historique des paiements</h4>
          <div className="overflow-x-auto rounded-xl border border-gold/15">
            <table className="w-full text-sm">
              <thead className="bg-vanilla/60 text-text-secondary">
                <tr>
                  <th className="text-left px-3 py-2">Date</th>
                  <th className="text-left px-3 py-2">Type</th>
                  <th className="text-left px-3 py-2">Période / motif</th>
                  <th className="text-right px-3 py-2">Montant</th>
                  <th className="text-center px-3 py-2"></th>
                </tr>
              </thead>
              <tbody>
                {[...current.payments].sort((a, b) => b.date.localeCompare(a.date)).map((p) => (
                  <tr key={p.id} className="border-t border-gold/10">
                    <td className="px-3 py-2 text-xs">{formatDate(p.date, language)}</td>
                    <td className="px-3 py-2">
                      <Badge variant={p.kind === 'overtime' ? 'warning' : 'info'}>
                        {p.kind === 'overtime' ? 'Heures sup.' : 'Salaire'}
                      </Badge>
                    </td>
                    <td className="px-3 py-2 text-xs text-text-muted">{p.period || p.description || '—'}</td>
                    <td className="px-3 py-2 text-right tabular font-bold">{formatCurrency(p.amount)}</td>
                    <td className="px-3 py-2 text-center">
                      <Button size="icon" variant="ghost" title="Supprimer" onClick={() => setDeletePaymentId(p.id)}>
                        <Trash2 size={14} className="text-rose-deep" />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={!!deletePaymentId}
        onClose={() => setDeletePaymentId(null)}
        onConfirm={() => {
          if (deletePaymentId) {
            void deletePayment(worker.id, deletePaymentId).then(() => toast.success('Paiement supprimé'));
          }
        }}
        title="Supprimer le paiement"
        message="La sortie de caisse sera annulée. Si ce paiement réglait des heures supplémentaires, elles redeviendront « non payées »."
      />
    </div>
  );
}

function Row({ label, value, color = 'text-text-primary' }: { label: string; value: string; color?: string }) {
  return (
    <div className="flex justify-between">
      <span className="text-text-muted">{label}</span>
      <span className={`tabular ${color}`}>{value}</span>
    </div>
  );
}

interface PendingRow { id: string; on: boolean; date: string; detail: string; amount: string; tone: string }

function PendingList({ title, icon, empty, hint, rows, onToggle, onAll, onExclude }: {
  title: string; icon: React.ReactNode; empty: string; hint: string; rows: PendingRow[];
  onToggle: (id: string, v: boolean) => void; onAll: (v: boolean) => void; onExclude: (id: string) => void;
}) {
  const allOn = rows.length > 0 && rows.every((r) => r.on);
  return (
    <div className="rounded-xl border border-gold/15 bg-vanilla/30 p-3 space-y-2">
      <div className="flex items-center justify-between gap-2">
        <p className="text-sm font-semibold text-text-primary flex items-center gap-1.5">{icon}{title} ({rows.length})</p>
        {rows.length > 0 && (
          <Button size="sm" variant="ghost" onClick={() => onAll(!allOn)}>
            {allOn ? 'Tout décocher' : 'Tout cocher'}
          </Button>
        )}
      </div>
      {rows.length === 0 ? (
        <p className="text-xs text-text-muted">{empty}</p>
      ) : (
        <>
          <div className="max-h-56 overflow-y-auto divide-y divide-gold/10 rounded-lg border border-gold/10">
            {rows.map((r) => (
              <div key={r.id} className={`flex items-center gap-2 px-2 py-1.5 text-xs ${r.on ? '' : 'opacity-60'}`}>
                <Checkbox checked={r.on} onChange={(v) => onToggle(r.id, v)} />
                <span className="font-semibold text-text-primary whitespace-nowrap">{r.date}</span>
                <span className="text-text-muted flex-1 truncate tabular">{r.detail}</span>
                <span className={`tabular font-bold whitespace-nowrap ${r.tone}`}>{r.amount}</span>
                <Button size="icon" variant="ghost" title="Exclure définitivement des calculs" onClick={() => onExclude(r.id)}>
                  <EyeOff size={13} className="text-text-muted" />
                </Button>
              </div>
            ))}
          </div>
          <p className="text-[10px] text-text-muted">{hint} Décochées = restent en attente. <EyeOff size={10} className="inline" /> = exclure.</p>
        </>
      )}
    </div>
  );
}

function Mini2({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gold/10 bg-chocolate px-2 py-1.5">
      <p className="text-[10px] text-text-muted">{label}</p>
      <p className="font-bold tabular text-text-primary">{value}</p>
    </div>
  );
}
