import { create } from 'zustand';
import type {
  Worker, Role, Acompte, Absence, WorkerPaymentRecord, WorkerPermissions, WorkerOvertime,
} from '@/types';
import { supabase } from '@/lib/supabase';
import { db, rpc, remove as removeRow } from '@/lib/db';
import { save, trySave } from '@/lib/persist';
import { zkCommands, type AutoOvertime, type AutoLate } from '@/lib/attendance';

/** Envoie automatiquement l'employé à la pointeuse (file attendance_commands). */
async function pushToDevice(commands: { command: string; label: string }[]) {
  if (!commands.length) return;
  await trySave('attendance.autosync', async () => {
    const { error } = await supabase.from('attendance_commands').insert(commands);
    if (error) throw new Error(error.message);
  });
}

/** Decimal hours between "fin du travail" and "fin des heures supplémentaires". */
export function overtimeHours(
  workEndH: number, workEndM: number, otEndH: number, otEndM: number
): number {
  const start = workEndH * 60 + workEndM;
  let end = otEndH * 60 + otEndM;
  if (end < start) end += 24 * 60;          // the overtime ran past midnight
  return Math.max(0, (end - start) / 60);
}

interface WorkerState {
  workers: Worker[];
  roles: Role[];
  load: () => Promise<void>;
  addWorker: (w: Partial<Worker> & { password?: string }) => Promise<Worker>;
  updateWorker: (id: string, data: Partial<Worker> & { password?: string }) => Promise<Worker>;
  deleteWorker: (id: string) => Promise<void>;
  addRole: (name: string) => Promise<Role>;
  deleteRole: (id: string) => Promise<void>;
  setPermissions: (workerId: string, perms: WorkerPermissions) => Promise<void>;
  addAcompte: (workerId: string, adv: Omit<Acompte, 'id'>) => Promise<void>;
  deleteAcompte: (workerId: string, id: string) => Promise<void>;
  addAbsence: (workerId: string, abs: Omit<Absence, 'id'>) => Promise<void>;
  deleteAbsence: (workerId: string, id: string) => Promise<void>;
  addPayment: (workerId: string, p: Omit<WorkerPaymentRecord, 'id'>) => Promise<void>;
  deletePayment: (workerId: string, id: string) => Promise<void>;
  // ---- heures supplémentaires ----
  addOvertime: (data: Omit<WorkerOvertime, 'id' | 'isPaid'>) => Promise<void>;
  updateOvertime: (id: string, data: Partial<WorkerOvertime>) => Promise<void>;
  deleteOvertime: (workerId: string, id: string) => Promise<void>;
  payOvertimes: (workerId: string, ids: string[], date?: string, description?: string) => Promise<void>;
  // ---- pointeuse → paie ----
  /** Crée / met à jour / retire les heures sup. et retards calculés depuis la pointeuse (dates de `from` à `to`). */
  syncAttendance: (workerId: string, from: string, to: string, items: { overtimes: AutoOvertime[]; lates: AutoLate[] }) => Promise<void>;
  setOvertimeExcluded: (id: string, excluded: boolean) => Promise<void>;
  setLateStatus: (id: string, status: 'pending' | 'excluded') => Promise<void>;
  /** Salaire + heures sup. incluses (paiement séparé) + retards déduits. */
  paySalary: (workerId: string, p: Omit<WorkerPaymentRecord, 'id'>, settle: { overtimeIds: string[]; lateIds: string[] }) => Promise<void>;
}

const fail = (error: { message: string } | null) => { if (error) throw new Error(error.message); };
const hm = (t: string) => t.split(':').map(Number) as [number, number];

const overtimePayload = (d: Partial<WorkerOvertime>) => ({
  worker_id: d.workerId,
  date: d.date,
  work_end_hour: d.workEndHour,
  work_end_minute: d.workEndMinute,
  overtime_end_hour: d.overtimeEndHour,
  overtime_end_minute: d.overtimeEndMinute,
  hours: d.hours,
  hourly_rate: d.hourlyRate,
  amount: d.amount,
  description: d.description ?? '',
});

