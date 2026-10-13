#!/usr/bin/env python3
"""Menu variant C, "Painted river": the hand-made pieces the mock draws with, all painted here from code (no image from
anywhere else; SOURCE.md). Writes PNGs next to this file:

  ink_<name>.png     brush art as white ink with alpha (the mock tints it): the four element glyphs, the ensō ring,
                     the row's swash, brush rules, chevrons, the life stamps
  wash_karst.png     an ink-wash river landscape (karst towers in mist, a sampan, reeds) for a scroll's foot
  seal_tidebreak.png the game's vermilion chop with a breaking wave cut out of it (full colour)
  chop_square.png    a bare square stamp (white with alpha, tinted by the mock)
  paper_tile.png     rice paper, 512 px, tiles
  lacquer_tile.png   black-red lacquer with gold dust, 512 px, tiles
  rod_top.png, rod_foot.png   the scroll's head stick and foot roller, dark wood with gold knobs (nine-patches)
  edge_noise.png, noise_a/b/c.png   tileable noises for the paper's torn edge and the oil-paint shader

  python3 tools/ui_audit/menu_variants/c_painted/make_ink.py [glyphs|chops|strokes|wash|tiles ...]
(numpy and Pillow; fixed seeds, so every file rebuilds the same.)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
RNG = np.random.default_rng(1765)


# ----------------------------------------------------------------------------------------------- tileable noise
def periodic_noise(n, sigma, rng):
    """Gaussian-filtered white noise on a torus (tiles), normalised to 0..1."""
    w = rng.standard_normal((n, n))
    f = np.fft.fft2(w)
    k = np.fft.fftfreq(n)
    kx, ky = np.meshgrid(k, k)
    g = np.exp(-2.0 * (math.pi ** 2) * (sigma ** 2) * (kx ** 2 + ky ** 2))
    out = np.real(np.fft.ifft2(f * g))
    out -= out.min()
    out /= max(out.max(), 1e-9)
    return out


def save_gray(a, name):
    Image.fromarray(np.clip(a * 255.0, 0, 255).astype(np.uint8)).save(os.path.join(HERE, name))


# ----------------------------------------------------------------------------------------------- the brush
def catmull(pts, per=40):
    """A smooth path through `pts` (Catmull-Rom), dense."""
    p = [np.array(pts[0], float)] + [np.array(q, float) for q in pts] + [np.array(pts[-1], float)]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        seg = np.linalg.norm(p2 - p1)
        m = max(4, int(seg / 1.0))
        for j in range(m):
            t = j / m
            t2, t3 = t * t, t * t * t
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out.append(q)
    out.append(p[-2])
    return np.array(out)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def stroke(canvas, pts, width, rng, t_in=0.10, t_out=0.35, dry=0.45, press=0.75, end=0.08, wobble=0.10,
           bristles=48, start_blob=1.12):
    """Lays one brush stroke along `pts` into `canvas` (coverage 0..1, max-combined). The width swells from a pressed
    start (`start_blob`), holds, and lifts off over the last `t_out` to `end`; `dry` of the bristles run out toward the
    end (streaks); the edge wobbles by `wobble`."""
    path = catmull(pts)
    seg = np.linalg.norm(np.diff(path, axis=0), axis=1)
    L = np.concatenate([[0.0], np.cumsum(seg)])
    total = max(L[-1], 1e-6)
    # resample every 0.5 px
    n = max(2, int(total / 0.5))
    ts = np.linspace(0.0, total, n)
    xs = np.interp(ts, L, path[:, 0])
    ys = np.interp(ts, L, path[:, 1])
    dx = np.gradient(xs)
    dy = np.gradient(ys)
    ln = np.hypot(dx, dy) + 1e-9
    nx, ny = -dy / ln, dx / ln
    t = ts / total
    prof = (press + (1 - press) * smoothstep(0.0, t_in, t)) * (1.0 - (1.0 - end) * smoothstep(1.0 - t_out, 1.0, t) ** 1.3)
    prof *= 1.0 + (start_blob - 1.0) * (1.0 - smoothstep(0.0, t_in * 1.5, t))
    wob = np.interp(t, np.linspace(0, 1, 9), rng.uniform(-1, 1, 9))
    fine = np.interp(t, np.linspace(0, 1, 60), rng.uniform(-1, 1, 60))
    r = width * 0.5 * prof * (1.0 + wobble * wob + wobble * 0.35 * fine)
    br = rng.uniform(0, 1, bristles)
    br = np.convolve(np.concatenate([br[-2:], br, br[:2]]), np.ones(3) / 3.0, mode="same")[2:-2]
    shade = rng.uniform(0.80, 1.0, bristles)
    H, W = canvas.shape
    for i in range(n):
        ri = r[i]
        if ri < 0.3:
            continue
        cx, cy = xs[i], ys[i]
        x0, x1 = int(max(0, cx - ri - 2)), int(min(W, cx + ri + 3))
        y0, y1 = int(max(0, cy - ri - 2)), int(min(H, cy + ri + 3))
        if x0 >= x1 or y0 >= y1:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        vx, vy = gx - cx, gy - cy
        d = np.hypot(vx, vy)
        cov = np.clip(ri - d + 0.75, 0.0, 1.0)
        u = np.clip((vx * nx[i] + vy * ny[i]) / max(ri, 1e-3), -1, 1)
        idx = np.clip(((u + 1.0) * 0.5 * (bristles - 1)).astype(int), 0, bristles - 1)
        thr = dry * smoothstep(0.35, 1.0, t[i]) ** 1.2
        ink = (br[idx] > thr).astype(float) * shade[idx]
        # the edges dry first
        ink *= 1.0 - smoothstep(0.6, 1.0, np.abs(u)) * dry * 0.6 * smoothstep(0.2, 1.0, t[i])
        val = cov * ink
        sub = canvas[y0:y1, x0:x1]
        np.maximum(sub, val, out=sub)


def ink_png(canvas, name, ss=2, blur=0.0):
    """White ink with the canvas as its alpha, down-sampled from `ss` x."""
    a = np.clip(canvas, 0, 1)
    img = Image.fromarray((a * 255).astype(np.uint8))
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    if ss > 1:
        img = img.resize((img.width // ss, img.height // ss), Image.LANCZOS)
    out = Image.new("RGBA", img.size, (255, 255, 255, 0))
    out.putalpha(img)
    out.save(os.path.join(HERE, name))
    return out


def scaled(pts, s):
    return [(x * s, y * s) for x, y in pts]


# ----------------------------------------------------------------------------------------------- the glyphs
# drawn in a 256 box, at 2x
GLYPHS = {
    # earth: two leaning karst peaks over a heavy ground stroke
    "earth": [
        dict(pts=[(30, 194), (62, 140), (90, 104), (112, 132), (128, 158)], w=22, dry=0.4, t_out=0.3),
        dict(pts=[(84, 196), (120, 120), (152, 50), (186, 120), (226, 192)], w=26, dry=0.45, t_out=0.35, press=0.6),
        dict(pts=[(22, 214), (96, 204), (170, 208), (236, 200)], w=24, dry=0.6, t_out=0.45, press=0.9),
    ],
    # water: a curling crest and two swells under it
    "water": [
        dict(pts=[(30, 150), (64, 104), (118, 82), (170, 92), (198, 124), (186, 156), (156, 158), (146, 136)], w=24,
             dry=0.4, t_out=0.3),
        dict(pts=[(34, 190), (84, 172), (134, 190), (186, 174), (228, 184)], w=17, dry=0.55, t_out=0.4),
        dict(pts=[(66, 224), (126, 212), (196, 224)], w=12, dry=0.6, t_out=0.45),
    ],
    # fire: a flame in two strokes and an inner flick
    "fire": [
        dict(pts=[(150, 26), (110, 82), (82, 140), (90, 192), (126, 222)], w=24, dry=0.35, t_out=0.25, press=0.5),
        dict(pts=[(160, 78), (186, 128), (182, 186), (150, 218), (118, 224)], w=22, dry=0.5, t_out=0.35, press=0.55),
        dict(pts=[(136, 118), (118, 160), (124, 192), (140, 200)], w=14, dry=0.4, t_out=0.4),
    ],
    # air: a spiral gust and a long wind line
    "air": [
        dict(pts=[(28, 96), (96, 84), (160, 86), (204, 108), (204, 144), (174, 152), (162, 130), (178, 118)], w=20,
             dry=0.4, t_out=0.3),
        dict(pts=[(56, 152), (122, 144), (190, 150), (232, 144)], w=16, dry=0.6, t_out=0.45),
        dict(pts=[(30, 202), (92, 194), (150, 204), (204, 196)], w=13, dry=0.65, t_out=0.5),
    ],
}


def glyph(name, rng, ss=2, size=256):
    c = np.zeros((size * ss, size * ss))
    for s in GLYPHS[name]:
        stroke(c, scaled(s["pts"], ss), s["w"] * ss, rng, dry=s.get("dry", 0.45), t_out=s.get("t_out", 0.35),
               press=s.get("press", 0.75))
    return c


def enso(rng, ss=2, size=256, width=22):
    c = np.zeros((size * ss, size * ss))
    R = size * 0.40
    cx, cy = size * 0.5, size * 0.5
    pts = []
    a0 = math.radians(-70)
    for k in range(0, 30):
        a = a0 + math.radians(332) * k / 29
        rr = R * (1.0 + 0.025 * math.sin(k * 0.9))
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    stroke(c, scaled(pts, ss), width * ss, rng, dry=0.62, t_out=0.45, press=0.85, end=0.15, start_blob=1.25,
           bristles=64)
    return c


def stamp_texture(alpha, rng, voids=0.12):
    """The ink a stamp leaves: small voids where it didn't take, a fine grain."""
    h, w = alpha.shape
    n = max(h, w)
    big = periodic_noise(n, 3.0, rng)[:h, :w]
    fine = periodic_noise(n, 0.8, rng)[:h, :w]
    low = periodic_noise(n, 22.0, rng)[:h, :w]
    hole = smoothstep(1.0 - voids, 1.0 - voids * 0.5, big)
    grain = 0.80 + 0.20 * fine
    press = 0.72 + 0.28 * smoothstep(0.15, 0.6, low)
    return alpha * (1.0 - hole) * grain * press


