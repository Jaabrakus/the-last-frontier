"""Body hair (2026-09-28): pubic hair of our own strands for the bare body v4.

The user asked for it with the anatomically complete bodies ("add pubic hair as well"): natural, as every
adult of the period had it. Built with the body (body_v4.build), one part per body type, each grown on its
own fit with the hair v3 strand builder (hair/_strands.py: short coily strips of the strand atlas, lying
close with springy curls over them), skinned like the body under it:

  assets/character/body/body_hair_f.glb   the women's: a triangle on the mons, its top edge level and soft,
                                          ending above the vulva
  assets/character/body/body_hair_m.glb   the men's: above the root of the genitals up the lower belly,
                                          wider at the top, and a thin line toward the navel
  assets/character/body/body_hair_mask.png  the same patterns (R women, G men) over MakeHuman's UV atlas:
                                          skin.gdshader tints the skin under the strips with the hair's
                                          root colour (as the scalp under a style), so the gaps read as roots

Each glb is at its own fit (no `sex` shape: a body shows the part of its type). The surface is
"body_hair_tex" (hair_tex.gdshader, the atlas's coily slot; BodyMaterials.body_hair_material).
"""

import math
import os
import struct
import zlib

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from hair import _strands as S
from lib import regions as RG
from lib.context import ASSETS
from lib.pipeline import write_import
from lib.rig import export_glb
from lib.sdf import log, nrm, smoothstep, v3
from lib.weights import limit_normalize, write_groups
from lib.wrap import Surface

OUT = os.path.join(ASSETS, "body")
MASK = os.path.join(OUT, "body_hair_mask.png")
MASK_SIZE = 1024
SURFACE = "body_hair_tex"
# strand layers: (count, width m, length m, offset off the skin at the root / a third along, taper, step)
LAYERS = {"f": [(300, 0.006, 0.020, (0.0008, 0.0025), 0.3, 0.004), (150, 0.008, 0.026, (0.002, 0.0065), 0.35, 0.005)],
          "m": [(340, 0.006, 0.022, (0.0008, 0.0025), 0.3, 0.004), (170, 0.008, 0.028, (0.002, 0.007), 0.35, 0.005)]}
CURL = (0.8, 420.0)          # the strands' swirl: its share of the flow, its frequency (rad / m)


# ---------------------------------------------------------------------------------------------
# where it grows (0..1), Blender space (x sideways, -y front, z up)

def density_f(frame):
    """The women's pattern, from the vulva frame (body_v4._vulva_frame: s along the crotch midline from
    the anterior commissure, u sideways, h off the midline profile): on the mons only, above the vulva
    (the user: "we want it above")."""
    def d(X):
        s, u, h, s_end = frame(X)
        au = np.abs(u)
        # a triangle widening upward, its top edge level (a little lower at the corners), soft; its foot
        # ends above the cleft
        top = -0.072 + 0.012 * (au / 0.06) ** 2
        wl = np.clip(0.014 + 0.72 * np.maximum(-s, 0.0), 0.014, 0.062)
        mons = (smoothstep(top, top + 0.014, s) * (1.0 - smoothstep(-0.016, -0.006, s))
                * (1.0 - smoothstep(wl - 0.014, wl, au)))
        return np.clip(mons, 0.0, 1.0) * (h < 0.035)
    return d


def density_m(root):
    """The men's pattern: above the root of the genitals (`root`, Blender space) up the lower belly, wider
    at the top, and a thin line toward the navel; none round or below the root."""
    def d(X):
        x, y, z = X[:, 0], X[:, 1], X[:, 2]
        ax = np.abs(x)
        zb, zt = root[2] + 0.004, root[2] + 0.078
        top = zt - 0.01 * (ax / 0.07) ** 2
        wl = np.clip(0.026 + 0.55 * (z - zb), 0.026, 0.068)
        low = smoothstep(zb, zb + 0.014, z) * (1.0 - smoothstep(top - 0.012, top, z))
        tri = low * (1.0 - smoothstep(wl - 0.014, wl, ax))
        trail = (smoothstep(top - 0.02, top, z) * (1.0 - smoothstep(zt + 0.03, zt + 0.07, z))
                 * (1.0 - smoothstep(0.003, 0.007, ax)) * 0.3)
        front = y < root[1] + 0.035
        return np.clip(np.maximum(tri, trail), 0.0, 1.0) * front
    return d


