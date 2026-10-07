-- =============================================================================
--  08 — SITE WEB : offres, contacts, réglages, textes, commandes web,
--       comptes de connexion des clients
-- -----------------------------------------------------------------------------
--  À exécuter UNE FOIS sur une base existante (parties 01 → 07 déjà en place).
--  Le script est rejouable : chaque objet est créé « if not exists » ou remplacé.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  1. COLONNES AJOUTÉES
-- -----------------------------------------------------------------------------
-- Présentation d'un produit (fiche technique) sur le site : nom, description,
-- prix et image propres au site (vides = ceux de la fiche) + masquage.
alter table public.fiche_technics add column if not exists web_name text;
alter table public.fiche_technics add column if not exists web_description text;
alter table public.fiche_technics add column if not exists web_price numeric(14,2);
alter table public.fiche_technics add column if not exists web_image_url text;
alter table public.fiche_technics add column if not exists web_hidden boolean not null default false;

-- Compte de connexion au site d'un client (ligne de auth.users, sans profil :
-- le client ne peut PAS ouvrir l'application de gestion).
alter table public.clients add column if not exists auth_user_id uuid references auth.users(id) on delete set null;
alter table public.clients add column if not exists login_email text;
create unique index if not exists clients_auth_user_uidx on public.clients(auth_user_id) where auth_user_id is not null;

-- -----------------------------------------------------------------------------
--  2. TABLES
-- -----------------------------------------------------------------------------
create table if not exists public.website_settings (
  id boolean primary key default true check (id),
  site_name text default '',
  site_description text default '',
  about_text text default '',
  background_url text,
  favicon_url text,
  is_public boolean not null default true,
  facebook text, instagram text, tiktok text, whatsapp text,
  phone text, phone2 text, email text, address text,
  updated_at timestamptz default now()
);
insert into public.website_settings (id) values (true) on conflict do nothing;

create table if not exists public.website_texts (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  content text not null default '',
  location text not null default 'landing' check (location in ('landing','order','contacts','offers')),
  position int not null default 0,
  created_at timestamptz not null default now()
);

create sequence if not exists public.website_order_ref_seq;
create table if not exists public.website_orders (
  id uuid primary key default gen_random_uuid(),
  reference text not null default ('WEB-' || lpad(nextval('public.website_order_ref_seq')::text, 6, '0')),
  client_id uuid references public.clients(id) on delete set null,          -- client connecté / affecté
  detected_client_id uuid references public.clients(id) on delete set null, -- trouvé par téléphone
  auth_user_id uuid,
  client_name text not null default '',
  client_phone text default '',
  client_address text default '',
  client_note text default '',
  rc text, nif text, nis text, article text,
  notes text default '',
  total_amount numeric(14,2) not null default 0,
  status text not null default 'pending' check (status in ('pending','accepted','cancelled')),
  command_id uuid references public.commands(id) on delete set null,
  cancel_reason text,
  accepted_at timestamptz,
  cancelled_at timestamptz,
  handled_by text,
  created_at timestamptz not null default now()
);
create index if not exists website_orders_client_idx on public.website_orders(client_id);
create index if not exists website_orders_status_idx on public.website_orders(status);

create table if not exists public.website_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.website_orders(id) on delete cascade,
  position int not null default 0,
  fiche_technic_id uuid references public.fiche_technics(id) on delete set null,
  product_name text not null,
  quantity numeric(14,3) not null default 0,
  unit_price numeric(14,2) not null default 0,
  total_price numeric(14,2) not null default 0,
  sell_unit text
);
create index if not exists website_order_items_order_idx on public.website_order_items(order_id);

-- -----------------------------------------------------------------------------
--  3. SÉCURITÉ (RLS)
-- -----------------------------------------------------------------------------
-- réglages + textes : lus par tout le monde (le site public), écrits par
-- l'administrateur ou un employé ayant le module « website ».
alter table public.website_settings enable row level security;
drop policy if exists ws_select on public.website_settings;
drop policy if exists ws_insert on public.website_settings;
drop policy if exists ws_update on public.website_settings;
create policy ws_select on public.website_settings for select to anon, authenticated using (true);
create policy ws_insert on public.website_settings for insert to authenticated
  with check (public.has_any_perm('{website,settings}'::text[], 'edit'));
