"""Procedural helper bones driven at runtime by scripts/player/character_body.gd
(CharacterBodyMesh): the table, the skirt / queue / twist constants (single source of
truth for the generators; the game script must match, check_body_attach.gd verifies),
a Python twin of the game's driver for previews, and the driver reference poses.

Split out of tools/character/build_body.py (lib v1); values unchanged.
"""

import math
import os

import bpy
from mathutils import Matrix, Quaternion, Vector

from .rig import FRONTIER, LIBS, PROJECT, clear_action, g2b, godot_xf, load_actions, set_action, xf12
from .sdf import log, smoothstep

# Legacy coat hem (the hunting frock of actor_b_body.glb): the skirt panel hems below.
LEGACY_SKIRT_HEM = 0.525
LEGACY_SKIRT_FRONT_RISE = 0.06

# ---------------------------------------------------------------------------
# Procedural helper bones (driven at runtime by scripts/player/character_body.gd)
# ---------------------------------------------------------------------------
# The rig's twist / leg helper bones are never animated by the clips. The game drives
# these from the animated pose (CharacterBodyMesh.HELPERS; the same table is written to
# the sidecar json and check_body_attach.gd compares both):
#   [name (per side), kind, a, b]
#   upper_arm: rotation = clavicle * swing^a * twist^b of the shoulder relative to the
#              clavicle (twist about the bind upper-arm axis), pivot at the shoulder joint
#   forearm:   rotation = elbow * (a * roll of the wrist relative to the elbow), pivot
#              at the elbow joint
#   skirt:     a = panel (0 front, 1 side, 2 back); rotation about the hip joint relative
#              to the pelvis: gravity (bind hang direction -> world-down, limited), the
#              thigh only pushing (front >= thigh flexion * ramp, back <= thigh flexion +
#              clearance, side between them leaning to gravity and pushed out by the
#              thigh's abduction), then lifted off the floor (lowest foot)
HELPERS = [
    ["shoulder_twist_a", "upper_arm", 0.5, 0.0],        # armpit: half the swing
    ["shoulder_twist_b", "upper_arm", 1.0, 0.0],        # top of the upper arm: swing only
    ["shoulder_twist_c", "upper_arm", 1.0, 1.0 / 3.0],
    ["shoulder_twist_d", "upper_arm", 1.0, 2.0 / 3.0],
    ["forarm_twist_a", "forearm", 0.3, 0.0],
    ["forarm_twist_b", "forearm", 0.6, 0.0],
    ["forarm_twist_c", "forearm", 0.9, 0.0],
    ["upper_leg_front_helper", "skirt", 0, 0.0],
    ["upper_leg_thigh_helper", "skirt", 1, 0.0],
    ["upper_leg_rear_helper", "skirt", 2, 0.0],
]


# Skirt panel constants (CharacterBodyMesh.SKIRT_*; json helpers.skirt). Hem centre of each
# panel, left leg, GODOT bind skeleton space (x, y up, z forward), right leg mirrored in x.
SKIRT_HEMS_GODOT = [(0.12, LEGACY_SKIRT_HEM + LEGACY_SKIRT_FRONT_RISE, 0.145),
                    (0.24, LEGACY_SKIRT_HEM + 0.5 * LEGACY_SKIRT_FRONT_RISE, -0.01), (0.12, LEGACY_SKIRT_HEM, -0.18)]
