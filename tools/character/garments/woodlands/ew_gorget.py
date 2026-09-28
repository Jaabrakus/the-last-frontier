"""Silver crescent gorget (costume bible §3.2, §3.8 `ew_gorget`).

A crescent gorget worn at the throat, a common diplomatic gift; Joseph Brant's of 1776 is in
the Joseph Brant Museum [M11]; silver ornaments are listed by Smith [P1], Heckewelder [P2]
and Jones [R2]. Hung on a ribbon round the neck. Grade A.

Rigid on the upper spine (spined), over the shirt's collar; the ribbon follows the base of
the neck (the body's weights there, smoothed along it).
"""

import numpy as np

from lib.body_shapes import neck_shape, torso_shapes
from lib.sdf import Offset, RoundCone, Union, nrm, sdf_normal, surface_point, v3

from garments.woodlands import _common as C
from garments.woodlands import _silver as S

SPEC = C.spec(
    id="ew_gorget", name="Silver gorget", slot="accessories.neck", layer={"default": 85},
    description="A crescent-shaped silver gorget worn at the throat on a silk ribbon round the neck.",
    history="Crescent gorgets of trade silver were given as diplomatic gifts and worn at the throat; Joseph "
            "Brant's of 1776 survives [M11]. Silver ornaments of the period are described by Smith [P1], "
            "Heckewelder [P2] and Jones [R2].",
    zones=[C.WZone(0, "metal", "MET", S.SILVER, "silver", name="gorget"),
           C.WZone(1, "ribbon", "FLAT", ["ribbon_black", "ribbon_red", "ribbon_blue", "ribbon_green"], "ribbon_black",
                   name="ribbon")],
    evidence="A", sources=["M11", "P1", "P2", "R2"], budget=900, tags=["men"],
)

Z_HORNS = 1.318


def build(ctx):
    K = ctx.K
    b = C.Builder(SPEC)
    chest = Offset(Union([torso_shapes(K, smooth=True), neck_shape(K)], k=0.05), 0.0105)
    z0 = Z_HORNS - 0.042

    def on_chest(u, v):
        return surface_point(chest, v3(u, -0.3, z0 + v), v3(0, 1, 0), 0.0, 0.3)
    P = S.crescent_grid(on_chest, width=0.096, drop=0.042)
    N = np.broadcast_to(v3(0, -1, 0), P.shape)
    C.sheet_piece(b, "plate", P, 0.0016, 0, normals=N)
    # ribbon: from each horn up round the back of the neck
    neck = Offset(C.body_f(ctx), 0.0085)
    pts = []
    for a in np.linspace(-140.0, 140.0, 15):
        r = np.radians(a)
        d = v3(np.sin(r), np.cos(r), 0.0)                  # a = 0: the back of the neck
        z = Z_HORNS + 0.012 + 0.030 * (1 + np.cos(r)) * 0.5
        c = v3(0, K["neck"][1] + 0.004, z)
        pts.append(surface_point(neck, c + d * 0.15, -d, 0.0, 0.15))
    left, right = P[1, -1], P[1, 0]
    path = [right] + pts + [left] if pts[0][0] < 0 else [left] + pts + [right]
    rib = Union([RoundCone(path[i], path[i + 1], 0.0016, 0.0016) for i in range(len(path) - 1)], k=0.001)
    b.sdf("ribbon", rib, 0.0006, 500, 1, symmetric=False, max_tris=420)
    bt = b.build()
    ob, V = bt.ob, bt.V
    part = np.full(len(ob.data.polygons), -1, int)
    part[bt.pmask("ribbon")] = 0
    yc = K["neck"][1]
    uv = C.loop_uvs(ob, [C.Cyl((0, yc, 1.4), (0, yc, 1.2), (0, -1, 0))], part, vertex_uv=bt.attrs["uv"])
    W = C.rigid_W(ctx, len(V), "spined")
    rm = bt.vmask("ribbon")
    Wr = C.body_W(ctx, V[rm])
    from lib.weights import band_smooth
    Wr = band_smooth(Wr, V[rm], np.ones(rm.sum(), int))
    # the front of the ribbon (near the horns) as the plate
    t = np.clip((V[rm, 1] - (-0.06)) / 0.05, 0, 1)[:, None]
    W[rm] = W[rm] * (1 - t) + Wr * t
    W = C.normalize(W)
    return C.finish(ctx, SPEC, bt, W, uv, hide_candidates=[], focus=((0.0, -0.05, 1.28), 0.30))
