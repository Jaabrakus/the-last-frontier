#!/usr/bin/env python3
"""Relief views of a region's baked terrain, for the owner and the builders (numpy + PIL only, system fonts).

    python3 tools/environment/terrain/regions/relief_views.py --out DIR [--bake DIR] [--only variants,region,internal]

Owner-facing (shaded perspective renders, flat water planes from the water network, plain captions):
  variants_C1.png ... variants_B2.png   each slice square from one camera, its A/B/C variants side by side (squares.json
                                        "variants": gorge depth and walls, terrace steps, ferry bank, hairpins)
  r1_relief.png                         the whole region stitched from the bake, the water in place
Internal (for the builders):
  squares_hillshade_splat.png           each square's hillshade over its splat colours, by type
  r1_hillshade_network.png              the stitched hillshade with the water network drawn over it

The renderer casts one ray per screen column over the height field, front to back, and fills each pixel from the
first sample that rises above it (no pitch distortion: the camera's tilt shifts the horizon). Ground is lit by one
sun plus sky light, fogged with distance; water is a flat plane at the network's surface (its level, the pounds').
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bake_region as br  # noqa: E402
from common import blur, fbm, noise, smoothstep  # noqa: E402

FONT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
SKY_TOP = np.array([0.55, 0.68, 0.80])
SKY_HAZE = np.array([0.82, 0.86, 0.86])
SUN = np.array([-0.45, 0.62, 0.64])          # toward the sun (x, y, z): morning light from the south-west
SUN = SUN / np.linalg.norm(SUN)
WATER_DEEP = np.array([0.16, 0.30, 0.30])
WATER_SKY = np.array([0.62, 0.72, 0.76])

# Albedo palette (tropical north: wet greens, ochre laterite, grey limestone).
C_GRASS = np.array([0.36, 0.50, 0.20])
C_DRY = np.array([0.58, 0.56, 0.30])
C_FOREST = np.array([0.13, 0.27, 0.12])
C_TERRACE = np.array([0.50, 0.62, 0.26])
C_ROCK = np.array([0.60, 0.60, 0.56])
C_PATH = np.array([0.66, 0.44, 0.27])
C_MUD = np.array([0.36, 0.30, 0.22])


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


# --- Colours and light ------------------------------------------------------------------------------------------

def albedo(H, aux, water_mask, seed, x, z, res):
    """Ground colour from slope, the recipes' hints and noise (a picture's palette, not the game's splat)."""
    gz, gx = np.gradient(blur(H, 1.0), res)
    slope = np.degrees(np.arctan(np.hypot(gx, gz)))
    rock = np.clip(np.maximum(smoothstep(33.0, 45.0, slope), aux["rock"]), 0, 1)
    forest_n = 0.5 + 0.5 * fbm(x, z, 90.0, 4, seed + 3) + np.clip(aux["forest"], -1, 1) \
        + 0.35 * smoothstep(8.0, 22.0, slope)
    forest = smoothstep(0.42, 0.58, forest_n) * (1 - rock)
    terr = np.clip(aux["terrace"], 0, 1)
    forest = forest * (1 - 0.9 * terr)
    path = np.clip(np.maximum(aux["path"], 0.8 * aux["pad"]), 0, 1)
    dry = 0.4 * smoothstep(0.3, 0.7, 0.5 + 0.5 * fbm(x, z, 30.0, 2, seed + 5))
    c = C_GRASS * (1 - dry)[..., None] + C_DRY * dry[..., None]
    c = c * (1 - terr)[..., None] + C_TERRACE * terr[..., None]
    c = c * (1 - 0.6 * aux["riser"])[..., None] + C_GRASS * 0.8 * (0.6 * aux["riser"])[..., None]
    crowns = 0.7 + 0.6 * (0.5 + 0.5 * noise(seed + 8)(x / 5.0, z / 5.0)) * (0.5 + 0.5 * noise(seed + 7)(x / 13.0, z / 13.0))
    c = c * (1 - forest)[..., None] + (C_FOREST * crowns[..., None]) * forest[..., None]
    c = c * (1 - rock)[..., None] + C_ROCK * rock[..., None]
    c = c * (1 - path)[..., None] + C_PATH * path[..., None]
    c = np.where(water_mask[..., None], C_MUD, c)
    var = 0.9 + 0.2 * (0.5 + 0.5 * noise(seed + 9)(x / 4.0, z / 4.0))
    return c * var[..., None], forest


