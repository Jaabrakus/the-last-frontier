"""Loadout carry gear for Frontier: procedural 1750s models, built headless in Blender 5.2.

Builds the carry gear that the loadout design (source/graph_analysis/
loadout/loadout_design.md) needs so every weapon the player carries but does not hold
is visible on the body, and writes them as GLB files to assets/loadout/ together with
assets/loadout/MANIFEST.json:

  quiver.glb             leather back quiver with 24 fletched arrow ends (count-driven)
  powder_horn.glb        curved cow horn: domed wooden plug, brass staple, carved spout
                         with a stopper, strap ties (+ a hidden full strap loop)
  spear_pair_tie.glb     two thong lashings that tie the two throwing spears together,
                         carrying-thong loops (+ a hidden thong for display)
  dart_bundle.glb        buckskin point cover and thong ties for five atlatl darts
  musket_sling.glb       leather musket sling ends at both swivels: loop, brass buckle,
                         keepers (+ a hidden taut strap between them)
  pistol_belt_hook.glb   steel belt hook on the pistol's left flat (1756 sea-service style)
  pistol_sling_loop.glb  pistol sling (baldric): leather holster loop for a chest pistol
  pistol_sling_buckle.glb  the sling's brass buckle with its band ends
  tomahawk_frog.glb      leather belt frog: belt loop and haft loop under the head
  bow_cord.glb           sinew cord tied round the bow handle, loop over the quiver strap

The weapons themselves stay WeaponModels / ThrowableModels (assets/weapons/*.glb). Items
that fit a weapon are authored in that weapon's model frame, so they are added as a child
of the weapon model with an identity transform. Body items have their own frame with the
pivot at the attach point. Marker empties (strap anchors, carry points, slots) import as
Node3D; scripts/loadout/loadout_models.gd turns them into Marker3D.

Run headless (factory scene), from the Frontier root:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      --python tools/loadout/build_loadout_assets.py -- \
      [--out-dir assets/loadout] [--renders DIR] [--only quiver,powder_horn] [--no-export]

  --renders   turnaround sheets (one PNG per asset, 6 views, with the host weapon)
  --only      build a subset (MANIFEST.json is merged, not replaced)

Conventions (Godot / glTF axes, metres). Blender works Z-up and the glTF exporter maps
Blender (x, y, z) to glTF (x, z, -y), so everything is written in Godot coordinates and
converted once by G().

Textures: generated PBR maps (base colour, normal, metallic-roughness), tileable, from
read-only CC0 Poly Haven maps already in assets/polyhaven (MANIFEST.json there):
brown_leather (leather, rawhide), scuba_suede (buckskin), the wooden_axe model's wood and
forged iron; horn, brass and sinew are procedural. The quiver's arrow ends reuse the
arrow mesh and atlas of assets/weapons/arrow.glb. Nothing is downloaded.
"""

import argparse
import json
import math
import os
import random
import struct
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
POLYHAVEN = os.path.join(PROJECT, "assets", "polyhaven")
WEAPONS = os.path.join(PROJECT, "assets", "weapons")
SKY = [os.path.join(PROJECT, "assets", "environment", "sky", "qwantani_late_afternoon_nosun_2k.exr"),
       os.path.join(POLYHAVEN, "hdri", "qwantani_late_afternoon_puresky_2k.hdr")]
TAU = 2.0 * math.pi
CM = Matrix(((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0)))   # Godot -> Blender basis


def V(x, y, z):
    return Vector((x, y, z))


def G(p):
    """Godot-space point (Vector or tuple) in Blender coordinates."""
    return Vector((p[0], -p[2], p[1]))


def B2G(v):
    return Vector((v[0], v[2], -v[1]))


def lerp(a, b, t):
    return a + (b - a) * t


def smooth01(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def interp(table, x):
    if x <= table[0][0]:
        return table[0][1]
    for a, b in zip(table, table[1:]):
        if x <= b[0]:
            return lerp(a[1], b[1], (x - a[0]) / (b[0] - a[0]))
    return table[-1][1]


def basis_from(x=None, y=None, z=None):
    """Right-handed Godot basis (columns) from two given axes."""
    if z is not None and y is not None:
        z = z.normalized()
        y = (y - z * y.dot(z)).normalized()
        x = y.cross(z)
    elif y is not None and x is not None:
        y = y.normalized()
        x = (x - y * x.dot(y)).normalized()
        z = x.cross(y)
    elif z is not None and x is not None:
        z = z.normalized()
        x = (x - z * x.dot(z)).normalized()
        y = z.cross(x)
    m = Matrix.Identity(3)
    for i, a in enumerate((x, y, z)):
        m.col[i] = a
    return m


def rot_axis(axis, deg):
    return Matrix.Rotation(math.radians(deg), 3, Vector(axis))


def to_bmat(basis, pos):
    """Blender world matrix of an object whose Godot basis (columns) and origin are given."""
    rb = CM @ (basis if basis is not None else Matrix.Identity(3)) @ CM.transposed()
    m = rb.to_4x4()
    m.translation = G(pos)
    return m


def godot_text(basis, pos):
    b = basis if basis is not None else Matrix.Identity(3)
    vals = [b[r][c] for r in range(3) for c in range(3)] + list(pos)
    return "Transform3D(%s)" % ", ".join("%.6f" % (0.0 if abs(v) < 5e-7 else v) for v in vals)


def rnd(v, n=4):
    return [round(float(c), n) + 0.0 for c in v]


# ==========================================================================
# Textures (numpy, rows bottom-up as Blender stores them)
# ==========================================================================
def load_px(rel):
    path = os.path.join(POLYHAVEN, rel)
    if not os.path.exists(path):
        return None
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[:, :, :3].copy()


def down(a, n):
    """Box downsample of a square tileable map to n x n (stays tileable)."""
    h, w = a.shape[:2]
    fy, fx = h // n, w // n
    a = a[:fy * n, :fx * n]
    return a.reshape(n, fy, n, fx, -1).mean(axis=(1, 3))


def resize(a, h, w):
    h0, w0 = a.shape[:2]
    ys = np.clip((np.arange(h) + 0.5) * h0 / h - 0.5, 0, h0 - 1)
    xs = np.clip((np.arange(w) + 0.5) * w0 / w - 0.5, 0, w0 - 1)
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    y1 = np.minimum(y0 + 1, h0 - 1)
    x1 = np.minimum(x0 + 1, w0 - 1)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    if a.ndim == 3:
        fy, fx = fy[..., None], fx[..., None]
    top = a[y0][:, x0] * (1 - fx) + a[y0][:, x1] * fx
    bot = a[y1][:, x0] * (1 - fx) + a[y1][:, x1] * fx
    return (top * (1 - fy) + bot * fy).astype(np.float32)


def crop(a, rect):
    """rect = (x0, y0, x1, y1) in top-down pixel coordinates."""
    h = a.shape[0]
    x0, y0, x1, y1 = rect
    return a[h - y1:h - y0, x0:x1].copy()


def mirror_tile(a, normal=False):
    """Seamless 2x2 mirror tile of a crop (flips negate the normal's x / y)."""
    fu = a[:, ::-1].copy()
    if normal:
        fu[..., 0] *= -1.0
    row = np.concatenate([a, fu], axis=1)
    fv = row[::-1].copy()
    if normal:
        fv[..., 1] *= -1.0
    return np.concatenate([row, fv], axis=0)


def renorm(n):
    return n / np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)


def dec_normal(a):
    return renorm(a * 2.0 - 1.0)


def lum(a):
    return a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11


def pnoise(h, w, cy, cx, seed):
    """Value noise that tiles over the image (cy x cx lattice cells)."""
    rng = np.random.default_rng(seed)
    g = rng.random((cy, cx)).astype(np.float32)
    ys = np.arange(h, dtype=np.float32) * cy / h
    xs = np.arange(w, dtype=np.float32) * cx / w
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = (fy * fy * (3 - 2 * fy))[:, None]
    fx = (fx * fx * (3 - 2 * fx))[None, :]
    y1 = (y0 + 1) % cy
    x1 = (x0 + 1) % cx
    y0 %= cy
    x0 %= cx
    a = g[y0][:, x0]
    b = g[y0][:, x1]
    c = g[y1][:, x0]
    d = g[y1][:, x1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def pfbm(h, w, cy, cx, seed, octaves=4):
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += amp * pnoise(h, w, cy * 2 ** o, cx * 2 ** o, seed + o * 31)
        tot += amp
        amp *= 0.5
    return out / tot


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def height_normal(hf, strength):
    dx = (np.roll(hf, -1, 1) - np.roll(hf, 1, 1)) * 0.5
    dy = (np.roll(hf, -1, 0) - np.roll(hf, 1, 0)) * 0.5
    return renorm(np.stack([-dx * strength, -dy * strength, np.ones_like(hf)], axis=2))


def blend_normals(a, b):
    return renorm(np.stack([a[..., 0] + b[..., 0], a[..., 1] + b[..., 1], a[..., 2] * b[..., 2]], axis=2))


def flat_normal(h, w):
    n = np.zeros((h, w, 3), np.float32)
    n[..., 2] = 1.0
    return n


TEX_SOURCES = {}     # material key -> list of source notes (for MANIFEST.json)


def _ph(key, rel):
    TEX_SOURCES.setdefault(key, []).append("polyhaven:" + rel)


def tex_hide(key, src, tint, rough_bias, n, seed, contrast=1.0, nstrength=1.0, mottle=0.24, rough_contrast=1.0):
    """Tileable leather-like maps from a Poly Haven clothing texture, recoloured."""
    base = "textures/clothing/%s/%s_" % (src, src)
    d = load_px(base + "diffuse_2k.jpg")
    nn = load_px(base + "nor_gl_2k.jpg")
    arm = load_px(base + "arm_2k.jpg")
    tint = np.array(tint, np.float32)
    if d is not None and nn is not None and arm is not None:
        for m in ("diffuse_2k.jpg", "nor_gl_2k.jpg", "arm_2k.jpg"):
            _ph(key, base + m)
        d = down(d, n)
        l = lum(d)
        l = l / max(float(l.mean()), 1e-4)
        col = tint * (1.0 + (l - 1.0) * contrast)[..., None]
        nor = down(nn, n) * 2.0 - 1.0
        nor[..., 0:2] *= nstrength
        nor = renorm(nor)
        a = down(arm, n)
        r = a[..., 1]
        rough = np.clip(float(r.mean()) + (r - float(r.mean())) * rough_contrast + rough_bias, 0.05, 1.0)
    else:
        TEX_SOURCES.setdefault(key, []).append("procedural fallback (Poly Haven map missing)")
        hf = pfbm(n, n, 16, 16, seed + 5)
        col = tint * (0.85 + 0.3 * hf)[..., None]
        nor = height_normal(hf, 4.0)
        rough = np.full((n, n), 0.6 + rough_bias, np.float32)
    mott = pfbm(n, n, 3, 3, seed)
    col = col * (1.0 - mottle / 2 + mottle * mott)[..., None]
    return np.clip(col, 0, 1), nor, np.clip(rough, 0.05, 1.0), np.zeros((n, n), np.float32)


def tex_wood(key, tint, n, seed):
    axe = "models/wooden_axe/textures/wooden_axe_"
    d = load_px(axe + "diff_2k.jpg")
    nn = load_px(axe + "nor_gl_2k.jpg")
    arm = load_px(axe + "arm_2k.jpg")
    tint = np.array(tint, np.float32)
    if d is not None and nn is not None and arm is not None:
        for m in ("diff_2k.jpg", "nor_gl_2k.jpg", "arm_2k.jpg"):
            _ph(key, axe + m)
        rect = (1165, 900, 1330, 1230)      # straight-grain handle wood, grain along the rows
        c = mirror_tile(crop(d, rect))
        nr = mirror_tile(dec_normal(crop(nn, rect)), True)
        r = mirror_tile(crop(arm, rect))[..., 1]
        c = resize(c, n, n)
        nr = renorm(resize(nr, n, n))
        r = resize(r[..., None], n, n)[..., 0]
        l = lum(c)
        col = tint * (l / max(float(l.mean()), 1e-4))[..., None]
        col = tint + (col - tint) * 1.3
        rough = np.clip(0.55 + (r - r.mean()) * 0.6, 0.2, 0.9)
    else:
        TEX_SOURCES.setdefault(key, []).append("procedural fallback")
        g = pfbm(n, n, 2, 24, seed)
        col = tint * (0.8 + 0.4 * g)[..., None]
        nr = height_normal(g, 3.0)
        rough = np.full((n, n), 0.55, np.float32)
    col = col * (0.9 + 0.2 * pfbm(n, n, 4, 4, seed + 1))[..., None]
    return np.clip(col, 0, 1), nr, rough, np.zeros((n, n), np.float32)


def tex_iron(key, n, seed):
    axe = "models/wooden_axe/textures/wooden_axe_"
    d = load_px(axe + "diff_2k.jpg")
    nn = load_px(axe + "nor_gl_2k.jpg")
    arm = load_px(axe + "arm_2k.jpg")
    base = np.array([0.17, 0.17, 0.18], np.float32)
    if d is not None and nn is not None and arm is not None:
        for m in ("diff_2k.jpg", "nor_gl_2k.jpg", "arm_2k.jpg"):
            _ph(key, axe + m)
        rect = (565, 962, 1005, 1105)       # forged iron of the axe head
        c = resize(mirror_tile(crop(d, rect)), n, n)
        nr = renorm(resize(mirror_tile(dec_normal(crop(nn, rect)), True), n, n))
        r = resize(mirror_tile(crop(arm, rect))[..., 1][..., None], n, n)[..., 0]
        l = np.clip(lum(c) / max(float(lum(c).mean()), 1e-4), 0.5, 1.6) ** 0.5
        col = base * l[..., None]
        rough = np.clip(0.5 + (r - r.mean()) * 0.5, 0.2, 0.9)
    else:
        TEX_SOURCES.setdefault(key, []).append("procedural fallback")
        g = pfbm(n, n, 8, 8, seed)
        col = base * (0.8 + 0.4 * g)[..., None]
        nr = height_normal(g, 3.0)
        rough = np.full((n, n), 0.5, np.float32)
    rust = sstep(0.62, 0.85, pfbm(n, n, 6, 6, seed + 3)) * 0.55
    col = col * (1 - rust[..., None]) + np.array([0.29, 0.16, 0.09], np.float32) * rust[..., None]
    rough = rough * (1 - rust) + 0.85 * rust
    metal = 0.8 * (1 - rust) + 0.2 * rust
    return np.clip(col, 0, 1), nr, rough, metal


def tex_brass(key, n, seed):
    TEX_SOURCES.setdefault(key, []).append("procedural (tarnished cast brass)")
    g = pfbm(n, n, 6, 6, seed)
    t = sstep(0.5, 0.8, pfbm(n, n, 3, 3, seed + 7)) * 0.6
    col = np.array([0.80, 0.62, 0.31], np.float32) * (0.88 + 0.2 * g)[..., None]
    col = col * (1 - t[..., None]) + np.array([0.33, 0.27, 0.15], np.float32) * t[..., None]
    rough = 0.28 + 0.32 * t + 0.08 * g
    metal = 1.0 - 0.35 * t
    nor = height_normal(pfbm(n, n, 24, 24, seed + 2, 3), 1.5)
    return np.clip(col, 0, 1), nor, rough, metal


def tex_steel(key, n, seed):
    """Filed, bright steel (belt hook): fine lengthwise file marks, a little tarnish."""
    TEX_SOURCES.setdefault(key, []).append("procedural (filed bright steel)")
    g = pfbm(n, n, 6, 6, seed)
    marks = pfbm(n, n, 2, 96, seed + 1, 2)
    t = sstep(0.55, 0.85, pfbm(n, n, 3, 3, seed + 2)) * 0.5
    col = np.array([0.58, 0.585, 0.59], np.float32) * (0.9 + 0.12 * g + 0.08 * marks)[..., None]
    col = col * (1 - t[..., None]) + np.array([0.30, 0.28, 0.26], np.float32) * t[..., None]
    rough = 0.26 + 0.1 * marks + 0.25 * t
    metal = 1.0 - 0.3 * t
    return np.clip(col, 0, 1), height_normal(marks * 2.0, 1.2), rough, metal


def tex_sinew(key, n, seed):
    """Twisted three-strand sinew cord: u around the cord, v along it (tile 2 cm)."""
    TEX_SOURCES.setdefault(key, []).append("procedural (twisted sinew)")
    u = (np.arange(n) + 0.5) / n
    v = (np.arange(n) + 0.5) / n
    uu, vv = np.meshgrid(u, v)
    phase = uu * 3.0 + vv * 6.0
    f = phase - np.floor(phase)
    ht = np.sin(np.pi * f) ** 0.6
    g = pfbm(n, n, 8, 8, seed)
    col = np.array([0.66, 0.55, 0.37], np.float32) * (0.62 + 0.42 * ht)[..., None] * (0.9 + 0.2 * g)[..., None]
    nor = height_normal(ht * 3.0, 2.0)
    rough = 0.72 + 0.1 * (1 - ht)
    return np.clip(col, 0, 1), nor, rough, np.zeros((n, n), np.float32)


def tex_horn(key, w=512, h=1024, seed=7):
    """Cow horn, not tiled: u around the horn (seam on the body side), v base -> tip."""
    TEX_SOURCES.setdefault(key, []).append("procedural (cow horn: cream to amber, dark tip, growth rings)")
    v = ((np.arange(h) + 0.5) / h)[:, None] * np.ones((1, w), np.float32)
    streak = pfbm(h, w, 3, 26, seed)
    streak2 = pfbm(h, w, 5, 48, seed + 3)
    fine = pfbm(h, w, 40, 64, seed + 9, 3)
    cream = np.array([0.84, 0.74, 0.53], np.float32)
    amber = np.array([0.68, 0.52, 0.30], np.float32)
    grey = np.array([0.34, 0.31, 0.25], np.float32)
    black = np.array([0.08, 0.075, 0.065], np.float32)
    dusk = np.array([0.46, 0.41, 0.33], np.float32)
    a = np.clip(sstep(0.5, 0.85, streak2) * 0.55 + 0.2 * (1 - v) * sstep(0.3, 0.7, streak), 0, 1)
    col = cream * (1 - a[..., None]) + amber * a[..., None]
    g = sstep(0.62, 0.9, pfbm(h, w, 4, 36, seed + 5)) * 0.45
    col = col * (1 - g[..., None]) + dusk * g[..., None]
    tipmix = sstep(0.52, 0.95, v + 0.28 * (streak - 0.5))
    tipcol = grey * (1 - sstep(0.8, 1.0, v))[..., None] + black * sstep(0.8, 1.0, v)[..., None]
    col = col * (1 - tipmix[..., None]) + tipcol * tipmix[..., None]
    col = col * (0.84 + 0.22 * streak)[..., None] * (0.96 + 0.08 * fine)[..., None]
    rings = np.sin(v * 230.0 + 5.0 * streak) * sstep(0.2, 0.0, v)
    hf = rings * 0.10 + fine * 0.12 + streak * 0.3
    nor = height_normal(hf, 2.0)
    rough = 0.30 + 0.14 * (1 - streak) + 0.08 * tipmix
    return np.clip(col, 0, 1), nor, rough, np.zeros((h, w), np.float32)


# material key -> (builder, tile metres, image size)
MAT_DEFS = {
    "LoadoutLeather": (lambda k: tex_hide(k, "brown_leather", (0.40, 0.245, 0.135), 0.04, 512, 11, 0.45, 0.30, 0.24, 0.35), 0.20),
    "LoadoutLeatherDark": (lambda k: tex_hide(k, "brown_leather", (0.12, 0.075, 0.045), 0.08, 256, 12, 0.6, 0.45), 0.20),
    "LoadoutBuckskin": (lambda k: tex_hide(k, "scuba_suede", (0.58, 0.44, 0.29), 0.10, 512, 13, 1.0, 0.6, 0.30), 0.18),
    "LoadoutRawhide": (lambda k: tex_hide(k, "brown_leather", (0.70, 0.56, 0.35), -0.18, 256, 14, 0.7, 0.5, 0.35), 0.15),
    "LoadoutHorn": (lambda k: tex_horn(k), 1.0),
    "LoadoutPlugWood": (lambda k: tex_wood(k, (0.50, 0.34, 0.19), 256, 21), 0.06),
    "LoadoutStopperWood": (lambda k: tex_wood(k, (0.30, 0.18, 0.09), 256, 22), 0.04),
    "LoadoutBrass": (lambda k: tex_brass(k, 256, 31), 0.05),
    "LoadoutIron": (lambda k: tex_iron(k, 256, 41), 0.06),
    "LoadoutSteel": (lambda k: tex_steel(k, 256, 45), 0.05),
    "LoadoutSinew": (lambda k: tex_sinew(k, 128, 51), 0.02),
}
MATS = {}


def to_image(name, arr, non_color=False):
    h, w = arr.shape[:2]
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((h, w, 1), np.float32)], axis=2).astype(np.float32)
    im = bpy.data.images.new(name, w, h, alpha=False, is_data=non_color)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    im.pixels.foreach_set(rgba.ravel())
    im.update()
    im.pack()
    return im


