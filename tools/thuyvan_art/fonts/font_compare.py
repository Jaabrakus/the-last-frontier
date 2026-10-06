#!/usr/bin/env python3
"""The shipped-font check and comparison strip for Thủy Vân (PIL, no Godot):

    python3 tools/thuyvan_art/fonts/font_compare.py --out <folder> --candidate-dir <folder> [--backdrop <sheet png>]

For the two OFL families fetched by fetch_fonts.py (Be Vietnam Pro, shipped under assets/fonts; Noto Serif, the
candidate, from fetch_fonts.py --candidates <folder>) it

  1. checks every shipped and candidate face's cmap for the 134 Vietnamese letters, the game's punctuation and every character in
     data/thuyvan/*.json, with T2's reader (tools/fonts/font_cmap_check.py);
  2. measures each face's ink outside its line box at 14-40 px (T2's font_proof method), the extra line spacing
     UiFonts.LINE_GAP_EM needs for stacked tone marks;
  3. draws font_compare_strip.png: T2's strip lines (tools/fonts/font_proof.py STRIP_LINES), light and dark, with the
     system Baskerville and Avenir Next (UiFonts' current first picks) beside Noto Serif and Be Vietnam Pro;
  4. draws font_compare_context.png: four title-card and HUD pairings (D the pick, Baskerville + Be Vietnam Pro; A Noto Serif + Be Vietnam Pro; B Be Vietnam Pro
     alone; C the system Baskerville + Avenir Next) over a concept sheet, when --backdrop is given.

Writes font_compare.txt and font_compare.json beside the images. Deterministic: same files in, same images out.
"""

import argparse
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, "tools", "fonts"))
import font_cmap_check as cc  # noqa: E402
import font_proof as fp  # noqa: E402

FONTS = os.path.join(REPO, "assets", "fonts")
SIZES = fp.SIZES
STRIP_LINES = fp.STRIP_LINES
MEASURE_LINES = fp.LINES
WEIGHT = 500


class Pick:
    """One font as the strip sets it: a file, a face index, and a weight for a variable file."""

    def __init__(self, label, path, index=0, wght=None, note=""):
        self.label, self.path, self.index, self.wght, self.note = label, path, index, wght, note

    def font(self, size):
        f = ImageFont.truetype(self.path, size, index=self.index)
        if self.wght is not None:
            axes = f.get_variation_axes()
            f.set_variation_by_axes([self.wght if a["name"] in (b"Weight", "Weight") else a["default"] for a in axes])
        return f


def system_pick(fams, family, weight=WEIGHT):
    face = fp.pick_face(fams[family], weight)
    return Pick(family, face.path, face.index, None, "system, weight %d" % face.weight)


def font_files(*roots):
    """Every face file in the family folders under the roots: [(folder, path)]."""
    out = []
    for root in roots:
        for folder in sorted(os.listdir(root)) if root and os.path.isdir(root) else []:
            d = os.path.join(root, folder)
            for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
                if f.lower().endswith((".ttf", ".otf")):
                    out.append((folder, os.path.join(d, f)))
    return out


def ink_out(pick, size):
    f = pick.font(size)
    asc, desc = f.getmetrics()
    top = bot = 0
    for line in MEASURE_LINES:
        b = f.getbbox(line, anchor="ls")
        top, bot = max(top, -b[1]), max(bot, b[3])
    return asc, desc, top - asc, bot - desc


