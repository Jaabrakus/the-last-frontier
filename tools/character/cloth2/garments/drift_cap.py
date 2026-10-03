"""The drift cap (cloth2, the Drift crews' set; recipes.soft_cap's cap with a crown of its own): a felted knit cap of
the Monmouth kind, a deep rounded crown, a ribbed turned-up band and a long soft knitted tail lying down the back-left,
ending in a brass-capped tassel round a keelstone bead. In the Drift the bead lifts and the tail streams with the
current (every cap on deck the same way, like the telltales on a sail); on Earth the bead is dead stone and the tail
lies down the back of the head.

2026-10-03: the flat-topped red cap with a short tassel read as a fez: the crown is domed and deep now (no flat top),
the band ribbed, the tail longer (about 0.24 m) and softer, and the default a sea grey (red is one option); the bead is dead stone
unless a costume lights it (one glow per costume)."""

import math

import numpy as np

from cloth2 import bridge as BR
from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import hats as HT
from cloth2.parts import angle_from_front
from cloth2.spec import Glow, Spec, Zone

SPEC = Spec(
    id="drift_cap", name="Drift cap", set="drift", slot="head", layer={"default": 80},
    description="A felted knit cap with a turned-up band and a long knitted tail ending in a brass-capped tassel round "
                "a glowing stone bead.",
    history="Knitted Monmouth caps and stocking caps were the seaman's caps from the 1600s on, close-fitting, some "
            "with a turned-up band, some long like a stocking [D1][D2]. The Drift crews knit the tail long and weight "
            "it with a keelstone bead, so it shows the current.",
    zones=[Zone(0, "knit", "cloth", "KNIT", ["slate_grey", "indigo_mid", "tow", "madder_red", "walnut_brown"],
                "slate_grey"),
           Zone(1, "band", "band", "KNIT", ["slate_grey", "indigo_mid", "tow", "madder_red", "walnut_brown"],
                "slate_grey"),
           Zone(2, "brass cap", "metal", "MET", ["brass", "pewter"], "brass", metal=True),
           Zone(3, "keelstone bead", "trim", "FLAT", ["dead_stone", "keel_glow"], "dead_stone",
                glow=Glow(strength=1.2, pulse=0.25, life=1.0))],
    hides_hair_zones=["crown"], sources=["D1", "D2"], evidence="B", tags=["drift", "sailor"], budget=2000,
    extra={"presets": {"deckhand": {"0": "slate_grey", "1": "slate_grey", "3": "dead_stone"},
                       "indigo": {"0": "indigo_mid", "1": "indigo_mid", "3": "dead_stone"},
                       "tow": {"0": "tow", "1": "tow", "3": "dead_stone"},
                       "red": {"0": "madder_red", "1": "madder_red", "3": "dead_stone"},
                       "lit": {"3": "keel_glow"},
                       "on_earth": {"3": "dead_stone", "glow_life": 0.0}},
           "glow_note": "The bead is dead stone by default (one glow per costume: a caster's is the mote belt, a watch "
                        "crew's the night-watch cord); the 'lit' preset lights it.",
           "tail_note": "The tail is rigid on headb; the Drift's lift (the bead rising, the tail streaming) is a runtime "
                        "driver not built yet (the hair queue's pendulum is the model).",
           "references": ["[D1] HMS Richmond, Sailor's Dress of 1775: https://hmsrichmond.org/sailordress.htm",
                          "[D2] Reconstructing History, Breeches for Seamen (on the slop trade): "
                          "https://reconstructinghistory.com/breeches-for-seamen/"]})

CAP = {"edge": (68.0, 84.0, 88.0), "ease": 0.012, "band": {"width": 0.045, "front_deg": 181.0}}
CROWN = (0.020, 1.5)            # the crown's extra depth (m) at the top, falling off as cos(polar)^p: a dome, no flat top
RIBS, RIB_H, BAND_H = 24, 0.0013, 0.0045    # the turned-up band: knit ribs round it, standing BAND_H +- RIB_H proud
SEGS = 48
# (the tail runs from behind the crown to the nape, about 0.24 m: rigid on the head, a longer one would swing into the
# neck and the collar as the head turns; the Drift's live tail driver is the place for more)
TAIL_AZ = 152.0                 # the tail falls toward the back-left (degrees round from the front)
TAIL_R = (0.0170, 0.0095)       # soft and full at the root, thinning to the tassel


