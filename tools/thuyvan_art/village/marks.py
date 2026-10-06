"""Our own clan marks for the Thủy Vân village kit (banners, the clan waystone, prayer-flag prints).

Style guide section 9: marks are geometric knot, mountain and tally forms built from straight cuts and at most one
ring, as a stonemason or a dyer would cut them. Nothing here resembles the Trường Sơn sheet's swirl emblem (an Avatar
emblem look-alike), the sheet's ring-and-rune bridge marks, the Thạch Uyên diamond knot, or the Tidebreak ring's element
glyphs. No writing, no Hán characters.

Every mark is a list of primitives in [-1, 1]^2 (y up):
    ("seg", x0, y0, x1, y1, width)      a straight cut (a capsule)
    ("ring", cx, cy, radius, width)     the one ring
    ("poly", [(x, y), ...])             a filled polygon (straight edges)
mask(name, X, Y) rasterises one to a float coverage.
"""

import numpy as np

MARKS = {
    # The Two Heights: two peaks of unequal height standing on one base cut, the sun-ring held between them, and the
    # three tally cuts of the clan's founding families under the base.
    "two_peaks": [
        ("seg", -0.80, -0.30, -0.36, 0.52, 0.13),
        ("seg", -0.36, 0.52, 0.02, -0.30, 0.13),
        ("seg", -0.10, -0.30, 0.34, 0.30, 0.13),
        ("seg", 0.34, 0.30, 0.80, -0.30, 0.13),
        ("seg", -0.92, -0.36, 0.92, -0.36, 0.12),
        ("ring", 0.10, 0.70, 0.17, 0.08),
        ("seg", -0.36, -0.58, -0.36, -0.86, 0.11),
        ("seg", 0.00, -0.58, 0.00, -0.86, 0.11),
        ("seg", 0.36, -0.58, 0.36, -0.86, 0.11),
    ],
    # Terraces and the river: three stepped terrace bars, shortest on top, cut through by a falling zig-zag stream;
    # the spring-ring at its head.
    "terrace_river": [
        ("seg", -0.78, -0.62, 0.78, -0.62, 0.12),
        ("seg", -0.56, -0.20, 0.56, -0.20, 0.12),
        ("seg", -0.34, 0.22, 0.34, 0.22, 0.12),
        ("seg", 0.00, 0.58, -0.16, 0.40, 0.10),
        ("seg", -0.16, 0.40, 0.16, 0.02, 0.10),
        ("seg", 0.16, 0.02, -0.16, -0.40, 0.10),
        ("seg", -0.16, -0.40, 0.10, -0.86, 0.10),
        ("ring", 0.00, 0.74, 0.15, 0.07),
    ],
    # The ledge pine: a straight stem with three pairs of down-swept branch cuts, rooted in the ring (the rock).
    "pine_ring": [
        ("seg", 0.0, -0.52, 0.0, 0.90, 0.12),
        ("seg", 0.0, 0.78, -0.30, 0.50, 0.10),
        ("seg", 0.0, 0.78, 0.30, 0.50, 0.10),
        ("seg", 0.0, 0.40, -0.50, 0.04, 0.10),
        ("seg", 0.0, 0.40, 0.50, 0.04, 0.10),
        ("seg", 0.0, 0.00, -0.68, -0.40, 0.10),
        ("seg", 0.0, 0.00, 0.68, -0.40, 0.10),
        ("ring", 0.0, -0.68, 0.22, 0.09),
    ],
    # Two small neighbour-clan marks for the waystone's lower rows ("each clan's version differs, carved in many
    # hands"): a crossed staff, and a stepped gate.
    "crossed_staff": [
        ("seg", -0.6, -0.8, 0.6, 0.8, 0.16),
        ("seg", 0.6, -0.8, -0.6, 0.8, 0.16),
        ("seg", -0.7, 0.0, 0.7, 0.0, 0.16),
    ],
    "stepped_gate": [
        ("seg", -0.7, -0.8, -0.7, 0.4, 0.16),
        ("seg", 0.7, -0.8, 0.7, 0.4, 0.16),
        ("seg", -0.9, 0.4, 0.9, 0.4, 0.16),
        ("seg", -0.5, 0.8, 0.5, 0.8, 0.16),
        ("seg", 0.0, 0.4, 0.0, 0.8, 0.16),
    ],
}


def _seg_dist(X, Y, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    t = np.clip(((X - x0) * dx + (Y - y0) * dy) / max(dx * dx + dy * dy, 1e-12), 0.0, 1.0)
    return np.hypot(X - (x0 + t * dx), Y - (y0 + t * dy))


def _inside(poly, X, Y):
    poly = np.asarray(poly, float)
    res = np.zeros(X.shape, bool)
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        res ^= ((yi > Y) != (yj > Y)) & (X < (xj - xi) * (Y - yi) / (yj - yi + 1e-12) + xi)
        j = i
    return res


def sdf(name, X, Y):
    """Signed-ish distance (negative inside) of a mark, in mark units."""
    d = np.full(X.shape, 9.0)
    for p in MARKS[name]:
        if p[0] == "seg":
            _, x0, y0, x1, y1, w = p
            d = np.minimum(d, _seg_dist(X, Y, x0, y0, x1, y1) - w / 2)
        elif p[0] == "ring":
            _, cx, cy, r, w = p
            d = np.minimum(d, np.abs(np.hypot(X - cx, Y - cy) - r) - w / 2)
        elif p[0] == "poly":
            ins = _inside(p[1], X, Y)
            d = np.where(ins, np.minimum(d, -0.01), d)
    return d


def mask(name, X, Y, soft=0.012):
    d = sdf(name, X, Y)
    return np.clip(0.5 - d / (2 * soft), 0.0, 1.0)
