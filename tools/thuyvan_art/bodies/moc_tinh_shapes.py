"""Mộc Tinh (P07) grey-box body: the human body v4 (MakeHuman topology and head, so every face, `sex`, `blink` and the
FaceExtras landmarks keep working), reshaped, plus its own parts on the human skeleton and the kit's extension bones.

Design: peoples_places/bodies_design.md section 4 and the build brief (variant A "Grove-Tender" is the base; B
"Sapling Spire" and C "Moss-Cloak" are the bold alternatives, later the Crown / Moss / Bark grain rows on one body).

- Reshape (PeopleProportion form "moc_tinh"): limb thickness 0.82 (A), forearm and shin length +5 %, pelvis and chest
  x 0.9; height within +2 %. The head above the neck seam is untouched except the `ear_leaf` point.
- `wood`: knot bulges at the elbows, knees and shoulders. Twig fingertips +1.5 cm.
- Parts: bark (raised plates and ridges over the limbs and trunk, 3-12 mm, vertical grain; spurs on the outer edges
  of the forearms, shins and back; the face and the front of the neck left smooth), roots (feet slot), crown (head
  slot), vines, and C's moss mantle.

Plain numpy + lib.sdf (no bpy): the Blender build (build_greybox.py) loads the arrays this writes.
"""

import math

import numpy as np

from lib.sdf import Ellipsoid, Inter, Onion, Plane, RoundCone, Sphere, Union, frame_from, lerp, nrm, v3, smoothstep
from lib.weights import deform_segments

from skeleton import moc_tinh_bones


class MTParams:
    DEFAULTS = {
        "name": "A", "sex": 0.0,
        "limb": 0.82, "trunk_x": 0.90, "trunk_y": 1.0, "hand": 0.92, "stretch": 0.05,
        "knot": 0.008, "twig": 0.015, "ear_leaf": 1.0,
        "bark_min": 0.004, "bark_max": 0.012, "bark_cell": (0.042, 0.13), "spurs": 1.0,
        "crown": "leafy", "crown_cap": 0.22, "vines": ("l_arm", "r_arm", "sash", "hang_l", "hang_3"),
        "roots": 0.12, "moss": 0.0, "bloom": 1.0,
    }

    def __init__(self, **kw):
        self.__dict__.update(self.DEFAULTS)
        for k, v in kw.items():
            if k not in self.DEFAULTS:
                raise KeyError(k)
            self.__dict__[k] = v

    def copy(self, **kw):
        d = {k: getattr(self, k) for k in self.DEFAULTS}
        d.update(kw)
        return MTParams(**d)


def variant(name, sex=0.0):
    if name == "A":       # Grove-Tender (the sheet)
        P = MTParams(name="A")
    elif name == "B":     # Sapling Spire
        P = MTParams(name="B", limb=0.72, trunk_x=0.86, hand=0.85, twig=0.022, bark_min=0.004, bark_max=0.014,
                     bark_cell=(0.030, 0.15), spurs=1.8, crown="branches", crown_cap=0.40, vines=("l_arm", "hang_l"),
                     roots=0.10, bloom=0.4)
    elif name == "C":     # Moss-Cloak
        P = MTParams(name="C", limb=0.95, trunk_x=1.10, trunk_y=1.15, hand=0.98, knot=0.010, bark_min=0.002,
                     bark_max=0.007, bark_cell=(0.06, 0.10), spurs=0.4, crown="umbrella", crown_cap=0.14,
                     vines=("l_arm", "r_arm", "sash", "l_leg", "hang_l", "hang_r", "hang_3", "hang_4"), roots=0.16,
                     moss=1.0, bloom=0.2)
    else:
        raise KeyError(name)
    return P.copy(sex=sex)


# ===========================================================================
# The human body v4, welded (glb vertices are split at UV and region seams)
# ===========================================================================
class Human:
    def __init__(self, m, J):
        from glb_read import merged
        V, F, Jn, Wt, morphs, pid = merged({"meshes": [m["meshes"][0]], "bones": m["bones"]})
        key = np.round(V * 1e5).astype(np.int64)
        _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
        inv = inv.ravel()
        self.split_to_weld = inv
        self.V = V[first]
        self.F = inv[F]
        self.F = self.F[(self.F[:, 0] != self.F[:, 1]) & (self.F[:, 1] != self.F[:, 2]) & (self.F[:, 0] != self.F[:, 2])]
        self.bones = list(m["bones"])
        W = np.zeros((len(V), len(self.bones)))
        for k in range(4):
            np.add.at(W, (np.arange(len(V)), Jn[:, k]), Wt[:, k])
        self.W = W[first]
        self.morphs = {k: v[first] for k, v in morphs.items()}
        col = m["meshes"][0].get("color")
        self.color = col[first] if col is not None else None
        self.J = J


def vertex_normals(V, F):
    n = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    N = np.zeros_like(V)
    for k in range(3):
        np.add.at(N, F[:, k], n)
    return N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)


