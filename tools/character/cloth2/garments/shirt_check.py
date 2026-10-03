"""The seaman's check shirt (cloth2, the Drift crews' set): a linen shirt of blue-and-white check, cut short and
tucked in (no hanging tails: it lies inside the slops or breeches), bloused a little over the waistband, the neck slit
left open under a narrow band collar, wrist bands."""

import numpy as np

from cloth2 import drift as D
from cloth2 import garment as G
from cloth2.mesh import smoothstep
from cloth2.spec import Spec, Zone

CHECK = {"options": ["none", "check"], "default": "check",
         "check": {"colors": ["check_blue", "linen_white"], "scale_m": 0.012}}

SPEC = Spec(
    id="shirt_check", name="Check shirt", set="drift", slot="shirt", layer={"default": 10},
    description="A seaman's shirt of checked linen, tucked into the slops, the neck slit open under a narrow collar "
                "band, full sleeves gathered into wrist bands.",
    history="Checked linen shirts were the seaman's working shirt through the century; plain white, grey or red "
            "shirts appear too [D1]. Cut like any linen shirt of the 1750s (body and sleeves of rectangles, the neck "
            "slit and a narrow band); the Drift crews' are mended and faded, nothing new. Rook's is coarse tow.",
    zones=[Zone(0, "check linen", "cloth", "LIN", ["check_blue", "linen_white", "linen_unbleached", "tow", "madder_red",
                                                  "slate_grey"], "check_blue", pattern=CHECK),
           Zone(1, "collar and wrist bands", "trim", "LIN", ["linen_white", "linen_unbleached", "tow", "check_blue"],
                "linen_white")],
    sources=["D1"], evidence="B", tags=["drift", "sailor"], budget=6200,
    extra={"presets": {"deckhand": {"0": "check_blue", "1": "linen_white"},
                       "rook_tow": {"0": "tow", "1": "linen_unbleached", "pattern": "check",
                                    "check": ["tow", "linen_unbleached"]},
                       "ithel_plain": {"0": "linen_white", "1": "linen_white", "pattern": "none"}},
           "ithel_note": "Captain Ithel wears it plain (fine white linen, no check) under the waistcoat and the sea "
                         "officer's coat: its cut-away fronts showed the linen shirt's hanging tails as a white skirt.",
           "pattern_note": "zone 0 pattern 'check' (1.2 cm, check_blue on linen_white) is stored for the cloth shader; "
                           "until it draws patterns the zone renders as its colour.",
           "references": ["[D1] HMS Richmond, Sailor's Dress of 1775: https://hmsrichmond.org/sailordress.htm"],
           "tucked_note": "No hanging tails: the shirt ends inside the slops / breeches waistband, so it is worn under "
                          "either (a shirt with tails would come through the breeches' thighs)."})

BLOUSE = (1.075, 0.040, 0.0045)      # the blousing over the waistband: centre height, half-height, extra ease (m)


def build(g):
    g.shell(G.TORSO + G.ARMS)
    g.neckline(a=0.080, b=0.070, z0=1.325, dip=0.012)
    g.bottom(0.885)
    g.sleeves(end=0.925, ease=(0.006, 0.014), gather=0.009)
    g.seams()
    g.fit(ease=G.LAYER_EASE["base"])
    # bloused over the waistband: a little more room in a band above it, all round (not on the sleeves)
    P = g.P
    arm = np.maximum(g.m.A["m_arm_l"], g.m.A["m_arm_r"])
    zc, hz, e = BLOUSE
    w = np.exp(-((P[:, 2] - zc) / hz) ** 2) * (1.0 - arm) * smoothstep(0.86, 0.95, P[:, 2])
    g.m.offset(e * w, vertical=0.2)
    g.m.smooth(2, 0.4)
    g.fits.clear(g.m, 0.002)
    # the neck slit, left open: 8 cm down the front
    D.clip_front_slit(g, 1.20, 1.33, 0.0015, 0.014)
    g.collar_zone(1, 0.032)
    D.wrist_band_zone(g, 1, 0.026)          # (square to the forearm: the limb parameter's border zigzagged)
    g.hem_below(0.95)
    g.uv()


build_and_export = G.runner(SPEC, build)
