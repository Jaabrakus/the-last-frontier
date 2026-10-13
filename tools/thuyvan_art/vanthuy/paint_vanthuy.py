"""Paint the Vạn Thủy kit's textures (VANTHUY; style guide section 3.2, the brush recipe).

    python3 tools/thuyvan_art/vanthuy/paint_vanthuy.py [--only key,key] [--check-dir DIR]

Reads materials.json (one row per material key) and the art director's palettes.json (albedo.van_thuy, and albedo.r1
for the cross-zone basics; never retyped) plus materials.json's proposal_ramps. Writes
assets/thuyvan/vanthuy/textures/<key>.png (sRGB, opaque) and, with --check-dir, each texture's <key>_check.png (the
3 x 3 tiling at 1/8 and the 1/16 squint) and paint_report.json (mean value against the style guide's value budget).

The brush engine is the VILLAGE kit's (tools/thuyvan_art/village/paint_village.py: the torus Canvas, its painters for
planks, tile, lacquer, rope, cloth and the rest, the cavity and edge-light passes and the finish), imported unchanged so
the two kits' surfaces read as one hand. This file adds the city's own painters: big ashlar coursing with pale patched
blocks, quay paving, bronze with verdigris, battened sail cloth, the court and district banners with our own marks
(marks_vt.py), the gate plaque and the blank notice sheets. Fixed seeds: the same inputs rebuild the same bytes.
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
sys.path.insert(0, os.path.join(REPO, "tools", "thuyvan_art", "village"))
sys.path.insert(0, HERE)
import marks  # noqa: E402  (the village marks table; ours are added to it)
import marks_vt  # noqa: E402
import paint_village as pv  # noqa: E402

marks_vt.register(marks)
OUT = os.path.join(REPO, "assets", "thuyvan", "vanthuy", "textures")
PALETTES = os.path.join(REPO, "docs", "thuyvan", "plan", "look", "palettes.json")
hex_lin = pv.hex_lin


def load_ramps():
    """{'van_thuy:river': [...], 'r1:rope': [...], 'proposal:gilt': [...]} from the art director's file + proposals."""
    albedo = json.load(open(PALETTES))["albedo"]
    mats = json.load(open(os.path.join(HERE, "materials.json")))
    out = {}
    for zone in ("r1", "van_thuy"):
        for k, v in albedo[zone].items():
            if not k.startswith("_"):
                out[zone + ":" + k] = v
    for k, v in mats["proposal_ramps"].items():
        if not k.startswith("_"):
            out["proposal:" + k] = v
    return out, mats


# ------------------------------------------------------------------------------------------------ the city's painters
def _rect(cv, x0, y0, w, h, color, hgt=1.0, alpha=1.0):
    """A hard-edged block (wraps on the torus)."""
    xs = np.arange(int(round(x0)), int(round(x0 + w))) % cv.w
    ys = np.arange(int(round(y0)), int(round(y0 + h))) % cv.h
    if len(xs) == 0 or len(ys) == 0:
        return
    if alpha >= 1.0:
        cv.rgb[np.ix_(ys, xs)] = color
    else:
        cv.rgb[np.ix_(ys, xs)] = cv.rgb[np.ix_(ys, xs)] * (1 - alpha) + np.asarray(color) * alpha
    cv.hgt[np.ix_(ys, xs)] = hgt
    cv.big[np.ix_(ys, xs)] = 1.0


