"""cloth2 tailor: small helpers the French marine and Canadian garments needed beside garment.py / trims.py
(2026-10-02). Additive only: nothing here changes how the shared operations behave.

  sel = cut_select(g, field)            # cut along field == 0, then the faces whose CENTRE lies where field < 0
                                        #   (trims.split_mask takes the mean of the interpolated field: a band thinner
                                        #   than one row of faces has every vertex on its cut lines, the mean is 0 and
                                        #   nothing is selected; a garter on a stocking, a tape on a hat)
  piece = flap(g, points, width, lift, angle_deg, ...)   # a cloth flap standing off the surface along a line of points
                                        #   on the garment, leaning back by angle_deg (a legging's side flap): rows
                                        #   across, bound to the garment's faces (every fit), weights of its root
  piece = ribbon(g, path_fn, ...)       # a strip with several vertices across (stripes along it: a sash's end)
  neck_collar(g, height, zone, where=)  # Garment.stand_collar grown from the neckline only (stand_collar takes every
                                        #   open edge above the neck's root, a raised overlap's top rim included);
                                        #   `where` keeps part of the edge (the capot's: the front and sides)
  clean(g)                              # merges the near-coincident corners of cut slivers (a pinhole at the centre
                                        #   back where the back seam meets another cut shaded as a dark spot)
  relax_fits(g, where, iters)           # smooths each fit's offset from the reference fit where(P) (a bump a push left
                                        #   in one fit only: the capot's skirt in the small-bust fit)
  carry(g, before, inner)               # after pushes, the vertices `inner` (a lining) take the move of the nearest
                                        #   other vertex, so a lining keeps its distance under its cloth
"""

import numpy as np

from cloth2 import hardware as HW
from cloth2.mesh import REF, unit


def cut_select(g, field):
    """Cuts g.m along field == 0 (a callable on reference positions) and returns the faces whose centre is where the
    field < 0."""
    g.m = g.m.split(np.asarray(field(g.P), float), 0.0)
    c = g.m.face_centres()
    return np.asarray(field(c), float) < 0.0


def band_select(g, z0, z1):
    """The faces between heights z0 and z1 (cut along both)."""
    for z in (z0, z1):
        g.m = g.m.split(g.P[:, 2] - z, 0.0)
    c = g.m.face_centres()
    return (c[:, 2] > z0) & (c[:, 2] < z1)


def flap(g, points, width, lift, lean, rows=3, zone=0, part=8, curl=0.0, width_fn=None, back=(0.0, 1.0, 0.0)):
    """A flap of cloth from a line of `points` on g.m (reference fit, ordered along the line): it leaves the surface
    `lift` off it and stands out `width` (m; or width_fn(s), s 0..1 along the line), leaning `lean` degrees from the
    surface normal toward `back` (projected on the surface), curling by `curl` (m, the edge dropping back toward the
    surface). rows: vertices across. Bound to the garment's faces in every fit; every vertex of a row across takes
    the weights of its root (it does not bend across). Returns a piece (g.add it)."""
    P = np.asarray(points, float)
    k = len(P)
    b = HW.Binding(g.m, P)
    s = np.linspace(0.0, 1.0, k)
    w = np.asarray(width_fn(s), float) if width_fn else np.full(k, float(width))
    a = np.radians(lean)
    V = {}
    for fit in g.m.V:
        p, n = b.at(g.m, fit)
        n = unit(n)
        bk = np.asarray(back, float)[None] - (n @ np.asarray(back, float))[:, None] * n
        bk = unit(bk)
        d = unit(n * np.cos(a) + bk * np.sin(a))
        rws = []
        for r in range(rows):
            f = r / (rows - 1)
            q = p + n * lift + d * (w * f)[:, None] - n * (curl * f * f)
            rws.append(q)
        V[fit] = np.concatenate(rws)
    F = []
    for r in range(rows - 1):
        for i in range(k - 1):
            a0, b0 = r * k + i, r * k + i + 1
            a1, b1 = (r + 1) * k + i, (r + 1) * k + i + 1
            F += [(a0, b0, b1), (a0, b1, a1)]
    F = np.array(F, int)
    W = np.concatenate([b.weights(g.m)] * rows)
    A = {name: np.concatenate([b.attr(g.m, name)] * rows) for name in g.m.A if name != "W"}
    region = np.tile(np.repeat(b.face_attr(g.m, "region")[:-1], 2), rows - 1)
    return HW.piece_mesh(g.m, V, F, W, region, zone, part, A)


