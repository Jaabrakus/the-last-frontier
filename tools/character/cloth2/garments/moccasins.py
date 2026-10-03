"""Moccasins, souliers de boeuf (cloth2, grown round the foot: cloth2.feet.SockTube): a soft sole wrapping the foot
to the quarters, a vamp over the instep gathered into the sole, ankle flaps turned down over the leggings' lower end,
tied in front with a thong. Plain leather: no quill or bead work (the Eastern Woodlands set is not extended)."""

import numpy as np

from cloth2 import feet as FT
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import tailor as TL
from cloth2 import trims as TR
from cloth2.mesh import REF, smoothstep, unit
from cloth2.parts import angle_from_front
from cloth2.spec import Spec, Zone

EASE = 0.0056               # soft leather close on the foot (over a stocking or a legging's foot)
TOP = 0.118                 # the moccasin's top round the ankle
FLAP_DROP = 0.056           # the turned-down flaps: their depth below the top edge
FLAP_OUT = 0.016            # how far the flaps stand off the upper at their lower edge
GAP = 0.0075                # the flaps' gap over the instep (half width)

SPEC = Spec(
    id="moccasins", name="Moccasins (souliers de boeuf)", set="colonial", slot="feet", layer={"default": 40},
    description="Soft-soled moccasins of smoked hide or cowhide: the sole drawn up round the foot and gathered into a "
                "vamp over the instep, with flaps turned down round the ankle over the leggings and a thong tied in "
                "front.",
    history="Canadians wore moccasins, souliers de boeuf, of smoked deer hide or of tanned cowhide, with mitasses and "
            "a capot; the troupes de la marine were issued them for campaigns in the woods and in winter, and "
            "settlers and rangers wore them too [S2][S1][M5]. Plain hide here: decoration is not part of this set.",
    zones=[Zone(0, "hide", "leather", "SUEDE", ["buckskin_smoked", "leather_brown", "buckskin_pale", "walnut_brown"],
                "buckskin_smoked"),
           Zone(1, "vamp", "leather", "SUEDE", ["buckskin_smoked", "leather_brown", "buckskin_pale", "walnut_brown"],
                "buckskin_smoked"),
           Zone(2, "thong", "leather", "LEA", ["leather_brown", "buckskin_smoked", "logwood_black"], "leather_brown")],
    sources=["S2", "S1", "M5"], evidence="A", tags=["men", "women", "colonial", "canada", "winter"], budget=2700,
    over=["stockings", "leggings_wool"],
    extra={"presets": {"smoked": {"0": "buckskin_smoked", "1": "buckskin_smoked", "2": "leather_brown"},
                       "cowhide": {"0": "leather_brown", "1": "leather_brown", "2": "logwood_black"}},
           "construction": "cloth2.feet.SockTube 5.6 mm off the skin, fitted over stockings and leggings_wool; the "
                           "flaps grown from the top edge (trims.extrude)",
           "consultation_note": "A French-Canadian and settler item (Fort Ticonderoga's Canadian militia and colonial "
                                "regulars guidelines); built new from cloth2, not from the Eastern Woodlands set, "
                                "and kept plain.",
           "references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-Canadian-Milice-Guidelines.pdf",
                          "https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-French-Army-Colonial-Regulars-Guidelines-1.pdf"]})


def _centre_x(fits, s):
    return fits.J[s + "_ankle"][0] + (0.004 if s == "l" else -0.004)


