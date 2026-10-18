-- =============================================================================
--  IMPORT EXCEL · ANNULATION
-- -----------------------------------------------------------------------------
--  Retire TOUT ce que l'import a créé (d'après import_excel.log) puis supprime
--  le schéma import_excel. Les clients / fournisseurs qui existaient déjà avant
--  l'import ne sont pas supprimés (seuls leurs documents importés le sont).
--  Les déclencheurs de l'application remettent acomptes et caisse en ordre.
-- =============================================================================
begin;

-- ⚠ SÉCURITÉ : ce fichier SUPPRIME tout l'import. Il ne fait rien tant que la
-- ligne ci-dessous n'est pas décommentée (retirez les deux tirets « -- »).
-- set local import_excel.confirmer_annulation = 'OUI';

do $$ begin
  if coalesce(current_setting('import_excel.confirmer_annulation', true), '') <> 'OUI' then
    raise exception 'Annulation NON effectuée : ce fichier supprime tout l''import. Pour confirmer, décommentez la ligne « set local import_excel.confirmer_annulation = ''OUI''; » en haut du fichier.';
  end if;
end $$;

-- versements d'abord : leurs imputations sur les factures disparaissent avec eux
delete from public.client_payments where id in (select row_id from import_excel.log where kind = 'client_payment');
delete from public.supplier_payments where id in (select row_id from import_excel.log where kind = 'supplier_payment');
-- factures d'abord (leurs bons de livraison suivent en cascade), puis les commandes
delete from public.sales where id in (select row_id from import_excel.log where kind = 'sale');
delete from public.command_deliveries where id in (select row_id from import_excel.log where kind = 'delivery');
delete from public.commands where id in (select row_id from import_excel.log where kind = 'command');
delete from public.purchases where id in (select row_id from import_excel.log where kind = 'purchase');
delete from public.party_old_debts where id in (select row_id from import_excel.log where kind = 'old_debt');
delete from public.clients where id in (select row_id from import_excel.log where kind = 'client');
delete from public.suppliers where id in (select row_id from import_excel.log where kind = 'supplier');

drop schema import_excel cascade;

commit;
