"""Procedural 1750s trade tomahawk for Frontier, in two mesh variants:

  Tomahawk      (default) forged-iron trade head: flared blade with a bright
                steel bit, drift eye, square spike on the poll
  TomahawkPipe  pipe tomahawk ("smoak tomahawk"): the same blade and eye with a
                moulded pipe bowl on the poll and a lead mouthpiece on the end
                of the drilled haft

Both share a 49 cm hickory haft (file-burnt spiral bands, brass tacks, a spiral
leather wrap where the hand holds it) and a buckskin thong with two glass trade
beads tied under the head.

Run headless (factory scene):
  Blender -b --factory-startup --python tools/models/tomahawk.py -- \
      [--out assets/weapons/tomahawk.glb] [--renders DIR] [--blend FILE.blend] \
      [--verify] [--tex-dir DIR]

  --renders   Blender preview renders (both variants, head close-ups, top view)
  --verify    re-import the exported GLB into an empty scene and check the
              conventions (node names, marker positions, forward axis, sizes,
              textures, triangle budget); with --renders also renders the
              re-imported model with its markers drawn in
  --tex-dir   also write the generated textures there as PNG (for inspection)

Conventions (Godot / glTF axes), matching scripts/weapons/weapon_models_throwables.gd:
  * origin = the throwing grip (centre of the hand), 6.2 cm above the haft end
  * up = +Y: the haft runs up +Y into the head (eye centre y = 0.401)
  * forward = -Z: the cutting edge faces -Z. -Z is the direction the head is
    swung and thrown; the blade leads at release and bites into the target
    along -Z. A throw spins about +X (end over end, top of the model forward).
  * the poll (spike, or pipe bowl) points to +Z; the blade's flat faces are +/-X
  * two meshes at the glTF root, "Tomahawk" (default) and "TomahawkPipe", which is
    exported hidden (KHR_node_visibility, patched into the GLB after export) so
    instancing the whole file shows one tomahawk; ThrowableModels.build("tomahawk")
    keeps Tomahawk, build("tomahawk_pipe") keeps TomahawkPipe and frees the other.
    One material (TomahawkAtlas: base colour, metallic-roughness and normal map)
  * markers (empties at the root, identity rotation, so -Z = throw direction):
      Muzzle   release / leading point of the head: middle of the cutting edge
      Blade    middle of the cutting edge (where it bites)
      Edge     same point as Blade (older name read by thrown_projectile.gd)
      Head     centre of the eye (head on the haft axis)
      COM      centre of mass (mean of the two variants; each is printed)
      Butt     end of the haft
    and, as a child of TomahawkPipe only: Mouthpiece (smoke hole of the lead
    mouthpiece), so it disappears with the pipe variant.

Sizes: head 0.23 m (edge to spike tip) / 0.18 m (edge to bowl back), edge 8.2
cm, haft 0.494 m; iron head 0.44 kg (spike) / 0.55 kg (pipe), whole tomahawk 0.67 /
0.81 kg (the script prints the part masses). Trade and pipe tomahawk figures: haft
under 61 cm, head 260-570 g, edge rarely over 10 cm.

Textures: generated 1024 px atlas, normal map and metallic-roughness map. Read-
only crops of CC0 Poly Haven textures are used as detail when present: the
wooden_axe model's wood and forged iron, brown_leather and scuba_suede
(recoloured). Without them the script falls back to procedural noise.
"""

import argparse
import json
import math
import os
import struct
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

# --------------------------------------------------------------------------
# Dimensions (metres, Godot axes)
# --------------------------------------------------------------------------
Y_BUTT, Y_TOP = -0.062, 0.432
N_HAFT = 16
HAFT = [  # (y, half width x, half depth z): oval, long axis in line with the blade
    (Y_BUTT, 0.0126, 0.0156), (-0.050, 0.0129, 0.0160), (-0.030, 0.0123, 0.0152),
    (0.020, 0.0119, 0.0147), (0.120, 0.0116, 0.0143), (0.240, 0.0112, 0.0138),
    (0.330, 0.0108, 0.0133), (0.372, 0.0110, 0.0136), (0.400, 0.0115, 0.0142),
    (Y_TOP, 0.0121, 0.0150)]
WRAP = (-0.046, 0.066)          # spiral leather wrap (the throwing grip)
WRAP_PITCH = 0.0115
BURN = [(0.100, 0.150), (0.258, 0.308)]
TACK_Y = (0.172, 0.192, 0.212, 0.232)
TIE = (0.359, 0.368)            # buckskin thong tied under the eye

EYE = (0.376, 0.426)
N_EYE = 20
EYE_HX, EYE_HZ_BACK, EYE_HZ_FRONT = 0.0156, 0.0190, 0.0165
HEAD_Y = 0.401

Z_NECK, Z_EDGE, EDGE_CURVE = -0.009, -0.124, 0.009
BEVEL_S = 0.86
BLADE_S = (0.0, 0.1, 0.2, 0.32, 0.44, 0.56, 0.67, 0.77, 0.86, 0.93, 1.0)
BLADE_SEC = [(0, 1), (0.45, 0.97), (0.85, 0.86), (1, 0.55), (1, 0), (1, -0.55), (0.85, -0.86),
             (0.45, -0.97), (0, -1), (-0.45, -0.97), (-0.85, -0.86), (-1, -0.55), (-1, 0),
             (-1, 0.55), (-0.85, 0.86), (-0.45, 0.97)]

SPIKE = [  # (z, centre y, half height, half width): square spike, slightly drooping
    (0.010, 0.4030, 0.0094, 0.0076), (0.019, 0.4030, 0.0090, 0.0072),
    (0.0225, 0.4030, 0.0102, 0.0083), (0.026, 0.4029, 0.0088, 0.0070),
    (0.033, 0.4026, 0.0078, 0.0062), (0.051, 0.4013, 0.0060, 0.0049),
    (0.069, 0.3995, 0.0043, 0.0035), (0.086, 0.3972, 0.0026, 0.0021),
    (0.099, 0.3950, 0.0011, 0.0009), (0.106, 0.3940, 0.0003, 0.0003)]
SPIKE_SEC = [(0.42, 1), (1, 0.42), (1, -0.42), (0.42, -1), (-0.42, -1), (-1, -0.42), (-1, 0.42), (-0.42, 1)]

PIPE_NECK = [(0.010, 0.4020, 0.0165, 0.0074), (0.017, 0.4030, 0.0150, 0.0068),
             (0.023, 0.4045, 0.0132, 0.0066), (0.030, 0.4060, 0.0122, 0.0070)]
BOWL_Z = 0.037
BOWL = [  # lathe profile (r, y) round the vertical axis x = 0, z = BOWL_Z
    (0.0040, 0.3940), (0.0072, 0.3960), (0.0090, 0.4010), (0.0096, 0.4120), (0.0100, 0.4230),
    (0.0116, 0.4270), (0.0118, 0.4300), (0.0106, 0.4330), (0.0114, 0.4420), (0.0136, 0.4510),
    (0.0146, 0.4560), (0.0148, 0.4585), (0.0140, 0.4600), (0.0108, 0.4600), (0.0094, 0.4540),
    (0.0078, 0.4400), (0.0062, 0.4290), (0.0032, 0.4240), (0.0005, 0.4232)]
MOUTH = [  # lead mouthpiece over the haft end: (y, extra on the haft oval | None, round radius)
    (Y_BUTT + 0.018, 0.0004, None), (Y_BUTT + 0.0165, 0.0013, None), (Y_BUTT + 0.001, 0.0013, None),
    (Y_BUTT - 0.0015, -0.0015, None), (Y_BUTT - 0.0025, None, 0.0068), (Y_BUTT - 0.0045, None, 0.0049),
    (Y_BUTT - 0.0068, None, 0.0042), (Y_BUTT - 0.0075, None, 0.0030)]
MOUTH_TIP_Y = Y_BUTT - 0.0075

BLADE_MID_Y = None  # set below (needs the blade outline)

DENSITY = {"iron": 7850.0, "hickory": 820.0, "leather": 950.0, "suede": 900.0,
           "glass": 2500.0, "lead": 11340.0}
TACK_MASS = 0.0009

