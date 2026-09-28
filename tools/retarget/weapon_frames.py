"""Weapon frames of the hand prop bone (`r_hand_prop_attachment`) for the actor_b_from_a library.

The source game attaches every weapon model to the hand prop bone with a per-weapon offset, so
the prop frame's axes mean different things in different clip families. The library ships one
frame per weapon family, so a weapon attached once (one offset) never flips or jumps when the
game blends between clip families. Everything here is measured from the source clips at build
time (retarget.py calls `measure()`); nothing is hand-tuned.

Families
  blade       one-handed blades (saber, tomahawk, knife). Library frame = the Actor_B knife
              clips' own frame: the blade leaves the fist along prop +Y (the finger channel,
              pinky -> index), the finger / edge side is about prop -Z, the origin is the fist
              centre (graph_analysis/melee_horse_prone/saber_model.md 3). The Actor_A machete
              clips hold the blade along prop +Z instead; they are converted by the constant
              rotation `D` below (a half turn), measured from the finger geometry of both sets.
              The saber attaches with saber_model.md's SABER_PROP_OFFSET in both sets.
  two_hand    spear, club and musket in the guard, haft sweep, club and butt-stroke clips.
              Library frame = the source's keyed two-handed haft clips (`atk-pipe-*`): +Z runs
              along the weapon from the left (lower) hand through the right hand to the working
              end (spear point, club head, musket butt); the left palm grips at `grip_l` in the
              prop frame (0.075 m up the axis from the origin), the right palm at `grip_r` (about
              0.2 m up). Guard clips that key no prop (`pipe-block-*`, `atk-pipe-block`) get this
              frame from where the source's two hands hold the haft (retarget.synthetic_two_hand):
              the axis runs through both hands' grip points (the palm plus `grip_*_point`, where the
              haft passes through each fist in the haft clips), the roll comes from the right palm
              (the canonical right-hand grip `right_fist` swung onto the axis), and the left grip point
              sits 0.075 m up the axis from the origin. The haft clips' own roll (their source prop is
              a round pipe, so its roll was never authored) is set the same way, so a roll-asymmetric
              weapon keeps one orientation in the fist. The long-gun clips (`atk-lg-*`, whose
              source frame has the right hand at the origin and the barrel along +Z past the left
              hand) are turned half a turn about prop Y (the butt, the musket's striking end,
              becomes +Z) and shifted along the axis so the left palm sits where the haft clips
              grip; they keep the source rifle's roll.

A conversion is a constant change of frame: prop_new = prop_old * [D | t] (rotation D,
translation t in the old prop frame). It moves no body part; the source frame is recovered
with the inverse, which the manifest records per clip.
"""
import numpy as np

from rtmath import axis_angle, m2q, q2m, rot_between


def _circle_centre(a, b, c):
    ab, ac = b - a, c - a
    n = np.cross(ab, ac)
    return a + (np.cross(n, ab) * np.sum(ac * ac, -1)[..., None] +
                np.cross(ac, n) * np.sum(ab * ab, -1)[..., None]) / (2 * np.sum(n * n, -1)[..., None])


def grip_frame(rig, GP, GR, side="r"):
    """Finger-channel grip of a closed hand, per frame, in the hand prop frame (saber_model.md 3.1):
    a circle through each finger's MCP / PIP / DIP joint heads; the grip axis is the line through
    the four centres (pinky -> index), the finger side the direction from that axis to the middle of
    the proximal phalanges. Returns (axis (F,3), finger side (F,3), fist centre (F,3))."""
    ip = rig.idx[side + "_hand_prop_attachment"]
    cs, mids = [], []
    for f in ("index", "middle", "ring", "pinky"):
        a, b, c = (GP[:, rig.idx["%s_%s%s" % (side, f, k)]] for k in "abc")
        cs.append(_circle_centre(a, b, c))
        mids.append(0.5 * (a + b))
    cs, mids = np.stack(cs, 1), np.stack(mids, 1)
    ctr = cs.mean(1)
    ax = cs[:, 0] - cs[:, 3]
    ax /= np.linalg.norm(ax, axis=1, keepdims=True)
    m = mids.mean(1) - ctr
    m -= np.sum(m * ax, 1, keepdims=True) * ax
    m /= np.linalg.norm(m, axis=1, keepdims=True)
    loc = lambda v: np.einsum("fji,fj->fi", GR[:, ip], v)  # noqa: E731
    return loc(ax), loc(m), loc(ctr - GP[:, ip])


def _unit(v):
    return v / np.linalg.norm(v)


