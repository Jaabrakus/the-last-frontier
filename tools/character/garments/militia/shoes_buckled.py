"""Buckled shoes (costume bible §4.5 `shoes_buckled`, §2.6): the legacy shoes of
actor_b_body.glb (the foot offset 7.2 mm with a tongue, cut at the throat) with a latchet
strap and a buckle over the instep.

Bible: "Black waxed calf with buckles (brass, steel or silver); pucker-toe moccasins were
acceptable in the field" [M3]; black buckled shoes were acceptable for rangers [M2]. Grade A.
"""

import numpy as np

from lib.body_shapes import foot_shapes
from lib.remesh import Prims, join
from lib.sdf import Inter, Offset, RoundBox, Union, frame_from, sdf_normal, surface_point, v3, zslab

from garments.militia import _militia as M

SPEC = M.spec(
    id="shoes_buckled", name="Buckled shoes", slot="feet", layer={"default": 40},
    zones=[M.MZone(0, "leather", "LEA", ["leather_black", "leather_brown"], "leather_black", name="leather"),
           M.MZone(1, "metal", "MET", ["brass", "pewter", "silver"], "brass", name="buckles")],
    description="Waxed-calf shoes closed over the instep with a strap and a buckle.",
    history="Black waxed calf with brass, steel or silver buckles: what the Massachusetts provincials of 1758 and "
            "Rogers' rangers wore when not in moccasins.",
    sources=["M3", "M2"], budget=1400, tags=["frontier", "regulars"])

SHOE_OFF = 0.0072
TOP_Z = 0.092


def shoes_node(K):
    feet = [Offset(foot_shapes(K, s), SHOE_OFF) for s in (1, -1)]
    tongue = []
    for s in (1, -1):
        A = K.side("ankle", s)
        c = v3(A[0], A[1] - 0.052, 0.085)
        tongue.append(RoundBox(c, (0.026, 0.006, 0.024), 0.005, frame_from(v3(0, -0.45, 1), v3(1, 0, 0))))
    # latchets: two straps over the instep, meeting under the buckle
    straps = []
    for s in (1, -1):
        A = K.side("ankle", s)
        c = v3(A[0], A[1] - 0.070, 0.070)
        straps.append(RoundBox(c, (0.036, 0.011, 0.0035), 0.003, frame_from(v3(0, -0.55, 1), v3(1, 0, 0))))
    shoes = Union([Union([f, t, st], k=0.010) for f, t, st in zip(feet, tongue, straps)], k=0)
    return Inter(shoes, zslab(0.0, TOP_Z + 0.02))


def throat_cut(K):
    """The top line: TOP_Z round the ankle, the tongue rising in front."""
    from lib.sdf import Fn

    def f(X, Y, Z):
        out = np.full(np.broadcast(X, Y, Z).shape, -1.0)
        for s in (1, -1):
            A = K.side("ankle", s)
            front = np.clip((A[1] - 0.03 - Y) / 0.03, 0.0, 1.0)
            top = TOP_Z + 0.018 * front
            near = (np.abs(X - A[0]) < 0.08)
            out = np.where(near, Z - top, out)
        return out
    return Fn(f, (-0.3, -0.3, -0.1), (0.3, 0.3, 0.3))


def build(ctx):
    K = ctx.K
    mats = M.zone_mats(SPEC)
    node = Inter(shoes_node(K), throat_cut(K))
    shoes = M.sdf_part(ctx, "shoes", node, 0.0025, 1100, mats[0],
                       visible=lambda P: np.where(P[:, 2] > 0.06, 0.0135, 0.0165), hidden=0.03,
                       hidden_below=0.003)
    M.strip_to_envelope(ctx, shoes, "outer")
    M.drop_small_islands(shoes)
    # buckles on the instep
    bp = Prims()
    for s in (1, -1):
        A = K.side("ankle", s)
        p = surface_point(node, v3(A[0], A[1] - 0.075, 0.2), v3(0, 0, -1), 0.0, 0.2)
        n = sdf_normal(node, p)
        bp.frame(p + n * 0.0025, frame_from(n, v3(1, 0, 0)), 0.034, 0.026, 0.005, 0.003, mi=1)
    buckles = bp.to_object("buckles", mats)
    ob = join([shoes, buckles], SPEC.id)
    M.with_mats(ob, mats)
    zones = M.zones_of(ob)
    # weights: the foot under the shoe; each buckle rigid on the leather under it
    W = M.body_weights(ctx, ob, smooth=1)
    metal = M.vert_mask_of_zone(ob, zones, {1})
    W = M.one_weight_per_piece(ob, W, metal, ~metal)
    # UVs: one cylinder per foot along heel -> toe (the seam under the sole)
    maps, C = [], M.poly_centers(ob)
    for s in (1, -1):
        A, Hl, B = K.side("ankle", s), K.side("heel", s), K.side("ball", s)
        maps.append(M.Cyl(v3(A[0], Hl[1] - 0.03, 0.035), v3(A[0], B[1] - 0.05, 0.025), v3(0, 0, 1)))
    part = np.where(C[:, 0] > 0, 0, 1)
    uv = M.loop_uvs(ob, maps, part)
    # shading: a darker sole edge
    V = M.mesh_arrays(ob)
    col = 1.0 - 0.35 * (1 - M.smoothstep(0.004, 0.012, V[:, 2]))
    return M.finish(ctx, SPEC, ob, zones, W, uv, hide_candidates=["foot_l", "foot_r"], colors=M.rgba(col))
