#!/usr/bin/env python3
"""Grass tuft card atlas for the Frontier grass (look-dev spec, section 5.5). Package B.

Output: assets/environment/grass/grass_atlas.png (2048 x 1024 RGBA, 4 x 4 cells of 512 x 256,
straight alpha, colours dilated into the transparent area so mipmaps do not fringe) and
grass_variants.json (per cell: uv rect of the content, aspect w/h, kind). Deterministic.

Cells 0-4   the five photographed tuft cards from Poly Haven grass_medium_01 (CC0; the tuft
            renders at the bottom of grass_medium_01_diff_2k.jpg). The JPG has no alpha: alpha is
            rebuilt as smoothstep(0.02, 0.08, max(rgb)) (spec 7.1) and the UV-padding smears
            under each tuft are cut off.
Cells 5-7   procedural seed-head clumps (tall stems with panicles, green and straw)
Cells 8-10  procedural dry blade clumps (late-summer straw and olive)
Cells 11-12 procedural short dense tufts (mowed range shoulders)
Cells 13-15 procedural sparse sedge / woodland grass (forest floor)
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SRC = os.path.join(ROOT, "assets", "polyhaven", "models", "grass_medium_01", "textures", "grass_medium_01_diff_2k.jpg")
OUT = os.path.join(ROOT, "assets", "environment", "grass")
CW, CH = 512, 256
COLS, ROWS = 4, 4
SS = 4   # supersampling for the procedural cells

# Photo tufts: crop box (x0, y0, x1, y1) in the 2K diffuse, with y1 at the tuft's base line.
PHOTO = [
    (380, 1528, 1030, 1799),
    (1180, 1548, 1680, 1751),
    (40, 1772, 420, 2001),
    (470, 1846, 1030, 2016),
    (1150, 1790, 1620, 2037),
]


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def photo_cell(box):
    im = np.asarray(Image.open(SRC).convert("RGB").crop(box)).astype(np.float64) / 255.0
    a = smoothstep(0.02, 0.08, im.max(-1))
    # Un-darken the edge pixels (the JPG blends blades with black): divide by a soft coverage.
    cov = np.clip(im.max(-1) / 0.35, 0.25, 1.0)
    rgb = np.clip(im / cov[..., None], 0.0, 1.0)
    return rgb, a


def bezier(p0, p1, p2, t):
    return ((1 - t) ** 2)[..., None] * p0 + (2 * (1 - t) * t)[..., None] * p1 + (t ** 2)[..., None] * p2


def draw_blade(draw, base, height, lean, curl, width, c0, c1, rng, segs=14):
    """Tapered curved blade from base (x, y) upward (image y grows down)."""
    bx, by = base
    tip = np.array([bx + lean * height, by - height * (1.0 - 0.35 * abs(curl))])
    ctrl = np.array([bx + lean * height * 0.2 + curl * height * 0.35, by - height * 0.6])
    p0 = np.array([bx, by], float)
    t = np.linspace(0.0, 1.0, segs + 1)
    pts = bezier(p0, ctrl, tip, t)
    d = np.gradient(pts, axis=0)
    nrm = np.stack([-d[:, 1], d[:, 0]], -1)
    nrm /= np.maximum(np.linalg.norm(nrm, axis=-1, keepdims=True), 1e-6)
    w = width * (1.0 - t) ** 0.75 + 0.6
    left = pts + nrm * w[:, None] * 0.5
    right = pts - nrm * w[:, None] * 0.5
    for k in range(segs):
        f = (k + 0.5) / segs
        col = tuple(int(255 * np.clip(c0[i] + (c1[i] - c0[i]) * f ** 1.2, 0, 1)) for i in range(3)) + (255,)
        poly = [tuple(left[k]), tuple(left[k + 1]), tuple(right[k + 1]), tuple(right[k])]
        draw.polygon(poly, fill=col)
    return tip


def draw_panicle(draw, tip, length, col, rng, droop):
    """Seed head: small spikelets along the top of a stem."""
    n = rng.integers(18, 28)
    for k in range(n):
        f = k / n
        x = tip[0] + droop * f * length * 0.3
        y = tip[1] + f * length
        rx = SS * (0.7 + 0.5 * rng.random())
        ry = SS * (1.8 + 1.4 * rng.random())
        off = (rng.random() - 0.5) * SS * 3.5 * (0.4 + f * 0.6)
        g = 0.9 + 0.2 * rng.random()
        c = tuple(int(255 * np.clip(col[i] * g, 0, 1)) for i in range(3)) + (255,)
        draw.ellipse([x + off - rx, y - ry, x + off + rx, y + ry], fill=c)


def procedural_cell(kind, seed):
    rng = np.random.default_rng(seed)
    W, H = CW * SS, CH * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    base_y = H - 2 * SS
    green = np.array([0.22, 0.30, 0.10])
    olive = np.array([0.42, 0.44, 0.20])
    straw = np.array([0.74, 0.64, 0.40])
    tan = np.array([0.58, 0.48, 0.28])
    root = np.array([0.16, 0.15, 0.08])
    if kind == "seed":
        nb = 26
        for _ in range(nb):     # leafy base
            x = W * (0.3 + 0.4 * rng.random())
            draw_blade(draw, (x, base_y), H * (0.25 + 0.3 * rng.random()), (rng.random() - 0.5) * 1.4,
                       (rng.random() - 0.5), SS * (4 + 3 * rng.random()), root, olive * (0.8 + 0.4 * rng.random()), rng)
        for _ in range(rng.integers(5, 9)):   # stems with seed heads
            x = W * (0.35 + 0.3 * rng.random())
            h = H * (0.7 + 0.28 * rng.random())
            lean = (rng.random() - 0.5) * 0.5
            c1 = straw if rng.random() < 0.6 else olive
            tip = draw_blade(draw, (x, base_y), h, lean, (rng.random() - 0.5) * 0.3, SS * 1.6, olive * 0.8, c1, rng)
            draw_panicle(draw, tip, H * (0.14 + 0.08 * rng.random()), np.array([0.66, 0.58, 0.38]) * (0.9 + 0.2 * rng.random()), rng, lean)
    elif kind == "dry":
        for _ in range(55):
            x = W * (0.2 + 0.6 * rng.random())
            h = H * (0.35 + 0.6 * rng.random())
            c1 = [straw, tan, olive][rng.integers(0, 3)] * (0.85 + 0.3 * rng.random())
            draw_blade(draw, (x, base_y), h, (rng.random() - 0.5) * 1.6, (rng.random() - 0.5) * 1.2,
                       SS * (3 + 3 * rng.random()), tan * 0.55, c1, rng)
    elif kind == "short":
        for _ in range(90):
            x = W * (0.1 + 0.8 * rng.random())
            h = H * (0.35 + 0.55 * rng.random())
            c1 = (olive if rng.random() < 0.7 else straw) * (0.8 + 0.4 * rng.random())
            draw_blade(draw, (x, base_y), h, (rng.random() - 0.5) * 1.1, (rng.random() - 0.5) * 0.8,
                       SS * (4 + 3 * rng.random()), root * 1.3, c1, rng)
    elif kind == "sedge":
        for _ in range(rng.integers(12, 20)):
            x = W * (0.4 + 0.2 * rng.random())
            h = H * (0.45 + 0.5 * rng.random())
            c1 = np.array([0.34, 0.40, 0.15]) * (0.9 + 0.35 * rng.random())
            draw_blade(draw, (x, base_y), h, (rng.random() - 0.5) * 2.2, (rng.random() - 0.5) * 1.5,
                       SS * (3 + 2 * rng.random()), root * 1.6, c1, rng)
    a = np.asarray(img).astype(np.float64) / 255.0
    # Premultiplied downsample.
    pm = a[..., :3] * a[..., 3:4]
    out_rgb = np.zeros((CH, CW, 3))
    for c in range(3):
        out_rgb[..., c] = np.asarray(Image.fromarray(pm[..., c].astype(np.float32), "F").resize((CW, CH), Image.BOX))
    out_a = np.asarray(Image.fromarray(a[..., 3].astype(np.float32), "F").resize((CW, CH), Image.BOX))
    rgb = np.where(out_a[..., None] > 1e-4, out_rgb / np.maximum(out_a[..., None], 1e-4), 0.0)
    return np.clip(rgb, 0, 1), np.clip(out_a, 0, 1)


def fit_cell(rgb, a):
    """Scale content into a CW x CH cell, bottom-aligned and centred. Returns cell + content rect."""
    h, w = a.shape
    s = min((CW - 8) / w, (CH - 4) / h, 1.0 if w <= CW and h <= CH else 99)
    s = min((CW - 8) / w, (CH - 4) / h)
    nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
    pm = rgb * a[..., None]
    chans = [np.asarray(Image.fromarray(pm[..., c].astype(np.float32), "F").resize((nw, nh), Image.LANCZOS)) for c in range(3)]
    na = np.clip(np.asarray(Image.fromarray(a.astype(np.float32), "F").resize((nw, nh), Image.LANCZOS)), 0, 1)
    nrgb = np.stack(chans, -1) / np.maximum(na[..., None], 1e-4)
    cell_rgb = np.zeros((CH, CW, 3))
    cell_a = np.zeros((CH, CW))
    x0 = (CW - nw) // 2
    y0 = CH - nh
    cell_rgb[y0:y0 + nh, x0:x0 + nw] = np.clip(nrgb, 0, 1)
    cell_a[y0:y0 + nh, x0:x0 + nw] = na
    return cell_rgb, cell_a, (x0, y0, x0 + nw, CH)


def dilate(rgb, a, iters=24):
    """Push opaque colours outward into transparent texels (mip-safe)."""
    known = a > 0.5
    col = np.where(known[..., None], rgb, 0.0)
    for _ in range(iters):
        acc = np.zeros_like(col)
        cnt = np.zeros(a.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            sk = np.roll(np.roll(known, dy, 0), dx, 1)
            sc = np.roll(np.roll(col, dy, 0), dx, 1)
            acc += sc * sk[..., None]
            cnt += sk
        new = (~known) & (cnt > 0)
        col[new] = acc[new] / cnt[new][:, None]
        known = known | new
    col[~known] = rgb[a > 0.5].mean(0)
    # Keep the real colour where the texel is at least partly covered.
    return np.where((a > 0.5)[..., None], rgb, col)


def main():
    os.makedirs(OUT, exist_ok=True)
    atlas_rgb = np.zeros((CH * ROWS, CW * COLS, 3))
    atlas_a = np.zeros((CH * ROWS, CW * COLS))
    cells = []
    for box in PHOTO:
        cells.append(("photo",) + photo_cell(box))
    for k, (kind, n) in enumerate([("seed", 3), ("dry", 3), ("short", 2), ("sedge", 3)]):
        for v in range(n):
            cells.append((kind,) + procedural_cell(kind, 1000 + k * 17 + v))
    meta = []
    for idx, (kind, rgb, a) in enumerate(cells):
        crgb, ca, rect = fit_cell(rgb, a)
        crgb = dilate(crgb, ca)
        cx, cy = idx % COLS, idx // COLS
        atlas_rgb[cy * CH:(cy + 1) * CH, cx * CW:(cx + 1) * CW] = crgb
        atlas_a[cy * CH:(cy + 1) * CH, cx * CW:(cx + 1) * CW] = ca
        x0, y0, x1, y1 = rect
        W, H = CW * COLS, CH * ROWS
        meta.append({"cell": idx, "kind": kind,
                     "uv_rect": [(cx * CW + x0) / W, (cy * CH + y0) / H, (cx * CW + x1) / W, (cy * CH + y1) / H],
                     "aspect": (x1 - x0) / (y1 - y0), "coverage": float((ca > 0.5).mean())})
    out = np.concatenate([atlas_rgb, atlas_a[..., None]], -1)
    Image.fromarray(np.round(out * 255).astype(np.uint8)).save(os.path.join(OUT, "grass_atlas.png"))
    with open(os.path.join(OUT, "grass_variants.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    # Preview on grey (not imported).
    prev = atlas_rgb * atlas_a[..., None] + 0.55 * (1 - atlas_a[..., None])
    Image.fromarray(np.round(prev * 255).astype(np.uint8)).save(os.path.join(HERE, "build", "preview_grass_atlas.png"))
    for m in meta:
        print(m)


if __name__ == "__main__":
    main()
