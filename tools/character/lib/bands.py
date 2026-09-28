"""Edge distances for bands drawn by the shader (design §7.4, §8.3): ribbons and bead
edging on leggings and skirts, the white list of stroud cloth, regimental lace, quill
bands. No extra geometry: the cloth shader reads CUSTOM0 = (distance from the hem or
lower edge, distance from the front / opening edge) in metres.

    d_hem = bands.edge_distance(ob, bands.boundary_verts(ob, select=lambda P: P[:, 2] < 0.5))
    d_open = bands.edge_distance(ob, bands.boundary_verts(ob, select=...))
    bands.write_edge_uv(ob, d_hem, d_open)        # UV layer "Edge" (TEXCOORD_2 -> CUSTOM0)

The distances are geodesic along the mesh edges (Dijkstra). The exporter writes v as
1 - v, so write_edge_uv stores 1 - d_open and Godot reads CUSTOM0.y = d_open.
"""

import heapq

import numpy as np

from .remesh import mesh_arrays


def boundary_verts(ob, select=None):
    """Vertices on open boundary edges (one face), optionally filtered by select(P)."""
    me = ob.data
    count = {}
    for p in me.polygons:
        vs = list(p.vertices)
        for i in range(len(vs)):
            e = tuple(sorted((vs[i], vs[(i + 1) % len(vs)])))
            count[e] = count.get(e, 0) + 1
    b = np.zeros(len(me.vertices), bool)
    for (a, c), n in count.items():
        if n == 1:
            b[a] = b[c] = True
    if select is not None:
        b &= np.asarray(select(mesh_arrays(ob)), bool)
    return np.nonzero(b)[0]


def edge_distance(ob, sources, max_d=1.0):
    """Geodesic (edge-path) distance of every vertex to the nearest source vertex (m)."""
    V = mesh_arrays(ob)
    me = ob.data
    adj = [[] for _ in range(len(V))]
    for e in me.edges:
        a, b = e.vertices
        L = float(np.linalg.norm(V[a] - V[b]))
        adj[a].append((b, L))
        adj[b].append((a, L))
    d = np.full(len(V), max_d)
    h = []
    for s in sources:
        d[s] = 0.0
        h.append((0.0, int(s)))
    heapq.heapify(h)
    while h:
        dd, v = heapq.heappop(h)
        if dd > d[v]:
            continue
        for n, L in adj[v]:
            nd = dd + L
            if nd < d[n]:
                d[n] = nd
                heapq.heappush(h, (nd, n))
    return d


def write_edge_uv(ob, d_hem, d_open=None, name="Edge"):
    """Per-loop UV layer `name` (after UVMap and Region, so it is TEXCOORD_2)."""
    me = ob.data
    for n in ("UVMap", "Region"):
        if me.uv_layers.get(n) is None:
            me.uv_layers.new(name=n)
    lay = me.uv_layers.get(name) or me.uv_layers.new(name=name)
    lv = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv)
    d_open = np.full(len(d_hem), 1.0) if d_open is None else d_open
    uv = np.stack([np.asarray(d_hem)[lv], 1.0 - np.asarray(d_open)[lv]], 1)
    lay.data.foreach_set("uv", uv.astype(np.float32).ravel())
    return lay
