"""Head lab: quick offline renders of the customizer head from the body cache, with plain python3
(numpy, Pillow), for designing face shapes without a Blender build or a Godot window.

    python3 tools/character/head_lab.py OUT.png [--presets id,id|--looks JSON] [--style cached|new|none]
        [--views front,34,side] [--size 360] [--sex-only]

Reads tools/character/cache/body_v1.npz (the base vertices, triangles and every shape delta that
body/body.py wrote) and the rig joints of tools/character/cache/paint_src_v1.npz. A look is the base
plus its shape weights (sex, face_*, style), as BodyMaterials.apply_look sets them in game.

--style cached   the `style` shape of the cache (what body.glb has)
--style new      lib/stylize.style_delta recomputed from the current source (to iterate on it)
--style none     the realistic head

The render is a plain z-buffer rasterizer (a key, a fill and a rim light on a clay colour of the
look's skin tone) with the eyeballs as spheres (iris and pupil painted); brows, lashes and hair are
not drawn. It shows the forms only: the real look needs tools/character/face_portraits.gd.
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from lib import face as FC  # noqa: E402

CACHE = os.path.join(HERE, "cache", "body_v1.npz")
PAINT_SRC = os.path.join(HERE, "cache", "paint_src_v1.npz")
PEOPLES = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "character", "body", "peoples.json"))


class Joints(dict):
    """Rig joints (Blender space) with lib/rig.Skel's side() helper."""

    def side(self, name, s):
        p = self["l_" + name]
        return p if s > 0 else p * np.array([-1.0, 1.0, 1.0])


def load():
    z = np.load(CACHE, allow_pickle=False)
    shapes = {str(n): z["shape_" + str(n)].astype(float) for n in z["shape_names"]}
    ps = np.load(PAINT_SRC)
    K = Joints({str(n): np.asarray(p, float) for n, p in zip(ps["k_names"], ps["k_pos"])})
    return {"V": z["V"].astype(float), "F": z["F"].astype(int), "vlab": np.array([str(s) for s in z["vlab"]]),
            "shapes": shapes, "K": K}


def edges_of(F):
    E = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    return np.unique(np.sort(E, axis=1), axis=0)


def vertex_normals(V, F):
    N = np.zeros_like(V)
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    for k in range(3):
        np.add.at(N, F[:, k], fn)
    return N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)


def sphere_mesh(c, r, n=24):
    th = np.linspace(0, math.pi, n + 1)
    ph = np.linspace(0, 2 * math.pi, 2 * n + 1)
    T, P = np.meshgrid(th, ph, indexing="ij")
    # axis along -y (the gaze): theta from the front
    d = np.stack([np.sin(T) * np.cos(P), -np.cos(T), np.sin(T) * np.sin(P)], -1).reshape(-1, 3)
    V = c + d * r
    F = []
    w = 2 * n + 1
    for i in range(n):
        for j in range(2 * n):
            a, b, cc, e = i * w + j, i * w + j + 1, (i + 1) * w + j, (i + 1) * w + j + 1
            F += [[a, cc, b], [b, cc, e]]
    return V, np.array(F), T.reshape(-1)


def compose(D, weights):
    V = D["V"].copy()
    for k, w in weights.items():
        if w and k in D["shapes"]:
            V += D["shapes"][k] * w
    return V


def tone(melanin):
    anchors = np.array([(0.8879, 0.6724, 0.5520), (0.8148, 0.5457, 0.3968), (0.7379, 0.4397, 0.2918),
                        (0.6376, 0.3419, 0.2016), (0.5271, 0.2502, 0.1329), (0.4179, 0.1812, 0.0887),
                        (0.3140, 0.1274, 0.0595), (0.2232, 0.0844, 0.0395), (0.1529, 0.0561, 0.0273),
                        (0.1022, 0.0369, 0.0185), (0.0685, 0.0252, 0.0137), (0.0452, 0.0176, 0.0097)])
    m = min(max(melanin, 0.0), 1.0) * 11.0
    i = min(int(m), 10)
    return anchors[i] + (anchors[i + 1] - anchors[i]) * (m - i)


