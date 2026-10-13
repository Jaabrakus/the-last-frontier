"""The web snapshot's Spellbreak effects cut down to the ones a public build plays (run by tools/web/prep_snapshot.sh on the
snapshot, never the project). A public build plays only the single moves the owner picked (data/bending/sb_fx/config.json
moves_on; SbFx.on is off for whole elements there, BendLooks.sb_bolt off): the effects of those entries are kept (their
specs, textures and meshes, assets/fx/spellbreak/index.json cut to them), every other file under assets/fx/spellbreak/
removed from the snapshot, and nothing from the client's MarketplaceAssets packs (third-party authors: SOURCE.md).
Provenance and the licence note: assets/fx/spellbreak/SOURCE.md (kept).
    python3 -I tools/web/prep_sbfx.py <snapshot dir>
"""
import json
import os
import sys

ELEMENTS = ['earth', 'water', 'fire', 'air']


def chain(key: str) -> list:
    out = [key]
    while '.' in key:
        key = key.rsplit('.', 1)[0]
        out.append(key)
    return out


def main(snap: str) -> int:
    if os.path.basename(os.path.normpath(snap)) == 'Frontier' or not os.path.exists(os.path.join(snap, 'project.godot')):
        print('not a snapshot:', snap)
        return 1
    root = os.path.join(snap, 'assets/fx/spellbreak')
    cfg = json.load(open(os.path.join(snap, 'data/bending/sb_fx/config.json')))
    moves_on = cfg.get('moves_on', {}) if cfg.get('enabled', False) else {}
    ids = set()
    for el in ELEMENTS:
        table = json.load(open(os.path.join(snap, 'data/bending/sb_fx/%s.json' % el))).get('moves', {})
        for key, roles in table.items():
            if not isinstance(roles, dict):
                continue
            on = set()
            for k in chain(key):
                on.update(moves_on.get(k, []))
            for role, e in roles.items():
                if isinstance(e, dict) and role in on and e.get('effect'):
                    ids.add(e['effect'])
    index_path = os.path.join(root, 'index.json')
    index = json.load(open(index_path))
    effects = index.get('effects', {})
    keep = {'SOURCE.md', 'index.json', 'materials.json'}
    for i in sorted(ids):
        e = effects.get(i)
        if e is None:
            print('not in the index: %s' % i)
            continue
        files = [e['spec']] + list(e.get('textures', [])) + list(e.get('meshes', []))
        for f in files:
            if 'MarketplaceAssets' in f:
                print('left out (a Marketplace pack): %s' % f)
                continue
            keep.add(f)
            if f.endswith('.gltf'):
                keep.add(f[:-5] + '.bin')      # (a glTF's buffer beside it)
    index['effects'] = {i: effects[i] for i in sorted(ids) if i in effects}
    removed = kept = 0
    for dirpath, _, files in os.walk(root, topdown=False):
        for fn in files:
            rel = os.path.relpath(os.path.join(dirpath, fn), root)
            base = rel[:-len('.import')] if rel.endswith('.import') else rel
            if base in keep:
                kept += 1
                continue
            os.remove(os.path.join(dirpath, fn))
            removed += 1
        if dirpath != root and not os.listdir(dirpath):
            os.rmdir(dirpath)
    json.dump(index, open(index_path, 'w'), indent=1)
    print('spellbreak: %d effects kept (%s), %d files kept, %d removed' % (
        len(index['effects']), ', '.join(i.rsplit('/', 1)[-1] for i in sorted(index['effects'])), kept, removed))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
