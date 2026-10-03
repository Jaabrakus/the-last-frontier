"""cloth2 feet: covers grown round the lower leg and the foot in every fit (2026-10-02): stockings, moccasins, shoes.

The covered cloth surface stops at the ankles (cloth2.fit COVERED: feet have their own parts), so legwear that reaches
the foot and footwear are grown from the body's own leg and foot instead:

  tube = SockTube(fits, side, top=0.56)      # rings along the leg's joint line (from `top` down), bent at the heel into
                                             #   the foot and closed over the toes (a stocking's shape: the seam at the
                                             #   back of the leg and under the sole, psi = 180 degrees)
  m = tube.mesh(ease)                        # each ring vertex the OUTERMOST point `ease` (m; a number or a function of
                                             #   (u, psi)) off the skin along its ray, traced from outside in every fit
                                             #   (the same rays, so the same topology): it bridges the toes and the hollow
                                             #   behind the knee the way knit or leather does
  m = both(fits, lambda s: SockTube(...).mesh(...))   # the two sides as one Mesh

Per-vertex attributes besides the body weights "W" (nearest skin point): "u" (0 at the tube's top .. 1 at the toe
apex), "ray_x/y/z" (the ray each vertex was traced along: a sole is where it points down), "foot" (0 on the leg,
1 on the foot: the part past the heel bend), "toe" (1 over the toes), and the cloth2 limb attributes (m_leg_*, t_leg_*), so Garment.zone and
the trims work on it like on a shell.

  sole(m, ...)                               # a shoe's flat sole and heel block (the vertices whose rays point down)
"""

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import regions as RG
from cloth2.fit import chain_param
from cloth2.mesh import REF, Mesh, concat, smoothstep, unit, vertex_normals

LEG_REGIONS = ("thigh_upper", "thigh_lower", "shin_upper", "shin_lower", "ankle", "foot")
R_START = 0.14            # rays start this far out from the tube's axis (and further while still inside)
TRACE_TOL = 0.00015
LIMBS = ("arm_l", "arm_r", "leg_l", "leg_r")


def _bvh(V, F):
    return BVHTree.FromPolygons([tuple(p) for p in V], [tuple(t) for t in F], all_triangles=True)


class Leg:
    """One side's leg and foot in every fit: distance queries (signed by the skin normal) and nearest-point weights."""

    def __init__(self, fits, side, regions=LEG_REGIONS):
        self.fits, self.side = fits, side
        self.sg = 1.0 if side == "l" else -1.0
        ids = [RG.REGIONS["%s_%s" % (r, side)] for r in regions]
        self.faces = np.nonzero(np.isin(fits.freg, ids))[0]
        F = fits.F[self.faces]
        self.bvh = {k: _bvh(V, F) for k, V in fits.V.items()}

    def signed(self, fit, p):
        loc, nrm, idx, d = self.bvh[fit].find_nearest(Vector(p))
        if loc is None:
            return 1.0
        return d if (np.asarray(p) - np.array(loc)) @ np.array(nrm) >= 0.0 else -d

    def trace(self, fit, O, d, ease, r0=R_START):
        """The outermost point `ease` off the skin on the ray O + t d (t in [0, r]), traced from outside inward (sphere
        tracing on the unsigned distance never steps through the offset surface)."""
        bv = self.bvh[fit]
        r = r0
        S = O + d * r
        while self.signed(fit, S) < ease + 0.001 and r < 0.40:
            r += 0.04
            S = O + d * r
        p = S
        t = r
        for _ in range(80):
            loc, _, _, dist = bv.find_nearest(Vector(p))
            if loc is None:
                break
            step = dist - ease
            if step < TRACE_TOL:
                break
            t -= step
            if t <= 0.0:
                t = 0.0
                break
            p = O + d * t
        return O + d * t

    def weights_at(self, P):
        """Body weights (and region of the nearest face) at the skin points nearest P (reference fit)."""
        fits = self.fits
        bv = self.bvh[REF]
        V = fits.V[REF]
        W = np.zeros((len(P), fits.W.shape[1]))
        reg = np.zeros(len(P), int)
        F = fits.F[self.faces]
        for i, p in enumerate(P):
            loc, _, idx, _ = bv.find_nearest(Vector(p))
            t = F[idx]
            b = _bary(np.array(loc), V[t[0]], V[t[1]], V[t[2]])
            W[i] = b @ fits.W[t]
            reg[i] = fits.freg[self.faces[idx]]
        return W, reg


