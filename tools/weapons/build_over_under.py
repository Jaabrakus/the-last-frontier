"""Over-under turnover flintlock ("Wender", swivel-breech gun) for Frontier.

One lock, two smoothbore barrels one above the other that turn by hand on a
swivel in front of the lock. Each barrel has its own pan, frizzen and frizzen
spring on a small iron pan plate at its breech; the barrel on top always brings
its pan under the cock. A catch at the front of the trigger guard releases the
barrels for the half turn. Paneled construction: wooden panels on both sides of
the barrel pair form the fore-end, so the wood under the left hand turns with
the barrels. The hickory ramrod rides in brass pipes in the groove between the
barrels on one side and turns with them. Each barrel has its own front and rear
sight. German sporting work of the mid-18th century: walnut half stock with a
cheekpiece and a sliding wooden patchbox lid, browned barrels, bright iron lock,
brass furniture. Design: Player_Animation_Project/graph_analysis/weapons/
weapons_balance_design.md sections 2.1, 2.2 and 2.7 (model contract), history in
over_under_research.md section 1.

Run headless (factory scene):
  Blender -b --factory-startup --python tools/weapons/build_over_under.py -- \
      [--out assets/weapons/over_under.glb] [--renders DIR] [--blend FILE.blend] \
      [--tex-dir DIR]

Conventions (Godot / glTF axes), the musket's (tools/models/musket.py,
scripts/weapons/weapon_models.gd):
  * origin = centre of the stock's wrist behind the trigger-guard bow (grip)
  * forward (barrels) = -Z, up = +Y, lock on the +X (right) side
  * top bore axis at y = 0.035, the musket's sight line, so the musket's aim
    calibration (aim_*_offset_deg) and hand placement hold unchanged
  * barrel spacing s = 0.027 m: swivel axis at y = 0.0215, lower bore y = 0.008
  * barrels 0.914 m (36 in) from the breech face at z = -0.128 to the muzzle at
    z = -1.042; overall 1.32 m (52 in)

Nodes (all names are part of the contract read by scripts/weapons/over_under/):
  OverUnder      stock-fixed body mesh: stock, standing breech, tang, lock plate,
                 trigger, guard, butt plate, side plate, cheekpiece, patchbox
  Cock           stock-fixed, origin on the tumbler axis (as musket.glb); mesh at
                 full cock; about -18 deg local X = half cock, -40 deg = fired
  Catch          stock-fixed barrel release at the front of the trigger guard,
                 origin on its pivot; about -14 deg local X = pressed
  Barrels        empty, origin on the swivel axis (0, 0.0215, -0.128); the
                 turnover rotates it 180 deg about its local Z. Children:
    BarrelPair   both barrels, side ribs, pan plates and pans, frizzen springs,
                 sights, wooden panels, nose caps, ramrod pipes
    FrizzenA     frizzen of barrel A (on top at rest), origin on its screw;
                 about -70 deg local X = open
    FrizzenB     barrel B's frizzen: the same part turned 180 deg about the swivel
    Ramrod       hickory rod with a brass tip, origin at its head
    MuzzleA/B    markers at each physical barrel's muzzle face
    PanA/B       markers at each physical barrel's pan
  Muzzle, Pan    root markers of the top slot (never move): where the barrel on
                 top fires from and flashes (Firearm reads these two)
  Muzzle_top, Muzzle_bottom, Pan_top, Pan_bottom   root markers of both slots
  LeftGrip       root marker on the fore-end where the left palm bone sits in
                 the musket's aim and carry clips (-0.012, -0.002, -0.270)

Textures: generated PBR maps (base colour, normal, metallic-roughness) for
walnut, hickory, browned iron, bright iron and brass. The wood and steel detail
comes from read-only crops of the CC0 Poly Haven textures already in
assets/polyhaven (MANIFEST.json: wooden_axe and hatchet model maps), recoloured;
without them the script falls back to procedural noise. Nothing is downloaded.
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

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
POLYHAVEN = os.path.join(PROJECT, "assets", "polyhaven")

# --------------------------------------------------------------------------
# Dimensions (metres, Godot axes: +X lock side, +Y up, -Z toward the muzzle)
# --------------------------------------------------------------------------
AXIS_Y = 0.035                      # top bore axis (the musket's sight line)
SPACING = 0.027                     # bore to bore
SWIVEL_Y = AXIS_Y - SPACING * 0.5   # 0.0215, the turnover axis
BOT_Y = AXIS_Y - SPACING            # 0.008, lower bore axis
Z_BREECH = -0.128                   # breech face of the barrel pair
BARREL_LEN = 0.914                  # 36 in
Z_MUZZLE = Z_BREECH - BARREL_LEN    # -1.042
OVERALL = 1.32                      # 52 in
Z_HEEL = Z_MUZZLE + OVERALL         # +0.278
BORE_R = 0.62 * 0.0254 * 0.5        # .62 (20-bore) smoothbore
R_OCT0, R_OCT1 = 0.0133, 0.0129     # octagon breech (inradius), breech -> band
Z_OCT_END = -0.330                  # octagon to round, with a raised band
R_BAND = 0.0143                     # just over the octagon's corners (0.0140)
R_ROUND0, R_MUZZLE = 0.0126, 0.0108
Z_PANEL0, Z_PANEL1 = -0.194, -0.622 # wooden fore-end panels
Z_NOSE = -0.634                     # brass nose caps
RIB_K = 0.45                        # side rib face at x = +-RIB_K * r(z)
RR = 0.0045                         # ramrod radius
RR_X = -0.0120                      # ramrod axis (left of barrel A), y = SWIVEL_Y
Z_RR_HEAD = Z_MUZZLE + 0.014
Z_RR_TAIL = -0.360
XP = 0.0265                         # outer face of lock plate and pan plates
XL = 0.029                          # centre plane of pan, frizzen and flint
PAN_Z = -0.1445
PAN_TOP = 0.0372
COCK_PIVOT = (-0.098, 0.016)        # (z, y) of the tumbler axis, as the musket
COCK_X = 0.030
COCK_TILT = math.radians(-22.0)
FRIZZEN_PIVOT = (-0.168, 0.0335)
CATCH_PIVOT = (-0.1005, -0.0205)    # (z, y)
LEFT_PALM = (-0.012, -0.002, -0.270)
N_RING = 24                         # stock cross-section vertices
N_BARREL = 32                       # barrel cross-section vertices (octagon corners included)
STOCK_LEN = Z_HEEL - Z_NOSE         # UV length of all wood (stock and panels)

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


def turn(p):
    """Point turned 180 deg about the swivel axis (barrel A's parts -> barrel B's)."""
    return (-p[0], 2.0 * SWIVEL_Y - p[1], p[2])


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


# --------------------------------------------------------------------------
# Barrel profile
# --------------------------------------------------------------------------
def r_round(z):
    """Outer radius of the round part (z < Z_OCT_END)."""
    return lerp(R_ROUND0, R_MUZZLE, (Z_OCT_END - 0.008 - z) / (Z_OCT_END - 0.008 - Z_MUZZLE))


def r_out(z):
    """Nominal outer radius (octagon inradius on the breech part)."""
    if z >= Z_OCT_END:
        return lerp(R_OCT0, R_OCT1, (Z_BREECH - z) / (Z_BREECH - Z_OCT_END))
    return r_round(z)


def barrel_ring(r, octagon, n=N_BARREL, start=-math.pi / 2):
    """(x, y) offsets around a barrel axis, starting at the bottom (seam side)."""
    pts = []
    for k in range(n):
        a = start + 2.0 * math.pi * k / n
        rr = r
        if octagon:
            # Flats face 0, 45, 90 ... deg; corners at 22.5 + 45 k (included for n = 32).
            f = ((a + math.pi / 8) % (math.pi / 4)) - math.pi / 8
            rr = r / math.cos(f)
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    return pts


def barrel_point(z, angle):
    """Point on barrel A's outer surface at `angle` (rad, from +X, CCW) and z."""
    octagon = z > Z_OCT_END
    r = r_out(z)
    if octagon:
        f = ((angle + math.pi / 8) % (math.pi / 4)) - math.pi / 8
        r = r / math.cos(f)
    return (r * math.cos(angle), AXIS_Y + r * math.sin(angle))


