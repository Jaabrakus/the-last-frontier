"""Neckwear (costume bible §5.1-5.3): the British linen or black stock (a stiffened band
buckled behind the neck) and the French white cravat (a neckcloth knotted at the throat,
its short ends tucked into the veste).

A band round the neck between the stock's bottom and top (build_body's stock: 1.27 to
1.352), 7.5 mm over the skin on the body as it blends into the shoulders, cut to within
8.5 cm of the neck axis. Layer 15: over the shirt's collar (base 10), under a coat
(40). Zones: 0 cloth, 3 buckle.
"""

import numpy as np

from lib.remesh import material
from lib.sdf import Fn, Inter, Offset, smoothstep, v3, zslab

from . import _base as B
from ._trims import Trims, hit

STOCK_Z = (1.258, 1.356)
NECK_OUT = 0.0075


def neck_axis(K):
    nk, ha = K["neck"], K["heada"]
    return v3(0, nk[1] + 0.010, nk[2] - 0.07), v3(0, ha[1] + 0.008, ha[2] + 0.12)


def neckwear(ctx, spec, cravat=False):
    K = ctx.K
    a, b = neck_axis(K)
    outer = Offset(ctx.body_sdf(), NECK_OUT)

    def cut(X, Y, Z):
        shape = np.broadcast(X, Y, Z).shape
        P = np.stack(np.broadcast_arrays(X, Y, Z), -1).reshape(-1, 3)
        t = np.clip(((P - a) @ (b - a)) / ((b - a) @ (b - a)), 0.0, 1.0)
        d = np.linalg.norm(P - (a + t[:, None] * (b - a)), axis=1).reshape(shape)
        top = STOCK_Z[1] - 0.016 * smoothstep(0.0, -0.05, np.broadcast_to(Y, shape) - a[1])   # lower under the chin
        return np.maximum.reduce([STOCK_Z[0] - Z, Z - top, d - 0.097])
    region = Fn(cut)
    ob = B.sheet(spec.id, outer, region, 0.0018, 700, material(spec.id, "#e8e3d3"),
                 sizing=lambda P: np.full(len(P), 0.013), feature_deg=40.0, domain=zslab(1.22, 1.40))
    B.solidify(ob, 0.002, rim_only=True)
    sol = Inter(outer, region)
    pieces = [B.Piece(ob, "cloth", zone=B.CLOTH, uv="body")]
    tm, tc = Trims(), Trims()
    zc = 0.5 * (STOCK_Z[0] + STOCK_Z[1])
    if not cravat:
        p, n = hit(sol, v3(0, 0.25, zc), v3(0, -1, 0), 0.25)
        tm.buckle(p, n, v3(0, 0, 1), w=0.030, h=0.022, bar=0.0032, t=0.0026)
    else:
        # the knot at the throat and two short ends lying on the upper chest
        p, n = hit(sol, v3(0, -0.25, STOCK_Z[0] + 0.022), v3(0, 1, 0), 0.30)
        body_out = Offset(ctx.body_sdf(), NECK_OUT + 0.001)
        for s in (1, -1):
            top = p + v3(s * 0.008, -0.004, -0.004)
            pts = np.array([top + v3(s * 0.006 * k / 5.0, -0.004 * k / 5.0, -0.075 * k / 5.0) for k in range(6)])
            tc.strip(body_out, pts, 0.036, lift=0.0015 + 0.001 * (s > 0),
                     taper=[1.0, 1.02, 1.05, 1.08, 1.1, 1.1])
        tc.button(p + n * 0.001, n, r=0.012, h=0.008, segs=8, sink=0.002)
    if not tm.empty():
        pieces.append(B.Piece(tm.to_object(spec.id + "_buckle"), "trim", zone=B.METAL, uv="attr"))
    if not tc.empty():
        pieces.append(B.Piece(tc.to_object(spec.id + "_ends", "#e8e3d3"), "trim", zone=B.CLOTH, uv="attr"))
    return B.assemble(ctx, spec, pieces, smooth=(2, 0.4))
