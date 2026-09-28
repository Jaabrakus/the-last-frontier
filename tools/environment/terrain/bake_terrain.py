#!/usr/bin/env python3
"""Bake the Frontier terrain data (look-dev spec, sections 5.1-5.5 and 6). Package B.

Deterministic and re-runnable (numpy only, fixed seeds). Writes raw little-endian arrays and
preview PNGs to tools/environment/terrain/build/ (ignored by Godot); then run

    Godot --headless --path . -s tools/environment/terrain/pack_terrain.gd

which turns them into the Image resources the game loads (assets/environment/terrain/*.res).

The world's squares (user 2026-09-27: "add another square map thats open planes with a river to a lake", "should we
do procedure land?" -> procedural by recipe from one world seed, baked): every value is a function of the WORLD
position, so squares baked one at a time meet without a seam. data/world/squares.json lays out the 3 x 3 grid of
SQUARE_M squares and their types; a square's recipe (woods: the fort map's rolling ground and forest; open land and
fields: long swells, few trees, tall grass) blends into its neighbour's over TYPE_BLEND m either side of the border.
The fort map's own features (the ridge, the hill, the brook's draw, the outcrops, paths, glades, the fort) stay where
they are. The outer rim (the ground rising 10-40 m so the edge is never seen) runs only along the edges of the BUILT
squares (types marked "built") that face an unbuilt one. The river runs north-south through the squares east of the
fort (river_x), its bed cut to a water level falling along it (water_level), through the rim where it leaves the
built land. Each square is baked with MARGIN samples past its edges (cropped), so its normals, occlusion and blurs
match its neighbour's at the seam.

    python3 tools/environment/terrain/bake_terrain.py [--square X,Y] [--built X,Y;X,Y]

--square: the square to bake (default 0,0, the fort's: build/; others build/sq_X_Y/, after the fort's, whose dry-grass
threshold they share). --built: which squares count as built (default: squares.json), e.g. --built 0,0 bakes the fort
map exactly as it was before there were squares.

Grid: N x N samples at 1 m, world x = i - HALF, z = j - HALF (row j = z), HALF = 416, so
13 x 13 chunks of 64 m (65 x 65 samples each, a power of two plus one, which Jolt's height
field wants). The playable world is +-400 m (FrontierTerrain.WORLD_HALF); the bake covers
+-416 so the outer bowl rises past the edge.

Outputs (float32 unless noted), all N x N:
  height.bin        rendered height (m); exactly 0 in the flat zones
  collision.bin     TerrainBody heights: height - 0.05 on flat-zone samples (the GroundFloor
                    box wins there), identical elsewhere
  splat0.bin  u8x4  grass, dry grass, dirt, mud               (weights, sum with splat1.rg = 1)
  splat1.bin  u8x4  forest floor, rock, forest_density, grass height (x 0.8 m)
  normal.bin  u8x4  normal x, normal z (x0.5+0.5), ambient occlusion, broadleaf litter share
  core.bin    u8x4  0.25 m detail map over CORE_RECT: mud, wear, dirt, grass height (x 0.8 m)
  macro.bin   u8x4  256 x 256 tileable noise (periods 1/2, 1/4, 1/16, 1/64 of the tile)
  bounds.bin        13 x 13 x 2 chunk min/max height
  overlay_dirt.bin / overlay_stone.bin  int32 cell indices (j * N + i) for the surface
                    overlay colliders (paths and brook bed = dirt, rock = stone)
  grass_cells.bin u8 104 x 104: per 8 m grass cell (x in [8i - 416, 8i - 408)), the maximum
                    local grass density (0..1, same formula as grass.gdshader); 0 = no grass
  meta.json
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "build")

HALF = 416
N = 2 * HALF + 1
CHUNK = 64

# The world's squares.
SQUARE_M = 2 * HALF          # a square's side: its grid shares its edge samples with its neighbour's
MARGIN = 64                  # samples baked past every edge and cropped (AO reaches 48 m, the widest blur 36 m)
TYPE_BLEND = 100.0           # m either side of a border over which two squares' recipes blend
OPEN_TYPES = ("open_land", "field_land", "lake")    # grassland recipes: long swells, few trees, tall grass
SQUARES_JSON = os.path.join(HERE, "..", "..", "..", "data", "world", "squares.json")

# Flat zones: keep identical to FrontierTerrain (scripts/world/terrain/terrain.gd).
FORT_FLAT_HALF = 26.0
LANE_FLAT_HALF_X = 14.0
LANE_FLAT_Z_MIN = -175.0
LANE_FLAT_Z_MAX = -12.0
BLEND_WIDTH = 24.0

# Palisade (frontier_level.gd): logs on the |x| or |z| = 16 square, radius 0.19.
WALL_IN = 15.81
WALL_OUT = 16.19
GATE_HALF = 3.0

# 0.25 m detail map over the fort, its clearing and the range lane.
CORE_X0, CORE_Z0 = -32.0, -184.0
CORE_W, CORE_D = 64.0, 216.0
CORE_RES = 0.25

GRASS_H_SCALE = 0.8   # grass height channel: value 1 = 0.8 m

SUN_XZ = np.array([-0.6384, 0.6967])
SUN_XZ = SUN_XZ / np.linalg.norm(SUN_XZ)

# Trampled paths outside the fort (x, z) and their widths (m).
PATHS = [
    # East path: from the firing line round the east side of the fort into the forest.
    ([(3.5, -21.0), (12.0, -22.6), (20.5, -19.5), (24.6, -9.0), (25.8, 3.0), (30.5, 12.5),
      (44.0, 23.0), (70.0, 33.0), (100.0, 51.0), (130.0, 64.0), (160.0, 77.0), (192.0, 84.0)], 1.3),
    # Woodcutters' track west toward the ridge (cart track, wider).
    ([(-3.5, -21.0), (-12.0, -22.6), (-22.0, -21.2), (-31.0, -17.0), (-45.0, -12.5),
      (-70.0, -10.0), (-100.0, -18.0), (-130.0, -30.0), (-160.0, -44.0), (-188.0, -50.0)], 1.8),
    # Hunters' trail south from the east path, round the south-east blockhouse.
    ([(30.5, 12.5), (27.5, 26.0), (15.0, 33.5), (-5.0, 40.5), (-24.0, 55.0), (-38.0, 84.0),
      (-48.0, 128.0), (-56.0, 170.0)], 1.0),
]

# Worn paths inside the fort (gate -> cabin door, storehouse, ramps, flag).
FORT_PATHS = [
    ([(0.0, -17.5), (0.0, -9.0), (-1.5, -2.0), (-3.0, 5.0), (-4.5, 10.5), (-8.0, 11.3)], 1.6),
    ([(0.0, -9.0), (3.0, -4.0), (5.8, 1.5), (6.1, 4.0)], 1.3),
    ([(0.0, -12.0), (7.0, -9.8), (14.0, -8.4)], 1.1),
    ([(0.0, -12.0), (-7.0, -9.8), (-12.0, -8.4)], 1.1),
    ([(-1.5, -2.0), (-4.9, -2.2)], 1.0),
    ([(0.0, 2.0), (-3.0, 5.0)], 0.9),
]

# Meadow glades inside the forest (x, z, radius).
GLADES = [(-95.0, 55.0, 16.0), (85.0, -95.0, 13.0), (70.0, 105.0, 18.0), (-80.0, -150.0, 12.0),
          (-118.0, 172.0, 15.0), (128.0, -30.0, 14.0), (-105.0, -100.0, 10.0)]

# Rock outcrops (x, z, radius, height).
RIDGE_A = np.array([-170.0, 120.0])
RIDGE_B = np.array([-230.0, -260.0])
OUTCROPS = []
for t, off, r, h in [(0.10, 6, 9, 2.6), (0.27, -8, 11, 3.0), (0.43, 4, 8, 2.4), (0.58, -5, 12, 3.0),
                     (0.74, 9, 9, 2.5), (0.90, -3, 10, 2.8)]:
    p = RIDGE_A + (RIDGE_B - RIDGE_A) * t
    OUTCROPS.append((p[0] + off, p[1] + off * 0.5, r, h))
OUTCROPS += [(-42.0, -292.0, 9.0, 2.4), (62.0, -268.0, 8.0, 2.2), (332.0, -150.0, 11.0, 3.0),
             (300.0, 222.0, 10.0, 2.6), (-318.0, 250.0, 12.0, 3.0), (150.0, -352.0, 10.0, 2.6),
             (-260.0, 330.0, 9.0, 2.4)]

DUMMIES = [(-2.5, -30.0), (0.0, -45.0), (2.5, -70.0), (-2.5, -95.0), (0.0, -120.0), (2.5, -140.0)]


# --- Noise ---------------------------------------------------------------------------------

class Perlin:
    """2D gradient noise in [-1, 1]; optionally periodic (period in lattice cells)."""

    def __init__(self, seed, period=None):
        rng = np.random.default_rng(seed)
        self.perm = rng.permutation(256).astype(np.int64)
        ang = rng.random(256) * 2.0 * np.pi
        self.gx = np.cos(ang)
        self.gz = np.sin(ang)
        self.period = period

    def _h(self, ix, iz):
        if self.period:
            ix = ix % self.period
            iz = iz % self.period
        return self.perm[(self.perm[ix & 255] + iz) & 255]

    def __call__(self, x, z):
        x = np.asarray(x, np.float64)
        z = np.asarray(z, np.float64)
        xi = np.floor(x).astype(np.int64)
        zi = np.floor(z).astype(np.int64)
        xf = x - xi
        zf = z - zi

        def g(dx, dz, ox, oz):
            h = self._h(xi + ox, zi + oz)
            return self.gx[h] * (xf - ox) + self.gz[h] * (zf - oz)

        u = xf * xf * xf * (xf * (xf * 6.0 - 15.0) + 10.0)
        v = zf * zf * zf * (zf * (zf * 6.0 - 15.0) + 10.0)
        n00 = g(0, 0, 0, 0)
        n10 = g(0, 0, 1, 0)
        n01 = g(0, 0, 0, 1)
        n11 = g(0, 0, 1, 1)
        a = n00 + (n10 - n00) * u
        b = n01 + (n11 - n01) * u
        return np.clip((a + (b - a) * v) * 1.4142, -1.0, 1.0)


_noise_cache = {}


def noise(seed):
    if seed not in _noise_cache:
        _noise_cache[seed] = Perlin(seed)
    return _noise_cache[seed]


def fbm(x, z, lam, octaves, seed, gain=0.5):
    total = np.zeros(np.broadcast(x, z).shape)
    amp = 1.0
    norm = 0.0
    f = 1.0 / lam
    for o in range(octaves):
        total += amp * noise(seed * 31 + o)(x * f + 17.3 * o, z * f - 9.1 * o)
        norm += amp
        amp *= gain
        f *= 2.0
    return total / norm


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# --- Geometry helpers ------------------------------------------------------------------------

def flat_distance(x, z):
    fx = np.maximum(np.abs(x) - FORT_FLAT_HALF, 0.0)
    fz = np.maximum(np.abs(z) - FORT_FLAT_HALF, 0.0)
    d_fort = np.hypot(fx, fz)
    lx = np.maximum(np.abs(x) - LANE_FLAT_HALF_X, 0.0)
    lz = np.maximum(np.maximum(LANE_FLAT_Z_MIN - z, z - LANE_FLAT_Z_MAX), 0.0)
    d_lane = np.hypot(lx, lz)
    return np.minimum(d_fort, d_lane)


def polyline_distance(x, z, pts):
    d = np.full(np.broadcast(x, z).shape, 1e9)
    for (ax, az), (bx, bz) in zip(pts[:-1], pts[1:]):
        vx, vz = bx - ax, bz - az
        l2 = vx * vx + vz * vz
        t = np.clip(((x - ax) * vx + (z - az) * vz) / l2, 0.0, 1.0)
        d = np.minimum(d, np.hypot(x - (ax + t * vx), z - (az + t * vz)))
    return d


def segment_distance(x, z, a, b):
    return polyline_distance(x, z, [tuple(a), tuple(b)])


def brook_centre(z):
    return 172.0 + 16.0 * np.sin(z / 75.0 + 0.7) + 7.0 * np.sin(z / 29.0 + 2.1)


# --- The world's squares ---------------------------------------------------------------------

def load_squares():
    with open(SQUARES_JSON) as fh:
        d = json.load(fh)
    grid = d["grid"]
    types = d["types"]
    r0 = (len(grid) - 1) // 2
    sq = {}
    for r, row in enumerate(grid):
        c0 = (len(row) - 1) // 2
        for c, t in enumerate(row):
            sq[(c - c0, r - r0)] = t
    built = {k for k, t in sq.items() if types.get(t, {}).get("built")}
    return sq, built


SQUARES, BUILT = load_squares()
SQ = (0, 0)                  # the square being baked (main)


def grid_type(sx, sz):
    """A square's type; past the grid, the nearest grid square's."""
    xs = [k[0] for k in SQUARES]
    zs = [k[1] for k in SQUARES]
    return SQUARES.get((min(max(sx, min(xs)), max(xs)), min(max(sz, min(zs)), max(zs))), "fort_woods")


def square_range(A):
    return (int(np.floor((A.min() + HALF) / SQUARE_M)) - 1, int(np.floor((A.max() + HALF) / SQUARE_M)) + 1)


def type_weights(X, Z):
    """Each type's share of the recipe at (X, Z): a square counts fully well inside it, half at its border, none
    TYPE_BLEND past it."""
    acc = {}
    tot = np.zeros_like(X)
    x0, x1 = square_range(X)
    z0, z1 = square_range(Z)
    for sx in range(x0, x1 + 1):
        for sz in range(z0, z1 + 1):
            w = smoothstep(-TYPE_BLEND, TYPE_BLEND, HALF - np.abs(X - sx * SQUARE_M)) \
                * smoothstep(-TYPE_BLEND, TYPE_BLEND, HALF - np.abs(Z - sz * SQUARE_M))
            if not w.any():
                continue
            t = grid_type(sx, sz)
            acc[t] = acc.get(t, 0.0) + w
            tot += w
    return {t: w / np.maximum(tot, 1e-9) for t, w in acc.items()}


def open_share(X, Z):
    tw = type_weights(X, Z)
    return sum((tw[t] for t in OPEN_TYPES if t in tw), np.zeros_like(X))


def rim_e(X, Z):
    """The rim's measure: the superellipse of the distances from a square's middle toward those of its sides that
    face an unbuilt square (the built land's outer edges); a side facing a built square counts nothing. Points in an
    unbuilt square (the margins) measure from the square being baked."""
    sx = np.floor((X + HALF) / SQUARE_M).astype(np.int64)
    sz = np.floor((Z + HALF) / SQUARE_M).astype(np.int64)
    ex = np.zeros_like(X)
    ez = np.zeros_like(X)
    for a in np.unique(sx):
        for b in np.unique(sz):
            m = (sx == a) & (sz == b)
            if not m.any():
                continue
            ref = (int(a), int(b)) if (int(a), int(b)) in BUILT else SQ
            lx = X[m] - ref[0] * SQUARE_M
            lz = Z[m] - ref[1] * SQUARE_M
            e_out = (ref[0] + 1, ref[1]) not in BUILT
            w_out = (ref[0] - 1, ref[1]) not in BUILT
            s_out = (ref[0], ref[1] + 1) not in BUILT
            n_out = (ref[0], ref[1] - 1) not in BUILT
            ex[m] = np.abs(lx) * np.where(lx >= 0.0, e_out, w_out)
            ez[m] = np.abs(lz) * np.where(lz >= 0.0, s_out, n_out)
    return (ex ** 6 + ez ** 6) ** (1.0 / 6.0)


# The river (squares.json "river", which the game's WorldRiver reads too): north-south through the squares east of
# the fort, falling along its course.
with open(SQUARES_JSON) as _fh:
    RIVER = json.load(_fh)["river"]
RIVER_X0 = float(RIVER["x0"])
RIVER_BED = float(RIVER["bed"])          # half width of its bed (m)
RIVER_BANK = float(RIVER["bank"])        # where its banks top out
RIVER_REACH = float(RIVER["reach"])      # beyond this it cuts nothing


def river_x(z):
    x = RIVER_X0
    for amp, wave, phase in RIVER["meanders"]:
        x = x + amp * np.sin(z / wave + phase)
    return x


def rapid_weight(z):
    """1 along a rapid, falling to 0 over rapid_ramp m past its ends."""
    w = np.zeros_like(np.asarray(z, dtype=np.float64))
    for zc, length, _drop in RIVER.get("rapids", []):
        w = np.maximum(w, smoothstep(length * 0.5 + RIVER["rapid_ramp"], length * 0.5, np.abs(z - zc)))
    return w


def water_level(z):
    """The river's surface (m): level0 where it enters the open land at its north edge, falling `fall` a metre and
    each rapid's drop along it."""
    lv = RIVER["level0"] - RIVER["fall"] * (z + HALF)
    for zc, length, drop in RIVER.get("rapids", []):
        lv = lv - drop * smoothstep(zc - length * 0.5, zc + length * 0.5, z)
    return lv


BOULDERS_JSON = os.path.join(HERE, "..", "..", "..", "data", "world", "river_boulders.json")


def boulders():
    """The rapids' boulders (seeded): [x, z, radius, top] (top over the water there); written to
    data/world/river_boulders.json for the game (RiverWater sets a rock on each)."""
    rng = np.random.default_rng(int(RIVER.get("boulder_seed", 1765)))
    out = []
    for zc, length, _drop in RIVER.get("rapids", []):
        for _k in range(int(round(length * RIVER.get("boulders_per_m", 0.3)))):
            z = zc + rng.uniform(-0.5, 0.5) * length
            x = float(river_x(z)) + rng.uniform(-7.0, 7.0)
            out.append((round(x, 3), round(z, 3), round(rng.uniform(1.4, 2.6), 3),
                        round(float(water_level(z)) + rng.uniform(0.1, 0.5), 3)))
    with open(BOULDERS_JSON, "w") as fh:
        json.dump({"_doc": "The river's rapids' boulders (bake_terrain.py boulders(), from squares.json 'river'): [x, z, radius, top over the ground there]; the ground has a bump for each, RiverWater sets a rock on it.",
                   "boulders": out}, fh, indent=0)
    return out


BOULDERS = []


def river_profile(dx, rw=0.0):
    """Ground over the water level across the river: its bed `depth` under (at a rapid, rapid_depth), the banks to
    `bank_top` over at RIVER_BANK, then the valley's sides rising `valley_rise` a metre."""
    d = RIVER["depth"] + (RIVER.get("rapid_depth", RIVER["depth"]) - RIVER["depth"]) * rw
    top = RIVER["bank_top"]
    bank = -d + (d + top) * smoothstep(RIVER_BED, RIVER_BANK, dx)
    return np.where(dx < RIVER_BANK, bank, top + RIVER["valley_rise"] * (dx - RIVER_BANK))


def smin(a, b, k):
    """Smooth minimum (exactly the lower where they differ by more than k)."""
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1.0 - h) + a * h - k * h * (1.0 - h)


