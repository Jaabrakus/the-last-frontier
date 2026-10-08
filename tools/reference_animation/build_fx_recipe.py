"""Resolve particle emitters/LODs while preserving raw property payloads.
Missing serialized properties are deliberately not filled with guessed defaults.
"""
import argparse
import hashlib
import json
from pathlib import Path


def recipe(path):
    source = json.loads(path.read_text())
    exports, imports = source['Exports'], source['Imports']
    def prop(e, key, default=None):
        return next((p.get('Value', p.get('EnumValue')) for p in e.get('Data', []) if p['Name'] == key), default)
    def obj(index):
        if not index:
            return None
        if index < 0:
            return {'import_index':index, **imports[-index-1]}
        e = exports[index-1]
        c = e.get('ClassIndex', 0)
        return {'export_index':index, 'name':e['ObjectName'], 'class':imports[-c-1]['ObjectName'] if c<0 else str(c), 'properties':e.get('Data', [])}
    systems = [e for e in exports if e.get('ClassIndex',0)<0 and imports[-e['ClassIndex']-1]['ObjectName']=='ParticleSystem']
    assert len(systems)==1, path
    emitters=[]
    for ref in prop(systems[0], 'Emitters', []):
        e=exports[ref['Value']-1]
        lods=[]
        for level in prop(e,'LODLevels',[]):
            lod=exports[level['Value']-1]
            lods.append({'export_index':level['Value'], 'explicit_level':prop(lod,'Level'), 'explicit_enabled':prop(lod,'bEnabled'), 'properties':lod.get('Data',[]), 'required':obj(prop(lod,'RequiredModule')), 'spawn':obj(prop(lod,'SpawnModule')), 'type_data':obj(prop(lod,'TypeDataModule')), 'modules':[obj(x['Value']) for x in prop(lod,'Modules',[])]})
        emitters.append({'export_index':ref['Value'], 'name':prop(e,'EmitterName',e['ObjectName']), 'properties':e.get('Data',[]), 'lods':lods})
    return {'source':str(path.resolve()), 'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'status':'extracted definition; Godot parity unverified', 'missing_property_policy':'Unknown/inherited; never assume zero or disabled.', 'emitters':emitters, 'imports':imports, 'exports':exports}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('decoded',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    rows=[]
    for path in sorted(args.decoded.rglob('*_FxP.json')):
        data=recipe(path)
        target=args.output/(path.stem+'.recipe.json')
        target.write_text(json.dumps(data,indent=2))
        rows.append({'name':path.stem,'emitters':[e['name'] for e in data['emitters']],'recipe':str(target)})
    (args.output/'index.json').write_text(json.dumps(rows,indent=2))
    print(json.dumps(rows,indent=2))

if __name__=='__main__':
    main()
