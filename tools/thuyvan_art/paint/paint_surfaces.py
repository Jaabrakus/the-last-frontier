#!/usr/bin/env python3
"""P02 rock tiling and P03 the village trim sheet (style guide 3.1-3.2, 5.2).

    python3 tools/thuyvan_art/paint/paint_surfaces.py [--only rock,trim]

Writes into assets/thuyvan/paint/:
  rock/tv_karst_face_16m.png         2048^2, karst face with strata, planes, fluting, water stains, moss rims; 16 m tile
  rock/tv_karst_face_16m_normal.png  1024^2, the one soft normal (OpenGL, +Y up) from the painted height; strength in
                                     the material 0.2-0.35 (style guide 5.2: rock only)
  rock/tv_river_stone_4m.png         1024^2, white river stone (Đá Trắng): smooth pale planes, few strokes; 4 m tile
  rock/tv_cliff_moss_6m.png          1024^2, moss cushions for the rock shader's moss blend; 6 m tile
  trim/tv_village_trim.png           2048^2 trim sheet at 256 px/m (8 m across): strips per material key
  trim/tv_village_trim.json          each key's strip (v0, v1 from the top, 0..1), metres tall, tiling in U
"""
import argparse
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvp  # noqa: E402
from tvp import lin, mix, ramp  # noqa: E402
import paint_terrain as pt  # noqa: E402


def normal_from_height(ht, strength=6.0):
    gx = (np.roll(ht, -1, 1) - np.roll(ht, 1, 1)) * 0.5
    gy = (np.roll(ht, -1, 0) - np.roll(ht, 1, 0)) * 0.5
    n = np.stack([-gx * strength, gy * strength, np.ones_like(ht)], -1)  # OpenGL: +Y up in the texture
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


# ------------------------------------------------------------------ rock

def rock(size=2048):
    out = {}
    cv = tvp.Canvas(size, size, 16.0, 8200, ramp("karst_limestone"))
    pt.m_karst(cv, fluting=1.4, streaks=1.6, moss_amt=1.0)
    cv.finish(value_target=0.62)
    img = cv.rgba(alpha=None)
    tvp.save(img, "rock/tv_karst_face_16m.png")
    out["karst_face"] = tvp.squint_check(img, "rock_karst_face_16m")
    h = cv.ht - tvp.blur(cv.ht, size / 24.0)
    h = tvp.blur(h, 2.0)
    h = h / max(np.percentile(np.abs(h), 99), 1e-6)
    nrm = normal_from_height(h, strength=1.2 * size / 1024.0)
    from PIL import Image
    nimg = Image.fromarray(tvp.to_u8(nrm)).resize((size // 2, size // 2), Image.BOX)
    nimg.save(os.path.join(tvp.OUT, "rock", "tv_karst_face_16m_normal.png"))

    # white river stone: smooth rounded planes, almost no strokes
    cv = tvp.Canvas(1024, 1024, 4.0, 8300, ramp("white_stone"))
    r4 = cv.ramp
    rng = cv.rng
    cv.base(color=mix(r4[1], r4[2], 0.6), dv=0.06)
    for _ in range(40):
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.w * rng.uniform(0.08, 0.2)
        c = cv.vary(mix(r4[1], r4[3], rng.uniform(0.2, 0.9)), x, y)
        cv.stroke3(x, y, L, L / rng.uniform(1.2, 2.2), rng.uniform(0, 3.14), c, mix(r4[0], c, 0.6),
                   mix(c, r4[3], 0.7), up=(0, -1), h_add=0.6, wob=0.15, edge=0.55, dark_amt=0.35, light_amt=0.5,
                   shade=0.15, poly=tvp.random_poly(rng, (5, 7), 0.3) if rng.random() < 0.4 else None)
    for _ in range(50):  # faint warm film and cool pits
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.04, 0.12))
        cv.dab(x, y, L, L * 0.6, rng.uniform(0, 3), lin("#d8ccaa") if rng.random() < 0.6 else r4[0], opacity=0.25,
               wob=0.2, edge=0.3)
    cv.cavity(k=0.3, cool="#7f8c96", sigma_frac=1 / 32.0)
    cv.finish(value_target=0.82)
    img = cv.rgba()
    tvp.save(img, "rock/tv_river_stone_4m.png")
    out["river_stone"] = tvp.squint_check(img, "rock_river_stone_4m")

    # cliff moss
    cv = tvp.Canvas(1024, 1024, 6.0, 8400, ramp("moss"))
    r4 = cv.ramp
    rng = cv.rng
    cv.base()
    pt.big_pass(cv, 70, aspect=(1.1, 1.8), weights=(0.25, 0.45, 0.25, 0.05), wob=0.18)
    for _ in range(520):
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.07, 0.2))
        c = cv.vary(r4[1] if rng.random() < 0.5 else r4[2], x, y)
        cv.stroke3(x, y, L, L * rng.uniform(0.75, 0.95), rng.uniform(0, 3), c, r4[0], mix(r4[2], r4[3], 0.6),
                   up=(0, -1), h_add=0.7, wob=0.08, edge=0.7, dark_off=0.2, shade=0.3)
    cv.cavity(k=0.42, cool=tvp.AO_GREEN)
    cv.finish(value_target=0.42)
    img = cv.rgba()
    tvp.save(img, "rock/tv_cliff_moss_6m.png")
    out["cliff_moss"] = tvp.squint_check(img, "rock_cliff_moss_6m")
    return out


