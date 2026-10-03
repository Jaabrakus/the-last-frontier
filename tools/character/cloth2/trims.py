"""cloth2 trims: the tailoring operations on a garment Mesh (2026-10-02). Every one works on the reference fit's
positions and replays on the other fits (cloth2.mesh), so the male fit and the bust gauge stay exact morph targets.

  m, sel = split_mask(m, field)                  # cut along field == 0 (a clean line), sel = the faces where < 0
  m = raise_region(m, sel, h, zone, rim=True)    # the faces of `sel` stand h (m) proud with a rim at their border
                                                 #   (cuffs, lapels, pocket flaps, turnbacks, collars, bands); the cloth
                                                 #   under them is not doubled
  piece = overlay(m, sel, h, zone, rim, flip)    # a separate copy of the faces h off the surface (a lining when h < 0
                                                 #   and flip: the inside of coat skirts in the facing colour)
  d = edge_distance(m, select)                   # distance along the surface to the boundary vertices `select` keeps
  m, sel = edge_band(m, select, width)           # the band within `width` of those edges (piping, a glow cord, tape)
  piece = extrude(m, select, disp, rings)        # rings grown from boundary edges (a standing collar, a frill)
  loops(m, select)                               # the boundary edges of `select` chained into loops (vertex ids)

Fields are callables on (n, 3) reference positions or per-vertex arrays. A field that is per vertex is carried
through the cut (interpolated), so the selection after the cut is exact.
"""

import heapq

import numpy as np

from cloth2.mesh import REF, Mesh, concat, unit, vertex_normals

RIM_EPS = 0.0004       # a rim's own vertices stand this far off the line they rise from


def _values(m, field):
    return np.asarray(field(m.ref()) if callable(field) else field, float)


def split_mask(m, field):
    """Cuts `m` along field == 0 and returns (mesh, faces where the field < 0)."""
    f = _values(m, field)
    m.A["_f"] = f
    try:
        m2 = m.split(f, 0.0)
    finally:
        del m.A["_f"]
    fc = m2.A.pop("_f")[m2.F].mean(1)
    return m2, fc < 0.0


def face_mask(m, field):
    """Faces whose centre lies where the field < 0 (no cut)."""
    f = _values(m, field)
    return f[m.F].mean(1) < 0.0


def _height(m, h, idx):
    if callable(h):
        return np.asarray(h(m.ref()[idx]), float) * np.ones(len(idx))
    h = np.asarray(h, float)
    return np.broadcast_to(h if h.ndim == 0 else h[idx], (len(idx),)).astype(float)