create policy ws_update on public.website_settings for update to authenticated
  using (public.has_any_perm('{website,settings}'::text[], 'edit'))
  with check (public.has_any_perm('{website,settings}'::text[], 'edit'));

alter table public.website_texts enable row level security;
drop policy if exists wt_select on public.website_texts;
drop policy if exists wt_insert on public.website_texts;
drop policy if exists wt_update on public.website_texts;
drop policy if exists wt_delete on public.website_texts;
create policy wt_select on public.website_texts for select to anon, authenticated using (true);
create policy wt_insert on public.website_texts for insert to authenticated
  with check (public.has_any_perm('{website,settings}'::text[], 'create'));
create policy wt_update on public.website_texts for update to authenticated
  using (public.has_any_perm('{website,settings}'::text[], 'edit'))
  with check (public.has_any_perm('{website,settings}'::text[], 'edit'));
create policy wt_delete on public.website_texts for delete to authenticated
  using (public.has_any_perm('{website,settings}'::text[], 'delete'));

-- commandes web : le personnel (module website ou clients) les gère ; un client
-- connecté au site lit SES commandes. Création uniquement par website_place_order().
alter table public.website_orders enable row level security;
alter table public.website_order_items enable row level security;
drop policy if exists wo_select on public.website_orders;
drop policy if exists wo_update on public.website_orders;
drop policy if exists wo_delete on public.website_orders;
create policy wo_select on public.website_orders for select to authenticated
  using (public.can_view_any('{website,clients,dashboard,reports}'::text[]) or auth_user_id = auth.uid());
create policy wo_update on public.website_orders for update to authenticated
  using (public.has_any_perm('{website,clients}'::text[], 'edit'))
  with check (public.has_any_perm('{website,clients}'::text[], 'edit'));
create policy wo_delete on public.website_orders for delete to authenticated
  using (public.has_any_perm('{website,clients}'::text[], 'delete'));

drop policy if exists woi_select on public.website_order_items;
drop policy if exists woi_write on public.website_order_items;
create policy woi_select on public.website_order_items for select to authenticated
  using (exists (select 1 from public.website_orders o where o.id = order_id
                 and (public.can_view_any('{website,clients,dashboard,reports}'::text[]) or o.auth_user_id = auth.uid())));
create policy woi_write on public.website_order_items for all to authenticated
  using (public.has_any_perm('{website,clients}'::text[], 'edit'))
  with check (public.has_any_perm('{website,clients}'::text[], 'edit'));

grant select on public.website_settings, public.website_texts to anon;
grant select, insert, update, delete on public.website_settings, public.website_texts,
  public.website_orders, public.website_order_items to authenticated;
grant usage, select on sequence public.website_order_ref_seq to authenticated;

-- -----------------------------------------------------------------------------
--  4. FONCTIONS DU SITE (appelables sans connexion)
-- -----------------------------------------------------------------------------
create or replace function public._phone_digits(p text)
returns text language sql immutable as $$
  select right(regexp_replace(coalesce(p, ''), '\D', '', 'g'), 9)
$$;

/** Client lié au compte connecté (null pour un visiteur ou un employé). */
create or replace function public.website_current_client()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.clients where auth_user_id = auth.uid() and auth.uid() is not null limit 1
$$;

/** Client existant dont le téléphone correspond (9 derniers chiffres). */
create or replace function public._website_detect_client(p_phone text)
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.clients
  where length(public._phone_digits(p_phone)) >= 8
    and public._phone_digits(phone) = public._phone_digits(p_phone)
  order by created_at limit 1
$$;

/**
 * Tout ce que le site affiche, en un appel : réglages, société, textes,
 * catalogue et client connecté. Site privé : sans connexion, seuls les
 * réglages (nom, logo, fond) sont renvoyés pour la page de connexion.
 */
