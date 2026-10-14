#!/usr/bin/env python3
"""P01: the Thủy Vân terrain array for R1 (style guide 3.1-3.3): twelve painted slices, 2048 x 2048 each, RGB albedo
with the light and occlusion painted in, A = blend height (0.6 x normalised stroke height + 0.4 x big-stroke mask).

    python3 tools/thuyvan_art/paint/paint_terrain.py [--size 2048] [--only grass,moss_fern] [--preview]

Writes assets/thuyvan/paint/terrain/tv_terrain_albedo_array.webp: the twelve slices as a 3 x 4 grid (6144 x 8192,
lossless WebP; a 12-slice vertical strip would pass WebP's 16383 px limit), slice i at column i % 3, row i // 3,
imported as a CompressedTexture2DArray (slices/horizontal=3, slices/vertical=4); otherwise the frontier's format
(assets/environment/terrain/textures/terrain_albedo_array.webp: RGB albedo, A height for the height blend). Also
terrain_slices.json (order, tile metres, mean colours: the grass cards' root colours read it), per-slice PNGs and the
check images (3 x 3 tiling + squint) in look/PAINT/.

Slices (the style guide's nine, plus the wet river bank and the vertical cliff face the look task asked for, plus an
upland flower meadow for variety):
   0 grass          lush grass, 8 m                    6 karst_rock     broken limestone ground and scree, 8 m
   1 terrace_rice   rice in rows 0.25 m apart, 8 m     7 white_stone    Đá Trắng gravel and pebbles, 8 m
   2 forest_floor   litter, twigs, moss, 8 m           8 moss_fern      moss cushions and fern fronds, 8 m
   3 dirt_path      foot-worn earth, pebbles, 8 m      9 river_bank     wet silt, pebbles, sheen, 8 m
   4 laterite       red earth banks, 8 m              10 cliff_face     strata, fluting, streaks (triplanar), 16 m
   5 paddy_mud      wet terrace mud, sky glints, 8 m  11 meadow         upland meadow with flowers, 8 m
"""
import argparse
import json
import math
import os
import sys
import time

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvp  # noqa: E402
from tvp import lin, mix, ramp  # noqa: E402

SLICES = [  # index, key, ramp, tile metres, value budget (sRGB mean)
    (0, "grass", "grass", 8.0, 0.45),
    (1, "terrace_rice", "terrace_rice", 8.0, 0.55),
    (2, "forest_floor", "forest_floor", 8.0, 0.30),
    (3, "dirt_path", "dirt_path", 8.0, 0.52),
    (4, "laterite", "laterite", 8.0, 0.45),
    (5, "paddy_mud", "paddy_mud", 8.0, 0.38),
    (6, "karst_rock", "karst_limestone", 8.0, 0.56),
    (7, "white_stone", "white_stone", 8.0, 0.80),
    (8, "moss_fern", "moss", 8.0, 0.40),
    (9, "river_bank", "paddy_mud", 8.0, 0.42),
    (10, "cliff_face", "karst_limestone", 16.0, 0.52),
    (11, "meadow", "grass", 8.0, 0.50),
]


def ground_up(rng):
    """Ground slivers: random direction, 60/40 bias to -V (style guide 3.2 step 4: no fixed sun on the ground)."""
    a = rng.normal(-math.pi / 2, 1.1) if rng.random() < 0.6 else rng.uniform(0, 2 * math.pi)
    return (math.cos(a), math.sin(a))


def rand_xy(cv):
    return cv.rng.uniform(0, cv.w), cv.rng.uniform(0, cv.h)


# ------------------------------------------------------------------ shared passes

def patches(cv, n, size_m=(0.5, 1.6), aspect=(1.1, 2.2), tones=(0.15, 0.85), ang=None, opacity=(0.45, 0.8),
            h=1.0, edge=0.5, wob=0.18, power=2.0, bristle=0.45, ramp4=None):
    """Big brush patches (style guide step 3): 6-20% of the tile, each a two-colour loaded stroke at partial
    opacity, so the ground breathes in soft, painted blobs."""
    rng = cv.rng
    r4 = cv.ramp if ramp4 is None else ramp4
    for _ in range(n):
        x, y = rand_xy(cv)
        L = cv.px(rng.uniform(*size_m))
        asp = rng.uniform(*aspect)
        a = ang(rng) if ang else rng.uniform(0, math.pi)
        t = rng.uniform(*tones)
        c1 = cv.vary(tvp.ramp_at(r4, t), x, y)
        c2 = cv.vary(tvp.ramp_at(r4, t + rng.uniform(-0.15, 0.15)), x, y)
        cv.dab(x, y, L, L / asp, a, c1, color2=c2, h_add=h, big=True, wob=wob, edge=edge,
               opacity=rng.uniform(*opacity), power=power, bristle=bristle, dry=0.5)


def strokes(cv, n, len_m=(0.06, 0.16), width_m=(0.015, 0.035), ang=None, tones=(0.2, 0.95), up=None, taper=0.6,
            h=0.5, density=None, tone_bias=None, dark_amt=0.8, light_amt=0.8, opacity=1.0, edge=0.6, ramp4=None,
            light_col=None, bend=0.3, power=2.0, dark_off=0.3, light_off=0.35):
    """Medium strokes with painted light (step 4): dark copy below, the body, a light sliver on top."""
    rng = cv.rng
    r4 = cv.ramp if ramp4 is None else ramp4
    k = 0
    tries = 0
    while k < n and tries < n * 20:
        tries += 1
        x, y = rand_xy(cv)
        dval = 0.0
        if density is not None:
            dval = density[int(y) % cv.h, int(x) % cv.w]
            if rng.random() > dval:
                continue
        k += 1
        L = cv.px(rng.uniform(*len_m)) * 0.5
        W = cv.px(rng.uniform(*width_m)) * 0.5
        a = ang(rng) if ang else rng.uniform(0, math.pi)
        t = rng.uniform(*tones)
        if tone_bias is not None:
            t = min(max(t + tone_bias[int(y) % cv.h, int(x) % cv.w], 0.0), 1.0)
        body = cv.vary(tvp.ramp_at(r4, t), x, y)
        dark = cv.vary(tvp.ramp_at(r4, max(t - 0.45, 0.0)), x, y)
        light = cv.vary(light_col if light_col is not None else mix(tvp.ramp_at(r4, min(t + 0.35, 1.0)), r4[3], 0.3),
                        x, y)
        u = up(rng, a) if up else ground_up(rng)
        cv.stroke3(x, y, L, W, a, body, dark, light, up=u, h_add=h, taper=taper, wob=0.06, edge=edge,
                   bend=bend * rng.uniform(-1, 1), dark_amt=dark_amt, light_amt=light_amt, opacity=opacity,
                   power=power, dark_off=dark_off, light_off=light_off)


