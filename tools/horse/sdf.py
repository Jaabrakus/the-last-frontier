"""Small signed-distance-field toolkit for the procedural horse (numpy only).

Nodes evaluate an (approximate) signed distance on broadcastable arrays X, Y, Z
(negative inside). Only the zero level set has to be exact: polygonize() extracts
it with surface nets and project() pulls the vertices onto it with Newton steps,
so approximate distances (lofts) are fine as long as the sign is right and the
scale is roughly metric near the surface (smooth unions blend on it).

Space: Blender armature space, metres, z up, the horse faces -y.
"""

import math

import numpy as np

F32 = np.float32
MAXD = 0.25   # far value; must exceed any blend radius used in the tree


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


class Node:
    lo = None
    hi = None

    def __call__(self, X, Y, Z):
        return self.f(X, Y, Z)


def _box_of(nodes, pad):
    if any(n.lo is None for n in nodes):
        return None, None
    lo = np.min([n.lo for n in nodes], axis=0) - pad
    hi = np.max([n.hi for n in nodes], axis=0) + pad
    return lo, hi


def _inside_box(node, X, Y, Z, pad):
    """Boolean mask (broadcast shape) of points within node's box + pad, or None."""
    if node.lo is None:
        return None
    lo, hi = node.lo - pad, node.hi + pad
    return ((X >= lo[0]) & (X <= hi[0]) & (Y >= lo[1]) & (Y <= hi[1]) & (Z >= lo[2]) & (Z <= hi[2]))


# ---------------------------------------------------------------------------
# Leaves
# ---------------------------------------------------------------------------
class Ellipsoid(Node):
    """Approximate ellipsoid distance (iq). R columns = local axes in world."""

    def __init__(self, c, r, R=None):
        self.c = np.asarray(c, float)
        self.r = np.asarray(r, float)
        self.R = np.eye(3) if R is None else np.asarray(R, float)
        ext = np.sqrt(((self.R * self.r[None, :]) ** 2).sum(1))
        self.lo, self.hi = self.c - ext, self.c + ext

    def f(self, X, Y, Z):
        R, c = self.R, self.c
        dx, dy, dz = X - c[0], Y - c[1], Z - c[2]
        qx = R[0, 0] * dx + R[1, 0] * dy + R[2, 0] * dz
        qy = R[0, 1] * dx + R[1, 1] * dy + R[2, 1] * dz
        qz = R[0, 2] * dx + R[1, 2] * dy + R[2, 2] * dz
        rx, ry, rz = self.r
        k0 = np.sqrt((qx / rx) ** 2 + (qy / ry) ** 2 + (qz / rz) ** 2)
        k1 = np.sqrt((qx / (rx * rx)) ** 2 + (qy / (ry * ry)) ** 2 + (qz / (rz * rz)) ** 2)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


class RoundCone(Node):
    """Capsule from a (radius ra) to b (radius rb), iq's sdRoundCone."""

    def __init__(self, a, b, ra, rb):
        self.a, self.b = np.asarray(a, float), np.asarray(b, float)
        self.ra, self.rb = float(ra), float(rb)
        self.lo = np.minimum(self.a - ra, self.b - rb)
        self.hi = np.maximum(self.a + ra, self.b + rb)
        self.ba = self.b - self.a
        self.l2 = float(self.ba @ self.ba)
        self.rr = self.ra - self.rb
        self.a2 = self.l2 - self.rr * self.rr
        self.il2 = 1.0 / self.l2

    def f(self, X, Y, Z):
        a, ba, l2 = self.a, self.ba, self.l2
        px, py, pz = X - a[0], Y - a[1], Z - a[2]
        y = px * ba[0] + py * ba[1] + pz * ba[2]
        z = y - l2
        wx, wy, wz = px * l2 - ba[0] * y, py * l2 - ba[1] * y, pz * l2 - ba[2] * y
        x2 = wx * wx + wy * wy + wz * wz
        y2 = y * y * l2
        z2 = z * z * l2
        k = math.copysign(1.0, self.rr) * self.rr * self.rr * x2
        d_b = np.sqrt(x2 + z2) * self.il2 - self.rb
        d_a = np.sqrt(x2 + y2) * self.il2 - self.ra
        d_m = (np.sqrt(np.maximum(x2 * self.a2 * self.il2, 0.0)) + y * self.rr) * self.il2 - self.ra
        return np.where(np.sign(z) * self.a2 * z2 > k, d_b, np.where(np.sign(y) * self.a2 * y2 < k, d_a, d_m))


