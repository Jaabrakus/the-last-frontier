#!/usr/bin/env python3
"""P04: cloth and marks (style guide 4, 9). Our own marks only: straight cuts and at most one ring each, as a mason
or a dyer would cut them. Nothing resembles the swirl emblem on the Trường Sơn waystone sheet (an Avatar-like emblem
that must not be reproduced), no Hán characters, no Tidebreak element glyphs, no Thạch Uyên diamond knot.

    python3 tools/thuyvan_art/paint/paint_marks.py

Writes into assets/thuyvan/paint/cloth/:
  tv_clan_marks.png            3 clan marks, white on transparent, 512 px cells (1536 x 512):
                               0 "twin peaks" (two chevrons over a bar and three tally notches; the Mountain Folk clan
                               of the reach), 1 "ladder" (two rails, three rungs, a roof-peak above; the bridge clan),
                               2 "set stone" (one ring resting on a ledge bar, two posts below; the waystone keepers)
  tv_banner_{indigo,ochre,jade}.png   512 x 1536 RGBA (1:3): painted cloth field with folds, sleeve at the top for the
                               crossbar, a bone-white mark in the upper third, a madder band and two ragged madder
                               tails (alpha); mark 0, 1, 2 respectively
  tv_prayer_flags.png          1024 x 512 RGBA atlas, 5 x 2 cells of 204 x 256: rags 30 x 45 cm in indigo, madder,
                               ochre, bone and jade, ragged hems, a rope sleeve on top; row 1 carries a small printed
                               tally (dots and bars, not writing)
  tv_waystone_mark.png         512^2 RGBA decal: mark 0 cut into stone (V-cut: shadowed upper wall, lit lower wall)
                               and a column of tally notches; alpha = the cut
  tv_maker_sign_a.png / _b.png 512^2 RGBA decals: the two different maker signs on one Two Heights pier (bible L16).
                               A "square and cut": a square with one corner-to-corner cut and a notch, cut in thin deep
                               lines; B "stepped stones": three stacked bars stepping in, with one ring above, pecked
                               (stippled) by a different hand
  cloth.json                   cell rects and colours
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvp  # noqa: E402
from tvp import lin, mix, ramp  # noqa: E402

SS = 4  # supersampling for the vector marks


# ------------------------------------------------------------------ marks (unit square, y down, stroke width w)

def mark_shapes(i):
    """Return (polylines, rings, width): polylines as lists of (x, y) in 0..1, rings as (cx, cy, r)."""
    if i == 0:  # twin peaks
        return ([[(0.12, 0.52), (0.31, 0.2), (0.5, 0.52)], [(0.5, 0.52), (0.69, 0.2), (0.88, 0.52)],
                 [(0.1, 0.64), (0.9, 0.64)], [(0.32, 0.74), (0.32, 0.9)], [(0.5, 0.74), (0.5, 0.9)],
                 [(0.68, 0.74), (0.68, 0.9)]], [], 0.075)
    if i == 1:  # ladder with a roof peak
        return ([[(0.3, 0.32), (0.3, 0.92)], [(0.7, 0.32), (0.7, 0.92)], [(0.3, 0.46), (0.7, 0.46)],
                 [(0.3, 0.64), (0.7, 0.64)], [(0.3, 0.82), (0.7, 0.82)], [(0.14, 0.34), (0.5, 0.1), (0.86, 0.34)]],
                [], 0.07)
    if i == 2:  # set stone: one ring on a ledge, two posts
        return ([[(0.12, 0.6), (0.88, 0.6)], [(0.3, 0.6), (0.3, 0.9)], [(0.7, 0.6), (0.7, 0.9)]],
                [(0.5, 0.36, 0.2)], 0.07)
    if i == 10:  # maker A: square and cut
        return ([[(0.2, 0.2), (0.8, 0.2), (0.8, 0.8), (0.2, 0.8), (0.2, 0.2)], [(0.2, 0.8), (0.8, 0.2)],
                 [(0.5, 0.2), (0.5, 0.08)]], [], 0.035)
    if i == 11:  # maker B: stepped stones and a ring
        return ([[(0.14, 0.86), (0.86, 0.86)], [(0.24, 0.7), (0.76, 0.7)], [(0.34, 0.54), (0.66, 0.54)]],
                [(0.5, 0.3, 0.1)], 0.09)
    raise ValueError(i)


def mark_mask(i, size, pad=0.0):
    S = size * SS
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    lines, rings, w = mark_shapes(i)
    W = max(int(w * S), 1)
    f = lambda p: ((pad + p[0] * (1 - 2 * pad)) * S, (pad + p[1] * (1 - 2 * pad)) * S)
    for pl in lines:
        pts = [f(p) for p in pl]
        d.line(pts, fill=255, width=W, joint="curve")
        for p in (pts[0], pts[-1]):
            d.rectangle([p[0] - W / 2, p[1] - W / 2, p[0] + W / 2, p[1] + W / 2], fill=255)
    for (cx, cy, r) in rings:
        c = f((cx, cy))
        rr = r * (1 - 2 * pad) * S
        d.ellipse([c[0] - rr - W / 2, c[1] - rr - W / 2, c[0] + rr + W / 2, c[1] + rr + W / 2], fill=255)
        d.ellipse([c[0] - rr + W / 2, c[1] - rr + W / 2, c[0] + rr - W / 2, c[1] + rr - W / 2], fill=0)
    return np.asarray(im.resize((size, size), Image.LANCZOS), np.float32) / 255.0


def brushy(mask, rng, amt=0.06, sigma=1.2):
    """Give a vector mask a painted edge: wobble its threshold with a smooth field."""
    h, w = mask.shape
    f = tvp.periodic_field(h, w, rng, 12, 4)
    m = tvp.blur(mask, sigma)
    return tvp.smoothstep(0.42, 0.58, m + amt * f)


# ------------------------------------------------------------------ cloth

def cloth_field(h, w, color_ramp, seed, folds=10):
    """Painted cloth: field colour, soft vertical fold strokes (lit and shadowed), faint weave of low strokes."""
    cv = tvp.Canvas(h, w, w / 512.0 * 0.5, seed, color_ramp, wrap=False)
    r4 = cv.ramp
    rng = cv.rng
    cv.base(dv=0.06)
    for _ in range(folds):
        x = rng.uniform(0, w)
        L = h * rng.uniform(0.25, 0.6)
        y = rng.uniform(L * 0.5, h)
        wd = w * rng.uniform(0.03, 0.07)
        cv.dab(x, y, L / 2, wd, math.pi / 2 + rng.uniform(-0.08, 0.08), cv.vary(r4[0], x, y), opacity=0.45, edge=0.3,
               taper=0.6)
        cv.dab(x + wd * 1.4, y, L / 2 * 0.9, wd * 0.6, math.pi / 2, cv.vary(r4[2], x, y), opacity=0.35, edge=0.3,
               taper=0.6)
    for _ in range(int(h * w / 4000)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        L = w * rng.uniform(0.04, 0.1)
        cv.dab(x, y, L, L * 0.5, rng.uniform(0, 3), cv.vary(cv.pick((0.3, 0.4, 0.3, 0.0)), x, y), opacity=0.25,
               wob=0.2, edge=0.4)
    return cv


def banner(field_ramp, mark_i, seed, name):
    W, H = 512, 1536
    rng = np.random.default_rng(seed)
    cv = cloth_field(H, W, field_ramp, seed, folds=14)
    col = cv.col
    bone, madder = ramp("bone_cloth"), ramp("madder_cloth")
    # sleeve (top 7%): darker, a seam line
    sl = int(H * 0.07)
    col[:sl] = col[:sl] * 0.7
    col[sl - 6:sl - 2] = mix(col[sl - 6:sl - 2], bone[0][None, None, :], 0.6)
    # bone border bands at both sides
    bw = int(W * 0.06)
    for x0 in (int(W * 0.05), W - int(W * 0.05) - bw):
        col[sl:int(H * 0.8), x0:x0 + bw] = mix(col[sl:int(H * 0.8), x0:x0 + bw], bone[1][None, None, :], 0.85)
    # mark in the upper third
    ms = int(W * 0.66)
    m = brushy(mark_mask(mark_i, ms, pad=0.04), rng, 0.08)
    y0, x0 = int(H * 0.14), (W - ms) // 2
    region = col[y0:y0 + ms, x0:x0 + ms]
    shadow = np.roll(np.roll(m, 4, 0), 3, 1) * 0.5
    region[:] = mix(region, (region * 0.55), shadow[..., None])
    region[:] = mix(region, mix(bone[2], bone[3], 0.3)[None, None, :], m[..., None])
    # madder band and tails
    yb = int(H * 0.8)
    col[yb:yb + int(H * 0.035)] = mix(col[yb:yb + int(H * 0.035)], madder[1][None, None, :], 0.95)
    col[yb + int(H * 0.035):] = mix(col[yb + int(H * 0.035):], madder[1][None, None, :], 0.9)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # alpha: swallow-tail cut, ragged hems
    rag = tvp.periodic_1d(W, rng, kmax=40, kmin=8) * 10
    ragy = tvp.periodic_1d(H, rng, kmax=40, kmin=8) * 5
    notch_top = H * 0.86
    depth = (H - notch_top)
    centre = np.abs(xx - W / 2) / (W / 2)
    cut = yy > (notch_top + depth * centre) + rag[None, :]
    alpha = np.ones((H, W), np.float32)
    alpha[cut] = 0.0
    alpha[(yy > H - 6 + rag[None, :] * 0.4)] = 0.0
    alpha[:, :2] = 0
    alpha[:, -2:] = 0
    side = (xx < 3 + np.abs(ragy[:, None]) * 0.4) | (xx > W - 3 - np.abs(ragy[:, None]) * 0.4)
    alpha[side & (yy > H * 0.8)] = 0
    alpha = tvp.blur(alpha, 0.8)
    # shade the tails a touch
    col[cut] = col[cut]
    cv.col = col
    img = tvp.to_u8(np.concatenate([tvp.l2s(col), alpha[..., None]], -1))
    tvp.save(img, "cloth/%s.png" % name)
    return img


def prayer_flags():
    W, H = 1024, 512
    cw, ch = W // 5, H // 2
    out = np.zeros((H, W, 4), np.float32)
    cols = ["indigo_cloth", "madder_cloth", "ochre_cloth", "bone_cloth", "jade_cloth"]
    rng = np.random.default_rng(9700)
    cells = []
    for row in range(2):
        for i, cname in enumerate(cols):
            fw, fh = int(cw * 0.86), int(ch * 0.92)  # 30 x 45 cm at 2:3
            fw = int(fh * 2 / 3)
            cv = cloth_field(fh, fw, ramp(cname), 9710 + row * 10 + i, folds=5)
            col = cv.col
            col[: int(fh * 0.08)] *= 0.72  # rope sleeve
            if row == 1:  # a printed tally in the field colour's dark: dots and bars (not writing)
                ink = ramp(cname)[0] if cname not in ("indigo_cloth",) else ramp("bone_cloth")[1]
                for k in range(3):
                    y = int(fh * (0.3 + k * 0.17))
                    col[y:y + 6, int(fw * 0.25):int(fw * 0.75)] = mix(col[y:y + 6, int(fw * 0.25):int(fw * 0.75)],
                                                                    ink[None, None, :], 0.8)
                    for dx in (0.3, 0.5, 0.7):
                        cx, cy = int(fw * dx), y + 16
                        col[cy - 3:cy + 3, cx - 3:cx + 3] = mix(col[cy - 3:cy + 3, cx - 3:cx + 3], ink, 0.8)
            yy, xx = np.mgrid[0:fh, 0:fw].astype(np.float32)
            rag = tvp.periodic_1d(fw, rng, kmax=24, kmin=5) * fh * 0.05 + rng.uniform(0, fh * 0.04)
            ragx = tvp.periodic_1d(fh, rng, kmax=20, kmin=5) * 2.5
            a = (yy < fh - 4 - fh * 0.06 - np.abs(rag[None, :])) & (xx > 1 + np.abs(ragx[:, None])) & \
                (xx < fw - 2 - np.abs(ragx[:, None]))
            # a tear or two
            for _ in range(rng.integers(0, 2)):
                tx = rng.uniform(0.2, 0.8) * fw
                a &= ~((np.abs(xx - tx) < 2.5) & (yy > fh * rng.uniform(0.55, 0.8)))
            alpha = tvp.blur(a.astype(np.float32), 0.7)
            x0, y0 = i * cw + (cw - fw) // 2, row * ch + (ch - fh) // 2
            out[y0:y0 + fh, x0:x0 + fw, :3] = tvp.l2s(col)
            out[y0:y0 + fh, x0:x0 + fw, 3] = alpha
            cells.append({"colour": cname, "row": row, "rect_px": [x0, y0, fw, fh],
                          "uv_rect": [x0 / W, y0 / H, fw / W, fh / H]})
    tvp.save(tvp.to_u8(out), "cloth/tv_prayer_flags.png")
    return cells


def carved(mask, stone_ramp, seed, name, tallies=0, pecked=False):
    """A carving decal: stone colour inside the cut, the upper inner wall in shadow, the lower inner wall lit;
    alpha = the cut plus a soft rim. Light from -V (above)."""
    S = mask.shape[0]
    rng = np.random.default_rng(seed)
    m = mask.copy()
    if tallies:
        mm = Image.fromarray((m * 255).astype(np.uint8))
        d = ImageDraw.Draw(mm)
        for k in range(tallies):
            y = S * (0.12 + k * 0.1)
            d.rectangle([S * 0.9, y, S * 0.97, y + S * 0.03], fill=255)
        m = np.asarray(mm, np.float32) / 255.0
    if pecked:
        speck = (rng.random(m.shape) < 0.55).astype(np.float32)
        m = m * tvp.blur(speck, 1.3) * 1.6
        m = np.clip(m, 0, 1)
    m = tvp.blur(m, 1.2)
    up = np.clip(np.roll(m, 5, 0) - m, 0, 1)  # cut edge facing up: the upper inner wall (shadow)
    dn = np.clip(np.roll(m, -5, 0) - m, 0, 1)
    s4 = stone_ramp
    base = mix(s4[1], s4[0], 0.55)
    col = np.broadcast_to(base, (S, S, 3)).copy()
    col = mix(col, np.broadcast_to(mix(s4[0], lin("#30344a"), 0.5), col.shape), np.clip(m * 0.6 + up * 2.0, 0, 1)[..., None])
    col = mix(col, np.broadcast_to(s4[2], col.shape), np.clip(dn * 1.6, 0, 1)[..., None] * 0.7)
    alpha = np.clip(m * 1.2 + up + dn, 0, 1)
    img = tvp.to_u8(np.concatenate([tvp.l2s(col), alpha[..., None]], -1))
    tvp.save(img, "cloth/%s.png" % name)
    return img


def main():
    meta = {}
    sheet = np.zeros((512, 1536, 4), np.float32)
    rng = np.random.default_rng(9600)
    for i in range(3):
        m = brushy(mark_mask(i, 512, pad=0.06), rng, 0.05)
        sheet[:, i * 512:(i + 1) * 512, :3] = 1.0
        sheet[:, i * 512:(i + 1) * 512, 3] = m
    tvp.save(tvp.to_u8(sheet), "cloth/tv_clan_marks.png")
    meta["clan_marks"] = {"cells": ["twin_peaks", "ladder", "set_stone"], "cell_px": 512}
    meta["banners"] = {}
    for name, rname, mi, seed in (("tv_banner_indigo", "indigo_cloth", 0, 9611), ("tv_banner_ochre", "ochre_cloth", 2, 9612),
                                  ("tv_banner_jade", "jade_cloth", 1, 9613)):
        banner(ramp(rname), mi, seed, name)
        meta["banners"][name] = {"field": rname, "mark": meta["clan_marks"]["cells"][mi], "size": [512, 1536],
                                 "metres": [1.0, 3.0]}
    meta["prayer_flags"] = prayer_flags()
    ks = ramp("karst_limestone")
    carved(mark_mask(0, 512, pad=0.14), ks, 9620, "tv_waystone_mark", tallies=7)
    carved(mark_mask(10, 512, pad=0.1), ks, 9621, "tv_maker_sign_a")
    carved(mark_mask(11, 512, pad=0.1), ks, 9622, "tv_maker_sign_b", pecked=True)
    meta["decals"] = {"tv_waystone_mark": "mark twin_peaks + 7 tally notches", "tv_maker_sign_a": "square and cut",
                      "tv_maker_sign_b": "stepped stones and ring (pecked)"}
    with open(os.path.join(tvp.OUT, "cloth", "cloth.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("cloth and marks written")


if __name__ == "__main__":
    main()
