"""Chosen Motifect moves taken into the game's clips (the owner, 2026-10-12: "we can take some moves and then add it into our own",
then "do and add what u can so we can see what it looks like"; animations/SOURCE.md "Motifect-derived clips"): motion from the
Motifect martial arts pack (AI-generated BVH, Motifect's licence: free for personal and commercial use in a project, the raw
files never redistributed; read from the owner's ~/Downloads/Motifect_martial_arts_v1_0, never copied into the project)
retargeted onto Actor_B's rig (assets/character/actor_b_body.glb, rigkit.SK) and cut to the game's cast shape, baked as
bend_clips.py bakes (each bone's local rotation as Godot has it, the root's place) for tools/anim_author/install_motifect.gd.

The retarget, frame by frame: the BVH's global joint rotations (its rest pose is its T-pose, every joint unrotated) carried onto
our bones through each mapped bone's rest frame (its direction and a second axis: our rest's turned onto the BVH rest's), so
our bone points where the BVH's points and twists as it twists; spinec half way between its neighbours; the bones between the
mapped ones (the bases, the pelvis, the palms, the heels) keep their rest under their parents; the fingers a closed fist
(style_kit's boxing fist); the root's place the BVH hips' (scaled by the legs' lengths), its drift across the deck taken back
by the clip's end, the whole set down so the standing feet stand on the deck. Then each clip's edits, typed below: its span,
its moments (hold_s the chamber held while the lock fills, strike_s, back_s), a kicking leg brought down (`cap`: the ankle no
higher than cap m, the leg swung down about the hip, its knee and foot as they were), an airborne part's lift taken off (the
game's jump carries the body), a spin made whole (its heading back to its start, a full turn more). Mirrored twins from the
BVH mirrored (left for right) before the retarget.
    blender -b --factory-startup -P tools/anim_author/blender/motifect_clips.py -- --out /tmp/motifect.json
        [--bvh-dir ~/Downloads/Motifect_martial_arts_v1_0/BVH] [--clips kick_low,...] [--report]
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import style_kit as kit  # noqa: E402  (bend_clips' rig and bake, the boxing fist)
import bend_clips as bc  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

SK = bc.SK
FPS = 30
DEFAULT_DIR = os.path.expanduser("~/Downloads/Motifect_martial_arts_v1_0/BVH")

## Ours <- the BVH's: (our bone, BVH joint, our direction (from, to) or "up", the BVH's, the second axis: "x" left, "z" forward,
## "hips" the hip line, "knuckles" across the knuckles).
MAP = [
    ("root", "Hips", "up", "up", "hips"),
    ("spinea", "Spine1", ("spinea", "spineb"), ("Spine1", "Spine2"), "x"),
    ("spineb", "Spine2", ("spineb", "spinec"), ("Spine2", "Chest"), "x"),
    ("spined", "Chest", ("spined", "neck"), ("Chest", "Neck1"), "x"),
    ("neck", "Neck1", ("neck", "heada"), ("Neck1", "Neck2"), "x"),
    ("heada", "Neck2", ("heada", "headb"), ("Neck2", "Head"), "x"),
    ("headb", "Head", "up", "up", "x"),
]
for _s, _S in (("l", "Left"), ("r", "Right")):
    MAP += [
        (_s + "_clavicle", _S + "Shoulder", (_s + "_clavicle", _s + "_shoulder"), (_S + "Shoulder", _S + "Arm"), "z"),
        (_s + "_shoulder", _S + "Arm", (_s + "_shoulder", _s + "_elbow"), (_S + "Arm", _S + "ForeArm"), "z"),
        (_s + "_elbow", _S + "ForeArm", (_s + "_elbow", _s + "_wrist"), (_S + "ForeArm", _S + "Hand"), "z"),
        (_s + "_wrist", _S + "Hand", (_s + "_wrist", _s + "_middlea"), (_S + "Hand", _S + "HandMiddle1"), "knuckles"),
        (_s + "_upper_leg", _S + "Leg", (_s + "_upper_leg", _s + "_knee"), (_S + "Leg", _S + "Shin"), "z"),
        (_s + "_knee", _S + "Shin", (_s + "_knee", _s + "_ankle"), (_S + "Shin", _S + "Foot"), "z"),
        (_s + "_ankle", _S + "Foot", (_s + "_ankle", _s + "_ball"), (_S + "Foot", _S + "ToeBase"), "x"),
        (_s + "_ball", _S + "ToeBase", (_s + "_ankle", _s + "_ball"), (_S + "Foot", _S + "ToeBase"), "x"),
    ]

## The clips: their BVH, span [first, last] (BVH frames), moments (BVH frames), words, edits. `cap`: [side, ankle height
## cap (m), frames the cap comes in over [a, b], holds, goes out over [c, d]]. `air`: [takeoff, last]: the lift taken off
## after takeoff. `spin`: [first, last]: the heading made a whole turn more than at first by the last frame.
CLIPS = {
    # Fire's Kick (the floor wave): Muay Thai's roundhouse, brought down to the shin (a leg kick: the Kick's tell stays low)
    "fire_kick_low": {"src": "muay_thai_roundhouse", "span": [56, 106], "hold": 70, "strike": 76, "back": 88,
                      "meta": {"hand": "foot_r", "mask": "full", "root": "place", "legs_always": 1.0},
                      "cap": ["r", 0.34, [68, 73], [88, 96]], "mirror": True},
    # Fire's High Kick: Taekwondo's high roundhouse (dollyeo chagi to the head)
    "fire_kick_high": {"src": "tkd_roundhouse_high", "span": [12, 56], "hold": 24, "strike": 30, "back": 36,
                       "meta": {"hand": "foot_r", "mask": "full", "root": "place"}, "mirror": True},
    # Fire's Kick held to grow it: Muay Thai's teep (the push kick), brought down to the belly
    "fire_teep": {"src": "muay_thai_teep", "span": [2, 52], "hold": 17, "strike": 28, "back": 36,
                  "meta": {"hand": "foot_r", "mask": "full", "root": "place", "legs_always": 1.0},
                  "cap": ["r", 0.78, [19, 23], [31, 38]], "mirror": True},
    # Air's Leap: Taekwondo's jumping spinning kick, cut before the landing (the game's jump and glide carry the body)
    "air_jump_spin_kick": {"src": "tkd_jump_spinning_kick", "span": [34, 72], "hold": 46, "strike": 54, "back": 66,
                           "meta": {"hand": "both", "mask": "full", "root": False, "legs_always": 1.0},
                           "air": [54, 72], "spin": [46, 72]},
}

NAMES = {"fire_kick_low": "motifect-fire-kick-low", "fire_kick_high": "motifect-fire-kick-high", "fire_teep": "motifect-fire-teep",
         "air_jump_spin_kick": "motifect-air-jump-spin-kick"}


# ---------------------------------------------------------------- the BVH (read as text: data only)
def parse(path):
    lines = open(path).read().split("\n")
    joints = []           # [name, parent index, offset Vector (cm), channels]
    stack = []
    cur = -1
    i = 0
    while i < len(lines):
        t = lines[i].strip().split()
        if not t:
            i += 1
            continue
        if t[0] in ("ROOT", "JOINT"):
            joints.append([t[1], stack[-1] if stack else -1, Vector(), []])
            cur = len(joints) - 1
        elif t[0] == "End":
            joints.append(["_end%d" % len(joints), stack[-1], Vector(), []])
            cur = len(joints) - 1
        elif t[0] == "{":
            stack.append(cur)
        elif t[0] == "}":
            stack.pop()
        elif t[0] == "OFFSET":
            joints[stack[-1]][2] = Vector([float(x) for x in t[1:4]])
        elif t[0] == "CHANNELS":
            joints[stack[-1]][3] = t[2:]
        elif t[0] == "MOTION":
            break
        i += 1
    n = int(lines[i + 1].split()[1])
    frames = [[float(x) for x in lines[i + 3 + k].split()] for k in range(n)]
    return joints, frames


def fk(joints, row):
    """{name: (position m, global rotation Matrix)} of one frame (`row` None: the rest)."""
    out = {}
    pos, rot = [], []
    c = 0
    for name, par, off, ch in joints:
        r = Matrix.Identity(3)
        t = off.copy()
        for chn in ch:
            v = row[c] if row is not None else 0.0
            c += 1
            if chn.endswith("position"):
                t["XYZ".index(chn[0])] = v
            else:
                r = r @ Matrix.Rotation(math.radians(v), 3, chn[0])
        if par < 0:
            p = t * 0.01
            g = r
        else:
            p = pos[par] + rot[par] @ (t * 0.01)
            g = rot[par] @ r
        pos.append(p)
        rot.append(g)
        out[name] = (p, g)
    return out


MIRROR_M = Matrix(((-1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)))


def mirrored(frame):
    """A frame's joints mirrored left for right (x -> -x, Left <-> Right)."""
    out = {}
    for name, (p, g) in frame.items():
        other = name.replace("Left", "\0").replace("Right", "Left").replace("\0", "Right")
        out[other] = (MIRROR_M @ p, MIRROR_M @ g @ MIRROR_M)
    return out


