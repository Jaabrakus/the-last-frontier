#!/usr/bin/env python3
"""P05 painted sky panoramas and P06 skyline cards (style guide 5.4 "Sky", 10; palettes.json "directions").

    python3 tools/thuyvan_art/paint/paint_sky.py [--only jade_mist_morning,...] [--size 4096]

One 4096 x 2048 equirectangular panorama per direction, painted, never photographic:
  * the sky's gradient (zenith -> mid -> (low) -> horizon) in the direction's colours, the lower half the fog colour;
  * a painted sun glow where that direction's sun is (no disc: the engine draws the sun; dusk gets a soft disc);
  * clouds as painted heaps of brushed puffs, each lit toward the sun with a cool shaded base: morning low banks and a
    few soft cumulus, noon two or three towering heaps with flat blue-grey bases, dusk long bars lit from beneath;
  * two bands of far karst silhouettes along the horizon (2 fog-tinted layers), so the skyline never ends flat.

Panorama convention (the Thủy Vân sky shader samples it this way; PanoramaSkyMaterial matches it when its sky is
rotated so that north faces -Z): u = fract(0.5 + atan(dir.x, -dir.z) / 2 pi) (north, -Z, at u = 0.5; east, +X, at
u = 0.75), v = acos(dir.y) / pi (zenith at the top). Azimuths are degrees clockwise from north, as in palettes.json.

P06: assets/thuyvan/paint/sky/tv_skyline_karst_{0,1,2}.png, 4096 x 512 RGBA cards of far karst towers (0 nearest,
2 farthest), painted lit (lit flank, shaded flank, pine crowns, mist at the foot) in neutral values; the card shader
multiplies them toward the direction's fog colour by distance (style guide 5.2 "Far skyline cards").

Writes assets/thuyvan/paint/sky/tv_sky_<direction>.png and sky.json (the convention, per-direction sun uv).
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvp  # noqa: E402
from tvp import lin, mix  # noqa: E402

DIRS = ["jade_mist_morning", "bright_saturated_noon", "golden_lantern_dusk"]


def srgb(h):
    return tvp.hex_srgb(h)


def az_to_u(az):
    return (0.5 + az / 360.0) % 1.0


class Sky:
    def __init__(self, W, seed, d):
        self.W, self.H = W, W // 2
        self.ppd = W / 360.0  # pixels per degree
        self.d = d
        self.cv = tvp.Canvas(self.H, self.W, 360.0, seed, np.stack([lin(d["sky"]["zenith"])] * 4), bristle=0.3,
                             streak=0.04)
        self.rng = self.cv.rng
        v = (np.arange(self.H, dtype=np.float32) + 0.5) / self.H
        self.elev = (90.0 - v * 180.0)[:, None] * np.ones((1, self.W), np.float32)
        u = (np.arange(self.W, dtype=np.float32) + 0.5) / self.W
        self.az = ((u - 0.5) * 360.0)[None, :] * np.ones((self.H, 1), np.float32)
        s = d["sun"]
        self.sun_az, self.sun_el = s["azimuth_deg"], s["elevation_deg"]

    def xy(self, az, el):
        return az_to_u(az) * self.W, (90.0 - el) / 180.0 * self.H

    def ang_to_sun(self):
        a1, e1 = np.radians(self.az), np.radians(self.elev)
        a2, e2 = math.radians(self.sun_az), math.radians(self.sun_el)
        c = np.sin(e1) * math.sin(e2) + np.cos(e1) * math.cos(e2) * np.cos(a1 - a2)
        return np.degrees(np.arccos(np.clip(c, -1, 1)))

    def gradient(self):
        sk = self.d["sky"]
        e = np.clip(self.elev, 0, 90)
        stops = [(0.0, sk["horizon"])]
        if "low" in sk:
            stops.append((7.0, sk["low"]))
            stops.append((26.0, sk["mid"]))
        else:
            stops.append((14.0, sk["mid"]))
        stops.append((90.0, sk["zenith"]))
        es = np.array([s[0] for s in stops], np.float32)
        cs = np.stack([srgb(s[1]) for s in stops])
        t = np.clip(e, 0, 90)
        # ease the gradient: denser colour change near the horizon
        out = np.zeros(e.shape + (3,), np.float32)
        for i in range(len(stops) - 1):
            m = (t >= es[i]) & (t <= es[i + 1])
            f = ((t - es[i]) / (es[i + 1] - es[i]))[..., None]
            f = f * f * (3 - 2 * f)
            out = np.where(m[..., None], cs[i] + (cs[i + 1] - cs[i]) * f, out)
        fog = srgb(self.d["fog"]["color"])
        hz = srgb(sk["horizon"])
        below = mix(hz, fog, np.clip(-self.elev / 4.0, 0, 1)[..., None])
        out = np.where((self.elev < 0)[..., None], below, out)
        # sun glow (screen blend in sRGB)
        a = self.ang_to_sun()
        sc = srgb(self.d["sun"]["color"])
        g = 0.55 * np.exp(-a / 7.0) + 0.28 * np.exp(-a / 28.0) + 0.1 * np.exp(-a / 70.0)
        if self.sun_el < 10:  # a low sun warms the whole horizon band around it
            g = g + 0.25 * np.exp(-np.abs(self.elev) / 6.0) * np.exp(-a / 60.0)
        g = np.clip(g, 0, 1)[..., None]
        out = 1.0 - (1.0 - out) * (1.0 - sc * g)
        self.cv.col = tvp.s2l(out)

    def puff_colours(self, x, y, el):
        sk = self.d["sky"]
        return lin(sk["cloud_lit"]), lin(sk["cloud_shade"])

    def heap(self, az, el_base, width_deg, height_deg, n_puffs=40, flat_base=True, lit_below=False, thin=1.0,
             opacity=1.0):
        """A cumulus heap: puffs filling a dome over a flat base; lit toward the sun, cool shade at the base."""
        rng = self.rng
        cl_lit, cl_shade = self.puff_colours(0, 0, el_base)
        sun_dx = ((self.sun_az - az + 180) % 360 - 180)
        up = np.array([np.clip(sun_dx / 60.0, -0.8, 0.8), -1.0 if not lit_below else 1.0])
        up = up / np.linalg.norm(up)
        puffs = []
        for i in range(n_puffs):
            fx = rng.uniform(-1, 1)
            top = (1 - fx * fx) ** 0.7
            fy = rng.uniform(0.0, 1.0) ** 0.8 * top
            r = (0.16 + 0.22 * top * rng.uniform(0.5, 1.0)) * min(width_deg * 0.5, height_deg * 1.4) * thin
            puffs.append((fx, fy, r))
        puffs.sort(key=lambda p: p[1])  # paint low puffs first, so the upper ones overlap them
        for (fx, fy, r) in puffs:
            a = az + fx * width_deg * 0.5
            e = el_base + fy * height_deg + r * 0.6
            x, y = self.xy(a, e)
            stretch = 1.0 / max(math.cos(math.radians(e)), 0.3)
            rx, ry = r * self.ppd * stretch, r * self.ppd
            k = np.clip(fy * 1.1 + 0.15, 0, 1) if not lit_below else np.clip(1.0 - fy * 1.2, 0, 1)
            body = mix(cl_shade, cl_lit, 0.35 + 0.55 * k)
            dark = mix(cl_shade, lin(self.d["sky"]["zenith"]), 0.2)
            light = mix(cl_lit, lin("#ffffff"), 0.3)
            self.cv.stroke3(x, y, rx, ry, 0.0, body, dark, light, up=(float(up[0]), float(up[1])), h_add=0.0,
                            power=2.0, wob=0.12, edge=0.45, dark_off=0.2, light_off=0.18, light_amt=0.8,
                            dark_amt=0.35 * opacity, shade=0.35, opacity=0.9 * opacity, bristle=0.25, dry=0.15)
        if flat_base:  # the flat cool base, brushed along
            x0, y0 = self.xy(az, el_base + 0.2 * height_deg * 0.15)
            self.cv.dab(x0, y0, width_deg * 0.42 * self.ppd, max(height_deg * 0.07, 0.4) * self.ppd, 0.0,
                        mix(cl_shade, cl_lit, 0.15), opacity=0.55 * opacity, edge=0.4, bristle=0.5, dry=0.5, wob=0.06)

    def bank(self, az, el, width_deg, height_deg, opacity=0.8):
        """A low cloud bank: long soft brushed layers, lit along the top."""
        rng = self.rng
        cl_lit, cl_shade = self.puff_colours(0, 0, el)
        for i in range(int(width_deg / 4) + 6):
            a = az + rng.uniform(-0.5, 0.5) * width_deg
            e = el + rng.uniform(0, 1) * height_deg
            x, y = self.xy(a, e)
            L = rng.uniform(6, 18) * self.ppd
            W = rng.uniform(0.8, 2.2) * self.ppd * (height_deg / 4.0)
            t = (e - el) / max(height_deg, 1e-3)
            body = mix(cl_shade, cl_lit, 0.3 + 0.6 * t)
            self.cv.stroke3(x, y, L, W, rng.uniform(-0.03, 0.03), body, mix(cl_shade, body, 0.4),
                            mix(cl_lit, lin("#ffffff"), 0.2), up=(0, -1), h_add=0.0, wob=0.15, edge=0.35,
                            opacity=opacity * rng.uniform(0.6, 1.0), dark_amt=0.25, light_amt=0.6, bristle=0.45,
                            dry=0.4, taper=0.3)

    def bars(self, n, el_range, width_range):
        """Dusk: long thin cloud bars, violet bodies lit gold from beneath where they face the sun."""
        rng = self.rng
        sk = self.d["sky"]
        lit, body_c = lin(sk["cloud_lit"]), lin(sk["cloud_shade"])
        for i in range(n):
            a = rng.uniform(-180, 180)
            e = rng.uniform(*el_range)
            x, y = self.xy(a, e)
            L = rng.uniform(*width_range) * self.ppd * 0.5
            W = rng.uniform(0.35, 1.1) * self.ppd
            ds = abs((a - self.sun_az + 180) % 360 - 180)
            near = math.exp(-ds / 50.0)
            b = mix(body_c, lin(sk["mid"]), 0.25)
            under = mix(b, lit, 0.35 + 0.65 * near)
            self.cv.stroke3(x, y, L, W, rng.uniform(-0.02, 0.02), mix(b, under, 0.25 * near), b, under, up=(0, 1),
                            h_add=0.0, wob=0.2, edge=0.4, opacity=rng.uniform(0.6, 0.95), dark_amt=0.0,
                            light_off=0.35, light_amt=0.9, bristle=0.5, dry=0.5, taper=0.4)

    def karst_band(self, el_top, el_foot, n, col_lit, col_shade, mist_col, seed_shift=0, width=(1.2, 3.2)):
        """A far range of karst towers along the horizon: leaning, flat-crowned columns, a lit flank toward the sun,
        their feet lost in mist."""
        prof, side = karst_profile(self.W, self.ppd, self.rng, n, el_top, width)
        Yp = (90.0 - prof) / 180.0 * self.H  # pixel row of the top of the range at each column
        rows = np.arange(self.H, dtype=np.float32)[:, None]
        inside = rows >= Yp[None, :]
        e_foot_px = (90.0 - el_foot) / 180.0 * self.H
        sunx = math.sin(math.radians(self.sun_az))
        f = np.clip((rows - Yp[None, :]) / max((e_foot_px - Yp.min()), 1.0), 0, 1)
        sgn = 1.0 if sunx >= 0 else -1.0
        lit_amt = tvp.smoothstep(-0.6, 0.6, side * sgn)[None, :] * (0.85 if self.sun_el > 8 else 1.0)
        c = mix(lin(col_shade), lin(col_lit), lit_amt[..., None] * (1 - f[..., None] * 0.6))
        mist = tvp.smoothstep(0.05, 0.85, f)[..., None]
        c = mix(c, lin(mist_col), mist)
        a = inside.astype(np.float32)
        a = tvp.blur_clamped(a, 0.8)
        self.cv.col = mix(self.cv.col, c, a[..., None])
        # brush the flanks: vertical strokes inside the range
        rng = self.rng
        for i in range(n * 6):
            x = rng.uniform(0, self.W)
            top = Yp[int(x) % self.W]
            y = top + rng.uniform(0.1, 0.7) * (e_foot_px - top)
            if y <= top + 2:
                continue
            cc = self.cv.col[int(y) % self.H, int(x) % self.W]
            self.cv.dab(x, y, rng.uniform(0.6, 2.0) * self.ppd, rng.uniform(0.08, 0.25) * self.ppd, math.pi / 2,
                        tvp.jitter(cc, dv=rng.uniform(-0.08, 0.08)), opacity=0.5, edge=0.4, bristle=0.6, dry=0.6)

    def mist_line(self, el, thick_deg, col, opacity=0.6):
        rng = self.rng
        for i in range(70):
            a = rng.uniform(-180, 180)
            x, y = self.xy(a, el + rng.uniform(-0.5, 0.5) * thick_deg)
            self.cv.dab(x, y, rng.uniform(8, 24) * self.ppd, rng.uniform(0.3, 0.8) * thick_deg * self.ppd, 0.0,
                        lin(col), opacity=opacity * rng.uniform(0.4, 1.0), edge=0.2, bristle=0.35, dry=0.4,
                        wob=0.2)


def karst_profile(W, ppd, rng, n, el_top, width=(1.2, 3.2)):
    """Height (degrees) of a range of karst towers per pixel column, and the flank it shows (-1 west .. +1 east).
    A tower: steep sides, a rounded dome crown (no flat mesa), 1-2 lower tiers stepping out at its foot, a few pine
    bumps on the crown; towers 1.5-4 x as tall as wide."""
    prof = np.zeros(W, np.float32)
    side = np.zeros(W, np.float32)
    x = np.arange(W, dtype=np.float32)
    for i in range(n):
        cx = rng.uniform(0, W)
        h = el_top * rng.uniform(0.35, 1.0)
        w = min(rng.uniform(*width) * ppd, h * ppd / rng.uniform(1.5, 3.5))  # full width (px)
        dx = (x - cx + W / 2) % W - W / 2
        hw = w * 0.5
        core = 0.55 + rng.uniform(-0.1, 0.1)
        a = np.abs(dx) / hw
        dome = np.where(a < core, 1.0, np.sqrt(np.clip(1 - ((a - core) / (1 - core)) ** 2, 0, 1)))
        hh = h * dome * (a < 1)
        for k in range(rng.integers(0, 3)):  # tiers stepping out lower down
            f = rng.uniform(0.3, 0.7)
            ww = hw * rng.uniform(1.2, 1.6)
            off = rng.uniform(-0.3, 0.3) * hw
            aa = np.abs(dx - off) / ww
            tier = h * f * np.where(aa < 0.7, 1.0, np.sqrt(np.clip(1 - ((aa - 0.7) / 0.3) ** 2, 0, 1))) * (aa < 1)
            hh = np.maximum(hh, tier)
        for k in range(rng.integers(2, 6)):  # pine bumps on the crown
            bx = cx + rng.uniform(-0.45, 0.45) * hw
            br = rng.uniform(0.08, 0.16) * hw
            ddx = (x - bx + W / 2) % W - W / 2
            top = h * np.where(np.abs(dx) < hw, dome, 0)
            bump = top + br * 0.9 / ppd * np.sqrt(np.clip(1 - (ddx / br) ** 2, 0, 1))
            hh = np.where(np.abs(ddx) < br, np.maximum(hh, bump), hh)
        upd = hh > prof
        prof = np.where(upd, hh, prof)
        side = np.where(upd, np.clip(dx / max(hw, 1), -1, 1), side)
    return prof, side


def paint_direction(name, W, seed):
    d = tvp.direction(name)
    s = Sky(W, seed, d)
    s.gradient()
    rng = s.rng
    sk = d["sky"]
    fog = d["fog"]["color"]
    if name == "jade_mist_morning":
        for i in range(9):
            s.heap(rng.uniform(-180, 180), rng.uniform(12, 34), rng.uniform(22, 44), rng.uniform(7, 13), 50,
                   opacity=0.8)
        for i in range(18):
            s.bank(rng.uniform(-180, 180), rng.uniform(2.0, 7.0), rng.uniform(40, 100), rng.uniform(3.0, 7.0), 0.7)
        far, near = mix(srgb(d["targets"]["far_karst"]), srgb(sk["horizon"]), 0.45), srgb(d["targets"]["far_karst"])
        s.karst_band(8.0, 0.0, 46, tvp_hex(mix(far, srgb(sk["horizon"]), 0.2)), tvp_hex(far),
                     sk["horizon"], width=(1.6, 4.0))
        s.mist_line(2.0, 3.0, d["mist"] if "mist" in d else "#e2eaea", 0.55)
        s.karst_band(5.5, 0.0, 30, tvp_hex(mix(near, srgb(d["targets"]["mid_karst_lit"]), 0.3)),
                     tvp_hex(mix(near, srgb(d["targets"]["karst_shade"]), 0.35)), fog, width=(2.2, 5.0))
        s.mist_line(0.4, 1.4, d["targets"]["mist"], 0.7)
    elif name == "bright_saturated_noon":
        for i in range(3):
            s.heap(-170 + i * 120 + rng.uniform(-30, 30), rng.uniform(4, 8), rng.uniform(40, 60), rng.uniform(22, 32),
                   110)
        for i in range(9):
            s.heap(rng.uniform(-180, 180), rng.uniform(5, 14), rng.uniform(10, 22), rng.uniform(4, 9), 34)
        for i in range(5):
            s.bank(rng.uniform(-180, 180), rng.uniform(0.5, 2.5), rng.uniform(40, 80), 2.0, 0.5)
        far = srgb(d["targets"]["far_karst"])
        s.karst_band(7.0, 0.0, 46, tvp_hex(mix(far, srgb(sk["horizon"]), 0.35)),
                     tvp_hex(mix(far, srgb(sk["horizon"]), 0.15)), sk["horizon"], width=(1.6, 4.0))
        s.karst_band(5.0, 0.0, 30, tvp_hex(mix(far, srgb(d["targets"]["mid_karst_lit"]), 0.35)),
                     tvp_hex(mix(far, srgb(d["targets"]["karst_shade"]), 0.3)), fog, width=(2.2, 5.0))
        s.mist_line(0.3, 1.0, d["targets"]["mist"], 0.5)
    else:  # dusk
        s.bars(70, (2.5, 24.0), (20, 70))
        for i in range(5):
            s.heap(rng.uniform(-180, 180), rng.uniform(6, 14), rng.uniform(16, 30), rng.uniform(4, 8), 26,
                   lit_below=True, opacity=0.8)
        # a soft sun disc (the sun is setting behind the Two Heights)
        x, y = s.xy(s.sun_az, s.sun_el)
        s.cv.dab(x, y, 1.6 * s.ppd, 1.6 * s.ppd, 0.0, lin("#fff0c8"), opacity=0.9, edge=0.3, bristle=0.0,
                 streak=0.0)
        far = srgb(d["targets"]["far_karst"])
        s.karst_band(8.0, 0.0, 46, tvp_hex(mix(far, srgb(sk["low"]), 0.35)), tvp_hex(far), sk["low"],
                     width=(1.6, 4.0))
        s.mist_line(1.0, 1.8, d["targets"]["mist"], 0.5)
        s.karst_band(5.5, 0.0, 30, tvp_hex(mix(srgb(d["targets"]["karst_shade"]), srgb(d["targets"]["mid_karst_lit"]),
                                                0.35)),
                     d["targets"]["karst_shade"], d["fog"]["valley_color"], width=(2.2, 5.0))
        s.mist_line(0.3, 1.2, d["targets"]["mist"], 0.6)
    c = s.cv.col
    c = tvp.blur(c, 0.5)
    return tvp.to_u8(tvp.l2s(c)), s


def tvp_hex(c_srgb):
    c = np.clip(np.asarray(c_srgb), 0, 1)
    return "#%02x%02x%02x" % tuple(int(round(v * 255)) for v in c)


def skyline_cards(W=4096, H=512, seed=5500):
    """P06: three far-karst silhouette cards (0 nearest .. 2 farthest), lit neutral values + alpha."""
    out = []
    for layer in range(3):
        rng = np.random.default_rng(seed + layer * 31)
        ppd = W / 120.0  # a card spans 120 degrees of view at its distance
        el_top = H / ppd * 0.92
        prof, side = karst_profile(W, ppd, rng, 26 - layer * 4, el_top, width=(3.0 + layer, 9.0 + layer * 2))
        rows = np.arange(H, dtype=np.float32)[:, None]
        Yp = H - prof * ppd
        inside = rows >= Yp[None, :]
        f = np.clip((rows - Yp[None, :]) / max(H - Yp.min(), 1.0), 0, 1)
        lit = tvp.smoothstep(-0.6, 0.6, side)[None, :]
        val = 0.4 + 0.42 * lit - 0.12 * f - 0.06 * layer
        col = np.stack([val * 0.97, val, val * 1.04], -1)
        cv = tvp.Canvas(H, W, 120.0, seed + layer, np.stack([lin("#8a96a0")] * 4), wrap=False, alpha=True)
        cv.col = tvp.s2l(np.clip(col, 0, 1))
        for i in range(2600):  # flank strokes (vertical fluting, horizontal strata) and pine crowns
            x = rng.uniform(0, W)
            top = Yp[int(x)]
            if top >= H - 4:
                continue
            y = top + rng.uniform(0.02, 0.85) * (H - top)
            cc = cv.col[int(y) % H, int(x) % W]
            vert = rng.random() < 0.6
            cv.dab(x, y, rng.uniform(8, 30) if vert else rng.uniform(6, 18), rng.uniform(1.5, 4),
                   (math.pi / 2 if vert else 0.0) + rng.uniform(-0.1, 0.1),
                   tvp.jitter(cc, dv=rng.uniform(-0.16, 0.12)), opacity=0.55, edge=0.4, bristle=0.6, dry=0.6)
        for i in range(700):
            x = rng.uniform(0, W)
            top = Yp[int(x)]
            if top >= H - 30:
                continue
            r = rng.uniform(4, 11) * (1.0 - 0.2 * layer)
            cv.dab(x, top + r * 0.4, r * 1.4, r, 0.0, tvp.s2l(np.array([0.3, 0.36, 0.33]) + 0.08 * layer),
                   opacity=0.85, edge=0.5, bristle=0.2, alpha_add=True)
        a = tvp.blur_clamped(inside.astype(np.float32), 0.7)
        a = np.maximum(a, cv.alpha) * (1.0 - tvp.smoothstep(0.75, 1.0, f) * 0.6)
        img = tvp.to_u8(np.concatenate([tvp.l2s(cv.col), np.clip(a, 0, 1)[..., None]], -1))
        tvp.save(img, "sky/tv_skyline_karst_%d.png" % layer)
        out.append("sky/tv_skyline_karst_%d.png" % layer)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--size", type=int, default=4096)
    a = ap.parse_args()
    only = set(filter(None, a.only.split(",")))
    meta = {"convention": "u = fract(0.5 + atan(dir.x, -dir.z) / (2 pi)) (north at u 0.5, east at 0.75); "
                          "v = acos(dir.y) / pi; azimuth degrees clockwise from north",
            "size": [a.size, a.size // 2], "directions": {}}
    for i, name in enumerate(DIRS):
        if only and name not in only:
            continue
        img, s = paint_direction(name, a.size, 6100 + i * 7)
        p = tvp.save(img, "sky/tv_sky_%s.png" % name)
        Image.fromarray(img).resize((1024, 512), Image.LANCZOS).save(tvp.look_path("sky/tv_sky_%s_small.jpg" % name),
                                                                    quality=90)
        meta["directions"][name] = {"file": "sky/tv_sky_%s.png" % name, "sun_uv": [az_to_u(s.sun_az),
                                                                                  (90 - s.sun_el) / 180.0]}
        print("sky", name, os.path.getsize(p) // 1024, "KB", flush=True)
    if not only:
        meta["skyline_cards"] = skyline_cards()
        with open(os.path.join(tvp.OUT, "sky", "sky.json"), "w") as f:
            json.dump(meta, f, indent=1)


if __name__ == "__main__":
    main()
