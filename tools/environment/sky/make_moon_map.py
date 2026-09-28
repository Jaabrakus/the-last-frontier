#!/usr/bin/env python3
"""The Moon's near side for the dynamic sky (sun and moon push, 2026-09-26): a procedural albedo map.

  python3 tools/environment/sky/make_moon_map.py [out_png] [--size 512] [--preview preview.png]
  (default: assets/environment/sky/moon_albedo.png, 512 x 512 RGB8; deterministic, seed 1765; no downloads)

What it is: the disc of the Moon as seen from the Earth (orthographic, no libration), north up and selenographic
east (IAU: the Mare Crisium side) to the right. That is how the Moon looks in the sky from the northern hemisphere
when it stands on the meridian: Crisium toward the western sky. The sky shader (frontier_sky_dynamic.gdshader,
moon_disc()) samples it at the disc coordinate q in [-1, 1]^2 (u = 0.5 + 0.5 q.x, v = 0.5 - 0.5 q.y) and lights it
with the sun (the phase), so the texture holds albedo only: no shading, no terminator.

Everything is generated here; nothing is traced from a photograph. The maria are soft-edged blobs placed at the
real selenographic positions and sizes of the near side's seas (IAU names, approximate centres and diameters),
their shorelines roughened by noise; the highlands carry fBm brightness and a crater population; the bright young
craters (Tycho, Copernicus, Kepler, Aristarchus, Proclus, ...) get ejecta haloes and ray systems, and the dark-
floored ones (Plato, Grimaldi) their dark floors. Relative albedo: highlands ~0.8, maria ~0.45-0.6, fresh craters
up to 1.0 (8-bit, linear, NOT sRGB-encoded: the shader reads it as data). The two colours are kept faint (the
titanium-rich blue of Tranquillitatis, the browner Imbrium / Serenitatis), as a naked eye sees them.

Outside the disc every texel repeats the limb's value, so the mipmaps never darken the edge.
"""
import argparse
import math
import os

import numpy as np
from PIL import Image

SEED = 1765
R_KM = 1737.4

# Maria: (name, lat, lon, diameter km, darkness 0..1, tint (r, g, b) multipliers, x-stretch along longitude).
# Positions and sizes: IAU / USGS gazetteer values, rounded. Oceanus Procellarum and Mare Frigoris are irregular:
# they are chains of blobs.
MARIA = [
    ("Imbrium", 32.8, -15.6, 1146, 0.92, (1.02, 1.0, 0.96), 1.0),
    ("Serenitatis", 28.0, 17.5, 707, 0.80, (1.02, 1.0, 0.97), 1.0),
    ("Tranquillitatis", 8.5, 31.4, 873, 1.00, (0.96, 0.99, 1.05), 1.1),
    ("Tranquillitatis SE", 3.0, 38.0, 420, 0.95, (0.96, 0.99, 1.05), 1.0),
    ("Crisium", 17.0, 59.1, 556, 0.95, (1.0, 1.0, 1.0), 1.15),
    ("Fecunditatis", -7.8, 51.3, 909, 0.72, (0.99, 1.0, 1.02), 0.85),
    ("Nectaris", -15.2, 35.5, 333, 0.78, (1.0, 1.0, 1.0), 1.0),
    ("Nubium", -21.3, -16.6, 715, 0.70, (1.0, 1.0, 1.0), 1.0),
    ("Humorum", -24.4, -38.6, 389, 0.80, (1.0, 1.0, 1.0), 1.0),
    ("Cognitum", -10.0, -23.1, 420, 0.72, (1.0, 1.0, 1.0), 1.0),
    ("Insularum", 7.5, -30.9, 560, 0.76, (1.0, 1.0, 1.0), 1.0),
    ("Vaporum", 13.3, 3.6, 245, 0.78, (1.0, 1.0, 1.0), 1.0),
    ("Sinus Medii", 2.4, 1.7, 335, 0.50, (1.0, 1.0, 1.0), 1.0),
    ("Sinus Aestuum", 10.9, -8.8, 290, 0.70, (1.0, 1.0, 1.0), 1.0),
    ("Palus Putredinis", 26.5, 0.4, 160, 0.60, (1.0, 1.0, 1.0), 1.0),
    ("Sinus Iridum", 44.1, -31.5, 236, 0.85, (1.02, 1.0, 0.96), 1.0),
    ("Lacus Somniorum", 38.0, 29.2, 380, 0.45, (1.0, 1.0, 1.0), 1.0),
    ("Mare Spumans", 1.1, 65.1, 139, 0.70, (1.0, 1.0, 1.0), 1.0),
    ("Mare Undarum", 6.8, 68.4, 243, 0.65, (1.0, 1.0, 1.0), 1.0),
    ("Smythii", 1.3, 87.5, 373, 0.75, (1.0, 1.0, 1.0), 1.0),
    ("Marginis", 13.3, 86.1, 358, 0.60, (1.0, 1.0, 1.0), 1.0),
    ("Humboldtianum", 56.8, 81.5, 273, 0.70, (1.0, 1.0, 1.0), 1.0),
    ("Australe", -38.9, 93.0, 603, 0.55, (1.0, 1.0, 1.0), 1.0),
    ("Orientale", -19.4, -92.8, 327, 0.50, (1.0, 1.0, 1.0), 1.0),
    # Oceanus Procellarum: the great western ocean, from Sinus Roris down past Kepler to Grimaldi's rim
    ("Procellarum N", 42.0, -53.0, 620, 0.88, (1.0, 1.0, 1.01), 1.0),
    ("Procellarum", 27.0, -58.0, 1000, 0.92, (1.0, 1.0, 1.01), 1.0),
    ("Procellarum E", 20.0, -40.0, 620, 0.85, (1.0, 1.0, 1.01), 1.0),
    ("Procellarum C", 12.0, -50.0, 1000, 0.90, (1.0, 1.0, 1.01), 1.0),
    ("Procellarum W", 18.0, -72.0, 620, 0.85, (1.0, 1.0, 1.01), 1.0),
    ("Procellarum S", -2.0, -50.0, 820, 0.85, (1.0, 1.0, 1.01), 1.0),
    ("Procellarum SW", -9.0, -62.0, 460, 0.75, (1.0, 1.0, 1.01), 1.0),
    ("Sinus Roris", 54.0, -56.0, 300, 0.75, (1.0, 1.0, 1.0), 1.0),
    # Mare Frigoris: a long thin band north of Imbrium and Serenitatis
    ("Frigoris W", 57.0, -38.0, 260, 0.70, (1.0, 1.0, 1.0), 1.4),
    ("Frigoris", 57.5, -14.0, 280, 0.72, (1.0, 1.0, 1.0), 1.6),
    ("Frigoris C", 58.0, 6.0, 260, 0.72, (1.0, 1.0, 1.0), 1.6),
    ("Frigoris E", 56.0, 26.0, 240, 0.65, (1.0, 1.0, 1.0), 1.5),
    ("Frigoris EE", 54.0, 42.0, 200, 0.55, (1.0, 1.0, 1.0), 1.3),
    ("Frigoris WC", 57.5, -26.0, 250, 0.70, (1.0, 1.0, 1.0), 1.5),
    ("Frigoris CC", 58.0, -4.0, 250, 0.72, (1.0, 1.0, 1.0), 1.5),
    ("Frigoris CE", 57.0, 16.0, 240, 0.70, (1.0, 1.0, 1.0), 1.5),
]

