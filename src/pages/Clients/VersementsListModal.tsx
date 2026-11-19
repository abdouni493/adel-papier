import { useMemo, useState } from 'react';
import { Modal } from '@/components/ui/Modal';
import { SearchBar } from '@/components/ui/SearchBar';
import { EmptyState } from '@/components/ui/EmptyState';
import { HandCoins } from 'lucide-react';
import { cn, dayOf, formatCurrency, formatDateTime, localISODate, paymentMethodLabel } from '@/lib/utils';
import type { Client, PartyPayment } from '@/types';

type Period = 'today' | 'yesterday' | 'week' | 'month' | 'custom';

const PERIODS: { value: Period; label: string }[] = [
  { value: 'today', label: "Aujourd'hui" },
  { value: 'yesterday', label: 'Hier' },
  { value: 'week', label: 'Semaine dernière (7 j)' },
  { value: 'month', label: 'Mois dernier (30 j)' },
  { value: 'custom', label: 'Période' },
];

function shift(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return localISODate(d);
}

function rangeOf(p: Period, from: string, to: string): [string, string] {
  const today = localISODate();
  switch (p) {
    case 'today': return [today, today];
    case 'yesterday': { const y = shift(-1); return [y, y]; }
    case 'week': return [shift(-6), today];
    case 'month': return [shift(-29), today];
    default: return [from || '0000-01-01', to || '9999-12-31'];
  }
}

interface Props {
  open: boolean;
  onClose: () => void;
  payments: PartyPayment[];
  clients: Client[];
}

/** Liste de tous les versements clients, filtrée par période (aujourd'hui par défaut). */
export function VersementsListModal({ open, onClose, payments, clients }: Props) {
  const [period, setPeriod] = useState<Period>('today');
  const [from, setFrom] = useState(localISODate());
  const [to, setTo] = useState(localISODate());
  const [search, setSearch] = useState('');

  const clientById = useMemo(() => new Map(clients.map((c) => [c.id, c])), [clients]);

  const rows = useMemo(() => {
    const [a, b] = rangeOf(period, from, to);
    const q = search.trim().toLowerCase();
    return payments
      .filter((p) => {
        const d = dayOf(p.date || p.paidAt);
        if (d < a || d > b) return false;
        if (!q) return true;
        const c = clientById.get(p.partyId);
        return [c?.name ?? p.partyName, c?.phone, c?.address, p.notes]
          .some((v) => v?.toLowerCase().includes(q));
      })
      .sort((x, y) => (y.paidAt || y.date).localeCompare(x.paidAt || x.date));
  }, [payments, clientById, period, from, to, search]);

  const total = rows.reduce((s, p) => s + p.amount, 0);

  return (
    <Modal open={open} onClose={onClose} title="Versements clients" size="xl">
      <div className="space-y-4">
        <div className="flex flex-wrap gap-2">
          {PERIODS.map((p) => (
            <button key={p.value} type="button" onClick={() => setPeriod(p.value)}
              className={cn('rounded-lg border px-3 py-1.5 text-sm transition',
                period === p.value ? 'border-gold bg-gold text-white' : 'border-gray-300 hover:bg-gray-100 dark:border-gray-600 dark:hover:bg-gray-800')}>
              {p.label}
            </button>
          ))}
        </div>
        {period === 'custom' && (
          <div className="flex flex-wrap items-center gap-3 text-sm">
            <label className="flex items-center gap-2">Du
              <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} className="rounded-lg border px-2 py-1" />
            </label>
            <label className="flex items-center gap-2">Au
              <input type="date" value={to} onChange={(e) => setTo(e.target.value)} className="rounded-lg border px-2 py-1" />
            </label>
          </div>
        )}
        <SearchBar value={search} onChange={setSearch} placeholder="Rechercher un client, téléphone, note…" />
        <div className="flex justify-between rounded-lg bg-gray-50 px-4 py-2 text-sm font-medium dark:bg-gray-800">
          <span>{rows.length} versement(s)</span>
          <span>Total : {formatCurrency(total)}</span>
        </div>
        {rows.length === 0 ? (
          <EmptyState icon={<HandCoins size={32} />} message="Aucun versement sur cette période." />
        ) : (
          <div className="max-h-[60vh] overflow-auto">
            <table className="w-full text-sm">
              <thead className="sticky top-0 bg-white text-left text-xs uppercase text-gray-500 dark:bg-gray-900">
                <tr>
                  <th className="px-2 py-2">Date / heure</th>
                  <th className="px-2 py-2">Client</th>
                  <th className="px-2 py-2">Téléphone</th>
                  <th className="px-2 py-2">Adresse</th>
                  <th className="px-2 py-2">Mode</th>
                  <th className="px-2 py-2">Note</th>
                  <th className="px-2 py-2">Par</th>
                  <th className="px-2 py-2 text-right">Montant</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((p) => {
                  const c = clientById.get(p.partyId);
                  return (
                    <tr key={p.id} className="border-t border-gray-100 dark:border-gray-800">
                      <td className="whitespace-nowrap px-2 py-2">{formatDateTime(p.paidAt || p.date)}</td>
                      <td className="px-2 py-2 font-medium">{c?.name ?? p.partyName ?? '—'}</td>
                      <td className="whitespace-nowrap px-2 py-2">{c?.phone || '—'}</td>
                      <td className="px-2 py-2">{c?.address || '—'}</td>
                      <td className="px-2 py-2">{paymentMethodLabel(p)}</td>
                      <td className="px-2 py-2">{p.notes || '—'}</td>
                      <td className="px-2 py-2">{p.createdBy || '—'}</td>
                      <td className="whitespace-nowrap px-2 py-2 text-right font-semibold">{formatCurrency(p.amount)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </Modal>
  );
}
