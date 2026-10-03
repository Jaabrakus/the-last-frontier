"""cloth2 hats: rigid felt hats and soft caps on the MakeHuman head, in every fit (2026-10-02).

The covered cloth surface stops at the neck (cloth2.fit COVERED), so headwear is placed on the body's head itself:

  aff = head_affines(fits)               # per fit: (centre, per-axis scale) of the cranium relative to the reference
                                         #   fit; a rigid hat is that affine copy of itself in every fit (a hat never
                                         #   bends, it sits on the bigger or smaller head)
  m = rigid_hat(g, style)                # a felt hat built in its own frame (TRICORNE, ROUND_HAT: the old
                                         #   garments/military_lib/_hats.py and militia/_hats.py ported to numpy),
                                         #   placed on headb, weighted 1.0 to headb
  m = head_grid(fits, ...)               # a soft cap: rays from inside the cranium hit the scalp in every fit (the same
                                         #   grid, so the same topology), offset by an ease, weighted to headb
  piece = tube(fits, template, path, radii)   # a knitted tail (the tuque's crown), rigid on headb

Hair under a hat: the hair glbs' `hat_fit` shape presses the hair above the hat band plane (hair/_common.CROWN_P /
CROWN_N) to at most 6.5 mm off the v2 cranium (lib/pipeline.HAT_FIT_OFFSET; the v3 scalp lies 1 mm under it), and
the entry's hides_hair_zones hides the crown zone. So a crown or cap clears the scalp by >= HAIR_CLEAR above the band
plane; `scalp_clearance` measures it (the build prints it).
"""

import math

import numpy as np
from mathutils import Vector

from lib import regions as RG
from cloth2.mesh import REF, Mesh, unit, vertex_normals

HAIR_CLEAR = 0.0085          # a hat's inside over the scalp above the band plane: pressed hair 6.5 mm + 1 mm + margin
CROWN_P = np.array([0.0, -0.03, 1.545])          # hair/_common: the hat band plane (hair crown zone above it)
CROWN_N = unit(np.array([0.0, -0.12, 1.0]))
HAT_CENTER = np.array([0.0, -0.028, 0.104])      # the crown base centre relative to headb (the legacy hats)

TRICORNE = {"crown_a": 0.080, "crown_b": 0.102, "crown_h": 0.062, "brim_r": 0.178, "chord": 0.104, "fold": 78.0,
            "fold_soft": 0.35, "tilt": -7.0, "lower": 0.0, "tape_w": 0.016, "thick": 0.0045, "segs": 36,
            "rings": 5, "cockade": "left", "cockade_r": 0.024, "loop": True, "button": True}
ROUND_HAT = {"crown_a": 0.080, "crown_b": 0.102, "crown_h": 0.075, "brim_r": 0.150, "chord": None, "fold": 0.0,
             "fold_soft": 0.0, "tilt": -5.0, "lower": 0.0, "tape_w": 0.0, "thick": 0.004, "segs": 36, "rings": 4,
             "droop": 0.012, "band_h": 0.016, "cockade": None, "loop": False, "button": False}


# ---- the head in every fit ----------------------------------------------------------------------------------------
def head_vertices(fits, z_min=1.50):
    """Ids of the body's head vertices above z_min (reference fit): the cranium."""
    hv = np.unique(fits.F[fits.freg == RG.REGIONS["head"]])
    return hv[fits.V[REF][hv, 2] > z_min]


def head_affines(fits, z_min=1.50):
    """{fit: (c_ref, c_fit, scale (3,))}: the cranium of each fit as an axis-aligned affine of the reference one."""
    ids = head_vertices(fits, z_min)
    P0 = fits.V[REF][ids]
    c0 = P0.mean(0)
    s0 = P0.std(0)
    out = {}
    for k, V in fits.V.items():
        P = V[ids]
        out[k] = (c0, P.mean(0), P.std(0) / np.maximum(s0, 1e-9))
    return out


def apply_affine(aff, P, fit):
    c0, c1, s = aff[fit]
    return c1 + (np.asarray(P, float) - c0) * s


def headb(fits):
    return fits.J["headb"]


