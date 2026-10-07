"""Thủy Vân dress: hand-painted cloth (style guide section 3.2, the brush recipe) for the peoples' garments.

    python3 tools/thuyvan_art/dress/paint_dress.py            # writes assets/thuyvan/dress/{paint,motifs}/ + json

Two kinds of tile, both painted on a torus (every dab wraps) with fixed seeds, so they rebuild bit for bit:

1. **Value maps** (`paint/<kit>.png`, 512², 8-bit grey): one per cloth kind (weave, hemp, felt, leather, fur, straw,
   cord, lacquer, metal, paper). A pixel is a place on the dye's 4-stop ramp (`peoples_dyes.json`, now the `tv_*`
   entries of cloth2/palette.json): 0 = dark, 0.40 = mid, 0.75 = light, 1.0 = accent. The ramp is applied at render
   time (Blender ColorRamp; in Godot a ramp lookup per zone), so one value map serves every dye: an indigo vest and a
   madder sash share the weave strokes and keep their own hue family. Strokes are the recipe's: big flat dabs with a
   firm painter's edge, medium dabs painted three times (dark under, body, light sliver on top: the texture's -V is
   up on cloth, which hangs), painted cavity AO, no noise finer than 1/16 of the tile.
2. **Motif tiles** (`motifs/<name>.png`, RGBA): woven pattern bands, our own straight-cut designs (style guide section
   9: straight cuts and at most one ring; no Hán, no swirl, nothing traced from any real people's brocade). R, G, B
   are the coverage of the motif's three thread colours over the zone's ground dye; A is 1. The cuts wobble a little
   (hand-woven), and each thread colour carries its own value strokes so the motif is painted, not printed.

`dress_paint.json` lists every tile: its world size (m), what it is for, and (motifs) the default thread dyes.
"""

import json
import math
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "thuyvan", "dress")
N = 512

STOPS = {"dark": 0.0, "mid": 0.40, "light": 0.75, "accent": 1.0}


# ---- the torus brush ------------------------------------------------------------------------------------------------
class Canvas:
    """A float canvas on a torus: every dab wraps round both edges."""

    def __init__(self, n=N, fill=0.40):
        self.n = n
        self.v = np.full((n, n), float(fill))
        self.h = np.zeros((n, n))

    def dab(self, cx, cy, rx, ry, ang, val, height=0.0, edge=0.75, alpha=1.0):
        """An elliptical dab (centre px, radii px, angle rad) of one flat value, alpha = smoothstep(1, edge, r)."""
        n = self.n
        R = int(math.ceil(max(rx, ry))) + 2
        xs = np.arange(-R, R + 1)
        X, Y = np.meshgrid(xs, xs)
        c, s = math.cos(ang), math.sin(ang)
        u = (X * c + Y * s) / max(rx, 0.5)
        w = (-X * s + Y * c) / max(ry, 0.5)
        r = np.sqrt(u * u + w * w)
        a = np.clip((1.0 - r) / (1.0 - edge), 0.0, 1.0)
        a = a * a * (3 - 2 * a) * alpha
        ix = (int(round(cx)) + xs) % n
        iy = (int(round(cy)) + xs) % n
        sub = self.v[np.ix_(iy, ix)]
        self.v[np.ix_(iy, ix)] = sub + (val - sub) * a
        if height:
            self.h[np.ix_(iy, ix)] += height * a

    def blur(self, arr, px):
        return torus_blur(arr, px)


def torus_blur(arr, px):
    """A Gaussian blur of sigma `px` on the torus (in the Fourier domain: it wraps exactly)."""
    if px <= 0:
        return arr
    h, w = arr.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2.0 * (np.pi * px) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(arr) * g))