# ------------------------------------------------------------------ trim sheet

def strip_canvas(h, key, seed, rname=None):
    return tvp.Canvas(h, 2048, 8.0, seed, ramp(rname or key))


def wood_grain(cv, n_long, up=(0, -1), knots=6, plank_h=None):
    r4 = cv.ramp
    rng = cv.rng
    cv.base(dv=0.06)
    for _ in range(int(n_long * 0.25)):
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.w * rng.uniform(0.08, 0.2)
        cv.dab(x, y, L, cv.px(rng.uniform(0.04, 0.1)), rng.uniform(-0.01, 0.01), cv.vary(cv.pick((0.2, .5, .3, 0)), x, y),
               h_add=0.6, big=True, wob=0.06, edge=0.6)
    for _ in range(n_long):
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.4, 1.4))
        cv.stroke3(x, y, L, cv.px(rng.uniform(0.008, 0.02)), rng.uniform(-0.015, 0.015),
                   cv.vary(r4[1] if rng.random() < 0.5 else r4[2], x, y), r4[0], mix(r4[2], r4[3], 0.5), up=up,
                   h_add=0.3, taper=0.5, wob=0.02, edge=0.5, dark_off=0.4, light_off=0.4, light_amt=0.5)
    for _ in range(knots):
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        r = cv.px(rng.uniform(0.025, 0.05))
        cv.stroke3(x, y, r * 1.6, r, 0.0, r4[0], mix(r4[0], lin("#000000"), 0.3), r4[1], up=up, h_add=-0.3,
                   edge=0.6, shade=0.3)


def t_timber(h, seed):
    cv = strip_canvas(h, "timber", seed)
    wood_grain(cv, 260)
    cv.cavity(k=0.4, cool=tvp.AO_WOOD, sigma_frac=1 / 128.0)
    cv.edge_light(amt=0.15)
    cv.finish(value_target=0.38)
    return cv


def t_planks(h, seed):
    cv = strip_canvas(h, "plank_weathered", seed)
    wood_grain(cv, 340, knots=12)
    r4 = cv.ramp
    rng = cv.rng
    ph = h / 4.0
    for j in range(4):  # 4 planks 0.3 m: tone per plank, a dark gap and a lit top edge
        y0 = j * ph
        x = rng.uniform(0, cv.w)
        x_end = x + cv.w
        while x < x_end:
            L = cv.px(rng.uniform(1.5, 3.5))
            cv.dab(x + L / 2, y0 + ph / 2, L / 2, ph / 2 - 2, 0.0,
                   tvp.jitter(r4[1], dv=rng.uniform(-0.12, 0.12)), opacity=0.35, power=8, wob=0.0, edge=0.95)
            cv.dab(x + L, y0 + ph / 2, cv.px(0.012), ph / 2, 0.0, r4[0], h_add=-1.0, power=8, wob=0.0, opacity=0.9)
            x += L
        cv.dab(cv.w / 2, y0, cv.w / 2 + 4, cv.px(0.022), 0.0, mix(r4[0], lin("#1a1410"), 0.5), h_add=-1.0, power=8,
               wob=0.0)
        for k in range(10):  # nail heads near the ends
            nx = rng.uniform(0, cv.w)
            for dy in (0.25, 0.75):
                cv.stroke3(nx, y0 + ph * dy, 4, 4, 0, ramp("iron")[1], ramp("iron")[0], ramp("iron")[3], up=(0, -1),
                           h_add=0.2)
    cv.cavity(k=0.4, cool=tvp.AO_WOOD, sigma_frac=1 / 128.0)
    cv.edge_light(amt=0.18)
    cv.finish(value_target=0.55)
    return cv


