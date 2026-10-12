import { useCallback, useEffect, useState } from 'react';
import { useAttendanceStore } from '@/store/attendanceStore';
import { useWorkerStore } from '@/store/workerStore';
import {
  attendanceItems, attendancePay, computeMonth, isoDate, type AutoLate, type AutoOvertime,
} from '@/lib/attendance';

/** Nombre de mois (mois en cours compris) recalculés à chaque ouverture. */
const SYNC_MONTHS = 3;

/**
 * Calcule automatiquement, depuis les pointages, les heures supplémentaires
 * (à partir de la fin du travail + délai) et les retards de l'employé, puis
 * les enregistre (à payer / à déduire depuis « Paie »).
 */
export function useAttendanceSync(workerId: string) {
  const { ready, loadMeta, fetchPunches } = useAttendanceStore();
  const syncAttendance = useWorkerStore((s) => s.syncAttendance);
  const [syncing, setSyncing] = useState(false);

  const run = useCallback(async () => {
    await loadMeta();
    const st = useAttendanceStore.getState();
    const worker = useWorkerStore.getState().workers.find((w) => w.id === workerId);
    if (!st.ready || !worker?.badgePin) return;
    setSyncing(true);
    try {
      const d = new Date();
      d.setDate(1);
      d.setMonth(d.getMonth() - (SYNC_MONTHS - 1));
      const months: string[] = [];
      for (let i = 0; i < SYNC_MONTHS; i++) {
        months.push(isoDate(d).slice(0, 7));
        d.setMonth(d.getMonth() + 1);
      }
      const from = `${months[0]}-01`;
      const to = isoDate(new Date());
      const punches = await fetchPunches(from, to, workerId);
      const items: { overtimes: AutoOvertime[]; lates: AutoLate[] } = { overtimes: [], lates: [] };
      for (const m of months) {
        const sum = computeMonth(m, punches, worker, st.settings);
        const it = attendanceItems(sum, attendancePay(worker, sum, st.settings), st.settings);
        // aujourd'hui : la journée n'est pas finie, pas d'heures sup. provisoires
        items.overtimes.push(...it.overtimes.filter((o) => o.date < to));
        items.lates.push(...it.lates);
      }
      await syncAttendance(workerId, from, to, items);
    } catch {
      /* pointeuse indisponible : les données déjà enregistrées restent affichées */
    } finally {
      setSyncing(false);
    }
  }, [workerId, loadMeta, fetchPunches, syncAttendance]);

  useEffect(() => { void run(); }, [run]);

  return { ready, syncing, resync: run };
}
