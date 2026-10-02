"""Coat textures of the procedural horse, baked with numpy from the body SDF and
procedural fields in the rest pose (no image input, no third-party texture).

For every texel of the body's UV layout the rasterizer gives the rest position, normal
and MikkTSpace tangent frame of the exported mesh. From those:

  horse_coat_normal.png   tangent-space normal (OpenGL, +Y = bitangent): the anatomy the
                          decimated mesh lost (eyelids, nostril rims, lips, bony lower legs,
                          ear rims; the SDF gradient), the ribs, and short-hair streaks along
                          the hair flow
  horse_coat_masks.png    R points (lower legs, ear rims, crest under the mane), G dapples,
                          B countershade (0 belly .. 0.5 .. 1 topline; > 0.86 dorsal stripe),
                          A white markings (star, right hind sock)
  horse_coat_detail.png   R hair luminance streaks, G ambient occlusion (from the SDF),
                          B mealy / soft areas (muzzle, eyes, flank, belly, inner legs),
                          A bare skin and horn (lips, nostrils, eyelid rims, inner ears,
                          chestnuts, ergots)
  horse_coat_flow.png     RG hair direction in tangent space (x 0.5 + 0.5), for anisotropy

Everything is evaluated in the base shape space (anatomy.K undone) so the fields follow the
anatomy. The Godot shader (assets/horse/materials/horse_coat.gdshader) turns the masks into
the coat colours of a variant (bay, brown, black, chestnut, grey, dun).
"""

import math
import time

import numpy as np

import anatomy as A
import sdf

K = np.asarray(A.K, float)


def log(*a):
    print("[coat]", *a, flush=True)


# ---------------------------------------------------------------------------
# Rasterizer
# ---------------------------------------------------------------------------
def rasterize(UV, attrs, R):
    """UV (T, 3, 2) in 0..1 (v up); attrs: name -> (T, 3, k) corner values. Returns
    (mask (R, R) bool, {name: (R, R, k)}) with row 0 = v 0 (bottom); texel centres."""
    out = {n: np.zeros((R, R, a.shape[2]), np.float32) for n, a in attrs.items()}
    mask = np.zeros((R, R), bool)
    P = UV * R - 0.5                          # texel centre (i + 0.5) / R -> i
    lo = np.floor(P.min(1)).astype(int)
    hi = np.ceil(P.max(1)).astype(int)
    lo = np.clip(lo, 0, R - 1)
    hi = np.clip(hi, 0, R - 1)
    for t in range(len(UV)):
        x0, y0 = lo[t]
        x1, y1 = hi[t]
        xs = np.arange(x0, x1 + 1)
        ys = np.arange(y0, y1 + 1)
        X, Y = np.meshgrid(xs, ys)
        a, b, c = P[t]
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        w0 = ((b[1] - c[1]) * (X - c[0]) + (c[0] - b[0]) * (Y - c[1])) / den
        w1 = ((c[1] - a[1]) * (X - c[0]) + (a[0] - c[0]) * (Y - c[1])) / den
        w2 = 1.0 - w0 - w1
        ins = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if not ins.any():
            continue
        yy, xx = Y[ins], X[ins]
        W = np.stack([w0[ins], w1[ins], w2[ins]], 1)
        mask[yy, xx] = True
        for n, a_ in attrs.items():
            out[n][yy, xx] = W @ a_[t]
    return mask, out


def dilate(img, mask, n=12):
    """Extend the islands of img (R, R, k) by n texels (mean of filled neighbours)."""
    img = img.copy()
    m = mask.copy()
    for _ in range(n):
        acc = np.zeros_like(img)
        cnt = np.zeros(m.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            sm = np.roll(np.roll(m, dy, 0), dx, 1)
            acc += np.roll(np.roll(img, dy, 0), dx, 1) * sm[..., None]
            cnt += sm
        new = (~m) & (cnt > 0)
        img[new] = acc[new] / cnt[new][:, None]
        m = m | new
    return img


# ---------------------------------------------------------------------------
# Noise (value noise and cellular noise on a hashed lattice)
# ---------------------------------------------------------------------------
def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float64) / float(0xFFFFFF)


