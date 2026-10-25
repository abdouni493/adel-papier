# Mise à jour du 25/10/2026 — « Copie de SITUATION.xlsx »

Comparaison du nouveau fichier avec `SITUATION.xlsx` (celui du premier import) et avec les scripts SQL déjà fournis.

## Ce qui a changé dans le fichier

- Feuilles **Situation client**, **ACHAT** et **Feuil3** : **identiques** (aucune cellule modifiée).
- Feuille **Feuil1** : 19 clients ont de nouvelles lignes à la suite de leur compte, soit **27 nouveaux bons de livraison** (6 467 080,00 DA) et **24 nouveaux versements** (10 433 468,24 DA).
- Feuil1 : **4 lignes déjà importées ont été modifiées** dans Excel (voir « Corrections »).
- Aucun nouveau client, aucun client supprimé.

## Fichiers à exécuter (éditeur SQL Supabase), dans l'ordre

**Seulement si le premier import (dossier `import_excel`, fichiers 00 → 04 puis 99_finalisation) est déjà fait dans la base.** Le fichier 10 le vérifie et s'arrête sinon. Si vous n'avez pas encore fait le premier import : faites-le d'abord, puis ces fichiers.

| # | Fichier | Contenu |
|---|---|---|
| 1 | `10_preparation_maj.sql` | vérifie que le premier import est là, ajoute les fonctions de correction |
| 2 | `11_corrections.sql` | 14 corrections de documents déjà importés |
| 3 | `12_nouveaux_mouvements.sql` | les 27 BL et 24 versements nouveaux |
| 4 | `19_finalisation_maj.sql` | retire les nouveaux versements de la caisse, renumérote les BL / factures par date, et affiche le **contrôle** : la colonne `ok` doit être `true` pour les 36 clients |

