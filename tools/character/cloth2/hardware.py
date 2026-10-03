"""cloth2 hardware: points bound to a mesh in every fit, and rigid pieces (buttons, buckles, a cockade, a knot, a
pouch, a ring) placed on them (2026-10-02).

  b = Binding(m, P)                     # points P (k, 3) of the reference fit -> the nearest point of mesh `m`
                                        #   (face, barycentrics, offset along the face normal)
  pos, nrm = b.at(m, fit)               # the same points and the face normals in another fit (same barycentrics)
  W = b.weights(m)                      # the skin weights there (interpolated)
  hit = ray_points(m, origins, dirs)    # the first point of `m` along each ray (reference fit), or None
  piece = rigid(m, b, prim, ...)        # one rigid copy of the primitive `prim` at every bound point: a Mesh with
                                        #   the same fits and attributes as `m`, every vertex weighted like its anchor

Primitives are (V, F) in a local frame: x across, y "up" (the hint projected on the surface), z out of the surface.
`button`, `box`, `frame` (a buckle), `disc`, `ellipsoid`, `ring` (torus), `lathe` (a profile turned round z).

A rigid piece keeps its size in every fit (a brass button on the male fit is the same button); it follows the
surface it sits on (position and normal per fit) and the skinning of its anchor (one set of weights for the whole
piece, so it never bends: the deform check's RIGID_EDGE).
"""

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from cloth2.mesh import REF, Mesh, unit, vertex_normals


def _bvh(V, F):
    return BVHTree.FromPolygons([tuple(p) for p in V], [tuple(t) for t in F], all_triangles=True)


def _bary(p, a, b, c):
    v0, v1, v2 = b - a, c - a, p - a
    d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
    d20, d21 = v2 @ v0, v2 @ v1
    den = d00 * d11 - d01 * d01
    if abs(den) < 1e-18:
        return np.array([1.0, 0.0, 0.0])
    v = (d11 * d20 - d01 * d21) / den
    w = (d00 * d21 - d01 * d20) / den
    u = np.clip(np.array([1.0 - v - w, v, w]), 0.0, 1.0)
    return u / u.sum()


def face_normals(V, F):
    return unit(np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]]))


class Binding:
    """Points bound to the faces of a mesh (reference fit): each fit then has the same points on its own surface."""

    def __init__(self, m, P, fit=REF):
        P = np.atleast_2d(np.asarray(P, float))
        bv = _bvh(m.V[fit], m.F)
        self.face = np.zeros(len(P), int)
        self.bary = np.zeros((len(P), 3))
        self.off = np.zeros(len(P))
        V = m.V[fit]
        fn = face_normals(V, m.F)
        for i, p in enumerate(P):
            loc, _, idx, _ = bv.find_nearest(Vector(p))
            t = m.F[idx]
            self.face[i] = idx
            self.bary[i] = _bary(np.array(loc), V[t[0]], V[t[1]], V[t[2]])
            self.off[i] = float((p - np.array(loc)) @ fn[idx])

    def __len__(self):
        return len(self.face)

    def at(self, m, fit):
        """(positions, unit face normals) of the bound points in `fit`."""
        T = m.F[self.face]
        V = m.V[fit]
        n = unit(np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]]))
        p = np.einsum("ij,ijk->ik", self.bary, V[T]) + n * self.off[:, None]
        return p, n

    def attr(self, m, name):
        """A per-vertex attribute of `m` interpolated at the bound points."""
        a = m.A[name]
        T = m.F[self.face]
        return np.einsum("ij,ij...->i...", self.bary, a[T])

    def weights(self, m):
        return self.attr(m, "W")

    def face_attr(self, m, name):
        return m.fa[name][self.face]


def ray_points(m, origins, dirs, dist=1.0, fit=REF):
    """The first hit of each ray on `m` (reference fit): (points (k, 3), ok (k,)). Missed rays give nan."""
    bv = _bvh(m.V[fit], m.F)
    O = np.atleast_2d(np.asarray(origins, float))
    D = unit(np.atleast_2d(np.asarray(dirs, float)) * np.ones_like(O))
    out = np.full_like(O, np.nan)
    ok = np.zeros(len(O), bool)
    for i in range(len(O)):
        loc, _, _, _ = bv.ray_cast(Vector(O[i]), Vector(D[i]), dist)
        if loc is not None:
            out[i] = np.array(loc)
            ok[i] = True
    return out, ok


def toward_axis(m, z, angle_deg, axis_y=0.0, r0=0.6, fit=REF):
    """Points of `m` at height z and `angle_deg` round the vertical axis (0 the front, +90 the wearer's left), found by a
    ray from outside toward the axis: buttons on a skirt, a pocket's corner."""
    a = np.radians(np.atleast_1d(np.asarray(angle_deg, float)))
    z = np.broadcast_to(np.asarray(z, float), a.shape)
    d = np.stack([np.sin(a), -np.cos(a), np.zeros_like(a)], 1)
    O = np.stack([np.zeros_like(a), np.full_like(a, axis_y), z], 1) + d * r0
    return ray_points(m, O, -d, r0 + 0.1, fit)


