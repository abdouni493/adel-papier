/* eslint-disable @typescript-eslint/no-explicit-any */
import { create } from 'zustand';
import type {
  AttendanceCommand, AttendanceDevice, AttendancePunch, AttendanceSettings,
} from '@/types';
import { supabase } from '@/lib/supabase';
import { save } from '@/lib/persist';
import { DEFAULT_ATTENDANCE_SETTINGS } from '@/lib/attendance';

/* Pointeuse ZKTeco — supabase/parts/10_pointeuse.sql */

const toPunch = (r: any): AttendancePunch => ({
  id: Number(r.id),
  deviceSn: r.device_sn ?? '',
  pin: r.pin ?? '',
  workerId: r.worker_id ?? null,
  punchedAt: String(r.punched_at).replace(' ', 'T'),
  status: Number(r.status ?? 0),
  verify: Number(r.verify ?? 0),
  source: r.source === 'manual' ? 'manual' : 'device',
  note: r.note ?? '',
});

const toSettings = (r: any): AttendanceSettings => ({
  workStart: String(r.work_start ?? '08:00').slice(0, 5),
  workEnd: String(r.work_end ?? '16:00').slice(0, 5),
  lateToleranceMin: Number(r.late_tolerance_min ?? 10),
  earlyToleranceMin: Number(r.early_tolerance_min ?? 10),
  minOvertimeMin: Number(r.min_overtime_min ?? 30),
  restDays: (r.rest_days ?? [5]).map(Number),
  deductAbsences: r.deduct_absences ?? true,
  deductLate: r.deduct_late ?? false,
});

const toDevice = (r: any): AttendanceDevice => ({
  sn: r.sn, name: r.name ?? r.sn, ip: r.ip ?? '', pushVersion: r.push_version ?? '',
  lastSeen: r.last_seen ?? null, lastPunchAt: r.last_punch_at ?? null,
});

const toCommand = (r: any): AttendanceCommand => ({
  id: Number(r.id), deviceSn: r.device_sn ?? '', command: r.command, label: r.label ?? '',
  status: r.status, returnCode: r.return_code ?? null, createdAt: r.created_at, doneAt: r.done_at ?? null,
});

const fail = (error: { message: string } | null) => { if (error) throw new Error(error.message); };

interface AttendanceState {
  /** false tant que le SQL 10_pointeuse.sql n'a pas été exécuté */
  ready: boolean;
  settings: AttendanceSettings;
  devices: AttendanceDevice[];
  commands: AttendanceCommand[];
  loadMeta: () => Promise<void>;
  /** pointages entre deux dates incluses (AAAA-MM-JJ), d'un employé ou de tous */
  fetchPunches: (from: string, to: string, workerId?: string) => Promise<AttendancePunch[]>;
  saveSettings: (s: AttendanceSettings) => Promise<void>;
  addManualPunch: (workerId: string, pin: string, at: string, note: string) => Promise<void>;
  deletePunch: (id: number) => Promise<void>;
  queueCommands: (items: { command: string; label: string }[], deviceSn?: string) => Promise<void>;
  clearCommands: () => Promise<void>;
  getToken: () => Promise<string>;
  regenerateToken: () => Promise<string>;
}

export const useAttendanceStore = create<AttendanceState>()((set, get) => ({
  ready: true,
  settings: DEFAULT_ATTENDANCE_SETTINGS,
  devices: [],
  commands: [],

  loadMeta: async () => {
    const [s, d, c] = await Promise.all([
      supabase.from('attendance_settings').select('*').eq('id', 1).maybeSingle(),
      supabase.from('attendance_devices').select('*').order('last_seen', { ascending: false }),
      supabase.from('attendance_commands').select('*').order('id', { ascending: false }).limit(50),
    ]);
    if (s.error && /does not exist|schema cache|PGRST205|42P01/i.test(s.error.message)) {
      set({ ready: false });
      return;
    }
    set({
      ready: true,
      settings: s.data ? toSettings(s.data) : DEFAULT_ATTENDANCE_SETTINGS,
      devices: (d.data ?? []).map(toDevice),
      commands: (c.data ?? []).map(toCommand),
    });
  },

  fetchPunches: async (from, to, workerId) => {
    const out: AttendancePunch[] = [];
    // pagination : PostgREST renvoie 1000 lignes au plus par requête
    for (let page = 0; page < 50; page++) {
      let q = supabase.from('attendance_punches').select('*')
        .gte('punched_at', `${from}T00:00:00`).lte('punched_at', `${to}T23:59:59`)
        .order('punched_at', { ascending: true })
        .range(page * 1000, page * 1000 + 999);
      if (workerId) q = q.eq('worker_id', workerId);
      const { data, error } = await q;
      if (error) {
        if (/does not exist|schema cache|PGRST205|42P01/i.test(error.message)) { set({ ready: false }); return []; }
        throw new Error(error.message);
      }
      out.push(...(data ?? []).map(toPunch));
      if (!data || data.length < 1000) break;
    }
    return out;
  },

  saveSettings: async (st) => {
    await save('attendance.settings', async () => {
      const { error } = await supabase.from('attendance_settings').upsert({
        id: 1,
        work_start: st.workStart, work_end: st.workEnd,
        late_tolerance_min: st.lateToleranceMin, early_tolerance_min: st.earlyToleranceMin,
        min_overtime_min: st.minOvertimeMin, rest_days: st.restDays,
        deduct_absences: st.deductAbsences, deduct_late: st.deductLate,
        updated_at: new Date().toISOString(),
      });
      fail(error);
    });
    set({ settings: st });
  },

  addManualPunch: async (workerId, pin, at, note) => {
    await save('attendance.manual', async () => {
      const { error } = await supabase.from('attendance_punches').insert({
        worker_id: workerId, pin: pin || `M-${workerId.slice(0, 8)}`,
        punched_at: at.length === 16 ? `${at}:00` : at, status: 0, verify: 0,
        source: 'manual', note,
      });
      fail(error);
    });
  },

  deletePunch: async (id) => {
    await save('attendance.delete', async () => {
      const { error } = await supabase.from('attendance_punches').delete().eq('id', id);
      fail(error);
    });
  },

  queueCommands: async (items, deviceSn) => {
    if (!items.length) return;
    await save('attendance.commands', async () => {
      const { error } = await supabase.from('attendance_commands').insert(
        items.map((i) => ({ command: i.command, label: i.label, device_sn: deviceSn ?? null }))
      );
      fail(error);
    });
    await get().loadMeta();
  },

  clearCommands: async () => {
    await save('attendance.commands.clear', async () => {
      const { error } = await supabase.from('attendance_commands').delete().in('status', ['done', 'error', 'pending', 'sent']);
      fail(error);
    });
    await get().loadMeta();
  },

  getToken: async () => {
    const { data, error } = await supabase.rpc('pointeuse_bridge_token');
    fail(error);
    return String(data ?? '');
  },

  regenerateToken: async () => save('attendance.token', async () => {
    const { data, error } = await supabase.rpc('pointeuse_regenerate_token');
    fail(error);
    return String(data ?? '');
  }),
}));
