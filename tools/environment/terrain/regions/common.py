"""Generic helpers for the region baker (bake_region.py, recipes_thuyvan.py, relief_views.py).

Noise, fbm, smoothstep, smin, blur, bilinear, to_u8 and the polyline and segment distances are COPIES of the ones in
tools/environment/terrain/bake_terrain.py (the frontier baker, by the same rules: numpy only, fixed seeds, world-position
functions). They are copied, not imported, because importing bake_terrain.py loads the frontier's
data/world/squares.json at import time. Keep the copies identical to the originals so a region square and a frontier
square made from the same seed read the same noise.

New here: nearest_on_polyline(), the exact nearest point of a long sampled centre line (a channel's), found block by block
so a square's million samples test only the few segments that can be nearest.
"""
import math

import numpy as np


# --- Noise (bake_terrain.py) ---------------------------------------------------------------------

class Perlin:
    """2D gradient noise in [-1, 1]; optionally periodic (period in lattice cells)."""

    def __init__(self, seed, period=None):
        rng = np.random.default_rng(seed)
        self.perm = rng.permutation(256).astype(np.int64)
        ang = rng.random(256) * 2.0 * np.pi
        self.gx = np.cos(ang)
        self.gz = np.sin(ang)
        self.period = period

    def _h(self, ix, iz):
        if self.period:
            ix = ix % self.period
            iz = iz % self.period
        return self.perm[(self.perm[ix & 255] + iz) & 255]

    def __call__(self, x, z):
        x = np.asarray(x, np.float64)
        z = np.asarray(z, np.float64)
        xi = np.floor(x).astype(np.int64)
        zi = np.floor(z).astype(np.int64)
        xf = x - xi
        zf = z - zi

        def g(dx, dz, ox, oz):
            h = self._h(xi + ox, zi + oz)
            return self.gx[h] * (xf - ox) + self.gz[h] * (zf - oz)

        u = xf * xf * xf * (xf * (xf * 6.0 - 15.0) + 10.0)
        v = zf * zf * zf * (zf * (zf * 6.0 - 15.0) + 10.0)
        n00 = g(0, 0, 0, 0)
        n10 = g(0, 0, 1, 0)
        n01 = g(0, 0, 0, 1)
        n11 = g(0, 0, 1, 1)
        a = n00 + (n10 - n00) * u
        b = n01 + (n11 - n01) * u
        return np.clip((a + (b - a) * v) * 1.4142, -1.0, 1.0)


_noise_cache = {}


def noise(seed):
    if seed not in _noise_cache:
        _noise_cache[seed] = Perlin(seed)
    return _noise_cache[seed]


def fbm(x, z, lam, octaves, seed, gain=0.5):
    total = np.zeros(np.broadcast(x, z).shape)
    amp = 1.0
    norm = 0.0
    f = 1.0 / lam
    for o in range(octaves):
        total += amp * noise(seed * 31 + o)(x * f + 17.3 * o, z * f - 9.1 * o)
        norm += amp
        amp *= gain
        f *= 2.0
    return total / norm


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def smin(a, b, k):
    """Smooth minimum (exactly the lower where they differ by more than k)."""
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1.0 - h) + a * h - k * h * (1.0 - h)


# --- Geometry (bake_terrain.py) ------------------------------------------------------------------

def polyline_distance(x, z, pts):
    d = np.full(np.broadcast(x, z).shape, 1e9)
    for (ax, az), (bx, bz) in zip(pts[:-1], pts[1:]):
        vx, vz = bx - ax, bz - az
        l2 = vx * vx + vz * vz
        t = np.clip(((x - ax) * vx + (z - az) * vz) / l2, 0.0, 1.0)
        d = np.minimum(d, np.hypot(x - (ax + t * vx), z - (az + t * vz)))
    return d


def segment_distance(x, z, a, b):
    return polyline_distance(x, z, [tuple(a), tuple(b)])


