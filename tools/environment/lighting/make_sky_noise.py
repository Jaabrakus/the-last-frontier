"""Tileable noise texture for the dynamic sky's clouds, stars' Milky Way and the moon (package A).

  python3 tools/environment/lighting/make_sky_noise.py [out_png]
  (default: assets/environment/sky/sky_noise.png, 512x512 RGBA8, deterministic, seed 1776)

Channels (all tile seamlessly; periodic by construction: FFT-synthesised or periodic distances):
  R  cumulus base: billowy fractal noise (power-law spectrum ~k^-2.3, |n| folded), 0..1
  G  cellular (Worley F1, inverted) detail for puffy edges, 0..1
  B  fine fractal noise (~k^-1.6) for erosion / Milky Way dust / moon maria detail, 0..1
  A  cirrus: anisotropic streaks (spectrum stretched ~2.6:1, varying along x), 0..1
"""
import os
import sys

import numpy as np
from PIL import Image

N = 512
rng = np.random.default_rng(1776)


def spectral(power, aniso=1.0, kmin=1.0):
    kx = np.fft.fftfreq(N) * N
    ky = np.fft.fftfreq(N) * N
    KX, KY = np.meshgrid(kx, ky)
    k = np.sqrt((KX / aniso) ** 2 + (KY * aniso) ** 2)
    k[0, 0] = 1.0
    amp = np.where(k >= kmin, k ** (-power), 0.0)
    amp[0, 0] = 0.0
    phase = rng.uniform(0, 2 * np.pi, (N, N))
    spec = amp * np.exp(1j * phase)
    n = np.real(np.fft.ifft2(spec))
    n = (n - n.mean()) / (n.std() + 1e-9)
    return n


def norm01(a, lo=1.0, hi=99.0):
    a0, a1 = np.percentile(a, lo), np.percentile(a, hi)
    return np.clip((a - a0) / (a1 - a0), 0.0, 1.0)


def worley(points=48):
    pts = rng.uniform(0, N, (points, 2))
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    d = np.full((N, N), 1e9, dtype=np.float32)
    for px, py in pts:
        dx = np.abs(xx - px)
        dy = np.abs(yy - py)
        dx = np.minimum(dx, N - dx)
        dy = np.minimum(dy, N - dy)
        d = np.minimum(d, np.sqrt(dx * dx + dy * dy))
    return 1.0 - norm01(d, 0.0, 100.0)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), '..', '..', '..', 'assets', 'environment', 'sky', 'sky_noise.png')
    base = spectral(2.3, kmin=2.0)
    billow = 1.0 - np.abs(base) * 0.6 + 0.35 * spectral(1.9, kmin=6.0)
    r = norm01(billow)
    g = worley(56)
    b = norm01(spectral(1.6, kmin=8.0))
    a = norm01(spectral(2.1, aniso=2.6, kmin=1.5) + 0.45 * spectral(1.7, aniso=1.4, kmin=4.0))
    img = np.stack([r, g, b, a], axis=-1)
    Image.fromarray((img * 255.0 + 0.5).astype(np.uint8)).save(os.path.abspath(out))
    print('wrote', os.path.abspath(out), [round(float(c.mean()), 3) for c in (r, g, b, a)])


if __name__ == '__main__':
    main()
