"""Reference boards for the Thủy Vân art direction: crops of the owner's concept sheets, enlarged and labelled, one
board per subject, plus colour swatches sampled from the sheets. Reference for our own painting only: no sheet pixel
goes into game art (plan 3.3 item 27).

    python3 boards.py        -> look/ref/board_<subject>.jpg, look/ref/swatches_<zone>.png, look/ref/swatches.json
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

S = "/Users/kiwimango/Downloads/New Folder With Items/"
OUT = os.path.dirname(os.path.abspath(__file__))

TS = "image-gen-4(1).png"   # Trường Sơn
TU = "image-gen-5(1).png"   # Thạch Uyên
VT = "image-gen-3(1).png"   # Vạn Thủy
DL = "image-gen-6(1).png"   # Đồng Lau
VS = "image-gen-7(1).png"   # Vực Sen Sâu
LU = "image-gen-9.png"      # Lâm Uyên
AT = "image-gen-8(1).png"   # Ảo Thành
MAP = "image-gen-2(1).png"  # Map
MF = "image-gen-2.png"      # Mountain Folk (1055 x 1491)
CF = "image-gen-1(1).png"   # Common Folk
DS = "image-gen-1.png"      # Dragon-Sea (1055 x 1491)

BOARDS = {
    "karst_cliffs": [
        ("Trường Sơn: leaning towers, tiered crowns of pine, mist between", TS, (380, 100, 1024, 520)),
        ("Trường Sơn: tower faces = vertical slabs, pale grey-ochre, dark crevices", TS, (820, 280, 1024, 520)),
        ("Trường Sơn: near cliff under the village, waterfall cut", TS, (0, 300, 300, 640)),
        ("Thạch Uyên: quarried benches, blocky white stone", TU, (20, 440, 470, 800)),
        ("Thạch Uyên: cliff sanctuary niches, warm grey", TU, (520, 1310, 755, 1435)),
        ("Map: the range as stacked spires", MAP, (60, 90, 640, 470)),
        ("Mountain Folk: range in mist, dark green crowns", MF, (207, 1080, 938, 1450)),
        ("Vạn Thủy: far karst islands on the water", VT, (150, 100, 1000, 260)),
    ],
    "waterfalls_mist": [
        ("Trường Sơn: the big fall beside the bridge, white ribbons + spray", TS, (60, 280, 330, 700)),
        ("Trường Sơn: falls off terraces into the valley, mist pooling", TS, (560, 430, 900, 700)),
        ("Trường Sơn: mist bands at several heights", TS, (520, 140, 1024, 420)),
        ("Thạch Uyên: falls behind the aqueduct", TU, (650, 160, 880, 330)),
        ("Lâm Uyên: stepped falls through roots", LU, (560, 260, 960, 700)),
        ("Vực Sen Sâu: cave curtains of water", VS, (240, 110, 700, 470)),
    ],
    "bridges": [
        ("Trường Sơn: hanging bridge, posts, flags, planks, rope rails", TS, (100, 480, 760, 780)),
        ("Trường Sơn: The Passes, long sagging span to a gate", TS, (20, 1105, 510, 1425)),
        ("Thạch Uyên: arched stone bridges and aqueduct", TU, (240, 400, 720, 660)),
        ("Thạch Uyên: bridge works, banners on piers", TU, (270, 1310, 510, 1435)),
        ("Lâm Uyên: living root bridge", LU, (20, 380, 520, 760)),
        ("Map: Two Heights Bridge", MAP, (120, 510, 280, 620)),
    ],
    "houses_roofs": [
        ("Trường Sơn: cliff village, gate tower, upturned eaves", TS, (30, 180, 420, 420)),
        ("Trường Sơn: tower houses on karst tops", TS, (560, 260, 900, 520)),
        ("Trường Sơn: pass gate pavilion", TS, (330, 1105, 510, 1260)),
        ("Đồng Lau: stilt fort, layered roofs, pole banners", DL, (470, 100, 980, 450)),
        ("Đồng Lau: thatched mooring huts on piles", DL, (0, 330, 520, 760)),
        ("Vạn Thủy: dock houses, dark tile, timber", VT, (20, 470, 360, 740)),
        ("Vạn Thủy: lock towers and gates", VT, (300, 400, 680, 600)),
        ("Ảo Thành: lantern-lit lacquer roofs", AT, (15, 100, 420, 700)),
    ],
    "terraces": [
        ("Trường Sơn: rice terraces round a hill, yellow-green steps", TS, (560, 420, 900, 640)),
        ("Trường Sơn: terraces under karst, houses on the steps", TS, (420, 300, 760, 560)),
        ("Trường Sơn: terraces and provisions panel", TS, (683, 790, 1006, 995)),
        ("Thạch Uyên: terraces and water", TU, (765, 1310, 1000, 1435)),
        ("Vạn Thủy: delta fields", VT, (655, 1290, 910, 1365)),
    ],
    "banners_waystones_lanterns": [
        ("Trường Sơn: the clan waystone, rag flags on a rope", TS, (300, 790, 540, 1090)),
        ("Trường Sơn: bridge banners: indigo field, bone-white mark, red tails", TS, (0, 300, 260, 560)),
        ("Trường Sơn: pass banner, tall pole", TS, (20, 1105, 230, 1425)),
        ("Thạch Uyên: maker's mark (diamond knot)", TU, (350, 815, 630, 1080)),
        ("Thạch Uyên: ochre banner on a crane", TU, (920, 500, 1020, 700)),
        ("Đồng Lau: heron banner, lanterns, rope", DL, (60, 100, 400, 560)),
        ("Vực Sen Sâu: lotus banner, paper lanterns", VS, (30, 120, 260, 600)),
        ("Ảo Thành: red lantern rows", AT, (15, 300, 420, 650)),
    ],
    "vegetation": [
        ("Trường Sơn: round pine crowns, dark green, flat-topped", TS, (0, 160, 260, 360)),
        ("Trường Sơn: broadleaf scrub on the near slope", TS, (0, 520, 330, 780)),
        ("Trường Sơn: pine-capped karst tops", TS, (860, 440, 1024, 700)),
        ("Đồng Lau: reed beds", DL, (760, 500, 1024, 660)),
        ("Đồng Lau: mangroves", DL, (808, 1310, 942, 1400)),
        ("Vực Sen Sâu: lotus pads and flowers", VS, (520, 540, 1000, 790)),
        ("Lâm Uyên: giant roots, mossy trunks", LU, (420, 90, 960, 420)),
        ("Mountain Folk: forested cliffs", MF, (560, 1080, 938, 1450)),
    ],
    "water": [
        ("Trường Sơn: river in the valley floor, pale jade with white water", TS, (600, 620, 900, 780)),
        ("Thạch Uyên: turquoise canal under bridges", TU, (420, 600, 700, 760)),
        ("Vạn Thủy: open water, grey-blue sky reflections", VT, (150, 250, 700, 460)),
        ("Vạn Thủy: lock spill, foam", VT, (360, 520, 650, 640)),
        ("Đồng Lau: still marsh water, silver", DL, (420, 420, 1024, 620)),
        ("Vực Sen Sâu: dark teal with lantern glints", VS, (240, 480, 760, 760)),
    ],
    "skies": [
        ("Trường Sơn: bright overcast, big soft cumulus behind the range", TS, (120, 100, 1024, 300)),
        ("Thạch Uyên: hazy blue, light cloud", TU, (120, 90, 1000, 240)),
        ("Vạn Thủy: high warm-grey sky over the delta", VT, (150, 40, 1000, 200)),
        ("Đồng Lau: low grey overcast, pale", DL, (200, 100, 1024, 300)),
        ("Ảo Thành: moonlit indigo night", AT, (200, 100, 950, 300)),
        ("Map vignette: soft blue-grey", MAP, (515, 1245, 815, 1430)),
    ],
    "peoples_dress": [
        ("Common Folk lineup, top row", CF, (0, 90, 1024, 700)),
        ("Common Folk lineup, bottom row", CF, (0, 720, 1024, 1280)),
        ("Mountain Folk: woven bands, indigo / madder / bone", MF, (720, 420, 1025, 670)),
    ],
}

# zone swatch sources: (zone, sheet, hero box)
ZONES = {
    "truong_son": (TS, (0, 100, 1024, 780)),
    "thach_uyen": (TU, (20, 90, 1010, 800)),
    "dong_lau": (DL, (0, 100, 1024, 760)),
    "vuc_sen_sau": (VS, (28, 100, 1000, 780)),
    "van_thuy": (VT, (10, 40, 1010, 760)),
    "lam_uyen": (LU, (20, 90, 1000, 760)),
    "ao_thanh": (AT, (10, 100, 1010, 740)),
}

# targeted samples for R1 (sheet, x, y, r, label): the materials the vista needs
R1_POINTS = [
    (TS, 900, 330, 6, "karst face lit"), (TS, 870, 360, 5, "karst face shade"), (TS, 760, 210, 8, "far karst in haze"),
    (TS, 470, 130, 5, "karst crown lit"), (TS, 300, 470, 5, "pine crown dark"), (TS, 720, 520, 6, "terrace green lit"),
    (TS, 690, 600, 5, "terrace green 2"), (TS, 640, 570, 5, "terrace yellow"), (TS, 200, 420, 6, "waterfall white"),
    (TS, 700, 640, 6, "mist"), (TS, 720, 730, 6, "river jade"), (TS, 760, 700, 5, "river white water"),
    (TS, 560, 160, 10, "sky blue"), (TS, 820, 170, 10, "cloud lit"), (TS, 690, 200, 6, "cloud shade"),
    (TS, 330, 720, 5, "plank wood"), (TS, 470, 690, 4, "rope"), (TS, 420, 560, 5, "banner indigo"),
    (TS, 500, 690, 4, "flag red"), (TS, 140, 220, 5, "roof tile dark"), (TS, 185, 280, 4, "wall lacquer red"),
    (TS, 400, 930, 8, "waystone stone"), (TS, 340, 950, 5, "flag cloth pale"), (TS, 50, 650, 6, "fern green"),
    (TU, 240, 560, 8, "white stone block"), (TU, 300, 640, 6, "white stone shade"), (TU, 560, 690, 6, "canal turquoise"),
    (TU, 820, 560, 5, "kiln fire"), (TU, 980, 590, 6, "banner ochre"),
]


def font(sz):
    for p in ("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", "/Library/Fonts/Arial Unicode.ttf",
              "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


_cache = {}


def sheet(name):
    if name not in _cache:
        _cache[name] = Image.open(S + name).convert("RGB")
    return _cache[name]


def board(name, items, cell_h=420, width=1800):
    # pack crops in rows of target height, scaled up to fill the row width
    crops = [(lbl, sheet(sh).crop(box)) for lbl, sh, box in items]
    rows, row, rw = [], [], 0.0
    for lbl, im in crops:
        w = im.width * cell_h / im.height
        if row and rw + w > width:
            rows.append(row)
            row, rw = [], 0.0
        row.append((lbl, im))
        rw += w
    if row:
        rows.append(row)
    f = font(20)
    ft = font(30)
    pad, lab = 10, 30
    layout = []
    y = 60
    for r in rows:
        tw = sum(im.width / im.height for _, im in r)
        h = min(int((width - pad * (len(r) + 1)) / tw), int(cell_h * 1.6))
        layout.append((y, h, r))
        y += h + lab + pad
    canvas = Image.new("RGB", (width, y + pad), (236, 230, 216))
    d = ImageDraw.Draw(canvas)
    d.text((pad, 14), "Thủy Vân look reference: " + name.replace("_", " ") + "  (crops of the owner's sheets; reference only)",
           fill=(40, 34, 28), font=ft)
    for y0, h, r in layout:
        x = pad
        for lbl, im in r:
            w = int(im.width * h / im.height)
            canvas.paste(im.resize((w, h), Image.LANCZOS), (x, y0))
            t = lbl
            while t and d.textlength(t, font=f) > w - 4:
                t = t[:-2]
            d.text((x + 2, y0 + h + 4), t if t == lbl else t[:-1] + "…", fill=(40, 34, 28), font=f)
            x += w + pad
    p = os.path.join(OUT, "board_%s.jpg" % name)
    canvas.save(p, quality=90)
    print(p, canvas.size)


def kmeans(px, k, it=25, seed=3):
    rng = np.random.default_rng(seed)
    c = px[rng.choice(len(px), k, replace=False)].astype(np.float64)
    for _ in range(it):
        dd = ((px[:, None, :] - c[None, :, :]) ** 2).sum(-1)
        lab = dd.argmin(1)
        for j in range(k):
            m = px[lab == j]
            if len(m):
                c[j] = m.mean(0)
    counts = np.bincount(lab, minlength=k)
    return c, counts


def hexc(c):
    return "#%02x%02x%02x" % tuple(int(round(v)) for v in c)


FAMILIES = {
    # name: (hue range deg, min sat, value range)
    "green foliage": ((60, 170), 0.12, (0.05, 1.0)),
    "yellow-green terrace": ((45, 75), 0.18, (0.35, 1.0)),
    "blue-grey sky / far": ((180, 250), 0.06, (0.55, 1.0)),
    "jade water": ((150, 200), 0.08, (0.3, 0.9)),
    "warm stone / ochre": ((20, 50), 0.10, (0.3, 0.85)),
    "neutral stone": ((0, 360), 0.0, (0.35, 0.85)),
    "white (falls, mist, cloud)": ((0, 360), 0.0, (0.86, 1.0)),
    "red (flags, lacquer)": ((345, 15), 0.30, (0.15, 0.9)),
    "dark timber / tile": ((0, 60), 0.10, (0.08, 0.35)),
}


def hsv(px):
    p = px / 255.0
    mx, mn = p.max(1), p.min(1)
    v, c = mx, mx - mn
    s = np.where(mx > 0, c / np.maximum(mx, 1e-6), 0)
    r, g, b = p[:, 0], p[:, 1], p[:, 2]
    hh = np.zeros(len(p))
    m = c > 1e-6
    rr = m & (mx == r)
    gg = m & (mx == g) & ~rr
    bb = m & ~rr & ~gg
    hh[rr] = ((g - b)[rr] / c[rr]) % 6
    hh[gg] = (b - r)[gg] / c[gg] + 2
    hh[bb] = (r - g)[bb] / c[bb] + 4
    return hh * 60, s, v


def families():
    """Per zone and colour family: the share of the hero image and its dark / mid / light colours (10/50/90 % value),
    and the family's median saturation. This shows how muted the sheets are (they are sepia-washed paintings)."""
    res = {}
    for zone, (sh, box) in ZONES.items():
        px = np.asarray(sheet(sh).crop(box)).reshape(-1, 3).astype(np.float64)
        hh, s, v = hsv(px)
        zr = {}
        for fam, ((h0, h1), smin, (v0, v1)) in FAMILIES.items():
            hm = (hh >= h0) & (hh < h1) if h0 < h1 else (hh >= h0) | (hh < h1)
            if fam == "neutral stone":
                m = (s < 0.12) & (v >= v0) & (v < v1)
            elif fam.startswith("white"):
                m = (s < 0.10) & (v >= v0)
            else:
                m = hm & (s >= smin) & (v >= v0) & (v <= v1)
            if m.sum() < 50:
                continue
            sel = px[m]
            lum = sel @ np.array([0.2126, 0.7152, 0.0722])
            q = np.percentile(lum, [10, 50, 90])
            cols = [hexc(sel[np.argsort(np.abs(lum - qq))[:200]].mean(0)) for qq in q]
            zr[fam] = {"share": round(float(m.mean()), 3), "dark_mid_light": cols,
                       "median_sat": round(float(np.median(s[m])), 3)}
        res[zone] = zr
    return res


