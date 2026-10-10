import type { AttendancePunch, AttendanceSettings, Worker } from '@/types';

/* =============================================================================
 *  POINTAGE — calcul des présences à partir des pointages de la pointeuse.
 *
 *  Règle d'une journée : le PREMIER pointage = entrée, le DERNIER = sortie
 *  (s'il y a au moins deux pointages). Les horaires sont ceux de l'employé ou,
 *  à défaut, ceux de l'usine ; les tolérances viennent des paramètres.
 *  Toutes les heures sont LOCALES (« AAAA-MM-JJTHH:MM:SS ») : aucun fuseau.
 * ========================================================================== */

export const DEFAULT_ATTENDANCE_SETTINGS: AttendanceSettings = {
  workStart: '08:00',
  workEnd: '16:00',
  lateToleranceMin: 10,
  earlyToleranceMin: 10,
  minOvertimeMin: 30,
  restDays: [5],
  deductAbsences: true,
  deductLate: false,
};

export const WEEKDAYS = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
export const MONTHS = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août',
  'Septembre', 'Octobre', 'Novembre', 'Décembre'];

export const VERIFY_LABEL: Record<number, string> = {
  0: 'Mot de passe', 1: 'Empreinte', 2: 'N° employé', 3: 'Mot de passe', 4: 'Carte',
  15: 'Visage', 25: 'Paume',
};
export const verifyLabel = (v: number, source?: string) =>
  source === 'manual' ? 'Saisie manuelle' : VERIFY_LABEL[v] ?? `Mode ${v}`;

export type DayStatus = 'present' | 'absent' | 'recorded' | 'rest' | 'pending' | 'future' | 'before';

export interface DayRecord {
  date: string;                 // AAAA-MM-JJ
  weekday: number;
  status: DayStatus;
  punches: AttendancePunch[];
  entry: string | null;         // HH:MM
  exit: string | null;          // HH:MM
  scheduleStart: string;
  scheduleEnd: string;
  workedMin: number;
  lateMin: number;
  earlyMin: number;
  overtimeMin: number;
  missingExit: boolean;
  /** Absence saisie à la main (écran Absences) ce jour-là. */
  recordedAbsence: boolean;
}

export interface MonthSummary {
  days: DayRecord[];
  workingDays: number;          // jours ouvrables du mois (hors repos), dans le contrat
  presentDays: number;
  absentDays: number;           // absences NON saisies (déduites par le pointage)
  recordedAbsences: number;     // déjà saisies dans « Absences »
  restWorkedDays: number;       // jours de repos où l'employé est venu
  lateCount: number;
  lateMin: number;
  earlyCount: number;
  earlyMin: number;
  workedMin: number;
  overtimeMin: number;
  missingExitCount: number;
  scheduledMinPerDay: number;
}

// ------------------------------------------------------------ helpers --
const pad = (n: number) => String(n).padStart(2, '0');
export const toMin = (hhmm: string) => {
  const [h, m] = (hhmm || '0:0').split(':').map(Number);
  return (h || 0) * 60 + (m || 0);
};
export const fmtMin = (min: number) => {
  if (!min) return '—';
  const h = Math.floor(min / 60);
  const m = Math.round(min % 60);
  return h ? `${h} h ${pad(m)}` : `${m} min`;
};
export const isoDate = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export const punchDate = (p: AttendancePunch) => p.punchedAt.slice(0, 10);
export const punchTime = (p: AttendancePunch) => p.punchedAt.slice(11, 16);
export const punchTimeSec = (p: AttendancePunch) => p.punchedAt.slice(11, 19);

