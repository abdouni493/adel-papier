import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Fingerprint, LogIn, LogOut, Clock, AlertTriangle, CalendarX, CalendarCheck,
  Printer, Plus, Trash2, Send, Timer, RefreshCw, Hourglass,
} from 'lucide-react';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { Select } from '@/components/ui/Select';
import { Input } from '@/components/ui/Input';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { useAttendanceStore } from '@/store/attendanceStore';
import { useWorkerStore } from '@/store/workerStore';
import { useSettingsStore } from '@/store/settingsStore';
import { usePermissions } from '@/hooks/usePermissions';
import {
  computeMonth, attendancePay, currentMonth, lastMonths, monthRange, monthLabel, fmtMin,
  punchTimeSec, verifyLabel, WEEKDAYS, STATUS_LABEL, zkCommands, toMin,
  type DayRecord,
} from '@/lib/attendance';
import { printDetailedReport } from '@/lib/reportPrint';
import { formatCurrency, todayISO } from '@/lib/utils';
import { toast } from '@/components/ui/Toast';
import type { AttendancePunch, Worker } from '@/types';

const statusVariant: Record<DayRecord['status'], 'success' | 'warning' | 'danger' | 'info' | 'neutral'> = {
  present: 'success', absent: 'danger', recorded: 'warning', rest: 'neutral',
  pending: 'info', future: 'neutral', before: 'neutral',
};

/**
 * Pointage d'un employé : chaque jour du mois avec l'heure et la minute
 * d'entrée et de sortie, tous les pointages, retards, départs anticipés,
 * heures supplémentaires, absences, et l'impact sur la paie.
 */
