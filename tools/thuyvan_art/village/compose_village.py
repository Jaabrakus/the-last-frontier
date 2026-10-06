"""Compose the village kit's review sheets from render_village.py's raw renders (plain Python + PIL):

    python3 tools/thuyvan_art/village/compose_village.py --dir LOOK/VILLAGE [--textures assets/thuyvan/village/textures]

For every lineup page (raw/<page>.png + .json): a title band, and under each piece its name, triangle count, material
keys and its 64 px black silhouette (the style guide's silhouette test). Also: textures.png (every painted texture with
its 3 x 3 tiling and 1/16 squint), and the diorama renders copied with a caption band. Writes into --dir.
"""

import argparse
import glob
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"   # labels only (Vietnamese diacritics); not shipped
INK = (38, 34, 30)
PAPER = (236, 230, 216)


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except OSError:
        return ImageFont.load_default()


TITLES = {
    "houses": "V01-V02  Mountain Folk stilt houses (thatch; wood shingle) and the cliff house (hung on the gorge lip)",
    "halls": "V03-V04  Clan house, the rope bridge's head gate, the Two Heights gate tower",
    "waystone": "V06, V07, V09  The clan waystone (our own carved marks), banners in indigo, ochre and jade, bridge lamp, lantern post",
    "terrace": "V10, V11, V14  Terrace walls (straight, curving in, curving out), paddy bund, sampan, survey camp",
    "clutter": "V09, V12, V13  Paper lanterns, bamboo and wattle fences, drying rack, baskets, firewood, water jars",
    "people": "V15, V08  Porters (the 1.75 m scale figure), prayer-flag ropes (4 m, 8 m)",
    "roofs": "Open choice: the roof curve.  A restrained   |   B the kit's default   |   C bold",
    "bridge": "V05  The R1 rope bridge: 63 m + 73 m spans on the needle platform, anchors, banners, rag flags",
}


def silhouette(path, h=64):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)[..., 3]
    ys, xs = np.nonzero(a > 8)
    if len(xs) == 0:
        return None
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    w = max(1, round(im.width * h / im.height))
    if w > 3 * h:
        w = 3 * h
        h2 = max(1, round(im.height * w / im.width))
        im = im.resize((w, h2), Image.LANCZOS)
    else:
        im = im.resize((w, h), Image.LANCZOS)
    a = np.asarray(im)[..., 3]
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    o = np.zeros((im.height, im.width, 4), np.uint8)
    o[..., 3] = (a > 100) * 255
    return Image.fromarray(o)


def page(d, name, out):
    raw = os.path.join(d, "raw")
    meta = json.load(open(os.path.join(raw, name + ".json")))
    im = Image.open(os.path.join(raw, name + ".png")).convert("RGB")
    W, H = im.size
    band = 260
    sheet = Image.new("RGB", (W, H + band + 70), PAPER)
    sheet.paste(im, (0, 70))
    dr = ImageDraw.Draw(sheet)
    dr.text((24, 18), "THỦY VÂN village kit  ·  " + TITLES.get(name, name), fill=INK, font=font(28))
    pieces = sorted(meta["pieces"].items(), key=lambda kv: kv[1]["screen"][0])
    n = len(pieces)
    colw = W / max(n, 1)
    for i, (nm, info) in enumerate(pieces):
        x0 = int(i * colw) + 10
        y0 = H + 70 + 10
        sp = os.path.join(raw, name + "_sil", nm + ".png")
        if os.path.exists(sp):
            s = silhouette(sp)
            if s is not None:
                sheet.paste(s, (x0, y0), s)
        # a tick from the label to the piece in the picture
        sx = int(info["screen"][0] * W)
        dr.line([(sx, H + 70 - 6), (sx, H + 70 + 4)], fill=INK, width=3)
        y = y0 + 74
        dr.text((x0, y), nm, fill=INK, font=font(17 if n > 8 else 20))
        dr.text((x0, y + 26), "%d tris" % info["tris"], fill=(120, 40, 30), font=font(17))
        mats = ", ".join(info["materials"])
        words, line, yy = mats.split(", "), "", y + 50
        for w_ in words:
            t = (line + ", " + w_) if line else w_
            if dr.textlength(t, font=font(14)) > colw - 18:
                dr.text((x0, yy), line, fill=(90, 84, 76), font=font(14))
                yy += 18
                line = w_
            else:
                line = t
        dr.text((x0, yy), line, fill=(90, 84, 76), font=font(14))
    sheet.save(os.path.join(out, "lineup_%s.png" % name), optimize=True)
    return sheet


