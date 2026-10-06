#!/usr/bin/env python3
"""Internal plots of R1's water network (water.json through water_net.py), for the builders, not the owner:

    python3 tools/environment/water/plot_network.py --out DIR [--layout PATH] [--sketch PNG]

  network_grid.png         top down over the layout's squares: the channels and pounds coloured by level (the M2 pounds
                           dashed), the Silent Reach, the falls, the junction, the lock step and the landmarks; insets of
                           the torrent's mouth (level and current) and of the lock and basin at M2
  network_over_sketch.png  the same network drawn over the planning sketch (--sketch: the plan's r1_slice_layout.png,
                           which predates the re-cut: its D column is gone and row 4 is added below it)
  flow_profile.png         the speed along the main channel's centre line, S0 against S1, with its surface below
  pound_levels.png         the downstream pounds' level over the river's first 30 still days
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from water_net import WATER, WaterNet  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
LAYOUT = os.path.join(ROOT, "data", "world", "maps", "r1", "layout.json")
FONT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
PAPER = (241, 233, 214)
INK = (52, 44, 36)
GRID = (150, 140, 120)
STILL = (236, 244, 250)
FALL = (190, 50, 40)
STEP = (120, 60, 40)
S0_COL = (40, 110, 170)
S1_COL = (200, 90, 40)


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def level_colour(lv, lo=90.0, hi=235.0):
    """Deep blue (low) through teal to pale green (high)."""
    u = min(max((lv - lo) / (hi - lo), 0.0), 1.0)
    stops = [(0.0, (30, 70, 150)), (0.3, (40, 130, 180)), (0.6, (60, 170, 160)), (1.0, (170, 215, 150))]
    for (u0, c0), (u1, c1) in zip(stops, stops[1:]):
        if u <= u1:
            k = (u - u0) / (u1 - u0)
            return tuple(int(a + (b - a) * k) for a, b in zip(c0, c1))
    return stops[-1][1]


def banks(ch):
    """Left and right bank polylines (x, z) of a channel."""
    dx = np.gradient(ch.x)
    dz = np.gradient(ch.z)
    L = np.hypot(dx, dz)
    rx, rz = -dz / L, dx / L
    right = np.c_[ch.x + rx * ch.hw, ch.z + rz * ch.hw]
    left = np.c_[ch.x - rx * ch.hw, ch.z - rz * ch.hw]
    return left, right, (rx, rz)


def dashed_poly(d, pts, col, w=2, dash=8, gap=5):
    pts = list(pts) + [pts[0]]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        L = math.hypot(bx - ax, by - ay)
        n = max(int(L // (dash + gap)), 1)
        for i in range(n + 1):
            s, e = i * (dash + gap) / L, min((i * (dash + gap) + dash) / L, 1.0)
            if s >= 1.0:
                break
            d.line([(ax + (bx - ax) * s, ay + (by - ay) * s), (ax + (bx - ax) * e, ay + (by - ay) * e)], fill=col, width=w)


def draw_network(img, net, lay, to_px, scale, labels=True, lw=1):
    """The network on img (RGBA) through to_px(x, z) -> (px, py); scale px per m."""
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for p in net.pounds:
        poly = [to_px(x, z) for x, z in p["polygon"]]
        col = level_colour(p["level"])
        d.polygon(poly, fill=col + (200,))
        if p["milestone"] == "M2":
            dashed_poly(d, poly, (30, 30, 30, 255), w=max(lw, 1), dash=5, gap=4)
        else:
            d.polygon(poly, outline=(30, 30, 30, 255))
    for ch in net.channels:
        left, right, _ = banks(ch)
        for i in range(len(ch.s) - 1):
            q = [to_px(*left[i]), to_px(*left[i + 1]), to_px(*right[i + 1]), to_px(*right[i])]
            d.polygon(q, fill=level_colour(0.5 * (ch.level[i] + ch.level[i + 1])) + (235,))
        d.line([to_px(*p) for p in left], fill=(20, 40, 80, 255), width=lw)
        d.line([to_px(*p) for p in right], fill=(20, 40, 80, 255), width=lw)
        for r in ch.reaches:
            m = (ch.s >= r["s_from"]) & (ch.s <= r["s_to"])
            for i in np.flatnonzero(m)[:-1]:
                q = [to_px(*left[i]), to_px(*left[i + 1]), to_px(*right[i + 1]), to_px(*right[i])]
                d.polygon(q, fill=STILL + (235,))
            for s in (r["s_from"], r["s_to"]):
                i = int(np.searchsorted(ch.s, s))
                d.line([to_px(*left[i]), to_px(*right[i])], fill=(90, 120, 160, 255), width=max(2, lw))
        for f in ch.d.get("falls", []):
            i = int(np.searchsorted(ch.s, 0.5 * (f["s_from"] + f["s_to"])))
            a, b = to_px(*left[i]), to_px(*right[i])
            d.line([a, b], fill=FALL + (255,), width=max(3, 2 * lw))
        for st in ch.steps:
            for s in (st["s_upper"], st["s_lower"]):
                i = int(np.searchsorted(ch.s, s))
                d.line([to_px(*left[i]), to_px(*right[i])], fill=STEP + (255,), width=max(2, lw))
    for j in net.data.get("junctions", []):
        x, y = to_px(*j["at"])
        rr = max(4, j["mouth_m"] * scale)
        d.ellipse([x - rr, y - rr, x + rr, y + rr], outline=(200, 40, 140, 255), width=2)
    img.alpha_composite(over)
    if labels and lay:
        d2 = ImageDraw.Draw(img)
        for name, lm in lay.get("landmarks", {}).items():
            ats = lm["at"] if isinstance(lm["at"][0], list) else [lm["at"]]
            for at in ats:
                x, y = to_px(*at)
                d2.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(180, 60, 40, 255), outline=(255, 255, 255, 255))
            x, y = to_px(*ats[0])
            d2.text((x + 6, y - 7), name.replace("_", " "), font=font(12), fill=INK + (255,))


def plot_grid(net, lay, out):
    sq = lay["square_m"]
    cols, rows = lay["grid"]["cols"], lay["grid"]["rows"]
    ccx = lay["grid"]["col_center_x"]
    rcz = lay["grid"]["row_center_z"]
    x0 = min(ccx.values()) - sq / 2
    z0 = min(rcz.values()) - sq / 2
    S = 0.36                           # px per m
    OX, OY = 70, 90
    W = OX + int(len(cols) * sq * S) + 560
    H = OY + int(len(rows) * sq * S) + 70
    img = Image.new("RGBA", (W, H), PAPER + (255,))
    d = ImageDraw.Draw(img)
    d.text((24, 18), "R1 water network (water.json, M1 + M2 pounds dashed): top down, north up", font=font(24), fill=INK)
    d.text((24, 52), "colour = surface level (m); pale = the Silent Reach (S1 still); red bars = falls; brown = lock step "
                     "(M2); pink ring = torrent mouth", font=font(14), fill=INK)

    def to_px(x, z):
        return OX + (x - x0) * S, OY + (z - z0) * S

    for ci, c in enumerate(cols):
        for r in rows:
            cx, cz = ccx[c], rcz[str(r)]
            a, b = to_px(cx - sq / 2, cz - sq / 2), to_px(cx + sq / 2, cz + sq / 2)
            d.rectangle([a, b], outline=GRID, width=2)
            d.text((a[0] + 6, a[1] + 4), "%s%d %s" % (c, r, lay["grid"]["cells"]["%s%d" % (c, r)]), font=font(13), fill=INK)
    draw_network(img, net, lay, to_px, S, labels=True, lw=1)
    # level key
    kx, ky = OX + int(len(cols) * sq * S) + 30, OY
    d = ImageDraw.Draw(img)
    for k in range(200):
        lv = 235.0 - (235.0 - 90.0) * k / 199.0
        d.line([(kx, ky + k), (kx + 18, ky + k)], fill=level_colour(lv))
    for lv in (235, 200, 160, 120, 90):
        y = ky + (235 - lv) / (235 - 90) * 199
        d.text((kx + 24, y - 7), "%d m" % lv, font=font(12), fill=INK)
    # insets: the torrent's mouth, the lock and basin at M2
    ins = [("torrent mouth (S0, M1): level and current", net, (752.0, -352.0), 70.0, 0.5),
           ("lock and barge basin (M2)", None, (880.0, 470.0), 140.0, 1.0)]
    iy = ky + 230
    for title, n, (cx, cz), half, mpp in ins:
        if n is None:
            n = WaterNet(net.data)
            n.set_milestone("M2")
        size = int(2 * half / mpp)
        xs = cx - half + (np.arange(size) + 0.5) * mpp
        zs = cz - half + (np.arange(size) + 0.5) * mpp
        X, Z = np.meshgrid(xs, zs)
        surf = n.surface_at(X, Z)
        fin = np.isfinite(surf)
        lo, hi = (surf[fin].min(), surf[fin].max()) if fin.any() else (0, 1)
        arr = np.zeros((size, size, 3), dtype=np.uint8)
        arr[:] = PAPER
        u = np.clip((surf - lo) / max(hi - lo, 1e-6), 0, 1)
        c0, c1 = (30, 70, 150), (170, 215, 150)
        for ch in range(3):
            arr[..., ch] = np.where(fin, (c0[ch] + (c1[ch] - c0[ch]) * np.nan_to_num(u)).astype(np.uint8), arr[..., ch])
        tile = Image.fromarray(arr).resize((260, 260), Image.NEAREST).convert("RGBA")
        dt = ImageDraw.Draw(tile)
        k = 260 / size
        cxs, czs = n.current_at(X, Z)
        for i in range(0, size, max(size // 14, 1)):
            for j in range(0, size, max(size // 14, 1)):
                if fin[j, i] and (cxs[j, i] or czs[j, i]):
                    v = math.hypot(cxs[j, i], czs[j, i])
                    a = ((i + 0.5) * k, (j + 0.5) * k)
                    b = (a[0] + cxs[j, i] / v * 9, a[1] + czs[j, i] / v * 9)
                    dt.line([a, b], fill=(255, 255, 255, 255), width=1)
                    dt.ellipse([b[0] - 1.5, b[1] - 1.5, b[0] + 1.5, b[1] + 1.5], fill=(255, 255, 255, 255))
        img.alpha_composite(tile, (kx, iy + 22))
        d = ImageDraw.Draw(img)
        d.text((kx, iy), title, font=font(13), fill=INK)
        d.text((kx + 268, iy + 30), "%.2f m" % hi, font=font(12), fill=INK)
        d.text((kx + 268, iy + 262), "%.2f m" % lo, font=font(12), fill=INK)
        d.text((kx + 268, iy + 140), "%d m across" % int(2 * half), font=font(12), fill=INK)
        iy += 310
    img.convert("RGB").save(os.path.join(out, "network_grid.png"))


def plot_sketch(net, lay, sketch, out):
    src = Image.open(sketch).convert("RGBA")
    S, OX, OY = 300, 90, 170            # the sketch's own scale and origin (draw_regions.py)
    top = 3 * S + OY
    img = Image.new("RGBA", (src.width, src.height + S), PAPER + (255,))
    img.alpha_composite(src.crop((0, 0, src.width, top)), (0, 0))
    img.alpha_composite(src.crop((0, top, src.width, src.height)), (0, top + S))
    veil = Image.new("RGBA", img.size, (255, 255, 255, 0))
    ImageDraw.Draw(veil).rectangle([0, OY, OX + 4 * S + 2, top + S], fill=(255, 255, 255, 120))
    img.alpha_composite(veil)
    d = ImageDraw.Draw(img)
    sq = lay["square_m"]
    x0 = min(lay["grid"]["col_center_x"].values()) - sq / 2
    z0 = min(lay["grid"]["row_center_z"].values()) - sq / 2

    def to_px(x, z):
        return OX + (x - x0) / sq * S, OY + (z - z0) / sq * S

    for c in lay["grid"]["cols"]:
        for r in lay["grid"]["rows"]:
            cx, cz = lay["grid"]["col_center_x"][c], lay["grid"]["row_center_z"][str(r)]
            a, b = to_px(cx - sq / 2, cz - sq / 2), to_px(cx + sq / 2, cz + sq / 2)
            d.rectangle([a, b], outline=(60, 60, 160), width=3)
            d.text((a[0] + 6, b[1] - 22), "%s%d (re-cut)" % (c, r), font=font(14), fill=(60, 60, 160))
    draw_network(img, net, lay, to_px, S / sq, labels=False, lw=2)
    d = ImageDraw.Draw(img)
    d.rectangle([20, 118, 1300, 160], fill=(255, 250, 235))
    d.text((28, 124), "OVERLAY (internal): water.json's network over the planning sketch. Blue frames = the re-cut 3 x 4 "
                      "grid; the sketch's D column and its old river are superseded.", font=font(16), fill=(60, 60, 160))
    img.convert("RGB").save(os.path.join(out, "network_over_sketch.png"))


def chart(w, h, title):
    img = Image.new("RGB", (w, h), (252, 250, 245))
    d = ImageDraw.Draw(img)
    d.text((20, 14), title, font=font(20), fill=INK)
    return img, d


def axes(d, box, xr, yr, xt, yt, xlabel, ylabel):
    x0, y0, x1, y1 = box
    d.rectangle(box, outline=(120, 120, 120))
    fx = lambda v: x0 + (v - xr[0]) / (xr[1] - xr[0]) * (x1 - x0)  # noqa: E731
    fy = lambda v: y1 - (v - yr[0]) / (yr[1] - yr[0]) * (y1 - y0)  # noqa: E731
    for v in xt:
        d.line([(fx(v), y1), (fx(v), y1 + 5)], fill=(120, 120, 120))
        d.text((fx(v) - 12, y1 + 8), ("%g" % v), font=font(12), fill=INK)
        d.line([(fx(v), y0), (fx(v), y1)], fill=(232, 228, 220))
    for v in yt:
        d.line([(x0 - 5, fy(v)), (x0, fy(v))], fill=(120, 120, 120))
        d.text((x0 - 52, fy(v) - 7), ("%g" % v), font=font(12), fill=INK)
        d.line([(x0, fy(v)), (x1, fy(v))], fill=(232, 228, 220))
    d.text(((x0 + x1) / 2 - 80, y1 + 26), xlabel, font=font(13), fill=INK)
    d.text((x0 - 60, y0 - 22), ylabel, font=font(13), fill=INK)
    return fx, fy


def plot_profile(net, out):
    ch = net.by_id["main"]
    s = np.linspace(0.0, ch.s[-1], 1600)
    i = np.clip(np.searchsorted(ch.s, s, side="right") - 1, 0, len(ch.s) - 2)
    t = (s - ch.s[i]) / (ch.s[i + 1] - ch.s[i])
    speed = ch.speed[i] + t * (ch.speed[i + 1] - ch.speed[i])
    v0 = speed * WaterNet(net.data).flow_factor(ch, s)
    n1 = WaterNet(net.data)
    n1.set_state("S1")
    v1 = speed * n1.flow_factor(ch, s)
    lv = net.level_at_s("main", s)
    img, d = chart(1200, 760, "Main channel: centre-line speed along it, S0 (running) vs S1 (the Silent Reach still); its surface below")
    box = (90, 70, 1160, 400)
    fx, fy = axes(d, box, (0, 3400), (0, 0.8), range(0, 3401, 400), [0, 0.2, 0.4, 0.6, 0.8], "s, m along (north to south)", "m/s")
    r = ch.reaches[0]
    d.rectangle([fx(r["s_from"]), box[1] + 1, fx(r["s_to"]), box[3] - 1], fill=(232, 240, 248))
    for e in (r["s_from"] - r["ease_m"], r["s_to"] + r["ease_m"]):
        d.line([(fx(e), box[1]), (fx(e), box[3])], fill=(170, 190, 215))
    d.text((fx(r["s_from"]) + 4, box[1] + 4), "Silent Reach (z %d to %d, ease %d m)" % (r["z_from"], r["z_to"], r["ease_m"]), font=font(12), fill=INK)
    j = net.data["junctions"][0]
    st = ch.steps[0]
    for x, lab, col in ((j["s_into"], "torrent joins", (200, 40, 140)), (st["s_upper"], "Fifth Lock step (M2)", STEP)):
        d.line([(fx(x), box[1]), (fx(x), box[3])], fill=col, width=2)
        d.text((fx(x) + 4, box[1] + 22), lab, font=font(12), fill=col)
    d.line([(fx(a), fy(b)) for a, b in zip(s, v0)], fill=S0_COL, width=3)
    d.line([(fx(a), fy(b)) for a, b in zip(s, v1)], fill=S1_COL, width=2)
    d.text((box[2] - 220, box[1] + 8), "S0", font=font(14), fill=S0_COL)
    d.text((box[2] - 190, box[1] + 8), "S1 (S2-S4 the same)", font=font(14), fill=S1_COL)
    box2 = (90, 470, 1160, 700)
    fx2, fy2 = axes(d, box2, (0, 3400), (90, 145), range(0, 3401, 400), range(90, 146, 10), "s, m along", "surface, m")
    d.line([(fx2(a), fy2(b)) for a, b in zip(s, lv)], fill=(40, 70, 120), width=2)
    m2 = WaterNet(net.data)
    m2.set_milestone("M2")
    lv2 = m2.level_at_s("main", s)
    d.line([(fx2(a), fy2(b)) for a, b in zip(s, lv2)], fill=STEP, width=1)
    d.text((box2[2] - 330, box2[1] + 8), "M1 (dark): the layout's levels; M2 (brown): the lock step held", font=font(12), fill=INK)
    img.save(os.path.join(out, "flow_profile.png"))


def plot_pounds(net, out):
    days = np.linspace(0.0, 30.0, 301)
    img, d = chart(1000, 560, "Downstream pounds: level over the river's first 30 still days (bible days since S1 began)")
    pids = [p["id"] for p in net.pounds if p.get("curve")]
    lvs = {pid: net.pound_level_at(pid, days) for pid in pids}
    lo = min(v.min() for v in lvs.values())
    hi = max(v.max() for v in lvs.values())
    box = (90, 70, 960, 460)
    fx, fy = axes(d, box, (-3, 30), (math.floor(lo * 2) / 2 - 0.25, hi + 0.25), [0, 5, 10, 15, 20, 25, 30],
                  list(np.arange(math.floor(lo * 2) / 2, hi + 0.26, 0.25)), "days since the river stopped", "level, m")
    d.line([(fx(0), box[1]), (fx(0), box[3])], fill=S1_COL, width=2)
    d.text((fx(0) + 4, box[1] + 4), "S1: the river stops", font=font(12), fill=S1_COL)
    cols = [(40, 110, 170), (40, 150, 100)]
    for k, pid in enumerate(pids):
        v = lvs[pid]
        pts = [(fx(-3), fy(v[0])), (fx(0), fy(v[0]))] + [(fx(a), fy(b)) for a, b in zip(days, v)]
        d.line(pts, fill=cols[k % 2], width=4 - 2 * k)
        d.text((fx(20), fy(v[200]) - 22 - 16 * k), "%s (%.2f m by day 30)" % (pid.replace("_", " "), v[0] - v[-1]),
               font=font(13), fill=cols[k % 2])
    cv = net.curves["downstream_drop"]
    d.text((90, 500), "curve downstream_drop (status %s): -%.1f m x (1 - e^(-day / %g)); both pounds sit at %g m before S1"
           % (cv["status"], cv["drop_m"], cv["tau_days"], net.pound_by_id[pids[0]]["level"]), font=font(13), fill=INK)
    img.save(os.path.join(out, "pound_levels.png"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--layout", default=LAYOUT)
    ap.add_argument("--sketch", default="")
    ap.add_argument("--water", default=WATER)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    net = WaterNet.load(a.water)
    with open(a.layout, encoding="utf-8") as fh:
        lay = json.load(fh)
    plot_grid(net, lay, a.out)
    if a.sketch:
        plot_sketch(net, lay, a.sketch, a.out)
    plot_profile(net, a.out)
    plot_pounds(net, a.out)
    print("wrote the plots to", a.out)


if __name__ == "__main__":
    main()
