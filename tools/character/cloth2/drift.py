"""cloth2 drift: the operations the Drift's sky-crew garments need beyond the shared recipe types (2026-10-02). New
helpers only (recipes.py and garment.py are shared with other garments and stay as they are):

  flare_legs(g, extra, t0, keep)        wide trouser legs (slops): more ease toward the hem, never across the midline
  clip_front_slit(g, z0, z1, w0, w1)    an open slit down the centre front (a shirt's neck slit)
  smooth_fit_offset(g, fit, weight)     a fit takes the reference shape there, moved (the male crotch of the slops)
  wrist_band_zone(g, idx, width)        a wrist band zone cut square to the forearm (not along the limb parameter)
  envelope(g, rows, cols, hits, ...)    cloth draped over whatever the rays meet first from outside (a cape over the
                                        shoulders and arms, a cloak over the coat): one grid in every fit
  cape_rows(...) / hit_bvhs(...)        the rows of polar and level rays an envelope is made of; the surfaces they hit
  boot(g, side, ...)                    a knee boot grown round the leg and the foot itself (the covered cloth surface
                                        stops at the ankle): level rings round the shin and foot, a flat sole; never
                                        across the midline, over only its own side of the garments under it
  rib(g, path, width, height, zone)     a batten standing proud along a path on the garment (the sail cloak's ribs;
                                        `normal` gives its up where the bound faces' normals would twist it)
  patch(g, centre, size, ...)           a sewn-on patch (a raised, rimmed region in a zone: weather_cape)
  tube_piece(g, path, radii, ...)       a rope or cord along points on the garment (rigid on its anchors)
  hook(), coil()                        rigid primitives: a plain hook, a coiled rope (cloth2.hardware frame)
  indexed_parts(g, pieces, base)        one UV part per piece whose U starts at its index (a cell count the cloth
                                        shader can light: the mote belt's windows)

Every piece exists in every fit (the reference fit's topology, each fit's positions), like the rest of cloth2.
"""

import math

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import regions as RG
from cloth2 import hardware as HW
from cloth2.fit import chain_param
from cloth2.mesh import BIG_FIELD, REF, Mesh, smoothstep, unit, vertex_normals
from cloth2.parts import skirt_weights


# ---- small utilities --------------------------------------------------------------------------------------------
def blank_attrs(fits, n):
    """Per-vertex attributes a cloth2 piece carries (the cloth surface's names), zero."""
    A = {"W": np.zeros((n, len(fits.bones)))}
    for k in fits.p_limb:
        A[k] = np.zeros(n)
    return A


def new_mesh(fits, V, F, W, region, zone=0, part=0, A=None):
    """A cloth2 Mesh from positions per fit, faces, weights and per-face region / zone / part."""
    F = np.asarray(F, int)
    n = len(V[REF])
    attrs = blank_attrs(fits, n)
    attrs["W"] = np.asarray(W, float)
    for k, v in (A or {}).items():
        attrs[k] = np.asarray(v, float)
    m = Mesh.__new__(Mesh)
    m.V = {k: np.asarray(v, float) for k, v in V.items()}
    m.F = F
    m.N = {k: vertex_normals(v, F) for k, v in m.V.items()}
    m.A = attrs
    nf = len(F)
    m.fa = {"region": np.broadcast_to(np.asarray(region), (nf,)).astype(int).copy(),
            "zone": np.broadcast_to(np.asarray(zone), (nf,)).astype(int).copy(),
            "part": np.broadcast_to(np.asarray(part), (nf,)).astype(int).copy()}
    return m


def smooth_weights(W, F, iters=2, lam=0.5):
    """Laplacian smoothing of skin weights over a mesh's edges (rows stay normalised)."""
    E = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    E = np.unique(np.sort(E, 1), axis=0)
    E = np.concatenate([E, E[:, ::-1]])
    W = W.copy()
    n = len(W)
    for _ in range(iters):
        acc = np.zeros_like(W)
        cnt = np.zeros(n)
        np.add.at(acc, E[:, 0], W[E[:, 1]])
        np.add.at(cnt, E[:, 0], 1.0)
        W = W * (1 - lam) + lam * acc / np.maximum(cnt, 1.0)[:, None]
    return W / np.maximum(W.sum(1, keepdims=True), 1e-9)


def proxy_weights(fits, P, no_arms=None):
    """Skin weights (and region) at the nearest point of the cloth surface (reference fit) to each point; where
    `no_arms` (bool per point) is set, the nearest point off the arms (a cloak's back beside the arm)."""
    V = fits.CV[REF]
    bv = fits.bvhc[REF]
    keep = np.nonzero(~np.isin(fits.p_region, [RG.REGIONS[r] for r in ARM_REGIONS]))[0]
    bv2 = BVHTree.FromPolygons([tuple(p) for p in V], [tuple(t) for t in fits.pF[keep]], all_triangles=True)
    W = np.zeros((len(P), fits.PW.shape[1]))
    reg = np.zeros(len(P), int)
    for i, p in enumerate(P):
        if no_arms is not None and no_arms[i]:
            loc, _, idx, _ = bv2.find_nearest(Vector(p))
            idx = keep[idx]
        else:
            loc, _, idx, _ = bv.find_nearest(Vector(p))
        t = fits.pF[idx]
        b = HW._bary(np.array(loc), V[t[0]], V[t[1]], V[t[2]])
        W[i] = b @ fits.PW[t]
        reg[i] = fits.p_region[idx]
    return W, reg