# --------------------------------------------------------------------------
# Stock cross-sections: (z, top, bottom, half width, belly y, n_top, n_bottom)
# The wrist and butt are the musket's (the right hand grips the same place);
# ahead of the wrist the stock ends at the standing breech with a section that
# matches the barrel pair and its pan plates. The butt is 1.2 cm shorter and a
# little fuller, German fashion.
# --------------------------------------------------------------------------
Z_STOCK0 = -0.1225
STOCK_KEYS = [
    (Z_STOCK0, 0.0488, -0.0082, 0.0262, 0.0205, 3.6, 3.0),
    (-0.112, 0.0484, -0.0150, 0.0258, 0.0195, 3.4, 3.1),
    (-0.095, 0.0462, -0.0230, 0.0252, 0.0172, 3.1, 3.3),
    (-0.070, 0.0415, -0.0272, 0.0249, 0.0148, 3.0, 3.4),
    (-0.030, 0.0325, -0.0278, 0.0243, 0.0100, 2.8, 3.1),
    (0.000, 0.0262, -0.0265, 0.0200, 0.0010, 2.5, 2.5),
    (0.030, 0.0200, -0.0300, 0.0190, -0.0040, 2.4, 2.4),
    (0.070, 0.0094, -0.0455, 0.0205, -0.0150, 2.5, 2.6),
    (0.115, 0.0016, -0.0680, 0.0226, -0.0285, 2.6, 2.8),
    (0.190, -0.0105, -0.1050, 0.0250, -0.0510, 2.7, 3.0),
    (Z_HEEL, -0.0240, -0.1440, 0.0258, -0.0770, 2.8, 3.0),
]
_SEC = [pchip([(k[0], k[i]) for k in STOCK_KEYS]) for i in range(1, 7)]
BUTT_SHEAR = 0.080
Y_HEEL = STOCK_KEYS[-1][1]


def section(z):
    return tuple(f(z) for f in _SEC)


def shear(z):
    return BUTT_SHEAR * smoothstep(0.205, 0.26, z)


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


def surf_side(z, y, side):
    """Point on the stock's left (side=-1) or right (+1) surface at height y."""
    top, bot, hw, belly, nt, nb = section(z)
    if y >= belly:
        n, h = nt, top - belly
    else:
        n, h = nb, belly - bot
    t = min(abs(y - belly) / h, 0.98)
    x = hw * (1.0 - t ** n) ** (1.0 / n)
    return Vector((side * x, y, z)), Vector((side, 0, 0))


# --------------------------------------------------------------------------
# Mesh building helpers (all input in Godot coordinates)
# --------------------------------------------------------------------------
class Part:
    """bmesh under construction. Faces given explicit UVs keep them; the rest get
    a world-scaled box projection (UV_BOX metres per UV unit) at build time."""
    UV_BOX = 0.10

    def __init__(self, name, mats):
        self.name = name
        self.mats = list(mats)
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.has_uv = set()

    def v(self, p):
        return self.bm.verts.new(G(p))

    def face(self, verts, mi=0, uvs=None):
        f = self.bm.faces.new(verts)
        f.material_index = mi
        f.smooth = True
        if uvs is not None:
            for loop, t in zip(f.loops, uvs):
                loop[self.uv].uv = t
            self.has_uv.add(f)
        return f

    def _box_uvs(self):
        s = 1.0 / self.UV_BOX
        for f in self.bm.faces:
            if f in self.has_uv:
                continue
            f.normal_update()
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            u_ax, v_ax = [(1, 2), (0, 2), (0, 1)][ax]
            for loop in f.loops:
                co = loop.vert.co
                loop[self.uv].uv = (co[u_ax] * s, co[v_ax] * s)

    def build(self, sharp=40.0):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        self._box_uvs()
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(MATS[m])
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(sharp))
        print("PART %-16s tris=%d" % (self.name, sum(len(f.vertices) - 2 for f in me.polygons)))
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


def prism_z(part, outline, z0, z1, mi=0, xf=None):
    """Extrude an (x, y) outline between z0 and z1 (optionally mapped by xf)."""
    f = xf or (lambda p: p)
    a = [part.v(f((x, y, z0))) for x, y in outline]
    b = [part.v(f((x, y, z1))) for x, y in outline]
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


def loft(part, rings, mats, uvs=None, cap0=True, cap1=True, closed_ring=True):
    """Skin consecutive rings of 3D points (equal counts). mats: per segment index or
    one int. uvs: per ring a list of (u, v) per point (one extra entry closes the seam)."""
    vs = [[part.v(p) for p in ring] for ring in rings]
    n = len(rings[0])
    seg = n if closed_ring else n - 1
    for i in range(len(rings) - 1):
        mi = mats[i] if isinstance(mats, (list, tuple)) else mats
        for k in range(seg):
            k1 = (k + 1) % n
            quv = None
            if uvs is not None:
                quv = [uvs[i][k], uvs[i][k + 1], uvs[i + 1][k + 1], uvs[i + 1][k]]
            part.face([vs[i][k], vs[i][k1], vs[i + 1][k1], vs[i + 1][k]], mi, quv)
    m0 = mats[0] if isinstance(mats, (list, tuple)) else mats
    m1 = mats[-1] if isinstance(mats, (list, tuple)) else mats
    if cap0:
        part.face(vs[0][::-1] if closed_ring else vs[0], m0)
    if cap1:
        part.face(vs[-1] if closed_ring else vs[-1][::-1], m1)
    return vs


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


def dome_screw(part, origin, axis, r, h=0.0016, sides=8, mi=0):
    lathe(part, origin, axis, [(0.0, r), (h * 0.4, r), (h * 0.85, r * 0.72), (h, 0.0)], sides, mats=mi)


# --------------------------------------------------------------------------
# Stock-fixed parts
# --------------------------------------------------------------------------
WOOD_RINGS = [-0.118, -0.112, -0.105, -0.095, -0.083, -0.070, -0.055, -0.042, -0.030, -0.015, 0.0,
              0.015, 0.03, 0.05, 0.07, 0.095, 0.115, 0.14, 0.165, 0.19, 0.215, 0.235, 0.255]


def build_stock():
    """Walnut half stock from the standing breech to the brass butt plate."""
    p = Part("Stock", ["Walnut", "Brass"])
    WOOD, BR = 0, 1
    z_bp = Z_HEEL - 0.006
    spec = ([(Z_STOCK0, WOOD, 0.0)] + [(z, WOOD, 0.0) for z in WOOD_RINGS]
            + [(z_bp, WOOD, 0.0), (z_bp, BR, 0.0006), (Z_HEEL, BR, 0.0006)])
    rings = []
    for z, mat, inf in spec:
        sh = shear(z)
        rings.append((z, mat, [p.v((x, y, z + sh * (y - Y_HEEL))) for x, y in ring2d(z, inf)]))
    for i in range(len(rings) - 1):
        z0, m0, A = rings[i]
        z1, m1, B = rings[i + 1]
        mi = BR if BR in (m0, m1) else WOOD
        u0, u1 = (Z_HEEL - z0) / STOCK_LEN, (Z_HEEL - z1) / STOCK_LEN
        for k in range(N_RING):
            k1 = (k + 1) % N_RING
            v0, v1 = k / N_RING, (k + 1) / N_RING
            p.face([A[k], A[k1], B[k1], B[k]], mi, [(u0, v0), (u0, v1), (u1, v1), (u1, v0)])
    p.face(rings[0][2], WOOD)
    p.face(rings[-1][2][::-1], BR)
    return p


