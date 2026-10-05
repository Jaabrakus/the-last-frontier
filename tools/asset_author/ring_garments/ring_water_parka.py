"""The water side's parka (cloth2 dress.tunic, a pull-over): a heavy coat to mid-thigh pulled on over the head, a hood
lying on the back, a standing collar of fur, deep fur cuffs and a fur band round the hem; a belt over it. Our own cut
in the spirit of Arctic fur-trimmed coats (no tribe's garment copied)."""

import numpy as np

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.mesh import BIG_FIELD, smoothstep
from cloth2.spec import Spec, Zone

from ring_garments import _common as C

PAL = ["ring_sea", "ring_deep", "ring_navy", "ring_ice", "ring_seal"]
FUR = ["ring_snow_fur", "ring_seal", "drift_frost", "fur_wolf"]
UNDER = ["ring_trousers_fitted"]
HEM = 0.66

SPEC = Spec(
    id="ring_water_parka", name="Water side parka", set=C.SET, slot="outer", layer={"default": 40},
    description="A heavy pull-over coat to mid-thigh with a hood lying on the back, a standing fur collar, deep fur "
                "cuffs and a fur band round the hem.",
    history=C.HISTORY,
    zones=[Zone(0, "coat", "cloth", "WOOL", PAL, "ring_sea"),
           Zone(1, "fur trim", "fur", "FUR", FUR, "ring_snow_fur"),
           Zone(2, "hood lining and seams", "trim", "WOOL", PAL, "ring_ice")],
    evidence="C", tags=C.tags("water", "winter"), budget=9500, over=UNDER,
    extra={"presets": {"water": {"0": "ring_sea", "1": "ring_snow_fur", "2": "ring_ice"}},
           "fur_note": "Zone 1 is a fur zone (role fur: the cloth shader's fur base); no fur shell surface.",
           "recipe_note": "dress.tunic: hem 0.66, sleeves to 0.95, the hood (hood.hood_on_back), a fur stand collar, "
                          "raised fur cuffs and hem band."})

STYLE = dress._style(dress.TUNIC, {"neck": {"a": 0.092, "b": 0.084, "z0": 1.33, "tilt": 17.0}, "slit": None,
                                   "ease": 0.0135, "hem": HEM, "side_hem": HEM + 0.005, "flare": 0.07,
                                   "folds": 0.004, "steps": 8, "closed": False,
                                   # (split at the sides: closed round both legs, a wide stance showed the trousers
                                   # through the stretched front)
                                   "slits": [(82.0, 98.0, HEM + 0.13)],
                                   "sleeves": {"end": 0.95, "ease": (0.010, 0.018), "wide": 0.012, "from": 0.6},
                                   "hood": {"tip_z": 1.07, "half_w": 0.13, "h_max": 0.022, "zone": 0},
                                   "over": tuple(UNDER), "over_gap": 0.007,
                                   "trim": {"neck": 0.0, "slit": 0.0, "cuff": 0.0}})


def build(g):
    recipes.tunic(g, STYLE)
    # the fur: a standing collar, deep cuffs, a band round the hem (not on the sleeves)
    g.stand_collar(0.032, lean=0.12, zone=1)
    g.cuffs(0.86, 0.008, 1, flare=0.004)
    def arm():
        return smoothstep(0.3, 0.6, np.maximum(g.m.A["m_arm_l"], g.m.A["m_arm_r"]))
    g.raised(g.P[:, 2] - (HEM + 0.055) + BIG_FIELD * arm(), 0.008, 1)
    # our own mark: an ice band round the chest under the arms
    g.raised(np.abs(g.P[:, 2] - 1.155) - 0.016 + BIG_FIELD * arm(), 0.0022, 2)
    g.hem_below(HEM + 0.08)
    g.uv()
    dress.arc_uv(g)


build_and_export = G.runner(SPEC, build)
