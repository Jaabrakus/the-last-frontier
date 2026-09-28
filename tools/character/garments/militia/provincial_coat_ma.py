"""Massachusetts provincial coat of 1758, costume bible §4.5 `provincial_coat_ma`: blue
wool with red lapels, cuffs and lining and white-metal buttons: a regimental cut on the
frock coat's pattern (the same skirt, pleats and vent), lapels buttoned back on the chest,
deep round cuffs, no collar.

Bible §4.1: Captain Job Winslow's Massachusetts company "probably wore blue coats with red
lapels, cuffs and lining and white-metal buttons" in 1758 [M3]. Grade A. The facing and
lining colours are options, so the Virginia Regiment's blue faced red (`provincial_coat_va`,
grade B) is a colour choice of the same coat (brass or gilt buttons for officers).
"""

from garments.militia import _coat as CO
from garments.militia import _militia as M
from garments.militia import frock_coat as FC

SPEC = M.spec(
    id="provincial_coat_ma", name="Provincial coat, blue faced red (1758)", slot="outer", layer={"default": 40},
    zones=[M.MZone(0, "cloth", "WOOL", ["indigo_mid", "royal_blue", "stroud_blue", "ranger_green", "drab",
                                         "madder_red"], "indigo_mid", name="coat", fabrics=["WOOL"]),
           M.MZone(1, "lining", "WOOL", ["madder_red", "scarlet", "buff", "white_facing", "indigo_mid", "drab"],
                   "madder_red", name="lining", fabrics=["WOOL", "TWILL", "LIN"]),
           M.MZone(2, "trim", "WOOL", ["madder_red", "scarlet", "buff", "white_facing", "royal_blue", "full_green"],
                   "madder_red", name="lapels and cuffs", fabrics=["WOOL"]),
           M.MZone(3, "button", "MET", ["pewter", "silver", "brass", "gold_lace"], "pewter", name="buttons")],
    description="Blue wool coat of regimental cut with red lapels buttoned back, red round cuffs and lining, and "
                "white-metal buttons.",
    history="Captain Job Winslow's Massachusetts company probably wore blue coats with red lapels, cuffs and "
            "lining and white-metal buttons in 1758 (Fort Ticonderoga, Massachusetts Provincials).",
    evidence="A", sources=["M3", "R19"], budget=6000, tags=["regulars"],
    extra={"variants_note": "Virginia Regiment (blue faced red, bible provincial_coat_va, grade B) = the same coat; "
                            "officers: brass or gold buttons."})

OPEN = ([0.44, 0.50, 0.60, 0.72, 0.84, 0.93, 1.02, 1.10, 1.20, 1.28, 1.34, 1.50],
        [0.215, 0.200, 0.165, 0.112, 0.062, 0.036, 0.034, 0.036, 0.042, 0.050, 0.060, 0.07])


def build(ctx):
    cut = CO.CoatCut(FC.SKIRT, OPEN, cape=False, collar=None, cuff=(0.52, 0.011), cuff_buttons=3,
                     lapels={"z0": 1.005, "z1": 1.282, "w0": 0.050, "w1": 0.068}, pockets={"z": 0.838, "ang": 60.0},
                     neck_r=0.010)
    # seven buttons on the outer edge of each lapel, two below them
    import numpy as np
    btn = []
    for s in (1, -1):
        for z in np.linspace(1.03, 1.26, 7):
            w = float(CO.open_w(cut, z))
            lw = 0.050 + 0.018 * (z - 1.005) / (1.282 - 1.005)
            btn.append((s * (w + lw - 0.011), float(z), 0.0058))
        for z in (0.955, 0.925):
            btn.append((s * (float(CO.open_w(cut, z)) + 0.014), z, 0.0058))
    cut.buttons = btn
    return CO.build_coat(ctx, SPEC, cut, target=3800)