def scalp_clearance(fits, V_by_fit, sel=None, above_band=True):
    """{fit: (min, 5th percentile) distance (m) of the given vertices to the scalp} (only those above the hat band
    plane when above_band): the room left for the pressed hair."""
    out = {}
    for k, V in V_by_fit.items():
        if k not in fits.bvh:
            continue
        P = V if sel is None else V[sel]
        if above_band:
            P = P[((P - CROWN_P) @ CROWN_N) > -0.002]
        if not len(P):
            continue
        d, _, _ = fits.dist(k, P)
        out[k] = (float(d.min()), float(np.percentile(d, 5)))
    return out


def rigid_mesh(fits, template_attrs, V_ref, F, zone, part, bone="headb", region="head"):
    """A rigid head piece: V_ref placed in every fit by the head affine, every vertex weighted 1.0 to `bone`."""
    aff = head_affines(fits)
    V = {k: apply_affine(aff, V_ref, k) for k in fits.V}
    n = len(V_ref)
    W = np.zeros((n, len(fits.bones)))
    W[:, fits.bones.index(bone)] = 1.0
    m = Mesh.__new__(Mesh)
    m.V = V
    m.F = np.asarray(F, int)
    m.N = {k: vertex_normals(v, m.F) for k, v in V.items()}
    m.A = {"W": W}
    for name in template_attrs:
        if name != "W":
            m.A[name] = np.zeros(n)
    nf = len(m.F)
    m.fa = {"region": np.full(nf, RG.REGIONS[region]), "zone": np.broadcast_to(np.asarray(zone), (nf,)).astype(int).copy(),
            "part": np.broadcast_to(np.asarray(part), (nf,)).astype(int).copy()}
    return m


# ---- rigid felt hats ----------------------------------------------------------------------------------------------
def _rot_x(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], float)


def _fold(st, X, Y):
    """The tricorne's brim: a flat disc folded up along three chords (front point forward, -y)."""
    chord = st.get("chord")
    Z = np.zeros_like(X)
    if not chord:
        return X, Y, Z
    fa = math.radians(st["fold"])
    normals = [(0.0, 1.0), (math.sin(math.radians(120)), -0.5), (-math.sin(math.radians(120)), -0.5)]
    ups = []
    X, Y = X.copy(), Y.copy()
    for nx, ny in normals:
        o = X * nx + Y * ny - chord
        o = np.maximum(o, 0.0)
        X = X - nx * o * (1 - math.cos(fa))
        Y = Y - ny * o * (1 - math.cos(fa))
        ups.append(o * math.sin(fa))
    U = np.sort(np.stack(ups + [np.zeros_like(X)], 1), 1)
    Z = U[:, -1] + st["fold_soft"] * U[:, -2]
    return X, Y, Z


