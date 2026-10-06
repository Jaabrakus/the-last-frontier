#!/usr/bin/env python3
"""The font choice strip for Thủy Vân: the two OFL candidates against the system fonts UiFonts uses today.

    python3 tools/thuyvan_art/fonts/font_compare.py --out <folder>

Four columns on the same lines T2's strip used (tools/fonts/font_proof.py STRIP_LINES), at 14, 18, 24 and 40 px,
light and dark: serif (system Baskerville, then Noto Serif) and sans (system Avenir Next, then Be Vietnam Pro), at
UiFonts' weight 500 (Medium where the family has it). Each card carries its cmap verdict over the 134 Vietnamese
letters, the game's punctuation and every character in data/thuyvan (tools/fonts/font_cmap_check.py's sets), and its
worst tone-mark overshoot outside the line box in ems. A candidate not yet under assets/fonts/<folder>/ is drawn as an
empty card that says so (tools/thuyvan_art/fonts/fetch_fonts.sh fetches them).

Writes font_compare.png and font_compare.txt. Deterministic: no randomness, only the font files on disk.
"""

import argparse
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, "tools", "fonts"))
import font_cmap_check as cc  # noqa: E402
import font_proof as fp  # noqa: E402

SIZES = [14, 18, 24, 40]
LINES = fp.STRIP_LINES + ["ạ ặ ự ỵ đ Đ", "“Mist that holds” — 1765 · §3"]
## (role, label, family name in the cmap reader, shipped folder or None for a system font)
COLUMNS = [("serif", "Baskerville (system, today)", "Baskerville", None),
           ("serif", "Noto Serif (OFL candidate)", "Noto Serif", "notoserif"),
           ("sans", "Avenir Next (system, today)", "Avenir Next", None),
           ("sans", "Be Vietnam Pro (OFL candidate)", "Be Vietnam Pro", "bevietnampro")]
WEIGHT = 500
COL_W = 760
PAD = 28


def shipped(folder):
    d = os.path.join(REPO, "assets", "fonts", folder)
    if not os.path.isdir(d):
        return []
    return [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.lower().endswith((".ttf", ".otf"))]


def font_at(face, size):
    f = ImageFont.truetype(face.path, size, index=face.index)
    if "[" in os.path.basename(face.path):  # a variable file: drive the weight axis
        try:
            axes = f.get_variation_axes()
            f.set_variation_by_axes([WEIGHT if a.get("name", b"") in (b"Weight", "Weight") else a["default"]
                                     for a in axes])
        except (OSError, AttributeError):
            pass
    return f


def overshoot(face):
    worst = 0.0
    for s in SIZES:
        f = font_at(face, s)
        asc, desc = f.getmetrics()
        for line in LINES:
            b = f.getbbox(line, anchor="ls")
            worst = max(worst, (-b[1] - asc) / s, (b[3] - desc) / s)
    return worst


def card(d, x, y, look, label, face, sets, measure_only=False):
    _, bg, panel, edge, ink, soft = look
    top = y
    y += 14
    if face is None:
        h = 300
        if not measure_only:
            d.rounded_rectangle([x, top, x + COL_W, top + h], radius=8, outline=soft, width=1)
            d.text((x + 24, top + 16), label, font=fp.ui_font(15, True), fill=soft)
            d.text((x + 24, top + 120), "not on disk: assets/fonts/ has no files for it yet", font=fp.ui_font(18),
                   fill=soft)
            d.text((x + 24, top + 150), "zsh tools/thuyvan_art/fonts/fetch_fonts.sh, then re-run", font=fp.ui_font(15),
                   fill=soft)
        return top + h, None
    miss = {k: face.missing(v) for k, v in sets.items()}
    n_miss = sum(len(v) for v in miss.values())
    verdict = "cmap complete" if not n_miss else "MISSING " + " ".join("".join(v[:12]) for v in miss.values() if v)
    if not measure_only:
        d.text((x + 24, y), label, font=fp.ui_font(15, True), fill=soft)
        d.text((x + COL_W - 260, y + 1), verdict, font=fp.ui_font(13), fill=fp.OK if not n_miss else fp.OVER)
    y += 30
    for size in SIZES:
        f = font_at(face, size)
        asc, desc = f.getmetrics()
        lx = x + 64
        if not measure_only:
            d.text((x + 24, y + asc - 10), str(size), font=fp.ui_font(12), fill=soft)
        for t in LINES:
            w = int(d.textlength(t, font=f))
            if lx + w > x + COL_W - 16 and lx > x + 64:
                lx = x + 64
                y += asc + desc + math.ceil(0.15 * size)
            if not measure_only:
                d.text((lx, y + asc), t, font=f, fill=ink, anchor="ls")
            lx += w + int(size * 1.0)
        y += asc + desc + 12
    y += 14
    if not measure_only:
        d.rounded_rectangle([x, top, x + COL_W, y], radius=8, outline=edge, width=1)
        d.rectangle([x, top + 4, x + 3, y - 4], fill=edge)
    return y, n_miss


