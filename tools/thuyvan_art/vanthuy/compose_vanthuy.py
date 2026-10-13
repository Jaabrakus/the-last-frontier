"""Compose the Vạn Thủy kit's review sheets from render_vanthuy.py's raw renders (plain Python + PIL):

    python3 tools/thuyvan_art/vanthuy/compose_vanthuy.py --dir REVIEW_DIR [--checks CHECK_DIR]

Every lineup page (raw/<page>.png + .json) gets a caption band and, under the render, a numbered table: each piece's
name, its triangles per LOD against places_se.md's budget, its material keys and its 64 px flat-black silhouette (the
style guide's silhouette test); numbers on the render mark which piece is which. The diorama renders get a caption
band each and a contact sheet (cameras x lights). textures.png shows every painted texture with its 3 x 3 tiling and
1/16 squint and its mean value. Labels use a system font (review sheets only; nothing here ships).
"""

import argparse
import glob
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FONT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
INK = (38, 34, 30)
SOFT = (110, 100, 90)
RED = (150, 50, 36)
PAPER = (236, 230, 216)


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except OSError:
        return ImageFont.load_default()


TITLES = {
    "landmarks": "VẠN THỦY landmarks to scale, each with the 1.75 m figure: the Court Tower (95 m above the water), a "
                 "lock gate tower at Vạn Thủy scale (the shared lock kit x1.6), a lacquer tower, a granary hall, a "
                 "treadwheel crane",
    "tower_abc": "Open choice (owner question 2): the Court Tower.  A the design, 95 m above the water   |   B lower "
                 "and wider   |   C bold, six roofs",
    "court": "VT1 the court: three terrace modules of pale quay stone with red lacquer galleries (the lowest with the "
             "closed gate facade), the 16 m court banner",
    "marks_abc": "Open choice (owner question 4): the Cửu Giang court mark, our own (a lock gate, two towers and a leaf, "
                 "in a ring), gold on indigo.  A stamp   |   B towers through the ring   |   C bold",
    "lock": "The shared lock kit, first block-in pieces (Fifth Lock scale; Vạn Thủy places them x1.6): chamber wall, gate "
            "tower, gate leaves, winch wheel, sluice port, gate gallery",
    "quay": "VT10 the Lantern Ward's quays: shop house, three-storey house with gallery, narrow canal house, canal steps "
            "(0.3 m risers; patched with one pale new block), drain mouth, notice board, blue-oil door lamp",
    "piers": "VT5 the grain piers: pier finger on its pile forest (straight, end with landing), treadwheel crane, sack "
             "mountain, crates, jars",
    "boats": "Boats: river junk (two masts), sea junk (three masts), battened sails as separate cloth meshes; the Rain "
             "Market barge with its awning, an ochre awning bay",
    "bridge": "VT7 the high bridge: 38 m span, 15 m clear for the junks, stair ramps of 0.3 m risers, the bridge gate "
              "open and shut (month 5's checkpoints)",
    "archive_night": "VT6 the archive's two-age walls (old dark blocks under new plaster, the silt line, the bronze gauge "
                     "cut with tallies), the Seventh Tide lantern net, the five district banners",
}
DIR_T = {"morning": "Jade Mist Morning", "noon": "Bright Saturated Noon", "dusk": "Golden Lantern Dusk",
         "night": "Blue Oil Night (the Seventh Tide)"}
CAM_T = {"steps": "from the Lantern Ward steps", "overview": "over the grain piers (bird's-eye)",
         "gate": "at the floodgates' foot"}


def silhouette(path, h=64):
    if not os.path.exists(path):
        return None
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)[..., 3]
    ys, xs = np.nonzero(a > 8)
    if len(xs) == 0:
        return None
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    w = max(1, round(im.width * h / im.height))
    if w > 3 * h:
        w = 3 * h
        im = im.resize((w, max(1, round(im.height * w / im.width))), Image.LANCZOS)
    else:
        im = im.resize((w, h), Image.LANCZOS)
    a = np.asarray(im)[..., 3]
    o = np.zeros((im.height, im.width, 4), np.uint8)
    o[..., 3] = (a > 100) * 255
    return Image.fromarray(o)


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