def felt_hat(st):
    """(V, F, zone per face, part per face, cockade (point, normal) or None) of a felt hat in its own frame: origin at
    the crown's base centre, z up, front -y. Zones: 0 felt, 1 binding tape / hat band, 2 cockade, 3 button / loop.
    Parts: 0 the crown (cylinder UV), 5 the brim (planar UV)."""
    a, b, h = st["crown_a"], st["crown_b"], st["crown_h"]
    segs, rings = st["segs"], st["rings"]
    th = 2 * np.pi * np.arange(segs) / segs
    ca, sa = np.cos(th), np.sin(th)
    r_in = np.hypot(a * ca, b * sa)
    # brim rings (the last tape_w metres a ring of their own: the tape has a straight inner edge)
    tape = st.get("tape_w", 0.0)
    if tape:
        rows_r = [r_in + (st["brim_r"] - tape - r_in) * f for f in np.linspace(0.0, 1.0, rings)] + \
                 [np.full(segs, float(st["brim_r"]))]
    else:
        rows_r = [r_in + (st["brim_r"] - r_in) * f for f in np.linspace(0.0, 1.0, rings + 1)]
    V, F, Z, Pt = [], [], [], []

    def add(P):
        V.extend(P.tolist())
        return np.arange(len(V) - len(P), len(V))

    droop = st.get("droop", 0.0)
    brim = []
    for k, r in enumerate(rows_r):
        X, Y = ca * r, sa * r
        X, Y, Zz = _fold(st, X, Y)
        f = (r - r_in) / np.maximum(st["brim_r"] - r_in, 1e-6)
        Zz = Zz - droop * f ** 2
        brim.append(add(np.stack([X, Y, Zz], 1)))
    nr = len(brim)
    top_faces = []
    for i in range(nr - 1):
        for j in range(segs):
            j2 = (j + 1) % segs
            top_faces += [(brim[i][j], brim[i + 1][j], brim[i + 1][j2]), (brim[i][j], brim[i + 1][j2], brim[i][j2])]
    top_faces = np.array(top_faces, int)
    Pb = np.array(V, float)
    # the underside: the top offset down along its normals, turned over; the outer rim joins them
    nb = vertex_normals(Pb, top_faces)
    under = add(Pb[np.concatenate(brim)] - nb[np.concatenate(brim)] * st["thick"])
    umap = -np.ones(len(V), int)
    umap[np.concatenate(brim)] = under
    under_faces = umap[top_faces][:, ::-1]
    o_top, o_bot = brim[-1], umap[brim[-1]]
    rim = []
    for j in range(segs):
        j2 = (j + 1) % segs
        rim += [(o_top[j], o_bot[j], o_bot[j2]), (o_top[j], o_bot[j2], o_top[j2])]
    rim = np.array(rim, int)
    # tape: the outer ring on both sides and the rim
    is_tape_top = np.zeros(len(top_faces), bool)
    if tape:
        is_tape_top[(nr - 2) * segs * 2:] = True
    for fs, zt in ((top_faces, is_tape_top), (under_faces, is_tape_top), (rim, np.full(len(rim), bool(tape)))):
        F.extend(fs.tolist())
        Z.extend(np.where(zt, 1, 0).tolist())
        Pt.extend([5] * len(fs))
    # crown wall (a slight bulge), a rounded top edge and a low dome; the bottom open (it sits on the head)
    hs = [0.35, 0.7, 1.0]
    band_h = st.get("band_h", 0.0)
    wall = [brim[0]]
    if band_h:
        # a ring at the top of the hat band (its edge straight)
        wall.append(add(np.stack([a * ca * 1.004, b * sa * 1.004, np.full(segs, band_h)], 1)))
    for hh in hs:
        bulge = 1.0 + 0.04 * math.sin(math.pi * hh)
        wall.append(add(np.stack([a * bulge * ca, b * bulge * sa, np.full(segs, h * hh)], 1)))
    crown_rows = list(wall)
    for sc, dz in ((0.955, 0.0048), (0.86, 0.0088), (0.66, 0.0118), (0.38, 0.0132)):
        crown_rows.append(add(np.stack([a * sc * ca, b * sc * sa, np.full(segs, h + dz)], 1)))
    apex = add(np.array([[0.0, 0.0, h + 0.0138]]))[0]
    for k in range(len(crown_rows) - 1):
        lo, hi = crown_rows[k], crown_rows[k + 1]
        zone = 1 if (band_h and k == 0) else 0
        for j in range(segs):
            j2 = (j + 1) % segs
            F += [(lo[j], lo[j2], hi[j2]), (lo[j], hi[j2], hi[j])]
            Z += [zone, zone]
            Pt += [0, 0]
    last = crown_rows[-1]
    for j in range(segs):
        F.append((last[j], last[(j + 1) % segs], apex))
        Z.append(0)
        Pt.append(0)
    V = np.array(V, float)
    F = np.array(F, int)
    cockade = None
    if st.get("cockade"):
        s = 1.0 if st["cockade"] == "left" else -1.0
        n = np.array([s * math.sin(math.radians(120)), -0.5])
        q = n * (st["chord"] + 0.032) if st.get("chord") else n * (st["brim_r"] - 0.03)
        X, Y, Zc = _fold(st, np.array([q[0]]), np.array([q[1]]))
        fa = math.radians(st["fold"])
        out = unit(np.array([n[0] * math.sin(fa), n[1] * math.sin(fa), -math.cos(fa)]))
        # (the fold's outer side faces away from the crown: out points away from the axis and down)
        cockade = (np.array([X[0], Y[0], Zc[0]]) + out * 0.0045, out)
    return V, F, np.array(Z, int), np.array(Pt, int), cockade