# ---------------------------------------------------------------- the rest frames
def _basis(d, s):
    d = d.normalized()
    s = (s - d * s.dot(d)).normalized()
    return Matrix((d, s, d.cross(s))).transposed()


def _second(kind, ours, P, names):
    if kind == "x":
        return Vector((1, 0, 0))
    if kind == "z":
        return Vector((0, 0, 1))
    if kind == "hips":
        return (P[names[0]] - P[names[1]])
    if kind == "knuckles":
        return P[names[0]] - P[names[1]]
    return Vector((1, 0, 0))


def rest_frames(bvh_rest):
    """Per mapped bone: our rest frame F_o and the BVH rest's F_m (world)."""
    P_o = bc.P_REST
    P_m = {k: v[0] for k, v in bvh_rest.items()}
    out = {}
    for ours, theirs, od, md, sec in MAP:
        side = ours[:2] if ours[:2] in ("l_", "r_") else ""
        S = "Left" if side == "l_" else "Right"
        d_o = Vector((0, 1, 0)) if od == "up" else (P_o[od[1]] - P_o[od[0]])
        d_m = Vector((0, 1, 0)) if md == "up" else (P_m[md[1]] - P_m[md[0]])
        if sec == "hips":
            s_o, s_m = P_o["l_upper_leg"] - P_o["r_upper_leg"], P_m["LeftLeg"] - P_m["RightLeg"]
        elif sec == "knuckles":
            s_o = P_o[side + "indexa"] - P_o[side + "pinkya"]
            s_m = P_m[S + "HandIndex1"] - P_m[S + "HandPinky1"]
        else:
            s_o = s_m = Vector((1, 0, 0)) if sec == "x" else Vector((0, 0, 1))
        out[ours] = (_basis(d_o, s_o), _basis(d_m, s_m), theirs)
    return out


