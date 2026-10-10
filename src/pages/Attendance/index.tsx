import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Fingerprint, Users, UserCheck, UserX, AlertTriangle, Wifi, WifiOff, RefreshCw,
  Send, Copy, KeyRound, Settings2, Save, History, Eye, Trash2, Download, Printer,
} from 'lucide-react';
import { PageHeader } from '@/components/layout/PageHeader';
import { StatCard } from '@/components/shared/StatCard';
import { Tabs } from '@/components/ui/Tabs';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { Input } from '@/components/ui/Input';
import { Select } from '@/components/ui/Select';
import { Switch } from '@/components/ui/Switch';
import { Modal } from '@/components/ui/Modal';
import { SearchBar } from '@/components/ui/SearchBar';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { useAttendanceStore } from '@/store/attendanceStore';
import { useWorkerStore } from '@/store/workerStore';
import { useSettingsStore } from '@/store/settingsStore';
import { usePermissions } from '@/hooks/usePermissions';
import { WorkerAttendance } from '@/pages/Workers/WorkerAttendance';
import {
  computeDay, computeMonth, attendancePay, currentMonth, lastMonths, monthRange, monthLabel,
  fmtMin, punchDate, punchTimeSec, verifyLabel, isoDate, zkCommands, WEEKDAYS, STATUS_LABEL,
} from '@/lib/attendance';
import { printDetailedReport } from '@/lib/reportPrint';
import { formatCurrency, formatDateTime, todayISO } from '@/lib/utils';
import { toast } from '@/components/ui/Toast';
import type { AttendancePunch, AttendanceSettings } from '@/types';

type Tab = 'today' | 'month' | 'journal' | 'device' | 'settings';

const ONLINE_MS = 3 * 60 * 1000;

