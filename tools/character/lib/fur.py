"""Fur (design §9): baked shells in one surface plus guard-hair cards.

    sh, h = fur.shells(base_ob, n=12, max_tris=2400)       # n stacked copies of the base
    cards = fur.guard_cards(base_ob, count=1500, length=0.07, comb=(0, 0, -1))
    ob, h2, _ = lib.cards.cards_object(id + "_fur_cards", cards, mat)

Shells are n copies of the (decimated) outer surface at the SAME bind positions; the fur
shader moves each along its skinned normal by h * length * COLOR.a (the flatten mask,
0.2 under belts) plus a droop h^2 toward world-down and a comb lean. h = shell / n goes
into the Region UV's v (Godot: UV2.y = 1 - h), so shells need no extra attribute and
share the base's weights (the pipeline transfers them from the base surface).
Guard cards are short strips rooted on the base surface, leaning along `comb`.
"""

import numpy as np

from .cards import Card
from .remesh import decimate, mesh_arrays, tri_count
from .sdf import nrm


def shells(base_ob, n=12, max_tris=2400, name=None):
    """(object with n shell copies, h per vertex in (0, 1])."""
    import bpy
    ob = base_ob.copy()
    ob.data = base_ob.data.copy()
    ob.name = name or (base_ob.name + "_shells")
    bpy.context.scene.collection.objects.link(ob)
    decimate(ob, max_tris, symmetric=True)
    me = ob.data
    V = mesh_arrays(ob)
    F = [tuple(p.vertices) for p in me.polygons]
    nv = len(V)
    allV, allF, h = [], [], []
    for k in range(1, n + 1):
        allV.append(V)
        allF += [tuple(i + (k - 1) * nv for i in f) for f in F]
        h.append(np.full(nv, k / float(n)))
    me2 = bpy.data.meshes.new(ob.name)
    me2.from_pydata([tuple(v) for v in np.concatenate(allV)], [], allF)
    me2.update()
    old = ob.data
    ob.data = me2
    bpy.data.meshes.remove(old)
    for p in me2.polygons:
        p.use_smooth = True
    return ob, np.concatenate(h)


def surface_samples(ob, count, seed=1):
    """Area-weighted random points on the mesh: (points, normals, polygon index)."""
    rng = np.random.default_rng(seed)
    me = ob.data
    me.calc_loop_triangles()
    V = mesh_arrays(ob)
    T = np.array([t.vertices[:] for t in me.loop_triangles], int)
    poly = np.array([t.polygon_index for t in me.loop_triangles], int)
    A = 0.5 * np.linalg.norm(np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]]), axis=1)
    pick = rng.choice(len(T), size=count, p=A / A.sum())
    r1, r2 = rng.random(count), rng.random(count)
    s = np.sqrt(r1)
    b = np.stack([1 - s, s * (1 - r2), s * r2], 1)
    P = np.einsum("ij,ijk->ik", b, V[T[pick]])
    N = np.cross(V[T[pick, 1]] - V[T[pick, 0]], V[T[pick, 2]] - V[T[pick, 0]])
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
    return P, N, poly[pick]


def guard_cards(base_ob, count=1500, length=0.06, width=0.004, comb=(0.0, 0.0, -1.0), lean=0.7, seed=2, segs=3):
    """Short cards rooted on the base surface, leaning `lean` of the way from the normal
    toward the comb direction (tangent to the surface)."""
    rng = np.random.default_rng(seed)
    P, N, _ = surface_samples(base_ob, count, seed)
    comb = nrm(comb)
    cards = []
    for p, n in zip(P, N):
        t = comb - n * (comb @ n)
        t = nrm(t) if np.linalg.norm(t) > 1e-6 else nrm(np.cross(n, [1.0, 0, 0]))
        L = length * (0.7 + 0.6 * rng.random())
        d = nrm(n * (1 - lean) + t * lean)
        pts = [p + d * L * (i / segs) + t * L * 0.15 * (i / segs) ** 2 for i in range(segs + 1)]
        cards.append(Card(pts, np.linspace(width, width * 0.4, segs + 1), n))
    return cards


def stats(ob):
    return {"tris": tri_count(ob), "verts": len(ob.data.vertices)}
