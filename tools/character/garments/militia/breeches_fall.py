"""Knee breeches with a fall front, costume bible §4.5 `breeches_*`, §2.6
`breeches_buckskin` / `breeches_wool`: the legacy buckskin breeches of actor_b_body.glb (a
smooth fall-front panel bridging the groin, a fuller seat, 10 mm over the legs) with a
waistband, knee bands buckled below the knee (now reaching 7 cm under the knee joint, so
they cover the knee in every pose) and buttons at the knee and on the fall. Leather, wool
or linen is a fabric option of the one garment.

Bible: "Knee breeches buckled below the knee, in red, blue, black, brown, drab or green
kersey or serge, or leather" [R20][M3]; buckskin breeches with a fall front are grade A for
rangers and backcountry men [M2].
"""

import numpy as np

from lib import sdf as S
from lib.remesh import Prims, join

from garments.militia import _militia as M

SPEC = M.spec(
    id="breeches_fall", name="Knee breeches, fall front", slot="legs.lower",
    layer={"default": 20, "torso_lower": 15},
    zones=[M.MZone(0, "cloth", "SUEDE", ["buckskin_smoked", "buckskin_pale", "madder_red", "indigo_mid",
                                          "logwood_black", "walnut_brown", "drab", "ranger_green", "linen_unbleached"],
                   "buckskin_smoked", name="breeches", fabrics=["SUEDE", "WOOL", "LIN", "TWILL"]),
           M.MZone(1, "band", "SUEDE", ["buckskin_smoked", "buckskin_pale", "madder_red", "indigo_mid",
                                         "logwood_black", "walnut_brown", "drab", "ranger_green", "linen_unbleached"],
                   "buckskin_smoked", name="waist and knee bands", fabrics=["SUEDE", "WOOL", "LIN", "TWILL"]),
           M.MZone(2, "metal", "MET", ["brass", "pewter", "silver", "logwood_black"], "brass",
                   name="buckles and buttons")],
    description="Knee breeches with a buttoned fall front and knee bands buckled below the knee; buckskin, wool "
                "or linen.",
    history="Worn by every rank, in red, blue, black, brown, drab or green kersey or serge, or leather; buckskin "
            "breeches with a fall front were typical of rangers and backcountry men.",
    sources=["R20", "M3", "M2"], budget=1800, tags=["frontier", "regulars"],
    extra={"layer_note": "torso_lower 15: the waistband lies under a waistcoat (20) and over the shirt (10)."})

Z0, Z1 = 0.397, 1.000
CROTCH_PELVIS = 0.55           # share of the pelvis on the crotch panel's midline
CROTCH_SMOOTH = 2          # knee band bottom, waist top
KNEE_BAND = (0.397, 0.425)
WAIST_BAND = (0.968, 1.000)


def breeches_base(K, body):
    hc = (K["l_upper_leg"] + S.mirror_x(K["l_upper_leg"])) * 0.5
    fall = S.Ellipsoid(hc + S.v3(0, -0.028, -0.065), (0.080, 0.045, 0.080))
    seat = S.Ellipsoid(hc + S.v3(0, 0.050, -0.040), (0.130, 0.070, 0.090))
    return S.Union([body, S.Union([fall, seat], k=0.02)], k=0.025)