# ---------------------------------------------------------------- the retarget
def leg_len_o():
    P = bc.P_REST
    return (P["l_knee"] - P["l_upper_leg"]).length + (P["l_ankle"] - P["l_knee"]).length


def leg_len_m(rest):
    return (rest["LeftShin"][0] - rest["LeftLeg"][0]).length + (rest["LeftFoot"][0] - rest["LeftShin"][0]).length


def fists():
    """The finger bones' local rotations of a closed fist (style_kit's boxing hands at grip 1)."""
    kit.hands()
    rots, _ = bc.pose({"length": 1, "grip_r": [(0, 1.0)], "grip_l": [(0, 1.0)]}, 0)
    out = {}
    for s in "lr":
        for dg, js in bc.CURL.items():
            for j in js:
                nm = "%s_%s%s" % (s, dg, j)
                if nm in rots:
                    out[nm] = rots[nm].copy()
    return out


def retarget(frame, frames_rest, scale, hips_ref, fist):
    """Our bones' local rotations and the root's place for one BVH frame (`frame`: name -> (pos, rot))."""
    G = {}
    for ours, (F_o, F_m, theirs) in frames_rest.items():
        R = frame[theirs][1]
        A = F_m @ F_o.transposed()
        G[ours] = (R @ A).to_quaternion() @ SK.grest[ours]
    G["spinec"] = G["spineb"].slerp(G["spined"], 0.5)
    rots = {}
    Gall = {}
    for nm in SK.order:
        par = SK.parent.get(nm)
        gp = Gall[par] if par is not None else Quaternion()
        if nm in G:
            rots[nm] = gp.inverted() @ G[nm]
        elif nm in fist:
            rots[nm] = fist[nm].copy()
        else:
            rots[nm] = SK.rest_q[nm].copy()
        Gall[nm] = gp @ rots[nm]
    h = frame["Hips"][0]
    root = bc.ROOT_REST + (h - hips_ref) * scale
    return rots, root


