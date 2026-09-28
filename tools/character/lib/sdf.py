"""Signed distance fields, polygonisation and small vector helpers.

Split out of tools/character/build_body.py (lib v1); the code is unchanged.
Shapes are SDF node trees (Leaf / Union / SymUnion / Inter / Sub / Offset / Onion)
evaluated on a grid (geval) or at points (peval). Everything is in Blender armature
space (z up, the character faces -y) at the bind pose null-add.
"""

import math
import time

import numpy as np

F32 = np.float32
# SDF values are clamped to MAXD, and a shape is only evaluated within MAXD of
# its bounding box. MAXD must exceed the sum of the blend radii and offsets on
# any path through the tree, or clamping would shift blended surfaces.
MAXD = 0.15
T0 = time.time()
_LOG_TAG = ["character"]


def set_log_tag(tag):
    """Prefix of log() lines (the running generator's name)."""
    _LOG_TAG[0] = tag


def log(*a):
    print("[%s %6.1fs]" % (_LOG_TAG[0], time.time() - T0), *a, flush=True)


# ===========================================================================
# Signed distance fields
# ===========================================================================
def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * (k * 0.25)


def smax(a, b, k):
    return -smin(-a, -b, k)


class Node:
    lo = None   # tight bounding box (None = unbounded)
    hi = None
    tag = ""


def _union_box(boxes, pad):
    if any(b[0] is None for b in boxes):
        return None, None
    lo = np.min([b[0] for b in boxes], axis=0) - pad
    hi = np.max([b[1] for b in boxes], axis=0) + pad
    return lo, hi


class Leaf(Node):
    def f(self, X, Y, Z):
        raise NotImplementedError


class Sphere(Leaf):
    def __init__(self, c, r):
        self.c = np.asarray(c, float)
        self.r = float(r)
        self.lo, self.hi = self.c - r, self.c + r

    def f(self, X, Y, Z):
        c = self.c
        return np.sqrt((X - c[0]) ** 2 + (Y - c[1]) ** 2 + (Z - c[2]) ** 2) - self.r


def _local(R, c, X, Y, Z):
    dx, dy, dz = X - c[0], Y - c[1], Z - c[2]
    return (R[0, 0] * dx + R[1, 0] * dy + R[2, 0] * dz,
            R[0, 1] * dx + R[1, 1] * dy + R[2, 1] * dz,
            R[0, 2] * dx + R[1, 2] * dy + R[2, 2] * dz)


class Ellipsoid(Leaf):
    """Approximate ellipsoid distance (iq). R columns = local axes (world)."""

    def __init__(self, c, r, R=None):
        self.c = np.asarray(c, float)
        self.r = np.asarray(r, float)
        self.R = np.eye(3) if R is None else np.asarray(R, float)
        ext = np.sqrt(((self.R * self.r[None, :]) ** 2).sum(1))
        self.lo, self.hi = self.c - ext, self.c + ext

    def f(self, X, Y, Z):
        qx, qy, qz = _local(self.R, self.c, X, Y, Z)
        rx, ry, rz = self.r
        k0 = np.sqrt((qx / rx) ** 2 + (qy / ry) ** 2 + (qz / rz) ** 2)
        k1 = np.sqrt((qx / (rx * rx)) ** 2 + (qy / (ry * ry)) ** 2 + (qz / (rz * rz)) ** 2)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


class RoundCone(Leaf):
    """Capsule with different end radii (iq's exact sdRoundCone)."""

    def __init__(self, a, b, ra, rb):
        self.a = np.asarray(a, float)
        self.b = np.asarray(b, float)
        self.ra, self.rb = float(ra), float(rb)
        self.lo = np.minimum(self.a - ra, self.b - rb)
        self.hi = np.maximum(self.a + ra, self.b + rb)
        ba = self.b - self.a
        self.ba = ba
        self.l2 = float(ba @ ba)
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


