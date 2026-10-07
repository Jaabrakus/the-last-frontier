"""Our own marks for Vạn Thủy (places_se.md 9.5), in the VILLAGE marks format (tools/thuyvan_art/village/marks.py):
primitives in [-1, 1]^2, y up: ("seg", x0, y0, x1, y1, width), ("ring", cx, cy, r, width), ("poly", [(x, y), ...]).

* The Cửu Giang court mark (PROPOSAL, owner question 4): a lock gate (two towers and a leaf) inside a ring, gold on
  indigo, drawn as a picture of a gate (filled towers with flicked roofs, an arched leaf, a wave cut), never as
  anything that reads as a letter or a character. Three drawings for the owner to choose from: A in a square stamp
  frame, B a pair of half leaves with the towers breaking the ring, C bold, with falling water cuts. Never "Thủy Vân", never
  the sheets' roundels or red seal, never a count of rivers.
* District marks for the lacquer towers' banners: a net knot (the Lantern Ward), a sheaf (the Grain Piers), a hull (the
  Naval Basin), stacked tablets (the Archive Islands), an umbrella's ribs (the Rain Market).

Cut lines and at most one ring each; no writing, no Hán characters, nothing from any show or game.
register() adds them to the village marks table so its sdf()/mask() and the VILLAGE banner painter draw them.
"""

import math


def _arc(cx, cy, r, a0, a1, n, w):
    pts = [(cx + r * math.cos(a0 + (a1 - a0) * k / n), cy + r * math.sin(a0 + (a1 - a0) * k / n)) for k in range(n + 1)]
    return [("seg", pts[k][0], pts[k][1], pts[k + 1][0], pts[k + 1][1], w) for k in range(n)]


def _rect(x0, y0, x1, y1, w):
    return [("seg", x0, y0, x1, y0, w), ("seg", x1, y0, x1, y1, w), ("seg", x1, y1, x0, y1, w),
            ("seg", x0, y1, x0, y0, w)]


def _tower(x, w0=0.27, w1=0.21, bot=-0.50, top=0.20, hat=0.20):
    """A pictured gate tower: a battered body and a roof with flicked eaves (filled), a short finial."""
    return [("poly", [(x - w0 / 2, bot), (x + w0 / 2, bot), (x + w1 / 2, top), (x - w1 / 2, top)]),
            ("poly", [(x - w1 / 2 - 0.05, top + 0.02), (x + w1 / 2 + 0.05, top + 0.02), (x + w1 / 2 + 0.11, top + 0.10),
                      (x + 0.07, top + 0.08), (x, top + hat), (x - 0.07, top + 0.08), (x - w1 / 2 - 0.11, top + 0.10)]),
            ("seg", x, top + hat, x, top + hat + 0.1, 0.05)]


def _leaf(x0, x1, bot=-0.44, top=0.02, arch=0.16, n=8):
    """A gate leaf pictured as a filled panel with an arched head."""
    cx, r = (x0 + x1) / 2, (x1 - x0) / 2
    pts = [(x0, bot), (x1, bot), (x1, top)]
    for k in range(1, n):
        a = math.pi * k / n
        pts.append((cx + r * math.cos(a), top + arch * math.sin(a)))
    pts.append((x0, top))
    return [("poly", pts)]


def _waves(y, x0, x1, n=6, amp=0.05, w=0.06):
    xs = [x0 + (x1 - x0) * k / n for k in range(n + 1)]
    return [("seg", xs[k], y + (amp if k % 2 else -amp), xs[k + 1], y + (-amp if k % 2 else amp), w) for k in range(n)]