def river_cut(H, X, Z):
    """The river's valley cut into H; at its rapids the boulders breaking the water. Also its distance and the
    rapids' weight there, and where the boulders are (their rock)."""
    dx = np.abs(X - river_x(Z))
    rw = rapid_weight(Z)
    valley = water_level(Z) + river_profile(dx, rw)
    H = np.where(dx < RIVER_REACH, smin(H, valley, 1.5), H)
    rock = np.zeros_like(H)
    for bx, bz, br, top in BOULDERS:
        d = np.hypot(X - bx, Z - bz)
        near = d < br * 1.3
        if not near.any():
            continue
        dome = top - (top - (float(water_level(bz)) - 2.0)) * (d / br) ** 4     # flat-topped: its crown breaks the water
        H = np.where(near, np.maximum(H, dome), H)
        rock = np.maximum(rock, smoothstep(br * 1.1, br * 0.7, d))
    return H, dx, rw, rock


def blur(a, sigma):
    """Separable Gaussian blur with edge clamping."""
    r = int(math.ceil(sigma * 3.0))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    p = np.pad(a, r, mode="edge")
    out = np.zeros_like(p)
    for i, w in enumerate(k):
        out[:, r:-r] += w * p[:, i:i + p.shape[1] - 2 * r]
    p2 = out[:, r:-r]
    out = np.zeros((p.shape[0], a.shape[1]))
    for i, w in enumerate(k):
        out[r:-r] += w * p2[i:i + p.shape[0] - 2 * r]
    return out[r:-r]


