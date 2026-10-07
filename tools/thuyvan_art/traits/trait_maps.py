"""The Thủy Vân peoples' skin traits, painted into today's body (numpy only: no Blender, no Godot).

    python3 tools/thuyvan_art/traits/trait_maps.py            -> assets/thuyvan/character/traits/*.png + traits_maps.json

Design: peoples_design.md section 2.4 (trait kinds 3 scales, 4 plates, 5 river) and 2.8 (markings). Everything is laid in
the body's MakeHuman UV atlas (body.glb TEXCOORD_2, Godot CUSTOM0.xy), the one atlas of the body whose islands never
overlap (the metre UVs, UV, overlap left with right and arm with leg). Each map is 2048 x 2048, 8 bit:

  trait_order_tv.png   where each mark appears first as its amount rises (the "order map": a texel is marked where
                       order < amount; 255 never):
                         R  scales (kind 3, Dragon-Sea): wrists -> temples and cheekbones -> shoulders and collarbones
                            -> outer forearms -> along the spine -> outer thighs
                         G  plates (kind 4, Stone Children), one value per plate so a plate comes whole: forearms and
                            knuckles -> upper arms and shoulders -> brow ridge and cheekbones -> back -> chest -> shins
                            and thighs -> most of the body; never the lips, eyelids, palms or inner elbows
                         B  river sheen (kind 5, Riverborn): broad wet patches
                         A  river scale patches (kind 5): temples, collarbones, outer forearms
  trait_detail_tv.png  R  the plates' crack distance (F2 - F1 of a Voronoi of plates about 18 per metre, in 0.1 mm
                          steps: 0 on a crack, 255 = 25.5 mm or more inside a plate)
                       G  the plate's own hash (its value jitter, its quartz speck)
                       B  the painted gill slits (kind 5): 3 a side behind the jaw; 255 the slit's core, falling to
                          about 100 on its lit lip
                       A  the scales' and river patches' value along the sheen (a soft broad noise, 0..255)
  ash_marks_tv.png     the Ancestor-Bound rite marks, as markings anyone may wear (pale ash, not a body trait):
                       R the thumbprint on the brow, G two fingers of ash on each cheekbone, B the backs of the hands,
                       A the powder's grain

The scales themselves (6-9 mm, arched, in offset rows) are too fine to bake at 2048: the shader draws them from the
metre UVs (people_trait.gdshaderinc `tv_scale_cell`, the same maths as `scale_cell` below, which the preview bake uses).

All of it is drawn from the body's own anatomy (the bind pose's joints, read from the glb's inverse binds) with fixed
seeds, so a rebuild is bit for bit. Our own marks only: nothing traced from the sheets or any people's tradition.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
from glb_read import Glb  # noqa: E402

BODY_GLB = os.path.join(ROOT, "assets/character/body/body.glb")
BODY_JSON = os.path.join(ROOT, "assets/character/body/body.json")
OUT_DIR = os.path.join(ROOT, "assets/thuyvan/character/traits")
GAME_N = 2048

PLATES_PER_M = 18.0
PLATES_PER_M_FACE = 34.0
# the scales' cell in metres (across, along the limb); the face's are smaller (peoples_design 2.4: about 6 x 5 mm; drawn
# a little bigger on the body so they read at a game camera's distance, WoW-chunky, never finer)
SCALE_CELL = (0.009, 0.0075)
SCALE_CELL_FACE = (0.0062, 0.0052)


# ------------------------------------------------------------------------------------------------------------- noise
def _hash3(ix, iy, iz, seed):
    h = (ix.astype(np.int64) * 73856093) ^ (iy.astype(np.int64) * 19349663) ^ (iz.astype(np.int64) * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float64) / float(0xFFFFFF)


def vnoise3(p, freq, seed=0):
    """Smooth value noise in 3D, 0..1, at `freq` cells per metre."""
    q = p * freq
    i = np.floor(q)
    f = q - i
    u = f * f * (3.0 - 2.0 * f)
    ix, iy, iz = i[:, 0].astype(np.int64), i[:, 1].astype(np.int64), i[:, 2].astype(np.int64)
    out = 0.0
    for dx in (0, 1):
        wx = u[:, 0] if dx else 1.0 - u[:, 0]
        for dy in (0, 1):
            wy = u[:, 1] if dy else 1.0 - u[:, 1]
            for dz in (0, 1):
                wz = u[:, 2] if dz else 1.0 - u[:, 2]
                out = out + wx * wy * wz * _hash3(ix + dx, iy + dy, iz + dz, seed)
    return out


def fbm3(p, freq, seed=0, octaves=3):
    tot, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        tot = tot + amp * vnoise3(p, freq * (2.03 ** o), seed + 17 * o)
        norm += amp
        amp *= 0.5
    return tot / norm


def hash2(x, y):
    """The shader's hash12 (skin_common.gdshaderinc), vectorised."""
    p3 = np.stack([x * 0.1031, y * 0.1031, x * 0.1031], -1)
    p3 = p3 - np.floor(p3)
    d = np.sum(p3 * (p3[..., [1, 2, 0]] + 33.33), -1, keepdims=True)
    p3 = p3 + d
    v = (p3[..., 0] + p3[..., 1]) * p3[..., 2]
    return v - np.floor(v)