def textures(tex_dir, out):
    fs = sorted(glob.glob(os.path.join(tex_dir, "*.png")))
    cell = 300
    cols = 6
    rows = (len(fs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cell * 2 + 30), rows * (cell + 46) + 60), PAPER)
    dr = ImageDraw.Draw(sheet)
    dr.text((20, 14), "THỦY VÂN village kit  ·  painted textures (left: one tile; right: 3 x 3 tiling over the 1/16 squint)",
            fill=INK, font=font(26))
    for i, f in enumerate(fs):
        im = Image.open(f).convert("RGB")
        x, y = (i % cols) * (cell * 2 + 30) + 14, (i // cols) * (cell + 46) + 60
        t = im.copy()
        t.thumbnail((cell, cell))
        sheet.paste(t, (x, y))
        tw, th = t.size
        sm = im.resize((max(1, tw // 3), max(1, th // 3)), Image.LANCZOS)
        tiled = Image.new("RGB", (sm.width * 3, sm.height * 3))
        for a in range(3):
            for b in range(3):
                tiled.paste(sm, (a * sm.width, b * sm.height))
        sq = im.resize((max(1, im.width // 16), max(1, im.height // 16)), Image.BOX).resize((tw // 3, th // 3),
                                                                                          Image.BICUBIC)
        sheet.paste(tiled, (x + cell + 8, y))
        sheet.paste(sq, (x + cell + 8, y + tiled.height + 4)) if tiled.height + sq.height + 4 <= cell else None
        lum = np.asarray(im, np.float32) / 255.0
        mean = float((lum[..., 0] * 0.2126 + lum[..., 1] * 0.7152 + lum[..., 2] * 0.0722).mean())
        dr.text((x, y + cell + 6), "%s  %dx%d  mean %.2f" % (os.path.basename(f)[:-4], im.width, im.height, mean),
                fill=INK, font=font(16))
    sheet.save(os.path.join(out, "textures.png"), optimize=True)


def diorama(d, out):
    raw = os.path.join(d, "raw")
    caps = {"noon": "Bright Saturated Noon", "morning": "Jade Mist Morning", "dusk": "Golden Lantern Dusk"}
    for f in sorted(glob.glob(os.path.join(raw, "diorama_*.png"))):
        nm = os.path.basename(f)[:-4]
        im = Image.open(f).convert("RGB")
        W, H = im.size
        sheet = Image.new("RGB", (W, H + 56), PAPER)
        sheet.paste(im, (0, 56))
        dr = ImageDraw.Draw(sheet)
        dname = nm.split("_")[-1]
        dr.text((22, 12), "THỦY VÂN village kit  ·  diorama (%s view)  ·  %s  ·  kit pieces are the assets; ground, water, "
                "trees, mist, far karst and sky are render-only stand-ins for the PAINT and ROCK sets" %
                (nm.split("_")[1], caps.get(dname, dname)), fill=INK, font=font(22))
        sheet.save(os.path.join(out, nm + ".png"), optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--textures", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..",
                                                       "assets", "thuyvan", "village", "textures"))
    a = ap.parse_args()
    raw = os.path.join(a.dir, "raw")
    for j in sorted(glob.glob(os.path.join(raw, "*.json"))):
        nm = os.path.basename(j)[:-5]
        if nm in ("diorama",):
            continue
        if os.path.exists(os.path.join(raw, nm + ".png")):
            page(a.dir, nm, a.dir)
            print("sheet", nm)
    textures(a.textures, a.dir)
    diorama(a.dir, a.dir)


if __name__ == "__main__":
    main()