def check(out_txt, candidate_dir):
    letters = cc.vietnamese_letters()
    sets = {"vietnamese": letters, "punct": cc.PUNCT, "data": cc.data_chars()}
    rows = []
    lines = ["Shipped (assets/fonts) and candidate fonts: cmap (%d Vietnamese letters, %d punctuation, %d data characters) and ink outside the line "
             "box at %s px (fraction of the size)" % (len(letters), len(cc.PUNCT), len(sets["data"]),
                                                      "/".join(map(str, SIZES)))]
    for folder, path in font_files(FONTS, candidate_dir):
        for face in cc.read_faces(path):
            miss = {k: "".join(face.missing(v)) for k, v in sets.items()}
            n = sum(len(v) for v in miss.values())
            # Variable files: measure at the weight UiFonts asks for by default.
            wght = WEIGHT if "[" in os.path.basename(path) else None
            pick = Pick(face.family, path, face.index, wght)
            worst = 0.0
            per = []
            for s in SIZES:
                asc, desc, over, under = ink_out(pick, s)
                worst = max(worst, over / s, under / s)
                per.append("%dpx %+d/%+d" % (s, over, under))
            rows.append({"folder": folder, "file": os.path.basename(path), "family": face.family, "style": face.style,
                         "weight_class": face.weight, "glyphs": len(face.cmap), "missing": miss, "ok": n == 0,
                         "ink_out_em": round(worst, 3), "per_size": per})
            lines.append("  %-14s %-34s %-4s cmap %5d  worst out %.3f em  (%s)" % (
                folder, os.path.basename(path), "OK" if n == 0 else "FAIL", len(face.cmap), worst, ", ".join(per)))
            for k, v in miss.items():
                if v:
                    lines.append("      missing %s: %s" % (k, v))
    ok = all(r["ok"] for r in rows) and rows
    lines.append("FONT CMAP CHECK %s (%d faces)" % ("PASSED" if ok else "FAILED", len(rows)))
    with open(out_txt, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    return rows, bool(ok)


def label_font(size, bold=False):
    return fp.ui_font(size, bold)


def strip(picks, path):
    """T2's strip, four families (role pairs side by side in reading order), light and dark."""
    col = 1240
    cols = []
    for look, bg, panel, edge, ink, soft in fp.STRIP_LOOKS:
        img = Image.new("RGB", (col + 72, 4000), bg)
        d = ImageDraw.Draw(img)
        y = 36
        d.text((36, y), "%s  ·  14, 18, 24, 40 px  ·  weight 500  ·  T2's lines" % look, font=label_font(16, True),
               fill=soft)
        y += 40
        for role, pick in picks:
            top = y
            y += 14
            d.text((62, y), "%s  ·  %s  (%s)" % (role, pick.label, pick.note), font=label_font(14, True), fill=soft)
            y += 30
            for size in SIZES:
                f = pick.font(size)
                asc, desc = f.getmetrics()
                gap = max(6, int(size * 0.15))
                x0, x = 100, 100
                base = y + asc
                d.text((62, base - 12), "%d" % size, font=label_font(11), fill=soft)
                for line in STRIP_LINES:
                    w = int(d.textlength(line, font=f))
                    if x > x0 and x + w > col:
                        x = x0
                        base += asc + desc + gap
                    d.text((x, base), line, font=f, fill=ink, anchor="ls")
                    x += w + int(size * 0.9)
                y = base + desc + gap + 8
            y += 10
            d.rounded_rectangle([36, top, col + 36, y], radius=6, outline=edge, width=1)
            d.rectangle([36, top + 2, 39, y - 2], fill=edge)
            y += 22
        cols.append(img.crop((0, 0, col + 72, y + 14)))
    h = max(c.height for c in cols)
    out = Image.new("RGB", (sum(c.width for c in cols), h), (0, 0, 0))
    x = 0
    for c in cols:
        out.paste(c, (x, 0))
        x += c.width
    out.save(path)
    return out.size


def spaced(d, xy, text, font, fill, track=0.0, anchor="ls"):
    """Draw with letter spacing (track, a fraction of the size); returns the width."""
    x, y = xy
    size = font.size
    for ch in text:
        d.text((x, y), ch, font=font, fill=fill, anchor=anchor)
        x += d.textlength(ch, font=font) + track * size
    return x - xy[0]


def spaced_width(d, text, font, track):
    return sum(d.textlength(ch, font=font) for ch in text) + track * font.size * len(text)


def context(backdrop, variants, path):
    """Each pairing as a zone title card over the Trường Sơn sheet's hero and a HUD prompt line."""
    src = Image.open(backdrop).convert("RGB")
    w, h = src.size
    # The hero panel of the Trường Sơn sheet (1024 x 1536): the bridge, falls and karst under the title.
    # Cropped short of the right edge so the sheet's Hán lettering stays out of the preview (style guide section 8).
    box = (0, int(h * 0.12), int(w * 0.86), int(h * 0.50))
    hero = src.crop(box).resize((1200, int(1200 * (box[3] - box[1]) / box[2])), Image.LANCZOS)
    cards = []
    for name, title, sans in variants:
        img = hero.copy()
        ov = Image.new("L", img.size, 0)
        od = ImageDraw.Draw(ov)
        for i in range(img.height):  # a soft dark band behind the title and at the foot for the HUD line
            t = abs(i - img.height * 0.30) / (img.height * 0.20)
            a = max(0.0, 1.0 - t) * 150
            b = max(0.0, (i - img.height * 0.80) / (img.height * 0.20)) * 170
            od.line([(0, i), (img.width, i)], fill=int(min(200, a + b)))
        img = Image.composite(Image.new("RGB", img.size, (14, 18, 20)), img, ov.filter(ImageFilter.GaussianBlur(8)))
        d = ImageDraw.Draw(img)
        cx = img.width // 2
        tf = title.font(64)
        txt = "ĐÁ TRẮNG"
        tw = spaced_width(d, txt, tf, 0.12)
        spaced(d, (cx - tw / 2 + 2, img.height * 0.30 + 2), txt, tf, (0, 0, 0), 0.12)
        spaced(d, (cx - tw / 2, img.height * 0.30), txt, tf, (246, 238, 220), 0.12)
        sf = title.font(24)
        sub = "the white-stone reach under the Two Heights · Trường Sơn"
        sw = d.textlength(sub, font=sf)
        d.text((cx - sw / 2, img.height * 0.30 + 40), sub, font=sf, fill=(232, 214, 176), anchor="ls")
        d.line([cx - 160, img.height * 0.30 + 56, cx + 160, img.height * 0.30 + 56], fill=(217, 158, 77), width=1)
        hf = sans.font(20)
        hud = "[E]  Cross the rope bridge   ·   Hồ Tinh waits at the clan house   ·   Mường Lò ferry: 3 đồng"
        d.text((40, img.height - 28), hud, font=hf, fill=(240, 234, 220), anchor="ls")
        lf = label_font(15, True)
        d.rectangle([0, 0, img.width, 26], fill=(14, 18, 20))
        d.text((12, 19), name, font=lf, fill=(217, 190, 140), anchor="ls")
        cards.append(img)
    out = Image.new("RGB", (cards[0].width, sum(c.height for c in cards) + 12 * (len(cards) - 1)), (14, 18, 20))
    y = 0
    for c in cards:
        out.paste(c, (0, y))
        y += c.height + 12
    out.save(path)
    return out.size


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--out", required=True)
    ap.add_argument("--candidate-dir", required=True, help="where fetch_fonts.py --candidates put Noto Serif")
    ap.add_argument("--backdrop", help="a concept sheet to set the title cards on (the Trường Sơn sheet)")
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    rows, ok = check(os.path.join(args.out, "font_compare.txt"), args.candidate_dir)
    fams = cc.installed()
    noto = os.path.join(args.candidate_dir, "notoserif", "NotoSerif[wdth,wght].ttf")
    bvp = os.path.join(FONTS, "bevietnampro", "BeVietnamPro-Medium.ttf")
    picks = [
        ("serif", system_pick(fams, "Baskerville")),
        ("serif", Pick("Noto Serif", noto, 0, WEIGHT, "OFL candidate, not shipped; variable at wght 500")),
        ("sans", system_pick(fams, "Avenir Next")),
        ("sans", Pick("Be Vietnam Pro", bvp, 0, None, "shipped OFL, Medium")),
    ]
    size = strip(picks, os.path.join(args.out, "font_compare_strip.png"))
    print("strip", size)
    if args.backdrop:
        variants = [
            ("D  THE PICK: titles the system serif (Baskerville)  ·  HUD Be Vietnam Pro Medium (shipped)",
             system_pick(fams, "Baskerville", 600), Pick("Be Vietnam Pro", bvp)),
            ("A  titles Noto Serif SemiBold (candidate, not shipped)  ·  HUD Be Vietnam Pro Medium",
             Pick("Noto Serif", noto, 0, 600), Pick("Be Vietnam Pro", bvp)),
            ("B  Be Vietnam Pro alone  (titles SemiBold, HUD Medium)",
             Pick("Be Vietnam Pro", os.path.join(FONTS, "bevietnampro", "BeVietnamPro-SemiBold.ttf")),
             Pick("Be Vietnam Pro", bvp)),
            ("C  today's system fonts  (Baskerville, Avenir Next)",
             system_pick(fams, "Baskerville", 600), system_pick(fams, "Avenir Next")),
        ]
        print("context", context(args.backdrop, variants, os.path.join(args.out, "font_compare_context.png")))
    with open(os.path.join(args.out, "font_compare.json"), "w", encoding="utf-8") as f:
        json.dump({"faces": rows, "ok": ok}, f, ensure_ascii=False, indent=1)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
