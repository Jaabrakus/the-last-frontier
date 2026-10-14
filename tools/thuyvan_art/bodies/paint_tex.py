"""Painted tiling textures for the body review renders (numpy + PIL), after the brush recipe of
docs/thuyvan/plan/look/style_guide.md section 3.2: paint on a torus, a 4-stop ramp, low-frequency variation, big and
medium dabs with firm painter's edges, a dark copy under and a light sliver over each medium dab, cavity AO from the
stroke height, no photographic grain. Fixed seeds.

Value maps (grey, 0..1) are mapped through ramps in the shader, so one scute or bark map serves every skin value
(the skin_map: melanin -> value, undertone -> cast).

    python3 paint_tex.py OUT_DIR
"""

import math
import os
import sys

import numpy as np
from PIL import Image


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def value_noise(n, period, rng):
    """Tileable value noise with `period` cells across the tile."""
    g = rng.rand(period, period)
    x = np.arange(n) * period / n
    i0 = np.floor(x).astype(int)
    f = x - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % period
    a = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
    b = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
    return a * (1 - f)[:, None] + b * f[:, None]


class Canvas:
    def __init__(self, n, channels=1):
        self.n = n
        self.c = np.zeros((n, n, channels))
        self.h = np.zeros((n, n))
        self.a = np.zeros((n, n))
        yy, xx = np.mgrid[0:n, 0:n]
        self.yy, self.xx = yy, xx

    def dab(self, cx, cy, rx, ry, ang, col, height=0.0, alpha=1.0, edge=0.75, wrap=True, write_alpha=False, p=2.0):
        """Elliptical dab, firm edge (alpha = smoothstep(1, edge, r)), wrapping on the torus."""
        n = self.n
        R = int(max(rx, ry)) + 2
        x0, x1 = int(cx) - R, int(cx) + R + 1
        y0, y1 = int(cy) - R, int(cy) + R + 1
        xs = np.arange(x0, x1)
        ys = np.arange(y0, y1)
        X, Y = np.meshgrid(xs, ys)
        ca, sa = math.cos(ang), math.sin(ang)
        dx, dy = X - cx, Y - cy
        u = (dx * ca + dy * sa) / rx
        v = (-dx * sa + dy * ca) / ry
        r = (np.abs(u) ** p + np.abs(v) ** p) ** (1.0 / p)
        t = np.clip((1.0 - r) / (1.0 - edge), 0, 1)
        m = t * t * (3 - 2 * t) * alpha
        if wrap:
            Xi, Yi = X % n, Y % n
        else:
            ok = (X >= 0) & (X < n) & (Y >= 0) & (Y < n)
            m = m * ok
            Xi, Yi = np.clip(X, 0, n - 1), np.clip(Y, 0, n - 1)
        col = np.asarray(col, float).reshape(1, 1, -1)
        self.c[Yi, Xi] = self.c[Yi, Xi] * (1 - m[..., None]) + col * m[..., None]
        if height:
            self.h[Yi, Xi] = np.maximum(self.h[Yi, Xi], height * m)
        if write_alpha:
            self.a[Yi, Xi] = np.maximum(self.a[Yi, Xi], m)


def blur(a, r):
    """Box blur x3 on the torus."""
    out = a.copy()
    for _ in range(3):
        for ax in (0, 1):
            acc = np.zeros_like(out)
            for k in range(-r, r + 1):
                acc += np.roll(out, k, axis=ax)
            out = acc / (2 * r + 1)
    return out


def cavity(h, r):
    return np.clip(blur(h, r) - h, 0, 1)


def ramp_lookup(val, stops):
    """val (..) in 0..1 -> colour on the 4-stop ramp (linear interpolation in linear light)."""
    S = np.array([srgb_to_lin(hexrgb(s)) for s in stops])
    x = np.clip(val, 0, 1) * (len(S) - 1)
    i = np.clip(np.floor(x).astype(int), 0, len(S) - 2)
    f = (x - i)[..., None]
    return S[i] * (1 - f) + S[i + 1] * f


