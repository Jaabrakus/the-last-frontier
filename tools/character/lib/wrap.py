"""Wrap transfer of the body's shape keys (sex, face_*) onto garments, hair and hats
(design §7.6), plus nearest-point queries on the body surface.

    surf = wrap.Surface(body.V, body.F, shapes=body.shapes)       # base body + deltas
    bind = surf.bind(P)                                            # garment vertices
    d_sex = surf.shape_delta(bind, "sex", smooth_E=E)             # (n, 3) deltas

Each garment vertex is bound to its nearest body triangle (barycentrics) with its offset
in that triangle's frame (interpolated normal, first edge as tangent). For a body shape
the frame is rebuilt on the shaped body and the offset re-applied, so every layer
follows the same displacement field and keeps its clearance to first order. Optional
smoothing over the garment's edges removes jumps where the nearest triangle changes
(between the arm and the ribs, at the crotch).
"""

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def vertex_normals(V, F):
    N = np.zeros_like(V)
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    for k in range(3):
        np.add.at(N, F[:, k], fn)
    return N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)


class Binding:
    def __init__(self, tri, bary, local, dist):
        self.tri, self.bary, self.local, self.dist = tri, bary, local, dist


class Surface:
    def __init__(self, V, F, shapes=None, allowed=None):
        """V (n, 3), F (m, 3) triangles; shapes {name: (n, 3) delta}; allowed: optional
        boolean mask of triangles that may be bound to (e.g. torso-only)."""
        self.V = np.asarray(V, float)
        self.F = np.asarray(F, int)
        self.shapes = shapes or {}
        self.N = vertex_normals(self.V, self.F)
        self.tri_ids = np.arange(len(self.F)) if allowed is None else np.nonzero(allowed)[0]
        self.bvh = BVHTree.FromPolygons([tuple(v) for v in self.V], [tuple(t) for t in self.F[self.tri_ids]],
                                        all_triangles=True)

    def nearest(self, P):
        """(triangle index, barycentrics (n, 3), nearest point (n, 3), distance)."""
        P = np.asarray(P, float)
        tri = np.zeros(len(P), int)
        bary = np.zeros((len(P), 3))
        Q = np.zeros_like(P)
        dist = np.zeros(len(P))
        for i, p in enumerate(P):
            loc, nor, fi, d = self.bvh.find_nearest(Vector(p))
            t = self.tri_ids[fi]
            a, b, c = self.V[self.F[t]]
            v0, v1, v2 = b - a, c - a, np.array(loc) - a
            d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
            d20, d21 = v2 @ v0, v2 @ v1
            den = max(d00 * d11 - d01 * d01, 1e-18)
            v = (d11 * d20 - d01 * d21) / den
            w = (d00 * d21 - d01 * d20) / den
            bc = np.clip([1 - v - w, v, w], 0, 1)
            bc /= bc.sum()
            tri[i], bary[i], Q[i], dist[i] = t, bc, loc, d
        return tri, bary, Q, dist

    def interpolate(self, values, tri, bary):
        """Barycentric interpolation of per-vertex `values` (n, k) at bound points."""
        return np.einsum("ij,ijk->ik", bary, np.asarray(values)[self.F[tri]])

    def _frames(self, V, N, tri, bary):
        q = np.einsum("ij,ijk->ik", bary, V[self.F[tri]])
        n = np.einsum("ij,ijk->ik", bary, N[self.F[tri]])
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
        e = V[self.F[tri, 1]] - V[self.F[tri, 0]]
        t1 = e - n * (e * n).sum(1, keepdims=True)
        t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-12)
        t2 = np.cross(n, t1)
        return q, t1, t2, n

    def bind(self, P):
        P = np.asarray(P, float)
        tri, bary, _, dist = self.nearest(P)
        q, t1, t2, n = self._frames(self.V, self.N, tri, bary)
        r = P - q
        local = np.stack([(r * t1).sum(1), (r * t2).sum(1), (r * n).sum(1)], 1)
        return Binding(tri, bary, local, dist)

    def shaped(self, name, weight=1.0):
        return self.V + weight * self.shapes[name]

    def shape_delta(self, b, name, smooth_E=None, smooth_iters=4, P=None, falloff=None):
        """Delta of bound points for body shape `name`. smooth_E: (e, 2) edges of the bound
        mesh for Laplacian smoothing of the delta field. falloff: optional per-point
        factor (0..1)."""
        Vs = self.V + self.shapes[name]
        Ns = vertex_normals(Vs, self.F)
        q0, a1, a2, an = self._frames(self.V, self.N, b.tri, b.bary)
        q1, b1, b2, bn = self._frames(Vs, Ns, b.tri, b.bary)
        L = b.local
        p0 = q0 + a1 * L[:, :1] + a2 * L[:, 1:2] + an * L[:, 2:]
        p1 = q1 + b1 * L[:, :1] + b2 * L[:, 1:2] + bn * L[:, 2:]
        D = p1 - p0
        if smooth_E is not None and len(smooth_E):
            D = smooth_field(D, smooth_E, smooth_iters)
        if falloff is not None:
            D = D * np.asarray(falloff)[:, None]
        return D


def smooth_field(D, E, iters, alpha=0.5, lock=None):
    """Laplacian smoothing of a per-vertex field over edges E."""
    n = len(D)
    deg = np.bincount(E.ravel(), minlength=n).astype(float)
    for _ in range(iters):
        acc = np.zeros_like(D)
        np.add.at(acc, E[:, 0], D[E[:, 1]])
        np.add.at(acc, E[:, 1], D[E[:, 0]])
        Dn = (1 - alpha) * D + alpha * acc / np.maximum(deg, 1)[:, None]
        Dn[deg == 0] = D[deg == 0]
        if lock is not None:
            Dn[lock] = D[lock]
        D = Dn
    return D
