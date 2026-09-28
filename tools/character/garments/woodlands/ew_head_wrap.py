"""Silk handkerchief head wrap (costume bible §3.2, §3.8 `ew_head_wrap`).

Shawnee men in 1773 wore their hair in a black silk handkerchief (Jones [R2]); men's heads
were otherwise often bare. A handkerchief wrapped round the head over the hair, knotted at
the back with two short ends. Grade A.

Rigid on the head (headb). Hides the hair's crown, sides, back and crown-lock zones (the
queue or club hangs out below it).
"""

import math

import numpy as np

from lib.sdf import Ellipsoid, Fn, Inter, Offset, RoundCone, Sphere, Union, nrm, peval, smoothstep, surface_point, v3

from garments.woodlands import _common as C

SPEC = C.spec(
    id="ew_head_wrap", name="Silk head wrap", slot="head", layer={"default": 80},
    description="A silk handkerchief wrapped round the head over the hair and knotted at the back.",
    history="Shawnee men in 1773 wore their hair in a black silk handkerchief (David Jones, quoted in [R2]).",
    zones=[C.WZone(0, "cloth", "LIN", ["logwood_black", "madder_red", "indigo_mid", "linen_white"], name="silk",
                   pattern={"options": ["none", "check"], "check": {"colors": ["check_blue", "linen_white"],
                                                                    "scale_m": 0.012}, "sheen": "silk"})],
    evidence="A", sources=["R2"], budget=2200, tags=["men"], hides_hair_zones=["crown", "sides", "back", "lock"],
    extra={"note": "The crown lock is hidden under the wrap (hair gathered into it); queues and clubs hang below."},
)

# lower edge of the wrap: a plane through the forehead (above the brows) and the nape
FRONT_Z, BACK_Z = 1.522, 1.438


def build(ctx):
    K = ctx.K
    hb = K["headb"]
    b = C.Builder(SPEC)
    cran = Ellipsoid(hb + v3(0, -0.027, 0.061), (0.074, 0.098, 0.092))
    base = Offset(cran, 0.0135)
    # wrap folds: three rolled bands at slightly different tilts, and the knot at the back
    folds = []
    for k, (dz, tilt) in enumerate(((0.012, 0.0), (0.040, 0.10), (0.068, -0.08))):
        pts = []
        for a in np.linspace(0.0, 2 * math.pi, 25):
            d = v3(math.sin(a), -math.cos(a), 0.0)
            z = FRONT_Z + dz + (BACK_Z - FRONT_Z) * (0.5 - 0.5 * math.cos(a)) * (1.0 - dz * 4) + tilt * 0.02 * math.sin(a)
            c = v3(0, hb[1] - 0.02, z)
            pts.append(surface_point(base, c + d * 0.2, -d, 0.0, 0.2))
        folds.append(Union([RoundCone(pts[i], pts[i + 1], 0.0032, 0.0032) for i in range(len(pts) - 1)], k=0.002))
    knot_c = surface_point(base, v3(0.012, 0.25, 1.462), v3(0, -1, 0), 0.0, 0.25)
    knot = Union([Sphere(knot_c + v3(0.0, 0.004, 0.0), 0.014), Sphere(knot_c + v3(0.012, 0.002, -0.006), 0.009),
                  Sphere(knot_c + v3(-0.010, 0.003, -0.004), 0.008)], k=0.006)
    solid = Union([base] + folds + [knot], k=0.004)
    n = nrm(v3(0, (BACK_Z - FRONT_Z), -((hb[1] + 0.07) - (hb[1] - 0.10))))
    if n[2] < 0:
        n = -n
    p0 = v3(0, hb[1] - 0.10, FRONT_Z)

    def keep(Cc):
        return (Cc - p0) @ n > 0.0
    b.cloth("wrap", solid, 0.0016, [(p0, n, lambda Cc: np.ones(len(Cc), bool))], keep, 900, 0.0016, 0,
            symmetric=False, max_edge=0.03)
    # two short ends hanging from the knot
    for k, (dx, L) in enumerate(((0.012, 0.070), (-0.006, 0.055))):
        rows = []
        for i, t in enumerate(np.linspace(0.0, 1.0, 6)):
            c = knot_c + v3(dx, 0.010 + 0.012 * t, -L * t)
            rows.append([c + v3(-0.011 * (1 - 0.3 * t), 0, 0), c, c + v3(0.011 * (1 - 0.3 * t), 0, 0)])
        C.sheet_piece(b, "end%d" % k, np.array(rows), 0.0014, 0, normals=np.broadcast_to(v3(0, 1, 0), (6, 3, 3)))
    bt = b.build()
    ob, V = bt.ob, bt.V
    part = np.zeros(len(ob.data.polygons), int)
    part[bt.pmask("end0", "end1")] = -1
    uv = C.loop_uvs(ob, [C.Cyl(hb + v3(0, -0.027, 0.3), hb + v3(0, -0.027, 0.0), v3(0, 1, 0))], part,
                    vertex_uv=bt.attrs["uv"])
    W = C.rigid_W(ctx, len(V), "headb")
    return C.finish(ctx, SPEC, bt, W, uv, hide_candidates=[], focus=((0.0, -0.01, 1.49), 0.30))
