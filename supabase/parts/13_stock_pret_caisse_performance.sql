-- =============================================================================
--  MISE À JOUR 2026-10-21 — STOCK PRÊT UNIQUE (production → comptoir → caisse
--  → livraison) + PERFORMANCE
-- -----------------------------------------------------------------------------
--  À exécuter UNE fois sur une base existante (SQL editor → Run). Le script peut
--  être relancé sans risque. Il est aussi ajouté à la fin de
--  papeterie_supabase_full.sql.
--
--  STOCK PRÊT d'un produit (fiche technique) =
--      productions du produit (hors caisse)
--    − ce qui est sorti du comptoir (vendu / détruit) pour ces productions
--    − quantités livrées depuis le stock prêt (bons de livraison)
--    + quantités récupérées sur des bons de livraison
--    − quantités vendues en caisse depuis le stock prêt (sale_lines.from_ready)
--
--  « Mettre au comptoir » ne sort plus rien du stock prêt : le comptoir n'est
--  qu'un emplacement du produit fini.
--
--  CAISSE : une ligne « fiche technique » prend d'abord dans le stock prêt ;
--  seul le MANQUANT est produit (production origine « caisse », visible dans
--  l'écran Production), puis la vente est enregistrée. Supprimer la vente rend
--  au stock prêt ce qu'elle y avait pris.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  1. COLONNE : part d'une ligne de vente prise dans le stock prêt
-- -----------------------------------------------------------------------------
alter table public.sale_lines add column if not exists from_ready numeric(14,3) not null default 0;

-- -----------------------------------------------------------------------------
--  2. INDEX (stock prêt + toutes les clés étrangères sans index)
-- -----------------------------------------------------------------------------
create index if not exists sale_lines_fiche_ready_idx on public.sale_lines (fiche_technic_id) where from_ready > 0;
create index if not exists comptoir_items_production_idx on public.comptoir_items (production_id);
create index if not exists productions_sale_idx on public.productions (sale_id);
create index if not exists productions_date_idx on public.productions (date desc);
create index if not exists commands_client_idx on public.commands (client_id);
create index if not exists sale_payments_date_idx on public.sale_payments (date);

-- Chaque clé étrangère reçoit un index : les jointures, les suppressions en
-- cascade et les lectures « vente + lignes + paiements » deviennent rapides.
do $$
declare r record; v_name text;
begin
  for r in
    select c.conrelid::regclass as tbl, c.conrelid, a.attname as col,
           cl.relname as tname
      from pg_constraint c
      join pg_class cl on cl.oid = c.conrelid
      join pg_namespace n on n.oid = cl.relnamespace
      join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
     where c.contype = 'f' and n.nspname = 'public' and array_length(c.conkey, 1) = 1
       and not exists (
         select 1 from pg_index i
          where i.indrelid = c.conrelid and i.indkey[0] = c.conkey[1])
  loop
    v_name := left(r.tname || '_' || r.col || '_fk_idx', 63);
    execute format('create index if not exists %I on %s (%I)', v_name, r.tbl, r.col);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
--  3. STOCK PRÊT
-- -----------------------------------------------------------------------------
create or replace function public.fiche_ready_quantity(p_fiche uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select round(
      coalesce((select sum(output_quantity) from public.productions
                 where fiche_technic_id = p_fiche and origin <> 'pos'), 0)
    - coalesce((select sum(greatest(0, ci.initial_quantity - ci.quantity)) from public.comptoir_items ci
                  join public.productions pr on pr.id = ci.production_id
                 where pr.fiche_technic_id = p_fiche and pr.origin <> 'pos'), 0)
    - coalesce((select sum(quantity) from public.command_delivery_items
                 where fiche_technic_id = p_fiche and ready_applied), 0)
    + coalesce((select sum(ri.quantity) from public.delivery_recovery_items ri
                 where ri.fiche_technic_id = p_fiche and ri.ready_applied), 0)
    - coalesce((select sum(sl.from_ready) from public.sale_lines sl
                  join public.sales s on s.id = sl.sale_id
                 where sl.fiche_technic_id = p_fiche and sl.from_ready > 0
                   and not coalesce(s.is_historical, false)), 0), 3)
$$;

-- Stock prêt de TOUS les produits en une requête (tableau de bord, écrans).
create or replace function public.fiche_ready_quantities()
returns table (fiche_technic_id uuid, ready numeric)
language sql stable security definer set search_path = public as $$
  select f.id, public.fiche_ready_quantity(f.id) from public.fiche_technics f
$$;

-- Comptoir encore disponible (non vendu) d'un produit — partie du stock prêt.
create or replace function public._fiche_on_comptoir(p_fiche uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(sum(greatest(0, ci.quantity)), 0) from public.comptoir_items ci
    join public.productions pr on pr.id = ci.production_id
   where pr.fiche_technic_id = p_fiche and pr.origin <> 'pos'
$$;

-- -----------------------------------------------------------------------------
--  4. METTRE AU COMPTOIR : seulement ce qui est prêt et pas déjà au comptoir
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
    v_free := public.fiche_ready_quantity(pr.fiche_technic_id) - public._fiche_on_comptoir(pr.fiche_technic_id);
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
--  5. LIGNES DE VENTE → comptoir / stock
--     La part prise dans le stock prêt (from_ready) ne touche pas le comptoir :
--     seule la part PRODUITE (lot de caisse mis au comptoir) en sort.
-- -----------------------------------------------------------------------------
create or replace function public.trg_sale_line_stock()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_hist boolean; v_delivery uuid; v_fiche uuid;
begin
  if tg_op in ('UPDATE','DELETE') and old.stock_applied then
    if old.comptoir_id is not null then
      update public.comptoir_items set quantity = quantity + greatest(0, old.quantity - old.from_ready)
       where id = old.comptoir_id;
    elsif old.product_id is not null then
      update public.products set current_quantity = current_quantity + old.quantity where id = old.product_id;
    end if;
  end if;
  if tg_op in ('INSERT','UPDATE') then
    -- une ligne réduite ne peut pas avoir pris plus que sa quantité
    new.from_ready := least(greatest(coalesce(new.from_ready, 0), 0), greatest(new.quantity, 0));
    select is_historical, delivery_id into v_hist, v_delivery from public.sales where id = new.sale_id;
    if coalesce(v_hist, false) or v_delivery is not null then new.from_ready := 0; end if;
    -- delivery invoices consume raw materials through command_delivery_consumptions instead
    new.stock_applied := not coalesce(v_hist, false) and v_delivery is null
                         and (new.comptoir_id is not null or new.product_id is not null);
    if new.stock_applied then
      if new.comptoir_id is not null then
        update public.comptoir_items set quantity = quantity - greatest(0, new.quantity - new.from_ready)
         where id = new.comptoir_id;
        -- un article du comptoir est du stock prêt : jamais vendu au-delà
        if tg_op = 'INSERT' or new.quantity > old.quantity + 0.0005 then
          select pr.fiche_technic_id into v_fiche from public.comptoir_items ci
            join public.productions pr on pr.id = ci.production_id
           where ci.id = new.comptoir_id and pr.origin <> 'pos';
          if v_fiche is not null and public.fiche_ready_quantity(v_fiche) < -0.0005 then
            raise exception 'Stock prêt insuffisant pour « % » : il a déjà été livré ou vendu', new.product_name;
          end if;
        end if;
      else
        update public.products set current_quantity = current_quantity - new.quantity where id = new.product_id;
      end if;
    end if;
    return new;
  end if;
  return old;
end $$;
drop trigger if exists sale_line_stock on public.sale_lines;
create trigger sale_line_stock before insert or update or delete on public.sale_lines
  for each row execute function public.trg_sale_line_stock();

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
      line_key, product_name, quantity, selling_price, base_price, sell_by_unit, unit, from_ready)
    values (p_sale, v_prod, v_comp, v_fiche, v_pr, v_ci, l->>'line_key', coalesce(l->>'product_name', ''),
      coalesce((l->>'quantity')::numeric, 0), coalesce((l->>'selling_price')::numeric, 0),
      (l->>'base_price')::numeric, coalesce((l->>'sell_by_unit')::boolean, false), l->>'unit',
      coalesce((l->>'from_ready')::numeric, 0));
  end loop;
end $$;

-- Recette d'un lot de caisse ramenée à la quantité réellement produite.
create or replace function public._scale_production_payload(pr jsonb, p_qty numeric)
returns jsonb language plpgsql immutable as $$
declare v_full numeric; v_k numeric; u jsonb; v_lines jsonb := '[]'::jsonb;
begin
  v_full := coalesce((pr->>'output_quantity')::numeric, 0);
  if v_full <= 0 or abs(v_full - p_qty) < 0.0005 then return pr; end if;
  v_k := p_qty / v_full;
  for u in select * from jsonb_array_elements(coalesce(pr->'used_products', '[]'::jsonb)) loop
    v_lines := v_lines || jsonb_build_array(u || jsonb_build_object(
      'quantity_used', round(coalesce((u->>'quantity_used')::numeric, 0) * v_k, 4),
      'line_cost', round(coalesce((u->>'line_cost')::numeric, 0) * v_k, 2)));
  end loop;
  return pr || jsonb_build_object('output_quantity', round(p_qty, 3), 'used_products', v_lines);
end $$;

-- -----------------------------------------------------------------------------
--  6. CAISSE : stock prêt d'abord, production du manquant, puis la vente
-- -----------------------------------------------------------------------------
create or replace function public.create_sale_with_productions(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare pr jsonb; v_prod public.productions; v_item public.comptoir_items; v_map jsonb := '{}'::jsonb;
        v_lines jsonb := '[]'::jsonb; l jsonb; v_sale public.sales; v_key text; v_fiche uuid;
        v_qty numeric; v_ready numeric; v_from numeric; v_missing numeric; v_used jsonb := '{}'::jsonb;
begin
  perform public.require_perm(array['pos:create','sales:create']);
  if not coalesce((p_payload->>'is_historical')::boolean, false) then
    for pr in select * from jsonb_array_elements(coalesce(p_payload->'productions', '[]'::jsonb)) loop
      v_key := pr->>'line_key';
      v_fiche := nullif(pr->>'fiche_technic_id', '')::uuid;
      v_qty := round(coalesce((pr->>'output_quantity')::numeric, 0), 3);
      v_from := 0;
      if v_fiche is not null then
        -- deux lignes du même produit se partagent le même stock prêt
        v_ready := greatest(0, public.fiche_ready_quantity(v_fiche)
                               - coalesce((v_used->>v_fiche::text)::numeric, 0));
        v_from := round(least(v_qty, v_ready), 3);
        v_used := v_used || jsonb_build_object(v_fiche::text,
                    coalesce((v_used->>v_fiche::text)::numeric, 0) + v_from);
      end if;
      v_missing := round(v_qty - v_from, 3);
      v_map := v_map || jsonb_build_object(v_key, jsonb_build_object('from_ready', v_from));
      if v_missing > 0.0005 then
        v_prod := public._create_production(public._scale_production_payload(pr, v_missing)
                    || jsonb_build_object('date', p_payload->>'date', 'origin', 'pos'));
        if v_prod.output_quantity > 0 then
          v_item := public._transfer_to_comptoir(v_prod.id, v_prod.output_quantity);
          v_map := v_map || jsonb_build_object(v_key, jsonb_build_object(
                     'from_ready', v_from, 'comptoir_id', v_item.id, 'production_id', v_prod.id));
        end if;
      end if;
    end loop;
  end if;
  for l in select * from jsonb_array_elements(coalesce(p_payload->'products', '[]'::jsonb)) loop
    v_key := l->>'line_key';
    if v_key is not null and v_map ? v_key then
      l := l || jsonb_build_object(
        'comptoir_id', v_map->v_key->>'comptoir_id',
        'production_id', v_map->v_key->>'production_id',
        'from_ready', coalesce((v_map->v_key->>'from_ready')::numeric, 0),
        'product_id', null);
    end if;
    v_lines := v_lines || jsonb_build_array(l);
  end loop;
  v_sale := public._create_sale(p_payload || jsonb_build_object('products', v_lines));
  update public.productions set sale_id = v_sale.id, sale_reference = v_sale.reference
  where id in (select (value->>'production_id')::uuid from jsonb_each(v_map) where value ? 'production_id');
  return to_jsonb(v_sale);
end $$;

-- Filet de sécurité : ne relance QUE la part manquante d'une ligne (idempotent).
create or replace function public.repair_pos_sale_productions(p_payload jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare v_sale public.sales; pr jsonb; v_prod public.productions; n int := 0; v_missing numeric;
begin
  perform public.require_perm(array['pos:create','sales:create']);
  select * into v_sale from public.sales where id = (p_payload->>'sale_id')::uuid;
  if not found or v_sale.is_historical then return 0; end if;
  for pr in select * from jsonb_array_elements(coalesce(p_payload->'productions', '[]'::jsonb)) loop
    if exists (select 1 from public.productions where sale_id = v_sale.id
               and coalesce(line_key, '') = coalesce(pr->>'line_key', '')) then continue; end if;
    select round(sl.quantity - sl.from_ready, 3) into v_missing from public.sale_lines sl
     where sl.sale_id = v_sale.id and coalesce(sl.line_key, '') = coalesce(pr->>'line_key', '') limit 1;
    v_missing := coalesce(v_missing, (pr->>'output_quantity')::numeric);
    continue when v_missing <= 0.0005;
    v_prod := public._create_production(public._scale_production_payload(pr, v_missing)
                || jsonb_build_object('date', v_sale.date, 'origin', 'pos',
                     'sale_id', v_sale.id, 'sale_reference', v_sale.reference));
    update public.productions set sent_to_comptoir = output_quantity where id = v_prod.id;
    n := n + 1;
  end loop;
  return n;
end $$;

-- -----------------------------------------------------------------------------
--  7. DROITS
-- -----------------------------------------------------------------------------
grant execute on function public.fiche_ready_quantity(uuid) to authenticated;
grant execute on function public.fiche_ready_quantities() to authenticated;
grant execute on function public.create_sale_with_productions(jsonb) to authenticated;
grant execute on function public.repair_pos_sale_productions(jsonb) to authenticated;

-- statistiques à jour pour le planificateur de requêtes
analyze;

notify pgrst, 'reload schema';