def body_faces(fits, regions):
    return np.nonzero(np.isin(fits.freg, [RG.REGIONS[r] for r in regions]))[0]


def body_bvh(fits, fit, faces):
    return BVHTree.FromPolygons([tuple(p) for p in fits.V[fit]], [tuple(t) for t in fits.F[faces]], all_triangles=True)


def body_weights(fits, P, faces):
    """Skin weights and region at the nearest point of the body faces `faces` (reference fit)."""
    bv = body_bvh(fits, REF, faces)
    V = fits.V[REF]
    W = np.zeros((len(P), fits.W.shape[1]))
    reg = np.zeros(len(P), int)
    for i, p in enumerate(P):
        loc, _, idx, _ = bv.find_nearest(Vector(p))
        f = faces[idx]
        t = fits.F[f]
        b = HW._bary(np.array(loc), V[t[0]], V[t[1]], V[t[2]])
        W[i] = b @ fits.W[t]
        reg[i] = fits.freg[f]
    return W, reg


# ---- slops: wide legs ----------------------------------------------------------------------------------------------
def flare_legs(g, extra, t0=0.15, keep=0.010):
    """More ease on the legs of g.m (after g.fit): `extra(t)` (m) along each leg from parameter t0, outward along the
    level part of the normal; on the inner side never closer than `keep` (m) to the body's midline (x = 0), so the
    two legs never cross. Clears the skin again."""
    m = g.m
    for side, sg in (("l", 1.0), ("r", -1.0)):
        mem = m.A["m_leg_" + side]
        t = m.A["t_leg_" + side]
        e = np.asarray(extra(t), float) * smoothstep(t0, t0 + 0.12, t) * smoothstep(0.3, 0.8, mem)
        sel = e > 1e-5
        for k in m.V:
            V = m.V[k]
            n = m.N[k].copy()
            n[:, 2] = 0.0
            n = unit(n)
            inward = np.maximum(-sg * n[:, 0], 0.0)
            room = np.maximum(sg * V[:, 0] - keep, 0.0)
            cap = np.where(inward > 0.05, room / np.maximum(inward, 1e-3), 1.0)
            ee = np.minimum(e, cap)
            V[sel] = V[sel] + n[sel] * ee[sel, None]
            m.V[k] = V
    m.recompute_normals()
    g.fits.clear(m, 0.002)
    return g


def smooth_fit_offset(g, fit, weight, iters=20, lam=0.5):
    """Fit `fit` where weight(P) (reference positions -> 0..1) is 1 takes the reference fit's shape, moved by the
    median offset of the blend round it; smoothed across the blend: the male fit's genitals part the folded cloth of
    a crotch sideways (the cloth proxy goes round them), which opened a slit and a pouch in the front of the slops.
    The genitals are hidden under any garment worn on the legs, so the cloth whose nearest skin is theirs is not
    pushed out of them (the skin the clearance measures has a hole there: its rim crumpled the cloth); the rest of
    the garment is cleared of the skin again."""
    m = g.m
    P0 = m.V[REF]
    D = m.V[fit] - P0
    w = np.clip(np.asarray(weight(P0), float), 0.0, 1.0)
    rim = (w > 0.02) & (w < 0.5)
    if rim.any():
        D = D * (1.0 - w)[:, None] + np.median(D[rim], 0)[None] * w[:, None]
    # smoothing only across the blend (not in the core, whose folds would be pulled apart by its rim)
    wb = 4.0 * w * (1.0 - w)
    E = m.adjacency()
    cnt = np.bincount(E[:, 0], minlength=m.n).astype(float)
    for _ in range(iters):
        acc = np.zeros_like(D)
        np.add.at(acc, E[:, 0], D[E[:, 1]])
        D = D + (lam * wb)[:, None] * (acc / np.maximum(cnt, 1.0)[:, None] - D)
    m.V[fit] = P0 + D
    m.recompute_normals()
    gen = np.zeros(m.n, bool)
    bv = g.fits.bvh[fit]
    for i in np.nonzero(w > 0.0)[0]:
        _, _, fi, _ = bv.find_nearest(Vector(m.V[fit][i]))
        gen[i] = fi is not None and bool(g.fits.gen_face[fi])
    g.fits.clear(m, np.where(gen, -0.05, 0.003))
    return g


def clip_front_slit(g, z0, z1, w0, w1, front_y=-0.03):
    """An open slit down the centre front from height z1 (half-width w1) to z0 (half-width w0): a shirt's neck."""
    P = g.P
    w = np.interp(P[:, 2], [z0, z1], [w0, w1])
    f = np.abs(P[:, 0]) - w + BIG_FIELD * (1.0 - smoothstep(z0 - 0.004, z0, P[:, 2])) + \
        BIG_FIELD * smoothstep(front_y, front_y + 0.03, P[:, 1])
    g.m = g.m.clip(f, 0.0)
    return g


# ---- envelopes: capes and cloaks ---------------------------------------------------------------------------------
ARM_REGIONS = ["upper_arm_l", "forearm_a_l", "forearm_b_l", "forearm_c_l", "wrist_l", "upper_arm_r", "forearm_a_r",
               "forearm_b_r", "forearm_c_r", "wrist_r"]