def p_ashlar(cv, spec, ground=False):
    """Oversized ashlar (1.5-2.5 m blocks; old masonry 2-3 m): rows of flat-painted blocks, thin cool joints, a lit top
    lip and a shaded foot on each block (walls only), chipped arrises, a few pale new blocks set into the old courses
    (the city's patched steps and walls: royal renovation hides repair joints instead of replacing the stones)."""
    rng = cv.rng
    W, H = cv.w, cv.h
    joint = 0.06 * cv.ppm_x
    jc = cv.ramp[0] * 0.55 + hex_lin(pv.COOL_ROCK) * 0.25
    cv.floor = jc * 0.9
    cv.rgb[:] = jc
    cv.hgt[:] = -1.0
    rows, y = [], 0.0
    bh0, bh1 = spec.get("block_h", [1.2, 1.9])
    while y < H - bh0 * 0.6 * cv.ppm_y:
        h = rng.uniform(bh0, bh1) * cv.ppm_y
        rows.append([y, h])
        y += h
    s = H / y
    bw0, bw1 = spec.get("block_w", [1.5, 2.6])
    for (y0, rh) in rows:
        y0, rh = y0 * s, rh * s
        x = rng.uniform(0, W)
        xe = x + W
        while x < xe - 0.5 * bw0 * cv.ppm_x:
            bw = min(rng.uniform(bw0, bw1) * cv.ppm_x, xe - x)
            patched = rng.random() < spec.get("patch", 0.0)
            base = 2.55 if patched else rng.uniform(*spec.get("base", (0.75, 1.75)))
            c = cv.col(base, 0.04)
            _rect(cv, x + joint / 2, y0 + joint / 2, bw - joint, rh - joint, c, hgt=1.0)
            # broad planes inside the block: two or three flat strokes a step lighter or darker
            for _ in range(rng.integers(2, 5)):
                L = rng.uniform(0.25, 0.6) * bw
                cv.dab(x + rng.uniform(0.2, 0.8) * bw, y0 + rng.uniform(0.25, 0.75) * rh, L / 2, L / 2 / rng.uniform(1.6, 3),
                       rng.normal(0, 0.15), cv.col(np.clip(base + rng.uniform(-0.45, 0.45), 0, 2.9)), 0.55, edge=0.6,
                       wobble=0.1)
            if not ground:
                _rect(cv, x + joint / 2, y0 + joint / 2, bw - joint, rh * 0.07, cv.col(min(base + 0.8, 2.95)), 1.0,
                      alpha=0.75)                                    # the lit top lip
                _rect(cv, x + joint / 2, y0 + rh * 0.86, bw - joint, rh * 0.14 - joint / 2, cv.col(max(base - 0.6, 0)),
                      0.9, alpha=0.6)                                # the shaded foot
            for _ in range(rng.integers(0, 3)):                      # chipped arrises
                cx = x + (joint if rng.random() < 0.5 else bw - joint)
                cy = y0 + rng.uniform(0.1, 0.9) * rh
                r = rng.uniform(0.06, 0.16) * cv.ppm_x
                cv.dab(cx, cy, r, r * 0.7, rng.uniform(0, 3), jc * 1.2, 0.95, hgt=-0.8)
            x += bw
    # long water and silt stains running down the courses (walls), worn paths (ground)
    stain = cv.ramp[0] * 0.7 + hex_lin("#2c3a3c") * 0.3
    for _ in range(int(16 * W / 1024)):
        if ground:
            L = rng.uniform(0.1, 0.3) * W
            cv.dab(rng.uniform(0, W), rng.uniform(0, H), L, L * 0.5, rng.uniform(0, 3), cv.col(2.2), 0.18, edge=0.3)
        else:
            cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.15, 0.4) * H, rng.uniform(0.04, 0.12) * cv.ppm_x,
                   math.pi / 2, stain, rng.uniform(0.15, 0.3), edge=0.4, wobble=0.04)
    # moss in a few joints (accent stop of the old masonry ramp is moss)
    if spec["ramp"].endswith("old_masonry"):
        for _ in range(60):
            cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(6, 22), rng.uniform(3, 8), rng.normal(0, 0.2),
                   cv.ramp[3], 0.7)


def p_paving(cv, spec):
    """Quay paving: big flags (0.8-1.6 m) laid in courses, direction-free light, worn pale where feet go."""
    spec = dict(spec, block_h=[0.8, 1.3], block_w=[0.9, 1.7], patch=0.05)
    p_ashlar(cv, spec, ground=True)


def p_bronze(cv, spec):
    """Cast bronze: warm brown body, rubbed lighter highlights, verdigris (the accent) running down from edges."""
    rng = cv.rng
    W, H = cv.w, cv.h
    pv.generic_ground(cv, 70, 220, 0.0, 3.0, (1.0, 1.8), weights=(0.3, 0.45, 0.25, 0.0))
    for _ in range(int(40 * W / 512)):
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.04, 0.12) * W, rng.uniform(0.01, 0.03) * W,
               rng.normal(0, 0.4), cv.col(2.4), 0.5, edge=0.5)
    for _ in range(int(26 * W / 512)):                               # verdigris tears
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        cv.dab(x, y, rng.uniform(0.08, 0.25) * H, rng.uniform(0.012, 0.03) * W, math.pi / 2 + rng.normal(0, 0.05),
               cv.ramp[3], rng.uniform(0.45, 0.8), hgt=0.2, edge=0.55, wobble=0.06)
        cv.dab(x, y - 0.05 * H, rng.uniform(0.02, 0.05) * W, rng.uniform(0.02, 0.04) * W, 0, cv.ramp[3] * 1.2, 0.7)


