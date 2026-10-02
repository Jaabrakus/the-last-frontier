"""Procedural British Long Land Pattern ("Brown Bess") flintlock musket.

Run headless (factory scene):
  Blender -b --factory-startup --python tools/models/musket.py -- \
      [--out assets/weapons/musket.glb] [--renders DIR] [--blend FILE.blend]

Dimensions follow the 1756 Long Land Pattern: a 46 in (1.168 m) .75 calibre
smoothbore barrel, 62.5 in (1.588 m) overall, walnut full stock, brass
furniture (butt plate with comb tang, trigger guard, side plate, thumb plate,
nose cap, three ramrod pipes and a tail pipe), steel ramrod, swan-neck cock
at full cock holding a flint in a leather, frizzen and pan, iron sling
swivels on the trigger-guard bow and the middle ramrod pipe, and the bayonet
stud on top of the barrel that doubles as the foresight.

Conventions (Godot / glTF axes), matching scripts/weapons/weapon_models.gd:
  * origin = centre of the stock's wrist just behind the trigger-guard bow,
    where the right hand grips; the bore axis runs 0.035 m above it
  * forward (barrel) = -Z, up = +Y, lock on the +X (right) side
  * top-level node "Muzzle" on the bore axis at the muzzle face
  * top-level node "Pan" at the priming pan (where the pan flash goes)
  * top-level mesh nodes "Cock" (origin on the tumbler axis; the mesh is at
    full cock and roughly -40 deg about local X brings the flint onto the
    frizzen), "Frizzen" (origin on the frizzen screw) and "Ramrod" (origin
    at its head, slides out along -Z) so they can be animated later.

Blender works Z-up and the glTF exporter maps Blender (x, y, z) to glTF
(x, z, -y), so every point here is written in Godot coordinates and turned
into Blender coordinates by G().
"""

import argparse
import bisect
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

# --------------------------------------------------------------------------
# Dimensions (metres, Godot axes: +X lock side, +Y up, -Z toward the muzzle)
# --------------------------------------------------------------------------
AXIS_Y = 0.035                     # bore axis height above the grip
BARREL_LEN = 1.168                 # 46 in
OVERALL = 1.588                    # 62.5 in
Z_BREECH = -0.130                  # rear face of the barrel
Z_MUZZLE = Z_BREECH - BARREL_LEN   # -1.298
Z_HEEL = Z_MUZZLE + OVERALL        # +0.290, heel of the butt plate
Y_HEEL = -0.025
BUTT_SHEAR = 0.082                 # toe of the butt sits 1 cm ahead of the heel
Z_TIP = Z_MUZZLE + 0.100           # stock stops 4 in short of the muzzle
Z_NOSE = Z_TIP + 0.012             # brass nose cap
Z_BP = Z_HEEL - 0.006              # brass butt plate
Z_REINF = -0.360                   # end of the breech reinforce taper
RB_BREECH, RB_REINF, RB_MUZZLE = 0.0165, 0.0147, 0.0122
BORE_R = 0.0096                    # .75 calibre (0.755 in bore)
RR = 0.0045                        # steel ramrod radius
RR_Y_TAIL, RR_Y_MUZZLE = 0.0130, 0.0158
Z_RR_HEAD = Z_MUZZLE + 0.012
Z_RR_TAIL = -0.135
XP = 0.0265                        # outer face of the lock plate
XL = 0.029                         # centre plane of pan, frizzen and flint
PAN_Z = -0.1445
PAN_TOP = 0.0372
COCK_PIVOT = (-0.098, 0.016)       # (z, y) of the tumbler axis
COCK_X = 0.030
COCK_TILT = math.radians(-22.0)    # full cock: leaned back toward the butt
FRIZZEN_PIVOT = (-0.168, 0.0335)
N_RING = 24                        # stock cross-section vertices

MATS = {}


def G(p):
    """Godot-space point (x, y, z) in Blender coordinates."""
    return Vector((p[0], -p[2], p[1]))


def to_godot(b):
    return Vector((b[0], b[2], -b[1]))


def lerp(a, b, t):
    return a + (b - a) * t


