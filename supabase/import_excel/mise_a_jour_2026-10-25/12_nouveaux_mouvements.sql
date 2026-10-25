-- =============================================================================
--  MISE À JOUR IMPORT EXCEL · 12 · NOUVEAUX BONS DE LIVRAISON ET VERSEMENTS
-- =============================================================================
-- Généré le 2026-10-25 à partir de « Copie de SITUATION.xlsx » — ne pas modifier à la main.
begin;
set local statement_timeout = 0;
select import_excel.start_file('maj_2026-10-25/12_nouveaux_mouvements.sql');

-- ---------------------------------------------------------------------------
--  C01 · PAP EL BASMALA — 2 nouveau(x) mouvement(s) · solde Excel 994 776.50 → 727 276.50 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C01', '2026-10-19', null, '[["SOUS CHEMISE 250 F", 50.0, 650.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L2432');
select import_excel.pay('C01', '2026-08-20', 300000, 'especes', '(Excel Feuil1 L2439)', null, null);

-- ---------------------------------------------------------------------------
--  C02 · PAP EL AMEL (AEK) — 1 nouveau(x) mouvement(s) · solde Excel 74 517.00 → 111 217.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C02', '2026-10-20', null, '[["ROULEAU TABLE TRACANTE 50 M", 20.0, 900.0], ["ROULEAU THERMIQUE 80X75", 100.0, 155.0], ["SOUS CHEMISE 250 F", 5.0, 640.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L695');

-- ---------------------------------------------------------------------------
--  C03 · DAR EL KALEM — 3 nouveau(x) mouvement(s) · solde Excel 1 347 991.20 → -1 599 186.12 DA
-- ---------------------------------------------------------------------------
select import_excel.pay('C03', '2026-10-15', 1347000.03, 'cheque', 'BDL1932150 — VERSEMENT PAR cheque — Facture N° 99 (Excel Feuil1 L4750)', '1932150', 'BDL');
select import_excel.pay('C03', '2026-10-15', 1000000.79, 'cheque', 'AGB7190021 — VERSEMENT PAR cheque — Facture N° 100 (Excel Feuil1 L4752)', '7190021', 'AGB');
select import_excel.pay('C03', '2026-10-07', 600176.5, 'virement', 'VERSEMENT PAR — Facture N° 94 (Excel Feuil1 L4754)', null, null);

-- ---------------------------------------------------------------------------
--  C04 · PAP YAHIA (kayed) — 3 nouveau(x) mouvement(s) · solde Excel 151 320.00 → 552 000.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C04', '2026-10-13', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 50.0, 2600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1567');
select import_excel.pay('C04', '2026-10-13', 281320, 'especes', '(Excel Feuil1 L1575) · date Excel corrigée (2022-01-19)', null, null);
select import_excel.bl('C04', '2026-10-15', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 400.0, 1380.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1577');

-- ---------------------------------------------------------------------------
--  C06 · NACER  BOUHADJAM — 3 nouveau(x) mouvement(s) · solde Excel 1 671 917.01 → 1 593 917.01 DA
-- ---------------------------------------------------------------------------
select import_excel.pay('C06', '2026-10-14', 400000, 'especes', '(Excel Feuil1 L3315)', null, null);
select import_excel.bl('C06', '2026-10-20', null, '[["SOUS CHEMISE 250 F", 840.0, 580.0], ["sous chemise 500 f", 130.0, 1160.0], ["rouleau table tracante 50 m", 40.0, 850.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L3317');
select import_excel.pay('C06', '2026-10-20', 350000, 'especes', '(Excel Feuil1 L3325)', null, null);

-- ---------------------------------------------------------------------------
--  C07 · YA PAP — 3 nouveau(x) mouvement(s) · solde Excel 1 979 928.39 → 1 435 928.39 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C07', '2026-10-12', null, '[["SOUS CHEMISE 250 F", 260.0, 580.0], ["POCHETTE DESSIN COULEUR", 1350.0, 22.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1510');
select import_excel.pay('C07', '2026-10-12', 1000000, 'especes', '(Excel Feuil1 L1517)', null, null);
select import_excel.bl('C07', '2026-10-13', null, '[["SOUS CHEMISE 250 F", 80.0, 580.0], ["POCHETTE DESSIN COULEUR", 1550.0, 22.0], ["CHEMISE DOSSIER 100 F", 300.0, 650.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1519');

-- ---------------------------------------------------------------------------
--  C08 · PAP SLIMANE — 2 nouveau(x) mouvement(s) · solde Excel 1 197 813.76 → 1 366 313.76 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C08', '2026-10-13', null, '[["pochette dessin couleur", 1750.0, 22.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1980');
select import_excel.bl('C08', '2026-10-19', null, '[["CHEMISE DOSSIER 100 F", 100.0, 680.0], ["Sous Chemise 250 f", 100.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1987');

-- ---------------------------------------------------------------------------
--  C11 · BOUHADJAM — 3 nouveau(x) mouvement(s) · solde Excel 591 393.86 → 268 893.86 DA
-- ---------------------------------------------------------------------------
select import_excel.pay('C11', '2026-10-11', 250000, 'especes', '(Excel Feuil1 L846)', null, null);
select import_excel.bl('C11', '2026-10-19', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 50.0, 2550.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L848');
select import_excel.pay('C11', '2026-10-19', 200000, 'especes', '(Excel Feuil1 L855)', null, null);

-- ---------------------------------------------------------------------------
--  C13 · AL SULTANE NASSIM — 1 nouveau(x) mouvement(s) · solde Excel 261 837.00 → 61 837.00 DA
-- ---------------------------------------------------------------------------
select import_excel.pay('C13', '2026-09-23', 200000, 'especes', '(Excel Feuil1 L658) · date Excel corrigée (2026-05-13)', null, null);

-- ---------------------------------------------------------------------------
--  C14 · MAK INFO — 2 nouveau(x) mouvement(s) · solde Excel 31 500.00 → 257 600.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C14', '2026-10-13', null, '[["Chemise dossier 250 f", 160.0, 740.0], ["sous chemise 250 f", 150.0, 650.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L261');
select import_excel.bl('C14', '2026-10-19', null, '[["Chemise dossier 250 f", 5.0, 740.0], ["sous chemise 250 f", 10.0, 650.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L267');

-- ---------------------------------------------------------------------------
--  C15 · DISPLAY — 6 nouveau(x) mouvement(s) · solde Excel 2 248 021.59 → 2 089 521.59 DA
-- ---------------------------------------------------------------------------
select import_excel.pay('C15', '2026-10-12', 330000, 'especes', 'Versement EN ESPECE (Excel Feuil1 L1783)', null, null);
select import_excel.pay('C15', '2026-10-13', 70000, 'especes', 'Versement EN ESPECE (Excel Feuil1 L1785)', null, null);
select import_excel.pay('C15', '2026-09-13', 450000, 'cheque', 'cpa n°9448284 (Excel Feuil1 L1787)', '9448284', 'CPA');
select import_excel.bl('C15', '2026-10-18', null, '[["sous chemise 250 f", 300.0, 590.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1789');
select import_excel.bl('C15', '2026-10-19', null, '[["CHEMISE DOSSIER 100 F", 400.0, 730.0], ["ROULEAU TIREUSE DE PLAN 150 M", 15.0, 2700.0], ["ROULEAU TABLE TRACANTE 50 M", 10.0, 900.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1796');
select import_excel.bl('C15', '2026-10-22', null, '[["CHEMISE DOSSIER 100 F", 50.0, 730.0], ["ROULEAU TIREUSE DE PLAN 150 M", 25.0, 2700.0], ["ROULEAU TABLE TRACANTE 50 M", 10.0, 900.0], ["Article (désignation non saisie)", 300.0, 200.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1803');

-- ---------------------------------------------------------------------------
--  C16 · PAP EL REDA — 7 nouveau(x) mouvement(s) · solde Excel 174 000.00 → -0.00 DA
-- ---------------------------------------------------------------------------
select import_excel.pay('C16', '2026-10-08', 174000, 'especes', '(Excel Feuil1 L4226)', null, null);
select import_excel.bl('C16', '2026-10-12', null, '[["sous chemise 250 f", 200.0, 580.0], ["CHEMISE DOSIER 100 F", 140.0, 670.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L4228');
select import_excel.bl('C16', '2026-10-13', null, '[["sous chemise 250 f", 200.0, 580.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L4235');
select import_excel.bl('C16', '2026-10-21', null, '[["sous chemise 250 f", 300.0, 580.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L4242');
select import_excel.bl('C16', '2026-10-22', null, '[["chemise dossier 100", 150.0, 670.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L4249');
select import_excel.pay('C16', '2026-10-21', 550791.5, 'especes', '(Excel Feuil1 L4256)', null, null);
select import_excel.pay('C16', '2026-10-22', 49508.5, 'especes', '(Excel Feuil1 L4258)', null, null);

-- ---------------------------------------------------------------------------
--  C19 · Pap El Hana — 2 nouveau(x) mouvement(s) · solde Excel 237 750.00 → 251 750.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C19', '2026-10-19', null, '[["SOUS CHEMISE 250 F", 100.0, 640.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1096');
select import_excel.pay('C19', '2026-10-19', 50000, 'especes', '(Excel Feuil1 L1102)', null, null);

-- ---------------------------------------------------------------------------
--  C21 · UNIVERSAL — 3 nouveau(x) mouvement(s) · solde Excel 423 662.01 → 223 161.09 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C21', '2026-10-15', null, '[["RUBAN THERMIQUE 57X30", 2700.0, 25.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L1204');
select import_excel.pay('C21', '2026-10-15', 68000, 'especes', '(Excel Feuil1 L1211)', null, null);
select import_excel.pay('C21', '2026-10-12', 200000.92, 'virement', 'Facture N° 82 (Excel Feuil1 L1213)', null, null);

-- ---------------------------------------------------------------------------
--  C24 · TECH ZONE — 1 nouveau(x) mouvement(s) · solde Excel 805 237.80 → 813 637.80 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C24', '2026-10-19', null, '[["ROULEAU THERMIQUE 57X30", 300.0, 28.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L584');

-- ---------------------------------------------------------------------------
--  C31 · TPV — 3 nouveau(x) mouvement(s) · solde Excel 0.00 → 288 100.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C31', '2026-10-24', null, '[["ruban thermique 80x75", 5000.0, 128.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L52');
select import_excel.pay('C31', '2026-10-20', 640000, 'especes', '(Excel Feuil1 L57)', null, null);
select import_excel.bl('C31', '2026-10-20', null, '[["ROULEAU ETIQUETTE 35X45", 1000.0, 195.0], ["ROULEAU THERMIQUE ECG 80X40", 980.0, 95.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L59');

-- ---------------------------------------------------------------------------
--  C33 · WAHAB — 1 nouveau(x) mouvement(s) · solde Excel 500 310.00 → 232 640.00 DA
-- ---------------------------------------------------------------------------
select import_excel.pay('C33', '2026-06-03', 267670, 'especes', '(Excel Feuil1 L63)', null, null);

-- ---------------------------------------------------------------------------
--  C35 · OUSSALMA — 3 nouveau(x) mouvement(s) · solde Excel 26 085.00 → 77 065.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C35', '2026-10-19', null, '[["etiqeutte 100x150", 320.0, 495.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L158');
select import_excel.bl('C35', '2026-10-20', null, '[["ROULEAU ETIQUETTE 100X150 300 etq", 384.0, 495.0], ["ROULEAU ETIQUETTE 100x150 (400 etq)", 130.0, 650.0], ["ROULEAU ETIQUETTE 35x45", 1000.0, 195.0], ["rouleau tHERMIQUE80x40 ecg", 5480.0, 100.0], ["rouleau thermique 80x75", 1500.0, 150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L165');
select import_excel.pay('C35', '2026-10-20', 1350000, 'especes', '(Excel Feuil1 L175)', null, null);

-- ---------------------------------------------------------------------------
--  C36 · ABDSELAM — 2 nouveau(x) mouvement(s) · solde Excel 0.00 → 0.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C36', '2026-10-01', null, '[["SOUS CHEMISE 250 F", 400.0, 590.0], ["CHEMISE DOSSIER 100 F", 100.0, 690.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L29');
select import_excel.pay('C36', '2026-10-01', 305000, 'especes', '(Excel Feuil1 L39)', null, null);

commit;
