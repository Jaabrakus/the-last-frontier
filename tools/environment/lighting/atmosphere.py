"""Reference implementation of the Frontier sky model (package A, dynamic sky system).

The same single-scattering atmosphere as shaders/sky/frontier_sky_dynamic.gdshader and the CPU
side of scripts/world/env/sky_model.gd, in numpy, for calibration against the Poly Haven HDRI
(look-dev spec 3.1) and for documentation. Units: radiance in "HDRI units" (the panorama at
energy 1), so the DirectionalLight energy convention of the rig stays E_normal / (pi * luma).

Usage:
  python3 atmosphere.py calibrate      # prints the default-state sky by elevation band vs the HDRI
  python3 atmosphere.py table          # sun colour / energy / sky irradiance vs sun elevation
"""
import math
import sys

import numpy as np

R_GROUND = 6360e3
R_TOP = 6460e3
H_R = 8000.0
H_M = 1200.0
BETA_R = np.array([5.802e-6, 13.558e-6, 33.1e-6])
BETA_M_SCA = 3.996e-6
BETA_O = np.array([0.650e-6, 1.881e-6, 0.085e-6])
OZONE_COLUMN_M = 15000.0      # equivalent thickness (density 1) of the ozone layer
OZONE_ALT_M = 25000.0
CAM_ALT_M = 200.0
LUMA = np.array([0.2126, 0.7152, 0.0722])

# Tunables (the shader's uniforms; defaults = calibrated late-summer haze, see calibrate()).
DEFAULTS = dict(
    sun_intensity=11.4,     # top-of-atmosphere sun normal irradiance (HDRI units)
    mie_density=4.0,        # x a clear standard Mie aerosol (late-summer haze)
    mie_g=0.75,
    ms_factor=1.0,          # multiple-scattering approximation (isotropic, fraction of single)
    sky_saturation=0.85,    # < 1: hazier, whiter sky (applied after the integral)
    samples=12,
)
LUT_MIE = [2.0, 4.0, 8.0, 16.0]
LUT_EL = list(range(-20, 91))


def chapman(X, h, mu):
    """Schueler 2012 approximation of the Chapman grazing-incidence function, times exp(-h):
    optical depth factor (in scale heights) from normalised altitude h (= alt / H) along a ray
    with zenith cosine mu, for X = R / H."""
    c = np.sqrt(X + h)
    mu = np.asarray(mu, dtype=float)
    up = c / (c * mu + 1.0) * np.exp(-h)
    x0 = np.sqrt(np.maximum(1.0 - mu * mu, 0.0)) * (X + h)
    c0 = np.sqrt(x0)
    down = 2.0 * c0 * np.exp(X - x0) - c / (1.0 - c * mu) * np.exp(-h)
    return np.where(mu >= 0.0, up, down)


def optical_depth_to_space(alt, mu, mie_density):
    """RGB optical depth from altitude alt (m) toward zenith cosine mu, to the top."""
    r = R_GROUND + alt
    tr = H_R * chapman(R_GROUND / H_R, alt / H_R, mu)
    tm = H_M * chapman(R_GROUND / H_M, alt / H_M, mu)
    # Ozone: a thin shell at OZONE_ALT_M; slant factor of a shell of radius R + 25 km.
    rs = R_GROUND + OZONE_ALT_M
    sin2 = (r / rs) ** 2 * (1.0 - mu * mu)
    slant = 1.0 / np.sqrt(np.maximum(1.0 - sin2, 0.02))
    below = mu >= -np.sqrt(np.maximum(1.0 - (R_GROUND / r) ** 2, 0.0))
    to = OZONE_COLUMN_M * slant * np.where(below, 1.0, 2.0)
    return (np.multiply.outer(tr, BETA_R) + np.multiply.outer(tm, np.full(3, BETA_M_SCA * 1.11 * mie_density))
            + np.multiply.outer(to, BETA_O))


def phase_r(c):
    return 3.0 / (16.0 * math.pi) * (1.0 + c * c)


def phase_m(c, g):
    g2 = g * g
    return 3.0 / (8.0 * math.pi) * (1.0 - g2) * (1.0 + c * c) / ((2.0 + g2) * (1.0 + g2 - 2.0 * g * c) ** 1.5)