# ------------------------------------------------------------------------------------------------------------- body
class Body:
    """body.glb's Body mesh in the bind pose (Godot space), its joints and its regions."""

    def __init__(self):
        self.g = Glb(BODY_GLB)
        p = self.g.prim("Body")
        self.pos = p["POSITION"].astype(np.float64)
        self.nrm = p["NORMAL"].astype(np.float64)
        self.muv = p["TEXCOORD_0"].astype(np.float64)        # metre UVs
        self.code = p["TEXCOORD_1"].astype(np.float64)       # region + 64 zone, body value
        self.mh = p["TEXCOORD_2"].astype(np.float64)         # MakeHuman atlas
        self.col = p["COLOR_0"].astype(np.float64)
        if self.col.shape[1] == 3:
            self.col = np.concatenate([self.col, np.zeros((len(self.col), 1))], 1)
        self.tri = p["indices"]
        info = json.load(open(BODY_JSON))
        self.region_ids = info["regions"]["ids"]
        self.face_warp = info["face"]["warp"]
        self.landmarks = info["face"]["landmarks"]
        sk = self.g.js["skins"][0]
        ibm = self.g.accessor(sk["inverseBindMatrices"]).reshape(-1, 4, 4)
        self.joints = {}
        for n, m in zip(self.g.joint_names(), ibm):
            self.joints[n] = np.linalg.inv(m.T)[:3, 3].astype(np.float64)
        f = self.g.prim("Face", 0)["POSITION"]
        self.eye_l = f[f[:, 0] > 0].mean(0).astype(np.float64)
        self.eye_r = f[f[:, 0] < 0].mean(0).astype(np.float64)

    def j(self, name):
        return self.joints[name]

    def front(self, x, y, r=0.006):
        """The skin's front-most point at (x, y) in the bind pose (the face's places are measured, not guessed)."""
        P = self.pos
        m = (np.abs(P[:, 0] - x) < r) & (np.abs(P[:, 1] - y) < r)
        return P[np.argmax(np.where(m, P[:, 2], -9.0))].copy()