# --------------------------------------------------------------------------
# Texture atlas layout (u0, u1, v0, v1); v up, as Blender stores pixels
# --------------------------------------------------------------------------
ATLAS = 1024
MARGIN = 3.0 / ATLAS
WOOD = (0.000, 0.195, 0.000, 1.000)       # haft: u round, v along (butt -> top)
IRON_SIDE = (0.200, 1.000, 0.640, 1.000)  # blade, spike, necks: box projection (z, y)
EYE_UV = (0.200, 0.470, 0.360, 0.495)     # eye collar, cylindrical
EYECAP_UV = (0.200, 0.330, 0.500, 0.635)
BOWL_UV = (0.475, 0.700, 0.360, 0.635)
LEATHER = (0.705, 1.000, 0.360, 0.635)    # wrap: u round, v along
SUEDE = (0.705, 1.000, 0.180, 0.355)
BRASS = (0.200, 0.300, 0.180, 0.355)
LEAD = (0.305, 0.450, 0.180, 0.355)
ENDGRAIN = (0.455, 0.600, 0.180, 0.355)
BEAD = (0.605, 0.700, 0.180, 0.355)
IRON_MISC = (0.200, 0.700, 0.360, 0.635)
Z_MIN, Z_MAX, Y_MIN, Y_MAX = -0.132, 0.112, 0.338, 0.462
SIDE_PPM = min((IRON_SIDE[1] - IRON_SIDE[0]) * ATLAS / (Z_MAX - Z_MIN),
               (IRON_SIDE[3] - IRON_SIDE[2]) * ATLAS / (Y_MAX - Y_MIN))

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
POLYHAVEN = os.path.join(PROJECT, "assets", "polyhaven")
SKY = os.path.join(PROJECT, "assets", "environment", "sky", "qwantani_late_afternoon_nosun_2k.exr")
BOX = "box"


def G(x, y, z):
    """Godot-space point expressed in Blender coordinates."""
    return Vector((x, -z, y))


def B2G(v):
    return Vector((v.x, v.z, -v.y))


def lerp(a, b, t):
    return a + (b - a) * t


def interp(table, x, idx):
    if x <= table[0][0]:
        return table[0][idx]
    for a, c in zip(table, table[1:]):
        if x <= c[0]:
            return lerp(a[idx], c[idx], (x - a[0]) / (c[0] - a[0]))
    return table[-1][idx]


def haft_hx(y):
    return interp(HAFT, y, 1)


def haft_hz(y):
    return interp(HAFT, y, 2)


def rect_uv(rect, fu, fv):
    u0, u1, v0, v1 = rect
    return (lerp(u0 + MARGIN, u1 - MARGIN, fu), lerp(v0 + MARGIN, v1 - MARGIN, fv))


def side_uv(z, y):
    u0, u1, v0, v1 = IRON_SIDE
    u = u0 + (z - Z_MIN) * SIDE_PPM / ATLAS
    v = v0 + (y - Y_MIN) * SIDE_PPM / ATLAS
    return (min(max(u, u0 + MARGIN), u1 - MARGIN), min(max(v, v0 + MARGIN), v1 - MARGIN))


# Blade outline (side view), s = 0 at the neck inside the eye, 1 at the edge.
def blade_top(s):
    return 0.4175 - 0.004 * s + 0.015 * s ** 4


def blade_bot(s):
    return 0.3865 + 0.002 * s - 0.042 * s ** 2.6


def blade_t(s):
    if s <= BEVEL_S:
        return lerp(0.0058, 0.0022, s / BEVEL_S)
    return lerp(0.0022, 0.00035, (s - BEVEL_S) / (1.0 - BEVEL_S))


def edge_z(y):
    """z of the cutting edge at height y (convex edge: corners pulled back). Works on
    numpy arrays; heights past the corners are clamped a little beyond them."""
    yc, hh = (blade_top(1) + blade_bot(1)) * 0.5, (blade_top(1) - blade_bot(1)) * 0.5
    f = np.clip((y - yc) / hh, -1.4, 1.4)
    return Z_EDGE + EDGE_CURVE * f * f


BLADE_MID_Y = (blade_top(1.0) + blade_bot(1.0)) * 0.5
EDGE_PT = Vector((0.0, BLADE_MID_Y, Z_EDGE))


# --------------------------------------------------------------------------
# Mesh builder
# --------------------------------------------------------------------------
class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.parts = {}
        self.part = None

    def begin(self, name):
        self.part = name
        self.parts.setdefault(name, [])

    def face(self, verts, uvs, out):
        """Face oriented so its normal follows `out` (Godot vector); `uvs` is a list or BOX."""
        n = Vector()
        for i, a in enumerate(verts):
            b = verts[(i + 1) % len(verts)]
            n.x += (a.co.y - b.co.y) * (a.co.z + b.co.z)
            n.y += (a.co.z - b.co.z) * (a.co.x + b.co.x)
            n.z += (a.co.x - b.co.x) * (a.co.y + b.co.y)
        if n.dot(G(*out)) < 0.0:
            verts = list(reversed(verts))
            if uvs is not BOX:
                uvs = list(reversed(uvs))
        f = self.bm.faces.new(verts)
        f.smooth = True
        f.normal_update()
        if uvs is BOX:
            uvs = box_uv(f)
        for loop, t in zip(f.loops, uvs):
            loop[self.uv].uv = t
        self.parts[self.part].append(f)
        return f

    def loft(self, rings, uvf, out_fn=None, cap0=None, cap1=None, sharp_rings=()):
        """rings: lists of Godot Vectors (closed loops, equal size n). uvf(i, j, p) -> (u, v)
        for ring i, index j in 0..n (n = the seam again), or BOX. cap0 / cap1: None or a
        uv function p -> (u, v) (or BOX) for an n-gon on the first / last ring."""
        n = len(rings[0])
        vs = [[self.bm.verts.new(G(*p)) for p in ring] for ring in rings]
        cents = [sum(ring, Vector()) / n for ring in rings]
        for i in range(len(rings) - 1):
            c = (cents[i] + cents[i + 1]) * 0.5
            for j in range(n):
                k = (j + 1) % n
                pts = [rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]]
                out = out_fn(i, j) if out_fn else sum(pts, Vector()) / 4 - c
                if uvf is BOX:
                    uvs = BOX
                else:
                    uvs = [uvf(i, j, pts[0]), uvf(i, j + 1, pts[1]), uvf(i + 1, j + 1, pts[2]), uvf(i + 1, j, pts[3])]
                self.face([vs[i][j], vs[i][k], vs[i + 1][k], vs[i + 1][j]], uvs, out)
        for i in sharp_rings:
            for j in range(n):
                e = self.bm.edges.get([vs[i][j], vs[i][(j + 1) % n]])
                if e:
                    e.smooth = False
        for cap, idx, other in ((cap0, 0, 1), (cap1, -1, -2)):
            if cap is None:
                continue
            ring = rings[idx]
            uvs = BOX if cap is BOX else [cap(p) for p in ring]
            f = self.face(list(vs[idx]), uvs, cents[idx] - cents[other])
            for e in f.edges:
                e.smooth = False
        return vs

    def to_mesh(self, name):
        ngons = [f for f in self.bm.faces if len(f.verts) > 4]
        bmesh.ops.triangulate(self.bm, faces=ngons, quad_method="BEAUTY", ngon_method="BEAUTY")
        self.bm.edges.index_update()
        manual = [e.index for e in self.bm.edges if not e.smooth]
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        me.shade_smooth()
        # Smooth shading split at creases over 38 degrees, plus the edges marked sharp
        # while building (blade bevel line, cap rims, mouldings).
        me.set_sharp_from_angle(angle=math.radians(38.0))
        attr = me.attributes.get("sharp_edge") or me.attributes.new("sharp_edge", "BOOLEAN", "EDGE")
        vals = [False] * len(me.edges)
        attr.data.foreach_get("value", vals)
        for i in manual:
            vals[i] = True
        attr.data.foreach_set("value", vals)
        me.validate()
        return me


def box_uv(f):
    """Box projection into the IRON_SIDE area (side view (z, y); tops use (z, y + x))."""
    n = B2G(f.normal)
    c = B2G(f.calc_center_median())
    ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
    out = []
    for loop in f.loops:
        p = B2G(loop.vert.co)
        if ax >= ay and ax >= az:
            out.append(side_uv(p.z, p.y))
        elif ay >= az:
            out.append(side_uv(p.z, c.y + p.x))
        else:
            out.append(side_uv(c.z + p.x, p.y))
    return out


def oval_ring(y, hx, hz, n):
    """Ring round the haft axis; j = 0 at +Z (the poll side, where the UV seam goes)."""
    return [Vector((hx * math.sin(2 * math.pi * j / n), y, hz * math.cos(2 * math.pi * j / n))) for j in range(n)]


def polygon_area(hx, hz, n):
    return 0.5 * n * math.sin(2 * math.pi / n) * hx * hz


def haft_overlap(y0, y1, steps=24):
    """Volume and centroid y of the haft between y0 and y1 (to subtract from sleeves)."""
    v, m = 0.0, 0.0
    for i in range(steps):
        ya = lerp(y0, y1, i / steps)
        yb = lerp(y0, y1, (i + 1) / steps)
        ym = (ya + yb) * 0.5
        a = polygon_area(haft_hx(ym), haft_hz(ym), N_HAFT) * (yb - ya)
        v += a
        m += a * ym
    return v, (m / v if v else 0.0)