def big_pass(cv, n, size_frac=(0.06, 0.20), aspect=(1.5, 3.0), ang=None, weights=(0.2, 0.45, 0.3, 0.05),
             h=1.0, wob=0.12, edge=0.7, opacity=1.0, power=2.0):
    """Big strokes sized as a fraction of the tile (the trim sheet's strips use this)."""
    rng = cv.rng
    for _ in range(n):
        x, y = rand_xy(cv)
        L = rng.uniform(*size_frac) * cv.w * 0.5
        asp = rng.uniform(*aspect)
        a = ang(rng) if ang else rng.uniform(0, math.pi)
        c = cv.vary(cv.pick(weights), x, y)
        cv.dab(x, y, L, L / asp, a, c, color2=cv.vary(cv.pick(weights), x, y), h_add=h, big=True, wob=wob,
               edge=edge, opacity=opacity * rng.uniform(0.6, 1.0), power=power)


def medium_pass(cv, n, size_frac=(0.02, 0.06), aspect=(1.6, 3.5), ang=None, up=None, h=0.5, ramp4=None,
                body_w=(0.55, 0.45), taper=0.0, wob=0.10, power=2.0, bend=0.0, dark_amt=0.9, opacity=1.0):
    """Medium three-pass strokes sized as a fraction of the tile (the trim sheet's strips use this)."""
    rng = cv.rng
    r4 = cv.ramp if ramp4 is None else ramp4
    for _ in range(n):
        x, y = rand_xy(cv)
        L = rng.uniform(*size_frac) * cv.w * 0.5
        asp = rng.uniform(*aspect)
        a = ang(rng) if ang else rng.uniform(0, math.pi)
        body = cv.vary(r4[1] if rng.random() < body_w[0] else r4[2], x, y)
        dark = cv.vary(r4[0], x, y)
        light = cv.vary(mix(r4[2], r4[3], 0.35), x, y)
        u = up(rng) if up else ground_up(rng)
        cv.stroke3(x, y, L, L / asp, a, body, dark, light, up=u, h_add=h, taper=taper, wob=wob, power=power,
                   bend=bend * rng.uniform(-1, 1), dark_amt=dark_amt, opacity=opacity)


def blade_up(rng, a):
    return (math.cos(a), math.sin(a))


def pebble(cv, x, y, r, r4, t=None, up=None, flat=1.4, h=0.8, dark_amt=0.85, shade=0.3, poly=False, light_amt=0.8):
    rng = cv.rng
    t = rng.uniform(0.45, 0.95) if t is None else t
    body = cv.vary(tvp.ramp_at(r4, t), x, y, jit=0.05)
    light = cv.vary(mix(tvp.ramp_at(r4, min(t + 0.3, 1.0)), r4[3], 0.4), x, y)
    dark = cv.vary(tvp.ramp_at(r4, max(t - 0.6, 0.0)), x, y)
    u = up if up is not None else (rng.normal(0, 0.4), -1.0)
    pl = tvp.random_poly(rng, (5, 8), jitter=0.3) if poly else None
    cv.stroke3(x, y, r, r / rng.uniform(1.05, flat), rng.uniform(0, math.pi), body, dark, light, up=u, h_add=h,
               power=rng.uniform(2.0, 2.6), wob=0.10, edge=0.72, dark_off=0.25, light_off=0.32, light_amt=light_amt,
               dark_amt=dark_amt, shade=shade, poly=pl, bristle=0.15, streak=0.03)


def flowers(cv, n_clusters, per=(3, 8), size_m=(0.025, 0.045), spread_m=0.14, cols=None, dark=None):
    rng = cv.rng
    fl = ramp("flowers")
    cols = cols if cols is not None else [fl[0], fl[1], fl[2], fl[3]]
    for _ in range(n_clusters):
        x, y = rand_xy(cv)
        c = cols[rng.integers(0, len(cols))]
        for _ in range(rng.integers(*per)):
            px, py = x + rng.normal(0, cv.px(spread_m)), y + rng.normal(0, cv.px(spread_m) * 0.8)
            rr = cv.px(rng.uniform(*size_m))
            cv.stroke3(px, py, rr, rr * 0.85, rng.uniform(0, 3.1), cv.vary(c, px, py, jit=0.06),
                       cv.ramp[0] if dark is None else dark, mix(c, lin("#fffbe8"), 0.45), up=(0, -1), h_add=0.4,
                       edge=0.62, shade=0.3, bristle=0.1, dark_off=0.35)


def scatter_packed(rng, w, h, rmin, rmax, count, tries=30, overlap=0.78, power=2.2):
    """Big-first, roughly non-overlapping disc placement on the torus."""
    radii = np.sort(rng.uniform(0, 1, count) ** power * (rmax - rmin) + rmin)[::-1]
    pts = []
    cell = rmax * 2
    grid = {}
    gw, gh = int(math.ceil(w / cell)), int(math.ceil(h / cell))
    for r in radii:
        for _ in range(tries):
            x, y = rng.uniform(0, w), rng.uniform(0, h)
            gx, gy = int(x / cell) % gw, int(y / cell) % gh
            ok = True
            for j in (-1, 0, 1):
                for i in (-1, 0, 1):
                    for (px, py, pr) in grid.get(((gx + i) % gw, (gy + j) % gh), ()):
                        ddx = (x - px + w / 2) % w - w / 2
                        ddy = (y - py + h / 2) % h - h / 2
                        if ddx * ddx + ddy * ddy < ((r + pr) * overlap) ** 2:
                            ok = False
                            break
                    if not ok:
                        break
                if not ok:
                    break
            if ok:
                pts.append((x, y, r))
                grid.setdefault((gx, gy), []).append((x, y, r))
                break
    return pts


