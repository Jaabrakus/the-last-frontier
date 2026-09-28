#!/usr/bin/env python3
"""Compose render_compare.gd frames into one labelled grid per group (PIL).

  python3 tools/retarget/compose_grid.py <frames dir> <jobs.json> <out dir> [report.json]
Rows = clips, columns = sampled frames. With a report (retarget.py --report) each row
label carries the clip's path r2 / foot-slide numbers.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CROPS = {"default": (60, 110, 790, 560), "crawl": (110, 110, 830, 560), "horse": (90, 50, 810, 590),
         "horsenative": (60, 60, 880, 590)}
LEGEND = {False: "orange = Actor_A source clip (true bind pose as rest)   blue = Actor_B retarget",
          True: "orange = Actor_A source   blue = Actor_B retarget   green = Actor_B native clip of the same motion (validation)"}


def font(size):
    for p in ("/System/Library/Fonts/Helvetica.ttc", "/System/Library/Fonts/SFNS.ttf"):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    frames, jobs, out = Path(sys.argv[1]), json.load(open(sys.argv[2])), Path(sys.argv[3])
    rep = json.load(open(sys.argv[4]))["clips"] if len(sys.argv) > 4 else {}
    out.mkdir(parents=True, exist_ok=True)
    f_title, f_lab = font(26), font(17)
    for job in jobs:
        g = job["group"]
        crop = tuple(job["crop"]) if "crop" in job else CROPS.get(g, CROPS["default"])
        sc = float(job.get("scale", 0.5))
        cw, ch = int((crop[2] - crop[0]) * sc), int((crop[3] - crop[1]) * sc)
        n = job.get("frames", 5)
        rows = job["clips"]
        W = 20 + n * (cw + 6)
        H = 70 + len(rows) * (ch + 40) + 10
        img = Image.new("RGB", (W, H), (250, 250, 247))
        d = ImageDraw.Draw(img)
        d.text((20, 12), job.get("title", f"{g}: Actor_A -> Actor_B retarget prototype"), fill=(20, 20, 20), font=f_title)
        d.text((20, 44), job.get("legend", LEGEND["native" in job]), fill=(70, 70, 70), font=f_lab)
        for r, clip in enumerate(rows):
            y0 = 70 + r * (ch + 40)
            lab = clip
            m = rep.get(clip, {})
            if "path_dynamic" in m:
                fs = m["foot_slide_mps"]
                lab += f"   path r2 {m['path_dynamic']['r2']:.3f}, dyn RMS {m['path_dynamic']['rms_cm_median']} cm," \
                       f" vel cos {m.get('vel_cos')}, planted-foot slide A {fs['A_scaled']['median']} / B {fs['B_ik']['median']} m/s"
            d.text((20, y0 + 4), lab, fill=(20, 20, 20), font=f_lab)
            for i in range(n):
                p = frames / f"{g}__{clip.replace('^', '_')}__{i}.png"
                if not p.exists():
                    continue
                im = Image.open(p).convert("RGB").crop(crop).resize((cw, ch), Image.LANCZOS)
                img.paste(im, (20 + i * (cw + 6), y0 + 28))
        dst = out / (job.get("prefix", "retarget_") + f"{g}.png")
        img.save(dst, optimize=True)
        print(dst, img.size)


if __name__ == "__main__":
    main()