# --------------------------------------------------------------------------
# Parts
# --------------------------------------------------------------------------
def endgrain_uv(p):
    k = 0.46 / 0.018
    return rect_uv(ENDGRAIN, 0.5 + p.x * k, 0.5 + p.z * k)


def build_haft(b):
    b.begin("haft")
    ys = [(Y_BUTT, 0.80), (Y_BUTT + 0.0015, 0.93), (Y_BUTT + 0.004, 1.0)]
    ys += [(h[0], 1.0) for h in HAFT[1:-1]]
    ys += [(Y_TOP - 0.0035, 1.0), (Y_TOP - 0.0012, 0.95), (Y_TOP, 0.86)]
    rings = [oval_ring(y, haft_hx(y) * k, haft_hz(y) * k, N_HAFT) for y, k in ys]

    def uvf(i, j, p):
        return rect_uv(WOOD, j / N_HAFT, (p.y - Y_BUTT) / (Y_TOP - Y_BUTT))
    b.loft(rings, uvf, cap0=endgrain_uv, cap1=endgrain_uv)


def build_wrap(b):
    b.begin("wrap")
    st = [(WRAP[0], 0.0003), (WRAP[0] + 0.0025, 0.0017), (-0.020, 0.0017), (0.020, 0.0017),
          (WRAP[1] - 0.0025, 0.0017), (WRAP[1], 0.0003)]
    rings = [oval_ring(y, haft_hx(y) + e, haft_hz(y) + e, N_HAFT) for y, e in st]

    def uvf(i, j, p):
        return rect_uv(LEATHER, j / N_HAFT, (p.y - WRAP[0]) / (WRAP[1] - WRAP[0]))
    cap = lambda p: rect_uv(LEATHER, 0.5, 0.02)
    b.loft(rings, uvf, cap0=cap, cap1=cap)


def build_tacks(b):
    """Brass tacks in a row down each side of the haft (point masses for the COM)."""
    b.begin("tacks")
    n = 6
    for sgn in (1.0, -1.0):
        for y in TACK_Y:
            hx = haft_hx(y)
            rings = []
            for off, r in ((-0.0004, 0.0027), (0.0009, 0.0019)):
                rings.append([Vector((sgn * (hx + off), y + r * math.cos(2 * math.pi * j / n), r * math.sin(2 * math.pi * j / n))) for j in range(n)])

            def uvf(i, j, p, y=y):
                return rect_uv(BRASS, 0.5 + (p.z / 0.006), 0.5 + (p.y - y) / 0.006)
            b.loft(rings, uvf, out_fn=lambda i, j, s=sgn: Vector((s, 0, 0)),
                   cap1=lambda p, y=y: rect_uv(BRASS, 0.5 + p.z / 0.006, 0.5 + (p.y - y) / 0.006))


def build_tie(b):
    b.begin("tie")
    st = [(TIE[0], 0.0004), (TIE[0] + 0.002, 0.0021), (TIE[1] - 0.002, 0.0021), (TIE[1], 0.0004)]
    rings = [oval_ring(y, haft_hx(y) + e, haft_hz(y) + e, N_HAFT) for y, e in st]

    def uvf(i, j, p):
        return rect_uv(SUEDE, j / N_HAFT, 0.72 + 0.26 * (p.y - TIE[0]) / (TIE[1] - TIE[0]))
    cap = lambda p: rect_uv(SUEDE, 0.5, 0.75)
    b.loft(rings, uvf, cap0=cap, cap1=cap)


def tail_curve(sgn, nt=8):
    pts = []
    for i in range(nt):
        t = i / (nt - 1)
        y = TIE[0] + 0.002 - 0.118 * t
        x = sgn * (0.0035 + 0.009 * t)
        z = haft_hz(y) + 0.0018 + 0.010 * t + 0.008 * t * t
        pts.append(Vector((x, y, z)))
    return pts


def build_tails(b):
    """Two buckskin thong ends hanging down the poll side, each with a trade bead."""
    beads = []
    for side, sgn in enumerate((1.0, -1.0)):
        b.begin("tails")
        pts = tail_curve(sgn)
        nt = len(pts)
        rings = []
        frames = []
        for i, p in enumerate(pts):
            tan = (pts[min(i + 1, nt - 1)] - pts[max(i - 1, 0)]).normalized()
            nrm = Vector((0.0, 0.0, 1.0))
            nrm = (nrm - tan * nrm.dot(tan)).normalized()
            wid = nrm.cross(tan).normalized()
            tw = 0.45 * sgn * i / (nt - 1)
            wid, nrm = wid * math.cos(tw) + nrm * math.sin(tw), nrm * math.cos(tw) - wid * math.sin(tw)
            w = 0.0025 * (1.0 - 0.25 * i / (nt - 1))
            th = 0.00055
            rings.append([p + wid * w + nrm * th, p - wid * w + nrm * th, p - wid * w - nrm * th, p + wid * w - nrm * th])
            frames.append((p, tan, wid, nrm))
        u_lo = 0.02 + 0.5 * side

        def uvf(i, j, p, u_lo=u_lo):
            return rect_uv(SUEDE, u_lo + 0.46 * i / (nt - 1), 0.05 + 0.6 * j / 4)
        b.loft(rings, uvf, cap0=lambda p: rect_uv(SUEDE, u_lo, 0.3), cap1=lambda p: rect_uv(SUEDE, u_lo + 0.46, 0.3))
        # Bead at 70% down the thong.
        t = 0.70 * (nt - 1)
        i0 = int(t)
        f = t - i0
        p = pts[i0].lerp(pts[i0 + 1], f)
        _, tan, wid, nrm = frames[i0]
        beads.append((p, tan, wid, nrm, side))
    b.begin("beads")
    for p, tan, wid, nrm, side in beads:
        r = 0.0036
        n = 8
        rings = []
        for lat in (-0.62, -0.3, 0.0, 0.3, 0.62):
            rr = r * math.cos(lat * 1.2)
            off = tan * (r * math.sin(lat * 1.2) * 0.9)
            rings.append([p + off + (wid * math.cos(2 * math.pi * j / n) + nrm * math.sin(2 * math.pi * j / n)) * rr for j in range(n)])
        u_lo = 0.0 if side == 0 else 0.5

        def uvf(i, j, q, u_lo=u_lo):
            return rect_uv(BEAD, u_lo + 0.48 * j / n, 0.1 + 0.8 * i / 4)
        cap = lambda q, u_lo=u_lo: rect_uv(BEAD, u_lo + 0.24, 0.5)
        b.loft(rings, uvf, cap0=cap, cap1=cap)


def build_eye(b):
    b.begin("eye")

    def ring(y, k):
        pts = []
        for j in range(N_EYE):
            a = 2 * math.pi * j / N_EYE
            hz = EYE_HZ_BACK if math.cos(a) > 0 else EYE_HZ_FRONT
            pts.append(Vector((EYE_HX * k * math.sin(a), y, hz * k * math.cos(a))))
        return pts
    st = [(EYE[0], 0.93), (EYE[0] + 0.0035, 1.0), (HEAD_Y, 0.985), (EYE[1] - 0.0035, 1.0), (EYE[1], 0.93)]
    rings = [ring(y, k) for y, k in st]

    def uvf(i, j, p):
        return rect_uv(EYE_UV, j / N_EYE, (p.y - EYE[0]) / (EYE[1] - EYE[0]))
    cap = lambda p: rect_uv(EYECAP_UV, 0.5 + p.x / 0.042, 0.5 + p.z / 0.042)
    b.loft(rings, uvf, cap0=cap, cap1=cap)


def build_blade(b):
    b.begin("blade")
    rings = []
    for s in BLADE_S:
        top, bot = blade_top(s), blade_bot(s)
        yc, hh = (top + bot) * 0.5, (top - bot) * 0.5
        t = blade_t(s)
        z0 = lerp(Z_NECK, Z_EDGE, s)
        ring = []
        for xf, yf in BLADE_SEC:
            ring.append(Vector((xf * t * (1.0 + 0.10 * (1.0 - yf * yf)), yc + yf * hh, z0 + EDGE_CURVE * s ** 3 * yf * yf)))
        rings.append(ring)
    b.loft(rings, BOX, cap0=BOX, cap1=BOX, sharp_rings=(BLADE_S.index(BEVEL_S),))


def build_spike(b):
    b.begin("spike")
    rings = [[Vector((px * hw, yc + py * hh, z)) for px, py in SPIKE_SEC] for z, yc, hh, hw in SPIKE]
    b.loft(rings, BOX, cap0=BOX, cap1=BOX, sharp_rings=(2,))


