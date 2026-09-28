"""Small fittings laid on a garment surface: buttons, lace loops (worsted tape), binding
strips, buckles. They are separate low-poly islands joined into the garment's surface
(zone 2 lace / tape or 3 metal) and move rigidly with the cloth under them
(_base.assemble: kind "trim").

Placement uses the SDF of the surface they lie on (the cloth's OUTER surface, i.e. the
solid form offset by the shell's outer clearance): points are projected onto it and
lifted along its normal.
"""

import math

import bpy
import numpy as np

from lib.remesh import link, material
from lib.sdf import nrm, peval, project_to_surface, v3


def normals_at(node, P, h=4e-4):
    P = np.atleast_2d(np.asarray(P, float))
    g = np.stack([(peval(node, P + e * h) - peval(node, P - e * h)) / (2 * h) for e in np.eye(3)], 1)
    return g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)


def project(node, P, iters=6, step=0.01):
    """Points P moved onto the zero set of `node` (and the unit normals there)."""
    P = project_to_surface(node, np.atleast_2d(np.asarray(P, float)).copy(), step, iters=iters)
    return P, normals_at(node, P)


def hit(node, p, d, t1, step=0.0015):
    """FIRST surface point of `node` along the ray p + t d, t in [0, t1] (marched in `step`s,
    then bisected), and the unit normal there. Raises if the ray never enters the solid."""
    p, d = np.asarray(p, float), nrm(d)
    ts = np.arange(0.0, t1 + step, step)
    f = peval(node, p[None] + ts[:, None] * d[None])
    inside = np.nonzero(f < 0)[0]
    if not len(inside):
        raise ValueError("hit: the ray from %s along %s misses" % (np.round(p, 3), np.round(d, 3)))
    k = int(inside[0])
    a, b = (ts[k - 1] if k else 0.0), ts[k]
    for _ in range(30):
        m = 0.5 * (a + b)
        if peval(node, (p + d * m)[None])[0] < 0:
            b = m
        else:
            a = m
    q = p + d * a
    return q, normals_at(node, q)[0]


def tangent_frame(n, along):
    """(t along, b across, n) with t = `along` made tangent to the normal n."""
    n = nrm(n)
    t = np.asarray(along, float) - n * (np.asarray(along, float) @ n)
    t = nrm(t)
    return t, np.cross(n, t), n


class Trims:
    """Accumulates trim geometry (vertices, triangles, per-vertex uv in metres)."""

    def __init__(self):
        self.V, self.F, self.UV = [], [], []

    def _add(self, verts, faces, uvs):
        o = len(self.V)
        self.V += [np.asarray(v, float) for v in verts]
        self.UV += [np.asarray(u, float) for u in uvs]
        self.F += [tuple(o + i for i in f) for f in faces]

    def button(self, p, n, r=0.0085, h=0.0032, segs=8, sink=0.0006):
        """Low dome (24 triangles) on the surface point p with normal n."""
        n = nrm(n)
        t, b, _ = tangent_frame(n, v3(1, 0, 0) if abs(n[0]) < 0.9 else v3(0, 0, 1))
        verts, uvs, faces = [], [], []
        for ring, (rr, hh) in enumerate(((r, -sink), (0.72 * r, 0.62 * h))):
            for j in range(segs):
                a = 2 * math.pi * j / segs
                d = t * math.cos(a) + b * math.sin(a)
                verts.append(p + d * rr + n * hh)
                uvs.append((rr * math.cos(a), rr * math.sin(a)))
        verts.append(p + n * h)
        uvs.append((0.0, 0.0))
        for j in range(segs):
            j1 = (j + 1) % segs
            faces += [(j, j1, segs + j1), (j, segs + j1, segs + j)]
            faces.append((segs + j, segs + j1, 2 * segs))
        self._add(verts, faces, uvs)

    def strip(self, node, P, width, lift=0.0012, along=None, taper=None):
        """Flat tape of `width` along the centre points P (projected onto `node`), lifted by
        `lift`; single-sided (it lies flat on the cloth). uv: u across (m), v along (m)."""
        P, Nn = project(node, P)
        k = len(P)
        verts, uvs, faces = [], [], []
        s = 0.0
        for i in range(k):
            d = P[min(i + 1, k - 1)] - P[max(i - 1, 0)]
            t, b, n = tangent_frame(Nn[i], d)
            w = width * (1.0 if taper is None else taper[i])
            if i:
                s += float(np.linalg.norm(P[i] - P[i - 1]))
            for sgn in (-1, 1):
                verts.append(P[i] + n * lift + b * (0.5 * w * sgn))
                uvs.append((0.5 * w * sgn + 0.5 * width, s))
        for i in range(k - 1):
            a, b_, c, d = 2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2
            faces += [(a, d, c), (a, c, b_)]
        # orientation: the strip's normal must face out of the surface
        V = np.array(verts)
        f = faces[0]
        fn = np.cross(V[f[1]] - V[f[0]], V[f[2]] - V[f[0]])
        if fn @ Nn[0] < 0:
            faces = [(f[0], f[2], f[1]) for f in faces]
        self._add(verts, faces, uvs)
        return P, Nn

    def line(self, node, a, b, n=5):
        return np.array([a + (b - a) * (i / (n - 1)) for i in range(n)])

    def box(self, c, half, R):
        """Oriented box (12 triangles), R columns = local axes."""
        R = np.asarray(R, float)
        verts, uvs = [], []
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    q = np.array([sx * half[0], sy * half[1], sz * half[2]])
                    verts.append(c + R @ q)
                    uvs.append((q[0], q[2]))
        faces = [(0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5), (0, 4, 5), (0, 5, 1), (2, 3, 7), (2, 7, 6),
                 (0, 2, 6), (0, 6, 4), (1, 5, 7), (1, 7, 3)]
        self._add(verts, faces, uvs)

    def buckle(self, c, n, up, w=0.030, h=0.024, bar=0.0035, t=0.003):
        """Rectangular buckle frame (4 boxes + a prong) on the plane with normal n."""
        _, x, _ = tangent_frame(n, up)
        y = np.cross(n, x)
        R = np.stack([x, y, nrm(n)], 1)
        c = np.asarray(c, float) + nrm(n) * (t * 0.5)
        self.box(c + y * (h - bar) / 2, (w / 2, bar / 2, t / 2), R)
        self.box(c - y * (h - bar) / 2, (w / 2, bar / 2, t / 2), R)
        self.box(c + x * (w - bar) / 2, (bar / 2, h / 2 - bar, t / 2), R)
        self.box(c - x * (w - bar) / 2, (bar / 2, h / 2 - bar, t / 2), R)
        self.box(c, (bar * 0.35, h / 2 - bar, t * 0.35), R)

    def empty(self):
        return not self.F

    def to_object(self, name, hexcol="#b58f4a"):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in self.V], [], self.F)
        me.validate(clean_customdata=False)
        me.update()
        ob = link(bpy.data.objects.new(name, me))
        me.materials.append(material(name, hexcol, 0.5))
        for p in me.polygons:
            p.use_smooth = True
        a = me.attributes.new("mil_uv", "FLOAT2", "POINT")
        a.data.foreach_set("vector", np.asarray(self.UV, np.float32).ravel())
        return ob
