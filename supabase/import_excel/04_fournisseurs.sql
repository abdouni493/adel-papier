-- =============================================================================
--  IMPORT EXCEL · FOURNISSEURS, FACTURES D'ACHAT ET RÈGLEMENTS (feuille ACHAT)
-- =============================================================================
-- Généré automatiquement depuis SITUATION.xlsx le 2026-10-19 — ne pas modifier à la main.
begin;
set local statement_timeout = 0;
select import_excel.start_file('04_fournisseurs.sql');

-- ---------------------------------------------------------------------------
--  F01 · P&C MAN
-- ---------------------------------------------------------------------------
select import_excel.supplier('F01', 'P&C MAN');
select import_excel.old_debt('supplier', 'F01', '2019-07-14', 134586, 'Solde initial reporté — ancien fichier Excel (ACHAT)');
select import_excel.purchase('F01', '2019-07-15', null, '[["PAPIER OFFSET BLANC 80Gr LZ 93 SOPROC.", 1773.0, 149.58], ["PAPIER OFFSET BLANC 80Gr LZ 93 MONDI.", 863.0, 136.97]]'::jsonb, true, 'Import Excel ACHAT L9 · TVA 19%');
select import_excel.spay('F01', '2019-07-15', 500000, 'Versement (Excel ACHAT L14)');
select import_excel.purchase('F01', '2019-08-08', null, '[["PAPIER OFFSET BLANC 80Gr LZ 93 SOPROC.", 2332.0, 142.86]]'::jsonb, true, 'Import Excel ACHAT L17 · TVA 19%');
select import_excel.spay('F01', '2019-08-08', 396447.929, 'Versement (Excel ACHAT L22)');
select import_excel.purchase('F01', '2019-09-17', null, '[["PAPIER OFFSET BLANC 80Gr LZ 93 SOPROC.", 2917.0, 142.86]]'::jsonb, true, 'Import Excel ACHAT L25 · TVA 19%');
select import_excel.purchase('F01', '2019-10-31', null, '[["PAPIER OFFSET BLANC 80Gr LZ 93 SOPROC.", 2943.0, 124.37]]'::jsonb, true, 'Import Excel ACHAT L33 · TVA 19%');
select import_excel.spay('F01', '2019-10-31', 495899.918, 'Versement (Excel ACHAT L38)');
select import_excel.purchase('F01', '2019-11-13', null, '[["PAPIER OFFSET BLANC 80Gr LZ 93 SOPROC.", 3530.0, 121.85]]'::jsonb, true, 'Import Excel ACHAT L41 · TVA 19%');
select import_excel.spay('F01', '2019-11-13', 500000, 'Versement (Excel ACHAT L46)');
select import_excel.purchase('F01', '2019-11-27', '7022', '[["PAPIER OFFSET BLANC 80Gr LZ 93 SOPROC.", 2935.0, 121.85]]'::jsonb, true, 'Import Excel ACHAT L49 · TVA 19%');
select import_excel.spay('F01', '2019-11-27', 447420.178, 'Versement (Excel ACHAT L54)');
select import_excel.purchase('F01', '2019-12-09', '7022', '[["PAPIER OFFSET BLANC 80Gr LZ 93 SOPORC.", 3530.0, 121.85]]'::jsonb, true, 'Import Excel ACHAT L57 · TVA 19%');
select import_excel.spay('F01', '2019-12-09', 200000, 'Versement (Excel ACHAT L62)');
select import_excel.purchase('F01', '2019-12-18', '7022', '[["PAPIER OFFSET BLANC 80Gr LZ 93 SOPORC.", 3540.0, 121.85]]'::jsonb, true, 'Import Excel ACHAT L65 · TVA 19%');
select import_excel.spay('F01', '2019-12-18', 513305.31, 'Versement (Excel ACHAT L70)');
select import_excel.purchase('F01', '2019-12-19', '7022', '[["PAPIER OFFSET BLANC 80Gr LZ 93 SOPORC.", 2334.0, 121.85]]'::jsonb, true, 'Import Excel ACHAT L73 · TVA 19%');
select import_excel.spay('F01', '2019-12-19', 500000, 'Versement (Excel ACHAT L94)');

