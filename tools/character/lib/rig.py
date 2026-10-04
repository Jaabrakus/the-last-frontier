"""Actor_B rig: the bind pose null-add, joint positions (Skel), the export rig
whose rest IS null-add (all 291 bones in rig order), Godot space conversions and
glb export.

Split out of tools/character/build_body.py (lib v1). export_glb() gained optional
texcoords / morph arguments; with the defaults it exports exactly as before.
"""

import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

from .remesh import link
from .sdf import mirror_x

HERE = os.path.dirname(os.path.abspath(__file__))
CHARACTER_TOOLS = os.path.normpath(os.path.join(HERE, ".."))
FRONTIER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
PROJECT = os.path.expanduser(os.environ.get("ANIMATION_SOURCE_ROOT", ""))
LIBS = os.path.join(PROJECT, "blender_libraries")
SOURCE_RIG_FILE = os.path.join(LIBS, "Actor_B_001.blend")
BIND_LIB = os.path.join(LIBS, "Actor_B_021.blend")
# The rig rebuilt from tools/character/rig/actor_b_skeleton.json (make_rig_blend.py: the same bones, order and bind
# pose, null-add in the same file); build_character.sh sets it when ACTOR_B_BLEND is not given.
RIG_BLEND = os.environ.get("ACTOR_B_RIG_BLEND", "")
if RIG_BLEND and not PROJECT:
    BIND_LIB = RIG_BLEND
BIND_ACTION = "null-add"
PROVENANCE_RIG = "Skeleton, bone names and bind pose: Actor_B rig."

# ===========================================================================
# Rig: bind pose (null-add) and joint positions
# ===========================================================================
def load_actions(path, names):
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        have = [n for n in names if n in src.actions]
        dst.actions = list(have)       # (Blender replaces the list items with the loaded IDs)
    return [n for n in names if n not in have]


def set_action(rig, act_name, frame=None, base=None):
    """Evaluate an action on the rig. Unkeyed channels keep `base` (dict name ->
    (loc, quat, scale)) or the rest (identity)."""
    for pb in rig.pose.bones:
        if base is not None and pb.name in base:
            loc, rot, scl = base[pb.name]
        else:
            loc, rot, scl = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
        pb.rotation_mode = "QUATERNION"
        pb.location, pb.rotation_quaternion, pb.scale = loc, rot, scl
    if rig.animation_data is None:
        rig.animation_data_create()
    act = bpy.data.actions[act_name]
    rig.animation_data.action = act
    if getattr(act, "slots", None) and len(act.slots):
        rig.animation_data.action_slot = act.slots[0]
    f = int(act.frame_range[0]) if frame is None else int(frame)
    bpy.context.scene.frame_set(f)
    bpy.context.view_layer.update()


def clear_action(rig):
    if rig.animation_data:
        rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
    bpy.context.view_layer.update()


def bind_pose(rig):
    """Globals (Blender armature space, orthonormal) and local channels of null-add."""
    set_action(rig, BIND_ACTION)
    G, base = {}, {}
    for pb in rig.pose.bones:
        m = rig.matrix_world @ pb.matrix
        loc, rot, scl = m.decompose()
        G[pb.name] = Matrix.LocRotScale(loc, rot, None)
        base[pb.name] = (tuple(pb.location), tuple(pb.rotation_quaternion), tuple(pb.scale))
    clear_action(rig)
    return G, base


class Skel:
    """Joint positions (numpy, Blender space) with left/right helpers.
    Right-side shapes use the mirrored LEFT joints so the mesh is symmetric
    (the rig is symmetric to < 1 mm)."""

    def __init__(self, G):
        self.G = G
        self.P = {n: np.array(m.translation, float) for n, m in G.items()}

    def __getitem__(self, name):
        return self.P[name]

    def side(self, name, s):
        p = self.P["l_" + name]
        return p if s > 0 else mirror_x(p)


