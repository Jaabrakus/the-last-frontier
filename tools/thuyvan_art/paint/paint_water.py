#!/usr/bin/env python3
"""P09 waterfall kit, P10 mist kit, P11 river surface (style guide 7).

    python3 tools/thuyvan_art/paint/paint_water.py

All painted with the brush engine (tvp.py) in 3-4 tones of one ramp (palettes.json foam_fall, mist, water_depth);
white with cool shade streaks, never photographic. Writes into assets/thuyvan/paint/water/:

  Falls (drawn for 2-3 x real flow; unshaded, alpha blend, colour x the direction's light_tint):
    tv_fall_body.png        512 x 2048 RGBA, tiles in V (scroll 0.6-1.2 m/s down V): ribbons of white with cool
                            shade streaks; alpha thins to ragged gaps at both U edges
    tv_fall_streaks.png     512 x 2048 RGBA, tiles in V: the faster second layer, sparse bright streaks only
    tv_fall_edge_foam.png   256 x 1024 RGBA, tiles in V: the lumpy white outline for the fall's two edges and lip
    tv_fall_spray.png       1024 x 1024 RGBA, 2 x 2 spray puffs (billboards at the foot)
    tv_pool_foam_ring.png   1024 x 1024 RGBA: the ring of foam on the plunge pool (radial, centred)
    tv_wet_stain.png        512 x 1024 RGBA decal: the dark wet stain on the rock behind a fall (alpha = wetness)
  Mist:
    tv_mist_band_{a,b,c}.png 2048 x 512 RGBA, tile in U: long soft bands (200-800 m cards), lit top lighter
    tv_mist_puffs.png       1024 x 1024 RGBA, 2 x 2 drifting puffs (8-30 m)
    tv_smoke_wisps.png      512 x 1024 RGBA, 2 wisps side by side (smoke caught under the roofs)
  River (for the river shader; the existing shaders/water/river.gdshader or its Thủy Vân copy):
    tv_river_ramp.png       256 x 8 RGB: depth colour ramp, x = depth 0..4 m (linear), rows 0-3 the day ramp,
                            rows 4-7 the still state S1 (clearer, paler over the white stones)
    tv_river_flow.png       1024 x 1024 RGBA, tiles both ways: painted flow streaks along +U (alpha = streak),
                            scrolled along the channel's flow UV (UV2)
    tv_river_foam.png       1024 x 1024 RGBA, tiles: foam patches with holes, for banks, rocks and falls' feet
    water.json              the ramp's depth stops, per-direction shallow_tint / deep_color for river.gdshader,
                            suggested scroll speeds
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvp  # noqa: E402
from tvp import lin, mix, ramp  # noqa: E402

OUT = os.path.join(tvp.OUT, "water")


def save_rgba(cv, name, alpha=None, clamp_blur=True):
    a = cv.alpha if alpha is None else alpha
    bl = tvp.blur if cv.wrap else tvp.blur_clamped
    c = bl(cv.col, 0.5)
    img = tvp.to_u8(np.concatenate([tvp.l2s(np.clip(c, 0, 1)), np.clip(a, 0, 1)[..., None]], -1))
    Image.fromarray(img).save(os.path.join(OUT, name), optimize=True)
    return img


def fall_body(seed, streaks_only=False):
    """Vertical ribbons: long down-strokes (V) in foam tones; cool shade streaks between bright ones."""
    W, H = 512, 2048
    r4 = ramp("foam_fall")
    cv = tvp.Canvas(H, W, 1.0, seed, r4, alpha=True, wrap=True, bristle=0.55, streak=0.06)
    rng = cv.rng
    if not streaks_only:
        cv.base(color=tvp.ramp_at(r4, 0.55), dv=0.06)
        cv.alpha[:] = 0.0
    n = 240 if not streaks_only else 120
    for i in range(n):
        x = rng.uniform(0, W)
        y = rng.uniform(0, H)
        L = rng.uniform(180, 700)
        Wd = rng.uniform(6, 26) if not streaks_only else rng.uniform(3, 10)
        t = rng.uniform(0.0, 1.0) if not streaks_only else rng.uniform(0.75, 1.0)
        c = tvp.ramp_at(r4, t) if t < 0.95 else r4[3]
        cv.dab(x, y, L * 0.5, Wd, math.pi / 2 + rng.uniform(-0.02, 0.02), c,
               color2=tvp.ramp_at(r4, min(t + 0.2, 1.0)), opacity=rng.uniform(0.5, 0.95), edge=0.45, bristle=0.6,
               dry=0.6, taper=0.4, alpha_add=True, wob=0.05)
    # alpha: the body is mostly opaque, with gaps and ragged edges at both U sides
    X = (np.arange(W, dtype=np.float32) + 0.5) / W
    edge = np.minimum(X, 1 - X)[None, :]
    rag = tvp.periodic_field(H, W, rng, 24, 6, slope=0.4) * 0.06
    side = tvp.smoothstep(0.02, 0.16, edge + rag)
    gaps = tvp.smoothstep(-0.55, 0.1, tvp.periodic_field(H, W, rng, 16, 4, slope=0.6))
    if streaks_only:
        a = np.clip(cv.alpha, 0, 1) * side
    else:
        a = np.clip(0.7 + 0.3 * cv.alpha, 0, 1) * side * (0.72 + 0.28 * gaps)
    return cv, a


def lumpy(cv, cx, cy, R, r4, n=24, flat=1.0, lit_up=True, soft=0.35, opacity=0.9, spread=0.65):
    """A soft cloud puff: a heap of round brushed dabs, lit on top, cool beneath."""
    rng = cv.rng
    pts = []
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi)
        rr = R * spread * math.sqrt(rng.uniform(0, 1))
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * flat, R * rng.uniform(0.3, 0.5)))
    pts.sort(key=lambda p: -p[1] if lit_up else p[1])
    if soft <= 0.25:  # vapour: big soft round dabs, no painted edges (mist, spray, puffs)
        for (x, y, r) in pts:
            k = np.clip((cy - y) / max(R, 1) * 0.9 + 0.55, 0, 1) if lit_up else 0.6
            body = mix(tvp.ramp_at(r4, 0.25), r4[3], k)
            cv.dab(x, y, r * 1.3, r * 1.3 * flat, 0.0, body, alpha_add=True, edge=0.0, wob=0.12,
                   opacity=opacity * rng.uniform(0.5, 0.9), bristle=0.12, dry=0.2, streak=0.03)
            if lit_up and k > 0.55:  # a lit cap on the upper puffs
                cv.dab(x, y - r * 0.35, r * 0.8, r * 0.6 * flat, 0.0, r4[3], edge=0.0, wob=0.12,
                       opacity=opacity * 0.5, bristle=0.1)
        return
    for (x, y, r) in pts:
        k = np.clip((cy - y) / max(R, 1) * 0.8 + 0.5, 0, 1) if lit_up else 0.6
        body = mix(tvp.ramp_at(r4, 0.3), tvp.ramp_at(r4, 1.0), k)
        cv.stroke3(x, y, r, r * flat, rng.uniform(0, 3), body, tvp.ramp_at(r4, 0.0), r4[3], up=(0, -1), h_add=0.0,
                   edge=soft, wob=0.2, dark_amt=0.25, light_amt=0.6, shade=0.25, alpha_add=True,
                   opacity=opacity * rng.uniform(0.6, 1.0), bristle=0.3, dry=0.3)


def mist_band(cv, m4, k):
    """A long horizontal mist band (tiles in U): a soft flat-bottomed body whose top billows in rounded heaps, lit
    along the top, cool beneath; a few horizontal soft strokes give it the painted grain."""
    rng = cv.rng
    H, W = cv.h, cv.w
    x = np.arange(W, dtype=np.float32)
    c = 0.58 + tvp.periodic_1d(W, rng, kmax=3) * 0.06 - 0.03 * k
    th = 0.1 + 0.03 * (tvp.periodic_1d(W, rng, kmax=5) + 1) + 0.02 * k
    bump = np.zeros(W, np.float32)
    for i in range(16 + 4 * k):
        xi, ri = rng.uniform(0, W), rng.uniform(70, 220)
        d = (x - xi + W / 2) % W - W / 2
        bump = np.maximum(bump, np.sqrt(np.clip(1 - (d / ri) ** 2, 0, 1)) * ri / H * rng.uniform(0.5, 1.0))
    top = c - th - bump
    bot = c + th * 0.7
    Y = (np.arange(H, dtype=np.float32)[:, None] + 0.5) / H
    soft = 0.05
    a = tvp.smoothstep(top[None, :] - soft, top[None, :] + soft, Y) * (1 - tvp.smoothstep(bot[None, :] - soft * 1.6,
                                                                                         bot[None, :] + soft * 1.6, Y))
    dens = 0.75 + 0.25 * tvp.periodic_field(H, W, rng, 10, 3, slope=0.7)
    a = np.clip(a * dens, 0, 1)
    f = np.clip((Y - top[None, :]) / np.maximum(bot - top, 1e-3)[None, :], 0, 1)  # 0 at the top, 1 at the bottom
    col = tvp.ramp_map(m4, 1.0 - 0.75 * f)
    col = mix(col, np.broadcast_to(m4[3], col.shape), (1 - tvp.smoothstep(0.0, 0.25, f))[..., None] * 0.6)
    cv.col = col
    for i in range(160):  # painted grain: soft horizontal strokes re-stating the tone
        xx, yy = rng.uniform(0, W), rng.uniform(0, H)
        if a[int(yy), int(xx)] < 0.2:
            continue
        cc = tvp.jitter(cv.col[int(yy), int(xx)], dv=rng.uniform(-0.06, 0.06))
        cv.dab(xx, yy, rng.uniform(60, 200), rng.uniform(8, 20), rng.uniform(-0.05, 0.05), cc, opacity=0.35,
               edge=0.2, bristle=0.5, dry=0.5)
    return a * 0.92


def main():
    os.makedirs(OUT, exist_ok=True)
    meta = {}
    # ---------------- falls
    cv, a = fall_body(9600)
    save_rgba(cv, "tv_fall_body.png", a)
    cv, a = fall_body(9610, streaks_only=True)
    save_rgba(cv, "tv_fall_streaks.png", a)
    r4 = ramp("foam_fall")
    cv = tvp.Canvas(1024, 256, 1.0, 9620, r4, alpha=True, wrap=True, bristle=0.3)
    cv.base(color=tvp.ramp_at(r4, 0.7))
    for y in np.linspace(0, 1024, 26, endpoint=False):
        lumpy(cv, 128 + cv.rng.uniform(-30, 30), y, cv.rng.uniform(55, 95), r4, n=14, soft=0.5)
    X = (np.arange(256, dtype=np.float32) + 0.5) / 256
    save_rgba(cv, "tv_fall_edge_foam.png", np.clip(cv.alpha, 0, 1) * tvp.smoothstep(0.0, 0.25,
                                                                                         np.minimum(X, 1 - X))[None, :])
    cv = tvp.Canvas(1024, 1024, 1.0, 9630, r4, alpha=True, wrap=False, bristle=0.3)
    cv.col[:] = tvp.ramp_at(r4, 0.6)
    for i in range(4):
        cx, cy = 256 + (i % 2) * 512, 256 + (i // 2) * 512
        lumpy(cv, cx, cy + 20, 190, r4, n=36, soft=0.25, opacity=0.75)
    save_rgba(cv, "tv_fall_spray.png", tvp.blur_clamped(cv.alpha, 6.0))
    cv = tvp.Canvas(1024, 1024, 1.0, 9640, r4, alpha=True, wrap=False, bristle=0.4)
    cv.col[:] = tvp.ramp_at(r4, 0.7)
    rng = cv.rng
    for i in range(260):
        a_ = rng.uniform(0, 2 * math.pi)
        rr = rng.normal(330, 55)
        x, y = 512 + math.cos(a_) * rr, 512 + math.sin(a_) * rr
        cv.dab(x, y, rng.uniform(25, 70), rng.uniform(12, 30), a_ + math.pi / 2, tvp.ramp_at(r4, rng.uniform(0.5, 1.0)),
               alpha_add=True, edge=0.4, opacity=rng.uniform(0.5, 0.9), bristle=0.5, dry=0.5)
    for i in range(120):  # trailing streaks outward
        a_ = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(380, 470)
        x, y = 512 + math.cos(a_) * rr, 512 + math.sin(a_) * rr
        cv.dab(x, y, rng.uniform(15, 40), rng.uniform(4, 10), a_ + math.pi / 2, r4[2], alpha_add=True, edge=0.4,
               opacity=0.5, bristle=0.6)
    save_rgba(cv, "tv_pool_foam_ring.png")
    st = ramp("cliff_stain")
    cv = tvp.Canvas(1024, 512, 1.0, 9650, st, alpha=True, wrap=False, bristle=0.6)
    cv.col[:] = st[0]
    rng = cv.rng
    for i in range(70):
        x = 256 + rng.normal(0, 70)
        L = rng.uniform(250, 900)
        cv.dab(x, L * 0.5 + rng.uniform(0, 60), L * 0.5, rng.uniform(12, 50), math.pi / 2, mix(st[0], st[1], rng.uniform(0, 0.6)),
               alpha_add=True, edge=0.3, opacity=rng.uniform(0.3, 0.7), bristle=0.6, dry=0.7, taper=0.6)
    for i in range(12):  # a little moss along the wet edges
        x, y = 256 + rng.normal(0, 110), rng.uniform(100, 900)
        cv.dab(x, y, rng.uniform(25, 60), rng.uniform(6, 14), math.pi / 2, mix(st[3], st[1], 0.5), alpha_add=True,
               edge=0.2, opacity=0.35, bristle=0.6)
    save_rgba(cv, "tv_wet_stain.png", np.clip(cv.alpha * 0.85, 0, 1))
    print("falls done", flush=True)

    # ---------------- mist
    m4 = ramp("mist")
    for k, name in enumerate("abc"):
        cv = tvp.Canvas(512, 2048, 1.0, 9700 + k, m4, alpha=True, wrap=True, bristle=0.35)
        a = mist_band(cv, m4, k)
        save_rgba(cv, "tv_mist_band_%s.png" % name, a)
    cv = tvp.Canvas(1024, 1024, 1.0, 9750, m4, alpha=True, wrap=False, bristle=0.3)
    cv.col[:] = tvp.ramp_at(m4, 0.6)
    for i in range(4):
        cx, cy = 256 + (i % 2) * 512, 256 + (i // 2) * 512
        lumpy(cv, cx, cy, 170, m4, n=26, soft=0.2, opacity=0.55, flat=0.7)
    save_rgba(cv, "tv_mist_puffs.png", tvp.blur_clamped(cv.alpha, 8.0))
    smoke = np.stack([lin("#6e6a6a"), lin("#9a9692"), lin("#c4c0ba"), lin("#e0dcd6")])
    cv = tvp.Canvas(1024, 512, 1.0, 9760, smoke, alpha=True, wrap=False, bristle=0.4)
    cv.col[:] = tvp.ramp_at(smoke, 0.6)
    rng = cv.rng
    for w in range(2):
        x = 128 + w * 256
        pts = []
        for i in range(40):
            t = i / 39
            y = 1000 - t * 950
            x += rng.normal(0, 5) + math.sin(t * 7 + w) * 3
            pts.append((x, y))
            r = 18 + 110 * t
            cv.dab(x, y, r, r * 0.8, rng.uniform(0, 3), tvp.ramp_at(smoke, 0.4 + 0.5 * t), alpha_add=True, edge=0.2,
                   opacity=(0.65 - 0.5 * t) * rng.uniform(0.6, 1.0), bristle=0.4, dry=0.4)
    save_rgba(cv, "tv_smoke_wisps.png", tvp.blur_clamped(cv.alpha, 4.0) * 0.8)
    print("mist done", flush=True)

    # ---------------- river
    wd = ramp("water_depth")  # deep, mid, shallow, over white stones
    ws = ramp("white_stone")
    depths = [0.0, 0.25, 0.8, 1.8, 4.0]
    day = [mix(wd[3], ws[2], 0.25), wd[3], wd[2], wd[1], wd[0]]
    still = [mix(wd[3], ws[3], 0.45), mix(wd[3], ws[2], 0.2), mix(wd[2], wd[3], 0.45), mix(wd[1], wd[2], 0.4), wd[0]]
    x = np.linspace(0, 4.0, 256)
    img = np.zeros((8, 256, 3), np.float32)
    for row, stops in ((0, day), (4, still)):
        s = np.stack([tvp.l2s(c) for c in stops])
        col = np.stack([np.interp(x, depths, s[:, k]) for k in range(3)], -1)
        img[row:row + 4] = col[None]
    Image.fromarray(tvp.to_u8(img)).save(os.path.join(OUT, "tv_river_ramp.png"))
    # flow streaks (tile both ways)
    cv = tvp.Canvas(1024, 1024, 1.0, 9800, wd, alpha=True, wrap=True, bristle=0.5)
    cv.col[:] = mix(wd[3], ws[3], 0.5)
    rng = cv.rng
    for i in range(420):
        x, y = rng.uniform(0, 1024), rng.uniform(0, 1024)
        L = rng.uniform(60, 260)
        cv.dab(x, y, L, rng.uniform(2, 7), rng.uniform(-0.04, 0.04), mix(wd[3], ws[3], rng.uniform(0.3, 0.9)),
               alpha_add=True, edge=0.4, opacity=rng.uniform(0.3, 0.8), bristle=0.5, dry=0.6, taper=0.6,
               bend=rng.uniform(-0.15, 0.15))
    save_rgba(cv, "tv_river_flow.png", np.clip(cv.alpha * 0.8, 0, 1))
    cv = tvp.Canvas(1024, 1024, 1.0, 9810, r4, alpha=True, wrap=True, bristle=0.4)
    cv.col[:] = tvp.ramp_at(r4, 0.8)
    rng = cv.rng
    for i in range(90):
        x, y = rng.uniform(0, 1024), rng.uniform(0, 1024)
        lumpy(cv, x, y, rng.uniform(30, 80), r4, n=8, flat=0.6, soft=0.35, opacity=0.7, spread=0.9)
    holes = tvp.smoothstep(-0.3, 0.3, tvp.periodic_field(1024, 1024, rng, 20, 6, slope=0.5))
    save_rgba(cv, "tv_river_foam.png", np.clip(cv.alpha, 0, 1) * holes)
    meta["river_ramp"] = {"file": "water/tv_river_ramp.png", "x": "depth 0..4 m linear",
                          "rows": {"0-3": "day", "4-7": "still S1"}, "stops_m": depths}
    meta["river_shader_uniforms"] = {}
    for dn, d in tvp.PAL["directions"].items():
        rv = tvp.hex_srgb(d["targets"]["river"])
        meta["river_shader_uniforms"][dn] = {
            "shallow_tint": [round(float(v), 3) for v in mix(tvp.l2s(wd[3]), rv, 0.35)],
            "deep_color": [round(float(v), 3) for v in mix(tvp.l2s(wd[0]), rv * 0.4, 0.3)],
            "absorb": 0.9, "still_absorb": 0.25}
    meta["scroll_m_per_s"] = {"fall_body": 0.8, "fall_streaks": 1.4, "river_flow": "flow_speed (0.6)",
                              "mist_bands": 0.5}
    json.dump(meta, open(os.path.join(OUT, "water.json"), "w"), indent=1)
    print("river done", flush=True)


if __name__ == "__main__":
    main()