def sky(view, sun, p=None):
    """Sky radiance RGB for unit view directions view (N, 3) and unit sun direction (3,)."""
    p = dict(DEFAULTS, **(p or {}))
    view = np.atleast_2d(view).astype(float)
    n = p['samples']
    r0 = R_GROUND + CAM_ALT_M
    # Below-horizon rays are evaluated along the horizon (the shader blends them to the ground).
    cos_t = view @ sun
    view = view.copy()
    view[:, 1] = np.maximum(view[:, 1], 0.0)
    view /= np.linalg.norm(view, axis=1)[:, None]
    mu_h = view[:, 1]
    b = r0 * mu_h
    t_top = -b + np.sqrt(b * b - r0 * r0 + R_TOP * R_TOP)
    pr = phase_r(cos_t)
    pm = phase_m(cos_t, p['mie_g'])
    L = np.zeros((view.shape[0], 3))
    tau_v = np.zeros((view.shape[0], 3))
    # Exponential sample distribution (dense near the camera).
    edges = (np.exp(np.linspace(0.0, 1.0, n + 1) * 4.0) - 1.0) / (math.exp(4.0) - 1.0)
    for i in range(n):
        s0 = edges[i] * t_top
        s1 = edges[i + 1] * t_top
        ds = s1 - s0
        s = 0.5 * (s0 + s1)
        pos_y = r0 + s * mu_h
        pos_r = np.sqrt((s * s) * (1.0 - mu_h * mu_h) + pos_y ** 2)
        alt = np.maximum(pos_r - R_GROUND, 0.0)
        rho_r = np.exp(-alt / H_R)
        rho_m = np.exp(-alt / H_M) * p['mie_density']
        ext = np.outer(rho_r, BETA_R) + np.outer(rho_m, np.full(3, BETA_M_SCA * 1.11))
        tau_v += ext * ds[:, None] * 0.5
        # Sun zenith cosine at the sample (the local up is the normalised position).
        up = np.stack([view[:, 0] * s, pos_y, view[:, 2] * s], axis=1) / pos_r[:, None]
        mu_s = up @ sun
        tau_s = optical_depth_to_space(alt, mu_s, p['mie_density'])
        T = np.exp(-(tau_v + tau_s))
        sca_r = np.outer(rho_r * pr, BETA_R)
        sca_m = np.outer(rho_m * pm, np.full(3, BETA_M_SCA))
        iso = (np.outer(rho_r, BETA_R) + np.outer(rho_m, np.full(3, BETA_M_SCA))) / (4.0 * math.pi)
        ms = iso * p['ms_factor'] * np.exp(-(tau_v + 0.25 * tau_s))
        L += (T * (sca_r + sca_m) + ms) * ds[:, None]
        tau_v += ext * ds[:, None] * 0.5
    L = L * p['sun_intensity']
    lum = L @ LUMA
    return lum[:, None] + (L - lum[:, None]) * p.get('sky_saturation', 1.0)


def sun_transmittance(sun, p=None):
    p = dict(DEFAULTS, **(p or {}))
    return np.exp(-optical_depth_to_space(CAM_ALT_M, np.array([sun[1]]), p['mie_density'])[0])


def dir_from(az_deg, el_deg):
    az = math.radians(az_deg)
    el = math.radians(el_deg)
    return np.array([math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el)])


def hemisphere_irradiance(sun, p=None, n=24):
    """Horizontal sky irradiance (RGB), cosine-weighted, n x 4n samples."""
    els = (np.arange(n) + 0.5) / n * 90.0
    azs = (np.arange(4 * n) + 0.5) / (4 * n) * 360.0
    E = np.zeros(3)
    dirs = []
    w = []
    for el in els:
        for az in azs:
            dirs.append(dir_from(az, el))
            e = math.radians(el)
            w.append(math.sin(e) * math.cos(e) * (math.pi / 2 / n) * (2 * math.pi / (4 * n)))
    dirs = np.array(dirs)
    L = sky(dirs, sun, p)
    E = (L * np.array(w)[:, None]).sum(0)
    return E


