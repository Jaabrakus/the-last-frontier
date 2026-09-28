"""Hand-painted look of the stylized face (lib v1 addition, 2026-09-26).

The stylized skin (assets/character/shaders/painted_skin.gdshader) is painted the way a
hand-painted game texture is: broad colour zones, soft painted light and shade, a few painted
highlights and lines, and almost no micro detail. The paint does not carry a skin colour: every
channel is a modulation of the look's own skin tone (melanin, undertone, blood), so one set of
maps serves every person and every people with the same rules.

Two maps in the head's UV space (lib/uv.py: u = arc length around the head, h = height; the
same coordinates as face_detail.gdshaderinc), baked from the stylized base head (body + `style`):

    paint_head.png   R  value: painted light and shade (0.5 = the skin's own value): a soft top
                        light on the forms, the hollows (eye sockets, under the brow, nose and
                        lower lip, under the jaw, the ear) darker, the lid margins and the mouth
                        line drawn a little darker
                     G  warm zone (cheeks, nose, ears, lids: the painter's red middle of the face)
                     B  cool zone (jaw, chin and upper lip: the lower third; the temples)
                     A  highlight (convex forms facing the light: brow ridge, nose bridge and tip,
                        cheekbones, chin, the top of the upper lip)
    paint_lines.png  R  painted expression lines (forehead, frown, crow's feet, under the eye,
                        nasolabial, chin), G their lit edge; the Complexion row sets how much
                     B  where the skin's cavity occlusion (body.glb COLOR_0.b, baked on the
                        realistic head) applies: 1 at the nostrils, the mouth, the ears and inside
                        the lids, 0 round the eyes outside the lids, where the stylized head has
                        smoothed away the realistic creases (cavity_mask)

The value map is laid down with a Kuwahara filter (flat painted patches with soft edges) and a
stroke texture that follows the forms (line integral convolution of noise along the value's
contours), so it reads as brushwork rather than a render bake.

The rest of the body gets the same painted value per vertex (body_paint: the Body mesh's
Region UV v; hands and neck): the concavity and the top light, no texture.

Everything is numpy (plus zlib for the PNGs): body.py calls bake() in Blender; the maps can be
re-baked from the cached source with plain python3 (tools/character/paint_bake.py).
"""

import math
import struct
import zlib

import numpy as np

from . import face as FC
from .sdf import smoothstep, v3
from .stylize import EYE_SCALE, STYLE_WARP

# texture space: u around the head (full circle of the uv.body_parts "head" segment, radius
# 0.08 m) x h (height)
HEAD_R = 0.08
U0, U1 = -math.pi * HEAD_R, math.pi * HEAD_R
H0, H1 = 1.335, 1.605
TEX_W, TEX_H = 1024, 512
LIGHT = np.array([0.0, -0.55, 0.84])          # the painted light: above and in front


# ---------------------------------------------------------------------------
# PNG (RGBA8) without Pillow (Blender's Python has none)
# ---------------------------------------------------------------------------
def write_png(path, rgba):
    a = np.clip(np.round(np.asarray(rgba, float) * 255.0), 0, 255).astype(np.uint8)
    h, w, c = a.shape
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    ct = {1: 0, 3: 2, 4: 6}[c]
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ct, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    return path


# ---------------------------------------------------------------------------
# mesh helpers
# ---------------------------------------------------------------------------
def vertex_normals(V, F):
    N = np.zeros_like(V)
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    for k in range(3):
        np.add.at(N, F[:, k], fn)
    return N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)


def edges_of(F):
    E = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    return np.unique(np.sort(E, axis=1), axis=0)


def laplace_smooth(X, E, iters, lam=0.5):
    X = np.asarray(X, float).copy()
    deg = np.maximum(np.bincount(E.ravel(), minlength=len(X)).astype(float), 1.0)[:, None]
    for _ in range(iters):
        acc = np.zeros_like(X)
        np.add.at(acc, E[:, 0], X[E[:, 1]])
        np.add.at(acc, E[:, 1], X[E[:, 0]])
        X += lam * (acc / deg - X)
    return X


