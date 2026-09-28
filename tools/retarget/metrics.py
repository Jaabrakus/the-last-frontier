"""Numeric checks for the Actor_A -> Actor_B retarget prototype (used by retarget.py --report).

Per full-body clip:
  pose_error_cm      joint positions relative to the pelvis, B vs A scaled by the anchor
                     scale (s on the ground, 1 in the saddle); median / p95 per joint
  vel_cos            speed-weighted cosine between B and scaled-A joint velocities in the
                     clip frame (1 = the joint moves in the same direction at every frame)
  seg_angle_deg      angle between B and A bone directions (mean / p95)
  foot_slide         planted-point horizontal speed (heel/ball): A scaled, B with IK,
                     B without IK (m/s; median / p90 over planted frames). Planted = within
                     2 cm of the point's lowest height in the clip AND slower than 0.25 m/s
                     in A (FootSlip's height rule plus a speed gate, because melee clips step).
  path_dynamic       joint paths relative to the pelvis, B vs anchor-scaled A, with each
                     joint's mean offset removed: r2 (1 - residual / A's variance) and RMS cm;
                     static_cm is the removed mean offset (the proportion difference)
  floor_cm           lowest heel/ball height relative to each rig's bind contact height
                     over A's planted frames (ground clips)
  intersect          self-intersection proxies: hand/forearm points inside a torso capsule,
                     shin/thigh capsules of both legs overlapping, hand inside the head sphere
                     (max depth cm and frames over 2 cm; A with radii scaled by 1/stature)
  native             horse clips with a native Actor_B counterpart: mean pelvis / ankle /
                     wrist offset of the retarget from the native clip (cm)
"""
import copy

import numpy as np

from rtmath import q2m, rot_angle_deg

JOINTS = ["heada", "l_wrist", "r_wrist", "r_hand_prop_attachment", "l_elbow", "r_elbow",
          "l_knee", "r_knee", "l_ankle", "r_ankle", "l_ball", "r_ball"]
SEGS = [("spinea", "spined"), ("spined", "neck"), ("neck", "heada"),
        ("l_clavicle", "l_shoulder"), ("l_shoulder", "l_elbow"), ("l_elbow", "l_wrist"),
        ("r_clavicle", "r_shoulder"), ("r_shoulder", "r_elbow"), ("r_elbow", "r_wrist"),
        ("l_upper_leg", "l_knee"), ("l_knee", "l_ankle"), ("l_ankle", "l_ball"),
        ("r_upper_leg", "r_knee"), ("r_knee", "r_ankle"), ("r_ankle", "r_ball")]
FOOT_POINTS = ["l_heel", "l_ball", "r_heel", "r_ball"]
PLANTED_TOL = 0.02
SLOW_MPS = 0.25
FPS = 30.0
TORSO_R, LIMB_R, HEAD_R = 0.11, 0.05, 0.10


def _j(rig, GP, n):
    return GP[:, rig.idx[n]]


def seg_point_dist(p, a, b):
    ab = b - a
    t = np.clip(np.sum((p - a) * ab, -1) / np.maximum(np.sum(ab * ab, -1), 1e-12), 0, 1)
    return np.linalg.norm(a + t[..., None] * ab - p, axis=-1)


def seg_seg_dist(p1, q1, p2, q2, n=12):
    ts = np.linspace(0, 1, n)
    best = np.full(p1.shape[0], np.inf)
    for t in ts:
        best = np.minimum(best, seg_point_dist(p1 + t * (q1 - p1), p2, q2))
    return best


def foot_slide(GP, rig, planted_src, scale=1.0):
    out = {}
    speeds = []
    for pt in FOOT_POINTS:
        x = GP[:, rig.idx[pt]][:, [0, 2]] * scale
        v = np.linalg.norm(np.diff(x, axis=0), axis=1) * FPS
        m = planted_src[pt][1:] & planted_src[pt][:-1]
        if m.any():
            speeds.append(v[m])
            out[pt] = round(float(np.median(v[m])), 3)
    allv = np.concatenate(speeds) if speeds else np.zeros(1)
    return {"median": round(float(np.median(allv)), 3), "p90": round(float(np.percentile(allv, 90)), 3),
            "n": int(allv.size), "per_point": out}