def spow(t, e):
    return math.copysign(abs(t) ** e, t)


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def pchip(keys):
    """Monotone cubic through (x, y) keys (no overshoot), clamped outside."""
    xs = [k[0] for k in keys]
    ys = [k[1] for k in keys]
    n = len(xs)
    d = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(n - 1)]
    m = [0.0] * n
    m[0], m[-1] = d[0], d[-1]
    for i in range(1, n - 1):
        if d[i - 1] * d[i] <= 0.0:
            m[i] = 0.0
        else:
            h0, h1 = xs[i] - xs[i - 1], xs[i + 1] - xs[i]
            w1, w2 = 2 * h1 + h0, h1 + 2 * h0
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])

    def f(x):
        if x <= xs[0]:
            return ys[0]
        if x >= xs[-1]:
            return ys[-1]
        i = bisect.bisect_right(xs, x) - 1
        h = xs[i + 1] - xs[i]
        t = (x - xs[i]) / h
        t2, t3 = t * t, t * t * t
        return ((2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h * m[i]
                + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h * m[i + 1])
    return f


def rb(z):
    """Outer barrel radius at z."""
    if z >= Z_REINF:
        return lerp(RB_BREECH, RB_REINF, (Z_BREECH - z) / (Z_BREECH - Z_REINF))
    return lerp(RB_REINF, RB_MUZZLE, (Z_REINF - z) / (Z_REINF - Z_MUZZLE))


def y_rr(z):
    """Height of the (straight) ramrod axis at z."""
    return lerp(RR_Y_TAIL, RR_Y_MUZZLE, (-0.30 - z) / (-0.30 - Z_MUZZLE))


def rr_point(z):
    return Vector((0.0, y_rr(z), z))


RR_DIR = (rr_point(Z_RR_TAIL) - rr_point(Z_RR_HEAD)).normalized()   # head -> tail


# --------------------------------------------------------------------------
# Stock cross-sections: (z, top, bottom, half width, belly y, n_top, n_bottom)
# Each section is a superellipse split at the belly (widest line); the
# exponents make the lock panels and forend top flat and the butt oval.
# --------------------------------------------------------------------------
def forend_key(z):
    # Wood up to the barrel's mid line, ramrod half let into the underside.
    return (z, AXIS_Y - 0.0005, y_rr(z) - 0.0002, rb(z) + 0.0035, AXIS_Y - 0.0045, 4.0, 2.2)


STOCK_KEYS = [forend_key(z) for z in (Z_TIP, -1.0, -0.8, -0.6, -0.45, -0.40)] + [
    (-0.350, AXIS_Y + 0.0000, 0.0055, 0.0197, AXIS_Y - 0.0070, 4.8, 2.4),
    (-0.290, AXIS_Y + 0.0010, -0.0050, 0.0220, AXIS_Y - 0.0110, 5.8, 2.8),
    (-0.240, AXIS_Y + 0.0017, -0.0150, 0.0240, AXIS_Y - 0.0150, 7.0, 3.2),
    (-0.205, AXIS_Y + 0.0020, -0.0210, 0.0250, AXIS_Y - 0.0170, 8.0, 3.5),
    (-0.150, AXIS_Y + 0.0020, -0.0245, 0.0252, AXIS_Y - 0.0175, 8.0, 3.5),
    (-0.137, AXIS_Y + 0.0020, -0.0250, 0.0252, AXIS_Y - 0.0175, 8.0, 3.5),
    # Behind the breech the wood rises over the breech plug and tang.
    (-0.127, 0.0475, -0.0255, 0.0252, 0.0175, 3.2, 3.5),
    (-0.100, 0.0455, -0.0265, 0.0250, 0.0165, 3.0, 3.5),
    (-0.060, 0.0395, -0.0275, 0.0248, 0.0140, 3.0, 3.4),
    (-0.030, 0.0325, -0.0278, 0.0243, 0.0100, 2.8, 3.1),
    # Wrist (the grip, origin) then the butt: comb drop ~1.9 in, heel ~3 in.
    (0.000, 0.0262, -0.0265, 0.0200, 0.0010, 2.5, 2.5),
    (0.030, 0.0200, -0.0300, 0.0190, -0.0040, 2.4, 2.4),
    (0.070, 0.0092, -0.0455, 0.0200, -0.0150, 2.5, 2.6),
    (0.120, 0.0012, -0.0690, 0.0215, -0.0290, 2.6, 2.8),
    (0.200, -0.0110, -0.1070, 0.0232, -0.0520, 2.7, 3.0),
    (Z_HEEL, Y_HEEL, -0.1470, 0.0240, -0.0780, 2.8, 3.0),
]
_SEC = [pchip([(k[0], k[i]) for k in STOCK_KEYS]) for i in range(1, 7)]


def section(z):
    return tuple(f(z) for f in _SEC)


def shear(z):
    return BUTT_SHEAR * smoothstep(0.215, 0.27, z)


def ring2d(z, inflate=0.0):
    top, bot, hw, belly, nt, nb = section(z)
    ht, hb = top - belly, belly - bot
    pts = []
    for k in range(N_RING):
        th = math.pi + 2.0 * math.pi * k / N_RING       # k = 0 at the bottom
        sn, cs = math.sin(th), math.cos(th)
        n, h = (nt, ht) if cs >= 0.0 else (nb, hb)
        pts.append((hw * spow(sn, 2.0 / n), belly + h * spow(cs, 2.0 / n)))
    if inflate:
        out = []
        for k in range(N_RING):
            a, b = pts[k - 1], pts[(k + 1) % N_RING]
            tx, ty = b[0] - a[0], b[1] - a[1]
            ln = math.hypot(tx, ty)
            nx, ny = ty / ln, -tx / ln
            if nx * pts[k][0] + ny * (pts[k][1] - belly) < 0.0:
                nx, ny = -nx, -ny
            out.append((pts[k][0] + nx * inflate, pts[k][1] + ny * inflate))
        pts = out
    return pts


def surf_top(z, x):
    top, bot, hw, belly, nt, nb = section(z)
    t = min(abs(x) / hw, 0.98)
    return Vector((x, belly + (top - belly) * (1.0 - t ** nt) ** (1.0 / nt), z)), Vector((0, 1, 0))


def surf_bot(z, x):
    top, bot, hw, belly, nt, nb = section(z)
    t = min(abs(x) / hw, 0.98)
    return Vector((x, belly - (belly - bot) * (1.0 - t ** nb) ** (1.0 / nb), z)), Vector((0, -1, 0))


# --------------------------------------------------------------------------
# Mesh building helpers (all input in Godot coordinates)
# --------------------------------------------------------------------------
class Part:
    def __init__(self, name, mats):
        self.name = name
        self.mats = list(mats)
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def v(self, p):
        return self.bm.verts.new(G(p))

    def face(self, verts, mi=0, uvs=None):
        f = self.bm.faces.new(verts)
        f.material_index = mi
        f.smooth = True
        if uvs is not None:
            for loop, t in zip(f.loops, uvs):
                loop[self.uv].uv = t
        return f

    def build(self, bevel=0.0, segments=1, sharp=40.0):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(MATS[m])
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        me.shade_smooth()
        if bevel > 0.0:
            # Small rounded edges; harden normals keep the flat faces flat.
            mod = obj.modifiers.new("Bevel", "BEVEL")
            mod.width = bevel
            mod.segments = segments
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(30.0)
            mod.harden_normals = True
            mod.use_clamp_overlap = True
            with bpy.context.temp_override(object=obj, active_object=obj,
                                           selected_objects=[obj], selected_editable_objects=[obj]):
                bpy.ops.object.modifier_apply(modifier=mod.name)
        else:
            me.set_sharp_from_angle(angle=math.radians(sharp))
        print("PART %-14s tris=%d" % (self.name, sum(len(f.vertices) - 2 for f in me.polygons)))
        return obj


def prism(part, outline, x0, x1, mi=0):
    """Extrude a (z, y) outline between x0 and x1."""
    a = [part.v((x0, y, z)) for z, y in outline]
    b = [part.v((x1, y, z)) for z, y in outline]
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        part.face([a[i], a[j], b[j], b[i]], mi)
    part.face(a, mi)
    part.face(b[::-1], mi)


def box(part, c, s, mi=0):
    hx, hy, hz = s[0] * 0.5, s[1] * 0.5, s[2] * 0.5
    prism(part, [(c[2] - hz, c[1] - hy), (c[2] + hz, c[1] - hy), (c[2] + hz, c[1] + hy),
                 (c[2] - hz, c[1] + hy)], c[0] - hx, c[0] + hx, mi)


def sweep_outline(path, widths):
    """Outline of a band of varying width along a (z, y) path."""
    left, right = [], []
    n = len(path)
    for i in range(n):
        p0, p1 = path[max(i - 1, 0)], path[min(i + 1, n - 1)]
        tz, ty = p1[0] - p0[0], p1[1] - p0[1]
        ln = math.hypot(tz, ty)
        nz, ny = -ty / ln, tz / ln
        h = widths[i] * 0.5
        left.append((path[i][0] + nz * h, path[i][1] + ny * h))
        right.append((path[i][0] - nz * h, path[i][1] - ny * h))
    return left + right[::-1]


def circle_outline(cz, cy, r, n=16):
    return [(cz + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def lathe(part, origin, axis, profile, sides, mats=0, e1=(1, 0, 0), phase=0.0, closed=False):
    """Surface of revolution; profile = [(t along axis, radius)], r=0 is a pole."""
    axis = Vector(axis).normalized()
    origin = Vector(origin)
    e1 = Vector(e1)
    e1 = (e1 - axis * e1.dot(axis))
    if e1.length < 1e-6:
        e1 = Vector((0, 1, 0)) - axis * axis.y
    e1.normalize()
    e2 = axis.cross(e1)
    rings = []
    for t, r in profile:
        c = origin + axis * t
        if r <= 1e-9:
            rings.append([part.v(c)])
        else:
            rings.append([part.v(c + (e1 * math.cos(phase + 2 * math.pi * j / sides)
                                      + e2 * math.sin(phase + 2 * math.pi * j / sides)) * r)
                          for j in range(sides)])
    nseg = len(rings) if closed else len(rings) - 1

    def mat(i):
        return mats[min(i, len(mats) - 1)] if isinstance(mats, (list, tuple)) else mats
    for i in range(nseg):
        A, B = rings[i], rings[(i + 1) % len(rings)]
        mi = mat(i)
        if len(A) == 1 and len(B) == 1:
            continue
        for j in range(sides):
            k = (j + 1) % sides
            if len(A) == 1:
                part.face([A[0], B[j], B[k]], mi)
            elif len(B) == 1:
                part.face([A[j], A[k], B[0]], mi)
            else:
                part.face([A[j], A[k], B[k], B[j]], mi)
    if not closed:
        if len(rings[0]) > 1:
            part.face(rings[0], mat(0))
        if len(rings[-1]) > 1:
            part.face(rings[-1][::-1], mat(nseg - 1))


def strip(part, zs, wfun, surf, thick, inset=0.0006, lat=(-1.0, 0.0, 1.0), mi=0):
    """Thin plate lying on the stock surface (tangs, straps, thumb plate)."""
    top, bot = [], []
    for z in zs:
        w = max(wfun(z), 0.0008)
        tr, br = [], []
        for f in lat:
            p, n = surf(z, f * w * 0.5)
            tr.append(part.v(p + n * thick))
            br.append(part.v(p - n * inset))
        top.append(tr)
        bot.append(br)
    m = len(lat)
    for i in range(len(zs) - 1):
        for j in range(m - 1):
            part.face([top[i][j], top[i][j + 1], top[i + 1][j + 1], top[i + 1][j]], mi)
            part.face([bot[i][j], bot[i + 1][j], bot[i + 1][j + 1], bot[i][j + 1]], mi)
        for j in (0, m - 1):
            part.face([top[i][j], top[i + 1][j], bot[i + 1][j], bot[i][j]], mi)
    for i in (0, len(zs) - 1):
        part.face(top[i] + bot[i][::-1], mi)


def sweep3d(part, pts, profile, bnorm, closed=False, mi=0):
    """Sweep a 2D profile (a along the in-plane normal, b along bnorm) along a planar path."""
    B = Vector(bnorm).normalized()
    n = len(pts)
    rings = []
    for i in range(n):
        if closed:
            p0, p1 = pts[(i - 1) % n], pts[(i + 1) % n]
        else:
            p0, p1 = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        T = (p1 - p0).normalized()
        N = B.cross(T).normalized()
        rings.append([part.v(pts[i] + N * a + B * b) for a, b in profile])
    m = len(profile)
    for i in range(n if closed else n - 1):
        A, C = rings[i], rings[(i + 1) % n]
        for j in range(m):
            k = (j + 1) % m
            part.face([A[j], A[k], C[k], C[j]], mi)
    if not closed:
        part.face(rings[0], mi)
        part.face(rings[-1][::-1], mi)


def rounded_rect_path(cx, cy, z, w, h, rc, nc=4):
    """Closed rounded rectangle in the x-y plane at depth z."""
    pts = []
    corners = [(cx + w / 2 - rc, cy + h / 2 - rc, 0.0), (cx - w / 2 + rc, cy + h / 2 - rc, 0.5 * math.pi),
               (cx - w / 2 + rc, cy - h / 2 + rc, math.pi), (cx + w / 2 - rc, cy - h / 2 + rc, 1.5 * math.pi)]
    for ccx, ccy, a0 in corners:
        for i in range(nc + 1):
            a = a0 + 0.5 * math.pi * i / nc
            pts.append(Vector((ccx + rc * math.cos(a), ccy + rc * math.sin(a), z)))
    return pts


def convex_hull(pts):
    """2D convex hull (monotone chain), counter-clockwise."""
    pts = sorted(set(pts))

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p_ in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p_) <= 0:
            lower.pop()
        lower.append(p_)
    for p_ in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p_) <= 0:
            upper.pop()
        upper.append(p_)
    return lower[:-1] + upper[:-1]


def catmull(pts, sub):
    """Catmull-Rom through 2D points, `sub` samples per span, endpoints kept."""
    out = []
    n = len(pts)
    for i in range(n - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, n - 1)]
        for k in range(sub):
            t = k / sub
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2
                                    + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3) for c in range(2)))
    out.append(pts[-1])
    return out


