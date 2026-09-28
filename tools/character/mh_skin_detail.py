"""Skin detail of the v3 head (plain python3 + PIL, numpy): the face of the MakeHuman skin textures
(CC0, makehuman_system_assets: photographed skin in the MakeHuman base mesh's UV layout) turned into
assets/character/body/head_detail.png, read by skin.gdshader through the head's MakeHuman UVs
(body.glb TEXCOORD_2 -> CUSTOM0, written by body/body_v3.py).

The user found the v3 head still looked plastic (the procedural pores read as orange peel). The
detail map keeps the creator's own skin tone model and adds the photograph's detail only:

  R  the detail of a young face: the fine band (pores, fine lines, lid and lip texture: the
     luminance over its blur at sigma BLUR px) times the mid band at MID_STRENGTH (the darker lids
     and eye bags, the lip borders, the lighter forehead: the blur at BLUR over the blur at MID),
     0.5 = no change, the ratio / 2
  G  the redness variation (red over luminance, over its blur), 0.5 = none
  B  the fine detail of an older face (wrinkles), as R: blended in by the look's weathering

The young female textures are used (no stubble shadow: the creator's stubble paints that). The
crop is the head's UV rectangle (written to body.json face.detail_rect by the body build as the
same numbers, image space: x right, y down).

    python3 tools/character/mh_skin_detail.py [--src ~/Downloads/Frontier_assets_staging/mpfb/system_assets]
"""

import argparse
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(FRONTIER, "assets", "character", "body", "head_detail.png")
RECT = os.path.join(HERE, "makehuman", "head_uv_rect.json")
SRC = os.path.expanduser("~/Downloads/Frontier_assets_staging/mpfb/system_assets")
YOUNG = "skins/young_caucasian_female/young_lightskinned_female_diffuse.png"
OLD = "skins/old_caucasian_female/old_lightskinned_female_diffuse.png"
BLUR = 7.0
MID = 48.0
MID_STRENGTH = 0.6
SIZE = 1024


def head_uv_rect():
    """The UV rectangle (image space, 0..1) of the MakeHuman head's face and scalp island: the base
    mesh's body faces above the chin line (from tools/character/makehuman/base.obj)."""
    base = os.path.join(HERE, "makehuman", "base.obj")
    V, VT, F = [], [], []
    group = None
    for line in open(base):
        if line.startswith("v "):
            V.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("vt "):
            VT.append([float(x) for x in line.split()[1:3]])
        elif line.startswith("g "):
            group = line.split()[1]
        elif line.startswith("f ") and group == "body":
            F.append([(int(t.split("/")[0]) - 1, int(t.split("/")[1]) - 1) for t in line.split()[1:]])
    V, VT = np.array(V), np.array(VT)
    eye_y = 7.284
    uv = np.array([VT[t] for f in F for v, t in f if V[v, 1] > eye_y - 1.6])
    # the face and scalp island (the right of the atlas); the small islands elsewhere (inner
    # mouth, sockets) take no detail
    uv = uv[uv[:, 0] > 0.55]
    x0, x1 = uv[:, 0].min(), uv[:, 0].max()
    y0, y1 = 1.0 - uv[:, 1].max(), 1.0 - uv[:, 1].min()
    pad = 0.004
    return [max(0.0, x0 - pad), max(0.0, y0 - pad), min(1.0, x1 + pad), min(1.0, y1 + pad)]


def _lum(a):
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    return lin[..., 0] * 0.2126 + lin[..., 1] * 0.7152 + lin[..., 2] * 0.0722, lin


def _blur(x, s):
    """Separable Gaussian blur (edges clamped)."""
    r = int(3 * s + 0.5)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / s) ** 2)
    k /= k.sum()
    p = np.pad(x, r, mode="edge")
    rows = np.stack([np.convolve(row, k, mode="valid") for row in p])
    return np.stack([np.convolve(col, k, mode="valid") for col in rows.T]).T


def detail(path, rect):
    im = Image.open(path).convert("RGB")
    W, H = im.size
    box = (int(rect[0] * W), int(rect[1] * H), int(rect[2] * W), int(rect[3] * H))
    a = np.asarray(im.crop(box), np.float64) / 255.0
    L, lin = _lum(a)
    b1 = _blur(L, BLUR)
    ratio = L / np.maximum(b1, 1e-5)
    mid = b1 / np.maximum(_blur(L, MID), 1e-5)
    ratio = ratio * (1.0 + MID_STRENGTH * (mid - 1.0))
    red = lin[..., 0] / np.maximum(L, 1e-5)
    rv = red / np.maximum(_blur(red, BLUR * 3), 1e-5)
    return np.clip(ratio, 0.0, 2.0) * 0.5, np.clip(rv, 0.0, 2.0) * 0.5


# The whole body (body v4, 2026-09-28): the same channels over MakeHuman's whole UV atlas, and in A the
# areolae and nipples, drawn by us (not a texture): discs round each nipple on the female base mesh
# (the same vertex in every build), in 3D, rasterised into the atlas
BODY_OUT = os.path.join(FRONTIER, "assets", "character", "body", "body_detail.png")
BODY_SIZE = 2048
NIPPLES = (8454, 1782)          # MakeHuman base mesh vertices (the female breasts' apex; the male's nipples too)
AREOLA_R = 0.016                # m on the female base (the man's is a little smaller: the same UV disc)
NIPPLE_R = 0.0045


