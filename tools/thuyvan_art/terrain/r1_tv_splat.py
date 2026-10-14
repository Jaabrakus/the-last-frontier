#!/usr/bin/env python3
"""R1's painted-ground splat (vista_spec.md 4 "Splat, painted slices"): the twelve tv_terrain slices' weights for every
square of T4's bake, derived from the bake itself and the layout. The bake's own splat is the frontier's six layers; the
painted array has twelve (assets/thuyvan/paint/terrain/terrain_slices.json):

    0 grass  1 terrace rice  2 forest floor  3 dirt path  4 laterite  5 paddy mud  6 karst rock  7 white stone
    8 moss and fern  9 river bank  10 cliff face (the shader's triplanar over 38 deg)  11 meadow

Reads, per square, tools/environment/terrain/build_regions/r1/<cell>/ (height.bin, splat0.bin, splat1.bin; T4's bake,
git-ignored: rerun tools/environment/terrain/regions/bake_region.py when missing) and the recipes' own hints (terrace
steps, risers, trails, pads) and water (channels, pounds) by re-running bake_region.height_field over the square's grid,
which reproduces the bake exactly (checked: the heights agree). Writes tv_splat0/1/2.bin (RGBA8 833 x 833: slices 0-3,
4-7, 8-11, the strongest scaled to 255; the shader normalises) beside them, and with --preview a stitched map.

    python3 tools/thuyvan_art/terrain/r1_tv_splat.py [--cell C1,B1] [--preview out.png]

Rules (vista_spec 4), strongest last:
    grass / meadow      the bake's open ground, split by its dry-grass weight (meadow is the warmer, flowered slice)
    forest floor        the bake's forest-floor weight (its forest density over 0.5)
    karst rock          the bake's rock weight (slopes 34-46 deg and the recipes' rock); the shader takes over past 38
    terrace rice        the recipes' terrace steps; laterite on their risers (the exposed bank under each edge)
    dirt path           the recipes' trails and pads, and the vista's trails (TRAILS: landmark to landmark, 2 m wide)
    river bank          the bake's bank mud along the channels, 4-8 m out; the lock's pounds
    white stone         the channels' beds and within 4 m of the waterline (Đá Trắng's white gravel)
    paddy mud           inside the paddy pounds and on their bunds
    moss and fern       within 25 m of a fall's foot (FALLS)
"""
import argparse
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "environment", "terrain", "regions"))
import bake_region as br  # noqa: E402
from common import noise, smoothstep  # noqa: E402

BUILD = os.path.join(br.OUT_ROOT, "r1")
N = br.N

# The vista's trails (x, z polylines; vista_spec D5-D7, D18-D19 and the layout's landmarks). Wobble added below.
TRAILS = [
    # the village down to the west bridge head and its gate pavilion
    [(0, -1248), (180, -1250), (380, -1236), (560, -1222), (700, -1218), (745, -1215)],
    # the village to the clan house and up to the rope-rite cliff
    [(0, -1248), (40, -1300), (60, -1330), (-60, -1400), (-150, -1450)],
    # the village to the paddies and on to the survey camp
    [(0, -1248), (60, -1190), (130, -1120), (300, -1060), (480, -1020), (650, -1000)],
    # the east bridge head along the lip: the waystone, the cairns north, the gorge south
    [(893, -1215), (905, -1228), (915, -1240), (930, -1300), (900, -1450), (760, -1560), (700, -1580)],
    [(893, -1215), (930, -1150), (960, -1000), (930, -832)],
    # the village west to the high pass and the waystones
    [(0, -1248), (-250, -1300), (-520, -1360), (-832, -1400), (-900, -1600)],
    # the shrine house down to the Two Heights bridge
    [(100, -500), (-200, -520), (-500, -540), (-760, -560), (-832, -545)],
]
TRAIL_W = 2.0
# Falls' feet (x, z): F1, F2 into the gorge (vista_spec D9: lips at x 752 / 750, the river below), the torrent's (D10)
FALLS = [(812, -1150), (808, -1330), (-600, -440), (-200, -415)]
MOSS_R = 25.0
SLICES = 12
# Open ground where the cameras and the bridge heads stand (x, z, radius): the dressing keeps trees off them, so the
# bake's forest floor there turns to meadow and grass (a lip in the sun, not dark litter with no trees over it).
OPEN_GROUND = [(930, -1245, 95), (900, -1210, 50), (745, -1215, 50), (-540, -400, 150), (857, -1180, 40)]


