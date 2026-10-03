"""The entari (cloth2 recipe type robe, mode crossed: cloth2.dress.ROBE): the long robe of the Ottoman and Arab
towns over the shirt and the wide trousers, fitted to the hip, the fronts wrapped left over right and tied with
tapes at the right side, a round collarless neck, sleeves to the wrist with small buttons, skirts to below the
knees with side slits from the hips. Under the sash (sash_shawl) and the outer robe."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["crimson", "yellow", "full_green", "linen_white", "indigo_mid", "madder_red", "cotton_white", "logwood_black"]
STRIPES = {"options": ["none", "stripe", "check"], "default": "stripe",
           "stripe": {"colors": ["crimson", "cotton_white", "yellow"], "scale_m": 0.022},
           "check": {"colors": ["indigo_mid", "cotton_white"], "scale_m": 0.014},
           "note": "striped silk-cotton (the stripes often figured), Aleppo flowered stuffs, Indian silk-cottons, "
                   "calico; plain indigo or madder for the common sort"}
UNDER = ["shirt_collarless", "salvar_mens", "shift_linen"]

SPEC = Spec(
    id="entari", name="Entari (long robe)", set="middle_east", slot="vest", layer={"default": 36},
    description="A long robe fitted to the hip, the fronts wrapped left over right and tied at the right side, a "
                "round collarless neck, sleeves to the wrist with small buttons, skirts to below the knees with side "
                "slits.",
    history="The entari (the Levant's kunbaz, the Egyptian kuftan) was the robe of every townsman over the shirt and "
            "drawers: fitted to the hip, the fronts wrapped over and tied with tapes at the side, a round collarless "
            "neck, the sleeves to the wrist with small buttons and loops, the skirts 'under the knees' with slits at "
            "the sides from the hip; of striped silk-cotton, Aleppo flowered stuffs, Indian silk-cottons or calico, "
            "muslin in summer. 'The common people ... are content with the breeches, the enteri, and the benisch' "
            "[RUS][NIE][LAN].",
    zones=[Zone(0, "striped silk-cotton", "cloth", "LIN", PAL, "crimson", pattern=STRIPES),
           Zone(1, "cuffs and facings", "trim", "LIN", PAL, "crimson"),
           Zone(2, "buttons", "button", "MET", ["brass", "silver", "logwood_black", "linen_white"], "brass"),
           Zone(3, "tapes", "ribbon", "FLAT", ["ribbon_red", "ribbon_yellow", "ribbon_green", "ribbon_white",
                                              "ribbon_black"], "ribbon_red")],
    sources=["RUS", "NIE", "LAN"], evidence="A",
    tags=["men", "women", "middle_east", "ottoman_turkish", "levantine", "armenian", "kurdish", "arab", "egyptian"],
    budget=9000, over=UNDER,
    extra={"presets": {"striped": {"0": "crimson", "1": "crimson", "2": "brass", "3": "ribbon_red"},
                       "indigo": {"0": "indigo_mid", "1": "indigo_mid", "2": "logwood_black", "3": "ribbon_black",
                                  "pattern": "none"},
                       "madder": {"0": "madder_red", "1": "madder_red", "2": "brass", "3": "ribbon_yellow",
                                  "pattern": "none"}},
           "recipe_note": "cloth2.dress.robe mode crossed: the overlap line runs from the left of the neck across the "
                          "breast to the right of the waist and straight down; the skirts split along it below 0.86 "
                          "(the line's fold raised 2.8 mm), side slits from 0.85 (recipes.coat slits).",
           "fabric_note": "LIN until the COT and SILK kits exist (docs/research/peoples_dress_1750s.md 2.4).",
           "references": ["[RUS] Russell, Natural History of Aleppo: https://archive.org/details/naturalhistoryof01russ",
                          "[NIE] Niebuhr: https://archive.org/details/b28773263_0001",
                          "[LAN] Lane: https://archive.org/details/accountofmanners00lane"]})

STYLE = recipes.style(dress.ROBE, mode="crossed", hem=(0.385, 0.38, 0.38), flare=0.12, folds=0.006, steps=12,
                      over=tuple(UNDER), over_gap=0.006, skirt_gap=0.048, sleeve_end=0.93,
                      cuffs={"t0": 0.845, "h": 0.0014}, cuff_buttons=5, button_r=0.0042,
                      ties=[(-50.0, 1.055), (-50.0, 0.985)], slits=[(86.0, 94.0, 0.85)])


def build(g):
    recipes.robe(g, STYLE)


build_and_export = G.runner(SPEC, build)
