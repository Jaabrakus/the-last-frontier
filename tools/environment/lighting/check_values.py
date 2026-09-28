"""Look-dev value targets (spec 2.3, package A acceptance A4) measured on scenic_shots images.

Usage: python3 check_values.py <shots_dir> <prefix> [--annotate <out.png>] [--json <out.json>]

Reads <shots_dir>/<prefix><view>.png (1280x720, tools/environment/scenic_shots.gd) and reports:
  earth_sun    sunlit horizontal packed earth, mean display value of fixed 60x40 patches   0.50-0.62
  earth_shade  the same earth in wall shadow                                                 0.24-0.34
  lit_ratio    linear lit/shadow ratio of those patches                                      2.5-4
  logs_sun     sun-facing vertical logs (mean value; warmth R-B)                     0.60-0.75, R-B >= 0.12
  sky_5deg     sky 5 deg above the horizon, away from the sun (never clipped)                0.78-0.88
  forest_shade forest interior in shade (needs the real forest; skipped when no patch fits)  0.10-0.20
  clipped      pixels with any channel = 255, outside 8 deg around the sun, per view         < 0.5 %
  near_black   pixels with all channels < 8, per view                                        < 1 %
Values are display-space means of R, G, B in 0..1 ("value" = mean of the three channels).
Patches sit on geometry that the fixed layout keeps (fort floor, walls, sky), so they stay valid
when the terrain, vegetation and structure packages land. Prints one line per check and
VALUES PASSED / VALUES FAILED (n). --annotate draws the patches for review.
"""
import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

W, H = 1280, 720
# Scenic cameras (tools/environment/scenic_shots.gd VIEWS): position, target, vertical fov.
CAMERAS = {
    'spawn_gate': ((1.4, 1.7, 4.0), (0.0, 1.4, -45.0), 60.0),
    'firing_line': ((-1.2, 1.7, -18.5), (0.0, 1.2, -110.0), 55.0),
    'range_lookback': ((5.0, 1.7, -118.0), (0.0, 2.8, -16.0), 50.0),
    'walkway': ((9.0, 5.0, -12.6), (-12.0, 1.0, -75.0), 65.0),
    'forest': ((-58.0, 1.7, -62.0), (-22.0, 4.0, -18.0), 65.0),
    'parade': ((7.0, 1.7, 11.0), (-8.0, 2.4, 3.0), 65.0),
    'aerial': ((48.0, 30.0, 48.0), (0.0, 0.0, -22.0), 55.0),
}
SUN_AZ, SUN_EL = 222.5, 19.1

# (view, x, y, w, h) in 1280x720 pixels.
PATCHES = {
    'earth_sun': [('spawn_gate', 1040, 560, 60, 40), ('parade', 1060, 560, 60, 40)],
    'earth_shade': [('spawn_gate', 300, 600, 60, 40), ('spawn_gate', 560, 640, 60, 40)],
    'logs_sun': [('spawn_gate', 760, 292, 60, 36), ('spawn_gate', 400, 292, 60, 36)],
    'sky_5deg': [('firing_line', 560, 262, 60, 30), ('spawn_gate', 300, 200, 60, 30)],
    'forest_shade': [],
}
TARGETS = {
    'earth_sun': (0.50, 0.62),
    'earth_shade': (0.24, 0.34),
    'logs_sun': (0.60, 0.75),
    'sky_5deg': (0.78, 0.88),
    'forest_shade': (0.10, 0.20),
    'lit_ratio': (2.5, 4.0),
}


def srgb_to_linear(x):
    return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)


def load(d, prefix, view):
    return np.asarray(Image.open('%s/%s%s.png' % (d, prefix, view)).convert('RGB')).astype(np.float64) / 255.0


def sun_pixel(view):
    """Projected sun position (x, y) and pixels per degree, or None when behind the camera."""
    if view not in CAMERAS:
        return None
    p, t, fov = CAMERAS[view]
    f = np.subtract(t, p)
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    az, el = math.radians(SUN_AZ), math.radians(SUN_EL)
    s = np.array([math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el)])
    z = s @ f
    if z <= 0:
        return None
    th = math.tan(math.radians(fov) / 2)
    x = W / 2 + (s @ r) / z / th * (H / 2)
    y = H / 2 - (s @ u) / z / th * (H / 2)
    return x, y, (H / 2) / th / 57.2958


