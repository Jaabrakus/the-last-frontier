#!/usr/bin/env python3
"""P07 / P08: painted foliage for R1 (style guide 6): leaf-card atlas, bark and culm tiles, grass and herb cards.

    python3 tools/thuyvan_art/paint/paint_foliage.py

Every card is painted with the brush engine (tvp.py): clusters of rounded leaf dabs, each with a dark copy under it
and a lit sliver on top, the lighting already in the paint (lighter on top, darker beneath and inside: the WoW
"lollipop" crown, never a photographic leaf mass). Alpha is the union of the dabs (alpha-scissor 0.5 in Godot).

Writes into assets/thuyvan/paint/foliage/:
  tv_foliage_atlas.png   2048 x 2048 RGBA, 4 x 4 tiles of 512 (index = row * 4 + col):
                           0-3  broadleaf crown clumps (A, B, C round; D light top clump)
                           4-6  karst pine tier pads (flat, dark), 7 pine tuft (side)
                           8-10 bamboo leaf sprays, 11 banana leaf
                           12-13 fern fronds, 14 shrub (madder flowers), 15 shrub (white and pink flowers)
  tv_foliage_tiles.json  the frontier's foliage_tiles.json format: per tile coverage, hexagonal hull (0..1, y down),
                         index, kind, size (m the card spans), uv [u0, v0, du, dv]
  tv_bark_broadleaf.png  512 x 1024 tiling bark (U around 1 m, V along 2 m)
  tv_bark_pine.png       512 x 1024 plated pine bark
  tv_bamboo_culm.png     256 x 1024 culm (U around, V along 1.2 m; dark node rings every 0.4 m)
  tv_banana_trunk.png    512 x 1024 layered sheaths
  tv_grass_atlas.png     2048 x 1024 RGBA, 4 x 4 cells of 512 x 256 (grass tufts, rice clumps, meadow tufts);
                         tv_grass_variants.json in the frontier's grass_variants.json format (cell, kind, uv_rect
                         [u0, v0, u1, v1], aspect, coverage); the root colour of every blade is the matching terrain
                         slice's mean colour (terrain_slices.json), so the cards melt into the ground
  tv_herb_atlas.png      2048 x 1024 RGBA, 16 cells: flower clumps, fern sprigs, small leafy herbs;
                         tv_herb_variants.json (same format)
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvp  # noqa: E402
from tvp import lin, mix, ramp  # noqa: E402

T = 512


def card(seed, ramp4, w=T, h=T, size_m=4.0):
    return tvp.Canvas(h, w, size_m, seed, ramp4, alpha=True, wrap=False, bristle=0.25, streak=0.05)


def leaf(cv, x, y, L, W, ang, body, dark, light, up=(0, -1), power=1.7, taper=0.35, dark_off=0.25):
    cv.stroke3(x, y, L, W, ang, body, dark, light, up=up, h_add=0.4, power=power, taper=taper, wob=0.06,
               edge=0.62, dark_off=dark_off, light_off=0.3, light_amt=0.85, dark_amt=0.9, alpha_add=True,
               bristle=0.2, dry=0.15)


def clump_cluster(cv, clumps, leaf_len, r4, leaves_per=40, lean_light=(0.0, -1.0), core=0.9, flowers=None,
                  leaf_w=0.5, flat=1.0):
    """Paint a crown cluster: clumps = [(cx, cy, rc)], back-to-front. Each clump: a dark core blob, then leaves
    from the inside out, toned by height in the cluster (lit on top) and by their place in the clump."""
    rng = cv.rng
    ys = [c[1] for c in clumps]
    ytop, ybot = min(c[1] - c[2] for c in clumps), max(c[1] + c[2] for c in clumps)
    for (cx, cy, rc) in clumps:
        hfac = 1.0 - (cy - ytop) / max(ybot - ytop, 1.0)
        dcol = tvp.ramp_at(r4, 0.05 + 0.15 * hfac)
        cv.dab(cx, cy + rc * 0.08, rc * 0.78, rc * 0.72 * flat, 0.0, dcol, alpha_add=True, edge=0.8, wob=0.2,
               opacity=core, bristle=0.0, streak=0.0)
        n = leaves_per
        pts = []
        for i in range(n):
            a = rng.uniform(0, 2 * math.pi)
            rr = rc * math.sqrt(rng.uniform(0.05, 1.0))
            px, py = cx + math.cos(a) * rr, cy + math.sin(a) * rr * flat
            pts.append((rr / rc, px, py, a))
        pts.sort(key=lambda p: p[0])  # inner first, rim last (the rim overlaps)
        for (fr, px, py, a) in pts:
            local = (cy - py) / max(rc, 1.0)  # +1 top of the clump
            t = 0.26 + 0.5 * hfac + 0.38 * local * fr + rng.uniform(-0.1, 0.1)
            body = cv.vary(tvp.ramp_at(r4, t), px, py, jit=0.05)
            if t > 0.8:
                body = mix(body, r4[3], (t - 0.8) * 1.5)
            dark = tvp.ramp_at(r4, t - 0.45)
            light = mix(tvp.ramp_at(r4, t + 0.35), r4[3], 0.35 + 0.45 * max(local, 0))
            ang = a + rng.normal(0, 0.5)
            L = leaf_len * rng.uniform(0.75, 1.2)
            leaf(cv, px, py, L, L * leaf_w * rng.uniform(0.8, 1.1), ang, body, dark, light, up=lean_light)
        if flowers is not None:
            for i in range(int(leaves_per * 0.18)):
                a = rng.uniform(0, 2 * math.pi)
                rr = rc * math.sqrt(rng.uniform(0.1, 0.95))
                px, py = cx + math.cos(a) * rr, cy + math.sin(a) * rr * flat
                if py > cy + rc * 0.4:
                    continue
                c = flowers[rng.integers(0, len(flowers))]
                fr = leaf_len * rng.uniform(0.35, 0.55)
                cv.stroke3(px, py, fr, fr * 0.9, rng.uniform(0, 3), c, mix(c, r4[0], 0.6), mix(c, lin("#fffbe8"), 0.5),
                           up=(0, -1), h_add=0.3, edge=0.6, shade=0.3, alpha_add=True, bristle=0.1)


def round_crown(seed, r4, n_clumps=(5, 8), spread=0.36, leaf_len=22, flowers=None, light_top=False):
    cv = card(seed, r4)
    rng = cv.rng
    clumps = [(T / 2, T * 0.52, T * 0.24)]
    k = rng.integers(*n_clumps)
    for i in range(k):  # a ring of clumps round the centre: a round, lumpy puff filling the card
        a = 2 * math.pi * i / k + rng.uniform(-0.3, 0.3)
        rr = T * spread * rng.uniform(0.62, 0.8)
        clumps.append((T / 2 + math.cos(a) * rr, T * 0.52 + math.sin(a) * rr * 0.85, T * rng.uniform(0.14, 0.19)))
    if light_top:
        clumps.append((T / 2, T * 0.4, T * 0.25))
    clumps.sort(key=lambda c: -c[1])  # bottom clumps first
    clump_cluster(cv, clumps, leaf_len, r4, leaves_per=int(95 * (T / 512)), flowers=flowers)
    return cv


def pine_pad(seed, r4, wide=0.86, tall=0.34):
    """A karst pine tier: a flat, wide pad of needle tufts, lit along its top, dark beneath."""
    cv = card(seed, r4)
    rng = cv.rng
    clumps = []
    for i in range(rng.integers(6, 10)):
        x = T / 2 + rng.uniform(-0.5, 0.5) * T * wide * 0.75
        y = T * 0.55 + rng.uniform(-0.5, 0.5) * T * tall * 0.6
        clumps.append((x, y, T * rng.uniform(0.11, 0.16)))
    clumps.sort(key=lambda c: -c[1])
    ytop = min(c[1] - c[2] for c in clumps)
    ybot = max(c[1] + c[2] for c in clumps)
    for (cx, cy, rc) in clumps:
        cv.dab(cx, cy + rc * 0.15, rc * 1.05, rc * 0.5, 0.0, tvp.ramp_at(r4, 0.05), alpha_add=True, edge=0.8,
               wob=0.2, bristle=0.0, streak=0.0)
    for (cx, cy, rc) in clumps:
        for i in range(70):
            a = rng.uniform(math.pi * 1.0, math.pi * 2.0) if rng.random() < 0.7 else rng.uniform(0, math.pi)
            rr = rc * math.sqrt(rng.uniform(0.0, 1.0))
            px, py = cx + math.cos(a) * rr * 1.25, cy + math.sin(a) * rr * 0.55
            hfac = 1.0 - (py - ytop) / max(ybot - ytop, 1.0)
            t = 0.2 + 0.85 * hfac + rng.uniform(-0.1, 0.1)
            # a needle tuft: 3-5 thin strokes fanning out
            base_a = math.atan2(py - cy, px - cx) if rr > 3 else rng.uniform(0, 6.28)
            for k in range(rng.integers(3, 6)):
                na = base_a + rng.uniform(-0.6, 0.6)
                L = rng.uniform(10, 18)
                body = cv.vary(tvp.ramp_at(r4, t), px, py, jit=0.05)
                cv.stroke3(px + math.cos(na) * L * 0.5, py + math.sin(na) * L * 0.5, L * 0.5, 2.2, na, body,
                           tvp.ramp_at(r4, t - 0.4), mix(tvp.ramp_at(r4, t + 0.3), r4[3], 0.3), up=(0, -1), h_add=0.3,
                           taper=0.7, wob=0.02, edge=0.6, dark_off=0.6, light_off=0.5, alpha_add=True, bristle=0.0,
                           streak=0.0)
    return cv


def bamboo_spray(seed, r4):
    """A bamboo leaf spray: an arching twig with fans of long lance leaves drooping from its nodes, filling the
    card (the leaves hang: lit on their upper edge, darker underneath)."""
    cv = card(seed, r4)
    rng = cv.rng
    culm = ramp("bamboo")
    x0, y0 = T * rng.uniform(0.05, 0.15), T * rng.uniform(0.12, 0.22)
    x1, y1 = T * rng.uniform(0.85, 0.95), T * rng.uniform(0.3, 0.45)
    sag = rng.uniform(-60, -20)
    twig = [(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + math.sin(t * math.pi) * sag) for t in np.linspace(0, 1, 10)]
    for k in range(11):
        t = (k + 0.5) / 11
        nx, ny = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + math.sin(t * math.pi) * sag
        for j in range(rng.integers(4, 7)):
            a = math.pi / 2 + rng.uniform(-1.0, 1.0) + 0.35
            L = rng.uniform(85, 140)
            tt = 0.3 + 0.5 * (j % 3) / 2 + rng.uniform(-0.15, 0.2)
            body = cv.vary(tvp.ramp_at(r4, tt), nx, ny, jit=0.05)
            cx, cy = nx + math.cos(a) * L * 0.5, ny + math.sin(a) * L * 0.5
            cv.stroke3(cx, cy, L * 0.5, rng.uniform(10, 15), a, body, tvp.ramp_at(r4, tt - 0.45),
                       mix(tvp.ramp_at(r4, tt + 0.35), r4[3], 0.45), up=(math.cos(a - 1.57), math.sin(a - 1.57)),
                       h_add=0.4, taper=0.85, wob=0.03, edge=0.6, dark_off=0.3, light_off=0.35, alpha_add=True,
                       bend=rng.uniform(-0.3, 0.3), bristle=0.15)
    cv.path(twig, 6, culm[1], culm[0], alpha_add=True, bristle=0.1, dry=0.0)
    return cv


def banana_leaf(seed, r4):
    """One big banana leaf: a paddle with a pale midrib, the lit half lighter, torn along its veins."""
    cv = card(seed, r4)
    rng = cv.rng
    a = -math.pi / 4
    cx, cy = T * 0.5, T * 0.5
    L, W = T * 0.46, T * 0.17
    cv.dab(cx, cy, L, W, a, tvp.ramp_at(r4, 0.45), color2=tvp.ramp_at(r4, 0.6), alpha_add=True, edge=0.8, power=2.2,
           wob=0.02, bristle=0.2, bend=0.12)
    # the shaded half
    ca, sa = math.cos(a), math.sin(a)
    for i in range(30):
        t = rng.uniform(-0.9, 0.9)
        px, py = cx + ca * L * t, cy + sa * L * t
        nx, ny = -sa, ca
        side = 1 if i % 2 else -1
        off = W * rng.uniform(0.2, 0.75) * side
        c = tvp.ramp_at(r4, 0.25 if side > 0 else 0.7) if True else None
        cv.dab(px + nx * off, py + ny * off, W * 0.5, W * 0.13, a + side * 1.0, cv.vary(c, px, py), opacity=0.55,
               edge=0.5, bristle=0.5, dry=0.5)
    # veins: thin lines angled off the midrib; tears along a few of them
    for i in range(16):
        t = -0.85 + i * 0.11
        px, py = cx + ca * L * t, cy + sa * L * t
        for side in (-1, 1):
            va = a + side * 1.1
            ex, ey = px + math.cos(va) * W * 1.1, py + math.sin(va) * W * 1.1
            cv.path([(px, py), (ex, ey)], 2.0, tvp.ramp_at(r4, 0.3), opacity=0.5, bristle=0.0)
            if rng.random() < 0.25:
                cv.alpha = cv.alpha * (1 - _line_mask(cv, (px + (ex - px) * 0.45, py + (ey - py) * 0.45), (ex, ey), 2.5))
    cv.path([(cx - ca * L * 1.0, cy - sa * L * 1.0), (cx + ca * L * 0.95, cy + sa * L * 0.95)], 7,
            mix(r4[2], r4[3], 0.6), alpha_add=True, bristle=0.0, dry=0.0)
    return cv


def _line_mask(cv, p0, p1, w):
    Y, X = np.mgrid[0:cv.h, 0:cv.w].astype(np.float32)
    d = np.array(p1) - np.array(p0)
    L2 = float(d @ d)
    t = np.clip(((X - p0[0]) * d[0] + (Y - p0[1]) * d[1]) / max(L2, 1e-6), 0, 1)
    dist = np.hypot(X - (p0[0] + t * d[0]), Y - (p0[1] + t * d[1]))
    return (dist < w).astype(np.float32)


def fern_frond(seed, r4, upright=True):
    cv = card(seed, r4)
    rng = cv.rng
    # an arching stem from the bottom centre
    pts = []
    n = 14
    lean = rng.uniform(0.35, 0.7) * (1 if rng.random() < 0.5 else -1)
    for i in range(n):
        t = i / (n - 1)
        pts.append((T * 0.5 + lean * T * 0.35 * t * t, T * 0.97 - T * 0.85 * t + T * 0.18 * t * t * abs(lean)))
    cv.path(pts, 5, r4[0], r4[1], alpha_add=True, bristle=0.0)
    for i in range(1, n - 1):
        t = i / (n - 1)
        px, py = pts[i]
        dx, dy = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
        sa = math.atan2(dy, dx)
        ll = T * 0.17 * (1 - 0.75 * t) * (0.6 if t < 0.15 else 1.0)
        for side in (-1, 1):
            aa = sa + side * 1.15
            tt = 0.3 + 0.5 * t + rng.uniform(-0.1, 0.1)
            cv.stroke3(px + math.cos(aa) * ll * 0.55, py + math.sin(aa) * ll * 0.55, ll * 0.55, ll * 0.2, aa,
                       cv.vary(tvp.ramp_at(r4, tt), px, py), tvp.ramp_at(r4, tt - 0.4),
                       mix(tvp.ramp_at(r4, tt + 0.3), r4[3], 0.4), up=(0, -1), h_add=0.3, taper=0.75, wob=0.04,
                       edge=0.6, dark_off=0.35, alpha_add=True, bristle=0.15, bend=0.2 * side)
    return cv


def bark(seed, r4, w, h, kind):
    cv = tvp.Canvas(h, w, 1.0 * w / 512, seed, r4, bristle=0.4)
    rng = cv.rng
    cv.base(dv=0.1)
    if kind == "broadleaf":
        # vertical furrowed ridges
        for i in range(260):
            x, y = rng.uniform(0, w), rng.uniform(0, h)
            L = rng.uniform(60, 220)
            t = rng.uniform(0.3, 0.95)
            cv.stroke3(x, y, L, rng.uniform(6, 16), math.pi / 2 + rng.uniform(-0.08, 0.08),
                       cv.vary(tvp.ramp_at(r4, t), x, y), tvp.ramp_at(r4, t - 0.5), mix(tvp.ramp_at(r4, t + 0.3), r4[3], 0.3),
                       up=(-1, 0), h_add=0.6, taper=0.5, wob=0.08, edge=0.6, dark_off=0.4, light_off=0.3,
                       bend=rng.uniform(-0.2, 0.2), bristle=0.5, dry=0.5)
        for i in range(5):
            x, y = rng.uniform(0, w), rng.uniform(0, h)
            cv.stroke3(x, y, 18, 12, math.pi / 2, r4[0], mix(r4[0], lin("#000000"), 0.3), r4[2], up=(0, -1), h_add=-0.5,
                       edge=0.6, shade=0.4)
        cv.cavity(k=0.45, cool=tvp.AO_WOOD, sigma_frac=1 / 40.0)
        cv.edge_light(amt=0.15, up=(-1, 0))
        cv.finish(value_target=0.36, squint=0.18)
    elif kind == "pine":
        for i in range(160):
            x, y = rng.uniform(0, w), rng.uniform(0, h)
            r = rng.uniform(18, 40)
            t = rng.uniform(0.35, 0.95)
            cv.stroke3(x, y, r * 0.8, r * 1.4, 0.0, cv.vary(tvp.ramp_at(r4, t), x, y), tvp.ramp_at(r4, t - 0.55),
                       mix(tvp.ramp_at(r4, t + 0.3), r4[3], 0.5), up=(0, -1), h_add=0.8, wob=0.1, edge=0.75,
                       poly=tvp.random_poly(rng, (5, 7), 0.3), shade=0.3, bristle=0.4)
        cv.cavity(k=0.5, cool=tvp.AO_WOOD, sigma_frac=1 / 50.0)
        cv.edge_light(amt=0.2)
        cv.finish(value_target=0.38, squint=0.18)
    elif kind == "bamboo":
        node = h / 3.0
        for i in range(120):
            x, y = rng.uniform(0, w), rng.uniform(0, h)
            cv.dab(x, y, rng.uniform(40, 160), rng.uniform(4, 12), math.pi / 2,
                   cv.vary(tvp.ramp_at(r4, rng.uniform(0.4, 1.0)), x, y), opacity=0.5, edge=0.5, bristle=0.6, dry=0.5)
        for k in range(3):
            y = (k + 0.5) * node
            cv.dab(w / 2, y, w / 2 + 2, 7, 0.0, tvp.ramp_at(r4, 0.0), power=6, edge=0.7, bristle=0.2, wob=0.0)
            cv.dab(w / 2, y - 9, w / 2 + 2, 4, 0.0, r4[3], power=6, edge=0.6, opacity=0.7, bristle=0.2, wob=0.0)
            cv.dab(w / 2, y + 30, w / 2 + 2, 28, 0.0, tvp.ramp_at(r4, 0.15), power=4, edge=0.2, opacity=0.35,
                   bristle=0.3, wob=0.0)
        # the culm's roundness: lit one side, shaded the other
        X = np.arange(w, dtype=np.float32)[None, :] / w
        sh = 0.75 + 0.35 * np.sin(X * 2 * math.pi)
        cv.col = cv.col * sh[..., None]
        cv.finish(value_target=0.5, squint=0.0)
    else:  # banana trunk sheaths
        for i in range(90):
            x, y = rng.uniform(0, w), rng.uniform(0, h)
            t = rng.uniform(0.2, 0.95)
            cv.stroke3(x, y, rng.uniform(80, 260), rng.uniform(18, 40), math.pi / 2 + rng.uniform(-0.1, 0.1),
                       cv.vary(tvp.ramp_at(r4, t), x, y), tvp.ramp_at(r4, t - 0.45),
                       mix(tvp.ramp_at(r4, t + 0.3), r4[3], 0.5), up=(-1, 0), h_add=0.6, taper=0.3, edge=0.7,
                       dark_off=0.35, bristle=0.5, dry=0.4)
        cv.cavity(k=0.4, cool=tvp.AO_WOOD, sigma_frac=1 / 40.0)
        cv.finish(value_target=0.45, squint=0.18)
    return cv


def hexagon_hull(alpha, thr=0.5):
    """An enclosing hexagon of the alpha > thr pixels (normalised 0..1, y down), from support lines at 6 angles."""
    ys, xs = np.nonzero(alpha > thr)
    if len(xs) == 0:
        return [[0, 0], [1, 0], [1, 1], [0, 1]]
    h, w = alpha.shape
    P = np.stack([(xs + 0.5) / w, (ys + 0.5) / h], -1)
    angs = [math.radians(a) for a in (90, 30, -30, -90, -150, 150)]
    lines = []
    for a in angs:
        n = np.array([math.cos(a), math.sin(a)])
        lines.append((n, float((P @ n).max()) + 0.5 / w))
    pts = []
    for i in range(6):
        n1, d1 = lines[i]
        n2, d2 = lines[(i + 1) % 6]
        A = np.array([n1, n2])
        p = np.linalg.solve(A, np.array([d1, d2]))
        pts.append([round(float(np.clip(p[0], 0, 1)), 4), round(float(np.clip(p[1], 0, 1)), 4)])
    return pts


def finish_card(cv):
    c = tvp.blur_clamped(cv.col, 0.5)
    a = np.clip(tvp.blur_clamped(cv.alpha, 0.6), 0, 1)
    # bleed the colour out under the transparent parts so mips never fringe dark
    wsum = tvp.blur_clamped(a, 6.0)[..., None]
    bleed = tvp.blur_clamped(c * a[..., None], 6.0) / np.maximum(wsum, 1e-4)
    c = np.where(a[..., None] > 0.02, c, bleed)
    return tvp.to_u8(np.concatenate([tvp.l2s(np.clip(c, 0, 1)), a[..., None]], -1)), a


# ------------------------------------------------------------------ grass / herb cards (512 x 256 cells)

def blade_card(seed, root_lin, r4, n=(15, 22), height=(0.55, 0.95), width=(10, 16), lean=0.5, kind="grass",
               panicles=False, flowers=None, fern=False):
    W, H = 512, 256
    cv = tvp.Canvas(H, W, 1.0, seed, r4, alpha=True, wrap=False, bristle=0.2, streak=0.04)
    rng = cv.rng
    if fern:
        for k in range(rng.integers(3, 5)):
            a0 = -math.pi / 2 + rng.uniform(-0.8, 0.8)
            L = H * rng.uniform(0.6, 0.95)
            x0 = W / 2 + rng.uniform(-40, 40)
            pts = [(x0 + math.cos(a0) * L * t + a0 * 0 + (t * t) * 60 * math.copysign(1, math.cos(a0)),
                    H - 2 + math.sin(a0) * L * t + t * t * 30) for t in np.linspace(0, 1, 10)]
            cv.path(pts, 3, r4[0], r4[1], alpha_add=True, bristle=0.0)
            for i in range(1, 9):
                px, py = pts[i]
                dx, dy = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
                sa = math.atan2(dy, dx)
                ll = 34 * (1 - i / 10)
                for side in (-1, 1):
                    aa = sa + side * 1.2
                    tt = 0.35 + 0.05 * i + rng.uniform(-0.1, 0.1)
                    cv.stroke3(px + math.cos(aa) * ll * 0.5, py + math.sin(aa) * ll * 0.5, ll * 0.5, ll * 0.2, aa,
                               tvp.ramp_at(r4, tt), tvp.ramp_at(r4, tt - 0.4), mix(tvp.ramp_at(r4, tt + 0.3), r4[3], 0.3),
                               up=(0, -1), h_add=0.2, taper=0.7, alpha_add=True, edge=0.6, bristle=0.1)
    else:
        nb = rng.integers(*n)
        for i in range(nb):
            x0 = W / 2 + rng.normal(0, W * 0.09)
            a0 = -math.pi / 2 + rng.uniform(-lean, lean)
            L = H * rng.uniform(*height)
            curl = rng.uniform(-0.6, 0.6)
            pts = []
            for t in np.linspace(0, 1, 9):
                a = a0 + curl * t * t
                pts.append((x0 + math.cos(a) * L * t + curl * 30 * t * t, H - 1 + math.sin(a) * L * t))
            wd = rng.uniform(*width)
            tip_t = rng.uniform(0.7, 1.0)
            tip = mix(tvp.ramp_at(r4, tip_t), r4[3], 0.3 if rng.random() < 0.3 else 0.0)
            cv.path(pts, wd, root_lin, tip, alpha_add=True, bristle=0.25, dry=0.0, taper=(0.02, 0.45), step=0.35)
            # a lit edge on one side of the blade
            off = [(p[0] + wd * 0.18, p[1]) for p in pts[2:]]
            cv.path(off, wd * 0.3, mix(tip, lin("#fffbe8"), 0.15), opacity=0.5, bristle=0.3, taper=(0.1, 0.4),
                    step=0.4)
            if panicles and rng.random() < 0.55:
                px, py = pts[-1]
                for k in range(8):
                    cv.dab(px + rng.normal(0, 6) + k * 2.5, py + k * 5, 4, 3, 0.4, lin("#c9b45a"), alpha_add=True,
                           bristle=0.0, edge=0.6)
    if flowers is not None:
        for k in range(rng.integers(4, 8)):
            x0 = W / 2 + rng.normal(0, W * 0.12)
            top = H * rng.uniform(0.15, 0.5)
            cv.path([(x0, H - 1), (x0 + rng.uniform(-20, 20), top)], 3.5, root_lin, lin("#4f7a33"), alpha_add=True,
                    bristle=0.0, taper=(0.05, 0.9))
            c = flowers[rng.integers(0, len(flowers))]
            fx, fy = x0 + rng.uniform(-20, 20), top
            for p in range(5):
                a = p * 2 * math.pi / 5 + rng.uniform(0, 0.3)
                cv.stroke3(fx + math.cos(a) * 9, fy + math.sin(a) * 9, 9, 6, a, c, mix(c, r4[0], 0.5),
                           mix(c, lin("#fffbe8"), 0.45), up=(0, -1), h_add=0.2, edge=0.6, alpha_add=True, bristle=0.0)
            cv.dab(fx, fy, 5, 5, 0, lin("#e8c040"), alpha_add=True, bristle=0.0)
    return cv


def pack_cells(cells, cell_w=512, cell_h=256, cols=4, kinds=None):
    rows = (len(cells) + cols - 1) // cols
    W, H = cols * cell_w, rows * cell_h
    atlas = np.zeros((H, W, 4), np.uint8)
    meta = []
    for i, (img, a, kind) in enumerate(cells):
        cx, cy = (i % cols) * cell_w, (i // cols) * cell_h
        atlas[cy:cy + cell_h, cx:cx + cell_w] = img
        ys, xs = np.nonzero(a > 0.5)
        x0, x1 = (xs.min(), xs.max() + 1) if len(xs) else (0, cell_w)
        y0 = ys.min() if len(ys) else 0
        x0, x1, y0 = max(x0 - 2, 0), min(x1 + 2, cell_w), max(y0 - 2, 0)
        meta.append({"cell": i, "kind": kind,
                     "uv_rect": [(cx + x0) / W, (cy + y0) / H, (cx + x1) / W, (cy + cell_h) / H],
                     "aspect": round((x1 - x0) / max(cell_h - y0, 1), 4),
                     "coverage": round(float((a > 0.5).mean()), 4)})
    return atlas, meta


def main():
    out = os.path.join(tvp.OUT, "foliage")
    os.makedirs(out, exist_ok=True)
    bl, pn, bb, fe = ramp("broadleaf"), ramp("pine"), ramp("bamboo"), ramp("fern")
    fl = ramp("flowers")
    banana = np.stack([mix(bb[0], bl[0], 0.5), mix(bb[1], bl[2], 0.3), bb[2], bb[3]])
    tiles = [
        ("broadleaf_a", "broadleaf", 4.0, lambda s: round_crown(s, bl)),
        ("broadleaf_b", "broadleaf", 4.0, lambda s: round_crown(s, bl, n_clumps=(6, 9), leaf_len=20)),
        ("broadleaf_c", "broadleaf", 4.0, lambda s: round_crown(s, bl, n_clumps=(4, 6), leaf_len=26)),
        ("broadleaf_top", "broadleaf", 4.0, lambda s: round_crown(s, bl, n_clumps=(3, 5), leaf_len=24, light_top=True)),
        ("pine_pad_a", "pine", 4.0, lambda s: pine_pad(s, pn)),
        ("pine_pad_b", "pine", 4.0, lambda s: pine_pad(s, pn, wide=0.7, tall=0.4)),
        ("pine_pad_c", "pine", 4.0, lambda s: pine_pad(s, pn, wide=0.95, tall=0.28)),
        ("pine_tuft", "pine", 3.0, lambda s: round_crown(s, pn, n_clumps=(4, 6), leaf_len=16)),
        ("bamboo_a", "bamboo", 2.5, lambda s: bamboo_spray(s, bb)),
        ("bamboo_b", "bamboo", 2.5, lambda s: bamboo_spray(s, bb)),
        ("bamboo_c", "bamboo", 2.5, lambda s: bamboo_spray(s, bb)),
        ("banana_leaf", "banana", 3.0, lambda s: banana_leaf(s, banana)),
        ("fern_a", "fern", 1.6, lambda s: fern_frond(s, fe)),
        ("fern_b", "fern", 1.6, lambda s: fern_frond(s, fe)),
        ("shrub_madder", "shrub", 2.0, lambda s: round_crown(s, bl, n_clumps=(4, 7), leaf_len=16,
                                                              flowers=[fl[0], mix(fl[0], fl[3], 0.5)])),
        ("shrub_white", "shrub", 2.0, lambda s: round_crown(s, fe, n_clumps=(4, 7), leaf_len=16,
                                                             flowers=[fl[2], fl[3], fl[1]])),
    ]
    atlas = np.zeros((4 * T, 4 * T, 4), np.uint8)
    meta = {"atlas": [4 * T, 4 * T], "tile": T, "tiles": {}}
    for i, (name, kind, size, fn) in enumerate(tiles):
        cv = fn(7700 + i * 13)
        img, a = finish_card(cv)
        r, c = i // 4, i % 4
        atlas[r * T:(r + 1) * T, c * T:(c + 1) * T] = img
        meta["tiles"][name] = {"coverage": round(float((a > 0.5).mean()), 3), "hull": hexagon_hull(a), "index": i,
                               "kind": kind, "size": size, "uv": [c / 4, r / 4, 0.25, 0.25]}
        print("tile %2d %-14s coverage %.3f" % (i, name, meta["tiles"][name]["coverage"]), flush=True)
    Image.fromarray(atlas).save(os.path.join(out, "tv_foliage_atlas.png"), optimize=True)
    with open(os.path.join(out, "tv_foliage_tiles.json"), "w") as f:
        json.dump(meta, f, indent=1)

    bark_r = ramp("bark")
    for name, r4, w, h, kind in [("tv_bark_broadleaf", bark_r, 512, 1024, "broadleaf"),
                                 ("tv_bark_pine", np.stack([bark_r[0], mix(bark_r[1], lin("#7a4a32"), 0.4),
                                                            mix(bark_r[2], lin("#a0684a"), 0.3), bark_r[3]]),
                                  512, 1024, "pine"),
                                 ("tv_bamboo_culm", bb, 256, 1024, "bamboo"),
                                 ("tv_banana_trunk", np.stack([mix(bb[0], bark_r[0], 0.5), mix(bb[1], bark_r[2], 0.4),
                                                               mix(bb[2], bark_r[3], 0.3), bb[3]]), 512, 1024, "banana")]:
        cv = bark(7900 + len(name), r4, w, h, kind)
        Image.fromarray(tvp.to_u8(tvp.l2s(cv.col))).save(os.path.join(out, name + ".png"), optimize=True)
        print("bark", name, flush=True)

    # grass / herb cards: root colour = the terrain slice's mean colour
    sl = json.load(open(os.path.join(tvp.OUT, "terrain", "terrain_slices.json")))["slices"]
    root = {s["key"]: tvp.s2l(np.array(s["mean_srgb"], np.float32)) for s in sl}
    gr, tr = ramp("grass"), ramp("terrace_rice")
    meadow = np.stack([gr[0], mix(gr[1], tr[1], 0.45), mix(gr[2], tr[2], 0.5), mix(gr[3], tr[3], 0.5)])
    cells = []
    specs = [("grass", root["grass"] * 0.85, gr, {}) for _ in range(4)] + \
            [("grass_short", root["grass"] * 0.85, gr, {"height": (0.35, 0.6), "n": (10, 16)}) for _ in range(2)] + \
            [("rice", root["terrace_rice"] * 0.8, tr, {"height": (0.7, 1.0), "width": (6, 10), "lean": 0.3,
                                                      "n": (14, 20), "panicles": True}) for _ in range(4)] + \
            [("meadow", root["meadow"] * 0.85, meadow, {"lean": 0.6}) for _ in range(4)] + \
            [("moss_tuft", root["moss_fern"] * 0.85, ramp("moss"), {"height": (0.3, 0.55), "width": (10, 16)})
             for _ in range(2)]
    for i, (kind, rl, r4, kw) in enumerate(specs):
        cv = blade_card(8100 + i * 7, rl, r4, kind=kind, **kw)
        img, a = finish_card(cv)
        cells.append((img, a, kind))
    atlas, gmeta = pack_cells(cells)
    Image.fromarray(atlas).save(os.path.join(out, "tv_grass_atlas.png"), optimize=True)
    json.dump(gmeta, open(os.path.join(out, "tv_grass_variants.json"), "w"), indent=1)
    print("grass atlas", atlas.shape, flush=True)
    cells = []
    hspecs = [("flower", root["meadow"] * 0.85, meadow, {"n": (4, 7), "height": (0.3, 0.6),
                                                        "flowers": [fl[c]]}) for c in (0, 1, 2, 3)] + \
             [("flower_mix", root["grass"] * 0.85, gr, {"n": (5, 8), "height": (0.3, 0.55),
                                                       "flowers": [fl[0], fl[1], fl[2], fl[3]]}) for _ in range(4)] + \
             [("fern", root["moss_fern"] * 0.85, fe, {"fern": True}) for _ in range(4)] + \
             [("herb", root["forest_floor"] * 0.9, ramp("broadleaf"), {"n": (6, 9), "width": (16, 26),
                                                                       "height": (0.35, 0.7), "lean": 0.9})
              for _ in range(4)]
    for i, (kind, rl, r4, kw) in enumerate(hspecs):
        cv = blade_card(8300 + i * 7, rl, r4, kind=kind, **kw)
        img, a = finish_card(cv)
        cells.append((img, a, kind))
    atlas, hmeta = pack_cells(cells)
    Image.fromarray(atlas).save(os.path.join(out, "tv_herb_atlas.png"), optimize=True)
    json.dump(hmeta, open(os.path.join(out, "tv_herb_variants.json"), "w"), indent=1)
    print("herb atlas", atlas.shape, flush=True)


if __name__ == "__main__":
    main()
