#!/usr/bin/env python3
"""P01: the Thủy Vân terrain array for R1 (style guide 3.3): nine painted slices, 2048 x 2048 each over 8 m
(256 px/m; slice 6, the karst limestone, is painted for 16 m because the terrain shader samples it triplanar on slopes
over 38 deg at 16 m), RGB albedo with the light and occlusion painted in, A = blend height
(0.6 x normalised stroke height + 0.4 x big-stroke mask).

    python3 tools/thuyvan_art/paint/paint_terrain.py [--size 2048] [--only grass,moss]

Writes assets/thuyvan/paint/terrain/tv_terrain_albedo_array.webp: the nine slices as a 3 x 3 grid (6144 x 6144,
lossless WebP; a 9-slice vertical strip would pass WebP's 16383 px limit), the frontier's format otherwise
(terrain_albedo_array.webp), imported as a CompressedTexture2DArray (slices/horizontal=3, slices/vertical=3). Also terrain_slices.json (order, tile metres, mean colours: the grass
cards' root colours read it) and the check images in look/PAINT/checks/.
"""
import argparse
import json
import math
import os
import sys
import time

import numpy as np

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
    (6, "karst_limestone", "karst_limestone", 16.0, 0.62),
    (7, "white_stone", "white_stone", 8.0, 0.82),
    (8, "moss_fern", "moss", 8.0, 0.40),
]


def ground_up(rng):
    """Ground slivers: random direction, 60/40 bias to +V (style guide 3.2 step 4: no fixed sun on the ground)."""
    a = rng.normal(math.pi / 2, 1.1) if rng.random() < 0.6 else rng.uniform(0, 2 * math.pi)
    return (math.cos(a), math.sin(a))


def big_pass(cv, n, size_frac=(0.06, 0.20), aspect=(1.5, 3.0), ang=None, weights=(0.2, 0.45, 0.3, 0.05),
             h=1.0, wob=0.12, edge=0.75, opacity=1.0, power=2.0):
    rng = cv.rng
    for _ in range(n):
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = rng.uniform(*size_frac) * cv.w * 0.5
        asp = rng.uniform(*aspect)
        a = ang(rng) if ang else rng.uniform(0, math.pi)
        c = cv.vary(cv.pick(weights), x, y)
        cv.dab(x, y, L, L / asp, a, c, h_add=h, big=True, wob=wob, edge=edge, opacity=opacity, power=power)


def medium_pass(cv, n, size_frac=(0.02, 0.06), aspect=(1.6, 3.5), ang=None, up=None, h=0.5, ramp4=None,
                body_w=(0.55, 0.45), taper=0.0, wob=0.10, power=2.0, bend=0.0, dark_amt=0.9, opacity=1.0):
    rng = cv.rng
    r4 = cv.ramp if ramp4 is None else ramp4
    for _ in range(n):
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = rng.uniform(*size_frac) * cv.w * 0.5
        asp = rng.uniform(*aspect)
        a = ang(rng) if ang else rng.uniform(0, math.pi)
        body = cv.vary(r4[1] if rng.random() < body_w[0] else r4[2], x, y)
        dark = cv.vary(r4[0], x, y)
        light = cv.vary(mix(r4[2], r4[3], 0.35), x, y)
        u = up(rng) if up else ground_up(rng)
        cv.stroke3(x, y, L, L / asp, a, body, dark, light, up=u, h_add=h, taper=taper, wob=wob, power=power,
                   bend=bend * rng.uniform(-1, 1), dark_amt=dark_amt, opacity=opacity)


