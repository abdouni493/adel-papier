-- =============================================================================
--  IMPORT DE L'ANCIEN FICHIER EXCEL « SITUATION.xlsx »  —  00 · PRÉPARATION
-- -----------------------------------------------------------------------------
--  À exécuter dans l'éditeur SQL de Supabase, fichier par fichier, dans l'ordre :
--      00_preparation.sql → 01_clients.sql → 02_… (mouvements clients)
--      → 03_fournisseurs.sql → 99_finalisation.sql
--  (ou bien le fichier unique IMPORT_COMPLET.sql qui contient tout).
--
--  Principe : chaque document est créé par les MÊMES fonctions internes que
--  l'application (_write_command_items, _build_delivery, _create_sale,
--  _allocate_client_payment, _allocate_supplier_payment …). Les déclencheurs
--  recalculent donc les totaux, restes, numéros de BL / factures et acomptes
--  exactement comme si les documents avaient été saisis à l'écran.
--
--  · Bon de livraison Excel → commande « historique » (finalisée) + bon de
--    livraison historique + sa facture (vente historique). Historique =
--    aucun mouvement de stock, aucune production automatique, aucune caisse.
--  · Versement Excel        → versement client (client_payments) imputé sur
--    les plus anciennes factures, l'excédent devient l'acompte du client.
--  · Solde de départ        → ancienne dette (party_old_debts).
--  · Achat chez le client, remise, retour, écart de calcul du fichier
--    → versement « non encaissé » marqué [COMPENSATION ACHAT] / [REMISE] /
--      [RETOUR] / [AJUSTEMENT EXCEL] dans la note.
--  · Frais refacturés (transport, chauffeur…) ou écart positif
--    → vente historique d'une ligne.
--
--  Les versements importés sont RETIRÉS de la caisse à la fin (99) : ce sont
--  des encaissements des années passées, ils ne doivent pas gonfler la caisse.
--
--  Tout ce qui est créé est noté dans import_excel.log → 99_annulation.sql
--  permet de tout retirer proprement.
-- =============================================================================

create schema if not exists import_excel;

create table if not exists import_excel.log (
  id bigserial primary key,
  kind text not null,          -- client | supplier | command | delivery | sale | client_payment | old_debt | purchase | supplier_payment
  row_id uuid not null,
  created_at timestamptz not null default now()
);
create index if not exists import_excel_log_kind_idx on import_excel.log (kind);

-- fichiers déjà exécutés : un fichier lancé deux fois est refusé (pas de doublons)
create table if not exists import_excel.done (
  file text primary key,
  executed_at timestamptz not null default now()
);

create or replace function import_excel.start_file(p_file text)
returns void language plpgsql as $$
begin
  if exists (select 1 from import_excel.done where file = p_file) then
    raise exception 'Le fichier % a déjà été importé le % — rien n''a été refait.', p_file,
      (select to_char(executed_at, 'DD/MM/YYYY HH24:MI') from import_excel.done where file = p_file);
  end if;
  insert into import_excel.done (file) values (p_file);
end $$;

-- clé Excel (C1, C2 … / F1 …) → id dans l'application
create table if not exists import_excel.party_map (
  key text primary key,
  party_type text not null check (party_type in ('client','supplier')),
  party_id uuid not null,
  name text not null
);

create or replace function import_excel._noon(p_date date)
returns timestamptz language sql immutable as $$
  select (p_date::timestamp + interval '12 hours') at time zone 'Africa/Algiers'
$$;

create or replace function import_excel._client(p_key text)
returns public.clients language plpgsql as $$
declare c public.clients;
begin
  select cl.* into c from public.clients cl join import_excel.party_map m on m.party_id = cl.id
   where m.key = p_key and m.party_type = 'client';
  if not found then raise exception 'Client % introuvable : exécutez d''abord 01_clients.sql', p_key; end if;
  return c;
end $$;

