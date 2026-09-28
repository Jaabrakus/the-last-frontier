#!/usr/bin/env python3
"""Ground texture arrays for the Frontier terrain (look-dev spec, section 5.4). Package B.

Reads the approved CC0 Poly Haven 2K sets from assets/polyhaven/textures/terrain (read-only),
grades them offline to the section 13 albedo targets and packs them into two 7-slice arrays:

  assets/environment/terrain/textures/terrain_albedo_array.webp   RGB graded albedo, A height
  assets/environment/terrain/textures/terrain_nrm_array.webp      RG normal (OpenGL), B rough, A AO

(vertical strips, 2048 x 14336 and 1024 x 7168; imported as CompressedTexture2DArray, BPTC,
with mipmaps). The normal/roughness/AO array is 1K per slice: its detail fades out by 60 m and
2K would cost another 29 MB of VRAM (texture budget 90 MB, spec 5.4).
Deterministic and re-runnable. Slices (FrontierTerrain / terrain.gdshader order):

  0 grass       aerial_grass_rock   hue -3 deg, saturation -10 %            (tiled 15 m, macro)
  1 dry grass   aerial_grass_rock   hue +12 deg, saturation -20 %, value +12 %
  2 dirt        dirt_floor          linear value x0.62, saturation -15 %    (tiled 3 m)
  3 mud         mud_forest          linear value x1.35, saturation -10 %    (tiled 3 m)
  4 forest      forest_ground_04    saturation -8 %                        (tiled 3 m; also the
                                                                            grass close detail)
  5 rock        forest_ground_04    linear value x0.8, saturation -60 %     (tiled 4 m)
  6 leaves      forest_leaves_04    saturation -30 %, hue -4 deg            (tiled 2.5 m)

Height (albedo alpha) = 0.55 AO + 0.45 high-passed luminance, normalised to the 1..99th
percentile. It drives the height-blended splat transitions.
"""
import colorsys
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SRC = os.path.join(ROOT, "assets", "polyhaven", "textures", "terrain")
OUT = os.path.join(ROOT, "assets", "environment", "terrain", "textures")
SIZE = 2048
NRM_SIZE = 1024

# name, source id, hue shift (deg), saturation scale, linear value scale
SLICES = [
    ("grass", "aerial_grass_rock", -3.0, 0.90, 1.00),
    ("dry_grass", "aerial_grass_rock", 12.0, 0.80, 1.12 ** 2.2),
    ("dirt", "dirt_floor", 0.0, 0.85, 0.62),
    ("mud", "mud_forest", 0.0, 0.90, 1.35),
    ("forest_floor", "forest_ground_04", 0.0, 0.92, 1.00),
    ("rock", "forest_ground_04", 0.0, 0.40, 0.80),
    ("leaves", "forest_leaves_04", -4.0, 0.70, 1.00),
]


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.where(m, d, 1), 0)
    gc = np.where(m, (mx - g) / np.where(m, d, 1), 0)
    bc = np.where(m, (mx - b) / np.where(m, d, 1), 0)
    h = np.where(r == mx, bc - gc, np.where(g == mx, 2.0 + rc - bc, 4.0 + gc - rc))
    h = np.where(m, (h / 6.0) % 1.0, 0.0)
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return np.stack([h, s, mx], -1)


def hsv_to_rgb(hsv):
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    i = np.floor(h * 6.0)
    f = h * 6.0 - i
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))
    i = i.astype(int) % 6
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], -1)


def box_blur(a, r):
    """Wrap-around box blur (the textures tile), three passes ~ Gaussian."""
    for _ in range(3):
        for ax in (0, 1):
            c = np.cumsum(np.concatenate([a.take(range(-r - 1, 0), axis=ax), a, a.take(range(0, r), axis=ax)], axis=ax), axis=ax)
            n = a.shape[ax]
            hi = c.take(range(2 * r + 1, 2 * r + 1 + n), axis=ax)
            lo = c.take(range(0, n), axis=ax)
            a = (hi - lo) / (2 * r + 1)
    return a


