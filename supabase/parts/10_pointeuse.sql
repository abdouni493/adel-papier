-- =============================================================================
--  10 — POINTEUSE ZKTECO (K50 PRO) · PRÉSENCES, ABSENCES, RETARDS, PAIE
-- -----------------------------------------------------------------------------
--  À exécuter APRÈS les parties 01 → 09 (ré-exécutable sans risque).
--
--  La pointeuse envoie chaque pointage (protocole ZKTeco PUSH / ADMS) au petit
--  programme « pointeuse/bridge.mjs » lancé sur le PC de l'usine. Celui-ci les
--  enregistre ici via les fonctions pointeuse_* protégées par un jeton secret
--  (table attendance_bridge, lisible uniquement par l'administrateur).
--
--  1. workers : n° de badge (PIN de la pointeuse) + horaires propres (option)
--  2. attendance_settings  : horaires de l'usine, tolérances, jours de repos
--  3. attendance_devices   : pointeuses connues (n° de série, dernière connexion)
--  4. attendance_punches   : chaque pointage (PIN, date-heure locale)
--  5. attendance_commands  : commandes envoyées à la pointeuse (employés, empreintes)
--  6. RLS + fonctions RPC
-- =============================================================================

-- -----------------------------------------------------------------------------
--  1. EMPLOYÉS
-- -----------------------------------------------------------------------------
alter table public.workers add column if not exists badge_pin text;
alter table public.workers add column if not exists work_start time;
alter table public.workers add column if not exists work_end time;
create unique index if not exists workers_badge_pin_uq
  on public.workers (badge_pin) where badge_pin is not null and badge_pin <> '';

-- -----------------------------------------------------------------------------
--  2. PARAMÈTRES
-- -----------------------------------------------------------------------------
create table if not exists public.attendance_settings (
  id int primary key default 1 check (id = 1),
  work_start time not null default '08:00',
  work_end time not null default '16:00',
  late_tolerance_min int not null default 10,
  early_tolerance_min int not null default 10,
  min_overtime_min int not null default 30,
  rest_days int[] not null default '{5}',          -- 0 = dimanche … 5 = vendredi, 6 = samedi
  deduct_absences boolean not null default true,
  deduct_late boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into public.attendance_settings (id) values (1) on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
--  3. POINTEUSES
-- -----------------------------------------------------------------------------
create table if not exists public.attendance_devices (
  sn text primary key,
  name text,
  ip text,
  push_version text,
  info text,
  last_seen timestamptz,
  last_punch_at timestamptz,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
--  4. POINTAGES
-- -----------------------------------------------------------------------------
create table if not exists public.attendance_punches (
  id bigserial primary key,
  device_sn text,
  pin text not null,
  worker_id uuid references public.workers(id) on delete set null,
  punched_at timestamp not null,                   -- heure LOCALE de la pointeuse
  status int,                                      -- 0 entrée, 1 sortie, 4/5 h. sup. …
  verify int,                                      -- 1 empreinte, 3 code, 4 carte, 15 visage
  source text not null default 'device',           -- device | manual
  note text,
  created_at timestamptz not null default now(),
  created_by text default public.current_username(),
  unique (pin, punched_at)
);
create index if not exists attendance_punches_worker_idx on public.attendance_punches (worker_id, punched_at);
create index if not exists attendance_punches_time_idx on public.attendance_punches (punched_at);

-- le PIN désigne l'employé : rattachement automatique
create or replace function public.trg_punch_worker()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.worker_id is null then
    select id into new.worker_id from public.workers where badge_pin = new.pin limit 1;
  elsif new.pin is null or new.pin = '' then
    select badge_pin into new.pin from public.workers where id = new.worker_id;
  end if;
  return new;
end $$;
drop trigger if exists punch_worker_trg on public.attendance_punches;
create trigger punch_worker_trg before insert on public.attendance_punches
  for each row execute function public.trg_punch_worker();

-- un PIN attribué (ou modifié) plus tard récupère les pointages déjà reçus
create or replace function public.trg_worker_badge_pin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.badge_pin, '') is distinct from coalesce(old.badge_pin, '') then
    update public.attendance_punches set worker_id = null
     where worker_id = new.id and source = 'device';
    if coalesce(new.badge_pin, '') <> '' then
      update public.attendance_punches set worker_id = new.id where pin = new.badge_pin;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists worker_badge_pin_trg on public.workers;
create trigger worker_badge_pin_trg after update of badge_pin on public.workers
  for each row execute function public.trg_worker_badge_pin();

create or replace function public.trg_worker_badge_pin_ins()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.badge_pin, '') <> '' then
    update public.attendance_punches set worker_id = new.id where pin = new.badge_pin and worker_id is null;
  end if;
  return new;
end $$;
drop trigger if exists worker_badge_pin_ins_trg on public.workers;
create trigger worker_badge_pin_ins_trg after insert on public.workers
  for each row execute function public.trg_worker_badge_pin_ins();

-- -----------------------------------------------------------------------------
--  5. COMMANDES VERS LA POINTEUSE
-- -----------------------------------------------------------------------------
create table if not exists public.attendance_commands (
  id bigserial primary key,
  device_sn text,                                  -- null = première pointeuse qui la demande
  command text not null,
  label text,
  status text not null default 'pending',          -- pending | sent | done | error
  return_code int,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  done_at timestamptz,
  created_by text default public.current_username()
);
create index if not exists attendance_commands_pending_idx on public.attendance_commands (status, id);

-- jeton secret du programme passerelle (aucune politique RLS = illisible sauf admin via RPC)
create table if not exists public.attendance_bridge (
  id int primary key default 1 check (id = 1),
  token text not null default replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
  created_at timestamptz not null default now()
);
insert into public.attendance_bridge (id) values (1) on conflict (id) do nothing;
alter table public.attendance_bridge enable row level security;
revoke all on public.attendance_bridge from anon, authenticated;

-- -----------------------------------------------------------------------------
--  6. SÉCURITÉ (mêmes règles que le module Employés)
-- -----------------------------------------------------------------------------
do $$
declare rec record; r text[]; w text[];
begin
  for rec in
    select * from (values
      ('attendance_settings', '{workers,caisse,dashboard,reports}', '{workers}'),
      ('attendance_devices',  '{workers,caisse,dashboard,reports}', '{workers}'),
      ('attendance_punches',  '{workers,caisse,dashboard,reports}', '{workers}'),
      ('attendance_commands', '{workers}',                          '{workers}')
    ) as t(tbl, rd, wr)
  loop
    r := rec.rd::text[]; w := rec.wr::text[];
    execute format('alter table public.%I enable row level security', rec.tbl);
    execute format('drop policy if exists p_select on public.%I', rec.tbl);
    execute format('drop policy if exists p_insert on public.%I', rec.tbl);
    execute format('drop policy if exists p_update on public.%I', rec.tbl);
    execute format('drop policy if exists p_delete on public.%I', rec.tbl);
    execute format('create policy p_select on public.%I for select to authenticated using (public.can_view_any(%L::text[]))', rec.tbl, r);
    execute format('create policy p_insert on public.%I for insert to authenticated with check (public.has_any_perm(%L::text[], ''create''))', rec.tbl, w);
    execute format('create policy p_update on public.%I for update to authenticated using (public.has_any_perm(%L::text[], ''edit'')) with check (public.has_any_perm(%L::text[], ''edit''))', rec.tbl, w, w);
    execute format('create policy p_delete on public.%I for delete to authenticated using (public.has_any_perm(%L::text[], ''delete''))', rec.tbl, w);
  end loop;
end $$;

grant select, insert, update, delete on public.attendance_settings, public.attendance_devices,
  public.attendance_punches, public.attendance_commands to authenticated;
grant usage, select on sequence public.attendance_punches_id_seq, public.attendance_commands_id_seq to authenticated;

-- -----------------------------------------------------------------------------
--  7. RPC — PASSERELLE (appelées par pointeuse/bridge.mjs avec le jeton)
-- -----------------------------------------------------------------------------
create or replace function public.pointeuse_check(p_token text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_token is null or not exists (select 1 from public.attendance_bridge where token = p_token) then
    raise exception 'Jeton de la pointeuse invalide' using errcode = '28000';
  end if;
end $$;
revoke all on function public.pointeuse_check(text) from public, anon, authenticated;

create or replace function public.pointeuse_heartbeat(p_token text, p_sn text, p_ip text default null, p_info text default null, p_push_version text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.pointeuse_check(p_token);
  insert into public.attendance_devices (sn, name, ip, info, push_version, last_seen)
  values (p_sn, 'ZKTeco ' || p_sn, p_ip, p_info, p_push_version, now())
  on conflict (sn) do update set
    ip = coalesce(excluded.ip, attendance_devices.ip),
    info = coalesce(excluded.info, attendance_devices.info),
    push_version = coalesce(excluded.push_version, attendance_devices.push_version),
    last_seen = now();
end $$;

-- p_rows = [{"pin":"1","t":"2026-10-11 08:02:11","status":0,"verify":1}, …]
create or replace function public.pointeuse_push_logs(p_token text, p_sn text, p_rows jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare v_n int;
begin
  perform public.pointeuse_check(p_token);
  insert into public.attendance_punches (device_sn, pin, punched_at, status, verify, source, created_by)
  select p_sn, trim(x.pin), x.t::timestamp, x.status, x.verify, 'device', 'pointeuse'
    from jsonb_to_recordset(coalesce(p_rows, '[]'::jsonb)) as x(pin text, t text, status int, verify int)
   where coalesce(trim(x.pin), '') <> '' and x.t is not null
  on conflict (pin, punched_at) do nothing;
  get diagnostics v_n = row_count;
  update public.attendance_devices set last_seen = now(), last_punch_at = now() where sn = p_sn;
  return v_n;
end $$;

create or replace function public.pointeuse_take_commands(p_token text, p_sn text)
returns table (id bigint, command text) language plpgsql security definer set search_path = public as $$
begin
  perform public.pointeuse_check(p_token);
  return query
  update public.attendance_commands c
     set status = 'sent', sent_at = now(), device_sn = coalesce(c.device_sn, p_sn)
   where c.id in (
     select c2.id from public.attendance_commands c2
      where (c2.status = 'pending' or (c2.status = 'sent' and c2.sent_at < now() - interval '10 minutes'))
        and (c2.device_sn is null or c2.device_sn = p_sn)
      order by c2.id limit 20)
  returning c.id, c.command;
end $$;

create or replace function public.pointeuse_command_result(p_token text, p_id bigint, p_return int)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.pointeuse_check(p_token);
  update public.attendance_commands
     set status = case when p_return >= 0 then 'done' else 'error' end,
         return_code = p_return, done_at = now()
   where id = p_id;
end $$;

grant execute on function public.pointeuse_heartbeat(text, text, text, text, text) to anon, authenticated;
grant execute on function public.pointeuse_push_logs(text, text, jsonb) to anon, authenticated;
grant execute on function public.pointeuse_take_commands(text, text) to anon, authenticated;
grant execute on function public.pointeuse_command_result(text, bigint, int) to anon, authenticated;

-- -----------------------------------------------------------------------------
--  8. RPC — APPLICATION (administrateur)
-- -----------------------------------------------------------------------------
create or replace function public.pointeuse_bridge_token()
returns text language plpgsql security definer set search_path = public as $$
declare v text;
begin
  if not public.is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  select token into v from public.attendance_bridge where id = 1;
  return v;
end $$;

create or replace function public.pointeuse_regenerate_token()
returns text language plpgsql security definer set search_path = public as $$
declare v text;
begin
  if not public.is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  update public.attendance_bridge
     set token = replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
         created_at = now()
   where id = 1
  returning token into v;
  return v;
end $$;
grant execute on function public.pointeuse_bridge_token() to authenticated;
grant execute on function public.pointeuse_regenerate_token() to authenticated;

notify pgrst, 'reload schema';
