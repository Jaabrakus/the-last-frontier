#!/usr/bin/env python3
"""The vista beside its targets, for the owner (review_local/vista/, git-ignored), and the spec's acceptance numbers.

    python3 tools/thuyvan_look/vista_board.py [--vista review_local/vista] [--sheet "<owner's Trường Sơn sheet>"]

Writes <vista>/V1_beside_targets.png: the engine's V1 at noon over the Trường Sơn sheet's hero (the target for shape,
colour and mood; review only, never game art: plan 3.3 item 27) and the Blender dioramas the kits were judged on
(review_local/look/VILLAGE/diorama_hero_noon.png, ROCK/diorama.png). Prints, per shot V<n>_<direction>.png, the
vista spec 5.3 numbers it can measure: the darkest 1 % of pixels (rule 4: above 0.06) and the median saturation of
the frame's coloured surfaces (rule 3: no surface under 0.12; white falls, mist, cloud and the white stones excepted,
so pixels brighter than 0.8 in value are left out).
"""
import argparse
import glob
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SHEET = "/Users/kiwimango/Downloads/New Folder With Items/image-gen-4(1).png"
FONT = os.path.join(ROOT, "assets", "fonts", "be_vietnam_pro", "BeVietnamPro-Medium.ttf")


def font(size):
    for p in [FONT] + glob.glob(os.path.join(ROOT, "assets", "**", "BeVietnamPro-*.ttf"), recursive=True):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def fit(img, w):
    return img.resize((w, int(img.height * w / img.width)), Image.LANCZOS)


def caption(img, text):
    d = ImageDraw.Draw(img)
    f = font(26)
    box = d.textbbox((0, 0), text, font=f)
    d.rectangle((12, 10, 30 + box[2], 24 + box[3]), fill=(24, 24, 28))
    d.text((21, 14), text, font=f, fill=(244, 242, 236))
    return img


def metrics(path):
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0
    a = a[80:]                                  # (under the caption)
    mx = a.max(-1)
    mn = a.min(-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    dark = float(np.percentile(mx, 1))
    surf = sat[mx < 0.8]
    return dark, float(np.median(surf)) if surf.size else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vista", default=os.path.join(ROOT, "review_local", "vista"))
    ap.add_argument("--sheet", default=SHEET)
    args = ap.parse_args()
    for p in sorted(q for q in glob.glob(os.path.join(args.vista, "V[123]_*.png")) if "beside" not in q):
        dark, sat = metrics(p)
        print("%-34s darkest 1%% %.3f (> 0.06 %s)  median surface saturation %.3f (>= 0.12 %s)" % (
            os.path.basename(p), dark, "ok" if dark > 0.06 else "LOW", sat, "ok" if sat >= 0.12 else "LOW"))
    v1 = os.path.join(args.vista, "V1_bright_saturated_noon.png")
    if not os.path.exists(v1):
        return
    W = 1920
    tiles = [caption(fit(Image.open(v1).convert("RGB"), W), "In the game (Godot): V1, the Reach, at noon")]
    if os.path.exists(args.sheet):
        s = Image.open(args.sheet).convert("RGB")
        hero = s.crop((0, int(s.height * 0.095), s.width, int(s.height * 0.505)))
        tiles.append(caption(fit(hero, W), "The target: the Trường Sơn sheet's hero (shape, colour and mood only)"))
    for rel, text in [("VILLAGE/diorama_hero_noon.png", "Blender: VILLAGE's diorama (kit pieces, stand-in ground)"),
                      ("ROCK/diorama.png", "Blender: ROCK's diorama (stand-in trees and mist)")]:
        p = os.path.join(ROOT, "review_local", "look", rel)
        if os.path.exists(p):
            tiles.append(caption(fit(Image.open(p).convert("RGB"), W), text))
    h = sum(t.height for t in tiles)
    board = Image.new("RGB", (W, h), (24, 24, 28))
    y = 0
    for t in tiles:
        board.paste(t, (0, y))
        y += t.height
    out = os.path.join(args.vista, "V1_beside_targets.png")
    board.save(out)
    print("->", out)


if __name__ == "__main__":
    main()
