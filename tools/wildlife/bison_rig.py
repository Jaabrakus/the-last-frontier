"""The bison made a living animal (user 2026-09-28: "bison behavior in the open plains a lot of them", "we have a bison
model"): Poly by Google's Bison mesh (CC-BY 3.0: assets/wildlife/polypizza/SOURCE.md; a still mesh, not rigged) put on
Quaternius's stag armature (CC0: assets/wildlife/quaternius/SOURCE.md) and moved by the stag's clips, written as one glTF.

    Blender -b --python tools/wildlife/bison_rig.py -- <project dir> <out.glb>

The stag's bones are points (a few thousandths of a unit long, pointing where they will), so each joint can be moved to
the bison's anatomy without turning any bone: the stag's clips (rotations about each bone's own axes) then move the
bison as they move the stag. The joints are placed from the two bodies' landmarks, each measured off its mesh:
    the spine and shoulders   along the body between the hind and the fore legs, at the same share of the body's depth
                              (belly to back, per slice) as on the stag
    the legs                  down the bison's leg columns (their centre where the joint's height cuts them), at the
                              same share of the leg's height (hoof to belly) as on the stag
    the neck and head         from the top of the chest forward and down to the head (a bison carries it low, before the
                              hump), the head's joint in the middle of the skull
    the tail                  from the top of the rump back and down
    the leg IK and its poles  with their hooves (they are not weighted: the clips' leg rotations are baked)
The clips' moves (the body's bounce, the shoulders' shift) are scaled with the animal's size. The mesh is weighted to the
anatomical bones by distance to each bone's reach (its joint to the next joint on), the legs' flesh only to that leg's
bones and the body's only to the trunk's, neck's, head's, tail's and the legs' tops. Everything in metres: the bison
about 1.9 m at the hump, 2.8 m long, facing the stag's way (-Y here: +Z in the glTF, as the game's animals).
"""

import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PROJECT = args[0] if args else "."
OUT = args[1] if len(args) > 1 else PROJECT + "/assets/wildlife/bison/bison.glb"
STAG = PROJECT + "/assets/wildlife/quaternius/stag.glb"
BISON = PROJECT + "/assets/wildlife/polypizza/bison.glb"
# the bison mesh's units to metres (about 1.9 m at the hump; scripts/climb/climb_yard.gd BISON_SCALE)
BISON_SCALE = 0.135
LEGS = {
    "Front.L": ["FrontShoulder.L", "FrontUpperLeg.L", "FrontLowerLeg.L"],
    "Front.R": ["FrontShoulder.R", "FrontUpperLeg.R", "FrontLowerLeg.R"],
    "Back.L": ["BackShoulder.L", "BackLeg.L", "BackUpperLeg.L", "BackLowerLeg.L"],
    "Back.R": ["BackShoulder.R", "BackLeg.R", "BackUpperLeg.R", "BackLowerLeg.R"],
}
# each leg's IK (the hoof's target and its toe) and its knee's pole
LEG_IK = {
    "Front.L": ["IKFrontLeg.L", "FF.L", "PoleTarget.L"],
    "Front.R": ["IKFrontLeg.R", "FF.R", "PoleTarget.R"],
    "Back.L": ["IKBackLeg.L", "FFB.L", "PoleTargetBack.L"],
    "Back.R": ["IKBackLeg.R", "FFB.R", "PoleTargetBack.R"],
}
SPINE = ["Body", "Back", "Torso", "Torso2", "Torso3"]
NECK = ["Neck1", "Neck2", "Neck3", "Head"]
TAIL = ["Tail1", "Tail2", "Tail3"]


def world_verts(ob):
    return [ob.matrix_world @ v.co for v in ob.data.vertices]


