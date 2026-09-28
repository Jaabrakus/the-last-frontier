"""The linen shirt (cloth2 recipe)."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="shirt_linen", name="Linen shirt", set="colonial", slot="shirt", layer={"default": 10, "hips": 35, "thighs": 35},
    description="A linen shirt with full sleeves gathered into wrist bands, a low standing collar and tails to mid-thigh, "
                "slit at the sides.",
    history="Men and women of every rank wore a linen shirt or shift next to the skin, changed weekly at best; "
            "coarse tow linen for labour, finer linen for those who could afford it [P1][M2].",
    zones=[Zone(0, "linen", "cloth", "LIN", ["linen_white", "linen_unbleached", "tow"], "linen_white"),
           Zone(1, "collar and wrist bands", "trim", "LIN", ["linen_white", "linen_unbleached", "tow"], "linen_white")],
    hides_force=["pelvis_center"],      # the tails hang over the groin: nothing of a man shows there (the genitals are hidden)
    sources=["P1", "M2"], evidence="A", tags=["men", "colonial"], budget=4400)


def build(g):
    recipes.shirt(g)


build_and_export = G.runner(SPEC, build)