def hexagon(r, n=6):
    return [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n)) for i in range(n)]


# --------------------------------------------------------------------------
# Parts
# --------------------------------------------------------------------------
WOOD_RINGS = [-0.80, -0.45, -0.40, -0.375, -0.35, -0.32, -0.29,
              -0.265, -0.24, -0.22, -0.205, -0.18, -0.15, -0.137, -0.133, -0.130, -0.127,
              -0.115, -0.10, -0.08, -0.06, -0.045, -0.03, -0.015, 0.0, 0.015, 0.03, 0.05,
              0.07, 0.095, 0.12, 0.16, 0.20, 0.24, 0.265]


def build_stock():
    """Walnut full stock lofted from cross-sections, with the brass nose cap
    and butt plate as the first and last rings."""
    p = Part("Stock", ["Walnut", "Brass"])
    WOOD, BR = 0, 1
    spec = ([(Z_TIP, BR, 0.0006), (Z_NOSE, BR, 0.0006), (Z_NOSE, WOOD, 0.0)]
            + [(z, WOOD, 0.0) for z in WOOD_RINGS]
            + [(Z_BP, WOOD, 0.0), (Z_BP, BR, 0.0006), (Z_HEEL, BR, 0.0006)])
    rings = []
    for z, mat, inf in spec:
        sh = shear(z)
        rings.append((z, mat, [p.v((x, y, z + sh * (y - Y_HEEL))) for x, y in ring2d(z, inf)]))
    length = Z_HEEL - Z_TIP
    for i in range(len(rings) - 1):
        z0, m0, A = rings[i]
        z1, m1, B = rings[i + 1]
        mi = BR if BR in (m0, m1) else WOOD
        u0, u1 = (Z_HEEL - z0) / length, (Z_HEEL - z1) / length
        for k in range(N_RING):
            k1 = (k + 1) % N_RING
            v0, v1 = k / N_RING, (k + 1) / N_RING
            p.face([A[k], A[k1], B[k1], B[k]], mi, [(u0, v0), (u0, v1), (u1, v1), (u1, v0)])
    p.face(rings[0][2], BR)
    p.face(rings[-1][2][::-1], BR)
    return p


def build_barrel():
    """Round tapered barrel with a breech reinforce, crowned muzzle and a
    dark .75 bore."""
    p = Part("Barrel", ["Iron", "Dark"])
    L = BARREL_LEN
    prof = [(0.0, 0.0), (0.0, RB_BREECH - 0.001), (0.001, RB_BREECH),
            (Z_BREECH - Z_REINF, RB_REINF), (0.70, rb(Z_BREECH - 0.70)),
            (L - 0.0015, RB_MUZZLE), (L, RB_MUZZLE - 0.0012), (L, BORE_R + 0.0008),
            (L - 0.0008, BORE_R), (L - 0.06, BORE_R), (L - 0.06, 0.0)]
    lathe(p, (0, AXIS_Y, Z_BREECH), (0, 0, -1), prof, 24, mats=[0] * 8 + [1, 1], e1=(0, 1, 0))
    return p


def build_barrel_fittings():
    """Breech tang on the wrist and the bayonet stud / foresight."""
    p = Part("BarrelFittings", ["Iron"])
    wf = pchip([(-0.1275, 0.0170), (-0.100, 0.0150), (-0.070, 0.0122), (-0.052, 0.0100),
                (-0.043, 0.0075), (-0.0385, 0.0040), (-0.0370, 0.0010)])
    zs = [-0.1275, -0.115, -0.100, -0.085, -0.070, -0.058, -0.049, -0.043, -0.0395, -0.0375, -0.0370]
    strip(p, zs, wf, surf_top, 0.0017)
    # Bayonet stud on top of the barrel 1.4 in from the muzzle; it is also the foresight.
    zc = Z_MUZZLE + 0.036
    yb, yt = AXIS_Y + rb(zc) - 0.0015, AXIS_Y + rb(zc) + 0.0055
    prism(p, [(zc - 0.005, yb), (zc + 0.005, yb), (zc + 0.005, yt - 0.0012), (zc + 0.0035, yt),
              (zc - 0.0035, yt), (zc - 0.005, yt - 0.0012)], -0.00225, 0.00225)
    return p


def dome_screw(part, origin, axis, r, h=0.0016, sides=8):
    lathe(part, origin, axis, [(0.0, r), (h * 0.4, r), (h * 0.85, r * 0.72), (h, 0.0)], sides)


