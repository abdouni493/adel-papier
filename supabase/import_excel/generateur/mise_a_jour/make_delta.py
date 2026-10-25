# usage: python make_delta.py <out dir> <shipped import_excel dir> <source label>
import json, sys, os, re, glob, datetime
OUT, SHIPPED, SRC = sys.argv[1], sys.argv[2], sys.argv[3]
HERE = os.path.dirname(os.path.abspath(__file__))
os.makedirs(OUT, exist_ok=True)
delta = json.load(open(os.path.join(HERE, 'delta.json'), encoding='utf-8'))
new = json.load(open(os.path.join(HERE, 'new_events.json'), encoding='utf-8'))
TAG = 'maj_2026-10-25'

def q(s): return "'" + str(s).replace("'", "''") + "'"
def row_of(k): return int(re.sub(r'\D', '', k))
NOTE_RE = re.compile(r"import_excel\.pay\('[^']*', '[^']*', [0-9.]+, '(?:especes|cheque|virement)', ('(?:[^']|'')*')")

def notes_of(sql):
    m = NOTE_RE.search(sql); return m.group(1) if m else None

def strip_notes(sql):
    n = notes_of(sql); return sql.replace(n, "''") if n else sql

corr, adds, report = [], [], []
for key, d in delta.items():
    name = d['name']
    c_lines, a_lines = [], []
    for o, n in d['changed']:
        r = row_of(o['k'])
        if not n['sql']:
            assert o['type'] == 'bl', o
            c_lines.append(f"select import_excel.del_bl({q(key)}, {r});  -- bon vide 0 DA (signe parasite dans Excel)")
            report.append((key, name, r, 'Bon vide supprimé', '« ' + (', '.join(x[0] for x in (o['lines'] or [])) or 'aucune ligne') + ' » — 0 DA'))
        elif o['type'] == 'bl' and n['type'] == 'bl':
            s = n['sql'][0]
            assert s.startswith(f"select import_excel.bl({q(key)}, ")
            c_lines.append(s.replace(f"select import_excel.bl({q(key)}, ", f"select import_excel.redo_bl({q(key)}, {r}, ", 1))
            report.append((key, name, r, 'Bon corrigé', f"{o['date']} {o['amount']:,.2f} → {n['date']} {n['amount']:,.2f}"
                           + ('' if o['lines'] == n['lines'] else ' · lignes modifiées')))
        elif o['type'] == 'pay' and n['type'] == 'pay' and strip_notes(o['sql'][0]) == strip_notes(n['sql'][0]):
            c_lines.append(f"select import_excel.fix_pay_note({q(key)}, {r}, {notes_of(n['sql'][0])});")
            report.append((key, name, r, 'Note de versement corrigée', notes_of(n['sql'][0])[1:-1][:60]))
        else:
            raise SystemExit(f'unhandled change {key} {o["k"]}: {o["sql"]} -> {n["sql"]}')
    for o in d['removed']:
        raise SystemExit(f'unhandled removal {key} {o["k"]}')
    for e in d['added']:
        a_lines += e['sql']
    if c_lines: corr.append(f"-- {key} · {name}\n" + '\n'.join(c_lines))
    if a_lines:
        adds.append(f"-- ---------------------------------------------------------------------------\n"
                    f"--  {key} · {name} — {len(d['added'])} nouveau(x) mouvement(s) · solde Excel {d['old_final']:,.2f} → {d['new_final']:,.2f} DA\n"
                    f"-- ---------------------------------------------------------------------------\n".replace(',', ' ')
                    + '\n'.join(a_lines))

# empty bons created by the first import from the 2019 sheet (same rule as the fixed parser)
for f in glob.glob(os.path.join(SHIPPED, '03_*.sql')):
    for l in open(f, encoding='utf-8'):
        m = re.match(r"select import_excel\.bl\('(S\d+)', .*?'(\[\[.*?\]\])'::jsonb, .*'Import Excel Situation client L(\d+)", l)
        if not m: continue
        lines = json.loads(m.group(2))
        if all(p == 0 and not re.search(r'[A-Za-z]{2}', n) for n, _, p in lines):
            corr.append(f"-- {m.group(1)}\nselect import_excel.del_bl({q(m.group(1))}, {m.group(3)}, 'Situation client');  -- bon vide 0 DA")
            report.append((m.group(1), 'SARL NOURYNE' if m.group(1) == 'S23' else m.group(1), int(m.group(3)), 'Bon vide supprimé', '« ' + ', '.join(x[0] for x in lines) + ' » — 0 DA'))

HDR = f"-- Généré le {datetime.date(2026, 10, 25)} à partir de « {SRC} » — ne pas modifier à la main.\n"
def wrap(fname, title, body):
    return (f"-- =============================================================================\n--  MISE À JOUR IMPORT EXCEL · {title}\n"
            f"-- =============================================================================\n{HDR}"
            f"begin;\nset local statement_timeout = 0;\nselect import_excel.start_file({q(TAG + '/' + fname)});\n\n{body}\n\ncommit;\n")

prep = open(os.path.join(HERE, 'maj_prep.sql'), encoding='utf-8').read()
open(os.path.join(OUT, '10_preparation_maj.sql'), 'w', encoding='utf-8', newline='\n').write(prep)
open(os.path.join(OUT, '11_corrections.sql'), 'w', encoding='utf-8', newline='\n').write(
    wrap('11_corrections.sql', '11 · CORRECTIONS DES LIGNES DÉJÀ IMPORTÉES', '\n\n'.join(corr)))
open(os.path.join(OUT, '12_nouveaux_mouvements.sql'), 'w', encoding='utf-8', newline='\n').write(
    wrap('12_nouveaux_mouvements.sql', '12 · NOUVEAUX BONS DE LIVRAISON ET VERSEMENTS', '\n\n'.join(adds)))

# finalisation: caisse + numbering + control against the new Excel balances
fin = open(os.path.join(HERE, 'maj_finish.sql'), encoding='utf-8').read()
vals = ',\n  '.join(f"({q(k)}, {new[k]['final']:.2f})" for k in sorted(new))
open(os.path.join(OUT, '19_finalisation_maj.sql'), 'w', encoding='utf-8', newline='\n').write(fin.replace('/*EXPECTED*/', vals))
json.dump(report, open(os.path.join(HERE, 'maj_report.json'), 'w', encoding='utf-8'), ensure_ascii=False)
print('corrections', len(report), 'clients with new data', len(adds), 'new statements', sum(len(a.splitlines()) - 4 for a in adds))
