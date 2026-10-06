"""Thủy Vân ROCK kit: the painted textures (numpy + PIL only; deterministic, fixed seeds).

    python3 tools/thuyvan_art/rock/rock_paint.py [--out assets/thuyvan/rock/textures] [--check-dir DIR] [--only NAME]

Follows the style guide's brush recipe (style_guide.md 3.2): every texture is painted on a torus (it tiles), from ONE
4-stop ramp per material read from tools/thuyvan_art/palettes.json (dark, mid, light, accent; nobody retypes hex
values), with low-frequency variation at 1 and 1/2 of the tile, big flat dabs with firm painter's edges, medium strokes
painted three times (dark copy below, body, light sliver on top), a stroke height map whose cavities darken toward a
cool dark (the painted AO), lit top edges on rock, a sparse accent pass, a 0.6 px blur + unsharp mask, a clamp to the
ramp and a per-material value budget. Every texture writes <name>_check.png (3 x 3 tiling at 1/8 + the 1/16 squint).

Writes (sRGB PNG):
    karst_face.png        2048^2, 16 m tile: karst limestone faces: strata 0.6-1.2 m in blocks, vertical fluting,
                          dark water streaks, moss on top edges. (Triplanar on towers, cliff walls, heads, boulders.)
    karst_face_height.png 2048^2 grey: the stroke height (for an optional soft normal, strength 0.2-0.35)
    karst_pale.png        2048^2, 16 m tile: the same recipe on the white-stone ramp (the bridge needle)
    white_stone.png       1024^2, 4 m tile: Đá Trắng's smooth pale river stones; almost no strokes
    ashlar.png            2048^2, 8 m tile: the Two Heights' dressed white limestone, blocks 1.2-2 m, courses
                          0.6-0.9 m (Thạch Uyên's worked-block ramp: the Stone Children built it)
    moss_cap.png          1024^2, 4 m tile: moss and fern ground for ledges, crowns and boulder caps
    lineup_grass.png      1024^2, 8 m tile: the lineup's painted ground (PAINT's grass slice replaces it in the vista)
    mist_card.png         1024 x 256 RGBA: a soft mist band card for the internal diorama only (PAINT's P10 replaces it)
    rock_textures.json    per texture: tile metres, size, mean value, budget, the squint/stroke check numbers
"""

import argparse
import colorsys
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PALETTES = os.path.join(HERE, "..", "palettes.json")


# ------------------------------------------------------------------------------------------------ colour
def hex_srgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def to_lin(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def ramp(pal, key, zone="r1"):
    """[dark, mid, light, accent] as linear RGB rows."""
    return np.array([to_lin(hex_srgb(h)) for h in pal["albedo"][zone][key]])


def lum(srgb):
    return 0.2126 * srgb[..., 0] + 0.7152 * srgb[..., 1] + 0.0722 * srgb[..., 2]


def rgb_to_hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-9
    rc = np.where(m, (mx - r) / np.where(m, d, 1), 0)
    gc = np.where(m, (mx - g) / np.where(m, d, 1), 0)
    bc = np.where(m, (mx - b) / np.where(m, d, 1), 0)
    h = np.where(r == mx, bc - gc, np.where(g == mx, 2.0 + rc - bc, 4.0 + gc - rc))
    h = np.where(m, (h / 6.0) % 1.0, 0.0)
    s = np.where(mx > 1e-9, d / np.where(mx > 1e-9, mx, 1), 0)
    return np.stack([h, s, mx], -1)


def hsv_to_rgb(a):
    h, s, v = a[..., 0], a[..., 1], a[..., 2]
    i = np.floor(h * 6.0).astype(int) % 6
    f = h * 6.0 - np.floor(h * 6.0)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], -1)


