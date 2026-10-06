"""Paint the Thủy Vân village kit's textures (VILLAGE; style guide section 3.2, the brush recipe).

    python3 tools/thuyvan_art/village/paint_village.py [--only key,key] [--check-dir DIR]

Reads materials.json (one row per material key) and palettes.json (albedo.r1 ramps, a byte-for-byte copy of the art
director's look/palettes.json). Writes assets/thuyvan/village/textures/<key>.png (sRGB, opaque) and, per texture, a
<key>_check.png (the 3 x 3 tiling at 1/8 and the 1/16 squint) into --check-dir.

Every texture is painted on a torus (dabs wrap), in linear float, from its material's 4-stop ramp only (dark, mid,
light, accent): low-frequency variation at 1 and 1/2 of the tile, big flat dabs with firm painter's edges, medium
strokes painted three times (dark under, body, light sliver on top), a stroke height map whose cavities darken toward
a cool dark, up-facing edge light on wood and stone, a sparse accent pass, a 0.6 px blur and an unsharp mask, then the
material's value budget. Fixed seeds: the same inputs rebuild the same bytes.
"""

import argparse
import colorsys
import json
import math
import os
import sys
import zlib

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import marks  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(REPO, "assets", "thuyvan", "village", "textures")

COOL_ROCK = "#4a4e63"      # style guide 3.2 step 5: cavities shift toward these cool darks
COOL_GREEN = "#24492c"
COOL_WOOD = "#3a2a33"      # brown-violet


# ------------------------------------------------------------------------------------------------ colour
def hex_lin(h):
    h = h.lstrip("#")
    c = np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def srgb_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def luma(srgb):
    return srgb[..., 0] * 0.2126 + srgb[..., 1] * 0.7152 + srgb[..., 2] * 0.0722


# ------------------------------------------------------------------------------------------------ torus helpers
def blur(a, sigma):
    """Periodic gaussian blur (FFT), sigma in px; works on (h, w) or (h, w, c)."""
    if sigma <= 0:
        return a
    h, w = a.shape[:2]
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.rfftfreq(w)[None, :]
    k = np.exp(-2.0 * math.pi ** 2 * sigma ** 2 * (fx ** 2 + fy ** 2))
    if a.ndim == 3:
        return np.stack([np.fft.irfft2(np.fft.rfft2(a[..., i]) * k, s=(h, w)) for i in range(a.shape[2])], -1)
    return np.fft.irfft2(np.fft.rfft2(a) * k, s=(h, w))


