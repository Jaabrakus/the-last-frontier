"""Linen neck stock, costume bible §4.5 `stock_linen`: a stiffened band of pleated linen
round the neck, buckled behind (the legacy shirt's stock, now its own accessory over the
shirt collar).

Bible: "A linen neck stock with a buckle behind, a linen roller, or a silk or linen
neckerchief" [R20][M3]. Grade A.
"""

import numpy as np

from lib.remesh import Prims, join
from lib.sdf import Inter, Offset, frame_from, sdf_normal, smoothstep, surface_point, v3, zslab

from garments.militia import _militia as M

SPEC = M.spec(
    id="stock_linen", name="Neck stock", slot="accessories.neck", layer={"default": 20},
    zones=[M.MZone(0, "cloth", "LIN", ["linen_white", "linen_unbleached", "logwood_black"], "linen_white",
                   name="stock"),
           M.MZone(1, "metal", "MET", ["brass", "pewter", "silver"], "pewter", name="buckle")],
    description="A band of pleated white linen round the neck, fastened behind with a small buckle.",
    history="The everyday neckwear of the period: a linen stock buckled behind, or a roller or kerchief.",
    sources=["R20", "M3"], budget=800, tags=["frontier", "regulars"])

Z0, Z1 = 1.272, 1.356


def build(ctx):
    K = ctx.K
    mats = M.zone_mats(SPEC)
    ct = M.body_f(ctx)
    # pleats: shallow horizontal ridges (a pleated stock), rounded top and bottom edges
    def roff(X, Y, Z):
        u = (Z - Z0) / (Z1 - Z0)
        return 0.0085 + 0.0004 * np.cos(u * 2 * np.pi * 4) * smoothstep(0.1, 0.25, u) * smoothstep(0.9, 0.75, u)
    col = M.neck_column(K, lambda Z: np.interp(Z, [1.26, 1.30, 1.36], [0.078, 0.073, 0.068]))
    node = Inter(Inter(Offset(ct, roff, r_max=0.0092), zslab(Z0, Z1), k=0.003), col, k=0.004)
    ob = M.sdf_part(ctx, SPEC.id, node, 0.0018, 700, mats[0], visible=0.0085, hidden=0.03)
    M.strip_to_envelope(ctx, ob, "mid")
    M.drop_small_islands(ob)
    M.fit_budget(ob, SPEC.budget["tris_max"] - 80)
    # the buckle behind (hidden by most hair styles; seen with cropped hair)
    bp = Prims()
    nk = K["neck"]
    p = surface_point(node, v3(0, 0.3, 1.31), v3(0, -1, 0), 0.0, 0.3)
    n = sdf_normal(node, p)
    bp.frame(p + n * 0.0018, frame_from(n, v3(1, 0, 0)), 0.022, 0.018, 0.0035, 0.0022, mi=1)
    M.with_mats(ob, mats)
    ob = join([ob, bp.to_object("buckle", mats)], SPEC.id)
    M.with_mats(ob, mats)
    zones = M.zones_of(ob)
    W = M.body_weights(ctx, ob, smooth=3, alpha=0.5)
    metal = M.vert_mask_of_zone(ob, zones, {1})
    W = M.one_weight_per_piece(ob, W, metal, ~metal)
    uv = M.loop_uvs(ob, [M.Cyl(v3(0, nk[1], 0), v3(0, nk[1], 1), v3(0, -1, 0))], np.zeros(len(ob.data.polygons), int))
    return M.finish(ctx, SPEC, ob, zones, W, uv, hide_candidates=["neck_lower"])
