"""Wool leggings, mitasses (cloth2, on the skin of the legs: recipes.leggings' cut with a flap of its own): coarse
wool from the instep to above the knee, sewn up the outer side so the two edges stand out beyond the seam as a flap,
tied under the knee with a garter. Plain cloth: no ribbon or bead edging (the Eastern Woodlands set is not
extended)."""

import numpy as np

from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import tailor as TL
from cloth2.mesh import smoothstep
from cloth2.spec import Spec, Zone

TOP = 0.70
EASE = 0.0062               # over the breeches above the garter
# (2026-10-03: they fitted like tights and the 3.8 cm flap read as a loose strip) cut loose below the garter, sagging in
# a few folds, the flap d'Aleyrac's four fingers wide
LOOSE = (0.0105, 0.115, 0.40)   # more ease below the garter (m), full from z LOOSE[1] up to LOOSE[2]
SAG = (0.0022, 0.075)           # sag folds round the leg below the garter: amplitude, pitch (m)
GARTER = (0.428, 0.456)
FLAP = {"width": 0.070, "lean": 66.0, "lift": 0.0020, "curl": 0.010, "z": (0.66, 0.155), "top_frac": 0.30,
        "full_t": 0.30}

PAL = ["stroud_blue", "stroud_red", "ranger_green", "royal_blue", "grey_white", "walnut_brown", "drab", "slate_grey"]

SPEC = Spec(
    id="leggings_wool", name="Wool leggings (mitasses)", set="colonial", slot="legs.over", layer={"default": 30},
    description="Coarse wool leggings from the instep to above the knee, sewn up the outer side with the edges "
                "standing out as a flap, tied under the knee with a garter.",
    history="Mitasses of coarse wool were what Canadians, the colonial regulars on campaign and rangers wore on the "
            "legs in the woods: about three quarters of a yard long, cut loose, the seam some four fingers in from the "
            "edges so the flap stands outside the leg, tied under the knee (d'Aleyrac; Knox, 1758). Blue, red or "
            "green [S2][S1][M1][M3]. Plain new builds of the documented French-Canadian and colonial-regular campaign "
            "wear, not the Eastern Woodlands set (the owner's consultation decision, 2026-10-03).",
    zones=[Zone(0, "leggings", "cloth", "WOOL", PAL, "stroud_red"),
           Zone(1, "garters", "ribbon", "WOOL", PAL + ["madder_red", "logwood_black", "ribbon_red"], "madder_red")],
    sources=["S2", "S1", "M1", "M3"], evidence="A", tags=["men", "women", "colonial", "canada", "winter"], budget=2800,
    over=["breeches"],
    extra={"presets": {"canadian": {"0": "stroud_red", "1": "madder_red"}, "marine": {"0": "stroud_blue", "1": "madder_red"},
                       "ranger": {"0": "ranger_green", "1": "madder_red"}},
           "slot_note": "Shares legs.over with stockings (worn instead of them).",
           "references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-Canadian-Milice-Guidelines.pdf",
                          "https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-British-Regulars-Guidelines.pdf"]})


def build(g):
    fits = g.fits
    g.shell(G.LEGS, base="skin")
    g.top(TOP)
    g.seams(back=False, limbs=())
    g.fit(ease=EASE, smooth=2, gap=0.002)
    # loose below the garter, the cloth sagging in a few soft folds (level, a little uneven round the leg)
    P = g.P
    z = P[:, 2]
    below = smoothstep(LOOSE[1] - 0.04, LOOSE[1], z) * (1.0 - smoothstep(LOOSE[2], LOOSE[2] + 0.025, z))
    ang = np.arctan2(P[:, 0] - np.sign(P[:, 0]) * 0.09, -P[:, 1])
    sag = SAG[0] * np.sin(2.0 * np.pi * (z + 0.012 * np.sin(ang)) / SAG[1])
    g.m.offset((LOOSE[0] + sag) * below, vertical=0.3)
    g.m.smooth(1, 0.4)
    g.fits.clear(g.m, 0.002)
    g.over(SPEC.over, 0.004)
    # the garter below the knee
    g.raised(TL.band_select(g, *GARTER), 0.0030, 1)
    # the flap up the outer side of each leg: the seam line found by rays from outside, the flap leaning back
    J = fits.J
    for s in ("l", "r"):
        sg = 1.0 if s == "l" else -1.0
        zs = np.linspace(FLAP["z"][0], FLAP["z"][1], 26)
        lx = np.interp(zs, [J[s + "_ankle"][2], J[s + "_knee"][2], J[s + "_upper_leg"][2]],
                       [J[s + "_ankle"][0], J[s + "_knee"][0], J[s + "_upper_leg"][0]])
        ly = np.interp(zs, [J[s + "_ankle"][2], J[s + "_knee"][2], J[s + "_upper_leg"][2]],
                       [J[s + "_ankle"][1], J[s + "_knee"][1], J[s + "_upper_leg"][1]])
        O = np.stack([lx + sg * 0.25, ly + 0.006, zs], 1)
        P, ok = HW.ray_points(g.m, O, [-sg, 0.0, 0.0], 0.3)
        P = P[ok]
        if len(P) > 3:
            # the flap narrows a little at its ends (the cut of the cloth), and above the knee, where a coat's or
            # capot's skirt hangs over it, it lies narrow (it would stand out through the skirt's side)
            wf = lambda t: FLAP["width"] * (0.75 + 0.25 * np.sin(np.pi * np.clip(t * 1.1, 0, 1))) * \
                (FLAP["top_frac"] + (1.0 - FLAP["top_frac"]) * smoothstep(0.0, FLAP["full_t"], t))
            g.add(TL.flap(g, P, FLAP["width"], FLAP["lift"], FLAP["lean"], rows=3, zone=0, curl=FLAP["curl"],
                          width_fn=wf))
    g.hem = lambda m: m.boundary()[1] & (m.V[G.REF][:, 2] < 0.12)
    g.uv(limbs=("leg_l", "leg_r"))


build_and_export = G.runner(SPEC, build)
