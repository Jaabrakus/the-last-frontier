"""Buckled shoes (cloth2, grown round the foot: cloth2.feet.SockTube + feet.sole): black waxed calf with a leather
sole and a low stacked heel, a rounded toe, the quarters below the ankle bones, latchets over the instep closed by a
buckle on the tongue."""

import numpy as np

from cloth2 import feet as FT
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import tailor as TL
from cloth2.parts import angle_from_front
from cloth2.mesh import smoothstep
from cloth2.spec import Spec, Zone

EASE = 0.0066               # the upper off the skin (over a stocking's 2.8 mm)
QUARTERS = 0.074            # the top line at the sides and back (below the ankle bones)
LATCHETS = 0.101            # the straps' top over the instep
TONGUE = 0.132              # the tongue's top in front of the ankle
BUCKLE_Z = 0.099

SPEC = Spec(
    id="shoes_buckled", name="Buckled shoes", set="colonial", slot="feet", layer={"default": 40},
    description="Black waxed-calf shoes with a rounded toe, a low stacked heel and a tongue, closed over the instep "
                "by latchets and a buckle.",
    history="Shoes of black waxed calf, closed with a buckle of brass, steel or silver over the instep, were the "
            "common footwear of townsmen, farmers and soldiers in garrison; pucker-toed moccasins replaced them in "
            "the woods [M3][M2][M6].",
    zones=[Zone(0, "upper", "leather", "LEA", ["leather_black", "leather_brown", "walnut_brown"], "leather_black"),
           Zone(1, "sole and heel", "leather", "LEA", ["leather_brown", "leather_black", "walnut_brown"], "leather_brown"),
           Zone(2, "buckles", "metal", "MET", ["brass", "pewter", "silver"], "brass", metal=True)],
    sources=["M3", "M2", "M6", "M4"], evidence="A", tags=["men", "women", "colonial"], budget=1800,
    over=["stockings", "leggings_wool"],
    extra={"presets": {"marine": {"0": "leather_black", "1": "leather_brown", "2": "brass"},
                       "gentleman": {"0": "leather_black", "1": "leather_black", "2": "silver"}},
           "construction": "cloth2.feet.SockTube 6.6 mm off the skin (a toe box over the toes), the downward rays "
                           "pressed onto a flat sole and a heel block (feet.sole), cut at the throat",
           "references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-British-Regulars-Guidelines.pdf",
                          "https://militaryheritage.com/c_franch.htm"]})


def _throat(fits):
    """The top line (field > 0 keeps): the quarters low at the sides and back, the latchets rising over the instep,
    the tongue up the front of the ankle."""
    J = fits.J

    def f(P):
        out = np.empty(len(P))
        for s in ("l", "r"):
            sg = 1.0 if s == "l" else -1.0
            A = J[s + "_ankle"]
            side = (sg * P[:, 0]) > 0.0
            c = np.array([A[0] + sg * 0.004, A[1] - 0.006])
            a = angle_from_front(P, centre=c)
            h = QUARTERS + 0.004 * smoothstep(120.0, 175.0, a)
            h = h + (LATCHETS - h) * (1.0 - smoothstep(48.0, 80.0, a))
            tw = 1.0 - smoothstep(0.015, 0.022, np.abs(P[:, 0] - c[0]))
            front = smoothstep(A[1] - 0.012, A[1] - 0.030, P[:, 1])
            h = np.maximum(h, TONGUE * tw * front)
            out[side] = (h - P[:, 2])[side]
        return out
    return f


def build(g):
    fits = g.fits
    g.m = FT.both(fits, lambda s: FT.SockTube(fits, s, top=0.16, segs=16, step_leg=0.014, step_foot=0.0116,
                                              cap=4).mesh(EASE, foot_smooth=8))
    g.over(SPEC.over, 0.003)
    FT.sole(g.m, fits, ball_z=-0.003, heel_z=-0.017, heel_from=0.038, toe_rise=0.006, edge=0.0025)
    g.m = g.m.clip(_throat(fits)(g.P), 0.0)
    # the sole and heel: below the welt's top line (the stacked heel's side, the sole's edge), cut clean
    J = fits.J

    def sole_line(P):
        out = np.empty(len(P))
        for s in ("l", "r"):
            sg = 1.0 if s == "l" else -1.0
            side = (sg * P[:, 0]) > 0.0
            A, B = J[s + "_ankle"], J[s + "_ball"]
            zt = 0.0045 + 0.006 * smoothstep(B[1] - 0.01, B[1] - 0.075, P[:, 1])
            zt = zt + (0.0015 - zt) * smoothstep(A[1] - 0.050, A[1] - 0.034, P[:, 1])
            out[side] = (P[:, 2] - zt)[side]
        return out
    sel = TL.cut_select(g, sole_line) & (g.m.A["foot"][g.m.F].mean(1) > 0.5)
    g.m.fa["zone"][sel] = 1
    # the buckles on the tongue over the latchets, and the strap's end through each
    for s in ("l", "r"):
        sg = 1.0 if s == "l" else -1.0
        A = fits.J[s + "_ankle"]
        P = g.front_points([A[0] + sg * 0.004], [BUCKLE_Z])
        g.hardware(P, HW.box(0.024, 0.0075, 0.0011), 0, lift=0.0002)
        g.hardware(P, HW.frame(0.040, 0.030, 0.0045, 0.0030), 2, lift=0.0018)
    g.hem = lambda m: m.boundary()[1] & (m.V[G.REF][:, 2] > QUARTERS - 0.01)
    _uv(g)


def _uv(g):
    J = g.fits.J
    m = g.m
    left = m.V[G.REF][m.F].mean(1)[:, 0] > 0.0
    keep = m.fa["part"] >= 9
    m.fa["part"] = np.where(keep, m.fa["part"], np.where(left, 5, 6))
    g.uvparts = {9: ("planar", [0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0])}
    for s, pid in (("l", 5), ("r", 6)):
        A, B = J[s + "_ankle"], J[s + "_ball"]
        g.uvparts[pid] = ("cyl", np.array([A[0], A[1] + 0.05, 0.035]), np.array([B[0], B[1] - 0.06, 0.025]),
                          [0.0, 0.0, 1.0])
    return g


build_and_export = G.runner(SPEC, build)
