# Natural props from Poly Haven (package C). Blender 5.2, background:
#
#   Blender -b --factory-startup -P tools/environment/vegetation/process_props.py -- [only=boulder_01,...]
#       [preview=<png>]
#
# Imports each approved Poly Haven model (assets/polyhaven/models, read-only), applies its node
# transforms, puts the origin at the bottom centre, decimates it to the LOD budgets of the look-dev
# spec (section 7.1) and exports assets/environment/props/<id>/<id>.glb with objects
# <variant>_lod<n> (no materials: the Godot side builds them from the 1K textures written by
# make_textures.py). Also writes assets/environment/props/props.json: per variant the bounding box
# (Godot Y-up), triangle counts and a convex hull (<= 48 points, from LOD2) for rock colliders.
#
# Composite variant: the three dry_branches_medium_01 pieces are stacked into a brush pile.
# (shrub_04 is rendered into the foliage atlas by build_atlas.py instead: see ASSETS below.)
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bcommon import *

A = args()
ONLY = A.get('only', '').split(',') if A.get('only') else []
OUT = os.path.join(ENV, 'props')

# asset: list of (variant name, source node names or None for all, budgets, kind)
ASSETS = {
    'tree_stump_01': [('stump_a', None, (3000, 800, 200), 'stump')],
    'tree_stump_02': [('stump_b', None, (3000, 800, 200), 'stump')],
    'rock_moss_set_01': [('rock_a', ['rock_moss_set_01_rock02'], (2000, 700, 200), 'rock'),
                         ('rock_b', ['rock_moss_set_01_rock04'], (2000, 700, 200), 'rock'),
                         ('rock_c', ['rock_moss_set_01_rock06'], (2000, 700, 200), 'rock')],
    'rock_moss_set_02': [('rock_d', ['rock_moss_set_02_rock09'], (2000, 700, 200), 'rock'),
                         ('rock_e', ['rock_moss_set_02_rock12'], (2000, 700, 200), 'rock')],
    'boulder_01': [('boulder', None, (3000, 800, 200), 'rock')],
    'dead_tree_trunk': [('log', None, (4000, 1000, 250), 'log')],
    'root_cluster_01': [('roots', None, (3000, 800, 200), 'roots')],
    'fern_02': [('fern_a', ['fern_02_a'], (1500, 400, 0), 'fern'),
                ('fern_b', ['fern_02_b'], (1500, 400, 0), 'fern'),
                ('fern_c', ['fern_02_c'], (1500, 400, 0), 'fern'),
                ('fern_d', ['fern_02_d'], (1500, 400, 0), 'fern')],
    # shrub_04 is not exported as a model: its leaf islands cannot be decimated below ~700
    # triangles per sprig, so build_atlas.py renders it into the foliage atlas instead.
    'dry_branches_medium_01': [('brush', 'pile', (4000, 1000, 250), 'brush')],
}


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def join(objs, name):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def apply_xform(ob):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def ground(ob):
    """Origin at the bottom centre of the bounding box."""
    vs = [v.co for v in ob.data.vertices]
    cx = (min(v.x for v in vs) + max(v.x for v in vs)) / 2
    cy = (min(v.y for v in vs) + max(v.y for v in vs)) / 2
    mz = min(v.z for v in vs)
    for v in ob.data.vertices:
        v.co.x -= cx
        v.co.y -= cy
        v.co.z -= mz
    ob.data.update()


def decimated_copy(ob, target, name, planar=0.0):
    c = ob.copy()
    c.data = ob.data.copy()
    c.name = name
    c.data.name = name
    link(c)
    cur = tri_count(c)
    if target and cur > target * 1.5 and planar:
        # Leaf islands (shrub_04) cannot collapse below a few triangles each: dissolve the
        # near-planar interior first.
        m = c.modifiers.new('planar', 'DECIMATE')
        m.decimate_type = 'DISSOLVE'
        m.angle_limit = math.radians(planar)
        for o in bpy.context.scene.objects:
            o.select_set(False)
        c.select_set(True)
        bpy.context.view_layer.objects.active = c
        bpy.ops.object.modifier_apply(modifier=m.name)
        m = c.modifiers.new('tri', 'TRIANGULATE')
        bpy.ops.object.modifier_apply(modifier=m.name)
        cur = tri_count(c)
    if target and cur > target:
        m = c.modifiers.new('dec', 'DECIMATE')
        m.decimate_type = 'COLLAPSE'
        m.ratio = target / cur
        m.use_collapse_triangulate = True
        for o in bpy.context.scene.objects:
            o.select_set(False)
        c.select_set(True)
        bpy.context.view_layer.objects.active = c
        bpy.ops.object.modifier_apply(modifier=m.name)
    for p in c.data.polygons:
        p.use_smooth = True
    return c