def flow_hair(root_x=0.0, back=0.3):
    """Down and in toward the midline (back, along the labia underneath), swirled into curls."""
    share, k = CURL

    def f(q, n):
        ax = abs(q[0] - root_x)
        sx = math.copysign(1.0, q[0] - root_x) if ax > 1e-4 else 0.0
        base = nrm(v3(-sx * 0.35 * min(1.0, ax / 0.02), back, -1.0))
        sw = v3(math.sin(q[2] * k + q[0] * 1.3 * k), math.cos(q[0] * k + q[1] * 1.7 * k), math.sin((q[1] + q[2]) * k))
        return S._tangent(base + share * sw, n)
    return f


class Skin:
    """The body surface where hair grows: nearest point and normal, density-weighted samples (the
    Scalp's interface for hair/_strands.grow)."""

    def __init__(self, V, F, dens):
        C = V[F].mean(1)
        dc = np.maximum(dens(C), dens(V[F].reshape(-1, 3)).reshape(-1, 3).max(1))
        keep = dc > 0.01
        self.V, self.F = V, F[keep]
        self.d = dens(C[keep])
        self.bvh = BVHTree.FromPolygons([tuple(v) for v in V], [tuple(t) for t in self.F], all_triangles=True)
        a, b, c = V[self.F[:, 0]], V[self.F[:, 1]], V[self.F[:, 2]]
        self.area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)

    def nearest(self, p):
        q, n, _, _ = self.bvh.find_nearest(Vector(p))
        return np.array(q), np.array(n)

    def sample(self, n, rng):
        w = self.area * self.d
        pick = rng.choice(len(self.F), size=n, p=w / w.sum())
        r1, r2 = rng.random(n), rng.random(n)
        s = np.sqrt(r1)
        a, b, c = self.V[self.F[pick, 0]], self.V[self.F[pick, 1]], self.V[self.F[pick, 2]]
        return a * (1 - s)[:, None] + b * (s * (1 - r2))[:, None] + c * (s * r2)[:, None]


def grow_part(tag, V, F, dens, flow, seed):
    skin = Skin(V, F, dens)
    rng = np.random.default_rng(seed)
    b = S.Builder("body_hair_" + tag)
    inside = (lambda Q: dens(Q) > 0.03)
    for count, width, length, off, taper, step in LAYERS[tag]:
        for p0 in skin.sample(count, rng):
            # sparser toward the pattern's edge: a seed there grows with its density's chance
            if rng.random() > 0.35 + 0.65 * float(dens(p0[None])[0]):
                continue
            L = length * (1.0 - 0.3 * rng.random())
            pts, nrms = S.grow(skin, p0, flow, L, step=step, off=off, rng=rng, inside=inside)
            b.strip(pts, nrms, width * rng.uniform(0.8, 1.2), "coily", rng, taper=taper, root_len=0.004)
    return b


def _weights_at(P, V, F, W):
    tri, bary, _, _ = Surface(V, F).nearest(P)
    return limit_normalize(np.einsum("ij,ijk->ik", bary, W[F[tri]]))


def _png_rgb(path, a):
    a = np.ascontiguousarray(a, np.uint8)
    raw = b"".join(b"\x00" + a[i].tobytes() for i in range(a.shape[0]))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", a.shape[1], a.shape[0], 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


