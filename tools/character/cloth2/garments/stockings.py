"""Knit stockings (cloth2, grown round the leg and foot: cloth2.feet.SockTube): from the toes to just above the knee,
the seam at the back of the leg and under the sole, gartered below the knee under the breeches' knee band."""

import numpy as np

from cloth2 import feet as FT
from cloth2 import garment as G
from cloth2 import tailor as TL
from cloth2.spec import Spec, Zone

TOP = 0.470                 # the stocking's top just above the knee, under the breeches' knee band (2026-10-03: at 0.565
                            # the thigh lay 1.5 mm under the breeches and came through them; the leg above is hidden)
GARTER = (0.437, 0.452)     # the garter below the knee (under the breeches' knee band, which ends ~0.434)
EASE = 0.0032               # knit close on the skin (its faces span ~2 cm: the chords stay clear of the calf)
FOOT_GAP = 0.0018           # every vertex, face centre and edge midpoint on the foot at least this far off the skin

SPEC = Spec(
    id="stockings", name="Knit stockings", set="colonial", slot="legs.over", layer={"default": 10},
    description="Knitted wool stockings from the toes to just above the knee, tied below the knee with a garter "
                "under the breeches' knee band.",
    history="Knitted wool or worsted stockings were worn by men and women alike: white, grey, blue, brown or black; "
            "red and yellow were not usual. The colonial regulars of New France wore blue stockings with their blue "
            "veste and breeches (the 31 May 1758 prize sale lists 'Soldiers blue Stockings') [M4][M5][M3].",
    zones=[Zone(0, "knit", "cloth", "KNIT", ["grey_white", "linen_white", "stroud_blue", "royal_blue", "drab",
                                             "logwood_black", "slate_grey", "walnut_brown"], "grey_white"),
           Zone(1, "garters", "ribbon", "WOOL", ["logwood_black", "madder_red", "linen_white", "stroud_blue",
                                                 "leather_brown", "grey_white"], "logwood_black")],
    sources=["M4", "M5", "M3", "M2"], evidence="A", tags=["men", "women", "colonial"], budget=3200,
    extra={"presets": {"marine": {"0": "royal_blue", "1": "royal_blue"}, "settler": {"0": "grey_white", "1": "logwood_black"},
                       "mourning": {"0": "logwood_black", "1": "logwood_black"}},
           "construction": "cloth2.feet.SockTube: rings along the leg's joint line bent into the foot, each vertex the "
                           "outermost point 3.2 mm off the skin along its ray (bridges the toes and the knee's hollow)",
           "slot_note": "Shares legs.over with leggings_wool (one or the other: leggings go over bare legs or are "
                        "worn instead of stockings).",
           "references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-French-Army-Colonial-Regulars-Guidelines-1.pdf",
                          "https://fortticonderoga.org/wp-content/uploads/2024/06/Zipped-1759-Siege-of-Carillon-French-Women-Guidelines.pdf"]})


def build(g):
    fits = g.fits
    g.m = FT.both(fits, lambda s: FT.SockTube(fits, s, top=TOP, segs=16, step_leg=0.025, step_foot=0.0120,
                                              cap=4).mesh(EASE, foot_smooth=6, gap=0.0021))
    # the foot's faces clear of the skin too (SockTube clears only the leg's: the heel and the sole's edges are
    # sharper than its rings, and the skin showed through the chords there)
    g.fits.clear(g.m, np.where(g.m.A["foot"] > 0.5, FOOT_GAP, -1.0))
    _unfold(g)
    # the garter: a band 1.2 mm proud
    g.raised(TL.band_select(g, *GARTER), 0.0012, 1)
    _uv(g)


def _unfold(g, iters=8, lam=0.5):
    """Relaxes the few faces folded over at the back of the heel bend (their normal against their vertices' rays,
    which point out: a dark notch above the heel) and their neighbours, in every fit, then clears the skin again."""
    from cloth2.mesh import vertex_normals
    m = g.m
    R = np.stack([m.A["ray_x"], m.A["ray_y"], m.A["ray_z"]], 1)
    E = m.adjacency()
    for k in m.V:
        P = m.V[k]
        fn = np.cross(P[m.F[:, 1]] - P[m.F[:, 0]], P[m.F[:, 2]] - P[m.F[:, 0]])
        bad = (fn * R[m.F].mean(1)).sum(1) < 0.0
        if not bad.any():
            continue
        sel = np.zeros(m.n, bool)
        sel[m.F[bad].ravel()] = True
        for _ in range(2):                                   # and two rings of neighbours
            grow = sel.copy()
            grow[E[sel[E[:, 0]], 1]] = True
            sel = grow
        for _ in range(iters):
            acc = np.zeros_like(P)
            cnt = np.zeros(m.n)
            np.add.at(acc, E[:, 0], P[E[:, 1]])
            np.add.at(cnt, E[:, 0], 1.0)
            avg = acc / np.maximum(cnt, 1.0)[:, None]
            P[sel] += lam * (avg[sel] - P[sel])
        m.V[k] = P
    m.N = {k: vertex_normals(v, m.F) for k, v in m.V.items()}
    g.fits.clear(m, np.where(m.A["foot"] > 0.5, FOOT_GAP, 0.0015))
    return g


def _uv(g):
    """UV parts: each leg round its own axis (the seam behind), each foot round the heel-to-toe axis (seam under)."""
    J = g.fits.J
    m = g.m
    foot = m.A["foot"][m.F].mean(1) > 0.5
    left = m.V[G.REF][m.F].mean(1)[:, 0] > 0.0
    part = np.where(left, 3, 4) + np.where(foot, 2, 0)
    m.fa["part"] = part
    g.uvparts = {}
    for s, pid in (("l", 3), ("r", 4)):
        g.uvparts[pid] = ("cyl", J[s + "_upper_leg"], J[s + "_ankle"], [0.0, -1.0, 0.0])
        A, B = J[s + "_ankle"], J[s + "_ball"]
        g.uvparts[pid + 2] = ("cyl", np.array([A[0], A[1] + 0.05, 0.035]), np.array([B[0], B[1] - 0.06, 0.025]),
                              [0.0, 0.0, 1.0])
    # the hem for the cloth shader: the top welt (the garter's rims are not hems)
    g.hem = lambda m: m.boundary()[1] & (m.V[G.REF][:, 2] > TOP - 0.008)
    return g


build_and_export = G.runner(SPEC, build)
