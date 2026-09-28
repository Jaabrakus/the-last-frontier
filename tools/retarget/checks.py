"""Validation of the Actor_A -> Actor_B batch retarget (library `actor_b_from_a`).

Called by retarget.py (--checks / --manifest / --test-ref). Everything is measured on the
tool's own forward kinematics here; tests/retarget/test_actor_b_from_a.gd measures the same
quantities again on the shipped AnimationLibrary in Godot, against the Actor_A reference
data written by write_test_ref().

Per clip (non-additive):
  path       joint paths relative to the pelvis (12 joints), B vs anchor-scaled A, each
             joint's mean offset removed: r2, dynamic RMS, speed-weighted velocity cosine
             (metrics.py definitions)
  contacts   horizontal slide of every contact point while A has it on the ground:
             heels / balls (ground clips: within 3 cm of the bind contact height and slower
             than 0.25 m/s in A), planted hands (wrist < 12 cm), knees (< 6 cm); A scaled vs B
  floor      ground clips: B's lowest heel / ball against A's lowest, and per frame every heel,
             ball and ankle at least min(A's scaled height on that frame, 0) - 1.5 cm (heights
             above the bind contact height)
  props      world rotation of each keyed hand prop bone, B vs A in the library's weapon frame
             (deg; the two-handed pipe clips, whose roll is set from the right palm: the weapon
             axis); two-handed grips: off palm in the source's prop frame, B vs A (cm, frames the
             grip is held); one-handed left prop following the right prop (cm)
  weapon     two-handed families: the off palm's place along the weapon (+Z) and no swapped ends
             (the right palm is not below the left one); guard clips: the +Z end of a 1.8 m spear
             held at its butt stays above the floor; the in-palm roll equals the canonical grip's
             (pipe and guard clips). Guard clips with a synthetic weapon frame, on the frames A holds
             with both hands (fist span <= 0.5 m): the off hand's grip point on the weapon axis, the
             off hand's grip point relative to the right one against A's scaled by s (the fist
             centres reported too), the weapon axis against the line through A's grip points (the
             fist-centre line reported), and the fist centres' separation along the axis
  joints     signed hinge flexion (elbows / knees, 0 = straight, flexion negative): B never more
             than 3 deg past straight where A is not (fully folded joints, |flexion| > 170, are
             sign-free); flexion speed B <= max(1.5 x A, A + 8 deg) + 1 deg per frame; straight source
             knees and elbows (A < 12 deg): B's extra bend; per-frame local rotation step of every
             keyed bone B <= A + 15 deg; wrist swing (bend away from the forearm, twist removed, from
             the bind) B <= A + 20 deg
  continuity largest frame-to-frame joint step of B against A's scaled step (30 fps), and
             for real loops (config loop: true) the B seam (first vs last frame)
  mount      the push-off foot under the documented runtime recipe (clip origin at the saddle
             attach point, shifted down by (attach height - reference_saddle_height) x
             (1 - ground_to_saddle)) for several saddle heights: ball height above the floor and
             horizontal slide over the push-off window; every ground contact of the ground phase
             (the planted ball, the standing feet of frame 0) within -2 / +1 cm of its bind
             contact height
Across clips:
  seams      every ordered pair (X end -> Y start) whose Actor_A pose distance is < 5 cm,
             plus the intro -> hit / start -> loop -> stop pairs by name: the B pose distance
             must stay within A's (scaled) + 2 cm
  weapon seams  the config's `weapon_seams` (guard <-> haft sweep <-> blocked <-> butt stroke):
             how far the weapon turns in the right hand across the seam (swing and roll: a jump
             of the weapon frame, not of the pose), its roll alone, the source's own turn of the
             haft in the right hand, and its world direction change against the hands' line
Pose distance = RMS over 9 joints (head, wrists, elbows, knees, ankles) relative to the pelvis
in the hips' heading frame, plus the pelvis height difference.
"""
import json
import re

import numpy as np

from metrics import JOINTS, FPS, clip_metrics
from rtmath import m2q, rot_between

SEAM_JOINTS = ["heada", "l_wrist", "r_wrist", "l_elbow", "r_elbow", "l_knee", "r_knee", "l_ankle", "r_ankle"]
PROPS = ("l_hand_prop_attachment", "r_hand_prop_attachment")
FOOT_POINTS = ["l_heel", "l_ball", "r_heel", "r_ball"]
FLOOR_POINTS = ["l_heel", "l_ball", "l_ankle", "r_heel", "r_ball", "r_ankle"]
FIST = ("_indexa", "_middlea", "_ringa", "_pinkya", "_palm")
CONTACT_SLOW = 0.25
REF_JOINTS = ["root", "pelvis", "heada", "l_wrist", "r_wrist", "r_hand_prop_attachment", "l_hand_prop_attachment",
              "l_knee", "r_knee", "l_ankle", "r_ankle", "l_ball", "r_ball"]
# hinge -> (chain root, chain end, local hinge axis)
HINGE = {"l_elbow": ("l_shoulder", "l_wrist", 1), "r_elbow": ("r_shoulder", "r_wrist", 1),
         "l_knee": ("l_upper_leg", "l_ankle", 0), "r_knee": ("r_upper_leg", "r_ankle", 0)}
STEP_BONES = ["l_shoulder", "l_elbow", "l_wrist", "r_shoulder", "r_elbow", "r_wrist",
              "l_upper_leg", "l_knee", "l_ankle", "r_upper_leg", "r_knee", "r_ankle"]
TWO_HAND_GROUPS = ("musket-butt", "two-hand-guard", "two-hand-club")
SPEAR_L = 1.8
MOUNT_ATTACH_M = (1.37, 1.4961, 1.60)  # saddle heights the mount recipe is checked at (1.4961: assets/horse)


def _j(rig, GP, n):
    return GP[:, rig.idx[n]]


def heading_frame(rig, GP, f):
    """Rotation (3x3) whose columns are the hips' heading frame at frame f (yaw only)."""
    d = GP[f, rig.idx["l_upper_leg"]] - GP[f, rig.idx["r_upper_leg"]]
    left = np.array([d[0], 0.0, d[2]])
    left /= max(np.linalg.norm(left), 1e-9)
    up = np.array([0.0, 1.0, 0.0])
    fwd = np.cross(left, up)
    return np.stack([left, up, fwd], 1)


def pose_vec(rig, GP, f, scale=1.0):
    H = heading_frame(rig, GP, f)
    pel = GP[f, rig.idx["pelvis"]]
    rel = np.array([(GP[f, rig.idx[j]] - pel) @ H for j in SEAM_JOINTS]) * scale
    return rel, pel[1] * scale


def pose_dist(a, b):
    (ra, ha), (rb, hb) = a, b
    return float(np.sqrt(np.mean(np.sum((ra - rb) ** 2, 1)) + (ha - hb) ** 2))


def _slide(GP, rig, pt, mask, scale=1.0):
    x = GP[:, rig.idx[pt]][:, [0, 2]] * scale
    v = np.linalg.norm(np.diff(x, axis=0), axis=1) * FPS
    m = mask[1:] & mask[:-1]
    return v[m]


def _ang(R):
    return np.degrees(np.arccos(np.clip((np.trace(R, axis1=-2, axis2=-1) - 1) / 2, -1, 1)))


def signed_flex(rig, GP, GR, j):
    """Signed hinge flexion (deg): the angle between the upper and lower segment, negative on the
    joint's flexion side (retarget.FLEX_SIGN), 0 = straight."""
    a, c, ax = HINGE[j]
    u = GP[:, rig.idx[j]] - GP[:, rig.idx[a]]
    v = GP[:, rig.idx[c]] - GP[:, rig.idx[j]]
    f = np.degrees(np.arccos(np.clip(np.sum(u * v, 1) / (np.linalg.norm(u, axis=1) * np.linalg.norm(v, axis=1)), -1, 1)))
    return f * np.sign(np.sum(np.cross(u, v) * GR[:, rig.idx[j]][:, :, ax], 1))


