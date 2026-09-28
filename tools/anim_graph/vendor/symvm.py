# Symbolic path-enumerating evaluator for the anim-player script lambdas.
import struct, re
from common import F

def c(v): return ('c', v)
def isc(e): return e[0]=='c'

def add(a,b):
    if isc(a) and isc(b): return c(a[1]+b[1])
    if isc(a): a,b=b,a
    if isc(b) and b[1]==0: return a
    if isc(b) and a[0]=='+' and isc(a[2]): return add(a[1], c(a[2][1]+b[1]))
    return ('+',a,b)
def mul(a,b):
    if isc(a) and isc(b): return c(a[1]*b[1])
    if isc(a): a,b=b,a
    if isc(b) and b[1]==0: return c(0)
    if isc(b) and b[1]==1: return a
    return ('*',a,b)

def fmt(e):
    t=e[0]
    if t=='c':
        v=e[1]
        if isinstance(v,float):
            r=round(v,4); return repr(r)
        return str(v)
    if t=='arg': return f'arg{e[1]}'
    if t=='sym': return '@'+e[1]
    if t in ('ptr','f32','i32'):
        a=e[1]
        # base + offset formatting
        if a[0]=='+' and isc(a[2]): inner=f'{fmt(a[1])}+{a[2][1]}'
        else: inner=fmt(a)
        if t=='ptr':
            m={'arg0+8':'C8','arg0':'C0','arg1+8':'D8','arg1':'D0','arg1+4':'D4','arg0+4':'C4','arg2':'E0'}
            return m.get(inner, f'ptr[{inner}]')
        return f'{t}[{inner}]'
    if t=='+': return f'({fmt(e[1])} + {fmt(e[2])})'
    if t=='*': return f'({fmt(e[1])} * {fmt(e[2])})'
    if t=='bin': return f'({fmt(e[2])} {e[1]} {fmt(e[3])})'
    if t=='un': return f'{e[1]}({fmt(e[2])})'
    if t=='call': return f'@{e[1]}(' + ', '.join(fmt(x) for x in e[2]) + ')'
    return str(e)

def const_of(f, idx, kind):
    k=f['constants'].get(str(idx))
    if k is None: return ('sym', f'const{idx}?')
    h=k['hex']; interp=k.get('interpretation','')
    if kind=='float':
        return c(struct.unpack('>f', bytes.fromhex(h))[0])
    if kind=='i32':
        if interp and not re.match(r'^-?\d', interp) and '0x' not in interp: return ('sym', interp)
        v=struct.unpack('>i', bytes.fromhex(h))[0]
        return c(v)
    if kind=='name':
        return ('sym', interp or f'fn_{h}')

BIN={0x05:'+f',0x06:'-',0x07:'*f',0x08:'/',0x23:'>',0x24:'>=',0x25:'<',0x26:'<=',0x1d:'==',0x1e:'>i',0x28:'%'}
UN={0x19:'int',0x1a:'float',0x2a:'abs',0x30:'not',0x39:'neg'}

def parse(f):
    ins=[]
    for line in f['instructions']:
        p=line.split()
        addr=int(p[0],16); b=[int(x,16) for x in p[1:5]]
        ins.append((addr,b,p[5]))
    return ins

def run(fid, maxpaths=4096):
    f=F[fid]; ins=parse(f); start=int(f['code_start'],16)
    idx_of={a:i for i,(a,_,_) in enumerate(ins)}
    results=[]; loads=set()
    def fold_bin(op,a,b):
        if isc(a) and isc(b):
            x,y=a[1],b[1]
            try:
                return c({'+f':x+y,'-':x-y,'*f':x*y,'/':x/y if y else float('nan'),'>':int(x>y),'>=':int(x>=y),'<':int(x<y),'<=':int(x<=y),'==':int(x==y),'>i':int(x>y),'%':x%y if y else float('nan')}[op])
            except Exception: pass
        if op=='+f': return add(a,b)
        if op=='*f': return mul(a,b)
        return ('bin',op,a,b)
    stack=[(0,{24+i:('arg',i) for i in range(8)},[])]
    n=0
    while stack:
        pc,regs,conds=stack.pop(); n+=1
        if n>maxpaths: results.append((conds,('sym','PATH_LIMIT'))); break
        steps=0
        while True:
            steps+=1
            if pc>=len(ins) or steps>500: results.append((conds,('sym','FELL_OFF'))); break
            addr,b,mn=ins[pc]; op=b[0]; R=lambda r: regs.get(r,('sym',f'r{r}?'))
            if op==0x43: regs[b[1]]=R(b[2])
            elif op==0x3b: regs[b[1]]=add(R(b[2]),c(b[3]))
            elif op==0x3d: regs[b[1]]=mul(R(b[2]),c(b[3]))
            elif op==0x0c: regs[b[1]]=c(b[2]|(b[3]<<8))
            elif op==0x40: regs[b[1]]=const_of(f,b[2],'float')
            elif op==0x3f: regs[b[1]]=const_of(f,b[2],'i32')
            elif op==0x15: regs[b[1]]=const_of(f,b[2],'name')
            elif op==0x01: regs[b[1]]=add(R(b[2]),R(b[3]))
            elif op in (0x0f,0x0e,0x0d):
                a=add(R(b[2]),c(b[3])) if b[3] else R(b[2])
                e=({0x0f:'ptr',0x0e:'f32',0x0d:'i32'}[op],a); regs[b[1]]=e
                if op!=0x0f: loads.add(fmt(e))
            elif op in BIN: regs[b[1]]=fold_bin(BIN[op],R(b[2]),R(b[3]))
            elif op in UN:
                a=R(b[2])
                if UN[op] in ('int','float') and isc(a): regs[b[1]]=c(int(a[1]) if UN[op]=='int' else float(a[1]))
                elif UN[op]=='neg' and isc(a): regs[b[1]]=c(-a[1])
                elif UN[op]=='not' and isc(a): regs[b[1]]=c(int(not a[1]))
                else: regs[b[1]]=('un',UN[op],a)
            elif op==0x1c:
                fn=R(b[2]); nm=fn[1] if fn[0]=='sym' else fmt(fn)
                regs[b[1]]=('call',nm,[R(24+i) for i in range(b[3])])
            elif op==0x00:
                results.append((conds,R(b[1]))); break
            elif op==0x2d:
                pc=b[1]|(b[2]<<8); continue
            elif op in (0x2e,0x2f):
                tgt=b[1]|(b[3]<<8); cond=R(b[2])
                jump_when = (op==0x2e)  # branch-if jumps when true
                if isc(cond):
                    truth=bool(cond[1])
                    if truth==jump_when: pc=tgt
                    else: pc+=1
                    continue
                cs=fmt(cond)
                # jump path
                stack.append((tgt,dict(regs),conds+[cs if jump_when else f'!{cs}']))
                conds=conds+[f'!{cs}' if jump_when else cs]
                pc+=1; continue
            else:
                regs[b[1]]=('sym',f'UNK_{mn}')
            pc+=1
    return results, sorted(loads)

if __name__=='__main__':
    import sys
    for fid in sys.argv[1:]:
        res,loads=run(fid)
        print('==',fid,'loads:',loads)
        for conds,r in res:
            print('   IF', ' & '.join(conds) or 'always', '=>', fmt(r))
