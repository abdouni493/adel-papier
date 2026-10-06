-- =============================================================================
--  BUSINESS TRIGGERS
--  Rule: every side effect written on INSERT is undone on DELETE, so editing a
--  document (delete + re-insert lines) and restoring from the recycle bin stay
--  consistent. All trigger functions are SECURITY DEFINER: a worker allowed to
--  sell can move stock and write the caisse without direct rights on them.
-- =============================================================================

alter table public.purchase_lines add column if not exists stock_applied boolean not null default false;
alter table public.production_used_products add column if not exists stock_applied boolean not null default false;
alter table public.command_delivery_consumptions add column if not exists stock_applied boolean not null default false;

-- -----------------------------------------------------------------------------
--  Caisse helpers
-- -----------------------------------------------------------------------------
create or replace function public._caisse_set(
  p_ref_table text, p_ref_id uuid, p_type text, p_amount numeric,
  p_date date, p_description text, p_category text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.caisse_transactions where ref_table = p_ref_table and ref_id = p_ref_id;
  if coalesce(p_amount, 0) > 0 then
    insert into public.caisse_transactions (type, amount, date, description, category_name, ref_table, ref_id)
    values (p_type, round(p_amount, 2), coalesce(p_date, current_date), coalesce(p_description, ''), p_category, p_ref_table, p_ref_id);
  end if;
end $$;

create or replace function public._caisse_clear(p_ref_table text, p_ref_id uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.caisse_transactions where ref_table = p_ref_table and ref_id = p_ref_id;
$$;

-- -----------------------------------------------------------------------------
--  Recalculation helpers
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
  update public.sales set
    total_amount = round(v_total, 2), tva_amount = v_tva, final_amount = v_final,
    paid_amount = v_paid, allocated_amount = v_alloc,
    rest_amount = greatest(0, v_final - v_paid),
    status = case when v_final - v_paid > 0.004 then 'debt' else 'paid' end
  where id = p_id;
  -- a delivery invoice mirrors its money on the delivery note
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

create or replace function public._recalc_purchase(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_total numeric; v_paid numeric; v_alloc numeric; v_has boolean; p public.purchases;
begin
  if position(p_id::text in coalesce(current_setting('app.deleting_doc', true), '')) > 0 then return; end if;
  select * into p from public.purchases where id = p_id;
  if not found then return; end if;
  select exists(select 1 from public.purchase_lines where purchase_id = p_id),
         coalesce(sum(quantity * purchase_price), 0)
    into v_has, v_total from public.purchase_lines where purchase_id = p_id;
  if not v_has then v_total := p.total_amount; end if;
  select coalesce(sum(amount), 0), coalesce(sum(amount) filter (where origin = 'credit'), 0)
    into v_paid, v_alloc from public.purchase_payments where purchase_id = p_id;
  update public.purchases set
    total_amount = round(v_total, 2), paid_amount = v_paid, allocated_amount = v_alloc,
    rest_amount = greatest(0, round(v_total, 2) - v_paid)
  where id = p_id;
end $$;

create or replace function public._recalc_command(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare c public.commands; v_ht numeric; v_tva numeric; v_ttc numeric; v_extra numeric; v_paid numeric;
begin
  select * into c from public.commands where id = p_id;
  if not found then return; end if;
  update public.command_items set total_price = round(quantity * unit_price, 2) where command_id = p_id;
  select coalesce(sum(greatest(0, quantity - cancelled_quantity) * unit_price), 0)
    into v_ht from public.command_items where command_id = p_id;
  v_ht := round(v_ht, 2);
  v_tva := case when c.tva_enabled then round(v_ht * c.tva_rate) / 100 else 0 end;
  v_ttc := round(v_ht + v_tva, 2);
  select coalesce(sum(amount), 0) into v_extra from public.command_payments where command_id = p_id;
  v_paid := c.advance_paid + v_extra + c.credit_applied;
  update public.commands set
    total_amount = v_ht, tva_amount = v_tva, total_ttc = v_ttc,
    extra_paid = v_extra, paid_amount = v_paid, rest_amount = greatest(0, v_ttc - v_paid)
  where id = p_id;
end $$;

create or replace function public._recalc_old_debt(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_paid numeric;
begin
  select coalesce(sum(amount), 0) into v_paid from public.party_old_debt_allocations where old_debt_id = p_id;
  update public.party_old_debts set paid_amount = v_paid, rest_amount = greatest(0, amount - v_paid) where id = p_id;
end $$;

-- -----------------------------------------------------------------------------
--  PURCHASE LINES → stock (skipped for « ancien achat »)
-- -----------------------------------------------------------------------------
create or replace function public.trg_purchase_line_stock()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_hist boolean;
begin
  if tg_op in ('UPDATE','DELETE') and old.stock_applied and old.product_id is not null then
    update public.products set
      current_quantity = current_quantity - old.quantity,
      principal_quantity = greatest(0, principal_quantity - old.quantity)
    where id = old.product_id;
  end if;
  if tg_op in ('INSERT','UPDATE') then
    select is_historical into v_hist from public.purchases where id = new.purchase_id;
    new.stock_applied := (not coalesce(v_hist, false)) and new.product_id is not null;
    if new.stock_applied then
      update public.products set
        current_quantity = current_quantity + new.quantity,
        principal_quantity = principal_quantity + new.quantity,
        purchase_price = case when new.purchase_price > 0 then new.purchase_price else purchase_price end,
        min_alert_quantity = coalesce(nullif(new.min_alert_quantity, 0), min_alert_quantity),
        unit_enabled = coalesce(new.unit_enabled, unit_enabled),
        unit = case when new.unit_enabled then coalesce(new.unit, unit) else unit end,
        expiration_enabled = case when new.expiration_date is not null then true else expiration_enabled end,
        expiration_date = coalesce(new.expiration_date, expiration_date)
      where id = new.product_id;
    end if;
    return new;
  end if;
  return old;
end $$;
drop trigger if exists purchase_line_stock on public.purchase_lines;
create trigger purchase_line_stock before insert or update or delete on public.purchase_lines
  for each row execute function public.trg_purchase_line_stock();

create or replace function public.trg_purchase_line_recalc()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public._recalc_purchase(coalesce(new.purchase_id, old.purchase_id));
  return null;
end $$;
drop trigger if exists purchase_line_recalc on public.purchase_lines;
create trigger purchase_line_recalc after insert or update or delete on public.purchase_lines
  for each row execute function public.trg_purchase_line_recalc();

-- -----------------------------------------------------------------------------
--  PURCHASE PAYMENTS → caisse withdrawal + totals
-- -----------------------------------------------------------------------------
create or replace function public.trg_purchase_payment()
returns trigger language plpgsql security definer set search_path = public as $$
declare p public.purchases;
begin
  if tg_op = 'DELETE' then
    perform public._caisse_clear('purchase_payments', old.id);
    if old.origin = 'credit' then
      update public.suppliers set credit_amount = credit_amount + old.amount
      where id = (select supplier_id from public.purchases where id = old.purchase_id);
    end if;
    perform public._recalc_purchase(old.purchase_id);
    return old;
  end if;
  select * into p from public.purchases where id = new.purchase_id;
  if tg_op = 'INSERT' and new.origin = 'credit' then
    update public.suppliers set credit_amount = credit_amount - new.amount where id = p.supplier_id;
  end if;
  if new.origin is null and not coalesce(p.is_historical, false) then
    perform public._caisse_set('purchase_payments', new.id, 'withdrawal', new.amount, new.date,
      'Achat ' || coalesce(p.reference, ''), 'Achat');
  else
    perform public._caisse_clear('purchase_payments', new.id);
  end if;
  perform public._recalc_purchase(new.purchase_id);
  return new;
end $$;
drop trigger if exists purchase_payment_trg on public.purchase_payments;
create trigger purchase_payment_trg after insert or update or delete on public.purchase_payments
  for each row execute function public.trg_purchase_payment();

-- -----------------------------------------------------------------------------
--  SALE LINES → comptoir / stock (skipped for « ancienne vente » & delivery invoices)
-- -----------------------------------------------------------------------------
create or replace function public.trg_sale_line_stock()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_hist boolean; v_delivery uuid;
begin
  if tg_op in ('UPDATE','DELETE') and old.stock_applied then
    if old.comptoir_id is not null then
      update public.comptoir_items set quantity = quantity + old.quantity where id = old.comptoir_id;
    elsif old.product_id is not null then
      update public.products set current_quantity = current_quantity + old.quantity where id = old.product_id;
    end if;
  end if;
  if tg_op in ('INSERT','UPDATE') then
    select is_historical, delivery_id into v_hist, v_delivery from public.sales where id = new.sale_id;
    -- delivery invoices consume raw materials through command_delivery_consumptions instead
    new.stock_applied := not coalesce(v_hist, false) and v_delivery is null
                         and (new.comptoir_id is not null or new.product_id is not null);
    if new.stock_applied then
      if new.comptoir_id is not null then
        update public.comptoir_items set quantity = quantity - new.quantity where id = new.comptoir_id;
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

create or replace function public.trg_sale_line_recalc()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public._recalc_sale(coalesce(new.sale_id, old.sale_id));
  return null;
end $$;
drop trigger if exists sale_line_recalc on public.sale_lines;
create trigger sale_line_recalc after insert or update or delete on public.sale_lines
  for each row execute function public.trg_sale_line_recalc();

-- -----------------------------------------------------------------------------
--  SALE PAYMENTS → caisse deposit (cash only) + totals
-- -----------------------------------------------------------------------------
create or replace function public.trg_sale_payment()
returns trigger language plpgsql security definer set search_path = public as $$
declare s public.sales;
begin
  if tg_op = 'DELETE' then
    perform public._caisse_clear('sale_payments', old.id);
    -- money that came from the client's acompte goes back to it
    if old.origin = 'credit' then
      update public.clients set credit_amount = credit_amount + old.amount
      where id = (select client_id from public.sales where id = old.sale_id);
    end if;
    perform public._recalc_sale(old.sale_id);
    return old;
  end if;
  select * into s from public.sales where id = new.sale_id;
  if tg_op = 'INSERT' and new.origin = 'credit' then
    update public.clients set credit_amount = credit_amount - new.amount where id = s.client_id;
  end if;
  if new.origin is null and not coalesce(s.is_historical, false) then
    perform public._caisse_set('sale_payments', new.id, 'deposit', new.amount, new.date,
      case when s.delivery_id is not null then 'Bon de livraison ' else 'Vente ' end || coalesce(s.reference, ''),
      case when s.delivery_id is not null then 'Livraison' else 'Vente' end);
  else
    perform public._caisse_clear('sale_payments', new.id);
  end if;
  perform public._recalc_sale(new.sale_id);
  return new;
end $$;
drop trigger if exists sale_payment_trg on public.sale_payments;
create trigger sale_payment_trg after insert or update or delete on public.sale_payments
  for each row execute function public.trg_sale_payment();

-- Payments are removed BEFORE their document so acompte money finds its party.
create or replace function public.trg_doc_before_delete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- the document itself must not be re-updated while it is being deleted
  perform set_config('app.deleting_doc', coalesce(current_setting('app.deleting_doc', true), '') || ',' || old.id::text, true);
  if tg_table_name = 'sales' then
    delete from public.sale_payments where sale_id = old.id;
    delete from public.sale_lines where sale_id = old.id;
  else
    delete from public.purchase_payments where purchase_id = old.id;
    delete from public.purchase_lines where purchase_id = old.id;
  end if;
  return old;
end $$;
drop trigger if exists sale_before_delete on public.sales;
create trigger sale_before_delete before delete on public.sales
  for each row execute function public.trg_doc_before_delete();
drop trigger if exists purchase_before_delete on public.purchases;
create trigger purchase_before_delete before delete on public.purchases
  for each row execute function public.trg_doc_before_delete();

-- -----------------------------------------------------------------------------
--  COMMANDS — advance & payments → caisse ; totals
-- -----------------------------------------------------------------------------
create or replace function public.trg_command_advance()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    perform public._caisse_clear('commands', old.id);
    if old.credit_applied > 0 and old.client_id is not null then
      update public.clients set credit_amount = credit_amount + old.credit_applied where id = old.client_id;
    end if;
    return old;
  end if;
  if new.is_historical then
    perform public._caisse_clear('commands', new.id);
  else
    perform public._caisse_set('commands', new.id, 'deposit', new.advance_paid,
      coalesce(new.created_at::date, current_date), 'Acompte commande ' || new.reference, 'Commande');
  end if;
  return new;
end $$;
drop trigger if exists command_advance_trg on public.commands;
create trigger command_advance_trg after insert or update of advance_paid, is_historical, created_at or delete on public.commands
  for each row execute function public.trg_command_advance();

create or replace function public.trg_command_payment()
returns trigger language plpgsql security definer set search_path = public as $$
declare c public.commands;
begin
  if tg_op = 'DELETE' then
    perform public._caisse_clear('command_payments', old.id);
    perform public._recalc_command(old.command_id);
    return old;
  end if;
  select * into c from public.commands where id = new.command_id;
  if coalesce(c.is_historical, false) then
    perform public._caisse_clear('command_payments', new.id);
  else
    perform public._caisse_set('command_payments', new.id, 'deposit', new.amount, new.date,
      'Règlement commande ' || coalesce(c.reference, ''), 'Commande');
  end if;
  perform public._recalc_command(new.command_id);
  return new;
end $$;
drop trigger if exists command_payment_trg on public.command_payments;
create trigger command_payment_trg after insert or update or delete on public.command_payments
  for each row execute function public.trg_command_payment();

-- -----------------------------------------------------------------------------
--  DELIVERIES — delivered quantities, raw-material consumption, linked sale
-- -----------------------------------------------------------------------------
create or replace function public.trg_delivery_item()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op in ('UPDATE','DELETE') and old.command_item_id is not null then
    update public.command_items set delivered_quantity = greatest(0, delivered_quantity - old.quantity)
    where id = old.command_item_id;
  end if;
  if tg_op in ('INSERT','UPDATE') and new.command_item_id is not null then
    update public.command_items set delivered_quantity = delivered_quantity + new.quantity
    where id = new.command_item_id;
  end if;
  return coalesce(new, old);
end $$;
drop trigger if exists delivery_item_trg on public.command_delivery_items;
create trigger delivery_item_trg after insert or update or delete on public.command_delivery_items
  for each row execute function public.trg_delivery_item();

create or replace function public.trg_delivery_consumption()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_hist boolean;
begin
  if tg_op = 'DELETE' then
    if old.stock_applied and old.product_id is not null then
      update public.products set current_quantity = current_quantity + old.quantity where id = old.product_id;
    end if;
    return old;
  end if;
  select is_historical into v_hist from public.command_deliveries where id = new.delivery_id;
  new.stock_applied := not coalesce(v_hist, false) and new.product_id is not null;
  if new.stock_applied then
    update public.products set current_quantity = current_quantity - new.quantity where id = new.product_id;
  end if;
  return new;
end $$;
drop trigger if exists delivery_consumption_trg on public.command_delivery_consumptions;
create trigger delivery_consumption_trg before insert or delete on public.command_delivery_consumptions
  for each row execute function public.trg_delivery_consumption();

-- deleting a delivery note deletes its invoice (and vice-versa through the FK cascade)
create or replace function public.trg_delivery_delete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.sale_id is not null then
    delete from public.sales where id = old.sale_id;
  end if;
  perform public._recalc_command(old.command_id);
  return old;
end $$;
drop trigger if exists delivery_delete_trg on public.command_deliveries;
create trigger delivery_delete_trg after delete on public.command_deliveries
  for each row execute function public.trg_delivery_delete();

-- -----------------------------------------------------------------------------
--  PRODUCTION — raw materials leave the stock ; comptoir transfers
-- -----------------------------------------------------------------------------
create or replace function public.trg_production_used()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if old.stock_applied then
      update public.products set current_quantity = current_quantity + old.quantity_used where id = old.product_id;
    end if;
    return old;
  end if;
  new.stock_applied := coalesce(new.source_type, 'stock') = 'stock'
                       and new.product_id is not null
                       and exists (select 1 from public.products where id = new.product_id);
  if new.stock_applied then
    update public.products set current_quantity = current_quantity - new.quantity_used where id = new.product_id;
  end if;
  return new;
end $$;
drop trigger if exists production_used_trg on public.production_used_products;
create trigger production_used_trg before insert or delete on public.production_used_products
  for each row execute function public.trg_production_used();

create or replace function public.trg_comptoir_item()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if old.production_id is not null then
      update public.productions set sent_to_comptoir = greatest(0, sent_to_comptoir - old.initial_quantity)
      where id = old.production_id;
    end if;
    return old;
  end if;
  if new.initial_quantity = 0 then new.initial_quantity := new.quantity; end if;
  if new.production_id is not null then
    update public.productions set sent_to_comptoir = sent_to_comptoir + new.initial_quantity
    where id = new.production_id;
  end if;
  return new;
end $$;
drop trigger if exists comptoir_item_trg on public.comptoir_items;
create trigger comptoir_item_trg before insert or delete on public.comptoir_items
  for each row execute function public.trg_comptoir_item();

-- -----------------------------------------------------------------------------
--  PARTY PAYMENTS, REFUNDS, OLD DEBTS
-- -----------------------------------------------------------------------------
create or replace function public.trg_client_payment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    perform public._caisse_clear('client_payments', old.id);
    update public.clients set credit_amount = credit_amount - old.credit_part where id = old.client_id;
    return old;
  end if;
  if tg_op = 'INSERT' and new.credit_part <> 0 then   -- restore from recycle bin
    update public.clients set credit_amount = credit_amount + new.credit_part where id = new.client_id;
  end if;
  perform public._caisse_set('client_payments', new.id, 'deposit', new.amount, new.date,
    'Versement client ' || coalesce(new.client_name, ''), 'Versement client');
  return new;
end $$;
drop trigger if exists client_payment_trg on public.client_payments;
create trigger client_payment_trg after insert or update or delete on public.client_payments
  for each row execute function public.trg_client_payment();

create or replace function public.trg_supplier_payment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    perform public._caisse_clear('supplier_payments', old.id);
    update public.suppliers set credit_amount = credit_amount - old.credit_part where id = old.supplier_id;
    return old;
  end if;
  if tg_op = 'INSERT' and new.credit_part <> 0 then
    update public.suppliers set credit_amount = credit_amount + new.credit_part where id = new.supplier_id;
  end if;
  perform public._caisse_set('supplier_payments', new.id, 'withdrawal', new.amount, new.date,
    'Règlement fournisseur ' || coalesce(new.supplier_name, ''), 'Règlement fournisseur');
  return new;
end $$;
drop trigger if exists supplier_payment_trg on public.supplier_payments;
create trigger supplier_payment_trg after insert or update or delete on public.supplier_payments
  for each row execute function public.trg_supplier_payment();

create or replace function public.trg_party_refund()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op in ('UPDATE','DELETE') then
    perform public._caisse_clear('party_credit_refunds', old.id);
    if old.party_type = 'client' then
      update public.clients set credit_amount = credit_amount + old.amount where id = old.party_id;
    else
      update public.suppliers set credit_amount = credit_amount + old.amount where id = old.party_id;
    end if;
  end if;
  if tg_op in ('INSERT','UPDATE') then
    if new.party_type = 'client' then
      update public.clients set credit_amount = credit_amount - new.amount where id = new.party_id;
      perform public._caisse_set('party_credit_refunds', new.id, 'withdrawal', new.amount, new.date,
        'Excédent rendu au client ' || coalesce(new.party_name, ''), 'Remboursement');
    else
      update public.suppliers set credit_amount = credit_amount - new.amount where id = new.party_id;
      perform public._caisse_set('party_credit_refunds', new.id, 'deposit', new.amount, new.date,
        'Excédent récupéré fournisseur ' || coalesce(new.party_name, ''), 'Remboursement');
    end if;
  end if;
  return coalesce(new, old);
end $$;
drop trigger if exists party_refund_trg on public.party_credit_refunds;
create trigger party_refund_trg after insert or update or delete on public.party_credit_refunds
  for each row execute function public.trg_party_refund();

create or replace function public.trg_old_debt_alloc()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public._recalc_old_debt(coalesce(new.old_debt_id, old.old_debt_id));
  return null;
end $$;
drop trigger if exists old_debt_alloc_trg on public.party_old_debt_allocations;
create trigger old_debt_alloc_trg after insert or update or delete on public.party_old_debt_allocations
  for each row execute function public.trg_old_debt_alloc();

create or replace function public.trg_old_debt_self()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.rest_amount := greatest(0, new.amount - new.paid_amount);
  return new;
end $$;
drop trigger if exists old_debt_self_trg on public.party_old_debts;
create trigger old_debt_self_trg before insert or update on public.party_old_debts
  for each row execute function public.trg_old_debt_self();

-- legacy client debts
create or replace function public.trg_client_debt_versement()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_id uuid := coalesce(new.debt_id, old.debt_id); v_paid numeric;
begin
  if tg_op = 'DELETE' then
    perform public._caisse_clear('client_debt_versements', old.id);
  else
    perform public._caisse_set('client_debt_versements', new.id, 'deposit', new.amount, new.date,
      'Versement dette ' || coalesce(new.client_name, ''), 'Versement client');
  end if;
  select coalesce(sum(amount), 0) into v_paid from public.client_debt_versements where debt_id = v_id;
  update public.client_debts set total_paid = v_paid, rest_amount = greatest(0, total_debt - v_paid) where id = v_id;
  return null;
end $$;
drop trigger if exists client_debt_versement_trg on public.client_debt_versements;
create trigger client_debt_versement_trg after insert or update or delete on public.client_debt_versements
  for each row execute function public.trg_client_debt_versement();

-- -----------------------------------------------------------------------------
--  EXPENSES & WORKERS → caisse
-- -----------------------------------------------------------------------------
create or replace function public.trg_expense()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then perform public._caisse_clear('expenses', old.id); return old; end if;
  perform public._caisse_set('expenses', new.id, 'withdrawal', new.amount, new.date,
    'Dépense : ' || new.name, coalesce(new.category_name, 'Dépense'));
  return new;
end $$;
drop trigger if exists expense_trg on public.expenses;
create trigger expense_trg after insert or update or delete on public.expenses
  for each row execute function public.trg_expense();

create or replace function public.trg_worker_money()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if tg_op = 'DELETE' then perform public._caisse_clear(tg_table_name, old.id); return old; end if;
  select full_name into v_name from public.workers where id = new.worker_id;
  perform public._caisse_set(tg_table_name, new.id, 'withdrawal', new.amount, new.date,
    case tg_table_name when 'worker_acomptes' then 'Acompte employé ' else 'Paiement employé ' end || coalesce(v_name, ''),
    case tg_table_name when 'worker_acomptes' then 'Acompte' else 'Salaire' end);
  return new;
end $$;
drop trigger if exists worker_acompte_trg on public.worker_acomptes;
create trigger worker_acompte_trg after insert or update or delete on public.worker_acomptes
  for each row execute function public.trg_worker_money();
drop trigger if exists worker_payment_trg on public.worker_payments;
create trigger worker_payment_trg after insert or update or delete on public.worker_payments
  for each row execute function public.trg_worker_money();

create or replace function public.trg_worker_payment_unmark()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.worker_overtimes set is_paid = false, paid_at = null, payment_id = null where payment_id = old.id;
  return old;
end $$;
drop trigger if exists worker_payment_unmark_trg on public.worker_payments;
create trigger worker_payment_unmark_trg before delete on public.worker_payments
  for each row execute function public.trg_worker_payment_unmark();

-- -----------------------------------------------------------------------------
--  RECYCLE BIN capture — only while recycle_delete() is running
-- -----------------------------------------------------------------------------
create or replace function public.trg_recycle_capture()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('app.recycle', true), '') <> 'on' then return old; end if;
  -- automatic caisse lines are rebuilt by their source document on restore
  if tg_table_name = 'caisse_transactions' and (to_jsonb(old) ->> 'ref_table') is not null then return old; end if;
  insert into public.recycle_bin (tx_id, table_name, row_id, data)
  values (txid_current(), tg_table_name, (to_jsonb(old) ->> 'id'), to_jsonb(old));
  return old;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'products','marques','categories','units','suppliers','clients','purchases','purchase_lines','purchase_payments',
    'sales','sale_lines','sale_payments','commands','command_items','command_payments','command_adjustments',
    'command_adjustment_lines','command_deliveries','command_delivery_items','command_delivery_consumptions',
    'productions','production_used_products','production_categories','fiche_technics','fiche_technic_lines',
    'fiche_categories','comptoir_items','destructions','client_payments','supplier_payments','party_old_debts',
    'party_old_debt_allocations','party_credit_refunds','client_debts','client_debt_versements','workers',
    'worker_acomptes','worker_absences','worker_payments','worker_overtimes','roles','expenses',
    'expense_categories','purchase_orders','purchase_order_items','caisse_transactions','caisse_categories',
    'caisse_reports','document_titles']
  loop
    execute format('drop trigger if exists zz_recycle on public.%I', t);
    execute format('create trigger zz_recycle after delete on public.%I for each row execute function public.trg_recycle_capture()', t);
  end loop;
end $$;
