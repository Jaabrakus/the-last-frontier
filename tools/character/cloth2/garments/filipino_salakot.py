"""The salakot (cloth2 rigid_hat profile DOME_FINIAL: cloth2.dress.lathe_hat): a wide domed hat of split bamboo or
rattan with a knob finial on top, held on the head by an inner head band (the baat) and a chin strap."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="filipino_salakot", name="Salakot (domed hat)", set="southeast_asia", slot="head", layer={"default": 80},
    description="A wide domed hat of split bamboo or rattan with a knob on top, held by an inner head band and a "
                "chin strap.",
    history="The salakot of the Tagalog and Visayan lowlands was a wide dome of bamboo, rattan or nito about 0.45 m "
            "across, standing above the head on an inner band (the baat), with a finial knob or spike, worn by "
            "farmers, boatmen and the Manila men of the galleon trade; silver-trimmed ones marked the better-off "
            "[PH5][PH3].",
    zones=[Zone(0, "bamboo", "cloth", "HES", ["bamboo", "straw", "walnut_brown", "logwood_black"], "bamboo"),
           Zone(1, "head band", "trim", "HES", ["straw", "bamboo", "walnut_brown"], "straw"),
           Zone(2, "finial", "trim", "WOOL", ["walnut_brown", "bamboo", "silver", "logwood_black"], "walnut_brown"),
           Zone(3, "chin strap", "ribbon", "FLAT", ["leather_brown", "straw", "logwood_black"], "leather_brown")],
    hides_hair_zones=["crown"], sources=["PH5", "PH3"], evidence="A",
    tags=["men", "women", "southeast_asia", "filipino"], budget=2600,
    extra={"presets": {"bamboo": {"0": "bamboo", "1": "straw", "2": "walnut_brown", "3": "leather_brown"},
                       "better_off": {"0": "walnut_brown", "1": "straw", "2": "silver", "3": "logwood_black"}},
           "recipe_note": "cloth2.dress.lathe_hat DOME_FINIAL: a dome of revolution 0.225 m in radius rising 0.145 m "
                          "from its rim, 5 mm thick, on an inner elliptic band (0.083 x 0.105 m) at the hat band plane, "
                          "a finial knob 4 cm, a chin strap kept 7 mm off the face; rigid on headb.",
           "fabric_note": "HES (a coarse weave) until the STRAW kit exists.",
           "references": ["[PH5] The salakot: https://en.wikipedia.org/wiki/Salakot"]})


def build(g):
    recipes.lathe_hat(g, dress.DOME_FINIAL)


build_and_export = G.runner(SPEC, build)
