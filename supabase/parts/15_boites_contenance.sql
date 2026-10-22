-- =============================================================================
--  MISE À JOUR 2026-10-23 — CONTENANCE DES BOÎTES & CORRECTION DU STOCK
-- -----------------------------------------------------------------------------
--  À exécuter UNE fois sur une base existante (SQL editor → Run), APRÈS la
--  partie 14. Le script peut être relancé sans risque. Il est aussi ajouté à la
--  fin de papeterie_supabase_full.sql.
--
--  · CONTENANCE : pour chaque produit fini (fiche technique) et chaque boîte,
--    on mémorise combien d'unités du produit la boîte contient
--    (box_capacities). Elle est saisie / modifiée dans la fenêtre « Boîtes »
--    et proposée à l'opération suivante.
--  · NOMBRE DE BOÎTES AUTOMATIQUE : quantité produite ÷ contenance, arrondi au
--    supérieur, quand l'écran n'envoie pas de nombre.
--  · CORRECTION : modifier un bon de livraison (ou sa commande) défait ses
--    productions automatiques — les boîtes revenaient au stock et n'en
--    ressortaient plus, le stock de boîtes AUGMENTAIT. La boîte du bon est
--    maintenant reprise à la reconstruction et redéduite du stock.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  1. CONTENANCE PAR PRODUIT ET PAR BOÎTE
-- -----------------------------------------------------------------------------
create table if not exists public.box_capacities (
  fiche_technic_id uuid not null references public.fiche_technics(id) on delete cascade,
  box_product_id   uuid not null references public.products(id) on delete cascade,
  capacity         numeric(14,3) not null check (capacity > 0),
  updated_at       timestamptz not null default now(),
  primary key (fiche_technic_id, box_product_id)
);
alter table public.box_capacities enable row level security;
drop policy if exists p_select on public.box_capacities;
create policy p_select on public.box_capacities for select to authenticated
  using (public.can_view_any('{production,pos,comptoir,stock,sales,clients,dashboard,reports}'::text[]));
-- écriture : uniquement par les fonctions ci-dessous