def edges_of(F):
    E = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    E = np.sort(E, 1)
    return np.unique(E, axis=0)


def main_bone_map(J, bones, segs):
    out = {}
    for b in bones:
        n = b
        while n is not None and n not in segs:
            n = J.parent.get(n)
        out[b] = n
    return out


LIMB = {"shoulder", "elbow", "upper_leg", "knee"}
HAND = {"wrist", "palm"}
TRUNK = {"pelvis", "spinea", "spineb", "spinec", "spined"}
KEEP = {"neck", "heada", "headb", "clavicle"}
STRETCH = {"elbow": "wrist", "knee": "ankle"}


def _kind(b):
    if b is None:
        return "keep"
    base = b[2:] if b[:2] in ("l_", "r_") else b
    if base in LIMB:
        return "limb"
    if base in HAND or base.startswith(("index", "middle", "ring", "pinky", "thumb")):
        return "hand"
    if base in TRUNK:
        return "trunk"
    if base in ("ankle", "heel", "ball"):
        return "foot"
    return "keep"


def joint_offsets(J, P):
    """Rest joint offsets of the proportion (forearm and shin +stretch, then the whole body up so the soles stay on the
    ground): {bone: offset (3,)} for every bone, as PeopleProportion's bone offsets."""
    off = {n: np.zeros(3) for n in J.order}
    for s in "lr":
        for a, end in (("elbow", "wrist"), ("knee", "ankle")):
            d = (J[s + "_" + end] - J[s + "_" + a]) * P.stretch
            root = s + "_" + end
            for n in J.order:
                m = n
                while m is not None and m != root:
                    m = J.parent.get(m)
                if m == root:
                    off[n] = off[n] + d
    lift = -(J["l_ankle"] - J["l_knee"])[2] * P.stretch
    for n in J.order:
        off[n] = off[n] + np.array([0, 0, lift])
    return off, lift


def reshape(H, V, P):
    """Proportion bake on vertices V (base or base + sex): limb thickness, trunk width, hands, forearm and shin length."""
    J = H.J
    segs = deform_segments(J)
    mb = main_bone_map(J, H.bones, segs)
    W = H.W
    out = np.zeros_like(V)
    off, lift = joint_offsets(J, P)
    for j, b in enumerate(H.bones):
        w = W[:, j]
        m = w > 0
        if not m.any():
            continue
        main = mb[b]
        kind = _kind(main)
        Vm = V[m]
        if kind in ("limb", "hand", "foot"):
            f = {"limb": P.limb, "hand": P.hand, "foot": 0.92}[kind]
            a, c = segs[main][0][0]
            ab = c - a
            t = np.clip(((Vm - a) @ ab) / (ab @ ab), 0, 1)
            proj = a + t[:, None] * ab
            nv = proj + (Vm - proj) * f
            base = main[2:]
            if base in STRETCH:
                nv = nv + t[:, None] * (J[main[:2] + STRETCH[base]] - J[main]) * P.stretch
        elif kind == "trunk":
            nv = Vm * np.array([P.trunk_x, 1.0, 1.0]) + (Vm * np.array([0, P.trunk_y - 1.0, 0]))
            nv[:, 1] += (1 - P.trunk_y) * 0.0
        else:
            nv = Vm.copy()
        nv = nv + off[b]
        out[m] += w[m, None] * nv
    tot = W.sum(1)
    out = out / np.maximum(tot, 1e-9)[:, None]
    out[tot < 1e-6] = V[tot < 1e-6]
    return out


def dominant_main(H):
    segs = deform_segments(H.J)
    mb = main_bone_map(H.J, H.bones, segs)
    Wm = {}
    for j, b in enumerate(H.bones):
        mm = mb[b]
        if mm is None:
            continue
        Wm.setdefault(mm, np.zeros(len(H.V)))
        Wm[mm] += H.W[:, j]
    names = list(Wm)
    A = np.stack([Wm[n] for n in names], 1)
    return [names[i] for i in A.argmax(1)], A.max(1), segs