def value_noise(n, period, rng):
    """Tileable value noise with `period` cells across (smooth cosine interpolation)."""
    g = rng.random((period, period))
    xs = np.arange(n) * period / n
    i0 = np.floor(xs).astype(int)
    f = xs - i0
    f = (1 - np.cos(f * np.pi)) / 2
    i1 = (i0 + 1) % period
    a = g[np.ix_(i0, i0)] * (1 - f)[None, :] + g[np.ix_(i0, i1)] * f[None, :]
    b = g[np.ix_(i1, i0)] * (1 - f)[None, :] + g[np.ix_(i1, i1)] * f[None, :]
    return a * (1 - f)[:, None] + b * f[:, None]


def pick(rng, weights=(0.20, 0.45, 0.30, 0.05)):
    k = rng.choice(4, p=np.array(weights) / sum(weights))
    v = [STOPS["dark"], STOPS["mid"], STOPS["light"], STOPS["accent"]][k]
    return float(np.clip(v + rng.normal(0, 0.03), 0.0, 1.0))


def finish(cv, cavity=0.45, lo=0.02, hi=0.98, blur=0.6):
    """Painted cavity AO (blur(height) - height), the 0.6 px blur and unsharp mask, clamped inside the ramp."""
    n = cv.n
    h = cv.h
    if h.max() > 0:
        h = h / h.max()
        cav = np.clip(cv.blur(h, n / 24.0) - h, 0.0, 1.0)
        cv.v = cv.v - cav * cavity * (cv.v - STOPS["dark"] + 0.15)
    v = cv.blur(cv.v, blur)
    soft = cv.blur(v, n / 32.0)
    v = v + 0.4 * (v - soft)
    return np.clip(v, lo, hi)


def strokes(cv, rng, count, length, aspect, ang, ang_jit, weights=(0.20, 0.45, 0.30, 0.05), height=1.0, three=False,
            alpha=1.0):
    """`count` dabs `length` (fraction of the tile, a (lo, hi) range) long, aspect (lo, hi), at `ang` +- ang_jit rad;
    `three`: the medium-stroke triple (dark copy under, body, light sliver above: -V is up)."""
    n = cv.n
    for _ in range(count):
        L = rng.uniform(*length) * n
        a = rng.uniform(*aspect)
        rx, ry = L / 2, L / 2 / a
        th = ang + rng.uniform(-ang_jit, ang_jit)
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        val = pick(rng, weights)
        if three:
            cv.dab(x, y + 0.15 * ry * 2, rx, ry, th, STOPS["dark"] + 0.05, 0.0, alpha=alpha * 0.8)
            cv.dab(x, y, rx, ry, th, max(val, STOPS["mid"] - 0.05), height * 0.5, alpha=alpha)
            cv.dab(x, y - 0.2 * ry * 2, rx * 0.8, ry * 0.35, th, STOPS["light"] + 0.05, 0.0, alpha=alpha * 0.9)
        else:
            cv.dab(x, y, rx, ry, th, val, height, alpha=alpha)


def base(cv, rng, amp=0.08):
    """Fill with mid and the two octaves of low-frequency value variation (periods 1 and 1/2 of the tile)."""
    n = cv.n
    lf = (value_noise(n, 1 + 1, rng) - 0.5) * 2 * amp + (value_noise(n, 2 * 2, rng) - 0.5) * amp
    cv.v = cv.v + lf


# ---- value maps ---------------------------------------------------------------------------------------------------
def layered(cv, rng, count, length, aspect, ang, ang_jit, vals, alpha=(0.35, 0.65), edge=0.45, height=0.6):
    """Layered translucent brush strokes (cloth is painted by glazing): `vals` (lo, hi) the value range."""
    n = cv.n
    for _ in range(count):
        L = rng.uniform(*length) * n
        a = rng.uniform(*aspect)
        cv.dab(rng.uniform(0, n), rng.uniform(0, n), L / 2, L / 2 / a, ang + rng.uniform(-ang_jit, ang_jit),
               rng.uniform(*vals), height, edge=edge, alpha=rng.uniform(*alpha))


