import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import json, datetime, re
from parse import load, low
from build import reconcile, assign_dates, emit_strip, q, fnum, jlines
from suppliers import parse_achat, purchase_lines

XLSX, OUT, SETUP = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.join(OUT, 'annulation'), exist_ok=True)

strips = load(XLSX)
for st in strips:
    reconcile(st); assign_dates(st)

fe = [s for s in strips if s['sheet'] == 'Feuil1']
si = [s for s in strips if s['sheet'] == 'Situation client' and s['name'] and s['events']]

def key_name(n):
    return re.sub(r'[^a-z0-9]', '', low(n or ''))

fe_keys = {key_name(s['name']): s for s in fe}
# the same client written under a slightly different name in the 2019 sheet
SAME = {'imdb': 'imdbyazid', 'taziripap': 'taziri', 'alsultane': 'alsultanenassim'}
si_only, si_overlap, si_optional = [], [], []
for s in si:
    k = key_name(s['name'])
    if k in fe_keys:
        si_overlap.append(s)
    elif k in SAME and SAME[k] in fe_keys:
        if k == 'imdb': si_overlap.append(s)
        else: si_optional.append((s, fe_keys[SAME[k]]))
    else:
        si_only.append(s)
# SARL NOURYNE appears twice in the 2019 sheet: one client
seen = {}
for s in si_only:
    seen.setdefault(key_name(s['name']), s)

for i, s in enumerate(fe): s['key'] = 'C%02d' % (s['strip'] + 1)
for i, s in enumerate(si_only): s['key'] = 'S%02d' % (s['strip'] + 1)
for s, target in si_optional: s['key'] = target['key']

HDR = "-- Généré automatiquement depuis SITUATION.xlsx le %s — ne pas modifier à la main.\n" % datetime.date.today()

def wrap(name, title, body):
    return (f"-- =============================================================================\n"
            f"--  IMPORT EXCEL · {title}\n"
            f"-- =============================================================================\n{HDR}"
            f"begin;\nset local statement_timeout = 0;\nselect import_excel.start_file({q(name)});\n\n{body}\n\ncommit;\n")

files = []
def write(name, title, body):
    path = os.path.join(OUT, name)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(wrap(name, title, body))
    files.append(name)

# ---------------------------------------------------------------- 00 setup
setup = open(SETUP, encoding='utf-8').read()
with open(os.path.join(OUT, '00_preparation.sql'), 'w', encoding='utf-8', newline='\n') as f:
    f.write(setup.replace('-- =============================================================================\n', '', 0))
files.append('00_preparation.sql')

# ---------------------------------------------------------------- 01 clients
cl = []
for s in fe:
    cl.append(f"select import_excel.client({q(s['key'])}, {q(s['name'])}, {q(s['address'] or '')}, "
              f"{q('Importé de SITUATION.xlsx — feuille Feuil1, colonnes %d-%d' % (s['col'] + 1, s['col'] + 6))});")
for s in seen.values():
    cl.append(f"select import_excel.client({q(s['key'])}, {q(s['name'])}, {q(s['address'] or '')}, "
              f"{q('Importé de SITUATION.xlsx — feuille « Situation client » (2019), colonnes %d-%d' % (s['col'] + 1, s['col'] + 6))});")
write('01_clients.sql', 'CRÉATION DES CLIENTS (%d)' % len(cl), '\n'.join(cl))

# ---------------------------------------------------------------- 02 Feuil1 movements, chunked
chunk, size, part = [], 0, 1
for s in fe:
    body = '\n'.join(emit_strip(s, s['key'], 'Feuil1')) + '\n'
    if size and size + len(body) > 250_000:
        write('02_clients_mouvements_partie%d.sql' % part, 'BONS DE LIVRAISON ET VERSEMENTS — PARTIE %d' % part, '\n'.join(chunk))
        chunk, size, part = [], 0, part + 1
    chunk.append(body); size += len(body)
