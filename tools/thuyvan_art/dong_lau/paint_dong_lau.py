"""Paint the Reed Marches stilt kit's textures (Đồng Lau, dl_*; style guide section 3.2, the brush recipe).

    python3 tools/thuyvan_art/dong_lau/paint_dong_lau.py [--only key,key] [--check-dir DIR] [--sky-dir DIR]

Reads materials.json (one row per key) and the art director's docs/thuyvan/plan/look/palettes.json (albedo.dong_lau;
'zone.name' ramps borrow r1's rope, iron, bamboo and dyes). Writes assets/thuyvan/dong_lau/textures/<key>.png (sRGB;
RGBA for the alpha-scissor keys: net, reedcard) and, with --check-dir, each texture's 3 x 3 tiling + 1/16 squint
(<key>_check.png) and paint_report.json. --sky-dir also paints the three marsh sky panoramas of directions.json
(4096 x 2048, render-only stand-ins until PAINT owns the marsh skies) with PAINT's sky painter.

The brush, the canvas and the shared painters (planks, thatch, weave, rope, iron, bamboo, earth, paper, cloth, banner)
are the village kit's (tools/thuyvan_art/village/paint_village.py, imported, never edited); this file adds the marsh's
own: pile timber, reed bundles, mangrove bark, leaf clumps, dried fish, net (alpha), reed cards (alpha atlas), the
tally face and the old drowned stone. Fixed seeds (CRC32 of the key): a rebuild gives the same bytes.
"""

import argparse
import json
import math
import os
import sys
import zlib

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "village"))
import dl_marks  # noqa: E402,F401  (registers the heron marks)
import paint_village as pv  # noqa: E402
from paint_village import Canvas, hex_lin, luma  # noqa: E402

OUT = os.path.join(REPO, "assets", "thuyvan", "dong_lau", "textures")
PALJ = json.load(open(os.path.join(REPO, "docs", "thuyvan", "plan", "look", "palettes.json")))["albedo"]


def ramp_of(name, zone="dong_lau"):
    if "." in name:
        zone, name = name.split(".", 1)
    return PALJ[zone][name]


# ------------------------------------------------------------------------------------------------ marsh painters
def p_pile(cv, spec):
    """Weathered round piles: long grain along U (a tube's length), split checks, grey sun-bleached streaks."""
    rng = cv.rng
    W, H = cv.w, cv.h
    pv.generic_ground(cv, 50, 0, 0.0, 0.03, (4, 8), big_size=(0.15, 0.4), weights=(0.3, 0.45, 0.25, 0.0))
    for _ in range(int(W * 0.9)):
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.08, 0.3) * W, rng.uniform(1.0, 2.6), rng.normal(0, 0.015),
               cv.col(rng.choice([0.2, 0.7, 1.2, 1.8, 2.4])), 0.5, hgt=0.25, wobble=0)
    for _ in range(26):
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.1, 0.35) * W, 1.6, rng.normal(0, 0.01),
               cv.col(0) * 0.7, 0.9, hgt=-0.8, wobble=0)
    for _ in range(14):
        kx, ky = rng.uniform(0, W), rng.uniform(0, H)
        cv.dab(kx, ky, 9, 6, 0, cv.col(2.4), 0.8)
        cv.dab(kx, ky, 5, 3.5, 0, cv.col(0) * 0.8, 1.0, hgt=-0.5)


