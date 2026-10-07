"""Compose the Reed Marches kit's review sheets from render_dong_lau.py's raw renders (Python + PIL):

    python3 tools/thuyvan_art/dong_lau/compose_dong_lau.py --dir REVIEW [--manifest assets/thuyvan/dong_lau/manifest.json]

Per lineup page: a title band, the render, and under each piece its label, triangle counts (LOD0 / LOD1 against the
places_se.md budget), material keys and its 64 px black silhouette (the style guide's silhouette test). The diorama
renders get each direction's grade (palettes.json-style contrast and saturation from directions.json) and a caption,
and a 3 x 3 contact sheet (cameras across, directions down). textures.png shows every painted texture with its 3 x 3
tiling and 1/16 squint. Captions use Be Vietnam Pro, the project's one OFL family.
"""

import argparse
import glob
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FONT_DIR = os.path.join(REPO, "assets", "fonts", "bevietnampro")
INK = (38, 34, 30)
RED = (130, 40, 30)
GREY = (96, 90, 82)
PAPER = (236, 230, 216)
DIRS = {k: v for k, v in json.load(open(os.path.join(HERE, "directions.json"))).items() if not k.startswith("_")}
KIT = "THỦY VÂN · Reed Marches stilt kit (Đồng Lau, dl_*)"


def font(sz, bold=False):
    f = os.path.join(FONT_DIR, "BeVietnamPro-%s.ttf" % ("SemiBold" if bold else "Regular"))
    try:
        return ImageFont.truetype(f, sz)
    except OSError:
        return ImageFont.load_default()


