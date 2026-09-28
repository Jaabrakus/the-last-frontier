#!/usr/bin/env python3
"""Packs the rendered spray tiles (build_atlas.py) into the foliage card atlas.

    python3 tools/environment/vegetation/assemble_atlas.py work=<dir with *_albedo/_normal.png>

Output (assets/environment/vegetation/foliage/):
  foliage_albedo.png   2048 x 3072 RGBA (sRGB colour, alpha = coverage), 4 x 6 tiles of 512 px
  foliage_normal.png   2048 x 3072 RGB, OpenGL tangent-space normals
  foliage_tiles.json   per tile: index, size (m), kind, uv rect (x, y, w, h; top-left origin)

Tiles 0-15 are the single sprays. Tiles 16-23 are "clumps" for the far LODs: 4-5 sprays of one
species fanned around the card base, so a large card stays dense when it is only ~20 px on screen.
Under every transparent texel the colour and normal are filled with the nearest opaque texel's
(push-pull), so mipmaps and bilinear filtering never pull in black or the flat background.
"""
import os, sys, json, math, random
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(FRONTIER, 'assets', 'environment', 'vegetation', 'foliage')
sys.path.insert(0, HERE)
from make_textures import dilate_rgb  # noqa: E402

TILE = 512
COLS, ROWS = 4, 6

# name: (index, size m, kind) for the rendered tiles (must match build_atlas.TILES)
BASE = {
    'pine_a': (0, 1.10, 'pine'), 'pine_b': (1, 1.10, 'pine'),
    'hemlock_a': (2, 0.80, 'hemlock'), 'hemlock_b': (3, 0.80, 'hemlock'),
    'oak_a': (4, 0.95, 'oak'), 'oak_b': (5, 0.95, 'oak'),
    'maple_a': (6, 0.90, 'maple'), 'maple_b': (7, 0.90, 'maple'),
    'birch_a': (8, 0.70, 'birch'), 'birch_b': (9, 0.70, 'birch'),
    'hazel_a': (10, 0.75, 'hazel'), 'hazel_b': (11, 0.75, 'hazel'),
    'maple_red': (12, 0.90, 'maple_red'), 'deadtwig': (13, 1.00, 'dead'),
    'fir_side': (14, 1.40, 'fir_side'), 'shrub04': (15, 0.62, 'shrub04'),
}
# clump name: (index, sources, clump size factor vs the spray, sprays, seed)
CLUMPS = {
    # Dense: the far-LOD cards are few and large, so every discarded texel is wasted fill (the
    # expensive part of alpha-tested foliage on Apple GPUs); ~0.4-0.5 coverage lets LOD1 / LOD2 use
    # about half the card area of LOD0 for the same crown opacity.
    'pine_clump': (16, ['pine_a', 'pine_b'], 1.45, 9, 1),
    'hemlock_clump': (17, ['hemlock_a', 'hemlock_b'], 1.45, 10, 2),
    'oak_clump': (18, ['oak_a', 'oak_b'], 1.4, 7, 3),
    'maple_clump': (19, ['maple_a', 'maple_b'], 1.4, 7, 4),
    'birch_clump': (20, ['birch_a', 'birch_b'], 1.4, 7, 5),
    'hazel_clump': (21, ['hazel_a', 'hazel_b'], 1.4, 7, 6),
    'maple_red_clump': (22, ['maple_red', 'maple_a'], 1.4, 7, 7),
    'hemlock_clump_b': (23, ['hemlock_b', 'hemlock_a'], 1.45, 9, 8),
}


def load_rgba(path):
    return np.asarray(Image.open(path).convert('RGBA')).astype(np.float32) / 255.0


def _xform_channel(ch, size, pad, angle_deg, pivot):
    """Scale a float channel to `size`, paste it into the tile at `pad`, rotate it about `pivot`."""
    im = Image.fromarray(ch.astype(np.float32), 'F').resize((size, size), Image.BILINEAR)
    canvas = Image.new('F', (TILE, TILE), 0.0)
    canvas.paste(im, pad)
    canvas = canvas.rotate(angle_deg, resample=Image.BILINEAR, center=pivot)
    return np.asarray(canvas)


def place(acc, src_a, src_n, scale, angle_deg, shift):
    """Composite a spray into a clump tile with premultiplied alpha ("over"): acc holds
    premultiplied albedo rgb, alpha and premultiplied normal xyz (7 channels). The spray is scaled
    about the tile's bottom centre, rotated CCW by angle_deg and shifted (px); its normals' xy are
    rotated with it. (Straight-alpha compositing onto an empty tile darkens every edge texel and
    tilts the normals there, which made the far-LOD cards read 10-17 % darker.)"""
    h, w = src_a.shape[:2]
    size = max(1, int(round(w * scale)))
    ox = (w - size) // 2 + int(shift[0])
    oy = h - size + int(shift[1])
    pivot = (w / 2 + shift[0], h - 1 + shift[1])
    a = src_a[..., 3]
    v = src_n[..., :3] * 2 - 1
    chans = [src_a[..., 0] * a, src_a[..., 1] * a, src_a[..., 2] * a, a, v[..., 0] * a, v[..., 1] * a, v[..., 2] * a]
    t = [_xform_channel(c, size, (ox, oy), angle_deg, pivot) for c in chans]
    th = math.radians(angle_deg)
    nx = t[4] * math.cos(th) - t[5] * math.sin(th)
    ny = t[4] * math.sin(th) + t[5] * math.cos(th)
    src = np.stack([t[0], t[1], t[2], t[3], nx, ny, t[6]], -1)
    sa = np.clip(src[..., 3:4], 0, 1)
    acc[:] = src + acc * (1 - sa)


