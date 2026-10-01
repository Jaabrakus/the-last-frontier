"""Procedural mid-18th-century infantry hanger (the game's "saber"), after the
British Pattern 1751 infantry hanger carried in the Seven Years' War: a one-piece
cast brass hilt (spirally fluted grip, globular pommel with a button for the
peened tang, D-shaped knuckle bow with two side bars, heart-shaped dish guard,
short rear quillon with a ball finial) on a slightly curved, single-edged steel
blade with one narrow fuller along the back, plus its scabbard: black leather
with a brass locket carrying a baluster frog stud, and a brass chape with a
ball drag.

Run headless (factory scene):
  Blender -b --factory-startup --python tools/models/saber.py -- \
      [--out assets/weapons/saber.glb] [--renders DIR] [--blend FILE.blend] \
      [--hand-check source/blender_libraries]   (needs --renders)

Dimensions (the 1751 pattern: blade 24 3/4-25 3/4 in, overall about 31-31.5 in):
  blade 0.652 m visible (25.7 in) from the quillon block to the point, spine
  6.2 mm at the forte, 33 mm wide, sagitta 14 mm (the point sits 59 mm below
  the grip line); fuller about 4/5 of the blade; grip 82 mm; overall 0.780 m;
  about 0.76 kg with the hilt cast hollow, balance 13 cm in front of the guard.

Conventions (Godot / glTF axes). Like the musket and pistol, the blade faces -Z:
  * origin = centre of the grip, where the fist closes (the middle of the four
    finger wraps measured on Actor_B's knife grip, see below)
  * forward = -Z: the blade runs from the quillon block (z = -0.051) to the
    point (z = -0.702); the pommel button is at z = +0.078
  * up = +Y = the cutting EDGE; the back of the blade (spine, fuller) is -Y.
    The knuckle bow is on the edge side (+Y); the rear quillon on the back (-Y).
    The blade's flat faces look along +/-X. It curves toward -Y (the edge is
    the convex side, as on any saber).
  * markers (empties, children of the "Saber" mesh): Tip (the point), Muzzle
    (same point, for loaders that need a Muzzle), BladeBase (blade centre where
    it leaves the quillon block), COM (balance point, computed from the part
    volumes with brass 8.5 and steel 7.85 g/cm3), Pommel (top of the button)
  * a second top-level mesh "Scabbard" (plus markers Throat, FrogStud, ChapeEnd)
    is modelled around the blade in the sheathed position, in the same
    coordinates: show both meshes for a sheathed sword, only "Saber" in the hand
    and only "Scabbard" on the belt once it is drawn. The frog stud is on the
    -X face (the outside when the sword hangs on the left hip edge-forward).

Holding it (measured, not guessed): Actor_B's knife clips key the prop bone so
that the source knife blade runs along the prop bone's +Y. Fitting circles through
each finger's MCP/PIP/DIP joints in atk-actor_b-knife-v-thug-* (Actor_B_001.blend)
gives a grip tunnel along prop (+0.105, +0.994, -0.022), centred at prop
(+0.006, +0.006, -0.006), with the proximal phalanges (where a knuckle bow sits)
toward prop (+0.33, -0.06, -0.94). So, attached to a BoneAttachment3D on
r_hand_prop_attachment (Godot's bone frame equals Blender's here; checked), the
model needs
  SABER_PROP_OFFSET = Transform3D(Basis(Vector3(-0.9397, 0.0915, -0.3295),
      Vector3(0.3256, -0.0551, -0.9439), Vector3(-0.1045, -0.9943, 0.0220)),
      Vector3(0.0057, 0.0059, -0.0060))
(model -Z along prop +Y, model +Y along the finger side). This is NOT the
half-turn the firearms use: the knife clips do not point prop -Z/+Z along the
blade. actor_b-p-knife--fingers keys the prop bone about 140 deg differently
about the blade; see the saber doc in graph_analysis/melee_horse_prone.

Blender works Z-up and the glTF exporter maps Blender (x, y, z) to glTF
(x, z, -y), so everything is built through G(x, y, z) with Godot coordinates.
Textures: one generated atlas (steel, brass, black leather), with the grain of
the CC0 Poly Haven brown_leather texture when present (read only).
"""

import argparse
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

# --------------------------------------------------------------------------
# Dimensions (metres, Godot model axes)
# --------------------------------------------------------------------------
GRIP_TOP = 0.042            # grip end at the pommel
GRIP_BOT = -0.040           # grip end at the dish guard
DISH_TOP = -0.0405          # top of the dish plate at the grip
DISH_T = 0.0026             # dish thickness
DISH_DROP = 0.0028          # rim turned down toward the blade
DISH_C = (0.0, 0.0045)      # heart centre (x, y)
BLOCK = (-0.0428, -0.0510)  # quillon block (z top, z bottom)
BLADE_Z0 = -0.046           # blade shoulder (s = 0), inside the block
BLADE_OUT = 0.005           # s where the blade leaves the block
BLADE_L = 0.656             # s of the point (along the grip axis)
SAGITTA = 0.014             # blade curve (parabola) over its length
K_CURVE = 4.0 * SAGITTA / (BLADE_L * BLADE_L)
BACK_Y0 = -0.0115           # spine at the shoulder
POINT_L = 0.095             # length of the point section
POINT_S = BLADE_L - POINT_L
FULLER_END = 0.530
FULLER_DEPTH = 0.0011
WIDTH = [(0.0, 0.0330), (0.06, 0.0325), (0.30, 0.0300), (0.50, 0.0283), (POINT_S, 0.0276)]
THICK = [(0.0, 0.0062), (0.10, 0.0056), (0.35, 0.0047), (0.50, 0.0041), (POINT_S, 0.0034)]
TIP_THICK = 0.0009
TIP_H = 0.30                # point height above the spine line, fraction of width

POMMEL = [  # lathe (r, z) around the grip axis, bottom to top
    (0.0100, 0.0405), (0.0114, 0.0428), (0.0110, 0.0460), (0.0129, 0.0490),
    (0.0150, 0.0528), (0.0163, 0.0572), (0.0165, 0.0610), (0.0155, 0.0646),
    (0.0128, 0.0678), (0.0092, 0.0700), (0.0068, 0.0710), (0.0063, 0.0714),
    (0.0063, 0.0744), (0.0055, 0.0763), (0.0032, 0.0776), (0.0010, 0.0780)]
POMMEL_SX = 0.92            # pommel slightly flattened across the blade plane

BOW = [  # knuckle bow centre line (y, z) in the blade plane x = 0
    (0.0300, -0.0446), (0.0385, -0.0335), (0.0432, -0.0160), (0.0444, 0.0060),
    (0.0415, 0.0290), (0.0330, 0.0490), (0.0215, 0.0600), (0.0120, 0.0640)]
SIDEBAR = [  # one side bar (x, y, z), mirrored in x
    (0.000, 0.0392, -0.0326), (0.010, 0.0382, -0.0347), (0.0185, 0.0300, -0.0382),
    (0.0232, 0.0172, -0.0410), (0.0245, 0.0065, -0.0426)]
