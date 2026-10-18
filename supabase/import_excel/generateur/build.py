import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import itertools, datetime, json, re
from parse import load, num, low, dt

TODAY = datetime.date(2026, 10, 19)
MIN_DATE = datetime.date(2018, 1, 1)
TOL = 1.0

GENERIC_DESC = re.compile(r'^(v\s*e\s*r\s*s*\s*s?\s*e\s*m\s*[er]\s*n\s*t|versement|verssement|vresement|versemrnt)$')
BANKS = [('fransbabk', 'FRANSABANK'), ('fransabank', 'FRANSABANK'), ('natixis', 'NATIXIS'), ('baraka', 'AL BARAKA'),
         ('badr', 'BADR'), ('bna', 'BNA'), ('bea', 'BEA'), ('cpa', 'CPA'), ('agb', 'AGB'), ('bdl', 'BDL'),
         ('sga', 'SGA'), ('cnep', 'CNEP'), ('salam', 'AL SALAM')]


def r2(x): return round(x + 0.0, 2)


# ---------------------------------------------------------------------------
#  lines of a BL block → [[name, qty, price]] + amount
# ---------------------------------------------------------------------------
def block_lines(b):
    out = []
    for l in b['lines']:
        name = l['name']
        if isinstance(name, datetime.datetime): name = name.strftime('%d/%m/%Y')
        name = re.sub(r'\s+', ' ', str(name)).strip() if name is not None else ''
        q, p, a = num(l['qty']), num(l['pu']), num(l['amount'])
        if a is None and q and p: a = q * p
        if not a and not q and name:
            if out:                        # continuation text of the previous line
                prev = out[-1][0]
                out[-1][0] = name if prev.startswith('Article (désignation') else (prev + ' ' + name).strip()
                continue
        if not a and not name:
            continue
        if not name: name = 'Article (désignation non saisie)'
        a = a or 0.0
        if not q:
            q, price = 1.0, a
        elif p is not None and abs(q * r2(p) - a) < 0.005:
            price = r2(p)
        else:
            price = r2(a / q)
        out.append([name, q, price])
    return out


def lines_sum(lines):
    return sum(round(q, 3) * p for _, q, p in lines)


