-- =============================================================================
--  RPC — AUTH, ACCOUNTS, PERMISSIONS
-- =============================================================================

-- Creates a confirmed e-mail/password user directly in auth.users + auth.identities.
create or replace function public._create_auth_user(p_email text, p_password text, p_meta jsonb)
returns uuid language plpgsql security definer set search_path = public, auth, extensions as $$
declare v_id uuid := gen_random_uuid(); v_email text := lower(trim(p_email));
begin
  if exists (select 1 from auth.users where lower(email) = v_email) then
    raise exception 'Cet utilisateur existe déjà (%)', v_email;
  end if;
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, reauthentication_token, phone_change, phone_change_token
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
    crypt(p_password, gen_salt('bf')), now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
    coalesce(p_meta, '{}'::jsonb), now(), now(),
    '', '', '', '', '', '', '', ''
  );
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), v_id, v_id::text,
          jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
          'email', now(), now(), now());
  return v_id;
end $$;

create or replace function public.admin_account_exists()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where role = 'admin')
$$;

-- Login page « Créer un compte Administrateur » — only while no admin exists.
create or replace function public.create_admin_account(p_name text, p_username text, p_email text, p_password text)
returns uuid language plpgsql security definer set search_path = public, auth, extensions as $$
declare v_id uuid;
begin
  if exists (select 1 from public.profiles where role = 'admin') then
    raise exception 'Un compte administrateur existe déjà';
  end if;
  if length(coalesce(p_password, '')) < 6 then
    raise exception 'Le mot de passe doit contenir au moins 6 caractères';
  end if;
  if exists (select 1 from public.profiles where lower(username) = lower(trim(p_username))) then
    raise exception 'Cet utilisateur existe déjà';
  end if;
  v_id := public._create_auth_user(p_email, p_password,
            jsonb_build_object('full_name', p_name, 'username', p_username, 'role', 'admin'));
  insert into public.profiles (id, full_name, username, email, role, permissions)
  values (v_id, p_name, trim(p_username), lower(trim(p_email)), 'admin', '{}'::jsonb);
  return v_id;
end $$;

-- Username → e-mail for the login form (callable before sign-in).
create or replace function public.resolve_login_email(p_identifier text)
returns text language sql stable security definer set search_path = public as $$
  select email from public.profiles
  where lower(username) = lower(trim(p_identifier)) or lower(email) = lower(trim(p_identifier))
  limit 1
$$;

-- /workers — creates (or re-keys) the login of an employee.
create or replace function public.admin_create_worker_account(
  p_worker_id uuid, p_email text, p_password text, p_username text default null)
returns uuid language plpgsql security definer set search_path = public, auth, extensions as $$
declare w public.workers; v_uid uuid; v_email text := lower(trim(p_email));
        v_user text := coalesce(nullif(trim(p_username), ''), split_part(lower(trim(p_email)), '@', 1));
begin
  perform public.require_perm(array['workers:create','workers:edit']);
  select * into w from public.workers where id = p_worker_id;
  if not found then raise exception 'Employé introuvable'; end if;
  if length(coalesce(p_password, '')) < 6 then
    raise exception 'Le mot de passe doit contenir au moins 6 caractères';
  end if;

  select id into v_uid from public.profiles where worker_id = p_worker_id limit 1;
  if v_uid is null and w.auth_user_id is not null then v_uid := w.auth_user_id; end if;

  if v_uid is not null and exists (select 1 from auth.users where id = v_uid) then
    update auth.users set email = v_email, encrypted_password = crypt(p_password, gen_salt('bf')),
           email_confirmed_at = coalesce(email_confirmed_at, now()), updated_at = now()
     where id = v_uid;
    update auth.identities set identity_data = identity_data || jsonb_build_object('email', v_email)
     where user_id = v_uid and provider = 'email';
  else
    if exists (select 1 from public.profiles where lower(username) = lower(v_user)) then
      raise exception 'Ce nom d''utilisateur existe déjà';
    end if;
    v_uid := public._create_auth_user(v_email, p_password,
               jsonb_build_object('full_name', w.full_name, 'username', v_user, 'role', 'worker'));
  end if;

  insert into public.profiles (id, full_name, username, email, role, permissions, worker_id)
  values (v_uid, w.full_name, v_user, v_email, 'worker', w.permissions, w.id)
  on conflict (id) do update set full_name = excluded.full_name, username = excluded.username,
    email = excluded.email, permissions = excluded.permissions, worker_id = excluded.worker_id, is_active = true;

  update public.workers set has_account = true, email = v_email, username = v_user, auth_user_id = v_uid
  where id = p_worker_id;
  return v_uid;