def tuft(cv, x, y, blade_len, blade_w, r4, nblades=(3, 6), lean=0.45, light_tip=True):
    """A grass tuft: blades fanning up from a root (texture up = -V), each with a dark copy and a lit tip."""
    rng = cv.rng
    nb = rng.integers(*nblades)
    base_ang = -math.pi / 2 + rng.uniform(-lean, lean)
    for i in range(nb):
        a = base_ang + (i - (nb - 1) / 2) * rng.uniform(0.18, 0.35)
        L = blade_len * rng.uniform(0.6, 1.0)
        cx = x + math.cos(a) * L * 0.5
        cy = y + math.sin(a) * L * 0.5
        body = cv.vary(r4[1] if rng.random() < 0.5 else r4[2], x, y)
        tip = cv.vary(mix(r4[2], r4[3], 0.5) if light_tip else r4[2], x, y)
        # blade: taper toward the tip (+u end is the tip since ang points from root to tip)
        cv.stroke3(cx, cy, L * 0.5, blade_w, a, body, cv.vary(r4[0], x, y), tip, up=(math.cos(a), math.sin(a)),
                   h_add=0.45, taper=0.85, wob=0.03, edge=0.6, dark_off=0.35, light_off=0.5, light_amt=0.7)


def pebble(cv, x, y, r, r4, body_w=(0.5, 0.5), up=None, flat=1.4, h=0.8, dark_amt=0.9):
    rng = cv.rng
    body = cv.vary(r4[1] if rng.random() < body_w[0] else r4[2], x, y, jit=0.05)
    light = cv.vary(mix(r4[2], r4[3], 0.6), x, y)
    dark = cv.vary(r4[0], x, y)
    u = up if up is not None else ground_up(rng)
    cv.stroke3(x, y, r, r / rng.uniform(1.05, flat), rng.uniform(0, math.pi), body, dark, light, up=u, h_add=h,
               power=rng.uniform(2.0, 2.6), wob=0.10, edge=0.7, dark_off=0.22, light_off=0.28, light_amt=0.8,
               dark_amt=dark_amt)


# ------------------------------------------------------------------ materials

def clump(cv, x, y, rad, r4, n_tufts=(3, 6), blade=(0.16, 0.34), bw=0.035):
    """A grass clump: a dark pool under it, then back tufts (dark), front tufts (mid/light, lit tips)."""
    rng = cv.rng
    cv.dab(x, y + rad * 0.25, rad * 1.15, rad * 0.75, rng.uniform(-0.3, 0.3), cv.vary(mix(r4[0], r4[1], 0.3), x, y),
           h_add=-0.3, wob=0.2, edge=0.55, opacity=0.75)
    back = np.stack([r4[0], mix(r4[0], r4[1], 0.6), r4[1], r4[2]])
    for _ in range(rng.integers(*n_tufts)):
        tuft(cv, x + rng.normal(0, rad * 0.5), y + rng.normal(0, rad * 0.35), cv.px(rng.uniform(*blade)), cv.px(bw),
             back, light_tip=False)
    for _ in range(rng.integers(*n_tufts)):
        tuft(cv, x + rng.normal(0, rad * 0.45), y + rng.normal(0, rad * 0.3) + rad * 0.2,
             cv.px(rng.uniform(*blade) * 0.9), cv.px(bw), r4)


def m_grass(cv):
    r4 = cv.ramp
    rng = cv.rng
    cv.base()
    big_pass(cv, 90, ang=lambda r: r.uniform(0, math.pi), weights=(0.22, 0.45, 0.28, 0.05))
    medium_pass(cv, 220, aspect=(1.3, 2.2), ang=lambda r: -math.pi / 2 + r.uniform(-0.45, 0.45))
    # clumps cluster in drifts (low-frequency density), so the ground breathes at the 0.5-2 m scale
    dens = tvp.periodic_field(cv.h, cv.w, rng, 5, 2)
    placed = 0
    while placed < 520:
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        if rng.random() > 0.35 + 0.65 * (dens[int(y), int(x)] * 0.5 + 0.5):
            continue
        clump(cv, x, y, cv.px(rng.uniform(0.12, 0.26)), r4)
        placed += 1
    cv.cavity(k=0.40, cool=tvp.AO_GREEN)
    # accent: flower specks in little clusters, a few warm tips
    fl = ramp("flowers")
    for _ in range(40):
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        c = fl[rng.integers(0, 4)]
        for _ in range(rng.integers(3, 8)):
            px, py = x + rng.normal(0, cv.px(0.12)), y + rng.normal(0, cv.px(0.12))
            rr = cv.px(rng.uniform(0.03, 0.05))
            cv.stroke3(px, py, rr, rr * 0.85, rng.uniform(0, 3.1), c, r4[0], mix(c, lin("#ffffff"), 0.35),
                       up=(0, -1), h_add=0.3, edge=0.6, shade=0.3)
    for _ in range(90):
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        tuft(cv, x, y, cv.px(rng.uniform(0.15, 0.3)), cv.px(0.03), np.stack([r4[0], r4[2], r4[3], r4[3]]),
             nblades=(2, 4))


