"""finish_part(): everything after a part module has built its geometry (design §7.1).

A part module (tools/character/{hair,garments/<set>}/<id>.py) defines SPEC
(lib.catalog.GarmentSpec) and build(ctx) returning {surface key: Surface or object}:

    def build(ctx):
        ob = sdf_object(SPEC.id, node, 0.003, 2000, mat, sizing=...)
        return {"main": pipeline.Surface(ob, zones=zone_per_polygon, uv=my_uvs)}

The pipeline then, per surface:
  1. UVs          UVMap (metres) from Surface.uv (callable(ob) -> per-loop uv) if given
  2. regions      Region UV: u = region + 64 * zone; region per polygon from Surface.regions
                  or the nearest body triangle's region; zone per polygon from Surface.zones
                  or the polygon's material index; v = h (Surface.h per vertex, e.g. shells)
  3. bands        Edge UV (CUSTOM0) from Surface.edge = (d_hem, d_open) per vertex
  4. weights      Surface.weights (n, bones) or SPEC.weights: "body" (nearest body point,
                  torso-from-torso above the waist), "headb" / "pelvis" (rigid), or a
                  callable(ctx, ob) -> W; then limited to 4 influences and normalized
and for the joined part:
  5. shape keys   `sex` (and face_* when SPEC.face_shapes) by wrap transfer from the body
  6. envelope     clearance check at bind against the layer's band (garments)
  7. budget       triangles vs SPEC.budget
  8. export       assets/character/<glb_rel> (+ .import without LODs / shadow meshes: those
                  would merge vertices across region borders), all 291 joints, rest null-add
  9. catalog      the JSON fragment next to the glb (lib.catalog)
"""

import json
import os
import time

import bpy
import numpy as np

from . import catalog as CAT
from . import layers as LY
from . import regions as RG
from .remesh import join, material, mesh_arrays, tri_count
from .rig import FRONTIER, export_glb
from .sdf import log
from .shapes import add_shape_keys
from .weights import limit_normalize, mesh_adjacency, smooth_weights, write_groups
from .wrap import Surface as WrapSurface