def blur(a, sigma):
    """Separable Gaussian blur with edge clamping."""
    r = int(math.ceil(sigma * 3.0))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    p = np.pad(a, r, mode="edge")
    out = np.zeros_like(p)
    for i, w in enumerate(k):
        out[:, r:-r] += w * p[:, i:i + p.shape[1] - 2 * r]
    p2 = out[:, r:-r]
    out = np.zeros((p.shape[0], a.shape[1]))
    for i, w in enumerate(k):
        out[r:-r] += w * p2[i:i + p.shape[0] - 2 * r]
    return out[r:-r]


def bilinear(arr, x, z, x0, z0, res=1.0):
    """Sample a grid array (row j = z) at world (x, z); (x0, z0) is sample [0, 0]."""
    fx = np.clip((x - x0) / res, 0, arr.shape[1] - 1.001)
    fz = np.clip((z - z0) / res, 0, arr.shape[0] - 1.001)
    i = np.floor(fx).astype(np.int64)
    j = np.floor(fz).astype(np.int64)
    u = fx - i
    v = fz - j
    a = arr[j, i] * (1 - u) + arr[j, i + 1] * u
    b = arr[j + 1, i] * (1 - u) + arr[j + 1, i + 1] * u
    return a * (1 - v) + b * v


def to_u8(a):
    return np.clip(np.round(a * 255.0), 0, 255).astype(np.uint8)


# --- Nearest point on a long polyline -------------------------------------------------------------

def nearest_on_polyline(X, Z, px, pz, block=64):
    """For every (X, Z) (2D arrays, the same shape): the nearest point of the polyline (px, pz): its segment, t (0..1)
    and the signed distance (+ on the right of the polyline's direction, as water_net's offset). Exact: in each block
    of block x block samples only the segments within the block's nearest distance plus its diagonal can be nearest.
    Ties go to the lowest segment, whichever block a sample falls in, so two squares agree on their shared edge."""
    ax, az = px[:-1], pz[:-1]
    dx, dz = px[1:] - ax, pz[1:] - az
    L2 = dx * dx + dz * dz
    L = np.sqrt(L2)
    seg = np.zeros(X.shape, dtype=np.int64)
    tt = np.zeros(X.shape)
    off = np.zeros(X.shape)
    H, W = X.shape
    for j0 in range(0, H, block):
        for i0 in range(0, W, block):
            xs = X[j0:j0 + block, i0:i0 + block]
            zs = Z[j0:j0 + block, i0:i0 + block]
            cx = 0.5 * (xs.min() + xs.max())
            cz = 0.5 * (zs.min() + zs.max())
            r = 0.5 * math.hypot(xs.max() - xs.min(), zs.max() - zs.min())
            tc = np.clip(((cx - ax) * dx + (cz - az) * dz) / L2, 0.0, 1.0)
            dc = np.hypot(cx - (ax + tc * dx), cz - (az + tc * dz))
            cand = np.flatnonzero(dc <= dc.min() + 2.0 * r + 1e-6)
            qx = xs.reshape(-1, 1)
            qz = zs.reshape(-1, 1)
            cax, caz, cdx, cdz = ax[cand][None, :], az[cand][None, :], dx[cand][None, :], dz[cand][None, :]
            t = np.clip(((qx - cax) * cdx + (qz - caz) * cdz) / L2[cand][None, :], 0.0, 1.0)
            ex = qx - (cax + t * cdx)
            ez = qz - (caz + t * cdz)
            d2 = ex * ex + ez * ez
            k = np.argmin(d2, axis=1)
            rows = np.arange(len(k))
            sg = cand[k]
            side = ex[rows, k] * (-dz[sg] / L[sg]) + ez[rows, k] * (dx[sg] / L[sg])
            dist = np.sqrt(d2[rows, k])
            shp = xs.shape
            seg[j0:j0 + block, i0:i0 + block] = sg.reshape(shp)
            tt[j0:j0 + block, i0:i0 + block] = t[rows, k].reshape(shp)
            off[j0:j0 + block, i0:i0 + block] = np.where(side >= 0.0, dist, -dist).reshape(shp)
    return seg, tt, off