def wrist_swing(rig, GR, R0, s):
    """Wrist bend away from the forearm (deg), twist about the forearm (local Z) removed, from the bind."""
    e, w = rig.idx[s + "_elbow"], rig.idx[s + "_wrist"]
    L = np.einsum("fji,fjk->fik", GR[:, e], GR[:, w])
    q = m2q(np.einsum("fij,kj->fik", L, R0[e].T @ R0[w]))
    tw = np.stack([np.zeros(len(q)), np.zeros(len(q)), q[:, 2], q[:, 3]], -1)
    tw /= np.maximum(np.linalg.norm(tw, axis=1, keepdims=True), 1e-9)
    return np.degrees(2 * np.arccos(np.clip(np.abs(q[:, 3] * tw[:, 3] + q[:, 2] * tw[:, 2]), 0, 1)))


def fist_centre(rig, GP, s):
    """Fist centre: mean of the four finger bases and the palm (the review's definition)."""
    return GP[:, [rig.idx[s + x] for x in FIST]].mean(1)


def roll_from_canonical(Rin, Mc):
    """Roll (deg, signed) of in-palm prop rotations Rin (F,3,3) about their own +Z against the minimal swing
    of the canonical grip Mc onto the same axis: 0 = the library's roll convention (roll from the right palm)."""
    z = Rin[:, :, 2]
    Rs = np.einsum("fij,jk->fik", rot_between(np.broadcast_to(Mc[:, 2], z.shape), z), Mc)
    T = np.einsum("fji,fjk->fik", Rs, Rin)
    return np.degrees(np.arctan2(T[:, 1, 0], T[:, 0, 0]))


def roll_between(Ra, Rb):
    """Roll (deg) between two in-palm rotations: the twist about Rb's +Z left after swinging Ra's +Z onto it."""
    Rs = rot_between(Ra[:, 2], Rb[:, 2]) @ Ra
    T = Rs.T @ Rb
    return float(abs(np.degrees(np.arctan2(T[1, 0], T[0, 0]))))


def local_steps(rig, GR, bones):
    """Per-frame local rotation step (deg) of each bone: (F-1,) per bone."""
    out = {}
    for b in bones:
        i = rig.idx[b]
        par = rig.parent[i]
        L = GR[:, i] if par < 0 else np.einsum("fji,fjk->fik", GR[:, par], GR[:, i])
        out[b] = _ang(np.einsum("fji,fjk->fik", L[:-1], L[1:]))
    return out


def contact_masks(pair, entry, GPA, k):
    """A-side contact frames per point (see module doc)."""
    A = pair.A
    F = GPA.shape[0]
    masks = {}
    ground = entry.get("profile", "ground") == "ground"

    def slow(pt):
        v = np.zeros(F)
        if F > 1:
            v[1:] = np.linalg.norm(np.diff(GPA[:, A.idx[pt]][:, [0, 2]] * k[:, None], axis=0), axis=1) * FPS
            v[0] = v[1]
        return v < CONTACT_SLOW

    if ground:
        for pt in FOOT_POINTS:
            y = GPA[:, A.idx[pt], 1] - pair.PA0[A.idx[pt], 1]
            masks[pt] = (y <= 0.03) & slow(pt)
        for s in "lr":
            masks[s + "_wrist"] = (GPA[:, A.idx[s + "_wrist"], 1] < 0.12) & slow(s + "_wrist")
            masks[s + "_knee"] = (GPA[:, A.idx[s + "_knee"], 1] < 0.06) & slow(s + "_knee")
    return {kk: v for kk, v in masks.items() if v.sum() >= 3}


def joint_checks(pair, r, src_clip, profile):
    """Hinge sign, flexion speed, straight knees, local rotation steps and wrist swing (module doc)."""
    A, B = pair.A, pair.B
    GPA, GRA = r["GPA"], r["GRA"]
    F = GPA.shape[0]
    P, R = B.local_arrays(r["tracks"], F)
    GPB, GRB = B.fk(P, R)
    keyed = {b for b, ch in src_clip["tracks"].items() if "rot" in ch}
    out = {"hinge": {}, "wrist": {}}
    for j, (a, c, _) in HINGE.items():
        if not {a, j} <= keyed:
            continue
        fa, fb = signed_flex(A, GPA, GRA, j), signed_flex(B, GPB, GRB, j)
        folded = (np.abs(fa) > 170) & (np.abs(fb) > 170)
        hyper = (fb > 3.0) & (fa <= 3.0) & ~folded
        row = {"hyper_frames": int(hyper.sum()), "B_max_deg": round(float(np.where(folded, -180, fb).max()), 1),
               "A_max_deg": round(float(np.where(folded, -180, fa).max()), 1)}
        if F > 2:
            da, db = np.abs(np.diff(np.abs(fa))), np.abs(np.diff(np.abs(fb)))
            ex = db - np.maximum(1.5 * da, da + 8.0)
            row["flex_speed_excess_deg"] = round(float(max(ex.max(), 0.0)), 1)
        if True:  # straight source limbs (knees and elbows): B's extra bend where A is within 12 deg of straight
            m = np.abs(fa) < 12.0
            extra = (np.abs(fb) - np.abs(fa))[m]
            row["straight_frames"] = int(m.sum())
            row["straight_extra_bend_max_deg"] = round(float(extra.max()), 1) if m.any() else 0.0
            row["straight_frames_over8"] = int((extra > 8).sum()) if m.any() else 0
        out["hinge"][j] = row
    if F > 2:
        bones = [b for b in STEP_BONES if b in keyed]
        sa, sb = local_steps(A, GRA, bones), local_steps(B, GRB, bones)
        worst = (0.0, "", 0)
        for b in bones:
            ex = sb[b] - sa[b]
            if ex.max() > worst[0]:
                worst = (float(ex.max()), b, int(np.argmax(ex)) + 1)
        out["rot_step_excess"] = {"max_deg": round(worst[0], 1), "bone": worst[1], "frame": worst[2]}
    for s in "lr":
        if {s + "_elbow", s + "_wrist"} <= keyed:
            wa, wb = wrist_swing(A, GRA, pair.RA0, s), wrist_swing(B, GRB, pair.RB0, s)
            out["wrist"][s] = {"excess_max_deg": round(float((wb - wa).max()), 1), "A_max_deg": round(float(wa.max()), 1),
                               "B_max_deg": round(float(wb.max()), 1)}
    return out