export const useWorkerStore = create<WorkerState>()((set, get) => {
  const reload = async () => set({ workers: await db.workers.list() });

  return {
    workers: [],
    roles: [],

    load: async () => {
      const [workers, roles] = await Promise.all([db.workers.list(), db.roles.list()]);
      set({ workers, roles });
    },

    addWorker: async (w) => {
      const row = await save('workers.create', () => db.workers.create(w));

      // A login account was requested → real row in the Supabase auth table
      if (w.hasAccount && w.email && w.password) {
        await save('workers.account', () =>
          rpc.createWorkerAccount(row.id, w.email!.trim(), w.password!, w.username?.trim() || undefined)
        );
      }
      // permissions are pushed through the dedicated RPC so `profiles` follows
      if (w.permissions && Object.keys(w.permissions).length) {
        await save('workers.permissions', () => rpc.setWorkerPermissions(row.id, w.permissions!));
      }
      if (w.badgePin) {
        await pushToDevice([{ command: zkCommands.userInfo(w.badgePin, w.fullName ?? ''), label: `Employé ${w.fullName}` }]);
      }
      await reload();
      return get().workers.find((x) => x.id === row.id) ?? row;
    },

    updateWorker: async (id, data) => {
      const before = get().workers.find((x) => x.id === id);
      const row = await save('workers.update', () => db.workers.update(id, data));

      if (data.hasAccount && data.email && data.password) {
        await save('workers.account', () =>
          rpc.createWorkerAccount(id, data.email!.trim(), data.password!, data.username?.trim() || undefined)
        );
      }
      // pointeuse : N° ou nom modifié → mise à jour de l'appareil (l'ancien N° est retiré)
      const pin = data.badgePin ?? before?.badgePin ?? '';
      const name = data.fullName ?? before?.fullName ?? '';
      const cmds: { command: string; label: string }[] = [];
      if (before?.badgePin && before.badgePin !== pin) {
        cmds.push({ command: zkCommands.deleteUser(before.badgePin), label: `Retrait N° ${before.badgePin}` });
      }
      if (pin && (pin !== before?.badgePin || name !== before?.fullName)) {
        cmds.push({ command: zkCommands.userInfo(pin, name), label: `Employé ${name}` });
      }
      await pushToDevice(cmds);
      await reload();
      return get().workers.find((x) => x.id === id) ?? row;
    },

    deleteWorker: async (id) => {
      const pin = get().workers.find((x) => x.id === id)?.badgePin;
      await save('workers.delete', () => db.workers.remove(id));
      if (pin) await pushToDevice([{ command: zkCommands.deleteUser(pin), label: `Retrait N° ${pin}` }]);
      set({ workers: get().workers.filter((w) => w.id !== id) });
    },

    addRole: async (name) => {
      const existing = get().roles.find((r) => r.name.toLowerCase() === name.toLowerCase());
      if (existing) return existing;
      const row = await save('roles.create', () => db.roles.create(name));
      set({ roles: [...get().roles, row] });
      return row;
    },

    deleteRole: async (id) => {
      await save('roles.delete', () => db.roles.remove(id));
      set({ roles: get().roles.filter((r) => r.id !== id) });
    },

    setPermissions: async (workerId, permissions) => {
      await save('workers.permissions', () => rpc.setWorkerPermissions(workerId, permissions));
      await reload();
    },

    addAcompte: async (workerId, adv) => {
      await save('workers.acompte', () =>
        rpc.addWorkerAcompte(workerId, adv.amount, adv.date, adv.description)
      );
      await reload();
    },

    deleteAcompte: async (workerId, id) => {
      await save('workers.acompte.delete', () => removeRow('worker_acomptes', id));
      await reload();
    },

    addAbsence: async (workerId, abs) => {
      await save('workers.absence', async () => {
        const { error } = await supabase.from('worker_absences').insert({
          worker_id: workerId, date: abs.date, description: abs.description, cost: abs.cost,
        });
        if (error) throw new Error(error.message);
      });
      await reload();
    },

    deleteAbsence: async (_workerId, id) => {
      await save('workers.absence.delete', () => removeRow('worker_absences', id));
      await reload();
    },

    addPayment: async (workerId, p) => {
      await save('workers.payment', () =>
        rpc.payWorkerSalary(workerId, p.amount, p.period, p.date, p.description)
      );
      await reload();
    },

    deletePayment: async (_workerId, id) => {
      await save('workers.payment.delete', () => removeRow('worker_payments', id));
      await reload();
    },

    addOvertime: async (data) => {
      await save('workers.overtime', () => rpc.addWorkerOvertime(overtimePayload(data)));
      await reload();
    },

    updateOvertime: async (id, data) => {
      await save('workers.overtime.update', () => rpc.updateWorkerOvertime(id, overtimePayload(data)));
      await reload();
    },

    deleteOvertime: async (_workerId, id) => {
      await save('workers.overtime.delete', () => rpc.deleteWorkerOvertime(id));
      await reload();
    },

    payOvertimes: async (workerId, ids, date, description) => {
      await save('workers.overtime.pay', () =>
        rpc.payWorkerOvertimes(workerId, ids, date, description ?? 'Paiement heures supplémentaires')
      );
      await reload();
    },

    syncAttendance: async (workerId, from, to, items) => {
      const w = get().workers.find((x) => x.id === workerId);
      if (!w) return;
      const inRange = (d: string) => d.slice(0, 10) >= from && d.slice(0, 10) <= to;
      let changed = false;
      await trySave('workers.attendance.sync', async () => {
        // ---- heures sup. ----
        const existing = (w.overtimes ?? []).filter((o) => inRange(o.date));
        const auto = new Map(items.overtimes.map((o) => [o.date, o]));
        for (const o of existing.filter((x) => x.source === 'device' && !x.isPaid && !x.excluded)) {
          const a = auto.get(o.date.slice(0, 10));
          if (!a) {
            fail((await supabase.from('worker_overtimes').delete().eq('id', o.id)).error); changed = true;
          } else if (Math.round(o.hours * 60) !== a.minutes || o.amount !== a.amount) {
            const [fh, fm] = hm(a.from); const [th, tm] = hm(a.to);
            fail((await supabase.from('worker_overtimes').update({
              work_end_hour: fh, work_end_minute: fm, overtime_end_hour: th, overtime_end_minute: tm,
              hours: Math.round((a.minutes / 60) * 100) / 100, hourly_rate: a.hourlyRate, amount: a.amount,
            }).eq('id', o.id)).error);
            changed = true;
          }
        }
        // un jour qui a déjà des heures sup. (saisies ou pointeuse) n'est pas recréé
        const known = new Set(existing.map((o) => o.date.slice(0, 10)));
        const toInsert = items.overtimes.filter((a) => !known.has(a.date)).map((a) => {
          const [fh, fm] = hm(a.from); const [th, tm] = hm(a.to);
          return {
            worker_id: workerId, date: a.date, work_end_hour: fh, work_end_minute: fm,
            overtime_end_hour: th, overtime_end_minute: tm, hours: Math.round((a.minutes / 60) * 100) / 100,
            hourly_rate: a.hourlyRate, amount: a.amount, description: 'Pointeuse', source: 'device',
          };
        });
        if (toInsert.length) { fail((await supabase.from('worker_overtimes').insert(toInsert)).error); changed = true; }

        // ---- retards ----
        const lates = (w.lates ?? []).filter((l) => inRange(l.date));
        const autoL = new Map(items.lates.map((l) => [l.date, l]));
        for (const l of lates.filter((x) => x.status === 'pending')) {
          const a = autoL.get(l.date.slice(0, 10));
          if (!a) {
            fail((await supabase.from('worker_lates').delete().eq('id', l.id)).error); changed = true;
          } else if (l.minutes !== a.minutes || l.amount !== a.amount || l.entryTime !== a.entry) {
            fail((await supabase.from('worker_lates').update({
              minutes: a.minutes, amount: a.amount, entry_time: a.entry, schedule_start: a.scheduleStart,
            }).eq('id', l.id)).error);
            changed = true;
          }
        }
        const knownL = new Set(lates.map((l) => l.date.slice(0, 10)));
        const lateInsert = items.lates.filter((a) => !knownL.has(a.date)).map((a) => ({
          worker_id: workerId, date: a.date, schedule_start: a.scheduleStart, entry_time: a.entry,
          minutes: a.minutes, amount: a.amount,
        }));
        if (lateInsert.length) { fail((await supabase.from('worker_lates').insert(lateInsert)).error); changed = true; }
      });
      if (changed) await reload();
    },

    setOvertimeExcluded: async (id, excluded) => {
      await save('workers.overtime.exclude', async () =>
        fail((await supabase.from('worker_overtimes').update({ excluded }).eq('id', id)).error));
      await reload();
    },

    setLateStatus: async (id, status) => {
      await save('workers.late.status', async () =>
        fail((await supabase.from('worker_lates').update({ status, payment_id: null, applied_at: null }).eq('id', id)).error));
      await reload();
    },

    paySalary: async (workerId, p, { overtimeIds, lateIds }) => {
      const w = get().workers.find((x) => x.id === workerId);
      const overtimeTotal = (w?.overtimes ?? []).filter((o) => overtimeIds.includes(o.id)).reduce((s, o) => s + o.amount, 0);
      if (overtimeIds.length && overtimeTotal > 0) {
        await save('workers.overtime.pay', () =>
          rpc.payWorkerOvertimes(workerId, overtimeIds, p.date, `Heures supplémentaires — ${p.period}`));
      }
      const salary = Math.round((p.amount - overtimeTotal) * 100) / 100;
      let paymentId: string | null = null;
      if (salary > 0) {
        const row = await save('workers.payment', () =>
          rpc.payWorkerSalary(workerId, salary, p.period, p.date, p.description));
        paymentId = (row as { id?: string } | null)?.id ?? null;
      }
      if (lateIds.length) {
        await save('workers.late.apply', async () =>
          fail((await supabase.from('worker_lates')
            .update({ status: 'applied', payment_id: paymentId, applied_at: p.date })
            .in('id', lateIds)).error));
      }
      await reload();
    },
  };
});
