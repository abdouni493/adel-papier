-- =============================================================================
--  12 — ACHATS : TVA, FRAIS DE DOUANE, TRANSITAIRE, FRAIS SUPPLÉMENTAIRES, DEVISE
-- -----------------------------------------------------------------------------
--  À exécuter APRÈS la partie 11 (ré-exécutable sans risque).
--
--  1. purchases : TVA optionnelle (taux modifiable) — la facture fournisseur
--     devient TTC (total_amount = (marchandise − retours) × (1 + taux)).
--  2. purchases : frais de douane, frais de transitaire, montant en euro et
--     taux de change (informatifs, hors dette fournisseur).
--  3. purchase_fee_categories + purchase_extra_fees : frais supplémentaires
--     ventilés par catégorie.
--  4. set_purchase_costs() : enregistre TVA / frais d'une facture.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  1-2. COLONNES
-- -----------------------------------------------------------------------------
alter table public.purchases add column if not exists tva_enabled boolean not null default false;
alter table public.purchases add column if not exists tva_rate numeric(6,2) not null default 19;
alter table public.purchases add column if not exists total_ht numeric(14,2) not null default 0;
alter table public.purchases add column if not exists tva_amount numeric(14,2) not null default 0;
alter table public.purchases add column if not exists customs_fees numeric(14,2) not null default 0;
alter table public.purchases add column if not exists transit_fees numeric(14,2) not null default 0;
alter table public.purchases add column if not exists extra_fees_total numeric(14,2) not null default 0;
alter table public.purchases add column if not exists euro_amount numeric(14,2);
alter table public.purchases add column if not exists exchange_rate numeric(14,4);

-- -----------------------------------------------------------------------------
--  3. FRAIS SUPPLÉMENTAIRES
-- -----------------------------------------------------------------------------
create table if not exists public.purchase_fee_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz default now()
);

create table if not exists public.purchase_extra_fees (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  category_id uuid references public.purchase_fee_categories(id) on delete set null,
  category_name text not null,
  amount numeric(14,2) not null default 0,
  created_at timestamptz default now()
);
create index if not exists purchase_extra_fees_purchase_idx on public.purchase_extra_fees (purchase_id);

