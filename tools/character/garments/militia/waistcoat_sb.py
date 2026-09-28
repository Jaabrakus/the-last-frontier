"""Single-breasted waistcoat, costume bible §4.5 `waistcoat_sb`: the legacy waistcoat of
actor_b_body.glb (sleeveless, a V at the neck, seven buttons, the hem dipping in front),
with pocket flaps and a linen back.

Bible: "Single- or double-breasted, with or without sleeves, in red, blue, drab, brown or
green wool, or linen and linsey in summer" [M3]. Grade A.
"""

import numpy as np

from lib import sdf as S
from lib.remesh import Prims

from garments.militia import _militia as M
from garments.militia import _vest as VST

PAL = ["madder_red", "indigo_mid", "drab", "walnut_brown", "ranger_green", "linen_unbleached", "buff", "logwood_black"]

SPEC = M.spec(
    id="waistcoat_sb", name="Waistcoat, single-breasted", slot="vest", layer={"default": 20},
    zones=[M.MZone(0, "cloth", "WOOL", PAL, "madder_red", name="fronts", fabrics=["WOOL", "LIN", "TWILL"]),
           M.MZone(1, "lining", "LIN", ["linen_unbleached", "linen_white", "tow", "drab"], "linen_unbleached",
                   name="back", fabrics=["LIN", "WOOL"]),
           M.MZone(2, "button", "MET", ["brass", "pewter", "silver", "logwood_black"], "brass", name="buttons")],
    description="Sleeveless waistcoat buttoned down the front, with pocket flaps; wool fronts on a linen back.",
    history="Worn by men of every rank, in red, blue, drab, brown or green wool, or linen in summer; the fronts "
            "of good cloth, the back of cheaper linen.",
    sources=["M3", "M2", "R20"], budget=1500, tags=["frontier", "regulars"])


def hem(X, Y, Z):
    return (0.905 + 0.22 * Y) - Z


def v_neck(X, Y, Z):
    w = 0.004 + np.maximum(Z - 1.16, 0.0) * 0.40
    return np.maximum(np.maximum(np.abs(X) - w, 1.16 - Z), Y + 0.01)


def build(ctx):
    K = ctx.K
    mats = M.zone_mats(SPEC)
    body, cuts = VST.vest_node(K, hem, v_neck)
    node = S.Union([body] + VST.pocket_flaps(K, body, 0.948), k=0.003)
    ob = M.sdf_part(ctx, SPEC.id, node, 0.0028, 1200, mats[0], visible=VST.vest_sizing(cuts), hidden=0.04,
                    feature_deg=35.0,
                    hidden_below=0.0035)
    M.strip_to_envelope(ctx, ob, "mid")
    M.drop_small_islands(ob)
    M.fit_budget(ob, SPEC.budget["tris_max"] - 300)
    zones = VST.zones_of_vest(ob, K)
    bp = Prims()
    M.buttons_on(bp, node, [(S.v3(-0.006, -0.25, z), S.v3(0, 1, 0)) for z in np.linspace(0.935, 1.135, 7)], mi=2)
    return VST.finish_vest(ctx, SPEC, ob, mats, zones, bp.to_object("buttons", mats))