def t_roof_tile(h, seed):
    """Dark slate-teal barrel tiles: U along the eave, V down the slope. Columns alternate a concave pan (dark) and a
    convex cap (lit along one side), in 0.25 m courses that overlap; six courses fill the strip, so it tiles in V."""
    cv = strip_canvas(h, "roof_tile", seed)
    r4 = cv.ramp
    rng = cv.rng
    cv.base(color=mix(r4[0], r4[1], 0.3))
    course = h / 6.0
    cw = cv.px(0.16)
    n = int(round(cv.w / cw / 2)) * 2
    cw = cv.w / n
    for i in range(n):
        x = (i + 0.5) * cw
        cap = i % 2 == 1
        for j in range(6):
            y = (j + 0.5) * course + (course * 0.5 if cap else 0.0)
            c = cv.vary(mix(r4[1], r4[2], rng.uniform(0.35, 0.8)) if cap else mix(r4[0], r4[1], rng.uniform(0.4, 0.9)),
                        x, y, jit=0.05)
            wdt = cw * (0.62 if cap else 0.58)
            cv.stroke3(x, y, wdt, course * 0.56, 0.0, c, r4[0], mix(c, r4[3], 0.65), up=(-0.8, -0.6),
                       h_add=1.0 if cap else 0.4, power=2.8, wob=0.03, edge=0.85, dark_off=0.15, light_off=0.25,
                       light_amt=0.8 if cap else 0.3, shade=0.4 if cap else 0.15)
    for _ in range(50):  # lichen and weather
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.03, 0.07))
        cv.dab(x, y, L, L * 0.7, rng.uniform(0, 3), lin("#8f9e64") if rng.random() < 0.6 else r4[3], opacity=0.4,
               wob=0.1)
    cv.cavity(k=0.45, cool="#1c2430", sigma_frac=1 / 160.0)
    cv.finish(value_target=0.32)
    return cv


def t_thatch(h, seed):
    """Thatch in two layered courses (0.5 m), straw running down-slope (+V): soft bundles, then dense long strands
    with lit sides, a shadow band under each course's ragged lower edge."""
    cv = strip_canvas(h, "thatch", seed)
    r4 = cv.ramp
    rng = cv.rng
    cv.base(color=mix(r4[0], r4[1], 0.5))
    layers = 2
    lh = h / layers
    for j in range(layers):
        y0 = j * lh
        for _ in range(int(cv.w / 40)):  # soft bundles
            x = rng.uniform(0, cv.w)
            c = cv.vary(cv.pick((0.2, 0.5, 0.3, 0.0)), x, y0, jit=0.05)
            cv.dab(x, y0 + lh * 0.5, lh * 0.55, cv.px(rng.uniform(0.06, 0.12)), math.pi / 2, c, h_add=0.5, big=True,
                   wob=0.08, edge=0.6, taper=0.3)
        for _ in range(int(cv.w / 1.6)):  # strands
            x = rng.uniform(0, cv.w)
            L = lh * rng.uniform(0.55, 1.0)
            yy = y0 + lh * rng.uniform(0.98, 1.08) - L
            c = cv.vary(cv.pick((0.1, 0.45, 0.37, 0.08)), x, yy, jit=0.07)
            cv.stroke3(x, yy + L / 2, L / 2, cv.px(rng.uniform(0.006, 0.014)), math.pi / 2 + rng.uniform(-0.06, 0.06),
                       c, r4[0], mix(c, r4[3], 0.6), up=(-1, 0), h_add=0.5, taper=0.7, wob=0.0, edge=0.55,
                       dark_off=0.6, light_off=0.5, light_amt=0.6, dark_amt=0.5)
        # the shadow under the next course's lower edge
        yb = (y0 + lh) % h
        for k in range(16):
            x = (k + rng.uniform(0, 0.4)) * cv.w / 16
            cv.dab(x, yb + cv.px(0.03), cv.w / 16 * 0.75, cv.px(0.035), 0.0, r4[0], h_add=-0.6, wob=0.25, opacity=0.6,
                   edge=0.4)
    cv.cavity(k=0.38, cool=tvp.AO_WOOD, sigma_frac=1 / 160.0)
    cv.finish(value_target=0.55)
    return cv


