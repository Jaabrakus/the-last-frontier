#!/usr/bin/env python3
"""Actor_A -> Actor_B clip retarget. numpy only.

  python3 tools/retarget/retarget.py --src A_dump.json --dst B_dump.json \
      --config tools/retarget/actor_b_from_a_clips.json --out out.json \
      [--report report.json] [--manifest lib.json] [--test-ref ref.json]

Inputs are dumps written by tools/retarget/dump_clips.gd (skeleton rests, 1-frame bind
pose clips, clip tracks sampled at 30 fps). Output: Actor_B local tracks per clip plus the
source clip's metadata (native_asset_id, original_name, ...) and a `retarget` stamp;
tools/retarget/build_library.gd turns it into an AnimationLibrary. Configs:
prototype_clips.json (the 29-clip prototype, library actor_a_rt) and
actor_b_from_a_clips.json (the production set, library actor_b_from_a; with a
library_name the run also writes checks.py's checks, manifest and Godot test reference).

Method (source/graph_analysis/melee_horse_prone/retarget.md and
actor_b_from_a.md):
 1. Bind poses. Actor_A's true bind pose is the 1-frame clip `bindpose` (asset 792869cd...):
    it equals `null-add` on all 40 channels null-add keys (<= 0.004 deg, 0 mm), it matches
    the constant bone offsets of the clips (156/162 bones within 1 mm) and it makes every
    hinge (knees, elbows, fingers) rotate about one local axis. Actor_B's bind is its built
    Skeleton3D rest (null-add), which is what Godot composes additives against.
 2. Rotations: per bone, the world rotation relative to each rig's bind pose is carried
    over:  R_B = R_A * R_A0^T * Align * R_B0 (Align = identity by default). In local terms
    L_B = K1 * L_A * K2 with constant K1, K2, so the mapping is per bone and works for
    partial (masked) clips. Knees and elbows are projected back onto their hinge axis.
 3. Additive clips: D_A = L_A0^T * add_A; add_B = L_B0 * K2^T * D_A * K2, which makes
    Add2(retarget(base), retarget(add)) == retarget(Add2(base, add)) for every rotation.
 4. Root / pelvis: the pelvis world position is mapped with an anchor map and the root
    translation is solved from it. `ground`: scale by s = hip height B / hip height A about
    the floor point under the character. `horse`: keep the absolute position (saddle frame)
    plus a seat offset calibrated on the native horse idle; where A rises in the stirrups B's
    pelvis follows her own leg length (at most 6 cm). `mount`: the source clip is first moved
    into the saddle frame by a solved ground -> saddle align (contacts.mount_align), then each
    point blends the two maps. A bounded (10 cm) support solve moves the root toward contact
    residuals (knees on the floor, mount grips). The runtime recipe's floor is raised by the
    rider's standing offset (the source stands about 3 cm above its fitted ground), so the planted
    push-off ball is on the floor.
 5. Effectors: hinge-preserving two-bone IK. Each knee and elbow bends only to its own
    flexion side (FLEX_SIGN, measured from the straight limb), may straighten fully, and the
    flexion change the IK adds is smoothed over time, so out-of-reach targets leave a small
    distance residual instead of a locked or reversed joint. Targets keep the limb's own
    proportions: ankles are mapped from the hip by the leg-length ratio k_leg and hands on
    the floor from the shoulder by the arm-length ratio k_arm (s is kept for the pelvis and
    root), with the height taken from the floor mapping near the floor; knees the source
    keeps straight may bend at most 6 deg more. Contacts are detected automatically
    (contacts.py, `contacts: auto`): planted heels / balls and planted hands are locked where
    the plant starts (contacts.plant_lock), knees on the floor, feet in the stirrups, the rein
    hand on the rein line (arm-relative where A reaches with a straight arm), the off hand on
    two-handed weapons. Knees and elbows the source keeps straight may bend at most 6 deg more
    (feet / hands keep a small residual; planted feet and hands, hands near the floor and an off
    hand holding a weapon keep their targets). The wrist bend is limited to the source's own +
    12 deg. Ground clips keep heel, ball and ankle, per frame, no lower than min(the source's
    scaled height, 0) - 0.8 cm (the ankle is lifted where the fold gate or a lunge would scrape a
    foot through the floor).
 6. Hand prop bones are weapon frames, world rotation copied; the grip point is A's offset in
    the palm frame scaled by the hand-length ratio (the offset along a two-handed weapon's
    axis is not scaled). Weapon families get one frame each (weapon_frames.py): Actor_A's
    machete and long-gun frames are converted by a measured constant change of frame; two-handed
    guard clips that key no prop get the weapon where the source's two hands hold it (the axis
    through both hands' grip points, the off hand at the source's placement relative to the right
    hand, the roll from the right palm; synthetic_two_hand); the haft clips (source prop: a round
    pipe, roll never authored) get their roll from the right palm too. A left prop bone that
    follows the right one (one-handed weapons) is recomputed from B's right prop.
 7. Loops: only clips the config marks `loop` (real cycles) loop; `seamless` records whether
    the source's first and last poses match. Real loops get wrap-around smoothing; the seams
    the solve leaves (<= 2 cm / 5 deg per channel) are closed over the last frames and larger
    gaps of the source's own cycle are removed as drift over the whole cycle (prop bones keep
    the source's world rotation).
"""
import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rtmath import Rig, q2m, m2q, q_continuous, axis_angle, rot_between, rot_angle_deg  # noqa: E402
from contacts import (HorseRef, grip_weights, hand_floor_weights, is_loop, knee_contact_weights,  # noqa: E402
                      mount_align, plant_lock, ramp, rein_weights, smooth, stirrup_weights, yaw_matrices)
import weapon_frames  # noqa: E402

TOOL_VERSION = "retarget.py 0.4"  # 0.1 = prototype (actor_a_rt_proto), 0.2 = first actor_b_from_a,
# 0.3 = first review fix pass, 0.4 = second (synthetic grip from both palms, roll, straight elbows, floor, mount floor)
A_BIND_POSE = "bindpose"
A_BIND_ASSET = "792869cd518b2384e05c827bcc09a169d9d23eba88b796053f329a850544260c"

# Bone -> child joint that defines its direction (for Align).
ALIGN_CHILD = {
    "spinea": "spineb", "spineb": "spinec", "spinec": "spined", "spined": "neck", "neck": "heada",
    "l_clavicle": "l_shoulder", "l_shoulder": "l_elbow", "l_elbow": "l_wrist",
    "r_clavicle": "r_shoulder", "r_shoulder": "r_elbow", "r_elbow": "r_wrist",
    "l_upper_leg": "l_knee", "l_knee": "l_ankle", "r_upper_leg": "r_knee", "r_knee": "r_ankle",
}
ALIGN_SETS = {
    "none": [],
    "limbs": ["l_shoulder", "l_elbow", "r_shoulder", "r_elbow", "l_upper_leg", "l_knee", "r_upper_leg", "r_knee"],
    "all": list(ALIGN_CHILD),
}
HINGES = {"l_knee": 0, "r_knee": 0, "l_elbow": 1, "r_elbow": 1}  # local axis index (X / Y)
# Flexion side of each hinge: the signed angle from the straight limb about the joint's hinge
# axis (sign of (upper x lower) . axis). Measured on all 146 non-additive Actor_A clips: elbows
# (local Y) and knees (local X) bend negative on 14.7k / 14.6k of 14.9k frames and never go past
# +3 deg except a fully folded (180 deg) crawl-stop elbow. The bind poses are bent (-16 / -19 deg
# elbows), so the side must not be taken from the rest pose.
FLEX_SIGN = {"l_knee": -1.0, "r_knee": -1.0, "l_elbow": -1.0, "r_elbow": -1.0}
LEGS = {"l": ("l_upper_leg", "l_knee", "l_ankle"), "r": ("r_upper_leg", "r_knee", "r_ankle")}
ARMS = {"l": ("l_shoulder", "l_elbow", "l_wrist"), "r": ("r_shoulder", "r_elbow", "r_wrist")}
PROPS = ("l_hand_prop_attachment", "r_hand_prop_attachment")
FIST = ("_indexa", "_middlea", "_ringa", "_pinkya", "_palm")  # fist centre: the four finger bases and the palm
FOOT_BONES = ("l_ankle", "l_heel", "l_ball", "r_ankle", "r_heel", "r_ball")
# Metadata copied verbatim from the source clip.
META_KEYS = ("native_asset_id", "original_name", "source_names", "sample_rate", "sample_count",
             "source_kind", "additive_source", "complete_stream_start", "conversion",
             "source_library")


# ----------------------------------------------------------------------------- rigs
class RigPair:
    def __init__(self, src, dst, align="limbs"):
        a_bind = src["poses"][A_BIND_POSE]
        assert a_bind["meta"].get("native_asset_id") == A_BIND_ASSET, "unexpected Actor_A bindpose asset"
        self.A = Rig(src["skeleton"]["bones"], a_bind["pose"])
        self.B = Rig(dst["skeleton"]["bones"])
        self.A_null_add = src["poses"].get("null-add", {}).get("pose", {})
        self.PA0, self.RA0 = self.A.bind_fk()
        self.PB0, self.RB0 = self.B.bind_fk()
        A, B = self.A, self.B
        rootA, rootB = A.idx["root"], B.idx["root"]
        # Mapped bones: in both rigs, under root in both, not the per-rig '_offset' drivers.
        self.mapped = [n for n in B.names if n in A.idx and "_offset" not in n
                       and A.is_descendant(A.idx[n], rootA) and B.is_descendant(B.idx[n], rootB)]
        self.mapped_set = set(self.mapped)
        self.set_align(align)
        # Scale factors.
        hipA = 0.5 * (self.PA0[A.idx["l_upper_leg"], 1] + self.PA0[A.idx["r_upper_leg"], 1])
        hipB = 0.5 * (self.PB0[B.idx["l_upper_leg"], 1] + self.PB0[B.idx["r_upper_leg"], 1])
        self.s = hipB / hipA
        self.ankleA = {k: self.PA0[A.idx[k + "_ankle"], 1] for k in "lr"}
        self.ankleB = {k: self.PB0[B.idx[k + "_ankle"], 1] for k in "lr"}
        self.wristA = {k: self.PA0[A.idx[k + "_wrist"], 1] for k in "lr"}
        self.wristB = {k: self.PB0[B.idx[k + "_wrist"], 1] for k in "lr"}
        # hand length ratio (wrist -> middle finger base) for grip / prop offsets
        self.k_hand = float(np.mean([np.linalg.norm(self.PB0[B.idx[k + "_middlea"]] - self.PB0[B.idx[k + "_wrist"]]) /
                                     np.linalg.norm(self.PA0[A.idx[k + "_middlea"]] - self.PA0[A.idx[k + "_wrist"]]) for k in "lr"]))
        neckA, neckB = self.PA0[A.idx["neck"], 1], self.PB0[B.idx["neck"], 1]
        self.stature_ratio = neckB / neckA

        # limb length ratios (bind segment lengths): hip -> knee -> ankle, shoulder -> elbow -> wrist.
        # s (hip height) includes Actor_A's 11.7 cm ankle height and B's torso is only 0.785x
        # A's, so neither leg nor arm targets should use s: 0.9455 and 0.904 here.
        def chain_len(P0, R, a, b, c):
            return (np.linalg.norm(P0[R.idx[b]] - P0[R.idx[a]]) + np.linalg.norm(P0[R.idx[c]] - P0[R.idx[b]]))
        self.k_leg = float(np.mean([chain_len(self.PB0, B, *LEGS[k]) / chain_len(self.PA0, A, *LEGS[k]) for k in "lr"]))
        self.k_arm = float(np.mean([chain_len(self.PB0, B, *ARMS[k]) / chain_len(self.PA0, A, *ARMS[k]) for k in "lr"]))

    def set_align(self, mode):
        """none: pure bind-relative. limbs / all: also turn B's bind bone direction onto A's
        (minimal rotation). frame / frame_all: full-frame alignment Al = R_A0 R_B0^T, which
        makes L_B = L_A (the rigs share per-bone axis conventions, so this is a joint-angle
        copy); `frame` keeps the feet (ankle, heel, ball) bind-relative so a flat foot stays
        flat on B's different foot geometry."""
        A, B = self.A, self.B
        self.align_mode = mode
        self.Al = {n: np.eye(3) for n in self.mapped}
        if mode in ("frame", "frame_all"):
            for n in self.mapped:
                if n in PROPS or (mode == "frame" and n in FOOT_BONES):
                    continue
                self.Al[n] = self.RA0[A.idx[n]] @ self.RB0[B.idx[n]].T
        else:
            for n in ALIGN_SETS[mode]:
                c = ALIGN_CHILD[n]
                dA = self.PA0[A.idx[c]] - self.PA0[A.idx[n]]
                dB = self.PB0[B.idx[c]] - self.PB0[B.idx[n]]
                self.Al[n] = rot_between(dB, dA)
        # Per-bone constants: R_B = R_A * C_post[b] where C_post = R_A0^T Al R_B0,
        # and K1 (parent-frame map for translations / additives).
        self.C_post = {}
        self.K1 = {}
        for n in self.mapped:
            ia, ib = A.idx[n], B.idx[n]
            # Hand prop bones are weapon frames with one convention in both rigs (a held
            # pistol: both world frames ~identity, 9.6 deg apart; bind-relative would be
            # 68 deg off), so their world rotation is copied as is.
            self.C_post[n] = np.eye(3) if n in PROPS else self.RA0[ia].T @ self.Al[n] @ self.RB0[ib]
            pa, pb = A.parent[ia], B.parent[ib]
            pn = B.names[pb] if pb >= 0 else None
            if pn is not None and pn in self.mapped_set:
                self.K1[n] = self.RB0[pb].T @ self.Al[pn].T @ self.RA0[A.idx[pn]]
            elif pb < 0 and pa < 0:
                self.K1[n] = np.eye(3)
            else:
                self.K1[n] = (self.RB0[pb].T @ self.RA0[pa]) if (pa >= 0 and pb >= 0) else np.eye(3)
        self.K2 = {n: self.C_post[n] for n in self.mapped}


# ----------------------------------------------------------------------------- helpers
def keyed_channels(tracks):
    return {b: set(ch.keys()) for b, ch in tracks.items()}


