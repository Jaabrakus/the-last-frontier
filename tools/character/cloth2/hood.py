"""cloth2 hood: a hood lying folded on the back of a coat (2026-10-02; the capot's, a hooded cloak's).

  hood_on_back(g, tip_z=1.06, half_w=0.128, zone=1)

A hood thrown back lies on the shoulders as a flattened bag: its crown fold at the neck, its sides falling to a
rounded point between the shoulder blades, the face opening rolled over across the top. It is made of the coat's own
back faces inside that outline, copied off the coat by a thickness that is greatest over the upper back (the crown
folded in it), less at the neckline and least at its sides and point, with a rim down to the coat (trims.overlay); a
ridge in a curve across the top is the opening's rolled edge. The copy keeps the coat's weights, so it moves with the
back.
"""

import numpy as np

from cloth2 import trims as TR
from cloth2.mesh import BIG_FIELD, REF, smoothstep


def _width(Z, tip_z, top_z, half_w, neck=(0.08, 0.80)):
    """The hood's half-width at height Z: a rounded V from the point up to the shoulders, drawn in toward the neckline
    by neck[0] of its width from neck[1] of the way up (0.30, 0.70: sewn to the neckline, its sides falling onto the
    shoulder blades rather than over the tops of the shoulders)."""
    u = np.clip((Z - tip_z) / (top_z - tip_z), 0.0, 1.0)
    return half_w * np.clip(u * 1.05, 0.0, 1.0) ** 0.62 * (1.0 - neck[0] * smoothstep(neck[1], 1.0, u))


def hood_outline(g, tip_z, half_w, top_z, neck=(0.08, 0.80), corner=0.0):
    """Field (< 0 inside) of the hood's outline on the back: widest at the shoulders, a rounded point at tip_z."""
    arm = np.maximum(g.m.A["m_arm_l"], g.m.A["m_arm_r"])
    neck_x, neck_z = np.array([-1.0, 1.0]), np.array([9.0, 9.0])
    if corner:
        # the neckline behind: the open edge's height across the back
        _, onb = g.m.boundary()
        P = g.m.V[REF]
        nb = onb & (P[:, 1] > 0.0) & (P[:, 2] > top_z - 0.08)
        if nb.sum() > 3:
            o = np.argsort(P[nb, 0])
            neck_x, neck_z = P[nb, 0][o], P[nb, 2][o]

    def f(P):
        X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
        f = np.maximum(np.abs(X) - _width(Z, tip_z, top_z, half_w, neck), tip_z - Z)
        if corner:
            # the top corners rounded off (they would stand up where the shoulders slope away from the neck): below
            # the neckline's own height there by up to `corner`, from 55% of the top's half-width out
            w_top = _width(np.array([top_z]), tip_z, top_z, half_w, neck)[0]
            nz = np.interp(X, neck_x, neck_z)
            f = np.maximum(f, Z - (nz + 0.004 - corner * smoothstep(0.55, 1.05, np.abs(X) / w_top)))
        return f + \
            BIG_FIELD * (1.0 - smoothstep(0.0, 0.03, Y))
    return f, arm


def hood_on_back(g, tip_z=1.06, half_w=0.128, h_max=0.022, h_neck=0.012, h_edge=0.0035, roll=0.006, zone=1,
                 top_z=None, neck=(0.08, 0.80), seam=0.0, corner=0.0):
    """The hood (see the module docstring) joined to g.m in zone `zone`: thickest (h_max, m) over the upper back where
    the hood's crown lies folded, h_neck at the neckline, h_edge at its sides and point (a soft bag, not a slab);
    `roll`: the rolled edge of the face opening, a ridge in a curve across its top (dipping at the middle); `neck`: how
    much it is drawn in toward the neckline and from where (see _width); `seam`: the depth (m) of the groove its back
    seam makes down the middle (0: none); `corner`: how far (m) its top corners are rounded down."""
    P = g.P
    if top_z is None:
        back = (P[:, 1] > 0.02) & (np.abs(P[:, 0]) < 0.03)
        top_z = float(P[back, 2].max()) if back.any() else 1.34
    f, arm = hood_outline(g, tip_z, half_w, top_z, neck, corner)
    vals = f(g.P) + BIG_FIELD * smoothstep(0.1, 0.3, arm)
    g.m, sel = TR.split_mask(g.m, vals)

    def thick(Q):
        X, Z = Q[:, 0], Q[:, 2]
        u = np.clip((Z - tip_z) / (top_z - tip_z), 0.0, 1.0)
        wv = _width(Z, tip_z, top_z, half_w, neck) + 1e-3
        across = np.sqrt(np.clip(1.0 - (X / wv) ** 2, 0.0, 1.0))
        # along: from the point up to the fullest place (u ~ 0.62), then down to the neckline
        along = np.where(u < 0.62, np.sin(0.5 * np.pi * np.clip(u / 0.62, 0.0, 1.0)) ** 0.8,
                         1.0 - (1.0 - h_neck / h_max) * smoothstep(0.62, 1.0, u))
        h = h_edge + (h_max - h_edge) * across * along
        if roll:
            zo = top_z - 0.028 - 0.05 * np.clip(1.0 - (X / (half_w * 0.95)) ** 2, 0.0, 1.0)
            h = h + roll * np.exp(-((Z - zo) / 0.011) ** 2) * smoothstep(0.0, 0.3, across)
        if seam:
            # the hood's back seam down its middle, from below the rolled edge to the point: a soft groove
            h = h - seam * np.exp(-(X / 0.007) ** 2) * smoothstep(0.02, 0.25, u) * (1.0 - smoothstep(0.55, 0.75, u))
        return h
    piece = TR.overlay(g.m, sel, thick, zone, rim=True, rim_frac=0.15)
    if piece is not None:
        g.add(piece)
    return g
