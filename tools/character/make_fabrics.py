"""Fabric kits for the cloth shader (customizer design 8.1), from the approved CC0 Poly Haven
scans in assets/polyhaven/textures/clothing (read only; nothing is downloaded).

    python3 tools/character/make_fabrics.py          # then: Godot --headless --path . --import

Writes assets/character/fabrics/:
  fabric_detail.jpg  1024 x (1024 * n) strip, one layer per fabric code (imported as a
                     Texture2DArray, slices/vertical = n):
                       R = linear luminance / mean luminance x 0.5 (0.5 = the mean: the scan's
                           own colour never reaches the game, the shader tints it)
                       G = roughness (the scan's arm.G)
                       B = ambient occlusion (arm.R)
  fabric_normal.jpg  the same strip of OpenGL (+Y up) tangent-space normals.
  fabrics.json       code -> layer, tile size (m), source kit, default shader strengths.

The scans are 2003-2091 px high: each is wrap-padded, resampled to 1024 x 1024 and cropped,
so the layers stay tileable. The FLAT layer is plain (metals, horn, wood, ribbons: their
detail comes from the shader).
"""

import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(ROOT, "assets", "polyhaven", "textures", "clothing")
OUT = os.path.join(ROOT, "assets", "character", "fabrics")
SIZE = 1024
PAD = 32

# code: (Poly Haven kit, tile m (Poly Haven API size), detail strength, normal strength, roughness mul, use)
FABRICS = [
    ("LIN", "rough_linen", 0.271, 0.55, 0.55, 1.00, "linen and tow: shirts, stocks, shifts, hunting shirts"),
    ("WOOL", "caban", 0.274, 0.85, 0.50, 1.00, "broadcloth, stroud, kersey, blanket cloth; felt (low normal)"),
    ("TWILL", "poly_wool_herringbone", 0.270, 0.45, 0.45, 1.00, "twilled wool, duffel, serge"),
    ("KNIT", "knitted_fleece", 0.266, 0.50, 0.70, 1.00, "knit caps, stockings, mittens"),
    ("SUEDE", "scuba_suede", 0.285, 0.55, 0.40, 1.00, "buckskin: breeches, leggings, moccasins, pouches"),
    ("LEA", "brown_leather", 0.400, 0.45, 0.60, 1.00, "tanned leather: belts, straps, shoes"),
    ("FUR", "curly_teddy_natural", 0.336, 0.45, 0.60, 1.00, "the base under fur shells; shaggy 'bearskin' cloth"),
    ("HES", "hessian_230", 0.269, 0.50, 0.60, 1.00, "coarse tow and hemp: tumplines, sacking"),
    ("FLAT", None, 0.0, 0.0, 0.0, 1.00, "metals, horn, wood, ribbons (procedural in the shader)"),
]


def srgb_to_linear(c):
    c = c.astype(np.float64) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def load(kit, m):
    return Image.open(os.path.join(SRC, kit, "%s_%s_2k.jpg" % (kit, m))).convert("RGB")


def resample(img):
    """Wrap-pad, resample the padded image so the tile becomes SIZE x SIZE, crop the pad:
    the result tiles like the scan."""
    a = np.asarray(img)
    h, w = a.shape[:2]
    p = int(round(PAD * max(w, h) / SIZE))
    big = np.pad(a, ((p, p), (p, p), (0, 0)), mode="wrap")
    sx, sy = SIZE / w, SIZE / h
    out = Image.fromarray(big).resize((int(round(big.shape[1] * sx)), int(round(big.shape[0] * sy))), Image.LANCZOS)
    o = np.asarray(out)
    ox, oy = int(round(p * sx)), int(round(p * sy))
    return o[oy:oy + SIZE, ox:ox + SIZE]


def blur_wrap(a, sigma):
    """Gaussian blur of a tileable 2D array (wraps at the borders), by FFT."""
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


# High-pass radii (px at 1024 px per tile, ~3.7 px per mm): the scans' low-frequency content is
# photographic (uneven light, a sagging swatch). Kept, it repeats every tile on a garment, and in
# the normal map it tilts whole triangles once the mipmaps average the weave away (the derivative
# frame differs per triangle, so the tilt showed as facets). The shader adds its own non-repeating
# large-scale variation instead.
HP_NORMAL = 10.0
HP_DETAIL = 48.0


