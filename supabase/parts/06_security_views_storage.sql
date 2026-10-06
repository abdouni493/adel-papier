-- =============================================================================
--  ROW LEVEL SECURITY
--  Admin: everything. Worker: only what profiles.permissions grants, per module
--  and per action (view / create / edit / delete / pay). A worker who can open
--  a screen can also READ the reference data that screen needs (e.g. the POS
--  reads clients and the comptoir) — but cannot write it without the right.
-- =============================================================================

create or replace function public.has_any_perm(p_modules text[], p_action text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (
    select 1 from public.profiles p, unnest(p_modules) m
    where p.id = auth.uid() and p.is_active
      and coalesce((p.permissions -> m ->> p_action)::boolean, false))
$$;

do $$
declare
  rec record;
  r text[]; w text[];
begin
  for rec in
    select * from (values
      ('products',              '{stock,purchase,production,pos,comptoir,sales,clients,dashboard,reports}', '{stock,purchase}'),
      ('marques',               '{stock,purchase,production,pos,comptoir,sales,clients,dashboard,reports}', '{stock,purchase}'),
      ('categories',            '{stock,purchase,production,pos,comptoir,sales,clients,dashboard,reports}', '{stock,purchase}'),
      ('units',                 '{stock,purchase,production,pos,comptoir,sales,clients,dashboard,reports,expenses}', '{stock,purchase,production}'),
      ('suppliers',             '{suppliers,purchase,expenses,caisse,dashboard,reports}', '{suppliers,purchase}'),
      ('clients',               '{clients,pos,sales,caisse,comptoir,dashboard,reports}', '{clients,pos,sales}'),
      ('purchases',             '{purchase,suppliers,stock,caisse,dashboard,reports}', '{purchase}'),
      ('purchase_lines',        '{purchase,suppliers,stock,caisse,dashboard,reports}', '{purchase}'),
      ('purchase_payments',     '{purchase,suppliers,caisse,dashboard,reports}', '{purchase,suppliers}'),
      ('sales',                 '{sales,pos,clients,caisse,comptoir,production,dashboard,reports}', '{sales,pos}'),
      ('sale_lines',            '{sales,pos,clients,caisse,comptoir,production,dashboard,reports}', '{sales,pos}'),
      ('sale_payments',         '{sales,pos,clients,caisse,dashboard,reports}', '{sales,pos,clients}'),
      ('commands',              '{clients,sales,pos,caisse,production,stock,dashboard,reports}', '{clients}'),
      ('command_items',         '{clients,sales,pos,caisse,production,stock,dashboard,reports}', '{clients}'),
      ('command_payments',      '{clients,sales,caisse,dashboard,reports}', '{clients}'),
      ('command_adjustments',   '{clients,sales,caisse,dashboard,reports}', '{clients}'),
      ('command_adjustment_lines','{clients,sales,caisse,dashboard,reports}', '{clients}'),
      ('command_deliveries',    '{clients,sales,pos,caisse,production,stock,dashboard,reports}', '{clients,sales}'),
      ('command_delivery_items','{clients,sales,pos,caisse,production,stock,dashboard,reports}', '{clients,sales}'),
      ('command_delivery_consumptions','{clients,sales,caisse,production,stock,dashboard,reports}', '{clients,sales}'),
      ('productions',           '{production,pos,comptoir,stock,sales,clients,caisse,dashboard,reports}', '{production}'),
      ('production_used_products','{production,pos,comptoir,stock,sales,clients,caisse,dashboard,reports}', '{production}'),
      ('production_categories', '{production,pos,comptoir,stock,sales,clients,dashboard,reports}', '{production}'),
      ('fiche_technics',        '{production,pos,comptoir,stock,sales,clients,dashboard,reports}', '{production}'),
      ('fiche_technic_lines',   '{production,pos,comptoir,stock,sales,clients,dashboard,reports}', '{production}'),
      ('fiche_categories',      '{production,pos,comptoir,stock,sales,clients,dashboard,reports}', '{production}'),
      ('comptoir_items',        '{comptoir,pos,production,sales,caisse,dashboard,reports}', '{comptoir,production}'),
      ('destructions',          '{comptoir,pos,production,sales,caisse,dashboard,reports}', '{comptoir}'),
      ('client_payments',       '{clients,sales,caisse,dashboard,reports}', '{clients}'),
      ('supplier_payments',     '{suppliers,purchase,caisse,dashboard,reports}', '{suppliers}'),
      ('party_old_debts',       '{clients,suppliers,sales,purchase,caisse,dashboard,reports}', '{clients,suppliers}'),
      ('party_old_debt_allocations','{clients,suppliers,caisse,dashboard,reports}', '{clients,suppliers}'),
      ('party_credit_refunds',  '{clients,suppliers,caisse,dashboard,reports}', '{clients,suppliers}'),
      ('client_debts',          '{clients,caisse,dashboard,reports}', '{clients}'),
      ('client_debt_versements','{clients,caisse,dashboard,reports}', '{clients}'),
      ('workers',               '{workers,caisse,expenses,dashboard,reports}', '{workers}'),
      ('worker_acomptes',       '{workers,caisse,expenses,dashboard,reports}', '{workers}'),
      ('worker_absences',       '{workers,caisse,expenses,dashboard,reports}', '{workers}'),
      ('worker_payments',       '{workers,caisse,expenses,dashboard,reports}', '{workers}'),
      ('worker_overtimes',      '{workers,caisse,expenses,dashboard,reports}', '{workers}'),
      ('roles',                 '{workers,settings}', '{workers}'),
      ('expenses',              '{expenses,caisse,dashboard,reports}', '{expenses}'),
      ('expense_categories',    '{expenses,caisse,dashboard,reports}', '{expenses}'),
      ('purchase_orders',       '{expenses,purchase,suppliers,dashboard,reports}', '{expenses,purchase}'),
      ('purchase_order_items',  '{expenses,purchase,suppliers,dashboard,reports}', '{expenses,purchase}'),
      ('caisse_transactions',   '{caisse,dashboard,reports}', '{caisse}'),
      ('caisse_categories',     '{caisse,dashboard,reports}', '{caisse}'),
      ('caisse_reports',        '{caisse,dashboard,reports}', '{caisse}'),
      ('caisse_settings',       '{caisse,dashboard,reports}', '{caisse}'),
      ('recycle_bin',           '{settings}', '{settings}')
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

-- recycle bin is written only by triggers
drop policy if exists p_insert on public.recycle_bin;
drop policy if exists p_update on public.recycle_bin;

-- profiles: everyone reads his own row; only the admin reads / edits all
alter table public.profiles enable row level security;
drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_update on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin() or public.has_perm('workers', 'view'));
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());
-- a worker may rename himself but never change his role or permissions
create or replace function public.trg_profile_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() and auth.uid() is not null then
    new.role := old.role; new.permissions := old.permissions;
    new.worker_id := old.worker_id; new.is_active := old.is_active;
  end if;
  return new;