def raster(body, n, cache_dir=None):
    """Every texel of the n x n MakeHuman atlas the body covers: its bind-pose position, normal, metre UV, region,
    vertex colour and body value (barycentric over the triangle), then grown 6 texels past the islands so filtering
    never reads the empty atlas. Returns a dict of flat arrays over the covered texels plus `index` (their row-major
    texel index) and `inside` (True on the triangles, False on the grown margin)."""
    if cache_dir:
        cp = os.path.join(cache_dir, "raster_%d.npz" % n)
        if os.path.exists(cp):
            z = np.load(cp)
            return {k: z[k] for k in z.files}
    N = n
    filled = np.zeros(N * N, bool)
    acc = {"pos": np.zeros((N * N, 3), np.float32), "nrm": np.zeros((N * N, 3), np.float32),
           "muv": np.zeros((N * N, 2), np.float32), "col": np.zeros((N * N, 4), np.float32),
           "bval": np.zeros(N * N, np.float32), "region": np.full(N * N, 255, np.uint8)}
    region_v = (np.round(body.code[:, 0]).astype(np.int64) & 63)
    xy = body.mh * N - 0.5
    for t in body.tri:
        a, b, c = xy[t[0]], xy[t[1]], xy[t[2]]
        x0 = int(np.floor(min(a[0], b[0], c[0]))); x1 = int(np.ceil(max(a[0], b[0], c[0])))
        y0 = int(np.floor(min(a[1], b[1], c[1]))); y1 = int(np.ceil(max(a[1], b[1], c[1])))
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, N - 1), min(y1, N - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        gx = gx.ravel().astype(np.float64); gy = gy.ravel().astype(np.float64)
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        w0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
        w1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
        w2 = 1.0 - w0 - w1
        ok = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        if not ok.any():
            continue
        w = np.stack([w0[ok], w1[ok], w2[ok]], 1)
        idx = gy[ok].astype(np.int64) * N + gx[ok].astype(np.int64)
        acc["pos"][idx] = w @ body.pos[t]
        acc["nrm"][idx] = w @ body.nrm[t]
        acc["muv"][idx] = w @ body.muv[t]
        acc["col"][idx] = w @ body.col[t]
        acc["bval"][idx] = w @ body.code[t, 1]
        acc["region"][idx] = region_v[t[np.argmax(w, 1)]]
        filled[idx] = True
    inside = filled.copy()
    # grow the islands 6 texels (each empty texel takes the mean of its filled 4-neighbours; region from any of them)
    img_f = filled.reshape(N, N)
    for _ in range(6):
        nb = np.zeros((N, N), np.float32)
        sums = {k: np.zeros((N, N) + acc[k].shape[1:], np.float32) for k in ("pos", "nrm", "muv", "col", "bval")}
        reg_take = np.full((N, N), 255, np.uint8)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sf = np.roll(img_f, (dy, dx), (0, 1))
            nb += sf
            for k in sums:
                arr = acc[k].reshape((N, N) + acc[k].shape[1:])
                sh = np.roll(arr, (dy, dx), (0, 1))
                m = sf if sh.ndim == 2 else sf[..., None]
                sums[k] += sh * m
            rr = np.roll(acc["region"].reshape(N, N), (dy, dx), (0, 1))
            reg_take = np.where(sf & (reg_take == 255), rr, reg_take)
        grow = (~img_f) & (nb > 0)
        for k in sums:
            arr = acc[k].reshape((N, N) + acc[k].shape[1:])
            d = nb if sums[k].ndim == 2 else nb[..., None]
            gm = grow if sums[k].ndim == 2 else grow[..., None]
            arr[...] = np.where(gm, sums[k] / np.maximum(d, 1), arr)
        acc["region"].reshape(N, N)[grow] = reg_take[grow]
        img_f = img_f | grow
    filled = img_f.ravel()
    index = np.nonzero(filled)[0]
    out = {k: v[index] for k, v in acc.items()}
    nn = np.linalg.norm(out["nrm"], axis=1, keepdims=True)
    out["nrm"] = out["nrm"] / np.maximum(nn, 1e-6)
    out["index"] = index
    out["inside"] = inside[index]
    out["n"] = np.array(N)
    if cache_dir:
        os.makedirs(cache_dir, exist_ok=True)
        np.savez(os.path.join(cache_dir, "raster_%d.npz" % n), **out)
    return out


# --------------------------------------------------------------------------------------------------- anatomy helpers
def seg(p, a, b):
    """Distance from points p to the segment a-b, and the parameter t (0 at a, 1 at b)."""
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1), t


def ramp(d, r):
    return np.clip(d / r, 0.0, 1.0)


class Anatomy:
    """Region groups and the places the marks start from, for the covered texels."""

    def __init__(self, body, R):
        self.b = body
        self.R = R
        ids = body.region_ids
        reg = R["region"].astype(np.int64)
        self.reg = reg
        name = {v: k for k, v in ids.items()}
        names = np.array([name.get(int(r), "none") for r in range(64)])
        self.rname = names[np.minimum(reg, 63)]
        self.P = R["pos"].astype(np.float64)
        self.N = R["nrm"].astype(np.float64)
        self.side = np.where(self.P[:, 0] >= 0.0, 1.0, -1.0)     # +1 the character's left

    def is_(self, *prefixes):
        m = np.zeros(len(self.P), bool)
        for p in prefixes:
            m |= np.char.startswith(self.rname, p)
        return m

    def mirrored(self, name):
        """The joint on this texel's own side (l_/r_)."""
        lj = self.b.j("l_" + name)
        rj = self.b.j("r_" + name)
        return np.where(self.side[:, None] > 0, lj[None, :], rj[None, :])

    def seg_side(self, a_name, b_name):
        A = self.mirrored(a_name)
        B = self.mirrored(b_name)
        ab = B - A
        t = np.clip(np.sum((self.P - A) * ab, 1) / np.maximum(np.sum(ab * ab, 1), 1e-12), 0.0, 1.0)
        return np.linalg.norm(self.P - (A + t[:, None] * ab), axis=1), t

    def point_side(self, p_left):
        q = np.where(self.side[:, None] > 0, np.asarray(p_left)[None, :], np.asarray(p_left)[None, :] * [-1.0, 1.0, 1.0])
        return np.linalg.norm(self.P - q, axis=1)

    def outward(self):
        """How much the skin faces away from the body's mid plane (the outer side of a limb), -1..1."""
        return self.N[:, 0] * self.side

    def eyes_near(self, r):
        d = np.minimum(np.linalg.norm(self.P - self.b.eye_l, axis=1), np.linalg.norm(self.P - self.b.eye_r, axis=1))
        return d < r

    def palm(self):
        """The palm side of the hand and fingers (the back of the hand faces outward-forward in the bind pose)."""
        wr = self.mirrored("wrist")
        ix = self.mirrored("indexa")
        pk = self.mirrored("pinkya")
        md = self.mirrored("middlea")
        along = md - wr
        across = ix - pk
        back = np.cross(along, across) * self.side[:, None]       # the back of the hand's normal, by the joints
        back /= np.maximum(np.linalg.norm(back, axis=1, keepdims=True), 1e-9)
        return np.sum(self.N * back, 1) < -0.15