# ===========================================================================
def grass_ground(n=1024, seed=3):
    """The neutral painted ground (style guide 11): the r1 grass ramp, tile 8 m, calm so the figures read."""
    rng = np.random.RandomState(seed)
    ramp = ["#2f5a2c", "#4e8a36", "#84b546", "#c2d16a"]
    base = 0.46 + 0.10 * (value_noise(n, 2, rng) - 0.5) + 0.06 * (value_noise(n, 4, rng) - 0.5)
    cv = Canvas(n, 1)
    cv.c[..., 0] = base
    for _ in range(70):
        cv.dab(rng.rand() * n, rng.rand() * n, n * (0.06 + 0.07 * rng.rand()), n * (0.03 + 0.03 * rng.rand()),
               rng.rand() * math.pi, [rng.choice([0.36, 0.44, 0.52, 0.6], p=[0.2, 0.35, 0.35, 0.1]) + rng.randn() * 0.015],
               height=1.0, edge=0.5)
    for _ in range(900):
        x, y = rng.rand() * n, rng.rand() * n
        L, w = n * (0.006 + 0.008 * rng.rand()), n * (0.0018 + 0.0015 * rng.rand())
        ang = math.pi / 2 + rng.randn() * 0.4
        cv.dab(x, y + w, L, w, ang, [0.3], height=0.5)
        cv.dab(x, y, L, w, ang, [rng.choice([0.5, 0.6, 0.7], p=[0.4, 0.4, 0.2])], height=0.5)
    v = cv.c[..., 0] - cavity(cv.h, n // 48) * 0.3
    v = np.clip(v, 0.12, 0.85)
    col = ramp_lookup(v, ramp)
    return Image.fromarray((lin_to_srgb(col) * 255).astype(np.uint8))


def scutes(n=1024, seed=5, rows=12, cols=10):
    """Crocodilian scute value map: offset rows of rounded rectangular plates, each a firm dab painted in 3-5 values
    with its occlusion under it and a light sliver on top; dark seams. Tile ~0.45 m (scutes 3.5-4.5 cm)."""
    rng = np.random.RandomState(seed)
    cv = Canvas(n, 1)
    cv.c[..., 0] = 0.12
    ch, cw = n / rows, n / cols
    for r in range(rows):
        for c in range(cols):
            cx = (c + 0.5 + (0.5 if r % 2 else 0.0)) * cw + rng.randn() * cw * 0.05
            cy = (r + 0.5) * ch + rng.randn() * ch * 0.05
            val = rng.choice([0.42, 0.55, 0.66, 0.78], p=[0.25, 0.4, 0.25, 0.1]) + rng.randn() * 0.03
            rx, ry = cw * 0.47, ch * 0.44
            cv.dab(cx, cy + ry * 0.16, rx, ry, rng.randn() * 0.04, [0.08], height=0.0, edge=0.75, p=3.5)
            cv.dab(cx, cy, rx * 0.95, ry * 0.92, rng.randn() * 0.04, [val], height=1.0, edge=0.8, p=3.5)
            cv.dab(cx, cy - ry * 0.34, rx * 0.72, ry * 0.30, 0, [min(1.0, val + 0.22)], edge=0.7, p=3.0)
            if rng.rand() < 0.35:   # a keel boss on some
                cv.dab(cx, cy - ry * 0.05, rx * 0.25, ry * 0.5, 0, [min(1.0, val + 0.12)], height=1.0)
    v = cv.c[..., 0] - cavity(cv.h, n // 64) * 0.4
    v = blur(v, 1)
    return np.clip(v, 0.03, 0.97)


def osteoderms(n=1024, seed=9, rows=11):
    """Dorsal value map: irregular rows of rounded osteoderm plates of mixed sizes, each with a keel ridge lit on
    top; narrow dark seams. Tile ~0.36 m."""
    rng = np.random.RandomState(seed)
    cv = Canvas(n, 1)
    cv.c[..., 0] = 0.2
    ch = n / rows
    for r in range(rows):
        x = rng.rand() * n * 0.1
        while x < n:
            w = n * (0.055 + 0.05 * rng.rand())
            cx = x + w / 2
            cy = (r + 0.5) * ch + rng.randn() * ch * 0.08
            val = rng.choice([0.38, 0.5, 0.62, 0.74], p=[0.25, 0.4, 0.25, 0.1]) + rng.randn() * 0.03
            rx, ry = w * 0.55, ch * (0.52 + 0.06 * rng.rand())
            cv.dab(cx, cy + ry * 0.15, rx, ry, rng.randn() * 0.06, [0.1], edge=0.75, p=2.4)
            cv.dab(cx, cy, rx * 0.93, ry * 0.9, rng.randn() * 0.06, [val], height=1.0, edge=0.8, p=2.4)
            cv.dab(cx, cy + ry * 0.05, rx * 0.13, ry * 0.45, 0, [min(1.0, val + 0.07)], height=1.0, edge=0.6)
            cv.dab(cx - rx * 0.1, cy - ry * 0.48, rx * 0.62, ry * 0.2, 0, [min(1.0, val + 0.2)], edge=0.6)
            x += w * (0.98 + 0.08 * rng.rand())
    v = cv.c[..., 0] - cavity(cv.h, n // 64) * 0.35
    return np.clip(blur(v, 1), 0.03, 0.97)


def bark(n=1024, seed=8):
    """Bark value map: vertical grain strokes in long plates with dark cracks between; finer strokes on top."""
    rng = np.random.RandomState(seed)
    cv = Canvas(n, 1)
    cv.c[..., 0] = 0.18
    for _ in range(140):
        x, y = rng.rand() * n, rng.rand() * n
        L, w = n * (0.12 + 0.18 * rng.rand()), n * (0.025 + 0.03 * rng.rand())
        val = rng.choice([0.45, 0.58, 0.7], p=[0.3, 0.45, 0.25])
        ang = math.pi / 2 + rng.randn() * 0.06
        cv.dab(x + w * 0.2, y, L, w, ang, [0.1], edge=0.7)
        cv.dab(x, y, L, w * 0.85, ang, [val], height=1.0, edge=0.6)
        cv.dab(x - w * 0.35, y, L * 0.85, w * 0.25, ang, [min(1, val + 0.22)], edge=0.5)
    for _ in range(600):
        x, y = rng.rand() * n, rng.rand() * n
        L, w = n * (0.03 + 0.05 * rng.rand()), n * 0.004
        cv.dab(x, y, L, w, math.pi / 2 + rng.randn() * 0.05, [rng.choice([0.25, 0.85])], edge=0.5)
    v = cv.c[..., 0] - cavity(cv.h, n // 64) * 0.35
    return np.clip(blur(v, 1), 0.03, 0.97)


def leaf_cluster(n=512, seed=2, ramp=("#123a24", "#1f4a2e", "#3e7a3c", "#77a84a")):
    """RGBA card: a cluster of 9-14 rounded leaf dabs (style guide 6), lighter on the upper halves, alpha = union."""
    rng = np.random.RandomState(seed)
    cv = Canvas(n, 3)
    S = [srgb_to_lin(hexrgb(s)) for s in ramp]
    k = rng.randint(16, 22)
    items = []
    for i in range(k):
        a = rng.rand() * 2 * math.pi
        r = n * 0.27 * math.sqrt(rng.rand())
        items.append((n / 2 + math.cos(a) * r, n / 2 + math.sin(a) * r, a))
    items.sort(key=lambda t: -t[1])          # back (lower) leaves first, the lit top ones over them
    for cx, cy, a in items:
        L, w = n * (0.13 + 0.05 * rng.rand()), n * (0.065 + 0.025 * rng.rand())
        ang = a + rng.randn() * 0.4
        depth = (cy / n)
        body = S[1] * (0.6 + 0.4 * (1 - depth)) + S[2] * (0.4 * (1 - depth))
        cv.dab(cx, cy + w * 0.15, L * 1.02, w * 1.05, ang, S[0], edge=0.85, wrap=False, write_alpha=True)
        cv.dab(cx, cy, L, w, ang, body, height=1.0, edge=0.85, wrap=False, write_alpha=True)
        cv.dab(cx, cy - w * 0.3, L * 0.75, w * 0.32, ang, S[3] * 0.9 + S[2] * 0.1, edge=0.75, wrap=False)
    col = cv.c * (1 - 0.35 * cavity(cv.h, 6)[..., None])
    rgba = np.concatenate([lin_to_srgb(col), cv.a[..., None]], 2)
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")


def flower(n=256):
    """RGBA five-petal flower card, #f2eedc petals, a warm centre."""
    cv = Canvas(n, 3)
    petal = srgb_to_lin(hexrgb("#f2eedc"))
    shade = srgb_to_lin(hexrgb("#c9c2a4"))
    for k in range(5):
        a = -math.pi / 2 + k * 2 * math.pi / 5
        cx, cy = n / 2 + math.cos(a) * n * 0.2, n / 2 + math.sin(a) * n * 0.2
        cv.dab(cx, cy, n * 0.2, n * 0.14, a, shade, wrap=False, write_alpha=True, edge=0.88)
        cv.dab(cx - math.cos(a) * 2, cy - math.sin(a) * 2 - 3, n * 0.17, n * 0.11, a, petal, wrap=False, edge=0.8)
    cv.dab(n / 2, n / 2, n * 0.07, n * 0.07, 0, srgb_to_lin(hexrgb("#e2c04a")), wrap=False, write_alpha=True)
    rgba = np.concatenate([lin_to_srgb(cv.c), cv.a[..., None]], 2)
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")


def save_value(v, path):
    Image.fromarray((v * 255).astype(np.uint8), "L").save(path)


def main(out):
    os.makedirs(out, exist_ok=True)
    grass_ground().save(os.path.join(out, "ground_grass.png"))
    save_value(scutes(), os.path.join(out, "fb_scutes.png"))
    save_value(osteoderms(), os.path.join(out, "fb_osteoderms.png"))
    save_value(bark(), os.path.join(out, "mt_bark.png"))
    leaf_cluster(seed=2).save(os.path.join(out, "mt_leaves_a.png"))
    leaf_cluster(seed=7).save(os.path.join(out, "mt_leaves_b.png"))
    flower().save(os.path.join(out, "mt_flower.png"))


if __name__ == "__main__":
    main(sys.argv[1])