def make_material(key):
    if key in MATS:
        return MATS[key]
    fn, _tile = MAT_DEFS[key]
    col, nor, rough, metal = fn(key)
    stem = key.replace("Loadout", "").lower()
    i_col = to_image("loadout_%s_col" % stem, col)
    i_nor = to_image("loadout_%s_nor" % stem, nor * 0.5 + 0.5, True)
    orm = np.stack([np.ones_like(rough), rough, metal], axis=2)
    i_orm = to_image("loadout_%s_orm" % stem, orm, True)
    m = bpy.data.materials.new(key)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t_col = nt.nodes.new("ShaderNodeTexImage")
    t_col.image = i_col
    nt.links.new(t_col.outputs["Color"], bsdf.inputs["Base Color"])
    t_orm = nt.nodes.new("ShaderNodeTexImage")
    t_orm.image = i_orm
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(t_orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    t_n = nt.nodes.new("ShaderNodeTexImage")
    t_n.image = i_nor
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(t_n.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    m.use_backface_culling = True
    MATS[key] = m
    return m


def tile_of(key):
    return MAT_DEFS[key][1] if key in MAT_DEFS else 0.1


# ==========================================================================
# Mesh building (Godot coordinates)
# ==========================================================================
class MB:
    def __init__(self):
        self.bm = bmesh.new()
        self.uvl = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []

    def mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def verts(self, pts):
        return [self.bm.verts.new(G(p)) for p in pts]

    def face(self, vs, uvs, mat, out=None, smooth=True):
        if out is not None and out.length > 1e-9:
            n = Vector()
            for i, a in enumerate(vs):
                b = vs[(i + 1) % len(vs)]
                n.x += (a.co.y - b.co.y) * (a.co.z + b.co.z)
                n.y += (a.co.z - b.co.z) * (a.co.x + b.co.x)
                n.z += (a.co.x - b.co.x) * (a.co.y + b.co.y)
            if n.dot(G(out)) < 0.0:
                vs = list(reversed(vs))
                uvs = list(reversed(uvs))
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.material_index = self.mi(mat)
        f.smooth = smooth
        for loop, t in zip(f.loops, uvs):
            loop[self.uvl].uv = t
        return f

    def grid(self, rings, us, vs_, mat, closed_v=False, out_fn=None):
        """rings: rows of Godot points (closed loops of equal size n). us: n + 1 u values
        (the last closes the loop), vs_: one v per ring (+1 if closed_v). out_fn(i, j, pc)
        gives the outward direction of the quad between rings i, i+1 and points j, j+1."""
        R, n = len(rings), len(rings[0])
        vv = [self.verts(r) for r in rings]
        for i in range(R if closed_v else R - 1):
            i2 = (i + 1) % R
            for j in range(n):
                j2 = (j + 1) % n
                pc = (rings[i][j] + rings[i][j2] + rings[i2][j2] + rings[i2][j]) * 0.25
                self.face([vv[i][j], vv[i][j2], vv[i2][j2], vv[i2][j]],
                          [(us[j], vs_[i]), (us[j + 1], vs_[i]), (us[j + 1], vs_[i + 1]), (us[j], vs_[i + 1])],
                          mat, out_fn(i, j, pc) if out_fn else None)
        return vv

    def cap(self, ring_verts, ring_pts, centre, mat, out, tile):
        a = out.orthogonal().normalized()
        b = out.normalized().cross(a)
        uvs = [((p - centre).dot(a) / tile + 0.5, (p - centre).dot(b) / tile + 0.5) for p in ring_pts]
        f = self.face(list(ring_verts), uvs, mat, out)
        if f:
            for e in f.edges:
                e.smooth = False
        return f

    def to_object(self, name, sharp_deg=35.0):
        ngons = [f for f in self.bm.faces if len(f.verts) > 4]
        if ngons:
            bmesh.ops.triangulate(self.bm, faces=ngons, quad_method="BEAUTY", ngon_method="BEAUTY")
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts[:], dist=1e-7)
        self.bm.edges.index_update()
        manual = [e.index for e in self.bm.edges if not e.smooth]
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(sharp_deg))
        if manual:
            attr = me.attributes.get("sharp_edge") or me.attributes.new("sharp_edge", "BOOLEAN", "EDGE")
            vals = [False] * len(me.edges)
            attr.data.foreach_get("value", vals)
            for i in manual:
                if i < len(vals):
                    vals[i] = True
            attr.data.foreach_set("value", vals)
        for m in self.mats:
            me.materials.append(make_material(m))
        me.validate()
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        return o


def tangents(path, closed=False):
    n = len(path)
    out = []
    for i in range(n):
        if closed:
            a, b = path[(i - 1) % n], path[(i + 1) % n]
        else:
            a, b = path[max(i - 1, 0)], path[min(i + 1, n - 1)]
        out.append((b - a).normalized())
    return out


def ptf(path, n0, closed=False):
    """Parallel-transport frames (T, N, B) along a polyline."""
    T = tangents(path, closed)
    n = n0 - T[0] * n0.dot(T[0])
    if n.length < 1e-6:
        n = T[0].orthogonal()
    n.normalize()
    Ns = [n.copy()]
    for i in range(1, len(path)):
        q = T[i - 1].rotation_difference(T[i])
        n = q @ n
        n = n - T[i] * n.dot(T[i])
        n.normalize()
        Ns.append(n.copy())
    return T, Ns, [T[i].cross(Ns[i]) for i in range(len(path))]


def arclen(path, closed=False):
    out = [0.0]
    for i in range(1, len(path)):
        out.append(out[-1] + (path[i] - path[i - 1]).length)
    if closed:
        out.append(out[-1] + (path[0] - path[-1]).length)
    return out


def perim(prof):
    out = [0.0]
    for j in range(len(prof)):
        a, b = prof[j], prof[(j + 1) % len(prof)]
        out.append(out[-1] + math.hypot(a[0] - b[0], a[1] - b[1]))
    return out


def circle(r, n, rb=None, start=0.0):
    rb = r if rb is None else rb
    return [(r * math.cos(start + TAU * k / n), rb * math.sin(start + TAU * k / n)) for k in range(n)]


def rect(w, t, bv=None):
    """Band cross-section: a along the band normal (thickness t), b across (width w)."""
    bv = t * 0.35 if bv is None else bv
    h, q = t / 2, w / 2
    return [(h, -q + bv), (h, q - bv), (h - bv, q), (-h + bv, q), (-h, q - bv), (-h, -q + bv), (-h + bv, -q), (h - bv, -q)]


def sweep(mb, path, prof, mat, n0=None, closed=False, scale=None, cap0=False, cap1=False,
          frames=None, u_tile=None, v_tile=None, v0=0.0):
    tile = tile_of(mat)
    T, N, B = frames if frames else ptf(path, n0 if n0 is not None else V(0, 1, 0), closed)
    rings = []
    for i, p in enumerate(path):
        sa, sb = scale(i) if scale else (1.0, 1.0)
        rings.append([p + N[i] * (a * sa) + B[i] * (b * sb) for a, b in prof])
    us = [x / (u_tile or tile) for x in perim(prof)]
    vs = [v0 + x / (v_tile or tile) for x in arclen(path, closed)]
    vv = mb.grid(rings, us, vs, mat, closed, out_fn=lambda i, j, pc: pc - (path[i] + path[(i + 1) % len(path)]) * 0.5)
    if cap0:
        mb.cap(vv[0], rings[0], path[0], mat, -T[0], tile)
    if cap1:
        mb.cap(vv[-1], rings[-1], path[-1], mat, T[-1], tile)
    return rings


def band(mb, path, w, t, mat, width_axis=None, normals=None, closed=False, caps=True, bv=None, v0=0.0):
    """Flat strap along `path`: width across `width_axis` (or normal to `normals`)."""
    T = tangents(path, closed)
    N, B = [], []
    for i, tv in enumerate(T):
        if normals is not None:
            n = normals[i] - tv * normals[i].dot(tv)
            n.normalize()
            b = tv.cross(n)
        else:
            b = width_axis - tv * width_axis.dot(tv)
            if b.length < 1e-6:
                b = tv.orthogonal()
            b.normalize()
            n = b.cross(tv)
        N.append(n)
        B.append(b)
    return sweep(mb, path, rect(w, t, bv), mat, closed=closed, cap0=caps and not closed,
                 cap1=caps and not closed, frames=(T, N, B), v0=v0)


def tube(mb, path, r, mat, n=8, n0=None, closed=False, caps=True, u_tile=None, rb=None):
    return sweep(mb, path, circle(r, n, rb), mat, n0=n0, closed=closed, cap0=caps and not closed,
                 cap1=caps and not closed, u_tile=u_tile if u_tile else None)


def lathe(mb, origin, axis, prof, mat, n=16, ref=None, rscale=(1.0, 1.0), cap0=False, cap1=False,
          rfunc=None, u_tile=None, v_tile=None, start=0.0):
    """Surface of revolution: prof = [(distance along axis, radius)]; rfunc(k, th, d) scales r."""
    axis = axis.normalized()
    ref = (ref if ref is not None else axis.orthogonal())
    ref = (ref - axis * ref.dot(axis)).normalized()
    side = axis.cross(ref)
    tile = tile_of(mat)
    rings = []
    for k, (d, r) in enumerate(prof):
        ring = []
        for j in range(n):
            th = start + TAU * j / n
            rr = r * (rfunc(k, th, d) if rfunc else 1.0)
            ring.append(origin + axis * d + ref * (rr * rscale[0] * math.cos(th)) + side * (rr * rscale[1] * math.sin(th)))
        rings.append(ring)
    rmax = max(r for _, r in prof)
    us = [(TAU * rmax * j / n) / (u_tile or tile) for j in range(n + 1)]
    mer = [0.0]
    for a, b in zip(prof, prof[1:]):
        mer.append(mer[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    vs = [x / (v_tile or tile) for x in mer]

    def out_fn(i, j, pc):
        (d0, r0), (d1, r1) = prof[i], prof[i + 1]
        rad = pc - origin
        rad = rad - axis * rad.dot(axis)
        rad = rad.normalized() if rad.length > 1e-9 else ref
        return axis * (-(r1 - r0)) + rad * (d1 - d0) if abs(d1 - d0) + abs(r1 - r0) > 1e-9 else rad
    vv = mb.grid(rings, us, vs, mat, False, out_fn=out_fn)
    if cap0:
        mb.cap(vv[0], rings[0], origin + axis * prof[0][0], mat, -axis, tile)
    if cap1:
        mb.cap(vv[-1], rings[-1], origin + axis * prof[-1][0], mat, axis, tile)
    return rings


def blob(mb, centre, axis, a, b, mat, n=8, ref=None, rb=None):
    """Ellipsoid knot: half length a along axis, radius b (rb across)."""
    prof = []
    for k in range(7):
        s = -1.0 + 2.0 * k / 6
        prof.append((a * s, max(b * math.sqrt(max(1 - s * s, 0.0)), b * 0.18)))
    return lathe(mb, centre, axis, prof, mat, n=n, ref=ref, rscale=(1.0, (rb or b) / b), cap0=True, cap1=True)


def catmull(pts, per=6, closed=False):
    """Catmull-Rom spline through Godot points (per segments between two points)."""
    P = list(pts)
    n = len(P)
    out = []
    segs = n if closed else n - 1
    for i in range(segs):
        p0 = P[(i - 1) % n] if closed else P[max(i - 1, 0)]
        p1, p2 = P[i], P[(i + 1) % n]
        p3 = P[(i + 2) % n] if closed else P[min(i + 2, n - 1)]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    if not closed:
        out.append(P[-1].copy())
    return out


def box(mb, centre, ex, ey, ez, mat):
    """Box with half extents along the (Godot) vectors ex, ey, ez."""
    tile = tile_of(mat)
    cs = {}
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                cs[(sx, sy, sz)] = centre + ex * sx + ey * sy + ez * sz
    vs = {k: mb.bm.verts.new(G(p)) for k, p in cs.items()}
    faces = [((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)), ((-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)),
             ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)), ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)),
             ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)), ((-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1))]
    for f in faces:
        pts = [cs[k] for k in f]
        c = sum(pts, Vector()) / 4
        out = c - centre
        a = (pts[1] - pts[0]).normalized()
        b = out.normalized().cross(a)
        f2 = mb.face([vs[k] for k in f], [((p - c).dot(a) / tile, (p - c).dot(b) / tile) for p in pts], mat, out)
        if f2:
            for e in f2.edges:
                e.smooth = False


