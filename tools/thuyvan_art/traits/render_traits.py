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
# the fur's warm shadow tone (the sheet's tails shade cream into peach-rose, not grey)
FUR_SHADE = {"cream": "#9e5644", "russet": "#6a2010", "silver_white": "#8a9aae", "ash": "#4a4440", "black_tipped": "#6a2010"}
FUR = {"cream": ("#dcb394", "#fbf3ea"), "russet": ("#b94420", "#f6efe6"), "silver_white": ("#dfe2e4", "#ffffff"),
       "ash": ("#8f8a86", "#d9d6d2"), "black_tipped": ("#b94420", "#1e1a18")}


def fur_material(o, fur, name):
    """The fur colour model of fox_features.json: COLOR_0.R the painted value through the fur's ramp, G the tip, B the
    inner ear (1) and its tuft (0.55)."""
    base, tip = FUR.get(fur, FUR["cream"])
    shade = FUR_SHADE.get(fur, "#b9705a")
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
    ramp.color_ramp.elements[0].position = 0.25
    sl = B.hex_lin(shade)
    ramp.color_ramp.elements[0].color = tuple((c * 0.5 + s * 0.5) * 0.7 for c, s in zip(bl[:3], sl[:3])) + (1,)
    ramp.color_ramp.elements[1].position = 0.78
    ramp.color_ramp.elements[1].color = tuple(c * 0.78 + 0.22 for c in bl[:3]) + (1,)
    e = ramp.color_ramp.elements.new(0.5)
    e.color = bl
    # painted fur strokes along the tail (its UVs: u round, v along); the ears have none and take a constant
    uv = nt.nodes.new("ShaderNodeUVMap")
    sc = nt.nodes.new("ShaderNodeVectorMath")
    sc.operation = "MULTIPLY"
    sc.inputs[1].default_value = (46.0, 2.6, 1.0)
    nt.links.new(uv.outputs[0], sc.inputs[0])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 1.0
    nz.inputs["Detail"].default_value = 3.0
    nt.links.new(sc.outputs[0], nz.inputs["Vector"])
    st = nt.nodes.new("ShaderNodeMath")
    st.operation = "SUBTRACT"
    st.inputs[1].default_value = 0.5
    nt.links.new(nz.outputs["Fac"], st.inputs[0])
    st2 = nt.nodes.new("ShaderNodeMath")
    st2.operation = "MULTIPLY_ADD"
    st2.inputs[1].default_value = 0.45
    nt.links.new(st.outputs[0], st2.inputs[0])
    nt.links.new(sep.outputs[0], st2.inputs[2])
    nt.links.new(st2.outputs[0], ramp.inputs[0])
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


def pose_tails(arm, spec):
    """The pose layer's target for a still shot (fox_features.json pose_layer, here by hand): tail k lies in the plane
    of the back axis and its own fan direction (theta from straight up, spread across the tails), each bone turned from
    the back axis toward that direction by phi_j, so the tails leave the sacrum backward and sweep up and out (the
    lineup's fan); a single tail falls and curls its tip back up."""
    bpy.context.view_layer.update()
    pbs = arm.pose.bones
    k = 1
    while pbs.get("fox_tail_%d_01" % k):
        k += 1
    n = k - 1
    back = Vector((0.0, 1.0, 0.0))
    for t in range(1, n + 1):
        u = 0.0 if n == 1 else (t - 1) / (n - 1) * 2 - 1
        jit = spec.get("jitter", 0.0)
        hj = math.sin(t * 12.9898 + n * 78.233) * 43758.5453
        hj = (hj - math.floor(hj)) * 2.0 - 1.0
        theta = math.radians(spec.get("theta0", 0.0) + u * spec.get("spread", 100.0) + jit * hj)
        d = Vector((math.sin(theta), 0.0, math.cos(theta)))
        phis = spec.get("phis", [15.0, 42.0, 70.0, 90.0, 102.0])
        curl = spec.get("curl", [0.0, 0.0, 0.0, 0.0, 0.0])
        lag = spec.get("lag", 0.0) * abs(u) + jit * 0.5 * hj
        for j in range(1, 6):
            pb = pbs.get("fox_tail_%d_%02d" % (t, j))
            if not pb:
                break
            cur = (pb.tail - pb.head).normalized()
            ph = math.radians(phis[j - 1] - lag * j)
            tgt = (back * math.cos(ph) + d * math.sin(ph) + Vector((0.0, 0.0, curl[j - 1]))).normalized()
            q = cur.rotation_difference(tgt).to_matrix().to_4x4()
            h = pb.head.copy()
            pb.matrix = Matrix.Translation(h) @ q @ Matrix.Translation(-h) @ pb.matrix
            bpy.context.view_layer.update()


def build_figure(f, ctx):
    t0 = time.time()
    objs = B.import_glb(BODY_GLB)
    arm = [o for o in objs if o.type == "ARMATURE"][0]
    arm.name = "Arm_" + f["name"]
    arm.rotation_mode = "XYZ"
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
    if any("trousers" in g["glb"] for g in f.get("garments", [])):
        # the trousers' seat and fork cover the pelvis below the waist band (the body type 1 fork showed through)
        pc = REGION_IDS["pelvis_center"]
        B.delete_faces(body, lambda v, uv2: uv2 is not None and (int(round(uv2.x)) & 63) == pc and v.co.z < 0.90)
    B.smooth_body(body)
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
    if f.get("vest"):
        v = B.body_vest(body, f["vest"]["zones"])
        parts.append(v)
        if tail_root is not None:
            r = tail_root
            B.delete_faces(v, lambda vv, uv2: (vv.co - r).length < 0.075 and vv.co.y > r.y - 0.06)
    for g in f.get("garments", []):
        go = B.import_glb(g["glb"])
        for m in B.retarget(go, arm):
            B.set_keys(m, {"sex": float(f["sex"])})
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
            B.set_keys(m, dict({"ear_back": 0.0, "ear_flat": 0.0, "ear_perk": 0.0}, **f["ears"].get("keys", {})))
            if m.data.shape_keys:
                print("TRAITS_EAR_KEYS", [(k.name, round(k.value, 2)) for k in m.data.shape_keys.key_blocks])
            fur_material(m, f["ears"].get("fur", "cream"), "Ears_" + f["name"])
            parts.append(m)
    B.pose_relaxed(arm, f.get("arm_down", 22.0), f.get("elbow", 14.0))
    if f.get("tails"):
        pose_tails(arm, f["tails"])
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
    scenes = set(argv[argv.index("--scenes") + 1].split(",")) if "--scenes" in argv else None
    for sc in job["scenes"]:
        if scenes is not None and sc["name"] not in scenes:
            continue
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
