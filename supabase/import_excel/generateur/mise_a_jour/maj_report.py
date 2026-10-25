import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); OUT = sys.argv[1]
delta = json.load(open(os.path.join(HERE, 'delta.json'), encoding='utf-8'))
corr = json.load(open(os.path.join(HERE, 'maj_report.json'), encoding='utf-8'))
def m(x): return f"{x:,.2f}".replace(',', ' ').replace('.', ',')
L = []; w = L.append
nb_bl = sum(1 for d in delta.values() for e in d['added'] if e['type'] == 'bl' and e['sign'] > 0)
nb_pay = sum(1 for d in delta.values() for e in d['added'] if e['type'] == 'pay' and e['sign'] < 0)
tot_bl = sum(e['amount'] for d in delta.values() for e in d['added'] if e['type'] == 'bl' and e['sign'] > 0)
tot_pay = sum(e['amount'] for d in delta.values() for e in d['added'] if e['type'] == 'pay' and e['sign'] < 0)
other = sum(1 for d in delta.values() for e in d['added']) - nb_bl - nb_pay
w('# Mise à jour du 25/10/2026 — « Copie de SITUATION.xlsx »\n')
w('Comparaison du nouveau fichier avec `SITUATION.xlsx` (celui du premier import) et avec les scripts SQL déjà fournis.\n')
w('## Ce qui a changé dans le fichier\n')
w('- Feuilles **Situation client**, **ACHAT** et **Feuil3** : **identiques** (aucune cellule modifiée).')
w(f'- Feuille **Feuil1** : {len([d for d in delta.values() if d["added"]])} clients ont de nouvelles lignes à la suite de leur compte, '
  f'soit **{nb_bl} nouveaux bons de livraison** ({m(tot_bl)} DA) et **{nb_pay} nouveaux versements** ({m(tot_pay)} DA)'
  + (f', plus {other} autre(s) mouvement(s)' if other else '') + '.')
w('- Feuil1 : **4 lignes déjà importées ont été modifiées** dans Excel (voir « Corrections »).')
w('- Aucun nouveau client, aucun client supprimé.\n')
w('## Fichiers à exécuter (éditeur SQL Supabase), dans l\'ordre\n')
w('**Seulement si le premier import (dossier `import_excel`, fichiers 00 → 04 puis 99_finalisation) est déjà fait dans la base.** '
  'Le fichier 10 le vérifie et s\'arrête sinon. Si vous n\'avez pas encore fait le premier import : faites-le d\'abord, puis ces fichiers.\n')
w('| # | Fichier | Contenu |\n|---|---|---|')
w('| 1 | `10_preparation_maj.sql` | vérifie que le premier import est là, ajoute les fonctions de correction |')
w(f'| 2 | `11_corrections.sql` | {len(corr)} corrections de documents déjà importés |')
w(f'| 3 | `12_nouveaux_mouvements.sql` | les {nb_bl} BL et {nb_pay} versements nouveaux |')
w('| 4 | `19_finalisation_maj.sql` | retire les nouveaux versements de la caisse, renumérote les BL / factures par date, et affiche le **contrôle** : la colonne `ok` doit être `true` pour les 36 clients |')
w('\nChaque fichier est une transaction (une erreur = rien n\'est enregistré) et ne peut pas être exécuté deux fois. '
  'Ne relancez PAS les anciens fichiers 00 → 04 : ils sont refusés de toute façon.\n')
w('## Corrections de lignes déjà importées\n')
w('| Client | Ligne Excel | Correction | Détail |\n|---|---:|---|---|')
for key, name, row, kind, det in corr:
    w(f'| {key} · {name} | {row} | {kind} | {det} |')
w('\nLes « bons vides » sont 10 bons à 0 DA que le premier import avait créés à partir de signes parasites du fichier '
  '(« * », « 0 µ », « 2025 », « , , »…). Ils ne changeaient aucun solde ; ils sont supprimés. '
  'Trois bons à 0 DA qui portent une vraie note (« SOUS CHEMISE 5000F UNIS », « … RETOUR 40 CARTONS », « PRESTATION DE SERVICE BOBINES ») sont conservés.\n')
w('Pour un bon corrigé, l\'ancien bon est supprimé et refait avec les nouvelles valeurs ; les versements qui le payaient '
  'redeviennent l\'acompte du client puis paient le nouveau bon, exactement comme une modification dans l\'application.\n')
w('## Soldes après la mise à jour\n')
w('| Client | Nouveaux BL | Nouveaux versements | Solde avant | **Solde après** (= Excel) |\n|---|---:|---:|---:|---:|')
for key, d in sorted(delta.items()):
    b = sum(1 for e in d['added'] if e['type'] == 'bl' and e['sign'] > 0)
    p = sum(1 for e in d['added'] if e['type'] == 'pay' and e['sign'] < 0)
    w(f"| {key} · {d['name']} | {b} | {p} | {m(d['old_final'])} | **{m(d['new_final'])}** |")
w('\nLes autres clients ne changent pas. Solde négatif = le client a une avance chez vous '
  '(DAR EL KALEM : −1 599 186,12 DA, d\'après les trois derniers versements d\'octobre écrits dans Excel).\n')
w('## Points à vérifier dans Excel\n')
w('- **PAP YAHIA (kayed)**, ligne 1575 : versement de 281 320 DA daté **19/01/2022** au milieu des lignes d\'octobre 2026 → importé au 13/10/2026 (date d\'origine gardée dans la note).')
w('- **AL SULTANE NASSIM**, ligne 658 : versement de 200 000 DA daté **13/05/2026** après des lignes de septembre → importé au 23/09/2026.')
w('- **PAP EL BASMALA**, ligne 2439 : versement de 300 000 DA daté **20/08/2026** juste après un BL du 19/10/2026 — gardé tel quel (peut-être 20/10/2026).')
w('- **WAHAB** (ligne 63) et **OUSSALMA** (ligne 175) : versements sans date dans Excel → datés comme la ligne précédente.')
w('- **BOUHADJAM**, ligne 839 : la date du BL de 65 500 DA est passée du 27/09/2026 au 11/10/2026 dans le nouveau fichier ; le BL est déplacé en octobre.\n')
w('## Test\n')
w('Testé sur une copie vide du schéma de l\'application : premier import complet (tel que livré), puis cette mise à jour → '
  'aucune erreur ; les 36 clients de Feuil1 ont exactement le solde du nouveau fichier ; les 16 clients de 2019 et les '
  '7 fournisseurs n\'ont pas bougé ; aucun numéro de BL / facture en double ou manquant ; caisse sans mouvement importé ; '
  'relancer un fichier est refusé ; lancer la mise à jour sans le premier import est refusé.\n')
open(os.path.join(OUT, 'RAPPORT_MISE_A_JOUR.md'), 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')
print(nb_bl, nb_pay, other, len(corr))