def build(g):
    fits = g.fits
    J = fits.J
    g.m = FT.both(fits, lambda s: FT.SockTube(fits, s, top=0.15, segs=16, step_leg=0.012, step_foot=0.0118,
                                              cap=4).mesh(EASE, foot_smooth=6))
    g.over(SPEC.over, 0.003)
    g.top(TOP)
    # the vamp: a U over the instep from the toes' root to the front of the ankle, its seam standing a little
    def vamp(P):
        out = np.full(len(P), 1.0)
        for s in ("l", "r"):
            sg = 1.0 if s == "l" else -1.0
            A, B = J[s + "_ankle"], J[s + "_ball"]
            side = (sg * P[:, 0]) > 0.0
            xc = np.interp(P[:, 1], [B[1] - 0.06, A[1]], [B[0] - sg * 0.006, A[0] + sg * 0.004])
            y0, y1 = B[1] - 0.050, A[1] - 0.034
            w = 0.024 * np.sqrt(np.clip((P[:, 1] - y0) / 0.026, 0.0, 1.0))
            f = np.maximum.reduce([np.abs(P[:, 0] - xc) - w, y0 - P[:, 1], P[:, 1] - y1,
                                   (0.030 - P[:, 2]) * 3.0])
            out[side] = f[side]
        return out
    g.raised(TL.cut_select(g, vamp), 0.0011, 1)
    # the flaps: grown down and out from the top edge, parted over the instep
    def disp(fit, P0, N0, s):
        n = N0.copy()
        n[:, 2] = 0.0
        n = unit(n)
        # over the instep the flaps are shorter (the foot rises in front of the ankle)
        drop = np.empty(len(P0))
        for side in ("l", "r"):
            sg = 1.0 if side == "l" else -1.0
            A = J[side + "_ankle"]
            on = (sg * P0[:, 0]) > 0.0
            a = angle_from_front(P0, centre=(A[0] + sg * 0.004, A[1] - 0.006))
            drop[on] = (FLAP_DROP * (0.40 + 0.60 * smoothstep(30.0, 80.0, a)))[on]
        return n * (0.0025 + FLAP_OUT * np.sqrt(s)) + np.stack([np.zeros(len(P0)), np.zeros(len(P0)), -drop * s], 1)
    piece = TR.extrude(g.m, lambda P: P[:, 2] > TOP - 0.004, disp, rings=3, zone=0)
    if piece is not None:
        def gap(P):
            out = np.full(len(P), 1.0)
            for s in ("l", "r"):
                sg = 1.0 if s == "l" else -1.0
                A = J[s + "_ankle"]
                side = (sg * P[:, 0]) > 0.0
                f = np.maximum(np.abs(P[:, 0] - _centre_x(fits, s)) - GAP, P[:, 1] - (A[1] - 0.025)) * -1.0
                out[side] = f[side]
            return out
        piece = piece.clip(gap(piece.V[REF]), 0.0, keep_above=False)
        piece = TR.drop_small(piece, 6)
        fits.clear(piece, 0.003)
        g.add(piece)
    # the thong's knot in the gap
    for s in ("l", "r"):
        P = g.front_points([_centre_x(fits, s)], [TOP - 0.012])
        g.hardware(P, HW.ellipsoid(0.0065, 0.0050, 0.0045, segs=8, rings=4), 2, lift=0.0)
        for dx in (-0.0035, 0.0035):
            Pt = g.front_points([_centre_x(fits, s) + dx], [TOP - 0.024])
            g.hardware(Pt, HW.box(0.0016, 0.0065, 0.0010), 2, lift=0.0016)
    g.hem = lambda m: m.boundary()[1] & (m.V[REF][:, 2] < TOP - FLAP_DROP + 0.01) & (m.V[REF][:, 2] > 0.04)
    _uv(g)


def _uv(g):
    J = g.fits.J
    m = g.m
    left = m.V[REF][m.F].mean(1)[:, 0] > 0.0
    keep = m.fa["part"] >= 9
    m.fa["part"] = np.where(keep, m.fa["part"], np.where(left, 5, 6))
    g.uvparts = {9: ("planar", [0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0])}
    for s, pid in (("l", 5), ("r", 6)):
        A, B = J[s + "_ankle"], J[s + "_ball"]
        g.uvparts[pid] = ("cyl", np.array([A[0], A[1] + 0.05, 0.035]), np.array([B[0], B[1] - 0.06, 0.025]),
                          [0.0, 0.0, 1.0])
    return g


build_and_export = G.runner(SPEC, build)
