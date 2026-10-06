-- =============================================================================
--  PAPETERIE PRODUCTION — FULL SUPABASE SCHEMA
--  Paper production factory management (stock, purchases, production,
--  comptoir, POS, sales, commands & deliveries, clients, suppliers, workers,
--  expenses, caisse, reports, settings, recycle bin, storage buckets).
--
--  Run this file ONCE on a fresh Supabase project (SQL editor → Run).
--  It is idempotent for functions/policies (create or replace / drop if exists)
--  but tables are created with IF NOT EXISTS.
-- =============================================================================

create extension if not exists pgcrypto;
create extension if not exists "uuid-ossp";

-- -----------------------------------------------------------------------------
--  0. IDENTITY & PERMISSIONS
-- -----------------------------------------------------------------------------

-- Application identity of every auth user (admin or worker).
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null default '',
  username    text unique,
  email       text not null,
  role        text not null default 'worker' check (role in ('admin','worker')),
  permissions jsonb not null default '{}'::jsonb,
  worker_id   uuid,
  language    text not null default 'fr',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Username of the caller — stamped on every created row (created_by).
create or replace function public.current_username()
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select coalesce(nullif(username,''), full_name, email) from public.profiles where id = auth.uid()),
    'system')
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role = 'admin' and is_active)
$$;

-- has_perm('sales','view') — admin always true; worker reads profiles.permissions.
create or replace function public.has_perm(p_module text, p_action text default 'view')
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_active
      and coalesce((p.permissions -> p_module ->> p_action)::boolean, false)
  )
$$;

-- true when the caller may VIEW at least one of the given modules.
create or replace function public.can_view_any(p_modules text[])
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (
    select 1 from public.profiles p, unnest(p_modules) m
    where p.id = auth.uid() and p.is_active
      and coalesce((p.permissions -> m ->> 'view')::boolean, false)
  )
$$;

-- RPC guard: raises when the caller has none of the (module, action) pairs.
-- p_pairs = array['pos:create','sales:create']
create or replace function public.require_perm(p_pairs text[])
returns void language plpgsql stable security definer set search_path = public as $$
declare v text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if public.is_admin() then return; end if;
  foreach v in array p_pairs loop
    if public.has_perm(split_part(v, ':', 1), split_part(v, ':', 2)) then return; end if;
  end loop;
  raise exception 'permission denied (%)', array_to_string(p_pairs, ', ');
end $$;

-- -----------------------------------------------------------------------------
--  1. REFERENCE LISTS
-- -----------------------------------------------------------------------------
create table if not exists public.marques               (id uuid primary key default gen_random_uuid(), name text not null unique, created_at timestamptz default now());
create table if not exists public.categories            (id uuid primary key default gen_random_uuid(), name text not null unique, created_at timestamptz default now());
create table if not exists public.units                 (id uuid primary key default gen_random_uuid(), name text not null unique, created_at timestamptz default now());
create table if not exists public.production_categories (id uuid primary key default gen_random_uuid(), name text not null unique, created_at timestamptz default now());
create table if not exists public.fiche_categories      (id uuid primary key default gen_random_uuid(), name text not null unique, created_at timestamptz default now());
create table if not exists public.expense_categories    (id uuid primary key default gen_random_uuid(), name text not null unique, created_at timestamptz default now());
create table if not exists public.caisse_categories     (id uuid primary key default gen_random_uuid(), name text not null unique, created_at timestamptz default now());
create table if not exists public.roles                 (id uuid primary key default gen_random_uuid(), name text not null unique, created_at timestamptz default now());

create table if not exists public.document_titles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  scope text not null default 'statement',
  created_at timestamptz default now(),
  created_by text default public.current_username()
);

-- -----------------------------------------------------------------------------
--  2. SETTINGS (singletons)
-- -----------------------------------------------------------------------------
create table if not exists public.store_settings (
  id boolean primary key default true check (id),
  logo text, name text default 'Papeterie Production',
  description text default 'Production & Vente de Papier',
  email text, phone text, address text, social_media text,
  nif text, nis text, article text, rc text, activity_place text, city text,
  updated_at timestamptz default now()
);
insert into public.store_settings (id) values (true) on conflict do nothing;

