"""Ring arm pieces: a close cover of the forearm grown off the skin (the leggings' method on the arms), from arm
parameter t0 (0 shoulder .. 1 wrist) to the wrist."""

import numpy as np

from cloth2.mesh import BIG_FIELD, smoothstep

FOREARM = ["forearm_a_l", "forearm_b_l", "forearm_c_l", "wrist_l", "forearm_a_r", "forearm_b_r", "forearm_c_r",
           "wrist_r"]


def forearm(g, t0, ease, t1=1.0):
    g.shell(FOREARM, base="skin")
    g.fit(ease=ease, smooth=2, gap=0.002)
    t =np.maximum(g.m.A["t_arm_l"] * (g.m.A["m_arm_l"] > 0.5), g.m.A["t_arm_r"] * (g.m.A["m_arm_r"] > 0.5))
    g.m = g.m.clip(t - t0, 0.0)
    if t1 < 1.0:
        t = np.maximum(g.m.A["t_arm_l"] * (g.m.A["m_arm_l"] > 0.5), g.m.A["t_arm_r"] * (g.m.A["m_arm_r"] > 0.5))
        g.m = g.m.clip(t1 - t, 0.0)
    return g


def rims(g, zone, width, h):
    """Raised rims at both open ends (the band within `width` of each boundary)."""
    g.edge_zone(zone, width, h=h)
    return g


def arm_axis_field(g, fn):
    """fn(u, phi) per vertex on each forearm: u metres from the elbow along the forearm, phi radians round it."""
    out = np.full(g.m.n, BIG_FIELD)
    P = g.P
    for s in ("l", "r"):
        sh, el, wr = g.fits.arm(s)
        ax = (wr - el) / np.linalg.norm(wr - el)
        on = (P[:, 0] > 0.0) if s == "l" else (P[:, 0] < 0.0)
        q = P - el
        u = q @ ax
        r = q - u[:, None] * ax
        ref = np.cross(ax, [0.0, 0.0, 1.0])
        ref = ref / max(np.linalg.norm(ref), 1e-9)
        ref2 = np.cross(ax, ref)
        phi = np.arctan2(r @ ref2, r @ ref)
        out[on] = fn(u, phi)[on]
    return out