def build_cheekpiece():
    """German cheekpiece on the left of the butt, and the sliding patchbox lid on the right."""
    p = Part("Cheekpiece", ["Walnut", "Brass"])
    zs = [0.080, 0.090, 0.105, 0.125, 0.150, 0.175, 0.200, 0.222, 0.236, 0.242]
    rings = []
    uvs = []
    n = 16
    for i, z in enumerate(zs):
        top, bot, hw, belly, nt, nb = section(z)
        t = (z - zs[0]) / (zs[-1] - zs[0])
        bulge = 0.0072 * math.sin(math.pi * min(1.0, t * 1.25)) ** 0.5 if t < 0.97 else 0.0045
        h = 0.034 * (0.35 + 0.65 * smoothstep(0.0, 0.35, t))
        yc = belly + 0.010 + 0.004 * t
        sh = shear(z)
        ring = []
        uv = []
        for k in range(n + 1):
            a = 2.0 * math.pi * (k % n) / n
            cx = spow(math.cos(a), 0.55)
            cy = spow(math.sin(a), 0.7)
            y = yc + cy * h * 0.5
            base = surf_side(z, y, -1)[0].x
            x = base - max(0.0, cx) * bulge + max(0.0, -cx) * 0.004
            if k < n:
                ring.append((x, y, z + sh * (y - Y_HEEL)))
            uv.append(((Z_HEEL - z) / STOCK_LEN, 0.62 + k / n * 0.25))
        rings.append(ring)
        uvs.append(uv)
    loft(p, rings, 0, uvs)
    # Patchbox lid: a thin sliding wooden lid proud of the right side of the butt,
    # with a small brass finger catch at its front.
    zs = [0.125, 0.132, 0.16, 0.19, 0.22, 0.240]
    rings, uvs = [], []
    n = 12
    for i, z in enumerate(zs):
        top, bot, hw, belly, nt, nb = section(z)
        sh = shear(z)
        t = (z - zs[0]) / (zs[-1] - zs[0])
        hh = 0.013 * (0.55 + 0.45 * smoothstep(0.0, 0.25, t))    # rounded front end
        y0 = belly - 0.003
        proud = 0.0016 if 0 < i < len(zs) - 1 else 0.0008
        ring, uv = [], []
        for k in range(n + 1):
            a = 2.0 * math.pi * (k % n) / n
            yy = y0 + hh * math.sin(a)
            base = surf_side(z, yy, 1)[0].x
            x = base + proud if math.cos(a) > -1e-6 else base - 0.002
            if k < n:
                ring.append((x, yy, z + sh * (yy - Y_HEEL)))
            uv.append(((Z_HEEL - z) / STOCK_LEN, 0.1 + k / n * 0.2))
        rings.append(ring)
        uvs.append(uv)
    loft(p, rings, 0, uvs)
    zc = 0.130
    yc = section(zc)[3] - 0.004
    x0 = surf_side(zc, yc, 1)[0].x + 0.0018
    lathe(p, (x0, yc, zc), (1, 0, 0), [(0.0, 0.0022), (0.0012, 0.0022), (0.0022, 0.0014), (0.0026, 0.0)],
          10, mats=1)
    return p


def build_breech_plate():
    """Iron standing breech: recoil face for the barrel pair, carries the swivel pin."""
    p = Part("BreechPlate", ["Iron"])
    zf, zb = Z_BREECH + 0.0002, Z_STOCK0 + 0.0008
    r0 = [(x, y, zf) for x, y in ring2d(Z_STOCK0, 0.0005)]
    r1 = [(x, y, zb) for x, y in ring2d(Z_STOCK0, 0.0005)]
    loft(p, [r0, r1], 0)
    # Breech tang on the top of the wrist.
    wf = pchip([(-0.1215, 0.0200), (-0.100, 0.0165), (-0.075, 0.0130), (-0.058, 0.0098),
                (-0.050, 0.0068), (-0.0455, 0.0035), (-0.0440, 0.0010)])
    zs = [-0.1215, -0.112, -0.100, -0.088, -0.075, -0.064, -0.056, -0.050, -0.047, -0.0448, -0.0440]
    strip(p, zs, wf, surf_top, 0.0017)
    return p


LOCK_PLATE = [(-0.1232, 0.0100), (-0.1232, 0.0318), (-0.1195, 0.0342), (-0.1050, 0.0337),
              (-0.0850, 0.0310), (-0.0650, 0.0265), (-0.0500, 0.0220), (-0.0400, 0.0180),
              (-0.0330, 0.0140), (-0.0290, 0.0105), (-0.0285, 0.0080), (-0.0310, 0.0055),
              (-0.0400, 0.0030), (-0.0600, 0.0012), (-0.0850, 0.0006), (-0.1050, 0.0012),
              (-0.1180, 0.0040)]


def build_lock_plate():
    p = Part("LockPlate", ["Iron"])
    prism(p, LOCK_PLATE, 0.0225, XP)
    # Bolster line and a little engraved border (a raised bead near the edge).
    box(p, (XP + 0.0003, 0.0322, -0.112), (0.0008, 0.0012, 0.020))
    return p


def build_side_plate():
    """Brass side plate opposite the lock, carrying the two lock bolts."""
    p = Part("SidePlate", ["Brass", "Iron"])
    path = [(-0.118, 0.0205), (-0.108, 0.0180), (-0.095, 0.0160), (-0.080, 0.0140),
            (-0.066, 0.0122), (-0.054, 0.0100), (-0.044, 0.0080), (-0.035, 0.0062)]
    widths = [0.0040, 0.0110, 0.0080, 0.0070, 0.0115, 0.0070, 0.0040, 0.0015]
    prism(p, sweep_outline(path, widths), -0.0272, -0.0232)
    for z, y in ((-0.108, 0.0180), (-0.066, 0.0122)):
        dome_screw(p, (-0.0270, y, z), (-1, 0, 0), 0.0042, 0.0017, 10, mi=1)
    return p


def build_trigger():
    p = Part("Trigger", ["Iron"])
    path = [(-0.0575, -0.0200), (-0.0582, -0.0300), (-0.0580, -0.0380), (-0.0562, -0.0450),
            (-0.0530, -0.0495), (-0.0495, -0.0515)]
    prism(p, sweep_outline(path, [0.0058, 0.0056, 0.0052, 0.0047, 0.0042, 0.0036]), -0.0025, 0.0025)
    return p


def build_furniture():
    """Brass trigger guard (strap and bow), butt-plate tang and thumb plate."""
    p = Part("Straps", ["Brass"])
    bow = Part("GuardBow", ["Brass"])
    flat = (-1.0, 1.0)
    # Guard strap: its front ends under the catch at the front of the bow.
    wf = pchip([(-0.1120, 0.0010), (-0.1100, 0.0085), (-0.1040, 0.0120), (-0.0950, 0.0135),
                (-0.0170, 0.0135), (0.0100, 0.0118), (0.0400, 0.0090), (0.0650, 0.0068),
                (0.0740, 0.0052), (0.0785, 0.0030), (0.0800, 0.0010)])
    zs = [-0.112, -0.1105, -0.108, -0.104, -0.099, -0.093, -0.075, -0.056,
          -0.037, -0.017, 0.0, 0.015, 0.03, 0.045, 0.058, 0.068, 0.074, 0.077, 0.079, 0.080]
    strip(p, zs, wf, surf_bot, 0.0025, lat=flat)
    zc, a, b = -0.0555, 0.0375, 0.029
    y0 = surf_bot(zc, 0.0)[0].y - 0.0015
    pts = [Vector((0.0, y0 + b * math.sin(t), zc + a * math.cos(t)))
           for t in (math.pi + math.pi * i / 18 for i in range(19))]
    sweep3d(bow, pts, [(0.0019, -0.0036), (0.0019, 0.0036), (0.0009, 0.0048), (-0.0009, 0.0048),
                       (-0.0019, 0.0036), (-0.0019, -0.0036), (-0.0009, -0.0048), (0.0009, -0.0048)], (1, 0, 0))
    # Butt plate tang over the comb.
    z_bp = Z_HEEL - 0.006
    wf = pchip([(0.170, 0.0010), (0.1725, 0.0075), (0.178, 0.0115), (0.190, 0.0128), (0.220, 0.0140),
                (z_bp + 0.001, 0.0165)])
    strip(p, [0.170, 0.1715, 0.174, 0.178, 0.185, 0.198, 0.222, 0.248, z_bp + 0.001],
          wf, surf_top, 0.0016)

    def wthumb(z):
        t = (z - 0.036) / 0.0155
        return 0.019 * math.sqrt(max(0.0, 1.0 - t * t))
    strip(p, [0.0206, 0.0222, 0.026, 0.031, 0.036, 0.041, 0.046, 0.0498, 0.0514],
          wthumb, surf_top, 0.0012)
    return p, bow