def lowfreq(rng, h, w, kmax):
    """Tileable smooth noise in [-1, 1] made of integer-frequency waves up to kmax cycles per tile."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    f = np.zeros((h, w))
    for kx in range(-kmax, kmax + 1):
        for ky in range(0, kmax + 1):
            if (kx == 0 and ky == 0) or kx * kx + ky * ky > kmax * kmax:
                continue
            a = rng.normal() / math.hypot(kx, ky)
            f += a * np.cos(2 * math.pi * (kx * x / w + ky * y / h) + rng.uniform(0, 2 * math.pi))
    m = np.abs(f).max()
    return f / m if m > 0 else f


class Canvas:
    """A torus canvas: linear RGB, a stroke height map, a big-stroke mask. Sizes are in px; `ppm` = px per metre."""

    def __init__(self, w, h, ramp, seed, ppm_x, ppm_y=None):
        self.w, self.h = w, h
        self.ramp = [hex_lin(c) for c in ramp]
        self.rng = np.random.default_rng(seed)
        self.ppm_x = ppm_x
        self.ppm_y = ppm_y or ppm_x
        self.rgb = np.zeros((h, w, 3)) + self.ramp[1]
        self.hgt = np.zeros((h, w))
        self.big = np.zeros((h, w))

    def col(self, k, jitter=0.03):
        """Ramp stop k (0 dark, 1 mid, 2 light, 3 accent; fractional = blend), value-jittered."""
        k = float(np.clip(k, 0, 3))
        i = min(int(k), 2)
        t = k - i
        c = self.ramp[i] * (1 - t) + self.ramp[i + 1] * t
        return c * (1.0 + self.rng.uniform(-jitter, jitter))

    def pick(self, weights=(0.2, 0.45, 0.30, 0.05)):
        return self.col(self.rng.choice(4, p=np.asarray(weights) / sum(weights)))

    def dab(self, cx, cy, rx, ry, ang, color, alpha=1.0, hgt=0.0, big=0.0, edge=0.75, wobble=0.08, mode="over"):
        """A firm-edged elliptical stroke centred (cx, cy) px, radii rx (along ang) and ry px; wraps on the torus."""
        e = int(math.ceil(max(rx, ry))) + 2
        xs = np.arange(int(cx) - e, int(cx) + e + 1)
        ys = np.arange(int(cy) - e, int(cy) + e + 1)
        X, Y = np.meshgrid(xs - cx, ys - cy)
        ca, sa = math.cos(ang), math.sin(ang)
        u = (X * ca + Y * sa) / max(rx, 0.5)
        v = (-X * sa + Y * ca) / max(ry, 0.5)
        r = np.hypot(u, v)
        if wobble > 0:
            th = np.arctan2(v, u)
            p1, p2 = self.rng.uniform(0, 6.283, 2)
            r = r * (1.0 + wobble * (np.sin(3 * th + p1) * 0.6 + np.sin(5 * th + p2) * 0.4))
        a = np.clip((1.0 - r) / (1.0 - edge), 0.0, 1.0)
        a = a * a * (3 - 2 * a) * alpha
        if not a.any():
            return
        iy = (ys % self.h)[:, None]
        ix = (xs % self.w)[None, :]
        if mode == "over":
            self.rgb[iy, ix] = self.rgb[iy, ix] * (1 - a[..., None]) + np.asarray(color) * a[..., None]
        elif mode == "mul":
            self.rgb[iy, ix] = self.rgb[iy, ix] * (1 - a[..., None] * (1 - np.asarray(color)))
        if hgt:
            self.hgt[iy, ix] += hgt * a
        if big:
            self.big[iy, ix] = np.maximum(self.big[iy, ix], a * big)

    def stroke3(self, cx, cy, rx, ry, ang, body, alpha=1.0, up=(0.0, -1.0), hgt=0.5):
        """A medium stroke painted three times: dark below, the body, a light sliver above (`up` in px space)."""
        rr = max(rx, ry)
        ux, uy = up
        under = self.ramp[0] * 0.5 + body * 0.5
        over = self.ramp[2] * 0.6 + body * 0.4
        self.dab(cx - ux * 0.15 * rr, cy - uy * 0.15 * rr, rx * 1.04, ry * 1.08, ang, under, alpha * 0.45)
        self.dab(cx, cy, rx, ry, ang, body, alpha, hgt=hgt)
        self.dab(cx + ux * 0.2 * rr, cy + uy * 0.2 * rr, rx * 0.75, ry * 0.4, ang, over, alpha * 0.45)

    def kcol(self, lo=0.6, hi=2.0):
        """A continuous ramp pick between stops lo and hi (keeps neighbouring strokes close in value)."""
        return self.col(self.rng.uniform(lo, hi))

    # ---- the recipe's global passes
    def variation(self, value=0.08, hue_deg=5.0, sat=0.10):
        rng = self.rng
        nv = 0.65 * lowfreq(rng, self.h, self.w, 1) + 0.35 * lowfreq(rng, self.h, self.w, 2)
        nh = lowfreq(rng, self.h, self.w, 2)
        ns = lowfreq(rng, self.h, self.w, 2)
        c = self.rgb * (1.0 + value * nv)[..., None]
        # hue: rotate chroma in YIQ space; saturation: scale chroma
        r, g, b = c[..., 0], c[..., 1], c[..., 2]
        Y = 0.299 * r + 0.587 * g + 0.114 * b
        I = 0.596 * r - 0.274 * g - 0.322 * b
        Q = 0.211 * r - 0.523 * g + 0.312 * b
        th = np.radians(hue_deg) * nh
        s = 1.0 + sat * ns
        I2 = (I * np.cos(th) - Q * np.sin(th)) * s
        Q2 = (I * np.sin(th) + Q * np.cos(th)) * s
        self.rgb = np.stack([Y + 0.956 * I2 + 0.621 * Q2, Y - 0.272 * I2 - 0.647 * Q2, Y - 1.106 * I2 + 1.703 * Q2], -1)

    def cavity(self, strength=0.42, cool=COOL_ROCK, sigma_frac=1 / 24):
        hb = blur(self.hgt, self.w * sigma_frac)
        cav = np.clip(hb - self.hgt, 0.0, None)
        if cav.max() > 0:
            cav = cav / np.percentile(cav, 99.5)
        cav = np.clip(cav, 0.0, 1.0)
        dark = self.ramp[0] * 0.55 + hex_lin(cool) * 0.45
        a = (cav * strength)[..., None]
        self.rgb = self.rgb * (1 - a) + dark * a
        return cav

    def edge_light(self, amount=0.18):
        """Lighten where the stroke height rises toward the top of the texture (-V): the rims catch the light."""
        hb = blur(self.hgt, 1.2)
        g = hb - np.roll(hb, 2, axis=0)            # height here minus the pixel above: >0 where the surface faces up
        g = np.clip(-g, 0.0, None)
        if g.max() > 0:
            g = np.clip(g / np.percentile(g[g > 0], 95), 0.0, 1.0)
        a = (g * amount)[..., None]
        self.rgb = self.rgb * (1 - a) + self.ramp[2] * a

    def finish(self, value_target=None, contrast=None):
        c = blur(self.rgb, 0.6)
        c = c + 0.4 * (c - blur(c, self.w / 32.0))
        lo = np.minimum.reduce(self.ramp[:3]) * 0.92
        hi = np.maximum.reduce(self.ramp) * 1.04
        c = np.clip(c, lo, hi)
        s = lin_srgb(c)
        if value_target is not None:
            # the value budget, met halfway and never by more than +-0.07 (a saturated red cannot reach a grey's luma
            # without turning pink, so the ramp's own value wins there)
            m0 = luma(s).mean()
            tgt = m0 + float(np.clip((value_target - m0), -0.07, 0.07))
            for _ in range(4):
                m = luma(s).mean()
                s = np.clip(s * (tgt / max(m, 1e-4)), 0.01, 0.99)
        self.srgb = np.clip(s, 1 / 255.0, 254 / 255.0)
        return self.srgb


# ------------------------------------------------------------------------------------------------ painters
def generic_ground(cv, n_big, n_med, flow_ang, flow_jit, aspect, med_size=(0.02, 0.06), big_size=(0.06, 0.2),
                   weights=(0.2, 0.45, 0.30, 0.05), sliver_free=True):
    rng = cv.rng
    W = cv.w
    for _ in range(n_big):
        L = rng.uniform(*big_size) * W
        a = rng.uniform(*aspect)
        k = rng.choice(4, p=np.asarray(weights) / sum(weights))
        k = 0.55 + 0.5 * min(k, 2.6) + rng.uniform(-0.2, 0.2)         # big dabs stay near the mid of the ramp
        cv.dab(rng.uniform(0, W), rng.uniform(0, cv.h), L / 2, L / 2 / a, flow_ang + rng.normal(0, flow_jit),
               cv.col(k), 0.85, hgt=1.0, big=1.0, edge=0.7)
    for _ in range(n_med):
        L = rng.uniform(*med_size) * W * 1.6
        a = rng.uniform(*aspect) * 1.6 + 1.0
        if sliver_free:
            th = rng.uniform(0, 2 * math.pi)
            up = (math.cos(th) * 0.4, -abs(math.sin(th)) if rng.random() < 0.6 else abs(math.sin(th)))
        else:
            up = (0.0, -1.0)
        cv.stroke3(rng.uniform(0, W), rng.uniform(0, cv.h), L / 2, L / 2 / a, flow_ang + rng.normal(0, flow_jit),
                   cv.kcol(0.7, 2.2), 0.8, up=up)


def p_planks(cv, spec):
    """Boards along U (grain horizontal); `gaps`: dark gaps between boards with a lit top edge on each board."""
    rng = cv.rng
    W, H = cv.w, cv.h
    nb = max(1, int(round(spec["tile_m"] / spec["boards_m"])))
    bh = H / nb
    for b in range(nb):
        y0 = b * bh
        x = rng.uniform(0, W)
        while x < rng.uniform(0, W) + W:
            L = rng.uniform(1.0, 2.6) * cv.ppm_x
            base = cv.col(rng.choice([0.7, 1.0, 1.3, 1.7]), 0.05)
            # the board body as overlapping long flat dabs
            xs = (np.arange(int(x), int(x + L)) % W)
            ys = (np.arange(int(y0), int(y0 + bh + 1)) % H)
            cv.rgb[np.ix_(ys, xs)] = base
            cv.hgt[np.ix_(ys, xs)] += 1.0
            cv.big[np.ix_(ys, xs)] = 1.0
            # grain strokes along the board
            for _ in range(int(L / cv.ppm_x * 9)):
                gx = rng.uniform(x, x + L)
                gy = rng.uniform(y0 + bh * 0.12, y0 + bh * 0.88)
                cv.dab(gx, gy, rng.uniform(0.1, 0.35) * cv.ppm_x, rng.uniform(1.0, 2.2), rng.normal(0, 0.02),
                       cv.col(rng.choice([0.0, 0.5, 2.0, 2.4])), rng.uniform(0.35, 0.7), hgt=0.15, wobble=0.0)
            # a knot or two, nail heads at the board's end
            if rng.random() < 0.5:
                kx, ky = rng.uniform(x, x + L), rng.uniform(y0 + bh * 0.3, y0 + bh * 0.7)
                cv.dab(kx, ky, bh * 0.16, bh * 0.11, 0, cv.col(2.3), 0.9, wobble=0.1)
                cv.dab(kx, ky, bh * 0.10, bh * 0.07, 0, cv.col(0.0), 1.0, hgt=-0.4, wobble=0.1)
            if spec.get("gaps"):
                for ny in (0.28, 0.72):
                    cv.dab(x + L - bh * 0.25, y0 + bh * ny, 2.6, 2.6, 0, hex_lin("#2e2c2a"), 1.0, hgt=-0.3)
                # the butt joint
                cv.dab(x + L, y0 + bh / 2, 2.0, bh * 0.5, 0, cv.col(0) * 0.7, 1.0, hgt=-1.0, edge=0.6, wobble=0)
            x += L
        if spec.get("gaps"):
            # dark gap under the board above, light sliver on this board's top edge
            for xx in np.arange(0, W, bh * 0.8):
                cv.dab(xx, y0 + 1.5, bh * 0.6, 3.2, 0, cv.col(0) * 0.6, 1.0, hgt=-1.2, edge=0.7, wobble=0.04)
                cv.dab(xx + bh * 0.3, y0 + 6.0, bh * 0.55, 1.6, 0, cv.col(2.5), 0.7, wobble=0.04)
        else:
            for xx in np.arange(0, W, bh * 0.8):
                cv.dab(xx, y0 + 1.0, bh * 0.6, 1.6, 0, cv.col(0), 0.55, hgt=-0.5, edge=0.6, wobble=0.04)
    # long checks (cracks) on timber
    for _ in range(int(14 * W / 512)):
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.15, 0.5) * cv.ppm_x, 1.3, rng.normal(0, 0.015),
               cv.col(0) * 0.75, 0.9, hgt=-0.6, wobble=0)


def p_thatch(cv, spec):
    rng = cv.rng
    W, H = cv.w, cv.h
    course = 0.45 * cv.ppm_y
    nc = max(1, int(round(H / course)))
    course = H / nc
    for c in range(nc - 1, -2, -1):          # bottom course first; each higher course's fringe lies over the one below
        y0 = c * course
        # the course's straw: vertical bundles
        for _ in range(int(W / 3.2)):
            x = rng.uniform(0, W)
            L = rng.uniform(0.6, 1.1) * course
            cv.dab(x, y0 + course * 0.45, rng.uniform(3.0, 6.5), L / 2, math.pi / 2 + rng.normal(0, 0.12),
                   cv.col(rng.choice([0.4, 0.9, 1.4, 1.9, 2.4, 2.8])), 0.8, hgt=0.6, wobble=0.03)
            if rng.random() < 0.3:
                cv.dab(x + 2, y0 + course * 0.4, 1.4, L * 0.4, math.pi / 2, cv.col(0) * 0.8, 0.6, hgt=-0.3, wobble=0)
        # shadow cast on the course below, then the fringe hanging over it
        for x in np.arange(0, W, 10):
            cv.dab(x + rng.uniform(-3, 3), y0 + course + 6, 9, 7, 0, cv.col(0) * 0.8, 0.55, hgt=-0.6, wobble=0.1)
        for _ in range(int(W / 4)):
            x = rng.uniform(0, W)
            L = rng.uniform(0.15, 0.45) * course
            cv.dab(x, y0 + course * 0.85 + L * 0.3, rng.uniform(2.0, 3.6), L / 2, math.pi / 2 + rng.normal(0, 0.1),
                   cv.col(rng.choice([1.4, 2.0, 2.5, 2.9])), 0.9, hgt=0.8, big=0.5, wobble=0.02)


def p_shingle(cv, spec):
    rng = cv.rng
    W, H = cv.w, cv.h
    course = 0.25 * cv.ppm_y
    nc = max(1, int(round(H / course)))
    course = H / nc
    for c in range(nc - 1, -2, -1):
        y0 = c * course
        x = rng.uniform(0, W)
        x_end = x + W
        while x < x_end:
            sw = rng.uniform(0.14, 0.30) * cv.ppm_x
            base = cv.col(rng.choice([0.8, 1.1, 1.4, 1.8, 2.2]), 0.06)
            cv.dab(x + sw / 2, y0 + course * 0.55, sw * 0.52, course * 0.62, 0, base, 1.0, hgt=1.0, big=1.0,
                   edge=0.9, wobble=0.03)
            for _ in range(4):
                cv.dab(x + rng.uniform(0.1, 0.9) * sw, y0 + course * rng.uniform(0.3, 0.8), 1.3,
                       course * rng.uniform(0.2, 0.45), math.pi / 2, cv.col(rng.choice([0.2, 2.4])), 0.5, wobble=0)
            cv.dab(x + sw / 2, y0 + course * 1.08, sw * 0.48, 2.2, 0, cv.col(2.7), 0.85, wobble=0.05)   # lit butt
            cv.dab(x + sw / 2, y0 + course * 1.08 + 7, sw * 0.5, 5.5, 0, cv.col(0) * 0.7, 0.6, hgt=-0.8)  # its shadow
            cv.dab(x + sw, y0 + course * 0.6, 1.6, course * 0.55, 0, cv.col(0) * 0.6, 0.95, hgt=-0.8, wobble=0)
            x += sw


def p_tile(cv, spec):
    """Barrel roof tiles: covering tiles (raised, rounded) over channel tiles, courses with lit lips."""
    rng = cv.rng
    W, H = cv.w, cv.h
    col_w = 0.25 * cv.ppm_x
    ncol = max(2, int(round(W / col_w)) // 2 * 2)
    col_w = W / ncol
    course = 0.32 * cv.ppm_y
    nc = max(1, int(round(H / course)))
    course = H / nc
    # channel (pan) columns: darker, mossy
    for j in range(0, ncol, 2):
        x = (j + 0.5) * col_w
        for c in range(nc - 1, -2, -1):
            y0 = c * course
            cv.dab(x, y0 + course / 2, col_w * 0.55, course * 0.58, 0, cv.col(rng.uniform(0.3, 0.8)), 1.0, hgt=0.2,
                   edge=0.9, wobble=0.02)
            if rng.random() < 0.25:
                cv.dab(x + rng.uniform(-4, 4), y0 + course * 0.8, col_w * 0.25, 5, 0, hex_lin("#4f7a33"), 0.55)
    for j in range(1, ncol, 2):
        x = (j + 0.5) * col_w
        for c in range(nc - 1, -2, -1):
            y0 = c * course
            base = rng.uniform(1.0, 1.7)
            # the rounded cover tile: dark flanks, body, lit crown stripe
            cv.dab(x, y0 + course * 0.5, col_w * 0.62, course * 0.62, 0, cv.col(0.2), 1.0, hgt=0.6, edge=0.85)
            cv.dab(x, y0 + course * 0.5, col_w * 0.42, course * 0.6, 0, cv.col(base), 1.0, hgt=1.0, big=1.0, edge=0.85)
            cv.dab(x - col_w * 0.08, y0 + course * 0.5, col_w * 0.13, course * 0.5, 0, cv.col(base + 0.9), 0.8)
            # the lip (bottom end) and its shadow on the course below
            cv.dab(x, y0 + course * 1.04, col_w * 0.42, course * 0.13, 0, cv.col(2.6), 0.9, hgt=0.4)
            cv.dab(x, y0 + course * 1.04 + course * 0.16, col_w * 0.5, course * 0.1, 0, cv.col(0) * 0.7, 0.7, hgt=-0.6)
            if rng.random() < 0.12:
                cv.dab(x + rng.uniform(-6, 6), y0 + course * 0.95, 6, 4, 0, hex_lin("#7fa544"), 0.7)


def p_weave(cv, spec):
    """2/2 twill of split bamboo strips; each strip shaded round, dark where it dives under its neighbour."""
    W, H = cv.w, cv.h
    cell = 16 if W >= 512 else 8
    n = W // cell
    y, x = np.mgrid[0:H, 0:W]
    i, j = y // cell, x // cell
    fy, fx = (y % cell + 0.5) / cell, (x % cell + 0.5) / cell
    horiz_top = ((i + j) // 2 + 0) % 2 == 0
    rng = cv.rng
    # per-strip tone: horizontal strips by row, vertical by column
    th = cv.rng.uniform(1.0, 2.2, n)
    tv = cv.rng.uniform(0.8, 2.0, n)
    tone_h = th[i % n]
    tone_v = tv[j % n]
    tone = np.where(horiz_top, tone_h, tone_v)
    across = np.where(horiz_top, fy, fx)          # 0..1 across the strip on top
    along = np.where(horiz_top, fx, fy)
    # which end of the cell dives under: the strip on top continues into the next cell if that one is also on top
    roundness = np.sin(np.pi * across) ** 0.7
    stops = np.array(cv.ramp[:3] + [cv.ramp[2]])
    k = np.clip(tone - 0.9 + 0.9 * roundness, 0, 2.99)
    i0 = np.floor(k).astype(int)
    t = (k - i0)[..., None]
    rgb = stops[i0] * (1 - t) + stops[np.minimum(i0 + 1, 3)] * t
    # occlusion where the strip passes under (cell edges along the strip) and in the gaps between strips
    nxt = np.where(horiz_top, ((i + j + 1) // 2) % 2 == 0, ((i + j + 1) // 2) % 2 == 0)
    dive = np.where(horiz_top, np.where(nxt, 0.0, fx ** 6), fy ** 6)
    prev_top = ((i + j - 1) // 2) % 2 == 0
    dive += np.where(prev_top == horiz_top, 0.0, (1 - along) ** 6)
    ao = np.clip(1.0 - 0.55 * dive - 0.6 * (1 - roundness) ** 3, 0.3, 1.0)
    cv.rgb = rgb * ao[..., None]
    cv.hgt = roundness * (1 - 0.6 * dive)
    # painted weathering: big flat dabs at low alpha, a few dark stains low
    for _ in range(70):
        L = rng.uniform(0.06, 0.18) * W
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), L / 2, L / 3, rng.uniform(0, 3.14), cv.pick(), 0.18, big=1.0)


def p_plaster(cv, spec):
    rng = cv.rng
    W, H = cv.w, cv.h
    generic_ground(cv, 90, 260, 0.0, 0.6, (1.2, 2.5), med_size=(0.02, 0.05), weights=(0.05, 0.45, 0.45, 0.05))
    for _ in range(80):
        L = rng.uniform(0.1, 0.25) * W
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), L / 2, L / 3, rng.uniform(0, 3.14), cv.col(2.2), 0.25)
    for _ in range(10):  # hairline cracks: a few short jointed segments
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        a = rng.uniform(0, 6.28)
        for _ in range(rng.integers(2, 5)):
            L = rng.uniform(0.04, 0.12) * W
            cv.dab(x, y, L / 2, 1.2, a, cv.col(0) * 0.9, 0.7, hgt=-0.8, wobble=0)
            x += math.cos(a) * L / 2
            y += math.sin(a) * L / 2
            a += rng.normal(0, 0.6)


def p_lacquer(cv, spec):
    rng = cv.rng
    W, H = cv.w, cv.h
    generic_ground(cv, 60, 160, math.pi / 2, 0.05, (3, 6), med_size=(0.04, 0.1), weights=(0.2, 0.5, 0.3, 0.0),
                   sliver_free=False)
    for _ in range(60):   # the gloss painted in: long light vertical streaks
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.08, 0.2) * H, rng.uniform(1.5, 3.5), math.pi / 2,
               cv.col(2.4), rng.uniform(0.2, 0.4), wobble=0.02)
    for _ in range(25):   # worn to the dark wood
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(4, 14), rng.uniform(3, 8), rng.uniform(0, 3), cv.col(0) * 0.8,
               0.8, hgt=-0.5)


def p_rope(cv, spec):
    """Twisted strands: diagonal stripes, periodic along U (8 per tile) and around V (16 per tile; a rope's
    circumference maps to 1/4 tile so 4 twists ring it)."""
    W, H = cv.w, cv.h
    y, x = np.mgrid[0:H, 0:W]
    ph = (8 * x / W + 16 * y / H) % 1.0
    rnd = np.sin(np.pi * ph) ** 0.8
    stops = np.array(cv.ramp)
    k = np.clip(0.25 + 2.2 * rnd, 0, 2.99)
    i0 = np.floor(k).astype(int)
    t = (k - i0)[..., None]
    cv.rgb = stops[i0] * (1 - t) + stops[i0 + 1] * t
    cv.hgt = rnd
    rng = cv.rng
    for _ in range(500):   # fibres
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(6, 16), 1.2, math.atan2(-16 / H, 8 / W) + 1.5708 + rng.normal(0, 0.2),
               cv.col(rng.choice([0.2, 2.6])), 0.45, wobble=0)


def p_iron(cv, spec):
    generic_ground(cv, 60, 200, 0.0, 3.0, (1.0, 1.6), weights=(0.3, 0.45, 0.25, 0.0))


def p_bamboo(cv, spec):
    rng = cv.rng
    W, H = cv.w, cv.h
    # long fibres along U
    for _ in range(int(W * 0.6)):
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.1, 0.3) * W, rng.uniform(1.2, 3.0), rng.normal(0, 0.01),
               cv.col(rng.choice([0.6, 1.0, 1.5, 2.0, 2.6])), 0.6, hgt=0.3, wobble=0)
    # nodes: 3 per tile (every ~0.33 m), a dark groove with a light ridge beside it
    for k in range(3):
        xn = (k + 0.3) * W / 3 + rng.uniform(-6, 6)
        for yy in np.arange(0, H, 8):
            cv.dab(xn, yy, 3.5, 6, 0, cv.col(0) * 0.85, 0.95, hgt=-1.0, wobble=0.05)
            cv.dab(xn + 7, yy, 3.0, 6, 0, cv.col(3), 0.8, hgt=0.6, wobble=0.05)
    # lit stripe along the culm (v = 0.1 of the 1/4-tile circumference) repeated per circumference
    y = np.arange(H)
    band = np.exp(-(((y / H * 4) % 1.0 - 0.3) / 0.12) ** 2)
    cv.rgb = cv.rgb * (1 - 0.35 * band[:, None, None]) + cv.ramp[2] * 0.35 * band[:, None, None]


def p_drystone(cv, spec):
    """Dry-stone coursing: rows of rounded stones, wider than tall, dark joints, lit tops, moss on the top edges."""
    rng = cv.rng
    W, H = cv.w, cv.h
    cv.rgb[:] = cv.ramp[0] * 0.35 + cv.ramp[1] * 0.25 + hex_lin("#4a3a2e") * 0.2
    cv.hgt[:] = -1.0
    y = 0.0
    rows = []
    while y < H - 0.2 * cv.ppm_y:
        rh = rng.uniform(0.26, 0.42) * cv.ppm_y
        rows.append((y, rh))
        y += rh
    s = H / y
    moss = [hex_lin(c) for c in ("#2f4f2a", "#4f7a33", "#7fa544")]
    for (y0, rh) in rows:
        y0 *= s
        rh *= s
        x = rng.uniform(0, W)
        xe = x + W
        while x < xe:
            sw = rng.uniform(0.35, 0.75) * cv.ppm_x
            cx, cy = x + sw / 2, y0 + rh / 2 + rng.uniform(-3, 3)
            ang = rng.normal(0, 0.06)
            base = rng.uniform(0.9, 1.7)
            cv.dab(cx, cy, sw * 0.5, rh * 0.5, ang, cv.col(base - 0.6), 1.0, hgt=1.2, big=1.0, edge=0.55, wobble=0.12)
            cv.dab(cx, cy - rh * 0.06, sw * 0.44, rh * 0.4, ang, cv.col(base), 1.0, hgt=0.6, edge=0.6, wobble=0.12)
            cv.dab(cx - sw * 0.05, cy - rh * 0.25, sw * 0.32, rh * 0.13, ang, cv.col(base + 0.6), 0.6, edge=0.5)
            if rng.random() < 0.35:
                cv.dab(cx + rng.uniform(-0.2, 0.2) * sw, cy - rh * 0.4, sw * rng.uniform(0.15, 0.35), rh * 0.12, ang,
                       moss[rng.integers(0, 3)], 0.9)
            x += sw * rng.uniform(0.92, 1.02)


def p_limestone(cv, spec):
    rng = cv.rng
    W, H = cv.w, cv.h
    generic_ground(cv, 90, 220, 0.0, 0.12, (2.5, 5), weights=(0.15, 0.45, 0.35, 0.05), sliver_free=False)
    # strata: faint horizontal dark bands every 0.6-1.2 m with a lit lip above
    y = 0.0
    while y < H:
        y += rng.uniform(0.6, 1.2) * cv.ppm_y
        for xx in np.arange(0, W, 24):
            cv.dab(xx, y % H + rng.uniform(-2, 2), 22, 3.5, rng.normal(0, 0.05), cv.col(0), 0.55, hgt=-1.0)
            cv.dab(xx + 10, (y - 6) % H, 18, 2.0, 0, cv.col(2.6), 0.5)
    stain = [hex_lin(c) for c in ("#3a3d4a", "#5a5c64")]
    for _ in range(18):   # dark water streaks running down
        x = rng.uniform(0, W)
        cv.dab(x, rng.uniform(0, H), rng.uniform(3, 9), rng.uniform(0.05, 0.2) * H, math.pi / 2, stain[rng.integers(0, 2)],
               0.35, wobble=0.04)


def p_grass(cv, spec):
    rng = cv.rng
    W, H = cv.w, cv.h
    generic_ground(cv, 110, 0, 0.0, 3.0, (1.0, 2.0), weights=(0.3, 0.45, 0.25, 0.0))
    for _ in range(int(380 * (W / 1024) ** 2 * 4)):    # tufts: blades tilted +-25 deg from vertical
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        L = rng.uniform(0.06, 0.16) * cv.ppm_y
        for b in range(3):
            a = math.pi / 2 + rng.normal(0, 0.44)
            cv.dab(x + rng.uniform(-L * 0.3, L * 0.3), y - L * 0.4, L * 0.55, L * 0.12, a, cv.col(0), 0.6, hgt=0.3)
            cv.dab(x + rng.uniform(-L * 0.3, L * 0.3), y - L * 0.5, L * 0.5, L * 0.1, a, cv.col(rng.choice([1.3, 2.0, 2.6])),
                   0.85, hgt=0.5)
    fl = [hex_lin(c) for c in ("#c9583a", "#e2c04a", "#f2eedc", "#d97aa0")]
    for _ in range(int(60 * (W / 1024) ** 2 * 4)):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        c = fl[rng.integers(0, 4)]
        for _ in range(rng.integers(2, 6)):
            cv.dab(x + rng.normal(0, 6), y + rng.normal(0, 6), 2.6, 2.2, 0, c, 0.95)


def p_earth(cv, spec):
    rng = cv.rng
    W, H = cv.w, cv.h
    generic_ground(cv, 80, 160, 0.0, 3.0, (1.2, 2.2), weights=(0.25, 0.45, 0.25, 0.05))
    if spec["ramp"] == "dirt_path" and spec["px"] <= 256:
        return                                       # skin: no pebbles
    for _ in range(int(70 * (W / 512) ** 2)):     # pebbles: flat two-tone ovals
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(0.02, 0.06) * cv.ppm_x
        cv.dab(x, y + r * 0.25, r, r * 0.7, rng.uniform(0, 3), cv.col(0), 0.8, hgt=0.4)
        cv.dab(x, y, r * 0.9, r * 0.6, rng.uniform(0, 3), cv.col(rng.choice([2.0, 2.6])), 0.9, hgt=0.6)


def p_paper(cv, spec):
    rng = cv.rng
    W, H = cv.w, cv.h
    generic_ground(cv, 40, 120, math.pi / 2, 0.08, (2, 4), weights=(0.05, 0.4, 0.45, 0.1), sliver_free=False)
    for _ in range(30):
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(10, 30), rng.uniform(1, 2), rng.uniform(0, 3),
               cv.col(3), 0.5, wobble=0)


def p_cloth(cv, spec):
    """Homespun cloth: vertical folds (long soft dabs), a faint weave, wear to the light stop."""
    rng = cv.rng
    W, H = cv.w, cv.h
    for _ in range(int(60 * W / 512)):
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.15, 0.45) * H, rng.uniform(0.02, 0.06) * W,
               math.pi / 2 + rng.normal(0, 0.05), cv.kcol(0.6, 1.5), 0.6, hgt=0.6, big=1.0, edge=0.5, wobble=0.03)
    for _ in range(int(90 * W / 512)):          # fold shadows and lit ridges
        x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
        L = rng.uniform(0.1, 0.3) * H
        cv.dab(x0, y0, L, rng.uniform(2, 5) * W / 512, math.pi / 2 + rng.normal(0, 0.04), cv.col(0.3), 0.4, hgt=-0.4,
               edge=0.4, wobble=0.02)
        cv.dab(x0 + rng.uniform(3, 7) * W / 512, y0, L * 0.8, rng.uniform(1.5, 3) * W / 512, math.pi / 2, cv.col(2.1),
               0.35, edge=0.4, wobble=0.02)
    y, x = np.mgrid[0:H, 0:W]
    weave = (np.sin(x * 2 * math.pi / 4) * np.sin(y * 2 * math.pi / 4)) * 0.03
    cv.rgb = cv.rgb * (1 + weave[..., None])
    _ = rng


def cloth_mark(cv, name, cx, cy, size, color, rough=0.012):
    """Stamp a clan mark (dyed: slightly ragged edges) centred at (cx, cy) px, `size` px across."""
    W, H = cv.w, cv.h
    y, x = np.mgrid[0:H, 0:W]
    X = (x - cx) / (size / 2)
    Y = -(y - cy) / (size / 2)
    d = marks.sdf(name, X, Y)
    n = lowfreq(cv.rng, H, W, 12) * 0.025
    m = np.clip(0.5 - (d + n) / 0.03, 0.0, 1.0)
    cv.rgb = cv.rgb * (1 - m[..., None] * 0.92) + np.asarray(color) * m[..., None] * 0.92
    return m


def border_band(cv, y0, y1, color):
    """A woven border: a stepped zig-zag between two lines (Mountain Folk textile band, our own)."""
    W = cv.w
    y, x = np.mgrid[0:cv.h, 0:W]
    inb = (y >= y0) & (y < y1)
    hgt = y1 - y0
    t = (y - y0) / hgt
    lines = (t < 0.14) | (t > 0.86)
    period = hgt * 1.4
    tri = np.abs(((x / period) % 1.0) * 2 - 1)            # 0..1 triangle wave
    step = np.floor(tri * 4) / 4                          # stepped
    zig = np.abs(t - (0.25 + 0.5 * step)) < 0.11
    m = (inb & (lines | zig)).astype(float)
    m = blur(m, 0.6)
    cv.rgb = cv.rgb * (1 - m[..., None] * 0.85) + np.asarray(color) * m[..., None] * 0.85


def p_banner(cv, spec, pal):
    W, H = cv.w, cv.h
    p_cloth(cv, spec)
    bone = hex_lin(pal["bone_cloth"][2])
    madder = hex_lin(pal["madder_cloth"][1])
    # pole sleeve at the top (darker), a border band below it and above the hem
    cv.rgb[: int(H * 0.06)] *= 0.62
    border_band(cv, int(H * 0.085), int(H * 0.13), bone)
    border_band(cv, int(H * 0.80), int(H * 0.84), madder * 1.1)
    cloth_mark(cv, spec["mark"], W / 2, H * 0.40, W * 0.78, bone)
    # wear: darker along both edges and toward the hem
    x = np.arange(W)
    edge = np.exp(-np.minimum(x, W - 1 - x) / (W * 0.05))
    cv.rgb *= (1 - 0.25 * edge)[None, :, None]
    yy = np.arange(H) / H
    cv.rgb *= (1 - 0.22 * np.clip((yy - 0.85) / 0.15, 0, 1))[:, None, None]


def p_flags(spec, pal, seed):
    """Prayer-flag atlas: 5 cells (indigo, madder, ochre, bone, jade), each 2:3, faded, with a small block print."""
    cw, ch = spec["px"] // 5, spec["py"]
    out = np.zeros((ch, spec["px"], 3))
    prints = ["two_peaks", "pine_ring", "terrace_river", "crossed_staff", "stepped_gate"]
    for k, rn in enumerate(spec["ramps"]):
        cv = Canvas(cw, ch, pal[rn], seed + 31 * k, 128 / 0.30)
        p_cloth(cv, spec)
        ink = hex_lin(pal["bone_cloth"][2]) if rn != "bone_cloth" else hex_lin(pal["indigo_cloth"][1])
        cloth_mark(cv, prints[k], cw / 2, ch * 0.45, cw * 0.62, ink * 0.9 + cv.ramp[1] * 0.1)
        yy = np.arange(ch) / ch
        cv.rgb *= (1 - 0.3 * np.clip((yy - 0.8) / 0.2, 0, 1))[:, None, None]   # frayed, dirtier hem
        cv.rgb[: int(ch * 0.08)] *= 0.7                                          # folded over the cord
        out[:, k * cw:(k + 1) * cw] = cv.finish(None)
    return out


def p_waystone(cv, spec, pal):
    """The clan waystone's carved face: limestone strokes, the clan's mark cut in the top third, other clans' smaller
    marks below it, and tally notches down the left edge (marks and tallies only, never writing)."""
    rng = cv.rng
    W, H = cv.w, cv.h
    p_limestone(cv, spec)
    cv.cavity(0.4)
    y, x = np.mgrid[0:H, 0:W]

    def carve(name, cx, cy, size_x, size_y, depth=1.0):
        X = (x - cx) / (size_x / 2)
        Y = -(y - cy) / (size_y / 2)
        d = marks.sdf(name, X, Y)
        groove = np.clip(0.5 - d / 0.035, 0, 1)
        # the groove's floor is in shadow; light catches the lower lip (light from above), shadow under the upper lip
        d_up = marks.sdf(name, X, Y - 0.05)
        lip = np.clip(0.5 - d_up / 0.03, 0, 1) * (1 - groove)
        dark = cv.ramp[0] * 0.7 + hex_lin(COOL_ROCK) * 0.3
        cv.rgb = cv.rgb * (1 - groove[..., None] * 0.85 * depth) + dark * groove[..., None] * 0.85 * depth
        cv.rgb = cv.rgb * (1 - lip[..., None] * 0.55) + cv.ramp[3] * lip[..., None] * 0.55

    # the clan's mark: big, in the top third
    carve(spec["mark"], W * 0.52, H * 0.22, W * 0.74, W * 0.74)
    # a cut frame round it
    for (x0, y0, x1, y1) in ((0.14, 0.07, 0.90, 0.07), (0.14, 0.38, 0.90, 0.38)):
        m = (np.abs(y - H * y0) < 3.5) & (x > W * x0) & (x < W * x1)
        cv.rgb[m] = cv.rgb[m] * 0.45 + cv.ramp[0] * 0.55
    # neighbour clans' marks, smaller, in two rows (each clan's version of the old federation)
    for k, (nm, cx, cy) in enumerate((("crossed_staff", 0.36, 0.47), ("stepped_gate", 0.66, 0.47),
                                      ("pine_ring", 0.36, 0.60), ("terrace_river", 0.66, 0.60))):
        carve(nm, W * cx, H * cy, W * 0.2, W * 0.2, 0.85)
    # tally notches down the left edge: groups of four and a slash
    ty = H * 0.42
    while ty < H * 0.86:
        for k in range(4):
            yy = ty + k * 12
            m = (np.abs(y - yy) < 2.6) & (x > W * 0.05) & (x < W * 0.15)
            cv.rgb[m] = cv.rgb[m] * 0.4 + cv.ramp[0] * 0.6
            m2 = (np.abs(y - yy - 4) < 1.2) & (x > W * 0.05) & (x < W * 0.15)
            cv.rgb[m2] = cv.rgb[m2] * 0.5 + cv.ramp[3] * 0.5
        X0, Y0 = W * 0.04, ty - 6
        d = np.abs((x - X0) * 44 - (y - Y0) * (W * 0.12)) / math.hypot(44, W * 0.12)
        m = (d < 2.4) & (y > Y0) & (y < Y0 + 44) & (x > W * 0.03) & (x < W * 0.17)
        cv.rgb[m] = cv.rgb[m] * 0.4 + cv.ramp[0] * 0.6
        ty += 72 + rng.uniform(0, 20)
    # moss and lichen creeping up from the foot, rag stains under the flag ropes
    moss = [hex_lin(c) for c in ("#2f4f2a", "#4f7a33", "#7fa544")]
    for _ in range(140):
        yy = H - abs(rng.normal(0, H * 0.08))
        cv.dab(rng.uniform(0, W), yy, rng.uniform(5, 16), rng.uniform(3, 9), rng.uniform(0, 3), moss[rng.integers(0, 3)], 0.85)
    for _ in range(30):
        cv.dab(rng.uniform(0, W), rng.uniform(0, H * 0.9), rng.uniform(4, 10), rng.uniform(3, 6), 0,
               hex_lin("#b4c766"), 0.5)


PAINTERS = {"planks": p_planks, "thatch": p_thatch, "shingle": p_shingle, "tile": p_tile, "weave": p_weave,
            "plaster": p_plaster, "lacquer": p_lacquer, "rope": p_rope, "iron": p_iron, "bamboo": p_bamboo,
            "drystone": p_drystone, "limestone": p_limestone, "grass": p_grass, "earth": p_earth, "paper": p_paper,
            "cloth": p_cloth}
CAVITY = {"planks": (0.45, COOL_WOOD), "thatch": (0.45, COOL_WOOD), "shingle": (0.45, COOL_WOOD),
          "tile": (0.4, COOL_ROCK), "weave": (0.25, COOL_WOOD), "plaster": (0.3, COOL_ROCK),
          "lacquer": (0.3, COOL_WOOD), "rope": (0.35, COOL_WOOD), "iron": (0.35, COOL_ROCK),
          "bamboo": (0.35, COOL_GREEN), "drystone": (0.5, COOL_ROCK), "limestone": (0.42, COOL_ROCK),
          "grass": (0.4, COOL_GREEN), "earth": (0.38, COOL_WOOD), "paper": (0.2, COOL_WOOD),
          "cloth": (0.3, COOL_ROCK)}
EDGE_LIGHT = {"planks", "shingle", "tile", "drystone", "limestone", "bamboo", "lacquer"}


def seed_of(key):
    return zlib.crc32(("thuyvan-village-" + key).encode()) & 0x7FFFFFFF


def paint(key, spec, pal):
    seed = seed_of(key)
    painter = spec["painter"]
    if painter == "flags":
        return p_flags(spec, pal, seed)
    w = spec["px"]
    h = spec.get("py", w)
    if spec.get("unit_uv"):
        ppm = w / 1.2
    else:
        ppm = w / spec["tile_m"]
    cv = Canvas(w, h, pal[spec["ramp"]], seed, ppm, ppm if not spec.get("unit_uv") else h / 4.2)
    if painter == "banner":
        p_banner(cv, spec, pal)
        cv.variation(0.06, 3, 0.06)
        return cv.finish(spec.get("value"))
    if painter == "waystone":
        p_waystone(cv, spec, pal)
        return cv.finish(spec.get("value"))
    cv.variation()
    PAINTERS[painter](cv, spec)
    st, cool = CAVITY[painter]
    cv.cavity(st, cool)
    if painter in EDGE_LIGHT:
        cv.edge_light(0.17)
    return cv.finish(spec.get("value"))


def check_image(srgb, path):
    """The squint (1/16 down, back up) beside the 3 x 3 tiling at 1/8 size."""
    im = Image.fromarray((srgb * 255 + 0.5).astype(np.uint8))
    w, h = im.size
    sq = im.resize((max(1, w // 16), max(1, h // 16)), Image.BOX).resize((w // 2, h // 2), Image.BICUBIC)
    t = im.resize((max(1, w // 4), max(1, h // 4)), Image.LANCZOS)
    tw, th = t.size
    tiled = Image.new("RGB", (tw * 3, th * 3))
    for i in range(3):
        for j in range(3):
            tiled.paste(t, (i * tw, j * th))
    out = Image.new("RGB", (tiled.width + sq.width + 12, max(tiled.height, sq.height)), (236, 232, 222))
    out.paste(tiled, (0, 0))
    out.paste(sq, (tiled.width + 12, 0))
    out.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--check-dir", default="")
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    mats = json.load(open(os.path.join(HERE, "materials.json")))
    pal = json.load(open(os.path.join(HERE, "palettes.json")))["albedo"][mats["palette_zone"]]
    os.makedirs(a.out, exist_ok=True)
    only = set(filter(None, a.only.split(",")))
    report = {}
    for key, spec in mats["keys"].items():
        if only and key not in only:
            continue
        srgb = paint(key, spec, pal)
        img = Image.fromarray((srgb * 255 + 0.5).astype(np.uint8))
        p = os.path.join(a.out, key + ".png")
        img.save(p, optimize=True)
        mean = float(luma(srgb).mean())
        report[key] = {"mean": round(mean, 3), "min": round(float(luma(srgb).min()), 3),
                       "max": round(float(luma(srgb).max()), 3), "size": list(img.size)}
        if a.check_dir:
            os.makedirs(a.check_dir, exist_ok=True)
            check_image(srgb, os.path.join(a.check_dir, key + "_check.png"))
        print("PAINT %-14s %s mean %.3f range %.2f-%.2f" % (key, img.size, mean, report[key]["min"], report[key]["max"]))
    if a.check_dir:
        with open(os.path.join(a.check_dir, "paint_report.json"), "w") as f:
            json.dump(report, f, indent=1)


if __name__ == "__main__":
    main()