def _bary(p, a, b, c):
    v0, v1, v2 = b - a, c - a, p - a
    d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
    d20, d21 = v2 @ v0, v2 @ v1
    den = d00 * d11 - d01 * d01
    if abs(den) < 1e-18:
        return np.array([1.0, 0.0, 0.0])
    v = (d11 * d20 - d01 * d21) / den
    w = (d00 * d21 - d01 * d20) / den
    u = np.clip(np.array([1.0 - v - w, v, w]), 0.0, 1.0)
    return u / u.sum()


def _resample(P, step):
    seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
    L = np.concatenate([[0.0], np.cumsum(seg)])
    n = max(int(np.ceil(L[-1] / step)) + 1, 2)
    s = np.linspace(0.0, L[-1], n)
    return np.stack([np.interp(s, L, P[:, k]) for k in range(3)], 1), s / L[-1]


def _catmull(P, per=8):
    """A smooth curve through the control points (centripetal enough for a few well spread points)."""
    P = np.asarray(P, float)
    Q = np.concatenate([[2 * P[0] - P[1]], P, [2 * P[-1] - P[-2]]])
    out = []
    for i in range(1, len(Q) - 2):
        p0, p1, p2, p3 = Q[i - 1], Q[i], Q[i + 1], Q[i + 2]
        for t in np.linspace(0.0, 1.0, per, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-1])
    return np.array(out)