class Body:
    """A four-legged body's landmarks, measured off its mesh's vertices (Z up, facing -Y)."""

    def __init__(self, vs):
        self.vs = vs
        self.y0 = min(v.y for v in vs)          # the nose
        self.y1 = max(v.y for v in vs)          # the rump
        self.h = max(v.z for v in vs)
        self.w = max(abs(v.x) for v in vs)
        mid = [v for v in vs if abs(v.x) < self.w * 0.25]
        # the belly: the lowest of the middle's flesh between the legs
        low = [v for v in vs if v.z < self.h * 0.12]
        self.fore_y = sum(v.y for v in low if v.y < (self.y0 + self.y1) * 0.5) / max(1, len([v for v in low if v.y < (self.y0 + self.y1) * 0.5]))
        self.hind_y = sum(v.y for v in low if v.y >= (self.y0 + self.y1) * 0.5) / max(1, len([v for v in low if v.y >= (self.y0 + self.y1) * 0.5]))
        between = [v for v in mid if self.fore_y + 0.25 * (self.hind_y - self.fore_y) < v.y < self.hind_y - 0.25 * (self.hind_y - self.fore_y)]
        self.belly = min(v.z for v in between) if between else self.h * 0.5
        self.mid = mid

    def top(self, y):
        """The back's height at `y` (the highest flesh of a slice about it)."""
        d = (self.y1 - self.y0) * 0.04
        s = [v.z for v in self.vs if abs(v.y - y) < d]
        return max(s) if s else self.h

    def under(self, y):
        """The underside's height at `y` along the middle (between the legs: the belly; before them the chest, the
        throat)."""
        d = (self.y1 - self.y0) * 0.04
        s = [v.z for v in self.mid if abs(v.y - y) < d and v.z > self.h * 0.12]
        return min(s) if s else self.belly

    def leg_centre(self, side, front, z):
        """The middle of a leg's column where the height `z` cuts it (side +1 left: +X; front: the fore leg)."""
        dz = self.h * 0.05
        cut = (self.fore_y + self.hind_y) * 0.5
        s = [v for v in self.vs if abs(v.z - z) < dz and v.x * side > self.w * 0.12
             and ((v.y < cut) if front else (v.y >= cut))]
        if not s:
            return None
        return Vector((sum(v.x for v in s) / len(s), sum(v.y for v in s) / len(s), z))