def _frame(axis, finger):
    """Right-handed basis (columns x, y = axis, z = finger side)."""
    y = _unit(axis)
    z = _unit(finger - (finger @ y) * y)
    return np.stack([np.cross(y, z), y, z], 1)


def mean_rotation(Ms):
    q = m2q(np.asarray(Ms, float))
    s = np.where(np.einsum("ij,j->i", q, q[0]) < 0, -1.0, 1.0)  # (einsum: numpy 2.0 + Accelerate flags spurious FP errors on matmul)
    m = (q * s[:, None]).mean(0)
    return q2m(m / np.linalg.norm(m))


def _angle_deg(M0, Ms):
    return np.degrees(np.arccos(np.clip((np.trace(np.einsum("ji,fjk->fik", M0, Ms), axis1=1, axis2=2) - 1) / 2, -1, 1)))


def _pose(rig, clip):
    F = clip["frames"]
    P, R = rig.local_arrays(clip["tracks"], F)
    return rig.fk(P, R)


def _hand_grips(A, src, names, ip):
    """Canonical grip of each hand on a two-handed weapon, pooled over `names` (A's keyed haft
    clips): the prop rotation in the palm frame, the palm position in the prop frame, and the grip
    point (the palm projected onto the weapon axis) in the palm frame. Frames more than 45 deg from
    the first mean (regrips: a hand sliding or turning on the haft) are left out."""
    g = {s: {"M": [], "P": [], "Q": []} for s in "lr"}
    for n in names:
        GP, GR = _pose(A, src["clips"][n])
        Z = GR[:, ip, :, 2]
        for s in "lr":
            pa = A.idx[s + "_palm"]
            g[s]["M"].append(np.einsum("fji,fjk->fik", GR[:, pa], GR[:, ip]))
            d = GP[:, pa] - GP[:, ip]
            g[s]["P"].append(np.einsum("fji,fj->fi", GR[:, ip], d))
            axis_pt = GP[:, ip] + np.sum(d * Z, 1, keepdims=True) * Z
            g[s]["Q"].append(np.einsum("fji,fj->fi", GR[:, pa], axis_pt - GP[:, pa]))
    res = {}
    for s in "lr":
        M, P, Q = (np.concatenate(g[s][k]) for k in ("M", "P", "Q"))
        keep = _angle_deg(mean_rotation(M), M) < 45.0
        m1 = mean_rotation(M[keep])
        res[s] = {"rot": m1, "pos": np.median(P[keep], 0), "point": np.median(Q[keep], 0),
                  "spread_deg_p50": float(np.percentile(_angle_deg(m1, M[keep]), 50)), "frames_kept": float(keep.mean())}
    return res