create or replace function public.website_public()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare s public.website_settings; st public.store_settings; v_client uuid; v_staff boolean; v_open boolean;
begin
  select * into s from public.website_settings where id;
  select * into st from public.store_settings where id;
  v_client := public.website_current_client();
  v_staff := auth.uid() is not null and exists (select 1 from public.profiles where id = auth.uid());
  v_open := coalesce(s.is_public, true) or v_client is not null or v_staff;
  return jsonb_build_object(
    'settings', jsonb_build_object(
      'site_name', coalesce(nullif(s.site_name, ''), st.name, ''),
      'site_description', coalesce(nullif(s.site_description, ''), st.description, ''),
      'about_text', case when v_open then coalesce(s.about_text, '') else '' end,
      'background_url', s.background_url, 'favicon_url', s.favicon_url,
      'is_public', coalesce(s.is_public, true),
      'company_name', coalesce(st.name, ''), 'logo', st.logo,
      'facebook', s.facebook, 'instagram', s.instagram, 'tiktok', s.tiktok, 'whatsapp', s.whatsapp,
      'phone', coalesce(nullif(s.phone, ''), st.phone), 'phone2', s.phone2,
      'email', coalesce(nullif(s.email, ''), st.email),
      'address', coalesce(nullif(s.address, ''), st.address)
    ),
    'open', v_open,
    'texts', case when v_open then coalesce((select jsonb_agg(jsonb_build_object(
        'id', t.id, 'title', t.title, 'content', t.content, 'location', t.location) order by t.position, t.created_at)
      from public.website_texts t), '[]'::jsonb) else '[]'::jsonb end,
    'products', case when v_open then coalesce((select jsonb_agg(jsonb_build_object(
        'id', f.id,
        'name', coalesce(nullif(f.web_name, ''), f.name),
        'description', coalesce(nullif(f.web_description, ''), f.description, ''),
        'price', coalesce(f.web_price, f.unit_price, 0),
        'image', coalesce(nullif(f.web_image_url, ''), nullif(f.image_url, '')),
        'category', coalesce(f.category_name, ''),
        'unit', coalesce(f.sell_unit, f.product_unit, '')) order by coalesce(nullif(f.web_name, ''), f.name))
      from public.fiche_technics f where not coalesce(f.web_hidden, false)), '[]'::jsonb) else '[]'::jsonb end,
    'client', case when v_client is null then null else (
      select jsonb_build_object('id', c.id, 'name', c.name, 'phone', c.phone, 'address', c.address, 'email', c.login_email)
      from public.clients c where c.id = v_client) end
  );
end $$;

/**
 * Passer une commande depuis le site. Les prix sont relus dans le catalogue
 * (jamais ceux envoyés par le navigateur).
 */
