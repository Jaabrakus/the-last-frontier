#!/usr/bin/env python3
"""Loadout design data: carry points, gear, items and presets (Frontier).

Reads the two loadout surveys and the rig, and writes the data files the loadout design
(Player_Animation_Project/graph_analysis/loadout/loadout_design.md) defines:

    python3 tools/loadout/build_loadout_data.py candidates   # 1. verification capsules
    Godot --headless --path . -s tools/loadout/measure_body_fit.gd -- \
        out=<scratch>/raw_design_fit.json samples=6 candidates=res://tools/loadout/design_candidates.json
    python3 tools/loadout/build_loadout_data.py build <scratch>/raw_design_fit.json [<scratch>/pose_dump.json]   # 2. data files
    (the survey run for step 2 of revision 3 needs extra=1 pose_dump=<path> dump_torso=...; see loadout_design.md)

Step 1 writes tools/loadout/design_candidates.json: the stow placements this design derives
from the SOURCE clips (the handoff survey's bone-space transforms, pushed out of the coat),
plus the body-fit survey's recommended back / belt items for the pair checks.
Step 2 reads the survey tool's output for those capsules and writes
    data/loadout/carry_gear.json       carry points (bone + stowed transform per kind) and gear
    data/loadout/loadout_items.json    item kinds, classes, slot preferences, counts, keys
    data/loadout/loadout_presets.json  presets and the default loadout
    data/loadout/design_fit_check.json clearance of every design placement (from the run)

Frames. Every transform is in rig (skeleton) space at the bind pose null-add (+Y up, the
character faces +Z, character right = -X) or local to a bone at that pose. The handoff survey's
model_in transforms are bone-local and frame-correct. The body-fit survey's placements are in
bind space; its "source" angles were read in the posed stealth idle (root yawed 16.6 deg), so they
are not used here as source positions (see loadout_design.md section 0.2).

Provenance: the rig, bind pose and clip measurements are Actor_B data.
"""
import json
import math
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loadout_revision as R  # noqa: E402  (revision-2 candidates and checks)

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(ROOT, "data", "loadout")
RIG = os.path.join(ROOT, "characters", "Actor_B.tscn")
CAND_OUT = os.path.join(ROOT, "tools", "loadout", "design_candidates.json")

PROVENANCE = ("Rig, bind pose and clip measurements: Actor_B. "
              "Clip names keep their native asset ids in the animation library.")

# --- item geometry (model space; WeaponModels / ThrowableModels conventions) -----------------
# Firearms: origin = grip, -Z = muzzle, +Y = top, +X = lock side.  Bow: origin = handle, +Y =
# upper limb, -Z = arrow direction, string at +Z.  Spear: origin = grip (balance), -Z = point.
# Tomahawk: origin = throwing grip, +Y = haft up to the head, -Z = cutting edge.  Atlatl: origin =
# grip (front end), board along +Z to the hook.  Dart: origin = tip, shaft along +Z to the nock.
PISTOL = {"muzzle": 0.31, "butt_back": 0.081, "butt_down": 0.089, "r_barrel": 0.018, "r_stock": 0.026}
MUSKET = {"muzzle": 1.298, "butt": 0.29, "r": 0.035}
BOW = {"length": 1.5264, "string_depth": 0.1859, "r": 0.02}
SPEAR = {"tip": 0.807, "butt": 0.993, "r": 0.035}
TOMAHAWK = {"head_y": 0.401, "butt_y": 0.062, "edge": [0.0, 0.3875, -0.124], "r_haft": 0.017, "r_head": 0.03}
ATLATL = {"length": 0.5883, "spur_z": 0.526, "r": 0.03}
DART = {"length": 1.65, "r": 0.035}
QUIVER = {"length": 0.674, "r": 0.05}
SKIP_OLD_HORN = ["horn", "wood", "horn_tip"]   # the old right-hip horn moves (change request)


# --- rig --------------------------------------------------------------------------------------

def _xf_from_text(s):
    nums = [float(x) for x in re.findall(r"[-+0-9.eE]+", s.replace("Transform3D", ""))]
    m = np.eye(4)
    m[:3, :3] = np.array(nums[:9]).reshape(3, 3)     # Godot text lists the basis rows
    m[:3, 3] = nums[9:12]
    return m


def load_rest():
    txt = open(RIG).read()
    bones = {}
    for m in re.finditer(r"bones/(\d+)/(name|parent|rest) = (.*)", txt):
        bones.setdefault(int(m.group(1)), {})[m.group(2)] = m.group(3)
    names = {i: b["name"].strip('"') for i, b in bones.items()}
    glob = {}

    def g(i):
        if i not in glob:
            p = int(bones[i]["parent"])
            loc = _xf_from_text(bones[i]["rest"])
            glob[i] = loc if p < 0 else g(p) @ loc
        return glob[i]
    return {names[i]: g(i) for i in bones}


