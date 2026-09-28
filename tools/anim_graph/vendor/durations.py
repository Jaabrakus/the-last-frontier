import csv
rows=list(csv.DictReader(open(__import__('_vendor_paths').INDEX_CSV)))  # vendored path shim
DUR={}   # (char,name)->(dur,kind,rate,count)
for r in rows:
    if r['kind']=='pose': continue
    key=(r['character'],r['original_name'])
    d=float(r['sample_count'])/float(r['sample_rate'])
    # prefer 'clip' over stitched
    if key not in DUR or (DUR[key][1]!='clip' and r['kind']=='clip'):
        DUR[key]=(d,r['kind'],float(r['sample_rate']),int(r['sample_count']),r['action_name'])
def dur(name,char='Actor_A'):
    v=DUR.get((char,name))
    return v