if chunk:
    write('02_clients_mouvements_partie%d.sql' % part, 'BONS DE LIVRAISON ET VERSEMENTS — PARTIE %d' % part, '\n'.join(chunk))

# ---------------------------------------------------------------- 03 2019-only clients
body = []
for s in si_only:
    k = seen[key_name(s['name'])]['key']
    body.append('\n'.join(emit_strip(s, k, 'Situation client')))
write('03_clients_2019_feuille_situation.sql', 'CLIENTS PRÉSENTS SEULEMENT DANS LA FEUILLE « Situation client » (2019)', '\n\n'.join(body))

# ---------------------------------------------------------------- 04 suppliers
sup = parse_achat(XLSX)
sb = []; sup_report = []
for i, s in enumerate(sup, start=1):
    key = 'F%02d' % i; s['key'] = key
    sb.append(f"-- ---------------------------------------------------------------------------\n--  {key} · {s['name']}\n"
              f"-- ---------------------------------------------------------------------------")
    sb.append(f"select import_excel.supplier({q(key)}, {q(s['name'])});")
    evs = []
    first = min([p['date'] for p in s['purchases'] if p['date']] + [y['date'] for y in s['payments'] if y['date']])
    total = s['opening']
    if s['opening']:
        sb.append(f"select import_excel.old_debt('supplier', {q(key)}, {q(first - datetime.timedelta(days=1))}, {fnum(s['opening'])}, "
                  f"'Solde initial reporté — ancien fichier Excel (ACHAT)');")
    for p in s['purchases']:
        lines, tva, amt = purchase_lines(p)
        if not lines or (amt <= 0 and all(pr == 0 and qq == 1 for _, qq, pr in lines)):
            continue   # empty template block of the sheet
        evs.append((p['date'], p['row'], 'p', (lines, tva, amt, p)))
    for y in s['payments']:
        evs.append((y['date'] or first, y['row'], 'v', y))
    for d, row, kind, x in sorted(evs, key=lambda e: (e[0], e[1])):
        if kind == 'p':
            lines, tva, amt, p = x
            total += amt
            sb.append(f"select import_excel.purchase({q(key)}, {q(d)}, {q(p['bon'])}, {jlines(lines)}, {'true' if tva else 'false'}, "
                      f"{q('Import Excel ACHAT L%d' % row + (' · TVA 19%' if tva else ''))});")
        else:
            total -= x['amount']
            sb.append(f"select import_excel.spay({q(key)}, {q(d)}, {fnum(x['amount'])}, {q('Versement (Excel ACHAT L%d)' % row)});")
    sheet = [c for c in s['checks'] if c[1]]
    sup_report.append((key, s['name'], s['opening'], round(total, 2), sheet[-1][1] if sheet else None))
    sb.append('')
write('04_fournisseurs.sql', 'FOURNISSEURS, FACTURES D\'ACHAT ET RÈGLEMENTS (feuille ACHAT)', '\n'.join(sb))

# ---------------------------------------------------------------- 05 optional 2019 data of 2 clients
body = ["-- ATTENTION : ces mouvements de 2019 concernent des clients qui existent aussi dans\n"
        "-- Feuil1, mais Feuil1 démarre leur compte à 0. Si vous exécutez ce fichier, leur solde\n"
        "-- dans l'application AUGMENTERA du solde 2019 ci-dessous. À n'exécuter que si ces\n"
        "-- montants n'ont jamais été réglés."]
for s, t in si_optional:
    body.append('\n'.join(emit_strip(s, t['key'], 'Situation client')))
write('05_optionnel_2019_TAZIRI_AL_SULTANE.sql', 'OPTIONNEL — HISTORIQUE 2019 DE TAZIRI ET AL SULTANE', '\n\n'.join(body))