def intersections(rig, GP, scale):
    r_t, r_l, r_h = TORSO_R * scale, LIMB_R * scale, HEAD_R * scale
    pel, neck = _j(rig, GP, "pelvis"), _j(rig, GP, "neck")
    spine_mid = _j(rig, GP, "spinec")
    res = {}
    depth = []
    for pt in ["l_wrist", "r_wrist", "l_elbow", "r_elbow"]:
        d = np.minimum(seg_point_dist(_j(rig, GP, pt), pel, spine_mid), seg_point_dist(_j(rig, GP, pt), spine_mid, neck))
        depth.append(np.maximum(0, r_t - d))
    arm_torso = np.max(depth, axis=0)
    legs = []
    for a, b in [("upper_leg", "knee"), ("knee", "ankle")]:
        d = seg_seg_dist(_j(rig, GP, "l_" + a), _j(rig, GP, "l_" + b), _j(rig, GP, "r_" + a), _j(rig, GP, "r_" + b))
        legs.append(np.maximum(0, 2 * r_l - d))
    leg_leg = np.max(legs, axis=0)
    head_c = 0.5 * (_j(rig, GP, "heada") + _j(rig, GP, "headb"))
    hh = [np.maximum(0, r_h - np.linalg.norm(_j(rig, GP, w) - head_c, axis=1)) for w in ("l_wrist", "r_wrist")]
    hand_head = np.max(hh, axis=0)
    for k, v in (("arm_torso", arm_torso), ("leg_leg", leg_leg), ("hand_head", hand_head)):
        res[k] = {"max_cm": round(float(v.max() * 100), 1), "frames_over_2cm": int((v > 0.02).sum())}
    return res, {"arm_torso": arm_torso, "leg_leg": leg_leg, "hand_head": hand_head}