SKIRT_GRAVITY_MAX_DEG = 60.0
SKIRT_FRONT_GAIN = (0.6, 1.0, 60.0)       # front: gain on the thigh's flexion ramps x -> y over 0..z deg
SKIRT_REAR_CLEAR_DEG = 6.0
SKIRT_REAR_ABD = 0.5
SKIRT_SIDE_CLEAR_DEG = 4.0
SKIRT_SIDE_GRAVITY = 0.5
SKIRT_FLOOR_MARGIN = 0.03
SKIRT_FLOOR_MAX_DEG = 70.0
SKIRT_FLOOR_TILT_DEG = (35.0, 60.0)       # the floor lift fades out as the pelvis tilts (lying)
SKIRT_FEET = ["l_heel", "l_ball", "r_heel", "r_ball"]
# twist wrap centres (degrees, left side; the right side is mirrored)
UPPER_ARM_TWIST_CENTER_DEG = -35.0
FOREARM_TWIST_CENTER_DEG = -25.0
# Hair queue: a pendulum on an unused root-level rig bone. Its root (the ribbon wrap,
# QUEUE_ROOT, Blender bind space) is carried by headb. It hangs along the torso's
# (spined) down direction turned QUEUE_GRAVITY of the way to world-down, never forward
# of the torso's down (into the neck) and at most QUEUE_SIDE_MAX_DEG to its side. Every
# hair style with a queue, club or braid hangs it from QUEUE_ROOT.
QUEUE_HELPER = "wrinklemaps"
QUEUE_GRAVITY = 0.6
QUEUE_SIDE_MAX_DEG = 25.0
QUEUE_ROOT = (0.0, 0.072, 1.428)     # the ribbon wrap at the nape (legacy QUEUE_PTS[1])
# Soft tissue (body v4, 2026-09-28): each breast on the rig's own breast bone (a child of spined,
# unused by the clips' meshes), a damped spring driven at runtime by the chest's acceleration
# (CharacterBodyMesh.BREAST_*); the weights are MPFB's CC0 breast weights
# (tools/character/makehuman/rigs/breast_weights.json).
BREAST_BONES = ["l_breast", "r_breast"]
# The male genitals (body v4): on an unused rig bone (keyed by the clips, no mesh used it), carried by
# the pelvis; bare, a bounce (offset spring) and a swing (pendulum about GENITAL_ROOT, the tip
# GENITAL_TIP) driven by the tip's acceleration (CharacterBodyMesh.GENITAL_*). Godot bind skeleton
# space; body_v4 measures both on the male fit and warns when they drift from these.
GENITAL_HELPER = "spinea_muscle"
GENITAL_ROOT = (0.0, 0.787, 0.08)
GENITAL_TIP = (0.0, 0.736, 0.128)


def helpers_json():
    """The "helpers" block of a sidecar / catalog json (check_body_attach.gd compares it with
    CharacterBodyMesh)."""
    return {"table": HELPERS,
            "skirt": {"hems_godot": [list(h) for h in SKIRT_HEMS_GODOT],
                      "gravity_max_deg": SKIRT_GRAVITY_MAX_DEG, "front_gain": list(SKIRT_FRONT_GAIN),
                      "rear_clear_deg": SKIRT_REAR_CLEAR_DEG, "rear_abd": SKIRT_REAR_ABD,
                      "side_clear_deg": SKIRT_SIDE_CLEAR_DEG, "side_gravity": SKIRT_SIDE_GRAVITY,
                      "floor_margin": SKIRT_FLOOR_MARGIN, "floor_max_deg": SKIRT_FLOOR_MAX_DEG,
                      "floor_tilt_deg": list(SKIRT_FLOOR_TILT_DEG),
                      "feet": SKIRT_FEET},
            "queue": {"bone": QUEUE_HELPER, "gravity": QUEUE_GRAVITY, "side_max_deg": QUEUE_SIDE_MAX_DEG,
                      "root_godot": [QUEUE_ROOT[0], QUEUE_ROOT[2], -QUEUE_ROOT[1]]},
            "genital": {"bone": GENITAL_HELPER, "root_godot": list(GENITAL_ROOT), "tip_godot": list(GENITAL_TIP)},
            "upper_arm_twist_center_deg": UPPER_ARM_TWIST_CENTER_DEG,
            "forearm_twist_center_deg": FOREARM_TWIST_CENTER_DEG,
            "note": ("Procedural helper bones driven at runtime by scripts/player/character_body.gd "
                     "(CharacterBodyMesh.HELPERS must match this table).")}


def helper_bones():
    return [sd + "_" + h[0] for sd in "lr" for h in HELPERS] + [QUEUE_HELPER] + BREAST_BONES + [GENITAL_HELPER]


def _twist(q, axis, sign, center_deg):
    a = 2.0 * math.atan2(Vector((q.x, q.y, q.z)).dot(axis), q.w)
    c = math.radians(center_deg)
    return ((a * sign - (c - math.pi)) % (2 * math.pi) + (c - math.pi)) * sign


def _rotvec(q):
    """Rotation vector (axis * angle, angle in [0, pi]) of a unit quaternion."""
    if q.w < 0:
        q = -q
    v = Vector((q.x, q.y, q.z))
    s = v.length
    if s < 1e-9:
        return v * 2.0
    return v * (2.0 * math.atan2(s, q.w) / s)


def _lift(v, u, up, need, limit):
    """Twin of CharacterBodyMesh._lift: smallest rotation about u (in the direction that
    raises v at first) that brings v.up to `need`, at most `limit`."""
    par = u * v.dot(u)
    perp = v - par
    base = par.dot(up)
    a = perp.dot(up)
    b = u.cross(perp).dot(up)
    if a >= need - base:
        return 0.0
    sg = 1.0 if b >= 0.0 else -1.0
    rr = math.hypot(a, b)
    if rr < 1e-9:
        return 0.0
    t0 = math.atan2(abs(b), a)
    c = (need - base) / rr
    t = t0 if c >= 1.0 else max(t0 - math.acos(min(max(c, -1.0), 1.0)), 0.0)
    return sg * min(t, limit)


