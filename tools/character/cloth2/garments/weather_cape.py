"""The weather cape (cloth2, the Drift crews' set): a short cape of tarred canvas to the elbow, a standing collar
closed with a hemp toggle, patched with pieces of old Drift sailcloth sewn on with tarred twine. The patches still
hold a little light in the Drift (a quarter of a glow cord's) and grey to dead stone over a season under our sky:
Rook's are grey all through Act 2 and come back in Act 3. Draped over the shoulders and the arms as one piece
(cloth2.drift.envelope), kept short so a raised arm does not come through it."""

import numpy as np

from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import recipes
from cloth2 import trims as TR
from cloth2.mesh import REF, unit
from cloth2.spec import Glow, Spec, Zone

UNDER = ["shirt_check", "waistcoat_long", "sea_jacket", "shirt_linen"]
SPEC = Spec(
    id="weather_cape", name="Weather cape", set="drift", slot="accessories.wrap", layer={"default": 50},
    description="A short cape of tarred canvas to the elbow with a standing collar and a hemp toggle, patched with "
                "pieces of old sailcloth that glow faintly.",
    history="The Drift's own gear, made from what a ship has: tarred canvas like a seaman's foul-weather clothes, "
            "patched with retired sails that sailed on light.",
    zones=[Zone(0, "tarred canvas", "cloth", "TWILL", ["tar_black", "slate_grey", "snuff"], "tar_black"),
           Zone(1, "toggle and loop", "trim", "TWILL", ["hemp", "horn", "tar_black"], "hemp"),
           Zone(3, "sailcloth patches", "trim", "LIN", ["sailcloth", "dead_stone", "linen_unbleached"], "sailcloth",
                glow=Glow(strength=0.25, pulse=0.05, life=1.0))],
    sources=[], evidence="C", tags=["drift", "sailor"], budget=3600, over=UNDER,
    extra={"presets": {"rook_act2": {"3": "dead_stone", "glow_life": 0.0}, "rook_act3": {"3": "sailcloth", "glow_life": 0.6}},
           "motion_note": "The 5 cm standing collar meets the jaw when the head bows to aim a long gun."})

HEM = (1.035, 1.05, 1.035)        # front, side, back (m)
PATCHES = [(28.0, 1.16, (0.032, 0.026), 6.0), (-58.0, 1.215, (0.026, 0.022), -9.0), (100.0, 1.20, (0.030, 0.035), 4.0),
           (160.0, 1.15, (0.040, 0.030), -5.0), (-140.0, 1.10, (0.030, 0.024), 12.0), (-100.0, 1.12, (0.028, 0.03), -3.0),
           (128.0, 1.255, (0.022, 0.020), 15.0)]


def build(g):
    from cloth2.garment import built
    fits = g.fits
    under = [built(fits, gid)[0] for gid in UNDER]
    hits = D.hit_bvhs(fits, arms=True, meshes=under)
    rows = D.cape_rows(z_c=1.19, phi=(24.0, 90.0), n_polar=9, z_rows=[1.16, 1.13, 1.10, 1.07, 1.04, 1.01])
    thetas = np.linspace(2.0, 358.0, 49)
    m, _ = D.envelope(g, rows, thetas, hits, 0.009, smooth=3, drape=0.006)
    g.m = m
    # the hem
    g.m = g.m.clip(g.P[:, 2] - recipes.hem_by_angle(*HEM)(g.P), 0.0)
    # the standing collar from the top row (5 cm, nearly upright)
    row = g.m.A["_row"].copy()
    tilt = np.radians(17.0)
    up = np.array([0.0, -np.sin(tilt), np.cos(tilt)])

    def disp(fit, P0, N0, s):
        inward = np.stack([-P0[:, 0], -P0[:, 1], np.zeros(len(P0))], 1)
        inward = inward / np.maximum(np.linalg.norm(inward, axis=1, keepdims=True), 1e-9)
        return (up[None] + inward * 0.02) * (0.05 * s)       # (6 cm leaning in met the jaw when the head turned)
    piece = TR.extrude(g.m, lambda P: row < 0.02, disp, rings=3, zone=0)
    D.drop_attrs(g.m)
    D.drop_attrs(piece)
    g.add(piece)
    g.fits.clear(g.m, 0.003)
    g.over(UNDER, 0.004)
    # the patches
    for a, z, half, spin in PATCHES:
        hit, ok = HW.toward_axis(g.m, z, [a])
        if ok[0]:
            D.patch(g, hit[0], half, 3, h=0.0014, spin=spin)
    # the toggle (left front of the collar) and its loop (right)
    for s, prim in ((1.0, HW.ellipsoid(0.017, 0.0055, 0.0055, segs=8, rings=4)), (-1.0, HW.ring(0.008, 0.0018, 10, 4))):
        hit, ok = HW.ray_points(g.m, [[s * 0.022, -0.4, 1.315]], [0.0, 1.0, 0.0], 0.6)
        if ok[0]:
            g.hardware(hit[:1], prim, 1, up=(0.0, 0.0, 1.0), lift=0.001)
    g.hem_below(1.08)
    g.uv(axis_top=1.45, axis_bottom=1.0, limbs=())


build_and_export = G.runner(SPEC, build)
