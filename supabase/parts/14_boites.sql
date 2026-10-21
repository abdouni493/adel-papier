-- =============================================================================
--  MISE À JOUR 2026-10-22 — BOÎTES (EMBALLAGES) DES PRODUITS FINIS
-- -----------------------------------------------------------------------------
--  À exécuter UNE fois sur une base existante (SQL editor → Run), APRÈS la
--  partie 13. Le script peut être relancé sans risque. Il est aussi ajouté à la
--  fin de papeterie_supabase_full.sql.
--
--  · Un produit du stock peut être marqué « boîte » (products.is_box).
--  · Toute production (manuelle, caisse, livraison) peut être mise en boîte :
--    la boîte choisie et sa quantité sont rattachées à la production, ajoutées
--    à ses matières (ligne is_box) et DÉDUITES DU STOCK automatiquement.
--  · Le STOCK PRÊT d'un produit est suivi PAR BOÎTE (une « variante » = un
--    produit fini dans une boîte donnée, ou sans boîte). Une livraison et une
--    vente de caisse indiquent dans quelle variante elles prennent le stock
--    prêt ; le manquant est produit dans la boîte choisie.
--
--  Le stock prêt TOTAL d'un produit (fiche_ready_quantity) ne change pas : il
--  reste la somme de ses variantes.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  1. COLONNES
-- -----------------------------------------------------------------------------
alter table public.products add column if not exists is_box boolean not null default false;
create index if not exists products_is_box_idx on public.products (is_box) where is_box;

alter table public.productions add column if not exists box_product_id uuid;
alter table public.productions add column if not exists box_product_name text;
alter table public.productions add column if not exists box_quantity numeric(14,3) not null default 0;
do $$ begin
  alter table public.productions add constraint productions_box_fk
    foreign key (box_product_id) references public.products(id) on delete set null;
exception when duplicate_object then null; end $$;
create index if not exists productions_fiche_box_idx on public.productions (fiche_technic_id, box_product_id);

-- la ligne « boîte » parmi les matières d'une production
alter table public.production_used_products add column if not exists is_box boolean not null default false;

-- variante (boîte) du stock prêt prise par une livraison :
--   ready_box_product_id    → la part `from_ready`
--   produced_box_product_id → la part produite (quantity − from_ready)
alter table public.command_delivery_items add column if not exists ready_box_product_id uuid;
alter table public.command_delivery_items add column if not exists produced_box_product_id uuid;
-- variante dans laquelle une récupération rend la marchandise
alter table public.delivery_recovery_items add column if not exists box_product_id uuid;
-- variante du stock prêt prise par une vente de caisse (part `from_ready`)
alter table public.sale_lines add column if not exists ready_box_product_id uuid;

