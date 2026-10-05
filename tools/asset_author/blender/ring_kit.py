"""The Tidebreak arena kit, authored procedurally in Blender (our own designs in the spirit of East Asian timber
architecture: curved tile roofs with upturned eaves, lacquered pillars, bracket sets, paper lanterns; no building,
emblem or insignia copied). Run headless:

    Blender -b --python tools/asset_author/blender/ring_kit.py -- --out assets/ring_kit [--blend /tmp/kit.blend]

Writes into --out (glTF binary, +Y up, Blender -Y = Godot +Z = the piece's front):
    gate_pavilion.glb   the gateway over each end's tunnel: four lacquered pillars on stone drums in one row, a main
                        roof over the middle bay and two lower roofs over the outer bays (curved, upturned eaves, hip
                        ridges, curled ridge ends), lintels with gold bands, bracket sets, a name board, two lanterns;
                        origin on the ground at the middle of the opening, 10.6 m across
    roof_hip.glb        a curved hip roof 4 x 2 m (ridge along X), 1 m high: scaled to fit (the scoreboard tower, ...)
    roof_pyramid.glb    a curved pyramid roof 2 x 2 m, 1 m high, a gold finial
    pillar_shaft.glb    a lacquered round shaft 1 m high (scaled up), radius 0.3
    pillar_base.glb     a stone drum on a square plinth with a gold ring (0.55 m high)
    pillar_cap.glb      the shaft's head: gold bands and a painted bracket capital (0.75 m high)
    lantern_paper.glb   a ribbed paper lantern 0.62 m high, radius 0.26 (centre at the origin), gold caps, a tassel
    awning_canopy.glb   one bay of the stands' canopy: a unit tile roof falling from the back (y 1 at z 0) to the
                        front (y 0 at z 1), concave, its front eave turned up, rafters under it; x 0..1
    glyphs.png          the four element glyphs (earth, water, fire, air: 2 x 2 cells of 256 px, white on black)
    glyphs.glb          the same glyphs as flat meshes (for reference)
Materials are named for the arena's material keys (RingDressing.KIT_KEYS): lacquer, wood, board, paint_green,
paint_teal, gold, tile, stone, lamp_red, iron. Their base colours are the tints.
"""

import argparse
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

COLORS = {
    "lacquer": (0.62, 0.10, 0.06), "wood": (0.30, 0.17, 0.10), "board": (0.12, 0.06, 0.05),
    "paint_green": (0.16, 0.42, 0.30), "paint_teal": (0.10, 0.36, 0.40), "gold": (1.0, 0.74, 0.32),
    "tile": (0.16, 0.34, 0.36), "stone": (0.80, 0.76, 0.70), "lamp_red": (0.85, 0.16, 0.08), "iron": (0.12, 0.11, 0.10),
}