def concavity(V, N, E, scales=(3, 12, 40)):
    """Signed concavity per vertex at a few smoothing scales (metres): > 0 in hollows (the
    smoothed surface lies outside), < 0 on ridges."""
    out = []
    X = np.asarray(V, float)
    done = 0
    S = X.copy()
    for k in scales:
        S = laplace_smooth(S, E, k - done)
        done = k
        out.append(((S - X) * N).sum(1))
    return out


def head_uv(V, headb_y):
    """(u, h) of the head segment (lib/uv.py body_parts): u = atan2(x, -(y - yc)) * 0.08."""
    q = V - v3(0, headb_y, 0)
    ang = np.arctan2(q[:, 0], -q[:, 1])
    return np.stack([ang * HEAD_R, V[:, 2]], 1)


# ---------------------------------------------------------------------------
# rasterizer (per-vertex attributes -> texture)
# ---------------------------------------------------------------------------
def rasterize(UVh, F, attrs, w=TEX_W, h=TEX_H):
    """Barycentric interpolation of per-vertex attrs (n, c) over the triangles F in (u, h) space.
    Returns (image (h, w, c), coverage mask)."""
    px = (UVh[:, 0] - U0) / (U1 - U0) * w
    py = (H1 - UVh[:, 1]) / (H1 - H0) * h
    img = np.zeros((h, w, attrs.shape[1]))
    cov = np.zeros((h, w), bool)
    for t in range(len(F)):
        i = F[t]
        xs = px[i].copy()
        ys = py[i]
        if xs.max() - xs.min() > w * 0.5:            # across the seam at the back: unwrap
            xs = np.where(xs < w * 0.5, xs + w, xs)
        for shift in ((0.0,) if xs.max() < w else (0.0, -w)):
            x = xs + shift
            x0, x1 = max(int(np.floor(x.min())), 0), min(int(np.ceil(x.max())), w - 1)
            y0, y1 = max(int(np.floor(ys.min())), 0), min(int(np.ceil(ys.max())), h - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            d = (ys[1] - ys[2]) * (x[0] - x[2]) + (x[2] - x[1]) * (ys[0] - ys[2])
            if abs(d) < 1e-12:
                continue
            b0 = ((ys[1] - ys[2]) * (gx - x[2]) + (x[2] - x[1]) * (gy - ys[2])) / d
            b1 = ((ys[2] - ys[0]) * (gx - x[2]) + (x[0] - x[2]) * (gy - ys[2])) / d
            b2 = 1.0 - b0 - b1
            ins = (b0 >= -0.02) & (b1 >= -0.02) & (b2 >= -0.02)
            if not ins.any():
                continue
            val = b0[..., None] * attrs[i[0]] + b1[..., None] * attrs[i[1]] + b2[..., None] * attrs[i[2]]
            sub = img[y0:y1 + 1, x0:x1 + 1]
            sub[ins] = val[ins]
            cov[y0:y1 + 1, x0:x1 + 1] |= ins
    return img, cov


def dilate(img, cov, iters=24):
    """Fills uncovered texels from their covered neighbours (no dark seams in the mips)."""
    img = img.copy()
    cov = cov.copy()
    for _ in range(iters):
        if cov.all():
            break
        acc = np.zeros_like(img)
        cnt = np.zeros(cov.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            s = np.roll(cov, (dy, dx), (0, 1))
            acc += np.roll(img, (dy, dx), (0, 1)) * s[..., None]
            cnt += s
        new = (~cov) & (cnt > 0)
        img[new] = acc[new] / cnt[new][:, None]
        cov |= new
    img[~cov] = img[cov].mean(0)
    return img


# ---------------------------------------------------------------------------
# painterly filters
# ---------------------------------------------------------------------------
def _box(a, r):
    """Mean over a (2r+1)^2 box (wrapping in u, clamped in h)."""
    p = np.pad(a, ((r, r), (0, 0)), mode="edge")
    c = np.cumsum(np.pad(p, ((1, 0), (0, 0))), 0)
    a1 = (c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1)
    p = np.concatenate([a1[:, -r:], a1, a1[:, :r]], 1)
    c = np.cumsum(np.pad(p, ((0, 0), (1, 0))), 1)
    return (c[:, 2 * r + 1:] - c[:, :-2 * r - 1]) / (2 * r + 1)


def blur(a, r, passes=3):
    for _ in range(passes):
        a = _box(a, r)
    return a


def kuwahara(a, r):
    """Kuwahara filter of a 2-D map: each texel takes the mean of the least varied of its four
    (r+1)^2 quadrants: flat patches with crisp-soft edges (painted), gradients kept."""
    m = _box(a, r // 2)
    m2 = _box(a * a, r // 2)
    var = m2 - m * m
    h = r // 2 + 1
    shifts = [(-h, -h), (-h, h), (h, -h), (h, h)]
    best = np.full(a.shape, np.inf)
    out = a.copy()
    for dy, dx in shifts:
        mv = np.roll(np.roll(m, dy, 0), dx, 1)
        vv = np.roll(np.roll(var, dy, 0), dx, 1)
        sel = vv < best
        best[sel] = vv[sel]
        out[sel] = mv[sel]
    return out


def lic(noise, vx, vy, steps=10, step=1.0):
    """Line integral convolution of `noise` along the unit field (vx, vy): strokes."""
    h, w = noise.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    acc = noise.copy()
    tot = np.ones_like(noise)
    for sgn in (1.0, -1.0):
        x, y = xx.copy(), yy.copy()
        for k in range(steps):
            xi = np.mod(np.round(x).astype(int), w)
            yi = np.clip(np.round(y).astype(int), 0, h - 1)
            x = x + sgn * vx[yi, xi] * step
            y = y + sgn * vy[yi, xi] * step
            xi = np.mod(np.round(x).astype(int), w)
            yi = np.clip(np.round(y).astype(int), 0, h - 1)
            wgt = 1.0 - k / steps
            acc += noise[yi, xi] * wgt
            tot += wgt
    return acc / tot


# ---------------------------------------------------------------------------
# the paint
# ---------------------------------------------------------------------------
def _gauss(V, c, r):
    return np.exp(-np.sum(((V - c) / np.asarray(r, float)) ** 2, 1) * 0.5)


def _frontmost(V, sel):
    """The vertex of V[sel] furthest forward (-y)."""
    idx = np.nonzero(sel)[0]
    return V[idx[np.argmin(V[idx, 1])]]


def vertex_paint(V, F, E, K, mucosa, sex_delta=None):
    """Per-vertex paint attributes of the stylized head (V: the stylized base head): value, warm,
    cool, highlight (0..1). The value is a soft form light from the painter's light (above and in
    front) and a little shade in the small hollows (the eye sockets under the brow, the nostrils,
    under the nose and the lower lip, the mouth corners, the ear); the broad forms are left to the
    game's own lights (no painted shadow blotches). Highlights and warm zones are placed on the
    head's landmarks, measured on the stylized head."""
    N = vertex_normals(V, F)
    c1, c2 = concavity(V, N, E, scales=(3, 10))
    L = LIGHT / np.linalg.norm(LIGHT)
    ndl = N @ L
    light = smoothstep(-0.4, 1.0, ndl)
    occ = np.clip(c1 / 0.0007, 0, 1) * 0.5 + np.clip(c2 / 0.0022, 0, 1) * 0.5
    front = smoothstep(-0.03, -0.07, V[:, 1])
    tip = _frontmost(V, (np.abs(V[:, 0]) < 0.003) & (V[:, 2] > 1.43) & (V[:, 2] < 1.47))
    chin = _frontmost(V, (np.abs(V[:, 0]) < 0.004) & (V[:, 2] > 1.37) & (V[:, 2] < 1.41))
    sto = FC.mouth_landmarks(K)["stomion"]
    # the painted shade of the hollows only at the features (eyes, nose, mouth, ears), never as
    # blotches on the broad planes of the cheeks and jaw
    hb = _v(K, "headb")
    feat = np.maximum(_gauss(V, tip + v3(0, 0.008, -0.004), (0.016, 0.014, 0.012)),
                      _gauss(V, sto, (0.024, 0.016, 0.014)))
    for s in (1, -1):
        feat = np.maximum(feat, _gauss(V, FC.eye_center(K, s) + v3(0, -0.008, 0.002), (0.018, 0.014, 0.014)))
        feat = np.maximum(feat, _gauss(V, v3(s * 0.073, hb[1] + 0.004, hb[2] + 0.016), (0.014, 0.018, 0.024)))
    value = 0.5 + 0.12 * (light - 0.6) - 0.16 * occ * np.clip(feat * 1.6, 0, 1)
    for s in (1, -1):
        c = FC.eye_center(K, s)
        # the eye socket: a soft painted shade under the brow and round the upper lid
        value -= 0.10 * _gauss(V, c + v3(s * 0.002, -0.010, 0.006), (0.016, 0.012, 0.009)) * front
        t, el, r, az = FC.eye_local(V, c, s)
        # the stylized margins (lib/stylize.py opens the lids a little; the eye scale keeps angles)
        up, lo = FC.margins(t, FC.add(FC.FACE_BASE, STYLE_WARP))
        near = smoothstep(FC.EYE_R * EYE_SCALE + 0.0080, FC.EYE_R * EYE_SCALE + 0.0035, r) * smoothstep(1.25, 0.9, np.abs(t))
        # a bold painted lash line on the upper lid (the stylized eye's frame), fuller toward the
        # outer corner; a faint one under the lower lid
        value -= 0.40 * np.exp(-((el - up - 1.6) / 3.4) ** 2) * near * (0.55 + 0.45 * smoothstep(-0.5, 0.8, t))
        value -= 0.10 * np.exp(-((el - lo + 1.2) / 3.0) ** 2) * near * smoothstep(-0.9, 0.2, t)
    # the mouth line
    mw = FC.FACE_BASE["mouth_w"]
    dm = np.abs(V[:, 2] - (sto[2] - 0.04 * np.abs(V[:, 0])))
    value -= 0.18 * np.exp(-(dm / 0.0012) ** 2) * smoothstep(mw + 0.004, mw - 0.004, np.abs(V[:, 0])) \
        * (V[:, 1] < sto[1] + 0.012)
    # under the jaw: the neck in the jaw's shade (soft)
    value -= 0.08 * smoothstep(-0.2, -0.8, N[:, 2]) * smoothstep(1.34, 1.37, V[:, 2]) * smoothstep(1.405, 1.385, V[:, 2]) \
        * smoothstep(-0.02, -0.06, V[:, 1])
    # colour zones (the painter's thirds): a rosy middle (cheeks, nose, ears), a faint cool lower third
    warm = np.zeros(len(V))
    for s in (1, -1):
        # the blush on the apple of the cheek: below and outside the eye (not a band under it)
        warm = np.maximum(warm, 0.55 * _gauss(V, v3(s * 0.043, -0.100, 1.440), (0.013, 0.016, 0.011)))
        warm = np.maximum(warm, 0.6 * _gauss(V, v3(s * 0.073, hb[1] + 0.004, hb[2] + 0.016), (0.010, 0.014, 0.018)))
        c = FC.eye_center(K, s)
        warm = np.maximum(warm, 0.15 * _gauss(V, c + v3(0, -0.008, 0.004), (0.012, 0.010, 0.005)))
    warm = np.maximum(warm, 0.7 * _gauss(V, tip + v3(0, 0.004, 0), (0.009, 0.010, 0.009)))
    warm = np.maximum(warm, 0.3 * _gauss(V, chin + v3(0, 0.004, 0), (0.010, 0.008, 0.007)))
    cool = smoothstep(1.425, 1.395, V[:, 2]) * smoothstep(-0.03, -0.07, V[:, 1]) * 0.5
    cool = np.maximum(cool, 0.45 * _gauss(V, sto + v3(0, -0.002, 0.011), (0.016, 0.012, 0.0055)))   # upper lip
    cool *= (1.0 - mucosa) * (1.0 - warm)
    warm *= 1.0 - 0.6 * mucosa
    # painted highlights on the landmarks, where they face the light
    lit = smoothstep(0.2, 0.85, ndl)
    high = np.zeros(len(V))
    nas = _frontmost(V, (np.abs(V[:, 0]) < 0.003) & (V[:, 2] > 1.48) & (V[:, 2] < 1.495))
    seg = tip - nas
    tt = np.clip((V - nas) @ seg / (seg @ seg), 0, 1)
    dd = np.linalg.norm(V - (nas + tt[:, None] * seg), axis=1)
    high = np.maximum(high, 0.8 * np.exp(-(dd / 0.0028) ** 2) * smoothstep(0.0, 0.25, tt))       # nose bridge
    high = np.maximum(high, 0.9 * _gauss(V, tip + v3(0, 0, 0.002), (0.004, 0.004, 0.0035)))      # tip
    high = np.maximum(high, 0.55 * _gauss(V, v3(0, -0.126, 1.518), (0.022, 0.012, 0.012)))        # forehead
    for s in (1, -1):
        high = np.maximum(high, 0.6 * _gauss(V, v3(s * 0.047, -0.100, 1.466), (0.010, 0.012, 0.007)))  # cheekbone
        high = np.maximum(high, 0.45 * _gauss(V, v3(s * 0.030, -0.120, 1.505), (0.012, 0.010, 0.005)))  # brow
    high = np.maximum(high, 0.6 * _gauss(V, chin + v3(0, 0.001, 0.003), (0.008, 0.006, 0.006)))  # chin
    # the upper lip's top (cupid's bow) and the lower lip's centre catch a little light
    high = np.maximum(high, 0.35 * np.exp(-((V[:, 2] - (sto[2] + 0.0082)) / 0.0012) ** 2)
                      * smoothstep(0.012, 0.004, np.abs(V[:, 0])) * (V[:, 1] < sto[1]))
    high = np.maximum(high, 0.35 * mucosa * _gauss(V, sto + v3(0, -0.003, -0.0045), (0.007, 0.01, 0.0025)))
    high *= lit
    return np.stack([np.clip(value, 0, 1), np.clip(warm, 0, 1), np.clip(cool, 0, 1), np.clip(high, 0, 1)], 1)


def _v(K, n):
    return np.asarray(K[n], float)


def _uvp(p, headb_y):
    q = np.asarray(p, float) - v3(0, headb_y, 0)
    return np.array([math.atan2(q[0], -q[1]) * HEAD_R, p[2]])


def _to_px(uh):
    return np.array([(uh[0] - U0) / (U1 - U0) * TEX_W, (H1 - uh[1]) / (H1 - H0) * TEX_H])


def _stroke(img, pts, width, amount, lit=None, lit_amount=0.0, lit_off=1.2):
    """Draws a soft polyline (texture px) into img[..., 0] (dark) and img[..., 1] (its lit edge,
    offset up by lit_off px)."""
    h, w = img.shape[:2]
    P = np.asarray(pts, float)
    x0, y0 = np.floor(P.min(0) - width * 3).astype(int)
    x1, y1 = np.ceil(P.max(0) + width * 3).astype(int)
    x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, w - 1), min(y1, h - 1)
    gy, gx = np.mgrid[y0:y1 + 1, x0:x1 + 1].astype(float)
    gx += 0.5
    gy += 0.5

    def dist(ox, oy):
        best = np.full(gx.shape, np.inf)
        tt = np.zeros(gx.shape)
        L = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))])
        for i in range(len(P) - 1):
            a, b = P[i], P[i + 1]
            ab = b - a
            t = np.clip(((gx - ox - a[0]) * ab[0] + (gy - oy - a[1]) * ab[1]) / max(ab @ ab, 1e-9), 0, 1)
            d = np.hypot(gx - ox - a[0] - t * ab[0], gy - oy - a[1] - t * ab[1])
            m = d < best
            best[m] = d[m]
            tt[m] = (L[i] + t[m] * np.linalg.norm(ab)) / max(L[-1], 1e-9)
        return best, tt
    d, t = dist(0.0, 0.0)
    taper = np.sin(np.pi * np.clip(t, 0, 1)) ** 0.6
    v = np.exp(-(d / (width * (0.35 + 0.65 * taper))) ** 2) * amount * taper
    img[y0:y1 + 1, x0:x1 + 1, 0] = np.maximum(img[y0:y1 + 1, x0:x1 + 1, 0], v)
    if lit_amount > 0:
        d2, t2 = dist(0.0, -lit_off)
        taper2 = np.sin(np.pi * np.clip(t2, 0, 1)) ** 0.6
        v2 = np.exp(-(d2 / (width * 0.9)) ** 2) * lit_amount * taper2
        img[y0:y1 + 1, x0:x1 + 1, 1] = np.maximum(img[y0:y1 + 1, x0:x1 + 1, 1], v2)


