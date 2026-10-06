#!/usr/bin/env python3
"""Bake a Thủy Vân region's terrain squares (R1 first) by the frontier baker's grid and seam rules.

Deterministic and re-runnable (numpy only, the region's seed). Reads

    data/world/maps/r1/layout.json     the squares' grid and centres, the channels' and pounds' levels, the landmarks
                                       (the only source of coordinates and levels; never edited here)
    data/world/maps/r1/squares.json    each square's type, recipe parameters and broad relief
    data/world/maps/r1/water.json      the water network, through tools/environment/water/water_net.py (M2: every
                                       pound), which sets the channels' beds and the pounds' floors

and writes, per square, tools/environment/terrain/build_regions/r1/<cell>/ in bake_terrain.py's output formats
(height.bin, collision.bin, splat0/1.bin, normal.bin, macro.bin, bounds.bin, overlay_dirt/stone.bin, grass_cells.bin,
meta.json; no core.bin, which is the fort's) plus sheer_cells.bin (u8 104 x 104: 1 where an 8 m cell's ground is
mostly steeper than 60 deg, a mesh face's footprint) and preview PNGs. Raw outputs are ignored by git.

    python3 tools/environment/terrain/regions/bake_region.py [--cell C1[,B1...]] [--layout PATH] [--out DIR]

Grid and seams, as bake_terrain.py: a square is 833 x 833 samples at 1 m about its centre (HALF 416), its edge
samples shared with its neighbour's; it is baked with MARGIN samples past every edge (cropped) so normals, occlusion
and blurs agree at the seam; every value is a function of world position, so two squares meet exactly. The squares'
recipes (recipes_thuyvan.py) blend over TYPE_BLEND m either side of a border.

Height, in order (height_field()):
  1. each recipe's upland h and valley ceiling v, blended by the squares' weights
  2. the region's outer rim added to the upland (the ground rising where the region ends, cut by the rivers)
  3. min(upland, valley), smoothed over SMIN_K m
  4. the banks lifted to their water level (BANK_FREEBOARD over it within 4 m, falling 1:1 past 8 m) and the pounds'
     rims likewise, so no water stands over dry ground
  5. in the water: water_net's bed (the main channel's centre held from rising downstream: see BedCap), each pound's
     flat floor, and the paddies' bunds inside their edges
"""
import argparse
import hashlib
import json
import math
import os
import sys
import time
import zlib

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "tools", "environment", "water"))
from common import (Perlin, bilinear, blur, fbm, nearest_on_polyline, noise, smin, smoothstep,  # noqa: E402
                    to_u8)
import recipes_thuyvan as recipes  # noqa: E402
from water_net import WaterNet  # noqa: E402

MAPS = os.path.join(ROOT, "data", "world", "maps")
LAYOUT = os.environ.get("TV_LAYOUT", os.path.join(MAPS, "r1", "layout.json"))
SQUARES = os.path.join(MAPS, "r1", "squares.json")
WATER = os.path.join(MAPS, "r1", "water.json")
OUT_ROOT = os.path.join(ROOT, "tools", "environment", "terrain", "build_regions")

# The grid (bake_terrain.py).
HALF = 416
N = 2 * HALF + 1
CHUNK = 64
MARGIN = 64
TYPE_BLEND = 100.0
GRASS_H_SCALE = 0.8
SUN_XZ = np.array([-0.6384, 0.6967])
SUN_XZ = SUN_XZ / np.linalg.norm(SUN_XZ)

# The water's edges.
SMIN_K = 3.0              # m: the valley's shoulder where it meets the upland
BANK_FREEBOARD = 0.25     # m over the water within 4 m of a channel's bank
BANK_BAND = 8.0           # m past the bank the freeboard holds, then falls away 1:1
POUND_FREEBOARD = 0.3     # m over a pound's level just outside it
POUND_BAND = 3.0
LEVEL_FAR = (60.0, 240.0)  # m past a bank: the channel's level read exactly before, smoothed (LEVEL_BLUR) after
LEVEL_GRID = 8.0
LEVEL_BLUR = 6.0          # coarse cells (48 m)
LEVEL_ALONG_SIGMA = 30.0  # m along a channel: the level its valley's sides read (falls and steps eased)
LEVEL_ALONG_DP = 30.0     # m past the bank over which the sides go from the exact level to that one
EXTEND_M = 800.0          # a channel leaving the region runs on straight this far (for the margins)
AUX = ("path", "pad", "terrace", "riser", "rock", "forest", "karst")   # the recipes' splat hints


def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def sha1(path):
    with open(path, "rb") as fh:
        return hashlib.sha1(fh.read()).hexdigest()


def cell_seed(seed, cid):
    return int(seed) * 7919 + zlib.crc32(cid.encode()) % 100003


def merged(base, over):
    out = dict(base)
    for k, v in over.items():
        out[k] = merged(out[k], v) if isinstance(v, dict) and isinstance(out.get(k), dict) else v
    return out


# --- The region's context ---------------------------------------------------------------------------------------

