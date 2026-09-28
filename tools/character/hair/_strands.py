"""Hair v3 (2026-09-28): strand strips of our own, grown over the v3 head.

The user asked for every hair style rebuilt with our own hair, true to the period ("remove all the
legacy hair and recreate with our custom hair, accurate time period"). A style is strips of the
strand atlas (tools/character/hair_atlas.py: drawn strands, the project's own) laid along strands
grown over the scalp:

  scalp    the v3 head and neck of the body cache (the scalp the hats fit)
  grows    where hair grows: behind the front hairline plane, off the ears, above the nape
  flow     the combing direction at a scalp point (back to a gather point, down from a parting,
           out from the crown whorl, up to a topknot), always in the scalp's tangent plane
  layers   (offset off the scalp, atlas slot, strips, width, length): a dense base, clumped strips
           over it, fine strands on top; each strip bends along its strand, its plane tangent to
           the scalp, the width tapering to the tip
  fall     past the head a strand falls with gravity, kept off the body (its SDF) by a clearance
  tails    queues, ponytails and braids: a ring of strips round a path (the braid slot for a
           plait), on the pendulum like the v1 tails
  accents  the v1 ribbons, cords and ornaments (SDF pieces, surface <id>, the hair shader's zones)

The strips are surface "<id>_tex" (hair_tex.gdshader with the atlas); the part pipeline gives them
the body's sex, sex_head and face shapes and hat_fit, as every style.
"""

import json
import math
import os
import struct
import zlib

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from hair import _common as H
from lib.context import ASSETS
from lib.pipeline import Surface, body_weights_at
from lib.remesh import mesh_arrays
from lib.sdf import log, nrm, peval, smoothstep, v3
from lib.weights import mesh_adjacency, smooth_weights

ATLAS = "res://assets/character/hair/tex/hair_atlas.png"
SLOTS = 8
SLOT = {"dense": 0, "clumps": 1, "fine": 2, "wavy": 3, "coily": 4, "braid": 5, "crop": 6, "tail": 7}
# metres of hair along one card (v 0..1); the tiling slots repeat along v (a plait lobe every 22 mm,
# coils a millimetre or two across)
CARD_M = {"dense": 0.36, "clumps": 0.42, "fine": 0.42, "wavy": 0.42, "coily": 0.45, "braid": 0.36, "crop": 0.36,
          "tail": 0.36}
TILES = {"coily", "braid"}
FALL_STEP = 1.8           # the step of a falling strand, times the layer's step
EDGE_FEATHER = 0.3        # the share of a strip's width feathered in from each edge (hair_tex.gdshader)
DOWN = v3(0, 0, -1)


class Scalp:
    """The v3 head and neck of the body cache: nearest point and normal, area-weighted samples."""

    def __init__(self, ctx):
        body = ctx.body()
        F = body.F
        lab = body.vlab
        C = body.V[F].mean(1)
        keep = np.isin(lab[F[:, 0]], ["head", "neck"]) & (C[:, 2] > 1.33)
        self.V = body.V
        self.F = F[keep]
        self.bvh = BVHTree.FromPolygons([tuple(v) for v in self.V], [tuple(t) for t in self.F], all_triangles=True)
        a, b, c = self.V[self.F[:, 0]], self.V[self.F[:, 1]], self.V[self.F[:, 2]]
        self.area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
        self.C = (a + b + c) / 3.0

    def nearest(self, p):
        q, n, _, _ = self.bvh.find_nearest(Vector(p))
        return np.array(q), np.array(n)

    def sample(self, n, ok, rng):
        m = ok(self.C)
        idx = np.nonzero(m)[0]
        w = self.area[idx] / self.area[idx].sum()
        pick = rng.choice(idx, size=n, p=w)
        r1, r2 = rng.random(n), rng.random(n)
        s = np.sqrt(r1)
        a, b, c = self.V[self.F[pick, 0]], self.V[self.F[pick, 1]], self.V[self.F[pick, 2]]
        return a * (1 - s)[:, None] + b * (s * (1 - r2))[:, None] + c * (s * r2)[:, None]