def clip_metrics(pair, rt, name, entry, r, src_clip, native=None, noik=None, skip=()):
    """`skip`: joints left out of the path / velocity comparison (a prop bone the library keys
    but the source does not: its source path is the bind placement, not a weapon)."""
    A, B = pair.A, pair.B
    JOINTS = [j for j in globals()["JOINTS"] if j not in skip]
    GPA, GPB, GRA, GRB = r["GPA"], r["GPB"], r["GRA"], r["GRB"]
    F = GPA.shape[0]
    w = r["w_pel"]
    k = w * pair.s + (1 - w)  # anchor scale per frame
    m = {}
    pelA, pelB = _j(A, GPA, "pelvis"), _j(B, GPB, "pelvis")
    pe = {}
    allerr = []
    for j in JOINTS:
        relA = (_j(A, GPA, j) - pelA) * k[:, None]
        relB = _j(B, GPB, j) - pelB
        e = np.linalg.norm(relB - relA, axis=1) * 100
        pe[j] = [round(float(np.median(e)), 1), round(float(np.percentile(e, 95)), 1)]
        allerr.append(e)
    m["pose_error_cm"] = {"all_median": round(float(np.median(np.concatenate(allerr))), 1),
                          "all_p95": round(float(np.percentile(np.concatenate(allerr), 95)), 1), "per_joint": pe}
    # dynamic path similarity: joint paths relative to the pelvis with each joint's mean
    # offset removed (proportions differ, so the static offset is reported separately)
    dyn, r2n, r2d = {}, 0.0, 0.0
    for j in JOINTS:
        relA = (_j(A, GPA, j) - pelA) * k[:, None]
        relB = _j(B, GPB, j) - pelB
        dA = relA - relA.mean(0)
        dB = relB - relB.mean(0)
        e = np.linalg.norm(dB - dA, axis=1)
        dyn[j] = {"rms_cm": round(float(np.sqrt(np.mean(e ** 2)) * 100), 1),
                  "static_cm": round(float(np.linalg.norm(relB.mean(0) - relA.mean(0)) * 100), 1),
                  "range_cm": round(float(np.sqrt(np.mean(np.sum(dA ** 2, 1))) * 100), 1)}
        r2n += float(np.sum(e ** 2))
        r2d += float(np.sum(dA ** 2))
    m["path_dynamic"] = {"r2": round(1 - r2n / max(r2d, 1e-12), 3),
                         "rms_cm_median": round(float(np.median([v["rms_cm"] for v in dyn.values()])), 1),
                         "rms_cm_max": round(float(max(v["rms_cm"] for v in dyn.values())), 1),
                         "per_joint": dyn}
    # velocity direction similarity (clip frame)
    cs, ws = [], []
    for j in JOINTS:
        pa = _j(A, GPA, j) * k[:, None]
        pb = _j(B, GPB, j)
        va, vb = np.diff(pa, axis=0), np.diff(pb, axis=0)
        na, nb = np.linalg.norm(va, axis=1), np.linalg.norm(vb, axis=1)
        ok = (na * FPS > 0.2) & (nb > 1e-9)
        if ok.any():
            cs.append(np.sum(va[ok] * vb[ok], 1) / (na[ok] * nb[ok]))
            ws.append(na[ok])
    if cs:
        c, wt = np.concatenate(cs), np.concatenate(ws)
        m["vel_cos"] = round(float(np.sum(c * wt) / np.sum(wt)), 3)
        m["vel_cos_p05"] = round(float(np.percentile(c, 5)), 3)
    # bone direction angles
    angs = []
    for a, b in SEGS:
        da = _j(A, GPA, b) - _j(A, GPA, a)
        db = _j(B, GPB, b) - _j(B, GPB, a)
        cosv = np.sum(da * db, 1) / (np.linalg.norm(da, axis=1) * np.linalg.norm(db, axis=1))
        angs.append(np.degrees(np.arccos(np.clip(cosv, -1, 1))))
    angs = np.array(angs)
    m["seg_angle_deg"] = {"mean": round(float(angs.mean()), 2), "p95": round(float(np.percentile(angs, 95)), 2),
                          "worst_seg": "%s->%s" % SEGS[int(np.argmax(angs.mean(1)))]}
    # foot sliding: planted = low (within 2 cm of the point's minimum) and slow in A
    planted = {}
    for pt in FOOT_POINTS:
        xa = _j(A, GPA, pt)
        y = xa[:, 1]
        va = np.zeros(F)
        va[1:] = np.linalg.norm(np.diff(xa[:, [0, 2]] * k[:, None], axis=0), axis=1) * FPS
        va[0] = va[1] if F > 1 else 0
        planted[pt] = (y <= y.min() + PLANTED_TOL) & (va < SLOW_MPS)
    m["foot_slide_mps"] = {"A_scaled": foot_slide(GPA, A, planted, float(np.median(k))),
                           "B_ik": foot_slide(GPB, B, planted)}
    if noik is not None:
        m["foot_slide_mps"]["B_no_ik"] = foot_slide(noik["GPB"], B, planted)
    m["planted_fraction"] = round(float(np.mean([planted[p_].mean() for p_ in FOOT_POINTS])), 3)
    # floor contact (heights relative to each rig's bind contact height) on planted frames
    if entry.get("profile", "ground") == "ground":
        fl = {}
        for pt in FOOT_POINTS:
            ya = _j(A, GPA, pt)[:, 1] - pair.PA0[A.idx[pt], 1]
            yb = _j(B, GPB, pt)[:, 1] - pair.PB0[B.idx[pt], 1]
            msk = planted[pt] if planted[pt].any() else (ya <= ya.min() + PLANTED_TOL)
            fl[pt] = {"A_cm": round(float(np.median(ya[msk]) * 100), 1), "B_cm": round(float(np.median(yb[msk]) * 100), 1),
                      "B_min_cm": round(float(yb.min() * 100), 1)}
        m["floor_rel_bind_cm"] = fl
        low = {}
        for pt in ["l_knee", "r_knee", "l_wrist", "r_wrist", "l_ball", "r_ball", "l_heel", "r_heel"]:
            low[pt] = [round(float(_j(A, GPA, pt)[:, 1].min() * 100), 1), round(float(_j(B, GPB, pt)[:, 1].min() * 100), 1)]
        m["lowest_point_cm_A_B"] = low
    # self intersection proxies
    ia, _ = intersections(A, GPA, 1.0 / pair.stature_ratio)
    ib, _ = intersections(B, GPB, 1.0)
    m["intersect"] = {"A": ia, "B": ib}
    m["ik_residual_m"] = r["diag"].get("ik_residual_m", {})
    m["hinge_swing_removed_p95_deg"] = r["diag"].get("hinge_swing_removed_deg", {})
    if "left_prop" in r["diag"]:
        m["left_prop"] = r["diag"]["left_prop"]
    # native counterpart
    if native is not None:
        Pn, Rn = B.local_arrays(native["tracks"], native["frames"])
        GPn, _ = B.fk(Pn, Rn)
        nat = {}
        for j in ["pelvis", "l_ankle", "r_ankle", "l_wrist", "r_wrist", "heada"]:
            a = _j(A, GPA, j).mean(0)
            b = _j(B, GPB, j).mean(0)
            n = GPn[:, B.idx[j]].mean(0)
            nat[j] = {"rt_minus_native_cm": np.round((b - n) * 100, 1).tolist(),
                      "A_minus_native_cm": np.round((a - n) * 100, 1).tolist()}
        m["native"] = {"clip": entry["native"], "mean_offsets": nat}
        se = {}
        for label, fa, fn in (("start", 0, 0), ("end", -1, -1)):
            se[label] = {j: np.round((_j(B, GPB, j)[fa] - GPn[fn, B.idx[j]]) * 100, 1).tolist()
                         for j in ["pelvis", "l_ankle", "r_ankle", "heada"]}
            se[label + "_A"] = {j: np.round((_j(A, GPA, j)[fa] - GPn[fn, B.idx[j]]) * 100, 1).tolist()
                                for j in ["pelvis", "l_ankle", "r_ankle", "heada"]}
        m["native"]["start_end_rt_minus_native_cm"] = se
    return m