def render(V, F, eyes, view, size=360, skin=(0.7, 0.5, 0.4), headc=None, dist=0.50, fov=24.0, vcol=None):
    """Shaded image (PIL) of the triangles F of V and the eyeballs [(V, F, theta, iris colour)];
    vcol: a colour per vertex of V instead of the skin colour."""
    ang = {"front": 0.0, "34": 38.0, "side": 88.0, "back34": 145.0}.get(view, float(view) if view.lstrip("-").isdigit() else 0.0)
    a = math.radians(ang)
    # the character faces -y; the camera orbits about z (positive = toward the character's left)
    fwd = np.array([math.sin(a), -math.cos(a), 0.0])
    cam = headc + fwd * dist + np.array([0, 0, 0.02])
    zc = headc - cam
    zc /= np.linalg.norm(zc)
    xc = np.cross(zc, [0, 0, 1.0])
    xc /= np.linalg.norm(xc)
    yc = np.cross(xc, zc)
    f = 0.5 * size / math.tan(math.radians(fov) * 0.5)
    img = np.zeros((size, size, 3))
    zbuf = np.full((size, size), np.inf)
    key = np.array([-0.45, -0.75, 0.55])
    key /= np.linalg.norm(key)
    fill = np.array([0.6, -0.5, -0.1])
    fill /= np.linalg.norm(fill)
    parts = [(V, F, None, None)] + list(eyes)
    for Vp, Fp, theta, iris in parts:
        N = vertex_normals(Vp, Fp)
        Q = Vp - cam
        cx, cy, cz = Q @ xc, Q @ yc, Q @ zc
        px = size * 0.5 + f * cx / cz
        py = size * 0.5 - f * cy / cz
        # back-face cull in view space
        e1 = np.stack([px[Fp[:, 1]] - px[Fp[:, 0]], py[Fp[:, 1]] - py[Fp[:, 0]]], 1)
        e2 = np.stack([px[Fp[:, 2]] - px[Fp[:, 0]], py[Fp[:, 2]] - py[Fp[:, 0]]], 1)
        area = e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0]
        for t in np.nonzero(area < 0)[0]:
            i = Fp[t]
            xs, ys = px[i], py[i]
            x0, x1 = max(int(xs.min()), 0), min(int(xs.max()) + 1, size - 1)
            y0, y1 = max(int(ys.min()), 0), min(int(ys.max()) + 1, size - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
            if abs(d) < 1e-9:
                continue
            b0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
            b1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
            b2 = 1 - b0 - b1
            ins = (b0 >= -1e-6) & (b1 >= -1e-6) & (b2 >= -1e-6)
            if not ins.any():
                continue
            z = b0 * cz[i[0]] + b1 * cz[i[1]] + b2 * cz[i[2]]
            sub = zbuf[y0:y1 + 1, x0:x1 + 1]
            m = ins & (z < sub)
            if not m.any():
                continue
            sub[m] = z[m]
            n = b0[..., None] * N[i[0]] + b1[..., None] * N[i[1]] + b2[..., None] * N[i[2]]
            n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-9)
            if theta is None and vcol is not None and Vp is V:
                base = b0[..., None] * vcol[i[0]] + b1[..., None] * vcol[i[1]] + b2[..., None] * vcol[i[2]]
            elif theta is None:
                base = np.array(skin)
            else:
                th = b0 * theta[i[0]] + b1 * theta[i[1]] + b2 * theta[i[2]]
                base = np.where((th < 0.30)[..., None], np.array([0.02, 0.02, 0.02]),
                                np.where((th < 0.62)[..., None], np.array(iris), np.array([0.85, 0.83, 0.80])))
            lam = np.clip(n @ key, 0, 1) * 0.95 + np.clip(n @ fill, 0, 1) * 0.25 + 0.18
            rim = np.clip(1.0 - np.abs(n @ (-zc)), 0, 1) ** 3 * 0.25
            col = base * lam[..., None] + rim[..., None] * 0.3
            img[y0:y1 + 1, x0:x1 + 1][m] = col[m]
    bg = np.isinf(zbuf)
    img[bg] = (0.30, 0.32, 0.34)
    img = np.clip(img, 0, 1) ** (1 / 2.2)
    return Image.fromarray((img * 255).astype(np.uint8))