def drive_helpers(Gp, Gb):
    """Python twin of CharacterBodyMesh._drive (previews only): posed globals of the
    driven helper bones from the posed globals Gp and bind globals Gb (Blender armature
    space, name -> Matrix). Godot's -X / +Z / DOWN are Blender's -X / -Y / -Z."""
    def skin_q(n):
        return (Gp[n] @ Gb[n].inverted()).to_quaternion().normalized()
    down = Vector((0, 0, -1))
    D = Vector((0, 0, -1))
    floor_h = min(-Gp[f].translation.dot(down) - Gb[f].translation.z for f in SKIRT_FEET)
    out = {}
    for sd, sign in (("l", 1.0), ("r", -1.0)):
        for name, kind, a, b in HELPERS:
            hb = sd + "_" + name
            if kind == "upper_arm":
                par, child, joint = sd + "_clavicle", sd + "_shoulder", sd + "_shoulder"
                axis = (Gb[sd + "_elbow"].translation - Gb[joint].translation).normalized()
            elif kind == "forearm":
                par, child, joint = sd + "_elbow", sd + "_wrist", sd + "_elbow"
                axis = (Gb[child].translation - Gb[joint].translation).normalized()
            else:
                par, child, joint = "pelvis", sd + "_upper_leg", sd + "_upper_leg"
                axis = (Gb[sd + "_knee"].translation - Gb[joint].translation).normalized()
            qp = skin_q(par)
            rel = (qp.inverted() @ skin_q(child)).normalized()
            jb, jp = Gb[joint].translation, Gp[joint].translation
            if kind == "upper_arm":
                tw = _twist(rel, axis, sign, UPPER_ARM_TWIST_CENTER_DEG)
                swing = rel @ Quaternion(axis, tw).inverted()
                if swing.w < 0:
                    swing.negate()
                r = qp @ Quaternion().slerp(swing, a) @ Quaternion(axis, tw * b)
            elif kind == "forearm":
                r = qp @ Quaternion(axis, _twist(rel, axis, sign, FOREARM_TWIST_CENTER_DEG) * a)
            else:
                fx, ax = Vector((-1, 0, 0)), Vector((0, -sign, 0))
                tv = _rotvec(axis.rotation_difference(rel @ axis))
                tf, ta = tv.dot(fx), tv.dot(ax)
                dl = (qp.inverted() @ down).normalized()
                gv = _rotvec(D.rotation_difference(dl)) if dl.dot(D) > -0.9999 else fx * math.pi
                gmax = math.radians(SKIRT_GRAVITY_MAX_DEG)
                if gv.length > gmax:
                    gv = gv * (gmax / gv.length)
                gf, ga = gv.dot(fx), gv.dot(ax)
                push = math.radians(15.0)
                lo = tf
                if tf > 0.0:
                    g0, g1, gd = SKIRT_FRONT_GAIN
                    lo = tf * (g0 + (g1 - g0) * float(smoothstep(0.0, math.radians(gd), tf)))
                ff = max(gf, lo)
                fa = ga + (ta - ga) * float(smoothstep(0.0, push, lo - gf))
                hi = tf + math.radians(SKIRT_REAR_CLEAR_DEG)
                bf = min(gf, hi)
                ba = ga + (ta * SKIRT_REAR_ABD - ga) * float(smoothstep(0.0, push, gf - hi))
                if int(a) == 0:
                    pf, pa = ff, fa
                elif int(a) == 2:
                    pf, pa = bf, ba
                else:
                    mid = 0.5 * (ff + bf)
                    pf = mid + (min(max(gf, min(ff, bf)), max(ff, bf)) - mid) * SKIRT_SIDE_GRAVITY
                    pa = max(0.5 * (fa + ba), ta - math.radians(SKIRT_SIDE_CLEAR_DEG))
                rv = fx * pf + ax * pa
                r = qp @ (Quaternion(rv.normalized(), rv.length) if rv.length > 1e-9 else Quaternion())
                hx, hy, hz = SKIRT_HEMS_GODOT[int(a)]
                hem = g2b((hx * sign, hy, hz))
                u = (qp @ (Vector((1, 0, 0)) if int(a) != 1 else Vector((0, -1, 0)))).normalized()
                tilt = (qp @ Vector((0, 0, 1))).angle(-down)
                upright = 1.0 - float(smoothstep(math.radians(SKIRT_FLOOR_TILT_DEG[0]), math.radians(SKIRT_FLOOR_TILT_DEG[1]), tilt))
                lift = upright * _lift(r @ (hem - jb), u, -down, floor_h + SKIRT_FLOOR_MARGIN + jp.dot(down),
                                       math.radians(SKIRT_FLOOR_MAX_DEG))
                if lift != 0.0:
                    r = Quaternion(u, lift) @ r
            R = r.normalized().to_matrix().to_4x4()
            m = Matrix.Translation(jp) @ R @ Matrix.Translation(-jb)
            out[hb] = m @ Gb[hb]
    # hair queue pendulum
    qs = skin_q("spined")
    td = qs @ D
    h = td * (1.0 - QUEUE_GRAVITY) + down * QUEUE_GRAVITY
    h = h.normalized() if h.length > 1e-6 else td
    fwd = qs @ Vector((0, -1, 0))
    f = h.dot(fwd)
    if f > 0.0:
        h = (h - fwd * f).normalized()
    right = qs @ Vector((1, 0, 0))
    sdv = h.dot(right)
    sm = math.sin(math.radians(QUEUE_SIDE_MAX_DEG))
    if abs(sdv) > sm:
        h = (h - right * (sdv - math.copysign(sm, sdv))).normalized()
    r = (td.rotation_difference(h) @ qs) if td.dot(h) > -0.9999 else qs
    root = Vector(QUEUE_ROOT)
    root_p = (Gp["headb"] @ Gb["headb"].inverted()) @ root
    m = Matrix.Translation(root_p) @ r.normalized().to_matrix().to_4x4() @ Matrix.Translation(-root)
    out[QUEUE_HELPER] = m @ Gb[QUEUE_HELPER]
    return out


