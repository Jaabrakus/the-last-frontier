"""Thủy Vân dress: build cloth2 garments and their bold variants in one Blender session, and cache each built mesh for
the renders (run inside Blender on a COPY of the Actor_B rig library, through the shared lock wrapper):

    zsh tools/thuyvan/bin/blender_run.sh -b <copy>/actor_b_rig_copy.blend --python-exit-code 1 \
        --python tools/thuyvan_art/dress/dress_session.py -- --ids tv_mf_wrap_vest,tv_mf_trousers \
        [--variants tv_mf_shoulder_mantle@B,...] [--no-export] --cache <dir>

- `--ids`: garments built and exported exactly as tools/character/build_cloth2.py does (assets/character/garments/
  <set>/<id>.glb + .json, merged into catalog.json), each in a try block so one failure does not stop the rest; the
  log prints `CLOTH2_GLB <path>` for cloth_bake.py and `DRESS_OK` / `DRESS_FAIL` per id with its checks.
- `--variants`: `<id>@<key>` built in memory only (never exported): the garment module's VARIANTS[key] style patch
  (tools/thuyvan_art/dress/variants.py) applied to its STYLE.
- `--cache`: every built garment (and variant) written as <cache>/<id>.npz: the female and male fit positions, the
  faces, the corner UVs (metres), zones and parts; dress_render.py renders from these without the rig.
"""

import argparse
import importlib
import json
import os
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
CHAR = os.path.join(ROOT, "tools", "character")
for p in (CHAR, HERE):
    if p not in sys.path:
        sys.path.insert(0, p)

import numpy as np  # noqa: E402

from lib.context import BuildContext  # noqa: E402
from lib.sdf import log, set_log_tag  # noqa: E402


def cache_mesh(path, m, uvparts, spec, entry=None):
    from cloth2 import export as EX
    from cloth2.mesh import weld
    m = weld(m)
    m.recompute_normals()
    uv = EX.corner_uv(m, uvparts)
    zones = {str(z.idx): {"name": z.name, "role": z.role, "default": z.default} for z in spec.zones}
    meta = {"id": spec.id, "set": spec.set, "slot": spec.slot, "zones": zones, "extra": spec.extra,
            "tris": int(len(m.F)), "budget": spec.budget}
    if entry:
        meta["checks"] = entry.get("checks", {})
        meta["hides_regions"] = entry.get("hides_regions", [])
    np.savez_compressed(path, Vf=m.V["f"].astype(np.float32), Vm=m.V["m"].astype(np.float32), F=m.F.astype(np.int32),
                        uv=uv.astype(np.float32), zone=m.fa["zone"].astype(np.int16), part=m.fa["part"].astype(np.int16),
                        meta=json.dumps(meta))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="dress_session.py")
    ap.add_argument("--ids", default="")
    ap.add_argument("--variants", default="")
    ap.add_argument("--no-export", action="store_true")
    ap.add_argument("--cache", required=True)
    args = ap.parse_args(argv)
    set_log_tag("dress")
    os.makedirs(args.cache, exist_ok=True)
    t0 = time.time()
    from cloth2.fit import Fits
    from cloth2 import export as EX
    from cloth2 import garment as G
    import variants as VR
    ctx = BuildContext()
    fits = Fits(ctx)
    log("fits ready (%.1fs)" % (time.time() - t0))
    exported = 0
    report = {}
    for gid in [s for s in args.ids.split(",") if s]:
        t1 = time.time()
        try:
            mod = importlib.import_module("cloth2.garments." + gid)
            entry = mod.build_and_export(ctx, fits, export=not args.no_export)
            m, uvparts, kw = G.built(fits, gid)
            cache_mesh(os.path.join(args.cache, gid + ".npz"), m.copy(), uvparts, mod.SPEC, entry)
            clear = {k: (v["min_mm"], v["inside_skin"]) for k, v in entry["checks"]["clearance"].items()}
            report[gid] = {"ok": True, "tris": entry["stats"]["tris"], "budget": mod.SPEC.budget, "clearance": clear,
                           "secs": round(time.time() - t1, 1)}
            print("DRESS_OK %s %s" % (gid, json.dumps(report[gid])))
            exported += 0 if args.no_export else 1
        except Exception as e:  # noqa: BLE001 (a failed garment is reported, the rest still build)
            traceback.print_exc()
            report[gid] = {"ok": False, "error": repr(e), "secs": round(time.time() - t1, 1)}
            print("DRESS_FAIL %s %s" % (gid, repr(e)))
        sys.stdout.flush()
    if exported:
        try:
            n = EX.merge_catalog()
            log("catalog: %d entries" % n)
        except Exception:
            traceback.print_exc()
    for vid in [s for s in args.variants.split(",") if s]:
        t1 = time.time()
        try:
            gid, key = vid.split("@")
            mod = importlib.import_module("cloth2.garments." + gid)
            build = VR.variant_build(mod, gid, key)
            m, uvparts, kw = G.built(fits, vid, build, mod.SPEC)
            cache_mesh(os.path.join(args.cache, vid + ".npz"), m.copy(), uvparts, mod.SPEC)
            report[vid] = {"ok": True, "tris": int(len(m.F)), "secs": round(time.time() - t1, 1)}
            print("DRESS_OK %s %s" % (vid, json.dumps(report[vid])))
        except Exception as e:  # noqa: BLE001
            traceback.print_exc()
            report[vid] = {"ok": False, "error": repr(e)}
            print("DRESS_FAIL %s %s" % (vid, repr(e)))
        sys.stdout.flush()
    path = os.path.join(args.cache, "report_%d.json" % int(time.time()))
    with open(path, "w") as f:
        json.dump(report, f, indent=1)
    log("done in %.1fs: %s" % (time.time() - t0, path))


if __name__ == "__main__":
    main()