Chaque fichier est une transaction (une erreur = rien n'est enregistré) et ne peut pas être exécuté deux fois. Ne relancez PAS les anciens fichiers 00 → 04 : ils sont refusés de toute façon.

## Corrections de lignes déjà importées

| Client | Ligne Excel | Correction | Détail |
|---|---:|---|---|
| C01 · PAP EL BASMALA | 1982 | Bon vide supprimé | « 2025 » — 0 DA |
| C02 · PAP EL AMEL (AEK) | 1056 | Bon vide supprimé | « 0 µ » — 0 DA |
| C04 · PAP YAHIA (kayed) | 1559 | Bon corrigé | 2026-10-11 86,000.00 → 2026-10-11 86,000.00 · lignes modifiées |
| C04 · PAP YAHIA (kayed) | 3428 | Bon vide supprimé | « µ µ » — 0 DA |
| C06 · NACER  BOUHADJAM | 1818 | Bon vide supprimé | « aucune ligne » — 0 DA |
| C07 · YA PAP | 2197 | Bon vide supprimé | « * » — 0 DA |
| C11 · BOUHADJAM | 839 | Bon corrigé | 2026-09-27 65,500.00 → 2026-10-11 65,500.00 |
| C12 · DAR EL AMINE | 778 | Bon corrigé | 2026-10-06 177,000.00 → 2026-10-06 174,000.00 · lignes modifiées |
| C14 · MAK INFO | 1264 | Bon vide supprimé | « * < » — 0 DA |
| C15 · DISPLAY | 1731 | Note de versement corrigée | CPA 9448151 — Facture N° 96 (Excel Feuil1 L1731) |
| C18 · SARL SBM | 218 | Bon vide supprimé | « , , » — 0 DA |
| C19 · Pap El Hana | 735 | Bon vide supprimé | « 2025 » — 0 DA |
| C23 · SARL TAZIRI ALGER | 188 | Bon vide supprimé | « µ » — 0 DA |
| S23 · SARL NOURYNE | 39 | Bon vide supprimé | « , » — 0 DA |

Les « bons vides » sont 10 bons à 0 DA que le premier import avait créés à partir de signes parasites du fichier (« * », « 0 µ », « 2025 », « , , »…). Ils ne changeaient aucun solde ; ils sont supprimés. Trois bons à 0 DA qui portent une vraie note (« SOUS CHEMISE 5000F UNIS », « … RETOUR 40 CARTONS », « PRESTATION DE SERVICE BOBINES ») sont conservés.

Pour un bon corrigé, l'ancien bon est supprimé et refait avec les nouvelles valeurs ; les versements qui le payaient redeviennent l'acompte du client puis paient le nouveau bon, exactement comme une modification dans l'application.

## Soldes après la mise à jour

| Client | Nouveaux BL | Nouveaux versements | Solde avant | **Solde après** (= Excel) |
|---|---:|---:|---:|---:|
| C01 · PAP EL BASMALA | 1 | 1 | 994 776,50 | **727 276,50** |
| C02 · PAP EL AMEL (AEK) | 1 | 0 | 74 517,00 | **111 217,00** |
| C03 · DAR EL KALEM | 0 | 3 | 1 347 991,20 | **-1 599 186,12** |
| C04 · PAP YAHIA (kayed) | 2 | 1 | 151 320,00 | **552 000,00** |
| C06 · NACER  BOUHADJAM | 1 | 2 | 1 671 917,01 | **1 593 917,01** |
| C07 · YA PAP | 2 | 1 | 1 979 928,39 | **1 435 928,39** |
| C08 · PAP SLIMANE | 2 | 0 | 1 197 813,76 | **1 366 313,76** |
| C11 · BOUHADJAM | 1 | 2 | 591 393,86 | **268 893,86** |
| C12 · DAR EL AMINE | 0 | 0 | 177 000,00 | **174 000,00** |
| C13 · AL SULTANE NASSIM | 0 | 1 | 261 837,00 | **61 837,00** |
| C14 · MAK INFO | 2 | 0 | 31 500,00 | **257 600,00** |
| C15 · DISPLAY | 3 | 3 | 2 248 021,59 | **2 089 521,59** |
| C16 · PAP EL REDA | 4 | 3 | 174 000,00 | **-0,00** |
| C18 · SARL SBM | 0 | 0 | 0,00 | **0,00** |
| C19 · Pap El Hana | 1 | 1 | 237 750,00 | **251 750,00** |
| C21 · UNIVERSAL | 1 | 2 | 423 662,01 | **223 161,09** |
| C23 · SARL TAZIRI ALGER | 0 | 0 | 0,00 | **0,00** |
| C24 · TECH ZONE | 1 | 0 | 805 237,80 | **813 637,80** |
| C31 · TPV | 2 | 1 | 0,00 | **288 100,00** |
| C33 · WAHAB | 0 | 1 | 500 310,00 | **232 640,00** |
| C35 · OUSSALMA | 2 | 1 | 26 085,00 | **77 065,00** |
| C36 · ABDSELAM | 1 | 1 | 0,00 | **0,00** |

Les autres clients ne changent pas. Solde négatif = le client a une avance chez vous (DAR EL KALEM : −1 599 186,12 DA, d'après les trois derniers versements d'octobre écrits dans Excel).

## Points à vérifier dans Excel

- **PAP YAHIA (kayed)**, ligne 1575 : versement de 281 320 DA daté **19/01/2022** au milieu des lignes d'octobre 2026 → importé au 13/10/2026 (date d'origine gardée dans la note).
- **AL SULTANE NASSIM**, ligne 658 : versement de 200 000 DA daté **13/05/2026** après des lignes de septembre → importé au 23/09/2026.
- **PAP EL BASMALA**, ligne 2439 : versement de 300 000 DA daté **20/08/2026** juste après un BL du 19/10/2026 — gardé tel quel (peut-être 20/10/2026).
- **WAHAB** (ligne 63) et **OUSSALMA** (ligne 175) : versements sans date dans Excel → datés comme la ligne précédente.
- **BOUHADJAM**, ligne 839 : la date du BL de 65 500 DA est passée du 27/09/2026 au 11/10/2026 dans le nouveau fichier ; le BL est déplacé en octobre.

## Test

Testé sur une copie vide du schéma de l'application : premier import complet (tel que livré), puis cette mise à jour → aucune erreur ; les 36 clients de Feuil1 ont exactement le solde du nouveau fichier ; les 16 clients de 2019 et les 7 fournisseurs n'ont pas bougé ; aucun numéro de BL / facture en double ou manquant ; caisse sans mouvement importé ; relancer un fichier est refusé ; lancer la mise à jour sans le premier import est refusé.