-- ---------------------------------------------------------------------------
--  F02 · GHOBRINI
-- ---------------------------------------------------------------------------
select import_excel.supplier('F02', 'GHOBRINI');
select import_excel.purchase('F02', '2019-02-28', null, '[["PAPIER OFFSET BLANC 80Gr LZ 92", 10192.0, 148.0], ["PAPIER OFFSETBLEU 80Gr LZ 90", 10156.0, 115.0]]'::jsonb, false, 'Import Excel ACHAT L7');
select import_excel.spay('F02', '2019-02-28', 676356, 'Versement (Excel ACHAT L13)');
select import_excel.spay('F02', '2019-03-07', 500000, 'Versement (Excel ACHAT L15)');
select import_excel.spay('F02', '2019-03-18', 300000, 'Versement (Excel ACHAT L18)');
select import_excel.spay('F02', '2019-03-28', 1200000, 'Versement (Excel ACHAT L21)');

-- ---------------------------------------------------------------------------
--  F03 · SOFIANE
-- ---------------------------------------------------------------------------
select import_excel.supplier('F03', 'SOFIANE');
select import_excel.purchase('F03', '2019-03-31', null, '[["bobines extra blanc 604kg,596kg,604kg ,604kg,606kg,600kg", 3614.0, 135.0]]'::jsonb, false, 'Import Excel ACHAT L7');
select import_excel.spay('F03', '2019-03-31', 400000, 'Versement (Excel ACHAT L12)');
select import_excel.purchase('F03', '2019-04-01', null, '[["bobine extra blanc lz 92", 598.0, 110.0], ["bobine extra blanc lz 92", 1200.0, 135.0]]'::jsonb, false, 'Import Excel ACHAT L15');
select import_excel.purchase('F03', '2019-05-12', null, '[["bob, extra blanc lz 92 (545k-582-594)", 1721.0, 0.0], ["bobine extra blanc lz 92(mouill.)", 1843.0, 0.0]]'::jsonb, false, 'Import Excel ACHAT L23');
select import_excel.purchase('F03', '2019-05-26', null, '[["bob, extra blanc (598kg-596kg-598kg)", 1792.0, 0.0]]'::jsonb, false, 'Import Excel ACHAT L31');
select import_excel.purchase('F03', '2019-05-28', null, '[["bob, extra blanc", 2400.0, 115.0], ["Bobines papier coucher", 1107.0, 115.0]]'::jsonb, false, 'Import Excel ACHAT L39');

-- ---------------------------------------------------------------------------
--  F04 · EURL MAMI
-- ---------------------------------------------------------------------------
select import_excel.supplier('F04', 'EURL MAMI');
select import_excel.purchase('F04', '2019-01-24', null, '[["CAISSE 150M (P.U Excel 57)", 200.0, 0.0], ["caisse 50M (P.U Excel 59)", 500.0, 0.0]]'::jsonb, false, 'Import Excel ACHAT L7');
select import_excel.purchase('F04', '2019-03-04', null, '[["CAISSE ROULEAUX PAPIER", 750.0, 0.0]]'::jsonb, false, 'Import Excel ACHAT L15');
select import_excel.purchase('F04', '2019-03-09', null, '[["CAISSE 150M", 1175.0, 0.0], ["caisse 50M", 750.0, 0.0]]'::jsonb, false, 'Import Excel ACHAT L23');
select import_excel.purchase('F04', '2019-03-13', null, '[["CAISSE 150M", 1125.0, 0.0], ["caisse 50M", 500.0, 0.0]]'::jsonb, false, 'Import Excel ACHAT L31');
select import_excel.purchase('F04', '2019-03-14', null, '[["carton rouleaux papier", 1825.0, 0.0]]'::jsonb, false, 'Import Excel ACHAT L39');
select import_excel.purchase('F04', '2019-05-13', null, '[["02 bobines extra blanc(594kg+582kg)", 1176.0, 0.0], ["bobines (prestation de service)", 1.0, 348600.0]]'::jsonb, false, 'Import Excel ACHAT L47');