def rough_rect(size, inset, rng, ss=2, corner=8, rough=1.6):
    """A square stamp's body: a rounded square whose edge wanders."""
    n = size * ss
    yy, xx = np.mgrid[0:n, 0:n] + 0.5
    h = n * 0.5
    half = h - inset * ss
    qx = np.abs(xx - h) - (half - corner * ss)
    qy = np.abs(yy - h) - (half - corner * ss)
    sd = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - corner * ss
    edge = ((periodic_noise(n, 5.0 * ss, rng) - 0.5) * 1.4 + (periodic_noise(n, 1.2 * ss, rng) - 0.5) * 1.0) * rough * ss
    return np.clip(-(sd + edge) + 0.75, 0, 1), sd


def chop_square(rng, ss=2, size=256):
    body, sd = rough_rect(size, 10, rng, ss)
    # a frame line cut into it, as on a carved seal
    frame = np.clip(1.0 - np.abs(sd + 20 * ss) / (3.2 * ss), 0, 1)
    a = body * (1.0 - frame)
    return stamp_texture(a, rng, 0.2)


def seal_tidebreak(rng, ss=2, size=256):
    body, sd = rough_rect(size, 8, rng, ss, corner=14)
    frame = np.clip(1.0 - np.abs(sd + 18 * ss) / (3.5 * ss), 0, 1)
    cut = np.zeros_like(body)
    # the breaking wave cut out of the stamp (white on red)
    stroke(cut, scaled([(52, 168), (70, 116), (116, 76), (168, 74), (200, 102), (198, 138), (170, 150), (152, 128),
                        (166, 112)], ss), 26 * ss, rng, dry=0.25, t_out=0.3, press=0.7)
    stroke(cut, scaled([(54, 196), (100, 182), (148, 196), (204, 182)], ss), 16 * ss, rng, dry=0.35, t_out=0.4)
    a = body * (1.0 - frame) * (1.0 - cut)
    a = stamp_texture(a, rng, 0.18)
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).resize((size, size), Image.LANCZOS)
    col = Image.new("RGBA", (size, size), (176, 48, 34, 0))
    col.putalpha(img)
    col.save(os.path.join(HERE, "seal_tidebreak.png"))