# -------------------------------------------------------------------------------------------------------- the orders
def order_scales(A):
    """Kind 3 (Dragon-Sea): the amount at which each texel takes scales (0..1; >1 never)."""
    b = A.b
    P = A.P
    o = np.full(len(P), 2.0)
    n = (fbm3(P, 9.0, 31) - 0.5) * 0.26 + (vnoise3(P, 40.0, 33) - 0.5) * 0.08
    arms = A.is_("forearm", "wrist", "hand", "upper_arm")
    # wrists: a ring round the wrist and the base of the back of the hand
    d, t = A.seg_side("wrist", "elbow")
    dw = np.linalg.norm(P - A.mirrored("wrist"), axis=1)
    w = 0.06 + 0.22 * ramp(dw, 0.06) + 0.10 * np.clip(-A.outward(), 0, 1)
    w = np.where(A.is_("hand") & A.palm(), 2.0, w)
    o = np.where(arms & (dw < 0.06), np.minimum(o, w), o)
    # temples and cheekbones (the face a little later and never near the eyes, lips or nostrils)
    head = A.is_("head")
    cheek_l = b.front(0.056, 1.468)
    temple_l = b.front(0.064, 1.508)
    dc = A.point_side(cheek_l)
    dt = A.point_side(temple_l)
    # a thin crescent along the cheekbone's ridge and a small patch at the temple, never round the eye
    f = np.minimum(0.20 + 0.40 * ramp(dc, 0.024), 0.24 + 0.36 * ramp(dt, 0.022))
    f = np.where((np.minimum(dc, dt) < 0.024) & head & ~A.eyes_near(0.021), f, 2.0)
    o = np.minimum(o, f)
    # shoulders and collarbones
    sh = A.mirrored("shoulder") + np.array([0.0, 0.035, 0.0]) + np.c_[A.side * 0.035, np.zeros(len(P)), np.zeros(len(P))]
    ds = np.linalg.norm(P - sh, axis=1)
    top = np.clip(A.N[:, 1] * 0.6 + A.outward() * 0.6, -1, 1)
    s = 0.28 + 0.24 * ramp(ds, 0.11) - 0.04 * top
    shoulder_ok = A.is_("chest_upper", "upper_arm", "neck_lower") & (ds < 0.11)
    o = np.where(shoulder_ok, np.minimum(o, s), o)
    cl_a = A.mirrored("clavicle") + np.array([0.0, -0.005, 0.07])
    cl_b = A.mirrored("shoulder") + np.array([0.0, 0.03, 0.05])
    ab = cl_b - cl_a
    tt = np.clip(np.sum((P - cl_a) * ab, 1) / np.sum(ab * ab, 1), 0, 1)
    dcl = np.linalg.norm(P - (cl_a + tt[:, None] * ab), axis=1)
    c = 0.32 + 0.22 * ramp(dcl, 0.035) + 0.06 * (1 - tt) + (fbm3(P, 30.0, 37) - 0.5) * 0.30
    o = np.where(A.is_("chest_upper", "neck_lower") & (dcl < 0.035) & (A.N[:, 2] > 0.0), np.minimum(o, c), o)
    # outer forearms: from the wrist up toward the elbow, on the outer side
    out = A.outward() + 0.35 * (-A.N[:, 2])
    fa = 0.45 + 0.22 * t + 0.10 * (1 - np.clip(out, 0, 1))
    o = np.where(A.is_("forearm", "wrist") & (out > 0.15) & (d < 0.08), np.minimum(o, fa), o)
    # along the spine, top down, narrow
    sp_a = b.j("neck") + np.array([0.0, 0.0, -0.06])
    sp_b = b.j("spinea") + np.array([0.0, 0.0, -0.10])
    dsp, tsp = seg(P, sp_a, sp_b)
    spn = 0.60 + 0.18 * tsp + 0.25 * ramp(np.abs(P[:, 0]), 0.07)
    o = np.where((A.N[:, 2] < -0.25) & (np.abs(P[:, 0]) < 0.07) & A.is_("neck", "chest", "abdomen", "pelvis") & (P[:, 1] > 0.86), np.minimum(o, spn), o)
    # outer thighs
    dth, tth = A.seg_side("upper_leg", "knee")
    th = 0.74 + 0.16 * tth + 0.15 * (1 - np.clip(A.outward(), 0, 1))
    o = np.where(A.is_("thigh", "pelvis_side") & (A.outward() > 0.35) & (P[:, 1] > 0.45), np.minimum(o, th), o)
    o = o + n
    o = np.where(A.is_("head") & (A.R["col"][:, 1] > 0.2), 2.0, o)      # never the lips
    return o


