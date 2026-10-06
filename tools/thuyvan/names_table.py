#!/usr/bin/env python3
"""Renders the owner's names tables from data/thuyvan as large-type PNGs for him to mark:

    python3 tools/thuyvan/names_table.py --out-dir <folder>

names_table_peoples.png: each people's English name, English title, the Vietnamese candidates (a box to tick beside
each, and room to write his own) and where each came from. names_table_places.png: the places whose English title or
Book I label is our placeholder, or which have no Vietnamese name yet. System fonts only (no downloads).
"""

import argparse
import json
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
DATA = os.path.join(REPO, "data", "thuyvan")
REG = ["/System/Library/Fonts/Supplemental/Arial Unicode.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf"]
BOLD = ["/System/Library/Fonts/Supplemental/Arial Bold.ttf"] + REG

INK = (38, 32, 26)
SOFT = (110, 100, 88)
PAPER = (247, 242, 231)
RULE = (205, 194, 172)
OURS = (160, 70, 30)


def font(paths, size):
    for p in paths:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def load(name, key):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)[key]


def wrap(d, text, fnt, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=fnt) <= width or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def table(out, title, notes, headers, widths, rows, w=2600):
    """rows: lists of cells; a cell is a list of (text, colour, kind) lines, kind "text" or "box" (a tick box)."""
    f_title, f_note, f_head, f_cell = font(BOLD, 58), font(REG, 32), font(BOLD, 34), font(REG, 36)
    m, pad, lh = 70, 22, 48
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    laid = []
    for row in rows:
        cells = []
        for cell, cw in zip(row, widths):
            lines = []
            for text, colour, kind in cell:
                if kind == "box":
                    lines.append((text, colour, kind))
                else:
                    lines += [(s, colour, kind) for s in wrap(probe, text, f_cell, cw - 2 * pad - (0 if kind == "text" else 60))]
            cells.append(lines)
        laid.append((cells, max(len(c) for c in cells) * lh + 2 * pad))
    note_lines = []
    for n in notes:
        note_lines += wrap(probe, n, f_note, w - 2 * m)
    head_h = 70
    h = m + 80 + len(note_lines) * 42 + 30 + head_h + sum(rh for _, rh in laid) + m
    img = Image.new("RGB", (w, h), PAPER)
    d = ImageDraw.Draw(img)
    y = m
    d.text((m, y), title, font=f_title, fill=INK)
    y += 86
    for s in note_lines:
        d.text((m, y), s, font=f_note, fill=SOFT)
        y += 42
    y += 30
    x = m
    d.rectangle([m, y, w - m, y + head_h], fill=(232, 223, 203))
    for hd, cw in zip(headers, widths):
        d.text((x + pad, y + 16), hd, font=f_head, fill=INK)
        x += cw
    y += head_h
    for cells, rh in laid:
        x = m
        for lines, cw in zip(cells, widths):
            ly = y + pad
            for text, colour, kind in lines:
                if kind == "box":
                    d.rectangle([x + pad, ly + 6, x + pad + 34, ly + 40], outline=INK, width=3)
                    d.text((x + pad + 54, ly), text, font=f_cell, fill=colour)
                else:
                    d.text((x + pad, ly), text, font=f_cell, fill=colour)
                ly += lh
            x += cw
        y += rh
        d.line([m, y, w - m, y], fill=RULE, width=2)
    img.save(out)
    return out


def peoples_table(out):
    rows = []
    for p in load("peoples.json", "peoples"):
        ours = p.get("proposal_fields", [])
        title_from = "from your sheet"
        if "title" in ours:
            # The plan corrects two sheet titles (D02: Stone Children are not Mountain Folk); the rest have no single
            # sheet to read a title from yet.
            title_from = "our correction" if p["src"][0] in ("P03", "P04") else "our placeholder (no single sheet yet)"
        vi = [(o, INK, "box") for o in p["vi_candidates"]["options"]] + [("other: ____________", SOFT, "box")]
        rows.append([
            [(p["name"]["text"], INK, "text")],
            [(p["title"]["text"], OURS if "title" in ours else INK, "text")],
            vi,
            [("Title: " + title_from, OURS if "title" in ours else SOFT, "text"),
             ("Vietnamese: your pick (shown as \"pending\" until then)", SOFT, "text")],
        ])
    return table(
        out, "Thủy Vân: the peoples' names",
        ["English names come first in the game, with the English title beside them. Tick the Vietnamese name you want "
         "for each people, or write your own; a native speaker should check them. Until you pick, the game shows the "
         "English name only.",
         "Red text is our suggestion, not yours: say no to any of it."],
        ["English name", "English title", "Vietnamese (tick one)", "Where it came from"],
        [420, 760, 600, 680], rows)


def places_table(out):
    rows = []
    for p in load("atlas.json", "places"):
        ours = p.get("proposal_fields", [])
        no_vi = p.get("vi_name") is None and p["src"][0] != "L07"
        if not ours and not no_vi:
            continue
        shown = [(p["title"]["text"], OURS if "title" in ours else INK, "text")]
        if "book1_label" in p:
            shown.append(("in Book I: " + p["book1_label"]["text"], OURS if "book1_label" in ours else INK, "text"))
        vi = [(p["vi_name"], INK, "text")] if p.get("vi_name") else [("none yet: ____________", SOFT, "box")]
        why = []
        if "title" in ours:
            why.append(("Title: our placeholder", OURS, "text"))
        if "book1_label" in ours:
            why.append(("Its name belongs to Book II; Book I label is our placeholder", OURS, "text"))
        if no_vi:
            why.append(("No Vietnamese name yet", SOFT, "text"))
        rows.append([[(p["name"]["text"], INK, "text")], shown, vi, why])
    return table(
        out, "Thủy Vân: place names waiting on you",
        ["Only the places with a placeholder title or no Vietnamese name are listed. Red text is our placeholder: keep "
         "it, change it, or write your own. The nine Sacred Rivers are not listed: they wait for your names."],
        ["Place", "English title as shown", "Vietnamese name", "What is ours"],
        [520, 820, 560, 560], rows)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--out-dir", default=".")
    args = ap.parse_args(argv)
    os.makedirs(args.out_dir, exist_ok=True)
    print(peoples_table(os.path.join(args.out_dir, "names_table_peoples.png")))
    print(places_table(os.path.join(args.out_dir, "names_table_places.png")))


if __name__ == "__main__":
    main()
