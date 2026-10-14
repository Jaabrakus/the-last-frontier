"""Thủy Vân palettes: the one machine-readable source for every builder (ROCK, VILLAGE, PAINT, the vista).

    python3 palettes.py   -> look/palettes.json, look/palettes.png, look/directions.png, look/color_keys.png

ALBEDO ramps are sRGB hex, 4 stops [dark, mid, light, accent]: the painter's cavity/AO tone, base tone, top-light
stroke tone and a sparse accent. They are the sheets' hues (look/ref/swatches_families.png) pushed to a World of
Warcraft Classic level of chroma (about 2-3x the sheets' saturation; the sheets are sepia-washed paintings, median
saturation 0.15-0.25 in every family). Values stay painter's values: no ramp reaches pure black or pure white.

DIRECTIONS are light, sky, fog and grade over the SAME albedo (one set of textures, three moods), plus the colours a
render must land near (`targets`, as rendered, sRGB) so a builder can check a frame by eye-dropper.
Sun azimuth is compass degrees (0 north = -Z, 90 east = +X), as EnvironmentRig.
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))

ALBEDO = {
    "r1": {
        "_about": "R1, the Đá Trắng reach under the Two Heights (Trường Sơn foothills; Mountain Folk / Stone Children)",
        "grass": ["#2f5a2c", "#4e8a36", "#84b546", "#c2d16a"],
        "terrace_rice": ["#4f7a2a", "#86ae3c", "#b9cf55", "#e2d873"],
        "forest_floor": ["#2e3a22", "#4c5a2e", "#6f7b3c", "#8a6a3a"],
        "moss": ["#2f4f2a", "#4f7a33", "#7fa544", "#b4c766"],
        "dirt_path": ["#5e4330", "#8c6a47", "#b8925f", "#d8b98a"],
        "laterite": ["#6b3424", "#9a4e30", "#c0703f", "#d99a5e"],
        "paddy_mud": ["#3e3a2c", "#5f5940", "#827b58", "#9fc6be"],
        "karst_limestone": ["#4a4e63", "#8e8c88", "#c9c2b2", "#eae3d0"],
        "white_stone": ["#7f8c96", "#c4c2b6", "#e8e3d3", "#fbf7ec"],
        "cliff_stain": ["#3a3d4a", "#5a5c64", "#7a7a78", "#6d8c3e"],
        "bark": ["#3a2a22", "#5e4636", "#8a6e55", "#a9927a"],
        "broadleaf": ["#24492c", "#3b7036", "#67a043", "#a4c95a"],
        "pine": ["#1f4436", "#2f634a", "#4f8a5a", "#86b172"],
        "bamboo": ["#3f6a2c", "#6e9a3a", "#a9c455", "#d6d88a"],
        "fern": ["#244a2a", "#3d7a36", "#6aa645", "#9cc45a"],
        "flowers": ["#c9583a", "#e2c04a", "#f2eedc", "#d97aa0"],
        "timber": ["#3b2a1f", "#64472f", "#8e6a47", "#b39069"],
        "plank_weathered": ["#4e4438", "#7a6a55", "#a39173", "#c7b595"],
        "roof_tile": ["#23343c", "#3a5460", "#5e7b84", "#8aa3a6"],
        "thatch": ["#5c4a2c", "#8e7342", "#bc9c5c", "#dcc384"],
        "plaster_lime": ["#8e8778", "#c1b9a4", "#e3dac2", "#f3ecd8"],
        "lacquer_red": ["#5e1c16", "#8e2e22", "#b8452f", "#d9704a"],
        "indigo_cloth": ["#1c2546", "#2d3d6e", "#4a5e96", "#7889b8"],
        "madder_cloth": ["#6a2219", "#a33a28", "#c9583a", "#e28657"],
        "ochre_cloth": ["#7a5520", "#b07f2e", "#d7a548", "#edc877"],
        "bone_cloth": ["#a69c84", "#cfc4a6", "#e9e0c6", "#f8f2e0"],
        "jade_cloth": ["#2f5c55", "#4e8577", "#7daf9c", "#b4d3c2"],
        "rope": ["#4a3a26", "#776040", "#a68a5e", "#c9b183"],
        "iron": ["#1e1d1c", "#2e2c2a", "#4a4642", "#6a645c"],
        "lantern_paper": ["#8e2e1e", "#d0562c", "#f08a44", "#ffb45a"],
        "water_depth": ["#12404a", "#1f6e6c", "#3fa294", "#8fd1c2"],
        "foam_fall": ["#9fb6bc", "#d4e0e0", "#eef3f0", "#ffffff"],
        "mist": ["#b8c8cc", "#d2dedf", "#e6eeee", "#f6f8f4"],
    },
    "thach_uyen": {
        "_about": "Thạch Uyên, the Stone Valleys: quarries, arched bridges, kilns, cliff sanctuaries; warm white stone",
        "quarry_stone": ["#6f6a78", "#b9aa95", "#e6dccb", "#f5eee0"],
        "worked_block": ["#7a7064", "#c8bba5", "#e2d6c0", "#f2e9d6"],
        "kiln_brick": ["#5a2a1c", "#9a4a2c", "#c06a3c", "#ff8a3a"],
        "smoke": ["#7c7874", "#a29c96", "#c9c3bb", "#e6e0d8"],
        "canal": ["#14525a", "#1f7a80", "#3fb0a8", "#9fe0d0"],
        "crane_timber": ["#33241a", "#5a3e2a", "#80603e", "#a8875e"],
        "banner_ochre": ["#7a5520", "#c7962f", "#e2b553", "#3a2a1e"],
        "terrace": ["#4f7a2a", "#86ae3c", "#b4ca55", "#d9d27a"],
        "dust": ["#9a8c74", "#cdbfa6", "#e3d8c2", "#f2ecdc"],
    },
    "dong_lau": {
        "_about": "Đồng Lau, the Reed Marches (Khar-Ul): stilt forts, reeds, mangroves, silver marsh water, overcast",
        "reed_gold": ["#6e5e30", "#9c8a4a", "#c7b36a", "#e2d48e"],
        "reed_green": ["#3e5a2a", "#5f7a38", "#7f9a48", "#a8bf66"],
        "marsh_water": ["#22403f", "#3e6463", "#6e8e8a", "#a9c2bc"],
        "mudflat": ["#3e3628", "#6b5e46", "#8e8064", "#b0a283"],
        "stilt_timber": ["#3a3128", "#5c4e3e", "#8a8070", "#b0a898"],
        "thatch": ["#5c4a2c", "#8e7342", "#a88c55", "#cfb67c"],
        "heron_banner": ["#1f2c4c", "#2f416a", "#4a5e8e", "#e6ddc6"],
        "mangrove_root": ["#2e261e", "#4a3d30", "#6e5c48", "#8e7a62"],
        "lantern": ["#8e3a1e", "#d06a2c", "#ffb060", "#ffe0a0"],
    },
    "vuc_sen_sau": {
        "_about": "Vực Sen Sâu, the Deep Lotus Reaches: caves, lotus basins, lanterns over dark teal water",
        "cave_rock": ["#1c2626", "#2b3a3a", "#4e6460", "#7c8f86"],
        "cave_water": ["#071f24", "#0f3b40", "#1f6464", "#2d8c88"],
        "lotus_flower": ["#a8456a", "#e67fa0", "#f7b9c9", "#fff0f2"],
        "lotus_pad": ["#21452a", "#3f7a3c", "#6ba048", "#9cc46a"],
        "lantern": ["#8e4a1a", "#e0862e", "#ffb24e", "#ffe2a0"],
        "ceramic": ["#1f4a58", "#3f7a8c", "#7fb3b0", "#d8e8e0"],
        "moss": ["#20381e", "#3e6a3a", "#6a9a4a", "#9cc46a"],
        "light_shaft": ["#7fb8b0", "#a8d8cc", "#d8f0e8", "#ffffff"],
    },
    "van_thuy": {
        "_about": "Vạn Thủy, the lock city of the Cửu Giang delta: floodgates, lacquer towers, quays, rice and sails",
        "river": ["#1e4658", "#2e5e70", "#5f8fa0", "#a9c8d4"],
        "quay_stone": ["#5e5a52", "#8f8778", "#cfc6b4", "#ebe4d4"],
        "roof_tile": ["#1e262e", "#2e3a44", "#4a5a66", "#7a8a94"],
        "lacquer_red": ["#5e1c16", "#a33a2c", "#c8553a", "#e0804e"],
        "court_banner": ["#16244a", "#24386e", "#3c5496", "#d8a743"],
        "dock_timber": ["#3a2a1e", "#6a4c34", "#94704e", "#b8966e"],
        "sail": ["#8e7e5e", "#bfae88", "#d8c9a6", "#efe4c8"],
        "rice": ["#4f7a2a", "#7fae3c", "#9dc24e", "#cfdc6a"],
    },
    "lam_uyen": {
        "_about": "Lâm Uyên, the Verdant Deep: giant root bridges, mossy trunks, stepped falls, green mist",
        "bark": ["#262016", "#3a3226", "#6a5a42", "#8e7c60"],
        "moss": ["#2a4a22", "#4f7a33", "#8db04a", "#c2d66e"],
        "canopy": ["#123a24", "#1f4a2e", "#3e7a3c", "#77a84a"],
        "root_wood": ["#3a2c1e", "#5a4632", "#7e6648", "#a08a68"],
        "falls": ["#9fb8b0", "#cfe0d8", "#eef2ec", "#ffffff"],
        "mist": ["#8ea898", "#bfd0c4", "#dce8dc", "#f0f6ee"],
        "flower": ["#c9a84a", "#e8dcb8", "#f2eedc", "#ffffff"],
    },
    "ao_thanh": {
        "_about": "Ảo Thành, the City of Illusions: night, lanterns, lacquer and crimson over reflecting water",
        "night_sky": ["#0f1430", "#1b2246", "#2e3a6e", "#4a5a96"],
        "moon": ["#c8bfa4", "#e8dfc4", "#f4ebd0", "#fffaf0"],
        "lantern": ["#8e221a", "#c23a2a", "#ffb45a", "#ffe6b0"],
        "lacquer_black": ["#140c0a", "#2a1a16", "#4a2e26", "#6e463a"],
        "crimson_banner": ["#5e1418", "#9e2a2a", "#c84a3a", "#e0a83e"],
        "water_night": ["#141a2c", "#2c3550", "#4a5478", "#f2b65e"],
        "plaster": ["#8e826c", "#b8aa90", "#d8cbb0", "#efe4cc"],
        "pine": ["#14281e", "#23402e", "#3a5e44", "#5a7e5a"],
    },
}

DIRECTIONS = {
    "jade_mist_morning": {
        "title": "Jade Mist Morning",
        "pitch": "Closest to the sheets: a cool, quiet morning where mist holds in the gorge and wraps the karst waists; "
                 "the white stones and the falls are the brightest things in frame; colour is fresh jade and moss, "
                 "warm cream only where the low sun touches.",
        "sun": {"azimuth_deg": 75, "elevation_deg": 14, "color": "#ffe2b8", "energy": 1.6, "angular_deg": 2.0},
        "sky": {"zenith": "#8fb4cf", "mid": "#bfd4de", "horizon": "#e4ebe6", "cloud_lit": "#fff6e8",
                "cloud_shade": "#afc0cc", "clouds": "low cloud banks round the peaks, a few high soft cumulus"},
        "ambient": {"color": "#a9c4cc", "energy": 1.0, "sky_contribution": 0.6},
        "fog": {"color": "#cfdcda", "light_energy": 1.0, "density": 0.0007, "aerial_perspective": 0.6,
                "sun_scatter": 0.15, "height": 175.0, "height_density": 0.012},
        "mist_bands_m": [[145, 165, "dense, holds over the still reach"], [185, 200, "drifting across the low terraces"],
                         [265, 285, "under the Two Heights deck and round the karst waists"]],
        "grade": {"tonemap": "AgX", "contrast": 1.05, "saturation": 1.10, "shadow_tint": "#2a4a50",
                  "highlight_tint": "#fff0d8", "notes": "greens stay jade; never pulled to olive"},
        "lanterns": "off (paper reads as colour)",
        "targets": {"sky_top": "#8fb4cf", "far_karst": "#b9c9cc", "mid_karst_lit": "#cfc8b4",
                    "karst_shade": "#7e8a98", "terrace_lit": "#9cc25a", "forest_shade": "#3f6650",
                    "white_stones": "#f2eee2", "river": "#3f9a8e", "mist": "#e2eaea", "banner": "#34477a"},
    },
    "bright_saturated_noon": {
        "title": "Bright Saturated Noon",
        "pitch": "Closest to the World of Warcraft Classic feel (Elwynn-green meets Stranglethorn-lush): a high sun, "
                 "deep blue sky with big white cumulus, vivid greens and warm earth, crisp readable silhouettes, "
                 "fog only far off; the red flags and indigo banners pop.",
        "sun": {"azimuth_deg": 200, "elevation_deg": 58, "color": "#fff3d9", "energy": 2.4, "angular_deg": 0.8},
        "sky": {"zenith": "#2f7fd6", "mid": "#6fb2ea", "horizon": "#cde9f4", "cloud_lit": "#ffffff",
                "cloud_shade": "#b4c8e4", "clouds": "big towering cumulus, flat grey-blue bases, two or three heaps"},
        "ambient": {"color": "#9ec3e6", "energy": 1.25, "sky_contribution": 0.5},
        "fog": {"color": "#b5d3ec", "light_energy": 1.0, "density": 0.00035, "aerial_perspective": 0.4,
                "sun_scatter": 0.05, "height": 150.0, "height_density": 0.006},
        "mist_bands_m": [[140, 152, "thin, only in the gorge and at the falls' feet"]],
        "grade": {"tonemap": "AgX", "contrast": 1.15, "saturation": 1.25, "shadow_tint": "#2a3e6a",
                  "highlight_tint": "#fff6e0", "notes": "the most saturated; shadows blue-violet, never grey"},
        "lanterns": "off",
        "targets": {"sky_top": "#2f7fd6", "far_karst": "#9cb8d4", "mid_karst_lit": "#e2d8c0",
                    "karst_shade": "#6e7ea6", "terrace_lit": "#b2d64e", "forest_shade": "#2e5e3a",
                    "white_stones": "#fbf6e8", "river": "#2fae9c", "mist": "#eef4f6", "banner": "#2f4690"},
    },
    "golden_lantern_dusk": {
        "title": "Golden Lantern Dusk",
        "pitch": "The sun sets behind the Two Heights: backlit karst cut out against peach and violet, gold rims on "
                 "every ridge, violet mist in the valleys, and the village lanterns, windows and bridge-head lamps "
                 "glowing warm; smoke caught under the roofs.",
        "sun": {"azimuth_deg": 285, "elevation_deg": 5, "color": "#ff9a45", "energy": 1.3, "angular_deg": 1.5},
        "sky": {"zenith": "#4b4a8c", "mid": "#8e6fa6", "horizon": "#ffd08a", "low": "#f2a66b",
                "cloud_lit": "#ffb070", "cloud_shade": "#7b6a9a", "clouds": "long low bars lit from beneath"},
        "ambient": {"color": "#6e6a9e", "energy": 0.7, "sky_contribution": 0.5},
        "fog": {"color": "#d99a7a", "valley_color": "#7a6e9c", "light_energy": 1.0, "density": 0.0006,
                "aerial_perspective": 0.7, "sun_scatter": 0.35, "height": 170.0, "height_density": 0.010},
        "mist_bands_m": [[145, 165, "violet, in the gorge"], [255, 280, "gold where the sun is behind it"]],
        "grade": {"tonemap": "AgX", "contrast": 1.10, "saturation": 1.15, "shadow_tint": "#3a3468",
                  "highlight_tint": "#ffd49a", "notes": "warm/cool split: everything sunlit gold, everything else violet"},
        "lanterns": "on: paper emission 3.0 (#ffb45a), windows 1.5, bridge-head lamps 4.0, glow on",
        "targets": {"sky_top": "#4b4a8c", "far_karst": "#9a7e9a", "mid_karst_lit": "#f0b67a",
                    "karst_shade": "#4e4870", "terrace_lit": "#c8b85a", "forest_shade": "#2e3a46",
                    "white_stones": "#f4d6b8", "river": "#d89a6a", "mist": "#b8a0c0", "banner": "#2a3058"},
    },
}


def font(sz):
    for p in ("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def palettes_png():
    rows = [(z, k, v) for z, d in ALBEDO.items() for k, v in d.items() if not k.startswith("_")]
    W, rh = 1500, 34
    zs = list(ALBEDO)
    im = Image.new("RGB", (W, 60 + len(rows) * rh + len(zs) * 40), (236, 230, 216))
    d = ImageDraw.Draw(im)
    d.text((10, 12), "Thủy Vân albedo ramps (sRGB): dark / mid / light / accent per material, per zone", fill=(40, 34, 28),
           font=font(26))
    y = 56
    for z in zs:
        d.text((10, y + 8), ALBEDO[z]["_about"], fill=(90, 40, 30), font=font(20))
        y += 40
        for k, v in ALBEDO[z].items():
            if k.startswith("_"):
                continue
            d.text((30, y + 7), k, fill=(40, 34, 28), font=font(17))
            for i, hx in enumerate(v):
                x = 260 + i * 300
                d.rectangle([x, y + 2, x + 200, y + rh - 4], fill=hx)
                d.text((x + 206, y + 7), hx, fill=(40, 34, 28), font=font(15))
            y += rh
    im.save(os.path.join(OUT, "palettes.png"))


def directions_png():
    W = 1500
    im = Image.new("RGB", (W, 80 + 3 * 300), (236, 230, 216))
    d = ImageDraw.Draw(im)
    d.text((10, 12), "Three directions for R1's first vista: light, sky, fog and the colours a render should land near",
           fill=(40, 34, 28), font=font(26))
    y = 60
    for key, D in DIRECTIONS.items():
        d.text((10, y), D["title"], fill=(90, 40, 30), font=font(24))
        # sky strip
        top, mid, hor = rgb(D["sky"]["zenith"]), rgb(D["sky"]["mid"]), rgb(D["sky"]["horizon"])
        for i in range(120):
            t = i / 119
            c = tuple(int(a + (b - a) * min(1, t * 2)) if t < 0.5 else int(b + (cc - b) * (t - 0.5) * 2)
                      for a, b, cc in zip(top, mid, hor))
            d.line([(10, y + 34 + i), (230, y + 34 + i)], fill=c)
        d.text((14, y + 160), "sky zenith > horizon", fill=(40, 34, 28), font=font(14))
        items = [("sun", D["sun"]["color"]), ("ambient", D["ambient"]["color"]), ("fog", D["fog"]["color"]),
                 ("cloud lit", D["sky"]["cloud_lit"]), ("cloud shade", D["sky"]["cloud_shade"])]
        items += list(D["targets"].items())
        for i, (n, hx) in enumerate(items):
            x = 250 + (i % 8) * 155
            yy = y + 34 + (i // 8) * 90
            d.rectangle([x, yy, x + 140, yy + 54], fill=hx)
            d.text((x, yy + 57), "%s %s" % (n.replace("_", " "), hx), fill=(40, 34, 28), font=font(13))
        s = D["sun"]
        d.text((250, y + 220), "sun az %d el %d energy %.1f | fog density %.5f, height fog %.0f m x %.3f | grade %s" % (
            s["azimuth_deg"], s["elevation_deg"], s["energy"], D["fog"]["density"], D["fog"]["height"],
            D["fog"]["height_density"], D["grade"]["notes"]), fill=(40, 34, 28), font=font(15))
        y += 300
    im.save(os.path.join(OUT, "directions.png"))


def color_keys_png():
    """A colour key per direction: V1's composition as flat painted layers (sky, far karst, the Two Heights, mid
    terraces and village, the gorge wall, the river with white stones, the bridge line, mist bands). An art
    director's colour key for choosing a mood, not a render."""
    import math
    import random
    W, H = 960, 540
    out = Image.new("RGB", (W * 3 + 40, H + 70), (236, 230, 216))
    dd = ImageDraw.Draw(out)
    for n, (key, D) in enumerate(DIRECTIONS.items()):
        T = D["targets"]
        im = Image.new("RGB", (W, H))
        d = ImageDraw.Draw(im, "RGBA")
        top, mid, hor = rgb(D["sky"]["zenith"]), rgb(D["sky"]["mid"]), rgb(D["sky"]["horizon"])
        for yy in range(H):
            t = min(1.0, yy / (H * 0.55))
            c = [int(a + (b - a) * min(1, t * 2)) if t < 0.5 else int(b + (cc - b) * (t - 0.5) * 2)
                 for a, b, cc in zip(top, mid, hor)]
            d.line([(0, yy), (W, yy)], fill=tuple(c))
        rnd = random.Random(7)
        # clouds
        cl, cs = rgb(D["sky"]["cloud_lit"]), rgb(D["sky"]["cloud_shade"])
        for _ in range(7):
            cx, cy, r = rnd.uniform(0, W), rnd.uniform(40, 170), rnd.uniform(30, 70)
            for k in range(6):
                ox, oy, rr = cx + rnd.uniform(-1.5, 1.5) * r, cy + rnd.uniform(-0.4, 0.3) * r, r * rnd.uniform(0.5, 0.9)
                d.ellipse([ox - rr, oy - rr * 0.7 + rr * 0.12, ox + rr, oy + rr * 0.7 + rr * 0.12], fill=cs + (200,))
                d.ellipse([ox - rr, oy - rr * 0.7, ox + rr, oy + rr * 0.55], fill=cl + (220,))

        def towers(base_y, col, count, hmin, hmax, wmin, wmax, seed, lean=0.15):
            r = random.Random(seed)
            for _ in range(count):
                x = r.uniform(-40, W + 40)
                hgt, w = r.uniform(hmin, hmax), r.uniform(wmin, wmax)
                ln = r.uniform(-lean, lean) * hgt
                pts = [(x - w / 2, base_y), (x - w * 0.42 + ln * 0.4, base_y - hgt * 0.45),
                       (x - w * 0.3 + ln, base_y - hgt * 0.9), (x + ln * 1.05, base_y - hgt),
                       (x + w * 0.32 + ln, base_y - hgt * 0.86), (x + w * 0.45 + ln * 0.4, base_y - hgt * 0.4),
                       (x + w / 2, base_y)]
                d.polygon(pts, fill=col)
                # pine cap
                d.ellipse([x + ln - w * 0.28, base_y - hgt - w * 0.12, x + ln + w * 0.3, base_y - hgt + w * 0.12],
                          fill=tuple(int(c * 0.8) for c in col[:3]) + (col[3],) if len(col) == 4 else col)

        fk = rgb(T["far_karst"])
        towers(300, fk + (255,), 14, 90, 190, 40, 80, 1)
        d.rectangle([0, 285, W, 320], fill=rgb(T["mist"]) + (150,))
        # the Two Heights: two tall heads and a bridge between, right of centre
        mk = tuple(int(a * 0.55 + b * 0.45) for a, b in zip(rgb(T["far_karst"]), rgb(T["karst_shade"])))
        for hx0, hh in ((610, 170), (700, 150)):
            d.polygon([(hx0 - 30, 330), (hx0 - 22, 230), (hx0 - 8, 330 - hh), (hx0 + 14, 330 - hh + 12),
                       (hx0 + 26, 240), (hx0 + 32, 330)], fill=mk)
        d.rectangle([636, 214, 676, 220], fill=mk)
        for px_ in (646, 666):
            d.rectangle([px_, 220, px_ + 5, 300], fill=mk)
        d.rectangle([0, 268, W, 290], fill=rgb(T["mist"]) + (110,))
        # mid hills and terraces with the village
        tl = rgb(T["terrace_lit"])
        d.polygon([(0, 360), (180, 300), (420, 315), (620, 330), (W, 345), (W, 420), (0, 420)], fill=tl)
        for k in range(9):
            yy = 318 + k * 9
            d.line([(60, yy + 20), (520, yy)], fill=tuple(int(c * 0.82) for c in tl), width=2)
        for k in range(8):
            hx0, hy0 = 250 + k * 34 + rnd.uniform(-8, 8), 322 + rnd.uniform(-6, 10)
            d.polygon([(hx0 - 16, hy0), (hx0 - 22, hy0 - 4), (hx0, hy0 - 16), (hx0 + 22, hy0 - 4), (hx0 + 16, hy0)],
                      fill=rgb(ALBEDO["r1"]["roof_tile"][1]))
            d.rectangle([hx0 - 11, hy0, hx0 + 11, hy0 + 9], fill=rgb(ALBEDO["r1"]["timber"][2]))
            if key == "golden_lantern_dusk":
                d.ellipse([hx0 - 3, hy0 + 2, hx0 + 3, hy0 + 8], fill=(255, 190, 100))
        fs = rgb(T["forest_shade"])
        for k in range(26):
            cx, cy, r = rnd.uniform(0, W), rnd.uniform(340, 400), rnd.uniform(12, 26)
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fs)
            d.ellipse([cx - r * 0.7, cy - r * 0.9, cx + r * 0.5, cy + r * 0.2], fill=tl + (90,))
        # gorge: west wall face lit, river, white stones
        kl, ks = rgb(T["mid_karst_lit"]), rgb(T["karst_shade"])
        d.polygon([(0, 400), (W, 410), (W, 470), (560, 470), (330, 460), (0, 480)], fill=ks)
        for k in range(14):
            x0 = k * 70 + rnd.uniform(-10, 10)
            d.polygon([(x0, 404), (x0 + 40, 406), (x0 + 30, 462), (x0 + 6, 466)], fill=kl)
        d.polygon([(0, 480), (330, 460), (560, 470), (W, 470), (W, H), (0, H)], fill=rgb(T["river"]))
        ws = rgb(T["white_stones"])
        for k in range(40):
            cx, cy = rnd.uniform(0, W), rnd.uniform(478, H)
            r = rnd.uniform(4, 14) * (cy - 440) / 80
            d.ellipse([cx - r, cy - r * 0.55, cx + r, cy + r * 0.5], fill=ws)
        d.rectangle([0, 430, W, 470], fill=rgb(T["mist"]) + (120,))
        # falls on the west wall
        for fx in (300, 760):
            d.rectangle([fx, 404, fx + 14, 480], fill=(245, 248, 245, 230))
            d.ellipse([fx - 30, 466, fx + 44, 494], fill=rgb(T["mist"]) + (200,))
        # rope bridge from lower left into the middle, with posts and banner
        rope = rgb(ALBEDO["r1"]["rope"][1])
        pts = [(x, 520 - 120 * (x / 560) + 22 * math.sin(math.pi * x / 560)) for x in range(0, 561, 8)]
        d.line(pts, fill=rope, width=6)
        d.line([(x, y - 14) for x, y in pts], fill=rope, width=3)
        for x, y in pts[::6]:
            d.line([(x, y), (x, y - 14)], fill=rope, width=2)
        d.rectangle([60, 400, 70, 520], fill=rgb(ALBEDO["r1"]["timber"][1]))
        d.rectangle([70, 404, 104, 470], fill=rgb(T["banner"]))
        d.polygon([(70, 470), (104, 470), (96, 492), (78, 480)], fill=rgb(T["banner"]))
        d.rectangle([84, 418, 90, 440], fill=rgb(ALBEDO["r1"]["bone_cloth"][2]))
        for k in range(6):
            d.rectangle([112 + k * 18, 430 + k * 3, 124 + k * 18, 446 + k * 3],
                        fill=rgb([ALBEDO["r1"]["madder_cloth"][1], ALBEDO["r1"]["ochre_cloth"][2],
                                  ALBEDO["r1"]["indigo_cloth"][1], ALBEDO["r1"]["bone_cloth"][2]][k % 4]))
        if key == "golden_lantern_dusk":
            for lx, ly in ((66, 396), (540, 400)):
                d.ellipse([lx - 14, ly - 14, lx + 14, ly + 14], fill=(255, 180, 90, 90))
                d.ellipse([lx - 6, ly - 8, lx + 6, ly + 8], fill=(255, 196, 110))
            # backlight rim on the Two Heights
            d.line([(600, 330 - 170), (624, 330 - 158)], fill=(255, 200, 120), width=3)
        out.paste(im, (10 + n * (W + 10), 10))
        dd.text((10 + n * (W + 10), H + 20), D["title"] + " (colour key, not a render)", fill=(40, 34, 28),
                font=font(24))
    out.save(os.path.join(OUT, "color_keys.png"))


if __name__ == "__main__":
    json.dump({"albedo": ALBEDO, "directions": DIRECTIONS}, open(os.path.join(OUT, "palettes.json"), "w"), indent=1,
              ensure_ascii=False)
    palettes_png()
    directions_png()
    color_keys_png()
    print("wrote palettes.json, palettes.png, directions.png, color_keys.png in", OUT)
