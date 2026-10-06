-- =============================================================================
--  RPC — SALES (POS, old sales, TVA)
-- =============================================================================
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
      line_key, product_name, quantity, selling_price, base_price, sell_by_unit, unit)
    values (p_sale, v_prod, v_comp, v_fiche, v_pr, v_ci, l->>'line_key', coalesce(l->>'product_name', ''),
      coalesce((l->>'quantity')::numeric, 0), coalesce((l->>'selling_price')::numeric, 0),
      (l->>'base_price')::numeric, coalesce((l->>'sell_by_unit')::boolean, false), l->>'unit');
  end loop;
end $$;

-- Replaces the cash part of a sale's payments so that the total paid = p_amount.
create or replace function public._sale_set_direct_paid(p_id uuid, p_amount numeric, p_date date)
returns void language plpgsql security definer set search_path = public as $$
declare v_other numeric; v_final numeric;
begin
  delete from public.sale_payments where sale_id = p_id and origin is null;
  select coalesce(sum(amount), 0) into v_other from public.sale_payments where sale_id = p_id;
  select final_amount into v_final from public.sales where id = p_id;
  if least(coalesce(p_amount, 0), v_final) - v_other > 0.004 then
    insert into public.sale_payments (sale_id, date, amount, description)
    values (p_id, coalesce(p_date, current_date), round(least(p_amount, v_final) - v_other, 2), 'Paiement à la vente');
  end if;
end $$;

create or replace function public._create_sale(p jsonb)
returns public.sales language plpgsql security definer set search_path = public as $$
declare v public.sales; v_client uuid;
begin
  v_client := nullif(p->>'client_id', '')::uuid;
  if v_client is not null and not exists (select 1 from public.clients where id = v_client) then v_client := null; end if;
  insert into public.sales (client_id, date, bon_number, is_historical, tva_enabled, tva_rate,
    reduction, total_amount, delivery_id, command_id)
  values (v_client, coalesce(nullif(p->>'date', '')::date, current_date), nullif(p->>'bon_number', ''),
    coalesce((p->>'is_historical')::boolean, false), coalesce((p->>'tva_enabled')::boolean, false),
    case when coalesce((p->>'tva_enabled')::boolean, false) then coalesce((p->>'tva_rate')::numeric, 19) else 0 end,
    coalesce((p->>'reduction')::numeric, 0), coalesce((p->>'total_amount')::numeric, 0),
    nullif(p->>'delivery_id', '')::uuid, nullif(p->>'command_id', '')::uuid)
  returning * into v;
  perform public._insert_sale_lines(v.id, p->'products');
  perform public._recalc_sale(v.id);
  perform public._sale_set_direct_paid(v.id, coalesce((p->>'paid_amount')::numeric, 0), v.date);
  select * into v from public.sales where id = v.id;
  return v;
end $$;

create or replace function public.create_sale(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['pos:create','sales:create']);
  return to_jsonb(public._create_sale(p_payload));
end $$;