def life_stamp(rng, ss=2, size=96):
    n = size * ss
    yy, xx = np.mgrid[0:n, 0:n] + 0.5
    d = np.hypot(xx - n / 2, yy - n / 2)
    edge = (periodic_noise(n, 3.0 * ss, rng) - 0.5) * 4.0 * ss
    a = np.clip((n * 0.40 + edge) - d + 0.75, 0, 1)
    a = stamp_texture(a, rng, 0.14)
    ink_png(a, "ink_life.png", ss)
    c = np.zeros((n, n))
    pts = []
    for k in range(24):
        ang = math.radians(-80 + 340 * k / 23)
        pts.append((n / 2 + n * 0.36 * math.cos(ang), n / 2 + n * 0.36 * math.sin(ang)))
    stroke(c, pts, 7 * ss, rng, dry=0.5, t_out=0.4, press=0.9, end=0.2)
    ink_png(c, "ink_life_empty.png", ss)


# ----------------------------------------------------------------------------------------------- strokes for the UI
def swash(rng, ss=2, w=560, h=84):
    c = np.zeros((h * ss, w * ss))
    pts = [(14, 50), (120, 40), (260, 38), (400, 44), (546, 36)]
    stroke(c, scaled(pts, ss), 54 * ss, rng, dry=0.72, t_out=0.55, press=0.9, end=0.35, start_blob=1.08, bristles=80,
           wobble=0.06)
    ink_png(c, "ink_swash.png", ss)


