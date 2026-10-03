"""cloth2 mesh: a garment mesh that exists in every body fit at once (2026-09-28).

The user asked for every garment to be remade ("discard and redo"): the old ones were shaped round the old
procedural body and did not fit the MakeHuman body (a shift the bust came through, breeches that left the
crotch bare). cloth2 grows garments from the body's own surface instead: a garment is a mesh whose
vertices exist in each *fit* of the body (the female base, the male fit, the two ends of the bust gauge) with
one topology, so the male fit and the bust gauge are exact morph targets and nothing is ever wrapped.

Every topology decision (which faces, where a cut runs) is made on the reference fit ("f", the female base)
and replayed on the others with the same interpolation weights; positions come from each fit.

  Mesh.V[fit]      (n, 3) positions in that fit
  Mesh.N[fit]      (n, 3) unit normals of the base surface (the direction offsets go)
  Mesh.A[name]     per-vertex attributes (the body's skin weights "W", ...), interpolated on cuts
  Mesh.fa[name]    per-face attributes (the body region "region", the garment's "zone", the "part"), carried

The operations return new meshes (or change fits in place where they say so).
"""

import numpy as np

REF = "f"
BIG_FIELD = 10.0     # added to a cut field where it must not cut (keeps the field continuous)
FITS = ("f", "m", "bl", "bs")
# body blend shape name -> the fit that is that shape at weight 1 (garments carry the same names)
SHAPE_FIT = {"sex": "m", "breast_large": "bl", "breast_small": "bs"}


def unit(v, eps=1e-12):
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), eps)


def vertex_normals(V, F):
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    N = np.zeros_like(V)
    for k in range(3):
        np.add.at(N, F[:, k], fn)
    return unit(N)