def empty(name, pos, basis=None, parent=None, size=0.01):
    o = bpy.data.objects.new(name, None)
    o.empty_display_type = "PLAIN_AXES"
    o.empty_display_size = size
    bpy.context.scene.collection.objects.link(o)
    o.matrix_world = to_bmat(basis, pos)
    if parent is not None:
        mw = o.matrix_world.copy()
        o.parent = parent
        o.matrix_world = mw
    return o


def import_glb(rel):
    """Imports a weapon GLB (read-only), returns {name: object}."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(WEAPONS, rel))
    return {o.name: o for o in bpy.data.objects if o not in before}


def mesh_points(obj):
    return [B2G(obj.matrix_world @ v.co) for v in obj.data.vertices]


def section(pts, axis, value, band_w=0.003):
    sel = [p for p in pts if abs(p[axis] - value) < band_w]
    if not sel:
        return None
    return [(min(p[i] for p in sel), max(p[i] for p in sel)) for i in range(3)]


# ==========================================================================
# Host weapon measurements (read-only imports of assets/weapons)
# ==========================================================================
HOST = {}


def measure_hosts():
    got = import_glb("spear.glb")
    pts = mesh_points(got["Spear"])
    HOST["spear_r"] = {}
    for z in (-0.36, 0.60):
        rr = [math.hypot(p.x, p.y) for p in pts if abs(p.z - z) < 0.07 and p.z > -0.44]
        HOST["spear_r"][z] = max(rr) if rr else 0.013
    for o in got.values():
        bpy.data.objects.remove(o, do_unlink=True)
    got = import_glb("atlatl_dart.glb")
    pts = mesh_points(next(o for o in got.values() if o.type == "MESH"))
    HOST["dart_r"] = {}
    for z in (0.495, 1.155, 0.212):
        s = section(pts, 2, z, 0.02)
        HOST["dart_r"][z] = max(abs(s[0][0]), abs(s[0][1])) if s else 0.0075
    for o in got.values():
        bpy.data.objects.remove(o, do_unlink=True)
    got = import_glb("musket.glb")
    pts = mesh_points(got["Musket"])
    for key, z, ymax in (("rear", -0.0930, -0.04), ("front", -0.9125, 0.0)):
        sel = [p for p in pts if abs(p.z - z) < 0.003 and p.y < ymax]
        ymin = min(p.y for p in sel)
        xmax = max(abs(p.x) for p in sel if p.y < ymin + 0.004)
        HOST["swivel_" + key] = (V(0.0, ymin + 0.0016, z), xmax)
    for o in got.values():
        bpy.data.objects.remove(o, do_unlink=True)
    got = import_glb("tomahawk.glb")
    pts = mesh_points(got["Tomahawk"])
    sel = [p for p in pts if abs(p.y - 0.33) < 0.002]
    HOST["haft"] = (max(abs(p.x) for p in sel), max(-p.z for p in sel))
    for o in got.values():
        bpy.data.objects.remove(o, do_unlink=True)
    got = import_glb("bow.glb")
    pts = mesh_points(got["Bow"])
    s = section(pts, 1, -0.065, 0.0008)
    HOST["bow_handle"] = (max(abs(s[0][0]), abs(s[0][1])), max(abs(s[2][0]), abs(s[2][1])))
    for o in got.values():
        bpy.data.objects.remove(o, do_unlink=True)
    print("HOST", {k: (str(v) if not isinstance(v, dict) else {kk: round(vv, 4) for kk, vv in v.items()}) for k, v in HOST.items()})


# ==========================================================================
# Assets. Each builder returns a dict:
#   objects: [mesh objects and empties to export], markers: {name: (pos, basis, role)},
#   hidden: [node names exported hidden], + manifest fields.
# ==========================================================================
def marker_objs(markers, parent=None):
    return [empty(k, v[0], v[1], parent) for k, v in markers.items()]


# ---------------------------------------------------------------- quiver --
Q_LEN = 0.560         # mouth to the bottom of the rawhide cup
Q_N = 28
Q_ARROWS = 24
Q_ARROW_SEAT = 0.545  # tip depth below the mouth (arrows stand on the padded bottom)
Q_CLIP = 0.47         # arrow mesh kept from this distance behind the tip (hidden below it)


def q_half(y):
    t = min(max(-y / Q_LEN, 0.0), 1.0)
    a = 0.056 - 0.010 * t + 0.004 * math.sin(math.pi * t)
    b = 0.046 - 0.008 * t + 0.003 * math.sin(math.pi * t)
    return a, b


def q_ring(y, grow=0.0, n=Q_N, scale=1.0):
    a, b = q_half(y)
    pts = []
    for k in range(n):
        th = math.pi + TAU * k / n          # starts at -X: the UV seam lies under the side seam
        x = (a * scale + grow) * math.cos(th)
        z = (b * scale + grow) * math.sin(th)
        if z < 0.0:
            z *= 0.86                        # flatter against the back (-Z)
        pts.append(V(x, y, z))
    return pts


def q_surface(y, th, grow=0.0):
    a, b = q_half(y)
    x = (a + grow) * math.cos(th)
    z = (b + grow) * math.sin(th)
    if z < 0.0:
        z *= 0.86
    return V(x, y, z)


def q_rings_grid(mb, ys, mat, grow=0.0, inward=False, scales=None):
    rings = [q_ring(y, grow, scale=(scales[i] if scales else 1.0)) for i, y in enumerate(ys)]
    tile = tile_of(mat)
    a, b = q_half(ys[0])
    per = TAU * math.sqrt((a * a + b * b) / 2)
    us = [per * j / Q_N / tile for j in range(Q_N + 1)]
    vs = [(y - ys[0]) / tile for y in ys]

    def out_fn(i, j, pc):
        o = V(pc.x, 0.0, pc.z)
        return -o if inward else o
    return mb.grid(rings, us, vs, mat, False, out_fn=out_fn), rings


def build_quiver():
    random.seed(5)
    mb = MB()
    # Body (brown leather), under the collar and the bottom cup.
    ys = [-0.520 + 0.475 * k / 14 for k in range(15)]
    q_rings_grid(mb, ys, "LoadoutLeather")
    # Rawhide bottom cup with a domed end.
    cup_ys = [-0.555, -0.545, -0.530, -0.515, -0.505]
    vv, rings = q_rings_grid(mb, cup_ys, "LoadoutRawhide", grow=0.0028)
    dome = [(-0.5615, 0.93), (-0.5665, 0.72), (-0.5695, 0.42)]
    prev_v, prev_r = vv[0], rings[0]
    tile = tile_of("LoadoutRawhide")
    for y, s in dome:
        ring = [V(p.x * s, y, p.z * s) for p in q_ring(-0.555, 0.0028)]
        nv = mb.verts(ring)
        for j in range(Q_N):
            j2 = (j + 1) % Q_N
            pc = (ring[j] + ring[j2] + prev_r[j] + prev_r[j2]) * 0.25
            mb.face([prev_v[j], prev_v[j2], nv[j2], nv[j]],
                    [(j / Q_N, 0.0), ((j + 1) / Q_N, 0.0), ((j + 1) / Q_N, 0.08), (j / Q_N, 0.08)],
                    "LoadoutRawhide", V(pc.x, -0.02, pc.z))
        prev_v, prev_r = nv, ring
    mb.cap(prev_v, prev_r, V(0, -0.5695, 0), "LoadoutRawhide", V(0, -1, 0), tile)
    # Rolled lip of the cup and its stitch welt.
    lip = q_ring(-0.504, 0.0040)
    tube(mb, lip, 0.0017, "LoadoutRawhide", n=6, closed=True)
    # Buckskin collar with a rolled rim at the mouth; inside wall and a dark floor.
    q_rings_grid(mb, [-0.060, -0.030, -0.004], "LoadoutBuckskin", grow=0.0024)
    rim = q_ring(-0.001, 0.0005)
    sweep(mb, rim, circle(0.0042, 8), "LoadoutBuckskin", n0=V(0, 1, 0), closed=True)
    inner_ys = [-0.100, -0.050, -0.003]
    ivv, irings = q_rings_grid(mb, inner_ys, "LoadoutLeatherDark", grow=-0.0035, inward=True)
    mb.cap(ivv[0], irings[0], V(0, -0.1, 0), "LoadoutLeatherDark", V(0, 1, 0), 0.2)
    # Collar fringe on the outer (+Z) half, and the lower collar edge band.
    tube(mb, q_ring(-0.061, 0.0032), 0.0016, "LoadoutBuckskin", n=6, closed=True)
    for k in range(17):
        th = math.radians(18 + 144 * k / 16)
        top = q_surface(-0.062, th, 0.0040)
        outd = V(top.x, 0.0, top.z).normalized()
        L = 0.050 + 0.012 * random.random()
        path = [top + outd * (0.004 * s + 0.006 * s * s) + V(0, -L * s, 0) + V(0.002 * math.sin(3 * s + k), 0, 0) for s in (0, 0.25, 0.5, 0.75, 1.0)]
        band(mb, path, 0.0042, 0.0011, "LoadoutBuckskin", normals=[outd] * len(path))
    # Side seam on -X: a welt standing off the body with a long fringe.
    seam = []
    for k in range(12):
        y = -0.505 + 0.44 * k / 11
        a, _b = q_half(y)
        seam.append(V(-(a + 0.0055), y, 0.0))
    band(mb, seam, 0.011, 0.0028, "LoadoutLeather", normals=[V(0, 0, 1)] * len(seam))
    for k in range(20):
        y = -0.480 + 0.40 * k / 19
        a, _b = q_half(y)
        st = V(-(a + 0.0105), y, 0.0)
        L = 0.055 + 0.015 * random.random()
        sway = (random.random() - 0.5) * 0.01
        path = [st + V(-0.028 * s, -L * s * s * 0.9 - 0.004 * s, sway * s) for s in (0, 0.25, 0.5, 0.75, 1.0)]
        band(mb, path, 0.0045, 0.0012, "LoadoutBuckskin", normals=[V(0, 0, 1)] * len(path))
    # Stitch lacing across the welt (small thong stitches every 3 cm).
    for k in range(14):
        y = -0.495 + 0.42 * k / 13
        a, _b = q_half(y)
        p0 = V(-(a + 0.001), y, 0.0)
        p1 = V(-(a + 0.008), y + 0.004, 0.0)
        tube(mb, [p0 + V(0, 0, 0.0016), p1 + V(0, 0, 0.0016)], 0.0008, "LoadoutBuckskin", n=4)
        tube(mb, [p0 - V(0, 0, 0.0016), p1 - V(0, 0, 0.0016)], 0.0008, "LoadoutBuckskin", n=4)
    # Strap tabs: D loops on the back (-Z) side, the carrying strap passes through along X.
    strap_marks = {}
    for name, y0 in (("StrapTop", -0.085), ("StrapBottom", -0.455)):
        zs = q_surface(y0, -math.pi / 2).z - 0.0012
        path = [V(0, y0 + 0.024, zs + 0.0015), V(0, y0 + 0.018, zs - 0.004), V(0, y0 + 0.008, zs - 0.0115),
                V(0, y0 - 0.008, zs - 0.0115), V(0, y0 - 0.018, zs - 0.004), V(0, y0 - 0.024, zs + 0.0015)]
        band(mb, catmull(path, 3), 0.024, 0.0032, "LoadoutLeather", width_axis=V(1, 0, 0))
        # stitched ends flat on the body
        for yy in (y0 + 0.027, y0 - 0.027):
            box(mb, V(0, yy, zs + 0.0008), V(0.012, 0, 0), V(0, 0.006, 0), V(0, 0, 0.0012), "LoadoutLeather")
        strap_marks[name] = V(0.0, y0, zs - 0.0075)
    body = mb.to_object("Quiver")

    # Arrow ends: the arrow.glb mesh, clipped below Q_CLIP, as 24 linked duplicates.
    got = import_glb("arrow.glb")
    src = next(o for o in got.values() if o.type == "MESH")
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0.0, -Q_CLIP, 0.0),
                           plane_no=(0.0, 1.0, 0.0), clear_outer=True)
    me = bpy.data.meshes.new("QuiverArrow")
    bm.to_mesh(me)
    bm.free()
    used = sorted({p.material_index for p in me.polygons})
    for i in used:
        me.materials.append(src.data.materials[i])
    remap = {old: new for new, old in enumerate(used)}
    for p in me.polygons:
        p.material_index = remap[p.material_index]
    arrow_tris = sum(len(p.vertices) - 2 for p in me.polygons)
    for o in got.values():
        bpy.data.objects.remove(o, do_unlink=True)
    root = empty("Arrows", V(0, 0, 0))
    arrows = []
    slots = []
    rng = random.Random(24)
    for i in range(Q_ARROWS):
        r = math.sqrt((i + 0.5) / Q_ARROWS) * 0.80
        th = i * math.radians(137.508)
        px, pz = r * 0.049 * math.cos(th), r * 0.039 * math.sin(th)
        d = V(px * 1.4, 1.0, pz * 1.4).normalized()
        seat = Q_ARROW_SEAT + (rng.random() - 0.4) * 0.03
        tip = V(px, 0.0, pz) - d * seat
        roll = rng.random() * 360.0
        basis = rot_axis(d, roll) @ basis_from(z=d, y=V(0, 0, 1) - d * d.z)
        o = bpy.data.objects.new("Arrow_%02d" % (i + 1), me)
        bpy.context.scene.collection.objects.link(o)
        o.matrix_world = to_bmat(basis, tip)
        o.parent = root
        o.matrix_world = to_bmat(basis, tip)
        arrows.append(o)
        slots.append((tip, basis))
    markers = {
        "Mouth": (V(0, 0, 0), None, "origin: centre of the mouth; +Y out of the mouth, +Z away from the wearer's back"),
        "Nocks": (V(0, 0.72 - Q_ARROW_SEAT, 0), None, "top of the arrow nocks (full quiver)"),
        "ArrowReach": (V(0, 0.105, 0), None, "where the drawing hand closes on an arrow (fletching)"),
        "Bottom": (V(0, -0.5695, 0), None, "bottom of the rawhide cup"),
        "StrapTop": (strap_marks["StrapTop"], None, "quiver strap anchor: upper tab (strap passes along X)"),
        "StrapBottom": (strap_marks["StrapBottom"], None, "quiver strap anchor: lower tab"),
        "COM": (V(0, -0.24, 0.0), None, "approximate centre of mass with 24 arrows"),
    }
    objs = [body, root] + arrows + marker_objs(markers)
    return {
        "objects": objs, "markers": markers, "hidden": [],
        "title": "Leather back quiver with arrows",
        "frame": "own (the carry_gear.json quiver.quiver stow frame)",
        "pivot": "centre of the mouth (the stow origin of quiver.quiver)",
        "axes": "+Y out of the mouth along the quiver, +Z away from the wearer's back, +X = Y x Z (the side seam and its fringe are on -X, toward the spine when worn behind the right shoulder)",
        "nodes": {"Quiver": "leather tube, buckskin collar and fringe, rawhide bottom cup, side-seam welt and fringe, two strap tabs",
                  "Arrows": "parent of Arrow_01..Arrow_24, linked duplicates of one mesh (QuiverArrow: the top %.2f m of assets/weapons/arrow.glb, %d tris); index order = fill order (centre first), show the first `count`" % (0.72 - Q_CLIP, arrow_tris)},
        "counts": {"arrows_max": Q_ARROWS, "fill_order": "Arrow_01 (centre) .. Arrow_24 (rim)",
                   "runtime": "LoadoutModels.set_arrow_count(model, n) (MultiMesh visible_instance_count)"},
        "dimensions": {"body_length_m": Q_LEN + 0.0095, "mouth_m": [0.112, 0.092], "nocks_above_mouth_m": round(0.72 - Q_ARROW_SEAT, 3),
                       "overall_with_arrows_m": round(0.72 - Q_ARROW_SEAT + Q_LEN + 0.0095, 3)},
        "carry_points": ["quiver.quiver"],
        "history": "Eastern Woodlands quivers of skin or bark were worn on the back (general practice, grade B in body_fit_history.md). Construction here (leather tube, buckskin collar, fringed side seam, rawhide cup) is a plausible reconstruction, not a copy of a specific surviving piece.",
        "slots": slots,
    }


# ----------------------------------------------------------- powder horn --
H_CHORD = 0.200
H_SAG = (-0.036, 0.012)        # bulge of the centreline (outward -X, up +Y) at mid length
H_R = [(0.0, 0.0300), (0.028, 0.0303), (0.036, 0.0315), (0.044, 0.0315), (0.052, 0.0302), (0.2, 0.0262),
       (0.4, 0.0210), (0.6, 0.0160), (0.75, 0.0122), (0.84, 0.0098), (0.852, 0.0112), (0.866, 0.0115),
       (0.878, 0.0092), (0.892, 0.0091), (0.902, 0.0105), (0.914, 0.0103), (0.924, 0.0084), (0.97, 0.0075),
       (1.0, 0.0071)]
H_OVAL = 0.93


def h_c(t):
    s = math.sin(math.pi * min(max(t, 0.0), 1.0) ** 0.92)
    return V(H_SAG[0] * s, H_SAG[1] * s, H_CHORD * t)


def h_t(t):
    e = 1e-3
    return (h_c(min(t + e, 1.0)) - h_c(max(t - e, 0.0))).normalized()


def build_powder_horn():
    mb = MB()
    ts = sorted(set([k / 40 for k in range(41)] + [t for t, _ in H_R]))
    path = [h_c(t) for t in ts]
    T, N, B = ptf(path, V(1, 0, 0))
    n = 24
    rings = []
    for i, t in enumerate(ts):
        r = interp(H_R, t)
        rings.append([path[i] + N[i] * (r * math.cos(TAU * j / n)) + B[i] * (r * H_OVAL * math.sin(TAU * j / n)) for j in range(n)])
    us = [j / n for j in range(n + 1)]
    vv = mb.grid(rings, us, ts, "LoadoutHorn", out_fn=lambda i, j, pc: pc - (path[i] + path[i + 1]) * 0.5)
    # Spout end face: an annulus round the stopper hole.
    tip, t1 = path[-1], T[-1]
    hole = [tip + N[-1] * (0.0037 * math.cos(TAU * j / n)) + B[-1] * (0.0037 * math.sin(TAU * j / n)) for j in range(n)]
    hv = mb.verts(hole)
    for j in range(n):
        j2 = (j + 1) % n
        mb.face([vv[-1][j], vv[-1][j2], hv[j2], hv[j]], [(j / n, 0.99), ((j + 1) / n, 0.99), ((j + 1) / n, 1.0), (j / n, 1.0)], "LoadoutHorn", t1)
    # Base rim (horn wall), hidden behind the plug's bead.
    base0, tb = path[0], -T[0]
    inner = [base0 + N[0] * (0.0273 * math.cos(TAU * j / n)) + B[0] * (0.0273 * H_OVAL * math.sin(TAU * j / n)) for j in range(n)]
    iv = mb.verts(inner)
    for j in range(n):
        j2 = (j + 1) % n
        mb.face([vv[0][j], vv[0][j2], iv[j2], iv[j]], [(j / n, 0.0), ((j + 1) / n, 0.0), ((j + 1) / n, 0.005), (j / n, 0.005)], "LoadoutHorn", tb)
    # Wooden base plug: domed, with a turned finial.
    plug_o = base0 + T[0] * 0.003
    prof = [(0.0, 0.0272), (0.003, 0.0278), (0.0045, 0.0286), (0.0062, 0.0277), (0.0085, 0.0256), (0.0110, 0.0221),
            (0.0135, 0.0175), (0.0152, 0.0125), (0.0162, 0.0080), (0.0166, 0.0066), (0.0190, 0.0057), (0.0205, 0.0069),
            (0.0228, 0.0065), (0.0252, 0.0041), (0.0266, 0.0015)]
    lathe(mb, plug_o, tb, prof, "LoadoutPlugWood", n=24, ref=N[0], rscale=(1.0, H_OVAL), cap0=True, cap1=True)
    # Brass staple on the dome, on the top (+Y) side.
    up = B[0] if B[0].y > 0 else -B[0]
    d_st, r_st = 0.0110, 0.0214
    c_st = plug_o + tb * d_st + up * (r_st * H_OVAL)
    nrm_st = (tb * 0.55 + up * 0.85).normalized()
    across = tb.cross(up).normalized()
    arch = [c_st - nrm_st * 0.003 + across * 0.0055 * math.cos(s) + nrm_st * 0.0062 * math.sin(s)
            for s in [math.pi * k / 10 for k in range(11)]]
    arch = [arch[0] - nrm_st * 0.002] + arch + [arch[-1] - nrm_st * 0.002]
    tube(mb, arch, 0.0011, "LoadoutBrass", n=6)
    staple_top = c_st + nrm_st * 0.0032
    # Brass tacks holding the plug, round the horn 1 cm from the mouth.
    for k in range(10):
        th = TAU * (k + 0.5) / 10
        i0 = ts.index(0.028)
        rr = interp(H_R, 0.028)
        radial = N[i0] * math.cos(th) + B[i0] * (H_OVAL * math.sin(th))
        p = path[i0] + radial * rr
        lathe(mb, p - radial.normalized() * 0.0006, radial, [(0.0, 0.0021), (0.0007, 0.0021), (0.0012, 0.0016), (0.0016, 0.0009), (0.0018, 0.0002)],
              "LoadoutBrass", n=8, cap1=True)
    # Wooden stopper in the spout.
    st_o = tip - t1 * 0.012
    lathe(mb, st_o, t1, [(0.0, 0.0034), (0.012, 0.0037), (0.0155, 0.0043), (0.0180, 0.0046), (0.0195, 0.0053),
                         (0.0222, 0.0057), (0.0245, 0.0049), (0.0260, 0.0028), (0.0266, 0.0008)],
          "LoadoutStopperWood", n=12, cap0=True, cap1=True)
    # Strap ties: a thong loop through the staple, two thong turns in the spout groove with a loop.
    loop_c = staple_top + nrm_st * 0.0045
    loop = [loop_c + nrm_st * 0.0065 * math.cos(TAU * k / 12) + tb * 0.0065 * math.sin(TAU * k / 12) for k in range(12)]
    band(mb, loop, 0.0045, 0.0016, "LoadoutLeather", width_axis=across, closed=True)
    i_g = ts.index(0.878)
    rg = interp(H_R, 0.878) + 0.0010
    for dz in (-0.0022, 0.0022):
        ring = [path[i_g] + T[i_g] * dz + N[i_g] * (rg * math.cos(TAU * k / 16)) + B[i_g] * (rg * H_OVAL * math.sin(TAU * k / 16)) for k in range(16)]
        band(mb, ring, 0.0040, 0.0015, "LoadoutLeather", width_axis=T[i_g], closed=True)
    up_g = B[i_g] if B[i_g].y > 0 else -B[i_g]
    knot = path[i_g] + up_g * (rg * H_OVAL + 0.002)
    blob(mb, knot, T[i_g], 0.0045, 0.0032, "LoadoutLeather", n=8)
    sl_c = knot + up_g * 0.0085
    sloop = [sl_c + up_g * 0.0065 * math.cos(TAU * k / 12) + T[i_g] * 0.0065 * math.sin(TAU * k / 12) for k in range(12)]
    band(mb, sloop, 0.0045, 0.0016, "LoadoutLeather", width_axis=up_g.cross(T[i_g]).normalized(), closed=True)
    horn = mb.to_object("PowderHorn")
    strap_base = loop_c + nrm_st * 0.0065
    strap_spout = sl_c + up_g * 0.0065
    # Hidden display strap: a loop hanging from a peg ~0.3 m above the horn.
    mb2 = MB()
    mid = h_c(0.45)
    pts = [strap_base, strap_base + V(0, 0.09, -0.01), mid + V(-0.01, 0.27, 0.0), strap_spout + V(0, 0.11, 0.01), strap_spout]
    spath = catmull(pts, 8)
    band(mb2, spath, 0.018, 0.0028, "LoadoutLeather", width_axis=V(1, 0, 0))
    strap = mb2.to_object("StrapPreview")
    i_mid = ts.index(0.5)
    markers = {
        "Plug": (V(0, 0, 0), None, "origin: centre of the horn mouth where the plug sits; +Z along the chord to the spout, +Y up, the curve bulges to -X"),
        "PlugApex": (plug_o + tb * 0.0266, None, "end of the plug finial"),
        "Staple": (staple_top, None, "brass staple on the plug (strap tie)"),
        "StrapBase": (strap_base, None, "strap anchor at the plug end (top of the thong loop)"),
        "SpoutRing": (path[i_g] + up_g * (rg * H_OVAL), None, "carved spout ring groove where the strap is tied"),
        "StrapSpout": (strap_spout, None, "strap anchor at the spout end (top of the thong loop)"),
        "SpoutTip": (tip + t1 * 0.0266, None, "end of the stopper"),
        "Bend": (path[i_mid], None, "middle of the curve"),
        "COM": (h_c(0.33), None, "approximate centre of mass (filled horn)"),
    }
    objs = [horn, strap] + marker_objs(markers)
    return {
        "objects": objs, "markers": markers, "hidden": ["StrapPreview"],
        "title": "Powder horn (curved cow horn) with strap ties",
        "frame": "own",
        "pivot": "centre of the horn mouth at the base plug (the plug end of the carry_gear.json horn capsule)",
        "axes": "+Z along the chord from the plug to the spout, +Y up when hanging, +X = Y x Z; the curve bulges toward -X (away from the body in the reference placement) and 1.2 cm up",
        "nodes": {"PowderHorn": "horn body (procedural horn texture, growth rings at the base, dark tip), domed wooden plug with a turned finial, brass staple, 10 brass tacks, carved spout rings, wooden stopper, thong ties at the staple and the spout ring",
                  "StrapPreview": "hidden (KHR_node_visibility): a 1.8 cm leather strap loop between StrapBase and StrapSpout, for display on its own; on the body the strap is the runtime ribbon"},
        "dimensions": {"chord_mouth_to_spout_m": H_CHORD, "overall_plug_to_stopper_m": round(H_CHORD + 0.0266 + 0.0146, 3),
                       "along_outer_curve_m": 0.27, "base_radius_m": 0.0300, "spout_radius_m": 0.0071},
        "carry_points": ["horn.powder_horn (reference only in carry_gear.json; see reference_bind_placement)"],
        "history": "A bullock's horn on a strap over the left shoulder (Knox 1757, via the costume bible [M2]; grade A for the horn and strap, grade C for its place behind the right hip, loadout_design.md 2.6). Sized to the measured placement envelope (plug radius 3.2 cm, spout 1.8 cm, chord 0.195 m), so it reads as a horn, not a lump.",
    }


# ----------------------------------------------------------- spear pair --
SP_X = 0.018            # each spear's axis 1.8 cm from the pair's centre (3.6 cm apart)
SP_LASH = (-0.36, 0.60)


def lash_turns(mb, z0, r, mat, turns=5, pitch=0.0052, half=SP_X, w=0.0048, t=0.0019):
    R = r + t * 0.5 + 0.0003
    for k in range(turns):
        z = z0 + (k - (turns - 1) / 2) * pitch
        pts = []
        for s in range(9):
            a = -math.pi / 2 + math.pi * s / 8
            pts.append(V(half + R * math.cos(a), R * math.sin(a), z))
        for s in range(9):
            a = math.pi / 2 + math.pi * s / 8
            pts.append(V(-half + R * math.cos(a), R * math.sin(a), z))
        band(mb, pts, w, t, mat, width_axis=V(0, 0, 1), closed=True)
    return R + t * 0.5


def frap(mb, z0, outer, mat, half_z, xs=(-0.0026, 0.0026)):
    for x in xs:
        ya, za, c = outer + 0.0014, half_z + 0.0026, 0.0028
        corners = [(ya - c, za), (ya, za - c), (ya, -za + c), (ya - c, -za), (-ya + c, -za), (-ya, -za + c), (-ya, za - c), (-ya + c, za)]
        pts = [V(x, y, z0 + z) for y, z in corners]
        band(mb, pts, 0.0042, 0.0017, mat, width_axis=V(1, 0, 0), closed=True, bv=0.0005)


def thong_loop(mb, centre, r, mat, plane_a, plane_b, w=0.0042, t=0.0016):
    pts = [centre + plane_a * r * math.cos(TAU * k / 12) + plane_b * r * math.sin(TAU * k / 12) for k in range(12)]
    band(mb, pts, w, t, mat, width_axis=plane_a.cross(plane_b).normalized(), closed=True)


def build_spear_pair_tie():
    mb = MB()
    marks = {}
    for z0, name in zip(SP_LASH, ("ThongUpper", "ThongLower")):
        r = HOST["spear_r"][z0]
        outer = lash_turns(mb, z0, r, "LoadoutBuckskin")
        frap(mb, z0, outer, "LoadoutBuckskin", 2 * 0.0052 + 0.0024)
        kp = V(0.0, outer + 0.0035, z0 + 0.0165)
        blob(mb, kp, V(0, 0, 1), 0.0055, 0.0038, "LoadoutBuckskin", n=8)
        for sx in (-1, 1):
            tail = [kp + V(0.002 * sx, 0.0, 0.003), kp + V(0.004 * sx, 0.001, 0.02), kp + V(0.005 * sx, -0.001, 0.038), kp + V(0.004 * sx, -0.003, 0.05)]
            band(mb, tail, 0.0040, 0.0014, "LoadoutBuckskin", width_axis=V(1, 0, 0))
        lc = V(0.0, -(outer + 0.0072), z0)
        thong_loop(mb, lc, 0.0075, "LoadoutBuckskin", V(0, 1, 0), V(0, 0, 1))
        marks[name] = V(0.0, -(outer + 0.0147), z0)
    tie = mb.to_object("SpearTie")
    mb2 = MB()
    a, b = marks["ThongUpper"], marks["ThongLower"]
    pts = [a, a + V(0, -0.06, 0.12), (a + b) * 0.5 + V(0, -0.14, 0), b + V(0, -0.06, -0.12), b]
    band(mb2, catmull(pts, 8), 0.015, 0.002, "LoadoutBuckskin", width_axis=V(1, 0, 0))
    thong = mb2.to_object("ThongPreview")
    markers = {
        "Centre": (V(0, 0, 0), None, "origin: between the two spears' balance points (the spear_pair stow origin)"),
        "Spear_1": (V(-SP_X, 0, 0), rot_axis((0, 0, 1), 180.0), "model transform of the first spear (ThrowableModels spear; trim tails outward)"),
        "Spear_2": (V(SP_X, 0, 0), rot_axis((0, 0, 1), 90.0), "model transform of the second spear"),
        "ThongUpper": (marks["ThongUpper"], None, "carrying thong anchor at the upper lashing (z -0.36, below the heads)"),
        "ThongLower": (marks["ThongLower"], None, "carrying thong anchor at the lower lashing (z +0.60)"),
        "Points": (V(0, 0, -0.8073), None, "spear points (-Z)"),
        "Butts": (V(0, 0, 0.9927), None, "spear butts (+Z)"),
    }
    objs = [tie, thong] + marker_objs(markers)
    return {
        "objects": objs, "markers": markers, "hidden": ["ThongPreview"],
        "title": "Spear pair lashing (two throwing spears tied for carrying)",
        "frame": "spear pair = ThrowableModels spear frame, centred between the two spears",
        "pivot": "between the two spears' balance points (the spear model origin), i.e. the long_A / long_B.spear_pair stow origin",
        "axes": "spear axes: -Z toward the points, +Z toward the butts; the spears lie side by side along X (Spear_1 at x -0.018, Spear_2 at x +0.018); +Y away from the wearer's back in the stow frame",
        "nodes": {"SpearTie": "two buckskin thong lashings (5 turns + 2 frapping turns, knot and tails) at z -0.36 and +0.60, each with a carrying-thong loop on the -Y (body) side",
                  "ThongPreview": "hidden: a 1.5 cm carrying thong between the two loops, for display; on the body the thong is the runtime ribbon"},
        "counts": {"spears_max": 2, "runtime": "LoadoutModels.slot_transforms(model, 'Spear_') -> spear model transforms; show the spears still carried (the thong stays when both are thrown)"},
        "dimensions": {"spear_axis_gap_m": 2 * SP_X, "lashing_z_m": list(SP_LASH), "shaft_radius_m": {str(k): round(v, 4) for k, v in HOST["spear_r"].items()}},
        "carry_points": ["long_A.spear_pair", "long_B.spear_pair"],
        "history": "Game placement (grade C): the throwables design carries two throwing spears tied together on the back. Rawhide or buckskin lashing with frapping turns is ordinary period practice for binding poles.",
    }


# ----------------------------------------------------------- dart bundle --
D_RING = 0.015
D_STAGGER = (0.0, 0.018, 0.006, 0.024, 0.012)
D_TIES = (0.495, 1.155)


def build_dart_bundle():
    mb = MB()
    rs = HOST["dart_r"]

    def wrinkle(k, th, d):
        neck = 1.0 - smooth01((d + 0.036) / 0.05)
        top = smooth01((d - 0.17) / 0.04)
        body = 0.045 * math.sin(4 * th + 6 * d + 0.7) + 0.025 * math.sin(7 * th - 4 * d)
        pleat = 0.16 * math.sin(9 * th + 40 * d)
        return 1.0 + neck * pleat + (1 - neck) * (1 - top) * body + top * 0.07 * math.sin(8 * th + 25 * d)
    prof = [(-0.036, 0.0064), (-0.031, 0.0105), (-0.024, 0.0180), (-0.014, 0.0250), (0.002, 0.0298), (0.040, 0.0312),
            (0.090, 0.0306), (0.140, 0.0291), (0.180, 0.0272), (0.200, 0.0256), (0.212, 0.0247), (0.222, 0.0253),
            (0.232, 0.0269), (0.238, 0.0275), (0.2385, 0.0258), (0.232, 0.0244)]
    lathe(mb, V(0, 0, 0), V(0, 0, 1), prof, "LoadoutBuckskin", n=28, ref=V(1, 0, 0), rfunc=wrinkle)
    # Overlapping edge of the wrapped hide, a slow spiral along the cover.
    flap, fn = [], []
    for k in range(15):
        d = 0.004 + 0.198 * k / 14
        th = 1.0 + 1.2 * d
        r = interp(prof[:13], d) * wrinkle(0, th, d) + 0.0009
        flap.append(V(r * math.cos(th), r * math.sin(th), d))
        fn.append(V(math.cos(th), math.sin(th), 0.0))
    band(mb, flap, 0.010, 0.0013, "LoadoutBuckskin", normals=fn, bv=0.0004)
    # Tuft of the gathered end.
    lathe(mb, V(0, 0, 0), V(0, 0, 1), [(-0.036, 0.0060), (-0.042, 0.0078), (-0.050, 0.0098), (-0.057, 0.0102), (-0.0575, 0.004)],
          "LoadoutBuckskin", n=12, ref=V(1, 0, 0), rfunc=lambda k, th, d: 1.0 + 0.25 * math.sin(9 * th) * (k >= 3), cap1=True)
    # Ties on the cover (neck and top) and round the bundle at 30 % and 70 %.
    def turns(z0, r, count, pitch=0.0042, hull=None):
        for k in range(count):
            z = z0 + (k - (count - 1) / 2) * pitch
            if hull is None:
                pts = [V(r * math.cos(TAU * s / 16), r * math.sin(TAU * s / 16), z) for s in range(16)]
            else:
                pts = [V(p.x, p.y, z) for p in hull]
            band(mb, pts, 0.0038, 0.0016, "LoadoutBuckskin", width_axis=V(0, 0, 1), closed=True)

    def hull(rho):
        """Convex hull of the five dart shafts (arcs round each, joined by tangents)."""
        pts = []
        for i in range(5):
            thc = math.radians(90 + 72 * i)
            c = V(D_RING * math.cos(thc), D_RING * math.sin(thc), 0)
            for s in range(5):
                a = thc + math.radians(-36 + 18 * s)
                pts.append(c + V(rho * math.cos(a), rho * math.sin(a), 0))
        return pts
    turns(-0.0355, 0.0074, 2)
    turns(0.2115, 0.0262, 3)
    blob(mb, V(0, 0.0290, 0.2115), V(0, 0, 1), 0.005, 0.0034, "LoadoutBuckskin", n=8)
    marks = {}
    for z0, name in zip(D_TIES, ("ThongLower", "ThongUpper")):
        h = hull(rs.get(z0, 0.0075) + 0.0010)
        turns(z0, 0.0, 3, hull=h)
        ytop = max(p.y for p in h)
        ybot = min(p.y for p in h)
        blob(mb, V(0, ytop + 0.0030, z0), V(0, 0, 1), 0.0055, 0.0036, "LoadoutBuckskin", n=8)
        lc = V(0, ybot - 0.0086, z0)
        thong_loop(mb, lc, 0.0075, "LoadoutBuckskin", V(0, 1, 0), V(0, 0, 1))
        marks[name] = V(0, ybot - 0.0161, z0)
    cover = mb.to_object("DartBundle")
    mb2 = MB()
    a, b = marks["ThongUpper"], marks["ThongLower"]
    pts = [a, a + V(0, -0.05, -0.1), (a + b) * 0.5 + V(0, -0.12, 0), b + V(0, -0.05, 0.1), b]
    band(mb2, catmull(pts, 8), 0.015, 0.002, "LoadoutBuckskin", width_axis=V(1, 0, 0))
    thong = mb2.to_object("ThongPreview")
    markers = {"Tips": (V(0, 0, 0), None, "origin: centre of the ring of dart tips; +Z toward the nocks, +Y away from the wearer's back")}
    for i in range(5):
        th = math.radians(90 + 72 * i)
        markers["Dart_%d" % (i + 1)] = (V(D_RING * math.cos(th), D_RING * math.sin(th), D_STAGGER[i]),
                                        rot_axis((0, 0, 1), 72 * i + 17 * (i % 2)), "model transform of dart %d (ThrowableModels atlatl_dart: origin at its tip)" % (i + 1))
    markers.update({
        "Nocks": (V(0, 0, 1.65), None, "nock ends"),
        "ThongLower": (marks["ThongLower"], None, "carrying thong anchor at the 30 % tie"),
        "ThongUpper": (marks["ThongUpper"], None, "carrying thong anchor at the 70 % tie"),
        "Cover": (V(0, 0, 0.10), None, "middle of the point cover"),
        "COM": (V(0, 0, 0.70), None, "approximate centre of mass of a full bundle"),
    })
    objs = [cover, thong] + marker_objs(markers)
    return {
        "objects": objs, "markers": markers, "hidden": ["ThongPreview"],
        "title": "Dart bundle: buckskin point cover and ties for five atlatl darts",
        "frame": "dart bundle = ThrowableModels atlatl_dart frame (origin at the tip, +Z to the nock), centred on the ring of five darts",
        "pivot": "centre of the ring of dart tips (the long_A / long_B.dart_bundle stow origin)",
        "axes": "+Z from the tips to the nocks; five darts in a ring of radius 1.5 cm; +Y away from the wearer's back in the stow frame",
        "nodes": {"DartBundle": "wrinkled buckskin cover gathered and tied over the five stone points (to z 0.24), thong ties at 30 % (z 0.495) and 70 % (z 1.155) with carrying-thong loops on -Y",
                  "ThongPreview": "hidden: a 1.5 cm carrying thong between the two loops, for display"},
        "counts": {"darts_max": 5, "runtime": "LoadoutModels.slot_transforms(model, 'Dart_') -> dart transforms; show count - (1 if a dart is on the board)"},
        "dimensions": {"ring_radius_m": D_RING, "cover_length_m": 0.2735, "tie_z_m": list(D_TIES), "dart_length_m": 1.65},
        "carry_points": ["long_A.dart_bundle", "long_B.dart_bundle"],
        "history": "Game licence (grade C): the atlatl is not a 1750s Eastern Woodlands weapon. The bundle uses period materials (smoked buckskin, thong ties) and protects the stone points the way arrow points were wrapped.",
    }


# ---------------------------------------------------------- musket sling --
SL_W = 0.023
SL_T = 0.0035


def sling_end(mb, bar, u, down_v, length_out, length_in, buckle):
    """Strap looped round a swivel's bottom bar at `bar`; u = along the gun toward the middle."""
    e = 0.0016 + SL_T * 0.5
    X = V(1, 0, 0)
    # U turn round the bar (on the far side from the middle).
    turn = [bar + down_v * (-e * math.cos(a)) + u * (-e * math.sin(a)) for a in [math.pi * k / 8 for k in range(9)]]
    outer = [bar + down_v * e + u * (length_out * k / 6) for k in range(7)]
    inner = [bar - down_v * e + u * 0.0, bar - down_v * (e * 0.6) + u * 0.012, bar + down_v * (e - SL_T) + u * 0.028]
    inner += [bar + down_v * (e - SL_T) + u * (0.028 + (length_in - 0.028) * k / 3) for k in range(1, 4)]
    path = list(reversed(inner)) + turn[1:-1] + outer
    band(mb, path, SL_W, SL_T, "LoadoutLeather", width_axis=X, bv=0.001)
    # Keeper round both layers.
    kc = bar + u * (length_in * 0.55) + down_v * (e - SL_T * 0.5)
    hy, hx = SL_T + 0.0022, SL_W * 0.5 + 0.0018
    ring = [kc + X * hx + down_v * hy, kc - X * hx + down_v * hy, kc - X * hx - down_v * hy, kc + X * hx - down_v * hy]
    ring = catmull(ring, 3, closed=True)
    band(mb, ring, 0.011, 0.0022, "LoadoutLeather", width_axis=u, closed=True, bv=0.0006)
    if buckle:
        bc = bar + u * (length_in + 0.004) + down_v * (e + SL_T * 0.5 + 0.0015)
        hx2, hz2, rr = SL_W * 0.5 + 0.004, 0.010, 0.0035
        cs = [(hx2 - rr, hz2), (-hx2 + rr, hz2), (-hx2, hz2 - rr), (-hx2, -hz2 + rr), (-hx2 + rr, -hz2), (hx2 - rr, -hz2), (hx2, -hz2 + rr), (hx2, hz2 - rr)]
        frame = catmull([bc + X * a + u * b for a, b in cs], 3, closed=True)
        tube(mb, frame, 0.0021, "LoadoutBrass", n=6, closed=True, n0=down_v)
        tube(mb, [bc + X * hx2, bc - X * hx2], 0.0019, "LoadoutBrass", n=6)
        tongue = [bc + down_v * 0.0005, bc + u * 0.008 + down_v * 0.0012, bc + u * 0.0135 + down_v * 0.0008, bc + u * 0.0145 - down_v * 0.002]
        tube(mb, tongue, 0.0011, "LoadoutBrass", n=5)
    else:
        sc = bar + u * (length_in * 0.85) + down_v * (e + SL_T * 0.5)
        lathe(mb, sc - down_v * 0.0005, down_v, [(0.0, 0.0034), (0.0009, 0.0033), (0.0018, 0.0024), (0.0024, 0.0010), (0.0026, 0.0)],
              "LoadoutBrass", n=10, cap0=True)
    return bar + down_v * e + u * length_out


