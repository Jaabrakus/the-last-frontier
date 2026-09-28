#!/usr/bin/env python3
"""Structure textures for the Frontier fort (look-dev spec, section 8; package D).

Reads the CC0 Poly Haven sources in assets/polyhaven/textures/structures (read-only) and writes
processed copies and procedural textures to assets/environment/structures/textures/:

  bark_palisade_{albedo,nor_gl,arm}_2k      bark_brown_02, albedo graded (palisade logs, round
                                            log backs, flag pole, chopping block)
  boards_weathered_{albedo,nor_gl,arm}_2k   brown_planks_07: four clean board rows (the lap
                                            grooves cut out), silvered. UV row k = [k/4, (k+1)/4]
  shingles_riven_{albedo,nor_gl,arm}_2k     riven shingles built from roof_planks board grain:
                                            8 courses of 0.35 m over a 2.8 m tile
  fieldstone_{albedo,nor_gl,arm}_2k         stacked_stone_wall, desaturated and brightened
  straw_fibre_{albedo,nor_gl,arm}_1k        procedural straw (trusses)
  straw_fibre_grey_1k                       the same, neutral grey (tinted by the dummy's colour)
  wool_twill_{grey,nor_gl}_512              procedural wool twill (dummy coats, flag)
  structure_noise_512                       RGBA tileable noise for the weathering shader:
                                            R broad fbm, G medium fbm, B vertical streaks, A grain

Deterministic (fixed seeds) and re-runnable:  python3 tools/environment/structures/process_textures.py
Linear-luminance targets (spec 13): bark 0.06-0.12, weathered wood 0.15-0.25, stone 0.12-0.22.
"""
import json
import os
import shutil

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SRC = os.path.join(ROOT, "assets", "polyhaven", "textures", "structures")
OUT = os.path.join(ROOT, "assets", "environment", "structures", "textures")
REPORT = {}


# --- helpers -----------------------------------------------------------------------------

def load(name, kind):
    return np.asarray(Image.open(os.path.join(SRC, name, f"{name}_{kind}_2k.jpg")).convert("RGB")).astype(np.float32) / 255.0


def to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


def lum(lin):
    return lin[..., 0] * 0.2126 + lin[..., 1] * 0.7152 + lin[..., 2] * 0.0722


def save(arr, name, mode="RGB"):
    a = np.clip(arr, 0.0, 1.0)
    img = Image.fromarray((a * 255.0 + 0.5).astype(np.uint8)).convert(mode)
    path = os.path.join(OUT, name)
    img.save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT), img.size)


def grade(srgb, sat=1.0, target_lum=None, value=1.0, tint=(1.0, 1.0, 1.0)):
    """Grade in linear space: saturation around luminance, then scale to a mean linear
    luminance (or by `value`), then a per-channel tint."""
    lin = to_lin(srgb)
    l = lum(lin)[..., None]
    lin = l + (lin - l) * sat
    lin = lin * np.array(tint, np.float32)
    if target_lum is not None:
        lin *= target_lum / max(float(lum(lin).mean()), 1e-6)
    lin *= value
    return to_srgb(lin), float(lum(lin).mean())


def periodic_noise(n, lo, hi, seed, aniso=(1.0, 1.0)):
    """Tileable band-limited noise in [0, 1] (white noise filtered in the frequency domain).
    lo/hi: radial frequency band in cycles per tile; aniso scales (fx, fy) before the band test
    (aniso=(1, 8) keeps low vertical frequencies only -> vertical streaks)."""
    rng = np.random.default_rng(seed)
    w = rng.standard_normal((n, n))
    f = np.fft.fft2(w)
    fy = np.fft.fftfreq(n)[:, None] * n * aniso[1]
    fx = np.fft.fftfreq(n)[None, :] * n * aniso[0]
    r = np.sqrt(fx * fx + fy * fy)
    band = np.exp(-((np.log2(np.maximum(r, 1e-3)) - np.log2(np.sqrt(lo * hi))) ** 2) / (2 * (0.5 * np.log2(hi / lo) + 0.5) ** 2))
    band[0, 0] = 0.0
    out = np.real(np.fft.ifft2(f * band))
    out = (out - out.mean()) / (out.std() + 1e-9)
    return np.clip(0.5 + out * 0.18, 0.0, 1.0)


def fbm(n, base, octaves, seed, aniso=(1.0, 1.0)):
    acc = np.zeros((n, n), np.float32)
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        f = base * (2 ** o)
        acc += amp * (periodic_noise(n, f * 0.7, f * 1.4, seed + o, aniso) - 0.5)
        tot += amp
        amp *= 0.5
    return np.clip(0.5 + acc / tot * 1.6, 0.0, 1.0)


