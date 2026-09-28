#!/usr/bin/env python3
"""Packs the impostor captures (bake_impostors.gd) into the impostor atlas.

    python3 tools/environment/vegetation/assemble_impostors.py work=<dir> [name=painted]

name=painted: the painted trees' capture (bake_impostors.gd style=painted) into painted_impostor_albedo.png and
painted_impostor_nrm.png (the rows, frames and cutout stay the realistic atlas's impostors.json: the same meshes).

Each capture is rendered at 2x: it is downsampled with premultiplied alpha (so edges keep the
right colour and the alpha becomes soft coverage), the colour / normal under transparent texels
is filled from the nearest opaque ones (no halos in the mips), and the frames are packed as
8 columns (views) x N rows (species variants):
  assets/environment/vegetation/impostors/impostor_albedo.png  RGBA (sRGB albedo with AO, coverage)
  assets/environment/vegetation/impostors/impostor_nrm.png     RGB  (view-space normal * 0.5 + 0.5)
  assets/environment/vegetation/impostors/impostors.json       rows: name, frame_w, frame_h, frame_y0
"""
import os, sys, json, math
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(FRONTIER, 'assets', 'environment', 'vegetation', 'impostors')
sys.path.insert(0, HERE)
from make_textures import dilate_rgb  # noqa: E402


def down2(rgba, size):
    """Stretch to 2x the cell size, then 2x box downsample, with premultiplied alpha."""
    a = rgba[..., 3:4]
    pre = np.concatenate([rgba[..., :3] * a, a], -1)
    if pre.shape[1] != size[0] * 2 or pre.shape[0] != size[1] * 2:
        chans = [np.asarray(Image.fromarray(pre[..., c].astype(np.float32), 'F').resize((size[0] * 2, size[1] * 2), Image.BILINEAR)) for c in range(4)]
        pre = np.stack(chans, -1)
    h, w = pre.shape[0] // 2, pre.shape[1] // 2
    pre = pre[:h * 2, :w * 2].reshape(h, 2, w, 2, 4).mean((1, 3))
    al = pre[..., 3:4]
    rgb = np.where(al > 1e-4, pre[..., :3] / np.maximum(al, 1e-4), 0.0)
    return np.concatenate([rgb, al], -1)


def main():
    work = None
    prefix = ''
    for a in sys.argv[1:]:
        if a.startswith('work='):
            work = a.split('=', 1)[1]
        elif a.startswith('name='):
            prefix = a.split('=', 1)[1] + '_'
    meta = json.load(open(os.path.join(work, 'impostor_rows.json')))
    rows = meta['rows']
    views = int(meta['frames'])
    fw, fh = meta['frame_px']
    W, H = fw * views, fh * len(rows)
    alb = np.zeros((H, W, 4), np.float32)
    nrm = np.zeros((H, W, 3), np.float32)
    for r in range(len(rows)):
        for k in range(views):
            a = np.asarray(Image.open(os.path.join(work, 'row%02d_%d_albedo.png' % (r, k))).convert('RGBA')).astype(np.float32) / 255
            n = np.asarray(Image.open(os.path.join(work, 'row%02d_%d_normal.png' % (r, k))).convert('RGBA')).astype(np.float32) / 255
            a2 = down2(a, (fw, fh))
            n2 = down2(np.concatenate([n[..., :3], a[..., 3:4]], -1), (fw, fh))
            alb[r * fh:(r + 1) * fh, k * fw:(k + 1) * fw] = a2
            nrm[r * fh:(r + 1) * fh, k * fw:(k + 1) * fw] = n2[..., :3]
    alpha = alb[..., 3]
    rgb = dilate_rgb(alb[..., :3], alpha, 0.05)
    nn = dilate_rgb(nrm, alpha, 0.05)
    v = nn * 2 - 1
    v /= np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-6)
    nn = v * 0.5 + 0.5
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(np.clip(np.dstack([rgb, alpha]) * 255 + 0.5, 0, 255).astype(np.uint8)).save(os.path.join(OUT, prefix + 'impostor_albedo.png'), optimize=True)
    Image.fromarray(np.clip(nn * 255 + 0.5, 0, 255).astype(np.uint8)).save(os.path.join(OUT, prefix + 'impostor_nrm.png'), optimize=True)
    if prefix:
        print('wrote', OUT, prefix + 'impostor_albedo.png / _nrm.png', W, 'x', H)
        return
    # One cutout polygon for every impostor (they share one MultiMesh / quad mesh): the bounding
    # octagon of the union of all frames' coverage in normalised frame space (x 0..1 right,
    # y 0..1 up from the frame bottom). It trims the empty corners around the trunk and the crown
    # top, i.e. fragments that would only be discarded.
    union = np.zeros((fh, fw), np.float32)
    for r in range(len(rows)):
        for k in range(views):
            union = np.maximum(union, alpha[r * fh:(r + 1) * fh, k * fw:(k + 1) * fw])
    ys, xs = np.nonzero(union > 0.15)
    pts = np.stack([(xs + 0.5) / fw, (fh - ys - 0.5) / fh], -1)
    cut = []
    kk = 8
    lines = []
    for i in range(kk):
        an = math.pi / kk + 2 * math.pi * i / kk
        d = np.array([math.cos(an), math.sin(an)])
        lines.append((d, float((pts @ d).max()) + 2.0 / fw))
    for i in range(kk):
        (d1, c1), (d2, c2) = lines[i], lines[(i + 1) % kk]
        v = np.linalg.solve(np.array([d1, d2]), np.array([c1, c2]))
        cut.append([round(float(np.clip(v[0], 0, 1)), 4), round(float(np.clip(v[1], 0, 1)), 4)])
    xs_ = [c[0] for c in cut]
    ys_ = [c[1] for c in cut]
    area = 0.5 * abs(sum(xs_[i] * ys_[(i + 1) % kk] - xs_[(i + 1) % kk] * ys_[i] for i in range(kk)))
    print('impostor cutout: %d-gon, %.0f %% of the frame' % (kk, area * 100))
    with open(os.path.join(OUT, 'impostors.json'), 'w') as f:
        json.dump(dict(rows=rows, frames=views, frame_px=[fw, fh], atlas=[W, H], cutout=cut), f, indent=1)
    for r in rows:
        print('%-14s frame %.2f x %.2f m, y0 %.2f' % (r['name'], r['frame_w'], r['frame_h'], r['frame_y0']))
    print('wrote', OUT, W, 'x', H)


if __name__ == '__main__':
    main()