class RoundBox(Leaf):
    def __init__(self, c, half, r, R=None):
        self.c = np.asarray(c, float)
        self.half = np.asarray(half, float)
        self.r = float(r)
        self.R = np.eye(3) if R is None else np.asarray(R, float)
        ext = (np.abs(self.R) * self.half[None, :]).sum(1)
        self.lo, self.hi = self.c - ext, self.c + ext

    def f(self, X, Y, Z):
        qx, qy, qz = _local(self.R, self.c, X, Y, Z)
        b = self.half - self.r
        dx, dy, dz = np.abs(qx) - b[0], np.abs(qy) - b[1], np.abs(qz) - b[2]
        out = np.sqrt(np.maximum(dx, 0) ** 2 + np.maximum(dy, 0) ** 2 + np.maximum(dz, 0) ** 2)
        return out + np.minimum(np.maximum(dx, np.maximum(dy, dz)), 0.0) - self.r


class Plane(Leaf):
    """Half space n.p <= d is inside (unbounded)."""

    def __init__(self, n, p0):
        n = np.asarray(n, float)
        self.n = n / np.linalg.norm(n)
        self.d = float(self.n @ np.asarray(p0, float))

    def f(self, X, Y, Z):
        return self.n[0] * X + self.n[1] * Y + self.n[2] * Z - self.d


class Fn(Leaf):
    """Arbitrary field fn(X, Y, Z) with an optional bounding box."""

    def __init__(self, fn, lo=None, hi=None):
        self.fn = fn
        self.lo = None if lo is None else np.asarray(lo, float)
        self.hi = None if hi is None else np.asarray(hi, float)

    def f(self, X, Y, Z):
        return self.fn(X, Y, Z)


class Union(Node):
    def __init__(self, kids, k=0.0, tag=""):
        self.kids = [c for c in kids if c is not None]
        self.k = float(k)
        self.tag = tag
        # smin(a, b, k) >= min(a, b) - k/4, so the union grows at most k/4
        self.lo, self.hi = _union_box([(c.lo, c.hi) for c in self.kids], self.k * 0.25)


class SymUnion(Node):
    """Smooth union of a centre shape with a mirrored left/right pair. The
    polynomial smooth-min is order dependent, so both orders are averaged to
    keep the result exactly mirror symmetric."""

    def __init__(self, center, left, right, k):
        self.c, self.l, self.r, self.k = center, left, right, float(k)
        self.lo, self.hi = _union_box([(n.lo, n.hi) for n in (center, left, right)], self.k * 0.25)


class Inter(Node):
    def __init__(self, a, b, k=0.0):
        self.a, self.b, self.k = a, b, float(k)
        if a.lo is None:
            self.lo, self.hi = b.lo, b.hi
        elif b.lo is None:
            self.lo, self.hi = a.lo, a.hi
        else:
            self.lo, self.hi = np.maximum(a.lo, b.lo), np.minimum(a.hi, b.hi)


class Sub(Node):
    def __init__(self, a, b, k=0.0):
        self.a, self.b, self.k = a, b, float(k)
        self.lo, self.hi = a.lo, a.hi


class Offset(Node):
    """child - r ; r is a float or fn(X, Y, Z) (r_max bounds it)."""

    def __init__(self, a, r, r_max=None):
        self.a, self.r = a, r
        rm = r if r_max is None else r_max
        self.lo = None if a.lo is None else a.lo - rm
        self.hi = None if a.hi is None else a.hi + rm


class Onion(Node):
    def __init__(self, a, t):
        self.a, self.t = a, float(t)
        self.lo = None if a.lo is None else a.lo - t
        self.hi = None if a.hi is None else a.hi + t


class Grid:
    def __init__(self, lo, hi, h, symmetric_x=True):
        self.h = h
        lo, hi = np.asarray(lo, float), np.asarray(hi, float)
        if symmetric_x:
            ext = max(abs(lo[0]), abs(hi[0]))
            nx = int(math.ceil(2 * ext / h)) + 3
            self.xs = (h * (np.arange(nx) - (nx - 1) / 2.0)).astype(F32)
        else:
            nx = int(math.ceil((hi[0] - lo[0]) / h)) + 3
            self.xs = (lo[0] - h + h * np.arange(nx)).astype(F32)
        ny = int(math.ceil((hi[1] - lo[1]) / h)) + 3
        nz = int(math.ceil((hi[2] - lo[2]) / h)) + 3
        self.ys = (lo[1] - h + h * np.arange(ny)).astype(F32)
        self.zs = (lo[2] - h + h * np.arange(nz)).astype(F32)
        self.full = (0, len(self.xs), 0, len(self.ys), 0, len(self.zs))

    def ranges(self, lo, hi, pad):
        if lo is None:
            return self.full
        out = []
        for ax, arr in enumerate((self.xs, self.ys, self.zs)):
            a0, h = float(arr[0]), self.h
            i0 = int(math.floor((lo[ax] - pad - a0) / h))
            i1 = int(math.ceil((hi[ax] + pad - a0) / h)) + 1
            out += [max(0, i0), min(len(arr), i1)]
        return tuple(out)