def along(y, a0, a1, b0, b1):
    """`y` on the stretch a0..a1 to its place on b0..b1."""
    return b0 + (y - a0) / (a1 - a0) * (b1 - b0)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # --- the stag: its armature, its clips, its body's landmarks
    bpy.ops.import_scene.gltf(filepath=STAG)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    stag = bpy.data.objects["Stag"]
    S = Body(world_verts(stag))
    sm = arm.matrix_world.copy()
    heads = {b.name: sm @ b.head_local for b in arm.data.bones}
    tails = {b.name: sm @ b.tail_local for b in arm.data.bones}
    world_scale = arm.matrix_world.to_scale().x
    for o in list(bpy.data.objects):
        if o != arm:
            bpy.data.objects.remove(o, do_unlink=True)
    # --- the bison, in metres
    bpy.ops.import_scene.gltf(filepath=BISON)
    bison = next(o for o in bpy.data.objects if o.type == 'MESH')
    bison.parent = None
    bison.matrix_world = bison.matrix_world.copy()
    bison.scale = bison.scale * BISON_SCALE
    bpy.context.view_layer.objects.active = bison
    for o in bpy.context.view_layer.objects:
        o.select_set(o == bison)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    B = Body(world_verts(bison))
    k = ((B.hind_y - B.fore_y) / (S.hind_y - S.fore_y) + B.h / S.h) * 0.5      # the stag to the bison, about
    print("BISON RIG stag h %.2f fore %.2f hind %.2f belly %.2f | bison h %.2f fore %.2f hind %.2f belly %.2f | k %.3f"
          % (S.h, S.fore_y, S.hind_y, S.belly, B.h, B.fore_y, B.hind_y, B.belly, k))

    def body_point(p):
        """A point of the stag's trunk to the bison's: along between the legs, at the same share of the depth."""
        y = along(p.y, S.fore_y, S.hind_y, B.fore_y, B.hind_y)
        su, st = S.under(p.y), S.top(p.y)
        bu, bt = B.under(y), B.top(y)
        f = (p.z - su) / max(st - su, 1e-4)
        return Vector((p.x * B.w / S.w, y, bu + f * (bt - bu)))

    new = {}
    for n in SPINE:
        new[n] = body_point(heads[n])
    new["Body"] = Vector((0.0, along(heads["Body"].y, S.fore_y, S.hind_y, B.fore_y, B.hind_y), heads["Body"].z * k))
    # the legs: each joint at its share of the leg's height, in the bison's column there
    for leg, bones in LEGS.items():
        side = 1.0 if leg.endswith(".L") else -1.0
        front = leg.startswith("Front")
        s_top = heads[bones[0]].z
        hoof_s = heads[LEG_IK[leg][1]].z
        b_top = B.under(B.fore_y if front else B.hind_y) + (B.top(B.fore_y if front else B.hind_y)
                - B.under(B.fore_y if front else B.hind_y)) * ((s_top - S.under(S.fore_y if front else S.hind_y))
                / max(S.top(S.fore_y if front else S.hind_y) - S.under(S.fore_y if front else S.hind_y), 1e-4))
        for n in bones:
            f = (heads[n].z - hoof_s) / max(s_top - hoof_s, 1e-4)
            z = f * b_top
            c = B.leg_centre(side, front, min(z, B.under(B.fore_y if front else B.hind_y) * 0.95))
            # (the stag's own offset of the joint from its leg's line, fore / aft: the hock behind, the knee)
            s_line = heads[bones[1]]
            dy = (heads[n].y - s_line.y) * k
            x = c.x if c else heads[n].x * B.w / S.w
            if n == bones[0]:
                x = heads[n].x * B.w / S.w          # the shoulder's joint inside the body
            new[n] = Vector((x, (c.y if c else along(heads[n].y, S.fore_y, S.hind_y, B.fore_y, B.hind_y)) + dy, z))
        foot = B.leg_centre(side, front, B.h * 0.03)
        ik, toe, pole = LEG_IK[leg]
        for n in (ik, toe):
            f = heads[n].z / max(s_top, 1e-4)
            new[n] = Vector((foot.x, foot.y + (heads[n].y - heads[bones[-1]].y) * k, f * b_top))
        new[pole] = new[bones[-1]] + (heads[pole] - heads[bones[-1]]) * k
    # the neck and head: from the chest's top forward and down to the skull's middle
    head_vs = [v for v in B.vs if v.y < B.fore_y - (B.fore_y - B.y0) * 0.45]
    skull = Vector((0.0, sum(v.y for v in head_vs) / len(head_vs), sum(v.z for v in head_vs) / len(head_vs)))
    chest = body_point(heads["Neck1"])
    for i, n in enumerate(NECK):
        f = i / (len(NECK) - 1)
        new[n] = chest.lerp(skull, f)
    # the tail: the rump's top, back and down
    rump = Vector((0.0, B.y1 - (B.y1 - B.hind_y) * 0.15, B.top(B.y1 - (B.y1 - B.hind_y) * 0.15) * 0.93))
    for i, n in enumerate(TAIL):
        new[n] = rump + Vector((0.0, (heads[n].y - heads["Tail1"].y) * k, (heads[n].z - heads["Tail1"].z) * k))
    missing = [b.name for b in arm.data.bones if b.name not in new]
    if missing:
        raise SystemExit("BISON RIG: no place for " + ", ".join(missing))

    # --- the armature in metres, its joints moved (each bone's own turn kept), the clips' moves scaled
    arm.parent = None
    arm.matrix_world = arm.matrix_world.Identity(4)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.view_layer.objects:
        o.select_set(o == arm)
    bpy.ops.object.mode_set(mode='EDIT')
    for eb in arm.data.edit_bones:
        roll = eb.roll
        d = (tails[eb.name] - heads[eb.name]) * k
        eb.head = new[eb.name]
        eb.tail = new[eb.name] + (d if d.length > 1e-6 else Vector((0.0, 0.0, 0.002)))
        eb.roll = roll
    bpy.ops.object.mode_set(mode='OBJECT')
    for act in list(bpy.data.actions):
        if act.name.startswith("AnimalArmature|"):
            bpy.data.actions.remove(act)
            continue
        for fc in _fcurves(act):
            if fc.data_path.endswith(".location"):
                for kp in fc.keyframe_points:
                    kp.co.y *= world_scale * k
                    kp.handle_left.y *= world_scale * k
                    kp.handle_right.y *= world_scale * k

    # --- the bison weighted to the anatomical bones
    reach = _reaches(new, B)
    for n in reach:
        bison.vertex_groups.new(name=n)
    for vi, v in enumerate(bison.data.vertices):
        p = v.co
        allowed = _allowed(p, B)
        ds = sorted(((_seg_dist(p, *reach[n]), n) for n in allowed), key=lambda t: t[0])[:2]
        ws = [1.0 / (d + 0.02) ** 4 for d, _ in ds]
        tot = sum(ws)
        for (d, n), w in zip(ds, ws):
            bison.vertex_groups[n].add([vi], w / tot, 'REPLACE')
    mod = bison.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    bison.parent = arm
    # --- out
    for o in bpy.context.view_layer.objects:
        o.select_set(o in (arm, bison))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_force_sampling=True, export_yup=True,
                              export_def_bones=False, export_optimize_animation_size=False)
    print("BISON RIG WROTE", OUT, "clips", sorted(a.name for a in bpy.data.actions))


