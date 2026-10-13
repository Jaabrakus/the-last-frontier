"""Index decoded third-party particle definitions without inferring missing defaults.
Usage: python3 particle_catalogue.py /path/to/particle_reference
"""
from pathlib import Path
import collections
import html
import json
import sys

root = Path(sys.argv[1])
rows = []
counts = collections.Counter()
for path in sorted((root / 'decoded').rglob('*.json')):
    if path.name == 'decode_report.json':
        continue
    data = json.loads(path.read_text())
    imports = data.get('Imports', [])
    modules = []
    materials = sorted({x['ObjectName'] for x in imports
                        if x.get('ClassName') in ('Material', 'MaterialInstanceConstant')})
    for export in data.get('Exports', []):
        index = export.get('ClassIndex', 0)
        cls = imports[-index - 1]['ObjectName'] if index < 0 else 'local export class'
        if cls.startswith('Particle'):
            counts[cls] += 1
            modules.append({'name': export['ObjectName'], 'class': cls,
                            'explicit_properties': [p['Name'] for p in export.get('Data', [])]})
    rows.append({'path': str(path.relative_to(root / 'decoded')),
                 'emitters': sum('Emitter' in m['class'] for m in modules),
                 'modules': modules, 'material_references': materials})
(root / 'particle_index.json').write_text(json.dumps({'packages': rows, 'class_counts': dict(counts)}, indent=2))
# A searchable local browser; raw JSON links retain every serialized value and object reference.
cards = []
for row in rows:
    name = row['path'].removesuffix('.json')
    classes = sorted({m['class'] for m in row['modules']})
    cards.append('<article><h2><a href="decoded/' + html.escape(row['path'], quote=True) + '">' +
                 html.escape(name) + '</a></h2><p>' + str(row['emitters']) +
                 ' emitter exports · ' + str(len(row['modules'])) + ' particle exports</p><p>' +
                 html.escape(', '.join(classes)) + '</p><small>Materials: ' +
                 html.escape(', '.join(row['material_references'])) + '</small></article>')
(root / 'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>Particle reference study</title>
<style>body{background:#15212a;color:#e5e8ec;font:16px system-ui;max-width:1100px;margin:40px auto;padding:20px}input{width:95%;padding:14px;font:inherit}article{padding:18px;margin:16px 0;background:#20323e;border-radius:10px}h2{font-size:16px;overflow-wrap:anywhere}a{color:#8fddd0}p,small{line-height:1.5}</style>
<h1>Spellbreak particle reference</h1><p>853 cooked definitions. These are third-party reference files, not Godot effects. Click a package for decoded values. Missing properties may use inherited defaults; this browser does not infer them. Materials are references, not converted shaders. Compiled/native behavior has not been reconstructed.</p>
<input id="search" placeholder="Search Earth, Fire, Trail, Impact, ColorOverLife…"><main>''' + ''.join(cards) + '''</main>
<script>document.querySelector('#search').addEventListener('input',e=>{let q=e.target.value.toLowerCase();document.querySelectorAll('article').forEach(a=>a.hidden=!a.textContent.toLowerCase().includes(q))});</script>''')
print(json.dumps({'packages': len(rows), 'top_particle_classes': counts.most_common(12)}, indent=2))
