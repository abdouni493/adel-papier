-- =============================================================================
--  15. POINTAGE — temps de repos (pause) entre le matin et l'après-midi
--  Ex. travail 08:00 → 16:00, repos 12:00 → 13:00 : l'heure de repos n'est ni
--  comptée comme travail, ni déduite du salaire (pas de retard / départ anticipé).
-- =============================================================================
alter table public.attendance_settings add column if not exists break_enabled boolean not null default false;
alter table public.attendance_settings add column if not exists break_start time not null default '12:00';
alter table public.attendance_settings add column if not exists break_end time not null default '13:00';

insert into public.attendance_settings (id) values (1) on conflict (id) do nothing;

notify pgrst, 'reload schema';