def build_musket_sling():
    mb = MB()
    s_r, xr = HOST["swivel_rear"]
    s_f, xf = HOST["swivel_front"]
    u = (s_f - s_r).normalized()
    down_v = V(0, -1, 0) - u * V(0, -1, 0).dot(u)
    down_v.normalize()
    end_r = sling_end(mb, s_r, u, down_v, 0.11, 0.068, False)
    end_f = sling_end(mb, s_f, -u, down_v, 0.11, 0.050, True)
    ends = mb.to_object("SlingEnds")
    mb2 = MB()
    path = [end_r + (end_f - end_r) * (k / 10) for k in range(11)]
    band(mb2, path, SL_W, SL_T, "LoadoutLeather", width_axis=V(1, 0, 0), bv=0.001)
    taut = mb2.to_object("SlingTaut")
    markers = {
        "SwivelRear": (s_r, None, "centre of the rear swivel's bottom bar (musket.glb, front of the trigger guard)"),
        "SwivelFront": (s_f, None, "centre of the front swivel's bottom bar (under the middle ramrod pipe)"),
        "StrapRear": (end_r, None, "sling ribbon anchor at the rear end (the strap continues from here)"),
        "StrapFront": (end_f, None, "sling ribbon anchor at the front end"),
    }
    objs = [ends, taut] + marker_objs(markers)
    return {
        "objects": objs, "markers": markers, "hidden": ["SlingTaut"],
        "title": "Musket sling ends (leather strap, brass buckle, keepers)",
        "frame": "WeaponModels musket frame (assets/weapons/musket.glb): add as a child of the musket model with an identity transform",
        "pivot": "the musket's origin (wrist of the stock); fittings at the two sling swivels",
        "axes": "musket axes: -Z muzzle, +Y top, +X lock side",
        "nodes": {"SlingEnds": "strap looped round each swivel's bottom bar and doubled back 5-7 cm, a keeper on each end, a brass frame buckle with tongue at the front end, a brass stud at the rear end",
                  "SlingTaut": "hidden: the strap straight between the two ends (sling drawn tight along the stock), for the musket in hand, on a rack or on the ground"},
        "dimensions": {"strap_width_m": SL_W, "strap_thickness_m": SL_T, "swivel_inner_half_width_m": [round(xr - 0.0032, 4), round(xf - 0.0032, 4)],
                       "rear_bar": rnd(s_r), "front_bar": rnd(s_f)},
        "carry_points": ["long_A.musket", "long_B.musket (and over_under if its swivels match)"],
        "history": "Leather musket sling with a brass buckle through the Land Pattern's iron swivels (general 18th-century practice, grade B; buff for regulars, russet here for a frontier kit).",
    }


