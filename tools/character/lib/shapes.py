"""Shape keys (glTF morph targets): projection of a mesh onto a variant SDF (the male fit,
face features) and writing Blender shape keys.

The base mesh keeps its topology and weights; a shape is only a per-vertex delta, so
the runtime blends it on the GPU (MeshInstance3D blend shapes) before skinning.
"""

import numpy as np

from .remesh import mesh_arrays
from .sdf import project_to_surface
from .wrap import smooth_field


def project_shape(V, target, E=None, sel=None, step=0.008, iters=8, smooth=3, lock=None):
    """Deltas (n, 3) that move the vertices V onto the zero set of the SDF `target`
    (only `sel` if given; the rest stays 0). The delta field is smoothed over the edges E
    (tangential bunching) and re-projected, so vertices stay evenly spread."""
    V = np.asarray(V, float)
    D = np.zeros_like(V)
    idx = np.arange(len(V)) if sel is None else np.nonzero(sel)[0]
    if len(idx) == 0:
        return D
    P = project_to_surface(target, V[idx].copy(), step_max=step, iters=iters)
    D[idx] = P - V[idx]
    if E is not None and smooth > 0:
        keep = np.zeros(len(V), bool) if sel is None else ~np.asarray(sel, bool)
        if lock is not None:
            keep |= lock
        D = smooth_field(D, E, smooth, lock=keep)
        P = project_to_surface(target, V[idx] + D[idx], step_max=step, iters=3)
        D[idx] = P - V[idx]
    return D


def relax_folds(V, F, D, E, sel, iters=40, rings=2):
    """Local repair of a shape delta D (n, 3) on the mesh (V, triangles F, edges E): while a
    triangle with a vertex in `sel` turns over at weight +1 or -1, the delta of its vertices
    and `rings` rings around them (inside `sel`) is smoothed; everything else keeps its delta.
    Projected features can land vertices by a narrow gap (the mouth seam, the alar groove, the
    nostril) on the wrong surface, and the folded skin shades as flecks. Returns (D, folded
    triangles left after `iters` passes)."""
    V = np.asarray(V, float)
    D = np.asarray(D, float).copy()
    sel = np.asarray(sel, bool)
    n0 = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    tri_sel = sel[F].any(1)
    deg = np.bincount(E.ravel(), minlength=len(V)).astype(float)

    def folded(D):
        out = np.zeros(len(F), bool)
        for s in (1.0, -1.0):
            X = V + s * D
            n = np.cross(X[F[:, 1]] - X[F[:, 0]], X[F[:, 2]] - X[F[:, 0]])
            out |= (n * n0).sum(1) < 0
        return out & tri_sel
    for _ in range(iters):
        f = folded(D)
        if not f.any():
            return D, 0
        m = np.zeros(len(V), bool)
        m[F[f].ravel()] = True
        for _r in range(rings):
            grow = m.copy()
            grow[E[m[E[:, 0]], 1]] = True
            grow[E[m[E[:, 1]], 0]] = True
            m = grow
        m &= sel
        acc = np.zeros_like(D)
        np.add.at(acc, E[:, 0], D[E[:, 1]])
        np.add.at(acc, E[:, 1], D[E[:, 0]])
        D[m] = 0.5 * D[m] + 0.5 * (acc / np.maximum(deg, 1)[:, None])[m]
    return D, int(folded(D).sum())


def add_shape_keys(ob, deltas):
    """Adds a Basis (if missing) and one shape key per {name: (n, 3) delta}, value 0."""
    base = mesh_arrays(ob)
    if ob.data.shape_keys is None:
        ob.shape_key_add(name="Basis", from_mix=False)
    for name, D in deltas.items():
        sk = ob.shape_key_add(name=name, from_mix=False)
        sk.data.foreach_set("co", (base + np.asarray(D, float)).astype(np.float32).ravel())
        sk.value = 0.0
    return [k.name for k in ob.data.shape_keys.key_blocks]


def shape_stats(deltas):
    return {n: round(float(np.linalg.norm(D, axis=1).max()), 4) for n, D in deltas.items()}