-- POS: produce every fiche-technique line, put it on the comptoir, then sell it.
create or replace function public.create_sale_with_productions(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare pr jsonb; v_prod public.productions; v_item public.comptoir_items; v_map jsonb := '{}'::jsonb;
        v_lines jsonb := '[]'::jsonb; l jsonb; v_sale public.sales; v_key text;
begin
  perform public.require_perm(array['pos:create','sales:create']);
  if not coalesce((p_payload->>'is_historical')::boolean, false) then
    for pr in select * from jsonb_array_elements(coalesce(p_payload->'productions', '[]'::jsonb)) loop
      v_prod := public._create_production(pr || jsonb_build_object('date', p_payload->>'date', 'origin', 'pos'));
      if v_prod.output_quantity > 0 then
        v_item := public._transfer_to_comptoir(v_prod.id, v_prod.output_quantity);
        v_map := v_map || jsonb_build_object(pr->>'line_key',
                   jsonb_build_object('comptoir_id', v_item.id, 'production_id', v_prod.id));
      end if;
    end loop;
  end if;
  for l in select * from jsonb_array_elements(coalesce(p_payload->'products', '[]'::jsonb)) loop
    v_key := l->>'line_key';
    if v_key is not null and v_map ? v_key then
      l := l || jsonb_build_object('comptoir_id', v_map->v_key->>'comptoir_id',
                                   'production_id', v_map->v_key->>'production_id', 'product_id', null);
    end if;
    v_lines := v_lines || jsonb_build_array(l);
  end loop;
  v_sale := public._create_sale(p_payload || jsonb_build_object('products', v_lines));
  update public.productions set sale_id = v_sale.id, sale_reference = v_sale.reference
  where id in (select (value->>'production_id')::uuid from jsonb_each(v_map));
  return to_jsonb(v_sale);
end $$;

-- Safety net: launches the productions of a POS sale that has none (idempotent).
create or replace function public.repair_pos_sale_productions(p_payload jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare v_sale public.sales; pr jsonb; v_prod public.productions; n int := 0;
begin
  perform public.require_perm(array['pos:create','sales:create']);
  select * into v_sale from public.sales where id = (p_payload->>'sale_id')::uuid;
  if not found or v_sale.is_historical then return 0; end if;
  for pr in select * from jsonb_array_elements(coalesce(p_payload->'productions', '[]'::jsonb)) loop
    if exists (select 1 from public.productions where sale_id = v_sale.id
               and coalesce(line_key, '') = coalesce(pr->>'line_key', '')) then continue; end if;
    v_prod := public._create_production(pr || jsonb_build_object('date', v_sale.date, 'origin', 'pos',
                'sale_id', v_sale.id, 'sale_reference', v_sale.reference));
    update public.productions set sent_to_comptoir = output_quantity where id = v_prod.id;
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public._apply_sale_header(p_id uuid, p jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v public.sales;
begin
  update public.sales set
    date      = coalesce(nullif(p->>'date', '')::date, date),
    reduction = coalesce((p->>'reduction')::numeric, reduction),
    note      = coalesce(p->>'note', note),
    tva_enabled = case when p ? 'tva_enabled' then coalesce((p->>'tva_enabled')::boolean, false) else tva_enabled end,
    tva_rate    = case when p ? 'tva_enabled' then
                    case when coalesce((p->>'tva_enabled')::boolean, false) then coalesce((p->>'tva_rate')::numeric, 19) else 0 end
                  else tva_rate end
  where id = p_id returning * into v;
  if v.delivery_id is not null and nullif(p->>'date', '') is not null then
    update public.command_deliveries set date = v.date where id = v.delivery_id;
  end if;
  perform public._recalc_sale(p_id);
  if p->>'paid_amount' is not null then
    perform public._sale_set_direct_paid(p_id, (p->>'paid_amount')::numeric, v.date);
  end if;
end $$;

create or replace function public.update_sale(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['sales:edit','pos:edit']);
  perform public._apply_sale_header(p_id, p_payload);
  return (select to_jsonb(s) from public.sales s where id = p_id);
end $$;

create or replace function public.update_sale_lines(p_sale_id uuid, p_lines jsonb, p_header jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare l jsonb;
begin
  perform public.require_perm(array['sales:edit','pos:edit']);
  for l in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    if coalesce((l->>'quantity')::numeric, 0) <= 0 then
      delete from public.sale_lines where id = (l->>'id')::uuid and sale_id = p_sale_id;
    else
      update public.sale_lines set
        quantity = (l->>'quantity')::numeric,
        selling_price = coalesce((l->>'selling_price')::numeric, selling_price),
        product_name = coalesce(l->>'product_name', product_name)
      where id = (l->>'id')::uuid and sale_id = p_sale_id;
    end if;
  end loop;
  perform public._apply_sale_header(p_sale_id, coalesce(p_header, '{}'::jsonb));
  return (select to_jsonb(s) from public.sales s where id = p_sale_id);
end $$;

create or replace function public.pay_sale_debt(p_sale_id uuid, p_amount numeric, p_date date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.sales; r public.sale_payments;
begin
  perform public.require_perm(array['sales:pay','pos:pay','clients:pay','sales:edit']);
  select * into v from public.sales where id = p_sale_id;
  if not found then raise exception 'Vente introuvable'; end if;
  if coalesce(p_amount, 0) <= 0 then raise exception 'Montant invalide'; end if;
  if v.rest_amount <= 0.004 then raise exception 'Cette vente est déjà réglée'; end if;
  insert into public.sale_payments (sale_id, date, amount, description)
  values (p_sale_id, coalesce(p_date, current_date), round(least(p_amount, v.rest_amount), 2), 'Règlement dette')
  returning * into r;
  return to_jsonb(r);
end $$;

-- =============================================================================
--  RPC — COMMANDS
-- =============================================================================
create or replace function public._write_command_items(p_command uuid, p_items jsonb)
returns boolean   -- false when a delivered line had to be kept
language plpgsql security definer set search_path = public as $$
declare it jsonb; v_id uuid; v_kept boolean := false; v_ids uuid[] := '{}'; v_pos int := 0; v_fiche uuid;
begin
  for it in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    v_id := nullif(it->>'id', '')::uuid;
    v_fiche := nullif(it->>'fiche_technic_id', '')::uuid;
    if v_fiche is not null and not exists (select 1 from public.fiche_technics where id = v_fiche) then v_fiche := null; end if;
    if v_id is not null and exists (select 1 from public.command_items where id = v_id and command_id = p_command) then
      update public.command_items set
        position = coalesce((it->>'position')::int, v_pos),
        product_id = nullif(it->>'product_id', '')::uuid, fiche_technic_id = v_fiche,
        product_name = coalesce(it->>'product_name', product_name),
        quantity = greatest(delivered_quantity + cancelled_quantity, coalesce((it->>'quantity')::numeric, quantity)),
        unit_price = coalesce((it->>'unit_price')::numeric, unit_price),
        sell_by_unit = coalesce((it->>'sell_by_unit')::boolean, false), sell_unit = it->>'sell_unit'
      where id = v_id;
    else
      insert into public.command_items (command_id, position, product_id, fiche_technic_id, product_name,
        quantity, unit_price, total_price, sell_by_unit, sell_unit)
      values (p_command, coalesce((it->>'position')::int, v_pos), nullif(it->>'product_id', '')::uuid, v_fiche,
        coalesce(it->>'product_name', ''), coalesce((it->>'quantity')::numeric, 0),
        coalesce((it->>'unit_price')::numeric, 0), coalesce((it->>'total_price')::numeric, 0),
        coalesce((it->>'sell_by_unit')::boolean, false), it->>'sell_unit')
      returning id into v_id;
    end if;
    v_ids := v_ids || v_id;
    v_pos := v_pos + 1;
  end loop;
  -- lines removed from the form: deleted unless something was already delivered
  if exists (select 1 from public.command_items where command_id = p_command and not (id = any(v_ids)) and delivered_quantity > 0) then
    v_kept := true;
  end if;
  delete from public.command_items where command_id = p_command and not (id = any(v_ids)) and delivered_quantity = 0;
  return not v_kept;
end $$;

create or replace function public.create_command(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.commands; v_client uuid;
begin
  perform public.require_perm(array['clients:create','pos:create']);
  v_client := nullif(p_payload->>'client_id', '')::uuid;
  if v_client is not null and not exists (select 1 from public.clients where id = v_client) then v_client := null; end if;
  insert into public.commands (client_id, client_name, client_phone, client_address, driver_name, driver_plate,
    receive_date, receive_hour, receive_minute, tva_enabled, tva_rate, advance_paid, notes, bon_number,
    is_historical, created_at)
  values (v_client, coalesce(p_payload->>'client_name', ''), p_payload->>'client_phone', p_payload->>'client_address',
    p_payload->>'driver_name', p_payload->>'driver_plate', nullif(p_payload->>'receive_date', '')::date,
    p_payload->>'receive_hour', p_payload->>'receive_minute',
    coalesce((p_payload->>'tva_enabled')::boolean, false),
    case when coalesce((p_payload->>'tva_enabled')::boolean, false) then coalesce((p_payload->>'tva_rate')::numeric, 19) else 0 end,
    coalesce((p_payload->>'advance_paid')::numeric, 0), p_payload->>'notes', nullif(p_payload->>'bon_number', ''),
    coalesce((p_payload->>'is_historical')::boolean, false),
    coalesce(nullif(p_payload->>'created_at', '')::timestamptz, now()))
  returning * into v;
  perform public._write_command_items(v.id, p_payload->'items');
  perform public._recalc_command(v.id);
  select * into v from public.commands where id = v.id;
  return to_jsonb(v);
end $$;

create or replace function public.update_command(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.commands; v_replaced boolean := true; d record;
begin
  perform public.require_perm(array['clients:edit']);
  select * into v from public.commands where id = p_id;
  if not found then raise exception 'Commande introuvable'; end if;
  update public.commands set
    client_id      = case when p_payload ? 'client_id' then nullif(p_payload->>'client_id', '')::uuid else client_id end,
    client_name    = coalesce(p_payload->>'client_name', client_name),
    client_phone   = case when p_payload ? 'client_phone' then p_payload->>'client_phone' else client_phone end,
    client_address = case when p_payload ? 'client_address' then p_payload->>'client_address' else client_address end,
    driver_name    = case when p_payload ? 'driver_name' then p_payload->>'driver_name' else driver_name end,
    driver_plate   = case when p_payload ? 'driver_plate' then p_payload->>'driver_plate' else driver_plate end,
    receive_date   = case when p_payload ? 'receive_date' then nullif(p_payload->>'receive_date', '')::date else receive_date end,
    receive_hour   = coalesce(p_payload->>'receive_hour', receive_hour),
    receive_minute = coalesce(p_payload->>'receive_minute', receive_minute),
    notes          = case when p_payload ? 'notes' then p_payload->>'notes' else notes end,
    bon_number     = case when p_payload ? 'bon_number' then p_payload->>'bon_number' else bon_number end,
    tva_enabled    = case when p_payload ? 'tva_enabled' then coalesce((p_payload->>'tva_enabled')::boolean, false) else tva_enabled end,
    tva_rate       = case when p_payload ? 'tva_enabled' then
                       case when coalesce((p_payload->>'tva_enabled')::boolean, false) then coalesce((p_payload->>'tva_rate')::numeric, 19) else 0 end
                     else tva_rate end,
    advance_paid   = coalesce((p_payload->>'advance_paid')::numeric, advance_paid),
    is_historical  = coalesce((p_payload->>'is_historical')::boolean, is_historical),
    created_at     = coalesce(nullif(p_payload->>'created_at', '')::timestamptz, created_at)
  where id = p_id;
  if p_payload ? 'items' and jsonb_typeof(p_payload->'items') = 'array' then
    v_replaced := public._write_command_items(p_id, p_payload->'items');
  end if;
  perform public._recalc_command(p_id);
  -- delivery invoices follow the corrected unit prices
  for d in select sale_id from public.command_deliveries where command_id = p_id and sale_id is not null loop
    update public.sale_lines sl set selling_price = ci.unit_price, product_name = ci.product_name
      from public.command_items ci where sl.sale_id = d.sale_id and sl.command_item_id = ci.id;
    update public.sales set client_id = (select client_id from public.commands where id = p_id) where id = d.sale_id;
    perform public._recalc_sale(d.sale_id);
  end loop;
  return jsonb_build_object('id', p_id, 'lines_replaced', v_replaced);
end $$;

create or replace function public.pay_command(p_command_id uuid, p_amount numeric, p_date date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.command_payments;
begin
  perform public.require_perm(array['clients:pay','clients:edit']);
  if coalesce(p_amount, 0) <= 0 then raise exception 'Montant invalide'; end if;
  insert into public.command_payments (command_id, amount, date)
  values (p_command_id, round(p_amount, 2), coalesce(p_date, current_date)) returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.update_command_payment(p_id uuid, p_amount numeric, p_date date default null, p_notes text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.command_payments;
begin
  perform public.require_perm(array['clients:pay','clients:edit']);
  if coalesce(p_amount, 0) <= 0 then
    delete from public.command_payments where id = p_id returning * into r;
  else
    update public.command_payments set amount = round(p_amount, 2), date = coalesce(p_date, date),
      notes = coalesce(p_notes, notes) where id = p_id returning * into r;
  end if;
  return to_jsonb(r);
end $$;

create or replace function public.set_command_status(p_command_id uuid, p_status text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.commands;
begin
  perform public.require_perm(array['clients:edit']);
  update public.commands set status = p_status where id = p_command_id returning * into v;
  return to_jsonb(v);
end $$;

create or replace function public._write_adjustment(p jsonb, p_type text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.commands; a public.command_adjustments; l jsonb; ci public.command_items; v_qty numeric;
        v_price numeric; v_item uuid; v_tq numeric := 0; v_ta numeric := 0;
begin
  select * into c from public.commands where id = (p->>'command_id')::uuid;
  if not found then raise exception 'Commande introuvable'; end if;
  insert into public.command_adjustments (command_id, command_reference, client_id, client_name, type, date, reason)
  values (c.id, c.reference, c.client_id, c.client_name, p_type,
          coalesce(nullif(p->>'date', '')::date, current_date), p->>'reason')
  returning * into a;
  for l in select * from jsonb_array_elements(coalesce(p->'lines', '[]'::jsonb)) loop
    v_qty := coalesce((l->>'quantity')::numeric, 0);
    if v_qty <= 0 then continue; end if;
    v_item := nullif(l->>'command_item_id', '')::uuid;
    select * into ci from public.command_items where id = v_item and command_id = c.id;
    if p_type = 'cancel' then
      if not found then continue; end if;
      v_qty := least(v_qty, greatest(0, ci.quantity - ci.delivered_quantity - ci.cancelled_quantity));
      if v_qty <= 0 then continue; end if;
      update public.command_items set cancelled_quantity = cancelled_quantity + v_qty where id = ci.id;
      v_price := ci.unit_price;
    else
      if found then
        update public.command_items set quantity = quantity + v_qty,
          unit_price = coalesce((l->>'unit_price')::numeric, unit_price) where id = ci.id;
        v_price := coalesce((l->>'unit_price')::numeric, ci.unit_price);
      else
        v_price := coalesce((l->>'unit_price')::numeric, 0);
        insert into public.command_items (command_id, position, product_name, quantity, unit_price, sell_unit)
        values (c.id, (select coalesce(max(position), -1) + 1 from public.command_items where command_id = c.id),
                coalesce(l->>'product_name', ''), v_qty, v_price, l->>'unit')
        returning id into v_item;
      end if;
    end if;
    insert into public.command_adjustment_lines (adjustment_id, command_item_id, product_name, quantity, unit_price, amount, unit)
    values (a.id, v_item, coalesce(l->>'product_name', ci.product_name, ''), v_qty, v_price, round(v_qty * v_price, 2), l->>'unit');
    v_tq := v_tq + v_qty; v_ta := v_ta + round(v_qty * v_price, 2);
  end loop;
  update public.command_adjustments set total_quantity = v_tq, total_amount = v_ta where id = a.id returning * into a;
  perform public._recalc_command(c.id);
  return to_jsonb(a);
end $$;

create or replace function public.cancel_command_remainder(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['clients:edit']);
  return public._write_adjustment(p_payload, 'cancel');
end $$;

create or replace function public.increase_command(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['clients:edit']);
  return public._write_adjustment(p_payload, 'increase');
end $$;

create or replace function public.delete_command_adjustment(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare a public.command_adjustments; l record;
begin
  perform public.require_perm(array['clients:edit','clients:delete']);
  select * into a from public.command_adjustments where id = p_id;
  if not found then return; end if;
  for l in select * from public.command_adjustment_lines where adjustment_id = p_id loop
    if l.command_item_id is null then continue; end if;
    if a.type = 'cancel' then
      update public.command_items set cancelled_quantity = greatest(0, cancelled_quantity - l.quantity) where id = l.command_item_id;
    else
      update public.command_items set quantity = greatest(delivered_quantity + cancelled_quantity, quantity - l.quantity)
      where id = l.command_item_id;
    end if;
  end loop;
  delete from public.command_adjustments where id = p_id;
  perform public._recalc_command(a.command_id);
end $$;

-- =============================================================================
--  RPC — DELIVERIES (bon de livraison = vente)
-- =============================================================================
-- Builds items, raw-material consumption, the invoice (sale) and its payments.
create or replace function public._build_delivery(p_id uuid, p jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare d public.command_deliveries; c public.commands; it jsonb; ci public.command_items; fl record;
        v_qty numeric; v_lines jsonb := '[]'::jsonb; v_sale public.sales; v_fiche public.fiche_technics;
        v_adv_avail numeric; v_adv numeric; v_cash numeric;
begin
  select * into d from public.command_deliveries where id = p_id;
  select * into c from public.commands where id = d.command_id;

  for it in select * from jsonb_array_elements(coalesce(p->'items', '[]'::jsonb)) loop
    v_qty := coalesce((it->>'quantity')::numeric, 0);
    if v_qty <= 0 then continue; end if;
    select * into ci from public.command_items where id = nullif(it->>'command_item_id', '')::uuid and command_id = c.id;
    insert into public.command_delivery_items (delivery_id, command_item_id, product_name, quantity, sell_unit)
    values (p_id, ci.id, coalesce(it->>'product_name', ci.product_name, ''), v_qty, coalesce(it->>'sell_unit', ci.sell_unit));

    -- raw materials of the recipe leave the stock, proportionally to what is delivered
    if ci.fiche_technic_id is not null then
      select * into v_fiche from public.fiche_technics where id = ci.fiche_technic_id;
      for fl in select * from public.fiche_technic_lines
                where fiche_technic_id = ci.fiche_technic_id and coalesce(source_type, 'stock') = 'stock'
                  and product_id is not null and exists (select 1 from public.products where id = product_id) loop
        insert into public.command_delivery_consumptions (delivery_id, command_item_id, fiche_technic_id, product_id,
          product_name, unit, delivered_quantity, quantity, unit_cost, line_cost)
        values (p_id, ci.id, ci.fiche_technic_id, fl.product_id, fl.product_name, fl.unit, v_qty,
          round(fl.quantity_used / nullif(v_fiche.output_quantity, 0) * v_qty, 4), fl.unit_cost,
          round(fl.unit_cost * fl.quantity_used / nullif(v_fiche.output_quantity, 0) * v_qty, 2));
      end loop;
    end if;

    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'product_name', coalesce(it->>'product_name', ci.product_name, ''), 'quantity', v_qty,
      'selling_price', coalesce(ci.unit_price, 0), 'base_price', ci.unit_price,
      'fiche_technic_id', ci.fiche_technic_id, 'command_item_id', ci.id,
      'sell_by_unit', coalesce(ci.sell_by_unit, false), 'unit', coalesce(it->>'sell_unit', ci.sell_unit)));
  end loop;

  -- the invoice
  v_sale := public._create_sale(jsonb_build_object(
    'client_id', c.client_id, 'date', d.date, 'bon_number', coalesce(c.bon_number, d.reference),
    'is_historical', d.is_historical, 'tva_enabled', d.tva_enabled, 'tva_rate', d.tva_rate,
    'delivery_id', d.id, 'command_id', c.id, 'products', v_lines, 'paid_amount', 0));

  -- money: part of the command's advance (no caisse) + cash received now (caisse)
  select greatest(0, c.paid_amount - coalesce(sum(advance_applied), 0)) into v_adv_avail
    from public.command_deliveries where command_id = c.id and id <> p_id;
  v_adv := least(coalesce((p->>'advance_applied')::numeric, 0), v_adv_avail, v_sale.final_amount);
  if v_adv > 0.004 then
    insert into public.sale_payments (sale_id, date, amount, description, origin)
    values (v_sale.id, d.date, round(v_adv, 2), 'Acompte de la commande ' || c.reference, 'command_advance');
  end if;
  v_cash := least(coalesce((p->>'cash_paid')::numeric, 0), greatest(0, v_sale.final_amount - v_adv));
  if v_cash > 0.004 then
    insert into public.sale_payments (sale_id, date, amount, description)
    values (v_sale.id, d.date, round(v_cash, 2), 'Versement à la livraison ' || d.reference);
  end if;

  update public.command_deliveries set sale_id = v_sale.id, sale_reference = v_sale.reference where id = p_id;
  perform public._recalc_sale(v_sale.id);
  perform public._recalc_command(c.id);
end $$;

create or replace function public.create_command_delivery(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.commands; d public.command_deliveries; v_tva boolean; v_at timestamptz;
begin
  perform public.require_perm(array['clients:create','sales:create']);
  select * into c from public.commands where id = (p_payload->>'command_id')::uuid;
  if not found then raise exception 'Commande introuvable'; end if;
  v_tva := case when p_payload ? 'tva_enabled' then coalesce((p_payload->>'tva_enabled')::boolean, false) else c.tva_enabled end;
  v_at := coalesce(nullif(p_payload->>'delivered_at', '')::timestamptz, now());
  insert into public.command_deliveries (command_id, date, delivered_at, notes, driver_name, driver_plate, location,
    is_historical, tva_enabled, tva_rate)
  values (c.id, v_at::date, v_at, coalesce(p_payload->>'notes', ''),
    coalesce(p_payload->>'driver_name', c.driver_name), coalesce(p_payload->>'driver_plate', c.driver_plate),
    coalesce(p_payload->>'location', c.client_address), c.is_historical, v_tva,
    case when v_tva then coalesce((p_payload->>'tva_rate')::numeric, nullif(c.tva_rate, 0), 19) else 0 end)
  returning * into d;
  perform public._build_delivery(d.id, p_payload);
  select * into d from public.command_deliveries where id = d.id;
  return to_jsonb(d);
end $$;

create or replace function public.update_command_delivery(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d public.command_deliveries; c public.commands; v_tva boolean; v_sale uuid; v_at timestamptz;
begin
  perform public.require_perm(array['clients:edit','sales:edit']);
  select * into d from public.command_deliveries where id = p_id;
  if not found then raise exception 'Bon de livraison introuvable'; end if;
  select * into c from public.commands where id = d.command_id;
  -- undo: detach and drop the invoice, give back delivered quantities and raw materials
  v_sale := d.sale_id;
  update public.command_deliveries set sale_id = null where id = p_id;
  if v_sale is not null then delete from public.sales where id = v_sale; end if;
  delete from public.command_delivery_items where delivery_id = p_id;
  delete from public.command_delivery_consumptions where delivery_id = p_id;

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

create or replace function public.delete_command_delivery(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['clients:delete','sales:delete']);
  delete from public.command_deliveries where id = p_id;
end $$;