def smoothstep(a, b, x):
    t = np.clip((np.asarray(x, float) - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


class Mesh:
    def __init__(self, V, F, N=None, A=None, fa=None):
        self.V = {k: np.asarray(v, float).copy() for k, v in V.items()}
        self.F = np.asarray(F, int).copy()
        self.N = {k: unit(np.asarray(v, float)) for k, v in (N or {}).items()} if N else \
            {k: vertex_normals(v, self.F) for k, v in self.V.items()}
        self.A = {k: np.asarray(v, float).copy() for k, v in (A or {}).items()}
        self.fa = {k: np.asarray(v).copy() for k, v in (fa or {}).items()}

    # ---- basics ---------------------------------------------------------------------------------
    @property
    def n(self):
        return len(self.V[REF])

    def copy(self):
        return Mesh(self.V, self.F, self.N, self.A, self.fa)

    def ref(self):
        return self.V[REF]

    def faces_of(self, mask):
        """The mesh of the faces in `mask` (a bool array over faces), vertices compacted."""
        F = self.F[mask]
        used = np.unique(F)
        remap = -np.ones(self.n, int)
        remap[used] = np.arange(len(used))
        return Mesh({k: v[used] for k, v in self.V.items()}, remap[F], {k: v[used] for k, v in self.N.items()},
                    {k: v[used] for k, v in self.A.items()}, {k: v[mask] for k, v in self.fa.items()})

    def face_centres(self, fit=REF):
        return self.V[fit][self.F].mean(1)

    def edges(self):
        E = np.concatenate([self.F[:, [0, 1]], self.F[:, [1, 2]], self.F[:, [2, 0]]])
        return E

    def boundary(self):
        """(boundary edges (k, 2) in face order, bool per vertex)."""
        E = self.edges()
        key = np.sort(E, 1)
        u, inv, cnt = np.unique(key, axis=0, return_inverse=True, return_counts=True)
        inv = inv.ravel()
        b = cnt[inv] == 1
        onb = np.zeros(self.n, bool)
        onb[E[b].ravel()] = True
        return E[b], onb

    def adjacency(self):
        """Symmetric edge list (both directions), for smoothing."""
        E = np.unique(np.sort(self.edges(), 1), axis=0)
        return np.concatenate([E, E[:, ::-1]])

    # ---- cutting --------------------------------------------------------------------------------
    def clip(self, field, level=0.0, keep_above=True):
        """Keeps what is on the `keep_above` side of field == level. `field` is per vertex (from the reference
        fit); triangles that cross the level are cut, the new vertices lie on the edges at the same fraction in
        every fit."""
        f = np.asarray(field, float) - level
        if not keep_above:
            f = -f
        inside = f > 1e-9
        F = self.F
        ins = inside[F]
        cnt = ins.sum(1)
        full = cnt == 3
        mixed = (cnt == 1) | (cnt == 2)
        new_v = {}
        verts_i, verts_j, verts_t = [], [], []
        base = self.n

        def point(i, j):
            # the vertex on edge i -> j (f[i] > 0 >= f[j] or the reverse): fraction from i
            key = (i, j) if i < j else (j, i)
            if key not in new_v:
                a, b = key
                fa_, fb_ = f[a], f[b]
                t = fa_ / (fa_ - fb_)
                new_v[key] = base + len(verts_i)
                verts_i.append(a)
                verts_j.append(b)
                verts_t.append(t)
            return new_v[key]
        out_faces = [F[full]]
        out_fa = {k: [v[full]] for k, v in self.fa.items()}
        extra_f, extra_src = [], []
        for fi in np.nonzero(mixed)[0]:
            a, b, c = F[fi]
            ia, ib, ic = ins[fi]
            if cnt[fi] == 1:
                if ib:
                    a, b, c = b, c, a
                elif ic:
                    a, b, c = c, a, b
                extra_f.append((a, point(a, b), point(c, a)))
                extra_src.append(fi)
            else:
                if not ia:
                    a, b, c = b, c, a
                elif not ib:
                    a, b, c = c, a, b
                # a, b inside, c outside
                pbc, pca = point(b, c), point(c, a)
                extra_f.append((a, b, pbc))
                extra_src.append(fi)
                extra_f.append((a, pbc, pca))
                extra_src.append(fi)
        if extra_f:
            out_faces.append(np.array(extra_f, int))
            for k, v in self.fa.items():
                out_fa[k].append(v[np.array(extra_src, int)])
        Fn = np.concatenate(out_faces)
        fa_new = {k: np.concatenate(v) for k, v in out_fa.items()}
        if verts_i:
            vi = np.array(verts_i)
            vj = np.array(verts_j)
            t = np.array(verts_t)
            lerp = lambda arr: np.concatenate([arr, arr[vi] * (1 - t)[:, None] + arr[vj] * t[:, None]]
                                              if arr.ndim == 2 else [arr, arr[vi] * (1 - t) + arr[vj] * t])
            V = {k: lerp(v) for k, v in self.V.items()}
            N = {k: unit(lerp(v)) for k, v in self.N.items()}
            A = {k: lerp(v) for k, v in self.A.items()}
        else:
            V, N, A = self.V, self.N, self.A
        m = Mesh.__new__(Mesh)
        m.V, m.N, m.A, m.F, m.fa = V, N, A, Fn, fa_new
        # (keep only what the kept faces use)
        keep = np.zeros(m.n, bool)
        keep[Fn] = True
        used = np.nonzero(keep)[0]
        remap = -np.ones(m.n, int)
        remap[used] = np.arange(len(used))
        m.V = {k: v[used] for k, v in m.V.items()}
        m.N = {k: v[used] for k, v in m.N.items()}
        m.A = {k: v[used] for k, v in m.A.items()}
        m.F = remap[Fn]
        return m

    def split(self, field, level=0.0):
        """Cuts along field == level so that mesh edges lie on the line (a straight seam for the UV, a straight
        opening): the two sides joined again (welded), the faces now ending on the line."""
        return weld(concat([self.clip(field, level, keep_above=True), self.clip(field, level, keep_above=False)]))

    def cut_out(self, field, lo, hi):
        """Removes the band lo < field < hi (a slit, a neck opening): two clips joined."""
        a = self.clip(field, lo, keep_above=False)
        # `field` is per vertex of self; the second clip needs it on self
        b = self.clip(field, hi, keep_above=True)
        return concat([a, b])

    # ---- shaping --------------------------------------------------------------------------------
    def offset(self, d, vertical=1.0):
        """Moves every vertex along its base normal by d (m; a scalar or per vertex), in every fit. `vertical` scales
        the normal's up-down part (below 1, cut lines stay level: a normal that leans up on one vertex and down on the
        next would zigzag a straight edge)."""
        d = np.asarray(d, float)
        if d.ndim == 0:
            d = np.full(self.n, float(d))
        for k in self.V:
            n = self.N[k].copy()
            n[:, 2] *= vertical
            self.V[k] = self.V[k] + unit(n) * d[:, None]
        return self

    def smooth(self, iters=3, lam=0.5, keep_boundary=True, weights=None):
        """Laplacian smoothing of every fit (the same operator on each). Boundary vertices move along the
        boundary only, so a hem or a cuff line does not shrink. `weights` (per vertex 0..1) scales the step."""
        E = self.adjacency()
        be, onb = self.boundary()
        bnd_edges = np.concatenate([be, be[:, ::-1]]) if len(be) else np.zeros((0, 2), int)
        w = np.ones(self.n) if weights is None else np.asarray(weights, float)
        for _ in range(iters):
            for k in self.V:
                P = self.V[k]
                acc = np.zeros_like(P)
                cnt = np.zeros(self.n)
                if keep_boundary:
                    inner = ~onb[E[:, 0]]
                    np.add.at(acc, E[inner, 0], P[E[inner, 1]])
                    np.add.at(cnt, E[inner, 0], 1.0)
                    if len(bnd_edges):
                        np.add.at(acc, bnd_edges[:, 0], P[bnd_edges[:, 1]])
                        np.add.at(cnt, bnd_edges[:, 0], 1.0)
                else:
                    np.add.at(acc, E[:, 0], P[E[:, 1]])
                    np.add.at(cnt, E[:, 0], 1.0)
                avg = acc / np.maximum(cnt, 1.0)[:, None]
                step = (lam * w)[:, None] * (avg - P)
                step[cnt == 0] = 0.0
                self.V[k] = P + step
        return self

    def recompute_normals(self):
        for k in self.V:
            self.N[k] = vertex_normals(self.V[k], self.F)
        return self


def concat(meshes):
    """The union of meshes with the same fits and attributes (vertices are not merged)."""
    meshes = [m for m in meshes if m is not None and len(m.F)]
    out = meshes[0].copy()
    for m in meshes[1:]:
        off = out.n
        out.V = {k: np.concatenate([out.V[k], m.V[k]]) for k in out.V}
        out.N = {k: np.concatenate([out.N[k], m.N[k]]) for k in out.N}
        out.A = {k: np.concatenate([out.A[k], m.A[k]]) for k in out.A}
        out.F = np.concatenate([out.F, m.F + off])
        out.fa = {k: np.concatenate([out.fa[k], m.fa[k]]) for k in out.fa}
    return out


def weld(m, tol=1e-5):
    """Merges vertices that coincide in the reference fit (the seams of concatenated parts and clipped
    pieces), keeping the first of each."""
    P = m.V[REF]
    key = np.round(P / tol).astype(np.int64)
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    keep = np.sort(first)
    remap_of_first = -np.ones(m.n, int)
    remap_of_first[keep] = np.arange(len(keep))
    # every vertex -> the index of its group's first vertex -> compact index
    group_first = first[inv]
    newidx = remap_of_first[group_first]
    F = newidx[m.F]
    ok = (F[:, 0] != F[:, 1]) & (F[:, 1] != F[:, 2]) & (F[:, 2] != F[:, 0])
    # two slivers welded onto the same three vertices: keep one (a duplicate face makes the mesh invalid in Blender)
    key = np.sort(F, 1)
    _, first_f = np.unique(key, axis=0, return_index=True)
    uniq = np.zeros(len(F), bool)
    uniq[first_f] = True
    ok &= uniq
    out = Mesh.__new__(Mesh)
    out.V = {k: v[keep] for k, v in m.V.items()}
    out.N = {k: v[keep] for k, v in m.N.items()}
    out.A = {k: v[keep] for k, v in m.A.items()}
    out.F = F[ok]
    out.fa = {k: v[ok] for k, v in m.fa.items()}
    return out
