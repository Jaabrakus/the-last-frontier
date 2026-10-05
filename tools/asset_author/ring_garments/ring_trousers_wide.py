"""Wide ring trousers (cloth2 dress.trousers kind wide): full legs gathered into ankle bands, for the air side's
running and turning. Tag pants."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

from ring_garments import _common as C

PAL = ["ring_tangerine", "ring_saffron", "ring_marigold", "ring_cream", "ring_rust"]

SPEC = Spec(
    id="ring_trousers_wide", name="Ring trousers (wide)", set=C.SET, slot="legs.lower", layer={"default": 30},
    description="Wide light trousers gathered on a drawstring at the waist and into bands at the ankles.",
    history=C.HISTORY,
    zones=[Zone(0, "cloth", "cloth", "LIN", PAL, "ring_tangerine"),
           Zone(1, "waist and ankle bands", "trim", "LIN", PAL, "ring_marigold")],
    evidence="C", tags=C.tags("pants", "air"), budget=7500,
    extra={"presets": {"air": {"0": "ring_tangerine", "1": "ring_marigold"}},
           "recipe_note": "dress.trousers wide: flare to 5.2 cm at the knee, gathered ankle bands 4 cm."})

STYLE = dress._style(dress.TROUSERS, {"top": 1.05, "flare": [(0.18, 0.0), (0.32, 0.026), (0.50, 0.052), (0.70, 0.044),
                                                              (0.84, 0.018), (0.92, 0.0)],
                                      "folds": {"amp": 0.006, "count": 7.0},
                                      "cuff": {"kind": "band", "len": 0.04, "h": 0.003}, "end": 0.93})


def build(g):
    recipes.trousers(g, STYLE)


build_and_export = G.runner(SPEC, build)