def _isect(r, s):
    return (max(r[0], s[0]), min(r[1], s[1]), max(r[2], s[2]), min(r[3], s[3]), max(r[4], s[4]), min(r[5], s[5]))


def _empty(r):
    return r[1] <= r[0] or r[3] <= r[2] or r[5] <= r[4]


def _rel(inner, outer):
    return (slice(inner[0] - outer[0], inner[1] - outer[0]), slice(inner[2] - outer[2], inner[3] - outer[2]),
            slice(inner[4] - outer[4], inner[5] - outer[4]))


def _shape(r):
    return (r[1] - r[0], r[3] - r[2], r[5] - r[4])


def geval(node, G, reg):
    """Field of `node` on grid region `reg` (float32, clamped to MAXD)."""
    out = np.full(_shape(reg), MAXD, F32)
    r = _isect(reg, G.ranges(node.lo, node.hi, MAXD))
    if _empty(r):
        return out
    out[_rel(r, reg)] = _geval_inner(node, G, r)
    return out


def _xyz(G, r):
    return (G.xs[r[0]:r[1]][:, None, None], G.ys[r[2]:r[3]][None, :, None], G.zs[r[4]:r[5]][None, None, :])


def _geval_inner(node, G, r):
    if isinstance(node, Leaf):
        X, Y, Z = _xyz(G, r)
        v = node.f(X, Y, Z)
        v = np.broadcast_to(v, _shape(r))
        return np.minimum(v, MAXD).astype(F32)
    if isinstance(node, Union):
        acc = np.full(_shape(r), MAXD, F32)
        for c in node.kids:
            cr = _isect(r, G.ranges(c.lo, c.hi, MAXD))
            if _empty(cr):
                continue
            sl = _rel(cr, r)
            acc[sl] = smin(acc[sl], _geval_inner(c, G, cr), node.k)
        return acc
    if isinstance(node, SymUnion):
        c = geval(node.c, G, r)
        acc1, acc2 = c.copy(), c
        parts = []
        for side in (node.l, node.r):
            cr = _isect(r, G.ranges(side.lo, side.hi, MAXD))
            parts.append(None if _empty(cr) else (_rel(cr, r), _geval_inner(side, G, cr)))
        for acc, order in ((acc1, parts), (acc2, parts[::-1])):
            for p in order:
                if p is not None:
                    acc[p[0]] = smin(acc[p[0]], p[1], node.k)
        return (0.5 * (acc1 + acc2)).astype(F32)
    if isinstance(node, Inter):
        return np.minimum(smax(geval(node.a, G, r), geval(node.b, G, r), node.k), MAXD).astype(F32)
    if isinstance(node, Sub):
        return smax(geval(node.a, G, r), -geval(node.b, G, r), node.k).astype(F32)
    if isinstance(node, Offset):
        a = geval(node.a, G, r)
        rr = node.r(*_xyz(G, r)) if callable(node.r) else node.r
        return np.minimum(a - rr, MAXD).astype(F32)
    if isinstance(node, Onion):
        return np.minimum(np.abs(geval(node.a, G, r)) - node.t, MAXD).astype(F32)
    raise TypeError(node)


def _pmask(node, P):
    if node.lo is None:
        return None
    return np.all((P >= node.lo - MAXD) & (P <= node.hi + MAXD), axis=1)


def peval(node, P):
    """Field of `node` at points P (N, 3); same clamping/skipping as geval."""
    m = _pmask(node, P)
    if m is None:
        return _peval_inner(node, P)
    out = np.full(len(P), MAXD)
    if m.any():
        out[m] = _peval_inner(node, P[m])
    return out