create or replace function public.website_place_order(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare s public.website_settings; v_client uuid; c public.clients; o public.website_orders;
        it jsonb; f public.fiche_technics; v_q numeric; v_price numeric; v_pos int := 0; v_total numeric := 0;
begin
  select * into s from public.website_settings where id;
  v_client := public.website_current_client();
  if not coalesce(s.is_public, true) and v_client is null then
    raise exception 'Connectez-vous pour passer une commande';
  end if;
  if jsonb_array_length(coalesce(p_payload->'items', '[]'::jsonb)) = 0 then
    raise exception 'Le panier est vide';
  end if;

  if v_client is not null then
    select * into c from public.clients where id = v_client;
    insert into public.website_orders (client_id, auth_user_id, client_name, client_phone, client_address, notes)
    values (c.id, auth.uid(), c.name, coalesce(c.phone, ''), coalesce(nullif(p_payload->>'client_address', ''), c.address, ''),
            coalesce(p_payload->>'notes', ''))
    returning * into o;
  else
    if coalesce(trim(p_payload->>'client_name'), '') = '' or coalesce(trim(p_payload->>'client_phone'), '') = '' then
      raise exception 'Nom et téléphone obligatoires';
    end if;
    insert into public.website_orders (detected_client_id, client_name, client_phone, client_address, client_note,
      rc, nif, nis, article, notes)
    values (public._website_detect_client(p_payload->>'client_phone'),
      left(trim(p_payload->>'client_name'), 200), left(trim(p_payload->>'client_phone'), 40),
      left(coalesce(p_payload->>'client_address', ''), 400), left(coalesce(p_payload->>'client_note', ''), 1000),
      nullif(p_payload->>'rc', ''), nullif(p_payload->>'nif', ''), nullif(p_payload->>'nis', ''),
      nullif(p_payload->>'article', ''), left(coalesce(p_payload->>'notes', ''), 2000))
    returning * into o;
  end if;

  for it in select * from jsonb_array_elements(p_payload->'items') loop
    select * into f from public.fiche_technics where id = (it->>'id')::uuid and not coalesce(web_hidden, false);
    if not found then continue; end if;
    v_q := greatest(coalesce((it->>'quantity')::numeric, 0), 0);
    if v_q <= 0 then continue; end if;
    v_price := coalesce(f.web_price, f.unit_price, 0);
    insert into public.website_order_items (order_id, position, fiche_technic_id, product_name, quantity, unit_price, total_price, sell_unit)
    values (o.id, v_pos, f.id, coalesce(nullif(f.web_name, ''), f.name), v_q, v_price, round(v_q * v_price, 2),
            coalesce(f.sell_unit, f.product_unit));
    v_pos := v_pos + 1; v_total := v_total + round(v_q * v_price, 2);
  end loop;
  if v_pos = 0 then raise exception 'Aucun produit valide dans le panier'; end if;
  update public.website_orders set total_amount = v_total where id = o.id;
  return jsonb_build_object('id', o.id, 'reference', o.reference, 'total', v_total);
end $$;

/** Commandes du client connecté (page « Mes commandes » du site). */
create or replace function public.website_my_orders()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', o.id, 'reference', o.reference, 'status', o.status, 'total', o.total_amount, 'created_at', o.created_at)
    order by o.created_at desc), '[]'::jsonb)
  from public.website_orders o
  where auth.uid() is not null and (o.auth_user_id = auth.uid() or o.client_id = public.website_current_client())
$$;

-- -----------------------------------------------------------------------------
--  5. FONCTIONS DE GESTION (application)
-- -----------------------------------------------------------------------------
/** Crée ou modifie l'accès au site d'un client (mot de passe vide = inchangé). */
create or replace function public.admin_set_client_account(p_client_id uuid, p_email text, p_password text default null)
returns uuid language plpgsql security definer set search_path = public, auth, extensions as $$
declare c public.clients; v_uid uuid; v_email text := lower(trim(p_email));
begin
  perform public.require_perm(array['clients:create','clients:edit','website:edit']);
  select * into c from public.clients where id = p_client_id;
  if not found then raise exception 'Client introuvable'; end if;
  if v_email is null or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'E-mail invalide'; end if;
  if exists (select 1 from auth.users where lower(email) = v_email and id is distinct from c.auth_user_id) then
    raise exception 'Cet e-mail est déjà utilisé par un autre compte';
  end if;

  if c.auth_user_id is not null and exists (select 1 from auth.users where id = c.auth_user_id) then
    v_uid := c.auth_user_id;
    update auth.users set email = v_email,
           encrypted_password = case when coalesce(p_password, '') <> '' then crypt(p_password, gen_salt('bf')) else encrypted_password end,
           email_confirmed_at = coalesce(email_confirmed_at, now()), updated_at = now()
     where id = v_uid;
    update auth.identities set identity_data = identity_data || jsonb_build_object('email', v_email)
     where user_id = v_uid and provider = 'email';
    if coalesce(p_password, '') <> '' and length(p_password) < 6 then
      raise exception 'Le mot de passe doit contenir au moins 6 caractères';
    end if;
  else
    if length(coalesce(p_password, '')) < 6 then
      raise exception 'Le mot de passe doit contenir au moins 6 caractères';
    end if;
    v_uid := public._create_auth_user(v_email, p_password,
               jsonb_build_object('full_name', c.name, 'role', 'client', 'client_id', c.id));
  end if;
  update public.clients set auth_user_id = v_uid, login_email = v_email where id = p_client_id;
  return v_uid;
