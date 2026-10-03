"""Stays, front-laced (cloth2: the torso shell stretched taut by cloth2.settlers): the boned bodice every woman wore
over her shift, a smooth cone from the waist to the bust, the top straight across the front and rising behind, a
point at the centre front and tabs round the waist, shoulder straps, the edges bound. This one laces up the front
over a stomacher panel, so it can be worn as the outer bodice with the shift's sleeves showing (the Palatine
women's working dress in summer) or under a jacket."""

import numpy as np

from cloth2 import bridge as BR
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import settlers as ST
from cloth2 import tailor as TL
from cloth2.mesh import smoothstep
from cloth2.parts import angle_from_front
from cloth2.spec import Spec, Zone

PAL = ["indigo_mid", "linen_unbleached", "full_green", "madder_red", "logwood_black", "walnut_brown", "drab"]

SPEC = Spec(
    id="stays_laced", name="Stays, front-laced", set="colonial", slot="vest", layer={"default": 20},
    description="A boned bodice over the shift, smooth and conical from the waist to the bust, laced up the front "
                "over a stomacher panel, with shoulder straps, a pointed front and tabs round the waist, the edges "
                "bound.",
    history="Every woman of the 1750s wore stays over her shift: boned, giving the period's smooth conical torso, most "
            "laced behind; dark green, blue or white were the common covers (the Fort Ticonderoga guidelines) [S6]. "
            "Working women also wore them, or a lightly boned bodice, as the outer garment over the shift with a "
            "petticoat and apron (Goschenhoppen Historians on rural Pennsylvania German dress) [S9]. Front lacing over "
            "a stomacher, as in the German Mieder, is less certain for the Mohawk valley (evidence L to M).",
    zones=[Zone(0, "stays", "cloth", "WOOL", PAL, "indigo_mid"),
           Zone(1, "binding", "trim", "LEA", ["leather_brown", "linen_unbleached", "logwood_black", "walnut_brown",
                                              "madder_red"], "leather_brown"),
           Zone(2, "lacing cord", "ribbon", "FLAT", ["linen_white", "logwood_black", "ribbon_red", "linen_unbleached"],
                "linen_white"),
           Zone(3, "stomacher", "trim", "WOOL", ["madder_red", "linen_unbleached", "indigo_mid", "full_green",
                                                 "logwood_black", "linen_white"], "madder_red")],
    sources=["S6", "S9", "S13", "M2"], evidence="B", tags=["women", "colonial", "settlers"], budget=3400,
    over=["shift_linen"],
    extra={"presets": {"margaretha": {"0": "indigo_mid", "1": "leather_brown", "2": "linen_white", "3": "madder_red"},
                       "anna": {"0": "logwood_black", "1": "logwood_black", "2": "logwood_black", "3": "drab"},
                       "linen": {"0": "linen_unbleached", "1": "leather_brown", "2": "linen_unbleached",
                                 "3": "linen_unbleached"}},
           "references": ["https://fortticonderoga.org/wp-content/uploads/2024/06/Zipped-1759-Siege-of-Carillon-French-Women-Guidelines.pdf",
                          "https://goschenhoppen.org/colonial-clothing/"],
           "male_body_note": "Built for every fit; on a man it is artistic licence."})

# heights (reference fit, m) by the angle round from the front: the top edge, the line the tabs are slit up to, and
# the tabs' lower edge (the centre-front point the lowest of the front)
TOP = ([0.0, 30.0, 62.0, 90.0, 118.0, 150.0, 180.0], [1.243, 1.245, 1.222, 1.196, 1.24, 1.285, 1.296])
TAB_LINE = ([0.0, 25.0, 40.0, 180.0], [1.035, 1.03, 1.012, 1.005])
TAB_TIP = ([0.0, 10.0, 24.0, 40.0, 180.0], [0.975, 0.99, 1.008, 0.958, 0.952])
TAB_SLITS = [32.0, 52.0, 72.0, 92.0, 112.0, 132.0, 152.0]
EASE, GAP, BUST_GAP = 0.0075, 0.0085, 0.002     # off the cloth surface; a little more over the bust (2026-10-03: 9 mm
                                                # made a point at each apex)
PIT_GAP = 0.004             # and under the arms (the shift's sleeve gathers there when the arm comes down)
PANEL = ([0.97, 1.02, 1.12, 1.25], [0.010, 0.011, 0.015, 0.020])     # the stomacher's half-width showing between the edges
EYELETS = 9


def panel_w(z):
    return np.interp(z, PANEL[0], PANEL[1])


