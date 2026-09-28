"""Caped hunting frock, costume bible §4.5 `hunting_frock` (Set B, "existing mesh"): the
legacy coat of actor_b_body.glb unchanged in cut: mid-thigh, open front, a short shoulder
cape with a straight lower edge, a standing collar, turned-back cuffs, side pleats and a
back vent, the skirt on the six panel helpers. Linen, linsey (low-nap wool) or tow.

Bible §2.2 / §4.2: the backcountry hunting shirt or frock, "an open-fronted frock reaching
halfway down the thigh, with large sleeves and a large shoulder cape", usually linsey or
coarse linen [P3][R5]; the current in-game outfit's frock is the "Backcountry militia"
look. Grade A (Virginia / Pennsylvania backcountry 1758+), B for New York and New England.
The fringed variant (`hunting_shirt_tow`) belongs to the frontier set.
"""

from garments.militia import _coat as CO
from garments.militia import _militia as M

PAL = ["linen_unbleached", "tow", "walnut_brown", "butternut", "indigo_mid", "ranger_green", "drab", "logwood_black"]

SPEC = M.spec(
    id="hunting_frock", name="Caped hunting frock", slot="outer", layer={"default": 40},
    zones=[M.MZone(0, "cloth", "LIN", PAL, "linen_unbleached", name="frock", fabrics=["LIN", "HES", "WOOL"]),
           M.MZone(1, "lining", "LIN", ["linen_unbleached", "tow", "linen_white", "drab"], "linen_unbleached",
                   name="lining", fabrics=["LIN", "HES"]),
           M.MZone(2, "trim", "LIN", PAL + ["madder_red", "linen_white", "stroud_blue"], "linen_unbleached",
                   name="collar and cuffs", fabrics=["LIN", "HES", "WOOL"])],
    description="Open-fronted frock to mid-thigh with a short shoulder cape, turned-back cuffs and a vented back, "
                "worn belted over shirt and waistcoat.",
    history="The backcountry hunting frock: linsey or coarse tow linen, caped, reaching halfway down the thigh "
            "(Doddridge). Put on the Virginia troops by Washington for the Forbes expedition of 1758.",
    evidence="A", sources=["P3", "R5", "R4", "P7"], budget=6000, tags=["frontier"],
    extra={"regional_note": "Grade A for the Virginia and Pennsylvania backcountry from 1758; grade B for New York "
                            "and New England before 1775 (bible §2.2)."})


def build(ctx):
    cut = CO.CoatCut(M.LEGACY_SKIRT, M.LEGACY_OPEN, cape=True, collar="stand", cuff=(0.645, 0.009))
    return CO.build_coat(ctx, SPEC, cut, target=3600)