def cap_leg(rots, root, side, cap_y, w):
    """The `side` leg swung down about its hip (its knee and foot as they are) so its ankle is no higher than `cap_y` m, by
    `w` (0..1)."""
    if w <= 0.0:
        return
    P, G = SK.fk(rots, root)
    hip, ankle = P[side + "_upper_leg"], P[side + "_ankle"]
    if ankle.y <= cap_y:
        return
    want_y = ankle.y + (cap_y - ankle.y) * w
    v = ankle - hip
    flat = Vector((v.x, 0.0, v.z))
    dy = max(min(want_y - hip.y, v.length * 0.999), -v.length * 0.999)
    fl = math.sqrt(max(v.length ** 2 - dy * dy, 0.0))
    v2 = (flat.normalized() if flat.length > 1e-4 else Vector((0, 0, 1))) * fl + Vector((0.0, dy, 0.0))
    q = v.rotation_difference(v2)
    nm = side + "_upper_leg"
    gpar = G[SK.parent[nm]]
    rots[nm] = gpar.inverted() @ (q @ G[nm])


def _win(f, a, b, c, d):
    """0 before a, up to 1 by b, 1 to c, down to 0 by d (smooth)."""
    if f <= a or f >= d:
        return 0.0
    if f < b:
        return bc.smooth((f - a) / max(b - a, 1e-6))
    if f <= c:
        return 1.0
    return 1.0 - bc.smooth((f - c) / max(d - c, 1e-6))


def lowest(rots, root):
    P, _ = SK.fk(rots, root)
    return min(P[s + "_" + b].y for s in "lr" for b in ("ankle", "ball", "heel"))


def heading(rots, root):
    P, _ = SK.fk(rots, root)
    d = P["l_upper_leg"] - P["r_upper_leg"]
    return math.atan2(d.x, d.z)