def weight_curve(keys, F, default):
    """Piecewise-linear (smoothstepped) weights from [[frame, w], ...]."""
    if not keys:
        return np.full(F, float(default))
    keys = sorted(keys)
    f = np.arange(F, dtype=float)
    xs = np.array([k[0] for k in keys], float)
    ys = np.array([k[1] for k in keys], float)
    w = np.interp(f, xs, ys)
    # smoothstep inside each segment
    out = w.copy()
    for i in range(len(xs) - 1):
        m = (f >= xs[i]) & (f <= xs[i + 1]) & (xs[i + 1] > xs[i])
        u = (f[m] - xs[i]) / (xs[i + 1] - xs[i])
        u = u * u * (3 - 2 * u)
        out[m] = ys[i] + (ys[i + 1] - ys[i]) * u
    return out


def slerp_m(Ra, Rb, w):
    """Per-frame slerp between rotation matrices (F,3,3) with weights w (F,)."""
    w = np.asarray(w, float)
    if np.all(w >= 1 - 1e-9):
        return Rb
    if np.all(w <= 1e-9):
        return Ra
    qa, qb = m2q(Ra), m2q(Rb)
    d = np.sum(qa * qb, 1)
    qb = np.where(d[:, None] < 0, -qb, qb)
    d = np.abs(d)
    th = np.arccos(np.clip(d, -1, 1))
    sn = np.sin(th)
    small = sn < 1e-6
    wa = np.where(small, 1 - w, np.sin((1 - w) * th) / np.where(small, 1, sn))
    wb = np.where(small, w, np.sin(w * th) / np.where(small, 1, sn))
    return q2m(wa[:, None] * qa + wb[:, None] * qb)


def aim_thigh(rig, GP, GR, L, hip, knee, target, w):
    """Swing the thigh about the hip (knee hinge and shin kept) so the knee moves toward
    `target` (reach-limited), blended by w (F,). Used for knee floor contacts: the knee,
    not the ankle, is the support, and Actor_B's shorter thigh / longer shin would otherwise
    leave the knee in the air or push it through the floor. Modifies L in place."""
    d0 = GP[:, knee] - GP[:, hip]
    d1 = target - GP[:, hip]
    S = rot_between(d0, d1)
    if np.any(w < 1 - 1e-9):
        S = slerp_m(np.repeat(np.eye(3)[None], len(w), 0), S, w)
    new_GR = S @ GR[:, hip]
    par = rig.parent[hip]
    L[:, hip] = np.einsum("fji,fjk->fik", GR[:, par], new_GR)


def knee_swivel(rig, GP, GR, L, hip, knee, ankle, ty, w, loop, max_deg=45.0, sigma=2.0):
    """Knee floor contact with the foot held: turn the leg about the hip->ankle axis (the
    swivel) so the knee comes down to height ty; the ankle stays on its IK target and the
    foot keeps its world orientation. The swivel is limited to +-max_deg, weighted by w and
    smoothed; returns the knee height residual (F,) left for the root solve."""
    H, K, An = GP[:, hip], GP[:, knee], GP[:, ankle]
    a = An - H
    a = a / np.maximum(np.linalg.norm(a, axis=1, keepdims=True), 1e-9)
    kh = K - H
    along = np.sum(kh * a, 1, keepdims=True) * a
    k = kh - along
    c = H[:, 1] + along[:, 1]
    p = k[:, 1]
    q = np.cross(a, k)[:, 1]
    R = np.sqrt(p * p + q * q) + 1e-12
    base = np.arctan2(q, p)
    x = np.clip((ty - c) / R, -1, 1)
    d = np.arccos(x)
    c1 = (base + d + np.pi) % (2 * np.pi) - np.pi
    c2 = (base - d + np.pi) % (2 * np.pi) - np.pi
    phi = np.where(np.abs(c1) < np.abs(c2), c1, c2)
    lim = np.radians(max_deg)
    phi = np.clip(phi, -lim, lim) * w
    phi = smooth(phi, sigma, loop)
    S = axis_angle(a, phi)
    par = rig.parent[hip]
    old_knee_R, old_ankle_R = GR[:, knee].copy(), GR[:, ankle].copy()
    new_hip_R = S @ GR[:, hip]
    L[:, hip] = np.einsum("fji,fjk->fik", GR[:, par], new_hip_R)
    new_knee_R = S @ old_knee_R
    L[:, ankle] = np.einsum("fji,fjk->fik", new_knee_R, old_ankle_R)
    newK = H + np.einsum("fij,fj->fi", S, kh)
    return ty - newK[:, 1]


def hinge_project(Lb0, L, axis_idx):
    """Keep only the twist of Lb0^T L about the local hinge axis (swing-twist)."""
    rel = np.einsum("ij,fjk->fik", Lb0.T, L)
    q = m2q(rel)
    ax = np.zeros(3)
    ax[axis_idx] = 1.0
    proj = np.sum(q[:, :3] * ax[None], axis=1)
    tw = np.concatenate([proj[:, None] * ax[None], q[:, 3:4]], axis=1)
    nrm = np.linalg.norm(tw, axis=1, keepdims=True)
    tw = np.where(nrm > 1e-9, tw / np.maximum(nrm, 1e-12), np.array([0, 0, 0, 1.0]))
    swing_deg = rot_angle_deg(np.einsum("fij,fjk->fik", np.transpose(q2m(tw), (0, 2, 1)), rel))
    return np.einsum("ij,fjk->fik", Lb0, q2m(tw)), swing_deg


def fold_gate(GP, chain, target, lengths, lo=0.25, hi=0.5):
    """IK weight multiplier for folded limbs. When the root->effector distance is a small
    fraction of the limb length (deep kneel, sitting on the heel, fist at the shoulder), the
    direction root->target swings wildly with a few cm of target motion and any analytic
    two-bone solution flips from frame to frame; the bind-relative (FK) pose is kept there
    instead. 0 below lo * (l1 + l2), 1 above hi * (l1 + l2), smoothstep between."""
    a, b, c = chain
    tot = lengths[0] + lengths[1]
    ext = np.minimum(np.linalg.norm(target - GP[:, a], axis=1), np.linalg.norm(GP[:, c] - GP[:, a], axis=1)) / tot
    u = np.clip((ext - lo) / (hi - lo), 0, 1)
    return u * u * (3 - 2 * u)


def two_bone_ik(rig, GP, GR, L, chain, hinge_idx, target, end_rot=None, flex_sign=-1.0, loop=False, flex_smooth=0.75,
                gate=None, flex_cap=None):
    """Hinge-preserving two-bone IK on world pose arrays (modified in place).
    chain = (a, b, c) bone indices; target (F,3). Returns the residual distance (F,) to the
    requested target.

    The middle joint turns only about its own hinge axis. Measured from the straight limb, the
    two solutions for a target distance are +-base; the one on the joint's flexion side
    (flex_sign, FLEX_SIGN) is always taken, so a knee or elbow never bends backwards and never
    swaps sides between frames. A target beyond reach straightens the limb completely (flexion 0)
    and leaves a distance residual; there is no reach clamp that forces a minimum bend. The
    flexion change the IK adds to the forward-kinematics pose is smoothed over time
    (flex_smooth frames, loop-aware), because near full extension the flexion needed changes very
    fast with the distance (about 23 deg per cm on an arm): the limb then trails the target by a
    few mm instead of snapping. `gate` (F,) in [0, 1] fades the whole solve out (folded limbs,
    fold_gate): at 0 the limb keeps its forward-kinematics pose, because with the effector within a
    few cm of the root the root -> target direction is meaningless and swings the limb.
    `flex_cap` (F,) caps the flexion magnitude (rad): where the source limb is straight the target
    may still ask for a bend (proportions), and the limb then stays straight with a residual."""
    target_in = target
    a, b, c = chain
    A, Bp, C = GP[:, a], GP[:, b], GP[:, c]
    ax = GR[:, b, :, hinge_idx]
    ax = ax / np.linalg.norm(ax, axis=1, keepdims=True)
    w = C - Bp
    w_par = np.sum(w * ax, 1, keepdims=True) * ax
    w_perp = w - w_par
    u = Bp - A
    d = np.linalg.norm(target - A, axis=1)
    # |u + Rot(ax, th) w|^2 = K + P cos th + Q sin th = K + Rr cos(th - phi): the limb is straight
    # (longest) at th = phi, and the signed flexion from straight is th - phi
    K = np.sum(u * u, 1) + np.sum(w * w, 1) + 2 * np.sum(u * w_par, 1)
    P = 2 * np.sum(u * w_perp, 1)
    Qv = 2 * np.sum(u * np.cross(ax, w_perp), 1)
    Rr = np.sqrt(P * P + Qv * Qv) + 1e-12
    phi = np.arctan2(Qv, P)
    base = np.arccos(np.clip((d * d - K) / Rr, -1, 1))  # 0 = straight (target at or beyond reach)
    if flex_cap is not None:
        base = np.minimum(base, flex_cap)
    flex_ik = flex_sign * base
    flex_fk = (-phi + np.pi) % (2 * np.pi) - np.pi  # flexion of the pose the limb has now (th = 0)
    th = (flex_ik - flex_fk + np.pi) % (2 * np.pi) - np.pi
    if flex_smooth > 0 and len(th) > 2:
        th = smooth(np.unwrap(th), flex_smooth, loop)
        th = (th + np.pi) % (2 * np.pi) - np.pi
    # never past straight (the smoothing must not carry a joint over it either); a fully folded
    # joint (|flexion| near 180 deg, where the sign is meaningless) is left alone
    flex = (flex_fk + th + np.pi) % (2 * np.pi) - np.pi
    th = np.where((flex_sign * flex < 0) & (np.abs(flex) < np.pi / 2), -flex_fk, th)
    if gate is not None:
        th = th * gate
    Rb = axis_angle(ax, th)
    C1 = Bp + np.einsum("fij,fj->fi", Rb, w)
    S = rot_between(C1 - A, target - A)
    if gate is not None and np.any(gate < 1 - 1e-9):
        S = slerp_m(np.repeat(np.eye(3)[None], len(gate), 0), S, gate)
    # keep the swivel: turn the chain about the root->target axis so the knee / elbow keeps
    # pointing where it pointed before. The reference is the joint's hinge axis: it stays
    # well defined when the limb is almost straight, where the knee position itself is no
    # usable pole and flips from frame to frame. (Folded limbs are handled by the caller:
    # see fold_gate.)
    ut = target - A
    ut = ut / np.maximum(np.linalg.norm(ut, axis=1, keepdims=True), 1e-9)

    def swivel_to(p_old_vec, p_new_vec, tol):
        po = p_old_vec - np.sum(p_old_vec * ut, 1, keepdims=True) * ut
        pn = p_new_vec - np.sum(p_new_vec * ut, 1, keepdims=True) * ut
        ok_ = (np.linalg.norm(po, axis=1) > tol) & (np.linalg.norm(pn, axis=1) > tol)
        sg = np.sign(np.sum(np.cross(pn, po) * ut, 1))
        cv = np.sum(pn * po, 1) / np.maximum(np.linalg.norm(pn, axis=1) * np.linalg.norm(po, axis=1), 1e-12)
        return np.where(ok_, sg * np.arccos(np.clip(cv, -1, 1)), 0.0), po

    phi_s, _ = swivel_to(ax, np.einsum("fij,fj->fi", S, ax), 1e-3)
    if gate is not None:
        phi_s = phi_s * gate
    S = axis_angle(ut, phi_s) @ S
    new_GRa = S @ GR[:, a]
    new_GRb = S @ Rb @ GR[:, b]
    new_Pb = A + np.einsum("fij,fj->fi", S, u)
    new_Pc = A + np.einsum("fij,fj->fi", S, C1 - A)
    new_GRc = end_rot if end_rot is not None else GR[:, c]
    pa = rig.parent[a]
    L[:, a] = np.einsum("fji,fjk->fik", GR[:, pa], new_GRa)
    L[:, b] = np.einsum("fji,fjk->fik", new_GRa, new_GRb)
    L[:, c] = np.einsum("fji,fjk->fik", new_GRb, new_GRc)
    GR[:, a], GR[:, b], GR[:, c] = new_GRa, new_GRb, new_GRc
    GP[:, b], GP[:, c] = new_Pb, new_Pc
    return np.linalg.norm(new_Pc - target_in, axis=1)


# ----------------------------------------------------------------------------- retarget
def smooth_linear(x, w, sigma, loop=False):
    """Weighted, locally linear Gaussian smoothing along axis 0 of x (F, k) with per-frame weights w (F,):
    each frame gets the value at that frame of a weighted straight-line fit over its neighbourhood, so a
    trend at the start or end of the weighted frames is followed without the lag of a weighted mean.
    Frames with too little weighted support fall back to the weighted mean."""
    x = np.asarray(x, float)
    w = np.asarray(w, float)
    F = len(x)
    r = max(int(np.ceil(3 * sigma)), 1)
    offs = np.arange(-r, r + 1)
    g = np.exp(-0.5 * (offs / max(sigma, 1e-6)) ** 2)
    n = F - 1 if (loop and F > 2) else F
    S = np.zeros((F, 3))
    T0 = np.zeros_like(x)
    T1 = np.zeros_like(x)
    for o, gk in zip(offs, g):
        j = np.arange(F) + o
        if loop and F > 2:
            j = j % n
            valid = np.ones(F, bool)
        else:
            valid = (j >= 0) & (j < F)
            j = np.clip(j, 0, F - 1)
        wk = gk * w[j] * valid
        S[:, 0] += wk
        S[:, 1] += wk * o
        S[:, 2] += wk * o * o
        T0 += wk[:, None] * x[j]
        T1 += (wk * o)[:, None] * x[j]
    det = S[:, 0] * S[:, 2] - S[:, 1] ** 2
    mean = T0 / np.maximum(S[:, 0], 1e-12)[:, None]
    lin = (S[:, 2, None] * T0 - S[:, 1, None] * T1) / np.where(np.abs(det) > 1e-9, det, 1.0)[:, None]
    ok = (det > 0.05 * np.maximum(S[:, 0], 1e-12) ** 2) & (S[:, 0] > 1e-6)
    out = np.where(ok[:, None], lin, mean)
    if loop and F > 2:
        out[-1] = out[0]
    return out


def bridge_gaps(mask, allowed, max_gap):
    """Fill runs of False in `mask` no longer than max_gap frames that lie between True runs and
    where `allowed` holds on every frame of the gap."""
    m = np.asarray(mask, bool).copy()
    F = len(m)
    f = 0
    while f < F:
        if m[f]:
            f += 1
            continue
        g = f
        while g < F and not m[g]:
            g += 1
        if f > 0 and g < F and g - f <= max_gap and np.all(allowed[f:g]):
            m[f:g] = True
        f = g
    return m