VT_MARKS = {
    # A: the stamp. Square frame, the ring, a pictured gate: two towers with flicked roofs, the arched leaf between
    # them, the water under it as a wave cut. A picture, never a letter or a character.
    "court_gate": (_rect(-0.93, -0.93, 0.93, 0.93, 0.08) + [("ring", 0.0, 0.0, 0.78, 0.07)] + _tower(-0.36) +
                   _tower(0.36) + _leaf(-0.19, 0.19) + _waves(-0.60, -0.50, 0.50)),
    # B: the towers stand through the ring (no frame); the leaf is a pair of half leaves meeting at the centre line.
    "court_gate_b": ([("ring", 0.0, -0.08, 0.70, 0.08)] + _tower(-0.40, 0.30, 0.23, -0.62, 0.36, 0.24) +
                     _tower(0.40, 0.30, 0.23, -0.62, 0.36, 0.24) + _leaf(-0.23, -0.02, -0.50, 0.10, 0.10, 4) +
                     _leaf(0.02, 0.23, -0.50, 0.10, 0.10, 4) + _waves(-0.68, -0.30, 0.30, 4)),
    # C: bold. Big towers, a tall leaf, three falling water cuts under it, in the ring alone.
    "court_gate_c": ([("ring", 0.0, 0.0, 0.82, 0.10)] + _tower(-0.40, 0.32, 0.25, -0.40, 0.28, 0.26) +
                     _tower(0.40, 0.32, 0.25, -0.40, 0.28, 0.26) + _leaf(-0.20, 0.20, -0.36, 0.14, 0.18) +
                     [("seg", -0.15, -0.50, -0.20, -0.68, 0.08), ("seg", 0.0, -0.50, 0.0, -0.72, 0.08),
                      ("seg", 0.15, -0.50, 0.20, -0.68, 0.08)]),
    # The Lantern Ward: a net knot (a diamond of mesh with its crossing cords, the knot held in a small ring).
    "net_knot": ([("seg", -0.80, 0.0, 0.0, 0.80, 0.11), ("seg", 0.0, 0.80, 0.80, 0.0, 0.11),
                  ("seg", 0.80, 0.0, 0.0, -0.80, 0.11), ("seg", 0.0, -0.80, -0.80, 0.0, 0.11),
                  ("seg", -0.40, -0.40, 0.40, 0.40, 0.09), ("seg", -0.40, 0.40, 0.40, -0.40, 0.09),
                  ("ring", 0.0, 0.0, 0.13, 0.08), ("seg", 0.0, -0.80, 0.0, -0.96, 0.09)]),
    # The Grain Piers: a sheaf. Stalks fanning above a tie, a short stubble below.
    "sheaf": ([("seg", 0.0, -0.25, x, 0.85 - abs(x) * 0.25, 0.09) for x in (-0.55, -0.28, 0.0, 0.28, 0.55)] +
              [("seg", -0.36, -0.25, 0.36, -0.25, 0.14)] +
              [("seg", 0.0, -0.25, x, -0.88, 0.09) for x in (-0.32, 0.0, 0.32)]),
    # The Naval Basin: a hull under a mast with two battens of a sail.
    "hull": ([("seg", -0.88, 0.02, -0.56, -0.46, 0.11), ("seg", -0.56, -0.46, 0.56, -0.46, 0.11),
              ("seg", 0.56, -0.46, 0.88, 0.02, 0.11), ("seg", -0.72, -0.12, 0.72, -0.12, 0.09),
              ("seg", 0.0, -0.12, 0.0, 0.88, 0.10), ("seg", 0.0, 0.74, 0.50, 0.62, 0.08),
              ("seg", 0.0, 0.42, 0.56, 0.32, 0.08), ("seg", 0.0, 0.12, 0.60, 0.04, 0.08)]),
    # The Archive Islands: three tablets stacked, each set back from the one below.
    "stacked_tablets": (_rect(-0.72, -0.86, 0.62, -0.36, 0.10) + _rect(-0.56, -0.24, 0.50, 0.22, 0.10) +
                        _rect(-0.40, 0.34, 0.36, 0.78, 0.10)),
    # The Rain Market: an umbrella's ribs from its crown, the canopy's rim and the handle's hook.
    "umbrella_rib": (_arc(0.0, 0.0, 0.86, 0.12, math.pi - 0.12, 8, 0.10) +
                     [("seg", 0.0, 0.0, 0.86 * math.cos(a), 0.86 * math.sin(a), 0.08)
                      for a in (0.12, 0.55, 1.0, 1.5708, 2.14, 2.59, math.pi - 0.12)] +
                     [("seg", 0.0, 0.0, 0.0, -0.74, 0.10)] + _arc(0.16, -0.74, 0.16, math.pi, 2 * math.pi, 4, 0.10)),
}


def register(marks_module):
    marks_module.MARKS.update(VT_MARKS)
    return marks_module
