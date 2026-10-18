"""Parse SITUATION.xlsx client strips into a ledger of events and verify
against the running 'Reste à payer' checkpoints written in the sheet."""
import openpyxl, sys, datetime, json, re, unicodedata

def norm(v):
    if isinstance(v, str):
        v = v.replace('\xa0', ' ').strip()
        return v
    return v

def low(v):
    if not isinstance(v, str): return ''
    v = unicodedata.normalize('NFKD', v).encode('ascii', 'ignore').decode().lower().strip()
    return re.sub(r'\s+', ' ', v)

def num(v):
    if isinstance(v, bool): return None
    if isinstance(v, (int, float)): return float(v)
    if isinstance(v, str):
        t = v.replace(' ', '').replace('\xa0', '').replace(',', '.')
        try: return float(t)
        except ValueError: return None
    return None

def dt(v):
    if isinstance(v, datetime.datetime): return v.date()
    if isinstance(v, datetime.date): return v
    return None

HEADER_C3 = {'quant.', 'qun', 'pds, kg', 'poids. t', 'qnt', 'qnt/kg', 'quantite'}
TOTAL_C3 = {'total', 'montant h.t', 'total. tva'}
PAY_WORDS = ('verss', 'verse', 'versm', 'espece', 'espace', 'cheque', 'virem', 'virm', 'v irm', 'ver',
             'achat', 'remise', 'retour', 'fransbabk', 'bna', 'bea', 'badr', 'sga', 'cpa', 'agb', 'bdl',
             'baraka', 'natixis', 'n ', 'agenda', 'difference', 'reste')

def classify_label(c3):
    l = low(c3)
    if not l: return None
    if l in HEADER_C3: return 'header'
    if l in TOTAL_C3 or l == 'total': return 'total'
    if l.startswith('reste') or l == 'montant total': return 'reste'
    if l.startswith('solde init'): return 'solde'
    return 'label'


