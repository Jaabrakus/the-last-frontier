"""The imperial levy coat (cloth2 recipe type robe, mode crossed: cloth2.dress.ROBE): a quilted court-indigo coat to the
knee, the front edge, hem and cuffs bound in lacquer red, side slits for the stride. The soldiers of the levy (R1, Act
1 at Đá Trắng: Trần Hổ's men), worn with tv_ds_levy_hat, trousers and leg wraps; spear, bow or dao only."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_mf_trousers"]

SPEC = Spec(
    id="tv_ds_levy_coat", name="Levy coat", set="tv_delta", slot="vest", layer={"default": 36},
    description="A quilted court-indigo coat to the knee, crossed and bound in lacquer red, with side slits.",
    history="Design note: the imperial levy's look (owner question 6): court indigo with lacquer-red binding, so a "
            "squad reads as one colour against the highland madder and indigo-black; quilting lines (our own lattice) "
            "instead of armour plates.",
    zones=[Zone(0, "quilted cloth", "cloth", "WOOL", TV.DELTA, "tv_deep_navy"),
           Zone(1, "binding", "band", "WOOL", TV.DELTA, "tv_lacquer_red"),
           Zone(2, "unused", "metal", "MET", TV.METALS, "tv_bronze"),
           Zone(3, "ties", "ribbon", "FLAT", TV.DELTA, "tv_lacquer_red")],
    sources=[], evidence="C", tags=["men", "women", "tv_delta", "dragon_sea", "npc", "levy_soldier"], budget=8000,
    over=UNDER,
    extra=TV.extra({0: "felt", 1: "weave", 2: "metal", 3: "cord"}, {0: TV.QUILT},
                   note="cloth2.dress.robe mode crossed, hem 0.60 (side slits to 0.85), sleeves to 0.90, cuffs from "
                        "0.80 raised 4 mm, a 4 cm binding along the collar and front (zone 1); quilting lattice "
                        "(motif quilting) on zone 0."))

STYLE = recipes.style(dress.ROBE, mode="crossed", hem=(0.60, 0.60, 0.605), flare=0.08, folds=0.006, steps=8,
                      ease=0.018, sleeve_end=0.90, sleeve_ease=(0.004, 0.014), over=tuple(UNDER), over_gap=0.007,
                      over_relax=1, skirt_gap=0.04, slits=[(80.0, 100.0, 0.85)], cuffs={"t0": 0.80, "h": 0.004},
                      collar_band={"w": 0.042, "h": 0.004}, ties=[(-50.0, 1.05), (-50.0, 0.98)])


def build(g, st=STYLE):
    recipes.robe(g, st)


build_and_export = G.runner(SPEC, build)