def srgb_to_linear(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def material(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        r, g, b = srgb_to_linear(COLORS[name])
        bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.6
    return m


class Builder:
    """Accumulates faces per material into one bmesh (a piece)."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def face(self, pts, mat, smooth=False):
        vs = [self.bm.verts.new(Vector(p)) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self.mi(mat)
        f.smooth = smooth
        return f

    def grid(self, P, mat, smooth=True, flip=False):
        """P: (rows, cols, 3) a quad grid."""
        rows, cols = P.shape[0], P.shape[1]
        V = [[self.bm.verts.new(Vector(P[i, j])) for j in range(cols)] for i in range(rows)]
        k = self.mi(mat)
        for i in range(rows - 1):
            for j in range(cols - 1):
                q = [V[i][j], V[i][j + 1], V[i + 1][j + 1], V[i + 1][j]]
                if flip:
                    q = q[::-1]
                f = self.bm.faces.new(q)
                f.material_index = k
                f.smooth = smooth
        return V

    def box(self, c, s, mat, rot=None):
        c, s = np.asarray(c, float), np.asarray(s, float) / 2.0
        R = np.eye(3) if rot is None else np.asarray(rot, float)
        corners = np.array([[x, y, z] for z in (-1, 1) for y in (-1, 1) for x in (-1, 1)]) * s
        P = corners @ R.T + c
        idx = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
        for q in idx:
            self.face([P[i] for i in q], mat)

    def lathe(self, prof, segs, mat, base=(0, 0, 0), smooth=True, cap_top=True, cap_bottom=True, ribs=0.0):
        """prof: [(r, z)] bottom to top; `ribs`: radial ribbing depth (a paper lantern's frames)."""
        b = np.asarray(base, float)
        rows = []
        for r, z in prof:
            ring = []
            for k in range(segs):
                a = 2.0 * math.pi * k / segs
                rr = r * (1.0 - ribs * (k % 2))          # (ribs: every other vertex drawn in, the frames between)
                ring.append(b + [rr * math.cos(a), rr * math.sin(a), z])
            ring.append(ring[0])
            rows.append(ring)
        P = np.array(rows)
        V = self.grid(P, mat, smooth=smooth, flip=True)
        k = self.mi(mat)
        if cap_bottom and prof[0][0] > 1e-4:
            f = self.bm.faces.new([V[0][j] for j in range(segs)])
            f.material_index = k
        if cap_top and prof[-1][0] > 1e-4:
            f = self.bm.faces.new([V[-1][j] for j in range(segs)][::-1])
            f.material_index = k

    def cylinder(self, c, r, h, segs, mat, smooth=True):
        self.lathe([(r, 0.0), (r, h)], segs, mat, base=c, smooth=smooth)

    def tube(self, path, radii, segs, mat, smooth=True):
        """A tube swept along `path` (points), radius per point; ends capped."""
        path = [np.asarray(p, float) for p in path]
        rows = []
        prev_n = None
        for i, p in enumerate(path):
            t = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
            t = t / max(np.linalg.norm(t), 1e-9)
            n = np.cross(t, [0, 0, 1]) if abs(t[2]) < 0.9 else np.cross(t, [1, 0, 0])
            if prev_n is not None and np.dot(n, prev_n) < 0:
                n = -n
            n = n / np.linalg.norm(n)
            prev_n = n
            bnorm = np.cross(t, n)
            ring = [p + radii[i] * (math.cos(2 * math.pi * k / segs) * n + math.sin(2 * math.pi * k / segs) * bnorm)
                    for k in range(segs)]
            ring.append(ring[0])
            rows.append(ring)
        V = self.grid(np.array(rows), mat, smooth=smooth)
        k = self.mi(mat)
        for row, rev in ((V[0], True), (V[-1], False)):
            vs = [row[j] for j in range(segs)]
            f = self.bm.faces.new(vs[::-1] if rev else vs)
            f.material_index = k

    def obj(self):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(material(m))
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


# ------------------------------------------------------------------------------------------------ roofs
def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def roof(bld, c, A, B, H, upturn=0.32, thick=0.10, tile_mat="tile", under_mat="wood", nx=48, ny=24, corr=0.2,
         corr_h=0.03, ridge_mat="tile", ends=True, finial=False, hips=True):
    """A curved hip roof centred on c (eave level), half sizes A (along X, the ridge) >= B, H high at the ridge:
    concave slopes (flat at the eaves, steep at the ridge), eave corners turned up by `upturn`, tile rows `corr` apart
    (`corr_h` deep), the underside `thick` below, a fascia round the eaves, the ridge and hip ridges, curled ridge ends
    (`ends`) or a finial (`finial`, a pyramid)."""
    c = np.asarray(c, float)
    u = np.linspace(-1.0, 1.0, nx + 1)
    v = np.linspace(-1.0, 1.0, ny + 1)
    U, Vv = np.meshgrid(u, v)
    X, Y = U * A, Vv * B
    d_side = B - np.abs(Y)
    d_end = A - np.abs(X)
    d = np.minimum(d_side, d_end)
    s = np.clip(d / B, 0.0, 1.0)
    e = 1.0 - s
    Z = H * s ** 1.6 + upturn * e ** 2 * (np.abs(U) * np.abs(Vv)) ** 2.5
    end_slope = d_end < d_side
    phase = np.where(end_slope, Y, X)
    Zt = Z + corr_h * np.abs(np.sin(math.pi * phase / corr)) * (1.0 - s ** 6)
    top = np.stack([X + c[0], Y + c[1], Zt + c[2]], -1)
    bot = np.stack([X + c[0], Y + c[1], Z - thick + c[2]], -1)
    bld.grid(top, tile_mat, smooth=True)
    bld.grid(bot, under_mat, smooth=True, flip=True)
    # the fascia: the rim between top and underside
    rim = []
    for j in range(nx + 1):
        rim.append((0, j))
    for i in range(1, ny + 1):
        rim.append((i, nx))
    for j in range(nx - 1, -1, -1):
        rim.append((ny, j))
    for i in range(ny - 1, 0, -1):
        rim.append((i, 0))
    rim.append(rim[0])
    for (i0, j0), (i1, j1) in zip(rim[:-1], rim[1:]):
        bld.face([top[i0, j0], top[i1, j1], bot[i1, j1], bot[i0, j0]], under_mat)
    zr = c[2] + H
    rl = A - B
    if rl > 0.05:
        bld.box(c + [0, 0, H + 0.06], (2 * rl + 0.1, 0.16, 0.16), ridge_mat)
        bld.box(c + [0, 0, H + 0.15], (2 * rl + 0.06, 0.10, 0.05), "gold")
    if hips:
        for sx in (-1, 1):
            for sy in (-1, 1):
                pts, rad = [], []
                for t in np.linspace(0.0, 1.0, 10):
                    x = sx * (rl + t * B)
                    y = sy * t * B
                    uu, vv = x / A, y / B
                    ss = 1.0 - t
                    z = H * ss ** 1.6 + upturn * t ** 2 * (abs(uu) * abs(vv)) ** 2.5 + 0.05
                    pts.append(c + [x, y, z])
                    rad.append(0.06 * (1.0 - 0.4 * t))
                bld.tube(pts, rad, 6, ridge_mat)
    if ends and rl > 0.05:
        # our own ridge ends: a horn sweeping up and curling back over the ridge
        for sx in (-1, 1):
            pts, rad = [], []
            for t in np.linspace(0.0, 1.0, 12):
                a = t * math.pi * 1.15
                pts.append(c + [sx * (rl + 0.05 - 0.22 * math.sin(a) * t), 0.0, H + 0.08 + 0.42 * (1 - math.cos(a)) * 0.5 + 0.1 * t])
                rad.append(0.09 * (1.0 - 0.75 * t))
            bld.tube(pts, rad, 8, "gold")
    if finial:
        bld.lathe([(0.10, 0.0), (0.06, 0.10), (0.14, 0.22), (0.08, 0.34), (0.02, 0.62), (0.0, 0.66)], 10, "gold",
                  base=c + [0, 0, H - 0.04])


# ------------------------------------------------------------------------------------------------ pieces
def lantern(bld, c, r=0.26, h=0.62, cord=0.0):
    c = np.asarray(c, float)
    prof = []
    for k in range(9):
        t = k / 8.0
        z = -h / 2 + t * h
        rr = r * (0.62 + 0.38 * math.sin(math.pi * (0.08 + 0.84 * t)))
        prof.append((rr, z))
    bld.lathe(prof, 16, "lamp_red", base=c, cap_top=False, cap_bottom=False, ribs=0.05)
    bld.lathe([(r * 0.52, -h / 2 - 0.05), (r * 0.62, -h / 2 + 0.01)], 12, "gold", base=c)
    bld.lathe([(r * 0.62, h / 2 - 0.01), (r * 0.5, h / 2 + 0.05)], 12, "gold", base=c)
    bld.lathe([(0.025, -h / 2 - 0.05), (0.05, -h / 2 - 0.14), (0.0, -h / 2 - 0.30)], 6, "gold", base=c)
    if cord > 0:
        bld.cylinder(c + [0, 0, h / 2 + 0.05], 0.012, cord, 4, "iron")


def pillar(bld, x, y, h, r=0.24, base=True):
    if base:
        bld.box((x, y, 0.15), (1.0, 1.0, 0.3), "stone")
        bld.lathe([(0.44, 0.30), (0.46, 0.38), (0.40, 0.55), (r + 0.02, 0.62)], 20, "stone", base=(x, y, 0))
    bld.cylinder((x, y, 0.6), r, h - 0.6, 20, "lacquer")
    for zb in (h - 0.34, h - 0.12):
        bld.cylinder((x, y, zb), r + 0.025, 0.06, 20, "gold")


def brackets(bld, x0, x1, z, y=0.0, step=0.62, depth=0.6):
    n = max(int(round((x1 - x0) / step)), 1)
    for k in range(n + 1):
        x = x0 + (x1 - x0) * k / n
        bld.box((x, y, z + 0.07), (0.22, 0.30, 0.14), "paint_green")
        bld.box((x, y, z + 0.19), (0.46, 0.22, 0.10), "paint_teal")
        bld.box((x, y, z + 0.19), (0.16, depth, 0.10), "paint_teal")
        bld.box((x, y, z + 0.29), (0.26, 0.30, 0.10), "gold")


def gate_pavilion():
    b = Builder("gate_pavilion")
    main_x, out_x = 3.0, 4.75
    for x in (-out_x, -main_x, main_x, out_x):
        pillar(b, x, 0.0, 6.45 if abs(x) < 4.0 else 5.35)
    # lintels with gold bands
    b.box((0, 0, 6.22), (2 * main_x + 0.7, 0.46, 0.46), "lacquer")
    for zz in (6.0, 6.44):
        b.box((0, -0.235, zz), (2 * main_x + 0.6, 0.012, 0.05), "gold")
        b.box((0, 0.235, zz), (2 * main_x + 0.6, 0.012, 0.05), "gold")
    b.box((0, 0, 5.62), (2 * main_x - 0.2, 0.30, 0.22), "lacquer")
    for sx in (-1, 1):
        cx = sx * (main_x + out_x) / 2
        b.box((cx, 0, 5.12), (out_x - main_x + 0.6, 0.40, 0.40), "lacquer")
        b.box((cx, -0.205, 5.12), (out_x - main_x + 0.5, 0.012, 0.05), "gold")
        b.box((cx, 0, 4.42), (out_x - main_x - 0.2, 0.26, 0.18), "lacquer")
        # a lattice panel in each outer bay over the opening
        for k in range(5):
            xx = cx + (k - 2) * 0.3
            b.box((xx, 0, 4.77), (0.05, 0.08, 0.52), "paint_teal")
        b.box((cx, 0, 4.77), (out_x - main_x - 0.25, 0.08, 0.05), "paint_teal")
        brackets(b, cx - 0.55, cx + 0.55, 5.32, step=0.55, depth=0.5)
        roof(b, (cx, 0, 5.68), 1.35, 1.0, 0.95, upturn=0.26, thick=0.09, nx=28, ny=18, corr=0.18)
    # the name board (the side's plaque is drawn on it) in a gold frame
    b.box((0, -0.05, 5.62), (2.1, 0.12, 0.92), "board")
    b.box((0, -0.12, 5.62), (2.24, 0.03, 1.06), "gold")
    b.box((0, -0.11, 5.62), (2.04, 0.04, 0.86), "board")
    brackets(b, -main_x + 0.2, main_x - 0.2, 6.45, step=0.6, depth=0.7)
    roof(b, (0, 0, 6.82), 4.1, 1.25, 1.6, upturn=0.42, thick=0.12, nx=64, ny=24, corr=0.2)
    for sx in (-1, 1):
        lantern(b, (sx * 1.95, -0.05, 4.95), cord=0.92)
    return b.obj()


def unit_roofs():
    r1 = Builder("roof_hip")
    roof(r1, (0, 0, 0), 2.0, 1.0, 1.0, upturn=0.22, thick=0.06, nx=48, ny=24, corr=0.11, corr_h=0.018)
    r2 = Builder("roof_pyramid")
    roof(r2, (0, 0, 0), 1.0, 1.0, 1.0, upturn=0.22, thick=0.06, nx=28, ny=28, corr=0.11, corr_h=0.018, ends=False,
         finial=True)
    return [r1.obj(), r2.obj()]


def pillar_pieces():
    sh = Builder("pillar_shaft")
    sh.cylinder((0, 0, 0), 0.3, 1.0, 20, "lacquer")
    bs = Builder("pillar_base")
    bs.box((0, 0, 0.12), (0.95, 0.95, 0.24), "stone")
    bs.lathe([(0.45, 0.24), (0.47, 0.32), (0.40, 0.48), (0.32, 0.55)], 20, "stone")
    bs.cylinder((0, 0, 0.50), 0.33, 0.05, 20, "gold")
    cp = Builder("pillar_cap")
    for zb in (0.0, 0.16):
        cp.cylinder((0, 0, zb), 0.325, 0.06, 20, "gold")
    cp.cylinder((0, 0, 0.06), 0.31, 0.10, 20, "paint_green")
    cp.box((0, 0, 0.32), (0.62, 0.62, 0.14), "paint_teal")
    cp.box((0, 0, 0.45), (0.86, 0.36, 0.12), "paint_green")
    cp.box((0, 0, 0.45), (0.36, 0.86, 0.12), "paint_green")
    cp.box((0, 0, 0.57), (0.98, 0.98, 0.10), "lacquer")
    cp.box((0, 0, 0.64), (1.02, 1.02, 0.04), "gold")
    return [sh.obj(), bs.obj(), cp.obj()]


def lantern_piece():
    b = Builder("lantern_paper")
    lantern(b, (0, 0, 0))
    return b.obj()


def awning_canopy():
    """Unit canopy: x 0..1 across the bay, z 0 (back, y 1) .. 1 (front, y 0), Blender Y = -z (the front is -Y)."""
    b = Builder("awning_canopy")
    nx, nz = 24, 10
    xs = np.linspace(0.0, 1.0, nx + 1)
    zs = np.linspace(0.0, 1.0, nz + 1)
    X, Zs = np.meshgrid(xs, zs)
    # concave fall from the back to the front, the front eave turned up at the bay's ends
    Yh = (1.0 - Zs) ** 1.35
    ends = (np.abs(X - 0.5) * 2.0) ** 4
    Yh = Yh + 0.10 * Zs ** 3 * (0.4 + 0.6 * ends)
    corr = 0.035 * np.abs(np.sin(math.pi * X * 22.0)) * (Zs < 0.995)
    top = np.stack([X, -Zs, Yh + corr], -1)
    bot = np.stack([X, -Zs, Yh - 0.05], -1)
    b.grid(top, "tile", smooth=True)
    b.grid(bot, "wood", smooth=True, flip=True)
    for j in range(nx):
        b.face([top[nz, j], top[nz, j + 1], bot[nz, j + 1], bot[nz, j]], "lacquer")
    # rafters under it, ends of each rafter gold-capped
    for k in range(7):
        x = 0.07 + k * 0.86 / 6.0
        pts = [np.array([x, -z, (1.0 - z) ** 1.35 + 0.10 * z ** 3 * (0.4 + 0.6 * (abs(x - 0.5) * 2) ** 4) - 0.075])
               for z in np.linspace(0.02, 1.0, 6)]
        b.tube(pts, [0.035] * len(pts), 6, "lacquer")
    return b.obj()


# ------------------------------------------------------------------------------------------------ glyphs
def glyph_shapes():
    """Our own element glyphs in [-1, 1]^2 (y up): [(polygon, add?)] per element."""
    def circ(cx, cy, rx, ry, a0=0.0, a1=360.0, n=48):
        return [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a)))
                for a in np.linspace(a0, a1, n, endpoint=a1 - a0 < 359.9)]

    def stadium(x0, x1, y, r, n=12):
        pts = [(x1 + r * math.cos(a), y + r * math.sin(a)) for a in np.linspace(-math.pi / 2, math.pi / 2, n)]
        pts += [(x0 + r * math.cos(a), y + r * math.sin(a)) for a in np.linspace(math.pi / 2, 3 * math.pi / 2, n)]
        return pts

    def arc_band(cx, cy, rx, ry, w, a0, a1, n=32):
        o = [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a))) for a in np.linspace(a0, a1, n)]
        i = [(cx + (rx - w) * math.cos(math.radians(a)), cy + (ry - w) * math.sin(math.radians(a)))
             for a in np.linspace(a1, a0, n)]
        return o + i
    earth = [([(-0.80, -0.42), (-0.12, 0.66), (0.42, -0.42)], True),
             ([(0.02, -0.42), (0.44, 0.22), (0.82, -0.42)], True),
             ([(-0.86, -0.72), (0.86, -0.72), (0.86, -0.54), (-0.86, -0.54)], True),
             ([(-0.30, 0.20), (-0.12, 0.48), (0.05, 0.20)], False)]
    # a drop: the tip, then round the bottom from the left tangent to the right one
    drop = [(0.0, 0.80)] + circ(0.0, 0.0, 0.40, 0.40, 150.0, 390.0, 40)
    water = [(drop, True),
             (arc_band(0.0, -0.30, 0.82, 0.42, 0.12, 200.0, 250.0), True),
             (arc_band(0.0, -0.30, 0.82, 0.42, 0.12, 290.0, 340.0), True)]
    fire = [([(0.0, 0.88), (0.34, 0.05), (0.0, -0.78), (-0.34, 0.05)], True),
            ([(0.0, 0.36), (0.13, 0.0), (0.0, -0.36), (-0.13, 0.0)], False),
            ([(-0.58, -0.02), (-0.44, -0.30), (-0.58, -0.58), (-0.72, -0.30)], True),
            ([(0.58, -0.02), (0.72, -0.30), (0.58, -0.58), (0.44, -0.30)], True)]
    air = [(stadium(-0.52, 0.70, 0.42, 0.095), True),
           (stadium(-0.78, 0.42, 0.0, 0.095), True),
           (stadium(-0.36, 0.62, -0.42, 0.095), True),
           (circ(0.86, 0.0, 0.10, 0.10), True)]
    return {"earth": earth, "water": water, "fire": fire, "air": air}


