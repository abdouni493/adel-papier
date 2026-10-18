import json, os, sys
S = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1]
r = json.load(open(os.path.join(S, 'report.json'), encoding='utf-8'))

def m(x):
    if x is None: return '—'
    return f"{x:,.2f}".replace(',', ' ').replace('.', ',')

cl = r['clients']; so = r['si_only']
allc = cl + so
L = []
w = L.append
w('# Import de SITUATION.xlsx — rapport\n')
w("Généré à partir de `SITUATION.xlsx` (feuilles **Feuil1**, **Situation client**, **ACHAT**). "
  "Les scripts SQL de ce dossier créent toutes ces données dans l'application. "
  "Le script a été exécuté de bout en bout sur une copie vide du schéma de l'application "
  "(`supabase/papeterie_supabase_full.sql`) : **aucune erreur, et le solde net de chacun des "
  f"{len(allc)} clients dans l'application est identique au dernier « Reste à payer » d'Excel**.\n")

w('## Ordre d\'exécution (éditeur SQL Supabase)\n')
w('| # | Fichier | Contenu |')
w('|---|---|---|')
rows = [
 ('1', '00_preparation.sql', "schéma temporaire `import_excel` + fonctions d'import (appellent les fonctions internes de l'application)"),
 ('2', '01_clients.sql', f"création des {len(allc)} clients (un client existant portant le même nom est réutilisé)"),
 ('3', '02_clients_mouvements_partie1..5.sql', 'bons de livraison, versements, soldes de départ — feuille Feuil1'),
 ('4', '03_clients_2019_feuille_situation.sql', f"{len(so)} clients présents seulement dans la feuille « Situation client » (2019)"),
 ('5', '04_fournisseurs.sql', 'fournisseurs, factures d\'achat et règlements — feuille ACHAT'),
 ('6', '99_finalisation.sql', 'retire de la caisse les versements importés, renumérote les BL / factures importés par date, affiche le contrôle des soldes'),
 ('—', '05_optionnel_2019_TAZIRI_AL_SULTANE.sql', 'facultatif, voir plus bas'),
 ('—', 'annulation/ANNULER_TOUT_L_IMPORT.sql', "**à ne PAS exécuter pendant l'import** : supprime TOUT l'import (protégé, demande une confirmation dans le fichier)"),
]
for a, b, c in rows: w(f'| {a} | `{b}` | {c} |')
w('\n`IMPORT_COMPLET.sql` contient les fichiers 1 → 6 à la suite (1 Mo) si vous préférez un seul fichier '
  '(≈ 1 min 30 sur un PC ; si l\'éditeur Supabase coupe, utilisez les fichiers séparés, chacun < 40 s). '
  'Chaque fichier est une transaction : en cas d\'erreur rien n\'est enregistré. Un fichier déjà exécuté est refusé '
  's\'il est relancé (pas de doublons).\n')

w('## Correspondance Excel → application\n')
w('| Dans Excel | Dans l\'application |')
w('|---|---|')
for a, b in [
 ('Colonne client (Nom, Adresse)', '`clients` (note = feuille et colonnes d\'origine)'),
 ('Bloc « BLN° / DATE / Désignation / Quant. / P.U / Mont »', 'commande **historique** finalisée (`commands` + `command_items`) → bon de livraison historique (`command_deliveries`, badge « Ancienne ») → sa facture (`sales` + `sale_lines`). N° de BL Excel = `bon_number`. Aucun mouvement de stock, aucune production automatique, aucune caisse.'),
 ('Ligne « v … Verssement / cheque / virement / espèce »', '`client_payments` (mode espèces / chèque / virement, banque et n° de chèque quand Excel les donne) imputé comme dans l\'application : anciennes dettes → factures les plus anciennes → acompte.'),
 ('Premier « Reste à payer » (solde reporté d\'avant)', '`party_old_debts` « Solde antérieur reporté » (ou acompte si négatif)'),
 ('Bloc « achat » chez le client, REMISE, RETOUR', 'versement non encaissé noté `[COMPENSATION ACHAT]`, `[REMISE]`, `[RETOUR MARCHANDISE]`'),
 ('Frais refacturés (transport, chauffeur, machine…), versement négatif', 'vente historique d\'une ligne'),
 ('Erreur de formule du fichier (solde écrit ≠ calcul)', '`[AJUSTEMENT EXCEL]` (versement) ou « Ajustement de solde (écart Excel) » (vente) pour retomber exactement sur le solde écrit — liste complète ci-dessous'),
 ('Feuille ACHAT', '`suppliers`, `purchases` historiques (TVA 19 % quand le total Excel est T.T.C.), `supplier_payments`'),
]: w(f'| {a} | {b} |')

tot_bl = sum(x['bl'] for x in allc); tot_lines = sum(x['bl_lines'] for x in allc)
tot_pay = sum(x['pay'] for x in allc)
w('\n## Volumes importés\n')
w(f'- **{len(allc)} clients** ({len(cl)} de Feuil1, {len(so)} de « Situation client »)')
w(f'- **{tot_bl} bons de livraison** ({tot_lines} lignes produits) = {tot_bl} commandes + {tot_bl} factures')
w(f'- **{tot_pay} versements clients** (+ {sum(len(x["credits"]) for x in allc)} compensations / retours / remises)')
w(f'- {sum(1 for x in allc if abs(x["opening"]) > 0.004)} soldes de départ, {sum(len(x["debits"]) for x in allc)} débits divers, {sum(len(x["adjust"]) for x in allc)} ajustements d\'écart Excel')
w(f'- **{len(r["suppliers"])} fournisseurs**, 34 factures d\'achat, 15 règlements')
w(f'- Contrôle : {sum(x["checks"] for x in allc)} « Reste à payer » d\'Excel vérifiés un par un pendant la lecture.\n')