def kit_weave(seed=11):
    """Homespun cotton and hemp cloth (vests, robes, trousers, skirts): glazed warp strokes across, fewer weft strokes
    down, soft fading blotches, a few light slubs."""
    rng = np.random.default_rng(seed)
    cv = Canvas()
    base(cv, rng, 0.06)
    layered(cv, rng, 40, (0.25, 0.45), (1.2, 2.0), 0.0, math.pi, (0.30, 0.50), (0.2, 0.4), 0.2, 1.0)
    layered(cv, rng, 700, (0.08, 0.20), (7.0, 14.0), 0.0, 0.05, (0.30, 0.52))
    layered(cv, rng, 300, (0.06, 0.14), (7.0, 12.0), math.pi / 2, 0.05, (0.30, 0.48), (0.2, 0.4))
    layered(cv, rng, 60, (0.04, 0.10), (8.0, 14.0), 0.0, 0.05, (0.62, 0.75), (0.5, 0.8), 0.6, 0.0)
    layered(cv, rng, 60, (0.04, 0.10), (8.0, 14.0), 0.0, 0.05, (0.10, 0.22), (0.4, 0.7), 0.6, 0.0)
    return finish(cv, 0.35)


def kit_hemp(seed=12):
    """Coarse undyed hemp (leg wraps, fringe, ties): heavier slub streaks across, more value spread, a rough tooth."""
    rng = np.random.default_rng(seed)
    cv = Canvas()
    base(cv, rng, 0.08)
    layered(cv, rng, 40, (0.25, 0.45), (1.2, 2.0), 0.0, math.pi, (0.28, 0.55), (0.2, 0.4), 0.2, 1.0)
    layered(cv, rng, 800, (0.06, 0.18), (6.0, 12.0), 0.0, 0.06, (0.25, 0.62))
    layered(cv, rng, 250, (0.05, 0.10), (6.0, 10.0), math.pi / 2, 0.06, (0.25, 0.5), (0.25, 0.45))
    layered(cv, rng, 120, (0.04, 0.12), (8.0, 14.0), 0.0, 0.05, (0.70, 0.85), (0.5, 0.8), 0.6, 0.0)
    layered(cv, rng, 90, (0.04, 0.10), (8.0, 14.0), 0.0, 0.05, (0.05, 0.18), (0.4, 0.7), 0.6, 0.0)
    return finish(cv, 0.45)


def kit_felt(seed=13):
    """Felted wool and heavy cloth (mantles, oath robes): soft round glazes, no grain, a nap of short strokes."""
    rng = np.random.default_rng(seed)
    cv = Canvas()
    base(cv, rng, 0.08)
    layered(cv, rng, 160, (0.10, 0.25), (1.1, 1.8), 0.0, math.pi, (0.26, 0.55), (0.2, 0.45), 0.3, 1.0)
    layered(cv, rng, 900, (0.02, 0.05), (2.0, 4.0), math.pi / 2, 0.6, (0.28, 0.58), (0.25, 0.5))
    return finish(cv, 0.40)


def kit_leather(seed=14):
    """Tanned hide (straps, sandals, aprons): mottled glazes, darker creases, a few worn light scuffs."""
    rng = np.random.default_rng(seed)
    cv = Canvas()
    base(cv, rng, 0.10)
    layered(cv, rng, 140, (0.10, 0.28), (1.2, 2.4), 0.0, math.pi, (0.22, 0.58), (0.25, 0.5), 0.3, 1.0)
    layered(cv, rng, 120, (0.03, 0.08), (6.0, 12.0), 0.0, math.pi, (0.05, 0.2), (0.4, 0.7), 0.6, 0.0)
    layered(cv, rng, 90, (0.03, 0.08), (3.0, 8.0), 0.0, math.pi, (0.65, 0.8), (0.4, 0.7), 0.5, 0.0)
    return finish(cv, 0.45)