def trail_distance(X, Z):
    """Distance (m) from each point to the nearest trail, the trails wobbling a few metres (a foot path, not a road)."""
    d = np.full(X.shape, 1e9)
    for pts in TRAILS:
        dense = []
        for (x0, z0), (x1, z1) in zip(pts[:-1], pts[1:]):
            n = max(int(np.hypot(x1 - x0, z1 - z0) / 4.0), 1)
            for k in range(n):
                t = k / n
                x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
                x += 3.0 * np.sin(z / 23.0 + x / 41.0)
                z += 3.0 * np.sin(x / 29.0 - z / 37.0)
                dense.append((x, z))
        dense.append(pts[-1])
        P = np.asarray(dense)
        for (x0, z0), (x1, z1) in zip(P[:-1], P[1:]):
            # only near the segment's box
            lo_x, hi_x = min(x0, x1) - 10, max(x0, x1) + 10
            lo_z, hi_z = min(z0, z1) - 10, max(z0, z1) + 10
            m = (X >= lo_x) & (X <= hi_x) & (Z >= lo_z) & (Z <= hi_z)
            if not m.any():
                continue
            dx, dz = x1 - x0, z1 - z0
            L2 = max(dx * dx + dz * dz, 1e-6)
            t = np.clip(((X[m] - x0) * dx + (Z[m] - z0) * dz) / L2, 0.0, 1.0)
            dd = np.hypot(X[m] - (x0 + t * dx), Z[m] - (z0 + t * dz))
            d[m] = np.minimum(d[m], dd)
    return d


def paddy_mask(reg, X, Z):
    """1 inside a paddy pound and on its bund (1 m round it), soft at the outer edge."""
    out = np.zeros(X.shape)
    for p in reg.pounds:
        if p.get("kind") != "paddy":
            continue
        poly = np.asarray(p["polygon"], dtype=np.float64)
        x0, z0 = poly[:, 0].min(), poly[:, 1].min()
        x1, z1 = poly[:, 0].max(), poly[:, 1].max()
        dx = np.maximum(np.maximum(x0 - X, X - x1), 0.0)
        dz = np.maximum(np.maximum(z0 - Z, Z - z1), 0.0)
        out = np.maximum(out, smoothstep(1.8, 0.8, np.hypot(dx, dz)))
    return out