def raise_region(m, sel, h, zone=None, rim=True, rim_zone=None):
    """The faces of `sel` (bool per face) lifted by h (m; a number, per vertex of m, or a callable on reference
    positions) along the surface normal in every fit. Vertices on the region's border that other faces share are
    split off, and a rim of quads joins the two edges (a folded edge of cloth). Returns the new mesh."""
    if not sel.any():
        return m
    F = m.F.copy()
    n = m.n
    ins = np.unique(F[sel])
    outs = np.unique(F[~sel])
    shared = np.intersect1d(ins, outs)
    copy_of = -np.ones(n, int)
    copy_of[shared] = n + np.arange(len(shared))
    Fs = F[sel]
    Fs = np.where(copy_of[Fs] >= 0, copy_of[Fs], Fs)
    F[sel] = Fs
    # normals of the whole surface (the copies keep their originals'), so the raised edge stands over the line
    Nfit = {k: vertex_normals(m.V[k], m.F) for k in m.V}
    inner = np.setdiff1d(ins, shared)
    moved = np.concatenate([inner, n + np.arange(len(shared))])
    src = np.concatenate([inner, shared])            # the original vertex of each moved one (heights, positions)
    hv = _height(m, h, src)
    out = Mesh.__new__(Mesh)
    out.V, out.N = {}, {}
    for k in m.V:
        V = np.concatenate([m.V[k], m.V[k][shared]])
        Nn = np.concatenate([Nfit[k], Nfit[k][shared]])
        V[moved] = V[moved] + Nn[moved] * hv[:, None]
        out.V[k] = V
        out.N[k] = Nn
    out.A = {k: np.concatenate([v, v[shared]]) for k, v in m.A.items()}
    out.F = F
    out.fa = {k: v.copy() for k, v in m.fa.items()}
    if zone is not None:
        out.fa["zone"][sel] = zone
    if rim and len(shared):
        # border edges of the region (in its faces' winding) whose ends were both split off
        E = np.concatenate([m.F[sel][:, [0, 1]], m.F[sel][:, [1, 2]], m.F[sel][:, [2, 0]]])
        fid = np.tile(np.nonzero(sel)[0], 3)
        key = np.sort(E, 1)
        Eo = np.concatenate([m.F[~sel][:, [0, 1]], m.F[~sel][:, [1, 2]], m.F[~sel][:, [2, 0]]])
        other = set(map(tuple, np.sort(Eo, 1).tolist()))
        border = np.array([tuple(k_) in other for k_ in key.tolist()], bool)
        E, fid = E[border], fid[border]
        if len(E):
            a, b = E[:, 0], E[:, 1]
            ok = (copy_of[a] >= 0) & (copy_of[b] >= 0)
            a, b, fid = a[ok], b[ok], fid[ok]
            # the rim has vertices of its own (RIM_EPS off the line and under the raised edge, so the weld keeps them
            # apart): the sleeve, the cuff and the rim keep their own normals (a crisp fold, no shading smear)
            line = np.unique(np.concatenate([a, b]))
            nl = len(line)
            base0 = out.n
            lo = -np.ones(n, int)
            hi = -np.ones(n, int)
            lo[line] = base0 + np.arange(nl)
            hi[line] = base0 + nl + np.arange(nl)
            hl = _height(m, h, line)
            for k in out.V:
                Nn = Nfit[k][line]
                P0 = m.V[k][line]
                out.V[k] = np.concatenate([out.V[k], P0 + Nn * RIM_EPS, P0 + Nn * (hl - RIM_EPS)[:, None]])
                out.N[k] = np.concatenate([out.N[k], Nn, Nn])
            out.A = {k_: np.concatenate([v, v[line], v[line]]) for k_, v in out.A.items()}
            RF = np.concatenate([np.stack([lo[a], lo[b], hi[b]], 1), np.stack([lo[a], hi[b], hi[a]], 1)])
            # outward: away from the region's own face
            P = out.V[REF]
            fn = np.cross(P[RF[:, 1]] - P[RF[:, 0]], P[RF[:, 2]] - P[RF[:, 0]])
            mid = P[RF].mean(1)
            own = np.tile(P[F[fid]].mean(1), (2, 1))
            flip = (fn * (mid - own)).sum(1) < 0
            RF[flip] = RF[flip][:, ::-1]
            out.F = np.concatenate([out.F, RF])
            src_f = np.tile(fid, 2)
            for k_, v in out.fa.items():
                out.fa[k_] = np.concatenate([v, v[src_f]])
            if rim_zone is not None:
                out.fa["zone"][-len(RF):] = rim_zone
    return out


def overlay(m, sel, h, zone, rim=False, flip=False, rim_frac=0.15, part=None):
    """A separate piece: the faces of `sel` copied h (m) off the surface (negative: inside), in `zone`. flip: the
    faces turned over (a lining seen from inside). rim: a strip from the piece's border back toward the surface (to
    rim_frac of h), so a flap reads thick. Returns the piece (concat it to the garment)."""
    sub = m.faces_of(sel)
    if not len(sub.F):
        return None
    Nfull = {k: vertex_normals(m.V[k], m.F) for k in m.V}
    used = np.unique(m.F[sel])
    hv = _height(m, h, used)
    for k in sub.V:
        sub.N[k] = Nfull[k][used]
        sub.V[k] = sub.V[k] + sub.N[k] * hv[:, None]
    sub.fa["zone"][:] = zone
    if part is not None:
        sub.fa["part"][:] = part
    if flip:
        sub.F = sub.F[:, ::-1].copy()
        for k in sub.N:
            sub.N[k] = -sub.N[k]
    if rim:
        be, onb = sub.boundary()
        if len(be):
            nb = sub.n
            idx = np.nonzero(onb)[0]
            low = -np.ones(nb, int)
            low[idx] = nb + np.arange(len(idx))
            for k in sub.V:
                Nn = Nfull[k][used][idx] * (-1.0 if flip else 1.0)
                sub.V[k] = np.concatenate([sub.V[k], sub.V[k][idx] - Nn * (hv[idx] * (1.0 - rim_frac))[:, None]])
                sub.N[k] = np.concatenate([sub.N[k], sub.N[k][idx]])
            sub.A = {k: np.concatenate([v, v[idx]]) for k, v in sub.A.items()}
            a, b = be[:, 0], be[:, 1]
            RF = np.concatenate([np.stack([a, b, low[b]], 1), np.stack([a, low[b], low[a]], 1)])
            P = sub.V[REF]
            fn = np.cross(P[RF[:, 1]] - P[RF[:, 0]], P[RF[:, 2]] - P[RF[:, 0]])
            cen = P[:nb].mean(0)
            fl = (fn * (P[RF].mean(1) - cen)).sum(1) < 0
            RF[fl] = RF[fl][:, ::-1]
            sub.F = np.concatenate([sub.F, RF])
            for k_, v in sub.fa.items():
                sub.fa[k_] = np.concatenate([v, np.full(len(RF), v[0])])
    return sub


