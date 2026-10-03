"""The glim (cloth2, the Drift crews' set): a lens of lantern-glass, ground the Lenswrights' way, in a hinged brass
case worn on the chest on a narrow leather strap round the neck, a cord from the case to a buttonhole. Held to a light
it shows the Drift's currents (not the channels through the Veil: that is the Wayglass alone). Rook keeps his lens-
mate's case with the lid shut."""

import numpy as np

from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2.mesh import REF
from cloth2.spec import Glow, Spec, Zone

Z_CASE = 1.185

SPEC = Spec(
    id="glim", name="Glim", set="drift", slot="accessories.neck", layer={"default": 30},
    description="A 5 cm lens in a hinged brass case on the chest, hung on a narrow leather strap round the neck, a cord "
                "to a buttonhole; the glass glows faintly.",
    history="The Drift's own gear: a pilot's lens of ordinary lantern-glass (the Lenswrights grind them in Vessary), "
            "in a brass case like a watch or a compass case of the period.",
    zones=[Zone(0, "strap", "leather", "LEA", ["leather_brown", "leather_black", "tar_black"], "leather_brown"),
           Zone(1, "cord", "trim", "TWILL", ["hemp", "linen_unbleached", "tar_black"], "hemp"),
           Zone(2, "brass case", "metal", "MET", ["brass", "pewter"], "brass", metal=True),
           Zone(3, "lens", "trim", "FLAT", ["lens_glass", "keel_glow", "brass", "dead_stone"], "lens_glass",
                glow=Glow(strength=0.3, pulse=0.0, life=1.0, color="lens_glass"))],
    sources=[], evidence="C", tags=["drift", "sailor"], budget=1200,
    over=["shirt_check", "waistcoat_long", "sea_jacket", "shirt_linen"],
    extra={"presets": {"open": {"3": "lens_glass"}, "rook_shut": {"3": "brass", "glow_life": 0.0}},
           "lore_note": "Not the Wayglass (main_story 7.1: the one lens cut from the Ninth Lantern)."})


def build(g):
    fits = g.fits
    body = fits.surface("cloth")
    J = fits.J
    # the strap: from the case up each side of the chest, over the shoulders by the neck, meeting behind
    top = HW.ray_points(body, [[0.0, -0.4, Z_CASE + 0.035]], [0.0, 1.0, 0.0], 0.6)[0][0]
    g.m = None
    for s in (1.0, -1.0):
        way = [top + np.array([s * 0.008, 0.0, 0.0]), np.array([s * 0.035, -0.09, 1.27]),
               np.array([s * 0.062, -0.035, 1.345]), np.array([s * 0.055, 0.045, 1.36]), np.array([0.0, 0.075, 1.35])]
        g.strap(way, 0.012, 0.010, 0)
    g.over(SPEC.over, 0.004)
    # the case's leather mount: a pad lying over whatever is outermost there (it bridges an open jacket's fronts)
    from cloth2.garment import built
    under = [built(fits, gid)[0] for gid in SPEC.over]
    hits = D.hit_bvhs(fits, arms=False, meshes=under)
    rows = [(float(z), 90.0) for z in np.linspace(Z_CASE + 0.036, Z_CASE - 0.034, 6)]
    pad, _ = D.envelope(g, rows, np.linspace(-15.0, 15.0, 7), hits, 0.0035, smooth=2, rowmax=True)
    D.drop_attrs(pad)
    g.add(pad)
    # the case: a brass drum with a domed lid ring, the lens set in it, a hinge and a bail at the top
    hit, ok = HW.ray_points(g.m, [[0.0, -0.4, Z_CASE]], [0.0, 1.0, 0.0], 0.6)
    if ok[0]:
        b = HW.Binding(g.m, hit[:1])
        case = HW.lathe([(0.0262, 0.0), (0.0272, 0.003), (0.0272, 0.0095), (0.0245, 0.0118), (0.0215, 0.0122),
                         (0.0, 0.0122)], segs=20)
        g.add(HW.rigid(g.m, b, case, 2, part=9, up=(0.0, 0.0, 1.0), lift=0.0008))
        g.add(HW.rigid(g.m, b, HW.disc(0.0212, 0.0014, segs=20, sink=0.0), 3, part=9, up=(0.0, 0.0, 1.0),
                       lift=0.0008 + 0.0118))
        g.add(HW.rigid(g.m, b, HW.translate(HW.box(0.008, 0.0025, 0.0035), (0.0, 0.0275, 0.002)), 2, part=9,
                       up=(0.0, 0.0, 1.0), lift=0.0008))
        g.add(HW.rigid(g.m, b, HW.translate(HW.ring(0.0045, 0.0013, 10, 4, z0=0.004), (0.0, 0.033, 0.0)), 2,
                       part=9, up=(0.0, 0.0, 1.0), lift=0.0008))
        # the cord: from the case's right side to a buttonhole on the right breast
        p, n = b.at(g.m, REF)
        c0 = p[0] + np.array([-0.026, 0.0, 0.0])
        way = [c0, c0 + np.array([-0.025, 0.004, 0.02]), np.array([-0.075, -0.095, Z_CASE + 0.045])]
        g.strap(way, 0.004, 0.012, 1, step=0.008)
        g.over(SPEC.over, 0.003)
    g.uv(axis_top=1.4, axis_bottom=1.1, limbs=())


build_and_export = G.runner(SPEC, build)