alter table public.purchase_fee_categories enable row level security;
alter table public.purchase_extra_fees enable row level security;
do $$
declare t text;
begin
  foreach t in array array['purchase_fee_categories', 'purchase_extra_fees'] loop
    execute format('drop policy if exists p_select on public.%I', t);
    execute format('drop policy if exists p_insert on public.%I', t);
    execute format('drop policy if exists p_update on public.%I', t);
    execute format('drop policy if exists p_delete on public.%I', t);
    execute format('create policy p_select on public.%I for select to authenticated using (public.can_view_any(''{purchase,suppliers,stock,caisse,dashboard,reports}''::text[]))', t);
    execute format('create policy p_insert on public.%I for insert to authenticated with check (public.has_any_perm(''{purchase}''::text[], ''create''))', t);
    execute format('create policy p_update on public.%I for update to authenticated using (public.has_any_perm(''{purchase}''::text[], ''edit'')) with check (public.has_any_perm(''{purchase}''::text[], ''edit''))', t);
    execute format('create policy p_delete on public.%I for delete to authenticated using (public.has_any_perm(''{purchase}''::text[], ''delete''))', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
--  RECALCUL : la TVA s'applique à la marchandise nette des retours
-- -----------------------------------------------------------------------------
create or replace function public._recalc_purchase(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_total numeric; v_paid numeric; v_alloc numeric; v_has boolean; p public.purchases;
        v_ret numeric := 0; v_refund numeric := 0; v_ht numeric; v_tva numeric := 0;
begin
  if position(p_id::text in coalesce(current_setting('app.deleting_doc', true), '')) > 0 then return; end if;
  select * into p from public.purchases where id = p_id;
  if not found then return; end if;
  select exists(select 1 from public.purchase_lines where purchase_id = p_id),
         coalesce(sum(quantity * purchase_price), 0)
    into v_has, v_total from public.purchase_lines where purchase_id = p_id;
  if to_regclass('public.purchase_returns') is not null then
    select coalesce(sum(total_amount), 0), coalesce(sum(refund_amount), 0)
      into v_ret, v_refund from public.purchase_returns where purchase_id = p_id;
  end if;
  if not v_has then v_total := coalesce(nullif(p.total_ht, 0), p.total_amount) + v_ret; end if;
  v_ht := round(greatest(0, v_total - v_ret), 2);
  if p.tva_enabled then v_tva := round(v_ht * coalesce(p.tva_rate, 0) / 100, 2); end if;
  v_total := v_ht + v_tva;
  select coalesce(sum(amount), 0), coalesce(sum(amount) filter (where origin = 'credit'), 0)
    into v_paid, v_alloc from public.purchase_payments where purchase_id = p_id;
  v_paid := greatest(0, v_paid - v_refund);
  update public.purchases set
    total_ht = v_ht, tva_amount = v_tva,
    total_amount = round(v_total, 2), paid_amount = v_paid, allocated_amount = v_alloc,
    rest_amount = greatest(0, round(v_total, 2) - v_paid)
  where id = p_id;
end $$;

-- -----------------------------------------------------------------------------
--  4. set_purchase_costs(p_id, p_payload)
--     { tva_enabled, tva_rate, customs_fees, transit_fees, euro_amount,
--       exchange_rate, extra_fees: [{category_id, category_name, amount}],
--       paid_amount?, date? }  — paid_amount présent => règlement refait sur
--     le nouveau total TTC.
-- -----------------------------------------------------------------------------
create or replace function public.set_purchase_costs(p_id uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.purchases; f jsonb; v_cat uuid; v_name text; v_extra numeric := 0;
begin
  perform public.require_perm(array['purchase:create', 'purchase:edit']);
  select * into v from public.purchases where id = p_id;
  if not found then raise exception 'Facture d''achat introuvable'; end if;

  delete from public.purchase_extra_fees where purchase_id = p_id;
  for f in select * from jsonb_array_elements(coalesce(p_payload->'extra_fees', '[]'::jsonb)) loop
    v_name := nullif(trim(f->>'category_name'), '');
    continue when v_name is null or coalesce((f->>'amount')::numeric, 0) = 0;
    v_cat := nullif(f->>'category_id', '')::uuid;
    if v_cat is null then
      insert into public.purchase_fee_categories (name) values (v_name)
        on conflict (name) do update set name = excluded.name returning id into v_cat;
    end if;
    insert into public.purchase_extra_fees (purchase_id, category_id, category_name, amount)
    values (p_id, v_cat, v_name, round((f->>'amount')::numeric, 2));
    v_extra := v_extra + round((f->>'amount')::numeric, 2);
  end loop;

  update public.purchases set
    tva_enabled   = coalesce((p_payload->>'tva_enabled')::boolean, false),
    tva_rate      = coalesce((p_payload->>'tva_rate')::numeric, tva_rate),
    customs_fees  = coalesce((p_payload->>'customs_fees')::numeric, 0),
    transit_fees  = coalesce((p_payload->>'transit_fees')::numeric, 0),
    euro_amount   = nullif(p_payload->>'euro_amount', '')::numeric,
    exchange_rate = nullif(p_payload->>'exchange_rate', '')::numeric,
    extra_fees_total = v_extra
  where id = p_id;

  perform public._recalc_purchase(p_id);
  if p_payload ? 'paid_amount' and p_payload->>'paid_amount' is not null then
    perform public._purchase_set_direct_paid(p_id, (p_payload->>'paid_amount')::numeric,
      coalesce(nullif(p_payload->>'date', '')::date, v.date));
    perform public._recalc_purchase(p_id);
  end if;
  select * into v from public.purchases where id = p_id;
  return to_jsonb(v);
end $$;
grant execute on function public.set_purchase_costs(uuid, jsonb) to authenticated;

-- les anciennes factures : total_ht = total_amount
update public.purchases set total_ht = total_amount where total_ht = 0 and not tva_enabled;

notify pgrst, 'reload schema';
