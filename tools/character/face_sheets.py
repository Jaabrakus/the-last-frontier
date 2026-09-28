"""Contact sheets of the face portraits (tools/character/face_portraits.gd output).

    python3 tools/character/face_sheets.py DIR [OUTDIR]

One sheet per people: rows = the presets found in DIR (peoples presets women A, B, men A, B;
stylized presets women s1.., men s1..), columns = views (front, three-quarter, profile), from
DIR/<preset>_<view>.png, each row labelled. Needs Pillow.
"""
import glob
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PEOPLES = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "character", "body", "peoples.json"))


def main():
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(src, "sheets")
    os.makedirs(dst, exist_ok=True)
    d = json.load(open(PEOPLES))
    views = ["front", "34", "side"]
    tile = 320
    n = 0
    for p in d["peoples"]:
        prs = [pr for pr in d["presets"] + d.get("stylized_presets", []) if pr["people"] == p["id"]]
        prs = [pr for pr in prs if any(os.path.exists(os.path.join(src, "%s_%s.png" % (pr["id"], v))) for v in views)]
        files = [[os.path.join(src, "%s_%s.png" % (pr["id"], v)) for v in views] for pr in prs]
        if not prs:
            continue
        sheet = Image.new("RGB", (tile * len(views), tile * len(prs) + 34), (24, 24, 26))
        dr = ImageDraw.Draw(sheet)
        dr.text((8, 8), "%s (%s)" % (p["label"], p["group"]), fill=(235, 235, 235))
        for r, row in enumerate(files):
            for c, f in enumerate(row):
                if os.path.exists(f):
                    im = Image.open(f).convert("RGB").resize((tile, tile), Image.LANCZOS)
                    sheet.paste(im, (c * tile, 34 + r * tile))
            if prs[r].get("showcase"):
                dr.text((tile * len(views) - 90, 34 + r * tile + 8), "showcase", fill=(235, 200, 120))
        sheet.save(os.path.join(dst, "sheet_%s.png" % p["id"]))
        n += 1
    # overview: a row per people, the front view of each of its presets found (showcase marked)
    rows = []
    for p in d["peoples"]:
        prs = [pr for pr in d["presets"] + d.get("stylized_presets", []) if pr["people"] == p["id"]
               and os.path.exists(os.path.join(src, "%s_front.png" % pr["id"]))]
        if prs:
            rows.append((p, prs))
    if rows:
        ot = 150
        cols = max(len(prs) for _, prs in rows)
        sheet = Image.new("RGB", (160 + ot * cols, ot * len(rows)), (24, 24, 26))
        dr = ImageDraw.Draw(sheet)
        for r, (p, prs) in enumerate(rows):
            dr.text((6, r * ot + ot // 2 - 6), p["label"][:24], fill=(235, 235, 235))
            for c, pr in enumerate(prs):
                im = Image.open(os.path.join(src, "%s_front.png" % pr["id"])).convert("RGB").resize((ot, ot), Image.LANCZOS)
                sheet.paste(im, (160 + c * ot, r * ot))
                if pr.get("showcase"):
                    dr.rectangle([160 + c * ot, r * ot, 160 + (c + 1) * ot - 1, (r + 1) * ot - 1], outline=(235, 200, 120))
        sheet.save(os.path.join(dst, "overview_front.png"))
        n += 1
    # hair sheet
    hair = sorted(glob.glob(os.path.join(src, "hair_*_34_hat.png")))
    if hair:
        cols = 4
        styles = [os.path.basename(h)[5:-11] for h in hair]
        sheet = Image.new("RGB", (tile * cols, tile * len(styles)), (24, 24, 26))
        for r, st in enumerate(styles):
            for c, (v, hat) in enumerate([("34", "hat"), ("back34", "hat"), ("34", "nohat"), ("back34", "nohat")]):
                f = os.path.join(src, "hair_%s_%s_%s.png" % (st, v, hat))
                if os.path.exists(f):
                    sheet.paste(Image.open(f).convert("RGB").resize((tile, tile), Image.LANCZOS), (c * tile, r * tile))
        sheet.save(os.path.join(dst, "sheet_hair.png"))
        n += 1
    print("%d sheets -> %s" % (n, dst))


if __name__ == "__main__":
    main()
