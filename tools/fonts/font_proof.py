#!/usr/bin/env python3
"""The internal proof sheet for UiFonts' fonts (PIL, no Godot), with a line-height check for Vietnamese tone marks:

    python3 tools/fonts/font_proof.py --out <folder> [--font path ...]

Writes font_proof.png and font_proof.txt. Each font in UiFonts' macOS lists (and, for contrast, the two left out,
Hoefler Text and Menlo; and any --font file or shipped family under assets/fonts) is set at 14, 18, 24 and 40 px with
the names, the stacked capitals (Ể Ỗ Ặ Ữ Ậ Ở) and dotted lower letters, drawn at their real size over their line box:

    blue    the line box (the font's ascent above the baseline and descent below; a Godot Label's line is the same box)
    grey    the baseline
    red     ink above the ascent or below the descent: where a mark leaves its line

A mark leaving its line does not clip in a Label (glyphs draw outside their box) but it can touch the line above or be
cut by a clipping parent. The text gives, per font, the most ink outside the box as a fraction of the size: the extra
line spacing that keeps two lines apart (UiFonts.LINE_GAP_EM is set from it).
"""

import argparse
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import font_cmap_check as cc  # noqa: E402

REPO = cc.REPO
SIZES = [14, 18, 24, 40]
LINES = ["Vạn Thủy, Capital of the Waters", "Ể Ỗ Ặ Ữ Ậ Ở   ạ ặ ự ỵ gyp"]
## The roles in UiFonts' order (macOS names first), then the two left out to show why.
SHOWN = [("serif", "Baskerville"), ("serif", "Georgia"), ("serif", "Times New Roman"),
         ("sans", "Avenir Next"), ("sans", "Helvetica Neue"), ("sans", "Arial"),
         ("mono", "Monaco"), ("mono", "Courier New"),
         ("left out", "Hoefler Text"), ("left out", "Menlo")]
WEIGHT = 500

PAPER = (250, 247, 240)
INK = (30, 26, 22)
SOFT = (120, 110, 98)
BOX = (120, 160, 225)
BASE = (190, 185, 178)
OVER = (215, 40, 30)
OK = (40, 140, 70)
W = 1800
PAD = 24


def ui_font(size, bold=False):
    path = "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf"
    return ImageFont.truetype(path, size) if os.path.exists(path) else ImageFont.load_default()


def pick_face(faces, weight=WEIGHT):
    """The upright text face nearest the weight (as SystemFont picks it)."""
    text = [f for f in faces if ord("a") in f.cmap] or faces
    upright = [f for f in text if "italic" not in (f.style + f.full).lower() and "oblique" not in (f.style + f.full).lower()]
    return min(upright or text, key=lambda f: (abs(f.weight - weight), f.weight))


def bundled_files():
    """Font files shipped under assets/fonts (none until a family is approved and added)."""
    out = []
    root = os.path.join(REPO, "assets", "fonts")
    for d, _, files in os.walk(root):
        out += [os.path.join(d, f) for f in sorted(files) if f.lower().endswith((".ttf", ".otf"))]
    return out


def measure(face, size):
    """(ascent, descent, ink top above baseline, ink bottom below baseline) in px over both lines."""
    f = ImageFont.truetype(face.path, size, index=face.index)
    asc, desc = f.getmetrics()
    top = bot = 0
    for line in LINES:
        b = f.getbbox(line, anchor="ls")
        top = max(top, -b[1])
        bot = max(bot, b[3])
    return f, asc, desc, top, bot


def card_height():
    return 30 + sum(s + int(s * 0.45) + 14 for s in SIZES) + 10