def _fcurves(act):
    try:
        return list(act.fcurves)
    except AttributeError:
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out.extend(cb.fcurves)
        return out


def _reaches(new, B):
    """Each weighted bone's reach: from its joint to the next joint on (the hoof, the nose, the tail's tip for the
    last)."""
    r = {}
    chain = ["Back", "Torso", "Torso2", "Torso3", "Neck1", "Neck2", "Neck3", "Head"]
    for a, b in zip(chain, chain[1:]):
        r[a] = (new[a], new[b])
    r["Head"] = (new["Head"], Vector((0.0, B.y0, new["Head"].z)))
    for a, b in zip(TAIL, TAIL[1:]):
        r[a] = (new[a], new[b])
    r["Tail3"] = (new["Tail3"], new["Tail3"] + (new["Tail3"] - new["Tail2"]))
    for leg, bones in LEGS.items():
        for a, b in zip(bones, bones[1:]):
            r[a] = (new[a], new[b])
        r[bones[-1]] = (new[bones[-1]], new[LEG_IK[leg][1]])
    return r


def _allowed(p, B):
    """The bones a vertex at `p` may follow: a leg's flesh (below the belly, out to its side) only that leg's; the
    body's the trunk's, the neck's, the head's, the tail's and the legs' tops."""
    front = p.y < (B.fore_y + B.hind_y) * 0.5
    side = "L" if p.x > 0.0 else "R"
    leg = ("Front." if front else "Back.") + side
    under = B.under(B.fore_y if front else B.hind_y)
    if p.z < under * 0.92 and abs(p.x) > B.w * 0.1 and p.y > B.y0 + (B.fore_y - B.y0) * 0.5:
        return LEGS[leg][1:]
    return ["Back", "Torso", "Torso2", "Torso3", "Neck1", "Neck2", "Neck3", "Head", "Tail1", "Tail2", "Tail3",
            LEGS[leg][0], LEGS[leg][1]]


def _seg_dist(p, a, b):
    ab = b - a
    t = 0.0 if ab.length_squared < 1e-9 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


main()
