"""Step 4 (plain python3 + PIL): the captioned 1920 x 1080 review sheets from render_bodies.py's tiles, beside the
owner's sheet crops (reference only, never game art).

    python3 compose.py RENDER_DIR REF_DIR OUT_DIR
"""

import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

PAPER = (236, 228, 212)
INK = (40, 34, 28)
SOFT = (110, 100, 88)
W, H = 1920, 1080
FONT_DIR = "/System/Library/Fonts/Supplemental"
RDIR = [""]


def rpath(p):
    """A render's path, found in the render folder given on the command line (the json may have been moved)."""
    q = os.path.join(RDIR[0], os.path.basename(p))
    return q if os.path.exists(q) else p


def font(size, bold=False):
    for name in (("Georgia Bold.ttf" if bold else "Georgia.ttf"), "Charter.ttc"):
        p = os.path.join(FONT_DIR, name)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def fit(im, w, h):
    s = min(w / im.width, h / im.height)
    return im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)


def header(d, title, sub):
    d.text((28, 14), title, font=font(30, True), fill=INK)
    d.text((30, 52), sub, font=font(16), fill=SOFT)


def footer(d, lines, y0=1004):
    for i, ln in enumerate(lines):
        d.text((30, y0 + i * 22), ln, font=font(16), fill=INK if i == 0 else SOFT)