def build_pipe(b):
    b.begin("neck")
    n = 12
    rings = [[Vector((hw * math.sin(2 * math.pi * j / n), yc + hh * math.cos(2 * math.pi * j / n), z)) for j in range(n)]
             for z, yc, hh, hw in PIPE_NECK]
    b.loft(rings, BOX, cap0=BOX, cap1=BOX)
    b.begin("bowl")
    n = 16
    rings = [[Vector((r * math.sin(2 * math.pi * j / n), y, BOWL_Z + r * math.cos(2 * math.pi * j / n))) for j in range(n)]
             for r, y in BOWL]
    lens = [0.0]
    for (ra, ya), (rc, yc) in zip(BOWL, BOWL[1:]):
        lens.append(lens[-1] + math.hypot(rc - ra, yc - ya))

    def uvf(i, j, p):
        return rect_uv(BOWL_UV, j / n, lens[i] / lens[-1])

    def outs(i, j):
        (ra, ya), (rc, yc) = BOWL[i], BOWL[i + 1]
        a = 2 * math.pi * (j + 0.5) / n
        dr, dy = rc - ra, yc - ya
        return Vector((math.sin(a) * dy, -dr, math.cos(a) * dy))
    b.loft(rings, uvf, out_fn=outs, cap0=lambda p: rect_uv(BOWL_UV, 0.5, 0.01),
           cap1=lambda p: rect_uv(BOWL_UV, 0.5, 0.99), sharp_rings=(5, 7, 12, 13))


def build_mouthpiece(b):
    b.begin("mouth")
    n = N_HAFT
    rings = []
    for y, extra, r in MOUTH:
        if r is None:
            rings.append(oval_ring(y, haft_hx(Y_BUTT) + extra, haft_hz(Y_BUTT) + extra, n))
        else:
            rings.append(oval_ring(y, r, r, n))
    lens = [0.0]
    for a, c in zip(rings, rings[1:]):
        lens.append(lens[-1] + (a[0] - c[0]).length)

    def uvf(i, j, p):
        return rect_uv(LEAD, 0.48 * j / n, lens[i] / lens[-1])
    hole = lambda p: rect_uv(LEAD, 0.75 + p.x / 0.016, 0.5 + p.z / 0.016)
    b.loft(rings, uvf, cap0=lambda p: rect_uv(LEAD, 0.25, 0.02), cap1=hole, sharp_rings=(1, 2))


# --------------------------------------------------------------------------
# Mass / centre of mass
# --------------------------------------------------------------------------
def part_volume(faces):
    vol, mom = 0.0, Vector()
    for f in faces:
        vs = [loop.vert.co for loop in f.loops]
        for k in range(1, len(vs) - 1):
            a, b_, c = vs[0], vs[k], vs[k + 1]
            v = a.dot(b_.cross(c)) / 6.0
            vol += v
            mom += v * (a + b_ + c) / 4.0
    return vol, (B2G(mom / vol) if vol else Vector())


def mass_report(b, variant):
    """[(part, kg, centroid)] with the haft volume inside sleeves and the eye removed."""
    mat = {"haft": "hickory", "wrap": "leather", "tie": "suede", "tails": "suede", "beads": "glass",
           "eye": "iron", "blade": "iron", "spike": "iron", "neck": "iron", "bowl": "iron", "mouth": "lead"}
    sleeves = {"wrap": WRAP, "tie": TIE, "eye": EYE, "mouth": (Y_BUTT, Y_BUTT + 0.018)}
    rows = []
    for name, faces in b.parts.items():
        if name == "tacks":
            for y in TACK_Y:
                for sgn in (1.0, -1.0):
                    rows.append(("tacks", TACK_MASS, Vector((sgn * haft_hx(y), y, 0.0))))
            continue
        vol, cen = part_volume(faces)
        if vol <= 0.0:
            raise RuntimeError("%s: part %s has non-positive volume %.3g (inward faces?)" % (variant, name, vol))
        rho = DENSITY[mat[name]]
        m, mom = rho * vol, cen * (rho * vol)
        if name in sleeves:
            ov, oy = haft_overlap(*sleeves[name])
            m -= rho * ov
            mom -= Vector((0.0, oy, 0.0)) * (rho * ov)
        rows.append((name, m, mom / m))
    return rows


def com_of(rows):
    tot = sum(r[1] for r in rows)
    return sum((r[2] * r[1] for r in rows), Vector()) / tot, tot


# --------------------------------------------------------------------------
# Textures
# --------------------------------------------------------------------------
def load_px(path):
    """RGB float array, rows bottom-up (Blender's order), or None."""
    if not os.path.exists(path):
        return None
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[:, :, :3].copy()


def crop(a, rect):
    """rect = (x0, y0, x1, y1) in top-down pixel coordinates (as an image viewer shows it)."""
    h = a.shape[0]
    x0, y0, x1, y1 = rect
    return a[h - y1:h - y0, x0:x1].copy()


def resize(a, h, w):
    h0, w0 = a.shape[:2]
    ys = np.clip((np.arange(h) + 0.5) * h0 / h - 0.5, 0, h0 - 1)
    xs = np.clip((np.arange(w) + 0.5) * w0 / w - 0.5, 0, w0 - 1)
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    y1 = np.minimum(y0 + 1, h0 - 1)
    x1 = np.minimum(x0 + 1, w0 - 1)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    if a.ndim == 3:
        fy, fx = fy[..., None], fx[..., None]
    top = a[y0][:, x0] * (1 - fx) + a[y0][:, x1] * fx
    bot = a[y1][:, x0] * (1 - fx) + a[y1][:, x1] * fx
    return (top * (1 - fy) + bot * fy).astype(np.float32)


def dec_normal(a):
    n = a * 2.0 - 1.0
    return n / np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)


def renorm(n):
    return n / np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)


def flip_u(a, normal=False):
    b = a[:, ::-1].copy()
    if normal:
        b[..., 0] *= -1.0
    return b


def flip_v(a, normal=False):
    b = a[::-1].copy()
    if normal:
        b[..., 1] *= -1.0
    return b


def rot90(a, normal=False):
    """Rotate 90 degrees counter-clockwise (u right, v up)."""
    b = a.transpose(1, 0, 2)[:, ::-1].copy()
    if normal:
        nx, ny = b[..., 0].copy(), b[..., 1].copy()
        b[..., 0], b[..., 1] = -ny, nx
    return b


def mirror_tile(a, h, w, normal=False):
    rows = []
    k = 0
    while sum(r.shape[0] for r in rows) < h:
        rows.append(a if k % 2 == 0 else flip_v(a, normal))
        k += 1
    col = np.concatenate(rows, axis=0)[:h]
    cols = []
    k = 0
    while sum(c.shape[1] for c in cols) < w:
        cols.append(col if k % 2 == 0 else flip_u(col, normal))
        k += 1
    return np.concatenate(cols, axis=1)[:, :w]


def value_noise(h, w, seed, cell):
    rng = np.random.default_rng(seed)
    small = rng.random((max(int(h / cell) + 2, 2), max(int(w / cell) + 2, 2))).astype(np.float32)
    ys = np.arange(h) / cell
    xs = np.arange(w) / cell
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = small[y0][:, x0] * (1 - fx) + small[y0][:, x0 + 1] * fx
    c = small[y0 + 1][:, x0] * (1 - fx) + small[y0 + 1][:, x0 + 1] * fx
    return a * (1 - fy) + c * fy


def fbm(h, w, seed, cell, octaves=4):
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += amp * value_noise(h, w, seed + o * 17, max(cell / 2 ** o, 1.0))
        tot += amp
        amp *= 0.5
    return out / tot


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def dimples(h, w, count, rmin, rmax, seed):
    """Hammer-peen height field (negative dents)."""
    rng = np.random.default_rng(seed)
    hf = np.zeros((h, w), np.float32)
    for _ in range(count):
        r = rng.uniform(rmin, rmax)
        cy, cx = rng.uniform(0, h), rng.uniform(0, w)
        d = rng.uniform(0.4, 1.0)
        y0, y1 = int(max(cy - r, 0)), int(min(cy + r + 1, h))
        x0, x1 = int(max(cx - r, 0)), int(min(cx + r + 1, w))
        if y1 <= y0 or x1 <= x0:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        q = ((yy - cy) ** 2 + (xx - cx) ** 2) / (r * r)
        hf[y0:y1, x0:x1] -= d * np.clip(1.0 - q, 0.0, None) ** 2
    return hf


def height_normal(hf, strength):
    dy, dx = np.gradient(hf)
    n = np.stack([-dx * strength, -dy * strength, np.ones_like(hf)], axis=2)
    return renorm(n)


