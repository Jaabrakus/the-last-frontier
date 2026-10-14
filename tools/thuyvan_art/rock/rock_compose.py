"""Thủy Vân ROCK kit: caption the Blender renders (plain python3 + PIL).

    python3 tools/thuyvan_art/rock/rock_compose.py --look <plan>/look/ROCK

For every <look>/raw/<scene>.json: the render with a title bar, each piece's label (name, height, triangles per LOD,
material keys) under it, and the silhouette inset (a 3/4 view as a flat black shape, plus the same shape 64 px tall:
the style guide's silhouette test). Writes <look>/<scene>.png and <look>/ROCK_contact.png (all of them small).
"""

import argparse
import glob
import json
import os

from PIL import Image, ImageDraw, ImageFont

FONTS = ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc",
         "/Library/Fonts/Arial.ttf", "/System/Library/Fonts/SFNS.ttf"]


def font(size):
    for f in FONTS:
        if os.path.exists(f):
            try:
                return ImageFont.truetype(f, size)
            except Exception:
                continue
    return ImageFont.load_default()


def sil_inset(path):
    im = Image.open(path).convert("L")
    bb = Image.eval(im, lambda v: 255 - v).getbbox()
    if bb:
        im = im.crop((max(bb[0] - 8, 0), max(bb[1] - 8, 0), min(bb[2] + 8, im.width), min(bb[3] + 8, im.height)))
    big = im.resize((max(1, int(im.width * 260 / im.height)), 260), Image.LANCZOS)
    small = im.resize((max(1, int(im.width * 64 / im.height)), 64), Image.LANCZOS)
    W = big.width + small.width + 36
    out = Image.new("RGB", (W, 300), (244, 240, 230))
    out.paste(big.convert("RGB"), (10, 30))
    out.paste(small.convert("RGB"), (big.width + 26, 30 + 260 - 64))
    d = ImageDraw.Draw(out)
    d.text((10, 6), "silhouette 3/4  ·  64 px test", font=font(16), fill=(40, 40, 40))
    return out


def compose(look, name):
    meta = json.load(open(os.path.join(look, "raw", name + ".json")))
    im = Image.open(os.path.join(look, "raw", name + ".png")).convert("RGB")
    s = im.width / 1920.0
    d = ImageDraw.Draw(im, "RGBA")
    f1, f2 = font(int(17 * s) + 1), font(int(14 * s) + 1)
    for lab in meta.get("labels", []):
        x, y = lab["x"] * s / (1920.0 / im.width * s) if False else lab["x"] * im.width / 1920.0, lab["y"] * im.height / 1080.0
        lines = lab["lines"]
        ws = [d.textlength(t, font=f1 if i == 0 else f2) for i, t in enumerate(lines)]
        w = max(ws) + 14
        h = 8 + int(20 * s) + int(17 * s) * (len(lines) - 1)
        x0 = max(4, min(im.width - w - 4, x - w / 2))
        y0 = max(60 * s, min(im.height - h - 4, y + 8 * s))
        d.rounded_rectangle((x0, y0, x0 + w, y0 + h), 6, fill=(246, 242, 232, 215))
        yy = y0 + 4
        for i, t in enumerate(lines):
            d.text((x0 + 7, yy), t, font=f1 if i == 0 else f2, fill=(30, 30, 30) if i == 0 else (70, 66, 60))
            yy += int(20 * s) if i == 0 else int(17 * s)
    d.rectangle((0, 0, im.width, int(44 * s)), fill=(246, 242, 232, 225))
    d.text((int(14 * s), int(10 * s)), meta["title"], font=font(int(22 * s) + 1), fill=(25, 25, 25))
    if meta.get("sil") and os.path.exists(os.path.join(look, "raw", meta["sil"])):
        ins = sil_inset(os.path.join(look, "raw", meta["sil"]))
        sc = s
        ins = ins.resize((int(ins.width * sc), int(ins.height * sc)))
        im.paste(ins, (im.width - ins.width - int(12 * s), int(54 * s)))
        d = ImageDraw.Draw(im)
        d.text((im.width - ins.width - int(12 * s), int(54 * s) + ins.height + 2), meta.get("sil_name", ""),
               font=f2, fill=(30, 30, 30))
    out = os.path.join(look, name + ".png")
    im.save(out)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--look", required=True)
    a = ap.parse_args()
    outs = []
    for j in sorted(glob.glob(os.path.join(a.look, "raw", "*.json"))):
        n = os.path.basename(j)[:-5]
        if os.path.exists(os.path.join(a.look, "raw", n + ".png")):
            outs.append(compose(a.look, n))
            print("ROCK_COMPOSE", outs[-1])
    if outs:
        th = [Image.open(o).convert("RGB").resize((640, 360), Image.LANCZOS) for o in outs]
        cols = 3
        rows = (len(th) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * 650 + 10, rows * 370 + 10), (236, 230, 216))
        for i, t in enumerate(th):
            sheet.paste(t, (10 + (i % cols) * 650, 10 + (i // cols) * 370))
        sheet.save(os.path.join(a.look, "ROCK_contact.png"))


if __name__ == "__main__":
    main()
