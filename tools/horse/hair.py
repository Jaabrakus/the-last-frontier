"""Hair cards of the procedural horse: mane, forelock, tail and light fetlock feathering,
plus the strand texture they sample (generated with numpy; no image input).

A card is a strip of quads that follows a hair lock from its root: it starts on the skin,
bends under gravity and is pushed out of the body SDF so it lies on the neck (mane) or
falls clear of the quarters (tail). UV: u across the lock inside one atlas strip, v from 1
at the root to 0 at the tip. Cards are rendered two-sided with alpha scissor and
anisotropic highlights along the strands (assets/horse/materials/horse_hair.gdshader).

Horse (Blender armature) space: metres, z up, the horse faces -y, +x is its left.
"""

import math

import numpy as np

import anatomy as A
import sdf

K = np.asarray(A.K, float)
ATLAS_STRIPS = 4          # 0 dense locks, 1 loose wavy locks, 2 wisps, 3 short tufts


# ---------------------------------------------------------------------------
# Strand texture
# ---------------------------------------------------------------------------
def strand_atlas(W=1024, H=1024, seed=5):
    """RGBA float image (H, W, 4), rows bottom-up (v = (row + 0.5) / H): R strand
    brightness, G depth in the lock (0 inside .. 1 on top), B per-strand random, A coverage.
    The root is at the top (v = 1), the tip at the bottom."""
    rng = np.random.default_rng(seed)
    img = np.zeros((H, W, 4), np.float32)
    cov = np.zeros((H, W), np.float32)
    lum = np.zeros((H, W), np.float32)
    dep = np.zeros((H, W), np.float32)
    rnd = np.zeros((H, W), np.float32)
    sw = W // ATLAS_STRIPS
    rows = np.arange(H)
    v = (rows + 0.5) / H
    params = [  # strands, min length, width px, wave px, taper start
        (330, 0.55, 2.0, 3.0, 0.7),
        (260, 0.45, 1.9, 9.0, 0.55),
        (140, 0.35, 1.5, 12.0, 0.5),
        (260, 0.30, 1.8, 5.0, 0.4),
    ]
    for k, (ns, lmin, wpx, wave, tap) in enumerate(params):
        x_lo = k * sw
        for _ in range(ns):
            L = lmin + (1.0 - lmin) * rng.random() ** 0.7          # fraction of the height from the root
            x0 = x_lo + 6 + (sw - 12) * (0.5 + 0.5 * math.sin(math.pi * (rng.random() - 0.5)))
            edge = min(x0 - x_lo, x_lo + sw - x0) / (0.5 * sw)            # 0 at the strip edge .. 1 centre
            if rng.random() > 0.35 + 0.65 * edge:
                continue
            ph, fr = rng.random() * 6.28, 1.5 + 2.5 * rng.random()
            drift = (rng.random() - 0.5) * 0.06 * sw
            depth = rng.random()
            b = 0.55 + 0.45 * rng.random()
            r0 = 0.08 * rng.random() ** 2                             # ragged start below the root edge
            t = (1.0 - v - r0) / L                                    # 0 at the root .. 1 at the strand end
            live = (t >= 0) & (t <= 1)
            cx = x0 + drift * t + wave * np.sin(ph + fr * t * 3.14) * t
            w = wpx * np.where(t > tap, 1.0 - 0.8 * (t - tap) / (1 - tap), 1.0) * (0.7 + 0.6 * rng.random())
            for dx in range(-4, 5):
                xi = np.floor(cx).astype(int) + dx
                ok = live & (xi >= x_lo) & (xi < x_lo + sw)
                a = np.clip(1.0 - np.abs(xi + 0.5 - cx) / np.maximum(w * 0.5, 0.35), 0, 1) * ok
                r_, x_ = rows[ok], xi[ok]
                a = a[ok]
                old = cov[r_, x_]
                new = 1.0 - (1.0 - old) * (1.0 - a)
                wt = np.where(new > 0, a / np.maximum(new, 1e-6), 0)
                lum[r_, x_] = lum[r_, x_] * (1 - wt) + b * wt
                dep[r_, x_] = dep[r_, x_] * (1 - wt) + depth * wt
                rnd[r_, x_] = rnd[r_, x_] * (1 - wt) + rng.random() * wt
                cov[r_, x_] = new
    img[..., 0] = lum
    img[..., 1] = dep
    img[..., 2] = rnd
    img[..., 3] = np.clip(cov * 1.15, 0, 1)
    # fill colour under transparent texels (mip bleeding): the mean of the strip
    for k in range(ATLAS_STRIPS):
        sl = img[:, k * sw:(k + 1) * sw]
        m = sl[..., 3] > 0.2
        for c in range(3):
            ch = sl[..., c]
            ch[~m] = ch[m].mean() if m.any() else 0.5
    return img


