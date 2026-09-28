"""Batched rotation math and skeleton FK for the Actor_A -> Actor_B retarget prototype.

numpy only. Quaternions are [x, y, z, w] (Godot order). Rotation matrices act on column
vectors. A skeleton pose is (P, R): local positions (F, n, 3) and local rotation matrices
(F, n, 3, 3); FK composes global = parent_global * local, exactly as Skeleton3D does
(bone scale is ignored: every body channel the prototype touches is keyed at scale 1).
"""
import numpy as np


def qnorm(q):
    q = np.asarray(q, float)
    return q / np.linalg.norm(q, axis=-1, keepdims=True)


def q2m(q):
    q = qnorm(q)
    x, y, z, w = q[..., 0], q[..., 1], q[..., 2], q[..., 3]
    m = np.empty(q.shape[:-1] + (3, 3))
    m[..., 0, 0] = 1 - 2 * (y * y + z * z)
    m[..., 0, 1] = 2 * (x * y - z * w)
    m[..., 0, 2] = 2 * (x * z + y * w)
    m[..., 1, 0] = 2 * (x * y + z * w)
    m[..., 1, 1] = 1 - 2 * (x * x + z * z)
    m[..., 1, 2] = 2 * (y * z - x * w)
    m[..., 2, 0] = 2 * (x * z - y * w)
    m[..., 2, 1] = 2 * (y * z + x * w)
    m[..., 2, 2] = 1 - 2 * (x * x + y * y)
    return m


def m2q(m):
    """Rotation matrices (..., 3, 3) -> unit quaternions (..., 4), w >= 0."""
    m = np.asarray(m, float)
    shp = m.shape[:-2]
    a = m.reshape(-1, 3, 3)
    q = np.empty((a.shape[0], 4))
    m00, m11, m22 = a[:, 0, 0], a[:, 1, 1], a[:, 2, 2]
    tr = m00 + m11 + m22
    c0 = tr > 0
    c1 = ~c0 & (m00 > m11) & (m00 > m22)
    c2 = ~c0 & ~c1 & (m11 > m22)
    c3 = ~c0 & ~c1 & ~c2
    with np.errstate(invalid="ignore", divide="ignore"):
        s = np.sqrt(np.maximum(tr + 1.0, 1e-30)) * 2
        q[c0] = np.stack([(a[:, 2, 1] - a[:, 1, 2]) / s, (a[:, 0, 2] - a[:, 2, 0]) / s,
                          (a[:, 1, 0] - a[:, 0, 1]) / s, 0.25 * s], 1)[c0]
        s = np.sqrt(np.maximum(1.0 + m00 - m11 - m22, 1e-30)) * 2
        q[c1] = np.stack([0.25 * s, (a[:, 0, 1] + a[:, 1, 0]) / s, (a[:, 0, 2] + a[:, 2, 0]) / s,
                          (a[:, 2, 1] - a[:, 1, 2]) / s], 1)[c1]
        s = np.sqrt(np.maximum(1.0 + m11 - m00 - m22, 1e-30)) * 2
        q[c2] = np.stack([(a[:, 0, 1] + a[:, 1, 0]) / s, 0.25 * s, (a[:, 1, 2] + a[:, 2, 1]) / s,
                          (a[:, 0, 2] - a[:, 2, 0]) / s], 1)[c2]
        s = np.sqrt(np.maximum(1.0 + m22 - m00 - m11, 1e-30)) * 2
        q[c3] = np.stack([(a[:, 0, 2] + a[:, 2, 0]) / s, (a[:, 1, 2] + a[:, 2, 1]) / s, 0.25 * s,
                          (a[:, 1, 0] - a[:, 0, 1]) / s], 1)[c3]
    q = qnorm(q)
    q[q[:, 3] < 0] *= -1
    return q.reshape(shp + (4,))


def q_continuous(q):
    """Flip signs along axis 0 so consecutive quaternions are in the same hemisphere."""
    q = np.array(q, float)
    for i in range(1, len(q)):
        if np.dot(q[i], q[i - 1]) < 0:
            q[i] = -q[i]
    return q