def rule(rng, ss=2, w=520, h=22, name="ink_rule.png", width=7):
    c = np.zeros((h * ss, w * ss))
    stroke(c, scaled([(6, 12), (180, 10), (360, 12), (512, 9)], ss), width * ss, rng, dry=0.6, t_out=0.6, press=0.6,
           end=0.05, start_blob=1.3, bristles=40)
    ink_png(c, name, ss)


def chevrons(rng, ss=2, size=48):
    for name, pts in (("ink_next.png", [(16, 8), (34, 24), (16, 40)]), ("ink_prev.png", [(32, 8), (14, 24), (32, 40)])):
        c = np.zeros((size * ss, size * ss))
        stroke(c, scaled(pts, ss), 7 * ss, rng, dry=0.3, t_out=0.35, press=0.8)
        ink_png(c, name, ss)


def dot(rng, ss=2, size=40):
    c = np.zeros((size * ss, size * ss))
    stroke(c, scaled([(12, 22), (20, 18), (28, 20)], ss), 16 * ss, rng, dry=0.2, t_out=0.4, press=1.0)
    ink_png(c, "ink_dot.png", ss)


# ----------------------------------------------------------------------------------------------- paper, lacquer, rod
def paper_tile(rng, n=512):
    base = np.array([238.0, 226.0, 198.0]) / 255.0
    low = periodic_noise(n, 48, rng) - 0.5
    mid = periodic_noise(n, 9, rng) - 0.5
    fine = periodic_noise(n, 1.2, rng) - 0.5
    lum = 1.0 + low * 0.07 + mid * 0.035 + fine * 0.03
    # fibres: short curved hairs, some light some dark, drawn on a 3x3 field and folded so the tile repeats
    big = Image.new("L", (n * 3, n * 3), 0)
    dark = Image.new("L", (n * 3, n * 3), 0)
    dl, dd = ImageDraw.Draw(big), ImageDraw.Draw(dark)
    for k in range(900):
        x, y = rng.uniform(n, 2 * n), rng.uniform(n, 2 * n)
        ang = rng.uniform(0, math.tau)
        length = rng.uniform(14, 70)
        bend = rng.uniform(-0.04, 0.04)
        pts = []
        for j in range(12):
            s = length * j / 11
            a = ang + bend * s
            pts.append((x + math.cos(a) * s, y + math.sin(a) * s))
            x, y = pts[-1][0] - math.cos(a) * s, pts[-1][1] - math.sin(a) * s
        (dd if k % 3 == 0 else dl).line(pts, fill=int(rng.uniform(60, 140)), width=1)
    def fold(im):
        a = np.asarray(im, dtype=float) / 255.0
        out = np.zeros((n, n))
        for i in range(3):
            for j in range(3):
                out += a[i * n:(i + 1) * n, j * n:(j + 1) * n]
        return np.clip(out, 0, 1)
    light = fold(big.filter(ImageFilter.GaussianBlur(0.6)))
    darkf = fold(dark.filter(ImageFilter.GaussianBlur(0.5)))
    lum = lum + light * 0.06 - darkf * 0.07
    # specks
    sp = periodic_noise(n, 0.7, rng)
    lum -= smoothstep(0.93, 0.99, sp) * 0.12
    rgb = np.clip(base[None, None, :] * lum[..., None], 0, 1)
    # a faint warm cast in the low mottling
    rgb[..., 2] *= 1.0 - low * 0.05
    Image.fromarray((rgb * 255).astype(np.uint8)).save(os.path.join(HERE, "paper_tile.png"))


