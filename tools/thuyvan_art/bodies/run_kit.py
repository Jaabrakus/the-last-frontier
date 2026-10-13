"""One Blender session (through the shared lock wrapper) that builds a kit if its .blend is missing, then renders
whatever grey and paint shots are not done yet. Re-run until every shot exists (each run is capped at 1100 s).

    ANIMATION_SOURCE_ROOT=<scratch>/src BLENDER_TIMEOUT=1100 zsh tools/thuyvan/bin/blender_run.sh \\
        -b <scratch>/work/actor_b_rig_copy.blend --python-exit-code 1 -P tools/thuyvan_art/bodies/run_kit.py -- \\
        --kit floodborn --npz DIR --save X.blend --glb assets/thuyvan/bodies --tex DIR --out DIR
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True
import libshim  # noqa: E402,F401

import bpy  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    for k in ("--kit", "--npz", "--save", "--tex", "--out"):
        ap.add_argument(k, required=True)
    ap.add_argument("--glb", default="")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--stages", default="grey,paint")
    a = ap.parse_args(argv)
    import build_greybox
    import render_bodies
    if not os.path.exists(a.save):
        build_greybox.build(a.kit, a.npz, a.save, a.glb)
    bpy.ops.wm.open_mainfile(filepath=a.save)
    scene = None
    if "grey" in a.stages:
        scene = render_bodies.run(a.kit, a.tex, a.out, False, "", a.samples)
    if "paint" in a.stages:
        render_bodies.run(a.kit, a.tex, a.out, True, "", a.samples, scene=scene)


if __name__ == "__main__":
    main()