def blend_normals(a, b):
    """Whiteout blend of two tangent-space normals."""
    return renorm(np.stack([a[..., 0] + b[..., 0], a[..., 1] + b[..., 1], a[..., 2] * b[..., 2]], axis=2))


def lum(a):
    return a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11


class Atlas:
    def __init__(self, size):
        self.n = size
        self.col = np.full((size, size, 3), 0.45, np.float32)
        self.nor = np.zeros((size, size, 3), np.float32)
        self.nor[..., 2] = 1.0
        self.rough = np.full((size, size), 0.6, np.float32)
        self.metal = np.zeros((size, size), np.float32)

    def region(self, rect):
        u0, u1, v0, v1 = rect
        rs = slice(int(round(v0 * self.n)), int(round(v1 * self.n)))
        cs = slice(int(round(u0 * self.n)), int(round(u1 * self.n)))
        h, w = rs.stop - rs.start, cs.stop - cs.start
        fv = ((np.arange(h) + 0.5) / h)[:, None] * np.ones((1, w), np.float32)
        fu = np.ones((h, 1), np.float32) * ((np.arange(w) + 0.5) / w)[None, :]
        return (rs, cs), h, w, fu, fv


def photo(name, rect, h, w, normal=False):
    """Crop of a Poly Haven texture, resized to (h, w); None if the file is missing."""
    a = load_px(os.path.join(POLYHAVEN, name))
    if a is None:
        return None
    a = crop(a, rect)
    if normal:
        a = dec_normal(a)
    a = resize(a, h, w)
    return renorm(a) if normal else a


def paint_wood(at, src):
    (rs, cs), h, w, fu, fv = at.region(WOOD)
    y = Y_BUTT + fv * (Y_TOP - Y_BUTT)
    hick = np.array([0.47, 0.31, 0.185], np.float32)
    if src.get("wood") is not None:
        c = resize(src["wood"], h, w)
        c = c / c.reshape(-1, 3).mean(0) * hick
        c = hick + (c - hick) * 1.25
        nor = renorm(resize(src["wood_n"], h, w))
        r = resize(src["wood_r"], h, w)
        rough = 0.58 + (r - r.mean()) * 0.6
    else:
        g = 0.5 + 0.5 * np.sin(2 * math.pi * (fu * 9 + 0.4 * fbm(h, w, 3, 40)))
        c = hick * (0.8 + 0.25 * g[..., None])
        nor = np.dstack([np.zeros((h, w)), np.zeros((h, w)), np.ones((h, w))]).astype(np.float32)
        rough = np.full((h, w), 0.58, np.float32)
    # Hand polish and grime at the grip, soot and oil at the head.
    grime = 0.12 * smoothstep(0.07, 0.03, y) * smoothstep(-0.07, -0.05, y) + 0.14 * smoothstep(0.33, 0.40, y)
    c = c * (1.0 - grime[..., None]) * (0.94 + 0.12 * fbm(h, w, 5, 60))[..., None]
    rough = rough - 0.10 * smoothstep(0.12, 0.05, y)
    # File-burnt decoration: two-start spirals between thin rings.
    height = np.zeros((h, w), np.float32)
    burn = np.zeros((h, w), np.float32)
    for y0, y1 in BURN:
        inside = smoothstep(y0 - 0.0006, y0 + 0.0006, y) * smoothstep(y1 + 0.0006, y1 - 0.0006, y)
        phase = fu * 2.0 + (y - y0) / 0.013
        f = np.abs(phase - np.floor(phase) - 0.5)
        spiral = smoothstep(0.13, 0.065, f)
        rings = smoothstep(0.0011, 0.0004, np.minimum(np.abs(y - y0 - 0.0015), np.abs(y - y1 + 0.0015)))
        m = np.maximum(spiral * inside, rings * smoothstep(y0 - 0.001, y0, y) * smoothstep(y1 + 0.001, y1, y))
        m = np.clip(m * (0.8 + 0.4 * fbm(h, w, 7, 6)), 0.0, 1.0)
        burn = np.maximum(burn, m)
    height -= burn
    char = np.array([0.075, 0.048, 0.032], np.float32)
    halo = np.clip(burn * 1.6, 0.0, 1.0)
    c = c * (1.0 - 0.35 * halo[..., None]) * (1 - burn[..., None]) + char * burn[..., None]
    rough = rough * (1 - burn) + 0.82 * burn
    nor = blend_normals(nor, height_normal(height, 1.2))
    at.col[rs, cs] = c
    at.nor[rs, cs] = nor
    at.rough[rs, cs] = rough
    at.metal[rs, cs] = 0.0


def paint_endgrain(at):
    (rs, cs), h, w, fu, fv = at.region(ENDGRAIN)
    x = (fu - 0.5 + 0.06) * 2.0
    yy = (fv - 0.5 + 0.04) * 2.0
    r = np.sqrt(x * x + yy * yy) + 0.04 * fbm(h, w, 21, 10)
    rings = 0.5 + 0.5 * np.sin(r * 55.0)
    c = np.array([0.40, 0.26, 0.15], np.float32) * (0.78 + 0.22 * rings[..., None])
    at.col[rs, cs] = c * (0.9 + 0.2 * fbm(h, w, 22, 4))[..., None]
    at.nor[rs, cs] = height_normal(rings * 0.3, 1.0)
    at.rough[rs, cs] = 0.7
    at.metal[rs, cs] = 0.0


def iron_detail(src, h, w):
    """Photo detail of forged iron (Poly Haven wooden_axe head) tiled to (h, w)."""
    if src.get("iron_a") is None:
        return None, None, None
    a_c, a_n, a_r = src["iron_a"], src["iron_a_n"], src["iron_a_r"]
    b_c, b_n, b_r = rot90(src["iron_b"]), rot90(src["iron_b_n"], True), rot90(src["iron_b_r"][..., None])[..., 0]
    wd = 450
    a_c, a_n, a_r = resize(a_c, 145, wd), renorm(resize(a_n, 145, wd)), resize(a_r, 145, wd)
    b_c, b_n, b_r = resize(b_c, 150, wd), renorm(resize(b_n, 150, wd)), resize(b_r, 150, wd)
    a_c = a_c / lum(a_c).mean()
    b_c = b_c / lum(b_c).mean()
    # Cross-fade the strips over 16 rows.
    ov = 16
    t = np.linspace(0, 1, ov, dtype=np.float32)[:, None]
    col = np.concatenate([a_c[:-ov], a_c[-ov:] * (1 - t[..., None]) + b_c[:ov] * t[..., None], b_c[ov:]], axis=0)
    nor = np.concatenate([a_n[:-ov], renorm(a_n[-ov:] * (1 - t[..., None]) + b_n[:ov] * t[..., None]), b_n[ov:]], axis=0)
    rgh = np.concatenate([a_r[:-ov], a_r[-ov:] * (1 - t) + b_r[:ov] * t, b_r[ov:]], axis=0)
    return (mirror_tile(col, h, w), mirror_tile(nor, h, w, True), mirror_tile(rgh[..., None], h, w)[..., 0])