create or replace function import_excel._supplier(p_key text)
returns public.suppliers language plpgsql as $$
declare s public.suppliers;
begin
  select su.* into s from public.suppliers su join import_excel.party_map m on m.party_id = su.id
   where m.key = p_key and m.party_type = 'supplier';
  if not found then raise exception 'Fournisseur % introuvable : exécutez d''abord 03_fournisseurs.sql', p_key; end if;
  return s;
end $$;

-- -----------------------------------------------------------------------------
--  TIERS — réutilise un client / fournisseur déjà présent (même nom), sinon le crée
-- -----------------------------------------------------------------------------
create or replace function import_excel.client(p_key text, p_name text, p_address text default '', p_note text default '')
returns uuid language plpgsql as $$
declare v uuid;
begin
  select party_id into v from import_excel.party_map where key = p_key;
  if v is not null then return v; end if;
  select id into v from public.clients where lower(trim(name)) = lower(trim(p_name)) order by created_at limit 1;
  if v is null then
    insert into public.clients (name, address, note, created_by)
    values (trim(p_name), coalesce(p_address, ''), coalesce(p_note, ''), 'import_excel')
    returning id into v;
    insert into import_excel.log (kind, row_id) values ('client', v);
  end if;
  insert into import_excel.party_map (key, party_type, party_id, name) values (p_key, 'client', v, trim(p_name));
  return v;
end $$;

create or replace function import_excel.supplier(p_key text, p_name text, p_address text default '')
returns uuid language plpgsql as $$
declare v uuid;
begin
  select party_id into v from import_excel.party_map where key = p_key;
  if v is not null then return v; end if;
  select id into v from public.suppliers where lower(trim(name)) = lower(trim(p_name)) order by created_at limit 1;
  if v is null then
    insert into public.suppliers (name, address, created_by)
    values (trim(p_name), coalesce(p_address, ''), 'import_excel')
    returning id into v;
    insert into import_excel.log (kind, row_id) values ('supplier', v);
  end if;
  insert into import_excel.party_map (key, party_type, party_id, name) values (p_key, 'supplier', v, trim(p_name));
  return v;
end $$;

-- L'acompte disponible du client règle la facture qui vient d'être créée
-- (comme « Utiliser l'acompte » dans l'application).
create or replace function import_excel._use_credit(p_sale uuid, p_date date)
returns void language plpgsql as $$
declare s public.sales; v_credit numeric; v_use numeric;
begin
  select * into s from public.sales where id = p_sale;
  select credit_amount into v_credit from public.clients where id = s.client_id;
  v_use := round(least(greatest(coalesce(v_credit, 0), 0), s.rest_amount), 2);
  if v_use > 0.004 then
    insert into public.sale_payments (sale_id, date, amount, description, origin, created_by)
    values (s.id, p_date, v_use, 'Acompte du client', 'credit', 'import_excel');
  end if;
end $$;

-- Lignes : [[désignation, quantité, prix unitaire], …]
create or replace function import_excel._fiche(p_name text)
returns uuid language sql stable as $$
  select id from public.fiche_technics
   where lower(regexp_replace(trim(name), '\s+', ' ', 'g')) = lower(regexp_replace(trim(p_name), '\s+', ' ', 'g'))
   order by created_at limit 1
$$;

-- -----------------------------------------------------------------------------
--  BON DE LIVRAISON : commande historique + BL historique + facture
-- -----------------------------------------------------------------------------
create or replace function import_excel.bl(
  p_client text, p_date date, p_bon text, p_lines jsonb,
  p_reduction numeric default 0, p_unit text default null, p_note text default null)
