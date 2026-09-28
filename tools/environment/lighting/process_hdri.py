"""Sky panorama for the Frontier sky shader (look-dev spec 3.2, package A).

Reads the Poly Haven HDRI (read-only source), removes the sun disc and its lens starburst, replaces
the mirrored lower hemisphere with the horizon colour, and writes:

  assets/environment/sky/qwantani_late_afternoon_nosun_2k.exr   half float, uncompressed, 2048x1024
  assets/environment/sky/sun.json                                sun direction / colour / energy
  <scratch>/nosun_preview.png (optional 3rd arg)                 tone-mapped preview for review

Why: the DirectionalLight must be the only direct sun. Left in the panorama, the 1.4e5-radiance sun
(and its mirror image at -19 deg in the lower hemisphere) would add a second sun to the ambient
light and to every reflection. The sky shader (shaders/sky/frontier_sky.gdshader) draws an analytic
disc on top that follows the light.

Sun removal. (1) The photograph's 8 diffraction spikes (thin radial streaks out to ~8 deg) are
clamped ring by ring to 1.03x the running median over +-20 deg of position angle, which keeps the
broad horizon-side gradient. (2) The measured radial profile around the sun falls as a power law
(about theta^-1.4) from 1.4 to 4 deg: the aureole. Inside 1.2 deg every pixel is replaced by that
power law fitted per channel and evaluated at max(theta, 1.2 deg), cross-faded into the sky over
1.2-1.6 deg, so the aureole continues smoothly into a plateau where the disc was (instead of a flat
ring median, which would leave a dark hole around the disc).

Usage: python3 process_hdri.py <source.hdr> <out_dir> [preview.png]
Deterministic: re-running gives identical files.
"""
import json
import math
import struct
import sys

import numpy as np


def read_hdr(path):
    """Radiance RGBE (new-style RLE) -> float64 HxWx3 linear."""
    data = open(path, 'rb').read()
    i = data.index(b'\n\n') + 2
    j = data.index(b'\n', i)
    dims = data[i:j].decode().split()
    h, w = int(dims[1]), int(dims[3])
    p = j + 1
    img = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        assert data[p] == 2 and data[p + 1] == 2
        p += 4
        for c in range(4):
            x = 0
            row = img[y, :, c]
            while x < w:
                n = data[p]
                p += 1
                if n > 128:
                    n -= 128
                    row[x:x + n] = data[p]
                    p += 1
                else:
                    row[x:x + n] = np.frombuffer(data[p:p + n], np.uint8)
                    p += n
                x += n
    e = img[..., 3].astype(np.int32)
    scale = np.where(e > 0, np.ldexp(1.0, e - 136), 0.0)
    return img[..., :3].astype(np.float64) * scale[..., None]


LUMA = np.array([0.2126, 0.7152, 0.0722])


def luma(x):
    # Explicit weighted sum: numpy's matmul on macOS Accelerate emits spurious FP warnings.
    return x[..., 0] * LUMA[0] + x[..., 1] * LUMA[1] + x[..., 2] * LUMA[2]


def write_exr_half(path, rgb):
    """Minimal scanline OpenEXR writer: RGB half float, NO_COMPRESSION, increasing Y."""
    h, w, _ = rgb.shape
    half = rgb.astype(np.float16)

    def attr(name, typ, payload):
        return name.encode() + b'\0' + typ.encode() + b'\0' + struct.pack('<i', len(payload)) + payload

    chl = b''
    for c in ('B', 'G', 'R'):                        # Channel list must be sorted by name.
        chl += c.encode() + b'\0' + struct.pack('<iB3xii', 1, 0, 1, 1)   # HALF, pLinear 0, sampling 1 1
    chl += b'\0'
    header = b''.join([
        attr('channels', 'chlist', chl),
        attr('compression', 'compression', b'\0'),
        attr('dataWindow', 'box2i', struct.pack('<iiii', 0, 0, w - 1, h - 1)),
        attr('displayWindow', 'box2i', struct.pack('<iiii', 0, 0, w - 1, h - 1)),
        attr('lineOrder', 'lineOrder', b'\0'),
        attr('pixelAspectRatio', 'float', struct.pack('<f', 1.0)),
        attr('screenWindowCenter', 'v2f', struct.pack('<ff', 0.0, 0.0)),
        attr('screenWindowWidth', 'float', struct.pack('<f', 1.0)),
    ]) + b'\0'
    prefix = struct.pack('<ii', 20000630, 2) + header
    line_bytes = w * 2 * 3
    table_start = len(prefix)
    first = table_start + 8 * h
    offsets = [first + y * (8 + line_bytes) for y in range(h)]
    out = bytearray(prefix)
    out += struct.pack('<%dQ' % h, *offsets)
    for y in range(h):
        out += struct.pack('<ii', y, line_bytes)
        for c in (2, 1, 0):                          # B, G, R planes.
            out += half[y, :, c].tobytes()
    open(path, 'wb').write(bytes(out))