# ------------------------------------------------------- pistol belt hook --
def build_pistol_belt_hook():
    mb = MB()
    y0 = 0.0376
    xp = -0.0189            # outer face of the pistol's brass side plate (pistol.py)
    t, w = 0.0028, 0.0095
    xin = -0.0265           # inner face of the hook bar: a 7.6 mm gap for the belt
    pts = [V(xp - t / 2, y0, -0.030), V(xp - t / 2, y0, -0.042), V(xp - t / 2 - 0.0012, y0, -0.049),
           V((xp + xin) / 2 - t / 2 - 0.002, y0, -0.055), V(xin - t / 2, y0, -0.061), V(xin - t / 2, y0, -0.080),
           V(xin - t / 2, y0, -0.110), V(xin - t / 2, y0, -0.140), V(xin - t / 2 - 0.0008, y0, -0.152),
           V(xin - t / 2 - 0.0025, y0, -0.160)]
    path = catmull(pts, 3)
    band(mb, path, w, t, "LoadoutSteel", width_axis=V(0, 1, 0), bv=0.0006)
    # Rounded ends: the boss under the rear side nail and the spoon-shaped tip.
    lathe(mb, V(xp, y0, -0.034), V(-1, 0, 0), [(0.0, 0.0062), (t * 0.8, 0.0062), (t, 0.0054), (t, 0.0)], "LoadoutSteel", n=16, ref=V(0, 1, 0))
    tipc = path[-1]
    lathe(mb, tipc + V(t / 2, 0, 0), V(-1, 0, 0), [(0.0, 0.0), (0.0, 0.0050), (t * 0.2, 0.0054), (t * 0.8, 0.0054), (t, 0.0048), (t, 0.0)],
          "LoadoutSteel", n=14, ref=V(0, 1, 0))
    # New screw head over the boss (the rear side nail passes through the hook).
    lathe(mb, V(xp - t, y0, -0.034), V(-1, 0, 0), [(0.0, 0.0034), (0.0006, 0.0034), (0.0011, 0.0027), (0.0015, 0.0012), (0.0016, 0.0)],
          "LoadoutSteel", n=12, ref=V(0, 1, 0))
    hook = mb.to_object("BeltHook")
    markers = {
        "Hook": (V((xp + xin) / 2, y0, -0.075), None, "belt seat: centre of a 4 cm belt pushed up to the closed end of the hook (the belt runs along Y here, its width along Z, its thickness along X)"),
        "HookTip": (V(xin - t / 2 - 0.0025, y0, -0.160), None, "free end of the hook"),
        "HookScrew": (V(xp - t - 0.0016, y0, -0.034), None, "rear side nail through the hook"),
        "Tuck": (V(0.0, 0.035, -0.125), None, "where a belt or sash crosses the pistol when it is thrust through (just ahead of the lock and guard)"),
    }
    objs = [hook] + marker_objs(markers)
    return {
        "objects": objs, "markers": markers, "hidden": [],
        "title": "Pistol belt hook (and tuck point)",
        "frame": "WeaponModels pistol frame (assets/weapons/pistol.glb): add as a child of the pistol model with an identity transform",
        "pivot": "the pistol's origin (the grip)",
        "axes": "pistol axes: -Z muzzle, +Y top, +X lock side; the hook is on the left flat (-X)",
        "nodes": {"BeltHook": "flat bright steel hook, 12.6 cm x 9.5 mm, fixed by the rear side nail on the brass side plate and running forward along the fore-stock 7.6 mm off it (room for a 5 mm belt), spoon-shaped free end"},
        "dimensions": {"length_m": 0.130, "bar_m": [w, t], "belt_gap_m": round(xp - xin, 4)},
        "carry_points": ["R_hip.pistol (hooked, lock out)", "L_hip.pistol / back_right.pistol: tucked (hook hidden or unused; use the Tuck marker)"],
        "history": "A long steel belt hook on the left side of the stock, fixed by the rear lock screw, let a pistol be carried in a waist or cross belt; the 1756 pattern long sea-service pistol had one (loadout_design.md [W2][W3], grade B). Hooked with its left flat to the belt the pistol hangs lock out.",
    }


