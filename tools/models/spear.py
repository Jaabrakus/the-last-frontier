"""Procedural throwing spear for Frontier (1750s eastern woodlands).

A light, javelin-style spear:
  * a forged iron trade point: leaf blade with a midrib and filed (bright) edges, a
    moulded neck and a conical split socket (open seam underneath) held by an iron
    rivet through the socket and the shaft's tenon; bare grey iron with patches of
    dark forge scale and a little rust;
  * a hand-shaved ash shaft, thickest behind the grip, painted with charcoal-black and
    white-clay bands (black zigzag on white behind the point);
  * sinew lashing behind the socket mouth, and a blue stroud tie with its undyed white
    selvage ("list"), knotted on one side, with two short stroud tails and a tuft of
    red-dyed deer hair hanging from the knot;
  * a leather grip wrap bound with rawhide thongs at the balance point (the spiral of
    the wrap and the lashing turns are baked into the albedo and normal maps).

The blue-and-white stroud and the red hair are the spear's own accent; the atlatl dart
keeps red/black cresting and barred turkey fletching, so the two read apart at range.

Run headless (factory scene):
  Blender -b --factory-startup --python tools/models/spear.py -- \
      [--out assets/weapons/spear.glb] [--renders DIR] [--blend FILE.blend]

Conventions (Godot / glTF axes), as scripts/weapons/weapon_models_throwables.gd expects:
  * origin = the throwing-hand grip = the balance point. The script computes the
    centre of mass from the part volumes and densities (ash, iron, sinew, wool, hair),
    puts the origin there and centres the grip wrap on it, so a throw launched from the
    hand is launched from the COM. A javelin is thrown held at its balance; with the
    iron point that is about 45% of the length from the point (55% from the butt). The
    run prints the mass table and TIP / BUTT; keep SPEAR_TIP and SPEAR_BUTT in
    scripts/weapons/weapon_models_throwables.gd in step.
  * forward = -Z: the point is at z = -TIP, the butt at z = +BUTT, 1.80 m overall.
  * up = +Y; the blade's flats face +/-Y and its edges +/-X.
  * two mesh nodes, one material:
      Spear  the spear itself (shaft, iron, grip, lashing, tie band and knot);
      Trim   child of Spear: the stroud tails and the hair tuft. Its origin (pivot) is
             the knot on the +X side of the shaft; at rest the trim trails back (+Z)
             and hangs at most 5 cm below the axis (-Y). Scripts re-hang it by rotating
             the node: about its X to stream it back in flight, about its Z to lay it
             out on the ground (ThrownProjectile does both).
  * markers (empties, children of Spear): Muzzle and Tip (both at the point, written
    from the one TIP value), COM (the origin), Butt (the butt end).
  * the material has a base colour atlas, a metallic/roughness map (glTF: G =
    roughness, B = metallic) and a tangent-space normal map (OpenGL / glTF +Y), all
    generated here. Bare iron is sRGB ~0.55-0.67 at metallic 1 (filed edges ~0.79),
    forge scale is dark at metallic 0.3, rust is not metallic. The leather wrap and the
    wool use read-only crops of the CC0 Poly Haven brown_leather and caban textures in
    assets/polyhaven when present.

Blender works Z-up and the glTF exporter maps Blender (x, y, z) to glTF (x, z, -y),
so geometry is written in Godot coordinates through G(x, y, z).
"""

import argparse
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

# --------------------------------------------------------------------------
# Layout. u = metres from the butt end along the axis (0 = butt, LENGTH = tip).
# --------------------------------------------------------------------------
LENGTH = 1.80
U_TIP = LENGTH
U_NECK = 1.645          # blade shoulders -> round neck
U_SOCKET = 1.633        # moulded collar -> socket
U_MOUTH = 1.555         # socket mouth (the shaft disappears into the socket here)
U_SHAFT_END = 1.612     # end of the shaft's tenon inside the socket (mass only)
BLADE_LEN = U_TIP - U_NECK
IRON_LEN = U_TIP - U_MOUTH
RIVET_U = 1.578         # through the socket and the tenon, 2.3 cm in front of the mouth
LASH_U = (1.521, 1.553)          # sinew lashing
TIE_U = (1.498, 1.518)           # stroud tie (the trim hangs from its knot)
TIE_MID = 0.5 * (TIE_U[0] + TIE_U[1])
GRIP_HALF = 0.080                # leather grip wrap, centred on the balance point
THONG = 0.0075                   # rawhide thong band at each end of the wrap
GRIP_PITCH = 0.024               # spiral pitch of the (baked) leather wrap
SIDES = 12

# Shaft radius (u, r). Thickest just behind the grip, slimmer toward the point; the
# tenon inside the socket follows the socket's bore (mass only, not meshed).
SHAFT_R = [(0.0, 0.0078), (0.0015, 0.0100), (0.005, 0.0117), (0.012, 0.0124), (0.10, 0.0128),
           (0.40, 0.0131), (0.85, 0.0128), (1.10, 0.0121), (1.35, 0.0114), (U_MOUTH, 0.0108),
           (RIVET_U, 0.0094), (1.595, 0.0081), (U_SHAFT_END, 0.0068)]

# Leaf blade: (s, half width, midrib half thickness); s = 0 at the tip, 1 at the neck.
BLADE_KEYS = [(0.00, 0.0000, 0.0000), (0.02, 0.0017, 0.0005), (0.05, 0.0037, 0.0008),
              (0.09, 0.0062, 0.0011), (0.14, 0.0092, 0.0015), (0.20, 0.0120, 0.0018),
              (0.27, 0.0142, 0.0021), (0.35, 0.0160, 0.0024), (0.44, 0.0174, 0.0026),
              (0.53, 0.0182, 0.0027), (0.62, 0.0183, 0.0028), (0.70, 0.0174, 0.0029),
              (0.78, 0.0154, 0.0031), (0.85, 0.0126, 0.0035), (0.91, 0.0098, 0.0042),
              (0.96, 0.0077, 0.0052), (1.00, 0.0066, 0.0062)]


def _densify(keys, upto):
    """Adds a Catmull-Rom midpoint between the keys up to s = `upto`, so the leaf's
    outline stays round where it curves most (the savings from the baked wraps)."""
    out = [keys[0]]
    n = len(keys)
    for i in range(n - 1):
        p0 = keys[i - 1] if i > 0 else tuple(2 * a - b for a, b in zip(keys[0], keys[1]))
        p1, p2 = keys[i], keys[i + 1]
        p3 = keys[i + 2] if i + 2 < n else p2
        if p2[0] <= upto:
            mid = tuple((-a + 9 * b + 9 * c - d) / 16.0 for a, b, c, d in zip(p0, p1, p2, p3))
            out.append((0.5 * (p1[0] + p2[0]), max(mid[1], 0.0), max(mid[2], 0.0)))
        out.append(p2)
    return out


BLADE = _densify(BLADE_KEYS, 0.78)
NECK_R = 0.0064
# Blade cross-section (x along the edges, y along the midrib), 12 points like the
# round rings so the blade blends into the neck: edge, bevel line, flat, midrib, ...
LENS = [(1.0, 0.0), (0.80, 0.30), (0.45, 0.72), (0.0, 1.0), (-0.45, 0.72), (-0.80, 0.30),
        (-1.0, 0.0), (-0.80, -0.30), (-0.45, -0.72), (0.0, -1.0), (0.45, -0.72), (0.80, -0.30)]