def ribbon(g, centre, normal, across, half_w, lift, weights, stripes=None, zone=0, part=8, n_across=5,
           attrs=None, region=0):
    """A strip along a centre line with n_across vertices across it, in every fit: centre {fit: (k, 3)}, normal
    {fit: (k, 3)} (off the surface), across {fit: (k, 3)} (unit, in the strip's plane), half_w (k,), lift (k,),
    weights (k, bones). stripes: [(u0, u1, zone)] bands across the strip (u -1 .. 1 from one edge to the other)
    in another zone (a sash's stripes run along it). Returns a piece."""
    k = len(next(iter(centre.values())))
    us = np.linspace(-1.0, 1.0, n_across)
    if stripes:
        cuts = sorted(set([u for s in stripes for u in s[:2]] + list(us)))
        us = np.array(cuts)
    V = {}
    for fit in centre:
        c = centre[fit] + normal[fit] * np.asarray(lift, float)[:, None]
        V[fit] = np.concatenate([c + across[fit] * (half_w * u)[:, None] for u in us])
    na = len(us)
    F, Z = [], []
    for j in range(na - 1):
        um = 0.5 * (us[j] + us[j + 1])
        z = zone
        for u0, u1, zz in (stripes or []):
            if u0 <= um <= u1:
                z = zz
        for i in range(k - 1):
            a0, b0 = j * k + i, j * k + i + 1
            a1, b1 = (j + 1) * k + i, (j + 1) * k + i + 1
            F += [(a0, b0, b1), (a0, b1, a1)]
            Z += [z, z]
    F = np.array(F, int)
    P = V[REF]
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    n0 = np.concatenate([normal[REF]] * na)
    if ((fn * n0[F[:, 0]]).sum(1) < 0).mean() > 0.5:
        F = F[:, ::-1].copy()
    W = np.concatenate([weights] * na)
    A = None
    if attrs is not None:
        A = {name: np.concatenate([v] * na) for name, v in attrs.items()}
    return HW.piece_mesh(g.m, V, F, W, region, np.array(Z, int), part, A)


def neck_collar(g, height=0.028, lean=0.25, zone=1, rings=2, rho_max=1.12, where=None, taper=None):
    """A standing collar grown from the neckline's own edge (the open boundary within rho_max of the neckline
    ellipse, Garment.neckline), `height` along the neck's axis, leaning in by `lean` of it; `where(P)` (bool per
    vertex, optional) keeps only part of the edge (a collar round the front and sides, the hood sewn on behind);
    `taper` (y0, y1): the height falls to nothing from y0 to y1 (m, toward the back: the collar's ends die away
    instead of standing up as tabs)."""
    from cloth2 import trims as TR
    a, b, z0, tilt, yc, dip, dip_width = g._neck
    th = np.radians(tilt)
    up = np.array([0.0, -np.sin(th), np.cos(th)])

    def near(P):
        rho, t = g._neck_coords(P)
        ok = (rho < rho_max) & (t > -0.02)
        return ok & np.asarray(where(P), bool) if where is not None else ok

    def disp(fit, P0, N0, s):
        inward = np.stack([-P0[:, 0], yc - P0[:, 1], np.zeros(len(P0))], 1)
        inward = inward / np.maximum(np.linalg.norm(inward, axis=1, keepdims=True), 1e-9)
        h = np.full((len(P0), 1), height * s)
        if taper is not None:
            from cloth2.mesh import smoothstep
            h = h * (1.0 - smoothstep(taper[0], taper[1], P0[:, 1]))[:, None]
        return (up[None] + inward * lean) * h
    piece = TR.extrude(g.m, near, disp, rings=rings, zone=zone)
    if piece is not None:
        g.add(piece)
    return g


