"""The strand atlas of hair v3 (plain python3 + numpy + PIL): assets/character/hair/tex/hair_atlas.png,
drawn strand by strand (the project's own; no photograph), for the strand strips of
tools/character/hair/_strands.py and hair_tex.gdshader.

The user preferred our own hair to the MakeHuman hair and asked for every style rebuilt with it
(2026-09-28). The atlas is SLOTS columns of cards, each 256 px wide and the full height tall, the
root at the top (v 0) and the tip at the bottom (v 1):

  RGB  the strand's relative brightness (0.5 = the average strand; the shader colours it with the
       hair colour model), A the coverage (thin anti-aliased strands, tapering to the tips)

  slot 0  dense straight: the base layer (many strands, nearly opaque, no tip taper)
  slot 1  straight clumps: long strands gathered in clumps, tips tapered and ragged
  slot 2  fine straight: fewer, thinner strands (the outer layer, flyaways)
  slot 3  wavy clumps
  slot 4  coily: small tight coils over the whole card (Afro-textured hair; tiles along v)
  slot 5  braid: a three-strand plait, a lobe every 128 px (tiles along v)
  slot 6  short cropped: short strands (about 2 cm at the cards' scale), dense
  slot 7  dense straight with a ragged tip (the tail end of a queue, a ponytail)

    python3 tools/character/hair_atlas.py
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(FRONTIER, "assets", "character", "hair", "tex", "hair_atlas.png")
SLOTS = 8
W, H = 256, 2048          # one card
SS = 2                    # supersampling


class Card:
    def __init__(self):
        self.a = Image.new("L", (W * SS, H * SS), 0)          # coverage
        self.b = Image.new("L", (W * SS, H * SS), 0)          # brightness x coverage
        self.da = ImageDraw.Draw(self.a)
        self.db = ImageDraw.Draw(self.b)

    def strand(self, pts, width, bright, taper=0.35, alpha=1.0):
        """A strand along pts (card pixels), tapering over its last `taper` share."""
        n = len(pts)
        for i in range(n - 1):
            t = i / max(n - 2, 1)
            w = width * (1.0 - max(0.0, (t - (1.0 - taper)) / max(taper, 1e-6)) * 0.85)
            a = alpha * (1.0 - max(0.0, (t - (1.0 - taper * 0.6)) / max(taper * 0.6, 1e-6)) * 0.9)
            p0 = (pts[i][0] * SS, pts[i][1] * SS)
            p1 = (pts[i + 1][0] * SS, pts[i + 1][1] * SS)
            ww = max(1, int(round(w * SS)))
            self.da.line([p0, p1], fill=int(255 * a), width=ww)
            self.db.line([p0, p1], fill=int(255 * a * min(bright, 1.99) / 2.0), width=ww)

    def result(self):
        a = np.asarray(self.a.resize((W, H), Image.LANCZOS), np.float64) / 255.0
        b = np.asarray(self.b.resize((W, H), Image.LANCZOS), np.float64) / 255.0
        rel = np.where(a > 1e-3, b / np.maximum(a, 1e-3), 0.25)          # brightness / 2
        return rel, a


def _wavy(x0, y0, length, amp, period, phase, drift, steps=40):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        y = y0 + t * length
        x = x0 + amp * math.sin(2 * math.pi * y / period + phase) + drift * t
        pts.append((x, y))
    return pts


def straight(rng, n, length=(0.85, 1.0), width=(1.0, 1.8), clump=0.0, taper=0.35, wave=0.0, alpha=(0.7, 1.0),
             period=(300, 700), y0=(0.0, 0.03)):
    c = Card()
    centres = rng.uniform(10, W - 10, max(1, int(n / 25)))
    for _ in range(n):
        x0 = rng.uniform(-4, W + 4)
        L = rng.uniform(*length) * H
        ys = rng.uniform(*y0) * H
        drift = 0.0
        if clump > 0:
            cc = centres[np.argmin(np.abs(centres - x0))]
            drift = (cc - x0) * clump
        pts = _wavy(x0, ys, L - ys, wave * rng.uniform(0.5, 1.5), rng.uniform(*period), rng.uniform(0, 6.3), drift)
        c.strand(pts, rng.uniform(*width), rng.uniform(0.55, 1.45), taper, rng.uniform(*alpha))
    return c.result()


def coily(rng, n=9000):
    c = Card()
    for _ in range(n):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(3.5, 7.5)
        turns = rng.uniform(1.2, 2.4)
        pts = [(cx + r * math.cos(t) * (1 + 0.15 * math.sin(3 * t)), cy + r * 0.8 * math.sin(t) + t * 1.6)
               for t in np.linspace(0, 2 * math.pi * turns, 26)]
        # wrap into the card along v (the card tiles vertically)
        pts = [(x, y % H) for x, y in pts]
        segs, cur = [], [pts[0]]
        for p, q in zip(pts, pts[1:]):
            if abs(q[1] - p[1]) > H / 2:
                segs.append(cur)
                cur = [q]
            else:
                cur.append(q)
        segs.append(cur)
        b = rng.uniform(0.5, 1.5)
        for s in segs:
            if len(s) > 1:
                c.strand(s, rng.uniform(1.3, 2.2), b, taper=0.05, alpha=rng.uniform(0.7, 1.0))
    rel, a = c.result()
    # coily hair is dense: nearly opaque, the coils read in the brightness
    return rel, np.clip(a * 1.5, 0, 1)


def braid(rng):
    """A three-strand plait: lobes alternating left and right, each running from the outer edge down
    to the middle, drawn as a bundle of strands (the lobe's middle brighter: it is rounder there),
    each lobe over the one before; SPACING px between lobes (tiles along v)."""
    c = Card()
    spacing = 128.0
    n = int(H / spacing) + 2
    for k in range(-1, n):
        side = 1 if k % 2 == 0 else -1
        y0 = k * spacing
        for _ in range(260):
            u = rng.uniform(-1, 1)
            pts = []
            for i in range(20):
                t = i / 19.0
                # from the outer edge (top) to past the middle (bottom), bowed outward
                x = W / 2 + side * (0.36 * W * (1 - t) - 0.10 * W * t) + u * 0.21 * W * (1 - 0.35 * t)
                y = y0 + t * spacing * 2.3 + u * 14 * math.sin(math.pi * t)
                pts.append((x, y))
            if pts[-1][1] < 0 or pts[0][1] > H:
                continue
            pts = [(x, min(max(y, 0), H - 1)) for x, y in pts]
            shade = 0.55 + 0.75 * (1 - abs(u)) ** 1.5
            c.strand(pts, rng.uniform(1.2, 2.0), shade * rng.uniform(0.85, 1.15), taper=0.08, alpha=rng.uniform(0.8, 1.0))
    rel, a = c.result()
    return rel, np.clip(a * 1.25, 0, 1)


def main():
    rng = np.random.default_rng(1758)
    cards = [
        straight(rng, 2600, length=(0.95, 1.0), width=(1.2, 2.2), taper=0.02, alpha=(0.8, 1.0)),
        straight(rng, 1500, length=(0.7, 1.0), clump=0.35, taper=0.4),
        straight(rng, 520, length=(0.5, 1.0), width=(0.8, 1.3), taper=0.5, alpha=(0.5, 0.9)),
        straight(rng, 1400, length=(0.7, 1.0), clump=0.3, taper=0.4, wave=9.0, period=(260, 520)),
        coily(rng),
        braid(rng),
        straight(rng, 5200, length=(0.08, 0.14), width=(1.0, 1.6), taper=0.4, y0=(0.0, 0.9)),
        straight(rng, 2200, length=(0.75, 1.0), width=(1.1, 2.0), clump=0.2, taper=0.45),
    ]
    rel = np.hstack([c[0] for c in cards])
    a = np.hstack([c[1] for c in cards])
    g = (np.clip(rel, 0, 1) * 255 + 0.5).astype(np.uint8)
    out = np.dstack([g, g, g, (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(out).save(OUT, optimize=True)
    print(OUT, out.shape)


if __name__ == "__main__":
    main()