# ---------------------------------------------------------------- 99 finalisation & rollback
fin = open(os.path.join(os.path.dirname(SETUP), 'sql_finish.sql'), encoding='utf-8').read()
with open(os.path.join(OUT, '99_finalisation.sql'), 'w', encoding='utf-8', newline='\n') as f: f.write(fin)
files.append('99_finalisation.sql')
rb = open(os.path.join(os.path.dirname(SETUP), 'sql_rollback.sql'), encoding='utf-8').read()
with open(os.path.join(OUT, 'annulation', 'ANNULER_TOUT_L_IMPORT.sql'), 'w', encoding='utf-8', newline='\n') as f: f.write(rb)

# ---------------------------------------------------------------- single file
order = [f for f in files if not f.startswith('05_')]
with open(os.path.join(OUT, 'IMPORT_COMPLET.sql'), 'w', encoding='utf-8', newline='\n') as f:
    f.write('-- Fichier unique : 00 → 04 puis 99_finalisation (le fichier 05 optionnel n\'est PAS inclus).\n\n')
    for name in order:
        f.write(open(os.path.join(OUT, name), encoding='utf-8').read() + '\n\n')

# ---------------------------------------------------------------- data for the report / test
rep = {'clients': [], 'suppliers': sup_report, 'si_overlap': [], 'si_optional': [], 'si_only': []}
def summary(s):
    ev = s['events']
    return {
        'key': s.get('key'), 'name': s['name'], 'sheet': s['sheet'], 'cols': f"{s['col'] + 1}-{s['col'] + 6}",
        'opening': s['opening'], 'final': s['computed'],
        'sheet_final': None if s['closing_sheet'] is None else round(s['closing_sheet'] + s['tail'], 2),
        'bl': sum(1 for e in ev if e['type'] == 'bl' and e['sign'] > 0),
        'bl_lines': sum(len(e['lines']) for e in ev if e['type'] == 'bl' and e['sign'] > 0),
        'pay': sum(1 for e in ev if e['type'] == 'pay' and e['sign'] < 0),
        'credit_bl': sum(1 for e in ev if e['type'] == 'bl' and e['sign'] < 0),
        'charges': sum(1 for e in ev if e['type'] == 'pay' and e['sign'] > 0),
        'adjust': [(e['row'], e['sign'] * e['amount'], e['expected'], e['sheet'], str(e['date'])) for e in ev if e['type'] == 'adjust'],
        'bad_dates': [(str(e['bad_date']), str(e['date']), (e.get('src') or {}).get('row')) for e in ev if e.get('bad_date')],
        'filled': [((e.get('src') or {}).get('row'), e['amount']) for e in ev if e.get('filled')],
        'credits': [((e.get('src') or {}).get('row'), e['amount'], str(e['date']),
                     '; '.join(n for n, _, _ in e['lines'])[:60]) for e in ev if e['type'] == 'bl' and e['sign'] < 0],
        'debits': [((e.get('src') or {}).get('row'), e['amount'], str(e['date']),
                    ' '.join(str(x) for x in ((e['src'].get('desc') or ''), (e['src'].get('label') or '')) if x)[:60])
                   for e in ev if e['type'] == 'pay' and e['sign'] > 0],
        'bl_total': round(sum(e['amount'] for e in ev if e['type'] == 'bl' and e['sign'] > 0), 2),
        'pay_total': round(sum(e['amount'] for e in ev if e['type'] == 'pay' and e['sign'] < 0), 2),
        'first': str(ev[0]['date']) if ev else None, 'last': str(ev[-1]['date']) if ev else None,
        'checks': s['stats']['checks'],
    }
rep['clients'] = [summary(s) for s in fe]
rep['si_only'] = [summary(s) for s in si_only]
rep['si_overlap'] = [summary(s) for s in si_overlap]
rep['si_optional'] = [summary(s) for s, _ in si_optional]
with open(os.path.join(os.path.dirname(SETUP), 'report.json'), 'w', encoding='utf-8') as f:
    json.dump(rep, f, ensure_ascii=False, indent=1, default=str)
print('files:', files)
for name in os.listdir(OUT):
    print(name, os.path.getsize(os.path.join(OUT, name)))
