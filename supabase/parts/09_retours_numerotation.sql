-- =============================================================================
--  09 — RETOURS D'ACHAT · NUMÉROTATION DES FACTURES ET DES BONS · LIVRAISON
--       DIRECTE (CLIENT PASSAGER / HORS COMMANDE)
-- -----------------------------------------------------------------------------
--  À exécuter APRÈS les parties 01 → 08 (ré-exécutable sans risque).
--
--  1. Numérotation imprimée :
--       · factures de vente  : 1/2026, 2/2026 … — repart à 1 chaque année ;
--       · bons de livraison  : 1, 2, 3 … — repart à 1 chaque mois.
--  2. Livraison directe : l'écran Livraisons accepte le client passager et les
--     quantités hors commande (une commande est créée automatiquement).
--  3. Retours d'achat : la marchandise achetée est rendue au fournisseur — le
--     stock diminue, la facture d'achat baisse et l'argent déjà payé revient en
--     caisse.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  1. NUMÉROTATION
-- -----------------------------------------------------------------------------
alter table public.sales add column if not exists invoice_number int;
alter table public.sales add column if not exists invoice_year int;
alter table public.command_deliveries add column if not exists bl_number int;
alter table public.command_deliveries add column if not exists bl_year int;
alter table public.command_deliveries add column if not exists bl_month int;
create index if not exists sales_invoice_no_idx on public.sales (invoice_year, invoice_number);
create index if not exists deliveries_bl_no_idx on public.command_deliveries (bl_year, bl_month, bl_number);

create or replace function public.trg_sale_invoice_number()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.invoice_number is null then
    new.invoice_year := extract(year from coalesce(new.date, current_date))::int;
    perform pg_advisory_xact_lock(hashtext('sale_invoice_no'), new.invoice_year);
    select coalesce(max(invoice_number), 0) + 1 into new.invoice_number
      from public.sales where invoice_year = new.invoice_year;
  end if;
  return new;
end $$;
drop trigger if exists sale_invoice_number_trg on public.sales;
create trigger sale_invoice_number_trg before insert on public.sales
  for each row execute function public.trg_sale_invoice_number();

create or replace function public.trg_delivery_bl_number()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_d date;
begin
  if new.bl_number is null then
    v_d := coalesce(new.date, new.delivered_at::date, current_date);
    new.bl_year := extract(year from v_d)::int;
    new.bl_month := extract(month from v_d)::int;
    perform pg_advisory_xact_lock(hashtext('delivery_bl_no'), new.bl_year * 100 + new.bl_month);
    select coalesce(max(bl_number), 0) + 1 into new.bl_number
      from public.command_deliveries where bl_year = new.bl_year and bl_month = new.bl_month;
  end if;
  return new;
end $$;
drop trigger if exists delivery_bl_number_trg on public.command_deliveries;
create trigger delivery_bl_number_trg before insert on public.command_deliveries
  for each row execute function public.trg_delivery_bl_number();

-- numéros des documents EXISTANTS, dans l'ordre chronologique
with n as (
  select id, extract(year from date)::int as y,
         row_number() over (partition by extract(year from date) order by date, created_at, reference) as rn
    from public.sales where invoice_number is null
), base as (
  select invoice_year as y, max(invoice_number) as m from public.sales
   where invoice_number is not null group by invoice_year
)
update public.sales s set invoice_year = n.y, invoice_number = n.rn + coalesce(b.m, 0)
  from n left join base b on b.y = n.y
 where s.id = n.id;

with n as (
  select id, extract(year from date)::int as y, extract(month from date)::int as m,
         row_number() over (partition by extract(year from date), extract(month from date)
                            order by date, delivered_at, created_at, reference) as rn
    from public.command_deliveries where bl_number is null
), base as (
  select bl_year as y, bl_month as m, max(bl_number) as mx from public.command_deliveries
   where bl_number is not null group by bl_year, bl_month
)
update public.command_deliveries d set bl_year = n.y, bl_month = n.m, bl_number = n.rn + coalesce(b.mx, 0)
  from n left join base b on b.y = n.y and b.m = n.m
 where d.id = n.id;