def hit_bvhs(fits, arms=True, meshes=(), base="cloth"):
    """{fit: BVHTree} of the cloth surface (with or without the arms) and the garment meshes `meshes` (worn under;
    without the arms, their sleeves are left out too)."""
    keep = np.ones(len(fits.pF), bool)
    if not arms:
        keep = ~np.isin(fits.p_region, [RG.REGIONS[r] for r in ARM_REGIONS])
        meshes = [_no_sleeves(m) for m in meshes]
    out = {}
    for k in fits.V:
        if not all(k in m.V for m in meshes):
            continue
        Vs = [(fits.CV if base == "cloth" else fits.PV)[k]]
        Fs = [fits.pF[keep]]
        off = len(Vs[0])
        for m in meshes:
            Vs.append(m.V[k])
            Fs.append(m.F + off)
            off += m.n
        V = np.concatenate(Vs)
        F = np.concatenate(Fs)
        out[k] = BVHTree.FromPolygons([tuple(p) for p in V], [tuple(t) for t in F], all_triangles=True)
    return out


def _no_sleeves(m):
    if "m_arm_l" not in m.A:
        return m
    arm = np.maximum(m.A["m_arm_l"], m.A["m_arm_r"])[m.F].max(1)
    return m.faces_of(arm < 0.5)


def cape_rows(z_c=1.18, phi=(22.0, 90.0), n_polar=8, z_rows=()):
    """Rows of an envelope: polar rays from (0, y, z_c) from phi[0] to phi[1] degrees off the vertical (over the
    shoulders), then level rays from the heights `z_rows` (below z_c). [(z origin, phi deg), ...] top to bottom."""
    rows = [(z_c, float(p)) for p in np.linspace(phi[0], phi[1], n_polar)]
    rows += [(float(z), 90.0) for z in z_rows]
    return rows


def envelope(g, rows, thetas, hits, ease, yc=0.0, smooth=3, reach=0.7, r_min=0.06, hits_by_row=None,
             closed=False, part=0, zone=0, drape=None, folds=None, flare=None, weight_arms=None, rowmax=False):
    """Cloth over whatever is outermost along rays from the vertical axis (rows x columns, a grid in every fit).

    rows: [(z, phi)] (cape_rows): each row's rays start at (0, yc, z) and leave at phi degrees off the vertical;
    thetas: the columns' angles round from the front (+ toward the wearer's left), increasing; hits: {fit: BVHTree}
    (hit_bvhs); hits_by_row: optional [hits per row] (rows below the shoulders that must not meet the arms). The
    outermost hit along each ray (cast from `reach` outside, inward) + `ease` is the cloth; the hit radii are
    smoothed over the grid but never inward (a cape bridges the hollows, never sinks into a bulge).
    drape: m; each level row comes in at most this much on the row above it (cloth falls from the widest point, it
    does not follow the calves). folds: (amplitude m, count round the body, from z): outward folds growing toward the bottom
    row; flare: (m at the bottom row, from z). weight_arms: per row, False to weight the row off the arms.
    rowmax: each row at its outermost radius (a flat pad bridging a gap: the glim's mount).
    Returns the Mesh (vertex (i, j) at i * ncols + j; faces outward) and the radii {fit: (rows, cols)}."""
    fits = g.fits
    R, C = len(rows), len(thetas)
    th = np.radians(np.asarray(thetas, float))
    zr = np.array([z for z, _ in rows])
    level = np.array([abs(ph - 90.0) < 1e-6 for _, ph in rows])
    V = {}
    radii = {}
    for k in fits.V:
        r = np.full((R, C), np.nan)
        D = np.zeros((R, C, 3))
        O = np.zeros((R, C, 3))
        for i, (z, ph) in enumerate(rows):
            bv = (hits_by_row[i] if hits_by_row is not None else hits)[k]
            p = math.radians(ph)
            o = np.array([0.0, yc, z])
            for j in range(C):
                d = np.array([math.sin(p) * math.sin(th[j]), -math.sin(p) * math.cos(th[j]), math.cos(p)])
                D[i, j] = d
                O[i, j] = o
                loc, _, _, _ = bv.ray_cast(Vector(o + d * reach), Vector(-d), reach)
                if loc is not None:
                    r[i, j] = max(float((np.array(loc) - o) @ d), r_min)
        # gaps (a ray that met nothing): the mean of the row
        for i in range(R):
            row = r[i]
            if np.isnan(row).all():
                r[i] = r_min
            else:
                row[np.isnan(row)] = np.nanmean(row)
        if rowmax:
            r[:] = r.max(1, keepdims=True)
        if drape is not None:
            for i in range(1, R):
                if level[i] and level[i - 1]:
                    r[i] = np.maximum(r[i], r[i - 1] - drape)
        raw = r.copy()
        for _ in range(smooth):
            acc = np.zeros_like(r)
            cnt = np.zeros_like(r)
            acc[1:] += r[:-1]
            cnt[1:] += 1
            acc[:-1] += r[1:]
            cnt[:-1] += 1
            if closed:
                acc += np.roll(r, 1, 1) + np.roll(r, -1, 1)
                cnt += 2
            else:
                acc[:, 1:] += r[:, :-1]
                cnt[:, 1:] += 1
                acc[:, :-1] += r[:, 1:]
                cnt[:, :-1] += 1
            s = 0.5 * r + 0.5 * acc / np.maximum(cnt, 1)
            r = np.maximum(s, raw)
        add = np.zeros((R, C))
        zmin = zr.min()
        if flare is not None:
            amt, z0 = flare
            sv = np.clip((z0 - zr) / max(z0 - zmin, 1e-6), 0.0, 1.0) ** 1.4
            add += amt * sv[:, None]
        if folds is not None:
            amp, count, z0 = folds
            sv = np.clip((z0 - zr) / max(z0 - zmin, 1e-6), 0.0, 1.0)
            add += amp * smoothstep(0.0, 1.0, sv)[:, None] * (0.5 + 0.5 * np.sin(count * th[None, :] + 1.3 * sv[:, None]))
        E = np.broadcast_to(np.asarray(ease, float), (R, C)) if np.ndim(ease) < 2 else np.asarray(ease, float)
        V[k] = (O + D * (r + E + add)[..., None]).reshape(-1, 3)
        radii[k] = r
    F = []
    jmax = C if closed else C - 1
    for i in range(R - 1):
        for j in range(jmax):
            j2 = (j + 1) % C
            a, b, c, d = i * C + j, i * C + j2, (i + 1) * C + j2, (i + 1) * C + j
            F += [(a, b, c), (a, c, d)]
    F = np.array(F, int)
    P = V[REF]
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    out_dir = P[F].mean(1) - np.array([0.0, yc, 0.0])
    out_dir[:, 2] = 0.0
    if ((fn * out_dir).sum(1) < 0).mean() > 0.5:
        F = F[:, ::-1].copy()
    no_arms = None
    if weight_arms is not None:
        no_arms = np.repeat(~np.asarray(weight_arms, bool), C)
    W, reg_v = proxy_weights(fits, P, no_arms)
    W = smooth_weights(W, F, 3)
    reg_f = reg_v[F[:, 0]]
    A = {"_row": np.repeat(np.arange(R, dtype=float), C), "_col": np.tile(np.arange(C, dtype=float), R),
         "_th": np.tile(np.asarray(thetas, float), R)}
    m = new_mesh(fits, V, F, W, reg_f, zone, part, A)
    return m, radii


