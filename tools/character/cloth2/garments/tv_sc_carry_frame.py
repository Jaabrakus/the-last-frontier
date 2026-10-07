"""The quarry carry frame (cloth2 recipe type carry, frame: cloth2.tv_dress.CARRY_FRAME): an A-frame of walnut poles on
two shoulder straps, three bound cross bars, a shelf at its foot and a dressed limestone block lashed on with hemp
cord. The quarry hands' load (NPCs first; anyone may wear it)."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_sc_work_tunic", "tv_sc_shade_cloth"]

SPEC = Spec(
    id="tv_sc_carry_frame", name="Carry frame and block", set="tv_stone", slot="accessories.shoulder",
    layer={"default": 85},
    description="An A-frame of poles carried on two shoulder straps, a dressed stone block lashed to its shelf.",
    history="Design note: the mason of the Common Folk lineup carries a dressed block high on the back; the frame "
            "puts the block above the shoulders, so the Stone Children read from behind as a square load.",
    zones=[Zone(0, "poles and shelf", "leather", "LEA", TV.STONE, "tv_walnut"),
           Zone(1, "bars, cords, straps", "ribbon", "HES", TV.STONE, "tv_hemp"),
           Zone(2, "dressed block", "trim", "FLAT", TV.STONE, "tv_quarry_white")],
    sources=[], evidence="C", tags=["men", "women", "tv_stone", "stone_children", "everyday", "npc"], budget=1800,
    over=UNDER,
    extra=TV.extra({0: "leather", 1: "cord", 2: "bone"},
                   note="cloth2.tv_dress.carry frame: two 1.6 cm poles 0.30 -> 0.10 m apart, 0.78 m tall from 0.70, "
                        "three bars, a 24 cm shelf, a 30 x 24 x 22 cm block and two lashings; rigid on the upper back."))

STYLE = dict(TVD.CARRY_FRAME, over=tuple(UNDER))


def build(g, st=STYLE):
    recipes.carry(g, st)


build_and_export = G.runner(SPEC, build)
