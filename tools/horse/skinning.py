"""Skin weights of the procedural horse (revision 5), numpy only.

build_horse.py computes Blender's heat weights on the skin with the anatomical bones (the
column, the neck and head, the tail, both girdles and every leg bone), then calls compute()
here, which keeps their spread and fixes what they get wrong for this rig:

  own_side       heat weights reach across the midline (the withers between the shoulder
                 blades, the chest between the fore legs, the inner thighs): a vertex off the
                 midline loses the limb bones of the other side
  withers        the withers belong to the chest, not to the shoulder blades (which turn about
                 a point below their upper border, so their top moves)
  spine_weights  the trunk's share of the column is spread smoothly along the body over chest,
                 back, loin, loin_2 and the pelvis (heat weights cut it into ragged bands)
  joint_helpers  at every limb joint with a helper bone (anatomy.helpers(): shoulder, elbow,
                 knee, fore fetlock, hip, hock, hind fetlock) the blend of the proximal and the
                 distal bone, t = distal / (proximal + distal), becomes the quadratic Bernstein
                 partition (1 - t)^2, 2 t (1 - t), t^2 on proximal, helper and distal: the same
                 spread, but the skin turns through the helper's half-way rotation instead of
                 cutting the chord between the two bones (linear blend skinning collapses a
                 two-bone blend on the inside of a bent joint and thins it on the outside)
  limit          at most four influences per vertex

  weights = skinning.compute(V, edges, heat)     # V (n, 3) Blender armature space, rest pose
                                                 # heat: list of {bone: weight}

Measured with tools/horse/skin_check.py (and its --mesh mode, which runs this module on a skin
dump without Blender): the variants tried in revision 5 (weights rebuilt along the limb
chains, the revision 4 hindquarter override, Laplacian smoothing over the junctions, a stifle
helper) all creased the elbow, girth, flank and stifle more than the heat weights did
(smoothing mixes more than four bones, and the cut back to four makes steps); this keeps the
heat weights' spread. The same function runs in the build and offline.
"""

import numpy as np

import anatomy as A

SPINE = ("chest", "back", "loin", "loin_2", "hips")
# limb bones and helpers (without the side suffix)
LIMB_BONES = ("scapula", "humerus", "radius", "cannon", "pastern", "hoof", "femur", "tibia", "hcannon", "hpastern",
              "hhoof") + tuple(h[:-2] for h in A.helpers() if h.endswith("_l"))


def sstep(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def spine_share(y):
    """Weights of the column's bones at Blender y (rest), a smooth partition of unity: chest |
    back at T9/T10, back | loin at the last rib, loin | loin_2, loin_2 | pelvis at the
    lumbosacral joint."""
    k = [A.S(A.SPINE_T)[1], A.S(A.SPINE_TL)[1], A.S(A.SPINE_L)[1], A.S(A.LUMBOSACRAL)[1]]
    w = [0.11, 0.07, 0.06, 0.08]
    t = [sstep(k[i] - w[i], k[i] + w[i], y) for i in range(4)]
    out = {"chest": 1.0 - t[0]}
    for i, n in enumerate(("back", "loin", "loin_2")):
        out[n] = t[i] * (1.0 - t[i + 1])
    out["hips"] = t[3]
    return out


def own_side(V, W):
    """A vertex off the midline loses the limb bones of the other side (their share goes to
    its other bones, or to the column)."""
    sh = spine_share(V[:, 1])
    for vi in np.nonzero(np.abs(V[:, 0]) > 0.012)[0]:
        other = "_r" if V[vi, 0] > 0 else "_l"
        wd = W[vi]
        drop = [b for b in wd if b.endswith(other) and b[:-2] in LIMB_BONES]
        if not drop:
            continue
        mv = sum(wd.pop(b) for b in drop)
        if sum(wd.values()) < 1e-6:
            for b in SPINE:
                wd[b] = mv * float(sh[b][vi])


def withers(V, W):
    """The shoulder blades' share fades out towards the dorsal midline and above the blade's
    upper border; the chest takes it."""
    top = A.J["scap_top"]
    for s, sg in (("l", 1.0), ("r", -1.0)):
        b = "scapula_" + s
        keep = sstep(0.05, 0.18, V[:, 0] * sg) * sstep(top[2] - 0.01, top[2] - 0.13, V[:, 2])
        keep = np.maximum(keep, sstep(top[1] - 0.05, top[1] - 0.20, V[:, 1]) * sstep(0.02, 0.08, V[:, 0] * sg))
        for vi in np.nonzero(keep < 0.999)[0]:
            wd = W[vi]
            if b not in wd:
                continue
            mv = wd[b] * (1.0 - float(keep[vi]))
            wd[b] -= mv
            wd["chest"] = wd.get("chest", 0.0) + mv


def spine_weights(V, W):
    """The trunk's column share (the heat weights on chest, back, loin, loin_2 and hips)
    redistributed smoothly along the body behind the neck root."""
    sh = spine_share(V[:, 1])
    region = sstep(A.S((0, -0.62, 0))[1], A.S((0, -0.50, 0))[1], V[:, 1])
    for vi in np.nonzero(region > 1e-4)[0]:
        wd = W[vi]
        s = sum(wd.get(b, 0.0) for b in SPINE)
        if s <= 1e-6:
            continue
        r = float(region[vi])
        for b in SPINE:
            old = wd.pop(b, 0.0)
            v = old * (1.0 - r) + s * float(sh[b][vi]) * r
            if v > 1e-6:
                wd[b] = v


def joint_helpers(W):
    """Proximal / distal blends -> (1 - t)^2, 2 t (1 - t), t^2 with the joint's helper."""
    use = [(h, pr, di) for h, (pr, di, _f, _k) in A.helpers().items()]
    for wd in W:
        for h, pr, di in use:
            p, d = wd.get(pr, 0.0), wd.get(di, 0.0)
            if p <= 1e-4 or d <= 1e-4:
                continue
            tot = p + d
            t = d / tot
            wd[pr] = tot * (1.0 - t) ** 2
            wd[di] = tot * t * t
            wd[h] = wd.get(h, 0.0) + tot * 2.0 * t * (1.0 - t)


def limit(W, n=4):
    out = []
    for wd in W:
        top = sorted(wd.items(), key=lambda kv: -kv[1])[:n]
        tot = sum(v for _, v in top) or 1.0
        out.append({k: v / tot for k, v in top if v / tot > 1e-4})
    return out


def compute(V, edges, heat, max_influences=4):
    """Revision 5 weights from the heat weights (see the module doc). `edges` is kept for
    callers (unused: smoothing made the junctions worse)."""
    V = np.asarray(V, float)
    W = [dict(w) for w in heat]
    own_side(V, W)
    withers(V, W)
    spine_weights(V, W)
    joint_helpers(W)
    return limit(W, max_influences)
