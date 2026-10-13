"""The web build's pack cut into parts for Reddit (files up to 100 MB, each upload within 30 s): <dir>/index.pck becomes
index.pck.000, .001, ... of at most --mb MB each, listed in index.pck.parts.json, which tools/web/shell.html reads to
join them in the browser. The whole index.pck is removed (--keep keeps it).
    python3 -I tools/web/split_pck.py <build dir> [--mb 24] [--keep]
"""
import hashlib
import json
import os
import sys


def main(argv: list) -> int:
    d = argv[0]
    mb = float(argv[argv.index('--mb') + 1]) if '--mb' in argv else 24.0
    keep = '--keep' in argv
    src = os.path.join(d, 'index.pck')
    for old in os.listdir(d):
        if old.startswith('index.pck.') and old[len('index.pck.'):].isdigit():
            os.remove(os.path.join(d, old))
    size = os.path.getsize(src)
    step = int(mb * 1024 * 1024)
    parts = []
    with open(src, 'rb') as f:
        i = 0
        while True:
            data = f.read(step)
            if not data:
                break
            name = 'index.pck.%03d' % i
            with open(os.path.join(d, name), 'wb') as out:
                out.write(data)
            parts.append({'file': name, 'offset': i * step, 'size': len(data)})
            i += 1
    # (the build's id: the page asks for each part with ?v=<id>, so a browser's cached parts of another build are never
    # joined with this one's)
    h = hashlib.sha1()
    with open(src, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    with open(os.path.join(d, 'index.pck.parts.json'), 'w') as f:
        json.dump({'size': size, 'build': h.hexdigest()[:12], 'parts': parts}, f, indent=1)
    if not keep:
        os.remove(src)
    print('index.pck %.1f MB -> %d parts of up to %.0f MB' % (size / 1048576, len(parts), mb))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
