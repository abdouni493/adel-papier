import json, sys, glob, collections
old = json.load(open('old_events.json', encoding='utf-8')); new = json.load(open('new_events.json', encoding='utf-8'))
shipped = collections.Counter()
for f in glob.glob(sys.argv[1] + '/02_*.sql'):
    for l in open(f, encoding='utf-8'):
        if l.startswith('select import_excel.') and "old_debt(" not in l: shipped[l.rstrip('\n')] += 1
gen = collections.Counter(s for v in old.values() for e in v['events'] for s in e['sql'])
print('shipped statements', sum(shipped.values()), 'reproduced', sum(gen.values()), 'identical:', shipped == gen)
res = {}
for key in old:
    o = {e['k']: e for e in old[key]['events']}; n = {e['k']: e for e in new[key]['events']}
    added = [e for e in new[key]['events'] if e['k'] not in o]
    removed = [e for e in old[key]['events'] if e['k'] not in n]
    changed = [(o[k], n[k]) for k in o if k in n and o[k]['sql'] != n[k]['sql']]
    if old[key]['opening'] != new[key]['opening']: print('OPENING CHANGED', key)
    if added or removed or changed:
        res[key] = {'name': new[key]['name'], 'added': added, 'removed': removed, 'changed': changed,
                    'old_final': old[key]['final'], 'new_final': new[key]['final']}
        print(f"{key} {new[key]['name'][:22]:22s} +{len(added)} -{len(removed)} ~{len(changed)}  solde {old[key]['final']:>14,.2f} -> {new[key]['final']:>14,.2f}")
        for a, b in changed: print('    ~ OLD', a['sql'][0][:150], '\n      NEW', b['sql'][0][:150] if b['sql'] else '(none)')
        for e in removed: print('    -', (e['sql'] or ['(no sql)'])[0][:150])
json.dump(res, open('delta.json', 'w', encoding='utf-8'), ensure_ascii=False)