# ---- frames ---------------------------------------------------------------------------------------------------
def frames(n, up_hint):
    """(k, 3, 3) rotations whose columns are (across, up, out): out = n, up = the hint projected on the surface."""
    n = unit(np.atleast_2d(n))
    u = np.broadcast_to(np.asarray(up_hint, float), n.shape).copy()
    u = u - (u * n).sum(1, keepdims=True) * n
    bad = np.linalg.norm(u, axis=1) < 1e-6
    if bad.any():
        alt = np.where(np.abs(n[bad, 2:3]) < 0.9, [[0.0, 0.0, 1.0]], [[0.0, 1.0, 0.0]])
        u[bad] = alt - (alt * n[bad]).sum(1, keepdims=True) * n[bad]
    u = unit(u)
    s = np.cross(u, n)
    return np.stack([s, u, n], 2)


# ---- primitives (local frame: x across, y up, z out) -------------------------------------------------------------
def _ring(r, z, segs, phase=0.0, ry=None):
    th = 2 * np.pi * (np.arange(segs) + phase) / segs
    return np.stack([r * np.cos(th), (ry if ry is not None else r) * np.sin(th), np.full(segs, z)], 1)


def button(r=0.0085, h=0.0032, segs=6, dome=0.35, sink=0.0006):
    """A low domed button: a side ring from below the cloth (`sink`) to h * (1 - dome), a centre at h."""
    V = np.concatenate([_ring(r, -sink, segs), _ring(r * 0.92, h * (1 - dome), segs), [[0.0, 0.0, h]]])
    F = []
    for j in range(segs):
        a, b = j, (j + 1) % segs
        F += [(a, b, segs + b), (a, segs + b, segs + a), (segs + a, segs + b, 2 * segs)]
    return V, np.array(F, int)


def disc(r, h, segs=12, sink=0.0004):
    """A flat round piece (a cockade, a rosette, a lens cap): a short side and a flat top."""
    V = np.concatenate([_ring(r, -sink, segs), _ring(r, h, segs), [[0.0, 0.0, h]]])
    F = []
    for j in range(segs):
        a, b = j, (j + 1) % segs
        F += [(a, b, segs + b), (a, segs + b, segs + a), (segs + a, segs + b, 2 * segs)]
    return V, np.array(F, int)


def box(hx, hy, hz, z0=0.0):
    """A box of half sizes (hx, hy, hz) standing on the surface (its bottom at z0)."""
    c = np.array([[-1, -1, 0], [1, -1, 0], [1, 1, 0], [-1, 1, 0], [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]], float)
    V = c * [hx, hy, 2 * hz] + [0, 0, z0]
    F = [(0, 2, 1), (0, 3, 2), (4, 5, 6), (4, 6, 7), (0, 1, 5), (0, 5, 4), (1, 2, 6), (1, 6, 5), (2, 3, 7), (2, 7, 6),
         (3, 0, 4), (3, 4, 7)]
    return V, np.array(F, int)


def frame(w, h, bar=0.004, t=0.003, z0=0.0):
    """A rectangular buckle frame (outer w x h, bars `bar` wide, `t` thick) and its tongue across the middle."""
    parts = [((0.0, (h - bar) / 2), (w / 2, bar / 2)), ((0.0, -(h - bar) / 2), (w / 2, bar / 2)),
             (((w - bar) / 2, 0.0), (bar / 2, h / 2)), ((-(w - bar) / 2, 0.0), (bar / 2, h / 2)),
             ((0.0, 0.0), (bar * 0.3, h / 2))]
    return merge([translate(box(sx, sy, t / 2, z0), (cx, cy, 0.0)) for (cx, cy), (sx, sy) in parts])


def ellipsoid(rx, ry, rz, segs=8, rings=4, z0=None):
    """An ellipsoid (a knot, a bead, a pommel); centred at z = rz (sitting on the surface) unless z0 is given."""
    zc = rz if z0 is None else z0
    V = [[0.0, 0.0, zc - rz]]
    for i in range(1, rings):
        ph = np.pi * i / rings
        V += [[rx * np.sin(ph) * np.cos(t), ry * np.sin(ph) * np.sin(t), zc - rz * np.cos(ph)]
              for t in 2 * np.pi * np.arange(segs) / segs]
    V.append([0.0, 0.0, zc + rz])
    V = np.array(V, float)
    top = len(V) - 1
    F = []
    for j in range(segs):
        F.append((0, 1 + (j + 1) % segs, 1 + j))
    for i in range(rings - 2):
        r0, r1 = 1 + i * segs, 1 + (i + 1) * segs
        for j in range(segs):
            a, b = j, (j + 1) % segs
            F += [(r0 + a, r0 + b, r1 + b), (r0 + a, r1 + b, r1 + a)]
    rl = 1 + (rings - 2) * segs
    for j in range(segs):
        F.append((rl + j, rl + (j + 1) % segs, top))
    return V, np.array(F, int)


