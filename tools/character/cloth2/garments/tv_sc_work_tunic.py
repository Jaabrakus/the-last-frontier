"""The Stone Children sleeveless work tunic (cloth2 recipe type robe, mode crossed, sleeveless: cloth2.dress.ROBE sleeves
None): a crossed charcoal tunic to the knee with deep side slits, an ochre guild band along the collar and the front
edge, the plated arms bare. The quarry hands' everyday dress (the Common Folk lineup's mason, Thạch Uyên)."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_sc_trousers"]

SPEC = Spec(
    id="tv_sc_work_tunic", name="Sleeveless work tunic", set="tv_stone", slot="shirt", layer={"default": 20},
    description="A crossed sleeveless tunic of charcoal cloth to the knee, deep side slits, an ochre guild band along "
                "the collar and the front edge.",
    history="Design note: the mason of the Common Folk lineup: a blocky dark column with the arms bare (the plates "
            "show), a pale shade cloth over it. Cut a little wider than the highland vest (more ease): Stone Children "
            "read broad.",
    zones=[Zone(0, "work cloth", "cloth", "WOOL", TV.STONE, "tv_charcoal"),
           Zone(1, "guild band", "band", "WOOL", TV.STONE, "tv_ochre_banner"),
           Zone(2, "unused", "metal", "MET", TV.METALS, "tv_bronze"),
           Zone(3, "ties", "ribbon", "HES", TV.STONE, "tv_leather")],
    sources=[], evidence="C", tags=["men", "women", "tv_stone", "stone_children", "everyday"], budget=6000, over=UNDER,
    extra=TV.extra({0: "felt", 1: "weave", 2: "metal", 3: "leather"}, {1: TV.HOUSE},
                   presets={"charcoal": {"0": "tv_charcoal", "1": "tv_ochre_banner"},
                            "dust": {"0": "tv_dust_buff", "1": "tv_kiln_brick"}},
                   note="cloth2.dress.robe mode crossed, sleeves None; hem 0.62 (side slits to 0.90), ease 1.6 cm; a "
                        "3.5 cm guild band (zone 1, house_mark weave); two leather ties at -50 deg."))

STYLE = recipes.style(dress.ROBE, mode="crossed", sleeves=None, ease=0.016, hem=(0.62, 0.62, 0.625), flare=0.08,
                      folds=0.008, steps=8, over=tuple(UNDER), over_gap=0.006, over_relax=1, skirt_gap=0.04,
                      slits=[(78.0, 102.0, 0.90)], collar_band={"w": 0.038, "h": 0.004},
                      ties=[(-50.0, 1.05), (-50.0, 0.98)])


def build(g, st=STYLE):
    recipes.robe(g, st)


build_and_export = G.runner(SPEC, build)
