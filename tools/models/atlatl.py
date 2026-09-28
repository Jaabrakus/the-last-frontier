"""Procedural atlatl (spear-thrower) and its dart: the game's legendary item.

The board is carved maple with a leather-wrapped handle and two suede finger loops
(Basketmaker style), a drilled "butterfly" bannerstone of green banded slate on a round
neck carved into the board and lashed with sinew either side (eastern Archaic style), an
antler end cap socketed over the board's end whose hook spur seats in the dart's cupped
butt, and red-ochre / charcoal painted motifs. The dart has a side-notched chert point
hafted with sinew into a hardwood foreshaft, a river-cane main shaft with raised
nodes, painted cresting, three barred turkey vanes laid on a slight helix, and a
cupped butt.

The atlatl is anachronistic for the 1750s eastern woodlands (the bow replaced it there
in the Late Woodland period, c. 500-1000 CE); see the throwables design doc.

Run headless (factory scene):
  Blender -b --factory-startup --python tools/models/atlatl.py -- \
      [--out assets/weapons/atlatl.glb] [--dart-out assets/weapons/atlatl_dart.glb] \
      [--renders DIR] [--blend FILE.blend] [--no-verify]

Conventions (Godot / glTF axes: +X right, +Y up, forward = -Z), matching
scripts/weapons/weapon_models_throwables.gd:
  atlatl.glb       origin = the grip (the hand's hold on the handle). The board runs back
                   along +Z to the antler hook at the far end; the dart lies on top of the
                   board pointing forward (-Z).
                   markers  Hook   where the dart's butt (nock) seats on the spur
                            Spur   same point as Hook (name used by throwable_atlatl.gd)
                            Muzzle tip of a seated dart = Hook - (0, 0, DART_LEN)
                            COM    balance point of the board
  atlatl_dart.glb  origin = the tip of the stone point (like arrow.glb); the shaft runs
                   back along +Z to the butt cup at z = DART_LEN. Cock vane up (+Y), hen
                   vanes at +/-120 degrees, clear of the board when seated.
                   markers  COM    balance point (mass-weighted, printed on export)
                            Nock   centre of the butt face (seats on the Hook)
  One mesh per GLB. Each GLB carries its own 512 px texture set: base colour
  (atlatl_atlas), tangent-space normal (atlatl_normal) and occlusion/roughness/metallic
  (atlatl_orm, glTF channel order R = AO, G = roughness, B = metallic).

Blender is Z-up and the glTF exporter maps Blender (x, y, z) to glTF (x, z, -y), so all
geometry is written in Godot coordinates through G(x, y, z).

Textures are procedural (numpy) plus read-only crops of the CC0 Poly Haven
brown_leather and scuba_suede maps in assets/polyhaven/textures, recoloured.
"""

import argparse
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

# --------------------------------------------------------------------------
# Dimensions (metres, Godot axes)
# --------------------------------------------------------------------------
# Board profile: (z, half width, half thickness). The front end (z < 0) is the handle
# knob; the far end carries the hook.
BOARD = [
    (-0.0300, 0.0060, 0.0040),
    (-0.0285, 0.0100, 0.0064),
    (-0.0255, 0.0126, 0.0080),
    (-0.0200, 0.0136, 0.0086),
    (-0.0120, 0.0131, 0.0084),
    (0.0000, 0.0126, 0.0084),
    (0.0300, 0.0128, 0.0084),
    (0.0600, 0.0135, 0.0082),
    (0.0900, 0.0150, 0.0076),
    (0.1300, 0.0174, 0.0068),
    (0.2000, 0.0196, 0.0062),
    (0.3000, 0.0206, 0.0058),
    (0.4000, 0.0196, 0.0056),
    (0.4600, 0.0176, 0.0057),
    (0.4900, 0.0150, 0.0060),
    (0.5050, 0.0118, 0.0062),              # narrows into the antler cap's socket
    (0.5200, 0.0100, 0.0064),
    (0.5400, 0.0092, 0.0062),
    (0.5480, 0.0075, 0.0050),
    (0.5505, 0.0045, 0.0030),
]
BOARD_Z0, BOARD_Z1 = BOARD[0][0], BOARD[-1][0]
GRIP = (-0.018, 0.078)                  # leather wrap
GRIP_G = 0.0018                         # wrap thickness
LOOP_Z = 0.040                          # finger loops, one each side of the handle
# The board is carved down to a round neck through the bannerstone's drilled bore
# (NECK_R = 1.7 cm bore); the flat-to-round shoulders are under the first two lashings.
NECK_R, NECK_Y = 0.0085, -0.0015
NECK = (0.2095, 0.2185, 0.2715, 0.2805)  # flat -> round, round -> flat
# Sinew lashings: either side of the bannerstone (over the neck's shoulders) and over the
# mouth of the antler end cap.
LASH = [(0.2070, 0.2235), (0.2665, 0.2830), (0.5020, 0.5180)]
BANNER_Z = 0.245                        # butterfly bannerstone, bored for the neck
BANNER_Y = NECK_Y
# (|x|, half thickness in Y, half length in Z): the barrel round the bore, then the wings.
BANNER = [(0.000, 0.0110, 0.0205), (0.012, 0.0107, 0.0200), (0.020, 0.0094, 0.0180),
          (0.025, 0.0068, 0.0155), (0.032, 0.0056, 0.0225), (0.040, 0.0049, 0.0285),
          (0.048, 0.0043, 0.0315), (0.054, 0.0036, 0.0310), (0.058, 0.0026, 0.0262),
          (0.0598, 0.0015, 0.0165), (0.0606, 0.0006, 0.0066)]
HOOK_POS = (0.0, 0.020, 0.526)          # = ThrowableModels.ATLATL_SPUR
# Antler end cap socketed over the tapered end of the board (eastern Archaic style); the
# hook is carved from the same tine. Oval section (z, half width, half height above and
# below the board's axis: the socket sits a little low in the tine), rounded at the end.
CAP_PROFILE = [(0.5050, 0.0142, 0.0084, 0.0094), (0.5150, 0.0127, 0.0084, 0.0094),
               (0.5300, 0.0119, 0.0084, 0.0094), (0.5420, 0.0115, 0.0082, 0.0092),
               (0.5480, 0.0109, 0.0078, 0.0088), (0.5520, 0.0097, 0.0070, 0.0080),
               (0.5550, 0.0076, 0.0056, 0.0064), (0.5570, 0.0048, 0.0036, 0.0042),
               (0.5580, 0.0022, 0.0017, 0.0019), (0.5583, 0.0008, 0.0006, 0.0007)]
CAP = (CAP_PROFILE[0][0], CAP_PROFILE[-1][0])
# Antler hook centreline (y, z) and radius: rises out of the cap, turns forward and
# ends in a spur that sits 2-3 mm deep in the dart's butt cup. Its foot is inside the cap.
HOOK = [((0.0000, 0.5405), 0.0068), ((0.0080, 0.5410), 0.0064), ((0.0145, 0.5400), 0.0058),
        ((0.0200, 0.5375), 0.0050), ((0.0232, 0.5338), 0.0042), ((0.0236, 0.5300), 0.0034),
        ((0.0222, 0.5268), 0.0025), ((0.0208, 0.5247), 0.0016), ((0.0201, 0.5233), 0.0006)]
# Minimum gap between a seated dart and the board, grip wrap, lashings and stone (verify).
SEAT_GAP = 0.0024

# Dart.
DART_LEN = 1.65
# Chert point: (z, half width, half thickness); shoulders at 0.044, side notches and
# base hidden in the sinew binding.
POINT = [(0.000, 0.0004, 0.0003), (0.004, 0.0032, 0.0014), (0.010, 0.0062, 0.0024),
         (0.017, 0.0086, 0.0031), (0.025, 0.0104, 0.0035), (0.033, 0.0116, 0.0036),
         (0.040, 0.0121, 0.0035), (0.044, 0.0118, 0.0033), (0.0448, 0.0070, 0.0031),
         (0.051, 0.0068, 0.0030), (0.054, 0.0074, 0.0026), (0.058, 0.0068, 0.0020)]
BIND = [(0.0450, 0.0074, 0.0035), (0.0478, 0.0081, 0.0052), (0.072, 0.0066, 0.0060),
        (0.079, 0.0050, 0.0050)]                  # sinew hafting: (z, rx, ry)
FORE = [(0.048, 0.0040), (0.056, 0.0047), (0.200, 0.0053), (0.300, 0.0057)]
MAIN = [(0.290, 0.0066), (0.300, 0.0069), (0.800, 0.0073), (1.300, 0.0069), (DART_LEN, 0.0064)]
NODES = [0.52, 0.76, 1.00, 1.24]
CANE_SPLIT = 0.97                                   # UV strip A | B
FLETCH = (DART_LEN - 0.235, DART_LEN - 0.045)
CREST = [(DART_LEN - 0.335, DART_LEN - 0.325, "black"), (DART_LEN - 0.325, DART_LEN - 0.285, "red"),
         (DART_LEN - 0.285, DART_LEN - 0.275, "black")]
DART_WRAPS = [(0.276, 0.318), (FLETCH[0] - 0.014, FLETCH[0] + 0.004),
              (FLETCH[1] - 0.004, FLETCH[1] + 0.012), (DART_LEN - 0.024, DART_LEN - 0.012)]
CUP = (0.0046, 0.0034, 0.004)                       # cup mouth radius, bottom radius, depth
SIDES = 8                                           # cane, foreshaft, wraps and butt
VANE_H = [(0.00, 0.0015), (0.08, 0.0062), (0.20, 0.0114), (0.40, 0.0156), (0.60, 0.0170),
          (0.80, 0.0161), (0.92, 0.0114), (1.00, 0.0028)]
VANE_ANGLES = (90.0, 210.0, 330.0)                  # cock up, hens down-left / down-right
VANE_TWIST = 6.0                                    # degrees of helix over the vane, centred
VANE_WIDEST = 0.60                                  # on the widest point (t = 0.6)