def value_noise(Q, seed=0):
    """Smooth value noise in 0..1 at points Q (n, 3) (lattice spacing 1)."""
    F = np.floor(Q)
    f = Q - F
    i = F.astype(np.int64)
    u = f * f * (3.0 - 2.0 * f)
    acc = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (u[:, 0] if dx else 1 - u[:, 0]) * (u[:, 1] if dy else 1 - u[:, 1]) * (u[:, 2] if dz else 1 - u[:, 2])
                acc = acc + w * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return acc


def fbm(Q, octaves=3, seed=0):
    s, a, tot = 0.0, 1.0, 0.0
    for o in range(octaves):
        s = s + a * value_noise(Q * (2.0 ** o), seed + 17 * o)
        tot += a
        a *= 0.5
    return s / tot


def cellular(Q, seed=0):
    """Distance to the nearest and second-nearest jittered lattice point (F1, F2)."""
    F = np.floor(Q).astype(np.int64)
    f1 = np.full(len(Q), 9.0)
    f2 = np.full(len(Q), 9.0)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                c = F + np.array([dx, dy, dz])
                jit = np.stack([_hash(c[:, 0], c[:, 1], c[:, 2], seed + k) for k in range(3)], 1)
                d = np.linalg.norm(c + 0.15 + 0.7 * jit - Q, axis=1)
                f2 = np.where(d < f1, f1, np.minimum(f2, d))
                f1 = np.minimum(f1, d)
    return f1, f2


def smooth(e0, e1, x):
    return sdf.smoothstep(e0, e1, x)


# ---------------------------------------------------------------------------
# Fields (base shape space)
# ---------------------------------------------------------------------------
def head_coords(B):
    """Authored head coordinates (s along the face before the shortening, h, x)."""
    return A.head_coords(B)


def region_weights(B, Nb):
    """Soft region weights: head, neck, legs (fore / hind lower legs), belly."""
    x, y, z = np.abs(B[:, 0]), B[:, 1], B[:, 2]
    s, h, _ = head_coords(B)
    head = smooth(-0.07, 0.02, s) * smooth(-0.22, -0.16, h) * (y < -0.95)
    neck = smooth(-0.50, -0.62, y) * smooth(0.90, 1.0, z) * (1 - head)
    fore = y < -0.15
    leg_top = np.where(fore, 0.70, 0.62)
    legs = smooth(leg_top, leg_top - 0.10, z)
    legs = np.maximum(legs, smooth(0.78, 0.66, z) * (x > 0.10) * (1 - fore))
    belly = smooth(-0.35, -0.75, Nb[:, 2]) * smooth(0.95, 0.80, z) * (1 - legs)
    return head, neck, legs, belly


def hair_flow(B, Nb):
    """Hair direction (base space, unit, in the tangent plane of Nb)."""
    head, neck, legs, belly = region_weights(B, Nb)
    n = len(B)
    body = np.tile(np.array([0.0, 1.0, -0.38]), (n, 1))
    # neck: down the sides from the crest, towards the shoulder
    nk = np.tile(np.array([0.0, 0.35, -1.0]), (n, 1))
    # face: down the nasal bone, with a whorl on the forehead
    fc = np.tile(A.HEAD_AX, (n, 1))
    wc = np.array(A.hp(0.14, 0.07, 0.0))
    r = B - wc[None, :]
    rn = np.linalg.norm(r, axis=1)[:, None] + 1e-6
    swirl = np.cross(Nb, r / rn) * 0.8 + r / rn
    ww = np.exp(-(rn[:, 0] / 0.035) ** 2)[:, None]
    fc = fc * (1 - ww) + swirl * ww
    lg = np.tile(np.array([0.0, 0.08, -1.0]), (n, 1))
    bl = np.tile(np.array([0.0, 1.0, 0.0]), (n, 1))
    f = body
    for w, v in ((neck, nk), (belly, bl), (legs, lg), (head, fc)):
        f = f * (1 - w[:, None]) + v * w[:, None]
    f = f - (f * Nb).sum(1)[:, None] * Nb
    return f / np.maximum(np.linalg.norm(f, axis=1), 1e-6)[:, None]


def streaks(B, F, seed, across=0.0026, along=0.02):
    """Hair streak noise: fine across the hair, long along it."""
    d = (B * F).sum(1)[:, None]
    Q = B / across - d * F * (1.0 / across - 1.0 / along)
    return 0.65 * value_noise(Q, seed) + 0.35 * value_noise(Q * 2.1, seed + 5)