def weapon_checks(pair, rt, entry, r, src_clip):
    """Two-handed weapon frame (module doc)."""
    B = pair.B
    F = r["GPA"].shape[0]
    P, R = B.local_arrays(r["tracks"], F)
    GP, GR = B.fk(P, R)
    ip = B.idx[PROPS[1]]
    O, Z = GP[:, ip], GR[:, ip, :, 2]
    gw = r.get("grip_w")
    held = (gw > 0.9) if gw is not None else np.zeros(F, bool)
    out = {}
    al = {s: np.sum((GP[:, B.idx[s + "_palm"]] - O) * Z, 1) for s in "lr"}
    if held.any():
        out["l_palm_along_m"] = [round(float(np.percentile(al["l"][held], 5)), 3), round(float(np.median(al["l"][held])), 3),
                                 round(float(np.percentile(al["l"][held], 95)), 3)]
        out["r_palm_along_m"] = round(float(np.median(al["r"][held])), 3)
        out["ends_swapped_frames"] = int((al["r"][held] < al["l"][held] - 0.05).sum())
    if "synthetic_grip" in r["diag"] and rt.grips_B is not None:
        ibP = B.idx["l_palm"]
        c = GP[:, ibP] + np.einsum("fij,j->fi", GR[:, ibP], rt.grips_B["l"]["point"])
        d = c - O
        off = np.linalg.norm(d - np.sum(d * Z, 1, keepdims=True) * Z, axis=1)
        if held.any():
            out["axis_grip_err_cm_max"] = round(float(off[held].max()) * 100, 2)
            out["axis_grip_frames"] = int(held.sum())
            # against the source's two hands (held = A's fist span <= 0.5 m): the off hand's grip point
            # relative to the right one vs A's scaled by s; the weapon axis vs A's grip-point line (the
            # line through the fist centres is reported too: in the keyed haft clips it lies 20-38 deg off
            # the keyed axis, the grip-point line 3-10 deg); fist centres apart along the axis
            A, GPA, GRA, tw = pair.A, r["GPA"], r["GRA"], rt.weapon["two_hand"]
            gA = {s: GPA[:, A.idx[s + "_palm"]] + np.einsum("fij,j->fi", GRA[:, A.idx[s + "_palm"]], np.asarray(tw["grip_%s_point" % s]))
                  for s in "lr"}
            gB = {s: GP[:, B.idx[s + "_palm"]] + np.einsum("fij,j->fi", GR[:, B.idx[s + "_palm"]], rt.grips_B[s]["point"]) for s in "lr"}
            fA = {s: fist_centre(A, GPA, s) for s in "lr"}
            fB = {s: fist_centre(B, GP, s) for s in "lr"}
            disp = np.linalg.norm((gB["l"] - gB["r"]) - pair.s * (gA["l"] - gA["r"]), axis=1)[held]
            dispf = np.linalg.norm((fB["l"] - fB["r"]) - pair.s * (fA["l"] - fA["r"]), axis=1)[held]
            cosd = lambda u, v: np.degrees(np.arccos(np.clip(np.sum(u * v, 1) / (np.linalg.norm(u, axis=1) * np.linalg.norm(v, axis=1)), -1, 1)))  # noqa: E731
            axg = cosd(Z, gA["r"] - gA["l"])[held]
            axf = cosd(Z, fA["r"] - fA["l"])[held]
            sep = np.sum((fB["r"] - fB["l"]) * Z, 1)[held]
            out["offhand_vs_source_cm"] = [round(float(np.median(disp)) * 100, 2), round(float(disp.max()) * 100, 2)]
            out["offhand_vs_source_fist_cm"] = [round(float(np.median(dispf)) * 100, 2), round(float(dispf.max()) * 100, 2)]
            out["axis_vs_source_grip_line_deg"] = [round(float(np.median(axg)), 1), round(float(axg.max()), 1)]
            out["axis_vs_source_fist_line_deg"] = [round(float(np.median(axf)), 1), round(float(axf.max()), 1)]
            out["fist_sep_along_axis_min_m"] = round(float(sep.min()), 3)
    if rt.grips_B is not None and ("synthetic_grip" in r["diag"] or "prop_roll" in r["diag"]):
        Rin = np.einsum("fji,fjk->fik", GR[:, B.idx["r_palm"]], GR[:, ip])
        out["in_palm_roll_dev_deg_max"] = round(float(np.abs(roll_from_canonical(Rin, rt.grips_B["r"]["rot"])).max()), 2)
    if entry.get("group") == "two-hand-guard":
        tip = O + Z * (SPEAR_L - 0.08)
        m = held if held.any() else np.ones(F, bool)
        out["spear_tip_min_y_m"] = round(float(tip[m, 1].min()), 3)
    return out


def mount_checks(pair, r):
    """Push-off foot under the runtime mount recipe (module doc)."""
    B = pair.B
    d = r["diag"].get("mount_align")
    if not d:
        return None
    F = r["GPA"].shape[0]
    P, R = B.local_arrays(r["tracks"], F)
    GP, _ = B.fk(P, R)
    g2s = np.asarray(d["ground_to_saddle"], float)
    ref_h = d["reference_saddle_height_m"]
    foot = d["push_off_foot"]
    w0, w1 = d["push_off_frames"]
    out = {"push_off_foot": foot, "window": [w0, w1], "reference_saddle_height_m": ref_h, "at": {}}
    for att in sorted(set([round(ref_h, 4)] + list(MOUNT_ATTACH_M))):
        W = GP.copy()
        W[:, :, 1] += att - (att - ref_h) * (1 - g2s)[:, None]  # floor at 0
        row = {}
        for pt in ("ball", "heel"):
            j = B.idx[foot + "_" + pt]
            y = W[w0:w1 + 1, j, 1] - pair.PB0[j, 1]
            v = np.linalg.norm(np.diff(W[w0:w1 + 1, j][:, [0, 2]], axis=0), axis=1) * FPS
            row[pt] = {"min_y_cm": round(float(y.min()) * 100, 2), "slide_max_mps": round(float(v.max()), 3)}
        gc = {}
        for pt, frames in (d.get("ground_contacts") or {}).items():
            j = B.idx[pt]
            y = W[frames, j, 1] - pair.PB0[j, 1]
            gc[pt] = [round(float(y.min()) * 100, 2), round(float(y.max()) * 100, 2)]
        if gc:
            row["ground_contacts_cm"] = gc
        out["at"]["%.4f" % att] = row
    return out