def draw_card(d, x, y, role, name, face, sets):
    miss = {k: face.missing(v) for k, v in sets.items()}
    n_miss = sum(len(v) for v in miss.values())
    head = "%s  ·  %s  (%s, face %d, weight %d)" % (role, name, os.path.basename(face.path), face.index, face.weight)
    d.text((x, y), head, font=ui_font(16, True), fill=INK)
    verdict = "cmap complete" if not n_miss else "cmap MISSING %d: %s" % (
        n_miss, ", ".join("%s %d" % (k, len(v)) for k, v in miss.items() if v))
    d.text((x + 900, y + 2), verdict, font=ui_font(14), fill=OK if not n_miss else OVER)
    y += 30
    worst = 0.0
    rows = []
    for size in SIZES:
        f, asc, desc, top, bot = measure(face, size)
        over, under = top - asc, bot - desc
        worst = max(worst, over / size, under / size)
        rows.append((size, asc, desc, top, bot))
        base = y + asc + int(size * 0.2)
        gx = x + 60
        d.text((x, base - 12), "%d px" % size, font=ui_font(12), fill=SOFT)
        cx = gx
        for line in LINES:
            wpx = int(d.textlength(line, font=f))
            d.rectangle([cx, base - asc, cx + wpx, base + desc], outline=BOX)
            d.line([cx, base, cx + wpx, base], fill=BASE)
            d.text((cx, base), line, font=f, fill=INK, anchor="ls")
            b = f.getbbox(line, anchor="ls")
            if -b[1] > asc:
                d.line([cx, base + b[1], cx + wpx, base + b[1]], fill=OVER)
            if b[3] > desc:
                d.line([cx, base + b[3], cx + wpx, base + b[3]], fill=OVER)
            cx += wpx + 40
        note = "asc %d  desc %d  ink %d / %d  out %+d / %+d" % (asc, desc, top, bot, over, under)
        d.text((x + W - 2 * PAD - 330, base - 12), note, font=ui_font(12),
               fill=OVER if over > 0 or under > 0 else SOFT)
        y = base + desc + int(size * 0.25) + 14 - int(size * 0.2)
    return worst, rows, n_miss


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--out", required=True, help="folder for font_proof.png and font_proof.txt")
    ap.add_argument("--font", action="append", default=[], help="also proof this font file")
    args = ap.parse_args(argv)
    extra = bundled_files() + args.font
    fams = cc.installed(extra)
    sets = {"vietnamese": cc.vietnamese_letters(), "punct": cc.PUNCT, "data": cc.data_chars()}
    shown = list(SHOWN)
    for p in extra:
        for face in cc.read_faces(p):
            if ("extra", face.family) not in shown:
                shown.insert(0, ("extra", face.family))
    shown = [(r, n) for r, n in shown if fams.get(n)]
    ch = card_height()
    img = Image.new("RGB", (W, PAD * 2 + 60 + ch * len(shown)), PAPER)
    d = ImageDraw.Draw(img)
    d.text((PAD, PAD), "UiFonts proof: real sizes, line boxes (blue), ink outside the box (red)", font=ui_font(22, True),
           fill=INK)
    d.text((PAD, PAD + 30), "Internal. Weight %d upright faces, as SystemFont picks them. Generated by "
           "tools/fonts/font_proof.py." % WEIGHT, font=ui_font(14), fill=SOFT)
    y = PAD + 60
    lines = ["UiFonts proof: ink outside the line box per font (fraction of the size = extra line spacing needed)", ""]
    for role, name in shown:
        face = pick_face(fams[name])
        worst, rows, n_miss = draw_card(d, PAD, y, role, name, face, sets)
        d.line([PAD, y + ch - 6, W - PAD, y + ch - 6], fill=BASE)
        y += ch
        lines.append("%-9s %-16s %-30s cmap %-9s worst out %.3f em (%s)" % (
            role, name, "%s#%d" % (os.path.basename(face.path), face.index),
            "complete" if not n_miss else "miss %d" % n_miss, worst,
            ", ".join("%dpx %+d/%+d" % (s, t - a, b - de) for s, a, de, t, b in rows)))
    lines += ["", "Line gap per role (the worst of the role's macOS fonts, rounded up to 0.025 em):"]
    for role in ("serif", "sans", "mono"):
        worst = 0.0
        for r, n in shown:
            if r == role:
                for s in SIZES:
                    _, a, de, t, b = measure(pick_face(fams[n]), s)
                    worst = max(worst, (t - a) / s, (b - de) / s)
        lines.append("  %-6s %.3f em" % (role, math.ceil(worst * 40) / 40))
    os.makedirs(args.out, exist_ok=True)
    img.save(os.path.join(args.out, "font_proof.png"))
    with open(os.path.join(args.out, "font_proof.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print("PROOF WRITTEN %s (%dx%d)" % (os.path.join(args.out, "font_proof.png"), img.width, img.height))
    return 0


if __name__ == "__main__":
    sys.exit(main())
