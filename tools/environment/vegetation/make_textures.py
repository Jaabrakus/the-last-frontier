#!/usr/bin/env python3
"""Package C texture processing (python3 with numpy + PIL; deterministic, re-runnable).

    python3 tools/environment/vegetation/make_textures.py [only=bark,birch,props]

Writes into assets/environment/vegetation/bark/ and assets/environment/props/<asset>/:

  bark/bark_conifer_albedo_2k.png   bark_brown_02 graded for white pine / hemlock: darker,
                                     red-brown, moss toned down (target linear luminance ~0.075)
  bark/bark_hardwood_albedo_2k.png  bark_brown_02 graded for oak / maple: grey, ~0.095
  bark/bark_normal_2k.png           bark_brown_02 nor_gl, unchanged (OpenGL = Godot convention)
  bark/bark_arm_2k.png              bark_brown_02 arm (AO / roughness / metal), unchanged
  bark/birch_albedo_1k.png, birch_normal_1k.png, birch_arm_1k.png
                                     procedural paper-birch bark (1024 around x 2048 up, tiles in
                                     both directions): cream base <= 0.85 sRGB, horizontal
                                     lenticels, peeling strips, a few black branch-scar chevrons
  props/<id>/...                     1K copies of the Poly Haven prop textures, with the alpha
                                     masks rebuilt for the plants (see alpha_* below)
"""
import os, sys, json
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
PH = os.path.join(FRONTIER, 'assets', 'polyhaven')
OUT_VEG = os.path.join(FRONTIER, 'assets', 'environment', 'vegetation')
OUT_PROPS = os.path.join(FRONTIER, 'assets', 'environment', 'props')
# Contact sheets and other review images go outside res:// (Godot would import them).
SHEET = os.environ.get('VEG_SHEET', '/tmp/frontier_veg_alpha_recovery_sheet.png')


def load(path):
    return np.asarray(Image.open(path).convert('RGB')).astype(np.float32) / 255.0


def save(arr, path, mode=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    a = np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(a, mode).save(path, optimize=True)
    print('wrote', os.path.relpath(path, FRONTIER), a.shape)


def to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def lum(lin):
    return lin[..., 0] * 0.2126 + lin[..., 1] * 0.7152 + lin[..., 2] * 0.0722


def rgb_to_hsv(c):
    mx = c.max(-1)
    mn = c.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    i = m & (mx == r)
    h[i] = ((g - b)[i] / d[i]) % 6
    i = m & (mx == g) & (mx != r)
    h[i] = (b - r)[i] / d[i] + 2
    i = m & (mx == b) & (mx != r) & (mx != g)
    h[i] = (r - g)[i] / d[i] + 4
    h = h / 6.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return np.stack([h, s, mx], -1)


def hsv_to_rgb(hsv):
    h, s, v = hsv[..., 0] * 6.0, hsv[..., 1], hsv[..., 2]
    i = np.floor(h).astype(int) % 6
    f = h - np.floor(h)
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))
    out = np.zeros(h.shape + (3,), np.float32)
    for k, (a, b, c) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        m = i == k
        out[..., 0][m] = a[m]
        out[..., 1][m] = b[m]
        out[..., 2][m] = c[m]
    return out


# --- tileable value noise ---------------------------------------------------------------------

def value_noise(shape, cells, rng, octaves=4, persistence=0.5):
    """Tileable fBm value noise in [0,1]. cells = (cy, cx) lattice cells for the first octave."""
    h, w = shape
    total = np.zeros(shape, np.float32)
    amp, norm = 1.0, 0.0
    cy, cx = cells
    for o in range(octaves):
        g = rng.random((cy, cx)).astype(np.float32)
        ys = np.arange(h) * cy / h
        xs = np.arange(w) * cx / w
        y0 = np.floor(ys).astype(int)
        x0 = np.floor(xs).astype(int)
        fy = ys - y0
        fx = xs - x0
        fy = fy * fy * (3 - 2 * fy)
        fx = fx * fx * (3 - 2 * fx)
        y1 = (y0 + 1) % cy
        x1 = (x0 + 1) % cx
        y0 %= cy
        x0 %= cx
        a = g[y0][:, x0]
        b = g[y0][:, x1]
        c = g[y1][:, x0]
        d = g[y1][:, x1]
        fxx = fx[None, :]
        fyy = fy[:, None]
        n = (a * (1 - fxx) + b * fxx) * (1 - fyy) + (c * (1 - fxx) + d * fxx) * fyy
        total += n * amp
        norm += amp
        amp *= persistence
        cy *= 2
        cx *= 2
    return total / norm


