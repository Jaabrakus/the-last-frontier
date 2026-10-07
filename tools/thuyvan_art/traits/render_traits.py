"""Render the Thủy Vân trait lineups and variant boards (inside Blender, through the shared lock wrapper only):

    BLENDER_TIMEOUT=1100 zsh tools/thuyvan/bin/blender_run.sh -b --python-exit-code 1 \
        --python tools/thuyvan_art/traits/render_traits.py -- <job.json> [--only shot1,shot2] [--fox]

The job (written by prep_traits.py) lists the figures (face preset, body type, the baked skin, eyes, hair, garments,
ears and tails, place and turn) and the shots (camera, size, output). `--fox` first builds the Hồ Tinh ears and tails
(build_fox_parts.main) so one lock turn does both. Every step reports `TRAITS_*` lines; a figure that fails is skipped
with its traceback so the rest still renders.
"""
import json
import math
import os
import sys
import time
import traceback

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bscene as B  # noqa: E402

BODY_GLB = os.path.join(B.CHAR, "body", "body.glb")
REGION_IDS = json.load(open(os.path.join(B.CHAR, "body", "body.json")))["regions"]["ids"]
FOX = os.path.join(B.ROOT, "assets", "thuyvan", "character", "fox")
FUR = {"cream": ("#f2dcc8", "#fbf5ec"), "russet": ("#b94420", "#f6efe6"), "silver_white": ("#dfe2e4", "#ffffff"),
       "ash": ("#8f8a86", "#d9d6d2"), "black_tipped": ("#b94420", "#1e1a18")}


