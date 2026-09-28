#!/usr/bin/env python3
"""Bakes assets/environment/sky/stars/star_map.png from the Yale Bright Star Catalog, 5th revised edition
(assets/environment/sky/stars/ybsc5.gz, from tdc-www.harvard.edu/catalogs/ybsc5.gz; Hoffleit & Warren 1991,
NASA ADC / Harvard-Smithsonian CfA; 9,110 stars to V ~ 6.5, every star the naked eye sees).

The map is equirectangular in equatorial coordinates (J2000): u = RA / 360, v = (90 - Dec) / 180, 8192 x 4096.
Each star is a small Gaussian in TRUE angular distance on the sphere (round near the poles too: Polaris stays a
point), its colour from B-V, its value the square root of its flux (V = 0 -> 1.0), so the 8 bits keep the faint
stars: the sky shader squares it. Real positions and brightness: the constellations and Polaris are where they
are, so the player can find north by the stars (user 2026-09-25).
"""
import gzip, math, os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SRC = os.path.join(ROOT, "assets/environment/sky/stars/ybsc5.gz")
OUT = os.path.join(ROOT, "assets/environment/sky/stars/star_map.png")
W, H = 8192, 4096
SIGMA_DEG = 0.035          # the star's glow (about one texel)


def bv_to_rgb(bv):
    # blackbody-ish tint from B-V (blue-white to orange), normalized to max 1
    bv = max(-0.4, min(2.0, bv))
    t = 4600.0 * (1.0 / (0.92 * bv + 1.7) + 1.0 / (0.92 * bv + 0.62))
    t = max(2500.0, min(30000.0, t)) / 100.0
    r = 255.0 if t <= 66 else 329.7 * (t - 60) ** -0.1332
    g = 99.47 * math.log(t) - 161.1 if t <= 66 else 288.1 * (t - 60) ** -0.0755
    b = 255.0 if t >= 66 else (0.0 if t <= 19 else 138.5 * math.log(t - 10) - 305.0)
    c = np.clip(np.array([r, g, b]) / 255.0, 0, 1)
    return c / max(c.max(), 1e-6)


def main():
    img = np.zeros((H, W, 3), np.float32)
    n = 0
    with gzip.open(SRC, "rt", encoding="latin-1") as f:
        for line in f:
            if len(line) < 107 or line[75:77].strip() == "":
                continue
            try:
                ra = (int(line[75:77]) + int(line[77:79]) / 60.0 + float(line[79:83]) / 3600.0) * 15.0
                sgn = -1.0 if line[83] == "-" else 1.0
                dec = sgn * (int(line[84:86]) + int(line[86:88]) / 60.0 + int(line[88:90]) / 3600.0)
                vmag = float(line[102:107])
            except ValueError:
                continue
            try:
                bv = float(line[109:114])
            except ValueError:
                bv = 0.6
            flux = 10.0 ** (-0.4 * vmag)
            # brighter stars glow wider (the eye's and the lens's bloom): the navigation stars stand out
            sig = SIGMA_DEG * (1.0 + 1.6 * max(0.0, min(1.0, (3.5 - vmag) / 4.5)))
            col = bv_to_rgb(bv) * min(flux, 4.0)
            # splat in true angular distance
            r_deg = sig * 3.0
            v0 = (90.0 - dec) / 180.0 * H
            dv = r_deg / 180.0 * H
            cosd = max(math.cos(math.radians(dec)), 1e-3)
            du = min(W / 2, r_deg / cosd / 360.0 * W)
            u0 = ra / 360.0 * W
            sx = math.cos(math.radians(dec)) * math.cos(math.radians(ra))
            sy = math.cos(math.radians(dec)) * math.sin(math.radians(ra))
            sz = math.sin(math.radians(dec))
            ys = np.arange(int(math.floor(v0 - dv)), int(math.ceil(v0 + dv)) + 1)
            xs = np.arange(int(math.floor(u0 - du)), int(math.ceil(u0 + du)) + 1)
            ys = ys[(ys >= 0) & (ys < H)]
            if len(ys) == 0:
                continue
            X, Y = np.meshgrid(xs, ys)
            tra = np.radians((X + 0.5) / W * 360.0)
            tdec = np.radians(90.0 - (Y + 0.5) / H * 180.0)
            dot = np.clip(np.cos(tdec) * np.cos(tra) * sx + np.cos(tdec) * np.sin(tra) * sy + np.sin(tdec) * sz, -1, 1)
            ang = np.degrees(np.arccos(dot))
            g = np.exp(-(ang ** 2) / (2 * sig ** 2))
            img[Y, X % W] += g[..., None] * col[None, None, :]
            n += 1
    enc = np.sqrt(np.clip(img, 0.0, 1.0))
    Image.fromarray((enc * 255.0 + 0.5).astype(np.uint8)).save(OUT, optimize=True)
    print("stars %d -> %s (%d bytes)" % (n, OUT, os.path.getsize(OUT)))


if __name__ == "__main__":
    main()