def m_terrace_rice(cv):
    """Rice in rows 0.25 m apart along the terrace contour (texture U), warm yellow-green, wet dark furrows."""
    r4 = cv.ramp
    rng = cv.rng
    cv.base()
    big_pass(cv, 70, aspect=(2.0, 4.0), ang=lambda r: r.uniform(-0.12, 0.12), weights=(0.25, 0.55, 0.2, 0.0),
             opacity=0.85)
    pitch = cv.px(0.25)
    rows = int(round(cv.h / pitch))
    pitch = cv.h / rows
    wave = tvp.periodic_1d(cv.w, rng, kmax=3) * cv.px(0.05)
    mud = ramp("paddy_mud")
    rr4 = np.stack([r4[0], r4[1], mix(r4[1], r4[2], 0.7), mix(r4[2], r4[3], 0.5)])
    for j in range(rows):
        y0 = (j + 0.5) * pitch
        # furrow: a long dark wet stroke between the rows (wraps along U)
        for k in range(8):
            x = (k + rng.uniform(0, 0.3)) * cv.w / 8
            cv.dab(x, y0 + pitch * 0.5 + wave[int(x) % cv.w], cv.w / 8 * 0.7, pitch * 0.16, rng.uniform(-0.03, 0.03),
                   cv.vary(mix(mud[0], r4[0], 0.6), x, y0), h_add=-0.2, wob=0.2, opacity=0.55)
        # clumps along the row
        x = rng.uniform(0, 20)
        while x < cv.w:
            yy = y0 + wave[int(x) % cv.w] + rng.normal(0, pitch * 0.05)
            if rng.random() < 0.9:
                tuft(cv, x, yy + pitch * 0.32, pitch * rng.uniform(0.5, 0.85), cv.px(0.024), rr4, nblades=(4, 7),
                     lean=0.3)
            x += cv.px(rng.uniform(0.08, 0.16))
    cv.cavity(k=0.38, cool=tvp.AO_GREEN)
    for _ in range(140):  # sparse glints of water in the furrows
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        j = int(y / pitch)
        yy = (j + 1.0) * pitch + wave[int(x) % cv.w]
        cv.dab(x, yy, cv.px(rng.uniform(0.05, 0.12)), cv.px(0.012), 0.0, cv.vary(mud[3], x, y), wob=0.05,
               opacity=0.7)


