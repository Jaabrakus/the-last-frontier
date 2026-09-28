"""Sample the hand and weapon-prop bones of Actor_B long-gun clips (Blender 5.2, headless).

Used by the over-under research (Player_Animation_Project/graph_analysis/weapons/
over_under_research.md) to measure what each hand does in the reload / pump / draw clips
relative to the weapon (the musket hangs off r_hand_prop_attachment, prop +Z along the barrel,
+Y up; scripts/player/player.gd musket_offset).

Run one library file at a time, under a time limit:
  Blender -b Player_Animation_Project/blender_libraries/Actor_B_016.blend \
      --python tools/weapons/long_gun_clip_probe.py -- --out samples.jsonl <action> [<action> ...]

Every pose bone is reset to identity before an action is evaluated, so a partial clip is sampled
over the rest pose of the bones it does not key (the spine for the --part clips). Positions are
world-space metres, rotations world-space quaternions (w, x, y, z), one record per source sample
(time k / sample_rate, frame f0 + k * fps / sample_rate, as graph/bl_measure.py does).
"""

import json
import math
import sys

import bpy

BONES = ["r_hand_prop_attachment", "l_hand_prop_attachment", "l_palm", "r_palm",
         "l_wrist", "r_wrist", "l_elbow", "r_elbow", "spined", "heada"]


def _args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = None
    if "--out" in argv:
        i = argv.index("--out")
        out = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    if not out or not argv:
        raise SystemExit("usage: ... -- --out FILE.jsonl ACTION [ACTION ...]")
    return out, argv


def _keyed_bones(act):
    keyed = set()
    curves = []
    try:
        curves = list(act.fcurves)
    except Exception:
        for layer in getattr(act, "layers", []):
            for strip in layer.strips:
                for bag in strip.channelbags:
                    curves.extend(bag.fcurves)
    for fc in curves:
        if fc.data_path.startswith('pose.bones["'):
            keyed.add(fc.data_path.split('"')[1])
    return sorted(keyed)


def main():
    out, names = _args()
    obj = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    if obj.animation_data is None:
        obj.animation_data_create()
    sc = bpy.context.scene
    fps = sc.render.fps / sc.render.fps_base
    recs = []
    for name in names:
        act = bpy.data.actions.get(name)
        if act is None:
            recs.append({"action": name, "error": "action not in this library"})
            continue
        for pb in obj.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.rotation_euler = (0, 0, 0)
            pb.scale = (1, 1, 1)
        obj.animation_data.action = act
        try:
            if len(act.slots):
                obj.animation_data.action_slot = act.slots[0]
        except Exception:
            pass
        sr = float(act.get("sample_rate", 10.0))
        n = int(act.get("sample_count", 1))
        f0 = act.frame_range[0]
        frames = []
        for k in range(n):
            fr = f0 + k * fps / sr
            fi = int(math.floor(fr))
            sc.frame_set(fi, subframe=fr - fi)
            m_w = obj.matrix_world
            rec = {"t": round(k / sr, 5)}
            for b in BONES:
                m = m_w @ obj.pose.bones[b].matrix
                rec[b] = {"p": [round(x, 5) for x in m.translation],
                          "q": [round(x, 6) for x in m.to_quaternion()]}
            frames.append(rec)
        recs.append({"action": name, "library": bpy.path.basename(bpy.data.filepath),
                     "sample_rate": sr, "sample_count": n, "length_s": round((n - 1) / sr, 5),
                     "keyed_bones": _keyed_bones(act), "frames": frames})
    with open(out, "a") as fh:
        for r in recs:
            fh.write(json.dumps(r) + "\n")
    print("PROBED", len(recs))


main()