export function WorkerAttendance({ worker }: { worker: Worker }) {
  const { settings, ready, loadMeta, fetchPunches, addManualPunch, deletePunch, queueCommands } = useAttendanceStore();
  const addOvertime = useWorkerStore((s) => s.addOvertime);
  const live = useWorkerStore((s) => s.workers.find((w) => w.id === worker.id)) ?? worker;
  const store = useSettingsStore((s) => s.settings);
  const { can } = usePermissions();

  const [month, setMonth] = useState(currentMonth());
  const [punches, setPunches] = useState<AttendancePunch[]>([]);
  const [loading, setLoading] = useState(false);
  const [openDay, setOpenDay] = useState<string | null>(null);
  const [manual, setManual] = useState({ date: todayISO(), time: '08:00', note: '' });
  const [showManual, setShowManual] = useState(false);
  const [deleteId, setDeleteId] = useState<number | null>(null);

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      const { from, to } = monthRange(month);
      setPunches(await fetchPunches(from, to, worker.id));
    } finally {
      setLoading(false);
    }
  }, [month, worker.id, fetchPunches]);

  useEffect(() => { void loadMeta(); }, [loadMeta]);
  useEffect(() => { void reload(); }, [reload]);

  const sum = useMemo(() => computeMonth(month, punches, live, settings), [month, punches, live, settings]);
  const pay = useMemo(() => attendancePay(live, sum, settings), [live, sum, settings]);
  const days = sum.days.filter((d) => d.status !== 'future' && d.status !== 'before');

  if (!ready) {
    return (
      <div className="rounded-2xl border border-caramel/40 bg-caramel/10 p-4 text-sm text-caramel">
        Le module pointeuse n'est pas encore installé dans la base : exécutez
        <b> supabase/parts/10_pointeuse.sql</b> dans Supabase › SQL Editor.
      </div>
    );
  }

  const sendToDevice = async () => {
    if (!live.badgePin) { toast.error("Attribuez d'abord un N° pointeuse (Modifier l'employé)"); return; }
    await queueCommands([{ command: zkCommands.userInfo(live.badgePin, live.fullName), label: `Employé ${live.fullName}` }]);
    toast.success('Envoyé — la pointeuse le recevra dans quelques secondes');
  };
  const enrollFinger = async () => {
    if (!live.badgePin) { toast.error("Attribuez d'abord un N° pointeuse (Modifier l'employé)"); return; }
    await queueCommands([
      { command: zkCommands.userInfo(live.badgePin, live.fullName), label: `Employé ${live.fullName}` },
      { command: zkCommands.enrollFinger(live.badgePin), label: `Empreinte ${live.fullName}` },
    ]);
    toast.success("Demande envoyée — l'employé pose son doigt 3 fois sur la pointeuse");
  };

  const saveManual = async () => {
    await addManualPunch(live.id, live.badgePin ?? '', `${manual.date}T${manual.time}`, manual.note);
    toast.success('Pointage ajouté');
    setShowManual(false);
    void reload();
  };

  const overtimeFromDay = async (d: DayRecord) => {
    if (!d.exit) return;
    const hours = d.overtimeMin / 60;
    const rate = live.paymentType === 'daily'
      ? live.paymentAmount / (sum.scheduledMinPerDay / 60)
      : pay.dailyRate / (sum.scheduledMinPerDay / 60);
    const [eh, em] = d.scheduleEnd.split(':').map(Number);
    const [xh, xm] = d.exit.split(':').map(Number);
    await addOvertime({
      workerId: live.id, date: d.date,
      workEndHour: eh, workEndMinute: em, overtimeEndHour: xh, overtimeEndMinute: xm,
      hours: Math.round(hours * 100) / 100, hourlyRate: Math.round(rate),
      amount: Math.round(hours * rate), description: 'Depuis la pointeuse',
    });
    toast.success('Heures supplémentaires créées (à payer dans « Paie »)');
  };
  const overtimeExists = (date: string) => (live.overtimes ?? []).some((o) => o.date?.slice(0, 10) === date);

  const print = () => {
    printDetailedReport({
      docTitle: `Pointage ${live.fullName} ${monthLabel(month)}`,
      headTitle: 'RELEVÉ DE POINTAGE',
      subtitle: monthLabel(month),
      meta: [
        { label: 'Employé', value: live.fullName },
        { label: 'N° pointeuse', value: live.badgePin || '—' },
        { label: 'Horaires', value: `${sum.days[0]?.scheduleStart ?? ''} → ${sum.days[0]?.scheduleEnd ?? ''}` },
      ],
      kpis: [
        { label: 'Jours ouvrables', value: String(sum.workingDays) },
        { label: 'Jours présents', value: String(sum.presentDays), tone: 'pos' },
        { label: 'Absences', value: String(sum.absentDays + sum.recordedAbsences), tone: 'neg' },
        { label: 'Retards', value: `${sum.lateCount} · ${fmtMin(sum.lateMin)}`, tone: 'neg' },
        { label: 'Départs anticipés', value: `${sum.earlyCount} · ${fmtMin(sum.earlyMin)}` },
        { label: 'Heures travaillées', value: fmtMin(sum.workedMin) },
        { label: 'Heures sup.', value: fmtMin(sum.overtimeMin), tone: 'pos' },
        { label: 'Retenues pointage', value: formatCurrency(pay.absenceDeduction + pay.lateDeduction), tone: 'neg' },
      ],
      sections: [{
        title: 'Détail journalier',
        cols: [
          { label: 'Date' }, { label: 'Jour' }, { label: 'Entrée', align: 'center' },
          { label: 'Sortie', align: 'center' }, { label: 'Travaillé', align: 'center' },
          { label: 'Retard', align: 'center' }, { label: 'Départ ant.', align: 'center' },
          { label: 'H. sup.', align: 'center' }, { label: 'Statut' },
        ],
        rows: days.map((d) => ({
          cells: [
            d.date.split('-').reverse().join('/'), WEEKDAYS[d.weekday], d.entry ?? '—',
            d.exit ?? (d.missingExit ? 'manquante' : '—'), fmtMin(d.workedMin), fmtMin(d.lateMin),
            fmtMin(d.earlyMin), fmtMin(d.overtimeMin), STATUS_LABEL[d.status],
          ],
          tone: d.status === 'absent' ? 'neg' : d.status === 'present' ? 'pos' : 'muted',
        })),
      }],
    }, store);
  };

  return (
    <div className="space-y-4">
      {/* barre */}
      <div className="flex flex-wrap items-end gap-2">
        <Select
          label="Mois" value={month} onChange={(e) => setMonth(e.target.value)}
          options={lastMonths(24)} className="max-w-[200px]"
        />
        <Button variant="secondary" size="sm" onClick={() => void reload()} disabled={loading}>
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} /> Actualiser
        </Button>
        <Button variant="secondary" size="sm" onClick={print}><Printer size={14} /> Imprimer</Button>
        {can('workers', 'create') && (
          <Button variant="secondary" size="sm" onClick={() => setShowManual((v) => !v)}>
            <Plus size={14} /> Pointage manuel
          </Button>
        )}
        <div className="ml-auto flex flex-wrap gap-2">
          <Badge variant={live.badgePin ? 'success' : 'warning'} className="gap-1">
            <Fingerprint size={11} /> {live.badgePin ? `N° pointeuse ${live.badgePin}` : 'Sans N° pointeuse'}
          </Badge>
        </div>
      </div>

      {can('workers', 'edit') && (
        <div className="flex flex-wrap gap-2">
          <Button variant="liver" size="sm" onClick={() => void sendToDevice()}>
            <Send size={14} /> Envoyer l'employé à la pointeuse
          </Button>
          <Button variant="gold" size="sm" onClick={() => void enrollFinger()}>
            <Fingerprint size={14} /> Enregistrer l'empreinte à distance
          </Button>
        </div>
      )}

      {showManual && (
        <div className="rounded-2xl border border-gold/20 bg-vanilla/40 p-3 grid grid-cols-1 sm:grid-cols-4 gap-2 items-end">
          <Input label="Date" type="date" value={manual.date} onChange={(e) => setManual({ ...manual, date: e.target.value })} />
          <Input label="Heure" type="time" value={manual.time} onChange={(e) => setManual({ ...manual, time: e.target.value })} />
          <Input label="Motif" value={manual.note} onChange={(e) => setManual({ ...manual, note: e.target.value })} placeholder="Oubli de pointage…" />
          <Button variant="gold" onClick={() => void saveManual()}><Plus size={14} /> Ajouter</Button>
        </div>
      )}

      {/* résumé */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
        <Kpi icon={<CalendarCheck size={15} />} label="Présent" value={`${sum.presentDays} / ${sum.workingDays} j`} tone="text-pistachio" />
        <Kpi icon={<CalendarX size={15} />} label="Absences" value={`${sum.absentDays} non justif. · ${sum.recordedAbsences} saisies`} tone="text-rose-deep" />
        <Kpi icon={<AlertTriangle size={15} />} label="Retards" value={`${sum.lateCount} · ${fmtMin(sum.lateMin)}`} tone="text-caramel" />
        <Kpi icon={<LogOut size={15} />} label="Départs anticipés" value={`${sum.earlyCount} · ${fmtMin(sum.earlyMin)}`} tone="text-caramel" />
        <Kpi icon={<Timer size={15} />} label="Heures travaillées" value={fmtMin(sum.workedMin)} />
        <Kpi icon={<Clock size={15} />} label="Heures sup. pointées" value={fmtMin(sum.overtimeMin)} tone="text-pistachio" />
        <Kpi icon={<Hourglass size={15} />} label="Sorties manquantes" value={String(sum.missingExitCount)} />
        <Kpi icon={<LogIn size={15} />} label="Jours de repos travaillés" value={String(sum.restWorkedDays)} />
      </div>

      {/* impact paie */}
      {live.paymentEnabled && (
        <div className="rounded-2xl border border-gold/20 bg-gold/5 px-4 py-3 text-sm space-y-1">
          <p className="font-semibold text-text-primary">Impact sur la paie — {monthLabel(month)}</p>
          {live.paymentType === 'daily' ? (
            <p className="text-text-muted">
              {sum.presentDays} jour(s) présent(s) × {formatCurrency(live.paymentAmount)} =
              <b className="text-text-primary"> {formatCurrency(pay.base)}</b>
            </p>
          ) : (
            <p className="text-text-muted">
              Salaire {formatCurrency(live.paymentAmount)} · taux journalier {formatCurrency(Math.round(pay.dailyRate))}
              {' '}· absences non justifiées : <b className="text-rose-deep">- {formatCurrency(pay.absenceDeduction)}</b>
            </p>
          )}
          <p className="text-text-muted">
            Retards + départs anticipés : {settings.deductLate
              ? <b className="text-rose-deep">- {formatCurrency(pay.lateDeduction)}</b>
              : 'non déduits (Pointage › Paramètres)'}
          </p>
        </div>
      )}

      {/* jours */}
      <div className="overflow-x-auto rounded-xl border border-gold/15">
        <table className="w-full text-sm">
          <thead className="bg-vanilla/60 text-text-secondary text-xs">
            <tr>
              <th className="text-left px-3 py-2">Date</th>
              <th className="text-center px-2 py-2">Entrée</th>
              <th className="text-center px-2 py-2">Sortie</th>
              <th className="text-center px-2 py-2">Travaillé</th>
              <th className="text-center px-2 py-2">Retard</th>
              <th className="text-center px-2 py-2">Départ ant.</th>
              <th className="text-center px-2 py-2">H. sup.</th>
              <th className="text-left px-2 py-2">Statut</th>
            </tr>
          </thead>
          <tbody>
            {days.length === 0 && (
              <tr><td colSpan={8} className="px-3 py-6 text-center text-text-muted">Aucun jour à afficher</td></tr>
            )}
            {[...days].reverse().map((d) => (
              <DayRow
                key={d.date} d={d} open={openDay === d.date}
                onToggle={() => setOpenDay(openDay === d.date ? null : d.date)}
                onDelete={can('workers', 'delete') ? setDeleteId : undefined}
                onOvertime={can('workers', 'create') && d.overtimeMin > 0 && !overtimeExists(d.date)
                  ? () => void overtimeFromDay(d) : undefined}
              />
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-[11px] text-text-muted">
        Cliquez sur un jour pour voir tous ses pointages (heure, minute, seconde et mode de vérification).
      </p>

      <ConfirmDialog
        open={deleteId !== null}
        onClose={() => setDeleteId(null)}
        onConfirm={() => { if (deleteId !== null) void deletePunch(deleteId).then(() => { toast.success('Pointage supprimé'); void reload(); }); }}
        title="Supprimer ce pointage"
        message="Le pointage sera retiré du calcul des présences et de la paie."
      />
    </div>
  );
}

function DayRow({ d, open, onToggle, onDelete, onOvertime }: {
  d: DayRecord; open: boolean; onToggle: () => void;
  onDelete?: (id: number) => void; onOvertime?: () => void;
}) {
  const dd = d.date.split('-').reverse().join('/');
  return (
    <>
      <tr onClick={onToggle} className={`border-t border-gold/10 cursor-pointer hover:bg-gold/5 ${d.status === 'absent' ? 'bg-rose-deep/5' : ''}`}>
        <td className="px-3 py-2 text-xs whitespace-nowrap">
          <span className="font-semibold text-text-primary">{dd}</span>
          <span className="text-text-muted"> · {WEEKDAYS[d.weekday].slice(0, 3)}</span>
        </td>
        <td className={`px-2 py-2 text-center tabular font-semibold ${d.lateMin ? 'text-caramel' : 'text-text-primary'}`}>{d.entry ?? '—'}</td>
        <td className={`px-2 py-2 text-center tabular font-semibold ${d.earlyMin ? 'text-caramel' : 'text-text-primary'}`}>
          {d.exit ?? (d.missingExit ? <span className="text-rose-deep text-xs">manquante</span> : '—')}
        </td>
        <td className="px-2 py-2 text-center tabular text-xs">{fmtMin(d.workedMin)}</td>
        <td className="px-2 py-2 text-center tabular text-xs text-caramel">{d.lateMin ? fmtMin(d.lateMin) : '—'}</td>
        <td className="px-2 py-2 text-center tabular text-xs text-caramel">{d.earlyMin ? fmtMin(d.earlyMin) : '—'}</td>
        <td className="px-2 py-2 text-center tabular text-xs text-pistachio">{d.overtimeMin ? fmtMin(d.overtimeMin) : '—'}</td>
        <td className="px-2 py-2"><Badge variant={statusVariant[d.status]} className="text-[10px]">{STATUS_LABEL[d.status]}</Badge></td>
      </tr>
      {open && (
        <tr className="bg-vanilla/30">
          <td colSpan={8} className="px-4 py-3">
            <p className="text-xs text-text-muted mb-2">
              Horaire prévu {d.scheduleStart} → {d.scheduleEnd}
              {d.entry && <> · arrivé à <b>{d.entry}</b> ({signed(toMin(d.entry) - toMin(d.scheduleStart))})</>}
              {d.exit && <> · parti à <b>{d.exit}</b> ({signed(toMin(d.exit) - toMin(d.scheduleEnd))})</>}
            </p>
            {d.punches.length === 0 ? (
              <p className="text-xs text-text-muted">Aucun pointage ce jour.</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {d.punches.map((p, i) => (
                  <span key={p.id} className="inline-flex items-center gap-1.5 rounded-lg border border-gold/20 bg-chocolate px-2 py-1 text-xs">
                    {i === 0 ? <LogIn size={12} className="text-pistachio" /> : i === d.punches.length - 1 ? <LogOut size={12} className="text-rose-deep" /> : <Clock size={12} />}
                    <b className="tabular">{punchTimeSec(p)}</b>
                    <span className="text-text-muted">{verifyLabel(p.verify, p.source)}{p.note ? ` · ${p.note}` : ''}</span>
                    {onDelete && (
                      <button title="Supprimer" onClick={(e) => { e.stopPropagation(); onDelete(p.id); }}>
                        <Trash2 size={12} className="text-rose-deep" />
                      </button>
                    )}
                  </span>
                ))}
              </div>
            )}
            {onOvertime && (
              <Button size="sm" variant="mint" className="mt-2" onClick={(e) => { e.stopPropagation(); onOvertime(); }}>
                <Clock size={13} /> Créer {fmtMin(d.overtimeMin)} d'heures supplémentaires
              </Button>
            )}
          </td>
        </tr>
      )}
    </>
  );
}

const signed = (min: number) => (min === 0 ? "à l'heure" : min > 0 ? `+${fmtMin(min)}` : `-${fmtMin(-min)}`);

function Kpi({ icon, label, value, tone = 'text-text-primary' }: { icon: React.ReactNode; label: string; value: string; tone?: string }) {
  return (
    <div className="rounded-xl border border-gold/15 bg-vanilla/40 px-3 py-2">
      <p className="flex items-center gap-1.5 text-[11px] text-text-muted">{icon}{label}</p>
      <p className={`text-sm font-bold tabular ${tone}`}>{value}</p>
    </div>
  );
}