def scrub(cv, n, len_m=(0.2, 0.5), width_m=(0.03, 0.08), ang=None, amt=0.14, opacity=(0.25, 0.5), mask=None,
          up_bias=0.0):
    """Dry-brush scrub: short bristly strokes that re-state the colour already under them a little lighter or darker
    (+-amt in value). Adds the hand-painted grain to smooth planes without changing their tone."""
    rng = cv.rng
    k = 0
    tries = 0
    while k < n and tries < n * 10:
        tries += 1
        x, y = rand_xy(cv)
        iy, ix = int(y) % cv.h, int(x) % cv.w
        if mask is not None and rng.random() > mask[iy, ix]:
            continue
        k += 1
        c = cv.col[iy, ix]
        d = rng.uniform(-amt, amt) + up_bias
        c = tvp.jitter(c, dv=d, ds=rng.uniform(-0.08, 0.08))
        a = ang(rng) if ang else rng.uniform(0, math.pi)
        cv.dab(x, y, cv.px(rng.uniform(*len_m)) * 0.5, cv.px(rng.uniform(*width_m)) * 0.5, a, c,
               opacity=rng.uniform(*opacity), edge=0.45, bristle=0.7, dry=0.7, wob=0.08, taper=0.35)


def lf_density(cv, kmax=5, kmin=2, lo=0.25, hi=1.0):
    f = tvp.periodic_field(cv.h, cv.w, cv.rng, kmax, kmin)
    return lo + (hi - lo) * tvp.smoothstep(-0.6, 0.6, f)


# ------------------------------------------------------------------ materials

def m_grass(cv, meadow=False):
    """Lush grass: soft painted patches (lighter sunny drifts, darker blue-green hollows), then thousands of short
    blade strokes leaning +-25 deg from texture-up, each with a dark root copy and a lit tip, densest in the
    drifts; a few flowers. Reads as a painted lawn from 30 m and as brushed blades at your feet."""
    rng = cv.rng
    r4 = cv.ramp
    if meadow:
        tr = ramp("terrace_rice")
        r4 = np.stack([r4[0], mix(r4[1], tr[1], 0.45), mix(r4[2], tr[2], 0.5), mix(r4[3], tr[3], 0.5)])
        cv.ramp = r4
    cv.base(dv=0.12, dh=8.0)
    vert = lambda r: -math.pi / 2 + r.uniform(-0.45, 0.45)
    # cool blue-green hollows and warm sunny drifts (the WoW ground breathes in hue as well as value)
    hollow = np.stack([mix(r4[0], lin(tvp.AO_GREEN), 0.5), mix(r4[0], r4[1], 0.5), r4[1], r4[1]])
    sunny = np.stack([r4[1], r4[2], mix(r4[2], r4[3], 0.6), r4[3]])
    patches(cv, 26, size_m=(0.8, 1.9), tones=(0.1, 0.8), opacity=(0.45, 0.7), ang=vert, ramp4=hollow)
    patches(cv, 26, size_m=(0.8, 1.9), tones=(0.1, 0.8), opacity=(0.35, 0.6), ang=vert, ramp4=sunny)
    patches(cv, 40, size_m=(0.5, 1.4), tones=(0.15, 0.9), opacity=(0.35, 0.6), ang=vert)
    tb = tvp.periodic_field(cv.h, cv.w, rng, 6, 2) * 0.3
    dens = lf_density(cv, 6, 2, 0.35, 1.0)
    # under-layer: broad soft blade strokes (the body of the turf)
    strokes(cv, 1600 if not meadow else 1300, len_m=(0.12, 0.26), width_m=(0.04, 0.07), ang=vert, tones=(0.1, 0.7),
            up=blade_up, taper=0.75, tone_bias=tb, dark_amt=0.55, light_amt=0.4, h=0.4, bend=0.25)
    # top layer: crisp lit blades in clumps
    strokes(cv, 5200 if not meadow else 4200, len_m=(0.07, 0.18), width_m=(0.016, 0.03), ang=vert,
            tones=(0.35, 1.0), up=blade_up, taper=0.85, density=dens, tone_bias=tb, dark_amt=0.75, light_amt=0.85,
            h=0.55, bend=0.35)
    cv.cavity(k=0.38, cool=tvp.AO_GREEN, sigma_frac=1 / 64.0)
    if meadow:
        flowers(cv, 110, per=(4, 10), spread_m=0.16)
        clover = mix(r4[2], lin("#f2eedc"), 0.55)
        flowers(cv, 60, per=(5, 12), size_m=(0.02, 0.03), spread_m=0.2, cols=[clover])
    else:
        flowers(cv, 28, per=(3, 7))
    # sparse warm tips (accent)
    strokes(cv, 260, len_m=(0.06, 0.12), width_m=(0.012, 0.02), ang=vert, tones=(0.85, 1.0), up=blade_up, taper=0.9,
            h=0.3, ramp4=np.stack([r4[1], r4[2], r4[3], r4[3]]), dark_amt=0.4)


def m_terrace_rice(cv):
    """Rice on the terrace steps: a dense, warm yellow-green turf of upright blades gathered into loose rows 0.25 m
    apart along the contour (texture U); the furrows between the rows sit darker and wet, with a few soft sky glints.
    Reads as bright painted rows at 20 m and as rice clumps at your feet, never as a ruled stripe."""
    r4 = cv.ramp
    rng = cv.rng
    mud = ramp("paddy_mud")
    cv.base(color=mix(r4[1], r4[0], 0.35), dv=0.1)
    pitch = cv.px(0.25)
    rows = int(round(cv.h / pitch))
    pitch = cv.h / rows
    Y = np.arange(cv.h, dtype=np.float32)[:, None]
    wave = tvp.periodic_field(cv.h, cv.w, rng, 3, 1) * pitch * 0.35
    phase = (Y + wave) / pitch * 2 * math.pi
    rowness = 0.5 + 0.5 * np.cos(phase)  # 1 on a row, 0 in a furrow
    breakup = tvp.smoothstep(-0.7, 0.4, tvp.periodic_field(cv.h, cv.w, rng, 10, 3, slope=0.6))
    dens = np.clip(0.25 + 0.75 * rowness ** 1.5 * (0.55 + 0.45 * breakup), 0, 1)
    patches(cv, 50, size_m=(0.7, 1.8), aspect=(2.0, 4.0), tones=(0.2, 0.85), opacity=(0.3, 0.55),
            ang=lambda r: r.uniform(-0.1, 0.1), bristle=0.3)
    fur = (1.0 - rowness) ** 3 * (0.6 + 0.4 * breakup)
    water = mix(mud[1], mud[3], 0.35)
    cv.col = mix(cv.col, np.broadcast_to(water, cv.col.shape), (fur * 0.55)[..., None])
    cv.ht -= fur * 0.6
    tb = (rowness - 0.5) * 0.35 + tvp.periodic_field(cv.h, cv.w, rng, 4, 1) * 0.15
    vert = lambda r: -math.pi / 2 + r.uniform(-0.5, 0.5)
    strokes(cv, 2600, len_m=(0.1, 0.2), width_m=(0.025, 0.045), ang=vert, tones=(0.15, 0.7), up=blade_up,
            taper=0.75, density=dens, tone_bias=tb, dark_amt=0.6, light_amt=0.4, h=0.45, bend=0.25)
    strokes(cv, 6000, len_m=(0.07, 0.16), width_m=(0.012, 0.022), ang=vert, tones=(0.4, 1.0), up=blade_up,
            taper=0.88, density=dens, tone_bias=tb, dark_amt=0.7, light_amt=0.85, h=0.55, bend=0.4)
    cv.cavity(k=0.32, cool=tvp.AO_GREEN, sigma_frac=1 / 64.0)
    glint = mix(mud[3], r4[2], 0.25)
    for _ in range(90):
        x, y = rand_xy(cv)
        if fur[int(y) % cv.h, int(x) % cv.w] < 0.35:
            continue
        cv.dab(x, y, cv.px(rng.uniform(0.04, 0.1)), cv.px(0.008), rng.uniform(-0.05, 0.05), cv.vary(glint, x, y),
               wob=0.05, opacity=0.55, bristle=0.4)


