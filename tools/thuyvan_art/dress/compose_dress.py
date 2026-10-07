"""Thủy Vân dress: the owner's review pages (python3; PIL). Each page sets a lineup render (dress_render.py) beside the
matching crops of the owner's concept sheets, with a caption under every figure and the garments, their triangle
counts and zone dyes in a strip below; the flat black silhouette inset in the render's corner.

    python3 tools/thuyvan_art/dress/compose_dress.py <renders dir> <out dir> <pages.json>

pages.json: [{"render": name, "out": file, "title", "subtitle", "people": "mountain_folk" | ..., "labels": [per
figure], "notes": [lines]}]. The sheet crops are review material only (never game textures).
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SHEETS = "/Users/kiwimango/Downloads/New Folder With Items/"
LINEUP = "image-gen-1(1).png"
# the crop boxes of peoples_places/work_peoples/peoples_data.py (make_pages.py): the lineup figure, then sheet crops
CROPS = {
    "mountain_folk": {"lineup": (265, 95, 535, 670),
                      "sheets": [("image-gen-2.png", (140, 105, 735, 1065), "People's sheet: the hunter"),
                                 ("image-gen-4(1).png", (22, 1105, 510, 1425), "Trường Sơn: a porter on the bridge")]},
    "stone_children": {"lineup": (510, 95, 770, 670),
                       "sheets": [("image-gen-5(1).png", (20, 480, 430, 800), "Thạch Uyên: quarry hands"),
                                  ("image-gen-5(1).png", (18, 815, 342, 1085), "Tools: chisels, hammers, cords")]},
    "dragon_sea": {"lineup": (0, 95, 300, 670),
                   "sheets": [("image-gen-3(1).png", (356, 815, 668, 1085), "Vạn Thủy piers: dock workers"),
                              ("image-gen-1.png", (120, 110, 745, 1085), "People's sheet: court dress")]},
}
FONT = "/System/Library/Fonts/HelveticaNeue.ttc"
SERIF = "/System/Library/Fonts/Supplemental/Georgia.ttf"
PAPER = (241, 233, 220)
INK = (38, 34, 30)
RED = (150, 52, 36)
GREY = (110, 104, 96)


def font(size, bold=False, serif=False):
    try:
        if serif and os.path.exists(SERIF):
            return ImageFont.truetype(SERIF, size)
        return ImageFont.truetype(FONT, size, index=1 if bold else 0)
    except OSError:
        return ImageFont.load_default()


def fit(img, w, h):
    s = min(w / img.width, h / img.height)
    return img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS)


def wrap(d, text, f, width):
    words, lines, cur = text.split(), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if d.textlength(t, font=f) > width and cur:
            lines.append(cur)
            cur = wd
        else:
            cur = t
    if cur:
        lines.append(cur)
    return lines


def page(rdir, odir, pg):
    rpath = os.path.join(rdir, pg["render"] + ".png")
    meta = json.load(open(os.path.join(rdir, pg["render"] + ".json")))
    R = Image.open(rpath).convert("RGB")
    W, H = 3000, 1820
    P = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(P)
    d.text((40, 26), pg["title"], font=font(56, serif=True), fill=INK)
    d.text((42, 98), pg.get("subtitle", ""), font=font(26), fill=GREY)
    d.line((40, 140, W - 40, 140), fill=INK, width=2)
    # the sheets on the left
    x0, y0 = 40, 165
    cw = 560
    cr = CROPS.get(pg.get("people", ""), None)
    if cr:
        lin = Image.open(SHEETS + LINEUP).convert("RGB").crop(cr["lineup"])
        a = fit(lin, cw // 2 - 8, 760)
        P.paste(a, (x0, y0))
        f0 = Image.open(SHEETS + cr["sheets"][0][0]).convert("RGB").crop(cr["sheets"][0][1])
        b = fit(f0, cw // 2 - 8, 760)
        P.paste(b, (x0 + cw // 2 + 8, y0))
        d.text((x0, y0 + max(a.height, b.height) + 8), "Common Folk lineup  |  " + cr["sheets"][0][2],
               font=font(20), fill=GREY)
        y1 = y0 + max(a.height, b.height) + 44
        for sh, box, cap in cr["sheets"][1:]:
            c = fit(Image.open(SHEETS + sh).convert("RGB").crop(box), cw, 420)
            P.paste(c, (x0, y1))
            d.text((x0, y1 + c.height + 6), cap, font=font(20), fill=GREY)
            y1 += c.height + 40
        d.text((x0, H - 60), "Sheet crops: the owner's concept art, for comparison only", font=font(18), fill=GREY)
    # the render
    rx = x0 + cw + 40
    rw = W - rx - 40
    rr = fit(R, rw, 1200)
    P.paste(rr, (rx, y0))
    sil = os.path.join(rdir, pg["render"] + "_sil.png")
    if os.path.exists(sil):
        s = Image.open(sil).convert("RGB")
        s = fit(s, 420, 240)
        P.paste(s, (rx + rr.width - s.width - 12, y0 + 12))
        d.rectangle((rx + rr.width - s.width - 12, y0 + 12, rx + rr.width - 12, y0 + 12 + s.height), outline=INK)
        d.text((rx + rr.width - s.width - 10, y0 + 16 + s.height), "silhouette", font=font(16), fill=GREY)
    # labels under the figures (by their x across the render: the camera frames them evenly)
    figs = meta["figures"]
    labels = pg.get("labels") or [f.get("label", "") for f in figs]
    if figs:
        for f, lab in zip(figs, labels):
            tx = rx + int(f.get("u", 0.5) * rr.width)
            tw = d.textlength(lab, font=font(22, bold=True))
            d.text((tx - tw / 2, y0 + rr.height + 8), lab, font=font(22, bold=True), fill=INK)
    # the garments strip
    yb = y0 + rr.height + 50
    d.text((rx, yb), "WORN (cloth2, triangles at LOD0 / budget; zones: dye)", font=font(24, bold=True), fill=RED)
    yb += 36
    seen = {}
    for f in figs:
        for wn in f["worn"]:
            seen.setdefault(wn["id"], wn)
    colw = (rw - 20) // 2
    i = 0
    for gid, wn in seen.items():
        cx = rx + (i % 2) * (colw + 20)
        cy = yb + (i // 2) * 52
        z = "  ".join("%s %s" % (k, v.replace("tv_", "")) for k, v in sorted(wn["dyes"].items()))
        d.text((cx, cy), "%s  (%s)  %d / %s tris" % (gid, wn.get("slot", ""), wn["tris"], wn.get("budget", "?")),
               font=font(20, bold=True), fill=INK)
        d.text((cx, cy + 24), "zones: " + z, font=font(18), fill=GREY)
        i += 1
    yn = yb + ((i + 1) // 2) * 52 + 10
    for line in pg.get("notes", []):
        for ln in wrap(d, line, font(20), rw):
            d.text((rx, yn), ln, font=font(20), fill=INK)
            yn += 26
    os.makedirs(odir, exist_ok=True)
    out = os.path.join(odir, pg["out"])
    P.save(out, quality=92)
    print("wrote", out)


def main():
    rdir, odir, pj = sys.argv[1], sys.argv[2], sys.argv[3]
    for pg in json.load(open(pj)):
        try:
            page(rdir, odir, pg)
        except FileNotFoundError as e:
            print("skip", pg.get("render"), e)


if __name__ == "__main__":
    main()