def wrist_swing_deg(GR, rig, rest_R0, side):
    """Swing (deg) of the wrist relative to the forearm, measured from the bind pose: the rotation of
    the wrist's local frame away from its bind, with the twist about the forearm (local Z) removed."""
    e, w = rig.idx[side + "_elbow"], rig.idx[side + "_wrist"]
    L = np.einsum("fji,fjk->fik", GR[:, e], GR[:, w])
    L0 = rest_R0[e].T @ rest_R0[w]
    q = m2q(np.einsum("fij,kj->fik", L, L0))
    tw = np.stack([np.zeros(len(q)), np.zeros(len(q)), q[:, 2], q[:, 3]], -1)
    tw /= np.maximum(np.linalg.norm(tw, axis=1, keepdims=True), 1e-9)
    return np.degrees(2 * np.arccos(np.clip(np.abs(q[:, 3] * tw[:, 3] + q[:, 2] * tw[:, 2]), 0, 1)))


def limit_wrist_swing(rig, PB, LB, side, ref_deg, margin_deg, loop, keep_world=()):
    """Limit the wrist swing (wrist_swing_deg) to ref_deg + margin_deg (ref: the source's own swing),
    keeping the twist. The IK keeps each hand's world orientation (reins, grips, the forward-kinematics
    hand), so where Actor_B's forearm points elsewhere than Actor_A's the wrist can bend far more than
    the source's. The reduction factor is smoothed over time. Bones in keep_world (the hand's prop
    bones) keep their world transform. Returns the largest reduction (deg)."""
    GP, GR = rig.fk(PB, LB)
    w = rig.idx[side + "_wrist"]
    L0 = rig.rest_R[w]
    D = np.einsum("fij,kj->fik", LB[:, w], L0)
    q = m2q(D)
    q = np.where(q[:, 3:4] < 0, -q, q)
    tw = np.stack([np.zeros(len(q)), np.zeros(len(q)), q[:, 2], q[:, 3]], -1)
    tw /= np.maximum(np.linalg.norm(tw, axis=1, keepdims=True), 1e-9)
    Tm = q2m(tw)
    Sm = np.einsum("fij,fkj->fik", D, Tm)  # swing = D T^T
    th = np.degrees(np.arccos(np.clip((np.trace(Sm, axis1=1, axis2=2) - 1) / 2, -1, 1)))
    lim = np.asarray(ref_deg, float) + margin_deg
    k = np.where(th > lim, lim / np.maximum(th, 1e-9), 1.0)
    if k.min() > 1 - 1e-6:
        return 0.0
    k = np.minimum(k, smooth(k, 1.5, loop))  # widened: the reduction eases in and out
    Sk = slerp_m(np.repeat(np.eye(3)[None], len(k), 0), Sm, k)
    saved = {b: (GP[:, rig.idx[b]].copy(), GR[:, rig.idx[b]].copy()) for b in keep_world}
    LB[:, w] = np.einsum("fij,fjk,kl->fil", Sk, Tm, L0)
    if saved:
        GP2, GR2 = rig.fk(PB, LB)
        for b, (gp, gr) in saved.items():
            i = rig.idx[b]
            par = rig.parent[i]
            LB[:, i] = np.einsum("fji,fjk->fik", GR2[:, par], gr)
            PB[:, i] = np.einsum("fji,fj->fi", GR2[:, par], gp - GP2[:, par])
    return float((th * (1 - k)).max())


def close_loop_seams(tracks, n_frames=8, pos_tol=0.02, rot_tol_deg=5.0, exact=()):
    """Close the seam of a real loop (first vs last key) on every channel, so the cycle plays
    without a pop. Small gaps (<= pos_tol / rot_tol_deg: what the solve leaves) are closed by a
    correction spread over the last n_frames (smoothstep). Larger gaps are the source's own (the
    source cycle does not close, e.g. a leg 6 deg off after a turning walk cycle, a finger that
    snaps back); they are removed as drift, linearly over the whole cycle, which changes any frame
    by at most the gap. Bones in `exact` (the hand prop bones, whose world rotation is the source's)
    are only closed when the gap is below 0.5 deg / 2 mm. Returns {closed_small, closed_drift,
    left, max_pos_cm, max_rot_deg (small), drift_max_pos_cm, drift_max_rot_deg}."""
    small = drift = left = 0
    mp = mr = dp = dr = 0.0
    for bn, t in tracks.items():
        for ch in t:
            arr = np.asarray(t[ch], float)
            F = len(arr)
            if F < 3:
                continue
            if ch == "rot":
                q0, q1 = arr[0].copy(), arr[-1]
                if float(np.sum(q0 * q1)) < 0:
                    q0 = -q0
                ang = float(np.degrees(2 * np.arccos(np.clip(abs(float(np.sum(q0 * q1))), 0, 1))))
                big = ang > rot_tol_deg
            else:
                gap = arr[0] - arr[-1]
                ang = float(np.linalg.norm(gap))
                big = ang > pos_tol
            if bn in exact and ang > (0.5 if ch == "rot" else 0.002):
                left += 1
                continue
            if big:
                u = np.linspace(0.0, 1.0, F)  # drift removal over the whole cycle
                idx = np.arange(F)
            else:
                n = min(n_frames, F - 1)
                u = np.linspace(0.0, 1.0, n + 1)[1:]
                u = u * u * (3 - 2 * u)
                idx = np.arange(F - n, F)
            if ch == "rot":
                qg = m2q(q2m(q0) @ q2m(q1).T)  # delta taking the last key onto the first
                if qg[3] < 0:
                    qg = -qg
                for k, uk in zip(idx, u):
                    qk = np.array([0, 0, 0, 1.0]) * (1 - uk) + qg * uk
                    qi = m2q(q2m(qk / np.linalg.norm(qk)) @ q2m(arr[k]))
                    if float(np.sum(qi * arr[k])) < 0:
                        qi = -qi
                    arr[k] = qi
                arr[-1] = q0
                if big:
                    dr = max(dr, ang)
                else:
                    mr = max(mr, ang)
            else:
                arr[idx] += u[:, None] * gap[None]
                arr[-1] = arr[0]
                if big:
                    dp = max(dp, ang)
                else:
                    mp = max(mp, ang)
            t[ch] = np.round(arr, 7).tolist()
            if big:
                drift += 1
            else:
                small += 1
    return {"closed_small": small, "closed_drift": drift, "left": left, "max_pos_cm": round(mp * 100, 3), "max_rot_deg": round(mr, 3),
            "drift_max_pos_cm": round(dp * 100, 3), "drift_max_rot_deg": round(dr, 3)}


