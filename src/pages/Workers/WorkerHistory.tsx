import { useEffect, useMemo, useState } from 'react';
import {
  Banknote, Clock, Wallet, CalendarX, Printer, Coins, TrendingDown, AlertTriangle, Fingerprint,
  Eye, EyeOff,
} from 'lucide-react';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { EmptyState } from '@/components/ui/EmptyState';
import { useSettingsStore } from '@/store/settingsStore';
import { useWorkerStore } from '@/store/workerStore';
import { useAttendanceSync } from '@/hooks/useAttendanceSync';
import { useLanguage } from '@/hooks/useLanguage';
import { formatCurrency, formatDate } from '@/lib/utils';
import { fmtMin } from '@/lib/attendance';
import { printOvertimeReceipt } from '@/lib/documents';
import { toast } from '@/components/ui/Toast';
import { WorkerReport } from './WorkerReport';
import { WorkerAttendance } from './WorkerAttendance';
import type { Worker, WorkerLate } from '@/types';

const pad = (n: number) => String(n).padStart(2, '0');
export type WorkerHistoryTab =
  | 'payments' | 'overtime' | 'lates' | 'acomptes' | 'absences' | 'attendance' | 'report';
type Tab = WorkerHistoryTab;

const LATE_STATUS: Record<WorkerLate['status'], { label: string; variant: 'warning' | 'success' | 'neutral' }> = {
  pending: { label: 'Non réglé', variant: 'warning' },
  applied: { label: 'Déduit', variant: 'success' },
  excluded: { label: 'Exclu', variant: 'neutral' },
};

/**
 * Historique complet d'un employé : paiements, heures supplémentaires,
 * retards, acomptes, absences, pointages et rapport de période. Les heures
 * sup. et retards exclus des calculs peuvent être réactivés ici.
 */