def surface_distance(m, sources):
    """Distance (m) along the mesh edges from the vertices in `sources` (bool), at most 1."""
    P = m.V[REF]
    E = np.unique(np.sort(m.edges(), 1), axis=0)
    adj = [[] for _ in range(m.n)]
    L = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1)
    for (a, b), l in zip(E.tolist(), L.tolist()):
        adj[a].append((b, l))
        adj[b].append((a, l))
    dist = np.full(m.n, 1.0)
    h = [(0.0, int(i)) for i in np.nonzero(sources)[0]]
    for _, i in h:
        dist[i] = 0.0
    heapq.heapify(h)
    while h:
        d, i = heapq.heappop(h)
        if d > dist[i]:
            continue
        for j, l in adj[i]:
            nd = d + l
            if nd < dist[j]:
                dist[j] = nd
                heapq.heappush(h, (nd, j))
    return dist


def open_boundary(m, tol=0.0012):
    """Bool per vertex: on a true open edge of the garment (a hem, a cuff, an opening). The rims of raised regions
    have edges of their own a fraction of a millimetre from the cloth (RIM_EPS); vertices within `tol` of each other
    count as one here, so those seams are not openings."""
    from mathutils import kdtree
    P = m.V[REF]
    kd = kdtree.KDTree(len(P))
    for i, p in enumerate(P):
        kd.insert(p, i)
    kd.balance()
    group = np.arange(len(P))
    for i, p in enumerate(P):
        if group[i] != i:
            continue
        for _, j, _ in kd.find_range(p, tol):
            if j > i and group[j] == j:
                group[j] = i
    E = np.concatenate([m.F[:, [0, 1]], m.F[:, [1, 2]], m.F[:, [2, 0]]])
    G = np.sort(group[E], 1)
    G = G[G[:, 0] != G[:, 1]]
    _, inv, cnt = np.unique(G, axis=0, return_inverse=True, return_counts=True)
    # an edge is open when its (merged) pair occurs once; a raised region's rim makes the pair occur twice or more
    Eg = np.sort(group[E], 1)
    keep = Eg[:, 0] != Eg[:, 1]
    open_e = np.zeros(len(E), bool)
    open_e[keep] = cnt[inv.ravel()] == 1
    onb = np.zeros(m.n, bool)
    onb[E[open_e].ravel()] = True
    return onb


def boundary_vertices(m, select=None):
    """Bool per vertex: on an open edge of the garment (open_boundary) and (if given) select(P) true there."""
    onb = open_boundary(m)
    if select is not None:
        onb = onb & np.asarray(select(m.ref()), bool)
    return onb


def edge_distance(m, select=None):
    return surface_distance(m, boundary_vertices(m, select))


def edge_band(m, select, width):
    """(mesh, faces) of the band within `width` (m, along the surface) of the boundary edges `select` keeps."""
    d = edge_distance(m, select)
    return split_mask(m, d - width)


