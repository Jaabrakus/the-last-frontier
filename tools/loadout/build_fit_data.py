#!/usr/bin/env python3
"""Assemble the loadout body-fit data from the Godot survey.

    python3 tools/loadout/build_fit_data.py <raw_fit.json> [candidates=tools/loadout/candidates.json] [out=data/loadout]

Inputs: the JSON written by tools/loadout/measure_body_fit.gd (bind landmarks, holster bones,
draw clips, limb-sweep grid, candidate stow capsules) and the candidate list made by
tools/loadout/make_candidates.py. Outputs (no other file is touched):

    data/loadout/body_fit.json            body surface, holster bones, source stows, sweep map
    data/loadout/carry_points_survey.json carry points per waist / shoulder / back gear
    data/loadout/keepout.json             zones customizer accessories must leave free

All positions are in rig (skeleton) space at the bind pose null-add: +Y up, the character
faces +Z, character right = -X. Angles around the torso axis: 0 front, 90 right, 180 back,
270 left. Distances in metres unless a key ends in _cm.
"""

import json
import math
import os
import sys
import time

CATS = ["idle", "walk", "run", "sprint", "crouch", "aim", "throw", "carry", "reload",
        "jump", "land", "vault", "climb", "ladder", "ledge"]
GROUPS = {
    "locomotion": ["idle", "walk", "run", "sprint"],
    "crouch": ["crouch"],
    "weapon_use": ["aim", "throw", "carry", "reload"],
    "traversal": ["jump", "land", "vault", "climb", "ladder", "ledge"],
}
CLEAN_CM, CONTACT_CM = -1.0, -3.5
PROVENANCE = ("Rig, bone names, bind pose and clips: Actor_B. Body and outfit geometry: "
              "tools/character/build_body.py. Weapon models: tools/models.")


def load(p):
    with open(p) as f:
        return json.load(f)


def r3(v, n=4):
    return [round(float(x), n) for x in v]


def cm(x):
    return None if x is None else round(float(x) * 100.0, 1)


def angle_of(p, axis_xz=(0.0, 0.024)):
    return round((math.degrees(math.atan2(-(p[0] - axis_xz[0]), p[2] - axis_xz[1])) + 360.0) % 360.0, 1)


# ---------------------------------------------------------------------------------------------
# placements: recommended / alternative / rejected stow placements -> candidate capsule ids
# ---------------------------------------------------------------------------------------------
PLACEMENTS = {
    # waist belt (legacy baked belt, belt_tied_behind, military waist belt)
    "belt.R_hip.pistol": dict(caps=["pistol_hook_R125~s2:barrel", "pistol_hook_R125:stock"], kind="pistol",
        attach="two_anchor", anchor_bones=["pelvis (hook on the belt band)", "skin of the right hip (barrel)"],
        status="recommended",
        note="Belt hook / holster at the right hip, 15 deg behind the source grab (110 deg): the right forearm swing of "
             "the diagonal walk clears it better. Barrel hangs down the hip, lock outward, butt to the rear, as in the "
             "source no-pack stow."),
    "belt.R_hip.pistol_source110": dict(caps=["pistol_hook_R110~s2:barrel", "pistol_hook_R110:stock"], kind="pistol",
        attach="two_anchor", status="reference",
        note="Exact source no-pack grab angle (fidelity reference); the right forearm swings through it in walk / sprint."),
    "belt.R_hip.pistol_rear140": dict(caps=["pistol_hook_R140~s2:barrel", "pistol_hook_R140:stock"], kind="pistol",
        attach="two_anchor", status="alternative",
        note="Cleanest right-hip spot for the arms, but 30 deg (9.5 cm) behind the source grab and its butt reaches the "
             "back belt point."),
    "belt.R_hip.pistol_rigid_root": dict(caps=["pistol_hook_R110_root:barrel", "pistol_hook_R110_root:stock"], kind="pistol",
        attach="rigid", bone="root", status="reference",
        note="Rigid on root like the rig bone holster_pistol."),
    "belt.back.tomahawk": dict(caps=["tomahawk_185_edgeL~s2:haft", "tomahawk_185_edgeL:head"], kind="tomahawk",
        attach="two_anchor", bone="pelvis", anchor_bones=["pelvis (head on the belt band)", "skin of the buttock (haft)"], status="recommended",
        note="Through the belt just left of the spine, head on the band with the edge toward the left (away from the "
             "pistol butt and the right elbow)."),
    "belt.back_right.tomahawk_150": dict(caps=["tomahawk_150:haft", "tomahawk_150:head"], kind="tomahawk",
        attach="rigid", bone="pelvis", status="rejected",
        note="Doddridge's 'right of the belt'; the right upper arm swings through the head in walk (-8.8 cm) and the "
             "pistol butt occupies it."),
    "belt.back.atlatl": dict(caps=["atlatl_200_lean20~s2"], kind="atlatl", attach="two_anchor", bone="pelvis", status="recommended",
        note="Board tucked through the belt just left of the spine, bottom leaning 20 deg to the left (instead of the back tomahawk)."),
    "belt.back_left.atlatl_upright": dict(caps=["atlatl_180~s2"], kind="atlatl", attach="two_anchor", bone="pelvis",
        status="alternative", note="Board upright through the belt at the spine."),
    "belt.back_left.tomahawk": dict(caps=["tomahawk_200_edgeL~s2:haft", "tomahawk_200_edgeL:head"], kind="tomahawk",
        attach="two_anchor", bone="pelvis", status="alternative",
        note="Second tomahawk position; only when belt.back is empty (the heads overlap)."),
    "belt.back_left.knife": dict(caps=["knife_L230~s2"], kind="knife", attach="two_anchor", bone="pelvis", status="recommended",
        note="Sheath knife behind the left hip, behind the shot pouch (Doddridge: knife on the left)."),
    "belt.L_hip.pistol": dict(caps=["pistol_hook_L280~s2:barrel", "pistol_hook_L280:stock"], kind="pistol",
        attach="two_anchor", status="recommended",
        note="Second belt pistol: belt hook at the left hip in front of the shot pouch, butt forward, cross draw."),
    "belt.L_hip.knife": dict(caps=["knife_L285~s2"], kind="knife", attach="two_anchor", bone="pelvis", status="alternative",
        note="Knife at the left front hip; the left thigh and hand sweep it."),
    "belt.L_hip.saber": dict(caps=["saber_L:hilt", "saber_L~s2:scabbard"], kind="saber", attach="two_anchor", bone="pelvis",
        status="recommended", note="Hanger in a frog, hilt forward at the left hip, scabbard down and back."),
    "belt.front_left.pistol_tuck": dict(caps=["belt_diag_F340~s2:barrel", "belt_diag_F340:stock"], kind="pistol",
        attach="two_anchor", status="rejected",
        note="Pushed through a plain belt left of the buckle: the left thigh passes through the barrel in crouch."),
    # sash (sash_fingerwoven, ew_sash worn as a belt)
    "sash.front_left.pistol": dict(caps=["sash_diag_F345:barrel", "sash_diag_F345:stock"], kind="pistol",
        attach="rigid", bone="spinea", status="recommended_with_mitigation",
        note="Pushed through the sash left of centre at a steep diagonal, butt up-right (cross draw). Clips the left "
             "thigh in a deep crouch unless the crouch nudge hook tilts it."),
    "sash.front_right.pistol": dict(caps=["sash_diag_F15:barrel", "sash_diag_F15:stock"], kind="pistol",
        attach="rigid", bone="spinea", status="alternative", note="Right of centre, same diagonal."),
    # pistol sling (new item) across the chest
    "pistol_sling.chest_L": dict(caps=["sling_diag_chestL:barrel", "sling_diag_chestL:stock"], kind="pistol",
        attach="rigid", bone="spined", status="recommended_with_mitigation",
        note="Hung on the sling on the left chest, barrel down-left, butt up-right (cross draw)."),
    "pistol_sling.chest_R": dict(caps=["sling_diag_chestR:barrel", "sling_diag_chestR:stock"], kind="pistol",
        attach="rigid", bone="spined", status="recommended_with_mitigation",
        note="Hung on the sling on the right chest where it crosses to the left hip."),
    # powder horn (moved off the right hip)
    "horn.back_R_top": dict(caps=["horn_backR_top2:base", "horn_backR_top2:spout"], kind="horn", attach="rigid",
        bone="spinec", status="recommended",
        note="Behind and below the right arm, above the pistol butt: base plug near the spine, spout forward-down to the "
             "right side. Strap over the left shoulder (Knox 1757), shortened."),
    "horn.back_R_under": dict(caps=["horn_backR_under:base", "horn_backR_under:spout"], kind="horn", attach="rigid",
        bone="pelvis", status="alternative", note="Behind the right hip below the belt."),
    "horn.back_L_top": dict(caps=["horn_backL_top:base", "horn_backL_top:spout"], kind="horn", attach="rigid",
        bone="spinec", status="alternative", note="Mirror behind the left arm, on the pouch strap."),
    "horn.under_arm_R": dict(caps=["horn_underarm_R:base", "horn_underarm_R:spout"], kind="horn", attach="rigid",
        bone="spinec", status="rejected", note="Literal 'under the right arm': the upper arm hangs on it (-10 cm)."),
    "horn.hip_L_over_pouch": dict(caps=["horn_hipL_over_pouch:base", "horn_hipL_over_pouch:spout"], kind="horn",
        attach="rigid", bone="spinea", status="rejected", note="On the shot pouch at the left hip: the left arm sweeps it."),
    "horn.chest": dict(caps=["horn_chest_front:base", "horn_chest_front:spout"], kind="horn", attach="rigid",
        bone="spined", status="rejected", note="High on the chest: the thighs reach it in crouch."),
    # back
    "back.long_A.musket": dict(caps=["musket_L_up_spineb"], kind="musket", attach="rigid", bone="spineb",
        status="recommended", note="Slung over the left shoulder, muzzle up behind the left shoulder, butt behind the "
        "right hip; the source long-gun draw reaches over the left shoulder with the left hand."),
    "back.long_A.musket_outer": dict(caps=["musket_L_up_outer"], kind="musket", attach="rigid", bone="spineb",
        status="layer_1", note="The same line 7.5 cm further out, over a crossing item / belt items at the back."),
    "back.long_A.spears": dict(caps=["spears_L"], kind="spear_pair", attach="rigid", bone="spineb", status="recommended"),
    "back.long_A.darts": dict(caps=["darts_L"], kind="dart_bundle", attach="rigid", bone="spineb", status="recommended"),
    "back.long_A.bow": dict(caps=["bow_L"], kind="bow", attach="rigid", bone="spineb", status="alternative"),
    "back.long_B.bow": dict(caps=["bow_R"], kind="bow", attach="rigid", bone="spineb", status="recommended",
        note="Stave across the back, top limb behind the right shoulder (the source bow stow line), string across the "
             "chest; the source bow draw takes it at the left mid back with the left hand."),
    "back.long_B.bow_source": dict(caps=["bow_source"], kind="bow", attach="rigid", bone="spineb", status="reference",
        note="The source bow stow pose itself (grip at the grab point, stave along the source prop +Y)."),
    "back.long_B.spears": dict(caps=["spears_R"], kind="spear_pair", attach="rigid", bone="spineb", status="recommended",
        note="Points up behind the right shoulder: the right hand takes the next one over the right shoulder."),
    "back.long_B.darts": dict(caps=["darts_R"], kind="dart_bundle", attach="rigid", bone="spineb", status="recommended",
        note="Nocks up behind the right shoulder (the source arrow reach)."),
    "back.long_B.musket": dict(caps=["musket_R_up"], kind="musket", attach="rigid", bone="spineb", status="alternative"),
    "back.quiver": dict(caps=["quiver_R"], kind="quiver", attach="rigid", bone="spineb", status="recommended",
        note="Back quiver, arrow nocks behind the right shoulder where the source reload clip reaches."),
    "back.quiver_outer": dict(caps=["quiver_R_outer"], kind="quiver", attach="rigid", bone="spineb", status="layer_1"),
    "back.musket_source_muzzle_down": dict(caps=["musket_source_muzzle_down"], kind="musket", attach="rigid",
        bone="spineb", status="rejected",
        note="The source long-gun stow taken literally: the Brown Bess is 1.59 m, so the butt ends behind the head "
             "and the muzzle at shin height."),
}


