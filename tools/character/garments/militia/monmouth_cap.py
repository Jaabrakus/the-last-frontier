"""Monmouth cap, costume bible §4.5 `monmouth_cap`: a knitted and felted round cap with a
turned-up band and a small button on the crown.

Bible: "Monmouth caps: felted knit round caps made in Monmouth and widely exported" [R22];
knit caps generally for militia and rangers [M2][M3]. Grade A. Hides the hair's crown zone;
the band sits over the sides and back of the hair.
"""

import numpy as np

from lib.sdf import Ellipsoid, Fn, Inter, Offset, Sphere, Union, nrm, peval, smoothstep, v3

from garments.militia import _militia as M

SPEC = M.spec(
    id="monmouth_cap", name="Monmouth cap", slot="head", layer={"default": 80},
    zones=[M.MZone(0, "cloth", "KNIT", ["walnut_brown", "slate_grey", "logwood_black", "madder_red", "drab",
                                         "indigo_mid"], "walnut_brown", name="knit"),
           M.MZone(1, "band", "KNIT", ["walnut_brown", "slate_grey", "logwood_black", "madder_red", "drab",
                                        "indigo_mid"], "walnut_brown", name="band"),
           M.MZone(2, "button", "KNIT", ["walnut_brown", "logwood_black", "madder_red"], "walnut_brown",
                   name="button")],
    description="Close-fitting knitted and felted wool cap with a turned-up band and a small button on top.",
    history="Knitted in Monmouth and exported across the Atlantic: the working man's and soldier's cap; knit caps "
            "of every kind were worn by militia and rangers.",
    sources=["R22", "M2", "M3"], budget=1500, hides_hair_zones=["crown"], tags=["frontier"])

CAP_OFF = 0.0135            # over the hair cap (7.5 mm) with room for the knit
BAND_H = 0.030


def band_plane(hb):
    """Lower edge of the cap: across the forehead above the brows, down behind the ears."""
    p0 = hb + v3(0, -0.10, 0.062)
    n = nrm(v3(0, 0.30, 1.0))          # tilts down toward the back
    return p0, n


def build(ctx):
    K = ctx.K
    hb = K["headb"]
    mats = M.zone_mats(SPEC)
    cran = Ellipsoid(hb + v3(0, -0.027, 0.061), (0.074, 0.098, 0.092))
    p0, n = band_plane(hb)
    side = lambda X, Y, Z: -((X - p0[0]) * n[0] + (Y - p0[1]) * n[1] + (Z - p0[2]) * n[2])
    above = Fn(side, (-0.2, -0.3, 1.3), (0.2, 0.3, 1.8))
    # a soft, slightly peaked crown (the knit gathers at the top)
    crown = Union([Offset(cran, CAP_OFF), Sphere(hb + v3(0, -0.020, 0.150), 0.036)], k=0.05)
    band = Inter(Offset(cran, CAP_OFF + 0.004), Fn(lambda X, Y, Z: np.maximum(side(X, Y, Z), -side(X, Y, Z) - BAND_H),
                                                    (-0.2, -0.3, 1.3), (0.2, 0.3, 1.8)), k=0.003)
    cap = Inter(Union([crown, band], k=0.004), above, k=0.002)
    top = hb + v3(0, -0.018, 0.186)
    ob = M.sdf_part(ctx, SPEC.id, cap, 0.002, 1300, mats[0], visible=0.0125, hidden=0.03, hidden_below=0.004)
    M.strip_to_envelope(ctx, ob, "head")
    M.drop_small_islands(ob)
    # zones: the band (below BAND_H above the edge, on the band's outer surface) and the button
    C = M.poly_centers(ob)
    d_edge = -side(C[:, 0], C[:, 1], C[:, 2])
    zones = np.where(d_edge < BAND_H + 0.001, 1, 0)
    from lib.remesh import Prims, join
    from lib.sdf import sdf_normal, surface_point
    bp = Prims()
    p = surface_point(cap, top + v3(0, 0, 0.1), v3(0, 0, -1), 0.0, 0.2)
    bp.sphere(p + v3(0, 0, 0.002), (0.008, 0.008, 0.006), mi=2, segs=10, rings=6)
    M.set_zone(ob, zones)
    btn = bp.to_object("button", mats)
    for m in mats:
        if m.name not in [x.name for x in ob.data.materials]:
            pass
    M.with_mats(ob, mats)
    ob = join([ob, btn], SPEC.id)
    M.with_mats(ob, mats)
    zones = M.zones_of(ob)
    nv = len(ob.data.vertices)
    W = M.rigid_bone(ctx, np.zeros((nv, len(ctx.bones))), np.ones(nv, bool), "headb")
    c = hb + v3(0, -0.027, 0.061)
    maps = [M.Cyl(c, c + v3(0, 0, 1), v3(0, -1, 0)), M.Flat(c, v3(1, 0, 0), v3(0, -1, 0))]
    N = M.poly_normals(ob)
    uv = M.loop_uvs(ob, maps, np.where(N[:, 2] > 0.8, 1, 0))
    # shading: a darker fold line under the band's top edge
    V = M.mesh_arrays(ob)
    dv = -side(V[:, 0], V[:, 1], V[:, 2])
    col = 1.0 - 0.25 * np.exp(-((dv - BAND_H) / 0.003) ** 2)
    return M.finish(ctx, SPEC, ob, zones, W, uv, hide_candidates=[], colors=M.rgba(col))
