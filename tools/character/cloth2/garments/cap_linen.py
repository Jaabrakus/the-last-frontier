"""The women's linen cap (cloth2: a cap over the head by hats.head_grid, like recipes.soft_cap "womens" with a fuller
caul and a gathered frill of its own): a white linen cap with a gathered caul puffed over the pinned-up hair, a band
framing the face with a narrow ruffled frill, and a ribbon round it tied in a bow behind. Rigid on the head; it hides
the hair's crown and back zones."""

import numpy as np

from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import hats as HT
from cloth2 import settlers as ST
from cloth2 import trims as TR
from cloth2.mesh import unit
from cloth2.parts import angle_from_front
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="cap_linen", name="Linen cap", set="colonial", slot="head", layer={"default": 80},
    description="A white linen cap with a gathered caul over the pinned-up hair, a band and a narrow frill framing the "
                "face, and a ribbon round it tied behind.",
    history="Women covered their hair with a white linen cap, starched if possible, loosely gathered into a caul over "
            "the hair, trimmed with silk ribbon (the Fort Ticonderoga guidelines; the 1759 Canadienne's cap trimmed with "
            "orange-red ribbon) [S6][S9]. A distinctly German cap shape for the valley is not documented, so the shape "
            "is the common one.",
    zones=[Zone(0, "cap", "cloth", "LIN", ["linen_white", "linen_unbleached", "logwood_black"], "linen_white"),
           Zone(1, "band and frill", "trim", "LIN", ["linen_white", "linen_unbleached", "logwood_black"], "linen_white"),
           Zone(2, "ribbon", "ribbon", "FLAT", ["ribbon_red", "ribbon_black", "ribbon_blue", "orange", "ribbon_white"],
                "ribbon_red")],
    hides_hair_zones=["crown", "back"], sources=["S6", "S9", "M2"], evidence="A",
    tags=["women", "colonial", "settlers"], budget=2200,
    extra={"presets": {"margaretha": {"0": "linen_white", "1": "linen_white", "2": "ribbon_red"},
                       "anna": {"0": "linen_white", "1": "linen_white", "2": "ribbon_black"}},
           "hair_note": "Worn over hair_pinned_capped or hair_bun_low (the caul's room is over the bun).",
           "references": ["https://fortticonderoga.org/wp-content/uploads/2024/06/Zipped-1759-Siege-of-Carillon-French-Women-Guidelines.pdf",
                          "https://goschenhoppen.org/colonial-clothing/"]})

EDGE = (68.0, 88.0, 128.0)       # the cap's edge, degrees from the crown at the front, the sides and the back
EASE = 0.0115                    # over the scalp (>= hats.HAIR_CLEAR: over the pressed hair)
CAUL = (0.050, 78.0, 34.0)       # the caul's puff: height (m), centred this many degrees from the crown, its spread
BAND = (0.030, 0.0025, 96.0)     # the band: width, raised, round the front within this angle
FRILL = (0.024, 80.0, 14, 0.30)  # the frill: depth (m), round the front within this angle, gathers round it, their depth
RIBBON = (24.0, 0.0055)          # the ribbon: its ring this many degrees in from the cap's edge; half its width (m)


def build(g):
    fr, sd, bk = [np.radians(a) for a in EDGE]
    ph0, spread = np.radians(CAUL[1]), np.radians(CAUL[2])

    def phi_max(th):
        c = np.cos(th)
        return np.where(c > 0, sd + (fr - sd) * c, sd + (bk - sd) * (-c))

    def ease(th, ph):
        back = (0.5 + 0.5 * np.clip(-np.cos(th), -1.0, 1.0)) ** 1.6
        return EASE + CAUL[0] * back * np.exp(-((ph - ph0) / spread) ** 2)
    m, ids, TH, PH = HT.head_grid(g.fits, segs=64, rows=10, phi_max=phi_max, ease=ease)
    g.m = m
    c0 = HT.headb(g.fits) + np.array([0.0, -0.035, 0.075])
    front = lambda deg: (lambda P: angle_from_front(P - np.array([0.0, c0[1], 0.0])) < deg)
    # the band framing the face
    g.edge_zone(1, BAND[0], h=BAND[1], select=front(BAND[2]))
    # the frill: gathered (its edge waving in and out round the face), standing off the band's edge
    depth, deg, n, amp = FRILL
    aff = HT.head_affines(g.fits)

    def disp(fit, P0, N0, s):
        q = P0 - HT.apply_affine(aff, c0[None], fit)[0]
        th = np.arctan2(q[:, 0], -q[:, 1])
        down = unit(np.array([0.0, 0.0, -1.0]) - (N0 @ np.array([0.0, 0.0, -1.0]))[:, None] * N0)
        out = unit(N0 * 0.9 + down * 0.35)
        wave = np.sin(n * th)
        # (tapering to nothing at its two ends, by the ears)
        taper = np.clip(1.0 - (np.abs(th) / np.radians(deg)) ** 4, 0.0, 1.0) ** 0.5
        return (out * (depth * taper * (1.0 + 0.25 * wave))[:, None] + down * (depth * taper * amp * wave)[:, None]) * s
    piece = TR.extrude(g.m, front(deg), disp, rings=2, zone=1)
    if piece is not None:
        g.add(piece)
    # (the frill over the brow kept off the hair; the cap's edge ends above the ears, whose skin normals are no guide
    # for a push)
    th = np.degrees(np.abs(np.arctan2(g.P[:, 0] - c0[0], -(g.P[:, 1] - c0[1]))))
    g.fits.clear(g.m, np.where(th < 62.0, HT.HAIR_CLEAR, -1.0))
    # the ribbon round the cap where the caul is gathered to the band (a ring RIBBON degrees in from the edge)
    rin, rhalf = np.radians(RIBBON[0]), RIBBON[1]
    th = np.linspace(-np.pi, np.pi, 64, endpoint=False)
    ph = phi_max(th) - rin
    D = np.stack([np.sin(ph) * np.sin(th), -np.sin(ph) * np.cos(th), np.cos(ph)], 1)
    hit, ok = HW.ray_points(g.m, c0 + D * 0.25, -D, 0.25)
    if ok.sum() > 8:
        ST.loop_strip(g, hit[ok], rhalf, 0.0012, 2)
    # the bow behind, on the ribbon
    pb = phi_max(np.array([np.pi]))[0] - rin
    d = np.array([0.0, np.sin(pb), np.cos(pb)])
    hit, ok = HW.ray_points(g.m, [c0 + d * 0.25], [-d], 0.25)
    if ok[0]:
        ST.bow(g, hit[0], 2, size=0.034, up=(0.0, 0.0, 1.0), tails=0.075, tail_w=0.012, lift=0.0018)
    g.notes["scalp_clearance_mm"] = {k: [round(v[0] * 1000, 1), round(v[1] * 1000, 1)] for k, v in
                                     HT.scalp_clearance(g.fits, g.m.V).items()}
    c = HT.headb(g.fits)
    g.uvparts = {0: ("cyl", c, c + np.array([0.0, 0.0, 0.2]), [0, -1, 0])}
    g.m.fa["part"][:] = 0
    g.shape_alias = {"sex_head": "m"}


build_and_export = G.runner(SPEC, build)