def lines_map(K):
    """Painted expression lines (R dark, G lit edge) in texture space, from the rig's landmarks."""
    img = np.zeros((TEX_H, TEX_W, 4))
    img[..., 3] = 1.0
    hy = _v(K, "headb")[1]

    def P(x, y, z):
        return _to_px(_uvp(v3(x, y, z), hy))
    for s in (1, -1):
        c = FC.eye_center(K, s)
        # crow's feet: three short lines fanning from the outer corner
        for k, ang in enumerate((-22.0, 0.0, 22.0)):
            a = math.radians(ang)
            p0 = c + v3(s * 0.0165, -0.004, 0.0)
            p1 = p0 + v3(s * 0.011 * math.cos(a), 0.004, 0.011 * math.sin(a))
            _stroke(img, [P(*p0), P(*((p0 + p1) / 2 + v3(0, 0, 0.0008))), P(*p1)], 1.3, 0.55, lit_amount=0.35)
        # under the eye: a soft curve below the lower lid
        pts = [P(*(c + v3(s * dx, -0.010 + 0.004 * abs(dx) / 0.016, -0.0125 - 0.0035 * math.cos(dx / 0.016 * 1.4))))
               for dx in np.linspace(-0.006, 0.016, 7)]
        _stroke(img, pts, 1.4, 0.45, lit_amount=0.25)
        # nasolabial: from the side of the ala down past the mouth corner
        pts = [P(s * 0.019, -0.119, 1.4475), P(s * 0.024, -0.116, 1.438), P(s * 0.028, -0.112, 1.428),
               P(s * 0.031, -0.108, 1.417)]
        _stroke(img, pts, 1.6, 0.6, lit_amount=0.3)
        # frown line between the brows
        _stroke(img, [P(s * 0.0055, -0.126, 1.496), P(s * 0.0065, -0.127, 1.507)], 1.1, 0.45)
    # forehead: two long, slightly waving lines above the brows
    for hz in (1.515, 1.523):
        pts = [P(x, -0.12, hz + 0.0012 * math.cos(x / 0.035 * math.pi)) for x in np.linspace(-0.034, 0.034, 9)]
        _stroke(img, pts, 1.2, 0.45, lit_amount=0.3)
    # the chin crease
    pts = [P(x, -0.12, 1.4025 + 8.0 * x * x) for x in np.linspace(-0.011, 0.011, 5)]
    _stroke(img, pts, 1.5, 0.35)
    return img


