"""Procedural sky galleon for Frontier's "etherium" chapters.

70 % a mid-18th-century two-masted brigantine (carvel oak hull with a V
floor, a hollow run fining into a thin deadwood under a round tuck, raked
sternpost and an overhanging counter, matte tarred bottom and wales with an
untarred oak keel, stem and sternpost (one timber line the whole length from
below), weathered-oak upper works in long strakes with a blue-green painted
strake and gold beading, a strong sheer, raised quarterdeck and forecastle, a
transom with five lit stern
windows over a small open gallery, a carved taffrail with poop lanterns,
quarter galleries, six gunports a side, channels and deadeyes, a bowsprit and
jib-boom, a square-rigged foremast with course, topsail and topgallant, a gaff
mainsail and boom with a gaff topsail on the taller main, three headsails, all
in warm canvas with dark boltropes, tabling and a reef band, a ship's wheel on
the quarterdeck), trimmed under sail on the starboard tack
(fore yards braced round 20 deg, boom and gaff swung out 11 deg to port,
headsails sheeted to port), and 30 % wonder, of our own design:
  1. etherium fans: rigid, asymmetric bird's-wing fans of brass ribs (the
     leading rib outboard and longest, the rest tapering aft; heavier outer
     sticks, knobbed tips) and translucent honey-amber panels under a brass
     rim, opening from a brass hub at the aft corner of each mast top, port
     and starboard, aft of the canvas, in a plane canted 22 deg up outboard and
     15 deg up aft (gently cupped);
  2. two keel-wings rooted high on the bilges just under the wale: swept (35
     deg), tapered lift fins, a heavy brass leading-edge spar with straight
     ribs raking back to the trailing edge, drooped 20 deg, the tips above the
     keel;
  3. a hard-faceted hexagonal etherium crystal slung under the keel midships in
     a brass cradle (bands, edge straps, collars, two raked pylons), and glow
     strips along both faces of every rib (material "EtheriumGlow", so the
     game can pulse it);
  4. brass armillary rings round the great stern lantern.
The oak is weathered and the brass a little dark and green, so the etherium is
the only saturated gold on the ship.

Run headless (factory scene), one Blender process at a time:
  Blender -b --factory-startup --python tools/models/sky_galleon.py -- \
      [--variant galleon|hunter] [--out assets/sky/sky_galleon.glb | sky_hunter.glb] [--renders DIR]
      [--blend FILE.blend] [--diag DIR (galleon: close-up check shots instead)] [--only shot,shot]
      [--atlas-png DIR] [--galleon-glb FILE (hunter: the ship beside it in the duel previews)]
Every build prints the triangle counts, the empties and a clash check (rigging,
sails or hull passing through a fan membrane; there should be none).

Conventions (Godot / glTF axes, metres):
  * forward (bow) = -Z, up = +Y, starboard = +X
  * origin = the underside of the keel at midships (the "waterline-equivalent"
    datum of a ship that never touches water); the main deck is at y ~ +3.2
    at the side midships (+3.35 on the centre line, camber), rising with the
    sheer to ~ +4.0 at the transom and ~ +4.35 at the stem; the quarterdeck
    ~ +4.6..5.35, the forecastle ~ +4.7..5.55
  * hull ~26.4 m from the stem head (z = -13.2) to the taffrail (z = +13.2);
    jib-boom end at z ~ -19.4; beam 7.5 m; main truck 30.0 m, fore truck
    28.5 m above the keel. The fans reach ~ x = +-7.5 and the keel-wing tips
    ~ x = +-8.4, y = +0.3 (roots at y ~ 2.05); the keel crystal hangs to
    y ~ -2.4
  * top-level mesh nodes: Hull (hull, decks, rails, guns, stern, keel crystal),
    Rig (spars, tops, deadeyes, standing and some running rigging), Sails
    (canvas, double sided), WingSails (etherium fans and keel-wings) and
    Galleon_LOD1 (one mesh, < 3000 triangles, the whole ship for far away; it
    overlaps the near meshes, so give the MeshInstance3D nodes visibility
    ranges in Godot)
  * top-level empties: Helm (deck point where the helmsman stands, 0.6 m aft of
    the wheel, facing -Z), Deck (spawn point on the main deck midships between
    the hatches), Bow (stem head), Stern (top of the taffrail on the centre
    line), KeelGlow (centre of the keel crystal, for a light)
  * WingSails should not cast shadows in Godot (cast_shadow off): its blended
    membranes only speckle; the previews render it that way
  * six materials: Wood, Tar, Paint, Canvas, Brass, EtheriumGlow. Wood, Tar,
    Paint, Canvas and Brass share one generated 1024 atlas (full-width bands
    that tile along U for planking, deck, spars and canvas; small cells for
    windows, gilt carving, brass, lantern glass, membrane, glow and crystal);
    a 512 emission mask of the same layout (sRGB, like glTF's emissive
    texture) lights the stern windows, skylight and lantern glass on Wood
    (strength 4) and the etherium on EtheriumGlow (strength 2, the knob to
    pulse): faint on the membranes (a little more toward the hub and beside
    the ribs), full on the rib strips and hub eyes, moderate on the crystal
    (its core band brightest, never white). EtheriumGlow takes colour and
    alpha (BLEND, double sided) from the atlas.
  * a light for the keel crystal belongs ~1.2 m above KeelGlow (between the
    crystal and the keel, as the previews' stand-in): one at the crystal's
    centre lights every facet from inside and blows it out to a white bulb

--variant hunter: the enemy of Two Fires (docs/main_story.md, mission 11), the same build system and conventions
rebound to another ship of our own design that reads as the enemy at 300 m against the night (use_hunter() rebinds
the knobs above; build_hunter() and the *_hunter builders replace what differs). Exports assets/sky/sky_hunter.glb:
  * a three-masted sloop-of-war, longer and lower: 36 m from the stem head (z = -18.0) to the taffrail
    (z ~ +18.0), beam 7.8 m, a low sheer (main rail 3.95 above the keel midships, deck ~3.1), a short forecastle and
    a low quarterdeck (break z = 8.0); an iron-shod beak (ram) on the cutwater, its point at (0, 1.72, -20.8);
    jib-boom end z ~ -25.8, spanker boom end z ~ +20.5; trucks 27.8 (fore), 31.0 (main), 20.0 (mizzen)
  * black-tarred bottom and blackened topsides, a dark red strake (with iron beading) through eight gunports a
    side, red port lids, iron fittings ("Brass" in the code, exported as material Iron), raked masts (4, 6, 8
    deg), dark patched sails (16 cloths a tile, patches sewn on), dim red-violet stern windows and an iron stern
    lantern round a glowing stone
  * the guns run out, every muzzle in a wind ring (an iron ring off the bell mouth, a glowing ring inside it: the
    Gust guns, no powder)
  * fans on the fore and main tops swept back like a bat's wing: five blackened iron ribs run out into spikes,
    smoky membranes, the edge scalloped between the ribs, glow strips on the ribs and a glow line along the edge;
    swept keel-wings; a longer, slimmer keel crystal; all the etherium in a cold red-violet (hue ~320 deg, apart
    from the galleon's amber and the tear's violet), material EtheriumGlow as on the galleon (the knob to pulse)
  * nodes Hull, Rig, Sails, WingSails, Galleon_LOD1 (< 3000 triangles; its fan ribs and keel-wing spars drawn as
    lines of glow); empties Helm, Deck, Bow, Stern, KeelGlow as the galleon's, plus Beak (the ram's point) and
    Muzzle_S1..S8 / Muzzle_P1..P8 (each wind ring's centre, starboard / port, bow to stern; the gun points
    straight out, +X / -X) for the battle's shots
  * --renders writes night previews (side, front 3/4, below; from the camp 300 m off at the player's field of
    view and magnified; beside the galleon of --galleon-glb at 300 m; a stand-in wonder sky; the far mesh at
    450 m) and four daylight check shots

Blender works Z-up and the glTF exporter maps Blender (x, y, z) to glTF
(x, z, -y), so everything is built in Godot coordinates and converted once by
G(); the windings below are worked out in Godot space (a proper rotation, so
they survive the conversion).
"""

import argparse
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))

# --------------------------------------------------------------------------
# Hull form (Godot axes, metres)
# --------------------------------------------------------------------------
B0 = 3.75                    # half-breadth at the maximum breadth line
YK = 0.40                    # rabbet line (top of the keel); keel underside y = 0
HM = 0.50                    # maximum breadth height, fraction rabbet -> sheer
TUMBLE = 0.10                # tumblehome at the sheer, fraction of B0
DRISE = 0.45                 # rise of floor (a visible V section)
Z_DW, DW_POW = 6.4, 1.5      # the run below the tuck fines away aft of here (hollow) into a thin deadwood fin
DW_H = (0.22, 0.47)          # ... fully below the first height fraction, not at all above the second
KEEL_W = 0.32                # keel siding; it stands proud of the garboards in a lighter timber
KEEL_BAND = ("oak", (2, 4))  # keel, stem and sternpost: one weathered-oak plank (the "dark" band vanished from below)
Z_FOREFOOT, STEM_RUN = -10.2, 3.0
Z_POST = 10.0                # sternpost at the keel (raked ~10 deg aft up to the wing transom)
H_WT, Z_WT = 0.52, 10.45     # wing transom (top of the sternpost)
H_C, Z_C = 0.80, 12.6        # top of the counter (the round tuck overhangs the post by ~2 m)
TRANSOM_RAKE = 0.20          # z gained per 0.2 of height fraction above the counter
TW = 0.70                    # transom half-width, fraction of B0
TUCK = (H_WT - 0.04, 0.62)   # below the first height the planking closes on the post (round tuck)
SB, SM = 0.40, 0.55          # entrance ends / run starts (fraction of length)
SHEER_MID, SHEER_LOW_Z, SHEER_BOW, SHEER_STERN = 4.25, 1.0, 1.15, 0.80
SHEER_BOW_HEAD = 0.75        # the bow sheer the knee of the head was drawn to (bow_lift adapts it)
BULWARK = 1.05               # main deck below the main rail
BT = 0.14                    # bulwark thickness
CAMBER = 0.10
FC_UP, FC_RAIL = 1.20, 0.90  # forecastle deck above the main deck; its rail
QD_UP, QD_RAIL = 1.35, 1.00
E_FC = FC_UP - BULWARK + FC_RAIL
E_QD = QD_UP - BULWARK + QD_RAIL
Z_FC_BREAK, Z_QD_BREAK, RAMP = -7.4, 3.9, 0.7
TRANSOM_BULGE = 0.10

PORTS_Z = [-5.4, -3.5, -1.6, 0.3, 2.6, 5.0]
PORTS_OPEN = [True, True, False, True, True, False]
PORT_W, PORT_H, PORT_SILL = 0.62, 0.55, 0.35

# Masts
Y_STEP = 3.3
Z_FORE, RAKE_FORE = -7.6, math.radians(2.0)
Z_MAIN, RAKE_MAIN = 2.2, math.radians(4.0)
STEEVE = math.radians(22.0)

# Atlas
ATLAS = 1024
EMIT = 512


def _b(p0, p1):
    return (p0 / ATLAS, p1 / ATLAS)


BAND = {"oak": _b(0, 128), "tar": _b(128, 256), "deck": _b(256, 384), "grain": _b(384, 448),
        "dark": _b(448, 512), "paint": _b(512, 576), "paint2": _b(576, 640), "canvas": _b(640, 960)}
CELL_V = _b(960, 1024)
CELLS = ["window", "gilt", "brass", "glass", "ether", "glow", "hemp", "crystal"]
CANVAS_TILE = 2.4            # metres of sail per U tile (4 cloths)
# etherium membrane: honey amber (sRGB, hub -> edge), alpha, linear glow level (hub, + toward the edge)
# (the membranes glow a little yellower than the rib strips: an orange glow under ~1/3 blue sky reads pink)
# glow = (level at the rim, extra toward the hub); halo = extra glow beside the ribs (the strips' light in the
# membrane), so the panels read without the sun behind them; crystal = (level at the ends, extra at the core)
ETHER = dict(rgb0=(0.58, 0.33, 0.05), rgb1=(0.70, 0.44, 0.09), alpha=0.66, glow=(0.20, 0.12), halo=0.16,
             glow_rgb=(1.0, 0.62, 0.20), membrane_rgb=(1.0, 0.72, 0.30), crystal=(0.16, 0.30),
             vein_rgb=(0.80, 0.56, 0.20), rim_rgb=(0.84, 0.60, 0.22), strip_rgb=(1.0, 0.80, 0.42),
             crystal_rgb=((0.74, 0.43, 0.10), (0.95, 0.64, 0.24)))

OAK = (0.46, 0.33, 0.20)      # weathered oak upper works
TAR = (0.10, 0.085, 0.07)     # tarred bottom and wales (browner, matte)
BRASS = (0.72, 0.60, 0.31)    # a little darker and greener than polished brass
CANVAS = (0.80, 0.76, 0.67)   # warm canvas, a value below the sky's, so the sails hold against it from below
HULL_U = 12.0                 # metres of hull per U tile of the planking bands (butts ~6 m apart)

# Knobs a variant rebinds (use_hunter); these defaults are the galleon's, and every function reads them when it runs
N_FULL = (1.55, 0.65)         # section fullness (n_full): finer at the ends, fuller midships
F_TOP = 1.65                  # depth below the sheer of the lower wale, where the "f" rows end
WALE = (1.65, 1.25)           # the main wale moulding (depths below the sheer)
RUDDER_TOP = 3.55
WHEEL_Z = 9.0
DOOR_X = 1.15                 # the doors in the bulkheads at the breaks
BOWSPRIT = dict(head_y=5.48, out=3.9, heel=3.7, jb_back=1.8, jb_steeve=19.0, jb_len=4.6)
DECK_RGB, GRAIN_RGB, DARK_RGB = (0.62, 0.55, 0.43), (0.60, 0.48, 0.34), (0.25, 0.16, 0.10)
PAINT_RGB, BEAD_RGB = (0.055, 0.215, 0.215), (0.86, 0.66, 0.27)    # the painted strake, its beading and the gilt
HEMP_RGB = (0.58, 0.48, 0.33)
BRASS_MOTTLE = (0.36, 0.33, 0.19)
WINDOW = dict(lit=(1.0, 0.80, 0.46), frame=(0.17, 0.10, 0.05), emit=(1.0, 0.70, 0.34))
GLASS = dict(bars=(0.25, 0.18, 0.08), lit=(1.0, 0.86, 0.56), emit=(1.0, 0.78, 0.42))
CANVAS_CLOTHS = 4             # cloths per U tile of the canvas band (CANVAS_TILE / 0.6 m)
CANVAS_PATCHES = 0            # seed of the patches sewn over the canvas band (0: none)
CANVAS_SHIFT = 0.0            # each sail's canvas starts this far along the band (U tiles) from the last one's
WOOD_EMIT = 4.0               # emission strength on Wood (the lit windows and lantern glass)
METAL = (0.32, 1.0)           # roughness, metallic of the "Brass" material
MAT_NAMES = {}                # material key -> the name exported, where it differs from the key
ATLAS_NAMES = ("galleon_atlas", "galleon_emission")
LOD_GLOW = False              # Galleon_LOD1 draws the keel-wing spars in EtheriumGlow (lines of light far away)

MATS = {}


# --------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------
def V(x, y, z):
    return Vector((x, y, z))


def G(p):
    """Godot-space point in Blender coordinates."""
    return Vector((p[0], -p[2], p[1]))


def lerp(a, b, t):
    return a + (b - a) * t


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def smoothstep(a, b, x):
    t = clamp((x - a) / (b - a))
    return t * t * (3.0 - 2.0 * t)


def newell(pts):
    n = Vector((0.0, 0.0, 0.0))
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


def catmull(points, per_seg=6):
    P = [Vector(p) for p in points]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(per_seg):
            t = k / per_seg
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-2].copy())
    return out


def mirror(p):
    return V(-p.x, p.y, p.z)


class UB:
    """UVs in a full-width atlas band: a = metres along U (tiles), b = 0..1 across."""
    def __init__(self, band, tile=4.0, sub=None):
        v0, v1 = BAND[band]
        if sub is not None:
            k, n = sub
            v0, v1 = lerp(v0, v1, k / n), lerp(v0, v1, (k + 1) / n)
        m = 1.5 / ATLAS
        self.v0, self.v1, self.tile = v0 + m, v1 - m, tile

    def __call__(self, a, b):
        return (a / self.tile, lerp(self.v0, self.v1, clamp(b)))


class UC:
    """UVs inside one small atlas cell: a = metres along (0..span), b = 0..1."""
    def __init__(self, name, span=1.0):
        k = CELLS.index(name)
        m = 2.5 / ATLAS
        self.u0, self.u1 = k / 8 + m, (k + 1) / 8 - m
        self.v0, self.v1 = CELL_V[0] + m, CELL_V[1] - m
        self.span = span

    def __call__(self, a, b):
        return (lerp(self.u0, self.u1, clamp(a / self.span)), lerp(self.v0, self.v1, clamp(b)))