-- -----------------------------------------------------------------------------
--  2. STOCK PRÊT PAR BOÎTE
-- -----------------------------------------------------------------------------
create or replace function public.fiche_ready_box_quantity(p_fiche uuid, p_box uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select round(
      coalesce((select sum(output_quantity) from public.productions
                 where fiche_technic_id = p_fiche and origin <> 'pos'
                   and box_product_id is not distinct from p_box), 0)
    - coalesce((select sum(greatest(0, ci.initial_quantity - ci.quantity)) from public.comptoir_items ci
                  join public.productions pr on pr.id = ci.production_id
                 where pr.fiche_technic_id = p_fiche and pr.origin <> 'pos'
                   and pr.box_product_id is not distinct from p_box), 0)
    - coalesce((select sum(from_ready) from public.command_delivery_items
                 where fiche_technic_id = p_fiche and ready_applied
                   and ready_box_product_id is not distinct from p_box), 0)
    - coalesce((select sum(quantity - from_ready) from public.command_delivery_items
                 where fiche_technic_id = p_fiche and ready_applied
                   and produced_box_product_id is not distinct from p_box), 0)
    + coalesce((select sum(ri.quantity) from public.delivery_recovery_items ri
                 where ri.fiche_technic_id = p_fiche and ri.ready_applied
                   and ri.box_product_id is not distinct from p_box), 0)
    - coalesce((select sum(sl.from_ready) from public.sale_lines sl
                  join public.sales s on s.id = sl.sale_id
                 where sl.fiche_technic_id = p_fiche and sl.from_ready > 0
                   and sl.ready_box_product_id is not distinct from p_box
                   and not coalesce(s.is_historical, false)), 0), 3)
$$;

-- Variante qui a le plus de stock prêt (choix par défaut quand l'écran n'en
-- précise aucune).
create or replace function public._best_ready_box(p_fiche uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select b.box from (
    select distinct box_product_id as box from public.productions
     where fiche_technic_id = p_fiche and origin <> 'pos'
  ) b
  order by public.fiche_ready_box_quantity(p_fiche, b.box) desc, (b.box is null) desc
  limit 1
$$;

-- Comptoir encore disponible (non vendu) d'une variante.
create or replace function public._fiche_box_on_comptoir(p_fiche uuid, p_box uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(sum(greatest(0, ci.quantity)), 0) from public.comptoir_items ci
    join public.productions pr on pr.id = ci.production_id
   where pr.fiche_technic_id = p_fiche and pr.origin <> 'pos'
     and pr.box_product_id is not distinct from p_box
$$;

-- -----------------------------------------------------------------------------
--  3. PRODUCTION : la boîte choisie sort du stock avec les matières
-- -----------------------------------------------------------------------------
create or replace function public._create_production(p jsonb)
returns public.productions language plpgsql security definer set search_path = public as $$
declare v public.productions; u jsonb; v_cost numeric := 0; v_fiche uuid;
        v_box uuid; v_box_qty numeric; bx public.products;
begin
  v_fiche := nullif(p->>'fiche_technic_id', '')::uuid;
  if v_fiche is not null and not exists (select 1 from public.fiche_technics where id = v_fiche) then v_fiche := null; end if;
  select coalesce(sum(coalesce((x->>'line_cost')::numeric, 0)), 0) into v_cost
    from jsonb_array_elements(coalesce(p->'used_products', '[]'::jsonb)) x;

  -- boîte (emballage) de la production
  v_box := nullif(p->>'box_product_id', '')::uuid;
  v_box_qty := round(greatest(0, coalesce((p->>'box_quantity')::numeric, 0)), 3);
  if v_box is not null then
    select * into bx from public.products where id = v_box for update;
    if not found then
      v_box := null; v_box_qty := 0;
    elsif v_box_qty > bx.current_quantity + 0.0005 then
      raise exception 'Stock insuffisant pour la boîte « % » : % disponible(s), % demandée(s)',
        bx.name, bx.current_quantity, v_box_qty;
    end if;
  else
    v_box_qty := 0;
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
    round(v_cost, 2), coalesce((p->>'output_quantity')::numeric, 0), coalesce((p->>'unit_price')::numeric, 0),
    round(coalesce((p->>'output_quantity')::numeric, 0) * coalesce((p->>'unit_price')::numeric, 0), 2),
    coalesce((p->>'sell_by_unit')::boolean, false), p->>'sell_unit',
    coalesce((p->>'has_loss')::boolean, false), (p->>'expected_quantity')::numeric,
    coalesce((p->>'loss_quantity')::numeric, 0), p->>'loss_description', coalesce((p->>'loss_value')::numeric, 0),
    case when p->>'origin' = 'pos' then 'pos' else 'manual' end,
    nullif(p->>'sale_id', '')::uuid, p->>'sale_reference', p->>'line_key',
    v_box, bx.name, v_box_qty)
  returning * into v;
  for u in select * from jsonb_array_elements(coalesce(p->'used_products', '[]'::jsonb)) loop
    -- la boîte est ajoutée ci-dessous : jamais deux fois
    continue when coalesce((u->>'is_box')::boolean, false);
    insert into public.production_used_products (production_id, product_id, product_name, quantity_used,
      source_type, unit, unit_cost, line_cost)
    values (v.id, nullif(u->>'product_id', '')::uuid, coalesce(u->>'product_name', ''),
      coalesce((u->>'quantity_used')::numeric, 0), coalesce(u->>'source_type', 'stock'), u->>'unit',
      coalesce((u->>'unit_cost')::numeric, 0), coalesce((u->>'line_cost')::numeric, 0));
  end loop;
  if v_box is not null and v_box_qty > 0 then
    -- le déclencheur production_used_trg déduit la boîte du stock
    insert into public.production_used_products (production_id, product_id, product_name, quantity_used,
      source_type, unit, unit_cost, line_cost, is_box)
    values (v.id, v_box, bx.name, v_box_qty, 'stock', bx.unit,
      coalesce(bx.purchase_price, 0), round(v_box_qty * coalesce(bx.purchase_price, 0), 2), true);
  end if;
  return v;
end $$;

-- Production automatique du manquant d'une livraison, dans la boîte choisie.
drop function if exists public._auto_produce(uuid, numeric, uuid, date, text);
create or replace function public._auto_produce(p_fiche uuid, p_qty numeric, p_delivery uuid, p_date date,
  p_label text, p_box uuid default null, p_box_qty numeric default 0)
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
    'box_product_id', p_box, 'box_quantity', coalesce(p_box_qty, 0)));
  update public.productions set origin = 'delivery', delivery_id = p_delivery where id = v.id returning * into v;
  return v;
end $$;

