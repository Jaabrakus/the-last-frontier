#!/usr/bin/env python3
"""Compose PAINT's review boards from the renders and textures (style guide 11: labels, triangle counts, material
keys, 64 px silhouette insets, squint checks). Pure PIL; run after the painters and the Blender renders:

    python3 tools/thuyvan_art/paint/compose_boards.py [foliage] [swatches] [sky] [water]

Writes into look/PAINT/: board_foliage_lineup.png, board_terrain_swatches.png, board_rock_trim.png,
board_skies.png, board_water_mist.png.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvp  # noqa: E402

LOOK = tvp.LOOK
BG = (34, 36, 38)
FG = (236, 232, 222)
DIM = (170, 168, 160)


def font(size):
    for f in ("/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc",
              "/Library/Fonts/Arial.ttf"):
        if os.path.exists(f):
            try:
                return ImageFont.truetype(f, size)
            except OSError:
                pass
    return ImageFont.load_default()


def title(img, text, sub=None):
    d = ImageDraw.Draw(img)
    d.text((24, 16), text, fill=FG, font=font(34))
    if sub:
        d.text((24, 58), sub, fill=DIM, font=font(18))


def on_bg(im, bg=(176, 168, 150)):
    im = im.convert("RGBA")
    b = Image.new("RGBA", im.size, bg + (255,))
    b.alpha_composite(im)
    return b.convert("RGB")


def silhouette(path, h=64):
    a = Image.open(path).convert("RGBA").getchannel("A")
    bb = a.getbbox()
    if bb is None:
        return Image.new("RGB", (h, h), (240, 238, 232))
    a = a.crop(bb)
    w = max(int(a.width * h / a.height), 1)
    a = a.resize((w, h), Image.LANCZOS)
    out = Image.new("RGB", (w + 8, h + 8), (240, 238, 232))
    out.paste((0, 0, 0), (4, 4), a.point(lambda v: 255 if v > 127 else 0))
    return out


def foliage():
    meta = json.load(open(os.path.join(LOOK, "foliage", "lineup.json")))
    W = 1920
    parts = []
    for row in ("trees", "understorey"):
        im = Image.open(os.path.join(LOOK, "foliage", "lineup_%s.png" % row)).convert("RGB")
        d = ImageDraw.Draw(im)
        for e in meta[row]:
            x, y = e["label_xy"]
            y = min(max(y + 12, 0), im.height - 64)
            txt = "%s v%d  %.1f m\n%d / %d tris" % (e["name"].replace("tv_", ""), e["v"], e["height_m"],
                                                     e["tris_lod0"], e["tris_lod1"])
            tw = 150
            d.rectangle((x - tw / 2, y, x + tw / 2, y + 44), fill=(20, 22, 24))
            d.multiline_text((x - tw / 2 + 6, y + 3), txt, fill=FG, font=font(15), spacing=2)
        parts.append(im)
    # silhouettes strip
    sils = []
    for row in ("trees", "understorey"):
        for e in meta[row]:
            p = os.path.join(LOOK, "foliage", "sil", "%s_v%d.png" % (e["name"], e["v"]))
            if os.path.exists(p):
                sils.append((e["name"].replace("tv_", "") + " v%d" % e["v"], silhouette(p, 64)))
    strip = Image.new("RGB", (W, 120), (240, 238, 232))
    d = ImageDraw.Draw(strip)
    x = 16
    d.text((16, 4), "64 px black-silhouette test (style guide 4): every plant must still read at 64 px", fill=(40, 40, 40),
           font=font(16))
    for name, s in sils:
        strip.paste(s, (x, 28))
        d.text((x, 100), name, fill=(60, 60, 60), font=font(11))
        x += max(s.width, 84) + 10
    H = 90 + sum(p.height for p in parts) + strip.height + 20
    board = Image.new("RGB", (W, H), BG)
    title(board, "Thủy Vân R1 vegetation: painted cards on puff meshes",
          "Eevee, bright game light, the painted grass slice as ground; dark figure = 1.75 m (porter with a conical "
          "hat); labels: LOD0 / LOD1 triangles; material per species (atlas + painted bark)")
    y = 90
    for p in parts:
        board.paste(p, (0, y))
        y += p.height
    board.paste(strip, (0, y + 10))
    board.save(os.path.join(LOOK, "board_foliage_lineup.png"))
    # the cards themselves
    fol = os.path.join(tvp.OUT, "foliage")
    at = on_bg(Image.open(os.path.join(fol, "tv_foliage_atlas.png"))).resize((960, 960), Image.LANCZOS)
    ga = on_bg(Image.open(os.path.join(fol, "tv_grass_atlas.png"))).resize((960, 480), Image.LANCZOS)
    ha = on_bg(Image.open(os.path.join(fol, "tv_herb_atlas.png"))).resize((960, 480), Image.LANCZOS)
    barks = [Image.open(os.path.join(fol, n)).convert("RGB") for n in
             ("tv_bark_broadleaf.png", "tv_bark_pine.png", "tv_bamboo_culm.png", "tv_banana_trunk.png")]
    b2 = Image.new("RGB", (1920 + 32, 90 + 960 + 30), BG)
    title(b2, "Painted foliage cards and bark", "leaf atlas 2048² (16 tiles), grass atlas and herb atlas 2048 x 1024 "
                                                "(16 cells each), bark / culm tiles; on a neutral ground")
    b2.paste(at, (16, 90))
    b2.paste(ga, (16 + 960 + 16, 90))
    b2.paste(ha, (16 + 960 + 16, 90 + 480))
    b2.save(os.path.join(LOOK, "board_foliage_cards.png"))
    x = 0
    bk = Image.new("RGB", (4 * 260, 520), BG)
    for b in barks:
        b = b.resize((int(b.width * 512 / b.height), 512), Image.LANCZOS)
        bk.paste(b, (x, 4))
        x += b.width + 8
    bk.save(os.path.join(LOOK, "foliage", "barks.png"))


def swatches():
    sl = json.load(open(os.path.join(tvp.OUT, "terrain", "terrain_slices.json")))["slices"]
    cell = 440
    cols = 4
    rows = (len(sl) + cols - 1) // cols
    ck0 = Image.open(os.path.join(LOOK, "checks", "terrain_%02d_%s_check.png" % (sl[0]["slice"], sl[0]["key"])))
    ckh = int(ck0.height * cell / ck0.width)
    rowh = cell + ckh + 36
    W = cols * (cell + 16) + 16
    H = 90 + rows * rowh
    board = Image.new("RGB", (W, H), BG)
    title(board, "Thủy Vân R1 terrain array: 12 painted slices",
          "each 2048² (8 m, 256 px/m; cliff face 16 m), RGB albedo with painted light and AO, A = blend height; "
          "top: one tile; below: 3 x 3 tiling check (1/8) and squint (1/16)")
    d = ImageDraw.Draw(board)
    for i, s in enumerate(sl):
        x = 16 + (i % cols) * (cell + 16)
        y = 90 + (i // cols) * rowh
        im = Image.open(os.path.join(LOOK, "slices", "%02d_%s.png" % (s["slice"], s["key"]))).convert("RGB")
        board.paste(im.resize((cell, cell), Image.LANCZOS), (x, y))
        ck = Image.open(os.path.join(LOOK, "checks", "terrain_%02d_%s_check.png" % (s["slice"], s["key"])))
        ck = ck.resize((cell, int(ck.height * cell / ck.width)), Image.LANCZOS)
        board.paste(ck, (x, y + cell + 4))
        d.text((x, y + cell + 6 + ck.height), "%d %s  %.0f m  mean %.2f (budget %.2f)  range %.2f-%.2f" %
               (s["slice"], s["key"], s["tile_m"], s["mean"], s["value_budget"], s["p2"], s["p98"]), fill=FG,
               font=font(14))
    board.save(os.path.join(LOOK, "board_terrain_swatches.png"))
    # rock and trim
    rk = os.path.join(tvp.OUT, "rock")
    ims = [("karst face 16 m", os.path.join(rk, "tv_karst_face_16m.png")),
           ("white river stone 4 m", os.path.join(rk, "tv_river_stone_4m.png")),
           ("cliff moss 6 m", os.path.join(rk, "tv_cliff_moss_6m.png")),
           ("village trim sheet, 256 px/m", os.path.join(tvp.OUT, "trim", "tv_village_trim.png"))]
    b2 = Image.new("RGB", (4 * 476 + 16, 90 + 470 + 30), BG)
    title(b2, "Rock tiling for meshes and the village trim sheet (P02, P03)")
    d = ImageDraw.Draw(b2)
    for i, (n, p) in enumerate(ims):
        im = Image.open(p).convert("RGB").resize((460, 460), Image.LANCZOS)
        b2.paste(im, (16 + i * 476, 90))
        d.text((16 + i * 476, 90 + 464), n, fill=FG, font=font(16))
    b2.save(os.path.join(LOOK, "board_rock_trim.png"))


def skies():
    names = ["jade_mist_morning", "bright_saturated_noon", "golden_lantern_dusk"]
    W = 1920
    parts = []
    for n in names:
        im = Image.open(os.path.join(tvp.OUT, "sky", "tv_sky_%s.png" % n)).convert("RGB")
        # the upper half and the horizon band (what the camera sees)
        im = im.crop((0, 0, im.width, int(im.height * 0.56))).resize((W, int(W * 0.56 / 2)), Image.LANCZOS)
        parts.append((tvp.direction(n)["title"], im))
    cards = [Image.open(os.path.join(tvp.OUT, "sky", "tv_skyline_karst_%d.png" % k)) for k in range(3)]
    H = 90 + sum(p.height + 40 for _, p in parts) + 3 * 130 + 40
    board = Image.new("RGB", (W, H), BG)
    title(board, "Painted sky panoramas (4096 x 2048 equirect, upper 56 % shown) and far skyline cards",
          "north at u 0.5, east at 0.75; the sun's glow painted where each direction's sun stands; two fog-tinted "
          "karst bands along the horizon")
    d = ImageDraw.Draw(board)
    y = 90
    for t, p in parts:
        d.text((16, y + 6), t, fill=FG, font=font(20))
        board.paste(p, (0, y + 34))
        y += p.height + 40
    d.text((16, y + 6), "skyline cards 0-2 (near to far), lit neutral, tinted toward the fog by the card shader",
           fill=FG, font=font(18))
    y += 34
    for k, c in enumerate(cards):
        c = on_bg(c, (190, 210, 220)).resize((W, 120), Image.LANCZOS)
        board.paste(c, (0, y))
        y += 128
    board.save(os.path.join(LOOK, "board_skies.png"))


def water():
    wd = os.path.join(tvp.OUT, "water")
    bg = (62, 85, 96)
    row1 = ["tv_fall_body.png", "tv_fall_streaks.png", "tv_fall_edge_foam.png", "tv_wet_stain.png",
            "tv_fall_spray.png", "tv_pool_foam_ring.png", "tv_mist_puffs.png", "tv_smoke_wisps.png"]
    row2 = ["tv_mist_band_a.png", "tv_mist_band_b.png", "tv_mist_band_c.png"]
    row3 = ["tv_river_flow.png", "tv_river_foam.png", "tv_river_ramp.png"]
    W = 1920
    board = Image.new("RGB", (W, 90 + 440 + 3 * 210 + 300 + 80), BG)
    title(board, "Falls, mist and river kit (P09-P11)",
          "white with cool shade streaks, 3-4 tones of one ramp; shown over a slate ground; unshaded and tinted per "
          "direction in game")
    d = ImageDraw.Draw(board)
    x, y = 16, 90
    for n in row1:
        im = on_bg(Image.open(os.path.join(wd, n)), bg)
        im = im.resize((max(int(im.width * 400 / im.height), 1), 400), Image.LANCZOS)
        board.paste(im, (x, y))
        d.text((x, y + 404), n.replace("tv_", "").replace(".png", ""), fill=FG, font=font(13))
        x += im.width + 12
    y += 440
    for n in row2:
        im = on_bg(Image.open(os.path.join(wd, n)), bg).resize((1600, 200), Image.LANCZOS)
        board.paste(im, (16, y))
        d.text((1630, y + 90), n.replace("tv_", "").replace(".png", ""), fill=FG, font=font(16))
        y += 210
    x = 16
    for n in row3:
        im = on_bg(Image.open(os.path.join(wd, n)), bg)
        if "ramp" in n:
            im = im.resize((900, 280), Image.NEAREST)
        else:
            im = im.resize((280, 280), Image.LANCZOS)
        board.paste(im, (x, y))
        d.text((x, y + 282), n.replace("tv_", "").replace(".png", "") +
               (" (x: depth 0-4 m; top: day, bottom: still S1)" if "ramp" in n else ""), fill=FG, font=font(13))
        x += im.width + 16
    board.save(os.path.join(LOOK, "board_water_mist.png"))


if __name__ == "__main__":
    which = set(sys.argv[1:]) or {"foliage", "swatches", "sky", "water"}
    if "foliage" in which:
        foliage()
    if "swatches" in which:
        swatches()
    if "sky" in which:
        skies()
    if "water" in which:
        water()
    print("boards done")
