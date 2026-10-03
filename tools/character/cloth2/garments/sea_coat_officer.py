"""The sea officer's coat (cloth2: recipes.coat, the Drift crews' set): Captain Ithel's. A frock-cut coat with skirts
to just above the knee, the fronts cut away below the waist, turned-back lapels and a falling collar in the facing
colour, deep round cuffs, side pleats and a back vent; thirteen small bronze pins sewn in the hem (Vessary's "a heavy
man"); keel-thread cording on the lapels, the fronts, the hem and the cuffs, and the captain's line down the back."""

import numpy as np

from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.mesh import BIG_FIELD, smoothstep
from cloth2.spec import Glow, Spec, Zone

SPEC = Spec(
    id="sea_coat_officer", name="Sea officer's coat", set="drift", slot="outer", layer={"default": 40},
    description="A long dark coat with skirts to just above the knee, the fronts cut away below the waist, buff "
                "lapels, collar and deep cuffs, side pleats and a back vent; small bronze pins weight the hem, and "
                "a glowing cord runs along the lapels, the fronts, the hem, the cuffs and down the back seam.",
    history="Cut like a landsman's frock coat of the 1750s (falling collar, cut-away fronts, side pleats and a vent) "
            "with lapels and deep round cuffs in a facing colour. The colour is a logwood purple-black, not a navy "
            "blue: Ithel is a Drift captain, not a King's officer. In Vessary a rich man's hem is weighted with small "
            "bronze pins ('a heavy man'); the keel-thread cording is the Drift's own, and it fades as Ithel dies.",
    zones=[Zone(0, "coat", "cloth", "WOOL", ["logwood_plum", "madder_red", "kersey_blue", "tar_black", "snuff"],
                "logwood_plum"),
           Zone(1, "lapels, collar, cuffs and lining", "trim", "WOOL", ["buff", "madder_red", "linen_unbleached",
                                                                        "logwood_plum", "slate_grey"], "buff"),
           Zone(2, "buttons and hem pins", "button", "MET", ["brass", "pewter", "gold_lace"], "brass"),
           Zone(3, "keel-thread cording", "trim", "TWILL", ["keel_glow", "dead_stone", "buff"], "keel_glow",
                glow=Glow(strength=1.0, pulse=0.2, life=1.0))],
    sources=[], evidence="C", tags=["drift", "officer"], budget=9000,
    over=["shirt_linen", "breeches", "waistcoat_long", "shirt_check", "slops"],
    extra={"presets": {"ithel": {"0": "logwood_plum", "1": "buff", "2": "brass", "3": "keel_glow"},
                       "ithel_red_facings": {"0": "logwood_plum", "1": "madder_red", "2": "brass", "3": "keel_glow"},
                       "ithel_dying": {"3": "keel_glow", "glow_life": 0.2}},
           "hem_pins": 13, "story_note": "mission 11: the game fades zone 3's glow life with Ithel.",
           "budget_note": "9,000 (the coat's 8,000 plus the cording's cut lines and the pins)."})

OPEN = [(0.40, 0.17), (0.52, 0.16), (0.62, 0.14), (0.75, 0.115), (0.86, 0.08), (0.95, 0.052), (1.02, 0.042),
        (1.15, 0.038), (1.27, 0.040), (1.34, 0.055), (1.6, 0.08)]
STYLE = recipes.style(
    recipes.FROCK, hem=(0.55, 0.54, 0.53), opening=OPEN, vent=0.80,
    lapels={"z": (1.02, 1.27), "w": (0.050, 0.060), "h": 0.0024},
    collar=("fall", 0.05), cuffs={"t0": 0.62, "h": 0.006, "flare": 0.008}, cuff_buttons=3,
    front_buttons=None, pleats=[(120.0, 34.0, 2, 0.012)], steps=6,
    # (2026-10-03) the flaps 4.5 mm proud and ending before the side pleats: at 3 mm they read as dotted outlines
    pockets={"z": (0.865, 0.905), "a": (54.0, 90.0), "h": 0.0045, "buttons": 3, "on_flap": True},
    over=tuple(SPEC.over), over_gap=0.007)


def build(g):
    recipes.coat(g, STYLE)
    zh = getattr(g, "_hung_z", 0.905)
    # the cording: lapel and front edges, the hem, the cuff ends (the falling collar's edge stays plain)
    def cord(P):
        front = D.front_edge_select(g, 0.50, 1.33, tol=0.010)(P)
        hem = (P[:, 2] < 0.62) & (np.abs(P[:, 0]) < 0.32)
        cuff = np.abs(P[:, 0]) > 0.30
        return front | hem | cuff
    g.edge_zone(3, 0.006, select=cord)
    # the captain's line: down the centre back seam from the collar to the vent
    sel = g.select(lambda P: (np.abs(P[:, 0]) - 0.003) + BIG_FIELD * (1.0 - smoothstep(0.02, 0.05, P[:, 1])) +
                   BIG_FIELD * smoothstep(1.30, 1.31, P[:, 2]) + BIG_FIELD * (1.0 - smoothstep(0.79, 0.80, P[:, 2])))
    g.m.fa["zone"][sel] = 3
    # buttons on the lapels (six a side) and the thirteen hem pins
    zs = np.linspace(1.245, 1.045, 6)
    for s in (1.0, -1.0):
        x = np.array([s * (float(g.opening_w(z)) + 0.030) for z in zs])
        g.buttons(g.front_points(x, zs), 2, r=0.0075, segs=6)
    pins = np.concatenate([g.around_points(0.555, np.linspace(62.0, 172.0, 7)),
                           g.around_points(0.555, -np.linspace(66.0, 170.0, 6))])
    g.buttons(pins, 2, r=0.0032, h=0.0018, segs=5)
    g.uv()


build_and_export = G.runner(SPEC, build)