export function WorkerHistory({ worker: initial, roleName, initialTab = 'payments' }: {
  worker: Worker; roleName?: string; initialTab?: WorkerHistoryTab;
}) {
  const { language } = useLanguage();
  const settings = useSettingsStore((s) => s.settings);
  const worker = useWorkerStore((s) => s.workers.find((w) => w.id === initial.id)) ?? initial;
  const { setOvertimeExcluded, setLateStatus } = useWorkerStore();
  useAttendanceSync(worker.id);
  const [tab, setTab] = useState<Tab>(initialTab);

  // reopening the modal on another tab (e.g. the "Rapport" card button)
  useEffect(() => setTab(initialTab), [initialTab, worker.id]);

  const payments = useMemo(
    () => [...worker.payments].sort((a, b) => b.date.localeCompare(a.date)),
    [worker.payments]
  );
  const overtimes = useMemo(
    () => [...(worker.overtimes ?? [])].sort((a, b) => b.date.localeCompare(a.date)),
    [worker.overtimes]
  );
  const lates = useMemo(
    () => [...(worker.lates ?? [])].sort((a, b) => b.date.localeCompare(a.date)),
    [worker.lates]
  );
  const acomptes = useMemo(
    () => [...worker.acomptes].sort((a, b) => b.date.localeCompare(a.date)),
    [worker.acomptes]
  );
  const absences = useMemo(
    () => [...worker.absences].sort((a, b) => b.date.localeCompare(a.date)),
    [worker.absences]
  );

  const totals = useMemo(() => {
    const active = overtimes.filter((o) => !o.excluded);
    const salaryPaid = payments.filter((p) => p.kind !== 'overtime').reduce((s, p) => s + p.amount, 0);
    const overtimePaid = payments.filter((p) => p.kind === 'overtime').reduce((s, p) => s + p.amount, 0);
    const pendingLates = lates.filter((l) => l.status === 'pending');
    return {
      salaryPaid,
      overtimePaid,
      overtimeUnpaid: active.filter((o) => !o.isPaid).reduce((s, o) => s + o.amount, 0),
      overtimeHours: active.reduce((s, o) => s + o.hours, 0),
      lateMin: lates.filter((l) => l.status !== 'excluded').reduce((s, l) => s + l.minutes, 0),
      latePending: pendingLates.reduce((s, l) => s + l.amount, 0),
      latePendingMin: pendingLates.reduce((s, l) => s + l.minutes, 0),
      lateApplied: lates.filter((l) => l.status === 'applied').reduce((s, l) => s + l.amount, 0),
      acomptes: acomptes.reduce((s, a) => s + a.amount, 0),
      absences: absences.reduce((s, a) => s + a.cost, 0),
      grandTotal: salaryPaid + overtimePaid,
    };
  }, [payments, overtimes, lates, acomptes, absences]);

  const printAllOvertime = () => {
    const list = overtimes.filter((o) => !o.excluded);
    if (list.length === 0) return;
    printOvertimeReceipt(
      {
        workerName: worker.fullName,
        role: roleName,
        paidAt: new Date().toISOString(),
        amount: list.reduce((s, o) => s + o.amount, 0),
        lines: list.map((o) => ({
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
  };

  const excludedCount = overtimes.filter((o) => o.excluded && !o.isPaid).length
    + lates.filter((l) => l.status === 'excluded').length;

  return (
    <div className="space-y-4">
      {/* Totals */}
      <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-8 gap-2.5">
        <Tile label="Salaires payés" value={formatCurrency(totals.salaryPaid)} color="text-pistachio" icon={<Banknote size={14} />} />
        <Tile label="H. sup. payées" value={formatCurrency(totals.overtimePaid)} color="text-gold-dark" icon={<Clock size={14} />} />
        <Tile label="H. sup. à payer" value={formatCurrency(totals.overtimeUnpaid)} color="text-rose-deep" icon={<Clock size={14} />} />
        <Tile label="Total heures sup." value={`${totals.overtimeHours.toFixed(2)} h`} icon={<Clock size={14} />} />
        <Tile label="Retards non réglés" value={`${fmtMin(totals.latePendingMin)} · ${formatCurrency(totals.latePending)}`} color="text-caramel" icon={<AlertTriangle size={14} />} />
        <Tile label="Retards déduits" value={formatCurrency(totals.lateApplied)} color="text-rose-deep" icon={<AlertTriangle size={14} />} />
        <Tile label="Acomptes" value={formatCurrency(totals.acomptes)} color="text-caramel" icon={<Coins size={14} />} />
        <Tile label="Coût des absences" value={formatCurrency(totals.absences)} color="text-rose-deep" icon={<TrendingDown size={14} />} />
      </div>

      <div className="rounded-2xl border border-gold/25 bg-gold/5 px-4 py-3 flex items-center justify-between">
        <span className="text-sm font-semibold text-text-secondary">Total versé à cet employé</span>
        <span className="text-xl font-bold tabular text-gold-dark">{formatCurrency(totals.grandTotal)}</span>
      </div>

      {excludedCount > 0 && (
        <p className="text-xs text-text-muted flex items-center gap-1.5">
          <EyeOff size={12} /> {excludedCount} élément(s) exclu(s) des calculs — bouton <Eye size={12} className="inline" /> pour les réactiver.
        </p>
      )}

      {/* Tabs */}
      <div className="flex gap-2 border-b border-gold/15 overflow-x-auto">
        {([
          ['payments', `Paiements (${payments.length})`],
          ['overtime', `Heures sup. (${overtimes.length})`],
          ['lates', `Retards (${lates.length})`],
          ['acomptes', `Acomptes (${acomptes.length})`],
          ['absences', `Absences (${absences.length})`],
          ['attendance', 'Pointages'],
          ['report', 'Rapport de période'],
        ] as const).map(([key, label]) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`pb-2 px-3 text-sm font-semibold border-b-2 transition-all whitespace-nowrap ${
              tab === key ? 'border-gold text-gold-dark' : 'border-transparent text-text-muted'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === 'payments' && (
        payments.length === 0 ? (
          <EmptyState message="Aucun paiement enregistré" icon={<Banknote size={28} />} />
        ) : (
          <Table
            head={['Date', 'Type', 'Période', 'Détail', 'Montant']}
            rows={payments.map((p) => [
              formatDate(p.date, language),
              <Badge key="t" variant={p.kind === 'overtime' ? 'warning' : 'info'}>
                {p.kind === 'overtime' ? 'Heures sup.' : 'Salaire'}
              </Badge>,
              p.period || '—',
              <span key="d" className="text-text-muted">{p.description || '—'}</span>,
              <span key="a" className="tabular font-bold text-pistachio">{formatCurrency(p.amount)}</span>,
            ])}
          />
        )
      )}

      {tab === 'overtime' && (
        overtimes.length === 0 ? (
          <EmptyState message="Aucune heure supplémentaire" icon={<Clock size={28} />} />
        ) : (
          <div className="space-y-3">
            <div className="flex justify-end">
              <Button size="sm" variant="secondary" onClick={printAllOvertime}>
                <Printer size={14} /> Imprimer le relevé
              </Button>
            </div>
            <Table
              head={['Date', 'Origine', 'Horaire', 'Durée', 'Taux', 'Montant', 'Statut', '']}
              rows={overtimes.map((o) => [
                formatDate(o.date, language),
                o.source === 'device'
                  ? <span key="o" className="inline-flex items-center gap-1 text-pistachio"><Fingerprint size={11} /> Pointeuse</span>
                  : 'Saisie',
                `${pad(o.workEndHour)}:${pad(o.workEndMinute)} → ${pad(o.overtimeEndHour)}:${pad(o.overtimeEndMinute)}`,
                `${o.hours.toFixed(2)} h`,
                formatCurrency(o.hourlyRate),
                <span key="a" className={`tabular font-bold ${o.excluded ? 'line-through text-text-muted' : 'text-gold-dark'}`}>{formatCurrency(o.amount)}</span>,
                <Badge key="s" variant={o.isPaid ? 'success' : o.excluded ? 'neutral' : 'warning'}>
                  {o.isPaid ? 'Payée' : o.excluded ? 'Exclue' : 'Non payée'}
                </Badge>,
                o.isPaid ? '' : (
                  <ToggleExclude
                    key="x" excluded={!!o.excluded}
                    onClick={() => void setOvertimeExcluded(o.id, !o.excluded)
                      .then(() => toast.success(o.excluded ? 'Réactivée — comptée dans la paie' : 'Exclue des calculs'))}
                  />
                ),
              ])}
            />
          </div>
        )
      )}

      {tab === 'lates' && (
        lates.length === 0 ? (
          <EmptyState message="Aucun retard pointé" icon={<AlertTriangle size={28} />} />
        ) : (
          <div className="space-y-2">
            <p className="text-xs text-text-muted">
              Total {fmtMin(totals.lateMin)} de retard · {formatCurrency(totals.latePending)} non réglé · {formatCurrency(totals.lateApplied)} déjà déduit.
            </p>
            <Table
              head={['Date', 'Début prévu', 'Arrivée', 'Retard', 'Retenue', 'Statut', '']}
              rows={lates.map((l) => [
                formatDate(l.date, language),
                l.scheduleStart || '—',
                <span key="e" className="tabular font-semibold text-caramel">{l.entryTime || '—'}</span>,
                fmtMin(l.minutes),
                <span key="a" className={`tabular font-bold ${l.status === 'excluded' ? 'line-through text-text-muted' : 'text-rose-deep'}`}>{formatCurrency(l.amount)}</span>,
                <Badge key="s" variant={LATE_STATUS[l.status].variant}>
                  {LATE_STATUS[l.status].label}{l.status === 'applied' && l.appliedAt ? ` le ${formatDate(l.appliedAt, language)}` : ''}
                </Badge>,
                l.status === 'applied' ? '' : (
                  <ToggleExclude
                    key="x" excluded={l.status === 'excluded'}
                    onClick={() => void setLateStatus(l.id, l.status === 'excluded' ? 'pending' : 'excluded')
                      .then(() => toast.success(l.status === 'excluded' ? 'Réactivé — compté dans la paie' : 'Exclu des calculs'))}
                  />
                ),
              ])}
            />
          </div>
        )
      )}

      {tab === 'acomptes' && (
        acomptes.length === 0 ? (
          <EmptyState message="Aucun acompte" icon={<Wallet size={28} />} />
        ) : (
          <Table
            head={['Date', 'Description', 'Montant']}
            rows={acomptes.map((a) => [
              formatDate(a.date, language),
              a.description || '—',
              <span key="a" className="tabular font-bold text-caramel">{formatCurrency(a.amount)}</span>,
            ])}
          />
        )
      )}

      {tab === 'absences' && (
        absences.length === 0 ? (
          <EmptyState message="Aucune absence saisie" icon={<CalendarX size={28} />} />
        ) : (
          <Table
            head={['Date', 'Motif', 'Coût']}
            rows={absences.map((a) => [
              formatDate(a.date, language),
              a.description || '—',
              <span key="a" className="tabular font-bold text-rose-deep">{formatCurrency(a.cost)}</span>,
            ])}
          />
        )
      )}

      {tab === 'attendance' && <WorkerAttendance worker={worker} />}

      {tab === 'report' && <WorkerReport worker={worker} roleName={roleName} />}
    </div>
  );
}

function ToggleExclude({ excluded, onClick }: { excluded: boolean; onClick: () => void }) {
  return (
    <Button size="icon" variant="ghost" title={excluded ? 'Réactiver (compter dans la paie)' : 'Exclure des calculs'} onClick={onClick}>
      {excluded ? <Eye size={14} className="text-pistachio" /> : <EyeOff size={14} className="text-text-muted" />}
    </Button>
  );
}

function Table({ head, rows }: { head: string[]; rows: React.ReactNode[][] }) {
  return (
    <div className="overflow-x-auto rounded-xl border border-gold/15">
      <table className="w-full text-sm">
        <thead className="bg-vanilla/60 text-text-secondary">
          <tr>
            {head.map((h, i) => (
              <th key={`${h}${i}`} className={`px-3 py-2 ${i >= head.length - 1 ? 'text-right' : 'text-left'}`}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i} className="border-t border-gold/10">
              {r.map((cell, j) => (
                <td key={j} className={`px-3 py-2 text-xs ${j >= r.length - 1 ? 'text-right' : 'text-left'}`}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Tile({ label, value, color = 'text-text-primary', icon }: {
  label: string; value: string; color?: string; icon?: React.ReactNode;
}) {
  return (
    <div className="rounded-xl border border-gold/15 bg-vanilla/40 px-3 py-2.5">
      <p className="text-[10px] uppercase tracking-wide text-text-muted flex items-center gap-1 leading-tight">{icon}{label}</p>
      <p className={`text-sm font-bold tabular ${color} mt-0.5`}>{value}</p>
    </div>
  );
}