def build_stock_screws():
    p = Part("StockScrews", ["Iron"])
    dome_screw(p, surf_top(-0.083, 0.0)[0] + Vector((0, 0.0016, 0)), (0, 1, 0), 0.0034)   # tang screw
    return p


def cock_xf(dz, dy):
    """Cock design coordinates (relative to the tumbler axis, upright) -> world (z, y) at full cock."""
    c, s = math.cos(COCK_TILT), math.sin(COCK_TILT)
    return (COCK_PIVOT[0] + dz * c - dy * s, COCK_PIVOT[1] + dz * s + dy * c)


def build_cock():
    """Swan-neck cock at full cock with the flint in a leather (the musket's lock pattern)."""
    iron = Part("CockIron", ["Iron"])
    body = convex_hull(circle_outline(0.0, 0.0, 0.0105, 16) + circle_outline(-0.0115, -0.0050, 0.0042, 8))
    prism(iron, [cock_xf(z, y) for z, y in body], 0.0268, 0.0332)
    neck = catmull([(0.0015, 0.0050), (-0.0035, 0.0170), (-0.0088, 0.0280), (-0.0072, 0.0375),
                    (-0.0005, 0.0448), (0.0058, 0.0500)], 3)
    widths = [lerp(0.0112, 0.0078, min(1.0, i / 6.0)) if i < 6 else
              lerp(0.0074, 0.0088, (i - 6) / (len(neck) - 7)) for i in range(len(neck))]
    prism(iron, [cock_xf(z, y) for z, y in sweep_outline(neck, widths)], 0.0270, 0.0330)
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
    c, s = math.cos(COCK_TILT), math.sin(COCK_TILT)
    up = (0.0, c, -s)
    zb, yb = cock_xf(0.0085, 0.0480)
    lathe(screws, (XL, yb, zb), up,
          [(0, 0), (0, 0.0026), (0.0195, 0.0026), (0.0195, 0.0048), (0.0225, 0.0048), (0.0240, 0.0036),
           (0.0247, 0.0)], 10)
    dome_screw(screws, (0.0330, COCK_PIVOT[1], COCK_PIVOT[0]), (1, 0, 0), 0.0050, 0.0018, 10)
    return [iron.build(), flint.build(), leather.build(), screws.build(sharp=50.0)]


def build_catch():
    """Barrel release: a lever pivoted in the stock belly in front of the guard bow. Its
    finger piece hangs in front of the bow; its hook reaches forward under the lower
    barrel into the latch notch. Pressing the finger piece back drops the hook."""
    p = Part("Catch", ["Iron"])
    zc, yc = CATCH_PIVOT
    finger = catmull([(zc, yc), (zc - 0.0035, yc - 0.0080), (zc - 0.0052, yc - 0.0160),
                      (zc - 0.0035, yc - 0.0225), (zc + 0.0005, yc - 0.0255)], 3)
    prism(p, sweep_outline(finger, [0.0050, 0.0048, 0.0044, 0.0040, 0.0046, 0.0050,
                                    0.0052, 0.0050, 0.0046, 0.0042, 0.0040, 0.0040, 0.0044]),
          -0.0024, 0.0024)
    hook = [(zc, yc), (zc - 0.0100, yc + 0.0030), (zc - 0.0205, yc + 0.0085), (-0.1272, yc + 0.0118)]
    prism(p, sweep_outline(hook, [0.0042, 0.0038, 0.0034, 0.0030]), -0.0020, 0.0020)
    box(p, (0.0, yc + 0.0130, -0.1270), (0.0040, 0.0030, 0.0030))     # hook tooth
    lathe(p, (-0.0026, yc, zc), (1, 0, 0), [(0.0, 0.0), (0.0, 0.0022), (0.0052, 0.0022), (0.0052, 0.0)], 8)
    return p


# --------------------------------------------------------------------------
# Barrel assembly (turns about the swivel axis)
# --------------------------------------------------------------------------
BARREL_Z = ([Z_BREECH, Z_BREECH - 0.0015, -0.170, -0.230, -0.290, Z_OCT_END + 0.003, Z_OCT_END]
            + [Z_OCT_END - 0.0012, Z_OCT_END - 0.0068, Z_OCT_END - 0.008]
            + [-0.42, -0.55, -0.68, -0.80, -0.90, -0.98, Z_MUZZLE + 0.012, Z_MUZZLE + 0.0015])


def build_barrel(part, flip, mi_out=0, mi_bore=1):
    """One barrel (A on top; flip = B) with an octagonal breech, a raised band, a round
    tapered barrel, a crowned muzzle and a dark .62 bore."""
    rings, uvs = [], []
    circ = 2.0 * math.pi * R_ROUND0
    for z in BARREL_Z:
        if z >= Z_OCT_END:
            r, octa = r_out(z), True
            if z == Z_BREECH:
                r -= 0.0006
        elif z > Z_OCT_END - 0.0081 and z < Z_OCT_END - 0.0009:
            r, octa = R_BAND, False
        elif z > Z_OCT_END - 0.0081:
            r, octa = r_round(z) + 0.0004, False     # small shoulder behind the band
        else:
            r, octa = r_round(z), False
        if z == Z_MUZZLE + 0.0015:
            r = R_MUZZLE
        pts = barrel_ring(r, octa)
        ring = [(x, AXIS_Y + y, z) for x, y in pts]
        if flip:
            ring = [turn(q) for q in ring]
        rings.append(ring)
        u = (Z_BREECH - z) / BARREL_LEN
        uvs.append([(u, k / N_BARREL * circ / 0.23) for k in range(N_BARREL + 1)])
    # Crown and bore.
    zc = Z_MUZZLE
    for z, r in ((zc, R_MUZZLE - 0.0011), (zc, BORE_R + 0.0007), (zc + 0.0008, BORE_R), (zc + 0.07, BORE_R)):
        ring = [(x, AXIS_Y + y, z) for x, y in barrel_ring(r, False)]
        if flip:
            ring = [turn(q) for q in ring]
        rings.append(ring)
        u = (Z_BREECH - z) / BARREL_LEN
        uvs.append([(u, k / N_BARREL * circ / 0.23) for k in range(N_BARREL + 1)])
    n_out = len(BARREL_Z)
    mats = [mi_out] * (n_out + 1) + [mi_bore] * 3
    loft(part, rings, mats, uvs, cap0=True, cap1=True)


def build_side_ribs(part, mi=0):
    """Flat ribs joining the barrels on both sides, from under the panels to the muzzle."""
    zs = [-0.200, -0.330, -0.338, -0.50, -0.70, -0.90, Z_MUZZLE + 0.0012]
    rings = []
    for z in zs:
        w = RIB_K * (r_round(z) if z < Z_OCT_END else r_out(z))
        y0, y1 = BOT_Y + BORE_R + 0.0010, AXIS_Y - BORE_R - 0.0010    # clear of both bores
        rings.append([(w, y0, z), (w, y1, z), (-w, y1, z), (-w, y0, z)])
    loft(part, rings, mi)


PAN_PLATE = [(-0.1284, 0.0120), (-0.1284, 0.0330), (-0.1330, 0.0345), (-0.1600, 0.0347),
             (-0.1860, 0.0340), (-0.1945, 0.0315), (-0.2005, 0.0265), (-0.2025, 0.0195),
             (-0.1965, 0.0125), (-0.1880, 0.0092), (-0.1700, 0.0075), (-0.1450, 0.0082)]


