#!/usr/bin/env python3
"""Tileable 3D noise for the volumetric clouds of the dynamic sky (cloud engine, 2026-09-26).

  python3 tools/environment/sky/make_cloud_noise.py [out_png]
  (default: assets/environment/sky/cloud_noise_3d.png: 64 x 64 x 64 RGBA8 as 8 x 8 slices of 64 x 64 in a
   512 x 512 PNG, imported by Godot as a Texture3D; deterministic, seed 1765)

Channels (all periodic in x, y and z: the texture tiles seamlessly in every direction):
  R  cloud base shape: Perlin-Worley (Perlin fBm remapped by a Worley fBm, Schneider 2015 / Hillaire 2016),
     then eroded by a low-frequency Worley fBm, so round billows with a cellular structure: 0..1
  G  detail: Worley fBm (8, 16, 32 cells per tile), inverted F1: the small billows that erode cloud edges
  B  Perlin fBm (4, 8, 16 cells): wisps and the rain shafts' streaks
  A  large cells: inverted Worley F1 (3 cells per tile): which cumulus cell a point belongs to
The sky shader (shaders/sky/frontier_sky_dynamic.gdshader) samples it in world metres; DayNight mirrors the base
channel on the CPU for the sun's cloud shade.
"""
import os
import sys

import numpy as np
from PIL import Image

N = 64
SLICES = 8
rng = np.random.default_rng(1765)
coords = (np.arange(N, dtype=np.float64) + 0.5) / N
X, Y, Z = np.meshgrid(coords, coords, coords, indexing="ij")


def fade(t):
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


def perlin(period):
    g = rng.normal(size=(period, period, period, 3))
    g /= np.linalg.norm(g, axis=-1, keepdims=True)
    px, py, pz = X * period, Y * period, Z * period
    x0, y0, z0 = np.floor(px).astype(int), np.floor(py).astype(int), np.floor(pz).astype(int)
    fx, fy, fz = px - x0, py - y0, pz - z0
    out = np.zeros_like(px)
    u, v, w = fade(fx), fade(fy), fade(fz)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                gi = g[(x0 + dx) % period, (y0 + dy) % period, (z0 + dz) % period]
                dot = gi[..., 0] * (fx - dx) + gi[..., 1] * (fy - dy) + gi[..., 2] * (fz - dz)
                wx = u if dx else 1.0 - u
                wy = v if dy else 1.0 - v
                wz = w if dz else 1.0 - w
                out += dot * wx * wy * wz
    return out


def perlin_fbm(period, octaves):
    s, a, tot = 0.0, 1.0, 0.0
    for o in range(octaves):
        s = s + a * perlin(period * (2 ** o))
        tot += a
        a *= 0.5
    s = s / tot
    return np.clip(s * 1.4 + 0.5, 0.0, 1.0)   # ~0..1


def worley(cells):
    """Inverted Worley F1 (1 at a feature point, 0 far from all), periodic, `cells` cells per axis."""
    pts = rng.uniform(0.0, 1.0, size=(cells, cells, cells, 3))
    px, py, pz = X * cells, Y * cells, Z * cells
    cx, cy, cz = np.floor(px).astype(int), np.floor(py).astype(int), np.floor(pz).astype(int)
    d = np.full(px.shape, 1e9)
    for ox in (-1, 0, 1):
        for oy in (-1, 0, 1):
            for oz in (-1, 0, 1):
                nx, ny, nz = cx + ox, cy + oy, cz + oz
                p = pts[nx % cells, ny % cells, nz % cells]
                ddx = nx + p[..., 0] - px
                ddy = ny + p[..., 1] - py
                ddz = nz + p[..., 2] - pz
                d = np.minimum(d, ddx * ddx + ddy * ddy + ddz * ddz)
    return 1.0 - np.clip(np.sqrt(d), 0.0, 1.0)


def worley_fbm(c):
    return worley(c) * 0.625 + worley(c * 2) * 0.25 + worley(c * 4) * 0.125


def remap(v, lo, hi, nlo, nhi):
    return nlo + (v - lo) / np.maximum(hi - lo, 1e-6) * (nhi - nlo)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "environment", "sky", "cloud_noise_3d.png")
    p = perlin_fbm(4, 4)
    wf_pw = worley_fbm(4)
    pw = remap(p, 0.0, 1.0, wf_pw, 1.0)                      # Perlin-Worley
    wf_lo = worley_fbm(3)
    base = np.clip(remap(pw, wf_lo - 1.0, 1.0, 0.0, 1.0), 0.0, 1.0)
    base = (base - np.percentile(base, 1)) / (np.percentile(base, 99.5) - np.percentile(base, 1))
    r = np.clip(base, 0.0, 1.0)
    g = worley_fbm(8)
    g = np.clip((g - np.percentile(g, 1)) / (np.percentile(g, 99) - np.percentile(g, 1)), 0.0, 1.0)
    b = perlin_fbm(4, 3)
    a = worley(3)
    vol = np.stack([r, g, b, a], axis=-1)                    # [x, y, z, c]
    # Godot's Texture3D import: the image is split into SLICES x SLICES tiles, left to right, top to bottom, each
    # tile one depth slice (z). Inside a tile, image x = volume x and image y = volume y.
    img = np.zeros((N * SLICES, N * SLICES, 4))
    for z in range(N):
        tx, ty = z % SLICES, z // SLICES
        img[ty * N:(ty + 1) * N, tx * N:(tx + 1) * N] = vol[:, :, z].transpose(1, 0, 2)
    Image.fromarray((np.clip(img, 0, 1) * 255.0 + 0.5).astype(np.uint8)).save(os.path.abspath(out))
    print("wrote", os.path.abspath(out), "means", [round(float(c.mean()), 3) for c in (r, g, b, a)])


if __name__ == "__main__":
    main()