# The natural hairline of the v3 head (the body cache's female base; the sex and face shapes carry it
# with the head): height (m) by the angle (degrees) about the head's vertical axis at y = AXIS_Y from
# the front: the forehead, the temple corner, the temple down to the sideburn in front of the ear, the
# ear, behind it, the nape. Drawn on the head against the face's proportions (hairline to brow about
# the brow to the nose base), 2026-09-28.
AXIS_Y = -0.025
HAIRLINE = [(0, 1.556), (22, 1.554), (38, 1.548), (46, 1.537), (51, 1.515), (55, 1.490), (59, 1.468), (63, 1.454),
            (71, 1.452), (75, 1.490), (106, 1.490), (112, 1.458), (122, 1.430), (136, 1.405), (150, 1.396),
            (180, 1.393)]
# the ear's root (an ellipsoid a few millimetres round it: no hair grows on the ear)
EAR_C, EAR_R = v3(0.080, -0.023, 1.461), v3(0.022, 0.018, 0.033)


def head_angle(P):
    """Degrees about the head's axis from the front (0) to the back (180), both sides alike."""
    P = np.atleast_2d(np.asarray(P, float))
    return np.degrees(np.arctan2(np.abs(P[:, 0]), -(P[:, 1] - AXIS_Y)))


class Domain:
    """Where hair grows, as a signed distance (m, > 0 inside): above the hairline (its front raised by
    `front` m: a receding or shaved forehead; the nape at least `nape`), off the ears; `extra(P) -> m`
    (> 0 inside) narrows it (a scalp lock, a shaved crown). Calling it gives the boolean mask."""

    def __init__(self, front=0.0, nape=None, ear_margin=0.0, extra=None, irregular=True):
        self.front, self.nape, self.ear_margin, self.extra, self.irregular = front, nape, ear_margin, extra, irregular

    def hairline(self, phi):
        k = np.array(HAIRLINE)
        hl = np.interp(phi, k[:, 0], k[:, 1])
        hl = hl + self.front * (1.0 - smoothstep(40.0, 64.0, phi))
        if self.nape is not None:
            hl = np.where(phi > 110.0, np.maximum(hl, self.nape), hl)
        if self.irregular:
            # a hairline is never a clean line: small, fixed irregularities along it
            r = np.radians(phi)
            hl = hl + 0.0018 * np.sin(r * 23.0 + 0.4) + 0.0012 * np.sin(r * 61.0 + 2.1)
        return hl

    def sd(self, P):
        P = np.atleast_2d(np.asarray(P, float))
        d = P[:, 2] - self.hairline(head_angle(P))
        q = (np.c_[np.abs(P[:, 0]), P[:, 1], P[:, 2]] - EAR_C) / EAR_R
        d = np.minimum(d, (np.linalg.norm(q, axis=1) - 1.0) * float(EAR_R.min()) - self.ear_margin)
        if self.extra is not None:
            d = np.minimum(d, self.extra(P))
        return d

    def __call__(self, P):
        return self.sd(P) > 0.0


def grows(K=None, front=0.0, nape=None, ear_margin=0.0, extra=None):
    """The style's Domain (K unused: the hairline is the v3 head's own)."""
    return Domain(front=front, nape=nape, ear_margin=ear_margin, extra=extra)


MASK_SIZE = 512
# the tint under the strips: full a few millimetres inside the hairline, none a few outside
MASK_EDGE = (-0.003, 0.007)


def _glb_body():
    """The body's triangles from assets/character/body/body.glb that carry the head's MakeHuman UVs
    (TEXCOORD_2, image space: x right, y down): (positions in Blender space, UVs, triangles)."""
    path = os.path.join(ASSETS, "body", "body.glb")
    b = open(path, "rb").read()
    n = struct.unpack_from("<I", b, 12)[0]
    js = json.loads(b[20:20 + n])
    blob = b[20 + n + 8:]
    ct = {5126: np.float32, 5123: np.uint16, 5125: np.uint32}
    nc = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}

    def acc(i):
        a = js["accessors"][i]
        bv = js["bufferViews"][a["bufferView"]]
        dt, k = np.dtype(ct[a["componentType"]]), nc[a["type"]]
        o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        st = bv.get("byteStride", 0) or dt.itemsize * k
        raw = np.frombuffer(blob, np.uint8, count=st * (a["count"] - 1) + dt.itemsize * k, offset=o)
        idx = (np.arange(a["count"])[:, None] * st + np.arange(dt.itemsize * k)[None, :])
        return raw[idx].copy().view(dt).reshape(a["count"], k)

    for m in js["meshes"]:
        for pr in m["primitives"]:
            at = pr["attributes"]
            if "TEXCOORD_2" in at:
                P = acc(at["POSITION"]).astype(float)
                T = acc(at["TEXCOORD_2"]).astype(float)
                I = acc(pr["indices"]).reshape(-1, 3).astype(int)
                I = I[(T[I][:, :, 0] >= 0.0).all(1)]
                return np.c_[P[:, 0], -P[:, 2], P[:, 1]], T, I
    raise SystemExit("body.glb has no MakeHuman UVs (TEXCOORD_2): rebuild the body")