def page(raw, name, out):
    meta = json.load(open(os.path.join(raw, name + ".json")))
    im = Image.open(os.path.join(raw, name + ".png")).convert("RGB")
    W, H = im.size
    pcs = list(meta["pieces"].items())
    ncol = min(len(pcs), 4)
    nrow = (len(pcs) + ncol - 1) // ncol
    cw = W // ncol
    band = 74
    rowh = 150
    sheet = Image.new("RGB", (W, band + H + nrow * rowh + 16), PAPER)
    d = ImageDraw.Draw(sheet)
    ft, fb, fs = font(26), font(19), font(15)
    y = 10
    for ln in wrap(d, TITLES.get(name, name), ft, W - 40)[:2]:
        d.text((20, y), ln, fill=INK, font=ft)
        y += 31
    sheet.paste(im, (0, band))
    for k, (nm, p) in enumerate(pcs):
        sx, sy = p["screen"]
        x, yy = int(sx * W), int(band + sy * H)
        yy = min(max(yy, band + 14), band + H - 30)
        d.ellipse((x - 15, yy - 15, x + 15, yy + 15), fill=(250, 246, 236), outline=RED, width=3)
        d.text((x, yy), str(k + 1), fill=RED, font=fb, anchor="mm")
        cx = (k % ncol) * cw + 16
        cy = band + H + 10 + (k // ncol) * rowh
        sil = silhouette(os.path.join(raw, name + "_sil", "show_" + nm + ".png")) or \
            silhouette(os.path.join(raw, name + "_sil", nm + ".png"))
        if sil is not None:
            sheet.paste(sil, (cx, cy + 4), sil)
            tx = cx + sil.width + 14
        else:
            tx = cx
        d.text((tx, cy), "%d  %s" % (k + 1, nm), fill=INK, font=fb)
        lines = []
        if p.get("label"):
            lines.append(p["label"])
        tri = "%s tris" % format(p["tris"], ",")
        if p.get("tris_lod1"):
            tri += " / LOD1 %s" % format(p["tris_lod1"], ",")
        if p.get("sails_tris"):
            tri += " + sails %s" % format(p["sails_tris"], ",")
        if p.get("budget"):
            tri += "   (budget %s)" % p["budget"]
        lines.append(tri)
        lines.append("size %s m%s" % (" x ".join("%.1f" % v for v in p["size_m"]),
                                       ("  (x%.1f)" % p["scale"]) if p.get("scale", 1.0) != 1.0 else ""))
        lines.append("keys: " + ", ".join(p["materials"]))
        ly = cy + 26
        for ln in lines:
            for l2 in wrap(d, ln, fs, cw - (tx - cx) - 24)[:3]:
                d.text((tx, ly), l2, fill=SOFT if ln.startswith("keys") else INK, font=fs)
                ly += 18
    sheet.save(os.path.join(out, name + ".png"))
    return os.path.join(out, name + ".png")


def dioramas(raw, out):
    files = sorted(glob.glob(os.path.join(raw, "diorama_*.png")))
    done = []
    for f in files:
        _, cam, dn = os.path.basename(f)[:-4].split("_", 2)
        im = Image.open(f).convert("RGB")
        W, H = im.size
        sheet = Image.new("RGB", (W, H + 56), PAPER)
        sheet.paste(im, (0, 56))
        d = ImageDraw.Draw(sheet)
        d.text((20, 12), "VẠN THỦY, a corner of the capital  ·  %s  ·  %s" % (CAM_T.get(cam, cam), DIR_T.get(dn, dn)),
               fill=INK, font=font(26))
        d.text((W - 20, 18), "kit pieces are the assets; water, islands, trees, far karst, mist and sky are render-only "
               "stand-ins", fill=SOFT, font=font(15), anchor="ra")
        p = os.path.join(out, "diorama_%s_%s.png" % (cam, dn))
        sheet.save(p)
        done.append((cam, dn, p))
    if not done:
        return
    cams = [c for c in ("steps", "overview", "gate") if any(x[0] == c for x in done)]
    dirs = [x for x in ("morning", "noon", "dusk", "night") if any(y[1] == x for y in done)]
    tw, th = 640, 360
    sheet = Image.new("RGB", (60 + tw * len(dirs), 70 + (th + 40) * len(cams)), PAPER)
    d = ImageDraw.Draw(sheet)
    d.text((20, 14), "VẠN THỦY diorama contact sheet: three cameras (rows) in the lights (columns)", fill=INK,
           font=font(28))
    for j, dn in enumerate(dirs):
        d.text((60 + j * tw + tw // 2, 60), DIR_T[dn], fill=INK, font=font(19), anchor="ma")
    for i, cam in enumerate(cams):
        y = 90 + i * (th + 40)
        d.text((30, y + th // 2), "", fill=INK, font=font(16))
        for j, dn in enumerate(dirs):
            f = os.path.join(raw, "diorama_%s_%s.png" % (cam, dn))
            if os.path.exists(f):
                sheet.paste(Image.open(f).convert("RGB").resize((tw - 8, th - 8), Image.LANCZOS), (60 + j * tw, y))
        d.text((60, y + th - 2), CAM_T[cam], fill=INK, font=font(17))
    sheet.save(os.path.join(out, "diorama_contact.png"))


def textures(checks, out):
    tex = os.path.join(REPO, "assets", "thuyvan", "vanthuy", "textures")
    rep = {}
    rp = os.path.join(checks, "paint_report.json") if checks else ""
    if rp and os.path.exists(rp):
        rep = json.load(open(rp))
    keys = sorted(os.path.basename(f)[:-4] for f in glob.glob(os.path.join(tex, "*.png")))
    cols, cw, ch = 6, 330, 250
    rows = (len(keys) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cw + 20, 70 + rows * ch), PAPER)
    d = ImageDraw.Draw(sheet)
    d.text((20, 14), "VẠN THỦY painted textures (style guide 3.2): each with its 3 x 3 tiling at 1/8 and the 1/16 squint; "
           "mean value against the budget", fill=INK, font=font(24))
    for k, key in enumerate(keys):
        x, y = 10 + (k % cols) * cw, 60 + (k // cols) * ch
        cf = os.path.join(checks, key + "_check.png") if checks else ""
        if cf and os.path.exists(cf):
            im = Image.open(cf).convert("RGB")
        else:
            im = Image.open(os.path.join(tex, key + ".png")).convert("RGB")
        im.thumbnail((cw - 14, ch - 44))
        sheet.paste(im, (x, y + 22))
        r = rep.get(key, {})
        t = key + ("   mean %.2f / %s" % (r["mean"], r.get("target")) if r else "")
        d.text((x, y + 2), t, fill=INK, font=font(15))
    sheet.save(os.path.join(out, "textures.png"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--checks", default="")
    a = ap.parse_args()
    raw = os.path.join(a.dir, "raw")
    for js in sorted(glob.glob(os.path.join(raw, "*.json"))):
        nm = os.path.basename(js)[:-5]
        if os.path.exists(os.path.join(raw, nm + ".png")):
            print("page", page(raw, nm, a.dir))
    dioramas(raw, a.dir)
    textures(a.checks, a.dir)


if __name__ == "__main__":
    main()
