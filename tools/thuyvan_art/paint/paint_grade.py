#!/usr/bin/env python3
"""P12: the Thủy Vân grade LUTs, one per direction (style guide 5.4 "Tonemap and grade"; palettes.json
directions.*.grade). The frontier's grade (scripts/world/env/grade_lut.gd) pulls greens toward olive; this one never
does: greens keep their hue and at least their saturation.

    python3 tools/thuyvan_art/paint/paint_grade.py

Writes assets/thuyvan/paint/grade/tv_grade_<direction>_64.png: a 64^3 LUT in the frontier's baked layout (an 8 x 8
grid of 64 x 64 slices, slice = blue at ((b % 8) * 64, (b // 8) * 64), x = red, y = green; texel i stores the grade
of (i + 0.5) / 64, the two end texels the grade of 0.25 / 64 and 1 - 0.25 / 64: GradeLut's texel convention), to
import as a Texture3D (slices/horizontal=8, slices/vertical=8) for Environment.adjustment_color_correction. The grade
works in display space after AgX (contrast here is a mild s-curve on top of the tonemapper's own AgX contrast),
plus a preview strip (look/PAINT/grade/) of the R1 palette before and after.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvp  # noqa: E402

N = 64


def texel_coords(n):
    t = (np.arange(n, dtype=np.float64) + 0.5) / n
    t[0] = 0.25 / n
    t[-1] = 1.0 - 0.25 / n
    return t


def grade(c, g):
    """c: (..., 3) display sRGB 0..1 -> graded."""
    luma = lambda x: 0.2126 * x[..., 0] + 0.7152 * x[..., 1] + 0.0722 * x[..., 2]
    # mild s-curve about 0.5 (contrast 1.05-1.15 -> 0.1-0.3 of a smoothstep)
    k = np.clip((g["contrast"] - 1.0) * 2.0, 0, 0.5)
    s = c * c * (3 - 2 * c)
    c = c + (s - c) * k
    # saturation about luma; greens (and teals) are never desaturated
    l = luma(c)[..., None]
    hsv = tvp.rgb_to_hsv(np.clip(c, 0, 1))
    h = hsv[..., 0] * 360.0
    green = (np.clip(1 - np.abs(h - 110.0) / 70.0, 0, 1) * (hsv[..., 1] > 0.08))[..., None]
    sat = np.maximum(g["saturation"], green * 1.0 + (1 - green) * g["saturation"])  # greens: never below 1
    c = l + (c - l) * sat
    # split tone: shadows toward the shadow tint, highlights toward the highlight tint (chroma only, not value)
    st, ht = tvp.hex_srgb(g["shadow_tint"]), tvp.hex_srgb(g["highlight_tint"])
    stc, htc = st - st.mean(), ht - ht.mean()
    l = luma(c)[..., None]
    c = c + stc * (1 - l) ** 2 * 0.35 + htc * l ** 2 * 0.22
    # keep the hue of greens exactly: re-apply the input hue to the graded value / saturation where green
    hsv2 = tvp.rgb_to_hsv(np.clip(c, 0, 1))
    hsv2[..., 0] = np.where(green[..., 0] > 0.5, hsv[..., 0], hsv2[..., 0])
    c = np.where(green > 0.5, tvp.hsv_to_rgb(hsv2), c)
    return np.clip(c, 0, 1)


def bake(g):
    t = texel_coords(N)
    b, gg, r = np.meshgrid(t, t, t, indexing="ij")  # [b, g, r]
    c = np.stack([r, gg, b], -1)
    out = grade(c, g)
    sheet = np.zeros((8 * N, 8 * N, 4), np.uint8)
    for bi in range(N):
        x0, y0 = (bi % 8) * N, (bi // 8) * N
        sheet[y0:y0 + N, x0:x0 + N, :3] = np.clip(np.round(out[bi] * 255), 0, 255).astype(np.uint8)
        sheet[y0:y0 + N, x0:x0 + N, 3] = 255
    return sheet


def main():
    out = os.path.join(tvp.OUT, "grade")
    os.makedirs(out, exist_ok=True)
    r1 = tvp.PAL["albedo"]["r1"]
    sw = np.array([tvp.hex_srgb(h) for k, v in r1.items() if k != "_about" for h in v], np.float64)
    meta = {}
    rows = []
    for name, d in tvp.PAL["directions"].items():
        g = d["grade"]
        sheet = bake(g)
        Image.fromarray(sheet).save(os.path.join(out, "tv_grade_%s_64.png" % name))
        meta[name] = {"file": "grade/tv_grade_%s_64.png" % name, "agx_contrast": g["contrast"],
                      "saturation": g["saturation"], "shadow_tint": g["shadow_tint"],
                      "highlight_tint": g["highlight_tint"]}
        rows.append(np.concatenate([sw[None], grade(sw, g)[None]], 0))
        print("lut", name, flush=True)
    json.dump(meta, open(os.path.join(out, "grade.json"), "w"), indent=1)
    # preview: the R1 palette, raw and through each LUT
    cell = 20
    img = np.zeros((len(rows) * 2 * cell + len(rows) * 6, sw.shape[0] * cell, 3), np.float64)
    y = 0
    for r in rows:
        for k in range(2):
            img[y:y + cell] = np.repeat(np.repeat(r[k][None], cell, 0), cell, 1)
            y += cell
        y += 6
    Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8)).save(tvp.look_path("grade/grade_preview.png"))


if __name__ == "__main__":
    main()
