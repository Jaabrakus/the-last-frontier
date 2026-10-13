"""Mud for the guards' fusions (the owner, 2026-10-12: "the water parry earth needs new blender effects it needs to look like
mud"): our own meshes, made here in Blender from metaballs (nothing imported or traced): a dripping blob (a held mud ball, a
Boulder turned to mud, a magma ball), a spear of mud (a stone turned by a water Turn), clods (splats and drips) and a squat lump
(the mud wave's crest). Each element group melts into one smooth surface, roughened with a little noise, UV-mapped round its
middle (the toon water shader's flowing noise reads its UVs), smooth-shaded, about 1 m across (the game scales it), centred on
the origin; the spear's point on Blender +Y, which the glTF export makes Godot's -Z (a bolt's forward). One glb, its meshes by
name: mud_blob, mud_spear, mud_clod_a, mud_clod_b, mud_clod_c, mud_lump. No materials (the game's ToonFx "mud" or "magma").
    blender -b --factory-startup -P tools/fx/blender/mud_meshes.py -- --out assets/fx/mud/mud.glb [--seed 7]
"""
import argparse
import math
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", type=int, default=7)
    return ap.parse_args(argv)


def metaball(name, elems, res=0.035, thresh=0.6):
    """A metaball object of `elems`: dicts {co, r, type: BALL | ELLIPSOID, size: (x, y, z)}. Its name has no dot: Blender
    melts metaball objects of one base name together."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = res
    mb.render_resolution = res
    mb.threshold = thresh
    for e in elems:
        el = mb.elements.new()
        el.type = e.get("type", "BALL")
        el.co = Vector(e["co"])
        el.radius = e["r"]
        if el.type == "ELLIPSOID":
            el.size_x, el.size_y, el.size_z = e.get("size", (1.0, 1.0, 1.0))
    ob = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def to_mesh(ob, out_name, rough, freq, rng):
    """Metaball `ob` made a mesh named `out_name`: roughened along its normals by noise (`rough` m at `freq` per m), centred,
    UVs round its middle (u the angle about Z, v the height), smooth."""
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    m = bpy.context.view_layer.objects.active
    m.name = out_name
    m.data.name = out_name
    bm = bmesh.new()
    bm.from_mesh(m.data)
    bm.normal_update()
    off = Vector((rng.uniform(0, 100), rng.uniform(0, 100), rng.uniform(0, 100)))
    for v in bm.verts:
        n = noise.noise(v.co * freq + off)
        v.co += v.normal * n * rough
    # centred on its bounds' middle
    lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
    hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
    mid = (lo + hi) * 0.5
    for v in bm.verts:
        v.co -= mid
    uv = bm.loops.layers.uv.new("UVMap")
    h = max(hi.z - lo.z, 1e-3)
    for f in bm.faces:
        us = []
        for lp in f.loops:
            c = lp.vert.co
            us.append((math.atan2(c.y, c.x) / (2.0 * math.pi) + 0.5, (c.z + h * 0.5) / h))
        # (a face across the seam keeps its u's together)
        if max(u for u, _ in us) - min(u for u, _ in us) > 0.5:
            us = [(u + 1.0 if u < 0.5 else u, v) for u, v in us]
        for lp, (u, v) in zip(f.loops, us):
            lp[uv].uv = (u, v)
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(m.data)
    bm.free()
    return m


def blob(rng):
    """A ball of mud about 1 m across: a main ball, lumps pressed into its surface, three drips hanging from its underside,
    each a long drop with a bulb at its end."""
    el = [{"co": (0, 0, 0), "r": 0.5}]
    for i in range(7):
        th = rng.uniform(0, 2 * math.pi)
        ph = rng.uniform(-0.6, 1.2)
        d = Vector((math.cos(th) * math.cos(ph), math.sin(th) * math.cos(ph), math.sin(ph))) * 0.36
        el.append({"co": tuple(d), "r": rng.uniform(0.17, 0.25)})
    for i in range(3):
        th = i * 2.1 + rng.uniform(-0.4, 0.4)
        x, y = math.cos(th) * 0.2, math.sin(th) * 0.2
        el.append({"co": (x, y, -0.42), "r": 0.13, "type": "ELLIPSOID", "size": (0.8, 0.8, 1.9)})
        el.append({"co": (x * 1.05, y * 1.05, -0.62 - 0.05 * i), "r": 0.09})
    return el


def spear(rng):
    """A spear of mud about 1 m long along +Y, its point at +Y: balls tapering from the butt to the point, lumps along it, two
    drips hanging from its underside."""
    el = []
    n = 9
    for i in range(n):
        t = i / (n - 1)
        el.append({"co": (rng.uniform(-0.01, 0.01), -0.45 + 0.95 * t, rng.uniform(-0.01, 0.01)), "r": 0.17 * (1.0 - t) + 0.035})
    for i in range(3):
        t = rng.uniform(0.1, 0.55)
        el.append({"co": (rng.uniform(-0.06, 0.06), -0.45 + 0.95 * t, rng.uniform(-0.04, 0.06)), "r": rng.uniform(0.08, 0.11)})
    for t in (0.2, 0.42):
        y = -0.45 + 0.95 * t
        el.append({"co": (0.0, y, -0.14), "r": 0.06, "type": "ELLIPSOID", "size": (0.8, 0.8, 1.8)})
        el.append({"co": (0.0, y + 0.02, -0.24), "r": 0.045})
    return el


def clod(rng):
    """A clod of mud about 0.5 m: two or three balls run together."""
    el = [{"co": (0, 0, 0), "r": 0.24}]
    for i in range(rng.randint(1, 2)):
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.6, 0.6))).normalized() * rng.uniform(0.12, 0.2)
        el.append({"co": tuple(d), "r": rng.uniform(0.13, 0.19)})
    return el


def lump(rng):
    """The mud wave's crest: a squat wide lump, gloops on its top."""
    el = [{"co": (0, 0, 0), "r": 0.5, "type": "ELLIPSOID", "size": (1.35, 1.0, 0.55)}]
    for i in range(4):
        el.append({"co": (rng.uniform(-0.45, 0.45), rng.uniform(-0.25, 0.25), 0.16), "r": rng.uniform(0.13, 0.2)})
    return el


def main():
    a = args()
    rng = random.Random(a.seed)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    made = []
    made.append(to_mesh(metaball("mudblobmeta", blob(rng)), "mud_blob", 0.03, 5.0, rng))
    made.append(to_mesh(metaball("mudspearmeta", spear(rng), res=0.02), "mud_spear", 0.012, 9.0, rng))
    for k in "abc":
        made.append(to_mesh(metaball("mudclodmeta" + k, clod(rng), res=0.03), "mud_clod_" + k, 0.025, 7.0, rng))
    made.append(to_mesh(metaball("mudlumpmeta", lump(rng)), "mud_lump", 0.025, 5.0, rng))
    for o in bpy.context.view_layer.objects:
        o.select_set(o in made)
    for o in made:
        print("MUD %s: %d verts, %d faces, %s m" % (o.name, len(o.data.vertices), len(o.data.polygons),
                                                   tuple(round(x, 3) for x in o.dimensions)))
    bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_apply=True,
                              export_materials="NONE", export_texcoords=True, export_normals=True)
    print("MUD exported", a.out)


main()
