"""Wool stockings, costume bible §4.5 `stockings`: knitted stockings from the toes to above
the knee, gartered below the knee (the garter under the breeches' knee band).

Bible: "Wool, worsted, linen or cotton, in white, grey, black, brown, blue or green. Fort
Ticonderoga's guidelines reject red and yellow stockings" [M3]. Grade A. Worn in the
legs.over slot (leggings go in the same slot).

Built as a skin copy (lib-free: _militia.skin_copy): the body's own triangles of the lower
legs and feet pushed 2.8 mm out along the skin normal, cut at the top of the stocking and at
the garter. The stocking therefore has the skin's topology and weights: it covers the shins,
ankles and feet exactly (they are hidden under it) and never lets the skin through.
"""

import numpy as np

from lib import sdf as S

from garments.militia import _militia as M

PAL = ["linen_white", "slate_grey", "logwood_black", "walnut_brown", "indigo_mid", "ranger_green", "drab"]

SPEC = M.spec(
    id="stockings", name="Wool stockings", slot="legs.over", layer={"default": 10},
    zones=[M.MZone(0, "cloth", "KNIT", PAL, "slate_grey", name="stockings", fabrics=["KNIT", "LIN"]),
           M.MZone(1, "ribbon", "KNIT", ["madder_red", "logwood_black", "linen_white", "slate_grey", "leather_brown"],
                   "logwood_black", name="garters")],
    description="Knitted wool stockings reaching above the knee, tied below the knee with garters.",
    history="Wool, worsted, linen or cotton, in white, grey, black, brown, blue or green; red and yellow were not "
            "worn by the provincials (Fort Ticonderoga guidelines).",
    sources=["M3", "M2"], budget=3500, tags=["frontier", "regulars", "women"],
    extra={"construction": "skin copy: the body's lower-leg and foot triangles offset along the skin normal"})

TOP_Z = 0.600
GARTER = (0.404, 0.420)
OFF = 0.0028


def build(ctx):
    K = ctx.K
    mats = M.zone_mats(SPEC)
    regs = []
    for sd in "lr":
        regs += ["thigh_lower_" + sd, "shin_upper_" + sd, "shin_lower_" + sd, "ankle_" + sd, "foot_" + sd]

    def off(P):
        z = P[:, 2]
        g = (z > GARTER[0] - 1e-4) & (z < GARTER[1] + 1e-4)
        welt = z > TOP_Z - 0.029
        return OFF + 0.0012 * g + 0.0006 * welt
    ob = M.skin_copy(ctx, SPEC.id, regs, off, cuts=(GARTER[0], GARTER[1], TOP_Z - 0.029), keep_below=TOP_Z,
                     mat=mats[0])
    M.with_mats(ob, mats)
    C = M.poly_centers(ob)
    zones = np.where((C[:, 2] > GARTER[0]) & (C[:, 2] < GARTER[1]), 1, 0)
    M.set_zone(ob, zones)
    W = M.body_weights(ctx, ob, smooth=0)
    V = M.mesh_arrays(ob)
    N = M.poly_normals(ob)
    sole = (C[:, 2] < 0.03) & (N[:, 2] < -0.6)
    extra = [M.Flat(S.v3(0, 0, 0), S.v3(1, 0, 0), S.v3(0, -1, 0))]
    uv = M.garment_uvs(ctx, ob, "legs", extra_maps=extra, extra_part=np.where(sole, 0, -1))
    col = 1.0 - 0.18 * np.exp(-((V[:, 2] - (TOP_Z - 0.029)) / 0.002) ** 2)
    hides = []
    for sd in "lr":
        hides += ["shin_upper_" + sd, "shin_lower_" + sd, "ankle_" + sd, "foot_" + sd]
    return M.finish(ctx, SPEC, ob, zones, W, uv, hide_candidates=hides, colors=M.rgba(col))