def build_screws():
    p = Part("Screws", ["Iron"])
    dome_screw(p, surf_top(-0.083, 0.0)[0] + Vector((0, 0.0016, 0)), (0, 1, 0), 0.0036)   # tang screw
    for z, y in ((-0.168, 0.0180), (-0.080, 0.0105)):                                      # lock bolts
        dome_screw(p, (-0.0262, y, z), (-1, 0, 0), 0.0045, 0.0018, 10)
    dome_screw(p, (0.0393, FRIZZEN_PIVOT[1], FRIZZEN_PIVOT[0]), (1, 0, 0), 0.0033, 0.0014)  # frizzen screw
    dome_screw(p, (0.0298, 0.0105, -0.1625), (1, 0, 0), 0.0030, 0.0013)                    # spring screw
    return p


def build_pipes():
    """Brass ramrod pipes: trumpet upper pipe, two plain pipes and the tail pipe."""
    p = Part("Pipes", ["Brass"])
    ri, ro = RR + 0.0006, RR + 0.0022
    Lp = 0.040
    lathe(p, rr_point(-1.160), RR_DIR,
          [(0, ri + 0.0012), (0, ro + 0.0028), (0.004, ro + 0.0014), (0.012, ro + 0.0004),
           (Lp - 0.004, ro), (Lp - 0.0025, ro + 0.0008), (Lp, ro + 0.0008), (Lp, ri)], 10, closed=True)
    Lp = 0.035
    for z0 in (-0.930, -0.700):
        lathe(p, rr_point(z0), RR_DIR,
              [(0, ri), (0, ro + 0.0008), (0.0025, ro + 0.0008), (0.0035, ro), (Lp - 0.0035, ro),
               (Lp - 0.0025, ro + 0.0008), (Lp, ro + 0.0008), (Lp, ri)], 10, closed=True)
    Lp = 0.060
    lathe(p, rr_point(-0.405), RR_DIR,
          [(0, ri), (0, ro + 0.0010), (0.003, ro + 0.0010), (0.0045, ro + 0.0002), (0.040, ro + 0.0002),
           (0.050, ro + 0.0008), (0.056, ro + 0.0012), (Lp, ro + 0.0004), (Lp, ri)], 10, closed=True)
    return p


def build_furniture():
    """Brass trigger guard (strap, bow, swivel lugs), tail-pipe finial,
    butt-plate tang and thumb plate. Returns (straps, bow) parts and the
    swivel attachment points."""
    p = Part("Straps", ["Brass"])
    bow = Part("GuardBow", ["Brass"])
    flat = (-1.0, 1.0)
    # Trigger guard strap with an acorn finial in front and a tapered tail.
    wf = pchip([(-0.2680, 0.0010), (-0.2655, 0.0080), (-0.2600, 0.0130), (-0.2520, 0.0150),
                (-0.2440, 0.0135), (-0.2350, 0.0095), (-0.2270, 0.0065), (-0.2180, 0.0075),
                (-0.1900, 0.0098), (-0.1400, 0.0118), (-0.0950, 0.0135), (-0.0170, 0.0135),
                (0.0100, 0.0118), (0.0400, 0.0090), (0.0650, 0.0068), (0.0740, 0.0052),
                (0.0785, 0.0030), (0.0800, 0.0010)])
    zs = [-0.268, -0.2665, -0.2645, -0.262, -0.258, -0.253, -0.248, -0.243, -0.238, -0.233,
          -0.228, -0.223, -0.215, -0.20, -0.18, -0.155, -0.13, -0.11, -0.095, -0.075, -0.056,
          -0.037, -0.017, 0.0, 0.015, 0.03, 0.045, 0.058, 0.068, 0.074, 0.077, 0.079, 0.080]
    strip(p, zs, wf, surf_bot, 0.0025, lat=flat)
    # Bow: a generous half-oval around the trigger, rounded-rectangle section.
    zc, a, b = -0.0555, 0.0375, 0.029
    y0 = surf_bot(zc, 0.0)[0].y - 0.0015
    pts = [Vector((0.0, y0 + b * math.sin(t), zc + a * math.cos(t)))
           for t in (math.pi + math.pi * i / 18 for i in range(19))]
    sweep3d(bow, pts, [(0.0019, -0.0036), (0.0019, 0.0036), (0.0009, 0.0048), (-0.0009, 0.0048),
                       (-0.0019, 0.0036), (-0.0019, -0.0036), (-0.0009, -0.0048), (0.0009, -0.0048)], (1, 0, 0))
    # Rear sling swivel lug on the front of the bow.
    tl = math.pi + 0.55
    zl, yl = zc + a * math.cos(tl), y0 + b * math.sin(tl)
    box(bow, (0.0, yl - 0.0020, zl - 0.0035), (0.0042, 0.0055, 0.0075))
    # Front swivel lug under the middle pipe.
    zf = -0.9125
    ypipe = y_rr(zf) - (RR + 0.0022)
    box(bow, (0.0, ypipe - 0.0020, zf), (0.0042, 0.0060, 0.0085))
    # Tail pipe finial on the stock underside.
    wf = pchip([(-0.347, 0.0100), (-0.325, 0.0085), (-0.310, 0.0062), (-0.303, 0.0035), (-0.300, 0.0010)])
    strip(p, [-0.347, -0.335, -0.320, -0.310, -0.304, -0.300], wf, surf_bot, 0.0015, lat=flat)
    # Butt plate tang running up over the comb.
    wf = pchip([(0.182, 0.0010), (0.1845, 0.0075), (0.190, 0.0115), (0.200, 0.0128), (0.230, 0.0140),
                (Z_BP + 0.001, 0.0165)])
    strip(p, [0.182, 0.1835, 0.186, 0.190, 0.197, 0.210, 0.235, 0.260, Z_BP + 0.001],
          wf, surf_top, 0.0016)
    # Oval thumb plate (wrist escutcheon).
    def wthumb(z):
        t = (z - 0.036) / 0.0155
        return 0.019 * math.sqrt(max(0.0, 1.0 - t * t))
    strip(p, [0.0206, 0.0222, 0.026, 0.031, 0.036, 0.041, 0.046, 0.0498, 0.0514],
          wthumb, surf_top, 0.0012)
    return p, bow, (zl - 0.0055, yl - 0.0037), (zf, ypipe - 0.0044)


def build_side_plate():
    """Brass side plate opposite the lock, carrying the two lock bolts."""
    p = Part("SidePlate", ["Brass"])
    path = [(-0.192, 0.0205), (-0.180, 0.0195), (-0.168, 0.0180), (-0.150, 0.0155), (-0.125, 0.0130),
            (-0.100, 0.0115), (-0.080, 0.0105), (-0.060, 0.0092), (-0.045, 0.0078), (-0.034, 0.0062)]
    widths = [0.0030, 0.0090, 0.0135, 0.0090, 0.0068, 0.0075, 0.0125, 0.0080, 0.0045, 0.0015]
    prism(p, sweep_outline(path, widths), -0.0265, -0.0225)
    return p


def build_trigger():
    p = Part("Trigger", ["Iron"])
    path = [(-0.0575, -0.0200), (-0.0582, -0.0300), (-0.0580, -0.0380), (-0.0562, -0.0450),
            (-0.0530, -0.0495), (-0.0495, -0.0515)]
    prism(p, sweep_outline(path, [0.0058, 0.0056, 0.0052, 0.0047, 0.0042, 0.0036]), -0.0025, 0.0025)
    return p


def build_swivels(rear, front):
    """Iron sling swivels hanging across the stock (the sling runs along Z through them)."""
    p = Part("Swivels", ["Iron"])
    for z, ytop in (rear, front):
        w, h = 0.028, 0.0135
        path = rounded_rect_path(0.0, ytop - h / 2, z, w, h, 0.0042, nc=3)
        sweep3d(p, path, hexagon(0.0016, 5), (0, 0, 1), closed=True)
    return p