def height_to_normal(hmap, strength):
    """OpenGL-convention normal map from a tileable height map (+Y = up in the image)."""
    dx = (np.roll(hmap, -1, 1) - np.roll(hmap, 1, 1)) * 0.5
    dy = (np.roll(hmap, 1, 0) - np.roll(hmap, -1, 0)) * 0.5   # image up = -row
    n = np.stack([-dx * strength, -dy * strength, np.ones_like(hmap)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


# --- bark ---------------------------------------------------------------------------------------

def bark():
    src = os.path.join(PH, 'textures', 'structures', 'bark_brown_02')
    d = load(os.path.join(src, 'bark_brown_02_diffuse_2k.jpg'))
    lin = to_lin(d)
    hsv = rgb_to_hsv(d)
    # Moss/lichen mask: green-yellow hues.
    green = np.clip(1 - np.abs(hsv[..., 0] - 0.2) / 0.08, 0, 1) * np.clip((hsv[..., 1] - 0.12) / 0.2, 0, 1)

    # Conifer: dark red-brown-grey, moss kept faintly (hemlock and pine carry little moss).
    c = hsv.copy()
    c[..., 1] = c[..., 1] * (1 - 0.65 * green) * 0.85
    c[..., 0] = c[..., 0] * (1 - green) + 0.07 * green
    conifer = to_lin(hsv_to_rgb(c)) * np.array([1.0, 0.86, 0.78], np.float32)
    conifer *= 0.075 / lum(conifer).mean()
    save(to_srgb(conifer), os.path.join(OUT_VEG, 'bark', 'bark_conifer_albedo_2k.png'))

    # Hardwood (oak, maple): grey, ridged; keep a little of the moss (north faces in reality).
    h = hsv.copy()
    h[..., 1] = h[..., 1] * (0.35 + 0.35 * green)
    hard = to_lin(hsv_to_rgb(h)) * np.array([0.98, 0.98, 0.97], np.float32)
    hard *= 0.095 / lum(hard).mean()
    save(to_srgb(hard), os.path.join(OUT_VEG, 'bark', 'bark_hardwood_albedo_2k.png'))

    for k, name in [('nor_gl', 'bark_normal_2k.png'), ('arm', 'bark_arm_2k.png')]:
        im = Image.open(os.path.join(src, 'bark_brown_02_%s_2k.jpg' % k)).convert('RGB')
        path = os.path.join(OUT_VEG, 'bark', name)
        im.save(path, optimize=True)
        print('wrote', os.path.relpath(path, FRONTIER))


def birch():
    rng = np.random.default_rng(1776)
    H, W = 2048, 1024          # rows = up the trunk (2 m), columns = around (1 circumference)
    base = value_noise((H, W), (8, 4), rng, 5)
    streak = value_noise((H, W), (64, 3), rng, 3)            # horizontal banding
    hmap = (base - 0.5) * 0.3 + (streak - 0.5) * 0.25
    col = np.zeros((H, W, 3), np.float32)
    cream = np.array([0.86, 0.84, 0.79], np.float32)
    grey = np.array([0.70, 0.69, 0.66], np.float32)
    pink = np.array([0.84, 0.72, 0.62], np.float32)
    t = np.clip((base - 0.35) * 2.0, 0, 1)[..., None]
    col[:] = cream * (1 - t * 0.5) + grey * (t * 0.5)
    col *= (0.93 + 0.07 * streak)[..., None]
    rough = np.full((H, W), 0.62, np.float32)
    ao = np.ones((H, W), np.float32)

    yy, xx = np.mgrid[0:H, 0:W]

    def wrap_box(y0, x0, h, w):
        ys = (np.arange(y0, y0 + h)) % H
        xs = (np.arange(x0, x0 + w)) % W
        return np.ix_(ys, xs)

    # Peeling strips: wide horizontal bands of slightly pinker, smoother bark with raised edges.
    for i in range(26):
        y = rng.integers(0, H)
        x = rng.integers(0, W)
        h = int(rng.integers(12, 40))
        w = int(rng.integers(90, 420))
        idx = wrap_box(y - h // 2, x - w // 2, h, w)
        ly = np.linspace(-1, 1, h)[:, None]
        lx = np.linspace(-1, 1, w)[None, :]
        shape = np.clip(1 - (np.abs(lx) ** 3), 0, 1) * np.clip(1 - np.abs(ly) ** 6, 0, 1)
        shape *= np.clip(1 - np.abs(ly + 0.2 * np.sin(lx * 7 + i)) ** 4, 0, 1)
        k = shape[..., None] * rng.uniform(0.35, 0.8)
        col[idx] = col[idx] * (1 - k) + pink * k
        edge = np.clip(1 - np.abs(np.abs(ly) - 0.85) * 8, 0, 1) * shape
        hmap[idx] += edge * 0.5 + shape * 0.15

    # Lenticels: thin dark horizontal dashes, clustered in bands.
    n_len = 2600
    for i in range(n_len):
        y = rng.integers(0, H)
        x = rng.integers(0, W)
        w = int(rng.integers(8, 70) * (1.5 if rng.random() < 0.15 else 1.0))
        h = int(rng.integers(2, 6))
        idx = wrap_box(y, x - w // 2, h, w)
        lx = np.linspace(-1, 1, w)[None, :]
        ly = np.linspace(-1, 1, h)[:, None]
        s = np.clip(1 - lx ** 2, 0, 1) ** 0.5 * np.clip(1 - ly ** 2, 0, 1) ** 0.7
        dark = rng.uniform(0.55, 0.85)
        k = (s * dark)[..., None]
        lc = np.array([0.20, 0.17, 0.15], np.float32) * rng.uniform(0.7, 1.3)
        col[idx] = col[idx] * (1 - k) + lc * k
        hmap[idx] -= s * 0.6
        rough[idx] = rough[idx] * (1 - s) + 0.85 * s
        ao[idx] *= 1 - 0.3 * s

    # Branch-scar chevrons: dark, rough inverted-V marks with a knot, a few per tile.
    for i in range(7):
        cy = rng.integers(0, H)
        cx = rng.integers(0, W)
        size = int(rng.integers(60, 140))
        h = size
        w = int(size * 2.2)
        idx = wrap_box(cy - h // 2, cx - w // 2, h, w)
        ly = np.linspace(-1, 1, h)[:, None]
        lx = np.linspace(-1, 1, w)[None, :]
        arm = np.abs(ly + 0.6 - np.abs(lx) * 0.9)          # the V's centre line
        thick = 0.18 * (1 - np.abs(lx)) + 0.04
        s = np.clip(1 - arm / thick, 0, 1) * (np.abs(lx) < 0.95)
        knot = np.clip(1 - ((lx * 2.2) ** 2 + ((ly + 0.55) * 1.4) ** 2), 0, 1)
        s = np.clip(np.maximum(s, knot) * 1.5, 0, 1)
        k = (s * 0.92)[..., None]
        col[idx] = col[idx] * (1 - k) + np.array([0.07, 0.06, 0.055], np.float32) * k
        hmap[idx] -= s * 0.8
        rough[idx] = rough[idx] * (1 - s) + 0.9 * s
        ao[idx] *= 1 - 0.35 * s

    # Fine vertical cracks / texture noise.
    fine = value_noise((H, W), (256, 128), rng, 2)
    hmap += (fine - 0.5) * 0.12
    col *= (0.96 + 0.08 * fine)[..., None]
    col = np.clip(col, 0, 0.85)                 # never above 0.85 sRGB (spec 2.2)
    lin = to_lin(col)
    print('birch albedo linear luminance mean %.3f (target <= 0.55)' % lum(lin).mean())
    # Downsample x2 for the 1K set? Keep 1024x2048 (1K around).
    save(col, os.path.join(OUT_VEG, 'bark', 'birch_albedo_1k.png'))
    save(height_to_normal(hmap, 6.0), os.path.join(OUT_VEG, 'bark', 'birch_normal_1k.png'))
    arm = np.stack([ao, rough, np.zeros_like(ao)], -1)
    save(arm, os.path.join(OUT_VEG, 'bark', 'birch_arm_1k.png'))


# --- props (Poly Haven models): 1K textures, rebuilt alpha ---------------------------------------

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def clean_mask(m, open_px=1, close_px=1):
    """Binary mask cleanup with PIL min/max filters (erode/dilate)."""
    im = Image.fromarray((m * 255).astype(np.uint8))
    for _ in range(close_px):
        im = im.filter(ImageFilter.MaxFilter(3))
    for _ in range(close_px + open_px):
        im = im.filter(ImageFilter.MinFilter(3))
    for _ in range(open_px):
        im = im.filter(ImageFilter.MaxFilter(3))
    return np.asarray(im).astype(np.float32) / 255.0


def dilate_rgb(rgb, alpha, threshold=0.5):
    """Push-pull fill of the RGB under transparent texels with the colour of the nearest opaque
    ones, so mipmaps and bilinear filtering never bleed the (meaningless) padding in."""
    valid = (alpha >= threshold).astype(np.float32)
    levels = []
    c = rgb * valid[..., None]
    w = valid.copy()
    while min(c.shape[0], c.shape[1]) > 1:
        levels.append((c, w))
        h2, w2 = c.shape[0] // 2, c.shape[1] // 2
        c = c[:h2 * 2, :w2 * 2].reshape(h2, 2, w2, 2, 3).sum((1, 3))
        w = w[:h2 * 2, :w2 * 2].reshape(h2, 2, w2, 2).sum((1, 3))
    filled = c / np.maximum(w, 1e-6)[..., None]
    for c, w in reversed(levels):
        up = np.repeat(np.repeat(filled, 2, 0), 2, 1)
        up = np.pad(up, ((0, c.shape[0] - up.shape[0]), (0, c.shape[1] - up.shape[1]), (0, 0)), mode='edge')
        own = c / np.maximum(w, 1e-6)[..., None]
        k = np.clip(w, 0, 1)[..., None]
        filled = own * k + up * (1 - k)
    return filled


def alpha_for(asset, diff, arm, nrm):
    if asset == 'fern_02':
        # ARM is pure yellow (AO 1, roughness 1) outside the fronds.
        a = (arm[..., 1] < 0.97).astype(np.float32)
        return clean_mask(a, 1, 1)
    if asset == 'shrub_04':
        # ARM is green with R (AO) = 0 outside the leaves and the twig.
        a = (arm[..., 0] > 0.1).astype(np.float32)
        return clean_mask(a, 1, 1)
    if asset == 'moss_01':
        return smoothstep(0.02, 0.08, diff.max(-1))
    if asset == 'shrub_02':
        # No mask channel: the padding is horizontal smear (every texel copies its row
        # neighbour), so texels whose horizontal detail vanishes are padding.
        g = diff.mean(-1)
        gx = np.abs(np.roll(g, -1, 1) - g)
        gy = np.abs(np.roll(g, -1, 0) - g)
        k = 9
        def box(x):
            im = Image.fromarray(np.clip(x * 255 * 8, 0, 255).astype(np.uint8))
            return np.asarray(im.filter(ImageFilter.BoxBlur(k))).astype(np.float32) / 255.0 / 8
        ratio = box(gx) / (box(gy) + 1e-3)
        a = (ratio > 0.45).astype(np.float32)
        return clean_mask(a, 3, 3)
    return None


PROP_TEXTURES = {
    # asset id: (maps, size, has alpha)
    'fern_02': (['diff', 'nor_gl', 'arm'], 1024, True),
    'shrub_04': (['diff', 'nor_gl', 'arm'], 1024, True),
    'tree_stump_01': (['diff', 'nor_gl', 'arm'], 1024, False),
    'tree_stump_02': (['diff', 'nor_gl', 'arm'], 1024, False),
    'dead_tree_trunk': (['diff', 'nor_gl', 'arm'], 1024, False),
    'dry_branches_medium_01': (['diff', 'nor_gl', 'arm'], 1024, False),
    'root_cluster_01': (['diff', 'nor_gl', 'arm'], 1024, False),
    'boulder_01': (['diff', 'nor_gl', 'arm'], 1024, False),
    'rock_moss_set_01': (['diff', 'nor_gl', 'rough'], 1024, False),
    'rock_moss_set_02': (['diff', 'nor_gl', 'rough'], 1024, False),
}


def props(only_assets=None):
    sheet = []
    for asset, (maps, size, has_alpha) in PROP_TEXTURES.items():
        if only_assets and asset not in only_assets:
            continue
        src = os.path.join(PH, 'models', asset, 'textures')
        imgs = {k: load(os.path.join(src, '%s_%s_2k.jpg' % (asset, k))) for k in maps}
        out = os.path.join(OUT_PROPS, asset)
        alpha = None
        if has_alpha:
            alpha = alpha_for(asset, imgs['diff'], imgs.get('arm'), imgs['nor_gl'])
        for k, arr in imgs.items():
            if k == 'rough':
                # Pack into an ORM ("arm") map: AO 1, roughness, metal 0.
                arr = np.stack([np.ones_like(arr[..., 0]), arr[..., 0], np.zeros_like(arr[..., 0])], -1)
                k = 'arm'
            if alpha is not None:
                arr = dilate_rgb(arr, alpha)
            im = Image.fromarray(np.clip(arr * 255 + 0.5, 0, 255).astype(np.uint8))
            if k == 'diff' and alpha is not None:
                a = Image.fromarray(np.clip(alpha * 255 + 0.5, 0, 255).astype(np.uint8))
                im.putalpha(a)
            im = im.resize((size, size), Image.LANCZOS)
            os.makedirs(out, exist_ok=True)
            name = '%s_%s_1k.png' % (asset, 'albedo' if k == 'diff' else ('normal' if k == 'nor_gl' else 'arm'))
            im.save(os.path.join(out, name), optimize=True)
            print('wrote', os.path.relpath(os.path.join(out, name), FRONTIER))
        if alpha is not None:
            # Contact sheet row: source diffuse | recovered mask | albedo over magenta.
            d = Image.fromarray((imgs['diff'] * 255).astype(np.uint8)).resize((384, 384))
            m = Image.fromarray((alpha * 255).astype(np.uint8)).convert('RGB').resize((384, 384))
            over = imgs['diff'] * alpha[..., None] + np.array([1, 0, 1], np.float32) * (1 - alpha[..., None])
            o = Image.fromarray((over * 255).astype(np.uint8)).resize((384, 384))
            sheet.append((asset, d, m, o))
    if sheet:
        W = 384 * 3
        im = Image.new('RGB', (W, 384 * len(sheet)))
        for r, (asset, d, m, o) in enumerate(sheet):
            im.paste(d, (0, r * 384))
            im.paste(m, (384, r * 384))
            im.paste(o, (768, r * 384))
        path = SHEET
        os.makedirs(os.path.dirname(path), exist_ok=True)
        im.save(path)
        print('wrote', path)


if __name__ == '__main__':
    only = None
    for a in sys.argv[1:]:
        if a.startswith('only='):
            only = a.split('=', 1)[1].split(',')
    if only is None or 'bark' in only:
        bark()
    if only is None or 'birch' in only:
        birch()
    if only is None or 'props' in only:
        props()
    for a in (only or []):
        if a in PROP_TEXTURES:
            props([a])