def wood_and_twigs(H, V, P):
    """`wood` knots at the elbows, knees and shoulders; twig fingertips; the `ear_leaf` point."""
    J = H.J
    N = vertex_normals(V, H.F)
    off, _ = joint_offsets(J, P)
    D = np.zeros_like(V)
    for s in "lr":
        for jn, r in (("elbow", 0.045), ("knee", 0.055), ("shoulder", 0.06)):
            c = J[s + "_" + jn] + off[s + "_" + jn]
            d = np.linalg.norm(V - c, axis=1)
            g = np.exp(-(d / r) ** 2)
            # knots on the outer and back side only (bark bulges, not a swollen joint)
            side = np.clip(((V - c) * np.array([1 if s == "l" else -1, 0.6, 0])).sum(1) / np.maximum(d, 1e-6), 0, 1)
            D += N * (P.knot * g * (0.35 + 0.65 * side))[:, None]
    # twig fingertips: the distal phalanx stretched past its joint
    bi = {b: i for i, b in enumerate(H.bones)}
    for s in "lr":
        for ch in (("indexb", "indexc"), ("middleb", "middlec"), ("ringb", "ringc"), ("pinkyc", "pinkyd"),
                   ("thumbb", "thumbc")):
            b0, b1 = s + "_" + ch[0], s + "_" + ch[1]
            w = H.W[:, bi[b1]] if b1 in bi else 0
            if not np.any(w):
                continue
            c = J[b1] + off[b1]
            d = nrm(J[b1] - J[b0])
            t = np.clip(((V - c) @ d) / 0.02, 0, 1)
            D += (d[None, :] * (P.twig * t * w)[:, None])
    # ear_leaf: the helix drawn up and back to a leaf point
    if "face_ears" in H.morphs and P.ear_leaf:
        ear = np.linalg.norm(H.morphs["face_ears"], axis=1) > 1e-5
        ear &= np.abs(V[:, 0]) > 0.055
        if ear.any():
            z0, z1 = V[ear, 2].min(), V[ear, 2].max()
            u = np.clip((V[:, 2] - (z0 + z1) * 0.5) / max(z1 - z0, 1e-3) * 2, 0, 1) * ear
            out = np.abs(V[:, 0]) - 0.06
            D += np.stack([np.sign(V[:, 0]) * 0.012 * u * u, 0.016 * u * u, 0.034 * u ** 2.2], 1) * P.ear_leaf
            del out
    return V + D


# ===========================================================================
# Bark shell: subdivided body copy, raised plates with cracks, the face and front neck left out
# ===========================================================================
def subdivide(V, F, attrs):
    E = edges_of(F)
    n = len(V)
    key = E[:, 0] * (n + 1) + E[:, 1]
    order = np.argsort(key)
    key_s = key[order]

    def mid(a, b):
        lo, hi = np.minimum(a, b), np.maximum(a, b)
        k = lo * (n + 1) + hi
        return n + order[np.searchsorted(key_s, k)]
    V2 = np.vstack([V, (V[E[:, 0]] + V[E[:, 1]]) * 0.5])
    A2 = [np.concatenate([a, (a[E[:, 0]] + a[E[:, 1]]) * 0.5]) for a in attrs]
    a, b, c = F[:, 0], F[:, 1], F[:, 2]
    ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
    F2 = np.concatenate([np.stack([a, ab, ca], 1), np.stack([ab, b, bc], 1), np.stack([ca, bc, c], 1),
                         np.stack([ab, bc, ca], 1)])
    return V2, F2, A2


def laplacian(V, F, iters=1, lam=0.5, mu=-0.53):
    E = edges_of(F)
    deg = np.bincount(E.ravel(), minlength=len(V)).astype(float)
    for _ in range(iters):
        for f in (lam, mu):
            acc = np.zeros_like(V)
            np.add.at(acc, E[:, 0], V[E[:, 1]])
            np.add.at(acc, E[:, 1], V[E[:, 0]])
            V = V + f * (acc / np.maximum(deg, 1)[:, None] - V)
    return V


def _hash2(i, j, seed):
    h = (i * 374761393 + j * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h & 0xFFFF) / 65535.0, ((h >> 16) & 0xFFFF) / 65535.0


def worley(u, v, seed=1):
    """F1, F2 and the cell value of an anisotropic jittered grid (u, v in cell units)."""
    iu, iv = np.floor(u).astype(np.int64), np.floor(v).astype(np.int64)
    best1 = np.full(len(u), 9.0)
    best2 = np.full(len(u), 9.0)
    cell = np.zeros(len(u))
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            ci, cj = iu + di, iv + dj
            rx, ry = _hash2(ci, cj, seed)
            px, py = ci + 0.15 + 0.7 * rx, cj + 0.15 + 0.7 * ry
            d = np.sqrt((u - px) ** 2 + (v - py) ** 2)
            closer = d < best1
            best2 = np.where(closer, best1, np.minimum(best2, d))
            cell = np.where(closer, _hash2(ci + 17, cj - 5, seed + 3)[0], cell)
            best1 = np.where(closer, d, best1)
    return best1, best2, cell