def clip_checks(pair, rt, name, entry, r, src_clip):
    A, B = pair.A, pair.B
    GPA, GRA, GPB, GRB = r["GPA"], r["GRA"], r["GPB"], r["GRB"]
    F = GPA.shape[0]
    w = r["w_pel"]
    k = w * pair.s + (1 - w)
    skip = tuple(p for p in PROPS if not ("rot" in src_clip["tracks"].get(p, {})))
    m = clip_metrics(pair, rt, name, entry, r, src_clip, skip=skip)
    out = {"path": {"r2": m["path_dynamic"]["r2"], "dyn_rms_cm_median": m["path_dynamic"]["rms_cm_median"],
                    "dyn_rms_cm_max": m["path_dynamic"]["rms_cm_max"], "vel_cos": m.get("vel_cos")},
           "seg_angle_deg_mean": m["seg_angle_deg"]["mean"],
           "intersect_B_max_cm": {kk: v["max_cm"] for kk, v in m["intersect"]["B"].items()},
           "intersect_A_max_cm": {kk: v["max_cm"] for kk, v in m["intersect"]["A"].items()}}
    # contacts
    cm = contact_masks(pair, entry, GPA, k)
    cs = {}
    for pt, msk in cm.items():
        va, vb = _slide(GPA, A, pt, msk, float(np.median(k))), _slide(GPB, B, pt, msk)
        if len(va) >= 5:
            row = {"frames": int(msk.sum()), "A_mps": round(float(np.median(va)), 3), "B_mps": round(float(np.median(vb)), 3)}
            if pt.endswith(("_wrist", "_knee")):
                ya = GPA[msk, A.idx[pt], 1] * pair.s
                yb = GPB[msk, B.idx[pt], 1]
                row["height_err_cm_median"] = round(float(np.median(yb - ya)) * 100, 1)
                row["height_err_cm_p90"] = round(float(np.percentile(np.abs(yb - ya), 90)) * 100, 1)
            cs[pt] = row
    out["contacts"] = cs
    # floor (ground clips): lowest heel / ball relative to the bind contact height
    if entry.get("profile", "ground") == "ground" and "root" in src_clip["tracks"]:
        la = min(float((GPA[:, A.idx[p], 1] - pair.PA0[A.idx[p], 1]).min()) for p in FOOT_POINTS)
        lb = min(float((GPB[:, B.idx[p], 1] - pair.PB0[B.idx[p], 1]).min()) for p in FOOT_POINTS)
        out["floor_lowest_cm"] = {"A": round(la * 100, 1), "B": round(lb * 100, 1)}
        # per frame: heel, ball and ankle of B at least min(A's scaled height on that frame, 0) - 1.5 cm
        worst = (1e9, "", -1)
        for pt in FLOOR_POINTS:
            ha = (GPA[:, A.idx[pt], 1] - pair.PA0[A.idx[pt], 1]) * pair.s
            hb = GPB[:, B.idx[pt], 1] - pair.PB0[B.idx[pt], 1]
            mg = hb - (np.minimum(ha, 0.0) - 0.015)
            if mg.min() < worst[0]:
                worst = (float(mg.min()), pt, int(np.argmin(mg)))
        out["floor_per_frame"] = {"min_margin_cm": round(worst[0] * 100, 2), "point": worst[1], "frame": worst[2]}
    # props
    keyed = src_clip["tracks"]
    pr = {}
    Pe, Re = B.local_arrays(r["tracks"], F)
    _, GRe = B.fk(Pe, Re)  # emitted tracks (after the loop closing)
    for p in PROPS:
        if p in keyed and "rot" in keyed[p]:
            if p == PROPS[1] and "prop_roll" in r["diag"]:
                # roll set from the right palm: the weapon axis keeps the source's world direction
                za, zb = GRA[:, A.idx[p], :, 2], GRe[:, B.idx[p], :, 2]
                ang = np.degrees(np.arccos(np.clip(np.sum(za * zb, 1), -1, 1)))
                pr[p + "_world_axis_err_deg"] = round(float(ang.max()), 3)
            elif p == PROPS[0] and "prop_roll" in r["diag"] and r["diag"].get("left_prop") == "follow":
                # a left prop riding on the rolled weapon: its rotation relative to the right prop is the source's
                relA = np.einsum("fji,fjk->fik", GRA[:, A.idx[PROPS[1]]], GRA[:, A.idx[p]])
                relB = np.einsum("fji,fjk->fik", GRe[:, B.idx[PROPS[1]]], GRe[:, B.idx[p]])
                pr[p + "_follow_rot_err_deg"] = round(float(_ang(np.einsum("fji,fjk->fik", relA, relB)).max()), 3)
            else:
                ang = _ang(np.einsum("fji,fjk->fik", GRA[:, A.idx[p]], GRe[:, B.idx[p]]))
                pr[p + "_world_rot_err_deg"] = round(float(ang.max()), 3)
    gw = r.get("grip_w")
    if entry.get("offhand") and gw is not None and (gw > 0.9).any() and "synthetic_grip" not in r["diag"]:
        off = entry["offhand"]
        mp = PROPS[1] if off == "l" else PROPS[0]
        palm = off + "_palm"
        # both in the source's prop frame (B's keyed prop has A's world rotation, apart from the pipe
        # clips' roll, which is set from the right palm; the grip is compared without it)
        ra = np.einsum("fji,fj->fi", GRA[:, A.idx[mp]], GPA[:, A.idx[palm]] - GPA[:, A.idx[mp]])
        rb = np.einsum("fji,fj->fi", GRA[:, A.idx[mp]], GPB[:, B.idx[palm]] - GPB[:, B.idx[mp]])
        e = np.linalg.norm(ra - rb, axis=1)[gw > 0.9]
        pr["offhand_grip_err_cm_max"] = round(float(e.max()) * 100, 2)
        pr["grip_held_frames"] = int((gw > 0.9).sum())
    if r["diag"].get("left_prop") == "follow":
        ra = np.einsum("fji,fj->fi", GRA[:, A.idx[PROPS[1]]], GPA[:, A.idx[PROPS[0]]] - GPA[:, A.idx[PROPS[1]]])
        rb = np.einsum("fji,fj->fi", GRB[:, B.idx[PROPS[1]]], GPB[:, B.idx[PROPS[0]]] - GPB[:, B.idx[PROPS[1]]])
        pr["left_prop_follow_err_cm_max"] = round(float(np.linalg.norm(ra - rb, axis=1).max()) * 100, 2)
    if pr:
        out["props"] = pr
    if entry.get("group") in TWO_HAND_GROUPS and "prop_far_from_palm_m" not in r["diag"]:
        out["weapon"] = weapon_checks(pair, rt, entry, r, src_clip)
    # joints
    out["joints"] = joint_checks(pair, r, src_clip, entry.get("profile", "ground"))
    # continuity (the prop joint is left out where the library adds prop tracks the source does not key)
    jn = [j for j in JOINTS if not (j in PROPS and j not in keyed)]
    stepA = np.linalg.norm(np.diff(np.stack([_j(A, GPA, j) for j in jn], 1) * k[:, None, None], axis=0), axis=2) if F > 1 else np.zeros((1, 1))
    stepB = np.linalg.norm(np.diff(np.stack([_j(B, GPB, j) for j in jn], 1), axis=0), axis=2) if F > 1 else np.zeros((1, 1))
    exc = stepB - (1.25 * stepA)
    out["continuity"] = {"max_step_cm_A": round(float(stepA.max()) * 100, 1), "max_step_cm_B": round(float(stepB.max()) * 100, 1),
                         "max_excess_cm": round(float(max(exc.max(), 0.0)) * 100, 1)}
    if r.get("loop"):  # on the emitted tracks (the seam is closed by the tool)
        P, R = B.local_arrays(r["tracks"], F)
        GPe, _ = B.fk(P, R)
        out["continuity"]["loop_seam_cm_B"] = round(pose_dist(pose_vec(B, GPe, 0), pose_vec(B, GPe, F - 1)) * 100, 3)
        out["continuity"]["loop_seam_cm_B_before_closing"] = round(pose_dist(pose_vec(B, GPB, 0), pose_vec(B, GPB, F - 1)) * 100, 2)
        out["continuity"]["loop_seam_cm_A"] = round(pose_dist(pose_vec(A, GPA, 0, k[0]), pose_vec(A, GPA, F - 1, k[-1])) * 100, 2)
    mc = mount_checks(pair, r)
    if mc:
        out["mount"] = mc
    return out


def seam_pairs(names):
    """Chains the designs play back to back (intro -> hit, start -> loop -> stop, ...)."""
    s = set(names)
    pairs = []
    for n in names:
        for suf, rep in (("-far-intro", ""), ("-intro", ""), ("-hit-intro", "-hit")):
            if n.endswith(suf):
                t = n[: -len(suf)] + rep
                if t in s:
                    pairs.append((n, t))
        m = re.match(r"(.*)downed-idle\^crawl-(.*)$", n)
        if m and "downed-crawl-" + m.group(2) in s:
            pairs.append((n, "downed-crawl-" + m.group(2)))
        m = re.match(r"downed-crawl-(.*)$", n)
        if m and "^" not in n and n + "^idle" in s:
            pairs.append((n, n + "^idle"))
            pairs.append((n, n))
    for a, b in (("fist-block-cycle-intro", "fist-block-cycle"), ("fist-block-cycle", "fist-block-hit"),
                 ("fist-block-hit", "fist-block-cycle"), ("fist-block-cycle", "fist-block-cycle-exit"),
                 ("pipe-block-intro", "pipe-block-cycle"), ("pipe-block-cycle", "pipe-block-hit"),
                 ("pipe-block-hit", "pipe-block-cycle"), ("pipe-block-cycle", "pipe-block-exit"),
                 ("actor_a-horse-jump-across-5m", "actor_a-horse-jump-across-5m-land")):
        if a in s and b in s:
            pairs.append((a, b))
    return list(dict.fromkeys(pairs))


def seams(pair, results, names, auto_tol=0.05):
    """Cross-clip seam distances, A (scaled) and B."""
    A, B = pair.A, pair.B
    ends, starts = {}, {}
    for n in names:
        r = results[n]
        if "GPB" not in r or r["GPA"].shape[0] < 2:
            continue
        F = r["GPA"].shape[0]
        ka = [r["w_pel"][i] * pair.s + (1 - r["w_pel"][i]) for i in (0, F - 1)]
        starts[n] = (pose_vec(A, r["GPA"], 0, ka[0]), pose_vec(B, r["GPB"], 0))
        ends[n] = (pose_vec(A, r["GPA"], F - 1, ka[1]), pose_vec(B, r["GPB"], F - 1))
    named = set(seam_pairs(list(starts)))
    out = []
    for a in ends:
        for b in starts:
            da = pose_dist(ends[a][0], starts[b][0])
            if (a, b) in named or da < auto_tol:
                db = pose_dist(ends[a][1], starts[b][1])
                out.append({"from": a, "to": b, "A_cm": round(da * 100, 2), "B_cm": round(db * 100, 2),
                            "named": (a, b) in named})
    return out