def m_forest_floor(cv):
    r4 = cv.ramp
    rng = cv.rng
    moss = ramp("moss")
    cv.base()
    big_pass(cv, 80, weights=(0.3, 0.5, 0.15, 0.05), aspect=(1.2, 2.0), power=2.4)
    for _ in range(24):  # moss patches
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.w * rng.uniform(0.04, 0.08)
        cv.dab(x, y, L, L / rng.uniform(1.2, 2.0), rng.uniform(0, 3.1), cv.vary(mix(moss[1], r4[1], 0.5), x, y),
               h_add=0.6, big=True, wob=0.2)
    medium_pass(cv, 200, aspect=(1.1, 1.8), power=2.4, ramp4=np.stack([r4[0], r4[1], mix(r4[1], r4[2], 0.5), r4[3]]),
                body_w=(0.7, 0.3), dark_amt=0.6)
    leaf_cols = [r4[3], mix(r4[3], r4[2], 0.5), r4[2], mix(r4[3], lin("#b0803a"), 0.5), moss[2]]
    for _ in range(1400):  # leaf litter: pointed leaf dabs
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.04, 0.09))
        c = cv.vary(leaf_cols[rng.integers(0, len(leaf_cols))], x, y, jit=0.08)
        cv.stroke3(x, y, L, L * rng.uniform(0.35, 0.5), rng.uniform(0, 6.28), c, r4[0], mix(c, r4[3], 0.5),
                   up=ground_up(rng), h_add=0.35, power=1.6, wob=0.05, edge=0.6, dark_off=0.3)
    for _ in range(90):  # twigs
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.12, 0.35))
        cv.stroke3(x, y, L, cv.px(0.012), rng.uniform(0, 3.14), cv.vary(lin("#5a4630"), x, y), r4[0],
                   lin("#8a7050"), up=ground_up(rng), h_add=0.4, wob=0.02, bend=rng.uniform(-0.6, 0.6))
    cv.cavity(k=0.45, cool=tvp.AO_GREEN)


def m_dirt_path(cv):
    r4 = cv.ramp
    rng = cv.rng
    cv.base()
    big_pass(cv, 95, aspect=(1.3, 2.4), weights=(0.08, 0.5, 0.37, 0.05), power=2.3)
    medium_pass(cv, 240, aspect=(1.2, 2.2), ang=lambda r: r.uniform(-0.5, 0.5), power=2.4, dark_amt=0.45)
    for _ in range(110):  # faint foot-scuffs, along U
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.25, 0.6))
        cv.dab(x, y, L, L / rng.uniform(4, 7), rng.uniform(-0.3, 0.3), cv.vary(r4[2], x, y), opacity=0.45, wob=0.1)
    sizes = np.sort(rng.uniform(0.03, 0.075, 380))[::-1]  # flat pebbles 5-15 cm
    stone = ramp("white_stone")
    pr = np.stack([mix(r4[0], stone[0], 0.3), mix(r4[1], stone[1], 0.3), mix(r4[2], stone[2], 0.25), r4[3]])
    for s in sizes:
        pebble(cv, rng.uniform(0, cv.w), rng.uniform(0, cv.h), cv.px(s), pr, flat=1.8, h=0.6)
    for _ in range(40):  # small cracks
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.1, 0.25))
        cv.dab(x, y, L, cv.px(0.01), rng.uniform(0, 3.1), cv.vary(r4[0], x, y), h_add=-0.4, wob=0.02, opacity=0.7,
               bend=rng.uniform(-0.8, 0.8))
    cv.cavity(k=0.40, cool="#5a4a58")


def m_laterite(cv):
    r4 = cv.ramp
    rng = cv.rng
    cv.base()
    big_pass(cv, 85, aspect=(1.4, 2.8), ang=lambda r: r.uniform(-0.25, 0.25), weights=(0.1, 0.5, 0.35, 0.05),
             power=2.3)
    for _ in range(28):  # faint strata, along U
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.w * rng.uniform(0.15, 0.35)
        cv.dab(x, y, L, cv.px(rng.uniform(0.02, 0.05)), rng.uniform(-0.06, 0.06),
               cv.vary(r4[0] if rng.random() < 0.5 else r4[2], x, y), opacity=0.5, wob=0.08, h_add=0.2)
    medium_pass(cv, 240, aspect=(1.2, 2.2), power=2.4, dark_amt=0.45)
    sizes = np.sort(rng.uniform(0.02, 0.06, 420))[::-1]
    for s in sizes:
        pebble(cv, rng.uniform(0, cv.w), rng.uniform(0, cv.h), cv.px(s), r4, flat=1.6, h=0.5)
    cv.cavity(k=0.42, cool="#4e3044")