create table if not exists public.caisse_settings (
  id boolean primary key default true check (id),
  initial_balance numeric(14,2) not null default 0
);
insert into public.caisse_settings (id) values (true) on conflict do nothing;

-- -----------------------------------------------------------------------------
--  3. STOCK (raw materials & paper products)
-- -----------------------------------------------------------------------------
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text default '',
  barcode text,
  image_url text,
  marque_id uuid references public.marques(id) on delete set null,
  category_id uuid references public.categories(id) on delete set null,
  principal_quantity numeric(14,3) not null default 0,
  current_quantity numeric(14,3) not null default 0,
  min_alert_quantity numeric(14,3) not null default 0,
  purchase_price numeric(14,2) not null default 0,
  unit_enabled boolean not null default false,
  unit text,
  expiration_enabled boolean not null default false,
  expiration_date date,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create index if not exists products_name_idx on public.products (lower(name));

-- -----------------------------------------------------------------------------
--  4. PARTIES
-- -----------------------------------------------------------------------------
create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null, phone text default '', address text default '',
  credit_amount numeric(14,2) not null default 0,   -- paid in excess (acompte)
  created_at timestamptz default now(),
  created_by text default public.current_username()
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null, phone text default '', address text default '', note text default '',
  rc text, nif text, nis text, article text,
  credit_amount numeric(14,2) not null default 0,   -- paid in excess (acompte)
  created_at timestamptz default now(),
  created_by text default public.current_username()
);

-- -----------------------------------------------------------------------------
--  5. CAISSE (cash register) — every money movement lands here
-- -----------------------------------------------------------------------------
create table if not exists public.caisse_transactions (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('deposit','withdrawal')),
  amount numeric(14,2) not null check (amount >= 0),
  date date not null default current_date,
  description text default '',
  category_id uuid references public.caisse_categories(id) on delete set null,
  category_name text,
  ref_table text,          -- source document table (sale_payments, expenses …)
  ref_id uuid,             -- source row id
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create index if not exists caisse_ref_idx on public.caisse_transactions (ref_table, ref_id);
create index if not exists caisse_date_idx on public.caisse_transactions (date);

create table if not exists public.caisse_reports (
  id uuid primary key default gen_random_uuid(),
  report_type text not null default 'day' check (report_type in ('day','period')),
  date date not null default current_date,
  end_date date,
  hour text default to_char(now() at time zone 'Africa/Algiers', 'HH24:MI'),
  description text default '',
  declared_amount numeric(14,2) not null default 0,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);

-- -----------------------------------------------------------------------------
--  6. PURCHASES
-- -----------------------------------------------------------------------------
create sequence if not exists public.purchase_ref_seq;
create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  reference text not null default ('ACH-' || lpad(nextval('public.purchase_ref_seq')::text, 6, '0')),
  supplier_id uuid references public.suppliers(id) on delete set null,
  date date not null default current_date,
  driver_plate text, bon_number text, note text,
  is_historical boolean not null default false,   -- old purchase: no stock, no caisse
  total_amount numeric(14,2) not null default 0,
  paid_amount numeric(14,2) not null default 0,
  rest_amount numeric(14,2) not null default 0,
  allocated_amount numeric(14,2) not null default 0,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);

create table if not exists public.purchase_lines (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  quantity numeric(14,3) not null default 0,
  purchase_price numeric(14,2) not null default 0,
  min_alert_quantity numeric(14,3),
  unit_enabled boolean default false, unit text,
  expiration_enabled boolean default false, expiration_date date
);

