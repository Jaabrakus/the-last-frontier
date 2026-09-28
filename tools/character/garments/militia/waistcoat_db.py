"""Double-breasted waistcoat, costume bible §4.5 `waistcoat_db`: the left front laps over
the right, two rows of buttons, a straight hem at the waist, a short V at the neck.

Bible: "Double-breasted red waistcoats were a favourite merchant offering to the 1758
provincials" [M3]. Grade A. Same pattern base as waistcoat_sb (10 mm over the torso, linen
back, pocket flaps).
"""

import numpy as np

from lib import sdf as S
from lib.body_shapes import torso_shapes
from lib.remesh import Prims

from garments.militia import _militia as M
from garments.militia import _vest as VST

PAL = ["madder_red", "indigo_mid", "drab", "walnut_brown", "ranger_green", "linen_unbleached", "buff", "logwood_black"]

SPEC = M.spec(
    id="waistcoat_db", name="Waistcoat, double-breasted", slot="vest", layer={"default": 20},
    zones=[M.MZone(0, "cloth", "WOOL", PAL, "madder_red", name="fronts", fabrics=["WOOL", "LIN", "TWILL"]),
           M.MZone(1, "lining", "LIN", ["linen_unbleached", "linen_white", "tow", "drab"], "linen_unbleached",
                   name="back", fabrics=["LIN", "WOOL"]),
           M.MZone(2, "button", "MET", ["brass", "pewter", "silver", "logwood_black"], "pewter", name="buttons")],
    description="Double-breasted waistcoat with two rows of buttons and a straight hem; wool fronts on a linen back.",
    history="Double-breasted red waistcoats were a favourite of the merchants who clothed the 1758 Massachusetts "
            "provincials (Fort Ticonderoga).",
    sources=["M3", "R20"], budget=1500, tags=["frontier"])

EDGE_X = -0.052        # the overlapping (left) front's edge, on the wearer's right


def hem(X, Y, Z):
    return (0.903 + 0.06 * Y) - Z


def v_neck(X, Y, Z):
    w = 0.004 + np.maximum(Z - 1.228, 0.0) * 0.55
    return np.maximum(np.maximum(np.abs(X) - w, 1.228 - Z), Y + 0.01)


def build(ctx):
    K = ctx.K
    mats = M.zone_mats(SPEC)

    def roff(X, Y, Z):
        lap = S.smoothstep(EDGE_X - 0.0006, EDGE_X + 0.0006, X) * S.smoothstep(0.15, 0.09, X) * (Y < -0.02)
        return VST.WC_OFF + 0.0019 * lap
    body, cuts = VST.vest_node(K, hem, v_neck, base_node=S.Offset(torso_shapes(K, smooth=True), roff, r_max=0.012))
    node = S.Union([body] + VST.pocket_flaps(K, body, 0.940, x=0.098), k=0.003)
    ob = M.sdf_part(ctx, SPEC.id, node, 0.0026, 1250, mats[0], visible=lambda P: np.minimum(VST.vest_sizing(cuts)(P), np.where(
        np.abs(P[:, 0] - EDGE_X) < 0.010, 0.013, 0.024)), hidden=0.04, feature_deg=30.0, symmetric=False,
                    hidden_below=0.0035)
    M.strip_to_envelope(ctx, ob, "mid")
    M.drop_small_islands(ob)
    M.fit_budget(ob, SPEC.budget["tris_max"] - 420)
    zones = VST.zones_of_vest(ob, K)
    bp = Prims()
    pts = [(S.v3(x, -0.25, z), S.v3(0, 1, 0)) for x in (-0.040, 0.040) for z in np.linspace(0.95, 1.19, 6)]
    M.buttons_on(bp, node, pts, radius=0.0058, mi=2)

    def edge_shade(V):
        return 1 - 0.3 * np.exp(-((V[:, 0] - EDGE_X - 0.0015) / 0.0022) ** 2) * (V[:, 1] < -0.02) * (V[:, 2] < 1.235)
    return VST.finish_vest(ctx, SPEC, ob, mats, zones, bp.to_object("buttons", mats), extra_col=edge_shade)
