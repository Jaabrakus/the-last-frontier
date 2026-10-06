import os, sys
root = sys.argv[1]
out = open(sys.argv[2], 'w')
for dp, dn, fn in sorted(os.walk(root)):
    dn.sort()
    for f in sorted(fn):
        if not f.endswith('.gd'):
            continue
        p = os.path.join(dp, f)
        lines = open(p, encoding='utf-8', errors='replace').read().splitlines()
        cls = ''
        doc = []
        for l in lines[:60]:
            if l.startswith('class_name'):
                cls = l.split()[1]
            if l.startswith('##'):
                doc.append(l[2:].strip())
                if len(' '.join(doc)) > 260:
                    break
            elif doc and not l.startswith('#'):
                break
        out.write(f"{os.path.relpath(p, root)} [{len(lines)}] {cls}: {' '.join(doc)[:280]}\n")
