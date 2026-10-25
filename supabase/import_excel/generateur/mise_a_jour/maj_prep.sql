-- =============================================================================
--  MISE À JOUR DE L'IMPORT EXCEL — 25/10/2026  ·  10 · PRÉPARATION
-- -----------------------------------------------------------------------------
--  Fichier source : « Copie de SITUATION.xlsx » (nouvelle version du fichier).
--  À exécuter SEULEMENT sur une base où le PREMIER import (00 → 04 + 99 du
--  dossier import_excel) a déjà été fait. Ce dossier n'ajoute que la
--  DIFFÉRENCE entre l'ancien et le nouveau fichier :
--      · les nouveaux bons de livraison et versements ;
--      · 4 corrections faites dans Excel sur des lignes déjà importées ;
--      · la suppression de 10 bons vides (0 DA) créés par le premier import
--        à partir de signes parasites du fichier (« * », « 0 µ », « 2025 »…).
--  Ordre : 10 → 11 → 12 → 19.
-- =============================================================================

do $$ begin
  if to_regclass('import_excel.done') is null then
    raise exception 'Le premier import n''a pas été trouvé dans cette base (schéma import_excel absent). Exécutez d''abord le dossier import_excel (00 → 04 puis 99_finalisation), puis cette mise à jour.';
  end if;
  if (select count(*) from import_excel.done where file in (
        '01_clients.sql', '02_clients_mouvements_partie1.sql', '02_clients_mouvements_partie2.sql',
        '02_clients_mouvements_partie3.sql', '02_clients_mouvements_partie4.sql',
        '02_clients_mouvements_partie5.sql', '03_clients_2019_feuille_situation.sql')) < 7 then
    raise exception 'Le premier import est incomplet : exécutez d''abord tous les fichiers 01 → 04 du dossier import_excel. Fichiers déjà faits : %',
      (select string_agg(file, ', ' order by file) from import_excel.done);
  end if;
end $$;

-- le bon importé depuis la ligne p_row de la feuille (d'après la note « Import Excel <feuille> L<ligne> »)
create or replace function import_excel._find_bl(p_client text, p_row int, p_sheet text default 'Feuil1')
returns uuid language plpgsql as $$
declare v uuid; n int;
begin
  select count(*), min(c.id::text)::uuid into n, v
    from public.commands c
    join import_excel.party_map m on m.party_id = c.client_id and m.key = p_client
    join import_excel.log l on l.kind = 'command' and l.row_id = c.id
   where c.notes ~ ('^Import Excel ' || p_sheet || ' L' || p_row || '( |$)');
  if n <> 1 then
    raise exception 'Bon Excel % ligne % du client % : % bon(s) trouvé(s) au lieu de 1', p_sheet, p_row, p_client, n;
  end if;
  return v;
end $$;

-- supprime un bon importé (commande + BL + facture) ; les versements qui le
-- payaient redeviennent l'acompte du client, comme dans l'application
create or replace function import_excel.del_bl(p_client text, p_row int, p_sheet text default 'Feuil1')
returns void language plpgsql as $$
declare v_cmd uuid; d record;
begin
  v_cmd := import_excel._find_bl(p_client, p_row, p_sheet);
  for d in select id, sale_id from public.command_deliveries where command_id = v_cmd loop
    perform public._release_sale_allocations(d.sale_id);
    delete from public.sales where id = d.sale_id;
    delete from public.command_deliveries where id = d.id;
  end loop;
  delete from public.commands where id = v_cmd;
end $$;

-- refait un bon importé avec les valeurs corrigées du nouveau fichier
create or replace function import_excel.redo_bl(
  p_client text, p_row int, p_date date, p_bon text, p_lines jsonb,
  p_reduction numeric default 0, p_unit text default null, p_note text default null)
returns uuid language plpgsql as $$
begin
  perform import_excel.del_bl(p_client, p_row, 'Feuil1');
  return import_excel.bl(p_client, p_date, p_bon, p_lines, p_reduction, p_unit, p_note);
end $$;

-- corrige la note d'un versement importé (le montant ne change pas)
create or replace function import_excel.fix_pay_note(p_client text, p_row int, p_notes text)
returns void language plpgsql as $$
declare n int;
begin
  update public.client_payments p set notes = p_notes
    from import_excel.party_map m
   where m.key = p_client and p.client_id = m.party_id
     and p.id in (select row_id from import_excel.log where kind = 'client_payment')
     and p.notes like '%(Excel Feuil1 L' || p_row || ')%';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Versement Excel ligne % du client % : % trouvé(s) au lieu de 1', p_row, p_client, n; end if;
end $$;