create or replace function public._box_capacity(p_fiche uuid, p_box uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select capacity from public.box_capacities where fiche_technic_id = p_fiche and box_product_id = p_box
$$;

create or replace function public._save_box_capacity(p_fiche uuid, p_box uuid, p_capacity numeric)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_fiche is null or p_box is null or coalesce(p_capacity, 0) <= 0 then return; end if;
  insert into public.box_capacities (fiche_technic_id, box_product_id, capacity, updated_at)
  values (p_fiche, p_box, round(p_capacity, 3), now())
  on conflict (fiche_technic_id, box_product_id)
  do update set capacity = excluded.capacity, updated_at = now();
end $$;

-- -----------------------------------------------------------------------------
--  2. PRODUCTION : contenance mémorisée, nombre de boîtes calculé si absent
--     payload : box_product_id, box_quantity (null / absent = automatique),
--               box_capacity (contenance saisie, mémorisée)
-- -----------------------------------------------------------------------------
create or replace function public._create_production(p jsonb)
returns public.productions language plpgsql security definer set search_path = public as $$
declare v public.productions; u jsonb; v_cost numeric := 0; v_fiche uuid;
        v_box uuid; v_box_qty numeric; v_cap numeric; v_out numeric; bx public.products;
begin
  v_fiche := nullif(p->>'fiche_technic_id', '')::uuid;
  if v_fiche is not null and not exists (select 1 from public.fiche_technics where id = v_fiche) then v_fiche := null; end if;
  select coalesce(sum(coalesce((x->>'line_cost')::numeric, 0)), 0) into v_cost
    from jsonb_array_elements(coalesce(p->'used_products', '[]'::jsonb)) x;
  v_out := coalesce((p->>'output_quantity')::numeric, 0);

  -- boîte (emballage) de la production
  v_box := nullif(p->>'box_product_id', '')::uuid;
  v_box_qty := nullif(p->>'box_quantity', '')::numeric;
  if v_box is not null then
    select * into bx from public.products where id = v_box for update;
    if not found then
      v_box := null;
    else
      v_cap := nullif(p->>'box_capacity', '')::numeric;
      if coalesce(v_cap, 0) > 0 then
        perform public._save_box_capacity(v_fiche, v_box, v_cap);
      else
        v_cap := public._box_capacity(v_fiche, v_box);
      end if;
      -- nombre de boîtes non précisé : quantité ÷ contenance, arrondi au supérieur
      if v_box_qty is null then
        v_box_qty := case when coalesce(v_cap, 0) > 0 and v_out > 0 then ceil(v_out / v_cap - 0.0000001) else 0 end;
      end if;
    end if;
  end if;
  v_box_qty := round(greatest(0, abs(coalesce(v_box_qty, 0))), 3);
  if v_box is null then v_box_qty := 0; end if;
  if v_box is not null and v_box_qty > bx.current_quantity + 0.0005 then
    raise exception 'Stock insuffisant pour la boîte « % » : % disponible(s), % demandée(s)',
      bx.name, bx.current_quantity, v_box_qty;
  end if;
  if v_box is not null then v_cost := v_cost + round(v_box_qty * coalesce(bx.purchase_price, 0), 2); end if;

  insert into public.productions (name, description, date, hour, fiche_technic_id, category_id, category_name,
    total_cost, output_quantity, unit_price, total_value, sell_by_unit, sell_unit,
    has_loss, expected_quantity, loss_quantity, loss_description, loss_value, origin,
    sale_id, sale_reference, line_key, box_product_id, box_product_name, box_quantity)
  values (coalesce(p->>'name', 'Production'), coalesce(p->>'description', ''),
    coalesce(nullif(p->>'date', '')::date, current_date),
    coalesce(p->>'hour', to_char(now() at time zone 'Africa/Algiers', 'HH24:MI')),
    v_fiche, nullif(p->>'category_id', '')::uuid, p->>'category_name',
    round(v_cost, 2), v_out, coalesce((p->>'unit_price')::numeric, 0),
    round(v_out * coalesce((p->>'unit_price')::numeric, 0), 2),
    coalesce((p->>'sell_by_unit')::boolean, false), p->>'sell_unit',
    coalesce((p->>'has_loss')::boolean, false), (p->>'expected_quantity')::numeric,
    coalesce((p->>'loss_quantity')::numeric, 0), p->>'loss_description', coalesce((p->>'loss_value')::numeric, 0),
    case when p->>'origin' = 'pos' then 'pos' else 'manual' end,
    nullif(p->>'sale_id', '')::uuid, p->>'sale_reference', p->>'line_key',
    v_box, case when v_box is not null then bx.name end, v_box_qty)
  returning * into v;
  for u in select * from jsonb_array_elements(coalesce(p->'used_products', '[]'::jsonb)) loop
    -- la boîte est ajoutée ci-dessous : jamais deux fois
    continue when coalesce((u->>'is_box')::boolean, false);
    continue when v_box is not null and nullif(u->>'product_id', '')::uuid = v_box;
    insert into public.production_used_products (production_id, product_id, product_name, quantity_used,
      source_type, unit, unit_cost, line_cost)
    values (v.id, nullif(u->>'product_id', '')::uuid, coalesce(u->>'product_name', ''),
      coalesce((u->>'quantity_used')::numeric, 0), coalesce(u->>'source_type', 'stock'), u->>'unit',
      coalesce((u->>'unit_cost')::numeric, 0), coalesce((u->>'line_cost')::numeric, 0));
  end loop;
  if v_box is not null and v_box_qty > 0 then
    -- le déclencheur production_used_trg DÉDUIT la boîte du stock
    insert into public.production_used_products (production_id, product_id, product_name, quantity_used,
      source_type, unit, unit_cost, line_cost, is_box)
    values (v.id, v_box, bx.name, v_box_qty, 'stock', bx.unit,
      coalesce(bx.purchase_price, 0), round(v_box_qty * coalesce(bx.purchase_price, 0), 2), true);
  end if;
  return v;
end $$;

-- Production automatique du manquant d'une livraison : nombre de boîtes
-- transmis tel quel (null = automatique d'après la contenance).
create or replace function public._auto_produce(p_fiche uuid, p_qty numeric, p_delivery uuid, p_date date,
  p_label text, p_box uuid default null, p_box_qty numeric default null)
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
    'used_products', v_lines,
    'box_product_id', p_box, 'box_quantity', p_box_qty));
  update public.productions set origin = 'delivery', delivery_id = p_delivery where id = v.id returning * into v;
  return v;
end $$;

