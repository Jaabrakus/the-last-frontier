#!/usr/bin/env python3
"""Before / after pictures of a vault's speed (vault speed push 2026-09-26) from two runs of
tools/traversal/vault_speed_strips.gd (side-view frames every 1/30 s and frames.json):

  chrono: a chronophotograph per run, the body every 0.1 s over the empty background (the run goes left to
          right; the spacing of the figures is the speed; the stakes are 1 m apart), with the capsule
          (dashed) and rendered-pelvis (solid) speed under it, the move's time shaded;
  strip:  a filmstrip per run, the body at even steps through the move and just after it (pose and
          contacts).

  python3 tools/traversal/vault_speed_compose.py BEFORE_DIR AFTER_DIR OUT_PREFIX "title"
Writes OUT_PREFIX_chrono.png and OUT_PREFIX_strip.png. Needs Pillow and numpy.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H = 1280, 720
VIEW_M = 10.0                 # the strips tool's view width (VIEW_BACK + VIEW_FWD)
BAND = (170, 640)             # rows of the frames kept (sky above, ground below)
STEP = 0.1


def font(size):
    for f in ["/System/Library/Fonts/Helvetica.ttc", "/System/Library/Fonts/SFNS.ttf", "/Library/Fonts/Arial.ttf"]:
        if os.path.exists(f):
            try:
                return ImageFont.truetype(f, size)
            except OSError:
                pass
    return ImageFont.load_default()


def load(d):
    meta = json.load(open(os.path.join(d, "frames.json")))
    plate = np.asarray(Image.open(os.path.join(d, "plate.png")).convert("RGB")).astype(np.int16)
    return meta, plate


def px_of(meta, z):
    z_back, z_fwd = meta["view"]
    zc = 0.5 * (z_back + z_fwd)
    return int(round(W * 0.5 + (zc - z) * W / VIEW_M))


def pick(meta, t0, t1, step):
    frames = meta["frames"]
    out = []
    t = t0
    while t <= t1 + 1e-6:
        best = min(frames, key=lambda f: abs(f["t_rel"] - t))
        if abs(best["t_rel"] - t) < 0.03 and (not out or out[-1]["file"] != best["file"]):
            out.append(best)
        t += step
    return out


def chrono(d, label, fnt, fnt_s):
    meta, plate = load(d)
    dur = (meta["ended"] - meta["began"]) if meta["ended"] and meta["ended"] > 0 else 1.0
    sel = pick(meta, -0.5, dur + 0.7, STEP)
    comp = plate.copy()
    for f in sel:
        img = np.asarray(Image.open(os.path.join(d, f["file"])).convert("RGB")).astype(np.int16)
        diff = np.abs(img - plate).sum(axis=2) > 36
        comp[diff] = img[diff]
    im = Image.fromarray(comp.clip(0, 255).astype(np.uint8)).crop((0, BAND[0], W, BAND[1]))
    dr = ImageDraw.Draw(im)
    for k, f in enumerate(sel):
        x = px_of(meta, f["z"])
        y = 8 + (k % 2) * 18
        col = (255, 235, 120) if f["mode"] != "OFF" else (235, 235, 235)
        dr.text((x - 14, y), "%+.1f" % f["t_rel"], fill=col, font=fnt_s)
    s = meta["summary"]
    dr.text((12, BAND[1] - BAND[0] - 70), "%s   %s at %s: %s" % (label, meta["gait"], meta["obstacle"], meta["move"]), fill=(255, 255, 255), font=fnt)
    dr.text((12, BAND[1] - BAND[0] - 42), "entry %.1f m/s, lowest %.1f (body) / %.1f (model), exit %.1f m/s, move %.2f s  (figures every 0.1 s, yellow = in the move)" % (
        s["entry"], s["min_cap"], s["min_model"], s["exit"], s["duration"]), fill=(255, 255, 255), font=fnt_s)
    return im, meta


def plot(meta, fnt_s, t0=-1.0, t1=2.0, vmax=8.0, h=150):
    im = Image.new("RGB", (W, h), (28, 30, 32))
    dr = ImageDraw.Draw(im)
    x0, x1, y0, y1 = 60, W - 20, 10, h - 22

    def X(t):
        return x0 + (t - t0) / (t1 - t0) * (x1 - x0)

    def Y(v):
        return y1 - max(0.0, min(v, vmax)) / vmax * (y1 - y0)

    dur = (meta["ended"] - meta["began"]) if meta["ended"] and meta["ended"] > 0 else 0.0
    dr.rectangle((X(0), y0, X(dur), y1), fill=(60, 55, 30))
    for v in range(0, int(vmax) + 1, 2):
        dr.line((x0, Y(v), x1, Y(v)), fill=(55, 58, 62))
        dr.text((8, Y(v) - 7), "%d m/s" % v, fill=(170, 170, 170), font=fnt_s)
    t = t0
    while t <= t1 + 1e-6:
        dr.text((X(t) - 10, y1 + 4), "%+.1f" % t, fill=(170, 170, 170), font=fnt_s)
        t += 0.5
    e = meta["summary"]["entry"] or 0.0
    dr.line((x0, Y(e * 0.85), x1, Y(e * 0.85)), fill=(120, 60, 60))
    pr = [p for p in meta["profile"] if t0 <= p[0] <= t1]
    pts_c = [(X(p[0]), Y(p[1])) for p in pr]
    pts_m = [(X(p[0]), Y(p[2])) for p in pr]
    for i in range(0, len(pts_c) - 1, 2):
        dr.line((pts_c[i], pts_c[i + 1]), fill=(120, 190, 255), width=2)
    if len(pts_m) > 1:
        dr.line(pts_m, fill=(255, 200, 90), width=2)
    dr.text((x1 - 560, y0), "model (rendered pelvis, 0.1 s mean)   body (capsule, dashed)   red: 85 % of entry", fill=(200, 200, 200), font=fnt_s)
    return im


def strip(d, label, fnt_s, n=7, cw=250, ch=330):
    meta, plate = load(d)
    dur = (meta["ended"] - meta["began"]) if meta["ended"] and meta["ended"] > 0 else 1.0
    times = [dur * k / (n - 2) for k in range(n - 1)] + [dur + 0.25]
    out = Image.new("RGB", (cw * n, ch + 22), (28, 30, 32))
    dr = ImageDraw.Draw(out)
    for k, t in enumerate(times):
        f = min(meta["frames"], key=lambda q: abs(q["t_rel"] - t))
        img = Image.open(os.path.join(d, f["file"])).convert("RGB")
        x = px_of(meta, f["z"])
        box = (x - cw // 2, BAND[0] + 10, x + cw // 2, BAND[0] + 10 + ch)
        out.paste(img.crop(box), (k * cw, 22))
        dr.text((k * cw + 6, 3), "%s %+.2f s  %.1f m/s" % (label if k == 0 else "", f["t_rel"], f["v_model"]), fill=(230, 230, 230), font=fnt_s)
    return out


def main():
    before, after, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
    title = sys.argv[4] if len(sys.argv) > 4 else ""
    fnt = font(20)
    fnt_s = font(14)
    rows = []
    head = Image.new("RGB", (W, 40), (20, 20, 22))
    ImageDraw.Draw(head).text((12, 8), title, fill=(255, 255, 255), font=fnt)
    rows.append(head)
    for d, lab in [(before, "BEFORE"), (after, "AFTER")]:
        im, meta = chrono(d, lab, fnt, fnt_s)
        rows.append(im)
        rows.append(plot(meta, fnt_s))
    hh = sum(r.height for r in rows)
    out = Image.new("RGB", (W, hh), (20, 20, 22))
    y = 0
    for r in rows:
        out.paste(r, (0, y))
        y += r.height
    out.save(prefix + "_chrono.png")
    s1 = strip(before, "BEFORE", fnt_s)
    s2 = strip(after, "AFTER", fnt_s)
    st = Image.new("RGB", (s1.width, s1.height + s2.height + 4), (20, 20, 22))
    st.paste(s1, (0, 0))
    st.paste(s2, (0, s1.height + 4))
    st.save(prefix + "_strip.png")
    print("wrote", prefix + "_chrono.png", prefix + "_strip.png")


if __name__ == "__main__":
    main()