def masks(B, Nb, P, node):
    """Channel values (n,) in 0..1: points, dapple, shade, white, mealy, skin."""
    x, y, z = np.abs(B[:, 0]), B[:, 1], B[:, 2]
    s, h, hx = head_coords(B)
    head, neck, legs, belly = region_weights(B, Nb)
    fore = y < -0.15
    nz = fbm(B * 18.0, 3, 3)
    # --- points: lower legs (to the knees and hocks, a ragged edge), ear rims and tips,
    # the crest under the mane, the tail head
    top = np.where(fore, 0.455, 0.50) + 0.05 * (nz - 0.5)
    pts = smooth(top + 0.05, top - 0.03, z) * (z < 0.75)
    ear = np.minimum(A._ear(1.0).f(*B.T), A._ear(-1.0).f(*B.T))
    on_ear = smooth(0.006, 0.0, ear)
    ear_tip = on_ear * smooth(1.63, 1.69, z)
    ear_rim = on_ear * smooth(0.55, 0.9, np.abs(Nb @ np.array([0.0, -1.0, 0.0])))
    pts = np.maximum(pts, np.maximum(ear_tip, 0.8 * ear_rim))
    crest = smooth(0.035, 0.012, x) * smooth(-0.45, -0.58, y) * smooth(1.2, 1.3, z) * (1 - head) \
        * smooth(0.2, 0.6, Nb[:, 2])
    pts = np.maximum(pts, crest)
    pts = np.maximum(pts, smooth(0.04, 0.015, x) * smooth(0.64, 0.72, y) * smooth(1.12, 1.2, z))
    # --- dapples: cellular rings on the body, fading on the legs, head and belly
    # round lighter spots in a darker net (dapple grey; faint on bays and chestnuts)
    f1, f2 = cellular(B / 0.075, 11)
    spot = smooth(0.58, 0.12, f1 + 0.14 * (fbm(B * 30.0, 2, 13) - 0.5)) * smooth(0.0, 0.25, f2 - f1)
    dap = spot * (1 - legs) * (1 - 0.7 * head) * (1 - 0.6 * belly) * smooth(0.62, 0.85, z)
    # --- countershade: topline darker, belly / inner legs / throat lighter; dorsal stripe
    back = smooth(1.05, 1.24, z) * smooth(0.1, 0.7, Nb[:, 2]) * (1 - head)
    under = np.maximum(belly, smooth(0.08, 0.02, x) * smooth(0.95, 0.75, z) * (x > -1))
    throat = smooth(-0.10, -0.17, h) * head * smooth(0.05, 0.25, s)
    under = np.maximum(under, throat * 0.7)
    stripe = smooth(0.022, 0.010, x) * smooth(-0.45, -0.3, y) * smooth(0.82, 0.72, y) * smooth(0.5, 0.85, Nb[:, 2])
    shade = np.clip(0.5 + 0.35 * back - 0.45 * under, 0, 1)
    shade = np.where(stripe > 0.5, 0.86 + 0.14 * stripe, np.minimum(shade, 0.85))
    # --- white markings: star on the forehead, sock on the right hind
    sc = np.array(A.hp(0.16, 0.075, 0.0))
    dd = np.linalg.norm((B - sc) * np.array([1.0, 0.8, 1.2]), axis=1) + 0.012 * (fbm(B * 60, 2, 21) - 0.5)
    star = smooth(0.030, 0.022, dd) * smooth(0.05, 0.07, h) * head
    sock_h = 0.17 + 0.02 * np.sin(np.arctan2(B[:, 1] - 0.45, B[:, 0] + 0.12) * 3.0) + 0.012 * (nz - 0.5)
    sock = smooth(sock_h + 0.006, sock_h - 0.006, z) * (B[:, 0] < -0.05) * (y > 0.3)
    white = np.maximum(star, sock)
    # --- mealy / soft areas
    eye_d = np.minimum(np.linalg.norm(B - A._eye_c(1.0), axis=1), np.linalg.norm(B - A._eye_c(-1.0), axis=1))
    muz = smooth(0.40, 0.50, s) * head * smooth(0.08, 0.0, h + 0.02)
    eyes = smooth(0.07, 0.035, eye_d) * head
    flank = np.exp(-(((y - 0.30) / 0.10) ** 2 + ((z - 0.92) / 0.10) ** 2)) * (x > 0.15)
    elbow = np.exp(-(((y + 0.42) / 0.07) ** 2 + ((z - 0.78) / 0.07) ** 2))
    inner = smooth(0.09, 0.04, x) * smooth(0.80, 0.55, z)
    mealy = np.clip(np.maximum.reduce([muz, eyes, flank * 0.8, elbow * 0.6, belly * 0.7, inner]), 0, 1)
    # --- bare skin and horn
    lips = smooth(0.52, 0.56, s) * head * smooth(-0.005, -0.03, h)
    nos = np.zeros(len(B))
    for sg in (1.0, -1.0):
        pn, dn, la = A._nostril_frame(sg)
        nos = np.maximum(nos, smooth(0.034, 0.02, np.linalg.norm(B - pn, axis=1)))
    # (the eyelid rim: a thin dark line round the eyeball, its size with it: user 2026-09-28, "those eyes look insane":
    # fixed at revision 4's eyeball it was a thick black ring round the smaller one)
    lid = smooth(A.EYE_R + 0.0065, A.EYE_R + 0.0015, eye_d) * head
    inear = on_ear * smooth(0.2, 0.7, Nb @ np.array([0.0, -1.0, 0.0])) * smooth(1.60, 1.62, z)
    horn = np.zeros(len(B))
    for sg in (1.0, -1.0):
        m = (lambda p: np.asarray(p, float)) if sg > 0 else (lambda p: np.asarray(A.mirror(p), float))
        jb = {k: np.asarray(v, float) for k, v in A.J_BASE.items()}
        for c, r in ((jb["carpus"] + (-0.045, 0.004, 0.105), 0.03), (jb["hock"] + (-0.040, 0.002, -0.05), 0.028),
                     (jb["f_fetlock"] + (0, 0.054, -0.022), 0.02), (jb["h_fetlock"] + (0, 0.054, -0.022), 0.02)):
            # the legs move rigidly with their girdles (not warped): the horn spot's position
            # in the unwarped base space of the other fields
            cb = A.to_base(np.array(A.SL(m(c))))
            horn = np.maximum(horn, smooth(r, r * 0.6, np.linalg.norm(B - cb, axis=1)))
    skin = np.clip(np.maximum.reduce([lips, nos, lid, inear, horn]), 0, 1)
    out = dict(points=np.clip(pts, 0, 1), dapple=np.clip(dap, 0, 1), shade=shade, white=np.clip(white, 0, 1),
               mealy=mealy, skin=skin)
    # another animal on the horse's rig repaints the channels (the bison: its cape in G, no white markings)
    if hasattr(A, "coat_masks"):
        out = A.coat_masks(B, Nb, out, dict(head=head, neck=neck, legs=legs, belly=belly, noise=nz))
    return out