returns uuid language plpgsql as $$
declare c public.clients; v_cmd uuid; v_del uuid; v_sale uuid; v_items jsonb := '[]'::jsonb; l jsonb; it record;
begin
  c := import_excel._client(p_client);
  insert into public.commands (client_id, client_name, client_phone, client_address, bon_number,
    receive_date, is_historical, status, notes, created_at, created_by)
  values (c.id, c.name, c.phone, c.address, nullif(p_bon, ''), p_date, true, 'pending',
    coalesce(p_note, 'Import Excel'), import_excel._noon(p_date), 'import_excel')
  returning id into v_cmd;
  insert into import_excel.log (kind, row_id) values ('command', v_cmd);

  for l in select * from jsonb_array_elements(p_lines) loop
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'product_name', l->>0, 'quantity', (l->>1)::numeric, 'unit_price', (l->>2)::numeric,
      'fiche_technic_id', import_excel._fiche(l->>0),
      'sell_by_unit', p_unit is not null, 'sell_unit', p_unit));
  end loop;
  perform public._write_command_items(v_cmd, v_items);
  perform public._recalc_command(v_cmd);

  insert into public.command_deliveries (command_id, date, delivered_at, notes, location,
    is_historical, tva_enabled, tva_rate, source, created_at, created_by)
  values (v_cmd, p_date, import_excel._noon(p_date),
    case when nullif(p_bon, '') is not null then 'BL N° ' || p_bon || ' (Excel)' else 'BL (Excel)' end,
    c.address, true, false, 0, 'livraison', import_excel._noon(p_date), 'import_excel')
  returning id into v_del;
  insert into import_excel.log (kind, row_id) values ('delivery', v_del);

  select coalesce(jsonb_agg(jsonb_build_object('command_item_id', ci.id, 'product_name', ci.product_name,
           'quantity', ci.quantity, 'sell_unit', ci.sell_unit) order by ci.position), '[]'::jsonb)
    into v_items from public.command_items ci where ci.command_id = v_cmd;
  perform public._build_delivery(v_del, jsonb_build_object('items', v_items, 'advance_applied', 0, 'cash_paid', 0));

  select sale_id into v_sale from public.command_deliveries where id = v_del;
  insert into import_excel.log (kind, row_id) values ('sale', v_sale);
  update public.sales set created_at = import_excel._noon(p_date), created_by = 'import_excel',
         note = coalesce(p_note, 'Import Excel'), reduction = round(coalesce(p_reduction, 0), 2)
   where id = v_sale;
  if coalesce(p_reduction, 0) <> 0 then perform public._recalc_sale(v_sale); end if;
  update public.sale_lines set stock_applied = false where sale_id = v_sale;
  perform import_excel._use_credit(v_sale, p_date);
  update public.commands set status = 'finalised' where id = v_cmd;
  return v_del;
end $$;

-- -----------------------------------------------------------------------------
--  VENTE HISTORIQUE D'UNE LIGNE (frais refacturés, écart positif du fichier)
-- -----------------------------------------------------------------------------
create or replace function import_excel.charge(p_client text, p_date date, p_label text, p_amount numeric, p_note text default null)
returns uuid language plpgsql as $$
declare c public.clients; v public.sales;
begin
  c := import_excel._client(p_client);
  v := public._create_sale(jsonb_build_object(
    'client_id', c.id, 'date', p_date, 'is_historical', true, 'paid_amount', 0,
    'products', jsonb_build_array(jsonb_build_object('product_name', p_label, 'quantity', 1,
                                                     'selling_price', round(p_amount, 2), 'base_price', round(p_amount, 2)))));
  insert into import_excel.log (kind, row_id) values ('sale', v.id);
  update public.sales set created_at = import_excel._noon(p_date), created_by = 'import_excel',
         note = coalesce(p_note, 'Import Excel') where id = v.id;
  perform import_excel._use_credit(v.id, p_date);
  return v.id;
end $$;