def p_sail(cv, spec):
    """Battened sail cloth: vertical bolts of canvas 0.6 m wide with seams, a few patches of fresher or older cloth,
    weather stains low; the battens themselves are geometry."""
    rng = cv.rng
    W, H = cv.w, cv.h
    pv.p_cloth(cv, spec)
    bolt = 0.6 * cv.ppm_x
    n = max(1, int(round(W / bolt)))
    bolt = W / n
    for k in range(n):
        x = k * bolt
        tone = cv.col(rng.uniform(0.9, 2.1), 0.02)
        _rect(cv, x + 2, 0, bolt - 4, H, tone, hgt=0.6, alpha=0.35)
        for yy in np.arange(0, H, 18):                               # the seam: a dark line and a lit stitch line
            cv.dab(x, yy + 9, 1.4, 10, 0, cv.col(0) * 0.9, 0.7, hgt=-0.5, wobble=0)
            cv.dab(x + 3.5, yy + 9, 1.0, 9, 0, cv.col(2.8), 0.5, wobble=0)
    for _ in range(int(4 * W / 1024)):                               # patches
        pw, ph = rng.uniform(0.35, 0.9) * cv.ppm_x, rng.uniform(0.3, 0.8) * cv.ppm_y
        x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
        _rect(cv, x0, y0, pw, ph, cv.col(rng.choice([1.0, 2.2]), 0.03), hgt=0.8, alpha=0.55)
        for (xa, ya, xb, yb) in ((x0, y0, x0 + pw, y0), (x0, y0 + ph, x0 + pw, y0 + ph)):
            for xx in np.arange(xa, xb, 10):
                cv.dab(xx, ya, 3.5, 1.0, 0, cv.col(0), 0.6, wobble=0)
    for _ in range(int(14 * W / 1024)):                              # weather stains
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.1, 0.3) * W, rng.uniform(0.05, 0.12) * W,
               rng.uniform(0, 3), cv.col(0.4), 0.15, edge=0.3)


def vt_mark(cv, name, cx, cy, size, color):
    """Stamp a mark like the VILLAGE cloth_mark (dyed, slightly ragged edges), but with filled shapes solid inside:
    the village sdf gives a polygon's inside a token depth, deepened here so the dye noise only frays the edges."""
    W, H = cv.w, cv.h
    y, x = np.mgrid[0:H, 0:W]
    X = (x - cx) / (size / 2)
    Y = -(y - cy) / (size / 2)
    d = marks.sdf(name, X, Y)
    d = np.where(d <= -0.0099, -0.06, d)
    n = pv.lowfreq(cv.rng, H, W, 12) * 0.02
    m = np.clip(0.5 - (d + n) / 0.03, 0.0, 1.0)
    cv.rgb = cv.rgb * (1 - m[..., None] * 0.94) + np.asarray(color) * m[..., None] * 0.94
    return m


def double_border(cv, x0, x1, color, w=0.03):
    """Two plain lines down a banner's long edges (the court's cloth: plain borders, no textile zig-zag)."""
    W = cv.w
    for xa in (x0, x1):
        for off in (0.0, 0.055):
            xc = W * (xa + (off if xa < 0.5 else -off))
            xs = np.arange(int(xc - W * w / 2), int(xc + W * w / 2) + 1) % W
            cv.rgb[:, xs] = cv.rgb[:, xs] * 0.12 + np.asarray(color) * 0.88


