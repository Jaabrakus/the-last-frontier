"""The neckerchief (cloth2 recipe: recipes.neckwear "neckerchief"): a linen or silk handkerchief folded into a band,
wound round the neck over the shirt's collar and knotted at the throat, the short ends tucked into the waistcoat or
veste. White linen it is the colonial regulars' cravat."""

import numpy as np

from cloth2 import bridge as BR
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import recipes
from cloth2.spec import Spec, Zone

# the band round the neck above its root (t: m along the neck's axis), the knot high on it at the throat (above
# a coat's or capot's neckline), the short ends going down into the waistcoat's V
STYLE = {"t": (0.010, 0.048), "ease": 0.0105, "knot": None, "ends": None}
KNOT = (0.020, 0.013, 0.0052)          # a flat knot (a ball would read as a button; 2026-10-03: flatter and wider,
CROSS = (0.0075, 0.015, 0.0064)        # with the turn of the cloth across it, so it reads as a knot)
SIDE_EASE = 0.006                      # more room over the shirt's collar at the sides of the neck (it came through)
KNOT_BELOW_TOP = 0.005
ENDS = {"len": 0.055, "w": 0.026, "lift": 0.0100}

SPEC = Spec(
    id="neckerchief", name="Neckerchief", set="colonial", slot="accessories.neck", layer={"default": 15},
    description="A linen or silk handkerchief folded into a band, tied round the neck with the knot at the throat and "
                "the short ends tucked in.",
    history="Black silk and checked or white linen handkerchiefs were everyday neckwear for settlers, Canadians, "
            "rangers and soldiers; the colonial regulars of New France wore a white linen cravat with the garrison "
            "uniform and a neckerchief on campaign [R20][M3][M15][M6][S2].",
    zones=[Zone(0, "kerchief", "cloth", "LIN", ["logwood_black", "linen_white", "check_blue", "madder_red", "indigo_mid"],
                "logwood_black")],
    sources=["R20", "M3", "M15", "M6", "S2"], evidence="A", tags=["men", "women", "colonial"], budget=900,
    over=["shirt_linen", "shirt_tucked", "shirt_check"],
    extra={"presets": {"cravat": {"0": "linen_white"}, "silk": {"0": "logwood_black"}, "checked": {"0": "check_blue"}},
           "pattern_note": "A check pattern is not drawn by the cloth shader yet: check_blue is the plain colour.",
           "replaces": "the v1 militia neckerchief (fitted to the old body); same id, so its users (factions.json "
                       "toughs, Rook's ROOK_WANTS) now get this one",
           "references": ["https://goschenhoppen.org/colonial-clothing/",
                          "https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-Canadian-Milice-Guidelines.pdf"]})


def build(g):
    recipes.neckwear(g, "neckerchief", STYLE)
    BR.ease_sides(g, SIDE_EASE)
    P = g.front_points(np.zeros(15), np.linspace(1.27, 1.41, 15))
    # only the band's front: a ray passing above the front (the band rises toward the back of the neck) hits the
    # inside of its back, and the knot would go there
    P = P[P[:, 1] < -0.02]
    if len(P):
        # the knot high on the band (above a capot's standing collar, whose top edge is ~1.34 m at the front)
        k = P[np.argmin(np.abs(P[:, 2] - (P[:, 2].max() - KNOT_BELOW_TOP)))]
        for s in (1, -1):
            way = [k + np.array([s * 0.005, -0.010, -0.010]), k + np.array([s * 0.013, -0.020, -0.032]),
                   k + np.array([s * 0.019, -0.026, -ENDS["len"]])]
            g.strap(way, ENDS["w"], ENDS["lift"], 0, step=0.01, width_fn=lambda t: ENDS["w"] * (0.75 + 0.25 * t))
        g.hardware([k], HW.ellipsoid(*KNOT, segs=10, rings=5), 0, lift=-0.002)
        g.hardware([k], HW.ellipsoid(*CROSS, segs=8, rings=4), 0, lift=-0.002)
    g.over(SPEC.over, 0.003)
    g.uv(axis_top=1.45, axis_bottom=1.2, limbs=())


build_and_export = G.runner(SPEC, build)
