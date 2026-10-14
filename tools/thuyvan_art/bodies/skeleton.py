"""Actor_B joints at the bind pose null-add without Blender, and the body kits' extension bones.

Plain numpy (no bpy), so the kit shapes can be drafted and checked outside the shared Blender lock. Inside Blender
the builders use lib.context.BuildContext (the rig COPY's null-add); `Joints` takes either source:

    J = Joints.from_json()             # tools/character/rig/actor_b_skeleton.json (the same bones, order and bind)
    J = Joints.from_globals(ctx.G)     # BuildContext globals (mathutils matrices)

Spaces follow tools/character/lib/README.md: Blender armature space, z up, the character faces -y; Godot skeleton
space is (x, z, -y). Extension bone tables are written in Godot space (as the design brief gives them) and converted
with g2b.
"""

import json
import math
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
CHARACTER_TOOLS = os.path.join(FRONTIER, "tools", "character")
SKELETON_JSON = os.path.join(CHARACTER_TOOLS, "rig", "actor_b_skeleton.json")

# Godot (Y up) -> Blender (Z up), as tools/character/rig/make_rig_blend.py C_INV
C_INV = np.array([[1, 0, 0, 0], [0, 0, -1, 0], [0, 1, 0, 0], [0, 0, 0, 1]], float)


def g2b(p):
    """Godot skeleton space (x, y up, z forward) -> Blender armature space (z up, facing -y)."""
    return np.array([p[0], -p[2], p[1]], float)


def b2g(p):
    return np.array([p[0], p[2], -p[1]], float)


class Joints:
    """Bone globals (4x4 numpy, Blender space, orthonormal) at null-add, in rig order, with parents."""

    def __init__(self, G, parents, order):
        self.G = G
        self.parent = parents
        self.order = order
        self.P = {n: G[n][:3, 3].copy() for n in order}

    def __getitem__(self, name):
        return self.P[name]

    def side(self, name, s):
        p = self.P["l_" + name]
        return p if s > 0 else p * np.array([-1.0, 1, 1])

    @staticmethod
    def from_json(path=SKELETON_JSON):
        rec = json.load(open(path))
        G, parents, order = {}, {}, []
        for b in rec["bones"]:
            r = b["rest"]
            m = np.array([r[0:4], r[4:8], r[8:12], [0, 0, 0, 1]], float)
            G[b["name"]] = C_INV @ m
            parents[b["name"]] = b["parent"]
            order.append(b["name"])
        return Joints(G, parents, order)

    @staticmethod
    def from_rig(rig, G):
        order = [b.name for b in rig.data.bones]
        parents = {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones}
        Gn = {n: np.array(G[n], float) for n in order}
        return Joints(Gn, parents, order)


# ===========================================================================
# Extension bones (design brief tables; Godot space, female base, stature 1.0, +Z forward)
# ===========================================================================
FLOODBORN_TAIL = [  # name, parent, head (godot), length
    ("tail_01", "pelvis", (0, 0.900, -0.110), 0.24),
    ("tail_02", "tail_01", (0, 0.746, -0.294), 0.22),
    ("tail_03", "tail_02", (0, 0.604, -0.462), 0.20),
    ("tail_04", "tail_03", (0, 0.476, -0.616), 0.19),
    ("tail_05", "tail_04", (0, 0.427, -0.799), 0.17),
    ("tail_06", "tail_05", (0, 0.383, -0.963), 0.16),
    ("tail_07", "tail_06", (0, 0.341, -1.118), 0.14),
    ("tail_08", "tail_07", (0, 0.305, -1.253), 0.13),
]
FLOODBORN_TAIL_TIP = (0, 0.271, -1.379)
FLOODBORN_MARKERS = [  # rigid, non-deforming markers
    ("snout_tip", "headb", (0, 1.48, 0.42), 0.0),
    ("jaw_tip", "jaw", (0, 1.42, 0.40), 0.0),
]


def floodborn_bones(tail_scale=1.0, snout_tip=None, jaw_tip=None):
    """[(name, parent, head (Blender), tail (Blender), deform)] in table order. tail_scale scales the chain about
    tail_01's head (variant B's 1.35 m and C's 1.10 m tails are A's chain scaled)."""
    root = g2b(FLOODBORN_TAIL[0][2])
    heads = [g2b(h) for _, _, h, _ in FLOODBORN_TAIL] + [g2b(FLOODBORN_TAIL_TIP)]
    heads = [root + (h - root) * tail_scale for h in heads]
    out = []
    for i, (n, par, _, _) in enumerate(FLOODBORN_TAIL):
        out.append((n, par, heads[i], heads[i + 1], True))
    st = g2b(snout_tip if snout_tip is not None else FLOODBORN_MARKERS[0][2])
    jt = g2b(jaw_tip if jaw_tip is not None else FLOODBORN_MARKERS[1][2])
    out.append(("snout_tip", "headb", st, st + np.array([0, -0.03, 0]), False))
    out.append(("jaw_tip", "jaw", jt, jt + np.array([0, -0.03, 0]), False))
    return out


def moc_tinh_bones(crown_lengths=((0.12, 0.10),) * 6, crown_fan=(25, 155), crown_tilt_deg=35.0):
    """Crown fan (6 branches of 2 bones round the top of the head) and the four hanging vines."""
    out = []
    cr = g2b((0, 1.60, -0.01))
    out.append(("crown_root", "headb", cr, cr + np.array([0, 0, 0.04]), True))
    c0 = cr + np.array([0, 0, 0.04])
    angs = np.linspace(math.radians(crown_fan[0]), math.radians(crown_fan[1]), 6)
    # the fan runs round the top: branch k leaves at angle a in the x-z plane (0 = +x side, 90 = up), tilted back
    for k, a in enumerate(angs):
        d = np.array([math.cos(a), 0.0, math.sin(a)])
        # alternate front / back so the six do not stand in one plane
        yb = (0.35 if k % 2 else -0.25) * math.sin(a)
        d = d + np.array([0, yb, 0])
        d = d / np.linalg.norm(d)
        h1 = c0 + d * 0.03
        l1, l2 = crown_lengths[k]
        t1 = h1 + d * l1
        d2 = d + np.array([0, 0, 0.35])
        d2 = d2 / np.linalg.norm(d2)
        t2 = t1 + d2 * l2
        out.append(("crown_%d_01" % (k + 1), "crown_root", h1, t1, True))
        out.append(("crown_%d_02" % (k + 1), "crown_%d_01" % (k + 1), t1, t2, True))
    vines = [("vine_1", "l_clavicle", (0.12, 1.30, 0.04), 0.13), ("vine_2", "r_clavicle", (-0.12, 1.30, 0.04), 0.13),
             ("vine_3", "pelvis", (0.10, 0.92, 0.08), 0.12), ("vine_4", "spined", (0.0, 1.22, -0.10), 0.14)]
    for name, par, h, L in vines:
        p = g2b(h)
        prev = par
        for i in range(4):
            q = p + np.array([0, 0, -L])
            n = "%s_%02d" % (name, i + 1)
            out.append((n, prev, p, q, True))
            prev, p = n, q
    return out
