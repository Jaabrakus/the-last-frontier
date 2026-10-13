"""Extract and decode a source particle dependency closure, retaining evidence.
Uses an existing uncompressed UE4 pak index and the local UAssetAPI TreeReader.
Does not generate Godot effects or assert visual equivalence.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import struct
import subprocess


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--pak', type=Path, required=True)
    p.add_argument('--index', type=Path, required=True)
    p.add_argument('--reader', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('packages', nargs='+')
    a = p.parse_args()
    entries = json.loads(a.index.read_text())
    by_stem = {}
    for entry in entries:
        by_stem.setdefault(entry['path'].rsplit('.', 1)[0], []).append(entry)
    out = a.output
    out.mkdir(parents=True, exist_ok=True)
    seen, missing, manifest, reports = set(), set(), [], []
    pending = set(a.packages)
    env = dict(os.environ, DOTNET_CLI_HOME='/private/tmp/spellbreak-animation-study/dotnet-home')
    with a.pak.open('rb') as archive:
        while pending:
            wave = sorted(pending - seen)
            if not wave:
                break
            seen.update(wave)
            paths = []
            for stem in wave:
                if stem not in by_stem:
                    missing.add(stem)
                    continue
                for entry in by_stem[stem]:
                    rel = PurePosixPath(entry['path'])
                    assert not rel.is_absolute() and '..' not in rel.parts
                    assert not entry['compression'] and not entry['flags'] & 1
                    archive.seek(entry['offset'])
                    header = archive.read(50)
                    _, size, usize, compression = struct.unpack_from('<QQQB', header)
                    assert (size, usize, compression) == (entry['size'], entry['uncompressed'], 0)
                    data = archive.read(size)
                    assert hashlib.sha1(data).hexdigest() == entry['sha1'] == header[25:45].hex()
                    dest = out / 'cooked' / rel
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(data)
                    sha = hashlib.sha256(data).hexdigest()
                    assert hashlib.sha256(dest.read_bytes()).hexdigest() == sha
                    manifest.append({'path': str(rel), 'size': size, 'sha256': sha, 'pak_sha1': entry['sha1']})
                    if rel.suffix == '.uasset':
                        paths.append(str(rel))
            if not paths:
                break
            listing = out / 'decode_wave.txt'
            listing.write_text('\n'.join(paths) + '\n')
            subprocess.run(['dotnet', str(a.reader), str(out/'cooked'), str(out/'decoded'), str(listing)], env=env, check=True)
            report = json.loads((out/'decoded/decode_report.json').read_text())
            reports.extend(report)
            pending = set()
            for row in report:
                if not row['success']:
                    continue
                data = json.loads((out/'decoded'/Path(row['path']).with_suffix('.json')).read_text())
                for imp in data.get('Imports', []):
                    name = imp.get('ObjectName', '')
                    if imp.get('ClassName') == 'Package' and name.startswith('/Game/'):
                        pending.add('g3/Content/' + name[len('/Game/'):])
                    elif imp.get('ClassName') == 'Package' and name.startswith('/Engine/'):
                        pending.add('Engine/Content/' + name[len('/Engine/'):])
            pending -= seen
    (out/'manifest.json').write_text(json.dumps({'source':str(a.pak), 'roots':a.packages, 'files':manifest, 'missing_packages':sorted(missing)}, indent=2))
    (out/'decode_report.json').write_text(json.dumps(reports, indent=2))
    print(json.dumps({'packages':len(reports), 'files':len(manifest), 'missing':sorted(missing), 'decode_errors':sum(not r['success'] for r in reports), 'raw_exports':sum(r.get('raw_exports',0) for r in reports)}, indent=2))

if __name__ == '__main__':
    main()