def cavity_mask(V, K):
    """Per vertex of the stylized head: 1 where the realistic cavity occlusion still belongs (the
    lid margins and the pocket inside them, and everywhere away from the eyes), 0 on the skin round
    the eyes outside the lids (the realistic head's lower-lid and lateral-canthus creases, which the
    stylized head smooths away, read as dark painted crescents)."""
    V = np.asarray(V, float)
    m = np.ones(len(V))
    for s in (1, -1):
        r = np.linalg.norm(V - FC.eye_center(K, s), axis=1)
        re = FC.EYE_R * EYE_SCALE
        m = np.minimum(m, np.maximum(smoothstep(re + 0.0045, re + 0.0030, r), smoothstep(re + 0.024, re + 0.032, r)))
    return m


def bake_maps(Vbase, Vsty, F, K, mucosa, head_tris, seed=7):
    """Returns (paint_head RGBA float image, paint_lines RGBA) for the triangles `head_tris`."""
    rng = np.random.default_rng(seed)
    E = edges_of(F)
    attrs = np.concatenate([vertex_paint(Vsty, F, E, K, mucosa), cavity_mask(Vsty, K)[:, None]], 1)
    hy = _v(K, "headb")[1]
    UVh = head_uv(Vbase, hy)
    img, cov = rasterize(UVh, F[head_tris], attrs)
    img = dilate(img, cov, 64)
    cmask = blur(img[..., 4], 1, 2)
    img = img[..., :4]
    val = img[..., 0]
    # painted patches (Kuwahara) and strokes along the forms: the stroke direction follows the
    # contours of the broad value (blurred), turning to a plain downward stroke where the value is
    # flat (no swirls)
    val = blur(kuwahara(blur(val, 1, 1), 4), 2, 2)
    gy, gx = np.gradient(blur(img[..., 0], 10))
    mag = np.hypot(gx, gy)
    t = smoothstep(0.0004, 0.002, mag)
    vx = -gy / np.maximum(mag, 1e-9) * t + 0.25 * (1 - t)
    vy = gx / np.maximum(mag, 1e-9) * t + 0.97 * (1 - t)
    n = np.maximum(np.hypot(vx, vy), 1e-9)
    vx, vy = vx / n, vy / n
    noise = blur(rng.random(val.shape), 1, 1)
    strokes = lic(noise, vx, vy, steps=8, step=1.0)
    strokes = (strokes - strokes.mean()) / max(strokes.std(), 1e-6)
    strokes = np.clip(strokes, -2.5, 2.5)
    val = val + 0.006 * strokes
    warm = blur(img[..., 1], 3) * (1.0 + 0.05 * strokes)
    cool = blur(img[..., 2], 3) * (1.0 + 0.05 * strokes)
    high = blur(img[..., 3], 2, 2)
    head = np.stack([np.clip(val, 0, 1), np.clip(warm, 0, 1), np.clip(cool, 0, 1), np.clip(high, 0, 1)], -1)
    lines = lines_map(K)
    lines[..., 0] = np.clip(blur(lines[..., 0], 1, 1) * (1.0 + 0.15 * strokes), 0, 1)
    lines[..., 1] = np.clip(blur(lines[..., 1], 1, 1), 0, 1)
    lines[..., 2] = np.clip(cmask, 0, 1)
    return head, lines


