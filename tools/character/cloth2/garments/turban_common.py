"""The common turban (cloth2 recipe type head_wrap, kind turban: cloth2.dress.HEAD_WRAP): coarse white cloth wound
loosely in four rolls on a tilted helix round a small red felt cap, the cap's crown showing at the top, the end
tucked in at the side. Rigid on the head."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["cotton_white", "linen_white", "undyed_white_wool", "madder_red", "saffron", "yellow", "indigo_mid",
       "logwood_black", "crimson"]
PATTERN = {"options": ["none", "stripe", "check"], "default": "none",
           "stripe": {"colors": ["cotton_white", "indigo_mid"], "scale_m": 0.014, "axis": "h"},
           "check": {"colors": ["cotton_white", "madder_red"], "scale_m": 0.012},
           "note": "preset christian: a red cap wrapped in blue-and-white striped linen"}

SPEC = Spec(
    id="turban_common", name="Turban (common)", set="middle_east", slot="head", layer={"default": 80},
    description="Coarse white cloth wound loosely in four rolls round a small red felt cap, the cap's crown showing "
                "at the top, the end tucked in at the side.",
    history="The common man's turban was a coarse cloth, white and washed fresh, a red or yellow woollen shawl, or "
            "plain cotton, wound in a few loose rolls round a small cloth or low scarlet felt cap; Christians at "
            "Aleppo wrapped the red cap in blue-and-white striped linen, the Copts wore dark ones [SHA][LAN][RUS][NIE]"
            "[RIC]. Green was reserved for the descendants of the Prophet and is not offered.",
    zones=[Zone(0, "wound cloth", "cloth", "LIN", PAL, "cotton_white", pattern=PATTERN),
           Zone(1, "cap", "cloth", "WOOL", ["scarlet", "madder_red", "cotton_white", "undyed_white_wool",
                                           "logwood_black"], "scarlet")],
    hides_hair_zones=["crown", "sides", "back"], sources=["SHA", "LAN", "RUS", "NIE", "RIC"], evidence="A",
    tags=["men", "women", "middle_east", "ottoman_turkish", "levantine", "armenian", "kurdish", "moorish", "egyptian",
          "arab", "north_african", "ethiopian"], budget=3600,
    extra={"presets": {"white": {"0": "cotton_white", "1": "scarlet"},
                       "christian": {"0": "cotton_white", "1": "scarlet", "pattern": "stripe"},
                       "copt": {"0": "logwood_black", "1": "logwood_black"},
                       "kurdish": {"0": "madder_red", "1": "madder_red"}},
           "no_green_note": "No green token: green turbans were reserved for the descendants of the Prophet.",
           "recipe_note": "cloth2.dress.head_wrap kind turban: the core a small cap (hats.head_grid, edge 58/70/78 "
                          "deg); four rolls (tubes r 14.5 mm) on a helix rising 16 mm a turn from the front of the "
                          "band plane, an ellipse 0.20 m across growing 4 mm a turn, never nearer the scalp than "
                          "9.5 mm; rigid on headb.",
           "references": ["[RUS] Russell: https://archive.org/details/naturalhistoryof01russ",
                          "[LAN] Lane: https://archive.org/details/accountofmanners00lane",
                          "[SHA] Shaw: https://archive.org/details/travelsobservati00shaw"]})


def build(g):
    recipes.head_wrap(g, dress.HEAD_WRAP)


build_and_export = G.runner(SPEC, build)
