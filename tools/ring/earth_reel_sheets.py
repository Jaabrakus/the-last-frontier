#!/usr/bin/env python3
"""Before/after contact sheets of the earth move reel (tools/ring/move_reel.gd, only=earth): one image a move, the BEFORE take's
frames in the top row and the AFTER take's in the bottom row, the same moments of the same shot (the reel is deterministic: the
same moves cast through the same keys on the same deck and camera), for the owner's eye (the earth look, 2026-10-16).

    python3 tools/ring/earth_reel_sheets.py <before take dir> <after take dir> <out dir> [--cells 6] [--cell 480] [--fps 60]
        [--from 0.15] [--to 0.9] [--match substring]

Each take dir holds frames/f#####.jpg, frames.txt and shots.json as move_reel.gd writes them. A shot's frames are taken evenly
from `--from` to `--to` of its length. Writes <out>/<nn>_<label>.jpg and <out>/index.json.
"""
import argparse
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw


def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


def load(take):
    take = Path(take)
    rows = [int(l.split()[0]) for l in (take / "frames.txt").read_text().splitlines() if l.strip() and not l.startswith("#")]
    shots = json.loads((take / "shots.json").read_text())
    return take, rows, shots


def pick(take, rows, shot, fps, cells, f0, f1):
    i0, i1 = float(shot["t0"]) * fps, float(shot["t1"]) * fps
    out = []
    for c in range(cells):
        u = f0 + (f1 - f0) * c / max(cells - 1, 1)
        i = min(int(round(i0 + (i1 - i0) * u)), len(rows) - 1)
        out.append((take / "frames" / f"f{rows[i]:05d}.jpg", (i - i0) / fps))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("before")
    ap.add_argument("after")
    ap.add_argument("out")
    ap.add_argument("--cells", type=int, default=6)
    ap.add_argument("--cell", type=int, default=480)
    ap.add_argument("--fps", type=int, default=60)
    ap.add_argument("--from", dest="f0", type=float, default=0.15)
    ap.add_argument("--to", dest="f1", type=float, default=0.9)
    ap.add_argument("--match", default="")
    a = ap.parse_args()
    tb, rb, sb = load(a.before)
    ta, ra, sa = load(a.after)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    by_label = {s["label"]: s for s in sb}
    index = []
    for k, s in enumerate(sa):
        if a.match and a.match.lower() not in s["label"].lower():
            continue
        b = by_label.get(s["label"])
        if b is None:
            continue
        h = int(a.cell * 9 / 16)
        sheet = Image.new("RGB", (a.cell * a.cells, h * 2), (18, 18, 18))
        dr = ImageDraw.Draw(sheet)
        for row, (take, rows, shot, tag) in enumerate([(tb, rb, b, "BEFORE"), (ta, ra, s, "AFTER")]):
            for c, (f, t) in enumerate(pick(take, rows, shot, a.fps, a.cells, a.f0, a.f1)):
                try:
                    im = Image.open(f).convert("RGB").resize((a.cell, h))
                except OSError:
                    continue
                sheet.paste(im, (c * a.cell, row * h))
                dr.text((c * a.cell + 8, row * h + 6), f"{tag}  {t:.2f} s", fill=(255, 255, 255))
        name = "%02d_%s.jpg" % (k + 1, slug(s["label"].replace("▲", "grown")))
        sheet.save(out / name, quality=88)
        index.append({"label": s["label"], "key": s.get("key"), "file": name})
        print("sheet", name)
    (out / "index.json").write_text(json.dumps(index, indent=1))


if __name__ == "__main__":
    main()