def bark_field(H, V, P, main, segs):
    """Plate height (0..1), crack mask and the grain coordinate per vertex of V (H-shaped attributes interpolated
    by the caller)."""
    J = H.J
    n = len(V)
    s_coord = np.zeros(n)
    u_coord = np.zeros(n)
    bone_id = np.zeros(n, int)
    names = sorted(set(main))
    for k, b in enumerate(names):
        m = np.array([x == b for x in main])
        if not m.any() or b is None:
            continue
        bone_id[m] = k
        (a, c), = segs[b][0][:1]
        if _kind(b) == "trunk" or b in ("neck", "heada", "headb"):
            a, c = v3(0, 0.0, 0.8), v3(0, 0.0, 1.6)
        ax = nrm(c - a)
        ref = nrm(np.cross(ax, v3(0, 1, 0))) if abs(ax[1]) < 0.9 else v3(1, 0, 0)
        ref2 = np.cross(ax, ref)
        d = V[m] - a
        s_coord[m] = d @ ax
        th = np.arctan2(d @ ref2, d @ ref)
        u_coord[m] = th * 0.065
    cw, ch = P.bark_cell
    f1, f2, cell = worley(u_coord / cw, s_coord / ch + bone_id * 13.0, seed=5)
    crack = smoothstep(0.06, 0.20, f2 - f1)
    return crack, cell, s_coord, u_coord


def bark_shell(H, V, P):
    """(V, F, W) of the bark part: one subdivision of the reshaped body, displaced by the plate field; the head, the
    front of the neck and the palms are left out."""
    main, dom, segs = dominant_main(H)
    bi = {b: i for i, b in enumerate(H.bones)}
    head_w = sum(H.W[:, bi[b]] for b in ("headb", "heada") if b in bi)
    neck_w = H.W[:, bi["neck"]]
    keep_out = (head_w > 0.35) | ((neck_w > 0.4) & (V[:, 1] < 0.0)) | ((head_w + neck_w > 0.3) & (V[:, 1] < -0.04))
    fade = np.clip(1.0 - (head_w + neck_w * (V[:, 1] < 0.01)) * 2.2, 0, 1)
    V2, F2, (W2, fade2, mi) = subdivide(V, H.F, [H.W, fade, np.arange(len(V), dtype=float)])
    # dominant main bone of the new vertices from the weights
    main_idx = {b: i for i, b in enumerate(sorted(set(x for x in main if x)))}
    V2 = laplacian(V2, F2, 1)
    main2 = []
    mb = main_bone_map(H.J, H.bones, segs)
    agg = {}
    for j, b in enumerate(H.bones):
        mm = mb[b]
        if mm is None:
            continue
        agg.setdefault(mm, np.zeros(len(V2)))
        agg[mm] += W2[:, j]
    nm = list(agg)
    A = np.stack([agg[x] for x in nm], 1)
    main2 = [nm[i] for i in A.argmax(1)]
    del main_idx
    crack, cell, s, u = bark_field(H, V2, P, main2, segs)
    hgt = P.bark_min + (P.bark_max - P.bark_min) * cell
    # grain: fine vertical ridges inside each plate
    grain = 0.5 + 0.5 * np.sin(u / 0.0045 + 2.0 * np.sin(s / 0.05))
    disp = 0.0018 + crack * hgt * (0.7 + 0.3 * grain)
    disp *= fade2
    N = vertex_normals(V2, F2)
    V3 = V2 + N * disp[:, None]
    # drop the faces of the left-out regions (all three vertices faded out)
    keepf = (fade2[F2] > 0.02).any(1)
    F3 = F2[keepf]
    used = np.unique(F3)
    remap = -np.ones(len(V3), int)
    remap[used] = np.arange(len(used))
    return V3[used], remap[F3], W2[used], {"crack": crack[used], "cell": cell[used], "grain_u": u[used],
                                           "grain_s": s[used], "fade": fade2[used]}


# ===========================================================================
# SDF parts: spurs, roots, crown, vines, moss mantle
# ===========================================================================
def limb_radius(V, a, c, t, around):
    """Distance of the body surface from the a-c axis at t, toward `around` (a unit direction)."""
    ab = c - a
    tt = ((V - a) @ ab) / (ab @ ab)
    m = np.abs(tt - t) < 0.06
    p = a + ab * t
    d = V[m] - p
    d = d - np.outer(d @ nrm(ab), nrm(ab))
    dist = np.linalg.norm(d, axis=1)
    cosang = (d @ around) / np.maximum(dist, 1e-9)
    sel = (cosang > 0.85) & (dist < 0.11)
    if not sel.any():
        near = dist[dist < 0.11]
        return float(np.percentile(near, 80)) if len(near) else 0.04
    return float(np.median(dist[sel]))


def spur(base, n, along, h, r):
    tip = base + nrm(n + along * 0.6) * h
    return RoundCone(base - n * 0.006, tip, r, r * 0.15)


