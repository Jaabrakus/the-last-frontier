"""The sea jacket (cloth2: recipes.jacket, the Drift crews' set): a short double-breasted kersey jacket with no
skirts, worn open, a low standing collar, slit cuffs; the night-watch cord (a keel-thread glow cord) along the front
edges, the collar and the cuff slits, so a crew can see each other aloft in the dark."""

import numpy as np

from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Glow, Spec, Zone

SPEC = Spec(
    id="sea_jacket", name="Sea jacket", set="drift", slot="outer", layer={"default": 40},
    description="A short double-breasted kersey jacket worn open, two rows of brass buttons, a low standing collar and "
                "slit cuffs; a thin glowing cord along the fronts, the collar and the cuff slits.",
    history="The short jacket was the seaman's mark ashore and afloat: grey earlier in the century, blue or brown "
            "later, waist- or hip-length, single- or double-breasted, with or without a collar [D1]. The Drift crews "
            "sew a cord spun with keelstone along the edges (the night-watch cord): it glows like a banked coal in "
            "the Drift and greys under our sky within a season.",
    zones=[Zone(0, "kersey", "cloth", "WOOL", ["kersey_blue", "slate_grey", "snuff", "walnut_brown", "tar_black"],
                "kersey_blue"),
           Zone(1, "collar and cuffs", "trim", "WOOL", ["kersey_blue", "slate_grey", "snuff", "tar_black", "madder_red"],
                "kersey_blue"),
           Zone(2, "buttons", "button", "MET", ["brass", "pewter", "horn"], "brass"),
           Zone(3, "night-watch cord", "trim", "TWILL", ["keel_glow", "dead_stone", "hemp"], "keel_glow",
                glow=Glow(strength=1.0, pulse=0.15, life=1.0))],
    sources=["D1"], evidence="B", tags=["drift", "sailor"], budget=7000,
    over=["shirt_check", "slops", "waistcoat_long", "shirt_linen", "breeches"],
    extra={"presets": {"gunner": {"0": "kersey_blue", "1": "kersey_blue", "2": "brass", "3": "keel_glow"},
                       "grey_watch": {"0": "slate_grey", "1": "slate_grey", "2": "pewter", "3": "keel_glow"},
                       "spent_on_earth": {"3": "dead_stone", "glow_life": 0.0}},
           "references": ["[D1] HMS Richmond, Sailor's Dress of 1775: https://hmsrichmond.org/sailordress.htm"],
           "glow_note": "zone 3 is the night-watch cord (spec glow): the cloth shader does not draw glow yet."})

OPEN = [(0.80, 0.036), (0.86, 0.034), (1.00, 0.033), (1.20, 0.033), (1.27, 0.036), (1.32, 0.045), (1.40, 0.07),
        (1.6, 0.09)]
STYLE = recipes.style(
    recipes.JACKET, neck={"a": 0.091, "b": 0.083, "z0": 1.335, "tilt": 17.0}, sleeve_end=0.93,
    cuffs={"t0": 0.785, "h": 0.0045}, opening=OPEN, front_buttons=None, collar=None,
    over=tuple(SPEC.over), over_gap=0.007)
BUTTONS = {"n": 6, "x": 0.066, "z": (1.205, 0.925)}


def build(g):
    recipes.jacket(g, STYLE)
    D.cuff_slit(g, length=0.07, around=110.0, half=0.003)
    D.stand_collar(g, height=0.03, lean=0.22, zone=1, front=D.front_edge_select(g, 0.85, 1.40, tol=0.006))
    # the night-watch cord: the front edges, the collar's edges, the cuff ends and slits
    nz = 1.28

    def cord(P):
        rho, t = g._neck_coords(P)
        front = D.front_edge_select(g, 0.875, 1.36)(P)
        collar = (P[:, 2] > 1.29) & (rho < 1.6)
        cuff = np.abs(P[:, 0]) > 0.30
        return front | collar | cuff
    g.edge_zone(3, 0.006, select=cord)
    # two rows of buttons (double-breasted, worn open)
    zs = np.linspace(BUTTONS["z"][0], BUTTONS["z"][1], BUTTONS["n"])
    for s in (1.0, -1.0):
        g.buttons(g.front_points(np.full(len(zs), s * BUTTONS["x"]), zs), 2, r=0.0085)
    g.hem_below(0.90)
    g.uv()


build_and_export = G.runner(SPEC, build)