def order_plates(A):
    """Kind 4 (Stone Children), per texel (the plates take their cell's mean later)."""
    P = A.P
    n = (fbm3(P, 6.0, 51) - 0.5) * 0.14
    o = np.full(len(P), 0.86)
    out = np.clip(A.outward() * 0.7 - A.N[:, 2] * 0.3, -1, 1)
    d, t = A.seg_side("wrist", "elbow")
    o = np.where(A.is_("forearm", "wrist"), 0.02 + 0.09 * t + 0.05 * (1 - out), o)
    o = np.where(A.is_("hand"), 0.05 + 0.07 * ramp(np.linalg.norm(P - A.mirrored("wrist"), axis=1), 0.12), o)
    du, tu = A.seg_side("elbow", "shoulder")
    o = np.where(A.is_("upper_arm"), 0.15 + 0.14 * tu + 0.05 * (1 - out), o)
    o = np.where(A.is_("chest_upper_side"), 0.22 + 0.12 * ramp(np.abs(np.abs(P[:, 0]) - 0.17), 0.12), o)
    head = A.is_("head")
    brow_l = A.b.front(0.030, 1.515)
    cheek_l = A.b.front(0.052, 1.461)
    db = A.point_side(brow_l)
    dc = A.point_side(cheek_l)
    o = np.where(head, 0.90, o)
    o = np.where(head & (db < 0.03), np.minimum(o, 0.30 + 0.15 * ramp(db, 0.03)), o)
    o = np.where(head & (dc < 0.032), np.minimum(o, 0.33 + 0.12 * ramp(dc, 0.032)), o)
    back = A.is_("chest_upper_back", "chest_back", "abdomen_back") | (A.is_("chest", "abdomen") & (A.N[:, 2] < -0.35))
    o = np.where(back, 0.40 + 0.20 * ramp(1.32 - P[:, 1], 0.40), o)
    front = A.is_("chest_upper_front", "chest_front", "chest_side", "abdomen_front", "abdomen_side") & ~back
    o = np.where(front, 0.55 + 0.15 * ramp(1.27 - P[:, 1], 0.32), o)
    legs = A.is_("thigh", "shin", "ankle")
    o = np.where(legs, 0.60 + 0.20 * ramp(np.abs(P[:, 1] - 0.30), 0.45) + 0.05 * (1 - out), o)
    o = np.where(A.is_("neck"), 0.80, o)
    o = np.where(A.is_("pelvis"), 0.84, o)
    o = np.where(A.is_("foot"), 0.82, o)
    o = o + n
    # never: the lips, the eyelids (and round the eyes), the palms, the inner elbows; the nose and mouth last
    never = (head & (A.R["col"][:, 1] > 0.15)) | (head & A.eyes_near(0.0165))
    never |= A.is_("hand") & A.palm()
    de = np.linalg.norm(P - A.mirrored("elbow"), axis=1)
    never |= A.is_("forearm_a", "upper_arm") & (de < 0.06) & (A.N[:, 2] > 0.35)
    mid = head & (np.abs(P[:, 0]) < 0.022) & (P[:, 2] > 0.10) & (P[:, 1] < 1.475)
    o = np.where(mid, np.maximum(o, 0.86), o)
    return np.where(never, 2.0, o)


