"""Silver ball-and-cone ear bobs (costume bible §3.2, §3.3, §3.8 `ew_earbobs`).

Ball-and-cone ear bobs of trade silver [P1][P2][R2][M11]; several earrings in each ear were
usual for women (Jones counted ten [R2]). One ear bob hangs from each lobe here, a short
wire loop, a ball and a cone. Grade A.

Rigid on the head (headb).
"""

import numpy as np

from lib.sdf import Fn, RoundCone, Sphere, Union, frame_from, nrm, v3

from garments.woodlands import _common as C
from garments.woodlands import _silver as S

SPEC = C.spec(
    id="ew_earbobs", name="Silver ear bobs", slot="accessories.ears_nose", layer={"default": 85},
    description="Ball-and-cone ear bobs of trade silver, one hanging from each ear lobe on a small wire loop.",
    history="Ball-and-cone ear bobs were common trade silver (Smith [P1], Heckewelder [P2], Jones [R2], [M11]); "
            "women often wore several in each ear (Jones counted ten [R2]).",
    zones=[C.WZone(0, "metal", "MET", S.SILVER, "silver", name="ear bobs")],
    evidence="A", sources=["P1", "P2", "R2", "M11"], budget=900, tags=["men", "women"],
    extra={"count_per_ear": 1, "note": "more ear bobs up the rim: a later variant"},
)


def torus(c, axis, R, r):
    ax = nrm(axis)
    Rm = frame_from(ax, v3(0, 1, 0) if abs(ax[1]) < 0.9 else v3(1, 0, 0))

    def f(X, Y, Z):
        px, py, pz = X - c[0], Y - c[1], Z - c[2]
        lx = Rm[0, 0] * px + Rm[1, 0] * py + Rm[2, 0] * pz
        ly = Rm[0, 1] * px + Rm[1, 1] * py + Rm[2, 1] * pz
        lz = Rm[0, 2] * px + Rm[1, 2] * py + Rm[2, 2] * pz
        q = np.sqrt(lx * lx + ly * ly) - R
        return np.sqrt(q * q + lz * lz) - r
    return Fn(f, c - (R + r + 0.002), c + (R + r + 0.002))


def build(ctx):
    K = ctx.K
    hb = K["headb"]
    b = C.Builder(SPEC)
    for s, sd in ((1, "l"), (-1, "r")):
        lobe = v3(s * 0.0715, hb[1] + 0.003, hb[2] + 0.018 - 0.022)     # the lobe of the ear (body_shapes ears)
        loop = torus(lobe + v3(0, 0, -0.002), v3(0, 1, 0), 0.0045, 0.0007)
        ball_c = lobe + v3(0, 0, -0.0105)
        ball = Sphere(ball_c, 0.0032)
        cone = RoundCone(ball_c + v3(0, 0, -0.004), ball_c + v3(0, 0, -0.020), 0.0012, 0.0042)
        node = Union([loop, Union([ball, cone], k=0.0015)], k=0.0008)
        b.sdf("bob_" + sd, node, 0.0004, 260, 0, symmetric=False, max_tris=240)
    bt = b.build()
    ob, V = bt.ob, bt.V
    uv = C.loop_uvs(ob, [C.Flat(V.mean(0), (1, 0, 0), (0, 0, 1))], np.zeros(len(ob.data.polygons), int))
    W = C.rigid_W(ctx, len(V), "headb")
    return C.finish(ctx, SPEC, bt, W, uv, hide_candidates=[], focus=((0.0, 0.0, 1.43), 0.26))