def kit_fur(seed=15):
    """Grey goat fur (the mantle's ruff): long locks down the tile (+V is down the hair), dark roots, light tips."""
    rng = np.random.default_rng(seed)
    cv = Canvas(fill=0.35)
    base(cv, rng, 0.08)
    n = cv.n
    for _ in range(700):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        L = rng.uniform(0.10, 0.22) * n
        th = math.pi / 2 + rng.uniform(-0.3, 0.3)
        cv.dab(x, y, L / 2, L / 2 / rng.uniform(6, 10), th, STOPS["dark"] + 0.08, 1.0, edge=0.4, alpha=0.7)
        cv.dab(x + math.cos(th) * L * 0.18, y + math.sin(th) * L * 0.18, L / 2.4, L / 2 / rng.uniform(7, 11), th,
               rng.uniform(0.38, 0.85), 0.5, edge=0.4, alpha=0.85)
    return finish(cv, 0.5)


def kit_straw(seed=16):
    """Woven split cane (baskets, hats): an over-under weave of 2 cm strips, each strip painted with a lit top edge."""
    rng = np.random.default_rng(seed)
    cv = Canvas(fill=0.10)
    n = cv.n
    k = 16                                         # strips across the 0.32 m tile: 2 cm
    s = n / k
    for i in range(k):
        for j in range(k):
            horiz = (i + j) % 2 == 0
            cx, cy = (j + 0.5) * s, (i + 0.5) * s
            val = float(np.clip(STOPS["mid"] + rng.normal(0.05, 0.08), 0.2, 0.9))
            if horiz:
                cv.dab(cx, cy, s * 0.62, s * 0.40, 0.0, val, 1.0, edge=0.85)
                cv.dab(cx, cy - s * 0.16, s * 0.55, s * 0.10, 0.0, STOPS["light"] + 0.05, 0.0)
            else:
                cv.dab(cx, cy, s * 0.40, s * 0.62, 0.0, val - 0.05, 1.0, edge=0.85)
                cv.dab(cx - s * 0.14, cy, s * 0.09, s * 0.52, 0.0, STOPS["light"], 0.0)
    strokes(cv, rng, 30, (0.15, 0.3), (1.2, 2.0), 0.0, math.pi, (0.4, 0.3, 0.3, 0.0), alpha=0.25)
    return finish(cv, 0.6)


def kit_cord(seed=17):
    """Twisted cord and braid (cords, tassels, ties): diagonal twist strokes."""
    rng = np.random.default_rng(seed)
    cv = Canvas()
    n = cv.n
    k = 24
    for i in range(k * 2):
        for j in range(k):
            x, y = (j + 0.5) * n / k, (i + 0.5) * n / (2 * k) + (j % 2) * n / (4 * k)
            cv.dab(x, y, n / k * 0.7, n / k * 0.22, 0.6, pick(rng, (0.1, 0.5, 0.35, 0.05)), 1.0)
            cv.dab(x - 2, y - 3, n / k * 0.5, n / k * 0.07, 0.6, STOPS["light"] + 0.1, 0.0)
    return finish(cv, 0.5)


def kit_metal(seed=18):
    """Cast bronze and gold (discs, fittings): broad smooth glazes from dark to light and a few bright scratches; the
    renderer adds the gloss."""
    rng = np.random.default_rng(seed)
    cv = Canvas(fill=0.45)
    base(cv, rng, 0.10)
    layered(cv, rng, 120, (0.15, 0.40), (1.5, 3.0), 0.3, 0.4, (0.25, 0.70), (0.25, 0.5), 0.3, 1.0)
    layered(cv, rng, 50, (0.04, 0.10), (8.0, 14.0), 0.3, 0.6, (0.8, 1.0), (0.4, 0.8), 0.6, 0.0)
    return finish(cv, 0.30)


def kit_bone(seed=19):
    """Bone, tooth and horn (beads, pins, teeth): smooth creamy glazes along the length, a few dark pores."""
    rng = np.random.default_rng(seed)
    cv = Canvas(fill=0.55)
    base(cv, rng, 0.08)
    layered(cv, rng, 200, (0.10, 0.30), (3.0, 6.0), math.pi / 2, 0.2, (0.40, 0.80), (0.2, 0.45), 0.3, 1.0)
    for _ in range(60):
        cv.dab(rng.uniform(0, N), rng.uniform(0, N), 1.8, 1.5, 0.0, STOPS["dark"] + 0.2, 0.0, alpha=0.6)
    return finish(cv, 0.3)


