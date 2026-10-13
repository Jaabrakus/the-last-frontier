"""Step 1 of the grey-box build, plain python3 (no Blender, so it runs outside the shared lock): polygonize the kit
SDFs and reshape the Mộc Tinh body, writing one npz per figure for build_greybox.py (Blender: QEM decimation,
weights, rig with extension bones, glb, poses, Eevee renders).

    python3 tools/thuyvan_art/bodies/prepare_greybox.py OUT_DIR [floodborn|moc_tinh|all] [variants] [sexes]
"""

import os
import sys
import time

sys.dont_write_bytecode = True
import warnings  # noqa: E402

warnings.filterwarnings("ignore")
import libshim  # noqa: E402,F401

import numpy as np  # noqa: E402

from lib.sdf import polygonize, log, set_log_tag  # noqa: E402
from skeleton import Joints, FRONTIER  # noqa: E402


def tris(Q):
    Q = np.asarray(Q)
    return np.concatenate([Q[:, [0, 1, 2]], Q[:, [0, 2, 3]]])


def poly(node, h, name):
    V, Q = polygonize(node, h, name)
    return V, tris(Q)


def floodborn(out, var, sex, J):
    import floodborn_shapes as FS
    P = FS.variant(var, sex)
    N = FS.build_nodes(J, P)
    rec = {}
    for k, h in (("body", 0.0045), ("eyes", 0.002), ("teeth", 0.0016), ("crest", 0.003)):
        if N.get(k) is None:
            continue
        V, F = poly(N[k], h, k)
        rec[k + "_V"], rec[k + "_F"] = V, F
    path = os.path.join(out, "floodborn_%s_%d.npz" % (var, int(sex)))
    np.savez_compressed(path, **rec)
    log("wrote %s" % path)


def moc_tinh(out, var, sex, J, H):
    import moc_tinh_shapes as MS
    P = MS.variant(var, sex)
    B = MS.build(H, P, sex)
    rec = {"body_V": B["V"], "body_F": B["F"], "body_W": B["W"].astype(np.float32), "bones": np.array(B["bones"]),
           "head_top": B["head_top"], "lift": B["lift"]}
    Vb, Fb, Wb, attrs = MS.bark_shell(H, B["V"], P)
    rec.update({"bark_V": Vb, "bark_F": Fb, "bark_W": Wb.astype(np.float32), "bark_crack": attrs["crack"],
                "bark_fade": attrs["fade"]})
    for k, node in B["nodes"].items():
        if node is None:
            continue
        h = 0.0035 if k in ("vines", "vine_leaves", "spurs") else 0.0045
        V, F = poly(node, h, k)
        rec[k + "_V"], rec[k + "_F"] = V, F
    rec["flowers"] = np.array([np.concatenate([c, n]) for c, n in B["flowers"]]) if B["flowers"] else np.zeros((0, 6))
    cb = B["crown_bones"]
    rec["kit_names"] = np.array([b[0] for b in cb])
    rec["kit_parents"] = np.array([b[1] for b in cb])
    rec["kit_heads"] = np.array([b[2] for b in cb])
    rec["kit_tails"] = np.array([b[3] for b in cb])
    rec["kit_deform"] = np.array([b[4] for b in cb])
    if H.color is not None:
        rec["body_color"] = H.color
    path = os.path.join(out, "moc_tinh_%s_%d.npz" % (var, int(sex)))
    np.savez_compressed(path, **rec)
    log("wrote %s" % path)


def main():
    set_log_tag("prepare_greybox")
    out = sys.argv[1]
    kit = sys.argv[2] if len(sys.argv) > 2 else "all"
    variants = sys.argv[3] if len(sys.argv) > 3 else "ABC"
    sexes = [float(s) for s in (sys.argv[4] if len(sys.argv) > 4 else "0").split(",")]
    os.makedirs(out, exist_ok=True)
    J = Joints.from_json()
    t = time.time()
    if kit in ("floodborn", "all"):
        for v in variants:
            for s in sexes:
                floodborn(out, v, s, J)
    if kit in ("moc_tinh", "all"):
        import moc_tinh_shapes as MS
        from glb_read import read_glb
        H = MS.Human(read_glb(os.path.join(FRONTIER, "assets/character/body/body.glb")), J)
        for v in variants:
            for s in sexes:
                moc_tinh(out, v, s, J, H)
    log("done in %.0fs" % (time.time() - t))


if __name__ == "__main__":
    main()