def drop_attrs(m, names=("_row", "_col", "_th")):
    """Removes the scratch attributes an envelope carries (before other pieces are joined to it)."""
    for n in names:
        m.A.pop(n, None)
    return m


def hang_weights(fits, m, z_top, z_full=None, where=None):
    """The vertices of m below z_top go over to the skirt panels (parts.skirt_weights) from z_top down to z_full,
    each from the weights of the nearest vertex at z_top above it (its column's top): a long cloak's back swings
    with the coat skirts and never splits along the legs."""
    from cloth2.garment import SKIRT_Z_FULL
    z_full = SKIRT_Z_FULL if z_full is None else z_full
    P = m.V[REF]
    low = P[:, 2] < z_top
    if where is not None:
        low &= np.asarray(where(P), bool)
    if not low.any():
        return m
    top = (np.abs(P[:, 2] - z_top) < 0.05) & ~low
    if not top.any():
        top = ~low
    ti = np.nonzero(top)[0]
    W = m.A["W"].copy()
    for i in np.nonzero(low)[0]:
        q = P[ti] - P[i]
        q[:, 2] *= 0.15            # the nearest above it: mostly by the angle round the body
        j = ti[np.argmin((q ** 2).sum(1))]
        W[i] = W[j]
    W[low] = skirt_weights(fits, P[low], W[low], z_top, z_full)
    m.A["W"] = W
    return m


# ---- boots ---------------------------------------------------------------------------------------------------------
LEG_REGIONS = ["foot_%s", "ankle_%s", "shin_lower_%s", "shin_upper_%s", "thigh_lower_%s"]


