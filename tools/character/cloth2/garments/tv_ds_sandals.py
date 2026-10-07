"""The Dragon-Sea toe sandals (cloth2 recipe type sandals, toe: cloth2.tv_dress.TOE_SANDALS): a thin walnut sole, a
strap over the instep and a loop round the big toe; the delta's everyday footwear at the piers."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_ds_sandals", name="Toe sandals", set="tv_delta", slot="feet", layer={"default": 40},
    description="Thin-soled sandals with a strap over the instep and a loop round the big toe.",
    history="Design note: the dock woman's light sandals on the lineup: a thin sole, almost bare feet.",
    zones=[Zone(0, "sole", "leather", "LEA", TV.DELTA, "tv_walnut"),
           Zone(1, "straps", "leather", "LEA", TV.DELTA, "tv_walnut")],
    sources=[], evidence="C", tags=["women", "men", "tv_delta", "tv_common", "dragon_sea", "everyday"], budget=2000,
    extra=TV.extra({0: "leather", 1: "leather"}, note="cloth2.tv_dress.sandals toe: a 9 mm sole, an 18 mm strap, a "
                                                      "12 mm toe loop."))

STYLE = TVD.TOE_SANDALS


def build(g, st=STYLE):
    recipes.sandals(g, st)


build_and_export = G.runner(SPEC, build)