def weapon_seams(pair, rt, results, pairs):
    """Weapon frame across the config's weapon seams (module doc):
    - `in_hand_deg`: the whole turn of the weapon relative to the right palm (swing and roll), i.e. the
      frame jumping in the hand; `in_hand_axis_deg` its axis alone and `in_hand_roll_deg` the roll about
      the weapon's own axis left after swinging the axis across;
    - `source_in_hand_deg`: the same axis turn in the source (A's keyed prop axis, or for clips that key
      no prop the line through A's grip points, in A's right palm);
    - `world_deg` / `hands_deg`: world direction change of the weapon / of the line between the palms;
      `pose_A_cm`: the source's own pose distance at that seam.
    `status`: `same_grip`; `regrip (source)` where a same-grip seam turns the weapon more than 45 deg in the
    hand because the source's own hands turn the haft that far (reported); config regrips as named."""
    A, B = pair.A, pair.B
    ip, rp, lp = B.idx[PROPS[1]], B.idx["r_palm"], B.idx["l_palm"]
    tw = rt.weapon.get("two_hand") if rt.weapon else None
    out = []

    def end(n, last):
        r = results[n]
        F = r["GPA"].shape[0]
        P, R = B.local_arrays(r["tracks"], F)
        GP, GR = B.fk(P, R)
        f = F - 1 if last else 0
        ka = r["w_pel"][f] * pair.s + (1 - r["w_pel"][f])
        GPA, GRA = r["GPA"], r["GRA"]
        Ra = GRA[f, A.idx["r_palm"]]
        if "rot" in r["src_keyed"].get(PROPS[1], ()):
            zs = Ra.T @ GRA[f, A.idx[PROPS[1]], :, 2]
        elif tw is not None:
            g = {s: GPA[f, A.idx[s + "_palm"]] + GRA[f, A.idx[s + "_palm"]] @ np.asarray(tw["grip_%s_point" % s]) for s in "lr"}
            zs = Ra.T @ (g["r"] - g["l"]) / np.linalg.norm(g["r"] - g["l"])
        else:
            zs = None
        return GP[f], GR[f], pose_vec(A, GPA, f, ka), zs

    cosd = lambda u, v: float(np.degrees(np.arccos(np.clip(u @ v / (np.linalg.norm(u) * np.linalg.norm(v)), -1, 1))))  # noqa: E731
    for rec in pairs:
        a, b, kind = rec[0], rec[1], (rec[2] if len(rec) > 2 else "same_grip")
        if a not in results or b not in results or "GPB" not in results[a] or "GPB" not in results[b]:
            continue
        GPa, GRa, pa, sa = end(a, True)
        GPb, GRb, pb, sb = end(b, False)
        ina = GRa[rp].T @ GRa[ip]
        inb = GRb[rp].T @ GRb[ip]
        za, zb = GRa[ip][:, 2], GRb[ip][:, 2]
        ha, hb = GPa[rp] - GPa[lp], GPb[rp] - GPb[lp]
        row = {"from": a, "to": b, "kind": kind, "pose_A_cm": round(pose_dist(pa, pb) * 100, 1),
               "in_hand_deg": round(float(_ang(ina.T @ inb)), 1), "in_hand_axis_deg": round(cosd(ina[:, 2], inb[:, 2]), 1),
               "in_hand_roll_deg": round(roll_between(ina, inb), 1),
               "source_in_hand_deg": round(cosd(sa, sb), 1) if sa is not None and sb is not None else None,
               "world_deg": round(cosd(za, zb), 1), "hands_deg": round(cosd(ha, hb), 1)}
        status = kind
        if kind == "same_grip" and row["in_hand_deg"] > TH["weapon_in_hand_deg"]:
            status = "regrip (source)"
        row["status"] = status
        out.append(row)
    return out


# pass / fail thresholds (shared with tests/retarget/test_actor_b_from_a.gd)
TH = {"r2": 0.85, "static_rms_cm": 1.0, "vel_cos": 0.88, "foot_slide_extra_mps": 0.05, "limb_slide_extra_mps": 0.10,
      "prop_rot_deg": 1.0, "grip_cm": 5.0, "axis_grip_cm": 2.0, "left_prop_cm": 1.0, "step_excess_fail_cm": 10.0,
      "step_excess_warn_cm": 3.0, "loop_seam_cm": 0.5, "named_seam_extra_cm": 2.0, "auto_seam_factor": 1.5,
      "auto_seam_extra_cm": 3.0, "hyper_deg": 3.0, "flex_speed_excess_deg": 1.0, "rot_step_excess_deg": 15.0,
      "wrist_swing_excess_deg": 20.0, "straight_knee_warn_deg": 12.0, "straight_knee_fail_deg": 30.0,
      "mount_floor_cm": -2.0, "mount_slide_mps": 0.10, "spear_tip_min_y_m": 0.0, "weapon_in_hand_deg": 45.0,
      "ends_swapped_frames": 0, "straight_elbow_warn_deg": 12.0, "straight_elbow_fail_deg": 20.0,
      "floor_frame_slack_cm": 1.5, "offhand_source_cm": 5.0, "axis_source_deg": 20.0, "fist_sep_m": 0.08,
      "in_palm_roll_deg": 1.0, "mount_contact_max_cm": 1.0, "weapon_seam_roll_deg": 10.0, "regrip_extra_deg": 15.0}