class Channel:
    """A channel's centre line from water.json, run on straight past the ends where it leaves the region."""

    def __init__(self, ch, bounds):
        self.ch = ch
        self.id = ch.id
        x, z, s = ch.x.copy(), ch.z.copy(), ch.s.copy()
        hw, bd = ch.hw.copy(), ch.bed_depth.copy()
        self.length = float(s[-1])

        def on_edge(px, pz):
            return min(abs(px - bounds[0]), abs(px - bounds[1]), abs(pz - bounds[2]), abs(pz - bounds[3])) < 1.0

        self.ext0 = self.ext1 = 0.0
        k = np.arange(1, int(EXTEND_M / 8.0) + 1) * 8.0
        if on_edge(x[0], z[0]):
            tx, tz = x[0] - x[1], z[0] - z[1]
            L = math.hypot(tx, tz)
            ex, ez = x[0] + k[::-1] * tx / L, z[0] + k[::-1] * tz / L
            x, z = np.r_[ex, x], np.r_[ez, z]
            s = np.r_[-k[::-1], s]
            hw, bd = np.r_[np.full(len(k), hw[0]), hw], np.r_[np.full(len(k), bd[0]), bd]
        if on_edge(x[-1], z[-1]):
            tx, tz = x[-1] - x[-2], z[-1] - z[-2]
            L = math.hypot(tx, tz)
            x, z = np.r_[x, x[-1] + k * tx / L], np.r_[z, z[-1] + k * tz / L]
            s = np.r_[s, self.length + k]
            hw, bd = np.r_[hw, np.full(len(k), hw[-1])], np.r_[bd, np.full(len(k), bd[-1])]
        self.x, self.z, self.s, self.hw, self.bd = x, z, s, hw, bd
        # The level's run past the ends: the slope of the first and last 100 m.
        self.g0 = (ch.level[0] - np.interp(100.0, ch.s, ch.level)) / 100.0
        self.g1 = (np.interp(self.length - 100.0, ch.s, ch.level) - ch.level[-1]) / 100.0

    def smooth_levels(self, net):
        """The surface level smoothed along the channel (LEVEL_ALONG_SIGMA): the valley's sides read it a few metres
        from the bank, so a fall or the lock step is a cliff at the water and a slope up the valley's side."""
        s = np.arange(-EXTEND_M, self.length + EXTEND_M + 1.0, 1.0)
        sc = np.clip(s, 0.0, self.length)
        past = np.where(s < 0.0, -s * self.g0, np.where(s > self.length, -(s - self.length) * self.g1, 0.0))
        lv = net.level_at_s(self.id, sc) + past
        r = int(3 * LEVEL_ALONG_SIGMA)
        k = np.exp(-0.5 * (np.arange(-r, r + 1) / LEVEL_ALONG_SIGMA) ** 2)
        self.sm_s = s
        self.sm_level = np.convolve(np.pad(lv, r, mode="edge"), k / k.sum(), mode="valid")

    def fields(self, net, seg, t, off):
        s = self.s[seg] + t * (self.s[seg + 1] - self.s[seg])
        hw = self.hw[seg] + t * (self.hw[seg + 1] - self.hw[seg])
        bd = self.bd[seg] + t * (self.bd[seg + 1] - self.bd[seg])
        sc = np.clip(s, 0.0, self.length)
        past = np.where(s < 0.0, -s * self.g0, np.where(s > self.length, -(s - self.length) * self.g1, 0.0))
        lvl0 = net.level_at_s(self.id, sc) + past
        eased = np.interp(sc, self.ch.s, self.ch.level) + past
        u = np.minimum(np.abs(off) / hw, 1.0)
        bed = eased - bd * (1.0 - u ** self.ch.exponent)
        return {"off": off, "dp": np.abs(off) - hw, "s": s, "hw": hw, "bd": bd, "exp": self.ch.exponent,
                "lvl0": lvl0, "lvl_s": np.interp(s, self.sm_s, self.sm_level), "bed": bed}