w('## Clients — solde final (= dernier « Reste à payer » Excel)\n')
w('| Clé | Client | Période | BL | Versements | Solde de départ | Solde final |')
w('|---|---|---|---:|---:|---:|---:|')
for x in allc:
    w(f"| {x['key']} | {x['name']} | {x['first']} → {x['last']} | {x['bl']} | {x['pay']} | {m(x['opening'])} | **{m(x['final'])}** |")
w('\nSolde négatif = le client a une avance (acompte) chez vous.\n')

w('## Écarts du fichier Excel corrigés par un ajustement\n')
w('À ces lignes, le « Reste à payer » écrit dans Excel ne correspond pas au calcul '
  '(formule cassée, total qui oublie une ligne, solde ressaisi à la main…). '
  'L\'import garde le solde **écrit** dans Excel et trace la différence. Vérifiez-les si besoin dans le fichier.\n')
w('| Client | Ligne Excel | Date | Solde calculé | Solde écrit | Ajustement |')
w('|---|---:|---|---:|---:|---:|')
for x in allc:
    for row, amt, exp, sheet, d in x['adjust']:
        w(f"| {x['name']} | {row} | {d} | {m(exp)} | {m(sheet)} | {m(amt)} |")

w('\n## Achats chez le client, retours, remises (en déduction du solde)\n')
w('| Client | Ligne | Date | Montant | Désignation |')
w('|---|---:|---|---:|---|')
for x in allc:
    for row, amt, d, desc in x['credits']:
        w(f"| {x['name']} | {row} | {d} | {m(amt)} | {desc} |")
w('\n## Débits divers (ajoutés au solde)\n')
w('| Client | Ligne | Date | Montant | Libellé Excel |')
w('|---|---:|---|---:|---|')
for x in allc:
    for row, amt, d, desc in x['debits']:
        w(f"| {x['name']} | {row} | {d} | {m(amt)} | {desc} |")

w('\n## Dates corrigées\n')
w('Dates impossibles (dans le futur) ou année manifestement mal tapée par rapport aux lignes voisines. '
  'La date d\'origine est conservée dans la note du document.\n')
w('| Client | Ligne | Date Excel | Date importée |')
w('|---|---:|---|---|')
for x in allc:
    for bad, good, row in x['bad_dates']:
        w(f"| {x['name']} | {row} | {bad} | {good} |")

w('\n## Feuille « Situation client » (2019)\n')
w('Cette feuille est une ancienne version (2019) avec de nombreuses cellules `#REF!`. '
  'Pour les clients qui existent aussi dans **Feuil1**, Feuil1 reprend déjà leur solde de 2019 '
  '(« solde de départ ») : leurs lignes 2019 ne sont **pas** réimportées, sinon elles seraient comptées deux fois :\n')
for x in r['si_overlap']: w(f"- {x['name']}")
w('\nLes autres clients de cette feuille sont importés (fichier 03). Leur solde n\'a pas pu être contrôlé '
  'ligne par ligne (formules `#REF!`), il est recalculé à partir des bons et versements.\n')
w('**Fichier facultatif `05_optionnel_2019_TAZIRI_AL_SULTANE.sql`** : TAZIRI PAP et AL SULTANE ont un solde '
  'en 2019 dans cette feuille mais leur compte repart de 0 dans Feuil1. Exécutez ce fichier seulement si ces montants '
  'n\'ont jamais été réglés (il ajoute leur historique 2019 à leur fiche) :\n')
for x in r['si_optional']: w(f"- {x['name']} : {x['bl']} BL, solde 2019 {m(x['final'])}")

w('\n## Fournisseurs (feuille ACHAT)\n')
w('| Clé | Fournisseur | Solde initial | Solde importé | Dernier « Reste » écrit dans Excel |')
w('|---|---|---:|---:|---:|')
for key, name, op, tot, sheet in r['suppliers']:
    w(f'| {key} | {name} | {m(op)} | **{m(tot)}** | {m(sheet)} |')
w('\nLa feuille ACHAT est moins fiable que Feuil1 : l\'import reprend les **factures et règlements réels**. '
  'Différences avec la feuille : P&C MAN (une ligne « solde initial » remise à 0 dans Excel au 17/09/2019 fait '
  'disparaître 90 844,44 DA), GHOBRINI (le dernier « Reste » 1 200 000 est avant le dernier versement de 1 200 000 → 0), '
  'SOFIANE (le « Reste » écrit ne compte que le dernier bon), ENVELOPPE DU NORD (37 200 écrit pour un bon de 40 500 '
  'sans versement noté + un bon de 17 000 non reporté). Corrigez dans l\'application si nécessaire.\n')

w('## Caisse\n')
w('Les versements et règlements importés sont des encaissements des années passées : `99_finalisation.sql` les retire '
  'de la caisse pour que le solde de caisse actuel ne soit pas faussé. Pour les y laisser, mettez '
  '`v_keep_caisse := true` dans ce fichier avant de l\'exécuter.\n')

w('## Produits / fiches techniques\n')
w('Les lignes de BL gardent la désignation écrite dans Excel. Quand une fiche technique de l\'application porte '
  'exactement le même nom, la ligne y est rattachée automatiquement. Les documents étant historiques, '
  'le stock et le stock prêt ne bougent pas.\n')

open(os.path.join(OUT, 'RAPPORT_IMPORT.md'), 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')
print('report lines', len(L))