# Densities (kg/m^3) for the balance points.
RHO = {"maple": 700.0, "slate": 2750.0, "antler": 1850.0, "leather": 900.0, "sinew": 1300.0,
       "chert": 2600.0, "hardwood": 800.0, "cane": 750.0}
CANE_WALL = 0.0015

# --------------------------------------------------------------------------
# Texture layout (u0, u1, v0, v1), 512 px atlases
# --------------------------------------------------------------------------
ATLAS = 512
A_BOARD = (0.0, 1.0, 0.5, 1.0)
A_LEATHER = (0.0, 0.25, 0.25, 0.5)
A_SUEDE = (0.25, 0.5, 0.25, 0.5)
A_SINEW = (0.5, 0.75, 0.25, 0.5)
A_ANTLER = (0.75, 1.0, 0.25, 0.5)
A_SLATE = (0.0, 0.625, 0.0, 0.25)
A_ENDGRAIN = (0.625, 0.75, 0.0, 0.125)

D_CANE_A = (0.0, 1.0, 0.8125, 1.0)
D_CANE_B = (0.0, 1.0, 0.625, 0.8125)
D_FORE = (0.0, 0.5, 0.5, 0.625)
D_FEATHER = (0.5, 1.0, 0.5, 0.625)
D_SINEW = (0.0, 0.25, 0.375, 0.5)
D_CHERT = (0.25, 0.5, 0.25, 0.5)
D_RED = (0.0, 0.125, 0.25, 0.375)
D_BLACK = (0.125, 0.25, 0.25, 0.375)
D_CANE_END = (0.5, 0.625, 0.25, 0.375)
D_CUP = (0.625, 0.75, 0.25, 0.375)
D_PAINT = {"red": D_RED, "black": D_BLACK}

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
POLYHAVEN = os.path.join(PROJECT, "assets", "polyhaven", "textures")


def G(x, y, z):
    """Godot-space point expressed in Blender coordinates."""
    return Vector((x, -z, y))


def GV(v):
    return G(v[0], v[1], v[2])


def lerp(a, b, t):
    return a + (b - a) * t


def interp(table, x, idx=1):
    if x <= table[0][0]:
        return table[0][idx]
    for a, c in zip(table, table[1:]):
        if x <= c[0]:
            return lerp(a[idx], c[idx], (x - a[0]) / (c[0] - a[0]))
    return table[-1][idx]


def inset(rect, px=2.0):
    m = px / ATLAS
    u0, u1, v0, v1 = rect
    return (u0 + m, u1 - m, v0 + m, v1 - m)