export default function AttendancePage() {
  const { can, isAdmin } = usePermissions();
  const workers = useWorkerStore((s) => s.workers);
  const store = useSettingsStore((s) => s.settings);
  const {
    ready, settings, devices, commands, loadMeta, fetchPunches, queueCommands, clearCommands,
    saveSettings, getToken, regenerateToken,
  } = useAttendanceStore();

  const [tab, setTab] = useState<Tab>('today');
  const [day, setDay] = useState(todayISO());
  const [month, setMonth] = useState(currentMonth());
  const [dayPunches, setDayPunches] = useState<AttendancePunch[]>([]);
  const [monthPunches, setMonthPunches] = useState<AttendancePunch[]>([]);
  const [journal, setJournal] = useState<AttendancePunch[]>([]);
  const [jFrom, setJFrom] = useState(isoDate(new Date(Date.now() - 6 * 864e5)));
  const [jTo, setJTo] = useState(todayISO());
  const [jSearch, setJSearch] = useState('');
  const [detailId, setDetailId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [token, setToken] = useState('');
  const [confirmRegen, setConfirmRegen] = useState(false);
  const [histFrom, setHistFrom] = useState(isoDate(new Date(Date.now() - 30 * 864e5)));

  const tracked = useMemo(() => workers.filter((w) => w.badgePin), [workers]);
  const workerOf = (id: string | null) => workers.find((w) => w.id === id);
  const detail = workers.find((w) => w.id === detailId) ?? null;

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      await loadMeta();
      const { from, to } = monthRange(month);
      const [d, m] = await Promise.all([fetchPunches(day, day), fetchPunches(from, to)]);
      setDayPunches(d);
      setMonthPunches(m);
    } finally {
      setLoading(false);
    }
  }, [day, month, loadMeta, fetchPunches]);

  useEffect(() => { void refresh(); }, [refresh]);
  // les pointages arrivent en direct : rafraîchissement toutes les 30 s
  useEffect(() => {
    const t = setInterval(() => { void refresh(); }, 30_000);
    return () => clearInterval(t);
  }, [refresh]);

  const loadJournal = useCallback(async () => setJournal(await fetchPunches(jFrom, jTo)), [jFrom, jTo, fetchPunches]);
  useEffect(() => { if (tab === 'journal') void loadJournal(); }, [tab, loadJournal]);
  useEffect(() => {
    if (tab === 'device' && isAdmin && ready && !token) void getToken().then(setToken).catch(() => undefined);
  }, [tab, isAdmin, ready, token, getToken]);

  // ---------------------------------------------------------------- jour --
  const todayRows = useMemo(() => tracked.map((w) => {
    const rec = computeDay(day, dayPunches.filter((p) => p.workerId === w.id), w, settings);
    return { w, rec };
  }).sort((a, b) => (a.rec.entry ?? '99').localeCompare(b.rec.entry ?? '99')), [tracked, day, dayPunches, settings]);
  const unknownToday = dayPunches.filter((p) => !p.workerId);
  const counts = {
    present: todayRows.filter((r) => r.rec.status === 'present').length,
    absent: todayRows.filter((r) => r.rec.status === 'absent' || r.rec.status === 'pending').length,
    late: todayRows.filter((r) => r.rec.lateMin > 0).length,
  };

  // --------------------------------------------------------------- mois --
  const monthRows = useMemo(() => tracked.map((w) => {
    const sum = computeMonth(month, monthPunches, w, settings);
    return { w, sum, pay: attendancePay(w, sum, settings) };
  }), [tracked, month, monthPunches, settings]);

  const online = devices.some((d) => d.lastSeen && Date.now() - new Date(d.lastSeen).getTime() < ONLINE_MS);

  const syncAll = async () => {
    if (!tracked.length) { toast.error("Aucun employé n'a de N° pointeuse"); return; }
    await queueCommands(tracked.map((w) => ({ command: zkCommands.userInfo(w.badgePin!, w.fullName), label: `Employé ${w.fullName}` })));
    toast.success(`${tracked.length} employé(s) envoyé(s) à la pointeuse`);
  };
  const fetchHistory = async () => {
    await queueCommands([{ command: zkCommands.queryLogs(histFrom, todayISO()), label: `Historique depuis ${histFrom}` }]);
    toast.success("Demande envoyée — l'historique arrive dans quelques instants");
  };

  const printMonth = () => {
    printDetailedReport({
      docTitle: `Pointage ${monthLabel(month)}`,
      headTitle: 'ÉTAT DE POINTAGE MENSUEL',
      subtitle: monthLabel(month),
      sections: [{
        title: 'Employés',
        cols: [
          { label: 'Employé' }, { label: 'N°', align: 'center' }, { label: 'Présent', align: 'center' },
          { label: 'Absences', align: 'center' }, { label: 'Retards', align: 'center' },
          { label: 'Départs ant.', align: 'center' }, { label: 'Travaillé', align: 'center' },
          { label: 'H. sup.', align: 'center' }, { label: 'Retenue', align: 'right' },
        ],
        rows: monthRows.map(({ w, sum, pay }) => ({
          cells: [
            w.fullName, w.badgePin ?? '', `${sum.presentDays}/${sum.workingDays}`,
            String(sum.absentDays + sum.recordedAbsences), `${sum.lateCount} · ${fmtMin(sum.lateMin)}`,
            `${sum.earlyCount} · ${fmtMin(sum.earlyMin)}`, fmtMin(sum.workedMin), fmtMin(sum.overtimeMin),
            formatCurrency(pay.absenceDeduction + pay.lateDeduction),
          ],
          tone: 'neg',
        })),
      }],
    }, store);
  };

  if (!ready) {
    return (
      <div className="space-y-6">
        <PageHeader title="Pointage" icon={<Fingerprint size={24} />} subtitle="Pointeuse ZKTeco" />
        <div className="rounded-2xl border border-caramel/40 bg-caramel/10 p-5 text-sm text-caramel">
          Le module pointeuse n'est pas encore installé : dans Supabase › SQL Editor, exécutez
          <b> supabase/parts/10_pointeuse.sql</b>, puis rechargez cette page.
        </div>
      </div>
    );
  }

  const tabs = [
    { id: 'today', label: "Aujourd'hui" },
    { id: 'month', label: 'Mensuel' },
    { id: 'journal', label: 'Journal' },
    { id: 'device', label: 'Pointeuse' },
    ...(can('workers', 'edit') ? [{ id: 'settings', label: 'Paramètres' }] : []),
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Pointage"
        icon={<Fingerprint size={24} />}
        subtitle={`${tracked.length} employé(s) suivis · horaires ${settings.workStart} → ${settings.workEnd}`}
        actions={
          <div className="flex items-center gap-2">
            <Badge variant={online ? 'success' : 'warning'} className="gap-1">
              {online ? <Wifi size={12} /> : <WifiOff size={12} />} {online ? 'Pointeuse connectée' : 'Pointeuse hors ligne'}
            </Badge>
            <Button variant="secondary" size="sm" onClick={() => void refresh()} disabled={loading}>
              <RefreshCw size={14} className={loading ? 'animate-spin' : ''} /> Actualiser
            </Button>
          </div>
        }
      />

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard label="Employés suivis" value={tracked.length} icon={<Users size={22} />} index={0} accent="gold" />
        <StatCard label="Présents" value={counts.present} icon={<UserCheck size={22} />} index={1} accent="pistachio" />
        <StatCard label="Absents / pas pointé" value={counts.absent} icon={<UserX size={22} />} index={2} accent="caramel" />
        <StatCard label="En retard" value={counts.late} icon={<AlertTriangle size={22} />} index={3} accent="lavender" />
      </div>

      <Tabs tabs={tabs} active={tab} onChange={(t) => setTab(t as Tab)} className="flex-wrap" />

      {/* ------------------------------------------------------ AUJOURD'HUI */}
      {tab === 'today' && (
        <div className="space-y-3">
          <div className="flex flex-wrap items-end gap-3">
            <Input label="Jour" type="date" value={day} onChange={(e) => setDay(e.target.value)} className="max-w-[200px]" />
            <span className="text-sm text-text-muted pb-2">{WEEKDAYS[new Date(`${day}T12:00:00`).getDay()]}</span>
          </div>
          {tracked.length === 0 ? (
            <Empty text="Aucun employé n'a de N° pointeuse. Ouvrez Employés › Modifier et renseignez « N° pointeuse »." />
          ) : (
            <div className="overflow-x-auto rounded-xl border border-gold/15">
              <table className="w-full text-sm">
                <thead className="bg-vanilla/60 text-text-secondary text-xs">
                  <tr>
                    <th className="text-left px-3 py-2">Employé</th>
                    <th className="text-center px-2 py-2">N°</th>
                    <th className="text-center px-2 py-2">Entrée</th>
                    <th className="text-center px-2 py-2">Sortie</th>
                    <th className="text-center px-2 py-2">Pointages</th>
                    <th className="text-center px-2 py-2">Retard</th>
                    <th className="text-center px-2 py-2">Travaillé</th>
                    <th className="text-left px-2 py-2">Statut</th>
                    <th className="px-2 py-2"></th>
                  </tr>
                </thead>
                <tbody>
                  {todayRows.map(({ w, rec }) => (
                    <tr key={w.id} className="border-t border-gold/10 hover:bg-gold/5">
                      <td className="px-3 py-2 font-semibold text-text-primary">{w.fullName}</td>
                      <td className="px-2 py-2 text-center tabular text-text-muted">{w.badgePin}</td>
                      <td className={`px-2 py-2 text-center tabular font-bold ${rec.lateMin ? 'text-caramel' : ''}`}>{rec.entry ?? '—'}</td>
                      <td className={`px-2 py-2 text-center tabular font-bold ${rec.earlyMin ? 'text-caramel' : ''}`}>{rec.exit ?? '—'}</td>
                      <td className="px-2 py-2 text-center text-xs tabular text-text-muted">
                        {rec.punches.map((p) => p.punchedAt.slice(11, 16)).join(' · ') || '—'}
                      </td>
                      <td className="px-2 py-2 text-center text-xs text-caramel">{rec.lateMin ? fmtMin(rec.lateMin) : '—'}</td>
                      <td className="px-2 py-2 text-center text-xs">{fmtMin(rec.workedMin)}</td>
                      <td className="px-2 py-2">
                        <Badge variant={rec.status === 'present' ? 'success' : rec.status === 'absent' ? 'danger' : 'neutral'} className="text-[10px]">
                          {STATUS_LABEL[rec.status]}
                        </Badge>
                      </td>
                      <td className="px-2 py-2 text-right">
                        <Button size="icon" variant="ghost" title="Détails" onClick={() => setDetailId(w.id)}><Eye size={15} /></Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {unknownToday.length > 0 && (
            <div className="rounded-xl border border-caramel/40 bg-caramel/10 px-4 py-3 text-xs text-caramel">
              <b>{unknownToday.length} pointage(s) d'un N° inconnu</b> :{' '}
              {[...new Set(unknownToday.map((p) => p.pin))].map((pin) => `N° ${pin}`).join(', ')} — attribuez ce N° à un employé
              (Employés › Modifier › N° pointeuse) : ses pointages lui seront rattachés automatiquement.
            </div>
          )}
        </div>
      )}

      {/* ----------------------------------------------------------- MOIS */}
      {tab === 'month' && (
        <div className="space-y-3">
          <div className="flex flex-wrap items-end gap-3">
            <Select label="Mois" value={month} onChange={(e) => setMonth(e.target.value)} options={lastMonths(24)} className="max-w-[200px]" />
            <Button variant="secondary" size="sm" onClick={printMonth}><Printer size={14} /> Imprimer</Button>
          </div>
          <div className="overflow-x-auto rounded-xl border border-gold/15">
            <table className="w-full text-sm">
              <thead className="bg-vanilla/60 text-text-secondary text-xs">
                <tr>
                  <th className="text-left px-3 py-2">Employé</th>
                  <th className="text-center px-2 py-2">Présent</th>
                  <th className="text-center px-2 py-2">Absences</th>
                  <th className="text-center px-2 py-2">Retards</th>
                  <th className="text-center px-2 py-2">Départs ant.</th>
                  <th className="text-center px-2 py-2">Travaillé</th>
                  <th className="text-center px-2 py-2">H. sup.</th>
                  <th className="text-right px-2 py-2">Retenue paie</th>
                  <th className="px-2 py-2"></th>
                </tr>
              </thead>
              <tbody>
                {monthRows.length === 0 && (
                  <tr><td colSpan={9} className="px-3 py-6 text-center text-text-muted">Aucun employé suivi</td></tr>
                )}
                {monthRows.map(({ w, sum, pay }) => (
                  <tr key={w.id} className="border-t border-gold/10 hover:bg-gold/5 cursor-pointer" onClick={() => setDetailId(w.id)}>
                    <td className="px-3 py-2 font-semibold text-text-primary">{w.fullName}</td>
                    <td className="px-2 py-2 text-center tabular text-pistachio font-bold">{sum.presentDays}/{sum.workingDays}</td>
                    <td className="px-2 py-2 text-center tabular text-rose-deep">{sum.absentDays}{sum.recordedAbsences ? ` (+${sum.recordedAbsences})` : ''}</td>
                    <td className="px-2 py-2 text-center text-xs text-caramel">{sum.lateCount} · {fmtMin(sum.lateMin)}</td>
                    <td className="px-2 py-2 text-center text-xs">{sum.earlyCount} · {fmtMin(sum.earlyMin)}</td>
                    <td className="px-2 py-2 text-center text-xs">{fmtMin(sum.workedMin)}</td>
                    <td className="px-2 py-2 text-center text-xs text-pistachio">{fmtMin(sum.overtimeMin)}</td>
                    <td className="px-2 py-2 text-right tabular font-bold text-rose-deep">{formatCurrency(pay.absenceDeduction + pay.lateDeduction)}</td>
                    <td className="px-2 py-2 text-right"><Eye size={15} className="text-text-muted inline" /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* -------------------------------------------------------- JOURNAL */}
      {tab === 'journal' && (
        <div className="space-y-3">
          <div className="flex flex-wrap items-end gap-3">
            <Input label="Du" type="date" value={jFrom} onChange={(e) => setJFrom(e.target.value)} className="max-w-[180px]" />
            <Input label="Au" type="date" value={jTo} onChange={(e) => setJTo(e.target.value)} className="max-w-[180px]" />
            <div className="flex-1 min-w-[200px]"><SearchBar value={jSearch} onChange={setJSearch} placeholder="Employé ou N°…" /></div>
          </div>
          <div className="overflow-x-auto rounded-xl border border-gold/15 max-h-[60vh]">
            <table className="w-full text-sm">
              <thead className="bg-vanilla/60 text-text-secondary text-xs sticky top-0">
                <tr>
                  <th className="text-left px-3 py-2">Date</th>
                  <th className="text-center px-2 py-2">Heure</th>
                  <th className="text-left px-2 py-2">Employé</th>
                  <th className="text-center px-2 py-2">N°</th>
                  <th className="text-left px-2 py-2">Mode</th>
                  <th className="text-left px-2 py-2">Pointeuse</th>
                </tr>
              </thead>
              <tbody>
                {[...journal].reverse()
                  .filter((p) => {
                    const q = jSearch.toLowerCase();
                    return !q || p.pin.includes(q) || (workerOf(p.workerId)?.fullName.toLowerCase().includes(q) ?? false);
                  })
                  .slice(0, 1000)
                  .map((p) => (
                    <tr key={p.id} className="border-t border-gold/10">
                      <td className="px-3 py-1.5 text-xs">{punchDate(p).split('-').reverse().join('/')}</td>
                      <td className="px-2 py-1.5 text-center tabular font-bold">{punchTimeSec(p)}</td>
                      <td className="px-2 py-1.5">{workerOf(p.workerId)?.fullName ?? <span className="text-caramel">N° inconnu</span>}</td>
                      <td className="px-2 py-1.5 text-center tabular text-text-muted">{p.pin}</td>
                      <td className="px-2 py-1.5 text-xs text-text-muted">{verifyLabel(p.verify, p.source)}{p.note ? ` · ${p.note}` : ''}</td>
                      <td className="px-2 py-1.5 text-xs text-text-muted">{p.deviceSn || '—'}</td>
                    </tr>
                  ))}
                {journal.length === 0 && (
                  <tr><td colSpan={6} className="px-3 py-6 text-center text-text-muted">Aucun pointage sur cette période</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ------------------------------------------------------ POINTEUSE */}
      {tab === 'device' && (
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
          <section className="rounded-2xl border border-gold/15 bg-vanilla/30 p-4 space-y-3">
            <h3 className="font-semibold text-text-primary flex items-center gap-2"><Wifi size={16} className="text-gold" /> Pointeuses</h3>
            {devices.length === 0 ? (
              <p className="text-sm text-text-muted">
                Aucune pointeuse n'a encore contacté la passerelle. Suivez le guide de connexion (README › Pointeuse).
              </p>
            ) : devices.map((d) => {
              const on = d.lastSeen && Date.now() - new Date(d.lastSeen).getTime() < ONLINE_MS;
              return (
                <div key={d.sn} className="rounded-xl border border-gold/15 bg-chocolate px-3 py-2 text-sm flex flex-wrap items-center gap-2">
                  <Badge variant={on ? 'success' : 'warning'}>{on ? 'En ligne' : 'Hors ligne'}</Badge>
                  <b>{d.sn}</b>
                  <span className="text-text-muted text-xs">IP {d.ip || '—'} · vue {d.lastSeen ? formatDateTime(d.lastSeen) : '—'}</span>
                </div>
              );
            })}
            {can('workers', 'edit') && (
              <div className="space-y-2 pt-2 border-t border-gold/10">
                <Button variant="liver" size="sm" onClick={() => void syncAll()}>
                  <Send size={14} /> Envoyer tous les employés à la pointeuse ({tracked.length})
                </Button>
                <div className="flex flex-wrap items-end gap-2">
                  <Input label="Récupérer l'historique depuis le" type="date" value={histFrom} onChange={(e) => setHistFrom(e.target.value)} className="max-w-[220px]" />
                  <Button variant="secondary" size="sm" onClick={() => void fetchHistory()}><Download size={14} /> Récupérer</Button>
                </div>
              </div>
            )}
          </section>

          {isAdmin && (
            <section className="rounded-2xl border border-gold/25 bg-gold/5 p-4 space-y-3">
              <h3 className="font-semibold text-text-primary flex items-center gap-2"><KeyRound size={16} className="text-gold" /> Jeton de la passerelle</h3>
              <p className="text-xs text-text-muted">
                À coller dans <b>pointeuse/config.json</b> (champ « token ») sur le PC relié à la pointeuse. Ne le partagez pas.
              </p>
              <div className="flex gap-2">
                <code className="flex-1 truncate rounded-lg border border-gold/20 bg-chocolate px-3 py-2 text-xs">{token || '…'}</code>
                <Button size="sm" variant="secondary" onClick={() => { void navigator.clipboard.writeText(token); toast.success('Jeton copié'); }}>
                  <Copy size={14} /> Copier
                </Button>
              </div>
              <Button size="sm" variant="ghost" onClick={() => setConfirmRegen(true)}><RefreshCw size={14} /> Générer un nouveau jeton</Button>
            </section>
          )}

          <section className="rounded-2xl border border-gold/15 bg-vanilla/30 p-4 space-y-2 xl:col-span-2">
            <div className="flex items-center justify-between">
              <h3 className="font-semibold text-text-primary flex items-center gap-2"><History size={16} className="text-gold" /> Commandes envoyées</h3>
              {can('workers', 'delete') && commands.length > 0 && (
                <Button size="sm" variant="ghost" onClick={() => void clearCommands()}><Trash2 size={14} /> Vider</Button>
              )}
            </div>
            {commands.length === 0 ? <p className="text-sm text-text-muted">Aucune commande.</p> : (
              <div className="overflow-x-auto">
                <table className="w-full text-xs">
                  <tbody>
                    {commands.map((c) => (
                      <tr key={c.id} className="border-t border-gold/10">
                        <td className="px-2 py-1.5 tabular text-text-muted">#{c.id}</td>
                        <td className="px-2 py-1.5">{c.label || c.command.split('\t')[0]}</td>
                        <td className="px-2 py-1.5">
                          <Badge
                            variant={c.status === 'done' ? 'success' : c.status === 'error' ? 'danger' : c.status === 'sent' ? 'info' : 'warning'}
                            className="text-[10px]"
                          >
                            {c.status === 'done' ? 'Exécutée' : c.status === 'error' ? `Erreur ${c.returnCode}` : c.status === 'sent' ? 'Envoyée' : 'En attente'}
                          </Badge>
                        </td>
                        <td className="px-2 py-1.5 text-text-muted">{formatDateTime(c.createdAt)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>
      )}

      {/* ----------------------------------------------------- PARAMÈTRES */}
      {tab === 'settings' && <SettingsForm initial={settings} onSave={saveSettings} />}

      <Modal open={!!detail} onClose={() => setDetailId(null)} title={`Pointage — ${detail?.fullName ?? ''}`} size="xl">
        {detail && <WorkerAttendance worker={detail} />}
      </Modal>

      <ConfirmDialog
        open={confirmRegen}
        onClose={() => setConfirmRegen(false)}
        onConfirm={() => { void regenerateToken().then((t) => { setToken(t); toast.success('Nouveau jeton — mettez à jour pointeuse/config.json'); }); }}
        title="Nouveau jeton"
        message="L'ancien jeton cessera de fonctionner : la passerelle devra être reconfigurée avec le nouveau."
      />
    </div>
  );
}

function SettingsForm({ initial, onSave }: { initial: AttendanceSettings; onSave: (s: AttendanceSettings) => Promise<void> }) {
  const [f, setF] = useState(initial);
  const [saving, setSaving] = useState(false);
  useEffect(() => setF(initial), [initial]);
  const set = <K extends keyof AttendanceSettings>(k: K, v: AttendanceSettings[K]) => setF((x) => ({ ...x, [k]: v }));

  return (
    <div className="rounded-2xl border border-gold/15 bg-vanilla/30 p-4 space-y-4 max-w-3xl">
      <h3 className="font-semibold text-text-primary flex items-center gap-2"><Settings2 size={16} className="text-gold" /> Horaires et règles</h3>
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
        <Input label="Début de travail" type="time" value={f.workStart} onChange={(e) => set('workStart', e.target.value)} />
        <Input label="Fin de travail" type="time" value={f.workEnd} onChange={(e) => set('workEnd', e.target.value)} />
        <Input label="Tolérance retard (min)" type="number" value={f.lateToleranceMin} onChange={(e) => set('lateToleranceMin', Number(e.target.value))} />
        <Input label="Tolérance départ anticipé (min)" type="number" value={f.earlyToleranceMin} onChange={(e) => set('earlyToleranceMin', Number(e.target.value))} />
        <Input label="Heures sup. à partir de (min)" type="number" value={f.minOvertimeMin} onChange={(e) => set('minOvertimeMin', Number(e.target.value))} />
      </div>
      <div>
        <p className="text-sm font-medium text-text-secondary mb-2">Jours de repos</p>
        <div className="flex flex-wrap gap-2">
          {WEEKDAYS.map((d, i) => {
            const on = f.restDays.includes(i);
            return (
              <button
                key={d}
                onClick={() => set('restDays', on ? f.restDays.filter((x) => x !== i) : [...f.restDays, i].sort())}
                className={`px-3 py-1.5 rounded-lg text-sm border transition-colors ${on ? 'bg-gradient-button text-white border-red-800/50' : 'border-gold/20 text-text-secondary hover:bg-gold/10'}`}
              >
                {d}
              </button>
            );
          })}
        </div>
      </div>
      <div className="space-y-2">
        <Switch checked={f.deductAbsences} onChange={(v) => set('deductAbsences', v)} label="Déduire les absences non justifiées du salaire mensuel" />
        <Switch checked={f.deductLate} onChange={(v) => set('deductLate', v)} label="Déduire les retards et départs anticipés (à la minute)" />
      </div>
      <p className="text-xs text-text-muted">
        Taux journalier = salaire mensuel ÷ jours ouvrables du mois. Un employé journalier est payé pour chaque jour pointé.
        Une absence déjà saisie dans « Absences » n'est jamais déduite deux fois.
      </p>
      <Button
        variant="gold" disabled={saving}
        onClick={async () => { setSaving(true); try { await onSave(f); toast.success('Paramètres enregistrés'); } finally { setSaving(false); } }}
      >
        <Save size={16} /> Enregistrer
      </Button>
    </div>
  );
}

function Empty({ text }: { text: string }) {
  return <div className="rounded-2xl border border-gold/15 bg-vanilla/30 px-4 py-8 text-center text-sm text-text-muted">{text}</div>;
}
