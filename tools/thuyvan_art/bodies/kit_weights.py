"""Skin weights of the kit bodies, on the lib's rules (tools/character/lib/README.md): segments joint -> child joint
(weights.deform_segments) never Blender bone tails, region-limited bones, the twist / armpit helpers
(weights.helper_weights), max 4 influences (weights.limit_normalize); the tail by a chain blend along the tail curve
(two adjacent tail bones per vertex, as weights.chain_weights does for the spine), the upper snout rigid on headb and
the lower jaw on Actor_B's `jaw`, the claws rigid on the ball / last finger bones.

Plain numpy (lib.weights' numpy functions); runs inside Blender and, through libshim, outside it.
"""

import numpy as np

from lib.helpers import helper_bones
from lib.sdf import peval
from lib.weights import deform_segments, helper_weights, limit_normalize, region_bones, seg_dist, smooth_weights


def weight_bones(J, kit_deform, extra=()):
    """Weight columns: deform-segment bones and driven helpers in rig order (plus `extra` Actor_B bones such as the
    Floodborn's `jaw`), then the kit's deforming bones."""
    segs = deform_segments(J)
    helpers = set(helper_bones())
    base = [n for n in J.order if (n in segs or n in helpers or n in extra) and n not in kit_deform]
    return base + list(kit_deform)


def edges(F):
    E = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    return np.unique(np.sort(E, 1), axis=0)


def floodborn_weights(V, F, J, groups, curve, P, bones, jaw_tip):
    segs = deform_segments(J)
    segs["jaw"] = ([(J["jaw"], jaw_tip)], 0.05)
    bi = {b: i for i, b in enumerate(bones)}
    labels = list(groups)
    D = np.stack([peval(groups[g], V) for g in labels], 1)
    lab = np.argmin(D, 1)
    allowed = region_bones()
    allowed["head"] = ["headb", "heada"]
    allowed["jaw"] = ["jaw", "headb"]
    allowed["neck"] = ["spined", "neck", "heada", "headb", "l_clavicle", "r_clavicle"]
    allowed["tail"] = ["pelvis"]
    W = np.zeros((len(V), len(bones)))
    for li, g in enumerate(labels):
        m = lab == li
        if not m.any():
            continue
        Vm = V[m]
        Wm = np.zeros((len(Vm), len(bones)))
        for b in allowed[g]:
            ss, rad = segs[b]
            d = np.min([seg_dist(Vm, a, c) for a, c in ss], axis=0)
            Wm[:, bi[b]] = (rad / np.maximum(d, 1e-4)) ** 4
        W[m] = Wm / np.maximum(Wm.sum(1, keepdims=True), 1e-12)
    # tail: chain blend along the curve (pelvis at the root)
    C, t = curve
    tail_names = ["tail_%02d" % k for k in range(1, 9)]
    heads = np.array([J[n] for n in tail_names])
    tm = lab == labels.index("tail")
    # nearest curve sample -> arc parameter -> bone index (fractional, by the bind heads)
    dd = np.linalg.norm(V[tm][:, None, :] - C[None, :, :], axis=2)
    k = dd.argmin(1)
    s_curve = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(C, axis=0), axis=1))])
    s_heads = np.array([s_curve[np.linalg.norm(C - h, axis=1).argmin()] for h in heads])
    sv = s_curve[k]
    u = np.interp(sv, s_heads, np.arange(8), left=0, right=7.999)
    lo = np.clip(np.floor(u).astype(int), 0, 6)
    f = np.clip(u - lo, 0, 1)
    # a smoother joint blend: the weight moves to the next bone over the second half of each bone
    f = np.clip((f - 0.35) / 0.65, 0, 1)
    Wt = np.zeros((tm.sum(), len(bones)))
    idx = np.arange(tm.sum())
    Wt[idx, [bi[tail_names[i]] for i in lo]] = 1 - f
    Wt[idx, [bi[tail_names[i + 1]] for i in lo]] += f
    root = np.clip(sv / max(s_heads[1], 1e-3), 0, 1)       # pelvis -> tail_01 over the first bone
    Wt *= root[:, None]
    Wt[:, bi["pelvis"]] += 1 - root
    W[tm] = Wt
    E = edges(F)
    W = smooth_weights(W, E, 4, 0.5)
    # rigid upper snout / skull on headb, lower jaw on jaw (forward of the hinge)
    hb = J["headb"]
    head = (lab == labels.index("head")) & ((V[:, 2] > 1.47) | (V[:, 1] < hb[1] - 0.05))
    jaw = (lab == labels.index("jaw")) & (V[:, 1] < -0.03)
    lock = head | jaw
    W[head] = 0
    W[head, bi["headb"]] = 1
    W[jaw] = 0
    W[jaw, bi["jaw"]] = 1
    # claws and toes rigid on the ball (forward of the ball pad)
    for sd, s in (("l", 1), ("r", -1)):
        fm = (lab == labels.index("foot_" + sd)) & (V[:, 1] < J[sd + "_ball"][1] - 0.02) & (V[:, 2] < 0.08)
        W[fm] = 0
        W[fm, bi[sd + "_ball"]] = 1
        lock |= fm
    W = smooth_weights(W, E, 1, 0.3, lock=lock)
    W = helper_weights(V, W, bones, J)
    return limit_normalize(W), lab, labels


def nearest_transfer(Vsrc, Wsrc, Vdst, k=4, mask=None):
    """Inverse-distance blend of the k nearest source vertices' weights (garment-style transfer)."""
    src = np.arange(len(Vsrc)) if mask is None else np.nonzero(mask)[0]
    S = Vsrc[src]
    out = np.zeros((len(Vdst), Wsrc.shape[1]))
    for i0 in range(0, len(Vdst), 256):
        P = Vdst[i0:i0 + 256]
        d2 = ((P[:, None, :] - S[None, :, :]) ** 2).sum(2)
        nn = np.argpartition(d2, k, axis=1)[:, :k]
        dn = np.sqrt(np.take_along_axis(d2, nn, 1)) + 1e-4
        w = 1 / dn
        w /= w.sum(1, keepdims=True)
        out[i0:i0 + 256] = (Wsrc[src[nn]] * w[:, :, None]).sum(1)
    return out


def chain_rigid(V, chains, bones, J):
    """Each vertex to the nearest segment of the given bones (rigid, for crown branches and hanging vines), the
    weight split between the two nearest bones of the chain."""
    bi = {b: i for i, b in enumerate(bones)}
    D = []
    for b in chains:
        a = J[b]
        c = J.tails[b] if hasattr(J, "tails") and b in J.tails else a + J.G[b][:3, 1] * 0.03
        D.append(seg_dist(V, a, c))
    D = np.stack(D, 1)
    W = np.zeros((len(V), len(bones)))
    w = (0.02 / np.maximum(D, 1e-4)) ** 4
    for j, b in enumerate(chains):
        W[:, bi[b]] = w[:, j]
    return limit_normalize(W, 2)