class Retargeter:
    def __init__(self, pair: RigPair, seat_offset=(0.0, 0.0, 0.0), effector_offset=(0.0, 0.0, 0.0),
                 stirrup_offset=None, horse=None, weapon=None):
        self.p = pair
        self.horse = horse  # contacts.HorseRef (stirrups, rein line) for contacts: auto
        self.src = None     # source dump (set by run(); used for cross-clip grip references)
        # seat_offset moves the pelvis on the saddle (rider anatomy). Reins are on the horse,
        # so hand targets in the seat frame keep A's absolute positions (+ effector_offset).
        # stirrup_offset (per side) moves the ankle targets in the seat frame to where
        # Actor_B's own riding clips put her feet (stirrups set for her shorter legs).
        self.seat_offset = np.asarray(seat_offset, float)
        self.effector_offset = np.asarray(effector_offset, float)
        so = stirrup_offset or {}
        self.stirrup_offset = {k: np.asarray(so.get(k, effector_offset), float) for k in "lr"}
        self.weapon = weapon or {}  # weapon_frames.measure(): per-family frame conversions
        self.ground_origin = np.zeros(3)  # floor point the ground map scales about (per clip)
        tw = self.weapon.get("two_hand")
        # canonical grips of both hands on a two-handed weapon, expressed for Actor_B's palms
        # (weapon_frames.two_hand_for_b): the synthetic frame of the guard clips is built from them
        self.grips_B = weapon_frames.two_hand_for_b(tw, pair.C_post, pair.k_hand) if tw is not None else None

    # anchor map of points: w=1 ground (scaled about the floor point), w=0 seat (absolute + offset)
    def map_points(self, X, w, offset=None, y_shift=None):
        s = self.p.s
        off = self.seat_offset if offset is None else np.asarray(offset, float)
        o = self.ground_origin
        g = o[None] + (X - o[None]) * s
        if y_shift is not None:
            g = g.copy()
            g[:, 1] += y_shift
        return w[:, None] * g + (1 - w[:, None]) * (X + off[None])

    def convert_weapon_frame(self, family, keyed, P, R, GP, GR):
        """Constant change of the keyed prop frames into the library's frame for `family`
        (weapon_frames.py). The left prop bone is converted too when it rides on the right one
        (one-handed weapons), so their relative transform is kept."""
        fam = self.weapon.get(family)
        if not fam:
            return None
        A = self.p.A
        lp, rp = PROPS
        if rp not in keyed or "rot" not in keyed[rp]:
            return None
        done = [rp]
        weapon_frames.convert(GP, GR, P, R, A, rp, fam["D"], fam["t"])
        if lp in keyed and "rot" in keyed[lp]:
            if float(np.median(np.linalg.norm(GP[:, A.idx[lp]] - GP[:, A.idx[rp]], axis=1))) < 0.05 + float(np.linalg.norm(fam["t"])):
                weapon_frames.convert(GP, GR, P, R, A, lp, fam["D"], fam["t"])
                done.append(lp)
        rec = {"family": family, "bones": done}
        rec.update(weapon_frames.as_record(fam))
        return rec

    def grip_ref_pose(self, clip_name, main_prop, palm, family=None):
        """Median off-palm position in the main prop frame of another clip (e.g. the intro
        of a hit clip), so both halves of a chain decide 'grip held' against the same point."""
        if not clip_name or self.src is None or clip_name not in self.src["clips"]:
            return None
        c = self.src["clips"][clip_name]
        P, R, GP, GR = self.source_pose(c)
        if family:
            self.convert_weapon_frame(family, keyed_channels(c["tracks"]), P, R, GP, GR)
        A = self.p.A
        rel = np.einsum("fji,fj->fi", GR[:, A.idx[main_prop]], GP[:, A.idx[palm]] - GP[:, A.idx[main_prop]])
        return np.median(rel, axis=0)

    def synthetic_two_hand(self, GPA, GRA, loop, cfg, span_delta=0.0):
        """The weapon frame of a two-handed clip that keys no prop (the guard clips),
        inferred from where Actor_A's two hands put the haft.

        Grip points: each palm plus the haft clips' grip point offset (weapon_frames: the palm
        projected onto the keyed haft axis). In the keyed haft clips the line through the two grip
        points lies 3-10 deg (median) from the keyed axis, the line through the fist centres 20-38 deg,
        so the grip points are what locate the haft.
        - Two-handed frames (A's fist span <= synthetic_grip_max_span_m, 0.5 m; fading out by 0.65 m):
          the off hand keeps the source's placement relative to the right hand, scaled by s (`pull`).
        - Held frames (`held`): the source's left grip also lies within 4-7 cm of where a rigid haft
          through the right grip puts it (the hand is on the haft, not letting go). There the weapon
          axis is A's right -> left grip line expressed in the right palm (smoothed over
          synthetic_grip_smooth_frames, weighted by how well the direction is defined), so in the
          world the haft runs where the source's hands hold it and the grip in the right hand is the
          source's, not the haft clips' bat grip; the left grip point is on that axis at A's grip
          span times s from the right one. The roll comes from the right palm (minimal swing of the
          canonical right-hand grip) and the prop origin lies grip_l z (0.075 m) below the left grip.
        - One-handed frames: the in-palm grip eases to the canonical right-hand grip
          (`synthetic_grip_one_hand`: `canonical`, the default: in atk-pipe-block's one-handed recoil
          the block grip would point a 1.8 m spear backwards and 0.55 m into the floor), or is
          interpolated between the grips at the release and at the regrab (`hold`).

        Returns {"prop", "M" (F,3,3), "p" (F,3): the prop's local transform in B's right palm frame,
        "held", "pull" (F,) weights, "rel" (F,3): A's left grip minus right grip (world), "zl", "diag"}."""
        p, A = self.p, self.p.A
        tw = self.weapon["two_hand"]
        gB = self.grips_B
        F = GPA.shape[0]
        gA = {s: GPA[:, A.idx[s + "_palm"]] + np.einsum("fij,j->fi", GRA[:, A.idx[s + "_palm"]],
                                                         np.asarray(tw["grip_%s_point" % s], float)) for s in "lr"}
        fist = {s: GPA[:, [A.idx[s + x] for x in ("_indexa", "_middlea", "_ringa", "_pinkya", "_palm")]].mean(1) for s in "lr"}
        fspan = np.linalg.norm(fist["r"] - fist["l"], axis=1)
        d = gA["r"] - gA["l"]
        span = np.linalg.norm(d, axis=1)
        Ra = GRA[:, A.idx["r_palm"]]
        zA_in = np.einsum("fji,fj->fi", Ra, d / np.maximum(span, 1e-9)[:, None])
        Cp = p.C_post["r_palm"]
        z_in = zA_in @ Cp  # the same world direction in B's right palm frame (B palm = A palm * C_post)
        max_span = float(cfg.get("synthetic_grip_max_span_m", 0.5))
        both = (fspan <= max_span).astype(float)
        pull0 = np.clip((max_span + 0.15 - fspan) / 0.15, 0.0, 1.0)
        pull = np.clip(np.maximum(pull0, smooth(pull0, 1.5, loop)), 0.0, 1.0)
        sig = float(cfg.get("synthetic_grip_smooth_frames", 0.75))

        def axis_from(conf):
            # locally linear (no lag where the source's grip turns fast at the start / end of a hold)
            num = smooth_linear(z_in, conf, sig, loop)
            den = smooth(conf, sig, loop)
            z = num / np.maximum(np.linalg.norm(num, axis=1, keepdims=True), 1e-9)
            sp = smooth_linear(span[:, None], conf, sig, loop)[:, 0]
            return z, sp, den

        def rigid_dev(z, sp):
            # A's left grip against where a rigid haft (direction z in the right palm, span sp) puts it
            zw = np.einsum("fij,fj->fi", Ra, z @ Cp.T)
            return np.linalg.norm(gA["l"] - (gA["r"] - sp[:, None] * zw), axis=1)

        dir_ok = np.clip((span - 0.06) / 0.06, 0.0, 1.0)  # the direction is undefined when the grips meet
        on = both
        if cfg.get("synthetic_grip_rigid", False):  # optional: only where the left grip stays on a rigid haft
            z_s, span_s, den = axis_from(both * dir_ok)
            for _ in range(2):
                on = both * np.clip((0.07 - rigid_dev(z_s, span_s)) / 0.03, 0.0, 1.0)
                z_s, span_s, den = axis_from(on * dir_ok)
        z_s, span_s, den = axis_from(on * dir_ok)
        held = np.clip(np.maximum(on, smooth(on, 1.0, loop)), 0.0, 1.0)
        # the left grip at A's grip span x s from the right one, plus span_delta (Actor_B's shorter reach:
        # retarget() sets it from B's own mapped hands, within +-3.5 cm); grip points never closer than
        # 0.12 m along the haft (the fists, about 8 cm across, would overlap)
        span_t = np.maximum(p.s * span_s + span_delta, float(cfg.get("synthetic_grip_min_span_m", 0.12)))
        zl = float(gB["l"]["pos"][2])
        Mc, pc = weapon_frames.right_fist(gB)
        defined = den > 0.5
        M2 = np.einsum("fij,jk->fik", rot_between(np.broadcast_to(Mc[:, 2], z_s.shape), z_s), Mc)
        p2 = np.asarray(gB["r"]["point"], float)[None] - (zl + span_t)[:, None] * z_s
        mode = cfg.get("synthetic_grip_one_hand", "canonical")
        defined = defined & (on > 0.5)
        idx = np.flatnonzero(defined)
        if not defined.any():
            M, pp = np.repeat(Mc[None], F, 0), np.repeat(pc[None], F, 0)
        elif mode == "hold":
            # one-handed frames: interpolate the in-palm grip between the release and the regrab
            M, pp = M2.copy(), p2.copy()
            q2 = q_continuous(m2q(M2))
            for f in np.flatnonzero(~defined):
                lo, hi = idx[idx < f], idx[idx > f]
                if len(lo) == 0 or len(hi) == 0:
                    j = hi[0] if len(lo) == 0 else lo[-1]
                    M[f], pp[f] = M2[j], p2[j]
                    continue
                f0, f1 = lo[-1], hi[0]
                u = (f - f0) / float(f1 - f0)
                u = u * u * (3 - 2 * u)
                qa, qb = q2[f0], q2[f1]
                if float(qa @ qb) < 0:
                    qb = -qb
                qq = (1 - u) * qa + u * qb
                M[f] = q2m(qq / np.linalg.norm(qq))
                pp[f] = (1 - u) * p2[f0] + u * p2[f1]
        else:
            # one-handed frames: ease to the canonical right-hand grip over synthetic_grip_ease_frames
            # after the off hand lets go (and back before it takes hold again)
            M2f, p2f = M2.copy(), p2.copy()
            wg = np.ones(F)
            n_ease = float(cfg.get("synthetic_grip_ease_frames", 12))
            for f in np.flatnonzero(~defined):
                j = idx[np.argmin(np.abs(idx - f))]
                M2f[f], p2f[f] = M2[j], p2[j]
                u = min(abs(f - j) / n_ease, 1.0)
                wg[f] = 1.0 - u * u * (3 - 2 * u)
            M = slerp_m(np.repeat(Mc[None], F, 0), M2f, wg)
            pp = pc[None] + wg[:, None] * (p2f - pc[None])
        rel_can = np.degrees(np.arccos(np.clip(np.einsum("fi,i->f", M[:, :, 2], Mc[:, 2]), -1, 1)))
        hm = held > 0.9
        diag = {"prop": PROPS[1], "method": "weapon axis from both source palms (grip points), roll from the right palm",
                "one_hand_frames": mode, "held_fraction": round(float(hm.mean()), 3),
                "two_hand_fraction": round(float((fspan <= max_span).mean()), 3),
                "fist_span_m": [round(float(fspan.min()), 3), round(float(fspan.max()), 3)],
                "grip_span_m": [round(float(span_t[hm].min()), 3), round(float(span_t[hm].max()), 3)] if hm.any() else None,
                "in_palm_vs_canonical_grip_deg": [round(float(x), 1) for x in np.percentile(rel_can, [0, 50, 100])]}
        # the off hand's placement relative to the right grip point (world, B scale): A's scaled by s, with
        # the span along the haft changed like span_t
        u = -d / np.maximum(span, 1e-9)[:, None]
        rel = -p.s * d + (span_t - p.s * span_s)[:, None] * u
        diag["span_delta_m"] = round(float(span_delta), 4)
        return {"prop": PROPS[1], "M": M, "p": pp, "held": held, "pull": pull, "rel": rel, "zl": zl, "z_in": z_s,
                "span_t": span_t, "diag": diag}

    def synth_wrist_target(self, synth, GPB, GRB, c, end_rot):
        """Left wrist target (F,3) with the hand at world rotation end_rot, for a synthetic two-handed
        frame: the left grip point at the source's placement relative to the right grip point (scaled
        by s), and while the hand holds (`held`) at its place on the weapon (grip_l z up the axis from
        the prop origin; the two agree within 4-7 cm x s there)."""
        B = self.p.B
        ibM, ibP, ibR = B.idx[synth["prop"]], B.idx["l_palm"], B.idx["r_palm"]
        on_axis = GPB[:, ibM] + synth["zl"] * GRB[:, ibM, :, 2]
        grip_r = GPB[:, ibR] + np.einsum("fij,j->fi", GRB[:, ibR], self.grips_B["r"]["point"])
        rel = grip_r + synth["rel"]
        tgt_grip = rel + synth["held"][:, None] * (on_axis - rel)
        cur = GPB[:, ibP] + np.einsum("fij,j->fi", GRB[:, ibP], self.grips_B["l"]["point"])
        Xg = np.einsum("fji,fj->fi", GRB[:, c], cur - GPB[:, c])  # grip point in the wrist frame
        return tgt_grip - np.einsum("fij,fj->fi", end_rot, Xg)

    def source_pose(self, clip):
        A = self.p.A
        F = clip["frames"]
        P, R = A.local_arrays(clip["tracks"], F)
        GP, GR = A.fk(P, R)
        return P, R, GP, GR

    def map_rotations(self, GRA, F):
        """B world rotations for mapped bones, B rest for the others; returns local R (F,n,3,3)."""
        p, B, A = self.p, self.p.B, self.p.A
        nB = B.n()
        GRB = np.zeros((F, nB, 3, 3))
        LB = np.repeat(B.rest_R[None], F, 0).copy()
        for i in B.order:
            n = B.names[i]
            par = B.parent[i]
            if n in p.mapped_set:
                GRB[:, i] = GRA[:, A.idx[n]] @ p.C_post[n]
                LB[:, i] = GRB[:, i] if par < 0 else np.einsum("fji,fjk->fik", GRB[:, par], GRB[:, i])
            else:
                GRB[:, i] = B.rest_R[i][None] if par < 0 else GRB[:, par] @ B.rest_R[i]
        return LB

    def retarget(self, name, clip, cfg):
        p, A, B = self.p, self.p.A, self.p.B
        F = clip["frames"]
        keyed = keyed_channels(clip["tracks"])
        additive = bool(clip["meta"].get("additive_source", False))
        profile = cfg.get("profile", "ground")
        diag = {"profile": profile, "additive": additive, "frames": F}
        if additive:
            return self.retarget_additive(name, clip, cfg, diag)
        PA, RA, GPA, GRA = self.source_pose(clip)
        full_body = "root" in keyed and "pos" in keyed["root"]
        lp, rp = PROPS
        # `seamless`: the source's first and last poses match. `loop`: the design plays the clip
        # as a cycle (config `loop`); only those get wrap-around smoothing and seam closing.
        seamless = bool(full_body and is_loop(GPA))
        # (configs without per-clip intents, e.g. the prototype's `loop_from_seam`, loop the seamless clips)
        loop = bool(cfg["loop"]) if "loop" in cfg else bool(cfg.get("loop_from_seam", False) and seamless)
        diag["loop"] = loop
        diag["seamless"] = seamless
        # 1. weapon frames (weapon_frames.py): one frame per weapon family
        if cfg.get("weapon_frame"):
            rec = self.convert_weapon_frame(cfg["weapon_frame"], keyed, PA, RA, GPA, GRA)
            if rec:
                diag["weapon_frame"] = rec
        # 2. mount: move the source into the saddle frame with the solved ground -> saddle align
        self.ground_origin = np.zeros(3)
        floor_y = floor_a = 0.0  # B's / A's floor height in the clip frame
        align = None
        if profile == "mount" and cfg.get("align_bake") and full_body:
            align = mount_align(A, GPA, cfg["align_bake"], self.horse)
            Rw = yaw_matrices(align["psi"])
            GPA = np.einsum("fij,fnj->fni", Rw, GPA) + align["t"][:, None]
            GRA = np.einsum("fij,fnjk->fnik", Rw, GRA)
            ira = A.idx["root"]
            PA, RA = PA.copy(), RA.copy()
            PA[:, ira], RA[:, ira] = GPA[:, ira], GRA[:, ira]
            # A's world (saddle frame, floor at the fitted source saddle height) maps to B's by the
            # scale s about the saddle attach point: B's ground-phase body, floor and reach are A's
            # scaled, her saddle-phase effectors use the saddle map (absolute + seat / stirrup offsets)
            floor_a = float(align["t_ground"][1])
            floor_y = p.s * floor_a
            fit = align.get("fit") or {}
            diag["mount_align"] = {
                "frame": "saddle", "floor_y_m": round(floor_y, 4), "reference_saddle_height_m": round(-floor_y, 4),
                "source_saddle_height_m": round(-floor_a, 4),
                "ground_frame_source": {"origin_m": np.round(align["t_ground"], 4).tolist(),
                                        "yaw_deg": round(float(np.degrees(align["psi"][0])), 2),
                                        "fit_rms_m": round(float(fit.get("rms_m", float("nan"))), 4)},
                "source_yaw_deg": np.round(np.degrees(align["psi"]), 2).tolist(),
                "source_offset_m": np.round(align["t"], 4).tolist(),
                "push_off_foot": cfg["align_bake"]["ground_foot"], "push_off_frames": list(cfg["align_bake"]["plant"]),
                "ground_to_saddle": np.round(align["ground_to_saddle"], 3).tolist()}
        auto = cfg.get("contacts") == "auto" and full_body
        sm = float(cfg.get("weight_smooth_frames", 1.0))
        LB = self.map_rotations(GRA, F)
        PB = np.repeat(B.rest_pos[None], F, 0).copy()
        offhand = cfg.get("offhand") if full_body else None
        two_hand = bool(offhand)
        # translation deltas of bones A animates (muscle helpers, props), mapped into B frames
        for n in p.mapped:
            if n == "root" or "pos" not in keyed.get(n, ()):
                continue
            ia, ib = A.idx[n], B.idx[n]
            if n in PROPS:  # grip point: A's offset in the palm frame, scaled to B's hand
                pa = PA[:, ia]
                if two_hand and n == (rp if offhand == "l" else lp):
                    # the weapon is the same object: only the part of the offset across the
                    # weapon axis (+Z) is hand-sized, the part along it is not scaled
                    v = np.einsum("fji,fj->fi", RA[:, ia], pa)
                    v[:, :2] *= p.k_hand
                    PB[:, ib] = np.einsum("ij,fj->fi", p.K1[n], np.einsum("fij,fj->fi", RA[:, ia], v))
                else:
                    PB[:, ib] = p.k_hand * np.einsum("ij,fj->fi", p.K1[n], pa)
                continue
            delta = PA[:, ia] - A.rest_pos[ia]
            if np.abs(delta).max() < 1e-4:
                continue
            PB[:, ib] = B.rest_pos[ib] + p.s * np.einsum("ij,fj->fi", p.K1[n], delta)
        # prop bones used as something other than a hand-held weapon frame (paired-move sync
        # markers, the sheathed weapon on the belt): > 0.3 m from both palms. Flagged, not changed.
        far = {}
        for pr in PROPS:
            if pr in keyed:
                dpal = np.minimum(np.linalg.norm(GPA[:, A.idx[pr]] - GPA[:, A.idx["l_palm"]], axis=1),
                                  np.linalg.norm(GPA[:, A.idx[pr]] - GPA[:, A.idx["r_palm"]], axis=1))
                if float(np.median(dpal)) > 0.3:
                    far[pr] = round(float(np.median(dpal)), 2)
        if far:
            diag["prop_far_from_palm_m"] = far
        # root translation from the pelvis anchor map (root rotation is mapped above)
        wkeys = cfg.get("anchor", {})
        ground_default = 1.0 if profile == "ground" else 0.0
        w_pel = weight_curve(wkeys.get("pelvis"), F, ground_default)
        ir, ipB, ipA = B.idx["root"], B.idx["pelvis"], A.idx["pelvis"]
        pel_target = self.map_points(GPA[:, ipA], w_pel)
        # two-handed weapons: the off hand keeps A's grip relative to the main-hand prop bone.
        # Clips that key no main-hand prop (the source placed the weapon in code) get the weapon at
        # the haft clips' canonical right-hand grip, and the off hand onto its axis (weapon_frames).
        added = {}
        grip_w = None
        synth = None
        if offhand:
            main_prop = rp if offhand == "l" else lp
            if "rot" not in keyed.get(main_prop, ()) and self.grips_B is not None and offhand == "l":
                # the weapon where A's two hands hold the haft (synthetic_two_hand); the off hand is
                # moved onto its grip point in the solve below
                synth = self.synthetic_two_hand(GPA, GRA, loop, cfg)
                added[main_prop] = {"pos", "rot"}
                LB[:, B.idx[main_prop]] = synth["M"]
                PB[:, B.idx[main_prop]] = synth["p"]
                grip_w = synth["held"]
                diag["synthetic_grip"] = synth["diag"]
            else:
                if "rot" not in keyed.get(main_prop, ()):
                    added[main_prop] = {"rot"}
                if cfg.get("grip", "auto" if auto else "fixed") == "auto":
                    ref_pose = self.grip_ref_pose(cfg.get("grip_ref"), main_prop, offhand + "_palm", cfg.get("weapon_frame"))
                    grip_w, grip_sd = grip_weights(GPA, GRA, A, main_prop, offhand + "_palm", ref_pose)
                    grip_w = smooth(grip_w, sm, loop)
                    diag["grip"] = {"rigidity_sd_m": round(grip_sd, 3), "held_fraction": round(float((grip_w > 0.5).mean()), 3)}
                else:
                    grip_w = np.ones(F)
            if added:
                diag["added_prop_tracks"] = {k: sorted(v) for k, v in added.items()}
        if full_body:
            PB[:, ir] = 0.0
            GPB0, _ = B.fk(PB, LB)
            PB[:, ir] = pel_target - GPB0[:, ipB]
        diag["pelvis_anchor_w"] = [round(float(x), 3) for x in (w_pel.min(), w_pel.max())]
        # limb chains: pre-projection effector (relative to the chain root) and orientation
        GPB, GRB = B.fk(PB, LB)
        if synth:
            # Actor_B's shorter arms and narrower shoulders put her mapped hands 4-6 cm closer together
            # along the haft than A's x s; the left grip goes that much closer (at most synthetic_grip_span_
            # adjust_m, 3.5 cm, one constant per clip) so the off hand is not stretched to the scaled span
            ibM, ibR, ibP = B.idx[synth["prop"]], B.idx["r_palm"], B.idx["l_palm"]
            hm = synth["held"] > 0.9
            if hm.any():
                cl = GPB[:, ibP] + np.einsum("fij,j->fi", GRB[:, ibP], self.grips_B["l"]["point"])
                gr = GPB[:, ibR] + np.einsum("fij,j->fi", GRB[:, ibR], self.grips_B["r"]["point"])
                Zw = np.einsum("fij,fj->fi", GRB[:, ibR], synth["z_in"])
                # (and never so far that the off hand ends more than 4.5 cm from the source's placement,
                # measured at the grip points and at the fist centres (knuckles + palm), where the smoothed
                # weapon axis already leaves it a little off: atk-pipe-block's hands jitter)
                A_ = p.A
                fB = {sd: GPB[:, [B.idx[sd + x] for x in FIST]].mean(1) for sd in "lr"}
                fA = {sd: GPA[:, [A_.idx[sd + x] for x in FIST]].mean(1) for sd in "lr"}
                on_ax = gr - synth["span_t"][:, None] * Zw  # the left grip point on the weapon (span delta 0)
                r_grip = (on_ax - gr - synth["rel"])[hm]
                r_fist = (on_ax + (fB["l"] - cl) - fB["r"] - p.s * (fA["l"] - fA["r"]))[hm]
                want = float(np.median(np.sum((gr - cl) * Zw, 1)[hm] - synth["span_t"][hm]))
                lim = float(cfg.get("synthetic_grip_span_adjust_m", 0.035))
                dlt = 0.0
                for cand in np.linspace(np.clip(want, -lim, lim), 0.0, 15):
                    worst = max(np.linalg.norm(r - cand * Zw[hm], axis=1).max() for r in (r_grip, r_fist))
                    if worst <= 0.045:
                        dlt = float(cand)
                        break
                synth = self.synthetic_two_hand(GPA, GRA, loop, cfg, dlt)
                LB[:, ibM] = synth["M"]
                PB[:, ibM] = synth["p"]
                grip_w = synth["held"]
                diag["synthetic_grip"] = synth["diag"]
                GPB, GRB = B.fk(PB, LB)
            # how far the off hand has to move from where the mapping puts it (B's proportions against
            # the scaled source), on the frames it holds
            ic = B.idx[offhand + "_wrist"]
            mv0 = np.linalg.norm(self.synth_wrist_target(synth, GPB, GRB, ic, GRB[:, ic]) - GPB[:, ic], axis=1)
            hm = synth["pull"] > 0.5
            if hm.any():
                diag["synthetic_grip"]["offhand_move_cm"] = [round(float(np.median(mv0[hm])) * 100, 1), round(float(mv0[hm].max()) * 100, 1)]
        GPB_pre = GPB.copy()
        limbs = {}
        for kind, chains in (("foot", LEGS), ("hand", ARMS)):
            for side, names in chains.items():
                a, b, c = (B.idx[x] for x in names)
                chain_keyed = all("rot" in keyed.get(x, ()) for x in names)
                limbs[side + "_" + kind] = {"chain": (a, b, c), "hinge": HINGES[names[1]], "flex": FLEX_SIGN[names[1]],
                                            "keyed": chain_keyed, "v_pre": GPB[:, c] - GPB[:, a], "R_pre": GRB[:, c].copy()}
        # hinge projection (knee / elbow stay pure hinges relative to the B bind)
        if cfg.get("hinge_project", True):
            for n, ax in HINGES.items():
                i = B.idx[n]
                LB[:, i], sw = hinge_project(B.rest_R[i], LB[:, i], ax)
                diag.setdefault("hinge_swing_removed_deg", {})[n] = round(float(np.percentile(sw, 95)), 2)
        # effector targets and their IK weights
        ik = cfg.get("ik", {})
        horse_ok = self.horse is not None and self.horse.ok
        auto_w = {}
        hand_plants = set()
        if auto and profile == "ground":
            for s_, w in hand_floor_weights(GPA, A).items():
                auto_w[s_ + "_hand"] = w
                hand_plants.add(s_ + "_hand")
        if auto and profile == "horse" and horse_ok:
            for s_, w in stirrup_weights(GPA, A, self.horse).items():
                auto_w[s_ + "_foot"] = w
            for s_, w in rein_weights(GPA, A, self.horse, tuple(cfg.get("rein_hands", ["l"]))).items():
                auto_w[s_ + "_hand"] = w
        auto_w = {k: smooth(v, sm, loop) for k, v in auto_w.items()}
        eff = {}
        weights = {}

        def speed_xz(X, k=1.0):
            v = np.zeros(F)
            if F > 1:
                v[1:] = np.linalg.norm(np.diff(X[:, [0, 2]], axis=0), axis=1) * 30.0 * k
                v[0] = v[1]
            return v

        # feet: ground part mapped from the hip by the leg-length ratio (straight legs stay
        # straight), height from the floor map near the floor; saddle part absolute + stirrup offset
        for side, names in LEGS.items():
            key = side + "_foot"
            if key in ik:
                wi = weight_curve(ik[key], F, 0.0)
            elif key in auto_w:
                wi = auto_w[key]
            else:
                wi = np.full(F, 1.0 if (full_body and profile in ("ground", "horse", "mount")) else 0.0)
            wa = weight_curve(wkeys.get(key), F, ground_default)
            ih, ian = A.idx[names[0]], A.idx[names[2]]
            ya, yb = p.ankleA[side], p.ankleB[side]
            e = {"w": wi, "base": B.idx[names[0]], "rel": p.k_leg * (GPA[:, ian] - GPA[:, ih]),
                 "y_floor": floor_y + yb + p.s * (GPA[:, ian, 1] - floor_a - ya),
                 "g": ramp(GPA[:, ian, 1] - floor_a - ya, 0.05, 0.20), "wa": wa,
                 "saddle": GPA[:, ian] + self.stirrup_offset[side][None]}
            locked = (auto and profile == "ground" and cfg.get("foot_lock", True)) or align is not None
            if locked:
                # foot plants: while A keeps a heel or ball planted (within 3 cm of its bind
                # contact height, slower than 0.25 m/s, 2 frames or more), B's same point is
                # held where the plant starts and only follows A's own (scaled) slide. Actor_B's
                # foot is 0.73x as long and pitched 12.5 deg differently, so an ankle target
                # alone lets a planted toe / heel slide while the foot rolls. Mount clips: the
                # push-off ball is held over the solved push-off window.
                free = self.eff_target(e, GPB_pre)
                ank_i = B.idx[names[2]]
                locks = {}
                for pt in ("heel", "ball"):
                    ia, ib = A.idx[side + "_" + pt], B.idx[side + "_" + pt]
                    ya_rel = GPA[:, ia, 1] - floor_a - p.PA0[ia, 1]
                    planted = (ya_rel <= 0.03) & (speed_xz(GPA[:, ia], p.s) < 0.25)
                    # a source contact that jitters over the speed limit for a frame or two while it
                    # stays on the floor (10-15 Hz source keys) is one plant, not several short ones
                    planted = bridge_gaps(planted, ya_rel <= 0.03, int(cfg.get("plant_gap_frames", 2)))
                    if align is not None:
                        gfoot = cfg["align_bake"]["ground_foot"]
                        planted = planted & (align["w_ground_foot"] > 0.5) if side == gfoot else np.zeros(F, bool)
                        if side == gfoot and pt == "ball":
                            planted = align["w_ground_foot"] > 0.5
                    if not planted.any():
                        weights[side + "_lock_" + pt] = np.zeros(F)
                        continue
                    off = GPB_pre[:, ib] - GPB_pre[:, ank_i]
                    # follow A's own (scaled) slide; the mount push-off is planted by construction
                    drift = np.zeros((F, 3)) if align is not None else p.s * GPA[:, ia]
                    lock, wl = plant_lock(free + off, planted, drift, loop,
                                          min_len=int(cfg.get("plant_min_frames", 2)), pad=0 if align is not None else 1)
                    locks[pt] = (lock, wl, off)
                    weights[side + "_lock_" + pt] = wl
                if locks:
                    # while heel and ball are both held (a flat foot) the foot turns so heel -> ball
                    # matches the two locks, then the ankle target satisfies both at once; a single
                    # lock keeps the forward-kinematics foot orientation. Averaging two inconsistent
                    # ankle targets instead let both points slide and jump when one released.
                    S = np.repeat(np.eye(3)[None], F, 0)
                    if len(locks) == 2:
                        (lh, wh, oh), (lb, wb, ob) = locks["heel"], locks["ball"]
                        both = np.minimum(wh, wb)
                        both = np.maximum(both, smooth(both, 2.5, loop))  # turn back gently after a release
                        if both.max() > 1e-3:
                            S = slerp_m(S, rot_between(ob - oh, lb - lh), both)
                    acc = np.zeros((F, 3))
                    wsum = np.zeros(F)
                    for lock, wl, off in locks.values():
                        acc += wl[:, None] * (lock - np.einsum("fij,fj->fi", S, off))
                        wsum += wl
                    e["lock"] = acc / np.maximum(wsum, 1e-9)[:, None]
                    e["lockw"] = np.minimum(wsum, 1.0)
                    e["end_rot"] = np.einsum("fij,fjk->fik", S, limbs[key]["R_pre"])
            eff[key] = e
            weights[key] = wi
        # hands: floor plants (crawl, get-down / get-up) mapped from the shoulder by the arm-length
        # ratio, so the plant is where B's own arm reaches it, and locked while planted; other
        # hand targets (reins, mount grips) keep the anchor map
        for side, names in ARMS.items():
            key = side + "_hand"
            wi = weight_curve(ik[key], F, 0.0) if key in ik else auto_w.get(key, np.zeros(F))
            wa = weight_curve(wkeys.get(key), F, ground_default)
            iw = A.idx[names[2]]
            if key in hand_plants:
                e = {"w": wi, "base": B.idx[names[0]], "rel": p.k_arm * (GPA[:, iw] - GPA[:, A.idx[names[0]]]),
                     "y_floor": p.s * GPA[:, iw, 1], "g": np.clip(smooth(ramp(GPA[:, iw, 1], 0.10, 0.24), 1.5, loop), 0, 1),
                     "floor_min": bool(cfg.get("hand_floor_min", True))}
                planted = (GPA[:, iw, 1] < 0.10) & (speed_xz(GPA[:, iw], p.s) < 0.25)
                if planted.any():
                    # a planted hand is on the floor (the floor-mapped height), even where B's shorter
                    # torso puts her shoulder higher than the arm-length map would reach
                    e["plant_w"] = np.clip(smooth(planted.astype(float), 1.0, loop), 0, 1)
                    lock, wl = plant_lock(self.eff_target(e, GPB_pre), planted, p.s * GPA[:, iw], loop,
                                          min_len=int(cfg.get("plant_min_frames", 2)))
                    e["lock"], e["lockw"] = lock, wl
                    weights[side + "_hand_lock"] = wl
            elif align is not None:
                # mount: while the rider climbs, the hands keep her own arm's reach (from the
                # shoulder, arm-length ratio); seated, they take the absolute grips (reins)
                e = {"w": wi, "base": B.idx[names[0]], "rel": p.k_arm * (GPA[:, iw] - GPA[:, A.idx[names[0]]]),
                     "y_floor": np.zeros(F), "g": np.zeros(F), "wa": wa,
                     "saddle": GPA[:, iw] + self.effector_offset[None]}
            elif profile == "horse":
                # reins: A's absolute hand position (the reins are on the horse); where A reaches with
                # a nearly straight arm (elbow under 25 deg, all of it under 10) B's hand follows her
                # own arm from the shoulder (arm-length ratio) instead, so the arm keeps A's extension
                # rather than folding up because B's shoulder is lower and narrower
                ish, iel = A.idx[names[0]], A.idx[names[1]]
                u_, v_ = GPA[:, iel] - GPA[:, ish], GPA[:, iw] - GPA[:, iel]
                fa_ = np.degrees(np.arccos(np.clip(np.sum(u_ * v_, 1) / (np.linalg.norm(u_, axis=1) * np.linalg.norm(v_, axis=1)), -1, 1)))
                w_rel = smooth(np.clip((25.0 - fa_) / 15.0, 0.0, 1.0), 2.0, loop)
                e = {"w": wi, "base": B.idx[names[0]], "rel": p.k_arm * (GPA[:, iw] - GPA[:, ish]),
                     "y_floor": np.zeros(F), "g": np.zeros(F), "wa": w_rel,
                     "saddle": self.map_points(GPA[:, iw], wa, offset=self.effector_offset)}
            else:
                e = {"w": wi, "abs": self.map_points(GPA[:, iw], wa, offset=self.effector_offset)}
            eff[key] = e
            weights[key] = wi
        # supports: effectors whose residual moves the root (full-body clips only)
        sup_cfg = cfg.get("support", {})
        sup_w = {k: weight_curve(v, F, 0.0) for k, v in sup_cfg.items()}
        contacts = {}
        kc = cfg.get("knee_contacts", "auto" if auto and profile == "ground" else [])
        if kc == "auto":
            kw = {k: smooth(v, sm, loop) for k, v in knee_contact_weights(GPA, A).items()}
            kw = {k: v for k, v in kw.items() if v.max() > 1e-3}
        else:
            kw = {kn: np.clip((0.08 - GPA[:, A.idx[kn]][:, 1]) / 0.04, 0, 1) for kn in kc}
        for kn, wc in kw.items():
            ktgt = GPA[:, A.idx[kn]] * p.s
            contacts[kn] = (wc, ktgt[:, 1], ktgt)
            weights[kn + "_contact"] = wc
        if "pelvis" not in sup_w:
            if kc == "auto" and contacts:
                sup_w["pelvis"] = 1.0 - 0.75 * np.max([c[0] for c in contacts.values()], axis=0)
            else:
                sup_w["pelvis"] = np.ones(F)
        iters = int(cfg.get("root_iterations", 4)) if (full_body and (len(sup_w) > 1 or contacts)) else 1
        resid = {}
        root_shift = np.zeros((F, 3))
        base_root = PB[:, ir].copy()
        max_shift = float(cfg.get("root_shift_max_m", 0.10))
        limb_len = {L["chain"]: (float(np.linalg.norm(p.PB0[L["chain"][1]] - p.PB0[L["chain"][0]])),
                                 float(np.linalg.norm(p.PB0[L["chain"][2]] - p.PB0[L["chain"][1]])))
                    for L in limbs.values()}
        fold_frames = {}
        swivel = bool(cfg.get("knee_swivel", False))
        knee_res = {}
        flex_smooth = float(cfg.get("flex_smooth_frames", 0.75))
        # straight source legs stay straight (ground clips): where A's knee is within 15 deg of
        # straight, B's knee may bend at most 6 deg more; the foot then keeps a small residual.
        # Planted (locked) frames keep the plant instead.
        caps = {}
        # (horse clips too: B's calibrated stirrups are not symmetric, so where A stands straight on
        # both, one of B's legs would otherwise bend 20 deg; the foot keeps a residual of 1-2 cm from
        # its stirrup target instead, which the runtime stirrup IK takes up)
        if profile in ("ground", "horse", "mount") and full_body and cfg.get("straight_leg_cap", True):
            for side, names in LEGS.items():
                ia_, ib_, ic_ = (A.idx[x] for x in names)
                u_, v_ = GPA[:, ib_] - GPA[:, ia_], GPA[:, ic_] - GPA[:, ib_]
                fa_ = np.arccos(np.clip(np.sum(u_ * v_, 1) / (np.linalg.norm(u_, axis=1) * np.linalg.norm(v_, axis=1)), -1, 1))
                lw_ = eff[side + "_foot"].get("lockw")
                free_ = np.ones(F, bool) if lw_ is None else (lw_ < 0.5)
                # continuous: the cap opens quickly above 15 deg (no step when A's knee crosses it)
                cap = fa_ + np.radians(6.0) + 3.0 * np.maximum(fa_ - np.radians(15.0), 0.0)
                cap = np.where(free_, np.minimum(cap, np.pi), np.pi)
                if (cap < np.pi).any():
                    caps[side + "_foot"] = cap
        # straight source elbows stay straight too (same rule): where A's elbow is within 15 deg of
        # straight, B's may bend at most 6 deg more and the hand keeps a small residual (the rein hand
        # when A reaches with a locked arm, bail-offs, stumbles, falls). Hands locked on the floor keep
        # their plant, hands near the floor keep their floor target (a straight limb would push the hand
        # past a target it cannot reach, into the floor), and an off hand holding a weapon keeps its grip.
        if profile in ("ground", "horse", "mount") and full_body and cfg.get("straight_arm_cap", True):
            for side, names in ARMS.items():
                ia_, ib_, ic_ = (A.idx[x] for x in names)
                u_, v_ = GPA[:, ib_] - GPA[:, ia_], GPA[:, ic_] - GPA[:, ib_]
                fa_ = np.arccos(np.clip(np.sum(u_ * v_, 1) / (np.linalg.norm(u_, axis=1) * np.linalg.norm(v_, axis=1)), -1, 1))
                e_ = eff[side + "_hand"]
                free_ = np.ones(F, bool)
                if e_.get("lockw") is not None:
                    free_ &= e_["lockw"] < 0.5
                if side + "_hand" in hand_plants:
                    free_ &= GPA[:, ic_, 1] - (floor_a if align is not None else 0.0) > 0.10
                if offhand == side and grip_w is not None:
                    free_ &= np.asarray(synth["pull"] if synth else grip_w) < 0.5
                cap = fa_ + np.radians(6.0) + 3.0 * np.maximum(fa_ - np.radians(15.0), 0.0)
                cap = np.where(free_, np.minimum(cap, np.pi), np.pi)
                if (cap < np.pi).any():
                    caps[side + "_hand"] = cap
        # rising in the stirrups (horse clips): seated, the calibrated seat and stirrups hold B's legs
        # as her own riding clips do; where A rises out of the saddle (knee opening past 45 deg to 25
        # deg) B's pelvis follows her own legs instead: it moves up or down (at most 6 cm) until her
        # hip -> stirrup distance is her leg length times A's extension (k_leg x A's hip -> ankle),
        # so a straight source leg stands straight and a bent one does not over-extend
        if profile in ("horse", "mount") and full_body and cfg.get("stirrup_stand", True):
            num = np.zeros(F)
            den = np.zeros(F)
            wmax = np.zeros(F)
            for side, names in LEGS.items():
                e = eff[side + "_foot"]
                ia_, ib_, ic_ = (A.idx[x] for x in names)
                u_, v_ = GPA[:, ib_] - GPA[:, ia_], GPA[:, ic_] - GPA[:, ib_]
                fa_ = np.degrees(np.arccos(np.clip(np.sum(u_ * v_, 1) / (np.linalg.norm(u_, axis=1) * np.linalg.norm(v_, axis=1)), -1, 1)))
                ws = np.clip(e["w"], 0, 1) * np.clip((45.0 - fa_) / 20.0, 0, 1)
                if profile == "mount":  # only while the foot is in the saddle frame (stirrup phase)
                    ws = ws * (1.0 - np.clip(e.get("wa", np.ones(F)), 0, 1))
                if ws.max() < 1e-3:
                    continue
                a_, b_, c_ = (B.idx[x] for x in names)
                T = self.eff_target(e, GPB_pre)
                v = GPB_pre[:, a_] - T
                lB = sum(limb_len[(a_, b_, c_)])
                Ldes = np.minimum(p.k_leg * np.linalg.norm(GPA[:, ic_] - GPA[:, ia_], axis=1), 0.999 * lB)
                disc = v[:, 1] ** 2 - np.sum(v * v, 1) + Ldes ** 2
                dy = np.where(disc > 0, -v[:, 1] + np.sqrt(np.maximum(disc, 0.0)), 0.0)
                num += ws * dy
                den += ws
                wmax = np.maximum(wmax, ws)
            if wmax.max() > 1e-3:
                lim = float(cfg.get("stirrup_stand_max_m", 0.06))
                lift = np.clip(num / np.maximum(den, 1e-9) * np.clip(2.0 * wmax, 0, 1), -lim, lim)
                lift = smooth(lift, 1.5, loop)
                base_root[:, 1] += lift
                pel_target[:, 1] += lift
                diag["stirrup_stand_cm"] = {"max": round(float(lift.max()) * 100, 1), "min": round(float(lift.min()) * 100, 1),
                                            "frames": int((np.abs(lift) > 0.005).sum())}
        for it in range(iters):
            PB[:, ir] = base_root + root_shift
            GPB, GRB = B.fk(PB, LB)
            order = ["l_foot", "r_foot"]
            main = ("r" if offhand == "l" else "l") if offhand else None
            order += [main + "_hand", offhand + "_hand"] if offhand else ["l_hand", "r_hand"]
            for key in order:
                L = limbs[key]
                if not L["keyed"]:
                    continue
                a, b, c = L["chain"]
                tgt = GPB[:, a] + L["v_pre"]
                e = eff[key]
                end_rot = e.get("end_rot", L["R_pre"])
                wi = e["w"]
                if full_body:
                    tgt = tgt + wi[:, None] * (self.eff_target(e, GPB) - tgt)
                if offhand and key == offhand + "_hand" and synth is None:
                    main_prop = rp if offhand == "l" else lp
                    palm = offhand + "_palm"
                    iaM, iaP, ibM, ibP = A.idx[main_prop], A.idx[palm], B.idx[main_prop], B.idx[palm]
                    # weapon frames are shared, so the palm target is A's palm offset from the
                    # weapon applied to B's weapon, with the palm's bind-relative rotation
                    relp = np.einsum("fji,fj->fi", GRA[:, iaM], GPA[:, iaP] - GPA[:, iaM])
                    tgtP = GPB[:, ibM] + np.einsum("fij,fj->fi", GRB[:, ibM], relp)
                    tgtR = GRB[:, ibM] @ np.einsum("fji,fjk->fik", GRA[:, iaM], GRA[:, iaP]) @ p.C_post[palm]
                    XR = np.einsum("fji,fjk->fik", GRB[:, c], GRB[:, ibP])
                    Xp = np.einsum("fji,fj->fi", GRB[:, c], GPB[:, ibP] - GPB[:, c])
                    g_rot = tgtR @ np.transpose(XR, (0, 2, 1))
                    g_tgt = tgtP - np.einsum("fij,fj->fi", g_rot, Xp)
                    tgt = tgt + grip_w[:, None] * (g_tgt - tgt)
                    end_rot = slerp_m(end_rot, g_rot, grip_w)
                    key = offhand + "_offhand"
                elif offhand and key == offhand + "_hand":
                    # synthetic two-handed frame: while the hands are together the off hand keeps the
                    # source's placement relative to the right hand, and while it holds its grip point
                    # is on the weapon (synth_wrist_target); the hand keeps its orientation
                    tgt = tgt + synth["pull"][:, None] * (self.synth_wrist_target(synth, GPB, GRB, c, end_rot) - tgt)
                    key = offhand + "_offhand"
                g = fold_gate(GPB, (a, b, c), tgt, limb_len[(a, b, c)],
                              *((0.25, 0.5) if key.endswith("_foot") else (0.12, 0.25)))
                lw_ = eff.get(key, {}).get("lockw")
                if lw_ is not None and key.endswith("_foot"):  # a planted foot is solved down to a more folded leg
                    g = np.maximum(g, lw_ * fold_gate(GPB, (a, b, c), tgt, limb_len[(a, b, c)], 0.14, 0.24))
                if g.min() < 1.0:  # the gate turns the solve on and off gradually (a plant released on a folded leg)
                    g = np.clip(smooth(g, 1.5, loop), 0.0, 1.0)
                if g.min() < 1.0:  # folded: keep the position the limb has, still restore the
                    # effector's world orientation (hand -> prop bone, foot)
                    tgt = GPB[:, c] + g[:, None] * (tgt - GPB[:, c])
                    fold_frames[key] = int((g < 0.5).sum())
                resid[key] = two_bone_ik(B, GPB, GRB, LB, (a, b, c), L["hinge"], tgt, end_rot, L["flex"], loop, flex_smooth,
                                         gate=g if g.min() < 1.0 else None, flex_cap=caps.get(key))
                GPB, GRB = B.fk(PB, LB)
                kn = key[0] + "_knee"
                if key.endswith("_foot") and kn in contacts and swivel:
                    wc, ty, _kt = contacts[kn]
                    knee_res[kn] = knee_swivel(B, GPB, GRB, LB, a, b, c, ty, wc, loop)
                    GPB, GRB = B.fk(PB, LB)
                if key in sup_w or key.replace("_offhand", "_hand") in sup_w:
                    resid[key + "_vec"] = tgt - GPB[:, c]
            if it == iters - 1:
                break
            # root update: weighted mean of support residuals (pelvis keeps its anchor)
            num = np.zeros((F, 3))
            den = np.zeros(F)
            pel_res = pel_target - GPB[:, ipB]
            num += sup_w["pelvis"][:, None] * pel_res
            den += sup_w["pelvis"]
            for k, w in sup_w.items():
                if k == "pelvis" or (k + "_vec") not in resid:
                    continue
                num += w[:, None] * resid[k + "_vec"]
                den += w
            for kn, (wc, ty, _kt) in contacts.items():
                dy = np.zeros((F, 3))
                dy[:, 1] = ty - GPB[:, B.idx[kn]][:, 1]
                num += wc[:, None] * dy
                den += wc
            step = num / np.maximum(den, 1e-9)[:, None]
            step = smooth(step, float(cfg.get("root_smooth_frames", 2.0)), loop)
            root_shift = root_shift + step
            # bounded: the support solve only absorbs proportion differences (B's thigh is
            # 0.82x A's, her shin 1.10x); it must not drag the body toward unreachable contacts
            nrm = np.linalg.norm(root_shift, axis=1, keepdims=True)
            root_shift = root_shift * np.minimum(1.0, max_shift / np.maximum(nrm, 1e-9))
        if contacts and cfg.get("knee_aim", True):
            # knees that still miss the floor after the bounded root solve: swing the thigh
            # (shin follows) the least amount that puts the knee at its contact height: the
            # closest point to the current knee on the hip-centred circle at that height
            for kn, (wc, ty, _kt) in contacts.items():
                side = kn[0]
                hip, knee = B.idx[side + "_upper_leg"], B.idx[kn]
                H, K = GPB[:, hip], GPB[:, knee]
                Lt = np.linalg.norm(K - H, axis=1)
                err = ty - K[:, 1]
                db = float(cfg.get("knee_deadband_m", 0.02))  # leave small misses to keep the motion
                err = np.sign(err) * np.maximum(np.abs(err) - db, 0.0)
                # a planted foot keeps its plant: swinging the thigh would drag it (the knee keeps
                # its small residual on those frames instead)
                lw_ = eff.get(side + "_foot", {}).get("lockw")
                wk = wc if lw_ is None else wc * (1.0 - np.clip(lw_, 0, 1))
                corr = smooth(wk * err, float(cfg.get("root_smooth_frames", 2.0)), loop)
                dy = np.clip(K[:, 1] + corr - H[:, 1], -Lt, Lt)
                rho = np.sqrt(np.maximum(Lt * Lt - dy * dy, 0.0))
                u = K - H
                u[:, 1] = 0.0
                un = np.linalg.norm(u, axis=1, keepdims=True)
                u = np.where(un > 1e-6, u / np.maximum(un, 1e-9), np.array([0.0, 0.0, 1.0]))
                tgt = H + rho[:, None] * u
                tgt[:, 1] = H[:, 1] + dy
                aim_thigh(B, GPB, GRB, LB, hip, knee, tgt, np.ones(F))
            GPB, GRB = B.fk(PB, LB)
        if profile == "ground" and full_body and cfg.get("floor_clamp", True):
            # per-frame floor (ground clips): heel, ball and ankle never lower than the source's own
            # (scaled) height on that frame, and never below the floor unless the source is (both
            # relative to the bind contact height), with 0.8 cm of slack. A swinging foot whose knee the
            # fold gate leaves in its forward-kinematics pose while B's pelvis is lower, or whose ankle
            # target misses on a deep lunge, would otherwise scrape through the floor for a few frames.
            # The ankle is lifted by the largest shortfall of the three points, the foot keeping its
            # world orientation.
            lifted = {}
            for side, names in [(sd, nm) for _ in range(3) for sd, nm in LEGS.items()]:  # (the smoothed IK can fall short: 3 passes)
                a, b, c = (B.idx[x] for x in names)
                need = np.zeros(F)
                for pt in (side + "_heel", side + "_ball", side + "_ankle"):
                    ha = (GPA[:, A.idx[pt], 1] - p.PA0[A.idx[pt], 1]) * p.s
                    hb = GPB[:, B.idx[pt], 1] - p.PB0[B.idx[pt], 1]
                    need = np.maximum(need, np.minimum(ha, 0.0) - float(cfg.get("floor_slack_m", 0.008)) - hb)
                pen = np.maximum(need, 0.0)
                if pen.max() < (0.002 if side not in lifted else 0.0005):
                    continue
                pen = np.maximum(pen, smooth(pen, 1.5, loop))
                tgt = GPB[:, c] + pen[:, None] * np.array([0.0, 1.0, 0.0])[None]
                old = {i: LB[:, i].copy() for i in (a, b, c)}
                # (a knee the source keeps straight keeps its cap: lifting a straight leg's foot 5 mm would
                # bend it 12 deg; there the source's own foot is at or below the floor too)
                two_bone_ik(B, GPB, GRB, LB, (a, b, c), HINGES[names[1]], tgt, GRB[:, c].copy(), FLEX_SIGN[names[1]], loop, flex_smooth,
                            flex_cap=caps.get(side + "_foot"))
                # only the frames that needed it (and their neighbours) change
                wl = np.clip(smooth((pen > 1e-4).astype(float), 1.0, loop) * 2.0, 0.0, 1.0)
                for i in (a, b, c):
                    LB[:, i] = slerp_m(old[i], LB[:, i], wl)
                GPB, GRB = B.fk(PB, LB)
                lifted[side] = round(max(lifted.get(side, 0.0), float(pen.max()) * 100), 1)
            if lifted:
                diag["floor_lift_cm"] = lifted
        if align is not None:
            # safety net: no foot below the floor (the fitted ground frame keeps them above it; this
            # only acts if a contact window is changed)
            lifted = {}
            for side, names in LEGS.items():
                a, b, c = (B.idx[x] for x in names)
                low = np.min([GPB[:, B.idx[side + "_" + pt], 1] - p.PB0[B.idx[side + "_" + pt], 1] for pt in ("heel", "ball")], axis=0)
                pen = np.maximum(floor_y - low, 0.0)
                if pen.max() < 0.005:
                    continue
                pen = np.maximum(pen, smooth(pen, 1.5))
                tgt = GPB[:, c] + pen[:, None] * np.array([0.0, 1.0, 0.0])[None]
                two_bone_ik(B, GPB, GRB, LB, (a, b, c), HINGES[names[1]], tgt, GRB[:, c].copy(), FLEX_SIGN[names[1]], loop, flex_smooth)
                GPB, GRB = B.fk(PB, LB)
                lifted[side] = round(float(pen.max()) * 100, 1)
            if lifted:
                diag["mount_floor_lift_cm"] = lifted
        if np.abs(root_shift).max() > 0:
            diag["root_shift_cm"] = {"max": round(float(np.linalg.norm(root_shift, axis=1).max() * 100), 1),
                                     "median": round(float(np.median(np.linalg.norm(root_shift, axis=1)) * 100), 1)}
        out_keyed_pre = {k for k, v in keyed.items() if "rot" in v} | set(added)
        # wrist swing: no more than the source's own swing + 12 deg on the hands the IK moved (the
        # hand's prop bones keep their world transform, so weapons are unchanged)
        if full_body and cfg.get("wrist_limit", True):
            ws_red = {}
            for side, names in ARMS.items():
                if not limbs[side + "_hand"]["keyed"]:
                    continue
                refA = wrist_swing_deg(GRA, A, p.RA0, side)
                # (a synthetic weapon frame is defined in the right palm: it turns with the hand)
                kw = tuple(pr for pr in PROPS if pr.startswith(side) and pr in out_keyed_pre and not (synth and pr == synth["prop"]))
                red = limit_wrist_swing(B, PB, LB, side, refA, float(cfg.get("wrist_margin_deg", 12.0)), loop, kw)
                if red > 0.05:
                    ws_red[side] = round(red, 1)
            if ws_red:
                diag["wrist_swing_limited_deg"] = ws_red
            GPB, GRB = B.fk(PB, LB)
            if synth and ws_red:
                # the wrist limits turn the hands a little: put the off hand's grip point back on the weapon
                a, b, c = limbs[offhand + "_hand"]["chain"]
                wt = self.synth_wrist_target(synth, GPB, GRB, c, GRB[:, c])
                if (np.linalg.norm(wt - GPB[:, c], axis=1) * synth["pull"]).max() > 5e-4:
                    tgt = GPB[:, c] + synth["pull"][:, None] * (wt - GPB[:, c])
                    two_bone_ik(B, GPB, GRB, LB, (a, b, c), HINGES[offhand + "_elbow"], tgt, GRB[:, c].copy(),
                                FLEX_SIGN[offhand + "_elbow"], loop, flex_smooth)
                    GPB, GRB = B.fk(PB, LB)
        # two-handed weapons whose source prop is a round pipe (config prop_roll: right_palm): the roll of
        # the prop about its long axis (+Z) was never authored and turns up to 180 deg in the fist within
        # a clip; it is set from the right palm (minimal swing of the canonical right-hand grip, as for
        # the synthetic guard frame), so a roll-asymmetric weapon (musket lock, club head, bayonet) keeps
        # one orientation in the hand. The weapon axis, and so every tip path, is unchanged.
        if full_body and cfg.get("prop_roll") == "right_palm" and self.grips_B is not None and not synth \
                and "rot" in keyed.get(rp, ()) and "weapon_frame" not in diag:
            ipB, irp = B.idx[rp], B.idx["r_palm"]
            assert B.parent[ipB] == irp
            Rin = np.einsum("fji,fjk->fik", GRB[:, irp], GRB[:, ipB])
            Mc = self.grips_B["r"]["rot"]
            Rnew = np.einsum("fij,jk->fik", rot_between(np.broadcast_to(Mc[:, 2], Rin[:, :, 2].shape), Rin[:, :, 2]), Mc)
            dR = rot_angle_deg(np.einsum("fji,fjk->fik", Rin, Rnew))
            LB[:, ipB] = Rnew
            GPB, GRB = B.fk(PB, LB)
            diag["prop_roll"] = {"mode": "right_palm", "roll_removed_deg_max": round(float(dR.max()), 1),
                                 "roll_removed_deg_median": round(float(np.median(dR)), 1)}
        # left prop following the right prop (one-handed weapons)
        if lp in keyed and rp in keyed:
            dist = np.linalg.norm(GPA[:, A.idx[lp]] - GPA[:, A.idx[rp]], axis=1)
            mode = cfg.get("left_prop", "auto")
            if mode == "auto":
                mode = "follow" if np.median(dist) < 0.05 else "hand"
            diag["left_prop"] = mode
            if mode == "follow":
                rel_R = np.einsum("fji,fjk->fik", GRA[:, A.idx[rp]], GRA[:, A.idx[lp]])
                rel_p = np.einsum("fji,fj->fi", GRA[:, A.idx[rp]], GPA[:, A.idx[lp]] - GPA[:, A.idx[rp]])
                ilB, irB = B.idx[lp], B.idx[rp]
                tgtR = GRB[:, irB] @ rel_R
                tgtP = GPB[:, irB] + np.einsum("fij,fj->fi", GRB[:, irB], rel_p)
                par = B.parent[ilB]
                LB[:, ilB] = np.einsum("fji,fjk->fik", GRB[:, par], tgtR)
                PB[:, ilB] = np.einsum("fji,fj->fi", GRB[:, par], tgtP - GPB[:, par])
                GPB, GRB = B.fk(PB, LB)
        if align is not None:
            # the recipe floor: the solve's floor is the fitted source ground scaled by s, but the source
            # stands on it about 3 cm high (its push-off ball 3.1 cm above its bind contact height for the
            # whole plant) and B inherits that. The floor the runtime recipe puts under the rider is raised
            # by B's standing offset (her push-off ball over the plant, median above its bind contact
            # height), so the planted ball and the standing feet of frame 0 touch the ground; the saddle
            # phase is unchanged (the recipe's shift is 0 at ground_to_saddle = 1).
            gfoot = cfg["align_bake"]["ground_foot"]
            w0, w1 = cfg["align_bake"]["plant"]
            ib_ball = B.idx[gfoot + "_ball"]
            ia_ball = A.idx[gfoot + "_ball"]
            stand_b = float(np.median(GPB[w0:w1 + 1, ib_ball, 1] - floor_y - p.PB0[ib_ball, 1]))
            stand_a = float(np.median(GPA[w0:w1 + 1, ia_ball, 1] - floor_a - p.PA0[ia_ball, 1]))
            floor_rec = floor_y + stand_b
            ma = diag["mount_align"]
            ma["solve_floor_y_m"] = round(floor_y, 4)
            ma["standing_offset_m"] = {"B": round(stand_b, 4), "source": round(stand_a, 4)}
            ma["floor_y_m"] = round(floor_rec, 4)
            ma["reference_saddle_height_m"] = round(-floor_rec, 4)
            # ground contacts of the ground phase (for the recipe checks): the push-off ball over its plant,
            # and at frame 0 every heel / ball the source has within 1 cm of its standing level
            gc = {gfoot + "_ball": list(range(w0, w1 + 1))}
            for sd in "lr":
                for pt in ("heel", "ball"):
                    j = A.idx[sd + "_" + pt]
                    if GPA[0, j, 1] - floor_a - p.PA0[j, 1] - stand_a <= 0.01:
                        gc.setdefault(sd + "_" + pt, [])
                        if 0 not in gc[sd + "_" + pt]:
                            gc[sd + "_" + pt].insert(0, 0)
            ma["ground_contacts"] = gc
            # where the rider stands and faces at the first frame (saddle frame): the mount point
            d0 = GPB[0, B.idx["l_upper_leg"]] - GPB[0, B.idx["r_upper_leg"]]
            pel0 = GPB[0, ipB]
            diag["mount_align"]["start_ground_pose"] = {
                "position_m": [round(float(pel0[0]), 4), round(float(floor_rec), 4), round(float(pel0[2]), 4)],
                "yaw_deg": round(float(np.degrees(np.arctan2(-d0[2], d0[0]))), 2),
                "note": "pelvis over the floor; yaw about +Y, 0 = facing the horse's forward (+Z)"}
        diag["ik_residual_m"] = {k: {"median": round(float(np.median(v)), 4), "max": round(float(v.max()), 4)}
                                 for k, v in resid.items() if not k.endswith("_vec")}
        if contacts:
            diag["knee_contact_err_cm"] = {kn: round(float(np.max(np.abs(GPB[:, B.idx[kn], 1] - c[1])[c[0] > 0.5], initial=0)) * 100, 1)
                                           for kn, c in contacts.items()}
        if fold_frames:
            diag["ik_folded_frames"] = fold_frames
        diag["contact_frames"] = {k: round(float((v > 0.5).mean()), 3) for k, v in weights.items()
                                  if v.max() > 1e-3 and v.min() < 1 - 1e-3}
        out_keyed = {k: set(v) for k, v in keyed.items()}
        for k, v in added.items():
            out_keyed.setdefault(k, set()).update(v)
        tracks = self.emit_tracks(out_keyed, PB, LB, F)
        if loop:
            # (source-keyed prop bones keep the source's world rotation; a synthetic weapon frame is closed
            # like any other channel)
            diag["loop_seam"] = close_loop_seams(tracks, int(cfg.get("seam_frames", 8)),
                                                 exact=tuple(pr for pr in PROPS if "rot" in keyed.get(pr, ())))
        return {"tracks": tracks, "diag": diag, "GPB": GPB, "GRB": GRB, "GPA": GPA, "GRA": GRA,
                "w_pel": w_pel, "weights": weights, "grip_w": grip_w, "loop": loop, "seamless": seamless,
                "align": align, "floor_y": floor_y, "src_keyed": keyed}

    def eff_target(self, e, GPB):
        """Effector target for the current body pose: absolute (`abs`), or relative to a chain root
        (`base` + `rel`) with the height blended to the floor map near the floor (`g`, `y_floor`),
        blended with an absolute saddle target by the anchor weight `wa`, then the plant lock."""
        if "abs" in e:
            t = e["abs"].copy()
        else:
            t = GPB[:, e["base"]] + e["rel"]
            yf = e["y_floor"]
            if e.get("floor_min"):  # never below the floor map; exactly on it while planted
                pw = e.get("plant_w", 0.0)
                yf = pw * yf + (1 - pw) * np.maximum(yf, t[:, 1])
            t[:, 1] = e["g"] * yf + (1 - e["g"]) * t[:, 1]
            if "saddle" in e:
                t = e["wa"][:, None] * t + (1 - e["wa"][:, None]) * e["saddle"]
        if e.get("lock") is not None:
            t = t + e["lockw"][:, None] * (e["lock"] - t)
        return t

    def retarget_additive(self, name, clip, cfg, diag):
        p, A, B = self.p, self.p.A, self.p.B
        F = clip["frames"]
        keyed = keyed_channels(clip["tracks"])
        LB = np.repeat(B.rest_R[None], F, 0).copy()
        PB = np.repeat(B.rest_pos[None], F, 0).copy()
        for bn, chs in keyed.items():
            if bn not in p.mapped_set:
                continue
            ia, ib = A.idx[bn], B.idx[bn]
            if "rot" in chs:
                addA = q2m(np.asarray(clip["tracks"][bn]["rot"], float))
                fam = self.weapon.get(cfg.get("weapon_frame") or "")
                if fam is not None and bn in PROPS and "rot" in keyed.get(PROPS[1], ()):
                    # same frame conversion as the partial twin: over a base at rest the layer
                    # then leaves the prop in the library's weapon frame (translation: none for blades)
                    addA = addA @ fam["D"]
                    diag.setdefault("weapon_frame", {"family": cfg["weapon_frame"], "bones": []})["bones"].append(bn)
                DA = np.einsum("ij,fjk->fik", A.rest_R[ia].T, addA)
                K2 = p.K2[bn]
                DB = np.einsum("ij,fjk,kl->fil", K2.T, DA, K2)
                LB[:, ib] = np.einsum("ij,fjk->fik", B.rest_R[ib], DB)
            if "pos" in chs:
                delta = np.asarray(clip["tracks"][bn]["pos"], float) - A.rest_pos[ia]
                k = p.k_hand if bn in PROPS else p.s
                PB[:, ib] = B.rest_pos[ib] + k * np.einsum("ij,fj->fi", p.K1[bn], delta)
        diag["method"] = "additive: add_B = L_B0 * K2^T * (L_A0^T * add_A) * K2"
        return {"tracks": self.emit_tracks(keyed, PB, LB, F), "diag": diag}

    def emit_tracks(self, keyed, PB, LB, F):
        p, B = self.p, self.p.B
        tracks = {}
        for bn, chs in keyed.items():
            if bn not in p.mapped_set:
                continue
            ib = B.idx[bn]
            t = {}
            if "rot" in chs:
                t["rot"] = np.round(q_continuous(m2q(LB[:, ib])), 7).tolist()
            if "pos" in chs:
                t["pos"] = np.round(PB[:, ib], 6).tolist()
            if t:
                tracks[bn] = t
        return tracks