def paint_iron(at, src, rect, seed, bit=False):
    (rs, cs), h, w, fu, fv = at.region(rect)
    det_c, det_n, det_r = iron_detail(src, h, w)
    mott = fbm(h, w, seed, 48)
    fine = fbm(h, w, seed + 5, 6, 3)
    base = np.array([0.185, 0.186, 0.192], np.float32)
    hf = dimples(h, w, int(h * w / 420), 3.5, 9.0, seed + 9) * 0.7
    hn = (hf - hf.min()) / max(float(hf.max() - hf.min()), 1e-6)
    if det_c is not None:
        dl = np.clip(lum(det_c), 0.55, 1.6) ** 0.45
        tint = det_c / np.maximum(lum(det_c)[..., None], 1e-3)
        c = base * dl[..., None] * (0.75 + 0.25 * tint)
        dn = renorm(np.dstack([det_n[..., 0] * 0.6, det_n[..., 1] * 0.6, det_n[..., 2]]))
        nor = blend_normals(dn, height_normal(hf, 1.1))
        rough = 0.52 + (det_r - det_r.mean()) * 0.5
    else:
        c = base * (0.85 + 0.3 * fine[..., None])
        nor = height_normal(hf + fine * 0.5, 1.5)
        rough = np.full((h, w), 0.52, np.float32)
    # Forge scale: broad darker / bluish and lighter / brownish patches; dent rims worn bright.
    scale = fbm(h, w, seed + 21, 90, 3)
    c = c * (0.78 + 0.44 * mott[..., None])
    c = c * (1 - 0.25 * scale[..., None]) + np.array([0.24, 0.215, 0.19], np.float32) * 0.25 * scale[..., None]
    rim = np.clip(np.abs(np.gradient(hf)[0]) + np.abs(np.gradient(hf)[1]), 0, 0.2) * 5.0
    c = c * (1.0 + 0.18 * rim[..., None])
    # Rust in the dents.
    rust = np.clip(smoothstep(0.58, 0.85, fbm(h, w, seed + 3, 14)) * smoothstep(0.75, 0.35, hn), 0.0, 1.0) * 0.45
    rc = np.array([0.30, 0.17, 0.10], np.float32) * (0.8 + 0.4 * fine[..., None])
    c = c * (1 - rust[..., None]) + rc * rust[..., None]
    rough = rough * (1 - rust) + 0.85 * rust - 0.08 * rim
    metal = 0.75 * (1 - rust) + 0.2 * rust
    if bit:
        # Bright filed/ground steel bit along the curved edge; grinding marks run along z.
        # Pixel -> model (z, y): the inverse of side_uv().
        z = Z_MIN + fu * w / SIDE_PPM
        y = Y_MIN + fv * h / SIDE_PPM
        d = z - edge_z(y)
        band = 0.0095 + 0.0025 * (value_noise(h, w, seed + 11, 40) - 0.5) * 2
        m = smoothstep(band + 0.0008, band - 0.0012, d)
        # Per-row random values, smooth along u (z): grinding scratches across the edge.
        streak = resize(np.random.default_rng(seed + 13).random((h, 16)).astype(np.float32), h, w)
        steel = np.array([0.55, 0.555, 0.55], np.float32) * (0.88 + 0.2 * streak[..., None])
        edge_ox = np.exp(-((d - band) / 0.0012) ** 2) * 0.45
        c = c * (1 - edge_ox[..., None]) * (1 - m[..., None]) + steel * m[..., None]
        rough = rough * (1 - m) + (0.28 + 0.1 * streak) * m
        metal = metal * (1 - m) + 1.0 * m
        nor = renorm(nor * (1 - m[..., None]) + np.array([0, 0, 1], np.float32) * m[..., None]
                     + np.stack([np.zeros_like(streak), (streak - 0.5) * 0.15 * m, np.zeros_like(streak)], axis=2))
    at.col[rs, cs] = np.clip(c, 0, 1)
    at.nor[rs, cs] = nor
    at.rough[rs, cs] = np.clip(rough, 0.05, 1.0)
    at.metal[rs, cs] = metal


def paint_leather(at, src):
    (rs, cs), h, w, fu, fv = at.region(LEATHER)
    dark = np.array([0.26, 0.155, 0.085], np.float32)
    if src.get("leather") is not None:
        l = lum(resize(src["leather"], h, w))
        c = dark * (l / l.mean())[..., None]
        nor = renorm(resize(src["leather_n"], h, w))
    else:
        c = dark * (0.85 + 0.3 * fbm(h, w, 31, 5))[..., None]
        nor = height_normal(fbm(h, w, 32, 3), 1.0)
    y = WRAP[0] + fv * (WRAP[1] - WRAP[0])
    phase = fu + (y - WRAP[0]) / WRAP_PITCH
    f = phase - np.floor(phase)
    strap = np.sin(np.pi * f) ** 0.45
    groove = smoothstep(0.10, 0.0, np.minimum(f, 1 - f))
    c = c * (0.72 + 0.34 * strap[..., None]) * (1 - 0.45 * groove[..., None])
    c = c * (1.0 + 0.18 * smoothstep(0.6, 0.95, fbm(h, w, 33, 30)))[..., None]  # worn shiny patches
    nor = blend_normals(nor, height_normal(strap * 6.0, 0.35))
    at.col[rs, cs] = c
    at.nor[rs, cs] = nor
    at.rough[rs, cs] = 0.6 + 0.2 * groove - 0.12 * smoothstep(0.6, 0.95, fbm(h, w, 33, 30))
    at.metal[rs, cs] = 0.0


def paint_suede(at, src):
    (rs, cs), h, w, fu, fv = at.region(SUEDE)
    tan = np.array([0.56, 0.42, 0.27], np.float32)
    if src.get("suede") is not None:
        l = lum(resize(src["suede"], h, w))
        c = tan * (l / l.mean())[..., None]
        nor = renorm(resize(src["suede_n"], h, w))
        nor = renorm(np.dstack([nor[..., 0] * 0.6, nor[..., 1] * 0.6, nor[..., 2]]))
    else:
        c = tan * (0.85 + 0.3 * fbm(h, w, 41, 4))[..., None]
        nor = height_normal(fbm(h, w, 42, 2), 0.5)
    c = c * (0.9 + 0.2 * fbm(h, w, 43, 25))[..., None]
    at.col[rs, cs] = c
    at.nor[rs, cs] = nor
    at.rough[rs, cs] = 0.93
    at.metal[rs, cs] = 0.0


def paint_flat(at, rect, color, rough, metal, seed, var=0.2):
    (rs, cs), h, w, fu, fv = at.region(rect)
    n = fbm(h, w, seed, 6)
    at.col[rs, cs] = np.array(color, np.float32) * (1 - var / 2 + var * n)[..., None]
    at.nor[rs, cs] = height_normal(n * 2.0, 0.4)
    at.rough[rs, cs] = rough
    at.metal[rs, cs] = metal
    return (rs, cs), h, w, fu, fv


def make_textures():
    at = Atlas(ATLAS)
    src = {}
    axe = "models/wooden_axe/textures/wooden_axe_"
    # Crops (top-down pixels of the 2k maps): two forged iron strips and straight-grain wood.
    iron_a, iron_b, wood = (565, 962, 1005, 1105), (320, 480, 480, 950), (1165, 730, 1330, 2025)
    diff = load_px(os.path.join(POLYHAVEN, axe + "diff_2k.jpg"))
    nor = load_px(os.path.join(POLYHAVEN, axe + "nor_gl_2k.jpg"))
    arm = load_px(os.path.join(POLYHAVEN, axe + "arm_2k.jpg"))
    if diff is not None and nor is not None and arm is not None:
        for key, rect in (("iron_a", iron_a), ("iron_b", iron_b), ("wood", wood)):
            src[key] = crop(diff, rect)
            src[key + "_n"] = dec_normal(crop(nor, rect))
            src[key + "_r"] = crop(arm, rect)[..., 1]
    del diff, nor, arm
    leather = "textures/clothing/brown_leather/brown_leather_"
    suede = "textures/clothing/scuba_suede/scuba_suede_"
    src["leather"] = photo(leather + "diffuse_2k.jpg", (300, 300, 780, 750), 282, 302)
    if src["leather"] is not None:
        src["leather_n"] = photo(leather + "nor_gl_2k.jpg", (300, 300, 780, 750), 282, 302, normal=True)
    src["suede"] = photo(suede + "diffuse_2k.jpg", (300, 300, 780, 580), 179, 302)
    if src["suede"] is not None:
        src["suede_n"] = photo(suede + "nor_gl_2k.jpg", (300, 300, 780, 580), 179, 302, normal=True)

    paint_flat(at, (0.0, 1.0, 0.0, 1.0), (0.42, 0.42, 0.42), 0.6, 0.0, 1)
    paint_wood(at, src)
    paint_endgrain(at)
    paint_iron(at, src, IRON_SIDE, 100, bit=True)
    paint_iron(at, src, IRON_MISC, 200)
    paint_leather(at, src)
    paint_suede(at, src)
    paint_flat(at, BRASS, (0.80, 0.62, 0.32), 0.32, 1.0, 51, 0.25)
    (rs, cs), h, w, fu, fv = paint_flat(at, LEAD, (0.50, 0.50, 0.52), 0.48, 0.9, 52, 0.3)
    hole = np.sqrt(((fu - 0.75) * (LEAD[1] - LEAD[0]) / 0.016) ** 2 + ((fv - 0.5) * (LEAD[3] - LEAD[2]) / 0.016) ** 2)
    m = smoothstep(0.17, 0.12, hole * 1.0)
    at.col[rs, cs] = at.col[rs, cs] * (1 - m[..., None]) + np.array([0.03, 0.025, 0.02]) * m[..., None]
    at.rough[rs, cs] = at.rough[rs, cs] * (1 - m) + 0.9 * m
    at.metal[rs, cs] = at.metal[rs, cs] * (1 - m)
    (rs, cs), h, w, fu, fv = paint_flat(at, BEAD, (0.14, 0.27, 0.60), 0.16, 0.0, 53, 0.15)
    white = fu >= 0.5
    at.col[rs, cs][white] = np.array([0.86, 0.85, 0.80], np.float32)
    return at