def m_forest_floor(cv):
    """Dark olive-brown floor under the trees: soft patches, moss islands, a carpet of leaf dabs (warm and olive,
    each with a dark underside), twigs."""
    r4 = cv.ramp
    rng = cv.rng
    moss = ramp("moss")
    cv.base(dv=0.10)
    patches(cv, 70, size_m=(0.5, 1.5), tones=(0.1, 0.8), opacity=(0.4, 0.75))
    for _ in range(26):  # moss islands
        x, y = rand_xy(cv)
        L = cv.px(rng.uniform(0.3, 0.7))
        c = cv.vary(mix(moss[1], r4[1], 0.55), x, y)
        cv.dab(x, y, L, L / rng.uniform(1.2, 2.0), rng.uniform(0, 3.1), c,
               color2=cv.vary(mix(moss[1], r4[2], 0.5), x, y), h_add=0.6, big=True, wob=0.3, edge=0.35,
               opacity=0.5, bristle=0.5, dry=0.6)
    leaf = np.stack([r4[0], mix(r4[1], r4[3], 0.5), r4[3], mix(r4[3], lin("#d0a050"), 0.4)])
    strokes(cv, 2600, len_m=(0.05, 0.1), width_m=(0.025, 0.045), tones=(0.2, 1.0), taper=0.45, ramp4=leaf, h=0.4,
            dark_amt=0.85, light_amt=0.6, bend=0.4, power=1.7)
    olive = np.stack([r4[0], r4[1], r4[2], moss[2]])
    strokes(cv, 900, len_m=(0.04, 0.08), width_m=(0.02, 0.035), tones=(0.3, 1.0), taper=0.45, ramp4=olive, h=0.35,
            dark_amt=0.8, light_amt=0.6, power=1.7)
    for _ in range(80):  # twigs
        x, y = rand_xy(cv)
        L = cv.px(rng.uniform(0.12, 0.35))
        cv.stroke3(x, y, L, cv.px(0.011), rng.uniform(0, 3.14), cv.vary(lin("#5a4630"), x, y), r4[0],
                   lin("#8a7050"), up=ground_up(rng), h_add=0.4, wob=0.02, bend=rng.uniform(-0.6, 0.6), bristle=0.1)
    cv.cavity(k=0.45, cool=tvp.AO_GREEN, sigma_frac=1 / 64.0)


def m_dirt_path(cv, r4=None, n_peb=420, strata=False, cool="#5a4a58"):
    """Foot-worn earth: warm soft patches (worn lighter in the middle of drifts), flat smeared strokes, small cracks,
    and flat pebbles 5-15 cm with a lit top and a dark underside."""
    r4 = cv.ramp if r4 is None else r4
    rng = cv.rng
    cv.base(dv=0.10)
    patches(cv, 80, size_m=(0.5, 1.6), tones=(0.25, 0.95), opacity=(0.4, 0.75), power=2.2, bristle=0.25)
    if strata:
        for _ in range(30):
            x, y = rand_xy(cv)
            L = cv.w * rng.uniform(0.15, 0.35)
            cv.dab(x, y, L, cv.px(rng.uniform(0.02, 0.05)), rng.uniform(-0.06, 0.06),
                   cv.vary(tvp.ramp_at(r4, 0.15 if rng.random() < 0.5 else 0.9), x, y), opacity=0.45, wob=0.08,
                   h_add=0.2, bristle=0.6, dry=0.6)
    strokes(cv, 1500, len_m=(0.12, 0.3), width_m=(0.04, 0.08), ang=lambda r: r.uniform(-0.5, 0.5), tones=(0.25, 0.9),
            taper=0.4, h=0.35, dark_amt=0.35, light_amt=0.45, power=2.3, bend=0.2)
    for _ in range(60):  # cracks
        x, y = rand_xy(cv)
        L = cv.px(rng.uniform(0.1, 0.3))
        cv.dab(x, y, L, cv.px(0.008), rng.uniform(0, 3.1), cv.vary(r4[0], x, y), h_add=-0.4, wob=0.02, opacity=0.65,
               bend=rng.uniform(-0.8, 0.8), bristle=0.3, dry=0.6)
    stone = ramp("white_stone")
    pr = np.stack([mix(r4[0], stone[0], 0.3), mix(r4[1], stone[1], 0.35), mix(r4[2], stone[2], 0.35), r4[3]])
    for (x, y, rr) in scatter_packed(rng, cv.w, cv.h, cv.px(0.02), cv.px(0.08), n_peb, overlap=1.0, power=3.0):
        pebble(cv, x, y, rr, pr, flat=1.8, h=0.7)
    cv.cavity(k=0.40, cool=cool, sigma_frac=1 / 64.0)


def m_laterite(cv):
    m_dirt_path(cv, n_peb=360, strata=True, cool="#4e3044")