def m_paddy_mud(cv):
    """Wet mud: two values, smooth, with sky glints."""
    r4 = cv.ramp
    rng = cv.rng
    cv.base(dv=0.06)
    big_pass(cv, 80, aspect=(1.5, 3.0), weights=(0.35, 0.65, 0.0, 0.0), h=0.6, edge=0.5, wob=0.18, opacity=0.6,
             ang=lambda r: r.uniform(-0.3, 0.3))
    medium_pass(cv, 160, aspect=(2.0, 4.0), ang=lambda r: r.uniform(-0.3, 0.3), h=0.25, power=2.2, dark_amt=0.35,
                ramp4=np.stack([r4[0], r4[1], mix(r4[1], r4[2], 0.6), r4[2]]), opacity=0.8)
    cv.cavity(k=0.3, cool="#2c3a40")
    for _ in range(220):  # sky glints: elongated, along U
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.04, 0.16))
        cv.dab(x, y, L, L / rng.uniform(4, 8), rng.uniform(-0.15, 0.15), cv.vary(r4[3], x, y), wob=0.08,
               opacity=rng.uniform(0.5, 0.9))
    for _ in range(60):  # a few drowned straw stubs
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.04, 0.08))
        cv.dab(x, y, L, cv.px(0.008), rng.uniform(0, 3.1), cv.vary(lin("#8a7a48"), x, y), opacity=0.8, wob=0.02)


