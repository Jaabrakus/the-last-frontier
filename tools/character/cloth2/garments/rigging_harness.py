"""The rigging harness (cloth2, the Drift crews' set): a narrow belly band of tarred canvas closed at the front with a
wooden toggle, two served-rope straps over the shoulders crossing in an X behind through a wooden deadeye, a wooden
thimble at the front left for the tether, and the tether itself, a hemp line coiled three times on a short canvas tab on
the right hip, its toggle end laid into the coil (no hook hanging below it). A keel-thread tracer is laid into the line, so a man overboard's
line shows in the dark (spent by default: one glow per costume).

2026-10-03: flat leather straps, a belly band and brass rings read as a climbing harness or braces, and the tether stood
out of the coil like a stick: it is made of what a ship has now, rope, canvas and wood."""

import numpy as np

from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import straps as SP
from cloth2.hardware import piece_mesh
from cloth2.mesh import REF, unit
from cloth2.spec import Glow, Spec, Zone

SPEC = Spec(
    id="rigging_harness", name="Rigging harness", set="drift", slot="accessories.shoulder", layer={"default": 60},
    description="A narrow tarred-canvas belly band closed with a wooden toggle, two served-rope straps over the "
                "shoulders crossing behind through a wooden deadeye, a wooden thimble at the front for the tether, and "
                "a hemp tether coiled on the right hip; a faint glowing thread can run in the line.",
    history="The Drift's own gear (Vessary: 'sailors wear harness and tethers'): on Earth's ships a topman had only "
            "his hands. Made from what a ship has: served and tarred rope, old canvas, a deadeye and a thimble of "
            "lignum vitae, toggles (no brass rings or snap hooks: a spring snap hook would be later than the 1750s).",
    zones=[Zone(0, "tarred canvas band", "cloth", "TWILL", ["tar_black", "sailcloth", "hemp", "slate_grey"], "tar_black"),
           Zone(1, "served rope", "trim", "TWILL", ["hemp", "tar_black", "sailcloth"], "hemp"),
           Zone(2, "deadeye, thimble and toggles", "button", "FLAT", ["walnut_brown", "horn", "butternut"],
                "walnut_brown"),
           Zone(3, "tether (keel-thread tracer)", "trim", "TWILL", ["hemp", "keel_glow", "dead_stone", "tar_black"],
                "hemp", glow=Glow(strength=0.35, pulse=0.1, life=0.0))],
    sources=[], evidence="C", tags=["drift", "sailor"], budget=3200, alt_slots=["accessories.wrap"],
    over=["shirt_check", "slops", "waistcoat_long", "shirt_linen", "breeches", "mote_belt"],
    extra={"slot_note": "accessories.shoulder is in the catalog's slots but not yet in PlayerOutfit.SLOTS; until it "
                        "is, the harness is offered in accessories.wrap (alt_slots: no Drift role wears it with a cape "
                        "or a cloak; Rook aboard trades his weather cape for it).",
           "tether_note": "The coil is rigid on the hip; a live tether (paying out to a ring on deck) is a runtime "
                          "rope, not part of the garment.",
           "glow_note": "The tracer is spent by default (Glow life 0: one glow per costume); the 'tracer' preset "
                        "lights it for a night-watch rigger.",
           "presets": {"aboard": {"0": "tar_black", "1": "hemp", "2": "walnut_brown", "3": "hemp"},
                       "tarred": {"0": "tar_black", "1": "tar_black", "2": "walnut_brown", "3": "tar_black"},
                       "tracer": {"3": "hemp", "glow_life": 1.0}}})

COIL_AZ = -96.0               # the coil on the right hip, a little behind the side seam
BELLY = (1.018, 1.052)        # the belly band (narrow canvas: 3.4 cm)
LIFT = 0.012
ROPE_R = 0.0058               # the served rope straps
SAMPLE = 0.012