def ribs(B, Nb):
    """Height (base units) of the rib relief behind the girth, fading up and back."""
    x, y, z = np.abs(B[:, 0]), B[:, 1], B[:, 2]
    phase = (y - 0.35 * (1.05 - z)) / 0.062
    w = smooth(-0.12, 0.02, y) * smooth(0.40, 0.25, y) * smooth(0.72, 0.82, z) * smooth(1.08, 0.95, z) * (x > 0.15)
    return 0.0006 * np.sin(2 * math.pi * phase) * w


def sdf_ao(node, P, N, scale=1.0):
    ds = np.array([0.012, 0.03, 0.06, 0.10, 0.16]) * scale
    ws = np.array([0.30, 0.25, 0.20, 0.15, 0.10])
    occ = np.zeros(len(P))
    for d, w in zip(ds, ws):
        q = P + N * d
        occ += w * np.maximum(0.0, d - node.f(*q.T)) / d
    return np.clip(1.0 - 1.1 * occ, 0.0, 1.0)


# ---------------------------------------------------------------------------
def bake(tri_uv, tri_p, tri_n, tri_t, tri_bs, node, R=2048, chunk=400000):
    """tri_*: (T, 3, k) corner values of the exported body mesh (horse space). Returns
    {name: (R, R, 4) float32 image, rows bottom-up} and a list of check samples."""
    t0 = time.time()
    mask, at = rasterize(tri_uv, {"p": tri_p, "n": tri_n, "t": tri_t, "bs": tri_bs[..., None]}, R)
    log("rasterized %d texels (%.0f%% of %d^2) %.1fs" % (mask.sum(), 100 * mask.mean(), R, time.time() - t0))
    idx = np.nonzero(mask)
    P = at["p"][idx].astype(float)
    N = at["n"][idx].astype(float)
    T = at["t"][idx].astype(float)
    bs = np.sign(at["bs"][idx][:, 0] + 1e-9)
    N /= np.linalg.norm(N, axis=1)[:, None]
    T = T - (T * N).sum(1)[:, None] * N
    T /= np.maximum(np.linalg.norm(T, axis=1), 1e-9)[:, None]
    Bt = np.cross(N, T) * bs[:, None]
    n = len(P)
    out = {k: np.zeros((n, 4), np.float32) for k in ("normal", "masks", "detail", "flow")}
    for a in range(0, n, chunk):
        sl = slice(a, min(n, a + chunk))
        p, nn, tt, bb = P[sl], N[sl], T[sl], Bt[sl]
        B = A.to_base(p)
        # base-space normal (inverse-transpose of the stretch)
        Nb = nn * K
        Nb /= np.linalg.norm(Nb, axis=1)[:, None]
        # anatomy normal from the SDF gradient (horse space)
        # a 3 mm central difference: smooths the kinks lofts have between their segments
        # (they would print as lines of highlights), keeps lids, rims and lips
        g = sdf.gradient(node, p, e=3e-3)
        g /= np.maximum(np.linalg.norm(g, axis=1), 1e-9)[:, None]
        bad = (g * nn).sum(1) < 0.2               # far from the surface / thin parts: keep the mesh normal
        g[bad] = nn[bad]
        # hair streaks and ribs as a height field: tangent-space slope by finite differences
        F = hair_flow(B, Nb)
        eps = 0.0008

        def height(q):
            qb = A.to_base(q)
            return 0.00040 * streaks(qb, F, 7) + ribs(qb, Nb) * 1.0
        dhu = (height(p + tt * eps) - height(p - tt * eps)) / (2 * eps)
        dhv = (height(p + bb * eps) - height(p - bb * eps)) / (2 * eps)
        # SDF normal to tangent space, then add the height slopes (UDN)
        tn = np.stack([(g * tt).sum(1), (g * bb).sum(1), (g * nn).sum(1)], 1)
        tn[:, 0] -= dhu
        tn[:, 1] -= dhv
        tn /= np.linalg.norm(tn, axis=1)[:, None]
        out["normal"][sl, :3] = tn * 0.5 + 0.5
        out["normal"][sl, 3] = 1.0
        mk = masks(B, Nb, p, node)
        out["masks"][sl] = np.stack([mk["points"], mk["dapple"], mk["shade"], mk["white"]], 1)
        hair = streaks(B, F, 31, 0.0022, 0.016)
        mott = fbm(B * 9.0, 3, 41)
        ao = sdf_ao(node, p, g)
        out["detail"][sl] = np.stack([np.clip(0.55 * hair + 0.45 * mott, 0, 1), ao, mk["mealy"], mk["skin"]], 1)
        Fh = F * K                                   # direction back in horse space
        Fh /= np.linalg.norm(Fh, axis=1)[:, None]
        fu, fv = (Fh * tt).sum(1), (Fh * bb).sum(1)
        fl = np.hypot(fu, fv) + 1e-9
        out["flow"][sl] = np.stack([fu / fl * 0.5 + 0.5, fv / fl * 0.5 + 0.5, np.zeros_like(fu), np.ones_like(fu)], 1)
        log("  chunk %d-%d %.1fs" % (sl.start, sl.stop, time.time() - t0))
    imgs = {}
    for k, v in out.items():
        im = np.zeros((R, R, 4), np.float32)
        im[idx] = v
        im = dilate(im, mask, 16)
        imgs[k] = im
    # samples for the Godot convention check: texel uv, expected flow and normal (horse space)
    rng = np.random.default_rng(3)
    pick = rng.choice(n, 24, replace=False)
    samples = []
    for i in pick:
        yy, xx = idx[0][i], idx[1][i]
        f = imgs["flow"][yy, xx, :2] * 2 - 1
        Fh = f[0] * T[i] + f[1] * Bt[i]
        samples.append({"uv": [(xx + 0.5) / R, (yy + 0.5) / R], "p": P[i].tolist(), "n": N[i].tolist(),
                        "flow": (Fh / np.linalg.norm(Fh)).tolist()})
    log("baked %.1fs" % (time.time() - t0))
    return imgs, samples