def bilinear(arr, x, z, x0=-HALF, z0=-HALF, res=1.0):
    """Sample a base-grid array at world (x, z)."""
    fx = np.clip((x - x0) / res, 0, arr.shape[1] - 1.001)
    fz = np.clip((z - z0) / res, 0, arr.shape[0] - 1.001)
    i = np.floor(fx).astype(np.int64)
    j = np.floor(fz).astype(np.int64)
    u = fx - i
    v = fz - j
    a = arr[j, i] * (1 - u) + arr[j, i + 1] * u
    b = arr[j + 1, i] * (1 - u) + arr[j + 1, i + 1] * u
    return a * (1 - v) + b * v


# --- Height field ----------------------------------------------------------------------------

def height_components(X, Z):
    d = flat_distance(X, Z)
    blend = smoothstep(0.0, BLEND_WIDTH, d)
    rolling = 2.5 * fbm(X, Z, 90.0, 4, seed=101)
    micro = 0.25 * (0.6 * noise(211)(X / 9.0, Z / 9.0) + 0.4 * noise(212)(X / 5.5, Z / 5.5))
    micro *= smoothstep(18.0, 30.0, d)
    # West ridge.
    rd = segment_distance(X, Z, RIDGE_A, RIDGE_B)
    ridge_f = np.exp(-rd * rd / (2.0 * 60.0 ** 2))
    ridge = 28.0 * ridge_f * (1.0 + 0.3 * fbm(X, Z, 200.0, 2, seed=303))
    # North backstop hill behind the range.
    hr2 = (X - 10.0) ** 2 + (Z + 300.0) ** 2
    hill = 16.0 * np.exp(-hr2 / (2.0 * 57.5 ** 2)) * (1.0 + 0.2 * fbm(X, Z, 120.0, 2, seed=404))
    # East draw with a dry brook bed along its bottom.
    xc = brook_centre(Z)
    draw_fade = 1.0 - smoothstep(330.0, 400.0, np.abs(Z))
    draw = -(4.2 * np.exp(-(X - xc) ** 2 / (2.0 * 22.0 ** 2))
             + 0.55 * np.exp(-(X - xc) ** 2 / (2.0 * 1.6 ** 2))) * draw_fade
    # Outer bowl: the ground rises 10-40 m toward the world edge so the edge is never seen (only the built land's
    # outer edges: rim_e).
    e = rim_e(X, Z)
    rim_n = 0.5 + 0.5 * fbm(X, Z, 160.0, 3, seed=505)
    bowl = smoothstep(290.0, 415.0, e) ** 1.3 * (10.0 + 30.0 * rim_n)
    # The open land's long swells.
    w_open = open_share(X, Z)
    swells = 5.0 * fbm(X, Z, 300.0, 3, seed=1101) * w_open
    # Rock outcrops (steep, up to ~45 deg).
    outcrop = np.zeros_like(X)
    outcrop_mask = np.zeros_like(X)
    on = noise(606)
    for (ox, oz, r, h) in OUTCROPS:
        dist = np.hypot(X - ox, Z - oz)
        wob = 1.0 + 0.25 * on(X / 4.0, Z / 4.0)
        s = smoothstep(r * wob, r * 0.5 * wob, dist)
        outcrop = np.maximum(outcrop, h * s * (0.85 + 0.15 * on(X / 2.0 + 50, Z / 2.0)))
        outcrop_mask = np.maximum(outcrop_mask, smoothstep(r * 1.1, r * 0.75, dist))
    macro = rolling + ridge + hill + draw + bowl + outcrop + swells
    macro, river_dx, rapid_w, boulder_rock = river_cut(macro, X, Z)
    outcrop_mask = np.maximum(outcrop_mask, boulder_rock)
    return dict(d=d, blend=blend, macro=macro, micro=micro, ridge_f=ridge_f, xc=xc,
                draw_fade=draw_fade, outcrop_mask=outcrop_mask, w_open=w_open, river_dx=river_dx, rapid_w=rapid_w)