SHARP_COLS = (0, 1, 3, 5, 6, 7, 9, 11)     # edges, bevel lines and the midrib stay crisp
# Collar and socket rings (u, outer radius), from the neck back to the mouth.
IRON_ROUND = [(1.641, 0.0071), (1.638, 0.0075), (1.635, 0.0073), (U_SOCKET, 0.0069),
              (1.615, 0.0081), (1.595, 0.0097), (1.575, 0.0113), (1.561, 0.0123),
              (1.557, 0.0127), (U_MOUTH, 0.0127)]
SOCKET_WALL = 0.0015

# Densities (kg/m^3) and small fixed masses (kg) for the balance.
ASH, IRON, SINEW = 670.0, 7750.0, 1150.0
TIE_MASS, HAIR_MASS, RIVET_MASS = 0.0035, 0.0020, 0.002

# Paint on the wood: (u0, u1, kind); "zig" is a band of black triangles (on the white).
PAINT = [(0.040, 0.047, "black"), (0.047, 0.085, "white"), (0.085, 0.092, "black"),
         (1.400, 1.408, "black"), (1.408, 1.458, "white"), (1.421, 1.447, "zig"),
         (1.458, 1.466, "black")]
BLACK = (0.07, 0.06, 0.05)
WHITE = (0.80, 0.77, 0.70)       # white clay
STROUD_BLUE = (0.13, 0.20, 0.44)
LIST_WHITE = (0.84, 0.82, 0.75)  # the undyed selvage of the stroud
HAIR_RED = (0.66, 0.10, 0.05)

# Atlas (pixels; rows count up from the bottom, v up, like Blender images).
ATLAS = 1024
WOOD_ROWS = [(512, 682), (682, 852), (852, 1022)]   # three strips along the shaft
REG = {
    "grip": (0, 512, 256, 512),
    "lash": (512, 768, 256, 512),
    "tie": (768, 1024, 256, 512),
    "iron": (0, 512, 0, 256),
    "tails": (512, 768, 0, 256),
    "hair": (768, 1024, 128, 256),
    "end": (768, 896, 0, 128),
}
TIE_FU = 0.6                     # the tie band uses fu 0..0.6 of its region, the knot the rest
MARGIN = 2.0

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
POLYHAVEN = os.path.join(PROJECT, "assets", "polyhaven", "textures")


def G(x, y, z):
    """Godot-space point expressed in Blender coordinates."""
    return Vector((x, -z, y))


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def interp(table, x):
    xs = [p[0] for p in table]
    return float(np.interp(x, xs, [p[1] for p in table]))


def shaft_r(u):
    return interp(SHAFT_R, u)


def blade_at(s):
    xs = [b[0] for b in BLADE]
    return float(np.interp(s, xs, [b[1] for b in BLADE])), float(np.interp(s, xs, [b[2] for b in BLADE]))


def blade_section(s):
    """12 (x, y) points of the blade at s, blended into the round neck near s = 1."""
    w, t = blade_at(s)
    rnd = float(smoothstep(0.80, 1.0, s))
    pts = []
    for k, (a, b) in enumerate(LENS):
        ang = 2.0 * math.pi * k / SIDES
        pts.append((lerp(a * w, NECK_R * math.cos(ang), rnd), lerp(b * t, NECK_R * math.sin(ang), rnd)))
    return pts


def polygon_area(pts):
    return 0.5 * abs(sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1])))


# --------------------------------------------------------------------------
# Balance point
# --------------------------------------------------------------------------
def mass_properties():
    """[(part, kg, centroid u)] and the COM (u). The grip wrap is centred on the COM,
    so it cannot move it and is left out."""
    parts = []
    us = np.linspace(0.0, U_SHAFT_END, 3201)
    mid = 0.5 * (us[1:] + us[:-1])
    r = np.array([shaft_r(u) for u in mid])
    m = ASH * math.pi * r ** 2 * np.diff(us)
    parts.append(("ash shaft + tenon", m.sum(), float((m * mid).sum() / m.sum())))
    ss = np.linspace(0.0, 1.0, 801)
    bm = bz = 0.0
    for s0, s1 in zip(ss, ss[1:]):
        s = 0.5 * (s0 + s1)
        dm = IRON * polygon_area(blade_section(s)) * (s1 - s0) * BLADE_LEN
        bm += dm
        bz += dm * (U_TIP - s * BLADE_LEN)
    parts.append(("iron blade", bm, bz / bm))
    # Collar: solid. Socket: a shell of SOCKET_WALL.
    cm = cz = 0.0
    for (u0, r0), (u1, r1) in zip(IRON_ROUND, IRON_ROUND[1:]):
        ra = 0.5 * (r0 + r1)
        solid = min(u0, u1) > U_SOCKET - 1e-6     # the collar; the socket is a shell
        area = math.pi * ra ** 2 if solid else math.pi * (ra ** 2 - max(ra - SOCKET_WALL, 0.0) ** 2)
        dm = IRON * area * abs(u0 - u1)
        cm += dm
        cz += dm * 0.5 * (u0 + u1)
    cm += IRON * math.pi * NECK_R ** 2 * (U_NECK - 1.641)
    cz += IRON * math.pi * NECK_R ** 2 * (U_NECK - 1.641) * 0.5 * (U_NECK + 1.641)
    parts.append(("iron neck + socket", cm, cz / cm))
    parts.append(("iron rivet", RIVET_MASS, RIVET_U))
    lash_len = LASH_U[1] - LASH_U[0]
    lm = SINEW * 2.0 * math.pi * shaft_r(sum(LASH_U) / 2) * 0.0014 * lash_len
    parts.append(("sinew lashing", lm, sum(LASH_U) / 2))
    parts.append(("stroud tie + tails", TIE_MASS, TIE_MID - 0.02))
    parts.append(("deer-hair tuft", HAIR_MASS, TIE_MID - 0.03))
    total = sum(p[1] for p in parts)
    com = sum(p[1] * p[2] for p in parts) / total
    return parts, total, com


PARTS, TOTAL_MASS, U_COM = mass_properties()
TIP = U_TIP - U_COM          # origin -> point (metres toward -Z)
BUTT = U_COM                 # origin -> butt (metres toward +Z)


def Z(u):
    """Godot z of the axis point u metres from the butt."""
    return U_COM - u


def U_of(z):
    return U_COM - z


# The knot of the tie, on the +X side of the shaft: the trim's pivot.
KNOT = Vector((shaft_r(TIE_MID) + 0.0022, -0.0030, Z(TIE_MID)))
KNOT_RADII = (0.0026, 0.0034, 0.0046)


# --------------------------------------------------------------------------
# Mesh builder
# --------------------------------------------------------------------------
def uv_in(reg, fu, fv):
    """UV inside an atlas region (pixel rect), fu/fv in 0..1, kept off the borders."""
    x0, x1, y0, y1 = reg
    return ((x0 + MARGIN + fu * (x1 - x0 - 2 * MARGIN)) / ATLAS,
            (y0 + MARGIN + fv * (y1 - y0 - 2 * MARGIN)) / ATLAS)


