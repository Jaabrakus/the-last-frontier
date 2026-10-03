"""Slops (cloth2, the Drift crews' set): a seaman's wide canvas breeches, straight and open at the knee, pleated into
a waistband, the hem tarred against the wet, a knee patch cut from old sailcloth."""

import numpy as np

from cloth2 import bridge as BR
from cloth2 import drift as D
from cloth2 import garment as G
from cloth2.mesh import BIG_FIELD, smoothstep
from cloth2.spec import Spec, Zone

TOP = 1.06            # the waistband's top (m); the band from 1.02
END = 0.565           # leg parameter of the hem: z ~0.40, just below the knee (0.468)
HEM_BAND = 0.055      # the tarred hem band, along the leg parameter (~4 cm)
CROTCH_DROP = 0.030   # the crotch cut low (2026-10-03: 1.5 cm lower than before; the thighs bound how far it can hang)
SEAT_EASE = 0.013     # more room across the seat: they hang loose behind

SPEC = Spec(
    id="slops", name="Slops", set="drift", slot="legs.lower", layer={"default": 30},
    description="Wide canvas breeches open at the knee, pleated into a waistband with a fly front, the hem band "
                "tarred, a patch of old sailcloth on the left knee.",
    history="Slops were the seaman's own breeches: loose, straight-cut, of canvas or old sailcloth, pleated into a "
            "waistband and ending just below the knee, open there, worn by no other trade; wider 'petticoat "
            "breeches' were older and rarer [D1][D2]. Joseph Haycock's slop shop in 1699 sold them among its "
            "breeches [D2]. The Drift crews tar the hems and patch the knees with retired sails.",
    zones=[Zone(0, "canvas", "cloth", "TWILL", ["linen_unbleached", "sailcloth", "tar_black", "slate_grey", "tow"],
                "linen_unbleached"),
           Zone(1, "waistband and tarred hem", "trim", "TWILL", ["tar_black", "linen_unbleached", "slate_grey"],
                "tar_black"),
           Zone(2, "knee patch", "trim", "LIN", ["sailcloth", "linen_white", "dead_stone", "tow"], "sailcloth"),
           Zone(3, "buttons", "button", "MET", ["horn", "brass", "pewter", "leather_black"], "horn")],
    hides_force=["pelvis_center", "pelvis_side", "abdomen_front", "abdomen_side", "abdomen_back", "thigh_upper_l",
                 "thigh_upper_r"],
    sources=["D1", "D2"], evidence="B", tags=["drift", "sailor"], budget=4200, over=["shirt_check"],
    extra={"presets": {"deckhand": {"0": "linen_unbleached", "1": "tar_black", "2": "sailcloth"},
                       "rook_tarred": {"0": "tar_black", "1": "tar_black", "2": "dead_stone"}},
           "fit_note": "The crotch hangs low and the seat is loose (2026-10-03); it is bridged (cloth2.bridge."
                       "crotch_bridge): taut in the female fits, a straight seam from the fly to the inseam (no "
                       "camel-toe), and in the male fit the female crotch moved, lying smoothly over the genitals, which "
                       "every legs garment hides; the clearance check counts those vertices (over the genitals' hole in "
                       "the measured skin) as inside, male fit only, all over pelvis_center genital faces.",
           "references": ["[D1] HMS Richmond, Sailor's Dress of 1775: https://hmsrichmond.org/sailordress.htm",
                          "[D2] Reconstructing History, Breeches for Seamen (Haycock's 1699 slop shop inventory): "
                          "https://reconstructinghistory.com/breeches-for-seamen/"]})


def build(g):
    g.shell(["abdomen_front", "abdomen_side", "abdomen_back", "pelvis_center", "pelvis_side",
             "thigh_upper_l", "thigh_lower_l", "thigh_upper_r", "thigh_lower_r", "shin_upper_l", "shin_upper_r"])
    g.top(TOP).legs(end=END, ease=(0.016, 0.022), gather=0.0)
    g.seams(back=True, limbs=())
    g.crotch(drop=CROTCH_DROP, width=0.075)
    g.fit(ease=0.016, gap=0.003)
    # ease across the seat (behind, from the small of the back to below the buttocks; not between the legs)
    P = g.P
    seat = smoothstep(0.0, 0.07, P[:, 1]) * smoothstep(0.74, 0.82, P[:, 2]) * (1.0 - smoothstep(0.96, 1.02, P[:, 2])) * \
        (1.0 - smoothstep(0.13, 0.19, np.abs(P[:, 0])))
    g.m.offset(SEAT_EASE * seat, vertical=0.3)
    g.m.smooth(2, 0.5, weights=np.minimum(1.0, seat * 2.0))
    g.fits.clear(g.m, 0.003)
    # wide legs: the ease rises to ~7 cm at the hem (the inner side kept off the other leg)
    D.flare_legs(g, lambda t: 0.050 * smoothstep(0.18, END, t) ** 0.8, t0=0.12, keep=0.012)
    g.m.smooth(4, 0.4)
    # the seat and the crotch hang as one low seam: smoothed hard there (no shape of the body's own between the legs)
    P = g.P
    w = np.exp(-(P[:, 0] / 0.07) ** 2) * np.exp(-((P[:, 2] - 0.79) / 0.08) ** 2)
    for _ in range(4):
        g.m.smooth(6, 0.5, weights=w)
        g.fits.clear(g.m, 0.003)
    g.over(SPEC.over, 0.004, where=lambda P: P[:, 2] > 0.90)      # (the shirt ends at 0.885: nothing to clear below)
    # the crotch bridged: taut in the female fits (a straight seam, no camel-toe), the male fit's front the female one
    # moved (its genitals parted the folded cloth sideways: a slit and a pouch). After over(), whose last skin
    # clearance would crumple it again round the genitals' hole in the skin
    BR.fill_holes(g, lambda P: (np.abs(P[:, 0]) < 0.06) & (P[:, 2] > 0.62) & (P[:, 2] < 0.86), max_edges=24)
    BR.crotch_bridge(g, window=BR.crotch_window(z_lo=(0.58, 0.64)),
                     male_window=lambda P: (1.0 - smoothstep(0.022, 0.048, np.abs(P[:, 0]))) *
                     smoothstep(0.0, -0.025, P[:, 1]) * smoothstep(0.64, 0.68, P[:, 2]) *
                     (1.0 - smoothstep(0.80, 0.85, P[:, 2])))
    # the waistband and the tarred hem band
    g.zone(1, above=1.02)
    g.zone(1, limb=("leg_l", "leg_r"), t_above=END - HEM_BAND)
    g.raised(lambda P: (1.02 - P[:, 2]) * 3.0, 0.0022, 1)
    # the knee patch: old sailcloth over the left knee, a little askew
    J = g.fits.J
    D.patch(g, J["l_knee"] + np.array([0.004, -0.09, 0.03]), (0.035, 0.03), 2, h=0.0014, spin=8.0)
    g.hem_below(0.46)
    # the fly: two horn buttons at the waistband's front
    P = g.front_points(np.array([-0.012, -0.012]), np.array([1.045, 1.03]) - 0.005)
    g.buttons(P, 3, r=0.0065, h=0.0028)
    g.uv(axis_top=1.07, axis_bottom=0.75, limbs=("leg_l", "leg_r"))


build_and_export = G.runner(SPEC, build)
