"""The owner's review pages for the traits (PIL only): each Blender render set beside the matching crops of his own
sheets, every image captioned (what it shows, the triangle count, the choice it asks for).

    python3 tools/thuyvan_art/traits/compose_pages.py <renders dir> <pages dir>

The sheet crops are for review only (the sheets are the owner's; no sheet pixel goes into a game texture).
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SHEETS = "/Users/kiwimango/Downloads/New Folder With Items/"
LINEUP = "image-gen-1(1).png"
SERIF = "/System/Library/Fonts/Supplemental/Georgia.ttf"
SERIF_B = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
SANS = "/System/Library/Fonts/HelveticaNeue.ttc"
BG = (240, 233, 221)
INK = (40, 32, 26)
RED = (150, 40, 30)
GREY = (110, 100, 92)

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import prep_traits as PT  # noqa: E402

# the people's figure on the Common Folk lineup (make_pages' boxes) and a detail crop of the trait on their sheets
CROPS = {
    "dragon_sea": [(LINEUP, (0, 95, 300, 670), "Lineup: Dragon-Sea"), ("image-gen-1.png", (728, 120, 1020, 358), "Scales on cheekbone and temple; reflective eyes"),
                   ("image-gen-1.png", (728, 755, 1020, 1000), "Scales on the shoulder")],
    "mountain_folk": [(LINEUP, (265, 95, 535, 670), "Lineup: Mountain Folk"), ("image-gen-2.png", (728, 120, 1020, 345), "Tattoos (W1; no body trait)")],
    "stone_children": [(LINEUP, (510, 95, 770, 670), "Lineup: Stone Children"), (LINEUP, (560, 150, 760, 400), "Plates: shoulders, arms, face")],
    "ho_tinh": [(LINEUP, (730, 95, 1024, 670), "Lineup: Hồ Tinh"), (LINEUP, (800, 100, 960, 260), "Fox ears")],
    "riverborn": [(LINEUP, (225, 720, 525, 1230), "Lineup: Riverborn"), ("image-gen-6.png", (728, 120, 1020, 362), "Blue-grey skin, gills, fin ear")],
    "ancestor_bound": [(LINEUP, (755, 720, 1024, 1230), "Lineup: Ancestor-Bound"), ("image-gen-8.png", (140, 105, 755, 1085), "People's sheet: rite dress")],
}


def font(sz, kind="sans", bold=False):
    if kind == "serif":
        return ImageFont.truetype(SERIF_B if bold else SERIF, sz)
    return ImageFont.truetype(SANS, sz, index=1 if bold else 0)


def crop(file, box):
    return Image.open(os.path.join(SHEETS, file)).convert("RGB").crop(box)


def fit(im, w, h):
    s = min(w / im.width, h / im.height)
    return im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)


def wrap(d, text, f, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=f) > width and cur:
            lines.append(cur)
            cur = w
        else:
            cur = t
    if cur:
        lines.append(cur)
    return lines


def text(d, xy, s, f, fill=INK, width=None, gap=4):
    x, y = xy
    for line in (wrap(d, s, f, width) if width else [s]):
        d.text((x, y), line, font=f, fill=fill)
        y += f.size + gap
    return y


def header(d, W, title, sub):
    d.text((40, 26), title, font=font(46, "serif"), fill=INK)
    tw = d.textlength(title, font=font(46, "serif"))
    d.text((40 + tw + 18, 44), sub, font=font(24, "serif"), fill=GREY)
    d.line((40, 92, W - 40, 92), fill=(120, 110, 100), width=2)


def paste_captioned(page, d, im, x, y, w, h, cap, capf=None, sub=None):
    capf = capf or font(18)
    f = fit(im, w, h)
    page.paste(f, (x + (w - f.width) // 2, y))
    yy = y + f.height + 6
    yy = text(d, (x, yy), cap, capf, INK, width=w)
    if sub:
        yy = text(d, (x, yy), sub, font(15), GREY, width=w)
    return yy


def stats(renders, scene):
    p = os.path.join(renders, "stats_%s.json" % scene)
    return json.load(open(p)) if os.path.exists(p) else {}


def lineup_pages(R, out):
    for sex, word in (("f", "body type 2"), ("m", "body type 1")):
        st = stats(R, "lineup_" + sex)
        for view, vname in (("front", "front"), ("34", "three-quarter"), ("back", "back")):
            src = os.path.join(R, "lineup_%s_%s.png" % (sex, view))
            if not os.path.exists(src):
                continue
            W, H = 2400, 1380
            page = Image.new("RGB", (W, H), BG)
            d = ImageDraw.Draw(page)
            header(d, W, "THE SIX PEOPLES' TRAITS", "on today's body, in the same neutral dress - %s, %s view" % (word, vname))
            ren = Image.open(src).convert("RGB")
            ren = fit(ren, 1800, 1013)
            page.paste(ren, (40, 110))
            # the sheet's figures, in the lineup's order, to the right
            x0, y0 = 1860, 110
            d.text((x0, y0), "The owner's Common Folk lineup", font=font(18, bold=True), fill=INK)
            for i, p in enumerate(PT.PEOPLE):
                c = CROPS[p["id"]][0]
                im = fit(crop(c[0], c[1]), 160, 300)
                xx = x0 + (i % 3) * 172
                yy = y0 + 30 + (i // 3) * 340
                page.paste(im, (xx, yy))
                d.text((xx, yy + im.height + 4), p["label"], font=font(14), fill=GREY)
            # captions under each figure (left to right as the figures stand)
            cw = 1800 // 6
            yb = 110 + ren.height + 14
            for i, p in enumerate(PT.PEOPLE):
                x = 40 + i * cw
                y = text(d, (x, yb), p["label"], font(22, "serif", True), INK)
                y = text(d, (x, y), p["title"], font(15, "serif"), GREY)
                y = text(d, (x, y + 2), p["caption"], font(15), INK, width=cw - 16)
                pre = PT.PRESETS[p[sex]]
                y = text(d, (x, y + 2), "face: %s (melanin %.2f) - any face works" % (pre["label"], pre["melanin"]), font(13), GREY, width=cw - 16)
                tr = st.get("%s_%s" % (p["id"], sex))
                if tr:
                    text(d, (x, y + 2), "%d tris (body, face, hair, dress%s)" % (tr, ", ears, tails" if p["id"] == "ho_tinh" else ""), font(13), RED, width=cw - 16)
            text(d, (40, H - 60), "Blender Eevee, style guide 11 light (sun 40 deg front-left, sky 0.6, AgX). The skin is the game's painted-skin "
                                  "model baked per person; the marks are the new trait kinds 3-5 (tv_traits.gdshaderinc). Neutral dress so only "
                                  "the body differs. Every face, tone and hair in the creator stays open to every people.", font(15), GREY, width=W - 80)
            page.save(os.path.join(out, "lineup_%s_%s.png" % (sex, view)))


def bust_pages(R, out):
    for sex, word in (("f", "body type 2"), ("m", "body type 1")):
        W, H = 2600, 1700
        page = Image.new("RGB", (W, H), BG)
        d = ImageDraw.Draw(page)
        header(d, W, "THE TRAITS UP CLOSE", "%s: front and three-quarter, the owner's sheet beside each" % word)
        cw = (W - 80) // 6
        for i, p in enumerate(PT.PEOPLE):
            x = 40 + i * cw
            y = 110
            for kind in ("bust", "bust34"):
                src = os.path.join(R, "bust", "%s_%s_%s.png" % (kind, p["id"], sex))
                if os.path.exists(src):
                    im = fit(Image.open(src).convert("RGB"), cw - 12, 520)
                    page.paste(im, (x, y))
                    y += im.height + 6
            gl = os.path.join(R, "bust", "gills_riverborn_%s.png" % sex)
            if p["id"] == "riverborn" and os.path.exists(gl):
                im = fit(Image.open(gl).convert("RGB"), cw - 12, 300)
                page.paste(im, (x, y))
                y = text(d, (x, y + im.height + 2), "The gills, from the side (painted slits, lit lip)", font(13), GREY, width=cw - 16)
            c = CROPS[p["id"]][1] if len(CROPS[p["id"]]) > 1 else CROPS[p["id"]][0]
            im = fit(crop(c[0], c[1]), cw - 12, 250 if p["id"] != "riverborn" else 160)
            page.paste(im, (x, y + 4))
            y += im.height + 10
            y = text(d, (x, y), "Sheet: " + c[2], font(13), GREY, width=cw - 16)
            y = text(d, (x, y + 4), p["label"], font(22, "serif", True), INK)
            text(d, (x, y), p["caption"], font(14), INK, width=cw - 16)
        page.save(os.path.join(out, "busts_%s.png" % sex))


VARIANT_TEXT = {
    "ds_amount": ("DRAGON-SEA SCALES: THE AMOUNT ROW", "None / Wrists / Marked / Heavy, sea-teal. Most commoners None or Wrists; no row is tied to rank.",
                  ["none", "wrists", "marked", "heavy"], "dragon_sea"),
    "ds_tone": ("DRAGON-SEA SCALES: THE TONE ROW", "At Heavy: sea-teal (default) / silver / gold / jade; the sheen turns teal -> violet -> gold with the view.",
                ["sea_teal", "silver", "gold", "jade"], "dragon_sea"),
    "sc_amount": ("STONE CHILDREN PLATES: THE AMOUNT ROW", "Patches 0.3 / Half 0.6 / Most 0.9 (the lineup's), slate; whole plates appear, never lips, lids, palms, inner elbows.",
                  ["patches", "half", "most"], "stone_children"),
    "sc_tone": ("STONE CHILDREN PLATES: THE TONE ROW", "At Most: slate (default) / sandstone / granite / jade-veined / ochre (owner question 4).",
                ["slate", "sandstone", "granite", "jade_veined", "ochre"], "stone_children"),
    "rb_tint": ("RIVERBORN: THE WATER TINT OVER EVERY SKIN", "Rows: a light, a mid and a deep tone; columns: tint 0.3 / 0.75 (default) / 1.0. Every face and skin stays (owner question 3).",
                ["light_30", "light_75", "light_100", "mid_30", "mid_75", "mid_100", "deep_30", "deep_75", "deep_100"], "riverborn"),
    "ab_ash": ("ANCESTOR-BOUND: THE RITE'S ASH (A MARKING ANYONE MAY WEAR)", "None / thumbprint / the rite (thumbprint, cheek fingers, backs of the hands), on a light and a deep skin.",
               ["none", "thumbprint", "rite", "deep_none", "deep_thumbprint", "deep_rite"], "ancestor_bound"),
    "ht_ears": ("HỒ TINH EARS: SHAPES AND SHAPE KEYS", "Pointed (cream) / rounded (russet) / tufted (silver-white) / pointed with ear_back / pointed with ear_flat (under a hat).",
                ["pointed", "rounded", "tufted", "pointed_back", "pointed_flat"], "ho_tinh"),
    "eyes_night": ("REFLECTIVE EYES AT NIGHT", "Dragon-Sea (green-gold) off / strong, Riverborn (gold) off / strong; by day only the iris rim lifts 10 %.",
                   ["ds_off", "ds_strong", "rb_off", "rb_strong"], "dragon_sea"),
}


def variant_pages(R, out):
    V = os.path.join(R, "variants")
    for key, (title, sub, labels, pid) in VARIANT_TEXT.items():
        files = [os.path.join(V, key, l + ".png") for l in labels]
        if not any(os.path.exists(f) for f in files):
            continue
        n = len(labels)
        cols = 3 if n == 9 else n
        rows = (n + cols - 1) // cols
        W = 2600
        cw = (W - 80 - 360) // cols
        ch = int(cw * 1080 / 960) if rows == 1 else 470
        H = 160 + rows * (ch + 70) + 60
        full = os.path.join(V, key, "full.png")
        if os.path.exists(full):
            H += 760
        page = Image.new("RGB", (W, max(H, 1100)), BG)
        d = ImageDraw.Draw(page)
        header(d, W, title, "")
        text(d, (40, 100), sub, font(20), INK, width=W - 480)
        # the sheet on the right
        cy = 110
        for c in CROPS[pid][:2]:
            im = fit(crop(c[0], c[1]), 340, 440)
            page.paste(im, (W - 380, cy))
            cy = text(d, (W - 380, cy + im.height + 4), "Sheet: " + c[2], font(13), GREY, width=340) + 12
        for i, (l, f) in enumerate(zip(labels, files)):
            x = 40 + (i % cols) * cw
            y = 150 + (i // cols) * (ch + 70)
            if os.path.exists(f):
                im = fit(Image.open(f).convert("RGB"), cw - 12, ch)
                page.paste(im, (x, y))
                text(d, (x, y + im.height + 4), l.replace("_", " "), font(20, "serif", True), INK)
        if os.path.exists(full):
            y = 150 + rows * (ch + 70)
            im = fit(Image.open(full).convert("RGB"), W - 480, 720)
            page.paste(im, (40, y))
            text(d, (40, y + im.height + 4), "Full figures, left to right as above.", font(15), GREY)
        page.save(os.path.join(out, "variants_%s.png" % key))


def tails_page(R, out):
    V = os.path.join(R, "variants", "ht_tails")
    if not os.path.exists(os.path.join(V, "back34.png")):
        return
    st = stats(R, "ht_tails")
    W, H = 2600, 1700
    page = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(page)
    header(d, W, "HỒ TINH TAILS", "1, 3 and 9 tails on their own bones, in the fur colours; a free cosmetic, never a stat")
    im = fit(Image.open(os.path.join(V, "back34.png")).convert("RGB"), 1700, 960)
    page.paste(im, (40, 110))
    labels = ["1 tail, cream", "3 tails, russet", "9 tails, cream", "9 tails, silver-white", "9 tails, black-tipped"]
    keys = ["t1_cream", "t3_russet", "t9_cream", "t9_silver", "t9_black_tipped"]
    for i, (l, k) in enumerate(zip(labels, keys)):
        x = 40 + i * 340
        y = text(d, (x, 110 + im.height + 6), l, font(20, "serif", True), INK)
        if st.get(k):
            text(d, (x, y), "%d tris with body, dress, ears" % st[k], font(13), RED)
    y2 = 110 + im.height + 80
    for j, nm in enumerate(("front", "side")):
        p = os.path.join(V, nm + ".png")
        if os.path.exists(p):
            im2 = fit(Image.open(p).convert("RGB"), 840, 480)
            page.paste(im2, (40 + j * 870, y2))
            text(d, (40 + j * 870, y2 + im2.height + 4), "The same, from the " + nm, font(15), GREY)
    c = CROPS["ho_tinh"][0]
    sc = fit(crop(c[0], c[1]), 760, 1300)
    page.paste(sc, (W - 800, 110))
    y = text(d, (W - 800, 110 + sc.height + 6), "Sheet: the Common Folk lineup's Hồ Tinh (many cream tails, white tips)", font(15), GREY, width=760)
    text(d, (W - 800, y + 10), "How they sit with garments: the tails root 2 cm off the skin at the sacrum, above the trouser band; a "
                               "lower garment opens the new tail_root hide region (a back slit), shown here cut into the neutral tunic. "
                               "A hat that hides the hair crown sets the ears' ear_flat key; a hood sets ear_back.", font(15), INK, width=760)
    page.save(os.path.join(out, "tails_ho_tinh.png"))


def main():
    R, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    lineup_pages(R, out)
    bust_pages(R, out)
    variant_pages(R, out)
    tails_page(R, out)
    print("PAGES", sorted(f for f in os.listdir(out) if f.endswith(".png")))


if __name__ == "__main__":
    main()