def lacquer_tile(rng, n=512):
    black = np.array([20, 12, 10], float) / 255.0
    red = np.array([84, 26, 18], float) / 255.0
    umber = np.array([46, 26, 18], float) / 255.0
    low = periodic_noise(n, 60, rng)
    mid = periodic_noise(n, 14, rng)
    fine = periodic_noise(n, 1.5, rng) - 0.5
    # the layers sanded back: red and umber showing through in soft patches
    a_red = smoothstep(0.58, 0.66, low) * 0.42
    a_umb = smoothstep(0.55, 0.62, mid) * 0.3
    rgb = black[None, None, :] * np.ones((n, n, 1))
    rgb = rgb * (1 - a_umb[..., None]) + umber * a_umb[..., None]
    rgb = rgb * (1 - a_red[..., None]) + red * a_red[..., None]
    rgb *= (1.0 + fine * 0.08)[..., None]
    # gold dust: flakes in drifts
    drift = periodic_noise(n, 30, rng)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for k in range(1500):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        if rng.uniform() > smoothstep(0.45, 0.9, drift[int(y) % n, int(x) % n]) * 0.9 + 0.03:
            continue
        r = rng.uniform(0.6, 2.4)
        pts = [(x + r * math.cos(t) * rng.uniform(0.5, 1.3), y + r * math.sin(t) * rng.uniform(0.5, 1.3))
               for t in np.linspace(0, math.tau, 6, endpoint=False)]
        g = rng.uniform(0.75, 1.0)
        col = (int(214 * g), int(170 * g), int(92 * g))
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d.polygon([(px + ox, py + oy) for px, py in pts], fill=col)
    img = img.filter(ImageFilter.GaussianBlur(0.3))
    img.save(os.path.join(HERE, "lacquer_tile.png"))


def rod(rng, w=900, h=34, cap=34, name="rod.png"):
    """A lacquered scroll rod with gold caps: dark red-brown, a highlight along its top third; a nine-patch whose
    margins are the caps."""
    ss = 2
    W, H = w * ss, h * ss
    img = np.zeros((H, W, 4))
    yy, xx = np.mgrid[0:H, 0:W] + 0.5
    # the body, a cylinder: shade by the height
    body_h = H * 0.66
    top = (H - body_h) / 2
    v = np.clip((yy - top) / body_h, 0, 1)
    inside = (yy >= top) & (yy <= top + body_h) & (xx > cap * ss * 0.7) & (xx < W - cap * ss * 0.7)
    shade = 0.35 + 0.65 * np.exp(-((v - 0.3) ** 2) / 0.02) * 0.9 + 0.25 * (1 - v)
    base = np.array([58, 30, 20], float) / 255.0
    col = base[None, None, :] * shade[..., None]
    col += np.exp(-((v - 0.24) ** 2) / 0.002)[..., None] * np.array([0.42, 0.30, 0.20])
    # a gold band near each end, as a fitted collar
    for ex in (cap * ss * 1.15, W - cap * ss * 1.15):
        band = (np.abs(xx - ex) < ss * 2.2)
        col[band] = (np.array([190, 146, 70], float) / 255.0) * (0.6 + 0.6 * np.exp(-((v[band] - 0.3) ** 2) / 0.05))[..., None]
    img[inside, :3] = col[inside]
    img[inside, 3] = 1.0
    # the caps: gold knobs, round
    for cx in (cap * ss * 0.5 + 1, W - cap * ss * 0.5 - 1):
        d = np.hypot(xx - cx, (yy - H / 2) * 1.0)
        rr = H * 0.47
        m = d < rr + 1
        a = np.clip(rr - d + 0.75, 0, 1)
        ny = (yy - H / 2) / rr
        nx = (xx - cx) / rr
        light = np.clip(0.55 - 0.6 * ny - 0.25 * nx, 0, 1)
        gold = np.array([150, 108, 46], float) / 255.0 * (0.55 + 0.8 * light[..., None])
        gold += (np.exp(-(((nx + 0.25) ** 2 + (ny + 0.45) ** 2)) / 0.03))[..., None] * np.array([0.5, 0.42, 0.28])
        ring = np.abs(d - rr * 0.62) < ss * 1.2
        gold[ring] *= 0.6
        img[m, :3] = gold[m]
        img[m, 3] = np.maximum(img[m, 3], a[m])
    out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS)
    out.save(os.path.join(HERE, name))


