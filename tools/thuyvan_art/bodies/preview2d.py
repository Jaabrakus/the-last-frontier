"""Quick software previews (plain python3 + PIL): orthographic, painter's order, lambert grey. Only for drafting
shapes outside the Blender lock; the owner's renders are Blender Eevee (render_bodies.py)."""

import math

import numpy as np
from PIL import Image, ImageDraw

VIEWS = {"front": 0.0, "34": -35.0, "side": -90.0, "back": 180.0, "34back": 145.0}


def rot_z(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def draw(meshes, view="front", px_per_m=300, size=(700, 700), origin=(350, 650), bg=(236, 228, 212), img=None,
         light=(-0.5, -0.8, 0.6)):
    """meshes: [(V, F, rgb)]. The camera looks along +y (at the character's front) after rotating the scene by
    the view's angle about z."""
    if img is None:
        img = Image.new("RGB", size, bg)
    d = ImageDraw.Draw(img)
    R = rot_z(VIEWS.get(view, view) if isinstance(view, str) else view)
    L = np.asarray(light, float)
    L = L / np.linalg.norm(L)
    tris, cols, depth = [], [], []
    for V, F, rgb in meshes:
        X = np.asarray(V, float) @ R.T
        T = X[F]
        n = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
        nl = np.linalg.norm(n, axis=1)
        ok = nl > 1e-12
        n[ok] /= nl[ok, None]
        shade = 0.35 + 0.65 * np.clip(n @ L * 0.8 + 0.2, 0, 1)
        vis = n[:, 1] < 0.05                      # faces toward the camera (camera at -y)
        T, shade = T[vis & ok], shade[vis & ok]
        tris.append(T)
        cols.append(np.clip(np.asarray(rgb)[None, :] * shade[:, None], 0, 255))
        depth.append(T[:, :, 1].mean(1))
    T = np.concatenate(tris)
    C = np.concatenate(cols).astype(int)
    D = np.concatenate(depth)
    order = np.argsort(-D)
    ox, oy = origin
    P2 = np.stack([ox + T[:, :, 0] * px_per_m, oy - T[:, :, 2] * px_per_m], 2)
    for i in order:
        p = P2[i]
        d.polygon([(p[0, 0], p[0, 1]), (p[1, 0], p[1, 1]), (p[2, 0], p[2, 1])], fill=tuple(C[i]))
    return img


def silhouette(meshes, view="front", px=64):
    img = draw([(V, F, (0, 0, 0)) for V, F, _ in meshes], view, px_per_m=px / 1.9, size=(px, px),
               origin=(px // 2, px - 2), bg=(255, 255, 255), light=(0, -1, 0))
    return img