LOCK_PLATE = [(-0.2005, 0.0195), (-0.1985, 0.0265), (-0.1945, 0.0315), (-0.1860, 0.0340),
              (-0.1600, 0.0345), (-0.1250, 0.0345), (-0.1050, 0.0335), (-0.0850, 0.0310),
              (-0.0650, 0.0265), (-0.0500, 0.0220), (-0.0400, 0.0180), (-0.0330, 0.0140),
              (-0.0290, 0.0105), (-0.0285, 0.0080), (-0.0310, 0.0055), (-0.0400, 0.0030),
              (-0.0600, 0.0012), (-0.0850, 0.0006), (-0.1100, 0.0010), (-0.1400, 0.0025),
              (-0.1700, 0.0050), (-0.1880, 0.0080), (-0.1965, 0.0125)]


def build_lock_plate():
    p = Part("LockPlate", ["Iron"])
    prism(p, LOCK_PLATE, 0.0225, XP)
    return p


def build_lock_parts():
    """Pan with its fence and bridle, and the frizzen spring."""
    p = Part("LockParts", ["Iron"])
    pan = [(-0.1575, PAN_TOP), (-0.1565, 0.0335), (-0.1535, 0.0307), (-0.1490, 0.0292),
           (-0.1445, 0.0288), (-0.1400, 0.0292), (-0.1355, 0.0307), (-0.1325, 0.0335), (-0.1315, PAN_TOP)]
    prism(p, pan[::-1], 0.0185, 0.0395)
    box(p, (0.0288, 0.0374, -0.1298), (0.0185, 0.0088, 0.0026))           # fence behind the pan
    box(p, (0.0283, 0.0320, -0.1665), (0.0040, 0.0080, 0.0130))           # bridle for the frizzen pivot
    path = [(-0.1600, 0.0105), (-0.1720, 0.0118), (-0.1850, 0.0135), (-0.1935, 0.0152),
            (-0.1975, 0.0178), (-0.1945, 0.0208), (-0.1860, 0.0232), (-0.1760, 0.0252)]
    prism(p, sweep_outline(path, [0.0042, 0.0040, 0.0035, 0.0032, 0.0030, 0.0030, 0.0028, 0.0025]),
          XP - 0.0005, XP + 0.0035)
    return p


def cock_xf(dz, dy):
    """Cock design coordinates (relative to the tumbler axis, upright) -> world (z, y) at full cock."""
    c, s = math.cos(COCK_TILT), math.sin(COCK_TILT)
    return (COCK_PIVOT[0] + dz * c - dy * s, COCK_PIVOT[1] + dz * s + dy * c)


def build_cock():
    """Swan-neck cock at full cock with the flint in a leather between the jaws."""
    iron = Part("CockIron", ["Iron"])
    # Body round the tumbler with the "breast" lobe below and in front of it.
    body = convex_hull(circle_outline(0.0, 0.0, 0.0105, 16) + circle_outline(-0.0115, -0.0050, 0.0042, 8))
    prism(iron, [cock_xf(z, y) for z, y in body], 0.0268, 0.0332)
    # The swan neck: an S that bows toward the pan and comes back under the jaws.
    neck = catmull([(0.0015, 0.0050), (-0.0035, 0.0170), (-0.0088, 0.0280), (-0.0072, 0.0375),
                    (-0.0005, 0.0448), (0.0058, 0.0500)], 3)
    widths = [lerp(0.0112, 0.0078, min(1.0, i / 6.0)) if i < 6 else
              lerp(0.0074, 0.0088, (i - 6) / (len(neck) - 7)) for i in range(len(neck))]
    prism(iron, [cock_xf(z, y) for z, y in sweep_outline(neck, widths)], 0.0270, 0.0330)
    # Lower jaw with the comb that guides the top jaw behind the jaw screw.
    lower = [(-0.0175, 0.0495), (0.0120, 0.0495), (0.0170, 0.0515), (0.0174, 0.0655), (0.0152, 0.0668),
             (0.0131, 0.0655), (0.0126, 0.0550), (-0.0175, 0.0550), (-0.0190, 0.0525)]
    upper = [(-0.0160, 0.0630), (0.0120, 0.0630), (0.0140, 0.0645), (0.0140, 0.0660), (0.0120, 0.0675),
             (-0.0150, 0.0675), (-0.0168, 0.0655)]
    for jaw in (lower, upper):
        prism(iron, [cock_xf(z, y) for z, y in jaw], 0.0215, 0.0365)

    flint = Part("CockFlint", ["Flint"])
    fl = [(0.0030, 0.0551), (0.0030, 0.0629), (-0.0100, 0.0625), (-0.0240, 0.0596), (-0.0258, 0.0588),
          (-0.0240, 0.0580), (-0.0100, 0.0556)]
    prism(flint, [cock_xf(z, y) for z, y in fl], 0.0185, 0.0395)

    leather = Part("CockLeather", ["Dark"])
    lt = [(-0.0115, 0.0547), (0.0060, 0.0547), (0.0060, 0.0633), (-0.0115, 0.0633)]
    prism(leather, [cock_xf(z, y) for z, y in lt], 0.0192, 0.0388)

    screws = Part("CockScrews", ["Iron"])
    # Jaw screw along the cock's own "up": design (dz, dy) = (0, 1) after the tilt.
    c, s = math.cos(COCK_TILT), math.sin(COCK_TILT)
    up = (0.0, c, -s)
    zb, yb = cock_xf(0.0085, 0.0480)
    lathe(screws, (XL, yb, zb), up,
          [(0, 0), (0, 0.0026), (0.0195, 0.0026), (0.0195, 0.0048), (0.0225, 0.0048), (0.0240, 0.0036),
           (0.0247, 0.0)], 10)
    dome_screw(screws, (0.0330, COCK_PIVOT[1], COCK_PIVOT[0]), (1, 0, 0), 0.0050, 0.0018, 10)

    objs = [iron.build(bevel=0.0005), flint.build(bevel=0.0004),
            leather.build(bevel=0.0004), screws.build(sharp=50.0)]
    return objs


def build_frizzen():
    p = Part("Frizzen", ["Iron"])
    cover = [(-0.1712, 0.0360), (-0.1690, 0.0395), (-0.1650, 0.0406), (-0.1320, 0.0406), (-0.1312, 0.0395),
             (-0.1312, 0.0373), (-0.1650, 0.0373), (-0.1700, 0.0350)]
    prism(p, cover, 0.0190, 0.0390)
    face = [(-0.1340, 0.0380), (-0.1352, 0.0480), (-0.1368, 0.0580), (-0.1388, 0.0680),
            (-0.1418, 0.0760), (-0.1460, 0.0815)]
    prism(p, sweep_outline(face, [0.0066, 0.0062, 0.0057, 0.0052, 0.0047, 0.0042]), 0.0190, 0.0390)
    prism(p, circle_outline(FRIZZEN_PIVOT[0], FRIZZEN_PIVOT[1], 0.0046, 14), 0.0300, 0.0393)
    toe = [(-0.1700, 0.0300), (-0.1745, 0.0262), (-0.1790, 0.0255), (-0.1790, 0.0240), (-0.1740, 0.0243),
           (-0.1680, 0.0285)]
    prism(p, toe, 0.0265, 0.0325)
    return p


def build_ramrod():
    p = Part("Ramrod", ["Iron"])
    length = (rr_point(Z_RR_TAIL) - rr_point(Z_RR_HEAD)).length
    prof = [(0.0, 0.0), (0.0, 0.0046), (0.0008, 0.0054), (0.014, 0.0056), (0.020, 0.0047), (0.024, RR),
            (0.60, 0.0043), (length - 0.003, 0.0038), (length, 0.0030), (length, 0.0)]
    lathe(p, rr_point(Z_RR_HEAD), RR_DIR, prof, 10)
    return p


