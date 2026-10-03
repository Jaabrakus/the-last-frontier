"""The women's kerchief (cloth2: the cloth shell of the shoulders cut to its outline by cloth2.settlers): a large
square of linen or silk folded into a triangle, its point hanging down the back, the ends brought over the shoulders,
crossed over the breast and tucked into the stays' front. Over the shift and stays; a jacket goes over it."""

import numpy as np

from cloth2 import garment as G
from cloth2 import settlers as ST
from cloth2 import tailor as TL
from cloth2.mesh import smoothstep
from cloth2.parts import angle_from_front
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="kerchief_womens", name="Kerchief (women's)", set="colonial", slot="accessories.neck", layer={"default": 25},
    description="A large linen or silk kerchief folded into a triangle, its point down the back, the ends crossed over "
                "the breast and tucked into the stays.",
    history="A large kerchief of white linen or cotton, or of black silk, folded into a triangle and crossed in front "
            "covered the neck opening of every woman's working dress; the 1759 print of a Canadienne shows a black one "
            "crossed in front (the Fort Ticonderoga guidelines) [S6][S9].",
    zones=[Zone(0, "kerchief", "cloth", "LIN", ["linen_white", "logwood_black", "check_blue", "linen_unbleached",
                                                "madder_red"], "linen_white",
                pattern={"options": ["none", "check"],
                         "check": {"colors": ["check_blue", "linen_white"], "scale_m": 0.010}}),
           Zone(1, "hem", "trim", "LIN", ["linen_white", "logwood_black", "check_blue", "linen_unbleached"],
                "linen_white")],
    sources=["S6", "S9", "M2"], evidence="A", tags=["women", "colonial", "settlers"], budget=1200,
    over=["shift_linen", "stays_laced"],
    extra={"presets": {"margaretha": {"0": "linen_white", "1": "linen_white"},
                       "anna": {"0": "logwood_black", "1": "logwood_black"}},
           "references": ["https://fortticonderoga.org/wp-content/uploads/2024/06/Zipped-1759-Siege-of-Carillon-French-Women-Guidelines.pdf",
                          "https://goschenhoppen.org/colonial-clothing/"]})

BACK_POINT = 1.150          # the triangle's point at the centre back
TUCK = 1.236                # the ends go into the stays' front here (just above their top edge, 1.243)
CROSS = 1.272               # the ends cross here at the centre front (the bottom of the V at the throat)
SHOULDER = (0.165, 1.335)   # the outer edge comes over the shoulder here (|x|, z)


def outline(P):
    """> 0 inside the kerchief: below the neck fold, above the lower edge (the back's point; in front each end's outer
    edge running from the shoulder down to the tuck at the centre)."""
    X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(X)
    th = angle_from_front(P)
    back = smoothstep(75.0, 130.0, th)
    low_back = BACK_POINT + 1.05 * ax
    k = (SHOULDER[1] - TUCK) / SHOULDER[0]
    low_front = TUCK + k * ax
    low = low_front * (1.0 - back) + low_back * back
    return Z - low


def left_end(P):
    """< 0 on the left end where it lies over the right one: from the left shoulder down across the centre front to
    its tuck right of the centre (the left end crosses over)."""
    X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
    # its lower edge: a line from the left shoulder down to the tuck 3 cm right of the centre
    k = (SHOULDER[1] - TUCK) / (SHOULDER[0] + 0.03)
    lower = TUCK + k * (X + 0.03)
    upper = CROSS + 1.45 * X               # its upper edge: the V's left side, carried on past the centre
    return np.maximum(lower - Z, Z - upper) + 10.0 * smoothstep(-0.05, -0.02, Y)


def build(g):
    g.shell(G.TORSO + G.NECK)
    # the neck fold, dipping in front into the V between the crossed ends
    g.neckline(a=0.074, b=0.066, z0=1.338, tilt=17.0, dip=0.045, dip_width=0.05)
    ST.keep(g, outline)
    g.seams(back=True, limbs=())
    g.fit(ease=0.011, gap=0.008)
    g.over(SPEC.over, 0.0035)
    g.m.smooth(2, 0.4)
    g.over(SPEC.over, 0.003)
    # the folded linen's thickness; the left end lying over the right where they cross
    g.raised(lambda P: np.full(len(P), -1.0), 0.0022, 0)
    g.raised(left_end, 0.0018, 0)
    g.edge_zone(1, 0.006, select=lambda P: P[:, 2] < 1.31)
    g.hem_below(1.40)
    TL.clean(g)
    g.uv(axis_top=1.40, axis_bottom=1.10, limbs=())


build_and_export = G.runner(SPEC, build)