def p_bundle(cv, spec):
    """Bound reed bundles (burial boats, bundle floats): strands along U, a lit crown on each bundle, dark rope ties
    every 0.5 m."""
    rng = cv.rng
    W, H = cv.w, cv.h
    nb = 4
    bh = H / nb
    for k in range(nb):
        y0 = k * bh
        for _ in range(int(W * 1.2)):
            y = y0 + bh * rng.beta(2, 2)
            t = abs((y - y0) / bh - 0.45)
            cv.dab(rng.uniform(0, W), y, rng.uniform(0.1, 0.3) * W, rng.uniform(1.2, 2.4), rng.normal(0, 0.02),
                   cv.col(np.clip(2.4 - t * 4.2 + rng.uniform(-0.4, 0.4), 0.0, 3.0)), 0.75, hgt=0.4, wobble=0)
        for xx in np.arange(0, W, 6):
            cv.dab(xx, y0 + 1.5, 6, 2.6, 0, cv.col(0) * 0.6, 0.8, hgt=-1.0, wobble=0.05)
    rope = [hex_lin(c) for c in ramp_of("r1.rope")]
    n_ties = int(round(spec["tile_m"] / 0.5))
    for k in range(n_ties):
        x = (k + 0.5) * W / n_ties + rng.uniform(-4, 4)
        for yy in np.arange(0, H, 5):
            cv.dab(x, yy, 7, 3.2, 0.25, rope[1], 1.0, hgt=1.2, wobble=0.0)
            cv.dab(x - 2, yy - 1, 4, 1.2, 0.25, rope[2], 0.9, wobble=0.0)
        for yy in np.arange(0, H, 5):
            cv.dab(x + 9, yy, 2.5, 3.5, 0, cv.col(0) * 0.7, 0.6, hgt=-0.4)


def p_bark(cv, spec):
    """Mangrove bark: smooth grey-brown skin with long flutes along U (a root's length), pale lenticel flecks and
    wet dark patches."""
    rng = cv.rng
    W, H = cv.w, cv.h
    pv.generic_ground(cv, 70, 0, 0.0, 0.05, (3, 6), big_size=(0.12, 0.3), weights=(0.25, 0.5, 0.25, 0.0))
    for _ in range(int(W * 0.35)):
        cv.stroke3(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.04, 0.14) * W, rng.uniform(2.5, 6.0),
                   rng.normal(0, 0.05), cv.kcol(0.4, 2.2), 0.7, up=(0.0, -1.0), hgt=0.6)
    for _ in range(int(W * 0.3)):
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(2.0, 4.0), rng.uniform(1.0, 1.8), 0.0, cv.col(3), 0.8)


def p_leaf(cv, spec):
    """Mangrove crowns: clusters of oval leaves, dark inside and lit on top, the WoW crown read as soft clumps."""
    rng = cv.rng
    W, H = cv.w, cv.h
    pv.generic_ground(cv, 60, 0, 0.0, 3.0, (1.0, 1.6), big_size=(0.1, 0.25), weights=(0.45, 0.4, 0.15, 0.0))
    for _ in range(int(900 * (W / 1024) ** 2)):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(0.05, 0.12) * cv.ppm_x
        for k in range(rng.integers(4, 8)):
            a = rng.uniform(0, 2 * math.pi)
            px, py = cx + math.cos(a) * r * 0.6, cy + math.sin(a) * r * 0.5
            lit = 1.0 - (py - cy + r) / (2 * r)
            cv.dab(px, py + 2, r * 0.42, r * 0.2, a, cv.col(0) * 0.8, 0.6, hgt=0.2)
            cv.dab(px, py, r * 0.4, r * 0.18, a, cv.col(0.8 + 1.8 * lit + rng.uniform(-0.3, 0.3)), 0.95, hgt=0.6)


def p_fish(cv, spec):
    """Split dried fish: warm brown flesh with a silver skin edge, rib stripes across."""
    rng = cv.rng
    W, H = cv.w, cv.h
    pv.generic_ground(cv, 40, 80, 0.0, 0.1, (2, 4), weights=(0.2, 0.4, 0.3, 0.1))
    for x in np.arange(0, W, W / 14):
        for yy in np.arange(0, H, 6):
            cv.dab(x + rng.uniform(-2, 2), yy, 1.8, 4, 0.3, cv.col(0) * 0.85, 0.6, hgt=-0.4)
    y = np.arange(H)
    band = np.exp(-(((y / H) % 1.0 - 0.1) / 0.06) ** 2)
    cv.rgb = cv.rgb * (1 - 0.5 * band[:, None, None]) + hex_lin("#cfd6d4") * 0.5 * band[:, None, None]