-- -----------------------------------------------------------------------------
--  2. LIVRAISON DIRECTE — client passager / quantités hors commande
-- -----------------------------------------------------------------------------
--  `direct_lines` : [{fiche_technic_id, product_name, quantity, unit_price,
--  sell_by_unit, sell_unit}] — une commande est créée pour ces quantités puis
--  livrée dans la foulée, comme n'importe quelle autre commande.
create or replace function public.create_client_delivery(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_client uuid; v_alloc jsonb := '[]'::jsonb; a jsonb; v_cmds uuid[] := '{}'; v_cmd uuid; c public.commands;
        d public.command_deliveries; v_at timestamptz; v_tva boolean; v_cash numeric; v_items jsonb;
        v_out jsonb := '[]'::jsonb; v_use_adv boolean; v_direct jsonb; cl public.clients;
        v_new uuid; it record; v_direct_tva boolean;
begin
  perform public.require_perm(array['clients:create','sales:create']);
  v_client := nullif(p_payload->>'client_id', '')::uuid;
  select * into cl from public.clients where id = v_client;
  if v_client is null or not found then
    raise exception 'Client introuvable';
  end if;
  v_at := coalesce(nullif(p_payload->>'delivered_at', '')::timestamptz, now());

  if exists (select 1 from jsonb_array_elements(coalesce(p_payload->'lines', '[]'::jsonb)) x
              where coalesce((x->>'quantity')::numeric, 0) > 0) then
    v_alloc := public._allocate_client_lines(v_client, p_payload->'lines');
  end if;

  -- quantités hors commande : nouvelle commande, livrée immédiatement
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_direct
    from jsonb_array_elements(coalesce(p_payload->'direct_lines', '[]'::jsonb)) x
   where coalesce((x->>'quantity')::numeric, 0) > 0;
  if jsonb_array_length(v_direct) > 0 then
    v_direct_tva := coalesce((p_payload->>'tva_enabled')::boolean, false);
    insert into public.commands (client_id, client_name, client_phone, client_address, driver_name, driver_plate,
      tva_enabled, tva_rate, advance_paid, notes, created_at)
    values (v_client, cl.name, cl.phone, coalesce(nullif(p_payload->>'location', ''), cl.address),
      nullif(p_payload->>'driver_name', ''), nullif(p_payload->>'driver_plate', ''),
      v_direct_tva, case when v_direct_tva then coalesce((p_payload->>'tva_rate')::numeric, 19) else 0 end,
      0, 'Commande directe — livraison', v_at)
    returning id into v_new;
    perform public._write_command_items(v_new, (
      select jsonb_agg(jsonb_build_object(
        'fiche_technic_id', x->>'fiche_technic_id', 'product_name', x->>'product_name',
        'quantity', (x->>'quantity')::numeric, 'unit_price', coalesce((x->>'unit_price')::numeric, 0),
        'total_price', round((x->>'quantity')::numeric * coalesce((x->>'unit_price')::numeric, 0), 2),
        'sell_by_unit', coalesce((x->>'sell_by_unit')::boolean, false), 'sell_unit', x->>'sell_unit'))
      from jsonb_array_elements(v_direct) x));
    perform public._recalc_command(v_new);
    for it in select id, product_name, sell_unit, quantity from public.command_items
               where command_id = v_new order by position loop
      v_alloc := v_alloc || jsonb_build_array(jsonb_build_object(
        'command_id', v_new, 'command_item_id', it.id, 'product_name', it.product_name,
        'sell_unit', it.sell_unit, 'quantity', it.quantity));
    end loop;
  end if;

  if jsonb_array_length(v_alloc) = 0 then raise exception 'Saisissez au moins une quantité à livrer'; end if;
  for a in select * from jsonb_array_elements(v_alloc) loop
    v_cmd := (a->>'command_id')::uuid;
    if not (v_cmd = any(v_cmds)) then v_cmds := v_cmds || v_cmd; end if;
  end loop;

  v_cash := greatest(0, coalesce((p_payload->>'cash_paid')::numeric, 0));
  v_use_adv := coalesce((p_payload->>'use_advance')::boolean, true);

  foreach v_cmd in array v_cmds loop
    select * into c from public.commands where id = v_cmd;
    select coalesce(jsonb_agg(x), '[]'::jsonb) into v_items
      from jsonb_array_elements(v_alloc) x where (x->>'command_id')::uuid = v_cmd;
    v_tva := case when p_payload ? 'tva_enabled' then coalesce((p_payload->>'tva_enabled')::boolean, false)
                  else c.tva_enabled end;
    insert into public.command_deliveries (command_id, date, delivered_at, notes, driver_name, driver_plate,
      location, is_historical, tva_enabled, tva_rate, source)
    values (c.id, v_at::date, v_at, coalesce(p_payload->>'notes', ''),
      coalesce(nullif(p_payload->>'driver_name', ''), c.driver_name),
      coalesce(nullif(p_payload->>'driver_plate', ''), c.driver_plate),
      coalesce(nullif(p_payload->>'location', ''), c.client_address),
      false, v_tva,
      case when v_tva then coalesce((p_payload->>'tva_rate')::numeric, nullif(c.tva_rate, 0), 19) else 0 end,
      'livraison')
    returning * into d;
    perform public._build_delivery(d.id, jsonb_build_object(
      'items', v_items,
      'advance_applied', case when v_use_adv then 999999999999 else 0 end,
      'cash_paid', v_cash));
    select * into d from public.command_deliveries where id = d.id;
    v_cash := greatest(0, v_cash - coalesce(d.cash_paid, 0));
    v_out := v_out || jsonb_build_array(to_jsonb(d));
  end loop;
  return v_out;
end $$;

-- -----------------------------------------------------------------------------
--  3. RETOURS D'ACHAT
-- -----------------------------------------------------------------------------
create sequence if not exists public.purchase_return_ref_seq;
create table if not exists public.purchase_returns (
  id uuid primary key default gen_random_uuid(),
  reference text not null default ('RA-' || lpad(nextval('public.purchase_return_ref_seq')::text, 6, '0')),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  supplier_id uuid references public.suppliers(id) on delete set null,
  date date not null default current_date,
  reason text default '',
  total_amount numeric(14,2) not null default 0,   -- valeur de la marchandise rendue
  refund_amount numeric(14,2) not null default 0,  -- argent rendu par le fournisseur (entre en caisse)
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create index if not exists purchase_returns_purchase_idx on public.purchase_returns (purchase_id);
create index if not exists purchase_returns_supplier_idx on public.purchase_returns (supplier_id);

create table if not exists public.purchase_return_items (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.purchase_returns(id) on delete cascade,
  purchase_line_id uuid references public.purchase_lines(id) on delete set null,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  quantity numeric(14,3) not null default 0,
  unit_price numeric(14,2) not null default 0,
  amount numeric(14,2) not null default 0,
  unit text,
  stock_applied boolean not null default false
);
create index if not exists purchase_return_items_return_idx on public.purchase_return_items (return_id);

-- la facture d'achat déduit la marchandise rendue, et l'argent remboursé
create or replace function public._recalc_purchase(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_total numeric; v_paid numeric; v_alloc numeric; v_has boolean; p public.purchases;
        v_ret numeric := 0; v_refund numeric := 0;
begin
  if position(p_id::text in coalesce(current_setting('app.deleting_doc', true), '')) > 0 then return; end if;
  select * into p from public.purchases where id = p_id;
  if not found then return; end if;
  select exists(select 1 from public.purchase_lines where purchase_id = p_id),
         coalesce(sum(quantity * purchase_price), 0)
    into v_has, v_total from public.purchase_lines where purchase_id = p_id;
  if to_regclass('public.purchase_returns') is not null then
    select coalesce(sum(total_amount), 0), coalesce(sum(refund_amount), 0)
      into v_ret, v_refund from public.purchase_returns where purchase_id = p_id;
  end if;
  if not v_has then v_total := p.total_amount + v_ret; end if;
  v_total := greatest(0, v_total - v_ret);
  select coalesce(sum(amount), 0), coalesce(sum(amount) filter (where origin = 'credit'), 0)
    into v_paid, v_alloc from public.purchase_payments where purchase_id = p_id;
  v_paid := greatest(0, v_paid - v_refund);
  update public.purchases set
    total_amount = round(v_total, 2), paid_amount = v_paid, allocated_amount = v_alloc,
    rest_amount = greatest(0, round(v_total, 2) - v_paid)
  where id = p_id;
end $$;

-- stock : la marchandise rendue sort du stock (sauf ancien achat)
create or replace function public.trg_purchase_return_item_stock()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_hist boolean;
begin
  if tg_op in ('UPDATE','DELETE') and old.stock_applied and old.product_id is not null then
    update public.products set
      current_quantity = current_quantity + old.quantity,
      principal_quantity = principal_quantity + old.quantity
    where id = old.product_id;
  end if;
  if tg_op in ('INSERT','UPDATE') then
    select p.is_historical into v_hist
      from public.purchase_returns r join public.purchases p on p.id = r.purchase_id
     where r.id = new.return_id;
    new.stock_applied := (not coalesce(v_hist, false)) and new.product_id is not null;
    if new.stock_applied then
      update public.products set
        current_quantity = current_quantity - new.quantity,
        principal_quantity = greatest(0, principal_quantity - new.quantity)
      where id = new.product_id;
    end if;
    return new;
  end if;
  return old;
end $$;
drop trigger if exists purchase_return_item_stock on public.purchase_return_items;
create trigger purchase_return_item_stock before insert or update or delete on public.purchase_return_items
  for each row execute function public.trg_purchase_return_item_stock();

-- caisse : l'argent rendu par le fournisseur est une ENTRÉE
create or replace function public.trg_purchase_return()
returns trigger language plpgsql security definer set search_path = public as $$
declare p public.purchases;
begin
  if tg_op = 'DELETE' then
    perform public._caisse_clear('purchase_returns', old.id);
    perform public._recalc_purchase(old.purchase_id);
    return old;
  end if;
  select * into p from public.purchases where id = new.purchase_id;
  if not coalesce(p.is_historical, false) then
    perform public._caisse_set('purchase_returns', new.id, 'deposit', new.refund_amount, new.date,
      'Retour achat ' || new.reference || ' (' || coalesce(p.reference, '') || ')', 'Achat');
  else
    perform public._caisse_clear('purchase_returns', new.id);
  end if;
  perform public._recalc_purchase(new.purchase_id);
  return new;
end $$;
drop trigger if exists purchase_return_trg on public.purchase_returns;
create trigger purchase_return_trg after insert or update or delete on public.purchase_returns
  for each row execute function public.trg_purchase_return();

-- payload : {purchase_id, date, reason, items: [{purchase_line_id, quantity}]}
create or replace function public.create_purchase_return(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare p public.purchases; r public.purchase_returns; x jsonb; l public.purchase_lines;
        v_qty numeric; v_done numeric; v_total numeric := 0; v_lines numeric; v_paid numeric;
        v_refunded numeric; v_returned numeric; v_refund numeric;
begin
  perform public.require_perm(array['purchase:create','purchase:edit']);
  select * into p from public.purchases where id = nullif(p_payload->>'purchase_id', '')::uuid for update;
  if not found then raise exception 'Facture d''achat introuvable'; end if;

  insert into public.purchase_returns (purchase_id, supplier_id, date, reason)
  values (p.id, p.supplier_id, coalesce(nullif(p_payload->>'date', '')::date, current_date),
          coalesce(p_payload->>'reason', ''))
  returning * into r;

  for x in select * from jsonb_array_elements(coalesce(p_payload->'items', '[]'::jsonb)) loop
    v_qty := round(coalesce((x->>'quantity')::numeric, 0), 3);
    continue when v_qty <= 0;
    select * into l from public.purchase_lines
     where id = nullif(x->>'purchase_line_id', '')::uuid and purchase_id = p.id;
    if not found then raise exception 'Ligne d''achat introuvable'; end if;
    select coalesce(sum(ri.quantity), 0) into v_done from public.purchase_return_items ri
     where ri.purchase_line_id = l.id;
    if v_qty > l.quantity - v_done + 0.0005 then
      raise exception 'Retour de « % » : % dépasse la quantité achetée non encore rendue (%)',
        l.product_name, v_qty, round(l.quantity - v_done, 3);
    end if;
    insert into public.purchase_return_items (return_id, purchase_line_id, product_id, product_name,
      quantity, unit_price, amount, unit)
    values (r.id, l.id, l.product_id, l.product_name, v_qty, l.purchase_price,
      round(v_qty * l.purchase_price, 2), case when l.unit_enabled then l.unit end);
    v_total := v_total + round(v_qty * l.purchase_price, 2);
  end loop;
  if v_total <= 0 then raise exception 'Saisissez au moins une quantité à rendre'; end if;

  -- argent récupéré : ce qui a été payé AU-DELÀ du nouveau total de la facture
  select coalesce(sum(quantity * purchase_price), 0) into v_lines from public.purchase_lines where purchase_id = p.id;
  select coalesce(sum(amount), 0) into v_paid from public.purchase_payments where purchase_id = p.id;
  select coalesce(sum(refund_amount), 0), coalesce(sum(total_amount), 0) into v_refunded, v_returned
    from public.purchase_returns where purchase_id = p.id and id <> r.id;
  v_refund := greatest(0, least(v_total, (v_paid - v_refunded) - (v_lines - v_returned - v_total)));

  update public.purchase_returns set total_amount = v_total, refund_amount = round(v_refund, 2)
   where id = r.id returning * into r;
  return to_jsonb(r);
end $$;
grant execute on function public.create_purchase_return(jsonb) to authenticated;

-- module des tables (droits, corbeille, journal)
create or replace function public._table_module(p_table text)
returns text language sql immutable as $$
  select case
    when p_table in ('products','marques','categories','units') then 'stock'
    when p_table in ('purchases','purchase_lines','purchase_payments','purchase_returns','purchase_return_items') then 'purchase'
    when p_table in ('productions','production_categories','fiche_technics','fiche_categories') then 'production'
    when p_table in ('comptoir_items','destructions') then 'comptoir'
    when p_table in ('sales','sale_lines','sale_payments','free_invoices','free_invoice_lines') then 'sales'
    when p_table in ('clients','commands','command_items','command_payments','command_deliveries','client_debts',
                     'client_payments','party_old_debts','party_credit_refunds','command_adjustments',
                     'delivery_recoveries','delivery_recovery_items') then 'clients'
    when p_table in ('suppliers','supplier_payments') then 'suppliers'
    when p_table in ('workers','worker_acomptes','worker_absences','worker_payments','worker_overtimes','roles') then 'workers'
    when p_table in ('expenses','expense_categories','purchase_orders') then 'expenses'
    when p_table in ('caisse_transactions','caisse_categories','caisse_reports') then 'caisse'
    else 'settings' end
$$;

do $$
declare t text;
begin
  foreach t in array array['purchase_returns','purchase_return_items'] loop
    execute format('drop trigger if exists zz_recycle on public.%I', t);
    execute format('create trigger zz_recycle after delete on public.%I for each row execute function public.trg_recycle_capture()', t);
  end loop;
end $$;

do $$
declare rec record; r text[]; w text[];
begin
  for rec in
    select * from (values
      ('purchase_returns',      '{purchase,suppliers,stock,caisse,dashboard,reports}', '{purchase,suppliers}'),
      ('purchase_return_items', '{purchase,suppliers,stock,caisse,dashboard,reports}', '{purchase,suppliers}')
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

grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

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

-- -----------------------------------------------------------------------------
--  4. EN-TÊTE DES DOCUMENTS — coordonnées de l'entreprise
-- -----------------------------------------------------------------------------
update public.store_settings set
  name           = 'SARL ADEL LIL WARAK',
  description    = 'FABRICATION ET TRANSFORMATION DU PAPIER',
  email          = 'adel16papier@gmail.com',
  phone          = '0552217369',
  nif            = '001735072796182',
  nis            = '001735370031843',
  article        = '35370037144',
  rc             = '35/000727961B17',
  activity_place = 'CITE BEN DANOUN SECT07 GPL31KHEMIS ELKHECHNA BOUMERDES',
  address        = '35000 HAI BENDANOUN CLASSE 07 GP 31 KHEMIS EL KHECHNA BOUMERDES',
  city           = coalesce(nullif(trim(city), ''), 'BOUMERDES'),
  updated_at     = now()
where id;

notify pgrst, 'reload schema';