# Dark-floored craters: (name, lat, lon, diameter km, darkness).
DARK_CRATERS = [
    ("Plato", 51.6, -9.4, 101, 0.9),
    ("Grimaldi", -5.2, -68.6, 173, 0.95),
    ("Riccioli", -3.0, -74.3, 139, 0.6),
    ("Ptolemaeus", -9.3, -1.9, 153, 0.35),
    ("Endymion", 53.6, 57.0, 123, 0.7),
    ("Crüger", -16.7, -66.8, 45, 0.8),
    ("Billy", -13.8, -50.1, 46, 0.8),
]

# Bright (young) craters: (name, lat, lon, diameter km, halo, rays (count, length deg, strength)).
BRIGHT_CRATERS = [
    ("Tycho", -43.3, -11.2, 86, 1.0, (40, 24.0, 0.20)),
    ("Copernicus", 9.6, -20.1, 93, 0.8, (28, 12.0, 0.14)),
    ("Kepler", 8.1, -38.0, 31, 0.7, (20, 8.0, 0.12)),
    ("Aristarchus", 23.7, -47.4, 40, 1.2, (12, 5.0, 0.08)),
    ("Proclus", 16.1, 46.8, 28, 0.8, (10, 7.0, 0.12)),
    ("Anaxagoras", 73.4, -10.1, 51, 0.6, (14, 8.0, 0.10)),
    ("Menelaus", 16.3, 16.0, 26, 0.7, (6, 8.0, 0.15)),
    ("Langrenus", -8.9, 60.9, 132, 0.5, (10, 12.0, 0.15)),
    ("Stevinus", -32.5, 54.2, 74, 0.6, (10, 6.0, 0.08)),
    ("Furnerius A", -33.5, 59.0, 20, 0.5, (10, 8.0, 0.1)),
    ("Byrgius A", -24.5, -63.7, 19, 0.6, (10, 8.0, 0.1)),
    ("Olbers A", 8.1, -77.6, 43, 0.5, (8, 7.0, 0.08)),
    ("Manilius", 14.5, 9.1, 39, 0.5, (0, 0.0, 0.0)),
    ("Censorinus", -0.4, 32.7, 3.8, 0.5, (0, 0.0, 0.0)),
    ("Dionysius", 2.8, 17.3, 18, 0.5, (6, 6.0, 0.12)),
    ("Theophilus", -11.4, 26.4, 110, 0.35, (0, 0.0, 0.0)),
    ("Clavius", -58.4, -14.4, 231, -0.1, (0, 0.0, 0.0)),
]


