"""The sail cloak (cloth2, the Drift crews' set): Captain Ithel's. A full-length cloak cut from a retired topsail,
over the shoulders and hanging behind the arms; the sail's bolt-rope kept as its hem and front edges, a reef band
across the back with short reef points; five battens fanning from the shoulder blades to the hem like a furled sail's
ribs (echoing the galleon's keel-fins), each with a keel-thread cord; a deep collar of drift-frost fur. Draped over the
coat (cloth2.drift.envelope)."""

import numpy as np

from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import trims as TR
from cloth2.mesh import REF, smoothstep, unit
from cloth2.parts import angle_from_front
from cloth2.spec import Glow, Spec, Zone

UNDER = ["sea_coat_officer", "waistcoat_long", "shirt_check", "shirt_linen", "breeches"]
SPEC = Spec(
    id="sail_cloak", name="Sail cloak", set="drift", slot="accessories.wrap", layer={"default": 50},
    description="A long cloak of old sailcloth over the shoulders and behind the arms, a rope-bound hem and front "
                "edges, a reef band with short ties, five battens fanning down the back, each with a glowing cord, "
                "and a deep fur collar.",
    history="The Drift's own: a captain's cloak cut from a topsail that sailed on light. Built from ship's things "
            "(sailcloth, bolt-rope, reef points, battens); the fur is the drift-frost of a Drift animal.",
    zones=[Zone(0, "sailcloth", "cloth", "TWILL", ["sailcloth", "tar_black", "slate_grey", "linen_unbleached"], "sailcloth"),
           Zone(1, "bolt-rope and reef points", "trim", "TWILL", ["hemp", "tar_black", "linen_unbleached"], "hemp"),
           Zone(2, "fur collar", "fur", "FUR", ["drift_frost", "fur_wolf", "fur_black_bear"], "drift_frost"),
           Zone(3, "battens' keel-thread", "trim", "TWILL", ["keel_glow", "dead_stone", "hemp"], "keel_glow",
                glow=Glow(strength=1.0, pulse=0.2, life=1.0))],
    sources=[], evidence="C", tags=["drift", "officer"], budget=6500, over=UNDER,
    extra={"glow_note": "One glow per costume (2026-10-03): Captain Ithel's is his coat's cording, so his cloak's battens "
                        "are dead hemp in his preset; 'lit' lights them.",
           "presets": {"ithel": {"0": "sailcloth", "1": "hemp", "2": "drift_frost", "3": "hemp", "glow_life": 0.0},
                       "lit": {"3": "keel_glow", "glow_life": 1.0},
                       "tarred": {"0": "tar_black", "1": "tar_black", "2": "fur_wolf", "3": "keel_glow"}},
           "fur_note": "Zone 2 is a fur zone (role fur: the cloth shader's fur base); no fur shell surface is exported "
                       "(cloth2 exports one surface).",
           "motion_note": "Godot skinning: a walk is clear of the boots (the hem stands 8.5 cm off the legs at the "
                          "bottom); in a run stride the trailing boot can touch the hem, and the shoulder cape rises "
                          "with an aiming arm (it lies over the arms to the elbow).",
           "treasure_planet_check": "The battens are low half-round strips sewn to the cloth (not standing fins), so "
                                    "they read as a furled sail's battens, not as solar sails."})

Z_C = 1.20
YOKE_E = 70.0                  # the front edge's angle round from the front over the shoulders
ARM_Z = 1.10                   # the shoulder cape over the arm ends here
BODY_E = 122.0                 # the front edge of the body of the cloak (behind the arms: clear of their swing)
HEM_EDGE, HEM_BACK = 0.33, 0.29