def p_tally(cv, spec):
    """The tally post's face (unit UV, the post's height = 1 V): weathered timber with cut tally notches in groups of
    four and a slash, a ring cut at the top for the mooring; marks and tallies only, never writing."""
    p_pile(cv, spec)
    W, H = cv.w, cv.h
    y, x = np.mgrid[0:H, 0:W]
    dark = cv.ramp[0] * 0.6
    lip = cv.ramp[3]
    rng = cv.rng
    ty = H * 0.16
    while ty < H * 0.82:
        for k in range(4):
            yy = ty + k * 16
            m = (np.abs(y - yy) < 3.0) & (x > W * 0.22) & (x < W * 0.78)
            cv.rgb[m] = cv.rgb[m] * 0.35 + dark * 0.65
            m2 = (np.abs(y - yy - 4.5) < 1.3) & (x > W * 0.22) & (x < W * 0.78)
            cv.rgb[m2] = cv.rgb[m2] * 0.5 + lip * 0.5
        X0, Y0 = W * 0.18, ty - 8
        d = np.abs((x - X0) * 64 - (y - Y0) * (W * 0.64)) / math.hypot(64, W * 0.64)
        m = (d < 2.8) & (y > Y0) & (y < Y0 + 64) & (x > W * 0.16) & (x < W * 0.84)
        cv.rgb[m] = cv.rgb[m] * 0.35 + dark * 0.65
        ty += 96 + rng.uniform(0, 30)
    r = np.hypot(x - W / 2, y - H * 0.07)
    m = np.abs(r - W * 0.2) < 3.5
    cv.rgb[m] = cv.rgb[m] * 0.35 + dark * 0.65


def p_oldstone(cv, spec):
    """Old dressed stone that has lain in the marsh for centuries: big dark blocks, soft worn edges, a green-black
    algae skin low and moss on the tops (the drowned-stone look; review-only in this kit)."""
    rng = cv.rng
    W, H = cv.w, cv.h
    pv.p_limestone(cv, spec)
    cv.rgb *= 0.72
    algae = [hex_lin(c) for c in ramp_of("r1.moss")]
    for _ in range(260):
        yy = rng.uniform(0, H)
        cv.dab(rng.uniform(0, W), yy, rng.uniform(8, 30), rng.uniform(4, 12), rng.uniform(0, 3),
               algae[rng.integers(0, 3)] * 0.75, rng.uniform(0.25, 0.6), hgt=0.3)
    for _ in range(40):   # block joints: long cut lines
        x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
        horiz = rng.random() < 0.6
        L = rng.uniform(0.15, 0.4) * W
        cv.dab(x0, y0, L, 2.4, 0.0 if horiz else math.pi / 2, cv.col(0) * 0.6, 0.85, hgt=-1.0, wobble=0.0)


def net_rgba(spec, seed):
    """A knotted fishing net: diamond mesh of 8 cm (at 1 UV = 1 m), rope-coloured twine with knots; alpha cut."""
    W = spec["px"]
    rgb = np.zeros((W, W, 3)) + hex_lin(ramp_of("r1.rope")[1])
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:W, 0:W].astype(np.float64)
    cell = W / 12.0
    u, v = (x + y) / cell, (x - y) / cell
    du = np.abs(u - np.round(u)) * cell / math.sqrt(2)
    dv = np.abs(v - np.round(v)) * cell / math.sqrt(2)
    d = np.minimum(du, dv)
    a = np.clip(1.6 - d / 1.4, 0, 1)
    knot = (np.abs(u - np.round(u)) * cell < 4.5) & (np.abs(v - np.round(v)) * cell < 4.5)
    a = np.maximum(a, knot * 1.0)
    ramp = [hex_lin(c) for c in ramp_of("r1.rope")]
    shade = 0.5 + 0.5 * np.cos(np.clip(d / 2.2, 0, 1) * math.pi / 2)
    rgb = ramp[0] * (1 - shade[..., None]) + ramp[2] * shade[..., None]
    rgb[knot] = ramp[1]
    tone = 1.0 + 0.12 * pv.lowfreq(rng, W, W, 2)
    rgb *= tone[..., None]
    return np.clip(pv.lin_srgb(rgb), 1 / 255, 254 / 255), a