def axis_angle(axis, ang):
    """Rotation matrices about unit axes (..., 3) by angles (...)."""
    axis = np.asarray(axis, float)
    axis = axis / np.linalg.norm(axis, axis=-1, keepdims=True)
    x, y, z = axis[..., 0], axis[..., 1], axis[..., 2]
    c, s = np.cos(ang), np.sin(ang)
    C = 1 - c
    m = np.empty(axis.shape[:-1] + (3, 3))
    m[..., 0, 0] = c + x * x * C
    m[..., 0, 1] = x * y * C - z * s
    m[..., 0, 2] = x * z * C + y * s
    m[..., 1, 0] = y * x * C + z * s
    m[..., 1, 1] = c + y * y * C
    m[..., 1, 2] = y * z * C - x * s
    m[..., 2, 0] = z * x * C - y * s
    m[..., 2, 1] = z * y * C + x * s
    m[..., 2, 2] = c + z * z * C
    return m


def rot_between(u, v):
    """Minimal rotation matrices taking directions u to v (batched, (..., 3))."""
    u = np.asarray(u, float)
    v = np.asarray(v, float)
    u = u / np.linalg.norm(u, axis=-1, keepdims=True)
    v = v / np.linalg.norm(v, axis=-1, keepdims=True)
    ax = np.cross(u, v)
    s = np.linalg.norm(ax, axis=-1)
    c = np.clip(np.sum(u * v, axis=-1), -1, 1)
    ang = np.arctan2(s, c)
    safe = s > 1e-9
    ax = np.where(safe[..., None], ax / np.where(safe, s, 1)[..., None], np.array([1.0, 0, 0]))
    return axis_angle(ax, np.where(safe, ang, 0.0))


def rot_angle_deg(m):
    """Rotation angle of matrices (..., 3, 3) in degrees."""
    tr = np.trace(m, axis1=-2, axis2=-1)
    return np.degrees(np.arccos(np.clip((tr - 1) / 2, -1, 1)))


class Rig:
    """Skeleton topology + a rest pose. `bind` overrides rest channels (bone -> {pos, rot})."""

    def __init__(self, bones, bind=None):
        self.names = [b["name"] for b in bones]
        self.idx = {n: i for i, n in enumerate(self.names)}
        self.parent = np.array([b["parent"] for b in bones])
        self.rest_pos = np.array([b["pos"] for b in bones], float)
        self.rest_q = np.array([b["rot"] for b in bones], float)
        self.bind_source = {}
        if bind:
            for bn, ch in bind.items():
                i = self.idx.get(bn)
                if i is None:
                    continue
                if "pos" in ch:
                    self.rest_pos[i] = ch["pos"]
                if "rot" in ch:
                    self.rest_q[i] = ch["rot"]
        self.rest_R = q2m(self.rest_q)
        order, seen = [], set()

        def visit(i):
            if i in seen:
                return
            if self.parent[i] >= 0:
                visit(self.parent[i])
            seen.add(i)
            order.append(i)

        for i in range(len(self.names)):
            visit(i)
        self.order = order
        self.children = {i: [] for i in range(len(self.names))}
        for i, p in enumerate(self.parent):
            if p >= 0:
                self.children[int(p)].append(i)

    def n(self):
        return len(self.names)

    def is_descendant(self, i, anc):
        while i >= 0:
            if i == anc:
                return True
            i = self.parent[i]
        return False

    def local_arrays(self, tracks, F):
        """Rest-filled local pose (P (F,n,3), R (F,n,3,3)) from dumped clip tracks."""
        P = np.repeat(self.rest_pos[None], F, 0)
        Q = np.repeat(self.rest_q[None], F, 0)
        for bn, ch in tracks.items():
            i = self.idx.get(bn)
            if i is None:
                continue
            if "pos" in ch:
                P[:, i] = np.asarray(ch["pos"], float)[:F]
            if "rot" in ch:
                Q[:, i] = np.asarray(ch["rot"], float)[:F]
        return P, q2m(Q)

    def fk(self, P, R):
        """World positions (F,n,3) and rotations (F,n,3,3)."""
        F, n = P.shape[:2]
        GP = np.zeros((F, n, 3))
        GR = np.zeros((F, n, 3, 3))
        for i in self.order:
            p = self.parent[i]
            if p < 0:
                GR[:, i] = R[:, i]
                GP[:, i] = P[:, i]
            else:
                GR[:, i] = GR[:, p] @ R[:, i]
                GP[:, i] = GP[:, p] + np.einsum("fij,fj->fi", GR[:, p], P[:, i])
        return GP, GR

    def bind_fk(self):
        P = self.rest_pos[None]
        R = self.rest_R[None]
        GP, GR = self.fk(P, R)
        return GP[0], GR[0]