def build(g):
    from cloth2.garment import built
    fits = g.fits
    under = [built(fits, gid)[0] for gid in UNDER]
    with_arms = D.hit_bvhs(fits, arms=True, meshes=under)
    no_arms = D.hit_bvhs(fits, arms=False, meshes=under)
    z_level = [1.17, 1.14, 1.11] + list(np.arange(1.075, 0.255, -0.036))
    rows = D.cape_rows(z_c=Z_C, phi=(22.0, 90.0), n_polar=8, z_rows=z_level)
    arms = [True] * 8 + [z >= ARM_Z - 0.005 for z in z_level]
    hits_by_row = [with_arms if a else no_arms for a in arms]
    thetas = np.linspace(YOKE_E - 2.0, 360.0 - YOKE_E + 2.0, 39)
    m, _ = D.envelope(g, rows, thetas, None, 0.012, smooth=3, hits_by_row=hits_by_row, drape=0.003,
                      folds=(0.018, 7.0, 0.95), flare=(0.085, 0.95), weight_arms=arms)   # (room for a walking leg)
    g.m = m
    # the front edges: over the shoulders at YOKE_E, then behind the arms below ARM_Z
    zr = np.array([z for z, _ in rows])
    e_row = np.where(zr >= ARM_Z - 0.005, YOKE_E, BODY_E)
    e_row[:8] = YOKE_E - 50.0 * (1.0 - np.linspace(0.0, 1.0, 8)) ** 2    # the collar wraps round to the throat
    e_v = np.interp(g.m.A["_row"], np.arange(len(rows)), e_row)
    th = g.m.A["_th"]
    g.m = g.m.clip(np.minimum(th - e_v, 360.0 - e_v - th), 0.0)
    # the hem: higher at the front edges
    th = g.m.A["_th"]
    back = np.abs(th - 180.0) / (180.0 - BODY_E)
    hem = HEM_BACK + (HEM_EDGE - HEM_BACK) * np.clip(back, 0.0, 1.0) ** 1.5
    g.m = g.m.clip(g.P[:, 2] - hem, 0.0)
    D.hang_weights(fits, g.m, 0.95)
    row = g.m.A["_row"].copy()
    # the fur collar: a roll standing up round the neck from the top row, and the fur lying over the shoulders
    up = np.array([0.0, -np.sin(np.radians(17.0)), np.cos(np.radians(17.0))])

    def disp(fit, P0, N0, s):
        # a soft roll turned down onto the shoulders (2026-10-03: standing up round the neck it rose in points like a
        # vampire's collar): a little up from the cloak's top edge, then out and down, lower toward its ends at the
        # throat
        out = np.stack([P0[:, 0], P0[:, 1], np.zeros(len(P0))], 1)
        out = out / np.maximum(np.linalg.norm(out, axis=1, keepdims=True), 1e-9)
        hf = 0.28 + 0.72 * smoothstep(22.0, 85.0, angle_from_front(P0))
        return (up[None] * (0.50 - 0.95 * s) + out * (0.45 + 0.85 * s)) * (0.046 * s * hf)[:, None]
    collar = TR.extrude(g.m, lambda P: row < 0.02, disp, rings=3, zone=2)
    D.drop_attrs(g.m)
    D.drop_attrs(collar)
    g.add(collar)
    c = np.array([0.0, 0.0, Z_C])

    def fur(P):
        q = P - c
        ph = np.degrees(np.arccos(np.clip(q[:, 2] / np.maximum(np.linalg.norm(q, axis=1), 1e-9), -1, 1)))
        return ph - 50.0 + 1000.0 * (P[:, 2] < 1.15)
    g.raised(fur, lambda P: 0.006 + 0.012 * np.clip((50.0 - np.degrees(np.arccos(np.clip((P - c)[:, 2] / np.maximum(
        np.linalg.norm(P - c, axis=1), 1e-9), -1, 1)))) / 25.0, 0.0, 1.0) ** 0.6, 2)
    g.fits.clear(g.m, 0.003)
    g.over(UNDER, 0.005)
    # the bolt-rope: the hem and the front edges (not the collar)
    g.edge_zone(1, 0.010, select=lambda P: P[:, 2] < 1.24, h=0.004)
    # the reef band across the back at 0.62, and its reef points
    g.raised(lambda P: np.abs(P[:, 2] - 0.62) - 0.009 + 1000.0 * (P[:, 1] < 0.0), 0.003, 1)
    for a in np.linspace(130.0, 230.0, 8):
        aa = a if a <= 180.0 else a - 360.0
        pts = []
        for z in np.linspace(0.615, 0.555, 5):
            hit, ok = HW.toward_axis(g.m, z, [aa])
            if ok[0]:
                pts.append(hit[0])
        if len(pts) >= 3:
            D.tube_piece(g, pts, np.linspace(0.0032, 0.0024, len(pts)), 1, segs=5, lift=0.002)
    # the five battens, fanning from the shoulder blades to the hem, each with its keel-thread (zone 3)
    def outward(P):
        # the battens' up: level and out from the body's axis (the bound faces' normals turned sideways where a
        # batten crossed the reef band's rim, and it twisted there)
        n = np.stack([P[:, 0], P[:, 1] - 0.01, np.zeros(len(P))], 1)
        return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    for top, bot in ((-26.0, -48.0), (-13.0, -24.0), (0.0, 0.0), (13.0, 24.0), (26.0, 48.0)):
        pts = []
        for z in np.linspace(1.14, HEM_BACK + 0.05, 22):
            u = (1.14 - z) / (1.14 - HEM_BACK - 0.05)
            a = 180.0 + top + (bot - top) * u
            aa = a if a <= 180.0 else a - 360.0
            hit, ok = HW.toward_axis(g.m, z, [aa])
            if ok[0]:
                pts.append(hit[0])
        if len(pts) >= 4:
            D.rib(g, pts, 0.022, 0.007, 3, segs=5, normal=outward)
    g.hem_below(0.40)
    g.uv(axis_top=1.45, axis_bottom=0.3, limbs=())


build_and_export = G.runner(SPEC, build)