# --------------------------------------------------------------------------
# Mesh builder (all input in Godot coordinates)
# --------------------------------------------------------------------------
class MB:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.slots = []

    def slot(self, mat):
        if mat not in self.slots:
            self.slots.append(mat)
        return self.slots.index(mat)

    def vert(self, p):
        return self.bm.verts.new(G(p))

    def face(self, verts, pts, uvs, mat, smooth=False, out=None):
        # drop repeated corners (apex rings), keep order
        vv, pp, uu = [], [], []
        for v, p, t in zip(verts, pts, uvs):
            if vv and (v is vv[-1]):
                continue
            vv.append(v)
            pp.append(p)
            uu.append(t)
        while len(vv) > 1 and vv[0] is vv[-1]:
            vv.pop()
            pp.pop()
            uu.pop()
        if len(vv) < 3:
            return None
        if out is not None:
            if newell(pp).dot(out) < 0.0:
                vv, uu = vv[::-1], uu[::-1]
        try:
            f = self.bm.faces.new(vv)
        except ValueError:
            return None
        f.material_index = self.slot(mat)
        f.smooth = smooth
        for lp, t in zip(f.loops, uu):
            lp[self.uv].uv = t
        return f

    def poly(self, pts, uvs, mat, smooth=False, out=None):
        pts = [Vector(p) for p in pts]
        return self.face([self.vert(p) for p in pts], pts, uvs, mat, smooth, out)

    def grid(self, P, uvf, matf, flip=False, smooth=True, out=None):
        """P[i][j]; quad (i, j) = (i,j) (i,j+1) (i+1,j+1) (i+1,j), reversed by flip, or
        oriented by out(i, j, pts). uvf(i, j, i0, j0) -> uv; matf(i0, j0) -> material or None."""
        BV = [[self.vert(p) for p in row] for row in P]
        for i in range(len(P) - 1):
            for j in range(len(P[0]) - 1):
                m = matf(i, j)
                if m is None:
                    continue
                idx = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
                if flip:
                    idx = idx[::-1]
                uniq = []
                for a in idx:
                    pa = P[a[0]][a[1]]
                    if all((pa - P[b[0]][b[1]]).length > 1e-5 for b in uniq):
                        uniq.append(a)
                if len(uniq) < 3:
                    continue
                pts = [P[a][b] for a, b in uniq]
                if newell(pts).length < 1e-9:
                    continue
                o = out(i, j, pts) if out else None
                self.face([BV[a][b] for a, b in uniq], pts, [uvf(a, b, i, j) for a, b in uniq], m, smooth, o)
        return BV

    def tube(self, path, radii, mat, uvm, sides=8, cap0=False, cap1=False, smooth=True, closed=False,
             normal0=None, phase=0.0):
        path = [Vector(p) for p in path]
        n = len(path)
        if callable(radii):
            rs = [radii(k / max(n - 1, 1)) for k in range(n)]
        elif isinstance(radii, (int, float)):
            rs = [float(radii)] * n
        else:
            rs = list(radii)
        T = []
        for k in range(n):
            if closed:
                a, b = path[k - 1], path[(k + 1) % n]
            else:
                a, b = path[max(k - 1, 0)], path[min(k + 1, n - 1)]
            t = b - a
            T.append(t.normalized() if t.length > 1e-12 else V(0, 1, 0))
        N = Vector(normal0) if normal0 is not None else (V(0, 1, 0) if abs(T[0].y) < 0.9 else V(1, 0, 0))
        rings = []
        for k in range(n):
            N = N - T[k] * T[k].dot(N)
            if N.length < 1e-9:
                N = V(1, 0, 0) - T[k] * T[k].x
            N.normalize()
            B = T[k].cross(N)
            rings.append([path[k] + (N * math.cos(phase + 2 * math.pi * j / sides)
                                     + B * math.sin(phase + 2 * math.pi * j / sides)) * rs[k] for j in range(sides)])
        L = [0.0]
        for k in range(1, n):
            L.append(L[-1] + (path[k] - path[k - 1]).length)
        BV = []
        for k in range(n):
            if rs[k] < 1e-7:
                v = self.vert(path[k])
                BV.append([v] * sides)
            else:
                BV.append([self.vert(p) for p in rings[k]])
        segs = n if closed else n - 1
        for k in range(segs):
            k2 = (k + 1) % n
            la = L[k]
            lb = L[k2] if k2 else L[-1] + (path[0] - path[-1]).length
            c = (path[k] + path[k2]) * 0.5
            for j in range(sides):
                j2 = (j + 1) % sides
                pts = [rings[k][j], rings[k][j2], rings[k2][j2], rings[k2][j]]
                o = (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25 - c
                uvs = [uvm(la, j / sides), uvm(la, (j + 1) / sides), uvm(lb, (j + 1) / sides), uvm(lb, j / sides)]
                self.face([BV[k][j], BV[k][j2], BV[k2][j2], BV[k2][j]], pts, uvs, mat, smooth, o)
        if not closed:
            for flag, k, sgn in ((cap0, 0, -1.0), (cap1, n - 1, 1.0)):
                if flag and rs[k] > 1e-6:
                    uvs = [uvm(L[k], 0.5 + 0.45 * math.cos(2 * math.pi * j / sides)) for j in range(sides)]
                    self.face(BV[k], rings[k], uvs, mat, False, T[k] * sgn)
        return rings

    def line(self, a, b, r, mat, sides=5, uvm=None):
        uvm = uvm or (UB("tar", 2.0) if mat == "Tar" else UC("hemp", 1.0))
        self.tube([a, b], r, mat, uvm, sides=sides, smooth=True)

    def box(self, c, ax, ay, az, mat, uvm, skip=()):
        """c centre; ax, ay, az half-extent vectors."""
        c, ax, ay, az = Vector(c), Vector(ax), Vector(ay), Vector(az)
        for key, nrm, u, w in (("+x", ax, ay, az), ("-x", -ax, ay, az), ("+y", ay, ax, az), ("-y", -ay, ax, az),
                               ("+z", az, ax, ay), ("-z", -az, ax, ay)):
            if key in skip:
                continue
            pts = [c + nrm - u - w, c + nrm + u - w, c + nrm + u + w, c + nrm - u + w]
            if u.length >= w.length:
                uvs = [uvm(0, 0), uvm(2 * u.length, 0), uvm(2 * u.length, 1), uvm(0, 1)]
            else:
                uvs = [uvm(0, 0), uvm(0, 1), uvm(2 * w.length, 1), uvm(2 * w.length, 0)]
            self.poly(pts, uvs, mat, False, nrm)

    def beam(self, p0, p1, w, h, up, mat, uvm, skip=()):
        p0, p1 = Vector(p0), Vector(p1)
        t = (p1 - p0) * 0.5
        side = t.cross(Vector(up))
        if side.length < 1e-9:
            side = t.cross(V(1, 0, 0))
        side = side.normalized() * (w * 0.5)
        upv = side.cross(t).normalized() * (h * 0.5)
        self.box((p0 + p1) * 0.5, t, side, upv, mat, uvm, skip)

    def obj(self):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        me.validate()
        for m in self.slots:
            me.materials.append(MATS[m])
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def lathe(mb, origin, axis, profile, mat, uvm, sides=10, perp=None, cap0=True, cap1=True, smooth=True):
    """profile [(t, r)] along the axis from origin."""
    ax = Vector(axis).normalized()
    o = Vector(origin)
    if perp is None:
        perp = V(1, 0, 0) if abs(ax.x) < 0.9 else V(0, 1, 0)
    return mb.tube([o + ax * t for t, r in profile], [r for t, r in profile], mat, uvm, sides=sides,
                   cap0=cap0, cap1=cap1, smooth=smooth, normal0=perp)


def torus(mb, c, normal, R, r, mat, uvm, seg=20, sides=6):
    nrm = Vector(normal).normalized()
    e1 = V(1, 0, 0) if abs(nrm.x) < 0.9 else V(0, 1, 0)
    e1 = (e1 - nrm * nrm.dot(e1)).normalized()
    e2 = nrm.cross(e1)
    path = [Vector(c) + (e1 * math.cos(2 * math.pi * k / seg) + e2 * math.sin(2 * math.pi * k / seg)) * R
            for k in range(seg)]
    mb.tube(path, r, mat, uvm, sides=sides, closed=True, normal0=nrm)


# --------------------------------------------------------------------------
# The hull surface
# --------------------------------------------------------------------------
def zb(h):
    """Stem (bow end) at height fraction h."""
    if h <= 1.0:
        return Z_FOREFOOT - STEM_RUN * math.sqrt(max(0.0, 1.0 - (1.0 - h) ** 2))
    return Z_FOREFOOT - STEM_RUN - 0.25 * (h - 1.0)


def zs(h):
    """Stern end: raked sternpost, the counter, then the transom."""
    if h <= H_WT:
        return Z_POST + (Z_WT - Z_POST) * max(h, 0.0) / H_WT
    if h <= H_C:
        return Z_WT + (Z_C - Z_WT) * math.sin(0.5 * math.pi * (h - H_WT) / (H_C - H_WT))
    return Z_C + TRANSOM_RAKE * (h - H_C) / 0.2


Z_BOW_TOP, Z_STERN_TOP = zb(1.0), zs(1.0)


def zn_of(s):
    return lerp(Z_BOW_TOP, Z_STERN_TOP, s)


def s_of_zn(z):
    return (z - Z_BOW_TOP) / (Z_STERN_TOP - Z_BOW_TOP)


def sheer(s):
    zn = zn_of(s)
    if zn < SHEER_LOW_Z:
        k = (zn - SHEER_LOW_Z) / (Z_BOW_TOP - SHEER_LOW_Z)
        return SHEER_MID + SHEER_BOW * k * k
    k = (zn - SHEER_LOW_Z) / (Z_STERN_TOP - SHEER_LOW_Z)
    return SHEER_MID + SHEER_STERN * k * k


def deck_y(s):
    return sheer(s) - BULWARK


def raise_e(s):
    zn = zn_of(s)
    fc = E_FC * (1.0 - smoothstep(Z_FC_BREAK, Z_FC_BREAK + RAMP, zn))
    qd = E_QD * smoothstep(Z_QD_BREAK - RAMP, Z_QD_BREAK, zn)
    return max(fc, qd)


def n_full(s):
    return N_FULL[0] + N_FULL[1] * math.sin(math.pi * clamp(s)) ** 0.5


def plan(s, h):
    hc = clamp(h, 0.0, 1.0)
    t = clamp(s / SB)
    p = 1.0 - (1.0 - t) ** lerp(1.8, 3.4, hc)
    if s > SM:
        t2 = (s - SM) / (1.0 - SM)
        tw = TW * smoothstep(TUCK[0], TUCK[1], h)
        p *= 1.0 - (1.0 - tw) * t2 ** lerp(1.6, 3.0, hc)
        # deadwood: below the tuck the run goes hollow aft of Z_DW, so under the counter the stern is a
        # thin fin closing on the post rather than a full box
        wl = 1.0 - smoothstep(DW_H[0], DW_H[1], h)
        if wl > 0.0:
            z, z_end = lerp(zb(h), zs(h), s), zs(h)
            t3 = clamp((z - Z_DW) / max(z_end - Z_DW, 1e-6))
            p *= lerp(1.0, (1.0 - t3) ** DW_POW, wl)
    return p


def _pt(s, h, xs, y):
    return V(B0 * plan(s, h) * xs, y, lerp(zb(h), zs(h), s))


def hull_lo(s, v):
    n = n_full(s)
    th = 0.5 * math.pi * clamp(v)
    st, ct = math.sin(th), math.cos(th)
    xs = st ** (2.0 / n)
    h = HM * (1.0 - ct ** (2.0 / n)) + DRISE * st * (1.0 - st)
    S = sheer(s)
    return _pt(s, h, xs, YK + h * (S - YK))


def hull_d(s, d):
    S = sheer(s)
    y = S - d
    h = (y - YK) / (S - YK)
    k = max(h - HM, 0.0) / (1.0 - HM)
    return _pt(s, h, 1.0 - TUMBLE * k ** 1.7, y)


def hp(s, spec):
    kind, val = spec
    if kind == "lo":
        return hull_lo(s, val)
    if kind == "d":
        return hull_d(s, val)
    if kind == "f":
        # between the maximum breadth line and the lower wale (the tuck needs the rows there)
        S = sheer(s)
        return hull_d(s, lerp((1.0 - HM) * (S - YK), F_TOP, val))
    return hull_d(s, -val * raise_e(s))


def hnorm(s, spec):
    e = 0.004
    a, b = hp(max(s - e, 0.0), spec), hp(min(s + e, 1.0), spec)
    t = b - a
    n = V(t.z, 0.0, -t.x)
    if n.length < 1e-9:
        return V(1, 0, 0)
    return n.normalized()


def hin(s, spec, t=BT):
    p = hp(s, spec)
    q = p - hnorm(s, spec) * t
    q.x = max(q.x, 0.0)
    return q


def s_at(z, spec):
    """Station whose point on row `spec` lies at Godot z (bisection)."""
    lo, hi = 0.0, 1.0
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        if hp(mid, spec).z < z:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


S_FCB, S_QDB = s_of_zn(Z_FC_BREAK), s_of_zn(Z_QD_BREAK)


def station_list(n):
    ss = [lerp(k / n, 0.5 - 0.5 * math.cos(math.pi * k / n), 0.6) for k in range(n + 1)]
    keys = [s_of_zn(z) for z in (Z_FC_BREAK, Z_FC_BREAK + 0.5 * RAMP, Z_FC_BREAK + RAMP,
                                 Z_QD_BREAK - RAMP, Z_QD_BREAK - 0.5 * RAMP, Z_QD_BREAK)]
    allv = sorted(set(ss) | set(keys))
    res = []
    for s in allv:
        if res and s - res[-1] < 0.0035:
            if s in keys:
                res[-1] = s
            continue
        res.append(s)
    res[0], res[-1] = 0.0, 1.0
    return res


OUTER_ROWS = {
    0: [("lo", k / 14) for k in range(15)] + [("f", 0.4), ("f", 0.75), ("d", 1.65), ("d", 1.20), ("d", 0.70),
                                              ("d", 0.35), ("d", 0.0), ("r", 0.38), ("r", 0.75), ("r", 1.0)],
    1: [("lo", 0.0), ("lo", 0.3), ("lo", 0.6), ("lo", 1.0), ("f", 0.6), ("d", 1.20), ("d", 0.70), ("d", 0.0),
        ("r", 1.0)],
}


def seg_kind(sa, sb, lod):
    if sb[0] in ("lo", "f") or sb in (("d", 1.65), ("d", 1.20)):
        return "tar"
    if sb == ("d", 0.70):
        return "paint"
    if sb == ("r", 1.0) and lod == 0:
        return "paint"
    return "oak"


KIND_MAT = {"tar": "Tar", "oak": "Wood", "paint": "Paint", "paint2": "Paint", "dark": "Wood", "deck": "Wood",
            "grain": "Wood"}


def band_uv(kind, j0, is_top, u):
    """UV for a planked row: each row is one plank of a 4-variant band (paint rows use the whole band)."""
    v0, v1 = BAND[kind]
    m = 1.5 / ATLAS
    if kind in ("oak", "tar"):
        k = j0 % 4
        a, b = lerp(v0, v1, k / 4) + m, lerp(v0, v1, (k + 1) / 4) - m
    else:
        a, b = v0 + m, v1 - m
    return (u, b if is_top else a)


def build_hull_shell(mb, lod):
    st = station_list(60 if lod == 0 else 12)
    rows = OUTER_ROWS[lod]
    kinds = [seg_kind(rows[j], rows[j + 1], lod) for j in range(len(rows) - 1)]
    P = [[hp(s, r) for r in rows] for s in st]
    for side in (1, -1):
        Q = P if side > 0 else [[mirror(p) for p in col] for col in P]
        uvf = (lambda a, b, i0, j0, Q=Q: band_uv(kinds[j0], j0, b > j0, Q[a][b].z / HULL_U))
        mb.grid(Q, uvf, lambda i, j: KIND_MAT[kinds[j]], flip=(side < 0), smooth=True)
    build_transom(mb, rows, lod)
    return st


def transom_xyz(spec):
    p = hp(1.0, spec)
    return p.x, p.y, p.z


def transom_point(x, y):
    """Point on the (bulged) transom face at height y."""
    xr, yy, zr = transom_xyz(("d", sheer(1.0) - y))
    q = clamp(x / max(xr, 1e-6), -1.0, 1.0)
    return V(x, y, zr + TRANSOM_BULGE * xr * (1.0 - q * q))


def build_transom(mb, rows, lod):
    qs = [1.0, 0.5, 0.0, -0.5, -1.0] if lod == 0 else [1.0, 0.0, -1.0]
    first = next(k for k, r in enumerate(rows) if hp(1.0, r).x > 0.03)
    rr = rows[max(first - 1, 0):]              # from the last row that closes on the post
    cols = []
    for q in qs:
        col = []
        for r in rr:
            xr, y, zr = transom_xyz(r)
            col.append(V(q * xr, y, zr + TRANSOM_BULGE * xr * (1 - q * q)))
        cols.append(col)

    def hkind(j):
        y = 0.5 * (cols[0][j].y + cols[0][j + 1].y)
        h = (y - YK) / (sheer(1.0) - YK)
        return "tar" if h < H_WT else ("oak" if h < H_C else "paint2")

    uvf = (lambda a, b, i0, j0: band_uv(hkind(j0), j0, b > j0, cols[a][b].x / 4.0))
    mb.grid(cols, uvf, lambda i, j: KIND_MAT[hkind(j)], smooth=False,
            out=lambda i, j, pts: V(0, -0.3, 1.0))
    # forward face of the transom above the quarterdeck
    inner = [("d", BULWARK - QD_UP + 0.06), ("r", 0.6), ("r", 1.0)]
    cols = []
    for q in qs:
        col = []
        for r in inner:
            p = hin(1.0, r)
            col.append(V(q * p.x, p.y, p.z + TRANSOM_BULGE * p.x * (1 - q * q)))
        cols.append(col)
    mb.grid(cols, lambda a, b, i0, j0: UB("paint2", 3.0)(cols[a][b].x, (cols[a][b].y - 4.7) / 1.6),
            lambda i, j: "Paint", smooth=False, out=lambda i, j, pts: V(0, 0, -1))


INNER = {
    "fc": [("d", BULWARK - FC_UP + 0.06), ("r", 0.6), ("r", 1.0)],
    "waist": [("d", BULWARK + 0.06), ("d", 0.70), ("d", 0.35), ("d", 0.0), ("r", 0.5), ("r", 1.0)],
    "qd": [("d", BULWARK - QD_UP + 0.06), ("r", 0.6), ("r", 1.0)],
}


def build_bulwarks(mb, st, lod):
    regions = [("fc", [s for s in st if s <= S_FCB + 1e-9]),
               ("waist", [s for s in st if S_FCB - 1e-9 <= s <= S_QDB + 1e-9]),
               ("qd", [s for s in st if s >= S_QDB - 1e-9])]
    for key, ss in regions:
        rows = INNER[key] if lod == 0 else [INNER[key][0], INNER[key][-1]]
        P = [[hin(s, r) for r in rows] for s in ss]
        for side in (1, -1):
            Q = P if side > 0 else [[mirror(p) for p in col] for col in P]
            uvf = (lambda a, b, i0, j0, Q=Q: band_uv("oak", j0 + 1, b > j0, Q[a][b].z / HULL_U))
            mb.grid(Q, uvf, lambda i, j: "Wood", flip=(side > 0), smooth=True)
    # rail cap round the whole top line
    top = ("r", 1.0)
    caps = []
    for s in st:
        o, i_, n = hp(s, top), hin(s, top), hnorm(s, top)
        up, dn = V(0, 0.07, 0), V(0, -0.06, 0)
        A = o + n * 0.05 + dn
        B = o + n * 0.05 + up
        C = i_ - n * 0.05 + up
        D = i_ - n * 0.05 + dn
        C.x, D.x = max(C.x, 0.0), max(D.x, 0.0)
        caps.append([A, B, C, D, A.copy()] if lod == 0 else [B, C])
    uvm = UB("dark", 3.0)
    for side in (1, -1):
        Q = caps if side > 0 else [[mirror(p) for p in col] for col in caps]
        if lod == 0:
            def out(i, j, pts, Q=Q, side=side):
                n = hnorm(st[i], top)
                n.x *= side
                return [n, V(0, 1, 0), -n, V(0, -1, 0)][j]
        else:
            def out(i, j, pts):
                return V(0, 1, 0)
        mb.grid(Q, lambda a, b, i0, j0, Q=Q: uvm(Q[a][b].z, (b - j0) * 1.0), lambda i, j: "Wood",
                smooth=False, out=out)


def moulding(mb, st, d_lo, d_hi, off, mat, kind, sub):
    """A raised band along the hull between two depths below the sheer (wales, sheer rail)."""
    lo_s, hi_s, mid = ("d", d_lo), ("d", d_hi), ("d", 0.5 * (d_lo + d_hi))
    P = []
    for s in st:
        n = hnorm(s, mid)
        a, b = hp(s, lo_s), hp(s, hi_s)
        P.append([a, a + n * off, b + n * off, b])
    for side in (1, -1):
        Q = P if side > 0 else [[mirror(p) for p in col] for col in P]

        def out(i, j, pts, side=side):
            n = hnorm(st[i], mid)
            n.x *= side
            return [V(0, -1, 0), n, V(0, 1, 0)][j]
        mb.grid(Q, lambda a, b, i0, j0, Q=Q: band_uv(kind, sub, b > j0, Q[a][b].z / HULL_U), lambda i, j: mat,
                smooth=False, out=out)
        e = Q[-1]
        mb.poly(e, [(0.1, BAND[kind][0] + 0.01)] * 4, mat, False, V(0, 0, 1))


def build_wale(mb, st):
    moulding(mb, st, WALE[0], WALE[1], 0.075, "Tar", "tar", 3)
    # sheer rail: a dark moulding along the main sheer, which breaks the raised bulwarks
    moulding(mb, st, 0.07, -0.05, 0.05, "Wood", "dark", 0)


def deck_point(s, depth):
    return hin(s, ("d", depth))


def build_deck(mb, ss, y_of, depth, lod):
    XS = [0.0, 0.8, 1.6, 2.4, 3.2, 4.0] if lod == 0 else [0.0, 2.0, 4.0]
    v0, v1 = BAND["deck"]
    m = 1.5 / ATLAS
    for side in (1, -1):
        for k in range(len(XS) - 1):
            a, b = XS[k], XS[k + 1]
            P = []
            for s in ss:
                q = deck_point(s, depth)
                w, z, y0 = q.x, q.z, y_of(s)
                xs = [min(a, w), min(0.5 * (a + b), w), min(b, w)] if lod == 0 else [min(a, w), min(b, w)]
                P.append([V(side * x, y0 + CAMBER * (1 - (x / 3.6) ** 2), z) for x in xs])
            if all(col[-1].x * side - a < 0.004 for col in P):
                continue
            mb.grid(P, (lambda i, j, i0, j0, P=P, a=a: (P[i][j].z / 6.0,
                                                          lerp(v0 + m, v1 - m, clamp((abs(P[i][j].x) - a) / 0.8)))),
                    lambda i, j: "Wood", smooth=True, out=lambda i, j, pts: V(0, 1, 0))


def deck_surface_y(s, x, raised=0.0):
    return deck_y(s) + raised + CAMBER * (1 - (x / 3.6) ** 2)


def build_decks(mb, st, lod):
    waist = [s for s in st if S_FCB - 0.02 <= s <= S_QDB + 0.02]
    build_deck(mb, waist, deck_y, BULWARK, lod)
    fc = [s for s in st if s <= S_FCB + 1e-9]
    build_deck(mb, fc, lambda s: deck_y(s) + FC_UP, BULWARK - FC_UP, lod)
    qd = [s for s in st if s >= S_QDB - 1e-9]
    build_deck(mb, qd, lambda s: deck_y(s) + QD_UP, BULWARK - QD_UP, lod)
    # bulkheads at the breaks
    for sb_, up, face_z, depth_r in ((S_FCB, FC_UP, 1.0, BULWARK - FC_UP), (S_QDB, QD_UP, -1.0, BULWARK - QD_UP)):
        q = deck_point(sb_, BULWARK)
        w, z = q.x, q.z
        xs = [-w, -0.5 * w, 0.0, 0.5 * w, w]
        cols = [[V(x, deck_surface_y(sb_, x) - 0.05, z), V(x, deck_surface_y(sb_, x, up) + 0.02, z)] for x in xs]
        mb.grid(cols, lambda i, j, i0, j0: UB("paint2", 3.0)(cols[i][j].x, j * 1.0), lambda i, j: "Paint",
                smooth=False, out=lambda i, j, pts, fz=face_z: V(0, 0, fz))
        if lod:
            continue
        # doors, small lit windows (quarterdeck), breast rail with balusters, ladders
        dark = UB("dark", 2.0)
        for x in (-DOOR_X, DOOR_X):
            yb = deck_surface_y(sb_, x)
            mb.box(V(x, yb + 0.62, z + face_z * 0.03), V(0.40, 0, 0), V(0, 0.60, 0), V(0, 0, 0.03), "Wood", dark)
            mb.box(V(x + 0.28, yb + 0.62, z + face_z * 0.07), V(0.04, 0, 0), V(0, 0.04, 0), V(0, 0, 0.02), "Brass",
                   UC("brass"))
        if face_z < 0:
            for x in (-0.42, 0.42):
                yb = deck_surface_y(sb_, x)
                c = V(x, yb + 0.85, z - 0.025)
                mb.poly([c + V(-0.17, -0.15, 0), c + V(0.17, -0.15, 0), c + V(0.17, 0.15, 0), c + V(-0.17, 0.15, 0)],
                        [UC("window")(0, 0), UC("window")(1, 0), UC("window")(1, 1), UC("window")(0, 1)],
                        "Wood", False, V(0, 0, -1))
                mb.box(c + V(0, 0, -0.01), V(0.21, 0, 0), V(0, 0.19, 0), V(0, 0, 0.012), "Paint", UC("gilt"),
                       skip=("-z", "+z"))
        yr = deck_surface_y(sb_, 0.0, up)
        zr = z - face_z * 0.12
        gap = 0.95                      # ladder openings near the sides
        xs = [x for x in np.arange(-w + 0.25, w - 0.2, 0.32) if abs(abs(x) - (w - gap)) > 0.45]
        for x in xs:
            mb.box(V(x, yr + 0.45, zr), V(0.035, 0, 0), V(0, 0.45, 0), V(0, 0, 0.035), "Wood", UB("grain", 2.0))
        segs = [(-w + 0.15, -(w - gap) - 0.45), (-(w - gap) + 0.45, (w - gap) - 0.45), ((w - gap) + 0.45, w - 0.15)]
        for x0, x1 in segs:
            mb.box(V(0.5 * (x0 + x1), yr + 0.93, zr), V(0.5 * (x1 - x0), 0, 0), V(0, 0.045, 0), V(0, 0, 0.07),
                   "Wood", dark)
        for sx in (-1, 1):
            xc = sx * (w - gap)
            yb, yt = deck_surface_y(sb_, xc), yr
            run = (yt - yb) * 0.62
            zb0, zt0 = z + face_z * run, z
            for k in (-1, 1):
                mb.beam(V(xc + k * 0.3, yb, zb0), V(xc + k * 0.3, yt + 0.05, zt0 + face_z * 0.05), 0.20, 0.06,
                        V(1, 0, 0), "Wood", dark)
            nst = 5
            for t in range(1, nst + 1):
                f = t / (nst + 1)
                mb.box(V(xc, lerp(yb, yt, f), lerp(zb0, zt0, f)), V(0.29, 0, 0), V(0, 0.025, 0), V(0, 0, 0.12),
                       "Wood", UB("grain", 2.0))


def build_keel_stem(mb, lod):
    """Keel, stem and sternpost in a lighter (untarred) timber than the bottom, so one timber line runs the
    whole length of the hull from below; the rudder stays tarred."""
    tar = UB("tar", 8.0, (1, 4))
    timber = UB(KEEL_BAND[0], 6.0, KEEL_BAND[1])
    kw = 0.5 * KEEL_W
    k0, k1 = Z_FOREFOOT, Z_POST + 0.1
    mb.box(V(0, 0.23, 0.5 * (k0 + k1)), V(kw, 0, 0), V(0, 0.23, 0), V(0, 0, 0.5 * (k1 - k0)), "Wood", timber)
    # stem: a timber round the forefoot and up the stem
    hs = [k / 16 * 1.06 for k in range(17)] if lod == 0 else [0.0, 0.3, 0.6, 1.06]
    path = [V(0, YK + h * (sheer(0.0) - YK), zb(h)) for h in hs]
    path[0] = V(0, 0.21, Z_FOREFOOT + 0.05)
    prof = [(-kw, -0.06), (kw, -0.06), (kw, 0.22), (-kw, 0.22)]
    rings = []
    for k, p in enumerate(path):
        a, b = path[max(k - 1, 0)], path[min(k + 1, len(path) - 1)]
        t = (b - a).normalized()
        nrm = V(1, 0, 0).cross(t).normalized() * -1.0      # outward (forward-down)
        rings.append([p + V(x, 0, 0) + nrm * o for x, o in prof])
    cols = [r + [r[0].copy()] for r in rings]
    mb.grid(cols, lambda i, j, i0, j0: timber(cols[i][j].y, (j - j0) * 1.0), lambda i, j: "Wood", smooth=False,
            out=lambda i, j, pts: (pts[0] + pts[2]) * 0.5 - (path[i] + path[i + 1]) * 0.5)
    # sternpost
    a = V(0, 0.0, Z_POST + 0.12)
    b = V(0, YK + H_WT * (sheer(1.0) - YK) + 0.15, Z_WT + 0.12)
    mb.beam(a, b, KEEL_W - 0.02, 0.34, V(1, 0, 0), "Wood", timber)
    if lod:
        return
    # rudder
    y0, y1 = 0.12, RUDDER_TOP
    pts = []
    for y in (y0, y1):
        zp = lerp(Z_POST, Z_WT, clamp((y - YK) / ((sheer(1.0) - YK) * H_WT), 0, 1.3)) + 0.30
        chord = 1.0 if y == y0 else 0.8          # the aft edge rakes with the post
        pts.append((y, zp, zp + chord))
    (ya, za0, za1), (yb, zb0, zb1) = pts
    q = [V(0, ya, za0), V(0, ya, za1), V(0, yb, zb1), V(0, yb, zb0)]
    for sx in (1, -1):
        th = [0.16, 0.10, 0.12, 0.17]
        mb.poly([p + V(sx * t, 0, 0) for p, t in zip(q, th)],
                [tar(p.z, (p.y - y0) / 3.5) for p in q], "Tar", False, V(sx, 0, 0))
    for k in range(4):
        p0, p1 = q[k], q[(k + 1) % 4]
        t0, t1 = [0.16, 0.10, 0.12, 0.17][k], [0.16, 0.10, 0.12, 0.17][(k + 1) % 4]
        quad = [p0 + V(t0, 0, 0), p1 + V(t1, 0, 0), p1 + V(-t1, 0, 0), p0 + V(-t0, 0, 0)]
        c = sum(q, Vector()) / 4
        mb.poly(quad, [tar(0, 0), tar(1, 0), tar(1, 1), tar(0, 1)], "Tar", False, (p0 + p1) * 0.5 - c)
    for y in (0.6, 1.6, 2.6):
        zp = lerp(za0, zb0, (y - ya) / (yb - ya))
        mb.box(V(0, y, zp + 0.05), V(0.2, 0, 0), V(0, 0.06, 0), V(0, 0, 0.32), "Brass", UC("brass"))


def bow_lift(p):
    """The head was drawn to a bow sheer of SHEER_BOW_HEAD: lift a point of it with the sheer, by
    as much as the sheer rises at its station and in proportion to its height above the rabbet."""
    p = Vector(p)
    k = clamp((p.z - SHEER_LOW_Z) / (Z_BOW_TOP - SHEER_LOW_Z))
    f = clamp((p.y - YK) / (SHEER_MID + SHEER_BOW_HEAD - YK), 0.0, 1.3)
    return p + V(0, (SHEER_BOW - SHEER_BOW_HEAD) * k * k * f, 0)


def build_head(mb):
    """Knee of the head with a gilt scroll figurehead, trailboards, head rails, catheads and anchors."""
    S0 = sheer(0.0)

    def stem(h):
        return V(0, YK + h * (S0 - YK), zb(h))
    front = catmull([bow_lift(p) for p in ((0, 1.9, -12.45), (0, 2.75, -13.35), (0, 3.55, -14.05), (0, 4.15, -14.55),
                                           (0, 4.5, -14.8), (0, 4.78, -14.55), (0, 4.92, -13.9), (0, 5.02, -13.32))], 3)
    hs = [lerp(0.33, 1.0, k / (len(front) - 1)) for k in range(len(front))]
    back = [stem(h) + V(0, 0, 0.05) for h in hs]
    tar = UB("tar", 4.0, (2, 4))
    for sx in (1, -1):
        th = [0.07 + 0.08 * (1 - k / (len(front) - 1)) for k in range(len(front))]
        cols = [[back[k] + V(sx * 0.16, 0, 0), front[k] + V(sx * th[k], 0, 0)] for k in range(len(front))]
        mb.grid(cols, lambda i, j, i0, j0, cols=cols: tar(cols[i][j].y, j * 1.0), lambda i, j: "Tar",
                smooth=False, out=lambda i, j, pts, sx=sx: V(sx, 0, 0))
        # gilt trailboard along the knee
        tb = [lerp(back[k], front[k], 0.55) for k in range(2, len(front) - 4)]
        tb2 = [lerp(back[k], front[k], 0.85) for k in range(2, len(front) - 4)]
        cols2 = [[tb[k] + V(sx * (th[k + 2] + 0.035), 0, 0), tb2[k] + V(sx * (th[k + 2] + 0.035), 0, 0)]
                 for k in range(len(tb))]
        g = UC("gilt", 3.0)
        mb.grid(cols2, lambda i, j, i0, j0, cols2=cols2: g(i * 0.25, j * 1.0), lambda i, j: "Paint",
                smooth=False, out=lambda i, j, pts, sx=sx: V(sx, 0, 0))
    cols = [[front[k] + V(0.07 + 0.08 * (1 - k / (len(front) - 1)), 0, 0),
             front[k] + V(-0.07 - 0.08 * (1 - k / (len(front) - 1)), 0, 0)] for k in range(len(front))]
    c = bow_lift(V(0, 3.6, -13.4))
    mb.grid(cols, lambda i, j, i0, j0: tar(i * 0.3, j * 1.0), lambda i, j: "Tar", smooth=False,
            out=lambda i, j, pts: (pts[0] + pts[2]) * 0.5 - c)
    # scroll (billet head) figurehead
    cc = bow_lift(V(0, 4.62, -14.98))
    spiral = []
    for k in range(34):
        th = k / 33 * 3.4 * math.pi
        r = 0.36 * math.exp(-0.17 * th)
        spiral.append(cc + V(0, r * math.cos(th), -r * math.sin(th)))
    mb.tube(spiral, lambda t: lerp(0.085, 0.03, t), "Paint", UC("gilt", 2.0), sides=8, cap0=True, cap1=True)
    # head rails
    dark = UB("dark", 2.0)
    for sx in (1, -1):
        for dy, k in ((0.0, 0), (-0.38, 1)):
            path = catmull([bow_lift(p) for p in ((sx * 2.15, 5.15 + dy, -11.5), (sx * 1.55, 4.95 + dy, -12.7),
                                                  (sx * 0.85, 4.75 + dy, -13.7), (sx * 0.18, 4.55 + dy * 0.6, -14.45))], 4)
            mb.tube(path, 0.055, "Wood", dark, sides=6, cap0=True, cap1=True)
        # cathead and anchor
        a, b = bow_lift(V(sx * 2.05, 5.75, -11.0)), bow_lift(V(sx * 3.05, 5.85, -11.95))
        mb.beam(a, b, 0.26, 0.26, V(0, 1, 0), "Wood", dark)
        mb.box(b + V(sx * 0.02, 0, -0.02), V(0.15, 0, 0), V(0, 0.15, 0), V(0, 0, 0.15), "Paint", UC("gilt"))
        ring = b + V(0, -0.25, 0)
        sa = s_at(-11.1, ("d", 1.35))
        rest = hp(sa, ("d", 1.35)) + hnorm(sa, ("d", 1.35)) * 0.22
        if sx < 0:
            rest = mirror(rest)
        shank_top, shank_bot = ring + V(0, -0.1, 0), rest
        mb.beam(shank_top, shank_bot, 0.12, 0.12, V(1, 0, 0), "Tar", tar)
        mb.beam(shank_top + V(-0.9, -0.25, 0.0), shank_top + V(0.9, -0.25, 0.0), 0.16, 0.16, V(0, 1, 0), "Wood", dark)
        for k in (-1, 1):
            tip = shank_bot + V(0, 0.75, k * 0.85)
            mb.beam(shank_bot, tip, 0.11, 0.11, V(1, 0, 0), "Tar", tar)
            mb.beam(tip, tip + V(0, -0.15, -k * 0.3), 0.06, 0.32, V(1, 0, 0), "Tar", tar)


def port_frame(s, side):
    """Centre, outward normal and along-hull tangent of a gunport (on the hull side)."""
    d_c = BULWARK - PORT_SILL - 0.5 * PORT_H
    c = hp(s, ("d", d_c))
    n = hnorm(s, ("d", d_c))
    t = V(-n.z, 0, n.x)               # aft along the hull (starboard)
    if side < 0:
        c, n, t = mirror(c), mirror(n), mirror(t)
    return c, n, t


def build_gunports(mb, lod):
    tar = UB("tar", 2.0, (0, 4))
    dark = UB("dark", 1.5)
    oak = UB("oak", 2.0, (1, 4))
    iron = UB("tar", 3.0, (3, 4))
    up = V(0, 1, 0)
    for side in (1, -1):
        for k, z in enumerate(PORTS_Z):
            d_c = BULWARK - PORT_SILL - 0.5 * PORT_H
            s = s_at(z, ("d", d_c))
            c, n, t = port_frame(s, side)
            hw, hh = 0.5 * PORT_W, 0.5 * PORT_H
            opening = [c + n * 0.025 + t * a + up * b for a, b in ((-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh))]
            mb.poly(opening, [tar(0, 0), tar(1, 0), tar(1, 1), tar(0, 1)], "Tar", False, n)
            if lod:
                continue
            fw = 0.075
            for a0, a1, b0, b1 in ((-hw - fw, hw + fw, hh, hh + fw), (-hw - fw, hw + fw, -hh - fw, -hh),
                                   (-hw - fw, -hw, -hh, hh), (hw, hw + fw, -hh, hh)):
                cc = c + n * 0.045 + t * (0.5 * (a0 + a1)) + up * (0.5 * (b0 + b1))
                mb.box(cc, t * (0.5 * (a1 - a0)), up * (0.5 * (b1 - b0)), n * 0.04, "Wood", dark, skip=("-z",))
            hinge = c + n * 0.09 + up * (hh + fw)
            lid_n = n
            if PORTS_OPEN[k]:
                ang = math.radians(100.0)
                lid_dn = (-up * math.cos(ang) + n * math.sin(ang))
                lid_n = (up * math.sin(ang) + n * math.cos(ang))
            else:
                lid_dn = -up
            lc = hinge + lid_dn * (hh + fw) + lid_n * 0.03
            mb.box(lc, t * (hw + fw), lid_dn * (hh + fw), lid_n * 0.035, "Wood", oak)
            if not PORTS_OPEN[k]:
                continue
            base = c - n * 1.5 + up * -0.05
            prof = [(0.0, 0.0), (0.03, 0.10), (0.10, 0.12), (0.14, 0.18), (0.6, 0.175), (0.72, 0.19), (0.78, 0.165),
                    (1.75, 0.135), (1.92, 0.13), (1.96, 0.16), (2.08, 0.16), (2.10, 0.09), (2.10, 0.0)]
            lathe(mb, base, n, prof, "Tar", iron, sides=10, perp=up, cap0=False, cap1=False)
            if z < Z_QD_BREAK - 0.7:
                # carriage on the deck under the breech
                inb = c - n * 0.95
                yd = deck_surface_y(s, abs(inb.x))
                mb.box(V(inb.x, yd + 0.24, inb.z), n * 0.55, V(0, 0.2, 0), t * 0.30, "Wood", dark)
                for sgn in (-1, 1):
                    for along in (-0.36, 0.36):
                        wc = inb + n * along + t * (sgn * 0.33)
                        lathe(mb, V(wc.x, yd + 0.14, wc.z), t * sgn,
                              [(0, 0.14), (0.08, 0.14)], "Wood", dark, sides=8, perp=up)


CHANNELS = {"fore": (-8.75, -5.75, [-8.4, -7.6, -6.8, -6.0]), "main": (1.0, 4.2, [1.4, 2.2, 3.0, 3.8])}
D_CH = 0.12


def channel_point(z, side):
    s = s_at(z, ("d", D_CH))
    p, n = hp(s, ("d", D_CH)), hnorm(s, ("d", D_CH))
    if side < 0:
        p, n = mirror(p), mirror(n)
    return s, p, n


def build_channels(mb):
    dark = UB("dark", 3.0)
    tar = UB("tar", 2.0, (2, 4))
    for key, (z0, z1, dz) in CHANNELS.items():
        for side in (1, -1):
            zs_ = [lerp(z0, z1, k / 4) for k in range(5)]
            rows = []
            for z in zs_:
                s, p, n = channel_point(z, side)
                rows.append([p - n * 0.05 + V(0, 0.07, 0), p + n * 0.62 + V(0, 0.07, 0),
                             p + n * 0.62 + V(0, -0.07, 0), p - n * 0.05 + V(0, -0.07, 0)])
            for j, out in ((0, V(0, 1, 0)), (1, None), (2, V(0, -1, 0))):
                cols = [[r[j], r[j + 1]] for r in rows]
                o = out
                if o is None:
                    _, _, nn = channel_point(0.5 * (z0 + z1), side)
                    o = nn
                mb.grid(cols, lambda i, jj, i0, j0, cols=cols: dark(cols[i][jj].z, jj * 1.0), lambda i, jj: "Wood",
                        smooth=False, out=lambda i, jj, pts, o=o: o)
            for r, o in ((rows[0], V(0, 0, -1)), (rows[-1], V(0, 0, 1))):
                mb.poly(r, [dark(0, 0), dark(1, 0), dark(1, 1), dark(0, 1)], "Wood", False, o)
            for z in dz:
                s, p, n = channel_point(z, side)
                top = p + n * 0.52 + V(0, -0.05, 0)
                s2 = s_at(z, ("d", D_CH + 1.15))
                q, n2 = hp(s2, ("d", D_CH + 1.15)), hnorm(s2, ("d", D_CH + 1.15))
                if side < 0:
                    q, n2 = mirror(q), mirror(n2)
                bot = q + n2 * 0.05
                mb.beam(top, bot, 0.09, 0.035, n, "Tar", tar)


def build_deck_fittings(mb):
    dark = UB("dark", 2.0)
    grain = UB("grain", 2.0)
    s_mid = s_of_zn(-2.0)
    # hatches with gratings
    for zc, hx, hz in ((-4.6, 0.65, 0.65), (-0.6, 0.75, 0.9)):
        s = s_of_zn(zc)
        y = deck_surface_y(s, 0.0)
        mb.box(V(0, y + 0.13, zc), V(hx, 0, 0), V(0, 0.15, 0), V(0, 0, hz), "Wood", dark)
        for k in range(-3, 4):
            mb.box(V(0, y + 0.29, zc + k * hz / 3.6), V(hx - 0.04, 0, 0), V(0, 0.02, 0), V(0, 0, 0.035), "Wood", grain)
        for k in (-1, 0, 1):
            mb.box(V(k * hx * 0.6, y + 0.30, zc), V(0.03, 0, 0), V(0, 0.02, 0), V(0, 0, hz - 0.04), "Wood", grain)
    # main fife rail
    s = s_of_zn(Z_MAIN)
    y = deck_surface_y(s, 0.0)
    for x in (-0.75, 0.75):
        for z in (Z_MAIN - 0.65, Z_MAIN + 0.65):
            mb.box(V(x, y + 0.45, z), V(0.06, 0, 0), V(0, 0.45, 0), V(0, 0, 0.06), "Wood", dark)
        mb.box(V(x, y + 0.88, Z_MAIN), V(0.07, 0, 0), V(0, 0.05, 0), V(0, 0, 0.75), "Wood", dark)
    mb.box(V(0, y + 0.88, Z_MAIN - 0.65), V(0.82, 0, 0), V(0, 0.05, 0), V(0, 0, 0.07), "Wood", dark)
    # windlass on the forecastle
    s = s_of_zn(-10.3)
    y = deck_surface_y(s, 0.0, FC_UP)
    lathe(mb, V(-1.55, y + 0.38, -10.3), V(1, 0, 0), [(0, 0.22), (0.15, 0.26), (2.95, 0.26), (3.1, 0.22)], "Wood",
          grain, sides=8)
    for x in (-1.2, 0.0, 1.2):
        mb.box(V(x, y + 0.38, -10.3), V(0.12, 0, 0), V(0, 0.42, 0), V(0, 0, 0.22), "Wood", dark)
    # skylight on the quarterdeck
    s = s_of_zn(6.4)
    y = deck_surface_y(s, 0.0, QD_UP)
    mb.box(V(0, y + 0.22, 6.4), V(0.6, 0, 0), V(0, 0.22, 0), V(0, 0, 0.7), "Wood", dark, skip=("+y",))
    w = UC("window")
    for sx in (1, -1):
        quad = [V(0, y + 0.62, 5.72), V(0, y + 0.62, 7.08), V(sx * 0.6, y + 0.44, 7.08), V(sx * 0.6, y + 0.44, 5.72)]
        mb.poly(quad, [w(0, 0), w(1, 0), w(1, 1), w(0, 1)], "Wood", False, V(sx * 0.4, 1, 0))
    for zz in (5.7, 7.1):
        tri = [V(0.6, y + 0.44, zz), V(-0.6, y + 0.44, zz), V(0, y + 0.62, zz)]
        mb.poly(tri, [dark(0, 0), dark(1, 0), dark(0.5, 1)], "Wood", False, V(0, 0, zz - 6.4))
    lathe(mb, V(0, y + 0.62, 5.7), V(0, 0, 1), [(0, 0.04), (1.4, 0.04)], "Brass", UC("brass", 1.4), sides=6)
    return s_mid


def build_wheel(mb):
    zw = WHEEL_Z
    s = s_of_zn(zw)
    y0 = deck_surface_y(s, 0.0, QD_UP)
    dark = UB("dark", 2.0)
    grain = UB("grain", 2.0)
    hub = V(0, y0 + 1.05, zw)
    # barrel and its two stands
    lathe(mb, hub + V(0, -0.05, -0.85), V(0, 0, 1), [(0, 0.20), (0.75, 0.20)], "Wood", grain, sides=10)
    for dz in (-0.9, -0.08):
        mb.box(V(0, y0 + 0.52, zw + dz), V(0.12, 0, 0), V(0, 0.52, 0), V(0, 0, 0.07), "Wood", dark)
        mb.box(V(0, y0 + 0.06, zw + dz), V(0.32, 0, 0), V(0, 0.06, 0), V(0, 0, 0.18), "Wood", dark)
    # the wheel
    lathe(mb, hub + V(0, 0, -0.06), V(0, 0, 1), [(0, 0.13), (0.24, 0.13)], "Brass", UC("brass", 0.3), sides=10)
    R = 0.72
    torus(mb, hub + V(0, 0, 0.08), V(0, 0, 1), R, 0.045, "Wood", grain, seg=28, sides=6)
    torus(mb, hub + V(0, 0, 0.08), V(0, 0, 1), R - 0.07, 0.02, "Brass", UC("brass", 3.0), seg=24, sides=4)
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        d = V(math.cos(a), math.sin(a), 0)
        lathe(mb, hub + V(0, 0, 0.08) + d * 0.1, d, [(0, 0.035), (R - 0.1, 0.03), (R + 0.04, 0.03), (R + 0.06, 0.045),
                                                     (R + 0.2, 0.04), (R + 0.24, 0.0)], "Wood", grain, sides=6,
              perp=V(0, 0, 1))
    return V(0, y0, zw + 0.6)


def build_stern(mb, lod):
    S1 = sheer(1.0)
    y_t = S1 + E_QD
    xr_t, _, zr_t = transom_xyz(("r", 1.0))
    w = UC("window")
    g = UC("gilt")
    dark = UB("dark", 2.0)
    yc = YK + H_C * (S1 - YK)                  # top of the counter: the gallery floor
    # stern windows
    yw0, yw1 = yc + 0.17, yc + 0.94
    for xc in (-1.86, -0.93, 0.0, 0.93, 1.86):
        hw = 0.28 if lod == 0 else 0.33
        cs = [transom_point(x, y) for x, y in ((xc - hw, yw0), (xc + hw, yw0), (xc + hw, yw1), (xc - hw, yw1))]
        mb.poly([p + V(0, 0, 0.035) for p in cs], [w(0, 0), w(1, 0), w(1, 1), w(0, 1)], "Wood", False, V(0, 0, 1))
        if lod:
            continue
        fw = 0.07
        for a0, a1, b0, b1 in ((xc - hw - fw, xc + hw + fw, yw1, yw1 + fw + 0.04), (xc - hw - fw, xc + hw + fw, yw0 - fw, yw0),
                               (xc - hw - fw, xc - hw, yw0, yw1), (xc + hw, xc + hw + fw, yw0, yw1)):
            p = transom_point(0.5 * (a0 + a1), 0.5 * (b0 + b1))
            mb.box(p + V(0, 0, 0.05), V(0.5 * (a1 - a0), 0, 0), V(0, 0.5 * (b1 - b0), 0), V(0, 0, 0.05), "Paint", g,
                   skip=("-z",))
    if lod:
        mb.box(V(0, y_t + 0.9, zr_t + 0.6), V(0.25, 0, 0), V(0, 0.35, 0), V(0, 0, 0.25), "Wood", UC("glass"))
        return
    # open stern gallery under the windows
    yp = yc - 0.04
    xs = np.linspace(-2.25, 2.25, 13)
    inner = [transom_point(x, yc + 0.04) for x in xs]
    outer = [p + V(0, 0, 0.62) for p in inner]
    for yy, o in ((yp, V(0, 1, 0)), (yp - 0.1, V(0, -1, 0))):
        cols = [[V(a.x, yy, a.z - 0.05), V(b.x, yy, b.z)] for a, b in zip(inner, outer)]
        mb.grid(cols, lambda i, j, i0, j0, cols=cols: dark(cols[i][j].x, j * 1.0), lambda i, j: "Wood", smooth=False,
                out=lambda i, j, pts, o=o: o)
    cols = [[V(b.x, yp - 0.1, b.z), V(b.x, yp, b.z)] for b in outer]
    mb.grid(cols, lambda i, j, i0, j0: dark(cols[i][j].x, j * 1.0), lambda i, j: "Wood", smooth=False,
            out=lambda i, j, pts: V(0, 0, 1))
    for k, b in enumerate(outer):
        if k in (0, len(outer) - 1):
            continue
        mb.box(V(b.x, yp + 0.34, b.z - 0.05), V(0.035, 0, 0), V(0, 0.34, 0), V(0, 0, 0.035), "Wood", UB("grain", 2.0))
    rail = [V(b.x, yp + 0.71, b.z - 0.05) for b in outer]
    rail = [transom_point(-2.25, yp + 0.71) + V(0, 0, 0.05)] + rail + [transom_point(2.25, yp + 0.71) + V(0, 0, 0.05)]
    mb.tube(rail, 0.045, "Wood", dark, sides=6, cap0=True, cap1=True)
    for sx in (-1, 1):
        a = V(sx * 2.25, yp, transom_point(sx * 2.25, yp).z + 0.6)
        mb.box(V(a.x, yp + 0.36, a.z - 0.3), V(0.04, 0, 0), V(0, 0.36, 0), V(0, 0, 0.3), "Wood", dark)
    for x in (-1.6, 0.0, 1.6):
        p = transom_point(x, yp - 0.1)
        tri = [p + V(0, -0.02, 0), p + V(0, -0.02, 0.55), p + V(0, -0.55, 0)]
        for sx in (-1, 1):
            mb.poly([q + V(sx * 0.05, 0, 0) for q in tri], [dark(0, 0), dark(0.5, 0), dark(0, 1)], "Wood", False,
                    V(sx, 0, 0))
        mb.poly([tri[1] + V(0.05, 0, 0), tri[1] + V(-0.05, 0, 0), tri[2] + V(-0.05, 0, 0), tri[2] + V(0.05, 0, 0)],
                [dark(0, 0), dark(1, 0), dark(1, 1), dark(0, 1)], "Wood", False, V(0, -1, 1))
    # carved taffrail: an arched gilt board on the top of the transom, a brass moulding
    qs = np.linspace(-1, 1, 17)
    base, topl = [], []
    for q in qs:
        x = q * (xr_t - 0.02)
        zc = zr_t + TRANSOM_BULGE * xr_t * (1 - q * q) - 0.07
        base.append(V(x, y_t - 0.04, zc))
        topl.append(V(x, y_t + 0.20 + 0.36 * (1 - q * q) ** 1.3, zc))
    for dz, o, mat, uvm in ((0.075, V(0, 0, 1), "Paint", None), (-0.075, V(0, 0, -1), "Paint", None)):
        cols = [[a + V(0, 0, dz), b + V(0, 0, dz)] for a, b in zip(base, topl)]
        if dz > 0:
            uvf = (lambda i, j, i0, j0, cols=cols: (lerp(g.u0, g.u1, i / (len(cols) - 1)), g.v1 if j else g.v0))
        else:
            uvf = (lambda i, j, i0, j0, cols=cols: UB("paint2", 3.0)(cols[i][j].x, j * 1.0))
        mb.grid(cols, uvf, lambda i, j: mat, smooth=False, out=lambda i, j, pts, o=o: o)
    cols = [[b + V(0, 0, 0.075), b + V(0, 0, -0.075)] for b in topl]
    mb.grid(cols, lambda i, j, i0, j0: dark(cols[i][j].x, j * 1.0), lambda i, j: "Wood", smooth=False,
            out=lambda i, j, pts: V(0, 1, 0))
    mb.tube([b + V(0, 0.03, 0) for b in topl], 0.045, "Brass", UC("brass", 6.0),
            sides=6, cap0=True, cap1=True)
    for sx in (-1, 1):
        p = topl[0 if sx < 0 else -1]
        lathe(mb, p + V(0, 0.02, 0), V(0, 1, 0), [(0, 0.0), (0.02, 0.09), (0.12, 0.11), (0.22, 0.06), (0.3, 0.09),
                                                  (0.38, 0.0)], "Paint", UC("gilt", 0.4), sides=8)
    # lanterns: the great poop lantern in its armillary rings, two quarter lanterns
    zt = zr_t + TRANSOM_BULGE * xr_t - 0.07
    top_c = V(0, y_t + 0.56, zt)
    mb.tube(catmull([(0, y_t + 0.45, zt - 0.02), (0, y_t + 0.72, zt + 0.12), (0, y_t + 0.86, zt + 0.48),
                     (0, y_t + 0.80, zt + 0.66)], 4), 0.045, "Tar", UB("tar", 2.0, (0, 4)), sides=6, cap0=True, cap1=True)
    lc = V(0, y_t + 1.18, zt + 0.66)
    lantern(mb, lc, 1.0)
    brass = UC("brass", 4.0)
    torus(mb, lc, V(0.0, math.cos(math.radians(23)), math.sin(math.radians(23))), 0.66, 0.026, "Brass", brass, 28, 6)
    torus(mb, lc, V(math.cos(math.radians(40)), 0, math.sin(math.radians(40))), 0.62, 0.024, "Brass", brass, 28, 6)
    torus(mb, lc, V(math.cos(math.radians(-40)), 0, math.sin(math.radians(-40))), 0.62, 0.024, "Brass", brass, 28, 6)
    lathe(mb, lc + V(0, -0.78, 0), V(0, 1, 0), [(0, 0.03), (1.56, 0.03)], "Brass", brass, sides=6)
    for sx in (-1, 1):
        p = V(sx * (xr_t - 0.05), y_t + 0.2, zr_t - 0.05)
        mb.tube([p, p + V(0, 0.32, 0.12)], 0.035, "Tar", UB("tar", 2.0, (0, 4)), sides=6, cap0=True, cap1=True)
        lantern(mb, p + V(0, 0.62, 0.16), 0.55)
    # quarter galleries (kept outside the bulwark: nothing shows through the quarterdeck)
    for sx in (-1, 1):
        zc, y0, y1 = 10.75, yc - 0.03, yc + 0.90
        ym = 0.5 * (y0 + y1)
        s = s_at(zc, ("d", S1 - ym))
        hx = hp(s, ("d", sheer(s) - ym)).x
        c = V(sx * (hx + 0.17), ym, zc)
        mb.box(c, V(0.23, 0, 0), V(0, 0.5 * (y1 - y0), 0), V(0, 0, 0.78), "Paint", UB("paint2", 2.0))
        for zz in (10.4, 11.1):
            q = V(c.x + sx * 0.235, ym, zz)
            quad = [q + V(0, -0.28, -0.22), q + V(0, -0.28, 0.22), q + V(0, 0.28, 0.22), q + V(0, 0.28, -0.22)]
            mb.poly(quad, [w(0, 0), w(1, 0), w(1, 1), w(0, 1)], "Wood", False, V(sx, 0, 0))
            mb.box(q + V(0, 0.33, 0), V(0.02, 0, 0), V(0, 0.04, 0), V(0, 0, 0.27), "Paint", g)
        mb.box(c + V(sx * 0.02, 0.5 * (y1 - y0) + 0.05, 0), V(0.27, 0, 0), V(0, 0.05, 0), V(0, 0, 0.86), "Wood", dark)
        lathe(mb, c + V(sx * 0.05, -0.5 * (y1 - y0), 0), V(0, -1, 0),
              [(0, 0.24), (0.22, 0.18), (0.5, 0.07), (0.65, 0.0)], "Paint", UC("gilt", 0.7), sides=8)


def lantern(mb, c, k):
    brass = UC("brass", 1.0)
    glass = UC("glass", 1.0)
    prof_lo = [(-0.42, 0.0), (-0.40, 0.12), (-0.33, 0.27), (-0.27, 0.29)]
    prof_g = [(-0.27, 0.28), (0.20, 0.31)]
    prof_hi = [(0.20, 0.33), (0.25, 0.33), (0.40, 0.20), (0.50, 0.08), (0.56, 0.05), (0.66, 0.0)]
    for prof, mat, uvm in ((prof_lo, "Brass", brass), (prof_g, "Wood", glass), (prof_hi, "Brass", brass)):
        lathe(mb, c, V(0, 1, 0), [(t * k, r * k) for t, r in prof], mat, uvm, sides=6, perp=V(1, 0, 0),
              cap0=(mat == "Wood"), cap1=(mat == "Wood"), smooth=(mat != "Wood"))


CRYSTAL_C = V(0, -1.45, -0.4)       # centre of the keel crystal (the KeelGlow empty)
CRYSTAL_TIP, CRYSTAL_PRISM, CRYSTAL_R = 2.28, 0.80, 0.94   # half lengths along z, hexagon corner radius
CRYSTAL_COLLAR = 1.72                # collars round the two pyramids, from the centre
# preview stand-in for a keel light: offset from KeelGlow, watts. It sits in the gap between the crystal and the
# keel, lighting the bottom and the crystal's upper facets; a light at the crystal's centre lights every facet
# from inside and blows the crystal out to a white bulb
POD_LIGHT = (V(0, 1.2, 0), 1500.0)


def crystal_r(t):
    """Corner radius of the hexagonal bipyramid at distance t from its centre along z."""
    t = abs(t)
    if t <= CRYSTAL_PRISM:
        return CRYSTAL_R
    return CRYSTAL_R * max(CRYSTAL_TIP - t, 0.0) / (CRYSTAL_TIP - CRYSTAL_PRISM)


def build_keel_crystal(mb, lod):
    """A hard-faceted hexagonal bipyramid with a prism waist, slung under the keel in a brass cradle:
    hexagonal bands round the prism, straps along four of its edges, a collar round each pyramid and two
    raked pylons from a brass shoe on the keel down to the collars."""
    c = CRYSTAL_C
    prof = [(-CRYSTAL_TIP, 0.0), (-CRYSTAL_PRISM, CRYSTAL_R), (CRYSTAL_PRISM, CRYSTAL_R), (CRYSTAL_TIP, 0.0)]
    lathe(mb, c, V(0, 0, 1), prof, "EtheriumGlow", UC("crystal", 2 * CRYSTAL_TIP), sides=6, perp=V(0, 1, 0),
          smooth=False, cap0=False, cap1=False)
    brass = UC("brass", 3.0)
    rc = crystal_r(CRYSTAL_COLLAR) + 0.07
    pyl = [(V(0, 0.02, c.z + sz * 1.22), V(0, c.y + rc + 0.02, c.z + sz * CRYSTAL_COLLAR)) for sz in (-1, 1)]
    if lod:
        for a, b in pyl:
            mb.beam(a, b, 0.16, 0.30, V(1, 0, 0), "Brass", UC("brass"))
        return c
    # corners of the hexagon: j = 0 on top (the lathe's first ring vertex), j = 3 underneath
    corner = [V(0, 1, 0) * math.cos(2 * math.pi * j / 6) + V(-1, 0, 0) * math.sin(2 * math.pi * j / 6)
              for j in range(6)]
    for t in (-CRYSTAL_PRISM, 0.0, CRYSTAL_PRISM):
        R = CRYSTAL_R + 0.05
        ring = []
        for j in range(6):
            p, q = corner[j] * R, corner[(j + 1) % 6] * R
            ring += [lerp(p, q, 0.10), lerp(p, q, 0.90)]       # chamfered corners keep the band from pinching
        mb.tube([c + V(0, 0, t) + p for p in ring], 0.06, "Brass", brass, sides=6, closed=True)
    for j in (1, 2, 4, 5):
        path = [c + V(0, 0, t) + corner[j] * (crystal_r(t) + 0.05)
                for t in (-CRYSTAL_COLLAR, -CRYSTAL_PRISM, 0.0, CRYSTAL_PRISM, CRYSTAL_COLLAR)]
        mb.tube(path, 0.04, "Brass", brass, sides=5, cap0=True, cap1=True)
    for sz in (-1, 1):
        t0, t1 = sz * (CRYSTAL_COLLAR - 0.16), sz * (CRYSTAL_COLLAR + 0.16)
        r0, r1 = crystal_r(t0) + 0.06, crystal_r(t1) + 0.06
        lathe(mb, c + V(0, 0, t0), V(0, 0, sz), [(0, r0 - 0.03), (0.03, r0 + 0.02), (0.29, r1 + 0.02), (0.32, r1 - 0.03)],
              "Brass", brass, sides=10, perp=V(0, 1, 0), cap0=False, cap1=False)
    for (a, b) in pyl:
        mb.tube([a, lerp(a, b, 0.5), b], [0.13, 0.10, 0.09], "Brass", brass, sides=8, cap0=True, cap1=True)
        mb.box(a + V(0, 0.0, 0), V(0.20, 0, 0), V(0, 0.05, 0), V(0, 0, 0.26), "Brass", brass)
    mb.box(V(0, 0.015, c.z), V(0.20, 0, 0), V(0, 0.03, 0), V(0, 0, 1.55), "Brass", brass)
    return c


def build_hull(name, lod):
    mb = MB(name)
    st = build_hull_shell(mb, lod)
    build_bulwarks(mb, st, lod)
    build_decks(mb, st, lod)
    build_keel_stem(mb, lod)
    build_gunports(mb, lod)
    build_stern(mb, lod)
    crystal = build_keel_crystal(mb, lod)
    info = {"crystal": crystal}
    if lod == 0:
        build_wale(mb, st)
        build_head(mb)
        build_channels(mb)
        build_deck_fittings(mb)
        info["helm"] = build_wheel(mb)
    return mb, info


# --------------------------------------------------------------------------
# Masts, spars and rigging
# --------------------------------------------------------------------------
class Mast:
    def __init__(self, z_foot, rake):
        self.z0, self.k = z_foot, math.tan(rake)

    def at(self, y, dz=0.0):
        return V(0.0, y, self.z0 + (y - Y_STEP) * self.k + dz)


FORE, MAIN = Mast(Z_FORE, RAKE_FORE), Mast(Z_MAIN, RAKE_MAIN)
# per mast: lower (y0, y_top, y_cap), topmast (dz, y0, y1, r0, r1), topgallant (dz, y0, y1) or None
SPEC = {
    "fore": dict(m=FORE, r=(0.27, 0.21), top=14.4, cap=15.95, tm=(-0.46, 13.7, 23.9, 0.18, 0.12),
                 xt=22.4, tg=(-0.76, 22.6, 28.5, 0.11, 0.05), top_w=1.45),
    "main": dict(m=MAIN, r=(0.29, 0.23), top=15.6, cap=17.05, tm=(-0.48, 16.0, 30.0, 0.18, 0.08),
                 xt=27.6, tg=None, top_w=1.55),
}
YARDS = {  # fore yards: y, dz from the mast it hangs on (lower/topmast/topgallant), half length, radius
    "course": (13.0, ("low", -0.55), 7.2, 0.19),
    "topsail": (21.0, ("tm", -0.36), 5.4, 0.15),
    "topgallant": (26.1, ("tg", -0.24), 3.6, 0.10),
}
# Under sail on the starboard tack: the fore yards braced round about the mast (port yardarms aft), the
# boom and gaff swung out to leeward (port) and the headsail clews sheeted to port.
BRACE = math.radians(20.0)
SWING = math.radians(11.0)
HEAD_SWING = math.radians(12.0)
E_YARD = V(math.cos(BRACE), 0.0, -math.sin(BRACE))      # along a fore yard, port -> starboard
E_FWD = V(-math.sin(BRACE), 0.0, -math.cos(BRACE))      # forward face of the square sails
E_BOOM = V(-math.sin(SWING), 0.0, math.cos(SWING))      # aft along the boom and gaff, out to port


def braced(v):
    """A vector given in the unbraced yard frame (x along the yard, z aft) in the braced frame."""
    return E_YARD * v.x + V(0, v.y, 0) - E_FWD * v.z


def swung(v):
    """A vector given in the unswung boom frame (z aft along the centre line) swung out to port."""
    return E_BOOM * v.z + V(0, v.y, 0) + V(math.cos(SWING), 0, math.sin(SWING)) * v.x


def yard_centre(name):
    """Centre of a fore yard (it hangs dz forward of its mast, and turns with it), half length, radius."""
    y, (which, dz), L, r = YARDS[name]
    sp = SPEC["fore"]
    off = {"low": 0.0, "tm": sp["tm"][0], "tg": sp["tg"][0]}[which]
    return FORE.at(y, off) + braced(V(0, 0, dz)), L, r


def bowsprit_geo():
    d = V(0, math.sin(STEEVE), -math.cos(STEEVE))
    bs = BOWSPRIT
    head = V(0, bs["head_y"], Z_BOW_TOP - 0.05)
    cap = head + d * bs["out"]
    heel = head - d * bs["heel"]
    perp = V(0, math.cos(STEEVE), math.sin(STEEVE))
    st = math.radians(bs["jb_steeve"])
    d2 = V(0, math.sin(st), -math.cos(st))
    jb0 = cap - d * bs["jb_back"] + perp * 0.36
    jb1 = jb0 + d2 * bs["jb_len"]
    return dict(d=d, head=head, cap=cap, heel=heel, perp=perp, jb0=jb0, jb1=jb1)


def gaff_geo():
    """Gaff jaw and peak, boom gooseneck and end, swung out to port about the main mast."""
    jaw = MAIN.at(14.3) + swung(V(0, 0, 0.34))
    a = math.radians(36.0)
    peak = jaw + swung(V(0, math.sin(a), math.cos(a))) * 8.0
    m0 = MAIN.at(6.9)
    goose = m0 + swung(V(0, 0, 0.34))
    z_end = 11.6
    y_end = sheer(s_of_zn(z_end)) + E_QD + 1.47           # well clear of the quarterdeck rail and the helm
    bend = m0 + swung(V(0, y_end - m0.y, z_end - m0.z))
    return jaw, peak, goose, bend


def gaff_topsail_geo():
    """Tack (just above the top, aft of the mast), head (main topmast head) and clew (gaff peak)."""
    sp = SPEC["main"]
    _, peak, _, _ = gaff_geo()
    tack = MAIN.at(sp["top"] + 0.45) + swung(V(0, 0, 0.98))
    head = MAIN.at(sp["xt"] + 0.6, sp["tm"][0]) + swung(V(0, 0, 0.22))
    clew = peak + swung(V(0, 0.12, -0.25))
    return tack, head, clew


def build_mast(mb, key, sp, lod, pts, sides, grain, tar, dark):
    """One mast from its SPEC entry: lower mast, mast head, topmast, topgallant (if any), truck, top, cap and
    crosstrees; its points go into pts under key."""
    m = sp["m"]
    r0, r1 = sp["r"]
    yt, yc = sp["top"], sp["cap"]
    mb.tube([m.at(Y_STEP), m.at(yt * 0.5 + 2), m.at(yt)], [r0, lerp(r0, r1, 0.6), r1], "Wood", grain, sides=sides)
    mb.tube([m.at(yt), m.at(yc + 0.1)], [r1, r1 * 0.92], "Tar", tar, sides=sides, cap1=True)
    dz, y0, y1, ra, rb = sp["tm"]
    mb.tube([m.at(y0, dz), m.at(sp["xt"], dz), m.at(y1, dz)], [ra, lerp(ra, rb, 0.8), rb], "Wood", grain,
            sides=max(sides - 2, 5), cap0=True, cap1=sp["tg"] is not None)
    pts[key + "_tm_head"] = m.at(sp["xt"] + 0.9, dz)
    pts[key + "_mh"] = m.at(yt - 0.3)
    pts[key + "_top"] = m.at(yt)
    if sp["tg"]:
        dz2, y2, y3, rc, rd = sp["tg"]
        mb.tube([m.at(y2, dz2), m.at(y3, dz2)], [rc, rd], "Wood", grain, sides=max(sides - 4, 5), cap0=True)
        truck = m.at(y3, dz2)
        pts[key + "_tg_head"] = m.at(y3 - 0.9, dz2)
    else:
        truck = m.at(y1, dz)
    pts[key + "_truck"] = truck
    lathe(mb, truck, V(0, 1, 0), [(0, 0.0), (0.0, 0.16), (0.12, 0.16), (0.12, 0.0)], "Wood", dark,
          sides=8 if lod == 0 else 5)
    # top platform: rounded fore part, straight aft edge
    c = m.at(yt, 0.15)
    hw = sp["top_w"]
    outline = []
    for k in range(13 if lod == 0 else 6):
        a = math.pi * k / (12 if lod == 0 else 5)
        outline.append(c + V(hw * math.cos(a), 0, -1.15 * math.sin(a)))
    outline = outline + [c + V(-hw, 0, 0.7), c + V(hw, 0, 0.7)]
    top_pts = [p + V(0, 0.14, 0) for p in outline]
    uv = [dark(p.x + 2, (p.z - c.z + 1.2) / 2) for p in outline]
    mb.poly(top_pts, uv, "Wood", False, V(0, 1, 0))
    mb.poly(outline, uv, "Wood", False, V(0, -1, 0))
    n = len(outline)
    for k in range(n):
        a, b = outline[k], outline[(k + 1) % n]
        mb.poly([a, b, b + V(0, 0.14, 0), a + V(0, 0.14, 0)], [dark(0, 0), dark(1, 0), dark(1, 1), dark(0, 1)],
                "Wood", False, (a + b) * 0.5 - c)
    pts[key + "_top_aft"] = c + V(0, 0.14, 0.7)
    # cap and crosstrees
    mb.box(m.at(yc, 0.5 * dz), V(0.32, 0, 0), V(0, 0.16, 0), V(0, 0, 0.62), "Tar", tar)
    xt_w = sp.get("xt_w", 1.15 if key == "fore" else 0.9)
    mb.box(m.at(sp["xt"], dz), V(xt_w, 0, 0), V(0, 0.07, 0), V(0, 0, 0.09), "Wood", dark)
    if lod == 0:
        for x in (-hw + 0.15, 0.0, hw - 0.15):
            mb.box(c + V(x, 0.55, 0.62), V(0.03, 0, 0), V(0, 0.42, 0), V(0, 0, 0.03), "Wood", dark)
        mb.box(c + V(0, 0.98, 0.62), V(hw - 0.1, 0, 0), V(0, 0.035, 0), V(0, 0, 0.04), "Wood", dark)


def build_rig(name, lod, mb=None):
    mb = mb or MB(name)
    grain = UB("grain", 4.0)
    tar = UB("tar", 3.0, (0, 4))
    dark = UB("dark", 2.0)
    sides = 12 if lod == 0 else 5
    pts = {}
    for key, sp in SPEC.items():
        build_mast(mb, key, sp, lod, pts, sides, grain, tar, dark)
    # fore yards
    ysides = 10 if lod == 0 else 4
    for nm in YARDS:
        c, L, r = yard_centre(nm)
        xs = [-L - 0.3, -L, -0.6 * L, 0.0, 0.6 * L, L, L + 0.3]
        rs = [r * 0.35, r * 0.45, r * 0.8, r, r * 0.8, r * 0.45, r * 0.35]
        mb.tube([c + E_YARD * x for x in xs], rs, "Wood", grain, sides=ysides, cap0=True, cap1=True)
        pts["yard_" + nm] = (c, L, r)
        if lod == 0:
            mb.box(c - E_FWD * 0.25, E_YARD * 0.25, V(0, 0.12, 0), E_FWD * 0.18, "Tar", tar)   # parrel/sling
    # gaff and boom
    jaw, peak, goose, bend = gaff_geo()
    mb.tube([jaw, peak], [0.15, 0.09], "Wood", grain, sides=ysides, cap0=True, cap1=True)
    mb.tube([goose, lerp(goose, bend, 0.6), bend], [0.17, 0.19, 0.13], "Wood", grain, sides=ysides, cap0=True, cap1=True)
    if lod == 0:
        # jaws of the gaff and boom round the mast
        for p, q, y in ((jaw, peak, 14.3), (goose, bend, 6.9)):
            d = (q - p).normalized()
            for sx in (-1, 1):
                a = MAIN.at(y) + swung(V(sx * 0.27, 0, -0.05))
                mb.beam(a, a + d * 0.5, 0.07, 0.22, V(0, 1, 0), "Wood", dark)
    # bowsprit, jib-boom, cap, dolphin striker
    bg = bowsprit_geo()
    mb.tube([bg["heel"], bg["head"], bg["cap"]], [0.31, 0.29, 0.19], "Wood", grain, sides=sides, cap0=True, cap1=True)
    mb.tube([bg["jb0"], bg["jb1"]], [0.14, 0.07], "Wood", grain, sides=max(sides - 4, 5), cap0=True, cap1=True)
    mb.beam(bg["cap"] + bg["perp"] * 0.18 + bg["d"] * 0.1, bg["cap"] + bg["perp"] * 0.18 - bg["d"] * 0.15, 0.75, 0.4,
            V(1, 0, 0), "Tar", tar)
    striker0 = bg["cap"] - bg["perp"] * 0.15
    striker1 = bg["cap"] - bg["perp"] * 1.6 + bg["d"] * 0.15
    mb.tube([striker0, striker1], 0.06, "Wood", dark, sides=5, cap1=True)
    pts["striker"] = striker1
    rig_lines(mb, pts, bg, lod)
    return mb, pts


def rig_lines(mb, pts, bg, lod):
    R_STAY, R_SHROUD, R_RUN = (0.05, 0.035, 0.022) if lod == 0 else (0.09, 0.07, 0.05)
    sides = 5 if lod == 0 else 3
    T = "Tar"
    L = lambda a, b, r=R_STAY, m=T: mb.line(a, b, r, m, sides=sides)   # noqa: E731
    fore_mh, main_mh = pts["fore_mh"], pts["main_mh"]
    # stays
    L(fore_mh + V(0, 0, -0.3), bg["head"] + bg["d"] * 1.55)
    L(pts["fore_tm_head"], bg["cap"] + bg["perp"] * 0.2)
    L(pts["fore_tg_head"], bg["jb1"] - bg["d"] * 0.2)
    L(main_mh + V(0, 0, -0.3), FORE.at(5.75, 0.3))
    L(pts["main_tm_head"], FORE.at(SPEC["fore"]["cap"] - 0.2, 0.25))
    if lod:
        return
    L(bg["cap"] - bg["perp"] * 0.1, V(0, 3.1, -13.45))                    # bobstay
    L(bg["jb1"] - bg["d"] * 0.2, pts["striker"], R_SHROUD)                # martingale
    L(pts["striker"], V(0, 4.4, -13.75), R_SHROUD)
    # shrouds with deadeyes, lanyards, ratlines; topmast shrouds and backstays
    dark = UB("dark", 1.0)
    for key, (z0, z1, dzs) in CHANNELS.items():
        sp = SPEC[key]
        m = sp["m"]
        for side in (1, -1):
            uppers = []
            for z in dzs:
                _, p, n = channel_point(z, side)
                lo_c = p + n * 0.52 + V(0, 0.08, 0)
                head = m.at(sp["top"] - 0.35) + V(side * 0.24, 0, 0)
                d = (head - lo_c).normalized()
                up_c = lo_c + d * 0.62
                for cc in (lo_c, up_c):
                    lathe(mb, cc - n * 0.05, n, [(0, 0.0), (0.0, 0.13), (0.1, 0.13), (0.1, 0.0)], "Wood", dark,
                          sides=8, perp=d)
                mb.line(lo_c + d * 0.1, up_c - d * 0.1, 0.018, "Wood", sides=4)
                L(up_c + d * 0.1, head, R_SHROUD)
                uppers.append((up_c + d * 0.1, head))
            # ratlines
            ya, yb = uppers[0][0].y + 0.45, uppers[0][1].y - 1.6
            y = ya
            while y < yb:
                ends = []
                for a, b in (uppers[0], uppers[-1]):
                    t = (y - a.y) / (b.y - a.y)
                    ends.append(lerp(a, b, t))
                mb.line(ends[0], ends[1], 0.014, T, sides=3)
                y += 0.42
            # topmast shrouds from the top's edge
            dz = sp["tm"][0]
            th = pts[key + "_tm_head"] + V(side * 0.12, -0.3, 0)
            for zo in (-0.45, 0.1, 0.6):
                L(m.at(sp["top"] + 0.1, zo) + V(side * (sp["top_w"] - 0.1), 0, 0), th, R_SHROUD * 0.8)
            # topmast backstay to the aft end of the channel (the main's at the end itself, so it passes
            # forward of the fan's leading rib)
            _, p, n = channel_point(z1 + (0.25 if key == "fore" else -0.1), side)
            L(pts[key + "_tm_head"] + V(side * 0.1, 0.1, 0.1), p + n * 0.5, R_SHROUD * 0.9)
            if key == "fore":
                _, p, n = channel_point(z1 + 0.6, side)
                L(pts["fore_tg_head"] + V(side * 0.08, 0, 0.1), p + n * 0.45, R_SHROUD * 0.7)
            # futtock shrouds
            for zo in (-0.45, 0.1, 0.6):
                L(m.at(sp["top"], zo) + V(side * (sp["top_w"] - 0.1), 0, 0), m.at(sp["top"] - 2.0) + V(side * 0.3, 0, 0),
                  R_SHROUD * 0.6)
    # lifts and braces (hemp), gaff peak halyard, vangs and the main sheet
    H = "Wood"
    for nm in YARDS:
        c, Lh, r = pts["yard_" + nm]
        above = {"course": pts["fore_mh"] + V(0, 1.4, 0), "topsail": pts["fore_tm_head"],
                 "topgallant": pts["fore_tg_head"] + V(0, 0.6, 0)}[nm]
        to = {"course": MAIN.at(11.0), "topsail": MAIN.at(15.0, 0.4), "topgallant": pts["main_tm_head"]}[nm]
        for side in (1, -1):
            arm = c + E_YARD * (side * (Lh - 0.1))
            mb.line(arm, above + E_YARD * (side * 0.15), R_RUN, H, sides=4)
            mb.line(arm, to + V(side * 0.3, 0, 0), R_RUN, H, sides=4)
    jaw, peak, goose, bend = gaff_geo()
    for t in (0.45, 0.95):
        mb.line(lerp(jaw, peak, t), MAIN.at(SPEC["main"]["cap"] - 0.3, -0.1), R_RUN, H, sides=4)
    rail = ("r", 1.0)
    s_v = s_at(11.4, rail)
    p_v = hp(s_v, rail)
    for side in (1, -1):
        mb.line(peak, V(side * (p_v.x - 0.1), p_v.y + 0.05, p_v.z), R_RUN, H, sides=4)          # vangs
    s_t = s_at(11.9, rail)
    p_t = hp(s_t, rail)
    mb.line(bend, V(-(p_t.x - 0.25), p_t.y + 0.05, p_t.z), R_RUN * 1.4, H, sides=4)          # main sheet, lee quarter
    # gaff topsail tack down to the top
    tack, head, clew = gaff_topsail_geo()
    mb.line(tack, MAIN.at(SPEC["main"]["top"] + 0.14, 0.75), R_RUN, H, sides=4)


# --------------------------------------------------------------------------
# Sails
# --------------------------------------------------------------------------
_CANVAS_U0 = [0.0]


def canvas_uv(width):
    v0, v1 = BAND["canvas"]
    m = 1.5 / ATLAS
    u0 = _CANVAS_U0[0]
    _CANVAS_U0[0] = (u0 + CANVAS_SHIFT) % 1.0

    def f(u, v):
        return (u * width / CANVAS_TILE + u0, lerp(v1 - m, v0 + m, v))
    return f


def bolt_ropes(mb, P, edges, r=0.045):
    """Dark boltropes round a sail's edges (P[u][v]; edges from 'u0', 'u1', 'v0', 'v1'), so its outline
    holds against the sky."""
    nu, nv = len(P) - 1, len(P[0]) - 1
    paths = {"u0": [P[0][j] for j in range(nv + 1)], "u1": [P[nu][j] for j in range(nv + 1)],
             "v0": [P[i][0] for i in range(nu + 1)], "v1": [P[i][nv] for i in range(nu + 1)]}
    for e in edges:
        path = paths[e]
        path = path[::2] + ([path[-1]] if len(path) % 2 == 0 else [])
        mb.tube(path, r, "Canvas", UC("hemp", 1.0), sides=4, cap0=True, cap1=True)


def square_sail(mb, hl, hr, cl, cr, depth, nu, nv, roach=0.45, fwd=V(0, 0, -1), rope=False):
    width = 0.5 * ((hr - hl).length + (cr - cl).length)
    P = []
    for iu in range(nu + 1):
        u = iu / nu
        col = []
        for jv in range(nv + 1):
            v = jv / nv
            head = lerp(hl, hr, u)
            foot = lerp(cl, cr, u) + V(0, roach * 4 * u * (1 - u), 0)
            p = lerp(head, foot, v)
            p = p + fwd * (depth * math.sin(math.pi * u) ** 0.7 * math.sin(0.75 * math.pi * v))
            p.y += -0.12 * depth * math.sin(math.pi * u) * math.sin(math.pi * v)
            col.append(p)
        P.append(col)
    f = canvas_uv(width)
    mb.grid(P, lambda i, j, i0, j0: f(i / nu, j / nv), lambda i, j: "Canvas", smooth=True,
            out=lambda i, j, pts: fwd)
    if rope:
        bolt_ropes(mb, P, ("u0", "u1", "v0", "v1"))


def fore_aft_sail(mb, tack, throat, peak, clew, depth, nu, nv, side_dir, rope=False):
    width = 0.5 * ((clew - tack).length + (peak - throat).length)
    P = []
    for iu in range(nu + 1):
        u = iu / nu
        col = []
        for jv in range(nv + 1):
            v = jv / nv
            p = lerp(lerp(tack, throat, v), lerp(clew, peak, v), u)
            p = p + side_dir * (depth * math.sin(math.pi * u) ** 0.8 * math.sin(math.pi * v) ** 0.8)
            col.append(p)
        P.append(col)
    f = canvas_uv(width)
    mb.grid(P, lambda i, j, i0, j0: f(i / nu, j / nv), lambda i, j: "Canvas", smooth=True,
            out=lambda i, j, pts: side_dir)
    if rope:
        bolt_ropes(mb, P, ("u0", "u1", "v0", "v1"))


def head_sail(mb, tack, head, clew, depth, nu, nv, side_dir, rope=False):
    width = (clew - tack).length
    P = []
    for iu in range(nu + 1):
        u = iu / nu
        col = []
        for jv in range(nv + 1):
            v = jv / nv
            p = lerp(lerp(tack, head, v), lerp(clew, head, v), u)
            b = depth * math.sin(math.pi * u) ** 0.8 * math.sin(math.pi * (0.18 + 0.82 * v)) * (1 - v) ** 0.25
            col.append(p + side_dir * b)
        P.append(col)
    f = canvas_uv(width)
    mb.grid(P, lambda i, j, i0, j0: f(i / nu, j / nv * 0.85), lambda i, j: "Canvas", smooth=True,
            out=lambda i, j, pts: side_dir)
    if rope:
        bolt_ropes(mb, P, ("u0", "u1", "v0"))


def build_sails(name, lod, mb=None):
    mb = mb or MB(name)
    nu, nv = (16, 12) if lod == 0 else (4, 3)
    rope = lod == 0
    # square sails on the fore
    names = ["course", "topsail", "topgallant"]
    for k, nm in enumerate(names):
        c, L, r = yard_centre(nm)
        hl, hr = c + E_YARD * -(L - 0.25) + V(0, -r - 0.05, 0), c + E_YARD * (L - 0.25) + V(0, -r - 0.05, 0)
        if nm == "course":
            # clews hauled down outboard and a little aft of the yard, turning with it
            cl, cr = (c + braced(V(sx * 7.0, 0, 0.5)) for sx in (-1, 1))
            cl.y = cr.y = 6.55
            depth, roach = 1.35, 0.55
        else:
            lc, Ll, rl = yard_centre(names[k - 1])
            cl, cr = lc + E_YARD * -(Ll - 0.35) + V(0, r * 0.3, 0), lc + E_YARD * (Ll - 0.35) + V(0, r * 0.3, 0)
            depth, roach = (1.05, 0.25) if nm == "topsail" else (0.7, 0.18)
        square_sail(mb, hl, hr, cl, cr, depth, nu, nv, roach, fwd=E_FWD, rope=rope)
    # gaff mainsail and gaff topsail, bellied out to leeward (port)
    jaw, peak, goose, bend = gaff_geo()
    lee = swung(V(-1, 0, 0))
    fore_aft_sail(mb, goose + swung(V(0, 0.35, 0.25)), jaw + swung(V(0, -0.2, 0.25)), peak + swung(V(0, -0.15, -0.35)),
                  bend + swung(V(0, 0.18, -0.35)), 1.0, nu, nv, lee, rope)
    tack, head, clew = gaff_topsail_geo()
    head_sail(mb, tack, head, clew, 0.55, max(nu // 2, 3), nv, lee, rope)
    # headsails: tacks on the stays, clews sheeted out to port
    port = V(-1, 0, 0)
    bg = bowsprit_geo()
    fmh = FORE.at(SPEC["fore"]["top"] - 0.6, -0.3)
    stay_lo = bg["head"] + bg["d"] * 1.55
    ftm = SPEC["fore"]

    def clew_of(t, dy, dz):
        return t + V(-dz * math.sin(HEAD_SWING), dy, dz * math.cos(HEAD_SWING))
    t0, h0 = lerp(stay_lo, fmh, 0.06), lerp(stay_lo, fmh, 0.66)
    head_sail(mb, t0, h0, clew_of(t0, 0.8, 4.05), 0.5, max(nu // 2, 3), nv, port, rope)
    tm_head = FORE.at(ftm["xt"] + 0.9, ftm["tm"][0])
    cap = bg["cap"] + bg["perp"] * 0.2
    t1, h1 = lerp(cap, tm_head, 0.05), lerp(cap, tm_head, 0.70)
    head_sail(mb, t1, h1, clew_of(t1, 1.6, 5.0), 0.65, max(nu // 2, 3), nv, port, rope)
    tg_head = FORE.at(ftm["tg"][2] - 0.9, ftm["tg"][0])
    jb = bg["jb1"] - bg["d"] * 0.2
    t2, h2 = lerp(jb, tg_head, 0.06), lerp(jb, tg_head, 0.62)
    head_sail(mb, t2, h2, clew_of(t2, 4.3, 7.2), 0.6, max(nu // 2, 3), nv, port, rope)
    return mb


# --------------------------------------------------------------------------
# The wonder: etherium fans and keel-wings
# --------------------------------------------------------------------------
FAN_DIHEDRAL = math.radians(22.0)     # the fan plane rises outboard at this angle
FAN_LIFT = math.radians(15.0)         # ... and rises aft at this one
FAN_CUP = math.radians(14.0)          # the middle ribs rise out of the plane: a cupped fan, never a stick edge-on
FANS = {
    # hub (starboard, at the aft corner of the top), leading (longest) rib, rib count, rib angles (deg, 0 =
    # abeam, + aft): an asymmetric bird's wing, the leading rib outboard and longest, the ribs tapering aft
    "fore": (V(1.3, 14.85, FORE.at(14.85).z + 1.05), 5.8, 6, (20.0, 80.0)),
    "main": (V(1.4, 16.05, MAIN.at(16.05).z + 1.05), 6.8, 7, (10.0, 82.0)),
}


def fan_frame(side):
    """Outboard and aft axes of a fan's plane, and its downward normal."""
    e_out = V(side * math.cos(FAN_DIHEDRAL), math.sin(FAN_DIHEDRAL), 0)
    e_aft = V(0, math.sin(FAN_LIFT), math.cos(FAN_LIFT))
    n_dn = e_out.cross(e_aft).normalized()
    if n_dn.y > 0:
        n_dn = -n_dn
    return e_out, e_aft, n_dn


def fan_ribs(key, side, lod=0):
    """[(direction, length)] of a fan's ribs: a backswept spread in the canted plane, the leading rib
    longest and the rest tapering aft, like the primaries of a bird's wing."""
    hub0, L, n, phis = FANS[key]
    if lod:
        n = 5
    e_out, e_aft, n_dn = fan_frame(side)
    ribs = []
    for k in range(n):
        f = k / (n - 1)
        phi = math.radians(lerp(phis[0], phis[1], f))
        d = (e_out * math.cos(phi) + e_aft * math.sin(phi)).normalized()
        d = (d - n_dn * math.tan(FAN_CUP * math.sin(math.pi * f))).normalized()
        ribs.append((d, L * (1.0 - 0.5 * f ** 1.2)))
    return ribs


def fan_hub(key, side):
    hub0 = FANS[key][0]
    return V(side * hub0.x, hub0.y, hub0.z)


def build_fan(mb, key, side, lod):
    hub = fan_hub(key, side)
    L = FANS[key][1]
    ribs = fan_ribs(key, side, lod)
    n = len(ribs)
    _, _, n_dn = fan_frame(side)
    up = -n_dn
    r_in = 0.45
    sides = 6 if lod == 0 else 3
    for k, (d, length) in enumerate(ribs):
        guard = k in (0, n - 1)                 # the two outer sticks are heavier, as on a folding fan
        r0 = 0.13 if guard else 0.10
        a, b = hub + d * 0.2, hub + d * length
        mb.tube([a, lerp(a, b, 0.5), b], [r0, r0 * 0.7, r0 * 0.4], "Brass", UC("brass", length), sides=sides,
                cap0=True, cap1=lod > 0)
        if lod == 0:
            lathe(mb, b - d * 0.02, d, [(0.0, r0 * 0.4), (0.03, 0.06), (0.08, 0.052), (0.12, 0.0)], "Brass",
                  UC("brass", 0.3), sides=6, cap0=False, cap1=False)                        # knob
            # glow strips on both faces of the rib (the underside is the one the valley sees)
            for face in (n_dn, up):
                gp = [hub + d * (t * length) + face * (r0 * s + 0.012)
                      for t, s in ((0.15, 0.95), (0.55, 0.72), (0.95, 0.45))]
                mb.tube(gp, [0.045, 0.04, 0.03], "EtheriumGlow", UC("glow", 1.0), sides=4, cap0=True, cap1=True)
    # membranes between the ribs, cupped upward mid-radius and back on the arc at the rim (barely scalloped)
    nr, nc = (6, 4) if lod == 0 else (1, 1)
    eu = UC("ether", 1.0)
    edge_pts = []
    for k in range(n - 1):
        (d0, l0), (d1, l1) = ribs[k], ribs[k + 1]
        P = []
        for ic in range(nc + 1):
            c = ic / nc
            dd = lerp(d0, d1, c).normalized()
            lc = lerp(l0, l1, c) * (1.0 - 0.03 * 4 * c * (1 - c))
            col = []
            for ir in range(nr + 1):
                r = ir / nr
                p = hub + dd * lerp(r_in, lc, r)
                p = p + up * (0.20 * math.sin(math.pi * c) * math.sin(math.pi * r) * (l0 / 7.0))
                col.append(p)
            P.append(col)
            if lod == 0 and (k == 0 or ic > 0):
                edge_pts.append(col[-1])
        mb.grid(P, lambda i, j, i0, j0: eu(j / nr, i / nc), lambda i, j: "EtheriumGlow", smooth=True,
                out=lambda i, j, pts: n_dn)
    if lod == 0:
        # brass rim along the edge, hub boss (glowing eye underneath) and its arms to the mast
        mb.tube(edge_pts, 0.04, "Brass", UC("brass", L * 3), sides=5, cap0=True, cap1=True)
        lathe(mb, hub + up * 0.18, n_dn, [(0, 0.0), (0.0, 0.30), (0.16, 0.38), (0.32, 0.24), (0.40, 0.0)], "Brass",
              UC("brass", 0.5), sides=12)
        lathe(mb, hub + n_dn * 0.18, n_dn, [(0, 0.15), (0.07, 0.15), (0.14, 0.0)], "EtheriumGlow", UC("glow", 0.2),
              sides=8)
        m = FORE if key == "fore" else MAIN
        root = m.at(hub.y - 0.15) + V(side * 0.2, 0, 0.1)
        mb.tube([root, hub + up * 0.05], 0.07, "Brass", UC("brass", 1.5), sides=6, cap0=True, cap1=True)
        mb.tube([root + V(0, -1.0, 0), hub + V(0, -0.15, 0)], 0.05, "Brass", UC("brass", 1.5), sides=6,
                cap0=True, cap1=True)


# keel-wings: a swept lift fin on each side, rooted high on the bilge just under the wale, so the side
# profile keeps one clean keel line (the tips stay above the keel)
KW_ROOT_Z = (-3.0, 1.5)       # leading and trailing edge at the root, along the bilge
KW_V = 0.91                   # bilge row of the root (y ~ 2.05, under the wale)
KW_SPAN, KW_DROOP, KW_SWEEP, KW_TIP = 5.0, math.radians(20.0), math.radians(35.0), 0.8
KW_RIBS = [0.14, 0.36, 0.58, 0.80, 1.0]           # where the ribs leave the spar (span fraction)
KW_RAKE = 0.45                # ... and the share of the rest of the span they rake out by at the trailing edge


def kw_frame(side):
    e_s = V(side * math.cos(KW_DROOP), -math.sin(KW_DROOP), 0)
    e_c = V(0, 0, 1)
    up = e_s.cross(e_c).normalized()
    if up.y < 0:
        up = -up
    return e_s, e_c, up


def kw_root(z, side):
    s = s_at(z, ("lo", KW_V))
    p = hull_lo(s, KW_V)
    return V(side * (p.x - 0.05), p.y, p.z)


def kw_le(f, side):
    """Leading-edge spar at span fraction f (straight, swept aft)."""
    e_s, e_c, _ = kw_frame(side)
    return kw_root(KW_ROOT_Z[0], side) + e_s * (f * KW_SPAN) + e_c * (f * KW_SPAN * math.tan(KW_SWEEP))


def kw_te(f, side):
    """Trailing edge at span fraction f (straight, from the root to the tapered tip)."""
    return lerp(kw_root(KW_ROOT_Z[1], side), kw_le(1.0, side) + V(0, 0, KW_TIP), f)


def keel_wing(mb, side, lod):
    """A swept, tapered lift wing: a heavy brass leading-edge spar, straight ribs raking back from it to a
    nearly straight trailing edge, amber membrane between, drooped 20 deg."""
    e_s, e_c, up = kw_frame(side)
    # (span fraction at the spar, span fraction at the trailing edge); the root (along the bilge) first
    ribs = [(0.0, 0.0)] + [(f, f + KW_RAKE * (1.0 - f)) for f in (KW_RIBS if lod == 0 else [0.4, 1.0])]
    ends = [(kw_le(f, side), kw_te(g, side)) for f, g in ribs]

    def rib_pt(k, c):
        a, b = ends[k]
        p = lerp(a, b, c)
        if k == 0:                              # the root follows the bilge
            p = p + kw_root(lerp(KW_ROOT_Z[0], KW_ROOT_Z[1], c), side) - lerp(a, b, c)
        return p

    def camber(k, c):
        return up * (0.018 * (ends[k][1] - ends[k][0]).length * math.sin(math.pi * c) ** 0.8)
    eu = UC("ether", 1.0)
    nr, nc = (6, 3) if lod == 0 else (1, 1)
    sides = 6 if lod == 0 else 3
    rim = []
    for k in range(len(ribs) - 1):
        P = []
        for ic in range(nc + 1):
            w = ic / nc
            cmax = 1.0 - 0.05 * 4 * w * (1 - w)              # a faint scallop between the rib ends
            col = []
            for ir in range(nr + 1):
                c = cmax * ir / nr
                col.append(lerp(rib_pt(k, c) + camber(k, c), rib_pt(k + 1, c) + camber(k + 1, c), w))
            P.append(col)
            if lod == 0 and (k == 0 or ic > 0):
                rim.append(col[-1])
        mb.grid(P, lambda i, j, i0, j0: eu(j / nr, i / nc), lambda i, j: "EtheriumGlow", smooth=True,
                out=lambda i, j, pts: up)
    # leading-edge spar, root spar, ribs (glow strips along both faces), trailing-edge rim
    le0, le1 = kw_le(-0.03, side), kw_le(1.02, side)
    spar = ("EtheriumGlow", UC("glow", 1.0)) if (lod and LOD_GLOW) else ("Brass", UC("brass", KW_SPAN))
    mb.tube([le0, lerp(le0, le1, 0.5), le1], [0.15, 0.13, 0.09], spar[0], spar[1], sides=8 if lod == 0 else 4,
            cap0=True, cap1=lod > 0)
    if lod:
        return
    lathe(mb, le1, (le1 - le0).normalized(), [(0, 0.09), (0.06, 0.11), (0.16, 0.07), (0.22, 0.0)], "Brass",
          UC("brass", 0.3), sides=8, cap0=False, cap1=False)
    for k in range(1, len(ribs)):
        path = [rib_pt(k, c) + camber(k, c) for c in (0.03, 0.35, 0.7, 1.0)]
        mb.tube(path, [0.085, 0.07, 0.05, 0.035], "Brass", UC("brass", 6.0), sides=sides, cap0=True, cap1=True)
        for face in (-up, up):
            gp = [rib_pt(k, c) + camber(k, c) + face * (r + 0.012) for c, r in ((0.08, 0.08), (0.5, 0.06), (0.95, 0.035))]
            mb.tube(gp, [0.045, 0.04, 0.03], "EtheriumGlow", UC("glow", 1.0), sides=4, cap0=True, cap1=True)
    # a glow strip along the underside of the spar
    gs = [kw_le(f, side) - up * 0.14 + e_c * 0.05 for f in (0.04, 0.5, 0.97)]
    mb.tube(gs, [0.05, 0.045, 0.035], "EtheriumGlow", UC("glow", 1.0), sides=4, cap0=True, cap1=True)
    mb.tube(rim, 0.035, "Brass", UC("brass", 12.0), sides=5, cap0=True, cap1=True)
    root = [kw_root(z, side) for z in np.linspace(KW_ROOT_Z[0] - 0.3, KW_ROOT_Z[1] + 0.2, 8)]
    mb.tube(root, 0.12, "Brass", UC("brass", 8.0), sides=8, cap0=True, cap1=True)


def build_wingsails(name, lod, mb=None):
    mb = mb or MB(name)
    for key in FANS:
        for side in (1, -1):
            build_fan(mb, key, side, lod)
    for side in (1, -1):
        keel_wing(mb, side, lod)
    return mb


# --------------------------------------------------------------------------
# Atlas and materials
# --------------------------------------------------------------------------
def wnoise(h, w, cy, cx, seed):
    """Value noise, periodic along x (so the bands tile along U)."""
    rng = np.random.default_rng(seed)
    gh, gw = max(h // cy, 1) + 2, max(w // cx, 2)
    small = rng.random((gh, gw))
    ys = np.linspace(0, gh - 2, h, endpoint=False) if h > 1 else np.zeros(1)
    xs = np.arange(w) * gw / w
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int) % gw
    x1 = (x0 + 1) % gw
    y1 = y0 + 1
    fy = (ys - np.floor(ys))[:, None]
    fx = (xs - np.floor(xs))[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = small[y0][:, x0] * (1 - fx) + small[y0][:, x1] * fx
    c = small[y1][:, x0] * (1 - fx) + small[y1][:, x1] * fx
    return a * (1 - fy) + c * fy


def rows_of(band):
    v0, v1 = BAND[band]
    return int(round(v0 * ATLAS)), int(round(v1 * ATLAS))


def planks(img, band, base, n_sub, seed, seam_dark, grain_amp, butt_tile, tone=0.08, seam_light=None,
           butt_dark=0.65, strake_tone=0.0):
    """Planks in a band: n_sub strakes across (a hull row is one strake), butt joints every 1/butt_tile of a
    U tile with a faint tone change per plank, dark seams at the strake edges and an optional light line
    just inside one (a caulked seam catching the light). strake_tone varies each strake's tone a little,
    so the runs read as separate planks converging on the stem and stern."""
    r0, r1 = rows_of(band)
    hh = (r1 - r0) // n_sub
    W = ATLAS
    rng = np.random.default_rng(seed)
    for k in range(n_sub):
        a = r0 + k * hh
        streak = 0.6 * wnoise(hh, W, 2, 60, seed + 10 * k) + 0.4 * wnoise(hh, W, 1, 14, seed + 10 * k + 1)
        cloud = wnoise(hh, W, 16, 160, seed + 10 * k + 2)
        fac = 1.0 + grain_amp * (streak - 0.5) * 2 - 0.10 * np.clip((cloud - 0.5) * 2.5, 0, 1)
        fac = fac * (1.0 + strake_tone * ((k * 0.618 + 0.31) % 1.0 - 0.5) * 2)
        # butt joints: plank segments with their own tone
        nb = max(int(round(butt_tile)), 1)
        offs = (rng.random() + np.arange(nb) / nb) % 1.0
        cuts = np.sort((offs * W).astype(int))
        seg_tone = np.ones(W)
        for i in range(len(cuts)):
            x0, x1 = cuts[i], cuts[(i + 1) % len(cuts)]
            t = 1.0 + tone * (rng.random() - 0.5) * 2
            if x1 > x0:
                seg_tone[x0:x1] = t
            else:
                seg_tone[x0:] = t
                seg_tone[:x1] = t
        fac = fac * seg_tone[None, :]
        col = np.array(base)[None, None, :] * fac[..., None]
        for c in cuts:
            col[:, max(c - 1, 0):c + 1] *= butt_dark
        col[0:2] *= seam_dark
        col[-1:] *= seam_dark
        if seam_light is not None:
            col[2:5] = col[2:5] * seam_light
        img[a:a + hh, :, :3] = col


def srgb_to_lin(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(np.asarray(c, dtype=np.float64), 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def glow_emit(level, rgb=None):
    """Emission mask texel (sRGB encoded, as the 8-bit mask and glTF's emissive texture are) for a glow of
    the given linear level in the etherium colour."""
    return lin_to_srgb(np.asarray(level)[..., None] * srgb_to_lin(rgb or ETHER["glow_rgb"]))


def make_atlas():
    H = W = ATLAS
    img = np.ones((H, W, 4), dtype=np.float32)
    # weathered oak (darker and greyer than the etherium amber, so the wonder is the only saturated gold);
    # butts ~6 m apart along the hull (two per 12 m U tile), barely a tone between planks
    planks(img, "oak", OAK, 4, 101, 0.42, 0.08, 2, tone=0.045, butt_dark=0.65, strake_tone=0.035)
    planks(img, "tar", TAR, 4, 202, 0.45, 0.16, 2, tone=0.08, seam_light=2.3, butt_dark=0.65, strake_tone=0.07)
    planks(img, "deck", DECK_RGB, 4, 303, 0.22, 0.06, 1, tone=0.06)
    # treenails on the deck planks
    r0, r1 = rows_of("deck")
    rng = np.random.default_rng(7)
    for k in range(4):
        yc = r0 + k * 32 + 16
        for x in rng.integers(0, W, 10):
            for dy in (-8, 8):
                img[yc + dy - 1:yc + dy + 1, x:x + 2, :3] *= 0.55
    # plain grain, dark wood
    for band, base, seed in (("grain", GRAIN_RGB, 404), ("dark", DARK_RGB, 505)):
        r0, r1 = rows_of(band)
        hh = r1 - r0
        streak = 0.6 * wnoise(hh, W, 2, 80, seed) + 0.4 * wnoise(hh, W, 1, 16, seed + 1)
        fac = 1.0 + 0.16 * (streak - 0.5) * 2
        img[r0:r1, :, :3] = np.array(base)[None, None, :] * fac[..., None]
    # paint: deep blue-green; gold beading along both edges of the painted strake
    green = np.array(PAINT_RGB)
    gold = np.array(BEAD_RGB)
    for band, bead in (("paint", True), ("paint2", False)):
        r0, r1 = rows_of(band)
        hh = r1 - r0
        n = wnoise(hh, W, 3, 40, 606 if bead else 607)
        col = green[None, None, :] * (0.92 + 0.16 * n[..., None])
        if bead:
            col[31:33] *= 0.7
            for rows, sh in (((1, 2, 3, 4, 5), (0.55, 0.9, 1.15, 1.0, 0.7)), ((58, 59, 60, 61, 62), (0.7, 1.0, 1.15, 0.9, 0.55))):
                for r, k in zip(rows, sh):
                    col[r] = gold * k
            col[0] = col[63] = green * 0.5
        img[r0:r1, :, :3] = col
    # canvas: warm off-white, a seam every 0.6 m (4 cloths per tile), darker tabling at head and foot and a
    # reef band with its points (the head of the band, v = 0, is the sail's head on the square sails and its
    # foot on the fore-and-aft sails, so square sails reef under the yard and the others along the foot)
    r0, r1 = rows_of("canvas")
    hh = r1 - r0
    base = np.array(CANVAS)
    weave = wnoise(hh, W, 1, 3, 707)
    stain = wnoise(hh, W, 40, 200, 708)
    col = base[None, None, :] * (0.97 + 0.05 * weave[..., None]) * (1.0 - 0.10 * np.clip(stain - 0.45, 0, 1)[..., None])
    col = col * np.array((1.0, 0.99, 0.96))[None, None, :] ** (np.clip(stain, 0, 1)[..., None] * 2)
    for k in range(CANVAS_CLOTHS):
        x = k * W // CANVAS_CLOTHS
        for dx, f in ((-3, 0.94), (-2, 0.86), (-1, 0.82), (0, 0.86), (1, 0.82), (2, 0.86), (3, 0.94)):
            col[:, (x + dx) % W] *= f
    for rr, f in ((range(0, 8), 0.72), (range(hh - 8, hh), 0.72)):
        for r in rr:
            col[r] *= f
    col[8:10] *= 0.85
    col[hh - 10:hh - 8] *= 0.85
    reef = hh - int(0.22 * hh)
    col[reef - 4:reef + 4] *= 0.76
    for x in range(8, W, 32):
        col[reef - 9:reef + 9, x:x + 3] *= 0.55
    if CANVAS_PATCHES:
        sew_patches(col, CANVAS_PATCHES)
    img[r0:r1, :, :3] = col
    # cells
    c0 = int(CELL_V[0] * ATLAS)
    cw = W // 8
    ch = H - c0
    yy, xx = np.mgrid[0:ch, 0:cw]
    u, v = xx / (cw - 1), yy / (ch - 1)

    def put(name, rgb, alpha=None):
        k = CELLS.index(name)
        img[c0:H, k * cw:(k + 1) * cw, :3] = rgb
        if alpha is not None:
            img[c0:H, k * cw:(k + 1) * cw, 3] = alpha
    emit = np.zeros((H, W, 3), dtype=np.float32)
    # window: 4 x 3 panes behind glazing bars
    panes = ((np.abs(((u * 4) % 1) - 0.5) < 0.40) & (np.abs(((v * 3) % 1) - 0.5) < 0.40)
             & (u > 0.04) & (u < 0.96) & (v > 0.05) & (v < 0.95))
    glow = 0.80 + 0.20 * np.exp(-((u - 0.5) ** 2 + (v - 0.45) ** 2) * 4)
    wrgb = np.where(panes[..., None], np.array(WINDOW["lit"]) * glow[..., None], np.array(WINDOW["frame"]))
    put("window", wrgb)
    k = CELLS.index("window")
    emit[c0:H, k * cw:(k + 1) * cw] = np.where(panes[..., None], np.array(WINDOW["emit"]) * glow[..., None], 0.0)
    # gilt carving: gold scrolls on blue-green
    p = np.sin(2 * math.pi * (3 * u) + 2.2 * np.sin(2 * math.pi * 1.5 * v)) * np.sin(2 * math.pi * 1.5 * v + 1.6 * np.sin(2 * math.pi * 3 * u))
    mask = np.clip((np.abs(p) - 0.45) * 5, 0, 1)
    shade = 0.75 + 0.35 * np.clip(np.gradient(p, axis=0) * 8, -1, 1)
    grgb = green * (1 - mask[..., None]) + gold * (mask * shade)[..., None]
    grgb[:3] = grgb[-3:] = gold * 0.9
    put("gilt", grgb)
    # brass
    mott = wnoise(ch, cw, 6, 6, 808)
    kk = np.clip((mott - 0.45) * 1.4, 0, 1)[..., None] * 0.45
    put("brass", np.array(BRASS) * (1 - kk) + np.array(BRASS_MOTTLE) * kk)
    # lantern glass, six panes round (V runs round the lantern)
    bars = np.abs(((v * 6) % 1) - 0.5) > 0.44
    lrgb = np.where(bars[..., None], np.array(GLASS["bars"]), np.array(GLASS["lit"]))
    put("glass", lrgb)
    k = CELLS.index("glass")
    emit[c0:H, k * cw:(k + 1) * cw] = np.where(bars[..., None], 0.0, np.array(GLASS["emit"]))
    # etherium membrane (u: hub -> edge, v: across): honey amber, translucent, faint veins, a lighter rim;
    # it glows only faintly of itself (the emission mask), the rib strips, hub eyes and crystal fully
    veins = np.clip(1 - np.abs(((v * 4) % 1) - 0.5) * 14, 0, 1) * (u > 0.15)
    rim = np.clip((u - 0.90) * 10, 0, 1)
    n = wnoise(ch, cw, 8, 8, 909)
    uu = u[..., None]
    mrgb = (np.array(ETHER["rgb0"]) * (1 - uu) + np.array(ETHER["rgb1"]) * uu) * (0.94 + 0.10 * n[..., None])
    mrgb = mrgb * (1 - veins[..., None] * 0.4) + np.array(ETHER["vein_rgb"]) * (veins[..., None] * 0.4)
    mrgb = mrgb * (1 - rim[..., None]) + np.array(ETHER["rim_rgb"]) * rim[..., None]
    put("ether", np.clip(mrgb, 0, 1), np.clip(ETHER["alpha"] + 0.04 * u + 0.05 * veins + 0.12 * rim, 0, 1))
    k = CELLS.index("ether")
    halo = np.exp(-(np.minimum(v, 1 - v) / 0.13) ** 2)
    emit[c0:H, k * cw:(k + 1) * cw] = glow_emit(ETHER["glow"][0] + ETHER["glow"][1] * (1 - u) ** 1.5
                                                + ETHER["halo"] * halo + 0.05 * veins, ETHER["membrane_rgb"])
    put("glow", np.array(ETHER["strip_rgb"]), np.ones_like(u))
    k = CELLS.index("glow")
    emit[c0:H, k * cw:(k + 1) * cw] = glow_emit(np.ones_like(u))
    # hemp
    tw = 0.5 + 0.5 * np.sin(2 * math.pi * (u * 10 + v * 3))
    put("hemp", np.array(HEMP_RGB) * (0.85 + 0.2 * tw[..., None]))
    # crystal (u along its length): honey amber, a bright core band on the prism waist
    band = np.clip(1.0 - np.abs(u - 0.5) / 0.17, 0, 1) ** 0.5
    crgb = (np.array(ETHER["crystal_rgb"][0]) * (1 - band[..., None])
            + np.array(ETHER["crystal_rgb"][1]) * band[..., None])
    put("crystal", crgb, 0.86 + 0.06 * band)
    k = CELLS.index("crystal")
    emit[c0:H, k * cw:(k + 1) * cw] = glow_emit(ETHER["crystal"][0] + ETHER["crystal"][1] * band,
                                                ETHER["membrane_rgb"])
    img[..., :3] = np.clip(img[..., :3], 0, 1)
    im = bpy.data.images.new(ATLAS_NAMES[0], W, H, alpha=True)
    im.pixels.foreach_set(img.reshape(-1))
    im.update()
    im.pack()
    e = emit.reshape(EMIT, ATLAS // EMIT, EMIT, ATLAS // EMIT, 3).mean(axis=(1, 3))
    e4 = np.concatenate([e, np.ones((EMIT, EMIT, 1), dtype=np.float32)], axis=2)
    em = bpy.data.images.new(ATLAS_NAMES[1], EMIT, EMIT, alpha=False)
    em.pixels.foreach_set(e4.astype(np.float32).reshape(-1))
    em.update()
    em.pack()
    return im, em


def make_material(name, atlas, rough, metal=0.0, cull=True, emit_img=None, emit_strength=0.0, alpha=False,
                  spec=None):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = atlas
    tex.location = (-500, 250)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if alpha:
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        try:
            m.surface_render_method = "BLENDED"
        except (AttributeError, TypeError):
            pass
    if emit_img is not None:
        et = nt.nodes.new("ShaderNodeTexImage")
        et.image = emit_img
        et.location = (-500, -150)
        nt.links.new(et.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    if spec is not None:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    m.use_backface_culling = cull
    return m


def make_materials():
    atlas, emit = make_atlas()
    MATS["Wood"] = make_material("Wood", atlas, 0.72, emit_img=emit, emit_strength=WOOD_EMIT)
    MATS["Tar"] = make_material("Tar", atlas, 0.78)
    MATS["Paint"] = make_material("Paint", atlas, 0.50)
    MATS["Canvas"] = make_material("Canvas", atlas, 0.88, cull=False)
    MATS["Brass"] = make_material(MAT_NAMES.get("Brass", "Brass"), atlas, METAL[0], metal=METAL[1])
    # emission from the shared mask: faint on the membranes, full on the rib strips, hub eyes and crystal;
    # the emissive strength (2) is the knob the game pulses
    MATS["EtheriumGlow"] = make_material("EtheriumGlow", atlas, 0.60, cull=False, alpha=True, emit_img=emit,
                                         emit_strength=2.0, spec=0.15)


# --------------------------------------------------------------------------
# Assembly / export
# --------------------------------------------------------------------------
def add_empty(name, p):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.6
    e.location = G(p)
    bpy.context.scene.collection.objects.link(e)
    return e


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def build_ship():
    make_materials()
    hull_mb, info = build_hull("Hull", 0)
    rig_mb, pts = build_rig("Rig", 0)
    sails_mb = build_sails("Sails", 0)
    wings_mb = build_wingsails("WingSails", 0)
    objs = [hull_mb.obj(), rig_mb.obj(), sails_mb.obj(), wings_mb.obj()]
    # far LOD: everything in one mesh
    lod_mb, _ = build_hull("Galleon_LOD1", 1)
    build_rig("Galleon_LOD1", 1, lod_mb)
    build_sails("Galleon_LOD1", 1, lod_mb)
    build_wingsails("Galleon_LOD1", 1, lod_mb)
    objs.append(lod_mb.obj())
    # markers
    s_deck = s_of_zn(-2.7)
    empties = [
        add_empty("Helm", info["helm"]),
        add_empty("Deck", V(0, deck_surface_y(s_deck, 0.0), -2.7)),
        add_empty("Bow", V(0, sheer(0.0), Z_BOW_TOP)),
        add_empty("Stern", V(0, sheer(1.0) + E_QD + 0.56, transom_xyz(("r", 1.0))[2]
                             + TRANSOM_BULGE * transom_xyz(("r", 1.0))[0] - 0.07)),
        add_empty("KeelGlow", info["crystal"]),
    ]
    return objs, empties


def fan_clashes(objs):
    """Print the rigging, sails and hull that pass through an etherium fan (segment against the fans'
    glowing membrane triangles). The fans are rigid: nothing should pass through them."""
    def godot(me):
        B = np.array([v.co[:] for v in me.vertices])
        return np.stack([B[:, 0], B[:, 2], -B[:, 1]], axis=1)
    wings = next(o for o in objs if o.name == "WingSails")
    me = wings.data
    me.calc_loop_triangles()
    W = godot(me)
    glow = [k for k, m in enumerate(me.materials) if m.name == "EtheriumGlow"][0]
    T = np.array([t.vertices[:] for t in me.loop_triangles if t.material_index == glow])
    T = T[W[T][:, :, 1].min(axis=1) > 8.0]                 # the fans (the keel-wings sit on the hull)
    A, Bv, C = W[T[:, 0]], W[T[:, 1]], W[T[:, 2]]
    lo, hi = np.minimum(np.minimum(A, Bv), C).min(axis=0) - 0.3, np.maximum(np.maximum(A, Bv), C).max(axis=0) + 0.3
    e1, e2 = Bv - A, C - A
    for o in objs:
        if o.name not in ("Hull", "Rig", "Sails"):
            continue
        P = godot(o.data)
        E = np.array([e.vertices[:] for e in o.data.edges])
        p0, p1 = P[E[:, 0]], P[E[:, 1]]
        keep = ~(((p0 < lo) & (p1 < lo)).any(axis=1) | ((p0 > hi) & (p1 > hi)).any(axis=1))
        p0, p1 = p0[keep], p1[keep]
        hits = []
        for i in range(0, len(p0), 256):
            q0, dq = p0[i:i + 256, None, :], (p1 - p0)[i:i + 256, None, :]
            h = np.cross(dq, e2[None])
            a = (e1[None] * h).sum(-1)
            ok = np.abs(a) > 1e-12
            f = np.where(ok, 1.0 / np.where(ok, a, 1.0), 0.0)
            sv = q0 - A[None]
            u = f * (sv * h).sum(-1)
            qv = np.cross(sv, e1[None])
            v = f * (dq * qv).sum(-1)
            t = f * (e2[None] * qv).sum(-1)
            hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t >= 0) & (t <= 1)
            for ei, ti in zip(*np.nonzero(hit)):
                hits.append(q0[ei, 0] + dq[ei, 0] * t[ei, ti])
        if hits:
            H = np.array(hits)
            keys = list(FANS)
            near = np.argmin(np.abs(H[:, 2:3] - np.array([[FANS[k][0].z for k in keys]])), axis=1)
            for sx in (1, -1):
                for ki, name in enumerate(keys):
                    m = (near == ki) & (np.sign(H[:, 0]) == sx)
                    if m.any():
                        X = H[m]
                        print("GALLEON clash %-5s through %s fan %+d: %3d hits, x %.1f..%.1f y %.1f..%.1f z %.1f..%.1f" % (
                            o.name, name, sx, m.sum(), X[:, 0].min(), X[:, 0].max(), X[:, 1].min(), X[:, 1].max(),
                            X[:, 2].min(), X[:, 2].max()))
    print("GALLEON clash check done")


def export_glb(objs, path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
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
# Previews (Eevee, 960 x 540, 16 samples)
# --------------------------------------------------------------------------
def make_world(name, stops, strength):
    w = bpy.data.worlds.new(name)
    try:
        w.use_nodes = True
    except AttributeError:
        pass
    nt = w.node_tree
    bg = nt.nodes.get("Background")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1.0
    mr.inputs["From Max"].default_value = 1.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = stops[0][0], (*stops[0][1], 1)
    els[1].position, els[1].color = stops[-1][0], (*stops[-1][1], 1)
    for pos, c in stops[1:-1]:
        e = els.new(pos)
        e.color = (*c, 1)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength
    return w


def look(obj, loc_g, target_g):
    obj.location = G(loc_g)
    d = G(target_g) - G(loc_g)
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def setup_compositor(sc, on):
    try:
        if not on:
            sc.compositing_node_group = None
            return
        tree = bpy.data.node_groups.get("GalleonComp")
        if tree is None:
            tree = bpy.data.node_groups.new("GalleonComp", "CompositorNodeTree")
            tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
            rl = tree.nodes.new("CompositorNodeRLayers")
            gl = tree.nodes.new("CompositorNodeGlare")
            gl.inputs["Type"].default_value = "Bloom"
            gl.inputs["Threshold"].default_value = 0.9
            gl.inputs["Strength"].default_value = 0.6
            gl.inputs["Size"].default_value = 0.6
            out = tree.nodes.new("NodeGroupOutput")
            tree.links.new(rl.outputs["Image"], gl.inputs["Image"])
            tree.links.new(gl.outputs[0], out.inputs[0])
        sc.compositing_node_group = tree
    except Exception as ex:   # the previews still render without the bloom
        print("COMPOSITOR skipped:", ex)


def render_previews(out_dir, near_objs, lod_obj, diag=None, only=None):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.eevee.taa_render_samples = 16
    sc.render.resolution_x, sc.render.resolution_y = 960, 540
    sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    sc.render.film_transparent = False
    day = make_world("Day", [(0.0, (0.16, 0.22, 0.13)), (0.40, (0.30, 0.38, 0.30)), (0.48, (0.52, 0.60, 0.64)),
                             (0.5, (0.70, 0.80, 0.92)), (0.54, (0.42, 0.60, 0.88)), (0.66, (0.24, 0.44, 0.82)),
                             (1.0, (0.10, 0.24, 0.62))], 1.0)
    dusk = make_world("Dusk", [(0.0, (0.03, 0.03, 0.05)), (0.47, (0.10, 0.07, 0.09)), (0.5, (0.95, 0.42, 0.18)),
                               (0.55, (0.55, 0.26, 0.30)), (0.68, (0.16, 0.13, 0.28)), (1.0, (0.03, 0.04, 0.12))], 0.55)
    sun_d = bpy.data.lights.new("Sun", "SUN")
    sun = bpy.data.objects.new("Sun", sun_d)
    sc.collection.objects.link(sun)
    sun_d.angle = math.radians(1.5)
    # the fans and keel-wings cast no shadows (as in the game: turn cast_shadow off on WingSails); the
    # keel crystal's blended shadow would only speckle
    for o in near_objs:
        if o.name == "WingSails":
            o.visible_shadow = False
    try:
        MATS["EtheriumGlow"].use_transparent_shadow = False
    except AttributeError:
        pass
    helpers = []
    lights = [("PodLight", CRYSTAL_C + POD_LIGHT[0], (1.0, 0.62, 0.22), POD_LIGHT[1], 0.6),
              ("SternLight", V(0, 4.7, 14.3), (1.0, 0.7, 0.4), 500.0, 0.4)]
    for key in FANS:
        for side in (1, -1):
            ribs = fan_ribs(key, side)
            d, ln = ribs[len(ribs) // 2]
            lights.append(("Fan_%s_%d" % (key, side), fan_hub(key, side) + d * (0.45 * ln) + V(0, -0.6, 0),
                           (1.0, 0.66, 0.28), 700.0, 1.0))
    for nm, p, col, e, r in lights:
        ld = bpy.data.lights.new(nm, "POINT")
        ld.color, ld.energy, ld.shadow_soft_size = col, e, r
        lo = bpy.data.objects.new(nm, ld)
        lo.location = G(p)
        sc.collection.objects.link(lo)
        helpers.append(lo)
    cd = bpy.data.cameras.new("Cam")
    cd.clip_start, cd.clip_end = 0.1, 800.0
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    lod_obj.hide_render = True
    shots = [
        # name, camera, target, lens, world, sun dir (toward the sun, Godot), sun energy, sun colour, helpers
        ("front3q", V(38, 28, -50), V(0, 12.0, -3.0), 40, day, V(0.55, 0.75, -0.35), 3.2, (1.0, 0.95, 0.88), False),
        ("side_starboard", V(72, 12.5, -3.5), V(0, 12.5, -3.5), 40, day, V(0.75, 0.6, 0.25), 3.2, (1.0, 0.95, 0.88), False),
        ("stern3q", V(-32, 17, 44), V(0, 9.5, 0.5), 35, day, V(-0.6, 0.7, 0.4), 3.2, (1.0, 0.95, 0.88), False),
        ("below", V(26, -36, 14), V(0, 8.5, -2.0), 30, day, V(0.3, 0.9, -0.2), 3.2, (1.0, 0.95, 0.88), False),
        ("dusk", V(-38, 3, -33), V(0, 9.5, 0), 35, dusk, V(0.3, 0.06, 0.95), 1.4, (1.0, 0.52, 0.28), True),
        # Galleon_LOD1 alone from 150 m, below, on the same line as "below": the far silhouette
        ("below_lod1_150m", V(0, 8.5, -2) + V(26, -44.5, 16).normalized() * 150.0, V(0, 8.5, -2), 40, day,
         V(0.3, 0.9, -0.2), 3.2, (1.0, 0.95, 0.88), False),
    ]
    if diag:
        shots = [
            ("d_deck", V(7, 12, 6), V(0, 3.6, -2.0), 30, day, V(0.55, 0.75, -0.35), 3.2, (1.0, 0.95, 0.88), False),
            ("d_bow", V(10, 7, -22), V(0, 4.8, -13.0), 35, day, V(0.55, 0.75, -0.35), 3.2, (1.0, 0.95, 0.88), False),
            ("d_stern", V(8, 7.5, 22), V(0, 5.2, 12.2), 35, day, V(0.3, 0.7, 0.6), 3.2, (1.0, 0.95, 0.88), False),
            ("d_ports", V(13, 4.5, -2), V(3.0, 3.9, -1.0), 35, day, V(0.75, 0.6, 0.25), 3.2, (1.0, 0.95, 0.88), False),
            ("d_top", V(12, 19, -16), V(0, 15, -6.5), 30, day, V(0.55, 0.75, -0.35), 3.2, (1.0, 0.95, 0.88), False),
            ("d_lod1", V(38, 30, -50), V(0, 12.5, -2.5), 32, day, V(0.55, 0.75, -0.35), 3.2, (1.0, 0.95, 0.88), False),
            ("d_qd", V(0.6, 6.7, 5.2), V(0, 5.6, 12.8), 24, day, V(0.55, 0.75, -0.35), 3.2, (1.0, 0.95, 0.88), False),
            ("d_fc", V(1.2, 6.6, -5.6), V(0, 5.4, -13.0), 24, day, V(0.55, 0.75, -0.35), 3.2, (1.0, 0.95, 0.88), False),
            ("d_wing", V(13, -5, -12), V(5.0, 0.4, -1.0), 32, day, V(0.55, 0.75, -0.35), 3.2, (1.0, 0.95, 0.88), False),
            ("d_wing_below", V(-7, -14, -1), V(-5.5, 0.3, -1.0), 40, day, V(0.3, 0.9, -0.2), 3.2, (1.0, 0.95, 0.88), False),
            ("d_wing_top", V(-9, 9, -3), V(-5.5, 0.3, -1.0), 35, day, V(0.3, 0.9, -0.2), 3.2, (1.0, 0.95, 0.88), False),
            ("d_fan", V(14, 27, -6), V(4.5, 18.5, 4.0), 30, day, V(0.55, 0.75, -0.35), 3.2, (1.0, 0.95, 0.88), False),
            ("d_crystal", V(5, -5.5, -7), V(0, -1.2, -0.4), 30, day, V(0.3, 0.9, -0.2), 3.2, (1.0, 0.95, 0.88), False),
            ("d_tuck", V(16, 2.5, 18), V(0, 2.6, 10.8), 30, day, V(-0.6, 0.7, 0.4), 3.2, (1.0, 0.95, 0.88), False),
            ("d_bottom", V(9, -34, 6), V(0, 1.0, 0.5), 32, day, V(0.3, 0.9, -0.2), 3.2, (1.0, 0.95, 0.88), False),
            ("d_fin", V(7, -9, 25), V(0, 1.2, 8.5), 32, day, V(-0.6, 0.7, 0.4), 3.2, (1.0, 0.95, 0.88), False),
            ("d_dusk_pod", V(-14, -1.5, -12), V(0, -0.6, -0.4), 30, dusk, V(0.3, 0.06, 0.95), 1.4, (1.0, 0.52, 0.28),
             True),
        ]
        out_dir = diag
        os.makedirs(out_dir, exist_ok=True)
    if only:
        shots = [sh for sh in shots if sh[0] in only]
    for name, loc, tgt, lens, world, sdir, se, scol, use_helpers in shots:
        lod = name in ("d_lod1", "below_lod1_150m")
        lod_obj.hide_render = not lod
        for o in near_objs:
            o.hide_render = lod
        sc.world = world
        cd.lens = lens
        look(cam, loc, tgt)
        d = -G(sdir.normalized())
        sun.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        sun_d.energy, sun_d.color = se, scol
        for h in helpers:
            h.hide_render = not use_helpers
        setup_compositor(sc, use_helpers)
        sc.render.filepath = os.path.join(out_dir, "galleon_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)


# ==========================================================================
# The hunter (--variant hunter): the enemy ship of Two Fires
# ==========================================================================
# The same build system and conventions (axes, origin, nodes, empties, materials, one atlas) rebound to another
# ship of our own design. use_hunter() rebinds the module's knobs (the functions above read them when they run)
# and the hunter's own builders below replace the galleon's where the ship differs (rig, sails, fans, stern,
# beak, guns, deck fittings). Nothing above changes for the galleon.
HUNTER = dict(
    # hull form: 36 m from the stem head to the taffrail, beam 7.8 m, low sheer, fine ends, a sharp V floor
    B0=3.9, DRISE=0.62, TUMBLE=0.12, N_FULL=(1.42, 0.55), Z_DW=9.4, KEEL_W=0.34, KEEL_BAND=("tar", (2, 4)),
    Z_FOREFOOT=-14.6, STEM_RUN=3.4, Z_POST=14.2, Z_WT=14.6, Z_C=17.4, TRANSOM_RAKE=0.22, TW=0.60,
    SB=0.44, SM=0.58, SHEER_MID=3.95, SHEER_LOW_Z=2.0, SHEER_BOW=0.70, SHEER_STERN=0.45,
    BULWARK=0.95, FC_UP=0.75, FC_RAIL=0.85, QD_UP=1.15, QD_RAIL=0.80, Z_FC_BREAK=-12.2, Z_QD_BREAK=8.0,
    TRANSOM_BULGE=0.08, F_TOP=1.50, WALE=(1.50, 1.15), RUDDER_TOP=3.25, WHEEL_Z=13.4, DOOR_X=0.85,
    # one row per strake; the d 0.72 -> 0.0 row is the dark red strake the ports are cut through
    OUTER_ROWS={
        0: [("lo", k / 14) for k in range(15)] + [("f", 0.4), ("f", 0.75), ("d", 1.50), ("d", 1.15), ("d", 0.72),
                                                  ("d", 0.0), ("r", 0.38), ("r", 0.75), ("r", 1.0)],
        1: [("lo", 0.0), ("lo", 0.3), ("lo", 0.6), ("lo", 1.0), ("f", 0.6), ("d", 1.15), ("d", 0.72), ("d", 0.0),
            ("r", 1.0)],
    },
    # eight ports a side, all open, the guns run out (clear of the channels)
    PORTS_Z=[-7.9, -5.7, -3.5, -1.3, 3.0, 5.0, 7.0, 12.2], PORTS_OPEN=[True] * 8, PORT_W=0.60, PORT_SILL=0.30,
    CHANNELS={"fore": (-11.9, -8.7, [-11.5, -10.7, -9.9, -9.1]), "main": (-0.8, 2.4, [-0.4, 0.4, 1.2, 2.0]),
              "mizzen": (9.0, 11.4, [9.4, 10.2, 11.0])},
    Y_STEP=2.9, STEEVE=math.radians(18.0),
    BOWSPRIT=dict(head_y=4.85, out=4.6, heel=4.0, jb_back=2.0, jb_steeve=16.0, jb_len=5.6),
    # keel-wings: longer in the root, swept harder
    KW_ROOT_Z=(-5.2, 0.6), KW_SPAN=5.4, KW_DROOP=math.radians(20.0), KW_SWEEP=math.radians(46.0), KW_TIP=0.7,
    KW_RIBS=[0.2, 0.45, 0.7, 1.0],
    # keel crystal: longer and slimmer, a little aft of midships
    CRYSTAL_C=V(0, -1.25, 0.6), CRYSTAL_TIP=2.9, CRYSTAL_PRISM=1.0, CRYSTAL_R=0.72, CRYSTAL_COLLAR=2.2,
    POD_LIGHT=(V(0, 1.1, 0), 1200.0),
    # fans: flatter planes (the ribs swept back, like a bat's wing, not opened up like the galleon's)
    FAN_DIHEDRAL=math.radians(16.0), FAN_LIFT=math.radians(9.0), FAN_CUP=math.radians(5.0),
    # the look: black tar, blackened topsides, a dark red strake, iron, dark patched canvas, a cold red-violet glow
    OAK=(0.125, 0.11, 0.10), TAR=(0.055, 0.05, 0.048), BRASS=(0.20, 0.20, 0.21), CANVAS=(0.33, 0.30, 0.27),
    DECK_RGB=(0.40, 0.37, 0.33), GRAIN_RGB=(0.24, 0.20, 0.16), DARK_RGB=(0.085, 0.07, 0.065),
    PAINT_RGB=(0.30, 0.045, 0.035), BEAD_RGB=(0.16, 0.16, 0.17), HEMP_RGB=(0.20, 0.17, 0.13),
    BRASS_MOTTLE=(0.24, 0.12, 0.07),
    WINDOW=dict(lit=(0.62, 0.18, 0.52), frame=(0.05, 0.04, 0.05), emit=(0.70, 0.12, 0.55)),
    GLASS=dict(bars=(0.06, 0.06, 0.065), lit=(0.82, 0.32, 0.74), emit=(0.80, 0.14, 0.62)),
    # a cold red-violet (hue ~320 deg): apart from the galleon's amber and from the tear's and the Drift's violet
    ETHER=dict(rgb0=(0.14, 0.03, 0.10), rgb1=(0.22, 0.045, 0.16), alpha=0.62, glow=(0.16, 0.14), halo=0.34,
               glow_rgb=(0.80, 0.12, 0.62), membrane_rgb=(0.74, 0.14, 0.66), crystal=(0.16, 0.34),
               vein_rgb=(0.40, 0.07, 0.30), rim_rgb=(0.46, 0.09, 0.36), strip_rgb=(0.92, 0.40, 0.86),
               crystal_rgb=((0.36, 0.07, 0.28), (0.78, 0.28, 0.70))),
    CANVAS_CLOTHS=16, CANVAS_PATCHES=4242, CANVAS_SHIFT=0.618, WOOD_EMIT=2.5, METAL=(0.55, 0.85),
    MAT_NAMES={"Brass": "Iron"}, ATLAS_NAMES=("hunter_atlas", "hunter_emission"), LOD_GLOW=True,
)
H_YARDS = {  # (mast, yard): y, which spar it hangs on (lower/topmast/topgallant), dz forward of it, half length, radius
    ("fore", "course"): (12.4, "low", -0.55, 7.4, 0.19),
    ("fore", "topsail"): (19.6, "tm", -0.36, 5.6, 0.15),
    ("fore", "topgallant"): (25.4, "tg", -0.24, 3.8, 0.10),
    ("main", "course"): (13.8, "low", -0.58, 8.4, 0.21),
    ("main", "topsail"): (22.0, "tm", -0.38, 6.4, 0.17),
    ("main", "topgallant"): (28.5, "tg", -0.25, 4.3, 0.11),
    ("mizzen", "crossjack"): (11.0, "low", -0.45, 5.6, 0.15),     # bare: the mizzen topsail sheets to it
    ("mizzen", "topsail"): (17.4, "tm", -0.30, 4.2, 0.12),
}
H_SQUARE = {"fore": ["course", "topsail", "topgallant"], "main": ["course", "topsail", "topgallant"],
            "mizzen": ["crossjack", "topsail"]}
H_CLEWS = {"fore": (7.1, 6.1), "main": (8.0, 5.5)}     # course clews: out along the yard, height
H_FAN_SCALLOP = 0.24          # the fan's edge dips in between two ribs by this share of their length (a bat's wing)
H_FAN_SPIKE = 0.65            # ... and the ribs run on past it as iron spikes (m)
BEAK = dict(root=V(0, 2.10, -16.3), tip=V(0, 1.72, -20.8), hh=0.62, hw=0.44, n=10)
# the duel previews: the galleon beside the hunter, as far from the camp, 100 m to its left and 8 m lower
DUEL_AT = V(-0.799, 0.0, -0.602) * 100.0 + V(0, -8.0, 0)
MIZZEN = None


def use_hunter():
    """Rebind the module's knobs to the hunter's and recompute what derives from them."""
    g = globals()
    g.update(HUNTER)
    g["TUCK"] = (H_WT - 0.04, 0.62)
    g["E_FC"] = FC_UP - BULWARK + FC_RAIL
    g["E_QD"] = QD_UP - BULWARK + QD_RAIL
    g["Z_BOW_TOP"], g["Z_STERN_TOP"] = zb(1.0), zs(1.0)
    g["S_FCB"], g["S_QDB"] = s_of_zn(Z_FC_BREAK), s_of_zn(Z_QD_BREAK)
    g["INNER"] = {
        "fc": [("d", BULWARK - FC_UP + 0.06), ("r", 0.6), ("r", 1.0)],
        "waist": [("d", BULWARK + 0.06), ("d", 0.70), ("d", 0.35), ("d", 0.0), ("r", 0.5), ("r", 1.0)],
        "qd": [("d", BULWARK - QD_UP + 0.06), ("r", 0.6), ("r", 1.0)],
    }
    g["CANVAS_TILE"] = 0.6 * CANVAS_CLOTHS
    g["seg_kind"] = seg_kind_hunter
    # three masts, raked harder aft each one
    F, M, Z = Mast(-10.0, math.radians(4.0)), Mast(0.4, math.radians(6.0)), Mast(10.4, math.radians(8.0))
    g["FORE"], g["MAIN"], g["MIZZEN"] = F, M, Z
    g["SPEC"] = {
        "fore": dict(m=F, r=(0.28, 0.22), top=13.6, cap=15.0, tm=(-0.46, 12.9, 22.2, 0.18, 0.12), xt=20.8,
                     tg=(-0.74, 21.0, 27.8, 0.11, 0.05), top_w=1.45, xt_w=1.1),
        "main": dict(m=M, r=(0.30, 0.24), top=15.0, cap=16.5, tm=(-0.48, 14.3, 24.6, 0.19, 0.12), xt=23.2,
                     tg=(-0.78, 23.4, 31.0, 0.12, 0.05), top_w=1.6, xt_w=1.2),
        "mizzen": dict(m=Z, r=(0.22, 0.17), top=12.2, cap=13.4, tm=(-0.36, 11.7, 20.0, 0.13, 0.07), xt=18.7,
                       tg=None, top_w=1.1, xt_w=0.8),
    }
    # fans on the fore and main tops: hub (starboard, aft of the top), leading rib, rib count, rib angles (0 = abeam)
    g["FANS"] = {
        "fore": (V(1.35, 14.05, F.at(14.05).z + 1.2), 6.6, 5, (26.0, 98.0)),
        "main": (V(1.5, 15.45, M.at(15.45).z + 1.2), 7.6, 5, (22.0, 100.0)),
    }


def seg_kind_hunter(sa, sb, lod):
    """Tarred black up to the wale, blackened topsides, the dark red strake (d 0.72 -> 0.0) through the ports."""
    if sb[0] in ("lo", "f") or sb in (("d", 1.50), ("d", 1.15)):
        return "tar"
    if sb == ("d", 0.0):
        return "paint"
    return "oak"


def sew_patches(col, seed, n=34):
    """Patches sewn over a canvas band (in place): cloth a little older or newer, some browner, a darker stitched
    hem; a patch or two per sail, never a quilt."""
    rng = np.random.default_rng(seed)
    hh, W = col.shape[:2]
    for _ in range(n):
        pw, ph = int(rng.integers(60, 170)), int(rng.integers(22, 70))
        x0, y0 = int(rng.integers(0, W)), int(rng.integers(14, hh - 14 - ph))
        xs = np.arange(x0, x0 + pw) % W
        tint = np.array((1.0, 1.0 - rng.uniform(0.0, 0.05), 1.0 - rng.uniform(0.0, 0.12))) * rng.uniform(0.84, 1.12)
        blk = col[y0:y0 + ph][:, xs] * tint[None, None, :]
        for sl in (np.s_[:2], np.s_[-2:]):
            blk[sl] *= 0.78
            blk[:, sl] *= 0.78
        blk[3, ::5] *= 0.85                     # the stitches, just inside the hem
        blk[-4, ::5] *= 0.85
        blk[::5, 3] *= 0.85
        blk[::5, -4] *= 0.85
        col[y0:y0 + ph, xs] = blk


# --------------------------------------------------------------------------
# Hunter: hull
# --------------------------------------------------------------------------
def build_beak(mb, lod):
    """The ram: an iron-shod beak thrust ahead of the cutwater, a tapered six-sided spike (a ridge on top, a keel
    under it, hooked down a touch) rooted inside the bow, two iron bands round it and a glow strip along each upper
    edge. At 300 m it is the point ahead of the bow, under the bowsprit."""
    p0, p1 = BEAK["root"], BEAK["tip"]
    n = BEAK["n"] if lod == 0 else 3
    iron = UC("brass", 4.0)
    shape = ((0, 1), (1, 0.32), (0.82, -0.52), (0, -1), (-0.82, -0.52), (-1, 0.32))

    def centre(t):
        return lerp(p0, p1, t) + V(0, -0.10 * math.sin(math.pi * t), 0)

    def section(t, grow=0.0):
        hh = BEAK["hh"] * (1.0 - t) ** 0.8 + 0.02 + grow
        hw = BEAK["hw"] * (1.0 - t) ** 0.9 + 0.015 + grow
        c = centre(t)
        return [c + V(x * hw, y * hh, 0) for x, y in shape]
    ts = [k / n for k in range(n + 1)]
    rings = [section(t) for t in ts[:-1]] + [[p1.copy() for _ in shape]]
    P = [r + [r[0].copy()] for r in rings]
    mb.grid(P, lambda i, j, i0, j0: iron(ts[i] * 4.0, j / 6.0), lambda i, j: "Brass", smooth=False,
            out=lambda i, j, pts: sum(pts, Vector()) / len(pts) - centre(ts[i]))
    if lod:
        return p1
    for t in (0.30, 0.48):
        mb.tube(section(t, 0.025), 0.035, "Brass", iron, sides=4, closed=True)
    for j in (1, 5):
        path = []
        for t in np.linspace(0.27, 0.93, 6):
            sec, c = section(t), centre(t)
            path.append(sec[j] + (sec[j] - c).normalized() * 0.02)
        mb.tube(path, lambda f: lerp(0.032, 0.012, f), "EtheriumGlow", UC("glow", 1.0), sides=4, cap0=True, cap1=True)
    return p1


def build_bow_hunter(mb):
    """Catheads on the forecastle rail and the anchors stowed against the bow (no head, no figurehead: the beak is
    the hunter's face)."""
    dark = UB("dark", 2.0)
    tar = UB("tar", 4.0, (2, 4))
    rail = ("r", 1.0)
    s = s_at(-15.4, rail)
    p = hp(s, rail)
    for sx in (1, -1):
        a = V(sx * (p.x - 0.3), p.y + 0.10, p.z + 0.25)
        b = V(sx * (p.x + 0.85), p.y + 0.22, p.z - 0.6)
        mb.beam(a, b, 0.24, 0.24, V(0, 1, 0), "Wood", dark)
        mb.box(b + V(sx * 0.02, 0, -0.02), V(0.14, 0, 0), V(0, 0.14, 0), V(0, 0, 0.14), "Brass", UC("brass"))
        ring = b + V(0, -0.25, 0)
        sa = s_at(-15.0, ("d", 1.30))
        rest = hp(sa, ("d", 1.30)) + hnorm(sa, ("d", 1.30)) * 0.22
        if sx < 0:
            rest = mirror(rest)
        shank_top, shank_bot = ring + V(0, -0.1, 0), rest
        mb.beam(shank_top, shank_bot, 0.12, 0.12, V(1, 0, 0), "Tar", tar)
        mb.beam(shank_top + V(-0.9, -0.25, 0.0), shank_top + V(0.9, -0.25, 0.0), 0.16, 0.16, V(0, 1, 0), "Wood", dark)
        for k in (-1, 1):
            tip = shank_bot + V(0, 0.75, k * 0.85)
            mb.beam(shank_bot, tip, 0.11, 0.11, V(1, 0, 0), "Tar", tar)
            mb.beam(tip, tip + V(0, -0.15, -k * 0.3), 0.06, 0.32, V(1, 0, 0), "Tar", tar)


H_GUN = [(0.0, 0.0), (0.03, 0.10), (0.14, 0.18), (0.72, 0.19), (0.78, 0.165), (1.70, 0.135), (1.92, 0.15),
         (2.06, 0.20), (2.10, 0.20), (2.10, 0.12), (1.96, 0.0)]     # an iron gun with a bell mouth
H_RING = (0.80, 0.25, 0.205)                 # wind ring: out from the port, iron ring radius, glow ring radius


def build_gunports_hunter(mb, lod):
    """Eight ports a side with the guns run out: frames, lids hauled up (red inside), iron guns on carriages, and at
    each bell mouth a wind ring: an iron ring on three struts with a glowing ring inside it, where the Gust leaves
    the gun (no powder, no smoke). Returns the muzzles [(side, k, ring centre, outward)]."""
    tar = UB("tar", 2.0, (0, 4))
    dark = UB("dark", 1.5)
    red = UB("paint2", 2.0)
    iron = UB("tar", 3.0, (3, 4))
    ring_uv = UC("brass", 1.6)
    up = V(0, 1, 0)
    muzzles = []
    for side in (1, -1):
        for k, z in enumerate(PORTS_Z):
            d_c = BULWARK - PORT_SILL - 0.5 * PORT_H
            s = s_at(z, ("d", d_c))
            c, n, t = port_frame(s, side)
            hw, hh = 0.5 * PORT_W, 0.5 * PORT_H
            opening = [c + n * 0.025 + t * a + up * b for a, b in ((-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh))]
            mb.poly(opening, [tar(0, 0), tar(1, 0), tar(1, 1), tar(0, 1)], "Tar", False, n)
            base = c - n * 1.45 + up * -0.05
            rc = base + n * (1.45 + H_RING[0])
            muzzles.append((side, k, rc, n))
            if lod:
                continue
            fw = 0.075
            for a0, a1, b0, b1 in ((-hw - fw, hw + fw, hh, hh + fw), (-hw - fw, hw + fw, -hh - fw, -hh),
                                   (-hw - fw, -hw, -hh, hh), (hw, hw + fw, -hh, hh)):
                cc = c + n * 0.045 + t * (0.5 * (a0 + a1)) + up * (0.5 * (b0 + b1))
                mb.box(cc, t * (0.5 * (a1 - a0)), up * (0.5 * (b1 - b0)), n * 0.04, "Wood", dark, skip=("-z",))
            hinge = c + n * 0.09 + up * (hh + fw)
            ang = math.radians(100.0)
            lid_dn = (-up * math.cos(ang) + n * math.sin(ang))
            lid_n = (up * math.sin(ang) + n * math.cos(ang))
            mb.box(hinge + lid_dn * (hh + fw) + lid_n * 0.03, t * (hw + fw), lid_dn * (hh + fw), lid_n * 0.035, "Paint",
                   red)
            lathe(mb, base, n, H_GUN, "Tar", iron, sides=8, perp=up, cap0=False, cap1=False)
            torus(mb, rc, n, H_RING[1], 0.035, "Brass", ring_uv, seg=10, sides=4)
            torus(mb, rc - n * 0.01, n, H_RING[2], 0.024, "EtheriumGlow", UC("glow", 1.3), seg=10, sides=3)
            for j in range(3):
                a = 2 * math.pi * j / 3 + math.pi / 6
                rad = up * math.cos(a) + t * math.sin(a)
                mb.tube([base + n * 2.06 + rad * 0.19, rc + rad * (H_RING[1] - 0.02)], 0.016, "Brass", ring_uv,
                        sides=3)
            if z < Z_QD_BREAK - 0.7:
                inb = c - n * 0.95
                yd = deck_surface_y(s, abs(inb.x))
                mb.box(V(inb.x, yd + 0.24, inb.z), n * 0.55, V(0, 0.2, 0), t * 0.30, "Wood", dark)
                for sgn in (-1, 1):
                    for along in (-0.36, 0.36):
                        wc = inb + n * along + t * (sgn * 0.33)
                        lathe(mb, V(wc.x, yd + 0.14, wc.z), t * sgn,
                              [(0, 0.14), (0.08, 0.14)], "Wood", dark, sides=8, perp=up)
    return muzzles


def lantern_hunter(mb, c, k):
    """An iron cage round a glowing stone: the hunter lights its stern with etherium, not flame."""
    iron = UC("brass", 1.0)
    y = V(0, 1, 0)
    lathe(mb, c, y, [(t * k, r * k) for t, r in ((-0.42, 0.0), (-0.40, 0.10), (-0.33, 0.24), (-0.29, 0.26))], "Brass",
          iron, sides=6, perp=V(1, 0, 0), cap0=False, cap1=True)
    lathe(mb, c, y, [(t * k, r * k) for t, r in ((-0.26, 0.0), (-0.06, 0.16), (0.08, 0.16), (0.24, 0.0))],
          "EtheriumGlow", UC("glow", 0.5 * k), sides=6, perp=V(1, 0, 0), smooth=False, cap0=False, cap1=False)
    for j in range(6):
        a = 2 * math.pi * j / 6
        d = V(math.cos(a), 0, math.sin(a))
        mb.tube([c + d * (0.26 * k) + V(0, -0.29 * k, 0), c + d * (0.29 * k), c + d * (0.27 * k) + V(0, 0.21 * k, 0)],
                0.018 * k, "Brass", iron, sides=4)
    lathe(mb, c, y, [(t * k, r * k) for t, r in ((0.20, 0.0), (0.20, 0.30), (0.26, 0.30), (0.38, 0.16), (0.48, 0.06),
                                                 (0.58, 0.0))], "Brass", iron, sides=6, perp=V(1, 0, 0), cap0=False,
          cap1=False)


def build_stern_hunter(mb, lod):
    """A narrow transom: three dim stern windows in iron frames, a low black taffrail with an iron capping rail,
    and one stern lantern on an iron bracket. Returns the Stern point (top of the taffrail, centre line)."""
    S1 = sheer(1.0)
    y_t = S1 + E_QD
    xr_t, _, zr_t = transom_xyz(("r", 1.0))
    w = UC("window")
    iron = UC("brass", 2.0)
    dark = UB("dark", 2.0)
    yc = YK + H_C * (S1 - YK)
    yw0, yw1 = yc + 0.16, yc + 0.82
    for xc in (-1.05, 0.0, 1.05):
        hw = 0.25 if lod == 0 else 0.30
        cs = [transom_point(x, y) for x, y in ((xc - hw, yw0), (xc + hw, yw0), (xc + hw, yw1), (xc - hw, yw1))]
        mb.poly([p + V(0, 0, 0.035) for p in cs], [w(0, 0), w(1, 0), w(1, 1), w(0, 1)], "Wood", False, V(0, 0, 1))
        if lod:
            continue
        fw = 0.06
        for a0, a1, b0, b1 in ((xc - hw - fw, xc + hw + fw, yw1, yw1 + fw), (xc - hw - fw, xc + hw + fw, yw0 - fw, yw0),
                               (xc - hw - fw, xc - hw, yw0, yw1), (xc + hw, xc + hw + fw, yw0, yw1)):
            p = transom_point(0.5 * (a0 + a1), 0.5 * (b0 + b1))
            mb.box(p + V(0, 0, 0.05), V(0.5 * (a1 - a0), 0, 0), V(0, 0.5 * (b1 - b0), 0), V(0, 0, 0.05), "Brass", iron,
                   skip=("-z",))
        for xb in (xc - hw / 3, xc + hw / 3):
            p = transom_point(xb, 0.5 * (yw0 + yw1))
            mb.box(p + V(0, 0, 0.06), V(0.018, 0, 0), V(0, 0.5 * (yw1 - yw0), 0), V(0, 0, 0.02), "Brass", iron)
    zt = zr_t + TRANSOM_BULGE * xr_t - 0.06
    if lod:
        mb.box(V(0, y_t + 0.75, zt + 0.5), V(0.2, 0, 0), V(0, 0.3, 0), V(0, 0, 0.2), "EtheriumGlow", UC("glow"))
        return V(0, y_t + 0.2, zt)
    qs = np.linspace(-1, 1, 13)
    base, topl = [], []
    for q in qs:
        x = q * (xr_t - 0.02)
        zc = zr_t + TRANSOM_BULGE * xr_t * (1 - q * q) - 0.06
        base.append(V(x, y_t - 0.04, zc))
        topl.append(V(x, y_t + 0.22 + 0.12 * (1 - q * q), zc))
    for dz, o in ((0.06, V(0, 0, 1)), (-0.06, V(0, 0, -1))):
        cols = [[a + V(0, 0, dz), b + V(0, 0, dz)] for a, b in zip(base, topl)]
        mb.grid(cols, lambda i, j, i0, j0, cols=cols: dark(cols[i][j].x, j * 1.0), lambda i, j: "Wood", smooth=False,
                out=lambda i, j, pts, o=o: o)
    cols = [[b + V(0, 0, 0.06), b + V(0, 0, -0.06)] for b in topl]
    mb.grid(cols, lambda i, j, i0, j0: dark(cols[i][j].x, j * 1.0), lambda i, j: "Wood", smooth=False,
            out=lambda i, j, pts: V(0, 1, 0))
    mb.tube([b + V(0, 0.03, 0) for b in topl], 0.04, "Brass", UC("brass", 6.0), sides=6, cap0=True, cap1=True)
    yt = topl[len(topl) // 2].y
    mb.tube(catmull([(0, yt - 0.05, zt), (0, yt + 0.25, zt + 0.12), (0, yt + 0.42, zt + 0.45), (0, yt + 0.36, zt + 0.62)],
                    4), 0.045, "Brass", UC("brass", 2.0), sides=6, cap0=True, cap1=True)
    lantern_hunter(mb, V(0, yt + 0.70, zt + 0.62), 0.9)
    return V(0, yt + 0.07, zt)


def build_deck_fittings_hunter(mb):
    """Two hatches with gratings, fife rails at the fore and main, a capstan, a skylight on the quarterdeck."""
    dark = UB("dark", 2.0)
    grain = UB("grain", 2.0)
    for zc, hx, hz in ((-6.6, 0.70, 0.80), (3.2, 0.75, 0.90)):
        y = deck_surface_y(s_of_zn(zc), 0.0)
        mb.box(V(0, y + 0.13, zc), V(hx, 0, 0), V(0, 0.15, 0), V(0, 0, hz), "Wood", dark)
        for k in range(-3, 4):
            mb.box(V(0, y + 0.29, zc + k * hz / 3.6), V(hx - 0.04, 0, 0), V(0, 0.02, 0), V(0, 0, 0.035), "Wood", grain)
        for k in (-1, 0, 1):
            mb.box(V(k * hx * 0.6, y + 0.30, zc), V(0.03, 0, 0), V(0, 0.02, 0), V(0, 0, hz - 0.04), "Wood", grain)
    for key in ("fore", "main"):
        m = SPEC[key]["m"]
        y = deck_surface_y(s_of_zn(m.z0), 0.0)
        zm = m.at(y).z
        for x in (-0.75, 0.75):
            for z in (zm - 0.65, zm + 0.65):
                mb.box(V(x, y + 0.45, z), V(0.06, 0, 0), V(0, 0.45, 0), V(0, 0, 0.06), "Wood", dark)
            mb.box(V(x, y + 0.88, zm), V(0.07, 0, 0), V(0, 0.05, 0), V(0, 0, 0.75), "Wood", dark)
        mb.box(V(0, y + 0.88, zm - 0.65), V(0.82, 0, 0), V(0, 0.05, 0), V(0, 0, 0.07), "Wood", dark)
    zc = 5.6
    y = deck_surface_y(s_of_zn(zc), 0.0)
    lathe(mb, V(0, y, zc), V(0, 1, 0), [(0, 0.48), (0.12, 0.48), (0.16, 0.34), (0.70, 0.30), (0.74, 0.44), (0.92, 0.44),
                                        (0.96, 0.0)], "Wood", dark, sides=10, cap0=True, cap1=False)
    for k in range(6):
        a = 2 * math.pi * k / 6
        d = V(math.cos(a), 0, math.sin(a))
        mb.beam(V(0, y + 0.83, zc) + d * 0.3, V(0, y + 0.83, zc) + d * 1.2, 0.07, 0.07, V(0, 1, 0), "Wood", grain)
    zs_ = 15.8
    y = deck_surface_y(s_of_zn(zs_), 0.0, QD_UP)
    mb.box(V(0, y + 0.22, zs_), V(0.55, 0, 0), V(0, 0.22, 0), V(0, 0, 0.62), "Wood", dark, skip=("+y",))
    w = UC("window")
    for sx in (1, -1):
        quad = [V(0, y + 0.60, zs_ - 0.6), V(0, y + 0.60, zs_ + 0.6), V(sx * 0.55, y + 0.44, zs_ + 0.6),
                V(sx * 0.55, y + 0.44, zs_ - 0.6)]
        mb.poly(quad, [w(0, 0), w(1, 0), w(1, 1), w(0, 1)], "Wood", False, V(sx * 0.4, 1, 0))
    for zz in (zs_ - 0.62, zs_ + 0.62):
        tri = [V(0.55, y + 0.44, zz), V(-0.55, y + 0.44, zz), V(0, y + 0.60, zz)]
        mb.poly(tri, [dark(0, 0), dark(1, 0), dark(0.5, 1)], "Wood", False, V(0, 0, zz - zs_))


def build_hull_hunter(name, lod):
    mb = MB(name)
    st = build_hull_shell(mb, lod)
    build_bulwarks(mb, st, lod)
    build_decks(mb, st, lod)
    build_keel_stem(mb, lod)
    muzzles = build_gunports_hunter(mb, lod)
    stern = build_stern_hunter(mb, lod)
    crystal = build_keel_crystal(mb, lod)
    beak = build_beak(mb, lod)
    info = {"crystal": crystal, "stern": stern, "beak": beak, "muzzles": muzzles}
    if lod == 0:
        build_wale(mb, st)
        build_bow_hunter(mb)
        build_channels(mb)
        build_deck_fittings_hunter(mb)
        info["helm"] = build_wheel(mb)
    return mb, info


# --------------------------------------------------------------------------
# Hunter: masts, spars, rigging, sails
# --------------------------------------------------------------------------
def h_yard(mast, nm):
    """Centre (braced round with its mast), half length and radius of one of the hunter's yards."""
    y, which, dz, L, r = H_YARDS[(mast, nm)]
    sp = SPEC[mast]
    off = {"low": 0.0, "tm": sp["tm"][0], "tg": sp["tg"][0] if sp["tg"] else 0.0}[which]
    return sp["m"].at(y, off) + braced(V(0, 0, dz)), L, r


def gaff_geo_hunter():
    """The spanker's gaff jaw and peak, the boom's gooseneck and end (past the taffrail), swung out to port about the
    mizzen; the boom clears the wheel and the helmsman."""
    Z = MIZZEN
    jaw = Z.at(11.5) + swung(V(0, 0, 0.30))
    a = math.radians(38.0)
    peak = jaw + swung(V(0, math.sin(a), math.cos(a))) * 7.0
    m0 = Z.at(6.9)
    goose = m0 + swung(V(0, 0, 0.30))
    z_end = 20.6
    y_end = sheer(1.0) + E_QD + 2.1
    bend = m0 + swung(V(0, y_end - m0.y, z_end - m0.z))
    return jaw, peak, goose, bend


def build_rig_hunter(name, lod, mb=None):
    mb = mb or MB(name)
    grain = UB("grain", 4.0)
    tar = UB("tar", 3.0, (0, 4))
    dark = UB("dark", 2.0)
    sides = 12 if lod == 0 else 5
    pts = {}
    for key, sp in SPEC.items():
        build_mast(mb, key, sp, lod, pts, sides, grain, tar, dark)
    ysides = 10 if lod == 0 else 4
    for key in H_YARDS:
        c, L, r = h_yard(*key)
        xs = [-L - 0.3, -L, -0.6 * L, 0.0, 0.6 * L, L, L + 0.3]
        rs = [r * 0.35, r * 0.45, r * 0.8, r, r * 0.8, r * 0.45, r * 0.35]
        mb.tube([c + E_YARD * x for x in xs], rs, "Wood", grain, sides=ysides, cap0=True, cap1=True)
        pts["yard_%s_%s" % key] = (c, L, r)
        if lod == 0:
            mb.box(c - E_FWD * 0.25, E_YARD * 0.25, V(0, 0.12, 0), E_FWD * 0.18, "Tar", tar)
    jaw, peak, goose, bend = gaff_geo_hunter()
    mb.tube([jaw, peak], [0.14, 0.08], "Wood", grain, sides=ysides, cap0=True, cap1=True)
    mb.tube([goose, lerp(goose, bend, 0.6), bend], [0.16, 0.18, 0.12], "Wood", grain, sides=ysides, cap0=True, cap1=True)
    if lod == 0:
        for p, q, y in ((jaw, peak, 11.5), (goose, bend, 6.9)):
            d = (q - p).normalized()
            for sx in (-1, 1):
                a = MIZZEN.at(y) + swung(V(sx * 0.22, 0, -0.05))
                mb.beam(a, a + d * 0.45, 0.07, 0.2, V(0, 1, 0), "Wood", dark)
    bg = bowsprit_geo()
    mb.tube([bg["heel"], bg["head"], bg["cap"]], [0.30, 0.28, 0.18], "Wood", grain, sides=sides, cap0=True, cap1=True)
    mb.tube([bg["jb0"], bg["jb1"]], [0.14, 0.06], "Wood", grain, sides=max(sides - 4, 5), cap0=True, cap1=True)
    mb.beam(bg["cap"] + bg["perp"] * 0.18 + bg["d"] * 0.1, bg["cap"] + bg["perp"] * 0.18 - bg["d"] * 0.15, 0.75, 0.4,
            V(1, 0, 0), "Tar", tar)
    striker0 = bg["cap"] - bg["perp"] * 0.15
    striker1 = bg["cap"] - bg["perp"] * 1.6 + bg["d"] * 0.15
    mb.tube([striker0, striker1], 0.06, "Wood", dark, sides=5, cap1=True)
    pts["striker"] = striker1
    rig_lines_hunter(mb, pts, bg, lod)
    return mb, pts


def rig_lines_hunter(mb, pts, bg, lod):
    R_STAY, R_SHROUD, R_RUN = (0.05, 0.035, 0.022) if lod == 0 else (0.09, 0.07, 0.05)
    sides = 5 if lod == 0 else 3
    T = "Tar"
    L = lambda a, b, r=R_STAY: mb.line(a, b, r, T, sides=sides)   # noqa: E731
    F, M, Z = FORE, MAIN, MIZZEN
    sf, sm, sz = SPEC["fore"], SPEC["main"], SPEC["mizzen"]
    # stays: fore to the bowsprit and jib-boom, main to the fore, mizzen to the main
    L(pts["fore_mh"] + V(0, 0, -0.3), bg["head"] + bg["d"] * 1.55)
    L(pts["fore_tm_head"], bg["cap"] + bg["perp"] * 0.2)
    L(pts["fore_tg_head"], bg["jb1"] - bg["d"] * 0.2)
    L(pts["main_mh"] + V(0, 0, -0.3), F.at(5.6, 0.3))
    L(pts["main_tm_head"], F.at(sf["cap"] - 0.2, 0.25))
    L(pts["main_tg_head"], pts["fore_tm_head"] + V(0, -0.5, 0.2))
    L(pts["mizzen_mh"] + V(0, 0, -0.25), M.at(6.4, 0.3))
    L(pts["mizzen_tm_head"], M.at(sm["cap"] - 0.2, 0.25))
    if lod:
        return

    def stem(y):
        return V(0, y, zb((y - YK) / (sheer(0.0) - YK)) - 0.1)
    L(bg["cap"] - bg["perp"] * 0.1, stem(3.3))                          # bobstay
    L(bg["jb1"] - bg["d"] * 0.2, pts["striker"], R_SHROUD)               # martingale
    L(pts["striker"], stem(4.3), R_SHROUD)
    dark = UB("dark", 1.0)
    back = {"fore": (0.25, 0.6), "main": (-0.1, -0.5), "mizzen": (1.8, None)}   # backstays: past the channel's end
    for key, (z0, z1, dzs) in CHANNELS.items():
        sp = SPEC[key]
        m = sp["m"]
        for side in (1, -1):
            uppers = []
            for z in dzs:
                _, p, n = channel_point(z, side)
                lo_c = p + n * 0.52 + V(0, 0.08, 0)
                head = m.at(sp["top"] - 0.35) + V(side * 0.24, 0, 0)
                d = (head - lo_c).normalized()
                up_c = lo_c + d * 0.62
                for cc in (lo_c, up_c):
                    lathe(mb, cc - n * 0.05, n, [(0, 0.0), (0.0, 0.13), (0.1, 0.13), (0.1, 0.0)], "Wood", dark,
                          sides=8, perp=d)
                mb.line(lo_c + d * 0.1, up_c - d * 0.1, 0.018, "Wood", sides=4)
                L(up_c + d * 0.1, head, R_SHROUD)
                uppers.append((up_c + d * 0.1, head))
            ya, yb = uppers[0][0].y + 0.45, uppers[0][1].y - 1.6
            y = ya
            while y < yb:
                ends = []
                for a, b in (uppers[0], uppers[-1]):
                    t = (y - a.y) / (b.y - a.y)
                    ends.append(lerp(a, b, t))
                mb.line(ends[0], ends[1], 0.014, T, sides=3)
                y += 0.42
            th = pts[key + "_tm_head"] + V(side * 0.12, -0.3, 0)
            for zo in (-0.45, 0.1, 0.6):
                L(m.at(sp["top"] + 0.1, zo) + V(side * (sp["top_w"] - 0.1), 0, 0), th, R_SHROUD * 0.8)
            b_tm, b_tg = back[key]
            _, p, n = channel_point(z1 + b_tm, side)
            L(pts[key + "_tm_head"] + V(side * 0.1, 0.1, 0.1), p + n * 0.5, R_SHROUD * 0.9)
            if sp["tg"] and b_tg is not None:
                _, p, n = channel_point(z1 + b_tg, side)
                L(pts[key + "_tg_head"] + V(side * 0.08, 0, 0.1), p + n * 0.45, R_SHROUD * 0.7)
            for zo in (-0.45, 0.1, 0.6):
                L(m.at(sp["top"], zo) + V(side * (sp["top_w"] - 0.1), 0, 0), m.at(sp["top"] - 2.0) + V(side * 0.3, 0, 0),
                  R_SHROUD * 0.6)
    # lifts up to the mast above; braces aft to the next mast (the mizzen's forward to the main)
    H = "Wood"
    lift_to = {("fore", "course"): pts["fore_mh"] + V(0, 1.4, 0), ("fore", "topsail"): pts["fore_tm_head"],
               ("fore", "topgallant"): pts["fore_tg_head"] + V(0, 0.6, 0),
               ("main", "course"): pts["main_mh"] + V(0, 1.4, 0), ("main", "topsail"): pts["main_tm_head"],
               ("main", "topgallant"): pts["main_tg_head"] + V(0, 0.6, 0),
               ("mizzen", "crossjack"): pts["mizzen_mh"] + V(0, 1.2, 0), ("mizzen", "topsail"): pts["mizzen_tm_head"]}
    brace_to = {("fore", "course"): M.at(10.5), ("fore", "topsail"): M.at(sm["top"] + 0.4, 0.4),
                ("fore", "topgallant"): pts["main_tm_head"],
                ("main", "course"): Z.at(9.2), ("main", "topsail"): Z.at(16.8, sz["tm"][0] + 0.25),   # over the fan
                ("main", "topgallant"): pts["mizzen_tm_head"],
                ("mizzen", "crossjack"): M.at(8.2), ("mizzen", "topsail"): M.at(11.2)}
    for key in H_YARDS:
        c, Lh, r = pts["yard_%s_%s" % key]
        for side in (1, -1):
            arm = c + E_YARD * (side * (Lh - 0.1))
            mb.line(arm, lift_to[key] + E_YARD * (side * 0.15), R_RUN, H, sides=4)
            mb.line(arm, brace_to[key] + V(side * 0.3, 0, 0), R_RUN, H, sides=4)
    jaw, peak, goose, bend = gaff_geo_hunter()
    for t in (0.45, 0.95):
        mb.line(lerp(jaw, peak, t), Z.at(sz["cap"] - 0.3, -0.1), R_RUN, H, sides=4)
    rail = ("r", 1.0)
    p_v = hp(s_at(17.0, rail), rail)
    for side in (1, -1):
        mb.line(peak, V(side * (p_v.x - 0.1), p_v.y + 0.05, p_v.z), R_RUN, H, sides=4)          # vangs
    p_t = hp(s_at(17.4, rail), rail)
    mb.line(bend, V(-(p_t.x - 0.25), p_t.y + 0.05, p_t.z), R_RUN * 1.4, H, sides=4)          # sheet, lee quarter


def build_sails_hunter(name, lod, mb=None):
    mb = mb or MB(name)
    _CANVAS_U0[0] = 0.0                        # the far mesh's sails start where the near ones do
    nu, nv = (16, 12) if lod == 0 else (4, 3)
    rope = lod == 0
    for mast, names in H_SQUARE.items():
        for k, nm in enumerate(names):
            if nm == "crossjack":
                continue
            c, L, r = h_yard(mast, nm)
            hl, hr = c + E_YARD * -(L - 0.25) + V(0, -r - 0.05, 0), c + E_YARD * (L - 0.25) + V(0, -r - 0.05, 0)
            if nm == "course":
                cx, cy = H_CLEWS[mast]
                cl, cr = (c + braced(V(sx * cx, 0, 0.5)) for sx in (-1, 1))
                cl.y = cr.y = cy
                depth, roach = 1.35, 0.55
            else:
                lc, Ll, rl = h_yard(mast, names[k - 1])
                cl, cr = lc + E_YARD * -(Ll - 0.35) + V(0, r * 0.3, 0), lc + E_YARD * (Ll - 0.35) + V(0, r * 0.3, 0)
                depth, roach = (1.05, 0.25) if nm == "topsail" else (0.7, 0.18)
                if mast == "mizzen":
                    depth, roach = 0.8, 0.2
            square_sail(mb, hl, hr, cl, cr, depth, nu, nv, roach, fwd=E_FWD, rope=rope)
    # the spanker, bellied out to leeward (port)
    jaw, peak, goose, bend = gaff_geo_hunter()
    lee = swung(V(-1, 0, 0))
    fore_aft_sail(mb, goose + swung(V(0, 0.35, 0.25)), jaw + swung(V(0, -0.2, 0.25)), peak + swung(V(0, -0.15, -0.35)),
                  bend + swung(V(0, 0.18, -0.35)), 0.9, nu, nv, lee, rope)
    # headsails on the fore stays, sheeted to port
    port = V(-1, 0, 0)
    bg = bowsprit_geo()
    sf = SPEC["fore"]
    fmh = FORE.at(sf["top"] - 0.6, -0.3)
    stay_lo = bg["head"] + bg["d"] * 1.55

    def clew_of(t, dy, dz):
        return t + V(-dz * math.sin(HEAD_SWING), dy, dz * math.cos(HEAD_SWING))
    t0, h0 = lerp(stay_lo, fmh, 0.06), lerp(stay_lo, fmh, 0.66)
    head_sail(mb, t0, h0, clew_of(t0, 0.8, 4.4), 0.5, max(nu // 2, 3), nv, port, rope)
    tm_head = FORE.at(sf["xt"] + 0.9, sf["tm"][0])
    cap = bg["cap"] + bg["perp"] * 0.2
    t1, h1 = lerp(cap, tm_head, 0.05), lerp(cap, tm_head, 0.70)
    head_sail(mb, t1, h1, clew_of(t1, 1.6, 5.4), 0.65, max(nu // 2, 3), nv, port, rope)
    tg_head = FORE.at(sf["tg"][2] - 0.9, sf["tg"][0])
    jb = bg["jb1"] - bg["d"] * 0.2
    t2, h2 = lerp(jb, tg_head, 0.06), lerp(jb, tg_head, 0.62)
    head_sail(mb, t2, h2, clew_of(t2, 4.3, 7.8), 0.6, max(nu // 2, 3), nv, port, rope)
    return mb


# --------------------------------------------------------------------------
# Hunter: fans and keel-wings
# --------------------------------------------------------------------------
def fan_ribs_hunter(key, side, lod=0):
    """[(direction, length)]: five ribs swept back from near abeam to past dead aft, the leading rib longest."""
    hub0, L, n, phis = FANS[key]
    if lod:
        n = 3
    e_out, e_aft, n_dn = fan_frame(side)
    ribs = []
    for k in range(n):
        f = k / (n - 1)
        phi = math.radians(lerp(phis[0], phis[1], f))
        d = (e_out * math.cos(phi) + e_aft * math.sin(phi)).normalized()
        d = (d - n_dn * math.tan(FAN_CUP * math.sin(math.pi * f))).normalized()
        ribs.append((d, L * (1.0 - 0.58 * f ** 1.1)))
    return ribs


def build_fan_hunter(mb, key, side, lod):
    """A swept fan like a bat's wing: blackened iron ribs run out past the edge into spikes, smoky membranes
    between them, the edge scalloped in between the ribs; glow strips along both faces of every rib and a glow line
    along the scalloped edge (EtheriumGlow). The far mesh draws the ribs as lines of glow."""
    hub = fan_hub(key, side)
    ribs = fan_ribs_hunter(key, side, lod)
    n = len(ribs)
    _, _, n_dn = fan_frame(side)
    up = -n_dn
    r_in = 0.40
    for k, (d, length) in enumerate(ribs):
        r0 = 0.11 if k == 0 else 0.085
        a, b = hub + d * 0.2, hub + d * length
        tip = hub + d * (length + H_FAN_SPIKE)
        if lod:
            mb.tube([a, tip], [r0 * 1.3, 0.0], "EtheriumGlow", UC("glow", 1.0), sides=3, cap0=True)
            continue
        mb.tube([a, lerp(a, b, 0.5), b, tip], [r0, r0 * 0.75, r0 * 0.5, 0.0], "Brass", UC("brass", length), sides=6,
                cap0=True)
        for face in (n_dn, up):
            gp = [hub + d * (t * length) + face * (r0 * s + 0.012) for t, s in ((0.12, 0.95), (0.55, 0.72), (0.97, 0.5))]
            mb.tube(gp, [0.045, 0.04, 0.03], "EtheriumGlow", UC("glow", 1.0), sides=4, cap0=True, cap1=True)
    nr, nc = (6, 4) if lod == 0 else (1, 2)
    eu = UC("ether", 1.0)
    edge = []
    for k in range(n - 1):
        (d0, l0), (d1, l1) = ribs[k], ribs[k + 1]
        P = []
        for ic in range(nc + 1):
            c = ic / nc
            dd = lerp(d0, d1, c).normalized()
            lc = lerp(l0, l1, c) * (1.0 - H_FAN_SCALLOP * 4 * c * (1 - c))
            col = []
            for ir in range(nr + 1):
                r = ir / nr
                p = hub + dd * lerp(r_in, lc, r)
                p = p + up * (0.16 * math.sin(math.pi * c) * math.sin(math.pi * r) * (l0 / 7.0))
                col.append(p)
            P.append(col)
            if lod == 0 and (k == 0 or ic > 0):
                edge.append(col[-1])
        mb.grid(P, lambda i, j, i0, j0: eu(j / nr, i / nc), lambda i, j: "EtheriumGlow", smooth=True,
                out=lambda i, j, pts: n_dn)
    if lod:
        return
    mb.tube(edge, 0.03, "EtheriumGlow", UC("glow", 1.0), sides=4, cap0=True, cap1=True)
    lathe(mb, hub + up * 0.16, n_dn, [(0, 0.0), (0.0, 0.26), (0.14, 0.33), (0.28, 0.20), (0.36, 0.0)], "Brass",
          UC("brass", 0.5), sides=10)
    lathe(mb, hub + n_dn * 0.16, n_dn, [(0, 0.13), (0.06, 0.13), (0.12, 0.0)], "EtheriumGlow", UC("glow", 0.2), sides=8)
    m = SPEC[key]["m"]
    root = m.at(hub.y - 0.15) + V(side * 0.2, 0, 0.1)
    mb.tube([root, hub + up * 0.05], 0.07, "Brass", UC("brass", 1.5), sides=6, cap0=True, cap1=True)
    mb.tube([root + V(0, -1.0, 0), hub + V(0, -0.15, 0)], 0.05, "Brass", UC("brass", 1.5), sides=6, cap0=True,
            cap1=True)


def build_wingsails_hunter(name, lod, mb=None):
    mb = mb or MB(name)
    for key in FANS:
        for side in (1, -1):
            build_fan_hunter(mb, key, side, lod)
    for side in (1, -1):
        keel_wing(mb, side, lod)
    return mb


def build_hunter():
    make_materials()
    hull_mb, info = build_hull_hunter("Hull", 0)
    rig_mb, pts = build_rig_hunter("Rig", 0)
    sails_mb = build_sails_hunter("Sails", 0)
    wings_mb = build_wingsails_hunter("WingSails", 0)
    objs = [hull_mb.obj(), rig_mb.obj(), sails_mb.obj(), wings_mb.obj()]
    lod_mb, _ = build_hull_hunter("Galleon_LOD1", 1)
    build_rig_hunter("Galleon_LOD1", 1, lod_mb)
    build_sails_hunter("Galleon_LOD1", 1, lod_mb)
    build_wingsails_hunter("Galleon_LOD1", 1, lod_mb)
    objs.append(lod_mb.obj())
    s_deck = s_of_zn(-2.6)
    empties = [
        add_empty("Helm", info["helm"]),
        add_empty("Deck", V(0, deck_surface_y(s_deck, 0.0), -2.6)),
        add_empty("Bow", V(0, sheer(0.0), Z_BOW_TOP)),
        add_empty("Stern", info["stern"]),
        add_empty("KeelGlow", info["crystal"]),
        add_empty("Beak", info["beak"]),
    ]
    for side, k, rc, n in info["muzzles"]:
        empties.append(add_empty("Muzzle_%s%d" % ("S" if side > 0 else "P", k + 1), rc))
    return objs, empties


def render_previews_hunter(out_dir, near_objs, lod_obj, galleon_glb=None, only=None):
    """Night look-dev of the hunter: side, front 3/4 and below; from the camp 300 m off at the game's field of view
    (and magnified); beside the galleon at 300 m; against a stand-in for the wonder sky; the far mesh at 450 m.
    The only light is the keel light (the game's budget: one shared light); the moon is a dim sun."""
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.eevee.taa_render_samples = 24
    sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    sc.render.film_transparent = False
    night = make_world("HunterNight", [(0.0, (0.004, 0.005, 0.008)), (0.47, (0.010, 0.012, 0.020)),
                                       (0.5, (0.035, 0.042, 0.070)), (0.58, (0.022, 0.028, 0.055)),
                                       (1.0, (0.006, 0.009, 0.026))], 1.0)
    wonder = make_world("HunterWonder", [(0.0, (0.004, 0.005, 0.008)), (0.47, (0.012, 0.014, 0.024)),
                                         (0.5, (0.10, 0.08, 0.16)), (0.58, (0.16, 0.10, 0.34)), (0.70, (0.06, 0.16, 0.20)),
                                         (0.85, (0.10, 0.06, 0.22)), (1.0, (0.03, 0.03, 0.10))], 1.0)
    day = make_world("HunterDay", [(0.0, (0.16, 0.22, 0.13)), (0.40, (0.30, 0.38, 0.30)), (0.5, (0.70, 0.80, 0.92)),
                                   (0.66, (0.24, 0.44, 0.82)), (1.0, (0.10, 0.24, 0.62))], 1.0)
    sun_d = bpy.data.lights.new("Moon", "SUN")
    sun = bpy.data.objects.new("Moon", sun_d)
    sc.collection.objects.link(sun)
    sun_d.angle = math.radians(1.0)
    sun_d.energy, sun_d.color = 0.45, (0.62, 0.72, 1.0)
    for o in near_objs:
        if o.name == "WingSails":
            o.visible_shadow = False
    try:
        MATS["EtheriumGlow"].use_transparent_shadow = False
    except AttributeError:
        pass
    ld = bpy.data.lights.new("KeelLight", "POINT")
    ld.color, ld.energy, ld.shadow_soft_size = ETHER["glow_rgb"], POD_LIGHT[1], 0.6
    keel_light = bpy.data.objects.new("KeelLight", ld)
    keel_light.location = G(CRYSTAL_C + POD_LIGHT[0])
    sc.collection.objects.link(keel_light)
    ref = []
    if galleon_glb and os.path.exists(galleon_glb):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=galleon_glb)
        ref = [o for o in bpy.data.objects if o not in before]
        root = bpy.data.objects.new("GalleonRef", None)
        sc.collection.objects.link(root)
        for o in ref:
            if o.parent is None:
                o.parent = root
            if o.name.startswith("Galleon_LOD1"):
                o.hide_render = True
            if o.name.startswith("WingSails"):
                o.visible_shadow = False
        # the galleon 100 m to the hunter's left as the camp sees them (as far from the camp), 8 m lower, turning
        root.location = G(DUEL_AT)
        root.rotation_euler = (0.0, 0.0, math.radians(20.0))
        gl = bpy.data.lights.new("GalleonKeel", "POINT")
        gl.color, gl.energy, gl.shadow_soft_size = (1.0, 0.62, 0.22), 1500.0, 0.6
        glo = bpy.data.objects.new("GalleonKeel", gl)
        glo.parent = root
        glo.location = G(V(0, -1.45 + 1.2, -0.4))
        sc.collection.objects.link(glo)
        ref += [root, glo]
    cd = bpy.data.cameras.new("Cam")
    cd.clip_start, cd.clip_end = 0.1, 2000.0
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    mid = V(0, 12.0, 0.0)
    camp = mid + V(0.55, -0.40, -0.73).normalized() * 300.0       # the camp: 300 m off, 24 deg below the ship
    duel_mid = (mid + DUEL_AT + V(0, 12.0, 0)) * 0.5
    duel_cam = duel_mid + V(0.55, -0.40, -0.73).normalized() * 300.0
    far = mid + V(0.55, -0.40, -0.73).normalized() * 450.0
    GAME = 20.5      # the player's 52.5 deg vertical field of view at 16:9, as a lens on a 36 mm sensor
    shots = [
        # name, camera, target, lens, world, resolution, far mesh only, with the galleon
        ("side_night", V(84, 8, -1.5), V(0, 12, -1.5), 32, night, (1280, 720), False, False),
        ("front3q_night", V(48, -16, -66), V(0, 11, -3), 32, night, (1280, 720), False, False),
        ("below_night", V(26, -50, 14), V(0, 9, -1), 26, night, (1280, 720), False, False),
        ("camp_300m_night", camp, mid, GAME, night, (1920, 1080), False, False),
        ("camp_300m_night_x5", camp, mid, GAME * 5, night, (1280, 720), False, False),
        ("camp_300m_wonder_x5", camp, mid, GAME * 5, wonder, (1280, 720), False, False),
        ("duel_300m_night", duel_cam, duel_mid, GAME, night, (1920, 1080), False, True),
        ("duel_300m_night_x3", duel_cam, duel_mid, GAME * 3, night, (1280, 720), False, True),
        ("lod1_450m_night_x5", far, mid, GAME * 5, night, (1280, 720), True, False),
        # by day, to check the build (the strake, the ports and wind rings, the beak, the patched canvas)
        ("check_side_day", V(70, 9, -2), V(0, 10, -2), 35, day, (1280, 720), False, False),
        ("check_bow_day", V(14, 3.5, -30), V(0, 3.0, -16.5), 35, day, (1280, 720), False, False),
        ("check_stern_day", V(-12, 9, 34), V(0, 5.0, 16.5), 35, day, (1280, 720), False, False),
        ("check_below_day", V(18, -40, 6), V(0, 6.0, -1.0), 30, day, (1280, 720), False, False),
    ]
    if only:
        shots = [sh for sh in shots if sh[0] in only]
    for name, loc, tgt, lens, world, res, lod, duel in shots:
        if duel and not ref:
            continue
        lod_obj.hide_render = not lod
        for o in near_objs:
            o.hide_render = lod
        for o in ref:
            if not o.name.startswith("Galleon_LOD1"):
                o.hide_render = not duel
        sc.world = world
        sc.render.resolution_x, sc.render.resolution_y = res
        cd.lens = lens
        look(cam, loc, tgt)
        is_day = world is day
        sun.rotation_euler = (-G((V(0.55, 0.75, -0.35) if is_day else V(0.35, 0.65, -0.65)).normalized())
                              ).to_track_quat("-Z", "Y").to_euler()
        sun_d.energy, sun_d.color = (3.2, (1.0, 0.95, 0.88)) if is_day else (0.45, (0.62, 0.72, 1.0))
        keel_light.hide_render = is_day
        setup_compositor(sc, not is_day)
        sc.render.filepath = os.path.join(out_dir, "hunter_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", default="galleon", choices=("galleon", "hunter"),
                    help="galleon (the brigantine) or hunter (the enemy sloop-of-war of Two Fires)")
    ap.add_argument("--out", default=None, help="default assets/sky/sky_galleon.glb or assets/sky/sky_hunter.glb")
    ap.add_argument("--renders", default=None)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--only", default=None, help="comma list of shot names to render")
    ap.add_argument("--diag", default=None, help="render close-up check shots here instead (galleon)")
    ap.add_argument("--atlas-png", default=None, help="also write the atlas and emission mask as PNGs here (a folder)")
    ap.add_argument("--galleon-glb", default=os.path.join(PROJECT, "assets", "sky", "sky_galleon.glb"),
                    help="hunter renders: the galleon to set beside it in the duel shots")
    args = ap.parse_args(argv)
    hunter = args.variant == "hunter"
    if hunter:
        use_hunter()
    out = args.out or os.path.join(PROJECT, "assets", "sky", "sky_hunter.glb" if hunter else "sky_galleon.glb")
    tag = "HUNTER" if hunter else "GALLEON"
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    objs, empties = build_hunter() if hunter else build_ship()
    near = 0
    for o in objs:
        t = tri_count(o)
        if o.name != "Galleon_LOD1":
            near += t
        elif t >= 3000:
            print("%s Galleon_LOD1 OVER BUDGET (3000)" % tag)
        print("%s %-13s tris=%6d verts=%6d mats=%s" % (tag, o.name, t, len(o.data.vertices),
                                                        [m.name for m in o.data.materials]))
    print("%s near total tris" % tag, near)
    for o in objs:
        B = np.array([v.co[:] for v in o.data.vertices])
        P = np.stack([B[:, 0], B[:, 2], -B[:, 1]], axis=1)
        print("%s bbox %-13s x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f" % (
            tag, o.name, P[:, 0].min(), P[:, 0].max(), P[:, 1].min(), P[:, 1].max(), P[:, 2].min(), P[:, 2].max()))
    fan_clashes(objs)
    for e in empties:
        g = Vector((e.location.x, e.location.z, -e.location.y))
        print("%s empty %-8s godot=(%.3f, %.3f, %.3f)" % (tag, e.name, g.x, g.y, g.z))
    if args.atlas_png:
        os.makedirs(args.atlas_png, exist_ok=True)
        for nm in ATLAS_NAMES:
            im = bpy.data.images[nm]
            im.save(filepath=os.path.join(args.atlas_png, nm + ".png"))
    export_glb(objs + empties, out)
    print("EXPORTED", out)
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    if args.renders:
        only = args.only.split(",") if args.only else None
        if hunter:
            render_previews_hunter(args.renders, objs[:4], objs[4], args.galleon_glb, only)
        else:
            render_previews(args.renders, objs[:4], objs[4], args.diag, only)


if __name__ == "__main__":
    main()