def reedcard_rgba(spec, seed):
    """The reed atlas: 4 cells of 256 x 512 (gold reeds, green reeds, gold with cattails, green with cattails). Blades are
    tapered curved strokes from the root, dark at the root and lit to the tip, each with a lit edge; cattail heads fat
    brown capsules; reed plumes soft panicles. Alpha = the union of the strokes."""
    Wt, Ht = spec["px"], spec["py"]
    cw = Wt // 4
    rgb = np.zeros((Ht, Wt, 3))
    al = np.zeros((Ht, Wt))
    rng = np.random.default_rng(seed)
    ramps = {"gold": [hex_lin(c) for c in ramp_of("reed_gold")], "green": [hex_lin(c) for c in ramp_of("reed_green")]}
    cattail = [hex_lin(c) for c in ramp_of("mangrove_root")]

    def disc(cx, cy, r, col, a_=1.0):
        e = int(r) + 2
        x0, x1 = max(int(cx) - e, 0), min(int(cx) + e + 1, Wt)
        y0, y1 = max(int(cy) - e, 0), min(int(cy) + e + 1, Ht)
        if x1 <= x0 or y1 <= y0:
            return
        X, Y = np.meshgrid(np.arange(x0, x1) - cx, np.arange(y0, y1) - cy)
        m = np.clip((r - np.hypot(X, Y)) / 0.9 + 0.5, 0, 1) * a_
        rgb[y0:y1, x0:x1] = rgb[y0:y1, x0:x1] * (1 - m[..., None]) + np.asarray(col) * m[..., None]
        al[y0:y1, x0:x1] = np.maximum(al[y0:y1, x0:x1], m)

    for cell, (fam, extra) in enumerate((("gold", None), ("green", None), ("gold", "cattail"), ("green", "cattail"))):
        R = ramps[fam]
        ox = cell * cw
        n = 30
        for k in range(n):
            base_x = ox + cw * (0.12 + 0.76 * rng.beta(2, 2))
            h = Ht * rng.uniform(0.55, 0.97)
            lean = rng.normal(0, 0.16) * h
            curl = rng.normal(0, 0.12) * h
            w0 = rng.uniform(5.0, 9.5)
            steps = int(h / 2)
            for i in range(steps):
                t = i / steps
                x = base_x + lean * t + curl * t * t
                yv = Ht - 1 - h * t
                if x < ox + 2 or x > ox + cw - 3:
                    continue
                w = w0 * (1 - t) ** 0.8 + 0.6
                c = R[0] * (1 - t) + R[2] * t if t < 0.8 else R[2] * (1 - (t - 0.8) * 2) + R[3] * (t - 0.8) * 2
                c = c * (1 + rng.uniform(-0.04, 0.04))
                disc(x, yv, w, c)
                if w > 1.6:
                    disc(x - w * 0.45, yv, w * 0.35, R[3] * 0.6 + c * 0.4, 0.8)
            if extra == "cattail" and rng.random() < 0.45:
                tx, ty = base_x + lean + curl, Ht - 1 - h
                for j in range(20):
                    disc(tx + (lean + curl) / h * j, ty + 12 + j, 4.2, cattail[1] if j % 6 else cattail[0])
                    disc(tx + (lean + curl) / h * j - 1.6, ty + 12 + j, 1.4, cattail[3])
            if extra == "plume" and rng.random() < 0.5:
                tx, ty = base_x + lean + curl, Ht - 1 - h
                for j in range(30):
                    disc(tx + rng.normal(0, 5) + j * 0.4, ty + rng.uniform(0, 34), rng.uniform(1.5, 3.5),
                         ramps["gold"][3] * 0.8 + ramps["gold"][2] * 0.2, 0.85)
    return np.clip(pv.lin_srgb(rgb), 1 / 255, 254 / 255), al