-- -----------------------------------------------------------------------------
--  3. BON DE LIVRAISON : la boîte d'un bon reconstruit n'est plus perdue
--     Quand un bon est modifié, ses productions automatiques sont supprimées
--     (les boîtes reviennent au stock). Leur boîte est notée ici, pour la
--     transaction en cours, et réutilisée à la reconstruction si l'écran n'en
--     donne pas d'autre : les boîtes ressortent du stock.
-- -----------------------------------------------------------------------------
create or replace function public.trg_production_keep_box()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_boxes jsonb; v_key text; v_cap numeric;
begin
  if old.delivery_id is not null and old.box_product_id is not null and old.fiche_technic_id is not null then
    v_boxes := coalesce(nullif(current_setting('app.delivery_boxes', true), '')::jsonb, '{}'::jsonb);
    v_key := old.fiche_technic_id::text;
    if not v_boxes ? v_key then
      v_cap := public._box_capacity(old.fiche_technic_id, old.box_product_id);
      v_boxes := v_boxes || jsonb_build_object(v_key, jsonb_build_object(
        'box_product_id', old.box_product_id,
        -- contenance connue : recalculée sur la nouvelle quantité, sinon même nombre
        'box_quantity', case when coalesce(v_cap, 0) > 0 then null else old.box_quantity end));
      perform set_config('app.delivery_boxes', v_boxes::text, true);
    end if;
  end if;
  return old;
end $$;
drop trigger if exists production_keep_box_trg on public.productions;
create trigger production_keep_box_trg before delete on public.productions
  for each row execute function public.trg_production_keep_box();

create or replace function public._build_delivery(p_id uuid, p jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare d public.command_deliveries; c public.commands; it record; ci public.command_items; rv record;
        v_qty numeric; v_lines jsonb := '[]'::jsonb; v_sale public.sales; pay record;
        v_adv_avail numeric; v_adv numeric; v_cash numeric; v_over numeric;
        v_ready numeric; v_from_ready numeric; v_produced numeric; v_cost numeric; v_live boolean;
        v_boxes jsonb; v_opt jsonb; v_rbox uuid; v_pbox uuid; v_bqty numeric; v_prod public.productions;
begin
  select * into d from public.command_deliveries where id = p_id;
  select * into c from public.commands where id = d.command_id;
  v_live := not coalesce(d.is_historical, false);
  v_boxes := coalesce(p->'boxes', nullif(current_setting('app.delivery_boxes', true), '')::jsonb, '{}'::jsonb);

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

    -- le produit fini sort du STOCK PRÊT (variante choisie) ; le manquant est
    -- produit maintenant, dans la boîte choisie
    v_from_ready := 0; v_produced := 0; v_cost := 0; v_rbox := null; v_pbox := null;
    if ci.fiche_technic_id is not null and v_live then
      v_opt := v_boxes->(ci.fiche_technic_id::text);
      if v_opt is not null and v_opt ? 'ready_box_product_id' then
        v_rbox := nullif(v_opt->>'ready_box_product_id', '')::uuid;
      else
        v_rbox := public._best_ready_box(ci.fiche_technic_id);
      end if;
      v_ready := greatest(0, public.fiche_ready_box_quantity(ci.fiche_technic_id, v_rbox));
      v_from_ready := least(v_qty, v_ready);
      v_produced := round(v_qty - v_from_ready, 3);
      if v_produced > 0.0005 then
        v_pbox := nullif(v_opt->>'box_product_id', '')::uuid;
        -- null = automatique (contenance)
        v_bqty := nullif(v_opt->>'box_quantity', '')::numeric;
        v_prod := public._auto_produce(ci.fiche_technic_id, v_produced, p_id, d.date, 'BL ' || d.reference,
                                       v_pbox, v_bqty);
        v_pbox := v_prod.box_product_id;
        if v_bqty is not null and v_bqty > 0 then
          -- un nombre saisi n'est consommé qu'une fois
          v_boxes := jsonb_set(v_boxes, array[ci.fiche_technic_id::text, 'box_quantity'], '0'::jsonb);
          perform set_config('app.delivery_boxes', v_boxes::text, true);
        end if;
      else
        v_produced := 0;
      end if;
      v_cost := public._fiche_unit_cost(ci.fiche_technic_id);
    end if;

    insert into public.command_delivery_items (delivery_id, command_item_id, product_name, quantity, sell_unit,
      fiche_technic_id, ready_applied, from_ready, produced_quantity, unit_cost, cost_amount,
      ready_box_product_id, produced_box_product_id)
    values (p_id, ci.id, coalesce(nullif(it.product_name, ''), ci.product_name, ''), v_qty,
      coalesce(it.sell_unit, ci.sell_unit), ci.fiche_technic_id,
      ci.fiche_technic_id is not null and v_live, v_from_ready, v_produced,
      round(coalesce(v_cost, 0), 4), round(coalesce(v_cost, 0) * v_qty, 2),
      v_rbox, v_pbox);

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

-- -----------------------------------------------------------------------------
--  4. DROITS
-- -----------------------------------------------------------------------------
grant select on public.box_capacities to authenticated;
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

notify pgrst, 'reload schema';
