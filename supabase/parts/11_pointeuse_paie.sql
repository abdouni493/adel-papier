-- =============================================================================
--  11 — POINTEUSE → PAIE : HEURES SUP. ET RETARDS AUTOMATIQUES
-- -----------------------------------------------------------------------------
--  À exécuter APRÈS la partie 10 (ré-exécutable sans risque).
--
--  1. Heures sup. comptées à partir de la fin du travail + 20 min
--     (16:00 → les heures sup. commencent à 16:20).
--  2. worker_overtimes : origine (manuel / pointeuse) + « exclue » (retirée
--     définitivement des calculs, réactivable depuis l'historique).
--  3. worker_lates : retards calculés depuis la pointeuse, à appliquer
--     (déduits d'un salaire), à laisser en attente ou à exclure.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  1. PARAMÈTRE : délai après la fin du travail avant les heures sup.
-- -----------------------------------------------------------------------------
alter table public.attendance_settings alter column min_overtime_min set default 20;
update public.attendance_settings set min_overtime_min = 20 where id = 1;
-- « deduct_late » = retards cochés (déduits) par défaut dans l'écran Paie
update public.attendance_settings set deduct_late = true where id = 1;

-- -----------------------------------------------------------------------------
--  2. HEURES SUPPLÉMENTAIRES
-- -----------------------------------------------------------------------------
alter table public.worker_overtimes add column if not exists source text not null default 'manual';
alter table public.worker_overtimes add column if not exists excluded boolean not null default false;
alter table public.worker_overtimes drop constraint if exists worker_overtimes_source_chk;
alter table public.worker_overtimes add constraint worker_overtimes_source_chk check (source in ('manual','device'));
create unique index if not exists worker_overtimes_device_uq
  on public.worker_overtimes (worker_id, date) where source = 'device';

-- -----------------------------------------------------------------------------
--  3. RETARDS
-- -----------------------------------------------------------------------------
create table if not exists public.worker_lates (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete cascade,
  date date not null,
  schedule_start text not null default '',
  entry_time text not null default '',
  minutes int not null default 0,
  amount numeric(14,2) not null default 0,
  status text not null default 'pending' check (status in ('pending','applied','excluded')),
  payment_id uuid references public.worker_payments(id) on delete set null,
  applied_at date,
  created_at timestamptz default now(),
  unique (worker_id, date)
);
create index if not exists worker_lates_worker_idx on public.worker_lates (worker_id, date);

-- suppression d'un paiement → ses retards et heures sup. redeviennent « à régler »
create or replace function public.trg_worker_payment_unmark()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.worker_overtimes set is_paid = false, paid_at = null, payment_id = null where payment_id = old.id;
  update public.worker_lates set status = 'pending', applied_at = null, payment_id = null where payment_id = old.id;
  return old;
end $$;
drop trigger if exists worker_payment_unmark_trg on public.worker_payments;
create trigger worker_payment_unmark_trg before delete on public.worker_payments
  for each row execute function public.trg_worker_payment_unmark();

-- -----------------------------------------------------------------------------
--  4. SÉCURITÉ (mêmes règles que le module Employés)
-- -----------------------------------------------------------------------------
alter table public.worker_lates enable row level security;
drop policy if exists p_select on public.worker_lates;
drop policy if exists p_insert on public.worker_lates;
drop policy if exists p_update on public.worker_lates;
drop policy if exists p_delete on public.worker_lates;
create policy p_select on public.worker_lates for select to authenticated
  using (public.can_view_any('{workers,caisse,dashboard,reports}'::text[]));
create policy p_insert on public.worker_lates for insert to authenticated
  with check (public.has_any_perm('{workers}'::text[], 'create'));
create policy p_update on public.worker_lates for update to authenticated
  using (public.has_any_perm('{workers}'::text[], 'edit'))
  with check (public.has_any_perm('{workers}'::text[], 'edit'));
create policy p_delete on public.worker_lates for delete to authenticated
  using (public.has_any_perm('{workers}'::text[], 'delete'));
grant select, insert, update, delete on public.worker_lates to authenticated;

notify pgrst, 'reload schema';
