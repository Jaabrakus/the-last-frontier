"""Driver of the character generators (Blender, headless, on a COPY of the rig library).

    tools/character/build_character.sh --body                 # body.glb (+ cache for the others)
    tools/character/build_character.sh --hair all            # every hair style
    tools/character/build_character.sh --hair hair_club_ribbon,hair_braid_f
    tools/character/build_character.sh --garments militia    # a set (tools/character/garments/<set>/*.py)
    tools/character/build_character.sh --garments id1,id2
    tools/character/build_character.sh --all --previews /tmp/prev

Parts are modules that define SPEC (lib.catalog.PartSpec / GarmentSpec) and build(ctx)
returning {"main": obj, "cards": obj?, "fur": obj?}; lib.pipeline.finish_part does the
rest (UVs, regions, weights, shape keys, checks, glb, catalog fragment). After a build:
`Godot --headless --path . --import`, then the checks (tools/character/README.md).
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

from lib import catalog as CAT  # noqa: E402
from lib import pipeline  # noqa: E402
from lib.context import BuildContext  # noqa: E402
from lib.sdf import log, set_log_tag  # noqa: E402


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="build_character.py")
    ap.add_argument("--body", action="store_true", help="build the full-skin body (and the body cache)")
    ap.add_argument("--hair", default="", help="'all' or comma-separated hair style ids")
    ap.add_argument("--garments", default="", help="'all', a set name, or comma-separated garment ids")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--previews", default="", help="directory for Blender preview PNGs")
    ap.add_argument("--no-export", action="store_true")
    ap.add_argument("--no-merge", action="store_true", help="do not merge the catalog fragments into catalog.json")
    return ap.parse_args(argv)


def part_modules(kind, sel):
    """[(module name, file)] of tools/character/<kind>/**.py matching `sel`."""
    root = os.path.join(HERE, kind)
    files = sorted(glob.glob(os.path.join(root, "**", "*.py"), recursive=True))
    files = [f for f in files if not os.path.basename(f).startswith("_")]
    out = []
    ids = set(s.strip() for s in sel.split(",") if s.strip())
    for f in files:
        rel = os.path.relpath(f, HERE)[:-3].replace(os.sep, ".")
        pid = os.path.basename(f)[:-3]
        subset = os.path.basename(os.path.dirname(f))
        if sel == "all" or pid in ids or subset in ids:
            out.append((rel, f))
    return out


def main():
    args = parse_args()
    set_log_tag("build_character")
    t0 = time.time()
    ctx = BuildContext()
    if args.all or args.body:
        from body import body_v4 as body_mod   # body v4: the MakeHuman body (2026-09-28); v3 = SDF body + MH head
        body_mod.build(ctx, previews=os.path.join(args.previews, "body") if args.previews else None,
                       export=not args.no_export)
    built = []
    for kind, sel in (("hair", "all" if args.all else args.hair), ("garments", "all" if args.all else args.garments)):
        if not sel:
            continue
        mods = part_modules(kind, sel)
        if not mods:
            raise SystemExit("no %s modules match %r" % (kind, sel))
        for name, f in mods:
            mod = importlib.import_module(name)
            log("---- %s (%s)" % (mod.SPEC.id, name))
            res = pipeline.build_part(ctx, mod, export=not args.no_export,
                                      previews=os.path.join(args.previews, kind) if args.previews else None)
            built.append(res)
    if built and not args.no_export and not args.no_merge:
        path, n, problems = CAT.merge_catalog()
        log("catalog: %d entries -> %s" % (n, path))
        for p in problems:
            log("CATALOG PROBLEM: %s" % p)
    if args.previews and built:
        pipeline.part_sheets(ctx, built, args.previews)
    log("done in %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
