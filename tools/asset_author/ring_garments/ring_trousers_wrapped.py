"""Wrapped ring trousers (cloth2 dress.trousers): roomy at the thigh, the shins bound in a long wrap band (a stripe
on the bias reads as the wound cloth). The earth side's. Tag pants."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

from ring_garments import _common as C

PAL = ["ring_olive", "ring_olive_dark", "ring_moss", "ring_khaki", "ring_umber", "ring_ochre"]
WRAP = {"options": ["none", "stripe"], "default": "stripe",
        "stripe": {"colors": ["ring_khaki", "ring_umber"], "scale_m": 0.05, "angle": 32.0, "duty": 0.78},
        "note": "the wound wrap: a dark line between the turns, on the bias"}

SPEC = Spec(
    id="ring_trousers_wrapped", name="Ring trousers (wrapped)", set=C.SET, slot="legs.lower", layer={"default": 30},
    description="Roomy trousers with the shins bound from the calf to the ankle in a long wrap.",
    history=C.HISTORY,
    zones=[Zone(0, "cloth", "cloth", "TWILL", PAL, "ring_olive"),
           Zone(1, "waistband and shin wraps", "trim", "LIN", PAL, "ring_khaki", pattern=WRAP)],
    evidence="C", tags=C.tags("pants", "earth"), budget=7500,
    extra={"presets": {"earth": {"0": "ring_olive", "1": "ring_khaki"}},
           "recipe_note": "dress.trousers: flare to 3.6 cm at the thigh, the band cuff 19 cm (the wrap) on the bias."})

STYLE = dress._style(dress.TROUSERS, {"top": 1.04, "flare": [(0.18, 0.0), (0.30, 0.022), (0.45, 0.036), (0.60, 0.020),
                                                              (0.70, 0.004), (0.74, 0.0)],
                                      "folds": {"amp": 0.005, "count": 7.0}, "crotch": {"drop": 0.028, "width": 0.075},
                                      "cuff": {"kind": "band", "len": 0.19, "h": 0.0035}, "end": 0.93})


def build(g):
    recipes.trousers(g, STYLE)


build_and_export = G.runner(SPEC, build)