def m_karst(cv, fluting=1.0, streaks=1.0, moss_amt=1.0):
    """Karst limestone, a vertical face lit from -V: strata bands 0.6-1.2 m, each broken by joints into blocks 1-4 m
    of slightly different tone with a lit top rim and a shadowed crack above it, the band face darkening toward its
    undercut foot; big angled facets inside the blocks; soft vertical fluting; dark water streaks; moss on the rims."""
    r4 = cv.ramp
    rng = cv.rng
    stain = ramp("cliff_stain")
    moss = ramp("moss")
    cv.base(dv=0.10)
    bands = []
    tot = 0.0
    while tot < cv.h:
        hb = cv.px(rng.uniform(0.6, 1.2))
        bands.append(hb)
        tot += hb
    scale = cv.h / tot
    lit = mix(r4[2], r4[3], 0.55)
    wave = tvp.periodic_1d(cv.w, rng, kmax=5) * cv.px(0.18)
    blocks = []
    y = 0.0
    for hb in bands:
        hb *= scale
        tone = rng.uniform(-0.08, 0.08)
        x = rng.uniform(0, cv.w)
        x_end = x + cv.w
        while x < x_end:  # irregular blocks that overlap, so only some joints show
            wsl = cv.px(rng.uniform(1.8, 6.0))
            cx = x + wsl / 2
            cy = y + hb / 2 + wave[int(cx) % cv.w] + rng.normal(0, hb * 0.06)
            blocks.append((cx, cy, wsl, hb * rng.uniform(0.85, 1.5), tone))
            x += wsl * rng.uniform(0.7, 0.95)
        y += hb
    order = rng.permutation(len(blocks))
    for i in order:
        cx, cy, wsl, hh, tone = blocks[i]
        c = cv.vary(mix(r4[1], r4[2], rng.uniform(0.0, 0.9)), cx, cy, dv=0.1, jit=0.04)
        c = tvp.jitter(c, dv=tone)
        poly = tvp.random_poly(rng, (4, 6), jitter=0.35)
        cv.stroke3(cx, cy, wsl / 2, hh / 2, rng.uniform(-0.1, 0.1), c, mix(r4[0], c, 0.4), lit,
                   up=(rng.normal(0, 0.15), -1.0), h_add=1.0, wob=0.03, edge=0.93, dark_off=0.06, light_off=0.05,
                   light_amt=0.8, dark_amt=0.6, poly=poly)
        cv.big[int(cy) % cv.h, int(cx) % cv.w] = 1.0
        # flat planes of the block: an upper plane lighter (faces the sky), a lower plane darker (faces down)
        for k in range(rng.integers(0, 3)):
            up_plane = rng.random() < 0.6
            fx = cx + rng.uniform(-0.3, 0.3) * wsl
            fy = cy + (-1 if up_plane else 1) * rng.uniform(0.05, 0.25) * hh
            fl = rng.uniform(0.22, 0.42) * wsl
            fc = mix(c, lit, rng.uniform(0.3, 0.6)) if up_plane else mix(c, r4[0], rng.uniform(0.2, 0.4))
            cv.dab(fx, fy, fl, min(fl / rng.uniform(1.0, 2.2), hh * 0.35), rng.uniform(-0.6, 0.6),
                   cv.vary(fc, fx, fy), h_add=0.25 if up_plane else -0.1, wob=0.02, edge=0.92,
                   poly=tvp.random_poly(rng, (3, 5), jitter=0.4), opacity=0.75)
    # strata cracks along most band boundaries (wavy, broken)
    y = 0.0
    for hb in bands:
        hb *= scale
        y += hb
        x = rng.uniform(0, cv.w)
        x_end = x + cv.w
        while x < x_end:
            L = cv.px(rng.uniform(0.8, 3.0))
            if rng.random() < 0.65:
                cx = x + L / 2
                cv.dab(cx, y + wave[int(cx) % cv.w], L / 2, cv.px(rng.uniform(0.025, 0.05)), rng.uniform(-0.05, 0.05),
                       cv.vary(r4[0], cx, y), h_add=-0.8, wob=0.15, edge=0.5, opacity=0.85)
            x += L * rng.uniform(1.0, 1.6)
    # soft vertical fluting: a few broad grooves, broken (low contrast; the meshes carry the real fluting)
    for _ in range(int(26 * fluting)):
        x, yy = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(1.0, 2.5))
        wv = cv.px(rng.uniform(0.2, 0.4))
        cv.dab(x, yy, L, wv, math.pi / 2 + rng.uniform(-0.05, 0.05), cv.vary(r4[0], x, yy), wob=0.15, opacity=0.14,
               edge=0.2, h_add=-0.15, hmode="add", taper=0.5)
    cv.cavity(k=0.5, cool=tvp.AO_ROCK, sigma_frac=1 / 96.0, gamma=0.9)
    e = cv.edge_light(amt=0.22)
    for _ in range(int(36 * streaks)):  # water streaks running down from the rims
        x, yy = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(1.5, 4.5))
        cv.dab(x, yy + L, L, cv.px(rng.uniform(0.25, 0.55)), math.pi / 2, cv.vary(stain[rng.integers(0, 2)], x, yy),
               taper=0.8, wob=0.12, opacity=rng.uniform(0.18, 0.32), edge=0.15)
    mm = tvp.blur(e, 9.0) * (0.5 + 0.5 * tvp.periodic_field(cv.h, cv.w, rng, 6, 3))
    mm = tvp.smoothstep(0.35, 0.8, mm / max(mm.max(), 1e-6)) * 0.85 * moss_amt
    mc = mix(moss[1], moss[2], 0.4)
    cv.col = mix(cv.col, np.broadcast_to(mc, cv.col.shape), mm[..., None])