# --------------------------------------------------------------------------
# Mesh builder
# --------------------------------------------------------------------------
class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, verts, uvs, smooth, out, mat=0):
        """Face whose normal points along `out` (a Godot-space direction)."""
        out_b = GV(out)
        n = Vector()
        for i, a in enumerate(verts):
            b = verts[(i + 1) % len(verts)]
            n.x += (a.co.y - b.co.y) * (a.co.z + b.co.z)
            n.y += (a.co.z - b.co.z) * (a.co.x + b.co.x)
            n.z += (a.co.x - b.co.x) * (a.co.y + b.co.y)
        if n.dot(out_b) < 0.0:
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

    def loft(self, centers, rings, seg_rect, vs=None, smooth=True, cap0=None, cap1=None, mat=0):
        """Closed tube through `rings` (lists of Godot Vectors, all the same length).
        seg_rect(i) -> (ua, ub, v0, v1) for the band between ring i and i + 1; vs are the
        v fractions of the ring vertices (len n + 1, 0 .. 1). cap0 / cap1 are UV rects for
        the end caps (None = open)."""
        n = len(rings[0])
        vs = vs or [j / n for j in range(n + 1)]
        vr = [[self.bm.verts.new(GV(p)) for p in ring] for ring in rings]
        for i in range(len(rings) - 1):
            ua, ub, v0, v1 = seg_rect(i)
            c = (centers[i] + centers[i + 1]) * 0.5
            for j in range(n):
                k = (j + 1) % n
                va, vb = lerp(v0, v1, vs[j]), lerp(v0, v1, vs[j + 1])
                mid = (rings[i][j] + rings[i][k] + rings[i + 1][j] + rings[i + 1][k]) * 0.25
                self.face([vr[i][j], vr[i][k], vr[i + 1][k], vr[i + 1][j]],
                          [(ua, va), (ua, vb), (ub, vb), (ub, va)], smooth, mid - c, mat)
        for rect, idx, other in ((cap0, 0, 1), (cap1, -1, -2)):
            if rect is None:
                continue
            u0, u1, v0, v1 = rect
            cu, cv, ru, rv = (u0 + u1) * 0.5, (v0 + v1) * 0.5, (u1 - u0) * 0.45, (v1 - v0) * 0.45
            uvs = [(cu + ru * math.cos(2 * math.pi * j / n), cv + rv * math.sin(2 * math.pi * j / n)) for j in range(n)]
            self.face(vr[idx], uvs, False, centers[idx] - centers[other], mat)
        return vr

    def grid(self, rows, rect, out_fn, mat=0):
        """Open sheet through rows of points (rows[i][j]); u along i, v along j."""
        u0, u1, v0, v1 = rect
        vr = [[self.bm.verts.new(GV(p)) for p in row] for row in rows]
        ni, nj = len(rows) - 1, len(rows[0]) - 1
        for i in range(ni):
            for j in range(nj):
                ua, ub = lerp(u0, u1, i / ni), lerp(u0, u1, (i + 1) / ni)
                va, vb = lerp(v0, v1, j / nj), lerp(v0, v1, (j + 1) / nj)
                self.face([vr[i][j], vr[i + 1][j], vr[i + 1][j + 1], vr[i][j + 1]],
                          [(ua, va), (ub, va), (ub, vb), (ua, vb)], True, out_fn(i, j), mat)

    def mesh(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        me.validate()
        return me


def tris(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def poly_area(pts):
    a = 0.0
    for i, p in enumerate(pts):
        q = pts[(i + 1) % len(pts)]
        a += p[0] * q[1] - q[0] * p[1]
    return abs(a) * 0.5


class Mass:
    """Accumulates point masses for a balance point."""

    def __init__(self):
        self.m = 0.0
        self.s = Vector()
        self.parts = {}

    def add(self, name, mass, pos):
        self.m += mass
        self.s += Vector(pos) * mass
        self.parts[name] = self.parts.get(name, 0.0) + mass

    def com(self):
        return self.s / max(self.m, 1e-9)


# --------------------------------------------------------------------------
# Atlatl
# --------------------------------------------------------------------------
# Board cross-section: 14 points, a flattened rounded rectangle with a slightly
# crowned top. Index 0 is the +X edge; the top face runs from index 2 to 5.
_RING = [(1.0, 0.0), (0.94, 0.65), (0.72, 0.97), (0.24, 1.0), (-0.24, 1.0), (-0.72, 0.97),
         (-0.94, 0.65), (-1.0, 0.0), (-0.94, -0.65), (-0.72, -0.97), (-0.24, -1.0), (0.24, -1.0),
         (0.72, -0.97), (0.94, -0.65)]


def _ring_fractions(w=0.020, t=0.006):
    pts = [(a * w, b * t) for a, b in _RING]
    d = [0.0]
    for i in range(len(pts)):
        p, q = pts[i], pts[(i + 1) % len(pts)]
        d.append(d[-1] + math.hypot(q[0] - p[0], q[1] - p[1]))
    return [x / d[-1] for x in d]


BOARD_VS = _ring_fractions()
TOP_V = (BOARD_VS[2], BOARD_VS[5])


def board_wt(z):
    return interp(BOARD, z, 1), interp(BOARD, z, 2)


def neck_k(z):
    """0 = flat board section, 1 = the round neck through the bannerstone (linear shoulders,
    so a loft between the shoulder rings follows it exactly)."""
    a0, a1, b0, b1 = NECK
    if z <= a0 or z >= b1:
        return 0.0
    if z < a1:
        return (z - a0) / (a1 - a0)
    if z <= b0:
        return 1.0
    return (b1 - z) / (b1 - b0)


def board_ring(z, grow=0.0):
    w, t = board_wt(z)
    k = neck_k(z)
    n = len(_RING)
    out = []
    for j, (a, b) in enumerate(_RING):
        p = Vector((a * (w + grow), b * (t + grow), z))
        if k > 0.0:
            ang = 2 * math.pi * j / n
            r = NECK_R + grow
            p = p.lerp(Vector((r * math.cos(ang), NECK_Y + r * math.sin(ang), z)), k)
        out.append(p)
    return out


def cap_ring(z, extra=0.0):
    """Oval section of the antler end cap (grown by `extra`), ring points in the same
    order as the board's so a loft can pass from one to the other."""
    rx, rt, rb = (interp(CAP_PROFILE, z, i) + extra for i in (1, 2, 3))
    n = len(_RING)
    out = []
    for j in range(n):
        ang = 2 * math.pi * j / n
        c, s = math.cos(ang), math.sin(ang)
        out.append(Vector((rx * c, (rt if s >= 0 else rb) * s, z)))
    return out


def board_u(z, rect=A_BOARD):
    u0, u1, _, _ = inset(rect)
    return lerp(u0, u1, (z - BOARD_Z0) / (BOARD_Z1 - BOARD_Z0))


def build_atlatl_mesh():
    b = Builder()
    mass = Mass()
    _, _, bv0, bv1 = inset(A_BOARD)
    cap = inset(A_ENDGRAIN)

    # Board (with the neck's shoulder rings).
    zs = sorted(set([p[0] for p in BOARD] + list(NECK)))
    rings = [board_ring(z) for z in zs]
    centers = [Vector((0, 0, z)) for z in zs]
    b.loft(centers, rings, lambda i: (board_u(zs[i]), board_u(zs[i + 1]), bv0, bv1), BOARD_VS,
           cap0=cap, cap1=cap)
    for z0, z1 in zip(zs, zs[1:]):
        zm = (z0 + z1) * 0.5
        area = poly_area([(p.x, p.y) for p in board_ring(zm)])
        mass.add("board", area * (z1 - z0) * RHO["maple"], (0, 0, zm))

    # Leather grip wrap (follows the board, GRIP_G proud).
    zs = [GRIP[0], GRIP[0] + 0.003] + [z for z, _, _ in BOARD if GRIP[0] + 0.003 < z < GRIP[1] - 0.003] + [GRIP[1] - 0.003, GRIP[1]]
    grows = [0.0006, GRIP_G] + [GRIP_G] * (len(zs) - 4) + [GRIP_G, 0.0006]
    u0, u1, v0, v1 = inset(A_LEATHER)
    b.loft([Vector((0, 0, z)) for z in zs], [board_ring(z, g) for z, g in zip(zs, grows)],
           lambda i: (lerp(u0, u1, (zs[i] - GRIP[0]) / (GRIP[1] - GRIP[0])),
                      lerp(u0, u1, (zs[i + 1] - GRIP[0]) / (GRIP[1] - GRIP[0])), v0, v1), BOARD_VS)
    for z0, z1 in zip(zs, zs[1:]):
        zm = (z0 + z1) * 0.5
        shell = poly_area([(p.x, p.y) for p in board_ring(zm, GRIP_G)]) - poly_area([(p.x, p.y) for p in board_ring(zm)])
        mass.add("leather", shell * (z1 - z0) * RHO["leather"], (0, 0, zm))

    # Antler end cap over the board's end; its open mouth is under the third lashing.
    zs = [p[0] for p in CAP_PROFILE]
    au0, au1, av0, av1 = inset(A_ANTLER)
    cu1 = lerp(au0, au1, 0.5)
    b.loft([Vector((0, 0, z)) for z in zs], [cap_ring(z) for z in zs],
           lambda i: (lerp(au0, cu1, (zs[i] - zs[0]) / (zs[-1] - zs[0])),
                      lerp(au0, cu1, (zs[i + 1] - zs[0]) / (zs[-1] - zs[0])), av0, av1), BOARD_VS,
           cap1=(au0, au0 + 0.03, av0, av0 + 0.03))
    for z0, z1 in zip(zs, zs[1:]):
        zm = (z0 + z1) * 0.5
        inner = poly_area([(p.x, p.y) for p in board_ring(zm)]) if zm < BOARD_Z1 else 0.0
        shell = poly_area([(p.x, p.y) for p in cap_ring(zm)]) - inner
        mass.add("antler", shell * (z1 - z0) * RHO["antler"], (0, 0, zm))

    # Sinew lashings over the neck's shoulders either side of the bannerstone (following
    # the flat-to-round change), and over the cap's mouth, tapering onto the board.
    u0, u1, v0, v1 = inset(A_SINEW)
    for k, (z0, z1) in enumerate(LASH):
        if k < 2:
            zs = [z0, z0 + 0.0015] + [z for z in NECK if z0 + 0.0015 < z < z1 - 0.0015] + [z1 - 0.0015, z1]
            gs = [-0.0002] + [0.0016] * (len(zs) - 2) + [-0.0002]      # ends sunk: no open rim
            rings = [board_ring(z, g) for z, g in zip(zs, gs)]
        else:
            zs = [z0, z0 + 0.0015, CAP[0] + 0.001, z1 - 0.0015, z1]
            rings = [board_ring(zs[0], -0.0002), board_ring(zs[1], 0.0030)] + \
                [cap_ring(z, e) for z, e in zip(zs[2:], (0.0016, 0.0016, -0.0002))]
        b.loft([Vector((0, 0, z)) for z in zs], rings,
               lambda i, zs=zs: (lerp(u0, u1, (zs[i] - zs[0]) / (zs[-1] - zs[0])),
                                 lerp(u0, u1, (zs[i + 1] - zs[0]) / (zs[-1] - zs[0])), v0, v1), BOARD_VS)
        zm = (z0 + z1) * 0.5
        base = board_ring(zm) if k < 2 else cap_ring(zm)
        outer = board_ring(zm, 0.0016) if k < 2 else cap_ring(zm, 0.0016)
        shell = poly_area([(p.x, p.y) for p in outer]) - poly_area([(p.x, p.y) for p in base])
        mass.add("sinew", shell * (z1 - z0) * RHO["sinew"], (0, 0, zm))

    # Finger loops: suede straps lying almost flat beside the handle, drooping a little.
    u0, u1, v0, v1 = inset(A_SUEDE)
    edge = board_wt(LOOP_Z)[0]
    for sx in (1.0, -1.0):
        npath, nside, half_t, half_w = 16, 8, 0.0015, 0.0020
        path = []
        for i in range(npath + 1):
            a = math.pi * i / npath
            out = 0.0200 * math.sin(a)
            path.append(Vector((sx * (edge - 0.0015 + out), -0.0010 - 0.25 * out, LOOP_Z - 0.0135 * math.cos(a))))
        plane_n = (path[-1] - path[0]).cross(path[npath // 2] - path[0]).normalized()
        if plane_n.y < 0:
            plane_n = -plane_n
        rings, centers = [], []
        for i, c in enumerate(path):
            tan = (path[min(i + 1, npath)] - path[max(i - 1, 0)]).normalized()
            inward = plane_n.cross(tan).normalized()
            rings.append([c + inward * (half_t * math.cos(2 * math.pi * j / nside)) + plane_n * (half_w * math.sin(2 * math.pi * j / nside))
                          for j in range(nside)])
            centers.append(c)
        b.loft(centers, rings, lambda i: (lerp(u0, u1, i / npath), lerp(u0, u1, (i + 1) / npath), v0, v1))
        length = sum((q - p).length for p, q in zip(path, path[1:]))
        mass.add("loops", length * 4 * half_t * half_w * RHO["leather"], path[npath // 2])

    # Butterfly bannerstone, lofted across the board (X); the board runs through its bore.
    table = [(-x, hy, hz) for x, hy, hz in reversed(BANNER[1:])] + BANNER
    nside = 14
    rings, centers = [], []
    for x, hy, hz in table:
        c = Vector((x, BANNER_Y, BANNER_Z))
        ring = []
        for j in range(nside):
            a = 2 * math.pi * j / nside
            ca, sa = math.cos(a), math.sin(a)
            # Superellipse: fuller wings, softly rounded rim.
            ring.append(Vector((x, BANNER_Y + hy * math.copysign(abs(sa) ** 0.8, sa), BANNER_Z + hz * math.copysign(abs(ca) ** 0.8, ca))))
        rings.append(ring)
        centers.append(c)
    xs = [x for x, _, _ in table]
    u0, u1, v0, v1 = inset(A_SLATE)
    b.loft(centers, rings, lambda i: (lerp(u0, u1, (xs[i] - xs[0]) / (xs[-1] - xs[0])),
                                      lerp(u0, u1, (xs[i + 1] - xs[0]) / (xs[-1] - xs[0])), v0, v1),
           cap0=(u0, u0 + 0.02, v0, v1), cap1=(u1 - 0.02, u1, v0, v1))
    for (xa, ha, za), (xb, hb, zb) in zip(table, table[1:]):
        area = math.pi * (ha + hb) * 0.5 * (za + zb) * 0.5 * 0.92
        mass.add("bannerstone", area * (xb - xa) * RHO["slate"], (0.5 * (xa + xb), BANNER_Y, BANNER_Z))
    bore = poly_area([(p.x, p.y) for p in board_ring(BANNER_Z)]) * 2 * BANNER[0][2]
    mass.add("bannerstone", -bore * RHO["slate"], (0, 0, BANNER_Z))

    # Antler hook.
    nside = 10
    rings, centers = [], []
    pts = [(Vector((0.0, y, z)), r) for (y, z), r in HOOK]
    for i, (c, r) in enumerate(pts):
        tan = (pts[min(i + 1, len(pts) - 1)][0] - pts[max(i - 1, 0)][0]).normalized()
        side = Vector((1.0, 0.0, 0.0))
        up = side.cross(tan).normalized()
        rings.append([c + side * (r * math.cos(2 * math.pi * j / nside)) + up * (r * math.sin(2 * math.pi * j / nside))
                      for j in range(nside)])
        centers.append(c)
    lens = [0.0]
    for p, q in zip(pts, pts[1:]):
        lens.append(lens[-1] + (q[0] - p[0]).length)
    u0, u1, v0, v1 = inset(A_ANTLER)
    b.loft(centers, rings, lambda i: (lerp(u0, u1, lens[i] / lens[-1]), lerp(u0, u1, lens[i + 1] / lens[-1]), v0, v1),
           cap1=(u1 - 0.01, u1, v0, v0 + 0.02))
    for (pa, ra), (pb, rb) in zip(pts, pts[1:]):
        mass.add("hook", math.pi * ((ra + rb) * 0.5) ** 2 * (pb - pa).length * RHO["antler"], (pa + pb) * 0.5)
    return b.mesh("Atlatl"), mass


# --------------------------------------------------------------------------
# Dart
# --------------------------------------------------------------------------
def ring_z(z, rx, ry=None, n=SIDES, phase=0.0):
    ry = rx if ry is None else ry
    return [Vector((rx * math.cos(2 * math.pi * j / n + phase), ry * math.sin(2 * math.pi * j / n + phase), z)) for j in range(n)]


def main_r(z):
    r = interp(MAIN, z)
    for n in NODES:
        if abs(z - n) < 1e-6:
            r += 0.0009
    return r


def build_dart_mesh():
    b = Builder()
    mass = Mass()
    rng = np.random.default_rng(7)
    L = DART_LEN

    # Knapped chert point: 8-sided biconvex lens, flat shaded, ridges jittered like flake scars.
    n = 8
    zs = [p[0] for p in POINT]
    rings = []
    for k, (z, w, t) in enumerate(POINT):
        ring = []
        for j in range(n):
            a = 2 * math.pi * j / n
            ca, sa = math.cos(a), math.sin(a)
            jit = 1.0 + (0.14 * (rng.random() - 0.5) if 0 < k < len(POINT) - 1 and j % 4 else 0.0)
            ring.append(Vector((w * ca, t * math.copysign(abs(sa) ** 0.75, sa) * jit, z)))
        rings.append(ring)
    u0, u1, v0, v1 = inset(D_CHERT)
    b.loft([Vector((0, 0, z)) for z in zs], rings,
           lambda i: (lerp(u0, u1, zs[i] / zs[-1]), lerp(u0, u1, zs[i + 1] / zs[-1]), v0, v1),
           smooth=False, cap0=(u0, u0 + 0.01, v0, v0 + 0.01), cap1=(u1 - 0.03, u1, v0, v1))
    for pa, pb in zip(POINT, POINT[1:]):
        area = 0.5 * (pa[1] * pa[2] + pb[1] * pb[2]) * 3.0
        mass.add("point", area * (pb[0] - pa[0]) * RHO["chert"], (0, 0, 0.5 * (pa[0] + pb[0])))

    # Sinew hafting over the notches, flattened to the width of the point's base.
    zs = [p[0] for p in BIND]
    u0, u1, v0, v1 = inset(D_SINEW)
    b.loft([Vector((0, 0, z)) for z in zs], [ring_z(z, rx, ry) for z, rx, ry in BIND],
           lambda i: (lerp(u0, u1, i / 3), lerp(u0, u1, (i + 1) / 3), v0, v1))
    mass.add("sinew", math.pi * 0.0065 * 0.0055 * 0.037 * RHO["sinew"] * 0.5, (0, 0, 0.06))

    # Hardwood foreshaft (its rear end is socketed in the cane).
    zs = [p[0] for p in FORE]
    u0, u1, v0, v1 = inset(D_FORE)
    b.loft([Vector((0, 0, z)) for z in zs], [ring_z(z, r) for z, r in FORE],
           lambda i: (lerp(u0, u1, (zs[i] - zs[0]) / (zs[-1] - zs[0])), lerp(u0, u1, (zs[i + 1] - zs[0]) / (zs[-1] - zs[0])), v0, v1),
           cap0=inset(D_FORE, 60))
    for (za, ra), (zb, rb) in zip(FORE, FORE[1:]):
        mass.add("foreshaft", math.pi * ((ra + rb) * 0.5) ** 2 * (zb - za) * RHO["hardwood"], (0, 0, 0.5 * (za + zb)))

    # River-cane main shaft: nodes, painted cresting, UV strips A (front) and B (rear).
    zs = sorted(set([p[0] for p in MAIN] + [nz + d for nz in NODES for d in (-0.005, 0.0, 0.005)]
                    + [z for a, c, _ in CREST for z in (a, c)] + [CANE_SPLIT] + list(FLETCH)))

    def cane_rect(i):
        z0, z1 = zs[i], zs[i + 1]
        for a, c, paint in CREST:
            if abs(z0 - a) < 1e-6 and abs(z1 - c) < 1e-6:
                return inset(D_PAINT[paint])
        if z1 <= CANE_SPLIT + 1e-6:
            u0, u1, v0, v1 = inset(D_CANE_A)
            za, zb = MAIN[0][0], CANE_SPLIT
        else:
            u0, u1, v0, v1 = inset(D_CANE_B)
            za, zb = CANE_SPLIT, L
        return (lerp(u0, u1, (z0 - za) / (zb - za)), lerp(u0, u1, (z1 - za) / (zb - za)), v0, v1)
    b.loft([Vector((0, 0, z)) for z in zs], [ring_z(z, main_r(z)) for z in zs], cane_rect,
           cap0=inset(D_CANE_END, 3))
    for za, zb in zip(zs, zs[1:]):
        r = interp(MAIN, 0.5 * (za + zb))
        mass.add("cane", math.pi * (r * r - (r - CANE_WALL) ** 2) * (zb - za) * RHO["cane"], (0, 0, 0.5 * (za + zb)))

    # Butt: lip, cup wall and cup bottom.
    rl, rc, depth = CUP
    lip_o, lip_i = ring_z(L, main_r(L)), ring_z(L, rl)
    cup_b = ring_z(L - depth, rc)
    vo = [b.bm.verts.new(GV(p)) for p in lip_o]
    vi = [b.bm.verts.new(GV(p)) for p in lip_i]
    vb = [b.bm.verts.new(GV(p)) for p in cup_b]
    cu0, cu1, cv0, cv1 = inset(D_CUP)
    lu0, lu1, lv0, lv1 = inset(D_CANE_END)
    nn = len(lip_o)
    for j in range(nn):
        k = (j + 1) % nn
        va, vb_ = lerp(cv0, cv1, j / nn), lerp(cv0, cv1, (j + 1) / nn)
        la, lb = lerp(lv0, lv1, j / nn), lerp(lv0, lv1, (j + 1) / nn)
        b.face([vo[j], vo[k], vi[k], vi[j]], [(lu0, la), (lu0, lb), (lu1, lb), (lu1, la)],
               False, Vector((0, 0, 1)))
        inward = -(lip_i[j] + lip_i[k]) * 0.5
        inward.z = 0.0
        b.face([vi[j], vi[k], vb[k], vb[j]], [(cu0, va), (cu0, vb_), (cu1, vb_), (cu1, va)], True, inward.normalized() + Vector((0, 0, 0.3)))
    b.face(vb, [(cu1 - 0.01, lerp(cv0, cv1, j / nn)) for j in range(nn)], False, Vector((0, 0, 1)))

    # Sinew wraps: foreshaft socket, both ends of the vanes, and the butt.
    u0, u1, v0, v1 = inset(D_SINEW)
    for z0, z1 in DART_WRAPS:
        zz = [z0, z0 + 0.0015, z1 - 0.0015, z1]
        gs = [0.0003, 0.0010, 0.0010, 0.0003]
        b.loft([Vector((0, 0, z)) for z in zz], [ring_z(z, interp(MAIN, z) + g) for z, g in zip(zz, gs)],
               lambda i, zz=zz: (lerp(u0, u1, (zz[i] - zz[0]) / (zz[-1] - zz[0])), lerp(u0, u1, (zz[i + 1] - zz[0]) / (zz[-1] - zz[0])), v0, v1))
        r = interp(MAIN, 0.5 * (z0 + z1))
        mass.add("sinew", math.pi * ((r + 0.001) ** 2 - r * r) * (z1 - z0) * RHO["sinew"], (0, 0, 0.5 * (z0 + z1)))

    # Vanes: three strips (base, middle, edge) laid on a slight helix, a little cambered.
    for ang0 in VANE_ANGLES:
        rows = []
        for t, h in VANE_H:
            z = lerp(FLETCH[0], FLETCH[1], t)
            a = math.radians(ang0 + VANE_TWIST * (t - VANE_WIDEST))
            d = Vector((math.cos(a), math.sin(a), 0.0))
            tang = Vector((-math.sin(a), math.cos(a), 0.0))
            r = interp(MAIN, z)
            base = Vector((0, 0, z)) + d * (r * 0.90)          # root sunk into the faceted cane
            rows.append([base, base + d * (0.5 * h) + tang * (0.0007 * h / 0.017), base + d * h + tang * (0.0003 * h / 0.017)])
        a_mid = math.radians(ang0)
        tang = Vector((-math.sin(a_mid), math.cos(a_mid), 0.0))
        b.grid(rows, inset(D_FEATHER), lambda i, j, tang=tang: tang, mat=1)
        mass.add("vanes", 0.0004, (0, 0, 0.5 * sum(FLETCH)))
    return b.mesh("AtlatlDart"), mass


# --------------------------------------------------------------------------
# Textures
# --------------------------------------------------------------------------
def vnoise(h, w, cy, cx, seed):
    """Smooth value noise with cy x cx cells over an h x w block."""
    rng = np.random.default_rng(seed)
    g = rng.random((int(cy) + 2, int(cx) + 2)).astype(np.float32)
    y = np.repeat(np.linspace(0, cy, h, endpoint=False)[:, None], w, axis=1)
    x = np.repeat(np.linspace(0, cx, w, endpoint=False)[None, :], h, axis=0)
    y0, x0 = np.floor(y).astype(int), np.floor(x).astype(int)
    fy, fx = y - y0, x - x0
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a, b_ = g[y0, x0], g[y0, x0 + 1]
    c, d = g[y0 + 1, x0], g[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b_ * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(h, w, cy, cx, seed, octaves=4, gain=0.5):
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for k in range(octaves):
        out += amp * vnoise(h, w, cy * 2 ** k, cx * 2 ** k, seed + 31 * k)
        tot += amp
        amp *= gain
    return out / tot


def scallops(h, w, n, seed, aspect=1.0):
    """Distance to the nearest of n random seeds, 0..1: bowls with ridges between."""
    rng = np.random.default_rng(seed)
    pts = rng.random((n, 2)) * np.array([h, w])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.full((h, w), 1e9, np.float32)
    for py, px in pts:
        d = np.minimum(d, ((yy - py) * aspect) ** 2 + (xx - px) ** 2)
    d = np.sqrt(d)
    return d / max(float(d.max()), 1e-6)


def normals(height, strength):
    gy, gx = np.gradient(height.astype(np.float32))
    n = np.dstack([-gx * strength, -gy * strength, np.ones_like(height, dtype=np.float32)])
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def blend_normals(a, b):
    """Whiteout blend of two unit tangent-space normal fields."""
    n = np.dstack([a[..., 0] + b[..., 0], a[..., 1] + b[..., 1], a[..., 2] * b[..., 2]])
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def col(c):
    return np.array(c, np.float32)[None, None, :]


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


def ph_crop(rel, size, factor=2):
    """size x size crop of a Poly Haven map (top-left corner, factor x box filtered),
    raw values 0..1; None when the file is missing."""
    path = os.path.join(POLYHAVEN, rel)
    if not os.path.exists(path):
        return None
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    px = px.reshape(h, w, 4)[:, :, :3]
    c = size * factor
    crop = px[h - c:h, :c] if c <= min(w, h) else px
    return crop.reshape(size, factor, size, factor, 3).mean(axis=(1, 3))


class Atlas:
    def __init__(self):
        A = ATLAS
        self.color = np.zeros((A, A, 3), np.float32) + 0.5
        self.nrm = np.dstack([np.zeros((A, A)), np.zeros((A, A)), np.ones((A, A))]).astype(np.float32)
        self.orm = np.dstack([np.ones((A, A)), np.full((A, A), 0.6), np.zeros((A, A))]).astype(np.float32)

    @staticmethod
    def block(rect):
        u0, u1, v0, v1 = rect
        r0, r1 = int(round(v0 * ATLAS)), int(round(v1 * ATLAS))
        c0, c1 = int(round(u0 * ATLAS)), int(round(u1 * ATLAS))
        h, w = r1 - r0, c1 - c0
        U = ((np.arange(w) + 0.5) / w)[None, :].repeat(h, axis=0).astype(np.float32)
        V = ((np.arange(h) + 0.5) / h)[:, None].repeat(w, axis=1).astype(np.float32)
        return (slice(r0, r1), slice(c0, c1)), h, w, U, V

    def put(self, rect, color, nrm=None, ao=None, rough=None):
        sl, h, w, _, _ = self.block(rect)
        self.color[sl] = np.clip(color, 0.0, 1.0)
        if nrm is not None:
            self.nrm[sl] = nrm
        if ao is not None:
            self.orm[sl[0], sl[1], 0] = np.clip(ao, 0.0, 1.0) * np.ones((h, w))
        if rough is not None:
            self.orm[sl[0], sl[1], 1] = np.clip(rough, 0.03, 1.0) * np.ones((h, w))

    def images(self, prefix):
        out = []
        for key, arr, non_color in (("atlas", self.color, False), ("normal", self.nrm * 0.5 + 0.5, True), ("orm", self.orm, True)):
            im = bpy.data.images.new("%s_%s" % (prefix, key), ATLAS, ATLAS, alpha=False)
            if non_color:
                im.colorspace_settings.name = "Non-Color"
            rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((ATLAS, ATLAS, 1), np.float32)], axis=2)
            im.pixels.foreach_set(rgba.astype(np.float32).ravel())
            im.update()
            im.pack()
            out.append(im)
        return out


def aa_band(d, half, px):
    """Anti-aliased band: 1 where |d| < half, a one-pixel soft edge (px = pixel size in d units)."""
    return smoothstep(half + px, half - px, np.abs(d))


def wrap_texture(at, rect, turns, seed, base=(0.78, 0.68, 0.50)):
    """Sinew wrap: fine ridged turns along u, a little darker between the turns."""
    _, h, w, U, V = at.block(rect)
    ph = U * turns + V * 1.0 + 0.08 * fbm(h, w, 4, 4, seed)
    ridge = np.abs(np.sin(np.pi * ph)) ** 0.5
    fib = fbm(h, w, 30, 8, seed + 1, octaves=3)
    c = col(base) * (0.80 + 0.20 * ridge[..., None]) * (0.92 + 0.14 * fib[..., None])
    at.put(rect, c, normals(0.6 * ridge + 0.15 * fib, 1.3), ao=0.84 + 0.16 * ridge, rough=0.5 + 0.1 * (1 - ridge))


def make_atlatl_textures():
    at = Atlas()
    # Maple board: soft lengthwise grain, knife facets, a hand-darkened handle and
    # worn red-ochre / charcoal motifs on the top face.
    rect = A_BOARD
    _, h, w, U, V = at.block(rect)
    z = BOARD_Z0 + U * (BOARD_Z1 - BOARD_Z0)
    pz = (BOARD_Z1 - BOARD_Z0) / w                       # metres per pixel along the board
    warp = fbm(h, w, 3, 10, 11)
    grain = 0.5 + 0.5 * np.sin(2 * math.pi * (V * 22.0 + 3.0 * warp))
    streak = fbm(h, w, 40, 6, 12, octaves=3)
    mott = fbm(h, w, 4, 16, 13, octaves=3)
    facets = fbm(h, w, 5, 30, 14, octaves=2)
    c = mix(col((0.62, 0.45, 0.27)), col((0.75, 0.58, 0.37)), 0.25 * grain + 0.45 * streak + 0.30 * mott)
    hand = smoothstep(0.11, 0.05, z)
    c = c * (1.0 - 0.18 * hand[..., None])
    top = smoothstep(TOP_V[0] - 0.004, TOP_V[0] + 0.004, V) * smoothstep(TOP_V[1] + 0.004, TOP_V[1] - 0.004, V)
    vt = (V - TOP_V[0]) / (TOP_V[1] - TOP_V[0])
    pv = 1.0 / (h * (TOP_V[1] - TOP_V[0]))               # vt units per pixel
    wear = 0.45 + 0.55 * smoothstep(0.28, 0.45, fbm(h, w, 10, 70, 15, octaves=3))
    red, black = col((0.55, 0.15, 0.07)), col((0.07, 0.055, 0.045))
    ring = aa_band(z - 0.0895, 0.0035, pz) + aa_band(z - 0.4885, 0.0025, pz)
    zone = smoothstep(0.098, 0.102, z) * smoothstep(0.482, 0.478, z)
    lines = aa_band(vt - 0.10, 0.045, pv) + aa_band(vt - 0.90, 0.045, pv)
    tri = np.abs(((z - 0.1) / 0.028) % 2.0 - 1.0)
    zig_zone = smoothstep(0.205, 0.201, z) + smoothstep(0.285, 0.289, z) * smoothstep(0.402, 0.398, z)
    zig = aa_band(vt - (0.26 + 0.48 * tri), 0.085, pv * 1.5) * zig_zone
    dz = (((z - 0.41) % 0.018) - 0.009)
    dist = np.sqrt(dz ** 2 + ((vt - 0.5) * 0.030) ** 2)
    dots = smoothstep(0.0032 + pz, 0.0032 - pz, dist) * smoothstep(0.404, 0.408, z) * smoothstep(0.478, 0.474, z)
    paint_red = np.clip(top * zone * np.maximum(zig, dots) * wear, 0, 1)
    # The thin ring bands only get a soft, broad fade: the fine wear mask is coarse along
    # the board (about 1.1 mm per pixel) and broke them into blocky marks.
    ring_wear = 0.80 + 0.20 * fbm(h, w, 3, 10, 26, octaves=2)
    paint_black = np.clip(np.maximum(top * zone * lines * wear, ring * ring_wear), 0, 1)
    c = mix(c, red, paint_red)
    c = mix(c, black, paint_black)
    paint = np.maximum(paint_red, paint_black)
    height = 0.5 * facets + 0.03 * grain + 0.06 * streak + 0.03 * paint
    rough = 0.55 - 0.13 * hand + 0.2 * paint + 0.06 * streak
    at.put(rect, c, normals(height, 5.0), ao=1.0 - 0.05 * (1 - streak), rough=rough)
    # End grain (board caps).
    _, h, w, U, V = at.block(A_ENDGRAIN)
    rr = np.sqrt((U - 0.5) ** 2 + (V - 0.5) ** 2)
    rings_ = 0.5 + 0.5 * np.sin(rr * 70.0 + 2 * fbm(h, w, 4, 4, 16))
    at.put(A_ENDGRAIN, mix(col((0.56, 0.41, 0.25)), col((0.66, 0.50, 0.32)), rings_), normals(rings_ * 0.2, 2.0), rough=0.7)

    # Leather grip: Poly Haven brown_leather, recoloured, with a spiral wrap seam.
    _, h, w, U, V = at.block(A_LEATHER)
    diff = ph_crop("clothing/brown_leather/brown_leather_diffuse_2k.jpg", h)
    nor = ph_crop("clothing/brown_leather/brown_leather_nor_gl_2k.jpg", h)
    arm = ph_crop("clothing/brown_leather/brown_leather_arm_2k.jpg", h)
    lum = diff.mean(axis=2) / max(float(diff.mean()), 1e-3) if diff is not None else 0.85 + 0.3 * fbm(h, w, 16, 16, 17)
    seam_ph = (U * 6.0 + V) % 1.0
    seam = smoothstep(0.06, 0.0, seam_ph) + smoothstep(0.94, 1.0, seam_ph)
    shade = smoothstep(0.0, 0.25, seam_ph)              # each turn overlaps the next: darker at the lap
    c = col((0.30, 0.18, 0.10)) * (0.75 + 0.25 * lum[..., None]) * (0.72 + 0.28 * shade[..., None])
    if nor is not None:
        n1 = nor * 2.0 - 1.0
        n1[..., :2] *= 0.6
        n1 = n1 / np.linalg.norm(n1, axis=2, keepdims=True)
    else:
        n1 = normals(fbm(h, w, 30, 30, 18), 1.5)
    n = blend_normals(n1, normals(0.6 * shade, 1.2))
    rough = np.clip(0.66 + 0.25 * arm[..., 1], 0.0, 0.92) if arm is not None else 0.75
    at.put(A_LEATHER, c, n, ao=0.7 + 0.3 * shade, rough=rough)

    # Finger-loop thongs: rolled suede (Poly Haven scuba_suede), dark brown.
    _, h, w, U, V = at.block(A_SUEDE)
    diff = ph_crop("clothing/scuba_suede/scuba_suede_diffuse_2k.jpg", h)
    nor = ph_crop("clothing/scuba_suede/scuba_suede_nor_gl_2k.jpg", h)
    lum = diff.mean(axis=2) / max(float(diff.mean()), 1e-3) if diff is not None else 0.85 + 0.3 * fbm(h, w, 16, 16, 19)
    twist = 0.5 + 0.5 * np.sin(2 * math.pi * (U * 10.0 + V))
    c = col((0.33, 0.21, 0.12)) * (0.8 + 0.2 * lum[..., None]) * (0.85 + 0.15 * twist[..., None])
    n1 = (nor * 2.0 - 1.0) if nor is not None else normals(fbm(h, w, 30, 30, 20), 1.5)
    n1 = blend_normals(n1 / np.linalg.norm(n1, axis=2, keepdims=True), normals(0.5 * twist, 1.5))
    at.put(A_SUEDE, c, n1, ao=0.85 + 0.15 * twist, rough=0.88)

    wrap_texture(at, A_SINEW, 26.0, 21)

    # Antler: off-white with long grooves and soft pores; the spur tip is worn smooth.
    _, h, w, U, V = at.block(A_ANTLER)
    grooves = fbm(h, w, 28, 2, 22, octaves=3)
    pores = smoothstep(0.60, 0.72, fbm(h, w, 24, 12, 23, octaves=2))
    tip = smoothstep(0.55, 1.0, U)
    c = mix(col((0.64, 0.58, 0.47)), col((0.86, 0.81, 0.70)), np.clip(0.45 + 0.55 * grooves + 0.3 * tip, 0, 1))
    c = c * (1.0 - 0.12 * (pores * (1 - tip))[..., None])
    at.put(A_ANTLER, c, normals(0.7 * grooves * (1 - 0.7 * tip) - 0.25 * pores, 3.0), ao=1.0 - 0.15 * pores,
           rough=0.52 - 0.18 * tip)

    # Green banded slate: olive-grey with dark bands and pale buff-green laminae, ground
    # smooth but not glossy (a satin stone, not polished metal).
    _, h, w, U, V = at.block(A_SLATE)
    warp = fbm(h, w, 3, 4, 24)
    ph = U * 6.0 + 1.1 * warp + 0.15 * np.sin(2 * math.pi * V)
    bands = smoothstep(0.2, 0.8, 0.5 + 0.5 * np.sin(2 * math.pi * (ph + 0.35 * np.sin(2 * math.pi * ph * 0.37))))
    lam = 0.5 + 0.5 * np.sin(2 * math.pi * (ph * 2.1 + 1.0 + 0.6 * fbm(h, w, 2, 5, 27)))
    light = smoothstep(0.86, 0.96, lam) * smoothstep(0.25, 0.55, fbm(h, w, 2, 6, 28))
    c = mix(col((0.20, 0.23, 0.18)), col((0.38, 0.41, 0.32)), bands)
    c = mix(c, col((0.60, 0.60, 0.49)), 0.8 * light)
    grit = fbm(h, w, 20, 32, 25, octaves=3)
    c = c * (0.92 + 0.16 * grit[..., None])
    at.put(A_SLATE, c, normals(0.2 * grit + 0.04 * light, 1.5), ao=0.96 + 0.04 * grit,
           rough=0.56 + 0.08 * grit + 0.04 * light)
    return at


def make_dart_textures():
    at = Atlas()
    L = DART_LEN
    # River cane: waxy yellow-tan, faint lengthwise streaks, darker sheath scars at the nodes.
    for rect, za, zb, seed in ((D_CANE_A, MAIN[0][0], CANE_SPLIT, 31), (D_CANE_B, CANE_SPLIT, L, 33)):
        _, h, w, U, V = at.block(rect)
        z = za + U * (zb - za)
        streak = fbm(h, w, 36, 4, seed, octaves=3)
        mott = fbm(h, w, 3, 14, seed + 1, octaves=3)
        node = np.zeros_like(z)
        for nz in NODES:
            node = np.maximum(node, smoothstep(0.014, 0.0, np.abs(z - nz)))
        fib = 0.5 + 0.5 * np.sin(2 * math.pi * (V * 48.0 + 0.8 * fbm(h, w, 5, 40, seed + 2)))
        c = mix(col((0.60, 0.50, 0.30)), col((0.74, 0.64, 0.42)), 0.45 * streak + 0.35 * mott + 0.2 * fib)
        c = mix(c, col((0.52, 0.42, 0.25)), 0.5 * node)
        fleck = smoothstep(0.66, 0.74, fbm(h, w, 40, 160, seed + 3, octaves=2))
        c = c * (1.0 - 0.10 * fleck[..., None])
        at.put(rect, c, normals(0.10 * streak + 0.05 * fib, 2.0), ao=1.0 - 0.12 * node, rough=0.34 + 0.08 * mott + 0.12 * node)
    # Cane end: the pale cut face of the butt lip.
    _, h, w, U, V = at.block(D_CANE_END)
    at.put(D_CANE_END, col((0.74, 0.64, 0.43)) * (0.9 + 0.2 * fbm(h, w, 6, 6, 32)[..., None]), rough=0.7)
    # Cup interior: dark, stained.
    _, h, w, U, V = at.block(D_CUP)
    at.put(D_CUP, col((0.20, 0.14, 0.09)) * (0.85 + 0.3 * fbm(h, w, 6, 6, 43)[..., None]), ao=0.55, rough=0.8)
    # Hardwood foreshaft.
    _, h, w, U, V = at.block(D_FORE)
    grain = 0.5 + 0.5 * np.sin(2 * math.pi * (V * 12.0 + 2.0 * fbm(h, w, 3, 10, 34)))
    streak = fbm(h, w, 24, 4, 44, octaves=3)
    c = mix(col((0.38, 0.24, 0.13)), col((0.52, 0.35, 0.20)), 0.4 * grain + 0.6 * streak)
    at.put(D_FORE, c, normals(0.1 * streak, 2.0), rough=0.46)
    # Barred wild-turkey primary: dark brown with narrower buff bars (about 1 : 2) sweeping
    # back from the rachis (v = 0), stepped and broken next to it, fine barbs, a slightly
    # frayed edge.
    _, h, w, U, V = at.block(D_FEATHER)
    ph = U * 9.0 + V * 1.1 + 0.3 * fbm(h, w, 3, 8, 35)
    ph = ph + 0.9 * smoothstep(0.32, 0.06, V) * (fbm(h, w, 2, 14, 49) - 0.5)
    bars = smoothstep(0.78, 0.90, 0.5 + 0.5 * np.sin(2 * math.pi * ph))
    bars = bars * (1.0 - 0.6 * smoothstep(0.62, 0.74, fbm(h, w, 16, 60, 50, octaves=2)))
    barbs = 0.5 + 0.5 * np.sin(2 * math.pi * (U * 90.0 - V * 22.0 + 2.0 * fbm(h, w, 4, 12, 36)))
    tint = fbm(h, w, 3, 6, 48)
    dark = mix(col((0.16, 0.11, 0.075)), col((0.25, 0.17, 0.10)), fbm(h, w, 4, 10, 51))   # faint bronze
    c = mix(dark, mix(col((0.55, 0.47, 0.34)), col((0.70, 0.62, 0.47)), tint), bars * (0.8 + 0.2 * tint))
    c = c * (0.90 + 0.10 * barbs[..., None])
    quill = smoothstep(0.09, 0.03, V)
    c = mix(c, col((0.84, 0.78, 0.64)), quill)
    fray = smoothstep(0.82, 1.0, V) * fbm(h, w, 4, 30, 37)
    c = c * (1.0 - 0.3 * fray[..., None])
    at.put(D_FEATHER, c, normals(0.3 * barbs, 1.2), ao=1.0 - 0.2 * fray, rough=0.74)
    wrap_texture(at, D_SINEW, 30.0, 38)
    # Chert: grey-brown, mottled and faintly banded, with conchoidal flake scars and finer
    # retouch scars along the two edges (v = 0, 0.5, 1 on the 8-sided lens).
    _, h, w, U, V = at.block(D_CHERT)
    big = scallops(h, w, 120, 39)
    small = scallops(h, w, 520, 40)
    edge = np.maximum(smoothstep(0.12, 0.0, np.minimum(V, 1 - V)), smoothstep(0.12, 0.0, np.abs(V - 0.5)))
    sc = big * (1 - edge) + small * edge
    mott = fbm(h, w, 5, 5, 41)
    band = 0.5 + 0.5 * np.sin(2 * math.pi * (U * 3.0 + 0.8 * fbm(h, w, 3, 3, 42)))
    c = mix(col((0.34, 0.31, 0.28)), col((0.52, 0.48, 0.42)), 0.6 * mott + 0.4 * band)
    c = mix(c, col((0.55, 0.42, 0.34)), 0.3 * smoothstep(0.55, 0.8, fbm(h, w, 3, 3, 45)))
    c = c * (0.88 + 0.2 * sc[..., None])
    at.put(D_CHERT, c, normals(sc ** 1.2, 3.2), ao=0.85 + 0.15 * sc, rough=0.42 + 0.12 * (1 - sc))
    # Paint (ochre red, charcoal black).
    for rect, base, seed in ((D_RED, (0.55, 0.15, 0.07), 46), (D_BLACK, (0.07, 0.055, 0.045), 47)):
        _, h, w, U, V = at.block(rect)
        n = fbm(h, w, 8, 8, seed)
        at.put(rect, col(base) * (0.88 + 0.24 * n[..., None]), normals(0.15 * n, 1.0), rough=0.78)
    return at


def gltf_settings_group():
    try:
        from io_scene_gltf2.blender.com.material_helpers import create_settings_group, get_gltf_node_name
        name = get_gltf_node_name()
        return bpy.data.node_groups.get(name) or create_settings_group(name)
    except Exception as e:  # pragma: no cover - addon layout changed
        print("WARNING no glTF settings group (occlusion not exported):", e)
        return None


def make_material(name, images, double_sided=False):
    color, normal, orm = images
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexImage")
    tc.image = color
    tc.location = (-700, 300)
    nt.links.new(tc.outputs["Color"], bsdf.inputs["Base Color"])
    to = nt.nodes.new("ShaderNodeTexImage")
    to.image = orm
    to.location = (-900, 0)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    sep.location = (-600, 0)
    nt.links.new(to.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = normal
    tn.location = (-900, -300)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.location = (-600, -300)
    nm.uv_map = "UVMap"
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    grp = gltf_settings_group()
    if grp is not None:
        gn = nt.nodes.new("ShaderNodeGroup")
        gn.node_tree = grp
        gn.location = (-300, -500)
        nt.links.new(sep.outputs["Red"], gn.inputs["Occlusion"])
    m.use_backface_culling = not double_sided
    return m


# --------------------------------------------------------------------------
# Export
# --------------------------------------------------------------------------
def add_empty(name, godot_pos, parent):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 0.02
    e.location = G(*godot_pos)
    e.parent = parent
    bpy.context.scene.collection.objects.link(e)
    return e


def export_glb(obj, path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for c in obj.children:
        c.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=True, export_normals=True,
        export_materials="EXPORT", export_image_format="AUTO",
        export_cameras=False, export_lights=False, export_extras=False)


def rnd(v, k=4):
    return [round(float(c), k) for c in v]


# --------------------------------------------------------------------------
# Preview renders
# --------------------------------------------------------------------------
def _flat(name, color, emission=0.0):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return m


def _box(name, center_g, size_g, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=G(*center_g))
    o = bpy.context.active_object
    o.name = name
    o.scale = (size_g[0], size_g[2], size_g[1])
    o.data.materials.append(mat)
    return o


def _sphere(name, center_g, r, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=G(*center_g), segments=16, ring_count=8)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    return o


def _text(body, loc_g, size, mat, view):
    cu = bpy.data.curves.new("txt_" + body, type="FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    o = bpy.data.objects.new("txt_" + body, cu)
    o.location = G(*loc_g)
    o.rotation_euler = (math.pi / 2, 0.0, math.pi / 2) if view == "side" else (0.0, 0.0, -math.pi / 2)
    o.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(o)
    return o


def _camera(name, loc_g, target_g, ortho=None, lens=50.0, roll_top=False):
    cd = bpy.data.cameras.new(name)
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    cd.clip_start = 0.002
    cd.clip_end = 20.0
    cam = bpy.data.objects.new(name, cd)
    cam.location = G(*loc_g)
    if roll_top:
        cam.rotation_euler = (0.0, 0.0, -math.pi / 2)
    else:
        d = G(*target_g) - G(*loc_g)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(cam)
    return cam


def render_previews(out_dir, atlatl, dart, info):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    try:
        sc.eevee.taa_render_samples = 48
    except AttributeError:
        pass
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("PreviewWorld")
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.60, 0.62, 0.66, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    sc.world = world
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.4
    sun.angle = math.radians(6)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(38), math.radians(-22), math.radians(-60))
    sc.collection.objects.link(so)

    white, black = _flat("RulerWhite", (0.92, 0.92, 0.92)), _flat("RulerBlack", (0.02, 0.02, 0.02))
    red, green, blue = _flat("MkRed", (0.95, 0.05, 0.03), 2.0), _flat("MkGreen", (0.05, 0.8, 0.1), 2.0), _flat("MkBlue", (0.1, 0.3, 1.0), 2.0)

    L = DART_LEN
    hook = Vector(HOOK_POS)
    groups = {}
    # Top-view ruler: 5 cm blocks along Z, below the atlatl in the image.
    g = []
    for i in range(-1, 12):
        g.append(_box("rt%d" % i, (-0.085, -0.02, (i + 0.5) * 0.05), (0.008, 0.002, 0.05), black if i % 2 else white))
    for i in range(0, 7):
        g.append(_text("%d" % (i * 10), (-0.100, -0.02, i * 0.1), 0.012, black, "top"))
    g.append(_text("Godot Z (cm), origin = grip, forward = -Z", (-0.118, -0.02, 0.25), 0.011, black, "top"))
    groups["ruler_top"] = g
    # Side-view ruler (atlatl): 5 cm blocks along Z below the board.
    g = []
    for i in range(-1, 12):
        g.append(_box("rs%d" % i, (-0.03, -0.042, (i + 0.5) * 0.05), (0.002, 0.006, 0.05), black if i % 2 else white))
    for i in range(0, 7):
        g.append(_text("%d" % (i * 10), (-0.03, -0.058, i * 0.1), 0.011, black, "side"))
    for i in range(-1, 2):
        g.append(_box("ry%d" % i, (-0.03, (i + 0.5) * 0.02, -0.06), (0.002, 0.02, 0.004), black if i % 2 else white))
    g.append(_text("Y 2 cm blocks", (-0.03, 0.036, -0.06), 0.008, black, "side"))
    groups["ruler_side"] = g
    # Long ruler for the loaded view: 10 cm blocks from -1.3 to 0.6.
    g = []
    for i in range(-13, 6):
        g.append(_box("rl%d" % i, (-0.05, -0.07, (i + 0.5) * 0.1), (0.002, 0.012, 0.1), black if i % 2 else white))
    for i in range(-12, 7, 2):
        g.append(_text("%d" % (i * 10), (-0.05, -0.105, i * 0.1), 0.028, black, "side"))
    g.append(_text("Godot Z (cm): Muzzle (green) = Hook (red) - %.2f m; COM blue" % L, (-0.05, 0.075, -0.4), 0.03, black, "side"))
    groups["ruler_long"] = g
    # Markers.
    groups["markers"] = [_sphere("mk_hook", HOOK_POS, 0.0022, red), _sphere("mk_com", info["atlatl_com"], 0.003, blue),
                         _sphere("mk_origin", (0, 0, 0), 0.002, blue)]
    groups["muzzle"] = [_sphere("mk_muzzle", (HOOK_POS[0], HOOK_POS[1], HOOK_POS[2] - L), 0.012, green),
                        _sphere("mk_hook_big", HOOK_POS, 0.010, red),
                        _sphere("mk_dcom", (0.0, HOOK_POS[1], HOOK_POS[2] - L + info["dart_com"][2]), 0.010, blue)]
    groups["dart_markers"] = [_sphere("mk_tip", (0, 0, 0), 0.0015, green), _sphere("mk_nock", (0, 0, L), 0.0012, red)]
    # Floor for perspective shots.
    bpy.ops.mesh.primitive_plane_add(size=3.0, location=G(0, -0.05, 0.3))
    floor = bpy.context.active_object
    fm = _flat("Floor", (0.47, 0.45, 0.42))
    floor.data.materials.append(fm)
    groups["floor"] = [floor]

    seated = G(HOOK_POS[0], HOOK_POS[1], HOOK_POS[2] - L)
    # (name, camera, resolution, visible groups, show atlatl, dart placement: None | "seated" | "alone")
    shots = [
        ("atlatl_top", _camera("c_top", (0.0, 1.0, 0.26), None, ortho=0.66, roll_top=True), (1800, 700),
         ["ruler_top", "markers"], True, None),
        ("atlatl_side", _camera("c_side", (1.0, 0.0, 0.26), (0.0, 0.0, 0.26), ortho=0.66), (1800, 520),
         ["ruler_side", "markers"], True, None),
        ("atlatl_3q", _camera("c_3q", (0.30, 0.26, -0.20), (0.0, -0.005, 0.25), lens=45), (1600, 1000),
         ["floor"], True, None),
        ("atlatl_seat_side", _camera("c_seat", (1.0, 0.0, 0.26), (0.0, 0.0, 0.26), ortho=0.66), (1800, 520),
         ["ruler_side"], True, "seated"),
        ("atlatl_hook_detail", _camera("c_hook", (0.085, 0.060, 0.600), (0.0, 0.014, 0.528), lens=50), (1400, 1000),
         [], True, "seated"),
        ("atlatl_cap_detail", _camera("c_cap", (0.080, 0.020, 0.620), (0.0, 0.004, 0.530), lens=50), (1400, 1000),
         [], True, None),
        ("atlatl_stone_detail", _camera("c_stone", (0.110, 0.080, 0.160), (0.0, -0.002, 0.245), lens=50), (1400, 1000),
         [], True, None),
        ("atlatl_grip_detail", _camera("c_grip", (0.10, 0.14, -0.10), (0.0, 0.0, 0.035), lens=50), (1400, 1000),
         [], True, "seated"),
        ("atlatl_loaded_side", _camera("c_loaded", (2.0, 0.0, -0.36), (0.0, 0.0, -0.36), ortho=2.05), (2400, 560),
         ["ruler_long", "muzzle"], True, "seated"),
        ("atlatl_loaded_3q", _camera("c_l3q", (0.55, 0.38, 0.95), (0.0, 0.0, -0.25), lens=35), (1600, 1000),
         ["floor"], True, "seated"),
        ("atlatl_dart_point", _camera("c_point", (0.075, 0.050, -0.040), (0.0, 0.0, 0.045), lens=50), (1400, 1000),
         ["dart_markers"], False, "alone"),
        ("atlatl_dart_fletch", _camera("c_fletch", (0.16, 0.12, L - 0.02), (0.0, 0.0, L - 0.16), lens=40), (1400, 1000),
         [], False, "alone"),
    ]
    for name, cam, (w, h), show, show_atlatl, dart_mode in shots:
        for key, objs in groups.items():
            for o in objs:
                o.hide_render = key not in show
        atlatl.hide_render = not show_atlatl
        dart.hide_render = dart_mode is None
        dart.location = seated if dart_mode == "seated" else Vector((0, 0, 0))
        sc.camera = cam
        sc.render.resolution_x, sc.render.resolution_y = w, h
        sc.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)
    dart.location = Vector((0, 0, 0))


# --------------------------------------------------------------------------
# Verification: re-import the GLBs and check the conventions
# --------------------------------------------------------------------------
def _clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def _import(path):
    _clear_scene()
    bpy.ops.import_scene.gltf(filepath=path)
    objs = list(bpy.context.scene.objects)
    meshes = [o for o in objs if o.type == "MESH"]
    empties = {o.name.split(".")[0]: o for o in objs if o.type == "EMPTY"}

    def godot(v):
        return Vector((v.x, v.z, -v.y))
    pts, polys = [], []
    for m in meshes:
        base = len(pts)
        pts += [godot(m.matrix_world @ v.co) for v in m.data.vertices]
        polys += [[base + i for i in poly.vertices] for poly in m.data.polygons]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    marks = {k: godot(o.matrix_world.translation) for k, o in empties.items()}
    ntri = sum(tris(m.data) for m in meshes)
    imgs = sorted({n.image.name for m in meshes for s in m.material_slots if s.material
                   for n in s.material.node_tree.nodes if n.type == "TEX_IMAGE" and n.image})
    has_normal = any(n.type == "NORMAL_MAP" for m in meshes for s in m.material_slots if s.material for n in s.material.node_tree.nodes)
    return {"meshes": [m.name for m in meshes], "lo": lo, "hi": hi, "markers": marks, "tris": ntri,
            "images": imgs, "normal_map": has_normal, "pts": pts, "polys": polys}


def seat_gaps(a, d):
    """Vertical gaps between a seated dart (Nock on Hook, no relative rotation) and the
    atlatl, from the re-imported meshes: rays down from every dart vertex onto the atlatl
    and up from every atlatl vertex onto the dart, ignoring the hook end (z > 0.515) where
    the spur sits in the butt cup by design. Returns {"shaft": m, "vanes": m}; a negative
    shaft gap means the two intersect."""
    from mathutils.bvhtree import BVHTree
    off = Vector((HOOK_POS[0], HOOK_POS[1], HOOK_POS[2] - DART_LEN))
    ta = BVHTree.FromPolygons([tuple(p) for p in a["pts"]], a["polys"])
    td = BVHTree.FromPolygons([tuple(p + off) for p in d["pts"]], d["polys"])
    gaps = {"shaft": 1.0, "vanes": 1.0}
    down, up = Vector((0, -1, 0)), Vector((0, 1, 0))

    def note(dart_pt, dist, inside):
        kind = "vanes" if math.hypot(dart_pt.x - off.x, dart_pt.y - off.y) > 0.009 else "shaft"
        gaps[kind] = min(gaps[kind], -dist if inside and kind == "shaft" else dist)
    for p in d["pts"]:
        q = p + off
        if q.z > 0.515:
            continue
        hit, nrm, _, dist = ta.ray_cast(q, down, 0.05)
        if hit is not None:
            note(q, dist, nrm.y < 0.0)        # a back face: the dart vertex is inside the atlatl
    for p in a["pts"]:
        if p.z > 0.515:
            continue
        hit, nrm, _, dist = td.ray_cast(p, up, 0.05)
        if hit is not None:
            note(hit, dist, nrm.y > 0.0)      # the atlatl vertex is inside the dart
    return gaps


def verify(atlatl_path, dart_path):
    fails = []

    def check(cond, msg):
        print(("  ok   " if cond else "  FAIL ") + msg)
        if not cond:
            fails.append(msg)
    L = DART_LEN
    print("VERIFY", atlatl_path)
    a = _import(atlatl_path)
    mk = a["markers"]
    size = a["hi"] - a["lo"]
    print("  atlatl bbox lo %s hi %s size %s tris %d images %s" % (rnd(a["lo"]), rnd(a["hi"]), rnd(size), a["tris"], a["images"]))
    print("  atlatl markers", {k: rnd(v) for k, v in mk.items()})
    check(set(["Hook", "Spur", "Muzzle", "COM"]) <= set(mk), "atlatl has Hook, Spur, Muzzle, COM")
    if set(["Hook", "Spur", "Muzzle", "COM"]) <= set(mk):
        check((mk["Hook"] - mk["Spur"]).length < 1e-5, "Hook == Spur")
        check((mk["Hook"] - Vector(HOOK_POS)).length < 1e-4, "Hook at %s" % (HOOK_POS,))
        check((mk["Muzzle"] - (mk["Hook"] - Vector((0, 0, L)))).length < 1e-4, "Muzzle = Hook - (0, 0, %.2f): tip of a seated dart" % L)
        check(mk["Muzzle"].z < -1.0 and mk["Hook"].z > 0.4, "forward is -Z (Muzzle ahead of the grip, Hook behind it)")
        check(a["lo"].z - 1e-3 <= mk["COM"].z <= a["hi"].z + 1e-3, "COM inside the board")
    check(0.50 <= size.z <= 0.65, "board length %.3f m (~55 cm)" % size.z)
    check(size.z > size.x and size.z > size.y, "longest axis is Z")
    check(a["lo"].z < -0.02 and a["hi"].z > 0.5, "origin (grip) at the front end, hook at the far end")
    check(abs(a["lo"].x + a["hi"].x) < 1e-3, "symmetric about X = 0")
    check(1000 <= a["tris"] <= 4000, "atlatl %d tris (1-4k)" % a["tris"])
    check(len(a["images"]) == 3 and a["normal_map"], "atlatl has colour, normal and ORM textures")
    hook_top = max(p.y for p in a["pts"] if p.z > 0.515)
    check(abs(hook_top - (HOOK_POS[1] + 0.0064)) < 0.004, "hook top %.4f is level with the dart's top" % hook_top)

    print("VERIFY", dart_path)
    d = _import(dart_path)
    mk = d["markers"]
    size = d["hi"] - d["lo"]
    print("  dart bbox lo %s hi %s size %s tris %d images %s" % (rnd(d["lo"]), rnd(d["hi"]), rnd(size), d["tris"], d["images"]))
    print("  dart markers", {k: rnd(v) for k, v in mk.items()})
    check(set(["COM", "Nock"]) <= set(mk), "dart has COM and Nock")
    tip = min(d["pts"], key=lambda p: p.length)
    check(tip.length < 5e-4, "a vertex at the origin: the point's tip (%.5f m)" % tip.length)
    check(abs(d["lo"].z) < 1e-4, "nothing ahead of the tip (min z %.5f)" % d["lo"].z)
    check(abs(d["hi"].z - L) < 1e-4, "butt at z = %.2f" % L)
    if set(["COM", "Nock"]) <= set(mk):
        check((mk["Nock"] - Vector((0, 0, L))).length < 1e-4, "Nock at (0, 0, %.2f)" % L)
        check(0.3 * L < mk["COM"].z < 0.5 * L and abs(mk["COM"].x) + abs(mk["COM"].y) < 1e-4, "COM on the axis, %.0f %% back from the tip" % (100 * mk["COM"].z / L))
    check(1.55 <= size.z <= 1.75, "dart length %.3f m (~1.6 m)" % size.z)
    check(600 <= d["tris"] <= 4000, "dart %d tris (0.6-4k)" % d["tris"])
    check(len(d["images"]) == 3 and d["normal_map"], "dart has colour, normal and ORM textures")
    # Seated clearance: the dart's hen vanes must clear the board.
    vane_low = min(p.y for p in d["pts"] if FLETCH[0] < p.z < FLETCH[1])
    check(HOOK_POS[1] + vane_low > 0.0070, "seated dart's lowest vane edge %.4f m above the board axis" % (HOOK_POS[1] + vane_low))
    gaps = seat_gaps(a, d)
    check(gaps["shaft"] >= SEAT_GAP, "seated dart shaft clears the grip, lashings and stone by %.1f mm (>= %.1f)"
          % (gaps["shaft"] * 1000, SEAT_GAP * 1000))
    check(gaps["vanes"] >= 0.0015, "seated dart's vanes clear the board by %.1f mm (>= 1.5)" % (gaps["vanes"] * 1000))
    print("VERIFY %s" % ("OK" if not fails else "FAILED: " + "; ".join(fails)))
    return not fails


# --------------------------------------------------------------------------
def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(PROJECT, "assets", "weapons", "atlatl.glb"))
    ap.add_argument("--dart-out", default=os.path.join(PROJECT, "assets", "weapons", "atlatl_dart.glb"))
    ap.add_argument("--renders", default=None)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--no-verify", action="store_true")
    args = ap.parse_args(argv)
    _clear_scene()

    # Atlatl.
    a_imgs = make_atlatl_textures().images("atlatl")
    a_mat = make_material("AtlatlMat", a_imgs)
    me, amass = build_atlatl_mesh()
    me.materials.append(a_mat)
    atlatl = bpy.data.objects.new("Atlatl", me)
    bpy.context.scene.collection.objects.link(atlatl)
    acom = amass.com()
    acom = (0.0, round(acom.y, 4), round(acom.z, 4))
    markers = {"Hook": HOOK_POS, "Spur": HOOK_POS, "Muzzle": (HOOK_POS[0], HOOK_POS[1], HOOK_POS[2] - DART_LEN), "COM": acom}
    for k, p in markers.items():
        add_empty(k, p, atlatl)
    export_glb(atlatl, args.out)
    print("EXPORTED", args.out)
    # Free the names for the dart: its images get the same names so that Godot's
    # extracted textures read <glb>_atlatl_{atlas,normal,orm}.png for both GLBs.
    for im in a_imgs:
        im.name = im.name.replace("atlatl_", "atlatl_board_")
    for c in atlatl.children:
        c.name = "Atlatl" + c.name

    # Dart.
    d_imgs = make_dart_textures().images("atlatl")
    d_mat = make_material("AtlatlDartMat", d_imgs)
    f_mat = make_material("AtlatlDartVanes", d_imgs, double_sided=True)
    dme, dmass = build_dart_mesh()
    dme.materials.append(d_mat)
    dme.materials.append(f_mat)
    dart = bpy.data.objects.new("AtlatlDart", dme)
    bpy.context.scene.collection.objects.link(dart)
    dcom = (0.0, 0.0, round(dmass.com().z, 4))
    add_empty("COM", dcom, dart)
    add_empty("Nock", (0.0, 0.0, DART_LEN), dart)
    export_glb(dart, args.dart_out)
    print("EXPORTED", args.dart_out)

    info = {"atlatl_tris": tris(me), "dart_tris": tris(dme), "atlatl_markers": markers, "atlatl_com": acom,
            "atlatl_mass_g": round(amass.m * 1000, 1), "atlatl_parts_g": {k: round(v * 1000, 1) for k, v in amass.parts.items()},
            "dart_len": DART_LEN, "dart_com": dcom, "dart_mass_g": round(dmass.m * 1000, 1),
            "dart_parts_g": {k: round(v * 1000, 1) for k, v in dmass.parts.items()}}
    print("MODEL INFO " + json.dumps(info))

    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    if args.renders:
        render_previews(args.renders, atlatl, dart, info)
    if not args.no_verify:
        ok = verify(args.out, args.dart_out)
        if not ok:
            sys.exit(1)


if __name__ == "__main__":
    main()