# ------------------------------------------------------------------------------------------------ dispatch
PAINTERS = dict(pv.PAINTERS, pile=p_pile, bundle=p_bundle, bark=p_bark, leaf=p_leaf, fish=p_fish, oldstone=p_oldstone)
CAVITY = dict(pv.CAVITY, pile=(0.4, pv.COOL_WOOD), bundle=(0.4, pv.COOL_WOOD), bark=(0.42, pv.COOL_WOOD),
              leaf=(0.45, pv.COOL_GREEN), fish=(0.25, pv.COOL_WOOD), oldstone=(0.5, pv.COOL_ROCK))
EDGE_LIGHT = pv.EDGE_LIGHT | {"pile", "bark", "oldstone"}


def seed_of(key):
    return zlib.crc32(("thuyvan-dong-lau-" + key).encode()) & 0x7FFFFFFF


def palette_view():
    """The village painters look ramps up by name in one dict: hand them dong_lau's ramps plus r1's dyes."""
    p = dict(PALJ["r1"])
    p.update(PALJ["dong_lau"])
    return p


def paint(key, spec):
    """Returns (srgb float HxWx3, alpha HxW or None)."""
    seed = seed_of(key)
    painter = spec["painter"]
    if painter == "net":
        return net_rgba(spec, seed)
    if painter == "reedcard":
        return reedcard_rgba(spec, seed)
    w = spec["px"]
    h = spec.get("py", w)
    ppm = w / 1.2 if spec.get("unit_uv") else w / spec["tile_m"]
    cv = Canvas(w, h, ramp_of(spec["ramp"]), seed, ppm, ppm if not spec.get("unit_uv") else h / 4.2)
    if painter == "banner":
        pv.p_banner(cv, spec, palette_view())
        cv.variation(0.06, 3, 0.06)
        return cv.finish(spec.get("value")), None
    if painter == "tally":
        cv.variation()
        p_tally(cv, spec)
        cv.cavity(0.35, pv.COOL_WOOD)
        return cv.finish(spec.get("value")), None
    if painter == "lacquer":
        cv.variation(0.06, 1.0, 0.04)
    else:
        cv.variation()
    PAINTERS[painter](cv, spec)
    st, cool = CAVITY[painter]
    cv.cavity(st, cool)
    if painter in EDGE_LIGHT:
        cv.edge_light(0.17)
    return cv.finish(spec.get("value")), None