# Poses whose driven helper globals the Python twin writes into the sidecar json, with the
# driver's input bone globals ("driver_reference"). check_body_attach.gd feeds the same
# inputs to CharacterBodyMesh._drive() and compares: the preview twin cannot drift from
# the game's driver. (action, library, frame)
DRIVER_REFERENCE = [
    ("actor_b-p-run-fw", "Actor_B_016.blend", 6),
    ("actor_b-p-sprint-fw", "Actor_B_016.blend", 12),
    ("actor_b-p-rifle-idle-aim", "Actor_B_016.blend", 1),
    ("actor_b-p-bow-aim-idle", "Actor_B_011.blend", 1),
    ("actor_b-p-crouch-idle", "Actor_B_012.blend", 1),
    ("actor_b-p-crouch-walk-fw", "Actor_B_012.blend", 12),
    ("actor_b-p-crouch-hr-fw", "Actor_B_012.blend", 22),
    ("actor_b-p-death-back", "Actor_B_012.blend", 60),
    ("actor_b-p-land-hard-damage^idle", "Actor_B_014.blend", 15),
]


def driver_reference(rig, base, G):
    """[{clip, frame, inputs, helpers}]: the bone globals the driver reads and the helper
    globals drive_helpers() makes of them, Godot space (xf12)."""
    if not PROJECT:
        # (the rig rebuilt from the skeleton record has no clip libraries: the reference the last build with them made)
        import json
        prev = os.path.join(FRONTIER, "assets", "character", "body", "body.json")
        log("driver reference: no clip libraries, kept from %s" % prev)
        return json.load(open(prev)).get("driver_reference", []) if os.path.exists(prev) else []
    libs = {}
    for act, lib, _ in DRIVER_REFERENCE:
        libs.setdefault(lib, []).append(act)
    for lib, names in libs.items():
        load_actions(os.path.join(LIBS, lib), [n for n in names if n not in bpy.data.actions])
    need = {"pelvis", "spined", "headb"} | set(SKIRT_FEET)
    for sd in "lr":
        need |= {sd + "_" + n for n in ("clavicle", "shoulder", "elbow", "wrist", "upper_leg", "knee")}
    out = []
    for act, lib, frame in DRIVER_REFERENCE:
        if act not in bpy.data.actions:
            log("driver reference clip missing: %s" % act)
            continue
        set_action(rig, act, frame, base)
        Gp = {}
        for pb in rig.pose.bones:
            loc, rot, _ = (rig.matrix_world @ pb.matrix).decompose()
            Gp[pb.name] = Matrix.LocRotScale(loc, rot, None)
        H = drive_helpers(Gp, G)
        out.append({"clip": act, "frame": frame, "inputs": {b: xf12(godot_xf(Gp[b])) for b in sorted(need)},
                    "helpers": {b: xf12(godot_xf(m)) for b, m in sorted(H.items())}})
    clear_action(rig)
    return out