def q2m(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def m2q(r):
    t = np.trace(r)
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        return [(r[2, 1] - r[1, 2]) / s, (r[0, 2] - r[2, 0]) / s, (r[1, 0] - r[0, 1]) / s, 0.25 * s]
    i = int(np.argmax([r[0, 0], r[1, 1], r[2, 2]]))
    if i == 0:
        s = math.sqrt(1.0 + r[0, 0] - r[1, 1] - r[2, 2]) * 2
        return [0.25 * s, (r[0, 1] + r[1, 0]) / s, (r[0, 2] + r[2, 0]) / s, (r[2, 1] - r[1, 2]) / s]
    if i == 1:
        s = math.sqrt(1.0 + r[1, 1] - r[0, 0] - r[2, 2]) * 2
        return [(r[0, 1] + r[1, 0]) / s, 0.25 * s, (r[1, 2] + r[2, 1]) / s, (r[0, 2] - r[2, 0]) / s]
    s = math.sqrt(1.0 + r[2, 2] - r[0, 0] - r[1, 1]) * 2
    return [(r[0, 2] + r[2, 0]) / s, (r[1, 2] + r[2, 1]) / s, 0.25 * s, (r[1, 0] - r[0, 1]) / s]


def xf(q, o):
    m = np.eye(4)
    m[:3, :3] = q2m(q)
    m[:3, 3] = o
    return m


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def frame(y_axis, z_hint):
    """Proper rotation with +Y along y_axis and +Z as close as possible to z_hint."""
    y = unit(y_axis)
    z = np.asarray(z_hint, float) - y * np.dot(z_hint, y)
    z = unit(z)
    x = np.cross(y, z)
    return np.column_stack([x, y, z])


def frame_z(z_axis, y_hint):
    """Proper rotation with +Z along z_axis and +Y as close as possible to y_hint."""
    z = unit(z_axis)
    y = np.asarray(y_hint, float) - z * np.dot(y_hint, z)
    y = unit(y)
    x = np.cross(y, z)
    return np.column_stack([x, y, z])


MIRROR = np.diag([-1.0, 1.0, 1.0, 1.0])


def mirror(t):
    """Sagittal reflection of a pose (a proper rotation again: S R S)."""
    return MIRROR @ t @ MIRROR


def outward(o, centre=(0.0, 0.0)):
    return unit([o[0] - centre[0], 0.0, o[2] - centre[1]])


def angle_deg(o):
    """Body-fit convention: 0 front (+Z), 90 character right (-X), 180 back, 270 left."""
    return (math.degrees(math.atan2(-o[0], o[2])) + 360.0) % 360.0


def godot_text(t):
    r = t[:3, :3]
    o = t[:3, 3]
    vals = [r[0, 0], r[0, 1], r[0, 2], r[1, 0], r[1, 1], r[1, 2], r[2, 0], r[2, 1], r[2, 2], o[0], o[1], o[2]]
    return "Transform3D(" + ", ".join("%.6f" % v for v in vals) + ")"


def xf_json(t, rest, bone):
    loc = np.linalg.inv(rest[bone]) @ t
    q = m2q(loc[:3, :3])
    return {"bone": bone, "local": godot_text(loc), "q": [round(v, 6) for v in q],
            "o": [round(v, 5) for v in loc[:3, 3]], "bind": godot_text(t),
            "bind_o": [round(v, 4) for v in t[:3, 3]], "angle_deg": round(angle_deg(t[:3, 3]), 1)}


# --- survey inputs ----------------------------------------------------------------------------

def load(name):
    return json.load(open(os.path.join(DATA, name)))


def stow_model(h, point, stance, bone, rest, which="parked"):
    """Bind-space model transform of a handoff stow point (source parked pose, else in-hand)."""
    c = h["stow_points"]["points"][point]["stances"][stance][0]
    p = c.get(which) or c.get("in_hand")
    mi = p["model_in"][bone]
    return rest[bone] @ xf(mi["quat_xyzw"], mi["origin"]), c, p


def push(t, d, centre=(0.0, 0.0)):
    out = t.copy()
    out[:3, 3] = t[:3, 3] + outward(t[:3, 3], centre) * d
    return out


# --- capsules -----------------------------------------------------------------------------------

def cap(cid, item, kind, bone, a, b, r, group, grip_at=0.0, skip=None, nopair=False):
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    L = float(np.linalg.norm(b - a))
    return {"id": cid, "item": item, "kind": kind, "gear": group, "group": group, "bone": bone,
            "origin": [round(v, 4) for v in a], "axis": [round(v, 5) for v in (b - a) / L], "length": round(L, 4),
            "radius": r, "grip_at": grip_at, "skip_labels": skip if skip is not None else SKIP_OLD_HORN,
            "nopair": nopair}


def pistol_caps(cid, t, bone, group):
    o = t[:3, 3]
    r = t[:3, :3]
    muzzle = o + r @ np.array([0.0, 0.0, -PISTOL["muzzle"]])
    butt = o + r @ np.array([0.0, -PISTOL["butt_down"], PISTOL["butt_back"]])
    return [cap(cid + ":barrel", cid, "pistol", bone, o, muzzle, PISTOL["r_barrel"], group),
            cap(cid + ":stock", cid, "pistol", bone, o, butt, PISTOL["r_stock"], group)]


# --- placements this design derives -------------------------------------------------------------

def design_placements(rest, h, cs):
    """Every stow transform of the design, bind space. Returns {id: dict}."""
    P = {}

    # 1. First pistol, right hip: the source no-pack grab's parked pose (0.4 mm handover), pushed
    #    out of the coat. Stand and crouch transforms (the stowed pistol swings with the stance).
    t_st, c_st, p_st = stow_model(h, "pistol_right_hip", "stand", "pelvis", rest)
    t_cr, c_cr, p_cr = stow_model(h, "pistol_right_hip", "crouch", "pelvis", rest)
    P["R_hip.src_stand"] = {"t": t_st, "source": c_st["case"], "inside_m": p_st["outside_belt_ring_m"]}
    P["R_hip.src_crouch"] = {"t": t_cr, "source": c_cr["case"], "inside_m": p_cr["outside_belt_ring_m"]}
    # 2. Behind the right hip: the graph's default (backpack) pistol set, horizontal across the back.
    t_br, c_br, p_br = stow_model(h, "pistol_back_right", "stand", "pelvis", rest)
    P["back_right.src"] = {"t": t_br, "source": c_br["case"], "inside_m": p_br["outside_belt_ring_m"]}
    # 3. Left hip: the mirrored no-pack set (measured over the unmirrored base; left hand).
    t_lh, c_lh, p_lh = stow_model(h, "pistol_left_hip_mirrored", "stand", "pelvis", rest)
    P["L_hip.mirror"] = {"t": t_lh, "source": c_lh["case"], "inside_m": p_lh["outside_belt_ring_m"]}
    # 4. Chest: flashlight strap point (left hand, exact) and its mirror (right hand). The grip is
    #    the source's; the pistol hangs on the sling barrel down along the sling line (authored).
    for name, point in (("chest_L", "strap_left_chest"), ("chest_R", "strap_right_chest_mirrored")):
        t_f, c_f, p_f = stow_model(h, point, "stand", "spined", rest)
        o = t_f[:3, 3]
        side = 1.0 if o[0] > 0 else -1.0
        # sling from the right shoulder to the left hip: down-left on the chest (+X is left)
        barrel = unit([0.45, -0.89, 0.0])
        top = unit([-side * 0.3, 0.0, 1.0])     # top of the gun forward, lock toward the sling
        t = np.eye(4)
        t[:3, :3] = frame_z(-barrel, top)
        t[:3, 3] = o
        P[name + ".src"] = {"t": t, "source": c_f["case"], "inside_m": p_f["outside_belt_ring_m"]}
    return P


def belt_ring():
    """Outer belt surface radius per 15 deg (body-fit bind landmarks), as (angle, radius, y)."""
    b = load("body_fit.json")
    return [(r["angle"], r["outer_radius"], r["centre"]) for r in b["bind_landmarks"]["belt"]["ring"]]


def ring_point(ring, a_deg, standoff):
    """Point on the outer belt surface at angle a (body-fit convention) plus `standoff` outward."""
    pts = sorted(ring)
    a = a_deg % 360.0
    for i in range(len(pts)):
        a0, r0, c0 = pts[i]
        a1, r1, c1 = pts[(i + 1) % len(pts)]
        span = (a1 - a0) % 360.0 or 360.0
        if (a - a0) % 360.0 <= span:
            u = ((a - a0) % 360.0) / span
            p = np.array(c0) * (1 - u) + np.array(c1) * u
            n = outward(p)
            return p + n * standoff, n
    raise ValueError(a_deg)


def belt_pistol(ring, a_deg, y, standoff, back_deg=8.0, out_deg=5.0):
    """A pistol hung / tucked at the belt: grip on the belt at angle a, barrel down (tilted
    back_deg toward the back and out_deg outward), top of the gun toward the front, so the butt
    points to the rear. Rigid; used only for the round-2 comparison capsules."""
    p, n = ring_point(ring, a_deg, standoff + PISTOL["r_stock"] * 0.6)
    p[1] = y
    tang = unit(np.cross([0.0, 1.0, 0.0], n))
    fwd = tang if tang[2] > 0 else -tang            # the belt tangent pointing to the front
    b = unit(np.array([0.0, -1.0, 0.0]) - fwd * math.tan(math.radians(back_deg)) + n * math.tan(math.radians(out_deg)))
    t = np.eye(4)
    t[:3, :3] = frame_z(-b, fwd)    # model -Z = barrel, +Y (top) toward the front: butt to the rear
    t[:3, 3] = p
    return t


def body_fit_caps(cands, ids):
    return [c for c in cands["points"] if c["id"] in ids]


def build_candidates():
    rest = load_rest()
    h = load("handoffs.json")
    cs = load("carry_points_survey.json")
    P = design_placements(rest, h, cs)
    caps = []
    for d in (0.0, 0.04, 0.06, 0.08):
        caps += pistol_caps("dz_R_hip_src_p%02d" % round(d * 100), push(P["R_hip.src_stand"]["t"], d), "pelvis", "design_belt")
    for d in (0.06,):
        caps += pistol_caps("dz_R_hip_crouchpose_p%02d" % round(d * 100), push(P["R_hip.src_crouch"]["t"], d), "pelvis",
                            "design_belt")
    for d in (0.06, 0.09):
        caps += pistol_caps("dz_L_hip_mirror_p%02d" % round(d * 100), push(P["L_hip.mirror"]["t"], d), "pelvis", "design_belt")
    for d in (0.02, 0.04):
        caps += pistol_caps("dz_back_right_src_p%02d" % round(d * 100), push(P["back_right.src"]["t"], d), "pelvis",
                            "design_belt")
    for name in ("chest_L", "chest_R"):
        for d in (0.03,):
            caps += pistol_caps("dz_%s_p%02d" % (name, round(d * 100)), push(P[name + ".src"]["t"], d, (0.0, 0.005)), "spined",
                                "design_chest")
    # round 2: authored belt pistols built on the ring (grip = outer belt surface + standoff)
    ring = belt_ring()
    for d in (0.02, 0.04):
        caps += pistol_caps("dz2_L_hip_tuck_p%02d" % round(d * 100), belt_pistol(ring, 280.0, 0.920, d, back_deg=8.0), "pelvis",
                            "design_belt")
    caps += pistol_caps("dz2_R_hip_115_p02", belt_pistol(ring, 115.0, 0.914, 0.02, back_deg=8.0), "pelvis", "design_belt")
    t = push(P["back_right.src"]["t"], 0.04)
    t[1, 3] -= 0.07
    caps += pistol_caps("dz2_back_right_belt_p04", t, "pelvis", "design_belt")
    # quiver lowered 10 cm (the source reach starts at the right shoulder blade, 1.20 m)
    q = next(c for c in load_cands()["points"] if c["id"] == "quiver_R")
    o = np.array(q["origin"]) + np.array([0.0, -0.10, 0.0])
    caps.append(cap("dz_quiver_low", "dz_quiver_low", "quiver", "spineb", o, o + np.array(q["axis"]) * q["length"], 0.05,
                    "design_back"))
    # second tomahawk stacked 3.5 cm outside the body-fit back tomahawk
    for c in body_fit_caps(load_cands(), ["tomahawk_185_edgeL:haft", "tomahawk_185_edgeL:head"]):
        o = np.array(c["origin"]) + outward(c["origin"]) * 0.035
        caps.append(cap(c["id"].replace("tomahawk_185_edgeL", "dz_tomahawk2_outer"), "dz_tomahawk2_outer", "tomahawk", c["bone"],
                        o, o + np.array(c["axis"]) * c["length"], c["radius"], "design_belt", c.get("grip_at", 0.0)))
    # the body-fit survey's recommended items, for the pair gaps (and as a same-run reference)
    ref = ["pistol_hook_R125~s2:barrel", "pistol_hook_R125:stock", "tomahawk_185_edgeL~s2:haft", "tomahawk_185_edgeL:head",
           "atlatl_200_lean20~s2", "knife_L230~s2", "horn_backR_top2:base", "horn_backR_top2:spout", "musket_L_up_spineb",
           "bow_R", "spears_R", "darts_L", "quiver_R"]
    for c in body_fit_caps(load_cands(), ref):
        c = dict(c)
        c["group"] = "ref"
        caps.append(c)
    out = {"note": "Generated by tools/loadout/build_loadout_data.py candidates: design placements derived from the source "
                   "clips (dz_*) plus the body-fit survey's recommended items (group ref). Rig space at null-add.",
           "provenance": PROVENANCE, "points": caps}
    json.dump(out, open(CAND_OUT, "w"), indent=1)
    print("DESIGN CANDIDATES OK: %d capsules -> %s" % (len(caps), CAND_OUT))
    for k, v in P.items():
        o = v["t"][:3, 3]
        print("  %-18s angle %6.1f  y %.3f  inside_ring %+.3f  %s" % (k, angle_deg(o), o[1], v["inside_m"], v["source"]))


def load_cands():
    return json.load(open(os.path.join(ROOT, "tools", "loadout", "candidates.json")))


# --- final placements (the slot map) ---------------------------------------------------------------

def _survey_caps(cs, pid):
    return cs["placements"][pid]["capsules"]


def _cap_pts(c):
    return np.array(c["from"], float), np.array(c["to"], float)


def pistol_from_caps(grip, barrel_dir, butt_dir):
    """Pistol model transform from a grip point, the barrel direction and the grip->butt direction."""
    z = -unit(barrel_dir)
    bd = unit(butt_dir)
    # butt = +Z * 0.081 - Y * 0.089  ->  Y ~ (0.6731 Z - butt_dir) / 0.7396
    k = math.hypot(PISTOL["butt_back"], PISTOL["butt_down"])
    y = (PISTOL["butt_back"] / k) * z - bd
    t = np.eye(4)
    t[:3, :3] = frame_z(z, y)
    t[:3, 3] = grip
    return t


def pistol_caps_final(cid, t, bone, group, two_anchor):
    caps = pistol_caps(cid, t, bone, group)
    if two_anchor:
        caps[0]["bone"] = "skin2"
        caps[0]["anchors"] = [0.08, 0.7]
    return caps


def roll_to_match(t, s):
    """t rolled about its own barrel axis (model Z) to the roll closest to the source pose s."""
    z = t[:3, 2]
    kx = np.array([[0, -z[2], z[1]], [z[2], 0, -z[0]], [-z[1], z[0], 0]])
    best = None
    for deg in range(0, 360, 1):
        a = math.radians(deg)
        r = (np.eye(3) + math.sin(a) * kx + (1 - math.cos(a)) * kx @ kx) @ t[:3, :3]
        m = np.eye(4)
        m[:3, :3] = r
        m[:3, 3] = t[:3, 3]
        ang = _rot_deg(s, m)
        if best is None or ang < best[0]:
            best = (ang, m)
    return best[1]


def final_placements(rest, h, cs):
    """The design's stowed transform per (point, kind): bind-space model transform, the carrying
    bone, the attach mode and the capsules used for the fit check."""
    F = {}
    ring = belt_ring()

    def add(key, point, kind, bone, attach, t, caps, note, basis="authored"):
        F[key] = {"point": point, "kind": kind, "bone": bone, "attach": attach, "t": t, "caps": caps, "note": note,
                  "basis": basis}

    # R_hip pistol (first pistol, user rule): the body-fit two-anchor placement at 125 deg.
    c = _survey_caps(cs, "belt.R_hip.pistol")
    grip = np.array(cs["placements"]["belt.R_hip.pistol"]["grip_bind"])
    bar = [v for k, v in c.items() if k.endswith("barrel")][0]
    stk = [v for k, v in c.items() if k.endswith("stock")][0]
    t = pistol_from_caps(grip, np.subtract(bar["to"], bar["from"]), np.subtract(stk["to"], stk["from"]))
    add("R_hip.pistol", "R_hip", "pistol", "pelvis", "two_anchor", t,
        pistol_caps_final("fin_R_hip_pistol", t, "pelvis", "final", True),
        "Hooked on the belt behind the right side seam (body-fit 125 deg), barrel down the hip, lock out, butt along the belt "
        "to the rear. While the hand reaches for it (grab clip) it pivots on its hook to grab_pose.",
        "body-fit belt.R_hip.pistol (the source no-pack grab spot at 71 deg is swept by the thigh and forearm)")
    # Variant: the same barrel line, rolled about the barrel so the gun matches the source grab
    # orientation as closely as the barrel line allows (the handover turn drops from ~103 to ~36 deg).
    tr = roll_to_match(t, stow_model(h, "pistol_right_hip", "stand", "pelvis", rest)[0])
    F["R_hip.pistol"]["grab_pose"] = tr
    F["R_hip.pistol"]["grab_caps"] = pistol_caps_final("fin_R_hip_pistol_rolled", tr, "pelvis", "grab_pose", True)
    # L_hip pistol: tucked through the belt at 280 deg (the mirrored source grab lands here), butt back.
    lg = np.array(cs["placements"]["belt.L_hip.pistol"]["grip_bind"])
    t = belt_pistol(ring, 280.0, lg[1], 0.0, back_deg=8.0, out_deg=5.0)
    t[:3, 3] = lg
    add("L_hip.pistol", "L_hip", "pistol", "pelvis", "two_anchor", t, pistol_caps_final("fin_L_hip_pistol", t, "pelvis", "final", True),
        "Thrust through the belt at the left hip (280 deg), barrel down, butt back: the mirror of the right-hand carry for a "
        "left-hand draw.", "grip at the mirrored no-pack grab angle; orientation authored (butt back)")
    # back_right pistol (sash only): the graph's default pistol stow, lowered into the sash band.
    t, _, _ = stow_model(h, "pistol_back_right", "stand", "pelvis", rest)
    t = push(t, 0.04)
    t[1, 3] -= 0.07
    add("back_right.pistol", "back_right", "pistol", "pelvis", "rigid", t, pistol_caps_final("fin_back_right_pistol", t, "pelvis", "final", False),
        "Pushed horizontally through the sash behind the right hip, muzzle to the left.",
        "source default (backpack-on) pistol stow, 7 cm lower and 4 cm out")
    # chest pistols on the pistol sling (body-fit placements, rigid spined).
    for side, pid in (("chest_L", "pistol_sling.chest_L"), ("chest_R", "pistol_sling.chest_R")):
        c = _survey_caps(cs, pid)
        bar = [v for k, v in c.items() if k.endswith("barrel")][0]
        stk = [v for k, v in c.items() if k.endswith("stock")][0]
        t = pistol_from_caps(np.array(bar["from"]), np.subtract(bar["to"], bar["from"]), np.subtract(stk["to"], stk["from"]))
        add(side + ".pistol", side, "pistol", "spined", "rigid", t, pistol_caps_final("fin_%s_pistol" % side, t, "spined", "final", False),
            "Hung on the pistol sling across the chest, barrel down-left along the sling, butt up-right.", "body-fit " + pid)
    # back tomahawks: inner (body-fit two-anchor) and the stacked outer one.
    c = _survey_caps(cs, "belt.back.tomahawk")
    haft = [v for k, v in c.items() if k.endswith("haft")][0]
    head = [v for k, v in c.items() if k.endswith("head")][0]
    top, bot = _cap_pts(haft)
    up = unit(top - bot)
    grip = bot + up * TOMAHAWK["butt_y"]
    edge = np.subtract(head["to"], head["from"])
    t = np.eye(4)
    t[:3, :3] = frame(up, -np.asarray(edge, float))    # -Z = cutting edge
    t[:3, 3] = grip
    tcaps = [cap("fin_back_tomahawk:haft", "fin_back_tomahawk", "tomahawk", "skin2", top, bot, TOMAHAWK["r_haft"], "final"),
             cap("fin_back_tomahawk:head", "fin_back_tomahawk", "tomahawk", "pelvis", head["from"], head["to"], TOMAHAWK["r_head"], "final")]
    tcaps[0]["anchors"] = [0.08, 0.7]
    add("back.tomahawk", "back", "tomahawk", "pelvis", "two_anchor", t, tcaps,
        "Through the belt just left of the spine, head on the belt, edge to the left.", "body-fit belt.back.tomahawk")
    off = outward(grip) * 0.045 + np.array([0.0, 0.04, 0.0])
    t2 = t.copy()
    t2[:3, 3] += off
    t2caps = [cap("fin_back_tomahawk2:haft", "fin_back_tomahawk2", "tomahawk", "skin2", top + off, bot + off, TOMAHAWK["r_haft"], "final"),
              cap("fin_back_tomahawk2:head", "fin_back_tomahawk2", "tomahawk", "pelvis", np.add(head["from"], off), np.add(head["to"], off),
                  TOMAHAWK["r_head"], "final")]
    t2caps[0]["anchors"] = [0.08, 0.7]
    add("back_2.tomahawk", "back_2", "tomahawk", "pelvis", "two_anchor", t2, t2caps,
        "The second tomahawk of the pair, stacked on the first: 4.5 cm further out and its head 4 cm higher.", "authored")
    # atlatl board at the back (instead of the tomahawks).
    c = _survey_caps(cs, "belt.back.atlatl")
    board = list(c.values())[0]
    a, b = _cap_pts(board)
    t = np.eye(4)
    t[:3, :3] = frame_z(b - a, outward(a))
    t[:3, 3] = a
    acaps = [cap("fin_back_atlatl", "fin_back_atlatl", "atlatl", "skin2", a, b, ATLATL["r"], "final")]
    acaps[0]["anchors"] = [0.08, 0.7]
    add("back.atlatl", "back", "atlatl", "pelvis", "two_anchor", t, acaps,
        "Board through the belt just left of the spine, hook end down and to the left.", "body-fit belt.back.atlatl")
    # knife (model later): sheath capsule only.
    for pid, key, point in (("belt.back_left.knife", "back_left.knife", "back_left"), ("belt.L_hip.knife", "L_hip.knife", "L_hip"),
                            ("belt.L_hip.saber", "L_hip.saber", "L_hip")):
        caps = []
        for k, v in _survey_caps(cs, pid).items():
            cc = cap("fin_%s:%s" % (key.replace(".", "_"), k.split(":")[-1]), "fin_" + key.replace(".", "_"), key.split(".")[1],
                     "skin2" if v["bone"] == "skin2" else "pelvis", v["from"], v["to"], v["radius"], "final")
            if v["bone"] == "skin2":
                cc["anchors"] = v.get("anchors") or [0.08, 0.7]
            caps.append(cc)
        add(key, point, key.split(".")[1], "pelvis", "two_anchor", None, caps, cs["placements"][pid]["note"], "body-fit " + pid)
    # back slings (rigid spineb).
    for pid, key in (("back.long_A.musket", "long_A.musket"), ("back.long_B.musket", "long_B.musket"),
                     ("back.long_A.spears", "long_A.spear_pair"), ("back.long_B.spears", "long_B.spear_pair"),
                     ("back.long_A.darts", "long_A.dart_bundle"), ("back.long_B.darts", "long_B.dart_bundle"),
                     ("back.long_A.bow", "long_A.bow"), ("back.long_B.bow", "long_B.bow"), ("back.quiver", "quiver.quiver")):
        c = list(_survey_caps(cs, pid).values())[0]
        a, b = _cap_pts(c)
        ax = unit(b - a)
        n = outward((a + b) * 0.5)
        kind = key.split(".")[1]
        t = np.eye(4)
        if kind == "musket":        # a = butt, b = muzzle; -Z = muzzle, top (+Y) outward
            t[:3, :3] = frame_z(-ax, n)
            t[:3, 3] = a + ax * MUSKET["butt"]
        elif kind == "spear_pair":  # a = butt, b = points; -Z = point
            t[:3, :3] = frame_z(-ax, n)
            t[:3, 3] = a + ax * SPEAR["butt"]
        elif kind == "dart_bundle":  # a = tips, b = nocks; +Z = toward the nock, origin = tip
            t[:3, :3] = frame_z(ax, n)
            t[:3, 3] = a
        elif kind == "bow":         # a = lower tip, b = upper tip; +Y = upper limb, string (+Z) toward the body
            t[:3, :3] = frame(ax, -n)
            t[:3, 3] = (a + b) * 0.5
        else:                       # quiver: origin at the mouth (b), +Y out of the mouth, +Z outward
            t[:3, :3] = frame(ax, n)
            t[:3, 3] = b
        cc = cap("fin_" + key.replace(".", "_"), "fin_" + key.replace(".", "_"), kind, "spineb", a, b, c["radius"], "final")
        add(key, key.split(".")[0], kind, "spineb", "rigid", t, [cc], cs["placements"][pid]["note"], "body-fit " + pid)
    # powder horn (body gear; the customizer owns the mesh): reference only.
    caps = []
    for k, v in _survey_caps(cs, "horn.back_R_top").items():
        caps.append(cap("fin_horn:%s" % k.split(":")[-1], "fin_horn", "horn", "spinec", v["from"], v["to"], v["radius"], "final"))
    add("horn.powder_horn", "horn", "powder_horn", "spinec", "rigid", None, caps, cs["placements"]["horn.back_R_top"]["note"],
        "body-fit horn.back_R_top (change request, customizer)")
    return F


def build_candidates_final():
    rest = load_rest()
    h = load("handoffs.json")
    cs = load("carry_points_survey.json")
    F = final_placements(rest, h, cs)
    d = json.load(open(CAND_OUT))
    pts = [p for p in d["points"] if p.get("group") not in ("final", "grab_pose")]
    finals = []
    for v in F.values():
        for c in v["caps"]:
            c = dict(c)
            c["dump"] = True        # the ride / prone / camera checks read the posed endpoints
            finals.append(c)
    # rigid survey-era references stay out of the extra clip sets (only the play and traversal clips)
    for p in pts:
        p.setdefault("cats", R.BASE_CATS + R.TRAV_CATS)
    pts += finals
    pts += R.revision_candidates(cs, finals)
    d["points"] = pts
    d["note"] = ("Generated by tools/loadout/build_loadout_data.py candidates: design placements derived from the source "
                 "clips (dz_*, dz2_*), revision-2 candidates (dz3_*, mirrors mir:*, traversal policies push*/swing*; "
                 "tools/loadout/loadout_revision.py), the body-fit survey's recommended items (group ref) and the design's "
                 "final placements (group final). Rig space at null-add. 'cats' limits a capsule to those clip categories.")
    json.dump(d, open(CAND_OUT, "w"), indent=1)
    from collections import Counter
    print("FINAL CANDIDATES OK: %d capsules (%d final placements) %s" % (len(pts), len(F), dict(Counter(p["group"] for p in pts))))


# --- loadout rules: gear, items, presets ---------------------------------------------------------------

# Carry points each gear provides, and the kinds allowed there. Points not listed by any worn gear do
# not exist. "blocks": points the gear physically occupies. "exclusive": point pairs that cannot both hold
# an item. Evidence grades: A documented for the region and period, B nearby / later / general practice,
# C game licence (costume bible convention; loadout body_fit_history.md section 4).
GEAR = {
    "legacy_baked_belt": {
        "slot": "waist", "customizer_ids": [], "legacy": True,
        "note": "The leather waist belt baked into assets/character/actor_b_body.glb (Gear). Default waist gear.",
        "points": {"R_hip": ["pistol"], "L_hip": ["pistol", "saber", "knife"], "back": ["tomahawk", "atlatl", "knife"],
                   "back_2": ["tomahawk"], "back_left": ["knife"]},
        "exclusive": [["back_2", "quiver"], ["back_2", "back_right"]], "requires": {"back_2": "back holds a tomahawk"},
        "evidence": "A (belt, Doddridge [P3]); B (R_hip: a pistol hooked in a waist belt by a belt hook on the left side of the "
                    "stock, sea-service practice [W2][W3]); C (L_hip: see the point's own grade)"},
    "belt_tied_behind": {
        "slot": "waist", "customizer_ids": ["belt_tied_behind"],
        "note": "Knot and short ends at the back (175-185 deg): the back item sits at 200 deg and back_left holds nothing; the knife "
                "goes on the shot-pouch strap.",
        "points": {"R_hip": ["pistol"], "L_hip": ["pistol", "saber", "knife"], "back": ["tomahawk", "atlatl"],
                   "back_2": ["tomahawk"]},
        "exclusive": [["back_2", "quiver"]], "requires": {"back_2": "back holds a tomahawk"},
        "point_variants": {"back": "belt.back_left.tomahawk / belt.back.atlatl geometry (200 deg)"},
        "evidence": "A [P3]"},
    "sash_fingerwoven": {
        "slot": "waist", "customizer_ids": ["sash_fingerwoven"],
        "note": "Wide band (y 0.90-1.06) tied at the left hip: the knot blocks L_hip; a second pistol goes horizontally through the "
                "sash behind the right hip (the graph's default pistol stow), which takes the back point.",
        "points": {"R_hip": ["pistol"], "back_right": ["pistol"], "back": ["tomahawk", "atlatl", "knife"], "back_2": ["tomahawk"]},
        "exclusive": [["back_right", "back"], ["back_right", "back_2"], ["back_2", "quiver"]], "blocks": ["L_hip"],
        "requires": {"back_2": "back holds a tomahawk"},
        "evidence": "A (sash) [M7c]; C (back_right: a pistol pushed horizontally through the sash behind the hip is a modern-looking "
                    "carry; the period front tuck was measured and rejected, thighs -9 to -11 cm, design_fit_check.json "
                    "revision.sash_front)"},
    "ew_sash": {
        "slot": "waist or shoulder", "customizer_ids": ["ew_sash"],
        "as_waist": "sash_fingerwoven",
        "as_shoulder": {"points": {"L_hip": ["pistol", "tomahawk", "knife"]},
                        "note": "Worn as a baldric over the right shoulder: its hanging end at the left hip carries one item. Adds "
                                "L_hip only when the waist gear lacks it (a sash)."},
        "evidence": "A/B (costume bible 3.8)"},
    "military_waist_belt": {
        "slot": "waist", "customizer_ids": ["fr_belt_gargoussier"],
        "note": "Buff waist belt with the cartridge pouch at the front (330-30 deg): no front items.",
        "points": {"R_hip": ["pistol"], "back": ["tomahawk"], "L_hip": ["saber", "pistol"]},
        "blocks": ["front"], "evidence": "A [M4]; 1758 tomahawks for regulars (Huck via [M1])"},
    "br_belts_cartridge": {
        "slot": "shoulder and waist", "customizer_ids": ["br_belts_cartridge"],
        "note": "Cartridge box on the shoulder belt behind the right hip blocks R_hip; a pistol can hook on the shoulder belt at the "
                "right chest.",
        "points": {"L_hip": ["saber", "pistol"], "chest_R": ["pistol"]}, "blocks": ["R_hip", "back_right"],
        "evidence": "A (belts, bible 5.6); C (a pistol hooked on the shoulder belt: no source for regulars)"},
    "pistol_sling": {
        "slot": "shoulder", "customizer_ids": ["pistol_sling"], "new_item": True,
        "note": "New gear built by the loadout workflow: a leather or silk sling over the right shoulder to the left hip with two "
                "pistol hooks / small holsters on the chest.",
        "points": {"chest_R": ["pistol"], "chest_L": ["pistol"]},
        "evidence": "B for one pistol hung by its belt hook from a thin shoulder belt at the left side (Highland soldiers of the "
                    "42nd in the French and Indian War wore one steel pistol under the left arm on a thin buff belt [W1]); C for "
                    "the second pistol (a sling with three brace of pistols in holsters: Blackbeard, 1718, Johnson 1724 [W4])"},
    "horn_strap": {
        "slot": "shoulder", "customizer_ids": ["powder_horn"], "points": {}, "body_items": ["powder_horn"],
        "note": "Horn behind and below the right arm on a strap over the left shoulder (Knox 1757); customizer-owned mesh.",
        "evidence": "A (Knox 1757 via [M2])"},
    "shot_pouch_strap": {
        "slot": "shoulder", "customizer_ids": ["shot_pouch", "ew_shot_pouch"], "points": {"pouch_strap": ["knife"]},
        "note": "Pouch at the left hip on a strap over the right shoulder; a sheath knife may ride on it.", "evidence": "A [M2]"},
    "back_slings": {
        "slot": "always", "customizer_ids": [], "always": True,
        "note": "The long weapons bring their own slings (musket sling, bow string across the chest, a thong for the spear pair or "
                "the dart bundle, the quiver strap).",
        "points": {"long_A": ["musket", "over_under", "spear_pair", "dart_bundle"],
                   "long_B": ["bow", "spear_pair", "dart_bundle", "musket", "over_under"], "quiver": ["quiver"]},
        "evidence": "B (slung muskets, bows and quivers on the back)"},
    "back_load": {
        "slot": "shoulder", "customizer_ids": ["tumpline_blanket_roll", "knapsack", "ew_tumpline"], "points": {},
        "blocks": ["long_B", "quiver"],
        "note": "A load on the back takes the upper right back: long_B and the quiver (the quiver would sit inside the pack). With "
                "a back load the bow cannot be carried slung (it needs long_B and the quiver).", "evidence": "A (tumplines)"},
}

PISTOL_POINT_ORDER = ["R_hip", "back_right", "chest_R", "L_hip", "chest_L"]   # fastest draw first

ITEMS = {
    "format": "frontier-loadout-items", "version": 1, "provenance": PROVENANCE,
    "classes": {
        "long": "longer than about 1.2 m: cannot hang from the waist band (0.94 m) on a 1.60 m body; slung across the back in "
                "long_A or long_B, at most two at once",
        "belt": "carried at a belt / sash / sling carry point provided by the worn gear",
        "companion": "travels with another item and takes no slot of its own",
        "body_gear": "part of the outfit (customizer); not a weapon",
    },
    "kinds": {
        "musket": {"class": "long", "family": "long_gun", "weapon_class": "Musket", "anim_profile": "musket", "length_m": 1.588,
                   "slots": ["long_A", "long_B"], "key": "weapon_2", "model": "WeaponModels.build('musket')"},
        "over_under": {"class": "long", "family": "long_gun", "weapon_class": "OverUnderMusket (weapon-ranges workflow)",
                       "anim_profile": "musket", "length_m": 1.59, "slots": ["long_A", "long_B"], "key": "weapon_2",
                       "model": "its own model (other workflow)"},
        "bow": {"class": "long", "weapon_class": "Bow", "anim_profile": "bow", "length_m": 1.526, "slots": ["long_B"],
                "needs": ["quiver"], "key": "weapon_1",
                "model": "WeaponModels.build('bow'), slung with the string outward (String mesh kept, no string ribbon)",
                "slot_note": "long_B only: with the order long guns, bow, spear pair, dart bundle long_B is always free for the bow; "
                             "the quiver sits under it"},
        "spear_pair": {"class": "long", "weapon_class": "ThrowableSpear", "weapon_key": "spear", "anim_profile": "spear", "length_m": 1.80,
                       "count_max": 2, "slots": ["long_A", "long_B"], "key": "weapon_4", "model": "ThrowableModels.build('spear') x count"},
        "dart_bundle": {"class": "long", "ammo_for": "atlatl", "length_m": 1.65, "count_max": 5, "slots": ["long_B", "long_A"],
                        "needs": ["atlatl"], "model": "ThrowableModels.build('atlatl_dart') x count, tied at two points"},
        "atlatl": {"class": "belt", "weapon_class": "ThrowableAtlatl", "weapon_key": "atlatl", "anim_profile": "atlatl", "length_m": 0.588,
                   "points": ["back"], "needs": ["dart_bundle"], "key": "weapon_6", "gate": "relic found (legendary, anachronistic)",
                   "model": "ThrowableModels.build('atlatl')"},
        "tomahawk": {"class": "belt", "weapon_class": "ThrowableTomahawk", "weapon_key": "tomahawk", "anim_profile": "tomahawk",
                     "length_m": 0.494, "count_max": 2, "points": ["back", "back_2"], "key": "weapon_5",
                     "pair_rule": "the second tomahawk stacks on the first (back_2) unless a quiver is worn (they collide by 7.4 cm); "
                                  "then only one is carried (the pair needs the back free of a quiver)",
                     "model": "ThrowableModels.build('tomahawk' | 'tomahawk_pipe')"},
        "pistol": {"class": "belt", "weapon_class": "FlintlockPistol", "anim_profile": "pistol", "length_m": 0.391, "per_instance": True,
                   "points": PISTOL_POINT_ORDER, "draw_order": PISTOL_POINT_ORDER, "key": "weapon_3", "max": 4,
                   "model": "WeaponModels.build('pistol')"},
        "quiver": {"class": "companion", "of": "bow", "point": "quiver", "arrows_max": 24, "model": "new: assets/loadout/quiver (tools/loadout)"},
        "knife": {"class": "belt", "points": ["back_left", "pouch_strap", "L_hip", "back"], "later": True},
        "saber": {"class": "belt", "points": ["L_hip"], "later": True},
        "powder_horn": {"class": "body_gear", "owner": "customizer (powder_horn)", "point": "horn"},
    },
    "long_slot_rule": "assign long items in the order long guns, bow, spear pair, dart bundle; each takes its first free slot in "
                      "`slots`; at most two long items; the quiver comes with the bow and sits under long_B",
    "keys": {
        "bindings": {"weapon_1": "KEY_1", "weapon_2": "KEY_2", "weapon_3": "KEY_3", "weapon_4": "KEY_4", "weapon_5": "KEY_5",
                     "weapon_6": "KEY_6", "sling_all": "KEY_X", "weapon_next": "wheel down", "weapon_prev": "wheel up"},
        "categories": {"weapon_1": "bow", "weapon_2": "long gun", "weapon_3": "pistols", "weapon_4": "spears", "weapon_5": "tomahawks",
                       "weapon_6": "atlatl"},
        "rules": [
            {"input": "weapon_N", "state": "category N not carried", "result": "nothing (HUD: not carried)"},
            {"input": "weapon_N", "state": "another weapon in hand, or hands free",
             "result": "holster the weapon in hand, then draw category N (pistols: the next LOADED pistol in draw order; none "
                       "loaded: the one with the most reload progress)"},
            {"input": "weapon_1 / weapon_4 / weapon_5 / weapon_6", "state": "that weapon already in hand", "result": "nothing"},
            {"input": "weapon_2", "state": "a long gun in hand", "result": "switch to the other long gun if one is carried, else nothing"},
            {"input": "weapon_3", "state": "a LOADED pistol in hand", "result": "nothing (hold 0.4 s: pistol pick list, later)"},
            {"input": "weapon_3", "state": "an EMPTY pistol in hand (fired, reload not finished)",
             "result": "holster it at its home point and draw the next loaded pistol (draw order, cyclic after the one in hand); "
                       "if no other pistol is loaded: nothing (R reloads the one in hand)"},
            {"input": "sling_all (X)", "state": "a weapon in hand", "result": "hands free: holster, finish, HandsFree"},
            {"input": "sling_all (X)", "state": "hands free", "result": "nothing"},
            {"input": "weapon_next / weapon_prev", "state": "any",
             "result": "step through the carried categories in key order; the pistols are one entry (next loaded)"}],
        "note": "Only X puts the weapons away (no same-key toggle). Registered by scripts/loadout/loadout_input.gd "
                "(LoadoutInput.ensure(): weapon_4..6 and sling_all; weapon_1..3 stay in input_setup.gd)."},
}

PRESETS = {
    "format": "frontier-loadout-presets", "version": 2, "provenance": PROVENANCE, "default": "musket_bow",
    "note": "Chosen at camp / a chest later; for now data-driven presets. Items name the point they start at; counts are the "
            "carried number (in hand + on the body).",
    "presets": {
        "musket_bow": {"name": "Frontier hunter: musket and bow", "grade": "C",
                       "note": "Keeps today's three weapons (bow, musket, pistol). A gun and a bow together is game licence for a "
                               "1750s hunter; rangers did not carry bows. The realistic reference kit is ranger_1758.",
                       "gear": ["legacy_baked_belt", "horn_strap", "shot_pouch_strap", "back_slings"],
                       "items": {"long_A": "musket", "long_B": "bow", "quiver": {"kind": "quiver", "arrows": 24},
                                 "R_hip": "pistol", "back": "tomahawk"},
                       "in_hand": "musket"},
        "ranger_1758": {"name": "Ranger (1758): musket, pistol, tomahawk", "grade": "B",
                        "note": "Firelock, horn and pouch, a belt pistol and a tomahawk; tomahawks were carried by the 1758 army [M1]. "
                                "The bow is not in this kit.",
                        "gear": ["legacy_baked_belt", "horn_strap", "shot_pouch_strap", "back_slings"],
                        "items": {"long_A": "musket", "R_hip": "pistol", "back": "tomahawk"}, "in_hand": "musket"},
        "musket_spears": {"name": "Musket and spears", "gear": ["legacy_baked_belt", "horn_strap", "shot_pouch_strap", "back_slings"],
                          "items": {"long_A": "musket", "long_B": {"kind": "spear_pair", "count": 2}, "R_hip": "pistol",
                                    "back": "tomahawk", "back_2": "tomahawk"}, "in_hand": "musket"},
        "bow_darts": {"name": "Bow and atlatl darts", "gear": ["belt_tied_behind", "shot_pouch_strap", "back_slings"],
                      "items": {"long_B": "bow", "quiver": {"kind": "quiver", "arrows": 24}, "long_A": {"kind": "dart_bundle", "count": 5},
                                "back": "atlatl", "R_hip": "pistol"}, "in_hand": "bow"},
        "brace_of_pistols": {"name": "Brace of pistols (belt)", "gear": ["legacy_baked_belt", "horn_strap", "shot_pouch_strap", "back_slings"],
                             "items": {"long_A": "musket", "R_hip": "pistol", "L_hip": "pistol", "back": "tomahawk"},
                             "in_hand": "pistol@R_hip"},
        "two_braces": {"name": "Two braces (belt and pistol sling)",
                       "gear": ["legacy_baked_belt", "pistol_sling", "horn_strap", "shot_pouch_strap", "back_slings"],
                       "items": {"long_A": "musket", "R_hip": "pistol", "L_hip": "pistol", "chest_R": "pistol", "chest_L": "pistol"},
                       "in_hand": "pistol@R_hip"},
        "sash_brace": {"name": "Sash brace", "gear": ["sash_fingerwoven", "horn_strap", "shot_pouch_strap", "back_slings"],
                       "items": {"long_A": "musket", "long_B": "bow", "quiver": {"kind": "quiver", "arrows": 24},
                                 "R_hip": "pistol", "back_right": "pistol"}, "in_hand": "musket"},
        "woodland_hunter": {"name": "Woodland hunter: bow, spears, tomahawks", "gear": ["belt_tied_behind", "shot_pouch_strap", "back_slings"],
                            "items": {"long_B": "bow", "quiver": {"kind": "quiver", "arrows": 24}, "long_A": {"kind": "spear_pair", "count": 2},
                                      "back": "tomahawk"}, "in_hand": "bow"},
    },
}


def gear_points(gear_ids, shoulder_ew_sash=False):
    """Carry points (point -> allowed kinds) of a set of worn gear, after blocks."""
    pts = {}
    blocked = set()
    excl = []
    for g in gear_ids:
        d = GEAR[g]
        if "as_waist" in d:
            d = GEAR[d["as_waist"]] if not shoulder_ew_sash else {"points": d["as_shoulder"]["points"]}
        for p, kinds in d.get("points", {}).items():
            pts.setdefault(p, [])
            pts[p] = sorted(set(pts[p]) | set(kinds))
        blocked |= set(d.get("blocks", []))
        excl += d.get("exclusive", [])
    for b in blocked:
        pts.pop(b, None)
    return pts, excl


def pistol_capacity(gear_ids, shoulder_ew_sash=False):
    pts, excl = gear_points(gear_ids, shoulder_ew_sash)
    n = len([p for p in pts if "pistol" in pts[p]])
    return min(n, 4), sorted([p for p in pts if "pistol" in pts[p]], key=PISTOL_POINT_ORDER.index)


def _kind_of(v):
    return v if isinstance(v, str) else v["kind"]


def effective_pistol_capacity(gear_ids, items=None, shoulder_ew_sash=False):
    """Pistol points still usable for a pistol once the other carried items take their points: a point held by
    a non-pistol item, or exclusive with a point that holds anything, is lost. Capped at pistol_cap (4). This
    is the number the HUD and LoadoutRules.can_carry use; pistol_capacity() is the gear's maximum."""
    pts, excl = gear_points(gear_ids, shoulder_ew_sash)
    items = {p: _kind_of(v).split("@")[0] for p, v in (items or {}).items()}
    free = []
    for p in PISTOL_POINT_ORDER:
        if p not in pts or "pistol" not in pts[p]:
            continue
        if p in items and items[p] != "pistol":
            continue
        if any((a == p and b in items) or (b == p and a in items) for a, b in excl):
            continue
        free.append(p)
    return min(len(free), 4), free


def validate(carry, items, presets):
    errors = []
    kinds = items["kinds"]
    for pid, pr in presets["presets"].items():
        pts, excl = gear_points(pr["gear"])
        used = pr["items"]
        longs = [p for p in used if p in ("long_A", "long_B")]
        if len(longs) > 2:
            errors.append("%s: more than two long weapons" % pid)
        for p, v in used.items():
            k = _kind_of(v).split("@")[0]
            if p not in pts:
                errors.append("%s: point %s not provided by %s" % (pid, p, pr["gear"]))
            elif k not in pts[p]:
                errors.append("%s: %s not allowed at %s" % (pid, k, p))
            if isinstance(v, dict) and "count" in v and v["count"] > kinds[k].get("count_max", 1):
                errors.append("%s: too many %s" % (pid, k))
            for need in kinds[k].get("needs", []):
                if not any(_kind_of(x) == need for x in used.values()):
                    errors.append("%s: %s needs %s" % (pid, k, need))
        for a, b in excl:
            if a in used and b in used:
                errors.append("%s: %s and %s exclude each other" % (pid, a, b))
        cap, _ = pistol_capacity(pr["gear"])
        np_ = len([v for v in used.values() if _kind_of(v) == "pistol"])
        if np_ > cap:
            errors.append("%s: %d pistols > capacity %d" % (pid, np_, cap))
    if presets["default"] not in presets["presets"]:
        errors.append("default preset missing")
    for key, e in carry["points"].items():
        if "stow" in e:
            q = e["stow"]["q"]
            if abs(sum(x * x for x in q) - 1.0) > 1e-4:
                errors.append("%s: stow quaternion not unit" % key)
    return errors


# --- step 2: data files -----------------------------------------------------------------------------

GROUPS = {"locomotion": ["idle", "walk", "run", "sprint"], "crouch": ["crouch"],
          "weapon_use": ["aim", "throw", "carry", "reload"],
          "traversal": ["jump", "land", "vault", "climb", "ladder", "ledge"]}
EXPECTED_REACH = {"quiver": ["actor_b-p-bow-reload--part"], "dart_bundle": ["actor_b-p-bow-reload--part"],
                  "spear_pair": ["actor_b-p-bow-reload--part"], "bow": ["actor_b-p-bow-reload--part"],
                  "musket": ["actor_b-p-bow-reload--part"]}


def fit_checks(raw, caps, kind):
    clip_cat = {k: v["category"] for k, v in raw["clips"].items()}
    C = {c["id"]: c for c in raw["candidates"]}
    skip = set(EXPECTED_REACH.get(kind, []))
    wc = {}
    for cid in caps:
        for clip, v in C[cid]["by_clip"].items():
            w = wc.setdefault(clip, [9.0, "", 9.0])
            if clip not in skip and v[0] < w[0]:
                w[0], w[1] = v[0], v[1]
            w[2] = min(w[2], v[2])
    out = {}
    for g, cats in GROUPS.items():
        s = l = None
        for clip, w in wc.items():
            if clip_cat.get(clip) not in cats:
                continue
            if s is None or w[2] < s[0]:
                s = [w[2], clip]
            if w[0] < 9.0 and (l is None or w[0] < l[0]):
                l = [w[0], w[1], clip]
        out[g] = {"surface_cm": round(s[0] * 100, 1), "surface_clip": s[1],
                  "limb_cm": round(l[0] * 100, 1) if l else None, "limb": l[1] if l else None, "limb_clip": l[2] if l else None}
    worst = min(min(out[g]["surface_cm"], out[g]["limb_cm"] if out[g]["limb_cm"] is not None else 99) for g in
                ("locomotion", "crouch", "weapon_use"))
    verdict = "clean" if worst >= -1.0 else ("contact" if worst >= -3.5 else "clips")
    ranked = sorted(wc.items(), key=lambda kv: min(kv[1][0], kv[1][2]))[:4]
    worst_clips = [{"clip": k, "category": clip_cat.get(k), "limb_cm": round(v[0] * 100, 1) if v[0] < 9 else None,
                    "limb": v[1] or None, "surface_cm": round(v[2] * 100, 1)} for k, v in ranked]
    return {"groups": out, "verdict": verdict, "worst_play_cm": round(worst, 1), "worst_clips": worst_clips,
            "expected_reach_clips_excluded": sorted(skip)}


def pair_gaps(raw, F):
    C = {c["id"]: c for c in raw["candidates"]}
    item_of = {}
    for key, v in F.items():
        for c in v["caps"]:
            item_of[c["id"]] = key
    gaps = {}
    for cid, c in C.items():
        if cid not in item_of:
            continue
        for o, v in c.get("pairs", {}).items():
            if o not in item_of or item_of[o] == item_of[cid]:
                continue
            a, b = sorted([item_of[cid], item_of[o]])
            for g, val in v.items():
                k = "%s | %s" % (a, b)
                e = gaps.setdefault(k, {})
                if g not in e or val[0] < e[g][0]:
                    e[g] = [val[0], val[1]]
    out = {}
    for k, e in sorted(gaps.items()):
        out[k] = {g: {"gap_cm": round(v[0] * 100, 1), "clip": v[1]} for g, v in e.items()}
    return out


def _rot_deg(a, b):
    r = a[:3, :3].T @ b[:3, :3]
    return math.degrees(math.acos(max(-1.0, min(1.0, (np.trace(r) - 1.0) / 2.0))))


def _closest_on_segment(p, a, b):
    d = b - a
    u = max(0.0, min(1.0, float(np.dot(p - a, d) / np.dot(d, d))))
    return a + d * u


# Source draw sets (graph actions resolved in data/loadout/graph_selections.json and handoffs.json).
# natural = the clip lengths; the graph's quick flag (D4+40) doubles the rate. "mirror": a copy
# reflected through the sagittal plane has to be built (library actor_b_loadout_mirrored).
DRAW_SETS = {
    "pistol_no_pack": {"hand": "right", "status": "source (graph backpack-off overlay)",
                       "grab": "actor_b-p-stealth-idle^p-grab--arm-r--no-pack", "grab_twin": "actor_b-p-stealth-idle^p-grab--add--no-pack",
                       "grab_s": 0.2, "attach_s": 0.17,
                       "equip": "actor_b-p-stealth-draw-p^idle--arm-r--no-pack", "equip_twin": "actor_b-p-stealth-draw-p^idle--add--no-pack",
                       "equip_s": 0.7, "holster": "equip reversed",
                       "holster_finish": {"stand": "actor_b-p-stealth-draw-p^idle--arm-r--no-pack",
                                          "crouch": "actor_b-p-stealth-stow-p^idle--arm-r--no-pack"}, "finish_s": {"stand": 0.7, "crouch": 0.3},
                       "sling_all_finish": {"stand": "actor_b-p-stealth-stow-p^idle--arm-r--no-pack",
                                            "crouch": "actor_b-p-stealth-stow-p^idle--arm-r--no-pack", "s": 0.3,
                                            "deviation": "the graph's standing finish row is the draw clip itself, which walks the "
                                                         "empty hand into the pistol carry pose; hands free uses the stow clip in "
                                                         "both stances (design_fit_check.json revision.holster_finish)"}},
    "pistol_default": {"hand": "right", "status": "source (graph default pistol set)",
                       "grab": "actor_b-p-crouch-idle^p-grab--arm-r", "grab_twin": "actor_b-p-crouch-idle^p-grab--add",
                       "grab_s": 0.2, "attach_s": 0.17,
                       "equip": "actor_b-p-stealth-draw-p^idle--arm-r", "equip_twin": "actor_b-p-crouch-draw-p^idle--add",
                       "equip_s": 0.7, "holster": "equip reversed",
                       "holster_finish": {"stand": "actor_b-p-stealth-draw-p^idle--arm-r", "crouch": "actor_b-p-stealth-stow-p^idle--arm-r"},
                       "finish_s": {"stand": 0.7, "crouch": 0.3}},
    "pistol_no_pack_mirrored": {"hand": "left", "status": "source-derived (mirrored copy to build), then pass_left_to_right",
                                "mirror": True, "grab": "M:actor_b-p-stealth-idle^p-grab--arm-r--no-pack", "grab_s": 0.2, "attach_s": 0.17,
                                "equip": "M:actor_b-p-stealth-draw-p^idle--arm-r--no-pack", "equip_s": 0.7,
                                "then": "pass_left_to_right", "holster": "pass_right_to_left, then equip reversed",
                                "holster_finish": {"stand": "M:actor_b-p-stealth-draw-p^idle--arm-r--no-pack",
                                                   "crouch": "M:actor_b-p-stealth-stow-p^idle--arm-r--no-pack"}, "finish_s": {"stand": 0.7, "crouch": 0.3}},
    "flashlight_left": {"hand": "left", "status": "source (flashlight strap clip), then pass_left_to_right",
                        "equip": "actor_b-fist-ambi-flashlight-draw--part", "equip_s": 1.0, "attach_s": 0.37, "then": "pass_left_to_right",
                        "holster": "pass_right_to_left, then actor_b-fist-ambi-flashlight-holster-part (1.0 s, release 0.50)"},
    "flashlight_right_mirrored": {"hand": "right", "status": "source-derived (mirrored copy to build)", "mirror": True,
                                  "equip": "M:actor_b-fist-ambi-flashlight-draw--part", "equip_s": 1.0, "attach_s": 0.37,
                                  "holster": "M:actor_b-fist-ambi-flashlight-holster-part (1.0 s, release 0.50)"},
    "pass_left_to_right": {"status": "source clip played backwards (forward it passes right -> left)",
                           "stand": "actor_b-p-switch-hands-knife", "crouch": "actor_b-p-switch-hands-knife-crouch",
                           "len_s": {"stand": 0.8, "crouch": 1.0}, "reverse": True,
                           "note": "reversed: the right hand closes at 0.10 s, the left lets go at 0.25 s (stand)"},
    "throwable_back": {"hand": "right", "status": "source (graph molotov-pack-draw)",
                       "grab": "actor_b-p-molotov-idle^draw--part", "grab_twin": "actor_b-p-molotov-idle^draw--add", "grab_s": 0.5,
                       "equip": "actor_b-p-molotov-draw^idle--part", "equip_twin": "actor_b-p-molotov-draw^idle--add", "equip_s": 0.5,
                       "holster": "equip reversed", "holster_finish": {"stand": "grab reversed", "crouch": "grab reversed"},
                       "next": "equip (take the next one from the belt, throwables design: 0.5 s)"},
    "long_gun_left": {"hand": "left, passes to the right at 0.25-0.40 s", "status": "source (graph musket set)",
                      "grab": "actor_b-lg-stealth-idle^grab--arm-r", "grab_twin": "actor_b-lg-stealth-idle^grab--add", "grab_s": 0.4,
                      "attach_s": 0.37, "equip": "actor_b-lg-stealth-draw^idle--arm-r", "equip_twin": "actor_b-lg-stealth-draw^idle--add",
                      "equip_s": 0.9, "holster": "equip reversed",
                      "holster_finish": {"stand": "actor_b-lg-stealth-stow^idle--arm-r", "crouch": "actor_b-lg-stealth-stow^idle--arm-r"},
                      "finish_s": {"stand": 0.7, "crouch": 0.7}},
    "bow_left": {"hand": "left", "status": "source (graph bow set)",
                 "grab": "actor_b-p-bow-draw-idle^grab--part", "grab_twin": "actor_b-p-bow-draw-idle^grab--add", "grab_s": 0.3, "attach_s": 0.27,
                 "equip": "actor_b-p-bow-draw-grab^idle--part", "equip_twin": "actor_b-p-bow-draw-grab^idle--add", "equip_s": 0.9,
                 "holster": "equip reversed",
                 "holster_finish": {"stand": "actor_b-p-bow-draw-grab^idle--part", "crouch": "actor_b-p-bow-stow-grab^idle--part"},
                 "finish_s": {"stand": 0.9, "crouch": 0.3},
                 "sling_all_finish": {"stand": "actor_b-p-bow-stow-grab^idle--part", "crouch": "actor_b-p-bow-stow-grab^idle--part", "s": 0.3,
                                      "deviation": "the standing finish row is the bow draw, which ends with the empty left hand "
                                                   "42 cm in front of the pelvis in the bow carry; hands free uses the stow clip"}},
    "reach_right_shoulder": {"hand": "right", "status": "source segment (bow nock clip: the right hand over the right shoulder); for "
                                                        "arrows and darts it is the whole take; for a spear pair or a musket on long_B "
                                                        "the carry that follows is a SYNTHETIC crossfade (no source clip carries a "
                                                        "long item off the right shoulder)",
                             "stand": "actor_b-p-bow-reload--part", "crouch": "actor_b-p-crouch-bow-reload--part", "len_s": 1.2,
                             "take_s": 0.4, "note": "the hand passes the quiver mouth / upper ends at 0.3-0.4 s; the item appears in the hand there"},
    "reach_left_shoulder": {"hand": "left", "status": "source segment (first 0.25 s of the long-gun draw)",
                            "stand": "actor_b-lg-stealth-draw^idle--arm-r", "segment_s": [0.0, 0.25]},
}


def draw_for(point, kind):
    return {
        ("R_hip", "pistol"): ["pistol_no_pack"],
        ("back_right", "pistol"): ["pistol_default"],
        ("L_hip", "pistol"): ["pistol_no_pack_mirrored", "pass_left_to_right"],
        ("chest_R", "pistol"): ["flashlight_right_mirrored"],
        ("chest_L", "pistol"): ["flashlight_left", "pass_left_to_right"],
        ("back", "tomahawk"): ["throwable_back"],
        ("back_2", "tomahawk"): ["throwable_back"],
        ("back", "atlatl"): ["throwable_back"],
        ("long_A", "musket"): ["long_gun_left"],
        ("long_A", "spear_pair"): ["long_gun_left"],
        ("long_A", "dart_bundle"): ["reach_left_shoulder"],
        ("long_A", "bow"): ["bow_left"],
        ("long_B", "bow"): ["bow_left"],
        ("long_B", "spear_pair"): ["reach_right_shoulder"],
        ("long_B", "dart_bundle"): ["reach_right_shoulder"],
        ("long_B", "musket"): ["reach_right_shoulder"],
        ("quiver", "quiver"): ["reach_right_shoulder"],
    }.get((point, kind), [])


SOURCE_POINT = {"pistol_no_pack": "pistol_right_hip", "pistol_default": "pistol_back_right",
                "pistol_no_pack_mirrored": "pistol_left_hip_mirrored", "flashlight_left": "strap_left_chest",
                "flashlight_right_mirrored": "strap_right_chest_mirrored", "throwable_back": "object_small_of_back",
                "long_gun_left": "long_gun_left_shoulder", "bow_left": "bow_left_back",
                "reach_right_shoulder": "quiver_right_shoulder", "reach_left_shoulder": "long_gun_left_shoulder"}


REACH_WINDOW = {
    "reach_right_shoulder": {"stand": ("clip:actor_b-p-bow-reload--part@stand", "r", 0.0, 0.5),
                             "crouch": ("clip:actor_b-p-crouch-bow-reload--part@crouch", "r", 0.0, 0.5)},
    "reach_left_shoulder": {"stand": ("graph:musket/stand/equip", "l", 0.0, 0.25),
                            "crouch": ("graph:musket/crouch/equip", "l", 0.0, 0.25)},
}
_CASES = {}


def _cases():
    if not _CASES:
        _CASES.update(json.load(open(os.path.join(DATA, "handoffs_cases.json")))["cases"])
    return _CASES


def handover(h, rest, key, v):
    """Gap between the stowed item and the source grab, per stance (bind frame of the carrying bone)."""
    sets = draw_for(v["point"], v["kind"])
    if not sets or v["t"] is None:
        return None
    src = SOURCE_POINT[sets[0]]
    out = {"draw_set": sets[0], "source_point": src, "stances": {}}
    t = v["t"]
    for st in ("stand", "crouch"):
        c = h["stow_points"]["points"][src]["stances"][st][0]
        p = c.get("parked") or c.get("in_hand")
        hand = np.array(c["hand_bind_equiv"], float)
        e = {"source_case": c["case"], "hand_bind_equiv": [round(x, 4) for x in hand]}
        reach = REACH_WINDOW.get(sets[0])
        if reach:
            # a reach segment: the item is taken where the hand passes closest to it inside the window
            case_id, side, t0, t1 = reach[st]
            trail = [(tt, np.array(pp, float)) for tt, pp, _ in _cases()[case_id]["hands"][side]["trail_bind_equiv"] if t0 <= tt <= t1]
            best = None
            for tt, pp in trail:
                for c2 in [c for c in v["caps"] if "string" not in c["id"]]:
                    a = np.array(c2["origin"], float)
                    b = a + np.array(c2["axis"], float) * c2["length"]
                    q = _closest_on_segment(pp, a, b)
                    d = float(np.linalg.norm(pp - q)) - float(c2["radius"])
                    if best is None or d < best[0]:
                        best = (d, q, tt, pp)
            e["source_case"] = case_id
            e["contact_gap_m"] = round(max(best[0], 0.0), 3)
            e["contact_bind"] = [round(x, 4) for x in best[1]]
            e["take_t_s"] = best[2]
            e["hand_bind_equiv"] = [round(x, 4) for x in best[3]]
            e["slide_to_grip_m"] = round(float(np.linalg.norm(best[1] - t[:3, 3])), 3)
            e["contact"] = "nearest pass of the reaching hand (10 Hz trail) within %.2f-%.2f s" % (t0, t1)
            out["stances"][st] = e
            continue
        if v["kind"] == "pistol" and v["point"] in ("R_hip", "L_hip", "back_right"):
            bone = "pelvis"
            mi = p["model_in"][bone]
            s = rest[bone] @ xf(mi["quat_xyzw"], mi["origin"])
            e["grip_gap_m"] = round(float(np.linalg.norm(s[:3, 3] - t[:3, 3])), 3)
            e["rotation_deg"] = round(_rot_deg(s, t), 1)
            if v.get("grab_pose") is not None:
                e["rotation_deg_from_grab_pose"] = round(_rot_deg(s, v["grab_pose"]), 1)
            e["contact"] = "grip"
            e["source_model_in_pelvis"] = mi["godot"]
            e["source_model_in_spined"] = p["model_in"]["spined"]["godot"]
        elif v["kind"] == "pistol":
            grip = t[:3, 3]
            e["grip_gap_m"] = round(float(np.linalg.norm(hand - grip)), 3)
            e["contact"] = "grip"
        else:
            caps = [c for c in v["caps"] if "string" not in c["id"]]
            best = None
            for c2 in caps:
                a = np.array(c2["origin"], float)
                b = a + np.array(c2["axis"], float) * c2["length"]
                q = _closest_on_segment(hand, a, b)
                d = float(np.linalg.norm(hand - q)) - float(c2["radius"])
                if best is None or d < best[0]:
                    best = (d, q)
            e["contact_gap_m"] = round(max(best[0], 0.0), 3)
            e["contact_bind"] = [round(x, 4) for x in best[1]]
            e["slide_to_grip_m"] = round(float(np.linalg.norm(best[1] - t[:3, 3])), 3)
            e["contact"] = "nearest point of the item to the source hand"
        out["stances"][st] = e
    g = [out["stances"][s].get("grip_gap_m", out["stances"][s].get("contact_gap_m", 0.0)) for s in out["stances"]]
    out["max_gap_m"] = max(g)
    out["reach_ik"] = max(g) > 0.06
    return out


def _json_default(o):
    if isinstance(o, np.ndarray):
        return [round(float(x), 4) for x in o.ravel()]
    if isinstance(o, (np.floating, np.integer)):
        return o.item()
    raise TypeError(type(o))


def design_candidate_table(raw):
    """The source-derived rigid candidates of revisions 1-2 (dz_*, dz2_*: the review asked for them here)."""
    out = {}
    for pref in sorted({c["id"].split(":")[0] for c in raw["candidates"] if c["id"].startswith(("dz_", "dz2_"))}):
        ids = [c["id"] for c in raw["candidates"] if c["id"].split(":")[0] == pref]
        fc = fit_checks(raw, ids, "pistol" if "hip" in pref or "chest" in pref or "back_right" in pref else "x")
        out[pref] = {"verdict": fc["verdict"], "worst_play_cm": fc["worst_play_cm"], "groups": fc["groups"], "attach": "rigid"}
    return out


FIDELITY = {
    ("R_hip", "pistol"): "source (graph backpack-off set) + reach IK",
    ("back_right", "pistol"): "source (graph default set) + reach IK crouched",
    ("L_hip", "pistol"): "source-derived (mirrored copies to build) + reach IK + reversed pass",
    ("chest_R", "pistol"): "source-derived (mirrored flashlight clip) + reach IK",
    ("chest_L", "pistol"): "source (flashlight clip) + reach IK + reversed pass",
    ("back", "tomahawk"): "source (graph molotov-pack-draw)", ("back_2", "tomahawk"): "source + reach IK",
    ("back", "atlatl"): "source + reach IK",
    ("long_A", "musket"): "source clips + explicit world-space path (left-hand IK out and over the shoulder)",
    ("long_A", "spear_pair"): "source clips (long-gun set) + the musket path",
    ("long_A", "dart_bundle"): "source segment (first 0.25 s of the long-gun draw)",
    ("long_B", "bow"): "source (graph bow set) + reach IK",
    ("long_B", "spear_pair"): "SYNTHETIC: source reach over the right shoulder, then a crossfade to the spear carry",
    ("long_B", "dart_bundle"): "source segment (bow nock reach): the take of a dart",
    ("long_B", "musket"): "SYNTHETIC: source reach over the right shoulder, then a crossfade to the carry",
    ("quiver", "quiver"): "source (bow nock clip)",
}


def handoff_specs(points, rev):
    """Per point: the handoff timing as phases of the draw clip, the pre-contact motion, the per-state policies."""
    for key, e in points.items():
        e["draw_fidelity"] = FIDELITY.get((e["point"], e["kind"]), "")
    r = rev.get("r_hip", {})
    if "R_hip.pistol" in points and r:
        st = r.get("settle", {})
        row = r["candidates"][r["pick"]]
        points["R_hip.pistol"]["handoff"] = {
            "pre_contact": {"motion": "pendulum about the belt normal through the hook (no roll about the barrel)",
                            "max_deg": 20, "swing_deg": row["pendulum"]["swing_deg"],
                            "only_while_hand_within_m": 0.12, "window_s_natural": st.get("pendulum_window_s_natural")},
            "rotation_left_for_the_hand_deg": row["pendulum"]["rotation_left_for_the_hand_deg"],
            "in_hand_settle_phase": st.get("settle_phase"), "settle_turn_rate_dps_quick": st.get("settle_turn_rate_dps_quick"),
            "crouch": r.get("settle_crouch"),
            "reach_ik_decay_phase": st.get("reach_ik_decay_phase"), "reach_ik_speed_mps_quick": st.get("reach_ik_speed_mps_quick"),
            "hand_peak_speed_mps_quick": st.get("hand_peak_speed_mps_quick"),
            "note": "phases are fractions of the draw clip, so they scale with the rate (quick = x2)"}
    if "long_A.musket" in points:
        points["long_A.musket"]["handoff"] = {"path": "explicit world-space path (loadout_design.md 5.2)", **R.MUSKET_PATH,
                                              "measured": rev.get("musket_path")}
    pol = rev.get("ride_prone", {}).get("policies", {})
    for key, p in pol.items():
        if key in points:
            points[key]["ride_prone"] = p
    for key, t in rev.get("traversal", {}).items():
        if key in points:
            points[key]["traversal"] = {"policy": t["choice"], "residual_cm": t["residual_cm"], "n_clips_below_contact": t["n_clips_below_contact"]}


def build(raw_path, dump_path=None):
    rest = load_rest()
    h = load("handoffs.json")
    cs = load("carry_points_survey.json")
    F = final_placements(rest, h, cs)
    raw = json.load(open(raw_path)) if raw_path else None
    rev = None
    dump = R.Dump(dump_path) if dump_path else None
    if raw is not None and dump is not None:
        rev = R.revise(F, raw, dump, h, rest, cs, fit_checks, stow_model)
    if raw is not None:
        have = {c["id"] for c in raw["candidates"]}
        missing = [c["id"] for v in F.values() for c in v["caps"] if c["id"] not in have]
        assert not missing, "fit run lacks %s: rerun step 1 and the survey tool" % missing[:5]

    points = {}
    fit = {}
    for key, v in F.items():
        e = {"point": v["point"], "kind": v["kind"], "bone": v["bone"], "attach": v["attach"], "basis": v["basis"], "note": v["note"],
             "yield_deg": v.get("yield_deg", 0.0),
             "capsules_bind": [{"id": c["id"], "bone": c["bone"], "from": c["origin"],
                                "to": [round(a + b * c["length"], 4) for a, b in zip(c["origin"], c["axis"])],
                                "radius": c["radius"], "anchors": c.get("anchors")} for c in v["caps"]]}
        if v["t"] is not None:
            e["stow"] = xf_json(v["t"], rest, v["bone"])
        if v.get("grab_pose") is not None:
            e["grab_pose"] = xf_json(v["grab_pose"], rest, v["bone"])
            e["grab_pose"]["use"] = ("slerp stow -> grab_pose about the hook while the grab clip plays (the pistol pivots on its "
                                     "hook under the reaching hand); reverse after the holster")
            if raw is not None:
                fc = fit_checks(raw, [c["id"] for c in v["grab_caps"]], v["kind"])
                e["grab_pose"]["fit_if_left_there"] = {"verdict": fc["verdict"], "worst_play_cm": fc["worst_play_cm"]}
        e["draw"] = draw_for(v["point"], v["kind"])
        ho = handover(h, rest, key, v)
        if ho:
            e["handover"] = ho
        if raw is not None:
            fc = fit_checks(raw, [c["id"] for c in v["caps"]], v["kind"])
            e["fit"] = {"verdict": fc["verdict"], "worst_play_cm": fc["worst_play_cm"]}
            fit[key] = fc
        points[key] = e
    gaps = pair_gaps(raw, F) if raw is not None else {}
    if rev is not None:
        R.revise_after(F, raw, dump, PRESETS, {k: e.get("handover", {}) for k, e in points.items()}, draw_for, rev)
        handoff_specs(points, rev)

    # Stack order on the back (inner -> outer) and the extra standoff of an item over another
    # (overlap + 1 cm; body-fit back_layering, measured with the stave / barrel capsules).
    layer_of = {"quiver": 1, "long_B": 2, "long_A": 3}
    extra = {}
    for k, e in gaps.items():
        a, b = k.split(" | ")
        la = layer_of.get(points[a]["point"], 0)
        lb = layer_of.get(points[b]["point"], 0)
        if la == lb or "loco" not in e or points[a]["point"] == points[b]["point"]:
            continue
        under, over = (a, b) if la < lb else (b, a)
        g = float(e["loco"]["gap_cm"])
        if g < 1.0:
            extra["%s over %s" % (over, under)] = round(1.0 - g, 1)
    layering = {"order_inner_to_outer": ["body (horn, belt pistol, back tomahawk / atlatl)", "quiver", "long_B", "long_A"],
                "extra_standoff_cm": dict(sorted(extra.items())),
                "survey_extra_standoff_cm": {k: v["extra_standoff_for_outer_cm"] for k, v in cs["back_layering"].items()},
                "rule": "standoff(item) = max over the items under it of standoff(under) + extra(under, item); applied as a "
                        "rotation about the item's upper contact (the shoulder) so that the crossing point gets its standoff, "
                        "not as a translation of the whole item"}

    gear = GEAR
    carry = {"format": "frontier-loadout-carry-gear", "version": 1, "provenance": PROVENANCE,
             "generator": "tools/loadout/build_loadout_data.py (step 2)",
             "conventions": {"space": "bind pose null-add; 'stow.local' is the model transform in the carrying bone's rest frame "
                                      "(Godot variant text: basis rows then origin); 'stow.bind' is the same in skeleton space",
                             "model_axes": "WeaponModels / ThrowableModels: firearms and spears -Z = muzzle / point, +Y = top; bow +Y = "
                                           "upper limb, string +Z; tomahawk +Y = haft to head, -Z = edge; atlatl +Z = to the hook; "
                                           "dart origin = tip, +Z = to the nock; quiver (new) origin = mouth, +Y = out of the mouth",
                             "angles": "0 front, 90 character right, 180 back, 270 left (about the skeleton Y axis)",
                             "attach": "rigid = the bone's pose; two_anchor = hook on the bone, direction from a skinned second anchor "
                                       "at 70 % of the item (body-fit survey)"},
             "points": points, "gear": gear, "pistol_cap": 4,
             "pistol_cap_note": "a game cap (two braces), not a documented maximum: Johnson (1724) gives Blackbeard three brace (six) "
                                "on one sling. Per gear the table of loadout_design.md 1.4 is a MAXIMUM; the usable number after the "
                                "other items is effective_pistol_capacity() (LoadoutRules)",
             "yield": {"max_deg": R.YIELD_MAX_DEG, "limbs": list(R.ARM_SWING) + ["r_upper_arm", "l_upper_arm", "r_thigh", "l_thigh", "r_shin",
                                                                                   "l_shin"],
                       "rule": "an item with yield_deg > 0 hangs from a hook or strap: each frame it swings about its hook "
                               "(first capsule origin) away from any limb capsule that would pass into it, by the smallest angle up "
                               "to yield_deg, never deeper into the body; smoothed over 0.08 s (measure_body_fit.gd 'yield')"},
             "back_layering": layering, "pair_gaps": gaps,
             "draw_sets": DRAW_SETS}
    json.dump(carry, open(os.path.join(DATA, "carry_gear.json"), "w"), indent=1)
    json.dump(ITEMS, open(os.path.join(DATA, "loadout_items.json"), "w"), indent=1)
    json.dump(PRESETS, open(os.path.join(DATA, "loadout_presets.json"), "w"), indent=1)
    if raw is not None:
        extra = {}
        if rev is not None:
            extra["revision"] = rev
            extra["design_candidates"] = design_candidate_table(raw)
        json.dump({"format": "frontier-loadout-design-fit-check", "version": 2, "provenance": PROVENANCE,
                   "run": os.path.basename(raw_path), "classification": {"clean": ">= -1 cm (locomotion, crouch, weapon use)",
                                                                        "contact": ">= -3.5 cm", "clips": "< -3.5 cm"},
                   "placements": fit, "pair_gaps": gaps, **extra}, open(os.path.join(DATA, "design_fit_check.json"), "w"), indent=1,
                  default=_json_default)
    errors = validate(carry, ITEMS, PRESETS)
    assert not errors, errors
    print("LOADOUT DATA OK: %d placements, %d gear, %d kinds, %d presets" % (len(points), len(gear), len(ITEMS["kinds"]),
                                                                          len(PRESETS["presets"])))
    for k, e in points.items():
        ho = e.get("handover")
        print("  %-20s %-10s %-8s %s  gap %s" % (k, e["bone"], e.get("fit", {}).get("verdict", "-"), e.get("fit", {}).get("worst_play_cm", ""),
                                            ho["max_gap_m"] if ho else "-"))


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "candidates"
    if mode == "candidates":
        build_candidates()
        build_candidates_final()
    elif mode == "build":
        build(sys.argv[2] if len(sys.argv) > 2 else None, sys.argv[3] if len(sys.argv) > 3 else None)
    else:
        sys.exit("usage: build_loadout_data.py candidates | build <raw_fit.json> [<pose_dump.json>]")