def m_paddy_mud(cv):
    """Wet terrace mud: two values, smooth long strokes, sky glints, drowned straw."""
    r4 = cv.ramp
    rng = cv.rng
    cv.base(dv=0.06)
    patches(cv, 70, size_m=(0.5, 1.8), aspect=(1.5, 3.0), tones=(0.1, 0.6), opacity=(0.35, 0.65), h=0.6,
            ang=lambda r: r.uniform(-0.3, 0.3), bristle=0.55)
    strokes(cv, 900, len_m=(0.2, 0.5), width_m=(0.04, 0.09), ang=lambda r: r.uniform(-0.3, 0.3), tones=(0.1, 0.75),
            taper=0.5, h=0.25, dark_amt=0.35, light_amt=0.3, power=2.2, bend=0.15)
    cv.cavity(k=0.3, cool="#2c3a40", sigma_frac=1 / 64.0)
    sky = r4[3]
    for _ in range(260):
        x, y = rand_xy(cv)
        L = cv.px(rng.uniform(0.05, 0.2))
        cv.dab(x, y, L, L / rng.uniform(4, 9), rng.uniform(-0.15, 0.15), cv.vary(sky, x, y), wob=0.08,
               opacity=rng.uniform(0.45, 0.85), bristle=0.4, dry=0.5)
    for _ in range(70):
        x, y = rand_xy(cv)
        L = cv.px(rng.uniform(0.04, 0.09))
        cv.dab(x, y, L, cv.px(0.008), rng.uniform(0, 3.1), cv.vary(lin("#8a7a48"), x, y), opacity=0.8, wob=0.02,
               bristle=0.1)


def m_river_bank(cv):
    """Wet river bank: dark silt and sand in soft wet patches, rounded stones gathered in drifts (grey-white, wet, so
    darker than the dry Đá Trắng gravel, with a glossy glint), damp sheen streaks along the water line (U)."""
    r4 = cv.ramp
    rng = cv.rng
    sand = ramp("dirt_path")
    stone = ramp("white_stone")
    bank = np.stack([r4[0], mix(r4[1], sand[1], 0.35), mix(r4[2], sand[2], 0.4), r4[3]])
    cv.ramp = bank
    cv.base(dv=0.08)
    patches(cv, 75, size_m=(0.4, 1.4), tones=(0.1, 0.85), opacity=(0.4, 0.75), ang=lambda r: r.uniform(-0.4, 0.4),
            aspect=(1.4, 3.0), bristle=0.3)
    strokes(cv, 1200, len_m=(0.15, 0.4), width_m=(0.03, 0.07), ang=lambda r: r.uniform(-0.25, 0.25),
            tones=(0.15, 0.85), taper=0.5, h=0.3, dark_amt=0.35, light_amt=0.35, bend=0.15)
    drift = tvp.smoothstep(-0.3, 0.5, tvp.periodic_field(cv.h, cv.w, rng, 5, 2))
    wet = np.stack([mix(stone[0], r4[0], 0.45), mix(stone[1], bank[1], 0.35), mix(stone[2], bank[2], 0.2),
                    stone[3]])
    for (x, y, rr) in scatter_packed(rng, cv.w, cv.h, cv.px(0.03), cv.px(0.22), 1600, overlap=0.85, power=2.6):
        if rng.random() > 0.15 + 0.85 * drift[int(y) % cv.h, int(x) % cv.w]:
            continue
        pebble(cv, x, y, rr, wet, t=rng.uniform(0.3, 0.85), flat=1.5, h=0.9, shade=0.4, light_amt=0.6)
        if rr > cv.px(0.06) and rng.random() < 0.6:  # wet glint
            cv.dab(x - rr * 0.2, y - rr * 0.38, rr * 0.3, rr * 0.1, rng.uniform(-0.3, 0.3), lin("#eef4ee"),
                   opacity=0.7, bristle=0.0, streak=0.0)
    cv.cavity(k=0.45, cool="#2c3a48", sigma_frac=1 / 70.0)
    for _ in range(200):  # sheen streaks
        x, y = rand_xy(cv)
        L = cv.px(rng.uniform(0.08, 0.3))
        cv.dab(x, y, L, L / rng.uniform(6, 12), rng.uniform(-0.08, 0.08), cv.vary(mix(r4[3], bank[2], 0.4), x, y),
               wob=0.05, opacity=rng.uniform(0.3, 0.6), bristle=0.5, dry=0.6)


def m_karst_rock(cv):
    """Broken limestone ground and scree seen from above: chunky plates 0.3-1.4 m (a warped Voronoi), each graded
    lighter to its upper edge, split by soil-filled joints with grass blades and chips in them, lichen on top."""
    r4 = cv.ramp
    rng = cv.rng
    moss = ramp("moss")
    grass = ramp("grass")
    dirt = ramp("dirt_path")
    sites = [(x, y, rng.uniform(0.3, 0.92)) for (x, y, rr) in
             scatter_packed(rng, cv.w, cv.h, cv.px(0.12), cv.px(0.9), 300, overlap=1.0, power=2.6)]
    soil = mix(dirt[0], grass[0], 0.35)
    idx, e = rock_planes(cv, sites, crack_px=(cv.px(0.02), cv.px(0.16)), bevel_px=cv.px(0.14), grad=0.35,
                         warp_px=cv.px(0.1), strokes_per=4, stroke_ang=0.0, stroke_len=(0.15, 0.4),
                         stroke_w=(0.05, 0.12), strokes_vertical=0.0, facets=(1, 3), crack_col=soil,
                         joint_keep=0.7)
    for (x, y, rr) in scatter_packed(rng, cv.w, cv.h, cv.px(0.02), cv.px(0.06), 700, overlap=1.2, power=2.0):
        if e[int(y) % cv.h, int(x) % cv.w] > cv.px(0.1):
            continue
        pebble(cv, x, y, rr, r4, flat=1.6, h=0.6, poly=True, shade=0.25)
    cv.cavity(k=0.5, cool=tvp.AO_ROCK, sigma_frac=1 / 80.0, gamma=0.85)
    cv.edge_light(amt=0.28, sigma=1.2)
    for _ in range(110):  # lichen
        x, y = rand_xy(cv)
        L = cv.px(rng.uniform(0.04, 0.14))
        c = mix(moss[2], lin("#c9c09a"), rng.uniform(0.0, 0.7))
        cv.dab(x, y, L, L * rng.uniform(0.6, 0.9), rng.uniform(0, 3), cv.vary(c, x, y), opacity=0.5, wob=0.3,
               edge=0.45, bristle=0.5)
    jm = 1.0 - tvp.smoothstep(cv.px(0.02), cv.px(0.08), e)
    strokes(cv, 900, len_m=(0.06, 0.15), width_m=(0.012, 0.024), ang=lambda r: -math.pi / 2 + r.uniform(-0.5, 0.5),
            tones=(0.3, 1.0), up=blade_up, taper=0.85, density=jm, ramp4=grass, h=0.3, dark_amt=0.6)


