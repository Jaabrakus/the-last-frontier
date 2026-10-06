#!/usr/bin/env python3
"""Apply each direction's Thủy Vân grade LUT (paint_grade.py) to the diorama renders, the way Godot applies
Environment.adjustment_color_correction after the tonemapper: display colour in, graded display colour out,
trilinear in the 64^3 LUT. Also writes the triptych the owner compares.

    python3 tools/thuyvan_art/paint/grade_renders.py

Reads look/PAINT/diorama/diorama_<direction>.png; writes diorama_<direction>_graded.png and
look/PAINT/board_diorama_triptych.png.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvp  # noqa: E402
from compose_boards import font, title, BG, FG  # noqa: E402

N = 64
DIRS = ["jade_mist_morning", "bright_saturated_noon", "golden_lantern_dusk"]


def load_lut(name):
    sheet = np.asarray(Image.open(os.path.join(tvp.OUT, "grade", "tv_grade_%s_64.png" % name)).convert("RGB"),
                       np.float32) / 255.0
    lut = np.zeros((N, N, N, 3), np.float32)  # [b, g, r]
    for b in range(N):
        x0, y0 = (b % 8) * N, (b // 8) * N
        lut[b] = sheet[y0:y0 + N, x0:x0 + N]
    return lut


def apply(img, lut):
    c = np.clip(img, 0, 1) * N - 0.5  # texel i sits at (i + 0.5) / N
    c = np.clip(c, 0, N - 1)
    i0 = np.floor(c).astype(np.int32)
    i1 = np.minimum(i0 + 1, N - 1)
    f = c - i0
    r0, g0, b0 = i0[..., 0], i0[..., 1], i0[..., 2]
    r1, g1, b1 = i1[..., 0], i1[..., 1], i1[..., 2]
    fr, fg, fb = f[..., 0:1], f[..., 1:2], f[..., 2:3]

    def L(b, g, r):
        return lut[b, g, r]

    c00 = L(b0, g0, r0) * (1 - fr) + L(b0, g0, r1) * fr
    c01 = L(b0, g1, r0) * (1 - fr) + L(b0, g1, r1) * fr
    c10 = L(b1, g0, r0) * (1 - fr) + L(b1, g0, r1) * fr
    c11 = L(b1, g1, r0) * (1 - fr) + L(b1, g1, r1) * fr
    c0 = c00 * (1 - fg) + c01 * fg
    c1 = c10 * (1 - fg) + c11 * fg
    return c0 * (1 - fb) + c1 * fb


def main():
    d = os.path.join(tvp.LOOK, "diorama")
    outs = []
    for name in DIRS:
        p = os.path.join(d, "diorama_%s.png" % name)
        if not os.path.exists(p):
            continue
        img = np.asarray(Image.open(p).convert("RGB"), np.float32) / 255.0
        g = apply(img, load_lut(name))
        out = Image.fromarray(np.clip(np.round(g * 255), 0, 255).astype(np.uint8))
        out.save(os.path.join(d, "diorama_%s_graded.png" % name))
        outs.append((tvp.direction(name)["title"], out))
        print("graded", name)
    if outs:
        W = 1920
        hs = [int(o.height * W / o.width) for _, o in outs]
        board = Image.new("RGB", (W, 90 + sum(h + 44 for h in hs)), BG)
        title(board, "Thủy Vân R1 look test: every painted surface together, three directions",
              "Eevee, the painted sky as the world, painted terrain array, rock, river, falls, mist, trees and grass "
              "cards; graded through each direction's LUT. A stand-in landform, not the T4 layout.")
        dr = ImageDraw.Draw(board)
        y = 90
        for (t, o), h in zip(outs, hs):
            dr.text((16, y + 8), t, fill=FG, font=font(22))
            board.paste(o.resize((W, h), Image.LANCZOS), (0, y + 40))
            y += h + 44
        board.save(os.path.join(tvp.LOOK, "board_diorama_triptych.png"))


if __name__ == "__main__":
    main()