def _peval_inner(node, P):
    if isinstance(node, Leaf):
        v = node.f(P[:, 0], P[:, 1], P[:, 2])
        return np.minimum(np.broadcast_to(v, (len(P),)), MAXD)
    if isinstance(node, Union):
        acc = np.full(len(P), MAXD)
        for c in node.kids:
            m = _pmask(c, P)
            if m is None:
                acc = smin(acc, _peval_inner(c, P), node.k)
            elif m.any():
                acc[m] = smin(acc[m], _peval_inner(c, P[m]), node.k)
        return acc
    if isinstance(node, SymUnion):
        c = peval(node.c, P)
        out = []
        for order in ((node.l, node.r), (node.r, node.l)):
            acc = c.copy()
            for s in order:
                m = _pmask(s, P)
                if m.any():
                    acc[m] = smin(acc[m], _peval_inner(s, P[m]), node.k)
            out.append(acc)
        return 0.5 * (out[0] + out[1])
    if isinstance(node, Inter):
        return np.minimum(smax(peval(node.a, P), peval(node.b, P), node.k), MAXD)
    if isinstance(node, Sub):
        return smax(peval(node.a, P), -peval(node.b, P), node.k)
    if isinstance(node, Offset):
        rr = node.r(P[:, 0], P[:, 1], P[:, 2]) if callable(node.r) else node.r
        return np.minimum(peval(node.a, P) - rr, MAXD)
    if isinstance(node, Onion):
        return np.minimum(np.abs(peval(node.a, P)) - node.t, MAXD)
    raise TypeError(node)


def surface_nets(F, xs, ys, zs):
    """Naive surface nets on a sampled field (inside = F < 0). Returns vertices and quads."""
    inside = F < 0
    nx, ny, nz = F.shape
    ncx, ncy, ncz = nx - 1, ny - 1, nz - 1

    def cid(i, j, k):
        return (i.astype(np.int64) * ncy + j) * ncz + k

    cells, pts, quads = [], [], []
    # x edges
    i, j, k = np.nonzero(inside[:-1] != inside[1:])
    t = F[i, j, k] / (F[i, j, k] - F[i + 1, j, k])
    P = np.stack([xs[i] + t * (xs[i + 1] - xs[i]), ys[j], zs[k]], 1)
    for dj in (-1, 0):
        for dk in (-1, 0):
            jj, kk = j + dj, k + dk
            ok = (jj >= 0) & (jj < ncy) & (kk >= 0) & (kk < ncz)
            cells.append(cid(i[ok], jj[ok], kk[ok]))
            pts.append(P[ok])
    ok = (j >= 1) & (j < ncy) & (k >= 1) & (k < ncz)
    a, b, c = i[ok], j[ok], k[ok]
    q = np.stack([cid(a, b - 1, c - 1), cid(a, b, c - 1), cid(a, b, c), cid(a, b - 1, c)], 1)
    fl = ~inside[a, b, c]
    q[fl] = q[fl][:, ::-1]
    quads.append(q)
    # y edges
    i, j, k = np.nonzero(inside[:, :-1] != inside[:, 1:])
    t = F[i, j, k] / (F[i, j, k] - F[i, j + 1, k])
    P = np.stack([xs[i], ys[j] + t * (ys[j + 1] - ys[j]), zs[k]], 1)
    for di in (-1, 0):
        for dk in (-1, 0):
            ii, kk = i + di, k + dk
            ok = (ii >= 0) & (ii < ncx) & (kk >= 0) & (kk < ncz)
            cells.append(cid(ii[ok], j[ok], kk[ok]))
            pts.append(P[ok])
    ok = (i >= 1) & (i < ncx) & (k >= 1) & (k < ncz)
    a, b, c = i[ok], j[ok], k[ok]
    q = np.stack([cid(a - 1, b, c - 1), cid(a - 1, b, c), cid(a, b, c), cid(a, b, c - 1)], 1)
    fl = ~inside[a, b, c]
    q[fl] = q[fl][:, ::-1]
    quads.append(q)
    # z edges
    i, j, k = np.nonzero(inside[:, :, :-1] != inside[:, :, 1:])
    t = F[i, j, k] / (F[i, j, k] - F[i, j, k + 1])
    P = np.stack([xs[i], ys[j], zs[k] + t * (zs[k + 1] - zs[k])], 1)
    for di in (-1, 0):
        for dj in (-1, 0):
            ii, jj = i + di, j + dj
            ok = (ii >= 0) & (ii < ncx) & (jj >= 0) & (jj < ncy)
            cells.append(cid(ii[ok], jj[ok], k[ok]))
            pts.append(P[ok])
    ok = (i >= 1) & (i < ncx) & (j >= 1) & (j < ncy)
    a, b, c = i[ok], j[ok], k[ok]
    q = np.stack([cid(a - 1, b - 1, c), cid(a, b - 1, c), cid(a, b, c), cid(a - 1, b, c)], 1)
    fl = ~inside[a, b, c]
    q[fl] = q[fl][:, ::-1]
    quads.append(q)

    cells = np.concatenate(cells)
    pts = np.concatenate(pts).astype(np.float64)
    uc, inv = np.unique(cells, return_inverse=True)
    cnt = np.bincount(inv).astype(np.float64)
    V = np.stack([np.bincount(inv, weights=pts[:, d]) for d in range(3)], 1) / cnt[:, None]
    Q = np.searchsorted(uc, np.concatenate(quads))
    return V, Q