def to_image(name, arr, non_color=False):
    h, w = arr.shape[:2]
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((h, w, 1), np.float32)], axis=2).astype(np.float32)
    im = bpy.data.images.new(name, w, h, alpha=False, is_data=non_color)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    im.pixels.foreach_set(rgba.ravel())
    im.update()
    im.pack()
    return im


def make_material(at, tex_dir=None):
    col = to_image("tomahawk_atlas", at.col)
    nrm = to_image("tomahawk_normal", at.nor * 0.5 + 0.5, True)
    orm = np.stack([np.ones_like(at.rough), at.rough, at.metal], axis=2)
    orm_img = to_image("tomahawk_orm", orm, True)
    if tex_dir:
        os.makedirs(tex_dir, exist_ok=True)
        for name, arr in (("tomahawk_atlas", at.col), ("tomahawk_normal", at.nor * 0.5 + 0.5), ("tomahawk_orm", orm)):
            tmp = to_image(name + "_dump", arr, True)
            tmp.filepath_raw = os.path.join(tex_dir, name + ".png")
            tmp.file_format = "PNG"
            tmp.save()
            bpy.data.images.remove(tmp)
    m = bpy.data.materials.new("TomahawkAtlas")
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t_col = nt.nodes.new("ShaderNodeTexImage")
    t_col.image = col
    t_col.location = (-600, 300)
    nt.links.new(t_col.outputs["Color"], bsdf.inputs["Base Color"])
    t_orm = nt.nodes.new("ShaderNodeTexImage")
    t_orm.image = orm_img
    t_orm.location = (-800, 0)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    sep.location = (-450, 0)
    nt.links.new(t_orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    t_n = nt.nodes.new("ShaderNodeTexImage")
    t_n.image = nrm
    t_n.location = (-800, -300)
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nmap.location = (-450, -300)
    nt.links.new(t_n.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    m.use_backface_culling = True
    return m


# --------------------------------------------------------------------------
# Assembly
# --------------------------------------------------------------------------
MARKERS = {
    "Muzzle": EDGE_PT,
    "Blade": EDGE_PT,
    "Edge": EDGE_PT,
    "Head": Vector((0.0, HEAD_Y, 0.0)),
    "Butt": Vector((0.0, Y_BUTT, 0.0)),
}


def build_variant(pipe):
    b = Builder()
    build_haft(b)
    build_wrap(b)
    build_tacks(b)
    build_tie(b)
    build_tails(b)
    build_eye(b)
    build_blade(b)
    if pipe:
        build_pipe(b)
        build_mouthpiece(b)
    else:
        build_spike(b)
    return b


def empty(name, p, parent=None):
    o = bpy.data.objects.new(name, None)
    o.empty_display_type = "PLAIN_AXES"
    o.empty_display_size = 0.02
    o.location = G(*p)
    bpy.context.scene.collection.objects.link(o)
    if parent:
        o.parent = parent
    return o


def build_tomahawk(tex_dir=None):
    at = make_textures()
    mat = make_material(at, tex_dir)
    objs, info = [], {}
    for name, pipe in (("Tomahawk", False), ("TomahawkPipe", True)):
        b = build_variant(pipe)
        rows = mass_report(b, name)
        com, tot = com_of(rows)
        me = b.to_mesh(name + "Mesh")
        b.bm.free()
        me.materials.append(mat)
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        head = sum(r[1] for r in rows if r[0] in ("eye", "blade", "spike", "neck", "bowl"))
        info[name] = {"tris": tris, "verts": len(me.vertices), "mass": tot, "head": head, "com": com, "rows": rows}
        objs.append(o)
    com = (info["Tomahawk"]["com"] + info["TomahawkPipe"]["com"]) * 0.5
    for i in range(3):
        com[i] = round(com[i], 4)
    com.x = 0.0
    helpers = [empty(n, p) for n, p in MARKERS.items()]
    helpers.append(empty("COM", com))
    helpers.append(empty("Mouthpiece", Vector((0.0, MOUTH_TIP_Y, 0.0)), objs[1]))
    info["COM"] = com
    return objs, helpers, info


def export_glb(objs, path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=True, export_normals=True, export_tangents=True,
        export_materials="EXPORT", export_image_format="AUTO",
        export_cameras=False, export_lights=False, export_extras=False)


def read_glb_json(path):
    with open(path, "rb") as fh:
        data = fh.read()
    n = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + n]), data, n


def hide_nodes(path, names):
    """Mark glTF nodes hidden with KHR_node_visibility (Blender's exporter does not write
    it; Godot imports it as visible = false), so only the default variant shows when the
    whole GLB is instanced."""
    doc, data, n = read_glb_json(path)
    for node in doc["nodes"]:
        if node.get("name") in names:
            node.setdefault("extensions", {})["KHR_node_visibility"] = {"visible": False}
    used = doc.setdefault("extensionsUsed", [])
    if "KHR_node_visibility" not in used:
        used.append("KHR_node_visibility")
    js = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    rest = data[20 + n:]
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + len(rest)) + struct.pack("<I", len(js)) + b"JSON" + js + rest
    with open(path, "wb") as fh:
        fh.write(out)


# --------------------------------------------------------------------------
# Preview renders
# --------------------------------------------------------------------------
def setup_render(w, h):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "CYCLES"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    if sc.render.engine == "CYCLES":
        sc.cycles.samples = 64
    else:
        try:
            sc.eevee.taa_render_samples = 64
        except AttributeError:
            pass
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.film_transparent = False
    world = bpy.data.worlds.get("PreviewWorld")
    if world is None:
        world = bpy.data.worlds.new("PreviewWorld")
        try:
            world.use_nodes = True
        except Exception:
            pass
        nt = world.node_tree
        bg = nt.nodes["Background"]
        out = nt.nodes["World Output"]
        if os.path.exists(SKY):
            env = nt.nodes.new("ShaderNodeTexEnvironment")
            env.image = bpy.data.images.load(SKY, check_existing=True)
            nt.links.new(env.outputs["Color"], bg.inputs["Color"])
            bg.inputs["Strength"].default_value = 0.9
        else:
            bg.inputs["Color"].default_value = (0.55, 0.57, 0.6, 1.0)
        backdrop = nt.nodes.new("ShaderNodeBackground")
        backdrop.inputs["Color"].default_value = (0.36, 0.38, 0.40, 1.0)
        lp = nt.nodes.new("ShaderNodeLightPath")
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
        nt.links.new(bg.outputs["Background"], mix.inputs[1])
        nt.links.new(backdrop.outputs["Background"], mix.inputs[2])
        nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
        sun = bpy.data.lights.new("Sun", "SUN")
        sun.energy = 3.2
        sun.angle = math.radians(3)
        so = bpy.data.objects.new("Sun", sun)
        so.rotation_euler = (math.radians(50), math.radians(-20), math.radians(40))
        sc.collection.objects.link(so)
    sc.world = world
    return sc


def camera(name, loc, target, ortho=None, lens=60.0):
    cd = bpy.data.cameras.new(name)
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    cd.clip_start = 0.005
    cam = bpy.data.objects.new(name, cd)
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(cam)
    return cam


def shoot(path, cam, w, h):
    sc = setup_render(w, h)
    sc.camera = cam
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDERED", path)


def render_previews(out_dir, objs):
    os.makedirs(out_dir, exist_ok=True)
    spike, pipe = objs
    # Both variants side by side (seen from +X, blade to the left). Blender (x, y, z) = Godot (x, -z, y).
    pipe.location = (0.0, -0.30, 0.0)
    shoot(os.path.join(out_dir, "tomahawk_variants_side.png"),
          camera("cam_side", (1.2, -0.13, 0.185), (0.0, -0.13, 0.185), ortho=0.66), 1400, 1500)
    pipe.location = (0.0, 0.0, 0.0)
    for o, tag in ((spike, "spike"), (pipe, "pipe")):
        other = pipe if o is spike else spike
        other.hide_render = True
        shoot(os.path.join(out_dir, "tomahawk_%s_3q.png" % tag),
              camera("cam_3q_" + tag, (0.26, 0.20, 0.50), (0.0, 0.0, 0.39), lens=70), 1400, 1050)
        shoot(os.path.join(out_dir, "tomahawk_%s_3q_back.png" % tag),
              camera("cam_3qb_" + tag, (-0.24, -0.22, 0.47), (0.0, 0.0, 0.385), lens=70), 1200, 900)
        other.hide_render = False
    pipe.hide_render = True
    shoot(os.path.join(out_dir, "tomahawk_top.png"),
          camera("cam_top", (0.0, 0.0, 1.2), (0.0, 0.0, 0.4), ortho=0.30), 1200, 700)
    pipe.hide_render = False