# ---------------------------------------------------------------------------
# Card geometry
# ---------------------------------------------------------------------------
class Cards:
    def __init__(self):
        self.V, self.F, self.UV, self.N = [], [], [], []

    def add(self, path, wdir, width, strip, flip=False, taper=0.55):
        """path (n, 3) root..tip, wdir (n, 3) width direction, width (m)."""
        n = len(path)
        base = len(self.V)
        u0 = strip / ATLAS_STRIPS + 0.004
        u1 = (strip + 1) / ATLAS_STRIPS - 0.004
        for i, (p, w) in enumerate(zip(path, wdir)):
            t = i / (n - 1)
            hw = 0.5 * width * (1.0 - (1 - taper) * t)
            self.V += [tuple(p - w * hw), tuple(p + w * hw)]
            self.UV += [(u0, 1.0 - t), (u1, 1.0 - t)]
        for i in range(n - 1):
            a, b = base + 2 * i, base + 2 * i + 1
            q = (a, a + 2, b + 2, b) if not flip else (a, b, b + 2, a + 2)
            self.F.append(q)

    def arrays(self):
        return np.array(self.V, float), self.F, np.array(self.UV, float)


def _grad(node, p):
    g = sdf.gradient(node, np.asarray(p, float)[None, :])[0]
    return g / max(np.linalg.norm(g), 1e-9)


def _lock(node, root, d0, length, n, gravity, offset, rng, stiff=0.0, sway=None):
    """Hair lock path from root: initial direction d0, bent by gravity, kept `offset`
    outside the body."""
    step = length / (n - 1)
    p = np.array(root, float)
    d = np.asarray(d0, float) / np.linalg.norm(d0)
    pts = [p.copy()]
    for i in range(1, n):
        g = np.array([0, 0, -1.0]) * gravity * (0.6 + 0.8 * i / n)
        if sway is not None:
            g = g + sway
        d = d * (1 + stiff) + g
        d /= np.linalg.norm(d)
        p = p + d * step
        dist = float(node.f(*p[:, None]))
        if dist < offset:
            p = p + _grad(node, p) * (offset - dist)
        pts.append(p.copy())
    return np.array(pts)


def _crest(node, n=40):
    """Top of the neck at x = 0 from the withers to the poll (horse space)."""
    out = []
    for y in np.linspace(A.S((0, -0.60, 0))[1], A.S((0, -1.075, 0))[1], n):
        z = 1.9
        while z > 1.0 and node.f(np.array([0.0]), np.array([y]), np.array([z]))[0] > 0:
            z -= 0.002
        out.append((0.0, y, z))
    return np.array(out)


def mane(node, seed=11):
    """Mane lying mostly to the horse's right (-x): three layers of locks from the crest."""
    rng = np.random.default_rng(seed)
    C = Cards()
    crest = _crest(node)
    tang = np.gradient(crest, axis=0)
    tang /= np.linalg.norm(tang, axis=1)[:, None]
    L_tot = np.sum(np.linalg.norm(np.diff(crest, axis=0), axis=1))
    s_all = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(crest, axis=0), axis=1))])
    for layer, (count, off, lmin, lmax, strip_p) in enumerate(((44, 0.008, 0.24, 0.34, (0.7, 0.3, 0.0)),
                                                               (40, 0.018, 0.26, 0.38, (0.45, 0.4, 0.15)),
                                                               (30, 0.028, 0.16, 0.32, (0.0, 0.45, 0.55)))):
        for k in range(count):
            s = (k + rng.random() * 0.8 + 0.1) / count * L_tot
            i = int(np.searchsorted(s_all, s).clip(1, len(crest) - 1))
            root = crest[i] + np.array([0, 0, -0.004])
            t = tang[i]
            poll = s / L_tot                              # 0 withers .. 1 poll
            length = (lmin + (lmax - lmin) * rng.random()) * (1.0 - 0.3 * poll ** 2)
            left = rng.random() < (0.08 if layer < 2 else 0.18)
            sx = 1.0 if left else -1.0
            d0 = np.array([sx * 1.0, 0.15 * (rng.random() - 0.5), 0.25 * rng.random() - 0.1])
            path = _lock(node, root + np.array([sx * 0.006, 0, 0]), d0, length, 8, 1.1, off, rng,
                         sway=np.array([sx * 0.35, 0.0, 0.0]))
            # width along the crest, turned a little per lock so the card edges do not line up
            tw = t + (rng.random() - 0.5) * 0.5 * np.array([0.0, t[2], -t[1]])
            w = np.tile(tw / np.linalg.norm(tw), (len(path), 1))
            width = 0.07 + 0.035 * rng.random()
            strip = int(rng.choice(3, p=strip_p))
            # normal outward (+x on the left, -x on the right)
            C.add(path, w, width, strip, flip=left, taper=0.75)
    return C