def boot(g, side, z_rows, cols=24, ease=None, obstacles=(), smooth=2, foot_y=None, reach=0.22, part=10,
         sole_z=0.0035, midline_keep=0.012):
    """A boot round the leg and foot of `side` ('l' / 'r'): level rings at the heights `z_rows` (top to bottom), the
    rays cast inward from outside toward a centre line that runs down the shin and then forward to the middle of the
    foot, outermost hit on the body's own leg and foot (full resolution) and the garments `obstacles` (worn under,
    e.g. the breeches' knee band); `ease(z)` (m) off it; a flat sole closing the bottom ring at sole_z. Returns the
    boot Mesh (zone 0; the sole faces zone 0 too, part + 2)."""
    fits = g.fits
    J = fits.J
    knee, ankle = J[side + "_knee"], J[side + "_ankle"]
    heel, ball = J[side + "_heel"], J[side + "_ball"]
    faces = body_faces(fits, [r % side for r in LEG_REGIONS])
    fy = foot_y if foot_y is not None else (heel[1] + ball[1]) / 2.0 - 0.012
    zs = np.asarray(z_rows, float)

    def centre(z):
        u = np.clip((z - ankle[2]) / (knee[2] - ankle[2]), 0.0, 1.0)
        c = ankle + (knee - ankle) * u
        w = smoothstep(ankle[2] + 0.07, ankle[2] - 0.035, z)        # 0 on the shin, 1 at the sole: the foot's middle
        return np.array([c[0], c[1] + (fy - c[1]) * w, z])
    th = 2 * np.pi * np.arange(cols) / cols
    sg = 1.0 if side == "l" else -1.0
    # only the obstacles' faces on this leg's side: a ray cast in from the inner side starts over the other leg, whose
    # breeches would otherwise be its outermost hit (the two boots' tops met between the knees)
    ob_faces = [ob.F[(ob.V[REF][ob.F].mean(1)[:, 0] * sg) > 0.0] for ob in obstacles]
    V = {}
    for k in fits.V:
        bvs = [body_bvh(fits, k, faces)]
        for ob, obF in zip(obstacles, ob_faces):
            bvs.append(BVHTree.FromPolygons([tuple(p) for p in ob.V[k]], [tuple(t) for t in obF], all_triangles=True))
        r = np.zeros((len(zs), cols))
        O = np.zeros((len(zs), cols, 3))
        D = np.zeros((len(zs), cols, 3))
        for i, z in enumerate(zs):
            c = centre(z)
            for j in range(cols):
                d = np.array([math.sin(th[j]), -math.cos(th[j]), 0.0])
                O[i, j], D[i, j] = c, d
                best = None
                for bv in bvs:
                    # a little band of heights and angles round the ring's own: the outermost of it (the toes'
                    # tips fall between the columns and between the rings)
                    for dz in (-0.004, 0.0, 0.004):
                        for da in (-0.5, 0.0, 0.5):
                            a2 = th[j] + da * (2 * np.pi / cols)
                            d2 = np.array([math.sin(a2), -math.cos(a2), 0.0])
                            o2 = c + np.array([0.0, 0.0, dz])
                            loc, _, _, _ = bv.ray_cast(Vector(o2 + d2 * reach), Vector(-d2), reach)
                            if loc is not None:
                                rr = float((np.array(loc) - o2) @ d)
                                best = rr if best is None else max(best, rr)
                r[i, j] = best if best is not None else np.nan
        for i in range(len(zs)):
            miss = np.isnan(r[i])
            if not miss.any():
                continue
            if i > 0:
                r[i][miss] = r[i - 1][miss]          # (a ray past the toes' tips: the ring above's reach)
            elif miss.all():
                r[i] = 0.03
            else:
                r[i][miss] = np.nanmin(r[i])
        raw = r.copy()
        for _ in range(smooth):
            s = 0.5 * r + 0.25 * (np.roll(r, 1, 1) + np.roll(r, -1, 1))
            s[1:-1] = 0.6 * s[1:-1] + 0.2 * (r[:-2] + r[2:])
            r = np.maximum(s, raw)
        e = np.array([ease(z) for z in zs]) if callable(ease) else np.full(len(zs), 0.005 if ease is None else ease)
        P = O + D * (r + e[:, None])[..., None]
        P[..., 0] = sg * np.maximum(sg * P[..., 0], midline_keep)       # never across the midline
        P[-1, :, 2] = np.maximum(P[-1, :, 2], sole_z)
        sole_c = P[-1].mean(0)
        sole_c[2] = sole_z
        V[k] = np.concatenate([P.reshape(-1, 3), sole_c[None]])
    R = len(zs)
    F = []
    for i in range(R - 1):
        for j in range(cols):
            j2 = (j + 1) % cols
            a, b, c_, d_ = i * cols + j, i * cols + j2, (i + 1) * cols + j2, (i + 1) * cols + j
            F += [(a, b, c_), (a, c_, d_)]
    nwall = len(F)
    ctr = R * cols
    for j in range(cols):
        F.append(((R - 1) * cols + j, ctr, (R - 1) * cols + (j + 1) % cols))
    F = np.array(F, int)
    P = V[REF]
    fn = np.cross(P[F[:nwall, 1]] - P[F[:nwall, 0]], P[F[:nwall, 2]] - P[F[:nwall, 0]])
    cen = np.array([centre(z) for z in P[F[:nwall, 0], 2]])
    if ((fn * (P[F[:nwall]].mean(1) - cen)).sum(1) < 0).mean() > 0.5:
        F[:nwall] = F[:nwall, ::-1]
    fs = F[nwall:]
    fn2 = np.cross(P[fs[:, 1]] - P[fs[:, 0]], P[fs[:, 2]] - P[fs[:, 0]])
    if (fn2[:, 2] > 0).mean() > 0.5:
        F[nwall:] = fs[:, ::-1]
    W, reg_v = body_weights(fits, P, faces)
    W = smooth_weights(W, F, 2)
    t, _ = chain_param(P, fits.leg(side))
    A = {"m_leg_" + side: np.ones(len(P)), "t_leg_" + side: t}
    part_f = np.full(len(F), part)
    part_f[nwall:] = part + 2
    reg_f = reg_v[F[:, 0]]
    return new_mesh(fits, V, F, W, reg_f, 0, part_f, A)


# ---- pieces along the garment's own surface -------------------------------------------------------------------------
def surface_points(m, P, normal_hint=None):
    """The nearest points of mesh m (reference fit) to P, as a hardware.Binding (positions in every fit)."""
    return HW.Binding(m, np.asarray(P, float))


