"""cloth2 parts: the building blocks garments are made of (2026-09-28).

  hang(fits, m, edge_mask, hem, ...)     cloth hanging from the bottom edge of a shell: shirt tails, coat skirts,
                                         petticoats, robes. Each edge vertex falls in `steps` rings to the hem,
                                         flaring and folding; the column weights hand the cloth over from the body
                                         to the skirt panel bones (the game swings the panels under gravity).
  skirt_weights(P, top_w, z_top, z_full) the weights of hanging cloth
  angle_from_front(P)                    degrees round the vertical axis, 0 at the front, 180 at the back

All positions are per fit (Mesh.V[fit]); hem heights and flare come from the reference fit, so the topology is the
same in every fit and the male fit and the bust gauge are exact morph targets.
"""

import numpy as np

from lib import regions as RG
from mathutils import Vector
from cloth2.mesh import REF, Mesh, concat, smoothstep, unit

SKIRT_BONES = {s: {p: "%s_upper_leg_%s_helper" % (s, p) for p in ("front", "thigh", "rear")} for s in ("l", "r")}
PELVIS_KEEP = 0.15           # what the pelvis keeps of the weight at the hem


def angle_from_front(P, centre=(0.0, 0.0)):
    """Degrees round the vertical axis: 0 at the front (-y), 90 at the sides, 180 at the back."""
    return np.degrees(np.arctan2(np.abs(P[:, 0] - centre[0]), -(P[:, 1] - centre[1])))


def skirt_weights(fits, P, top_w, z_top, z_full):
    """(n, bones) weights of hanging cloth at points P (reference fit) that hang from vertices with weights `top_w`:
    the body's at z_top, the skirt panels' from z_full down (front, side or rear panel of the left or right leg by
    the angle round the body, the two legs blended near the middle so the cloth is never one-sided)."""
    idx = {b: i for i, b in enumerate(fits.bones)}
    n = len(P)
    a = angle_from_front(P)
    front = 1.0 - smoothstep(35.0, 75.0, a)
    rear = smoothstep(105.0, 145.0, a)
    side = np.clip(1.0 - front - rear, 0.0, 1.0)
    left = smoothstep(-0.10, 0.10, P[:, 0])
    Wp = np.zeros((n, len(fits.bones)))
    for sd, share in (("l", left), ("r", 1.0 - left)):
        for panel, pw in (("front", front), ("thigh", side), ("rear", rear)):
            Wp[:, idx[SKIRT_BONES[sd][panel]]] += pw * share
    h = smoothstep(z_top, z_full, P[:, 2]) * (1.0 - PELVIS_KEEP)
    # the rest of the weight: the pelvis at the hem, the body's own at the top
    Wb = np.asarray(top_w, float)
    W = Wb * (1.0 - h)[:, None] + Wp * h[:, None]
    W[:, idx["pelvis"]] += (1.0 - h) * 0.0 + h * PELVIS_KEEP
    return W


def hang(fits, m, edge_mask, hem, steps=8, flare=0.05, flare_pow=1.4, folds=0.0, fold_freq=9.0, z_full=0.72,
         part=0, zone=0, slits=None):
    """Extends the shell `m` downward from its boundary edges whose both vertices satisfy `edge_mask` (bool per vertex
    of m): `hem(P)` is the hem height per boundary vertex (reference position), `flare` the outward spread at the hem
    (m; a number or a function of the reference position), `folds` the amplitude of the folds (m; they grow toward
    the hem). `slits`: [(from angle, to angle, up to z)] openings cut from the hem (side slits of tails). Returns
    the shell and the hanging cloth as one Mesh."""
    be, onb = m.boundary()
    sel = edge_mask[be[:, 0]] & edge_mask[be[:, 1]]
    be = be[sel]
    verts = np.unique(be)
    col = {int(v): i for i, v in enumerate(verts)}
    nv = len(verts)
    K = steps
    P0 = m.V[REF][verts]
    z_hem = np.broadcast_to(np.asarray(hem(P0), float), (nv,))
    fl = np.broadcast_to(np.asarray(flare(P0) if callable(flare) else flare, float), (nv,))
    ang = np.radians(angle_from_front(P0))
    top_w = m.A["W"][verts]
    V = {}
    N = {}
    for k in m.V:
        Vk = m.V[k][verts]
        n = m.N[k][verts]
        nh = n.copy()
        nh[:, 2] = 0.0
        nh = unit(nh)
        rings = []
        for i in range(1, K + 1):
            s = i / K
            drop = (Vk[:, 2] - z_hem) * s
            out = fl * s ** flare_pow + folds * smoothstep(0.15, 1.0, s) * np.sin(fold_freq * ang + 1.7 * s) * 0.5
            p = Vk + nh * out[:, None]
            p[:, 2] = Vk[:, 2] - drop
            rings.append(p)
        V[k] = np.concatenate(rings)                   # ring i occupies rows (i-1)*nv .. i*nv
        N[k] = np.concatenate([nh] * K)
    # weights per new vertex
    Pref = V[REF]
    Wn = skirt_weights(fits, Pref, np.concatenate([top_w] * K), float(P0[:, 2].max()), z_full)
    # faces: strips between consecutive rings along every boundary edge
    def vid(v, i):
        # column vertex of boundary vertex v at ring i (0 = the shell's own vertex)
        return int(v) if i == 0 else m.n + (i - 1) * nv + col[int(v)]
    F = []
    for a, b in be:
        for i in range(K):
            quad = (vid(a, i), vid(b, i), vid(b, i + 1), vid(a, i + 1))
            F.append((quad[0], quad[1], quad[2]))
            F.append((quad[0], quad[2], quad[3]))
    F = np.array(F, int)
    # winding: outward (the shell's own normal side)
    allV = {k: np.concatenate([m.V[k], V[k]]) for k in m.V}
    P = allV[REF]
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    ref_n = np.concatenate([m.N[REF], N[REF]])[F].mean(1)
    flip = (fn * ref_n).sum(1) < 0
    F[flip] = F[flip][:, ::-1]
    # region of each new face: the body region nearest its centre
    cen = P[F].mean(1)
    bv = fits.bvh[REF]
    reg = np.array([fits.freg[bv.find_nearest(Vector(c))[2]] for c in cen], int)
    nf = len(F)
    out = Mesh.__new__(Mesh)
    out.V = allV
    out.N = {k: np.concatenate([m.N[k], N[k]]) for k in m.N}
    out.A = {"W": np.concatenate([m.A["W"], Wn])}
    out.F = np.concatenate([m.F, F])
    out.fa = {"region": np.concatenate([m.fa["region"], reg]), "part": np.concatenate([m.fa["part"], np.full(nf, part)]),
              "zone": np.concatenate([m.fa["zone"], np.full(nf, zone)])}
    for name, arr in m.A.items():
        if name != "W":
            out.A[name] = np.concatenate([arr, np.zeros((K * nv,) + arr.shape[1:])])
    for a1, a2, zmax in (slits or []):
        ang_v = angle_from_front(out.V[REF])
        f = ang_v + 1000.0 * smoothstep(zmax, zmax + 0.03, out.V[REF][:, 2])
        out = out.cut_out(f, a1, a2)
    return out