def project_to_surface(node, V, step_max, iters=3, h=4e-4):
    for _ in range(iters):
        f = peval(node, V)
        g = np.zeros_like(V)
        for d in range(3):
            e = np.zeros(3)
            e[d] = h
            g[:, d] = (peval(node, V + e) - peval(node, V - e)) / (2 * h)
        g2 = np.maximum((g * g).sum(1), 1e-4)
        s = np.clip(f / g2, -step_max, step_max)
        V = V - g * s[:, None]
    return V


def polygonize(node, h, name):
    lo, hi = node.lo - 3 * h, node.hi + 3 * h
    G = Grid(lo, hi, h)
    t = time.time()
    F = geval(node, G, G.full)
    F[0, :, :] = F[-1, :, :] = F[:, 0, :] = F[:, -1, :] = F[:, :, 0] = F[:, :, -1] = MAXD
    V, Q = surface_nets(F, G.xs.astype(np.float64), G.ys.astype(np.float64), G.zs.astype(np.float64))
    V = project_to_surface(node, V, step_max=h * 0.75)
    log("  %-12s grid %s  %d verts %d quads (%.1fs)" % (name, F.shape, len(V), len(Q), time.time() - t))
    return V, Q


# ===========================================================================
# Small vector helpers
# ===========================================================================
def v3(*a):
    return np.array(a if len(a) == 3 else a[0], float)


def nrm(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def frame_from(z_axis, x_hint):
    """Rotation matrix (columns x, y, z) with z along z_axis and x close to x_hint."""
    z = nrm(z_axis)
    x = np.asarray(x_hint, float) - z * (np.asarray(x_hint, float) @ z)
    x = nrm(x)
    y = np.cross(z, x)
    return np.stack([x, y, z], 1)


def lerp(a, b, t):
    return np.asarray(a) + (np.asarray(b) - np.asarray(a)) * t


def mirror_x(p):
    p = np.array(p, float)
    p[..., 0] *= -1
    return p


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ===========================================================================
# Outfit shapes (18th-century frontier ranger)
# ===========================================================================
def zslab(z0, z1):
    return Fn(lambda X, Y, Z: np.maximum(z0 - Z, Z - z1), (-2, -2, z0), (2, 2, z1))


def xband(xmax):
    return Fn(lambda X, Y, Z: np.abs(X) - xmax, (-xmax, -2, -1), (xmax, 2, 3))


def cut_plane(point, keep_dir):
    """Half space keeping points p with keep_dir.(p - point) >= 0."""
    return Plane(-np.asarray(keep_dir, float), point)


def surface_point(node, p, d, t0=0.0, t1=0.25):
    """First crossing of the zero set along p + t*d (outside -> inside search from t1 to t0)."""
    p, d = np.asarray(p, float), nrm(d)
    a, b = t0, t1
    for _ in range(50):
        m = 0.5 * (a + b)
        if peval(node, (p + d * m)[None])[0] < 0:
            b = m
        else:
            a = m
    return p + d * a


def sdf_normal(node, p, h=5e-4):
    g = np.array([(peval(node, (p + e * h)[None])[0] - peval(node, (p - e * h)[None])[0]) for e in np.eye(3)])
    return nrm(g)