def cutout(alpha, k=6, threshold=0.2):
    """Card cutout: the bounding k-gon (k half-planes at equal angles, pushed out to the last
    texel with alpha > threshold plus 2 texels) of a tile, as [u, v] in 0..1 with u to the right
    and v up from the tile's bottom edge, counter-clockwise. Trees use it instead of the full
    quad: on this tile set it covers 40-60 % of the square, so about half the alpha-tested
    fragments (the expensive part of foliage on Apple GPUs) are never rasterised."""
    n = alpha.shape[0]
    ys, xs = np.nonzero(alpha > threshold)
    if len(xs) == 0:
        return [[0, 0], [1, 0], [1, 1], [0, 1]]
    pts = np.stack([(xs + 0.5) / n, (n - ys - 0.5) / n], -1)
    lines = []
    for i in range(k):
        an = math.pi / k + 2 * math.pi * i / k
        d = np.array([math.cos(an), math.sin(an)])
        lines.append((d, float((pts @ d).max()) + 2.0 / n))
    verts = []
    for i in range(k):
        (d1, c1), (d2, c2) = lines[i], lines[(i + 1) % k]
        v = np.linalg.solve(np.array([d1, d2]), np.array([c1, c2]))
        verts.append([round(float(np.clip(v[0], 0, 1)), 4), round(float(np.clip(v[1], 0, 1)), 4)])
    return verts


def main():
    work = '/tmp/frontier_veg_atlas'
    for a in sys.argv[1:]:
        if a.startswith('work='):
            work = a.split('=', 1)[1]
    W, H = TILE * COLS, TILE * ROWS
    atlas_a = np.zeros((H, W, 4), np.float32)
    atlas_n = np.zeros((H, W, 3), np.float32)
    meta = {}
    tiles = {}
    for name, (idx, size, kind) in BASE.items():
        a = load_rgba(os.path.join(work, name + '_albedo.png'))
        n = load_rgba(os.path.join(work, name + '_normal.png'))
        tiles[name] = (a, n)
        r, c = divmod(idx, COLS)
        atlas_a[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE] = a
        atlas_n[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE] = n[..., :3]
        meta[name] = dict(index=idx, size=size, kind=kind)
    for name, (idx, srcs, factor, count, seed) in CLUMPS.items():
        rng = random.Random(seed)
        acc = np.zeros((TILE, TILE, 7), np.float32)
        # Back sprays first (wide angles, small), then the upright centre ones on top.
        angles = sorted([(-38 + 76 * (k + rng.uniform(0.2, 0.8)) / count) for k in range(count)], key=lambda x: -abs(x))
        for k, ang in enumerate(angles):
            src = srcs[k % len(srcs)]
            a, n = tiles[src]
            s_ = (1.0 / factor) * rng.uniform(1.0, 1.15) * (0.92 if abs(ang) > 15 else 1.0)
            shift = (rng.uniform(-0.04, 0.04) * TILE - math.sin(math.radians(ang)) * 0.05 * TILE, -rng.uniform(0.0, 0.06) * TILE)
            place(acc, a, n, s_, ang, shift)
        al = np.clip(acc[..., 3], 0, 1)
        inv = 1.0 / np.maximum(al, 1e-4)
        ca = np.zeros((TILE, TILE, 4), np.float32)
        ca[..., :3] = np.clip(acc[..., :3] * inv[..., None], 0, 1)
        ca[..., 3] = al
        nv = acc[..., 4:7] * inv[..., None]
        nv[al < 1e-4] = (0, 0, 1)
        nv /= np.maximum(np.linalg.norm(nv, axis=-1, keepdims=True), 1e-6)
        cn = nv * 0.5 + 0.5
        r, c = divmod(idx, COLS)
        atlas_a[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE] = ca
        atlas_n[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE] = cn
        base_size = BASE[srcs[0]][1]
        meta[name] = dict(index=idx, size=round(base_size * factor, 3), kind=BASE[srcs[0]][2] + '_clump')
    for name, m in meta.items():
        r, c = divmod(m['index'], COLS)
        m['uv'] = [c * TILE / W, r * TILE / H, TILE / W, TILE / H]
        m['hull'] = cutout(atlas_a[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE, 3])
        # Coverage stats: fraction of the tile that survives a 0.5 alpha test.
        t = atlas_a[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE, 3]
        m['coverage'] = round(float((t >= 0.5).mean()), 3)
    alpha = atlas_a[..., 3]
    rgb = dilate_rgb(atlas_a[..., :3], alpha, 0.02)
    nrm = dilate_rgb(atlas_n, alpha, 0.02)
    # Renormalise the filled normals.
    v = nrm * 2 - 1
    v /= np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-6)
    nrm = v * 0.5 + 0.5
    os.makedirs(OUT, exist_ok=True)
    out_a = np.dstack([rgb, alpha])
    Image.fromarray(np.clip(out_a * 255 + 0.5, 0, 255).astype(np.uint8)).save(os.path.join(OUT, 'foliage_albedo.png'), optimize=True)
    Image.fromarray(np.clip(nrm * 255 + 0.5, 0, 255).astype(np.uint8)).save(os.path.join(OUT, 'foliage_normal.png'), optimize=True)
    with open(os.path.join(OUT, 'foliage_tiles.json'), 'w') as f:
        json.dump(dict(atlas=[W, H], tile=TILE, tiles=meta), f, indent=1, sort_keys=True)
    for name, m in sorted(meta.items(), key=lambda kv: kv[1]['index']):
        print('%-16s idx=%2d size=%.2f coverage(a>=0.5)=%.3f' % (name, m['index'], m['size'], m['coverage']))
    print('wrote', OUT)


if __name__ == '__main__':
    main()