def hat_frame(fits, st):
    """(origin, rotation) of the hat frame on the reference head: HAT_CENTER over headb (lowered by st['lower']),
    tilted st['tilt'] degrees about x (front edge down)."""
    c = headb(fits) + HAT_CENTER - np.array([0.0, 0.0, st.get("lower", 0.0)])
    return c, _rot_x(st["tilt"])


def rigid_hat(g, st, zones=(0, 1, 2, 3)):
    """A felt hat on headb (g.m is replaced): the hat (zones felt, tape, cockade, button), the cockade, loop and
    button when the style has them. Returns g."""
    from cloth2 import hardware as HW
    fits = g.fits
    V, F, Z, Pt, ck = felt_hat(st)
    C, R = hat_frame(fits, st)
    Vw = C + V @ R.T
    zmap = np.array(zones)
    pieces_V, pieces_F, pieces_Z, pieces_P = [Vw], [F], [zmap[np.clip(Z, 0, 3)]], [Pt]
    off = len(Vw)
    if ck is not None:
        p, n = ck
        pw, nw = C + p @ R.T, n @ R.T
        Rf = HW.frames(nw[None], [0.0, 0.0, 1.0])[0]
        r = st["cockade_r"]
        parts = [(HW.disc(r, 0.0036, segs=16), zones[2]), (HW.disc(r * 0.58, 0.0058, segs=12), zones[2])]
        if st.get("loop"):
            parts.append((HW.translate(HW.box(0.0018, r * 0.42, 0.0007, z0=0.0058), (0.0, r * 0.42, 0.0)), zones[1]))
        if st.get("button"):
            parts.append((HW.translate(HW.button(0.0055, 0.0035, segs=8), (0.0, r * 0.82, 0.0058)), zones[3]))
        for (Vl, Fl), z in parts:
            pieces_V.append(pw + Vl @ Rf.T)
            pieces_F.append(Fl + off)
            pieces_Z.append(np.full(len(Fl), z))
            pieces_P.append(np.full(len(Fl), 6))
            off += len(Vl)
    Vall = np.concatenate(pieces_V)
    m = rigid_mesh(fits, (g.m.A if g.m is not None else {"W": None}), Vall, np.concatenate(pieces_F),
                   np.concatenate(pieces_Z), np.concatenate(pieces_P))
    g.m = m
    g._hat = (C, R, st)
    up = R @ np.array([0.0, 0.0, 1.0])
    g.uvparts = {0: ("cyl", C, C + up * 0.1, R @ np.array([0.0, -1.0, 0.0])),
                 5: ("planar", C, R @ np.array([1.0, 0.0, 0.0]), R @ np.array([0.0, 1.0, 0.0])),
                 6: ("planar", C, R @ np.array([1.0, 0.0, 0.0]), R @ np.array([0.0, 0.0, 1.0]))}
    g.shape_alias = {"sex_head": "m"}
    return g