def load(src_id, kind):
    folder = os.path.join(SRC, src_id)
    name = {"diffuse": f"{src_id}_diffuse_2k.jpg", "nor": f"{src_id}_nor_gl_2k.jpg", "arm": f"{src_id}_arm_2k.jpg"}[kind]
    im = Image.open(os.path.join(folder, name)).convert("RGB")
    if im.size != (SIZE, SIZE):
        im = im.resize((SIZE, SIZE), Image.LANCZOS)
    return np.asarray(im).astype(np.float64) / 255.0


def main():
    os.makedirs(OUT, exist_ok=True)
    albedo_strip = np.zeros((SIZE * len(SLICES), SIZE, 4), np.uint8)
    nrm_strip = np.zeros((NRM_SIZE * len(SLICES), NRM_SIZE, 4), np.uint8)
    report = []
    cache = {}
    for k, (name, src, hue, sat, val) in enumerate(SLICES):
        if src not in cache:
            cache[src] = (load(src, "diffuse"), load(src, "nor"), load(src, "arm"))
        diff, nor, arm = cache[src]
        lin = srgb_to_linear(diff) * val
        srgb = linear_to_srgb(lin)
        hsv = rgb_to_hsv(srgb)
        hsv[..., 0] = (hsv[..., 0] + hue / 360.0) % 1.0
        hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0.0, 1.0)
        out = np.clip(hsv_to_rgb(hsv), 0.0, 1.0)
        lum = (srgb_to_linear(out) * [0.2126, 0.7152, 0.0722]).sum(-1)
        hp = lum - box_blur(lum, 24)
        ao = arm[..., 0]
        h = 0.55 * (ao - ao.mean()) / max(ao.std(), 1e-4) + 0.45 * hp / max(hp.std(), 1e-4)
        lo, hi = np.percentile(h, [1, 99])
        h = np.clip((h - lo) / (hi - lo), 0.0, 1.0)
        rows = slice(k * SIZE, (k + 1) * SIZE)
        albedo_strip[rows, :, :3] = np.round(out * 255).astype(np.uint8)
        albedo_strip[rows, :, 3] = np.round(h * 255).astype(np.uint8)
        nrows = slice(k * NRM_SIZE, (k + 1) * NRM_SIZE)
        packed = np.stack([nor[..., 0], nor[..., 1], arm[..., 1], arm[..., 0]], -1)
        packed = np.asarray(Image.fromarray(np.round(packed * 255).astype(np.uint8), "RGBA").resize((NRM_SIZE, NRM_SIZE), Image.LANCZOS))
        nrm_strip[nrows] = packed
        report.append({"slice": k, "name": name, "source": src, "hue_deg": hue, "sat_scale": sat,
                       "linear_value_scale": round(val, 3), "mean_linear_luminance": round(float(lum.mean()), 4),
                       "mean_srgb": [round(float(v), 3) for v in out.reshape(-1, 3).mean(0)],
                       "mean_roughness": round(float(arm[..., 1].mean()), 3)})
        print(report[-1])
    Image.fromarray(albedo_strip, "RGBA").save(os.path.join(OUT, "terrain_albedo_array.webp"), quality=94, method=4)
    Image.fromarray(nrm_strip, "RGBA").save(os.path.join(OUT, "terrain_nrm_array.webp"), quality=96, method=4)
    # Preview sheet (not imported: .gdignore'd build folder).
    prev = Image.fromarray(albedo_strip[..., :3], "RGB").resize((256, 256 * len(SLICES)))
    prev.save(os.path.join(HERE, "build", "preview_albedo_slices.png"))
    with open(os.path.join(HERE, "build", "textures_report.json"), "w") as fh:
        json.dump(report, fh, indent=1)
    for base, n in (("terrain_albedo_array.webp", len(SLICES)), ("terrain_nrm_array.webp", len(SLICES))):
        imp = os.path.join(OUT, base + ".import")
        # Always (re)write: an open editor auto-imports a new file as a plain Texture2D.
        with open(imp, "w") as fh:
            fh.write(IMPORT_TEMPLATE.format(n=n))


IMPORT_TEMPLATE = """[remap]

importer="2d_array_texture"
type="CompressedTexture2DArray"

[params]

compress/mode=2
compress/high_quality=true
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
slices/horizontal=1
slices/vertical={n}
"""

if __name__ == "__main__":
    main()
