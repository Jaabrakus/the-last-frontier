"""Blender-side helper for tools/sfx/gathering_rec.py: decodes Ogg Vorbis recordings to float arrays.

The system python3 has no Vorbis decoder; Blender's bundled audaspace (`aud`) has one. gathering_rec.py runs this
script when its decode cache lacks a take:

  Blender --background --factory-startup --python tools/sfx/cc0_decode.py -- <src_root> <cache_dir> <rel.ogg>...

Each <src_root>/<rel.ogg> is resampled to 44.1 kHz (aud, high quality) and saved as float32 (n, channels) to
<cache_dir>/<pack>/<basename>.npy, where <pack> is the first folder of <rel.ogg>. Nothing else is read or written.
"""
import os
import sys

import aud
import numpy as np

SR = 44100


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 3:
        print("usage: ... -- <src_root> <cache_dir> <rel.ogg>...")
        sys.exit(2)
    src, cache, rels = argv[0], argv[1], argv[2:]
    done = 0
    for rel in rels:
        path = os.path.join(src, rel)
        pack = rel.replace("\\", "/").split("/")[0]
        name = os.path.splitext(os.path.basename(rel))[0]
        s = aud.Sound(path)
        rate = s.specs[0]
        d = s.resample(SR, True).data() if int(rate) != SR else s.data()
        os.makedirs(os.path.join(cache, pack), exist_ok=True)
        np.save(os.path.join(cache, pack, name + ".npy"), np.asarray(d, dtype=np.float32))
        done += 1
    print("CC0_DECODED", done)


main()