def m_white_stone(cv):
    """Đá Trắng gravel: packed rounded pebbles 5-40 cm, very pale cream to cool grey, painted as rounded forms (lit
    warm top, cool shaded side), cool-grey AO between them; the brightest ground."""
    r4 = cv.ramp
    rng = cv.rng
    cv.base(color=mix(r4[0], r4[1], 0.45))
    patches(cv, 40, size_m=(0.4, 1.2), tones=(0.0, 0.5), opacity=(0.4, 0.7), h=0.1)
    tints = [r4[2], r4[3], r4[1], mix(r4[2], lin("#e2d6b8"), 0.6), mix(r4[1], lin("#b9c6c8"), 0.5)]
    for (x, y, rr) in scatter_packed(rng, cv.w, cv.h, cv.px(0.025), cv.px(0.22), 2900, overlap=0.8):
        c = cv.vary(tints[rng.choice(5, p=[0.32, 0.18, 0.2, 0.18, 0.12])], x, y, jit=0.04)
        u = (rng.normal(0, 0.35), -1.0) if rng.random() < 0.6 else ground_up(rng)
        cv.stroke3(x, y, rr, rr / rng.uniform(1.05, 1.45), rng.uniform(0, math.pi), c, mix(r4[0], c, 0.3),
                   mix(c, r4[3], 0.75), up=u, h_add=1.0 if rr > cv.px(0.1) else 0.7, power=rng.uniform(2.0, 2.5),
                   wob=0.1, edge=0.72, dark_off=0.22, light_off=0.3, light_amt=0.8, dark_amt=0.7, shade=0.35,
                   bristle=0.15, streak=0.025)
        if rr > cv.px(0.1):
            cv.big[int(y) % cv.h, int(x) % cv.w] = 1
    cv.cavity(k=0.5, cool="#6c7890", sigma_frac=1 / 90.0, gamma=0.75)
    for _ in range(80):
        x, y = rand_xy(cv)
        L = cv.px(rng.uniform(0.02, 0.05))
        c = lin("#c9c09a") if rng.random() < 0.6 else lin("#9fc6be")
        cv.dab(x, y, L, L * 0.7, rng.uniform(0, 3), c, opacity=0.45, wob=0.1)


def m_moss_fern(cv, ferns=True):
    """Moss and fern ground under the spray: soft moss cushions (irregular lumps 0.2-0.5 m with a lit top and a dark
    hollow), stippled with short dabbing strokes, then fern fronds lying over them."""
    r4 = cv.ramp
    rng = cv.rng
    fern = ramp("fern")
    cv.base(dv=0.1)
    patches(cv, 60, size_m=(0.5, 1.4), aspect=(1.1, 1.8), tones=(0.1, 0.8), opacity=(0.4, 0.7), bristle=0.3)
    for (x, y, rr) in scatter_packed(rng, cv.w, cv.h, cv.px(0.12), cv.px(0.35), 600, overlap=0.55):
        t = rng.uniform(0.3, 0.85)
        cv.stroke3(x, y, rr, rr * rng.uniform(0.6, 0.9), rng.uniform(0, 3), cv.vary(tvp.ramp_at(r4, t), x, y),
                   cv.vary(tvp.ramp_at(r4, t - 0.5), x, y), mix(tvp.ramp_at(r4, min(t + 0.35, 1)), r4[3], 0.35),
                   up=(rng.normal(0, 0.4), -1.0), h_add=0.8, wob=0.3, edge=0.55, dark_off=0.3, light_off=0.3,
                   shade=0.45, bristle=0.3, light_amt=0.6)
    hb = tvp.blur(cv.ht, cv.px(0.05))
    hb = (hb - hb.min()) / max(float(np.ptp(hb)), 1e-6)
    strokes(cv, 3500, len_m=(0.03, 0.06), width_m=(0.015, 0.03), tones=(0.1, 0.8), taper=0.3, h=0.2,
            tone_bias=(hb - 0.5) * 0.5, dark_amt=0.5, light_amt=0.5, power=1.8, opacity=0.8)
    cv.cavity(k=0.45, cool=tvp.AO_GREEN, sigma_frac=1 / 60.0)
    for _ in range(36 if ferns else 0):  # fern fronds: a stem with paired, tapering leaflets
        x, y = rand_xy(cv)
        a = rng.uniform(0, 6.283)
        L = cv.px(rng.uniform(0.45, 0.85))
        nl = 11
        for i in range(nl):
            t = (i + 0.5) / nl
            px, py = x + math.cos(a) * L * t, y + math.sin(a) * L * t
            ll = cv.px(0.13) * (1.0 - 0.75 * t)
            for sgn in (-1, 1):
                aa = a + sgn * 1.05
                cv.stroke3(px + math.cos(aa) * ll * 0.6, py + math.sin(aa) * ll * 0.6, ll, ll * 0.3, aa,
                           cv.vary(fern[2] if i % 2 else mix(fern[1], fern[2], 0.5), px, py), fern[0], fern[3],
                           up=(math.cos(a + math.pi), math.sin(a + math.pi)), h_add=0.5, taper=0.7, wob=0.03,
                           edge=0.6, dark_off=0.35, bristle=0.2, dark_amt=0.9)
        cv.dab(x + math.cos(a) * L / 2, y + math.sin(a) * L / 2, L / 2, cv.px(0.012), a, fern[0], wob=0.0,
               bristle=0.0)