QUILLON = [(0.0, -0.0135, -0.0470), (0.0, -0.0222, -0.0488), (0.0, -0.0298, -0.0526), (0.0, -0.0342, -0.0584)]
QUILLON_BALL = (0.0, -0.0352, -0.0612, 0.0040)

# Scabbard
SCAB_CLEAR = 0.0028         # leather + clearance round the blade section
LOCKET = (0.0055, 0.090)    # s range of the brass locket
CHAPE_L = 0.062
SCAB_END = BLADE_L + 0.016
STUD_S = 0.050

ATLAS = 512
UV_STEEL = (0.0, 1.0, 0.5, 1.0)
UV_BRASS = (0.0, 0.5, 0.25, 0.5)
UV_GRIP = (0.0, 0.5, 0.0, 0.25)
UV_LEATHER = (0.5, 1.0, 0.0, 0.5)
MAT_STEEL, MAT_BRASS, MAT_LEATHER = 0, 1, 2
RHO_STEEL, RHO_BRASS = 7850.0, 8500.0
# The one-piece hilt is cast hollow round the iron tang: effective densities for the
# balance estimate (about a 3 mm wall plus the tang in the grip and pommel).
RHO_GRIP, RHO_POMMEL = 0.45 * RHO_BRASS, 0.55 * RHO_BRASS
GRIP_N, FLUTES, TWIST, FLUTE_AMP = 40, 8, 0.9, 0.14
GRIP_BAND = 0.0055

# Attachment measured on Actor_B's knife attack grip (see the docstring).
SABER_PROP_OFFSET = ((-0.9397, 0.0915, -0.3295), (0.3256, -0.0551, -0.9439),
                     (-0.1045, -0.9943, 0.0220), (0.0057, 0.0059, -0.0060))
# The same measurement for actor_b-p-knife--fingers (the knife carry grip layer).
SABER_PROP_OFFSET_CARRY = ((0.6191, 0.1258, 0.7751), (-0.7669, 0.3092, 0.5624),
                           (-0.1689, -0.9426, 0.2879), (-0.0049, -0.0133, -0.0021))

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
POLYHAVEN = os.path.join(PROJECT, "assets", "polyhaven", "textures")


def G(x, y, z):
    """Godot-space point expressed in Blender coordinates."""
    return Vector((x, -z, y))


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def interp(table, x):
    if x <= table[0][0]:
        return table[0][1]
    for a, c in zip(table, table[1:]):
        if x <= c[0]:
            return lerp(a[1], c[1], (x - a[0]) / (c[0] - a[0]))
    return table[-1][1]


def catmull(points, per_seg=6):
    """Uniform Catmull-Rom through `points` (tuples), endpoints included."""
    P = [Vector(p) for p in points]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(per_seg):
            t = k / per_seg
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-2].copy())
    return out


class MassAcc:
    """Accumulates volume-weighted centroids of the lofted parts."""
    def __init__(self):
        self.m = 0.0
        self.mc = Vector()
        self.parts = {}

    def add(self, name, mass, centroid):
        self.m += mass
        self.mc += centroid * mass
        self.parts[name] = self.parts.get(name, 0.0) + mass

    def com(self):
        return self.mc / max(self.m, 1e-9)