class Fn(Node):
    def __init__(self, fn, lo=None, hi=None):
        self.fn = fn
        self.lo = None if lo is None else np.asarray(lo, float)
        self.hi = None if hi is None else np.asarray(hi, float)

    def f(self, X, Y, Z):
        return self.fn(X, Y, Z)


def _interp_table(t, ts, vals):
    """Piecewise-linear interpolation of rows `vals` (n, k) at t (any shape) -> (..., k)."""
    t = np.clip(t, ts[0], ts[-1])
    out = []
    for k in range(vals.shape[1]):
        out.append(np.interp(t.ravel(), ts, vals[:, k]).reshape(t.shape))
    return out


class LoftY(Node):
    """Solid swept along y. Rows: y, z_top, z_bot, half_width, widest (0..1 from bottom),
    p_top, p_bot (superellipse exponents of the upper / lower half). The section at y is
    |x|/w and the vertical coordinate normalised separately above and below the widest
    level. Ends close where the table ends (elliptical caps of length `cap`)."""

    def __init__(self, rows, cap=0.10):
        self.T = np.asarray(rows, float)
        self.cap = cap
        ys = self.T[:, 0]
        self.lo = np.array([-self.T[:, 3].max(), ys[0] - cap, self.T[:, 2].min()])
        self.hi = np.array([self.T[:, 3].max(), ys[-1] + cap, self.T[:, 1].max()])

    def f(self, X, Y, Z):
        X, Y, Z = np.broadcast_arrays(X, Y, Z)
        ys = self.T[:, 0]
        zt, zb, w, wid, pt, pb = _interp_table(Y, ys, self.T[:, 1:])
        zw = zb + wid * (zt - zb)
        up = Z >= zw
        hz = np.where(up, zt - zw, zw - zb)
        p = np.where(up, pt, pb)
        u = np.abs(X) / w
        v = np.abs(Z - zw) / np.maximum(hz, 1e-4)
        rn = (u ** p + v ** p) ** (1.0 / p)
        # axial overshoot beyond the ends -> elliptical cap
        a0 = np.maximum(ys[0] - Y, 0.0) / self.cap
        a1 = np.maximum(Y - ys[-1], 0.0) / self.cap
        ax = np.maximum(a0, a1)
        rn = np.sqrt(rn * rn + ax * ax)
        scale = np.minimum(w, 0.5 * (zt - zb))
        return (rn - 1.0) * np.maximum(scale, 0.03)


class LoftZ(Node):
    """Solid swept along z (limbs that hang roughly vertically, such as the thigh and
    gaskin). Rows: z, cx, cy, half_width (x), half_front (towards -y), half_back (+y), p
    (superellipse exponent). Sections are horizontal; the ends close with elliptical caps
    of lengths `caps` (bottom, top). Unlike LoftPath there is no nearest-segment choice, so
    the field has no creases between rows."""

    def __init__(self, rows, caps=(0.03, 0.05)):
        self.T = np.asarray(rows, float)
        self.caps = caps
        zs = self.T[:, 0]
        r = self.T[:, 3:6].max()
        self.lo = np.array([self.T[:, 1].min() - r, self.T[:, 2].min() - r, zs[0] - caps[0]])
        self.hi = np.array([self.T[:, 1].max() + r, self.T[:, 2].max() + r, zs[-1] + caps[1]])

    def f(self, X, Y, Z):
        X, Y, Z = np.broadcast_arrays(X, Y, Z)
        zs = self.T[:, 0]
        cx, cy, hx, hf, hb, p = _interp_table(Z, zs, self.T[:, 1:])
        dy = Y - cy
        u = np.abs(X - cx) / hx
        v = np.where(dy < 0, -dy / hf, dy / hb)
        rn = (u ** p + v ** p) ** (1.0 / p)
        a0 = np.maximum(zs[0] - Z, 0.0) / self.caps[0]
        a1 = np.maximum(Z - zs[-1], 0.0) / self.caps[1]
        ax = np.maximum(a0, a1)
        rn = np.sqrt(rn * rn + ax * ax)
        scale = np.minimum(hx, 0.5 * (hf + hb))
        return (rn - 1.0) * np.maximum(scale, 0.02)