def _base_mesh():
    """MakeHuman base mesh: positions (female young average, metres), UVs, faces (vertex and UV indices),
    groups."""
    import gzip
    base = os.path.join(HERE, "makehuman", "base.obj")
    V, VT, F, FT, G = [], [], [], [], []
    g = None
    for line in open(base):
        if line.startswith("v "):
            V.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("vt "):
            VT.append([float(x) for x in line.split()[1:3]])
        elif line.startswith("g "):
            g = line.split()[1]
        elif line.startswith("f "):
            t = [x.split("/") for x in line.split()[1:]]
            F.append([int(a[0]) - 1 for a in t])
            FT.append([int(a[1]) - 1 for a in t])
            G.append(g)
    V = np.array(V)
    for name in ("universal-female-young-averagemuscle-averageweight", "caucasian-female-young"):
        path = os.path.join(HERE, "makehuman", "targets", "macrodetails", name + ".target.gz")
        w = 1.0 if name.startswith("universal") else 1.0 / 3.0
        for line in gzip.open(path, "rt"):
            t = line.split()
            if len(t) == 4 and not line.startswith("#"):
                V[int(t[0])] += w * np.array([float(x) for x in t[1:]])
    return V * 0.1, np.array(VT), F, FT, G


def nipple_mask(size):
    """A (size x size, image space): 1 on the nipples, about 0.55 over the areolae, 0 elsewhere."""
    V, VT, F, FT, G = _base_mesh()
    C = V[list(NIPPLES)]
    img = np.zeros((size, size))
    for f, ft, g in zip(F, FT, G):
        if g != "body":
            continue
        P = V[f]
        if np.min(np.linalg.norm(P[:, None, :] - C[None], axis=2)) > AREOLA_R * 2.5:
            continue
        T = VT[ft] * np.array([size, size])
        T[:, 1] = size - T[:, 1]
        for k in range(1, len(f) - 1):
            a, b, c = T[0], T[k], T[k + 1]
            pa, pb, pc = P[0], P[k], P[k + 1]
            lo = np.floor(np.minimum(np.minimum(a, b), c)).astype(int)
            hi = np.ceil(np.maximum(np.maximum(a, b), c)).astype(int)
            xs, ys = np.meshgrid(np.arange(max(lo[0], 0), min(hi[0], size - 1) + 1),
                                 np.arange(max(lo[1], 0), min(hi[1], size - 1) + 1))
            q = np.c_[xs.ravel(), ys.ravel()].astype(float) + 0.5
            m = np.array([[b[0] - a[0], c[0] - a[0]], [b[1] - a[1], c[1] - a[1]]])
            if abs(np.linalg.det(m)) < 1e-9:
                continue
            uv = np.linalg.solve(m, (q - a).T).T
            w = np.c_[1.0 - uv.sum(1), uv]
            ins = (w > -0.01).all(1)
            if not ins.any():
                continue
            X = w[ins] @ np.array([pa, pb, pc])
            d = np.min(np.linalg.norm(X[:, None, :] - C[None], axis=2), axis=1)
            areola = 1.0 - _smooth(AREOLA_R * 0.75, AREOLA_R, d)
            nip = 1.0 - _smooth(NIPPLE_R * 0.6, NIPPLE_R, d)
            val = np.maximum(0.55 * areola, nip)
            qi = q[ins].astype(int)
            img[qi[:, 1], qi[:, 0]] = np.maximum(img[qi[:, 1], qi[:, 0]], val)
    return img


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def body_detail(src):
    rect = [0.0, 0.0, 1.0, 1.0]
    young, red = detail(os.path.join(src, YOUNG), rect)
    old, _ = detail(os.path.join(src, OLD), rect)
    a = nipple_mask(young.shape[0])
    rgb = np.dstack([young, red, old, a])
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8))
    if img.size[0] != BODY_SIZE:
        img = img.resize((BODY_SIZE, BODY_SIZE), Image.LANCZOS)
    img.save(BODY_OUT, optimize=True)
    print(BODY_OUT, "areola texels", int((a > 0.3).sum()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC)
    ap.add_argument("--body", action="store_true", help="also the whole body's map (body_detail.png)")
    a = ap.parse_args()
    src = os.path.expanduser(a.src)
    if a.body:
        body_detail(src)
    rect = head_uv_rect()
    young, red = detail(os.path.join(src, YOUNG), rect)
    old, _ = detail(os.path.join(src, OLD), rect)
    rgb = np.dstack([young, red, old, np.ones_like(young)])
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)).resize((SIZE, SIZE), Image.LANCZOS)
    img.save(OUT, optimize=True)
    with open(RECT, "w") as f:
        json.dump({"rect": [round(x, 5) for x in rect], "note": "image space (x right, y down) of the MakeHuman head's UVs",
                   "source": [YOUNG, OLD]}, f, indent=1)
    print(OUT, "rect", [round(x, 4) for x in rect])


if __name__ == "__main__":
    main()