def _ease(th, ph):
    return CAP["ease"] + CROWN[0] * np.cos(np.clip(ph, 0.0, np.pi / 2)) ** CROWN[1]


def _cap(g):
    """recipes.soft_cap's Monmouth cap with a domed crown (its ease rising to the top) and a ribbed band."""
    fr, sd, bk = [np.radians(a) for a in CAP["edge"]]

    def phi_max(th):
        c = np.cos(th)
        return np.where(c > 0, sd + (fr - sd) * c, sd + (bk - sd) * (-c))
    m, ids, TH, PH = HT.head_grid(g.fits, segs=SEGS, rows=11, phi_max=phi_max, ease=_ease)
    g.m = m
    c0 = HT.headb(g.fits) + np.array([0.0, -0.035, 0.075])
    bd = CAP["band"]

    def band_h(P):
        q = P - c0
        th = np.arctan2(q[:, 0], -q[:, 1])
        return BAND_H + RIB_H * np.cos(RIBS * th)
    g.edge_zone(1, bd["width"], h=band_h,
                select=lambda P: angle_from_front(P - np.array([0.0, c0[1], 0.0])) < bd["front_deg"])
    return g


def build(g):
    _cap(g)
    fits = g.fits
    c = HT.headb(fits) + np.array([0.0, -0.035, 0.075])
    az = math.radians(TAIL_AZ)
    # the tail's line from behind the crown (sunk into the cap there, so it is no crest seen from the front) down past
    # its back edge and on over the back of the head, a little off the hair (rigid on the head: it lies, it does not
    # hang)
    ph = np.radians(np.linspace(26.0, 128.0, 20))
    dirs = np.stack([np.sin(ph) * math.sin(az), -np.sin(ph) * math.cos(az), np.cos(ph)], 1)
    k = np.linspace(0.0, 1.0, len(ph))
    r = TAIL_R[0] + (TAIL_R[1] - TAIL_R[0]) * k ** 0.8
    from cloth2.mesh import smoothstep
    phd = np.degrees(ph)
    lift = _ease(0.0, ph) + r * (-0.55 + 1.35 * smoothstep(34.0, 80.0, phd)) + 0.010 * smoothstep(72.0, 96.0, phd) + \
        0.014 * smoothstep(96.0, 132.0, phd)                  # (over the hair below the cap, then off the nape)
    lift = np.maximum(lift, r + 0.0025)                    # (the root inside the cap, never in the scalp)
    # (lifted where it would go into the skin in any fit: down the nape the male fit's neck is thicker)
    used = BR.tube_clear_of_skin(g, lambda lf: D.scalp_path(g, c, dirs, lf), lift, r, segs=10)
    P = D.scalp_path(g, c, dirs, used)
    s = np.linalg.norm(np.diff(P, axis=0), axis=1).sum()
    g.notes["tail_m"] = round(float(s), 3)
    # the end: a brass cap, the bead, the tassel
    end, tan = P[-1], P[-1] - P[-2]
    tan = tan / np.linalg.norm(tan)
    # (the tassel hangs a little out from the nape: along the tail it went into the male fit's neck)
    out = end - c
    out = out / np.linalg.norm(out)
    tan = tan + 0.7 * out
    tan = tan / np.linalg.norm(tan)
    D.head_rigid(g, HW.lathe([(0.011, 0.0), (0.0095, 0.006), (0.0068, 0.010), (0.0, 0.011)], segs=10),
                 end - tan * 0.004, tan, 2)
    D.head_rigid(g, HW.ellipsoid(0.0068, 0.0068, 0.0068, segs=10, rings=6, z0=0.0), end + tan * 0.0135, tan, 3)
    D.head_rigid(g, HW.lathe([(0.0035, 0.0), (0.0068, 0.012), (0.0100, 0.030), (0.0, 0.032)], segs=10),
                 end + tan * 0.019, tan, 0)
    g.uvparts = {0: ("cyl", HT.headb(fits), HT.headb(fits) + np.array([0.0, 0.0, 0.2]), [0, -1, 0]),
                 6: ("planar", end, [1.0, 0.0, 0.0], [0.0, 0.0, 1.0])}
    g.m.fa["part"][g.m.fa["part"] < 5] = 0
    g.shape_alias = {"sex_head": "m"}
    g.notes["scalp_clearance_mm"] = {kk: [round(v[0] * 1000, 1), round(v[1] * 1000, 1)] for kk, v in
                                     HT.scalp_clearance(fits, g.m.V).items()}


build_and_export = G.runner(SPEC, build)
