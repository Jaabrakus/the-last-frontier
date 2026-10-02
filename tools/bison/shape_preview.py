"""Quick look at the bison's shape (no rig, coat or clips): the skin, horns and hooves polygonised coarsely and
rendered beside the horse, side and three-quarters, in headless Blender.

  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/bison/shape_preview.py -- OUT_DIR [h]
"""

import importlib.util
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
HORSE = os.path.join(HERE, "..", "horse")
sys.path.insert(0, HORSE)
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True

import anatomy as A           # noqa: E402  (the bison's)
import blender_util as U      # noqa: E402
import sdf                    # noqa: E402


def horse_anatomy():
    spec = importlib.util.spec_from_file_location("horse_anatomy", os.path.join(HORSE, "anatomy.py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def mesh(name, node, h, col, dx=0.0):
    V, Q = sdf.polygonize(node, h)
    V = V + np.array([dx, 0.0, 0.0])
    ob = U.mesh_object(name, V, Q, U.material(name + "_m", col, 0.8))
    return ob


def hooves(mod, dx):
    Vs, Fs, off = [], [], 0
    for s in ("l", "r"):
        for hind in (False, True):
            V, F, _uv = mod.hoof_mesh_detail(s, hind)
            Vs.append(V + np.array([dx, 0, 0]))
            Fs += [[i + off for i in f] for f in F]
            off += len(V)
    return U.mesh_object("Hooves%d" % int(dx), np.concatenate(Vs), Fs, U.material("hoof%d" % int(dx), "#2b2520", 0.5))


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    out = a[0]
    h = float(a[1]) if len(a) > 1 else 0.014
    U.reset_scene()
    mesh("Bison", A.horse_body(), h, "#4a3222")
    mesh("Horns", A.horns(), 0.006, "#1c1814")
    hooves(A, 0.0)
    H = horse_anatomy()
    mesh("Horse", H.horse_body(), h, "#7a4527", dx=-1.6)
    hooves(H, -1.6)
    U.render_views(out, "shape", center=(-0.8, -0.3, 0.95), dist=7.2,
                   views={"side": (1, 0, 0.08), "front34": (0.75, -0.75, 0.22)}, res=(1200, 700))
    U.render_views(out, "bison", center=(0, -0.15, 1.0), dist=5.4,
                   views={"side": (1, 0, 0.06), "front34": (0.7, -0.7, 0.2), "back34": (0.6, 0.75, 0.25)}, res=(1000, 700))


main()
