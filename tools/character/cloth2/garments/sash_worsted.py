"""The worsted sash (cloth2: a band round the waist like recipes.sash, striped along its length, the ends hanging over
the capot's skirt): wound twice round the waist over the capot, knotted at the left hip, the two ends hanging with a
fringe. Plain or with two stripes along it; no arrow pattern (finger-weaving is an Indigenous technique, and the
ceinture flechee belongs to later decades)."""

import numpy as np

from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import tailor as TL
from cloth2.mesh import REF, unit
from cloth2.parts import angle_from_front
from cloth2.spec import Spec, Zone

Z = (0.952, 1.042)                     # the band: about 9 cm wide
LIFT = 0.030                           # off the cloth surface before it is fitted over the capot
STRIPES = [(0.967, 0.975), (1.019, 1.027)]   # two stripes along the band (zone 1: the same colour = plain)
KNOT = 68.0                            # degrees round from the front toward the wearer's left
ENDS = [{"dx": -0.012, "len": 0.30, "w": 0.068}, {"dx": 0.022, "len": 0.25, "w": 0.062}]
FRINGE = 0.05

PAL = ["ribbon_red", "stroud_red", "stroud_blue", "ribbon_green", "madder_red", "ribbon_blue", "walnut_brown",
       "grey_white"]

SPEC = Spec(
    id="sash_worsted", name="Worsted sash", set="colonial", slot="accessories.waist", layer={"default": 60},
    description="A long worsted sash wound twice round the waist over the capot and knotted at the left hip, the "
                "fringed ends hanging; plain or with two stripes along it.",
    history="'A sash around the capot' (d'Aleyrac): Canadians closed the wrap-over capot with a worsted sash, red, "
            "blue or green; the patterned ceinture flechee is documented from the 1770s at the latest, so a plain or "
            "simply striped sash suits 1757 [S2][S14][M5].",
    zones=[Zone(0, "sash", "cloth", "WOOL", PAL, "ribbon_red"),
           Zone(1, "stripes", "trim", "WOOL", PAL + ["linen_white", "ribbon_yellow", "logwood_black"], "ribbon_red"),
           Zone(2, "unused", "trim", "WOOL", ["ribbon_red"], "ribbon_red"),
           Zone(3, "fringe", "fringe", "WOOL", PAL, "ribbon_red")],
    sources=["S2", "S14", "M5"], evidence="B", tags=["men", "women", "colonial", "canada"], budget=1800,
    over=["shirt_linen", "breeches", "veste_sleeved", "waistcoat_sb", "capot"],
    extra={"presets": {"plain_red": {"0": "ribbon_red", "1": "ribbon_red", "3": "ribbon_red"},
                       "red_striped": {"0": "ribbon_red", "1": "ribbon_yellow", "3": "ribbon_red"},
                       "blue": {"0": "stroud_blue", "1": "stroud_blue", "3": "stroud_blue"},
                       "green_striped": {"0": "ribbon_green", "1": "ribbon_red", "3": "ribbon_green"}},
           "fit_note": "Fitted over the capot (and the veste, waistcoat and shirt under it): worn over a veste alone "
                       "it stands off by about the capot's thickness.",
           "consultation_note": "No arrow (fleche) or chevron pattern: finger-weaving is an Indigenous technique; "
                                "stripes along the sash only.",
           "references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-Canadian-Milice-Guidelines.pdf",
                          "https://en.wikipedia.org/wiki/Ceinture_fl%C3%A9ch%C3%A9e"]})


def build(g):
    from cloth2.garment import built
    fits = g.fits
    g.m = None
    g.band(Z[0], Z[1], LIFT, 0)
    g.over(SPEC.over, 0.005)
    for z0, z1 in STRIPES:
        sel = TL.band_select(g, z0, z1)
        g.m.fa["zone"][sel] = 1
    zc = 0.5 * (Z[0] + Z[1])
    P = g.around_points(zc, np.array([KNOT]))
    if not len(P):
        return
    k = P[0]
    # a flat knot, the turn of the sash across it (2026-10-03: the round knot read as a big button or a pompom); the
    # ends come out from under it
    g.hardware([k], HW.ellipsoid(0.040, 0.032, 0.0085, segs=10, rings=4), 0, lift=-0.003, up=(0.0, 0.0, 1.0))
    g.hardware([k], HW.ellipsoid(0.017, 0.036, 0.0105, segs=8, rings=4), 0, lift=-0.003, up=(0.25, 0.0, 1.0))
    # the ends hang from under the knot over the capot's skirt (bound to its surface: every fit, its weights)
    cap = built(fits, "capot")[0]
    for e in ENDS:
        zs = np.linspace(k[2] - 0.015, k[2] - e["len"], 12)
        a0 = float(angle_from_front(k[None])[0])
        ang = a0 + np.degrees(e["dx"] / 0.17) + np.linspace(0.0, 6.0, len(zs))
        Q, ok = HW.toward_axis(cap, zs, ang)
        if ok.sum() < 3:
            continue
        b = HW.Binding(cap, Q[ok])
        centre, normal, across = {}, {}, {}
        for fit in cap.V:
            p, n = b.at(cap, fit)
            n = unit(n)
            t = unit(np.gradient(p, axis=0))
            centre[fit], normal[fit], across[fit] = p, n, unit(np.cross(n, t))
        kk = len(Q[ok])
        s = np.linspace(0.0, 1.0, kk)
        hw = 0.5 * e["w"] * (0.80 + 0.20 * s)                      # it opens out a little below the knot
        lift = 0.010 + 0.004 * (1.0 - s)
        attrs = {name: b.attr(cap, name) for name in g.m.A if name != "W" and name in cap.A}
        for name in g.m.A:
            if name != "W" and name not in attrs:
                attrs[name] = np.zeros(kk)
        piece = TL.ribbon(g, centre, normal, across, hw, lift, b.weights(cap), stripes=[(-0.62, -0.42, 1), (0.42, 0.62, 1)],
                          zone=0, part=8, n_across=4, attrs=attrs, region=int(np.bincount(b.face_attr(cap, "region")).argmax()))
        fc = piece.face_centres()
        piece.fa["zone"][fc[:, 2] < k[2] - e["len"] + FRINGE] = 3
        g.add(piece)
    g.over(SPEC.over, 0.004, where=lambda P: P[:, 2] < k[2] - 0.02)
    g.uv(axis_top=1.1, axis_bottom=0.6, limbs=())


build_and_export = G.runner(SPEC, build)