def kit_feather(seed=20):
    """A hawk feather card (alpha in the value map's own file: feather_alpha.png): a dark-barred vane round a pale
    shaft, painted along +V (tip at the top)."""
    rng = np.random.default_rng(seed)
    n = 256
    W, H = n, n * 4
    v = np.full((H, W), 0.4)
    a = np.zeros((H, W))
    ys, xs = np.mgrid[0:H, 0:W]
    t = ys / H                                     # 0 tip .. 1 quill
    half = (0.42 * np.sin(np.clip(t, 0, 0.82) / 0.82 * np.pi) ** 0.6) * W
    half = np.where(t > 0.82, half * np.clip((1.0 - t) / 0.18, 0, 1), half)
    dx = np.abs(xs - W / 2)
    a = (dx < half).astype(float)
    # barbs slant toward the tip; dark bars every 9% of the length (the hawk's barring)
    slant = (ys + dx * 0.7) / H
    bars = (np.sin(slant * 2 * np.pi * 11) > 0.35).astype(float)
    v = 0.55 - 0.45 * bars * (t < 0.8) + 0.1 * (dx / np.maximum(half, 1)) - 0.25 * (t > 0.82)
    v = np.where(dx < W * 0.025, 0.85, v)          # the shaft
    # ragged vane: a few splits
    for _ in range(9):
        y0 = rng.uniform(0.1, 0.75) * H
        sgn = rng.choice([-1, 1])
        cut = (np.abs(ys - (y0 - dx * 0.7)) < 3) & (sgn * (xs - W / 2) > 0) & (dx > W * 0.12)
        a[cut] = 0.0
    v = np.clip(v + (rng.random((H, W)) - 0.5) * 0.04, 0.02, 0.98)
    return v, a


KITS = {
    "weave": (kit_weave, 0.40, "homespun cotton and hemp cloth: vests, robes, trousers, skirts, panels"),
    "hemp": (kit_hemp, 0.32, "coarse undyed hemp: leg wraps, fringe strips, ties"),
    "felt": (kit_felt, 0.45, "felted wool and heavy cloth: mantles, oath robes"),
    "leather": (kit_leather, 0.40, "tanned hide: straps, sandals, aprons"),
    "fur": (kit_fur, 0.30, "goat fur: ruffs and shaggy edges"),
    "straw": (kit_straw, 0.32, "woven split cane and straw: baskets, hats"),
    "cord": (kit_cord, 0.10, "twisted cord and braid: cords, tassels"),
    "metal": (kit_metal, 0.20, "cast bronze, gold and silver: discs, fittings, pins"),
    "bone": (kit_bone, 0.10, "bone, tooth and horn: beads, teeth, pins"),
}


# ---- motif tiles ----------------------------------------------------------------------------------------------------
def _wobble(n, rng, amp):
    return (value_noise(n, 8, rng) - 0.5) * 2 * amp