def swatches():
    out = {}
    f = font(18)
    for zone, (sh, box) in ZONES.items():
        im = sheet(sh).crop(box).resize((256, int(256 * (box[3] - box[1]) / (box[2] - box[0]))), Image.BILINEAR)
        px = np.asarray(im).reshape(-1, 3).astype(np.float64)
        c, n = kmeans(px, 12)
        order = np.argsort([0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2] for v in c])
        cols = [(hexc(c[i]), int(n[i])) for i in order]
        out[zone] = cols
        sw = Image.new("RGB", (12 * 110, 150), (236, 230, 216))
        d = ImageDraw.Draw(sw)
        d.text((6, 4), zone.replace("_", " ") + " (12 k-means colours of the hero image, dark to light; width = share)",
               fill=(40, 34, 28), font=f)
        tot = sum(k for _, k in cols)
        x = 0
        for hx, k in cols:
            w = max(40, int(12 * 110 * k / tot))
            d.rectangle([x, 30, x + w, 120], fill=hx)
            d.text((x + 3, 124), hx, fill=(40, 34, 28), font=f)
            x += w
        sw = sw.crop((0, 0, max(x, 600), 150))
        sw.save(os.path.join(OUT, "swatches_%s.png" % zone))
    pts = families()
    out["families"] = pts
    sw = Image.new("RGB", (6 * 220, 70 + ((len(pts) + 5) // 6) * 90), (236, 230, 216))
    d = ImageDraw.Draw(sw)
    d.text((6, 6), "R1 materials sampled from the Trường Sơn and Thạch Uyên sheets (raw, before the style guide's push)",
           fill=(40, 34, 28), font=f)
    for i, (lbl, hx) in enumerate(pts):
        x, y = (i % 6) * 220 + 6, 40 + (i // 6) * 90
        d.rectangle([x, y, x + 200, y + 50], fill=hx)
        d.text((x, y + 54), "%s %s" % (hx, lbl), fill=(40, 34, 28), font=f)
    sw.save(os.path.join(OUT, "swatches_r1_points.png"))
    json.dump(out, open(os.path.join(OUT, "swatches.json"), "w"), indent=1, ensure_ascii=False)
    for z, cols in out.items():
        print(z, " ".join(h for h, _ in cols) if z != "r1_points" else cols)


if __name__ == "__main__":
    for n, items in BOARDS.items():
        board(n, items)
    swatches()