def scatter_packed(rng, w, h, rmin, rmax, count, tries=30):
    """Big-first, roughly non-overlapping disc placement on the torus (allows 25% overlap)."""
    radii = np.sort(rng.uniform(0, 1, count) ** 2.2 * (rmax - rmin) + rmin)[::-1]
    pts = []
    cell = rmax * 2
    grid = {}
    gw, gh = int(math.ceil(w / cell)), int(math.ceil(h / cell))
    for r in radii:
        for _ in range(tries):
            x, y = rng.uniform(0, w), rng.uniform(0, h)
            gx, gy = int(x / cell), int(y / cell)
            ok = True
            for j in (-1, 0, 1):
                for i in (-1, 0, 1):
                    for (px, py, pr) in grid.get(((gx + i) % gw, (gy + j) % gh), ()):
                        ddx = (x - px + w / 2) % w - w / 2
                        ddy = (y - py + h / 2) % h - h / 2
                        if ddx * ddx + ddy * ddy < ((r + pr) * 0.78) ** 2:
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


def m_white_stone(cv):
    """Đá Trắng gravel: packed rounded pebbles 5-40 cm (some bigger), very pale cream to cool grey, cool-grey AO
    between them; the brightest ground."""
    r4 = cv.ramp
    rng = cv.rng
    cv.base(color=mix(r4[0], r4[1], 0.45))
    big_pass(cv, 50, weights=(0.45, 0.55, 0.0, 0.0), h=0.1, opacity=0.6)
    tints = [r4[2], r4[3], r4[1], mix(r4[2], lin("#e2d6b8"), 0.6), mix(r4[1], lin("#b9c6c8"), 0.5)]
    for (x, y, rr) in scatter_packed(rng, cv.w, cv.h, cv.px(0.03), cv.px(0.24), 2600):
        c = cv.vary(tints[rng.choice(5, p=[0.32, 0.18, 0.2, 0.18, 0.12])], x, y, jit=0.04)
        u = (rng.normal(0, 0.35), -1.0) if rng.random() < 0.55 else ground_up(rng)
        cv.stroke3(x, y, rr, rr / rng.uniform(1.05, 1.45), rng.uniform(0, math.pi), c, mix(r4[0], c, 0.25),
                   mix(c, r4[3], 0.7), up=u, h_add=1.0 if rr > cv.px(0.1) else 0.7, power=rng.uniform(2.0, 2.5),
                   wob=0.1, edge=0.72, dark_off=0.2, light_off=0.3, light_amt=0.75, dark_amt=0.7, shade=0.28)
        if rr > cv.px(0.1):
            cv.big[int(y) % cv.h, int(x) % cv.w] = 1
    cv.cavity(k=0.5, cool="#6c7890", sigma_frac=1 / 90.0, gamma=0.75)
    for _ in range(70):  # faint warm and jade flecks (wet film, lichen)
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.02, 0.05))
        c = lin("#c9c09a") if rng.random() < 0.6 else lin("#9fc6be")
        cv.dab(x, y, L, L * 0.7, rng.uniform(0, 3), c, opacity=0.45, wob=0.1)


def m_moss_fern(cv):
    r4 = cv.ramp
    rng = cv.rng
    fern = ramp("fern")
    cv.base()
    big_pass(cv, 85, aspect=(1.1, 1.8), weights=(0.25, 0.45, 0.25, 0.05), wob=0.18)
    for _ in range(420):  # moss cushions: round lumps, lit top
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.06, 0.16))
        c = cv.vary(r4[1] if rng.random() < 0.5 else r4[2], x, y)
        cv.stroke3(x, y, L, L * rng.uniform(0.75, 0.95), rng.uniform(0, 3), c, r4[0], mix(r4[2], r4[3], 0.6),
                   up=ground_up(rng), h_add=0.7, wob=0.08, edge=0.7, dark_off=0.2, shade=0.25)
    cv.cavity(k=0.42, cool=tvp.AO_GREEN)
    for _ in range(46):  # fern fronds: a stem with paired leaflets
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        a = rng.uniform(0, 6.283)
        L = cv.px(rng.uniform(0.35, 0.7))
        nl = 9
        for i in range(nl):
            t = (i + 0.5) / nl
            px, py = x + math.cos(a) * L * t, y + math.sin(a) * L * t
            ll = cv.px(0.09) * (1.0 - 0.7 * t)
            for sgn in (-1, 1):
                aa = a + sgn * 1.0
                cv.stroke3(px + math.cos(aa) * ll * 0.6, py + math.sin(aa) * ll * 0.6, ll, ll * 0.32, aa,
                           cv.vary(fern[2] if i % 2 else fern[1], px, py), fern[0], fern[3], up=ground_up(rng),
                           h_add=0.5, taper=0.7, wob=0.03, edge=0.6, dark_off=0.3)
        cv.dab(x + math.cos(a) * L / 2, y + math.sin(a) * L / 2, L / 2, cv.px(0.01), a, fern[0], wob=0.0)