class Region:
    def __init__(self, layout_path=LAYOUT, squares_path=SQUARES, water_path=WATER, overrides=None):
        if not os.path.exists(layout_path):
            sys.exit("no layout at %s (T0 commits data/world/maps/r1/layout.json; TV_LAYOUT=<path> or --layout names "
                     "another)" % layout_path)
        self.layout = load_json(layout_path)
        self.squares = load_json(squares_path)
        self.water = load_json(water_path)
        self.paths = {"layout": layout_path, "squares": squares_path, "water": water_path}
        self.inputs = {k: sha1(v) for k, v in self.paths.items()}
        if self.water.get("source", {}).get("sha1") not in (None, self.inputs["layout"]):
            print("warning: water.json was built from another layout (rerun build_water_json.py)", file=sys.stderr)
        self.net = WaterNet(self.water)
        self.net.set_milestone("M2")          # carve every pound and the lock step
        self.seed = int(self.squares["seed"])
        g = self.layout["grid"]
        self.square_m = float(self.layout["square_m"])
        assert abs(self.square_m - 2 * HALF) < 1e-9
        self.cols, self.rows = g["cols"], [str(r) for r in g["rows"]]
        self.cells = {}
        types = self.squares["types"]
        for r, row in enumerate(self.rows):
            for c, col in enumerate(self.cols):
                cid = "%s%s" % (col, row)
                typ = g["cells"][cid]
                sq = self.squares["cells"][cid]
                assert sq["type"] == typ, "squares.json %s is %s, the layout says %s" % (cid, sq["type"], typ)
                prm = merged(types[typ]["params"], sq.get("params", {}))
                if overrides and cid in overrides:
                    prm = merged(prm, overrides[cid])
                self.cells[cid] = {"id": cid, "type": typ, "col": c, "row": r, "cx": float(g["col_center_x"][col]),
                                   "cz": float(g["row_center_z"][row]), "seed": cell_seed(self.seed, cid),
                                   "params": prm, "relief": sq["relief"]}
        xs = [c["cx"] for c in self.cells.values()]
        zs = [c["cz"] for c in self.cells.values()]
        self.bounds = (min(xs) - HALF, max(xs) + HALF, min(zs) - HALF, max(zs) + HALF)
        # The broad relief: every square's points (u west->east, v north->south over the square).
        pts = []
        for c in self.cells.values():
            for u, v, h in c["relief"]:
                pts.append((c["cx"] + (u - 0.5) * 2 * HALF, c["cz"] + (v - 0.5) * 2 * HALF, h))
        self.relief = np.asarray(pts, dtype=np.float64)
        self.relief_sigma = float(self.squares["relief_sigma_m"])
        self.rim = self.squares["region_rim"]
        self.channels = [Channel(ch, self.bounds) for ch in self.net.channels]
        for c in self.channels:
            c.smooth_levels(self.net)
        self.channel_by_id = {c.id: c for c in self.channels}
        self.pounds = self.water["pounds"]
        self.landmarks = self.layout["landmarks"]
        self.cache = {}
        self._level_grids()
        self.bedcap = BedCap(self)

    def _level_grids(self):
        """Each channel's level on a coarse grid over the region and well past it, blurred: what the land reads far
        from a channel, where the nearest centre-line point jumps (behind a bend) but the ground must not."""
        b = self.bounds
        pad = EXTEND_M - 100.0
        self.lg_x0, self.lg_z0 = b[0] - pad, b[2] - pad
        nx = int((b[1] - b[0] + 2 * pad) / LEVEL_GRID) + 1
        nz = int((b[3] - b[2] + 2 * pad) / LEVEL_GRID) + 1
        X, Z = np.meshgrid(self.lg_x0 + np.arange(nx) * LEVEL_GRID, self.lg_z0 + np.arange(nz) * LEVEL_GRID)
        self.level_grid = {}
        for c in self.channels:
            seg, t, off = nearest_on_polyline(X, Z, c.x, c.z)
            lv = c.fields(self.net, seg, t, off)["lvl_s"]
            self.level_grid[c.id] = blur(lv, LEVEL_BLUR)

    def landmark(self, name):
        lm = self.landmarks[name]
        return lm["at"]

    def landmark_s(self, name, cid):
        key = ("s", name, cid)
        if key not in self.cache:
            at = self.landmark(name)
            c = self.channel_by_id[cid]
            seg, t, off = nearest_on_polyline(np.array([[float(at[0])]]), np.array([[float(at[1])]]), c.x, c.z)
            self.cache[key] = float(c.fields(self.net, seg, t, off)["s"][0, 0])
        return self.cache[key]

    def pound_group(self, gid):
        ps = [p for p in self.pounds if p["group"] == gid]
        return {"pounds": ps, "bed_top": max(float(p["bed"]) for p in ps), "level_top": max(float(p["level"]) for p in ps)}

    def relief_at(self, x, z):
        """The broad relief U: a Gaussian-weighted mean of the squares' relief points (smooth, within their range)."""
        num = np.zeros(x.shape)
        den = np.zeros(x.shape)
        k = -0.5 / (self.relief_sigma ** 2)
        for px, pz, h in self.relief:
            w = np.exp(((x - px) ** 2 + (z - pz) ** 2) * k)
            num += w * h
            den += w
        return num / np.maximum(den, 1e-300)

    def outer_rim(self, x, z):
        """The ground's rise toward the region's outer edges (the edge is never seen), eased off at the notches (where
        a route leaves) and cut later by the rivers' valleys."""
        b = self.bounds
        e = np.minimum(np.minimum(x - b[0], b[1] - x), np.minimum(z - b[2], b[3] - z))
        r = self.rim
        n = 0.5 + 0.5 * fbm(x, z, 170.0, 3, self.seed + 505)
        rise = smoothstep(r["width_m"], -0.25 * r["width_m"], e) ** 1.3 * (r["rise_min_m"] + (r["rise_max_m"] - r["rise_min_m"]) * n)
        for name, edge, radius in r.get("notches", []):
            at = self.landmark(name)
            nx, nz = {"north": (at[0], b[2]), "south": (at[0], b[3]), "west": (b[0], at[1]), "east": (b[1], at[1])}[edge]
            rise = rise * smoothstep(radius * 0.5, radius, np.hypot(x - nx, z - nz))
        return rise


class BedCap:
    """The main channel's bed on its centre line must not rise downstream. It does in one place: below the lock
    chamber, whose floor (the pound's bed) lies under the channel's own bed just downstream. There the channel's bed is
    lowered (most on the centre line, none at its banks) by how far its centre stands over the lowest bed upstream."""

    def __init__(self, reg, cid="main", ds=0.5):
        ch = reg.net.by_id[cid]
        s = np.arange(0.0, float(ch.s[-1]) + ds, ds)
        x, z = np.interp(s, ch.s, ch.x), np.interp(s, ch.s, ch.z)
        bed = reg.net.bed_at(x, z)                     # a pound's floor where the line crosses one
        self.cid = cid
        self.ch = ch
        self.s = s
        self.cap = np.minimum.accumulate(bed)

    def at(self, s):
        """How far the channel's own centre bed at s stands over the lowest bed upstream (the cap is continuous past
        a pound's lower end, so this is too)."""
        own = np.interp(s, self.ch.s, self.ch.level) - np.interp(s, self.ch.s, self.ch.bed_depth)
        return np.maximum(own - np.interp(s, self.s, self.cap), 0.0)