def _png_gray(path, a):
    a = np.ascontiguousarray(a, np.uint8)
    raw = b"".join(b"\x00" + a[i].tobytes() for i in range(a.shape[0]))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", a.shape[1], a.shape[0], 8, 0, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


def scalp_mask(style_id, domain):
    """The scalp under the style (the domain), baked into the head's MakeHuman UV rectangle (body.json
    face.detail_rect, as head_detail.png): skin.gdshader tints it with the hair's root colour, so the
    skin between the strips reads as dense roots and the hairline fades in over a few millimetres.
    Writes assets/character/hair/tex/<id>_scalp.png; returns its res:// path."""
    rect = json.load(open(os.path.join(ASSETS, "body", "body.json")))["face"]["detail_rect"]
    P, T, I = _glb_body()
    S = MASK_SIZE
    px = np.c_[(T[:, 0] - rect[0]) / (rect[2] - rect[0]), (T[:, 1] - rect[1]) / (rect[3] - rect[1])] * S - 0.5
    pts, pix = [], []
    for f in I:
        a, b, c = px[f]
        lo = np.floor(np.minimum(np.minimum(a, b), c)).astype(int)
        hi = np.ceil(np.maximum(np.maximum(a, b), c)).astype(int)
        xs, ys = np.meshgrid(np.arange(max(lo[0], 0), min(hi[0], S - 1) + 1), np.arange(max(lo[1], 0), min(hi[1], S - 1) + 1))
        q = np.c_[xs.ravel(), ys.ravel()].astype(float)
        if not len(q):
            continue
        m = np.array([[b[0] - a[0], c[0] - a[0]], [b[1] - a[1], c[1] - a[1]]])
        det = np.linalg.det(m)
        if abs(det) < 1e-12:
            continue
        uv = np.linalg.solve(m, (q - a).T).T
        w = np.c_[1.0 - uv.sum(1), uv]
        inside = (w > -0.02).all(1)
        if not inside.any():
            continue
        w = np.clip(w[inside], 0.0, None)
        w /= w.sum(1)[:, None]
        pts.append(w @ P[f])
        pix.append(q[inside].astype(int))
    pts, pix = np.concatenate(pts), np.concatenate(pix)
    val = smoothstep(MASK_EDGE[0], MASK_EDGE[1], domain.sd(pts))
    img = np.full((S, S), -1.0)
    img[pix[:, 1], pix[:, 0]] = val
    # bleed the islands' edges outward (bilinear filtering and mipmaps read past them)
    for _ in range(6):
        e = img < 0
        if not e.any():
            break
        pad = np.pad(img, 1, constant_values=-1.0)
        nb = np.stack([pad[1 + dy:S + 1 + dy, 1 + dx:S + 1 + dx] for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1))])
        filled = np.where(nb >= 0, nb, 0.0).sum(0) / np.maximum((nb >= 0).sum(0), 1)
        grow = e & (nb >= 0).any(0)
        img[grow] = filled[grow]
    img = np.clip(img, 0.0, 1.0)
    out = os.path.join(ASSETS, "hair", "tex", style_id + "_scalp.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    _png_gray(out, np.round(img * 255.0))
    log("  %s: scalp mask %d px, %.0f%% of the head" % (style_id, S, 100.0 * float((val > 0.5).mean())))
    return "res://assets/character/hair/tex/%s_scalp.png" % style_id


def _tangent(d, n):
    t = d - n * (d @ n)
    L = np.linalg.norm(t)
    return t / L if L > 1e-9 else None


def flow_to(G):
    """Combed toward the point G (a queue at the nape, a knot on the crown)."""
    G = np.asarray(G, float)
    return lambda q, n: _tangent(G - q, n)


def flow_parted(part_x=0.0, back=0.25, down=0.8):
    """Parted at x = part_x: away from the parting and down (a little back) on the front of the head;
    behind the crown straight down and back (no parting there: it opened a gap at the nape)."""
    def f(q, n):
        s = 1.0 if q[0] >= part_x else -1.0
        side = smoothstep(0.0, 0.02, abs(q[0] - part_x))
        front = 1.0 - smoothstep(-0.03, 0.03, q[1])
        return _tangent(v3(s * (0.35 + 0.65 * side) * front, back, -down), n)
    return f


def flow_dir(d):
    """Combed one way (e.g. straight back from the forehead), in the scalp's tangent plane."""
    d = nrm(np.asarray(d, float))
    return lambda q, n: _tangent(d, n)


def flow_whorl(W, down=0.35):
    """Out from the crown whorl W and a little down (a short crop)."""
    W = np.asarray(W, float)
    return lambda q, n: _tangent(nrm(q - W) + v3(0, 0, -down), n)


def grow(scalp, p0, flow, length, step=0.006, off=(0.0015, 0.004), gather=None, gather_r=0.01, fall=None, sdf=None,
         clearance=0.012, rng=None, inside=None):
    """The strand from p0: along `flow` on the scalp at the layer's offset; stops within gather_r
    of `gather`; with `fall`, past the head (below fall z, or off the scalp) it falls with gravity
    kept `clearance` off the body SDF; with `inside(P)`, a strand on the scalp stops where it would
    leave the hair's domain (no strip over the forehead, a cheek or an ear). Returns (points, normals)."""
    pts, nrms = [], []
    p = np.asarray(p0, float)
    L = 0.0
    free = False
    prev = None
    jitter = (rng.normal(size=3) * 0.15) if rng is not None else np.zeros(3)
    if gather is not None:
        # a gathered strand leaves the scalp over its last `lift` metres to the tie (off the scalp)
        gather = np.asarray(gather, float)
        gs, _ = scalp.nearest(gather)
        lift = max(0.02, 1.4 * float(np.linalg.norm(gather - gs)))
    while L <= length:
        if not free:
            q, n = scalp.nearest(p)
            t = L / max(length, 1e-6)
            o = off[0] + (off[1] - off[0]) * min(1.0, t * 3.0)
            pos = q + n * o
            d = flow(q, n)
            if d is None:
                break
            d = nrm(d + jitter * (0.3 if L > 0.01 else 0.0) - n * ((d + jitter) @ n))
            if gather is not None:
                w = float(smoothstep(lift, 0.0, np.linalg.norm(q - gs)))
                pos = pos + (gather - pos) * w * w * (3 - 2 * w) * 0.9
            pts.append(pos)
            nrms.append(n)
            if gather is not None and (np.linalg.norm(pos - gather) < gather_r or np.linalg.norm(q - gs) < 0.004):
                break
            if inside is not None and L > 0.0 and not inside(q[None])[0]:
                pts.pop()
                nrms.pop()
                break
            if fall is not None and (q[2] < fall or np.linalg.norm(p - q) > 0.02):
                free = True
                prev = d
                p = pos
            else:
                p = q + d * step
        else:
            d = nrm(prev * 0.6 + DOWN * 0.4)
            prev = d
            # hanging hair is nearly straight: longer steps (fewer quads)
            p = p + d * step * FALL_STEP
            if sdf is not None:
                dd = float(peval(sdf, p[None])[0])
                if dd < clearance:
                    h = 4e-4
                    g = np.array([(peval(sdf, (p + e * h)[None])[0] - peval(sdf, (p - e * h)[None])[0]) for e in np.eye(3)])
                    g = nrm(g)
                    p = p + g * (clearance - dd)
                    nn = g
                else:
                    nn = nrms[-1] if nrms else v3(0, 1, 0)
            else:
                nn = nrms[-1]
            pts.append(p.copy())
            nrms.append(nn)
        L += step * (FALL_STEP if free else 1.0)
    return np.array(pts), np.array(nrms)


class Builder:
    """Collects strips (vertices, quads, UVs, a tail flag) and makes the Blender object."""

    def __init__(self, name):
        self.name = name
        self.V, self.F, self.UV, self.tail, self.across = [], [], [], [], []

    def strip(self, pts, nrms, width, slot, rng, taper=0.55, tail=False, u_window=0.55, v0=None, flip=False,
              root_len=0.02):
        n = len(pts)
        if n < 2:
            return
        s0 = SLOT[slot] / SLOTS
        sw = 1.0 / SLOTS
        uw = sw * u_window
        ua = s0 + sw * 0.03 + rng.uniform(0, sw * 0.94 - uw)
        ub = ua + uw
        if flip:
            ua, ub = ub, ua
        seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        arc = np.concatenate([[0], np.cumsum(seg)])
        vv = (rng.uniform(0.0, 0.12) if v0 is None else v0) + arc / CARD_M[slot]
        if slot not in TILES:
            vv = np.minimum(vv, 0.995)
        base = len(self.V)
        for i in range(n):
            t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
            t = t / max(np.linalg.norm(t), 1e-9)
            side = np.cross(t, nrms[i])
            L = np.linalg.norm(side)
            side = side / L if L > 1e-9 else v3(1, 0, 0)
            w = width * (1.0 - taper * (i / max(n - 1, 1)) ** 1.5)
            # the root comes to a point over its first root_len metres (no hard strip end at a hairline)
            w *= 0.25 + 0.75 * smoothstep(0.0, root_len, arc[i]) if root_len > 0 else 1.0
            self.V += [pts[i] - side * w * 0.5, pts[i] + side * w * 0.5]
            self.UV += [(ua, vv[i]), (ub, vv[i])]
            self.tail += [tail, tail]
            self.across += [0.0, 1.0]
        for i in range(n - 1):
            a = base + 2 * i
            self.F.append((a, a + 1, a + 3, a + 2))

    def ring(self, axis, radii, count, slot, rng, width_scale=1.35, tail=True, u_window=0.8, twist=0.0, aspect=1.0,
             jitter=0.0):
        """Strips round the path `axis` (a queue, a ponytail, a braid); `aspect` > 1 flattens the section
        (wider across the body: a flat club), `jitter` (m) loosens it (a loosely tied tail)."""
        A = np.asarray(axis, float)
        R = np.asarray(radii, float)
        for k in range(count):
            th = 2 * math.pi * k / count + rng.uniform(-0.15, 0.15)
            dr = rng.uniform(-jitter, jitter, len(A)) if jitter > 0 else np.zeros(len(A))
            pts, nrms = [], []
            for i in range(len(A)):
                t = A[min(i + 1, len(A) - 1)] - A[max(i - 1, 0)]
                t = nrm(t)
                e1 = nrm(np.cross(t, v3(1, 0, 0)))
                e2 = np.cross(t, e1)
                a = th + twist * i / max(len(A) - 1, 1)
                pts.append(A[i] + (e1 * math.cos(a) + e2 * math.sin(a) * aspect) * (R[i] + dr[i]))
                nrms.append(nrm(e1 * math.cos(a) + e2 * math.sin(a) / aspect))
            w = 2 * math.pi * float(R.mean()) * (1.0 + aspect) * 0.5 / count * width_scale
            self.strip(np.array(pts), np.array(nrms), w, slot, rng, taper=0.35, tail=tail, u_window=u_window, root_len=0.0)

    def coil(self, center, radii, rng, rings=12, slot="clumps", turns=1.08):
        """A bun: hair wrapped round it on an ellipsoid (radii x, y, z), each layer round its own tilted
        axis (the wraps cross, as a twisted knot's do; wrapped round one axis it read as a flat coil)."""
        c = np.asarray(center, float)
        R = np.asarray(radii, float)
        layers = ((0.0, "dense", nrm(v3(1.0, 0.25, 0.55))), (0.0025, slot, nrm(v3(-0.9, 0.3, 0.6))),
                  (0.0045, "fine", nrm(v3(0.35, 0.2, 1.0))))
        for layer_i, (off, sl, ax) in enumerate(layers):
            e1 = nrm(np.cross(ax, v3(0.0, 1.0, 0.0)) if abs(ax[1]) < 0.9 else np.cross(ax, v3(1.0, 0.0, 0.0)))
            e2 = np.cross(ax, e1)
            for k in range(rings):
                sa = -0.82 + 1.64 * (k + 0.5 * (layer_i % 2)) / rings
                ring = math.sqrt(max(1.0 - sa * sa, 0.02))
                th = rng.uniform(0, 2 * math.pi) + np.linspace(0.0, 2 * math.pi * turns, 28)
                D = ax[None, :] * sa + (e1[None, :] * np.cos(th)[:, None] + e2[None, :] * np.sin(th)[:, None]) * ring
                t = 1.0 / np.sqrt(((D / R) ** 2).sum(1))
                P = D * t[:, None]
                Nn = P / R ** 2
                Nn /= np.linalg.norm(Nn, axis=1)[:, None]
                P = c + P + Nn * off
                w = 2.0 * float(R.mean()) * 1.5 / rings * (0.75 + 0.25 * ring)
                self.strip(P, Nn, w, sl, rng, taper=0.25, root_len=0.0)

    def object(self):
        me = bpy.data.meshes.new(self.name)
        me.from_pydata([tuple(p) for p in self.V], [], self.F)
        me.update()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = True
        lay = me.uv_layers.new(name="UVMap")
        uv = np.zeros((len(me.loops), 2), np.float32)
        UV = np.array(self.UV)
        for p in me.polygons:
            for li in range(p.loop_start, p.loop_start + p.loop_total):
                uv[li] = UV[me.loops[li].vertex_index]
        # the atlas has the root at the top: Blender's v is up, the glTF export flips it
        uv[:, 1] = 1.0 - uv[:, 1]
        lay.data.foreach_set("uv", uv.ravel())
        return ob, np.array(self.tail, bool)


def hairline_band(domain, depth=0.012):
    """The strip of scalp just inside the hairline (seeds for a hairline row: the strands that make the
    hairline itself, which strands seeded further back never reach)."""
    return lambda P: (lambda d: (d > 0.0) & (d < depth))(domain.sd(P))


def layer(builder, scalp, K, ok, flow, rng, count, slot, width, length, off, gather=None, fall=None, sdf=None,
          taper=0.55, length_jitter=0.25, step=0.006, domain=None, clearance=0.012, root_len=0.02):
    """A layer of strips: `count` seeds where `ok`, each grown and laid as a strip; `domain` (default
    `ok`) is where a strand may run on the scalp."""
    domain = ok if domain is None else domain
    seeds = scalp.sample(count, ok, rng)
    for s in seeds:
        L = length * (1.0 - length_jitter * rng.random())
        pts, nrms = grow(scalp, s, flow, L, step=step, off=off, gather=gather, fall=fall, sdf=sdf, rng=rng,
                         inside=domain, clearance=clearance)
        builder.strip(pts, nrms, width * rng.uniform(0.8, 1.2), slot, rng, taper=taper, root_len=root_len)


def weights(ctx, ob, tail_mask=None, tail_axis=None, tail_radius=0.03, lie=None, tail_rigid=None):
    """Head and neck of the nearest body point (hair lying on the back: the torso and neck only);
    tail strips on the pendulum as the v1 tails."""
    V = mesh_arrays(ob)
    W = body_weights_at(ctx, V)
    Wt = body_weights_at(ctx, V, torso_only=np.ones(len(V), bool))
    t = smoothstep(1.45, 1.39, V[:, 2]) * smoothstep(-0.03, 0.0, V[:, 1])
    W = W * (1 - t[:, None]) + Wt * t[:, None]
    W = smooth_weights(W, mesh_adjacency(ob), 3, 0.5)
    if tail_axis is not None and tail_rigid is not None and tail_mask is not None:
        W = H.rigid_zone(W, tail_mask, tail_rigid, ctx.bones)
    elif tail_axis is not None:
        W, _ = H.tail_weights(ctx, ob, W, tail_axis, tail_radius, in_tail=tail_mask, lie=lie)
    return W


def finish(ctx, spec, builder, tail_axis=None, tail_radius=0.03, lie=None, accents=None, domain=None,
           tail_rigid=None):
    """{"strands": Surface(<id>_tex), "main": accents (surface <id>) if any}; with the style's domain,
    its scalp mask (hair json "scalp_mask")."""
    if domain is not None:
        spec.extra["hair"]["scalp_mask"] = scalp_mask(spec.id, domain)
    spec.extra["hair"]["edge_feather"] = EDGE_FEATHER
    ob, tail = builder.object()
    log("  %s: %d strips' quads, %d verts" % (spec.id, len(builder.F), len(builder.V)))
    W = weights(ctx, ob, tail if tail.any() else None, tail_axis, tail_radius, lie, tail_rigid)
    C = H.poly_centers(ob)
    poly_tail = np.array([tail[list(p.vertices)].any() for p in ob.data.polygons])
    has_tail = poly_tail.any()
    regions = H.cap_regions(C, queue=poly_tail if has_tail and tail_rigid is None else None,
                            lock=poly_tail if has_tail and tail_rigid is not None else None)
    # h: across the strip (0 one edge, 1 the other; hair_tex.gdshader feathers the edges)
    out = {"strands": Surface(ob, zones=np.zeros(len(ob.data.polygons), int), regions=regions, weights=W,
                              h=np.array(builder.across, float))}
    if accents is not None:
        out["main"] = accents
    return out