def head_tris(D, V):
    F = D["F"]
    keep = np.isin(D["vlab"], ["head", "neck"]) & (D["V"][:, 2] > 1.27)
    return F[keep[F].all(1)]


def eyes_for(K, weights, style_scale):
    out = []
    for s in (1, -1):
        c = FC.eye_center(K, s)
        Vs, Fs, th = sphere_mesh(c, FC.EYE_R * (1.0 + (style_scale - 1.0)), 16)
        out.append((Vs, Fs, th, (0.25, 0.15, 0.08)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--presets", default="english_f_a,english_m_a")
    ap.add_argument("--style", default="cached", choices=["cached", "new", "none"])
    ap.add_argument("--compare", action="store_true", help="each preset twice: realistic, then the style")
    ap.add_argument("--views", default="front,34,side")
    ap.add_argument("--size", type=int, default=360)
    ap.add_argument("--dist", type=float, default=0.50, help="camera distance (m)")
    ap.add_argument("--heat", action="store_true", help="colour the style's displacement along the normal "
                    "(red out, blue in, 4 mm full)")
    a = ap.parse_args()
    D = load()
    K = D["K"]
    peoples = json.load(open(PEOPLES))
    presets = {p["id"]: p for p in peoples["presets"] + peoples.get("stylized_presets", [])}
    style = None
    style_m = None
    eye_scale = 1.0
    if a.style == "cached":
        style = D["shapes"].get("style")
        style_m = D["shapes"].get("style_male")
    elif a.style == "new":
        from lib import stylize as ST
        E = edges_of(D["F"])
        from lib.body_shapes import BodyParams
        style = ST.style_delta(D["V"], D["F"], E, K, D["vlab"], P=BodyParams.female())
        style_m = ST.style_male_delta(D["V"], D["F"], E, K, D["vlab"], BodyParams.male(), D["shapes"]["sex"], style)
    if style is not None:
        from lib import stylize as ST
        eye_scale = ST.EYE_SCALE
    views = a.views.split(",")
    rows = []
    for pid in a.presets.split(","):
        pr = presets[pid]
        for st in ([None, style] if a.compare else [style]):
            w = dict(pr["face"])
            w["sex"] = pr["sex"]
            V = compose(D, w)
            if st is not None:
                if style_m is not None:
                    st = st + style_m * pr["sex"]
                V = V + st
            hc = K["headb"] + np.array([0, -0.045, 0.02 + (0.02 if a.dist < 0.35 else 0.0)])
            skin = tuple(tone(pr["melanin"]) ** (1 / 1.6))
            vcol = None
            if a.heat and st is not None:
                dn = (st * vertex_normals(V - st, D["F"])).sum(1) / 0.004
                vcol = np.stack([0.6 + 0.4 * np.clip(dn, 0, 1), 0.6 - 0.4 * np.abs(np.clip(dn, -1, 1)),
                                 0.6 + 0.4 * np.clip(-dn, 0, 1)], 1)
            imgs = [render(V, head_tris(D, V), eyes_for(K, w, eye_scale if st is not None else 1.0), v, a.size,
                           skin, hc, dist=a.dist, vcol=vcol) for v in views]
            label = "%s (%s)" % (pr["label"], "style" if st is not None else "realistic")
            rows.append((label, imgs))
    W = a.size * len(views)
    sheet = Image.new("RGB", (W, a.size * len(rows)), (20, 20, 22))
    dr = ImageDraw.Draw(sheet)
    for r, (label, imgs) in enumerate(rows):
        for c, im in enumerate(imgs):
            sheet.paste(im, (c * a.size, r * a.size))
        dr.text((6, r * a.size + 4), label, fill=(240, 240, 240))
    sheet.save(a.out)
    print(a.out, sheet.size)


if __name__ == "__main__":
    main()