def p_banner_vt(cv, spec, ramps):
    """Court or district banner (unit UVs, 1:4 or 1:3): cloth folds, a darker pole sleeve, plain double borders and a
    hem band in the ink colour, the mark in the upper third; worn darker at the edges and hem."""
    W, H = cv.w, cv.h
    pv.p_cloth(cv, spec)
    ink_ramp = ramps[spec["ink"]]
    ink = hex_lin(ink_ramp[2] if spec["ink"] != "proposal:gilt" else ink_ramp[2])
    cv.rgb[: int(H * 0.05)] *= 0.6
    double_border(cv, 0.07, 0.93, ink, 0.022)
    yb = int(H * 0.86)
    cv.rgb[yb:yb + max(2, int(H * 0.012))] = cv.rgb[yb:yb + max(2, int(H * 0.012))] * 0.1 + ink * 0.9
    yb2 = int(H * 0.06)
    cv.rgb[yb2:yb2 + max(2, int(H * 0.01))] = cv.rgb[yb2:yb2 + max(2, int(H * 0.01))] * 0.1 + ink * 0.9
    m = vt_mark(cv, spec["mark"], W / 2, H * (0.30 if H / W >= 3.9 else 0.38), W * 0.72, ink)
    if spec["ink"] == "proposal:gilt":                             # gilt thread: a lighter rim on the mark's top edge
        sh = np.roll(m, 3, axis=0)
        rim = np.clip(m - sh, 0, 1)
        cv.rgb = cv.rgb * (1 - rim[..., None] * 0.6) + hex_lin(ink_ramp[3]) * rim[..., None] * 0.6
    x = np.arange(W)
    edge = np.exp(-np.minimum(x, W - 1 - x) / (W * 0.05))
    cv.rgb *= (1 - 0.22 * edge)[None, :, None]
    yy = np.arange(H) / H
    cv.rgb *= (1 - 0.2 * np.clip((yy - 0.88) / 0.12, 0, 1))[:, None, None]


def p_plaque(cv, spec, ramps):
    """The gate plaque on the gate towers' faces (our own gate mark in place of the sheets' roundels): an indigo board
    with a gilt rim and the court mark in gilt, lacquered smooth."""
    W, H = cv.w, cv.h
    pv.generic_ground(cv, 40, 120, math.pi / 2, 0.1, (2, 4), weights=(0.2, 0.5, 0.3, 0.0), sliver_free=False)
    gl = [hex_lin(c) for c in ramps[spec["ink"]]]
    y, x = np.mgrid[0:H, 0:W]
    d = np.minimum.reduce([x, W - 1 - x, y, H - 1 - y]) / W
    rim = (d < 0.06).astype(float)
    cv.rgb = cv.rgb * (1 - rim[..., None]) + (gl[1] * (1 - d / 0.06)[..., None] * 0.4 + gl[2] * 0.6) * rim[..., None]
    inner = ((d > 0.085) & (d < 0.1)).astype(float)
    cv.rgb = cv.rgb * (1 - inner[..., None] * 0.9) + gl[2] * inner[..., None] * 0.9
    m = vt_mark(cv, spec["mark"], W / 2, H / 2, W * 0.74, gl[2])
    sh = np.roll(np.roll(m, 3, axis=0), 2, axis=1)
    cv.rgb = cv.rgb * (1 - np.clip(sh - m, 0, 1)[..., None] * 0.5) + cv.ramp[0] * np.clip(sh - m, 0, 1)[..., None] * 0.5
    lip = np.clip(m - np.roll(m, -2, axis=0), 0, 1)
    cv.rgb = cv.rgb * (1 - lip[..., None] * 0.7) + gl[3] * lip[..., None] * 0.7


def p_notice(cv, spec, ramps):
    """The notice board's sheets (unit UVs): old paste and torn scraps under five or six pinned sheets, each blank
    (text comes from the approved OFL font at run time, never baked), official ones stamped with the court mark in
    indigo; ruled margins only."""
    rng = cv.rng
    W, H = cv.w, cv.h
    timber = [hex_lin(c) for c in ramps["van_thuy:dock_timber"]]
    cv.rgb[:] = timber[1] * 0.8
    for _ in range(140):
        cv.dab(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(6, 30), rng.uniform(3, 12), rng.uniform(0, 3),
               cv.col(rng.uniform(0.0, 1.2)), 0.6)
    ink = hex_lin(ramps["van_thuy:court_banner"][1])
    sheets = [(0.04, 0.05, 0.30, 0.55), (0.37, 0.04, 0.27, 0.42), (0.68, 0.07, 0.28, 0.50), (0.06, 0.62, 0.36, 0.33),
              (0.47, 0.52, 0.22, 0.42), (0.73, 0.62, 0.23, 0.33)]
    for k, (sx, sy, sw, sh) in enumerate(sheets):
        x0, y0, w, h = sx * W, sy * H, sw * W, sh * H
        _rect(cv, x0 + 3, y0 + 4, w, h, timber[0] * 0.7, hgt=0.0, alpha=0.5)        # its shadow
        _rect(cv, x0, y0, w, h, cv.col(rng.uniform(1.6, 2.6), 0.02), hgt=1.0)
        for _ in range(6):
            cv.dab(x0 + rng.uniform(0, w), y0 + rng.uniform(0, h), rng.uniform(8, 20), rng.uniform(4, 10),
                   rng.uniform(0, 3), cv.col(rng.uniform(1.4, 2.4)), 0.35)
        for xx in (x0 + w * 0.08, x0 + w * 0.92):                                  # ruled margins
            xs = np.arange(int(xx), int(xx) + 1) % W
            ys = np.arange(int(y0 + h * 0.06), int(y0 + h * 0.94)) % H
            cv.rgb[np.ix_(ys, xs)] = cv.rgb[np.ix_(ys, xs)] * 0.7 + cv.ramp[0] * 0.3
        if k in (0, 2, 4):
            vt_mark(cv, "court_gate", x0 + w * 0.74, y0 + h * 0.82, min(w, h) * 0.28, ink)
        for (px, py) in ((x0 + w * 0.5, y0 + 6),):
            cv.dab(px, py, 4, 4, 0, hex_lin("#2e2c2a"), 1.0)
        if rng.random() < 0.5:                                                     # a torn corner
            cv.dab(x0 + w, y0 + h, w * 0.18, h * 0.1, 0.6, timber[1] * 0.8, 1.0)


