"""Draft previews outside Blender: polygonize the kit SDFs (lib.sdf surface nets) and draw them with preview2d.

    python3 draft_preview.py floodborn A 0 out.png [h]
"""

import os
import sys
import time

os.environ.setdefault("PYTHONDONTWRITEBYTECODE", "1")
sys.dont_write_bytecode = True
import libshim  # noqa: F401,E402

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

from lib.sdf import polygonize  # noqa: E402
import preview2d  # noqa: E402
from skeleton import Joints  # noqa: E402
from glb_read import read_glb, merged  # noqa: E402

FRONTIER = libshim.CHARACTER_TOOLS.rsplit("/tools/", 1)[0]


def quads_to_tris(Q):
    Q = np.asarray(Q)
    return np.concatenate([Q[:, [0, 1, 2]], Q[:, [0, 2, 3]]])


def human():
    m = read_glb(os.path.join(FRONTIER, "assets/character/body/body.glb"))
    V, F, *_ = merged(m)
    return V, F


def kit_meshes(kit, var, sex, h, J):
    meshes = []
    if kit == "floodborn":
        import floodborn_shapes as FS
        P = FS.variant(var, sex)
        N = FS.build_nodes(J, P)
        V, Q = polygonize(N["body"], h, "body")
        meshes.append((V, quads_to_tris(Q), (150, 150, 150)))
        for k, col in (("eyes", (90, 80, 40)), ("teeth", (220, 215, 200)), ("crest", (110, 110, 118))):
            if N[k] is not None:
                V2, Q2 = polygonize(N[k], min(h, 0.004), k)
                meshes.append((V2, quads_to_tris(Q2), col))
    elif kit == "moc_tinh":
        import moc_tinh_shapes as MS
        H = MS.Human(read_glb(os.path.join(FRONTIER, "assets/character/body/body.glb")), J)
        P = MS.variant(var, sex)
        B = MS.build(H, P, sex)
        Vb, Fb, Wb, attrs = MS.bark_shell(H, B["V"], P)
        meshes.append((B["V"], B["F"], (120, 120, 120)))
        meshes.append((Vb, Fb, (150, 150, 150)))
        for k, col in (("spurs", (140, 140, 140)), ("roots", (140, 140, 140)), ("crown_branches", (120, 120, 125)),
                       ("crown_leaves", (175, 178, 185)), ("vines", (160, 162, 168)), ("vine_leaves", (175, 178, 185)),
                       ("moss", (170, 172, 178))):
            if B["nodes"].get(k) is not None:
                V2, Q2 = polygonize(B["nodes"][k], min(h, 0.004), k)
                meshes.append((V2, quads_to_tris(Q2), col))
        print("head top", B["head_top"], "crown top", max(m[0][:, 2].max() for m in meshes))
    return meshes


def lineup(kit, vars_, sex, out, h):
    J = Joints.from_json()
    hv, hf = human()
    img = Image.new("RGB", (900 * len(vars_), 700), (236, 228, 212))
    for i, var in enumerate(vars_):
        ms = kit_meshes(kit, var, sex, h, J)
        ox = 900 * i
        preview2d.draw([(hv, hf, (205, 195, 175))], "side", 330, origin=(ox + 560, 640), img=img)
        preview2d.draw(ms, "side", 330, origin=(ox + 560, 640), img=img)
        preview2d.draw(ms, "front", 330, origin=(ox + 760, 640), img=img)
    img.save(out)


def main():
    kit, var, sex, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
    if len(var) > 1:
        return lineup(kit, var, sex, out, float(sys.argv[5]) if len(sys.argv) > 5 else 0.008)
    h = float(sys.argv[5]) if len(sys.argv) > 5 else 0.008
    J = Joints.from_json()
    t = time.time()
    meshes = []
    if kit == "floodborn":
        import floodborn_shapes as FS
        P = FS.variant(var, sex)
        N = FS.build_nodes(J, P)
        V, Q = polygonize(N["body"], h, "body")
        meshes.append((V, quads_to_tris(Q), (150, 150, 150)))
        for k, col in (("eyes", (90, 80, 40)), ("teeth", (220, 215, 200)), ("crest", (110, 110, 118))):
            if N[k] is not None:
                V2, Q2 = polygonize(N[k], min(h, 0.004), k)
                meshes.append((V2, quads_to_tris(Q2), col))
    print("polygonized in %.1fs" % (time.time() - t))
    hv, hf = human()
    W, H = 2400, 700
    img = Image.new("RGB", (W, H), (236, 228, 212))
    for i, view in enumerate(["front", "34", "side", "back"]):
        ox = 300 + i * 560
        preview2d.draw([(hv + np.array([0.0, 0.6, 0]), hf, (205, 195, 175))], view, 330, origin=(ox - 150, 640), img=img)
        preview2d.draw(meshes, view, 330, origin=(ox + 80, 640), img=img)
    img.save(out)
    print("saved", out)


if __name__ == "__main__":
    main()