def cluster(sprig, count, seed, name):
    """Arrange copies of a sprig into a shrub: sprigs radiating from the root, arching up."""
    rng = random.Random(seed)
    parts = []
    for i in range(count):
        c = sprig.copy()
        c.data = sprig.data.copy()
        link(c)
        az = 2 * math.pi * i / count + rng.uniform(-0.3, 0.3)
        tilt = math.radians(rng.uniform(35, 75))
        s = rng.uniform(0.85, 1.35)
        # The sprig lies along -X from its base (bounds -0.53..0.05): stand it up and fan it out.
        c.rotation_mode = 'XYZ'
        c.rotation_euler = (0.0, -(math.pi / 2 - tilt), az)
        c.scale = (s, s, s)
        c.location = (math.cos(az) * 0.05, math.sin(az) * 0.05, rng.uniform(0.0, 0.25))
        parts.append(c)
    bpy.context.view_layer.update()
    for p in parts:
        apply_xform(p)
    return join(parts, name)


def brush_pile(pieces, seed, name):
    rng = random.Random(seed)
    parts = []
    for k in range(6):
        src = pieces[k % len(pieces)]
        c = src.copy()
        c.data = src.data.copy()
        link(c)
        c.rotation_mode = 'XYZ'
        c.rotation_euler = (rng.uniform(-0.3, 0.3), rng.uniform(-0.25, 0.25), rng.uniform(0, 2 * math.pi))
        s = rng.uniform(1.4, 2.0)
        c.scale = (s, s, s)
        c.location = (rng.uniform(-0.4, 0.4), rng.uniform(-0.3, 0.3), 0.08 * k)
        parts.append(c)
    bpy.context.view_layer.update()
    for p in parts:
        apply_xform(p)
    return join(parts, name)


def hull_points(ob, max_points=48):
    """Convex hull of the object's vertices (bmesh), reduced to max_points by farthest-point
    sampling; returned in Godot's Y-up frame."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    res = bmesh.ops.convex_hull(bm, input=bm.verts)
    hv = [v for v in res['geom'] if isinstance(v, bmesh.types.BMVert)]
    pts = [v.co.copy() for v in hv] or [v.co.copy() for v in bm.verts]
    bm.free()
    if len(pts) > max_points:
        chosen = [max(pts, key=lambda p: p.z)]
        while len(chosen) < max_points:
            far = max(pts, key=lambda p: min((p - q).length for q in chosen))
            chosen.append(far)
        pts = chosen
    return [[round(p.x, 4), round(p.z, 4), round(-p.y, 4)] for p in pts]


def bounds(ob):
    vs = [v.co for v in ob.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    # Godot Y-up: (x, z, -y)
    return [round(mx.x - mn.x, 3), round(mx.z - mn.z, 3), round(mx.y - mn.y, 3)]


def export(objs, path):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_materials='NONE',
                              export_vertex_color='NONE', export_normals=True, export_texcoords=True,
                              export_tangents=False, export_yup=True, export_apply=False)
    print('exported', os.path.relpath(path, FRONTIER))


def process(asset, variants, meta):
    reset()
    src = import_gltf(os.path.join(POLYHAVEN, 'models', asset, '%s_2k.gltf' % asset))
    meshes = {o.name: o for o in src if o.type == 'MESH'}
    for o in src:
        if o.type == 'MESH':
            o.rotation_mode = 'QUATERNION'
    bpy.context.view_layer.update()
    for o in meshes.values():
        apply_xform(o)
        # The glTF importer keeps every split vertex separate; weld them (UVs live on the face
        # corners, so they survive) or the decimator cannot collapse across the seams.
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bm.to_mesh(o.data)
        bm.free()
    out_objs = []
    for (vname, nodes, budgets, kind) in variants:
        if nodes is None:
            base = join(list(meshes.values()), vname)
        elif isinstance(nodes, list):
            sel = [meshes[n] for n in nodes]
            base = join(sel, vname)
        elif nodes.startswith('cluster:'):
            sprig = list(meshes.values())[0]
            # Decimate the sprig first (27k tris) so the clump fits the budget.
            n = int(nodes.split(':')[1])
            small = decimated_copy(sprig, budgets[0] // n, 'sprig_' + vname, planar=12.0)
            base = cluster(small, n, sum(ord(ch) for ch in vname), vname)
        elif nodes == 'pile':
            pieces = [decimated_copy(o, budgets[0] // 6, 'piece_%d' % i) for i, o in enumerate(meshes.values())]
            base = brush_pile(pieces, 7, vname)
        ground(base)
        lods = []
        for lod, target in enumerate(budgets):
            if target <= 0:
                continue
            c = decimated_copy(base, target, '%s_lod%d' % (vname, lod))
            lods.append(c)
            out_objs.append(c)
        info = dict(asset=asset, kind=kind, size=bounds(base), tris=[tri_count(c) for c in lods])
        if kind in ('rock', 'stump', 'roots', 'log', 'brush'):
            info['hull'] = hull_points(lods[-1])
        meta[vname] = info
        print('%-12s %-10s size=%s tris=%s' % (vname, kind, info['size'], info['tris']))
    export(out_objs, os.path.join(OUT, asset, asset + '.glb'))


if __name__ == '__main__':
    path = os.path.join(OUT, 'props.json')
    meta = json.load(open(path)) if os.path.exists(path) else {}
    for asset, variants in ASSETS.items():
        if ONLY and asset not in ONLY:
            continue
        process(asset, variants, meta)
    with open(path, 'w') as f:
        json.dump(meta, f, indent=1, sort_keys=True)
    print('PROPS DONE')