# ---------------------------------------------------------------------------
#  reconcile a strip against its « Reste à payer » checkpoints
# ---------------------------------------------------------------------------
def reconcile(st):
    evs = []
    items = st['items']
    for idx, it in enumerate(items):
        # « Montant total » written just before a real « Reste à payer » = cumulative billed, not a balance
        if it['kind'] == 'reste' and it.get('soft') and idx + 1 < len(items) and items[idx + 1]['kind'] == 'reste':
            continue
        if it['kind'] == 'block':
            lines = block_lines(it)
            ls = r2(lines_sum(lines))
            tot = it.get('total')
            amount = tot if tot is not None else ls
            evs.append({'type': 'bl', 'src': it, 'lines': lines, 'amount': r2(abs(amount)), 'alt': ls,
                        'sign': -1 if amount < 0 else 1})
        elif it['kind'] == 'pay':
            a = r2(it['amount'] or 0)
            # a negative versement in the sheet = money given back / cancelled payment (a debit)
            evs.append({'type': 'pay', 'src': it, 'amount': abs(a), 'sign': 1 if a < 0 else -1,
                        'missing': it['amount'] is None, 'negative': a < 0})
        elif it['kind'] == 'solde' and it['value'] and not evs:
            evs.append({'type': 'check', 'value': it['value'], 'row': it['row']})
        elif it['kind'] == 'reste' and it['value'] is not None:
            evs.append({'type': 'check', 'value': it['value'], 'row': it['row']})

    out = []; bal = None; pend = []; stats = {'checks': 0, 'adjust': 0, 'alt': 0, 'flip': 0, 'fill': 0}
    opening = None
    val = lambda e: e['sign'] * e['amount']
    for e in evs:
        if e['type'] != 'check':
            pend.append(e); continue
        v = e['value']
        s = sum(val(x) for x in pend)
        if bal is None:
            opening = r2(v - s); bal = v; out += pend; pend = []; continue
        stats['checks'] += 1
        diff = v - (bal + s)
        if abs(diff) > TOL:
            fixed = False
            # a) BL whose « Total » formula is wrong but whose lines are right
            for x in pend:
                if x['type'] == 'bl' and abs(x['alt'] - x['amount'] - diff) <= TOL:
                    x['amount'] = x['alt']; fixed = True; stats['alt'] += 1; break
            # b) versement whose amount cell is empty
            if not fixed:
                miss = [x for x in pend if x['type'] == 'pay' and (x['missing'] or x['amount'] == 0)]
                if len(miss) == 1 and diff < 0:
                    miss[0]['amount'] = r2(-diff); miss[0]['filled'] = True; fixed = True; stats['fill'] += 1
            # c) movements in the opposite direction (purchase from the client, refund, charge)
            if not fixed:
                for n in (1, 2):
                    for comb in itertools.combinations(range(len(pend)), n):
                        d2 = sum(-2 * val(pend[i]) for i in comb)
                        if abs(d2 - diff) <= TOL:
                            for i in comb:
                                pend[i]['sign'] *= -1; pend[i]['flipped'] = True
                            fixed = True; stats['flip'] += 1; break
                    if fixed: break
            # d) the sheet itself is wrong here: keep its balance with an explicit adjustment
            if not fixed:
                pend.append({'type': 'adjust', 'amount': r2(abs(diff)), 'sign': 1 if diff > 0 else -1,
                             'row': e['row'], 'expected': r2(bal + s), 'sheet': v})
                stats['adjust'] += 1
        out += pend; pend = []; bal = v
    out += pend
    st['opening'] = opening or 0.0
    st['closing_sheet'] = bal
    st['tail'] = r2(sum(val(x) for x in pend))
    st['events'] = out
    st['stats'] = stats
    st['computed'] = r2((opening or 0) + sum(val(x) for x in out))
    return st


# ---------------------------------------------------------------------------
#  dates
# ---------------------------------------------------------------------------
def event_date(e):
    if e['type'] == 'bl':
        b = e['src']
        return b.get('date') or next((l['date'] for l in b['lines'] if l['date']), None)
    if e['type'] == 'pay':
        return e['src']['date']
    return None


def assign_dates(st):
    evs = st['events']
    raw = [event_date(e) for e in evs]
    last = None
    gap = datetime.timedelta(days=90)
    for i, e in enumerate(evs):
        d = raw[i]
        if d is not None and (d > TODAY or d < MIN_DATE):
            e['bad_date'] = d; d = None
        if d is not None and last is not None:
            nxt = next((x for x in raw[i + 1:] if x and MIN_DATE <= x <= TODAY), None)
            # a typo year: far before the previous entry while the next entries carry on
            if d < last - gap and (nxt is None or nxt >= last - datetime.timedelta(days=15)):
                e['bad_date'] = d; d = None
            # a typo year: far after both neighbours
            elif nxt is not None and d > last + gap and d > nxt + gap and nxt >= last:
                e['bad_date'] = d; d = None
        if d is None and e.get('bad_date') and last is not None:
            # same day and month with a neighbouring year, when it fits between the entries around it
            nxt = next((x for x in raw[i + 1:] if x and MIN_DATE <= x <= TODAY), None) or TODAY
            bd = e['bad_date']
            for y in sorted({last.year, last.year + 1, nxt.year}):
                try: cand = bd.replace(year=y)
                except ValueError: continue
                if last - datetime.timedelta(days=15) <= cand <= nxt + datetime.timedelta(days=15) and cand <= TODAY:
                    d = cand; break
        if d is None:
            d = last
            if d is None:      # look ahead
                d = next((x for x in raw[i + 1:] if x and MIN_DATE <= x <= TODAY), None)
        e['date'] = d or datetime.date(2019, 1, 1)
        last = e['date']
    first = evs[0]['date'] if evs else datetime.date(2019, 1, 1)
    st['opening_date'] = first - datetime.timedelta(days=1)