def source_path():
    import os
    return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "cache", "paint_src_v1.npz")


def save_source(Vbase, Vsty, F, mucosa, head_tris, K):
    """The inputs of bake_maps (tools/character/cache/paint_src_v1.npz), so the maps can be
    re-baked with plain python3 (tools/character/paint_bake.py) without rebuilding the body."""
    names = sorted(K.P) if hasattr(K, "P") else sorted(K)
    np.savez_compressed(source_path(), Vbase=np.asarray(Vbase, np.float64), Vsty=np.asarray(Vsty, np.float64),
                        F=np.asarray(F, np.int32), mucosa=np.asarray(mucosa, np.float32),
                        head_tris=np.asarray(head_tris, bool), k_names=np.array(names),
                        k_pos=np.array([np.asarray(K[n], float) for n in names]))


def load_source():
    z = np.load(source_path())
    K = {str(n): p for n, p in zip(z["k_names"], z["k_pos"])}
    return z["Vbase"], z["Vsty"], z["F"], z["mucosa"], z["head_tris"], K


def body_paint(V, F, E=None):
    """Per-vertex painted value of the whole body (0.5 neutral): the hollows at two scales
    (between the fingers, the knuckle creases, the neck under the jaw) darker, a soft top light."""
    E = edges_of(F) if E is None else E
    N = vertex_normals(V, F)
    c1, c2 = concavity(V, N, E, scales=(3, 12))
    light = smoothstep(-0.6, 1.0, N @ np.array([0.0, -0.3, 0.95]))
    occ = np.clip(c1 / 0.0008, 0, 1) * 0.45 + np.clip(c2 / 0.0025, 0, 1) * 0.45
    return np.clip(0.5 + 0.14 * (light - 0.6) - 0.22 * occ, 0, 1)