# ===========================================================================
# Export rig (rest pose = null-add bind pose) and glTF
# ===========================================================================
def build_bind_rig(src_rig, G, name="Actor_B"):
    arm = bpy.data.armatures.new(name + "_bind")
    rig = link(bpy.data.objects.new(name, arm))
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.view_layer.objects:
        o.select_set(o is rig)
    bpy.ops.object.mode_set(mode="EDIT")
    ebs = {}
    for b in src_rig.data.bones:          # parents come before children
        eb = arm.edit_bones.new(b.name)
        kids = [c for c in b.children]
        L = 0.03
        if kids:
            L = float(np.clip((G[kids[0].name].translation - G[b.name].translation).length, 0.01, 0.15))
        eb.head = (0, 0, 0)
        eb.tail = (0, L, 0)
        eb.matrix = G[b.name]
        eb.use_connect = False
        eb.use_deform = False
        if b.parent is not None:
            eb.parent = ebs[b.parent.name]
        ebs[b.name] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    err = max((rig.data.bones[n].matrix_local.translation - G[n].translation).length for n in G)
    def ang(q):
        a = q.angle
        return math.degrees(min(a, 2 * math.pi - a))
    rot = max(ang(rig.data.bones[n].matrix_local.to_quaternion().rotation_difference(G[n].to_quaternion())) for n in G)
    return rig, err, rot


C_GODOT = np.array([[1, 0, 0, 0], [0, 0, 1, 0], [0, -1, 0, 0], [0, 0, 0, 1]], float)


def godot_xf(m):
    """Blender 4x4 -> Godot (Y up) 4x4: G_godot = C * G_blender (bone axes not remapped)."""
    return C_GODOT @ np.array(m, float)


def xf12(m):
    """Godot Transform3D as 12 floats: basis columns x, y, z, then origin."""
    return [float(m[r][c]) for c in range(3) for r in range(3)] + [float(m[r][3]) for r in range(3)]


def export_glb(rig, objs, path, texcoords=False, morph=False, vertex_color=True):
    """glb with the armature `rig` (all its bones, rest = null-add) and the skinned `objs`.
    texcoords: export every UV map (TEXCOORD_0.. in layer order; Godot imports 0 -> UV,
    1 -> UV2, 2 -> CUSTOM0). morph: export shape keys (with normals) as morph targets.
    The exporter writes V as 1 - v, and Godot does not flip it back."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for o in bpy.context.view_layer.objects:
        o.select_set(o is rig or o in objs)
    bpy.context.view_layer.objects.active = rig
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
              export_skins=True, export_influence_nb=4, export_all_influences=False, export_def_bones=False,
              export_animations=False, export_morph=morph, export_morph_normal=morph, export_morph_tangent=False,
              export_materials="EXPORT", export_normals=True,
              export_extras=True, export_rest_position_armature=True, export_leaf_bone=False,
              export_texcoords=texcoords, export_cameras=False, export_lights=False,
              export_vertex_color="NAME" if vertex_color else "NONE", export_vertex_color_name="Color",
              export_all_vertex_colors=False,
              export_active_vertex_color_when_no_material=False)
    props = {p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
    bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props})


def guard_source():
    if RIG_BLEND and not PROJECT:
        return
    if not PROJECT:
        raise SystemExit("Set ANIMATION_SOURCE_ROOT to the external animation source before rebuilding")
    cur = os.path.realpath(bpy.data.filepath) if bpy.data.filepath else ""
    if not cur:
        raise SystemExit("open a COPY of Actor_B_001.blend (Blender -b copy.blend --python build_body.py)")
    if cur == os.path.realpath(SOURCE_RIG_FILE) or cur.startswith(os.path.realpath(PROJECT) + os.sep):
        raise SystemExit("refusing to run on a file inside external animation source; open a copy instead")


def g2b(p):
    """Godot skeleton space (x, y up, z forward) -> Blender armature space."""
    return Vector((p[0], -p[2], p[1]))
