"""The Mountain Folk crossed short robe (cloth2 recipe type robe, mode crossed: cloth2.dress.ROBE): the vest's cut with
narrow sleeves to the wrist and skirts to above the knee, the woven band at the collar, the front edge and the cuffs.
The women's everyday default and everyone's in the cold months; worn under the hip panels and the sash."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_mf_trousers"]

SPEC = Spec(
    id="tv_mf_short_robe", name="Crossed short robe", set="tv_highland", slot="shirt", layer={"default": 20},
    description="A crossed short robe of indigo-black homespun, narrow sleeves to the wrist, skirts to above the knee "
                "with side slits, a woven madder band at the collar, the front edge and the cuffs.",
    history="Design note: the vest made a robe for the cold months and the women's everyday dress (peoples_design.md "
            "3.1). Narrow sleeves keep the arm line clean under the fringed mantle; the bands repeat at the cuffs so "
            "the hands are framed in madder, as the sheets frame them.",
    zones=[Zone(0, "homespun", "cloth", "LIN", TV.HIGHLAND, "tv_indigo_black"),
           Zone(1, "woven band", "band", "LIN", TV.HIGHLAND, "tv_madder"),
           Zone(2, "unused", "metal", "MET", TV.METALS, "tv_bronze"),
           Zone(3, "ties", "ribbon", "HES", TV.HIGHLAND, "tv_hemp")],
    sources=[], evidence="C", tags=["men", "women", "tv_highland", "mountain_folk", "everyday"], budget=8000,
    over=UNDER,
    extra=TV.extra({0: "weave", 1: "weave", 2: "metal", 3: "cord"}, {1: TV.BAND}, presets=TV.clan_presets(),
                   note="cloth2.dress.robe mode crossed, hem 0.70 (side slits to 0.88), sleeves to 0.92 eased "
                        "(0.002, 0.009), cuffs from 0.80 raised 2.5 mm (zone 1), a 3.4 cm collar band (zone 1), two "
                        "ties at -50 deg."))

STYLE = recipes.style(dress.ROBE, mode="crossed", hem=(0.70, 0.70, 0.705), flare=0.075, folds=0.007, steps=8,
                      sleeve_end=0.92, sleeve_ease=(0.002, 0.009), over=tuple(UNDER), over_gap=0.006, over_relax=1,
                      skirt_gap=0.035, slits=[(82.0, 98.0, 0.88)], cuffs={"t0": 0.80, "h": 0.0025},
                      collar_band={"w": 0.034, "h": 0.0035}, ties=[(-50.0, 1.05), (-50.0, 0.98)])


def build(g, st=STYLE):
    recipes.robe(g, st)


build_and_export = G.runner(SPEC, build)