def rib(g, path, width, height, zone, part=8, segs=5, end_taper=0.25, normal=None):
    """A batten standing proud of the garment along `path` (points near its surface, reference fit): a half-round
    section `width` wide and `height` high, bound to the garment's faces in every fit, tapering at both ends.
    `normal(P) -> N`: the batten's up direction at its points (default the bound faces' normals; a path crossing a
    raised band or a rim takes the rim's sideways normal there and twists)."""
    m = g.m
    P = np.asarray(path, float)
    b = HW.Binding(m, P)
    k = len(P)
    s = np.linspace(0, 1, k)
    taper = np.minimum(1.0, np.minimum(s, 1 - s) / max(end_taper, 1e-3)) ** 0.5
    taper = 0.35 + 0.65 * taper
    ang = np.linspace(0.0, np.pi, segs)
    prof = np.stack([-np.cos(ang) * 0.5, np.sin(ang)], 1)       # (across, up) of the half-round
    V = {}
    for fit in m.V:
        p, n = b.at(m, fit)
        if normal is not None:
            n = unit(np.asarray(normal(p), float))
        t = unit(np.gradient(p, axis=0))
        sd = unit(np.cross(n, t))
        rows = []
        for i in range(k):
            rows.append(p[i] + sd[i] * (prof[:, 0] * width * taper[i])[:, None] + n[i] * (prof[:, 1] * height * taper[i] + 0.0006)[:, None])
        V[fit] = np.concatenate(rows)
    F = []
    for i in range(k - 1):
        for j in range(segs - 1):
            a, b_, c, d = i * segs + j, i * segs + j + 1, (i + 1) * segs + j + 1, (i + 1) * segs + j
            F += [(a, b_, c), (a, c, d)]
    F = np.array(F, int)
    Pr = V[REF]
    _, n0 = b.at(m, REF)
    fn = np.cross(Pr[F[:, 1]] - Pr[F[:, 0]], Pr[F[:, 2]] - Pr[F[:, 0]])
    outward = Pr[F].mean(1) - np.repeat(b.at(m, REF)[0], 2 * (segs - 1), axis=0)[:len(F)]
    if ((fn * outward).sum(1) < 0).mean() > 0.5:
        F = F[:, ::-1].copy()
    W = np.repeat(b.weights(m), segs, axis=0)
    A = {name: np.repeat(b.attr(m, name), segs, axis=0) for name in m.A if name != "W"}
    region = np.repeat(b.face_attr(m, "region"), segs)[F[:, 0]]
    return g.add(HW.piece_mesh(m, V, F, W, region, zone, part, A))


def tube_piece(g, path, radius, zone, part=8, segs=6, lift=0.0, closed_ends=True):
    """A cord or rope along `path` (points near the garment's surface, reference fit), bound to the garment's faces in
    every fit, `lift` (m) off it."""
    m = g.m
    P = np.asarray(path, float)
    b = HW.Binding(m, P)
    k = len(P)
    rad = np.broadcast_to(np.asarray(radius, float), (k,))
    th = 2 * np.pi * np.arange(segs) / segs
    V = {}
    for fit in m.V:
        p, n = b.at(m, fit)
        t = unit(np.gradient(p, axis=0))
        sd = unit(np.cross(n, t))
        up = np.cross(t, sd)
        c = p + n * (lift + rad[:, None])
        rows = [c[i] + rad[i] * (np.cos(th)[:, None] * sd[i] + np.sin(th)[:, None] * up[i]) for i in range(k)]
        V[fit] = np.concatenate(rows + [c[:1], c[-1:]])
    F = []
    for i in range(k - 1):
        for j in range(segs):
            j2 = (j + 1) % segs
            a, b_, c_, d = i * segs + j, i * segs + j2, (i + 1) * segs + j2, (i + 1) * segs + j
            F += [(a, b_, c_), (a, c_, d)]
    if closed_ends:
        e0, e1 = k * segs, k * segs + 1
        for j in range(segs):
            j2 = (j + 1) % segs
            F.append((e0, j2, j))
            F.append((e1, (k - 1) * segs + j, (k - 1) * segs + j2))
    F = np.array(F, int)
    Pr = V[REF]
    fn = np.cross(Pr[F[:, 1]] - Pr[F[:, 0]], Pr[F[:, 2]] - Pr[F[:, 0]])
    axis_pt = np.concatenate([np.repeat(b.at(m, REF)[0], segs, axis=0), b.at(m, REF)[0][:1], b.at(m, REF)[0][-1:]])
    if ((fn * (Pr[F].mean(1) - axis_pt[F[:, 0]])).sum(1) < 0).mean() > 0.5:
        F = F[:, ::-1].copy()
    W = np.concatenate([np.repeat(b.weights(m), segs, axis=0), b.weights(m)[:1], b.weights(m)[-1:]])
    A = {name: np.concatenate([np.repeat(b.attr(m, name), segs, axis=0), b.attr(m, name)[:1], b.attr(m, name)[-1:]])
         for name in m.A if name != "W"}
    region = np.concatenate([np.repeat(b.face_attr(m, "region"), segs), b.face_attr(m, "region")[:2]])[F[:, 0]]
    return g.add(HW.piece_mesh(m, V, F, W, region, zone, part, A))