end $$;
drop trigger if exists profile_guard on public.profiles;
create trigger profile_guard before update on public.profiles
  for each row execute function public.trg_profile_guard();

-- store settings: readable before login (name + logo on the login page)
alter table public.store_settings enable row level security;
drop policy if exists store_select on public.store_settings;
drop policy if exists store_write on public.store_settings;
drop policy if exists store_update on public.store_settings;
create policy store_select on public.store_settings for select to anon, authenticated using (true);
create policy store_write on public.store_settings for insert to authenticated with check (public.has_perm('settings', 'edit'));
create policy store_update on public.store_settings for update to authenticated
  using (public.has_perm('settings', 'edit')) with check (public.has_perm('settings', 'edit'));

-- printing titles: shared by every logged-in user
alter table public.document_titles enable row level security;
drop policy if exists titles_all on public.document_titles;
create policy titles_all on public.document_titles for all to authenticated using (true) with check (true);

-- =============================================================================
--  GRANTS
-- =============================================================================
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant select on public.store_settings to anon;

-- Internal helpers (prefixed with _ ) and trigger functions are SECURITY DEFINER
-- without permission checks: they must never be callable through the API.
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and (p.proname like '\_%' or p.proname like 'trg\_%')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
end $$;

-- Login page: callable before authentication
grant execute on function public.admin_account_exists() to anon, authenticated;
grant execute on function public.create_admin_account(text, text, text, text) to anon, authenticated;
grant execute on function public.resolve_login_email(text) to anon, authenticated;

