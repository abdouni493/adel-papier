-- =============================================================================
--  IMPORT EXCEL · OPTIONNEL — HISTORIQUE 2019 DE TAZIRI ET AL SULTANE
-- =============================================================================
-- Généré automatiquement depuis SITUATION.xlsx le 2026-10-19 — ne pas modifier à la main.
begin;
set local statement_timeout = 0;
select import_excel.start_file('05_optionnel_2019_TAZIRI_AL_SULTANE.sql');

-- ATTENTION : ces mouvements de 2019 concernent des clients qui existent aussi dans
-- Feuil1, mais Feuil1 démarre leur compte à 0. Si vous exécutez ce fichier, leur solde
-- dans l'application AUGMENTERA du solde 2019 ci-dessous. À n'exécuter que si ces
-- montants n'ont jamais été réglés.

-- ---------------------------------------------------------------------------
--  C17 · TAZIRI PAP  (Situation client, colonnes 145-150)
--  solde de départ 0.00 DA · solde final Excel 496 100.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C17', '2019-08-21', '255', '[["Bristol A2 QUADRILL.", 500.0, 565.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.bl('C17', '2019-08-28', '275', '[["POCHETTE DESSIN BLANCHE", 15400.0, 13.5], ["Bristol A2 QUADRILL.", 1780.0, 565.0]]'::jsonb, 0, null, 'Import Excel Situation client L12');
select import_excel.pay('C17', '2019-08-28', 1000000, 'especes', '(Excel Situation client L18)', null, null);

-- ---------------------------------------------------------------------------
--  C13 · AL SULTANE  (Situation client, colonnes 157-162)
--  solde de départ 605 000.00 DA · solde final Excel 153 721.25 DA
-- ---------------------------------------------------------------------------
select import_excel.old_debt('client', 'C13', '2019-08-20', 605000, 'Solde antérieur reporté — ancien fichier Excel (Situation client)');
select import_excel.pay('C13', '2019-08-21', 300028.75, 'cheque', 'VERSSEMENT PAR CHEQUE CPA N° 9622578 (Excel Situation client L12)', '9622578', 'CPA');
select import_excel.bl('C13', '2019-08-21', null, '[["Bristol A4 QUADRILL", 500.0, 215.0]]'::jsonb, 0, null, 'Import Excel Situation client L15');
select import_excel.bl('C13', '2019-08-28', '276', '[["POCHETTE DESSIN COULEUR", 2500.0, 16.5]]'::jsonb, 0, null, 'Import Excel Situation client L20');
select import_excel.pay('C13', '2019-08-28', 300000, 'especes', '(Excel Situation client L38)', null, null);

commit;