# --- Surface fields --------------------------------------------------------------------------

def fort_fields(X, Z):
    """Fort interior, gate, firing line and range lane details (analytic)."""
    m = np.maximum(np.abs(X), np.abs(Z))
    inside = m < WALL_IN
    dist_in = WALL_IN - m
    dist_out = m - WALL_OUT
    n3 = noise(701)(X / 3.0, Z / 3.0)
    n1 = noise(702)(X / 1.1, Z / 1.1)

    # Bare packed earth.
    dirt = np.where(inside, 1.0, 0.0)
    # Sparse grass along the inner foot of the palisade, not at the gate or in the blockhouses.
    foot = 1.0 - smoothstep(0.25, 0.9 + 0.5 * (0.5 + 0.5 * n3), dist_in)
    foot *= smoothstep(0.3, 0.7, 0.5 + 0.5 * noise(703)(X / 1.7, Z / 1.7))
    gate_zone = (np.abs(X) < 4.8) & (Z < -12.0)
    blockhouse = ((X < -13.4) & (Z < -13.4)) | ((X > 13.4) & (Z > 13.4))
    foot = np.where(inside & ~gate_zone & ~blockhouse, foot, 0.0)
    # Tufts around posts: flagpole, gate posts (outside), rail posts.
    posts = [(-6.0, -2.0, 0.55), (3.1, -16.5, 0.7), (-3.1, -16.5, 0.7),
             (-4.0, -20.0, 0.4), (0.0, -20.0, 0.35), (4.0, -20.0, 0.4)]
    post_g = np.zeros_like(X)
    for (px, pz, r) in posts:
        post_g = np.maximum(post_g, smoothstep(r, r * 0.35, np.hypot(X - px, Z - pz)))

    # Gate apron (fan from the gate to the firing line) and the firing-line standing area.
    below = -15.8 - Z
    fan = (Z < -15.0) & (Z > -26.5) & (np.abs(X) < 3.3 + np.maximum(below, 0.0) * 0.38 + 0.25 * n3)
    fire = smoothstep(0.35, -0.35, np.maximum(np.abs(X) - 6.0, np.maximum(-22.8 - Z, Z + 18.2))
                      + 0.3 * n3)
    lane = smoothstep(0.12, -0.12, np.abs(X) - 5.0 + 0.08 * n1) \
        * smoothstep(-163.0, -159.5, Z + 1.5 * n3) * (Z < -15.0)
    apron = np.maximum(np.where(fan, 1.0, 0.0), np.maximum(fire, lane))
    # Soften the fan edge where it meets the meadow.
    dirt = np.maximum(dirt, apron)
    # Trampled strip along the outside foot of the palisade.
    out_trample = np.where(dist_out > -0.1, smoothstep(0.9, 0.0, dist_out), 0.0)
    dirt = np.maximum(dirt, 0.55 * out_trample * smoothstep(0.35, 0.0, dist_out - 0.1 * n1))
    dirt = np.clip(dirt - 0.4 * np.maximum(foot, post_g), 0.0, 1.0)   # sparse tufts only

    # Wear (darker, compacted earth): general fort wear plus the worn paths.
    wear = np.where(inside, 0.28 + 0.12 * n3, 0.0)
    for pts, w in FORT_PATHS:
        pd = polyline_distance(X, Z, pts)
        wear = np.maximum(wear, smoothstep(w * 0.5 + 0.4, w * 0.5 - 0.3, pd + 0.25 * n1) * (0.85 + 0.15 * n3))
    ring = np.abs(np.hypot(X + 6.0, Z + 2.0) - 1.3)
    wear = np.maximum(wear, smoothstep(0.7, 0.1, ring) * 0.7)
    # Firing line and the lane: two foot tracks to the targets and rings round the dummies.
    wear = np.maximum(wear, fire * (0.7 + 0.2 * n3))
    tracks = smoothstep(0.45, 0.1, np.abs(np.abs(X) - 1.35 + 0.15 * n3)) * lane
    wear = np.maximum(wear, tracks * 0.8)
    for (dx, dz) in DUMMIES:
        wear = np.maximum(wear, smoothstep(2.2, 0.8, np.hypot(X - dx, Z - dz)) * 0.8 * lane)
    mover = smoothstep(1.4, 0.3, np.abs(Z + 60.0)) * (np.abs(X) < 6.0)
    wear = np.maximum(wear, mover * 0.75)
    wear = np.maximum(wear, np.where(fan, 0.75 + 0.2 * n3, 0.0))
    wear = np.maximum(wear, out_trample * 0.5)
    wear = np.clip(wear * np.maximum(dirt, 0.4), 0.0, 1.0)

    # Mud: cart ruts through the gate throat, puddles.
    wob = 0.08 * noise(704)(Z / 2.3, 0.0)
    rut = smoothstep(0.34, 0.08, np.abs(np.abs(X + wob) - 0.8 - 0.03 * n1))
    rut *= smoothstep(-10.0, -12.5, Z) * smoothstep(-26.0, -21.5, Z)
    mud = rut * (0.42 + 0.18 * n1) * (0.6 + 0.4 * (0.5 + 0.5 * noise(705)(X / 0.9, Z / 2.7)))
    for (px, pz, r) in [(1.4, -18.6, 0.95), (-0.5, -13.2, 0.65), (-3.3, -21.3, 0.7), (6.8, -2.6, 0.55)]:
        pr = np.hypot((X - px) * 0.8, Z - pz) + 0.3 * n1 * r + 0.35 * n3 * r
        mud = np.maximum(mud, 0.48 * smoothstep(r * 1.2, r * 0.2, pr))
    mud = np.clip(mud * np.maximum(dirt, 0.3), 0.0, 1.0)

    # Grass height (m): mowed range shoulders, tufts along the walls and posts.
    mowed = (np.abs(X) < LANE_FLAT_HALF_X + 0.5) & (Z < -16.3) & (Z > LANE_FLAT_Z_MIN)
    return dict(dirt=dirt, wear=wear, mud=mud, foot=foot, post=post_g, mowed=mowed,
                inside=inside, dist_out=dist_out, out_trample=out_trample)