def additive_metrics(pair, rt, entry, src, dst, out_tracks):
    """Compare retargeted additive deltas with a native Actor_B additive (same motion)."""
    A, B = pair.A, pair.B
    ca = src["clips"][entry["name"]]
    res = {}
    nat = dst["clips"].get(entry.get("native", ""), None)
    per = {}
    for bn, t in out_tracks.items():
        if "rot" not in t:
            continue
        DA = np.einsum("ij,fjk->fik", A.rest_R[A.idx[bn]].T, q2m(np.asarray(ca["tracks"][bn]["rot"])))
        DB = np.einsum("ij,fjk->fik", B.rest_R[B.idx[bn]].T, q2m(np.asarray(t["rot"])))
        row = {"A_max_deg": round(float(rot_angle_deg(DA).max()), 2), "rt_max_deg": round(float(rot_angle_deg(DB).max()), 2)}
        if nat is not None and bn in nat["tracks"] and "rot" in nat["tracks"][bn]:
            Dn = np.einsum("ij,fjk->fik", B.rest_R[B.idx[bn]].T, q2m(np.asarray(nat["tracks"][bn]["rot"])))
            # resample native to the retarget's frame count
            idx = np.clip(np.round(np.linspace(0, len(Dn) - 1, len(DB))).astype(int), 0, len(Dn) - 1)
            Dn = Dn[idx]
            diff = rot_angle_deg(np.einsum("fji,fjk->fik", Dn, DB))
            row["native_max_deg"] = round(float(rot_angle_deg(Dn).max()), 2)
            row["rt_vs_native_deg_median"] = round(float(np.median(diff)), 2)
            row["rt_vs_native_deg_max"] = round(float(diff.max()), 2)
        per[bn] = row
    res["per_bone"] = per
    if nat is not None:
        res["native"] = entry.get("native")
    return res


