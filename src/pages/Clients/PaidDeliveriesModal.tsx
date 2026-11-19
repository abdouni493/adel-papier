import { useMemo, useState } from 'react';
import { Modal } from '@/components/ui/Modal';
import { SearchBar } from '@/components/ui/SearchBar';
import { EmptyState } from '@/components/ui/EmptyState';
import { Truck } from 'lucide-react';
import { cn, dayOf, formatCurrency, formatDateTime, localISODate } from '@/lib/utils';
import type { CommandDelivery } from '@/types';
import type { Command } from '@/store/commandStore';
import type { Client } from '@/types';
import { PERIODS, rangeOf, type Period } from './VersementsListModal';

interface Props {
  open: boolean;
  onClose: () => void;
  deliveries: CommandDelivery[];
  commands: Command[];
  clients: Client[];
}

/** Bons de livraison payés (montant encaissé > 0), filtrés par période — aujourd'hui par défaut. */
export function PaidDeliveriesModal({ open, onClose, deliveries, commands, clients }: Props) {
  const [period, setPeriod] = useState<Period>('today');
  const [from, setFrom] = useState(localISODate());
  const [to, setTo] = useState(localISODate());
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<'all' | 'paid' | 'rest'>('all');

  const cmdById = useMemo(() => new Map(commands.map((c) => [c.id, c])), [commands]);
  const clientById = useMemo(() => new Map(clients.map((c) => [c.id, c])), [clients]);

  const rows = useMemo(() => {
    const [a, b] = rangeOf(period, from, to);
    const q = search.trim().toLowerCase();
    return deliveries
      .filter((d) => {
        const paid = (d.paidAmount ?? 0) > 0 || (d.cashPaid ?? 0) > 0;
        const rest = (d.restAmount ?? 0) > 0;
        if (status === 'paid') return paid && !rest;
        if (status === 'rest') return rest;
        return paid || rest;
      })
      .map((d) => {
        const cmd = cmdById.get(d.commandId);
        const cl = cmd ? clientById.get(cmd.clientId) : undefined;
        return {
          d,
          name: cl?.name ?? cmd?.clientName ?? '—',
          phone: cl?.phone || cmd?.clientPhone || '',
          address: d.location || cmd?.clientAddress || cl?.address || '',
          cmdRef: cmd?.reference ?? '',
        };
      })
      .filter((r) => {
        const day = dayOf(r.d.deliveredAt || r.d.date);
        if (day < a || day > b) return false;
        if (!q) return true;
        return [r.name, r.phone, r.address, r.cmdRef, r.d.reference, r.d.driverName, String(r.d.blNumber ?? '')]
          .some((v) => v?.toLowerCase().includes(q));
      })
      .sort((x, y) => (y.d.deliveredAt || y.d.date).localeCompare(x.d.deliveredAt || x.d.date));
  }, [deliveries, cmdById, clientById, period, from, to, search, status]);

  const totals = rows.reduce(
    (t, r) => ({
      ttc: t.ttc + (r.d.totalTtc ?? 0),
      paid: t.paid + (r.d.paidAmount ?? 0),
      cash: t.cash + (r.d.cashPaid ?? 0),
      rest: t.rest + (r.d.restAmount ?? 0),
    }),
    { ttc: 0, paid: 0, cash: 0, rest: 0 },
  );

  return (
    <Modal open={open} onClose={onClose} title="Bons de livraison payés / avec reste" size="xl">
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
        <div className="flex flex-wrap gap-2">
          {([['all', 'Tous'], ['paid', 'Payés entièrement'], ['rest', 'Avec reste à payer']] as const).map(([v, l]) => (
            <button key={v} type="button" onClick={() => setStatus(v)}
              className={cn('rounded-lg border px-3 py-1.5 text-sm transition',
                status === v ? 'border-gold bg-gold text-white' : 'border-gray-300 hover:bg-gray-100 dark:border-gray-600 dark:hover:bg-gray-800')}>
              {l}
            </button>
          ))}
        </div>
        <SearchBar value={search} onChange={setSearch} placeholder="Rechercher un bon, un client, un téléphone…" />
        <div className="grid grid-cols-2 gap-2 rounded-lg bg-gray-50 px-4 py-2 text-sm font-medium sm:grid-cols-5 dark:bg-gray-800">
          <span>{rows.length} bon(s)</span>
          <span>Total TTC : {formatCurrency(totals.ttc)}</span>
          <span>Payé : {formatCurrency(totals.paid)}</span>
          <span>Encaissé : {formatCurrency(totals.cash)}</span>
          <span>Reste : {formatCurrency(totals.rest)}</span>
        </div>
        {rows.length === 0 ? (
          <EmptyState icon={<Truck size={32} />} message="Aucun bon de livraison sur cette période." />
        ) : (
          <div className="max-h-[60vh] overflow-auto">
            <table className="w-full text-sm">
              <thead className="sticky top-0 bg-white text-left text-xs uppercase text-gray-500 dark:bg-gray-900">
                <tr>
                  <th className="px-2 py-2">Date / heure</th>
                  <th className="px-2 py-2">Bon</th>
                  <th className="px-2 py-2">Client</th>
                  <th className="px-2 py-2">Téléphone</th>
                  <th className="px-2 py-2">Adresse</th>
                  <th className="px-2 py-2">Chauffeur</th>
                  <th className="px-2 py-2 text-right">Total TTC</th>
                  <th className="px-2 py-2 text-right">Acompte</th>
                  <th className="px-2 py-2 text-right">Encaissé</th>
                  <th className="px-2 py-2 text-right">Payé</th>
                  <th className="px-2 py-2 text-right">Reste</th>
                </tr>
              </thead>
              <tbody>
                {rows.map(({ d, name, phone, address, cmdRef }) => (
                  <tr key={d.id} className="border-t border-gray-100 dark:border-gray-800">
                    <td className="whitespace-nowrap px-2 py-2">{formatDateTime(d.deliveredAt || d.date)}</td>
                    <td className="whitespace-nowrap px-2 py-2">
                      <div className="font-medium">{d.blNumber ? `BL n° ${d.blNumber}` : d.reference}</div>
                      {cmdRef && <div className="text-xs text-gray-500">{cmdRef}</div>}
                    </td>
                    <td className="px-2 py-2 font-medium">{name}</td>
                    <td className="whitespace-nowrap px-2 py-2">{phone || '—'}</td>
                    <td className="px-2 py-2">{address || '—'}</td>
                    <td className="px-2 py-2">{d.driverName || '—'}</td>
                    <td className="whitespace-nowrap px-2 py-2 text-right">{formatCurrency(d.totalTtc ?? 0)}</td>
                    <td className="whitespace-nowrap px-2 py-2 text-right">{formatCurrency(d.advanceApplied ?? 0)}</td>
                    <td className="whitespace-nowrap px-2 py-2 text-right">{formatCurrency(d.cashPaid ?? 0)}</td>
                    <td className="whitespace-nowrap px-2 py-2 text-right font-semibold">{formatCurrency(d.paidAmount ?? 0)}</td>
                    <td className={cn('whitespace-nowrap px-2 py-2 text-right', (d.restAmount ?? 0) > 0 && 'text-rose-600')}>{formatCurrency(d.restAmount ?? 0)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </Modal>
  );
}