def fur_material(o, fur, name):
    """The fur colour model of fox_features.json: COLOR_0.R the painted value through the fur's ramp, G the tip, B the
    inner ear (1) and its tuft (0.55)."""
    base, tip = FUR.get(fur, FUR["cream"])
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = B.color_attr_name(o)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(vc.outputs[0], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    bl = B.hex_lin(base)
    ramp.color_ramp.elements[0].position = 0.2
    ramp.color_ramp.elements[0].color = tuple(c * 0.42 for c in bl[:3]) + (1,)
    ramp.color_ramp.elements[1].position = 0.8
    ramp.color_ramp.elements[1].color = tuple(c * 0.65 + 0.35 for c in bl[:3]) + (1,)
    e = ramp.color_ramp.elements.new(0.5)
    e.color = bl
    nt.links.new(sep.outputs[0], ramp.inputs[0])
    mt = nt.nodes.new("ShaderNodeMix")
    mt.data_type = "RGBA"
    nt.links.new(sep.outputs[1], mt.inputs[0])
    nt.links.new(ramp.outputs[0], mt.inputs[6])
    mt.inputs[7].default_value = B.hex_lin(tip)
    # the inner ear: pale skin (1) and the tuft (0.55)
    inner = nt.nodes.new("ShaderNodeMapRange")
    inner.inputs["From Min"].default_value = 0.75
    inner.inputs["From Max"].default_value = 0.95
    nt.links.new(sep.outputs[2], inner.inputs["Value"])
    tuft = nt.nodes.new("ShaderNodeMapRange")
    tuft.inputs["From Min"].default_value = 0.35
    tuft.inputs["From Max"].default_value = 0.5
    nt.links.new(sep.outputs[2], tuft.inputs["Value"])
    mtu = nt.nodes.new("ShaderNodeMix")
    mtu.data_type = "RGBA"
    nt.links.new(tuft.outputs[0], mtu.inputs[0])
    nt.links.new(mt.outputs[2], mtu.inputs[6])
    mtu.inputs[7].default_value = B.hex_lin("#fbf3e8")
    mi = nt.nodes.new("ShaderNodeMix")
    mi.data_type = "RGBA"
    nt.links.new(inner.outputs[0], mi.inputs[0])
    nt.links.new(mtu.outputs[2], mi.inputs[6])
    mi.inputs[7].default_value = B.hex_lin("#e8b4a8")
    nt.links.new(mi.outputs[2], bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = 0.85
    if "Sheen Weight" in bs.inputs:
        bs.inputs["Sheen Weight"].default_value = 0.7
        bs.inputs["Sheen Roughness"].default_value = 0.35
        bs.inputs["Sheen Tint"].default_value = (1, 1, 1, 1)
    B._spec(bs, 0.15)
    o.data.materials.clear()
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True


def pose_tails(arm, lift_deg, fan, curl_deg=9.0):
    """The pose layer's idle target, by hand: each tail lifted about its own horizontal axis, fanned out about the
    vertical, and curled a little more per bone toward the tip (the lineup's fan)."""
    bpy.context.view_layer.update()
    pbs = arm.pose.bones
    k = 1
    while pbs.get("fox_tail_%d_01" % k):
        k += 1
    n = k - 1
    for t in range(1, n + 1):
        b0 = pbs["fox_tail_%d_01" % t]
        d = (b0.tail - b0.head)
        d.z = 0
        yaw0 = math.atan2(d.x, d.y)
        axis = Vector((math.cos(yaw0), -math.sin(yaw0), 0.0))
        u = 0.0 if n == 1 else (t - 1) / (n - 1) * 2 - 1
        extra_yaw = yaw0 * (fan - 1.0)
        lift = math.radians(lift_deg * (1.0 - 0.25 * abs(u)) if n > 1 else lift_deg)
        R = Matrix.Rotation(-extra_yaw, 4, "Z") @ Matrix.Rotation(-lift, 4, axis)
        h = b0.head.copy()
        b0.matrix = Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ b0.matrix
        bpy.context.view_layer.update()
        for j in range(2, 6):
            bj = pbs.get("fox_tail_%d_%02d" % (t, j))
            if not bj:
                break
            hj = bj.head.copy()
            dd = (bj.tail - bj.head).normalized()
            ax = dd.cross(Vector((0, 0, 1)))
            if ax.length < 1e-4:
                continue
            ax.normalize()
            Rj = Matrix.Rotation(math.radians(curl_deg) * (1 if j < 4 else 0.6), 4, ax)
            bj.matrix = Matrix.Translation(hj) @ Rj @ Matrix.Translation(-hj) @ bj.matrix
            bpy.context.view_layer.update()


def build_figure(f, ctx):
    t0 = time.time()
    objs = B.import_glb(BODY_GLB)
    arm = [o for o in objs if o.type == "ARMATURE"][0]
    arm.name = "Arm_" + f["name"]
    body = [o for o in objs if o.type == "MESH" and o.name.startswith("Body")][0]
    face = [o for o in objs if o.type == "MESH" and o.name.startswith("Face")]
    keys = {"sex": float(f["sex"])}
    keys.update(f.get("face", {}))
    for o in objs:
        B.set_keys(o, keys)
    # skin under the garments is hidden as the game's hide_mask does
    hide = set()
    for g in f.get("garments", []):
        gj = g["glb"][:-4] + ".json"
        if os.path.exists(gj):
            hide |= set(json.load(open(gj)).get("hides_regions", []))
    hide_ids = {REGION_IDS[r] for r in hide if r in REGION_IDS}
    if hide_ids:
        B.delete_faces(body, lambda v, uv2: uv2 is not None and (int(round(uv2.x)) & 63) in hide_ids)
    B.skin_material(body, f["skin_prefix"], "Skin_" + f["name"])
    for fo in face:
        mats = [m.name for m in fo.data.materials]
        for i, mn in enumerate(mats):
            if mn.startswith("eye"):
                fo.data.materials[i] = B.eye_material(fo, f.get("iris", "#4a2e1a"), f.get("reflect", 0.0), f.get("tapetum", "#9fd08a"))
            elif mn.startswith("face_hair"):
                fo.data.materials[i] = B.face_hair_material(fo, ctx["brow_png"], f.get("hair_hex", "#1c1714"))
    parts = [body] + face
    if f.get("hair"):
        h = B.import_glb(os.path.join(B.CHAR, "hair", f["hair"] + ".glb"))
        for m in B.retarget(h, arm):
            B.set_keys(m, {"sex": float(f["sex"]), "sex_head": 0.0})
            B.set_keys(m, f.get("face", {}))
            m.data.materials.clear()
            m.data.materials.append(B.hair_material(m, f.get("hair_hex", "#1c1714"), f.get("hair_sheen")))
            parts.append(m)
    tail_root = None
    if f.get("tails"):
        tg = B.import_glb(os.path.join(FOX, "ho_tinh_tails_%d.glb" % f["tails"]["n"]))
        tarm = [o for o in tg if o.type == "ARMATURE"][0]
        # the tails' bones live in their glb's armature: copy them into this figure's armature
        bpy.context.view_layer.objects.active = tarm
        bpy.ops.object.mode_set(mode="EDIT")
        tb = {b.name: (b.head.copy(), b.tail.copy(), b.roll, b.parent.name if b.parent else None)
              for b in tarm.data.edit_bones if b.name.startswith("fox_tail_")}
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        eb = arm.data.edit_bones
        for name in sorted(tb):
            hd, tl, rl, par = tb[name]
            nb = eb.new(name)
            nb.head, nb.tail, nb.roll = hd, tl, rl
        for name in sorted(tb):
            par = tb[name][3]
            if par and par in eb:
                eb[name].parent = eb[par]
        bpy.ops.object.mode_set(mode="OBJECT")
        for m in B.retarget(tg, arm):
            fur_material(m, f["tails"].get("fur", "cream"), "Tail_" + f["name"])
            parts.append(m)
        tail_root = min((Vector(v[0]) for v in tb.values()), key=lambda p: p.z)
        tail_root = sum((Vector(v[0]) for k, v in tb.items() if k.endswith("_01")), Vector()) / max(1, sum(1 for k in tb if k.endswith("_01")))
    for g in f.get("garments", []):
        go = B.import_glb(g["glb"])
        for m in B.retarget(go, arm):
            B.set_keys(m, {"sex": float(f["sex"]), "sex_head": float(f["sex"])})
            if g.get("drop_zones"):
                dz = set(g["drop_zones"])
                B.delete_faces(m, lambda v, uv2: uv2 is not None and (int(round(uv2.x)) >> 6) in dz)
            if tail_root is not None:
                # the tail slit: the garment opens over the tails' root (tail_root hide region)
                r = tail_root
                B.delete_faces(m, lambda v, uv2: (v.co - r).length < 0.075 and v.co.y > r.y - 0.06)
            B.cloth_material(m, {int(k): v for k, v in g["zones"].items()}, "Cloth_" + f["name"])
            parts.append(m)
    if f.get("ears"):
        eo = B.import_glb(os.path.join(FOX, "ho_tinh_ears_%s.glb" % f["ears"]["shape"]))
        for m in B.retarget(eo, arm):
            B.set_keys(m, f["ears"].get("keys", {}))
            fur_material(m, f["ears"].get("fur", "cream"), "Ears_" + f["name"])
            parts.append(m)
    B.pose_relaxed(arm, f.get("arm_down", 22.0), f.get("elbow", 14.0))
    if f.get("tails"):
        pose_tails(arm, f["tails"].get("lift", 38.0), f["tails"].get("fan", 1.35), f["tails"].get("curl", 9.0))
    s = 1.07 if f["sex"] >= 0.5 else 1.0
    arm.scale = (s, s, s)
    arm.location = Vector((f["loc"][0], f["loc"][1], 0.0))
    arm.rotation_euler = (0, 0, math.radians(f.get("rot_z", 0.0)))
    tris = 0
    for o in parts:
        o.data.update()
        tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("TRAITS_FIGURE", f["name"], "tris", tris, "s %.1f" % (time.time() - t0))
    return arm, parts, tris


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    job = json.load(open(argv[0]))
    only = None
    if "--only" in argv:
        only = set(argv[argv.index("--only") + 1].split(","))
    if "--fox" in argv:
        try:
            import build_fox_parts
            build_fox_parts.main()
        except Exception:
            traceback.print_exc()
            print("TRAITS_FOX_FAILED")
    for sc in job["scenes"]:
        shots = [s for s in sc["shots"] if only is None or s["name"] in only]
        if not shots:
            continue
        B.reset()
        B.setup_scene(res=tuple(sc.get("res", (1920, 1080))), samples=sc.get("samples", 48), ground_png=job["ground_png"],
                      night=sc.get("night", False), sun_az_deg=sc.get("sun_az", -50.0))
        stats = {}
        arms = []
        for f in sc["figures"]:
            try:
                arm, parts, tris = build_figure(f, job)
                stats[f["name"]] = tris
                arms.append((arm, f.get("rot_z", 0.0)))
            except Exception:
                traceback.print_exc()
                print("TRAITS_FIGURE_FAILED", f["name"])
        for s in shots:
            for arm, r0 in arms:
                arm.rotation_euler = (0, 0, math.radians(r0 + s.get("turn", 0.0)))
            bpy.context.view_layer.update()
            c = s["cam"]
            B.add_camera(c["loc"], c["look"], c.get("lens", 85.0), ortho=c.get("ortho"))
            sce = bpy.context.scene
            sce.render.resolution_x, sce.render.resolution_y = s.get("res", sc.get("res", (1920, 1080)))
            t0 = time.time()
            os.makedirs(os.path.dirname(s["out"]), exist_ok=True)
            B.render(s["out"])
            print("TRAITS_SHOT", s["name"], s["out"], "s %.1f" % (time.time() - t0))
        json.dump(stats, open(os.path.join(os.path.dirname(shots[0]["out"]), "stats_%s.json" % sc["name"]), "w"), indent=1)
    print("TRAITS_DONE")


if __name__ == "__main__":
    main()