end $$;

-- Permission matrix of an employee: { "sales": {"view":true,"create":true,…}, … }
create or replace function public.set_worker_permissions(p_worker_id uuid, p_permissions jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['workers:edit','workers:create']);
  update public.workers set permissions = coalesce(p_permissions, '{}'::jsonb) where id = p_worker_id;
  update public.profiles set permissions = coalesce(p_permissions, '{}'::jsonb) where worker_id = p_worker_id;
  return coalesce(p_permissions, '{}'::jsonb);
end $$;

-- deleting a worker disables his login
create or replace function public.trg_worker_delete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.profiles set is_active = false, permissions = '{}'::jsonb where worker_id = old.id;
  return old;
end $$;
drop trigger if exists worker_delete_trg on public.workers;
create trigger worker_delete_trg before delete on public.workers
  for each row execute function public.trg_worker_delete();

-- =============================================================================
--  RPC — PURCHASES
-- =============================================================================
create or replace function public._insert_purchase_lines(p_purchase uuid, p_lines jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare l jsonb; v_pid uuid;
begin
  for l in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_pid := nullif(l->>'product_id', '')::uuid;
    if v_pid is not null and not exists (select 1 from public.products where id = v_pid) then v_pid := null; end if;
    insert into public.purchase_lines (purchase_id, product_id, product_name, quantity, purchase_price,
      min_alert_quantity, unit_enabled, unit, expiration_enabled, expiration_date)
    values (p_purchase, v_pid, coalesce(l->>'product_name', ''), coalesce((l->>'quantity')::numeric, 0),
      coalesce((l->>'purchase_price')::numeric, 0), (l->>'min_alert_quantity')::numeric,
      coalesce((l->>'unit_enabled')::boolean, false), l->>'unit',
      coalesce((l->>'expiration_enabled')::boolean, false), nullif(l->>'expiration_date', '')::date);
  end loop;
end $$;

create or replace function public._purchase_set_direct_paid(p_id uuid, p_amount numeric, p_date date)
returns void language plpgsql security definer set search_path = public as $$
declare v_other numeric; v_total numeric;
begin
  delete from public.purchase_payments where purchase_id = p_id and origin is null;
  select coalesce(sum(amount), 0) into v_other from public.purchase_payments where purchase_id = p_id;
  select total_amount into v_total from public.purchases where id = p_id;
  if least(coalesce(p_amount, 0), v_total) - v_other > 0.004 then
    insert into public.purchase_payments (purchase_id, date, amount, description)
    values (p_id, coalesce(p_date, current_date), round(least(p_amount, v_total) - v_other, 2), 'Règlement à l''achat');
  end if;
end $$;

create or replace function public.create_purchase(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.purchases;
begin
  perform public.require_perm(array['purchase:create']);
  insert into public.purchases (supplier_id, date, driver_plate, bon_number, is_historical, total_amount)
  values (nullif(p_payload->>'supplier_id', '')::uuid, coalesce(nullif(p_payload->>'date', '')::date, current_date),
          p_payload->>'driver_plate', p_payload->>'bon_number',
          coalesce((p_payload->>'is_historical')::boolean, false), coalesce((p_payload->>'total_amount')::numeric, 0))
  returning * into v;
  perform public._insert_purchase_lines(v.id, p_payload->'products');
  perform public._recalc_purchase(v.id);
  perform public._purchase_set_direct_paid(v.id, coalesce((p_payload->>'paid_amount')::numeric, 0), v.date);
  select * into v from public.purchases where id = v.id;
  return to_jsonb(v);
end $$;

create or replace function public.update_purchase(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.purchases; v_lines jsonb; v_hist_changed boolean;
begin
  perform public.require_perm(array['purchase:edit']);
  select * into v from public.purchases where id = p_id;
  if not found then raise exception 'Facture d''achat introuvable'; end if;
  v_hist_changed := p_payload->>'is_historical' is not null
                    and (p_payload->>'is_historical')::boolean <> v.is_historical;

  -- lines to (re)write: the new ones, or the current ones when only « ancien achat » flips
  if p_payload ? 'products' and jsonb_typeof(p_payload->'products') = 'array' then
    v_lines := p_payload->'products';
  elsif v_hist_changed then
    select coalesce(jsonb_agg(to_jsonb(l)), '[]'::jsonb) into v_lines from public.purchase_lines l where purchase_id = p_id;
  end if;
  if v_lines is not null then delete from public.purchase_lines where purchase_id = p_id; end if;

  update public.purchases set
    supplier_id   = coalesce(nullif(p_payload->>'supplier_id', '')::uuid, supplier_id),
    date          = coalesce(nullif(p_payload->>'date', '')::date, date),
    bon_number    = coalesce(p_payload->>'bon_number', bon_number),
    driver_plate  = coalesce(p_payload->>'driver_plate', driver_plate),
    is_historical = coalesce((p_payload->>'is_historical')::boolean, is_historical),
    note          = coalesce(p_payload->>'note', note)
  where id = p_id returning * into v;

  if v_lines is not null then perform public._insert_purchase_lines(p_id, v_lines); end if;
  perform public._recalc_purchase(p_id);

  if p_payload->>'paid_amount' is not null then
    perform public._purchase_set_direct_paid(p_id, (p_payload->>'paid_amount')::numeric, v.date);
  elsif v_hist_changed then
    -- caisse lines follow the new « ancien achat » flag
    update public.purchase_payments set amount = amount where purchase_id = p_id;
  end if;
  select * into v from public.purchases where id = p_id;
  return to_jsonb(v);
end $$;

create or replace function public.pay_supplier_debt(p_purchase_id uuid, p_amount numeric, p_date date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.purchases; r public.purchase_payments;
begin
  perform public.require_perm(array['purchase:pay','suppliers:pay','purchase:edit']);
  select * into v from public.purchases where id = p_purchase_id;
  if not found then raise exception 'Facture introuvable'; end if;
  if coalesce(p_amount, 0) <= 0 then raise exception 'Montant invalide'; end if;
  insert into public.purchase_payments (purchase_id, date, amount, description)
  values (p_purchase_id, coalesce(p_date, current_date), round(least(p_amount, greatest(v.rest_amount, 0.01)), 2), 'Règlement dette')
  returning * into r;
  return to_jsonb(r);
end $$;

-- =============================================================================
--  RPC — PRODUCTION / COMPTOIR / STOCK
-- =============================================================================
create or replace function public._create_production(p jsonb)
returns public.productions language plpgsql security definer set search_path = public as $$
declare v public.productions; u jsonb; v_cost numeric := 0; v_fiche uuid;
begin
  v_fiche := nullif(p->>'fiche_technic_id', '')::uuid;
  if v_fiche is not null and not exists (select 1 from public.fiche_technics where id = v_fiche) then v_fiche := null; end if;
  select coalesce(sum(coalesce((x->>'line_cost')::numeric, 0)), 0) into v_cost
    from jsonb_array_elements(coalesce(p->'used_products', '[]'::jsonb)) x;
  insert into public.productions (name, description, date, hour, fiche_technic_id, category_id, category_name,
    total_cost, output_quantity, unit_price, total_value, sell_by_unit, sell_unit,
    has_loss, expected_quantity, loss_quantity, loss_description, loss_value, origin,
    sale_id, sale_reference, line_key)
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
    nullif(p->>'sale_id', '')::uuid, p->>'sale_reference', p->>'line_key')
  returning * into v;
  for u in select * from jsonb_array_elements(coalesce(p->'used_products', '[]'::jsonb)) loop
    insert into public.production_used_products (production_id, product_id, product_name, quantity_used,
      source_type, unit, unit_cost, line_cost)
    values (v.id, nullif(u->>'product_id', '')::uuid, coalesce(u->>'product_name', ''),
      coalesce((u->>'quantity_used')::numeric, 0), coalesce(u->>'source_type', 'stock'), u->>'unit',
      coalesce((u->>'unit_cost')::numeric, 0), coalesce((u->>'line_cost')::numeric, 0));
  end loop;
  return v;
end $$;

create or replace function public.create_production(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['production:create','pos:create']);
  return to_jsonb(public._create_production(p_payload));
end $$;

create or replace function public._transfer_to_comptoir(p_production_id uuid, p_quantity numeric)
returns public.comptoir_items language plpgsql security definer set search_path = public as $$
declare pr public.productions; v public.comptoir_items;
begin
  select * into pr from public.productions where id = p_production_id;
  if not found then raise exception 'Production introuvable'; end if;
  if p_quantity <= 0 then raise exception 'Quantité invalide'; end if;
  if pr.sent_to_comptoir + p_quantity > pr.output_quantity + 0.0005 then
    raise exception 'La quantité dépasse le reste en stock de production';
  end if;
  insert into public.comptoir_items (production_id, product_name, description, quantity, initial_quantity,
    unit_price, date, category_id, category_name, sell_by_unit, unit)
  values (pr.id, pr.name, pr.description, p_quantity, p_quantity, pr.unit_price, current_date,
    pr.category_id, pr.category_name, pr.sell_by_unit, pr.sell_unit)
  returning * into v;
  return v;
end $$;

create or replace function public.transfer_production_to_comptoir(p_production_id uuid, p_quantity numeric)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['production:edit','production:create','comptoir:create','pos:create']);
  return to_jsonb(public._transfer_to_comptoir(p_production_id, p_quantity));
end $$;

create or replace function public.destroy_comptoir_item(p_comptoir_id uuid, p_quantity numeric, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.comptoir_items; d public.destructions;
begin
  perform public.require_perm(array['comptoir:delete','comptoir:edit']);
  select * into c from public.comptoir_items where id = p_comptoir_id;
  if not found then raise exception 'Article introuvable'; end if;
  if p_quantity <= 0 or p_quantity > c.quantity + 0.0005 then raise exception 'Quantité invalide'; end if;
  update public.comptoir_items set quantity = quantity - p_quantity where id = c.id;
  insert into public.destructions (comptoir_id, product_name, quantity, value, reason, unit)
  values (c.id, c.product_name, p_quantity, round(p_quantity * c.unit_price, 2), coalesce(p_reason, ''), c.unit)
  returning * into d;
  return to_jsonb(d);
end $$;

create or replace function public.recover_destruction(p_destruction_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare d public.destructions;
begin
  perform public.require_perm(array['comptoir:edit','comptoir:delete']);
  select * into d from public.destructions where id = p_destruction_id;
  if not found then return; end if;
  if d.comptoir_id is not null then
    update public.comptoir_items set quantity = quantity + d.quantity where id = d.comptoir_id;
  end if;
  delete from public.destructions where id = d.id;
end $$;

create or replace function public.recover_destructions(p_ids uuid[])
returns void language plpgsql security definer set search_path = public as $$
declare i uuid;
begin
  foreach i in array coalesce(p_ids, '{}') loop perform public.recover_destruction(i); end loop;
end $$;

create or replace function public.delete_destructions(p_ids uuid[])
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['comptoir:delete']);
  delete from public.destructions where id = any(coalesce(p_ids, '{}'));
end $$;

create or replace function public.adjust_stock(p_product_id uuid, p_quantity numeric, p_reason text default 'manual')
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.products;
begin
  perform public.require_perm(array['stock:edit']);
  update public.products set current_quantity = current_quantity + coalesce(p_quantity, 0)
  where id = p_product_id returning * into v;
  return to_jsonb(v);
end $$;

-- Fiches techniques (recipes)
create or replace function public._fiche_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select to_jsonb(f) || jsonb_build_object('fiche_technic_lines',
         coalesce((select jsonb_agg(to_jsonb(l)) from public.fiche_technic_lines l where l.fiche_technic_id = f.id), '[]'::jsonb))
  from public.fiche_technics f where f.id = p_id
$$;

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
    total_gains = coalesce((p->>'total_gains')::numeric, 0)
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

create or replace function public.create_fiche_technic(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.require_perm(array['production:create']);
  insert into public.fiche_technics (name) values (coalesce(p_payload->>'name', 'Fiche')) returning id into v_id;
  perform public._write_fiche(v_id, p_payload);
  return public._fiche_json(v_id);
end $$;

create or replace function public.update_fiche_technic(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['production:edit']);
  perform public._write_fiche(p_id, p_payload);
  return public._fiche_json(p_id);
end $$;

create or replace function public.upsert_fiche_category(p_name text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.fiche_categories;
begin
  perform public.require_perm(array['production:create','production:edit']);
  select * into v from public.fiche_categories where lower(name) = lower(trim(p_name));
  if not found then insert into public.fiche_categories (name) values (trim(p_name)) returning * into v; end if;
  return to_jsonb(v);
end $$;