def build_lock_half(part, flip, mi_iron):
    """Barrel A's pan plate, pan, fence, frizzen bridle, frizzen spring and screws; flip = B."""
    xf = turn if flip else None

    def P(p):
        return turn(p) if flip else p

    def prism_f(outline, x0, x1):
        a = [part.v(P((x0, y, z))) for z, y in outline]
        b = [part.v(P((x1, y, z))) for z, y in outline]
        n = len(outline)
        for i in range(n):
            j = (i + 1) % n
            part.face([a[i], a[j], b[j], b[i]], mi_iron)
        part.face(a, mi_iron)
        part.face(b[::-1], mi_iron)

    def box_f(c, s):
        hx, hy, hz = s[0] * 0.5, s[1] * 0.5, s[2] * 0.5
        prism_f([(c[2] - hz, c[1] - hy), (c[2] + hz, c[1] - hy), (c[2] + hz, c[1] + hy),
                 (c[2] - hz, c[1] + hy)], c[0] - hx, c[0] + hx)
    prism_f(PAN_PLATE, 0.0115, XP)
    pan = [(-0.1575, PAN_TOP), (-0.1565, 0.0335), (-0.1535, 0.0307), (-0.1490, 0.0292),
           (-0.1445, 0.0288), (-0.1400, 0.0292), (-0.1355, 0.0307), (-0.1325, 0.0335), (-0.1315, PAN_TOP)]
    prism_f(pan[::-1], 0.0185, 0.0395)
    box_f((0.0288, 0.0374, -0.1300), (0.0185, 0.0088, 0.0024))           # fence behind the pan
    box_f((0.0283, 0.0320, -0.1665), (0.0040, 0.0080, 0.0130))           # bridle for the frizzen pivot
    path = [(-0.1600, 0.0105), (-0.1720, 0.0118), (-0.1850, 0.0135), (-0.1935, 0.0152),
            (-0.1975, 0.0178), (-0.1945, 0.0208), (-0.1860, 0.0232), (-0.1760, 0.0252)]
    prism_f(sweep_outline(path, [0.0042, 0.0040, 0.0035, 0.0032, 0.0030, 0.0030, 0.0028, 0.0025]),
            XP - 0.0005, XP + 0.0035)
    # Screws: frizzen pivot and spring.
    ax = Vector((-1, 0, 0)) if flip else Vector((1, 0, 0))
    dome_screw(part, P((0.0393, FRIZZEN_PIVOT[1], FRIZZEN_PIVOT[0])), ax, 0.0033, 0.0014, mi=mi_iron)
    dome_screw(part, P((0.0298, 0.0105, -0.1625)), ax, 0.0030, 0.0013, mi=mi_iron)
    dome_screw(part, P((XP, 0.0215, -0.188)), ax, 0.0034, 0.0014, mi=mi_iron)
    return xf


def build_sights(part, flip, mi_brass, mi_iron):
    """Front sight (brass blade) and rear sight (iron notch) of one barrel, on its top."""
    def P(p):
        return turn(p) if flip else p
    zf = Z_MUZZLE + 0.024
    yb = AXIS_Y + r_round(zf) - 0.0012
    blade = [(zf - 0.0060, yb), (zf + 0.0060, yb), (zf + 0.0040, yb + 0.0030), (zf + 0.0015, yb + 0.0048),
             (zf - 0.0015, yb + 0.0048), (zf - 0.0045, yb + 0.0030)]
    a = [part.v(P((-0.0010, y, z))) for z, y in blade]
    b = [part.v(P((0.0010, y, z))) for z, y in blade]
    for i in range(len(blade)):
        j = (i + 1) % len(blade)
        part.face([a[i], a[j], b[j], b[i]], mi_brass)
    part.face(a, mi_brass)
    part.face(b[::-1], mi_brass)
    zr = -0.300
    yb = AXIS_Y + r_out(zr) - 0.0004
    notch = [(-0.0065, yb), (0.0065, yb), (0.0060, yb + 0.0048), (0.0014, yb + 0.0048),
             (0.0, yb + 0.0026), (-0.0014, yb + 0.0048), (-0.0060, yb + 0.0048)]
    prism_z(part, notch, zr + 0.0022, zr - 0.0022, mi_iron, xf=P)


def panel_ring(z, inflate=0.0, n_outer=13):
    """Right fore-end panel of barrel A at z: from the top contact on barrel A (14 deg above
    its equator) round the outer bulge to the lower barrel (14 deg below its equator),
    then back inside the barrels (hidden)."""
    t = (z - Z_PANEL0) / (Z_PANEL1 - Z_PANEL0)
    hw = lerp(0.0208, 0.0184, max(0.0, min(1.0, t))) + inflate
    xt, yt = barrel_point(z, math.radians(14.0))
    yt = min(yt, AXIS_Y + 0.0046)
    yb_ = 2.0 * SWIVEL_Y - yt
    xt -= 0.0003
    a = hw - xt
    b = yt - SWIVEL_Y + inflate * 0.5
    pts = []
    for k in range(n_outer):
        th = math.pi / 2 - math.pi * k / (n_outer - 1)
        c, s = math.cos(th), math.sin(th)
        pts.append((xt + a * spow(c, 2.0 / 2.15), SWIVEL_Y + b * spow(s, 2.0 / 2.0)))
    pts[0] = (xt, SWIVEL_Y + b)
    pts[-1] = (xt, SWIVEL_Y - b)
    pts.append((0.0035, yb_ + 0.0005))
    pts.append((0.0035, yt - 0.0005))
    return pts


def ring_arclen_uv(pts, u, scale=0.16):
    out = [(u, 0.0)]
    s = 0.0
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        s += math.hypot(b[0] - a[0], b[1] - a[1])
        out.append((u, s / scale))
    return out


PANEL_Z = [Z_PANEL0, -0.215, -0.26, -0.33, -0.40, -0.48, -0.56, -0.60, Z_PANEL1]


def build_panel(part, flip, mi_wood, mi_brass):
    """Walnut fore-end panel on barrel A's lock side (flip = B's, on the other side), with its
    brass nose cap. The two panels turn with the barrels."""
    def P(p):
        return turn(p) if flip else p
    rings, uvs = [], []
    for i, z in enumerate(PANEL_Z):
        pts = panel_ring(z)
        # Round the rear end into the pan plate: pull the first ring in a little.
        if i == 0:
            pts = [(lerp(0.0122, x, 0.85) if x > 0.0122 else x, y) for x, y in pts]
        rings.append([P((x, y, z)) for x, y in pts])
        uvs.append(ring_arclen_uv(pts, (Z_HEEL - z) / STOCK_LEN))
    loft(part, rings, mi_wood, uvs)
    rings = []
    for z in (Z_PANEL1 + 0.0004, Z_NOSE + 0.0015, Z_NOSE):
        pts = panel_ring(Z_PANEL1, 0.0006 if z != Z_NOSE else 0.0002)
        rings.append([P((x, y, z)) for x, y in pts])
    loft(part, rings, mi_brass)


def build_pipes(part, mi_brass):
    """Brass ramrod pipes in the left groove between the barrels (barrel A on top)."""
    ri, ro = RR + 0.0006, RR + 0.0019
    axis = (0, 0, 1)
    for z0, ln in ((-0.985, 0.034), (-0.805, 0.030)):
        lathe(part, (RR_X, SWIVEL_Y, z0), axis,
              [(0, ri), (0, ro + 0.0007), (0.0025, ro + 0.0007), (0.0035, ro), (ln - 0.0035, ro),
               (ln - 0.0025, ro + 0.0007), (ln, ro + 0.0007), (ln, ri)], 12, mats=mi_brass, closed=True)
    # Entry pipe with a trumpet mouth at the nose caps.
    ln = 0.045
    lathe(part, (RR_X, SWIVEL_Y, Z_NOSE - ln + 0.004), axis,
          [(0, ri + 0.0012), (0, ro + 0.0018), (0.004, ro + 0.0008), (0.012, ro), (ln, ro), (ln, ri)],
          12, mats=mi_brass, closed=True)