def add2_identity(pair, rt, src, base_name, add_name):
    """max angle between retarget(Add2(base, add)) and Add2(retarget(base), retarget(add))."""
    A, B = pair.A, pair.B
    base, add = src["clips"][base_name], src["clips"][add_name]
    F = min(base["frames"], add["frames"])
    comp = copy.deepcopy(base)
    comp["frames"] = F
    for bn, t in add["tracks"].items():
        if "rot" not in t or bn not in comp["tracks"] or "rot" not in comp["tracks"][bn]:
            continue
        Lb = q2m(np.asarray(comp["tracks"][bn]["rot"][:F]))
        La = q2m(np.asarray(t["rot"][:F]))
        R0 = A.rest_R[A.idx[bn]]
        from rtmath import m2q
        comp["tracks"][bn]["rot"] = m2q(Lb @ R0.T @ La).tolist()
    for bn in comp["tracks"]:
        for ch in comp["tracks"][bn]:
            comp["tracks"][bn][ch] = comp["tracks"][bn][ch][:F]
    cfg = {"profile": "none_ik", "hinge_project": False, "ik": {"l_foot": [[0, 0]], "r_foot": [[0, 0]]}}
    r_comp = rt.retarget("comp", comp, cfg)
    base_c = copy.deepcopy(base)
    base_c["frames"] = F
    r_base = rt.retarget("base", base_c, cfg)
    r_add = rt.retarget("add", add, {"profile": "none_ik"})
    worst = 0.0
    for bn, t in r_add["tracks"].items():
        if "rot" not in t or bn not in r_base["tracks"]:
            continue
        Lb = q2m(np.asarray(r_base["tracks"][bn]["rot"][:F]))
        La = q2m(np.asarray(t["rot"][:F]))
        R0 = B.rest_R[B.idx[bn]]
        mine = Lb @ R0.T @ La
        ref = q2m(np.asarray(r_comp["tracks"][bn]["rot"][:F]))
        worst = max(worst, float(rot_angle_deg(np.einsum("fji,fjk->fik", mine, ref)).max()))
    return round(worst, 5)


def build_report(pair, rt, src, dst, cfg, results):
    rep = {"scale_s": round(float(pair.s), 4), "stature_ratio": round(float(pair.stature_ratio), 4),
           "align": pair.align_mode, "seat_offset_m": np.round(rt.seat_offset, 4).tolist(), "clips": {}}
    for entry in cfg["clips"]:
        name = entry["name"]
        r = results[name]
        if "GPB" not in r:
            rep["clips"][name] = {"additive": additive_metrics(pair, rt, entry, src, dst, r["tracks"])}
            continue
        e2 = copy.deepcopy(entry)
        e2["ik"] = {"l_foot": [[0, 0]], "r_foot": [[0, 0]]}
        e2["offhand"] = None
        noik = rt.retarget(name, src["clips"][name], e2)
        native = dst["clips"].get(entry.get("native", ""))
        skip = tuple(p for p in ("l_hand_prop_attachment", "r_hand_prop_attachment")
                     if "rot" not in src["clips"][name]["tracks"].get(p, {}))
        rep["clips"][name] = clip_metrics(pair, rt, name, entry, r, src["clips"][name], native, noik, skip=skip)
        if entry.get("partial"):
            rep["clips"][name]["tracks_out"] = sorted(r["tracks"].keys())
    for pairdef in cfg.get("add2_checks", []):
        rep.setdefault("add2_identity_max_deg", {})["%s + %s" % tuple(pairdef)] = add2_identity(pair, rt, src, *pairdef)
    return rep
