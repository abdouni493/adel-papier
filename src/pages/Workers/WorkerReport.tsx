import { useEffect, useMemo, useState } from 'react';
import {
  FileBarChart, Printer, Banknote, Clock, Wallet, CalendarX, RotateCcw, AlertTriangle, Fingerprint,
} from 'lucide-react';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import {
  PeriodPicker, ReportKpis, ReportSection, firstDayOfMonth, inPeriod,
} from '@/components/shared/PeriodReport';
import { useSettingsStore } from '@/store/settingsStore';
import { useAttendanceStore } from '@/store/attendanceStore';
import {
  computeMonth, fmtMin, punchTimeSec, STATUS_LABEL, WEEKDAYS, type DayRecord,
} from '@/lib/attendance';
import { useLanguage } from '@/hooks/useLanguage';
import { formatCurrency, formatDate, todayISO } from '@/lib/utils';
import { printDetailedReport, type PrintRow, type PrintTableSection } from '@/lib/reportPrint';
import type { AttendancePunch, Worker } from '@/types';

const pad = (n: number) => String(n).padStart(2, '0');

const LATE_LABEL = { pending: 'Non réglé', applied: 'Déduit', excluded: 'Exclu' } as const;

/** Mois (AAAA-MM) couverts par une période. */
function monthsBetween(from: string, to: string): string[] {
  const out: string[] = [];
  const d = new Date(`${from.slice(0, 7)}-01T12:00:00`);
  while (out.length < 60) {
    const m = `${d.getFullYear()}-${pad(d.getMonth() + 1)}`;
    if (m > to.slice(0, 7)) break;
    out.push(m);
    d.setMonth(d.getMonth() + 1);
  }
  return out;
}

/**
 * Rapport détaillé d'un employé sur une période : pointages jour par jour,
 * retards, heures supplémentaires, absences, acomptes et paiements, avec tous
 * les détails et une impression professionnelle.
 */