class LoftPath(Node):
    """Solid swept along a polyline. pts (n,3); up (n,3) dorsal direction per point;
    sections (n,4): half_width (lateral), half_up (towards `up`), half_down, p (exponent);
    an optional fifth column is the exponent of the lower half.
    Caps: `caps` (start, end) lengths of the elliptical end caps."""

    def __init__(self, pts, up, sections, caps=(0.05, 0.05)):
        self.P = np.asarray(pts, float)
        U = np.asarray(up, float)
        self.S = np.asarray(sections, float)
        n = len(self.P)
        T = np.zeros_like(self.P)
        T[1:-1] = self.P[2:] - self.P[:-2]
        T[0] = self.P[1] - self.P[0]
        T[-1] = self.P[-1] - self.P[-2]
        T /= np.linalg.norm(T, axis=1)[:, None]
        U = U - (U * T).sum(1)[:, None] * T
        U /= np.linalg.norm(U, axis=1)[:, None]
        self.T, self.U = T, U
        self.B = np.cross(T, U)
        self.caps = caps
        seg = np.linalg.norm(self.P[1:] - self.P[:-1], axis=1)
        self.s = np.concatenate([[0.0], np.cumsum(seg)])
        r = self.S[:, :3].max()
        self.lo = self.P.min(0) - r - max(caps)
        self.hi = self.P.max(0) + r + max(caps)

    def f(self, X, Y, Z):
        X, Y, Z = np.broadcast_arrays(X, Y, Z)
        shp = X.shape
        Q = np.stack([X.ravel(), Y.ravel(), Z.ravel()], 1)
        best_d = np.full(len(Q), np.inf)
        best_s = np.zeros(len(Q))
        best_i = np.zeros(len(Q), int)
        best_t = np.zeros(len(Q))
        last = len(self.P) - 2
        for i in range(len(self.P) - 1):
            a, b = self.P[i], self.P[i + 1]
            ab = b - a
            L2 = float((ab * ab).sum())
            t = ((Q - a) * ab).sum(1) / L2
            tc = np.clip(t, 0.0, 1.0)
            proj = a + tc[:, None] * ab
            d = np.linalg.norm(Q - proj, axis=1)
            m = d < best_d
            best_d[m] = d[m]
            best_i[m] = i
            # keep the overshoot before the start / after the end for the caps
            t_lo = -np.inf if i == 0 else 0.0
            t_hi = np.inf if i == last else 1.0
            best_t[m] = np.clip(t, t_lo, t_hi)[m]
        i = best_i
        t = best_t
        tt = np.clip(t, 0.0, 1.0)
        a = self.P[i]
        proj = a + t[:, None] * (self.P[i + 1] - a)
        rel = Q - proj
        # interpolated frame and section
        U = self.U[i] * (1 - tt)[:, None] + self.U[i + 1] * tt[:, None]
        B = self.B[i] * (1 - tt)[:, None] + self.B[i + 1] * tt[:, None]
        U /= np.linalg.norm(U, axis=1)[:, None]
        B /= np.linalg.norm(B, axis=1)[:, None]
        S = self.S[i] * (1 - tt)[:, None] + self.S[i + 1] * tt[:, None]
        # axial overshoot (only at the two ends)
        Tn = self.P[i + 1] - self.P[i]
        Ln = np.linalg.norm(Tn, axis=1)
        over = np.where(t < 0, -t * Ln, np.where(t > 1, (t - 1) * Ln, 0.0))
        cap = np.where(t < 0.5, self.caps[0], self.caps[1])
        u = (rel * U).sum(1)
        b = (rel * B).sum(1)
        # remove the axial part from rel for the section coordinates (already orthogonal
        # for interior points; for end overshoot the axial part is `over`)
        hw, hu, hd, p = S[:, 0], S[:, 1], S[:, 2], S[:, 3]
        hv = np.where(u >= 0, hu, hd)
        if S.shape[1] > 4:           # optional exponent of the lower (-up) half
            p = np.where(u >= 0, p, S[:, 4])
        rn = ((np.abs(b) / hw) ** p + (np.abs(u) / hv) ** p) ** (1.0 / p)
        rn = np.sqrt(rn * rn + (over / cap) ** 2)
        scale = np.minimum(hw, 0.5 * (hu + hd))
        return ((rn - 1.0) * np.maximum(scale, 0.02)).reshape(shp)