def ring(r, tube, segs=10, tube_segs=4, z0=None):
    """A torus lying on the surface (a harness ring, a sling ring)."""
    zc = tube if z0 is None else z0
    V = []
    for i in range(segs):
        a = 2 * np.pi * i / segs
        c, s = np.cos(a), np.sin(a)
        for j in range(tube_segs):
            b = 2 * np.pi * j / tube_segs
            rr = r + tube * np.cos(b)
            V.append([rr * c, rr * s, zc + tube * np.sin(b)])
    F = []
    for i in range(segs):
        for j in range(tube_segs):
            a = i * tube_segs + j
            b = ((i + 1) % segs) * tube_segs + j
            c = ((i + 1) % segs) * tube_segs + (j + 1) % tube_segs
            d = i * tube_segs + (j + 1) % tube_segs
            F += [(a, b, c), (a, c, d)]
    return np.array(V, float), np.array(F, int)


def lathe(profile, segs=10, closed_top=True):
    """A body of revolution round the local z axis from a profile [(radius, z), ...] (bottom to top): a lens case, a
    powder measure, a horn cap. A last radius of 0 closes the top with a fan."""
    prof = [(float(r), float(z)) for r, z in profile]
    V, rows = [], []
    for r, z in prof:
        if r <= 1e-6:
            rows.append([len(V)])
            V.append([0.0, 0.0, z])
        else:
            rows.append(list(range(len(V), len(V) + segs)))
            V += _ring(r, z, segs).tolist()
    F = []
    for a, b in zip(rows[:-1], rows[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for j in range(segs):
            if len(b) == 1:
                F.append((a[j], a[(j + 1) % segs], b[0]))
            elif len(a) == 1:
                F.append((a[0], b[(j + 1) % segs], b[j]))
            else:
                F += [(a[j], a[(j + 1) % segs], b[(j + 1) % segs]), (a[j], b[(j + 1) % segs], b[j])]
    return np.array(V, float), np.array(F, int)


def translate(prim, d):
    V, F = prim
    return V + np.asarray(d, float), F


def scale(prim, s):
    V, F = prim
    return V * np.asarray(s, float), F


def merge(prims):
    Vs, Fs, off = [], [], 0
    for V, F in prims:
        Vs.append(V)
        Fs.append(F + off)
        off += len(V)
    return np.concatenate(Vs), np.concatenate(Fs)


# ---- placing ----------------------------------------------------------------------------------------------------
def piece_mesh(template, V, F, W, region, zone, part, A=None):
    """A Mesh with `template`'s fits and attribute names: V {fit: (n, 3)}, W (n, bones), per-face region / zone /
    part (scalars or arrays). Attributes of the template not given in `A` are zero."""
    n = len(next(iter(V.values())))
    F = np.asarray(F, int)
    attrs = {}
    for name, arr in template.A.items():
        if name == "W":
            attrs[name] = np.asarray(W, float)
        elif A is not None and name in A:
            attrs[name] = np.asarray(A[name], float)
        else:
            attrs[name] = np.zeros((n,) + arr.shape[1:])
    nf = len(F)
    fa = {"region": np.broadcast_to(np.asarray(region), (nf,)).astype(int).copy(),
          "zone": np.broadcast_to(np.asarray(zone), (nf,)).astype(int).copy(),
          "part": np.broadcast_to(np.asarray(part), (nf,)).astype(int).copy()}
    for k, v in template.fa.items():
        if k not in fa:
            fa[k] = np.zeros(nf, v.dtype)
    out = Mesh.__new__(Mesh)
    out.V = {k: np.asarray(v, float) for k, v in V.items()}
    out.F = F
    out.N = {k: vertex_normals(v, F) for k, v in out.V.items()}
    out.A = attrs
    out.fa = fa
    return out


def rigid(m, binding, prim, zone, part=9, up=(0.0, 0.0, 1.0), lift=0.0, spin=None, scale_by=None):
    """One rigid copy of `prim` (V, F in the local frame) at every point of `binding` on mesh `m`, in every fit.
    up: the frame's up hint (one vector, or one per point); lift: raised off the surface along the normal (m);
    spin: degrees about the normal per point; scale_by: a scale per point. Weights: the anchor's, for every vertex."""
    Vl, Fl = prim
    k = len(binding)
    up = np.broadcast_to(np.asarray(up, float), (k, 3))
    nl = len(Vl)
    V = {}
    for fit in m.V:
        p, n = binding.at(m, fit)
        R = frames(n, up)
        out = []
        for i in range(k):
            L = Vl * (1.0 if scale_by is None else scale_by[i])
            if spin is not None:
                a = np.radians(spin[i])
                c, s = np.cos(a), np.sin(a)
                L = L @ np.array([[c, s, 0.0], [-s, c, 0.0], [0.0, 0.0, 1.0]])
            out.append(p[i] + n[i] * lift + L @ R[i].T)
        V[fit] = np.concatenate(out)
    W = np.repeat(binding.weights(m), nl, axis=0)
    F = np.concatenate([Fl + i * nl for i in range(k)])
    region = np.repeat(binding.face_attr(m, "region"), len(Fl))
    A = {name: np.repeat(binding.attr(m, name), nl, axis=0) for name in m.A if name != "W"}
    return piece_mesh(m, V, F, W, region, zone, part, A)