class SockTube:
    """A tube along one leg from height `top` down the joint line, bent at the heel into the foot and closed over the
    toes. `step_leg` / `step_foot`: ring spacing (m) on the leg / past the ankle; `segs` vertices round each ring;
    `cap` rings over the toes (the last one an apex)."""

    def __init__(self, fits, side, top=0.56, segs=16, step_leg=0.022, step_foot=0.0095, cap=4, leg=None):
        self.fits, self.side = fits, side
        sg = 1.0 if side == "l" else -1.0
        self.sg = sg
        self.leg = leg or Leg(fits, side)
        J = fits.J
        U, K, A, B = J[side + "_upper_leg"], J[side + "_knee"], J[side + "_ankle"], J[side + "_ball"]
        c_ank = A + np.array([sg * 0.005, -0.008, 0.045])
        # the leg's line: through the middle of each cross-section of the leg (not the joint line, which runs
        # near the shin: rays from it would be sparse over the calf), from `top` down to the ankle
        Vb = fits.V[REF]
        vids = np.unique(fits.F[self.leg.faces])
        vids = vids[(sg * Vb[vids, 0]) > 0.0]
        zs = np.arange(top, c_ank[2] + 0.02, -0.02)
        leg_pts = []
        for z in zs:
            near = vids[np.abs(Vb[vids, 2] - z) < 0.012]
            if len(near) > 8:
                q = Vb[near]
                leg_pts.append(np.array([0.5 * (q[:, 0].min() + q[:, 0].max()), 0.5 * (q[:, 1].min() + q[:, 1].max()), z]))
        leg_pts = np.array(leg_pts)
        if len(leg_pts) > 4:
            sm = leg_pts.copy()
            for _ in range(3):
                sm[1:-1, :2] = 0.25 * sm[:-2, :2] + 0.5 * sm[1:-1, :2] + 0.25 * sm[2:, :2]
            leg_pts = sm
        # into the ankle's centre smoothly
        leg_line = np.concatenate([leg_pts, [c_ank]]) if len(leg_pts) else np.array([c_ank + [0, 0, top - c_ank[2]], c_ank])
        foot_ctrl = np.array([c_ank,
                              A + np.array([sg * 0.005, -0.010, 0.000]),
                              A + np.array([sg * 0.004, -0.028, -0.030]),
                              np.array([A[0] + sg * 0.003, B[1] + 0.045, 0.036]),
                              np.array([B[0], B[1] + 0.008, B[2] + 0.010]),
                              np.array([B[0] - sg * 0.003, B[1] - 0.028, B[2] + 0.003]),
                              np.array([B[0] - sg * 0.005, B[1] - 0.045, B[2] + 0.001])])
        P1, _ = _resample(leg_line, step_leg)
        foot_curve = _catmull(foot_ctrl, 10)
        P2, _ = _resample(foot_curve, step_foot)
        path = np.concatenate([P1[:-1], P2])
        self.n_leg = len(P1) - 1
        # tangents and frames: e1 across (x), e2 = the front of the leg / the top of the foot
        T = unit(np.gradient(path, axis=0))
        ex = np.array([1.0, 0.0, 0.0])
        e1 = unit(ex[None] - (T @ ex)[:, None] * T)
        e2 = unit(np.cross(T, e1))
        e1 = e1 * sg                                        # psi grows toward the outside of each leg (mirror images)
        self.path, self.T, self.e1, self.e2 = path, T, e1, e2
        self.segs, self.cap = segs, cap
        L = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])
        self.s = L                                          # arc length from the top
        self.foot_from = L[self.n_leg]

    def rays(self):
        """(origins (n, 3), directions (n, 3), u (n,), psi (n,), foot (n,)) of every ring vertex, then the cap rings
        and the toe apex; self.toe (n,): 1 over the toes (the last 5 cm of the path) .. 0 from 10 cm back."""
        segs = self.segs
        psi = 2 * np.pi * np.arange(segs) / segs
        O, D, U, S, Ft, Te = [], [], [], [], [], []
        L = self.s
        total = L[-1] + 0.03
        for i, p in enumerate(self.path):
            d = np.cos(psi)[:, None] * self.e2[i] + np.sin(psi)[:, None] * self.e1[i]
            O.append(np.repeat(p[None], segs, 0))
            D.append(d)
            U.append(np.full(segs, L[i] / total))
            S.append(psi)
            Ft.append(np.full(segs, 1.0 if L[i] >= self.foot_from else 0.0))
            Te.append(np.full(segs, float(smoothstep(0.10, 0.05, L[-1] - L[i]))))
        p, T, e1, e2 = self.path[-1], self.T[-1], self.e1[-1], self.e2[-1]
        for k in range(1, self.cap):
            ph = 0.5 * np.pi * k / self.cap
            r = np.cos(psi)[:, None] * e2 + np.sin(psi)[:, None] * e1
            d = unit(np.cos(ph) * r + np.sin(ph) * T[None])
            O.append(np.repeat(p[None], segs, 0))
            D.append(d)
            U.append(np.full(segs, (L[-1] + 0.03 * k / self.cap) / total))
            S.append(psi)
            Ft.append(np.ones(segs))
            Te.append(np.ones(segs))
        O.append(p[None])
        D.append(T[None])
        U.append(np.ones(1))
        S.append(np.zeros(1))
        Ft.append(np.ones(1))
        Te.append(np.ones(1))
        self.toe = np.concatenate(Te)
        return (np.concatenate(O), np.concatenate(D), np.concatenate(U), np.concatenate(S), np.concatenate(Ft))

    def faces(self):
        segs = self.segs
        nr = len(self.path) + self.cap - 1
        F = []
        for i in range(nr - 1):
            for j in range(segs):
                a, b = i * segs + j, i * segs + (j + 1) % segs
                c, d = (i + 1) * segs + (j + 1) % segs, (i + 1) * segs + j
                F += [(a, b, c), (a, c, d)]
        apex = nr * segs
        last = (nr - 1) * segs
        for j in range(segs):
            F.append((last + j, last + (j + 1) % segs, apex))
        return np.array(F, int)

    def mesh(self, ease, smooth=2, foot_smooth=0, gap=None, bridge=0.010, leg_gap=0.0015):
        """The tube `ease` off the skin (m; or a function ease(u, psi, foot) per vertex), in every fit. On the foot the
        rays are traced to the `bridge` offset (a smooth envelope over the toes: an offset surface rounds what is
        smaller than its distance) and drawn back along the ray to the ease. The distances along the rays are then
        smoothed over the mesh (`smooth` rounds everywhere, `foot_smooth` more toward the toes: a toe box, not a
        glove for each toe), never below the outermost point `gap` off the skin (default 0.6 x the ease, at most
        2.4 mm): every vertex stays on its own ray, so nothing folds. Last, the leg's part (above the heel bend,
        where the skin is smooth) is pushed clear by leg_gap between its vertices too (face centres, edge midpoints:
        a calf bulges past the chords of a coarse ring)."""
        O, D, U, S, Ft = self.rays()
        n = len(O)
        E = np.asarray(ease(U, S, Ft) if callable(ease) else np.full(n, float(ease)), float)
        Et = E + (np.maximum(E, bridge) - E) * Ft if bridge else E
        gp = np.minimum(E, 0.004) * 0.6 if gap is None else np.broadcast_to(np.asarray(gap, float), (n,))
        F = self.faces()
        Eadj = np.unique(np.sort(np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]]), 1), axis=0)
        Eadj = np.concatenate([Eadj, Eadj[:, ::-1]])
        wf = Ft * (0.2 + 0.8 * self.toe)
        V = {}
        for k in self.fits.V:
            t = np.array([float((self.leg.trace(k, O[i], D[i], Et[i]) - O[i]) @ D[i]) for i in range(n)]) - (Et - E)
            tmin = np.array([float((self.leg.trace(k, O[i], D[i], gp[i]) - O[i]) @ D[i]) for i in range(n)])
            t = np.maximum(t, tmin)
            for it in range(smooth + foot_smooth):
                acc = np.zeros(n)
                cnt = np.zeros(n)
                np.add.at(acc, Eadj[:, 0], t[Eadj[:, 1]])
                np.add.at(cnt, Eadj[:, 0], 1.0)
                lam = 0.4 if it < smooth else 0.5 * wf
                t = np.maximum(t + lam * (acc / np.maximum(cnt, 1.0) - t), tmin)
            V[k] = O + D * t[:, None]
        P = V[REF]
        fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
        # outward: away from the ray origins
        Oc = O[F].mean(1)
        if ((fn * (P[F].mean(1) - Oc)).sum(1) < 0).mean() > 0.5:
            F = F[:, ::-1].copy()
        W, reg_v = self.leg.weights_at(P)
        A = {"W": W, "u": U, "ray_x": D[:, 0], "ray_y": D[:, 1], "ray_z": D[:, 2], "foot": Ft, "toe": self.toe}
        lim = "leg_" + self.side
        for name in LIMBS:
            A["m_" + name] = np.ones(len(P)) if name == lim else np.zeros(len(P))
            A["t_" + name] = chain_param(P, self.fits.leg(self.side))[0] if name == lim else np.zeros(len(P))
        nf = len(F)
        reg_f = reg_v[F][:, 0]
        m = Mesh.__new__(Mesh)
        m.V = V
        m.F = F
        m.N = {k: vertex_normals(v, F) for k, v in V.items()}
        m.A = A
        m.fa = {"region": reg_f, "zone": np.zeros(nf, int), "part": np.zeros(nf, int)}
        if leg_gap:
            self.fits.clear(m, np.where(Ft > 0.5, -1.0, leg_gap))
        return m