# --------------------------------------------------------------------------
# Materials and the walnut texture
# --------------------------------------------------------------------------
def make_walnut(W=1024, H=256, seed=1756):
    """Walnut grain running along U (the length of the stock), tiling in V."""
    u = (np.arange(W) + 0.5) / W
    v = (np.arange(H) + 0.5) / H
    U, V = np.meshgrid(u, v)

    def vnoise(cu, cv, s):
        g = np.random.default_rng(s).random((cv, cu))
        x, y = U * cu, V * cv
        x0, y0 = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64)
        fx, fy = x - x0, y - y0
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        x0, y0 = x0 % cu, y0 % cv
        x1, y1 = (x0 + 1) % cu, (y0 + 1) % cv
        a, b = g[y0, x0], g[y0, x1]
        c, d = g[y1, x0], g[y1, x1]
        return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy

    def fbm(cu, cv, s, octaves=4):
        tot, amp, norm = 0.0, 1.0, 0.0
        for o in range(octaves):
            tot = tot + amp * vnoise(cu * 2 ** o, cv * 2 ** o, s + o)
            norm += amp
            amp *= 0.5
        return tot / norm

    def sstep(a, b, x):
        t = np.clip((x - a) / (b - a), 0.0, 1.0)
        return t * t * (3 - 2 * t)

    # Growth bands: few, soft and wandering, so the figure is not pinstriped.
    warp = fbm(4, 3, seed, 4) - 0.5
    warp2 = fbm(14, 7, seed + 5, 3) - 0.5
    phase = V * 12.0 + warp * 4.5 + warp2 * 0.9
    rings = 0.5 + 0.5 * np.sin(2 * np.pi * phase)
    late = sstep(0.62, 1.0, rings)
    streak = fbm(8, 64, seed + 20, 4)                     # fine streaks along the grain
    mineral = sstep(0.66, 0.86, fbm(3, 18, seed + 50, 3))  # occasional dark walnut streaks
    pores = sstep(0.88, 0.97, vnoise(420, 220, seed + 30))
    tone = fbm(3, 2, seed + 40, 3)
    light = np.array([0.44, 0.270, 0.150])
    mid = np.array([0.330, 0.190, 0.098])
    dark = np.array([0.170, 0.092, 0.046])
    t = np.clip(0.6 * (streak - 0.5) + 1.0 * (tone - 0.5) + 0.5, 0.0, 1.0)[..., None]
    col = mid + (light - mid) * t
    col = col + (dark - col) * (0.30 * late[..., None] + 0.35 * mineral[..., None])
    col = col * (1.0 - 0.14 * pores[..., None])
    col = np.clip(col, 0.0, 1.0)
    rgba = np.concatenate([col, np.ones((H, W, 1))], axis=2).astype(np.float32)
    img = bpy.data.images.new("musket_walnut", W, H, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.update()
    return img


def principled(name, color=None, metallic=0.0, roughness=0.5, image=None):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if color:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    if image:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.location = (-400, 200)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def make_materials(texture_png=None):
    img = make_walnut()
    if texture_png:
        os.makedirs(os.path.dirname(texture_png), exist_ok=True)
        img.filepath_raw = texture_png
        img.file_format = "PNG"
        img.save()
        img.source = "FILE"
        img.reload()
    img.pack()
    MATS["Walnut"] = principled("Walnut", roughness=0.45, image=img)
    # Bright (polished) iron, as issued in the 18th century.
    MATS["Iron"] = principled("Iron", color=(0.42, 0.42, 0.43), metallic=1.0, roughness=0.40)
    MATS["Brass"] = principled("Brass", color=(0.78, 0.56, 0.24), metallic=1.0, roughness=0.30)
    MATS["Flint"] = principled("Flint", color=(0.045, 0.040, 0.036), roughness=0.22)
    MATS["Dark"] = principled("Dark", color=(0.030, 0.020, 0.012), roughness=0.85)


# --------------------------------------------------------------------------
# Assembly / export
# --------------------------------------------------------------------------
def join(objs, name, origin=None):
    target = objs[0]
    if len(objs) > 1:
        with bpy.context.temp_override(active_object=target, object=target,
                                       selected_objects=objs, selected_editable_objects=objs):
            bpy.ops.object.join()
    target.name = name
    target.data.name = name
    if origin is not None:
        o = G(origin)
        target.data.transform(Matrix.Translation(-o))
        target.location = o
    return target


def add_empty(name, p):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.05
    e.location = G(p)
    bpy.context.scene.collection.objects.link(e)
    return e


VARIANT = ""


def _guard(o):
    """The trade gun's big trigger-guard bow (room for a mittened finger): grown 1.35x about the trigger."""
    if VARIANT == "trade":
        c = G((0.0, -0.035, -0.0555))
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            v.co = o.matrix_world.inverted() @ (c + (w - c) * 1.35)
    return o


def build_musket(texture_png=None):
    make_materials(texture_png)
    straps, bow, rear_swivel, front_swivel = build_furniture()
    body = [
        build_stock().build(sharp=50.0),
        build_barrel().build(sharp=35.0),
        build_barrel_fittings().build(sharp=30.0),
        build_screws().build(sharp=50.0),
        build_pipes().build(sharp=45.0),
        straps.build(sharp=30.0),
        _guard(bow.build(sharp=50.0)),
        build_side_plate().build(bevel=0.0006),
        build_trigger().build(bevel=0.0006),
        build_swivels(rear_swivel, front_swivel).build(sharp=80.0),
    ]
    if VARIANT != "hall":      # (the Hall's lock is on its breech block: no side lock)
        body += [build_lock_plate().build(bevel=0.0007, segments=2), build_lock_parts().build(bevel=0.0005)]
    musket = join(body, "Musket")
    cock = join(build_cock(), "Cock", (COCK_X, COCK_PIVOT[1], COCK_PIVOT[0]))
    frizzen = join([build_frizzen().build(bevel=0.0005)], "Frizzen",
                   (0.030, FRIZZEN_PIVOT[1], FRIZZEN_PIVOT[0]))
    ramrod = join([build_ramrod().build(sharp=50.0)], "Ramrod", tuple(rr_point(Z_RR_HEAD)))
    muzzle = add_empty("Muzzle", (0.0, AXIS_Y, Z_MUZZLE))
    pan = add_empty("Pan", (XL, PAN_TOP, PAN_Z))
    return [musket, cock, frizzen, ramrod, muzzle, pan]


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def export_glb(objs, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=True, export_normals=True,
        export_materials="EXPORT", export_image_format="AUTO",
        export_cameras=False, export_lights=False, export_extras=False)


# --------------------------------------------------------------------------
# Re-import check and preview renders
# --------------------------------------------------------------------------
def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras,
                 bpy.data.lights, bpy.data.curves, bpy.data.worlds):
        for d in list(coll):
            coll.remove(d)


