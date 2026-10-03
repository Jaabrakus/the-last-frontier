"""The knit tuque (cloth2: recipes.soft_cap's cap over the head, with the folded length of its own): a long knitted
wool cap, the brim turned up into a band, the rest of its length folded over flat onto the crown toward the back-left,
its rounded end hanging over the band behind the wearer's left ear. Pulled down to the brows and over the tops of the
ears, the hair tucked in: it hides the hair's crown, sides and back zones (a queue still hangs below it). Rigid on the
head."""

import math

import numpy as np

from cloth2 import bridge as BR
from cloth2 import garment as G
from cloth2 import hats as HT
from cloth2.parts import angle_from_front
from cloth2.spec import Spec, Zone

CAP = {"edge": (94.0, 97.0, 106.0), "ease": 0.0115, "band": {"width": 0.05, "h": 0.0045, "front_deg": 181.0}}
# the folded length lying on the crown: the cap fuller over the top (FOLD_TOP, falling off as cos(polar)) and fuller
# still in a lobe drawn over toward FOLD_AZ (degrees round from the front toward the wearer's left), from the crown down
# to about FOLD_PH (degrees from the crown); then the end, a soft rounded tube hanging over the band behind the ear
FOLD_TOP, FOLD_SIDE, FOLD_AZ, FOLD_W, FOLD_PH = 0.014, 0.024, 142.0, 48.0, 88.0
END = {"ph": (76.0, 124.0), "az": 146.0, "r": (0.026, 0.013), "lift": 0.006, "n": 11}
SEGS, ROWS = 40, 12


SPEC = Spec(
    id="tuque_knit", name="Knit tuque", set="colonial", slot="head", layer={"default": 80},
    description="A long knitted wool cap with the brim turned up into a band, the rest folded over flat on the crown, "
                "its end hanging at the back of the head on the left, to about the ear.",
    history="The bonnet or tuque, a long knitted cap, was the Canadian's headwear, issued to the militia and to "
            "the colonial regulars for campaigns (the 1756 issue lists one bonnet); red was the usual colour, blue "
            "and white were worn too, and settlers, sailors and rangers wore knit caps of the same kind [S1][S2]"
            "[S13][S5].",
    zones=[Zone(0, "knit", "cloth", "KNIT", ["ribbon_red", "stroud_red", "stroud_blue", "linen_white", "walnut_brown",
                                             "grey_white", "madder_red"], "ribbon_red"),
           Zone(1, "band", "cloth", "KNIT", ["ribbon_red", "stroud_red", "stroud_blue", "linen_white", "walnut_brown",
                                             "grey_white", "madder_red"], "ribbon_red")],
    hides_hair_zones=["crown", "sides", "back"], sources=["S1", "S2", "S13", "S5"], evidence="A",
    tags=["men", "women", "colonial", "canada", "winter"], budget=1600,
    extra={"presets": {"canadian": {"0": "ribbon_red", "1": "ribbon_red"}, "blue": {"0": "stroud_blue", "1": "stroud_blue"},
                       "settler": {"0": "walnut_brown", "1": "walnut_brown"}},
           "fold_note": "2026-10-03: the long tube rising out of the crown and hooking over read as a bonnet rouge or "
                        "an elf's cap, with a hole at the fold: the folded length now lies on the crown as the cap's own "
                        "fuller crown, drawn over toward the back-left, and its rounded end hangs over the band behind "
                        "the left ear (rigid on the head).",
           "references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-French-Army-Colonial-Regulars-Guidelines-1.pdf",
                          "https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-Canadian-Milice-Guidelines.pdf",
                          "https://thecanadianencyclopedia.ca/en/article/clothing-during-the-colonial-period"]})


def _ease(th, ph):
    """The cap's room over the scalp at (azimuth th, polar ph; radians): the folded length's volume on the crown."""
    th = np.asarray(th, float)
    ph = np.asarray(ph, float)
    d = np.angle(np.exp(1j * (th - math.radians(FOLD_AZ))))           # wrapped to -pi..pi
    lobe = np.exp(-(d / math.radians(FOLD_W)) ** 2) * np.sin(np.pi * np.clip(ph / math.radians(FOLD_PH + 14.0), 0.0, 1.0)) ** 0.8
    return CAP["ease"] + FOLD_TOP * np.cos(np.clip(ph, 0.0, np.pi / 2)) ** 1.2 + FOLD_SIDE * lobe


def build(g):
    fits = g.fits
    fr, sd, bk = [np.radians(a) for a in CAP["edge"]]

    def phi_max(th):
        c = np.cos(th)
        return np.where(c > 0, sd + (fr - sd) * c, sd + (bk - sd) * (-c))
    m, ids, TH, PH = HT.head_grid(fits, segs=SEGS, rows=ROWS, phi_max=phi_max, ease=_ease)
    g.m = m
    c0 = HT.headb(fits) + np.array([0.0, -0.035, 0.075])
    bd = CAP["band"]
    g.edge_zone(1, bd["width"], h=bd["h"],
                select=lambda P: angle_from_front(P - np.array([0.0, c0[1], 0.0])) < bd["front_deg"])
    # the end: from inside the fold's lobe out over the band behind the left ear, rounded at its tip
    from cloth2 import drift as D
    az = math.radians(END["az"])
    ph = np.radians(np.linspace(END["ph"][0], END["ph"][1], END["n"]))
    dirs = np.stack([np.sin(ph) * math.sin(az), -np.sin(ph) * math.cos(az), np.cos(ph)], 1)
    k = np.linspace(0.0, 1.0, len(ph))
    r = END["r"][0] + (END["r"][1] - END["r"][0]) * k ** 1.2
    lift = _ease(az, ph) - r * 0.45 + (r * 0.95 + CAP["band"]["h"] + END["lift"]) * np.clip(k * 1.6, 0.0, 1.0)
    # (lifted where it would go into the skin in any fit: behind the ear and the nape)
    used = BR.tube_clear_of_skin(g, lambda lf: D.scalp_path(g, c0, dirs, lf), lift, r, segs=12)
    P = D.scalp_path(g, c0, dirs, used)
    g.m.fa["part"][:] = 0
    g.uvparts = {0: ("cyl", HT.headb(fits), HT.headb(fits) + np.array([0.0, 0.0, 0.2]), [0, -1, 0])}
    g.shape_alias = {"sex_head": "m"}
    g.notes["end_tip_z"] = round(float(P[-1, 2]), 3)
    g.notes["scalp_clearance_mm"] = {kk: [round(v[0] * 1000, 1), round(v[1] * 1000, 1)] for kk, v in
                                     HT.scalp_clearance(fits, g.m.V).items()}


build_and_export = G.runner(SPEC, build)
