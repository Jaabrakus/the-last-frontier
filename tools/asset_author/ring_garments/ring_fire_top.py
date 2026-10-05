"""The fire side's top (cloth2 dress.tunic, sleeveless): a fitted sleeveless tunic to the hip, a high standing collar
in gold, a structured shoulder line (stiffened shoulder caps raised over each shoulder to the armhole), a gold placket
slanting from the collar to the right hip, gold piping round the armholes and the hem, side slits. Worn over the
fitted trousers, under the sash; the arms bare for the wrist guards."""

import numpy as np

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import trims as TR
from cloth2.mesh import BIG_FIELD, smoothstep
from cloth2.spec import Spec, Zone

from ring_garments import _common as C

PAL = ["ring_flame", "ring_ember", "ring_char", "ring_gold"]
UNDER = ["ring_trousers_fitted"]
HEM = 0.80

SPEC = Spec(
    id="ring_fire_top", name="Fire side top", set=C.SET, slot="shirt", layer={"default": 36},
    description="A fitted sleeveless tunic to the hip with a high gold standing collar, stiffened shoulder caps, a "
                "gold placket slanting to the right hip and gold piping at the armholes and hem.",
    history=C.HISTORY,
    zones=[Zone(0, "tunic", "cloth", "TWILL", PAL, "ring_flame"),
           Zone(1, "gold collar, placket and piping", "trim", "FLAT", PAL, "ring_gold"),
           Zone(2, "shoulder caps", "leather", "LEA", PAL, "ring_ember")],
    evidence="C", tags=C.tags("fire"), budget=8000, over=UNDER,
    extra={"presets": {"fire": {"0": "ring_flame", "1": "ring_gold", "2": "ring_ember"}},
           "recipe_note": "dress.tunic without sleeves (round armholes), hem 0.80 with side slits to 0.88, a 4.2 cm "
                          "stand collar, raised shoulder caps, a slanting placket."})

STYLE = dress._style(dress.TUNIC, {"neck": {"a": 0.084, "b": 0.076, "z0": 1.335, "tilt": 17.0}, "slit": None,
                                   "ease": 0.0075, "sleeves": None,
                                   "armholes": {"size": (0.064, 0.074, 0.105), "centre": (0.010, 0.004, -0.045),
                                                "t_cut": 0.10},
                                   "hem": HEM, "side_hem": HEM + 0.01, "flare": 0.05, "folds": 0.003, "steps": 6,
                                   "slits": [(80.0, 100.0, 0.88)], "closed": False,
                                   "over": tuple(UNDER), "over_gap": 0.006,
                                   "trim": {"neck": 0.0, "slit": 0.0, "cuff": 0.0}})


def _placket_x(z):
    # from the collar's left front down to the right hip (the wearer's right: -x)
    return 0.035 - 0.11 * np.clip((1.30 - z) / 0.40, 0.0, 1.0)


def _collar(g, height, zone, rings=2):
    """A standing collar grown straight up from the neckline only (Garment.stand_collar takes every open edge above the
    neck's foot, and on a sleeveless top that is the armholes' tops too: they grew points at the shoulders)."""
    a, b, z0, tilt, yc, dip, dip_width = g._neck
    th = np.radians(tilt)
    up = np.array([0.0, -np.sin(th), np.cos(th)])

    def disp(fit, P0, N0, s):
        return np.broadcast_to(up * (height * s), P0.shape).copy()
    piece = TR.extrude(g.m, lambda P: (P[:, 2] > z0 - 0.09) & (np.hypot(P[:, 0], P[:, 1] - yc) < a + 0.035), disp,
                       rings=rings, zone=zone)
    if piece is not None:
        g.add(piece)


def build(g):
    recipes.tunic(g, STYLE)
    # the shoulder line: a stiffened cap over each shoulder from the collar's side to the armhole
    def caps(P):
        return np.maximum(1.255 - P[:, 2], 0.075 - np.abs(P[:, 0])) * 4.0
    g.raised(caps, 0.0045, 2)
    # the slanting placket (front only)
    g.raised(lambda P: np.abs(P[:, 0] - _placket_x(P[:, 2])) - 0.011 + BIG_FIELD * smoothstep(-0.03, 0.0, P[:, 1]) +
             BIG_FIELD * smoothstep(1.30, 1.32, P[:, 2]), 0.0025, 1)
    # gold piping round the armholes and the hem (the boundaries below the collar)
    a, yc = g._neck[0], g._neck[4]
    g.edge_zone(1, 0.010, select=lambda P: (P[:, 2] < 1.27) | (np.hypot(P[:, 0], P[:, 1] - yc) > a + 0.035), h=0.0018)
    _collar(g, 0.042, 1)
    # (the collar's foot at the throat and the caps' back edges over the shoulder blades sat a few mm in the skin)
    g.fits.clear(g.m, 0.003)
    g.hem_below(HEM + 0.10)
    g.uv()
    dress.arc_uv(g)


build_and_export = G.runner(SPEC, build)