def reimport_report(path):
    """Import the GLB into an empty scene and print node positions / bounds in Godot axes."""
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=path)
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    total = 0
    for o in sorted(bpy.context.scene.objects, key=lambda o: o.name):
        g = to_godot(o.matrix_world.translation)
        line = "REIMPORT node %-8s type=%-5s godot_pos=(%.4f, %.4f, %.4f)" % (o.name, o.type, g.x, g.y, g.z)
        if o.type == "MESH":
            t = tri_count(o)
            total += t
            olo = Vector((1e9, 1e9, 1e9))
            ohi = -olo
            for v in o.data.vertices:
                p = to_godot(o.matrix_world @ v.co)
                for i in range(3):
                    olo[i] = min(olo[i], p[i])
                    ohi[i] = max(ohi[i], p[i])
                    lo[i] = min(lo[i], p[i])
                    hi[i] = max(hi[i], p[i])
            line += " tris=%d bbox_min=(%.4f, %.4f, %.4f) bbox_max=(%.4f, %.4f, %.4f)" % (
                t, olo.x, olo.y, olo.z, ohi.x, ohi.y, ohi.z)
        print(line)
    print("REIMPORT total tris=%d bbox_min=(%.4f, %.4f, %.4f) bbox_max=(%.4f, %.4f, %.4f) size=(%.4f, %.4f, %.4f)" % (
        total, lo.x, lo.y, lo.z, hi.x, hi.y, hi.z, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z))


def _mat(name, color, rough=0.9, emission=None):
    m = principled(name, color=color, roughness=rough)
    if emission:
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    return m


def _box(name, center, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.data.materials.append(mat)
    return o


def _text(body, loc, size, mat, rot):
    cu = bpy.data.curves.new("txt_" + body, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    o = bpy.data.objects.new("txt_" + body, cu)
    o.location = loc
    o.rotation_euler = rot
    o.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(o)
    return o


def _sphere(name, loc, r, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=16, ring_count=8)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    return o


def _camera(name, loc, target=None, ortho=None, lens=50.0, rot=None):
    cd = bpy.data.cameras.new(name)
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    cd.clip_start = 0.005
    cd.clip_end = 20.0
    o = bpy.data.objects.new(name, cd)
    o.location = loc
    if rot is not None:
        o.rotation_euler = rot
    else:
        d = Vector(target) - Vector(loc)
        o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)
    return o


def render_previews(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    try:
        sc.eevee.taa_render_samples = 48
    except AttributeError:
        pass
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False

    # Sky-to-ground gradient so the metal has something to reflect.
    world = bpy.data.worlds.new("PreviewWorld")
    try:
        world.use_nodes = True
    except AttributeError:
        pass
    nt = world.node_tree
    bg = nt.nodes.get("Background")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (0.20, 0.19, 0.18, 1)
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = (0.80, 0.84, 0.90, 1)
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1.0
    mr.inputs["From Max"].default_value = 1.0
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.9
    sc.world = world

    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 2.6
    sun.angle = math.radians(6)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(35), math.radians(-30), math.radians(40))
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 35.0
    fill.size = 1.5
    fo = bpy.data.objects.new("Fill", fill)
    fo.location = (-1.2, 0.5, 0.9)
    fo.rotation_euler = Vector((1.2, 0.0, -0.9)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(fo)

    white = _mat("RulerWhite", (0.92, 0.92, 0.92))
    black = _mat("RulerBlack", (0.02, 0.02, 0.02))
    red = _mat("MarkRed", (0.9, 0.05, 0.03), emission=(0.9, 0.05, 0.03))
    green = _mat("MarkGreen", (0.05, 0.8, 0.1), emission=(0.05, 0.8, 0.1))
    orange = _mat("MarkOrange", (1.0, 0.5, 0.0), emission=(1.0, 0.5, 0.0))

    # Ruler: 10 cm blocks from Godot z = +0.3 to -1.3; labels are Godot z in metres.
    zr = -0.200
    helpers = []
    for i in range(16):
        yb = -0.30 + 0.1 * i
        helpers.append(_box("rul%d" % i, (0.0, yb + 0.05, zr), (0.012, 0.1, 0.005), black if i % 2 == 0 else white))
    rot_r = (math.radians(90), 0.0, math.radians(90))
    rot_l = (math.radians(90), 0.0, math.radians(-90))
    labels_r, labels_l = [], []
    for i in range(17):
        zg = 0.30 - 0.1 * i
        s = "0" if abs(zg) < 1e-6 else "%+.1f" % zg
        labels_r.append(_text(s, (0.02, -zg, zr - 0.024), 0.017, black, rot_r))
        labels_l.append(_text(s, (-0.02, -zg, zr - 0.024), 0.017, black, rot_l))
    labels_r.append(_text("Godot z (m), 10 cm blocks.  Origin = grip.  Muzzle -Z, up +Y",
                          (0.02, 0.50, zr - 0.052), 0.017, black, rot_r))
    labels_l.append(_text("Godot z (m), 10 cm blocks", (-0.02, 0.50, zr - 0.052), 0.017, black, rot_l))
    # Convention markers (drawn in front of the model for the right side view).
    marks = [_sphere("mk_muzzle", (0.06, -Z_MUZZLE, AXIS_Y), 0.006, red),
             _sphere("mk_origin", (0.06, 0.0, 0.0), 0.006, green),
             _sphere("mk_pan", (0.06, -PAN_Z, PAN_TOP), 0.004, orange),
             _text("Muzzle (0, %.3f, %.3f)" % (AXIS_Y, Z_MUZZLE), (0.07, -Z_MUZZLE - 0.10, AXIS_Y + 0.03),
                   0.016, red, rot_r),
             _text("origin / grip", (0.07, 0.0, -0.045), 0.016, green, rot_r),
             _text("Pan", (0.07, -PAN_Z, PAN_TOP + 0.055), 0.014, orange, rot_r)]

    floor_m = bpy.data.materials.new("Floor")
    try:
        floor_m.use_nodes = True
    except AttributeError:
        pass
    fnt = floor_m.node_tree
    bsdf = next(n for n in fnt.nodes if n.type == "BSDF_PRINCIPLED")
    tco = fnt.nodes.new("ShaderNodeTexCoord")
    chk = fnt.nodes.new("ShaderNodeTexChecker")
    chk.inputs["Scale"].default_value = 10.0
    chk.inputs["Color1"].default_value = (0.20, 0.20, 0.20, 1)
    chk.inputs["Color2"].default_value = (0.15, 0.15, 0.15, 1)
    fnt.links.new(tco.outputs["Object"], chk.inputs["Vector"])
    fnt.links.new(chk.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0, 0.5, -0.165))
    floor = bpy.context.active_object
    floor.data.materials.append(floor_m)

    yc = -(Z_HEEL + Z_MUZZLE) * 0.5
    shots = [
        # name, camera, resolution, show floor, show ruler, which labels, markers
        ("musket_side_right", _camera("c_sr", (2.0, yc, -0.075), (0, yc, -0.075), ortho=1.72), (2400, 760),
         False, True, "r", True),
        ("musket_side_left", _camera("c_sl", (-2.0, yc, -0.075), (0, yc, -0.075), ortho=1.72), (2400, 760),
         False, True, "l", False),
        ("musket_top", _camera("c_top", (0.0, yc, 2.0), rot=(0.0, 0.0, math.radians(90)), ortho=1.72),
         (2400, 440), False, False, "", False),
        ("musket_3q", _camera("c_3q", (1.95, 1.00, 0.95), (0.0, 0.50, -0.03), lens=40), (1800, 1000),
         True, False, "", False),
        ("musket_3q_left", _camera("c_3ql", (-1.45, -0.62, 0.92), (0.0, 0.47, -0.03), lens=42), (1800, 1000),
         True, False, "", False),
        ("musket_lock", _camera("c_lock", (0.24, 0.26, 0.13), (0.028, 0.115, 0.042), lens=50), (1400, 1000),
         False, False, "", False),
        ("musket_muzzle", _camera("c_muz", (0.13, 1.44, 0.10), (0.0, 1.24, 0.028), lens=50), (1400, 1000),
         False, False, "", False),
        ("musket_butt", _camera("c_butt", (0.42, -0.45, -0.22), (0.0, -0.07, -0.055), lens=35), (1400, 1000),
         False, False, "", False),
    ]
    for name, cam, (w, h), show_floor, show_ruler, lab, show_marks in shots:
        floor.hide_render = not show_floor
        for o in helpers:
            o.hide_render = not show_ruler
        for o in labels_r:
            o.hide_render = lab != "r"
        for o in labels_l:
            o.hide_render = lab != "l"
        for o in marks:
            o.hide_render = not show_marks
        sc.camera = cam
        sc.render.resolution_x = w
        sc.render.resolution_y = h
        sc.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
    project = os.path.abspath(os.path.join(here, "..", ".."))
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(project, "assets", "weapons", "musket.glb"))
    ap.add_argument("--renders", default=None, help="re-import the GLB and render previews here")
    ap.add_argument("--blend", default=None)
    ap.add_argument("--texture-png", default=None, help="also write the walnut texture here")
    ap.add_argument("--variant", default="", help="hall (M1819 Hall rifle) or trade (Northwest trade gun); none: the Brown Bess")
    args = ap.parse_args(argv)
    global VARIANT
    VARIANT = args.variant
    if VARIANT and args.out.endswith("musket.glb"):
        args.out = os.path.join(project, "assets", "weapons", {"hall": "hall_rifle.glb", "trade": "trade_musket.glb"}[VARIANT])

    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    objs = build_musket(args.texture_png)
    if VARIANT:
        objs = apply_variant(objs, VARIANT)
    total = 0
    for o in objs:
        if o.type == "MESH":
            t = tri_count(o)
            total += t
            print("MUSKET %-8s tris=%d verts=%d mats=%s" % (o.name, t, len(o.data.vertices),
                                                           [m.name for m in o.data.materials]))
    print("MUSKET total tris", total)
    export_glb(objs, args.out)
    print("EXPORTED", args.out)
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    reimport_report(args.out)
    if args.renders:
        render_previews(args.renders)