def cand_index(raw):
    return {c["id"]: c for c in raw["candidates"]}


def group_min(entry, field, cats):
    """min over categories of surface (field='surface') or limbs (field='limbs')."""
    best = None
    if field == "surface":
        for k in cats:
            v = entry["surface"].get(k)
            if v and (best is None or v[0] < best[0]):
                best = [v[0], v[1].split("@")[0], v[2], v[3]]
    else:
        for key, v in entry["limbs"].items():
            cat, limb = key.split("|")
            if cat in cats and (best is None or v[0] < best[0]):
                best = [v[0], limb, v[1], v[2]]
    return best


# Clips whose purpose is to reach an item: their hand contact with that item is expected.
EXPECTED_REACH = {
    "quiver": ["actor_b-p-bow-reload--part"],
    "dart_bundle": ["actor_b-p-bow-reload--part"],
    "spear_pair": ["actor_b-p-bow-reload--part"],
    "bow": ["actor_b-p-bow-reload--part"],
}


def placement_checks(caps, C, clip_cat, kind):
    """Per group: min surface clearance and min limb clearance over the placement's capsules,
    from the per-clip minima (expected reach clips excluded for the limb check)."""
    skip = set(EXPECTED_REACH.get(kind, []))
    out = {}
    worst_clips = {}
    for c in caps:
        for clip, v in C[c].get("by_clip", {}).items():
            w = worst_clips.setdefault(clip, [9.0, "", 9.0])
            if clip not in skip and v[0] < w[0]:
                w[0], w[1] = v[0], v[1]
            w[2] = min(w[2], v[2])
    for g, cats in GROUPS.items():
        s = l = None
        for clip, w in worst_clips.items():
            if clip_cat.get(clip) not in cats:
                continue
            if s is None or w[2] < s[0]:
                s = [w[2], clip]
            if w[0] < 9.0 and (l is None or w[0] < l[0]):
                l = [w[0], w[1], clip]
        out[g] = {"surface_cm": cm(s[0]) if s else None, "surface_clip": s[1] if s else None,
                  "limb_cm": cm(l[0]) if l else None, "limb": l[1] if l else None, "limb_clip": l[2] if l else None}
    ranked = sorted(worst_clips.items(), key=lambda kv: min(kv[1][0], kv[1][2]))[:6]
    worst = [{"clip": k, "category": clip_cat.get(k), "limb_cm": cm(v[0]) if v[0] < 9 else None, "limb": v[1] or None,
              "surface_cm": cm(v[2])} for k, v in ranked]
    return out, worst, sorted(skip)


def verdict(checks):
    worst = min(min(checks[g]["surface_cm"], checks[g]["limb_cm"]) for g in ("locomotion", "crouch", "weapon_use"))
    if worst >= CLEAN_CM:
        return "clean", worst
    if worst >= CONTACT_CM:
        return "contact", worst
    return "clips", worst


def pair_gap(C, a, b, grp):
    x = C.get(a, {}).get("pairs", {}).get(b) or C.get(b, {}).get("pairs", {}).get(a)
    if not x:
        return None
    return x.get(grp)