/** « 2026-10 » → bornes du mois */
export function monthRange(month: string): { from: string; to: string; days: string[] } {
  const [y, m] = month.split('-').map(Number);
  const last = new Date(y, m, 0).getDate();
  const days = Array.from({ length: last }, (_, i) => `${y}-${pad(m)}-${pad(i + 1)}`);
  return { from: days[0], to: days[days.length - 1], days };
}
export const currentMonth = () => isoDate(new Date()).slice(0, 7);
export const monthLabel = (month: string) => {
  const [y, m] = month.split('-').map(Number);
  return `${MONTHS[m - 1]} ${y}`;
};
/** les 12 derniers mois, le plus récent d'abord */
export function lastMonths(n = 12): { value: string; label: string }[] {
  const out: { value: string; label: string }[] = [];
  const d = new Date();
  d.setDate(1);
  for (let i = 0; i < n; i++) {
    const v = isoDate(d).slice(0, 7);
    out.push({ value: v, label: monthLabel(v) });
    d.setMonth(d.getMonth() - 1);
  }
  return out;
}

export function scheduleOf(worker: Pick<Worker, 'workStart' | 'workEnd'>, s: AttendanceSettings) {
  return { start: worker.workStart || s.workStart, end: worker.workEnd || s.workEnd };
}

// ------------------------------------------------------------ calcul --
export function computeDay(
  date: string,
  punches: AttendancePunch[],
  worker: Worker,
  s: AttendanceSettings,
  today = isoDate(new Date()),
): DayRecord {
  const weekday = new Date(`${date}T12:00:00`).getDay();
  const { start, end } = scheduleOf(worker, s);
  const sorted = [...punches].sort((a, b) => a.punchedAt.localeCompare(b.punchedAt));
  const isRest = s.restDays.includes(weekday);
  const recordedAbsence = worker.absences.some((a) => a.date?.slice(0, 10) === date);

  const base: DayRecord = {
    date, weekday, status: 'present', punches: sorted, entry: null, exit: null,
    scheduleStart: start, scheduleEnd: end, workedMin: 0, lateMin: 0, earlyMin: 0,
    overtimeMin: 0, missingExit: false, recordedAbsence,
  };

  if (worker.startDate && date < worker.startDate.slice(0, 10) && !sorted.length) return { ...base, status: 'before' };
  if (date > today) return { ...base, status: 'future' };

  if (!sorted.length) {
    if (isRest) return { ...base, status: 'rest' };
    if (recordedAbsence) return { ...base, status: 'recorded' };
    if (date === today) return { ...base, status: 'pending' };
    return { ...base, status: 'absent' };
  }

  const first = sorted[0];
  const last = sorted[sorted.length - 1];
  const entryMin = toMin(punchTime(first));
  const hasExit = sorted.length > 1 && toMin(punchTime(last)) - entryMin >= 1;
  const exitMin = hasExit ? toMin(punchTime(last)) : null;
  const startMin = toMin(start);
  const endMin = toMin(end);

  const late = entryMin - startMin;
  const early = exitMin !== null ? endMin - exitMin : 0;
  const over = exitMin !== null ? exitMin - endMin : 0;

  return {
    ...base,
    status: 'present',
    entry: punchTime(first),
    exit: hasExit ? punchTime(last) : null,
    workedMin: exitMin !== null ? exitMin - entryMin : 0,
    lateMin: !isRest && late > s.lateToleranceMin ? late : 0,
    earlyMin: !isRest && exitMin !== null && early > s.earlyToleranceMin ? early : 0,
    overtimeMin: exitMin !== null && over >= s.minOvertimeMin ? over : 0,
    missingExit: !hasExit && date < today,
  };
}

