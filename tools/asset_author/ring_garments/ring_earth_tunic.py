"""The earth side's tunic (cloth2 dress.robe, mode crossed): a heavy wrap tunic to mid-thigh, the fronts crossed left
over right with a broad contrasting band along the neck and the overlap (the layered look: the under-tunic's colour
showing at the edges), sleeves to below the elbow with turned cuffs, side slits for a wide stance, a knotted tie at the
right side. Worn over the wrapped trousers, under the sash."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

from ring_garments import _common as C

PAL = ["ring_ochre", "ring_moss", "ring_olive", "ring_khaki", "ring_umber"]
UNDER = ["ring_trousers_wrapped"]

SPEC = Spec(
    id="ring_earth_tunic", name="Earth side tunic", set=C.SET, slot="shirt", layer={"default": 36},
    description="A heavy wrap tunic to mid-thigh, crossed left over right, a broad band of the under-layer's colour "
                "along the neck and the overlap, sleeves to below the elbow, side slits.",
    history=C.HISTORY,
    zones=[Zone(0, "tunic", "cloth", "TWILL", PAL, "ring_ochre"),
           Zone(1, "bands and cuffs", "trim", "TWILL", PAL, "ring_moss"),
           Zone(3, "tie", "ribbon", "FLAT", PAL, "ring_umber")],
    evidence="C", tags=C.tags("earth"), budget=9500, over=UNDER,
    extra={"presets": {"earth": {"0": "ring_ochre", "1": "ring_moss", "3": "ring_umber"}},
           "recipe_note": "dress.robe crossed: hem 0.60, sleeves to arm 0.60, a 5 cm collar band and binding, side "
                          "slits to 0.80, fitted over the wrapped trousers."})

STYLE = recipes.style(dress.ROBE, mode="crossed", hem=(0.60, 0.60, 0.60), flare=0.10, folds=0.005, steps=8,
                      over=tuple(UNDER), over_gap=0.006, skirt_gap=0.05, sleeve_end=0.60,
                      sleeve_ease=(0.004, 0.016), cuffs={"t0": 0.53, "h": 0.004}, cuff_buttons=0,
                      collar_band={"w": 0.05, "h": 0.0032}, slits=[(80.0, 100.0, 0.80)],
                      ties=[(-50.0, 1.02)], over_relax=1)


def build(g):
    recipes.robe(g, STYLE)


build_and_export = G.runner(SPEC, build)