end $$;

/** Supprime l'accès au site d'un client (le client lui-même est conservé). */
create or replace function public.admin_remove_client_account(p_client_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_uid uuid;
begin
  perform public.require_perm(array['clients:edit','website:edit']);
  select auth_user_id into v_uid from public.clients where id = p_client_id;
  update public.clients set auth_user_id = null, login_email = null where id = p_client_id;
  if v_uid is not null and not exists (select 1 from public.profiles where id = v_uid) then
    delete from auth.users where id = v_uid;
  end if;
end $$;

/** Modifie une commande web en attente (client + lignes). */
create or replace function public.website_update_order(p_id uuid, p_payload jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare o public.website_orders; it jsonb; v_pos int := 0; v_total numeric := 0; v_q numeric; v_p numeric;
begin
  perform public.require_perm(array['website:edit','clients:edit']);
  select * into o from public.website_orders where id = p_id;
  if not found then raise exception 'Commande introuvable'; end if;
  if o.status <> 'pending' then raise exception 'Seule une commande en attente peut être modifiée'; end if;
  update public.website_orders set
    client_id = nullif(p_payload->>'client_id', '')::uuid,
    client_name = coalesce(p_payload->>'client_name', client_name),
    client_phone = coalesce(p_payload->>'client_phone', client_phone),
    client_address = coalesce(p_payload->>'client_address', client_address),
    client_note = coalesce(p_payload->>'client_note', client_note),
    rc = nullif(p_payload->>'rc', ''), nif = nullif(p_payload->>'nif', ''),
    nis = nullif(p_payload->>'nis', ''), article = nullif(p_payload->>'article', ''),
    notes = coalesce(p_payload->>'notes', notes),
    detected_client_id = public._website_detect_client(coalesce(p_payload->>'client_phone', client_phone))
  where id = p_id;
  if p_payload ? 'items' then
    delete from public.website_order_items where order_id = p_id;
    for it in select * from jsonb_array_elements(p_payload->'items') loop
      v_q := coalesce((it->>'quantity')::numeric, 0); v_p := coalesce((it->>'unit_price')::numeric, 0);
      if v_q <= 0 then continue; end if;
      insert into public.website_order_items (order_id, position, fiche_technic_id, product_name, quantity, unit_price, total_price, sell_unit)
      values (p_id, v_pos, nullif(it->>'fiche_technic_id', '')::uuid, it->>'product_name', v_q, v_p, round(v_q * v_p, 2), it->>'sell_unit');
      v_pos := v_pos + 1; v_total := v_total + round(v_q * v_p, 2);
    end loop;
    if v_pos = 0 then raise exception 'La commande doit contenir au moins un produit'; end if;
    update public.website_orders set total_amount = v_total where id = p_id;
  end if;
end $$;

/**
 * ACCEPTER : la commande web devient une commande normale (écran Commandes),
 * donc s'ajoute aux totaux commandés par produit. Le client est, dans l'ordre :
 * celui choisi, celui du compte connecté, celui détecté par téléphone, sinon
 * il est CRÉÉ automatiquement.
 */
create or replace function public.website_accept_order(p_id uuid, p_client_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare o public.website_orders; c public.clients; v_client uuid; v_cmd jsonb; v_created boolean := false;
begin
  perform public.require_perm(array['website:edit','clients:create']);
  select * into o from public.website_orders where id = p_id for update;
  if not found then raise exception 'Commande introuvable'; end if;
  if o.status <> 'pending' then raise exception 'Cette commande a déjà été traitée'; end if;

  v_client := coalesce(p_client_id, o.client_id, o.detected_client_id, public._website_detect_client(o.client_phone));
  if v_client is not null and not exists (select 1 from public.clients where id = v_client) then v_client := null; end if;
  if v_client is null then
    insert into public.clients (name, phone, address, note, rc, nif, nis, article)
    values (o.client_name, o.client_phone, o.client_address, coalesce(nullif(o.client_note, ''), 'Créé depuis le site web'),
            o.rc, o.nif, o.nis, o.article)
    returning id into v_client;
    v_created := true;
  end if;
  select * into c from public.clients where id = v_client;

  v_cmd := public.create_command(jsonb_build_object(
    'client_id', c.id, 'client_name', c.name, 'client_phone', coalesce(nullif(c.phone, ''), o.client_phone),
    'client_address', coalesce(nullif(o.client_address, ''), c.address),
    'advance_paid', 0, 'tva_enabled', false,
    'notes', trim(both ' ' from 'Commande web ' || o.reference || ' ' || coalesce(o.notes, '')),
    'items', (select coalesce(jsonb_agg(jsonb_build_object(
        'position', i.position, 'fiche_technic_id', i.fiche_technic_id, 'product_id', i.fiche_technic_id,
        'product_name', i.product_name, 'quantity', i.quantity, 'unit_price', i.unit_price,
        'total_price', i.total_price, 'sell_by_unit', i.sell_unit is not null, 'sell_unit', i.sell_unit)
        order by i.position), '[]'::jsonb)
      from public.website_order_items i where i.order_id = o.id)
  ));

  update public.website_orders set status = 'accepted', client_id = v_client, accepted_at = now(),
    command_id = (v_cmd->>'id')::uuid, handled_by = public.current_username()
  where id = p_id;
  return jsonb_build_object('command', v_cmd, 'client_id', v_client, 'client_created', v_created);
end $$;

/** ANNULER : la commande reste dans l'historique du client avec son motif. */
create or replace function public.website_cancel_order(p_id uuid, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare o public.website_orders;
begin
  perform public.require_perm(array['website:edit','clients:edit']);
  select * into o from public.website_orders where id = p_id for update;
  if not found then raise exception 'Commande introuvable'; end if;
  if o.status = 'accepted' then raise exception 'Commande déjà acceptée : annulez-la depuis l''écran Commandes'; end if;
  update public.website_orders set status = 'cancelled', cancelled_at = now(), cancel_reason = p_reason,
    client_id = coalesce(client_id, detected_client_id), handled_by = public.current_username()
  where id = p_id;
end $$;

/** Présentation d'un produit sur le site (nom, description, prix, image, masqué). */
create or replace function public.website_update_product(p_id uuid, p_payload jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_perm(array['website:edit','production:edit']);
  update public.fiche_technics set
    web_name = case when p_payload ? 'web_name' then nullif(trim(p_payload->>'web_name'), '') else web_name end,
    web_description = case when p_payload ? 'web_description' then nullif(p_payload->>'web_description', '') else web_description end,
    web_price = case when p_payload ? 'web_price' then nullif(p_payload->>'web_price', '')::numeric else web_price end,
    web_image_url = case when p_payload ? 'web_image_url' then nullif(p_payload->>'web_image_url', '') else web_image_url end,
    web_hidden = case when p_payload ? 'web_hidden' then coalesce((p_payload->>'web_hidden')::boolean, false) else web_hidden end
  where id = p_id;
  if not found then raise exception 'Produit introuvable'; end if;
end $$;

grant execute on function public.website_public() to anon, authenticated;
grant execute on function public.website_place_order(jsonb) to anon, authenticated;
grant execute on function public.website_my_orders() to authenticated;
grant execute on function public.website_current_client() to anon, authenticated;
grant execute on function public.admin_set_client_account(uuid, text, text) to authenticated;
grant execute on function public.admin_remove_client_account(uuid) to authenticated;
grant execute on function public.website_update_order(uuid, jsonb) to authenticated;
grant execute on function public.website_accept_order(uuid, uuid) to authenticated;
grant execute on function public.website_cancel_order(uuid, text) to authenticated;
grant execute on function public.website_update_product(uuid, jsonb) to authenticated;
revoke execute on function public._website_detect_client(text) from public, anon, authenticated;

-- Le module « website » apparaît dans la matrice des permissions des employés ;
-- l'administrateur y a accès d'office (is_admin()).

notify pgrst, 'reload schema';