def main():
    d, prefix = sys.argv[1], sys.argv[2]
    annotate = sys.argv[sys.argv.index('--annotate') + 1] if '--annotate' in sys.argv else None
    out_json = sys.argv[sys.argv.index('--json') + 1] if '--json' in sys.argv else None
    cache = {}
    res = {}
    fails = []

    def img(v):
        if v not in cache:
            cache[v] = load(d, prefix, v)
        return cache[v]

    for key, patches in PATCHES.items():
        if not patches:
            print('skip %-12s no patch on this content (needs the forest from package C)' % key)
            continue
        vals, lins, warm = [], [], []
        for v, x, y, w, h in patches:
            a = img(v)[y:y + h, x:x + w]
            vals.append(a.mean())
            lins.append(srgb_to_linear(a).mean())
            warm.append(a[..., 0].mean() - a[..., 2].mean())
        res[key] = {'value': float(np.mean(vals)), 'linear': float(np.mean(lins)),
                    'r_minus_b': float(np.mean(warm)), 'per_patch': [round(float(x), 3) for x in vals]}
        lo, hi = TARGETS[key]
        ok = lo <= res[key]['value'] <= hi
        extra = ''
        if key == 'logs_sun':
            ok = ok and res[key]['r_minus_b'] >= 0.12
            extra = ' R-B %.3f (>= 0.12)' % res[key]['r_minus_b']
        print('%s %-12s %.3f (target %.2f-%.2f) patches %s%s' % ('ok  ' if ok else 'FAIL', key, res[key]['value'], lo, hi,
                                                               res[key]['per_patch'], extra))
        if not ok:
            fails.append(key)
    if 'earth_sun' in res and 'earth_shade' in res:
        ratio = res['earth_sun']['linear'] / max(res['earth_shade']['linear'], 1e-6)
        lo, hi = TARGETS['lit_ratio']
        ok = lo <= ratio <= hi
        res['lit_ratio'] = ratio
        print('%s %-12s %.2f (target %.1f-%.1f, linear display values)' % ('ok  ' if ok else 'FAIL', 'lit_ratio', ratio, lo, hi))
        if not ok:
            fails.append('lit_ratio')
    if 'sky_5deg' in res:
        clipped = 0
        for v, x, y, w, h in PATCHES['sky_5deg']:
            clipped += int((img(v)[y:y + h, x:x + w] >= 1.0).any(-1).sum())
        if clipped:
            fails.append('sky_clipped')
        print('%s %-12s %d clipped pixels in the sky patches' % ('ok  ' if not clipped else 'FAIL', 'sky_clip', clipped))

    import os
    views = sorted(f[len(prefix):-4] for f in os.listdir(d) if f.startswith(prefix) and f.endswith('.png') and not f.endswith('sheet.png'))
    res['views'] = {}
    for v in views:
        a = img(v)
        mask = np.ones(a.shape[:2], bool)
        sp = sun_pixel(v)
        if sp:
            yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
            mask &= np.hypot(xx - sp[0], yy - sp[1]) > 8.0 * sp[2]
        clipped = float(((a >= 1.0).any(-1) & mask).sum() / max(mask.sum(), 1))
        black = float((a < 8 / 255).all(-1).mean())
        res['views'][v] = {'clipped': clipped, 'near_black': black, 'mean': float(a.mean())}
        ok = clipped < 0.005 and black < 0.01
        print('%s view %-15s clipped %.2f %% (< 0.5 %%, sun excluded: %s)  near-black %.2f %% (< 1 %%)  mean %.3f' % (
            'ok  ' if ok else 'FAIL', v, clipped * 100, 'yes' if sp else 'n/a', black * 100, a.mean()))
        if not ok:
            fails.append('view_' + v)

    if annotate:
        imgs = []
        for v in ['spawn_gate', 'parade', 'firing_line']:
            im = Image.open('%s/%s%s.png' % (d, prefix, v)).convert('RGB')
            dr = ImageDraw.Draw(im)
            for key, patches in PATCHES.items():
                for pv, x, y, w, h in patches:
                    if pv == v:
                        dr.rectangle([x, y, x + w, y + h], outline=(255, 0, 255), width=2)
                        dr.text((x, y - 12), key, fill=(255, 0, 255))
            imgs.append(im)
        sheet = Image.new('RGB', (W * len(imgs), H))
        for i, im in enumerate(imgs):
            sheet.paste(im, (i * W, 0))
        sheet.save(annotate)
    if out_json:
        json.dump(res, open(out_json, 'w'), indent=2)
    print('VALUES PASSED' if not fails else 'VALUES FAILED (%d): %s' % (len(fails), ', '.join(fails)))


if __name__ == '__main__':
    main()
