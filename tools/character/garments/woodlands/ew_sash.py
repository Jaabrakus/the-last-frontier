"""Finger-woven sash (costume bible §3.8 `ew_sash`; garters and belts [R16][P1]).

A finger-woven wool sash with white beads woven in, worn as a belt round the waist and
knotted at the left hip, the fringed ends hanging (grade A/B: finger-woven belts, sashes and
garters with beads are documented [R16][P1]; the chevron pattern is a game choice pending
review, §3.7).

The band sits over a shirt at the waist (8-12 mm over the skin; it floats a little on bare
skin); the ends hang in front of the left thigh, clear of the shirt tails. Weights: the band
band-averaged on the torso (legacy belt), the knot with it, the ends from the pelvis to the
left front skirt panel, the fringe rigid with the end.
"""

import math

import numpy as np

from lib.remesh import Prims
from lib.sdf import Sphere, Union, smoothstep, v3

from garments.woodlands import _common as C

SASH_Z = (0.972, 1.014)
KNOT_TH = C.FRONT + math.radians(42.0)          # left front hip

SPEC = C.spec(
    id="ew_sash", name="Finger-woven sash", slot="accessories.waist", layer={"default": 60},
    description="A finger-woven wool sash with white beads worked into the pattern, tied round the waist and knotted "
                "at the hip with the fringed ends hanging.",
    history="Finger-woven belts, sashes and garters of wool, with white beads woven in, were made across the "
            "Northeast [R16]; Smith's garters were dressed with beads [P1]. The chevron pattern here is generic.",
    zones=[C.WZone(0, "band", "KNIT", ["madder_red", "stroud_blue", "logwood_black", "ribbon_yellow"], "madder_red",
                   name="sash", pattern={"type": "chevron", "colors": ["stroud_blue", "ribbon_yellow"],
                                         "beads": "bead_white", "scale_m": 0.04}),
           C.WZone(1, "fringe", "KNIT", ["madder_red", "stroud_blue", "logwood_black"], "madder_red", name="fringe")],
    evidence="B", sources=["R16", "P1"], budget=1800, tags=["men", "women"], excludes=["ew_matchcoat"],
    extra={"variants_note": "Built for the waist over a shirt, shift or bare skin (env10); worn over the "
                            "blanket the blanket's own belt is used."},
)


def build(ctx):
    b = C.Builder(SPEC)
    hull = C.Hull(ctx)
    form = hull.form(lambda z: 0.0096, hang_top=None, z_range=(0.9, 1.06))
    th = math.pi / 2 + np.linspace(0.0, 2 * math.pi, 44, endpoint=False)
    zs = np.linspace(SASH_Z[1], SASH_Z[0], 4)
    P = np.array([form.point(th, np.full(len(th), z), extra=0.0015) for z in zs])
    C.sheet_piece(b, "band", P, 0.0030, 0, closed_u=True)
    kc = form.point(KNOT_TH, 0.993, extra=0.011)
    knot = Union([Sphere(kc, 0.013), Sphere(kc + v3(0.006, -0.004, -0.010), 0.009)], k=0.006)
    b.sdf("knot", knot, 0.0012, 240, 0, symmetric=False, max_tris=200)
    # the ends: strips hanging from the knot, clear of the shirt tails
    tails = C.Hull(ctx).form(lambda z: float(np.interp(z, [0.60, 0.86, 0.95, 0.985], [0.046, 0.044, 0.024, 0.013])),
                             hang_top=1.0, z_range=(0.55, 1.05))
    ends = []
    for k, (dth, z_end) in enumerate(((math.radians(-4.0), 0.640), (math.radians(5.0), 0.672))):
        zs = np.linspace(0.985, z_end, 10)
        rows = []
        for z in zs:
            r = float(tails.radius(KNOT_TH + dth, z))
            half = 0.024 / r
            t3 = KNOT_TH + dth + np.linspace(-half, half, 3)
            rows.append(tails.point(t3, np.full(3, z), extra=0.0015 + 0.004 * k))
        P = np.array(rows)
        C.sheet_piece(b, "end%d" % k, P, 0.0030, 0)
        ends.append(P)
    # fringe: short strands at the ends
    for k, P in enumerate(ends):
        pr = Prims()
        bot = P[-1]
        for u in np.linspace(0.0, 1.0, 7):
            c = bot[0] * (1 - u) + bot[-1] * u
            pr.box(c + v3(0, 0, -0.030), (0.0022, 0.0012, 0.030))
        b.prims("fringe%d" % k, pr, 1)
    bt = b.build()
    ob, V = bt.ob, bt.V
    part = np.full(len(ob.data.polygons), -1, int)
    part[bt.pmask("knot", "fringe0", "fringe1")] = 0
    uv = C.loop_uvs(ob, [C.Flat(kc, (1, 0, 0), (0, 0, 1))], part, vertex_uv=bt.attrs["uv"],
                    vertex_uwrap=bt.attrs["uwrap"])
    e = np.nan_to_num(bt.attrs["edge"], nan=1.0)
    bi = {n: i for i, n in enumerate(ctx.bones)}
    W = np.zeros((len(V), len(ctx.bones)))
    band = bt.vmask("band", "knot")
    W[band] = C.belt_W(ctx, V[band], 0.5 * sum(SASH_Z))
    for k in (0, 1):
        m = bt.vmask("end%d" % k)
        Wp = C.panel_W(ctx, V[m], lr_width=0.10, pelvis_z=(0.56, 0.95))
        Wb = C.belt_W(ctx, V[m], 0.5 * sum(SASH_Z))
        t = smoothstep(0.93, 0.985, V[m, 2])[:, None]
        W[m] = Wp * (1 - t) + Wb * t
        # fringe: the end's lowest row
        f = bt.vmask("fringe%d" % k)
        ij = bt.attrs["ij"]
        low = m & (np.nan_to_num(ij[:, 0], nan=-1) == 9)
        W[f] = W[low].mean(0)
    W = C.normalize(W)
    return C.finish(ctx, SPEC, bt, W, uv, hide_candidates=[], edge=(e[:, 0], e[:, 1]),
                    focus=((0.05, -0.05, 0.86), 0.55))
