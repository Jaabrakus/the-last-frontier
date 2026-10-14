"""The moorings' heron (places_se.md §9.5, PROPOSAL): our own standing-heron mark for the Reed Marches' banners, in the
village kit's mark grammar (tools/thuyvan_art/village/marks.py: straight cuts as capsules and at most one ring, as a
dyer would cut a stencil). Three variants for the owner (A/B/C); none copies the Đồng Lau sheet's painted heron, any
crest of a people (the heron is the moorings' common sign, not a people's), any Avatar: The Last Airbender emblem, or any
writing.

Importing this module registers the marks in marks.MARKS, so paint_village's cloth_mark() can stamp them.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "village"))
import marks  # noqa: E402

# A standing heron in profile facing left: two stilt legs, a thick tilted body, an S-neck of three cuts, a long beak,
# one trailing plume; the ring is the water at its feet.
_HERON = [
    ("seg", 0.06, -0.94, 0.08, -0.26, 0.07),      # near leg
    ("seg", 0.26, -0.94, 0.20, -0.28, 0.07),      # far leg
    ("seg", -0.08, -0.06, 0.34, -0.26, 0.38),     # breast and body
    ("seg", 0.30, -0.22, 0.66, -0.46, 0.22),      # back, sloping to the tail
    ("seg", 0.60, -0.42, 0.80, -0.60, 0.09),      # tail feathers
    ("seg", -0.14, 0.04, 0.04, 0.30, 0.12),       # neck, lower
    ("seg", 0.04, 0.30, -0.16, 0.52, 0.11),       # neck, the S
    ("seg", -0.16, 0.52, -0.04, 0.64, 0.15),      # head
    ("seg", -0.14, 0.60, -0.60, 0.50, 0.065),     # beak, a short dagger
    ("seg", 0.00, 0.66, 0.26, 0.56, 0.04),        # plume, drooping back
]

MARKS = {
    # A: the heron alone, its water-ring at its feet (a flat ellipse made by one ring cut low).
    "heron_standing": _HERON + [
        ("seg", -0.62, -0.96, 0.82, -0.96, 0.07),  # the water line
        ("seg", -0.40, -0.80, -0.10, -0.80, 0.05),  # two short ripple cuts
        ("seg", 0.40, -0.80, 0.66, -0.80, 0.05),
    ],
    # B: the heron inside the one ring (the mooring's ring), smaller.
    "heron_ring": [(p[0],) + tuple(v * 0.70 for v in p[1:5]) + (p[5] * 0.8,) for p in _HERON] + [
        ("ring", 0.0, 0.0, 0.92, 0.09),
    ],
    # C: the heron between two reed stalks, each stalk a straight cut with a cattail head (a fat short cut).
    "heron_reeds": [(p[0], p[1] * 0.8 + 0.05, p[2] * 0.8 - 0.1, p[3] * 0.8 + 0.05, p[4] * 0.8 - 0.1, p[5] * 0.85)
                    for p in _HERON] + [
        ("seg", -0.86, -0.96, -0.80, 0.70, 0.05),
        ("seg", -0.80, 0.42, -0.79, 0.70, 0.14),
        ("seg", 0.86, -0.96, 0.92, 0.88, 0.05),
        ("seg", 0.91, 0.58, 0.92, 0.86, 0.14),
        ("seg", -0.92, -0.96, 0.96, -0.96, 0.07),
    ],
}

marks.MARKS.update(MARKS)