def clean(g, tol=2.0e-4):
    """Merges vertices closer than `tol` (m, reference fit) and drops the faces that collapse or repeat: the slivers
    a cut leaves where two cut lines meet (the centre back seam crossing the neckline's or hem's lines left a zero-area
    triangle whose three corners were not welded: a pinhole that shades as a dark spot). Rims stand RIM_EPS (0.4 mm)
    off their cloth and buttons sink 0.6 mm, so tol stays below both."""
    from mathutils import kdtree
    from cloth2.mesh import Mesh
    m = g.m
    P = m.V[REF]
    kd = kdtree.KDTree(len(P))
    for i, p in enumerate(P):
        kd.insert(p, i)
    kd.balance()
    rep = np.arange(len(P))
    for i, p in enumerate(P):
        if rep[i] != i:
            continue
        for _, j, _ in kd.find_range(p, tol):
            if j > i and rep[j] == j:
                rep[j] = i
    F = rep[m.F]
    ok = (F[:, 0] != F[:, 1]) & (F[:, 1] != F[:, 2]) & (F[:, 2] != F[:, 0])
    key = np.sort(F, 1)
    _, first = np.unique(key, axis=0, return_index=True)
    uniq = np.zeros(len(F), bool)
    uniq[first] = True
    ok &= uniq
    used = np.unique(F[ok])
    remap = -np.ones(len(P), int)
    remap[used] = np.arange(len(used))
    out = Mesh.__new__(Mesh)
    out.V = {k: v[used] for k, v in m.V.items()}
    out.N = {k: v[used] for k, v in m.N.items()}
    out.A = {k: v[used] for k, v in m.A.items()}
    out.F = remap[F[ok]]
    out.fa = {k: v[ok] for k, v in m.fa.items()}
    out.recompute_normals()
    g.m = out
    return g


def relax_fits(g, where, iters=24, lam=0.5):
    """Smooths, in every fit but the reference one, the offset of each vertex from its reference position over the
    mesh (Laplacian, `iters` passes) where `where(P)` (reference positions) holds: a bump that a push left in one fit
    only spreads into a gentle swell (follow with Garment.over to clear the layers under it again)."""
    m = g.m
    sel = np.asarray(where(m.V[REF]), bool)
    E = m.adjacency()
    for k in m.V:
        if k == REF:
            continue
        D = m.V[k] - m.V[REF]
        for _ in range(iters):
            acc = np.zeros_like(D)
            cnt = np.zeros(m.n)
            np.add.at(acc, E[:, 0], D[E[:, 1]])
            np.add.at(cnt, E[:, 0], 1.0)
            avg = acc / np.maximum(cnt, 1.0)[:, None]
            D[sel] += lam * (avg[sel] - D[sel])
        m.V[k] = m.V[REF] + D
    m.recompute_normals()
    return g


def carry(g, before, inner):
    """After operations moved g.m's vertices (positions `before`: {fit: (n, 3)}, same vertices), the vertices `inner`
    (bool per vertex: a skirt lining) take the displacement of the nearest other vertex (reference fit, before) in
    every fit: Garment.over pushes each vertex on its own, and a lining 1.6 mm under its cloth was pushed onto the
    same surface (the two shaded through each other)."""
    from mathutils import kdtree
    m = g.m
    inner = np.asarray(inner, bool)
    outer = np.nonzero(~inner)[0]
    kd = kdtree.KDTree(len(outer))
    for i, j in enumerate(outer):
        kd.insert(before[REF][j], i)
    kd.balance()
    near = np.array([outer[kd.find(before[REF][j])[1]] for j in np.nonzero(inner)[0]], int)
    for k in m.V:
        m.V[k][inner] = before[k][inner] + (m.V[k][near] - before[k][near])
    m.recompute_normals()
    return g