def build(ctx):
    K = ctx.K
    mats = M.zone_mats(SPEC)
    base = breeches_base(K, M.body_f(ctx))

    def roff(X, Y, Z):
        band = S.smoothstep(KNEE_BAND[1] + 0.002, KNEE_BAND[1] - 0.001, Z) + S.smoothstep(
            WAIST_BAND[0] - 0.002, WAIST_BAND[0] + 0.001, Z)
        return 0.010 + 0.0022 * np.clip(band, 0, 1)
    node = S.Inter(S.Inter(S.Offset(base, roff, r_max=0.0125), S.zslab(Z0, Z1), k=0.003), S.xband(0.26))
    ob = M.sdf_part(ctx, SPEC.id, node, 0.003, 1100, mats[0],
                    visible=lambda P: np.minimum(np.where((P[:, 2] < 0.52) | (P[:, 2] > 0.93), 0.022, 0.031),
                        M.rim_sizing([P[:, 2] - Z0, P[:, 2] - Z1], 0.010, 0.031)), hidden=0.04,
                    feature_deg=35.0, hidden_below=0.0008)
    M.strip_to_envelope(ctx, ob, "mid")
    M.drop_small_islands(ob)
    M.fit_budget(ob, SPEC.budget["tris_max"] - 560)
    C = M.poly_centers(ob)
    zones = np.where((C[:, 2] < KNEE_BAND[1] + 0.0005) | (C[:, 2] > WAIST_BAND[0] - 0.0005), 1, 0)
    M.set_zone(ob, zones)
    M.with_mats(ob, mats)
    # knee buckles on the outside of the bands, three buttons above each, fall and waist buttons
    bp = Prims()
    for s in (1, -1):
        Kn = K.side("knee", s)
        zc = 0.5 * (KNEE_BAND[0] + KNEE_BAND[1])
        p = S.surface_point(node, S.v3(s * 0.35, Kn[1] - 0.004, zc), S.v3(-s, 0, 0), 0.0, 0.35 - abs(Kn[0]))
        n = S.sdf_normal(node, p)
        bp.frame(p + n * 0.0018, S.frame_from(n, S.v3(0, 0, 1)), 0.020, 0.016, 0.0035, 0.0024, mi=2)
        M.buttons_on(bp, node, [(S.v3(s * 0.35, Kn[1] - 0.006, z), S.v3(-s, 0, 0)) for z in (0.440, 0.465, 0.49)],
                     radius=0.0042, thick=0.0022, mi=2)
    M.buttons_on(bp, node, [(S.v3(x, -0.3, z), S.v3(0, 1, 0)) for x, z in
                            ((-0.075, 0.984), (0.075, 0.984), (-0.070, 0.945), (0.070, 0.945), (0.0, 0.984))],
                 radius=0.005, thick=0.0025, mi=2)
    ob = join([ob, bp.to_object("fittings", mats)], SPEC.id)
    M.with_mats(ob, mats)
    zones = M.zones_of(ob)
    W = M.body_weights(ctx, ob, smooth=2, alpha=0.4)
    # the crotch panel (the fall and seat bridging the thighs) takes part of the pelvis
    # instead of being torn between the two thighs' weights (the nearest body point flips
    # from one thigh to the other at the midline)
    V0 = M.mesh_arrays(ob)
    ax = np.abs(V0[:, 0])
    f = CROTCH_PELVIS * (1 - S.smoothstep(0.015, 0.075, ax)) * S.smoothstep(0.66, 0.74, V0[:, 2]) * \
        (1 - S.smoothstep(0.86, 0.92, V0[:, 2]))
    Wp = np.zeros_like(W)
    Wp[:, ctx.bones.index("pelvis")] = 1.0
    W = W * (1 - f[:, None]) + Wp * f[:, None]
    from lib.weights import smooth_weights
    W = smooth_weights(W, M.mesh_adjacency(ob), CROTCH_SMOOTH, 0.5)
    metal = M.vert_mask_of_zone(ob, zones, {2})
    W = M.one_weight_per_piece(ob, W, metal, ~metal)
    uv = M.garment_uvs(ctx, ob, "legs")
    # shading: the fall's outline (a flap from hip to hip under the waistband), side seams
    V = M.mesh_arrays(ob)
    X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
    col = np.ones(len(V))
    front = Y < -0.03
    flap = front & (Z > 0.86) & (Z < WAIST_BAND[0])
    col[flap] *= 1 - 0.28 * np.exp(-((np.abs(X[flap]) - 0.085) / 0.0025) ** 2)
    edge = front & (np.abs(X) < 0.085)
    col[edge] *= 1 - 0.22 * np.exp(-((Z[edge] - 0.865) / 0.0025) ** 2)
    col *= 1 - 0.16 * np.exp(-((Z - WAIST_BAND[0]) / 0.002) ** 2) - 0.16 * np.exp(-((Z - KNEE_BAND[1]) / 0.002) ** 2)
    hides = ["pelvis_center", "pelvis_side", "thigh_upper_l", "thigh_upper_r", "thigh_lower_l", "thigh_lower_r"]
    return M.finish(ctx, SPEC, ob, zones, W, uv, hide_candidates=hides, colors=M.rgba(col))