class Builder:
    def __init__(self, mass=None):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mass = mass

    def face(self, verts, uvs, mat, smooth, out):
        n = Vector()
        for i, a in enumerate(verts):
            b = verts[(i + 1) % len(verts)]
            n.x += (a.co.y - b.co.y) * (a.co.z + b.co.z)
            n.y += (a.co.z - b.co.z) * (a.co.x + b.co.x)
            n.z += (a.co.x - b.co.x) * (a.co.y + b.co.y)
        if n.dot(out) < 0.0:
            verts = list(reversed(verts))
            uvs = list(reversed(uvs))
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        f.material_index = mat
        f.smooth = smooth
        for loop, t in zip(f.loops, uvs):
            loop[self.uv].uv = t
        return f

    def loft(self, stations, uv_rect, mat, smooth=True, cap0=False, cap1=False, outs=None,
             density=None, part=None):
        """stations: [(centre Godot Vector, [ring points Godot Vector])]; rings have equal
        size. U runs along the stations (by length), V around the ring. `outs`, if given,
        is a callable (i, j) -> outward Godot vector for the quad (else centre -> quad).
        With `density`, the solid's mass and centroid go to self.mass (rings must be planar
        cross-sections)."""
        rings = [[self.bm.verts.new(G(*p)) for p in pts] for _, pts in stations]
        n = len(stations[0][1])
        lengths = [0.0]
        for i in range(1, len(stations)):
            lengths.append(lengths[-1] + (stations[i][0] - stations[i - 1][0]).length)
        total = max(lengths[-1], 1e-6)
        m = 2.0 / ATLAS
        u0, u1, v0, v1 = uv_rect
        u0, u1, v0, v1 = u0 + m, u1 - m, v0 + m, v1 - m
        for i in range(len(stations) - 1):
            ua = lerp(u0, u1, lengths[i] / total)
            ub = lerp(u0, u1, lengths[i + 1] / total)
            c = (stations[i][0] + stations[i + 1][0]) * 0.5
            for j in range(n):
                k = (j + 1) % n
                va = lerp(v0, v1, j / n)
                vb = lerp(v0, v1, (j + 1) / n)
                if outs:
                    o = outs(i, j)
                else:
                    mid = (stations[i][1][j] + stations[i][1][k] + stations[i + 1][1][j] + stations[i + 1][1][k]) * 0.25
                    o = mid - c
                self.face([rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]],
                          [(ua, va), (ua, vb), (ub, vb), (ub, va)], mat, smooth, G(*o) - G(0, 0, 0))
        for cap, idx in ((cap0, 0), (cap1, -1)):
            if not cap:
                continue
            ring = rings[idx]
            c = stations[idx][0]
            other = stations[1 if idx == 0 else -2][0]
            cu, cv = lerp(u0, u1, 0.02 if idx == 0 else 0.98), (v0 + v1) * 0.5
            uvs = [(cu + 0.01 * math.cos(2 * math.pi * j / n), cv + 0.02 * math.sin(2 * math.pi * j / n)) for j in range(n)]
            self.face(ring, uvs, mat, False, G(*(c - other)) - G(0, 0, 0))
        if density and self.mass is not None:
            self._mass(stations, density, part or "part")
        return rings

    def _mass(self, stations, density, part):
        areas, cents, norms = [], [], []
        for _, pts in stations:
            nv = Vector()
            for i, a in enumerate(pts):
                nv += a.cross(pts[(i + 1) % len(pts)])
            areas.append(nv.length * 0.5)
            norms.append(nv.normalized() if nv.length > 1e-12 else Vector((0, 0, 1)))
            cents.append(sum(pts, Vector()) / len(pts))
        for i in range(len(stations) - 1):
            h = abs((cents[i + 1] - cents[i]).dot(norms[i]))
            if h < 1e-9:
                h = (cents[i + 1] - cents[i]).length
            vol = 0.5 * (areas[i] + areas[i + 1]) * h
            self.mass.add(part, vol * density, (cents[i] + cents[i + 1]) * 0.5)

    def fan(self, ring_verts, apex, uv_rect, mat, smooth, centre):
        """Closes a ring onto one apex vertex (Godot point)."""
        tip = self.bm.verts.new(G(*apex))
        n = len(ring_verts)
        u0, u1, v0, v1 = uv_rect
        for j in range(n):
            k = (j + 1) % n
            a, b = ring_verts[j], ring_verts[k]
            mid = (Vector(a.co) + Vector(b.co)) * 0.5
            out = (mid - G(*centre)) + (G(*apex) - G(*centre)) * 0.3
            self.face([a, b, tip], [(u1 - 0.004, lerp(v0, v1, j / n)), (u1 - 0.004, lerp(v0, v1, (j + 1) / n)), (u1 - 0.002, (v0 + v1) / 2)], mat, smooth, out)
        return tip

    def mesh(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        me.validate()
        return me


def lathe(b, profile, mat, uv_rect, axis_o, axis_d, perp, n=24, sx=1.0, cap0=False, cap1=False,
          density=None, part=None):
    """Surface of revolution: profile [(r, h)] from bottom to top round the outside;
    axis_o + h * axis_d is the axis, `perp` a unit vector across it (scaled by sx)."""
    ad = Vector(axis_d).normalized()
    p1 = Vector(perp).normalized()
    p2 = ad.cross(p1)
    st = []
    for r, h in profile:
        c = Vector(axis_o) + ad * h
        st.append((c, [c + p1 * (r * sx * math.cos(2 * math.pi * j / n)) + p2 * (r * math.sin(2 * math.pi * j / n)) for j in range(n)]))

    def outs(i, j):
        (ra, ha), (rc, hc) = profile[i], profile[i + 1]
        dr, dh = rc - ra, hc - ha
        a = 2 * math.pi * (j + 0.5) / n
        radial = p1 * math.cos(a) + p2 * math.sin(a)
        return radial * dh - ad * dr
    return b.loft(st, uv_rect, mat, outs=outs, cap0=cap0, cap1=cap1, density=density, part=part)


def sweep(b, path, radii, mat, uv_rect, n=12, binormal=None, cap0=True, cap1=True, density=None, part=None):
    """Tube along `path` (Godot Vectors). radii(t) -> (a, c): half-size along the
    binormal (constant `binormal` projected, else parallel transport) and across it."""
    st = []
    prev_b = None
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        if binormal is not None:
            bn = Vector(binormal) - t * t.dot(Vector(binormal))
        elif prev_b is None:
            ref = Vector((1, 0, 0)) if abs(t.x) < 0.9 else Vector((0, 1, 0))
            bn = ref - t * t.dot(ref)
        else:
            bn = prev_b - t * t.dot(prev_b)
        bn.normalize()
        prev_b = bn
        nm = t.cross(bn)
        a, c = radii(i / (len(path) - 1))
        st.append((p, [p + bn * (a * math.cos(2 * math.pi * j / n)) + nm * (c * math.sin(2 * math.pi * j / n)) for j in range(n)]))
    return b.loft(st, uv_rect, mat, cap0=cap0, cap1=cap1, density=density, part=part)


# --------------------------------------------------------------------------
# Blade
# --------------------------------------------------------------------------
def blade_frame(s):
    """Spine-line point, unit tangent (toward the point) and unit normal (toward the
    edge) of the curved blade at s (distance along the grip axis from the shoulder)."""
    y = BACK_Y0 - K_CURVE * s * s
    dy = -2.0 * K_CURVE * s
    c = Vector((0.0, y, BLADE_Z0 - s))
    t = Vector((0.0, dy, -1.0)).normalized()
    nrm = Vector((0.0, 1.0, dy)).normalized()
    return c, t, nrm


def blade_section(s):
    """(back offset, edge offset, spine thickness, fuller depth) along the normal."""
    if s <= POINT_S:
        w = interp(WIDTH, s)
        th = interp(THICK, s)
        back, edge = 0.0, w
    else:
        t = (s - POINT_S) / POINT_L
        wp = interp(WIDTH, POINT_S)
        h = TIP_H * wp
        back = h * t ** 2.2
        edge = h + (wp - h) * math.cos(t * math.pi / 2)
        th = lerp(interp(THICK, POINT_S), TIP_THICK, t)
    fd = FULLER_DEPTH * smoothstep(0.0, 0.010, s) * (1.0 - smoothstep(FULLER_END - 0.035, FULLER_END, s))
    return back, edge, th, fd


def blade_ring(s):
    back, edge, th, fd = blade_section(s)
    span = edge - back
    hb = th * 0.5
    o = 0.0006 * min(1.0, span / 0.02)   # keeps the fuller clear of the rounded back
    right = [
        (0.55 * hb, back),
        (hb, back + min(0.0030, 0.12 * span)),
        (hb * 0.97, back + 0.10 * span + o),
        (hb * 0.96 - fd, back + 0.15 * span + o),
        (hb * 0.94 - fd, back + 0.25 * span + o),
        (hb * 0.93, back + 0.30 * span + o),
        (hb * 0.72, back + 0.66 * span),
    ]
    pts2 = right + [(0.0, edge)] + [(-x, v) for x, v in reversed(right)]
    c, t, nrm = blade_frame(s)
    xa = Vector((1.0, 0.0, 0.0))
    ring = [c + xa * x + nrm * v for x, v in pts2]
    centre = sum(ring, Vector()) / len(ring)
    return centre, ring


def build_blade(b):
    ss = [0.0, 0.004, 0.012, 0.03, 0.06, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45,
          0.48, 0.505, 0.525, 0.545]
    ss = [s for s in ss if s < POINT_S - 1e-4] + [POINT_S]
    ss += [POINT_S + POINT_L * t for t in (0.12, 0.25, 0.38, 0.50, 0.62, 0.73, 0.83, 0.91, 0.965)]
    st = [blade_ring(s) for s in ss]
    rings = b.loft(st, UV_STEEL, MAT_STEEL, smooth=False, cap0=True, density=RHO_STEEL, part="blade")
    c, t, nrm = blade_frame(BLADE_L)
    back, edge, th, fd = blade_section(BLADE_L)
    tip = c + nrm * back
    b.fan(rings[-1], tip, UV_STEEL, MAT_STEEL, False, st[-1][0])
    return tip


# --------------------------------------------------------------------------
# Hilt
# --------------------------------------------------------------------------
def flute(a, tf):
    """Spiral groove depth (0..1) at angle a round the grip and fluted fraction tf."""
    fade = smoothstep(0.0, 0.05, tf) * (1.0 - smoothstep(0.95, 1.0, tf))
    return max(0.0, math.cos(FLUTES * a + 2 * math.pi * TWIST * tf)) ** 3 * fade


def flute_span():
    return GRIP_BOT + GRIP_BAND + 0.0008, GRIP_TOP - GRIP_BAND - 0.0008


def build_grip(b):
    n = GRIP_N
    band = GRIP_BAND
    zs = [GRIP_BOT, GRIP_BOT + 0.0012, GRIP_BOT + band - 0.0010, GRIP_BOT + band]
    f0, f1 = flute_span()
    zs += [lerp(f0, f1, k / 23) for k in range(24)]
    zs += [GRIP_TOP - band, GRIP_TOP - band + 0.0010, GRIP_TOP - 0.0012, GRIP_TOP]
    st = []
    for z in zs:
        t = (z - GRIP_BOT) / (GRIP_TOP - GRIP_BOT)
        sw = math.sin(math.pi * t) ** 0.8
        ry = lerp(0.0112, 0.0126, sw)
        rx = lerp(0.0094, 0.0105, sw)
        in_band = z < GRIP_BOT + band + 1e-6 or z > GRIP_TOP - band - 1e-6
        edge_bev = z in (GRIP_BOT, GRIP_TOP)
        pts = []
        for j in range(n):
            a = 2 * math.pi * j / n
            if in_band:
                f = 1.035 if not edge_bev else 0.985
            else:
                f = 1.0 + 0.02 - FLUTE_AMP * flute(a, (z - f0) / (f1 - f0))
            pts.append(Vector((rx * f * math.cos(a), ry * f * math.sin(a), z)))
        st.append((Vector((0, 0, z)), pts))
    b.loft(st, UV_GRIP, MAT_BRASS, smooth=True, density=RHO_GRIP, part="grip")


def build_pommel(b):
    lathe(b, POMMEL, MAT_BRASS, UV_BRASS, (0, 0, 0), (0, 0, 1), (1, 0, 0), n=20, sx=POMMEL_SX,
          cap1=True, density=RHO_POMMEL, part="pommel")


def heart(n=48):
    """Heart outline, point toward +Y (the knuckle bow), lobes toward -Y; notch softened."""
    pts = []
    for j in range(n):
        t = 2 * math.pi * j / n
        hx = 16 * math.sin(t) ** 3
        hy = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        hy += 4.5 * max(math.cos(t), 0.0) ** 8
        pts.append((hx * 0.00166 + DISH_C[0], -hy * 0.00172 + DISH_C[1]))
    return pts


def build_dish(b):
    outline = heart()
    cx, cy = DISH_C[0], DISH_C[1] + 0.004
    scales = [1.0, 0.985, 0.8, 0.6, 0.4, 0.2]
    n = len(outline)
    u0, u1, v0, v1 = UV_BRASS

    def ztop(sc):
        return DISH_TOP - DISH_DROP * sc * sc

    tops, bots = [], []
    for k, sc in enumerate(scales):
        zt = ztop(sc) + (0.0006 if k == 1 else 0.0)   # a slight raised rim
        tops.append([b.bm.verts.new(G(cx + (x - cx) * sc, cy + (y - cy) * sc, zt)) for x, y in outline])
        bots.append([b.bm.verts.new(G(cx + (x - cx) * sc, cy + (y - cy) * sc, ztop(sc) - DISH_T)) for x, y in outline])
    ct = b.bm.verts.new(G(cx, cy, DISH_TOP))
    cb = b.bm.verts.new(G(cx, cy, DISH_TOP - DISH_T))

    def uv(x, y):
        return (lerp(u0, u1, 0.5 + (x - cx) / 0.09), lerp(v0, v1, 0.5 + (y - cy) / 0.09))
    gup, gdown = G(0, 0, 1) - G(0, 0, 0), G(0, 0, -1) - G(0, 0, 0)
    for rings, centre, out in ((tops, ct, gup), (bots, cb, gdown)):
        for k in range(len(scales) - 1):
            ra, rb = rings[k], rings[k + 1]
            for j in range(n):
                i2 = (j + 1) % n
                vs = [ra[j], ra[i2], rb[i2], rb[j]]
                b.face(vs, [uv(v.co.x, v.co.z) for v in vs], MAT_BRASS, True, out)
        last = rings[-1]
        for j in range(n):
            i2 = (j + 1) % n
            vs = [last[j], last[i2], centre]
            b.face(vs, [uv(v.co.x, v.co.z) for v in vs], MAT_BRASS, True, out)
    # rim side
    for j in range(n):
        i2 = (j + 1) % n
        x0, y0 = outline[j]
        x1, y1 = outline[i2]
        o = G((x0 + x1) / 2 - cx, (y0 + y1) / 2 - cy, 0) - G(0, 0, 0)
        vs = [tops[0][j], tops[0][i2], bots[0][i2], bots[0][j]]
        b.face(vs, [uv(v.co.x, v.co.z) for v in vs], MAT_BRASS, False, o)
    # mass: heart area x thickness
    area = 0.0
    for j in range(n):
        x0, y0 = outline[j]
        x1, y1 = outline[(j + 1) % n]
        area += x0 * y1 - x1 * y0
    area = abs(area) * 0.5
    if b.mass is not None:
        b.mass.add("dish", area * DISH_T * RHO_BRASS, Vector((cx, cy, DISH_TOP - DISH_DROP * 0.5 - DISH_T * 0.5)))


def build_block(b):
    """Quillon block (ecusson) under the dish, hugging the blade shoulder."""
    def rrect(y0, y1, hx, z, r=0.0022, n_c=4):
        pts = []
        cy = (y0 + y1) / 2
        hy = (y1 - y0) / 2
        for qx, qy, a0 in ((1, 1, 0.0), (-1, 1, 90.0), (-1, -1, 180.0), (1, -1, 270.0)):
            ccx = qx * (hx - r)
            ccy = cy + qy * (hy - r)
            for k in range(n_c):
                a = math.radians(a0 + 90.0 * k / (n_c - 1))
                pts.append(Vector((ccx + r * math.cos(a), ccy + r * math.sin(a), z)))
        return pts
    z0, z1 = BLOCK
    st = []
    for z, y0, y1, hx in ((z0, -0.0150, 0.0215, 0.0068), (lerp(z0, z1, 0.5), -0.0146, 0.0212, 0.0064),
                          (z1 + 0.0012, -0.0136, 0.0207, 0.0056), (z1, -0.0130, 0.0203, 0.0050)):
        st.append((Vector((0, (y0 + y1) / 2, z)), rrect(y0, y1, hx, z)))
    b.loft(st, UV_BRASS, MAT_BRASS, smooth=False, cap0=True, cap1=True, density=RHO_BRASS, part="block")


def build_guards(b):
    # Knuckle bow: flat bar, widest (the small flare) where it meets the pommel.
    path = [Vector((0.0, y, z)) for y, z in BOW]
    path = catmull([tuple(p) for p in path], per_seg=4)

    def bow_r(t):
        w = 0.0038 + 0.0012 * smoothstep(0.78, 1.0, t) + 0.0004 * smoothstep(0.0, 0.12, 1 - t)
        return (w, 0.0025)
    sweep(b, path, bow_r, MAT_BRASS, UV_BRASS, n=10, binormal=(1, 0, 0), density=RHO_BRASS, part="knuckle_bow")
    # Two side bars from the bow to the dish rim.
    for sgn in (1.0, -1.0):
        pts = [(sgn * x, y, z) for x, y, z in SIDEBAR]
        path = catmull(pts, per_seg=3)
        sweep(b, path, lambda t: (0.0022 - 0.0003 * t, 0.0020 - 0.0002 * t), MAT_BRASS, UV_BRASS, n=8,
              density=RHO_BRASS, part="side_bars")
    # Rear quillon with a ball finial, swept toward the point.
    path = catmull(QUILLON, per_seg=4)
    sweep(b, path, lambda t: (0.0030 - 0.0007 * t, 0.0028 - 0.0006 * t), MAT_BRASS, UV_BRASS, n=10,
          binormal=(1, 0, 0), density=RHO_BRASS, part="quillon")
    x, y, z, r = QUILLON_BALL
    prof = [(r * math.sin(math.pi * k / 8) + 1e-4, -r * math.cos(math.pi * k / 8)) for k in range(9)]
    lathe(b, prof, MAT_BRASS, UV_BRASS, (x, y, z), (0, -0.45, -1.0), (1, 0, 0), n=12,
          cap0=True, cap1=True, density=RHO_BRASS, part="quillon")


# --------------------------------------------------------------------------
# Scabbard
# --------------------------------------------------------------------------
def scab_ring(s, grow=0.0, n=16):
    """Superellipse round the blade section at s (unclipped point widths)."""
    s_eff = min(s, BLADE_L)
    if s_eff <= POINT_S:
        back, edge, th, _ = blade_section(s_eff)
    else:
        back, edge, th = 0.0, interp(WIDTH, POINT_S), interp(THICK, POINT_S)
    c, t, nrm = blade_frame(s)
    vc = (back + edge) * 0.5
    hv = (edge - back) * 0.5 + SCAB_CLEAR + grow
    hx = max(th * 0.5 + SCAB_CLEAR * 0.95, 0.0034) + grow
    if s > BLADE_L - 0.03:  # round the end past the point
        k = (s - (BLADE_L - 0.03)) / (SCAB_END - (BLADE_L - 0.03))
        f = math.sqrt(max(1.0 - k ** 2.2, 0.0)) * 0.85 + 0.15
        hv *= f
        hx *= lerp(1.0, 0.8, k)
        vc -= 0.003 * k          # the end follows the point, which lies near the back
    xa = Vector((1.0, 0.0, 0.0))
    e = 2.6
    pts = []
    for j in range(n):
        a = 2 * math.pi * j / n
        ca, sa = math.cos(a), math.sin(a)
        px = math.copysign(abs(ca) ** (2 / e), ca) * hx
        pv = math.copysign(abs(sa) ** (2 / e), sa) * hv
        pts.append(c + xa * px + nrm * (vc + pv))
    return c + nrm * vc, pts


def build_scabbard(b):
    # Leather body (runs on under both fittings).
    ss = [LOCKET[0] + 0.004] + [lerp(0.02, SCAB_END - 0.012, k / 15) for k in range(16)] + [SCAB_END - 0.006]
    st = [scab_ring(s) for s in ss]
    b.loft(st, UV_LEATHER, MAT_LEATHER, smooth=True, cap0=True, cap1=True)
    # Brass locket: raised top band and a lower bead.
    s0, s1 = LOCKET
    prof = [(s0, 0.0006), (s0 + 0.0008, 0.0016), (s0 + 0.0060, 0.0016), (s0 + 0.0068, 0.0009),
            (s1 - 0.0070, 0.0009), (s1 - 0.0062, 0.0015), (s1 - 0.0010, 0.0015), (s1, 0.0004)]
    st = [scab_ring(s, g) for s, g in prof]
    b.loft(st, UV_BRASS, MAT_BRASS, smooth=True, cap0=True)
    # The throat: a dark slot where the blade enters.
    c, t, nrm = blade_frame(s0)
    back, edge, th, _ = blade_section(s0)
    zup = -t * 0.0003
    xa = Vector((1, 0, 0))
    slot = [c + zup + xa * (th * 0.6) + nrm * (back - 0.0008), c + zup + xa * (-th * 0.6) + nrm * (back - 0.0008),
            c + zup + xa * (-th * 0.6) + nrm * (edge + 0.0008), c + zup + xa * (th * 0.6) + nrm * (edge + 0.0008)]
    vs = [b.bm.verts.new(G(*p)) for p in slot]
    u0, u1, v0, v1 = UV_LEATHER
    b.face(vs, [(u0 + 0.01, v0 + 0.01), (u0 + 0.02, v0 + 0.01), (u0 + 0.02, v0 + 0.02), (u0 + 0.01, v0 + 0.02)],
           MAT_LEATHER, False, G(*(-t)) - G(0, 0, 0))
    # Baluster frog stud on the -X face of the locket.
    c, t, nrm = blade_frame(STUD_S)
    back, edge, th, _ = blade_section(STUD_S)
    hx = max(th * 0.5 + SCAB_CLEAR * 0.95, 0.0034) + 0.0016
    base = c + nrm * ((back + edge) * 0.5) + Vector((-(hx - 0.0008), 0, 0))
    stud = [(0.0058, 0.0), (0.0060, 0.0011), (0.0034, 0.0023), (0.0042, 0.0037), (0.0045, 0.0051),
            (0.0030, 0.0063), (0.0010, 0.0067)]
    lathe(b, stud, MAT_BRASS, UV_BRASS, base, (-1, 0, 0), (0, 0, 1), n=14, cap0=True, cap1=True)
    stud_tip = base + Vector((-0.0067, 0, 0))
    # Brass chape with a top band and a ball drag at the end.
    c0 = SCAB_END - CHAPE_L
    prof = [(c0, 0.0005), (c0 + 0.0008, 0.0016), (c0 + 0.0055, 0.0016), (c0 + 0.0062, 0.0010)]
    prof += [(lerp(c0 + 0.008, SCAB_END - 0.004, k / 3), 0.0010) for k in range(4)]
    prof += [(SCAB_END - 0.0015, 0.0006)]
    st = [scab_ring(s, g) for s, g in prof]
    b.loft(st, UV_BRASS, MAT_BRASS, smooth=True, cap1=True)
    ce, te, ne = blade_frame(SCAB_END)
    end_c = st[-1][0]
    r = 0.0046
    ball_c = end_c + te * (r * 0.55)
    prof = [(r * math.sin(math.pi * k / 8) + 1e-4, -r * math.cos(math.pi * k / 8)) for k in range(9)]
    lathe(b, prof, MAT_BRASS, UV_BRASS, ball_c, te, (1, 0, 0), n=12, cap0=True, cap1=True)
    c_s0 = blade_frame(s0)
    b0, e0, _, _ = blade_section(s0)
    throat = c_s0[0] + c_s0[2] * ((b0 + e0) * 0.5)
    return throat, stud_tip, ball_c + te * r


# --------------------------------------------------------------------------
# Textures
# --------------------------------------------------------------------------
def _noise(h, w, seed, scale_y, scale_x=None):
    scale_x = scale_x or scale_y
    rng = np.random.default_rng(seed)
    small = rng.random((max(h // scale_y, 2), max(w // scale_x, 2)))
    ys = np.linspace(0, small.shape[0] - 1, h)
    xs = np.linspace(0, small.shape[1] - 1, w)
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    y1 = np.minimum(y0 + 1, small.shape[0] - 1)
    x1 = np.minimum(x0 + 1, small.shape[1] - 1)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    a = small[y0][:, x0] * (1 - fx) + small[y0][:, x1] * fx
    c = small[y1][:, x0] * (1 - fx) + small[y1][:, x1] * fx
    return a * (1 - fy) + c * fy


def _polyhaven(rel, size):
    path = os.path.join(POLYHAVEN, rel)
    if not os.path.exists(path):
        return None
    img = bpy.data.images.load(path)
    img.scale(size, size)
    px = np.empty(size * size * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(size, size, 4)[:, :, :3]


def region(rect):
    u0, u1, v0, v1 = rect
    return slice(int(v0 * ATLAS), int(v1 * ATLAS)), slice(int(u0 * ATLAS), int(u1 * ATLAS))


def make_atlas():
    H = W = ATLAS
    img = np.zeros((H, W, 3), dtype=np.float32)
    # Steel: U along the blade, V round the 15-point section (edge bevel at V ~ 0.40-0.53,
    # fuller at V ~ 0.13-0.27 and 0.73-0.87). Fine lengthwise polishing streaks, soft
    # grey patina clouds, a brighter honed edge bevel, a slightly darker fuller and forte.
    ys, xs = region(UV_STEEL)
    h, w = ys.stop - ys.start, xs.stop - xs.start
    v = np.linspace(0, 1, h)[:, None]
    u = np.linspace(0, 1, w)[None, :]
    streak = 0.6 * _noise(h, w, 21, 1, 40) + 0.4 * _noise(h, w, 27, 2, 12)
    cloud = _noise(h, w, 22, 16, 48)
    base = 0.58 + 0.06 * (streak - 0.5) - 0.10 * np.clip((cloud - 0.45) * 2.0, 0.0, 1.0)
    edge = np.clip(1.0 - np.abs(v - 0.466) / 0.07, 0.0, 1.0)
    fuller = (np.clip(1.0 - np.abs(v - 0.20) / 0.06, 0, 1) + np.clip(1.0 - np.abs(v - 0.80) / 0.06, 0, 1))
    base = base + 0.12 * edge - 0.06 * fuller * (u < 0.82) - 0.06 * np.clip(1.0 - u / 0.05, 0, 1)
    img[ys, xs] = np.clip(base, 0, 1)[..., None] * np.array([0.98, 1.0, 1.03])[None, None, :]
    # Cast brass, aged: muted yellow with soft brown tarnish, darker in the low areas.
    brass = np.array([0.74, 0.60, 0.34])
    tarn = np.array([0.42, 0.34, 0.20])
    ys, xs = region(UV_BRASS)
    h, w = ys.stop - ys.start, xs.stop - xs.start
    mott = _noise(h, w, 23, 20)[..., None]
    fine = _noise(h, w, 24, 3)[..., None]
    k = np.clip((mott - 0.40) * 1.2, 0, 1) * 0.40
    img[ys, xs] = (brass * (1 - k) + tarn * k) * (0.95 + 0.10 * fine)
    # Grip: the same brass with the spiral grooves darkened (tarnish and grime collect
    # there), laid out as the grip loft maps it (U along z, V round the section).
    ys, xs = region(UV_GRIP)
    h, w = ys.stop - ys.start, xs.stop - xs.start
    zz = GRIP_BOT + np.linspace(0, 1, w)[None, :] * (GRIP_TOP - GRIP_BOT)
    aa = 2 * math.pi * np.linspace(0, 1, h)[:, None]
    f0, f1 = flute_span()
    tf = np.clip((zz - f0) / (f1 - f0), 0.0, 1.0)
    fade = np.clip(tf / 0.05, 0, 1) * np.clip((1.0 - tf) / 0.05, 0, 1) * ((zz > f0) & (zz < f1))
    groove = np.maximum(0.0, np.cos(FLUTES * aa + 2 * math.pi * TWIST * tf)) ** 2 * fade
    mott = _noise(h, w, 28, 10)[..., None]
    k = np.clip((mott - 0.40) * 1.2, 0, 1) * 0.35 + 0.55 * groove[..., None]
    img[ys, xs] = (brass * (1 - k) + tarn * 0.8 * k) * (0.95 + 0.10 * _noise(h, w, 29, 3)[..., None])
    # Black leather: Poly Haven brown_leather grain (CC0) recoloured, else noise; a stitched
    # seam along the back of the scabbard (V = 0.75 of the 16-point ring) and a few scuffs.
    ys, xs = region(UV_LEATHER)
    h, w = ys.stop - ys.start, xs.stop - xs.start
    tex = _polyhaven("clothing/brown_leather/brown_leather_diffuse_2k.jpg", max(h, w))
    col = np.array([0.050, 0.042, 0.036])
    if tex is not None:
        lum = tex[:h, :w].mean(axis=2, keepdims=True)
        img[ys, xs] = lum / max(float(lum.mean()), 1e-3) * col * 1.1
    else:
        img[ys, xs] = col * (0.8 + 0.4 * _noise(h, w, 25, 3)[..., None])
    scuff = np.clip((_noise(h, w, 26, 10) - 0.7) * 2.0, 0, 1)[..., None] * 0.7
    img[ys, xs] = img[ys, xs] * (1 - scuff) + np.array([0.12, 0.10, 0.085]) * scuff
    vv = np.linspace(0, 1, h)[:, None]
    uu = np.linspace(0, 1, w)[None, :]
    seam = np.clip(1.0 - np.abs(vv - 0.75) / 0.012, 0, 1)
    stitch = seam * (np.sin(2 * math.pi * uu * 160) > 0.2)
    img[ys, xs] = img[ys, xs] * (1 - 0.5 * seam[..., None]) + np.array([0.16, 0.13, 0.10]) * stitch[..., None] * 0.6
    img = np.clip(img, 0.0, 1.0)
    rgba = np.concatenate([img, np.ones((H, W, 1), dtype=np.float32)], axis=2)
    im = bpy.data.images.new("saber_atlas", W, H, alpha=False)
    im.pixels.foreach_set(rgba.reshape(-1))
    im.update()
    im.pack()
    return im


def principled(name, image=None, color=None, metallic=0.0, roughness=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
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


def add_empty(name, godot_pos, parent):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 0.02
    e.location = G(*godot_pos)
    e.parent = parent
    bpy.context.scene.collection.objects.link(e)
    return e


def build_saber():
    mats = {}
    atlas = make_atlas()
    mats["steel"] = principled("SaberSteel", image=atlas, metallic=0.9, roughness=0.32)
    mats["brass"] = principled("SaberBrass", image=atlas, metallic=0.9, roughness=0.38)
    mats["leather"] = principled("ScabbardLeather", image=atlas, metallic=0.0, roughness=0.52)

    acc = MassAcc()
    b = Builder(mass=acc)
    tip = build_blade(b)
    build_grip(b)
    build_pommel(b)
    build_dish(b)
    build_block(b)
    build_guards(b)
    me = b.mesh("Saber")
    me.materials.append(mats["steel"])
    me.materials.append(mats["brass"])
    saber = bpy.data.objects.new("Saber", me)
    bpy.context.scene.collection.objects.link(saber)

    sb = Builder()
    throat, stud_tip, chape_end = build_scabbard(sb)
    me2 = sb.mesh("Scabbard")
    me2.materials.append(mats["steel"])     # slot 0 unused: keeps MAT_* indices shared
    me2.materials.append(mats["brass"])
    me2.materials.append(mats["leather"])
    scab = bpy.data.objects.new("Scabbard", me2)
    bpy.context.scene.collection.objects.link(scab)

    c, t, nrm = blade_frame(BLADE_OUT)
    back, edge, th, _ = blade_section(BLADE_OUT)
    blade_base = c + nrm * ((back + edge) * 0.5)
    com = acc.com()
    add_empty("Tip", tuple(tip), saber)
    add_empty("Muzzle", tuple(tip), saber)
    add_empty("BladeBase", tuple(blade_base), saber)
    add_empty("COM", tuple(com), saber)
    add_empty("Pommel", (0.0, 0.0, POMMEL[-1][1]), saber)
    add_empty("Throat", tuple(throat), scab)
    add_empty("FrogStud", tuple(stud_tip), scab)
    add_empty("ChapeEnd", tuple(chape_end), scab)
    info = dict(tip=tuple(round(x, 4) for x in tip), blade_base=tuple(round(x, 4) for x in blade_base),
                com=tuple(round(x, 4) for x in com), mass=round(acc.m, 3),
                parts={k: round(v, 3) for k, v in acc.parts.items()},
                frog_stud=tuple(round(x, 4) for x in stud_tip), throat=tuple(round(x, 4) for x in throat))
    return saber, scab, info


def export_glb(objs, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
        for c in obj.children:
            c.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=True, export_normals=True,
        export_materials="EXPORT", export_image_format="AUTO",
        export_cameras=False, export_lights=False, export_extras=False)


# --------------------------------------------------------------------------
# Previews
# --------------------------------------------------------------------------
def setup_render():
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        sc.render.engine = "BLENDER_WORKBENCH"
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (0.16, 0.14, 0.12, 1.0)
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = (0.80, 0.84, 0.90, 1.0)
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    sc.world = world
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.0
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(40), math.radians(-25), math.radians(35))
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new("Fill", "SUN")
    fill.energy = 0.8
    fo = bpy.data.objects.new("Fill", fill)
    fo.rotation_euler = (math.radians(-60), math.radians(30), math.radians(-150))
    sc.collection.objects.link(fo)


def shoot(tag, target, loc, ortho, size, out_dir, name, up="Y", rot=None):
    sc = bpy.context.scene
    cd = bpy.data.cameras.new("cam_" + tag)
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = 50
    cd.clip_start = 0.002
    cam = bpy.data.objects.new("cam_" + tag, cd)
    cam.location = loc
    if rot is not None:
        cam.rotation_euler = rot
    else:
        d = Vector(target) - Vector(loc)
        cam.rotation_euler = d.to_track_quat("-Z", up).to_euler()
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.filepath = os.path.join(out_dir, "%s_%s.png" % (name, tag))
    bpy.ops.render.render(write_still=True)
    print("RENDERED", sc.render.filepath)


def render_previews(out_dir, saber, scab):
    os.makedirs(out_dir, exist_ok=True)
    setup_render()
    # Blender coordinates: Godot (x, y, z) -> (x, -z, y). The blade runs along Blender +Y.
    mid = (0.0, 0.31, -0.01)
    scab.hide_render = True
    shoot("side", mid, (1.2, 0.31, -0.01), 0.86, (1400, 700), out_dir, "saber")
    shoot("edge", mid, (0.0, 0.31, 1.2), 0.86, (1400, 700), out_dir, "saber", rot=(0.0, 0.0, math.pi / 2))
    shoot("hilt", (0.0, -0.01, 0.01), (0.19, -0.13, 0.12), 0.0, (1000, 1000), out_dir, "saber")
    shoot("hilt_back", (0.0, 0.0, 0.0), (-0.17, -0.12, -0.08), 0.0, (1000, 1000), out_dir, "saber")
    shoot("point", (0.0, 0.62, -0.04), (0.16, 0.50, 0.05), 0.0, (1000, 700), out_dir, "saber")
    scab.hide_render = False
    shoot("sheathed", mid, (1.2, 0.31, -0.01), 0.86, (1400, 700), out_dir, "saber")
    shoot("sheathed_out", mid, (-1.2, 0.31, -0.01), 0.86, (1400, 700), out_dir, "saber")
    shoot("locket", (0.0, 0.07, 0.0), (-0.20, -0.06, 0.10), 0.0, (1000, 1000), out_dir, "saber")
    saber.hide_render = True
    shoot("scabbard_empty", (0.0, 0.03, 0.0), (0.10, -0.12, 0.13), 0.0, (1000, 1000), out_dir, "saber")
    saber.hide_render = False


# --------------------------------------------------------------------------
# In-hand check against Actor_B's knife clips (needs the Blender animation libraries)
# --------------------------------------------------------------------------
HAND_CLIPS = [  # (blend, action, sample index; negative from the end, label)
    ("Actor_B_001.blend", "atk-actor_b-knife-v-thug-hit1-intro", 0, "ready"),
    ("Actor_B_001.blend", "atk-actor_b-knife-v-thug-hit1-intro", -1, "hit1_contact"),
    ("Actor_B_001.blend", "atk-actor_b-knife-v-thug-hit2-intro", -1, "hit2_contact"),
    ("Actor_B_001.blend", "atk-actor_b-knife-v-thug-hit3-intro", -1, "hit3_contact"),
    ("Actor_B_014.blend", "actor_b-p-knife--fingers", 0, "carry_fingers"),
]
HAND_SEGS = [  # capsules between joint heads (the input bones' tails are arbitrary)
    ("r_wrist", "r_middle_metacarpal", 0.020), ("r_wrist", "r_index_metacarpal", 0.012),
    ("r_wrist", "r_pinkya", 0.012), ("r_index_metacarpal", "r_indexa", 0.009),
    ("r_middle_metacarpal", "r_middlea", 0.009), ("r_ring_metacarpal", "r_ringa", 0.009),
    ("r_pinkya", "r_pinkyb", 0.009), ("r_indexa", "r_middlea", 0.009), ("r_middlea", "r_ringa", 0.009),
    ("r_ringa", "r_pinkyb", 0.009),
    ("r_indexa", "r_indexb", 0.0080), ("r_indexb", "r_indexc", 0.0074),
    ("r_middlea", "r_middleb", 0.0082), ("r_middleb", "r_middlec", 0.0076),
    ("r_ringa", "r_ringb", 0.0078), ("r_ringb", "r_ringc", 0.0072),
    ("r_pinkyb", "r_pinkyc", 0.0072), ("r_pinkyc", "r_pinkyd", 0.0066),
    ("r_thumba", "r_thumbb", 0.0095), ("r_thumbb", "r_thumbc", 0.0085)]
HAND_TIPS = [("r_indexb", "r_indexc", 0.017, 0.0068), ("r_middleb", "r_middlec", 0.018, 0.0070),
             ("r_ringb", "r_ringc", 0.017, 0.0066), ("r_pinkyc", "r_pinkyd", 0.015, 0.0060),
             ("r_thumbb", "r_thumbc", 0.020, 0.0080)]


def offset_matrix(off):
    X, Y, Z, C = (Vector(v) for v in off)
    m = Matrix.Identity(4)
    for r in range(3):
        m[r][0], m[r][1], m[r][2], m[r][3] = X[r], Y[r], Z[r], C[r]
    return m


def hand_check(lib_dir, out_dir, saber, scab):
    """Poses Actor_B with the knife clips, hangs the saber on r_hand_prop_attachment
    by SABER_PROP_OFFSET and renders the hand (bones as capsules) for a fit check.
    Prints the tip position in the clip's align frame (right, forward, up)."""
    os.makedirs(out_dir, exist_ok=True)
    scab.hide_render = True
    lib001 = os.path.join(lib_dir, "Actor_B_001.blend")
    with bpy.data.libraries.load(lib001, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n == "Actor_B Rig"]
    rig = [o for o in dst.objects if o is not None][0]
    bpy.context.scene.collection.objects.link(rig)
    rig.hide_render = True
    needed = {}
    for blend, act, _, _ in HAND_CLIPS:
        needed.setdefault(blend, set()).add(act)
    for blend, acts in needed.items():
        with bpy.data.libraries.load(os.path.join(lib_dir, blend), link=False) as (src, dst):
            dst.actions = [a for a in src.actions if a in acts]
    if rig.animation_data is None:
        rig.animation_data_create()
    cg = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))   # Godot -> Blender
    off = offset_matrix(SABER_PROP_OFFSET)
    off_carry = offset_matrix(SABER_PROP_OFFSET_CARRY)
    sc = bpy.context.scene
    hand_mat = principled("HandCheck", color=(0.72, 0.55, 0.45), roughness=0.7)
    for blend, act_name, k, label in HAND_CLIPS:
        act = bpy.data.actions.get(act_name)
        if act is None:
            print("HANDCHECK MISSING", act_name)
            continue
        for pb in rig.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.scale = (1, 1, 1)
        rig.animation_data.action = act
        try:
            if len(act.slots):
                rig.animation_data.action_slot = act.slots[0]
        except Exception:
            pass
        sr = float(act.get("sample_rate", 10.0))
        n = int(act.get("sample_count", 1))
        kk = k if k >= 0 else n + k
        fr = act.frame_range[0] + kk * 30.0 / sr
        fi = int(math.floor(fr))
        sc.frame_set(fi, subframe=fr - fi)
        bpy.context.view_layer.update()
        M = rig.matrix_world
        prop = M @ rig.pose.bones["r_hand_prop_attachment"].matrix
        prop = Matrix.LocRotScale(prop.to_translation(), prop.to_quaternion(), None)
        use = off_carry if label.startswith("carry") else off
        saber.matrix_world = prop @ use @ cg.inverted()
        # capsules for the hand
        bm = bmesh.new()

        def head(bn):
            return M @ rig.pose.bones[bn].head

        segs = [(head(a), head(c), r) for a, c, r in HAND_SEGS]
        for a, c, L, r in HAND_TIPS:
            ha, hc = head(a), head(c)
            segs.append((hc, hc + (hc - ha).normalized() * L, r))
        for h, t, r in segs:
            L = (t - h).length
            if L < 1e-5:
                continue
            ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=r, radius2=r, depth=L)
            q = (t - h).normalized().to_track_quat("Z", "Y")
            mat = Matrix.Translation((h + t) * 0.5) @ q.to_matrix().to_4x4()
            bmesh.ops.transform(bm, matrix=mat, verts=ret["verts"])
            for p in (h, t):
                sp = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=r)
                bmesh.ops.translate(bm, vec=p, verts=sp["verts"])
        me = bpy.data.meshes.new("hand_" + label)
        bm.to_mesh(me)
        bm.free()
        ho = bpy.data.objects.new("hand_" + label, me)
        me.materials.append(hand_mat)
        sc.collection.objects.link(ho)
        # tip in the align frame (right = -X, forward = -Y, up = +Z)
        tip_obj = [c for c in saber.children if c.name == "Tip"][0]
        tipw = saber.matrix_world @ tip_obj.location
        grip = saber.matrix_world.to_translation()
        print("HANDCHECK %-14s %-40s tip(right,fwd,up)=(%.3f, %.3f, %.3f) grip=(%.3f, %.3f, %.3f)" % (
            label, act_name, -tipw.x, -tipw.y, tipw.z, -grip.x, -grip.y, grip.z))
        R = saber.matrix_world.to_3x3().normalized()
        xw, yw, zw = R @ Vector((1, 0, 0)), R @ Vector((0, 0, 1)), R @ Vector((0, -1, 0))
        g = grip
        shoot("hand_%s_side" % label, g, g + xw * 0.30 + zw * 0.04, 0.24, (800, 800), out_dir, "saber")
        shoot("hand_%s_3q" % label, g, g + (xw * 0.6 - yw * 0.55 + zw * 0.55).normalized() * 0.32, 0.24, (800, 800), out_dir, "saber")
        shoot("hand_%s_axial" % label, g, g + zw * 0.40 + xw * 0.002, 0.16, (800, 800), out_dir, "saber")
        ho.hide_render = True
    scab.hide_render = False
    saber.matrix_world = Matrix.Identity(4)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(PROJECT, "assets", "weapons", "saber.glb"))
    ap.add_argument("--renders", default=None)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--hand-check", default=None, help="folder with Actor_B_001.blend and Actor_B_014.blend")
    args = ap.parse_args(argv)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    saber, scab, info = build_saber()
    for obj in (saber, scab):
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print("%s TRIS %d VERTS %d" % (obj.name.upper(), tris, len(obj.data.vertices)))
    print("SABER INFO", info)
    export_glb([saber, scab], args.out)
    print("EXPORTED", args.out)
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    if args.renders:
        render_previews(args.renders, saber, scab)
        if args.hand_check:
            hand_check(args.hand_check, args.renders, saber, scab)


if __name__ == "__main__":
    main()