def render_markers(out_dir, meshes, empties):
    """Side view of the re-imported model with its markers drawn as coloured balls."""
    sc = setup_render(1500, 1500)
    colors = {"Muzzle": (1, 0.1, 0.1), "Blade": (1, 0.1, 0.1), "Edge": (1, 0.1, 0.1), "COM": (0.1, 1, 0.2),
              "Head": (0.2, 0.4, 1), "Butt": (1, 0.85, 0.1), "Mouthpiece": (1, 0.3, 1)}
    for o in meshes:
        o.hide_render = o.name != "Tomahawk"
    for e in empties:
        name = e.name.split(".")[0]
        mat = bpy.data.materials.new("mk_" + name)
        mat.use_nodes = True
        em = mat.node_tree.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*colors.get(name, (1, 1, 1)), 1)
        em.inputs["Strength"].default_value = 4.0
        mat.node_tree.links.new(em.outputs["Emission"], mat.node_tree.nodes["Material Output"].inputs["Surface"])
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.006, location=e.matrix_world.translation + Vector((0.03, 0, 0)))
        s = bpy.context.active_object
        s.data.materials.append(mat)
        s.show_in_front = True
    # -Z (Godot) forward arrow from the edge: Blender +Y.
    ez = -Z_EDGE
    bpy.ops.mesh.primitive_cylinder_add(radius=0.0018, depth=0.075, location=(0, ez + 0.0425, BLADE_MID_Y),
                                        rotation=(math.radians(-90), 0, 0))
    bpy.ops.mesh.primitive_cone_add(radius1=0.0055, depth=0.016, location=(0, ez + 0.088, BLADE_MID_Y),
                                    rotation=(math.radians(-90), 0, 0))
    for label, g in (("-Z forward (throw, blade leads)", (0.03, 0.428, -0.135)),
                     ("Muzzle = Blade = Edge", (0.03, 0.362, -0.135)),
                     ("Head", (0.04, 0.397, 0.048)), ("COM", (0.04, 0.321, 0.062)),
                     ("Butt", (0.04, -0.066, 0.062)), ("Mouthpiece (pipe only)", (0.04, -0.082, 0.21)),
                     ("origin = grip", (0.04, -0.004, 0.13)),
                     ("+Y up the haft", (0.03, 0.475, 0.07))):
        cu = bpy.data.curves.new("t_" + label, "FONT")
        cu.body = label
        cu.size = 0.013
        t = bpy.data.objects.new("t_" + label, cu)
        t.location = G(*g)
        t.rotation_euler = (math.radians(90), 0, math.radians(90))
        sc.collection.objects.link(t)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.004, location=(0.03, 0, 0))
    shoot(os.path.join(out_dir, "tomahawk_reimport_markers.png"),
          camera("cam_mk", (1.2, 0.05, 0.2), (0.0, 0.05, 0.2), ortho=0.74), 1500, 1500)


# --------------------------------------------------------------------------
# Re-import verification
# --------------------------------------------------------------------------
def verify(path, info, renders=None):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = {o.name: o for o in bpy.context.scene.objects}
    fails = []

    def check(ok, msg):
        print("  %s  %s" % ("ok  " if ok else "FAIL", msg))
        if not ok:
            fails.append(msg)
    print("VERIFY", path)
    doc = read_glb_json(path)[0]
    vis = {nd.get("name"): nd.get("extensions", {}).get("KHR_node_visibility", {}).get("visible", True) for nd in doc["nodes"]}
    check(vis.get("Tomahawk") is True and vis.get("TomahawkPipe") is False,
          "glTF: Tomahawk visible, TomahawkPipe hidden (KHR_node_visibility) %s" % {k: vis.get(k) for k in ("Tomahawk", "TomahawkPipe")})
    meshes = [o for o in objs.values() if o.type == "MESH"]
    check(sorted(o.name for o in meshes) == ["Tomahawk", "TomahawkPipe"], "meshes Tomahawk + TomahawkPipe (%s)" % [o.name for o in meshes])
    expect = dict(MARKERS)
    expect["COM"] = info["COM"]
    expect["Mouthpiece"] = Vector((0.0, MOUTH_TIP_Y, 0.0))
    empties = []
    for name, p in expect.items():
        o = objs.get(name)
        check(o is not None and o.type == "EMPTY", "marker %s present" % name)
        if o is None:
            continue
        empties.append(o)
        g = B2G(o.matrix_world.translation)
        check((g - p).length < 1e-4, "  %s at Godot %s (expected %s)" % (name, tuple(round(c, 4) for c in g), tuple(round(c, 4) for c in p)))
        q = o.matrix_world.to_quaternion()
        check(abs(abs(q.w) - 1.0) < 1e-4, "  %s has identity rotation" % name)
        want_parent = "TomahawkPipe" if name == "Mouthpiece" else None
        check((o.parent.name if o.parent else None) == want_parent, "  %s parent %s" % (name, want_parent))
    for o in meshes:
        check(o.matrix_world == o.matrix_world.Identity(4), "%s has an identity transform" % o.name)
        pts = [B2G(o.matrix_world @ v.co) for v in o.data.vertices]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        size = hi - lo
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        print("  %s: Godot AABB %s .. %s, size %s, %d tris" % (o.name, tuple(round(c, 4) for c in lo), tuple(round(c, 4) for c in hi), tuple(round(c, 4) for c in size), tris))
        check(1000 <= tris <= 4000, "  %s triangle budget 1k-4k (%d)" % (o.name, tris))
        check(0.45 <= max(size) <= 0.6 and abs(size.y - max(size)) < 1e-9, "  %s longest along +Y, %.3f m (0.45-0.6)" % (o.name, max(size)))
        check(abs(lo.z - (Z_EDGE)) < 0.002, "  %s: most forward point (min z %.4f) is the cutting edge (%.4f)" % (o.name, lo.z, Z_EDGE))
        front = [p for p in pts if p.z < lo.z + 0.001]
        check(all(abs(p.x) < 0.001 and blade_bot(1) - 0.003 < p.y < blade_top(1) + 0.003 for p in front), "  %s: the front is the edge (thin, x ~ 0, blade height)" % o.name)
        check(hi.z > 0.05, "  %s: poll toward +Z (max z %.3f)" % (o.name, hi.z))
        check(abs(lo.y - (MOUTH_TIP_Y if o.name == "TomahawkPipe" else Y_BUTT)) < 0.001, "  %s: bottom at the haft end (%.4f)" % (o.name, lo.y))
        check(abs(lo.x + hi.x) < 0.005, "  %s: symmetric about x = 0" % o.name)
        mat = o.data.materials[0] if o.data.materials else None
        check(mat is not None and mat.name.startswith("TomahawkAtlas"), "  %s material %s" % (o.name, mat.name if mat else None))
        if mat:
            imgs = sorted({n.image.name for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image})
            print("    textures:", imgs)
            check(len(imgs) >= 3, "  %s: base colour, metallic-roughness and normal textures" % o.name)
            has_nmap = any(n.type == "NORMAL_MAP" for n in mat.node_tree.nodes)
            check(has_nmap, "  %s: normal map wired" % o.name)
    print("VERIFY %s (%d failures)" % ("PASSED" if not fails else "FAILED", len(fails)))
    if renders:
        render_markers(renders, meshes, empties)
    return not fails


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(PROJECT, "assets", "weapons", "tomahawk.glb"))
    ap.add_argument("--renders", default=None)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--tex-dir", default=None)
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args(argv)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    objs, helpers, info = build_tomahawk(args.tex_dir)
    for name in ("Tomahawk", "TomahawkPipe"):
        d = info[name]
        print("%s: %d tris, %d verts, %.0f g (iron head %.0f g), COM %s" % (
            name, d["tris"], d["verts"], d["mass"] * 1000, d["head"] * 1000, tuple(round(c, 4) for c in d["com"])))
        for part, m, c in d["rows"]:
            if part != "tacks":
                print("    %-6s %6.1f g at %s" % (part, m * 1000, tuple(round(v, 3) for v in c)))
    diff = (info["Tomahawk"]["com"] - info["TomahawkPipe"]["com"]).length
    print("COM marker %s (variants %.1f mm apart)" % (tuple(info["COM"]), diff * 1000))
    print("MARKERS", {k: tuple(round(c, 4) for c in v) for k, v in MARKERS.items()}, "Mouthpiece y", MOUTH_TIP_Y)
    export_glb(objs + helpers, args.out)
    hide_nodes(args.out, {"TomahawkPipe"})
    print("EXPORTED", args.out, os.path.getsize(args.out), "bytes")
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    if args.renders:
        render_previews(args.renders, objs)
    if args.verify:
        ok = verify(args.out, info, args.renders)
        if not ok:
            sys.exit(1)


if __name__ == "__main__":
    main()