export function computeMonth(
  month: string,
  punches: AttendancePunch[],
  worker: Worker,
  s: AttendanceSettings,
): MonthSummary {
  const { days } = monthRange(month);
  const today = isoDate(new Date());
  const byDay = new Map<string, AttendancePunch[]>();
  for (const p of punches) {
    if (p.workerId !== worker.id) continue;
    const d = punchDate(p);
    byDay.set(d, [...(byDay.get(d) ?? []), p]);
  }
  const records = days.map((d) => computeDay(d, byDay.get(d) ?? [], worker, s, today));
  const { start, end } = scheduleOf(worker, s);
  const startDate = worker.startDate?.slice(0, 10) ?? '';

  const sum: MonthSummary = {
    days: records,
    workingDays: days.filter((d) => {
      const wd = new Date(`${d}T12:00:00`).getDay();
      return !s.restDays.includes(wd) && (!startDate || d >= startDate);
    }).length,
    presentDays: 0, absentDays: 0, recordedAbsences: 0, restWorkedDays: 0,
    lateCount: 0, lateMin: 0, earlyCount: 0, earlyMin: 0, workedMin: 0, overtimeMin: 0,
    missingExitCount: 0,
    scheduledMinPerDay: Math.max(60, toMin(end) - toMin(start)),
  };
  for (const r of records) {
    if (r.status === 'present') {
      sum.presentDays++;
      if (s.restDays.includes(r.weekday)) sum.restWorkedDays++;
    }
    if (r.status === 'absent') sum.absentDays++;
    if (r.status === 'recorded') sum.recordedAbsences++;
    if (r.lateMin) { sum.lateCount++; sum.lateMin += r.lateMin; }
    if (r.earlyMin) { sum.earlyCount++; sum.earlyMin += r.earlyMin; }
    if (r.missingExit) sum.missingExitCount++;
    sum.workedMin += r.workedMin;
    sum.overtimeMin += r.overtimeMin;
  }
  return sum;
}

// --------------------------------------------------------------- paie --
export interface AttendancePay {
  dailyRate: number;
  minuteRate: number;
  /** salaire de base de la période (journalier : jours présents × tarif) */
  base: number;
  absenceDeduction: number;
  lateDeduction: number;
}

export function attendancePay(worker: Worker, sum: MonthSummary, s: AttendanceSettings): AttendancePay {
  const daily = worker.paymentType === 'daily';
  const dailyRate = daily ? worker.paymentAmount : worker.paymentAmount / Math.max(1, sum.workingDays);
  const minuteRate = dailyRate / sum.scheduledMinPerDay;
  const round = (n: number) => Math.round(n);
  return {
    dailyRate,
    minuteRate,
    base: daily ? round(sum.presentDays * worker.paymentAmount) : worker.paymentAmount,
    // journalier : l'absence n'est simplement pas payée (déjà dans la base)
    absenceDeduction: !daily && s.deductAbsences ? round(sum.absentDays * dailyRate) : 0,
    lateDeduction: s.deductLate ? round((sum.lateMin + sum.earlyMin) * minuteRate) : 0,
  };
}

export const STATUS_LABEL: Record<DayStatus, string> = {
  present: 'Présent',
  absent: 'Absent',
  recorded: 'Absence saisie',
  rest: 'Repos',
  pending: 'Pas encore pointé',
  future: '—',
  before: 'Avant embauche',
};

/** Commandes du protocole PUSH (séparateur = tabulation) */
export const zkCommands = {
  /** Nom ASCII, 24 caractères max (afficheur de la pointeuse) */
  userInfo: (pin: string, name: string) => {
    const clean = name.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^\x20-\x7e]/g, '').slice(0, 24);
    return `DATA UPDATE USERINFO PIN=${pin}\tName=${clean}\tPri=0\tPasswd=\tCard=\tGrp=1\tTZ=0000000100000000\tVerify=0`;
  },
  deleteUser: (pin: string) => `DATA DELETE USERINFO PIN=${pin}`,
  enrollFinger: (pin: string, fid = 0) => `ENROLL_FP PIN=${pin}\tFID=${fid}\tRETRY=3\tOVERWRITE=1`,
  queryLogs: (from: string, to: string) => `DATA QUERY ATTLOG StartTime=${from} 00:00:00\tEndTime=${to} 23:59:59`,
  info: () => 'INFO',
  reboot: () => 'REBOOT',
};