-- -----------------------------------------------------------------------------
--  7. PRODUCTION
-- -----------------------------------------------------------------------------
create table if not exists public.fiche_technics (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category_id uuid, category_name text,
  description text default '',
  sell_by_unit boolean default false, sell_unit text,
  usable_in_production boolean default false, product_unit text,
  output_quantity numeric(14,3) not null default 1,
  unit_price numeric(14,2) default 0, total_cost numeric(14,2) default 0,
  cost_per_unit numeric(14,4) default 0, total_value numeric(14,2) default 0,
  gains_per_unit numeric(14,4) default 0, total_gains numeric(14,2) default 0,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create table if not exists public.fiche_technic_lines (
  id uuid primary key default gen_random_uuid(),
  fiche_technic_id uuid not null references public.fiche_technics(id) on delete cascade,
  product_id uuid,             -- products.id (stock) or fiche_technics.id (fiche)
  product_name text not null,
  quantity_used numeric(14,4) not null default 0,
  source_type text default 'stock' check (source_type in ('stock','fiche')),
  unit text, unit_cost numeric(14,4) default 0, line_cost numeric(14,2) default 0
);

create table if not exists public.productions (
  id uuid primary key default gen_random_uuid(),
  name text not null, description text default '',
  date date not null default current_date, hour text,
  fiche_technic_id uuid references public.fiche_technics(id) on delete set null,
  category_id uuid, category_name text,
  total_cost numeric(14,2) not null default 0,
  output_quantity numeric(14,3) not null default 0,
  unit_price numeric(14,2) not null default 0,
  total_value numeric(14,2) not null default 0,
  sell_by_unit boolean default false, sell_unit text,
  sent_to_comptoir numeric(14,3) not null default 0,
  has_loss boolean default false, expected_quantity numeric(14,3),
  loss_quantity numeric(14,3) default 0, loss_description text, loss_value numeric(14,2) default 0,
  origin text not null default 'manual' check (origin in ('manual','pos')),
  sale_id uuid, sale_reference text, line_key text,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create table if not exists public.production_used_products (
  id uuid primary key default gen_random_uuid(),
  production_id uuid not null references public.productions(id) on delete cascade,
  product_id uuid,
  product_name text not null,
  quantity_used numeric(14,4) not null default 0,
  source_type text default 'stock',
  unit text, unit_cost numeric(14,4) default 0, line_cost numeric(14,2) default 0
);

-- -----------------------------------------------------------------------------
--  8. COMPTOIR (finished goods ready to sell) & DESTRUCTIONS
-- -----------------------------------------------------------------------------
create table if not exists public.comptoir_items (
  id uuid primary key default gen_random_uuid(),
  production_id uuid references public.productions(id) on delete set null,
  product_name text not null, description text,
  quantity numeric(14,3) not null default 0,
  initial_quantity numeric(14,3) not null default 0,
  unit_price numeric(14,2) not null default 0,
  date date not null default current_date,
  category_id uuid, category_name text,
  sell_by_unit boolean default false, unit text,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create table if not exists public.destructions (
  id uuid primary key default gen_random_uuid(),
  comptoir_id uuid references public.comptoir_items(id) on delete set null,
  product_name text not null,
  quantity numeric(14,3) not null default 0,
  value numeric(14,2) not null default 0,
  reason text default '', unit text,
  date date not null default current_date,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);

-- -----------------------------------------------------------------------------
--  9. COMMANDS & DELIVERIES (a delivery = a sale)
-- -----------------------------------------------------------------------------
create sequence if not exists public.command_ref_seq;
create table if not exists public.commands (
  id uuid primary key default gen_random_uuid(),
  reference text not null default ('CMD-' || lpad(nextval('public.command_ref_seq')::text, 6, '0')),
  bon_number text,
  client_id uuid references public.clients(id) on delete set null,
  client_name text not null default '', client_phone text, client_address text,
  driver_name text, driver_plate text,
  receive_date date, receive_hour text, receive_minute text,
  total_amount numeric(14,2) not null default 0,       -- H.T
  tva_enabled boolean not null default false,
  tva_rate numeric(6,2) not null default 0,
  tva_amount numeric(14,2) not null default 0,
  total_ttc numeric(14,2) not null default 0,
  advance_paid numeric(14,2) not null default 0,
  extra_paid numeric(14,2) not null default 0,
  credit_applied numeric(14,2) not null default 0,
  paid_amount numeric(14,2) not null default 0,
  rest_amount numeric(14,2) not null default 0,
  status text not null default 'pending' check (status in ('pending','finalised','cancelled')),
  is_historical boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create table if not exists public.command_items (
  id uuid primary key default gen_random_uuid(),
  command_id uuid not null references public.commands(id) on delete cascade,
  position int not null default 0,
  product_id uuid,
  fiche_technic_id uuid references public.fiche_technics(id) on delete set null,
  product_name text not null,
  quantity numeric(14,3) not null default 0,
  delivered_quantity numeric(14,3) not null default 0,
  cancelled_quantity numeric(14,3) not null default 0,
  unit_price numeric(14,2) not null default 0,
  total_price numeric(14,2) not null default 0,
  sell_by_unit boolean default false, sell_unit text
);
create table if not exists public.command_payments (
  id uuid primary key default gen_random_uuid(),
  command_id uuid not null references public.commands(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  date date not null default current_date,
  notes text,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create table if not exists public.command_adjustments (
  id uuid primary key default gen_random_uuid(),
  command_id uuid not null references public.commands(id) on delete cascade,
  command_reference text, client_id uuid, client_name text,
  type text not null check (type in ('cancel','increase')),
  date date not null default current_date,
  reason text,
  total_quantity numeric(14,3) default 0, total_amount numeric(14,2) default 0,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create table if not exists public.command_adjustment_lines (
  id uuid primary key default gen_random_uuid(),
  adjustment_id uuid not null references public.command_adjustments(id) on delete cascade,
  command_item_id uuid references public.command_items(id) on delete set null,
  product_name text not null,
  quantity numeric(14,3) not null default 0,
  unit_price numeric(14,2) default 0, amount numeric(14,2) default 0, unit text
);

-- -----------------------------------------------------------------------------
--  10. SALES (POS, old sales, delivery invoices)
-- -----------------------------------------------------------------------------
create sequence if not exists public.sale_ref_seq;
create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  reference text not null default ('V-' || lpad(nextval('public.sale_ref_seq')::text, 6, '0')),
  client_id uuid references public.clients(id) on delete set null,
  date date not null default current_date,
  bon_number text, note text,
  is_historical boolean not null default false,  -- old sale: no stock / comptoir / caisse movement
  tva_enabled boolean not null default false,
  tva_rate numeric(6,2) not null default 0,
  tva_amount numeric(14,2) not null default 0,
  delivery_id uuid,
  command_id uuid references public.commands(id) on delete set null,
  total_amount numeric(14,2) not null default 0,   -- H.T lines
  reduction numeric(14,2) not null default 0,
  final_amount numeric(14,2) not null default 0,   -- T.T.C
  paid_amount numeric(14,2) not null default 0,
  rest_amount numeric(14,2) not null default 0,
  allocated_amount numeric(14,2) not null default 0,
  status text not null default 'paid' check (status in ('paid','debt')),
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create index if not exists sales_client_idx on public.sales (client_id);
create index if not exists sales_date_idx on public.sales (date);

create table if not exists public.sale_lines (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  comptoir_id uuid references public.comptoir_items(id) on delete set null,
  fiche_technic_id uuid references public.fiche_technics(id) on delete set null,
  production_id uuid references public.productions(id) on delete set null,
  command_item_id uuid references public.command_items(id) on delete set null,
  line_key text,
  product_name text not null,
  quantity numeric(14,3) not null default 0,
  selling_price numeric(14,2) not null default 0,
  base_price numeric(14,2),
  sell_by_unit boolean default false, unit text,
  stock_applied boolean not null default false   -- true when stock/comptoir was decremented
);

create sequence if not exists public.delivery_ref_seq;
create table if not exists public.command_deliveries (
  id uuid primary key default gen_random_uuid(),
  command_id uuid not null references public.commands(id) on delete cascade,
  reference text not null default ('BL-' || lpad(nextval('public.delivery_ref_seq')::text, 6, '0')),
  date date not null default current_date,
  delivered_at timestamptz not null default now(),
  notes text default '',
  driver_name text, driver_plate text, location text,
  is_historical boolean not null default false,
  tva_enabled boolean not null default false,
  tva_rate numeric(6,2) not null default 0,
  tva_amount numeric(14,2) not null default 0,
  total_ht numeric(14,2) not null default 0,
  total_ttc numeric(14,2) not null default 0,
  advance_applied numeric(14,2) not null default 0,
  cash_paid numeric(14,2) not null default 0,
  paid_amount numeric(14,2) not null default 0,
  rest_amount numeric(14,2) not null default 0,
  sale_id uuid references public.sales(id) on delete cascade,
  sale_reference text,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
do $$ begin
  alter table public.sales add constraint sales_delivery_fk
    foreign key (delivery_id) references public.command_deliveries(id) on delete set null
    deferrable initially immediate;
exception when duplicate_object then null; end $$;
-- sales <-> command_deliveries reference each other: deferrable so both can be restored together
do $$ begin
  alter table public.command_deliveries alter constraint command_deliveries_sale_id_fkey deferrable initially immediate;
exception when others then null; end $$;

create table if not exists public.command_delivery_items (
  id uuid primary key default gen_random_uuid(),
  delivery_id uuid not null references public.command_deliveries(id) on delete cascade,
  command_item_id uuid references public.command_items(id) on delete set null,
  product_name text not null,
  quantity numeric(14,3) not null default 0,
  sell_unit text
);
create table if not exists public.command_delivery_consumptions (
  id uuid primary key default gen_random_uuid(),
  delivery_id uuid not null references public.command_deliveries(id) on delete cascade,
  command_item_id uuid references public.command_items(id) on delete set null,
  fiche_technic_id uuid references public.fiche_technics(id) on delete set null,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  unit text,
  delivered_quantity numeric(14,3) default 0,
  quantity numeric(14,4) not null default 0,
  unit_cost numeric(14,4) default 0,
  line_cost numeric(14,2) default 0
);

-- -----------------------------------------------------------------------------
--  11. PAYMENTS & PARTY LEDGER
-- -----------------------------------------------------------------------------
create table if not exists public.client_payments (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete cascade,
  client_name text,
  amount numeric(14,2) not null check (amount > 0),
  date date not null default current_date,
  paid_at timestamptz not null default now(),
  notes text default '',
  method text not null default 'especes' check (method in ('especes','cheque','virement')),
  cheque_number text, virement_number text, bank_name text,
  credit_part numeric(14,2) not null default 0,   -- part kept as acompte
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create table if not exists public.supplier_payments (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid references public.suppliers(id) on delete cascade,
  supplier_name text,
  amount numeric(14,2) not null check (amount > 0),
  date date not null default current_date,
  paid_at timestamptz not null default now(),
  notes text default '',
  method text not null default 'especes' check (method in ('especes','cheque','virement')),
  cheque_number text, virement_number text, bank_name text,
  credit_part numeric(14,2) not null default 0,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);

-- origin: null (cash at the counter / pay debt) | 'client_payment' | 'credit' | 'command_advance'
create table if not exists public.sale_payments (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  date date not null default current_date,
  amount numeric(14,2) not null check (amount > 0),
  description text default '',
  origin text,
  client_payment_id uuid references public.client_payments(id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
-- origin: null | 'supplier_payment' | 'credit'
create table if not exists public.purchase_payments (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  date date not null default current_date,
  amount numeric(14,2) not null check (amount > 0),
  description text default '',
  origin text,
  supplier_payment_id uuid references public.supplier_payments(id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);

create table if not exists public.party_old_debts (
  id uuid primary key default gen_random_uuid(),
  party_type text not null check (party_type in ('client','supplier')),
  party_id uuid not null,
  party_name text,
  amount numeric(14,2) not null default 0,
  paid_amount numeric(14,2) not null default 0,
  rest_amount numeric(14,2) not null default 0,
  date date not null default current_date,
  description text default '',
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create table if not exists public.party_old_debt_allocations (
  id uuid primary key default gen_random_uuid(),
  old_debt_id uuid not null references public.party_old_debts(id) on delete cascade,
  client_payment_id uuid references public.client_payments(id) on delete cascade,
  supplier_payment_id uuid references public.supplier_payments(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0)
);
create table if not exists public.party_credit_refunds (
  id uuid primary key default gen_random_uuid(),
  party_type text not null check (party_type in ('client','supplier')),
  party_id uuid not null,
  party_name text,
  amount numeric(14,2) not null check (amount > 0),
  date date not null default current_date,
  refunded_at timestamptz not null default now(),
  notes text default '',
  method text not null default 'especes',
  cheque_number text, virement_number text, bank_name text,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);

-- legacy « dettes clients » screen
create table if not exists public.client_debts (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete cascade,
  client_name text not null default '', client_phone text,
  total_debt numeric(14,2) not null default 0,
  total_paid numeric(14,2) not null default 0,
  rest_amount numeric(14,2) not null default 0,
  date date not null default current_date,
  description text default '',
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create table if not exists public.client_debt_versements (
  id uuid primary key default gen_random_uuid(),
  debt_id uuid not null references public.client_debts(id) on delete cascade,
  client_id uuid, client_name text,
  amount numeric(14,2) not null check (amount > 0),
  date date not null default current_date,
  notes text,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);

-- -----------------------------------------------------------------------------
--  12. WORKERS
-- -----------------------------------------------------------------------------
create table if not exists public.workers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  birthday date, id_card_number text, phone text,
  role_id uuid references public.roles(id) on delete set null,
  payment_enabled boolean default true,
  payment_type text default 'monthly',
  payment_amount numeric(14,2) default 0,
  start_date date,
  has_account boolean default false,
  email text, username text,
  permissions jsonb not null default '{}'::jsonb,
  auth_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
do $$ begin
  alter table public.profiles add constraint profiles_worker_fk
    foreign key (worker_id) references public.workers(id) on delete set null;
exception when duplicate_object then null; end $$;

create table if not exists public.worker_acomptes (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete cascade,
  date date not null default current_date,
  amount numeric(14,2) not null check (amount > 0),
  description text default '',
  created_at timestamptz default now(), created_by text default public.current_username()
);
create table if not exists public.worker_absences (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete cascade,
  date date not null default current_date,
  description text default '', cost numeric(14,2) default 0,
  created_at timestamptz default now(), created_by text default public.current_username()
);
create table if not exists public.worker_payments (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete cascade,
  date date not null default current_date,
  period text default '',
  amount numeric(14,2) not null check (amount > 0),
  description text default '',
  kind text not null default 'salary' check (kind in ('salary','overtime')),
  created_at timestamptz default now(), created_by text default public.current_username()
);
create table if not exists public.worker_overtimes (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete cascade,
  date date not null default current_date,
  work_end_hour int default 0, work_end_minute int default 0,
  overtime_end_hour int default 0, overtime_end_minute int default 0,
  hours numeric(8,2) default 0, hourly_rate numeric(14,2) default 0,
  amount numeric(14,2) default 0, description text default '',
  is_paid boolean not null default false, paid_at date,
  payment_id uuid references public.worker_payments(id) on delete set null,
  created_at timestamptz default now(), created_by text default public.current_username()
);

-- -----------------------------------------------------------------------------
--  13. EXPENSES & PURCHASE ORDERS
-- -----------------------------------------------------------------------------
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  name text not null, description text default '',
  amount numeric(14,2) not null default 0,
  date date not null default current_date,
  category_id uuid references public.expense_categories(id) on delete set null,
  category_name text,
  created_at timestamptz default now(), created_by text default public.current_username()
);

create sequence if not exists public.purchase_order_ref_seq;
create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  reference text not null default ('BC-' || lpad(nextval('public.purchase_order_ref_seq')::text, 6, '0')),
  date date not null default current_date,
  supplier_name text default '', notes text default '',
  created_at timestamptz default now(), created_by text default public.current_username()
);
create table if not exists public.purchase_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_name text not null, description text default '',
  quantity numeric(14,3) default 0, unit text
);

-- -----------------------------------------------------------------------------
--  14. RECYCLE BIN
-- -----------------------------------------------------------------------------
create table if not exists public.recycle_bin (
  id bigserial primary key,
  tx_id bigint not null,
  table_name text not null,
  row_id text,
  data jsonb not null,
  deleted_at timestamptz not null default now(),
  deleted_by_name text default public.current_username()
);
create index if not exists recycle_tx_idx on public.recycle_bin (tx_id);