def blur(a, sigma):
    """Periodic gaussian blur through the FFT (tileable)."""
    n0, n1 = a.shape[:2]
    fy = np.fft.fftfreq(n0)[:, None]
    fx = np.fft.fftfreq(n1)[None, :]
    g = np.exp(-2 * (np.pi ** 2) * (sigma ** 2) * (fx * fx + fy * fy))
    if a.ndim == 2:
        return np.real(np.fft.ifft2(np.fft.fft2(a) * g))
    return np.stack([np.real(np.fft.ifft2(np.fft.fft2(a[..., c]) * g)) for c in range(a.shape[2])], -1)


def normal_from_height(h, strength):
    """OpenGL-convention normal map (green up) from a tileable height field (pixels)."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    # Image rows go down; OpenGL normal maps have +Y up, so the v slope flips.
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def decode_normal(img):
    n = img * 2.0 - 1.0
    return n


def encode_normal(n):
    n = n / np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def resize(arr, w, h):
    """Bicubic resize of a float image (channels last)."""
    chans = []
    a = arr if arr.ndim == 3 else arr[..., None]
    for c in range(a.shape[2]):
        im = Image.fromarray(a[..., c].astype(np.float32)).resize((w, h), Image.BICUBIC)
        chans.append(np.asarray(im))
    out = np.stack(chans, -1)
    return out if arr.ndim == 3 else out[..., 0]


# --- 1. bark (palisade logs) -------------------------------------------------------------

def bark():
    d = load("bark_brown_02", "diffuse")
    # Slightly less yellow-green, a touch greyer: weathered palisade bark (#7A6A58 sunlit).
    g, l = grade(d, sat=0.82, tint=(1.04, 0.99, 0.97), target_lum=0.105)
    save(g, "bark_palisade_albedo_2k.png")
    for k in ("nor_gl", "arm"):
        shutil.copyfile(os.path.join(SRC, "bark_brown_02", f"bark_brown_02_{k}_2k.jpg"),
                        os.path.join(OUT, f"bark_palisade_{k}_2k.jpg"))
        print("copied", f"bark_palisade_{k}_2k.jpg")
    REPORT["bark_palisade"] = {"source": "bark_brown_02", "lin_lum": l, "sat": 0.82}


# --- 2. weathered boards ------------------------------------------------------------------

# Flat board faces in brown_planks_07 (rows of the 2048 px tile between the lap grooves and
# their shadow ramps; found from the diffuse/normal row profiles).
BOARD_ROWS = [(285, 525), (715, 970), (1160, 1398), (1915, 2150)]


def boards():
    d = load("brown_planks_07", "diffuse")
    n = load("brown_planks_07", "nor_gl")
    arm = load("brown_planks_07", "arm")
    rows_d, rows_n, rows_a = [], [], []
    for a, b in BOARD_ROWS:
        idx = np.arange(a, b) % 2048
        sd, sn, sa = d[idx], n[idx], arm[idx]
        rows_d.append(resize(sd, 2048, 512))
        nn = decode_normal(resize(sn, 2048, 512))
        nn[..., 1] *= (b - a) / 512.0      # stretched across the grain: flatter v slopes
        rows_n.append(encode_normal(nn))
        rows_a.append(resize(sa, 2048, 512))
    D = np.concatenate(rows_d, 0)
    N = np.concatenate(rows_n, 0)
    A = np.concatenate(rows_a, 0)
    # Even out the brightness of the four rows (the variation comes from vertex tints).
    lin = to_lin(D)
    for k in range(4):
        sl = slice(k * 512, (k + 1) * 512)
        lin[sl] *= float(lum(to_lin(D)).mean()) / max(float(lum(lin[sl]).mean()), 1e-6)
    D = to_srgb(lin)
    # Weathered grain: long streaks along the board (u) and sparse dark checks (drying cracks).
    rng = np.random.default_rng(1779)
    streak = fbm(2048, 3, 4, 505, aniso=(14.0, 1.0))
    streak = np.concatenate([streak[:, :] for _ in range(1)], 0)
    lin = to_lin(D)
    lin *= (0.84 + 0.32 * streak)[..., None]
    hgt = (streak - 0.5) * 0.6
    for k in range(260):
        y = int(rng.integers(0, 2048))
        if (y % 512) < 30 or (y % 512) > 482:
            continue
        x0 = int(rng.integers(0, 2048))
        L = int(rng.integers(60, 700))
        xs = (x0 + np.arange(L)) % 2048
        wob = (np.sin(np.arange(L) / rng.uniform(40, 120)) * rng.uniform(0, 3)).astype(int)
        ys = np.clip(y + wob, 0, 2047)
        depth = rng.uniform(0.35, 0.7)
        lin[ys, xs] *= depth
        lin[np.clip(ys + 1, 0, 2047), xs] *= 0.5 + depth * 0.5
        hgt[ys, xs] -= 0.8
    D = to_srgb(lin)
    nn = decode_normal(N)
    hn = decode_normal(normal_from_height(blur(hgt, 0.8) * 6.0, 1.0))
    nn[..., :2] += hn[..., :2]
    N = encode_normal(nn)
    # Silvered, weathered hewn wood (#8C8274 sunlit): strong desaturation, slight warm grey.
    g, l = grade(D, sat=0.55, tint=(1.04, 1.0, 0.94), target_lum=0.18)
    # Keep the texture AO but soften it (edges come from geometry / vertex AO).
    A[..., 0] = 0.55 + 0.45 * A[..., 0]
    A[..., 1] = np.clip(A[..., 1] * 0.95, 0.6, 1.0)
    save(g, "boards_weathered_albedo_2k.png")
    save(N, "boards_weathered_nor_gl_2k.png")
    save(A, "boards_weathered_arm_2k.png")
    REPORT["boards_weathered"] = {"source": "brown_planks_07", "rows_px": BOARD_ROWS, "lin_lum": l, "sat": 0.55,
                                  "layout": "4 rows of 512 px; row k covers v in [k/4,(k+1)/4]; u tile = 1 m"}


# --- 3. riven shingles --------------------------------------------------------------------

ROOF_COLS = [(79, 105), (246, 272), (413, 444), (585, 614), (755, 789), (930, 957), (1099, 1130),
             (1271, 1299), (1441, 1475), (1615, 1643), (1784, 1815), (1956, 1985)]


def shingles():
    rng = np.random.default_rng(1777)
    src = load("roof_planks", "diffuse")
    # Desaturate 60 % and darken to silver-brown before cutting shingles out of the grain.
    src, _ = grade(src, sat=0.2, tint=(1.03, 1.0, 0.93), target_lum=0.15)
    src_n = decode_normal(load("roof_planks", "nor_gl"))
    N = 2048
    COURSES = 8
    ch = N // COURSES                      # 256 px = 0.35 m
    px_per_m = N / 2.8
    albedo = np.zeros((N, N, 3), np.float32)
    height = np.zeros((N, N), np.float32)
    ao = np.ones((N, N), np.float32)
    rough = np.zeros((N, N), np.float32)
    # Board flats between the gaps of roof_planks (vertical grain).
    flats = []
    for i in range(len(ROOF_COLS)):
        a = ROOF_COLS[i][1] + 8
        b = ROOF_COLS[(i + 1) % len(ROOF_COLS)][0] - 8 + (2048 if i == len(ROOF_COLS) - 1 else 0)
        flats.append((a, b))
    grain = fbm(N, 6, 3, 91, aniso=(1.0, 10.0))       # riven ridges along the grain
    yy = np.arange(ch)[:, None] / (ch - 1.0)
    for c in range(COURSES):
        y0 = c * ch
        widths = []
        while sum(widths) < N:
            widths.append(int(rng.uniform(0.10, 0.24) * px_per_m))
        excess = sum(widths) - N
        widths[-1] -= excess
        if widths[-1] < 50:
            widths[-2] += widths[-1]
            widths.pop()
        x = 0
        for w in widths:
            gap = int(rng.integers(3, 7))
            fa, fb = flats[int(rng.integers(0, len(flats)))]
            fw = fb - fa
            sx = int(rng.integers(0, 2048))
            cols = (fa + (np.arange(w - gap) * (fw / max(w - gap, 1))).astype(int)) % 2048
            rows = (sx + np.arange(ch) * 1) % 2048
            patch = src[rows][:, cols]
            tint = rng.uniform(0.9, 1.1)
            warm = rng.uniform(-0.03, 0.03)
            if rng.random() < 0.1:
                tint *= 0.78                      # older, darker shingle
            elif rng.random() < 0.05:
                tint *= 1.18                      # newer replacement
            patch = patch * tint * np.array([1 + warm, 1.0, 1 - warm], np.float32)
            # Ragged, slightly slanted butt: the bottom few pixels of the shingle are cut away
            # (they show the course below, in the butt's shadow).
            cut = (rng.uniform(0, 7) + rng.uniform(-5, 5) * (np.arange(w - gap) / max(w - gap, 1) - 0.5)
                   + rng.uniform(0, 2.5, w - gap)).astype(int)
            cut = np.clip(cut, 0, 12)
            short = np.arange(ch)[:, None] >= (ch - cut)[None, :]
            # Butt end a little darker (weathering) and a few split cracks.
            patch *= (0.92 + 0.08 * (1.0 - yy))[..., None] ** 0.5
            xs = (x + np.arange(w - gap)) % N
            albedo[y0:y0 + ch][:, xs] = patch
            # Thickness: thin at the top (under the course above) to thick at the butt.
            tilt = rng.uniform(-0.15, 0.15)
            ramp = 0.25 + 0.75 * yy + tilt * (np.arange(w - gap)[None, :] / max(w - gap, 1) - 0.5) * 0.4
            hh = ramp + 0.12 * (grain[y0:y0 + ch][:, xs] - 0.5)
            hh = np.where(short, 0.1, hh)
            height[y0:y0 + ch][:, xs] = hh
            blk = albedo[y0:y0 + ch][:, xs]
            albedo[y0:y0 + ch][:, xs] = np.where(short[..., None], blk * 0.3, blk)
            rough[y0:y0 + ch][:, xs] = rng.uniform(0.82, 0.95)
            if rng.random() < 0.3:                # a split crack
                cx = int(rng.integers(3, max(4, w - gap - 3)))
                cl = int(rng.integers(ch // 3, ch))
                xc = (x + cx) % N
                albedo[y0 + ch - cl:y0 + ch, xc] *= 0.45
                height[y0 + ch - cl:y0 + ch, xc] -= 0.15
            gx = (x + w - gap + np.arange(gap)) % N
            albedo[y0:y0 + ch][:, gx] = albedo[y0:y0 + ch][:, (x + w - gap - 1) % N][:, None] * 0.25
            height[y0:y0 + ch][:, gx] = 0.0
            ao[y0:y0 + ch][:, gx] = 0.35
            rough[y0:y0 + ch][:, gx] = 1.0
            x += w
        # Shadow under the butt of the course above.
        shade = 1.0 - 0.45 * np.exp(-yy / 0.08)
        ao[y0:y0 + ch] *= shade
        albedo[y0:y0 + ch] *= (0.75 + 0.25 * shade)[..., None]
        # Random horizontal offset per course (joints never line up).
        sh = int(rng.integers(0, N))
        for arr in (albedo, height, ao, rough):
            arr[y0:y0 + ch] = np.roll(arr[y0:y0 + ch], sh, 1)
    height = blur(height, 1.2)
    nrm = normal_from_height(height * 28.0, 1.0)
    # Add the fine grain of the source normal map (vertical, fibrous).
    nn = decode_normal(nrm)
    nn[..., :2] += src_n[..., :2] * 0.6
    nrm = encode_normal(nn)
    arm = np.stack([ao, np.clip(rough, 0, 1), np.zeros_like(ao)], -1)
    lin_l = float(lum(to_lin(albedo)).mean())
    save(albedo, "shingles_riven_albedo_2k.png")
    save(nrm, "shingles_riven_nor_gl_2k.png")
    save(arm, "shingles_riven_arm_2k.png")
    REPORT["shingles_riven"] = {"source": "roof_planks (grain)", "lin_lum": lin_l, "tile_m": 2.8, "courses": COURSES,
                                "course_m": 0.35, "layout": "course k covers v in [k/8,(k+1)/8]; v runs down-slope; butt at the bottom"}


# --- 4. fieldstone --------------------------------------------------------------------------

def fieldstone():
    d = load("stacked_stone_wall", "diffuse")
    g, l = grade(d, sat=0.3, tint=(1.04, 1.0, 0.93), target_lum=0.15)
    save(g, "fieldstone_albedo_2k.png")
    for k in ("nor_gl", "arm"):
        shutil.copyfile(os.path.join(SRC, "stacked_stone_wall", f"stacked_stone_wall_{k}_2k.jpg"),
                        os.path.join(OUT, f"fieldstone_{k}_2k.jpg"))
        print("copied", f"fieldstone_{k}_2k.jpg")
    REPORT["fieldstone"] = {"source": "stacked_stone_wall", "lin_lum": l, "sat": 0.3}


# --- 5. straw -------------------------------------------------------------------------------

def straw():
    rng = np.random.default_rng(1778)
    N = 1024
    height = np.zeros((N, N), np.float32)
    col = np.zeros((N, N), np.float32)
    col[:] = 0.08
    for i in range(5200):
        x0, y0 = rng.uniform(0, N, 2)
        L = rng.uniform(60, 380)
        ang = rng.normal(0.0, 0.13)
        w = rng.uniform(1.2, 3.6)
        bright = rng.uniform(0.55, 1.0) if rng.random() > 0.08 else rng.uniform(0.25, 0.45)
        t = np.arange(0, L, 0.7)
        off = np.arange(-np.ceil(w), np.ceil(w) + 1)
        xs = x0 + np.cos(ang) * t[:, None] - np.sin(ang) * off[None, :]
        ys = y0 + np.sin(ang) * t[:, None] + np.cos(ang) * off[None, :]
        prof = np.sqrt(np.clip(1.0 - (off / w) ** 2, 0.0, 1.0))[None, :]
        base = (i / 5200.0) * 0.6          # later strands lie on top
        hv = (base + 0.4 * prof) * np.ones_like(xs)
        xi = xs.astype(int) % N
        yi = ys.astype(int) % N
        flat = yi * N + xi
        hflat = height.reshape(-1)
        cflat = col.reshape(-1)
        upd = hv.reshape(-1) > hflat[flat.reshape(-1)]
        idx = flat.reshape(-1)[upd]
        hflat[idx] = hv.reshape(-1)[upd]
        # Nodes and a slight darkening toward strand ends.
        shade = bright * (0.85 + 0.15 * np.sin(t / L * np.pi))[:, None] * np.ones_like(off)[None, :]
        cflat[idx] = shade.reshape(-1)[upd]
    height = blur(height, 0.8)
    col = blur(col, 0.6)
    grey = np.clip(0.22 + 0.8 * col, 0, 1)
    hue = fbm(N, 5, 2, 1779)
    # Golden straw for the trusses (some strands paler, some greyer): linear luminance ~0.28.
    straw_rgb = np.stack([grey * (0.98 + 0.02 * hue), grey * (0.80 + 0.08 * hue), grey * (0.45 + 0.15 * hue)], -1)
    g, l = grade(straw_rgb, target_lum=0.28)
    save(g, "straw_fibre_albedo_1k.png")
    # Dummy straw: neutral, with deep gaps between strands (the dummy's own colour tints it).
    gd = np.clip((grey - 0.25) / 0.75, 0, 1) ** 1.2 * 0.85 + 0.15
    save(np.stack([gd] * 3, -1), "straw_fibre_grey_1k.png")
    save(normal_from_height(height * 10.0, 1.0), "straw_fibre_nor_gl_1k.png")
    ao = np.clip(0.45 + 0.7 * (height - height.min()) / (np.ptp(height) + 1e-6), 0, 1)
    save(np.stack([ao, np.full_like(ao, 0.9), np.zeros_like(ao)], -1), "straw_fibre_arm_1k.png")
    REPORT["straw_fibre"] = {"source": "procedural", "lin_lum": l}


# --- 6. wool twill ------------------------------------------------------------------------

def wool():
    N = 512
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    period = 8.0
    twill = 0.5 + 0.5 * np.sin((x + y) * 2 * np.pi / period)
    weft = 0.5 + 0.5 * np.sin(y * 2 * np.pi / (period / 2))
    fuzz = fbm(N, 24, 3, 17)
    slub = fbm(N, 4, 2, 23, aniso=(1.0, 6.0))
    h = 0.55 * twill + 0.2 * weft + 0.35 * fuzz + 0.2 * slub
    grey = np.clip(0.72 + 0.18 * (h - h.mean()) + 0.12 * (slub - 0.5), 0, 1)
    save(np.stack([grey] * 3, -1), "wool_twill_grey_512.png")
    save(normal_from_height(blur(h, 0.7) * 3.0, 1.0), "wool_twill_nor_gl_512.png")
    REPORT["wool_twill"] = {"source": "procedural"}


# --- 7. weathering noise --------------------------------------------------------------------

def noise():
    N = 512
    r = fbm(N, 2, 4, 101)
    g = fbm(N, 8, 3, 202)
    b = fbm(N, 3, 3, 303, aniso=(1.0, 12.0))     # vertical streaks (low vertical frequency)
    a = periodic_noise(N, 40, 120, 404)
    save(np.stack([r, g, b, a], -1), "structure_noise_512.png", "RGBA")
    REPORT["structure_noise"] = {"source": "procedural", "channels": "R broad fbm, G medium fbm, B vertical streaks, A grain"}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    bark()
    boards()
    shingles()
    fieldstone()
    straw()
    wool()
    noise()
    with open(os.path.join(OUT, "grading_report.json"), "w") as f:
        json.dump(REPORT, f, indent=1)
    print(json.dumps(REPORT, indent=1))