def rock_planes(cv, sites, sx=1.0, sy=1.0, crack_px=(4, 9), bevel_px=14, grad=0.28, warp_px=10, crack_col=None,
                strokes_per=6, stroke_ang=0.0, stroke_len=(0.3, 0.7), stroke_w=(0.06, 0.18), lit_rim=0.8,
                strokes_vertical=0.3, joint_keep=1.0, facets=(1, 3)):
    """Chunky painted rock planes: a warped periodic Voronoi of `sites` [(x, y, tone)], each cell one plane of one
    tone graded lighter toward its top (texture -V), bevelled into a height plateau, split by dark cracks of varying
    width; then brush strokes inside each plane (bristle streaks along the strata, a few vertical drips) so the
    planes read painted, not flat. Returns (cell index map, border distance)."""
    rng = cv.rng
    r4 = cv.ramp
    crack_col = mix(r4[0], lin("#5a4a50"), 0.5) if crack_col is None else crack_col
    pts = [(x, y) for (x, y, _) in sites]
    wf = cv.warp(warp_px, kmax=8, kmin=3) if warp_px else None
    idx, d1, d2 = tvp.voronoi(cv.h, cv.w, pts, sx, sy, warp=wf, reach=4.0 * math.sqrt(cv.h * cv.w / len(pts)) / min(sx, sy))
    e = (d2 - d1) * 0.5
    tones = np.array([t for (_, _, t) in sites], np.float32)
    cy = np.array([y for (_, y, _) in sites], np.float32)
    Y = np.arange(cv.h, dtype=np.float32)[:, None]
    dy = (Y - cy[idx] + cv.h / 2) % cv.h - cv.h / 2
    # cell half-height: the largest |dy| seen inside each cell
    hh = np.zeros(len(sites), np.float32)
    np.maximum.at(hh, idx.ravel(), np.abs(dy).ravel())
    g = dy / np.maximum(hh[idx], 1.0)
    t = tones[idx] - grad * g
    cv.col = tvp.ramp_map(r4, t)
    cw = rng.uniform(*crack_px, len(sites)).astype(np.float32)[idx]
    if joint_keep < 1.0:
        # joints across the strata (vertical borders) are thinner and break off; bedding cracks stay strong
        gy = np.abs(np.roll(e, -1, 0) - np.roll(e, 1, 0))
        gx = np.abs(np.roll(e, -1, 1) - np.roll(e, 1, 1))
        horiz = tvp.smoothstep(0.2, 0.8, gy / np.maximum(gx + gy, 1e-4))
        keep = tvp.smoothstep(-0.2, 0.3, tvp.periodic_field(cv.h, cv.w, rng, 14, 5, slope=0.5) + joint_keep - 0.5)
        cw = cw * (horiz + (1.0 - horiz) * 0.55 * keep)
    crack = 1.0 - tvp.smoothstep(cw * 0.35, np.maximum(cw, 0.5), e)
    cv.col = mix(cv.col, np.broadcast_to(crack_col, cv.col.shape), (crack * 0.92)[..., None])
    tilt = rng.uniform(-0.3, 0.3, len(sites)).astype(np.float32)
    cv.ht = tvp.smoothstep(0.0, bevel_px, e) * (1.0 + 0.25 * tones[idx] - 0.2 * g + tilt[idx] * 0.2)
    cv.big = (e > bevel_px).astype(np.float32)
    # brushwork inside each plane
    lit = mix(r4[2], r4[3], 0.5)
    for (x, y, tone) in sites:
        for k in range(strokes_per):
            fx = x + rng.normal(0, cv.px(0.5) / sx)
            fy = y + rng.normal(0, cv.px(0.25))
            vertical = rng.random() < strokes_vertical
            L = cv.px(rng.uniform(*stroke_len)) * (0.7 if vertical else 1.0)
            W = cv.px(rng.uniform(*stroke_w))
            a = (math.pi / 2 if vertical else stroke_ang) + rng.uniform(-0.12, 0.12)
            tt = tone + rng.uniform(-0.22, 0.22) - (0.15 if vertical else 0.0)
            c = cv.vary(tvp.ramp_at(r4, tt), fx, fy, jit=0.04)
            cv.dab(fx, fy, L, W, a, c, color2=cv.vary(tvp.ramp_at(r4, tt + rng.uniform(-0.15, 0.15)), fx, fy),
                   opacity=rng.uniform(0.3, 0.6), edge=0.5, bristle=0.65, dry=0.65, wob=0.1, taper=0.3)
    # facets: a lighter upper plane or a darker lower plane cut across some cells (chunky, carved forms)
    for (x, y, tone) in sites:
        for k in range(rng.integers(*facets)):
            up_plane = rng.random() < 0.55
            fx = x + rng.normal(0, cv.px(0.5) / sx)
            fy = y + (-1 if up_plane else 1) * cv.px(rng.uniform(0.1, 0.35))
            fl = cv.px(rng.uniform(0.5, 1.2))
            fc = tvp.ramp_at(r4, tone + (rng.uniform(0.12, 0.25) if up_plane else -rng.uniform(0.12, 0.25)))
            cv.dab(fx, fy, fl, fl / rng.uniform(1.6, 3.0), rng.uniform(-0.35, 0.35), cv.vary(fc, fx, fy),
                   wob=0.04, edge=0.6, poly=tvp.random_poly(rng, (4, 6), jitter=0.3), opacity=0.35, bristle=0.0,
                   streak=0.0, h_add=0.15 if up_plane else -0.1, hmode="add")
    scrub(cv, 3000,
          len_m=(stroke_len[0] * 0.5, stroke_len[1] * 0.6), width_m=(0.03, 0.08),
          ang=lambda r: stroke_ang + r.uniform(-0.15, 0.15), amt=0.16, opacity=(0.3, 0.55),
          mask=1.0 - crack)
    # keep the cracks crisp over the brushwork
    cv.col = mix(cv.col, np.broadcast_to(crack_col, cv.col.shape), (crack * 0.85)[..., None])
    cv.apply_lf(dv=0.08, dh=4.0, ds=0.1)
    return idx, e