# ---------------------------------------------------------------------------
# Operators
# ---------------------------------------------------------------------------
class Union(Node):
    def __init__(self, kids, k=0.0):
        self.kids = [c for c in kids if c is not None]
        self.k = float(k)
        self.lo, self.hi = _box_of(self.kids, self.k)

    def f(self, X, Y, Z):
        X, Y, Z = np.broadcast_arrays(X, Y, Z)
        acc = np.full(X.shape, MAXD)
        for c in self.kids:
            m = _inside_box(c, X, Y, Z, MAXD * 0.5)
            if m is None:
                acc = smin(acc, np.minimum(c.f(X, Y, Z), MAXD), self.k)
            elif m.any():
                v = np.minimum(c.f(X[m], Y[m], Z[m]), MAXD)
                acc[m] = smin(acc[m], v, self.k)
        return acc


class Inter(Node):
    def __init__(self, a, b, k=0.0):
        self.a, self.b, self.k = a, b, float(k)
        if a.lo is None:
            self.lo, self.hi = b.lo, b.hi
        elif b.lo is None:
            self.lo, self.hi = a.lo, a.hi
        else:
            self.lo, self.hi = np.maximum(a.lo, b.lo), np.minimum(a.hi, b.hi)

    def f(self, X, Y, Z):
        return smax(self.a.f(X, Y, Z), self.b.f(X, Y, Z), self.k)


class Sub(Node):
    def __init__(self, a, b, k=0.0):
        self.a, self.b, self.k = a, b, float(k)
        self.lo, self.hi = a.lo, a.hi

    def f(self, X, Y, Z):
        return smax(self.a.f(X, Y, Z), -self.b.f(X, Y, Z), self.k)


class Offset(Node):
    """a - r (r float or fn(X, Y, Z)); r_max bounds the box growth."""

    def __init__(self, a, r, r_max=None):
        self.a, self.r = a, r
        rm = r if r_max is None else r_max
        self.lo = None if a.lo is None else a.lo - rm
        self.hi = None if a.hi is None else a.hi + rm

    def f(self, X, Y, Z):
        rr = self.r(X, Y, Z) if callable(self.r) else self.r
        return self.a.f(X, Y, Z) - rr


class Onion(Node):
    def __init__(self, a, t):
        self.a, self.t = a, float(t)
        self.lo = None if a.lo is None else a.lo - t
        self.hi = None if a.hi is None else a.hi + t

    def f(self, X, Y, Z):
        return np.abs(self.a.f(X, Y, Z)) - self.t


class Bounded(Node):
    """Restrict a node's box (for unbounded CSG results)."""

    def __init__(self, a, lo, hi):
        self.a = a
        self.lo, self.hi = np.asarray(lo, float), np.asarray(hi, float)

    def f(self, X, Y, Z):
        return self.a.f(X, Y, Z)


class Scaled(Node):
    """`a` stretched by K = (kx, ky, kz) about the origin (a is evaluated at p / K). The
    distance is rescaled by min(K), a lower bound for mild anisotropy, which is enough for
    the zero set, the gradient direction and the Newton projection."""

    def __init__(self, a, K):
        self.a = a
        self.K = np.asarray(K, float)
        self.m = float(self.K.min())
        self.lo = None if a.lo is None else a.lo * self.K
        self.hi = None if a.hi is None else a.hi * self.K

    def f(self, X, Y, Z):
        return self.a.f(X / self.K[0], Y / self.K[1], Z / self.K[2]) * self.m


# ---------------------------------------------------------------------------
# Polygonisation (surface nets) and projection
# ---------------------------------------------------------------------------
def grid_eval(node, lo, hi, h, symmetric_x=True, chunk=24):
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    if symmetric_x:
        ext = max(abs(lo[0]), abs(hi[0]))
        nx = int(math.ceil(2 * ext / h)) + 3
        xs = h * (np.arange(nx) - (nx - 1) / 2.0)
    else:
        xs = lo[0] - h + h * np.arange(int(math.ceil((hi[0] - lo[0]) / h)) + 3)
    ys = lo[1] - h + h * np.arange(int(math.ceil((hi[1] - lo[1]) / h)) + 3)
    zs = lo[2] - h + h * np.arange(int(math.ceil((hi[2] - lo[2]) / h)) + 3)
    F = np.empty((len(xs), len(ys), len(zs)), F32)
    for k0 in range(0, len(zs), chunk):
        zz = zs[k0:k0 + chunk]
        X, Y, Z = np.meshgrid(xs, ys, zz, indexing="ij")
        F[:, :, k0:k0 + len(zz)] = np.minimum(node.f(X, Y, Z), MAXD)
    return F, xs, ys, zs