# ---- soft caps -----------------------------------------------------------------------------------------------------
def head_grid(fits, segs=32, rows=9, phi_max=lambda th: np.full_like(th, 1.2), ease=lambda th, ph: 0.010,
              centre=(0.0, -0.035, 0.075), phi0=0.16, smooth=2, bone="headb"):
    """A cap over the cranium: rays from `centre` (relative to headb) at polar angle phi (0 = up, radians) and azimuth
    theta (0 = the front, -y; pi/2 the wearer's left) hit the scalp in every fit; each point is lifted by
    ease(theta, phi) (m) along the scalp normal. Rows run from phi0 to phi_max(theta) (the cap's edge: low at the
    back, high over the brow); an apex closes the top. Returns (Mesh, grid ids (rows, segs), theta, phi (rows, segs))."""
    th = 2 * np.pi * np.arange(segs) / segs
    pm = np.asarray(phi_max(th), float)
    PH = np.stack([phi0 + (pm - phi0) * (i / (rows - 1)) for i in range(rows)])      # (rows, segs)
    TH = np.broadcast_to(th, PH.shape)
    D = np.stack([np.sin(PH) * np.sin(TH), -np.sin(PH) * np.cos(TH), np.cos(PH)], -1).reshape(-1, 3)
    D = np.concatenate([[[0.0, 0.0, 1.0]], D])
    E = np.concatenate([[float(ease(0.0, 0.0))], np.asarray(ease(TH, PH), float).reshape(-1) * np.ones(D.shape[0] - 1)])
    aff = head_affines(fits)
    c_ref = headb(fits) + np.asarray(centre, float)
    V = {}
    for k in fits.V:
        c = apply_affine(aff, c_ref[None], k)[0]
        bv = fits.bvh[k]
        P = np.zeros_like(D)
        for i, d in enumerate(D):
            loc, nrm, _, _ = bv.ray_cast(Vector(c), Vector(d), 0.4)
            if loc is None:
                loc, nrm = c + d * 0.09, d
            n = np.array(nrm)
            if n @ d < 0:
                n = -n
            P[i] = np.array(loc) + n * E[i]
        V[k] = P
    ids = 1 + np.arange(rows * segs).reshape(rows, segs)
    F = []
    for j in range(segs):
        F.append((0, ids[0][(j + 1) % segs], ids[0][j]))
    for i in range(rows - 1):
        for j in range(segs):
            j2 = (j + 1) % segs
            F += [(ids[i][j], ids[i][j2], ids[i + 1][j2]), (ids[i][j], ids[i + 1][j2], ids[i + 1][j])]
    F = np.array(F, int)
    # outward winding
    P = V[REF]
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    cen = headb(fits) + np.asarray(centre, float)
    if ((fn * (P[F].mean(1) - cen)).sum(1) < 0).mean() > 0.5:
        F = F[:, ::-1].copy()
    n = len(D)
    W = np.zeros((n, len(fits.bones)))
    W[:, fits.bones.index(bone)] = 1.0
    m = Mesh.__new__(Mesh)
    m.V = V
    m.F = F
    m.N = {k: vertex_normals(v, F) for k, v in V.items()}
    m.A = {"W": W}
    nf = len(F)
    m.fa = {"region": np.full(nf, RG.REGIONS["head"]), "zone": np.zeros(nf, int), "part": np.zeros(nf, int)}
    if smooth:
        m.smooth(smooth, 0.4)
    return m, ids, TH, PH


def tube(fits, template, path_ref, radii, segs=10, zone=0, part=0, bone="headb"):
    """A closed-ended knitted tube along `path_ref` (k, 3; reference fit) with radius per point (the tuque's crown,
    a stocking cap's tail), rigid on `bone`, placed in every fit by the head affine."""
    path = np.asarray(path_ref, float)
    k = len(path)
    T = np.gradient(path, axis=0)
    T = unit(T)
    ref = np.array([1.0, 0.0, 0.0])
    V = []
    for i in range(k):
        u = unit(np.cross(T[i], ref) if abs(T[i] @ ref) < 0.95 else np.cross(T[i], [0.0, 1.0, 0.0]))
        w = np.cross(T[i], u)
        th = 2 * np.pi * np.arange(segs) / segs
        V += (path[i] + radii[i] * (np.cos(th)[:, None] * u + np.sin(th)[:, None] * w)).tolist()
    V.append(path[-1] + T[-1] * radii[-1] * 0.6)
    V = np.array(V, float)
    F = []
    for i in range(k - 1):
        for j in range(segs):
            a, b = i * segs + j, i * segs + (j + 1) % segs
            c, d = (i + 1) * segs + (j + 1) % segs, (i + 1) * segs + j
            F += [(a, b, c), (a, c, d)]
    tip = len(V) - 1
    for j in range(segs):
        F.append(((k - 1) * segs + j, (k - 1) * segs + (j + 1) % segs, tip))
    F = np.array(F, int)
    P = V
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    axis_pts = np.repeat(path, segs, axis=0)
    if len(F) and ((fn[:(k - 1) * segs * 2] * (P[F[:(k - 1) * segs * 2]].mean(1) -
                                              axis_pts[F[:(k - 1) * segs * 2, 0]])).sum(1) < 0).mean() > 0.5:
        F = F[:, ::-1].copy()
    return rigid_mesh(fits, template.A, V, F, zone, part, bone=bone)
