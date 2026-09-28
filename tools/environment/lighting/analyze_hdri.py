"""Sun direction, colour and sky statistics of an equirectangular Radiance .hdr (look-dev spec 3.1).

Usage: python3 analyze_hdri.py <file.hdr>. Writes nothing; prints the sun pixel, elevation, Godot
panorama azimuth (0 = -Z, 90 = +X), colour, irradiance ratios and sky means by elevation.
"""
import numpy as np, sys, math
def read_hdr(path):
    f = open(path, 'rb'); data = f.read(); f.close()
    i = data.index(b'\n\n') + 2
    j = data.index(b'\n', i)
    dims = data[i:j].decode().split()
    h, w = int(dims[1]), int(dims[3])
    p = j + 1
    img = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        assert data[p] == 2 and data[p+1] == 2
        p += 4
        for c in range(4):
            x = 0
            row = img[y, :, c]
            while x < w:
                n = data[p]; p += 1
                if n > 128:
                    n -= 128
                    row[x:x+n] = data[p]; p += 1
                else:
                    row[x:x+n] = np.frombuffer(data[p:p+n], np.uint8); p += n
                x += n
    e = img[..., 3].astype(np.int32)
    scale = np.where(e > 0, np.ldexp(1.0, e - 136), 0.0)
    rgb = img[..., :3].astype(np.float64) * scale[..., None]
    return rgb
rgb = read_hdr(sys.argv[1])

h, w, _ = rgb.shape
lum = 0.2126*rgb[...,0] + 0.7152*rgb[...,1] + 0.0722*rgb[...,2]
y, x = np.unravel_index(np.argmax(lum), lum.shape)
print('size', w, h, 'max lum', lum.max(), 'at', x, y)
u = (x + 0.5) / w; v = (y + 0.5) / h
el = 90 - v * 180
phi = u * 360
print('u %.4f v %.4f -> elevation %.2f deg, godot phi %.1f deg (0=-Z, 90=+X)' % (u, v, el, phi))
# Solid angle weights
thetas = (np.arange(h) + 0.5) / h * math.pi
dw = (2*math.pi/w) * (math.pi/h) * np.sin(thetas)[:, None]
# Sun region: pixels above threshold
thr = lum.max() * 0.02
mask = lum > max(thr, 50)
print('sun pixels', mask.sum(), 'thr', thr)
sun_E = (rgb * (dw * mask)[..., None]).sum((0,1))
# direction-weighted irradiance on a surface facing the sun (approx = integral of radiance * dw)
print('sun integral radiance*sr (rgb)', sun_E, 'color norm', sun_E / sun_E.max())
# sun angular size
print('sun solid angle sr', (dw*mask).sum())
# Sky irradiance on horizontal plane (upper hemisphere, excluding sun)
cos = np.cos(thetas)[:, None]
up = (cos > 0)
sky = rgb * (~mask)[..., None]
E_sky_h = (sky * (dw * np.clip(cos, 0, None))[..., None]).sum((0,1))
E_sun_h = sun_E * math.sin(math.radians(el))
print('horizontal irradiance: sky', E_sky_h, 'sun', E_sun_h, 'ratio sun/sky (lum)', (0.2126*E_sun_h[0]+0.7152*E_sun_h[1]+0.0722*E_sun_h[2])/(0.2126*E_sky_h[0]+0.7152*E_sky_h[1]+0.0722*E_sky_h[2]))
# average sky colors by elevation band
for lo, hi in [(80, 90), (45, 60), (20, 30), (5, 10), (0, 3), (-10, 0), (-90, -30)]:
    rows = [r for r in range(h) if lo <= 90 - (r + 0.5) / h * 180 < hi]
    c = (rgb[rows] * (~mask[rows])[..., None]).mean((0, 1))
    print('elev %3d..%3d mean rgb %s' % (lo, hi, np.round(c, 3)))
# azimuth variation near horizon at 5-10 deg elevation
rows = [r for r in range(h) if 5 <= 90 - (r + 0.5) / h * 180 < 10]
band = rgb[rows].mean(0)
for k in range(0, 360, 30):
    cols = slice(int(k/360*w), int((k+30)/360*w))
    print('phi %3d..%3d rgb %s' % (k, k+30, np.round(band[cols].mean(0), 3)))