# ----------------------------------------------------------------------------- driver
def calibrate_seat(pair, src, dst, a_clip, b_clip, joint="pelvis"):
    """Offset = mean joint(B native) - mean joint(A) on a pair of saddle clips (seat: pelvis,
    stirrups: l_ankle / r_ankle)."""
    A, B = pair.A, pair.B
    ca, cb = src["clips"][a_clip], dst["clips"][b_clip]
    PA, RA = A.local_arrays(ca["tracks"], ca["frames"])
    GPA, _ = A.fk(PA, RA)
    PBn, RBn = B.local_arrays(cb["tracks"], cb["frames"])
    GPBn, _ = B.fk(PBn, RBn)
    return GPBn[:, B.idx[joint]].mean(0) - GPA[:, A.idx[joint]].mean(0)


def resolve_entries(cfg):
    """Config entries with `defaults` and per-group presets (`groups`) merged in."""
    out = []
    for e in cfg["clips"]:
        m = dict(cfg.get("defaults", {}))
        m.update(cfg.get("groups", {}).get(e.get("group", ""), {}))
        m.update(e)
        out.append(m)
    return out


def weapon_frame_summary(weapon):
    """JSON summary of weapon_frames.measure() (manifest and report)."""
    out = {}
    for fam, v in weapon.items():
        r = {}
        if "D" in v:
            r.update(weapon_frames.as_record(v))
        for k, x in v.items():
            if k in ("D", "t", "grip_l_rot", "grip_r_rot"):
                continue
            r[k] = np.round(x, 4).tolist() if isinstance(x, np.ndarray) else (round(x, 3) if isinstance(x, float) else x)
        for k in ("grip_l_rot", "grip_r_rot"):
            if k in v:
                r[k + "_q_xyzw"] = np.round(m2q(v[k]), 6).tolist()
        out[fam] = r
    return out