def surface_fields(X, Z, base):
    """All splat fields at world points (X, Z). `base` supplies height-derived maps sampled at
    these points: slope (deg), convex, sw (sun-facing), ridge_f, outcrop_mask, d, xc, draw_fade."""
    d = base["d"]
    n_edge = fbm(X, Z, 28.0, 2, seed=801)
    edge = d - (17.0 + 6.0 * n_edge)
    fd = smoothstep(-5.0, 5.0, edge)
    glade = np.ones_like(X)
    gn = noise(802)(X / 9.0, Z / 9.0)
    for k, (gx, gz, r) in enumerate(GLADES):
        # Irregular outline: radius wobbles +-35 % with the bearing, plus a noisy rim.
        ang = np.arctan2(Z - gz, X - gx)
        wob = 1.0 + 0.22 * np.sin(2.0 * ang + k * 1.7) + 0.13 * np.sin(3.0 * ang + k * 2.9)
        rr = np.hypot(X - gx, Z - gz) / wob
        glade = np.minimum(glade, smoothstep(r - 3.0 + 5.0 * gn, r + 8.0, rr))
    fd *= glade
    path_d = np.full_like(X, 1e9)
    path_mask = np.zeros_like(X)
    pn = noise(803)(X / 3.0, Z / 3.0)
    pn2 = noise(804)(X / 1.3, Z / 1.3)
    for pts, w in PATHS:
        pdist = polyline_distance(X, Z, pts)
        path_d = np.minimum(path_d, pdist)
        path_mask = np.maximum(path_mask, smoothstep(w * 0.5 + 0.25, w * 0.5 - 0.45, pdist + 0.3 * pn + 0.2 * pn2))
    fd *= smoothstep(1.8, 5.2, path_d + 1.2 * pn)
    # Dry brook bed: an open wet strip along the bottom of the east draw.
    brook_d = np.abs(X - base["xc"])
    fd *= 1.0 - (1.0 - smoothstep(3.0, 9.0, brook_d + 2.0 * pn)) * base["draw_fade"]
    # Rock: steep ground, outcrops and the ridge crest.
    crest = smoothstep(0.965, 0.995, base["ridge_f"]) * smoothstep(0.25, 0.6, fbm(X, Z, 18.0, 2, seed=805))
    rock = np.clip(np.maximum(np.maximum(smoothstep(26.0, 33.0, base["slope"]),
                                         base["outcrop_mask"] * 0.95), crest * 0.6), 0.0, 1.0)
    fd *= 1.0 - 0.6 * rock
    # Thinner woodland patches (still forest).
    fd *= 1.0 - 0.3 * smoothstep(0.35, 0.8, fbm(X, Z, 60.0, 2, seed=806))
    fd = np.clip(fd, 0.0, 1.0)
    # The open land: copses here and there, trees along the river's banks (not on its bed).
    w_open = base["w_open"]
    if w_open.any():
        rdx = base["river_dx"]
        copse = 0.85 * smoothstep(0.6, 0.8, 0.5 + 0.5 * fbm(X, Z, 110.0, 3, seed=1201))
        riparian = 0.55 * smoothstep(45.0, 22.0, rdx) * smoothstep(RIVER_BED + 3.0, RIVER_BANK + 2.0, rdx)
        fd_open = np.clip(np.maximum(copse, riparian) * (1.0 - 0.6 * rock), 0.0, 1.0)
        fd = fd * (1.0 - w_open) + fd_open * w_open

    forest = smoothstep(0.3, 0.75, fd + 0.18 * noise(807)(X / 9.0, Z / 9.0)) * (1.0 - rock)
    open_ = np.clip(1.0 - forest - rock, 0.0, 1.0)

    # Dry grass: sunny knolls and sun-facing slopes, noisy patches (~35 % of the clearing).
    dry_v = fbm(X, Z, 22.0, 3, seed=808) + 0.6 * base["convex"] + 0.25 * base["sw"] \
        + 0.35 * (1.0 - glade) + 0.05 * base["w_open"]
    dry = smoothstep(DRY_THRESHOLD - 0.08, DRY_THRESHOLD + 0.12, dry_v)

    f = fort_fields(X, Z)
    dirt = np.maximum(f["dirt"], path_mask)
    brook_bed = (1.0 - smoothstep(0.9, 2.4, brook_d + 0.4 * pn)) * base["draw_fade"]
    wet = smoothstep(0.05, 0.1, base["concave"]) * forest * smoothstep(0.3, 0.7, noise(809)(X / 7.0, Z / 7.0))
    river_bed = 1.0 - smoothstep(RIVER_BED + 3.5, RIVER_BED + 5.5, base["river_dx"] + 0.6 * pn)   # to the water's edge (9.5-10 m)
    # at the rapids a stony bed, not mud
    rock = np.maximum(rock, river_bed * base["rapid_w"] * (0.55 + 0.35 * smoothstep(-0.3, 0.5, pn)))
    river_bed = river_bed * (1.0 - 0.8 * base["rapid_w"])
    mud = np.clip(np.maximum(np.maximum(np.maximum(f["mud"], brook_bed), 0.35 * wet), river_bed), 0.0, 1.0)
    dirt = np.clip(dirt * (1.0 - mud), 0.0, 1.0)
    rest = np.clip(1.0 - dirt - mud, 0.0, 1.0)
    w = np.stack([open_ * (1.0 - dry), open_ * dry, dirt, mud, forest, rock], -1)
    w[..., [0, 1, 4, 5]] *= rest[..., None] / np.maximum(w[..., [0, 1, 4, 5]].sum(-1, keepdims=True), 1e-6)
    w /= np.maximum(w.sum(-1, keepdims=True), 1e-6)

    # Grass height (m).
    gh_n = 0.5 + 0.5 * noise(810)(X / 6.0, Z / 6.0)
    meadow_h = 0.42 + 0.2 * gh_n + 0.08 * dry                   # knee high
    edge_h = 0.5 + 0.15 * gh_n                                  # tall at the forest edge
    gh = meadow_h + (edge_h - meadow_h) * smoothstep(0.1, 0.45, fd) * (1.0 - smoothstep(0.55, 0.8, fd))
    gh = np.where(fd > 0.6, 0.18 + 0.12 * gh_n, gh)              # sparse, short on forest floor
    gh = np.where(f["mowed"], 0.12 + 0.08 * gh_n, gh)            # mowed range shoulders
    gh = np.where(f["inside"], 0.26 + 0.1 * gh_n, gh)            # wall-foot tufts
    prairie_h = 0.55 + 0.25 * gh_n + 0.1 * dry                   # the open land: tall grass
    gh = gh * (1.0 - base["w_open"]) + np.where(fd > 0.6, gh, prairie_h) * base["w_open"]
    trample = np.maximum(smoothstep(w_path_trample(), 0.0, path_d - 1.0), f["out_trample"])
    gh *= 1.0 - 0.55 * trample
    gh *= 1.0 - np.clip(dirt + mud + rock, 0.0, 1.0)
    grass_h = np.clip(gh / GRASS_H_SCALE, 0.0, 1.0)

    # Broadleaf litter share (vs conifer needles) under the canopy.
    litter = np.clip(0.5 + 0.6 * fbm(X, Z, 45.0, 2, seed=811) - 0.35 * base["north"], 0.0, 1.0)
    return dict(w=w, fd=fd, grass_h=grass_h, wear=f["wear"], litter=litter, dirt=dirt, mud=mud,
                rock=rock)