def parse_strip(rows, k, sheet):
    get = lambda r, j: norm(r[k + j]) if k + j < len(r) else None
    name = addr = None
    for r in rows[:8]:
        for j in range(6):
            v = get(r, j)
            if isinstance(v, str) and low(v).startswith('nom'):
                rest = v.split(':', 1)[1].strip() if ':' in v else ''
                nxt = [get(r, jj) for jj in range(j + 1, 6)]
                nxt = [x for x in nxt if isinstance(x, str) and x.strip()]
                name = ' '.join(([rest] if rest else []) + nxt).strip()
            if isinstance(v, str) and low(v).startswith('adresse'):
                rest = v.split(':', 1)[1].strip() if ':' in v else ''
                nxt = [get(r, jj) for jj in range(j + 1, 6)]
                nxt = [x for x in nxt if isinstance(x, str) and x.strip()]
                addr = ' '.join(([rest] if rest else []) + nxt).strip()
    items = []          # sequence of raw items
    block = None
    def flush():
        nonlocal block
        if block and (block['lines'] or block.get('total')):
            items.append(block)
        block = None
    for ri, r in enumerate(rows[8:], start=9):
        c = [get(r, j) for j in range(6)]
        if all(x is None or (isinstance(x, str) and not x) for x in c): continue
        lab = classify_label(c[3])
        if lab is None and classify_label(c[4]) in ('total', 'reste', 'solde'):
            lab = classify_label(c[4])
        l0 = low(c[0]); l2 = low(c[2])
        if lab == 'header' or l0.startswith('bln') or l0.startswith('bl n') or l0 == 'ref' or l2.startswith('designation') or low(c[1]) == 'date':
            flush()
            block = {'kind': 'block', 'row': ri, 'bl': None, 'date': dt(c[1]), 'lines': [], 'total': None, 'tag': None}
            continue
        if lab == 'reste':
            flush()
            items.append({'kind': 'reste', 'row': ri, 'value': num(c[5]), 'raw': c[5],
                          'soft': low(c[3]) == 'montant total' or low(c[4]) == 'montant total'})
            continue
        if lab == 'solde':
            items.append({'kind': 'solde', 'row': ri, 'value': num(c[5])})
            continue
        if lab == 'total':
            if block is None:
                block = {'kind': 'block', 'row': ri, 'bl': None, 'date': None, 'lines': [], 'tag': None}
            block['total'] = num(c[5]); block['total_row'] = ri
            flush()
            continue
        is_marker = bool(re.match(r'^(v|fa?\d*|a)$', l0)) and lab not in ('total', 'reste', 'solde')
        if re.sub(r'\s+', '', l2).startswith(('vers', 'verss')) and lab is None:
            is_marker = True
        if isinstance(c[1], str) and low(c[1]).startswith('vers') and num(c[5]):
            is_marker = True; c[2] = c[2] or c[1]
        if (lab == 'label' or is_marker) and not num(c[5]) and not dt(c[1]):
            continue   # empty marker row ('V', '1ER' ...) inside a block
        if lab == 'label' or is_marker:
            # payment / credit style row: label in c3, amount in c5
            flush()
            items.append({'kind': 'pay', 'row': ri, 'marker': c[0], 'date': dt(c[1]), 'desc': c[2] if not isinstance(c[2], datetime.datetime) else None,
                          'label': c[3], 'amount': num(c[5]), 'extra': c[4]})
            continue
        # an amount alone on its row, outside any bon = the running balance written without label
        if block is None and all(x is None or x == '' for x in c[:5]) and num(c[5]) is not None:
            items.append({'kind': 'reste', 'row': ri, 'value': num(c[5]), 'raw': c[5], 'unlabeled': True})
            continue
        # plain line
        if block is None:
            block = {'kind': 'block', 'row': ri, 'bl': None, 'date': None, 'lines': [], 'total': None, 'tag': None, 'headless': True}
        if c[0] is not None and block['bl'] is None and not block['lines']:
            block['bl'] = c[0]
        elif c[0] is not None and isinstance(c[0], str) and block['tag'] is None:
            block['tag'] = c[0]
        if dt(c[1]) and block['date'] is None: block['date'] = dt(c[1])
        if (block['lines'] and c[2] is None and c[3] is None and c[4] is None and num(c[5])
                and abs(sum((num(x['amount']) or 0) for x in block['lines']) - num(c[5])) <= 1.0):
            block['total'] = num(c[5]); block['total_row'] = ri; block['implicit_total'] = True
            flush(); continue
        if l2.startswith('total'):
            continue   # yearly subtotal ('TOTAL /2018') — already counted in the blocks above
        line = {'row': ri, 'c0': c[0], 'date': dt(c[1]), 'name': c[2], 'qty': c[3], 'pu': c[4], 'amount': c[5]}
        if not (c[2] is None and num(c[5]) in (None, 0.0) and c[3] is None):
            block['lines'].append(line)
    flush()
    return {'sheet': sheet, 'strip': k // 6, 'col': k, 'name': name, 'address': addr, 'items': items}


def load(path):
    wb = openpyxl.load_workbook(path, data_only=True)
    out = []
    for sheet in ['Situation client', 'Feuil1']:
        ws = wb[sheet]
        rows = [list(r) for r in ws.iter_rows(values_only=True)]
        ncol = max(len(r) for r in rows)
        for k in range(0, ncol, 6):
            st = parse_strip(rows, k, sheet)
            if st['name'] or st['items']:
                out.append(st)
    return out

if __name__ == '__main__':
    strips = load(sys.argv[1])
    for st in strips:
        nb = sum(1 for i in st['items'] if i['kind'] == 'block')
        npay = sum(1 for i in st['items'] if i['kind'] == 'pay')
        print(st['sheet'][:5], st['strip'], repr(st['name']), repr(st['address']), 'blocks', nb, 'pays', npay)