def horse_reference(pair, src):
    A = pair.A
    fk = {}
    for n in ("actor_a-horse-idle", "actor_a-horse-gallop-fw", "actor_a-horse-gallop-sprint"):
        if n in src["clips"]:
            c = src["clips"][n]
            P, R = A.local_arrays(c["tracks"], c["frames"])
            fk[n] = A.fk(P, R)[0]
    return HorseRef(A, fk)


def run(args):
    src = json.load(open(args.src))
    dst = json.load(open(args.dst))
    cfg = json.load(open(args.config))
    entries = resolve_entries(cfg)
    cfg["clips"] = entries
    pair = RigPair(src, dst, cfg.get("align", "limbs"))
    seat = cfg.get("seat_offset", [0, 0, 0])
    stirrups = None
    cal = cfg.get("seat_calibration")
    if cal and cal["a"] in src["clips"] and cal["b"] in dst.get("clips", {}):
        seat = calibrate_seat(pair, src, dst, cal["a"], cal["b"]).tolist()
        if cal.get("stirrups", True):
            stirrups = {k: calibrate_seat(pair, src, dst, cal["a"], cal["b"], k + "_ankle").tolist() for k in "lr"}
    horse = horse_reference(pair, src)
    weapon = weapon_frames.measure(pair.A, pair.B, src, dst, cfg.get("weapon_frames", {})) if cfg.get("weapon_frames") else {}
    rt = Retargeter(pair, seat, stirrup_offset=stirrups, horse=horse, weapon=weapon)
    rt.src = src
    lib_name = cfg.get("library_name", "actor_a_rt")
    out = {"tool": TOOL_VERSION, "library_name": lib_name, "source_actor": "Actor_A", "target_actor": "Actor_B",
           "fps": src["fps"], "scale_s": pair.s, "stature_ratio": pair.stature_ratio,
           "align": pair.align_mode, "seat_offset": list(map(float, seat)),
           "stirrup_offset": {k: [float(x) for x in v] for k, v in rt.stirrup_offset.items()},
           "horse_reference": horse.as_dict(), "weapon_frames": weapon_frame_summary(weapon),
           "k_leg": pair.k_leg, "k_arm": pair.k_arm,
           "a_bind": {"clip": A_BIND_POSE, "native_asset_id": A_BIND_ASSET},
           "clips": {}}
    results = {}
    for entry in entries:
        name = entry["name"]
        clip = src["clips"][name]
        r = rt.retarget(name, clip, entry)
        results[name] = r
        if not entry.get("ship", True):
            continue
        meta = {k: clip["meta"][k] for k in META_KEYS if k in clip["meta"]}
        stamp = {"source_actor": "Actor_A", "source_clip": name,
                 "source_native_asset_id": clip["meta"].get("native_asset_id"),
                 "profile": entry.get("profile", "ground"), "tool": TOOL_VERSION,
                 "a_bind_pose": A_BIND_POSE, "a_bind_asset_id": A_BIND_ASSET,
                 "scale_s": round(pair.s, 5), "align": pair.align_mode}
        if "library_name" in cfg:
            stamp["library"] = lib_name
        for k in ("group", "use", "priority"):
            if k in entry:
                stamp[k] = entry[k]
        out["clips"][name] = {
            "length": clip["length"], "loop_mode": clip["loop_mode"], "frames": clip["frames"],
            "meta": meta, "tracks": r["tracks"], "diag": r["diag"], "retarget": stamp,
        }
    with open(args.out, "w") as f:
        json.dump(out, f)
    print(f"retarget: {len(results)} clips retargeted, {len(out['clips'])} shipped, s={pair.s:.4f}, "
          f"align={pair.align_mode}, seat={np.round(seat, 4)} -> {args.out}")
    return pair, rt, src, dst, cfg, results, out