def spurs(H, V, P, J):
    if P.spurs <= 0:
        return None
    off, _ = joint_offsets(J, P)
    out = []
    for s, sd in ((1, "l"), (-1, "r")):
        E, Wr = J[sd + "_elbow"] + off[sd + "_elbow"], J[sd + "_wrist"] + off[sd + "_wrist"]
        n = nrm(v3(s * 1.0, 0.55, 0.15))
        cnt = int(round(3 * P.spurs))
        for k in range(cnt):
            t = 0.2 + 0.6 * k / max(1, cnt - 1)
            r = limb_radius(V, E, Wr, t, n)
            out.append(spur(lerp(E, Wr, t) + n * (r - 0.002), n, nrm(Wr - E), 0.016 * min(P.spurs, 1.6), 0.007))
        Kn, A = J[sd + "_knee"] + off[sd + "_knee"], J[sd + "_ankle"] + off[sd + "_ankle"]
        n = nrm(v3(s * 0.7, -0.7, 0.0))
        for k in range(cnt):
            t = 0.18 + 0.55 * k / max(1, cnt - 1)
            r = limb_radius(V, Kn, A, t, n)
            out.append(spur(lerp(Kn, A, t) + n * (r - 0.002), n, nrm(A - Kn), 0.020 * min(P.spurs, 1.4), 0.008))
        if P.spurs > 1:   # upper arms too
            S, Ee = J[sd + "_shoulder"] + off[sd + "_shoulder"], E
            n = nrm(v3(s, 0.3, 0.3))
            for t in (0.35, 0.65):
                r = limb_radius(V, S, Ee, t, n)
                out.append(spur(lerp(S, Ee, t) + n * (r - 0.002), n, nrm(Ee - S), 0.024, 0.009))
    # back: a short row down the spine between the shoulder blades
    for z in np.arange(1.30, 1.02, -0.07):
        m = (np.abs(V[:, 0]) < 0.02) & (np.abs(V[:, 2] - z) < 0.02) & (V[:, 1] > 0)
        if not m.any():
            continue
        y = V[m, 1].max()
        out.append(spur(v3(0, y - 0.004, z), v3(0, 1, 0.25), v3(0, 0, -1), 0.020 * min(P.spurs, 1.5), 0.009))
    return Union(out, k=0.003)


def roots(J, P, lift):
    out = []
    for s, sd in ((1, "l"), (-1, "r")):
        B, Hl = J[sd + "_ball"], J[sd + "_heel"]
        x = B[0]
        L = P.roots
        for k, ang in enumerate((-38, -16, 4, 24, 44)):
            a = math.radians(ang)
            d = nrm(v3(s * math.sin(a), -math.cos(a), 0))
            base = v3(x + s * (k - 2) * 0.012, B[1] - 0.045, 0.022 + lift * 0.0)
            mid = base + d * (0.10 * L / 0.12) * 0.5 + v3(0, 0, -0.004)
            tip = base + d * (0.16 * L / 0.12) + v3(0, 0, -0.016)
            r0 = 0.014 if k != 2 else 0.016
            out.append(RoundCone(base, mid, r0, r0 * 0.7))
            out.append(RoundCone(mid, tip, r0 * 0.7, 0.004))
        hb = v3(x, Hl[1] + 0.005, 0.02)
        ht = hb + v3(s * 0.01, 0.06 * L / 0.12 + 0.02, -0.012)
        out.append(RoundCone(hb, ht, 0.016, 0.004))
        # a root sheath over the instep (the foot reads as rooted)
        out.append(Ellipsoid(v3(x, B[1] - 0.005, 0.045), (0.042, 0.06, 0.022), frame_from(v3(0, -0.3, 1), v3(1, 0, 0))))
    U = Union(out, k=0.012)
    return Inter(U, Plane((0, 0, -1), (0, 0, 0.002)), k=0.002)


def _puff(c, r, rng, n=6, flat=1.0):
    parts = [Ellipsoid(c, (r, r, r * flat))]
    for _ in range(n):
        d = nrm(rng.randn(3) * np.array([1, 1, 0.6]))
        parts.append(Ellipsoid(c + d * r * 0.75, (r * 0.62,) * 2 + (r * 0.62 * flat,)))
    return Union(parts, k=r * 0.35)


