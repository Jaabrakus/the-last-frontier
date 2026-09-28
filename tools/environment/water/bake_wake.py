#!/usr/bin/env python3
"""The river's boulders' white water as a map (RiverWater, shaders/water/river.gdshader; user 2026-09-28: the rapids
"hard to see and doesnt make it look good", "the rocks white looks good", "keep the v trail make it less powerfull",
"lose the inside of the v circle around the rock"): for each boulder (data/world/river_boulders.json), the water piling
white on its upstream face (the pillow) and round its sides where it meets the rock, and, fainter (V_WHITE), the two
shear lines of the V it trails downstream from its sides (widening, fading); inside the V, behind the rock, clear.
Where the V's of boulders near one another meet, they run together ("some v's can combine together"): the trails are
added up and eased toward white (1 - e^-x), so arms that cross or come alongside fill in as one band. Over the river's box at PX_M m a pixel, one channel (0..255), with the box
in a JSON beside it:

    python3 tools/environment/water/bake_wake.py

writes assets/environment/water/river_wake.png and river_wake.json ({x0, z0, width_m, depth_m}). Rerun when the river
or its boulders change (bake_terrain.py writes the boulders).
"""
import json, math, os, zlib, struct
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
PX_M = 0.25
MARGIN = 20.0
TRAIL = 5.0          # the V's length, in the boulder's radii
V_WHITE = 0.45       # how white its shear lines (the pillow and ring: 1)
ARM_TOP = 0.9        # the trails added up, eased toward this: ARM_TOP (1 - e^(-sum ARM_K))
ARM_K = 1.6


def river():
    d = json.load(open(os.path.join(ROOT, "data/world/squares.json")))["river"]
    return d


def x_at(rv, z):
    x = rv.get("x0", 832.0)
    for a, w, p in rv.get("meanders", []):
        x += a * math.sin(z / w + p)
    return x


def flow_at(rv, z):
    dx = 0.0
    for a, w, p in rv.get("meanders", []):
        dx += a / w * math.cos(z / w + p)
    n = math.hypot(dx, 1.0)
    return dx / n, 1.0 / n


def write_png(path, a):
    h, w = a.shape
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def main():
    rv = river()
    bl = json.load(open(os.path.join(ROOT, "data/world/river_boulders.json")))["boulders"]
    size = 832.0
    z0, z1 = -size * 0.5, size * 0.5
    xs = [x_at(rv, z) for z in np.arange(z0, z1 + 1, 4.0)]
    x0 = min(xs) - rv.get("bank", 14.0) - MARGIN
    x1 = max(xs) + rv.get("bank", 14.0) + MARGIN
    w = int(math.ceil((x1 - x0) / PX_M))
    h = int(math.ceil((z1 - z0) / PX_M))
    m = np.zeros((h, w), np.float32)
    arms = np.zeros((h, w), np.float32)
    rng = np.random.default_rng(1765)
    for bx, bz, r, top in bl:
        fx, fz = flow_at(rv, bz)
        reach = r * (TRAIL + 2.0)
        i0 = max(int((bx - reach - x0) / PX_M), 0)
        i1 = min(int((bx + reach - x0) / PX_M) + 1, w)
        j0 = max(int((bz - reach - z0) / PX_M), 0)
        j1 = min(int((bz + reach - z0) / PX_M) + 1, h)
        X, Z = np.meshgrid(x0 + (np.arange(i0, i1) + 0.5) * PX_M, z0 + (np.arange(j0, j1) + 0.5) * PX_M)
        rx, rz = X - bx, Z - bz
        along = rx * fx + rz * fz
        across = -rx * fz + rz * fx
        # the trail bends a little with the eddies (each boulder its own)
        across = across + 0.25 * r * np.sin(along / (1.3 * r) + rng.uniform(0, 6.28))
        d = np.hypot(rx, rz)
        # round its upstream face and sides only: none behind it
        ring = 0.7 * np.exp(-((d - r * 0.92) / (0.14 * r)) ** 2) * np.clip((0.3 * r - along) / (0.6 * r), 0.0, 1.0)
        pillow = np.where(along < 0.0, np.exp(-((d - r * 1.12) / (0.26 * r)) ** 2) * np.clip(-along / r + 0.2, 0.0, 1.0), 0.0)
        t = np.clip(along / (r * TRAIL), 0.0, 1.0)
        half = r * (0.85 + 0.32 * np.maximum(along, 0.0) / r)
        width = 0.18 * r + 0.05 * np.maximum(along, 0.0)
        shear = np.where(along > 0.0, np.exp(-((np.abs(across) - half) / width) ** 2) * (1.0 - t) ** 1.6, 0.0)
        inside = d < r * 0.8
        m[j0:j1, i0:i1] = np.maximum(m[j0:j1, i0:i1], np.where(inside, 0.0, np.maximum(ring, pillow)))
        arms[j0:j1, i0:i1] += np.where(inside, 0.0, shear * V_WHITE)
    # the V's run together where they meet (a lone arm stays V_WHITE)
    m = np.maximum(m, ARM_TOP * (1.0 - np.exp(-arms * ARM_K)))
    a = (np.clip(m, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    out = os.path.join(ROOT, "assets/environment/water")
    os.makedirs(out, exist_ok=True)
    write_png(os.path.join(out, "river_wake.png"), a)
    json.dump({"_doc": "The river's boulders' white water map's box (bake_wake.py): world x0, z0 at pixel (0, 0), its size in m.",
               "x0": round(x0, 3), "z0": z0, "width_m": w * PX_M, "depth_m": h * PX_M},
              open(os.path.join(out, "river_wake.json"), "w"), indent=1)
    print("wake map %d x %d px (%.0f x %.0f m), %d boulders, %.1f%% white" % (w, h, w * PX_M, h * PX_M, len(bl), 100.0 * (m > 0.3).mean()))


if __name__ == "__main__":
    main()
