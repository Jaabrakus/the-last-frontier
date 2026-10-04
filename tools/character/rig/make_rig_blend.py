"""The Actor_B rig .blend the character generators run on, built from actor_b_skeleton.json:
an armature with every bone in the rig's order at its bind pose (the rest = null-add) and the
bind clip null-add (every bone at its rest), so lib/rig.py reads the same bind pose as from the
rig library (Actor_B_001.blend + Actor_B_021.blend's null-add).

    Blender -b --python tools/character/rig/make_rig_blend.py -- out.blend [skeleton.json]
"""

import json
import os
import sys

import bpy
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
# Godot (Y up) -> Blender (Z up): the inverse of lib/rig.py C_GODOT (bone axes not remapped)
C_INV = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
BIND_ACTION = "null-add"


def main(out, skel=os.path.join(HERE, "actor_b_skeleton.json")):
    rec = json.load(open(skel))
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    arm = bpy.data.armatures.new("Actor_B_rig")
    rig = bpy.data.objects.new("Actor_B_rig", arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    G = {}
    for b in rec["bones"]:
        r = b["rest"]
        G[b["name"]] = C_INV @ Matrix((r[0:4], r[4:8], r[8:12], (0, 0, 0, 1)))
    kids = {}
    for b in rec["bones"]:
        kids.setdefault(b["parent"], []).append(b["name"])
    bpy.ops.object.mode_set(mode="EDIT")
    ebs = {}
    for b in rec["bones"]:                 # parents first: the rig's order kept (depth first, children in order)
        n = b["name"]
        eb = arm.edit_bones.new(n)
        L = 0.03
        if kids.get(n):
            L = min(max((G[kids[n][0]].translation - G[n].translation).length, 0.01), 0.15)
        eb.head, eb.tail = (0, 0, 0), (0, L, 0)
        eb.matrix = G[n]
        eb.use_connect = False
        if b["parent"]:
            eb.parent = ebs[b["parent"]]
        ebs[n] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    order = [b.name for b in arm.bones]
    want = [b["name"] for b in rec["bones"]]
    assert order == want, "bone order differs from the skeleton record"
    err = max((arm.bones[n].matrix_local.translation - G[n].translation).length for n in G)
    rot = max(arm.bones[n].matrix_local.to_quaternion().rotation_difference(G[n].to_quaternion()).angle for n in G)
    # the bind clip: every bone at its rest
    rig.animation_data_create()
    act = bpy.data.actions.new(BIND_ACTION)
    act.use_fake_user = True
    rig.animation_data.action = act
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
        for p in ("location", "rotation_quaternion", "scale"):
            pb.keyframe_insert(p, frame=1)
    rig.animation_data.action = None
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out))
    print("rig: %d bones, rest vs record max %.2e m / %.2e rad -> %s" % (len(order), err, rot, out))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main(*argv[:2])
