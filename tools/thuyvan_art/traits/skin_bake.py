"""Preview bakes of a person's painted skin with their people's trait, for the Blender renders the owner judges
(numpy only). The game draws the same thing live in painted_skin.gdshader + people_trait.gdshaderinc (kinds 3-5) from
the maps of trait_maps.py; this bake is that shader's twin in the MakeHuman atlas, at 4096 so the scales are crisp.

    from skin_bake import Fields, bake
    F = Fields.load(4096, cache_dir)          # the per-texel fields (positions, orders, plates, scales...), cached
    bake(F, look, out_prefix)                 # -> <prefix>_albedo.png, _rough.png, _sheen.png, _height.png

`look` keys (the creator's look plus the Thủy Vân rows): melanin 0-1, undertone (cool/neutral/warm/olive), haemoglobin,
male (0/1), trait_kind (0 none, 3 scales, 4 plates, 5 river), trait (amount 0-1), trait_tone (hex), tint (Riverborn
water tint 0-1, 0 off), ash (a list of "thumbprint", "cheeks", "hands").

The painted skin is skin_common.gdshaderinc's tone_at / blood and painted_skin.gdshader's paint_skin, ported line by
line; the head's paint comes from body/paint_head.png through face_coords(), as in the game.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import trait_maps as TM  # noqa: E402

ROOT = TM.ROOT
TONES = np.array([[0.8879, 0.6724, 0.5520], [0.8148, 0.5457, 0.3968], [0.7379, 0.4397, 0.2918],
                  [0.6376, 0.3419, 0.2016], [0.5271, 0.2502, 0.1329], [0.4125, 0.1845, 0.0887],
                  [0.3050, 0.1301, 0.0612], [0.2086, 0.0887, 0.0437], [0.1384, 0.0612, 0.0319],
                  [0.0908, 0.0409, 0.0222], [0.0482, 0.0232, 0.0137], [0.0262, 0.0137, 0.0086]])
UNDERTONES = {"cool": (0.01, -0.012), "neutral": (0.0, 0.0), "warm": (0.004, 0.014), "olive": (-0.01, 0.01)}
HB_ABS = np.array([0.07, 0.62, 0.46])
M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566],
               [0.0883024619, 0.2817188376, 0.6299787005]])
M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099],
               [0.0259040371, 0.7827717662, -0.8086757660]])
M2i = np.linalg.inv(M2)
M1i = np.linalg.inv(M1)


def lin_to_oklab(c):
    lms = np.cbrt(np.maximum(c @ M1.T, 0.0))
    return lms @ M2.T


def oklab_to_lin(lab):
    lms = (lab @ M2i.T) ** 3
    return np.maximum(lms @ M1i.T, 0.0)


def srgb_to_lin(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def hexlin(h):
    return srgb_to_lin(np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)]) / 255.0)


# the water tint's chroma: the design's 0.050, pushed to 0.062 by eye for the painted look (data: tint.chroma)
TINT_CHROMA = 0.062


def tone_at(mel, undertone, tint=0.0):
    """skin_common.tone_at plus the Riverborn water tint (peoples_design 2.4) in OKLab."""
    m = min(max(mel, 0.0), 1.0) * 11.0
    i = min(int(math.floor(m)), 10)
    c = TONES[i] + (TONES[i + 1] - TONES[i]) * (m - i)
    lab = lin_to_oklab(c[None])[0]
    k = min(max(lab[0] / 0.87, 0.25), 1.0)
    u = UNDERTONES.get(undertone, (0.0, 0.0))
    lab[1] += u[0] * k * k
    lab[2] += u[1] * k
    if tint > 0.0:
        C = TINT_CHROMA * min(max(lab[0] / 0.65, 0.55), 1.0)
        tgt = np.array([C * math.cos(math.radians(230.0)), C * math.sin(math.radians(230.0))])
        lab[1:] = lab[1:] + (tgt - lab[1:]) * tint
        lab[0] = lab[0] + (lab[0] * 0.94 + 0.03 - lab[0]) * tint
    return oklab_to_lin(lab[None])[0]


def blood(amount, mel):
    screen = 1.0 + (0.30 - 1.0) * min(max(mel, 0.0), 1.0)
    return np.exp(-HB_ABS * (amount - 0.5) * 0.8 * screen)


def paint_skin(c, v, warm, cool, high, zone_strength=1.0, highlight=1.0):
    """painted_skin.gdshader paint_skin, over arrays."""
    lab = lin_to_oklab(c)
    chroma = np.maximum(np.linalg.norm(lab[:, 1:], axis=1), 0.02)
    lab[:, 0] *= 1.0 + v * 0.62
    sh = np.clip(-v * 2.0, 0, 1)
    li = np.clip(v * 2.0, 0, 1)
    lab[:, 1:] *= (1.0 + 0.10 * sh - 0.10 * li)[:, None]
    lab[:, 1:] += np.array([0.22, -0.02])[None] * (chroma * sh * 0.3)[:, None]
    lab[:, 1:] += np.array([0.55, -0.05])[None] * (chroma * warm * 0.30 * zone_strength)[:, None]
    lab[:, 1:] += np.array([-0.30, -0.40])[None] * (chroma * cool * 0.22 * zone_strength)[:, None]
    lab[:, 0] *= 1.0 - 0.03 * cool * zone_strength
    lab[:, 0] *= 1.0 + 0.10 * high * highlight
    lab[:, 1:] *= (1.0 - 0.12 * high * highlight)[:, None]
    return oklab_to_lin(lab)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


class Fields:
    """Everything per texel that does not depend on the person (cached as npz)."""

    @staticmethod
    def load(n, cache_dir):
        cp = os.path.join(cache_dir, "fields_%d.npz" % n)
        if os.path.exists(cp):
            z = np.load(cp)
            F = Fields()
            F.__dict__.update({k: z[k] for k in z.files})
            return F
        body = TM.Body()
        R = TM.raster(body, n, cache_dir)
        A = TM.Anatomy(body, R)
        F = Fields()
        F.n = np.array(n)
        F.index = R["index"]
        F.region = R["region"]
        F.pos = R["pos"].astype(np.float32)
        F.nrm = R["nrm"].astype(np.float32)
        F.col = R["col"].astype(np.float32)
        F.o_scales = TM.order_scales(A).astype(np.float32)
        edge, cid, ch = TM.plate_cells(A)
        F.o_plates = TM.per_cell_mean(TM.order_plates(A), cid).astype(np.float32)
        F.plate_edge = edge.astype(np.float32)
        F.plate_hash = ch.astype(np.float32)
        rs, rsc = TM.order_river(A)
        F.o_sheen = rs.astype(np.float32)
        F.o_rscale = rsc.astype(np.float32)
        F.gills = TM.gills(A).astype(np.float32)
        F.ash = TM.ash_marks(A).astype(np.float32)
        F.sheen_v = TM.sheen_value(A).astype(np.float32)
        # the scales, in the metre UVs, "down" made consistent per region; the face's smaller
        muv = R["muv"].astype(np.float64).copy()
        muv[:, 1] *= TM.v_down_sign(A.rname)
        head = A.is_("head", "neck_upper")
        cov, rim, h = TM.scale_cell(muv, TM.SCALE_CELL)
        cov_f, rim_f, h_f = TM.scale_cell(muv, TM.SCALE_CELL_FACE)
        F.sc_cover = np.where(head, cov_f, cov).astype(np.float32)
        F.sc_rim = np.where(head, rim_f, rim).astype(np.float32)
        F.sc_hash = np.where(head, h_f, h).astype(np.float32)
        cov2, rim2, h2 = TM.scale_cell(muv, (TM.SCALE_CELL[0] * 0.55, TM.SCALE_CELL[1] * 0.55))
        F.rsc_cover, F.rsc_rim, F.rsc_hash = cov2.astype(np.float32), rim2.astype(np.float32), h2.astype(np.float32)
        # the head's paint (paint_head.png through face_coords, as painted_skin.gdshader)
        info = json.load(open(TM.BODY_JSON))
        warp = info["face"]["warp"]
        u = R["muv"][:, 0].astype(np.float64)
        hgt = 1.0 - R["muv"][:, 1].astype(np.float64)
        hk, ht = np.array(warp["h"]), np.array(warp["h_v2"])
        uk, ut = np.array([0.0] + warp["u"]), np.array([0.0] + warp["u_v2"])
        fh = np.interp(hgt, hk, ht, left=None, right=None)
        fh = np.where(hgt < hk[0], ht[0] + (hgt - hk[0]), np.where(hgt > hk[-1], ht[-1] + (hgt - hk[-1]), fh))
        au = np.abs(u)
        fu = np.where(au > uk[-1], ut[-1] + (au - uk[-1]), np.interp(au, uk, ut)) * np.sign(u)
        pr = (-0.251327, 0.251327, 1.335, 1.605)
        tx = (fu - pr[0]) / (pr[1] - pr[0])
        ty = (pr[3] - fh) / (pr[3] - pr[2])
        ph = np.asarray(Image.open(os.path.join(ROOT, "assets/character/body/paint_head.png")).convert("RGBA"), np.float32) / 255.0
        H, W = ph.shape[:2]
        xi = np.clip(np.round(tx * W - 0.5), 0, W - 1).astype(int)
        yi = np.clip(np.round(ty * H - 0.5), 0, H - 1).astype(int)
        on_head = (R["region"] <= 1)
        P = ph[yi, xi]
        F.paint = np.where(on_head[:, None], P, np.array([0.5, 0.0, 0.0, 0.0], np.float32)[None]).astype(np.float32)
        F.on_head = on_head
        np.savez(cp, **{k: v for k, v in F.__dict__.items()})
        return F


def bake(F, look, prefix):
    n = int(F.n)
    mel = float(look.get("melanin", 0.3))
    under = look.get("undertone", "neutral")
    hb = float(look.get("haemoglobin", 0.5))
    tint = float(look.get("tint", 0.0))
    male = float(look.get("male", 0.0))
    kind = int(look.get("trait_kind", 0))
    amt = float(look.get("trait", 0.0))
    tone_hex = look.get("trait_tone", "#3f9a9a")
    M = len(F.index)
    if look.get("scalp_png"):
        look = dict(look, _mh=mh_of(F))
    skin = tone_at(mel, under, tint) * 0.9
    skin = skin * blood(0.5 + (hb - 0.5) * (1.0 - 0.7 * tint), mel)
    flush, mucosa, cavity = F.col[:, 0], F.col[:, 1], F.col[:, 2]
    fl = flush * (1.0 + (0.35 - 1.0) * min(max(mel, 0), 1)) * (1.0 - 0.8 * tint)
    base = skin[None] * (1.0 + (np.array([1.06, 0.89, 0.91]) - 1.0)[None] * (fl * 0.6)[:, None])
    # the painted value: the head's paint; the body a soft top light (the painter's broad forms)
    value = np.where(F.on_head, F.paint[:, 0], 0.5 + 0.07 * F.nrm[:, 1] + 0.03 * F.nrm[:, 2])
    v = (value - 0.5) * 1.35
    cool = F.paint[:, 2] * (0.12 + (0.55 - 0.12) * male)
    alb = paint_skin(base, v, F.paint[:, 1], cool, F.paint[:, 3])
    rough = np.full(M, 0.62) - 0.05 * flush
    sheen = np.zeros((M, 2))
    height = np.full(M, 0.5)
    tone = hexlin(tone_hex)
    # ------------------------------------------------------------------ the people's trait
    if kind == 3 and amt > 0.001:
        feather = np.clip((amt - F.o_scales) / 0.15, 0, 1)
        show = F.sc_cover * (F.sc_hash < feather * 1.08)
        share = np.where(F.on_head, 0.50, 0.62)[:, None]
        body_c = alb * (1 - share) + (tone * 1.25)[None] * share
        lit = 1.0 + 0.18 * (1.0 - F.sc_rim)
        sc = body_c * lit[:, None]
        sc = sc * (1.0 - 0.45 * smooth(0.55, 1.0, F.sc_rim))[:, None]
        k = show * (0.55 + 0.45 * feather)
        alb = alb * (1 - k[:, None]) + sc * k[:, None]
        rough = rough * (1 - k) + 0.30 * k
        sheen[:, 0] = k * (1.0 - 0.6 * F.sc_rim) * (0.6 + 0.4 * F.sheen_v)
        height = height + show * 0.35 * (1.0 - F.sc_rim ** 2)
        # a faint tint of the tone round the patch's edge (the patch reads from afar)
        halo = np.clip((amt + 0.10 - F.o_scales) / 0.10, 0, 1) * (1 - feather)
        alb = alb * (1 - 0.15 * halo[:, None]) + tone[None] * alb * 1.4 * (0.15 * halo[:, None])
    elif kind == 4 and amt > 0.001:
        on = (F.o_plates < amt).astype(np.float64)
        jit = 1.0 + (F.plate_hash - 0.5) * 0.16
        plate = alb * 0.18 + tone[None] * 0.82
        plate = plate * jit[:, None]
        e = F.plate_edge
        rim = smooth(0.0045, 0.0015, e) * smooth(0.0007, 0.0016, e)
        plate = plate * (1.0 + 0.16 * rim)[:, None]
        crack = 1.0 - smooth(0.0006, 0.0013, e)
        crack_c = tone[None] * 0.22 + np.array([0.004, 0.006, 0.012])[None]
        plate = plate * (1 - crack[:, None]) + crack_c * crack[:, None]
        quartz = (F.plate_hash < 0.083) & (e > 0.0013) & (e < 0.0020) & (F.sheen_v > 0.74)
        plate = np.where(quartz[:, None], hexlin("#dfe6ea")[None] * 0.9, plate)
        # a broad painted value inside each plate: lighter toward its upper middle, so the plates read as raised
        dome = smooth(0.0, 0.012, e)
        plate = plate * (0.92 + 0.12 * dome)[:, None]
        alb = alb * (1 - on[:, None]) + plate * on[:, None]
        rough = rough * (1 - on) + 0.8 * on
        height = height + on * (0.15 + 0.35 * dome - 0.5 * crack)
    elif kind == 5:
        # wet sheen patches
        wet = np.clip((amt - F.o_sheen) / 0.12, 0, 1)
        pearl = hexlin("#d8e4e4")
        alb = alb * (1 - 0.18 * wet[:, None]) + (alb * 0.5 + pearl[None] * 0.5) * (0.18 * wet[:, None])
        rough = rough * (1 - wet) + 0.38 * wet
        sheen[:, 1] = wet
        # scale patches (half size)
        feather = np.clip((amt - F.o_rscale) / 0.15, 0, 1)
        show = F.rsc_cover * (F.rsc_hash < feather * 1.15)
        sc = (alb * 0.62 + tone[None] * 0.38) * (1.0 + 0.2 * (1 - F.rsc_rim))[:, None]
        sc = sc * (1.0 - 0.4 * smooth(0.55, 1.0, F.rsc_rim))[:, None]
        k = show * (0.5 + 0.5 * feather)
        alb = alb * (1 - k[:, None]) + sc * k[:, None]
        rough = rough * (1 - k) + 0.3 * k
        sheen[:, 0] = k * (1.0 - 0.6 * F.rsc_rim)
        height = height + show * 0.25 * (1.0 - F.rsc_rim ** 2)
    if kind == 5 or look.get("gills"):
        g = F.gills if amt > 0.1 or look.get("gills") else 0.0 * F.gills
        core = smooth(0.6, 0.95, g)
        lip = smooth(0.15, 0.4, g) * (1 - core)
        inner = hexlin("#8a4a5a")
        alb = alb * (1 - core[:, None]) + (inner[None] * 0.7 + alb * 0.1) * core[:, None]
        alb = alb * (1 + 0.30 * lip)[:, None]
        height = height - 0.35 * core + 0.15 * lip
    # ------------------------------------------------------------------ ash marks (markings anyone may wear)
    ash = look.get("ash", [])
    if ash:
        a = np.zeros(M)
        if "thumbprint" in ash:
            a = np.maximum(a, F.ash[:, 0])
        if "cheeks" in ash:
            a = np.maximum(a, F.ash[:, 1])
        if "hands" in ash:
            a = np.maximum(a, F.ash[:, 2])
        # pale ash on a deep skin, a grey ash on a light one (it must read on every tone)
        lum = alb @ np.array([0.2126, 0.7152, 0.0722])
        k = smooth(0.12, 0.45, lum)[:, None]
        ash_c = hexlin("#cfcac2")[None] * (1 - k) + hexlin("#7e7a74")[None] * k
        L = np.clip(a * 0.78, 0, 1)
        alb = alb * (1 - L[:, None]) + (ash_c * (0.85 + 0.25 * F.ash[:, 3:4])) * L[:, None]
        rough = rough * (1 - L) + 0.92 * L
    # lips (painted mucosa) and the painted cavities, after the trait (lips are never marked)
    lipc = tone_at(mel * 0.82 + 0.02, under, tint) * 0.9 * blood(0.5 + 0.55 + 0.25 * hb, mel * 0.8)
    lipc = lipc * np.array([0.94, 0.80, 0.82])
    lipc = paint_skin(np.repeat(lipc[None], M, 0), v, np.zeros(M), np.zeros(M), F.paint[:, 3])
    mu = np.where(F.on_head, mucosa, 0.0)
    alb = alb * (1 - mu[:, None]) + lipc * mu[:, None]
    # the scalp under a hair style: its baked domain (the hair json's scalp_mask, in head_detail_rect) in the hair's
    # root colour, so the skin between the strand strips reads as roots (skin.gdshader's scalp_tint)
    if look.get("scalp_png"):
        rect = (0.6372, 0.1784, 0.9975, 0.9921)
        mh = look["_mh"]
        su = (mh[:, 0] - rect[0]) / (rect[2] - rect[0])
        sv = (mh[:, 1] - rect[1]) / (rect[3] - rect[1])
        sm = np.asarray(Image.open(look["scalp_png"]).convert("L"), np.float32) / 255.0
        H, W = sm.shape
        ok = (su >= 0) & (su <= 1) & (sv >= 0) & (sv <= 1) & F.on_head
        xi = np.clip((su * W).astype(int), 0, W - 1)
        yi = np.clip((sv * H).astype(int), 0, H - 1)
        nz = F.sheen_v
        m = np.where(ok, np.clip(sm[yi, xi] * 1.5 - 0.5 * nz, 0, 1), 0.0)
        hc = hexlin(look.get("hair_hex", "#1b1613"))
        alb = alb * (1 - m[:, None]) + (hc[None] * (0.5 + 0.3 * nz[:, None])) * m[:, None]
    cav = smooth(0.10, 0.45, cavity)
    cav = np.where(F.on_head, cav, 1.0 - 0.5 * (1.0 - cav))
    alb = alb * (0.55 + 0.45 * cav)[:, None]

    def save(arr, path, channels):
        img = np.zeros((n * n, channels), np.uint8)
        img[F.index] = np.clip(np.round(arr * 255.0), 0, 255).astype(np.uint8).reshape(M, channels)
        Image.fromarray(img.reshape(n, n, channels) if channels > 1 else img.reshape(n, n)).save(path)

    save(lin_to_srgb(alb), prefix + "_albedo.png", 3)
    save(np.clip(rough, 0, 1), prefix + "_rough.png", 1)
    save(np.c_[sheen, np.zeros(M)], prefix + "_sheen.png", 3)
    save(np.clip(height, 0, 1), prefix + "_height.png", 1)
    return prefix


def mh_of(F):
    """The texels' MakeHuman UVs (their atlas position: row = v * n)."""
    n = int(F.n)
    i = F.index
    return np.stack([(i % n + 0.5) / n, (i // n + 0.5) / n], 1)
