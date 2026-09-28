import json,struct,csv,collections
P=__import__('_vendor_paths').GRAPH_JSON  # vendored path shim
D=json.load(open(P))
S=D['states']; N=D['nodes']; F=D['functions']
BYNAME={}
for s in S: BYNAME.setdefault(s['name'],s)
def f32(h): return round(struct.unpack('>f',bytes.fromhex(h))[0],4)
def fexpr(fid):
    if not fid: return None
    f=F.get(fid)
    if not f: return fid
    return f.get('straight_line_return') or ('BRANCHED:'+fid)
def tree(nid,depth=0,out=None):
    if out is None: out=[]
    ind='  '*depth
    n=N.get(nid)
    if n is None: out.append(ind+'?'+str(nid)); return out
    if n['type']=='anim-node-animation':
        out.append(f"{ind}CLIP {n['clip']} [{n['clip_id']}] flags={n['raw_flags']} cb={n.get('callback')}")
    else:
        out.append(f"{ind}BLEND {nid} mode={n['raw_mode_bytes']} s14={n['scalar_0x14']} r18={n['raw_0x18']} w={n.get('weight_callback')} :: {fexpr(n.get('weight_callback'))}")
        tree(n['left'],depth+1,out); tree(n['right'],depth+1,out)
    return out
def clips(nid,acc=None):
    if acc is None: acc=[]
    n=N.get(nid)
    if not n: return acc
    if n['type']=='anim-node-animation': acc.append(n['clip'])
    else: clips(n['left'],acc); clips(n['right'],acc)
    return acc
def cond_str(c):
    r=[x['hex'] for x in c['raw']]
    k=int(r[0],16); lo=f32(r[1]); hi=f32(r[2])
    parts=[]
    if k&2: parts.append(f">={lo}")
    if k&1: parts.append(f"<={hi}")
    s='range['+(' & '.join(parts) if parts else 'always')+']'
    if len(r)>3:
        s+=f" flags={r[3]} lambda={c.get('callback')}"
    return s
def trans_str(t):
    rw=[x['hex'] for x in t['raw']]
    return f"{t['request']:>18} -> {t['target']:<32} f1c={t['scalar_0x1c']:.3g} f20={t['scalar_0x20']:.3g} fl04={rw[1]} r28={rw[10]} r2c={rw[11]} | " + ' AND '.join(cond_str(c) for c in t['conditions'])
def short_cond(t):
    out=[]
    for c in t['conditions']:
        r=[x['hex'] for x in c['raw']]
        k=int(r[0],16); lo=f32(r[1]); hi=f32(r[2])
        p=[]
        if k&2: p.append(f">={lo:g}")
        if k&1: p.append(f"<={hi:g}")
        s='&'.join(p)
        if len(r)>3 and c.get('callback'): s+=('' if not s else ' ')+'L'+c['callback'][-5:]
        if len(r)>3 and r[3] not in ('00000001','00000000'): s+=f'[{r[3][:4]}]'
        out.append(s or '-')
    return ' AND '.join(out)
def compact(s):
    return '; '.join(f"{t['request']}->{t['target']}({t['scalar_0x1c']:.3g}|{short_cond(t)})" for t in s['transitions'])