export function WorkerReport({ worker, roleName }: { worker: Worker; roleName?: string }) {
  const { language } = useLanguage();
  const settings = useSettingsStore((s) => s.settings);

  const [from, setFrom] = useState(firstDayOfMonth());
  const [to, setTo] = useState(todayISO());
  const [period, setPeriod] = useState<{ from: string; to: string } | null>(null);

  // ---- pointages de la période ----
  const { settings: attSettings, ready: attReady, loadMeta, fetchPunches } = useAttendanceStore();
  const [punches, setPunches] = useState<AttendancePunch[]>([]);
  useEffect(() => { void loadMeta(); }, [loadMeta]);
  useEffect(() => {
    if (!period || !attReady) { setPunches([]); return; }
    void fetchPunches(period.from, period.to, worker.id).then(setPunches).catch(() => setPunches([]));
  }, [period, attReady, worker.id, fetchPunches]);
  const days = useMemo<DayRecord[]>(() => {
    if (!period || !attReady || !worker.badgePin) return [];
    return monthsBetween(period.from, period.to)
      .flatMap((m) => computeMonth(m, punches, worker, attSettings).days)
      .filter((d) => d.date >= period.from && d.date <= period.to && d.status !== 'future' && d.status !== 'before');
  }, [period, attReady, punches, worker, attSettings]);
  const att = useMemo(() => ({
    present: days.filter((d) => d.status === 'present').length,
    absent: days.filter((d) => d.status === 'absent').length,
    recorded: days.filter((d) => d.status === 'recorded').length,
    worked: days.reduce((s, d) => s + d.workedMin, 0),
    late: days.reduce((s, d) => s + d.lateMin, 0),
    early: days.reduce((s, d) => s + d.earlyMin, 0),
    overtime: days.reduce((s, d) => s + d.overtimeMin, 0),
    punches: days.reduce((s, d) => s + d.punches.length, 0),
  }), [days]);

  const data = useMemo(() => {
    if (!period) return null;
    const { from: f, to: t } = period;

    const payments = worker.payments
      .filter((p) => inPeriod(p.date, f, t))
      .sort((a, b) => a.date.localeCompare(b.date));
    const overtimes = (worker.overtimes ?? [])
      .filter((o) => inPeriod(o.date, f, t))
      .sort((a, b) => a.date.localeCompare(b.date));
    const lates = (worker.lates ?? [])
      .filter((l) => inPeriod(l.date, f, t))
      .sort((a, b) => a.date.localeCompare(b.date));
    const acomptes = worker.acomptes
      .filter((a) => inPeriod(a.date, f, t))
      .sort((a, b) => a.date.localeCompare(b.date));
    const absences = worker.absences
      .filter((a) => inPeriod(a.date, f, t))
      .sort((a, b) => a.date.localeCompare(b.date));

    const salaryPaid = payments.filter((p) => p.kind !== 'overtime').reduce((s, p) => s + p.amount, 0);
    const overtimePaid = payments.filter((p) => p.kind === 'overtime').reduce((s, p) => s + p.amount, 0);
    const activeOt = overtimes.filter((o) => !o.excluded);
    const overtimeHours = activeOt.reduce((s, o) => s + o.hours, 0);
    const overtimeAmount = activeOt.reduce((s, o) => s + o.amount, 0);
    const overtimeUnpaid = activeOt.filter((o) => !o.isPaid).reduce((s, o) => s + o.amount, 0);
    const activeLates = lates.filter((l) => l.status !== 'excluded');
    const lateMin = activeLates.reduce((s, l) => s + l.minutes, 0);
    const lateAmount = activeLates.reduce((s, l) => s + l.amount, 0);
    const latePending = lates.filter((l) => l.status === 'pending').reduce((s, l) => s + l.amount, 0);
    const acomptesTotal = acomptes.reduce((s, a) => s + a.amount, 0);
    const absencesCost = absences.reduce((s, a) => s + a.cost, 0);

    return {
      payments, overtimes, lates, acomptes, absences,
      salaryPaid, overtimePaid, overtimeHours, overtimeAmount, overtimeUnpaid,
      lateMin, lateAmount, latePending,
      acomptesTotal, absencesCost,
      totalPaid: salaryPaid + overtimePaid,
      net: salaryPaid + overtimePaid + acomptesTotal - absencesCost,
    };
  }, [worker, period]);

  const periodLabel = period
    ? `Du ${formatDate(period.from, language)} au ${formatDate(period.to, language)}`
    : '';

  const doPrint = () => {
    if (!data || !period) return;

    const paymentsSection: PrintTableSection = {
      title: 'Historique des paiements',
      icon: '💵',
      headerTotal: formatCurrency(data.totalPaid),
      cols: [
        { label: 'Date' }, { label: 'Type' }, { label: 'Période / motif' },
        { label: 'Description' }, { label: 'Montant', align: 'right' },
      ],
      rows: [
        ...data.payments.map<PrintRow>((p) => ({
          cells: [
            formatDate(p.date, language),
            p.kind === 'overtime' ? 'Heures sup.' : 'Salaire',
            p.period || '—',
            p.description || '—',
            formatCurrency(p.amount),
          ],
          tone: 'pos',
        })),
        ...(data.payments.length
          ? [{
              cells: ['TOTAL VERSÉ', '', '', '', formatCurrency(data.totalPaid)],
              variant: 'total' as const,
            }]
          : []),
      ],
      emptyLabel: 'Aucun paiement sur la période',
    };

    const overtimeSection: PrintTableSection = {
      title: 'Heures supplémentaires',
      icon: '⏱️',
      headerTotal: formatCurrency(data.overtimeAmount),
      note: `${data.overtimeHours.toFixed(2)} heure(s) au total · ${formatCurrency(data.overtimeUnpaid)} restant à payer`,
      cols: [
        { label: 'Date' }, { label: 'Fin de poste' }, { label: 'Fin des heures sup.' },
        { label: 'Durée', align: 'right' }, { label: 'Taux horaire', align: 'right' },
        { label: 'Montant', align: 'right' }, { label: 'Statut', align: 'center' },
        { label: 'Motif' },
      ],
      rows: [
        ...data.overtimes.map<PrintRow>((o) => ({
          cells: [
            formatDate(o.date, language),
            `${pad(o.workEndHour)}:${pad(o.workEndMinute)}`,
            `${pad(o.overtimeEndHour)}:${pad(o.overtimeEndMinute)}`,
            `${o.hours.toFixed(2)} h`,
            formatCurrency(o.hourlyRate),
            formatCurrency(o.amount),
            o.isPaid ? 'Payée' : o.excluded ? 'Exclue' : 'Non payée',
            o.description || '—',
          ],
          tone: o.excluded ? 'muted' : undefined,
        })),
        ...(data.overtimes.length
          ? [{
              cells: ['TOTAL HEURES SUP.', '', '', `${data.overtimeHours.toFixed(2)} h`, '',
                formatCurrency(data.overtimeAmount), '', ''],
              variant: 'total' as const,
            }]
          : []),
      ],
      emptyLabel: 'Aucune heure supplémentaire sur la période',
    };

    const acompteSection: PrintTableSection = {
      title: 'Acomptes versés',
      icon: '🪙',
      headerTotal: formatCurrency(data.acomptesTotal),
      cols: [{ label: 'Date' }, { label: 'Description' }, { label: 'Montant', align: 'right' }],
      rows: [
        ...data.acomptes.map<PrintRow>((a) => ({
          cells: [formatDate(a.date, language), a.description || '—', formatCurrency(a.amount)],
          tone: 'accent',
        })),
        ...(data.acomptes.length
          ? [{ cells: ['TOTAL ACOMPTES', '', formatCurrency(data.acomptesTotal)], variant: 'total' as const }]
          : []),
      ],
      emptyLabel: 'Aucun acompte sur la période',
    };

    const absenceSection: PrintTableSection = {
      title: 'Absences',
      icon: '📅',
      headerTotal: formatCurrency(data.absencesCost),
      cols: [{ label: 'Date' }, { label: 'Motif' }, { label: 'Coût retenu', align: 'right' }],
      rows: [
        ...data.absences.map<PrintRow>((a) => ({
          cells: [formatDate(a.date, language), a.description || '—', formatCurrency(a.cost)],
          tone: 'neg',
        })),
        ...(data.absences.length
          ? [{ cells: ['TOTAL ABSENCES', '', formatCurrency(data.absencesCost)], variant: 'total' as const }]
          : []),
      ],
      emptyLabel: 'Aucune absence sur la période',
    };

    const lateSection: PrintTableSection = {
      title: 'Retards',
      icon: '⏰',
      headerTotal: formatCurrency(data.lateAmount),
      note: `${fmtMin(data.lateMin)} de retard · ${formatCurrency(data.latePending)} non réglé`,
      cols: [
        { label: 'Date' }, { label: 'Début prévu', align: 'center' }, { label: 'Arrivée', align: 'center' },
        { label: 'Retard', align: 'center' }, { label: 'Retenue', align: 'right' }, { label: 'Statut', align: 'center' },
      ],
      rows: [
        ...data.lates.map<PrintRow>((l) => ({
          cells: [formatDate(l.date, language), l.scheduleStart || '—', l.entryTime || '—', fmtMin(l.minutes),
            formatCurrency(l.amount), LATE_LABEL[l.status]],
          tone: l.status === 'excluded' ? 'muted' : 'neg',
        })),
        ...(data.lates.length
          ? [{ cells: ['TOTAL RETARDS', '', '', fmtMin(data.lateMin), formatCurrency(data.lateAmount), ''], variant: 'total' as const }]
          : []),
      ],
      emptyLabel: 'Aucun retard sur la période',
    };

    const attendanceSection: PrintTableSection = {
      title: 'Pointages jour par jour',
      icon: '🕘',
      note: `${att.present} j présent(s) · ${att.absent} absence(s) non justifiée(s) · ${att.recorded} absence(s) saisie(s) · travaillé ${fmtMin(att.worked)}`,
      cols: [
        { label: 'Date' }, { label: 'Jour' }, { label: 'Entrée', align: 'center' }, { label: 'Sortie', align: 'center' },
        { label: 'Travaillé', align: 'center' }, { label: 'Retard', align: 'center' }, { label: 'Départ ant.', align: 'center' },
        { label: 'H. sup.', align: 'center' }, { label: 'Tous les pointages' }, { label: 'Statut' },
      ],
      rows: days.map<PrintRow>((d) => ({
        cells: [
          formatDate(d.date, language), WEEKDAYS[d.weekday], d.entry ?? '—',
          d.exit ?? (d.missingExit ? 'manquante' : '—'), fmtMin(d.workedMin), fmtMin(d.lateMin),
          fmtMin(d.earlyMin), fmtMin(d.overtimeMin), d.punches.map(punchTimeSec).join(' · ') || '—',
          STATUS_LABEL[d.status],
        ],
        tone: d.status === 'absent' ? 'neg' : d.status === 'present' ? 'pos' : 'muted',
      })),
      emptyLabel: worker.badgePin ? 'Aucun pointage sur la période' : 'Employé sans N° pointeuse',
    };

    printDetailedReport(
      {
        docTitle: `Rapport ${worker.fullName}`,
        headTitle: 'RAPPORT EMPLOYÉ',
        subtitle: periodLabel,
        meta: [
          { label: 'Employé', value: worker.fullName },
          { label: 'Poste', value: roleName || '—' },
          { label: 'Téléphone', value: worker.phone || '—' },
          { label: 'Carte identité', value: worker.idCardNumber || '—' },
          { label: 'Embauché le', value: worker.startDate ? formatDate(worker.startDate, language) : '—' },
          {
            label: 'Salaire',
            value: worker.paymentEnabled
              ? `${formatCurrency(worker.paymentAmount)} / ${worker.paymentType === 'monthly' ? 'mois' : 'jour'}`
              : '—',
          },
          { label: 'Période', value: periodLabel },
        ],
        kpis: [
          { label: 'Salaires payés', value: formatCurrency(data.salaryPaid), tone: 'pos' },
          { label: 'Heures sup. payées', value: formatCurrency(data.overtimePaid), tone: 'pos' },
          { label: 'Heures sup. à payer', value: formatCurrency(data.overtimeUnpaid), tone: 'neg' },
          { label: 'Total heures sup.', value: `${data.overtimeHours.toFixed(2)} h`, tone: 'accent' },
          { label: 'Jours présents', value: String(att.present), tone: 'pos' },
          { label: 'Absences pointeuse', value: String(att.absent), tone: 'neg' },
          { label: 'Retards', value: `${fmtMin(data.lateMin)} · ${formatCurrency(data.lateAmount)}`, tone: 'neg' },
          { label: 'Retards non réglés', value: formatCurrency(data.latePending), tone: 'neg' },
          { label: 'Acomptes', value: formatCurrency(data.acomptesTotal), tone: 'accent' },
          { label: 'Coût des absences', value: formatCurrency(data.absencesCost), tone: 'neg' },
          { label: 'Total versé', value: formatCurrency(data.totalPaid), tone: 'pos' },
          { label: 'Coût employé (net)', value: formatCurrency(data.net), tone: 'accent' },
        ],
        sections: [attendanceSection, lateSection, overtimeSection, absenceSection, acompteSection, paymentsSection],
      },
      settings,
      language
    );
  };

  return (
    <div className="space-y-5">
      <PeriodPicker
        from={from}
        to={to}
        onChange={(f, t) => { setFrom(f); setTo(t); setPeriod(null); }}
        onGenerate={() => setPeriod({ from, to })}
        label="Créer le rapport de l'employé"
      />

      {!data ? (
        <div className="rounded-2xl border border-dashed border-gold/25 bg-vanilla/20 py-10 text-center">
          <FileBarChart size={34} className="mx-auto text-gold opacity-60 mb-3" />
          <p className="text-sm text-text-muted">
            Choisissez une date de début et une date de fin, puis créez le rapport détaillé.
          </p>
        </div>
      ) : (
        <div className="space-y-5">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <p className="font-display text-base font-semibold text-text-primary">{worker.fullName}</p>
              <p className="text-xs text-text-muted">{roleName ? `${roleName} · ` : ''}{periodLabel}</p>
            </div>
            <div className="flex gap-2">
              <Button size="sm" variant="secondary" onClick={() => setPeriod(null)}>
                <RotateCcw size={14} /> Changer la période
              </Button>
              <Button size="sm" variant="gold" onClick={doPrint}>
                <Printer size={14} /> Imprimer le rapport
              </Button>
            </div>
          </div>

          <ReportKpis
            items={[
              { label: 'Salaires payés', value: formatCurrency(data.salaryPaid), color: 'text-pistachio' },
              { label: 'H. sup. payées', value: formatCurrency(data.overtimePaid), color: 'text-gold-dark' },
              { label: 'H. sup. à payer', value: formatCurrency(data.overtimeUnpaid), color: 'text-rose-deep' },
              { label: 'Total heures sup.', value: `${data.overtimeHours.toFixed(2)} h` },
              { label: 'Jours présents', value: String(att.present), color: 'text-pistachio' },
              { label: 'Absences pointeuse', value: String(att.absent), color: 'text-rose-deep' },
              { label: 'Retards', value: `${fmtMin(data.lateMin)} · ${formatCurrency(data.lateAmount)}`, color: 'text-caramel' },
              { label: 'Retards non réglés', value: formatCurrency(data.latePending), color: 'text-rose-deep' },
              { label: 'Acomptes', value: formatCurrency(data.acomptesTotal), color: 'text-caramel' },
              { label: 'Coût des absences', value: formatCurrency(data.absencesCost), color: 'text-rose-deep' },
              { label: 'Total versé', value: formatCurrency(data.totalPaid), color: 'text-pistachio' },
              { label: 'Coût employé (net)', value: formatCurrency(data.net), color: 'text-gold-dark' },
            ]}
          />

          <ReportSection
            title="Pointages jour par jour" icon={<Fingerprint size={14} />}
            note={`${att.present} j présent(s) · ${att.absent} absence(s) · ${att.punches} pointage(s) · travaillé ${fmtMin(att.worked)} · départs anticipés ${fmtMin(att.early)} · h. sup. pointées ${fmtMin(att.overtime)}`}
            head={['Date', 'Entrée', 'Sortie', 'Travaillé', 'Retard', 'Départ ant.', 'H. sup.', 'Pointages', 'Statut']}
            empty={worker.badgePin ? 'Aucun pointage sur cette période' : 'Employé sans N° pointeuse'}
            rows={days.map((d) => [
              `${formatDate(d.date, language)} · ${WEEKDAYS[d.weekday].slice(0, 3)}`,
              d.entry ?? '—',
              d.exit ?? (d.missingExit ? 'manquante' : '—'),
              fmtMin(d.workedMin),
              <span key="l" className="text-caramel">{fmtMin(d.lateMin)}</span>,
              fmtMin(d.earlyMin),
              <span key="o" className="text-pistachio">{fmtMin(d.overtimeMin)}</span>,
              <span key="p" className="text-text-muted tabular">{d.punches.map(punchTimeSec).join(' · ') || '—'}</span>,
              STATUS_LABEL[d.status],
            ])}
          />

          <ReportSection
            title="Retards" icon={<AlertTriangle size={14} />}
            total={formatCurrency(data.lateAmount)}
            note={`${fmtMin(data.lateMin)} · ${formatCurrency(data.latePending)} non réglé`}
            head={['Date', 'Début prévu', 'Arrivée', 'Retard', 'Retenue', 'Statut']}
            empty="Aucun retard sur cette période"
            rows={data.lates.map((l) => [
              formatDate(l.date, language),
              l.scheduleStart || '—',
              l.entryTime || '—',
              fmtMin(l.minutes),
              <span key="a" className="font-bold text-rose-deep">{formatCurrency(l.amount)}</span>,
              <Badge key="s" variant={l.status === 'applied' ? 'success' : l.status === 'excluded' ? 'neutral' : 'warning'}>{LATE_LABEL[l.status]}</Badge>,
            ])}
          />

          <ReportSection
            title="Historique des paiements" icon={<Banknote size={14} />}
            total={formatCurrency(data.totalPaid)}
            head={['Date', 'Type', 'Période / motif', 'Description', 'Montant']}
            empty="Aucun paiement sur cette période"
            rows={data.payments.map((p) => [
              formatDate(p.date, language),
              <Badge key="t" variant={p.kind === 'overtime' ? 'warning' : 'info'}>
                {p.kind === 'overtime' ? 'Heures sup.' : 'Salaire'}
              </Badge>,
              p.period || '—',
              p.description || '—',
              <span key="a" className="font-bold text-pistachio">{formatCurrency(p.amount)}</span>,
            ])}
          />

          <ReportSection
            title="Heures supplémentaires" icon={<Clock size={14} />}
            total={formatCurrency(data.overtimeAmount)}
            note={`${data.overtimeHours.toFixed(2)} heure(s) · ${formatCurrency(data.overtimeUnpaid)} restant à payer`}
            head={['Date', 'Fin de poste', 'Fin h. sup.', 'Durée', 'Taux', 'Montant', 'Statut', 'Motif']}
            empty="Aucune heure supplémentaire sur cette période"
            rows={data.overtimes.map((o) => [
              formatDate(o.date, language),
              `${pad(o.workEndHour)}:${pad(o.workEndMinute)}`,
              `${pad(o.overtimeEndHour)}:${pad(o.overtimeEndMinute)}`,
              `${o.hours.toFixed(2)} h`,
              formatCurrency(o.hourlyRate),
              <span key="a" className="font-bold text-gold-dark">{formatCurrency(o.amount)}</span>,
              <Badge key="s" variant={o.isPaid ? 'success' : o.excluded ? 'neutral' : 'warning'}>
                {o.isPaid ? 'Payée' : o.excluded ? 'Exclue' : 'Non payée'}
              </Badge>,
              o.description || '—',
            ])}
          />

          <ReportSection
            title="Acomptes versés" icon={<Wallet size={14} />}
            total={formatCurrency(data.acomptesTotal)}
            head={['Date', 'Description', 'Montant']}
            empty="Aucun acompte sur cette période"
            rows={data.acomptes.map((a) => [
              formatDate(a.date, language),
              a.description || '—',
              <span key="a" className="font-bold text-caramel">{formatCurrency(a.amount)}</span>,
            ])}
          />

          <ReportSection
            title="Absences" icon={<CalendarX size={14} />}
            total={formatCurrency(data.absencesCost)}
            head={['Date', 'Motif', 'Coût retenu']}
            empty="Aucune absence sur cette période"
            rows={data.absences.map((a) => [
              formatDate(a.date, language),
              a.description || '—',
              <span key="a" className="font-bold text-rose-deep">{formatCurrency(a.cost)}</span>,
            ])}
          />
        </div>
      )}
    </div>
  );
}