def w_path_trample():
    return 2.2


DRY_THRESHOLD = 0.0   # set from the clearing's distribution in main()


# --- Main ------------------------------------------------------------------------------------

def to_u8(a):
    return np.clip(np.round(a * 255.0), 0, 255).astype(np.uint8)


def save_png(name, arr):
    Image.fromarray(arr).save(os.path.join(OUT, name))


def main():
    global DRY_THRESHOLD, SQ, BUILT
    ap = argparse.ArgumentParser()
    ap.add_argument("--square", default="0,0")
    ap.add_argument("--built", default="")
    args = ap.parse_args()
    SQ = tuple(int(v) for v in args.square.split(","))
    BOULDERS[:] = boulders()
    if args.built:
        BUILT = {tuple(int(v) for v in b.split(",")) for b in args.built.split(";")}
    fort = SQ == (0, 0)
    out = OUT if fort else os.path.join(OUT, "sq_%d_%d" % SQ)
    os.makedirs(out, exist_ok=True)
    cx, cz = SQ[0] * SQUARE_M, SQ[1] * SQUARE_M
    NM = N + 2 * MARGIN
    ax = np.arange(NM, dtype=np.float64) - HALF - MARGIN
    X, Z = np.meshgrid(ax + cx, ax + cz)     # [j, i] = world (x, z); the square's own grid is the middle N x N
    crop = (slice(MARGIN, MARGIN + N), slice(MARGIN, MARGIN + N))

    c = height_components(X, Z)
    macro_h = c["blend"] * c["macro"]
    H = macro_h + c["blend"] * c["micro"]
    flat = c["d"] <= 0.0
    H[flat] = 0.0
    assert np.all(H[flat] == 0.0)
    Hs = blur(macro_h, 2.0)
    gz, gx = np.gradient(Hs)
    slope = np.degrees(np.arctan(np.hypot(gx, gz)))
    convex = np.clip((Hs - blur(Hs, 10.0)) / 1.5, -1.0, 1.0)
    concave = np.clip(blur(H, 3.0) - blur(H, 0.8) + 0.5 * (blur(Hs, 12.0) - Hs), -1, 1)
    nlen = np.sqrt(gx * gx + gz * gz + 1.0)
    nx, nz = -gx / nlen, -gz / nlen
    sw = (nx * SUN_XZ[0] + nz * SUN_XZ[1]) / np.maximum(np.hypot(nx, nz), 0.05) * smoothstep(0.02, 0.15, np.hypot(nx, nz))
    north = np.clip(-nz / 0.2, -1, 1) * smoothstep(0.02, 0.15, np.hypot(nx, nz))
    base = dict(d=c["d"], slope=slope, convex=convex, concave=concave, sw=sw, north=north,
                ridge_f=c["ridge_f"], outcrop_mask=c["outcrop_mask"], xc=c["xc"],
                draw_fade=c["draw_fade"], w_open=c["w_open"], river_dx=c["river_dx"], rapid_w=c["rapid_w"])

    # Dry-grass threshold: 35 % of the fort's open clearing band (the fort's bake sets it; the other squares share it).
    if fort:
        clearing = (c["d"] < 24.0) & (np.maximum(np.abs(X), np.abs(Z)) > WALL_OUT + 1.0)
        dv = fbm(X, Z, 22.0, 3, seed=808) + 0.6 * convex + 0.25 * sw
        DRY_THRESHOLD = float(np.percentile(dv[clearing], 65.0))
    else:
        fm = os.path.join(OUT, "meta.json")
        if not os.path.exists(fm):
            sys.exit("bake the fort's square (0,0) first: the others share its dry-grass threshold")
        with open(fm) as fh:
            DRY_THRESHOLD = float(json.load(fh)["stats"]["dry_threshold"])
        clearing = np.zeros_like(X, dtype=bool)

    s = surface_fields(X, Z, base)
    w = s["w"]

    # Normals (central differences of the rendered height, 1 m) and ambient occlusion from
    # the height field (horizon angles in 8 directions out to 48 m).
    gz1, gx1 = np.gradient(H)
    nl = np.sqrt(gx1 * gx1 + gz1 * gz1 + 1.0)
    NX, NZ = -gx1 / nl, -gz1 / nl
    ao = np.zeros_like(H)
    pad = 48
    Hp = np.pad(H, pad, mode="edge")
    dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)]
    for (di, dj) in dirs:
        best = np.zeros_like(H)
        for dist in (2, 4, 8, 16, 32, 48):
            si = int(round(di * dist / math.hypot(di, dj)))
            sj = int(round(dj * dist / math.hypot(di, dj)))
            sh = Hp[pad + sj:pad + sj + NM, pad + si:pad + si + NM]
            best = np.maximum(best, (sh - H) / math.hypot(si, sj))
        ao += 1.0 - np.sin(np.arctan(best))
    ao /= len(dirs)
    ao = np.clip(ao, 0.0, 1.0)

    # Collision heights: flat-zone samples 5 cm down so the GroundFloor box wins there.
    col = H.copy()
    col[flat] -= 0.05

    splat0 = np.stack([to_u8(w[..., 0]), to_u8(w[..., 1]), to_u8(w[..., 2]), to_u8(w[..., 3])], -1)
    splat1 = np.stack([to_u8(w[..., 4]), to_u8(w[..., 5]), to_u8(s["fd"]), to_u8(s["grass_h"])], -1)
    normal = np.stack([to_u8(NX * 0.5 + 0.5), to_u8(NZ * 0.5 + 0.5), to_u8(ao), to_u8(s["litter"])], -1)

    # The square's own grid from here on (the margins done their part).
    Xf, Zf = X, Z
    X, Z = X[crop], Z[crop]
    H, col, flat = H[crop], col[crop], flat[crop]
    splat0, splat1, normal, ao = splat0[crop], splat1[crop], normal[crop], ao[crop]
    NX, NZ, gx1, gz1 = NX[crop], NZ[crop], gx1[crop], gz1[crop]
    w = w[crop]
    s_fd, s_gh = s["fd"][crop], s["grass_h"][crop]
    d_c = c["d"][crop]
    clearing = clearing[crop]

    # Core detail map (0.25 m): the fort's square only.
    cw, cd = int(CORE_W / CORE_RES), int(CORE_D / CORE_RES)
    cs = None
    if fort:
        cxs = CORE_X0 + (np.arange(cw) + 0.5) * CORE_RES
        czs = CORE_Z0 + (np.arange(cd) + 0.5) * CORE_RES
        CX, CZ = np.meshgrid(cxs, czs)
        x0m, z0m = cx - HALF - MARGIN, cz - HALF - MARGIN
        cbase = {k: bilinear(v, CX, CZ, x0m, z0m) for k, v in base.items() if k not in ("d", "xc", "draw_fade")}
        cbase["d"] = flat_distance(CX, CZ)
        cbase["xc"] = brook_centre(CZ)
        cbase["draw_fade"] = bilinear(base["draw_fade"], CX, CZ, x0m, z0m)
        cs = surface_fields(CX, CZ, cbase)
        core = np.stack([to_u8(cs["mud"]), to_u8(cs["wear"]), to_u8(cs["dirt"]), to_u8(cs["grass_h"])], -1)

    # Grass cell maxima (8 m cells, 1 m margin), from the same inputs the grass shader reads.
    def grass_loc(w_, gh_):
        meadow = w_[..., 0] + w_[..., 1]
        fshare = w_[..., 4] / np.maximum(meadow + w_[..., 4], 1e-3)
        bare = np.clip(w_[..., 2] + w_[..., 3] + w_[..., 5], 0, 1)
        return np.clip(1.0 - bare * 1.25, 0, 1) * (1.0 - 0.7 * fshare) * (gh_ * GRASS_H_SCALE > 0.03)
    loc_base = grass_loc(w, s_gh)
    ncell = N // 8
    gcell = np.zeros((ncell, ncell))
    for cj in range(ncell):
        for ci in range(ncell):
            j0, i0 = cj * 8, ci * 8
            blk = loc_base[max(j0 - 1, 0):j0 + 10, max(i0 - 1, 0):i0 + 10]
            gcell[cj, ci] = blk.max() if blk.size else 0.0
    if fort:
        # Inside the core rect the shader takes dirt / mud / grass height from the detail map.
        wc = np.stack([bilinear(s["w"][..., k], CX, CZ, x0m, z0m) for k in range(6)], -1)
        wc[..., 2] = cs["dirt"]
        wc[..., 3] = cs["mud"]
        loc_core = grass_loc(wc, cs["grass_h"])
        # Cells overlapping the core rect: use the 0.25 m maxima there.
        for cj in range(ncell):
            for ci in range(ncell):
                x0, z0 = ci * 8 - HALF, cj * 8 - HALF
                if x0 + 9 > CORE_X0 and x0 - 1 < CORE_X0 + CORE_W and z0 + 9 > CORE_Z0 and z0 - 1 < CORE_Z0 + CORE_D:
                    a0 = int(max((x0 - 1 - CORE_X0) / CORE_RES, 0)); a1 = int(min((x0 + 9 - CORE_X0) / CORE_RES, cw))
                    b0 = int(max((z0 - 1 - CORE_Z0) / CORE_RES, 0)); b1 = int(min((z0 + 9 - CORE_Z0) / CORE_RES, cd))
                    inside_blk = loc_core[b0:b1, a0:a1]
                    if inside_blk.size:
                        fully = x0 - 1 >= CORE_X0 + 2 and x0 + 9 <= CORE_X0 + CORE_W - 2 and z0 - 1 >= CORE_Z0 + 2 and z0 + 9 <= CORE_Z0 + CORE_D - 2
                        gcell[cj, ci] = inside_blk.max() if fully else max(gcell[cj, ci], inside_blk.max())
    grass_cells = to_u8(np.minimum(gcell * 1.05 + 0.02 * (gcell > 0), 1.0))

    # Macro noise tile (256 px, periodic): the same for every square.
    t = np.arange(256) / 256.0
    TX, TZ = np.meshgrid(t, t)
    macro = []
    for k, (per, sd) in enumerate([(2, 901), (4, 902), (16, 903), (64, 904)]):
        p = Perlin(sd, period=per)
        v = p(TX * per, TZ * per)
        if per < 64:
            p2 = Perlin(sd + 50, period=per * 2)
            v = 0.7 * v + 0.3 * p2(TX * per * 2, TZ * per * 2)
        macro.append(to_u8(np.clip(v * 0.5 + 0.5, 0, 1)))
    macro = np.stack(macro, -1)

    # Chunk bounds.
    nch = (N - 1) // CHUNK
    bounds = np.zeros((nch, nch, 2), np.float32)
    for cj in range(nch):
        for ci in range(nch):
            blk = H[cj * CHUNK:cj * CHUNK + CHUNK + 1, ci * CHUNK:ci * CHUNK + CHUNK + 1]
            bounds[cj, ci] = (blk.min(), blk.max())

    # Surface overlay colliders: 1 m cells fully outside the flat zones (d >= 1 at all four
    # corners), where the ground is mostly dirt/mud (paths, brook bed, the river's) or rock: within +-250 m of the fort
    # in its square, all of another.
    dmin = np.minimum(np.minimum(d_c[:-1, :-1], d_c[1:, 1:]), np.minimum(d_c[1:, :-1], d_c[:-1, 1:]))
    cellw = (w[:-1, :-1] + w[1:, 1:] + w[1:, :-1] + w[:-1, 1:]) * 0.25
    reach = 250 if fort else HALF
    within = (np.abs(X[:-1, :-1] - cx + 0.5) < reach) & (np.abs(Z[:-1, :-1] - cz + 0.5) < reach) & (dmin >= 1.0)
    dirt_cells = np.argwhere(within & (cellw[..., 2] + cellw[..., 3] > 0.5))
    stone_cells = np.argwhere(within & (cellw[..., 5] > 0.55))
    dirt_idx = (dirt_cells[:, 0] * N + dirt_cells[:, 1]).astype(np.int32)
    stone_idx = (stone_cells[:, 0] * N + stone_cells[:, 1]).astype(np.int32)

    H.astype("<f4").tofile(os.path.join(out, "height.bin"))
    col.astype("<f4").tofile(os.path.join(out, "collision.bin"))
    splat0.tofile(os.path.join(out, "splat0.bin"))
    splat1.tofile(os.path.join(out, "splat1.bin"))
    normal.tofile(os.path.join(out, "normal.bin"))
    if fort:
        core.tofile(os.path.join(out, "core.bin"))
    macro.tofile(os.path.join(out, "macro.bin"))
    bounds.astype("<f4").tofile(os.path.join(out, "bounds.bin"))
    dirt_idx.astype("<i4").tofile(os.path.join(out, "overlay_dirt.bin"))
    grass_cells.tofile(os.path.join(out, "grass_cells.bin"))
    stone_idx.astype("<i4").tofile(os.path.join(out, "overlay_stone.bin"))

    meadow_w = w[..., 0] + w[..., 1]
    stats = {
        "height_min": float(H.min()), "height_max": float(H.max()),
        "slope_max_deg": float(np.degrees(np.arctan(np.hypot(gx1, gz1))).max()),
        "slope_p99_deg": float(np.percentile(np.degrees(np.arctan(np.hypot(gx1, gz1))), 99)),
        "flat_samples": int(flat.sum()),
        "dry_threshold": DRY_THRESHOLD,
        "dry_share_clearing": float((w[..., 1] / np.maximum(meadow_w, 1e-6))[clearing & (meadow_w > 0.5)].mean()) if clearing.any() else 0.0,
        "forest_share": float((s_fd > 0.5).mean()),
        "layer_share": [float(v) for v in w.reshape(-1, 6).mean(0)],
        "dirt_overlay_cells": int(dirt_idx.size), "stone_overlay_cells": int(stone_idx.size),
    }
    stats["grass_cells_empty_share"] = float((grass_cells == 0).mean())
    stats["grass_cells_mean_max"] = float(grass_cells.mean() / 255.0)
    meta = {"N": N, "half": HALF, "chunk": CHUNK, "core": [CORE_X0, CORE_Z0, CORE_W, CORE_D, CORE_RES],
            "grass_cells": int(N // 8),
            "core_size": [cw, cd] if fort else [0, 0], "grass_h_scale": GRASS_H_SCALE, "macro_size": 256,
            "square": list(SQ), "origin": [cx, cz], "type": grid_type(*SQ), "built": sorted(list(BUILT)),
            "river": {"x0": RIVER_X0, "bed": RIVER_BED, "bank": RIVER_BANK},
            "stats": stats}
    with open(os.path.join(out, "meta.json"), "w") as fh:
        json.dump(meta, fh, indent=1)

    # Previews.
    hn = (H - H.min()) / max(H.max() - H.min(), 1e-6)
    shade = np.clip(0.35 + 0.65 * (NX * -0.64 + 0.33 + NZ * 0.70) / 1.1, 0, 1)
    Image.fromarray(to_u8(hn * 0.6 + shade * 0.4)).save(os.path.join(out, "preview_height.png"))
    cols = np.array([[0.40, 0.45, 0.20], [0.70, 0.62, 0.38], [0.55, 0.43, 0.30], [0.28, 0.20, 0.12],
                     [0.30, 0.24, 0.16], [0.50, 0.50, 0.50]])
    rgb = (w @ cols) * (0.6 + 0.4 * shade[..., None]) * (1 - 0.35 * s_fd[..., None])
    Image.fromarray(to_u8(rgb)).save(os.path.join(out, "preview_splat.png"))
    Image.fromarray(to_u8(s_fd)).save(os.path.join(out, "preview_forest.png"))
    Image.fromarray(to_u8(ao)).save(os.path.join(out, "preview_ao.png"))
    if fort:
        crgb = np.stack([cs["dirt"] * 0.8 + cs["mud"] * 0.2, cs["wear"], cs["grass_h"]], -1)
        Image.fromarray(to_u8(crgb)).save(os.path.join(out, "preview_core.png"))
    print(json.dumps(stats, indent=1))


if __name__ == "__main__":
    main()
