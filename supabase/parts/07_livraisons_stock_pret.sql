-- =============================================================================
--  MISE À JOUR 2026-10 — LIVRAISONS, STOCK PRÊT, RÉCUPÉRATIONS,
--  FACTURES NON COMPTABILISÉES, IMAGES DES FICHES TECHNIQUES
-- -----------------------------------------------------------------------------
--  À exécuter UNE fois sur une base existante (SQL editor → Run). Le script peut
--  être relancé sans risque. Sur une installation neuve il est déjà inclus à la
--  fin de papeterie_supabase_full.sql.
--
--  Les fonctions redéfinies ici (create or replace) REMPLACENT celles des
--  parties 02 à 06 : _recalc_sale, trg_delivery_item, _build_delivery,
--  update_command_delivery, _write_fiche, _transfer_to_comptoir, _table_module.
--
--  STOCK PRÊT d'un produit (fiche technique) =
--      productions du produit (hors caisse) − envoyé au comptoir
--    − quantités livrées depuis le stock prêt
--    + quantités récupérées sur des bons de livraison
--
--  Une livraison prend d'abord dans le stock prêt ; ce qui manque est PRODUIT
--  automatiquement (production rattachée au bon, matières déduites du stock)
--  puis livré. Supprimer ou modifier le bon défait cette production.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  1. COLONNES
-- -----------------------------------------------------------------------------
alter table public.fiche_technics add column if not exists image_url text;

alter table public.productions add column if not exists delivery_id uuid;
do $$ begin
  alter table public.productions add constraint productions_delivery_fk
    foreign key (delivery_id) references public.command_deliveries(id) on delete cascade;
exception when duplicate_object then null; end $$;
alter table public.productions drop constraint if exists productions_origin_check;
alter table public.productions add constraint productions_origin_check
  check (origin in ('manual','pos','delivery'));
create index if not exists productions_fiche_idx on public.productions (fiche_technic_id);
create index if not exists productions_delivery_idx on public.productions (delivery_id);

-- 'command' : bon créé depuis l'écran Commandes · 'livraison' : depuis l'écran Livraisons
alter table public.command_deliveries add column if not exists source text not null default 'command';

alter table public.command_delivery_items add column if not exists fiche_technic_id uuid;
alter table public.command_delivery_items add column if not exists ready_applied boolean not null default false;
alter table public.command_delivery_items add column if not exists from_ready numeric(14,3) not null default 0;
alter table public.command_delivery_items add column if not exists produced_quantity numeric(14,3) not null default 0;
alter table public.command_delivery_items add column if not exists unit_cost numeric(14,4) not null default 0;
alter table public.command_delivery_items add column if not exists cost_amount numeric(14,2) not null default 0;
create index if not exists cdi_fiche_idx on public.command_delivery_items (fiche_technic_id);
create index if not exists cdi_item_idx on public.command_delivery_items (command_item_id);

-- les lignes déjà livrées connaissent désormais leur produit
update public.command_delivery_items di set fiche_technic_id = ci.fiche_technic_id
  from public.command_items ci
 where di.command_item_id = ci.id and di.fiche_technic_id is null and ci.fiche_technic_id is not null;

-- part de l'encaissement d'une facture rendue au client après une récupération
alter table public.sales add column if not exists refunded_amount numeric(14,2) not null default 0;