def surface_nets(F, xs, ys, zs):
    """Vertices (one per sign-changing cell, mean of edge crossings) and quads."""
    s = F < 0
    nx, ny, nz = F.shape
    cell_id = -np.ones((nx - 1, ny - 1, nz - 1), np.int64)
    acc = np.zeros((nx - 1, ny - 1, nz - 1, 3))
    cnt = np.zeros((nx - 1, ny - 1, nz - 1))
    h = (xs[1] - xs[0], ys[1] - ys[0], zs[1] - zs[0])
    # edges along each axis: crossing point, add to the 4 adjacent cells
    for ax in range(3):
        sl0 = [slice(None)] * 3
        sl1 = [slice(None)] * 3
        sl0[ax] = slice(0, -1)
        sl1[ax] = slice(1, None)
        f0, f1 = F[tuple(sl0)], F[tuple(sl1)]
        ch = (f0 < 0) != (f1 < 0)
        idx = np.nonzero(ch)
        t = f0[idx] / (f0[idx] - f1[idx])
        p = np.stack([xs[idx[0]], ys[idx[1]], zs[idx[2]]], 1).astype(float)
        p[:, ax] += t * h[ax]
        others = [a for a in range(3) if a != ax]
        for da in (0, 1):
            for db in (0, 1):
                c = [idx[0].copy(), idx[1].copy(), idx[2].copy()]
                c[others[0]] = c[others[0]] - da
                c[others[1]] = c[others[1]] - db
                ok = ((c[0] >= 0) & (c[0] < nx - 1) & (c[1] >= 0) & (c[1] < ny - 1) & (c[2] >= 0) & (c[2] < nz - 1))
                cc = (c[0][ok], c[1][ok], c[2][ok])
                np.add.at(acc, cc, p[ok])
                np.add.at(cnt, cc, 1.0)
    act = cnt > 0
    V = acc[act] / cnt[act][:, None]
    cell_id[act] = np.arange(act.sum())
    quads = []
    for ax in range(3):
        sl0 = [slice(None)] * 3
        sl1 = [slice(None)] * 3
        sl0[ax] = slice(0, -1)
        sl1[ax] = slice(1, None)
        f0, f1 = F[tuple(sl0)], F[tuple(sl1)]
        ch = (f0 < 0) != (f1 < 0)
        idx = np.array(np.nonzero(ch))
        inside_first = (f0 < 0)[ch]
        others = [a for a in range(3) if a != ax]
        ok = (idx[others[0]] >= 1) & (idx[others[1]] >= 1) & (idx[others[0]] < F.shape[others[0]] - 1) & \
             (idx[others[1]] < F.shape[others[1]] - 1)
        idx = idx[:, ok]
        inside_first = inside_first[ok]
        cells = []
        for da, db in ((0, 0), (1, 0), (1, 1), (0, 1)):
            c = idx.copy()
            c[others[0]] -= da
            c[others[1]] -= db
            cells.append(cell_id[c[0], c[1], c[2]])
        q = np.stack(cells, 1)
        # orientation: outward normal points from inside (negative) to outside
        flip = inside_first if ax != 1 else ~inside_first
        q[flip] = q[flip][:, ::-1]
        quads.append(q)
    Q = np.concatenate(quads, 0)
    Q = Q[(Q >= 0).all(1)]
    return V, Q


def gradient(node, P, e=4e-4):
    g = np.zeros_like(P)
    for a in range(3):
        d = np.zeros(3)
        d[a] = e
        g[:, a] = (node.f(*(P + d).T) - node.f(*(P - d).T)) / (2 * e)
    return g


def project(node, P, iters=3, step_max=0.004):
    P = P.copy()
    for _ in range(iters):
        d = node.f(*P.T)
        g = gradient(node, P)
        gn = (g * g).sum(1)
        step = (d / np.maximum(gn, 1e-8))[:, None] * g
        n = np.linalg.norm(step, axis=1)
        step *= np.minimum(1.0, step_max / np.maximum(n, 1e-12))[:, None]
        P -= step
    return P


def polygonize(node, h, lo=None, hi=None, symmetric_x=True, iters=3):
    lo = node.lo if lo is None else lo
    hi = node.hi if hi is None else hi
    F, xs, ys, zs = grid_eval(node, np.asarray(lo) - 2 * h, np.asarray(hi) + 2 * h, h, symmetric_x)
    V, Q = surface_nets(F, xs, ys, zs)
    if iters:
        V = project(node, V, iters, step_max=h * 0.6)
    return V, Q
