"""Waistcoats of the militia set: the legacy single-breasted waistcoat of
actor_b_body.glb (10 mm over the smoothed torso, a V at the neck from 1.16 m, the hem
sloping from the back down to the front, armholes cut at |x| = 0.138) and a
double-breasted variant (overlapping fronts, two rows of buttons, a straight hem), both
with pocket flaps and a linen back (a zone of its own).
"""

import math

import numpy as np

from lib.remesh import Prims, join
from lib.body_shapes import torso_shapes
from lib import sdf as S

from garments.militia import _militia as M

WC_OFF = 0.010
ARM_X = 0.138
SIDE_SEAM_DEG = 105.0          # front panels | back panel (degrees from the front centre)


def base(K):
    return S.Offset(torso_shapes(K, smooth=True), WC_OFF)


def armholes(K):
    """Cut round each arm: the xband of the legacy plus a round hole about the shoulder
    joint, so the shirt sleeve's root never shows through the waistcoat."""
    holes = []
    for s in (1, -1):
        Sh = K.side("shoulder", s)
        holes.append(S.Ellipsoid(Sh + S.v3(s * 0.012, 0.004, -0.040), (0.050, 0.060, 0.090)))
    return S.Union(holes, k=0.0)


def vest_node(K, hem_fn, neck_fn, z_top=1.36, base_node=None):
    """(node, [cut nodes]) of a waistcoat: rounded cuts (hem, armholes, neck) so the edges
    mesh cleanly."""
    hem = S.Fn(hem_fn, (-0.3, -0.3, 0.8), (0.3, 0.3, 1.45))
    neck = S.Fn(neck_fn, (-0.2, -0.3, 1.0), (0.2, -0.005, 1.5))
    arms = armholes(K)
    xb = S.xband(ARM_X)
    nh = M.neck_hole(K, 0.012)
    wc = S.Inter(S.Inter(base_node or base(K), hem, k=0.003), S.zslab(0.84, z_top), k=0.003)
    wc = S.Inter(wc, xb, k=0.003)
    wc = S.Sub(wc, arms, k=0.006)
    wc = S.Sub(wc, neck, k=0.003)
    return S.Sub(wc, nh, k=0.003), [hem, neck, arms, xb, nh]


def vest_sizing(cuts, coarse=0.024, fine=0.0095):
    def f(P):
        return M.rim_sizing([S.peval(c, P) for c in cuts], fine, coarse)
    return f


def pocket_flaps(K, node, z, x=0.092, half=(0.040, 0.013, 0.0028)):
    out = []
    for s in (1, -1):
        p = S.surface_point(node, S.v3(s * x, -0.3, z), S.v3(0, 1, 0), 0.0, 0.3)
        n = S.sdf_normal(node, p)
        out.append(S.RoundBox(p + n * 0.0012, half, 0.0025, S.frame_from(n, S.v3(1, 0, 0))))
    return out


def zones_of_vest(ob, K, back_zone=1):
    C = M.poly_centers(ob)
    yc = K["spineb"][1]
    ang = np.degrees(np.arctan2(np.abs(C[:, 0]), -(C[:, 1] - yc)))
    # the fronts run over the shoulders to the shoulder seam; the linen back below it
    return np.where((ang > SIDE_SEAM_DEG) & (C[:, 2] < 1.285), back_zone, 0)


def finish_vest(ctx, spec_, ob, mats, zones, buttons_ob=None, extra_col=None):
    K = ctx.K
    if buttons_ob is not None:
        M.set_zone(ob, zones)
        M.with_mats(ob, mats)
        ob = join([ob, buttons_ob], spec_.id)
        M.with_mats(ob, mats)
        zones = M.zones_of(ob)
    W = M.body_weights(ctx, ob, smooth=1)
    metal = M.vert_mask_of_zone(ob, zones, {2})
    W = M.one_weight_per_piece(ob, W, metal, ~metal)
    uv = M.garment_uvs(ctx, ob, "torso")
    V = M.mesh_arrays(ob)
    yc = K["spineb"][1]
    ang = np.degrees(np.arctan2(np.abs(V[:, 0]), -(V[:, 1] - yc)))
    col = 1.0 - 0.16 * np.exp(-((ang - SIDE_SEAM_DEG) / 1.5) ** 2)        # side seams
    back = V[:, 1] > 0.02
    col[back] *= 1 - 0.14 * np.exp(-(V[back, 0] / 0.003) ** 2)              # centre-back seam
    if extra_col is not None:
        col *= extra_col(V)
    hides = ["abdomen_front", "abdomen_side", "abdomen_back", "chest_front", "chest_side", "chest_back",
             "chest_upper_side", "chest_upper_back", "chest_upper_front"]
    return M.finish(ctx, spec_, ob, zones, W, uv, hide_candidates=hides, colors=M.rgba(col))