def measure(A, B, src, dst, spec):
    """spec = actor_b_from_a_clips.json `weapon_frames`. Returns {family: {...}} with rotation D,
    translation t (library frame = source frame * [D | t]) and, for two_hand, the canonical grip of
    each hand (`grip_l_rot` / `grip_r_rot`: rotation of the prop in the palm frame; `grip_l` /
    `grip_r`: palm position in the prop frame; `grip_l_point` / `grip_r_point`: the grip point on
    the weapon axis in the palm frame), all in Actor_A's palm frames."""
    out = {}
    ip = A.idx["r_hand_prop_attachment"]
    bl = spec.get("blade")
    if bl:
        ref = [n for n in bl.get("reference_b", []) if n in dst.get("clips", {})]
        srcs = [n for n in bl.get("source_a", []) if n in src["clips"]]
        if ref and srcs:
            def pooled(rig, dump, names):
                ax, fs, c = [], [], []
                for n in names:
                    GP, GR = _pose(rig, dump["clips"][n])
                    a, f, cc = grip_frame(rig, GP, GR)
                    ax.append(a), fs.append(f), c.append(cc)
                ax, fs, c = np.concatenate(ax), np.concatenate(fs), np.concatenate(c)
                return _unit(np.median(ax, 0)), _unit(np.median(fs, 0)), np.median(c, 0)
            ka, kf, kc = pooled(B, dst, ref)
            ma, mf, mc = pooled(A, src, srcs)
            D = _frame(ma, mf) @ _frame(ka, kf).T  # knife-frame coordinates -> machete-frame coordinates
            out["blade"] = {"D": D, "t": np.zeros(3), "clips_source": srcs, "clips_reference": ref,
                            "reference_axis": ka, "reference_finger_side": kf, "reference_centre": kc,
                            "source_axis": ma, "source_finger_side": mf, "source_centre": mc,
                            "angle_deg": float(np.degrees(np.arccos(np.clip((np.trace(D) - 1) / 2, -1, 1))))}
    th = spec.get("two_hand")
    if th:
        ref = [n for n in th.get("reference_a", []) if n in src["clips"]]
        gr = _hand_grips(A, src, ref, ip)
        grip_l = gr["l"]["pos"]
        out["two_hand"] = {"grip_l_rot": gr["l"]["rot"], "grip_l": grip_l, "grip_l_point": gr["l"]["point"],
                           "grip_r_rot": gr["r"]["rot"], "grip_r": gr["r"]["pos"], "grip_r_point": gr["r"]["point"],
                           "clips_reference": ref,
                           "grip_rot_spread_deg_p50": {s: gr[s]["spread_deg_p50"] for s in "lr"},
                           "grip_frames_kept": {s: gr[s]["frames_kept"] for s in "lr"}}
        lg = [n for n in th.get("long_gun_a", []) if n in src["clips"]]
        if lg:
            MLg, PLg = [], []
            for n in lg:
                GP, GR = _pose(A, src["clips"][n])
                lp = A.idx["l_palm"]
                MLg.append(np.einsum("fji,fjk->fik", GR[:, lp], GR[:, ip]))
                PLg.append(np.einsum("fji,fj->fi", GR[:, ip], GP[:, lp] - GP[:, ip]))
            MLg, PLg = np.concatenate(MLg), np.concatenate(PLg)
            # The source long-gun frame has the right hand (stock wrist) at the origin and the
            # barrel along +Z past the left hand, so its +Z runs right hand -> left hand, the
            # opposite of the haft clips (left -> right, toward the working end). A half turn about
            # prop Y reverses the axis (the butt, the musket's striking end, becomes +Z) and a shift
            # along it puts the left palm where the haft clips grip (grip_l z). The hands then hold
            # the musket with a rifle grip, not the haft clips' bat grip, which is right: the grip
            # mismatch printed here is for information.
            D = axis_angle(np.array([0.0, 1.0, 0.0]), np.pi)
            z0 = float(np.median(PLg[:, 2]) + grip_l[2])
            out["long_gun"] = {"D": D, "t": np.array([0.0, 0.0, z0]), "clips_source": lg,
                               "left_palm_z_source_m": float(np.median(PLg[:, 2])),
                               "left_grip_vs_haft_deg": float(np.median(_angle_deg(gr["l"]["rot"], MLg @ D)))}
    return out


def two_hand_for_b(fam, C_post, k_hand):
    """The two_hand grips expressed for Actor_B's palms: world prop rotations are shared and B's
    palm = A's palm * C_post, so a rotation in the palm frame becomes C_post^T R and a palm-frame
    offset C_post^T v (scaled to B's hand, k_hand); positions along the weapon axis are the same
    object and are not scaled."""
    out = {}
    for s in "lr":
        Cp = C_post[s + "_palm"]
        g = np.asarray(fam["grip_%s" % s], float)
        out[s] = {"rot": Cp.T @ fam["grip_%s_rot" % s],
                  "pos": np.array([k_hand * g[0], k_hand * g[1], g[2]]),
                  "point": k_hand * (Cp.T @ np.asarray(fam["grip_%s_point" % s], float))}
    return out


def right_fist(grips):
    """Local transform (rotation, position) of the prop bone in the right palm frame that holds the
    weapon at the haft clips' canonical right-hand grip (grips = two_hand_for_b()): the prop origin
    is where the palm sits at grip_r in the prop frame."""
    M = grips["r"]["rot"]
    return M, -M @ grips["r"]["pos"]


def convert(GP, GR, P, R, rig, prop, D, t):
    """Apply a frame conversion to one prop bone on world (GP, GR) and local (P, R) pose arrays of
    `rig` (in place). The prop is a child of the palm, so its local channels are recomputed."""
    i = rig.idx[prop]
    par = rig.parent[i]
    GP[:, i] = GP[:, i] + np.einsum("fij,j->fi", GR[:, i], t)
    GR[:, i] = GR[:, i] @ D
    R[:, i] = np.einsum("fji,fjk->fik", GR[:, par], GR[:, i])
    P[:, i] = np.einsum("fji,fj->fi", GR[:, par], GP[:, i] - GP[:, par])


def as_record(fam):
    """JSON record of a conversion (library frame = source frame * [D | t])."""
    return {"rotation_q_xyzw": np.round(m2q(fam["D"]), 6).tolist(), "translation_m": np.round(fam["t"], 4).tolist()}