# ----------------------------------------------------------- pistol sling --
PS_W, PS_T = 0.050, 0.0030


def build_pistol_sling():
    mb = MB()
    # Holster loop round the fore-stock of a chest pistol, sewn to the sling band on the +X
    # (lock) side: carry_gear.json chest_R / chest_L lay the pistol along the band, lock in.
    xb = 0.0335
    z0 = -0.142
    loop = [V(xb, 0.071, 0), V(0.020, 0.0735, 0), V(0.002, 0.0715, 0), V(-0.012, 0.064, 0), V(-0.0185, 0.046, 0),
            V(-0.015, 0.026, 0), V(-0.003, 0.0155, 0), V(0.015, 0.0125, 0), V(xb, 0.0120, 0)]
    loop = catmull(loop, 3)
    for dz in (0.0,):
        band(mb, [p + V(0, 0, z0 + dz) for p in loop], 0.026, 0.0032, "LoadoutLeather", width_axis=V(0, 0, 1), bv=0.0009)
    # Sewn tabs of the loop and a reinforcing patch on the band.
    for y in (0.078, 0.0055):
        box(mb, V(xb + 0.0016, y, z0), V(0.0016, 0, 0), V(0, 0.0085, 0), V(0, 0, 0.0125), "LoadoutLeather")
    box(mb, V(xb + 0.0045, 0.042, z0), V(0.0012, 0, 0), V(0, 0.030, 0), V(0, 0, 0.030), "LoadoutLeather")
    loop_obj = mb.to_object("PistolLoop")
    markers = {
        "LoopCentre": (V(0.0, 0.042, z0), None, "centre of the loop round the pistol's fore-stock"),
        "BandSeat": (V(xb + 0.0045 + 0.0027, 0.042, z0), None, "sling band centreline under the loop, on the outer face of the patch: ribbon anchor (the band runs along the pistol's Z here, its width along Y)"),
    }
    objs = [loop_obj] + marker_objs(markers)
    return {
        "objects": objs, "markers": markers, "hidden": [],
        "title": "Pistol sling holster loop (one per chest pistol)",
        "frame": "WeaponModels pistol frame (assets/weapons/pistol.glb): add as a child of each stowed chest pistol with an identity transform",
        "pivot": "the pistol's origin (grip)",
        "axes": "pistol axes (-Z muzzle, +Y top, +X lock side); the loop wraps the -X side and is sewn to a band lying on the +X (lock) side, as carry_gear.json chest_R / chest_L carry the pistol along the band, lock toward the body. Mirror x for a lock-out variant.",
        "nodes": {"PistolLoop": "2.6 cm leather loop round the fore-stock just ahead of the lock (the lock and guard stop the pistol sliding through), sewn tabs and a patch on the band"},
        "band": {"width_m": PS_W, "thickness_m": PS_T, "route": "right shoulder -> chest_R loop -> chest_L loop -> left hip -> back (buckle) -> right shoulder (runtime ribbon; bind-space route in strap_routes_bind.json)"},
        "carry_points": ["chest_R.pistol", "chest_L.pistol"],
        "history": "One pistol hung from a thin shoulder belt (Highland soldiers of the 42nd, [W1], grade B); several pistols in holsters on one sling (Johnson 1724 on Blackbeard, [W4], grade C). Loops rather than bare hooks because the chest pistols in carry_gear.json face the band with the lock side.",
    }


def build_pistol_sling_buckle():
    # Buckle with its band ends, in the band frame (+Z along the band, +X across, +Y out).
    mb2 = MB()
    X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
    hx, hz, rr = PS_W * 0.5 + 0.005, 0.016, 0.006
    cs = [(hx - rr, hz), (-hx + rr, hz), (-hx, hz - rr), (-hx, -hz + rr), (-hx + rr, -hz), (hx - rr, -hz), (hx, -hz + rr), (hx, hz - rr)]
    fr = catmull([X * a + Z * b + Y * 0.0045 for a, b in cs], 3, closed=True)
    tube(mb2, fr, 0.0026, "LoadoutBrass", n=6, closed=True, n0=Y)
    tube(mb2, [X * hx + Y * 0.0045, -X * hx + Y * 0.0045], 0.0023, "LoadoutBrass", n=6)
    tube(mb2, [Y * 0.0048, Z * 0.010 + Y * 0.0062, Z * 0.018 + Y * 0.0052, Z * 0.020 + Y * 0.0020], 0.0013, "LoadoutBrass", n=5)
    # Fixed end folded round the centre bar (two layers toward -Z) and the running end.
    e = 0.0023 + PS_T * 0.5
    fold = [Z * (-0.050) + Y * (0.0045 + e), Z * (-0.012) + Y * (0.0045 + e), Z * (-0.002) + Y * (0.0045 + e * 0.9)]
    fold += [Y * 0.0045 + Z * (e * math.sin(a)) + Y * (e * math.cos(a)) for a in [math.pi * k / 6 for k in range(1, 6)]]
    fold += [Z * (-0.002) + Y * (0.0045 - e * 0.9), Z * (-0.012) + Y * (0.0045 - e), Z * (-0.050) + Y * (0.0045 - e)]
    band(mb2, fold, PS_W, PS_T, "LoadoutLeather", width_axis=X, bv=0.001)
    run = [Z * (-0.030) + Y * (0.0045 - e - PS_T), Z * (-0.010) + Y * (0.0045 - e - PS_T), Z * 0.012 + Y * 0.0012, Z * 0.035 + Y * 0.0008, Z * 0.100 + Y * 0.0008]
    band(mb2, run, PS_W, PS_T, "LoadoutLeather", width_axis=X, bv=0.001)
    kc = Z * (-0.034) + Y * 0.0020
    hy, hx2 = 0.0065, PS_W * 0.5 + 0.0018
    ring = catmull([kc + X * hx2 + Y * hy, kc - X * hx2 + Y * hy, kc - X * hx2 - Y * hy, kc + X * hx2 - Y * hy], 3, closed=True)
    band(mb2, ring, 0.012, 0.0022, "LoadoutLeather", width_axis=Z, closed=True, bv=0.0006)
    buckle = mb2.to_object("SlingBuckle")
    markers = {
        "BuckleBar": (V(0, 0.0045, 0), None, "origin: centre bar of the buckle"),
        "BandIn": (V(0, 0.0045, -0.050), None, "the band ribbon ends here (fixed end, folded round the bar)"),
        "BandOut": (V(0, 0.0008, 0.100), None, "the band ribbon starts again here (running end)"),
    }
    objs = [buckle] + marker_objs(markers)
    return {
        "objects": objs, "markers": markers, "hidden": [],
        "title": "Pistol sling (baldric) buckle with band ends",
        "frame": "band frame: +Z along the band, +X across its width, +Y away from the body",
        "pivot": "the buckle's centre bar",
        "axes": "+Z along the band (fixed end toward -Z, running end toward +Z), +X across, +Y out",
        "nodes": {"SlingBuckle": "brass frame buckle 6 cm with tongue; the band's fixed end folded round the centre bar, the running end with the tongue through it, a keeper"},
        "band": {"width_m": PS_W, "thickness_m": PS_T, "place": "on the back segment of the pistol sling (left hip -> right shoulder), about 40 % up; interrupt the ribbon between BandIn and BandOut"},
        "carry_points": ["pistol_sling gear (accessories.shoulder)"],
        "history": "Brass frame buckle on a buff or russet leather belt, ordinary 18th-century belt furniture (grade B).",
    }


# ---------------------------------------------------------- tomahawk frog --
def build_tomahawk_frog():
    mb = MB()
    hx, hz = HOST["haft"]
    t = 0.0034
    # Haft loop under the head: an oval leather ring 3 cm tall round the haft.
    rx, rz = hx + 0.0012 + t / 2, hz + 0.0012 + t / 2
    rz_poll = hz + 0.0105 + t / 2      # roomier on the poll (+Z) side: the thong tails pass inside
    ring_y = (0.297, 0.327)
    for y in (ring_y[0] + 0.0075, ring_y[1] - 0.0075):
        pts = []
        for k in range(20):
            a = TAU * k / 20
            s = math.sin(a)
            pts.append(V(rx * math.cos(a), y, (rz_poll if s > 0 else rz) * s))
        band(mb, pts, 0.015, t, "LoadoutLeather", width_axis=V(0, 1, 0), closed=True, bv=0.001)
    # Belt loop on the body (+X) side: a flat sleeve round a 4 cm x 5 mm belt, along Z.
    xo = rx + t / 2           # outer wall of the belt loop starts at the haft loop
    x_belt0, x_belt1 = xo + t + 0.0002, xo + t + 0.0052
    xi = x_belt1 + 0.0002
    yb0, yb1 = 0.327, 0.381
    c = 0.004
    cs = [V(xo + t / 2, yb0 + c, 0), V(xo + t / 2, yb1 - c, 0), V(xo + t / 2 + c * 0.6, yb1 - 0.0005, 0), V(xi + t / 2 - c * 0.6, yb1 - 0.0005, 0),
          V(xi + t / 2, yb1 - c, 0), V(xi + t / 2, yb0 + c, 0), V(xi + t / 2 - c * 0.6, yb0 + 0.0005, 0), V(xo + t / 2 + c * 0.6, yb0 + 0.0005, 0)]
    sleeve = catmull(cs, 2, closed=True)
    for zc in (0.0,):
        band(mb, [p + V(0, 0, zc) for p in sleeve], 0.034, t, "LoadoutLeather", width_axis=V(0, 0, 1), closed=True, bv=0.001)
    # Joint: the frog's tongue from the belt loop down over the haft loop, stitched.
    box(mb, V(xo + t * 0.5, 0.3165, 0.0), V(t * 0.5, 0, 0), V(0, 0.0125, 0), V(0, 0, 0.0115), "LoadoutLeather")
    frog = mb.to_object("TomahawkFrog")
    markers = {
        "BeltSeat": (V((x_belt0 + x_belt1) / 2, (yb0 + yb1) / 2, 0.0), None, "centre of the belt where it passes through the frog (belt along Z, width along Y, thickness along X): the carry pivot"),
        "HaftLoop": (V(0.0, sum(ring_y) / 2, 0.0), None, "centre of the haft loop (the head rests on it)"),
    }
    objs = [frog] + marker_objs(markers)
    return {
        "objects": objs, "markers": markers, "hidden": [],
        "title": "Tomahawk belt frog",
        "frame": "ThrowableModels tomahawk frame (assets/weapons/tomahawk.glb): add as a child of the tomahawk model with an identity transform",
        "pivot": "the tomahawk's origin (throwing grip); the frog sits just under the head at y 0.30-0.38",
        "axes": "tomahawk axes: +Y up the haft to the head, -Z cutting edge; the belt loop is on +X (the flat that lies against the body in carry_gear.json back.tomahawk)",
        "nodes": {"TomahawkFrog": "leather haft loop (two turns, 3 cm) under the head and a belt loop for a 4 cm x 5 mm belt on the body side, joined by a stitched tongue"},
        "dimensions": {"haft_half_widths_m": [round(hx, 4), round(hz, 4)], "belt_opening_m": [round(yb1 - yb0 - 0.004, 4), round(x_belt1 - x_belt0, 4)]},
        "carry_points": ["back.tomahawk", "back_2.tomahawk (the second frog on the same belt)"],
        "history": "Doddridge hangs the tomahawk in the belt (on the right; loadout_design.md 1.5, [P3]). A leather frog is a plausible way to hang it by the head; here it sits at the back of the belt (grade C) because the first pistol takes the right hip.",
    }


