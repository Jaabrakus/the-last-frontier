from lib import *
from durations import DUR
OS={o['name']:o for o in D['overlay_sets']}
PRIO={p['layer']:p['priority'] for p in D['overlay_priorities']}
def subst_map(setname):
    o=OS.get(setname)
    m={}
    if not o: return m
    for r in o['remaps']:
        if r['raw_flags'].split()[0]=='00':
            m.setdefault(r['from_clip'],r['to_clip'])
    return m
def resolve(clip, sets):
    """apply substitution remaps of overlay sets in ascending layer priority (INFERRED order)"""
    sets=sorted(sets,key=lambda n: PRIO.get(OS[n]['layer'],99) if n in OS else 99)
    chain=[clip]
    for n in sets:
        m=subst_map(n)
        if chain[-1] in m: chain.append(m[chain[-1]])
    return chain
def have(char,name): return (char,name) in DUR