def rope(g, path, radius, lift, zone, part=8, segs=6):
    """A rope (a closed tube) along `path` (straps.SurfacePath), `lift` off the cloth surface, every ring with the
    path's weights at its point (like straps.strip)."""
    k = len(path)
    th = 2 * np.pi * np.arange(segs) / segs
    V = {}
    for fit in g.fits.V:
        p, n, t = path.at(fit)
        sd = unit(np.cross(n, t))
        up = unit(np.cross(t, sd))
        c = p + n * (lift + radius)
        rows = [c[i] + radius * (np.cos(th)[:, None] * sd[i] + np.sin(th)[:, None] * up[i]) for i in range(k)]
        V[fit] = np.concatenate(rows + [c[:1], c[-1:]])
    F = []
    for i in range(k - 1):
        for j in range(segs):
            j2 = (j + 1) % segs
            a, b, c_, d = i * segs + j, i * segs + j2, (i + 1) * segs + j2, (i + 1) * segs + j
            F += [(a, b, c_), (a, c_, d)]
    e0, e1 = k * segs, k * segs + 1
    for j in range(segs):
        j2 = (j + 1) % segs
        F += [(e0, j2, j), (e1, (k - 1) * segs + j, (k - 1) * segs + j2)]
    F = np.array(F, int)
    # outward: away from the rope's axis
    P = V[REF]
    p0, n0, _ = path.at(REF)
    axis = np.concatenate([np.repeat(p0 + n0 * (lift + radius), segs, axis=0), p0[:1], p0[-1:]])
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    if ((fn * (P[F].mean(1) - axis[F[:, 0]])).sum(1) < 0).mean() > 0.5:
        F = F[:, ::-1].copy()
    W0 = path.weights()
    W = np.concatenate([np.repeat(W0, segs, axis=0), W0[:1], W0[-1:]])
    la = path.limb_attrs()
    A = {name: np.concatenate([np.repeat(v, segs), v[:1], v[-1:]]) for name, v in la.items()}
    region = g.fits.p_region[path.tri]
    reg = np.concatenate([np.repeat(region, segs), region[:1], region[-1:]])[F[:, 0]]
    return g.add(piece_mesh(g.m, V, F, W, reg, zone, part, A))


def build(g):
    J = g.fits.J
    g.m = None
    # the narrow canvas belly band
    g.band(BELLY[0], BELLY[1], LIFT, 0)
    g.over(SPEC.over, 0.004)
    # the served rope straps: from the band in front over each shoulder, crossing behind through the deadeye
    zb = BELLY[1] - 0.008
    for s_ in ("l", "r"):
        sg = 1.0 if s_ == "l" else -1.0
        S = J[s_ + "_shoulder"]
        way = [np.array([sg * 0.09, -0.20, zb]), np.array([sg * 0.10, -0.12, 1.22]), S + np.array([-sg * 0.045, 0.0, 0.06]),
               np.array([sg * 0.06, 0.15, 1.24]), np.array([0.0, 0.15, 1.19]), np.array([-sg * 0.09, 0.15, zb])]
        rope(g, SP.surface_path(g.fits, way, SAMPLE), ROPE_R, LIFT + 0.002, 1)
    # the coil's hanger: a short tab of the band's canvas down the right hip (the coil lies flat on it)
    # (on the torso alone: rays at the side found the hanging arm, and the old hanger ran out to it like a stick)
    torso = G.Garment(g.fits, g.spec).shell(G.TORSO).m
    way, ok = HW.toward_axis(torso, np.array([BELLY[0] + 0.004, 0.95, 0.88]), np.full(3, COIL_AZ))
    g.strap(way[ok], 0.032, LIFT + 0.002, 0)
    g.over(SPEC.over, 0.004)
    # the deadeye where the straps cross behind, the thimble (the tether's) on the band front left, the toggle closing
    # the band at the front; the coiled tether on the right hip (three turns, flat on the tab), its toggle end laid into
    # the coil. The deadeye and the coil are placed on the torso's cloth surface (a ray at the thin ropes' crossing
    # finds nothing to sit on), as far out as the ropes and the tab
    def on_torso(z, az, lift, prim, zone, up=(0.0, 0.0, 1.0)):
        P, ok = HW.toward_axis(torso, np.array([z]), np.array([az]))
        if ok[0]:
            g.add(HW.rigid(torso, HW.Binding(torso, P[:1]), prim, zone, lift=lift, up=up))
    on_torso(1.19, 180.0, LIFT + 2.0 * ROPE_R + 0.0015, HW.disc(0.024, 0.011, segs=14), 2)
    P = g.around_points(0.5 * (BELLY[0] + BELLY[1]), np.array([36.0]))
    g.hardware(P, HW.ring(0.0135, 0.0042, 14, 5), 2, lift=0.002)
    P = g.front_points([0.0], [0.5 * (BELLY[0] + BELLY[1])])
    g.hardware(P, HW.ellipsoid(0.019, 0.0062, 0.0062, segs=10, rings=5), 2, lift=0.002)
    on_torso(0.895, COIL_AZ, LIFT + 0.019, D.coil(r=0.050, rope=0.0062, turns=3, spread=0.005, segs=16, tube_segs=5), 3)
    on_torso(0.895, COIL_AZ, LIFT + 0.019, HW.translate(HW.ellipsoid(0.016, 0.0055, 0.0055, segs=8, rings=4),
                                                         (0.0, -0.036, 0.020)), 2)
    g.uv(axis_top=1.4, axis_bottom=0.8, limbs=())


build_and_export = G.runner(SPEC, build)
