"""The owner's hand edits back into the game: reads every action of a .blend that tools/anim_author/blender/bend_clips.py kept
(--blend: an Actor_B rig with one action a clip, named as the CLIPS keys) after it has been opened and refined in Blender, and
writes the same json bend_clips.py writes (each keyed bone's local rotation as Godot has it, rigmap.RigMap.to_godot, and the
root's position), for tools/anim_author/install_bend.gd. The metas (strike_s, hold_s, ...) are the CLIPS table's for a clip of
that name (an action of another name gets none: add its row to CLIPS first). The pattern of forage_grab.py's bake. Reads only
the given .blend (no library, no dumped move).

  Blender -b <bend.blend> --python tools/anim_author/blender/bake_blend.py -- --out <bend.json> [--actions earth_stomp,...]
  (in this project through the lock: zsh <scratchpad>/blender_run.sh -b <bend.blend> --python ...)
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bend_clips  # noqa: E402  (sets rigmap to this checkout's rig)
import rigmap  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--actions", default="")
    ap.add_argument("--glb", default=None)
    a = ap.parse_args(argv)
    only = [x for x in a.actions.split(",") if x]
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rm = rigmap.RigMap(arm)
    scn = bpy.context.scene
    names = bend_clips.keyed()
    table = bend_clips.all_clips()
    C = Matrix.Rotation(math.pi / 2, 3, "X")
    out = {"fps": bend_clips.FPS, "clips": {}, "names": {},
           "about": "tools/anim_author/blender/bake_blend.py: bend_clips.py's clips as refined by hand in Blender"}
    if arm.animation_data is None:
        arm.animation_data_create()
    for act in bpy.data.actions:
        if only and act.name not in only:
            continue
        arm.animation_data.action = act
        f0, f1 = (int(round(x)) for x in act.frame_range)
        frames, roots = [], []
        for f in range(f0, f1 + 1):
            scn.frame_set(f)
            bpy.context.view_layer.update()
            rots = {}
            for nm in names:
                pb = arm.pose.bones.get(nm)
                if pb is None or nm not in rm.B:
                    continue
                m = pb.matrix if pb.parent is None else pb.parent.matrix.inverted() @ pb.matrix
                lr = pb.bone.matrix_local if pb.parent is None else pb.parent.bone.matrix_local.inverted() @ pb.bone.matrix_local
                rots[nm] = rm.to_godot(nm, (lr.inverted() @ m).to_quaternion())
            frames.append(rots)
            rb = arm.pose.bones.get("root")
            h = rb.bone.matrix_local.to_3x3() @ rb.location + rb.bone.head_local
            r = C.inverted() @ Vector(h)
            roots.append([r.x, r.y, r.z])
        meta = dict(table.get(act.name, {}).get("meta", {}))
        out["clips"][act.name] = {"frames": frames, "root": roots, "meta": meta}
        out["names"][act.name] = bend_clips.game_name(act.name)
        print("BAKE %s: %d frames (metas %s)" % (act.name, len(frames), sorted(meta)))
    json.dump(out, open(a.out, "w"))
    print("BAKE %d clips -> %s" % (len(out["clips"]), a.out))


if __name__ == "__main__":
    main()