def summarize_checks(chk):
    """Failures and warnings per clip with the thresholds in TH."""
    fails, warns = {}, {}
    for n, c in chk["clips"].items():
        f, w = [], []
        p = c.get("path")
        if p:
            if p["r2"] < TH["r2"] and p["dyn_rms_cm_median"] > TH["static_rms_cm"]:
                f.append("path r2 %.3f" % p["r2"])
            if p["vel_cos"] is not None and p["vel_cos"] < TH["vel_cos"] and p["dyn_rms_cm_median"] > TH["static_rms_cm"]:
                f.append("vel cos %.3f" % p["vel_cos"])
        for pt, row in c.get("contacts", {}).items():
            extra = TH["foot_slide_extra_mps"] if pt[2:] in ("heel", "ball") else TH["limb_slide_extra_mps"]
            if row["B_mps"] > row["A_mps"] + extra:
                f.append("%s slide %.3f vs A %.3f m/s" % (pt, row["B_mps"], row["A_mps"]))
        pr = c.get("props", {})
        for kk, v in pr.items():
            if kk.endswith("_deg") and v > TH["prop_rot_deg"]:
                f.append("%s %.2f" % (kk, v))
            if kk == "offhand_grip_err_cm_max" and v > TH["grip_cm"]:
                f.append("grip %.1f cm" % v)
            if kk == "left_prop_follow_err_cm_max" and v > TH["left_prop_cm"]:
                f.append("left prop %.1f cm" % v)
        wp = c.get("weapon", {})
        if wp.get("axis_grip_err_cm_max", 0) > TH["axis_grip_cm"]:
            f.append("off hand %.1f cm off the weapon axis" % wp["axis_grip_err_cm_max"])
        if wp.get("ends_swapped_frames", 0) > TH["ends_swapped_frames"]:
            f.append("weapon ends swapped on %d frames" % wp["ends_swapped_frames"])
        if "spear_tip_min_y_m" in wp and wp["spear_tip_min_y_m"] < TH["spear_tip_min_y_m"]:
            f.append("1.8 m spear tip %.2f m below the floor" % -wp["spear_tip_min_y_m"])
        if wp.get("offhand_vs_source_cm", [0, 0])[1] > TH["offhand_source_cm"]:
            f.append("off hand %.1f cm from the source's placement" % wp["offhand_vs_source_cm"][1])
        if wp.get("axis_vs_source_grip_line_deg", [0, 0])[1] > TH["axis_source_deg"]:
            f.append("weapon axis %.0f deg off the source's hands" % wp["axis_vs_source_grip_line_deg"][1])
        if wp.get("fist_sep_along_axis_min_m", 1.0) < TH["fist_sep_m"]:
            f.append("fists %.2f m apart along the weapon" % wp["fist_sep_along_axis_min_m"])
        if wp.get("in_palm_roll_dev_deg_max", 0) > TH["in_palm_roll_deg"]:
            f.append("weapon rolls %.1f deg in the palm" % wp["in_palm_roll_dev_deg_max"])
        jt = c.get("joints", {})
        for j, row in jt.get("hinge", {}).items():
            if row["hyper_frames"]:
                f.append("%s bends backwards on %d frames (max %+.1f deg)" % (j, row["hyper_frames"], row["B_max_deg"]))
            if row.get("flex_speed_excess_deg", 0) > TH["flex_speed_excess_deg"]:
                f.append("%s flexion step %.1f deg over max(1.5 A, A + 8)" % (j, row["flex_speed_excess_deg"]))
            sb = row.get("straight_extra_bend_max_deg", 0)
            lim = "knee" if j.endswith("knee") else "elbow"
            if sb > TH["straight_%s_fail_deg" % lim]:
                f.append("%s bent %.0f deg where the source is straight" % (j, sb))
            elif sb > TH["straight_%s_warn_deg" % lim]:
                w.append("%s bent %.0f deg where the source is straight (%d frames over 8)" % (j, sb, row["straight_frames_over8"]))
        rs = jt.get("rot_step_excess", {})
        if rs.get("max_deg", 0) > TH["rot_step_excess_deg"]:
            f.append("%s local rotation step %.1f deg over the source's (frame %d)" % (rs["bone"], rs["max_deg"], rs["frame"]))
        for s, row in jt.get("wrist", {}).items():
            if row["excess_max_deg"] > TH["wrist_swing_excess_deg"]:
                f.append("%s wrist swing %.1f deg over the source's" % (s, row["excess_max_deg"]))
        ct = c.get("continuity", {})
        if ct.get("max_excess_cm", 0) > TH["step_excess_fail_cm"]:
            f.append("frame step excess %.1f cm" % ct["max_excess_cm"])
        elif ct.get("max_excess_cm", 0) > TH["step_excess_warn_cm"]:
            w.append("frame step excess %.1f cm" % ct["max_excess_cm"])
        if ct.get("loop_seam_cm_B", 0) > TH["loop_seam_cm"]:
            f.append("loop seam %.2f cm" % ct["loop_seam_cm_B"])
        fpf = c.get("floor_per_frame")
        if fpf and fpf["min_margin_cm"] < 0:
            f.append("%s %.1f cm below min(source, floor) - %.1f cm on frame %d" % (fpf["point"], -fpf["min_margin_cm"], TH["floor_frame_slack_cm"], fpf["frame"]))
        mt = c.get("mount")
        if mt:
            for att, row in mt["at"].items():
                b = row["ball"]
                if b["min_y_cm"] < TH["mount_floor_cm"] or b["slide_max_mps"] > TH["mount_slide_mps"]:
                    f.append("mount push-off ball at saddle %s m: %.1f cm, %.3f m/s" % (att, b["min_y_cm"], b["slide_max_mps"]))
                for pt, (lo, hi) in row.get("ground_contacts_cm", {}).items():
                    if lo < TH["mount_floor_cm"] or hi > TH["mount_contact_max_cm"]:
                        f.append("mount %s on the ground at saddle %s m: %.1f .. %.1f cm from its contact height" % (pt, att, lo, hi))
        if f:
            fails[n] = f
        if w:
            warns[n] = w
    for s in chk.get("seams", []):
        lim = (s["A_cm"] + TH["named_seam_extra_cm"]) if s["named"] else (s["A_cm"] * TH["auto_seam_factor"] + TH["auto_seam_extra_cm"])
        if s["B_cm"] > lim:
            fails.setdefault("seam %s -> %s" % (s["from"], s["to"]), []).append(
                "B %.1f cm vs A %.1f cm (limit %.1f)" % (s["B_cm"], s["A_cm"], lim))
    for s in chk.get("weapon_seams", []):
        key = "weapon seam %s -> %s" % (s["from"], s["to"])
        st = s.get("status", s["kind"])
        if st == "same_grip":
            if s["in_hand_deg"] > TH["weapon_in_hand_deg"] or s["in_hand_roll_deg"] > TH["weapon_seam_roll_deg"]:
                fails.setdefault(key, []).append("weapon turns %.0f deg (roll %.0f) in the hand" % (s["in_hand_deg"], s["in_hand_roll_deg"]))
        elif st == "regrip (source)":
            src = s.get("source_in_hand_deg") or 0.0
            msg = "regrip: weapon turns %.0f deg in the hand (the source's hands turn the haft %.0f deg)" % (s["in_hand_deg"], src)
            if s["in_hand_deg"] > src + TH["regrip_extra_deg"] or s["in_hand_roll_deg"] > TH["weapon_seam_roll_deg"]:
                fails.setdefault(key, []).append(msg)
            else:
                warns.setdefault(key, []).append(msg)
        elif s["in_hand_deg"] > TH["weapon_in_hand_deg"]:
            warns.setdefault(key, []).append("regrip: weapon turns %.0f deg in the hand (%s)" % (s["in_hand_deg"], s["kind"]))
    return fails, warns


def native_seams(pair, results, dst, src_clips, pairs):
    """Seams between retargeted clips and Actor_B's own riding clips (the game plays them back
    to back): B distance, and Actor_A's distance for the same pair with its own clip."""
    A, B = pair.A, pair.B
    out = []

    def b_native(name, first):
        c = dst["clips"].get(name)
        if c is None:
            return None
        P, R = B.local_arrays(c["tracks"], c["frames"])
        GP, _ = B.fk(P, R)
        return pose_vec(B, GP, 0 if first else GP.shape[0] - 1)

    def a_clip(name, first):
        c = src_clips.get(name)
        if c is None:
            return None
        P, R = A.local_arrays(c["tracks"], c["frames"])
        GP, _ = A.fk(P, R)
        return pose_vec(A, GP, 0 if first else GP.shape[0] - 1)

    for a, b in pairs:
        if a.startswith("actor_b-"):
            vb_from, va_from = b_native(a, False), a_clip(a.replace("actor_b-", "actor_a-"), False)
        else:
            r = results.get(a)
            vb_from = pose_vec(B, r["GPB"], r["GPB"].shape[0] - 1) if r is not None and "GPB" in r else None
            va_from = pose_vec(A, r["GPA"], r["GPA"].shape[0] - 1) if r is not None and "GPA" in r else None
        if b.startswith("actor_b-"):
            vb_to, va_to = b_native(b, True), a_clip(b.replace("actor_b-", "actor_a-"), True)
        else:
            r = results.get(b)
            vb_to = pose_vec(B, r["GPB"], 0) if r is not None and "GPB" in r else None
            va_to = pose_vec(A, r["GPA"], 0) if r is not None and "GPA" in r else None
        if vb_from is None or vb_to is None:
            continue
        row = {"from": a, "to": b, "B_cm": round(pose_dist(vb_from, vb_to) * 100, 2)}
        if va_from is not None and va_to is not None:
            row["A_cm"] = round(pose_dist(va_from, va_to) * 100, 2)
        out.append(row)
    return out