# --------------------------------------------------------------------------
# Variants (user 2026-10-01: "blender the new Hall rifle and an Indian trade musket"; the game spans decades)
# --------------------------------------------------------------------------
# Built from the Long Land Pattern above and then changed: the barrel and fore-end shortened (everything ahead of the breech
# reinforce, Z_REINF, pulled back toward it: barrel, stock, pipes, ramrod, swivel, muzzle), then each gun's own parts.
#   hall   US M1819 Hall breech-loading rifle (Harpers Ferry): 32.7 in barrel, .52 rifled; iron (browned) furniture, three
#          barrel bands, and the hinged breech block ("Breech": its own node, origin on the hinge at its rear, so the game can
#          tip its front up to load a paper cartridge into the chamber's mouth)
#   trade  the Northwest (Indian) trade gun: a light .58 smoothbore, 38 in barrel; brass, a big trigger-guard bow (a mittened
#          finger), a wooden ramrod
VARIANTS = {
    "hall": {"barrel": 0.831, "name": "HallRifle"},
    "trade": {"barrel": 0.965, "name": "TradeMusket"},
}


def compress_forward(objs, barrel_len):
    """Pull everything ahead of Z_REINF back toward it so the barrel is `barrel_len` long (Blender y = -Godot z)."""
    y0 = -Z_REINF
    y_old = -Z_MUZZLE
    y_new = -(Z_BREECH - barrel_len)
    k = (y_new - y0) / (y_old - y0)

    def squash(p):
        if p.y > y0:
            p.y = y0 + (p.y - y0) * k
        return p
    for o in objs:
        world = [o.matrix_world @ v.co for v in o.data.vertices] if o.type == "MESH" else None
        loc = o.location.copy()
        o.location = squash(loc)
        bpy.context.view_layer.update()
        if world is not None:
            inv = o.matrix_world.inverted()
            for v, w in zip(o.data.vertices, world):
                v.co = inv @ squash(w.copy())
    return lambda z: -squash(Vector((0.0, -z, 0.0))).y      # a Godot z before -> after


def _ring(name, z, r_out, width, y_c, mat):
    """An iron band round the barrel and fore-end at Godot z (a short tube along the bore)."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=r_out, depth=width, location=G((0.0, y_c, z)),
                                        rotation=(math.radians(90.0), 0.0, 0.0))
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o


def _block(name, c, s, mat):
    """A box (Godot centre and size) as its own object."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=G(c))
    o = bpy.context.active_object
    o.scale = (s[0], s[2], s[1])
    bpy.ops.object.transform_apply(scale=True)
    o.name = name
    o.data.materials.append(mat)
    bev = o.modifiers.new("bevel", "BEVEL")
    bev.width = 0.0012
    bev.segments = 2
    with bpy.context.temp_override(object=o, active_object=o):
        bpy.ops.object.modifier_apply(modifier=bev.name)
    return o


def apply_variant(objs, variant):
    v = VARIANTS[variant]
    by = {o.name: o for o in objs}
    gun = by["Musket"]
    if variant == "trade":
        # the big bow: the guard grown about its own middle before the shortening (it is behind the breech, untouched by it)
        pass
    zmap = compress_forward(objs, v["barrel"])
    z_muzzle = zmap(Z_MUZZLE)
    if variant == "hall":
        # browned iron for what was brass
        iron = principled("BrownedIron", color=(0.17, 0.14, 0.11), metallic=1.0, roughness=0.5)
        for slot in gun.material_slots:
            if slot.material and slot.material.name.startswith("Brass"):
                slot.material = iron
        # three bands: by the muzzle, the middle, and ahead of the lock
        bands = []
        for i, z in enumerate((z_muzzle + 0.085, lerp(z_muzzle + 0.085, -0.42, 0.5), -0.42)):
            bands.append(_ring("Band%d" % i, z, 0.0235 if i else 0.0205, 0.014 if i else 0.022, AXIS_Y - 0.012, iron))
        gun = join([gun] + bands, "Musket")
        # the breech block: a steel box over the chamber, hinged at its rear; its front face is the chamber's mouth
        steel = MATS["Iron"]
        blk = _block("Breech", (0.0, AXIS_Y + 0.004, -0.092), (0.034, 0.040, 0.160), steel)
        mouth = _block("BreechMouth", (0.0, AXIS_Y, -0.1725), (0.020, 0.020, 0.004), MATS["Dark"])
        breech = join([blk, mouth], "Breech", (0.0, AXIS_Y + 0.004, -0.012))
        # its lock on top: the hammer at the rear, the frizzen and pan at the front, all in one plane just right of the middle,
        # raised from the side lock's place onto the block's top, and carried on the block (they tip up with it)
        lift = G((-0.026, 0.024, 0.0)) - G((0.0, 0.0, 0.0))
        for nm in ("Cock", "Frizzen", "Pan"):
            o = by.get(nm)
            if o is None:
                continue
            o.location = o.location + lift
            bpy.context.view_layer.update()
            mw = o.matrix_world.copy()
            o.parent = breech
            o.matrix_world = mw
        browned = principled("BrownedBarrel", color=(0.20, 0.16, 0.12), metallic=1.0, roughness=0.45)
        for slot in gun.material_slots:
            if slot.material and slot.material.name.startswith("Iron"):
                slot.material = browned
        objs = [o for o in objs if o.name != "Musket"] + [gun, breech]
        gun.name = v["name"]
        gun.data.name = v["name"]
        return objs
    if variant == "trade":
        wood = principled("RamrodWood", color=(0.36, 0.22, 0.11), roughness=0.7)
        rr = by.get("Ramrod")
        if rr:
            rr.data.materials.clear()
            rr.data.materials.append(wood)
        gun.name = v["name"]
        gun.data.name = v["name"]
    return objs



if __name__ == "__main__":
    main()
