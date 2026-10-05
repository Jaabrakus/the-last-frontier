"""Ring footwear on cloth2.feet.SockTube: light soft shoes (earth, fire, air) and fur-topped soft boots (water)."""

import numpy as np

from cloth2 import feet as FT
from cloth2 import garment as G
from cloth2.mesh import REF, BIG_FIELD, smoothstep


def tube(g, top, ease, under=(), gap=0.004):
    fits = g.fits
    g.m = FT.both(fits, lambda s: FT.SockTube(fits, s, top=top + 0.03, segs=16, step_leg=0.012, step_foot=0.0118,
                                              cap=4).mesh(ease, foot_smooth=6))
    if under:
        g.over(list(under), gap)
    g.top(top)
    return g


def sole(g, zone, z=0.013):
    g.zone(zone, below=z)
    return g


def strap(g, zone, h=0.0018):
    """A strap over the instep, slanting down and back, on each foot."""
    J = g.fits.J
    for s in ("l", "r"):
        A = J[s + "_ankle"]
        c = np.array([A[0], A[1] - 0.045, 0.062])
        n = np.array([0.0, 0.55, 0.835])
        g.raised(lambda P, c=c, n=n: np.abs((P - c) @ n) - 0.009 + BIG_FIELD * smoothstep(0.075, 0.09, np.abs(P[:, 0] - c[0])) +
                 BIG_FIELD * (1.0 - smoothstep(0.016, 0.022, P[:, 2])), h, zone)
    return g


def uv(g):
    """The moccasins' UV: a cylinder along each foot, planar parts kept."""
    J = g.fits.J
    m = g.m
    left = m.V[REF][m.F].mean(1)[:, 0] > 0.0
    keep = m.fa["part"] >= 9
    m.fa["part"] = np.where(keep, m.fa["part"], np.where(left, 5, 6))
    g.uvparts = {9: ("planar", [0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0])}
    for s, pid in (("l", 5), ("r", 6)):
        A, B = J[s + "_ankle"], J[s + "_ball"]
        g.uvparts[pid] = ("cyl", np.array([A[0], A[1] + 0.05, 0.035]), np.array([B[0], B[1] - 0.06, 0.025]),
                          [0.0, 0.0, 1.0])
    return g