-- ---------------------------------------------------------------------------
--  F05 · SOCIETE DES ARTES GRAPHIQUE
-- ---------------------------------------------------------------------------
select import_excel.supplier('F05', 'SOCIETE DES ARTES GRAPHIQUE');
select import_excel.purchase('F05', '2019-04-11', null, '[["PAPIER OFFSET COULEUR", 2378.0, 170.0], ["PAPIER OFFSET NOIR", 556.0, 0.0]]'::jsonb, false, 'Import Excel ACHAT L7');
select import_excel.spay('F05', '2019-04-11', 700000, 'Versement (Excel ACHAT L13)');
select import_excel.purchase('F05', '2019-04-15', null, '[["PAPIER OFFSET COULEUR", 2357.0, 170.0], ["PAPIER OFFSET NOIR", 585.0, 0.0]]'::jsonb, false, 'Import Excel ACHAT L16');
select import_excel.purchase('F05', '2019-04-16', null, '[["PAPIER OFFSET COULEUR", 2210.0, 170.0], ["PAPIER OFFSET NOIR", 595.0, 0.0]]'::jsonb, false, 'Import Excel ACHAT L25');
select import_excel.purchase('F05', '2019-04-18', null, '[["PAPIER OFFSET COULEU", 1257.0, 170.0]]'::jsonb, false, 'Import Excel ACHAT L34');
select import_excel.spay('F05', '2019-04-22', 300000, 'Versement (Excel ACHAT L42)');
select import_excel.purchase('F05', '2019-04-24', null, '[["PAPIER OFFSET COULEU verre", 374.0, 170.0]]'::jsonb, false, 'Import Excel ACHAT L45');

-- ---------------------------------------------------------------------------
--  F06 · ENVELOPPE DU NORD
-- ---------------------------------------------------------------------------
select import_excel.supplier('F06', 'ENVELOPPE DU NORD');
select import_excel.purchase('F06', '2019-04-15', null, '[["ENV. BLANCHE F26 A/A", 5000.0, 8.1]]'::jsonb, false, 'Import Excel ACHAT L7');
select import_excel.purchase('F06', '2019-04-15', null, '[["POCHETTE CRAFT F24 AUTO-ADHESIVES AVEC IMPRESSION", 1000.0, 0.0], ["POCHETTE CRAFT F26 AUTO-ADHESIVES AVEC IMPRESSION", 500.0, 0.0], ["POCHETTE CRAFT F16 AUTO-ADHESIVES AVEC IMPRESSION", 500.0, 0.0], ["POCHETTE BLANCHE F10 AUTO- ADHESIVES AVEC IMPRESSION", 500.0, 0.0], ["POCHETTE CRAFT F10 A.DH. IMP.", 500.0, 0.0], ["Montant du bon (prix non détaillés dans Excel)", 1.0, 17000.0]]'::jsonb, false, 'Import Excel ACHAT L16');

-- ---------------------------------------------------------------------------
--  F07 · imdb
-- ---------------------------------------------------------------------------
select import_excel.supplier('F07', 'imdb');
select import_excel.purchase('F07', '2019-02-07', null, '[["BL N°162 PAGE DE GARDE", 50200.0, 1.0]]'::jsonb, false, 'Import Excel ACHAT L7');
select import_excel.purchase('F07', '2019-02-19', null, '[["BL N°220 PAGE DE GARDE", 14000.0, 1.0]]'::jsonb, false, 'Import Excel ACHAT L14');
select import_excel.purchase('F07', '2019-03-04', null, '[["Mondrain 57", 10500.0, 1.6]]'::jsonb, false, 'Import Excel ACHAT L21');
select import_excel.purchase('F07', '2019-06-09', null, '[["BL N° 541 PAGE DE GARDE", 63420.0, 1.0]]'::jsonb, false, 'Import Excel ACHAT L28');
select import_excel.purchase('F07', '2019-06-20', null, '[["BL N° 573 PAGE DE GARDE", 67800.0, 1.0]]'::jsonb, false, 'Import Excel ACHAT L35');
select import_excel.purchase('F07', '2019-06-25', null, '[["BL N° 573 PAGE DE GARDE", 67800.0, 1.0], ["BOBINES THERMIQUE 80X80", 160.0, 130.0]]'::jsonb, false, 'Import Excel ACHAT L42');


commit;
