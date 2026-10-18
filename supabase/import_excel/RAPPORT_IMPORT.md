# Import de SITUATION.xlsx — rapport

Généré à partir de `SITUATION.xlsx` (feuilles **Feuil1**, **Situation client**, **ACHAT**). Les scripts SQL de ce dossier créent toutes ces données dans l'application. Le script a été exécuté de bout en bout sur une copie vide du schéma de l'application (`supabase/papeterie_supabase_full.sql`) : **aucune erreur, et le solde net de chacun des 52 clients dans l'application est identique au dernier « Reste à payer » d'Excel**.

## Ordre d'exécution (éditeur SQL Supabase)

| # | Fichier | Contenu |
|---|---|---|
| 1 | `00_preparation.sql` | schéma temporaire `import_excel` + fonctions d'import (appellent les fonctions internes de l'application) |
| 2 | `01_clients.sql` | création des 52 clients (un client existant portant le même nom est réutilisé) |
| 3 | `02_clients_mouvements_partie1..5.sql` | bons de livraison, versements, soldes de départ — feuille Feuil1 |
| 4 | `03_clients_2019_feuille_situation.sql` | 16 clients présents seulement dans la feuille « Situation client » (2019) |
| 5 | `04_fournisseurs.sql` | fournisseurs, factures d'achat et règlements — feuille ACHAT |
| 6 | `99_finalisation.sql` | retire de la caisse les versements importés, renumérote les BL / factures importés par date, affiche le contrôle des soldes |
| — | `05_optionnel_2019_TAZIRI_AL_SULTANE.sql` | facultatif, voir plus bas |
| — | `99_annulation_import.sql` | annule TOUT l'import (testé : la base revient exactement à son état d'avant) |