def loops(m, select=None):
    """The boundary edges whose both ends `select` keeps, chained into loops / runs: [array of vertex ids]."""
    be, onb = m.boundary()
    keep = onb if select is None else onb & np.asarray(select(m.ref()), bool)
    be = be[keep[be[:, 0]] & keep[be[:, 1]]]
    nxt = {}
    for a, b in be.tolist():
        nxt.setdefault(a, []).append(b)
    starts = set(nxt) - set(b for _, b in be.tolist())
    seen = set()
    out = []
    for s in list(starts) + list(nxt):
        if s in seen or s not in nxt:
            continue
        run = [s]
        seen.add(s)
        cur = s
        while cur in nxt:
            nx = [v for v in nxt[cur] if v not in seen]
            if not nx:
                break
            cur = nx[0]
            seen.add(cur)
            run.append(cur)
        if len(run) > 1:
            out.append(np.array(run, int))
    return out


def extrude(m, select, disp, rings=3, zone=0, part=None, weights=None):
    """New cloth grown from the boundary edges `select` keeps (both ends): ring s = 1..rings of each edge vertex at
    p + disp(fit, P0, N0, s) (P0, N0: the edge's positions and surface normals in that fit, s in (0, 1]). The strips
    take the root's weights unless `weights(W_root, P_ring_ref, s)` says otherwise. Returns a piece (its first ring
    is a copy of the edge, so it joins when welded)."""
    be, _ = m.boundary()
    keep = open_boundary(m) & np.asarray(select(m.ref()), bool)
    be = be[keep[be[:, 0]] & keep[be[:, 1]]]
    if not len(be):
        return None
    verts = np.unique(be)
    col = {int(v): i for i, v in enumerate(verts)}
    nv = len(verts)
    Nfit = {k: vertex_normals(m.V[k], m.F) for k in m.V}
    V = {}
    for k in m.V:
        P0, N0 = m.V[k][verts], Nfit[k][verts]
        rows = [P0] + [P0 + disp(k, P0, N0, i / rings) for i in range(1, rings + 1)]
        V[k] = np.concatenate(rows)
    W0 = m.A["W"][verts]
    Ws = [W0]
    for i in range(1, rings + 1):
        Ws.append(W0 if weights is None else weights(W0, V[REF][i * nv:(i + 1) * nv], i / rings))
    A = {"W": np.concatenate(Ws)}
    for name, arr in m.A.items():
        if name != "W":
            A[name] = np.concatenate([arr[verts]] * (rings + 1))
    F = []
    for a, b in be.tolist():
        for i in range(rings):
            q = (i * nv + col[a], i * nv + col[b], (i + 1) * nv + col[b], (i + 1) * nv + col[a])
            F += [(q[0], q[1], q[2]), (q[0], q[2], q[3])]
    F = np.array(F, int)
    # facing like the surface it grows from
    P = V[REF]
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    ref_n = np.concatenate([Nfit[REF][verts]] * (rings + 1))[F].mean(1)
    fl = (fn * ref_n).sum(1) < 0
    F[fl] = F[fl][:, ::-1]
    # region / part of the face each edge belongs to
    E = np.concatenate([m.F[:, [0, 1]], m.F[:, [1, 2]], m.F[:, [2, 0]]])
    fidx = np.tile(np.arange(len(m.F)), 3)
    look = {(int(a), int(b)): int(f) for (a, b), f in zip(E.tolist(), fidx.tolist())}
    src = np.repeat([look.get((a, b), look.get((b, a), 0)) for a, b in be.tolist()], 2 * rings)
    out = Mesh.__new__(Mesh)
    out.V = V
    out.N = {k: vertex_normals(v, F) for k, v in V.items()}
    out.A = A
    out.F = F
    out.fa = {k: v[src].copy() for k, v in m.fa.items()}
    out.fa["zone"][:] = zone
    if part is not None:
        out.fa["part"][:] = part
    return out


def drop_small(m, min_faces=12):
    """Removes islands of fewer than `min_faces` faces (slivers a cut left behind)."""
    nf = len(m.F)
    parent = np.arange(m.n)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for a, b, c in m.F.tolist():
        ra, rb, rc = find(a), find(b), find(c)
        parent[rb] = ra
        parent[find(rc)] = ra
    roots = np.array([find(v) for v in m.F[:, 0]])
    u, cnt = np.unique(roots, return_counts=True)
    big = set(u[cnt >= min_faces].tolist())
    keep = np.array([r in big for r in roots], bool)
    if keep.all() or not nf:
        return m
    return m.faces_of(keep)