def inside(poly, X, Y):
    poly = np.asarray(poly, float)
    res = np.zeros(X.shape, bool)
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        cond = ((yi > Y) != (yj > Y)) & (X < (xj - xi) * (Y - yi) / (yj - yi + 1e-12) + xi)
        res ^= cond
        j = i
    return res


def glyph_atlas(path, cell=256, ss=4):
    shapes = glyph_shapes()
    n = cell * ss
    t = (np.arange(n) + 0.5) / n * 2.0 - 1.0
    X, Y = np.meshgrid(t, -t)          # row 0 at the top (y = +1)
    img = np.zeros((cell * 2, cell * 2), np.float32)
    for k, el in enumerate(["earth", "water", "fire", "air"]):
        m = np.zeros(X.shape, bool)
        for poly, add in shapes[el]:
            if add:
                m |= inside(poly, X, Y)
        for poly, add in shapes[el]:
            if not add:
                m &= ~inside(poly, X, Y)
        a = m.reshape(cell, ss, cell, ss).mean(axis=(1, 3))
        r, c = divmod(k, 2)
        img[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell] = a
    w = h = cell * 2
    im = bpy.data.images.new("glyphs", w, h, alpha=False)
    px = np.zeros((h, w, 4), np.float32)
    px[..., 0] = px[..., 1] = px[..., 2] = img
    px[..., 3] = 1.0
    im.pixels.foreach_set(px[::-1].ravel())        # Blender's rows run bottom-up
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    # the glyphs as flat meshes too (a reference, and for carving later)
    b = Builder("glyphs")
    for k, el in enumerate(["earth", "water", "fire", "air"]):
        for poly, add in shapes[el]:
            if add:
                b.face([(x * 0.5 + (k - 1.5) * 1.2, 0.0, y * 0.5) for x, y in poly][::-1], "gold")
    return b.obj()


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_animations=False, export_skins=False, export_morph=False)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("RING_KIT %s tris=%d mats=%s" % (os.path.basename(path), tris, [m.name for m in ob.data.materials]))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--blend", default="")
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obs = [gate_pavilion()] + unit_roofs() + pillar_pieces() + [lantern_piece(), awning_canopy()]
    obs.append(glyph_atlas(os.path.join(a.out, "glyphs.png")))
    for ob in obs:
        export(ob, os.path.join(a.out, ob.name + ".glb"))
    if a.blend:
        bpy.ops.wm.save_as_mainfile(filepath=a.blend)
    print("RING_KIT DONE")


if __name__ == "__main__":
    main()