def crown(J, P, lift, head_top):
    """(branches node, leaves node, flowers [(centre, normal)], crown bones). Height capped to P.crown_cap above
    the head top."""
    rng = np.random.RandomState({"leafy": 3, "branches": 11, "umbrella": 5}[P.crown])
    up = v3(0, 0, lift)
    branches, leaves, flowers = [], [], []
    if P.crown == "leafy":
        bones = moc_tinh_bones(((0.10, 0.07), (0.08, 0.06), (0.07, 0.05), (0.07, 0.05), (0.08, 0.06), (0.10, 0.07)),
                               (12, 168))
    elif P.crown == "branches":
        bones = moc_tinh_bones(((0.14, 0.12), (0.13, 0.11), (0.15, 0.13), (0.15, 0.13), (0.13, 0.11), (0.14, 0.12)),
                               (40, 140))
    else:
        bones = moc_tinh_bones(((0.06, 0.05),) * 6, (60, 120))
    bones = [(n, p, h + up, t + up, d) for n, p, h, t, d in bones]
    bpos = {n: (h, t) for n, p, h, t, d in bones}
    root_h, root_t = bpos["crown_root"]
    if P.crown == "leafy":
        for k in range(1, 7):
            h1, t1 = bpos["crown_%d_01" % k]
            h2, t2 = bpos["crown_%d_02" % k]
            branches += [RoundCone(root_t + v3(0, 0, -0.03), h1, 0.012, 0.010), RoundCone(h1, t1, 0.010, 0.007),
                         RoundCone(t1, t2, 0.007, 0.004)]
            for c, r in ((t2, 0.028), (lerp(h1, t1, 0.75), 0.024), (lerp(t1, t2, 0.5) + v3(0, 0.02, 0), 0.022)):
                leaves.append(_puff(c + rng.randn(3) * 0.008, r, rng, n=5, flat=0.8))
        # a wreath of puffs round the crown of the head, hanging sprigs by the temples
        for a in np.linspace(0, 2 * math.pi, 11, endpoint=False):
            c = v3(math.cos(a) * 0.085, math.sin(a) * 0.08 - 0.005, head_top - 0.04 + 0.01 * math.sin(a))
            leaves.append(_puff(c, 0.024, rng, n=4, flat=0.75))
        for s in (1, -1):
            for k in range(3):
                leaves.append(_puff(v3(s * (0.09 + 0.005 * k), 0.02 + 0.01 * k, head_top - 0.08 - 0.045 * k), 0.022, rng, n=3))
        for c in [bpos["crown_%d_02" % k][1] for k in range(1, 7)][::2] + [v3(0.05, -0.06, head_top + 0.02),
                                                                             v3(-0.07, -0.05, head_top + 0.01)]:
            flowers.append((c + v3(0, -0.035, 0.02), nrm(v3(0, -1, 0.6))))
    elif P.crown == "branches":
        for k in range(1, 7):
            h1, t1 = bpos["crown_%d_01" % k]
            h2, t2 = bpos["crown_%d_02" % k]
            kink = lerp(h1, t1, 0.55) + rng.randn(3) * 0.012
            branches += [RoundCone(root_t + v3(0, 0, -0.03), h1, 0.016, 0.013), RoundCone(h1, kink, 0.013, 0.010),
                         RoundCone(kink, t1, 0.010, 0.008), RoundCone(t1, t2, 0.008, 0.003)]
            # two gnarled twigs, never tines: short, crooked, blossom-tipped
            for j in range(2):
                b0 = lerp(h1, t1, 0.5 + 0.35 * j)
                d = nrm(rng.randn(3) * 0.6 + (t2 - t1) * 4)
                tw = b0 + d * 0.06
                branches.append(RoundCone(b0, tw, 0.006, 0.0025))
                if rng.rand() < 0.5 * (1 + P.bloom):
                    leaves.append(_puff(tw, 0.016, rng, n=3))
                    flowers.append((tw + v3(0, -0.012, 0.004), nrm(v3(0, -1, 0.5))))
    else:   # umbrella: a flat two-tier canopy like the karst pines, with moss drips
        branches.append(RoundCone(root_t + v3(0, 0, -0.03), root_t + v3(0.01, 0.0, 0.07), 0.02, 0.014))
        for k in range(1, 7):
            h1, t1 = bpos["crown_%d_01" % k]
            branches.append(RoundCone(root_t + v3(0, 0, 0.02), t1 * v3(1.0, 1.0, 1.0), 0.010, 0.006))
        for tier, (z, R, n) in enumerate(((head_top + 0.055, 0.30, 11), (head_top + 0.115, 0.19, 7))):
            for a in np.linspace(0, 2 * math.pi, n, endpoint=False):
                c = v3(math.cos(a) * R * 0.72, math.sin(a) * R * 0.72, z)
                leaves.append(_puff(c, 0.065 - 0.012 * tier, rng, n=5, flat=0.45))
            leaves.append(_puff(v3(0, 0, z), 0.08 - 0.02 * tier, rng, n=5, flat=0.45))
            if tier == 0:
                for a in np.linspace(0.2, 2 * math.pi, 9, endpoint=False):
                    c = v3(math.cos(a) * R * 0.95, math.sin(a) * R * 0.95, z - 0.03)
                    L = 0.05 + 0.05 * rng.rand()
                    leaves.append(RoundCone(c, c + v3(0, 0, -L), 0.014, 0.006))     # moss drips
    B = Union(branches, k=0.006)
    Lv = Union(leaves, k=0.008) if leaves else None
    # the playable cap: squash the crown into P.crown_cap above the head top (a ceiling probe bends it at runtime)
    from lib.sdf import polygonize
    top = max(n.hi[2] for n in ([B] + ([Lv] if Lv is not None else [])))
    if top > head_top + P.crown_cap:
        from sdf_extra import Warp
        f = (P.crown_cap - 0.01) / (top - head_top)
        c = v3(0, 0, head_top)
        B = Warp(B, c, (1.0, 1.0, f))
        Lv = Warp(Lv, c, (1.0, 1.0, f)) if Lv is not None else None
        flowers = [(c + (p - c) * np.array([1, 1, f]), n) for p, n in flowers]
        bones = [(nm, pa, c + (h - c) * np.array([1, 1, f]) if h[2] > head_top else h,
                  c + (t - c) * np.array([1, 1, f]) if t[2] > head_top else t, d) for nm, pa, h, t, d in bones]
    del polygonize
    return B, Lv, flowers, bones