`IMPORT_COMPLET.sql` contient les fichiers 1 → 6 à la suite (1 Mo) si vous préférez un seul fichier (≈ 1 min 30 sur un PC ; si l'éditeur Supabase coupe, utilisez les fichiers séparés, chacun < 40 s). Chaque fichier est une transaction : en cas d'erreur rien n'est enregistré. Un fichier déjà exécuté est refusé s'il est relancé (pas de doublons).

## Correspondance Excel → application

| Dans Excel | Dans l'application |
|---|---|
| Colonne client (Nom, Adresse) | `clients` (note = feuille et colonnes d'origine) |
| Bloc « BLN° / DATE / Désignation / Quant. / P.U / Mont » | commande **historique** finalisée (`commands` + `command_items`) → bon de livraison historique (`command_deliveries`, badge « Ancienne ») → sa facture (`sales` + `sale_lines`). N° de BL Excel = `bon_number`. Aucun mouvement de stock, aucune production automatique, aucune caisse. |
| Ligne « v … Verssement / cheque / virement / espèce » | `client_payments` (mode espèces / chèque / virement, banque et n° de chèque quand Excel les donne) imputé comme dans l'application : anciennes dettes → factures les plus anciennes → acompte. |
| Premier « Reste à payer » (solde reporté d'avant) | `party_old_debts` « Solde antérieur reporté » (ou acompte si négatif) |
| Bloc « achat » chez le client, REMISE, RETOUR | versement non encaissé noté `[COMPENSATION ACHAT]`, `[REMISE]`, `[RETOUR MARCHANDISE]` |
| Frais refacturés (transport, chauffeur, machine…), versement négatif | vente historique d'une ligne |
| Erreur de formule du fichier (solde écrit ≠ calcul) | `[AJUSTEMENT EXCEL]` (versement) ou « Ajustement de solde (écart Excel) » (vente) pour retomber exactement sur le solde écrit — liste complète ci-dessous |
| Feuille ACHAT | `suppliers`, `purchases` historiques (TVA 19 % quand le total Excel est T.T.C.), `supplier_payments` |

## Volumes importés

- **52 clients** (36 de Feuil1, 16 de « Situation client »)
- **3991 bons de livraison** (7909 lignes produits) = 3991 commandes + 3991 factures
- **2630 versements clients** (+ 38 compensations / retours / remises)
- 11 soldes de départ, 8 débits divers, 34 ajustements d'écart Excel
- **7 fournisseurs**, 34 factures d'achat, 15 règlements
- Contrôle : 6534 « Reste à payer » d'Excel vérifiés un par un pendant la lecture.

## Clients — solde final (= dernier « Reste à payer » Excel)

| Clé | Client | Période | BL | Versements | Solde de départ | Solde final |
|---|---|---|---:|---:|---:|---:|
| C01 | PAP EL BASMALA | 2019-11-04 → 2026-09-14 | 302 | 189 | 1 701 295,00 | **994 776,50** |
| C02 | PAP EL AMEL (AEK) | 2023-02-07 → 2026-09-22 | 85 | 49 | 0,00 | **74 517,00** |
| C03 | DAR EL KALEM | 2019-09-30 → 2026-09-28 | 601 | 274 | 10 295 130,00 | **1 347 991,20** |
| C04 | PAP YAHIA (kayed) | 2019-10-25 → 2026-10-11 | 180 | 165 | 310 650,00 | **151 320,00** |
| C05 | IMDB (yazid) | 2019-07-10 → 2024-11-19 | 42 | 25 | 436 363,41 | **396 500,01** |
| C06 | NACER  BOUHADJAM | 2019-12-16 → 2026-09-29 | 337 | 278 | 879 685,00 | **1 671 917,01** |
| C07 | YA PAP | 2021-08-11 → 2026-10-08 | 186 | 103 | 0,00 | **1 979 928,39** |
| C08 | PAP SLIMANE | 2019-08-29 → 2026-10-11 | 257 | 124 | 1 492 100,00 | **1 197 813,76** |
| C09 | TIRIKI FARID | 2019-08-22 → 2024-12-25 | 85 | 61 | 0,00 | **16 065,00** |
| C10 | YA PAP 31 | 2022-09-01 → 2026-09-01 | 43 | 41 | 0,00 | **84 981,30** |
| C11 | BOUHADJAM | 2022-02-27 → 2026-09-27 | 100 | 72 | -82 000,00 | **591 393,86** |
| C12 | DAR EL AMINE | 2021-05-24 → 2026-10-06 | 100 | 42 | 0,00 | **177 000,00** |
| C13 | AL SULTANE NASSIM | 2022-07-12 → 2026-09-23 | 79 | 67 | 0,00 | **261 837,00** |
| C14 | MAK INFO | 2023-11-29 → 2026-10-11 | 32 | 25 | 0,00 | **31 500,00** |
| C15 | DISPLAY | 2022-12-13 → 2026-10-05 | 222 | 118 | 0,00 | **2 248 021,59** |
| C16 | PAP EL REDA | 2020-09-01 → 2026-10-08 | 486 | 414 | 0,00 | **174 000,00** |
| C17 | TAZIRI | 2022-07-28 → 2025-07-28 | 47 | 25 | 0,00 | **0,00** |
| C18 | SARL SBM | 2023-03-07 → 2025-01-19 | 26 | 12 | 0,00 | **0,00** |
| C19 | Pap El Hana | 2021-11-17 → 2026-09-14 | 131 | 136 | 0,00 | **237 750,00** |
| C20 | MHAMMED | 2023-05-25 → 2025-10-30 | 100 | 78 | 211 426,00 | **235 638,00** |
| C21 | UNIVERSAL | 2023-07-10 → 2026-10-04 | 139 | 113 | 0,00 | **423 662,01** |
| C22 | PAGE | 2023-08-29 → 2026-09-17 | 35 | 16 | 0,00 | **475 240,00** |
| C23 | SARL TAZIRI ALGER | 2024-03-03 → 2024-11-24 | 11 | 10 | 0,00 | **0,00** |
| C24 | TECH ZONE | 2024-04-04 → 2026-10-05 | 88 | 17 | 0,00 | **805 237,80** |
| C25 | SARL EL BIBANE | 2024-10-30 → 2025-06-16 | 3 | 3 | 0,00 | **0,00** |
| C26 | ADEL MIMOUNE | 2024-10-30 → 2026-10-01 | 57 | 46 | 0,00 | **632 789,00** |
| C27 | PAPETRIE GHAREBI | 2024-10-01 → 2026-09-21 | 54 | 27 | 0,00 | **602 560,00** |
| C28 | PAPETRIE HAMEDI | 2024-10-29 → 2026-09-23 | 25 | 23 | 0,00 | **320 000,00** |
| C29 | TAZIRI SEDDIK | 2025-02-27 → 2026-09-21 | 21 | 10 | 0,00 | **915 635,00** |
| C30 | PAPETRIE MESBAH | 2025-09-03 → 2026-09-30 | 4 | 4 | 0,00 | **5 400,00** |
| C31 | TPV | 2026-08-12 → 2026-09-20 | 7 | 5 | 0,00 | **0,00** |
| C32 | BEN YAMINA | 2025-12-17 → 2026-08-06 | 14 | 12 | 0,00 | **-403 249,07** |
| C33 | WAHAB | 2025-12-15 → 2026-06-03 | 6 | 5 | 0,00 | **500 310,00** |
| C34 | ALICHE NOURELDINE | 2026-02-23 → 2026-09-02 | 21 | 7 | 0,00 | **130 000,00** |
| C35 | OUSSALMA | 2026-02-23 → 2026-09-28 | 16 | 17 | 0,00 | **26 085,00** |
| C36 | ABDSELAM | 2026-02-23 → 2026-10-01 | 2 | 1 | 0,00 | **0,00** |
| S06 | BRAHIMI ABDELKADER | 2019-11-11 → 2019-11-11 | 1 | 1 | 0,00 | **-257 120,00** |
| S09 | REDOUANE | 2019-01-01 → 2019-01-01 | 0 | 1 | 378 000,00 | **200 000,00** |
| S10 | PAP EL AMEL (MOUSSA) | 2019-02-18 → 2019-04-28 | 2 | 0 | 0,00 | **448 000,00** |
| S11 | EDN(MOUSSA) | 2018-10-10 → 2019-04-02 | 7 | 0 | 0,00 | **325 485,00** |
| S12 | KACIMI | 2019-01-01 → 2019-01-01 | 1 | 0 | 0,00 | **5 000,00** |
| S13 | IMP MARAM | 2019-02-25 → 2019-02-27 | 1 | 1 | 0,00 | **0,00** |
| S14 | BELLOUCHE | 2019-02-26 → 2019-03-04 | 1 | 1 | 0,00 | **156 000,00** |
| S16 | EURL MAMI | 2019-09-15 → 2019-09-15 | 1 | 0 | 0,00 | **36 000,00** |
| S18 | DIGITAL PLUS | 2019-03-17 → 2019-04-23 | 2 | 0 | 0,00 | **200 200,00** |
| S19 | BAKOUR | 2019-03-03 → 2019-07-25 | 1 | 1 | 0,00 | **40 000,00** |
| S20 | DJEMAI SLIMANE | 2019-01-17 → 2019-03-05 | 3 | 2 | -49 000,00 | **0,00** |
| S21 | PRIME DOC | 2019-05-05 → 2019-05-10 | 2 | 0 | 0,00 | **165 700,00** |
| S22 | BAGGOUR | 2019-09-15 → 2019-09-15 | 1 | 0 | 0,00 | **101 075,00** |
| S23 | SARL NOURYNE | 2019-06-01 → 2019-12-07 | 6 | 1 | -53 425,00 | **182 625,00** |
| S24 | IMP BOUJIOTE | 2019-06-19 → 2019-11-21 | 9 | 4 | 0,00 | **347 875,00** |
| S26 | OMAR BLIDA AL NIBRAS | 2019-08-31 → 2019-12-05 | 9 | 4 | 0,00 | **489 965,00** |

Solde négatif = le client a une avance (acompte) chez vous.

## Écarts du fichier Excel corrigés par un ajustement

À ces lignes, le « Reste à payer » écrit dans Excel ne correspond pas au calcul (formule cassée, total qui oublie une ligne, solde ressaisi à la main…). L'import garde le solde **écrit** dans Excel et trace la différence. Vérifiez-les si besoin dans le fichier.

| Client | Ligne Excel | Date | Solde calculé | Solde écrit | Ajustement |
|---|---:|---|---:|---:|---:|
| DAR EL KALEM | 181 | 2020-02-26 | 1 741 500,77 | 1 583 854,00 | -157 646,77 |
| DAR EL KALEM | 4607 | 2026-07-11 | 3 451 926,46 | 1 527 300,00 | -1 924 626,46 |
| PAP YAHIA (kayed) | 57 | 2019-11-25 | 527 950,00 | 408 450,00 | -119 500,00 |
| PAP YAHIA (kayed) | 82 | 2020-01-15 | 754 050,00 | 778 050,00 | 24 000,00 |
| PAP YAHIA (kayed) | 1350 | 2025-11-19 | 800,00 | 0,00 | -800,00 |
| PAP YAHIA (kayed) | 1376 | 2025-11-19 | -497 000,00 | 0,00 | 497 000,00 |
| PAP YAHIA (kayed) | 1482 | 2026-06-14 | -56 800,00 | 0,00 | 56 800,00 |
| IMDB (yazid) | 82 | 2019-12-01 | 218 741,79 | 268 741,78 | 49 999,99 |
| IMDB (yazid) | 121 | 2020-05-10 | 18 095,95 | 15 000,00 | -3 095,95 |
| IMDB (yazid) | 232 | 2021-12-12 | -182 277,40 | 182 277,40 | 364 554,80 |
| IMDB (yazid) | 254 | 2022-05-18 | 520 607,40 | -85 000,00 | -605 607,40 |
| IMDB (yazid) | 281 | 2022-05-30 | 72 565,00 | 11 648,00 | -60 917,00 |
| IMDB (yazid) | 296 | 2022-07-18 | 261 806,85 | 38 193,15 | -223 613,70 |
| NACER  BOUHADJAM | 78 | 2020-01-13 | 1 102 424,68 | 1 473 124,68 | 370 700,00 |
| PAP SLIMANE | 798 | 2022-11-15 | 23 240,68 | 0,00 | -23 240,68 |
| TIRIKI FARID | 82 | 2020-03-15 | 41 732,00 | 45 839,00 | 4 107,00 |
| BOUHADJAM | 23 | 2022-04-23 | 276 000,00 | 207 000,00 | -69 000,00 |
| BOUHADJAM | 129 | 2023-05-04 | -205 825,00 | 0,00 | 205 825,00 |
| BOUHADJAM | 587 | 2025-12-28 | -103,00 | 0,00 | 103,00 |
| DAR EL AMINE | 118 | 2021-10-06 | 660 015,00 | 659 935,00 | -80,00 |
| DISPLAY | 42 | 2023-01-15 | -730,00 | 0,00 | 730,00 |
| PAP EL REDA | 1478 | 2023-02-14 | -1 000,00 | 0,00 | 1 000,00 |
| PAP EL REDA | 2025 | 2023-12-05 | 228,06 | 0,00 | -228,06 |
| PAP EL REDA | 3803 | 2026-02-08 | 791 680,00 | 781 680,00 | -10 000,00 |
| TAZIRI | 376 | 2025-07-28 | 1 995 926,00 | 0,00 | -1 995 926,00 |
| Pap El Hana | 60 | 2022-03-09 | 449,21 | 0,00 | -449,21 |
| UNIVERSAL | 46 | 2023-08-23 | 49 125,30 | 49 356,00 | 230,70 |
| UNIVERSAL | 1052 | 2026-03-01 | 554 884,00 | 573 600,00 | 18 716,00 |
| PAGE | 82 | 2024-05-28 | -8,43 | 0,00 | 8,43 |
| TECH ZONE | 38 | 2024-06-11 | 91,87 | 0,00 | -91,87 |
| TECH ZONE | 169 | 2025-04-13 | -8,27 | 0,00 | 8,27 |
| PAPETRIE HAMEDI | 190 | 2025-11-19 | -200,00 | 0,00 | 200,00 |
| BEN YAMINA | 116 | 2026-07-01 | 1 380 000,00 | -1 020 000,00 | -2 400 000,00 |
| OUSSALMA | 33 | 2026-05-20 | 478 648,00 | 709 724,00 | 231 076,00 |

## Achats chez le client, retours, remises (en déduction du solde)

| Client | Ligne | Date | Montant | Désignation |
|---|---:|---|---:|---|
| PAP EL BASMALA | 58 | 2019-12-18 | 2 200,00 | achat stylo |
| PAP EL BASMALA | 1811 | 2024-09-30 | 13 642,65 | achat |
| PAP EL BASMALA | 2270 | 2026-02-05 | 20 000,00 | Article (désignation non saisie) |
| IMDB (yazid) | 17 | 2019-07-10 | 105 797,66 | page de garde |
| IMDB (yazid) | 27 | 2019-07-24 | 102 958,80 | page de garde |
| IMDB (yazid) | 32 | 2019-08-05 | 82 407,02 | page de garde |
| IMDB (yazid) | 39 | 2019-08-20 | 123 550,56 | page de garde |
| IMDB (yazid) | 50 | 2019-09-04 | 23 400,00 | page de garde rlx 150m |
| IMDB (yazid) | 56 | 2019-09-16 | 59 826,06 | page de garde pochette dessin |
| IMDB (yazid) | 61 | 2019-09-26 | 11 399,97 | rlx papier photo 180grs 30m |
| IMDB (yazid) | 66 | 2019-10-07 | 46 121,54 | page de garde chemise dossier |
| IMDB (yazid) | 83 | 2019-12-26 | 212 500,00 | listing 4ex 11X38 |
| IMDB (yazid) | 96 | 2020-01-09 | 90 000,00 | mondrin |
| IMDB (yazid) | 111 | 2020-03-02 | 60 395,83 | page de garde pochette dessin |
| IMDB (yazid) | 116 | 2020-05-10 | 271 560,00 | page de garde pochette dessin |
| IMDB (yazid) | 129 | 2020-07-08 | 11 250,00 | mondrin |
| IMDB (yazid) | 141 | 2020-08-17 | 25 500,00 | mondrin |
| IMDB (yazid) | 155 | 2020-10-18 | 45 000,00 | page de garde rlx 150m et 50m |
| IMDB (yazid) | 162 | 2020-10-28 | 22 500,00 | tube 80cm |
| IMDB (yazid) | 167 | 2020-12-26 | 34 230,00 | mondrin fax 210mm |
| IMDB (yazid) | 172 | 2021-01-03 | 22 500,00 | tube 80cm |
| IMDB (yazid) | 184 | 2021-02-24 | 17 400,00 | tube 80cm |
| IMDB (yazid) | 196 | 2021-05-26 | 84 400,00 | page de garde rlx 150m et 50m |
| IMDB (yazid) | 201 | 2021-05-26 | 68 972,40 | page de garde |
| IMDB (yazid) | 206 | 2021-08-30 | 42 000,00 | tube 80cm |
| IMDB (yazid) | 211 | 2021-09-19 | 52 500,00 | tube 80cm |
| IMDB (yazid) | 216 | 2021-11-04 | 673 860,00 | 08 bobines thermique |
| IMDB (yazid) | 223 | 2021-12-12 | 145 000,00 | Rouleau termique 80x70 |
| IMDB (yazid) | 297 | 2022-08-02 | 32 400,00 | Tube 80 cm |
| IMDB (yazid) | 302 | 2022-08-03 | 24 300,00 | Tube 80 cm |
| IMDB (yazid) | 321 | 2022-08-14 | 16 200,00 | Tube 80 cm |
| PAP SLIMANE | 1798 | 2026-02-18 | 11 813,76 | achat |
| PAP SLIMANE | 1821 | 2026-04-11 | 11 813,76 | ACHAT DE SCOTCH |
| PAP SLIMANE | 1837 | 2026-05-03 | 15 848,16 | achat double face+sckotch |
| PAP SLIMANE | 1856 | 2026-06-09 | 13 687,68 | achat double face+sckotch |
| PAP SLIMANE | 1895 | 2026-07-19 | 300 000,00 | Article (désignation non saisie) |
| PAP SLIMANE | 1918 | 2026-08-03 | 17 634,72 | achat sckotch double face |
| YA PAP 31 | 335 | 2025-06-04 | 1 200 000,00 | Article (désignation non saisie) |

## Débits divers (ajoutés au solde)

| Client | Ligne | Date | Montant | Libellé Excel |
|---|---:|---|---:|---|
| IMDB (yazid) | 221 | 2021-11-04 | 500 000,00 | v e r s s e m e n t Verssement |
| IMDB (yazid) | 381 | 2023-04-18 | 102 000,00 | versement |
| YA PAP 31 | 25 | 2022-09-20 | 20 000,00 | Yapap Oran +20000,00 Verssement |
| YA PAP 31 | 265 | 2024-08-24 | 5 000,00 | chauffeur chauffeur |
| YA PAP 31 | 326 | 2025-02-26 | 18 000,00 | TRANSPORT TRANSPORT |
| DAR EL AMINE | 617 | 2025-05-18 | 110 000,00 | 2,20X50000 |
| DAR EL AMINE | 705 | 2026-04-09 | 650 000,00 | ACHAT MACHINE MACHINE |
| BEN YAMINA | 110 | 2026-07-13 | 1 200 000,00 | v e r s e m e n t espece |

## Dates corrigées

Dates impossibles (dans le futur) ou année manifestement mal tapée par rapport aux lignes voisines. La date d'origine est conservée dans la note du document.

| Client | Ligne | Date Excel | Date importée |
|---|---:|---|---|
| PAP EL BASMALA | 1225 | 2022-10-15 | 2023-02-14 |
| PAP EL BASMALA | 2272 | 2025-09-30 | 2026-02-05 |
| PAP EL AMEL (AEK) | 78 | 2023-08-02 | 2020-08-02 |
| PAP EL AMEL (AEK) | 87 | 2023-08-06 | 2020-08-06 |
| PAP EL AMEL (AEK) | 404 | 2023-01-05 | 2025-01-05 |
| PAP EL AMEL (AEK) | 413 | 2024-01-27 | 2025-01-27 |
| PAP EL AMEL (AEK) | 422 | 2028-02-09 | 2025-02-09 |
| PAP EL AMEL (AEK) | 431 | 2028-02-10 | 2025-02-10 |
| PAP EL AMEL (AEK) | 438 | 2028-03-09 | 2025-03-09 |
| PAP EL AMEL (AEK) | 447 | 2028-04-09 | 2025-04-09 |
| PAP EL AMEL (AEK) | 454 | 2028-04-29 | 2025-04-29 |
| PAP YAHIA (kayed) | 1385 | 2025-01-04 | 2026-01-04 |
| PAP YAHIA (kayed) | 1407 | 2028-02-10 | 2025-02-10 |
| PAP YAHIA (kayed) | 1415 | 2028-02-10 | 2025-02-10 |
| PAP YAHIA (kayed) | 1425 | 2028-02-10 | 2025-02-10 |
| PAP YAHIA (kayed) | 1433 | 2028-03-08 | 2025-02-10 |
| PAP YAHIA (kayed) | 1443 | 2026-04-06 | 2025-04-06 |
| PAP YAHIA (kayed) | 1453 | 2026-04-30 | 2025-04-13 |
| IMDB (yazid) | 129 | 2020-01-09 | 2020-07-08 |
| IMDB (yazid) | 172 | 2020-01-03 | 2021-01-03 |
| IMDB (yazid) | 328 | 2020-08-15 | 2022-08-15 |
| IMDB (yazid) | 432 | 2021-01-18 | 2024-01-18 |
| PAP SLIMANE | 149 | 2019-01-06 | 2020-01-06 |
| PAP SLIMANE | 909 | 2022-02-26 | 2023-02-26 |
| PAP SLIMANE | 968 | 2022-12-07 | 2023-05-28 |
| TIRIKI FARID | 268 | 2021-01-27 | 2022-01-27 |
| TIRIKI FARID | 398 | 2022-01-11 | 2023-01-11 |
| BOUHADJAM | 14 | 2023-08-28 | 2022-04-23 |
| DAR EL AMINE | 217 | 2022-03-31 | 2021-03-31 |
| AL SULTANE NASSIM | 27 | 2020-01-23 | 2022-08-10 |
| MAK INFO | 107 | 2024-03-11 | 2025-03-11 |
| MAK INFO | 195 | 2025-01-05 | 2026-01-05 |
| DISPLAY | 494 | 2023-01-16 | 2024-01-16 |
| DISPLAY | 1180 | 2022-04-30 | 2025-04-30 |
| PAP EL REDA | 1311 | 2022-04-15 | 2022-08-10 |
| PAP EL REDA | 2929 | 2024-05-28 | 2024-11-06 |
| PAP EL REDA | 3396 | 2024-06-17 | 2025-06-17 |
| PAP EL REDA | 3710 | 2025-01-08 | 2026-01-08 |
| TAZIRI | 323 | 2024-02-06 | 2025-02-06 |
| TAZIRI | 333 | 2024-02-27 | 2025-02-27 |
| TAZIRI | 359 | 2024-05-28 | 2025-05-28 |
| SARL SBM | 107 | 2023-04-09 | 2023-08-08 |
| Pap El Hana | 45 | 2021-01-25 | 2022-01-25 |
| MHAMMED | 93 | 2021-07-23 | 2023-07-23 |
| MHAMMED | 101 | 2021-07-31 | 2023-07-31 |
| MHAMMED | 121 | 2021-08-14 | 2023-08-14 |
| MHAMMED | 671 | 2024-01-13 | 2025-01-13 |
| MHAMMED | 745 | 2024-03-11 | 2025-03-11 |
| UNIVERSAL | 965 | 2025-01-15 | 2026-01-15 |
| UNIVERSAL | 974 | 2025-02-02 | 2026-02-02 |
| UNIVERSAL | 1053 | 2025-04-12 | 2026-04-12 |
| UNIVERSAL | 1064 | 2025-04-22 | 2026-04-22 |
| UNIVERSAL | 1073 | 2025-05-05 | 2026-05-05 |
| PAGE | 47 | 2023-01-14 | 2024-01-14 |
| PAGE | 242 | 2025-09-03 | 2026-09-03 |
| TECH ZONE | 115 | 2024-01-14 | 2025-01-14 |
| TECH ZONE | 128 | 2024-01-26 | 2025-01-26 |
| ADEL MIMOUNE | 528 | 2026-01-01 | 2026-10-01 |
| BEN YAMINA | 33 | 2025-01-19 | 2026-01-19 |
| BEN YAMINA | 43 | 2025-02-03 | 2026-02-03 |
| BEN YAMINA | 70 | 2026-02-26 | 2025-03-26 |
| BEN YAMINA | 79 | 2026-04-28 | 2025-04-28 |
| WAHAB | 54 | 2025-04-19 | 2026-04-19 |

## Feuille « Situation client » (2019)

Cette feuille est une ancienne version (2019) avec de nombreuses cellules `#REF!`. Pour les clients qui existent aussi dans **Feuil1**, Feuil1 reprend déjà leur solde de 2019 (« solde de départ ») : leurs lignes 2019 ne sont **pas** réimportées, sinon elles seraient comptées deux fois :

- PAP EL BASMALA
- PAP EL AMEL (AEK)
- DAR EL KALEM
- PAP YAHIA (kayed)
- IMDB
- NACER  BOUHADJAM
- PAP SLIMANE
- TIRIKI FARID

Les autres clients de cette feuille sont importés (fichier 03). Leur solde n'a pas pu être contrôlé ligne par ligne (formules `#REF!`), il est recalculé à partir des bons et versements.

**Fichier facultatif `05_optionnel_2019_TAZIRI_AL_SULTANE.sql`** : TAZIRI PAP et AL SULTANE ont un solde en 2019 dans cette feuille mais leur compte repart de 0 dans Feuil1. Exécutez ce fichier seulement si ces montants n'ont jamais été réglés (il ajoute leur historique 2019 à leur fiche) :

- TAZIRI PAP : 2 BL, solde 2019 496 100,00
- AL SULTANE : 2 BL, solde 2019 153 721,25

## Fournisseurs (feuille ACHAT)

| Clé | Fournisseur | Solde initial | Solde importé | Dernier « Reste » écrit dans Excel |
|---|---|---:|---:|---:|
| F01 | P&C MAN | 134 586,00 | **666 712,65** | 575 868,20 |
| F02 | GHOBRINI | 0,00 | **0,00** | 1 200 000,00 |
| F03 | SOFIANE | 0,00 | **718 975,00** | 403 305,00 |
| F04 | EURL MAMI | 0,00 | **348 600,00** | — |
| F05 | SOCIETE DES ARTES GRAPHIQUE | 0,00 | **457 920,00** | 457 920,00 |
| F06 | ENVELOPPE DU NORD | 0,00 | **57 500,00** | 37 200,00 |
| F07 | imdb | 0,00 | **300 820,00** | 300 820,00 |

La feuille ACHAT est moins fiable que Feuil1 : l'import reprend les **factures et règlements réels**. Différences avec la feuille : P&C MAN (une ligne « solde initial » remise à 0 dans Excel au 17/09/2019 fait disparaître 90 844,44 DA), GHOBRINI (le dernier « Reste » 1 200 000 est avant le dernier versement de 1 200 000 → 0), SOFIANE (le « Reste » écrit ne compte que le dernier bon), ENVELOPPE DU NORD (37 200 écrit pour un bon de 40 500 sans versement noté + un bon de 17 000 non reporté). Corrigez dans l'application si nécessaire.

## Caisse

Les versements et règlements importés sont des encaissements des années passées : `99_finalisation.sql` les retire de la caisse pour que le solde de caisse actuel ne soit pas faussé. Pour les y laisser, mettez `v_keep_caisse := true` dans ce fichier avant de l'exécuter.

## Produits / fiches techniques

Les lignes de BL gardent la désignation écrite dans Excel. Quand une fiche technique de l'application porte exactement le même nom, la ligne y est rattachée automatiquement. Les documents étant historiques, le stock et le stock prêt ne bougent pas.

