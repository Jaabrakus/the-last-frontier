#!/usr/bin/env python3
"""Draws Thủy Vân's route graph from data/thuyvan (atlas.json, routes.json, calendar.json) for internal review:

    python3 tools/thuyvan/route_graph.py --out route_graph.png

Each place is a node (its Book I label and bible id; places first shown in a later book dashed and grey). Each route is
an edge with its ordinary / disrupted windows in bible days, the same in game hours (ThuyVanCanon.travel_hours's rule),
and its gates. The node positions are a rough topology from the bible's situation lines, not a map: distances are the
windows. Uses system fonts only (no downloads).
"""

import argparse
import json
import math
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
DATA = os.path.join(REPO, "data", "thuyvan")
FONT_PATHS = ["/System/Library/Fonts/Supplemental/Arial Unicode.ttf", "/Library/Fonts/Arial Unicode.ttf",
              "/System/Library/Fonts/Supplemental/Arial.ttf"]
BOLD_PATHS = ["/System/Library/Fonts/Supplemental/Arial Bold.ttf"] + FONT_PATHS

# Rough topology (fractions of the canvas, north up): the highlands north-west, the delta east, the marshes south.
LAYOUT = {
    "truong_son": (0.18, 0.08), "da_trang": (0.45, 0.12), "buried_kingdom": (0.84, 0.06), "two_heights": (0.22, 0.32),
    "ancestor_roads": (0.68, 0.20), "thach_uyen": (0.12, 0.52), "lam_uyen": (0.10, 0.80), "ao_thanh": (0.33, 0.62),
    "van_thuy": (0.63, 0.50), "cuu_giang": (0.86, 0.36), "deep_lotus": (0.47, 0.74), "reed_marches": (0.70, 0.90),
    "khar_ul": (0.36, 0.96), "southern_delta": (0.86, 0.68), "fishing_coast": (0.90, 0.90),
}
GATE_WORDS = {"pilot": "pilot", "licence": "licence", "open_lock": "open locks", "season": "season",
              "invitation": "invitation", "grove_leave": "grove leave"}


def font(paths, size):
    for p in paths:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def load(name, key):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)[key]


def label(place, book=1):
    if place.get("name_book", 1) > book and "book1_label" in place:
        return place["book1_label"]["text"]
    return place["name"]["text"]


def dashed_ellipse(d, box, color, width=3, dash=10):
    x0, y0, x1, y1 = box
    cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    steps = 72
    for i in range(0, steps, 2):
        a0, a1 = 2 * math.pi * i / steps, 2 * math.pi * (i + 1) / steps
        d.line([(cx + rx * math.cos(a0), cy + ry * math.sin(a0)), (cx + rx * math.cos(a1), cy + ry * math.sin(a1))],
               fill=color, width=width)


def draw(out, w=1800, h=1250):
    places = {p["id"]: p for p in load("atlas.json", "places")}
    routes = load("routes.json", "routes")
    cal = {r["id"]: r for r in load("calendar.json", "calendar")}
    hpd = cal["day_scale"]["game_hours_per_day"]
    img = Image.new("RGB", (w, h), (246, 241, 230))
    d = ImageDraw.Draw(img)
    f_title, f_node, f_id, f_edge = font(BOLD_PATHS, 34), font(BOLD_PATHS, 22), font(FONT_PATHS, 17), font(FONT_PATHS, 17)
    m = 90

    def pos(pid):
        fx, fy = LAYOUT.get(pid, (0.5, 0.5))
        return m + fx * (w - 2 * m), m + 30 + fy * (h - 2 * m - 60)

    d.text((m, 24), "Thủy Vân route graph (internal; from data/thuyvan; 1 bible day = %.1f game hours)" % hpd,
           font=f_title, fill=(40, 34, 28))
    for r in routes:
        (x0, y0), (x1, y1) = pos(r["from"]), pos(r["to"])
        gated = bool(r["gates"])
        d.line([(x0, y0), (x1, y1)], fill=(150, 90, 40) if gated else (90, 110, 130), width=5 if gated else 4)
    for r in routes:
        (x0, y0), (x1, y1) = pos(r["from"]), pos(r["to"])
        o, z = r["ordinary_days"], r["disrupted_days"]
        lines = ["%d–%d d  (%d–%d d disrupted)" % (o[0], o[1], z[0], z[1]),
                 "%g–%g h  /  %g–%g h" % (round(o[0] * hpd, 1), round(o[1] * hpd, 1), round(z[0] * hpd, 1), round(z[1] * hpd, 1))]
        if "return_ordinary_days" in r:
            b = r["return_ordinary_days"]
            lines.append("back: %d–%d d" % (b[0], b[1]))
        if r["gates"]:
            lines.append("gate: " + ", ".join(GATE_WORDS.get(g, g) for g in r["gates"]))
        lines.insert(0, r["method"]["text"])
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        tw = max(d.textlength(s, font=f_edge) for s in lines)
        th = 21 * len(lines)
        d.rectangle([mx - tw / 2 - 6, my - th / 2 - 4, mx + tw / 2 + 6, my + th / 2 + 4], fill=(255, 252, 244),
                    outline=(200, 190, 170))
        for i, s in enumerate(lines):
            col = (40, 34, 28) if i else (110, 60, 20)
            d.text((mx - d.textlength(s, font=f_edge) / 2, my - th / 2 + i * 21), s, font=f_edge, fill=col)
    for pid, p in places.items():
        x, y = pos(pid)
        name = label(p)
        later = p.get("reveal_book", 1) > 1
        tw = max(d.textlength(name, font=f_node), 60)
        box = [x - tw / 2 - 26, y - 38, x + tw / 2 + 26, y + 38]
        if later:
            d.ellipse(box, fill=(232, 230, 226))
            dashed_ellipse(d, box, (150, 150, 150))
        else:
            d.ellipse(box, fill=(255, 255, 255), outline=(60, 80, 70), width=3)
        col = (130, 130, 130) if later else (30, 50, 40)
        d.text((x, y - 10), name, font=f_node, fill=col, anchor="mm")
        sub = p["src"][0] + ("  (Book %d)" % p["reveal_book"] if later else "")
        if p.get("name_book", 1) > 1:
            sub += "  Book I label"
        d.text((x, y + 17), sub, font=f_id, fill=col, anchor="mm")
    legend = ["brown edge: the journey has a gate;  blue: none.  Dashed node: first shown in a later book.",
              "No L15 (and no L14 to L15 route): neither ships in data. Positions are topology only."]
    for i, s in enumerate(legend):
        d.text((m, h - 64 + i * 24), s, font=f_id, fill=(70, 60, 50))
    img.save(out)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--out", default="route_graph.png")
    args = ap.parse_args(argv)
    print(draw(args.out))


if __name__ == "__main__":
    main()
