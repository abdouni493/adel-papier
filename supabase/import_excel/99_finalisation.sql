-- =============================================================================
--  IMPORT EXCEL · 99 · FINALISATION
-- -----------------------------------------------------------------------------
--  1. Retire de la caisse les versements / règlements importés : ce sont des
--     encaissements des années passées (déjà dépensés), ils ne doivent pas
--     apparaître comme de l'argent présent dans la caisse aujourd'hui.
--     → Pour les GARDER en caisse, mettez v_keep_caisse := true ci-dessous.
--  2. Affiche le contrôle : solde net de chaque client importé.
-- =============================================================================
begin;

do $$
declare v_keep_caisse boolean := false; n int;
begin
  if not v_keep_caisse then
    delete from public.caisse_transactions t
     using import_excel.log l
     where l.kind in ('client_payment', 'supplier_payment')
       and t.ref_table = case l.kind when 'client_payment' then 'client_payments' else 'supplier_payments' end
       and t.ref_id = l.row_id;
    get diagnostics n = row_count;
    raise notice 'Caisse : % mouvement(s) importé(s) retiré(s)', n;
  end if;
end $$;

-- Numéros imprimés : les bons ont été créés client par client ; on redonne
-- aux bons importés de chaque mois (et aux factures importées de chaque année)
-- leurs numéros dans l'ordre chronologique. Seuls les numéros déjà détenus par
-- des documents importés sont redistribués : les documents saisis dans
-- l'application gardent leur numéro.
with imp as (
  select d.id, d.bl_year, d.bl_month, d.bl_number, d.date, l.id as seq
    from public.command_deliveries d join import_excel.log l on l.kind = 'delivery' and l.row_id = d.id
), nums as (
  select bl_year, bl_month, bl_number, row_number() over (partition by bl_year, bl_month order by bl_number) as rn from imp
), ord as (
  select id, bl_year, bl_month, row_number() over (partition by bl_year, bl_month order by date, seq) as rn from imp
)
update public.command_deliveries d set bl_number = n.bl_number
  from ord o join nums n on n.bl_year = o.bl_year and n.bl_month = o.bl_month and n.rn = o.rn
 where d.id = o.id and d.bl_number is distinct from n.bl_number;

with imp as (
  select s.id, s.invoice_year, s.invoice_number, s.date, l.id as seq
    from public.sales s join import_excel.log l on l.kind = 'sale' and l.row_id = s.id
), nums as (
  select invoice_year, invoice_number, row_number() over (partition by invoice_year order by invoice_number) as rn from imp
), ord as (
  select id, invoice_year, row_number() over (partition by invoice_year order by date, seq) as rn from imp
)
update public.sales s set invoice_number = n.invoice_number
  from ord o join nums n on n.invoice_year = o.invoice_year and n.rn = o.rn
 where s.id = o.id and s.invoice_number is distinct from n.invoice_number;

commit;

-- Contrôle : solde net = reste des factures + anciennes dettes − acompte
-- (même calcul que la fiche client de l'application). Comparez la colonne
-- « solde_net » avec le dernier « Reste à payer » de chaque client dans Excel.
select m.key as cle_excel, c.name as client,
       (select count(*) from public.command_deliveries d join public.commands k on k.id = d.command_id
         where k.client_id = c.id and d.is_historical) as bons_livraison,
       (select count(*) from public.client_payments p where p.client_id = c.id) as versements,
       round(coalesce((select sum(final_amount) from public.sales where client_id = c.id), 0), 2) as total_facture,
       round(coalesce((select sum(amount) from public.party_old_debts where party_type = 'client' and party_id = c.id), 0), 2) as anciennes_dettes,
       round(coalesce((select sum(amount) from public.client_payments where client_id = c.id), 0), 2) as total_verse,
       round(c.credit_amount, 2) as acompte,
       round(coalesce((select sum(rest_amount) from public.sales where client_id = c.id), 0)
           + coalesce((select sum(rest_amount) from public.party_old_debts where party_type = 'client' and party_id = c.id), 0)
           - c.credit_amount, 2) as solde_net
  from import_excel.party_map m join public.clients c on c.id = m.party_id
 where m.party_type = 'client'
 order by m.key;