def ref_panel(img, refs, x, y, w, h, caption="The owner's sheets (reference only, never game art)"):
    d = ImageDraw.Draw(img)
    n = len(refs)
    each = (h - 30) // n
    for i, r in enumerate(refs):
        im = fit(Image.open(r).convert("RGB"), w, each - 8)
        img.paste(im, (x + (w - im.width) // 2, y + i * each))
    d.text((x, y + h - 22), caption, font=font(13), fill=SOFT)


def tri_line(tris):
    tot = sum(tris.values())
    parts = []
    import re
    for k, v in sorted(tris.items(), key=lambda kv: -kv[1]):
        short = re.sub(r"^.*?_[ABC]_\d_", "", k).replace("_", " ")
        parts.append("%s %s" % (short, f"{v:,}"))
    return "%s tris (%s)" % (f"{tot:,}", ", ".join(parts[:5]))


def label(d, xy, text, sub=None):
    f = font(17, True)
    tw = d.textlength(text, font=f)
    bw = max(tw, d.textlength(sub, font=font(13)) if sub else 0)
    x, y = xy
    d.rounded_rectangle((x - bw / 2 - 8, y - 2, x + bw / 2 + 8, y + 24 + (20 if sub else 0)), 6, fill=(250, 246, 236))
    d.text((x - tw / 2, y), text, font=f, fill=INK)
    if sub:
        f2 = font(13)
        sw = d.textlength(sub, font=f2)
        d.text((x - sw / 2, y + 22), sub, font=f2, fill=SOFT)


def lineup_sheet(meta, shot, refs, title, sub, names, notes, out, panel_w=420, render_box=(420, 74, 1500, 930)):
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    header(d, title, sub)
    m = meta[shot]
    r = Image.open(rpath(m["path"])).convert("RGB")
    bx, by, bw, bh = render_box
    r = fit(r, bw, bh)
    img.paste(r, (bx, by))
    ref_panel(img, refs, 12, by, panel_w - 24, bh)
    for fig, (u, v) in m["labels"].items():
        if fig in names:
            t, s = names[fig]
            label(d, (bx + u * r.width, min(by + v * r.height + 6, by + r.height - 52)), t, s)
    footer(d, notes)
    img.save(out)
    return out


def sil_inset(path, h=64):
    im = Image.open(path).convert("RGBA")
    a = np.array(im)[..., 3]
    ys, xs = np.nonzero(a > 40)
    if len(xs) == 0:
        return None
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    m = Image.fromarray((255 - (a > 110).astype(np.uint8) * 255).astype(np.uint8))
    s = h / m.height
    m = m.resize((max(1, int(m.width * s)), h), Image.LANCZOS)
    m = m.point(lambda v: 0 if v < 128 else 255)
    return m


def turnaround_sheet(meta, shots, refs, title, sub, notes, out, row_labels=()):
    """One row of tiles per shot (body type 2, body type 1), all at one scale, each tile with its 64 px
    silhouette."""
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    header(d, title, sub)
    shots = [sh for sh in shots if sh in meta]
    rows = [[(Image.open(rpath(t["path"])).convert("RGB"), t) for t in meta[sh]["tiles"]] for sh in shots]
    panel, gap, top = 300, 8, 84
    foot = 26 * (len(notes) + len(shots)) + 16
    avail_w, avail_h = W - panel - 20, 1080 - top - foot
    th = max(t.height for row in rows for t, _ in row)
    s = min(min(avail_w / (sum(t.width for t, _ in row) + gap * (len(row) - 1)) for row in rows),
            (avail_h - gap * (len(rows) - 1)) / (th * len(rows)))
    y = top
    max_rw = max(sum(int(t.width * s) for t, _ in row) + gap * (len(row) - 1) for row in rows)
    panel = int(max(300, min(560, W - max_rw - 40)))      # the sheet crops take the room the tiles leave
    avail_w = W - panel - 20
    for ri, row in enumerate(rows):
        rw = sum(int(t.width * s) for t, _ in row) + gap * (len(row) - 1)
        x = panel + 10 + (avail_w - rw) // 2
        for t, rec in row:
            tt = t.resize((int(t.width * s), int(t.height * s)), Image.LANCZOS)
            img.paste(tt, (x, y))
            d.text((x + 8, y + 6), rec["view"], font=font(16, True), fill=INK)
            if row_labels and rec["view"].endswith("human"):
                d.rectangle((x, y + tt.height - 34, x + tt.width, y + tt.height), fill=(250, 246, 236))
                d.text((x + 6, y + tt.height - 30), row_labels[ri].split(" (")[0], font=font(15, True), fill=INK)
                d.text((x + 6, y + tt.height - 14), "(" + row_labels[ri].split(" (")[1] if " (" in row_labels[ri] else "",
                       font=font(11), fill=SOFT)
            if rec.get("sil"):
                si = sil_inset(rpath(rec["sil"]))
                if si is not None:
                    bxx, byy = x + tt.width - si.width - 12, y + tt.height - si.height - 28
                    d.rectangle((bxx - 6, byy - 6, bxx + si.width + 6, byy + si.height + 22), fill=(255, 255, 255))
                    img.paste(si, (bxx, byy))
                    d.text((bxx - 2, byy + si.height + 3), "64 px", font=font(12), fill=SOFT)
            x += tt.width + gap
        y += int(th * s) + gap
    ref_panel(img, refs, 12, top, panel - 24, y - top - gap)
    lines = [notes[0]] + ["%s: %s" % (row_labels[k] if row_labels else shots[k], tri_line(meta[sh]["tris"]))
                          for k, sh in enumerate(shots)] + notes[1:]
    footer(d, lines, y0=1080 - 26 * len(lines) - 6)
    img.save(out)
    return out


def main(rdir, refdir, outdir):
    os.makedirs(outdir, exist_ok=True)
    RDIR[0] = rdir
    REF = {"fb": [os.path.join(refdir, "fb_sheet_figure.png"), os.path.join(refdir, "cf_floodborn.png")],
           "mt": [os.path.join(refdir, "cf_moc_tinh.png")]}
    made = []
    for kit, key in (("floodborn", "fb"), ("moc_tinh", "mt")):
        for paint in ("", "_paint"):
            p = os.path.join(rdir, "shots_%s%s.json" % (kit, paint))
            if not os.path.exists(p):
                continue
            meta = json.load(open(p))
            made += SHEETS[kit](meta, REF[key], outdir, bool(paint))
    print("\n".join(made))


# ===========================================================================
# The sheets' words
# ===========================================================================
HUMAN = {"human_0": ("Human, body type 2", "the creator's body, 1.60 m"),
         "human_1": ("Human, body type 1", "stature 1.07, 1.71 m")}


def floodborn_sheets(meta, refs, out, paint):
    made = []
    names = dict(HUMAN)
    names.update({"floodborn_A_0": ("A  Mooring Guard", "the sheet; the recommended base"),
                  "floodborn_B_0": ("B  Reed Runner", "long narrow snout, lean, tail carried"),
                  "floodborn_C_0": ("C  Old River Bull", "massive, blunt snout, shoulder plates"),
                  "floodborn_A_1": ("A, body type 1", "male fit at stature 1.07")})
    tris = lambda shot, f: tri_line(meta[shot]["tris"].get(f, {})) if shot in meta else ""  # noqa: E731
    if not paint:
        if "floodborn_variants_rest" in meta:
            made.append(lineup_sheet(meta, "floodborn_variants_rest", refs,
                                     "FLOODBORN  -  three grey-box bodies, rest pose",
                                     "Grey clay with painted AO, rigged on the Actor_B skeleton (291 bones) plus the tail chain and the snout / jaw markers. Body type 2 beside a human of the same height.",
                                     names,
                                     ["Rest = the bind pose null-add; the tail in its idle pose-layer target (A lies on the ground from tail_05, B is carried, C is carried low). Mid grey = parts on extension bones.",
                                      "Upright as modelled: the forward lean is the runtime posture overlay (see the action pose). Plantigrade feet on the human ankle, heel and ball. A: " + tris("floodborn_variants_rest", "floodborn_A_0")],
                                     os.path.join(out, "01_floodborn_variants_rest.png")))
        if "floodborn_variants_action" in meta:
            made.append(lineup_sheet(meta, "floodborn_variants_action", refs,
                                     "FLOODBORN  -  the same three bodies in a spear stance",
                                     "Spear upright in the right hand as on the sheet; the posture overlay on (A 8 deg, B 16 deg, C 12 deg lean, neck and head counter-rotated); the tail curled to the free side.",
                                     names,
                                     ["Every pose here is the human skeleton's: the legs and feet are untouched by the overlay, so every clip's foot contact stays exact. The tail and jaw are procedural (no clip keys them).",
                                      "B: " + tris("floodborn_variants_action", "floodborn_B_0") + "     C: " + tris("floodborn_variants_action", "floodborn_C_0")],
                                     os.path.join(out, "02_floodborn_variants_spear.png")))
        if "floodborn_A_turnaround_f" in meta:
            made.append(turnaround_sheet(meta, ["floodborn_A_turnaround_f", "floodborn_A_turnaround_m"], refs,
                                         "FLOODBORN A  -  turnaround, both body types",
                                         "Front, 3/4, side and back at one scale beside a 1.75 m human; the tail in its idle pose-layer target; each view with its 64 px flat-black silhouette.",
                                         ["Crest top about 1.66 m (type 2) and 1.78 m (type 1, stature 1.07); snout 30 cm eye to tip; shoulders 0.52 / 0.60 m; feet 34 cm, four clawed toes; tail 1.45 m.",
                                          "Geometry scutes: a two-row dorsal ridge, shoulder and forearm osteoderms, the serrated tail crest. Everything finer is paint."],
                                         os.path.join(out, "03_floodborn_A_turnaround.png"),
                                         row_labels=("body type 2 (stature 1.0)", "body type 1 (male fit, stature 1.07)")))
        if "floodborn_A_body_types" in meta:
            made.append(lineup_sheet(meta, "floodborn_A_body_types", refs,
                                     "FLOODBORN A  -  both body types beside humans of the same height",
                                     "Body type 2 (female base): narrower snout, slimmer neck, broader hips, finer scutes, no bust. Body type 1 (male fit, stature 1.07): broader snout and shoulders, a nasal boss, heavier jowls, bigger scutes.",
                                     names,
                                     ["Heights stay human (within +4 %): no capsule, camera, speed or aim change for any body.",
                                      "The exported grey-box glb carries `sex` as a morph target (projected onto the male fit), as every other part does."],
                                     os.path.join(out, "05_floodborn_A_body_types.png")))
    else:
        if "floodborn_A_painted_action" in meta:
            made.append(lineup_sheet(meta, "floodborn_A_painted_action", refs,
                                     "FLOODBORN A  -  first paint pass (where the look is going)",
                                     "Hand-painted scutes in 3-5 tones (no photo grain), the cream belly ramp, a teal cast on olive, river-gold slit eyes, bone claws and teeth, near-black quills; smooth light, no cel shading, no outlines.",
                                     names,
                                     ["Hide ramps from the design: ventral #d9cfb0 / #b9ad8a, dorsal #2f3b2c / #3e4f3a / #5b6b4a, teal #3e5a52, seams #1e2620; eyes #e0b030; claws and teeth #cfc4a6.",
                                      "Not yet: the dress (net vest, reed and net armour, panels split round the tail), beads and the scar decals; those come with the cloth2 Floodborn set after approval."],
                                     os.path.join(out, "06_floodborn_A_painted.png")))
        if "floodborn_A_painted_close" in meta:
            made.append(close_sheet(meta, "floodborn_A_painted_close", "floodborn_A_painted_rest", refs,
                                    "FLOODBORN A  -  the paint up close", os.path.join(out, "07_floodborn_A_painted_close.png")))
    return made


def moc_sheets(meta, refs, out, paint):
    made = []
    names = dict(HUMAN)
    names.update({"moc_tinh_A_0": ("A  Grove-Tender", "the sheet; the recommended base"),
                  "moc_tinh_B_0": ("B  Sapling Spire", "thinnest, gnarled branches (NPC 40 cm)"),
                  "moc_tinh_C_0": ("C  Moss-Cloak", "trunk-like, umbrella crown, moss mantle"),
                  "moc_tinh_A_1": ("A, body type 1", "male fit at stature 1.07")})
    tris = lambda shot, f: tri_line(meta[shot]["tris"].get(f, {})) if shot in meta else ""  # noqa: E731
    if not paint:
        if "moc_tinh_variants_rest" in meta:
            made.append(lineup_sheet(meta, "moc_tinh_variants_rest", refs,
                                     "MỘC TINH  -  three grey-box bodies, rest pose",
                                     "The creator's own body and head (so every face, skin and hair keeps working), reshaped, with bark plates, spurs, root feet, a crown, vines; rigged on Actor_B plus the crown and vine bones.",
                                     names,
                                     ["Limbs x0.82 (A), x0.72 (B), x0.95 (C); forearms and shins +5 %; height +1.2 %. The face is untouched except the leaf-pointed ear. Mid grey = parts on extension bones.",
                                      "A: " + tris("moc_tinh_variants_rest", "moc_tinh_A_0")],
                                     os.path.join(out, "11_moc_tinh_variants_rest.png")))
        if "moc_tinh_variants_action" in meta:
            made.append(lineup_sheet(meta, "moc_tinh_variants_action", refs,
                                     "MỘC TINH  -  the same three bodies with a walking staff",
                                     "The staff planted in the left hand as on the sheet; head tilted down, weight on one leg, a slight droop. Crown under the playable cap (A 22 cm; B's 40 cm branches are the NPC height).",
                                     names,
                                     ["Hanging vine ends hang on their bones (springs at runtime). Every pose is the human skeleton's: all clips play unchanged.",
                                      "B: " + tris("moc_tinh_variants_action", "moc_tinh_B_0") + "     C: " + tris("moc_tinh_variants_action", "moc_tinh_C_0")],
                                     os.path.join(out, "12_moc_tinh_variants_staff.png")))
        if "moc_tinh_A_turnaround_f" in meta:
            made.append(turnaround_sheet(meta, ["moc_tinh_A_turnaround_f", "moc_tinh_A_turnaround_m"], refs,
                                         "MỘC TINH A  -  turnaround, both body types",
                                         "Front, 3/4, side and back at one scale beside a 1.75 m human, each view with its 64 px flat-black silhouette.",
                                         ["Crown capped 22 cm above the head; roots spread 12 cm past the toes and 6 cm behind the heel; vines on both arms and the sash; the face untouched but the leaf ear.",
                                          "Bark relief here is geometry (raised plates 4-12 mm); the game part keeps the big plates and spurs and moves the rest into paint (the 6k budget)."],
                                         os.path.join(out, "13_moc_tinh_A_turnaround.png"),
                                         row_labels=("body type 2 (stature 1.0)", "body type 1 (stature 1.07)")))
        if "moc_tinh_A_body_types" in meta:
            made.append(lineup_sheet(meta, "moc_tinh_A_body_types", refs,
                                     "MỘC TINH A  -  both body types beside humans of the same height",
                                     "The human `sex` fit on the reshaped body: every face preset, `blink` and the face landmarks work as they are.",
                                     names,
                                     ["No hats: the head slot takes the crown. Loose human layers refit through the proportion bake; tight layers and all footwear are hidden.",
                                      ""],
                                     os.path.join(out, "15_moc_tinh_A_body_types.png")))
    else:
        if "moc_tinh_A_painted_action" in meta:
            made.append(lineup_sheet(meta, "moc_tinh_A_painted_action", refs,
                                     "MỘC TINH A  -  first paint pass (where the look is going)",
                                     "Pale grey-green bark painted in long vertical strokes, moss in the cracks and hollows, painted leaf-cluster cards (alpha scissor) over the crown puffs, white five-petal flowers, green-gold eyes.",
                                     names,
                                     ["Ramps: bark #a8a690 to #3a3226 (the skin_map's melanin range), moss and canopy from the Lâm Uyên palette, flowers #f2eedc. Smooth light, no cel shading, no outlines.",
                                      "Not yet: the bark-fibre hair variant, the mortal-given wrap and sash, tags and the basket; those come with the grove set after approval."],
                                     os.path.join(out, "16_moc_tinh_A_painted.png")))
        if "moc_tinh_A_painted_close" in meta:
            made.append(close_sheet(meta, "moc_tinh_A_painted_close", "moc_tinh_A_painted_rest", refs,
                                    "MỘC TINH A  -  the paint up close", os.path.join(out, "17_moc_tinh_A_painted_close.png")))
    return made


def close_sheet(meta, close, rest, refs, title, out):
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    header(d, title, "Head and shoulders (left) and the whole figure in its rest pose (right), the same paint, Eevee, the review light.")
    x = 12
    ref_panel(img, refs, x, 74, 330, 930)
    x = 360
    ims = [Image.open(rpath(meta[k]["path"])).convert("RGB") for k in (close, rest) if k in meta]
    tot = sum(i.width * 930 / i.height for i in ims) + 10 * (len(ims) - 1)
    s = min(1.0, (W - x - 10) / tot)
    for im in ims:
        r = im.resize((int(im.width * 930 / im.height * s), int(930 * s)), Image.LANCZOS)
        img.paste(r, (x, 74))
        x += r.width + 10
    img.save(out)
    return out


SHEETS = {"floodborn": floodborn_sheets, "moc_tinh": moc_sheets}

if __name__ == "__main__":
    main(*sys.argv[1:4])