# ---------------------------------------------------------------------------
#  SQL helpers
# ---------------------------------------------------------------------------
def q(s):
    if s is None: return 'null'
    return "'" + str(s).replace("'", "''") + "'"


def fnum(x):
    x = round(float(x), 3)
    return ('%.3f' % x).rstrip('0').rstrip('.') if x != int(x) else str(int(x))


def jlines(lines):
    return q(json.dumps([[n, round(a, 3), round(p, 2)] for n, a, p in lines], ensure_ascii=False)) + '::jsonb'


def bon_of(b):
    v = b.get('bl')
    if v is None: return None
    if isinstance(v, float) and v == int(v): v = int(v)
    s = str(v).strip()
    if isinstance(v, (datetime.datetime, datetime.date)): return None
    if low(s) in ('', 'v', 'vente', 'vent', 'achat'): return None
    return s


def pay_info(src):
    desc = src.get('desc'); label = src.get('label'); marker = src.get('marker')
    desc = re.sub(r'\s+', ' ', str(desc)).strip() if desc is not None else ''
    label = re.sub(r'\s+', ' ', str(label)).strip() if label is not None else ''
    marker = re.sub(r'\s+', ' ', str(marker)).strip() if marker is not None else ''
    text = low(' '.join([desc, label, marker]))
    bank = next((b for k, b in BANKS if re.search(r'(^|[^a-z])' + k, text)), None)
    method = 'especes'
    if re.search(r'ch\s?e?que|cheq|chq', text) or (bank and 'vir' not in text):
        method = 'cheque'
    elif re.search(r'v\s?ir+e?m|virm|virement', text):
        method = 'virement'
    numero = None
    m = re.search(r'(\d{5,})', desc + ' ' + label)
    if m: numero = m.group(1)
    kind = None
    if 'remise' in text: kind = 'REMISE'
    elif 'retour' in text: kind = 'RETOUR MARCHANDISE'
    elif 'achat' in text: kind = 'COMPENSATION ACHAT'
    parts = []
    for t in (label, desc):
        if t and not GENERIC_DESC.match(low(t)) and low(t) not in ('verssement', 'versement', 'espece', 'espace', 'cheque', 'virement', 'ver', 'achat') and t not in parts:
            parts.append(t)
    fm = re.match(r'^f[a]?\s*(\d+)$', low(marker))
    if fm: parts.append('Facture N° ' + fm.group(1))
    return method, numero, bank, kind, ' — '.join(parts)


