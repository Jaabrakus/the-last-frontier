"""The mote belt (cloth2, the Drift crews' set): a broad leather hip belt worn slanting, low on the left hip, with six
small square brass cells set apart on it, like little snuff boxes or the compartments of a belly box, each with a round
lantern-glass window facing out. A lit cell holds a mote (3 on Earth, up to 6 in the Drift); the others show dead
stone. It puts the HUD's mote count on the body: in a duel you can read a caster's motes.

2026-10-03: ten round-ended brass cylinders read at 3 m as a 19th- or 20th-century cartridge belt; six flat square
cells with round windows, leather between them, on a wider belt, set forward of the swinging arm."""

import numpy as np

from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2.mesh import BIG_FIELD, REF, smoothstep
from cloth2.spec import Glow, Spec, Zone

Z_RIGHT, Z_LEFT, HALF = 0.955, 0.878, 0.027          # the belt's centre line on the right and left hips, half width
CELLS = 6
CELL_ANGLES = np.linspace(18.0, 100.0, CELLS)         # degrees round from the front toward the left hip (the arm
                                                      # swings behind the last)
CELL_SIZE = (0.0175, 0.015, 0.006)                    # half sizes: 3.5 x 3 x 1.2 cm, square-cornered
LID = (0.0160, 0.0135, 0.0007)                        # the lid's step on top
WINDOW_R = 0.0092                                     # the round window (and its bezel round it)

SPEC = Spec(
    id="mote_belt", name="Mote belt", set="drift", slot="accessories.waist", layer={"default": 60},
    description="A broad leather hip belt worn slanting low on the left, a brass buckle, and six small square brass "
                "cells set apart on it, each with a round glass window that glows when it holds a mote.",
    history="The Drift's own gear. The cells are cut like small brass snuff boxes or the compartments of the belly "
            "boxes soldiers and hunters wore at the front of a belt, flat and square-cornered, with round "
            "lantern-glass windows; leather shows between them.",
    zones=[Zone(0, "belt", "leather", "LEA", ["leather_brown", "leather_black", "tar_black"], "leather_brown"),
           Zone(2, "brass cells and buckle", "metal", "MET", ["brass", "pewter"], "brass", metal=True),
           Zone(3, "cell windows", "trim", "FLAT", ["keel_glow", "dead_stone", "lens_glass"], "keel_glow",
                glow=Glow(strength=1.0, pulse=0.3, life=1.0))],
    sources=[], evidence="C", tags=["drift", "caster"], budget=2400,
    over=["shirt_check", "slops", "waistcoat_long", "shirt_linen", "breeches"],
    extra={"cells": {"count": CELLS, "index": "floor(UV.x) of the window faces (zone 3): 0 at the front, 5 at the "
                                              "left hip", "lit_default": {"earth": 3, "drift": 6},
                     "unlit": "dead_stone"},
           "presets": {"rook_earth": {"lit": 3}, "drift": {"lit": 6}},
           "motion_note": "The cells sit forward of the swinging left arm (18-100 degrees round from the front) and "
                          "stand 1.3 cm off the belt; in a deep crouch the raised left thigh covers the front cells (as "
                          "it does every skirt)."})


def zc(P):
    """The belt's centre height at the points P: a plane leaning down to the left hip."""
    return (Z_RIGHT + Z_LEFT) / 2.0 + (Z_LEFT - Z_RIGHT) / 2.0 * np.clip(P[:, 0] / 0.17, -1.4, 1.4)


def build(g):
    g.shell(G.TORSO)
    P = g.P
    g.m = g.m.clip(HALF - np.abs(P[:, 2] - zc(P)), 0.0)
    g.m.offset(0.016, vertical=0.0)
    g.m.smooth(2, 0.5)
    g.fits.clear(g.m, 0.003)
    g.over(SPEC.over, 0.004)
    # the buckle at the front
    p0 = g.front_points([0.0], [float(zc(np.array([[0.0, 0.0, 0.0]]))[0])])
    g.hardware(p0, HW.frame(0.048, 0.050, 0.0055, 0.0035), 2, lift=0.0005)
    # the cells: each a flat square brass box with a lid's step and a round window in a bezel facing out (its own UV
    # part: the index the shader lights), leather showing between them
    centres, udirs, vdirs = [], [], []
    hz2 = 2 * CELL_SIZE[2]
    for i, a in enumerate(CELL_ANGLES):
        th = np.radians(a)
        z = float(zc(np.array([[np.sin(th) * 0.17, 0.0, 0.0]]))[0])
        hit, ok = HW.toward_axis(g.m, z, [a])
        if not ok[0]:
            continue
        b = HW.Binding(g.m, hit[:1])
        g.add(HW.rigid(g.m, b, HW.box(*CELL_SIZE), 2, part=9, lift=0.0005))
        g.add(HW.rigid(g.m, b, HW.box(*LID, z0=hz2), 2, part=9, lift=0.0005))
        g.add(HW.rigid(g.m, b, HW.ring(WINDOW_R + 0.0011, 0.0011, 16, 4, z0=hz2 + 2 * LID[2]), 2, part=9, lift=0.0005))
        p, n = b.at(g.m, REF)
        R = HW.frames(n, [0.0, 0.0, 1.0])[0]
        out = p[0] + n[0] * (0.0005 + hz2 + 2 * LID[2])
        win = HW.Binding(g.m, hit[:1])
        g.add(HW.rigid(g.m, win, HW.translate(HW.disc(WINDOW_R, 0.0014, segs=16), (0.0, 0.0, hz2 + 2 * LID[2])), 3,
                       part=20 + i, lift=0.0005))
        centres.append(out)
        udirs.append(R[:, 0])
        vdirs.append(R[:, 1])
    g.uv(axis_top=1.0, axis_bottom=0.85, limbs=())
    D.indexed_parts(g, 20, len(centres), centres, udirs, vdirs)


build_and_export = G.runner(SPEC, build)