def wash_karst(rng, w=1000, h=380):
    """An ink-wash river landscape for a scroll's foot (sumi-e, boneless): far ridges in mist, karst towers with pine
    dots on their crowns, a bank of reeds and a small river boat with its curved roof, water lines. White with alpha."""
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    acc = np.zeros((h, w))

    def lay(a):
        np.copyto(acc, 1.0 - (1.0 - acc) * (1.0 - np.clip(a, 0, 1)))

    tex = periodic_noise(max(w, h), 2.5, rng)[:h, :w]
    tex2 = periodic_noise(max(w, h), 12.0, rng)[:h, :w]
    # far ridges
    for k, (base, amp, alpha) in enumerate([(200, 26, 0.16), (232, 34, 0.22)]):
        ridge = base + amp * (np.interp(xx[0], np.linspace(0, w, 14), rng.uniform(-1, 1, 14)))
        inside = yy >= ridge[None, :]
        fade = 1.0 - smoothstep(0.0, 70.0, yy - ridge[None, :])
        edge = 1.0 + 0.8 * np.exp(-(yy - ridge[None, :]) / 5.0)
        lay(inside * fade * edge * alpha * (0.75 + 0.25 * tex2))
    # karst towers, the back rank paler: [centre x, base y, half width, height, lean, alpha]; each painted over what
    # is behind it (the wash covers), darkest at its crown, its sides streaked by the brush, its foot lost in mist
    streak = np.asarray(Image.fromarray((periodic_noise(512, 1.2, rng) * 255).astype(np.uint8)).resize((w, h // 6))
                        .resize((w, h), Image.BICUBIC), dtype=float) / 255.0
    back = [(470, 296, 26, 112, 4, 0.20), (560, 300, 34, 150, -5, 0.22), (735, 298, 30, 128, 8, 0.20),
            (905, 300, 38, 160, -6, 0.22), (990, 300, 30, 120, 4, 0.18)]
    front = [(615, 306, 44, 196, 12, 0.46), (690, 312, 30, 132, -8, 0.40), (820, 306, 50, 236, 16, 0.52),
             (890, 314, 26, 118, -4, 0.38), (958, 308, 40, 176, 8, 0.46), (520, 314, 26, 96, 6, 0.34)]
    for cx, base, hw, ht, lean, alpha in back + front:
        t = np.clip((base - yy) / ht, 0, 1.2)
        c = cx + lean * t
        f = np.clip(1.0 - t ** 4.0, 0, 1) ** 0.25
        ks = rng.uniform(0, 10, 4)
        nl = 0.10 * np.sin(t * 13 + ks[0]) + 0.06 * np.sin(t * 31 + ks[1]) + 0.08 * np.floor(t * 5 + ks[2] % 1) / 5
        nr = 0.10 * np.sin(t * 11 + ks[2]) + 0.06 * np.sin(t * 27 + ks[3]) + 0.07 * np.floor(t * 4 + ks[1] % 1) / 4
        left = c - hw * f * (1.0 + nl)
        right = c + hw * f * (1.0 + nr)
        inside = (xx >= left) & (xx <= right) & (yy <= base) & (t < 1.0)
        top = base - ht
        side_d = np.minimum(xx - left, right - xx)
        pool = 1.0 + 0.7 * np.exp(-np.maximum(side_d, 0) / 3.5)
        crown = 1.0 + 0.6 * smoothstep(0.55, 1.0, t)
        fade = smoothstep(base + 6, base - ht * 0.6, yy)
        a = inside * np.clip(alpha * pool * crown * fade * (0.62 + 0.38 * streak) * (0.85 + 0.15 * tex), 0, 1)
        cover = inside * fade * 0.8
        np.copyto(acc, acc * (1.0 - cover) + a)
        # pines on the crown: small dark dabs in clumps along the top edge
        for k in range(int(hw * 0.9)):
            px = cx + lean + rng.uniform(-hw * 0.75, hw * 0.75)
            tt = 1.0 - (abs(px - cx - lean) / hw) ** 4
            py = base - ht * max(tt, 0.0) ** 0.25 * 0.995 + rng.uniform(-2, 7)
            r = rng.uniform(1.6, 3.4)
            dab = (np.hypot(xx - px, (yy - py) * 1.25) < r)
            np.copyto(acc, np.maximum(acc, dab * min(alpha * 1.9, 0.85)))
    # water lines
    wl = np.zeros((h, w))
    for k in range(7):
        y0 = rng.uniform(310, 360)
        x0 = rng.uniform(80, 700)
        L = rng.uniform(120, 300)
        stroke(wl, [(x0, y0), (x0 + L * 0.5, y0 + rng.uniform(-2, 2)), (x0 + L, y0 + rng.uniform(-2, 2))],
               rng.uniform(2.0, 3.5), rng, dry=0.75, t_out=0.6, press=0.7, end=0.1, bristles=24)
    lay(wl * 0.45)
    # the boat: a long low hull and a curved roof (a sampan), small, on the water
    bx, by = 330.0, 318.0
    hull = (np.abs(xx - bx) < 46 - (yy - by) * 1.6) & (yy >= by) & (yy <= by + 7)
    hull |= ((xx - bx - 46) ** 2 / 90 + (yy - by + 4) ** 2 / 20 < 1) & (yy <= by + 4)
    hull |= ((xx - bx + 46) ** 2 / 60 + (yy - by + 2) ** 2 / 16 < 1) & (yy <= by + 3)
    roof = ((xx - bx + 4) ** 2 / (22 ** 2) + (yy - by + 3) ** 2 / (13 ** 2) < 1) & (yy <= by)
    lay(hull * 0.8)
    lay(roof * 0.62)
    pole = (np.abs(xx - (bx + 30 + (by - yy) * 0.35)) < 1.2) & (yy > by - 40) & (yy < by)
    lay(pole * 0.7)
    # reeds on the near bank, left
    rd = np.zeros((h, w))
    for k in range(26):
        x0 = rng.uniform(10, 230)
        y0 = rng.uniform(350, 378)
        ht = rng.uniform(30, 90)
        bend = rng.uniform(-18, 18)
        stroke(rd, [(x0, y0), (x0 + bend * 0.4, y0 - ht * 0.5), (x0 + bend, y0 - ht)], rng.uniform(2.5, 4.5), rng,
               dry=0.3, t_out=0.7, press=1.0, end=0.05, bristles=16)
    lay(rd * 0.55)
    bank = (yy > 355 + 10 * np.sin(xx / 60.0)) & (xx < 300 - (yy - 355) * 2)
    lay(bank * 0.35 * (0.7 + 0.3 * tex))
    img = Image.fromarray((np.clip(acc, 0, 1) * 255).astype(np.uint8))
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    out = Image.new("RGBA", img.size, (255, 255, 255, 0))
    out.putalpha(img)
    out.save(os.path.join(HERE, "wash_karst.png"))


def noises(rng):
    save_gray(periodic_noise(256, 9, rng), "noise_a.png")
    save_gray(periodic_noise(256, 9, rng), "noise_b.png")
    save_gray(periodic_noise(256, 2.2, rng), "noise_c.png")
    save_gray(periodic_noise(256, 6, rng) * 0.7 + periodic_noise(256, 1.5, rng) * 0.3, "edge_noise.png")
    save_gray(periodic_noise(256, 1.0, rng), "flake_noise.png")


def main():
    only = sys.argv[1:]
    def want(k):
        return not only or k in only
    if want("glyphs"):
        for name in GLYPHS:
            ink_png(glyph(name, np.random.default_rng(sum(map(ord, name)) + 11)), "ink_%s.png" % name)
        ink_png(enso(np.random.default_rng(42)), "ink_enso.png")
    if want("chops"):
        a = chop_square(np.random.default_rng(7))
        ink_png(a, "chop_square.png")
        seal_tidebreak(np.random.default_rng(9))
        life_stamp(np.random.default_rng(5))
    if want("strokes"):
        swash(np.random.default_rng(3))
        rule(np.random.default_rng(4))
        rule(np.random.default_rng(14), w=260, h=18, name="ink_rule_short.png", width=6)
        chevrons(np.random.default_rng(6))
        dot(np.random.default_rng(8))
    if want("wash"):
        wash_karst(np.random.default_rng(21))
    if want("tiles"):
        paper_tile(np.random.default_rng(10))
        lacquer_tile(np.random.default_rng(12))
        rod(np.random.default_rng(13), h=28, cap=30, name="rod_top.png")
        rod(np.random.default_rng(13), h=42, cap=44, name="rod_foot.png")
        noises(np.random.default_rng(15))
    print("MAKE INK DONE")


if __name__ == "__main__":
    main()