def motif_band(seed=31, n=512):
    """band_motif, the Mountain Folk woven band (our ridge-and-ladder): across the tile, from the top: a bone line, a
    bone zigzag ridge between two indigo lines, a madder-ground strip of stepped terraces in bone, an ochre ladder
    (two lines and rungs: the tally of journeys), the ridge again, a bone line. Thread colours: R bone, G indigo-black,
    B ochre (the zone's own dye, madder, is the ground). Straight cuts only."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n] / n
    yw = y + _wobble(n, rng, 0.004)
    R = np.zeros((n, n))
    G = np.zeros((n, n))
    B = np.zeros((n, n))

    def line(y0, h):
        return (np.abs(yw - y0) < h / 2).astype(float)

    R += line(0.03, 0.025) + line(0.97, 0.025)
    G += line(0.075, 0.02) + line(0.245, 0.02) + line(0.755, 0.02) + line(0.925, 0.02)
    # zigzag ridges (period 1/8 across)
    for yc in (0.16, 0.84):
        tri = np.abs(((x * 8) % 1.0) - 0.5) * 2              # 0..1 triangle
        zz = yc - 0.05 + tri * 0.10
        R += (np.abs(yw - zz) < 0.017).astype(float)
    # stepped terraces in the middle strip: blocks stepping up and down, period 1/4
    ph = (x * 4) % 1.0
    step = np.floor(np.abs(ph - 0.5) * 2 * 4) / 4          # 0, .25, .5, .75 terraces
    top = 0.36 + step * 0.10
    R += ((yw > top) & (yw < top + 0.03) & (yw < 0.64)).astype(float)
    # the ladder: two lines and rungs every 1/16
    B += line(0.53, 0.018) + line(0.63, 0.018)
    rung = (np.abs(((x * 16) % 1.0) - 0.5) < 0.09) & (yw > 0.53) & (yw < 0.63)
    B += rung.astype(float)
    return _thread_paint(np.clip(R, 0, 1), np.clip(G, 0, 1), np.clip(B, 0, 1), rng)


def motif_quilting(seed=32, n=512):
    """quilting: the levy coat's quilting lines, a square lattice on the bias (stitch lines, R) with a stitch dot
    every 1/32 (G); for the cloth shader's seams-and-padding look."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n] / n
    u = (x + y) % 0.25
    v = (x - y) % 0.25
    R = ((np.minimum(u, 0.25 - u) < 0.006) | (np.minimum(v, 0.25 - v) < 0.006)).astype(float)
    dots = ((np.abs(((x + y) * 32) % 1.0 - 0.5) < 0.18) & (R > 0)).astype(float)
    return _thread_paint(R * 0.8, dots, np.zeros((n, n)), rng)


def motif_house(seed=33, n=512):
    """house_mark: a Stone Children guild band, a repeated straight-cut maker's mark (a square with a cross-cut
    corner and one tally) in rows between two lines. R the mark, G the lines."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n] / n
    G = ((np.abs(y - 0.1) < 0.015) | (np.abs(y - 0.9) < 0.015)).astype(float)
    cx = (x * 4) % 1.0
    cy = (y - 0.5) / 0.6 + 0.5
    sq = (np.maximum(np.abs(cx - 0.5), np.abs(cy - 0.5)) < 0.30) & (np.maximum(np.abs(cx - 0.5), np.abs(cy - 0.5)) > 0.22)
    diag = (np.abs((cx - 0.5) - (cy - 0.5)) < 0.04) & (np.abs(cx - 0.5) < 0.22)
    tally = (np.abs(cx - 0.85) < 0.025) & (np.abs(cy - 0.5) < 0.25)
    R = (sq | diag | tally).astype(float)
    return _thread_paint(R, G, np.zeros((n, n)), rng)


def motif_tide(seed=34, n=512):
    """tide_scroll (Dragon-Sea): stacked arcs, three nested half-rings in rows offset by half a repeat (one ring form
    only; no swirl, no spiral). R the arcs, G a fine line under each row."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n] / n
    R = np.zeros((n, n))
    for row in range(4):
        off = 0.125 * (row % 2)
        cy = (row + 1) * 0.25
        cx = ((x + off) * 4) % 1.0
        r = np.hypot(cx - 0.5, (y - cy) * 4 * 0.25 / 0.25)
        above = y < cy
        for rr in (0.18, 0.32, 0.46):
            R += ((np.abs(r - rr) < 0.035) & above & (np.abs(y - cy) < 0.2)).astype(float)
    G = (np.abs(((y * 4) % 1.0) - 0.0) < 0.012).astype(float)
    return _thread_paint(np.clip(R, 0, 1), G, np.zeros((n, n)), rng)