def t_shingle(h, seed):
    cv = strip_canvas(h, "timber", seed, "plank_weathered")
    r4 = cv.ramp
    rng = cv.rng
    cv.base(color=r4[0])
    rows = 4
    rh = h / rows
    for j in range(rows):
        x = rng.uniform(0, 40) + (j % 2) * cv.px(0.08)
        x_end = x + cv.w
        while x < x_end:
            wsh = cv.px(rng.uniform(0.12, 0.22))
            c = cv.vary(mix(r4[1], r4[2], rng.uniform(0, 0.8)), x, j * rh, jit=0.06)
            cv.stroke3(x + wsh / 2, j * rh + rh * 0.62, wsh / 2 - 1, rh * 0.62, rng.uniform(-0.03, 0.03), c, r4[0],
                       mix(c, r4[3], 0.5), up=(0, -1), h_add=1.0, power=6, wob=0.03, edge=0.9, dark_off=0.08,
                       light_off=0.05, shade=0.3)
            x += wsh
    cv.cavity(k=0.4, cool=tvp.AO_WOOD, sigma_frac=1 / 160.0)
    cv.edge_light(amt=0.2)
    cv.finish(value_target=0.45)
    return cv


def t_bamboo_weave(h, seed):
    cv = strip_canvas(h, "bamboo", seed)
    b4, t4 = ramp("bamboo"), ramp("thatch")
    r4 = np.stack([mix(b4[0], t4[0], 0.7), mix(b4[2], t4[2], 0.75), mix(b4[3], t4[3], 0.7), mix(b4[3], t4[3], 0.5)])
    cv.ramp = r4
    rng = cv.rng
    cv.base(color=r4[0])
    cell = cv.px(0.1)
    n = int(round(cv.w / cell))
    cell = cv.w / n
    m = int(round(h / cell))
    for j in range(m):
        for i in range(n):
            x, y = (i + 0.5) * cell, (j + 0.5) * cell
            horiz = (i + j) % 2 == 0
            c = cv.vary(mix(r4[1], r4[2], rng.uniform(0, 0.7)), x, y, jit=0.05)
            for k in (-1, 1):  # two strips per cell
                if horiz:
                    cv.stroke3(x, y + k * cell * 0.24, cell * 0.52, cell * 0.2, 0.0, c, r4[0], r4[3], up=(0, -1),
                               h_add=0.6, power=3, wob=0.02, edge=0.8, shade=0.3)
                else:
                    cv.stroke3(x + k * cell * 0.24, y, cell * 0.2, cell * 0.52, 0.0, c, r4[0], r4[3], up=(0, -1),
                               h_add=0.6, power=3, wob=0.02, edge=0.8, shade=0.3)
    cv.cavity(k=0.45, cool=tvp.AO_WOOD, sigma_frac=1 / 200.0)
    cv.finish(value_target=0.5)
    return cv


def t_plaster(h, seed):
    cv = strip_canvas(h, "plaster_lime", seed)
    r4 = cv.ramp
    rng = cv.rng
    cv.base()
    pt.big_pass(cv, 60, size_frac=(0.04, 0.12), weights=(0.05, 0.5, 0.4, 0.05), h=0.4, opacity=0.7, wob=0.2)
    pt.medium_pass(cv, 140, up=lambda r: (0, -1), h=0.3, dark_amt=0.2, opacity=0.5, aspect=(1.1, 1.6), power=2.4,
                   wob=0.15)
    for _ in range(18):  # hairline cracks
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.1, 0.3))
        cv.dab(x, y, L, 1.5, rng.uniform(0, 3.1), r4[0], h_add=-0.5, wob=0.0, bend=rng.uniform(-0.8, 0.8),
               opacity=0.6)
    for _ in range(14):  # rain stains (downward)
        x = rng.uniform(0, cv.w)
        L = h * rng.uniform(0.3, 0.6)
        cv.dab(x, L, L, cv.px(rng.uniform(0.05, 0.12)), math.pi / 2, mix(r4[0], lin("#7a7a6a"), 0.5), taper=0.8,
               opacity=0.18, edge=0.2)
    cv.cavity(k=0.3, cool="#8a8a96", sigma_frac=1 / 128.0)
    cv.finish(value_target=0.80)
    return cv


