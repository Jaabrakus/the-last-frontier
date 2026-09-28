"""Card strips along curves: loose hair strands, braid tufts, fringe (design §10.3).

    paths = [Card(points, widths, normal_hint), ...]
    ob = cards_object("hair_x_cards", paths, mat)

A card is a flat ribbon along a polyline (points (k, 3), widths (k,)), facing
`normal_hint` (e.g. away from the head) and twisted to stay perpendicular to the path.
UVMap: u = across the card in metres (0 at its centre line), v = along it in metres from
the root. The Region UV's v holds h = root (0) .. tip (1), which the hair and fringe
shaders use for the taper and the alpha fade (Godot reads UV2.y = 1 - h). The shaders
draw the strands procedurally; cards are rendered double-sided with alpha to coverage.
"""

import numpy as np

from .remesh import mesh_object
from .sdf import nrm


class Card:
    def __init__(self, points, widths, normal_hint, twist=0.0):
        self.P = np.asarray(points, float)
        self.w = np.broadcast_to(np.asarray(widths, float), (len(self.P),)).copy()
        self.n = np.asarray(normal_hint, float)
        if self.n.ndim == 1:
            self.n = np.repeat(self.n[None], len(self.P), 0)
        self.twist = float(twist)


def resample(points, n):
    """n points evenly spaced along the polyline."""
    P = np.asarray(points, float)
    seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    t = np.linspace(0.0, s[-1], n)
    return np.stack([np.interp(t, s, P[:, k]) for k in range(3)], 1)


def bezier(p0, p1, p2, p3, n):
    t = np.linspace(0.0, 1.0, n)[:, None]
    return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * t * t * p2 + (t ** 3) * p3


def strip_arrays(cards):
    """(V, quads, uv per vertex (n, 2), h per vertex, card index per vertex)."""
    V, Q, UVs, H, C = [], [], [], [], []
    base = 0
    for ci, c in enumerate(cards):
        P = c.P
        k = len(P)
        T = np.gradient(P, axis=0)
        T /= np.maximum(np.linalg.norm(T, axis=1, keepdims=True), 1e-12)
        s = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))])
        for i in range(k):
            n = c.n[i] - T[i] * (c.n[i] @ T[i])
            n = nrm(n) if np.linalg.norm(n) > 1e-9 else nrm(np.cross(T[i], [1.0, 0, 0]))
            side = nrm(np.cross(T[i], n))
            if c.twist:
                a = c.twist * s[i]
                side = side * np.cos(a) + n * np.sin(a)
            hw = 0.5 * c.w[i]
            V += [P[i] - side * hw, P[i] + side * hw]
            UVs += [(-hw, s[i]), (hw, s[i])]
            h = s[i] / max(s[-1], 1e-9)
            H += [h, h]
            C += [ci, ci]
        for i in range(k - 1):
            a = base + 2 * i
            Q.append((a, a + 1, a + 3, a + 2))
        base += 2 * k
    return np.array(V), np.array(Q, int), np.array(UVs), np.array(H), np.array(C)


def cards_object(name, cards, mat):
    """Blender object of the cards with UVMap (metres) set; returns (object, h per vertex,
    card index per vertex). The caller writes the Region UV (with h) via the pipeline."""
    V, Q, UVs, H, C = strip_arrays(cards)
    ob = mesh_object(name, V, Q, mat)
    me = ob.data
    lay = me.uv_layers.new(name="UVMap")
    lv = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv)
    lay.data.foreach_set("uv", UVs[lv].astype(np.float32).ravel())
    for p in me.polygons:
        p.use_smooth = True
    return ob, H, C
