"""Silver ring brooches in rows (costume bible §3.2, §3.3, §3.8 `ew_brooches`).

Rows of small silver ring brooches on shirts, blankets and skirts: Cresswell noted as many as
500 on one woman's clothing [R2]; Seneca dresses with more than 200 are known [M11]; dress
shifts were covered with small brooches (Cresswell [R1]); heart-and-crown ("Luckenbooth")
designs became something of a Haudenosaunee emblem [M11][R18]. This item: the "rows"
density on a shirt front (down both sides of the front opening and across the upper chest).
Plain ring brooches only (heart-and-crown and council-fire designs belong to specific
communities; left for review, §3.7). Grade A.

Each brooch is a rigid piece with the weights of the torso under its centre.
"""

import math

import numpy as np

from lib.body_shapes import neck_shape, torso_shapes
from lib.sdf import Offset, Union, nrm, sdf_normal, surface_point, v3

from garments.woodlands import _common as C
from garments.woodlands import _silver as S

SPEC = C.spec(
    id="ew_brooches", name="Silver brooches, rows", slot="accessories.neck", layer={"default": 85},
    description="Rows of small silver ring brooches pinned down both sides of the shirt's front opening and across "
                "the upper chest.",
    history="Rows of small ring brooches decorated shirts, blankets and skirts; Cresswell saw as many as 500 on one "
            "woman's clothing [R2]; Seneca dresses with more than 200 are known [M11].",
    zones=[C.WZone(0, "metal", "MET", S.SILVER, "silver", name="brooches")],
    evidence="A", sources=["R2", "M11", "R1"], budget=2200, tags=["men", "women"], requires=["shirt:*"],
    extra={"density": "rows", "densities_planned": {"few": 6, "rows": 17, "heavy": 60}},
)

RO, RI = 0.0085, 0.0048


def brooch_grid(c, n, rows=2, cols=16, dome=0.0008):
    x = nrm(np.cross(n, v3(0, 0, 1)))
    y = np.cross(n, x)
    P = np.zeros((rows, cols, 3))
    for i, r in enumerate(np.linspace(RO, RI, rows)):
        for j, a in enumerate(np.linspace(0.0, 2 * math.pi, cols, endpoint=False)):
            P[i, j] = c + (x * math.cos(a) + y * math.sin(a)) * r + n * dome * (i / max(rows - 1, 1))
    return P


def spots():
    out = []
    for s in (1, -1):
        for z in (1.290, 1.254, 1.218, 1.182):
            out.append((s * 0.046, z))
        for x in (0.074, 0.100):
            out.append((s * x, 1.236 - 0.014 * (x - 0.074) / 0.026))
    out += [(0.0, 1.128)]
    return out


def build(ctx):
    K = ctx.K
    b = C.Builder(SPEC)
    shirt = Offset(Union([torso_shapes(K, smooth=True), neck_shape(K)], k=0.05), 0.0068)
    centers = []
    for k, (x, z) in enumerate(spots()):
        p = surface_point(shirt, v3(x, -0.3, z), v3(0, 1, 0), 0.0, 0.3)
        n = sdf_normal(shirt, p)
        centers.append(p)
        P = brooch_grid(p + n * 0.0006, n)
        C.sheet_piece(b, "b%02d" % k, P, 0.0010, 0, closed_u=True, normals=np.broadcast_to(n, P.shape))
    bt = b.build()
    ob, V = bt.ob, bt.V
    uv = C.loop_uvs(ob, [], np.full(len(ob.data.polygons), -1, int), vertex_uv=bt.attrs["uv"],
                    vertex_uwrap=bt.attrs["uwrap"])
    W = np.zeros((len(V), len(ctx.bones)))
    Wc = C.body_W(ctx, np.array(centers))
    from lib.weights import limit_normalize
    Wc = limit_normalize(Wc)
    for k in range(len(centers)):
        W[bt.vmask("b%02d" % k)] = Wc[k]
    return C.finish(ctx, SPEC, bt, W, uv, hide_candidates=[], focus=((0.0, -0.05, 1.24), 0.34))