MATERIALS = {
    "grass": m_grass, "terrace_rice": m_terrace_rice, "forest_floor": m_forest_floor, "dirt_path": m_dirt_path,
    "laterite": m_laterite, "paddy_mud": m_paddy_mud, "karst_limestone": m_karst, "white_stone": m_white_stone,
    "moss_fern": m_moss_fern,
}


def paint_slice(idx, key, rname, tile_m, budget, size, seed_base=7100):
    t0 = time.time()
    cv = tvp.Canvas(size, size, tile_m, seed_base + idx * 17, ramp(rname))
    MATERIALS[key](cv)
    cv.finish(value_target=budget)
    rgb = tvp.l2s(cv.col)
    # A = 0.6 x normalised stroke height + 0.4 x big-stroke mask
    h = cv.ht - tvp.blur(cv.ht, size / 16.0)
    lo, hi = np.percentile(h, 1.0), np.percentile(h, 99.0)
    hn = np.clip((h - lo) / max(hi - lo, 1e-6), 0, 1)
    bigm = np.clip(tvp.blur(cv.big, 1.0) * 1.5, 0, 1)
    a = np.clip(0.6 * hn + 0.4 * bigm, 0.0, 1.0)
    img = tvp.to_u8(np.concatenate([rgb, a[..., None]], -1))
    stats = tvp.squint_check(img, "terrain_%d_%s" % (idx, key))
    stats["seconds"] = round(time.time() - t0, 1)
    stats["mean_srgb"] = [round(float(v), 4) for v in rgb.reshape(-1, 3).mean(0)]
    print("slice %d %-16s %s" % (idx, key, stats), flush=True)
    return img, stats


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
        img, st = paint_slice(idx, key, rname, tile_m, budget, args.size)
        from PIL import Image
        Image.fromarray(img[..., :3]).save(tvp.look_path("slices/%d_%s.png" % (idx, key)))
        imgs.append(img)
        meta.append({"slice": idx, "key": key, "ramp": rname, "tile_m": tile_m, "value_budget": budget, **st})
    if only or args.preview:
        return
    # 3 x 3 grid (WebP's 16383 px limit rules out a 9-slice vertical strip): slice i at column i % 3, row i // 3,
    # which is the order Godot's 2d_array_texture importer reads (slices/horizontal=3, slices/vertical=3)
    s = args.size
    grid = np.zeros((3 * s, 3 * s, 4), np.uint8)
    for i, im in enumerate(imgs):
        grid[(i // 3) * s:(i // 3 + 1) * s, (i % 3) * s:(i % 3 + 1) * s] = im
    p = tvp.save(grid, "terrain/tv_terrain_albedo_array.webp")
    with open(os.path.join(tvp.OUT, "terrain", "terrain_slices.json"), "w") as f:
        json.dump({"size": args.size, "layout": "3 x 3 grid, slice i at column i % 3, row i // 3 (import: slices/horizontal=3, vertical=3)",
                   "alpha": "blend height: 0.6 x normalised stroke height + 0.4 x big-stroke mask",
                   "slices": meta}, f, indent=1)
    print("wrote", p, os.path.getsize(p) // 1024, "KB")


if __name__ == "__main__":
    main()
