"""Civilian frock coat, costume bible §4.5 `frock_coat`: plain cloth, a falling collar, an
easy cut with the fronts curving away below the waist, pleated skirts to just above the
knee with a back vent, round cuffs with buttons, flapped pockets; buttons down the right
front, buttonholes on the left (it closes at the chest or hangs open).

Bible §4.2: "Men at almost every social level wore the frock coat for work and informal
wear: plain cloth, a turn-down collar and an easy cut" [R20]; colours drab, brown, grey,
blue and green. Grade A. The skirt is on the six skirt panel helpers; its hem (0.49 m at
the back, 4.5 cm higher in front) is declared in `skirt.hems_godot` for the driver's floor
clamp.
"""

from garments.militia import _coat as CO
from garments.militia import _militia as M

PAL = ["drab", "walnut_brown", "slate_grey", "indigo_mid", "ranger_green", "snuff", "butternut", "logwood_black",
       "madder_red"]

SPEC = M.spec(
    id="frock_coat", name="Frock coat", slot="outer", layer={"default": 40},
    zones=[M.MZone(0, "cloth", "WOOL", PAL, "walnut_brown", name="coat", fabrics=["WOOL", "TWILL", "LIN"]),
           M.MZone(1, "lining", "TWILL", ["walnut_brown", "drab", "linen_unbleached", "madder_red", "slate_grey"],
                   "drab", name="lining", fabrics=["TWILL", "LIN", "WOOL"]),
           M.MZone(2, "trim", "WOOL", PAL, "walnut_brown", name="collar and cuffs", fabrics=["WOOL", "TWILL", "LIN"]),
           M.MZone(3, "button", "MET", ["brass", "pewter", "silver", "logwood_black", "walnut_brown"], "brass",
                   name="buttons")],
    description="Plain wool frock coat with a turned-down collar, cuffs and flapped pockets, the skirts pleated "
                "at the sides and vented behind.",
    history="The everyday coat of men of almost every rank for work and informal wear: plain cloth, a turn-down "
            "collar and an easy cut, in drab, brown, grey, blue or green.",
    evidence="A", sources=["R20", "M3", "M15"], budget=6000, tags=["frontier"])

SKIRT = M.Skirt(Z=[0.47, 0.55, 0.65, 0.75, 0.85, 0.93, 0.99],
                A=[0.262, 0.252, 0.236, 0.214, 0.190, 0.162, 0.150],
                B=[0.192, 0.186, 0.172, 0.156, 0.142, 0.118, 0.110],
                C=[0.010, 0.010, 0.010, 0.011, 0.012, 0.006, 0.004],
                pleats=(96.0, 134.0, 3, 0.0048), hem=0.49, front_rise=0.045, vent_top=0.76)
OPEN = ([0.44, 0.50, 0.60, 0.72, 0.84, 0.93, 1.05, 1.18, 1.26, 1.34, 1.50],
        [0.215, 0.200, 0.165, 0.112, 0.062, 0.030, 0.022, 0.030, 0.042, 0.058, 0.07])


def build(ctx):
    cut = CO.CoatCut(SKIRT, OPEN, cape=False, collar="fall", cuff=(0.56, 0.010), cuff_buttons=3,
                     pockets={"z": 0.838, "ang": 60.0})
    cut.buttons = CO.front_buttons(cut, 0.86, 1.245, 8)
    return CO.build_coat(ctx, SPEC, cut, target=3600, extra_col=CO.buttonhole_shade(cut, 0.86, 1.245, 8))