REF_JOINTS = ["root", "pelvis", "heada", "l_wrist", "r_wrist", "r_hand_prop_attachment", "l_hand_prop_attachment",
              "l_knee", "r_knee", "l_ankle", "r_ankle", "l_ball", "r_ball"]


def godot_add2_pose(B, base_tracks, add_tracks, F):
    """Godot AnimationTree Add2 (amount 1) on the B rig: rotation base * rest^-1 * add,
    position base + (add - rest); channels a clip does not key read the rest."""
    P, R = B.local_arrays(base_tracks, F)
    for bn, ch in add_tracks.items():
        i = B.idx.get(bn)
        if i is None:
            continue
        if "rot" in ch:
            addR = q2m(np.asarray(ch["rot"], float))[:F]
            R[:, i] = R[:, i] @ B.rest_R[i].T @ addR
        if "pos" in ch:
            P[:, i] = P[:, i] + np.asarray(ch["pos"], float)[:F] - B.rest_pos[i]
    return B.fk(P, R)


def summarize(m):
    if "additive" in m:
        per = m["additive"]["per_bone"]
        out = {"bones": len(per), "max_delta_deg_A": max((v["A_max_deg"] for v in per.values()), default=0),
               "max_delta_deg_B": max((v["rt_max_deg"] for v in per.values()), default=0)}
        vs = [v["rt_vs_native_deg_median"] for v in per.values() if "rt_vs_native_deg_median" in v]
        if vs:
            out["native"] = m["additive"].get("native")
            out["rt_vs_native_median_deg_worst_bone"] = max(vs)
        return out
    fs = m["foot_slide_mps"]
    out = {"path_r2": m["path_dynamic"]["r2"], "path_dyn_rms_cm_median": m["path_dynamic"]["rms_cm_median"],
           "path_dyn_rms_cm_max": m["path_dynamic"]["rms_cm_max"], "vel_cos": m.get("vel_cos"),
           "seg_angle_deg_mean": m["seg_angle_deg"]["mean"], "seg_angle_deg_p95": m["seg_angle_deg"]["p95"],
           "foot_slide_median_mps": {"A_scaled": fs["A_scaled"]["median"], "B": fs["B_ik"]["median"],
                                     "B_no_ik": fs.get("B_no_ik", {}).get("median")},
           "planted_fraction": m["planted_fraction"],
           "intersect_B_max_cm": {k: v["max_cm"] for k, v in m["intersect"]["B"].items()},
           "intersect_A_max_cm": {k: v["max_cm"] for k, v in m["intersect"]["A"].items()},
           "ik_residual_max_m": {k: v["max"] for k, v in m["ik_residual_m"].items()}}
    if "native" in m:
        out["native"] = {"clip": m["native"]["clip"],
                         "mean_offset_cm": {k: v["rt_minus_native_cm"] for k, v in m["native"]["mean_offsets"].items()}}
    return out