def emit_strip(st, key, sheet_tag):
    out = []
    unit = None
    if any(low(l['qty']) in ('pds, kg',) for l in []): unit = 'kg'
    if st['name'] and 'TIRIKI' in st['name'].upper(): unit = 'kg'
    out.append(f"-- ---------------------------------------------------------------------------")
    out.append(f"--  {key} · {st['name']}  ({sheet_tag}, colonnes {st['col'] + 1}-{st['col'] + 6})")
    out.append(f"--  solde de départ {st['opening']:,.2f} DA · solde final Excel {st['computed']:,.2f} DA".replace(',', ' '))
    out.append(f"-- ---------------------------------------------------------------------------")
    if abs(st['opening']) > 0.004:
        if st['opening'] > 0:
            out.append(f"select import_excel.old_debt('client', {q(key)}, {q(st['opening_date'])}, {fnum(st['opening'])}, "
                       f"{q('Solde antérieur reporté — ancien fichier Excel (' + sheet_tag + ')')});")
        else:
            out.append(f"select import_excel.pay({q(key)}, {q(st['opening_date'])}, {fnum(-st['opening'])}, 'especes', "
                       f"{q('[SOLDE INITIAL CRÉDITEUR] avance du client reportée — ancien fichier Excel (' + sheet_tag + ')')});")
    for e in st['events']:
        d = q(e['date'])
        note_date = f" · date Excel corrigée ({e['bad_date']})" if e.get('bad_date') else ''
        if e['type'] == 'bl':
            b = e['src']; row = b.get('row')
            lines = [list(x) for x in e['lines']]
            if e['sign'] > 0:
                if not lines:
                    lines = [['Bon de livraison (détail non saisi dans Excel)', 1.0, e['amount']]]
                diff = r2(e['amount'] - lines_sum(lines))
                red = 0.0
                if diff > 0.004:
                    lines.append(['Écart Excel sur le total du bon', 1.0, diff])
                elif diff < -0.004:
                    red = -diff
                bon = bon_of(b)
                note = f'Import Excel {sheet_tag} L{row}' + note_date
                tag = b.get('tag')
                if tag and low(tag) not in ('v',): note += f' · {tag}'
                out.append(f"select import_excel.bl({q(key)}, {d}, {q(bon)}, {jlines(lines)}, {fnum(red)}, {q(unit)}, {q(note)});")
            else:
                if all(n.startswith('Article (désignation') for n, _, _ in lines) or not lines:
                    out.append(f"select import_excel.pay({q(key)}, {d}, {fnum(e['amount'])}, 'especes', "
                               f"{q(f'Versement (montant sans désignation dans Excel {sheet_tag} L{row}){note_date}')});")
                    continue
                desc = '; '.join(f'{n} {fnum(a)} x {fnum(p)}' for n, a, p in lines) or 'achat'
                word = 'RETOUR MARCHANDISE' if 'retour' in low(desc) else ('REMISE' if 'remise' in low(desc) else 'COMPENSATION ACHAT')
                out.append(f"select import_excel.pay({q(key)}, {d}, {fnum(e['amount'])}, 'especes', "
                           f"{q(f'[{word}] {desc} (Excel {sheet_tag} L{row}){note_date}')});")
        elif e['type'] == 'pay':
            src = e['src']; row = src['row']
            method, numero, bank, kind, txt = pay_info(src)
            if e['amount'] <= 0.004: continue
            extra = ' · montant absent dans Excel, déduit du solde' if e.get('filled') else ''
            if e['sign'] < 0:
                prefix = f'[{kind}] ' if kind else ''
                if kind: method = 'especes'
                notes = f"{prefix}{txt + ' ' if txt else ''}(Excel {sheet_tag} L{row}){extra}{note_date}".strip()
                out.append(f"select import_excel.pay({q(key)}, {d}, {fnum(e['amount'])}, {q(method)}, {q(notes)}, {q(numero)}, {q(bank)});")
            else:
                label = txt or ('Règlement versé au client (versement négatif dans Excel)' if e.get('negative') else 'Frais / débit reporté')
                out.append(f"select import_excel.charge({q(key)}, {d}, {q(label)}, {fnum(e['amount'])}, "
                           f"{q(f'Débit Excel {sheet_tag} L{row}{note_date}')});")
        elif e['type'] == 'adjust':
            txt = (f"écart du fichier Excel {sheet_tag} L{e['row']} : solde calculé {e['expected']:,.2f}, "
                   f"solde écrit {e['sheet']:,.2f}").replace(',', ' ')
            if e['sign'] > 0:
                out.append(f"select import_excel.charge({q(key)}, {d}, 'Ajustement de solde (écart Excel)', {fnum(e['amount'])}, {q(txt)});")
            else:
                out.append(f"select import_excel.pay({q(key)}, {d}, {fnum(e['amount'])}, 'especes', {q('[AJUSTEMENT EXCEL] ' + txt)});")
    return out
