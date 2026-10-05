"""The air side's tunic (cloth2 dress.tunic): a light flowing pull-over to the knee, wide sleeves to the forearm that
open toward the cuff, the skirt split high at both sides so it streams when running and turning, a neck slit and broad
contrasting bands at the neck, the slit and the cuffs. Over the wide trousers, under the wound sash. Our own cut in the
spirit of mountain monastery robes."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

from ring_garments import _common as C

PAL = ["ring_marigold", "ring_saffron", "ring_cream", "ring_rust"]
UNDER = ["ring_trousers_wide"]

SPEC = Spec(
    id="ring_air_tunic", name="Air side tunic", set=C.SET, slot="shirt", layer={"default": 36},
    description="A light pull-over tunic to the knee with wide sleeves to the forearm, the skirt split high at both "
                "sides, broad bands at the neck, the slit and the cuffs.",
    history=C.HISTORY,
    zones=[Zone(0, "tunic", "cloth", "LIN", PAL, "ring_marigold"),
           Zone(1, "bands", "trim", "LIN", PAL, "ring_saffron")],
    evidence="C", tags=C.tags("air"), budget=8500, over=UNDER,
    extra={"presets": {"air": {"0": "ring_marigold", "1": "ring_saffron"}},
           "recipe_note": "dress.tunic: hem 0.44, slits to 0.80 at both sides, sleeves to arm 0.80 widening 6 cm from "
                          "0.45, bands 3.4 cm at the neck, 1.4 cm along the slit, 5 cm at the cuffs."})

STYLE = dress._style(dress.TUNIC, {"neck": {"a": 0.082, "b": 0.074, "z0": 1.325, "tilt": 17.0},
                                   "slit": {"z0": 1.19, "w": (0.0015, 0.016)}, "ease": 0.0085,
                                   "sleeves": {"end": 0.80, "ease": (0.010, 0.020), "wide": 0.060, "from": 0.45},
                                   "hem": 0.44, "side_hem": 0.46, "flare": 0.12, "folds": 0.010, "steps": 12,
                                   "slits": [(78.0, 102.0, 0.80)], "closed": False,
                                   "over": tuple(UNDER), "over_gap": 0.007,
                                   "trim": {"neck": 0.034, "slit": 0.014, "cuff": 0.05}})


def build(g):
    recipes.tunic(g, STYLE)


build_and_export = G.runner(SPEC, build)