-- -----------------------------------------------------------------------------
--  2. TABLES
-- -----------------------------------------------------------------------------
create sequence if not exists public.recovery_ref_seq;
create table if not exists public.delivery_recoveries (
  id uuid primary key default gen_random_uuid(),
  reference text not null default ('RET-' || lpad(nextval('public.recovery_ref_seq')::text, 6, '0')),
  delivery_id uuid not null references public.command_deliveries(id) on delete cascade,
  command_id uuid references public.commands(id) on delete set null,
  client_id uuid references public.clients(id) on delete set null,
  client_name text,
  date date not null default current_date,
  recovered_at timestamptz not null default now(),
  reason text default '',
  tva_enabled boolean not null default false,
  tva_rate numeric(6,2) not null default 0,
  total_ht numeric(14,2) not null default 0,
  tva_amount numeric(14,2) not null default 0,
  total_ttc numeric(14,2) not null default 0,
  excess_amount numeric(14,2) not null default 0,   -- argent payé que la facture n'appelle plus
  refund_amount numeric(14,2) not null default 0,   -- part rendue en espèces (sortie de caisse)
  refund_method text not null default 'especes',
  refund_id uuid references public.party_credit_refunds(id) on delete set null,
  is_historical boolean not null default false,
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create index if not exists recoveries_delivery_idx on public.delivery_recoveries (delivery_id);

create table if not exists public.delivery_recovery_items (
  id uuid primary key default gen_random_uuid(),
  recovery_id uuid not null references public.delivery_recoveries(id) on delete cascade,
  command_item_id uuid references public.command_items(id) on delete set null,
  fiche_technic_id uuid,
  product_name text not null,
  quantity numeric(14,3) not null default 0,
  unit_price numeric(14,2) not null default 0,
  amount numeric(14,2) not null default 0,
  unit text,
  ready_applied boolean not null default true,
  unit_cost numeric(14,4) not null default 0,
  cost_amount numeric(14,2) not null default 0
);
create index if not exists recovery_items_fiche_idx on public.delivery_recovery_items (fiche_technic_id);
create index if not exists recovery_items_item_idx on public.delivery_recovery_items (command_item_id);

-- Factures NON COMPTABILISÉES : documents imprimables, sans aucun effet
-- (ni stock, ni caisse, ni dette, ni rapport).
create sequence if not exists public.free_invoice_ref_seq;
create table if not exists public.free_invoices (
  id uuid primary key default gen_random_uuid(),
  reference text not null default ('FNC-' || lpad(nextval('public.free_invoice_ref_seq')::text, 6, '0')),
  doc_type text not null default 'facture' check (doc_type in ('facture','bon_livraison','proforma')),
  client_id uuid references public.clients(id) on delete set null,
  client_name text not null default '',
  client_phone text, client_address text,
  client_rc text, client_nif text, client_nis text, client_article text,
  date date not null default current_date,
  location text, driver_name text, driver_plate text,
  tva_enabled boolean not null default false,
  tva_rate numeric(6,2) not null default 0,
  reduction numeric(14,2) not null default 0,
  total_amount numeric(14,2) not null default 0,
  tva_amount numeric(14,2) not null default 0,
  final_amount numeric(14,2) not null default 0,
  paid_amount numeric(14,2) not null default 0,
  rest_amount numeric(14,2) not null default 0,
  payment_mode text,
  notes text default '',
  created_at timestamptz not null default now(),
  created_by text default public.current_username()
);
create table if not exists public.free_invoice_lines (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.free_invoices(id) on delete cascade,
  position int not null default 0,
  fiche_technic_id uuid,
  product_name text not null,
  description text default '',
  quantity numeric(14,3) not null default 0,
  unit text,
  unit_price numeric(14,2) not null default 0,
  total_price numeric(14,2) not null default 0
);

-- -----------------------------------------------------------------------------
--  3. STOCK PRÊT & COÛT DE REVIENT D'UN PRODUIT
-- -----------------------------------------------------------------------------
create or replace function public.fiche_ready_quantity(p_fiche uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select round(
      coalesce((select sum(output_quantity - sent_to_comptoir) from public.productions
                 where fiche_technic_id = p_fiche and origin <> 'pos'), 0)
    - coalesce((select sum(quantity) from public.command_delivery_items
                 where fiche_technic_id = p_fiche and ready_applied), 0)
    + coalesce((select sum(ri.quantity) from public.delivery_recovery_items ri
                  join public.delivery_recoveries r on r.id = ri.recovery_id
                 where ri.fiche_technic_id = p_fiche and ri.ready_applied), 0), 3)
$$;

create or replace function public._fiche_unit_cost(p_fiche uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(
    (select sum(total_cost) / nullif(sum(output_quantity), 0)
       from public.productions where fiche_technic_id = p_fiche and output_quantity > 0),
    (select nullif(cost_per_unit, 0) from public.fiche_technics where id = p_fiche),
    (select total_cost / nullif(output_quantity, 0) from public.fiche_technics where id = p_fiche),
    0)
$$;

-- -----------------------------------------------------------------------------
--  4. QUANTITÉ LIVRÉE D'UNE LIGNE DE COMMANDE = livré − récupéré (recalculée)
-- -----------------------------------------------------------------------------
create or replace function public._recalc_item_delivered(p_item uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_item is null then return; end if;
  update public.command_items set delivered_quantity = greatest(0, round(
      coalesce((select sum(di.quantity) from public.command_delivery_items di where di.command_item_id = p_item), 0)
    - coalesce((select sum(ri.quantity) from public.delivery_recovery_items ri
                  join public.delivery_recoveries r on r.id = ri.recovery_id
                 where ri.command_item_id = p_item), 0), 3))
  where id = p_item;
end $$;

create or replace function public.trg_delivery_item()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op <> 'INSERT' then perform public._recalc_item_delivered(old.command_item_id); end if;
  if tg_op <> 'DELETE' then perform public._recalc_item_delivered(new.command_item_id); end if;
  return coalesce(new, old);
end $$;
drop trigger if exists delivery_item_trg on public.command_delivery_items;
create trigger delivery_item_trg after insert or update or delete on public.command_delivery_items
  for each row execute function public.trg_delivery_item();

-- -----------------------------------------------------------------------------
--  5. FACTURE D'UN BON : lignes = livré − récupéré ; argent rendu déduit
-- -----------------------------------------------------------------------------
create or replace function public._recalc_sale(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare s public.sales; v_total numeric; v_base numeric; v_tva numeric; v_final numeric;
        v_paid numeric; v_alloc numeric; v_has_lines boolean;
begin
  if position(p_id::text in coalesce(current_setting('app.deleting_doc', true), '')) > 0 then return; end if;
  select * into s from public.sales where id = p_id;
  if not found then return; end if;
  select exists(select 1 from public.sale_lines where sale_id = p_id),
         coalesce(sum(quantity * selling_price), 0)
    into v_has_lines, v_total from public.sale_lines where sale_id = p_id;
  if not v_has_lines then v_total := s.total_amount; end if;
  v_base := greatest(0, round(v_total, 2) - coalesce(s.reduction, 0));
  v_tva := case when s.tva_enabled then round(v_base * s.tva_rate) / 100 else 0 end;
  v_final := round(v_base + v_tva, 2);
  select coalesce(sum(amount), 0), coalesce(sum(amount) filter (where origin = 'credit'), 0)
    into v_paid, v_alloc from public.sale_payments where sale_id = p_id;
  -- argent rendu au client après une récupération : il ne paie plus la facture
  v_paid := greatest(0, v_paid - least(coalesce(s.refunded_amount, 0), v_paid));
  update public.sales set
    total_amount = round(v_total, 2), tva_amount = v_tva, final_amount = v_final,
    paid_amount = v_paid, allocated_amount = v_alloc,
    rest_amount = greatest(0, v_final - v_paid),
    status = case when v_final - v_paid > 0.004 then 'debt' else 'paid' end
  where id = p_id;
  if s.delivery_id is not null then
    update public.command_deliveries d set
      total_ht = v_base, tva_amount = v_tva, total_ttc = v_final,
      tva_enabled = s.tva_enabled, tva_rate = s.tva_rate,
      advance_applied = coalesce((select sum(amount) from public.sale_payments where sale_id = p_id and origin = 'command_advance'), 0),
      cash_paid = coalesce((select sum(amount) from public.sale_payments where sale_id = p_id and origin is distinct from 'command_advance'), 0),
      paid_amount = v_paid, rest_amount = greatest(0, v_final - v_paid)
    where d.id = s.delivery_id;
  end if;
end $$;

create or replace function public._sync_delivery_sale(p_delivery uuid)
returns void language plpgsql security definer set search_path = public as $$
declare d public.command_deliveries; l record; v_qty numeric; v_ref numeric;
begin
  select * into d from public.command_deliveries where id = p_delivery;
  if not found or d.sale_id is null then return; end if;
  if not exists (select 1 from public.sales where id = d.sale_id) then return; end if;
  if position(d.sale_id::text in coalesce(current_setting('app.deleting_doc', true), '')) > 0 then return; end if;
  for l in select sl.id, sl.command_item_id, sl.quantity from public.sale_lines sl
            where sl.sale_id = d.sale_id and sl.command_item_id is not null loop
    v_qty := greatest(0, round(
        coalesce((select sum(quantity) from public.command_delivery_items
                   where delivery_id = d.id and command_item_id = l.command_item_id), 0)
      - coalesce((select sum(ri.quantity) from public.delivery_recovery_items ri
                    join public.delivery_recoveries r on r.id = ri.recovery_id
                   where r.delivery_id = d.id and ri.command_item_id = l.command_item_id), 0), 3));
    if abs(v_qty - l.quantity) > 0.0005 then
      update public.sale_lines set quantity = v_qty where id = l.id;
    end if;
  end loop;
  -- montant non plafonné : `_recalc_sale` le borne aux encaissements présents,
  -- quel que soit l'ordre dans lequel ils reviennent (corbeille)
  select coalesce(sum(excess_amount), 0) into v_ref from public.delivery_recoveries where delivery_id = d.id;
  update public.sales set refunded_amount = round(v_ref, 2) where id = d.sale_id;
  perform public._recalc_sale(d.sale_id);
end $$;

-- -----------------------------------------------------------------------------
--  6. PRODUCTION AUTOMATIQUE DU MANQUANT D'UNE LIVRAISON
-- -----------------------------------------------------------------------------
create or replace function public._auto_produce(p_fiche uuid, p_qty numeric, p_delivery uuid, p_date date, p_label text)
returns public.productions language plpgsql security definer set search_path = public as $$
declare f public.fiche_technics; v public.productions; fl record; v_lines jsonb := '[]'::jsonb;
        v_factor numeric; v_qty numeric; v_cost numeric; v_pid uuid; pr public.products;
begin
  select * into f from public.fiche_technics where id = p_fiche;
  if not found or coalesce(p_qty, 0) <= 0 then return null; end if;
  v_factor := p_qty / coalesce(nullif(f.output_quantity, 0), 1);
  for fl in select * from public.fiche_technic_lines where fiche_technic_id = p_fiche loop
    v_qty := round(coalesce(fl.quantity_used, 0) * v_factor, 4);
    continue when v_qty <= 0;
    v_pid := fl.product_id;
    v_cost := coalesce(fl.unit_cost, 0);
    if coalesce(fl.source_type, 'stock') = 'stock' then
      -- matière du stock : par identifiant, sinon par nom ; prix d'achat actuel
      select * into pr from public.products where id = fl.product_id;
      if not found then
        select * into pr from public.products
         where lower(trim(name)) = lower(trim(fl.product_name)) order by created_at limit 1;
      end if;
      if pr.id is not null then
        v_pid := pr.id;
        v_cost := coalesce(nullif(pr.purchase_price, 0), fl.unit_cost, 0);
      else
        v_pid := null;
      end if;
    end if;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'product_id', v_pid, 'product_name', fl.product_name, 'quantity_used', v_qty,
      'source_type', coalesce(fl.source_type, 'stock'), 'unit', fl.unit,
      'unit_cost', v_cost, 'line_cost', round(v_qty * v_cost, 2)));
  end loop;
  v := public._create_production(jsonb_build_object(
    'name', f.name,
    'description', 'Production automatique — ' || coalesce(p_label, 'livraison'),
    'date', coalesce(p_date, current_date),
    'fiche_technic_id', f.id,
    'category_id', f.category_id, 'category_name', f.category_name,
    'output_quantity', round(p_qty, 3), 'unit_price', coalesce(f.unit_price, 0),
    'sell_by_unit', coalesce(f.sell_by_unit, false), 'sell_unit', f.sell_unit,
    'used_products', v_lines));
  update public.productions set origin = 'delivery', delivery_id = p_delivery where id = v.id returning * into v;
  return v;
end $$;

-- -----------------------------------------------------------------------------
--  7. CONSTRUCTION D'UN BON DE LIVRAISON (stock prêt + production + facture)
-- -----------------------------------------------------------------------------
create or replace function public._build_delivery(p_id uuid, p jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare d public.command_deliveries; c public.commands; it record; ci public.command_items; rv record;
        v_qty numeric; v_lines jsonb := '[]'::jsonb; v_sale public.sales; pay record;
        v_adv_avail numeric; v_adv numeric; v_cash numeric; v_over numeric;
        v_ready numeric; v_from_ready numeric; v_produced numeric; v_cost numeric; v_live boolean;
begin
  select * into d from public.command_deliveries where id = p_id;
  select * into c from public.commands where id = d.command_id;
  v_live := not coalesce(d.is_historical, false);

  -- une seule ligne par ligne de commande, dans l'ordre de saisie
  for it in
    select nullif(x->>'command_item_id', '')::uuid as item_id,
           coalesce(x->>'product_name', '') as product_name,
           max(x->>'sell_unit') as sell_unit,
           sum(coalesce((x->>'quantity')::numeric, 0)) as qty
      from jsonb_array_elements(coalesce(p->'items', '[]'::jsonb)) with ordinality as t(x, n)
     group by 1, 2
     order by min(n)
  loop
    v_qty := round(coalesce(it.qty, 0), 3);
    continue when v_qty <= 0;
    select * into ci from public.command_items where id = it.item_id and command_id = c.id;

    -- le produit fini sort du STOCK PRÊT ; le manquant est produit maintenant
    v_from_ready := 0; v_produced := 0; v_cost := 0;
    if ci.fiche_technic_id is not null and v_live then
      v_ready := greatest(0, public.fiche_ready_quantity(ci.fiche_technic_id));
      v_from_ready := least(v_qty, v_ready);
      v_produced := round(v_qty - v_from_ready, 3);
      if v_produced > 0.0005 then
        perform public._auto_produce(ci.fiche_technic_id, v_produced, p_id, d.date, 'BL ' || d.reference);
      else
        v_produced := 0;
      end if;
      v_cost := public._fiche_unit_cost(ci.fiche_technic_id);
    end if;

    insert into public.command_delivery_items (delivery_id, command_item_id, product_name, quantity, sell_unit,
      fiche_technic_id, ready_applied, from_ready, produced_quantity, unit_cost, cost_amount)
    values (p_id, ci.id, coalesce(nullif(it.product_name, ''), ci.product_name, ''), v_qty,
      coalesce(it.sell_unit, ci.sell_unit), ci.fiche_technic_id,
      ci.fiche_technic_id is not null and v_live, v_from_ready, v_produced,
      round(coalesce(v_cost, 0), 4), round(coalesce(v_cost, 0) * v_qty, 2));

    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'product_name', coalesce(nullif(it.product_name, ''), ci.product_name, ''), 'quantity', v_qty,
      'selling_price', coalesce(ci.unit_price, 0), 'base_price', ci.unit_price,
      'fiche_technic_id', ci.fiche_technic_id, 'command_item_id', ci.id,
      'sell_by_unit', coalesce(ci.sell_by_unit, false), 'unit', coalesce(it.sell_unit, ci.sell_unit)));
  end loop;

  -- la facture
  v_sale := public._create_sale(jsonb_build_object(
    'client_id', c.client_id, 'date', d.date, 'bon_number', coalesce(c.bon_number, d.reference),
    'is_historical', d.is_historical, 'tva_enabled', d.tva_enabled, 'tva_rate', d.tva_rate,
    'delivery_id', d.id, 'command_id', c.id, 'products', v_lines, 'paid_amount', 0));

  -- l'argent : acompte de la commande (pas de caisse) + encaissement à la remise (caisse)
  select greatest(0, c.paid_amount - coalesce(sum(advance_applied), 0)) into v_adv_avail
    from public.command_deliveries where command_id = c.id and id <> p_id;
  v_adv := least(coalesce((p->>'advance_applied')::numeric, 0), v_adv_avail, v_sale.final_amount);
  if v_adv > 0.004 then
    insert into public.sale_payments (sale_id, date, amount, description, origin)
    values (v_sale.id, d.date, round(v_adv, 2), 'Acompte de la commande ' || c.reference, 'command_advance');
  end if;
  v_cash := least(coalesce((p->>'cash_paid')::numeric, 0), greatest(0, v_sale.final_amount - greatest(v_adv, 0)));
  if v_cash > 0.004 then
    insert into public.sale_payments (sale_id, date, amount, description)
    values (v_sale.id, d.date, round(v_cash, 2), 'Versement à la livraison ' || d.reference);
  end if;

  update public.command_deliveries set sale_id = v_sale.id, sale_reference = v_sale.reference where id = p_id;

  -- les récupérations déjà faites sur ce bon restent appliquées à la facture refaite
  if exists (select 1 from public.delivery_recoveries where delivery_id = p_id) then
    for rv in select ri.command_item_id, sum(ri.quantity) as q
                from public.delivery_recovery_items ri
                join public.delivery_recoveries r on r.id = ri.recovery_id
               where r.delivery_id = p_id group by 1 loop
      if rv.q > coalesce((select sum(quantity) from public.command_delivery_items
                           where delivery_id = p_id and command_item_id is not distinct from rv.command_item_id), 0) + 0.0005 then
        raise exception 'Ce bon a des récupérations : chaque produit doit rester livré au moins pour la quantité déjà récupérée';
      end if;
    end loop;
    perform public._sync_delivery_sale(p_id);
    -- jamais plus encaissé que ce que le client garde : l'encaissement saisi est ramené
    select greatest(0, paid_amount - final_amount) into v_over from public.sales where id = v_sale.id;
    if v_over > 0.004 then
      for pay in select id, amount from public.sale_payments
                  where sale_id = v_sale.id and origin is null order by created_at desc loop
        exit when v_over <= 0.004;
        if pay.amount <= v_over + 0.004 then
          delete from public.sale_payments where id = pay.id;
          v_over := v_over - pay.amount;
        else
          update public.sale_payments set amount = round(pay.amount - v_over, 2) where id = pay.id;
          v_over := 0;
        end if;
      end loop;
      perform public._sync_delivery_sale(p_id);
    end if;
  end if;

  perform public._recalc_sale(v_sale.id);
  perform public._recalc_command(c.id);
end $$;

-- Avant de refaire la facture d'un bon : les versements du client qui la
-- payaient (« client_payment ») redeviennent son ACOMPTE au lieu de disparaître
-- avec elle ; l'écran les réimpute ensuite sur la nouvelle facture.
create or replace function public._release_sale_allocations(p_sale uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if p_sale is null then return; end if;
  for r in select sp.client_payment_id, sum(sp.amount) as a from public.sale_payments sp
            where sp.sale_id = p_sale and sp.origin = 'client_payment' and sp.client_payment_id is not null
            group by 1 loop
    update public.client_payments set credit_part = credit_part + r.a where id = r.client_payment_id;
    update public.clients set credit_amount = credit_amount + r.a
     where id = (select client_id from public.client_payments where id = r.client_payment_id);
  end loop;
end $$;

-- Modifier un bon depuis l'écran Commandes : tout est défait puis reconstruit.
create or replace function public.update_command_delivery(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d public.command_deliveries; c public.commands; v_tva boolean; v_sale uuid; v_at timestamptz;
begin
  perform public.require_perm(array['clients:edit','sales:edit']);
  select * into d from public.command_deliveries where id = p_id;
  if not found then raise exception 'Bon de livraison introuvable'; end if;
  select * into c from public.commands where id = d.command_id;
  -- défaire : facture, quantités livrées, matières et productions automatiques
  v_sale := d.sale_id;
  perform public._release_sale_allocations(v_sale);
  update public.command_deliveries set sale_id = null where id = p_id;
  if v_sale is not null then delete from public.sales where id = v_sale; end if;
  delete from public.command_delivery_items where delivery_id = p_id;
  delete from public.command_delivery_consumptions where delivery_id = p_id;
  delete from public.productions where delivery_id = p_id;

  v_tva := case when p_payload ? 'tva_enabled' then coalesce((p_payload->>'tva_enabled')::boolean, false) else d.tva_enabled end;
  v_at := coalesce(nullif(p_payload->>'delivered_at', '')::timestamptz, d.delivered_at);
  update public.command_deliveries set
    delivered_at = v_at, date = v_at::date,
    notes = coalesce(p_payload->>'notes', notes),
    driver_name = case when p_payload ? 'driver_name' then p_payload->>'driver_name' else driver_name end,
    driver_plate = case when p_payload ? 'driver_plate' then p_payload->>'driver_plate' else driver_plate end,
    location = case when p_payload ? 'location' then p_payload->>'location' else location end,
    is_historical = c.is_historical, tva_enabled = v_tva,
    tva_rate = case when v_tva then coalesce((p_payload->>'tva_rate')::numeric, nullif(tva_rate, 0), 19) else 0 end
  where id = p_id;
  perform public._build_delivery(p_id, p_payload);
  select * into d from public.command_deliveries where id = p_id;
  return to_jsonb(d);
end $$;

-- -----------------------------------------------------------------------------
--  8. ÉCRAN LIVRAISONS : client → produit → quantité
--     Les quantités sont imputées sur les commandes en cours du client, la plus
--     ancienne d'abord. Un bon par commande touchée.
-- -----------------------------------------------------------------------------
create or replace function public._allocate_client_lines(
  p_client uuid, p_lines jsonb, p_prefer_items uuid[] default '{}', p_prefer_command uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare l record; r record; v_need numeric; v_take numeric; v_out jsonb := '[]'::jsonb;
begin
  for l in
    select nullif(x->>'fiche_technic_id', '')::uuid as fiche,
           case when nullif(x->>'fiche_technic_id', '') is null
                then lower(trim(coalesce(x->>'product_name', ''))) end as lname,
           max(coalesce(x->>'product_name', '')) as pname,
           sum(coalesce((x->>'quantity')::numeric, 0)) as qty
      from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) with ordinality as t(x, n)
     group by 1, 2
     order by min(n)
  loop
    v_need := round(coalesce(l.qty, 0), 3);
    continue when v_need <= 0;
    for r in
      select ci.id, ci.command_id, ci.product_name, ci.sell_unit,
             greatest(0, ci.quantity - ci.cancelled_quantity - ci.delivered_quantity) as left_qty
        from public.command_items ci
        join public.commands cm on cm.id = ci.command_id
       where cm.client_id = p_client and cm.status <> 'cancelled' and not coalesce(cm.is_historical, false)
         and ((l.fiche is not null and (ci.fiche_technic_id = l.fiche
                or (ci.fiche_technic_id is null and lower(trim(ci.product_name)) = lower(trim(l.pname)))))
              or (l.fiche is null and lower(trim(ci.product_name)) = l.lname))
         and ci.quantity - ci.cancelled_quantity - ci.delivered_quantity > 0.0005
       order by (ci.id = any(coalesce(p_prefer_items, '{}'))) desc,
                (cm.id = p_prefer_command) desc nulls last,
                cm.created_at, cm.reference, ci.position
       for update of ci
    loop
      exit when v_need <= 0.0005;
      v_take := round(least(v_need, r.left_qty), 3);
      continue when v_take <= 0;
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'command_id', r.command_id, 'command_item_id', r.id, 'product_name', r.product_name,
        'sell_unit', r.sell_unit, 'quantity', v_take));
      v_need := v_need - v_take;
    end loop;
    if v_need > 0.0005 then
      raise exception 'La quantité de « % » dépasse le reste à livrer des commandes du client (excédent : %)',
        coalesce(nullif(l.pname, ''), (select name from public.fiche_technics where id = l.fiche), '?'), round(v_need, 3);
    end if;
  end loop;
  return v_out;
end $$;

create or replace function public.create_client_delivery(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_client uuid; v_alloc jsonb; a jsonb; v_cmds uuid[] := '{}'; v_cmd uuid; c public.commands;
        d public.command_deliveries; v_at timestamptz; v_tva boolean; v_cash numeric; v_items jsonb;
        v_out jsonb := '[]'::jsonb; v_use_adv boolean;
begin
  perform public.require_perm(array['clients:create','sales:create']);
  v_client := nullif(p_payload->>'client_id', '')::uuid;
  if v_client is null or not exists (select 1 from public.clients where id = v_client) then
    raise exception 'Client introuvable';
  end if;
  v_alloc := public._allocate_client_lines(v_client, p_payload->'lines');
  if jsonb_array_length(v_alloc) = 0 then raise exception 'Saisissez au moins une quantité à livrer'; end if;
  for a in select * from jsonb_array_elements(v_alloc) loop
    v_cmd := (a->>'command_id')::uuid;
    if not (v_cmd = any(v_cmds)) then v_cmds := v_cmds || v_cmd; end if;
  end loop;

  v_at := coalesce(nullif(p_payload->>'delivered_at', '')::timestamptz, now());
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

create or replace function public.update_client_delivery(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d public.command_deliveries; c public.commands; v_client uuid; v_prev uuid[]; v_alloc jsonb;
        v_cmd uuid; v_old_cmd uuid; v_n int; v_sale uuid; v_tva boolean; v_at timestamptz;
begin
  perform public.require_perm(array['clients:edit','sales:edit']);
  select * into d from public.command_deliveries where id = p_id;
  if not found then raise exception 'Bon de livraison introuvable'; end if;
  if coalesce(d.is_historical, false) then
    raise exception 'Une ancienne livraison se modifie depuis l''écran Commandes';
  end if;
  select * into c from public.commands where id = d.command_id;
  v_old_cmd := d.command_id;
  v_client := coalesce(nullif(p_payload->>'client_id', '')::uuid, c.client_id);
  if v_client is null or not exists (select 1 from public.clients where id = v_client) then
    raise exception 'Client introuvable';
  end if;
  if v_client is distinct from c.client_id
     and exists (select 1 from public.delivery_recoveries where delivery_id = p_id) then
    raise exception 'Ce bon a des récupérations : son client ne peut plus être changé';
  end if;
  select coalesce(array_agg(command_item_id), '{}') into v_prev
    from public.command_delivery_items where delivery_id = p_id and command_item_id is not null;

  -- défaire : facture, quantités livrées, matières et productions automatiques
  v_sale := d.sale_id;
  perform public._release_sale_allocations(v_sale);
  update public.command_deliveries set sale_id = null where id = p_id;
  if v_sale is not null then delete from public.sales where id = v_sale; end if;
  delete from public.command_delivery_items where delivery_id = p_id;
  delete from public.command_delivery_consumptions where delivery_id = p_id;
  delete from public.productions where delivery_id = p_id;

  v_alloc := public._allocate_client_lines(v_client, p_payload->'lines', v_prev, d.command_id);
  if jsonb_array_length(v_alloc) = 0 then raise exception 'Saisissez au moins une quantité à livrer'; end if;
  select count(distinct x->>'command_id') into v_n from jsonb_array_elements(v_alloc) x;
  if v_n > 1 then
    raise exception 'Les quantités dépassent le reste d''une seule commande : enregistrez le surplus dans une nouvelle livraison';
  end if;
  v_cmd := (v_alloc->0->>'command_id')::uuid;
  select * into c from public.commands where id = v_cmd;

  v_tva := case when p_payload ? 'tva_enabled' then coalesce((p_payload->>'tva_enabled')::boolean, false) else d.tva_enabled end;
  v_at := coalesce(nullif(p_payload->>'delivered_at', '')::timestamptz, d.delivered_at);
  update public.command_deliveries set
    command_id = c.id, delivered_at = v_at, date = v_at::date,
    notes = coalesce(p_payload->>'notes', notes),
    driver_name = case when p_payload ? 'driver_name' then nullif(p_payload->>'driver_name', '') else driver_name end,
    driver_plate = case when p_payload ? 'driver_plate' then nullif(p_payload->>'driver_plate', '') else driver_plate end,
    location = case when p_payload ? 'location' then nullif(p_payload->>'location', '') else location end,
    tva_enabled = v_tva,
    tva_rate = case when v_tva
                    then coalesce((p_payload->>'tva_rate')::numeric, nullif(tva_rate, 0), nullif(c.tva_rate, 0), 19)
                    else 0 end
  where id = p_id;

  perform public._build_delivery(p_id, jsonb_build_object(
    'items', v_alloc,
    'advance_applied', case when coalesce((p_payload->>'use_advance')::boolean, true) then 999999999999 else 0 end,
    'cash_paid', greatest(0, coalesce((p_payload->>'cash_paid')::numeric, 0))));
  if v_old_cmd is distinct from c.id then perform public._recalc_command(v_old_cmd); end if;
  select * into d from public.command_deliveries where id = p_id;
  return to_jsonb(d);
end $$;

-- -----------------------------------------------------------------------------
--  9. RÉCUPÉRATION D'UN BON : la marchandise revient au stock prêt,
--     la facture baisse et l'argent payé en trop revient au client
-- -----------------------------------------------------------------------------
create or replace function public.trg_recovery_item()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_delivery uuid;
begin
  if tg_op <> 'INSERT' then perform public._recalc_item_delivered(old.command_item_id); end if;
  if tg_op <> 'DELETE' then perform public._recalc_item_delivered(new.command_item_id); end if;
  select delivery_id into v_delivery from public.delivery_recoveries
   where id = coalesce(new.recovery_id, old.recovery_id);
  if v_delivery is not null then perform public._sync_delivery_sale(v_delivery); end if;
  return coalesce(new, old);
end $$;
drop trigger if exists recovery_item_trg on public.delivery_recovery_items;
create trigger recovery_item_trg after insert or update or delete on public.delivery_recovery_items
  for each row execute function public.trg_recovery_item();

-- un remboursement annulé depuis la fiche client n'est plus rendu
create or replace function public.trg_delivery_recovery_before()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.refund_id is not null and new.refund_id is null then new.refund_amount := 0; end if;
  return new;
end $$;
drop trigger if exists delivery_recovery_before_trg on public.delivery_recoveries;
create trigger delivery_recovery_before_trg before update on public.delivery_recoveries
  for each row execute function public.trg_delivery_recovery_before();

-- l'argent libéré par la facture devient l'ACOMPTE du client (le remboursement
-- en espèces, s'il y en a un, le lui rend ensuite par une sortie de caisse)
create or replace function public.trg_delivery_recovery()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_old numeric := 0; v_new numeric := 0; v_client uuid;
begin
  if tg_op <> 'INSERT' then v_old := coalesce(old.excess_amount, 0); end if;
  if tg_op <> 'DELETE' then v_new := coalesce(new.excess_amount, 0); end if;
  v_client := case when tg_op = 'DELETE' then old.client_id else new.client_id end;
  if v_client is not null and abs(v_new - v_old) > 0.004 then
    update public.clients set credit_amount = credit_amount + (v_new - v_old) where id = v_client;
  end if;
  if tg_op = 'DELETE' then
    if old.refund_id is not null then
      delete from public.party_credit_refunds where id = old.refund_id;
    end if;
    perform public._sync_delivery_sale(old.delivery_id);
    return old;
  end if;
  perform public._sync_delivery_sale(new.delivery_id);
  return new;
end $$;
drop trigger if exists delivery_recovery_trg on public.delivery_recoveries;
create trigger delivery_recovery_trg after insert or update or delete on public.delivery_recoveries
  for each row execute function public.trg_delivery_recovery();

create or replace function public.create_delivery_recovery(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d public.command_deliveries; c public.commands; s public.sales; r public.delivery_recoveries;
        it jsonb; di record; v_q numeric; v_avail numeric; v_price numeric; v_fiche uuid; v_item uuid;
        v_ht numeric; v_tva numeric; v_ttc numeric; v_paid numeric; v_excess numeric := 0; v_refund numeric;
        v_at timestamptz; v_ref public.party_credit_refunds;
begin
  perform public.require_perm(array['clients:edit','sales:edit','clients:create']);
  select * into d from public.command_deliveries where id = nullif(p_payload->>'delivery_id', '')::uuid;
  if not found then raise exception 'Bon de livraison introuvable'; end if;
  select * into c from public.commands where id = d.command_id;
  v_at := coalesce(nullif(p_payload->>'recovered_at', '')::timestamptz, now());

  insert into public.delivery_recoveries (delivery_id, command_id, client_id, client_name, date, recovered_at,
    reason, tva_enabled, tva_rate, refund_method, is_historical)
  values (d.id, c.id, c.client_id, c.client_name, v_at::date, v_at, coalesce(p_payload->>'reason', ''),
    d.tva_enabled, d.tva_rate, coalesce(nullif(p_payload->>'refund_method', ''), 'especes'),
    coalesce(d.is_historical, false))
  returning * into r;

  for it in select * from jsonb_array_elements(coalesce(p_payload->'items', '[]'::jsonb)) loop
    v_q := round(coalesce((it->>'quantity')::numeric, 0), 3);
    continue when v_q <= 0;
    v_item := nullif(it->>'command_item_id', '')::uuid;
    select max(x.product_name) as product_name, max(x.sell_unit) as sell_unit, sum(x.quantity) as qty,
           (array_agg(x.fiche_technic_id))[1] as fiche, max(x.unit_cost) as unit_cost
      into di
      from public.command_delivery_items x
     where x.delivery_id = d.id and x.command_item_id = v_item;
    if di.qty is null then raise exception 'Ce produit ne figure pas sur le bon %', d.reference; end if;
    v_avail := di.qty - coalesce((select sum(ri.quantity) from public.delivery_recovery_items ri
                                    join public.delivery_recoveries rr on rr.id = ri.recovery_id
                                   where rr.delivery_id = d.id and ri.command_item_id = v_item), 0);
    if v_q > v_avail + 0.0005 then
      raise exception 'Quantité à récupérer de « % » supérieure à la quantité livrée restante (% au plus)',
        di.product_name, round(v_avail, 3);
    end if;
    v_price := coalesce(
      (select selling_price from public.sale_lines where sale_id = d.sale_id and command_item_id = v_item limit 1),
      (select unit_price from public.command_items where id = v_item), 0);
    v_fiche := coalesce(di.fiche, (select fiche_technic_id from public.command_items where id = v_item));
    insert into public.delivery_recovery_items (recovery_id, command_item_id, fiche_technic_id, product_name,
      quantity, unit_price, amount, unit, ready_applied, unit_cost, cost_amount)
    values (r.id, v_item, v_fiche, di.product_name, v_q, v_price, round(v_q * v_price, 2), di.sell_unit,
      v_fiche is not null and not coalesce(d.is_historical, false),
      coalesce(di.unit_cost, 0), round(v_q * coalesce(di.unit_cost, 0), 2));
  end loop;

  select coalesce(sum(amount), 0) into v_ht from public.delivery_recovery_items where recovery_id = r.id;
  if v_ht <= 0 and not exists (select 1 from public.delivery_recovery_items where recovery_id = r.id) then
    raise exception 'Saisissez au moins une quantité à récupérer';
  end if;
  v_tva := case when r.tva_enabled then round(v_ht * r.tva_rate) / 100 else 0 end;
  v_ttc := round(v_ht + v_tva, 2);

  -- la facture vient d'être ramenée à la marchandise gardée par le client :
  -- ce qu'il avait payé au-delà lui revient
  select * into s from public.sales where id = d.sale_id;
  if found then
    select coalesce(sum(amount), 0) into v_paid from public.sale_payments where sale_id = s.id;
    v_paid := v_paid - least(coalesce(s.refunded_amount, 0), v_paid);
    v_excess := greatest(0, round(v_paid - s.final_amount, 2));
  end if;
  if coalesce(d.is_historical, false) then v_excess := 0; end if;

  update public.delivery_recoveries set total_ht = round(v_ht, 2), tva_amount = v_tva, total_ttc = v_ttc,
    excess_amount = v_excess
  where id = r.id;

  v_refund := case when coalesce(p_payload->>'refund_mode', 'cash') = 'cash'
                   then least(v_excess, greatest(0, coalesce((p_payload->>'refund_amount')::numeric, v_excess)))
                   else 0 end;
  if v_refund > 0.004 and c.client_id is not null then
    insert into public.party_credit_refunds (party_type, party_id, party_name, amount, date, refunded_at, notes, method)
    values ('client', c.client_id, c.client_name, round(v_refund, 2), v_at::date, v_at,
            'Remboursement — récupération ' || r.reference || ' (BL ' || d.reference || ')', r.refund_method)
    returning * into v_ref;
    update public.delivery_recoveries set refund_id = v_ref.id, refund_amount = v_ref.amount where id = r.id;
  end if;

  select * into r from public.delivery_recoveries where id = r.id;
  return to_jsonb(r);
end $$;

-- -----------------------------------------------------------------------------
--  10. FACTURES NON COMPTABILISÉES (aucun effet sur les données)
-- -----------------------------------------------------------------------------
create or replace function public.save_free_invoice(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.free_invoices; l jsonb; v_pos int := 0; v_ht numeric; v_base numeric; v_tva numeric;
        v_final numeric; v_paid numeric; v_rate numeric; v_on boolean; v_red numeric; v_q numeric; v_p numeric;
begin
  if p_id is null then
    perform public.require_perm(array['sales:create','clients:create']);
    insert into public.free_invoices (client_name) values ('') returning * into v;
  else
    perform public.require_perm(array['sales:edit','clients:edit']);
    select * into v from public.free_invoices where id = p_id;
    if not found then raise exception 'Facture introuvable'; end if;
  end if;

  delete from public.free_invoice_lines where invoice_id = v.id;
  for l in select * from jsonb_array_elements(coalesce(p_payload->'lines', '[]'::jsonb)) loop
    v_q := coalesce((l->>'quantity')::numeric, 0);
    v_p := coalesce((l->>'unit_price')::numeric, 0);
    continue when coalesce(trim(l->>'product_name'), '') = '' and v_q = 0;
    insert into public.free_invoice_lines (invoice_id, position, fiche_technic_id, product_name, description,
      quantity, unit, unit_price, total_price)
    values (v.id, v_pos, nullif(l->>'fiche_technic_id', '')::uuid, coalesce(l->>'product_name', ''),
      coalesce(l->>'description', ''), v_q, nullif(l->>'unit', ''), v_p, round(v_q * v_p, 2));
    v_pos := v_pos + 1;
  end loop;

  select coalesce(sum(total_price), 0) into v_ht from public.free_invoice_lines where invoice_id = v.id;
  v_on := coalesce((p_payload->>'tva_enabled')::boolean, false);
  v_rate := case when v_on then coalesce((p_payload->>'tva_rate')::numeric, 19) else 0 end;
  v_red := greatest(0, coalesce((p_payload->>'reduction')::numeric, 0));
  v_base := greatest(0, round(v_ht, 2) - v_red);
  v_tva := case when v_on then round(v_base * v_rate) / 100 else 0 end;
  v_final := round(v_base + v_tva, 2);
  v_paid := least(greatest(0, coalesce((p_payload->>'paid_amount')::numeric, 0)), v_final);

  update public.free_invoices set
    doc_type = coalesce(nullif(p_payload->>'doc_type', ''), 'facture'),
    client_id = case when nullif(p_payload->>'client_id', '') is not null
                      and exists (select 1 from public.clients where id = (p_payload->>'client_id')::uuid)
                     then (p_payload->>'client_id')::uuid end,
    client_name = coalesce(p_payload->>'client_name', ''),
    client_phone = nullif(p_payload->>'client_phone', ''),
    client_address = nullif(p_payload->>'client_address', ''),
    client_rc = nullif(p_payload->>'client_rc', ''),
    client_nif = nullif(p_payload->>'client_nif', ''),
    client_nis = nullif(p_payload->>'client_nis', ''),
    client_article = nullif(p_payload->>'client_article', ''),
    date = coalesce(nullif(p_payload->>'date', '')::date, date),
    location = nullif(p_payload->>'location', ''),
    driver_name = nullif(p_payload->>'driver_name', ''),
    driver_plate = nullif(p_payload->>'driver_plate', ''),
    tva_enabled = v_on, tva_rate = v_rate, reduction = v_red,
    total_amount = round(v_ht, 2), tva_amount = v_tva, final_amount = v_final,
    paid_amount = v_paid, rest_amount = greatest(0, v_final - v_paid),
    payment_mode = nullif(p_payload->>'payment_mode', ''),
    notes = coalesce(p_payload->>'notes', '')
  where id = v.id
  returning * into v;
  return to_jsonb(v);
end $$;

-- -----------------------------------------------------------------------------
--  11. FICHE TECHNIQUE : image du produit
-- -----------------------------------------------------------------------------
create or replace function public._write_fiche(p_id uuid, p jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare u jsonb;
begin
  update public.fiche_technics set
    name = coalesce(p->>'name', name), category_id = nullif(p->>'category_id', '')::uuid,
    category_name = p->>'category_name', description = coalesce(p->>'description', ''),
    sell_by_unit = coalesce((p->>'sell_by_unit')::boolean, false), sell_unit = p->>'sell_unit',
    usable_in_production = coalesce((p->>'usable_in_production')::boolean, false), product_unit = p->>'product_unit',
    output_quantity = coalesce((p->>'output_quantity')::numeric, 1), unit_price = coalesce((p->>'unit_price')::numeric, 0),
    total_cost = coalesce((p->>'total_cost')::numeric, 0), cost_per_unit = coalesce((p->>'cost_per_unit')::numeric, 0),
    total_value = coalesce((p->>'total_value')::numeric, 0), gains_per_unit = coalesce((p->>'gains_per_unit')::numeric, 0),
    total_gains = coalesce((p->>'total_gains')::numeric, 0),
    image_url = case when p ? 'image_url' then nullif(p->>'image_url', '') else image_url end
  where id = p_id;
  delete from public.fiche_technic_lines where fiche_technic_id = p_id;
  for u in select * from jsonb_array_elements(coalesce(p->'used_products', '[]'::jsonb)) loop
    insert into public.fiche_technic_lines (fiche_technic_id, product_id, product_name, quantity_used,
      source_type, unit, unit_cost, line_cost)
    values (p_id, nullif(u->>'product_id', '')::uuid, coalesce(u->>'product_name', ''),
      coalesce((u->>'quantity_used')::numeric, 0), coalesce(u->>'source_type', 'stock'), u->>'unit',
      coalesce((u->>'unit_cost')::numeric, 0), coalesce((u->>'line_cost')::numeric, 0));
  end loop;
end $$;

-- Mettre au comptoir : jamais plus que le stock prêt (une partie a pu être livrée)
create or replace function public._transfer_to_comptoir(p_production_id uuid, p_quantity numeric)
returns public.comptoir_items language plpgsql security definer set search_path = public as $$
declare pr public.productions; v public.comptoir_items; v_ready numeric;
begin
  select * into pr from public.productions where id = p_production_id;
  if not found then raise exception 'Production introuvable'; end if;
  if p_quantity <= 0 then raise exception 'Quantité invalide'; end if;
  if pr.sent_to_comptoir + p_quantity > pr.output_quantity + 0.0005 then
    raise exception 'La quantité dépasse le reste en stock de production';
  end if;
  if pr.fiche_technic_id is not null and pr.origin <> 'pos' then
    v_ready := public.fiche_ready_quantity(pr.fiche_technic_id);
    if p_quantity > v_ready + 0.0005 then
      raise exception 'Stock prêt insuffisant : une partie de ce produit a déjà été livrée (prêt : %)', greatest(0, v_ready);
    end if;
  end if;
  insert into public.comptoir_items (production_id, product_name, description, quantity, initial_quantity,
    unit_price, date, category_id, category_name, sell_by_unit, unit)
  values (pr.id, pr.name, pr.description, p_quantity, p_quantity, pr.unit_price, current_date,
    pr.category_id, pr.category_name, pr.sell_by_unit, pr.sell_unit)
  returning * into v;
  return v;
end $$;

-- -----------------------------------------------------------------------------
--  12. CORBEILLE, SÉCURITÉ, DROITS
-- -----------------------------------------------------------------------------
create or replace function public._table_module(p_table text)
returns text language sql immutable as $$
  select case
    when p_table in ('products','marques','categories','units') then 'stock'
    when p_table in ('purchases','purchase_lines','purchase_payments') then 'purchase'
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
  foreach t in array array['delivery_recoveries','delivery_recovery_items','free_invoices','free_invoice_lines'] loop
    execute format('drop trigger if exists zz_recycle on public.%I', t);
    execute format('create trigger zz_recycle after delete on public.%I for each row execute function public.trg_recycle_capture()', t);
  end loop;
end $$;

do $$
declare rec record; r text[]; w text[];
begin
  for rec in
    select * from (values
      ('delivery_recoveries',     '{clients,sales,pos,caisse,production,stock,dashboard,reports}', '{clients,sales}'),
      ('delivery_recovery_items', '{clients,sales,pos,caisse,production,stock,dashboard,reports}', '{clients,sales}'),
      ('free_invoices',           '{sales,clients,pos,dashboard,reports}', '{sales,clients}'),
      ('free_invoice_lines',      '{sales,clients,pos,dashboard,reports}', '{sales,clients}')
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

-- les fonctions internes (_…) et de déclencheur (trg_…) restent hors de l'API
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
grant execute on function public.fiche_ready_quantity(uuid) to authenticated;

-- -----------------------------------------------------------------------------
--  13. FACULTATIF — rattacher les productions manuelles EXISTANTES à leur fiche
-- -----------------------------------------------------------------------------
--  Les productions lancées AVANT cette mise à jour ne sont reliées à aucune
--  fiche technique : elles ne comptent donc pas dans le « stock prêt ». Si leur
--  reste (quantité produite − envoyé au comptoir) est réellement en attente de
--  livraison, retirez les deux tirets devant les lignes ci-dessous puis
--  relancez ce bloc. Sinon, laissez-le tel quel.
--
-- update public.productions p set fiche_technic_id = f.id
--   from public.fiche_technics f
--  where p.fiche_technic_id is null and p.origin = 'manual'
--    and lower(trim(p.name)) = lower(trim(f.name))
--    and (select count(*) from public.fiche_technics f2 where lower(trim(f2.name)) = lower(trim(f.name))) = 1;

notify pgrst, 'reload schema';
