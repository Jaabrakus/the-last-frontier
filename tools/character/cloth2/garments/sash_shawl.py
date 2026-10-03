"""The shawl sash (cloth2 recipe type sash, wound: recipes.sash with turns, cloth2.dress.wound_sash): a long shawl
or striped silk girdle wound two or three times round the waist over the inner robe, the end tucked in at the left,
a short end hanging; under the outer robe. Worn by all the peoples of the Ottoman lands, Persia, Arabia and the
Maghreb."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["madder_red", "crimson", "cotton_white", "undyed_white_wool", "yellow", "full_green", "indigo_mid",
       "logwood_black", "saffron"]
PATTERN = {"options": ["none", "stripe", "check"], "default": "stripe",
           "stripe": {"colors": ["crimson", "yellow", "cotton_white"], "scale_m": 0.036, "axis": "h"},
           "check": {"colors": ["madder_red", "cotton_white"], "scale_m": 0.02},
           "note": "stripes along the sash (axis h: round the body); a Kerman or Kashmir shawl's boteh once the "
                   "shader draws it; white figured muslin; white or red wool in Egypt"}
UNDER = ["shirt_collarless", "salvar_mens", "entari"]

SPEC = Spec(
    id="sash_shawl", name="Shawl sash", set="middle_east", slot="accessories.waist", layer={"default": 38},
    description="A long shawl or striped silk girdle wound two or three times round the waist over the robe, the end "
                "tucked in at the left and a short end hanging.",
    history="Over the entari every man wore a girdle wound several times round the waist, a Kerman or Kashmir shawl "
            "for the better-off, white figured muslin, white or red wool in Egypt, a striped silk one at Fez (a V&A "
            "sash measures 0.565 x 0.145 m folded); a dagger or a scribe's inkhorn was stuck in it [NIE][RUS][LAN]"
            "[SHA][VA-O364379].",
    zones=[Zone(0, "shawl", "cloth", "WOOL", PAL, "crimson", pattern=PATTERN),
           Zone(3, "fringe", "fringe", "WOOL", PAL, "crimson")],
    sources=["NIE", "RUS", "LAN", "SHA", "VA-O364379"], evidence="A",
    tags=["men", "women", "middle_east", "ottoman_turkish", "levantine", "persian", "arab", "armenian", "kurdish",
          "north_african", "moorish", "egyptian"], budget=4500, over=UNDER,
    extra={"presets": {"fez_stripe": {"0": "crimson", "3": "crimson"},
                       "red_wool": {"0": "madder_red", "3": "madder_red", "pattern": "none"},
                       "white_muslin": {"0": "cotton_white", "3": "cotton_white", "pattern": "none"}},
           "gear_note": "A dagger, a jambiya or an inkhorn in the sash is gear (weapons), not part of the garment.",
           "recipe_note": "recipes.sash with turns 3 (cloth2.dress.wound_sash): three bands 7.2 cm tall on a helix "
                          "from 0.94 to 1.09, each 3.2 mm over the one under it, open at 52 deg (the tuck at the left "
                          "front), a short end of 12 cm hanging there.",
           "references": ["[VA-O364379] V&A Moroccan sash: https://collections.vam.ac.uk/item/O364379",
                          "[RUS] Russell: https://archive.org/details/naturalhistoryof01russ"]})

STYLE = {"turns": 3, "z": (0.94, 1.09), "height": 0.072, "lift": 0.022, "step": 0.0032, "start": 52.0,
         "end": {"len": 0.12, "w": 0.065}, "over": tuple(UNDER), "over_gap": 0.004}


def build(g):
    recipes.sash(g, STYLE)


build_and_export = G.runner(SPEC, build)
