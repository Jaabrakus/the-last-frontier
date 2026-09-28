"""Builds cloth2 garments (run inside Blender by build_cloth2.sh):

    tools/character/build_cloth2.sh shirt_linen,breeches            # by id (tools/character/cloth2/garments/<id>.py)
    tools/character/build_cloth2.sh all
    tools/character/build_cloth2.sh --no-export shirt_linen         # build and report, write nothing

Writes assets/character/garments/<set>/<id>.glb + .json and merges the entries into assets/character/catalog.json.
"""

import argparse
import glob
import importlib
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from lib.context import BuildContext  # noqa: E402
from lib.sdf import log, set_log_tag  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="build_cloth2.py")
    ap.add_argument("ids", nargs="?", default="all")
    ap.add_argument("--no-export", action="store_true")
    ap.add_argument("--no-merge", action="store_true")
    ap.add_argument("--remove-sets", default="", help="catalog sets whose old garments are dropped from catalog.json")
    args = ap.parse_args(argv)
    set_log_tag("cloth2")
    t0 = time.time()
    from cloth2.fit import Fits
    from cloth2 import export as EX
    ctx = BuildContext()
    fits = Fits(ctx)
    log("fits %s, cloth proxy %d verts %d tris (%.1fs)" % (sorted(fits.V), len(fits.PV["f"]), len(fits.pF), time.time() - t0))
    files = sorted(glob.glob(os.path.join(HERE, "cloth2", "garments", "*.py")))
    want = None if args.ids == "all" else set(args.ids.split(","))
    built = 0
    for f in files:
        gid = os.path.basename(f)[:-3]
        if gid.startswith("_") or (want is not None and gid not in want):
            continue
        mod = importlib.import_module("cloth2.garments." + gid)
        log("---- %s" % mod.SPEC.id)
        mod.build_and_export(ctx, fits, export=not args.no_export)
        built += 1
    if want and built != len(want):
        raise SystemExit("not all garments found: %s" % sorted(want))
    if built and not args.no_export and not args.no_merge:
        n = EX.merge_catalog(remove_sets=tuple(s for s in args.remove_sets.split(",") if s))
        log("catalog: %d entries" % n)
    log("done in %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
