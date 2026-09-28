"""Trade silver (costume bible §3.2, §3.3, §7): crescent gorget, arm and wrist bands, ear
bobs and ring brooches [P1][P2][R2][M11]. Rigid pieces: each band or ornament moves with one
bone (the design's "rigid on the upper spine or neck; arm bands rigid on the upper arm,
respecting the twist helpers"), so they never stretch; brooches take the weights of the
cloth under their centre.
"""

import math

import numpy as np

from lib.body_shapes import arm_shapes, forearm_t, head_shapes, neck_shape, torso_shapes
from lib.sdf import (Ellipsoid, Fn, Offset, RoundCone, Sphere, Union, frame_from, nrm, peval, sdf_normal,
                     surface_point, v3)

from garments.woodlands import _common as C

SILVER = ["silver", "pewter", "brass"]


def ring_on_limb(node, a, b, t0, t1, rows=4, cols=28, bulge=0.0006):
    """Mid-surface grid of a band round the a -> b axis between t0 and t1, lying on the
    surface of `node` (found from outside); the middle rows bulge out a little."""
    ax = nrm(b - a)
    x = nrm(np.cross(ax, v3(0, 1, 0)))
    if np.linalg.norm(np.cross(ax, v3(0, 1, 0))) < 1e-6:
        x = v3(1, 0, 0)
    y = np.cross(ax, x)
    L = np.linalg.norm(b - a)
    P = np.zeros((rows, cols, 3))
    N = np.zeros((rows, cols, 3))
    for i, t in enumerate(np.linspace(t0, t1, rows)):
        c = a + ax * L * t
        for j, ang in enumerate(np.linspace(0.0, 2 * math.pi, cols, endpoint=False)):
            d = x * math.cos(ang) + y * math.sin(ang)
            p = surface_point(node, c + d * 0.12, -d, 0.0, 0.12)
            k = math.sin(math.pi * i / (rows - 1))
            P[i, j] = p + d * bulge * k
            N[i, j] = d
    return P, N


def band_piece(b, name, node, a, b_, t0, t1, thick=0.0012, zone=0):
    P, N = ring_on_limb(node, a, b_, t0, t1)
    return C.sheet_piece(b, name, P, thick, zone, closed_u=True, normals=N)


def crescent_grid(center_fn, width=0.105, drop=0.048, horns=0.018, rows=3, cols=17):
    """Crescent gorget in its local plane: an arc band whose outer edge hangs `drop` below
    the horns and whose inner edge is a shallower arc (the crescent narrows to the horns).
    center_fn(u, v) -> point on the chest (u across, v up from the lowest point)."""
    P = np.zeros((rows, cols, 3))
    for j, s in enumerate(np.linspace(-1.0, 1.0, cols)):
        u = s * width * 0.5
        v_out = drop * (s * s)                        # outer edge (lower): a parabola up to the horns
        v_in = drop * 0.45 + (drop - drop * 0.45) * (s * s) - 0.002 * (1 - s * s)   # inner edge
        v_in = max(v_in, v_out + 0.003 + (horns * 0.0) * (1 - abs(s)))
        width_here = (v_in - v_out)
        for i, t in enumerate(np.linspace(0.0, 1.0, rows)):
            P[i, j] = center_fn(u, v_out + width_here * t)
    return P