def bake_clip(key, spec, bvh_dir, mirror, fist, report):
    joints, rows = parse(os.path.join(bvh_dir, spec["src"] + ".bvh"))
    rest = fk(joints, None)
    if mirror:
        rest = mirrored(rest)
    frames_rest = rest_frames(rest)
    scale = leg_len_o() / max(leg_len_m(rest), 1e-6)
    # the BVH hips' height standing at its rest (the lowest foot point on the deck)
    floor_m = min(rest[n][0].y for n in rest if "Foot" in n or "ToeBase" in n)
    a, b = spec["span"]
    first = fk(joints, rows[a])
    if mirror:
        first = mirrored(first)
    # (the hips' height over the deck at the BVH's rest, standing: its feet's lowest point below the hips there; the motion's
    # deck is at 0)
    hips_ref = Vector((first["Hips"][0].x, rest["Hips"][0].y - floor_m, first["Hips"][0].z))
    out_rots, out_roots = [], []
    for f in range(a, b + 1):
        fr = fk(joints, rows[f])
        if mirror:
            fr = mirrored(fr)
        rots, root = retarget(fr, frames_rest, scale, hips_ref, fist)
        out_rots.append(rots)
        out_roots.append(root)
    n = len(out_roots)
    # set down: the first frame's lowest foot point on the deck as our rest's
    drop = lowest(out_rots[0], out_roots[0]) - lowest(dict(bc.REST), bc.ROOT_REST)
    # the drift across the deck taken back by the end (a cast in place: it ends where it began)
    d_end = Vector((out_roots[-1].x - out_roots[0].x, 0.0, out_roots[-1].z - out_roots[0].z))
    for i in range(n):
        t = bc.smooth(i / max(n - 1, 1))
        out_roots[i] = out_roots[i] - Vector((0.0, drop, 0.0)) - d_end * t
    x0 = Vector((out_roots[0].x - bc.ROOT_REST.x, 0.0, out_roots[0].z - bc.ROOT_REST.z))
    for i in range(n):
        out_roots[i] = out_roots[i] - x0
    if "cap" in spec:
        # (the kicking leg brought down, on the clip as it stands on the deck)
        side, cap_y, (c0, c1), (c2, c3) = spec["cap"]
        if mirror:
            side = "l" if side == "r" else "r"
        for i in range(n):
            cap_leg(out_rots[i], out_roots[i], side, cap_y, _win(a + i, c0, c1, c2, c3))
    if "air" in spec:
        # (airborne from its takeoff: its lift off the deck taken off, the game's jump carries the body; its crouches kept)
        t0, t1 = spec["air"]
        stand = bc.ROOT_REST.y - drop * 0.0
        for i in range(n):
            f = a + i
            if f >= t0:
                k = bc.smooth(min((f - t0) / 3.0, 1.0))
                if out_roots[i].y > stand:
                    out_roots[i].y = out_roots[i].y + (stand - out_roots[i].y) * k
            out_roots[i].x = bc.ROOT_REST.x
            out_roots[i].z = bc.ROOT_REST.z
    if "spin" in spec:
        # (the heading made whole: by its last frame a full turn more than at its first, the turn short of it spread over the
        # spin, about the root's upright)
        s0, s1 = spec["spin"]
        h0 = heading(out_rots[s0 - a], out_roots[s0 - a])
        total = 0.0
        prev = h0
        for i in range(s0 - a + 1, s1 - a + 1):
            h = heading(out_rots[i], out_roots[i])
            dh = (h - prev + math.pi) % (2.0 * math.pi) - math.pi
            total += dh
            prev = h
        want = 2.0 * math.pi * (1.0 if total >= 0.0 else -1.0)
        short = want - total
        for i in range(s0 - a, n):
            k = bc.smooth(min(max((a + i - s0) / max(s1 - s0, 1), 0.0), 1.0))
            q = Quaternion(Vector((0, 1, 0)), short * k)
            out_rots[i]["root"] = q @ out_rots[i]["root"]
        if report:
            print("  SPIN %s turned %.0f deg, made %.0f" % (key, math.degrees(total), math.degrees(want)))
    names = bc.keyed()
    frames = [{nm: [r[nm].x, r[nm].y, r[nm].z, r[nm].w] for nm in names} for r in out_rots]
    roots = [[p.x, p.y, p.z] for p in out_roots]
    meta = dict(spec["meta"])
    if mirror and isinstance(meta.get("hand"), str):
        meta["hand"] = {"foot_r": "foot_l", "foot_l": "foot_r", "r": "l", "l": "r"}.get(meta["hand"], meta["hand"])
    meta["hold_s"] = (spec["hold"] - a) / FPS
    meta["strike_s"] = (spec["strike"] - a) / FPS
    meta["back_s"] = (spec["back"] - a) / FPS
    meta["length_frames"] = n - 1
    meta["source"] = "Motifect martial arts pack (AI-generated BVH, licensed for commercial use): %s.bvh frames %d-%d%s" % (
        spec["src"], a, b, ", mirrored" if mirror else "")
    if report:
        for i in range(0, n, 3):
            P, _ = SK.fk(out_rots[i], out_roots[i])
            print("  %s f%02d root %s  r_ankle %s  l_ankle %s  heading %.0f" % (
                key + ("_l" if mirror else ""), i, [round(x, 3) for x in out_roots[i]], [round(x, 3) for x in P["r_ankle"]],
                [round(x, 3) for x in P["l_ankle"]], math.degrees(heading(out_rots[i], out_roots[i]))))
    return {"frames": frames, "root": roots, "meta": meta}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--bvh-dir", default=DEFAULT_DIR)
    ap.add_argument("--clips", default="")
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args(argv)
    only = [c for c in a.clips.split(",") if c]
    fist = fists()
    out = {"fps": FPS, "clips": {}, "names": {},
           "about": "tools/anim_author/blender/motifect_clips.py: chosen Motifect moves retargeted onto Actor_B's rig and cut to "
                    "the cast shape (animations/SOURCE.md, Motifect-derived clips)"}
    for key, spec in CLIPS.items():
        if only and key not in only:
            continue
        for mirror in ([False, True] if spec.get("mirror") else [False]):
            k = key + ("_l" if mirror else "")
            out["clips"][k] = bake_clip(k, spec, a.bvh_dir, mirror, fist, a.report)
            out["names"][k] = NAMES[key] + ("-l" if mirror else "")
            print("MOTIFECT %s -> %s: %d frames" % (k, out["names"][k], len(out["clips"][k]["frames"])))
    json.dump(out, open(a.out, "w"))
    print("MOTIFECT baked %d clips -> %s" % (len(out["clips"]), a.out))


main()