# --- Points --------------------------------------------------------------------------------------------------------

class Points:
    """Sample points (1D) with what the recipes read, computed once and shared with their subsets."""

    def __init__(self, reg, x, z, cache=None):
        self.reg = reg
        self.x = np.asarray(x, dtype=np.float64).ravel()
        self.z = np.asarray(z, dtype=np.float64).ravel()
        self._c = cache if cache is not None else {}
        self.channels = [c.id for c in reg.channels]

    @classmethod
    def grid(cls, reg, X, Z):
        """Points over a 2D grid: the channels' nearest points found block by block over it."""
        P = cls(reg, X, Z)
        for c in reg.channels:
            seg, t, off = nearest_on_polyline(X, Z, c.x, c.z)
            P._c["ch:" + c.id] = P._finish(c, seg.ravel(), t.ravel(), off.ravel())
        return P

    def _finish(self, c, seg, t, off):
        f = c.fields(self.reg.net, seg, t, off)
        far = bilinear(self.reg.level_grid[c.id], self.x, self.z, self.reg.lg_x0, self.reg.lg_z0, LEVEL_GRID)
        near = f["lvl0"] + (f["lvl_s"] - f["lvl0"]) * smoothstep(0.0, LEVEL_ALONG_DP, f["dp"])
        f["lvl"] = near + (far - near) * smoothstep(LEVEL_FAR[0], LEVEL_FAR[1], f["dp"])
        return f

    def take(self, idx):
        sub = {}
        for k, v in self._c.items():
            sub[k] = {kk: (vv[idx] if isinstance(vv, np.ndarray) else vv) for kk, vv in v.items()} \
                if isinstance(v, dict) else v[idx]
        return Points(self.reg, self.x[idx], self.z[idx], sub)

    def sub(self, x, z):
        return Points(self.reg, x, z)

    @property
    def U(self):
        if "U" not in self._c:
            self._c["U"] = self.reg.relief_at(self.x, self.z)
        return self._c["U"]

    def ch(self, cid):
        key = "ch:" + cid
        if key not in self._c:
            c = self.reg.channel_by_id[cid]
            seg, t, off = nearest_on_polyline(self.x.reshape(-1, 1), self.z.reshape(-1, 1), c.x, c.z)
            self._c[key] = self._finish(c, seg.ravel(), t.ravel(), off.ravel())
        return self._c[key]

    def landmark(self, name):
        return self.reg.landmark(name)

    def landmark_s(self, name, cid):
        return self.reg.landmark_s(name, cid)

    def pound_group(self, gid):
        return self.reg.pound_group(gid)

    def trail(self, cell, prm):
        key = ("trail", cell["id"], json.dumps(prm, sort_keys=True))
        if key not in self.reg.cache:
            self.reg.cache[key] = recipes.Trail(self, cell, prm)
        return self.reg.cache[key]


# --- Height ----------------------------------------------------------------------------------------------------------

def cell_weights(reg, x, z):
    """Each real square's share at (x, z): a square counts fully well inside it, half at its border, none TYPE_BLEND past
    it; the squares past the grid count as the nearest grid square (bake_terrain.py's rule)."""
    ncol, nrow = len(reg.cols), len(reg.rows)
    x0 = reg.bounds[0] + HALF
    z0 = reg.bounds[2] + HALF
    S = 2 * HALF
    ci = np.floor((x - (x0 - HALF)) / S).astype(np.int64)
    ri = np.floor((z - (z0 - HALF)) / S).astype(np.int64)
    acc = {}
    for c in range(int(ci.min()) - 1, int(ci.max()) + 2):
        for r in range(int(ri.min()) - 1, int(ri.max()) + 2):
            w = smoothstep(-TYPE_BLEND, TYPE_BLEND, HALF - np.abs(x - (x0 + c * S))) \
                * smoothstep(-TYPE_BLEND, TYPE_BLEND, HALF - np.abs(z - (z0 + r * S)))
            if not w.any():
                continue
            cid = "%s%s" % (reg.cols[min(max(c, 0), ncol - 1)], reg.rows[min(max(r, 0), nrow - 1)])
            acc[cid] = acc.get(cid, 0.0) + w
    return acc


def polygon_inside(poly, x, z):
    inside = np.zeros(x.shape, dtype=bool)
    n = len(poly)
    for k in range(n):
        ax, az = poly[k]
        bx, bz = poly[(k + 1) % n]
        cross = (az > z) != (bz > z)
        xi = ax + (z - az) * (bx - ax) / ((bz - az) if bz != az else 1e-12)
        inside ^= cross & (x < xi)
    return inside


