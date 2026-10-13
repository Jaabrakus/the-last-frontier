"""Extra SDF leaves for the body kits, in the idiom of tools/character/lib/sdf.py (Leaf subclasses with a bounding
box, evaluated on broadcast grids by geval and on point lists by peval). The lib is not edited: these live beside the
kit generators.

    ECapsule(a, b, (rx_a, rx_b), (rn_a, rn_b), side, n)   elliptic / boxy round cone (snouts, tails, limbs)
    Warp(child, c, R, s)                                   the child scaled by s (3 axes of frame R) about c
"""

import numpy as np

from lib.sdf import Leaf, peval, nrm


def _bc(X, Y, Z):
    return np.broadcast_arrays(X, Y, Z)


class ECapsule(Leaf):
    """Round cone a -> b whose cross-section is a superellipse: half-width rx along `side` (made perpendicular to
    the axis) and half-height rn along axis x side; both radii interpolate linearly from a to b. Exponent n = 2 is an
    ellipse, larger is boxier. Beyond the ends the section is closed by an ellipsoidal cap of the end radii.
    Distance is approximate (scaled by the smaller radius), which polygonize's projection tolerates."""

    def __init__(self, a, b, rx, rn, side=(1.0, 0.0, 0.0), n=2.0):
        self.a = np.asarray(a, float)
        self.b = np.asarray(b, float)
        self.rx = (float(rx[0]), float(rx[1]))
        self.rn = (float(rn[0]), float(rn[1]))
        d = self.b - self.a
        self.L = float(np.linalg.norm(d))
        self.d = d / self.L
        s = np.asarray(side, float)
        s = s - self.d * (s @ self.d)
        self.s = nrm(s)
        self.nv = np.cross(self.d, self.s)
        self.n = float(n)
        r = max(self.rx + self.rn)
        self.lo = np.minimum(self.a, self.b) - r
        self.hi = np.maximum(self.a, self.b) + r

    def f(self, X, Y, Z):
        a, d, s, nv = self.a, self.d, self.s, self.nv
        px, py, pz = X - a[0], Y - a[1], Z - a[2]
        along = px * d[0] + py * d[1] + pz * d[2]
        t = np.clip(along / self.L, 0.0, 1.0)
        oa = along - t * self.L                         # beyond the ends only
        ox = px * s[0] + py * s[1] + pz * s[2]
        on = px * nv[0] + py * nv[1] + pz * nv[2]
        rx = self.rx[0] + (self.rx[1] - self.rx[0]) * t
        rn = self.rn[0] + (self.rn[1] - self.rn[0]) * t
        n = self.n
        k = (np.abs(ox) / rx) ** n + (np.abs(on) / rn) ** n
        k = k ** (1.0 / n)
        k = np.sqrt(k * k + (oa / np.minimum(rx, rn)) ** 2)
        return (k - 1.0) * np.minimum(rx, rn)


class Warp(Leaf):
    """`child` scaled by s = (sx, sy, sz) along the columns of R about c (approximate distance x min(s))."""

    def __init__(self, child, c, s, R=None):
        self.child = child
        self.c = np.asarray(c, float)
        self.s = np.asarray(s, float)
        self.R = np.eye(3) if R is None else np.asarray(R, float)
        M = self.R @ np.diag(self.s) @ self.R.T
        self.M_inv = self.R @ np.diag(1.0 / self.s) @ self.R.T
        lo, hi = child.lo, child.hi
        corners = np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
        w = (corners - self.c) @ M.T + self.c
        self.lo, self.hi = w.min(0), w.max(0)

    def f(self, X, Y, Z):
        X, Y, Z = _bc(X, Y, Z)
        shp = X.shape
        P = np.stack([X.ravel(), Y.ravel(), Z.ravel()], 1).astype(float)
        Q = (P - self.c) @ self.M_inv.T + self.c
        return (peval(self.child, Q) * float(self.s.min())).reshape(shp)
