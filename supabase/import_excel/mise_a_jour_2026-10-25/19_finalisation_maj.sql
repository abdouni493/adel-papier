-- =============================================================================
--  MISE À JOUR IMPORT EXCEL · 19 · FINALISATION
-- -----------------------------------------------------------------------------
--  1. Retire de la caisse les versements importés (anciens et nouveaux) :
--     → pour les GARDER en caisse, mettez v_keep_caisse := true ci-dessous.
--  2. Renumérote par date les BL / factures importés.
--  3. Contrôle : solde de chaque client de Feuil1 comparé au dernier
--     « Reste à payer » du NOUVEAU fichier Excel (colonne « ok »).
-- =============================================================================
begin;

do $$ begin
  if to_regclass('import_excel.done') is null
     or not exists (select 1 from import_excel.done where file = 'maj_2026-10-25/12_nouveaux_mouvements.sql') then
    raise exception 'Exécutez d''abord 10_preparation_maj.sql, 11_corrections.sql et 12_nouveaux_mouvements.sql.';
  end if;
end $$;

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

-- Numéros des BL importés, mois par mois, dans l'ordre des dates :
--  · mois sans aucun BL saisi dans l'application → 1, 2, 3 … (aucun trou) ;
--  · mois qui contient aussi des BL de l'application → seuls les numéros déjà
--    détenus par des BL importés sont redistribués (ceux de l'application ne bougent pas).
with imp as (
  select d.id, d.bl_year, d.bl_month, d.bl_number, d.date, l.id as seq,
         exists (select 1 from public.command_deliveries x
                  where x.bl_year = d.bl_year and x.bl_month = d.bl_month
                    and not exists (select 1 from import_excel.log l2 where l2.kind = 'delivery' and l2.row_id = x.id)) as shared
    from public.command_deliveries d join import_excel.log l on l.kind = 'delivery' and l.row_id = d.id
), nums as (
  select bl_year, bl_month, bl_number, row_number() over (partition by bl_year, bl_month order by bl_number) as rn from imp
), ord as (
  select id, bl_year, bl_month, shared, row_number() over (partition by bl_year, bl_month order by date, seq) as rn from imp
)
update public.command_deliveries d
   set bl_number = case when o.shared then n.bl_number else o.rn end
  from ord o join nums n on n.bl_year = o.bl_year and n.bl_month = o.bl_month and n.rn = o.rn
 where d.id = o.id and d.bl_number is distinct from (case when o.shared then n.bl_number else o.rn end);

with imp as (
  select s.id, s.invoice_year, s.invoice_number, s.date, l.id as seq,
         exists (select 1 from public.sales x
                  where x.invoice_year = s.invoice_year
                    and not exists (select 1 from import_excel.log l2 where l2.kind = 'sale' and l2.row_id = x.id)) as shared
    from public.sales s join import_excel.log l on l.kind = 'sale' and l.row_id = s.id
), nums as (
  select invoice_year, invoice_number, row_number() over (partition by invoice_year order by invoice_number) as rn from imp
), ord as (
  select id, invoice_year, shared, row_number() over (partition by invoice_year order by date, seq) as rn from imp
)
update public.sales s
   set invoice_number = case when o.shared then n.invoice_number else o.rn end
  from ord o join nums n on n.invoice_year = o.invoice_year and n.rn = o.rn
 where s.id = o.id and s.invoice_number is distinct from (case when o.shared then n.invoice_number else o.rn end);

commit;

-- Contrôle : « solde_app » doit être égal à « solde_excel » (ok = true).
-- Un écart sur un client veut dire qu'un document a été saisi ou modifié pour
-- lui dans l'application depuis l'import — ce n'est pas forcément une erreur.
with expected(key, solde_excel) as (values
  ('C01', 727276.50),
  ('C02', 111217.00),
  ('C03', -1599186.12),
  ('C04', 552000.00),
  ('C05', 396500.01),
  ('C06', 1593917.01),
  ('C07', 1435928.39),
  ('C08', 1366313.76),
  ('C09', 16065.00),
  ('C10', 84981.30),
  ('C11', 268893.86),
  ('C12', 174000.00),
  ('C13', 61837.00),
  ('C14', 257600.00),
  ('C15', 2089521.59),
  ('C16', -0.00),
  ('C17', 0.00),
  ('C18', 0.00),
  ('C19', 251750.00),
  ('C20', 235638.00),
  ('C21', 223161.09),
  ('C22', 475240.00),
  ('C23', 0.00),
  ('C24', 813637.80),
  ('C25', 0.00),
  ('C26', 632789.00),
  ('C27', 602560.00),
  ('C28', 320000.00),
  ('C29', 915635.00),
  ('C30', 5400.00),
  ('C31', 288100.00),
  ('C32', -403249.07),
  ('C33', 232640.00),
  ('C34', 130000.00),
  ('C35', 77065.00),
  ('C36', 0.00)
)
select e.key as cle_excel, c.name as client,
       round(coalesce((select sum(rest_amount) from public.sales where client_id = c.id), 0)
           + coalesce((select sum(rest_amount) from public.party_old_debts where party_type = 'client' and party_id = c.id), 0)
           - c.credit_amount, 2) as solde_app,
       e.solde_excel,
       abs(round(coalesce((select sum(rest_amount) from public.sales where client_id = c.id), 0)
           + coalesce((select sum(rest_amount) from public.party_old_debts where party_type = 'client' and party_id = c.id), 0)
           - c.credit_amount, 2) - e.solde_excel) <= 1 as ok
  from expected e
  join import_excel.party_map m on m.key = e.key
  join public.clients c on c.id = m.party_id
 order by ok, e.key;