# ------------------------------------------------------------------------------------------------ marsh skies
def paint_skies(out_dir, W=4096):
    """The three directions' panoramas with PAINT's sky painter (tools/thuyvan_art/paint/paint_sky.py's Sky, imported):
    a low overcast deck, evening bars, or morning cumulus; two far bands of low karst hills in the mist on the horizon
    (the Đồng Lau sheet's far hills), mist lines along the water."""
    sys.path.insert(0, os.path.join(HERE, "..", "paint"))
    import paint_sky as ps  # noqa: E402
    import tvp  # noqa: E402
    dirs = json.load(open(os.path.join(HERE, "directions.json")))
    os.makedirs(out_dir, exist_ok=True)
    for name, d in dirs.items():
        if name.startswith("_"):
            continue
        s = ps.Sky(W, seed_of("sky-" + name), d)
        s.gradient()
        rng = s.rng
        sk = d["sky"]
        T = d["targets"]
        if name == "silver_overcast":
            for i in range(34):
                s.bank(rng.uniform(-180, 180), rng.uniform(6, 40), rng.uniform(50, 120), rng.uniform(5, 12), 0.75)
            for i in range(14):
                s.heap(rng.uniform(-180, 180), rng.uniform(4, 14), rng.uniform(24, 46), rng.uniform(5, 10), 40,
                       opacity=0.7)
        elif name == "smoke_and_lantern":
            s.bars(80, (2.0, 26.0), (20, 70))
            for i in range(6):
                s.heap(rng.uniform(-180, 180), rng.uniform(5, 12), rng.uniform(16, 30), rng.uniform(4, 8), 26,
                       lit_below=True, opacity=0.75)
        else:
            for i in range(3):
                s.heap(-150 + i * 110 + rng.uniform(-25, 25), rng.uniform(3, 6), rng.uniform(40, 60),
                       rng.uniform(16, 24), 100)
            for i in range(8):
                s.heap(rng.uniform(-180, 180), rng.uniform(5, 14), rng.uniform(12, 24), rng.uniform(4, 8), 30)
            for i in range(6):
                s.bank(rng.uniform(-180, 180), rng.uniform(0.5, 3.0), rng.uniform(40, 80), 2.0, 0.5)
        far = ps.srgb(T["far_karst"])
        hz = ps.srgb(sk["horizon"])
        s.karst_band(4.2, 0.0, 40, ps.tvp_hex(tvp.mix(far, hz, 0.45)), ps.tvp_hex(tvp.mix(far, hz, 0.25)), sk["horizon"],
                     width=(2.0, 5.0))
        s.mist_line(1.2, 2.0, T["mist"], 0.55)
        s.karst_band(2.6, 0.0, 26, ps.tvp_hex(tvp.mix(far, ps.srgb(T["mid_karst_lit"]), 0.4)),
                     ps.tvp_hex(tvp.mix(far, ps.srgb(T["karst_shade"]), 0.4)), d["fog"]["color"], width=(2.5, 6.0))
        s.mist_line(0.3, 1.2, T["mist"], 0.7)
        c = tvp.blur(s.cv.col, 0.5)
        Image.fromarray(tvp.to_u8(tvp.l2s(c))).save(os.path.join(out_dir, "dl_sky_%s.png" % name))
        print("SKY", name)


def check_image(srgb, alpha, path):
    if alpha is not None:
        bg = np.array([0.93, 0.91, 0.86])
        srgb = srgb * alpha[..., None] + bg * (1 - alpha[..., None])
    pv.check_image(srgb, path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--check-dir", default="")
    ap.add_argument("--sky-dir", default="")
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    mats = json.load(open(os.path.join(HERE, "materials.json")))
    os.makedirs(a.out, exist_ok=True)
    only = set(filter(None, a.only.split(",")))
    report = {}
    for key, spec in mats["keys"].items():
        if only and key not in only:
            continue
        srgb, alpha = paint(key, spec)
        if alpha is None:
            img = Image.fromarray((srgb * 255 + 0.5).astype(np.uint8))
        else:
            rgba = np.concatenate([srgb, alpha[..., None]], -1)
            img = Image.fromarray((rgba * 255 + 0.5).astype(np.uint8))
        img.save(os.path.join(a.out, key + ".png"), optimize=True)
        lum = luma(srgb) if alpha is None else luma(srgb)[alpha > 0.5]
        report[key] = {"mean": round(float(lum.mean()), 3), "min": round(float(lum.min()), 3),
                       "max": round(float(lum.max()), 3), "size": list(img.size), "alpha": alpha is not None}
        if a.check_dir:
            os.makedirs(a.check_dir, exist_ok=True)
            check_image(srgb, alpha, os.path.join(a.check_dir, key + "_check.png"))
        print("PAINT %-14s %s mean %.3f" % (key, img.size, report[key]["mean"]))
    if a.check_dir:
        with open(os.path.join(a.check_dir, "paint_report.json"), "w") as f:
            json.dump(report, f, indent=1)
    if a.sky_dir:
        paint_skies(a.sky_dir)


if __name__ == "__main__":
    main()