# --------------------------------------------------------------- bow cord --
def build_bow_cord():
    mb = MB()
    hx, hz = HOST["bow_handle"]
    r = 0.0013
    ax, az = hx + r + 0.0003, hz + r + 0.0003
    y0, pitch, turns = -0.074, 0.0028, 3
    helix = []
    steps = turns * 12
    for k in range(steps + 1):
        a = -math.pi / 2 + TAU * k / 12
        helix.append(V(ax * math.cos(a), y0 + pitch * k / 12, az * math.sin(a)))
    tube(mb, helix, r, "LoadoutSinew", n=6, n0=V(0, 1, 0))
    top = helix[-1]
    knot = V(0.0, y0 + pitch * turns * 0.5, -az - 0.0028)
    blob(mb, knot, V(0, 1, 0), 0.005, 0.0034, "LoadoutSinew", n=8)
    # Hanging loop toward -Z (the body side when the bow is slung string outward).
    lp = [knot + V(0.0025, 0.003, -0.002), knot + V(0.006, 0.004, -0.030), knot + V(0.004, -0.004, -0.062),
          knot + V(0.0, -0.012, -0.074), knot + V(-0.004, -0.004, -0.062), knot + V(-0.006, 0.004, -0.030), knot + V(-0.0025, 0.003, -0.002)]
    tube(mb, catmull(lp, 4), r, "LoadoutSinew", n=6, n0=V(0, 1, 0))
    tube(mb, [top, top + V(0, 0.001, -0.002), knot + V(0.001, 0.002, 0.001)], r, "LoadoutSinew", n=6)
    cord = mb.to_object("BowCord")
    markers = {
        "Handle": (V(0, 0, 0), None, "bow origin: centre of the handle"),
        "StrapLoop": (knot + V(0.0, -0.012, -0.074), None, "far end of the cord loop: the quiver strap passes through it (loadout_design.md 4: the quiver strap holds the slung bow at its handle)"),
        "Knot": (knot, None, "knot on the back of the bow"),
    }
    objs = [cord] + marker_objs(markers)
    return {
        "objects": objs, "markers": markers, "hidden": [],
        "title": "Bow sling cord",
        "frame": "WeaponModels bow frame (assets/weapons/bow.glb): add as a child of the stowed bow with an identity transform (hide it on the bow in hand)",
        "pivot": "the bow's origin (centre of the handle)",
        "axes": "bow axes: +Y upper limb, string at +Z; the cord's loop hangs to -Z (the back of the bow, toward the wearer when slung string outward)",
        "nodes": {"BowCord": "twisted sinew cord, three turns round the lower handle below the grip (y -0.074 to -0.066), knot on the back of the bow, 7 cm loop"},
        "carry_points": ["long_B.bow"],
        "history": "Game placement (grade C): the design slings the bow string outward and hangs it from the quiver strap instead of a string across the chest; a tied sinew cord is period-plausible material.",
    }


BUILDERS = {
    "quiver": build_quiver,
    "powder_horn": build_powder_horn,
    "spear_pair_tie": build_spear_pair_tie,
    "dart_bundle": build_dart_bundle,
    "musket_sling": build_musket_sling,
    "pistol_belt_hook": build_pistol_belt_hook,
    "pistol_sling_loop": build_pistol_sling,
    "pistol_sling_buckle": build_pistol_sling_buckle,
    "tomahawk_frog": build_tomahawk_frog,
    "bow_cord": build_bow_cord,
}


# ==========================================================================
# Export, GLB checks, manifest
# ==========================================================================
def export_glb(objs, path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
              export_texcoords=True, export_normals=True, export_tangents=True, export_materials="EXPORT",
              export_image_format="JPEG", export_cameras=False, export_lights=False, export_extras=False)
    try:
        bpy.ops.export_scene.gltf(export_jpeg_quality=92, **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)


def read_glb(path):
    with open(path, "rb") as fh:
        data = fh.read()
    n = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + n]), data, n


def hide_nodes(path, names):
    """Mark glTF nodes hidden with KHR_node_visibility (Godot imports visible = false)."""
    if not names:
        return
    doc, data, n = read_glb(path)
    for node in doc["nodes"]:
        if node.get("name") in names:
            node.setdefault("extensions", {})["KHR_node_visibility"] = {"visible": False}
    used = doc.setdefault("extensionsUsed", [])
    if "KHR_node_visibility" not in used:
        used.append("KHR_node_visibility")
    js = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    rest = data[20 + n:]
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + len(rest)) + struct.pack("<I", len(js)) + b"JSON" + js + rest
    with open(path, "wb") as fh:
        fh.write(out)


