-- =============================================================================
--  IMPORT EXCEL · BONS DE LIVRAISON ET VERSEMENTS — PARTIE 5
-- =============================================================================
-- Généré automatiquement depuis SITUATION.xlsx le 2026-10-19 — ne pas modifier à la main.
begin;
set local statement_timeout = 0;
select import_excel.start_file('02_clients_mouvements_partie5.sql');

-- ---------------------------------------------------------------------------
--  C22 · PAGE  (Feuil1, colonnes 127-132)
--  solde de départ 0.00 DA · solde final Excel 475 240.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C22', '2023-08-29', null, '[["Rouleau traceur 50 m", 40.0, 1280.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.bl('C22', '2023-08-30', null, '[["sous chemise 500 f", 150.0, 1600.0], ["chemise dossier 200f", 153.0, 1720.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L14');
select import_excel.pay('C22', '2023-10-19', 498000.72, 'cheque', 'VERSEMENT PAR CHEQUE — Facture N° 139 (Excel Feuil1 L20)', null, null);
select import_excel.pay('C22', '2023-10-19', 50000, 'especes', '(Excel Feuil1 L22)', null, null);
select import_excel.bl('C22', '2023-10-19', null, '[["chemise dossier 200 f", 100.0, 1660.0], ["Sous Chemise 500 f", 100.0, 1520.0], ["Ruban Thermique 80x80", 192.0, 180.0], ["Rouleau fax 25 m", 312.0, 190.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L24');
select import_excel.pay('C22', '2023-11-29', 418199.28, 'cheque', 'VERSEMENT PAR CHEQUE — Facture N° 151 (Excel Feuil1 L31)', null, null);
select import_excel.bl('C22', '2023-12-17', null, '[["chemise dossier 200 f", 100.0, 1600.0], ["Rouleau fax 25 m", 552.0, 180.0], ["Rouleau table traçante 50 m", 40.0, 1150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L33');
select import_excel.bl('C22', '2023-12-20', null, '[["Sous Chemise 500 f", 100.0, 1480.0], ["Ruban Thermique 80x75", 480.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L40');
select import_excel.bl('C22', '2024-01-14', null, '[["chemise dossier 200 f", 150.0, 1600.0], ["sous chemise 500 f", 50.0, 1480.0], ["Rouleau table traçante 50 m", 40.0, 1150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L47 · date Excel corrigée (2023-01-14)');
select import_excel.pay('C22', '2024-01-18', 534961.55, 'cheque', 'VERSEMENT PAR CHEQUE — Facture N° 04 (Excel Feuil1 L54)', null, null);
select import_excel.bl('C22', '2024-02-15', null, '[["chemise dossier 200 f", 150.0, 1600.0], ["sous chemise 500 f", 140.0, 1480.0], ["sous chemise250 f", 100.0, 740.0], ["chemise dossier 100", 36.0, 800.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L56');
select import_excel.pay('C22', '2024-02-27', 360001.18, 'cheque', 'VERSEMENT PAR CHEQUE — Facture N° 31 (Excel Feuil1 L63)', null, null);
select import_excel.bl('C22', '2024-03-20', null, '[["chemise dossier 200 f", 50.0, 1600.0], ["Rouleaau fax 25 m", 240.0, 180.0], ["Ruban thermique 80x60", 150.0, 120.0], ["chemise dossier 100", 13.0, 800.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L65');
select import_excel.bl('C22', '2024-04-01', null, '[["chemise dossier 100 f", 50.0, 800.0], ["Sous Chemise 500 f", 200.0, 1480.0], ["Sous Chemise 250 f", 50.0, 740.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L72');
select import_excel.pay('C22', '2024-05-28', 500228.4, 'cheque', 'VERSEMENT PAR CHEQUE — Facture N° 65 (Excel Feuil1 L79)', null, null);
select import_excel.pay('C22', '2024-05-28', 574377.3, 'cheque', 'VERSEMENT PAR CHEQUE — Facture N° 66 (Excel Feuil1 L81)', null, null);
select import_excel.charge('C22', '2024-05-28', 'Ajustement de solde (écart Excel)', 8.43, 'écart du fichier Excel Feuil1 L82 : solde calculé -8.43  solde écrit 0.00');
select import_excel.bl('C22', '2024-06-13', null, '[["chemise dossier 200 f", 200.0, 1580.0], ["Sous Chemise 500 f", 200.0, 1480.0], ["ruban thermique 80x75", 240.0, 165.0], ["ruban thermique 80x60", 375.0, 115.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L83');
select import_excel.bl('C22', '2024-06-13', null, '[["chemise dossier 100 f", 50.0, 790.0], ["Sous Chemise 250 f", 50.0, 740.0], ["ruban thermique 80x75", 720.0, 165.0], ["Rouleau table traçante 50 m", 40.0, 1130.0], ["Rouleau fax 25 m", 240.0, 180.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L90');
select import_excel.bl('C22', '2024-08-19', null, '[["sous chemise 500 f", 100.0, 1480.0], ["chemise dossier 200f", 100.0, 1580.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L98');
select import_excel.pay('C22', '2024-08-19', 500000, 'especes', '(Excel Feuil1 L104)', null, null);
select import_excel.pay('C22', '2024-08-19', 306000, 'especes', '(Excel Feuil1 L106)', null, null);
select import_excel.pay('C22', '2024-09-10', 478425, 'especes', '(Excel Feuil1 L108)', null, null);
select import_excel.bl('C22', '2024-10-14', null, '[["CHEMISE DOSSIER 100 F", 120.0, 790.0], ["chemise dossier 200f", 350.0, 1580.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L110');
select import_excel.bl('C22', '2024-10-16', null, '[["sous chemise 250 f", 150.0, 740.0], ["RUBAN THERMIQUE 80X60", 375.0, 100.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L116');
select import_excel.bl('C22', '2024-10-20', null, '[["sous chemise 250 f", 50.0, 740.0], ["SOUS CHEMISE 500 F", 50.0, 1480.0], ["CHEMISE DOSSIER 100 F", 50.0, 790.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L122');
select import_excel.pay('C22', '2024-10-20', 400000, 'especes', '(Excel Feuil1 L128)', null, null);
select import_excel.bl('C22', '2024-11-03', null, '[["ROULEAU FAX 25 M", 840.0, 175.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L130');
select import_excel.bl('C22', '2024-12-01', null, '[["chemise dossier 100 f", 100.0, 790.0], ["Sous Chemise 250 f", 50.0, 740.0], ["Sous chemise 500 f", 50.0, 1480.0], ["chemise dossier 200 f", 150.0, 1580.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L136');
select import_excel.pay('C22', '2024-12-01', 693800, 'especes', '(Excel Feuil1 L144)', null, null);
select import_excel.bl('C22', '2025-01-06', null, '[["SOUS CHEMISE 250 F", 50.0, 730.0], ["SOUS CHEMISE 500 F", 50.0, 1460.0], ["ROULEAU TABLE TRACANTE 50 M", 30.0, 1130.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L146');
select import_excel.bl('C22', '2025-01-15', null, '[["ROULEAU TABLE TRACANTE 50 M", 20.0, 1130.0], ["ROULEAU FAX 25 M", 240.0, 175.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L152');
select import_excel.pay('C22', '2025-01-15', 140000, 'especes', '(Excel Feuil1 L158)', null, null);
select import_excel.bl('C22', '2025-03-05', null, '[["SOUS CHEMISE 250 F", 100.0, 730.0], ["SOUS CHEMISE 500 F", 100.0, 1460.0], ["CHEMISE DOSSIER 200 F", 60.0, 1580.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L160');
select import_excel.bl('C22', '2025-04-23', null, '[["ROULEAU TABLE TRACANTE 50 M", 40.0, 1150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L166');
select import_excel.bl('C22', '2025-05-13', null, '[["SOUS CHEMISE 250 F", 100.0, 720.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L172');
select import_excel.pay('C22', '2025-05-13', 926800, 'especes', '(Excel Feuil1 L178)', null, null);
select import_excel.bl('C22', '2025-07-31', null, '[["ROULEAU TABLE TRACANTE 50 M", 20.0, 900.0], ["CHEMISE DOSSIER 200 F", 50.0, 1540.0], ["SOUS CHEMISE 500 F", 50.0, 1440.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L180');
select import_excel.bl('C22', '2025-09-21', null, '[["ROULEAU FAX 25 M", 120.0, 165.0], ["CHEMISE DOSSIER 200 F", 150.0, 1540.0], ["SOUS CHEMISE 500 F", 80.0, 1440.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L186');
select import_excel.bl('C22', '2025-10-20', null, '[["SOUS CHEMISE 500 F", 50.0, 1440.0], ["CHEMISE DOSSIER 200 F", 50.0, 1540.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L192');
select import_excel.bl('C22', '2025-10-27', null, '[["ROULEAU TABLE TRACANTE 50 M", 20.0, 900.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L198');
select import_excel.bl('C22', '2025-11-04', null, '[["ROULEAU TABLE TRACANTE 50 M", 20.0, 900.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L204');
select import_excel.bl('C22', '2025-09-15', null, '[["CHEMISE DOSSIER 100 F", 50.0, 770.0], ["SOUS CHEMISE 25 0D", 50.0, 700.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L210');
select import_excel.pay('C22', '2025-11-04', 791500, 'especes', '(Excel Feuil1 L216)', null, null);
select import_excel.bl('C22', '2026-06-30', null, '[["CHEMISE DOSSIER 100 F", 50.0, 730.0], ["SOUS CHEMISE 25 0D", 50.0, 600.0], ["ROULEAU TABLE TRACANTE 50 M", 40.0, 900.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L218');
select import_excel.bl('C22', '2026-07-13', null, '[["CHEMISE DOSSIER 200 F", 50.0, 1460.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L224');
select import_excel.bl('C22', '2026-08-09', null, '[["POCHETTE DESSIN BLANC", 2500.0, 18.0], ["SOUS CHEMISE 25 0D", 50.0, 600.0], ["POCHETTE DESSIN COULEUR", 2500.0, 23.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L230');
select import_excel.bl('C22', '2026-08-03', null, '[["SOUS CHEMISE 25 0D", 50.0, 600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L236');
select import_excel.pay('C22', '2026-09-03', 308000, 'especes', '(Excel Feuil1 L242) · date Excel corrigée (2025-09-03)', null, null);
select import_excel.bl('C22', '2026-09-07', null, '[["CHEMISE DOSSIER 200 F", 50.0, 1460.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L244');
select import_excel.bl('C22', '2026-09-09', null, '[["CHEMISE DOSSIER 100 F", 50.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L250');
select import_excel.bl('C22', '2026-09-17', null, '[["CHEMISE DOSSIER 100 F", 100.0, 730.0], ["SOUS CHEMISE 250 F", 100.0, 600.0], ["SOUS CHEMISE 500 F", 105.0, 1180.0], ["CHEMISE DOSSIER 200 F", 54.0, 1460.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L256');

-- ---------------------------------------------------------------------------
--  C23 · SARL TAZIRI ALGER  (Feuil1, colonnes 133-138)
--  solde de départ 0.00 DA · solde final Excel 0.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C23', '2024-03-03', null, '[["Rouleau Traçante 50 m", 120.0, 1100.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.bl('C23', '2024-03-04', null, '[["Rouleau Traçante 50 m", 40.0, 1100.0], ["Rouleau Traçante 150 m", 60.0, 3300.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L15');
select import_excel.pay('C23', '2024-03-04', 374000, 'especes', '(Excel Feuil1 L21)', null, null);
select import_excel.bl('C23', '2024-07-02', null, '[["Rouleau Traçante 50 m", 120.0, 1050.0], ["Rouleau Traçante 150 m", 50.0, 3150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L23');
select import_excel.pay('C23', '2024-07-02', 150000, 'especes', '(Excel Feuil1 L29)', null, null);
select import_excel.pay('C23', '2024-07-08', 133500, 'especes', '(Excel Feuil1 L31)', null, null);
select import_excel.bl('C23', '2024-08-21', null, '[["Rouleau Traçante 50 m", 120.0, 1050.0], ["Rouleau Traçante 150 m", 60.0, 3150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L33');
select import_excel.pay('C23', '2024-08-21', 200000, 'especes', '(Excel Feuil1 L39)', null, null);
select import_excel.pay('C23', '2024-08-21', 115000, 'especes', '(Excel Feuil1 L41)', null, null);
select import_excel.bl('C23', '2024-08-29', null, '[["Rouleau Traçante 150 m", 100.0, 3150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L43');
select import_excel.pay('C23', '2024-08-29', 315000, 'especes', '(Excel Feuil1 L49)', null, null);
select import_excel.bl('C23', '2024-09-29', null, '[["Rouleau Traçante 150 m", 100.0, 3150.0], ["ROULEA TABLE TRACANTE 50 M", 120.0, 1050.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L51');
select import_excel.bl('C23', '2024-09-30', null, '[["ROULEA TABLE TRACANTE 50 M", 120.0, 1050.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L57');
select import_excel.pay('C23', '2024-09-30', 567000, 'especes', '(Excel Feuil1 L63)', null, null);
select import_excel.bl('C23', '2024-10-13', null, '[["ROULEA TABLE TRACANTE 50 M", 160.0, 1050.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L65');
select import_excel.pay('C23', '2024-10-24', 168000, 'especes', '(Excel Feuil1 L71)', null, null);
select import_excel.bl('C23', '2024-10-29', null, '[["ROULEA TABLE TRACANTE 50 M", 240.0, 1100.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L73');
select import_excel.pay('C23', '2024-10-29', 264000, 'especes', '(Excel Feuil1 L79)', null, null);
select import_excel.bl('C23', '2024-11-20', null, '[["ROULEA TABLE TRACANTE 50 M", 360.0, 1100.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L81');
select import_excel.pay('C23', '2024-11-24', 396000, 'especes', '(Excel Feuil1 L87)', null, null);
select import_excel.bl('C23', '2024-11-24', null, '[["µ", 1.0, 0.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L188');

-- ---------------------------------------------------------------------------
--  C24 · TECH ZONE  (Feuil1, colonnes 139-144)
--  solde de départ 0.00 DA · solde final Excel 805 237.80 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C24', '2024-04-04', null, '[["Sous Chemise 250 f", 100.0, 720.0], ["Chemise Dossier 100 f", 100.0, 770.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.bl('C24', '2024-04-24', null, '[["Sous Chemise 250 f", 200.0, 720.0], ["Chemise Dossier 100 f", 200.0, 770.0], ["Ruban Thermique 80x75", 240.0, 165.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L15');
select import_excel.pay('C24', '2024-04-24', 300000, 'especes', '(Excel Feuil1 L21)', null, null);
select import_excel.bl('C24', '2024-04-07', null, '[["Ruban Thermique 80x80", 192.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L23');
select import_excel.bl('C24', '2024-06-11', null, '[["SOUS CHEMISE JAUNE 250 F", 20.0, 720.0], ["CHEMISE DOSSIER BLEU 100 F", 50.0, 770.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L29');
select import_excel.pay('C24', '2024-06-11', 186450, 'virement', '(Excel Feuil1 L35)', null, null);
select import_excel.pay('C24', '2024-06-11', 85598.13, 'virement', '(Excel Feuil1 L37)', null, null);
select import_excel.pay('C24', '2024-06-11', 91.87, 'especes', '[AJUSTEMENT EXCEL] écart du fichier Excel Feuil1 L38 : solde calculé 91.87  solde écrit 0.00');
select import_excel.bl('C24', '2024-07-02', null, '[["SOUS CHEMISE 250 F", 50.0, 720.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L39');
select import_excel.bl('C24', '2024-07-30', null, '[["pochette dessin couleur", 5000.0, 24.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L45');
select import_excel.bl('C24', '2024-09-04', null, '[["ROULEAU TABLE TRACANTE 50 M", 200.0, 1100.0], ["RUBAN THERMIQUE 80X75", 336.0, 165.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L51');
select import_excel.bl('C24', '2024-09-15', null, '[["SOUS CHEMISE 250 F", 100.0, 720.0], ["CHEMISE DOSSIER 100 F", 100.0, 770.0], ["pochette dessin couleur", 1000.0, 24.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L57');
select import_excel.bl('C24', '2024-09-22', null, '[["pochette dessin couleur", 500.0, 24.0], ["RUBAN THERMIQUE 80X75", 48.0, 160.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L63');
select import_excel.pay('C24', '2024-09-19', 431808, 'virement', 'Facture N° 111 (Excel Feuil1 L69)', null, null);
select import_excel.bl('C24', '2024-10-11', null, '[["SOUS CHEMISE 250 F", 160.0, 720.0], ["CHEMISE DOSSIER 100 F", 150.0, 770.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L71');
select import_excel.bl('C24', '2024-10-30', null, '[["SOUS CHEMISE 250 F", 100.0, 720.0], ["RUBAN THERMIQUE 80X75", 240.0, 160.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L77');
select import_excel.bl('C24', '2024-11-18', null, '[["ROULEAU PAPIER PHOTO 30 M", 4.0, 5200.0], ["ROULEAU TABLE TRACANTE 50 M", 6.0, 1200.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L83');
select import_excel.bl('C24', '2024-12-01', null, '[["CHEMISE DOSSIER 100 F", 70.0, 770.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L89');
select import_excel.bl('C24', '2024-12-15', null, '[["Ruban Thermique 80x80", 240.0, 160.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L95');
select import_excel.pay('C24', '2024-12-10', 442382.5, 'virement', 'Facture N° 139 (Excel Feuil1 L101)', null, null);
select import_excel.bl('C24', '2024-12-24', null, '[["Ruban Thermique 80x60", 750.0, 90.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L103');
select import_excel.bl('C24', '2024-12-30', null, '[["CHEMISE DOSSIER 100 F", 50.0, 770.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L109');
select import_excel.bl('C24', '2025-01-14', null, '[["CHEMISE DOSSIER 100 F", 50.0, 770.0], ["SOUS CHEMISE 250 F", 60.0, 710.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L115 · date Excel corrigée (2024-01-14)');
select import_excel.bl('C24', '2025-01-23', null, '[["ROULEAU ETIQUETTE 100/100", 66.0, 560.0], ["ROULEAU ETIQUETTE150/100", 60.0, 610.0], ["ROULEAU ETIQUETTE35/45", 68.0, 225.0], ["ruban thermique 80x40", 294.0, 45.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L121');
select import_excel.bl('C24', '2025-01-26', null, '[["SOUS CHEMISE 250 F", 40.0, 700.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L128 · date Excel corrigée (2024-01-26)');
select import_excel.bl('C24', '2025-02-20', null, '[["chemise dossier 100 f", 150.0, 770.0], ["sous chemise 500 f", 1.0, 1400.0], ["chemise dossier 500 f", 1.0, 3850.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L134');
select import_excel.pay('C24', '2024-12-10', 528514.7, 'virement', 'Facture N° 139 (Excel Feuil1 L140)', null, null);
select import_excel.bl('C24', '2025-03-05', null, '[["chemise dossier 100 f", 70.0, 770.0], ["sous chemise 250 f", 100.0, 700.0], ["RUBAN THERMIQUE 80X75", 240.0, 158.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L142');
select import_excel.bl('C24', '2025-03-12', null, '[["ETIQUETTE 100X150", 135.0, 600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L148');
select import_excel.bl('C24', '2025-04-06', null, '[["RUBAN THERMIQUE 80X75", 240.0, 155.0], ["RUBAN THERMIQUE 57X50", 288.0, 49.0], ["RUBAN THERMIQUE 57X40", 512.0, 39.0], ["ETIQUETTE 35X45", 20.0, 225.0], ["ETIQUETTE 20X40", 20.0, 220.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L154');
select import_excel.bl('C24', '2025-04-09', null, '[["pochette dessin couleur", 500.0, 23.9]]'::jsonb, 0, null, 'Import Excel Feuil1 L162');
select import_excel.pay('C24', '2025-04-13', 455713.07, 'virement', 'Facture N° 38 (Excel Feuil1 L168)', null, null);
select import_excel.charge('C24', '2025-04-13', 'Ajustement de solde (écart Excel)', 8.27, 'écart du fichier Excel Feuil1 L169 : solde calculé -8.27  solde écrit 0.00');
select import_excel.bl('C24', '2025-04-21', null, '[["ETIQUETTE 100X100", 165.0, 560.0], ["ETIQUETTE 100X150", 150.0, 600.0], ["ETIQUETTE 20X40", 40.0, 220.0], ["ETIQUETTE 35X45", 40.0, 225.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L170');
select import_excel.bl('C24', '2025-04-23', null, '[["sous chemise 250 f", 50.0, 700.0], ["ETIQUETTE 35X45", 80.0, 225.0], ["ETIQUETTE 20X40", 80.0, 220.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L178');
select import_excel.bl('C24', '2025-05-04', null, '[["SOUS CHEMISE 250 F", 100.0, 700.0], ["CHEMISE DOSSIER 100 F", 50.0, 760.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L186');
select import_excel.bl('C24', '2025-05-26', null, '[["SOUS CHEMISE 250 F", 50.0, 680.0], ["ROULEAU FAX 25 M", 120.0, 160.0], ["pochette dessin couleur", 500.0, 23.5]]'::jsonb, 0, null, 'Import Excel Feuil1 L192');
select import_excel.bl('C24', '2025-05-28', null, '[["ROULEAU ETIQUETTE 100X150", 150.0, 600.0], ["RUBAN THERMIQUE 80X75", 240.0, 150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L198');
select import_excel.pay('C24', '2025-05-28', 378812.7, 'virement', 'Facture N° 51 (Excel Feuil1 L204)', null, null);
select import_excel.bl('C24', '2025-06-04', null, '[["ROULEAU FAX 25 M", 120.0, 160.0], ["RUBAN THERMIQUE LAIZE 60", 18.0, 1350.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L206');
select import_excel.bl('C24', '2025-06-05', null, '[["RUBAN THERMIQUE LAIZE 60", 234.0, 1350.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L212');
select import_excel.bl('C24', '2025-06-09', null, '[["RUBAN THERMIQUE LAIZE 60", 90.0, 1350.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L218');
select import_excel.bl('C24', '2025-06-09', 'V2', '[["RUBAN THERMIQUE LAIZE 60", 64.0, 1350.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L224');
select import_excel.bl('C24', '2025-06-22', null, '[["pochette dessin couleur", 3000.0, 23.5], ["POCHETTE DESSIN BLANCHE", 3000.0, 19.5]]'::jsonb, 0, null, 'Import Excel Feuil1 L230');
select import_excel.bl('C24', '2025-06-24', null, '[["SOUS CHEMISE 250 F", 50.0, 680.0], ["CHEMISE DOSSIER 100 F", 50.0, 750.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L236');
select import_excel.bl('C24', '2025-06-26', null, '[["ROULEAU THERMIQUE GAB 80X100", 503.0, 230.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L242');
select import_excel.bl('C24', '2025-06-30', null, '[["SOUS CHEMISE 250 F", 30.0, 680.0], ["RUBAN THERMIQUE 80X75", 240.0, 150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L248');
select import_excel.bl('C24', '2025-07-07', null, '[["ROULEAU ETIQUETTE 100X150", 140.0, 600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L254');
select import_excel.pay('C24', '2025-07-17', 1214827.3, 'virement', 'Facture N° 71 (Excel Feuil1 L260)', null, null);
select import_excel.bl('C24', '2025-08-04', null, '[["ruban thermique 80x75", 1008.0, 150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L262');
select import_excel.bl('C24', '2025-08-23', null, '[["SOUS CHEMISE 250 F", 30.0, 660.0], ["CHEMISE DOSSIER 100 F", 30.0, 750.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L268');
select import_excel.bl('C24', '2025-09-04', null, '[["SOUS CHEMISE 250 F", 50.0, 660.0], ["CHEMISE DOSSIER 100 F", 50.0, 750.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L274');
select import_excel.bl('C24', '2025-09-09', null, '[["SOUS CHEMISE 250 F", 30.0, 660.0], ["CHEMISE DOSSIER 100 F", 50.0, 750.0], ["ROULEAU FAX 25 M", 48.0, 160.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L280');
select import_excel.bl('C24', '2025-09-09', null, '[["RUBAN THERMIQUE 80X75", 240.0, 150.0], ["CHEMISE DOSSIER 100 F", 6.0, 1500.0], ["ROULEAU FAX 25 M", 72.0, 160.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L286');
select import_excel.bl('C24', '2025-09-23', null, '[["RUBAN THERMIQUE 80X60", 750.0, 88.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L292');
select import_excel.bl('C24', '2025-09-24', null, '[["ROULEAU ETIQUETTE 100X150", 120.0, 600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L298');
select import_excel.bl('C24', '2025-09-30', null, '[["SOUS CHEMISE 250 F", 150.0, 660.0], ["CHEMISE DOSSIER 100 F", 200.0, 750.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L304');
select import_excel.bl('C24', '2025-10-06', null, '[["SOUS CHEMISE 250 F", 50.0, 660.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L310');
select import_excel.pay('C24', '2025-10-06', 800000, 'virement', '(Excel Feuil1 L316)', null, null);
select import_excel.bl('C24', '2025-11-04', null, '[["SOUS CHEMISE 250 F", 100.0, 660.0], ["CHEMISE DOSSIER 100 F", 50.0, 750.0], ["RUBAN THERMIQUE 80X75", 250.0, 150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L318');
select import_excel.bl('C24', '2025-11-10', null, '[["SOUS CHEMISE 250 F", 250.0, 650.0], ["CHEMISE DOSSIER 100 F", 250.0, 750.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L324');
select import_excel.bl('C24', '2025-11-17', null, '[["ETIQUETTE 20X40", 288.0, 200.0], ["RUBAN THERMIQUE 80X75", 500.0, 148.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L330');
select import_excel.bl('C24', '2025-12-02', null, '[["SOUS CHEMISE 250 F", 80.0, 630.0], ["CHEMISE DOSSIER 100 F", 50.0, 740.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L336');
select import_excel.bl('C24', '2025-12-07', null, '[["PAPIER BRISTOL UNIS A 4 VERT", 100.0, 330.0], ["PAPIER BRISTOL UNIS A 4ROSE", 10.0, 330.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L342');
select import_excel.bl('C24', '2025-12-18', null, '[["SOUS CHEMISE 250 F", 100.0, 630.0], ["CHEMISE DOSSIER 100 F", 40.0, 740.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L348');
select import_excel.bl('C24', '2025-12-30', null, '[["ROULEAU FAX 25 M", 72.0, 160.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L354');
select import_excel.bl('C24', '2026-01-04', null, '[["SOUS CHEMISE 250 F", 100.0, 630.0], ["CHEMISE DOSSIER 100 F", 100.0, 740.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L360');
select import_excel.bl('C24', '2026-01-14', null, '[["RUBAN THERMIQUE 80X60", 250.0, 86.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L366');
select import_excel.pay('C24', '2026-01-18', 751803, 'virement', '(Excel Feuil1 L372)', null, null);
select import_excel.bl('C24', '2026-01-19', null, '[["ruban thermique 80x75", 250.0, 148.0], ["ETIQUETTE 100X150", 128.0, 540.0], ["sous chemise 25 0f", 120.0, 620.0], ["chemise dossier 100f", 200.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L374');
select import_excel.bl('C24', '2025-11-30', null, '[["ROULEAU ETIQUETTE 100X150", 60.0, 540.0], ["ROULEAU THERMIQUE 80X40", 98.0, 45.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L382');
select import_excel.bl('C24', '2025-11-30', null, '[["ROULEAU TABLE TRACANTE 50 M", 4.0, 860.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L388');
select import_excel.bl('C24', '2026-02-10', null, '[["RUBAN THERMIQUE 80X75", 500.0, 145.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L394');
select import_excel.bl('C24', '2026-03-10', null, '[["RUBAN THERMIQUE 80X100X25", 457.0, 450.0], ["SOUS CHEMISE 250 F", 100.0, 620.0], ["CHEMISE DOSSIER 100 F", 100.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L400');
select import_excel.bl('C24', '2026-03-24', null, '[["ROULEAU ETIQUETTE 58X45", 240.0, 240.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L406');
select import_excel.bl('C24', '2026-03-25', null, '[["ROULEAU ETIQUETTE 58X45", 96.0, 240.0], ["RUBAN THERMIQUE 80X60", 500.0, 86.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L412');
select import_excel.bl('C24', '2026-03-25', null, '[["ROULEAU ETIQUETTE 58X45", 240.0, 240.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L418');
select import_excel.bl('C24', '2026-04-01', null, '[["RUBAN THERMIQUE 80X60", 50.0, 86.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L424');
select import_excel.pay('C24', '2026-04-01', 500014.2, 'virement', '(Excel Feuil1 L430)', null, null);
select import_excel.bl('C24', '2026-04-06', null, '[["SOUS CHEMISE 250 F", 160.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L432');
select import_excel.pay('C24', '2026-04-06', 400000, 'virement', '(Excel Feuil1 L438)', null, null);
select import_excel.bl('C24', '2026-04-16', null, '[["SOUS CHEMISE 250 F", 100.0, 620.0], ["CHEMISE DOSSIER 100 F", 100.0, 730.0], ["RUBAN THERMIQUE 80X60", 100.0, 86.0], ["ROULEAU ETIQUETTE 20X40", 100.0, 190.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L440');
select import_excel.bl('C24', '2026-04-20', null, '[["SOUS CHEMISE 250 F", 100.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L448');
select import_excel.pay('C24', '2026-04-06', 500000, 'virement', '(Excel Feuil1 L454)', null, null);
select import_excel.bl('C24', '2026-04-29', null, '[["RUBAN THERMIQUE 80X75", 7.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L456');
select import_excel.bl('C24', '2026-05-06', null, '[["SOUS CHEMISE 250 F", 100.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L462');
select import_excel.bl('C24', '2026-05-07', null, '[["chemise dossier 100 f", 100.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L468');
select import_excel.bl('C24', '2026-05-10', null, '[["chemise dossier 100 f", 100.0, 730.0], ["SOUS CHEMISE 250 F", 100.0, 620.0], ["CHEMISE DOSSIER 200 F", 100.0, 1460.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L474');
select import_excel.bl('C24', '2026-05-13', null, '[["SOUS CHEMISE 250 F", 100.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L480');
select import_excel.bl('C24', '2026-05-17', null, '[["CHEMISE DOSSIER 100 F", 100.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L486');
select import_excel.bl('C24', '2026-05-17', null, '[["SOUS CHEMISE 250 F", 50.0, 620.0], ["CHEMISE DOSSIER 100 F", 50.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L492');
select import_excel.pay('C24', '2026-06-10', 500395, 'virement', 'Facture N° 52 (Excel Feuil1 L498)', null, null);
select import_excel.bl('C24', '2026-06-21', null, '[["POCHETTE DESSIN COULEUR", 3000.0, 23.5], ["ROULEAU ETIQUETTE 20X40", 100.0, 190.0], ["ROULEAU ETIQUETTE 100X150", 64.0, 520.0], ["ROULEAU ETIQUETTE 58X45", 96.0, 240.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L500');
select import_excel.bl('C24', '2026-06-21', null, '[["SOUS CHEMISE 250 F", 50.0, 620.0], ["CHEMISE DOSSIER 100 F", 50.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L508');
select import_excel.bl('C24', '2026-06-21', null, '[["RUBAN THERMIQUE 80X75", 150.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L514');
select import_excel.bl('C24', '2026-06-21', null, '[["CHEMISE DOSSIER 100 F", 50.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L520');
select import_excel.bl('C24', '2026-07-08', null, '[["SOUS CHEMISE 250 F", 50.0, 620.0], ["rouleau etiquette 20x40", 120.0, 190.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L526');
select import_excel.bl('C24', '2026-07-13', null, '[["rouleau etiquette 100X150", 96.0, 520.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L532');
select import_excel.bl('C24', '2026-07-21', null, '[["SOUS CHEMISE 250 F", 70.0, 620.0], ["CHEMISE DOSSIER 100 F", 50.0, 730.0], ["RUBAN THERMIQUE 80X100X25", 540.0, 450.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L538');
select import_excel.pay('C24', '2026-07-16', 700000, 'virement', 'Facture N° 64 (Excel Feuil1 L544)', null, null);
select import_excel.bl('C24', '2026-07-23', null, '[["RUBAN THERMIQUE 80X100X25", 1485.0, 450.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L546');
select import_excel.bl('C24', '2026-07-28', null, '[["POCHETTE DESSIN BLANCHE", 2000.0, 18.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L552');
select import_excel.bl('C24', '2026-08-02', null, '[["ROULEAU TABLE TRACANTE 50 M", 10.0, 860.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L558');
select import_excel.bl('C24', '2026-08-27', null, '[["SOUS CHEMISE 250F", 50.0, 620.0], ["RUBAN THERMIQUE 80X75", 250.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L564');
select import_excel.bl('C24', '2026-09-27', null, '[["SOUS CHEMISE 250F", 150.0, 620.0], ["CHEMISE DOSSIER 100 F", 150.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L570');
select import_excel.pay('C24', '2026-09-24', 500000, 'virement', '(Excel Feuil1 L576)', null, null);
select import_excel.bl('C24', '2026-10-05', null, '[["ROULEAU ETIQUETTE 20X40", 300.0, 185.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L578');

-- ---------------------------------------------------------------------------
--  C25 · SARL EL BIBANE  (Feuil1, colonnes 145-150)
--  solde de départ 0.00 DA · solde final Excel 0.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C25', '2024-10-30', null, '[["chemise dossier 100 f", 300.0, 760.0], ["Rouleaau fax 25 m", 720.0, 168.0], ["Sous chemise 250 f", 400.0, 690.0], ["papier photo 30 m", 8.0, 5100.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.pay('C25', '2024-10-30', 665760, 'especes', '(Excel Feuil1 L16)', null, null);
select import_excel.bl('C25', '2025-05-18', null, '[["ROULEAU TABLE TRACANTE 50 M", 10.0, 1150.0], ["ROULEAU FAX 25 M", 504.0, 160.0], ["RUBAN THERMIQUE 80X75", 672.0, 150.0], ["CHEMISE DOSSIER 100 F", 100.0, 750.0], ["papier photo 25 m", 8.0, 4000.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L18');
select import_excel.bl('C25', '2025-06-16', null, '[["ROULEAU FAX 25 M", 816.0, 155.0], ["SOUS chemise500 f", 100.0, 1280.0], ["Sous chemise 250 f", 20.0, 640.0], ["CHEMISE DOSSIER 100 F", 100.0, 1850.0], ["BRISTOL UNIS JAUNE", 600.0, 230.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L26');
select import_excel.pay('C25', '2025-06-16', 299940, 'especes', '(Excel Feuil1 L34)', null, null);
select import_excel.pay('C25', '2025-06-16', 590280, 'especes', '(Excel Feuil1 L36)', null, null);

-- ---------------------------------------------------------------------------
--  C26 · ADEL MIMOUNE  (Feuil1, colonnes 151-156)
--  solde de départ 0.00 DA · solde final Excel 632 789.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C26', '2024-10-30', null, '[["RUBAN THERMIQUE 57X40", 2560.0, 38.0], ["RUBAN THERMIQUE 80X60", 750.0, 94.0], ["ROULEAY TIREUSE DE PLAN 150 M", 10.0, 3300.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.bl('C26', '2024-11-07', null, '[["RUBAN THERMIQUE 80X80", 960.0, 170.0], ["RUBAN THERMIQUE 80X35", 2430.0, 42.0], ["ROULEAY TIREUSE DE PLAN 150 M", 35.0, 3100.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L16');
select import_excel.pay('C26', '2024-11-07', 500000, 'especes', '(Excel Feuil1 L23)', null, null);
select import_excel.bl('C26', '2024-11-12', null, '[["RUBAN THERMIQUE 80X75", 2784.0, 145.0], ["RUBAN THERMIQUE 57X40", 1280.0, 38.0], ["ROULEAY TIREUSE DE PLAN 150 M", 30.0, 3100.0], ["ROULEAU TABLE TRACANTE 50 M", 46.0, 1070.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L25');
select import_excel.pay('C26', '2024-11-12', 300000, 'especes', '(Excel Feuil1 L32)', null, null);
select import_excel.bl('C26', '2024-11-18', null, '[["RUBAN THERMIQUE 80X75", 1200.0, 148.0], ["RUBAN THERMIQUE 57X30", 2000.0, 27.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L34');
select import_excel.pay('C26', '2024-11-18', 300000, 'especes', '(Excel Feuil1 L41)', null, null);
select import_excel.bl('C26', '2024-11-25', null, '[["RUBAN THERMIQUE 80x40", 735.0, 45.0], ["RUBAN THERMIQUE 57X30", 2000.0, 27.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L43');
select import_excel.bl('C26', '2024-12-03', null, '[["RUBAN THERMIQUE 57x40", 2560.0, 38.0], ["RUBAN THERMIQUE 80X35", 2430.0, 42.0], ["RUBAN THERMIQUE 80X60", 1200.0, 94.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L50');
select import_excel.pay('C26', '2024-12-03', 300000, 'especes', '(Excel Feuil1 L57)', null, null);
select import_excel.bl('C26', '2024-12-16', null, '[["RUBAN THERMIQUE 80X75", 4800.0, 142.0], ["RUBAN THERMIQUE 57X30", 2000.0, 27.0], ["ROULEAU FAX 25 M", 360.0, 158.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L59');
select import_excel.pay('C26', '2024-12-16', 700000, 'especes', '(Excel Feuil1 L66)', null, null);
select import_excel.bl('C26', '2025-01-08', null, '[["RUBAN THERMIQUE 80X35", 2430.0, 38.0], ["RUBAN THERMIQUE 80X40", 1470.0, 42.0], ["RUBAN THERMIQUE 80X80", 480.0, 170.0], ["ROULEAU TIREAUSE DE PLAN 150 M", 30.0, 3000.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L68');
select import_excel.pay('C26', '2025-01-08', 200000, 'especes', '(Excel Feuil1 L75)', null, null);
select import_excel.bl('C26', '2025-01-14', null, '[["RUBAN THERMIQUE 80X60", 2250.0, 82.0], ["RUBAN THERMIQUE 80X40", 1470.0, 42.0], ["MONDRIN", 1000.0, 3.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L77');
select import_excel.bl('C26', '2025-01-19', null, '[["ROULEAU TABLE TRACANTE 50 M", 6.0, 1030.0], ["RUBAN THERMIQUE 80X60", 2250.0, 82.0], ["RUBAN THERMIQUE 80X75", 2400.0, 142.0], ["CHEMISE DOSSIER 100 F", 100.0, 710.0], ["SOUS CHEMISE 250 F", 100.0, 650.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L84');
select import_excel.pay('C26', '2025-01-19', 865000, 'especes', '(Excel Feuil1 L92)', null, null);
select import_excel.bl('C26', '2025-01-22', null, '[["RUBAN THERMIQUE 57X30", 3000.0, 27.0], ["RUBAN THERMIQUE 57X50", 720.0, 48.0], ["RUBAN THERMIQUE 80X40", 735.0, 42.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L94');
select import_excel.pay('C26', '2025-01-22', 15000, 'especes', '[COMPENSATION ACHAT] ACHAT IMPRIMENTE ETIQUETTE (Excel Feuil1 L101)', null, null);
select import_excel.bl('C26', '2025-02-02', null, '[["Ruban Thermique 80x75", 960.0, 142.0], ["ruban thermique 80x60", 750.0, 82.0], ["Rouleau tireuse de plan 150 m", 50.0, 3000.0], ["ROULEAU TABLE TRACANTE 50 M", 120.0, 1030.0], ["RUBAN THERMIQUE 75X75", 720.0, 142.0], ["RUBAN THERMIQUE 80X40", 2646.0, 42.0], ["RUBAN THERMIQUE 57X40", 768.0, 37.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L103');
select import_excel.pay('C26', '2025-02-02', 801205, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L113)', null, null);
select import_excel.bl('C26', '2025-02-09', null, '[["Rouleau tireuse de plan 150 m", 10.0, 3000.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L115');
select import_excel.bl('C26', '2025-03-02', null, '[["Ruban Thermique 80x75", 960.0, 142.0], ["POCHETTE DESSIN COULEUR", 5000.0, 23.0], ["Rouleau tireuse de plan 150 m", 50.0, 3000.0], ["RUBAN THERMIQUE 110X30", 1000.0, 100.0], ["RUBAN THERMIQUE 110X40", 480.0, 110.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L122');
select import_excel.pay('C26', '2025-03-02', 500000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L132)', null, null);
select import_excel.pay('C26', '2025-04-22', 797328, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L134)', null, null);
select import_excel.bl('C26', '2025-04-22', null, '[["Rouleau tireuse de plan 150 m", 50.0, 3000.0], ["ROULEAU TABLE TRACANTE 50 M", 140.0, 1000.0], ["RUBAN THERMIQUE 80x40", 1470.0, 40.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L136');
select import_excel.bl('C26', '2025-05-05', null, '[["POCHTTE DESSIN COULEUR", 5000.0, 23.0], ["ROULEAU FAX 25 M", 3216.0, 155.0], ["RUBAN THERMIQUE 80x60", 375.0, 82.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L143');
select import_excel.bl('C26', '2025-05-12', null, '[["RUBAN THERMIQUE 80x35", 1215.0, 38.0], ["RUBAN THERMIQUE 80x40", 735.0, 42.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L150');
select import_excel.bl('C26', '2025-05-14', null, '[["Ruban Thermique 80x75", 1920.0, 135.0], ["POCHETTE DESSIN COULEUR", 2500.0, 21.0], ["RUBAN THERMIQUE 80X80", 480.0, 170.0], ["RUBAN THERMIQUE 80X60", 1125.0, 82.0], ["RUBAN THERMIQUE 80X40", 2205.0, 42.0], ["RUBAN THERMIQUE 80X35", 1215.0, 38.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L157');
select import_excel.pay('C26', '2025-05-14', 800000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L167)', null, null);
select import_excel.bl('C26', '2025-05-12', null, '[["RUBAN THERMIQUE 50X40", 498.0, 50.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L169');
select import_excel.bl('C26', '2025-05-27', null, '[["ROULEAU TIREAUSE DE PLAN 150 M", 100.0, 2900.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L176');
select import_excel.pay('C26', '2025-05-02', 500000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L183)', null, null);
select import_excel.bl('C26', '2025-06-19', null, '[["RUBAN THERMIQUE 80X75", 2400.0, 142.0], ["RUBAN THERMIQUE 80X35", 2430.0, 38.0], ["RUBAN THERMIQUE 80X60", 75.0, 82.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L185');
select import_excel.pay('C26', '2025-06-19', 400000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L192)', null, null);
select import_excel.bl('C26', '2025-06-24', null, '[["RUBAN THERMIQUE 75X75", 1200.0, 142.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L194');
select import_excel.bl('C26', '2025-05-29', null, '[["Ruban Thermique 80x75", 1200.0, 140.0], ["CHEMISE DOSSIER 200 F", 100.0, 1040.0], ["ROULEAU TABLE TRACANTE 50 M", 120.0, 1000.0], ["RUBAN THERMIQUE 80X60", 1500.0, 82.0], ["RUBAN THERMIQUE 80X40", 1470.0, 42.0], ["CHEMISE DOSSIER 100 F", 545.0, 520.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L201');
select import_excel.pay('C26', '2025-06-29', 800000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L211)', null, null);
select import_excel.bl('C26', '2025-07-28', null, '[["RUBAN THERMIQUE 80X75", 3840.0, 140.0], ["RUBAN THERMIQUE 80X60", 1500.0, 82.0], ["RUBAN THERMIQUE 57X40", 2880.0, 37.0], ["RUBAN THERMIQUE 57X30", 4000.0, 25.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L213');
select import_excel.pay('C26', '2025-07-28', 600000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L220)', null, null);
select import_excel.bl('C26', '2025-07-28', null, '[["RUBAN THERMIQUE 80X75", 2400.0, 140.0], ["RUBAN THERMIQUE 80X80", 480.0, 165.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L222');
select import_excel.pay('C26', '2025-08-07', 500000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L229)', null, null);
select import_excel.bl('C26', '2025-08-17', null, '[["RUBAN THERMIQUE 80X75", 480.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L231');
select import_excel.bl('C26', '2025-08-23', null, '[["RUBAN THERMIQUE 80X75", 2880.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L238');
select import_excel.bl('C26', '2025-08-29', null, '[["Ruban Thermique 80x75", 2640.0, 140.0], ["RUBAN THERMIQUE 80X80", 480.0, 165.0], ["ROULEAU TIRAUSE DE PLAN 150 M", 31.0, 2700.0], ["RUBAN THERMIQUE 80X60", 2325.0, 82.0], ["RUBAN THERMIQUE 80X40", 1470.0, 45.0], ["RUBAN THERMQIUE 57X50", 720.0, 50.0], ["RUBA THERMIQUE 57X40", 1280.0, 41.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L245');
select import_excel.pay('C26', '2025-08-31', 1000000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L255)', null, null);
select import_excel.bl('C26', '2025-08-11', null, '[["RUBAN THERMIQUE 80X75", 2400.0, 140.0], ["rubna, thermique 80x40", 1470.0, 45.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L257');
select import_excel.pay('C26', '2025-08-11', 500000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L264)', null, null);
select import_excel.bl('C26', '2025-09-24', null, '[["RUBAN THERMIQUE 80X75", 720.0, 140.0], ["rubna, thermique 80x75", 240.0, 135.0], ["ROULEAU TABLE TRACANTE 50 M", 50.0, 860.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L266');
select import_excel.pay('C26', '2025-09-24', 500000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L273)', null, null);
select import_excel.bl('C26', '2025-10-02', null, '[["RUBAN THERMIQUE 80X75", 3840.0, 128.0], ["rubna, thermique 80x80", 480.0, 160.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L275');
select import_excel.pay('C26', '2025-10-02', 1400000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L282)', null, null);
select import_excel.bl('C26', '2025-10-12', null, '[["RUBAN THERMIQUE 80X75", 3920.0, 128.0], ["ROULEAU TIREUSE DE PLAN 150 M", 60.0, 2600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L284');
select import_excel.pay('C26', '2025-10-12', 700000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L291)', null, null);
select import_excel.bl('C26', '2025-10-20', null, '[["RUBAN THERMIQUE 80X75", 5000.0, 128.0], ["ROULEAU TIREUSE DE PLAN 150 M", 50.0, 2600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L293');
select import_excel.pay('C26', '2025-10-20', 700000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L300)', null, null);
select import_excel.bl('C26', '2025-10-20', null, '[["RUBAN THERMIQUE 80X75", 7000.0, 128.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L302');
select import_excel.bl('C26', '2025-10-20', null, '[["RUBAN THERMIQUE 75X75", 2500.0, 142.0], ["SOUS CHEMISE 250 F", 40.0, 600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L309');
select import_excel.pay('C26', '2025-10-28', 900000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L316)', null, null);
select import_excel.bl('C26', '2025-10-28', null, '[["Ruban Thermique 80x75", 4050.0, 128.0], ["RUBAN THERMIQUE 75X75", 1500.0, 142.0], ["RUBA THERMIQUE 57X40", 1280.0, 40.0], ["RUBAN THERMIQUE 110X50", 360.0, 120.0], ["RUBAN THERMIQUE 80X40", 1960.0, 42.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L318');
select import_excel.bl('C26', '2025-11-10', null, '[["RUBAN THERMIQUE 80X75", 3500.0, 128.0], ["RUBAN THERMIQUE 80X60", 3000.0, 75.0], ["RUBAN THERMIQUE 80X80", 320.0, 160.0], ["ETIQUETTE 20X40", 108.0, 188.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L328');
select import_excel.pay('C26', '2025-11-10', 1000000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L335)', null, null);
select import_excel.bl('C26', '2025-11-10', null, '[["RUBAN THERMIQUE 57X30", 3000.0, 27.0], ["RUBAN THERMIQUE 80X35", 384.0, 40.0], ["RUBAN THERMIQUE 57X50", 1080.0, 48.0], ["ETIQUETTE 100X150", 312.0, 480.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L337');
select import_excel.pay('C26', '2025-11-20', 500000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L344)', null, null);
select import_excel.bl('C26', '2025-11-22', null, '[["RUBAN THERMIQUE 80x75", 750.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L346');
select import_excel.bl('C26', '2025-11-30', null, '[["RUBAN THERMIQUE 80x75", 4450.0, 126.0], ["Ruban thermique 80x40", 1470.0, 40.0], ["ruban thermique 80x35", 896.0, 38.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L353');
select import_excel.pay('C26', '2025-11-30', 1000000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L360)', null, null);
select import_excel.bl('C26', '2025-12-07', null, '[["RUBAN THERMIQUE 80x55", 3000.0, 75.0], ["Ruban thermique 80x40", 490.0, 40.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L362');
select import_excel.bl('C26', '2025-12-17', null, '[["RUBAN THERMIQUE 80x75", 2800.0, 126.0], ["Ruban thermique 80x75", 1500.0, 138.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L369');
select import_excel.pay('C26', '2025-12-17', 400000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L376)', null, null);
select import_excel.bl('C26', '2025-12-31', null, '[["ROULEAU ETIQUETTE 20X40", 2000.0, 180.0], ["ROULEAU ETIQUETTE 35X45", 680.0, 185.0], ["ROULEAU TABLE TRACANTE 50 M", 80.0, 850.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L378');
select import_excel.pay('C26', '2025-12-31', 700000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L385)', null, null);
select import_excel.bl('C26', '2026-01-07', null, '[["ROULEAU ETIQUETTE 20X40", 400.0, 180.0], ["ROULEAU ETIQUETTE 35X45", 600.0, 185.0], ["RUBAN THERMIQUE 80X75", 2500.0, 135.0], ["RUBAN THERMIQUE 80X60", 50.0, 82.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L387');
select import_excel.pay('C26', '2026-01-15', 222490, 'especes', '[REMISE] REMISE (Excel Feuil1 L394)', null, null);
select import_excel.pay('C26', '2026-01-15', 593408, 'especes', '[RETOUR MARCHANDISE] RETOUR (Excel Feuil1 L396)', null, null);
select import_excel.bl('C26', '2026-01-07', null, '[["ROULEAU ETIQUETTE 20X40", 760.0, 180.0], ["ROULEAU ETIQUETTE 35X45", 240.0, 185.0], ["RUBAN THERMIQUE 80X75", 2500.0, 135.0], ["RUBAN THERMIQUE 80X60", 1450.0, 82.0], ["ruban thermique 57x30", 12000.0, 20.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L398');
select import_excel.pay('C26', '2026-01-15', 500000, 'especes', '[RETOUR MARCHANDISE] RETOUR (Excel Feuil1 L407)', null, null);
select import_excel.pay('C26', '2026-01-22', 153600, 'especes', '[RETOUR MARCHANDISE] RETOUR (Excel Feuil1 L409)', null, null);
select import_excel.bl('C26', '2026-01-22', null, '[["ROULEAU ETIQUETTE 20X40", 600.0, 180.0], ["ROULEAU ETIQUETTE 35X45", 1000.0, 185.0], ["RUBAN THERMIQUE 80X75", 2500.0, 135.0], ["RUBAN THERMIQUE 80X40", 1960.0, 40.0], ["ruban thermique 57x30", 6300.0, 20.0], ["RUBAN THERMIQUE57X75", 300.0, 110.0], ["RUBAN THERMQIQUE 57X40", 2940.0, 35.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L411');
select import_excel.pay('C26', '2026-01-22', 250000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L421)', null, null);
select import_excel.bl('C26', '2026-02-09', null, '[["ROULEAU TABLE TRACANTE 50 M", 160.0, 850.0], ["ROULEAU ETIQUETTE 35X45", 400.0, 185.0], ["ROULEAU ETIQUETTE 58X45", 840.0, 230.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L423');
select import_excel.pay('C26', '2026-02-09', 500000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L430)', null, null);
select import_excel.pay('C26', '2026-02-09', 249600, 'especes', '[RETOUR MARCHANDISE] RETOUR — RETOUR 39 C (Excel Feuil1 L432)', null, null);
select import_excel.pay('C26', '2026-03-31', 950000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L434)', null, null);
select import_excel.bl('C26', '2026-02-09', null, '[["ROULEAU THERMIQUE 57X40", 3675.0, 35.0], ["ROULEAU THERMIQUE 57X30", 3600.0, 20.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L436');
select import_excel.pay('C26', '2026-04-21', 200000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L443)', null, null);
select import_excel.bl('C26', '2026-05-17', null, '[["sous chemise 250 f", 50.0, 600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L445');
select import_excel.bl('C26', '2026-06-01', null, '[["ROULEAU ETIQUETTE 100X150", 672.0, 470.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L452');
select import_excel.pay('C26', '2026-06-01', 1500000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L459)', null, null);
select import_excel.bl('C26', '2026-07-29', null, '[["ROULEAU ETIQUETTE 20X40", 2016.0, 170.0], ["RUBAN THERMIQUE 80X75", 5000.0, 130.0], ["ROULEAU ETIQUETTE 20X40", 900.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L461');
select import_excel.pay('C26', '2026-07-29', 800000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L468)', null, null);
select import_excel.bl('C26', '2026-08-17', null, '[["ROULEAU ETIQUETTE 20X40", 1344.0, 170.0], ["ROULEAU ETIQUETTE 35X45", 1080.0, 170.0], ["RUBAN THERMIQUE 80X75", 2500.0, 130.0], ["ruban thermique 57x30", 15000.0, 20.0], ["ROULEAU ETIQUETTE 58X45", 480.0, 230.0], ["RUBAN THERMIQUE57X75", 320.0, 470.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L470');
select import_excel.pay('C26', '2026-08-17', 500000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L480)', null, null);
select import_excel.bl('C26', '2026-08-26', null, '[["ROULEAU ETIQUETTE 20X40", 940.0, 170.0], ["rouleau etiquette 100x150 2500 etq", 640.0, 400.0], ["RUBAN THERMIQUE 80X75", 700.0, 130.0], ["ruban thermique 57x30", 15000.0, 20.0], ["rouleau tireuse de plan 150 m", 50.0, 2550.0], ["rouleau etiquette 100x150", 128.0, 470.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L482');
select import_excel.pay('C26', '2026-08-26', 600000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L492)', null, null);
select import_excel.bl('C26', '2026-06-27', null, '[["ROULEAU ETIQUETTE 50X30", 150.0, 175.0], ["RUBAN THERMIQUE 80X75", 2500.0, 130.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L494');
select import_excel.pay('C26', '2026-08-26', 400000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L501)', null, null);
select import_excel.bl('C26', '2026-09-03', null, '[["ROULEAU ETIQUETTE 100X150 250 ETQ", 324.0, 420.0], ["ROULEAU ETIQUETTE 100X150300 ETQ", 352.0, 470.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L503');
select import_excel.pay('C26', '2026-09-03', 300000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L510)', null, null);
select import_excel.bl('C26', '2026-09-10', null, '[["RUBAN THERMIUQUE 80X40 ECG", 588.0, 90.0], ["RUBAN THERMIQUE 210", 757.0, 240.0], ["ROULEAU ETIQUETTE 100X150", 144.0, 420.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L512');
select import_excel.pay('C26', '2026-09-10', 400000, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L519)', null, null);
select import_excel.bl('C26', '2026-10-01', null, '[["RUBAN THERMIUQUE 80x75", 850.0, 130.0], ["rouleau etiquette 20x40", 300.0, 180.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L521');
select import_excel.pay('C26', '2026-10-01', 247620, 'especes', 'VERSEMENT ESPECE (Excel Feuil1 L528) · date Excel corrigée (2026-01-01)', null, null);

-- ---------------------------------------------------------------------------
--  C27 · PAPETRIE GHAREBI  (Feuil1, colonnes 157-162)
--  solde de départ 0.00 DA · solde final Excel 602 560.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C27', '2024-10-01', null, '[["CHEMISE DOSSIER 100 F", 100.0, 770.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.bl('C27', '2024-10-20', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 10.0, 3200.0], ["SOUS CHEMISE 250F", 100.0, 720.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L16');
select import_excel.bl('C27', '2024-11-10', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 40.0, 3350.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L23');
select import_excel.pay('C27', '2024-11-10', 200000, 'especes', '(Excel Feuil1 L30)', null, null);
select import_excel.bl('C27', '2024-11-11', null, '[["RUBAN THERMIQUE 57X40", 512.0, 45.0], ["ROULEAU ETIQUETTE 20X40", 100.0, 225.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L32');
select import_excel.bl('C27', '2024-11-12', null, '[["CHEMISE DOSSIER UNIS 100 F", 100.0, 770.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L39');
select import_excel.bl('C27', '2024-12-05', null, '[["CHEMISE DOSSIER UNIS 100 F", 100.0, 770.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L46');
select import_excel.pay('C27', '2024-12-05', 100000, 'especes', '(Excel Feuil1 L53)', null, null);
select import_excel.bl('C27', '2024-12-11', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 10.0, 3350.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L55');
select import_excel.bl('C27', '2024-12-25', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 30.0, 3300.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L62');
select import_excel.pay('C27', '2024-12-25', 200000, 'especes', '(Excel Feuil1 L69)', null, null);
select import_excel.bl('C27', '2025-01-15', null, '[["ROULEAU ETIQUETTE 20 X40", 360.0, 219.0], ["CHEMISE DOSSIER 100 F", 100.0, 770.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L71');
select import_excel.bl('C27', '2025-02-19', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 20.0, 3300.0], ["SOUS CHEMISE 250F", 150.0, 700.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L78');
select import_excel.pay('C27', '2025-02-20', 200000, 'especes', '(Excel Feuil1 L85)', null, null);
select import_excel.bl('C27', '2025-02-25', null, '[["POCHETTE DESSIN COULEUR", 1000.0, 23.9]]'::jsonb, 0, null, 'Import Excel Feuil1 L87');
select import_excel.bl('C27', '2025-02-26', null, '[["CHEMISE DOSSIER 100 F", 117.0, 760.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L94');
select import_excel.bl('C27', '2025-03-05', null, '[["CHEMISE DOSSIER 100 F", 100.0, 760.0], ["ROULEAU TIREUSE DE PLAN 150 M", 15.0, 3200.0], ["ROULEAU TABLE TRACANTE 50 M", 20.0, 1150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L101');
select import_excel.pay('C27', '2025-03-10', 250000, 'especes', '(Excel Feuil1 L108)', null, null);
select import_excel.bl('C27', '2025-04-13', null, '[["SOUS CHEMISE 250 F", 100.0, 700.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L110');
select import_excel.bl('C27', '2025-04-28', null, '[["SOUS CHEMISE 250 F", 100.0, 700.0], ["CHEMISE DOSSIER 100 F", 100.0, 760.0], ["ROULEAU TIREUSE DE PLAN 150 M", 20.0, 3100.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L117');
select import_excel.pay('C27', '2025-04-29', 400000, 'especes', '(Excel Feuil1 L124)', null, null);
select import_excel.bl('C27', '2025-05-27', null, '[["SOUS CHEMISE 250 F", 100.0, 650.0], ["CHEMISE DOSSIER 100 F", 100.0, 730.0], ["CHEMISE DOSSIER 100 F UNIS", 50.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L126');
select import_excel.bl('C27', '2025-06-22', null, '[["CHEMISE DOSSIER UNIS 100 F", 100.0, 730.0], ["ROULEAU TABLE TRACANTE 50 M", 20.0, 1080.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L133');
select import_excel.pay('C27', '2025-06-09', 100000, 'especes', '(Excel Feuil1 L140)', null, null);
select import_excel.bl('C27', '2025-07-31', null, '[["CHEMISE DOSSIER UNIS 100 F", 50.0, 730.0], ["SOUS CHEMISE 250F", 100.0, 650.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L142');
select import_excel.bl('C27', '2025-09-09', null, '[["CHEMISE DOSSIER 100 F", 140.0, 730.0], ["SOUS CHEMISE 250F", 100.0, 650.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L149');
select import_excel.bl('C27', '2025-10-05', null, '[["CHEMISE DOSSIER 100 F", 100.0, 730.0], ["SOUS CHEMISE 250F", 100.0, 650.0], ["ROULEAU TIREUSE DE PLAN 150 M", 10.0, 2700.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L156');
select import_excel.pay('C27', '2025-10-06', 350000, 'especes', '(Excel Feuil1 L163)', null, null);
select import_excel.bl('C27', '2025-10-14', null, '[["CHEMISE DOSSIER 100 F", 50.0, 730.0], ["SOUS CHEMISE 250F", 50.0, 650.0], ["ROULEAU TIREUSE DE PLAN 150 M", 500.0, 148.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L165');
select import_excel.bl('C27', '2025-11-04', null, '[["SOUS CHEMISE 250 F UNIS", 100.0, 650.0], ["SOUS CHEMISE 250F", 100.0, 650.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L172');
select import_excel.pay('C27', '2025-11-04', 200000, 'especes', '(Excel Feuil1 L179)', null, null);
select import_excel.bl('C27', '2025-11-06', null, '[["SOUS CHEMISE 250 F UNIS", 200.0, 630.0], ["CHEMISE DOSSIER 100 F", 200.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L181');
select import_excel.pay('C27', '2025-11-18', 100000, 'especes', '(Excel Feuil1 L188)', null, null);
select import_excel.bl('C27', '2025-11-23', null, '[["SOUS CHEMISE 250 F UNIS", 100.0, 630.0], ["CHEMISE DOSSIER 100 F", 100.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L190');
select import_excel.bl('C27', '2025-11-24', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 10.0, 2700.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L197');
select import_excel.pay('C27', '2025-12-04', 400000, 'especes', '(Excel Feuil1 L204)', null, null);
select import_excel.bl('C27', '2025-12-23', null, '[["SOUS CHEMISE 250 F UNIS", 50.0, 620.0], ["CHEMISE DOSSIER 100 F", 50.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L206');
select import_excel.bl('C27', '2025-12-28', null, '[["SOUS CHEMISE 250 F", 100.0, 620.0], ["ROULEAU TIREUSE DE PLAN 150 M", 11.0, 2700.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L213');
select import_excel.pay('C27', '2025-12-28', 202700, 'especes', '(Excel Feuil1 L220)', null, null);
select import_excel.bl('C27', '2026-01-07', null, '[["CHEMISE DOSSIER 100 F", 100.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L222');
select import_excel.bl('C27', '2026-01-18', null, '[["CHEMISE DOSSIER 200 F", 170.0, 1440.0], ["SOUS CHEMISE 500 F", 66.0, 1220.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L229');
select import_excel.bl('C27', '2026-01-25', null, '[["PAPIER A 4 THERMIQUE", 323.0, 260.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L236');
select import_excel.pay('C27', '2026-01-25', 195000, 'especes', '(Excel Feuil1 L243)', null, null);
select import_excel.bl('C27', '2026-01-26', null, '[["ROULEAU ETIQUETTE 20X40", 100.0, 190.0], ["ROULEAU ETIQUETTE 35X45", 20.0, 195.0], ["ROULEAU ETIQUETTE 58X45", 48.0, 240.0], ["ROULEAU ETIQUETTE 100X100", 32.0, 470.0], ["ROULEAU ETIQUETTE 100X150", 32.0, 530.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L245');
select import_excel.bl('C27', '2026-01-28', null, '[["SOUS CHEMISE 250 F", 100.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L254');
select import_excel.bl('C27', '2026-02-05', null, '[["CHEMISE DOSSIER 100 F", 100.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L261');
select import_excel.bl('C27', '2026-02-11', null, '[["CHEMISE DOSSIER 100 F", 100.0, 730.0], ["SOUS CHEMISE 250 F", 100.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L268');
select import_excel.pay('C27', '2026-02-11', 400000, 'especes', '(Excel Feuil1 L275)', null, null);
select import_excel.bl('C27', '2026-02-25', null, '[["PAPIER THERMIQUE A 4", 807.0, 260.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L277');
select import_excel.pay('C27', '2026-03-01', 200000, 'especes', '(Excel Feuil1 L284)', null, null);
select import_excel.pay('C27', '2026-03-11', 150000, 'especes', '(Excel Feuil1 L286)', null, null);
select import_excel.bl('C27', '2026-03-16', null, '[["ROULEAU TABLE TRACANTE 50 M", 40.0, 880.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L288');
select import_excel.pay('C27', '2026-05-13', 100000, 'especes', '(Excel Feuil1 L295)', null, null);
select import_excel.bl('C27', '2026-04-08', null, '[["SOUS CHEMISE 250 F", 50.0, 620.0], ["CHEMISE DOSSIER 100 F", 50.0, 730.0], ["ROULEAU ETIQUETTE 100X150", 32.0, 530.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L297');
select import_excel.pay('C27', '2026-04-08', 200000, 'especes', '(Excel Feuil1 L304)', null, null);
select import_excel.bl('C27', '2026-04-30', null, '[["ROULEAU ETIQUETTE 100X150", 96.0, 520.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L306');
select import_excel.bl('C27', '2026-05-03', null, '[["SOUS CHEMISE 250 F", 100.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L313');
select import_excel.pay('C27', '2026-05-03', 100000, 'especes', '(Excel Feuil1 L320)', null, null);
select import_excel.bl('C27', '2026-05-06', null, '[["PAPIER THERMIQUE A 4", 96.0, 260.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L322');
select import_excel.bl('C27', '2026-05-12', null, '[["CHEMISE DOSSIER 100 F", 100.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L329');
select import_excel.pay('C27', '2026-05-12', 100000, 'especes', '(Excel Feuil1 L336)', null, null);
select import_excel.bl('C27', '2026-05-13', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 10.0, 2700.0], ["ROULEAU ETIQUETTE 20X40", 100.0, 190.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L338');
select import_excel.bl('C27', '2026-06-03', null, '[["SOUS CHEMISE 250 F", 100.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L345');
select import_excel.bl('C27', '2026-06-11', null, '[["papier a 4 thermqieu", 288.0, 260.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L352');
select import_excel.pay('C27', '2026-06-29', 100000, 'especes', '(Excel Feuil1 L359)', null, null);
select import_excel.bl('C27', '2026-07-08', null, '[["ruban thermique 80x75", 2000.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L361');
select import_excel.bl('C27', '2026-07-12', null, '[["SOUS CHEMISE 250 F", 100.0, 620.0], ["chEMISE DOSSIER 100 F", 100.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L368');
select import_excel.bl('C27', '2026-07-13', null, '[["SOUS CHEMISE UNIS 250 F", 50.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L375');
select import_excel.pay('C27', '2026-07-13', 200000, 'especes', '(Excel Feuil1 L382)', null, null);
select import_excel.bl('C27', '2026-07-19', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 15.0, 2700.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L384');
select import_excel.pay('C27', '2026-07-22', 100000, 'especes', '(Excel Feuil1 L391)', null, null);
select import_excel.bl('C27', '2026-08-02', null, '[["POCHETTE DESSIN BLANCHE", 1000.0, 18.0], ["chEMISE DOSSIER 100 F", 100.0, 730.0], ["POCHETTE DESSIN COULEUR", 1000.0, 23.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L393');
select import_excel.pay('C27', '2026-08-02', 100000, 'especes', '(Excel Feuil1 L400)', null, null);
select import_excel.bl('C27', '2026-08-18', null, '[["SOUS CHEMISE UNIS 250 F", 70.0, 620.0], ["CHEMISE DOSSIER 100 F", 240.0, 730.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L402');
select import_excel.pay('C27', '2026-08-18', 200000, 'especes', '(Excel Feuil1 L409)', null, null);
select import_excel.bl('C27', '2026-08-19', null, '[["POCHETTE DESSIN COULEUR", 2500.0, 23.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L411');
select import_excel.bl('C27', '2026-08-27', null, '[["SOUS CHEMISE UNIS 250 F", 100.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L418');
select import_excel.bl('C27', '2026-09-07', null, '[["CHEMISE DOSSIER 100 F", 100.0, 730.0], ["ROULEAU TIREUSE DE PLAN 150 M", 20.0, 2700.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L425');
select import_excel.pay('C27', '2026-09-07', 200000, 'especes', '(Excel Feuil1 L432)', null, null);
select import_excel.pay('C27', '2026-09-16', 100000, 'especes', '(Excel Feuil1 L434)', null, null);
select import_excel.bl('C27', '2026-09-21', null, '[["SOUS CHEMISE 250 F", 100.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L436');

-- ---------------------------------------------------------------------------
--  C28 · PAPETRIE HAMEDI  (Feuil1, colonnes 163-168)
--  solde de départ 0.00 DA · solde final Excel 320 000.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C28', '2024-10-29', null, '[["SOUS CHEMISE 250 F", 150.0, 710.0], ["CHEMISE DOSSIER 100 F", 150.0, 770.0], ["BRISTOL UNIS A4", 350.0, 300.0], ["ROULEAU TRACEUR 50 M", 10.0, 1100.0], ["ROULEAU TIREAUSE DE PLAN 150 M", 5.0, 3350.0], ["POCHETTE DESIN COULEUR", 1500.0, 23.7]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.pay('C28', '2024-11-29', 200000, 'especes', '(Excel Feuil1 L21)', null, null);
select import_excel.bl('C28', '2024-11-14', null, '[["CHEMISE DOSSIER 100 F", 100.0, 770.0], ["SOUS CHEMISE 250F", 100.0, 710.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L23');
select import_excel.pay('C28', '2024-11-14', 148000, 'especes', '(Excel Feuil1 L30)', null, null);
select import_excel.bl('C28', '2024-12-03', null, '[["CHEMISE DOSSIER 100 F", 42.0, 770.0], ["SOUS CHEMISE 250F", 200.0, 710.0], ["POCHETTE DESIN COULEUR", 2000.0, 23.7]]'::jsonb, 0, null, 'Import Excel Feuil1 L32');
select import_excel.pay('C28', '2024-12-03', 300000, 'especes', '(Excel Feuil1 L39)', null, null);
select import_excel.bl('C28', '2024-12-15', null, '[["ROULEAU TABLE TRACANTE 50 M", 20.0, 1100.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L41');
select import_excel.pay('C28', '2024-12-15', 70000, 'especes', '(Excel Feuil1 L48)', null, null);
select import_excel.bl('C28', '2024-12-15', null, '[["chemise dossier 100 f", 100.0, 740.0], ["Sous Chemise 250 f", 100.0, 680.0], ["BRISTOL UNIS A4 BLEU", 20.0, 320.0], ["BRISTOL UNIS A4 ROSE", 20.0, 320.0], ["BRISTOL UNIS A4 VERT", 20.0, 320.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L50');
select import_excel.pay('C28', '2024-12-31', 200000, 'especes', '(Excel Feuil1 L58)', null, null);
select import_excel.bl('C28', '2025-01-07', null, '[["RUBAN THERMIQUE 80X75", 720.0, 150.0], ["ROULEAU TABLE TRACANTE 50 M", 20.0, 1060.0], ["ROULEAU TIREUSE DE PLAN 150 M", 10.0, 3150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L60');
select import_excel.pay('C28', '2025-01-07', 185940, 'especes', '(Excel Feuil1 L67)', null, null);
select import_excel.bl('C28', '2025-02-11', null, '[["CHEMISE DOSSIER 100 F", 100.0, 740.0], ["SOUS CHEMISE 250 F", 100.0, 680.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L69');
select import_excel.pay('C28', '2025-02-11', 100000, 'especes', '(Excel Feuil1 L76)', null, null);
select import_excel.bl('C28', '2025-03-09', null, '[["CHEMISE DOSSIER 100 F", 50.0, 740.0], ["POCHETTE DESSIN COULEUR", 2500.0, 23.7]]'::jsonb, 0, null, 'Import Excel Feuil1 L78');
select import_excel.pay('C28', '2025-03-09', 138250, 'especes', '(Excel Feuil1 L85)', null, null);
select import_excel.bl('C28', '2025-04-10', null, '[["ROULEAU TABLE TRACANTE 50 M", 20.0, 1060.0], ["ROULEAU TIREUSE DE PLAN 150 M", 10.0, 3150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L87');
select import_excel.pay('C28', '2025-04-10', 42100, 'especes', '(Excel Feuil1 L94)', null, null);
select import_excel.bl('C28', '2025-04-21', null, '[["ROULEAU TABLE TRACANTE 50 M", 20.0, 1060.0], ["ROULEAU TIREUSE DE PLAN 150 M", 10.0, 3150.0], ["chemise dossier 100 f", 100.0, 740.0], ["SOUS CHEMISE 250 F", 100.0, 680.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L96');
select import_excel.pay('C28', '2025-04-21', 205300, 'especes', '(Excel Feuil1 L103)', null, null);
select import_excel.bl('C28', '2025-05-13', null, '[["chemise dossier 100 f", 100.0, 680.0], ["SOUS CHEMISE 250 F", 100.0, 740.0], ["RUBAN THERMIQUE 80X75", 480.0, 150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L105');
select import_excel.pay('C28', '2025-05-13', 100000, 'especes', '(Excel Feuil1 L112)', null, null);
select import_excel.bl('C28', '2025-05-15', null, '[["ROULEAU FAX 25 M", 168.0, 158.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L114');
select import_excel.pay('C28', '2025-05-15', 26544, 'especes', '(Excel Feuil1 L121)', null, null);
select import_excel.bl('C28', '2025-05-27', null, '[["ROULEAU TABLE TRACANTE 50 M", 40.0, 1060.0], ["ROULEAU TIREUSE DE PLAN 150 M", 10.0, 3150.0], ["BRISTOL UNIS JAUNE", 20.0, 260.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L123');
select import_excel.pay('C28', '2025-05-27', 193100, 'especes', '(Excel Feuil1 L130)', null, null);
select import_excel.bl('C28', '2025-06-22', null, '[["ROULEAU TABLE TRACANTE 50 M", 20.0, 1050.0], ["SCHEMISE DOSSIER 100 F", 100.0, 730.0], ["SOUS CHEMISE 250 F", 200.0, 660.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L132');
select import_excel.pay('C28', '2025-06-22', 226000, 'especes', '(Excel Feuil1 L139)', null, null);
select import_excel.bl('C28', '2025-07-13', null, '[["RUBAN THERMIQUE 80X75", 240.0, 150.0], ["SCHEMISE DOSSIER 100 F", 300.0, 720.0], ["SOUS CHEMISE 250 F", 200.0, 650.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L141');
select import_excel.pay('C28', '2025-07-13', 382000, 'especes', '(Excel Feuil1 L148)', null, null);
select import_excel.bl('C28', '2025-07-13', null, '[["POCHETTE DESSIN COULEUR", 2500.0, 22.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L150');
select import_excel.bl('C28', '2025-08-04', null, '[["POCHETTE DESSIN COULEUR", 5000.0, 22.0], ["CHEMISE DOSSIER 100 F", 400.0, 690.0], ["SOUS CHEMISE 250 F", 400.0, 620.0], ["POCHETTE DESSIN BLANCHE", 1550.0, 18.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L157');
select import_excel.pay('C28', '2025-07-13', 200000, 'especes', '(Excel Feuil1 L164)', null, null);
select import_excel.bl('C28', '2025-08-05', null, '[["POCHETTE DESSIN COULEUR", 12500.0, 22.0], ["CHEMISE DOSSIER 100 F", 300.0, 690.0], ["SOUS CHEMISE 250 F", 300.0, 620.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L166');
select import_excel.pay('C28', '2025-08-04', 1500000, 'especes', '(Excel Feuil1 L173)', null, null);
select import_excel.bl('C28', '2025-09-18', null, '[["POCHETTE DESSIN BLANCHE", 7050.0, 18.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L175');
select import_excel.bl('C28', '2025-11-19', null, '[["SOUS CHEMISE 250 F", 200.0, 620.0], ["CHEMISE DOSSIER 100 F", 100.0, 690.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L182');
select import_excel.pay('C28', '2025-11-19', 5000, 'especes', '(Excel Feuil1 L189)', null, null);
select import_excel.charge('C28', '2025-11-19', 'Ajustement de solde (écart Excel)', 200, 'écart du fichier Excel Feuil1 L190 : solde calculé -200.00  solde écrit 0.00');
select import_excel.bl('C28', '2025-12-10', null, '[["SOUS CHEMISE 250 F", 200.0, 620.0], ["CHEMISE DOSSIER 100 F", 200.0, 690.0], ["ETIQUETTE 20X40", 100.0, 195.0], ["RUBAN THERMIQUE 80X75", 250.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L191');
select import_excel.pay('C28', '2025-12-10', 262000, 'especes', '(Excel Feuil1 L198)', null, null);
select import_excel.bl('C28', '2025-12-31', null, '[["SOUS CHEMISE 250 F", 300.0, 620.0], ["CHEMISE DOSSIER 100 F", 300.0, 690.0], ["ROULEAU TABLE TRACANTE 50 M", 20.0, 880.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L200');
select import_excel.pay('C28', '2025-12-30', 200000, 'especes', '(Excel Feuil1 L207)', null, null);
select import_excel.bl('C28', '2026-02-24', null, '[["SOUS CHEMISE 250 F", 300.0, 610.0], ["CHEMISE DOSSIER 100 F", 150.0, 690.0], ["ROULEAU TABLE TRACANTE 50 M", 40.0, 870.0], ["POCHETTE DESSIN COULEUR", 3000.0, 23.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L209');
select import_excel.pay('C28', '2026-02-24', 300000, 'especes', '(Excel Feuil1 L216)', null, null);
select import_excel.bl('C28', '2026-04-23', null, '[["SOUS CHEMISE 250 F", 250.0, 610.0], ["CHEMISE DOSSIER 100 F", 300.0, 690.0], ["RUBAN THERMIQUE 80X75", 500.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L218');
select import_excel.pay('C28', '2026-04-23', 300000, 'especes', '(Excel Feuil1 L225)', null, null);
select import_excel.pay('C28', '2026-06-17', 484900, 'especes', '(Excel Feuil1 L227)', null, null);
select import_excel.bl('C28', '2026-09-23', null, '[["RUBAN THERMIQUE 80X60", 2000.0, 90.0], ["RUBAN THERMIQUE 80X75", 1000.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L229');

-- ---------------------------------------------------------------------------
--  C29 · TAZIRI SEDDIK  (Feuil1, colonnes 169-174)
--  solde de départ 0.00 DA · solde final Excel 915 635.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C29', '2025-02-27', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 100.0, 3100.0], ["RUBAN THERMIQUE 80X75", 2400.0, 145.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.bl('C29', '2025-04-30', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 100.0, 2950.0], ["RUBAN THERMIQUE 80X75", 2400.0, 145.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L15');
select import_excel.bl('C29', '2025-05-04', null, '[["RUBAN THERMIQUE 80X75", 2400.0, 145.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L21');
select import_excel.bl('C29', '2025-05-13', null, '[["CHEMISE DOSSIER 100 F", 500.0, 710.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L27');
select import_excel.bl('C29', '2025-06-15', null, '[["RUBAN THERMIQUE 80X75", 4368.0, 145.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L33');
select import_excel.bl('C29', '2025-07-28', null, '[["RUBAN THERMIQUE 80X75", 4800.0, 145.0], ["Rouleau Tireuse de plan 150 m", 100.0, 2700.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L39');
select import_excel.pay('C29', '2025-03-04', 648000, 'especes', '(Excel Feuil1 L45)', null, null);
select import_excel.pay('C29', '2025-03-04', 1494000, 'especes', '(Excel Feuil1 L47)', null, null);
select import_excel.bl('C29', '2025-08-23', null, '[["RUBAN THERMIQUE 80X75", 4800.0, 145.0], ["RUBAN THERMIQUE 57X30", 400.0, 29.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L49');
select import_excel.pay('C29', '2025-08-23', 1500000, 'especes', '(Excel Feuil1 L55)', null, null);
select import_excel.pay('C29', '2025-08-30', 668960, 'especes', '(Excel Feuil1 L57)', null, null);
select import_excel.bl('C29', '2025-10-05', null, '[["RUBAN THERMIQUE 80X75", 3250.0, 140.0], ["Rouleau Tireuse de plan 150 m", 100.0, 2700.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L59');
select import_excel.bl('C29', '2025-11-16', null, '[["RUBAN THERMIQUE 80X75", 7500.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L65');
select import_excel.bl('C29', '2025-11-19', null, '[["RUBAN THERMIQUE 80X75", 3000.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L71');
select import_excel.pay('C29', '2025-11-30', 1000000, 'especes', '(Excel Feuil1 L77)', null, null);
select import_excel.bl('C29', '2025-12-29', null, '[["rouleau etiquette 58x45", 931.0, 235.0], ["rouleau etiquette 20x40 (2000)", 2000.0, 180.0], ["rouleau etiquette 20x40 (1500 )", 600.0, 150.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L79');
select import_excel.pay('C29', '2026-01-21', 1760000, 'especes', '(Excel Feuil1 L85)', null, null);
select import_excel.bl('C29', '2026-02-17', null, '[["RUBAN THERMIQUE 80X75", 5750.0, 135.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L87');
select import_excel.bl('C29', '2026-02-19', null, '[["RUBAN THERMIQUE 80X75", 4500.0, 135.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L93');
select import_excel.bl('C29', '2026-03-15', null, '[["rouleau etiquette 58x45", 480.0, 235.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L99');
select import_excel.bl('C29', '2026-03-25', null, '[["rouleau etiquette 58x45", 240.0, 235.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L105');
select import_excel.pay('C29', '2026-04-12', 800000, 'especes', '(Excel Feuil1 L111)', null, null);
select import_excel.bl('C29', '2026-06-04', null, '[["rouleau etiquette 58x45", 384.0, 240.0], ["RUBAN THERMIQUE 80X75", 2500.0, 138.0], ["ROULEAU ETIQUETTE 20X40", 1400.0, 185.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L113');
select import_excel.pay('C29', '2026-06-21', 1060000, 'especes', '(Excel Feuil1 L119)', null, null);
select import_excel.bl('C29', '2026-06-24', null, '[["rouleau etiquette 58x45", 288.0, 240.0], ["RUBAN THERMIQUE 80X75", 4000.0, 138.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L121');
select import_excel.bl('C29', '2026-07-06', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 150.0, 2550.0], ["RUBAN THERMIQUE 80X75", 1000.0, 138.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L127');
select import_excel.pay('C29', '2026-07-14', 1000000, 'especes', '(Excel Feuil1 L133)', null, null);
select import_excel.bl('C29', '2026-08-20', null, '[["RUBAN THERMIQUE 80X40", 196.0, 40.0], ["RUBAN THERMIQUE 80X75", 1250.0, 138.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L135');
select import_excel.bl('C29', '2026-08-23', null, '[["RUBAN THERMIQUE 80X40", 1862.0, 40.0], ["RUBAN THERMIQUE 80X75", 3350.0, 138.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L141');
select import_excel.bl('C29', '2026-09-16', null, '[["rouleau etiquette 58x45", 2400.0, 235.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L147');
select import_excel.pay('C29', '2026-09-21', 1000000, 'especes', '(Excel Feuil1 L153)', null, null);

-- ---------------------------------------------------------------------------
--  C30 · PAPETRIE MESBAH  (Feuil1, colonnes 175-180)
--  solde de départ 0.00 DA · solde final Excel 5 400.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C30', '2025-09-03', null, '[["RUBAN THERMIQUE 80X75", 1536.0, 145.0], ["CHEMISE DOSSIER 100F", 470.0, 690.0], ["SOUS CHEMISE 250 F", 330.0, 620.0], ["RUBAN THERMIQUE 80X40", 588.0, 50.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.pay('C30', '2025-09-03', 500000, 'especes', '(Excel Feuil1 L15)', null, null);
select import_excel.bl('C30', '2025-10-09', null, '[["RUBAN THERMIQUE 80X75", 2400.0, 140.0], ["SOUS CHEMISE 250 F", 500.0, 600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L17');
select import_excel.pay('C30', '2025-10-09', 281020, 'especes', '(Excel Feuil1 L24)', null, null);
select import_excel.pay('C30', '2025-10-09', 636000, 'especes', '(Excel Feuil1 L26)', null, null);
select import_excel.bl('C30', '2026-06-01', null, '[["SOUS CHEMISE 250 F", 200.0, 590.0], ["CHEMISE DOSSIER 100 F", 150.0, 690.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L28');
select import_excel.bl('C30', '2026-09-30', null, '[["SOUS CHEMISE 250 F", 370.0, 600.0], ["CHEMISE DOSSIER 100 F", 267.0, 700.0], ["RUBAN THERMIQUE 80X75", 1250.0, 140.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L35');
select import_excel.pay('C30', '2026-09-30', 800000, 'especes', '(Excel Feuil1 L42)', null, null);

-- ---------------------------------------------------------------------------
--  C31 · TPV  (Feuil1, colonnes 181-186)
--  solde de départ 0.00 DA · solde final Excel 0.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C31', '2026-08-12', null, '[["ETIQUETTE 50X30", 600.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.bl('C31', '2026-08-19', null, '[["ROULEAU THERMIQUE 80X75", 5000.0, 128.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L12');
select import_excel.bl('C31', '2026-08-20', null, '[["rouleau etiquette 58x45", 1100.0, 217.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L17');
select import_excel.pay('C31', '2026-08-20', 959000, 'especes', '(Excel Feuil1 L22)', null, null);
select import_excel.bl('C31', '2026-08-20', null, '[["rouleau etiquette 50x30", 1000.0, 170.0], ["ruban thermique 80x75", 5000.0, 128.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L24');
select import_excel.pay('C31', '2026-08-24', 750000, 'especes', '(Excel Feuil1 L29)', null, null);
select import_excel.bl('C31', '2026-09-02', null, '[["ruban thermique 80x75", 1800.0, 128.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L31');
select import_excel.pay('C31', '2026-09-02', 550000, 'especes', '(Excel Feuil1 L36)', null, null);
select import_excel.bl('C31', '2026-09-02', null, '[["rouleau etiquette 100x60", 1250.0, 188.0], ["ruban thermique 80x75", 500.0, 128.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L38');
select import_excel.pay('C31', '2026-09-08', 171700, 'especes', '(Excel Feuil1 L43)', null, null);
select import_excel.bl('C31', '2026-09-14', null, '[["rouleau etiquette 100x60", 250.0, 188.0], ["ruban thermique 80x75", 2500.0, 128.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L45');
select import_excel.pay('C31', '2026-09-20', 256400, 'especes', '(Excel Feuil1 L50)', null, null);

-- ---------------------------------------------------------------------------
--  C32 · BEN YAMINA  (Feuil1, colonnes 187-192)
--  solde de départ 0.00 DA · solde final Excel -403 249.07 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C32', '2025-12-17', null, '[["ROULEAU ETIQUETTE 35X45", 800.0, 190.0], ["SOUS CHEMISE UNIS", 192.0, 600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.bl('C32', '2025-12-31', null, '[["ROULEAU ETIQUETTE 100X60", 500.0, 220.0], ["RUBAN THERMIQUE 80X60", 1500.0, 85.0], ["ROULEAU FAX 25", 480.0, 160.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L15');
select import_excel.bl('C32', '2026-01-15', null, '[["SOUS CHEMISE 250 F", 192.0, 600.0], ["ROULEAU ETIQUETTE 20X40", 1200.0, 185.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L22');
select import_excel.pay('C32', '2026-01-15', 800000.25, 'especes', 'Facture N° 111 (Excel Feuil1 L29)', null, null);
select import_excel.pay('C32', '2026-01-15', 10000, 'especes', '[REMISE] REMISE (Excel Feuil1 L31)', null, null);
select import_excel.bl('C32', '2026-01-19', null, '[["ROULEAU 80x75", 4500.0, 135.0], ["rouleau etiquette 20x40", 1320.0, 180.0], ["rouleau etiquette 35x45", 1080.0, 185.0], ["ruban thermique 57x30", 900.0, 23.0], ["rouleau etiquette 100x150", 320.0, 500.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L33 · date Excel corrigée (2025-01-19)');
select import_excel.pay('C32', '2026-01-22', 930000, 'especes', '[REMISE] REMISE (Excel Feuil1 L41)', null, null);
select import_excel.bl('C32', '2026-02-03', null, '[["ROULEAU ETIQUETTE58X45", 960.0, 240.0], ["SOUS CHEMISE UNIS", 196.0, 320.0], ["ROULEAU THERMIQUE 80X30", 400.0, 34.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L43 · date Excel corrigée (2025-02-03)');
select import_excel.pay('C32', '2026-02-03', 200000, 'especes', '(Excel Feuil1 L50)', null, null);
select import_excel.pay('C32', '2026-02-03', 200000, 'especes', 'Facture N° 13 (Excel Feuil1 L52)', null, null);
select import_excel.pay('C32', '2026-02-03', 204543.82, 'especes', 'Facture N° 14 (Excel Feuil1 L54)', null, null);
select import_excel.bl('C32', '2025-02-18', null, '[["PAPIER COULEUR A 4", 182.0, 320.0], ["SOUS CHEMISE 250 F", 200.0, 600.0], ["ROULEAU ETIQUETTE 20X40", 3000.0, 180.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L56');
select import_excel.bl('C32', '2025-03-26', null, '[["ROULEAU THERMIQUE 57X30", 1800.0, 23.0], ["SOUS CHEMISE 250 F", 750.0, 600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L63');
select import_excel.pay('C32', '2025-03-26', 500000, 'especes', '(Excel Feuil1 L70) · date Excel corrigée (2026-02-26)', null, null);
select import_excel.bl('C32', '2025-04-28', null, '[["SOUS CHEMISE 250 F UNIS", 200.0, 600.0], ["ROULEAU THERMIQUE 80X75", 3000.0, 136.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L72');
select import_excel.pay('C32', '2025-04-28', 1000000, 'especes', '(Excel Feuil1 L79) · date Excel corrigée (2026-04-28)', null, null);
select import_excel.bl('C32', '2025-04-28', null, '[["ROULEAU ETIQUETTE 100X150", 160.0, 500.0], ["ROULEAU THERMIQUE 57X30", 1500.0, 23.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L81');
select import_excel.pay('C32', '2025-04-28', 200000, 'especes', '(Excel Feuil1 L88)', null, null);
select import_excel.bl('C32', '2026-05-12', null, '[["CHEMISE DOSSIER 100 F", 170.0, 690.0], ["ROULEAU ETIQUETTE 35X45", 900.0, 180.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L90');
select import_excel.pay('C32', '2026-05-12', 300000, 'especes', '(Excel Feuil1 L97)', null, null);
select import_excel.bl('C32', '2026-06-23', null, '[["SOUS CHEMISE UNIS 250 F", 200.0, 600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L99');
select import_excel.pay('C32', '2026-06-23', 120000, 'especes', '(Excel Feuil1 L106)', null, null);
select import_excel.pay('C32', '2026-06-23', 237915, 'especes', '(Excel Feuil1 L108)', null, null);
select import_excel.charge('C32', '2026-07-13', 'Frais / débit reporté', 1200000, 'Débit Excel Feuil1 L110');
select import_excel.bl('C32', '2026-07-01', null, '[["SOUS CHEMISE UNIS 250 F", 300.0, 600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L112');
select import_excel.pay('C32', '2026-07-01', 2400000, 'especes', '[AJUSTEMENT EXCEL] écart du fichier Excel Feuil1 L116 : solde calculé 1 380 000.00  solde écrit -1 020 000.00');
select import_excel.bl('C32', '2026-07-13', null, '[["SOUS CHEMISE UNIS 250 F", 450.0, 600.0], ["SOUS CHEMISE 250 F", 150.0, 600.0], ["POCHETTE DEISSIN COULEUR", 500.0, 23.5]]'::jsonb, 0, null, 'Import Excel Feuil1 L117');
select import_excel.bl('C32', '2026-08-06', null, '[["SOUS CHEMISE UNIS 250 F", 280.0, 600.0], ["rouleau etiquette 100x60", 350.0, 220.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L124');

-- ---------------------------------------------------------------------------
--  C33 · WAHAB  (Feuil1, colonnes 193-198)
--  solde de départ 0.00 DA · solde final Excel 500 310.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C33', '2025-12-15', null, '[["ROULEAU 80x75", 500.0, 142.0], ["rouleau etiquette 20x40", 500.0, 188.0], ["rouleau etiquette 35x45", 260.0, 190.0], ["SOUS CHEMISE 250 F", 25.0, 620.0], ["rouleau etiquette 100x150", 160.0, 510.0], ["CHEMISE DOSSIER 100 F", 25.0, 690.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.bl('C33', '2025-12-23', null, '[["rouleau etiquette 58x45", 288.0, 235.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L18');
select import_excel.pay('C33', '2025-12-23', 100000, 'especes', '(Excel Feuil1 L25)', null, null);
select import_excel.pay('C33', '2026-01-15', 60000, 'especes', '(Excel Feuil1 L27)', null, null);
select import_excel.bl('C33', '2026-01-25', null, '[["rouleau etiquette 58x45", 480.0, 235.0], ["etiquette 80x75", 1500.0, 142.0], ["ruban thermique 57x30", 300.0, 23.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L29');
select import_excel.bl('C33', '2026-02-10', null, '[["rouleau etiquette 20x40 (250etq)", 416.0, 120.0], ["etiquette 80x75", 500.0, 142.0], ["rouleau etiquette 100x150", 64.0, 510.0], ["rouleau etiquette 20x40", 400.0, 188.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L36');
select import_excel.bl('C33', '2026-02-17', null, '[["ROULEAU TIREUSE DE PLAN 150 M", 35.0, 2700.0], ["ROULEAU ETIQUETTE 100X150", 128.0, 510.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L43');
select import_excel.pay('C33', '2026-02-17', 60000, 'especes', '(Excel Feuil1 L50)', null, null);
select import_excel.pay('C33', '2026-03-15', 200000, 'especes', '(Excel Feuil1 L52)', null, null);
select import_excel.pay('C33', '2026-04-19', 230000, 'especes', '(Excel Feuil1 L54) · date Excel corrigée (2025-04-19)', null, null);
select import_excel.bl('C33', '2026-06-03', null, '[["rouleau tetiquette 100x150", 64.0, 510.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L56');

-- ---------------------------------------------------------------------------
--  C34 · ALICHE NOURELDINE  (Feuil1, colonnes 199-204)
--  solde de départ 0.00 DA · solde final Excel 130 000.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C34', '2026-02-23', null, '[["ROULEAU ETIQUETTE 100X150", 320.0, 470.0], ["RUBAN THERMIQUE 80X55", 350.0, 85.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.bl('C34', '2026-02-23', null, '[["ROULEAU ETIQUETTEB20X40", 200.0, 180.0], ["ROULEAU ETIQUTTE 35X45", 200.0, 180.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L15');
select import_excel.bl('C34', '2026-02-23', null, '[["ROULEAU 80X60", 650.0, 85.0], ["ROULEAU 57X75", 35.0, 110.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L22');
select import_excel.pay('C34', '2026-03-02', 311250, 'especes', '(Excel Feuil1 L29)', null, null);
select import_excel.pay('C34', '2026-03-02', 1030000, 'especes', '(Excel Feuil1 L31)', null, null);
select import_excel.bl('C34', '2026-04-09', null, '[["rouleau etiquette 20x40", 960.0, 170.0], ["rouleau etiquette 35x45", 200.0, 170.0], ["rouleau etiquette 58x45 230 da", 480.0, 218.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L33');
select import_excel.bl('C34', '2026-04-16', null, '[["ROULEAU 57X75", 200.0, 110.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L40');
select import_excel.bl('C34', '2026-04-21', null, '[["RUBAN THERMIQUE 20X40 (20 ps)", 600.0, 170.0], ["RUBAN THERMIQUE35X45", 200.0, 170.0], ["ROULEAU ETIQUETTE 20X40 (96 ps)", 960.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L47');
select import_excel.bl('C34', '2026-04-27', null, '[["ROULEAU ETIQUETTE 100X60 (26 ps)", 260.0, 630.0], ["RUBAN THERMIQUE80X75", 500.0, 130.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L54');
select import_excel.bl('C34', '2026-05-10', null, '[["ROULEAU ETIQUETTE100X150", 288.0, 450.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L61');
select import_excel.bl('C34', '2026-05-18', null, '[["ROULEAU ETIQUETTE20X40", 960.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L68');
select import_excel.bl('C34', '2026-06-01', null, '[["ROULEAU ETIQUETTE20X40 96 PS", 1440.0, 170.0], ["ROULEAU ETIQUETTE 20X40 20 PS", 400.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L75');
select import_excel.pay('C34', '2026-06-01', 427440, 'especes', '(Excel Feuil1 L82)', null, null);
select import_excel.bl('C34', '2026-06-01', null, '[["RUBAN THERMIQUE75X75", 21.0, 160.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L84');
select import_excel.bl('C34', '2026-06-01', null, '[["ROULEAU ETIQUETTE 20X40", 1440.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L91');
select import_excel.bl('C34', '2026-06-01', null, '[["ROULEAU ETIQUETTE 20X40", 400.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L98');
select import_excel.pay('C34', '2026-07-12', 60000, 'especes', '(Excel Feuil1 L105)', null, null);
select import_excel.bl('C34', '2026-07-12', null, '[["ROULEAU ETIQUETTE 20X40", 960.0, 170.0], ["ROULEAU ETIQUETTE 100X150", 320.0, 450.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L107');
select import_excel.bl('C34', '2026-07-12', null, '[["ROULEAU ETIQUETTE 20X40", 960.0, 170.0], ["ROULEAU ETIQUETTE 100X150", 320.0, 450.0], ["ruban thermique 80x75", 500.0, 130.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L114');
select import_excel.pay('C34', '2026-07-20', 935560, 'especes', '(Excel Feuil1 L121)', null, null);
select import_excel.bl('C34', '2026-08-03', null, '[["ROULEAU ETIQUETTE 20X40", 1920.0, 170.0], ["ROULEAU ETIQUETTE 20X40", 600.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L123');
select import_excel.bl('C34', '2026-08-06', null, '[["ruban thermique 80x75", 600.0, 130.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L130');
select import_excel.bl('C34', '2026-08-18', null, '[["ROULEAU ETIQUETTE 20X40", 384.0, 170.0], ["ROULEAU ETIQUETTE 50X30", 320.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L137');
select import_excel.bl('C34', '2026-08-19', null, '[["ROULEAU ETIQUETTE 20X40", 960.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L144');
select import_excel.pay('C34', '2026-08-23', 500000, 'especes', '(Excel Feuil1 L151)', null, null);
select import_excel.bl('C34', '2026-08-23', null, '[["ROULEAU ETIQUETTE 20X40", 1152.0, 170.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L153');
select import_excel.pay('C34', '2026-09-02', 485120, 'especes', '(Excel Feuil1 L160)', null, null);
select import_excel.bl('C34', '2026-09-02', null, '[["ruban thermique 80x75", 1000.0, 130.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L162');

-- ---------------------------------------------------------------------------
--  C35 · OUSSALMA  (Feuil1, colonnes 205-210)
--  solde de départ 0.00 DA · solde final Excel 26 085.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C35', '2026-02-23', null, '[["ROULEAU ETIQUETTE 100X150", 2272.0, 470.0], ["ROUELAU ETIQUETTE 20X40", 200.0, 175.0], ["RUBAN THERMIQUE 80X75", 500.0, 135.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.pay('C35', '2026-05-06', 1100000, 'especes', '(Excel Feuil1 L15)', null, null);
select import_excel.bl('C35', '2026-05-17', null, '[["ROULEAU ETIQUETTE35X45", 600.0, 175.0], ["RUBANTHERMIQUE 80X40", 686.0, 39.0], ["ROULEAU ETIQUETTE 100X150", 64.0, 470.0], ["RUBAN THERMIQUE 80X75", 50.0, 135.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L17');
select import_excel.pay('C35', '2026-05-17', 470000, 'especes', '(Excel Feuil1 L24)', null, null);
select import_excel.pay('C35', '2026-05-17', 231076, 'especes', 'avance (Excel Feuil1 L25)', null, null);
select import_excel.bl('C35', '2026-05-20', null, '[["ROULEAU ETIQUETTE35X45", 400.0, 175.0], ["RUBANTHERMIQUE 80X75", 1000.0, 125.0], ["ROULEAU ETIQUETTE 100X150", 640.0, 470.0], ["RUBAN THERMIQUE 80X75", 2000.0, 135.0], ["ROULEUZ ETIQUETTE 20X40", 1000.0, 175.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L26');
select import_excel.charge('C35', '2026-05-20', 'Ajustement de solde (écart Excel)', 231076, 'écart du fichier Excel Feuil1 L33 : solde calculé 478 648.00  solde écrit 709 724.00');
select import_excel.pay('C35', '2026-05-20', 700000, 'especes', '(Excel Feuil1 L34)', null, null);
select import_excel.bl('C35', '2026-06-03', null, '[["ROULEAU ETIQUETTE 50X30", 432.0, 185.0], ["RUBANTHERMIQUE 80X75", 2500.0, 140.0], ["ROULEAU ETIQUETTE 58X45", 2400.0, 225.0], ["RUBAN THERMIQUE 57X50", 150.0, 55.0], ["ROULEUZ ETIQUETTE 20X40", 1200.0, 180.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L36');
select import_excel.pay('C35', '2026-06-03', 840000, 'especes', '(Excel Feuil1 L44)', null, null);
select import_excel.bl('C35', '2026-06-11', null, '[["PAPIER THERMIQUE A 4", 300.0, 280.0], ["RUBAN THERMIQUE 80X40", 2106.0, 39.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L46');
select import_excel.pay('C35', '2026-06-14', 400000, 'especes', '(Excel Feuil1 L53)', null, null);
select import_excel.pay('C35', '2026-07-16', 130028, 'especes', '(Excel Feuil1 L55)', null, null);
select import_excel.bl('C35', '2026-07-30', null, '[["ROULEAU ETIQUETTE 58X45", 432.0, 230.0], ["ROULEAU ETIQUETTE 20X40", 4000.0, 172.0], ["ROULEAU ETIQUETTE 100X60", 312.0, 640.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L57');
select import_excel.pay('C35', '2026-07-30', 900000, 'especes', '(Excel Feuil1 L64)', null, null);
select import_excel.bl('C35', '2026-08-09', null, '[["ROULEAU ETIQUETTE 100X150", 1216.0, 450.0], ["ROUELAU ETIQUETTE 35X45", 880.0, 175.0], ["RUBAN THERMIQUE 80X75", 1000.0, 135.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L66');
select import_excel.pay('C35', '2026-08-09', 690000, 'especes', '(Excel Feuil1 L73)', null, null);
select import_excel.bl('C35', '2026-08-19', null, '[["ROULEAU ETIQUETTE 35X45", 1000.0, 175.0], ["ROUELAU ETIQUETTE 58X45", 100.0, 230.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L75');
select import_excel.pay('C35', '2026-08-19', 570000, 'especes', '(Excel Feuil1 L82)', null, null);
select import_excel.bl('C35', '2026-08-20', null, '[["ROULEAU ETIQUETTE 35X45", 600.0, 175.0], ["ROUELAU ETIQUETTE 58X45", 1920.0, 225.0], ["ROULEAU ETIQUETTE 100X150", 736.0, 450.0], ["ROULEAU THERMIQUE 57X40", 3675.0, 35.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L84');
select import_excel.pay('C35', '2026-08-20', 900000, 'especes', '(Excel Feuil1 L91)', null, null);
select import_excel.bl('C35', '2026-09-01', null, '[["ROULEAU ETIQUETTE 50X30", 1470.0, 170.0], ["RUBAN THERMIQUE 80X75", 2500.0, 135.0], ["ROULEAU ETIQUETTE 100X150", 640.0, 470.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L93');
select import_excel.pay('C35', '2026-09-01', 800000, 'especes', '(Excel Feuil1 L100)', null, null);
select import_excel.bl('C35', '2026-09-12', null, '[["RUBAN THERMIQUE 80X40", 3360.0, 39.0], ["RUBAN THERMIQUE 80X40 ECG", 2842.0, 100.0], ["ROULEAU ETIQUETTE 100X60 1000ETQ", 480.0, 640.0], ["ROULEAU ETIQUETTE 100X150", 864.0, 470.0], ["RUBAN THERMIQUE 80X75", 1500.0, 135.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L102');
select import_excel.pay('C35', '2026-09-12', 1100000, 'especes', '(Excel Feuil1 L110)', null, null);
select import_excel.bl('C35', '2026-09-14', null, '[["etiquette 58x45", 500.0, 235.0], ["etiqeutte 100x150", 256.0, 470.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L112');
select import_excel.pay('C35', '2026-09-12', 600000, 'especes', '(Excel Feuil1 L119)', null, null);
select import_excel.bl('C35', '2026-09-17', null, '[["ROULEAU ETIQUETTE 100X150", 960.0, 470.0], ["ROULEAU ETIQUETTE 58X45 (48)", 432.0, 235.0], ["ROULEAU ETIQUETTE 58X45 (50)", 700.0, 235.0], ["ROULEAU ETIQUETTE 35X45", 1260.0, 185.0], ["ROULEAU ETIQUETTE 20X40", 900.0, 185.0], ["RUBAN THERMIQUE 57X75", 240.0, 130.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L121');
select import_excel.pay('C35', '2026-09-20', 1000000, 'especes', '(Excel Feuil1 L131)', null, null);
select import_excel.bl('C35', '2026-09-22', null, '[["etiqeutte 100x150", 576.0, 470.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L133');
select import_excel.pay('C35', '2026-09-22', 270000, 'especes', '(Excel Feuil1 L140)', null, null);
select import_excel.bl('C35', '2026-09-26', null, '[["etiqeutte 100x150 300 ETQ", 608.0, 470.0], ["ROULEAU ETIQUETTE 100X150 400 ETQ", 286.0, 630.0], ["ROULEAU ETIQUETTE 58X45", 240.0, 230.0], ["RUBAN THERMIQUE 80X75", 2500.0, 135.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L142');
select import_excel.bl('C35', '2026-09-28', null, '[["etiqeutte 20X40", 560.0, 185.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L149');
select import_excel.pay('C35', '2026-09-28', 1000000, 'especes', '(Excel Feuil1 L156)', null, null);

-- ---------------------------------------------------------------------------
--  C36 · ABDSELAM  (Feuil1, colonnes 211-216)
--  solde de départ 0.00 DA · solde final Excel 0.00 DA
-- ---------------------------------------------------------------------------
select import_excel.bl('C36', '2026-02-23', null, '[["SOUS CHEMISE 250 F", 130.0, 600.0], ["SOUS CHEMISE 250 F UNIS", 40.0, 600.0], ["CHEMISE DOSSIER 100 F", 100.0, 700.0], ["ROULEAU TABLE TRACANTE 50 M", 20.0, 860.0], ["ROULEAU TIREUSE DE PLAN 150 M", 10.0, 2600.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L9');
select import_excel.bl('C36', '2026-10-01', null, '[["SOUS CHEMISE 250 F", 255.0, 590.0], ["SOUS CHEMISE 250 F UNIS", 40.0, 590.0], ["CHEMISE DOSSIER 100 F", 182.0, 690.0], ["bristol unis a 4", 295.0, 290.0], ["ROULEAU TIREUSE DE PLAN 150 M", 36.0, 2550.0], ["ROULEAU TABLE TRACANTE 50 M", 70.0, 860.0]]'::jsonb, 0, null, 'Import Excel Feuil1 L16');
select import_excel.pay('C36', '2026-10-01', 752380, 'especes', '(Excel Feuil1 L27)', null, null);


commit;