def t_rope(h, seed):
    """Twisted rope strip (wrap round a rope cylinder: U along the rope, V around it)."""
    cv = strip_canvas(h, "rope", seed)
    r4 = cv.ramp
    rng = cv.rng
    cv.base(color=r4[0])
    pitch = cv.px(0.06)
    n = int(round(cv.w / pitch))
    pitch = cv.w / n
    for i in range(n):
        for k in range(3):
            x = (i + k / 3.0) * pitch
            c = cv.vary(mix(r4[1], r4[2], rng.uniform(0.2, 0.8)), x, h / 2, jit=0.05)
            cv.stroke3(x + h * 0.1, h / 2 + (k - 1) * h * 0.33, pitch * 0.62, h * 0.2, 0.9, c, r4[0], r4[3],
                       up=(0, -1), h_add=0.8, wob=0.05, edge=0.75, shade=0.3)
    cv.cavity(k=0.45, cool=tvp.AO_WOOD, sigma_frac=1 / 300.0)
    cv.finish(value_target=0.5)
    return cv


def t_lacquer(h, seed):
    cv = strip_canvas(h, "lacquer_red", seed)
    r4 = cv.ramp
    rng = cv.rng
    cv.base(dv=0.05)
    for _ in range(60):  # long soft sheen and wear
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.4, 1.2))
        cv.dab(x, y, L, h * rng.uniform(0.1, 0.25), 0.0, r4[2] if rng.random() < 0.5 else r4[0], opacity=0.35,
               wob=0.05, edge=0.3)
    for _ in range(14):  # worn edges showing the dark ground
        x = rng.uniform(0, cv.w)
        cv.dab(x, h * rng.choice([0.05, 0.95]), cv.px(rng.uniform(0.05, 0.15)), h * 0.08, 0.0, lin("#2a1612"),
               opacity=0.6, wob=0.2)
    cv.finish(value_target=0.42)
    return cv


def t_iron(h, seed):
    cv = strip_canvas(h, "iron", seed)
    r4 = cv.ramp
    rng = cv.rng
    cv.base()
    pt.big_pass(cv, 40, size_frac=(0.03, 0.08), weights=(0.3, 0.4, 0.3, 0.0), h=0.3, opacity=0.6)
    for _ in range(25):  # rust blooms
        x, y = rng.uniform(0, cv.w), rng.uniform(0, cv.h)
        L = cv.px(rng.uniform(0.02, 0.06))
        cv.dab(x, y, L, L * 0.7, rng.uniform(0, 3), lin("#6a3a22"), opacity=0.5, wob=0.2)
    pitch = cv.px(0.25)
    for i in range(int(cv.w / pitch)):  # rivets
        cv.stroke3((i + 0.5) * pitch, h / 2, h * 0.16, h * 0.16, 0, r4[2], r4[0], r4[3], up=(0, -1), h_add=0.6,
                   shade=0.4)
    cv.cavity(k=0.4, cool="#141418", sigma_frac=1 / 300.0)
    cv.edge_light(amt=0.2)
    cv.finish(value_target=0.24)
    return cv


TRIM = [  # key, height px, painter, value budget note
    ("timber", 192, t_timber),
    ("plank_weathered", 320, t_planks),
    ("roof_tile", 384, t_roof_tile),
    ("thatch", 256, t_thatch),
    ("wood_shingle", 256, t_shingle),
    ("bamboo_weave", 192, t_bamboo_weave),
    ("plaster", 256, t_plaster),
    ("rope", 64, t_rope),
    ("lacquer", 64, t_lacquer),
    ("iron", 64, t_iron),
]


def trim():
    rows = []
    meta = {"size": [2048, 2048], "px_per_m": 256, "tile_u_m": 8.0,
            "note": "strips tile in U (and each strip wraps in V within itself); v0/v1 from the top of the image",
            "strips": {}}
    y = 0
    for i, (key, h, fn) in enumerate(TRIM):
        cv = fn(h, 9000 + i * 13)
        rows.append(tvp.to_u8(tvp.l2s(cv.col)))
        meta["strips"][key] = {"v0": y / 2048.0, "v1": (y + h) / 2048.0, "px": [y, y + h], "metres_tall": h / 256.0,
                               "mean_srgb": round(float(tvp.l2s(cv.col).mean()), 3)}
        print("trim %-16s %d px  mean %.3f" % (key, h, meta["strips"][key]["mean_srgb"]), flush=True)
        y += h
    img = np.concatenate(rows, 0)
    assert img.shape[0] == 2048, img.shape
    tvp.save(img, "trim/tv_village_trim.png")
    with open(os.path.join(tvp.OUT, "trim", "tv_village_trim.json"), "w") as f:
        json.dump(meta, f, indent=1)
    return meta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="rock,trim")
    a = ap.parse_args()
    only = set(a.only.split(","))
    if "rock" in only:
        print(json.dumps(rock(), indent=0))
    if "trim" in only:
        trim()


if __name__ == "__main__":
    main()