def polygon_edge_distance(poly, x, z):
    d = np.full(x.shape, np.inf)
    n = len(poly)
    for k in range(n):
        ax, az = poly[k]
        bx, bz = poly[(k + 1) % n]
        vx, vz = bx - ax, bz - az
        t = np.clip(((x - ax) * vx + (z - az) * vz) / (vx * vx + vz * vz), 0.0, 1.0)
        d = np.minimum(d, np.hypot(x - (ax + t * vx), z - (az + t * vz)))
    return d


def paddy_aprons(reg, pounds, x, z, H):
    """Round each paddy group the ground eases to its nearest paddy's bund top over apron_m, so the paddies sit in
    their slope (a cut on the uphill side, a fill below, both eased), not in a pit or on a mound."""
    pp = reg.squares["paddy"]
    groups = {}
    for p in pounds:
        if p.get("kind") == "paddy":
            groups.setdefault(p["group"], []).append(p)
    for ps in groups.values():
        bx = [q[0] for p in ps for q in p["polygon"]]
        bz = [q[1] for p in ps for q in p["polygon"]]
        a = pp["apron_m"]
        near = (x > min(bx) - a) & (x < max(bx) + a) & (z > min(bz) - a) & (z < max(bz) + a)
        if not near.any():
            continue
        ii = np.flatnonzero(near)
        dmin = np.full(ii.shape, np.inf)
        top = np.zeros(ii.shape)
        for p in ps:
            de = np.where(polygon_inside(p["polygon"], x[ii], z[ii]), 0.0, polygon_edge_distance(p["polygon"], x[ii], z[ii]))
            closer = de < dmin
            dmin = np.where(closer, de, dmin)
            top = np.where(closer, float(p["level"]) + pp["bund_h_m"], top)
        H[ii] = top + (H[ii] - top) * smoothstep(1.0, a, dmin)
    return H


def height_field(reg, X, Z, stages=False):
    """The ground at world points X, Z (any shape; a 2D grid finds the channels block by block). Returns a dict: H,
    and what the surfaces need (aux hints, water, bed, the pounds' floors)."""
    shape = np.shape(X)
    P = Points.grid(reg, X, Z) if np.ndim(X) == 2 else Points(reg, X, Z)
    x, z = P.x, P.z
    W = cell_weights(reg, x, z)
    tot = np.zeros(x.shape)
    hu = np.zeros(x.shape)
    hv = np.zeros(x.shape)
    aux = {k: np.zeros(x.shape) for k in AUX}
    for cid in sorted(W):
        w = W[cid]
        idx = np.flatnonzero(w > 0.0)
        cell = reg.cells[cid]
        Ps = P.take(idx)
        h, v, a = recipes.RECIPES[cell["type"]](Ps, cell, cell["params"])
        wi = w[idx]
        tot[idx] += wi
        hu[idx] += wi * h
        hv[idx] += wi * v
        for k, val in a.items():
            aux[k][idx] += wi * val
    hu /= tot
    hv /= tot
    for k in aux:
        aux[k] /= tot
    hu = hu + reg.outer_rim(x, z)
    H = smin(hu, hv, SMIN_K)
    H0 = H.copy()
    # The banks at their water level.
    for c in reg.channels:
        f = P.ch(c.id)
        dp = f["dp"]
        g = f["lvl0"] + BANK_FREEBOARD * smoothstep(0.0, 4.0, dp) - np.maximum(dp - BANK_BAND, 0.0)
        H = np.where(dp >= 0.0, np.maximum(H, g), H)
    # The pounds' rims, then the water: beds, floors, bunds.
    pounds = [p for p in reg.pounds if reg.net._live(p.get("milestone", "M1"))]
    H = paddy_aprons(reg, pounds, x, z, H)
    in_pound = np.zeros(x.shape, dtype=bool)
    inside = {}
    for p in pounds:
        poly = p["polygon"]
        px = [q[0] for q in poly]
        pz = [q[1] for q in poly]
        near = (x > min(px) - 12) & (x < max(px) + 12) & (z > min(pz) - 12) & (z < max(pz) + 12)
        if not near.any():
            inside[p["id"]] = (near, None, None)
            continue
        ii = np.flatnonzero(near)
        ins = polygon_inside(poly, x[ii], z[ii])
        de = polygon_edge_distance(poly, x[ii], z[ii])
        inside[p["id"]] = (near, ins, de)
        lv = float(p["level"])
        g = lv + POUND_FREEBOARD * smoothstep(0.0, 1.5, de) - np.maximum(de - POUND_BAND, 0.0)
        H[ii] = np.where(~ins, np.maximum(H[ii], g), H[ii])
    bed = reg.net.bed_at(x, z)
    water = np.isfinite(bed)
    surface = reg.net.surface_at(x, z)
    for p in pounds:
        near, ins, de = inside[p["id"]]
        if ins is None or not ins.any():
            continue
        ii = np.flatnonzero(near)[ins]
        in_pound[ii] = True
    # The main channel's bed held from rising downstream (BedCap), most on its centre line.
    chm = reg.net.channel_at(x, z)["channel"] == reg.bedcap.cid
    m = chm & water & ~in_pound
    if m.any():
        f = P.ch(reg.bedcap.cid)
        u = np.minimum(np.abs(f["off"][m]) / f["hw"][m], 1.0)
        bed[m] = bed[m] - reg.bedcap.at(f["s"][m]) * (1.0 - u ** f["exp"])
    H = np.where(water, bed, H)
    # Where two channels' water overlaps (a mouth), each one's own bed is cut: the joining channel keeps its depth
    # through the shallow edge of the one it joins (the surface is the network's either way).
    for c in reg.channels:
        f = P.ch(c.id)
        m = water & ~in_pound & (f["dp"] < 0.0)
        if m.any():
            u = np.minimum(np.abs(f["off"][m]) / f["hw"][m], 1.0)
            own = np.minimum(np.interp(np.clip(f["s"][m], 0.0, c.length), c.ch.s, c.ch.level), surface[m]) \
                - f["bd"][m] * (1.0 - u ** f["exp"])
            H[m] = np.minimum(H[m], own)
    floor = np.zeros(x.shape, dtype=bool)        # the flat floors (pounds, paddies inside their bunds)
    for p in pounds:
        near, ins, de = inside[p["id"]]
        if ins is None or not ins.any():
            continue
        ii = np.flatnonzero(near)[ins]
        d_in = de[ins]
        if p.get("kind") == "paddy":
            pp = reg.squares["paddy"]
            top = float(p["level"]) + pp["bund_h_m"]
            H[ii] = float(p["bed"]) + (top - float(p["bed"])) * smoothstep(pp["bund_m"], pp["bund_m"] * 0.4, d_in)
            floor[ii] = d_in >= pp["bund_m"]
        else:
            floor[ii] = True
    out = {"H": H.reshape(shape), "water": water.reshape(shape), "surface": surface.reshape(shape),
           "floor": floor.reshape(shape), "in_pound": in_pound.reshape(shape),
           "aux": {k: v.reshape(shape) for k, v in aux.items()},
           "dp_min": np.minimum.reduce([P.ch(c.id)["dp"] for c in reg.channels]).reshape(shape)}
    if stages:
        out["upland"] = hu.reshape(shape)
        out["valley"] = hv.reshape(shape)
        out["H0"] = H0.reshape(shape)
    return out