def build_checks(pair, rt, src, dst, cfg, results, out):
    names = [e["name"] for e in cfg["clips"] if e["name"] in out["clips"]]
    ents = {e["name"]: e for e in cfg["clips"]}
    chk = {"clips": {}}
    for n in names:
        r = results[n]
        if "GPB" not in r:
            continue
        chk["clips"][n] = clip_checks(pair, rt, n, ents[n], r, src["clips"][n])
    chk["seams"] = seams(pair, results, names)
    chk["weapon_seams"] = weapon_seams(pair, rt, results, cfg.get("weapon_seams", []))
    chk["native_seams"] = native_seams(pair, results, dst, src["clips"], cfg.get("native_seams", []))
    chk["fails"], chk["warnings"] = summarize_checks(chk)
    chk["thresholds"] = TH
    return chk


# ----------------------------------------------------------------------------- outputs
def _deg10(x):
    return [int(round(float(v) * 10)) for v in x]


def write_test_ref(path, pair, rt, cfg, results, out, chk):
    """Per-clip Actor_A reference data for tests/retarget/test_actor_b_from_a.gd. Angles are
    stored in tenths of a degree (ints)."""
    A, B = pair.A, pair.B
    ents = {e["name"]: e for e in cfg["clips"]}
    ref = {"fps": FPS, "scale_s": round(pair.s, 6), "joints": JOINTS, "seam_joints": SEAM_JOINTS,
           "bind_contact_height_B": {p: round(float(pair.PB0[B.idx[p], 1]), 5) for p in FLOOR_POINTS},
           "hinges": {j: list(v) for j, v in HINGE.items()}, "step_bones": STEP_BONES,
           "mount_attach_m": list(MOUNT_ATTACH_M),
           "clips": {}, "seams": [s for s in chk.get("seams", [])], "weapon_seams": chk.get("weapon_seams", [])}
    if rt.grips_B is not None:
        ref["axis_grip_point_l"] = np.round(rt.grips_B["l"]["point"], 5).tolist()
        ref["axis_grip_point_r"] = np.round(rt.grips_B["r"]["point"], 5).tolist()
        ref["canonical_right_grip_q"] = np.round(m2q(rt.grips_B["r"]["rot"]), 7).tolist()
    ref["floor_points"] = FLOOR_POINTS
    ref["fist_bones"] = [x[1:] for x in FIST]
    for n, c in out["clips"].items():
        r = results[n]
        if "GPB" not in r:
            continue
        e = ents[n]
        GPA, GRA = r["GPA"], r["GRA"]
        F = GPA.shape[0]
        k = r["w_pel"] * pair.s + (1 - r["w_pel"])
        pel = GPA[:, A.idx["pelvis"]]
        rel = np.stack([(GPA[:, A.idx[j]] - pel) * k[:, None] for j in JOINTS], 1)
        skip = [p for p in PROPS if p in JOINTS and "rot" not in r["src_keyed"].get(p, ())]
        rec = {"frames": F, "profile": e.get("profile", "ground"), "group": e.get("group"), "loop": bool(r.get("loop")),
               "path_skip": skip,
               "a_rel": np.round(rel, 4).tolist(),
               "a_abs": np.round(np.stack([GPA[:, A.idx[j]] * k[:, None] for j in JOINTS], 1), 4).tolist()}
        cm = contact_masks(pair, e, GPA, k)
        rec["contacts"] = {pt: {"mask": "".join("1" if x else "0" for x in msk),
                                "a_slide_mps": chk["clips"][n]["contacts"].get(pt, {}).get("A_mps")}
                           for pt, msk in cm.items() if pt in chk["clips"][n]["contacts"]}
        for pt in list(rec["contacts"]):
            if pt.endswith(("_wrist", "_knee")):
                rec["contacts"][pt]["a_height"] = np.round(GPA[:, A.idx[pt], 1] * pair.s, 4).tolist()
        # prop world rotations the library copies (keyed in the source; the library's weapon frame)
        props = {}
        for p in PROPS:
            if p in r["src_keyed"] and "rot" in r["src_keyed"][p]:
                props[p] = np.round(m2q(GRA[:, A.idx[p]]), 6).tolist()
        rec["a_prop_world_q"] = props
        gw = r.get("grip_w")
        if e.get("offhand") and gw is not None and (gw > 0.9).any():
            off = e["offhand"]
            mp = PROPS[1] if off == "l" else PROPS[0]
            held = "".join("1" if x > 0.9 else "0" for x in gw)
            if "synthetic_grip" in r["diag"]:
                # the source's two hands (as in weapon_checks): A's left grip point minus the right one, scaled
                # by s, and the unit line from the left grip point to the right one
                tw = rt.weapon["two_hand"]
                gA = {sd: GPA[:, A.idx[sd + "_palm"]] + np.einsum("fij,j->fi", GRA[:, A.idx[sd + "_palm"]], np.asarray(tw["grip_%s_point" % sd]))
                      for sd in "lr"}
                d = gA["r"] - gA["l"]
                rec["axis_grip"] = {"main_prop": mp, "palm": off + "_palm", "held": held,
                                    "a_rel_s": np.round(-pair.s * d, 4).tolist(),
                                    "a_line": np.round(d / np.linalg.norm(d, axis=1, keepdims=True), 4).tolist()}
            else:
                ra = np.einsum("fji,fj->fi", GRA[:, A.idx[mp]], GPA[:, A.idx[off + "_palm"]] - GPA[:, A.idx[mp]])
                rec["grip"] = {"main_prop": mp, "palm": off + "_palm", "held": held, "a_palm_in_prop": np.round(ra, 5).tolist()}
        if r["diag"].get("left_prop") == "follow":
            ra = np.einsum("fji,fj->fi", GRA[:, A.idx[PROPS[1]]], GPA[:, A.idx[PROPS[0]]] - GPA[:, A.idx[PROPS[1]]])
            rec["left_prop_in_right"] = np.round(ra, 5).tolist()
        fl = chk["clips"][n].get("floor_lowest_cm")
        if fl:
            rec["a_floor_lowest_cm"] = fl["A"]
            # per frame: A's heel / ball / ankle height above its bind contact height, scaled by s (mm)
            rec["a_floor_h_mm"] = {pt: [int(round(float(x) * 1000)) for x in (GPA[:, A.idx[pt], 1] - pair.PA0[A.idx[pt], 1]) * pair.s]
                                   for pt in FLOOR_POINTS}
        if "prop_roll" in r["diag"]:
            rec["prop_axis_only"] = True  # the right prop's roll is set from the palm: compare its axis
        if "prop_roll" in r["diag"] or "synthetic_grip" in r["diag"]:
            rec["roll_check"] = True  # in-palm roll = the canonical grip's (minimal swing)
        # joints: A's signed hinge flexion, wrist swing and limb local rotation steps
        keyed = {b for b, ch in r["src_keyed"].items() if "rot" in ch}
        rec["a_flex"] = {j: _deg10(signed_flex(A, GPA, GRA, j)) for j, (a, cj, _) in HINGE.items() if {a, j} <= keyed}
        rec["a_wrist_swing"] = {s: _deg10(wrist_swing(A, GRA, pair.RA0, s)) for s in "lr" if {s + "_elbow", s + "_wrist"} <= keyed}
        if F > 2:
            rec["a_step"] = {b: _deg10(v) for b, v in local_steps(A, GRA, [b for b in STEP_BONES if b in keyed]).items()}
        if e.get("group") in TWO_HAND_GROUPS and "prop_far_from_palm_m" not in r["diag"]:
            rec["weapon"] = {"guard": e.get("group") == "two-hand-guard"}
        mc = chk["clips"][n].get("mount")
        if mc:
            d = r["diag"]["mount_align"]
            rec["mount"] = {"ground_to_saddle": d["ground_to_saddle"], "reference_saddle_height_m": d["reference_saddle_height_m"],
                            "push_off_foot": d["push_off_foot"], "push_off_frames": d["push_off_frames"],
                            "ground_contacts": d.get("ground_contacts", {})}
        ref["clips"][n] = rec
    with open(path, "w") as f:
        json.dump(ref, f, separators=(",", ":"))
    print("test reference ->", path)