# ------------------------------------------------------------------------------------------------ torus tools
def blur(img, sigma):
    """Gaussian blur on the torus (FFT), so tiling survives. img (H, W) or (H, W, C)."""
    if sigma <= 0:
        return img
    H, W = img.shape[:2]
    fy = np.fft.fftfreq(H)[:, None]
    fx = np.fft.rfftfreq(W)[None, :]
    g = np.exp(-2.0 * (math.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    if img.ndim == 2:
        return np.fft.irfft2(np.fft.rfft2(img) * g, s=(H, W))
    return np.stack([np.fft.irfft2(np.fft.rfft2(img[..., c]) * g, s=(H, W)) for c in range(img.shape[2])], -1)


def lf_noise(n, kmin, kmax, rng, aniso=(1.0, 1.0)):
    """Tileable low-frequency noise from integer Fourier modes kmin..kmax cycles per tile, normalised to [-1, 1]."""
    t = np.arange(n) / n
    f = np.zeros((n, n))
    K = int(math.ceil(kmax))
    for kx in range(-K, K + 1):
        for ky in range(0, K + 1):
            k = math.hypot(kx * aniso[0], ky * aniso[1])
            if k < kmin or k > kmax or (kx == 0 and ky == 0):
                continue
            a, ph = rng.normal() / (1 + k), rng.uniform(0, 2 * math.pi)
            ax = 2 * math.pi * kx * t + ph
            by = 2 * math.pi * ky * t
            f += a * (np.cos(by)[:, None] * np.cos(ax)[None, :] - np.sin(by)[:, None] * np.sin(ax)[None, :])
    return f / max(np.abs(f).max(), 1e-9)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


class Canvas:
    """A linear-RGB painting on a torus with a stroke height map."""

    def __init__(self, n, base, seed):
        self.n = n
        self.rgb = np.ones((n, n, 3)) * base
        self.h = np.zeros((n, n))
        self.big = np.zeros((n, n))           # big-stroke mask (terrain alpha uses it; kept for parity)
        self.rng = np.random.default_rng(seed)

    def dab(self, cx, cy, rx, ry, ang, col, alpha=1.0, height=0.0, wobble=0.12, taper=0.0, soft=0.25, big=False,
            mode="over"):
        """An elliptical dab with a firm edge (alpha = smoothstep(1, 1-soft, r)), wrapped round the torus.
        `taper` > 0 narrows it toward +u (a brush lifting off); `wobble` roughens the outline."""
        n = self.n
        R = int(math.ceil(max(rx, ry) * (1 + wobble) + 2))
        if R > n // 2:
            R = n // 2
        xs = np.arange(-R, R + 1)
        X, Y = np.meshgrid(xs - (cx - math.floor(cx)), xs - (cy - math.floor(cy)))
        ca, sa = math.cos(ang), math.sin(ang)
        u = (X * ca + Y * sa) / rx
        v = (-X * sa + Y * ca) / ry
        if taper:
            v = v / np.clip(1.0 - taper * (u + 1) * 0.5, 0.15, 1.0)
        th = np.arctan2(v, u)
        ph = self.rng.uniform(0, 2 * math.pi, 3)
        r = np.sqrt(u * u + v * v) / (1 + wobble * (0.5 * np.sin(3 * th + ph[0]) + 0.3 * np.sin(5 * th + ph[1])
                                                      + 0.2 * np.sin(7 * th + ph[2])))
        a = alpha * smoothstep(1.0, 1.0 - soft, r)
        iy = (int(math.floor(cy)) + xs) % n
        ix = (int(math.floor(cx)) + xs) % n
        sl = np.ix_(iy, ix)
        if mode == "over":
            self.rgb[sl] = self.rgb[sl] * (1 - a[..., None]) + np.asarray(col) * a[..., None]
        elif mode == "mul":
            self.rgb[sl] = self.rgb[sl] * (1 - a[..., None] * (1 - np.asarray(col)))
        if height:
            self.h[sl] += a * height
        if big:
            self.big[sl] = np.maximum(self.big[sl], a)
        return a

    def pick(self, R, weights=(0.20, 0.45, 0.30, 0.05), jitter=0.03):
        i = self.rng.choice(4, p=np.asarray(weights) / sum(weights))
        return R[i] * (1 + self.rng.uniform(-jitter, jitter))

    def stroke3(self, cx, cy, rx, ry, ang, R, body, up=(0.0, -1.0), alpha=1.0, height=0.5, dark_a=0.8):
        """A medium stroke painted three times: dark copy offset 'down' 15% of its radius, the body, a light sliver
        offset 'up' 20%. `up` is the texture direction of the light (-V on walls)."""
        ux, uy = up
        self.dab(cx - ux * 0.15 * ry, cy - uy * 0.15 * ry, rx, ry, ang, R[0], alpha * dark_a, 0.0)
        self.dab(cx, cy, rx, ry, ang, body, alpha, height)
        self.dab(cx + ux * 0.20 * ry, cy + uy * 0.20 * ry, rx * 0.8, ry * 0.35, ang, R[2], alpha * 0.9, 0.0)

    # ---- recipe steps 5, 6, 8, 9, 10
    def cavity_ao(self, dark_cool, amount=0.42, sigma_frac=1 / 24):
        cav = np.clip(blur(self.h, self.n * sigma_frac / 2.5) - self.h, 0.0, None)
        cav = cav / max(np.percentile(cav, 99.5), 1e-6)
        cav = np.clip(cav, 0, 1)[..., None] * amount
        self.rgb = self.rgb * (1 - cav) + np.asarray(dark_cool) * cav
        return cav

    def edge_light(self, light, amount=0.18, width_px=3.0):
        hb = blur(self.h, width_px)
        gy = (np.roll(hb, -1, 0) - np.roll(hb, 1, 0)) * 0.5      # +: height rises going down = a top edge
        e = np.clip(gy / max(np.percentile(np.abs(gy), 99), 1e-6), 0, 1)[..., None] * amount
        self.rgb = self.rgb * (1 - e) + np.asarray(light) * e
        return e[..., 0]

    def lf_variation(self, seed, val=0.08, hue_deg=5.0, sat=0.10):
        rng = np.random.default_rng(seed)
        n = self.n
        nv = 0.65 * lf_noise(n, 1, 1.5, rng) + 0.35 * lf_noise(n, 2, 2.9, rng)
        nh = 0.65 * lf_noise(n, 1, 1.5, rng) + 0.35 * lf_noise(n, 2, 2.9, rng)
        ns = 0.65 * lf_noise(n, 1, 1.5, rng) + 0.35 * lf_noise(n, 2, 2.9, rng)
        hsv = rgb_to_hsv(to_srgb(self.rgb))
        hsv[..., 0] = (hsv[..., 0] + nh * hue_deg / 360.0) % 1.0
        hsv[..., 1] = np.clip(hsv[..., 1] * (1 + sat * ns), 0, 1)
        hsv[..., 2] = np.clip(hsv[..., 2] * (1 + val * nv), 0, 1)
        self.rgb = to_lin(hsv_to_rgb(hsv))

    def finish(self, R, budget, lo=None, hi=None, allow_hi=False):
        n = self.n
        img = blur(self.rgb, 0.6)
        img = img + 0.4 * (img - blur(img, n / 32 / 2.5))
        lo = R[:3].min(0) if lo is None else lo
        hi = R[:3].max(0) if hi is None else hi
        img = np.clip(img, lo, hi)
        # value budget: scale (in linear) toward the target sRGB mean, then re-clamp to the ramp span
        for _ in range(8):
            m = lum(to_srgb(img)).mean()
            if abs(m - budget) < 0.004:
                break
            img = np.clip(img * (to_lin(budget) / to_lin(m)), lo, hi)
        s = to_srgb(img)
        if not allow_hi:
            s = np.clip(s, 0.0, 0.85 + 1e-3) if budget < 0.8 else s
        self.out = np.clip(s, 1 / 255, 254 / 255)
        return self.out


# ------------------------------------------------------------------------------------------------ checks
def check_image(srgb, name, path):
    """<name>_check.png: the 3 x 3 tiling at 1/8 size beside the 1/16 squint; returns the check numbers."""
    n = srgb.shape[0]
    im = Image.fromarray((srgb * 255).astype(np.uint8))
    s8 = max(n // 8, 64)
    small = im.resize((s8, int(s8 * srgb.shape[0] / srgb.shape[1])), Image.LANCZOS)
    tile = Image.new("RGB", (small.width * 3, small.height * 3))
    for i in range(3):
        for j in range(3):
            tile.paste(small, (i * small.width, j * small.height))
    sq = im.resize((max(n // 16, 8), max(srgb.shape[0] // 16, 8)), Image.BOX).resize((tile.height, tile.height),
                                                                                       Image.BICUBIC)
    W = tile.width + sq.width + 30
    out = Image.new("RGB", (W, tile.height + 40), (236, 230, 216))
    out.paste(tile, (10, 30))
    out.paste(sq, (tile.width + 20, 30))
    L = lum(srgb)
    stroke = blur(L, n / 32 / 2.5)
    worst = float(np.abs(stroke - L.mean()).max())
    blobs = blur(L, n / 16 / 2.5)
    d = ImageDraw.Draw(out)
    d.text((10, 8), "%s  mean %.3f  contrast %.2f-%.2f  worst stroke vs mean %.3f (<= 0.25)  |  squint 1/16" % (
        name, L.mean(), np.percentile(L, 2), np.percentile(L, 98), worst), fill=(30, 30, 30))
    out.save(path)
    return {"mean": round(float(L.mean()), 4), "p02": round(float(np.percentile(L, 2)), 3),
            "p98": round(float(np.percentile(L, 98)), 3), "worst_stroke_dev": round(worst, 3),
            "squint_range": round(float(blobs.max() - blobs.min()), 3), "pass_stroke": worst <= 0.25}


# ------------------------------------------------------------------------------------------------ materials
def paint_karst(pal, n=2048, seed=1601, R=None, stain=None, moss=None, budget=0.62, name="karst_face"):
    """Karst limestone faces, 16 m tile (128 px/m at 2048): strata 0.6-1.2 m broken into blocks, vertical fluting,
    water streaks under the ledges, moss on the top edges."""
    R = ramp(pal, "karst_limestone") if R is None else R
    stain = ramp(pal, "cliff_stain") if stain is None else stain
    moss = ramp(pal, "moss") if moss is None else moss
    c = Canvas(n, R[1], seed)
    rng = c.rng
    ppm = n / 16.0
    yy, xx = np.mgrid[0:n, 0:n]
    # strata: band heights 0.6-1.2 m (the guide) with every few a thick bed up to 1.8 m; boundaries waver
    hs = []
    while sum(hs) < 16.0 - 0.6:
        hs.append(rng.uniform(0.6, 1.2) if rng.random() < 0.75 else rng.uniform(1.3, 1.8))
    hs = np.array(hs) * (16.0 / sum(hs))
    tops = np.concatenate([[0], np.cumsum(hs)[:-1]]) * ppm
    xs = np.arange(n) / n
    wav = []
    for _ in tops:
        w = np.zeros(n)
        for k in (1, 2, 3, 5):
            w += rng.normal() * 0.15 * ppm / k * np.sin(2 * math.pi * k * xs + rng.uniform(0, 6.283))
        wav.append(w)
    yb = tops[:, None] + np.array(wav)             # (nb, n) top boundary per band, per column
    nb = len(hs)
    Ye = np.where(yy < yb[0][None, :], yy + n, yy).astype(float)     # rows above band 0's top belong to the last
    band = np.zeros((n, n), int)
    for b in range(1, nb):
        band += (Ye >= yb[b][None, :]).astype(int)
    top = yb[band, xx]
    bot = np.where(band + 1 < nb, yb[np.minimum(band + 1, nb - 1), xx], yb[0, xx] + n)
    dy_top = Ye - top
    dy_bot = bot - Ye
    # blocks: slanted joints (+-20 deg) every 1.5-6 m; a third of them only crack part of the bed. Each block one flat
    # ramp colour (weighted to the warm light stones) and a pillow height
    blockcol = np.zeros((n, n, 3))
    blockh = np.zeros((n, n))
    dx = np.full((n, n), 1e9)
    for b in range(nb):
        m = band == b
        js = []
        x = rng.uniform(0, n)
        while len(js) == 0 or (x - js[0]) < n - 1.5 * ppm:
            js.append(x)
            x += rng.uniform(1.5, 6.0) * ppm
        js = np.array(js) % n
        sl = np.tan(np.radians(rng.uniform(-20, 20, len(js))))
        part = np.where(rng.random(len(js)) < 0.33, rng.uniform(0.3, 0.7, len(js)), 1.01)
        X = xx[m].astype(float)
        T = dy_top[m]
        Hb = (dy_top[m] + dy_bot[m])
        jx = (js[None, :] + sl[None, :] * T[:, None]) % n             # each joint's x on this pixel's row
        d = np.abs(X[:, None] - jx)
        d = np.minimum(d, n - d)
        d = np.where(T[:, None] <= part[None, :] * Hb[:, None], d, 1e9)
        dx[m] = d.min(1)
        full = part >= 1.0
        idx = ((X[:, None] - jx[:, full]) % n).argmin(1) if full.any() else np.zeros(len(X), int)
        k = max(int(full.sum()), 1)
        cols = np.array([c.pick(R, (0.10, 0.42, 0.40, 0.08), 0.04) for _ in range(k)])
        hts = rng.uniform(0.6, 1.0, k)
        blockcol[m] = cols[idx]
        blockh[m] = hts[idx]
    edge = np.minimum(np.minimum(dy_top * 0.8, dy_bot * 1.6), dx * 1.4)
    pillow = smoothstep(0.0, 0.16 * ppm, edge)
    c.rgb = c.rgb * 0.62 + blockcol * 0.38
    c.h += blockh * pillow
    # big strokes along the strata (60-120): flat, firm edged, horizontal +-12 deg; warm light slabs lead
    for _ in range(rng.integers(90, 120)):
        L = rng.uniform(0.06, 0.20) * n
        asp = rng.uniform(2.0, 4.0)
        c.dab(rng.uniform(0, n), rng.uniform(0, n), L / 2, L / 2 / asp, math.radians(rng.uniform(-12, 12)),
              c.pick(R, (0.15, 0.40, 0.37, 0.08)), alpha=rng.uniform(0.3, 0.55), height=0.25, big=True)
    # vertical fluting: broad soft dark/light pairs (the slab grooves), every 1.5-4 m
    x = rng.uniform(0, n)
    x0 = x
    while x < x0 + n - 1.2 * ppm:
        L = rng.uniform(0.15, 0.45) * n
        y0 = rng.uniform(0, n)
        c.dab(x, y0, L / 2, rng.uniform(0.10, 0.18) * ppm, math.radians(90 + rng.uniform(-3, 3)), R[0], 0.26, -0.4,
              taper=0.5)
        c.dab(x + 0.22 * ppm, y0, L / 2 * 0.9, rng.uniform(0.08, 0.14) * ppm, math.radians(90 + rng.uniform(-3, 3)),
              R[2], 0.26, 0.2, taper=0.5)
        x += rng.uniform(2.5, 6.0) * ppm
    # medium strokes with painted light (150-400): long, along the strata, light from -V (up)
    for _ in range(rng.integers(170, 230)):
        L = rng.uniform(0.03, 0.07) * n
        c.stroke3(rng.uniform(0, n), rng.uniform(0, n), L / 2, L / 2 / rng.uniform(3.0, 6.0),
                  math.radians(rng.uniform(-8, 8)), R, c.pick(R, (0, 0.55, 0.45, 0)), up=(0, -1),
                  alpha=rng.uniform(0.3, 0.5), height=0.35, dark_a=0.45)
    # water streaks: dark tapered streaks hanging under band edges (the seeps), 20-40
    for _ in range(rng.integers(22, 38)):
        L = rng.uniform(0.12, 0.45) * n
        b = rng.integers(0, nb)
        x = rng.uniform(0, n)
        y = yb[b, int(x) % n] + L / 2
        c.dab(x, y, L / 2, rng.uniform(0.008, 0.02) * n, math.radians(90 + rng.uniform(-4, 4)),
              stain[rng.integers(0, 2)], alpha=rng.uniform(0.15, 0.32), height=0.0, taper=0.85, wobble=0.05)
    # cavity AO toward the cool shade, then lit top edges
    c.cavity_ao(R[0] * 0.9, amount=0.45)
    e = c.edge_light(R[2] * 1.05, amount=0.22, width_px=3.0)
    # accent: moss lines on a few top edges (sparse; where the edge light is strongest and a LF field allows)
    mz = lf_noise(n, 1, 3, rng)
    mm = (e > 0.12) & (mz > 0.35) & (rng.random((n, n)) < 0.006)
    ys, xs_ = np.nonzero(mm)
    for k in (rng.choice(len(ys), size=min(len(ys), 140), replace=False) if len(ys) else []):
        L = rng.uniform(0.012, 0.03) * n
        c.dab(xs_[k], ys[k] - L * 0.08, L, L * 0.16, rng.uniform(-0.1, 0.1), moss[rng.integers(0, 3)],
              alpha=0.85, height=0.1)
    c.lf_variation(seed + 7)
    out = c.finish(R, budget)
    return out, c.h


def paint_white_stone(pal, n=1024, seed=1702, budget=0.82):
    """Smooth pale river stone, 4 m tile: soft broad dabs, almost no strokes, cool-grey cavity."""
    R = ramp(pal, "white_stone")
    c = Canvas(n, R[2], seed)
    rng = c.rng
    for _ in range(rng.integers(90, 120)):
        L = rng.uniform(0.08, 0.22) * n
        c.dab(rng.uniform(0, n), rng.uniform(0, n), L / 2, L / 2 / rng.uniform(1.2, 2.2), rng.uniform(0, 3.14),
              c.pick(R, (0.03, 0.30, 0.47, 0.20), 0.02), alpha=rng.uniform(0.35, 0.6), height=0.6, soft=0.6, big=True)
    for _ in range(rng.integers(150, 180)):
        L = rng.uniform(0.06, 0.12) * n
        ang = rng.uniform(0, 3.14)
        up = (math.cos(ang + 1.57), math.sin(ang + 1.57)) if rng.random() < 0.4 else (0, -1)
        c.stroke3(rng.uniform(0, n), rng.uniform(0, n), L / 2, L / 2 / rng.uniform(1.2, 2.0), ang,
                  np.array([R[1] * 0.97, R[1], R[3]]), c.pick(R, (0, 0.3, 0.5, 0.2), 0.02), up=up,
                  alpha=rng.uniform(0.15, 0.3), height=0.3)
    c.cavity_ao(to_lin(np.array([0.50, 0.55, 0.60])), amount=0.30)
    c.lf_variation(seed + 7, val=0.05, hue_deg=4, sat=0.08)
    out = c.finish(R, budget, allow_hi=True)
    return out, c.h


def paint_ashlar(pal, n=2048, seed=1803, budget=0.68):
    """Dressed white limestone, 8 m tile (256 px/m): courses 0.6-0.9 m, blocks 1.2-2 m, sunk joints, lit top
    arrises, chisel strokes, rain stains under the joints, moss in a few top joints."""
    R = ramp(pal, "worked_block", "thach_uyen")
    stain = ramp(pal, "cliff_stain")
    moss = ramp(pal, "moss")
    c = Canvas(n, R[1], seed)
    rng = c.rng
    ppm = n / 8.0
    yy, xx = np.mgrid[0:n, 0:n]
    hs = []
    while sum(hs) < 8.0 - 0.6:
        hs.append(rng.uniform(0.6, 0.9))
    hs = np.array(hs) * (8.0 / sum(hs))
    tops = np.concatenate([[0], np.cumsum(hs)]) * ppm
    joint = 0.035 * ppm
    blockcol = np.zeros((n, n, 3))
    edge = np.zeros((n, n))
    for b in range(len(hs)):
        y0, y1 = tops[b], tops[b + 1]
        m = (yy >= y0) & (yy < y1)
        js = []
        x = rng.uniform(0, n)
        x0 = x
        while x < x0 + n - 1.2 * ppm:
            js.append(x)
            x += rng.uniform(1.2, 2.0) * ppm
        js = np.array(js) % n
        js.sort()
        X = xx[m].astype(float)
        d = np.abs(X[:, None] - js[None, :])
        d = np.minimum(d, n - d).min(1)
        idx = np.searchsorted(js, X) % len(js)
        cols = np.array([c.pick(R, (0.0, 0.55, 0.38, 0.07), 0.05) * (1 - 0.12 * rng.random()) for _ in js])
        blockcol[m] = cols[idx]
        Y = yy[m].astype(float)
        edge[m] = np.minimum(np.minimum(Y - y0, y1 - Y), d)
    pillow = smoothstep(joint * 0.5, joint * 0.5 + 0.10 * ppm, edge)
    c.rgb = blockcol
    c.h += pillow
    # chisel strokes and dressing (medium, diagonal), light from -V
    for _ in range(rng.integers(260, 360)):
        L = rng.uniform(0.012, 0.035) * n
        c.stroke3(rng.uniform(0, n), rng.uniform(0, n), L / 2, L / 2 / rng.uniform(2, 4),
                  math.radians(rng.choice([-35, 35]) + rng.uniform(-10, 10)), R, c.pick(R, (0, 0.6, 0.4, 0)),
                  up=(0, -1), alpha=rng.uniform(0.25, 0.5), height=0.15)
    # big soft weather patches
    for _ in range(rng.integers(60, 90)):
        L = rng.uniform(0.06, 0.18) * n
        c.dab(rng.uniform(0, n), rng.uniform(0, n), L / 2, L / 2 / rng.uniform(1.5, 3), rng.uniform(-0.2, 0.2),
              c.pick(R, (0.25, 0.45, 0.3, 0)), alpha=rng.uniform(0.12, 0.25), big=True)
    # rain stains below joints
    for _ in range(rng.integers(25, 40)):
        b = rng.integers(0, len(hs))
        L = rng.uniform(0.05, 0.2) * n
        c.dab(rng.uniform(0, n), tops[b + 1] + L / 2, L / 2, rng.uniform(0.004, 0.01) * n, math.radians(90),
              stain[1], alpha=rng.uniform(0.12, 0.25), taper=0.9, wobble=0.04)
    c.cavity_ao(R[0], amount=0.5, sigma_frac=1 / 48)
    e = c.edge_light(R[3], amount=0.22, width_px=2.0)
    mm = (e > 0.12) & (rng.random((n, n)) < 0.004)
    ys, xs_ = np.nonzero(mm)
    for k in rng.choice(len(ys), size=min(len(ys), 120), replace=False) if len(ys) else []:
        L = rng.uniform(0.004, 0.012) * n
        c.dab(xs_[k], ys[k] - L * 0.2, L, L * 0.4, rng.uniform(-0.2, 0.2), moss[rng.integers(1, 4)], alpha=0.9)
    c.lf_variation(seed + 7, val=0.06)
    lo = np.minimum(R[:3].min(0), stain[1])
    out = c.finish(R, budget, lo=lo)
    return out, c.h


def paint_moss(pal, n=1024, seed=1904, budget=0.40):
    """Moss and fern ground, 4 m tile: clumps 0.2-0.6 m, light on the clumps' upper halves, direction-free."""
    R = ramp(pal, "moss")
    F = ramp(pal, "fern")
    c = Canvas(n, R[1], seed)
    rng = c.rng
    for _ in range(rng.integers(70, 110)):
        L = rng.uniform(0.06, 0.18) * n
        c.dab(rng.uniform(0, n), rng.uniform(0, n), L / 2, L / 2 / rng.uniform(1.0, 1.8), rng.uniform(0, 3.14),
              c.pick(R), alpha=rng.uniform(0.6, 0.95), height=1.0, big=True)
    for _ in range(rng.integers(170, 230)):
        L = rng.uniform(0.04, 0.09) * n
        a = rng.uniform(0, 6.28)
        up = (math.cos(a), math.sin(a)) if rng.random() < 0.4 else (0, -1)
        RR = F if rng.random() < 0.25 else R
        c.stroke3(rng.uniform(0, n), rng.uniform(0, n), L / 2, L / 2 / rng.uniform(1.0, 1.6), a, RR,
                  c.pick(RR, (0, 0.65, 0.35, 0)), up=up, alpha=rng.uniform(0.45, 0.75), height=0.5)
    c.cavity_ao(to_lin(hex_srgb("#24492c")), amount=0.45)
    fl = ramp(pal, "flowers")
    for _ in range(40):
        L = rng.uniform(0.004, 0.008) * n
        c.dab(rng.uniform(0, n), rng.uniform(0, n), L, L * 0.7, 0, fl[rng.choice([1, 2])], 0.9)
    c.lf_variation(seed + 7)
    return c.finish(R, budget, lo=np.minimum(R[:3].min(0), F[0]), hi=np.maximum(R[:4].max(0), F[3])), c.h


def paint_grass(pal, n=1024, seed=2005, budget=0.45):
    """The lineup ground (8 m tile): tufts tilted +-25 deg from vertical, 1-2 m patches, flower specks."""
    R = ramp(pal, "grass")
    c = Canvas(n, R[1], seed)
    rng = c.rng
    ppm = n / 8.0
    for _ in range(rng.integers(70, 100)):
        L = rng.uniform(0.08, 0.2) * n
        c.dab(rng.uniform(0, n), rng.uniform(0, n), L / 2, L / 2 / rng.uniform(1.2, 2.2), rng.uniform(0, 3.14),
              c.pick(R, (0.25, 0.45, 0.3, 0.0)), alpha=rng.uniform(0.4, 0.7), height=1.0, big=True)
    for _ in range(rng.integers(320, 400)):
        L = rng.uniform(0.3, 0.6) * ppm
        a = math.radians(90 + rng.uniform(-25, 25))
        up = (0, -1) if rng.random() < 0.6 else (0, 1)
        c.stroke3(rng.uniform(0, n), rng.uniform(0, n), L / 2, L / 2 / rng.uniform(2.5, 4), a, R,
                  c.pick(R, (0, 0.5, 0.45, 0.05)), up=up, alpha=rng.uniform(0.6, 0.9), height=0.5)
    c.cavity_ao(to_lin(hex_srgb("#24492c")), amount=0.4)
    fl = ramp(pal, "flowers")
    for _ in range(70):
        L = rng.uniform(0.04, 0.07) * ppm
        c.dab(rng.uniform(0, n), rng.uniform(0, n), L, L * 0.7, 0, fl[rng.integers(0, 4)], 0.95)
    c.lf_variation(seed + 7)
    return c.finish(R, budget, hi=R.max(0), lo=np.minimum(R.min(0), ramp(pal, "flowers").min(0))), c.h


def paint_mist(pal, w=1024, h=256, seed=2106):
    """An RGBA mist band card: soft-edged union of overlapping blobs, lit top lighter (3 values), alpha fades to 0
    at every edge. Internal diorama only."""
    M = ramp(pal, "mist")
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    a = np.zeros((h, w))
    top = np.zeros((h, w))
    for _ in range(46):
        cx = rng.uniform(0.08, 0.92) * w
        cy = rng.uniform(0.45, 0.62) * h
        rx = rng.uniform(0.06, 0.16) * w
        ry = rng.uniform(0.18, 0.32) * h
        r = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
        d = smoothstep(1.0, 0.35, r)
        a = np.maximum(a, d * rng.uniform(0.6, 1.0))
        top = np.maximum(top, d * smoothstep(cy, cy - ry, yy))
    edge = smoothstep(0, 0.12 * w, xx) * smoothstep(w, w - 0.12 * w, xx) * smoothstep(0, 0.15 * h, yy) * \
        smoothstep(h, h - 0.2 * h, yy)
    a = np.clip(a * edge, 0, 1) * 0.85
    col = M[1][None, None] * (1 - top[..., None]) + M[3][None, None] * top[..., None]
    col = col * (1 - 0.25 * smoothstep(0.55 * h, h, yy))[..., None] + M[0] * 0.25 * smoothstep(0.55 * h, h, yy)[
        ..., None]
    s = to_srgb(col)
    return np.concatenate([s, a[..., None]], -1)


def save(srgb, path):
    Image.fromarray((np.clip(srgb, 0, 1) * 255 + 0.5).astype(np.uint8)).save(path, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(REPO, "assets", "thuyvan", "rock", "textures"))
    ap.add_argument("--check-dir", default="", help="also copy the _check.png images here (the lineup folder)")
    ap.add_argument("--only", default="")
    ap.add_argument("--palettes", default=PALETTES)
    a = ap.parse_args()
    pal = json.load(open(a.palettes))
    os.makedirs(a.out, exist_ok=True)
    report = {}
    jobs = {
        "karst_face": (lambda: paint_karst(pal), 16.0, 0.62),
        "karst_pale": (lambda: paint_karst(pal, seed=1611, R=np.array([ramp(pal, "karst_limestone")[0],
                                                                       ramp(pal, "white_stone")[1],
                                                                       ramp(pal, "white_stone")[2],
                                                                       ramp(pal, "white_stone")[3]]),
                                           budget=0.74, name="karst_pale"), 16.0, 0.74),
        "white_stone": (lambda: paint_white_stone(pal), 4.0, 0.82),
        "ashlar": (lambda: paint_ashlar(pal), 8.0, 0.68),
        "moss_cap": (lambda: paint_moss(pal), 4.0, 0.40),
        "lineup_grass": (lambda: paint_grass(pal), 8.0, 0.45),
    }
    for name, (fn, tile_m, budget) in jobs.items():
        if a.only and name not in a.only.split(","):
            continue
        img, h = fn()
        p = os.path.join(a.out, name + ".png")
        save(img, p)
        if name == "karst_face":
            hh = (h - h.min()) / max(h.max() - h.min(), 1e-6)
            save(np.repeat(blur(hh, 1.0)[..., None], 3, -1)[..., 0], os.path.join(a.out, name + "_height.png"))
        chk = check_image(img, name, os.path.join(a.out, name + "_check.png"))
        chk.update({"tile_m": tile_m, "size": img.shape[0], "budget": budget,
                    "budget_ok": abs(chk["mean"] - budget) <= 0.05})
        report[name] = chk
        print("ROCK_PAINT", name, json.dumps(chk))
    if not a.only or "mist_card" in a.only:
        save(paint_mist(pal), os.path.join(a.out, "mist_card.png"))
    rp = os.path.join(a.out, "rock_textures.json")
    old = json.load(open(rp)) if os.path.exists(rp) else {}
    old.update(report)
    json.dump(old, open(rp, "w"), indent=1, sort_keys=True)
    if a.check_dir:
        os.makedirs(a.check_dir, exist_ok=True)
        sheet(a.out, list(old.keys()), os.path.join(a.check_dir, "rock_textures.png"))


def sheet(tex_dir, names, path):
    """The textures' lineup: each texture at 512 px beside its 3 x 3 / squint check."""
    rows = []
    for nm in names:
        p = os.path.join(tex_dir, nm + ".png")
        c = os.path.join(tex_dir, nm + "_check.png")
        if os.path.exists(p) and os.path.exists(c):
            rows.append((nm, Image.open(p).convert("RGB").resize((420, 420), Image.LANCZOS), Image.open(c)))
    W = 1920
    H = sum(max(420, int(ch.height * (W - 460) / ch.width)) + 16 for _, _, ch in rows) + 60
    out = Image.new("RGB", (W, H), (236, 230, 216))
    d = ImageDraw.Draw(out)
    d.text((16, 16), "ROCK kit: painted textures (tile, 3x3 tiling at 1/8, squint at 1/16)", fill=(20, 20, 20))
    y = 50
    for nm, t, ch in rows:
        out.paste(t, (16, y))
        chs = ch.resize((W - 460, int(ch.height * (W - 460) / ch.width)), Image.LANCZOS)
        out.paste(chs, (450, y))
        y += max(420, chs.height) + 16
    out.save(path)


if __name__ == "__main__":
    main()