def helix(a, c, r0, r1, turns, phase, n=40):
    ax = nrm(c - a)
    ref = nrm(np.cross(ax, v3(0, 1, 0))) if abs(ax[1]) < 0.9 else v3(1, 0, 0)
    ref2 = np.cross(ax, ref)
    pts = []
    for i in range(n + 1):
        t = i / n
        th = phase + turns * 2 * math.pi * t
        r = r0 + (r1 - r0) * t
        pts.append(lerp(a, c, t) + (ref * math.cos(th) + ref2 * math.sin(th)) * r)
    return np.array(pts)


def _leaf(p, n, along, size):
    return Ellipsoid(p + n * size * 0.4, (size, size * 0.5, size * 0.12), frame_from(n, along))


def vines(H, V, P, J, off):
    """Vine tubes wound round the limbs and chest, hanging ends on the vine bones, leaves along them."""
    rng = np.random.RandomState(9)
    tubes, leaves = [], []
    paths = []

    def axis(sd, a, c):
        return J[sd + "_" + a] + off[sd + "_" + a], J[sd + "_" + c] + off[sd + "_" + c]
    for v in P.vines:
        if v in ("l_arm", "r_arm"):
            sd = v[0]
            S, E = axis(sd, "shoulder", "elbow")
            E2, Wr = axis(sd, "elbow", "wrist")
            n = nrm(v3(1 if sd == "l" else -1, 0, 0))
            r1 = limb_radius(V, S, E, 0.5, n) + 0.006
            r2 = limb_radius(V, E2, Wr, 0.5, n) + 0.005
            p1 = helix(S + (E - S) * 0.05, E, r1 * 1.05, r1 * 0.95, 1.25, 0.3)
            p2 = helix(E2, Wr + (Wr - E2) * -0.05, r2, r2 * 0.9, 1.5, 0.3 + 1.25 * 2 * math.pi)
            paths.append(np.vstack([p1, p2]))
        elif v in ("l_leg", "r_leg"):
            sd = v[0]
            Hh, Kn = axis(sd, "upper_leg", "knee")
            Kn2, A = axis(sd, "knee", "ankle")
            n = nrm(v3(1 if sd == "l" else -1, 0, 0))
            r1 = limb_radius(V, Hh, Kn, 0.5, n) + 0.006
            r2 = limb_radius(V, Kn2, A, 0.4, n) + 0.005
            paths.append(np.vstack([helix(Hh + (Kn - Hh) * 0.25, Kn, r1, r1 * 0.9, 1.0, 1.0),
                                    helix(Kn2, A + (Kn2 - A) * 0.15, r2, r2 * 0.85, 1.0, 1.0 + 2 * math.pi)]))
        elif v == "sash":
            # across the chest from the left shoulder to the right hip and round the waist
            pts = []
            for t in np.linspace(0, 1, 30):
                z = 1.30 - 0.38 * t
                x = 0.11 - 0.24 * t
                m = (np.abs(V[:, 2] - z) < 0.015) & (np.abs(V[:, 0] - x) < 0.015)
                y = V[m, 1].min() - 0.008 if m.any() else -0.12
                pts.append(v3(x, y, z))
            for a in np.linspace(math.pi * 1.5 - 0.6, math.pi * 1.5 - 0.6 - 2 * math.pi, 34):
                z = 0.92
                m = (np.abs(V[:, 2] - z) < 0.015) & (np.abs(V[:, 0]) < 0.2) & (np.abs(V[:, 1]) < 0.2)
                Vm = V[m]
                ang = np.arctan2(Vm[:, 1], Vm[:, 0])
                d = np.abs((ang - a + math.pi) % (2 * math.pi) - math.pi) < 0.12
                r = np.linalg.norm(Vm[d][:, :2], axis=1).max() + 0.008 if d.any() else 0.15
                pts.append(v3(math.cos(a) * r, math.sin(a) * r, z))
            paths.append(np.array(pts))
    for path in paths:
        for i in range(len(path) - 1):
            tubes.append(RoundCone(path[i], path[i + 1], 0.0085, 0.0085))
        for i in range(2, len(path) - 1, 3):
            d = nrm(path[i + 1] - path[i - 1])
            # leaves lie on the body (their thin axis along the outward normal), never as fins
            j = np.linalg.norm(V - path[i], axis=1).argmin()
            out = nrm(path[i] - V[j] + rng.randn(3) * 0.002)
            side = nrm(np.cross(out, d)) * (1 if (i // 3) % 2 else -1)
            leaves.append(_leaf(path[i] + side * 0.012, out, nrm(d + side * 0.8), 0.022 + 0.006 * rng.rand()))
    # hanging ends on the vine bones
    bones = moc_tinh_bones()
    bones = [(nm, p, h + off.get(p, np.zeros(3)) * 0 + v3(0, 0, off["pelvis"][2]), t + v3(0, 0, off["pelvis"][2]), d)
             for nm, p, h, t, d in bones]
    chains = {}
    for nm, p, h, t, d in bones:
        if nm.startswith("vine_"):
            chains.setdefault(nm[:6], []).append((h, t))
    want = {"hang_l": "vine_1", "hang_r": "vine_2", "hang_3": "vine_3", "hang_4": "vine_4"}
    for v in P.vines:
        if v not in want:
            continue
        segs = chains[want[v]]
        pts = [segs[0][0]] + [t for h, t in segs]
        # push the start onto the body surface and let the end sway outward a little
        pts = np.array(pts)
        for i, p in enumerate(pts):
            d = np.linalg.norm(V - p, axis=1)
            j = d.argmin()
            nrmv = nrm(p - V[j]) if d[j] > 1e-6 else v3(0, -1, 0)
            pts[i] = V[j] + nrmv * 0.012 + v3(0, 0, 0) if d[j] < 0.03 else p
        for i in range(len(pts) - 1):
            tubes.append(RoundCone(pts[i], pts[i + 1], 0.008, 0.007 - 0.001 * i))
            dd = nrm(pts[i + 1] - pts[i])
            for k in range(2):
                q = lerp(pts[i], pts[i + 1], 0.3 + 0.4 * k)
                o = nrm(np.cross(dd, v3(0, 0, 1)) * (1 if k else -1) + v3(0, -0.4, 0))
                leaves.append(_leaf(q, o, dd, 0.024))
    T = Union(tubes, k=0.004) if tubes else None
    L = Union(leaves, k=0.0) if leaves else None
    return T, L


def moss_mantle(J, P, V):
    """Variant C: a hanging moss mantle (shaggy strands from the shoulders and upper back to mid-thigh), so it reads
    as moss on the body, never as a cloak."""
    if P.moss < 0.5:
        return None
    rng = np.random.RandomState(4)
    out = []
    for a in np.linspace(-0.15, math.pi + 0.15, 26):
        x0 = math.cos(a) * 0.17
        z0 = 1.36 - 0.06 * abs(math.cos(a)) ** 2
        m = (np.abs(V[:, 0] - x0) < 0.02) & (np.abs(V[:, 2] - z0) < 0.025) & (V[:, 1] > -0.02)
        if not m.any():
            continue
        p = V[m][V[m, 1].argmax()] + v3(0, 0.012, 0.01)
        L = 0.55 + 0.18 * rng.rand() - 0.15 * abs(math.cos(a))
        flare = v3(math.cos(a) * 0.10, 0.07 + 0.03 * rng.rand(), 0)
        q1 = p + v3(0, 0.04, -0.15)
        q2 = p + flare * 0.6 + v3(0, 0, -L * 0.6)
        q3 = p + flare + v3(0, 0, -L)
        r = 0.032 + 0.01 * rng.rand()
        out += [RoundCone(p, q1, r, r * 0.95), RoundCone(q1, q2, r * 0.95, r * 0.7), RoundCone(q2, q3, r * 0.7, 0.008)]
    for s in (1, -1):
        S = J.side("shoulder", s)
        out.append(_puff(S + v3(s * 0.01, 0.01, 0.06), 0.05, rng, n=5, flat=0.6))
    return Union(out, k=0.02)


def build(H, P, sex=0.0):
    """Everything the Blender build needs, as arrays and SDF nodes."""
    J = H.J
    V0 = H.V + H.morphs["sex"] * sex if sex else H.V.copy()
    # a tree spirit's body: the creator's smallest genital shape, smoothed over by the bark
    if "genital_small" in H.morphs:
        V0 = V0 + H.morphs["genital_small"]
    Vr = reshape(H, V0, P)
    Vw = wood_and_twigs(H, Vr, P)
    off, lift = joint_offsets(J, P)
    head_top = float(Vw[:, 2].max())
    nodes = {"spurs": spurs(H, Vw, P, J), "roots": roots(J, P, lift)}
    cb, cl, flowers, crown_bones = crown(J, P, lift, head_top)
    nodes["crown_branches"], nodes["crown_leaves"] = cb, cl
    vt, vl = vines(H, Vw, P, J, off)
    nodes["vines"], nodes["vine_leaves"] = vt, vl
    nodes["moss"] = moss_mantle(J, P, Vw)
    return {"V": Vw, "F": H.F, "W": H.W, "bones": H.bones, "nodes": nodes, "flowers": flowers,
            "crown_bones": crown_bones, "offsets": off, "lift": lift, "head_top": head_top}
