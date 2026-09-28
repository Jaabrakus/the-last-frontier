"""Neckerchief, costume bible §4.5 `neckerchief`: a silk or linen handkerchief folded
into a band, wound round the neck and knotted in front, the short ends hanging on the
chest (over the waistcoat, under a coat).

Bible: "a silk or linen neckerchief" [R20][M3]; colours linen_white, logwood_black (silk),
check_blue. New England advertisements describe black silk and checked handkerchiefs
[M15]. Grade A.
"""

import numpy as np

from lib.sdf import (Ellipsoid, Inter, Offset, RoundCone, Union, frame_from, nrm, sdf_normal, smoothstep,
                     surface_point, v3, zslab)

from garments.militia import _militia as M

SPEC = M.spec(
    id="neckerchief", name="Neckerchief", slot="accessories.neck", layer={"default": 30},
    zones=[M.MZone(0, "cloth", "LIN", ["logwood_black", "linen_white", "check_blue", "madder_red", "indigo_mid"],
                   "logwood_black", name="kerchief", fabrics=["LIN", "FLAT"],
                   pattern={"options": ["none", "check", "stripe"], "default": "none",
                            "check": {"colors": ["check_blue", "linen_white"], "scale_m": 0.010}})],
    description="A silk or linen handkerchief folded into a band, tied round the neck with the knot in front.",
    history="Black silk and checked linen handkerchiefs were everyday neckwear; worn instead of a stock.",
    sources=["R20", "M3", "M15"], budget=900, tags=["frontier", "women"])

Z0, Z1 = 1.285, 1.338


def build(ctx):
    K = ctx.K
    mats = M.zone_mats(SPEC)
    ct = M.body_f(ctx)

    def roff(X, Y, Z):              # a rolled band: thickest in the middle of its height
        u = np.clip((Z - Z0) / (Z1 - Z0), 0, 1)
        return 0.0098 + 0.0035 * np.sin(np.pi * u)
    col = M.neck_column(K, lambda Z: np.interp(Z, [1.26, 1.30, 1.36], [0.084, 0.079, 0.074]))
    band = Inter(Inter(Offset(ct, roff, r_max=0.0135), zslab(Z0 - 0.004, Z1 + 0.004), k=0.004), col, k=0.005)
    # the knot at the throat and two short ends lying on the chest
    fr = surface_point(ct, v3(0, -0.3, 1.285), v3(0, 1, 0), 0.0, 0.3)
    n = nrm(sdf_normal(ct, fr) + v3(0, -0.3, 0))
    knot = Ellipsoid(fr + n * 0.018, (0.016, 0.011, 0.013), frame_from(n, v3(1, 0, 0)))
    ends = []
    for s, dz, sp in ((1, 0.070, 0.022), (-1, 0.058, 0.030)):
        pts, rad = [], []
        for k, u in enumerate(np.linspace(0, 1, 5)):
            z = fr[2] - 0.010 - dz * u
            x = s * (0.004 + sp * u)
            p = surface_point(ct, v3(x, -0.3, z), v3(0, 1, 0), 0.0, 0.3)
            nn = sdf_normal(ct, p)
            pts.append(p + nn * (0.0125 + 0.004 * (1 - u)))
            rad.append(0.0105 - 0.004 * u)
        ends.append(Union([RoundCone(pts[i], pts[i + 1], rad[i] * 0.45, rad[i + 1] * 0.45) for i in range(4)], k=0.004))
    # flatten the ends: intersect with a slab around the chest offset
    flat = Inter(Union(ends, k=0.0), Offset(ct, 0.0165), k=0.002)
    node = Union([band, knot, flat], k=0.006)
    ob = M.sdf_part(ctx, SPEC.id, node, 0.0016, 800, mats[0], visible=lambda P: np.where(P[:, 2] > 1.26, 0.0105, 0.0085),
                    hidden=0.03, symmetric=False)
    M.strip_to_envelope(ctx, ob, "legwear")
    M.drop_small_islands(ob)
    M.fit_budget(ob, SPEC.budget["tris_max"] - 10)
    M.with_mats(ob, mats)
    zones = np.zeros(len(ob.data.polygons), int)
    W = M.body_weights(ctx, ob, smooth=3, alpha=0.5)
    V = M.mesh_arrays(ob)
    kn = np.linalg.norm(V - (fr + n * 0.018), axis=1) < 0.022
    W = M.rigid_pieces(ob, W, kn)
    nk = K["neck"]
    uv = M.loop_uvs(ob, [M.Cyl(v3(0, nk[1], 0), v3(0, nk[1], 1), v3(0, -1, 0))], np.zeros(len(ob.data.polygons), int))
    col = 1.0 - 0.20 * np.exp(-((V[:, 2] - Z0) / 0.004) ** 2) - 0.20 * np.exp(-((V[:, 2] - Z1) / 0.004) ** 2)
    return M.finish(ctx, SPEC, ob, zones, W, uv, hide_candidates=[], colors=M.rgba(col))