-- -----------------------------------------------------------------------------
--  4. METTRE AU COMPTOIR : contrôle par variante (boîte)
-- -----------------------------------------------------------------------------
create or replace function public._transfer_to_comptoir(p_production_id uuid, p_quantity numeric)
returns public.comptoir_items language plpgsql security definer set search_path = public as $$
declare pr public.productions; v public.comptoir_items; v_free numeric;
begin
  select * into pr from public.productions where id = p_production_id;
  if not found then raise exception 'Production introuvable'; end if;
  if p_quantity <= 0 then raise exception 'Quantité invalide'; end if;
  if pr.sent_to_comptoir + p_quantity > pr.output_quantity + 0.0005 then
    raise exception 'La quantité dépasse le reste en stock de production';
  end if;
  if pr.fiche_technic_id is not null and pr.origin <> 'pos' then
    v_free := public.fiche_ready_box_quantity(pr.fiche_technic_id, pr.box_product_id)
            - public._fiche_box_on_comptoir(pr.fiche_technic_id, pr.box_product_id);
    if p_quantity > v_free + 0.0005 then
      raise exception 'Stock prêt insuffisant : une partie de ce produit a déjà été livrée ou vendue (disponible : %)', greatest(0, v_free);
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
--  5. CAISSE : variante choisie du stock prêt + boîte du manquant produit
--     productions[] : { line_key, fiche_technic_id, output_quantity, …,
--                       ready_box_product_id (variante, '' = sans boîte),
--                       box_product_id, box_quantity }
-- -----------------------------------------------------------------------------
create or replace function public._insert_sale_lines(p_sale uuid, p_lines jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare l jsonb; v_prod uuid; v_comp uuid; v_fiche uuid; v_pr uuid; v_ci uuid;
begin
  for l in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_prod := nullif(l->>'product_id', '')::uuid;
    v_comp := nullif(l->>'comptoir_id', '')::uuid;
    v_fiche := nullif(l->>'fiche_technic_id', '')::uuid;
    v_pr := nullif(l->>'production_id', '')::uuid;
    v_ci := nullif(l->>'command_item_id', '')::uuid;
    if v_prod is not null and not exists (select 1 from public.products where id = v_prod) then v_prod := null; end if;
    if v_comp is not null and not exists (select 1 from public.comptoir_items where id = v_comp) then v_comp := null; end if;
    if v_fiche is not null and not exists (select 1 from public.fiche_technics where id = v_fiche) then v_fiche := null; end if;
    if v_pr is not null and not exists (select 1 from public.productions where id = v_pr) then v_pr := null; end if;
    insert into public.sale_lines (sale_id, product_id, comptoir_id, fiche_technic_id, production_id, command_item_id,
      line_key, product_name, quantity, selling_price, base_price, sell_by_unit, unit, from_ready, ready_box_product_id)
    values (p_sale, v_prod, v_comp, v_fiche, v_pr, v_ci, l->>'line_key', coalesce(l->>'product_name', ''),
      coalesce((l->>'quantity')::numeric, 0), coalesce((l->>'selling_price')::numeric, 0),
      (l->>'base_price')::numeric, coalesce((l->>'sell_by_unit')::boolean, false), l->>'unit',
      coalesce((l->>'from_ready')::numeric, 0), nullif(l->>'ready_box_product_id', '')::uuid);
  end loop;
end $$;

create or replace function public.create_sale_with_productions(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare pr jsonb; v_prod public.productions; v_item public.comptoir_items; v_map jsonb := '{}'::jsonb;
        v_lines jsonb := '[]'::jsonb; l jsonb; v_sale public.sales; v_key text; v_fiche uuid;
        v_qty numeric; v_ready numeric; v_from numeric; v_missing numeric; v_used jsonb := '{}'::jsonb;
        v_rbox uuid; v_vkey text; v_entry jsonb;
begin
  perform public.require_perm(array['pos:create','sales:create']);
  if not coalesce((p_payload->>'is_historical')::boolean, false) then
    for pr in select * from jsonb_array_elements(coalesce(p_payload->'productions', '[]'::jsonb)) loop
      v_key := pr->>'line_key';
      v_fiche := nullif(pr->>'fiche_technic_id', '')::uuid;
      v_qty := round(coalesce((pr->>'output_quantity')::numeric, 0), 3);
      v_from := 0; v_rbox := null;
      if v_fiche is not null then
        -- variante choisie à la caisse, sinon celle qui a le plus de stock prêt
        if pr ? 'ready_box_product_id' then
          v_rbox := nullif(pr->>'ready_box_product_id', '')::uuid;
        else
          v_rbox := public._best_ready_box(v_fiche);
        end if;
        v_vkey := v_fiche::text || ':' || coalesce(v_rbox::text, '');
        -- deux lignes de la même variante se partagent le même stock prêt
        v_ready := greatest(0, public.fiche_ready_box_quantity(v_fiche, v_rbox)
                               - coalesce((v_used->>v_vkey)::numeric, 0));
        v_from := round(least(v_qty, v_ready), 3);
        v_used := v_used || jsonb_build_object(v_vkey, coalesce((v_used->>v_vkey)::numeric, 0) + v_from);
      end if;
      v_missing := round(v_qty - v_from, 3);
      v_entry := jsonb_build_object('from_ready', v_from, 'ready_box_product_id', v_rbox);
      if v_missing > 0.0005 then
        v_prod := public._create_production(public._scale_production_payload(pr, v_missing)
                    || jsonb_build_object('date', p_payload->>'date', 'origin', 'pos'));
        if v_prod.output_quantity > 0 then
          v_item := public._transfer_to_comptoir(v_prod.id, v_prod.output_quantity);
          v_entry := v_entry || jsonb_build_object('comptoir_id', v_item.id, 'production_id', v_prod.id);
        end if;
      end if;
      v_map := v_map || jsonb_build_object(v_key, v_entry);
    end loop;
  end if;
  for l in select * from jsonb_array_elements(coalesce(p_payload->'products', '[]'::jsonb)) loop
    v_key := l->>'line_key';
    if v_key is not null and v_map ? v_key then
      l := l || jsonb_build_object(
        'comptoir_id', v_map->v_key->>'comptoir_id',
        'production_id', v_map->v_key->>'production_id',
        'from_ready', coalesce((v_map->v_key->>'from_ready')::numeric, 0),
        'ready_box_product_id', v_map->v_key->>'ready_box_product_id',
        'product_id', null);
    end if;
    v_lines := v_lines || jsonb_build_array(l);
  end loop;
  v_sale := public._create_sale(p_payload || jsonb_build_object('products', v_lines));
  update public.productions set sale_id = v_sale.id, sale_reference = v_sale.reference
  where id in (select (value->>'production_id')::uuid from jsonb_each(v_map) where value ? 'production_id');
  return to_jsonb(v_sale);
end $$;

-- -----------------------------------------------------------------------------
--  6. BON DE LIVRAISON : variante du stock prêt + boîte du manquant produit
--     Les choix de l'écran arrivent dans `boxes` (voir les fonctions *_boxes
--     plus bas) : { "<fiche_id>": { ready_box_product_id, box_product_id,
--     box_quantity } }. La quantité de boîtes est consommée par la PREMIÈRE
--     production automatique du produit dans l'opération.
-- -----------------------------------------------------------------------------
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
        v_bqty := coalesce((v_opt->>'box_quantity')::numeric, 0);
        v_prod := public._auto_produce(ci.fiche_technic_id, v_produced, p_id, d.date, 'BL ' || d.reference,
                                       v_pbox, v_bqty);
        v_pbox := v_prod.box_product_id;
        if v_bqty > 0 then
          -- les boîtes saisies ne sont consommées qu'une fois
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

-- Écran Livraisons : mêmes fonctions qu'avant, avec les choix de boîtes.
create or replace function public.create_client_delivery_boxes(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.delivery_boxes', coalesce(p_payload->'boxes', '{}'::jsonb)::text, true);
  return public.create_client_delivery(p_payload - 'boxes');
end $$;

create or replace function public.update_client_delivery_boxes(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.delivery_boxes', coalesce(p_payload->'boxes', '{}'::jsonb)::text, true);
  return public.update_client_delivery(p_id, p_payload - 'boxes');
end $$;

-- -----------------------------------------------------------------------------
--  7. RÉCUPÉRATION : la marchandise revient dans la variante livrée
--     (la boîte de la part produite si le bon en a produit, sinon celle du
--     stock prêt)
-- -----------------------------------------------------------------------------
create or replace function public.trg_recovery_item_box()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.box_product_id is null then
    select case when di.quantity - di.from_ready > 0.0005 then di.produced_box_product_id
                else di.ready_box_product_id end
      into new.box_product_id
      from public.delivery_recoveries r
      join public.command_delivery_items di on di.delivery_id = r.delivery_id
     where r.id = new.recovery_id and di.command_item_id is not distinct from new.command_item_id
     limit 1;
  end if;
  return new;
end $$;
drop trigger if exists recovery_item_box_trg on public.delivery_recovery_items;
create trigger recovery_item_box_trg before insert on public.delivery_recovery_items
  for each row execute function public.trg_recovery_item_box();

-- -----------------------------------------------------------------------------
--  8. DROITS
-- -----------------------------------------------------------------------------
grant execute on function public.fiche_ready_box_quantity(uuid, uuid) to authenticated;
grant execute on function public.create_client_delivery_boxes(jsonb) to authenticated;
grant execute on function public.update_client_delivery_boxes(uuid, jsonb) to authenticated;
-- fonctions internes (préfixe _ / trg_) : jamais appelables depuis l'API
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
