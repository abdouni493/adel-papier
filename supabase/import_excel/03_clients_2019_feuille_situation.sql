-- =============================================================================
--  IMPORT EXCEL · CLIENTS PRÉSENTS SEULEMENT DANS LA FEUILLE « Situation client » (2019)
-- =============================================================================
-- Généré automatiquement depuis SITUATION.xlsx le 2026-10-19 — ne pas modifier à la main.
begin;
set local statement_timeout = 0;
select import_excel.start_file('03_clients_2019_feuille_situation.sql');

-- ---------------------------------------------------------------------------
--  S06 · BRAHIMI ABDELKADER  (Situation client, colonnes 31-36)
--  solde de départ 0.00 DA · solde final Excel -257 120.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S06', '2019-11-11', '419', '[["BOBINES THERMIQUE 80X80", 1308.0, 110.0], ["CHEMISE DOSSIER 100F", 100.0, 490.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.pay('S06', '2019-11-11', 450000, 'especes', '(Excel Situation client L13)', null, null);

-- ---------------------------------------------------------------------------
--  S09 · REDOUANE  (Situation client, colonnes 49-54)
--  solde de départ 378 000.00 DA · solde final Excel 200 000.00 DA
-- ---------------------------------------------------------------------------
select import_excel.old_debt('client', 'S09', '2018-12-31', 378000, 'Solde antérieur reporté — ancien fichier Excel (Situation client)');
select import_excel.pay('S09', '2019-01-01', 178000, 'especes', '(Excel Situation client L10)', null, null);

-- ---------------------------------------------------------------------------
--  S10 · PAP EL AMEL (MOUSSA)  (Situation client, colonnes 55-60)
--  solde de départ 0.00 DA · solde final Excel 448 000.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S10', '2019-02-18', '25', '[["CHEMISE DOSSIER 200F", 400.0, 1000.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.bl('S10', '2019-04-28', null, '[["CHEMISE DOSSIER 200F", 50.0, 960.0]]'::jsonb, 0, null, 'Import Excel Situation client L12');

-- ---------------------------------------------------------------------------
--  S11 · EDN(MOUSSA)  (Situation client, colonnes 61-66)
--  solde de départ 0.00 DA · solde final Excel 325 485.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S11', '2018-10-10', null, '[["277kg, 282kg,282kg,292kg,267kg,272kg", 1949.0, 5.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.bl('S11', '2018-10-17', null, '[["260kg, 260kg, 260kg, 260kg, 253kg, 253kg.", 1546.0, 5.0]]'::jsonb, 0, null, 'Import Excel Situation client L12');
select import_excel.bl('S11', '2018-10-20', null, '[["367kg, 371kg, 360kg, 360kg, 365kg, 360kg,", 7653.0, 5.0]]'::jsonb, 0, null, 'Import Excel Situation client L15');
select import_excel.bl('S11', '2018-10-20', null, '[["460kg, 463kg, 459kg, 458kg, 469kg, 467kg, 470kg, 466kg, 469kg, 456kg, 448kg, 464kg.", 5549.0, 5.0]]'::jsonb, 0, null, 'Import Excel Situation client L18');
select import_excel.bl('S11', '2019-02-19', null, '[["894kg, 480kg, 494kg, 1040kg, 930kg, 950k 1020kg, 1045kg, 1067kg, 915kg, 894kg,", 13388.0, 10.0], ["506Kg, 428kg, 431kg, 437kg,", 1802.0, 10.0]]'::jsonb, 0, null, 'Import Excel Situation client L24');
select import_excel.bl('S11', '2019-03-04', null, '[["439kg, 395kg, 432kg.", 1266.0, 10.0], ["447Kg, 333kg, 462kg, 411kg,", 1653.0, 10.0]]'::jsonb, 0, null, 'Import Excel Situation client L30');
select import_excel.bl('S11', '2019-04-02', null, '[["522kg, 752kg, 735kg, 543kg ,349kg", 2901.0, 10.0], ["453kg, 437kg, 434kg, 426kg ,1440kg", 3190.0, 10.0]]'::jsonb, 0, null, 'Import Excel Situation client L35');

-- ---------------------------------------------------------------------------
--  S12 · KACIMI  (Situation client, colonnes 67-72)
--  solde de départ 0.00 DA · solde final Excel 5 000.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S12', '2019-01-01', null, '[["PRESTATION DE SERVICE", 1.0, 5000.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');

-- ---------------------------------------------------------------------------
--  S13 · IMP MARAM  (Situation client, colonnes 73-78)
--  solde de départ 0.00 DA · solde final Excel 0.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S13', '2019-02-27', '60', '[["PRESTATION DE SERVICE BOBINES L:70", 1.0, 0.0]]'::jsonb, 0, null, 'Import Excel Situation client L12');

-- ---------------------------------------------------------------------------
--  S14 · BELLOUCHE  (Situation client, colonnes 79-84)
--  solde de départ 0.00 DA · solde final Excel 156 000.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S14', '2019-02-26', '34', '[["ROULEAU FAX 25M", 1650.0, 125.0], ["RLX TIREUSE DE PLAN 150M", 20.0, 2400.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.pay('S14', '2019-03-04', 98250, 'especes', '(Excel Situation client L13)', null, null);

-- ---------------------------------------------------------------------------
--  S16 · EURL MAMI  (Situation client, colonnes 91-96)
--  solde de départ 0.00 DA · solde final Excel 36 000.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S16', '2019-09-15', '312', '[["RLX TIREUSE DE PLAN 150M", 15.0, 2400.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');

-- ---------------------------------------------------------------------------
--  S18 · DIGITAL PLUS  (Situation client, colonnes 103-108)
--  solde de départ 0.00 DA · solde final Excel 200 200.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S18', '2019-03-17', '58', '[["ETIQUETTE CDB20X40", 200.0, 175.0], ["ETIQUETTE CDB 35X45", 304.0, 175.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.bl('S18', '2019-04-23', '99', '[["ETIQUETTE CDB20X40", 640.0, 175.0]]'::jsonb, 0, null, 'Import Excel Situation client L13');

-- ---------------------------------------------------------------------------
--  S19 · BAKOUR  (Situation client, colonnes 109-114)
--  solde de départ 0.00 DA · solde final Excel 40 000.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S19', '2019-03-03', '64', '[["ROULEAU TIREUSE DE PLAN 150M", 20.0, 2450.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.pay('S19', '2019-07-25', 9000, 'cheque', 'v e r s s e m e n t (chéque) (Excel Situation client L12)', null, null);

-- ---------------------------------------------------------------------------
--  S20 · DJEMAI SLIMANE  (Situation client, colonnes 115-120)
--  solde de départ -49 000.00 DA · solde final Excel 0.00 DA
-- ---------------------------------------------------------------------------
select import_excel.pay('S20', '2019-01-16', 49000, 'especes', '[SOLDE INITIAL CRÉDITEUR] avance du client reportée — ancien fichier Excel (Situation client)');
select import_excel.bl('S20', '2019-01-17', '4', '[["ROULEAU TIREUSE DE PLAN 150M", 20.0, 2450.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.bl('S20', '2019-02-12', '19', '[["ROULEAU TIREUSE DE PLAN 150M", 40.0, 2450.0]]'::jsonb, 0, null, 'Import Excel Situation client L12');
select import_excel.pay('S20', '2019-02-12', 98000, 'especes', '(Excel Situation client L16)', null, null);
select import_excel.bl('S20', '2019-03-05', '44', '[["ROULEAU TIREUSE DE PLAN 150M", 40.0, 2450.0]]'::jsonb, 0, null, 'Import Excel Situation client L17');
select import_excel.pay('S20', '2019-03-05', 98000, 'especes', '(Excel Situation client L20)', null, null);

-- ---------------------------------------------------------------------------
--  S21 · PRIME DOC  (Situation client, colonnes 121-126)
--  solde de départ 0.00 DA · solde final Excel 165 700.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S21', '2019-05-05', null, '[["PAPIER EXTRA BLANC", 664.0, 150.0], ["PRESTATION DE SERVICE", 2420.0, 5.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.bl('S21', '2019-05-10', null, '[["Achat Page de Garde Bistol", 60000.0, 0.9]]'::jsonb, 0, null, 'Import Excel Situation client L13');

-- ---------------------------------------------------------------------------
--  S22 · BAGGOUR  (Situation client, colonnes 127-132)
--  solde de départ 0.00 DA · solde final Excel 101 075.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S22', '2019-09-15', '314', '[["CHEMISE DOSSIER 200F", 100.0, 1000.0], ["BRISTOL QUADRILL. A4", 5.0, 215.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');

-- ---------------------------------------------------------------------------
--  S23 · SARL NOURYNE  (Situation client, colonnes 133-138)
--  solde de départ -53 425.00 DA · solde final Excel 182 625.00 DA
-- ---------------------------------------------------------------------------
select import_excel.pay('S23', '2019-05-31', 53425, 'especes', '[SOLDE INITIAL CRÉDITEUR] avance du client reportée — ancien fichier Excel (Situation client)');
select import_excel.bl('S23', '2019-06-01', '140', '[["RLX TIREUSE DE PLAN 150M", 5.0, 2480.0], ["RLX TRACEUR 50M", 20.0, 870.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.bl('S23', '2019-06-02', '141', '[["POCHETTE DESSIN BLANCHE", 2500.0, 13.5]]'::jsonb, 0, null, 'Import Excel Situation client L15 · FACTURE N°11  LE 16/06/2019  Régler par chéque CPA N°');
select import_excel.bl('S23', '2019-09-03', '288', '[["POCHETTE DESSIN COULEUR", 2000.0, 17.0], ["BRISTOL A4 QUADRILL.", 300.0, 215.0]]'::jsonb, 0, null, 'Import Excel Situation client L19');
select import_excel.pay('S23', '2019-09-03', 66000, 'especes', '(Excel Situation client L22)', null, null);
select import_excel.bl('S23', '2019-12-05', '668', '[["CHEMISE DOSSIER 200", 51.0, 1000.0]]'::jsonb, 0, null, 'Import Excel Situation client L25');
select import_excel.bl('S23', '2019-12-07', null, '[["CHEMISE DOSSIER 200", 89.0, 1000.0]]'::jsonb, 0, null, 'Import Excel Situation client L29');
select import_excel.bl('S23', '2019-12-07', null, '[[",", 1.0, 0.0]]'::jsonb, 0, null, 'Import Excel Situation client L39');

-- ---------------------------------------------------------------------------
--  S24 · IMP BOUJIOTE  (Situation client, colonnes 139-144)
--  solde de départ 0.00 DA · solde final Excel 347 875.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S24', '2019-06-19', '154', '[["CHEMISE DOSSIER 200F", 80.0, 1000.0], ["CHEMISE DOSSIER 100F", 110.0, 500.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.pay('S24', '2019-06-19', 215000, 'especes', '(Excel Situation client L13)', null, null);
select import_excel.bl('S24', '2019-06-19', null, '[["SOUS CHEMISE 500F", 50.0, 925.0], ["pochette dessin blanche", 3750.0, 13.5], ["pochette dessin couleur", 3750.0, 17.0]]'::jsonb, 0, null, 'Import Excel Situation client L16');
select import_excel.bl('S24', '2019-07-10', '188', '[["Bristol A4 Uni Blanche", 300.0, 195.0]]'::jsonb, 0, null, 'Import Excel Situation client L23');
select import_excel.bl('S24', '2019-08-06', '234', '[["CHEMISE DOSSIER 200F", 20.0, 1000.0], ["SOUS CHEMISE 250F", 30.0, 462.5], ["BRISTOL QUADR. A4", 120.0, 215.0], ["POCHETTE DESSIN BLANCHE RAM 25", 3750.0, 13.5]]'::jsonb, 0, null, 'Import Excel Situation client L27');
select import_excel.pay('S24', '2019-08-06', 70000, 'especes', '(Excel Situation client L32)', null, null);
select import_excel.bl('S24', '2019-08-21', '258', '[["CHEMISE DOSSIER 200F", 60.0, 1000.0], ["BRISTOL QUADR. A2", 50.0, 580.0]]'::jsonb, 0, null, 'Import Excel Situation client L35');
select import_excel.bl('S24', '2019-08-21', null, '[["SOUS CHEMISE 250F", 30.0, 462.5], ["BRISTOL QUADR. A4", 155.0, 215.0], ["POCHETTE DESSIN BLANCHE", 500.0, 13.5], ["SOUS CHEMISE 500F", 50.0, 925.0]]'::jsonb, 0, null, 'Import Excel Situation client L42');
select import_excel.bl('S24', '2019-10-01', '346', '[["CHEMISE DOSSIER 100F", 50.0, 500.0]]'::jsonb, 0, null, 'Import Excel Situation client L49');
select import_excel.bl('S24', '2019-10-24', '390', '[["BRISTOL UNI A4 160GRS", 200.0, 195.0]]'::jsonb, 0, null, 'Import Excel Situation client L53');
select import_excel.pay('S24', '2019-10-24', 40500, 'especes', '(Excel Situation client L58)', null, null);
select import_excel.bl('S24', '2019-11-21', '447', '[["CHEMISE DOSSIER 200F", 30.0, 1000.0], ["CHEMISE DOSSIER 100F", 40.0, 500.0], ["CHEMISE DOSSIER COULEUR UNI", 40.0, 1000.0], ["SOUS CHEMISE 250F", 30.0, 462.5], ["SOUS CHEMISE 500F", 15.0, 925.0], ["BRISTOL UNI A4 160 Grs", 200.0, 195.0]]'::jsonb, 0, null, 'Import Excel Situation client L61');
select import_excel.pay('S24', '2019-11-21', 201000, 'especes', '(Excel Situation client L70)', null, null);

-- ---------------------------------------------------------------------------
--  S26 · OMAR BLIDA AL NIBRAS  (Situation client, colonnes 151-156)
--  solde de départ 0.00 DA · solde final Excel 489 965.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('S26', '2019-08-31', '281', '[["CHEMISE DOSSIER 200F", 200.0, 980.0], ["Bristol A2 QUADRILL. RAM DE 25", 200.0, 300.0]]'::jsonb, 0, null, 'Import Excel Situation client L9');
select import_excel.bl('S26', '2019-09-08', '300', '[["CHEMISE DOSSIER 100F", 50.0, 490.0], ["POCHETTE DESSIN COULEUR", 1000.0, 17.0]]'::jsonb, 0, null, 'Import Excel Situation client L13');
select import_excel.bl('S26', '2019-09-22', '323', '[["CHEMISE DOSSIER 200F", 20.0, 980.0]]'::jsonb, 0, null, 'Import Excel Situation client L18');
select import_excel.bl('S26', '2019-10-05', '350', '[["SOUS CHEMISE 250F", 200.0, 462.5], ["CHEMISE DOSSIER 100F", 100.0, 490.0]]'::jsonb, 0, null, 'Import Excel Situation client L22');
select import_excel.bl('S26', '2019-10-14', '368', '[["CHEMISE DOSSIER 200F", 18.0, 980.0], ["CHEMISE DOSSIER 100F", 150.0, 490.0], ["BRISTOL UNI A4 160 Grs", 200.0, 195.0], ["BRISTOL UNI A4 240Grs", 250.0, 220.0]]'::jsonb, 0, null, 'Import Excel Situation client L27');
select import_excel.pay('S26', '2019-10-14', 100000, 'especes', '(Excel Situation client L33)', null, null);
select import_excel.bl('S26', '2019-11-10', '415', '[["CHEMISE DOSSIER 100F", 100.0, 490.0]]'::jsonb, 0, null, 'Import Excel Situation client L40');
select import_excel.bl('S26', '2019-11-17', '433', '[["CHEMISE DOSSIER 200F", 30.0, 980.0]]'::jsonb, 0, null, 'Import Excel Situation client L44');
select import_excel.pay('S26', '2019-11-17', 100000, 'especes', '(Excel Situation client L55)', null, null);
select import_excel.bl('S26', '2019-12-05', 'RET.', '[["CHEMISE DOSSIER 250 RETOUR", 97.0, 1225.0]]'::jsonb, 0, null, 'Import Excel Situation client L58');
select import_excel.pay('S26', '2019-12-05', 118825, 'especes', '(Excel Situation client L61)', null, null);
select import_excel.bl('S26', '2019-12-05', '467', '[["SOUS CHEMISE 250F", 50.0, 462.5], ["chemise dossier 100f", 30.0, 490.0]]'::jsonb, 0, null, 'Import Excel Situation client L64');
select import_excel.pay('S26', '2019-12-05', 70000, 'especes', '(Excel Situation client L69)', null, null);

commit;