def forelock(node, seed=12):
    rng = np.random.default_rng(seed)
    C = Cards()
    poll = np.array(A.S(A.hp(-0.035, 0.045)))
    for k in range(12):
        x = (rng.random() - 0.5) * 0.05
        root = poll + np.array([x, 0.0, 0.0])
        d0 = np.array(A.HEAD_AX) * np.array([1.0, A.KY, A.KZ]) + np.array([x * 2, 0, 0])
        length = 0.13 + 0.08 * rng.random()
        path = _lock(node, root, d0, length, 7, 0.10, 0.008 + 0.006 * (k % 2), rng, stiff=0.4)
        w = np.tile(np.array([1.0, 0, 0]), (len(path), 1))
        C.add(path, w, 0.035 + 0.015 * rng.random(), int(rng.choice([0, 1, 3])), flip=False)
    return C


TAIL_END_Z = 0.36          # tip of the tail hair above the ground (m): a long, full colonial tail


def tail(node, seed=13):
    """Locks from the dock (tail bones) hanging behind the quarters. The cards stand on a
    loose cone round the fall line (width tangential to it), so the tail has volume from
    every side; a few short locks cover the top of the dock."""
    rng = np.random.default_rng(seed)
    C = Cards()
    dock = np.array([A.S(p) for p in ((0, 0.675, 1.20), (0, 0.755, 1.125), (0, 0.80, 0.98), (0, 0.815, 0.84))])
    seg = np.linalg.norm(np.diff(dock, axis=0), axis=1)
    s_all = np.concatenate([[0], np.cumsum(seg)])
    for k in range(104):
        s = rng.random() ** 0.8 * s_all[-1] * 0.95
        i = int(np.searchsorted(s_all, s).clip(1, len(dock) - 1))
        f = (s - s_all[i - 1]) / seg[i - 1]
        c = dock[i - 1] * (1 - f) + dock[i] * f
        ax = (dock[i] - dock[i - 1]) / seg[i - 1]
        ang = (rng.random() - 0.5) * 2.0 * math.radians(140)       # round the dock, not underneath
        up = np.array([0, 0, 1.0]) - ax * ax[2]
        up /= np.linalg.norm(up)
        side = np.cross(ax, up)
        radial = up * math.cos(ang) + side * math.sin(ang)
        root = c + radial * 0.035
        short = k % 7 == 6                                  # short hair over the dock
        length = 0.12 + 0.12 * rng.random() if short else max(0.2, root[2] - TAIL_END_Z - 0.08 * rng.random())
        d0 = radial * 0.6 + ax * 0.6 + np.array([0, 0.25, -0.2])
        n = 10
        path = _lock(node, root, d0, length, n, 0.9, 0.025, rng)
        # the fall: out to a loose cone round the centre line, gathered again at the end
        phi = rng.random() * 2 * math.pi
        rad = np.array([math.cos(phi), math.sin(phi) * 0.8, 0.0])
        R = 0.02 + 0.07 * rng.random() ** 0.7
        ctr_y = dock[-1][1] + 0.05
        w = np.zeros((n, 3))
        for j in range(n):
            t = j / (n - 1)
            spread = R * math.sin(math.pi * min(1.0, t * 1.2)) ** 0.8 * (1 - 0.35 * t)
            path[j, 0] = path[j, 0] * (1 - t) + (rad[0] * spread) * t
            path[j, 1] = path[j, 1] * (1 - 0.7 * t) + (ctr_y + rad[1] * spread) * 0.7 * t
            w[j] = np.array([-rad[1], rad[0], 0.0])
        width = 0.05 + 0.04 * rng.random()
        C.add(path, w, width, int(rng.choice(3, p=(0.45, 0.35, 0.2))), flip=bool(rng.random() < 0.5), taper=0.7)
    return C


def feathers(node, seed=14):
    """Light feathering behind each fetlock: short tufts round the ergot. Returns
    {bone: Cards}."""
    rng = np.random.default_rng(seed)
    out = {}
    for s in ("l", "r"):
        m = (lambda p: np.asarray(p, float)) if s == "l" else (lambda p: np.asarray(A.mirror(p), float))
        for key, bone in (("f_fetlock", "pastern_" + s), ("h_fetlock", "hpastern_" + s)):
            C = Cards()
            ft = np.asarray(A.SL(m(np.asarray(A.J_BASE[key]) + (0, 0.054, -0.012))), float)
            for k in range(5):
                x = (k - 2) * 0.012
                root = ft + np.array([x, 0.0, 0.01 * rng.random()])
                d0 = np.array([x * 3, 0.5, -1.0])
                path = _lock(node, root, d0, 0.055 + 0.03 * rng.random(), 4, 0.6, 0.004, rng)
                w = np.tile(np.array([1.0, 0, 0]), (4, 1))
                C.add(path, w, 0.022 + 0.01 * rng.random(), 3, flip=False, taper=0.4)
            out[bone] = C
    return out
