# usage: python dump_events.py <generator dir> <xlsx> <out.json>
import sys, json, copy
sys.path.insert(0, sys.argv[1])
from parse import load
from build import reconcile, assign_dates, emit_strip
out = {}
for st in load(sys.argv[2]):
    if st['sheet'] != 'Feuil1': continue
    reconcile(st); assign_dates(st)
    key = 'C%02d' % (st['strip'] + 1)
    evs = []
    for e in st['events']:
        one = dict(st); one['events'] = [e]; one['opening'] = 0.0
        sql = [l for l in emit_strip(one, key, 'Feuil1') if not l.startswith('--')]
        k = ('adj%d' % e['row']) if e['type'] == 'adjust' else ('%s%d' % (e['type'], e['src']['row']))
        evs.append({'k': k, 'type': e['type'], 'sign': e['sign'], 'amount': e['amount'], 'date': str(e['date']),
                    'lines': e.get('lines'), 'sql': sql})
    out[key] = {'name': st['name'], 'opening': st['opening'], 'opening_date': str(st['opening_date']),
                'final': st['computed'], 'events': evs}
json.dump(out, open(sys.argv[3], 'w', encoding='utf-8'), ensure_ascii=False, default=str)
print('clients', len(out), 'events', sum(len(v['events']) for v in out.values()))
