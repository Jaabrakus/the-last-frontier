import json, collections, functools
P=__import__('_vendor_paths').GRAPH_JSON  # vendored path shim
D=json.load(open(P))
N=D['nodes']; F=D['functions']; S=D['states']
B={k:v for k,v in N.items() if v['type']=='anim-node-blend'}
A={k:v for k,v in N.items() if v['type']=='anim-node-animation'}
def leaves(nid):
    n=N.get(nid)
    if n is None: return []
    if n['type']=='anim-node-animation': return [n['clip']]
    return leaves(n['left'])+leaves(n['right'])
def expr(fid):
    if not fid: return None
    f=F[fid]
    return f['straight_line_return'] or 'BRANCHY'
def render(nid, ind=0, show_cb=True):
    n=N.get(nid); pad='  '*ind
    if n is None: return pad+f'?? {nid}\n'
    if n['type']=='anim-node-animation':
        cb = f"  leafcb={expr(n['callback'])}" if n.get('callback') else ''
        rf = f" flags={n['raw_flags']}" if n['raw_flags']!='0x00000000' else ''
        return pad+f"CLIP {n['clip']} [{n['clip_id']}]{rf}{cb}\n"
    s=pad+f"BLEND {n['offset']} mode={n['raw_mode_bytes'][:2]} x18={n['raw_0x18'][-1]} w={n['weight_callback'] and n['weight_callback'][-8:]} :: {expr(n['weight_callback'])}\n"
    s+=pad+' L:\n'+render(n['left'],ind+1)
    s+=pad+' R:\n'+render(n['right'],ind+1)
    return s
# parents and states
parents=collections.defaultdict(list)
for k,v in B.items():
    parents[v['left']].append((k,'L')); parents[v['right']].append((k,'R'))
def subtree(nid):
    out=[nid]; n=N.get(nid)
    if n and n['type']=='anim-node-blend':
        out+=subtree(n['left'])+subtree(n['right'])
    return out
node_states=collections.defaultdict(list)
for s in S:
    if s.get('tree'):
        for x in subtree(s['tree']): node_states[x].append(s['name'])