def calibrate(p=None):
    sun = dir_from(222.5, 19.1)
    hdri = {  # spec 3.1 mean HDRI radiance by elevation band (all azimuths)
        (80, 90): (0.13, 0.20, 0.31), (45, 60): (0.22, 0.31, 0.46), (20, 30): (0.52, 0.65, 0.83),
        (5, 10): (0.84, 0.91, 0.93), (0, 3): (0.85, 0.81, 0.72)}
    for (a, b), ref in hdri.items():
        dirs = np.array([dir_from(az, el) for el in np.linspace(a, b, 4) for az in np.arange(0, 360, 10)])
        L = sky(dirs, sun, p).mean(0)
        print('band %2d-%2d  model %s  hdri %s' % (a, b, np.round(L, 3), ref))
    T = sun_transmittance(sun, p)
    Esun = T * dict(DEFAULTS, **(p or {}))['sun_intensity']
    Esky = hemisphere_irradiance(sun, p)
    print('sun normal irradiance RGB', np.round(Esun, 3), 'lum %.3f (HDRI 7.64)' % (Esun @ LUMA))
    print('sun colour (max 1)', np.round(T / T.max(), 3), 'HDRI (1.0, 0.805, 0.572)')
    print('sky horizontal irradiance', np.round(Esky, 3), 'lum %.3f (HDRI 1.33, rgb 1.06 1.36 1.82)' % (Esky @ LUMA))
    print('sun horizontal / sky = %.2f (HDRI 1.75)' % ((Esun @ LUMA) * sun[1] / (Esky @ LUMA)))


def table(p=None):
    for el in [-12, -8, -6, -4, -2, 0, 2, 5, 10, 19.1, 30, 45, 60]:
        sun = dir_from(222.5, el)
        T = sun_transmittance(sun, p)
        E = T * dict(DEFAULTS, **(p or {}))['sun_intensity']
        Es = hemisphere_irradiance(sun, p, n=12)
        zen = sky(np.array([[0, 1, 0]]), sun, p)[0]
        print('el %6.1f  T %s  Esun_lum %.4f  Esky_lum %.5f  zenith %s' % (el, np.round(T, 4), E @ LUMA, Es @ LUMA, np.round(zen, 5)))


def lut(out_path):
    """Per haze level and sun elevation, per unit sun_intensity: horizontal sky irradiance,
    mean radiance of the horizon band (0-4 deg, all azimuths), zenith radiance and the mean over
    the upper hemisphere. Read by scripts/world/env/sky_model.gd (ambient, fog, exposure, ground
    and overcast colours on the CPU)."""
    import json
    out = {'about': 'tools/environment/lighting/atmosphere.py lut; values per unit sun_intensity, RGB',
           'mie': LUT_MIE, 'elevation_deg': LUT_EL, 'params': {k: v for k, v in DEFAULTS.items() if k != 'mie_density'},
           'irradiance': [], 'horizon': [], 'zenith': [], 'upper_mean': []}
    hor_dirs = np.array([dir_from(az, el) for el in (0.5, 2.0, 4.0) for az in range(0, 360, 15)])
    up_dirs = np.array([dir_from(az, el) for el in (10, 25, 40, 55, 70) for az in range(0, 360, 20)])
    for md in LUT_MIE:
        rows = {'irradiance': [], 'horizon': [], 'zenith': [], 'upper_mean': []}
        for el in LUT_EL:
            p = dict(mie_density=md, sun_intensity=1.0)
            sun = dir_from(222.5, el)
            rows['irradiance'].append([round(float(v), 7) for v in hemisphere_irradiance(sun, p, n=10)])
            rows['horizon'].append([round(float(v), 7) for v in sky(hor_dirs, sun, p).mean(0)])
            rows['zenith'].append([round(float(v), 7) for v in sky(np.array([[0.0, 1.0, 0.0]]), sun, p)[0]])
            rows['upper_mean'].append([round(float(v), 7) for v in sky(up_dirs, sun, p).mean(0)])
        for k in rows:
            out[k].append(rows[k])
        print('mie', md, 'done')
    with open(out_path, 'w') as f:
        json.dump(out, f, separators=(',', ':'))
    print('wrote', out_path)


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'calibrate'
    if cmd == 'lut':
        lut(sys.argv[2] if len(sys.argv) > 2 else 'assets/environment/sky/sky_lut.json')
        sys.exit(0)
    kw = {}
    for a in sys.argv[2:]:
        k, v = a.split('=')
        kw[k] = float(v) if '.' in v else int(v)
    if cmd == 'table':
        table(kw)
    else:
        calibrate(kw)