TITLES = {
    "landmarks": ("Landmarks: the mooring fort (DL1), a reed watch tower (DL2), the heron banner, a mangrove with its "
                  "root arches (DL4)", "Fort 30 x 30 m on ~225 piles, finial 31 m; tower lookout 16.5 m, cap 21 m; "
                  "banner mast 24 m with a 3.3 x 10 m cloth; mangrove 15 m, root arches 6-7 m over a side channel."),
    "houses": ("Houses: Floodborn-built (a), the public standard (b), the kitchen hut (c), the raft house",
               "a: door 2.8 x 1.8 m, no sill, bench in runs with a 0.5 m tail gap, soaking trough, haul-out ramp.  "
               "b: door 2.4 x 1.3 m, 8 cm sill, steps.  c: hearth at the edge, a mangrove root through the floor."),
    "moorings": ("Water works: pile forests (4 m, 6 m), platforms with a haul-out ramp or steps, the hidden causeway, "
                 "the tally post", "Piles 0.36-0.5 m (~2x real) from the bed at -1.8 m; causeway walk surface 15 cm "
                 "under the water; the tally post's marks are notches in fours and a ring, never writing."),
    "racks": ("Moorings and means: screens, fish and nets drying, the soaking trough, the burial reed boat on its frame, "
              "the lift net", "Burial boat 9 m of bound reed bundles, ends upswept 3 m; lift net 4 x 4 m on a 9 m lever. "
              "fish_rack, net_rack and dip_net are PROPOSAL ids (not in the kit list)."),
    "boats": ("Boats and reeds: the dugout, the flat ferry, reed clumps (gold, green, gold with cattails)",
              "Dugout 6.6 m; ferry 9 x 3 m with a 2.0 m clear canopy; reeds 3-4 m (~1.5x) as crossed painted cards."),
    "fort_abc": ("Open choice: the fort's roofs.   A restrained   |   B the kit's default   |   C bold",
                 "Same fort, same piles: only the eave upturn, flare, overhang and tier heights change."),
    "tower_abc": ("Open choices: the watch tower's cap (A plain, B upturned, C two-tier with a pennant) and the moorings' "
                  "heron mark (A standing, B in the ring, C between reeds)",
                  "Our own heron in cut lines and one ring, bone on indigo with madder tails; not the sheet's painted "
                  "heron, no people's crest, no writing."),
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
        im = im.resize((w, max(1, round(im.height * w / im.width))), Image.LANCZOS)
    else:
        im = im.resize((w, h), Image.LANCZOS)
    a = np.asarray(im)[..., 3]
    o = np.zeros((im.height, im.width, 4), np.uint8)
    o[..., 3] = (a > 100) * 255
    return Image.fromarray(o)


def page(raw, name, out, manifest):
    meta = json.load(open(os.path.join(raw, name + ".json")))
    im = Image.open(os.path.join(raw, name + ".png")).convert("RGB")
    W, H = im.size
    top, band = 104, 250
    sheet = Image.new("RGB", (W, H + top + band), PAPER)
    sheet.paste(im, (0, top))
    dr = ImageDraw.Draw(sheet)
    t1, t2 = TITLES.get(name, (name, ""))
    dr.text((24, 12), KIT, fill=GREY, font=font(20))
    dr.text((24, 40), t1, fill=INK, font=font(25, True))
    dr.text((24, 74), t2, fill=GREY, font=font(18))
    pieces = sorted(meta["pieces"].items(), key=lambda kv: kv[1]["screen"][0])
    n = len(pieces)
    colw = W / max(n, 1)
    for i, (nm, info) in enumerate(pieces):
        x0 = int(i * colw) + 12
        y0 = H + top + 10
        sp = os.path.join(raw, name + "_sil", nm + ".png")
        if os.path.exists(sp):
            s = silhouette(sp)
            if s is not None:
                sheet.paste(s, (x0, y0), s)
        sx = int(info["screen"][0] * W)
        dr.line([(sx, H + top - 8), (sx, H + top + 4)], fill=INK, width=3)
        y = y0 + 72
        lab = info.get("label", nm)
        dr.text((x0, y), lab, fill=INK, font=font(19 if n > 5 else 21, True))
        if lab != nm:
            dr.text((x0, y + 26), nm, fill=GREY, font=font(15))
            y += 22
        m = manifest["pieces"].get(nm, {})
        tris = "%d tris" % info["tris"]
        if m.get("tris_lod1"):
            tris += " / LOD1 %d" % m["tris_lod1"]
        if m.get("budget"):
            tris += "   (budget %s)" % m["budget"]
        if nm.startswith("review_"):
            tris += "   (review variant)"
        dr.text((x0, y + 28), tris, fill=RED, font=font(16))
        mats = ", ".join(info["materials"])
        words, line, yy = mats.split(", "), "", y + 52
        for w_ in words:
            t = (line + ", " + w_) if line else w_
            if dr.textlength(t, font=font(14)) > colw - 22:
                dr.text((x0, yy), line, fill=GREY, font=font(14))
                yy += 18
                line = w_
            else:
                line = t
        dr.text((x0, yy), line, fill=GREY, font=font(14))
    sheet.save(os.path.join(out, "lineup_%s.png" % name), optimize=True)


def textures(tex_dir, out):
    fs = sorted(glob.glob(os.path.join(tex_dir, "*.png")))
    cell = 260
    cols = 5
    rows = (len(fs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cell * 2 + 34), rows * (cell + 50) + 84), PAPER)
    dr = ImageDraw.Draw(sheet)
    dr.text((20, 12), KIT, fill=GREY, font=font(20))
    dr.text((20, 40), "Painted textures (our own, numpy + PIL, the style guide's brush recipe). Left: one tile.  Right: "
            "3 x 3 tiling over the 1/16 squint.", fill=INK, font=font(24, True))
    for i, f in enumerate(fs):
        im = Image.open(f)
        if im.mode == "RGBA":
            bg = Image.new("RGBA", im.size, (110, 140, 138, 255))
            bg.alpha_composite(im)
            im = bg
        im = im.convert("RGB")
        x, y = (i % cols) * (cell * 2 + 34) + 14, (i // cols) * (cell + 50) + 84
        t = im.copy()
        t.thumbnail((cell, cell))
        sheet.paste(t, (x, y))
        tw, th = t.size
        sm = im.resize((max(1, tw // 3), max(1, th // 3)), Image.LANCZOS)
        tiled = Image.new("RGB", (sm.width * 3, sm.height * 3))
        for a in range(3):
            for b in range(3):
                tiled.paste(sm, (a * sm.width, b * sm.height))
        sheet.paste(tiled, (x + cell + 8, y))
        sq = im.resize((max(1, im.width // 16), max(1, im.height // 16)), Image.BOX).resize(
            (max(1, tw // 3), max(1, th // 3)), Image.BICUBIC)
        if tiled.height + sq.height + 4 <= cell:
            sheet.paste(sq, (x + cell + 8, y + tiled.height + 4))
        lum = np.asarray(im, np.float32) / 255.0
        mean = float((lum[..., 0] * 0.2126 + lum[..., 1] * 0.7152 + lum[..., 2] * 0.0722).mean())
        dr.text((x, y + cell + 6), "%s  %dx%d  mean %.2f" % (os.path.basename(f)[:-4], im.width, im.height, mean),
                fill=INK, font=font(16))
    sheet.save(os.path.join(out, "textures.png"), optimize=True)


CAMS = {"arrival": "arriving up the channel by barge (the mangrove's root arches on the left, the fort ahead)",
        "tower": "from a reed watch tower (the floating settlement, the reed bands and channels)",
        "yard": "at Har-Kel's yard (the burial reed boat on its frame, fish and nets drying, the fort beyond)"}
NOTE = ("Kit pieces are the assets. Water, the reed sea (built from the kit's reed cards), mud banks, herons, smoke, "
        "mist, far hills and figures are render-only stand-ins. People shown are humans only, until the Floodborn NPC "
        "body's grey box is approved. The drowned stone lintel by the yard is Book II look-dev (Khar-Ul), not a Book I "
        "piece.")


def grade(im, dname):
    g = DIRS[dname]["grade"]
    im = ImageEnhance.Contrast(im).enhance(g["contrast"])
    return ImageEnhance.Color(im).enhance(g["saturation"])


def diorama(raw, out):
    shots = {}
    for f in sorted(glob.glob(os.path.join(raw, "diorama_*.png"))):
        nm = os.path.basename(f)[:-4]
        cam = nm.split("_")[1]
        dname = nm[len("diorama_%s_" % cam):]
        if dname not in DIRS:
            continue
        im = grade(Image.open(f).convert("RGB"), dname)
        shots[(cam, dname)] = im
        W, H = im.size
        sheet = Image.new("RGB", (W, H + 112), PAPER)
        sheet.paste(im, (0, 112))
        dr = ImageDraw.Draw(sheet)
        d = DIRS[dname]
        dr.text((22, 10), KIT + "  ·  diorama", fill=GREY, font=font(18))
        dr.text((22, 34), "%s  ·  %s" % (d["title"], CAMS.get(cam, cam)), fill=INK, font=font(25, True))
        dr.text((22, 70), "Light: %s.  %s" % (d["status"], NOTE[:150] + "…" if W < 1600 else NOTE), fill=GREY,
                font=font(14))
        sheet.save(os.path.join(out, nm + ".png"), optimize=True)
    if not shots:
        return
    cams = [c for c in ("arrival", "tower", "yard") if any(k[0] == c for k in shots)]
    dirs = [d for d in ("silver_overcast", "heron_morning", "smoke_and_lantern") if any(k[1] == d for k in shots)]
    tw, th = 960, 540
    left, top = 230, 150
    sheet = Image.new("RGB", (left + tw * len(cams) + 12 * len(cams), top + (th + 12) * len(dirs) + 90), PAPER)
    dr = ImageDraw.Draw(sheet)
    dr.text((24, 14), KIT, fill=GREY, font=font(22))
    dr.text((24, 46), "The diorama: a Floodborn stilt fort and its floating settlement in the reed sea, three cameras "
            "in three lights", fill=INK, font=font(32, True))
    for j, c in enumerate(cams):
        dr.text((left + j * (tw + 12) + 6, top - 40), c.upper() + ": " + CAMS[c].split(" (")[0], fill=INK,
                font=font(20, True))
    for i, dn in enumerate(dirs):
        y = top + i * (th + 12)
        dr.text((20, y + 10), DIRS[dn]["title"], fill=INK, font=font(24, True))
        dr.text((20, y + 46), DIRS[dn]["status"].replace(" (", "\n("), fill=GREY, font=font(15))
        for j, c in enumerate(cams):
            if (c, dn) in shots:
                sheet.paste(shots[(c, dn)].resize((tw, th), Image.LANCZOS), (left + j * (tw + 12), y))
    dr.text((24, sheet.height - 70), NOTE, fill=GREY, font=font(17))
    sheet.save(os.path.join(out, "contact_diorama.png"), optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--manifest", default=os.path.join(REPO, "assets", "thuyvan", "dong_lau", "manifest.json"))
    ap.add_argument("--textures", default=os.path.join(REPO, "assets", "thuyvan", "dong_lau", "textures"))
    a = ap.parse_args()
    raw = os.path.join(a.dir, "raw")
    manifest = json.load(open(a.manifest)) if os.path.exists(a.manifest) else {"pieces": {}}
    for j in sorted(glob.glob(os.path.join(raw, "*.json"))):
        nm = os.path.basename(j)[:-5]
        if os.path.exists(os.path.join(raw, nm + ".png")):
            page(raw, nm, a.dir, manifest)
            print("sheet", nm)
    textures(a.textures, a.dir)
    diorama(raw, a.dir)


if __name__ == "__main__":
    main()