def build_ramrod():
    p = Part("Ramrod", ["Hickory", "Brass"])
    length = Z_RR_HEAD - Z_RR_TAIL
    length = abs(length)
    head = (RR_X, SWIVEL_Y, Z_RR_HEAD)
    prof = [(0.0, 0.0), (0.0, 0.0038), (0.0008, 0.0046), (0.012, 0.0048), (0.016, RR - 0.0001)]
    lathe(p, head, (0, 0, 1), prof + [(0.0165, 0.0)], 12, mats=1)
    lathe(p, (RR_X, SWIVEL_Y, Z_RR_HEAD + 0.016), (0, 0, 1),
          [(0.0, 0.0), (0.0, RR - 0.0002), (0.3, RR - 0.0004), (length - 0.019, 0.0036), (length - 0.016, 0.0),
           ], 12, mats=0)
    obj = p.build(sharp=50.0)
    # Hickory UVs: along the rod.
    return obj


def build_frizzen(name):
    p = Part(name, ["Iron"])
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
    return p.build()


def build_barrel_pair():
    p = Part("BarrelPair", ["BrownedIron", "Dark", "Iron", "Walnut", "Brass"])
    BRN, DARK, IRON, WOOD, BRASS = 0, 1, 2, 3, 4
    for flip in (False, True):
        build_barrel(p, flip, BRN, DARK)
        build_lock_half(p, flip, IRON)
        build_sights(p, flip, BRASS, IRON)
        build_panel(p, flip, WOOD, BRASS)
    build_side_ribs(p, BRN)
    build_pipes(p, BRASS)
    return p.build(sharp=35.0)


# --------------------------------------------------------------------------
# Textures (generated PBR maps; detail from the CC0 Poly Haven crops when present)
# --------------------------------------------------------------------------
def load_px(rel):
    path = os.path.join(POLYHAVEN, rel)
    if not os.path.exists(path):
        print("TEXTURE missing (procedural fallback):", rel)
        return None
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    print("TEXTURE source", rel)
    return px.reshape(h, w, 4)[:, :, :3].copy()


def crop(a, rect):
    """rect = (x0, y0, x1, y1) in top-down pixels (as an image viewer shows it); rows stay bottom-up."""
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
    return top * (1 - fy) + bot * fy


def dec_normal(a):
    n = a * 2.0 - 1.0
    return n / np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)


def renorm(n):
    return n / np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)


def rot_cw(a, normal=False):
    """Rotate a bottom-up (y-up) array 90 deg clockwise; normals turn with it."""
    b = np.rot90(a, k=1).copy()
    if normal:
        nx, ny = b[..., 0].copy(), b[..., 1].copy()
        b[..., 0] = ny
        b[..., 1] = -nx
    return b


def mirror_tile(a, normal=False, u=False, v=True):
    """Seamless by mirroring: append the flipped copy along V (and U)."""
    if v:
        f = a[::-1].copy()
        if normal:
            f[..., 1] *= -1.0
        a = np.concatenate([a, f], axis=0)
    if u:
        f = a[:, ::-1].copy()
        if normal:
            f[..., 0] *= -1.0
        a = np.concatenate([a, f], axis=1)
    return a


def lum(a):
    return a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11


def norm01(x, lo=2.0, hi=98.0):
    a, b = np.percentile(x, lo), np.percentile(x, hi)
    return np.clip((x - a) / max(b - a, 1e-6), 0.0, 1.0)


def vnoise(h, w, cells_y, cells_x, seed):
    g = np.random.default_rng(seed).random((cells_y + 1, cells_x + 1))
    g[-1, :] = g[0, :]
    g[:, -1] = g[:, 0]
    y = (np.arange(h) + 0.5) / h * cells_y
    x = (np.arange(w) + 0.5) / w * cells_x
    y0, x0 = np.floor(y).astype(int), np.floor(x).astype(int)
    fy, fx = y - y0, x - x0
    sy, sx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    sx, sy = sx[None, :], sy[:, None]
    return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy


def fbm(h, w, cy, cx, seed, octaves=4):
    tot, amp, norm = np.zeros((h, w)), 1.0, 0.0
    for o in range(octaves):
        tot += amp * vnoise(h, w, cy * 2 ** o, cx * 2 ** o, seed + o)
        norm += amp
        amp *= 0.5
    return tot / norm


def height_normal(hmap, strength):
    gy, gx = np.gradient(hmap)
    n = np.dstack([-gx * strength, -gy * strength, np.ones_like(hmap)])
    return renorm(n)


def to_image(name, arr, non_color=False):
    h, w = arr.shape[:2]
    if arr.ndim == 2:
        arr = np.dstack([arr, arr, arr])
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((h, w, 1), np.float32)], axis=2).astype(np.float32)
    im = bpy.data.images.new(name, w, h, alpha=False, is_data=non_color)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    im.pixels.foreach_set(rgba.ravel())
    im.update()
    im.pack()
    return im


def wood_maps(src_rect, h, w, dark, light, rough_range, seed, figure=0.0):
    diff = load_px("models/wooden_axe/textures/wooden_axe_diff_2k.jpg")
    nor = load_px("models/wooden_axe/textures/wooden_axe_nor_gl_2k.jpg")
    arm = load_px("models/wooden_axe/textures/wooden_axe_arm_2k.jpg")
    if diff is not None and nor is not None and arm is not None:
        c = mirror_tile(rot_cw(crop(diff, src_rect)))
        n = mirror_tile(rot_cw(dec_normal(crop(nor, src_rect)), True), True)
        r = mirror_tile(rot_cw(crop(arm, src_rect)[..., 1]))
        L = norm01(lum(resize(c, h, w)))
        n = resize(n, h, w)
        r = norm01(resize(r, h, w))
    else:
        u = np.linspace(0, 1, w)[None, :]
        v = np.linspace(0, 1, h)[:, None]
        warp = fbm(h, w, 2, 3, seed, 3) - 0.5
        L = 0.5 + 0.5 * np.sin(2 * np.pi * (v * 9.0 + warp * 3.0 + u * 0.3))
        L = 0.6 * L + 0.4 * fbm(h, w, 32, 6, seed + 5, 4)
        n = height_normal(L * 3.0, 0.5)
        r = fbm(h, w, 8, 8, seed + 9, 3)
    tone = fbm(h, w, 2, 3, seed + 40, 3)
    streak = fbm(h, w, 24, 6, seed + 20, 3)
    t = np.clip(0.78 * L + 0.35 * (tone - 0.5) + 0.25 * (streak - 0.5) + figure, 0.0, 1.0) ** 1.15
    col = np.array(dark)[None, None, :] + (np.array(light) - np.array(dark))[None, None, :] * t[..., None]
    n = renorm(np.dstack([n[..., 0] * 0.55, n[..., 1] * 0.55, n[..., 2]]))
    rough = rough_range[0] + (rough_range[1] - rough_range[0]) * np.clip(0.6 * r + 0.4 * (1 - L), 0, 1)
    return col.astype(np.float32), n.astype(np.float32), rough.astype(np.float32), np.zeros_like(rough)


def metal_maps(h, w, dark, light, rough_range, metal, seed, speckle=0.0):
    diff = load_px("models/hatchet/textures/hatchet_diff_2k.jpg")
    nor = load_px("models/hatchet/textures/hatchet_nor_gl_2k.jpg")
    arm = load_px("models/hatchet/textures/hatchet_arm_2k.jpg")
    rect = (80, 1650, 920, 1990)
    if diff is not None and nor is not None and arm is not None:
        c = mirror_tile(crop(diff, rect), u=True)
        n = mirror_tile(dec_normal(crop(nor, rect)), True, u=True)
        r = mirror_tile(crop(arm, rect)[..., 1], u=True)
        L = norm01(lum(resize(c, h, w)))
        n = resize(n, h, w)
        r = norm01(resize(r, h, w))
    else:
        L = fbm(h, w, 16, 64, seed, 5)
        n = height_normal(L, 0.3)
        r = fbm(h, w, 8, 32, seed + 3, 4)
    mott = fbm(h, w, 3, 12, seed + 11, 4)
    t = np.clip(0.55 * L + 0.55 * (mott - 0.5) + 0.25, 0.0, 1.0)
    col = np.array(dark)[None, None, :] + (np.array(light) - np.array(dark))[None, None, :] * t[..., None]
    rough = rough_range[0] + (rough_range[1] - rough_range[0]) * np.clip(0.5 * r + 0.5 * mott, 0, 1)
    if speckle > 0.0:
        sp = np.clip((vnoise(h, w, 90, 360, seed + 50) - 0.82) * 6.0, 0.0, 1.0) * speckle
        col = col * (1.0 - 0.35 * sp[..., None]) + np.array([0.22, 0.10, 0.05])[None, None, :] * 0.35 * sp[..., None]
        rough = np.clip(rough + 0.25 * sp, 0.0, 1.0)
    n = renorm(np.dstack([n[..., 0] * 0.45, n[..., 1] * 0.45, n[..., 2]]))
    return col.astype(np.float32), n.astype(np.float32), rough.astype(np.float32), np.full_like(rough, metal)