# --- Surfaces ------------------------------------------------------------------------------------------------------

def surface_fields(reg, X, Z, H, hf, slope, sw):
    """Splat weights (grass, dry grass, dirt, mud, forest floor, rock), forest density, grass height, litter."""
    seed = reg.seed
    a = hf["aux"]
    water = hf["water"]
    dp = hf["dp_min"]
    rock = np.clip(np.maximum(smoothstep(34.0, 46.0, slope), a["rock"]), 0.0, 1.0)
    rock = np.where(water & ~hf["in_pound"], np.maximum(rock, 0.25 * smoothstep(0.3, 0.8, noise(seed + 1)(X / 6.0, Z / 6.0))), rock)
    pn = noise(seed + 2)(X / 3.0, Z / 3.0)
    bank = smoothstep(3.0 + pn, 0.5, dp) * (~water)
    mud = np.clip(np.maximum(np.where(water, 1.0, 0.0), 0.7 * bank), 0.0, 1.0) * (1.0 - 0.6 * rock)
    terr = np.clip(a["terrace"], 0.0, 1.0)
    dirt = np.clip(np.maximum(a["path"], 0.8 * a["pad"]) * (1.0 - mud), 0.0, 1.0)
    fd = 0.5 + 0.5 * fbm(X, Z, 70.0, 3, seed + 3)
    fd = smoothstep(0.42, 0.62, fd + np.clip(a["forest"], -1.0, 1.0))
    fd = fd * (1.0 - rock) * (1.0 - mud) * (1.0 - dirt) * (1.0 - 0.85 * terr)
    forest = smoothstep(0.3, 0.75, fd + 0.18 * noise(seed + 4)(X / 9.0, Z / 9.0)) * (1.0 - rock)
    open_ = np.clip(1.0 - forest - rock, 0.0, 1.0)
    dry = smoothstep(0.25, 0.6, fbm(X, Z, 22.0, 3, seed + 5) + 0.25 * sw) * 0.6
    rest = np.clip(1.0 - dirt - mud, 0.0, 1.0)
    w = np.stack([open_ * (1.0 - dry), open_ * dry, dirt, mud, forest, rock], -1)
    w[..., [0, 1, 4, 5]] *= rest[..., None] / np.maximum(w[..., [0, 1, 4, 5]].sum(-1, keepdims=True), 1e-6)
    w /= np.maximum(w.sum(-1, keepdims=True), 1e-6)
    gh_n = 0.5 + 0.5 * noise(seed + 6)(X / 6.0, Z / 6.0)
    gh = 0.42 + 0.2 * gh_n
    gh = np.where(fd > 0.6, 0.18 + 0.12 * gh_n, gh)
    gh = gh * (1.0 - 0.6 * terr)
    gh *= 1.0 - np.clip(dirt + mud + rock, 0.0, 1.0)
    grass_h = np.clip(gh / GRASS_H_SCALE, 0.0, 1.0)
    litter = np.clip(0.5 + 0.6 * fbm(X, Z, 45.0, 2, seed + 7), 0.0, 1.0)
    return {"w": w, "fd": fd, "grass_h": grass_h, "litter": litter}