def glb_report(path, info):
    """Checks on the written file: nodes, markers, meshes, triangles, textures, hidden nodes."""
    doc, data, _n = read_glb(path)
    names = [nd.get("name") for nd in doc["nodes"]]
    fails = []
    for m in info["markers"]:
        if m not in names:
            fails.append("marker %s missing" % m)
    for h in info["hidden"]:
        nd = next((x for x in doc["nodes"] if x.get("name") == h), None)
        if nd is None or nd.get("extensions", {}).get("KHR_node_visibility", {}).get("visible", True):
            fails.append("%s not hidden" % h)
    tris = {}
    lo, hi = [1e9] * 3, [-1e9] * 3
    for nd in doc["nodes"]:
        if "mesh" not in nd:
            continue
        m = doc["meshes"][nd["mesh"]]
        cnt = 0
        for p in m["primitives"]:
            cnt += doc["accessors"][p["indices"]]["count"] // 3 if "indices" in p else doc["accessors"][p["attributes"]["POSITION"]]["count"] // 3
            acc = doc["accessors"][p["attributes"]["POSITION"]]
            if "translation" not in nd and "rotation" not in nd:
                for i in range(3):
                    lo[i] = min(lo[i], acc["min"][i])
                    hi[i] = max(hi[i], acc["max"][i])
        tris[nd["name"]] = cnt
    for mname, cnt in tris.items():
        if cnt <= 0:
            fails.append("%s has no triangles" % mname)
    mats = [m.get("name") for m in doc.get("materials", [])]
    imgs = [i.get("name") for i in doc.get("images", [])]
    unique_mesh_tris = sum(
        (doc["accessors"][p["indices"]]["count"] // 3) for m in doc["meshes"] for p in m["primitives"] if "indices" in p)
    rep = {"nodes": len(names), "meshes": len(doc["meshes"]), "triangles_per_node": tris,
           "triangles_unique": unique_mesh_tris, "triangles_drawn": sum(tris.values()),
           "aabb_untransformed_nodes_m": [rnd(lo), rnd(hi)] if lo[0] < 1e8 else None,
           "materials": mats, "images": imgs, "bytes": len(data), "fails": fails}
    return rep


def marker_json(markers):
    out = {}
    for k, (pos, basis, role) in markers.items():
        e = {"pos": rnd(pos), "role": role}
        if basis is not None:
            e["xform"] = godot_text(basis, pos)
        out[k] = e
    return out


def horn_reference_placement():
    """Model -> bind (skeleton space) transform that lays the horn along the carry_gear.json horn
    capsules (plug -> bend -> spout on spinec)."""
    path = os.path.join(PROJECT, "data", "loadout", "carry_gear.json")
    if not os.path.exists(path):
        return None
    d = json.load(open(path))
    caps = d["points"]["horn.powder_horn"]["capsules_bind"]
    p0, p1, p2 = V(*caps[0]["from"]), V(*caps[0]["to"]), V(*caps[1]["to"])
    dvec = (p2 - p0).normalized()
    bend = p1 - (p0 + dvec * (p1 - p0).dot(dvec))
    u = bend.normalized()
    w = dvec.cross(u)
    mb_ = V(H_SAG[0], H_SAG[1], 0).normalized()
    mw = V(0, 0, 1).cross(mb_)
    S = basis_from(x=u, y=w, z=dvec)       # columns u, w, d (u, w already orthonormal to d)
    S.col[0], S.col[1], S.col[2] = u, w, dvec
    M = Matrix.Identity(3)
    M.col[0], M.col[1], M.col[2] = mb_, mw, V(0, 0, 1)
    R = S @ M.transposed()
    return {"bone": caps[0]["bone"], "bind": godot_text(R, p0),
            "note": "model origin on the capsule's plug point, chord along plug -> spout, the curve's bulge toward the measured bend; local = spinec global rest affine_inverse() * bind",
            "spout_tip_bind": rnd(p0 + R @ (h_c(1.0) + h_t(1.0) * 0.0266)),
            "measured_spout_point": rnd(p2), "up_axis_bind": rnd(R @ V(0, 1, 0))}


# ==========================================================================
# Turnaround renders
# ==========================================================================
def setup_render(w, h):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    try:
        sc.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    world = bpy.data.worlds.get("PreviewWorld")
    if world is None:
        world = bpy.data.worlds.new("PreviewWorld")
        try:
            world.use_nodes = True
        except Exception:
            pass
        nt = world.node_tree
        bg = nt.nodes["Background"]
        out = nt.nodes["World Output"]
        sky = next((p for p in SKY if os.path.exists(p)), None)
        if sky:
            env = nt.nodes.new("ShaderNodeTexEnvironment")
            env.image = bpy.data.images.load(sky, check_existing=True)
            nt.links.new(env.outputs["Color"], bg.inputs["Color"])
            bg.inputs["Strength"].default_value = 0.8
        backdrop = nt.nodes.new("ShaderNodeBackground")
        backdrop.inputs["Color"].default_value = (0.30, 0.32, 0.34, 1.0)
        lp = nt.nodes.new("ShaderNodeLightPath")
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
        nt.links.new(bg.outputs["Background"], mix.inputs[1])
        nt.links.new(backdrop.outputs["Background"], mix.inputs[2])
        nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
        sun = bpy.data.lights.new("PreviewSun", "SUN")
        sun.energy = 3.0
        sun.angle = math.radians(4)
        so = bpy.data.objects.new("PreviewSun", sun)
        so.rotation_euler = (math.radians(48), math.radians(-18), math.radians(35))
        sc.collection.objects.link(so)
    sc.world = world
    return sc


def world_points(objs):
    pts = []
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        if o.type != "MESH" or o.hide_render:
            continue
        mw = o.matrix_world
        vs = o.data.vertices
        step = max(1, len(vs) // 1500)
        for i in range(0, len(vs), step):
            pts.append(mw @ vs[i].co)
    return pts


def shoot_view(path, objs, az, el, w, h, margin=1.12, focus=None):
    sc = setup_render(w, h)
    pts = world_points(objs)
    if focus is not None:
        c0, rad = focus
        pts = [p for p in pts if (p - c0).length < rad] or pts
    azr, elr = math.radians(az), math.radians(el)
    fwd = -Vector((math.cos(elr) * math.sin(azr), -math.cos(elr) * math.cos(azr), math.sin(elr)))
    right = fwd.cross(Vector((0, 0, 1)))
    if right.length < 1e-6:
        right = Vector((1, 0, 0))
    right.normalize()
    up = right.cross(fwd).normalized()
    xs = [p.dot(right) for p in pts]
    ys = [p.dot(up) for p in pts]
    zs = [p.dot(fwd) for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    ext = max((max(xs) - min(xs)) * h / w, max(ys) - min(ys), 0.02) * margin
    centre = right * cx + up * cy + fwd * ((min(zs) + max(zs)) / 2)
    cd = bpy.data.cameras.new("TurnCam")
    cd.type = "ORTHO"
    cd.ortho_scale = ext * (w / h if w > h else 1.0)
    cd.clip_start = 0.001
    cd.clip_end = 50.0
    cam = bpy.data.objects.new("TurnCam", cd)
    cam.location = centre - fwd * 5.0
    cam.rotation_euler = fwd.to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.cameras.remove(cd)


def compose(paths, cols, out, tile):
    rows = (len(paths) + cols - 1) // cols
    W, H = cols * tile, rows * tile
    sheet = np.full((H, W, 4), 0.18, np.float32)
    sheet[..., 3] = 1.0
    for i, p in enumerate(paths):
        img = bpy.data.images.load(p, check_existing=False)
        w, h = img.size
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        bpy.data.images.remove(img)
        px = px.reshape(h, w, 4)
        r, c = i // cols, i % cols
        y0 = H - (r + 1) * tile          # bottom-up rows
        sheet[y0 + 2:y0 + tile - 2, c * tile + 2:c * tile + tile - 2] = px[2:tile - 2, 2:tile - 2]
    im = bpy.data.images.new(os.path.basename(out), W, H, alpha=True)
    im.pixels.foreach_set(sheet.ravel())
    im.filepath_raw = out
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)
    for p in paths:
        try:
            os.remove(p)
        except OSError:
            pass
    print("SHEET", out)


def standin_band(name, centre, along, across, w, t, length, mat="LoadoutLeatherDark"):
    mb = MB()
    along = along.normalized()
    pts = [centre + along * (length * (k / 8 - 0.5)) for k in range(9)]
    band(mb, pts, w, t, mat, width_axis=across)
    return mb.to_object(name)


def place(objs, basis, pos):
    """Parent the given root-level objects to a display empty with a Godot transform."""
    root = bpy.data.objects.new("Display", None)
    bpy.context.scene.collection.objects.link(root)
    root.matrix_world = to_bmat(basis, pos)
    for o in objs:
        if o.parent is None:
            mw = o.matrix_world.copy()
            o.parent = root
            o.matrix_world = root.matrix_world @ mw
    return root


IMPORTED = []


def host_instance(rel, basis=None, pos=V(0, 0, 0), keep=None):
    got = import_glb(rel)
    objs = list(got.values())
    IMPORTED.extend(objs)
    if keep:
        for o in list(objs):
            if o.type == "MESH" and o.name not in keep:
                bpy.data.objects.remove(o, do_unlink=True)
                objs.remove(o)
    roots = [o for o in objs if o.parent is None]
    root = bpy.data.objects.new("Host_" + rel, None)
    bpy.context.scene.collection.objects.link(root)
    IMPORTED.append(root)
    root.matrix_world = to_bmat(basis, pos)
    for o in roots:
        mw = o.matrix_world.copy()
        o.parent = root
        o.matrix_world = root.matrix_world @ mw
    return [o for o in objs if o.type == "MESH"], root


def render_asset(kind, info, out_dir, tile=640):
    """Turnaround sheet for one asset (6 views) with its host weapon where it has one."""
    tmp = os.path.join(out_dir, "_tmp")
    os.makedirs(tmp, exist_ok=True)
    meshes = [o for o in info["objects"] if o.type == "MESH"]
    extra = []
    roots = []
    for o in meshes:
        o.hide_render = o.name in info["hidden"]
    focus_pts = {}
    stand = Matrix.Identity(3)
    views = [(0, 8), (90, 8), (180, 8), (270, 8), (35, 30), (215, -20)]
    focus = {}
    if kind == "quiver":
        views = [(0, 6), (90, 6), (180, 6), (270, 6), (30, 38), (200, 55)]
    elif kind == "powder_horn":
        views = [(90, 10), (270, 10), (0, 80), (40, 25), (140, 25), (230, -25)]
    elif kind == "spear_pair_tie":
        ms, _ = host_instance("spear.glb", info["markers"]["Spear_1"][1], info["markers"]["Spear_1"][0])
        ms2, _ = host_instance("spear.glb", info["markers"]["Spear_2"][1], info["markers"]["Spear_2"][0])
        extra += ms + ms2
        stand = rot_axis((1, 0, 0), 90.0)        # points (-Z) up
    elif kind == "dart_bundle":
        for i in range(5):
            m, _ = host_instance("atlatl_dart.glb", info["markers"]["Dart_%d" % (i + 1)][1], info["markers"]["Dart_%d" % (i + 1)][0])
            extra += m
        stand = rot_axis((1, 0, 0), -90.0)       # nocks (+Z) up
    elif kind == "musket_sling":
        m, _ = host_instance("musket.glb")
        extra += m
    elif kind in ("pistol_belt_hook",):
        m, _ = host_instance("pistol.glb")
        extra += m
        extra.append(standin_band("Belt", info["markers"]["Hook"][0], V(0, 1, 0), V(0, 0, 1), 0.040, 0.005, 0.16))
        views = [(270, 5), (270, 55), (90, 5), (0, 15), (300, 25), (240, -30)]
    elif kind == "pistol_sling_loop":
        m, _ = host_instance("pistol.glb")
        extra += m
        bs = info["markers"]["BandSeat"][0]
        extra.append(standin_band("Band", bs + V(0.0015, 0, 0), V(0, 0, 1), V(0, 1, 0), 0.050, 0.003, 0.34))
    elif kind == "pistol_sling_buckle":
        views = [(90, 85), (60, 40), (120, 40), (90, 5), (240, 45), (300, 45)]
        extra.append(standin_band("Band", V(0, 0.0008, 0.16), V(0, 0, 1), V(1, 0, 0), 0.050, 0.003, 0.12, "LoadoutLeather"))
        extra.append(standin_band("Belt", V(0, 0.0045, -0.10), V(0, 0, 1), V(1, 0, 0), 0.050, 0.003, 0.10, "LoadoutLeather"))
    elif kind == "tomahawk_frog":
        m, _ = host_instance("tomahawk.glb", keep=["Tomahawk"])
        extra += m
        extra.append(standin_band("Belt", info["markers"]["BeltSeat"][0], V(0, 0, 1), V(0, 1, 0), 0.040, 0.005, 0.24))
        views = [(0, 8), (90, 8), (180, 8), (270, 8), (300, 30), (120, -25)]
    elif kind == "bow_cord":
        m, _ = host_instance("bow.glb")
        extra += m
        extra.append(standin_band("QuiverStrap", info["markers"]["StrapLoop"][0] + V(0, 0.001, 0), V(1, 0, 0), V(0, 1, 0), 0.030, 0.003, 0.16))
    everything = meshes + extra
    for o in [o for o in info["objects"] if o.parent is None] + [o for o in bpy.data.objects if o.name.startswith("Host_") or o.name in ("Belt", "Band", "QuiverStrap")]:
        roots.append(o)
    disp = place(roots, stand, V(0, 0, 0))
    bpy.context.view_layer.update()
    paths = []
    shots = list(views)
    close = []
    if kind == "musket_sling":
        shots = [(90, 5), (270, 5)]
        for mk in ("SwivelRear", "SwivelFront"):
            c = disp.matrix_world @ G(info["markers"][mk][0])
            close += [(60, -35, (c, 0.12)), (200, -20, (c, 0.12))]
    elif kind in ("bow_cord",):
        shots = [(90, 5)]
        c = disp.matrix_world @ G(V(0, -0.07, -0.03))
        close = [(0, 10, (c, 0.12)), (90, 10, (c, 0.12)), (180, 10, (c, 0.12)), (270, 20, (c, 0.12)), (45, -30, (c, 0.12))]
    elif kind == "spear_pair_tie":
        shots = [(0, 5), (90, 5)]
        for z in SP_LASH:
            c = disp.matrix_world @ G(V(0, 0, z))
            close += [(30, 15, (c, 0.07)), (200, -10, (c, 0.07))]
    elif kind == "dart_bundle":
        shots = [(0, 5), (90, 5)]
        for z in (0.10, D_TIES[1]):
            c = disp.matrix_world @ G(V(0, 0, z))
            close += [(30, 15, (c, 0.16 if z < 0.2 else 0.06)), (200, -10, (c, 0.16 if z < 0.2 else 0.06))]
    for i, v in enumerate(shots):
        p = os.path.join(tmp, "%s_%02d.png" % (kind, i))
        shoot_view(p, everything, v[0], v[1], tile, tile)
        paths.append(p)
    for i, (az, el, fc) in enumerate(close):
        p = os.path.join(tmp, "%s_c%02d.png" % (kind, i))
        shoot_view(p, everything, az, el, tile, tile, focus=fc, margin=1.05)
        paths.append(p)
    compose(paths, 3, os.path.join(out_dir, "%s_turnaround.png" % kind), tile)
    # Extra sheet for hidden display parts and counts.
    extra_paths = []
    if kind == "quiver":
        arrows = [o for o in info["objects"] if o.name.startswith("Arrow_")]
        for n_show, az in ((12, 30), (3, 30), (0, 30)):
            for o in arrows:
                o.hide_render = int(o.name.split("_")[1]) > n_show
            p = os.path.join(tmp, "quiver_count_%d.png" % n_show)
            shoot_view(p, everything, az, 38, tile, tile)
            extra_paths.append(p)
        for o in arrows:
            o.hide_render = False
    if info["hidden"]:
        for o in meshes:
            o.hide_render = False
        for i, v in enumerate(((90, 8), (35, 25), (0, 8))):
            p = os.path.join(tmp, "%s_display_%d.png" % (kind, i))
            shoot_view(p, everything, v[0], v[1], tile, tile)
            extra_paths.append(p)
        for o in meshes:
            o.hide_render = o.name in info["hidden"]
    if extra_paths:
        compose(extra_paths, 3, os.path.join(out_dir, "%s_variants.png" % kind), tile)
    # Clean up the display helpers so the next asset starts from its own objects.
    for o in extra + IMPORTED:
        try:
            bpy.data.objects.remove(o, do_unlink=True)
        except ReferenceError:
            pass
    IMPORTED.clear()
    for o in list(bpy.data.objects):
        if o.parent is None and o.type == "EMPTY" and o.name.startswith("Display"):
            for ch in o.children:
                mw = ch.matrix_world.copy()
                ch.parent = None
                ch.matrix_world = mw
            bpy.data.objects.remove(o, do_unlink=True)


# ==========================================================================
def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=os.path.join(PROJECT, "assets", "loadout"))
    ap.add_argument("--renders", default=None)
    ap.add_argument("--only", default="")
    ap.add_argument("--no-export", action="store_true")
    args = ap.parse_args(argv)
    t0 = time.time()
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    kinds = [k for k in BUILDERS if not args.only or k in args.only.split(",")]
    measure_hosts()
    manifest_path = os.path.join(args.out_dir, "MANIFEST.json")
    prev = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
    manifest = prev if args.only else {}
    assets = {a["kind"]: a for a in manifest.get("assets", [])}
    fails = []
    for kind in kinds:
        print("BUILD", kind)
        info = BUILDERS[kind]()
        path = os.path.join(args.out_dir, kind + ".glb")
        rep = None
        if not args.no_export:
            export_glb(info["objects"], path)
            hide_nodes(path, info["hidden"])
            rep = glb_report(path, info)
            fails += ["%s: %s" % (kind, f) for f in rep["fails"]]
            print("  GLB %s: %d bytes, %s tris drawn, nodes %d, fails %s" % (kind, rep["bytes"], rep["triangles_drawn"], rep["nodes"], rep["fails"]))
        mats = sorted({m.name for o in info["objects"] if o.type == "MESH" for m in o.data.materials})
        entry = {
            "kind": kind, "file": "assets/loadout/%s.glb" % kind, "title": info["title"], "frame": info["frame"],
            "pivot": info["pivot"], "axes": info["axes"], "nodes": info["nodes"],
            "hidden_nodes": info["hidden"], "markers": marker_json(info["markers"]),
            "materials": mats,
            "texture_sources": {m: TEX_SOURCES.get(m, ["assets/weapons/arrow.glb (ArrowAtlas: project-generated, tools/models/arrow.py)"]) for m in mats},
            "carry_points": info.get("carry_points", []), "history": info.get("history", ""),
        }
        for key in ("counts", "dimensions", "band"):
            if key in info:
                entry[key] = info[key]
        if kind == "powder_horn":
            entry["reference_bind_placement"] = horn_reference_placement()
        if rep:
            entry["glb"] = {k: rep[k] for k in ("bytes", "meshes", "triangles_unique", "triangles_drawn", "triangles_per_node", "images", "aabb_untransformed_nodes_m")}
        if args.renders:
            render_asset(kind, info, args.renders)
            try:
                os.rmdir(os.path.join(args.renders, "_tmp"))
            except OSError:
                pass
            entry["renders"] = ["%s/%s_turnaround.png" % (os.path.relpath(args.renders, os.path.dirname(PROJECT)), kind)]
        assets[kind] = entry
        # Free this asset's objects before the next one.
        for o in info["objects"]:
            if o.name in bpy.data.objects:
                bpy.data.objects.remove(o, do_unlink=True)
    if not args.no_export:
        manifest = {
            "format": "frontier-loadout-assets", "version": 1,
            "generated": time.strftime("%Y-%m-%d"),
            "generator": "tools/loadout/build_loadout_assets.py (Blender %s, headless, --factory-startup)" % bpy.app.version_string,
            "rebuild": "/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/loadout/build_loadout_assets.py -- [--renders DIR] [--only kind,...]; then Godot --headless --import (hard time limit)",
            "licence": {
                "models": "Original procedural models generated by this project's script; no third-party geometry except the arrow mesh reused from assets/weapons/arrow.glb (also generated by this project, tools/models/arrow.py).",
                "textures": "Derived from CC0 1.0 Poly Haven maps already in assets/polyhaven (public domain dedication, no attribution required; see assets/polyhaven/MANIFEST.json for each source URL), recoloured and downsampled; horn, brass and sinew maps are procedural. Nothing was downloaded.",
                "provenance": "Model placement frames follow data/loadout/carry_gear.json, which was measured on the Actor_B rig.",
            },
            "conventions": {
                "units": "metres",
                "axes": "Godot / glTF (+Y up). Items fitted to a weapon use that weapon's model frame (WeaponModels / ThrowableModels) and are added as a child of the weapon model with an identity transform; body items have their own frame with the origin at the attach point.",
                "markers": "glTF empties at the root (identity rotation unless 'xform' is given); they import as Node3D and LoadoutModels.build() turns them into Marker3D children of the model root",
                "hidden_nodes": "exported with KHR_node_visibility visible=false (display-only parts)",
                "materials": "PBR: base colour, normal (OpenGL +Y), metallic-roughness (G roughness, B metal); tileable maps with UVs in metres / tile size; images embedded as JPEG",
            },
            "assets": [assets[k] for k in BUILDERS if k in assets],
            "strap_routes": "assets/loadout/strap_routes_bind.json (tools/loadout/render_loadout_on_body.py)",
            "integration_hooks": INTEGRATION_HOOKS,
        }
        shots = args.renders
        if not shots and prev.get("screens"):
            manifest["screens"] = prev["screens"]
        if shots and os.path.isdir(shots):
            manifest["screens"] = {"dir": os.path.relpath(shots, os.path.dirname(PROJECT)),
                                   "turnarounds": sorted(f for f in os.listdir(shots) if f.endswith("_turnaround.png") or f.endswith("_variants.png")),
                                   "on_body": sorted(f for f in os.listdir(shots) if f.startswith("onbody_")),
                                   "on_body_generator": "tools/loadout/render_loadout_on_body.py (bind pose, legacy body, all items stowed)"}
        with open(manifest_path, "w") as fh:
            json.dump(manifest, fh, indent=1)
        print("MANIFEST", manifest_path)
    print("DONE in %.1f s, %d failures%s" % (time.time() - t0, len(fails), (": " + "; ".join(fails)) if fails else ""))


INTEGRATION_HOOKS = [
    "Load through scripts/loadout/loadout_models.gd: LoadoutModels.build(kind) instances assets/loadout/<kind>.glb, turns the marker empties into Marker3D children of the root and (quiver) converts Arrow_01..24 into one MultiMeshInstance3D; set_arrow_count(model, n), slot_transforms(model, prefix), set_display(model, on), quiver_nocks_offset(model), manifest_entry(kind). Tested by tests/loadout/test_loadout_models.gd.",
    "Weapon-frame items (musket_sling, pistol_belt_hook, pistol_sling_loop, tomahawk_frog, bow_cord) are children of the STOWED weapon copy with an identity transform. spear_pair_tie and dart_bundle are placed at the long_A / long_B stow and the stowed spears / darts are its children at the Spear_n / Dart_n markers (ThrowableModels spear / atlatl_dart). Hide BowCord on the bow in hand; keep the musket sling ends on the musket in hand and show SlingTaut there.",
    "Straps: assets/loadout/strap_routes_bind.json (tools/loadout/render_loadout_on_body.py) gives every StrapRibbon its anchors in order: item markers (StrapFront/StrapRear, StrapTop/StrapBottom, ThongUpper/ThongLower, StrapBase/StrapSpout, BandSeat) and bind-space body anchors (shoulder tops, chest, sternum, ribs, under the arms, hips, back), the inner-to-outer layer order, width and the bind-pose length (musket sling 1.59 m, quiver strap 1.06 m, horn strap 0.99 m, pistol sling 1.37 m closed).",
    "Quiver height (recommend changing carry_gear.json): with the stow as stated (origin = the quiver's Mouth at y 1.567 m) the fletching spans 1.57-1.71 m and the nocks reach 1.73 m, above the hat, while the source arrow reach (actor_b-p-bow-reload--part) moves the hand from 1.20 m to 1.47 m by 0.4 s (handoff_survey.md). Placed with stow * LoadoutModels.quiver_nocks_offset(model) (the nocks at the stow origin, as the body-fit candidate generator read the capsule) the fletching spans 1.40-1.54 m, in the hand's path. Screens: onbody_musket_bow.png vs onbody_musket_bow_quiver_at_nocks.png. Re-run the survey for the lowered quiver before adopting it.",
    "Right-hip pistol hook: carry_gear.json R_hip.pistol puts the pistol's grip on the belt; the hook's belt seat (Hook marker, 8.7 cm from the grip in the pistol frame) lands at bind (-0.181, 0.929, 0.105), 5.2 cm off the baked belt. For the hook to seat, move the pistol by -Hook in its own frame (stow * Transform3D(Basis(), -Hook)) and re-run the survey for that placement, or accept the gap (it is on the body side, hidden by the pistol from the gameplay camera).",
    "Chest pistols: the chest_R and chest_L loops' band seats are at bind (0.014, 1.066, 0.148) and (0.125, 1.133, 0.146): 13 cm apart with the left one 6.7 cm HIGHER, and the two pistols lie parallel 12.6 cm apart across the band direction, so one baldric from the right shoulder to the left hip zig-zags through them (onbody_two_braces*.png). Suggested fix for the loadout design: keep chest_R on the band and move the second sling pistol down the same band toward the left side under the arm (the Highland carry [W1]), then re-measure. PistolLoop is sewn on the pistol's +X (lock) side because both placements put the lock toward the body; mirror it in x for lock-out placements.",
    "back_2.tomahawk: the stacked second tomahawk (4.5 cm out, 4 cm up) leaves its frog's belt seat 6.5 cm off the belt; hang its frog on the belt beside the first (a shift along the belt) or from the first frog. back.tomahawk's frog seat is 1.2 cm from the belt.",
    "L_hip.pistol (thrust through the belt, lock in): its Tuck point (where a belt crosses a thrust-through pistol, just ahead of the lock) is 15 cm below the belt at bind (0.212, 0.786, 0.080); a tucked pistol rests on the belt by its lock and guard, so that placement should rise about 12-15 cm (or become a hooked carry, lock out, with the belt hook). BeltHook is not shown on tucked pistols.",
    "Musket sling: the swivel opening of musket.glb is 2.5 cm, so the strap is 2.3 cm wide at the ends; use 2.3 cm for the musket sling ribbon (loadout_design.md 4 says 3.5 cm). In long_A the rear swivel sits at mid-back (StrapRear at y 1.32 m, because the stowed musket's wrist is at y 1.115 m), so the route closes from the right lower ribs under the right arm to the rear swivel, not via the right hip.",
    "Powder horn: reference_bind_placement is the model -> bind transform on spinec along the measured horn capsules; the customizer's horn_node() change (loadout_design.md 2.6) can bake this mesh there, or the loadout can place it rigidly with the 30 deg yield. The legacy body's baked horn strap still runs to the old right-hip place; the horn_strap route in strap_routes_bind.json goes plug staple -> left shoulder -> chest -> under the right arm -> spout ring.",
    "Hidden display parts (powder_horn StrapPreview, spear_pair_tie / dart_bundle ThongPreview, musket_sling SlingTaut) are for world pickups, racks and the camp chest; on the body the straps are StrapRibbon ribbons through the markers.",
]


if __name__ == "__main__":
    main()