def both(fits, make):
    """The left and right covers (make(side) -> Mesh) as one Mesh."""
    return concat([make("l"), make("r")])


def ray_down(m):
    """Per vertex how much its ray points down (0 sideways or up .. 1 straight down)."""
    rz = m.A["ray_z"] / np.maximum(np.sqrt(m.A["ray_x"] ** 2 + m.A["ray_y"] ** 2 + m.A["ray_z"] ** 2), 1e-9)
    return np.clip(-rz, 0.0, 1.0)


def sole(m, fits, ball_z=-0.003, heel_z=-0.016, heel_from=0.035, toe_rise=0.006, edge=0.0025, sides=("l", "r")):
    """A shoe's sole: the vertices whose rays point down are pressed onto a flat sole (ball_z under the forefoot,
    the toe rising by toe_rise to the tip) and, behind y = ankle + heel_from... a heel block down to heel_z; the
    sole's edge stands `edge` proud of the upper (a welt). In every fit (the same heights: a sole does not grow)."""
    J = fits.J
    w = smoothstep(0.30, 0.80, ray_down(m)) * m.A["foot"]
    P0 = m.V[REF]
    for k in m.V:
        P = m.V[k]
        Q = P.copy()
        for s in sides:
            sg = 1.0 if s == "l" else -1.0
            side = (sg * P0[:, 0]) > 0.0
            A, B = J[s + "_ankle"], J[s + "_ball"]
            y = P0[:, 1]
            heel = smoothstep(A[1] - heel_from - 0.012, A[1] - heel_from + 0.004, y)
            toe = smoothstep(B[1] - 0.01, B[1] - 0.075, y)
            z = ball_z + toe_rise * toe
            z = z + (heel_z - z) * heel
            sel = side & (w > 0.0)
            Q[sel, 2] = P[sel, 2] + (z[sel] - P[sel, 2]) * w[sel]
        # the welt: the sole's rim a little wider than the upper
        rim = np.exp(-((w - 0.5) / 0.25) ** 2) * (w > 0.05)
        nh = m.N[k].copy()
        nh[:, 2] = 0.0
        Q = Q + unit(nh) * (edge * rim)[:, None]
        m.V[k] = Q
    m.recompute_normals()
    return m