def square_splat(reg, cid):
    c = reg.cells[cid]
    d = os.path.join(BUILD, cid)
    H = np.fromfile(os.path.join(d, "height.bin"), "<f4").reshape(N, N).astype(np.float64)
    s0 = np.fromfile(os.path.join(d, "splat0.bin"), np.uint8).reshape(N, N, 4) / 255.0
    s1 = np.fromfile(os.path.join(d, "splat1.bin"), np.uint8).reshape(N, N, 4) / 255.0
    X, Z = br.square_grid(reg, cid, margin=0)
    hf = br.height_field(reg, X, Z)
    if np.abs(hf["H"] - H).max() > 0.05:
        print("warning: %s's bake is not the current recipes' (rerun bake_region.py)" % cid, file=sys.stderr)
    a = hf["aux"]
    water = hf["water"] & ~hf["in_pound"]
    dp = hf["dp_min"]                               # m past the nearest channel's waterline (< 0 in the water)
    seed = reg.seed + 31
    n1 = 0.5 + 0.5 * noise(seed)(X / 17.0, Z / 17.0)
    n2 = 0.5 + 0.5 * noise(seed + 1)(X / 5.0, Z / 5.0)

    w = np.zeros((N, N, SLICES))
    grass, dry, dirt, mud, forest, rock = s0[..., 0], s0[..., 1], s0[..., 2], s0[..., 3], s1[..., 0], s1[..., 1]
    w[..., 0] = grass * (0.75 + 0.25 * n1)
    w[..., 11] = dry + grass * 0.35 * (1.0 - n1)
    w[..., 2] = forest
    for ox, oz, r in OPEN_GROUND:
        f = smoothstep(r, r * 0.55, np.hypot(X - ox, Z - oz) + 8.0 * (n1 - 0.5))
        w[..., 11] += forest * f * (0.45 + 0.4 * n2)
        w[..., 0] += forest * f * (0.75 - 0.4 * n2)
        w[..., 2] *= 1.0 - f
    w[..., 6] = rock
    # terraces: rice on the steps, laterite on the risers
    terr = np.clip(a["terrace"], 0.0, 1.0)
    riser = np.clip(a["riser"], 0.0, 1.0) * terr
    keep = 1.0 - terr
    w[..., [0, 2, 6, 11]] *= keep[..., None]
    w[..., 1] = np.maximum(w[..., 1], terr * (1.0 - riser) * 1.2)
    w[..., 4] = np.maximum(w[..., 4], riser * 1.4)
    w[..., 0] += riser * 0.35 * n2                  # grass lips on the risers
    # paths: the recipes' and the vista's trails
    td = trail_distance(X, Z)
    path = np.maximum(np.clip(np.maximum(a["path"], 0.8 * a["pad"]), 0.0, 1.0), dirt)
    path = np.maximum(path, smoothstep(TRAIL_W + 1.2, TRAIL_W * 0.5, td + 0.8 * (n2 - 0.5)))
    w[..., 3] = path * 1.6
    # the banks: river silt 4-8 m out, white stone in the bed and within 4 m of the waterline
    bank = smoothstep(9.0 + 2.0 * n1, 4.0, dp) * (~water)
    w[..., 9] = np.maximum(w[..., 9], np.maximum(bank, mud * (~water)) * 1.2)
    white = np.where(water, 1.0, smoothstep(4.5 + 1.5 * (n2 - 0.5), 2.5, dp))
    w[..., 7] = white * 2.2
    w[..., 9] += np.where(water, 0.5 * smoothstep(0.55, 0.85, n1), 0.0)
    # pounds: paddy mud in the paddies and on their bunds; the lock's and the basin's floors are bank silt
    pad = paddy_mask(reg, X, Z)
    other = hf["in_pound"] & (pad < 0.5)
    w[..., 5] = pad * 3.0
    w[..., 9] = np.where(other, 3.0, w[..., 9])
    # moss and fern by the falls' feet
    moss = np.zeros((N, N))
    for fx, fz in FALLS:
        r = np.hypot(X - fx, Z - fz)
        moss = np.maximum(moss, smoothstep(MOSS_R, MOSS_R * 0.3, r + 6.0 * (n2 - 0.5)))
    w[..., 8] = moss * 1.8
    # the strongest weight wins its pixel's 8 bits (the shader normalises)
    m = np.maximum(w.max(-1, keepdims=True), 1e-6)
    u8 = np.clip(np.round(w / m * 255.0), 0, 255).astype(np.uint8)
    for k in range(3):
        np.ascontiguousarray(u8[..., k * 4:k * 4 + 4]).tofile(os.path.join(d, "tv_splat%d.bin" % k))
    return w / m


# preview colours per slice (the slices' mean sRGB, terrain_slices.json; the cliff face as karst)
def slice_colours():
    import json
    meta = json.load(open(os.path.join(ROOT, "assets", "thuyvan", "paint", "terrain", "terrain_slices.json")))
    cols = np.zeros((SLICES, 3))
    for s in meta["slices"]:
        cols[int(s["slice"])] = s.get("mean_srgb", [0.5, 0.5, 0.5])
    return cols


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cell", default="")
    ap.add_argument("--preview", default="")
    args = ap.parse_args()
    reg = br.Region()
    cells = [c for c in args.cell.split(",") if c] or sorted(reg.cells)
    missing = [c for c in cells if not os.path.exists(os.path.join(BUILD, c, "height.bin"))]
    if missing:
        sys.exit("no bake for %s: run tools/environment/terrain/regions/bake_region.py first" % ",".join(missing))
    cols = slice_colours()
    tiles = {}
    for cid in cells:
        w = square_splat(reg, cid)
        print("%s  %s" % (cid, " ".join("%d:%.2f" % (k, v) for k, v in enumerate((w / np.maximum(w.sum(-1, keepdims=True), 1e-6))
                                                                                   .reshape(-1, SLICES).mean(0)) if v > 0.005)))
        if args.preview:
            rgb = (w / np.maximum(w.sum(-1, keepdims=True), 1e-6)) @ cols
            tiles[cid] = rgb[::2, ::2]
    if args.preview:
        from PIL import Image
        cs = sorted({reg.cells[c]["col"] for c in tiles})
        rs = sorted({reg.cells[c]["row"] for c in tiles})
        t = next(iter(tiles.values())).shape[0]
        img = np.zeros((len(rs) * t, len(cs) * t, 3))
        for cid, rgb in tiles.items():
            c = reg.cells[cid]
            img[rs.index(c["row"]) * t:(rs.index(c["row"]) + 1) * t, cs.index(c["col"]) * t:(cs.index(c["col"]) + 1) * t] = rgb
        Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8)).save(args.preview)
        print("preview ->", args.preview)


if __name__ == "__main__":
    main()
