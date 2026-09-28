import re
from lib import *
def summarize(fid):
    f=F.get(fid)
    if not f: return fid+' ?'
    if f.get('straight_line_return'): return 'RET '+f['straight_line_return']
    parts=[]
    last=None
    for ins in f['instructions']:
        m=re.match(r'0x[0-9a-f]+\s+(?:[0-9a-f]{2} ){4}\s*(\S+)\s+(.*?)\s*;\s*(.*)$',ins)
        if not m: continue
        op,args,ann=m.groups()
        if op in ('fgt','flt','fge','fle','feq','igt','ilt','ige','ile','ieq','ineq','fneq','not','load-int','call-native') or op.startswith('i') and op in ('igt','ilt'):
            last=ann
        if op=='branch-if-not':
            parts.append('AND['+(last or '?').split('=',1)[-1].strip()+']')
        elif op=='branch-if':
            parts.append('ORSKIP['+(last or '?').split('=',1)[-1].strip()+']')
        elif op=='return':
            parts.append('RET['+ann.replace('return','').strip()+']')
    return ' '.join(parts)
