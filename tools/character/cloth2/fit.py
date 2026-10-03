"""cloth2 fits: the body in each of its fits, the cloth surface grown from it, and the clearance solver.

  fits = Fits(ctx)
  m = fits.surface("cloth")              # the whole covered body as a Mesh: neck, torso, arms to the wrists, legs
                                         #   to the ankles, ~7k triangles (a decimated copy of the body, each vertex
                                         #   bound to the full body by triangle + barycentrics + offset)
  m = fits.surface("skin")               # the same on the skin itself (stockings, leggings, tight sleeves)
  fits.clear(m, gap)                     # pushes every fit's vertices out of the body to `gap` m (scalar / per vertex)
  fits.dist(fit, P)                      # signed distance of points to the body of that fit (+ outside)

"cloth" is the body with its skin detail smoothed away (Taubin, so the volume stays): cloth over a bust lies
on its dome, not on the nipples and the groove; over the male fit it does not tent at the genitals (the
clearance solver pushes it clear of the real surface).
"""

import json
import os

import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import regions as RG
from lib.context import ASSETS
from cloth2.mesh import FITS, REF, SHAPE_FIT, Mesh, unit, vertex_normals

# body regions the garments cover (head, hands and feet have their own parts: hats, gloves, shoes)
COVERED = ["neck_upper", "neck_lower", "chest_upper_front", "chest_upper_side", "chest_upper_back", "chest_front",
           "chest_side", "chest_back", "abdomen_front", "abdomen_side", "abdomen_back", "pelvis_center", "pelvis_side",
           "upper_arm_l", "forearm_a_l", "forearm_b_l", "forearm_c_l", "wrist_l", "upper_arm_r", "forearm_a_r",
           "forearm_b_r", "forearm_c_r", "wrist_r", "thigh_upper_l", "thigh_lower_l", "shin_upper_l", "shin_lower_l",
           "ankle_l", "thigh_upper_r", "thigh_lower_r", "shin_upper_r", "shin_lower_r", "ankle_r"]
PROXY_RATIO = 0.55
OBSTACLE_REACH = 0.05      # Garment.over: obstacles (open garment sheets) farther than this from a point are ignored
GENITAL_WEIGHT = 0.02      # a vertex with more weight than this on the genital bone belongs to the (hidden) genitals
BODY_JSON = os.path.join(ASSETS, "body", "body.json")


def joints():
    """The skeleton's joints at the bind pose in Blender space (x, y, z up; the character faces -y): from the body's
    inverse binds (body.json, Godot space x, y up, z forward)."""
    ib = json.load(open(BODY_JSON))["inverse_bind_godot"]
    J = {}
    for k, m in ib.items():
        a = np.array(m).reshape(4, 3)
        B = np.array([a[0], a[1], a[2]]).T
        g = -B.T @ a[3]
        J[k] = np.array([g[0], -g[2], g[1]])
    return J


def chain_param(P, pts):
    """Position of points along the polyline `pts` (joint positions): (t 0..1 by length, distance to the line)."""
    pts = np.asarray(pts, float)
    seg = pts[1:] - pts[:-1]
    L = np.linalg.norm(seg, axis=1)
    cum = np.concatenate([[0.0], np.cumsum(L)])
    best_d = np.full(len(P), np.inf)
    best_t = np.zeros(len(P))
    for i in range(len(seg)):
        d = seg[i] / max(L[i], 1e-9)
        s = np.clip(((P - pts[i]) @ d), 0.0, L[i])
        q = pts[i] + s[:, None] * d
        dist = np.linalg.norm(P - q, axis=1)
        m = dist < best_d
        best_d[m] = dist[m]
        best_t[m] = (cum[i] + s[m]) / cum[-1]
    return best_t, best_d
TAUBIN = (0.5, -0.53)
CLOTH_SMOOTH = 7
HOLLOW_SMOOTH = 30
HOLLOW_FILL = 0.9


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