def dot(p, v):
    """Per-texel dot product (explicit: numpy's BLAS matmul raises spurious FP warnings on macOS)."""
    return p[..., 0] * v[0] + p[..., 1] * v[1] + p[..., 2] * v[2]


def unit(lat, lon):
    la, lo = math.radians(lat), math.radians(lon)
    return np.array([math.cos(la) * math.sin(lo), math.sin(la), math.cos(la) * math.cos(lo)])


def km_to_deg(d_km):
    return math.degrees(d_km * 0.5 / R_KM)


class Noise:
    """3D value-noise fBm on the unit sphere (trilinear on a random lattice, smoothstep weights)."""

    def __init__(self, rng, grid=96):
        self.g = rng.random((grid, grid, grid))
        self.n = grid

    def value(self, p, freq):
        q = (p + 1.5) * freq
        i = np.floor(q).astype(int)
        f = q - i
        f = f * f * (3.0 - 2.0 * f)
        n = self.n
        out = 0.0
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    v = self.g[(i[..., 0] + dx) % n, (i[..., 1] + dy) % n, (i[..., 2] + dz) % n]
                    w = (f[..., 0] if dx else 1 - f[..., 0]) * (f[..., 1] if dy else 1 - f[..., 1]) * (f[..., 2] if dz else 1 - f[..., 2])
                    out = out + v * w
        return out

    def fbm(self, p, freq, octaves, gain=0.5):
        s, a, tot = 0.0, 1.0, 0.0
        for o in range(octaves):
            s = s + a * (self.value(p, freq * (2.03 ** o)) - 0.5)
            tot += a
            a *= gain
        return s / tot


