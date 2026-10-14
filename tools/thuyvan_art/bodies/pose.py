"""Poses for the grey-box review (plain numpy; the Blender build applies the same globals to the bind rig).

The rest is null-add. A pose is {bone: rotation} with each rotation given about world axes AS SEEN AT REST and applied
about the bone's head (so "+x 20 deg" on a spine bone leans it forward whatever the bone's own axes are), plus
`world_dirs` for the extension chains (tail, crown, vines): the pose-layer TARGET direction of each bone in world space,
the runtime's per-state target that the springs then move around.

    Jk = extend(J, kit_bones)               # Actor_B joints + the kit's extension bones (table order)
    Gp = fk(Jk, pose["rot"], pose["dirs"])  # posed globals (4x4, Blender armature space)
    Vp = lbs(V, W, bones, Jk, Gp)
"""

import math

import numpy as np

from skeleton import Joints


def rot(axis, deg):
    a = np.asarray(axis, float)
    a = a / np.linalg.norm(a)
    t = math.radians(deg)
    K = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + math.sin(t) * K + (1 - math.cos(t)) * K @ K


def compose(*Rs):
    out = np.eye(3)
    for R in Rs:
        out = R @ out
    return out


def align(u, v):
    """Smallest rotation taking direction u to direction v."""
    u = u / np.linalg.norm(u)
    v = v / np.linalg.norm(v)
    c = float(u @ v)
    ax = np.cross(u, v)
    s = np.linalg.norm(ax)
    if s < 1e-9:
        return np.eye(3) if c > 0 else rot(np.cross(u, [1, 0, 0]) if abs(u[0]) < 0.9 else np.cross(u, [0, 1, 0]), 180)
    return rot(ax, math.degrees(math.atan2(s, c)))


def bone_frame(head, tail, up=(0, 0, 1)):
    """Blender bone convention: y along the bone; z toward `up`."""
    y = np.asarray(tail, float) - np.asarray(head, float)
    L = np.linalg.norm(y)
    y = y / L if L > 1e-9 else np.array([0, -1.0, 0])
    z = np.asarray(up, float) - y * (np.asarray(up, float) @ y)
    if np.linalg.norm(z) < 1e-6:
        z = np.array([0, 1.0, 0]) - y * y[1]
    z = z / np.linalg.norm(z)
    x = np.cross(y, z)
    M = np.eye(4)
    M[:3, 0], M[:3, 1], M[:3, 2], M[:3, 3] = x, y, z, head
    return M


def extend(J, kit_bones):
    G = dict(J.G)
    parents = dict(J.parent)
    order = list(J.order)
    for name, par, head, tail, deform in kit_bones:
        G[name] = bone_frame(head, tail, up=(0, 1, 0) if abs((np.asarray(tail) - np.asarray(head))[2]) > 0.7 *
                             max(np.linalg.norm(np.asarray(tail) - np.asarray(head)), 1e-9) else (0, 0, 1))
        parents[name] = par
        order.append(name)
    Jk = Joints(G, parents, order)
    Jk.tails = {n: np.asarray(t, float) for n, p, h, t, d in kit_bones}
    Jk.kit = [b[0] for b in kit_bones]
    Jk.deform_kit = [b[0] for b in kit_bones if b[4]]
    return Jk


def fk(J, rots=None, dirs=None):
    rots = rots or {}
    dirs = dirs or {}
    Gp = {}
    inv = {}
    for n in J.order:
        Gr = J.G[n]
        M = Gr.copy()
        p = J.parent.get(n)
        if p is not None:
            if p not in inv:
                inv[p] = np.linalg.inv(J.G[p])
            base = Gp[p] @ inv[p] @ Gr
        else:
            base = Gr.copy()
        if n in dirs:
            tail = J.tails[n] if hasattr(J, "tails") and n in J.tails else None
            rest_dir = (tail - Gr[:3, 3]) if tail is not None else Gr[:3, 1]
            cur_dir = base[:3, :3] @ (Gr[:3, :3].T @ rest_dir)
            R = align(cur_dir, np.asarray(dirs[n], float))
            M = base.copy()
            M[:3, :3] = R @ base[:3, :3]
        else:
            R = rots.get(n)
            M = base.copy()
            if R is not None:
                # rotate about the bone's head by R in the posed parent's world frame (= the rest axes for an
                # unposed parent)
                if p is not None:
                    Rp = (Gp[p] @ inv[p])[:3, :3]
                    R = Rp @ R @ Rp.T
                M[:3, :3] = R @ base[:3, :3]
        Gp[n] = M
    return Gp


def lbs(V, W, bones, J, Gp):
    out = np.zeros_like(V)
    Vh = np.c_[V, np.ones(len(V))]
    for j, b in enumerate(bones):
        w = W[:, j]
        m = w > 0
        if not m.any() or b not in Gp:
            continue
        S = Gp[b] @ np.linalg.inv(J.G[b])
        out[m] += w[m, None] * (Vh[m] @ S.T)[:, :3]
    tot = W.sum(1)
    out[tot < 1e-9] = V[tot < 1e-9]
    return out


# ===========================================================================
# Poses
# ===========================================================================
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def _arms_down(R, deg=22):
    R["l_shoulder"] = rot(Y, deg)
    R["r_shoulder"] = rot(Y, -deg)