def write_manifest(path, args, pair, rt, src, dst, cfg, results, out, rep):
    B = pair.B
    man = {"tool": TOOL_VERSION, "library_name": out.get("library_name", "actor_a_rt"), "source_actor": "Actor_A", "target_actor": "Actor_B",
           "source_library": "Actor_A.res",
           "a_bind": {"clip": A_BIND_POSE, "native_asset_id": A_BIND_ASSET,
                      "evidence": "equals null-add on its 40 channels; constant bone offsets of the clips; single-axis hinges"},
           "scale_s": round(pair.s, 5), "stature_ratio": round(pair.stature_ratio, 5), "hand_ratio": round(pair.k_hand, 5),
           "align": pair.align_mode, "seat_offset_m": [round(float(x), 5) for x in rt.seat_offset],
           "stirrup_offset_m": {k: [round(float(x), 5) for x in v] for k, v in rt.stirrup_offset.items()},
           "clips": {}, "add2_reference": []}
    for entry in cfg["clips"]:
        name = entry["name"]
        if name not in out["clips"]:
            continue
        r = results[name]
        c = out["clips"][name]
        rec = {"group": entry.get("group"), "profile": entry.get("profile", "ground"),
               "native_asset_id": c["meta"].get("native_asset_id"), "original_name": c["meta"].get("original_name"),
               "source_library": c["meta"].get("source_library"), "additive": c["diag"].get("additive", False),
               "frames": c["frames"], "length": c["length"], "tracks_out": len(c["tracks"])}
        if rep is not None:
            rec["metrics"] = summarize(rep["clips"][name])
        if "GPB" in r:
            F = c["frames"]
            fr = sorted(set([0, F // 2, F - 1]))
            rec["reference"] = {"frames": fr, "joints": {j: np.round(r["GPB"][fr, B.idx[j]], 5).tolist() for j in REF_JOINTS}}
        man["clips"][name] = rec
    for base, add in cfg.get("add2_checks", []):
        bt, at = out["clips"][base]["tracks"], out["clips"][add]["tracks"]
        F = min(out["clips"][base]["frames"], out["clips"][add]["frames"])
        GP, _ = godot_add2_pose(B, bt, at, F)
        fr = sorted(set([0, F // 2, F - 1]))
        man["add2_reference"].append({"base": base, "add": add, "frames": fr,
                                      "joints": {j: np.round(GP[fr, B.idx[j]], 5).tolist() for j in REF_JOINTS}})
    if rep is not None:
        man["add2_identity_max_deg"] = rep.get("add2_identity_max_deg")
    with open(path, "w") as f:
        json.dump(man, f, indent=1)
    print("manifest ->", path)


def add2_references(pair, cfg, out):
    B = pair.B
    refs = []
    for base, add in cfg.get("add2_checks", []):
        if base not in out["clips"] or add not in out["clips"]:
            continue
        bt, at = out["clips"][base]["tracks"], out["clips"][add]["tracks"]
        F = min(out["clips"][base]["frames"], out["clips"][add]["frames"])
        GP, _ = godot_add2_pose(B, bt, at, F)
        fr = sorted(set([0, F // 2, F - 1]))
        refs.append({"base": base, "add": add, "frames": fr,
                     "joints": {j: np.round(GP[fr, B.idx[j]], 5).tolist() for j in REF_JOINTS}})
    return refs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dst", required=True)
    ap.add_argument("--config", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--report", help="metrics report (metrics.py, + checks.py when the config names a library)")
    ap.add_argument("--manifest", help="library manifest (provenance, usage metadata, checks, FK reference)")
    ap.add_argument("--test-ref", help="Actor_A reference data for the Godot test (checks.py)")
    args = ap.parse_args()
    pair, rt, src, dst, cfg, results, out = run(args)
    production = "library_name" in cfg
    rep = None
    chk = None
    if args.report or args.manifest:
        from metrics import build_report
        rep = build_report(pair, rt, src, dst, cfg, results)
    if production and (args.report or args.manifest or args.test_ref):
        import checks
        chk = checks.build_checks(pair, rt, src, dst, cfg, results, out)
        if rep is not None:
            rep["checks"] = chk
        print("checks: %d clips, %d seams, %d failing items" % (len(chk["clips"]), len(chk["seams"]), len(chk["fails"])))
        for k, v in chk["fails"].items():
            print("  CHECK", k, v)
    if args.report:
        with open(args.report, "w") as f:
            json.dump(rep, f, indent=1)
        print("report ->", args.report)
    if args.manifest:
        if production:
            import checks
            checks.write_manifest(args.manifest, TOOL_VERSION, pair, rt, cfg, results, out, chk)
            man = json.load(open(args.manifest))
            man["add2_reference"] = add2_references(pair, cfg, out)
            man["add2_identity_max_deg"] = rep.get("add2_identity_max_deg")
            with open(args.manifest, "w") as f:
                json.dump(man, f, indent=1)
        else:
            write_manifest(args.manifest, args, pair, rt, src, dst, cfg, results, out, rep)
    if args.test_ref and production:
        import checks
        checks.write_test_ref(args.test_ref, pair, rt, cfg, results, out, chk)


if __name__ == "__main__":
    main()