def pick(fams, family):
    faces = fams.get(family) or []
    return fp.pick_face(faces, WEIGHT) if faces else None


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--out", required=True)
    args = ap.parse_args(argv)
    extra = [p for _, _, _, folder in COLUMNS if folder for p in shipped(folder)]
    fams = cc.installed(extra)
    sets = {"vietnamese": cc.vietnamese_letters(), "punct": cc.PUNCT, "data": cc.data_chars()}
    faces = []
    for role, label, family, folder in COLUMNS:
        face = pick(fams, family)
        if folder and face is not None and not face.path.startswith(os.path.join(REPO, "assets", "fonts")):
            face = None  # only the shipped copy counts for a candidate
        faces.append(face)
    # Height of the tallest column, measured once.
    probe = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    col_h = max(card(probe, 0, 0, fp.STRIP_LOOKS[0], c[1], f, sets, True)[0] for c, f in zip(COLUMNS, faces))
    width = PAD + len(COLUMNS) * (COL_W + PAD)
    head = 96
    img = Image.new("RGB", (width, head + 2 * (col_h + PAD) + PAD), fp.STRIP_LOOKS[0][1])
    d = ImageDraw.Draw(img)
    d.text((PAD, 24), "Thủy Vân lettering: the OFL candidates against today's system fonts", font=fp.ui_font(24, True),
           fill=fp.INK)
    d.text((PAD, 60), "Weight %d, 14 / 18 / 24 / 40 px, the T2 strip's lines. Generated by "
           "tools/thuyvan_art/fonts/font_compare.py." % WEIGHT, font=fp.ui_font(14), fill=fp.SOFT)
    report = ["role   column                           file                                  cmap       overshoot"]
    for li, look in enumerate(fp.STRIP_LOOKS):
        y0 = head + li * (col_h + PAD)
        d.rectangle([0, y0 - PAD // 2, width, y0 + col_h + PAD // 2], fill=look[1])
        for ci, ((role, label, family, folder), face) in enumerate(zip(COLUMNS, faces)):
            x = PAD + ci * (COL_W + PAD)
            _, n_miss = card(d, x, y0, look, label, face, sets)
            if li == 0:
                if face is None:
                    report.append("%-6s %-32s %-37s %s" % (role, label, "-", "not fetched"))
                else:
                    report.append("%-6s %-32s %-37s %-10s %.3f em" % (
                        role, label, "%s#%d" % (os.path.basename(face.path), face.index),
                        "complete" if not n_miss else "miss %d" % n_miss, overshoot(face)))
    os.makedirs(args.out, exist_ok=True)
    img.save(os.path.join(args.out, "font_compare.png"))
    with open(os.path.join(args.out, "font_compare.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(report) + "\n")
    print("\n".join(report))
    print("WRITTEN %s (%dx%d)" % (os.path.join(args.out, "font_compare.png"), img.width, img.height))
    return 0


if __name__ == "__main__":
    sys.exit(main())