def brass_maps(h, w, seed):
    n1 = fbm(h, w, 6, 6, seed, 5)
    n2 = fbm(h, w, 40, 40, seed + 7, 3)
    base = np.array([0.76, 0.56, 0.27])
    col = base[None, None, :] * (0.86 + 0.22 * n1 - 0.08 * n2)[..., None]
    rough = 0.26 + 0.18 * n1 + 0.08 * n2
    return (col.astype(np.float32), height_normal(n2 * 1.5, 0.3).astype(np.float32),
            rough.astype(np.float32), np.ones_like(rough, dtype=np.float32))


def pbr_material(name, maps, tex_dir=None):
    col, nor, rough, metal = maps
    c_img = to_image("over_under_%s_color" % name.lower(), col)
    n_img = to_image("over_under_%s_normal" % name.lower(), nor * 0.5 + 0.5, True)
    orm = np.dstack([np.ones_like(rough), rough, metal])
    o_img = to_image("over_under_%s_orm" % name.lower(), orm, True)
    if tex_dir:
        os.makedirs(tex_dir, exist_ok=True)
        for tag, arr in (("color", col), ("normal", nor * 0.5 + 0.5), ("orm", orm)):
            tmp = to_image("dump_%s_%s" % (name, tag), arr, True)
            tmp.filepath_raw = os.path.join(tex_dir, "over_under_%s_%s.png" % (name.lower(), tag))
            tmp.file_format = "PNG"
            tmp.save()
            bpy.data.images.remove(tmp)
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t_col = nt.nodes.new("ShaderNodeTexImage")
    t_col.image = c_img
    t_col.location = (-600, 300)
    nt.links.new(t_col.outputs["Color"], bsdf.inputs["Base Color"])
    t_orm = nt.nodes.new("ShaderNodeTexImage")
    t_orm.image = o_img
    t_orm.location = (-800, 0)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    sep.location = (-450, 0)
    nt.links.new(t_orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    t_n = nt.nodes.new("ShaderNodeTexImage")
    t_n.image = n_img
    t_n.location = (-800, -300)
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nmap.location = (-450, -300)
    nt.links.new(t_n.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def flat_material(name, color, metallic=0.0, roughness=0.5):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    return m


def make_materials(tex_dir=None):
    # Oil-finished European walnut, darker and redder than the Bess's.
    MATS["Walnut"] = pbr_material("Walnut", wood_maps(
        (30, 450, 240, 1760), 256, 1024, (0.105, 0.052, 0.028), (0.40, 0.225, 0.115), (0.34, 0.56), 1751), tex_dir)
    MATS["Hickory"] = pbr_material("Hickory", wood_maps(
        (1165, 730, 1330, 2025), 128, 512, (0.30, 0.20, 0.11), (0.60, 0.45, 0.29), (0.5, 0.72), 1752), tex_dir)
    # Browned barrels: a controlled rust finish, deep plum-brown, satin.
    MATS["BrownedIron"] = pbr_material("BrownedIron", metal_maps(
        256, 1024, (0.105, 0.062, 0.042), (0.25, 0.155, 0.10), (0.40, 0.62), 0.7, 1753, speckle=0.6), tex_dir)
    # Bright (filed) iron lock, pan plates and screws.
    MATS["Iron"] = pbr_material("Iron", metal_maps(
        256, 512, (0.30, 0.30, 0.31), (0.52, 0.515, 0.51), (0.30, 0.48), 1.0, 1754), tex_dir)
    MATS["Brass"] = pbr_material("Brass", brass_maps(256, 256, 1755), tex_dir)
    MATS["Flint"] = flat_material("Flint", (0.045, 0.040, 0.036), roughness=0.22)
    MATS["Dark"] = flat_material("Dark", (0.030, 0.020, 0.012), roughness=0.85)


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


def add_empty(name, p, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.03
    bpy.context.scene.collection.objects.link(e)
    if parent is not None:
        e.parent = parent
        e.matrix_parent_inverse = Matrix.Identity(4)
    e.matrix_world = Matrix.Translation(G(p))
    return e


def turn_matrix():
    """180 deg about the swivel axis, in Blender coordinates (Godot Z = Blender -Y)."""
    c = Vector((0.0, 0.0, SWIVEL_Y))
    return Matrix.Translation(c) @ Matrix.Rotation(math.pi, 4, "Y") @ Matrix.Translation(-c)


def parent_keep(obj, parent):
    mw = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_world = mw


def build_over_under(tex_dir=None):
    make_materials(tex_dir)
    straps, bow = build_furniture()
    body = [
        build_stock().build(sharp=50.0),
        build_cheekpiece().build(sharp=60.0),
        build_breech_plate().build(sharp=35.0),
        build_lock_plate().build(sharp=40.0),
        build_side_plate().build(sharp=40.0),
        build_trigger().build(sharp=40.0),
        straps.build(sharp=30.0),
        bow.build(sharp=50.0),
        build_stock_screws().build(sharp=50.0),
    ]
    stock = join(body, "OverUnder")
    cock = join(build_cock(), "Cock", (COCK_X, COCK_PIVOT[1], COCK_PIVOT[0]))
    catch = join([build_catch().build(sharp=40.0)], "Catch", (0.0, CATCH_PIVOT[1], CATCH_PIVOT[0]))

    barrels = bpy.data.objects.new("Barrels", None)
    barrels.empty_display_type = "ARROWS"
    barrels.empty_display_size = 0.05
    bpy.context.scene.collection.objects.link(barrels)
    barrels.location = G((0.0, SWIVEL_Y, Z_BREECH))
    bpy.context.view_layer.update()

    pair = build_barrel_pair()
    pair = join([pair], "BarrelPair", (0.0, SWIVEL_Y, Z_BREECH))
    fa = join([build_frizzen("FrizzenA")], "FrizzenA", (0.030, FRIZZEN_PIVOT[1], FRIZZEN_PIVOT[0]))
    fb = join([build_frizzen("FrizzenB")], "FrizzenB", (0.030, FRIZZEN_PIVOT[1], FRIZZEN_PIVOT[0]))
    bpy.context.view_layer.update()
    fb.matrix_world = turn_matrix() @ fb.matrix_world
    rod = join([build_ramrod()], "Ramrod", (RR_X, SWIVEL_Y, Z_RR_HEAD))
    bpy.context.view_layer.update()
    for o in (pair, fa, fb, rod):
        parent_keep(o, barrels)
    ma = add_empty("MuzzleA", (0.0, AXIS_Y, Z_MUZZLE), barrels)
    mb = add_empty("MuzzleB", turn((0.0, AXIS_Y, Z_MUZZLE)), barrels)
    pa = add_empty("PanA", (XL, PAN_TOP, PAN_Z), barrels)
    pb = add_empty("PanB", turn((XL, PAN_TOP, PAN_Z)), barrels)
    markers = [
        add_empty("Muzzle", (0.0, AXIS_Y, Z_MUZZLE)),
        add_empty("Pan", (XL, PAN_TOP, PAN_Z)),
        add_empty("Muzzle_top", (0.0, AXIS_Y, Z_MUZZLE)),
        add_empty("Muzzle_bottom", turn((0.0, AXIS_Y, Z_MUZZLE))),
        add_empty("Pan_top", (XL, PAN_TOP, PAN_Z)),
        add_empty("Pan_bottom", turn((XL, PAN_TOP, PAN_Z))),
        add_empty("LeftGrip", LEFT_PALM),
    ]
    bpy.context.view_layer.update()
    return [stock, cock, catch, barrels, pair, fa, fb, rod, ma, mb, pa, pb] + markers


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
    """Import the GLB into an empty scene; print node positions / bounds in Godot axes and
    check the contract (names, parents, marker positions)."""
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=path)
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    total = 0
    objs = {o.name: o for o in bpy.context.scene.objects}
    for o in sorted(objs.values(), key=lambda o: o.name):
        g = to_godot(o.matrix_world.translation)
        line = "REIMPORT node %-13s type=%-5s parent=%-8s godot_pos=(%.4f, %.4f, %.4f)" % (
            o.name, o.type, o.parent.name if o.parent else "-", g.x, g.y, g.z)
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
            line += " tris=%d bbox=(%.4f, %.4f, %.4f)-(%.4f, %.4f, %.4f) mats=%s" % (
                t, olo.x, olo.y, olo.z, ohi.x, ohi.y, ohi.z, [m.name for m in o.data.materials])
        print(line)
    print("REIMPORT total tris=%d bbox_min=(%.4f, %.4f, %.4f) bbox_max=(%.4f, %.4f, %.4f) size=(%.4f, %.4f, %.4f)" % (
        total, lo.x, lo.y, lo.z, hi.x, hi.y, hi.z, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z))
    fails = []
    want_parent = {"Barrels": None, "BarrelPair": "Barrels", "FrizzenA": "Barrels", "FrizzenB": "Barrels",
                   "Ramrod": "Barrels", "MuzzleA": "Barrels", "MuzzleB": "Barrels", "PanA": "Barrels",
                   "PanB": "Barrels", "Cock": None, "Catch": None, "OverUnder": None, "Muzzle": None,
                   "Pan": None, "Muzzle_top": None, "Muzzle_bottom": None, "Pan_top": None,
                   "Pan_bottom": None, "LeftGrip": None}
    for name, par in want_parent.items():
        o = objs.get(name)
        if o is None:
            fails.append("missing node " + name)
            continue
        got = o.parent.name if o.parent else None
        if got != par:
            fails.append("%s parent %s, want %s" % (name, got, par))
    want_pos = {"Muzzle": (0.0, AXIS_Y, Z_MUZZLE), "Muzzle_top": (0.0, AXIS_Y, Z_MUZZLE),
                "Muzzle_bottom": (0.0, BOT_Y, Z_MUZZLE), "MuzzleA": (0.0, AXIS_Y, Z_MUZZLE),
                "MuzzleB": (0.0, BOT_Y, Z_MUZZLE), "Pan": (XL, PAN_TOP, PAN_Z),
                "Pan_bottom": turn((XL, PAN_TOP, PAN_Z)), "Barrels": (0.0, SWIVEL_Y, Z_BREECH),
                "LeftGrip": LEFT_PALM, "Cock": (COCK_X, COCK_PIVOT[1], COCK_PIVOT[0]),
                "FrizzenA": (0.030, FRIZZEN_PIVOT[1], FRIZZEN_PIVOT[0]),
                "FrizzenB": turn((0.030, FRIZZEN_PIVOT[1], FRIZZEN_PIVOT[0])),
                "Catch": (0.0, CATCH_PIVOT[1], CATCH_PIVOT[0]),
                "Ramrod": (RR_X, SWIVEL_Y, Z_RR_HEAD)}
    for name, p in want_pos.items():
        o = objs.get(name)
        if o is None:
            continue
        g = to_godot(o.matrix_world.translation)
        if (g - Vector(p)).length > 1e-4:
            fails.append("%s at %s, want %s" % (name, tuple(round(c, 4) for c in g), p))
    fb = objs.get("FrizzenB")
    if fb is not None:
        # Its local rotation is the half turn about the (Godot) Z axis.
        q = fb.matrix_basis.to_quaternion()
        if abs(abs(q.y) - 1.0) > 1e-3:
            fails.append("FrizzenB rotation %s is not a half turn about the barrel axis" % (tuple(q),))
    for f in fails:
        print("REIMPORT FAIL", f)
    print("REIMPORT CONTRACT", "OK" if not fails else "FAILED (%d)" % len(fails))
    return not fails


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
    """Renders of the re-imported GLB: sides, top, three-quarters, lock, muzzle, butt, and the
    barrels half turned (90 deg) and turned over (180 deg)."""
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    try:
        sc.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    sc.view_settings.view_transform = "Standard"
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

    barrels = bpy.data.objects.get("Barrels")
    yc = -(Z_HEEL + Z_MUZZLE) * 0.5
    shots = [
        ("ou_side_right", _camera("c_sr", (2.0, yc, 0.0), (0, yc, 0.0), ortho=1.42), (2400, 700), 0.0),
        ("ou_side_left", _camera("c_sl", (-2.0, yc, 0.0), (0, yc, 0.0), ortho=1.42), (2400, 700), 0.0),
        ("ou_top", _camera("c_top", (0.0, yc, 2.0), rot=(0.0, 0.0, math.radians(90)), ortho=1.42), (2400, 420), 0.0),
        ("ou_3q", _camera("c_3q", (1.55, 0.95, 0.75), (0.0, 0.42, -0.01), lens=40), (1800, 1000), 0.0),
        ("ou_3q_left", _camera("c_3ql", (-1.2, -0.45, 0.72), (0.0, 0.40, -0.01), lens=42), (1800, 1000), 0.0),
        ("ou_lock", _camera("c_lock", (0.22, 0.30, 0.12), (0.02, 0.14, 0.03), lens=50), (1400, 1000), 0.0),
        ("ou_lock_turned", _camera("c_lock2", (0.22, 0.30, 0.12), (0.02, 0.14, 0.03), lens=50), (1400, 1000), 180.0),
        ("ou_lock_halfturn", _camera("c_lock3", (0.22, 0.30, 0.12), (0.02, 0.14, 0.03), lens=50), (1400, 1000), 90.0),
        ("ou_muzzle", _camera("c_muz", (0.10, 1.20, 0.07), (0.0, 1.02, 0.02), lens=50), (1400, 1000), 0.0),
        ("ou_breech_under", _camera("c_under", (0.16, 0.30, -0.16), (0.0, 0.12, 0.0), lens=45), (1400, 1000), 0.0),
        ("ou_butt", _camera("c_butt", (-0.42, -0.45, 0.02), (0.0, -0.12, -0.04), lens=35), (1400, 1000), 0.0),
    ]
    for name, cam, (w, h), ang in shots:
        if barrels is not None:
            barrels.rotation_mode = "XYZ"
            barrels.rotation_euler = (0.0, math.radians(ang), 0.0)
        sc.camera = cam
        sc.render.resolution_x = w
        sc.render.resolution_y = h
        sc.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)
    if barrels is not None:
        barrels.rotation_euler = (0.0, 0.0, 0.0)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(PROJECT, "assets", "weapons", "over_under.glb"))
    ap.add_argument("--renders", default=None, help="re-import the GLB and render previews here")
    ap.add_argument("--blend", default=None)
    ap.add_argument("--tex-dir", default=None, help="also write the generated textures here")
    args = ap.parse_args(argv)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    objs = build_over_under(args.tex_dir)
    total = 0
    for o in objs:
        if o.type == "MESH":
            t = tri_count(o)
            total += t
            print("OVERUNDER %-10s tris=%d verts=%d mats=%s" % (o.name, t, len(o.data.vertices),
                                                               [m.name for m in o.data.materials]))
    print("OVERUNDER total tris", total)
    export_glb(objs, args.out)
    print("EXPORTED", args.out, os.path.getsize(args.out), "bytes")
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    ok = reimport_report(args.out)
    if args.renders:
        render_previews(args.renders)
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