def kit_layers(kit):
    dif = resample(load(kit, "diffuse"))
    lin = srgb_to_linear(dif)
    lum = (lin * np.array([0.2126, 0.7152, 0.0722])).sum(-1)
    lum = lum / np.maximum(blur_wrap(lum, HP_DETAIL), 1e-6) * lum.mean()
    ratio = lum / max(lum.mean(), 1e-6)
    arm = resample(load(kit, "arm")).astype(np.float64) / 255.0
    det = np.stack([np.clip(ratio * 0.5, 0.0, 1.0), arm[..., 1], arm[..., 0]], -1)
    nm = resample(load(kit, "nor_gl")).astype(np.float64) / 255.0 * 2.0 - 1.0
    nm /= np.maximum(np.linalg.norm(nm, axis=-1, keepdims=True), 1e-6)
    for c in (0, 1):
        nm[..., c] -= blur_wrap(nm[..., c], HP_NORMAL)
    nm[..., 2] = np.sqrt(np.clip(1.0 - nm[..., 0] ** 2 - nm[..., 1] ** 2, 0.0025, 1.0))
    # no overall tilt: a scan's mean normal leans a little (lighting of the capture), which the
    # mipmaps turn into a flat tilt of the whole garment at a distance
    tilt = nm[..., :2].mean((0, 1))
    nm[..., :2] -= tilt
    nm[..., 2] = np.maximum(nm[..., 2], 0.05)
    nm /= np.linalg.norm(nm, axis=-1, keepdims=True)
    stats = {"lum_cv": float(lum.std() / lum.mean()), "rough_mean": float(arm[..., 1].mean()),
             "ao_mean": float(arm[..., 0].mean()), "ratio_clipped": float((ratio > 2.0).mean()),
             "normal_tilt_removed": [round(float(t), 4) for t in tilt]}
    return det, nm * 0.5 + 0.5, stats


def main():
    os.makedirs(OUT, exist_ok=True)
    dets, nrms, info = [], [], {}
    for i, (code, kit, tile, ds, ns, rm, use) in enumerate(FABRICS):
        if kit is None:
            det = np.stack([np.full((SIZE, SIZE), 0.5), np.full((SIZE, SIZE), 0.5), np.ones((SIZE, SIZE))], -1)
            nm = np.stack([np.full((SIZE, SIZE), 0.5), np.full((SIZE, SIZE), 0.5), np.ones((SIZE, SIZE))], -1)
            stats = {}
        else:
            det, nm, stats = kit_layers(kit)
        dets.append(det)
        nrms.append(nm)
        info[code] = {"layer": i, "kit": kit, "tile_m": tile, "detail_strength": ds, "normal_strength": ns,
                      "roughness_mul": rm, "use": use, "stats": stats}
        print("%-5s layer %d  %s" % (code, i, stats))
    to8 = lambda a: np.clip(np.round(a * 255.0), 0, 255).astype(np.uint8)
    # JPEG like the source scans (a PNG strip is 32 MB in git); 4:4:4 so the channels stay apart
    for name, arr in (("fabric_detail.jpg", dets), ("fabric_normal.jpg", nrms)):
        Image.fromarray(to8(np.concatenate(arr, 0))).save(os.path.join(OUT, name), quality=94, subsampling=0)
    meta = {
        "format": "frontier-fabrics", "version": 1, "size": SIZE, "layers": len(FABRICS),
        "detail": "res://assets/character/fabrics/fabric_detail.jpg",
        "normal": "res://assets/character/fabrics/fabric_normal.jpg",
        "channels": {"detail": "R = luminance / mean x 0.5, G = roughness, B = AO", "normal": "OpenGL tangent space"},
        "fabrics": info,
        "generator": "tools/character/make_fabrics.py",
        "provenance": ("Derived from CC0 Poly Haven scans (https://polyhaven.com, CC0 1.0, no attribution required) "
                       "already in assets/polyhaven/textures/clothing (MANIFEST.json); luminance, roughness, AO and "
                       "normals only, resampled to 1024 px."),
    }
    with open(os.path.join(OUT, "fabrics.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