def m_cliff_face(cv, fluting=1.0, streaks=1.0, moss_amt=1.0):
    """A vertical karst face lit from texture-up (-V): strata bands 0.8-1.8 m alternating in tone, each split into
    wide planes 1.5-5 m (a warped anisotropic Voronoi), every plane lighter at its top with a lit rim under the
    crack above it; vertical fluting, dark water streaks from the rims, moss on the ledges."""
    r4 = cv.ramp
    rng = cv.rng
    stain = ramp("cliff_stain")
    moss = ramp("moss")
    sites = []
    y = 0.0
    bands = []
    while y < cv.h:
        hb = cv.px(rng.uniform(0.8, 1.8))
        bands.append((y, hb))
        y += hb
    sc = cv.h / y
    for (y0, hb) in bands:
        y0, hb = y0 * sc, hb * sc
        band_t = rng.uniform(0.3, 0.85)
        x = rng.uniform(0, cv.w)
        x_end = x + cv.w
        while x < x_end - cv.px(0.8):
            wsl = cv.px(rng.uniform(1.0, 6.0) if rng.random() < 0.7 else rng.uniform(0.5, 1.2))
            sites.append(((x + wsl / 2) % cv.w, (y0 + hb * rng.uniform(0.3, 0.7)) % cv.h,
                          band_t + rng.uniform(-0.14, 0.14)))
            x += wsl
    rock_planes(cv, sites, sx=0.38, sy=1.0, crack_px=(cv.px(0.02), cv.px(0.055)), bevel_px=cv.px(0.1), grad=0.42,
                warp_px=cv.px(0.12), strokes_per=5, stroke_len=(0.4, 1.0), stroke_w=(0.08, 0.2), joint_keep=0.45,
                crack_col=mix(r4[0], lin("#5a4a50"), 0.35))
    for _ in range(int(30 * fluting)):  # broad vertical fluting
        x, yy = rand_xy(cv)
        L = cv.px(rng.uniform(1.0, 2.5))
        cv.dab(x, yy, L, cv.px(rng.uniform(0.2, 0.4)), math.pi / 2 + rng.uniform(-0.05, 0.05), cv.vary(r4[0], x, yy),
               wob=0.15, opacity=0.12, edge=0.2, taper=0.5, bristle=0.5)
    cv.cavity(k=0.5, cool=tvp.AO_ROCK, sigma_frac=1 / 96.0, gamma=0.9)
    e = cv.edge_light(amt=0.35, sigma=1.2)
    for _ in range(int(40 * streaks)):  # water streaks running down from the rims
        x, yy = rand_xy(cv)
        L = cv.px(rng.uniform(1.5, 4.5))
        cv.dab(x, yy + L, L, cv.px(rng.uniform(0.15, 0.45)), math.pi / 2, cv.vary(stain[rng.integers(0, 2)], x, yy),
               taper=0.8, wob=0.12, opacity=rng.uniform(0.2, 0.35), edge=0.2, bristle=0.7, dry=0.7)
    mm = tvp.blur(e, 6.0) * tvp.smoothstep(0.1, 0.7, tvp.periodic_field(cv.h, cv.w, rng, 6, 2))
    mm = tvp.smoothstep(0.25, 0.7, mm / max(mm.max(), 1e-6)) * 0.7 * moss_amt
    mc = mix(moss[0], moss[2], 0.55)
    cv.col = mix(cv.col, np.broadcast_to(mc, cv.col.shape), mm[..., None])


MATERIALS = {
    "grass": m_grass, "terrace_rice": m_terrace_rice, "forest_floor": m_forest_floor, "dirt_path": m_dirt_path,
    "laterite": m_laterite, "paddy_mud": m_paddy_mud, "karst_rock": m_karst_rock, "white_stone": m_white_stone,
    "moss_fern": m_moss_fern, "river_bank": m_river_bank, "cliff_face": m_cliff_face,
    "meadow": lambda cv: m_grass(cv, meadow=True),
}


def blend_height(cv, size):
    h = cv.ht - tvp.blur(cv.ht, size / 16.0)
    lo, hi = np.percentile(h, 1.0), np.percentile(h, 99.0)
    hn = np.clip((h - lo) / max(hi - lo, 1e-6), 0, 1)
    bigm = np.clip(tvp.blur(cv.big, 1.0) * 1.5, 0, 1)
    return np.clip(0.6 * hn + 0.4 * bigm, 0.0, 1.0)


def paint_slice(idx, key, rname, tile_m, budget, size, seed_base=7100):
    t0 = time.time()
    cv = tvp.Canvas(size, size, tile_m, seed_base + idx * 17, ramp(rname))
    MATERIALS[key](cv)
    # ground tiles repeat every 8 m: hold the patches above ~20 cm to +-0.1 of the tile mean (the 3 x 3 check), so
    # no tile-sized blotch repeats; the shader's macro variation (+-12 % over 60-250 m) carries the big breathing
    soft_ground = key in ("grass", "meadow", "terrace_rice", "forest_floor", "moss_fern", "paddy_mud")
    cv.finish(value_target=budget, squint=(0.05 if soft_ground else 0.1) if tile_m <= 8 else 0.16)
    rgb = tvp.l2s(cv.col)
    a = blend_height(cv, size)
    img = tvp.to_u8(np.concatenate([rgb, a[..., None]], -1))
    stats = tvp.squint_check(img, "terrain_%02d_%s" % (idx, key))
    stats["seconds"] = round(time.time() - t0, 1)
    stats["mean_srgb"] = [round(float(v), 4) for v in rgb.reshape(-1, 3).mean(0)]
    print("slice %2d %-14s %s" % (idx, key, stats), flush=True)
    return img, stats, cv


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=2048)
    ap.add_argument("--only", default="")
    ap.add_argument("--preview", action="store_true", help="write per-slice PNGs to look/PAINT only, no array")
    args = ap.parse_args()
    only = set(filter(None, args.only.split(",")))
    imgs, meta = [], []
    for idx, key, rname, tile_m, budget in SLICES:
        if only and key not in only:
            continue
        img, st, _ = paint_slice(idx, key, rname, tile_m, budget, args.size)
        Image.fromarray(img[..., :3]).save(tvp.look_path("slices/%02d_%s.png" % (idx, key)))
        imgs.append(img)
        meta.append({"slice": idx, "key": key, "ramp": rname, "tile_m": tile_m, "value_budget": budget, **st})
    if only or args.preview:
        return
    s = args.size
    cols, rows = 3, 4
    grid = np.zeros((rows * s, cols * s, 4), np.uint8)
    for i, im in enumerate(imgs):
        grid[(i // cols) * s:(i // cols + 1) * s, (i % cols) * s:(i % cols + 1) * s] = im
    p = tvp.save(grid, "terrain/tv_terrain_albedo_array.webp")
    with open(os.path.join(tvp.OUT, "terrain", "terrain_slices.json"), "w") as f:
        json.dump({"size": s, "grid": [cols, rows],
                   "layout": "3 x 4 grid, slice i at column i %% 3, row i // 3 (import: slices/horizontal=3, "
                             "slices/vertical=4)",
                   "alpha": "blend height: 0.6 x normalised stroke height + 0.4 x big-stroke mask",
                   "slices": meta}, f, indent=1)
    print("wrote", p, os.path.getsize(p) // 1024, "KB")


if __name__ == "__main__":
    main()