def placement_gap(C, pa, pb, grp):
    best = None
    for a in PLACEMENTS[pa]["caps"]:
        for b in PLACEMENTS[pb]["caps"]:
            v = pair_gap(C, a, b, grp)
            if v and (best is None or v[0] < best[0]):
                best = v
    return best


def cap_geometry(cands, cap_id):
    c = cands[cap_id]
    o, a, L = c["origin"], c["axis"], c["length"]
    e = [o[i] + a[i] * L for i in range(3)]
    return {"from": r3(o), "to": r3(e), "radius": c["radius"], "bone": c["bone"], "anchors": c.get("anchors")}


# ---------------------------------------------------------------------------------------------
def build_body_fit(raw, cands):
    b = raw["bind"]
    joints = {k: v["origin"] for k, v in b["joints"].items()}
    # holster bone summary over all sampled clips
    hol = {}
    for h, clips in raw["holsters"].items():
        rel = {}
        for bn in ("root", "pelvis", "spinea", "spineb", "spined"):
            dm = max(v["rel"][bn]["drift_max"] for v in clips.values())
            tm = max(v["rel"][bn]["turn_max"] for v in clips.values())
            worst = max(clips.items(), key=lambda kv: kv[1]["rel"][bn]["drift_max"])[0]
            rel[bn] = {"drift_max_m": round(dm, 3), "turn_max_deg": round(tm, 1), "worst_clip": worst}
        smin = min(v["surf_min"] for v in clips.values())
        smax = max(v["surf_max"] for v in clips.values())
        keyed_by = sorted(c for c, m in raw["clips"].items() if h in (m.get("keys_holsters") or []))
        bind_xf = b["joints"][h]
        # depth under the legacy outer surface at bind (radial, from the fine no-gear map)
        fine = b["outer_fine_nogear"]
        hp = bind_xf["origin"]
        yk = min(fine["rows"], key=lambda k: abs(float(k) - hp[1]))
        ax = fine["axis"][yk]
        ang = (math.degrees(math.atan2(-(hp[0] - ax[0]), hp[2] - ax[1])) + 360.0) % 360.0
        row = fine["rows"][yk]
        ak = min(row, key=lambda k: min(abs(float(k) - ang), 360 - abs(float(k) - ang)))
        radial = math.hypot(hp[0] - ax[0], hp[2] - ax[1])
        hol_depth = round(float(row[ak]) - radial, 3)
        hol[h] = {
            "depth_below_outer_surface_at_bind_m": hol_depth,
            "parent": b["holster_parents"][h],
            "bind": bind_xf,
            "bind_angle_deg": angle_of(bind_xf["origin"]),
            "keyed_in_sampled_clips": len(keyed_by),
            "not_keyed_in": sorted(c for c, m in raw["clips"].items() if not m.get("missing") and h not in (m.get("keys_holsters") or [])),
            "surface_distance_range_m": [round(smin, 3), round(smax, 3)],
            "drift_vs_bone": rel,
        }
    hol["holster_long"]["reading"] = ("Rigid on spineb in every clip (keyed = rest). Its origin lies 6-8 cm inside the back "
                                      "left of the spine (x 0.06, y 1.05): a pivot, not a surface point. The source long-gun "
                                      "and bow grips are 0.30-0.36 m and 0.13 m from it (source_stows prop_in_closest_holster).")
    hol["holster_pistol"]["reading"] = ("Keyed with the same value relative to root in every sampled clip: it follows root, not "
                                        "the pelvis, so it slides up to 11 cm against the hip (run-bw-lt) and turns up to 49 deg. "
                                        "In the idle it sits over the right buttock (x -0.08, y 0.85, z -0.13); at bind 3 cm under "
                                        "the coat surface. The source no-pack pistol grab is 13 cm from it: the stowed pistol "
                                        "hangs between holster_pistol and holster_melee.")
    hol["holster_melee"]["reading"] = ("Same behaviour as holster_pistol (root-fixed). In the idle it sits on the right hip side "
                                       "(x -0.15, y 0.83, z -0.02), 5 cm under the surface at bind; the source no-pack pistol "
                                       "grab is 9 cm from it.")

    # source stows from the draw clips: grab frame = t 0 of *^idle / stow clips, last frame of idle^grab
    stows = {}
    for e in raw["draws"]:
        if e.get("missing"):
            continue
        fr = e["frames"]
        kind = e["kind"]
        if kind.startswith("grab"):
            f = fr[-1]
        elif kind in ("reach_arrow", "reach_arrow_crouch"):
            # the right hand over the right shoulder (0.3 s), before it pulls the arrow up and out
            f = min(fr, key=lambda x: abs(x["t"] - 0.3))
        elif kind == "put_away":
            f = fr[-1]
        else:
            f = fr[0]
        hand = "l" if e["weapon"] in ("bow",) else "r"
        prop = f[hand + "_prop"]
        if e["weapon"] == "arrows":
            # the reaching hand is the right one; the props hold the bow in front
            prop = f["r_wrist"]
        key = e["weapon"] + ":" + kind + (":" + e["base"].replace("actor_b-p-", "") if "crouch" in e["base"] else "")
        stows[key] = {
            "clip": e["clip"], "additive_twin": e.get("add"), "base_pose": e["base"], "length_s": e["length"],
            "grab_time_s": f["t"], "weapon_prop_bone": (hand + "_hand_prop_attachment") if e["weapon"] != "arrows" else "r_wrist (reaching hand; the props hold the bow)",
            "prop_position": prop, "prop_angle_deg": angle_of(prop), "prop_height": prop[1],
            "prop_surface_distance_m": f[hand + "_surf"],
            "prop_barrel_dir": f[hand + "_prop_zdir"], "prop_up_dir": f[hand + "_prop_ydir"],
            "r_wrist": f["r_wrist"], "l_wrist": f["l_wrist"],
            "closest_holster": min(("holster_pistol", "holster_melee", "holster_long"), key=lambda h: f[hand + "_to_" + h]),
            "distance_to_holster_m": {h: f[hand + "_to_" + h] for h in ("holster_pistol", "holster_melee", "holster_long")},
            "keys_holster_bones": e["keys_holsters"],
            "prop_in_closest_holster_at_min": e["closest"].get(hand + "|" + min(("holster_pistol", "holster_melee", "holster_long"), key=lambda h: f[hand + "_to_" + h])),
        }
    readings = {
        "pistol": ("The game's current pistol actions (pistol/stand/equip etc.) use the BACKPACK variants: the right hand "
                   "reaches behind to the small of the back (147 deg, y 1.05). The --no-pack variants (same states, "
                   "Actor_B without a backpack) reach the RIGHT HIP on the belt line: grip at 110 deg, y 0.914, barrel "
                   "straight down, lock outward, butt to the rear. Frontier has no backpack, so the no-pack clips are "
                   "the faithful draw for a belt pistol."),
        "musket": ("lg-stealth: the LEFT hand reaches over the left shoulder (wrist y 1.44) to the grip at the upper left "
                   "back (0.10, 1.34..1.39, -0.09..-0.11); the stowed gun hangs muzzle DOWN. Taken literally with the "
                   "1.59 m Brown Bess the butt ends behind the head and the muzzle at shin height (rejected placement "
                   "back.musket_source_muzzle_down)."),
        "bow": ("p-bow-draw-grab / stow-grab: the LEFT hand takes the bow at the left mid back (0.10, 1.17, -0.05); the "
                "stave runs from the lower left to behind the right shoulder (prop +Y (-0.46, 0.89, 0.05))."),
        "arrows": ("p-bow-reload: the right hand goes up over the right shoulder (wrist (-0.25, 1.45, 0.06) at 0.3-0.4 s) "
                   "and pulls up and out (to y 1.6): a back quiver with the nocks behind the right shoulder."),
        "throwable": ("p-molotov-draw^idle: the right hand starts at the small of the back (173 deg, y 1.03) and passes "
                      "the right back of the belt (149 deg, y 0.92) at 0.2 s on its way forward: usable for a tomahawk "
                      "at the back of the belt (start the clip at 0.1-0.2 s)."),
    }

    # outer surface: legacy outfit rows and the customizer skin proxy, every 15 deg at key heights
    om, sm = b["outer_map"], b["skin_map"]
    surface_rows = {}
    for y in sorted(om, key=float):
        row = {}
        for a, v in om[y].items():
            skin = sm.get(y, {}).get(a) if isinstance(sm.get(y), dict) else None
            row[a] = {"outer_r": v[0], "label": v[1], "skin_proxy_r": skin,
                      "bulk_cm": cm(v[0] - skin) if isinstance(skin, (int, float)) else None}
        surface_rows[y] = row
    # regional bulk of the legacy outfit (outer minus skin proxy), median over bins
    def med(vals):
        vals = sorted(v for v in vals if v is not None)
        return vals[len(vals) // 2] if vals else None
    regions = {"back_upper (y 1.15-1.30, 150-210 deg)": (1.15, 1.30, 150, 210),
               "back_lower (y 1.00-1.10, 150-210 deg)": (1.00, 1.10, 150, 210),
               "chest (y 1.15-1.30, 330-30 deg)": (1.15, 1.30, -30, 30),
               "waist / belt (y 0.95, all)": (0.95, 0.95, 0, 360),
               "hips (y 0.80-0.90, 60-120 / 240-300 deg)": (0.80, 0.90, 60, 120)}
    legacy_bulk = {}
    for name, (y0, y1, a0, a1) in regions.items():
        vals = []
        for y, row in surface_rows.items():
            if not (y0 - 1e-6 <= float(y) <= y1 + 1e-6):
                continue
            for a, v in row.items():
                aa = float(a)
                aa = aa - 360 if a0 < 0 and aa > 180 else aa
                if a0 <= aa <= a1 and v["bulk_cm"] is not None and v["label"] not in ("horn", "pouch", "wood", "horn_tip"):
                    vals.append(v["bulk_cm"])
        legacy_bulk[name] = {"median_cm": med(vals), "n": len(vals)}

    outfit_bulk = {
        "note": ("Outer surface above the skin, in mm, per outfit and region. 'design' values come from the customizer "
                 "layer envelopes (tools/character/lib/layers.py, customizer_design.md 5.3) and the fur lengths (costume "
                 "bible 2.4, customizer_design.md 9.1-9.4: belts and straps flatten the fur to 20 %). Stowed items must "
                 "sit on this surface: stow offset along the outward normal = bulk(outfit, region) - bulk(legacy coat, "
                 "region). The legacy measured values (legacy_outfit_measured) are the current baked outfit against the "
                 "customizer's full-skin body.glb as a skin proxy; the two bodies are not the same shape, so they are an "
                 "upper bound for the legacy coat."),
        "reference_legacy_coat_mm": {"back": 17, "chest": 17, "waist_belt": 24, "hips_skirt": 20},
        "outfits": {
            "shirt_only": {"back": [5, 6, 20], "chest": [5, 6, 20], "waist_belt": [8, 10, 12],
                           "note": "shirt / shift worn alone; blousing above a belt up to 20 mm (hunting shirt worn as shirt)."},
            "waistcoat": {"back": [10, 11, 12], "chest": [10, 11, 12], "waist_belt": [14, 16, 18]},
            "coat_or_frock": {"back": [15, 17, 18], "chest": [15, 17, 18], "waist_belt": [22, 24, 26],
                              "note": "legacy hunting frock, regimental coats, capots without wrap; skirts free-hanging."},
            "hunting_shirt_outer": {"back": [15, 18, 35], "chest": [15, 18, 35], "waist_belt": [22, 24, 28],
                                    "note": "Doddridge: wide enough to overlap a foot when belted; the bosom is used as a pocket (bloused 15-20 mm more above the belt)."},
            "fur_coat_tailored": {"back": [40, 75, 120], "chest": [40, 75, 120], "waist_belt": [28, 33, 40],
                                  "note": "13-18 mm base + 4 mm hide + pile 20-30 (beaver) / 50-80 (wolf) / 60-100 (bear) mm; under belts and slings the pile flattens to 20 %; a slung weapon presses it about half way."},
            "fur_mantle_or_robe": {"back": [60, 95, 130], "chest": [45, 70, 110], "waist_belt": [35, 45, 50],
                                   "note": "wrap layer: inner >= 22 mm over the outer garment, hide 5 mm, full pile; belted at the waist."},
            "blanket_wrap_matchcoat": {"back": [30, 45, 60], "chest": [30, 40, 55], "waist_belt": [30, 35, 45],
                                       "note": "wrap layer: inner >= 22 mm, 2-3 folded layers of 3-4 mm wool, 10-30 mm drape folds at the back."},
            "capot_with_sash": {"back": [20, 23, 28], "chest": [20, 23, 28], "waist_belt": [26, 30, 34],
                                "note": "blanket cloth 3-4 mm, bloused above the sash."},
        },
        "format": "[min, typical, max] mm",
        "legacy_outfit_measured": legacy_bulk,
    }

    # sweep map (limb clearance of points 3 cm outside the outer surface)
    sweep = []
    for p in raw["grid"]:
        e = {"y": p["y"], "a": p["a"], "outer_r": p["outer_r"], "surface": p["surface"]}
        for g, cats in GROUPS.items():
            vals = [(p["limb_min"][c][0], p["limb_min"][c][1], p["limb_min"][c][2]) for c in cats if c in p["limb_min"]]
            if vals:
                m = min(vals)
                e[g] = [cm(m[0]), m[1], m[2]]
        dr = p["drift"]
        best = min(("root", "pelvis", "spinea", "spineb", "spinec", "spined"), key=lambda bn: dr.get(bn + "|loco", 9))
        e["best_rigid_bone"] = best
        e["best_rigid_drift_cm"] = {"play": cm(dr.get(best + "|loco")), "traversal": cm(dr.get(best + "|trav"))}
        e["drift_cm_play"] = {bn: cm(dr.get(bn + "|loco")) for bn in ("pelvis", "spinea", "spineb", "spinec", "spined")}
        sweep.append(e)

    return {
        "format": "frontier-loadout-body-fit", "version": 1,
        "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "generator": "tools/loadout/measure_body_fit.gd (Godot 4.7, headless) + tools/loadout/build_fit_data.py",
        "provenance": PROVENANCE,
        "conventions": {
            "space": "rig (skeleton) space at the bind pose null-add: +Y up, character faces +Z, character right = -X",
            "angles": "around the torso axis (pelvis-spine chain): 0 front, 90 character right, 180 back, 270 left",
            "player_note": "FrontierPlayer turns the rig 180 deg (model_yaw_offset_deg); these positions are rig-local.",
            "body": "assets/character/actor_b_body.glb via CharacterBodyMesh (helper bones driven as in game)",
            "clearance_sign": "negative = the surface or a limb capsule passes into the item by that much",
        },
        "method": {
            "clips": {k: v for k, v in raw["clips"].items()},
            "samples_per_clip": "up to 6 evenly spaced (every key of the draw clips)",
            "posing": "channel by channel like the deterministic mixer: rest (= null-add), full-body clip, partial over a base clip at t 0, additive twin as base * rest^-1 * add",
            "surface": "Clothes + Gear vertices of the torso, hips and upper thighs with outward normals (belt / strap edge vertices dropped), CPU-skinned; signed distance = median plane distance of the 5 nearest",
            "limbs": {k: v for k, v in b["limb_radius"].items()},
            "limb_note": "capsules between joints, radius = 90th percentile of the dominated vertices' distance (middle 60 % of the segment); the thigh starts 25 % down from the hip joint",
            "groups": GROUPS,
        },
        "bind_landmarks": {
            "joints": joints,
            "belt": {"band_y": [0.922, 0.962], "centre_y": 0.942, "perimeter_m": 0.95, "ring": b["belt_ring"],
                     "follows": "spinea at its top edge, pelvis at its bottom edge (the build averages the coat weights along the band)"},
            "gear_parts": b["gear_parts"],
            "old_powder_horn": {"aabb": [b["gear_parts"]["horn"]["min"], b["gear_parts"]["horn"]["max"]],
                                "reading": "0.19 m long and 6.7 cm tall at the right hip (90-120 deg): with its 5.4 cm base it reads as a round lump; it moves (see carry_points_survey.json horn)"},
            "shot_pouch": {"aabb": [b["gear_parts"]["pouch"]["min"], b["gear_parts"]["pouch"]["max"]],
                           "angles_deg": [240, 285], "note": "left hip, rigid on the pelvis, hangs from the strap over the right shoulder"},
            "straps": "crossed: left shoulder -> right hip and right shoulder -> left hip, over the coat, y 0.95-1.37",
        },
        "outer_surface": {"rows": surface_rows,
                          "note": "outer_r: max radius of the legacy outer surface per 5 cm x 15 deg bin (label = outermost material); skin_proxy_r: customizer body.glb torso (its A-pose arms show up at the sides above y 0.95)."},
        "outfit_bulk": outfit_bulk,
        "holster_bones": hol,
        "source_stows": stows,
        "source_stow_readings": readings,
        "sweep_map": {
            "note": ("Points 3 cm outside the outer surface every 5 cm x 15 deg, carried by the skin weights of their "
                     "surface vertex. Per group: [min clearance to any limb capsule in cm, limb, clip]. "
                     "best_rigid_bone / drift: the bone a rigid attachment should use there and how far it drifts from "
                     "the skinned surface point (play = locomotion, crouch, weapon use; traversal separately)."),
            "points": sweep,
        },
        "findings": [
            "Belt band: its lower edge follows the pelvis (0-1 cm drift at y 0.85-0.90), its upper edge spinea (y 0.95: 0-8 cm); above 1.05 spinec, above 1.20 spinec / spined.",
            "Hip twist: hip-turning clips (run-bw-lt) rotate the pelvis up to ~50 deg against the spine; items on the belt and items on the back move against each other there.",
            "Sides of the waist (60-120 and 240-300 deg, y 0.85-1.25): the hanging arms and hands (idle), the forearm swing (walk, run) and the elbows reach 3-7 cm into points 3 cm off the surface.",
            "Front below the belt (330-30 deg, y 0.55-0.95): the thighs reach 7-11 cm into items in crouch, running knee lifts and climbs.",
            "Back of the belt below the buttocks (y < 0.65): the heels kick up into hanging items when running (shin -3 to -9 cm).",
            "Clean zones: back 135-225 deg from the belt up to the shoulder blades in play clips; right back hip 125-160 deg; upper back / behind the shoulders for long weapons (rigid on spineb).",
            "Climb / ladder / ledge clips: every back and belt item touches the body or a limb somewhere (-2 to -11 cm); traversal needs the stow pose kept but may nudge items (see hooks).",
        ],
    }


# ---------------------------------------------------------------------------------------------
def build_survey(raw, cands, C):
    items = raw["items"]
    pl_out = {}
    for pid, P in PLACEMENTS.items():
        caps = [c for c in P["caps"] if c in cands]
        clip_cat = {k: m.get("category") for k, m in raw["clips"].items()}
        checks, worst_clips, expected = placement_checks(caps, C, clip_cat, P["kind"])
        v, worst = verdict(checks)
        grip_cap = cands[caps[0]]
        o, a, L = grip_cap["origin"], grip_cap["axis"], grip_cap["length"]
        grip = [o[i] + a[i] * L * grip_cap.get("grip_at", 0.0) for i in range(3)]
        hand = "l" if P["kind"] in ("musket", "bow") and pid.startswith("back.") else "r"
        rs = raw["bind"]["joints"][hand + "_shoulder"]["origin"]
        reach = math.dist(grip, rs)
        pl_out[pid] = {
            "kind": P["kind"], "status": P["status"], "attach": P["attach"], "bone": P.get("bone"),
            "anchors": P.get("anchor_bones"), "note": P.get("note", ""),
            "capsules": {c: cap_geometry(cands, c) for c in caps},
            "grip_bind": r3(grip), "grip_angle_deg": angle_of(grip), "grip_height": round(grip[1], 3),
            "outward_dir_bind": r3([-math.sin(math.radians(angle_of(grip))), 0.0, math.cos(math.radians(angle_of(grip)))], 3),
            "drawing_hand": "left" if hand == "l" else "right",
            "reach_from_shoulder_m": round(reach, 3),
            "reachable": reach <= 0.62,
            "checks": checks, "verdict": v, "worst_play_cm": round(worst, 1),
            "worst_clips": worst_clips, "expected_reach_clips_excluded": expected,
        }

    def gap(pa, pb):
        g = {grp: placement_gap(C, pa, pb, grp) for grp in ("loco", "trav")}
        return {"play_cm": cm(g["loco"][0]) if g["loco"] else None, "play_clip": g["loco"][1] if g["loco"] else None,
                "traversal_cm": cm(g["trav"][0]) if g["trav"] else None, "traversal_clip": g["trav"][1] if g["trav"] else None}

    conflict_ids = ["belt.R_hip.pistol", "belt.back.tomahawk", "belt.back.atlatl", "belt.back_left.knife",
                    "belt.back_left.tomahawk", "belt.L_hip.pistol", "belt.L_hip.knife", "belt.L_hip.saber",
                    "sash.front_left.pistol", "pistol_sling.chest_L", "pistol_sling.chest_R", "horn.back_R_top",
                    "back.long_A.musket", "back.long_A.musket_outer", "back.long_A.spears", "back.long_A.darts",
                    "back.long_B.bow", "back.long_B.spears", "back.long_B.darts", "back.quiver", "back.quiver_outer"]
    conflicts = {}
    for i, pa in enumerate(conflict_ids):
        for pb in conflict_ids[i + 1:]:
            g = gap(pa, pb)
            if g["play_cm"] is not None and g["play_cm"] < 3.0:
                conflicts[pa + " | " + pb] = g

    # back layering: extra standoff for the outer item where two back items overlap (same bone: constant gap)
    back_ids = ["back.long_A.musket", "back.long_A.spears", "back.long_A.darts", "back.long_B.bow",
                "back.long_B.spears", "back.long_B.darts", "back.quiver", "horn.back_R_top", "belt.back.tomahawk",
                "belt.back.atlatl", "belt.R_hip.pistol"]
    layering = {}
    for i, pa in enumerate(back_ids):
        for pb in back_ids[i + 1:]:
            g = placement_gap(C, pa, pb, "loco")
            if g and g[0] < 0.01:
                layering[pa + " | " + pb] = {"gap_cm": cm(g[0]), "extra_standoff_for_outer_cm": round(-g[0] * 100 + 1.0, 1),
                                             "worst_clip": g[1]}

    lengths = {
        "musket": {"length_m": items["musket"]["size"][2], "grip_to_muzzle_m": -items["musket"]["markers"]["Muzzle"][2],
                   "grip_to_butt_m": items["musket"]["aabb_max"][2]},
        "bow": {"length_m": items["bow"]["size"][1], "string_depth_m": items["bow"]["size"][2]},
        "spear": {"length_m": items["spear"]["size"][2], "grip_to_tip_m": 0.807, "grip_to_butt_m": 0.993},
        "atlatl_dart": {"length_m": items["atlatl_dart"]["size"][2]},
        "atlatl": {"length_m": items["atlatl"]["size"][2], "width_m": items["atlatl"]["size"][0]},
        "pistol": {"length_m": items["pistol"]["size"][2], "grip_to_muzzle_m": 0.31, "butt_behind_grip_m": 0.081,
                   "butt_below_grip_m": 0.089},
        "tomahawk": {"length_m": items["tomahawk"]["size"][1], "head_length_m": items["tomahawk"]["size"][2]},
        "arrow": {"length_m": items["arrow"]["size"][2]},
    }

    gear = {
        "legacy_baked_belt": {
            "customizer_slot": "(legacy body, assets/character/actor_b_body.glb)", "band_y": [0.922, 0.962],
            "points": {
                "R_hip": {"placement": "belt.R_hip.pistol", "allowed": ["pistol"], "primary": True},
                "back": {"placement": "belt.back.tomahawk", "allowed": ["tomahawk", "atlatl", "knife"],
                         "placements_by_kind": {"tomahawk": "belt.back.tomahawk", "atlatl": "belt.back.atlatl"}},
                "back_left": {"placement": "belt.back_left.knife", "allowed": ["knife", "tomahawk (only if back is empty)"],
                              "placements_by_kind": {"knife": "belt.back_left.knife", "tomahawk": "belt.back_left.tomahawk"}},
                "L_hip": {"placement": "belt.L_hip.pistol", "allowed": ["pistol (cross draw)", "saber", "knife"],
                          "placements_by_kind": {"pistol": "belt.L_hip.pistol", "saber": "belt.L_hip.saber", "knife": "belt.L_hip.knife"}},
            },
            "pistol_points": 2, "note": "The shot pouch hangs at the left hip (240-285 deg) from its own strap; L_hip sits in front of it at 280 deg.",
        },
        "belt_tied_behind": {
            "customizer_slot": "accessories.waist", "evidence": "A (Doddridge [P3]: the hunting-shirt belt was always tied behind)",
            "same_points_as": "legacy_baked_belt",
            "differences": "The knot and its short ends sit at 175-185 deg: the back tomahawk moves to 200 deg (belt.back_left.tomahawk; belt.back.atlatl already sits at 200 deg) and back_left then holds nothing else (the knife goes on the shot pouch strap).",
            "pistol_points": 2,
        },
        "sash_fingerwoven": {
            "customizer_slot": "accessories.waist", "evidence": "A (Canadian arrow sash [M7c]); tucking pistols and tomahawks into a sash is general period practice (B)",
            "band_y": [0.90, 1.06], "tie": "at the left hip, ends hanging to about y 0.6 (blocks L_hip)",
            "points": {
                "R_hip": {"placement": "belt.R_hip.pistol", "allowed": ["pistol"], "primary": True, "note": "tucked, same place and draw as the belt"},
                "back": {"placement": "belt.back.tomahawk", "allowed": ["tomahawk", "atlatl", "knife"]},
                "front_left": {"placement": "sash.front_left.pistol", "allowed": ["pistol (cross draw)", "tomahawk", "knife"],
                               "note": "needs the crouch nudge (thigh)"},
            },
            "pistol_points": 2,
        },
        "ew_sash": {
            "customizer_slot": "accessories.waist (as a belt) or accessories.shoulder (as a baldric)",
            "evidence": "A/B (costume bible 3.8: finger-woven sash with white beads, belt or baldric)",
            "as_belt": "same points as sash_fingerwoven",
            "as_baldric": {"points": {"hip_end": {"allowed": ["tomahawk", "knife", "pistol"],
                                                  "note": "the hanging end at the opposite hip; on the left it replaces belt.L_hip, on the right it collides with belt.R_hip"}},
                           "pistol_points": 1},
            "pistol_points": "2 as a belt, +1 as a baldric",
        },
        "military_waist_belt": {
            "customizer_slot": "accessories.waist (fr_belt_gargoussier)", "evidence": "A (Fort Ticonderoga [M4]: buff waist belt with the red cartridge pouch on it)",
            "blocked": "the gargoussier at the front (330-30 deg, y 0.87-0.97)",
            "points": {"R_hip": {"placement": "belt.R_hip.pistol", "allowed": ["pistol"]},
                       "back": {"placement": "belt.back.tomahawk", "allowed": ["tomahawk"], "evidence": "1758: tomahawks carried by the regulars (Huck, via [M1])"},
                       "L_hip": {"placement": "belt.L_hip.saber", "allowed": ["saber / hanger", "bayonet frog", "pistol"]}},
            "pistol_points": 2,
        },
        "br_belts_cartridge": {
            "customizer_slot": "accessories.shoulder + accessories.waist", "evidence": "A (costume bible 5.6)",
            "blocked": "the cartridge box on the shoulder belt behind the right hip (120-170 deg, y 0.85-1.02): no R_hip pistol, no back-right tomahawk",
            "points": {"L_hip": {"placement": "belt.L_hip.saber", "allowed": ["saber / hanger", "bayonet", "pistol"]},
                       "chest_hook": {"placement": "pistol_sling.chest_R", "allowed": ["pistol (belt hook on the shoulder belt)"],
                                      "evidence": "Highland practice of hooking the pistol on a belt (general, B)"}},
            "pistol_points": 2,
        },
        "pistol_sling": {
            "customizer_slot": "accessories.shoulder (new item, built by the loadout workflow)",
            "evidence": "C for 1750s frontier; primary evidence is maritime and earlier: Captain Charles Johnson, A General History of the Pyrates (1724) describes Blackbeard with 'three brace of pistols' in holsters on a sling over his shoulders, and Bartholomew Roberts with two pairs hanging from a silk sling. Not in the costume bible; not verified online in this run.",
            "design": "a leather or silk sling over the right shoulder to the left hip (or both shoulders), two pistols hung by belt hooks / small holsters across the chest",
            "points": {"chest_L": {"placement": "pistol_sling.chest_L", "allowed": ["pistol"]},
                       "chest_R": {"placement": "pistol_sling.chest_R", "allowed": ["pistol"]}},
            "pistol_points": 2,
            "note": "Chest pistols are clean against the body in play clips but the swinging forearms touch them when running (-4 to -8 cm) and the thighs reach them in a deep crouch; they need the crouch / aim nudge hook.",
        },
        "horn_strap": {
            "customizer_slot": "accessories.shoulder (powder_horn)",
            "evidence": "A: 'a bullock's horn hung under the right arm from a strap over the left shoulder' (Knox 1757, via [M2])",
            "points": {"horn": {"placement": "horn.back_R_top", "allowed": ["powder horn"]}},
        },
        "shot_pouch_strap": {
            "customizer_slot": "accessories.shoulder (shot_pouch / ew_shot_pouch)",
            "evidence": "A: pouch on the belt or a strap with a folding or sheath knife [M2]",
            "points": {"pouch_knife": {"allowed": ["knife"], "note": "a sheath knife on the pouch strap or the pouch front: a period place for the belt knife that frees a belt point"}},
        },
        "back_slings": {
            "long_A": {"line": "upper end behind the LEFT shoulder, lower end behind the right hip (sling over the left shoulder, across the chest to the right hip)",
                       "placements": {"musket": "back.long_A.musket", "spear_pair": "back.long_A.spears",
                                      "dart_bundle": "back.long_A.darts", "bow": "back.long_A.bow"},
                       "draw": "left hand over the left shoulder (source lg-stealth-draw^idle)"},
            "long_B": {"line": "upper end behind the RIGHT shoulder, lower end behind the left hip (over the right shoulder, across the chest to the left hip)",
                       "placements": {"bow": "back.long_B.bow", "spear_pair": "back.long_B.spears",
                                      "dart_bundle": "back.long_B.darts", "musket": "back.long_B.musket"},
                       "draw": "bow: left hand at the left mid back (source p-bow-draw-grab^idle); spears / darts: right hand over the right shoulder (source p-bow-reload reach)"},
            "quiver": {"placement": "back.quiver", "note": "travels with the bow, no long slot; nocks behind the right shoulder",
                       "layering": "when a long_B item is slung too it lies over the quiver (use back.quiver as inner layer and push the long_B item out by the standoff in back_layering)"},
            "rule": "at most two long weapons at once: one on long_A, one on long_B",
        },
    }

    capacity = {
        "rule": "pistols the player can carry = pistol-capable points of the worn waist + shoulder gear, capped at 4 (two braces)",
        "per_gear": {
            "legacy_baked_belt / leather waist belt": {"pistols": 2, "points": ["R_hip (clean-ish, source draw)", "L_hip (cross draw, contact with the hanging left hand)"]},
            "belt_tied_behind": {"pistols": 2},
            "sash_fingerwoven / ew_sash as belt": {"pistols": 2, "points": ["R_hip", "front_left (crouch nudge)"]},
            "military_waist_belt (gargoussier)": {"pistols": 2},
            "br_belts_cartridge": {"pistols": 2, "points": ["L_hip", "chest hook on the shoulder belt"], "note": "the cartridge box blocks R_hip"},
            "ew_sash as baldric": {"pistols": 1},
            "pistol_sling (new)": {"pistols": 2},
            "no waist gear": {"pistols": 0, "note": "a pistol is then carried in the hand or not at all"},
        },
        "combos": {
            "belt": 2, "belt + pistol_sling": 4, "sash + pistol_sling": 4, "belt + ew_sash baldric": 3,
            "br_belts_cartridge (+ waist belt)": 2,
        },
        "evidence_summary": ("A 'brace' is a pair. Belt-hook pistols (sea-service, Highland all-steel, many civilian) hung from a "
                             "waist belt or shoulder belt; officers and horsemen carried pairs in saddle holsters (not on the "
                             "body); pirates of the 1710s-20s wore several on slings (Johnson 1724). For the 1750s frontier a "
                             "single pistol in the belt is the common case, two is plausible for officers, rangers and traders, "
                             "more is a game liberty. These are general arms-history points, not from the costume bible; "
                             "grade B/C."),
    }

    horn = {
        "decision": "Move the horn off the right hip (the pistol takes it) to behind and below the right arm, above the pistol butt, on its strap over the left shoulder; reshape it as a clearly curved cow horn.",
        "placement": "horn.back_R_top",
        "why": ["Knox 1757 (costume bible [M2]): horn under the right arm on a strap over the left shoulder; this keeps the side and the strap, moved behind the arm where the arm does not hang.",
                "Survey: surface clearance >= +0.8 cm in every clip group including traversal; limbs: -2.7 cm (the left elbow swinging back in run-fw reaches the base plug near the spine), -0.6 cm (right upper arm, walk-bw); crouch and weapon use clear (+5.7 / +6.5).",
                "Against the other body items in play clips: belt pistol butt +1.0 cm, back tomahawk head +0.1 cm; long_A / long_B items and the quiver lie over it (back_layering: 3.5-7.6 cm extra standoff for the item over it)."],
        "rejected": {"horn.under_arm_R": "the arm hangs on it", "horn.hip_L_over_pouch": "left arm sweep",
                     "horn.chest": "thighs in crouch", "right hip (old)": "taken by the pistol; reads as a lump"},
        "change_request": "see graph_analysis/loadout/body_fit_history.md section 6 (apply after the customizer run)",
    }

    hooks = [
        "Stow attachment: belt items rigid on pelvis at their bind offset (not the belt band's skin weights: a band vertex shears up to ~50 deg in hip-twist clips); hanging pistols two-anchor (hook on the belt, barrel along the hip skin); sash items on spinea; horn on spinec; back items on spineb (rig bone holster_long's parent).",
        "Pistol draw / holster: use the --no-pack pistol clips (actor_b-p-stealth-idle^p-grab--arm-r--no-pack, actor_b-p-stealth-draw-p^idle--arm-r--no-pack, actor_b-p-stealth-stow-p^idle--arm-r--no-pack and their --add--no-pack twins); the default (pack) clips reach the small of the back. The prop meets the grip about 5 cm in front of belt.R_hip.pistol: blend the model from the stow socket to r_hand_prop_attachment over the first 0.1 s of the draw.",
        "Musket draw: source lg-stealth-draw^idle keeps its hand path (left hand over the left shoulder) but its gun turns from muzzle-down; with the muzzle-up stow blend the model from the stow socket (fore-end at the hand) to the prop between 0.0 and 0.3 s (at 0.3 s the source gun is muzzle up in front).",
        "Tomahawk draw from the back of the belt: p-molotov-draw^idle--part started at 0.1-0.2 s (the hand passes the right back of the belt).",
        "Arrow / dart reach: p-bow-reload--part (right hand over the right shoulder) matches back.quiver and long_B nocks.",
        "Crouch / aim nudge: front items (sash.front_left.pistol, pistol_sling.*) rotate out about the band tangent by the thigh flexion (and by the forearm when aiming) so the thighs and forearms do not pass through them.",
        "Traversal: keep items stowed during climbs; allow a push-out of up to 5 cm along the outward normal while climb / ladder / ledge clips play (every back and belt item touches the body there).",
        "Layering: back items that overlap get the standoff in back_layering; the order is quiver, long_B, long_A (outermost).",
        "Outfit bulk: offset every stow point along its outward normal by bulk(outfit, region) - bulk(legacy coat, region) (body_fit.json outfit_bulk).",
    ]

    return {
        "format": "frontier-loadout-carry-points-survey", "version": 1,
        "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "provenance": PROVENANCE,
        "conventions": "rig space at null-add (+Y up, faces +Z, right = -X); angles 0 front / 90 right / 180 back / 270 left; clearances in cm, negative = interpenetration",
        "user_rules": {
            "back": "at most two long weapons slung at once",
            "sidearms": "the worn belt / sash / slings decide the carry points; pistols = pistol-capable points",
            "pistols": "separate instances with their own loaded state",
            "loadout": "chosen at camp / a chest later; data-driven presets and a default",
            "first_pistol": "on the belt at the right hip (the user's correction); the powder horn moves off that spot",
        },
        "long_weapon_classification": {
            "long": {"musket": lengths["musket"], "bow (strung)": lengths["bow"], "spear pair (2 tied)": lengths["spear"],
                     "dart bundle (5 tied)": lengths["atlatl_dart"]},
            "not_long": {"quiver": "0.66-0.76 m with the arrows; back, travels with the bow", "atlatl board": lengths["atlatl"],
                         "pistol": lengths["pistol"], "tomahawk": lengths["tomahawk"], "knife": "about 0.30 m in the sheath",
                         "saber / hanger": "about 0.8 m; waist frog or baldric"},
            "reason": "items longer than ~1.2 m cannot hang from a waist band on a 1.60 m body without reaching the ground or the knees (belt at 0.94 m): they must be slung across the back from the shoulder",
        },
        "classification_rule": {"clean": ">= -1 cm in locomotion, crouch and weapon use", "contact": ">= -3.5 cm", "clips": "< -3.5 cm",
                                "note": "traversal reported separately"},
        "gear": gear,
        "pistol_capacity": capacity,
        "placements": pl_out,
        "conflicts_below_3cm": conflicts,
        "back_layering": layering,
        "horn": horn,
        "default_layout": {
            "waist": "legacy_baked_belt (or belt_tied_behind)",
            "shoulder": "horn_strap (left shoulder) + shot_pouch_strap (right shoulder)",
            "belt": {"R_hip": "pistol", "back": "tomahawk", "back_left": "knife", "L_hip": "second pistol or empty"},
            "back": {"long_A": "musket", "long_B": "bow", "quiver": "yes (inner layer)"},
            "note": "Throwables beyond one tomahawk (second tomahawk, spears, atlatl + darts) replace an item above according to the rules.",
        },
        "integration_hooks": hooks,
    }


# ---------------------------------------------------------------------------------------------
def build_keepout(survey):
    P = survey["placements"]

    def zone(zid, purpose, used_by, bone, ang, ys, band_cm, rules, note=""):
        return {"id": zid, "purpose": purpose, "used_by": used_by, "follows_bone": bone,
                "angles_deg": ang, "y": ys, "radial_band_above_legacy_outer_cm": band_cm, "rules": rules, "note": note}

    zones = [
        zone("right_hip_pistol", "belt pistol at the right hip (source no-pack draw target)", ["belt.R_hip.pistol"], "pelvis",
             [105, 160], [0.58, 1.02], [0, 7],
             ["No accessory may hang or bulge here: no pouch, horn, cartridge box, sash ends, knife or fringe.",
              "Belts and sashes pass through at y 0.92-1.06 only (the pistol hooks or tucks on them).",
              "Coat skirts may lie under it (cloth); fur pile under it flattens (customizer_design.md 9.4)."],
             "br_belts_cartridge's box violates this zone: with the cross belts the pistol moves to L_hip / chest hook."),
        zone("back_belt_items", "tomahawk / atlatl through the belt at the back, knife behind the left hip", ["belt.back.tomahawk", "belt.back.atlatl", "belt.back_left.knife"],
             "pelvis", [170, 240], [0.50, 1.06], [0, 6],
             ["Leave free of pouches, blanket rolls and tumplines hanging below the belt.",
              "The knot of belt_tied_behind sits at 175-185 deg: the back point moves to 200 deg (see survey)."]),
        zone("left_hip_second_item", "second pistol (cross draw) / hanger frog / knife in front of the shot pouch", ["belt.L_hip.pistol", "belt.L_hip.saber", "belt.L_hip.knife"],
             "pelvis", [270, 300], [0.55, 1.05], [0, 7],
             ["The shot pouch must hang at or behind 285 deg (today 240-285: it may not move forward).",
              "Sash knots and ends tied at the left hip block this zone (sash gear lists no L_hip point)."]),
        zone("horn_back_right", "powder horn behind and below the right arm", ["horn.back_R_top"], "spinec",
             [130, 195], [1.02, 1.20], [0, 7],
             ["Keep capes, blanket folds and tumplines from filling this band; the horn strap comes over the left shoulder.",
              "A wrap (blanket, fur mantle) over it pushes it out by the wrap bulk; the horn stays outside the wrap."]),
        zone("back_long_slots", "long_A / long_B slung weapons and the quiver", ["back.long_A.*", "back.long_B.*", "back.quiver"],
             "spineb", [140, 220], [0.80, 1.45], [0, 16],
             ["No hard accessories on the back between the shoulder blades and the buttocks (blanket rolls, knapsacks, tumpline loads) while long weapons are slung; a tumpline blanket roll replaces a long slot.",
              "Wraps and fur mantles raise the slot by their back bulk (outfit_bulk)."]),
        zone("over_shoulders", "long weapons pass behind and above both shoulders; quiver nocks behind the right shoulder", ["back.long_A.*", "back.long_B.*", "back.quiver"],
             "spineb", [110, 250], [1.35, 2.35], [0, 20],
             ["Hats: brims and plumes must clear lines from (+-0.10, 1.42, -0.18) up to (+-0.5, 2.3, -0.10); tricorn back corners are the risk.",
              "Hair queues / braids lie under the slung items (they are pendulums on wrinklemaps)."]),
        zone("chest_pistol_sling", "pistols hung on the pistol sling", ["pistol_sling.chest_L", "pistol_sling.chest_R"],
             "spined", [320, 40], [1.02, 1.32], [0, 6],
             ["Only while the pistol sling is worn: gorgets, brooches and kerchief ends must stay above y 1.30 or under the pistols."]),
        zone("front_sash_tuck", "pistol through the sash at the front left", ["sash.front_left.pistol"], "spinea",
             [320, 360], [0.85, 1.12], [0, 6], ["Only with a sash: aprons and breechcloth fronts lie under it."]),
    ]
    return {
        "format": "frontier-loadout-keepout", "version": 1,
        "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "provenance": PROVENANCE,
        "conventions": "rig space at null-add; angles 0 front / 90 right / 180 back / 270 left around the torso axis; radial band measured from the legacy outer surface (data/loadout/body_fit.json outer_surface); follows_bone = the bone the zone moves with",
        "layer": "stowed weapons sit on layer 65 (above belts 60, below hair 70); a zone is kept free of layer >= 50 items that would sit on or through the stowed item",
        "bulk_rule": "for outfits with more bulk than the legacy coat the whole zone moves out by bulk(outfit, region) - bulk(legacy, region) (body_fit.json outfit_bulk)",
        "zones": zones,
        "customizer_conflicts": [
            {"item": "knife_tomahawk (accessories.waist)", "issue": "a cosmetic belt knife + tomahawk duplicates loadout weapons",
             "request": "drop it from the catalog or make it a loadout display (hidden when the loadout provides the knife / tomahawk)"},
            {"item": "powder_horn (accessories.shoulder, existing mesh)", "issue": "sits in right_hip_pistol",
             "request": "use the new horn shape and placement horn_back_right (body_fit_history.md section 6)"},
            {"item": "shot_pouch / ew_shot_pouch", "issue": "left hip; must stay at or behind 285 deg", "request": "keep today's placement"},
            {"item": "br_belts_cartridge", "issue": "cartridge box in right_hip_pistol", "request": "declare it 'blocks R_hip' in the catalog so the loadout moves the pistol"},
            {"item": "sash_fingerwoven / ew_sash", "issue": "knot and ends", "request": "tie at the left hip (270 deg), ends hanging no lower than y 0.55, nothing in right_hip_pistol"},
            {"item": "tumpline_blanket_roll / knapsack", "issue": "back_long_slots", "request": "declare 'uses back' so the loadout frees a long slot"},
        ],
    }


def main():
    raw = load(sys.argv[1])
    cpath, out = "tools/loadout/candidates.json", "data/loadout"
    for a in sys.argv[2:]:
        if a.startswith("candidates="):
            cpath = a.split("=", 1)[1]
        elif a.startswith("out="):
            out = a.split("=", 1)[1]
    cands = {c["id"]: c for c in load(cpath)["points"]}
    C = cand_index(raw)
    body = build_body_fit(raw, cands)
    survey = build_survey(raw, cands, C)
    keep = build_keepout(survey)
    os.makedirs(out, exist_ok=True)
    for name, data in (("body_fit.json", body), ("carry_points_survey.json", survey), ("keepout.json", keep)):
        with open(os.path.join(out, name), "w") as f:
            json.dump(data, f, indent=1)
        print("wrote", os.path.join(out, name), os.path.getsize(os.path.join(out, name)) // 1024, "KB")
    # console summary
    print("\nplacement                          verdict  worst  loco(s/l)      crouch(s/l)    use(s/l)       trav(s/l)")
    for pid, p in survey["placements"].items():
        ch = p["checks"]
        print("%-34s %-8s %5.1f  %s" % (pid, p["verdict"], p["worst_play_cm"], "  ".join(
            "%5.1f/%5.1f %-4s" % (ch[g]["surface_cm"], ch[g]["limb_cm"], (ch[g]["limb"] or "")[:4]) for g in GROUPS)))


if __name__ == "__main__":
    main()