class Fits:
    def __init__(self, ctx, ratio=PROXY_RATIO):
        body = ctx.body()
        self.ctx = ctx
        self.F = body.F
        self.freg = body.freg
        self.bones = list(ctx.bones)
        self.W = body.W
        Vf = body.V.copy()
        self.V = {"f": Vf}
        for shape, fit in SHAPE_FIT.items():
            if shape in body.shapes:
                self.V[fit] = Vf + body.shapes[shape]
        self.N = {k: vertex_normals(v, self.F) for k, v in self.V.items()}
        self.bvh = {k: BVHTree.FromPolygons([tuple(p) for p in v], [tuple(t) for t in self.F], all_triangles=True)
                    for k, v in self.V.items()}
        # the male genitals (faces on the genital bone) are hidden under every garment (the user, 2026-09-28: pants or
        # underwear hide them; a shirt's tails cover them): the cloth follows the body without them
        gi = [i for i, b in enumerate(self.bones) if b == "spinea_muscle"]
        self.gen_face = np.zeros(len(self.F), bool)
        if gi:
            self.gen_face = (self.W[:, gi[0]] > GENITAL_WEIGHT)[self.F].any(1)
        keep = [tuple(t) for t in self.F[~self.gen_face]]
        self.bvhs = {k: BVHTree.FromPolygons([tuple(p) for p in v], keep, all_triangles=True) for k, v in self.V.items()}
        self.J = joints()
        self._proxy(ratio)
        self._limbs()
        self._cloth()

    def arm(self, side):
        """Joint chain of an arm ('l' / 'r'): shoulder, elbow, wrist."""
        return [self.J[side + "_shoulder"], self.J[side + "_elbow"], self.J[side + "_wrist"]]

    def leg(self, side):
        return [self.J[side + "_upper_leg"], self.J[side + "_knee"], self.J[side + "_ankle"]]

    # ---- the decimated cloth proxy, bound to the full body ---------------------------------------
    def _proxy(self, ratio):
        ids = [RG.REGIONS[n] for n in COVERED]
        sel = np.isin(self.freg, ids) & ~self.gen_face
        Fs = self.F[sel]
        used = np.unique(Fs)
        remap = -np.ones(len(self.V[REF]), int)
        remap[used] = np.arange(len(used))
        me = bpy.data.meshes.new("cloth2_src")
        me.from_pydata([tuple(p) for p in self.V[REF][used]], [], [tuple(t) for t in remap[Fs]])
        me.update()
        ob = bpy.data.objects.new("cloth2_src", me)
        bpy.context.scene.collection.objects.link(ob)
        mod = ob.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_symmetry = True
        mod.symmetry_axis = "X"
        mod.use_collapse_triangulate = True
        dg = bpy.context.evaluated_depsgraph_get()
        ev = ob.evaluated_get(dg)
        me2 = ev.to_mesh()
        Vp = np.array([tuple(v.co) for v in me2.vertices], float)
        Fp = np.array([tuple(p.vertices) for p in me2.polygons if len(p.vertices) == 3], int)
        ev.to_mesh_clear()
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(me)
        # drop vertices no triangle uses
        u = np.unique(Fp)
        rp = -np.ones(len(Vp), int)
        rp[u] = np.arange(len(u))
        Vp, Fp = Vp[u], rp[Fp]
        # bind every proxy vertex to the full body (triangle, barycentrics, offset along the normal)
        tri = np.zeros(len(Vp), int)
        bary = np.zeros((len(Vp), 3))
        off = np.zeros(len(Vp))
        bv = self.bvh[REF]
        Vb = self.V[REF]
        for i, p in enumerate(Vp):
            loc, nrm, idx, dist = bv.find_nearest(Vector(p))
            t = self.F[idx]
            b = _bary(np.array(loc), Vb[t[0]], Vb[t[1]], Vb[t[2]])
            tri[i], bary[i] = idx, b
            off[i] = float((p - np.array(loc)) @ np.array(nrm))
        self.pF = Fp
        self.p_tri, self.p_bary, self.p_off = tri, bary, off
        self.PV = {}
        self.PN = {}
        for k, V in self.V.items():
            n = unit(np.einsum("ij,ijk->ik", bary, self.N[k][self.F[tri]]))
            self.PV[k] = np.einsum("ij,ijk->ik", bary, V[self.F[tri]]) + n * off[:, None]
            self.PN[k] = n
        self.PW = np.einsum("ij,ijk->ik", bary, self.W[self.F[tri]])
        # the body region of each proxy face: the region of the body face nearest its centre
        C = self.PV[REF][Fp].mean(1)
        self.p_region = np.array([self.freg[bv.find_nearest(Vector(c))[2]] for c in C], int)
        # the genital vertices (their weight on the genital bone): the cloth does not follow them
        self.p_genital = np.zeros(len(Vp), bool)
        gi = [i for i, b in enumerate(self.bones) if b == "spinea_muscle"]
        if gi:
            self.p_genital = self.PW[:, gi[0]] > 0.05

    def _limbs(self):
        """Per proxy vertex: how much it belongs to each limb (from the skin weights, 0..1: continuous, so a cut
        field built from it never jumps) and its place along the limb (0 root .. 1 end, reference fit)."""
        from cloth2.mesh import smoothstep
        prefixes = {"arm_l": ["l_shoulder", "l_elbow", "l_wrist", "l_palm", "l_forarm", "l_pinky", "l_thumb", "l_index",
                              "l_ring", "l_middle"],
                    "arm_r": ["r_shoulder", "r_elbow", "r_wrist", "r_palm", "r_forarm", "r_pinky", "r_thumb", "r_index",
                              "r_ring", "r_middle"],
                    "leg_l": ["l_upper_leg", "l_knee", "l_ankle", "l_heel", "l_ball"],
                    "leg_r": ["r_upper_leg", "r_knee", "r_ankle", "r_heel", "r_ball"]}
        chains = {"arm_l": self.arm("l"), "arm_r": self.arm("r"), "leg_l": self.leg("l"), "leg_r": self.leg("r")}
        self.p_limb = {}
        for name, pre in prefixes.items():
            cols = [i for i, b in enumerate(self.bones) if any(b.startswith(p) for p in pre)]
            w = self.PW[:, cols].sum(1)
            self.p_limb["m_" + name] = smoothstep(0.35, 0.75, w)
            t, _ = chain_param(self.PV[REF], chains[name])
            self.p_limb["t_" + name] = t

    def _mesh(self, V):
        return Mesh(V, self.pF, None, {"W": self.PW, **self.p_limb},
                    {"region": self.p_region, "part": np.zeros(len(self.pF), int), "zone": np.zeros(len(self.pF), int)})

    def _cloth(self):
        m = self._mesh(self.PV)
        for _ in range(CLOTH_SMOOTH):
            m.smooth(1, TAUBIN[0], keep_boundary=True)
            m.smooth(1, TAUBIN[1], keep_boundary=True)
        # cloth bridges the hollows (the sternum, the collarbones, the armpit, the small of the back): where a much
        # smoother version of the surface lies outside this one, the cloth follows the smoother one
        s2 = self._mesh(self.PV)
        for _ in range(HOLLOW_SMOOTH):
            s2.smooth(1, TAUBIN[0], keep_boundary=True)
            s2.smooth(1, TAUBIN[1], keep_boundary=True)
        self.CV = {}
        for k in m.V:
            n1 = vertex_normals(m.V[k], self.pF)
            fill = np.maximum(((s2.V[k] - m.V[k]) * n1).sum(1), 0.0)
            self.CV[k] = m.V[k] + n1 * (fill * HOLLOW_FILL)[:, None]
        self.CN = {k: vertex_normals(v, self.pF) for k, v in self.CV.items()}
        # the cloth surface as an obstacle (hanging cloth lies on it: it bridges the hollows, e.g. the groove between
        # the buttocks, which the raw skin would crumple the cloth into)
        self.bvhc = {k: BVHTree.FromPolygons([tuple(p) for p in v], [tuple(t) for t in self.pF], all_triangles=True)
                     for k, v in self.CV.items()}

    def surface(self, base="cloth"):
        """The covered body as a Mesh in every fit (`base` "cloth": smoothed; "skin": the skin itself)."""
        V, N = (self.PV, self.PN) if base == "skin" else (self.CV, self.CN)
        return Mesh(V, self.pF, N, {"W": self.PW, **self.p_limb},
                    {"region": self.p_region, "part": np.zeros(len(self.pF), int), "zone": np.zeros(len(self.pF), int)})

    # ---- distances and clearance ------------------------------------------------------------------
    def dist(self, fit, P, surface="skin"):
        """Signed distance of points to the body of `fit` (positive outside), and the nearest point / normal.
        `surface` "cloth": the smoothed cloth surface instead of the skin (hanging cloth); a dict {fit: BVHTree}: those
        obstacles (the garments worn under, Garment.over: open sheets, so a point farther than OBSTACLE_REACH from
        them counts as clear)."""
        if isinstance(surface, dict):
            return self._dist_obstacle(surface[fit], P)
        bv = (self.bvhc if surface == "cloth" else self.bvhs)[fit]
        d = np.zeros(len(P))
        loc = np.zeros_like(P)
        nrm = np.zeros_like(P)
        for i, p in enumerate(P):
            l, n, idx, dd = bv.find_nearest(Vector(p))
            l, n = np.array(l), np.array(n)
            s = 1.0 if (p - l) @ n >= 0.0 else -1.0
            d[i], loc[i], nrm[i] = s * dd, l, n
        return d, loc, nrm

    def _dist_obstacle(self, ob, P):
        """Signed distance to an obstacle (bvh, boundary-face mask): a nearest point on a sheet's open border (not
        straight under the point) says nothing about inside or outside, so it counts as clear."""
        bv, border = ob
        d = np.full(len(P), 1.0)
        loc = np.zeros_like(P)
        nrm = np.zeros_like(P)
        nrm[:, 2] = 1.0
        for i, p in enumerate(P):
            l, n, idx, dd = bv.find_nearest(Vector(p), OBSTACLE_REACH)
            if l is None:
                continue
            l, n = np.array(l), np.array(n)
            q = p - l
            if border[idx] and np.linalg.norm(q - (q @ n) * n) > 0.0008:
                continue
            s = 1.0 if q @ n >= 0.0 else -1.0
            d[i], loc[i], nrm[i] = s * dd, l, n
        return d, loc, nrm

    def obstacles(self, meshes):
        """{fit: (BVHTree, boundary-face mask)} of garment meshes (cloth2 Mesh, every fit) to clear: Garment.over()."""
        out = {}
        Fs, off = [], 0
        for m in meshes:
            Fs.append(m.F + off)
            off += m.n
        F = np.concatenate(Fs)
        E = np.sort(np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]]), 1)
        _, inv, cnt = np.unique(E, axis=0, return_inverse=True, return_counts=True)
        open_e = (cnt[inv.ravel()] == 1).reshape(3, -1)
        border = open_e.any(0)
        for k in self.V:
            if not all(k in m.V for m in meshes):
                continue
            V = np.concatenate([m.V[k] for m in meshes])
            # faces that face into the body (the inside of a rim, a lining) are not a layer to clear: skipped like a border
            C = V[F].mean(1)
            fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
            inward = np.zeros(len(F), bool)
            bv = self.bvhs[k]
            for i in range(len(F)):
                _, bn, _, _ = bv.find_nearest(Vector(C[i]))
                if bn is not None and (fn[i] @ np.array(bn)) < -0.2 * np.linalg.norm(fn[i]):
                    inward[i] = True
            out[k] = (BVHTree.FromPolygons([tuple(p) for p in V], [tuple(t) for t in F], all_triangles=True),
                      border | inward)
        return out

    def clear(self, m, gap, iters=5, spread=0.5, surface="skin", max_push=None):
        """Pushes the vertices of every fit out of the body until every vertex, face centre and edge midpoint of the
        garment is `gap` m above its surface (a scalar, or per vertex). A sample that is short pushes the vertices
        it sits between along the body's outward normal at the nearest skin point; the push spreads to the
        neighbours (a soft correction, not a spike); the last pass is exact. Returns
        {fit: (lowest clearance m, samples short)}.
        max_push: no vertex moves farther than this (m) from where it started (Garment.over: in a fold of the layer
        under it the push can run on)."""
        n = m.n
        F = m.F
        nf = len(F)
        gap = np.broadcast_to(np.asarray(gap, float), (n,)).copy()
        gs = np.concatenate([gap, gap[F].mean(1), (gap[F[:, 0]] + gap[F[:, 1]]) / 2, (gap[F[:, 1]] + gap[F[:, 2]]) / 2,
                             (gap[F[:, 2]] + gap[F[:, 0]]) / 2])
        # which vertices each sample sits between: (sample, vertex) pairs
        fi = np.arange(nf)
        own_s = np.concatenate([np.arange(n)] + [n + fi] * 3 + [n + nf + fi] * 2 + [n + 2 * nf + fi] * 2 + [n + 3 * nf + fi] * 2)
        own_v = np.concatenate([np.arange(n), F[:, 0], F[:, 1], F[:, 2], F[:, 0], F[:, 1], F[:, 1], F[:, 2], F[:, 2], F[:, 0]])
        E = m.adjacency()
        report = {}

        def samples(P):
            return np.concatenate([P, P[F].mean(1), (P[F[:, 0]] + P[F[:, 1]]) / 2, (P[F[:, 1]] + P[F[:, 2]]) / 2,
                                   (P[F[:, 2]] + P[F[:, 0]]) / 2])
        for k in m.V:
            if k not in self.bvh or (isinstance(surface, dict) and k not in surface):
                continue
            start = m.V[k].copy()
            for it in range(iters + 10):
                P = m.V[k]
                d, loc, nrm = self.dist(k, samples(P), surface)
                short = np.maximum(gs - d, 0.0)
                sv_s = short[own_s]
                sv = np.zeros(n)
                np.maximum.at(sv, own_v, sv_s)
                tie = (sv_s > 0) & (sv_s >= sv[own_v] - 1e-9)
                D = np.zeros((n, 3))
                cnt = np.zeros(n)
                np.add.at(D, own_v[tie], nrm[own_s[tie]] * sv_s[tie][:, None])
                np.add.at(cnt, own_v[tie], 1.0)
                D /= np.maximum(cnt, 1.0)[:, None]
                if sv.max() < 3e-4:
                    break
                if it >= iters:
                    m.V[k] = P + D * 1.05    # the exact passes: no spreading
                else:
                    acc = np.zeros_like(D)
                    c2 = np.zeros(n)
                    np.add.at(acc, E[:, 0], D[E[:, 1]])
                    np.add.at(c2, E[:, 0], 1.0)
                    Ds = acc / np.maximum(c2, 1.0)[:, None]
                    m.V[k] = P + np.where(sv[:, None] > 0, D, spread * Ds)
                if max_push is not None:
                    q = m.V[k] - start
                    L = np.linalg.norm(q, axis=1, keepdims=True)
                    m.V[k] = start + q * np.minimum(1.0, max_push / np.maximum(L, 1e-12))
            d, _, _ = self.dist(k, samples(m.V[k]), surface)
            report[k] = (float(d.min()), int((d < gs - 0.0007).sum()))
        m.recompute_normals()
        return report
