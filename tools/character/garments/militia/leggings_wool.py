"""Wool leggings (the 1758 issue), costume bible §4.5 / §2.6 `leggings_wool`: the legacy
leggings of actor_b_body.glb: coarse wool from the instep to above the knee, the seam
flaps on the outside of the leg, tied under the knee with garters of the same cloth
(rigid on the shin, as today).

Bible (Knox, 1758): coarse wool about ¾ yard long, sewn so the flaps sit on the outside,
tied under the knee and above the ankle with garters [M1]; issued in blue or green to the
1758 provincials [M3]. Grade A.
"""

import numpy as np

from lib import sdf as S
from lib.remesh import join

from garments.militia import _militia as M

PAL = ["indigo_mid", "ranger_green", "stroud_blue", "stroud_red", "drab", "slate_grey", "walnut_brown"]

SPEC = M.spec(
    id="leggings_wool", name="Wool leggings (1758 issue)", slot="legs.over", layer={"default": 30},
    zones=[M.MZone(0, "cloth", "WOOL", PAL, "ranger_green", name="leggings", fabrics=["WOOL", "TWILL"]),
           M.MZone(1, "band", "WOOL", PAL + ["madder_red", "logwood_black"], "ranger_green", name="garters",
                   fabrics=["WOOL", "KNIT", "LEA"])],
    description="Coarse wool leggings from the instep to above the knee with the seam flaps outside, tied under "
                "the knee with garters.",
    history="Knox, 1758: frieze about three quarters of a yard long, the flaps outside, gartered under the knee; "
            "issued in blue or green to the provincials that year.",
    sources=["M1", "M3", "M2"], budget=2500, tags=["frontier"])

GARTER_Z = (0.396, 0.416)


def legging_radius(X, Y, Z):
    return np.interp(Z, [0.07, 0.14, 0.40, 0.55, 0.64], [0.018, 0.013, 0.014, 0.017, 0.019])


def leggings_node(K, body):
    leg = S.Inter(S.Inter(S.Offset(body, legging_radius, r_max=0.019), S.zslab(0.075, 0.625)), S.xband(0.26))
    flaps = []
    for s in (1, -1):
        H, Kn, A = K.side("upper_leg", s), K.side("knee", s), K.side("ankle", s)
        out = S.v3(s, 0, 0)
        R1 = S.frame_from(S.nrm(Kn - H), out)
        R2 = S.frame_from(S.nrm(A - Kn), out)
        flaps.append(S.Union([
            S.RoundBox(S.lerp(Kn, H, 0.25) + out * 0.078 + S.v3(0, 0.004, 0), (0.022, 0.0028, 0.085), 0.0025, R1),
            S.RoundBox(S.lerp(Kn, A, 0.47) + out * 0.058 + S.v3(0, 0.008, 0), (0.020, 0.0028, 0.205), 0.0025, R2),
        ], k=0.01))
    return S.SymUnion(leg, flaps[0], flaps[1], k=0.008)


def garters_node(K, body):
    band = S.Inter(S.Inter(S.Offset(body, 0.0185), S.zslab(*GARTER_Z)), S.xband(0.26))
    ties = []
    zc = 0.5 * (GARTER_Z[0] + GARTER_Z[1])
    for s in (1, -1):
        kn = K.side("knee", s)
        base = S.surface_point(band, S.v3(s * 0.30, kn[1] - 0.004, zc), S.v3(-s, 0, 0), 0.0, 0.30 - abs(kn[0]))
        base = base + S.v3(s * 0.002, 0, 0)
        ties.append(S.Union([S.Sphere(base, 0.0065),
                             S.RoundCone(base, base + S.v3(s * 0.001, -0.006, -0.030), 0.0034, 0.0026),
                             S.RoundCone(base, base + S.v3(s * 0.001, 0.007, -0.026), 0.0034, 0.0026)], k=0.003))
    return S.SymUnion(band, ties[0], ties[1], k=0.003)


def build(ctx):
    K = ctx.K
    mats = M.zone_mats(SPEC)
    body = M.body_f(ctx)
    legs = M.sdf_part(ctx, "leggings", leggings_node(K, body), 0.003, 1500, mats[0],
                      visible=lambda P: np.where(P[:, 2] < 0.10, 0.018, np.where(np.abs(P[:, 2] - 0.47) < 0.08, 0.021, 0.029)),
                      hidden=0.036, feature_deg=35.0, iters=22, sharp_deg=55, hidden_below=0.010)
    M.strip_to_envelope(ctx, legs, "legwear")
    M.drop_small_islands(legs)
    M.fit_budget(legs, SPEC.budget["tris_max"] - 520)
    gart = M.sdf_part(ctx, "garters", garters_node(K, body), 0.002, 260, mats[1], visible=0.011, hidden=0.03,
                      sharp_deg=45, hidden_below=0.0105)
    M.strip_to_envelope(ctx, gart, "legwear", extra_level={"shins": 0.010, "thighs": 0.010})
    M.drop_small_islands(gart)
    M.fit_budget(gart, 500)
    ob = join([legs, gart], SPEC.id)
    M.with_mats(ob, mats)
    zones = M.zones_of(ob)
    W = M.body_weights(ctx, ob, smooth=1)
    V = M.mesh_arrays(ob)
    g = M.vert_mask_of_zone(ob, zones, {1})
    W = M.rigid_bone(ctx, W, g & (V[:, 0] >= 0), "l_knee")
    W = M.rigid_bone(ctx, W, g & (V[:, 0] < 0), "r_knee")
    uv = M.garment_uvs(ctx, ob, "legs_out")
    hides = []
    for sd in "lr":
        hides += ["shin_upper_" + sd, "shin_lower_" + sd, "ankle_" + sd]
    return M.finish(ctx, SPEC, ob, zones, W, uv, hide_candidates=hides)