def build(size):
    rng = np.random.default_rng(SEED)
    noise = Noise(rng)
    c = (np.arange(size) + 0.5) / size * 2.0 - 1.0
    x, y = np.meshgrid(c, -c)            # row 0 = north
    r = np.sqrt(x * x + y * y)
    # texels outside the disc repeat the limb (clamped just inside it)
    s = np.where(r > 0.998, 0.998 / np.maximum(r, 1e-9), 1.0)
    x, y = x * s, y * s
    z = np.sqrt(np.maximum(1.0 - x * x - y * y, 0.0))
    p = np.stack([x, y, z], axis=-1)       # x east, y north, z toward the Earth

    def ang_to(v):
        return np.degrees(np.arccos(np.clip(dot(p, v), -1.0, 1.0)))

    # highlands: bright, mottled
    alb = 0.82 + 0.10 * noise.fbm(p, 3.0, 5) + 0.05 * noise.fbm(p, 14.0, 3)
    tint = np.ones(p.shape)
    tint *= np.array([1.0, 0.975, 0.94])   # the highlands' faint warmth
    # maria: soft blobs with noisy shorelines, darkest in the middle
    warp = noise.fbm(p, 5.0, 5) + 0.5 * noise.fbm(p, 17.0, 3)
    mare = np.zeros(x.shape)
    mare_tint = np.ones(p.shape)
    for name, lat, lon, d_km, dark, tn, stretch in MARIA:
        cen = unit(lat, lon)
        rad = km_to_deg(d_km)
        if stretch != 1.0:
            # stretch along the local east direction (Frigoris' band, Crisium's E-W length)
            east = np.array([math.cos(math.radians(lon)), 0.0, -math.sin(math.radians(lon))])
            north = np.cross(cen, east)
            de = np.degrees(np.arcsin(np.clip(dot(p, east), -1, 1)))
            dn = np.degrees(np.arcsin(np.clip(dot(p, north), -1, 1)))
            dist = np.sqrt((de / stretch) ** 2 + dn ** 2)
            dist = np.where(dot(p, cen) > 0.0, dist, 180.0)
        else:
            dist = ang_to(cen)
        dist = dist + warp * (rad * 0.6 + 3.0)
        m = np.clip((rad - dist) / (0.3 * rad + 1.5), 0.0, 1.0)
        m = m * m * (3.0 - 2.0 * m) * dark
        upd = m > mare
        mare = np.maximum(mare, m)
        mare_tint[upd] = np.array(tn)
    # the maria's own mottling (lava flows of different ages)
    mare_level = 0.43 + 0.08 * noise.fbm(p, 9.0, 4) + 0.03 * noise.fbm(p, 30.0, 2)
    alb = alb * (1.0 - mare) + mare_level * mare
    tint = tint * (1.0 - mare[..., None]) + mare_tint * mare[..., None]
    # a crater population (fewer on the maria): bright rims, slightly darker floors
    n_craters = int(900 * (size / 512.0) ** 0.5)
    pts = rng.normal(size=(n_craters, 3))
    pts[:, 2] = np.abs(pts[:, 2])            # the near side
    pts /= np.linalg.norm(pts, axis=1, keepdims=True)
    radii = 0.25 * (1.0 - rng.random(n_craters)) ** (-0.55)
    radii = np.minimum(radii, 5.0)
    for k in range(n_craters):
        cen = pts[k]
        rad = radii[k]
        cosr = math.cos(math.radians(rad * 2.2))
        near = (dot(p, cen)) > cosr
        if not near.any():
            continue
        d = np.degrees(np.arccos(np.clip(dot(p[near], cen), -1, 1))) / rad
        on_mare = mare[near]
        keep = 1.0 - 0.75 * on_mare
        rim = np.exp(-((d - 1.0) / 0.2) ** 2) * 0.035
        floor = -0.02 * np.clip((0.9 - d) / 0.2, 0.0, 1.0)
        ejecta = 0.015 * np.exp(-np.maximum(d - 1.0, 0.0) / 0.6) * (d > 1.0)
        alb[near] += (rim + floor + ejecta) * keep
    # dark-floored craters
    for name, lat, lon, d_km, dark in DARK_CRATERS:
        cen = unit(lat, lon)
        rad = km_to_deg(d_km)
        d = ang_to(cen) / rad
        f = np.clip((1.0 - d) / 0.2, 0.0, 1.0) * dark
        alb = alb * (1.0 - f) + 0.40 * f
        alb += 0.06 * np.exp(-((d - 1.05) / 0.15) ** 2)
    # bright craters: halo of ejecta and rays
    for name, lat, lon, d_km, halo, rays in BRIGHT_CRATERS:
        cen = unit(lat, lon)
        rad = max(km_to_deg(d_km), 0.25)
        dist = ang_to(cen)
        d = dist / rad
        if halo > 0:
            alb += halo * (0.22 * np.exp(-np.maximum(d - 0.3, 0.0) / 1.2) + 0.12 * np.exp(-((d - 1.0) / 0.25) ** 2))
        else:
            alb += halo * np.exp(-((d - 1.0) / 0.25) ** 2)
        n_rays, length, strength = rays
        if n_rays <= 0:
            continue
        # bearing of every texel as seen from the crater (on its tangent plane)
        east = np.cross(np.array([0.0, 1.0, 0.0]), cen)
        east /= max(np.linalg.norm(east), 1e-9)
        north = np.cross(cen, east)
        bearing = np.arctan2(dot(p, east), dot(p, north))
        ray = np.zeros(x.shape)
        for i in range(n_rays):
            b = rng.uniform(-math.pi, math.pi)
            ln = length * rng.uniform(0.35, 1.0)
            w = math.radians(rng.uniform(0.4, 1.1))
            db = np.angle(np.exp(1j * (bearing - b)))
            across = np.abs(db) * np.sin(np.radians(np.minimum(dist, 90.0)))
            seg = np.exp(-(across / w) ** 2) * np.exp(-np.maximum(dist - rad, 0.0) / ln) * np.clip((dist - rad) / (2.0 * rad), 0.0, 1.0) * (dist < 3.0 * ln)
            ray = np.maximum(ray, seg * rng.uniform(0.5, 1.0))
        # rays are patchy along their length
        ray *= 0.6 + 0.8 * np.clip(noise.fbm(p, 20.0, 2) + 0.5, 0.0, 1.0)
        alb += strength * ray
    alb = np.clip(alb, 0.25, 1.0)
    rgb = np.clip(alb[..., None] * tint, 0.0, 1.0)
    return rgb


def main():
    ap = argparse.ArgumentParser()
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(os.path.join(here, "..", "..", ".."))
    ap.add_argument("out", nargs="?", default=os.path.join(root, "assets", "environment", "sky", "moon_albedo.png"))
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--preview", default="", help="also write a lit full-moon preview (sRGB) here")
    a = ap.parse_args()
    rgb = build(a.size)
    Image.fromarray((rgb * 255.0 + 0.5).astype(np.uint8)).save(a.out, optimize=True)
    print("wrote %s (%d x %d)" % (a.out, a.size, a.size))
    if a.preview:
        c = (np.arange(a.size) + 0.5) / a.size * 2.0 - 1.0
        x, y = np.meshgrid(c, -c)
        inside = (x * x + y * y) < 1.0
        img = np.where(inside[..., None], rgb, 0.0) ** (1.0 / 2.2)
        Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(a.preview)
        print("wrote %s" % a.preview)


if __name__ == "__main__":
    main()