PAINTERS = {"ashlar": p_ashlar, "paving": p_paving, "bronze": p_bronze, "sail": p_sail}
CAVITY = dict(pv.CAVITY, ashlar=(0.4, pv.COOL_ROCK), paving=(0.35, pv.COOL_ROCK), bronze=(0.35, "#2a2a30"),
              sail=(0.25, pv.COOL_WOOD))
EDGE_LIGHT = pv.EDGE_LIGHT | {"ashlar", "bronze"}


def seed_of(key):
    return zlib.crc32(("thuyvan-vanthuy-" + key).encode()) & 0x7FFFFFFF


def paint(key, spec, ramps):
    seed = seed_of(key)
    painter = spec["painter"]
    w = spec["px"]
    h = spec.get("py", w)
    ppm = w / 1.2 if spec.get("unit_uv") else w / spec["tile_m"]
    cv = pv.Canvas(w, h, ramps[spec["ramp"]], seed, ppm, ppm if not spec.get("unit_uv") else h / 4.2)
    if painter == "banner":
        p_banner_vt(cv, spec, ramps)
        cv.variation(0.05, 2, 0.05)
        return cv.finish(spec.get("value"))
    if painter == "plaque":
        p_plaque(cv, spec, ramps)
        return cv.finish(spec.get("value"))
    if painter == "notice":
        p_notice(cv, spec, ramps)
        return cv.finish(None)
    if painter == "lacquer":
        cv.variation(0.06, 1.0, 0.04)
    else:
        cv.variation()
    (PAINTERS.get(painter) or pv.PAINTERS[painter])(cv, spec)
    st, cool = CAVITY[painter]
    cv.cavity(st, cool)
    if painter in EDGE_LIGHT:
        cv.edge_light(0.17)
    return cv.finish(spec.get("value"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--check-dir", default="")
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    ramps, mats = load_ramps()
    os.makedirs(a.out, exist_ok=True)
    only = set(filter(None, a.only.split(",")))
    report = {}
    for key, spec in mats["keys"].items():
        if only and key not in only:
            continue
        srgb = paint(key, spec, ramps)
        img = Image.fromarray((srgb * 255 + 0.5).astype(np.uint8))
        p = os.path.join(a.out, key + ".png")
        img.save(p, optimize=True)
        mean = float(pv.luma(srgb).mean())
        report[key] = {"mean": round(mean, 3), "target": spec.get("value"), "min": round(float(pv.luma(srgb).min()), 3),
                       "max": round(float(pv.luma(srgb).max()), 3), "size": list(img.size)}
        if a.check_dir:
            os.makedirs(a.check_dir, exist_ok=True)
            pv.check_image(srgb, os.path.join(a.check_dir, key + "_check.png"))
        print("PAINT %-15s %s mean %.3f (target %s) range %.2f-%.2f" % (key, img.size, mean, spec.get("value"),
                                                                       report[key]["min"], report[key]["max"]))
    if a.check_dir:
        with open(os.path.join(a.check_dir, "paint_report.json"), "w") as f:
            json.dump(report, f, indent=1)


if __name__ == "__main__":
    main()