def patch(g, centre, half, zone, h=0.0016, spin=0.0, up=(0.0, 0.0, 1.0)):
    """A sewn-on patch: the garment's faces within a rectangle (half sizes `half` (u, v) m) round `centre` (a point on
    its surface, reference fit), u level round the body, v up, turned `spin` degrees, raised h with a rim in `zone`."""
    m = g.m
    c = np.asarray(centre, float)
    bv = HW._bvh(m.V[REF], m.F)
    loc, nrm, _, _ = bv.find_nearest(Vector(c))
    c, n = np.array(loc), unit(np.array(nrm))
    v = np.asarray(up, float) - n * (np.asarray(up, float) @ n)
    v = unit(v)
    u = np.cross(v, n)
    a = math.radians(spin)
    u, v = u * math.cos(a) + v * math.sin(a), -u * math.sin(a) + v * math.cos(a)

    def f(P):
        q = P - c
        return np.maximum(np.abs(q @ u) - half[0], np.abs(q @ v) - half[1]) + \
            BIG_FIELD * smoothstep(0.02, 0.05, np.abs(q @ n))
    g.raised(f, h, zone)
    return g


# ---- rigid primitives (hardware frame: x across, y up, z out of the surface) ----------------------------------------
def _sweep(path, radius, segs=6):
    """A closed tube along a polyline in the local frame: (V, F)."""
    path = np.asarray(path, float)
    k = len(path)
    T = unit(np.gradient(path, axis=0))
    V = []
    for i in range(k):
        ref = np.array([0.0, 0.0, 1.0]) if abs(T[i][2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        u = unit(np.cross(T[i], ref))
        w = np.cross(T[i], u)
        for a in 2 * np.pi * np.arange(segs) / segs:
            V.append(path[i] + radius * (math.cos(a) * u + math.sin(a) * w))
    V.append(path[0])
    V.append(path[-1])
    F = []
    for i in range(k - 1):
        for j in range(segs):
            j2 = (j + 1) % segs
            a, b, c, d = i * segs + j, i * segs + j2, (i + 1) * segs + j2, (i + 1) * segs + j
            F += [(a, b, c), (a, c, d)]
    e0, e1 = k * segs, k * segs + 1
    for j in range(segs):
        j2 = (j + 1) % segs
        F.append((e0, j2, j))
        F.append((e1, (k - 1) * segs + j, (k - 1) * segs + j2))
    V = np.array(V, float)
    F = np.array(F, int)
    # outward
    ctr = np.concatenate([np.repeat(path, segs, axis=0), path[:1], path[-1:]])
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    if ((fn * (V[F].mean(1) - ctr[F[:, 0]])).sum(1) < 0).mean() > 0.5:
        F = F[:, ::-1].copy()
    return V, F


def hook(r=0.011, wire=0.0024, shank=0.032, segs=6):
    """A plain open hook (forged, no spring: period-safe), lying in the surface plane: the shank up, the bill below
    curving up again; the eye at the shank's top."""
    pts = [[0.0, shank, 0.0], [0.0, shank * 0.5, 0.0], [0.0, 0.0, 0.0]]
    for a in np.linspace(0.0, np.pi * 1.15, 9)[1:]:
        pts.append([r - r * math.cos(a), -r * math.sin(a), 0.0])
    V, F = _sweep(np.array(pts) + [0.0, 0.0, wire], wire, segs)
    eye = HW.translate(HW.ring(0.0055, wire * 0.9, 10, 4), (0.0, shank + 0.005, 0.0))
    return HW.merge([(V, F), eye])


def coil(r=0.062, rope=0.0065, turns=3, spread=0.006, segs=22, tube_segs=6):
    """A coiled rope lying on the surface: `turns` rings of radius r, each a little farther out and lower."""
    parts = []
    for i in range(turns):
        Vt, Ft = HW.ring(r - i * 0.003, rope, segs, tube_segs, z0=rope + i * spread * 0.9)
        parts.append(HW.translate((Vt, Ft), (i * 0.004, -i * spread, 0.0)))
    return HW.merge(parts)


def indexed_parts(g, base, count, centres, u_dirs, v_dirs):
    """UV parts base .. base + count - 1, one per piece: planar, U = the piece's index + 0.5 at its centre (the cloth
    shader can light the first n of them: floor(UV.x) < n). Call after g.uv()."""
    for i in range(count):
        ud = unit(np.asarray(u_dirs[i], float))
        o = np.asarray(centres[i], float) - ud * (i + 0.5)
        g.uvparts[base + i] = ("planar", o, ud, unit(np.asarray(v_dirs[i], float)))
    return g


# ---- tailoring additions ----------------------------------------------------------------------------------------------
def stand_collar(g, height=0.03, lean=0.25, zone=1, rings=2, z_min=None, front=None):
    """A standing collar grown from the neckline only (Garment.stand_collar grows it from every edge above a height,
    which on an open front raises the fronts' top edges too): the boundary above z_min (default the neck's root
    plane less 9 cm, as Garment.stand_collar) that is not on the front opening (`front`: a select(P) of the opening's
    edges, e.g. front_edge_select)."""
    from cloth2 import trims as TR
    a, b, z0, tilt, yc, dip, dip_width = g._neck
    th = np.radians(tilt)
    up = np.array([0.0, -np.sin(th), np.cos(th)])
    z_min = z0 - 0.09 if z_min is None else z_min

    def disp(fit, P0, N0, s):
        inward = np.stack([-P0[:, 0], yc - P0[:, 1], np.zeros(len(P0))], 1)
        inward = inward / np.maximum(np.linalg.norm(inward, axis=1, keepdims=True), 1e-9)
        return (up[None] + inward * lean) * (height * s)

    def sel(P):
        s = P[:, 2] > z_min
        if front is not None:
            s &= ~np.asarray(front(P), bool)
        return s
    piece = TR.extrude(g.m, sel, disp, rings=rings, zone=zone)
    if piece is not None:
        g.add(piece)
    return g


def cuff_slit(g, length=0.07, around=110.0, half=0.003, limbs=("arm_l", "arm_r")):
    """A slit up the sleeve from its end, `length` (m) long, `around` degrees round from the arm's outer side toward
    the back (the hind-arm seam), `half` (m) half-width: a sea jacket's slit cuffs."""
    end = g._sleeve[0]
    for lb in limbs:
        side = lb[-1]
        sg = 1.0 if side == "l" else -1.0
        ch = g.fits.arm(side)
        L = np.linalg.norm(ch[1] - ch[0]) + np.linalg.norm(ch[2] - ch[1])
        ax = unit(ch[2] - ch[1])
        outer = np.array([sg, 0.0, 0.0])
        outer = unit(outer - ax * (outer @ ax))
        back = np.cross(ax, outer) * (-sg)
        P = g.P
        q = P - ch[1]
        q = q - np.outer(q @ ax, ax)
        ang = np.degrees(np.arctan2(q @ back, q @ outer))
        r = np.linalg.norm(q, axis=1)
        dang = np.abs((ang - around + 180.0) % 360.0 - 180.0)
        t = g.m.A["t_" + lb]
        mem = g.m.A["m_" + lb]
        t0 = end - length / L
        f = np.radians(dang) * r - half + BIG_FIELD * (1.0 - smoothstep(0.3, 0.6, mem)) + \
            BIG_FIELD * (1.0 - smoothstep(t0 - 0.004, t0, t))
        g.m = g.m.clip(f, 0.0)
    return g


def wrist_band_zone(g, idx, width, limbs=("arm_l", "arm_r")):
    """Zone `idx` for a band `width` (m) up the sleeve from its end, cut square to the forearm (Garment.zone's limb
    parameter t rides on the vertices, which the fit's smoothing slid along the sleeve: its border zigzagged)."""
    for lb in limbs:
        side = lb[-1]
        ch = g.fits.arm(side)
        ax = unit(ch[2] - ch[1])
        mem = g.m.A["m_" + lb]
        P = g.P
        u = (P - ch[1]) @ ax
        be, onb = g.m.boundary()
        end = onb & (mem > 0.5) & (g.m.A["t_" + lb] > 0.6)
        if not end.any():
            continue
        u0 = float(np.median(u[end])) - width
        g.m = g.m.split((u - u0) + BIG_FIELD * (1.0 - smoothstep(0.3, 0.6, mem)), 0.0)
        P = g.P
        uf = ((P - ch[1]) @ ax)[g.m.F].mean(1)
        memf = g.m.A["m_" + lb][g.m.F].min(1)
        g.m.fa["zone"][(memf > 0.5) & (uf > u0)] = idx
    return g


def front_edge_select(g, z_lo, z_hi=1.40, tol=0.008, front_y=-0.02):
    """select(P) for the front opening's edges (Garment.opening's table) between two heights."""
    def sel(P):
        w = g.opening_w(P[:, 2])
        return (P[:, 1] < front_y) & (P[:, 2] > z_lo) & (P[:, 2] < z_hi) & (np.abs(np.abs(P[:, 0]) - w) < tol)
    return sel


# ---- head pieces (rigid on headb, placed by the head affine like cloth2.hats) ------------------------------------------
def frame_z(axis, hint=(0.0, 0.0, 1.0)):
    """A rotation (3, 3) whose third column is `axis` (columns x, y, z)."""
    z = unit(np.asarray(axis, float))
    h = np.asarray(hint, float)
    if abs(h @ z) > 0.95:
        h = np.array([1.0, 0.0, 0.0])
    x = unit(np.cross(h, z))
    y = np.cross(z, x)
    return np.stack([x, y, z], 1)


def head_rigid(g, prim, origin, axis, zone, part=6, hint=(0.0, 0.0, 1.0)):
    """A rigid primitive (V, F in its own frame, z its axis) at `origin` with its z along `axis` (reference fit, world
    coordinates), rigid on headb in every fit (cloth2.hats.rigid_mesh); joined to g."""
    from cloth2 import hats as HT
    V, F = prim
    R = frame_z(axis, hint)
    Vw = np.asarray(origin, float) + np.asarray(V, float) @ R.T
    return g.add(HT.rigid_mesh(g.fits, g.m.A, Vw, F, zone, part))


def scalp_path(g, centre, dirs, lift):
    """Points over the head: rays from `centre` (reference fit) along `dirs` hit the scalp, each lifted by `lift` (m,
    per point) along its ray: a cap's tail lying on the cap."""
    bv = g.fits.bvh[REF]
    out = []
    for d, l in zip(np.asarray(dirs, float), np.broadcast_to(np.asarray(lift, float), (len(dirs),))):
        d = unit(d)
        loc, _, _, _ = bv.ray_cast(Vector(centre), Vector(d), 0.4)
        r = float((np.array(loc) - centre) @ d) if loc is not None else 0.1
        out.append(np.asarray(centre, float) + d * (r + l))
    return np.array(out)