def newell(ps):
    n = Vector()
    for i, a in enumerate(ps):
        b = ps[(i + 1) % len(ps)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


class Builder:
    def __init__(self, origin=None):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.origin = origin.copy() if origin is not None else Vector((0.0, 0.0, 0.0))
        self.pos = {}              # BMVert -> Godot position (spear space)
        self.sharp = set()         # frozenset({v0, v1}) edges kept hard

    def v(self, p):
        q = p - self.origin
        bv = self.bm.verts.new(G(q.x, q.y, q.z))
        self.pos[bv] = p
        return bv

    def face(self, verts, uvs, out):
        n = newell([self.pos[v] for v in verts])
        if n.dot(out) < 0.0:
            verts = list(reversed(verts))
            uvs = list(reversed(uvs))
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        f.smooth = True
        for loop, t in zip(f.loops, uvs):
            loop[self.uv].uv = t
        return f

    def grid(self, P, UV, closed, out_fn):
        """Quads between rows of points. P[i][j]: Godot Vector (row i, column j).
        UV[i][j]: j runs 0..n when closed (the seam gets its own UV), 0..n-1 open.
        out_fn(i, j, centroid) -> outward Godot vector for that quad."""
        V = [[self.v(p) for p in row] for row in P]
        n = len(P[0])
        for i in range(len(P) - 1):
            for j in range(n if closed else n - 1):
                k = (j + 1) % n
                c = (P[i][j] + P[i][k] + P[i + 1][k] + P[i + 1][j]) * 0.25
                self.face([V[i][j], V[i][k], V[i + 1][k], V[i + 1][j]],
                          [UV[i][j], UV[i][j + 1], UV[i + 1][j + 1], UV[i + 1][j]], out_fn(i, j, c))
        return V

    def fan(self, centre, centre_uv, ring, ring_uv, out, closed=True):
        """Triangles from one vertex to a ring. ring_uv has len(ring) + 1 entries when closed."""
        cv = self.v(centre) if isinstance(centre, Vector) else centre
        n = len(ring)
        for j in range(n if closed else n - 1):
            k = (j + 1) % n
            cuv = centre_uv(j) if callable(centre_uv) else centre_uv
            self.face([cv, ring[j], ring[k]], [cuv, ring_uv[j], ring_uv[j + 1]], out)
        return cv

    def mark_sharp(self, a, b):
        self.sharp.add(frozenset((a, b)))

    def finish(self, name, hard_angle=48.0):
        bm = self.bm
        bm.normal_update()
        lim = math.radians(hard_angle)
        for e in bm.edges:
            if frozenset(e.verts) in self.sharp:
                e.smooth = False
            elif len(e.link_faces) == 2 and e.calc_face_angle(0.0) > lim:
                e.smooth = False
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.validate()
        return me


def radial_out(_i, _j, c):
    return Vector((c.x, c.y, 0.0))


def ring_pts(z, r, n=SIDES, jitter=None):
    pts = []
    for j in range(n):
        a = 2.0 * math.pi * j / n
        rr = r * (1.0 + jitter(a)) if jitter else r
        pts.append(Vector((rr * math.cos(a), rr * math.sin(a), z)))
    return pts


def around_uv(reg, fu, n=SIDES, v0=0.0, v1=1.0):
    return [uv_in(reg, fu, lerp(v0, v1, j / n)) for j in range(n + 1)]


# --------------------------------------------------------------------------
# Parts
# --------------------------------------------------------------------------
def wood_strip(u):
    third = U_MOUTH / 3.0
    k = min(int(u / third), 2)
    return k, (u - k * third) / third


def wood_reg(k):
    y0, y1 = WOOD_ROWS[k]
    return (0, ATLAS, y0, y1)


def build_shaft(b):
    """Ash shaft from the butt to the socket mouth, three texture strips, rounded butt."""
    def shave(u):
        return lambda a: 0.010 * (0.6 * math.sin(3 * a + 5.3 * u) + 0.4 * math.sin(2 * a - 2.1 * u + 1.3))
    third = U_MOUTH / 3.0
    stations = [0.0015, 0.005, 0.012]
    for k in range(3):
        stations += list(np.linspace(k * third, (k + 1) * third, 9)[1:])
    stations = sorted(set(round(u, 6) for u in stations if u >= 0.0015))
    # Each strip is its own grid so the texture can jump between strips at a ring.
    rows = [(u, ring_pts(Z(u), shaft_r(u), jitter=shave(u) if u > 0.012 else None)) for u in stations]
    first_ring = None
    for k in range(3):
        lo, hi = k * third, (k + 1) * third
        sel = [(u, pts) for u, pts in rows if lo - 1e-6 <= u <= hi + 1e-6]
        if k == 0:
            sel = [(u, pts) for u, pts in rows if u <= hi + 1e-6]
        P = [pts for _, pts in sel]
        UV = [around_uv(wood_reg(k), (u - lo) / third) for u, _ in sel]
        V = b.grid(P, UV, True, radial_out)
        if k == 0:
            first_ring = V[0]
    # End grain disc at the butt.
    reg = REG["end"]
    cx, cy = (reg[0] + reg[1]) / 2 / ATLAS, (reg[2] + reg[3]) / 2 / ATLAS
    rad = (reg[1] - reg[0] - 2 * MARGIN) * 0.5 / ATLAS
    ring_uv = [(cx + rad * math.cos(2 * math.pi * j / SIDES), cy + rad * math.sin(2 * math.pi * j / SIDES))
               for j in range(SIDES + 1)]
    b.fan(Vector((0, 0, Z(0.0))), (cx, cy), first_ring, ring_uv, Vector((0, 0, 1)))


def build_iron(b):
    """Blade, collar and socket as one 12-sided loft from the tip back to the mouth."""
    reg = REG["iron"]
    ss = [row[0] for row in BLADE][1:]
    P, UV, blade_rows = [], [], []
    for s in ss:
        u = U_TIP - s * BLADE_LEN
        P.append([Vector((x, y, Z(u))) for x, y in blade_section(s)])
        UV.append(around_uv(reg, (U_TIP - u) / IRON_LEN))
        blade_rows.append(s)
    for u, r in IRON_ROUND:
        P.append(ring_pts(Z(u), r))
        UV.append(around_uv(reg, (U_TIP - u) / IRON_LEN))
    V = b.grid(P, UV, True, radial_out)
    for i, s in enumerate(blade_rows[:-1]):
        if s > 0.86:
            break
        for j in SHARP_COLS:
            b.mark_sharp(V[i][j], V[i + 1][j])
    tip = b.fan(Vector((0, 0, Z(U_TIP))), lambda j: uv_in(reg, 0.0, (j + 0.5) / SIDES), V[0],
                UV[0], Vector((0, 0, -1)))
    for j in SHARP_COLS:
        b.mark_sharp(tip, V[0][j])
    # Mouth: annulus from the socket rim down onto the shaft.
    rim = V[-1]
    inner = [b.v(p) for p in ring_pts(Z(U_MOUTH), shaft_r(U_MOUTH) + 0.0002)]
    for j in range(SIDES):
        k = (j + 1) % SIDES
        b.face([rim[j], rim[k], inner[k], inner[j]],
               [uv_in(reg, 0.985, j / SIDES), uv_in(reg, 0.985, (j + 1) / SIDES),
                uv_in(reg, 1.0, (j + 1) / SIDES), uv_in(reg, 1.0, j / SIDES)], Vector((0, 0, 1)))
    # Rivet heads, domed, on both sides of the socket.
    rs = interp([(u, r) for u, r in reversed(IRON_ROUND)], RIVET_U)
    fu_r = (U_TIP - RIVET_U) / IRON_LEN
    for sx in (1.0, -1.0):
        c = Vector((sx * rs, 0.0, Z(RIVET_U)))
        rings = [(0.0028, -0.0005), (0.0022, 0.0007)]
        P, UV = [], []
        for rad, h in rings:
            P.append([Vector((sx * (rs + h), rad * math.cos(2 * math.pi * j / 8), Z(RIVET_U) + rad * math.sin(2 * math.pi * j / 8)))
                      for j in range(8)])
            UV.append([uv_in(reg, fu_r + 0.012 * rad / 0.0028 * math.cos(2 * math.pi * j / 8),
                             0.43 + 0.03 * rad / 0.0028 * math.sin(2 * math.pi * j / 8)) for j in range(9)])
        out = lambda _i, _j, cc, c=c, sx=sx: (cc - c) + Vector((sx * 0.002, 0, 0))
        Vr = b.grid(P, UV, True, out)
        b.fan(Vector((sx * (rs + 0.0012), 0.0, Z(RIVET_U))), uv_in(reg, fu_r, 0.43), Vr[-1], UV[-1],
              Vector((sx, 0, 0)))


def build_band(b, u0, u1, profile, reg, fu_span=(0.0, 1.0)):
    """A wrap around the shaft between u0 and u1; profile = [(t 0..1, offset above the wood)]."""
    P, UV = [], []
    for t, off in profile:
        u = lerp(u0, u1, t)
        P.append(ring_pts(Z(u), shaft_r(u) + off))
        UV.append(around_uv(reg, lerp(fu_span[0], fu_span[1], t)))
    b.grid(P, UV, True, radial_out)


def build_grip(b):
    """Leather grip wrap with a rawhide thong band at each end, as one band from the
    rear (butt side) to the front; the spiral of the wrap is in the textures."""
    f = THONG / (2.0 * GRIP_HALF)
    e = 0.25 * f
    leather = 0.0016                          # 1.1 mm leather, lapped
    thong = 0.0027
    prof = [(0.0, 0.0008), (e, thong), (f - e, thong), (f, leather),
            (1.0 - f, leather), (1.0 - f + e, thong), (1.0 - e, thong), (1.0, 0.0008)]
    build_band(b, U_COM - GRIP_HALF, U_COM + GRIP_HALF, prof, REG["grip"])


def build_lashing(b):
    """Sinew lashing: a low band, the turns are in the textures."""
    build_band(b, LASH_U[1], LASH_U[0], [(0.0, 0.0004), (0.14, 0.0015), (0.86, 0.0015), (1.0, 0.0004)],
               REG["lash"])


def sweep(b, path, section, reg, uvs_v, cap_end=True):
    """Ribbon/slab/bundle along `path` (Godot points). section(t) -> list of (w, n)
    offsets in the frame (W = width, N = thickness); uvs_v: V for each section point
    (+ closing value)."""
    m = len(path)
    X = Vector((1, 0, 0))
    P, UV, C = [], [], []
    for i, pt in enumerate(path):
        t = i / (m - 1)
        T = (path[min(i + 1, m - 1)] - path[max(i - 1, 0)]).normalized()
        W = T.cross(X).normalized()
        if W.y < 0:
            W = -W
        N = W.cross(T).normalized()
        P.append([pt + W * a + N * c for a, c in section(t)])
        UV.append([uv_in(reg, t, v) for v in uvs_v])
        C.append(pt)
    out = lambda i, _j, c: c - (C[i] + C[i + 1]) * 0.5
    V = b.grid(P, UV, True, out)
    if cap_end:
        T = (path[-1] - path[-2]).normalized()
        b.face(V[-1], [uv_in(reg, 1.0, v) for v in uvs_v[:-1]], T)
    return V


def hang_path(start, length, back, drop, spread, wave, n):
    """Cloth or hair hanging off the knot: back (+Z) and down (-Y) in a gentle drape,
    sagging a little more toward the end."""
    pts = []
    for i in range(n):
        t = i / (n - 1)
        pts.append(Vector((start.x + spread * math.sin(min(t * 1.4, 1.0) * math.pi / 2) + wave * math.sin(t * math.pi * 2.5),
                           start.y - length * drop * (0.6 * t + 0.4 * t * t),
                           start.z + length * back * (1.12 * t - 0.12 * t * t))))
    return pts


def build_tie(b):
    """The stroud band round the shaft and its knot (+X side), in the main mesh."""
    reg = REG["tie"]
    build_band(b, TIE_U[1], TIE_U[0], [(0.0, 0.0005), (0.25, 0.0026), (0.5, 0.0030), (0.75, 0.0026), (1.0, 0.0005)],
               reg, (0.0, TIE_FU))
    kc = KNOT
    rx, ry, rz = KNOT_RADII
    ns, nr = 6, 4
    rows, uvs = [], []
    for i in range(1, nr):
        lat = -math.pi / 2 + math.pi * i / nr
        rows.append([Vector((kc.x + rx * math.cos(lat) * math.cos(2 * math.pi * j / ns),
                             kc.y + ry * math.sin(lat),
                             kc.z + rz * math.cos(lat) * math.sin(2 * math.pi * j / ns))) for j in range(ns)])
        uvs.append([uv_in(reg, 0.66 + 0.3 * j / ns, 0.2 + 0.6 * i / nr) for j in range(ns + 1)])
    Vk = b.grid(rows, uvs, True, lambda _i, _j, c: c - kc)
    b.fan(Vector((kc.x, kc.y - ry, kc.z)), uv_in(reg, 0.8, 0.1), Vk[0], uvs[0], Vector((0, -1, 0)))
    b.fan(Vector((kc.x, kc.y + ry, kc.z)), uv_in(reg, 0.8, 0.9), Vk[-1], uvs[-1], Vector((0, 1, 0)))


# Trim at rest: (length, back, drop, spread, wave, twist, dx) for the two stroud tails.
TAILS = ((0.092, 0.70, 0.44, 0.004, 0.0022, 0.55, 0.0),
         (0.078, 0.80, 0.36, 0.015, -0.0018, -0.45, 0.0035))
HAIR = (0.070, 0.46, 0.60, 0.010, 0.0012)      # length, back, drop, spread, wave: steeper, between the tails


def build_trim(b):
    """Stroud tails (white list along one edge) and a red deer-hair tuft, hanging from the knot."""
    kc = KNOT
    reg = REG["tails"]
    hw, ht = 0.0070, 0.0006
    for (length, back, drop, spread, wave, twist, dx) in TAILS:
        start = Vector((kc.x + dx, kc.y - 0.002, kc.z + 0.002))
        path = hang_path(start, length, back, drop, spread, wave, 10)

        def section(t, twist=twist):
            a = twist * t
            wv = hw * (1.0 - 0.15 * t)
            return [(wv * math.cos(a) - ht * math.sin(a), wv * math.sin(a) + ht * math.cos(a)),
                    (-wv * math.cos(a) - ht * math.sin(a), -wv * math.sin(a) + ht * math.cos(a)),
                    (-wv * math.cos(a) + ht * math.sin(a), -wv * math.sin(a) - ht * math.cos(a)),
                    (wv * math.cos(a) + ht * math.sin(a), wv * math.sin(a) - ht * math.cos(a))]
        # +w top, -w top, -w bottom, +w bottom: the white list runs along the +w edge.
        sweep(b, path, section, reg, [0.0, 0.45, 0.5, 0.95, 1.0])
    length, back, drop, spread, wave = HAIR
    start = Vector((kc.x + 0.0020, kc.y - 0.0035, kc.z + 0.0030))
    path = hang_path(start, length, back, drop, spread, wave, 9)
    n = 8

    def tuft(t):
        # Bound with sinew at the root, flaring, then thinning out to the tips.
        if t < 0.13:
            r = 0.0021
        else:
            q = (t - 0.13) / 0.87
            r = 0.0021 + 0.0040 * math.sin(math.pi * min(q / 0.45, 1.0) * 0.5) - 0.0052 * smoothstep(0.35, 1.0, q)
            r = max(r, 0.0007)
        return [(r * math.cos(2 * math.pi * j / n), r * math.sin(2 * math.pi * j / n)) for j in range(n)]
    sweep(b, path, tuft, REG["hair"], [j / n for j in range(n + 1)])


# --------------------------------------------------------------------------
# Textures
# --------------------------------------------------------------------------
def vnoise(h, w, cy, cx, seed, wrap_y=False):
    rng = np.random.default_rng(seed)
    g = rng.random((cy + 1, cx + 1)).astype(np.float32)
    if wrap_y:
        g[cy, :] = g[0, :]
    y = (np.arange(h) + 0.5) / h * cy
    x = (np.arange(w) + 0.5) / w * cx
    y0 = np.minimum(np.floor(y).astype(int), cy - 1)
    x0 = np.minimum(np.floor(x).astype(int), cx - 1)
    fy = y - y0
    fx = x - x0
    fy = (fy * fy * (3 - 2 * fy))[:, None]
    fx = (fx * fx * (3 - 2 * fx))[None, :]
    a = g[y0][:, x0]
    bb = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + bb * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(h, w, cy, cx, seed, octaves=4, wrap_y=False):
    tot = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        tot += amp * vnoise(h, w, cy * 2 ** o, cx * 2 ** o, seed + 17 * o, wrap_y)
        norm += amp
        amp *= 0.5
    return tot / norm


def mix(a, b, t):
    a = np.asarray(a, np.float32)
    b = np.asarray(b, np.float32)
    t = np.asarray(t, np.float32)
    if t.ndim == 2:
        t = t[..., None]
    return a * (1 - t) + b * t


def height_to_normal(h, strength, wrap_y=False):
    if wrap_y:
        gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    else:
        gy = np.gradient(h, axis=0)
    gx = np.gradient(h, axis=1)
    n = np.stack([-gx * strength, -gy * strength, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def region_uv(reg):
    """(fu, fv) of every pixel of a region, with uv_in's margins undone, so patterns that
    wrap round the shaft (fv 0 == fv 1) meet exactly at the UV seam."""
    x0, x1, y0, y1 = reg
    w, h = x1 - x0, y1 - y0
    fu = ((np.arange(w) + 0.5 - MARGIN) / (w - 2 * MARGIN))[None, :] * np.ones((h, 1), np.float32)
    fv = ((np.arange(h) + 0.5 - MARGIN) / (h - 2 * MARGIN))[:, None] * np.ones((1, w), np.float32)
    return h, w, fu.astype(np.float32), fv.astype(np.float32)


def polyhaven(rel):
    """Full-resolution RGB of a Poly Haven map (rows bottom-up, like Blender), or None."""
    path = os.path.join(POLYHAVEN, rel)
    if not os.path.exists(path):
        return None
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[:, :, :3]


def dimples(h, w, count, rmin, rmax, seed, wrap_y=False):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    for _ in range(count):
        cy, cx = rng.uniform(0, h), rng.uniform(0, w)
        r = rng.uniform(rmin, rmax)
        y0, y1 = int(cy - 2 * r), int(cy + 2 * r) + 1
        x0, x1 = max(int(cx - 2 * r), 0), min(int(cx + 2 * r) + 1, w)
        ys = np.arange(y0, y1)
        xs = np.arange(x0, x1)
        d2 = ((ys[:, None] - cy) ** 2 + (xs[None, :] - cx) ** 2) / (r * r)
        bump = np.exp(-d2 * 1.5)
        if wrap_y:
            out[np.mod(ys, h)[:, None], xs[None, :]] -= bump
        else:
            ok = (ys >= 0) & (ys < h)
            out[ys[ok][:, None], xs[None, :]] -= bump[ok]
    return out


class Atlas:
    def __init__(self):
        self.col = np.zeros((ATLAS, ATLAS, 3), np.float32) + np.array([0.5, 0.45, 0.4], np.float32)
        self.rough = np.full((ATLAS, ATLAS), 0.7, np.float32)
        self.metal = np.zeros((ATLAS, ATLAS), np.float32)
        self.nrm = np.zeros((ATLAS, ATLAS, 3), np.float32) + np.array([0.5, 0.5, 1.0], np.float32)

    def put(self, reg, col, rough, metal, nrm):
        x0, x1, y0, y1 = reg
        self.col[y0:y1, x0:x1] = col
        self.rough[y0:y1, x0:x1] = rough
        self.metal[y0:y1, x0:x1] = metal
        self.nrm[y0:y1, x0:x1] = nrm


def tex_wood(at):
    H = WOOD_ROWS[0][1] - WOOD_ROWS[0][0]
    W = 3 * ATLAS
    th = ((np.arange(H) + 0.5) / H)[:, None]
    s = ((np.arange(W) + 0.5) / W * U_MOUTH)[None, :]
    circ = 2 * math.pi * 0.0126
    # Split and shaved ash: straight grain lines that wander slowly along the shaft.
    # Latewood as long, uneven streaks (random widths and spacing), not regular stripes.
    lines = fbm(H, W, 28, 5, 17, 3, wrap_y=True)
    late = smoothstep(0.52, 0.70, lines) * (0.5 + 0.5 * fbm(H, W, 6, 30, 18, 2, wrap_y=True))
    fine = vnoise(H, W, 85, 22, 16, wrap_y=True)                    # fine streaks
    pores = smoothstep(0.80, 0.92, vnoise(H, W, 170, 520, 12, wrap_y=True)) * (1 - late)
    streak = fbm(H, W, 6, 90, 13, 3, wrap_y=True)
    col = mix((0.63, 0.50, 0.35), (0.50, 0.37, 0.24), late * 0.75 + 0.18 * fine)
    col = col * (0.90 + 0.14 * streak)[..., None] - 0.05 * pores[..., None]
    col *= np.array([0.95, 0.93, 0.90], np.float32)
    rough = 0.66 + 0.08 * streak - 0.05 * late
    height = 0.06 * late + 0.10 * fine + 0.12 * streak - 0.10 * pores
    # Handling: darker and smoother where hands go (behind the point, at the butt).
    use = 0.13 * np.exp(-((s - 1.36) / 0.11) ** 2) + 0.20 * (1 - smoothstep(0.0, 0.07, s))
    col *= (1 - use)[..., None]
    rough -= 0.6 * use
    # Grime against every wrap edge.
    for sb in (U_MOUTH, LASH_U[0], TIE_U[1], TIE_U[0], U_COM - GRIP_HALF, U_COM + GRIP_HALF):
        g = 0.28 * np.exp(-((s - sb) / 0.004) ** 2)
        col *= (1 - g)[..., None]
    # Two pin knots.
    for s0, t0 in ((0.62, 0.20), (1.13, 0.66)):
        dth = (th - t0 + 0.5) % 1.0 - 0.5
        d = np.sqrt(((s - s0) / 0.0045) ** 2 + (dth * circ / 0.0028) ** 2)
        knot = 1 - smoothstep(0.55, 1.0, d)
        halo = np.exp(-((d - 1.3) / 0.35) ** 2)
        col = mix(col, (0.30, 0.20, 0.12), knot * 0.9)
        col *= (1 - 0.18 * halo)[..., None]
        height += 0.5 * knot
        rough -= 0.1 * knot
    # Paint (charcoal black, white clay), worn.
    edge = (fbm(H, W, 6, 300, 14, 2, wrap_y=True) - 0.5) * 0.004
    wear = smoothstep(0.26, 0.36, fbm(H, W, 10, 500, 15, 3, wrap_y=True))
    se = s + edge
    for u0, u1, kind in PAINT:
        inside = ((se > u0) & (se < u1)).astype(np.float32)
        if kind == "zig":
            tri = np.abs(((th * 8) % 1.0) - 0.5) * 2.0
            inside = inside * smoothstep(-0.03, 0.03, tri - (se - u0) / (u1 - u0))
            colr = BLACK
        else:
            colr = WHITE if kind == "white" else BLACK
        a = inside * wear
        col = mix(col, colr, a * 0.95)
        rough += 0.1 * a
        height += 0.06 * a
    col = np.clip(col, 0, 1)
    nrm = height_to_normal(height, 1.0, wrap_y=True)
    for k, (y0, y1) in enumerate(WOOD_ROWS):
        sl = slice(k * ATLAS, (k + 1) * ATLAS)
        at.put(wood_reg(k), col[:, sl], np.clip(rough[:, sl], 0.3, 0.95), 0.0, nrm[:, sl])


def tex_end(at):
    x0, x1, y0, y1 = REG["end"]
    h, w = y1 - y0, x1 - x0
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = (xx + 0.5) / w - 0.5, (yy + 0.5) / h - 0.5
    r = np.sqrt(dx * dx + dy * dy) * 2
    ang = np.arctan2(dy, dx)
    n = fbm(h, w, 6, 6, 31, 3)
    rings = 0.5 + 0.5 * np.sin(2 * math.pi * (r * 9 + 0.4 * n))
    checks = np.exp(-((np.sin(ang * 3 + 0.7) * r * 40) ** 2)) * (r > 0.25)
    col = mix((0.47, 0.36, 0.23), (0.36, 0.26, 0.16), rings * 0.6 + 0.25 * n)
    col = mix(col, (0.12, 0.08, 0.05), checks * 0.8)
    col *= (1 - 0.25 * smoothstep(0.7, 1.0, r))[..., None]
    height = rings * 0.5 - checks
    at.put(REG["end"], np.clip(col, 0, 1), 0.8, 0.0, height_to_normal(height, 1.2))


def tex_iron(at):
    """Forged iron: bare grey metal (sRGB ~0.55-0.67, metallic 1) with filed bright
    bevels, patches of dark forge scale (metallic 0.3) mostly on the socket and collar,
    a little non-metallic rust, and the dark seam of the split socket."""
    x0, x1, y0, y1 = REG["iron"]
    h, w = y1 - y0, x1 - x0
    U = ((np.arange(w) + 0.5) / w)[None, :] * np.ones((h, 1), np.float32)
    Vv = ((np.arange(h) + 0.5) / h)[:, None] * np.ones((1, w), np.float32)
    f_blade = BLADE_LEN / IRON_LEN
    f_sock = (U_TIP - U_SOCKET) / IRON_LEN
    on_blade = 1 - smoothstep(f_blade * 0.95, f_blade * 1.02, U)
    mott = fbm(h, w, 6, 12, 21, 4, wrap_y=True)
    # Filed bevels: from each edge (V = 0, 0.5, 1) across the whole bevel facet (1/12).
    dv = np.minimum(np.minimum(np.abs(Vv), np.abs(Vv - 0.5)), np.abs(Vv - 1.0))
    filed = (1 - smoothstep(0.075, 0.105, dv)) * (1 - smoothstep(f_blade * 0.86, f_blade * 0.97, U))
    # Forge scale: soft dark clouds on the socket and the moulded collar (the blade is
    # ground and filed clean).
    sn = fbm(h, w, 4, 8, 22, 3, wrap_y=True)
    scale = smoothstep(0.52, 0.70, sn) * 0.75 * (1 - on_blade)
    collar = smoothstep(f_blade - 0.005, f_blade + 0.01, U) * (1 - smoothstep(f_sock - 0.01, f_sock + 0.005, U))
    scale = np.maximum(scale, collar * 0.7) * (1 - filed)
    rustn = vnoise(h, w, 70, 140, 23, wrap_y=True) * 0.55 + fbm(h, w, 8, 16, 24, 3, wrap_y=True) * 0.45
    rust_bias = 0.06 * smoothstep(f_blade, 1.0, U) + 0.04 * np.exp(-((U - f_blade) / 0.04) ** 2) + 0.06 * smoothstep(0.96, 1.0, U)
    rust = smoothstep(0.80, 0.90, rustn + rust_bias) * (1 - 0.7 * filed)
    col = mix((0.55, 0.545, 0.53), (0.67, 0.66, 0.645), mott)       # bare iron (sRGB)
    col = mix(col, (0.79, 0.78, 0.765), filed)                      # filed bright
    col = mix(col, (0.21, 0.20, 0.19), scale * 0.92)                # forge scale
    col = mix(col, (0.33, 0.18, 0.10), rust * 0.9)                  # rust
    height = dimples(h, w, 320, 3.0, 9.0, 25, wrap_y=True) * 0.22 + 0.3 * mott + 0.4 * rust + 0.15 * scale
    # Split socket: the seam of the folded iron underneath (-Y, V = 0.75).
    seam_w = 0.004 + 0.006 * smoothstep(f_sock, 1.0, U)
    seam = np.exp(-((Vv - 0.75) / seam_w) ** 2) * smoothstep(f_sock - 0.01, f_sock + 0.03, U)
    col = mix(col, (0.10, 0.09, 0.08), seam * 0.9)
    height -= 2.5 * seam
    rough = 0.44 + 0.10 * mott - 0.14 * filed + 0.30 * scale + 0.45 * rust + 0.2 * seam
    metal = (1.0 - 0.7 * scale) * (1.0 - np.clip(rust / 0.8, 0, 1)) * (1.0 - 0.7 * seam)
    at.put(REG["iron"], np.clip(col, 0, 1), np.clip(rough, 0.18, 0.95), np.clip(metal, 0, 1),
           height_to_normal(height, 1.4, wrap_y=True))


def tex_grip(at):
    """Grip band, rear (fu 0) to front (fu 1), fv around: rawhide thong turns at both
    ends, and between them the leather strip wound in a spiral, each turn lapping the
    one behind it (a step and a dark cut edge every GRIP_PITCH)."""
    reg = REG["grip"]
    h, w, fu, fv = region_uv(reg)
    L = 2.0 * GRIP_HALF
    s = fu * L
    f = THONG / L
    diff = polyhaven("clothing/brown_leather/brown_leather_diffuse_2k.jpg")
    nor = polyhaven("clothing/brown_leather/brown_leather_nor_gl_2k.jpg")
    arm = polyhaven("clothing/brown_leather/brown_leather_arm_2k.jpg")
    oy, ox = 620, 700
    if diff is not None:
        lum = diff[oy:oy + h, ox:ox + w].mean(axis=2)
        lum = lum / max(float(lum.mean()), 1e-3)
        col = np.array([0.27, 0.16, 0.09], np.float32)[None, None, :] * np.clip(lum, 0.5, 1.6)[..., None] ** 0.7
    else:
        col = np.array([0.30, 0.18, 0.10], np.float32) * (0.85 + 0.3 * fbm(h, w, 8, 16, 41, 3))[..., None]
    if nor is not None:
        base_n = nor[oy:oy + h, ox:ox + w].copy()
        base_n[..., :2] = 0.5 + (base_n[..., :2] - 0.5) * 0.55
    else:
        base_n = height_to_normal(fbm(h, w, 40, 80, 42, 3), 3.0)
    rough = (arm[oy:oy + h, ox:ox + w, 1] * 0.5 + 0.38) if arm is not None else np.full((h, w), 0.7, np.float32)
    # Spiral: phase advances one turn per pitch along the grip and once round the shaft.
    ph = (s - THONG) / GRIP_PITCH + fv
    r = ph - np.floor(ph)                  # 0 just in front of a lap edge .. 1 at the next
    step = smoothstep(0.955, 1.0, r)       # the upper turn's cut edge (height drops)
    lap_h = (r * (1 - step)) * 1.1         # mm: the turn rises over the one it laps
    edge = np.exp(-((1.0 - r) / 0.03) ** 2) + np.exp(-(r / 0.02) ** 2)
    shade = 1 - smoothstep(0.0, 0.25, r)   # just in front of an edge: tucked, in shadow
    col = mix(col, (0.12, 0.075, 0.045), np.clip(edge, 0, 1) * 0.8)
    col *= (1 - 0.22 * shade)[..., None]
    polish = 0.5 + 0.5 * np.cos(2 * math.pi * (fv - 0.25))     # palm side a little polished
    col *= (1 + 0.08 * polish)[..., None]
    rough = rough - 0.08 * polish + 0.2 * np.clip(edge, 0, 1)
    px_mm = 1000.0 * L / w
    spiral_n = height_to_normal(lap_h / px_mm, 1.0)
    nrm = spiral_n.copy()
    nrm[..., :2] = np.clip(spiral_n[..., :2] + (base_n[..., :2] - 0.5), 0, 1)
    # Rawhide thongs: three turns in each end band.
    th_zone = np.maximum(1 - smoothstep(f - 0.004, f, fu), smoothstep(1 - f, 1 - f + 0.004, fu))
    a = np.where(fu < 0.5, s, L - s) / THONG
    turns = 0.5 + 0.5 * np.cos(2 * math.pi * (3.0 * a + fv))
    n = fbm(h, w, 8, 16, 71, 3)
    th_col = np.array([0.60, 0.46, 0.30], np.float32) * (0.60 + 0.32 * turns + 0.15 * n)[..., None]
    th_nrm = height_to_normal(turns ** 0.5 * 0.9 / px_mm, 1.0)
    col = mix(col, th_col, th_zone)
    rough = rough * (1 - th_zone) + (0.62 + 0.1 * n) * th_zone
    nrm = mix(nrm, th_nrm, th_zone)
    at.put(reg, np.clip(col, 0, 1), np.clip(rough, 0.3, 0.95), 0.0, nrm)


def tex_lash(at):
    """Sinew lashing: close turns spiralling round the shaft, 1 mm thread."""
    reg = REG["lash"]
    h, w, fu, fv = region_uv(reg)
    turns = (LASH_U[1] - LASH_U[0]) / 0.001
    thread = 0.5 + 0.5 * np.cos(2 * math.pi * (turns * fu + fv))
    fib = fbm(h, w, 64, 8, 51, 3)
    dirt = fbm(h, w, 4, 6, 52, 3)
    ends = smoothstep(0.0, 0.08, fu) * (1 - smoothstep(0.92, 1.0, fu))
    col = np.array([0.78, 0.67, 0.49], np.float32) * (0.62 + 0.28 * thread + 0.12 * fib)[..., None]
    col *= (0.85 + 0.2 * dirt)[..., None] * (0.8 + 0.2 * ends)[..., None]
    height = thread ** 0.6 + 0.2 * fib
    rough = 0.55 + 0.15 * (1 - thread) + 0.1 * dirt
    at.put(reg, np.clip(col, 0, 1), rough, 0.0, height_to_normal(height, 2.6))


def wool(h, w, oy, ox, colour, seed):
    """Stroud broadcloth: the Poly Haven caban weave's luminance on `colour`, and its normal."""
    diff = polyhaven("clothing/caban/caban_diffuse_2k.jpg")
    nor = polyhaven("clothing/caban/caban_nor_gl_2k.jpg")
    c = np.array(colour, np.float32)
    if diff is not None:
        lum = diff[oy:oy + h, ox:ox + w].mean(axis=2)
        lum = lum / max(float(lum.mean()), 1e-3)
        lum = np.clip(lum, 0.6, 1.45)
    else:
        lum = 0.85 + 0.3 * fbm(h, w, 32, 32, seed, 3)
    nrm = nor[oy:oy + h, ox:ox + w].copy() if nor is not None else height_to_normal(fbm(h, w, 64, 64, seed + 1, 2), 3.0)
    return lum, nrm


def tex_tie(at):
    """Tie band (fu 0..TIE_FU, front to rear, fv around) with the white list along its
    rear edge; the knot (fu > TIE_FU) is plain blue."""
    reg = REG["tie"]
    h, w, fu, fv = region_uv(reg)
    lum, nrm = wool(h, w, 900, 900, STROUD_BLUE, 61)
    t = fu / TIE_FU
    lst = smoothstep(0.68, 0.72, t) * (fu < TIE_FU + 0.01)
    col = mix(np.array(STROUD_BLUE, np.float32)[None, None, :] * lum[..., None],
              np.array(LIST_WHITE, np.float32)[None, None, :] * (0.55 + 0.45 * lum)[..., None], lst)
    dirt = fbm(h, w, 5, 5, 63, 3)
    col *= (0.82 + 0.28 * dirt)[..., None]
    at.put(reg, np.clip(col, 0, 1), 0.93, 0.0, nrm)


def tex_tails(at):
    """Stroud tails: fu along the tail (knot -> cut end), fv across both faces
    (+w top 0 .. -w 0.45 | edge | -w bottom 0.5 .. +w 0.95 | edge): the undyed white
    list runs along the +w edge, the cut end is frayed."""
    reg = REG["tails"]
    h, w, fu, fv = region_uv(reg)
    lum, nrm = wool(h, w, 300, 1200, STROUD_BLUE, 65)
    # Distance across the width from the +w edge (0) to the -w edge (1), both faces.
    across = np.where(fv < 0.475, fv / 0.45, np.where(fv < 0.975, (0.95 - fv) / 0.45, 0.0))
    across = np.clip(across, 0, 1)
    wob = (fbm(h, w, 4, 12, 66, 2) - 0.5) * 0.04
    lst = 1 - smoothstep(0.30, 0.34, across + wob)
    line = np.exp(-((across + wob - 0.22) / 0.018) ** 2) * 0.35          # faint line in the list
    blue = np.array(STROUD_BLUE, np.float32)[None, None, :] * lum[..., None]
    white = np.array(LIST_WHITE, np.float32)[None, None, :] * (0.6 + 0.4 * lum)[..., None]
    col = mix(blue, white, lst)
    col = mix(col, (0.30, 0.30, 0.34), line * lst)
    dirt = fbm(h, w, 5, 5, 67, 3)
    col *= (0.80 + 0.30 * dirt)[..., None]
    fray = smoothstep(0.92, 1.0, fu)
    col *= (1 - 0.35 * fray)[..., None]
    at.put(reg, np.clip(col, 0, 1), 0.93, 0.0, nrm)


def tex_hair(at):
    """Red-dyed deer hair: fu along the tuft (root -> tips), fv around. Bound with
    sinew at the root; coarse strands, darker at the root, lighter at the tips."""
    reg = REG["hair"]
    h, w, fu, fv = region_uv(reg)
    strands = vnoise(h, w, 48, 3, 81, wrap_y=True) * 0.6 + vnoise(h, w, 96, 6, 82, wrap_y=True) * 0.4
    fine = vnoise(h, w, 160, 10, 83, wrap_y=True)
    col = np.array(HAIR_RED, np.float32)[None, None, :] * (0.62 + 0.55 * strands + 0.12 * fine)[..., None]
    col = mix(col, (0.80, 0.30, 0.12), smoothstep(0.75, 1.0, fu) * 0.45)       # sun-faded tips
    col = mix(col, (0.28, 0.05, 0.03), (1 - smoothstep(0.13, 0.24, fu)) * 0.6)  # roots under the binding
    bind = 1 - smoothstep(0.125, 0.14, fu)
    thread = 0.5 + 0.5 * np.cos(2 * math.pi * (14.0 * fu / 0.13 + fv))
    sinew = np.array([0.74, 0.63, 0.46], np.float32) * (0.65 + 0.3 * thread)[..., None]
    col = mix(col, sinew, bind)
    height = (0.5 * strands + 0.3 * fine) * (1 - bind) + thread ** 0.6 * bind
    rough = 0.62 - 0.1 * strands * (1 - bind) + 0.05 * bind
    at.put(reg, np.clip(col, 0, 1), rough, 0.0, height_to_normal(height, 1.6))


def make_images():
    at = Atlas()
    tex_wood(at)
    tex_end(at)
    tex_iron(at)
    tex_grip(at)
    tex_lash(at)
    tex_tie(at)
    tex_tails(at)
    tex_hair(at)
    rng = np.random.default_rng(99)
    col = np.clip(at.col + rng.uniform(-0.01, 0.01, at.col.shape[:2])[..., None], 0, 1)
    orm = np.stack([np.ones_like(at.rough), np.clip(at.rough, 0, 1), np.clip(at.metal, 0, 1)], axis=-1)

    def image(name, arr, non_color):
        rgba = np.concatenate([arr, np.ones(arr.shape[:2] + (1,), np.float32)], axis=2).astype(np.float32)
        im = bpy.data.images.new(name, ATLAS, ATLAS, alpha=False)
        if non_color:
            im.colorspace_settings.name = "Non-Color"
        im.pixels.foreach_set(rgba.ravel())
        im.update()
        im.pack()
        return im
    return image("spear_atlas", col, False), image("spear_orm", orm, True), image("spear_normal", at.nrm, True)


def make_material(cimg, oimg, nimg):
    m = bpy.data.materials.new("SpearAtlas")
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexImage")
    tc.image = cimg
    tc.location = (-600, 300)
    nt.links.new(tc.outputs["Color"], bsdf.inputs["Base Color"])
    to = nt.nodes.new("ShaderNodeTexImage")
    to.image = oimg
    to.location = (-800, 0)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    sep.location = (-450, 0)
    nt.links.new(to.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = nimg
    tn.location = (-800, -350)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.location = (-450, -350)
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    m.use_backface_culling = True
    return m


# --------------------------------------------------------------------------
# Assembly, export, previews
# --------------------------------------------------------------------------
def add_empty(name, godot_pos, parent):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 0.03
    e.location = G(*godot_pos)
    e.parent = parent
    bpy.context.scene.collection.objects.link(e)
    return e


def build_spear():
    b = Builder()
    build_shaft(b)
    build_iron(b)
    build_lashing(b)
    build_tie(b)
    build_grip(b)
    me = b.finish("Spear")
    mat = make_material(*make_images())
    me.materials.append(mat)
    obj = bpy.data.objects.new("Spear", me)
    bpy.context.scene.collection.objects.link(obj)
    bt = Builder(origin=KNOT)
    build_trim(bt)
    tme = bt.finish("Trim")
    tme.materials.append(mat)
    trim = bpy.data.objects.new("Trim", tme)
    trim.location = G(KNOT.x, KNOT.y, KNOT.z)
    trim.parent = obj
    bpy.context.scene.collection.objects.link(trim)
    add_empty("Muzzle", (0, 0, -TIP), obj)
    add_empty("Tip", (0, 0, -TIP), obj)
    add_empty("COM", (0, 0, 0), obj)
    add_empty("Butt", (0, 0, BUTT), obj)
    return obj, trim


def export_glb(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for c in obj.children:
        c.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=True, export_normals=True, export_tangents=False,
        export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=92,
        export_cameras=False, export_lights=False, export_extras=False)


def render_previews(obj, out_dir, name):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        sc.render.engine = "BLENDER_WORKBENCH"
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("PreviewWorld")
    try:
        world.use_nodes = True
    except Exception:
        pass
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.50, 0.53, 0.57, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    sc.world = world
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(3)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(38), math.radians(-20), math.radians(40))
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 25.0
    fill.size = 1.5
    fo = bpy.data.objects.new("Fill", fill)
    fo.location = (-1.2, 0.3, 0.8)
    fo.rotation_euler = (math.radians(-40), math.radians(-50), 0)
    sc.collection.objects.link(fo)
    ymid = -(BUTT - TIP) / 2.0
    tipy = TIP
    ky = -KNOT.z                                 # Blender y of the knot
    shots = [
        # tag, target (Blender), camera location, ortho scale (0 = perspective, lens), resolution
        ("side", (0.0, ymid, 0.0), (2.0, ymid, 0.0), 1.92, 0, (2400, 560)),
        ("top", (0.0, ymid, 0.0), (0.0, ymid, 2.0), 1.92, 0, (2400, 440)),
        ("point", (0.0, tipy - 0.19, -0.012), (0.30, tipy - 0.36, 0.13), 0.0, 55, (1600, 1000)),
        ("point_left", (0.0, tipy - 0.24, -0.02), (-0.30, tipy - 0.46, 0.10), 0.0, 55, (1600, 1000)),
        ("blade_top", (0.0, tipy - 0.12, 0.0), (0.0, tipy - 0.12, 0.6), 0.30, 0, (1400, 700)),
        ("trim", (0.02, ky - 0.03, -0.02), (0.30, ky + 0.10, 0.06), 0.0, 60, (1400, 1000)),
        ("grip", (0.0, 0.0, 0.0), (0.20, -0.10, 0.09), 0.0, 50, (1400, 900)),
        ("butt", (0.0, -BUTT + 0.06, 0.0), (0.16, -BUTT + 0.20, 0.07), 0.0, 50, (1200, 800)),
        ("hero", (0.0, ymid + 0.05, -0.02), (1.25, 0.55, 0.55), 0.0, 38, (1800, 1000)),
    ]
    out = []
    for tag, target, loc, ortho, lens, (w, h) in shots:
        cd = bpy.data.cameras.new("cam_" + tag)
        if ortho:
            cd.type = "ORTHO"
            cd.ortho_scale = ortho
        else:
            cd.lens = lens
        cd.clip_start = 0.005
        cam = bpy.data.objects.new("cam_" + tag, cd)
        cam.location = loc
        d = Vector(target) - Vector(loc)
        if abs(d.normalized().z) > 0.99:
            cam.rotation_euler = (0.0, 0.0, math.pi / 2)     # top view, point to the right
        else:
            cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(cam)
        sc.camera = cam
        sc.render.resolution_x, sc.render.resolution_y = w, h
        sc.render.filepath = os.path.join(out_dir, "%s_%s.png" % (name, tag))
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)
        out.append(sc.render.filepath)
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(PROJECT, "assets", "weapons", "spear.glb"))
    ap.add_argument("--renders", default=None)
    ap.add_argument("--blend", default=None)
    args = ap.parse_args(argv)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for name, kg, u in PARTS:
        print("MASS %-20s %6.1f g at %.3f m from the butt" % (name, kg * 1000.0, u))
    print("BALANCE total %.0f g, COM %.3f m from the butt (%.1f%%), TIP %.4f BUTT %.4f"
          % (TOTAL_MASS * 1000.0, U_COM, 100.0 * U_COM / LENGTH, TIP, BUTT))
    print("KNOT (trim pivot) %.4f %.4f %.4f" % (KNOT.x, KNOT.y, KNOT.z))
    obj, trim = build_spear()
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in (obj, trim)}
    print("SPEAR TRIS", sum(tris.values()), tris, "VERTS", len(obj.data.vertices) + len(trim.data.vertices),
          "LENGTH", round(TIP + BUTT, 4))
    export_glb(obj, args.out)
    print("EXPORTED", args.out)
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    if args.renders:
        render_previews(obj, args.renders, "spear")


if __name__ == "__main__":
    main()