WEAPON_CONVENTIONS = {
    "blade": "saber / tomahawk / knife in the machete clips (group machete, machete-draw): the Actor_A machete prop frames "
             "are converted to Actor_B's own knife frame (weapon_frames.py `blade`): the blade leaves the fist along the "
             "prop bone's +Y, the edge / finger side about -Z, origin at the fist centre. Attach the saber with "
             "saber_model.md's SABER_PROP_OFFSET, the same offset as in Actor_B's native knife clips.",
    "two_hand": "spear, club and musket in the guard, haft sweep, club, blocked and butt-stroke clips (groups two-hand-guard, "
                "two-hand-club, musket-butt): +Z runs along the weapon from the left (lower) hand through the right hand to "
                "the working end (spear point, club head, musket butt); the left palm grips about 0.08 m up +Z from the "
                "origin. The roll about +Z is set from the right palm (the canonical right-hand grip swung onto the axis): "
                "the haft and club clips (atk-pipe-*, whose source prop is a round pipe with no authored roll) and the guard "
                "clips keep one roll in the fist, so a roll-asymmetric weapon (musket lock, club head, bayonet) attaches "
                "with one offset; the long-gun clips (atk-lg-*) keep the source rifle's roll. Haft clips hold the weapon in "
                "a bat grip (right palm about 0.2 m up); atk-pipe-block and the pipe-block-* clips key no prop in the "
                "source and get the weapon where the source's two hands hold it (synthetic_grip: the axis through both "
                "hands' grip points, the off hand at the source's placement relative to the right hand, scaled; right "
                "palm about 0.45 m up in the guard); in the one-handed recoil of atk-pipe-block it eases to the bat grip.",
    "other": "fist, pistol / bow quick melee and the crawl clips key the prop bones as in the source (world rotation copied); "
             "clips listed with prop_far_from_palm_m use the prop bones for something other than a held weapon.",
}
MOUNT_CONVENTION = (
    "Mount clips are baked into the saddle frame (retarget.diag.mount_align): the clip origin is the saddle attach point "
    "of the horse for the whole clip, and the root carries the solved ground -> saddle align. During the ground phase "
    "the floor lies reference_saddle_height_m below the origin (the fitted source ground scaled by s, raised by the "
    "rider's standing offset, standing_offset_m: the source stands about 3 cm above its fitted ground, so the planted "
    "push-off ball and the feet of the first frame are at their bind contact height on this floor). Runtime recipe for "
    "a horse whose saddle attach point is H above the ground: place the rider's skeleton at the saddle attach point and "
    "shift it down (along the saddle's up axis) by (H - reference_saddle_height_m) x (1 - ground_to_saddle[frame]). "
    "ground_to_saddle is 0 until the push-off foot leaves the ground (so the planted foot is exact on the real floor), "
    "then rises to 1 while that foot is in the air. Foot IK the stirrup foot to the horse's stirrup and the hands to the "
    "pommel / reins while the difference is being taken up. start_ground_pose gives where the rider stands (x, z in the "
    "saddle frame, floor) and faces (yaw) at the first frame: move the player there before the clip starts.")


def write_manifest(path, tool, pair, rt, cfg, results, out, chk):
    """animations_extra/Actor_B_from_A.json: provenance, usage metadata, checks, FK reference."""
    B = pair.B
    ents = {e["name"]: e for e in cfg["clips"]}
    man = {"library": "Actor_B_from_A.res", "library_name": out.get("library_name"), "tool": tool,
           "source_actor": "Actor_A", "target_actor": "Actor_B",
           "source_library": "Player_Animation_Project/godot_export/animations/Actor_A.res",
           "a_bind": out.get("a_bind"), "scale_s": round(pair.s, 5), "stature_ratio": round(pair.stature_ratio, 5),
           "hand_ratio": round(pair.k_hand, 5), "leg_ratio": round(pair.k_leg, 5), "arm_ratio": round(pair.k_arm, 5),
           "align": pair.align_mode,
           "seat_offset_m": [round(float(x), 5) for x in rt.seat_offset],
           "stirrup_offset_m": {k: [round(float(x), 5) for x in v] for k, v in rt.stirrup_offset.items()},
           "horse_reference": out.get("horse_reference"), "weapon_frames": out.get("weapon_frames"),
           "conventions": {
               "tracks": "Skeleton3D:<bone> position/rotation, 30 fps keys, only the channels the source keys "
                         "(+ main-hand prop tracks on the guard clips, see added_prop_tracks)",
               "weapon": WEAPON_CONVENTIONS,
               "ground": "clip origin = floor point under the character (pelvis and stride scaled by scale_s; legs by "
                         "leg_ratio from the hip, hands on the floor by arm_ratio from the shoulder)",
               "horse": "clip origin = saddle attach point (horse.md 1.2); rider seat and stirrups calibrated on "
                        "actor_b-horse-idle (rider clips are saddle-relative: another saddle height needs no change; "
                        "foot IK to the stirrups)",
               "mount": MOUNT_CONVENTION,
               "loop": "loop: true = a real cycle the runtime loops (seam closed by the tool); seamless: the source's "
                       "first and last poses match (not a loop by itself). loop_mode is copied from the source (0)."},
           "clips": {}, "seams": chk.get("seams", []), "weapon_seams": chk.get("weapon_seams", []),
           "native_seams": chk.get("native_seams", []),
           "check_thresholds": chk.get("thresholds"), "check_failures": chk.get("fails", {}),
           "check_warnings": chk.get("warnings", {})}
    for n, c in out["clips"].items():
        e = ents[n]
        r = results[n]
        d = c["diag"]
        rec = {"group": e.get("group"), "priority": e.get("priority"), "use": e.get("use"),
               "profile": e.get("profile", "ground"), "native_asset_id": c["meta"].get("native_asset_id"),
               "original_name": c["meta"].get("original_name"), "source_library": c["meta"].get("source_library"),
               "additive": d.get("additive", False), "loop": d.get("loop", False), "seamless": d.get("seamless", False),
               "frames": c["frames"], "length": c["length"], "tracks_out": len(c["tracks"])}
        for kk in ("weapon_frame", "synthetic_grip", "added_prop_tracks", "prop_far_from_palm_m", "grip", "left_prop",
                   "prop_roll", "contact_frames", "loop_seam", "wrist_swing_limited_deg", "stirrup_stand_cm", "floor_lift_cm"):
            if kk in d:
                rec[kk] = d[kk]
        if "mount_align" in d:
            ma = d["mount_align"]
            rec["mount"] = {k: ma[k] for k in ("frame", "reference_saddle_height_m", "floor_y_m", "push_off_foot",
                                               "push_off_frames", "ground_to_saddle", "start_ground_pose",
                                               "source_saddle_height_m", "standing_offset_m", "solve_floor_y_m",
                                               "ground_contacts", "ground_frame_source") if k in ma}
        if n in chk["clips"]:
            rec["checks"] = chk["clips"][n]
        if "GPB" in r:  # FK of the emitted tracks (what the library plays)
            F = c["frames"]
            fr = sorted(set([0, F // 2, F - 1]))
            P, R = B.local_arrays(c["tracks"], F)
            GPe, _ = B.fk(P, R)
            rec["reference"] = {"frames": fr, "joints": {j: np.round(GPe[fr, B.idx[j]], 5).tolist() for j in REF_JOINTS}}
        man["clips"][n] = rec
    with open(path, "w") as f:
        json.dump(man, f, indent=1)
    print("manifest ->", path)