-- =============================================================================
--  REPORT VIEWS (security_invoker: they respect the caller's RLS)
-- =============================================================================
create or replace view public.v_stock_alerts with (security_invoker = true) as
  select id, name, current_quantity, min_alert_quantity, unit, expiration_date
  from public.products
  where current_quantity <= min_alert_quantity
     or (expiration_enabled and expiration_date is not null and expiration_date <= current_date + 30);

create or replace view public.v_sales_daily with (security_invoker = true) as
  select date, count(*) as sales_count, sum(total_amount) as total_ht, sum(tva_amount) as total_tva,
         sum(final_amount) as total_ttc, sum(paid_amount) as total_paid, sum(rest_amount) as total_rest
  from public.sales group by date order by date desc;

create or replace view public.v_reports_monthly with (security_invoker = true) as
  with m as (
    select date_trunc('month', date)::date as month, 'sales' as k, sum(final_amount) as v from public.sales group by 1
    union all select date_trunc('month', date)::date, 'purchases', sum(total_amount) from public.purchases group by 1
    union all select date_trunc('month', date)::date, 'expenses', sum(amount) from public.expenses group by 1
    union all select date_trunc('month', date)::date, 'salaries', sum(amount) from public.worker_payments group by 1
    union all select date_trunc('month', date)::date, 'production_cost', sum(total_cost) from public.productions group by 1
    union all select date_trunc('month', date)::date, 'destructions', sum(value) from public.destructions group by 1
  )
  select month,
    coalesce(sum(v) filter (where k = 'sales'), 0) as sales,
    coalesce(sum(v) filter (where k = 'purchases'), 0) as purchases,
    coalesce(sum(v) filter (where k = 'expenses'), 0) as expenses,
    coalesce(sum(v) filter (where k = 'salaries'), 0) as salaries,
    coalesce(sum(v) filter (where k = 'production_cost'), 0) as production_cost,
    coalesce(sum(v) filter (where k = 'destructions'), 0) as destructions
  from m group by month order by month desc;

create or replace view public.v_client_balances with (security_invoker = true) as
  select c.id, c.name, c.credit_amount,
    coalesce((select sum(final_amount) from public.sales s where s.client_id = c.id), 0) as billed,
    coalesce((select sum(paid_amount) from public.sales s where s.client_id = c.id), 0) as paid,
    coalesce((select sum(rest_amount) from public.sales s where s.client_id = c.id), 0)
      + coalesce((select sum(rest_amount) from public.party_old_debts o where o.party_type = 'client' and o.party_id = c.id), 0) as rest
  from public.clients c;

create or replace view public.v_supplier_balances with (security_invoker = true) as
  select s.id, s.name, s.credit_amount,
    coalesce((select sum(total_amount) from public.purchases p where p.supplier_id = s.id), 0) as billed,
    coalesce((select sum(paid_amount) from public.purchases p where p.supplier_id = s.id), 0) as paid,
    coalesce((select sum(rest_amount) from public.purchases p where p.supplier_id = s.id), 0)
      + coalesce((select sum(rest_amount) from public.party_old_debts o where o.party_type = 'supplier' and o.party_id = s.id), 0) as rest
  from public.suppliers s;

create or replace view public.v_worker_balances with (security_invoker = true) as
  select w.id, w.full_name, w.payment_amount,
    coalesce((select sum(amount) from public.worker_acomptes a where a.worker_id = w.id), 0) as acomptes,
    coalesce((select sum(cost) from public.worker_absences a where a.worker_id = w.id), 0) as absences,
    coalesce((select sum(amount) from public.worker_payments p where p.worker_id = w.id), 0) as paid,
    coalesce((select sum(amount) from public.worker_overtimes o where o.worker_id = w.id and not o.is_paid), 0) as overtime_due
  from public.workers w;

create or replace view public.v_comptoir_stats with (security_invoker = true) as
  select coalesce(category_name, 'Sans catégorie') as category, count(*) as items,
         sum(quantity) as quantity, sum(quantity * unit_price) as value
  from public.comptoir_items group by 1;

create or replace view public.v_production_profitability with (security_invoker = true) as
  select id, name, date, category_name, output_quantity, total_cost, total_value,
         total_value - total_cost - coalesce(loss_value, 0) as gains,
         case when output_quantity > 0 then round(total_cost / output_quantity, 4) end as cost_per_unit
  from public.productions;

create or replace view public.v_dashboard_kpis with (security_invoker = true) as
  select
    (select count(*) from public.products) as products_count,
    (select count(*) from public.v_stock_alerts) as stock_alerts,
    (select coalesce(sum(final_amount), 0) from public.sales where date = current_date) as sales_today,
    (select coalesce(sum(final_amount), 0) from public.sales where date_trunc('month', date) = date_trunc('month', current_date)) as sales_month,
    (select coalesce(sum(rest_amount), 0) from public.sales) as client_debts,
    (select coalesce(sum(rest_amount), 0) from public.purchases) as supplier_debts,
    (select coalesce(sum(quantity * unit_price), 0) from public.comptoir_items) as comptoir_value,
    public.caisse_balance() as caisse_balance;

grant select on public.v_stock_alerts, public.v_sales_daily, public.v_reports_monthly, public.v_client_balances,
  public.v_supplier_balances, public.v_worker_balances, public.v_comptoir_stats,
  public.v_production_profitability, public.v_dashboard_kpis to authenticated;

-- =============================================================================
--  STORAGE BUCKETS (images & documents)
--   store-assets   public   logo, stamps, signatures         (write: settings)
--   product-images public   raw materials & paper products   (write: stock)
--   documents      private  scanned invoices / BL / receipts (any staff)
-- =============================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('store-assets',   'store-assets',   true,  5242880,  array['image/png','image/jpeg','image/webp','image/svg+xml','image/gif']),
  ('product-images', 'product-images', true,  5242880,  array['image/png','image/jpeg','image/webp','image/gif']),
  ('documents',      'documents',      false, 20971520, array['image/png','image/jpeg','image/webp','application/pdf'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "papeterie public read" on storage.objects;
drop policy if exists "papeterie store-assets write" on storage.objects;
drop policy if exists "papeterie store-assets update" on storage.objects;
drop policy if exists "papeterie store-assets delete" on storage.objects;
drop policy if exists "papeterie product-images write" on storage.objects;
drop policy if exists "papeterie product-images update" on storage.objects;
drop policy if exists "papeterie product-images delete" on storage.objects;
drop policy if exists "papeterie documents read" on storage.objects;
drop policy if exists "papeterie documents write" on storage.objects;
drop policy if exists "papeterie documents delete" on storage.objects;

create policy "papeterie public read" on storage.objects for select to anon, authenticated
  using (bucket_id in ('store-assets', 'product-images'));

create policy "papeterie store-assets write" on storage.objects for insert to authenticated
  with check (bucket_id = 'store-assets' and public.has_perm('settings', 'edit'));
create policy "papeterie store-assets update" on storage.objects for update to authenticated
  using (bucket_id = 'store-assets' and public.has_perm('settings', 'edit'));
create policy "papeterie store-assets delete" on storage.objects for delete to authenticated
  using (bucket_id = 'store-assets' and public.has_perm('settings', 'edit'));

create policy "papeterie product-images write" on storage.objects for insert to authenticated
  with check (bucket_id = 'product-images' and public.has_any_perm(array['stock','purchase','production'], 'create'));
create policy "papeterie product-images update" on storage.objects for update to authenticated
  using (bucket_id = 'product-images' and public.has_any_perm(array['stock','purchase','production'], 'edit'));
create policy "papeterie product-images delete" on storage.objects for delete to authenticated
  using (bucket_id = 'product-images' and public.has_any_perm(array['stock'], 'delete'));

create policy "papeterie documents read" on storage.objects for select to authenticated
  using (bucket_id = 'documents' and exists (select 1 from public.profiles where id = auth.uid() and is_active));
create policy "papeterie documents write" on storage.objects for insert to authenticated
  with check (bucket_id = 'documents' and exists (select 1 from public.profiles where id = auth.uid() and is_active));
create policy "papeterie documents delete" on storage.objects for delete to authenticated
  using (bucket_id = 'documents' and public.is_admin());

-- reload PostgREST schema cache
notify pgrst, 'reload schema';
