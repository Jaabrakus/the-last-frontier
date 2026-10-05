"""Fitted ring trousers (cloth2 dress.trousers): a drawstring band, the legs eased a little at the knee for kicks and
narrowing into a band at the ankle. The fire and water sides' trousers. Tag pants."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

from ring_garments import _common as C

PAL = ["ring_ember", "ring_char", "ring_deep", "ring_navy", "ring_olive", "ring_rust", "ring_flame", "ring_sea"]

SPEC = Spec(
    id="ring_trousers_fitted", name="Ring trousers (fitted)", set=C.SET, slot="legs.lower", layer={"default": 30},
    description="Trousers for the ring: a drawstring band, room at the knee for a kick, the legs narrowing into an "
                "ankle band.",
    history=C.HISTORY,
    zones=[Zone(0, "cloth", "cloth", "TWILL", PAL, "ring_ember"),
           Zone(1, "waist and ankle bands", "trim", "TWILL", PAL + ["ring_gold"], "ring_char")],
    evidence="C", tags=C.tags("pants", "fire", "water"), budget=7000,
    extra={"presets": {"fire": {"0": "ring_ember", "1": "ring_char"},
                       "water": {"0": "ring_deep", "1": "ring_navy"}},
           "recipe_note": "dress.trousers: flare to 2.4 cm at the knee, band cuff 5 cm."})

STYLE = dress._style(dress.TROUSERS, {"top": 1.04, "flare": [(0.18, 0.0), (0.32, 0.012), (0.50, 0.024), (0.68, 0.018),
                                                              (0.84, 0.006), (0.92, 0.0)],
                                      "folds": {"amp": 0.004, "count": 7.0}, "crotch": {"drop": 0.025, "width": 0.075},
                                      "cuff": {"kind": "band", "len": 0.05, "h": 0.003}, "end": 0.93})


def build(g):
    recipes.trousers(g, STYLE)


build_and_export = G.runner(SPEC, build)
