import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import openpyxl, re, datetime
from parse import num, low, dt, norm


def parse_achat(path):
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb['ACHAT']
    rows = [list(r) for r in ws.iter_rows(values_only=True)]
    ncol = max(len(r) for r in rows)
    out = []
    for k in range(0, ncol, 6):
        get = lambda r, j: norm(r[k + j]) if k + j < len(r) else None
        name = None; opening = 0.0
        for r in rows[:8]:
            for j in range(6):
                v = get(r, j)
                if isinstance(v, str) and low(v).startswith('fournisseur'):
                    rest = v.split(':', 1)[1].strip()
                    nxt = [get(r, jj) for jj in range(j + 1, 6)]
                    name = (rest or ' '.join(x for x in nxt if isinstance(x, str) and x.strip())).strip()
                if isinstance(v, str) and low(v).startswith('solde initial') and ':' in v:
                    opening = num(v.split(':', 1)[1]) or 0.0
        if not name: continue
        purchases = []; payments = []; checks = []
        cur = None; last_date = None
        for ri, r in enumerate(rows, start=1):
            if ri < 7: continue
            c = [get(r, j) for j in range(6)]
            l0, l3 = low(c[0]), low(c[3])
            if l0 == 'ref':
                cur = {'row': ri, 'date': None, 'bon': None, 'lines': [], 'total': None, 'tva_label': False}
                purchases.append(cur); continue
            if l3.startswith('total'):
                if cur is not None:
                    cur['total'] = num(c[5]); cur['tva_label'] = 'tva' in l3
                continue
            if l3.startswith('solde initial'):
                continue
            if l3.startswith('verssement') or low(c[2]).startswith('verssement'):
                amt = num(c[5])
                if amt:
                    d = dt(c[1]) or (cur['date'] if cur else None) or last_date
                    payments.append({'row': ri, 'date': d, 'amount': amt})
                continue
            if l3.startswith('reste'):
                if num(c[5]) is not None: checks.append((ri, num(c[5])))
                cur_closed = True
                continue
            if cur is not None and (c[2] or num(c[5])):
                if dt(c[1]): cur['date'] = cur['date'] or dt(c[1]); last_date = dt(c[1])
                if c[0] is not None and cur['bon'] is None:
                    cur['bon'] = str(int(c[0])) if isinstance(c[0], float) and c[0] == int(c[0]) else str(c[0])
                cur['lines'].append({'row': ri, 'name': c[2], 'qty': c[3], 'pu': c[4], 'amount': c[5]})
        for p in purchases:
            if p['date'] is None: p['date'] = last_date
        out.append({'col': k, 'name': name, 'opening': opening, 'purchases': purchases,
                    'payments': payments, 'checks': checks})
    return out


def purchase_lines(p):
    lines = []; line_tva = False
    tot = p['total'] or 0.0
    for l in p['lines']:
        name = re.sub(r'\s+', ' ', str(l['name'])).strip() if l['name'] is not None else ''
        q, pu, a = num(l['qty']), num(l['pu']), num(l['amount'])
        if a is None and q and pu:
            if tot == 0:          # unit price written but the sheet never counted it
                name += f' (P.U Excel {pu:g})'; pu = None
            else:
                a = q * pu
        if not name and not a: continue
        if not a and not q:
            if name and lines: lines[-1][0] += ' ' + name
            continue
        if not name: name = 'Article'
        a = a or 0.0
        if not q: q, price = 1.0, a
        elif pu is not None and abs(q * round(pu, 2) - a) < 0.005: price = round(pu, 2)
        elif pu is not None and abs(q * round(pu, 2) * 1.19 - a) <= 1.0:
            price = round(pu, 2); line_tva = True      # amount column already T.T.C
        elif a: price = round(a / q, 2)
        else: price = 0.0
        lines.append([name, q, price])
    ls = sum(q * pr for _, q, pr in lines)
    tva = line_tva or (ls > 0 and abs(ls * 1.19 - tot) <= 1.0)
    if ls <= 0.004 and tot > 0:
        lines.append(['Montant du bon (prix non détaillés dans Excel)', 1.0, round(tot, 2)])
        ls = tot
    amount = round(ls + round(ls * 19) / 100, 2) if tva else round(ls, 2)
    return lines, tva, amount