def ambient_occlusion(H):
    """Horizon angles in 8 directions out to 48 m (bake_terrain.py)."""
    NM = H.shape[0]
    ao = np.zeros_like(H)
    pad = 48
    Hp = np.pad(H, pad, mode="edge")
    for (di, dj) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)]:
        best = np.zeros_like(H)
        for dist in (2, 4, 8, 16, 32, 48):
            si = int(round(di * dist / math.hypot(di, dj)))
            sj = int(round(dj * dist / math.hypot(di, dj)))
            sh = Hp[pad + sj:pad + sj + NM, pad + si:pad + si + H.shape[1]]
            best = np.maximum(best, (sh - H) / math.hypot(si, sj))
        ao += 1.0 - np.sin(np.arctan(best))
    return np.clip(ao / 8.0, 0.0, 1.0)


def square_grid(reg, cid, margin=MARGIN):
    c = reg.cells[cid]
    ax = np.arange(N + 2 * margin, dtype=np.float64) - HALF - margin
    X, Z = np.meshgrid(ax + c["cx"], ax + c["cz"])
    return X, Z


def bake_square(reg, cid, out_dir, previews=True, quiet=False):
    t0 = time.time()
    c = reg.cells[cid]
    os.makedirs(out_dir, exist_ok=True)
    X, Z = square_grid(reg, cid)
    hf = height_field(reg, X, Z)
    H = hf["H"]
    crop = (slice(MARGIN, MARGIN + N), slice(MARGIN, MARGIN + N))
    Hs = blur(H, 2.0)
    gz, gx = np.gradient(Hs)
    slope = np.degrees(np.arctan(np.hypot(gx, gz)))
    nlen = np.sqrt(gx * gx + gz * gz + 1.0)
    nx, nz = -gx / nlen, -gz / nlen
    sw = (nx * SUN_XZ[0] + nz * SUN_XZ[1]) / np.maximum(np.hypot(nx, nz), 0.05) * smoothstep(0.02, 0.15, np.hypot(nx, nz))
    s = surface_fields(reg, X, Z, H, hf, slope, sw)
    gz1, gx1 = np.gradient(H)
    nl = np.sqrt(gx1 * gx1 + gz1 * gz1 + 1.0)
    NX, NZ = -gx1 / nl, -gz1 / nl
    ao = ambient_occlusion(H)
    w = s["w"]
    splat0 = np.stack([to_u8(w[..., 0]), to_u8(w[..., 1]), to_u8(w[..., 2]), to_u8(w[..., 3])], -1)
    splat1 = np.stack([to_u8(w[..., 4]), to_u8(w[..., 5]), to_u8(s["fd"]), to_u8(s["grass_h"])], -1)
    normal = np.stack([to_u8(NX * 0.5 + 0.5), to_u8(NZ * 0.5 + 0.5), to_u8(ao), to_u8(s["litter"])], -1)
    raw_slope = np.degrees(np.arctan(np.hypot(gx1, gz1)))

    # The square's own grid from here on.
    Xc, Zc = X[crop], Z[crop]
    H = H[crop]
    splat0, splat1, normal, w = splat0[crop], splat1[crop], normal[crop], w[crop]
    NX, NZ, ao, raw_slope = NX[crop], NZ[crop], ao[crop], raw_slope[crop]
    fd, gh = s["fd"][crop], s["grass_h"][crop]
    water = hf["water"][crop]

    # Grass cell maxima (8 m cells, 1 m margin), as bake_terrain.py.
    meadow = w[..., 0] + w[..., 1]
    fshare = w[..., 4] / np.maximum(meadow + w[..., 4], 1e-3)
    bare = np.clip(w[..., 2] + w[..., 3] + w[..., 5], 0, 1)
    loc = np.clip(1.0 - bare * 1.25, 0, 1) * (1.0 - 0.7 * fshare) * (gh * GRASS_H_SCALE > 0.03)
    ncell = N // 8
    gcell = np.zeros((ncell, ncell))
    sheer = np.zeros((ncell, ncell), dtype=np.uint8)
    steep = raw_slope > 60.0
    for cj in range(ncell):
        for ci in range(ncell):
            j0, i0 = cj * 8, ci * 8
            blk = loc[max(j0 - 1, 0):j0 + 10, max(i0 - 1, 0):i0 + 10]
            gcell[cj, ci] = blk.max() if blk.size else 0.0
            sheer[cj, ci] = 1 if steep[j0:j0 + 8, i0:i0 + 8].mean() > 0.5 else 0
    grass_cells = to_u8(np.minimum(gcell * 1.05 + 0.02 * (gcell > 0), 1.0))

    # Macro noise tile: the same for every square (bake_terrain.py).
    t = np.arange(256) / 256.0
    TX, TZ = np.meshgrid(t, t)
    macro = []
    for per, sd in [(2, 901), (4, 902), (16, 903), (64, 904)]:
        p = Perlin(sd, period=per)
        v = p(TX * per, TZ * per)
        if per < 64:
            p2 = Perlin(sd + 50, period=per * 2)
            v = 0.7 * v + 0.3 * p2(TX * per * 2, TZ * per * 2)
        macro.append(to_u8(np.clip(v * 0.5 + 0.5, 0, 1)))
    macro = np.stack(macro, -1)

    nch = (N - 1) // CHUNK
    bounds = np.zeros((nch, nch, 2), np.float32)
    for cj in range(nch):
        for ci in range(nch):
            blk = H[cj * CHUNK:cj * CHUNK + CHUNK + 1, ci * CHUNK:ci * CHUNK + CHUNK + 1]
            bounds[cj, ci] = (blk.min(), blk.max())

    # Surface overlay colliders: 1 m cells of mostly dirt / mud (paths, banks, beds) or rock, over the whole square.
    cellw = (w[:-1, :-1] + w[1:, 1:] + w[1:, :-1] + w[:-1, 1:]) * 0.25
    dirt_cells = np.argwhere(cellw[..., 2] + cellw[..., 3] > 0.5)
    stone_cells = np.argwhere(cellw[..., 5] > 0.55)
    dirt_idx = (dirt_cells[:, 0] * N + dirt_cells[:, 1]).astype(np.int32)
    stone_idx = (stone_cells[:, 0] * N + stone_cells[:, 1]).astype(np.int32)

    H32 = H.astype("<f4")
    H32.tofile(os.path.join(out_dir, "height.bin"))
    H32.tofile(os.path.join(out_dir, "collision.bin"))       # no flat zones in a region square
    splat0.tofile(os.path.join(out_dir, "splat0.bin"))
    splat1.tofile(os.path.join(out_dir, "splat1.bin"))
    normal.tofile(os.path.join(out_dir, "normal.bin"))
    macro.tofile(os.path.join(out_dir, "macro.bin"))
    bounds.astype("<f4").tofile(os.path.join(out_dir, "bounds.bin"))
    dirt_idx.astype("<i4").tofile(os.path.join(out_dir, "overlay_dirt.bin"))
    stone_idx.astype("<i4").tofile(os.path.join(out_dir, "overlay_stone.bin"))
    grass_cells.tofile(os.path.join(out_dir, "grass_cells.bin"))
    sheer.tofile(os.path.join(out_dir, "sheer_cells.bin"))

    P0 = Points(reg, np.zeros(1), np.zeros(1))
    typ = reg.squares["types"][c["type"]]
    stats = {
        "height_min": float(H.min()), "height_max": float(H.max()),
        "slope_max_deg": float(raw_slope.max()), "slope_p99_deg": float(np.percentile(raw_slope, 99)),
        "water_share": float(water.mean()), "forest_share": float((fd > 0.5).mean()),
        "layer_share": [float(v) for v in w.reshape(-1, 6).mean(0)],
        "dirt_overlay_cells": int(dirt_idx.size), "stone_overlay_cells": int(stone_idx.size),
        "sheer_cells": int(sheer.sum()),
        "grass_cells_empty_share": float((grass_cells == 0).mean()),
        "bake_s": round(time.time() - t0, 2),
    }
    meta = {"N": N, "half": HALF, "chunk": CHUNK, "core": [0, 0, 0, 0, 0.25], "grass_cells": int(N // 8),
            "core_size": [0, 0], "grass_h_scale": GRASS_H_SCALE, "macro_size": 256,
            "region": reg.squares["region"], "square": cid, "origin": [c["cx"], c["cz"]], "type": c["type"],
            "recipe_status": typ["status"], "params": c["params"], "milestone_carved": "M2",
            "inputs": reg.inputs, "code": code_hash(),
            "footprints": recipes.footprints(P0, c, c["type"], c["params"]),
            "stats": stats}
    with open(os.path.join(out_dir, "meta.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    if previews:
        shade = np.clip(0.35 + 0.65 * (NX * -0.64 + 0.33 + NZ * 0.70) / 1.1, 0, 1)
        hn = (H - H.min()) / max(H.max() - H.min(), 1e-6)
        Image.fromarray(to_u8(hn * 0.6 + shade * 0.4)).save(os.path.join(out_dir, "preview_height.png"))
        cols = np.array([[0.40, 0.50, 0.22], [0.66, 0.62, 0.36], [0.62, 0.40, 0.26], [0.30, 0.24, 0.16],
                         [0.16, 0.30, 0.14], [0.62, 0.62, 0.58]])
        rgb = (w @ cols) * (0.6 + 0.4 * shade[..., None]) * (1 - 0.35 * fd[..., None])
        rgb = np.where(water[..., None], rgb * 0.5 + np.array([0.12, 0.24, 0.32]), rgb)
        Image.fromarray(to_u8(rgb)).save(os.path.join(out_dir, "preview_splat.png"))
    if not quiet:
        print("%s %-17s %6.1f..%6.1f m  %5.1f s" % (cid, c["type"], stats["height_min"], stats["height_max"],
                                                   stats["bake_s"]))
    return meta


def code_hash():
    h = hashlib.sha1()
    for name in ("common.py", "recipes_thuyvan.py", "bake_region.py"):
        with open(os.path.join(HERE, name), "rb") as fh:
            h.update(fh.read())
    with open(os.path.join(ROOT, "tools", "environment", "water", "water_net.py"), "rb") as fh:
        h.update(fh.read())
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cell", default="", help="cells to bake, e.g. C1,B1 (default: all)")
    ap.add_argument("--layout", default=LAYOUT)
    ap.add_argument("--out", default=None, help="default tools/environment/terrain/build_regions/<region>/")
    ap.add_argument("--no-previews", action="store_true")
    args = ap.parse_args()
    reg = Region(args.layout)
    out = args.out or os.path.join(OUT_ROOT, reg.squares["region"])
    cells = [c for c in args.cell.split(",") if c] or sorted(reg.cells)
    for cid in cells:
        bake_square(reg, cid, os.path.join(out, cid), previews=not args.no_previews)


if __name__ == "__main__":
    main()
