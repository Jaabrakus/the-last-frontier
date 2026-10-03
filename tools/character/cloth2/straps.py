"""cloth2 straps: bands round the body and strips along paths on it, in every fit (2026-10-02).

  m = band(g, z0, z1, lift)                    # a closed band round the torso between two heights (a belt, a sash's
                                               #   turns, a waistband), `lift` off the cloth surface
  path = surface_path(fits, waypoints, step)   # a polyline on the cloth surface through the waypoints (reference fit)
  piece = strip(g, path, width, lift)          # a flat strap along it (a harness strap, a pouch belt, the hanging ends
                                               #   of a sash or neckerchief); rigid across its width: every vertex of a
                                               #   cross-section takes the centre line's weights
  piece = fin(g, path, depth, lift)            # a flap standing out of the surface along the path (the leggings' flap)

A path is bound to the cloth surface (the fits' proxy, triangle + barycentrics + offset), so it exists in every fit
and the male fit and the bust gauge carry it. Straps go over the clothes under them by `lift` and then
Garment.over() (pushed clear of the garments' built meshes).
"""

import numpy as np
from mathutils import Vector

from cloth2.hardware import _bary, piece_mesh
from cloth2.mesh import REF, unit


class SurfacePath:
    """Points bound to the fits' cloth surface (cloth2.fit: Fits.surface('cloth'))."""

    def __init__(self, fits, P, base="cloth"):
        self.fits = fits
        self.base = base
        V = fits.CV[REF] if base == "cloth" else fits.PV[REF]
        bv = fits.bvhc[REF] if base == "cloth" else None
        if bv is None:
            from mathutils.bvhtree import BVHTree
            bv = BVHTree.FromPolygons([tuple(p) for p in V], [tuple(t) for t in fits.pF], all_triangles=True)
        P = np.asarray(P, float)
        self.tri = np.zeros(len(P), int)
        self.bary = np.zeros((len(P), 3))
        self.surf = np.zeros_like(P)
        for i, p in enumerate(P):
            loc, nrm, idx, _ = bv.find_nearest(Vector(p))
            t = fits.pF[idx]
            self.tri[i] = idx
            self.bary[i] = _bary(np.array(loc), V[t[0]], V[t[1]], V[t[2]])
            self.surf[i] = np.array(loc)

    def __len__(self):
        return len(self.tri)

    def at(self, fit):
        """(points, unit normals, unit tangents) on the cloth surface of `fit`."""
        V = (self.fits.CV if self.base == "cloth" else self.fits.PV)[fit]
        T = self.fits.pF[self.tri]
        p = np.einsum("ij,ijk->ik", self.bary, V[T])
        fn = unit(np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]]))
        N = (self.fits.CN if self.base == "cloth" else self.fits.PN)[fit]
        vn = unit(np.einsum("ij,ijk->ik", self.bary, N[T]))
        n = unit(vn + fn * 0.0)
        tg = unit(np.gradient(p, axis=0))
        return p, n, tg

    def weights(self):
        return np.einsum("ij,ijk->ik", self.bary, self.fits.PW[self.fits.pF[self.tri]])

    def limb_attrs(self):
        out = {}
        for name, arr in self.fits.p_limb.items():
            out[name] = np.einsum("ij,ij->i", self.bary, arr[self.fits.pF[self.tri]])
        return out


def surface_path(fits, waypoints, step=0.012, base="cloth", iters=3):
    """A polyline through `waypoints` (reference fit) resampled every `step` metres and projected onto the cloth
    surface (a few rounds of resample + project, so it lies on the body between the waypoints)."""
    P = np.asarray(waypoints, float)
    for _ in range(iters):
        seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
        L = np.concatenate([[0.0], np.cumsum(seg)])
        n = max(int(np.ceil(L[-1] / step)) + 1, 2)
        s = np.linspace(0.0, L[-1], n)
        P = np.stack([np.interp(s, L, P[:, k]) for k in range(3)], 1)
        P = SurfacePath(fits, P, base).surf
    return SurfacePath(fits, P, base)


def strip(g, path, width, lift, zone=0, part=8, width_fn=None, twist_up=None):
    """A strap of `width` (m; or width_fn(s) along the path, s 0..1) along `path` (SurfacePath), `lift` (m, a number
    or per point) off the cloth surface, rigid across. Returns a piece for the garment `g`."""
    k = len(path)
    s = np.linspace(0.0, 1.0, k)
    w = np.asarray(width_fn(s), float) if width_fn else np.full(k, float(width))
    lift = np.broadcast_to(np.asarray(lift, float), (k,))
    V = {}
    for fit in g.fits.V:
        p, n, t = path.at(fit)
        side = unit(np.cross(n, t))
        c = p + n * lift[:, None]
        V[fit] = np.concatenate([c - side * (w / 2)[:, None], c + side * (w / 2)[:, None]])
    F = []
    for i in range(k - 1):
        a, b, c_, d = i, i + 1, k + i + 1, k + i
        F += [(a, b, c_), (a, c_, d)]
    F = np.array(F, int)
    P = V[REF]
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    _, n0, _ = path.at(REF)
    if ((fn * np.concatenate([n0, n0])[F[:, 0]]).sum(1) < 0).mean() > 0.5:
        F = F[:, ::-1].copy()
    W = np.concatenate([path.weights()] * 2)
    A = {name: np.concatenate([v] * 2) for name, v in path.limb_attrs().items()}
    region = g.fits.p_region[path.tri]
    reg_f = np.concatenate([region[:-1], region[:-1]])
    return piece_mesh(g.m if g.m is not None else _template(g), V, F, W, reg_f, zone, part, A)


def fin(g, path, depth, lift, zone=0, part=8):
    """A flap standing `depth` (m) out of the surface along `path`, from `lift` off it (the wool leggings' side
    flap). Rigid across, like a strip."""
    k = len(path)
    V = {}
    for fit in g.fits.V:
        p, n, _ = path.at(fit)
        V[fit] = np.concatenate([p + n * lift, p + n * (lift + depth)])
    F = []
    for i in range(k - 1):
        F += [(i, i + 1, k + i + 1), (i, k + i + 1, k + i)]
    W = np.concatenate([path.weights()] * 2)
    A = {name: np.concatenate([v] * 2) for name, v in path.limb_attrs().items()}
    region = g.fits.p_region[path.tri]
    return piece_mesh(g.m if g.m is not None else _template(g), V, np.array(F, int), W,
                      np.concatenate([region[:-1], region[:-1]]), zone, part, A)


def band(g, z0, z1, lift, regions=None, zone=0, part=0, base="cloth"):
    """A closed band round the torso from z0 to z1 (m), `lift` off the cloth surface: a new Mesh (not g.m)."""
    from cloth2 import garment as G
    regions = regions or G.TORSO
    sub = G.Garment(g.fits, g.spec)
    sub.shell(regions, base=base)
    sub.top(z1).bottom(z0)
    sub.m.offset(lift, vertical=0.0)
    sub.m.fa["zone"][:] = zone
    sub.m.fa["part"][:] = part
    g.fits.clear(sub.m, 0.002)
    return sub.m


def _template(g):
    return g.fits.surface("cloth")
