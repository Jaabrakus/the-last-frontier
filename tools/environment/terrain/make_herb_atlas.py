#!/usr/bin/env python3
"""Herb and wildflower card atlas for the procedural ground cover (user 2026-09-28: "add a procdure grass thing right
that will save us cpu and gpu? with chance for herbs and etc"). The grass's GPU tuft pattern (scripts/world/terrain/grass.gd,
shaders/grass/grass.gdshader) turns some of its tufts into these by chance, by the ground, the shade and the season: no
placement on the CPU, no objects, the same instances the grass already draws.

Output: assets/environment/grass/herb_atlas.png (2048 x 1024 RGBA, 4 x 4 cells of 512 x 256, straight alpha, colours
dilated into the transparent area) and herb_variants.json (per cell: uv rect of the content, aspect w/h, kind).
Deterministic. Painted like the grass atlas's procedural cells (make_grass_atlas.py, whose helpers it uses). None of
them is a forage plant (scripts/forage: yarrow, strawberry, plantain, ...): what can be picked stays an object.

Cells 0-3   fern clumps (arching fronds, paired leaflets): the woods
Cell  4     wood sorrel (low trifoliate leaves, small white flowers): the woods
Cell  5     mayapple (umbrella leaves on stalks): the woods
Cell  6     trillium (three white petals over three leaves): the woods in spring
Cell  7     violets (heart leaves, small purple flowers): the woods' edges in spring
Cells 8-9   asters (purple and lavender daisies on leafy stems): the open ground, late summer and autumn
Cells 10-11 goldenrod (arching yellow plumes): the open ground, late summer and autumn
Cells 12-13 black-eyed Susans (gold petals, dark centres): the open ground, summer
Cells 14-15 wild bergamot (lavender puffs): the open ground, summer
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_grass_atlas as g  # noqa: E402

ROOT = g.ROOT
OUT = g.OUT
CW, CH, COLS, ROWS, SS = g.CW, g.CH, g.COLS, g.ROWS, g.SS

GREEN = np.array([0.20, 0.30, 0.09])
DEEP = np.array([0.12, 0.20, 0.06])
YELLOWGREEN = np.array([0.36, 0.44, 0.14])
ROOT_C = np.array([0.14, 0.13, 0.07])


def rgba(c, a=255):
    return tuple(int(255 * np.clip(c[i], 0, 1)) for i in range(3)) + (a,)


def leaf(draw, base, length, width, angle, c0, c1, segs=10, pointed=1.0):
    """A tapered leaf from `base` along `angle` (radians, 0 = right, -pi/2 = up; image y grows down)."""
    d = np.array([math.cos(angle), math.sin(angle)])
    n = np.array([-d[1], d[0]])
    b = np.array(base, float)
    for k in range(segs):
        t0, t1 = k / segs, (k + 1) / segs
        w0 = width * math.sin(math.pi * min(t0, 1.0)) ** (0.6 * pointed) * 0.5
        w1 = width * math.sin(math.pi * min(t1, 1.0)) ** (0.6 * pointed) * 0.5
        p0 = b + d * length * t0
        p1 = b + d * length * t1
        col = rgba(c0 + (c1 - c0) * ((t0 + t1) * 0.5))
        draw.polygon([tuple(p0 + n * w0), tuple(p1 + n * w1), tuple(p1 - n * w1), tuple(p0 - n * w0)], fill=col)


def daisy(draw, c, r, petal, centre, n, rng, tilt=0.0):
    for k in range(n):
        a = 2 * math.pi * k / n + rng.random() * 0.2
        px = c[0] + math.cos(a) * r * 0.55
        py = c[1] + math.sin(a) * r * 0.55 * (0.45 + 0.4 * abs(math.cos(tilt)))
        rr = r * 0.42
        col = petal * (0.9 + 0.2 * rng.random())
        draw.ellipse([px - rr, py - rr * 0.55, px + rr, py + rr * 0.55], fill=rgba(col))
    cr = r * 0.32
    draw.ellipse([c[0] - cr, c[1] - cr, c[0] + cr, c[1] + cr], fill=rgba(centre))


def stem_leaves(draw, base, tip, n, length, width, rng, c0=DEEP, c1=GREEN):
    for k in range(n):
        f = 0.15 + 0.7 * (k + rng.random() * 0.5) / n
        p = (base[0] + (tip[0] - base[0]) * f, base[1] + (tip[1] - base[1]) * f)
        side = -1 if k % 2 else 1
        ang = -math.pi / 2 + side * (0.9 + 0.5 * rng.random())
        leaf(draw, p, length * (1.1 - 0.5 * f) * (0.8 + 0.4 * rng.random()), width, ang, c0, c1 * (0.9 + 0.2 * rng.random()))


def fern(draw, W, H, base_y, rng):
    nf = rng.integers(7, 11)
    for i in range(nf):
        side = -1 if i % 2 else 1
        spread = (0.15 + 0.85 * rng.random()) * side
        length = H * (0.75 + 0.35 * rng.random())
        p0 = np.array([W * 0.5 + (rng.random() - 0.5) * W * 0.04, base_y])
        ctrl = p0 + np.array([spread * length * 0.45, -length * 0.95])
        tip = p0 + np.array([spread * length * 1.05, -length * (0.35 + 0.25 * rng.random())])
        t = np.linspace(0, 1, 40)
        pts = g.bezier(p0, ctrl, tip, t)
        col_r = DEEP * (0.9 + 0.2 * rng.random())
        for k in range(len(t) - 1):
            draw.line([tuple(pts[k]), tuple(pts[k + 1])], fill=rgba(col_r), width=int(SS * 1.6 * (1 - t[k]) + SS * 0.6))
        # paired leaflets, longest a third of the way up, none on the bare stalk at the base
        c1 = (GREEN if rng.random() < 0.6 else YELLOWGREEN) * (0.85 + 0.3 * rng.random())
        for k in range(6, len(t) - 1, 2):
            f = t[k]
            d = pts[k + 1] - pts[k]
            ang = math.atan2(d[1], d[0])
            ln = length * 0.22 * math.sin(math.pi * min(1.0, (f - 0.1) / 0.95)) ** 0.8
            if ln <= SS:
                continue
            for s in (-1, 1):
                a = ang + s * (1.25 + 0.15 * rng.random())
                leaf(draw, tuple(pts[k]), ln, ln * 0.3, a + 0.25 * s, DEEP, c1, segs=6)


def sorrel(draw, W, H, base_y, rng):
    for _ in range(rng.integers(26, 36)):
        x = W * (0.2 + 0.6 * rng.random())
        h = H * (0.3 + 0.45 * rng.random())
        tip = g.draw_blade(draw, (x, base_y), h, (rng.random() - 0.5) * 0.9, (rng.random() - 0.5) * 0.4, SS * 1.2,
                           DEEP, GREEN, rng)
        r = SS * (5 + 3 * rng.random())
        c = YELLOWGREEN * (0.8 + 0.3 * rng.random())
        for k in range(3):
            a = -math.pi / 2 + (k - 1) * 1.9 + (rng.random() - 0.5) * 0.3
            cx, cy = tip[0] + math.cos(a) * r * 0.8, tip[1] + math.sin(a) * r * 0.45
            draw.ellipse([cx - r, cy - r * 0.55, cx + r, cy + r * 0.55], fill=rgba(c))
    for _ in range(rng.integers(3, 7)):
        x, y = W * (0.25 + 0.5 * rng.random()), base_y - H * (0.55 + 0.3 * rng.random())
        daisy(draw, (x, y), SS * 4.5, np.array([0.93, 0.92, 0.88]), np.array([0.85, 0.8, 0.5]), 5, rng)


def mayapple(draw, W, H, base_y, rng):
    for i in range(rng.integers(3, 5)):
        x = W * (0.25 + 0.5 * rng.random())
        h = H * (0.6 + 0.3 * rng.random())
        tip = g.draw_blade(draw, (x, base_y), h, (rng.random() - 0.5) * 0.3, 0.0, SS * 2.2, DEEP, GREEN, rng)
        # the umbrella: a wide lobed leaf seen from the side, drooping at its edges
        wdt = W * (0.16 + 0.06 * rng.random())
        c = GREEN * (0.9 + 0.25 * rng.random())
        for k in range(7):
            a = (k / 6.0 - 0.5) * 2.4
            ex = tip[0] + math.sin(a) * wdt
            ey = tip[1] + (1 - math.cos(a)) * wdt * 0.35
            leaf(draw, tip, math.hypot(ex - tip[0], ey - tip[1]), wdt * 0.42, math.atan2(ey - tip[1], ex - tip[0]),
                 c * 0.8, c, segs=8)


def trillium(draw, W, H, base_y, rng):
    for i in range(rng.integers(2, 4)):
        x = W * (0.3 + 0.4 * rng.random())
        h = H * (0.55 + 0.3 * rng.random())
        tip = g.draw_blade(draw, (x, base_y), h, (rng.random() - 0.5) * 0.3, 0.0, SS * 2.0, DEEP, GREEN, rng)
        for k in range(3):
            a = -math.pi / 2 + (k - 1) * 1.6
            leaf(draw, (tip[0], tip[1] + SS * 6), H * 0.28, H * 0.16, a + math.pi * 0.5 * (1 if k == 1 else 0) * 0 + (k - 1) * 0.6,
                 DEEP, GREEN * 1.1, segs=8)
        for k in range(3):
            a = -math.pi / 2 + (k - 1) * 0.9
            leaf(draw, tip, H * 0.2, H * 0.1, a, np.array([0.85, 0.85, 0.8]), np.array([0.97, 0.96, 0.93]), segs=8)


def violets(draw, W, H, base_y, rng):
    for _ in range(rng.integers(12, 18)):
        x = W * (0.2 + 0.6 * rng.random())
        h = H * (0.25 + 0.3 * rng.random())
        tip = g.draw_blade(draw, (x, base_y), h, (rng.random() - 0.5) * 0.8, 0.0, SS * 1.2, DEEP, GREEN, rng)
        r = SS * (6 + 3 * rng.random())
        draw.ellipse([tip[0] - r, tip[1] - r * 0.7, tip[0] + r, tip[1] + r * 0.7], fill=rgba(GREEN * (0.85 + 0.3 * rng.random())))
    for _ in range(rng.integers(6, 10)):
        x = W * (0.25 + 0.5 * rng.random())
        tip = g.draw_blade(draw, (x, base_y), H * (0.45 + 0.25 * rng.random()), (rng.random() - 0.5) * 0.5, 0.2, SS * 1.0, DEEP, GREEN, rng)
        daisy(draw, tip, SS * 5.5, np.array([0.42, 0.24, 0.62]), np.array([0.9, 0.85, 0.5]), 5, rng)


def aster(draw, W, H, base_y, rng, petal):
    for _ in range(rng.integers(5, 8)):
        x = W * (0.3 + 0.4 * rng.random())
        h = H * (0.75 + 0.22 * rng.random())
        lean = (rng.random() - 0.5) * 0.6
        tip = g.draw_blade(draw, (x, base_y), h, lean, (rng.random() - 0.5) * 0.3, SS * 1.8, DEEP, GREEN, rng)
        stem_leaves(draw, (x, base_y), tip, 5, H * 0.16, SS * 5, rng)
        for k in range(rng.integers(4, 8)):
            f = rng.random()
            cx = tip[0] + (rng.random() - 0.5) * W * 0.12
            cy = tip[1] + f * H * 0.18
            daisy(draw, (cx, cy), SS * (5.5 + 2 * rng.random()), petal, np.array([0.92, 0.75, 0.25]), 12, rng)


def goldenrod(draw, W, H, base_y, rng):
    for _ in range(rng.integers(4, 7)):
        x = W * (0.3 + 0.4 * rng.random())
        h = H * (0.8 + 0.18 * rng.random())
        lean = (rng.random() - 0.5) * 0.5
        tip = g.draw_blade(draw, (x, base_y), h, lean, (rng.random() - 0.5) * 0.3, SS * 2.0, DEEP, GREEN, rng)
        stem_leaves(draw, (x, base_y), tip, 7, H * 0.14, SS * 4, rng)
        # the plume: arching side branches crowded with small yellow heads on their upper sides
        for b in range(rng.integers(5, 8)):
            y0 = tip[1] + b * H * 0.035
            side = -1 if b % 2 else 1
            ln = W * (0.05 + 0.05 * rng.random()) * (1.0 - b * 0.08)
            for k in range(14):
                f = k / 13.0
                px = tip[0] + side * ln * f
                py = y0 - math.sin(f * math.pi * 0.8) * H * 0.04 + f * f * H * 0.03
                rr = SS * (2.2 + 1.0 * rng.random())
                col = np.array([0.93, 0.74, 0.12]) * (0.85 + 0.25 * rng.random())
                draw.ellipse([px - rr, py - rr, px + rr, py + rr], fill=rgba(col))


def susan(draw, W, H, base_y, rng):
    for _ in range(rng.integers(5, 8)):
        x = W * (0.3 + 0.4 * rng.random())
        h = H * (0.6 + 0.35 * rng.random())
        lean = (rng.random() - 0.5) * 0.6
        tip = g.draw_blade(draw, (x, base_y), h, lean, (rng.random() - 0.5) * 0.3, SS * 1.6, DEEP, GREEN, rng)
        stem_leaves(draw, (x, base_y), tip, 3, H * 0.2, SS * 7, rng)
        daisy(draw, tip, SS * (9 + 3 * rng.random()), np.array([0.95, 0.68, 0.1]), np.array([0.18, 0.1, 0.05]), 13, rng,
              tilt=rng.random())


def bergamot(draw, W, H, base_y, rng):
    for _ in range(rng.integers(5, 8)):
        x = W * (0.3 + 0.4 * rng.random())
        h = H * (0.7 + 0.25 * rng.random())
        tip = g.draw_blade(draw, (x, base_y), h, (rng.random() - 0.5) * 0.5, 0.0, SS * 1.8, DEEP, GREEN, rng)
        stem_leaves(draw, (x, base_y), tip, 5, H * 0.15, SS * 6, rng)
        # the puff: a ball of tubular lavender florets
        r = SS * (9 + 3 * rng.random())
        for k in range(40):
            a = rng.random() * 2 * math.pi
            d = r * math.sqrt(rng.random())
            px, py = tip[0] + math.cos(a) * d, tip[1] - SS * 3 + math.sin(a) * d * 0.8
            rr = SS * (1.4 + rng.random())
            col = np.array([0.72, 0.55, 0.78]) * (0.85 + 0.3 * rng.random())
            draw.ellipse([px - rr, py - rr * 1.6, px + rr, py + rr * 1.6], fill=rgba(col))


PAINT = {"fern": fern, "sorrel": sorrel, "mayapple": mayapple, "trillium": trillium, "violet": violets,
         "goldenrod": goldenrod, "susan": susan, "bergamot": bergamot}


def painted_cell(kind, seed):
    rng = np.random.default_rng(seed)
    W, H = CW * SS, CH * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    base_y = H - 2 * SS
    if kind == "aster":
        aster(draw, W, H, base_y, rng, np.array([0.55, 0.42, 0.78]) if seed % 2 else np.array([0.72, 0.64, 0.86]))
    else:
        PAINT[kind](draw, W, H, base_y, rng)
    a = np.asarray(img).astype(np.float64) / 255.0
    pm = a[..., :3] * a[..., 3:4]
    out_rgb = np.zeros((CH, CW, 3))
    for c in range(3):
        out_rgb[..., c] = np.asarray(Image.fromarray(pm[..., c].astype(np.float32), "F").resize((CW, CH), Image.BOX))
    out_a = np.asarray(Image.fromarray(a[..., 3].astype(np.float32), "F").resize((CW, CH), Image.BOX))
    rgb = np.where(out_a[..., None] > 1e-4, out_rgb / np.maximum(out_a[..., None], 1e-4), 0.0)
    # cropped to the plant (a card no wider than it: less overdraw), a few texels' margin, the base kept at the bottom
    ys, xs = np.nonzero(out_a > 0.02)
    x0, x1 = max(xs.min() - 4, 0), min(xs.max() + 5, CW)
    y0 = max(ys.min() - 4, 0)
    return np.clip(rgb[y0:, x0:x1], 0, 1), np.clip(out_a[y0:, x0:x1], 0, 1)


CELLS = ["fern", "fern", "fern", "fern", "sorrel", "mayapple", "trillium", "violet",
         "aster", "aster", "goldenrod", "goldenrod", "susan", "susan", "bergamot", "bergamot"]


def main():
    atlas_rgb = np.zeros((CH * ROWS, CW * COLS, 3))
    atlas_a = np.zeros((CH * ROWS, CW * COLS))
    meta = []
    for idx, kind in enumerate(CELLS):
        rgb, a = painted_cell(kind, 5000 + idx * 31)
        crgb, ca, rect = g.fit_cell(rgb, a)
        crgb = g.dilate(crgb, ca)
        cx, cy = idx % COLS, idx // COLS
        atlas_rgb[cy * CH:(cy + 1) * CH, cx * CW:(cx + 1) * CW] = crgb
        atlas_a[cy * CH:(cy + 1) * CH, cx * CW:(cx + 1) * CW] = ca
        x0, y0, x1, y1 = rect
        W, H = CW * COLS, CH * ROWS
        meta.append({"cell": idx, "kind": kind,
                     "uv_rect": [(cx * CW + x0) / W, (cy * CH + y0) / H, (cx * CW + x1) / W, (cy * CH + y1) / H],
                     "aspect": (x1 - x0) / (y1 - y0), "coverage": float((ca > 0.5).mean())})
    out = np.concatenate([atlas_rgb, atlas_a[..., None]], -1)
    Image.fromarray(np.round(out * 255).astype(np.uint8)).save(os.path.join(OUT, "herb_atlas.png"))
    with open(os.path.join(OUT, "herb_variants.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    os.makedirs(os.path.join(HERE, "build"), exist_ok=True)
    prev = atlas_rgb * atlas_a[..., None] + 0.55 * (1 - atlas_a[..., None])
    Image.fromarray(np.round(prev * 255).astype(np.uint8)).save(os.path.join(HERE, "build", "preview_herb_atlas.png"))
    for m in meta:
        print(m["cell"], m["kind"], round(m["aspect"], 2), round(m["coverage"], 3))


if __name__ == "__main__":
    main()
