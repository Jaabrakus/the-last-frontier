"""Extract and decode the dependency closure of many particle systems, reading the
pak from inside the verified client backup ZIP (the loose client was deleted).

Each wave streams the pak once, front to back, collecting only the entries it
needs (sorted by offset), so no 22 GiB restore is needed. Every entry is checked
against the pak index SHA-1 and rewritten files are re-read for SHA-256.

usage:
  python3 -I extract_fx_closure_from_zip.py --zip BACKUP.zip --index pak_entries.json \
      --reader TreeReader.dll --output OUT  [--roots-file roots.txt | ROOT ...]

Roots are package stems such as g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP.
Resumable: packages already decoded under OUT are not fetched again.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import struct
import subprocess
import sys
import time
import zipfile

PAK_MEMBER = 'g3/Content/Paks/g3-WindowsNoEditor.pak'


def stream_entries(zip_path, entries):
    """Yield (entry, bytes) for entries in ascending offset order, one forward pass."""
    entries = sorted(entries, key=lambda e: e['offset'])
    with zipfile.ZipFile(zip_path) as z, z.open(PAK_MEMBER) as f:
        pos = 0
        chunk = 1 << 24
        for e in entries:
            skip = e['offset'] - pos
            while skip > 0:
                n = f.read(min(chunk, skip))
                if not n:
                    raise EOFError(e['path'])
                skip -= len(n)
            header = f.read(50)
            _, size, usize, compression = struct.unpack_from('<QQQB', header)
            assert (size, usize, compression) == (e['size'], e['uncompressed'], 0), e['path']
            data = f.read(size)
            pos = e['offset'] + 50 + size
            assert hashlib.sha1(data).hexdigest() == e['sha1'] == header[25:45].hex(), e['path']
            yield e, data


def imports_of(decoded_json):
    out = set()
    for imp in decoded_json.get('Imports', []):
        name = imp.get('ObjectName', '')
        if imp.get('ClassName') != 'Package':
            continue
        if name.startswith('/Game/'):
            out.add('g3/Content/' + name[len('/Game/'):])
        elif name.startswith('/Engine/'):
            out.add('Engine/Content/' + name[len('/Engine/'):])
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--zip', type=Path, required=True)
    p.add_argument('--index', type=Path, required=True)
    p.add_argument('--reader', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--roots-file', type=Path)
    p.add_argument('--max-waves', type=int, default=12)
    p.add_argument('roots', nargs='*')
    a = p.parse_args()
    roots = set(a.roots)
    if a.roots_file:
        roots |= {l.strip() for l in a.roots_file.read_text().splitlines() if l.strip()}
    by_stem = {}
    for entry in json.loads(a.index.read_text()):
        by_stem.setdefault(entry['path'].rsplit('.', 1)[0], []).append(entry)
    out = a.output
    (out / 'cooked').mkdir(parents=True, exist_ok=True)
    (out / 'decoded').mkdir(parents=True, exist_ok=True)
    manifest_path = out / 'manifest.json'
    state = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'files': {}, 'missing_packages': [], 'decode': {}}
    env = dict(os.environ, DOTNET_CLI_HOME=str(out / '.dotnet-home'))
    seen = set()
    pending = set(roots)
    wave = 0
    while pending and wave < a.max_waves:
        wave += 1
        todo = sorted(pending - seen)
        seen.update(todo)
        # skip packages already decoded on a previous run, but still follow their imports
        fresh, follow = [], set()
        for stem in todo:
            dj = out / 'decoded' / (stem + '.json')
            if dj.exists():
                follow |= imports_of(json.loads(dj.read_text()))
            else:
                fresh.append(stem)
        want = []
        for stem in fresh:
            if stem not in by_stem:
                state['missing_packages'].append(stem)
                continue
            for e in by_stem[stem]:
                rel = PurePosixPath(e['path'])
                assert not rel.is_absolute() and '..' not in rel.parts
                assert not e['compression'] and not e['flags'] & 1
                want.append(e)
        t0 = time.time()
        uassets = []
        for e, data in stream_entries(a.zip, want):
            dest = out / 'cooked' / e['path']
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            sha = hashlib.sha256(data).hexdigest()
            assert hashlib.sha256(dest.read_bytes()).hexdigest() == sha
            state['files'][e['path']] = {'size': e['size'], 'sha256': sha, 'pak_sha1': e['sha1']}
            if e['path'].endswith('.uasset'):
                uassets.append(e['path'])
        print(f'wave {wave}: {len(todo)} packages, {len(want)} files fetched in {time.time() - t0:.0f}s', flush=True)
        if uassets:
            listing = out / 'decode_wave.txt'
            listing.write_text('\n'.join(uassets) + '\n')
            subprocess.run(['dotnet', str(a.reader), str(out / 'cooked'), str(out / 'decoded'), str(listing)], env=env, check=True,
                           stdout=subprocess.DEVNULL)
            for row in json.loads((out / 'decoded/decode_report.json').read_text()):
                state['decode'][row['path']] = {k: row.get(k) for k in ('success', 'raw_exports', 'error') if k in row}
                if row.get('success'):
                    dj = out / 'decoded' / Path(row['path']).with_suffix('.json')
                    follow |= imports_of(json.loads(dj.read_text()))
        pending = follow - seen
        manifest_path.write_text(json.dumps(state, indent=1))
    state['missing_packages'] = sorted(set(state['missing_packages']))
    manifest_path.write_text(json.dumps(state, indent=1))
    dec = state['decode'].values()
    print(json.dumps({'waves': wave, 'files': len(state['files']), 'packages_decoded': len(state['decode']),
                      'decode_errors': sum(not d.get('success') for d in dec),
                      'raw_exports': sum(d.get('raw_exports') or 0 for d in dec),
                      'missing': len(state['missing_packages']), 'unfinished': len(pending)}, indent=1))


if __name__ == '__main__':
    sys.exit(main())