MOTIFS = {
    "band_motif": (motif_band, (0.12, 0.12), ["tv_bone", "tv_indigo_black", "tv_ochre"],
                   "Mountain Folk woven band: ridge zigzags, stepped terraces, a ladder of journeys; on a madder ground"),
    "quilting": (motif_quilting, (0.20, 0.20), ["tv_deep_navy", "tv_bone", "tv_bone"],
                 "the imperial levy coat's quilting lattice and stitches"),
    "house_mark": (motif_house, (0.16, 0.06), ["tv_quarry_white", "tv_charcoal", "tv_charcoal"],
                   "Stone Children guild band: a straight-cut maker's mark in rows"),
    "tide_scroll": (motif_tide, (0.16, 0.16), ["tv_pearl", "tv_sea_glass", "tv_sea_glass"],
                    "Dragon-Sea stacked arcs (one ring form; no swirl)"),
}


def _thread_paint(R, G, B, rng):
    """Masks made a little soft (0.8 px) with each thread's own value strokes in A of a second image: the motif's
    stroke variation is the weave map's, so the render multiplies the thread colour by it."""
    out = np.stack([torus_blur(np.clip(c, 0, 1), 0.8) for c in (R, G, B)], -1)
    return np.clip(out, 0, 1)


# ---- the check sheets ---------------------------------------------------------------------------------------------
def squint(v):
    """The squint test: 3x3 tiles at 1/2, and the 1/16 downscale blown back up beside it."""
    n = v.shape[0]
    img = Image.fromarray((v * 255).astype(np.uint8), "L")
    t = Image.new("L", (n * 3 // 2, n * 3 // 2))
    small = img.resize((n // 2, n // 2), Image.LANCZOS)
    for i in range(3):
        for j in range(3):
            t.paste(small, (i * n // 2, j * n // 2))
    sq = img.resize((n // 16, n // 16), Image.LANCZOS).resize((n * 3 // 2, n * 3 // 2), Image.BILINEAR)
    out = Image.new("L", (n * 3, n * 3 // 2))
    out.paste(t, (0, 0))
    out.paste(sq, (n * 3 // 2, 0))
    return out


def main():
    os.makedirs(os.path.join(OUT, "paint"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "motifs"), exist_ok=True)
    meta = {"format": "thuyvan-dress-paint", "version": 1,
            "note": "Value maps: grey = place on the zone dye's 4-stop ramp (0 dark, 0.40 mid, 0.75 light, 1.0 accent; "
                    "peoples_dyes.json ramps, cloth2 palette tv_*). Motifs: RGB = coverage of three thread dyes over the "
                    "zone's ground dye. Our own strokes and straight-cut marks; painted with numpy (no photographs, no "
                    "sheet pixels).",
            "stops": STOPS, "kits": {}, "motifs": {}}
    for name, (fn, tile, use) in KITS.items():
        v = fn()
        Image.fromarray((v * 255).astype(np.uint8), "L").save(os.path.join(OUT, "paint", name + ".png"))
        squint(v).save(os.path.join(OUT, "paint", name + "_check.png"))
        meta["kits"][name] = {"png": "res://assets/thuyvan/dress/paint/%s.png" % name, "tile_m": tile, "use": use,
                              "mean": round(float(v.mean()), 3)}
    v, a = kit_feather()
    rgba = np.stack([v, v, v, a], -1)
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "paint", "feather.png"))
    meta["kits"]["feather"] = {"png": "res://assets/thuyvan/dress/paint/feather.png", "tile_m": 0.0,
                               "use": "hawk feather card (value in RGB, the vane in A)"}
    for name, (fn, tile, colors, use) in MOTIFS.items():
        m = fn()
        Image.fromarray((m * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "motifs", name + ".png"))
        meta["motifs"][name] = {"png": "res://assets/thuyvan/dress/motifs/%s.png" % name, "tile_m": list(tile),
                                "threads": colors, "use": use}
    with open(os.path.join(OUT, "dress_paint.json"), "w") as f:
        json.dump(meta, f, indent=1, ensure_ascii=False)
    print("wrote", len(KITS) + 1, "value maps and", len(MOTIFS), "motifs to", OUT)


if __name__ == "__main__":
    main()