IMPORT_PARAMS = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
mesh_library/use_node_names_as_mesh_names=false
array_mesh/deduplicate_surfaces=true
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=false
meshes/create_shadow_meshes=false
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=true
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
materials/extract=0
materials/extract_format=0
materials/extract_path=""
_subresources={}
gltf/naming_version=2
gltf/embedded_image_handling=1
gltf/texture_map_mode=1
"""


class Surface:
    """One surface of a part: the object and optional per-polygon / per-vertex data."""

    def __init__(self, ob, zones=None, regions=None, h=None, weights=None, uv=None, edge=None, colors=None):
        self.ob, self.zones, self.regions, self.h = ob, zones, regions, h
        self.weights, self.uv, self.edge, self.colors = weights, uv, edge, colors


def write_import(glb_path):
    p = glb_path + ".import"
    if not os.path.exists(p):
        with open(p, "w") as f:
            f.write(IMPORT_PARAMS)


# ---------------------------------------------------------------------------
# weights
# ---------------------------------------------------------------------------
TORSO_Z = (0.98, 1.04)


def body_weights_at(ctx, P, torso_only=None):
    """Weights of the nearest body point of each point P. torso_only (mask): those points
    bind to the body's torso / neck triangles only (a garment's torso must not follow the
    arm that hangs next to the ribs in the A-pose; see build_body.torso_from_torso)."""
    body = ctx.body()
    surf = WrapSurface(body.V, body.F)
    tri, bary, _, _ = surf.nearest(P)
    W = surf.interpolate(body.W, tri, bary)
    if torso_only is not None and np.any(torso_only):
        tl = np.isin(body.vlab[body.F[:, 0]], ["torso", "neck"])
        st = WrapSurface(body.V, body.F, allowed=tl)
        idx = np.nonzero(torso_only)[0]
        t2, b2, _, _ = st.nearest(P[idx])
        W[idx] = st.interpolate(body.W, t2, b2)
    return W


def garment_body_weights(ctx, ob):
    """Default garment weights: nearest body point; above the waist the torso part of the
    garment (closer to the torso than to an arm) binds to the torso only, blended over
    TORSO_Z and the armhole (lib.weights.sleeve_factor)."""
    from .sdf import smoothstep
    from .weights import sleeve_factor
    V = mesh_arrays(ob)
    W = body_weights_at(ctx, V)
    sel = V[:, 2] > TORSO_Z[0]
    if sel.any():
        idx = np.nonzero(sel)[0]
        t = (1.0 - sleeve_factor(V[idx], ctx.K)) * smoothstep(TORSO_Z[0], TORSO_Z[1], V[idx, 2])
        Wt = body_weights_at(ctx, V[idx], torso_only=np.ones(len(idx), bool))
        W[idx] = W[idx] * (1 - t[:, None]) + Wt * t[:, None]
    return W


def rigid_weights(ctx, n, bone):
    W = np.zeros((n, len(ctx.bones)))
    W[:, ctx.bones.index(bone)] = 1.0
    return W


def _weights(ctx, spec, sf):
    ob = sf.ob
    n = len(ob.data.vertices)
    if sf.weights is not None:
        W = sf.weights(ctx, ob) if callable(sf.weights) else np.asarray(sf.weights, float)
    elif callable(spec.weights):
        W = spec.weights(ctx, ob)
    elif spec.weights == "body":
        W = garment_body_weights(ctx, ob)
    elif spec.weights in ("headb", "pelvis", "spined"):
        W = rigid_weights(ctx, n, spec.weights)
    else:
        raise ValueError("unknown weights %r" % (spec.weights,))
    return limit_normalize(W)


# ---------------------------------------------------------------------------
# per surface attributes
# ---------------------------------------------------------------------------
def _poly_regions(ctx, ob):
    body = ctx.body()
    me = ob.data
    C = np.array([p.center for p in me.polygons], float)
    surf = WrapSurface(body.V, body.F)
    tri, _, _, _ = surf.nearest(C)
    return body.freg[tri]


def _prepare_surface(ctx, spec, key, sf, mat):
    ob = sf.ob
    me = ob.data
    if me.uv_layers.get("UVMap") is None:
        # UVMap must be TEXCOORD_0: recreate the layer order if another exists already
        names = [l.name for l in me.uv_layers]
        data = {n: np.array([d.uv[:] for d in me.uv_layers[n].data]) for n in names}
        for n in names:
            me.uv_layers.remove(me.uv_layers[n])
        me.uv_layers.new(name="UVMap")
        for n in names:
            lay = me.uv_layers.new(name=n)
            lay.data.foreach_set("uv", data[n].astype(np.float32).ravel())
    if sf.uv is not None:
        uv = sf.uv(ob) if callable(sf.uv) else sf.uv
        me.uv_layers["UVMap"].data.foreach_set("uv", np.asarray(uv, np.float32).ravel())
    zones = np.array([p.material_index for p in me.polygons]) if sf.zones is None else np.asarray(sf.zones, int)
    regions = _poly_regions(ctx, ob) if sf.regions is None else np.asarray(sf.regions, int)
    codes = regions + 64 * zones
    lv = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv)
    h_loop = None if sf.h is None else np.asarray(sf.h, float)[lv]
    RG.write_region_uv(ob, codes, "Region", h_loop)
    if sf.edge is not None:
        from .bands import write_edge_uv
        write_edge_uv(ob, sf.edge[0], sf.edge[1] if len(sf.edge) > 1 else None)
    col = sf.colors if sf.colors is not None else np.ones((len(me.vertices), 4))
    attr = me.color_attributes.get("Color") or me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.asarray(col, np.float32).ravel())
    me.color_attributes.active_color = attr
    W = _weights(ctx, spec, sf)
    write_groups(ob, W, ctx.bones)
    while len(me.materials):
        me.materials.pop()
    me.materials.append(mat)
    for p in me.polygons:
        p.material_index = 0
    return {"tris": tri_count(ob), "verts": len(me.vertices), "zones": sorted(set(int(z) for z in zones)),
            "regions": sorted(set(RG.REGION_NAMES.get(int(r), str(r)) for r in regions)),
            "max_influences": int((W > 0).sum(1).max()) if len(W) else 0,
            "bones": [ctx.bones[j] for j in range(len(ctx.bones)) if W[:, j].max() > 0]}, W


HAT_FIT_OFFSET = 0.0065      # hair under a hat band: at most this far off the scalp


def hat_fit_delta(ctx, V, E):
    """`hat_fit` shape of a hair style: hair above the hat band plane (and fading out 2 cm
    below it) pressed toward the scalp to at most HAT_FIT_OFFSET, so a hat built over the
    legacy 7.5 mm cap fits every style. Zero for thin styles."""
    from hair import _common as HC
    from .sdf import peval
    head = HC.head_base(ctx.K)
    d = peval(head, V)
    h = 4e-4
    g = np.stack([(peval(head, V + e * h) - peval(head, V - e * h)) / (2 * h) for e in np.eye(3)], 1)
    g /= np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)
    band = (V - HC.CROWN_P) @ HC.CROWN_N
    w = np.clip((band + 0.020) / 0.020, 0.0, 1.0)
    w = w * w * (3 - 2 * w)
    excess = np.clip(d - HAT_FIT_OFFSET, 0.0, None) * w
    D = -g * excess[:, None]
    from .wrap import smooth_field
    return smooth_field(D, E, 3)


def finish_part(ctx, spec, parts, generator="", export=True):
    t0 = time.time()
    surfs = {}
    for key, v in parts.items():
        if v is None:
            continue
        surfs[key] = v if isinstance(v, Surface) else Surface(v)
    stats = {"surfaces": {}}
    objs = []
    has_edge = any(sf.edge is not None for sf in surfs.values())
    for key, sf in surfs.items():
        mname = spec.surfaces.get(key, "%s_%s" % (spec.id, key))
        mat = material(mname, "#8a6a50", 0.7)
        s, _ = _prepare_surface(ctx, spec, key, sf, mat)
        if has_edge and sf.ob.data.uv_layers.get("Edge") is None:
            from .bands import write_edge_uv
            write_edge_uv(sf.ob, np.ones(len(sf.ob.data.vertices)))
        stats["surfaces"][key] = s
        objs.append(sf.ob)
    ob = join(objs, spec.id) if len(objs) > 1 else objs[0]
    ob.name = ob.data.name = spec.id
    # 5. shape keys by wrap transfer from the body
    body = ctx.body()
    V = mesh_arrays(ob)
    # hair follows the head part of the male fit and the face features (hairline, sideburns, ears)
    face = spec.face_shapes or spec.kind == "hair"
    names = ["sex"] + ([n for n in body.shapes if n.startswith("face_") or n == "sex_head"] if face else [])
    if spec.kind == "hair":
        # the cap is carved around the ears: a hair vertex bound to the ear would amplify the
        # ear's turn (centimetres away from it); the eye and mouth warps never reach the hair
        names = [n for n in names if n not in ("face_ears", "face_eye_tilt", "face_eye_height", "face_epicanthus",
                                               "face_mouth_width")]
    surf = WrapSurface(body.V, body.F, shapes=body.shapes)
    b = surf.bind(V)
    E = mesh_adjacency(ob)
    deltas = {n: surf.shape_delta(b, n, smooth_E=E, smooth_iters=3) for n in names}
    if spec.kind == "hair":
        deltas["hat_fit"] = hat_fit_delta(ctx, V, E)
    add_shape_keys(ob, deltas)
    # 6. envelope (garments only)
    checks = {}
    if spec.kind != "hair":
        layer = LY.LAYER_OF_VALUE.get(spec.layer.get("default"), None)
        if layer is not None:
            ok, rep = LY.check_envelope(body, V, body.freg[b.tri], layer, sdf=ctx.body_sdf())
            checks["envelope"] = {"ok": ok, "layer": layer, "groups": rep}
            if not ok:
                log("  ENVELOPE %s: vertices below the %s band: %s" % (spec.id, layer,
                    {g: r["below_inner"] for g, r in rep.items() if r["below_inner"]}))
    tris = tri_count(ob)
    stats.update({"tris": tris, "verts": len(ob.data.vertices), "surface_count": len(objs),
                  "shapes": {n: round(float(np.linalg.norm(d, axis=1).max()), 4) for n, d in deltas.items()}})
    budget = spec.budget.get("tris_max")
    if budget and tris > budget:
        log("  BUDGET %s: %d tris > %d" % (spec.id, tris, budget))
    # 8. export
    rig = ctx.bind_rig()
    ob.parent = rig
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    used = set()
    for vg in ob.vertex_groups:
        used.add(vg.name)
    for bn in rig.data.bones:
        if bn.name in used:
            bn.use_deform = True
    glb = os.path.join(CAT.ASSETS, spec.glb_rel())
    result = {"spec": spec, "object": ob, "glb": glb, "stats": stats}
    if export:
        export_glb(rig, [ob], glb, texcoords=True, morph=True)
        write_import(glb)
        stats["glb_kb"] = round(os.path.getsize(glb) / 1024.0, 1)
        path, problems = CAT.write_fragment(spec, stats, checks, generator)
        result["problems"] = problems
        for p in problems:
            log("  CATALOG %s" % p)
        log("  %s: %d tris, %d verts, %s -> %s (%.1fs)" % (spec.id, tris, stats["verts"], stats["shapes"],
                                                          os.path.relpath(glb, FRONTIER), time.time() - t0))
    return result


def build_part(ctx, mod, export=True, previews=None):
    parts = mod.build(ctx)
    gen = os.path.relpath(mod.__file__, FRONTIER)
    res = finish_part(ctx, mod.SPEC, parts, generator=gen, export=export)
    if previews:
        res["previews"] = part_previews(ctx, res, previews)
    # keep the scene light: the part is exported, hide it from later renders
    res["object"].hide_render = True
    return res


# ---------------------------------------------------------------------------
# previews (Blender Workbench; the reference renders are Godot's)
# ---------------------------------------------------------------------------
_PREVIEW = {}


def preview_body(ctx):
    """A plain skin-coloured body object from the body cache (with its shape keys)."""
    if "body" in _PREVIEW:
        return _PREVIEW["body"]
    body = ctx.body()
    me = bpy.data.meshes.new("PreviewBody")
    me.from_pydata([tuple(v) for v in body.V], [], [tuple(int(i) for i in f) for f in body.F])
    me.update()
    ob = bpy.data.objects.new("PreviewBody", me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(material("preview_skin", "#b8876a", 0.6))
    for p in me.polygons:
        p.use_smooth = True
    add_shape_keys(ob, {"sex": body.shapes["sex"]})
    _PREVIEW["body"] = ob
    return ob


def part_previews(ctx, res, outdir):
    from .preview import contact_sheet, render_view, setup_preview_scene
    os.makedirs(outdir, exist_ok=True)
    if "cam" not in _PREVIEW:
        ctx.rig.hide_render = True
        ctx.bind_rig().hide_render = True
        _PREVIEW["cam"] = setup_preview_scene()
    co = _PREVIEW["cam"]
    body = preview_body(ctx)
    ob = res["object"]
    spec = res["spec"]
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o not in (body, ob):
            o.hide_render = True
    body.hide_render = False
    ob.hide_render = False
    shots = []
    head = spec.kind == "hair" or spec.slot == "head"
    for sex in (0.0, 1.0):
        body.data.shape_keys.key_blocks["sex"].value = sex
        ob.data.shape_keys.key_blocks["sex"].value = sex
        for v in ("front34", "back", "side"):
            p = os.path.join(outdir, "%s_%s_%d.png" % (spec.id, v, int(sex)))
            if head:
                shots.append(render_view(co, p, v, center=(0, 0.0, 1.46), scale=0.42, res=(420, 460)))
            else:
                shots.append(render_view(co, p, v, center=(0, 0, 0.84), scale=1.8, res=(420, 760)))
    body.data.shape_keys.key_blocks["sex"].value = 0.0
    ob.data.shape_keys.key_blocks["sex"].value = 0.0
    sheet = contact_sheet(shots, os.path.join(outdir, "%s_sheet.png" % spec.id), 6)
    return sheet


def part_sheets(ctx, built, outdir):
    """One contact sheet of the first view of every built part."""
    from .preview import contact_sheet
    shots = []
    for r in built:
        sp = r.get("previews")
        if sp:
            shots.append(os.path.join(os.path.dirname(sp), "%s_front34_0.png" % r["spec"].id))
            shots.append(os.path.join(os.path.dirname(sp), "%s_back_1.png" % r["spec"].id))
    if shots:
        contact_sheet(shots, os.path.join(outdir, "parts_sheet.png"), 8)