def bake_mask(Vs, Ft, Ft_uv, dens, size=MASK_SIZE):
    """The patterns over MakeHuman's UV atlas: channel k from the MakeHuman triangles Ft (their corner UVs
    Ft_uv) at the positions Vs[k] (the fitted MakeHuman vertices of each body type) through dens[k]."""
    img = np.zeros((size, size, 3), np.float32)
    for k, (V, dfun) in enumerate(zip(Vs, dens)):
        dc = dfun(V[Ft].reshape(-1, 3)).reshape(-1, 3)
        C = V[Ft].mean(1)
        near = (dc.max(1) > 0.0) | (dfun(C) > 0.0)
        # and their neighbours' reach: any triangle within 2 cm of a hairy one
        hot = C[near]
        if len(hot):
            from mathutils.kdtree import KDTree
            kd = KDTree(len(hot))
            for i, c in enumerate(hot):
                kd.insert(Vector(c), i)
            kd.balance()
            near |= np.array([kd.find(Vector(c))[2] < 0.02 for c in C])
        for t in np.nonzero(near)[0]:
            uv = Ft_uv[t] * size
            px = np.stack([uv[:, 0], (1.0 - Ft_uv[t][:, 1]) * size], 1)
            x0, y0 = np.floor(px.min(0)).astype(int)
            x1, y1 = np.ceil(px.max(0)).astype(int)
            x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, size - 1), min(y1, size - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            G = np.stack([gx.ravel(), gy.ravel()], 1)
            a, b, c = px
            m = np.array([[b[0] - a[0], c[0] - a[0]], [b[1] - a[1], c[1] - a[1]]])
            if abs(np.linalg.det(m)) < 1e-12:
                continue
            l12 = np.linalg.solve(m, (G - a).T).T
            bary = np.stack([1.0 - l12.sum(1), l12[:, 0], l12[:, 1]], 1)
            ok = (bary > -0.02).all(1)
            if not ok.any():
                continue
            P = bary[ok] @ V[Ft[t]]
            xs, ys = G[ok, 0].astype(int), G[ok, 1].astype(int)
            img[ys, xs, k] = np.maximum(img[ys, xs, k], dfun(P))
    _png_rgb(MASK, np.clip(img * 255.0 + 0.5, 0, 255))
    log("  body hair mask %s: women %d, men %d texels" % (os.path.relpath(MASK, ASSETS), int((img[..., 0] > 0.05).sum()),
                                                             int((img[..., 1] > 0.05).sum())))


def export_part(ctx, tag, b, V, F, W):
    ob, _ = b.object()
    me = ob.data
    P = np.array([tuple(v.co) for v in me.vertices])
    Wp = _weights_at(P, V, F, W)
    lv = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv)
    codes = np.full(len(me.polygons), RG.encode("pelvis_center"))
    RG.write_region_uv(ob, codes, "Region", np.asarray(b.across, float)[lv])
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.ones(len(me.vertices) * 4, np.float32))
    me.color_attributes.active_color = attr
    write_groups(ob, Wp, ctx.bones)
    mat = bpy.data.materials.get(SURFACE) or bpy.data.materials.new(SURFACE)
    me.materials.clear()
    me.materials.append(mat)
    rig = ctx.bind_rig()
    ob.parent = rig
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    used = {vg.name for vg in ob.vertex_groups}
    for bn in rig.data.bones:
        if bn.name in used:
            bn.use_deform = True
    glb = os.path.join(OUT, "body_hair_%s.glb" % tag)
    export_glb(rig, [ob], glb, texcoords=True)
    write_import(glb)
    log("  body hair %s: %d quads (%d tris) -> %s" % (tag, len(b.F), 2 * len(b.F), os.path.relpath(glb, ASSETS)))
    ob.hide_render = True
    return ob


def build(ctx, V, Vm, F, W, is_gen, frame, root, Vf_mh, Vm_mh, Ft, Ft_uv):
    """V / Vm: the body's female base and male positions (faces F, weights W; is_gen: the genital
    vertices, no hair grows on them); frame(X): the vulva frame; root: the male genitals' root (Blender
    space); Vf_mh / Vm_mh, Ft, Ft_uv: the fitted MakeHuman surface of each type and its UVs (the mask)."""
    Fb = F[~is_gen[F].any(1)]
    df, dm = density_f(frame), density_m(root)
    for tag, Vx, dens, flow, seed in (("f", V, df, flow_hair(0.0, 0.35), 11), ("m", Vm, dm, flow_hair(root[0], 0.15), 12)):
        b = grow_part(tag, Vx, Fb, dens, flow, seed)
        export_part(ctx, tag, b, Vx, F, W)
    bake_mask((Vf_mh, Vm_mh), Ft, Ft_uv, (df, dm))
