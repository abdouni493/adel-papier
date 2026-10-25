-- =============================================================================
--  MISE À JOUR IMPORT EXCEL · 11 · CORRECTIONS DES LIGNES DÉJÀ IMPORTÉES
-- =============================================================================
-- Généré le 2026-10-25 à partir de « Copie de SITUATION.xlsx » — ne pas modifier à la main.
begin;
set local statement_timeout = 0;
select import_excel.start_file('maj_2026-10-25/11_corrections.sql');

-- C01 · PAP EL BASMALA
select import_excel.del_bl('C01', 1982);  -- bon vide 0 DA (signe parasite dans Excel)

-- C02 · PAP EL AMEL (AEK)
select import_excel.del_bl('C02', 1056);  -- bon vide 0 DA (signe parasite dans Excel)

-- C04 · PAP YAHIA (kayed)
select import_excel.redo_bl('C04', 1559, '2026-10-11', null, '[["ROULEAU TRACEUR 50 M", 100.0, 860.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1559');
select import_excel.del_bl('C04', 3428);  -- bon vide 0 DA (signe parasite dans Excel)

-- C06 · NACER  BOUHADJAM
select import_excel.del_bl('C06', 1818);  -- bon vide 0 DA (signe parasite dans Excel)

-- C07 · YA PAP
select import_excel.del_bl('C07', 2197);  -- bon vide 0 DA (signe parasite dans Excel)

-- C11 · BOUHADJAM
select import_excel.redo_bl('C11', 839, '2026-10-11', null, '[["ROULEAU TIREUSE DE PLAN 50 M", 40.0, 850.0], ["SOUS CHEMISE 250 F", 50.0, 630.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L839');

-- C12 · DAR EL AMINE
select import_excel.redo_bl('C12', 778, '2026-10-06', null, '[["sous chemise 250 f", 300.0, 580.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L778');

-- C14 · MAK INFO
select import_excel.del_bl('C14', 1264);  -- bon vide 0 DA (signe parasite dans Excel)

-- C15 · DISPLAY
select import_excel.fix_pay_note('C15', 1731, 'CPA 9448151 — Facture N° 96 (Excel Feuil1 L1731)');

-- C18 · SARL SBM
select import_excel.del_bl('C18', 218);  -- bon vide 0 DA (signe parasite dans Excel)

-- C19 · Pap El Hana
select import_excel.del_bl('C19', 735);  -- bon vide 0 DA (signe parasite dans Excel)

-- C23 · SARL TAZIRI ALGER
select import_excel.del_bl('C23', 188);  -- bon vide 0 DA (signe parasite dans Excel)

-- S23
select import_excel.del_bl('S23', 39, 'Situation client');  -- bon vide 0 DA

commit;