def order_river(A):
    """Kind 5 (Riverborn): (sheen patches, scale patches)."""
    P = A.P
    big = fbm3(P, 3.2, 71, 3)
    sheen = 0.10 + 0.75 * np.clip((0.78 - big) / 0.5, 0, 1)
    sheen = np.where(A.is_("head") & (A.R["col"][:, 1] > 0.2), 2.0, sheen)
    sc = order_scales(A)
    # keep the temples, the collarbones and the outer forearms of the Dragon-Sea order (a smaller share)
    keep = (A.is_("head") | A.is_("chest_upper", "neck_lower") | A.is_("forearm", "wrist")) & ~A.is_("hand")
    rs = np.where(keep, sc + 0.18, 2.0)
    return sheen, rs


def plate_cells(A, per_m=None):
    """A Voronoi of plates in the bind pose (about 18 per metre on the body, 34 on the face and upper neck so a face
    carries several plates, not one): F2 - F1 in metres, the cell's id and hash."""
    if per_m is None:
        e1, i1, h1 = plate_cells(A, PLATES_PER_M)
        e2, i2, h2 = plate_cells(A, PLATES_PER_M_FACE)
        face = A.is_("head", "neck_upper")
        return np.where(face, e2, e1), np.where(face, i2 + (1 << 40), i1), np.where(face, h2, h1)
    P = A.P
    s = per_m
    q = P * s
    base = np.floor(q).astype(np.int64)
    best1 = np.full(len(P), 1e9)
    best2 = np.full(len(P), 1e9)
    bid = np.zeros(len(P), np.int64)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                c = base + np.array([dx, dy, dz])
                jit = np.stack([_hash3(c[:, 0], c[:, 1], c[:, 2], 101 + k) for k in range(3)], 1)
                site = (c + 0.15 + 0.7 * jit) / s
                d = np.linalg.norm(P - site, axis=1)
                cid = (c[:, 0] + 512) * 1048576 + (c[:, 1] + 512) * 1024 + (c[:, 2] + 512)
                closer = d < best1
                best2 = np.where(closer, best1, np.minimum(best2, d))
                bid = np.where(closer, cid, bid)
                best1 = np.where(closer, d, best1)
    # F2 - F1 is not the distance to the edge; half of it, over the sites' spacing, is close enough for a crack line
    edge = (best2 - best1) * 0.5
    h = _hash3(bid // 1048576, (bid // 1024) % 1024, bid % 1024, 7)
    return edge, bid, h


def per_cell_mean(values, cell_id):
    u, inv = np.unique(cell_id, return_inverse=True)
    v = np.where(values > 1.5, np.nan, values)
    sums = np.zeros(len(u)); cnt = np.zeros(len(u)); never = np.zeros(len(u))
    ok = ~np.isnan(v)
    np.add.at(sums, inv[ok], v[ok])
    np.add.at(cnt, inv[ok], 1)
    m = np.where(cnt > 0, sums / np.maximum(cnt, 1), 2.0)
    return np.where(values > 1.5, 2.0, m[inv])


def gills(A):
    """Three curved slits a side behind the jaw on the upper neck (5 cm long, 9 mm apart): 1 at the core, a lit lip
    above it falling to about 0.4."""
    P = A.P
    out = np.zeros(len(P))
    neck = A.is_("neck_upper", "head")
    ax = A.b.j("neck") * 0.5 + A.b.j("heada") * 0.5
    rel = P - ax
    ang = np.arctan2(rel[:, 0] * A.side, rel[:, 2])          # 0 at the throat, + toward this side, pi at the nape
    rad = np.hypot(rel[:, 0], rel[:, 2])
    h = P[:, 1]
    for k in range(3):
        a0 = 1.42 + 0.17 * k                                   # behind the jaw angle, the next ones further back
        hc = 1.395 - 0.004 * k
        # a gentle arc: the slit leans back toward its top
        a_line = a0 + 1.6 * (h - hc) + 6.0 * (h - hc) ** 2
        arc = np.abs(ang - a_line) * np.maximum(rad, 0.03)    # metres across the slit
        along = np.abs(h - hc) / 0.026
        taper = np.clip(1.0 - along ** 2, 0.0, 1.0)
        core = np.clip(1.0 - arc / (0.0016 + 0.0014 * taper), 0, 1) * (taper > 0)
        lip_off = arc - 0.0032
        lip = np.clip(1.0 - np.abs(lip_off) / 0.0018, 0, 1) * (ang > a_line) * (taper > 0) * 0.4
        out = np.maximum(out, np.maximum(core * np.sqrt(taper), lip * taper))
    return np.where(neck & (h > 1.33) & (h < 1.45), out, 0.0)


def ash_marks(A):
    """The Ancestor-Bound rite marks (markings anyone may wear): R a thumbprint on the brow, G two short fingers of
    ash on each cheekbone, B the backs of the hands; A a dry powder grain."""
    P = A.P
    head = A.is_("head")
    grain = fbm3(P, 260.0, 91, 2)
    thumb_c = A.b.front(0.0, 1.535)
    d = np.linalg.norm((P - thumb_c) * [1.0, 0.85, 1.0], axis=1)
    edge = fbm3(P, 90.0, 93, 2)
    thumb = np.clip((0.0140 + 0.004 * (edge - 0.5) - d) / 0.003, 0, 1)
    # the print's ridges: rings round a point a little below the centre, broken by the grain
    rings = 0.5 + 0.5 * np.cos(np.linalg.norm((P - thumb_c - [0.0, -0.003, 0.0]) * [1.0, 1.25, 1.0], axis=1) * 2 * np.pi / 0.0011)
    thumb = thumb * (0.55 + 0.45 * rings) * (0.7 + 0.6 * grain)
    thumb = np.where(head & (P[:, 2] > 0.08), thumb, 0.0)
    cheeks = np.zeros(len(P))
    for k, off in enumerate((0.0, 0.011)):
        a = A.b.front(0.038, 1.469 - off)
        bpt = A.b.front(0.066, 1.461 - off * 0.8)
        al = np.where(A.side[:, None] > 0, a[None], a[None] * [-1, 1, 1])
        bl = np.where(A.side[:, None] > 0, bpt[None], bpt[None] * [-1, 1, 1])
        ab = bl - al
        t = np.clip(np.sum((P - al) * ab, 1) / np.sum(ab * ab, 1), 0, 1)
        dd = np.linalg.norm(P - (al + t[:, None] * ab), axis=1)
        w = 0.0058 * (1.0 - 0.55 * t) + 0.0012 * (edge - 0.5)
        stroke = np.clip((w - dd) / 0.0018, 0, 1) * (0.55 + 0.45 * (1.0 - t)) * (0.6 + 0.7 * grain)
        cheeks = np.maximum(cheeks, stroke)
    cheeks = np.where(head & ~A.eyes_near(0.017), cheeks, 0.0)
    hands = np.zeros(len(P))
    hb = A.is_("hand") & ~A.palm()
    dh = np.linalg.norm(P - A.mirrored("palm"), axis=1)
    hands = np.where(hb, np.clip((0.05 + 0.02 * (edge - 0.5) - dh) / 0.012, 0, 1) * (0.5 + 0.8 * grain), 0.0)
    return np.clip(np.stack([thumb, cheeks, hands, grain], 1), 0, 1)


def sheen_value(A):
    return fbm3(A.P, 14.0, 111, 3)


# ------------------------------------------------------------------------------------------- scales (shader twin)
# Which way is "down the limb" in the metre UVs, per region group: the torso and head's v grows downward, the limbs'
# toward the hand and foot... measured: the arms' and legs' v grows toward the trunk, so they flip.
def v_down_sign(rname):
    flip = np.char.startswith(rname, "upper_arm") | np.char.startswith(rname, "forearm") | np.char.startswith(rname, "wrist")
    flip |= np.char.startswith(rname, "thigh") | np.char.startswith(rname, "shin") | np.char.startswith(rname, "ankle")
    return np.where(flip, -1.0, 1.0)


def scale_cell(uv, cell):
    """Arched scales in offset rows over metre UVs (u across, v down the limb). Returns (cover 0..1 of the scale's
    body, rim 0..1 toward its free edge, the scale's hash). The shader's `tv_scale_cell` is the same maths."""
    gx = uv[:, 0] / cell[0]
    gy = uv[:, 1] / cell[1]
    best_row = np.full(len(uv), -1e9)
    best_d = np.full(len(uv), 9.0)
    best_h = np.zeros(len(uv))
    row0 = np.floor(gy)
    for dr in (-1, 0, 1):
        r = row0 + dr
        off = np.where(np.mod(r, 2.0) == 1.0, 0.5, 0.0)
        cx0 = np.floor(gx - off)
        for dc in (0, 1):
            cx = cx0 + dc + off
            # the scale hangs from its row line: centre half a row above its free edge
            dx = (gx - (cx + 0.0)) / 0.62
            dy = (gy - (r + 0.15)) / 1.05
            d = np.sqrt(dx * dx + dy * dy)
            inside = (d < 1.0) & (gy >= r - 0.2)
            # a later row (larger r) lies over an earlier one: its free edge (the arch's bottom) covers
            take = inside & (r > best_row)
            best_row = np.where(take, r, best_row)
            best_d = np.where(take, d, best_d)
            best_h = np.where(take, hash2(cx, r), best_h)
    cover = (best_d < 1.0).astype(np.float64)
    rim = np.clip((best_d - 0.62) / 0.38, 0, 1) * cover
    return cover, rim, best_h


# ----------------------------------------------------------------------------------------------------- the writing
def to8(x, scale=255.0):
    return np.clip(np.round(x * scale), 0, 255).astype(np.uint8)


def write_maps(out_dir=OUT_DIR, n=GAME_N, cache=None):
    body = Body()
    R = raster(body, n, cache)
    A = Anatomy(body, R)
    os_ = order_scales(A)
    edge, cid, ch = plate_cells(A)
    op = per_cell_mean(order_plates(A), cid)
    rsheen, rscale = order_river(A)
    gl = gills(A)
    ash = ash_marks(A)
    sv = sheen_value(A)

    def img(chans):
        a = np.zeros((n * n, 4), np.uint8)
        a[R["index"]] = np.stack(chans, 1)
        return Image.fromarray(a.reshape(n, n, 4))

    os.makedirs(out_dir, exist_ok=True)
    order = lambda o: to8(np.where(o > 1.5, 1.0, np.clip(o, 0.0, 254.0 / 255.0)))  # noqa: E731
    img([order(os_), order(op), order(rsheen), order(rscale)]).save(os.path.join(out_dir, "trait_order_tv.png"))
    img([to8(edge * 1000.0 / 25.5), to8(ch), to8(gl), to8(sv)]).save(os.path.join(out_dir, "trait_detail_tv.png"))
    img([to8(ash[:, 0]), to8(ash[:, 1]), to8(ash[:, 2]), to8(ash[:, 3])]).save(os.path.join(out_dir, "ash_marks_tv.png"))
    # the texel's size on the skin, for the record (and the scales' resolution check)
    tri = body.tri
    a3 = np.linalg.norm(np.cross(body.pos[tri[:, 1]] - body.pos[tri[:, 0]], body.pos[tri[:, 2]] - body.pos[tri[:, 0]]), axis=1) * 0.5
    a2 = np.abs(np.cross(body.mh[tri[:, 1]] - body.mh[tri[:, 0]], body.mh[tri[:, 2]] - body.mh[tri[:, 0]])) * 0.5
    reg = np.round(body.code[tri[:, 0], 0]).astype(int) & 63
    texel = {}
    inv = {v: k for k, v in body.region_ids.items()}
    for r in np.unique(reg):
        m = reg == r
        texel[inv[int(r)]] = round(float(np.sqrt(a3[m].sum() / max(a2[m].sum(), 1e-12)) / n * 1000.0), 3)
    meta = {
        "format": "thuyvan.trait_maps", "version": 1,
        "note": "The Thủy Vân peoples' skin traits in body.glb's MakeHuman UV atlas (TEXCOORD_2 / CUSTOM0.xy), built by "
                "tools/thuyvan_art/traits/trait_maps.py from the body's own anatomy (fixed seeds). Order maps: a texel is "
                "marked where order < amount x 255 (255 never). Visual only: no stat is read from any of it.",
        "size": n, "uv": "TEXCOORD_2 (Godot CUSTOM0.xy), row = v * size",
        "files": {
            "trait_order_tv.png": {"R": "scales order (kind 3)", "G": "plates order, one value per plate (kind 4)",
                                    "B": "river sheen order (kind 5)", "A": "river scale-patch order (kind 5)"},
            "trait_detail_tv.png": {"R": "plate crack distance, 0.1 mm per step (0 on the crack)", "G": "plate hash",
                                     "B": "gill slits (255 core, about 100 the lit lip)", "A": "sheen value noise"},
            "ash_marks_tv.png": {"R": "ash thumbprint (brow)", "G": "ash fingers (cheekbones)", "B": "ash on the backs of the hands",
                                  "A": "powder grain"},
        },
        "plates_per_m": PLATES_PER_M, "scale_cell_m": SCALE_CELL, "scale_cell_face_m": SCALE_CELL_FACE,
        "texel_mm_by_region": texel,
    }
    json.dump(meta, open(os.path.join(out_dir, "traits_maps.json"), "w"), indent=1, ensure_ascii=False)
    return meta


if __name__ == "__main__":
    cache = os.environ.get("TRAITS_CACHE")
    m = write_maps(cache=cache)
    print(json.dumps(m["texel_mm_by_region"]))