-- -----------------------------------------------------------------------------
--  ANCIENNE DETTE (solde reporté)
-- -----------------------------------------------------------------------------
create or replace function import_excel.old_debt(p_party_type text, p_key text, p_date date, p_amount numeric, p_description text)
returns uuid language plpgsql as $$
declare v uuid; v_id uuid; v_name text;
begin
  select party_id, name into v_id, v_name from import_excel.party_map where key = p_key;
  if v_id is null then raise exception 'Tiers % introuvable', p_key; end if;
  insert into public.party_old_debts (party_type, party_id, party_name, amount, paid_amount, date, description, created_at, created_by)
  values (p_party_type, v_id, v_name, round(p_amount, 2), 0, p_date, p_description, import_excel._noon(p_date), 'import_excel')
  returning id into v;
  insert into import_excel.log (kind, row_id) values ('old_debt', v);
  return v;
end $$;

-- -----------------------------------------------------------------------------
--  VERSEMENT CLIENT (imputé : anciennes dettes → factures les plus anciennes → acompte)
-- -----------------------------------------------------------------------------
create or replace function import_excel.pay(
  p_client text, p_date date, p_amount numeric, p_method text default 'especes',
  p_notes text default '', p_cheque text default null, p_bank text default null)
returns uuid language plpgsql as $$
declare c public.clients; v uuid;
begin
  if coalesce(p_amount, 0) <= 0 then return null; end if;
  c := import_excel._client(p_client);
  insert into public.client_payments (client_id, client_name, amount, date, paid_at, notes, method,
    cheque_number, virement_number, bank_name, created_at, created_by)
  values (c.id, c.name, round(p_amount, 2), p_date, import_excel._noon(p_date), coalesce(p_notes, ''),
    coalesce(p_method, 'especes'),
    case when p_method = 'cheque' then p_cheque end,
    case when p_method = 'virement' then p_cheque end,
    p_bank, import_excel._noon(p_date), 'import_excel')
  returning id into v;
  insert into import_excel.log (kind, row_id) values ('client_payment', v);
  perform public._allocate_client_payment(v);
  update public.sale_payments set created_by = 'import_excel' where client_payment_id = v;
  return v;
end $$;

-- -----------------------------------------------------------------------------
--  FOURNISSEURS : facture d'achat historique (sans stock ni caisse) + règlements
-- -----------------------------------------------------------------------------
create or replace function import_excel.purchase(
  p_supplier text, p_date date, p_bon text, p_lines jsonb, p_tva boolean default false, p_note text default null)
returns uuid language plpgsql as $$
declare s public.suppliers; v uuid; l jsonb;
begin
  s := import_excel._supplier(p_supplier);
  insert into public.purchases (supplier_id, date, bon_number, note, is_historical, tva_enabled, tva_rate, created_at, created_by)
  values (s.id, p_date, nullif(p_bon, ''), coalesce(p_note, 'Import Excel'), true, coalesce(p_tva, false), 19,
          import_excel._noon(p_date), 'import_excel')
  returning id into v;
  insert into import_excel.log (kind, row_id) values ('purchase', v);
  for l in select * from jsonb_array_elements(p_lines) loop
    insert into public.purchase_lines (purchase_id, product_id, product_name, quantity, purchase_price)
    values (v, null, l->>0, (l->>1)::numeric, (l->>2)::numeric);
  end loop;
  perform public._recalc_purchase(v);
  return v;
end $$;

create or replace function import_excel.spay(
  p_supplier text, p_date date, p_amount numeric, p_notes text default '', p_method text default 'especes')
returns uuid language plpgsql as $$
declare s public.suppliers; v uuid;
begin
  if coalesce(p_amount, 0) <= 0 then return null; end if;
  s := import_excel._supplier(p_supplier);
  insert into public.supplier_payments (supplier_id, supplier_name, amount, date, paid_at, notes, method, created_at, created_by)
  values (s.id, s.name, round(p_amount, 2), p_date, import_excel._noon(p_date), coalesce(p_notes, ''),
          coalesce(p_method, 'especes'), import_excel._noon(p_date), 'import_excel')
  returning id into v;
  insert into import_excel.log (kind, row_id) values ('supplier_payment', v);
  perform public._allocate_supplier_payment(v);
  return v;
end $$;