def build(g):
    g.shell(G.TORSO)
    top = lambda P: np.interp(angle_from_front(P), *TOP) - P[:, 2]
    ST.keep(g, top)
    ST.keep(g, ST.tabs(lambda th: np.interp(th, *TAB_LINE), lambda th: np.interp(th, *TAB_TIP), TAB_SLITS,
                       half_slit=(0.0008, 0.0065), r=0.14))
    g.seams(back=True, limbs=())
    g.fit(ease=EASE, gap=GAP)
    # boned: stretched over the bust and across the cleavage (more round the front, the back follows the body)
    bust = lambda P: np.exp(-((np.abs(P[:, 0]) - 0.088) / 0.055) ** 2 - ((P[:, 2] - 1.155) / 0.065) ** 2) * \
        smoothstep(-0.04, -0.08, P[:, 1])
    J = g.fits.J
    pits = np.array([J["l_shoulder"] + [-0.02, 0.0, -0.09], J["r_shoulder"] + [0.02, 0.0, -0.09]])
    pit = lambda P: np.exp(-((P[:, None, :] - pits[None]) ** 2).sum(-1).min(1) / 0.06 ** 2)
    ST.taut(g, iters=7, gap=lambda P: GAP + BUST_GAP * bust(P) + PIT_GAP * pit(P), smooth=5,
            where=lambda P: 0.35 + 0.65 * (P[:, 1] < 0.02))
    # one flat-fronted cone, as boned stays made it (2026-10-03: each breast showed as a mound with a point): the
    # cleavage spanned straight across from apex to apex, the top edge straight across it, and below the apexes the
    # front straight down to the busk point and the tabs
    BR.flat_front(g, apex_z=(1.08, 1.235), bottom_z=1.035, top_z=1.245, gap=GAP)
    g.over(SPEC.over, 0.0035)
    # shoulder straps: from the back's top over the shoulder to the front under the arm
    for s in (1.0, -1.0):
        S = J["l_shoulder" if s > 0 else "r_shoulder"]
        way = [np.array([s * 0.086, 0.085, 1.282]), np.array([s * 0.112, 0.05, 1.325]),
               S + np.array([-s * 0.03, -0.012, 0.052]), np.array([s * 0.142, -0.055, 1.262]),
               np.array([s * 0.150, -0.068, 1.232])]
        g.strap(way, 0.020, 0.0115, 0)
    g.over(SPEC.over, 0.0035)
    # the front: the stomacher panel between the laced edges (recessed a little), the edges bound
    front = lambda P: (np.abs(P[:, 0]) - panel_w(P[:, 2])) + BIG * (P[:, 1] > -0.03)
    sel = ST.stripe(g, front, 3)
    v = np.zeros(g.m.n)
    v[np.unique(g.m.F[sel])] = 1.0
    ST.sink(g, v, 0.0022)
    ST.stripe(g, lambda P: np.abs(np.abs(P[:, 0]) - panel_w(P[:, 2]) - 0.0045) - 0.0045 + BIG * (P[:, 1] > -0.03) +
              BIG * (P[:, 2] > 1.25), 1)
    g.edge_zone(1, 0.0075)
    g.hem_below(1.04)
    TL.clean(g)
    # the lacing: eyelets down both edges (the right side's half a step lower), the cord in parallel diagonals
    zs = np.linspace(1.005, 1.215, EYELETS)
    dz = (zs[1] - zs[0]) / 2.0
    xl, xr = panel_w(zs) + 0.0035, -(panel_w(zs - dz) + 0.0035)
    O = np.concatenate([np.stack([xl, np.full(len(zs), -0.5), zs], 1), np.stack([xr, np.full(len(zs), -0.5), zs - dz], 1)])
    hit, ok = HW.ray_points(g.m, O, [0.0, 1.0, 0.0], 1.0)
    n = len(zs)
    pairs = [(hit[n + i], hit[i]) for i in range(n) if ok[i] and ok[n + i]]
    for a, b in pairs:
        ST.cord(g, a, b, 0.0032, zone=2, lift=0.0006)
    ST.eyelets(g, hit[ok], 2, r=0.0022, tube=0.0008, segs=6, tube_segs=3)
    # (a straight cord over the large bust's deeper front sinks at its ends: those few vertices clear of the skin)
    g.fits.clear(g.m, 0.002)
    g.uv(axis_top=1.35, axis_bottom=0.9, limbs=())


BIG = 10.0
build_and_export = G.runner(SPEC, build)