def _curl(R, side, deg, thumb=30):
    s = 1 if side == "l" else -1
    for f in ("index", "middle", "ring"):
        for k, n in enumerate(("a", "b", "c")):
            R["%s_%s%s" % (side, f, n)] = rot((0, s * 1, 0.0), deg * (0.8 if k == 0 else 1.0))
    for k, n in enumerate(("b", "c", "d")):
        R["%s_pinky%s" % (side, n)] = rot((0, s * 1, 0.0), deg * (0.8 if k == 0 else 1.0))
    R["%s_thumbb" % side] = rot((0, 0, s), thumb)


def tail_dirs(pitches, yaws, n=8):
    """World directions for tail_01..tail_08: pitch below horizontal (deg), yaw toward +x (deg); the character
    faces -y, so 'back' is +y."""
    out = {}
    for i in range(n):
        p, yw = math.radians(pitches[i]), math.radians(yaws[i])
        out["tail_%02d" % (i + 1)] = np.array([math.sin(yw) * math.cos(p), math.cos(yw) * math.cos(p), -math.sin(p)])
    return out


TAIL_IDLE = {   # pose-layer targets per variant (design 3.7 idle; B carries it, C carries it low)
    "A": tail_dirs([52, 50, 44, 30, 6, 0, -2, -3], [0, 0, 3, 7, 11, 14, 16, 18]),
    "B": tail_dirs([34, 26, 16, 8, 2, -2, -5, -8], [0, 0, 1, 2, 3, 4, 5, 6]),
    "C": tail_dirs([50, 46, 38, 26, 12, 4, 0, 0], [0, 2, 5, 9, 13, 16, 18, 20]),
}

POSTURE = {   # the runtime posture overlay (design 3.6): spine lean, neck and head counter, clavicles, arms
    "A": (8, -5, -3, 3, 4), "B": (16, -9, -5, 3, 4), "C": (12, -4, -2, 4, 5),
}


def posture(R, var):
    lean, neck, head, clav, arm = POSTURE[var]
    for b in ("spinea", "spineb", "spinec", "spined"):
        R[b] = rot(X, lean / 4.0)
    R["neck"] = rot(X, neck)
    R["heada"] = rot(X, head)
    R["l_clavicle"] = rot(X, clav)
    R["r_clavicle"] = rot(X, clav)
    return arm


def floodborn_rest(var):
    return {"rot": {}, "dirs": dict(TAIL_IDLE[var])}


def floodborn_spear(var):
    """Spear stance, as on the Floodborn sheet: the spear upright in the right hand beside the body, the left arm
    hanging heavy, feet planted wide, with the posture overlay and the idle tail curled to the free side."""
    R = {}
    abd = posture(R, var)
    R["l_shoulder"] = compose(rot(Y, 18 - abd), rot(X, -6))
    R["l_elbow"] = rot(X, -18)
    _curl(R, "l", 35)
    # right arm: upper arm down and a little forward, forearm raised to grip the shaft
    R["r_shoulder"] = compose(rot(Y, -16), rot(X, -10))
    R["r_elbow"] = compose(rot(X, -78), rot(Z, 10))
    R["r_wrist"] = rot(Y, 10)
    _curl(R, "r", 80, thumb=45)
    R["l_upper_leg"] = rot(Y, 6)
    R["r_upper_leg"] = rot(Y, -6)
    R["l_ankle"] = rot(Y, -6)
    R["r_ankle"] = rot(Y, 6)
    R["l_knee"] = rot(X, 4)
    R["r_knee"] = rot(X, 4)
    dirs = tail_dirs([52, 48, 40, 26, 5, 0, -2, -3], [0, -4, -10, -18, -26, -32, -36, -38])
    return {"rot": R, "dirs": dirs, "prop": ("spear", "r")}


def moc_rest(var):
    return {"rot": {}, "dirs": {}}


def moc_staff(var):
    """Walking-staff stance, as on the Mộc Tinh sheet: the staff planted in the left hand, the right arm hanging,
    the head tilted down, the weight on one leg; a slight droop."""
    R = {}
    for b in ("spinea", "spineb", "spinec", "spined"):
        R[b] = rot(X, 1.5)
    R["spinea"] = compose(rot(X, 1.5), rot(Y, 3))
    R["neck"] = compose(rot(X, 3), rot(Y, -4))
    R["heada"] = compose(rot(X, 3), rot(Z, 10))
    R["r_shoulder"] = compose(rot(Y, -20), rot(X, 4))
    R["r_elbow"] = rot(X, -12)
    _curl(R, "r", 25)
    R["l_shoulder"] = compose(rot(Y, 8), rot(X, -24))
    R["l_elbow"] = compose(rot(X, -70), rot(Z, -8))
    R["l_wrist"] = rot(Y, -8)
    _curl(R, "l", 80, thumb=45)
    R["pelvis"] = rot(Y, -3)
    R["l_upper_leg"] = compose(rot(Y, 3), rot(X, -6))
    R["r_upper_leg"] = compose(rot(Y, -1), rot(X, 4))
    R["l_knee"] = rot(X, 10)
    R["l_ankle"] = rot(X, -4)
    return {"rot": R, "dirs": {}, "prop": ("staff", "l")}