def lit(H, col, forest, res):
    gz, gx = np.gradient(H, res)
    n = np.stack([-gx, np.ones_like(H), -gz], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    lam = np.clip(n @ SUN, 0, 1)
    sky = 0.5 + 0.5 * n[..., 1]
    occl = np.clip(1.0 - 0.6 * np.clip(blur(H, 6.0) - H, 0, 6) / 6.0, 0.4, 1.0)
    light = (0.9 * lam + 0.38 * sky) * occl * (1 - 0.25 * forest)
    return col * light[..., None]


# --- The renderer ---------------------------------------------------------------------------------------------------

def render(H, surf, rgb, x0, z0, res, cam, target, size=(960, 600), fov=55.0, far=4000.0, haze=2600.0, ss=2):
    """H, surf (water surface, nan where none) and rgb are grids (row = z) with sample [0, 0] at (x0, z0) and `res`
    m between samples. cam and target are (x, y, z)."""
    W, R = size[0] * ss, size[1] * ss
    f = 0.5 * W / math.tan(math.radians(fov) * 0.5)
    fx, fz = target[0] - cam[0], target[2] - cam[2]
    L = math.hypot(fx, fz)
    fx, fz = fx / L, fz / L
    rx, rz = -fz, fx                             # the screen's right on the ground (x right when looking -z: east)
    pitch = math.atan2(cam[1] - target[1], L)
    horizon = R * 0.5 - f * math.tan(pitch)
    u = (np.arange(W) - W * 0.5 + 0.5) / f
    d = [2.0]
    while d[-1] < far:
        d.append(d[-1] + max(0.35 * res, d[-1] * 0.0035))
    d = np.asarray(d)
    top = np.where(np.isfinite(surf), np.maximum(surf, H), H)
    wat = np.isfinite(surf) & (surf > H)
    floor_h = float(np.nanmin(H)) - 400.0
    out = np.zeros((R, W, 3))
    ymin_all = np.zeros((len(d), W))
    cols = np.zeros((len(d), W, 3))
    ny, nx = H.shape
    for k0 in range(0, len(d), 256):
        dk = d[k0:k0 + 256][:, None]
        px = cam[0] + dk * (fx + u[None, :] * rx)
        pz = cam[2] + dk * (fz + u[None, :] * rz)
        fi = (px - x0) / res
        fj = (pz - z0) / res
        inside = (fi >= 0) & (fi < nx - 1) & (fj >= 0) & (fj < ny - 1)
        i = np.clip(np.floor(fi).astype(np.int64), 0, nx - 2)
        j = np.clip(np.floor(fj).astype(np.int64), 0, ny - 2)
        a = np.clip(fi - i, 0, 1)[..., None]
        b = np.clip(fj - j, 0, 1)[..., None]
        hh = (top[j, i] * (1 - a[..., 0]) + top[j, i + 1] * a[..., 0]) * (1 - b[..., 0]) \
            + (top[j + 1, i] * (1 - a[..., 0]) + top[j + 1, i + 1] * a[..., 0]) * b[..., 0]
        c = (rgb[j, i] * (1 - a) + rgb[j, i + 1] * a) * (1 - b) + (rgb[j + 1, i] * (1 - a) + rgb[j + 1, i + 1] * a) * b
        ww = wat[j, i] | wat[j + 1, i + 1]
        fres = np.clip(1.0 - (cam[1] - hh) / dk / 0.35, 0.0, 1.0)[..., None]
        wc = WATER_DEEP * (1 - fres) + WATER_SKY * fres
        c = np.where(ww[..., None], wc, c)
        fog = (1.0 - np.exp(-dk / haze))[..., None]
        c = c * (1 - fog) + SKY_HAZE * fog
        # Past the grid the edge runs on, falling away into the haze, so the ground's edge is never a cut wall.
        out_m = np.maximum.reduce([-fi, fi - (nx - 1), -fj, fj - (ny - 1), np.zeros_like(fi)]) * res
        hh = np.maximum(hh - out_m * 0.9, floor_h)
        mist = smoothstep(0.0, 260.0, out_m)[..., None]
        c = c * (1 - mist) + SKY_HAZE * mist
        y = horizon + (cam[1] - hh) / dk * f
        ymin_all[k0:k0 + 256] = y
        cols[k0:k0 + 256] = c
    ymin = np.minimum.accumulate(ymin_all, axis=0)
    rows = np.arange(R) + 0.5
    sky_t = np.clip((rows - (horizon - R * 0.6)) / (R * 0.6), 0, 1)[:, None]
    sky = SKY_TOP * (1 - sky_t) + SKY_HAZE * sky_t
    for c_ in range(W):
        k = np.searchsorted(-ymin[:, c_], -rows, side="left")
        hit = k < len(d)
        out[:, c_] = np.where(hit[:, None], cols[np.minimum(k, len(d) - 1), c_], sky)
    img = Image.fromarray((np.clip(out, 0, 1) ** (1 / 1.1) * 255).astype(np.uint8))
    return img.resize(size, Image.LANCZOS)


# --- Fields for a view ----------------------------------------------------------------------------------------------

def view_fields(reg, x0, z0, x1, z1, res):
    xs = np.arange(x0, x1 + 1e-9, res)
    zs = np.arange(z0, z1 + 1e-9, res)
    X, Z = np.meshgrid(xs, zs)
    hf = br.height_field(reg, X, Z)
    H = hf["H"]
    surf = np.where(hf["water"], hf["surface"], np.nan)
    col, forest = albedo(H, hf["aux"], hf["water"], reg.seed, X, Z, res)
    rgb = lit(H, col, forest, res)
    return H, surf, rgb


# Each slice square's camera and target (x, y, z), the same for its three variants so they compare; the view frames
# the feature the variants change, over the box of ground it renders (x0, z0, x1, z1).
CAMERAS = {
    "C1": {"cam": (800, 280, -660), "target": (835, 140, -1380), "box": (420, -1720, 1248, -620), "fov": 54},
    "B1": {"cam": (430, 300, -780), "target": (40, 165, -1210), "box": (-480, -1720, 560, -700), "fov": 56},
    "C2": {"cam": (540, 190, 140), "target": (780, 112, -170), "box": (400, -600, 1248, 220), "fov": 52},
    "B2": {"cam": (130, 250, -210), "target": (110, 175, -580), "box": (-260, -840, 460, -170), "fov": 54},
}


def caption(img, title, sub, size=(960, 600)):
    canvas = Image.new("RGB", (size[0], size[1] + 64), (241, 233, 214))
    canvas.paste(img, (0, 64))
    dr = ImageDraw.Draw(canvas)
    dr.text((16, 6), title, fill=(40, 34, 28), font=font(28))
    dr.text((16, 38), sub, fill=(90, 80, 66), font=font(18))
    return canvas


def variants_sheet(squares, cid, out, layout, res=1.0):
    reg0 = br.Region(layout)
    typ = reg0.cells[cid]["type"]
    var = reg0.squares["types"][typ]["variants"]
    cam = CAMERAS[cid]
    panels = []
    for key in ("A", "B", "C"):
        over = {k: v for k, v in var[key].items() if k != "label"}
        reg = br.Region(layout, overrides={cid: over})
        x0, z0, x1, z1 = cam["box"]
        H, surf, rgb = view_fields(reg, x0, z0, x1, z1, res)
        img = render(H, surf, rgb, x0, z0, res, cam["cam"], cam["target"], size=(960, 600), fov=cam["fov"],
                     far=2200.0, haze=1600.0)
        picked = "  (in the bake now)" if key == var["pick"] else ""
        panels.append(caption(img, "%s   %s" % (key, var[key]["label"]), var["about"] + picked))
    w, h = panels[0].size
    sheet = Image.new("RGB", (w * 3 + 40, h + 70), (241, 233, 214))
    dr = ImageDraw.Draw(sheet)
    dr.text((16, 12), "%s  %s: three choices" % (cid, reg0.squares["types"][typ]["name"]), fill=(40, 34, 28),
            font=font(36))
    for k, p in enumerate(panels):
        sheet.paste(p, (10 + k * (w + 10), 60))
    sheet.save(os.path.join(out, "variants_%s.png" % cid))
    print("variants_%s.png" % cid)


def stitch(reg, bake):
    """The baked squares stitched into one region grid at 1 m (shared edges written once)."""
    cols, rows = reg.cols, reg.rows
    b = reg.bounds
    nx = int(b[1] - b[0]) + 1
    nz = int(b[3] - b[2]) + 1
    R = np.zeros((nz, nx), np.float32)
    for cid, c in reg.cells.items():
        Hs = np.fromfile(os.path.join(bake, cid, "height.bin"), "<f4").reshape(br.N, br.N)
        i0 = int(c["cx"] - br.HALF - b[0])
        j0 = int(c["cz"] - br.HALF - b[2])
        R[j0:j0 + br.N, i0:i0 + br.N] = Hs
    return R


def region_view(reg, bake, out, pad=800.0):
    """The region from the bake, set in the recipes' own ground for `pad` m round it (the land past the region, as
    the margins are baked), which fades into the haze so the region reads as the place."""
    R = stitch(reg, bake)
    b = reg.bounds
    res = 2.0
    x0, z0 = b[0] - pad, b[2] - pad
    xs = x0 + np.arange(int((b[1] - b[0] + 2 * pad) / res) + 1) * res
    zs = z0 + np.arange(int((b[3] - b[2] + 2 * pad) / res) + 1) * res
    X, Z = np.meshgrid(xs, zs)
    hf = br.height_field(reg, X, Z)
    H = hf["H"].copy()
    k = int(pad / res)
    Rb = R[::2, ::2].astype(np.float64)
    H[k:k + Rb.shape[0], k:k + Rb.shape[1]] = Rb       # inside the region: the bake itself
    surf = np.where(hf["water"], hf["surface"], np.nan)
    col, forest = albedo(H, hf["aux"], hf["water"], reg.seed, X, Z, res)
    rgb = lit(H, col, forest, res)
    out_m = np.maximum.reduce([b[0] - X, X - b[1], b[2] - Z, Z - b[3], np.zeros_like(X)])
    mist = 0.8 * smoothstep(0.0, 500.0, out_m)[..., None]
    rgb = rgb * (1 - mist) + SKY_HAZE * mist
    b = (x0, None, z0)
    shots = [("r1_relief.png", (1750, 620, 2150), (250, 150, -500), 54,
              "From the south-east: the river runs up through the lock and the ferry into the gorge; the torrent comes "
              "in from the left. Grey discs: where the karst towers will stand"),
             ("r1_relief_north.png", (1150, 560, -2350), (300, 160, -500), 56,
              "From the north-east: the gorge in front, the village terraces on the right, the switchback trail above "
              "the torrent in the middle, the river running on south past the ferry")]
    for name, cam, target, fov, sub in shots:
        img = render(H, surf, rgb, b[0], b[2], res, cam, target, size=(1600, 960), fov=fov, far=7000.0, haze=5200.0)
        caption(img, "R1, the Đá Trắng Reach and Two Heights (first terrain)", sub, size=(1600, 960)).save(
            os.path.join(out, name))
        print(name)


# --- Internal sheets ----------------------------------------------------------------------------------------------

def hillshade(H, res=1.0):
    gz, gx = np.gradient(H, res)
    n = np.stack([-gx, np.ones_like(H), -gz], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    l1 = np.clip(n @ np.array([-0.5, 0.7, -0.5]) / 1.0, 0, 1)
    l2 = np.clip(n @ np.array([0.3, 0.9, -0.3]) / 1.0, 0, 1)
    return np.clip(0.15 + 0.6 * l1 + 0.35 * l2, 0, 1)


def squares_sheet(reg, bake, out):
    tiles = []
    for cid in sorted(reg.cells, key=lambda c: (reg.cells[c]["row"], reg.cells[c]["col"])):
        d = os.path.join(bake, cid)
        H = np.fromfile(os.path.join(d, "height.bin"), "<f4").reshape(br.N, br.N).astype(np.float64)
        sp = np.asarray(Image.open(os.path.join(d, "preview_splat.png")), dtype=np.float64) / 255.0
        hs = hillshade(H)
        img = np.clip(sp * (0.45 + 0.75 * hs[..., None]), 0, 1)
        t = Image.fromarray((img * 255).astype(np.uint8)).resize((416, 416), Image.LANCZOS)
        meta = json.load(open(os.path.join(d, "meta.json")))
        c = Image.new("RGB", (416, 470), (241, 233, 214))
        c.paste(t, (0, 54))
        dr = ImageDraw.Draw(c)
        st = meta["stats"]
        dr.text((6, 2), "%s %s (%s)" % (cid, meta["type"], meta["recipe_status"]), fill=(40, 34, 28), font=font(18))
        dr.text((6, 26), "%.0f-%.0f m, slope p99 %.0f deg, %.1f s" % (st["height_min"], st["height_max"],
                                                                     st["slope_p99_deg"], st["bake_s"]),
                fill=(90, 80, 66), font=font(15))
        tiles.append(c)
    sheet = Image.new("RGB", (3 * 426 + 10, 4 * 480 + 10), (241, 233, 214))
    for k, t in enumerate(tiles):
        sheet.paste(t, (10 + (k % 3) * 426, 10 + (k // 3) * 480))
    sheet.save(os.path.join(out, "squares_hillshade_splat.png"))
    print("squares_hillshade_splat.png")


def network_sheet(reg, bake, out):
    R = stitch(reg, bake).astype(np.float64)
    b = reg.bounds
    hs = hillshade(R)
    lo, hi = np.percentile(R, 1), np.percentile(R, 99)
    t = np.clip((R - lo) / (hi - lo), 0, 1)[..., None]
    tint = np.array([0.55, 0.62, 0.42]) * (1 - t) + np.array([0.86, 0.80, 0.66]) * t
    img = Image.fromarray((np.clip(tint * (0.35 + 0.8 * hs[..., None]), 0, 1) * 255).astype(np.uint8))
    scale = 0.5
    img = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
    dr = ImageDraw.Draw(img)

    def px(x, z):
        return ((x - b[0]) * scale, (z - b[2]) * scale)

    for c in reg.net.channels:
        for side in (-1.0, 1.0):
            dx, dz = np.gradient(c.x), np.gradient(c.z)
            L = np.hypot(dx, dz)
            bx = c.x + side * c.hw * (-dz / L)
            bz = c.z + side * c.hw * (dx / L)
            dr.line([px(a, q) for a, q in zip(bx, bz)], fill=(30, 70, 160), width=2)
        dr.line([px(a, q) for a, q in zip(c.x, c.z)], fill=(120, 170, 230), width=1)
    for p in reg.pounds:
        poly = [px(a, q) for a, q in p["polygon"]]
        dr.polygon(poly, outline=(200, 40, 40))
    for r in reg.rows:
        for cc in reg.cols:
            c = reg.cells[cc + r]
            x0, z0 = px(c["cx"] - br.HALF, c["cz"] - br.HALF)
            x1, z1 = px(c["cx"] + br.HALF, c["cz"] + br.HALF)
            dr.rectangle([x0, z0, x1, z1], outline=(60, 50, 40))
            dr.text((x0 + 6, z0 + 4), "%s %s" % (cc + r, c["type"]), fill=(30, 26, 20), font=font(16))
    for name, lm in reg.landmarks.items():
        pts = lm["at"] if isinstance(lm["at"][0], list) else [lm["at"]]
        for a, q in pts:
            x, y = px(a, q)
            dr.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(230, 120, 30))
    img.save(os.path.join(out, "r1_hillshade_network.png"))
    print("r1_hillshade_network.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--bake", default=None, help="the baked region (default build_regions/<region>/)")
    ap.add_argument("--layout", default=br.LAYOUT)
    ap.add_argument("--only", default="variants,region,internal")
    ap.add_argument("--cells", default="C1,B1,C2,B2")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    reg = br.Region(args.layout)
    bake = args.bake or os.path.join(br.OUT_ROOT, reg.squares["region"])
    only = args.only.split(",")
    if "variants" in only:
        for cid in args.cells.split(","):
            variants_sheet(reg.squares, cid, args.out, args.layout)
    if "region" in only:
        region_view(reg, bake, args.out)
    if "internal" in only:
        squares_sheet(reg, bake, args.out)
        network_sheet(reg, bake, args.out)


if __name__ == "__main__":
    main()
