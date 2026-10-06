-- =============================================================================
--  RPC — CLIENT / SUPPLIER PAYMENTS (oldest debt first, excess → acompte)
-- =============================================================================
create or replace function public._allocate_client_payment(p_payment_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pay public.client_payments; v_left numeric; od record; s record; v_use numeric;
begin
  select * into pay from public.client_payments where id = p_payment_id;
  v_left := pay.amount;
  -- 1. old debts (ardoise d'avant le logiciel)
  for od in select * from public.party_old_debts
            where party_type = 'client' and party_id = pay.client_id and rest_amount > 0.004
            order by date, created_at loop
    exit when v_left <= 0.004;
    v_use := least(v_left, od.rest_amount);
    insert into public.party_old_debt_allocations (old_debt_id, client_payment_id, amount) values (od.id, pay.id, round(v_use, 2));
    v_left := v_left - v_use;
  end loop;
  -- 2. unpaid sales & delivery invoices
  for s in select id, rest_amount from public.sales
           where client_id = pay.client_id and rest_amount > 0.004 order by date, created_at loop
    exit when v_left <= 0.004;
    v_use := least(v_left, s.rest_amount);
    insert into public.sale_payments (sale_id, date, amount, description, origin, client_payment_id)
    values (s.id, pay.date, round(v_use, 2), 'Versement client', 'client_payment', pay.id);
    v_left := v_left - v_use;
  end loop;
  -- 3. the rest becomes the client's acompte
  v_left := round(greatest(0, v_left), 2);
  update public.client_payments set credit_part = v_left where id = pay.id;
  update public.clients set credit_amount = credit_amount + v_left where id = pay.client_id;
end $$;

create or replace function public._unallocate_client_payment(p_payment_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pay public.client_payments;
begin
  select * into pay from public.client_payments where id = p_payment_id;
  delete from public.sale_payments where client_payment_id = p_payment_id;
  delete from public.party_old_debt_allocations where client_payment_id = p_payment_id;
  update public.clients set credit_amount = credit_amount - pay.credit_part where id = pay.client_id;
  update public.client_payments set credit_part = 0 where id = p_payment_id;
end $$;

create or replace function public._allocate_supplier_payment(p_payment_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pay public.supplier_payments; v_left numeric; od record; p record; v_use numeric;
begin
  select * into pay from public.supplier_payments where id = p_payment_id;
  v_left := pay.amount;
  for od in select * from public.party_old_debts
            where party_type = 'supplier' and party_id = pay.supplier_id and rest_amount > 0.004
            order by date, created_at loop
    exit when v_left <= 0.004;
    v_use := least(v_left, od.rest_amount);
    insert into public.party_old_debt_allocations (old_debt_id, supplier_payment_id, amount) values (od.id, pay.id, round(v_use, 2));
    v_left := v_left - v_use;
  end loop;
  for p in select id, rest_amount from public.purchases
           where supplier_id = pay.supplier_id and rest_amount > 0.004 order by date, created_at loop
    exit when v_left <= 0.004;
    v_use := least(v_left, p.rest_amount);
    insert into public.purchase_payments (purchase_id, date, amount, description, origin, supplier_payment_id)
    values (p.id, pay.date, round(v_use, 2), 'Règlement fournisseur', 'supplier_payment', pay.id);
    v_left := v_left - v_use;
  end loop;
  v_left := round(greatest(0, v_left), 2);
  update public.supplier_payments set credit_part = v_left where id = pay.id;
  update public.suppliers set credit_amount = credit_amount + v_left where id = pay.supplier_id;
end $$;

create or replace function public._unallocate_supplier_payment(p_payment_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pay public.supplier_payments;
begin
  select * into pay from public.supplier_payments where id = p_payment_id;
  delete from public.purchase_payments where supplier_payment_id = p_payment_id;
  delete from public.party_old_debt_allocations where supplier_payment_id = p_payment_id;
  update public.suppliers set credit_amount = credit_amount - pay.credit_part where id = pay.supplier_id;
  update public.supplier_payments set credit_part = 0 where id = p_payment_id;
end $$;

create or replace function public.pay_client(
  p_client_id uuid, p_amount numeric, p_paid_at timestamptz, p_notes text default '',
  p_method text default 'especes', p_cheque_number text default null,
  p_virement_number text default null, p_bank_name text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.client_payments;
begin
  perform public.require_perm(array['clients:pay','clients:edit']);
  if coalesce(p_amount, 0) <= 0 then raise exception 'Montant invalide'; end if;
  insert into public.client_payments (client_id, client_name, amount, date, paid_at, notes, method,
    cheque_number, virement_number, bank_name)
  values (p_client_id, (select name from public.clients where id = p_client_id), round(p_amount, 2),
    coalesce(p_paid_at, now())::date, coalesce(p_paid_at, now()), coalesce(p_notes, ''),
    coalesce(p_method, 'especes'), p_cheque_number, p_virement_number, p_bank_name)
  returning * into r;
  perform public._allocate_client_payment(r.id);
  select * into r from public.client_payments where id = r.id;
  return to_jsonb(r);
end $$;

create or replace function public.update_client_payment(
  p_id uuid, p_amount numeric, p_paid_at timestamptz default null, p_notes text default null,
  p_method text default null, p_cheque_number text default null,
  p_virement_number text default null, p_bank_name text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.client_payments;
begin
  perform public.require_perm(array['clients:pay','clients:edit']);
  perform public._unallocate_client_payment(p_id);
  update public.client_payments set
    amount = round(p_amount, 2),
    paid_at = coalesce(p_paid_at, paid_at), date = coalesce(p_paid_at::date, date),
    notes = coalesce(p_notes, notes), method = coalesce(p_method, method),
    cheque_number = coalesce(nullif(p_cheque_number, ''), case when p_cheque_number = '' then null else cheque_number end),
    virement_number = coalesce(nullif(p_virement_number, ''), case when p_virement_number = '' then null else virement_number end),
    bank_name = coalesce(nullif(p_bank_name, ''), case when p_bank_name = '' then null else bank_name end)
  where id = p_id returning * into r;
  perform public._allocate_client_payment(p_id);
  select * into r from public.client_payments where id = p_id;
  return to_jsonb(r);
end $$;

create or replace function public.delete_client_payment(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['clients:delete','clients:pay']);
  delete from public.client_payments where id = p_id;   -- triggers reverse caisse, allocations, acompte
end $$;

create or replace function public.pay_supplier(
  p_supplier_id uuid, p_amount numeric, p_paid_at timestamptz, p_notes text default '',
  p_method text default 'especes', p_cheque_number text default null,
  p_virement_number text default null, p_bank_name text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.supplier_payments;
begin
  perform public.require_perm(array['suppliers:pay','suppliers:edit']);
  if coalesce(p_amount, 0) <= 0 then raise exception 'Montant invalide'; end if;
  insert into public.supplier_payments (supplier_id, supplier_name, amount, date, paid_at, notes, method,
    cheque_number, virement_number, bank_name)
  values (p_supplier_id, (select name from public.suppliers where id = p_supplier_id), round(p_amount, 2),
    coalesce(p_paid_at, now())::date, coalesce(p_paid_at, now()), coalesce(p_notes, ''),
    coalesce(p_method, 'especes'), p_cheque_number, p_virement_number, p_bank_name)
  returning * into r;
  perform public._allocate_supplier_payment(r.id);
  select * into r from public.supplier_payments where id = r.id;
  return to_jsonb(r);
end $$;

create or replace function public.update_supplier_payment(
  p_id uuid, p_amount numeric, p_paid_at timestamptz default null, p_notes text default null,
  p_method text default null, p_cheque_number text default null,
  p_virement_number text default null, p_bank_name text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.supplier_payments;
begin
  perform public.require_perm(array['suppliers:pay','suppliers:edit']);
  perform public._unallocate_supplier_payment(p_id);
  update public.supplier_payments set
    amount = round(p_amount, 2),
    paid_at = coalesce(p_paid_at, paid_at), date = coalesce(p_paid_at::date, date),
    notes = coalesce(p_notes, notes), method = coalesce(p_method, method),
    cheque_number = coalesce(nullif(p_cheque_number, ''), case when p_cheque_number = '' then null else cheque_number end),
    virement_number = coalesce(nullif(p_virement_number, ''), case when p_virement_number = '' then null else virement_number end),
    bank_name = coalesce(nullif(p_bank_name, ''), case when p_bank_name = '' then null else bank_name end)
  where id = p_id returning * into r;
  perform public._allocate_supplier_payment(p_id);
  select * into r from public.supplier_payments where id = p_id;
  return to_jsonb(r);
end $$;

create or replace function public.delete_supplier_payment(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['suppliers:delete','suppliers:pay']);
  delete from public.supplier_payments where id = p_id;
end $$;

-- =============================================================================
--  RPC — OLD DEBTS, REFUNDS, ACOMPTE (credit) IMPUTATIONS
-- =============================================================================
create or replace function public._party_perm(p_type text, p_action text)
returns text[] language sql immutable as $$
  select array[(case when p_type = 'supplier' then 'suppliers' else 'clients' end) || ':' || p_action,
               (case when p_type = 'supplier' then 'suppliers' else 'clients' end) || ':pay']
$$;

create or replace function public.add_party_old_debt(p_party_type text, p_party_id uuid, p_amount numeric, p_date date, p_description text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.party_old_debts;
begin
  perform public.require_perm(public._party_perm(p_party_type, 'create'));
  insert into public.party_old_debts (party_type, party_id, party_name, amount, date, description)
  values (p_party_type, p_party_id,
    case when p_party_type = 'supplier' then (select name from public.suppliers where id = p_party_id)
         else (select name from public.clients where id = p_party_id) end,
    round(p_amount, 2), coalesce(p_date, current_date), coalesce(p_description, ''))
  returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.update_party_old_debt(p_id uuid, p_amount numeric, p_date date, p_description text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.party_old_debts;
begin
  select * into r from public.party_old_debts where id = p_id;
  perform public.require_perm(public._party_perm(r.party_type, 'edit'));
  update public.party_old_debts set amount = round(p_amount, 2), date = coalesce(p_date, date),
    description = coalesce(p_description, description) where id = p_id returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.delete_party_old_debt(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r public.party_old_debts;
begin
  select * into r from public.party_old_debts where id = p_id;
  if not found then return; end if;
  perform public.require_perm(public._party_perm(r.party_type, 'delete'));
  delete from public.party_old_debts where id = p_id;
end $$;

create or replace function public.refund_party_credit(
  p_party_type text, p_party_id uuid, p_amount numeric, p_refunded_at timestamptz, p_notes text default '',
  p_method text default 'especes', p_cheque_number text default null,
  p_virement_number text default null, p_bank_name text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.party_credit_refunds;
begin
  perform public.require_perm(public._party_perm(p_party_type, 'pay'));
  if coalesce(p_amount, 0) <= 0 then raise exception 'Montant invalide'; end if;
  insert into public.party_credit_refunds (party_type, party_id, party_name, amount, date, refunded_at, notes,
    method, cheque_number, virement_number, bank_name)
  values (p_party_type, p_party_id,
    case when p_party_type = 'supplier' then (select name from public.suppliers where id = p_party_id)
         else (select name from public.clients where id = p_party_id) end,
    round(p_amount, 2), coalesce(p_refunded_at, now())::date, coalesce(p_refunded_at, now()), coalesce(p_notes, ''),
    coalesce(p_method, 'especes'), p_cheque_number, p_virement_number, p_bank_name)
  returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.update_party_refund(
  p_id uuid, p_amount numeric, p_refunded_at timestamptz, p_notes text default '',
  p_method text default 'especes', p_cheque_number text default '',
  p_virement_number text default '', p_bank_name text default '')
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.party_credit_refunds;
begin
  select * into r from public.party_credit_refunds where id = p_id;
  perform public.require_perm(public._party_perm(r.party_type, 'edit'));
  update public.party_credit_refunds set amount = round(p_amount, 2),
    refunded_at = coalesce(p_refunded_at, refunded_at), date = coalesce(p_refunded_at::date, date),
    notes = coalesce(p_notes, ''), method = coalesce(p_method, 'especes'),
    cheque_number = nullif(p_cheque_number, ''), virement_number = nullif(p_virement_number, ''),
    bank_name = nullif(p_bank_name, '')
  where id = p_id returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.delete_party_refund(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r public.party_credit_refunds;
begin
  select * into r from public.party_credit_refunds where id = p_id;
  if not found then return; end if;
  perform public.require_perm(public._party_perm(r.party_type, 'delete'));
  delete from public.party_credit_refunds where id = p_id;
end $$;

create or replace function public.apply_credit_to_sale(p_sale_id uuid, p_amount numeric default null)
returns numeric language plpgsql security definer set search_path = public as $$
declare s public.sales; v_credit numeric; v_use numeric;
begin
  perform public.require_perm(array['clients:pay','sales:pay','pos:create','sales:create']);
  select * into s from public.sales where id = p_sale_id;
  if not found or s.client_id is null then return 0; end if;
  select credit_amount into v_credit from public.clients where id = s.client_id for update;
  v_use := round(least(greatest(v_credit, 0), s.rest_amount, coalesce(p_amount, s.rest_amount)), 2);
  if v_use <= 0 then return 0; end if;
  insert into public.sale_payments (sale_id, date, amount, description, origin)
  values (s.id, current_date, v_use, 'Acompte du client', 'credit');
  return v_use;
end $$;

create or replace function public.apply_credit_to_command(p_command_id uuid, p_amount numeric default null)
returns numeric language plpgsql security definer set search_path = public as $$
declare c public.commands; v_credit numeric; v_use numeric;
begin
  perform public.require_perm(array['clients:pay','clients:edit','clients:create']);
  select * into c from public.commands where id = p_command_id;
  if not found or c.client_id is null then return 0; end if;
  select credit_amount into v_credit from public.clients where id = c.client_id for update;
  v_use := round(least(greatest(v_credit, 0), c.rest_amount, coalesce(p_amount, c.rest_amount)), 2);
  if v_use <= 0 then return 0; end if;
  update public.clients set credit_amount = credit_amount - v_use where id = c.client_id;
  update public.commands set credit_applied = credit_applied + v_use where id = c.id;
  perform public._recalc_command(c.id);
  return v_use;
end $$;

create or replace function public.apply_credit_to_purchase(p_purchase_id uuid, p_amount numeric default null)
returns numeric language plpgsql security definer set search_path = public as $$
declare p public.purchases; v_credit numeric; v_use numeric;
begin
  perform public.require_perm(array['suppliers:pay','purchase:pay','purchase:create']);
  select * into p from public.purchases where id = p_purchase_id;
  if not found or p.supplier_id is null then return 0; end if;
  select credit_amount into v_credit from public.suppliers where id = p.supplier_id for update;
  v_use := round(least(greatest(v_credit, 0), p.rest_amount, coalesce(p_amount, p.rest_amount)), 2);
  if v_use <= 0 then return 0; end if;
  insert into public.purchase_payments (purchase_id, date, amount, description, origin)
  values (p.id, current_date, v_use, 'Acompte du fournisseur', 'credit');
  return v_use;
end $$;

create or replace function public.cancel_credit_imputation(p_kind text, p_id uuid)
returns numeric language plpgsql security definer set search_path = public as $$
declare v_back numeric := 0; c public.commands;
begin
  perform public.require_perm(array['clients:pay','clients:edit']);
  if p_kind = 'sale' then
    select coalesce(sum(amount), 0) into v_back from public.sale_payments where sale_id = p_id and origin = 'credit';
    delete from public.sale_payments where sale_id = p_id and origin = 'credit';   -- trigger gives the credit back
  else
    select * into c from public.commands where id = p_id;
    v_back := coalesce(c.credit_applied, 0);
    update public.clients set credit_amount = credit_amount + v_back where id = c.client_id;
    update public.commands set credit_applied = 0 where id = p_id;
    perform public._recalc_command(p_id);
  end if;
  return v_back;
end $$;

-- Uses the party's acompte on its open documents (oldest first). Returns what is left.
create or replace function public.rebalance_party_credit(p_party_type text, p_party_id uuid)
returns numeric language plpgsql security definer set search_path = public as $$
declare d record; v_left numeric;
begin
  perform public.require_perm(public._party_perm(p_party_type, 'edit'));
  if p_party_type = 'supplier' then
    for d in select id from public.purchases where supplier_id = p_party_id and rest_amount > 0.004 order by date, created_at loop
      exit when (select credit_amount from public.suppliers where id = p_party_id) <= 0.004;
      perform public.apply_credit_to_purchase(d.id, null);
    end loop;
    select credit_amount into v_left from public.suppliers where id = p_party_id;
  else
    for d in select id from public.sales where client_id = p_party_id and rest_amount > 0.004 order by date, created_at loop
      exit when (select credit_amount from public.clients where id = p_party_id) <= 0.004;
      perform public.apply_credit_to_sale(d.id, null);
    end loop;
    select credit_amount into v_left from public.clients where id = p_party_id;
  end if;
  return coalesce(v_left, 0);
end $$;

-- « Recalculer le compte » : every document of the client is recomputed from its rows.
create or replace function public.rebuild_client_account(p_client_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r record;
begin
  perform public.require_perm(array['clients:edit']);
  for r in select id from public.commands where client_id = p_client_id loop perform public._recalc_command(r.id); end loop;
  for r in select id from public.sales where client_id = p_client_id loop perform public._recalc_sale(r.id); end loop;
  for r in select id from public.party_old_debts where party_type = 'client' and party_id = p_client_id loop
    perform public._recalc_old_debt(r.id);
  end loop;
  return jsonb_build_object('reimpute', false);
end $$;

-- Walk-in client shared by the POS.
create or replace function public.get_or_create_passager()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.clients;
begin
  perform public.require_perm(array['pos:create','sales:create','clients:create']);
  select * into v from public.clients where lower(name) like 'client passager%' order by created_at limit 1;
  if not found then insert into public.clients (name) values ('Client Passager') returning * into v; end if;
  return to_jsonb(v);
end $$;

-- Legacy « dettes clients »
create or replace function public.add_client_debt(p_client_id uuid, p_total_debt numeric, p_date date, p_description text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.client_debts; c public.clients;
begin
  perform public.require_perm(array['clients:create']);
  select * into c from public.clients where id = p_client_id;
  insert into public.client_debts (client_id, client_name, client_phone, total_debt, rest_amount, date, description)
  values (p_client_id, coalesce(c.name, ''), c.phone, round(p_total_debt, 2), round(p_total_debt, 2),
          coalesce(p_date, current_date), coalesce(p_description, ''))
  returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.add_client_debt_versement(p_debt_id uuid, p_amount numeric, p_date date, p_notes text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.client_debt_versements; d public.client_debts;
begin
  perform public.require_perm(array['clients:pay']);
  select * into d from public.client_debts where id = p_debt_id;
  if not found then raise exception 'Dette introuvable'; end if;
  insert into public.client_debt_versements (debt_id, client_id, client_name, amount, date, notes)
  values (d.id, d.client_id, d.client_name, round(p_amount, 2), coalesce(p_date, current_date), p_notes)
  returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.delete_client_debt_versement(p_versement_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['clients:delete','clients:pay']);
  delete from public.client_debt_versements where id = p_versement_id;
end $$;

-- =============================================================================
--  RPC — WORKERS
-- =============================================================================
create or replace function public.pay_worker_salary(p_worker_id uuid, p_amount numeric, p_period text default null,
  p_date date default null, p_description text default '')
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.worker_payments;
begin
  perform public.require_perm(array['workers:pay','workers:create']);
  insert into public.worker_payments (worker_id, date, period, amount, description, kind)
  values (p_worker_id, coalesce(p_date, current_date), coalesce(p_period, ''), round(p_amount, 2), coalesce(p_description, ''), 'salary')
  returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.add_worker_acompte(p_worker_id uuid, p_amount numeric, p_date date default null, p_description text default '')
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.worker_acomptes;
begin
  perform public.require_perm(array['workers:pay','workers:create']);
  insert into public.worker_acomptes (worker_id, date, amount, description)
  values (p_worker_id, coalesce(p_date, current_date), round(p_amount, 2), coalesce(p_description, ''))
  returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.add_worker_overtime(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.worker_overtimes;
begin
  perform public.require_perm(array['workers:create','workers:edit']);
  insert into public.worker_overtimes (worker_id, date, work_end_hour, work_end_minute, overtime_end_hour,
    overtime_end_minute, hours, hourly_rate, amount, description)
  values ((p_payload->>'worker_id')::uuid, coalesce(nullif(p_payload->>'date', '')::date, current_date),
    coalesce((p_payload->>'work_end_hour')::int, 0), coalesce((p_payload->>'work_end_minute')::int, 0),
    coalesce((p_payload->>'overtime_end_hour')::int, 0), coalesce((p_payload->>'overtime_end_minute')::int, 0),
    coalesce((p_payload->>'hours')::numeric, 0), coalesce((p_payload->>'hourly_rate')::numeric, 0),
    coalesce((p_payload->>'amount')::numeric, 0), coalesce(p_payload->>'description', ''))
  returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.update_worker_overtime(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.worker_overtimes;
begin
  perform public.require_perm(array['workers:edit']);
  update public.worker_overtimes set
    date = coalesce(nullif(p_payload->>'date', '')::date, date),
    work_end_hour = coalesce((p_payload->>'work_end_hour')::int, work_end_hour),
    work_end_minute = coalesce((p_payload->>'work_end_minute')::int, work_end_minute),
    overtime_end_hour = coalesce((p_payload->>'overtime_end_hour')::int, overtime_end_hour),
    overtime_end_minute = coalesce((p_payload->>'overtime_end_minute')::int, overtime_end_minute),
    hours = coalesce((p_payload->>'hours')::numeric, hours),
    hourly_rate = coalesce((p_payload->>'hourly_rate')::numeric, hourly_rate),
    amount = coalesce((p_payload->>'amount')::numeric, amount),
    description = coalesce(p_payload->>'description', description)
  where id = p_id returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.delete_worker_overtime(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['workers:delete','workers:edit']);
  delete from public.worker_overtimes where id = p_id;
end $$;

create or replace function public.pay_worker_overtimes(p_worker_id uuid, p_ids uuid[], p_date date default null, p_description text default '')
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_total numeric; r public.worker_payments;
begin
  perform public.require_perm(array['workers:pay']);
  select coalesce(sum(amount), 0) into v_total from public.worker_overtimes
  where worker_id = p_worker_id and id = any(p_ids) and not is_paid;
  if v_total <= 0 then raise exception 'Aucune heure supplémentaire à payer'; end if;
  insert into public.worker_payments (worker_id, date, period, amount, description, kind)
  values (p_worker_id, coalesce(p_date, current_date), 'Heures supplémentaires', round(v_total, 2),
          coalesce(nullif(p_description, ''), 'Paiement heures supplémentaires'), 'overtime')
  returning * into r;
  update public.worker_overtimes set is_paid = true, paid_at = coalesce(p_date, current_date), payment_id = r.id
  where worker_id = p_worker_id and id = any(p_ids) and not is_paid;
  return to_jsonb(r);
end $$;

-- =============================================================================
--  RPC — CAISSE, PURCHASE ORDERS
-- =============================================================================
create or replace function public.add_caisse_transaction(p_type text, p_amount numeric, p_description text,
  p_date date default null, p_category_id uuid default null, p_category_name text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.caisse_transactions;
begin
  perform public.require_perm(array['caisse:create']);
  insert into public.caisse_transactions (type, amount, date, description, category_id, category_name)
  values (p_type, round(p_amount, 2), coalesce(p_date, current_date), coalesce(p_description, ''), p_category_id, p_category_name)
  returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.caisse_balance()
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select initial_balance from public.caisse_settings limit 1), 0)
       + coalesce((select sum(case when type = 'deposit' then amount else -amount end) from public.caisse_transactions), 0)
$$;

create or replace function public.create_caisse_report(p_declared_amount numeric, p_description text,
  p_report_type text default 'day', p_date date default null, p_end_date date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.caisse_reports;
begin
  perform public.require_perm(array['caisse:create']);
  insert into public.caisse_reports (report_type, date, end_date, description, declared_amount)
  values (coalesce(p_report_type, 'day'), coalesce(p_date, current_date),
          case when p_report_type = 'period' then coalesce(p_end_date, p_date) end,
          coalesce(p_description, ''), round(coalesce(p_declared_amount, 0), 2))
  returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public._write_order_items(p_id uuid, p jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare i jsonb;
begin
  delete from public.purchase_order_items where order_id = p_id;
  for i in select * from jsonb_array_elements(coalesce(p->'items', '[]'::jsonb)) loop
    insert into public.purchase_order_items (order_id, product_name, description, quantity, unit)
    values (p_id, coalesce(i->>'product_name', ''), coalesce(i->>'description', ''),
            coalesce((i->>'quantity')::numeric, 0), i->>'unit');
  end loop;
end $$;

create or replace function public.create_purchase_order(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.purchase_orders;
begin
  perform public.require_perm(array['expenses:create','purchase:create']);
  insert into public.purchase_orders (date, supplier_name, notes)
  values (coalesce(nullif(p_payload->>'date', '')::date, current_date), coalesce(p_payload->>'supplier_name', ''),
          coalesce(p_payload->>'notes', ''))
  returning * into r;
  perform public._write_order_items(r.id, p_payload);
  return to_jsonb(r);
end $$;

create or replace function public.update_purchase_order(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.purchase_orders;
begin
  perform public.require_perm(array['expenses:edit','purchase:edit']);
  update public.purchase_orders set date = coalesce(nullif(p_payload->>'date', '')::date, date),
    supplier_name = coalesce(p_payload->>'supplier_name', supplier_name), notes = coalesce(p_payload->>'notes', notes)
  where id = p_id returning * into r;
  perform public._write_order_items(p_id, p_payload);
  return to_jsonb(r);
end $$;

-- =============================================================================
--  RPC — RECYCLE BIN (Paramètres › Corbeille)
-- =============================================================================
create or replace function public._table_module(p_table text)
returns text language sql immutable as $$
  select case
    when p_table in ('products','marques','categories','units') then 'stock'
    when p_table in ('purchases','purchase_lines','purchase_payments') then 'purchase'
    when p_table in ('productions','production_categories','fiche_technics','fiche_categories') then 'production'
    when p_table in ('comptoir_items','destructions') then 'comptoir'
    when p_table in ('sales','sale_lines','sale_payments') then 'sales'
    when p_table in ('clients','commands','command_items','command_payments','command_deliveries','client_debts',
                     'client_payments','party_old_debts','party_credit_refunds','command_adjustments') then 'clients'
    when p_table in ('suppliers','supplier_payments') then 'suppliers'
    when p_table in ('workers','worker_acomptes','worker_absences','worker_payments','worker_overtimes','roles') then 'workers'
    when p_table in ('expenses','expense_categories','purchase_orders') then 'expenses'
    when p_table in ('caisse_transactions','caisse_categories','caisse_reports') then 'caisse'
    else 'settings' end
$$;

create or replace function public.recycle_delete(p_table text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array[public._table_module(p_table) || ':delete']);
  if not exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = p_table) then
    raise exception 'Table inconnue: %', p_table;
  end if;
  perform set_config('app.recycle', 'on', true);
  execute format('delete from public.%I where id = $1', p_table) using p_id;
  perform set_config('app.recycle', 'off', true);
end $$;

create or replace function public.recycle_bin_list()
returns setof public.recycle_bin language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_perm(array['settings:view']);
  return query select * from public.recycle_bin order by deleted_at desc, id;
end $$;

-- Re-inserts every row of a deletion (parents first, retried until FKs resolve).
create or replace function public.recycle_restore(p_tx_id bigint)
returns integer language plpgsql security definer set search_path = public as $$
declare r record; v_done int := 0; v_progress boolean := true; v_pending int;
begin
  perform public.require_perm(array['settings:edit','settings:view']);
  create temp table if not exists _restore_ok (id bigint primary key) on commit drop;
  set constraints public.sales_delivery_fk, public.command_deliveries_sale_id_fkey deferred;
  while v_progress loop
    v_progress := false;
    for r in select * from public.recycle_bin b where tx_id = p_tx_id
             and not exists (select 1 from _restore_ok o where o.id = b.id) order by id loop
      begin
        execute format('insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)
                        on conflict (id) do nothing', r.table_name, r.table_name) using r.data;
        insert into _restore_ok values (r.id);
        v_done := v_done + 1; v_progress := true;
      exception when foreign_key_violation then null;   -- parent not back yet: next pass
      end;
    end loop;
  end loop;
  select count(*) into v_pending from public.recycle_bin b where tx_id = p_tx_id
    and not exists (select 1 from _restore_ok o where o.id = b.id);
  if v_pending > 0 then raise exception 'Restauration impossible : % élément(s) dépendent de données supprimées', v_pending; end if;
  delete from public.recycle_bin where tx_id = p_tx_id;
  return v_done;
end $$;