def main():
    src, out_dir = sys.argv[1], sys.argv[2]
    preview = sys.argv[3] if len(sys.argv) > 3 else None
    rgb = read_hdr(src)
    h, w, _ = rgb.shape
    lum = luma(rgb)

    # Direction of every pixel (Godot panorama convention: u = atan2(x, -z) / 2pi, v = acos(y) / pi).
    u = (np.arange(w) + 0.5) / w * 2.0 * math.pi
    v = (np.arange(h) + 0.5) / h * math.pi
    U, V = np.meshgrid(u, v)
    dirs = np.stack([np.sin(U) * np.sin(V), np.cos(V), -np.cos(U) * np.sin(V)], -1)
    d_omega = (2.0 * math.pi / w) * (math.pi / h) * np.sin(V)

    # Sun: energy-weighted centroid of the core (pixels above 2 % of the peak).
    core = lum > lum.max() * 0.02
    wsum = (lum * core)[..., None]
    sun_dir = (dirs * wsum).sum((0, 1))
    sun_dir /= np.linalg.norm(sun_dir)
    elev = math.degrees(math.asin(sun_dir[1]))
    az = math.degrees(math.atan2(sun_dir[0], -sun_dir[2])) % 360.0
    ang = np.degrees(np.arccos(np.clip((dirs * sun_dir).sum(-1), -1.0, 1.0)))

    # 1. Starburst spikes: the photograph's diffraction spikes are thin radial streaks out to about 8 deg.
    #    Around the sun, in rings of 0.1 deg, every pixel is compared with the running median over
    #    +-20 deg of position angle in its ring (which keeps the broad horizon-side gradient) and
    #    clamped to 1.03x that median.
    out = rgb.copy()
    e1 = np.cross([0.0, 1.0, 0.0], sun_dir)
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(sun_dir, e1)
    psi = np.degrees(np.arctan2((dirs * e2).sum(-1), (dirs * e1).sum(-1)))
    spikes = np.zeros(lum.shape, bool)
    for r0 in np.arange(1.0, 10.0, 0.1):
        ys, xs = np.nonzero((ang >= r0) & (ang < r0 + 0.1))
        if ys.size < 8:
            continue
        order = np.argsort(psi[ys, xs])
        ys, xs = ys[order], xs[order]
        p_sorted = psi[ys, xs]
        l_sorted = lum[ys, xs]
        med = np.empty_like(l_sorted)
        for k in range(ys.size):                     # Circular window of +-20 deg.
            dpsi = np.abs((p_sorted - p_sorted[k] + 180.0) % 360.0 - 180.0)
            med[k] = np.median(l_sorted[dpsi <= 20.0])
        fade = 1.03 + 0.5 * max(0.0, (r0 - 8.0) / 2.0)   # No clamping past 10 deg.
        hot = l_sorted > fade * med
        scale = np.where(hot, fade * med / np.maximum(l_sorted, 1e-9), 1.0)
        out[ys, xs] *= scale[:, None]
        spikes[ys[hot], xs[hot]] = True
    lum_c = luma(out)

    # 2. Disc: power-law aureole per channel, fitted on the cleaned 1.4-4 deg ring in log-log space,
    #    evaluated at max(theta, 1.2 deg) inside the disc and cross-faded into the cleaned sky over
    #    1.2-1.6 deg.
    ring = (ang >= 1.4) & (ang < 4.0) & (V < math.pi / 2)
    fit = []
    for c in range(3):
        a = np.log(ang[ring])
        b = np.log(np.maximum(out[..., c][ring], 1e-6))
        slope, icpt = np.polyfit(a, b, 1)
        fit.append((slope, icpt))
    theta = np.maximum(ang, 1.2)
    profile = np.stack([np.exp(fit[c][1]) * theta ** fit[c][0] for c in range(3)], -1)
    t = np.clip((ang - 1.2) / 0.4, 0.0, 1.0)
    t = t * t * (3.0 - 2.0 * t)
    near = ang < 1.6
    disc = ang < 1.2
    out[near] = profile[near] * (1.0 - t[near, None]) + out[near] * t[near, None]
    removed = ((rgb - out) * d_omega[..., None])
    removed_up = removed[: h // 2].sum((0, 1))       # The sun itself (upper hemisphere).

    # Lower hemisphere: the source mirrors the sky (including a second sun at -19 deg). Replace every
    # row below the horizon with the lowest sky row; the shader blends it into the ground bounce.
    horizon_row = h // 2 - 1
    out[h // 2:] = out[horizon_row][None, :, :]

    # The painted-out result must hold no second sun anywhere.
    out_lum = luma(out)
    assert out_lum.max() < 40.0, out_lum.max()

    import os
    os.makedirs(out_dir, exist_ok=True)
    exr = os.path.join(out_dir, 'qwantani_late_afternoon_nosun_2k.exr')
    write_exr_half(exr, out.astype(np.float32))

    sun_e = removed_up                                 # Normal irradiance of the removed sun (RGB).
    sun_lum = float(luma(sun_e))
    chroma = sun_e / sun_e.max()
    chroma_lum = float(luma(chroma))

    def to_srgb(x):
        return 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055

    # Sky irradiance on a horizontal plane (the processed upper hemisphere).
    cosv = np.clip(np.cos(V), 0.0, None)
    sky_e = (out[: h // 2] * (d_omega * cosv)[: h // 2, :, None]).sum((0, 1))
    sky_lum = float(luma(sky_e))
    info = {
        'source': 'assets/polyhaven/hdri/qwantani_late_afternoon_puresky_2k.hdr',
        'output': 'assets/environment/sky/qwantani_late_afternoon_nosun_2k.exr',
        'size': [w, h],
        'sun_native_azimuth_deg': round(az, 3),
        'sun_elevation_deg': round(elev, 3),
        'sun_native_direction': [round(float(x), 5) for x in sun_dir],
        'panorama_convention': 'u = atan2(x, -z) / 2pi (0 = north = -Z, 0.25 = east = +X), v = acos(y) / pi',
        'removed_sun_normal_irradiance_rgb': [round(float(x), 4) for x in sun_e],
        'removed_sun_normal_irradiance_lum': round(sun_lum, 4),
        'removed_solid_angle_sr': float((d_omega * (disc | spikes))[: h // 2].sum()),
        'spike_pixels_clamped': int(spikes[: h // 2].sum()),
        'disc_radius_deg': 1.2,
        'aureole_fit_rgb_slope_intercept': [[round(float(s), 4), round(float(i), 4)] for s, i in fit],
        'sun_color_linear': [round(float(x), 4) for x in chroma],
        'sun_color_srgb': [round(to_srgb(float(x)), 4) for x in chroma],
        # Godot shades a Lambert surface facing a DirectionalLight as albedo * energy * colour
        # (measured: albedo 0.5 under energy 1 renders 0.503 linear), and sky ambient as
        # albedo * E_sky / pi (a uniform sky of radiance L gives albedo * L). So the light that matches
        # the sky at ambient/background energy 1 has energy * lum(colour) = E_sun / pi.
        'godot_light_energy_for_sky_energy_1': round(sun_lum / math.pi / chroma_lum, 4),
        'sky_horizontal_irradiance_rgb': [round(float(x), 4) for x in sky_e],
        'sun_horizontal_irradiance_lum': round(sun_lum * math.sin(math.radians(elev)), 4),
        'sky_horizontal_irradiance_lum': round(sky_lum, 4),
        'processed_max_luminance': round(float(out_lum.max()), 3),
    }
    json.dump(info, open(os.path.join(out_dir, 'sun.json'), 'w'), indent=2)
    print(json.dumps(info, indent=2))

    if preview:
        from PIL import Image
        t = out / (1.0 + out)
        t = np.clip(t, 0, 1) ** (1 / 2.2)
        Image.fromarray((t * 255).astype(np.uint8)).save(preview)


if __name__ == '__main__':
    main()
