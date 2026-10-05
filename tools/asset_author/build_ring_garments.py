"""Builds the Tidebreak ring dress (cloth2 garments, set "ring") inside Blender, on a COPY of the Actor_B rig library
(as tools/character/build_cloth2.sh does; the scratchpad wrapper runs it under the one-heavy-process lock):

    Blender -b <copy of Actor_B_001.blend> --python-exit-code 1 --python tools/asset_author/build_ring_garments.py -- all
    Blender ... -- ring_fire_top,ring_trousers_fitted [--no-export]
    then: python3 tools/character/cloth_bake.py <each new glb>; Godot --headless --path . --import

Needs ANIMATION_SOURCE_ROOT (the rig backup: blender_libraries/Actor_B_001.blend and Actor_B_021.blend) and the body
cache tools/character/cache/body_v1.npz. Writes assets/character/garments/ring/<id>.glb + .json and merges ONLY the
ring entries (and the set's label and tooltip) into assets/character/catalog.json (the other entries are left as they
are on disk). The recipes are in tools/asset_author/ring_garments/ (one module per garment, cloth2's garment API).
"""

import argparse
import importlib
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
CHAR = os.path.join(os.path.dirname(HERE), "character")
for p in (CHAR, HERE):
    if p not in sys.path:
        sys.path.insert(0, p)

from lib.context import BuildContext  # noqa: E402
from lib.sdf import log, set_log_tag  # noqa: E402

# build order: what a garment is fitted over comes first
ORDER = ["ring_trousers_fitted", "ring_trousers_wide", "ring_trousers_wrapped",
         "ring_earth_tunic", "ring_water_parka", "ring_fire_top", "ring_air_tunic",
         "ring_sash_earth", "ring_sash_fire", "ring_sash_air", "ring_water_belt",
         "ring_shoes", "ring_water_boots", "ring_arm_wraps", "ring_wrist_guards"]
GENERATOR = "tools/asset_author/ring_garments"


def merge(ids):
    from ring_garments import _common as C
    from cloth2 import export as EX
    cat = json.load(open(EX.CATALOG))
    root = os.path.join(EX.ASSETS, "garments", C.SET)
    n = 0
    for gid in ids:
        f = os.path.join(root, gid + ".json")
        if not os.path.exists(f):
            continue
        e = json.load(open(f))
        e["generator"] = "%s/%s.py" % (GENERATOR, gid)
        e["provenance"] = e.get("provenance", "").replace("generated procedurally by tools/character/cloth2/garments",
                                                          "generated procedurally by " + GENERATOR)
        with open(f, "w") as fh:
            json.dump(e, fh, indent=1)
        cat["items"][gid] = e
        n += 1
    cat["sets"][C.SET] = C.SET_LABEL
    cat.setdefault("set_tooltips", {})[C.SET] = C.SET_TIP
    with open(EX.CATALOG, "w") as fh:
        json.dump(cat, fh, indent=1)
    return n


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="build_ring_garments.py")
    ap.add_argument("ids", nargs="?", default="all")
    ap.add_argument("--no-export", action="store_true")
    args = ap.parse_args(argv)
    set_log_tag("ring")
    t0 = time.time()
    from ring_garments import _common as C
    C.install_palette()
    import cloth2.garments  # noqa: F401  (the package the over() lookups import from)
    mods = {}
    for gid in ORDER:
        mod = importlib.import_module("ring_garments." + gid)
        sys.modules["cloth2.garments." + gid] = mod
        mods[gid] = mod
    from cloth2.fit import Fits
    ctx = BuildContext()
    fits = Fits(ctx)
    log("fits %s (%.1fs)" % (sorted(fits.V), time.time() - t0))
    want = ORDER if args.ids == "all" else [g for g in ORDER if g in set(args.ids.split(","))]
    if args.ids != "all" and len(want) != len(set(args.ids.split(","))):
        raise SystemExit("unknown ids: %s" % sorted(set(args.ids.split(",")) - set(ORDER)))
    for gid in want:
        log("---- %s" % gid)
        mods[gid].build_and_export(ctx, fits, export=not args.no_export)
    if want and not args.no_export:
        log("catalog: %d ring entries merged" % merge(want))
    log("done in %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
