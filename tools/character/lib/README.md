# tools/character/lib: shared Blender library (lib v1)

Owner: the body and library workstream. Garment, hair and fur generators **import** this
package and never edit it. Ask for a change instead: a lib change needs a rebuild of every
catalog glb (`build_character.sh --all`) and every character check.

Everything runs inside Blender 5.2 (headless), on a **copy** of `Actor_B_001.blend`
(`build_character.sh` makes the copy; `rig.guard_source()` refuses the original).

## Conventions

| Topic | Rule |
| --- | --- |
| Space | Blender armature space at the bind pose `null-add`: z up, the character faces -y. Godot skeleton space is (x, z, -y). |
| Bind | glb armature `Actor_B` with all 291 bones in rig order, rest = null-add; inverse binds = inverse(null-add global). `CharacterBodyMesh` rebinds from the clip at runtime and shares one `Skin` between parts. |
| Weights | Segments joint -> child joint (`weights.deform_segments`), never Blender bone tails or automatic weights. Main deform bones plus the helpers the game drives (`helpers.HELPERS`, `QUEUE_HELPER`). Max 4 influences (`weights.limit_normalize`). |
| Regions | `UV2.x = region + 64 * zone` (`regions.encode`). 38 body regions (ids 0-37), hair zones 48-52. Every triangle lies in one region; the exporter splits vertices at borders. The shaders collapse hidden regions (`hide_mask`, a uvec2 of 64 bits). |
| Zones | Up to 4 material zones per surface (fabric / colour). The surface is the glb material name. |
| UVs | UVMap (TEXCOORD_0 -> Godot UV) in metres along the grain; Region (TEXCOORD_1 -> UV2: code, and v = h for shells and cards); Edge (TEXCOORD_2 -> CUSTOM0: distance to hem, distance to opening). The exporter writes v as 1 - v and Godot keeps it: store 1 - value where the shader needs the value. |
| Shapes | Every part has the `sex` morph target (0 female base .. 1 male fit), made by wrap transfer from the body; parts touching the face may also take `face_*`. |
| Colour | COLOR_0: rgb = baked shading multiplier, a = mask (beard, fur flatten, pattern). |
| Determinism | Builds are deterministic (`remesh.untangle` smooths in index order). |

## Modules

| Module | Main API |
| --- | --- |
| `sdf` | SDF nodes `Sphere, Ellipsoid, RoundCone, RoundBox, Plane, Fn, Union, SymUnion, Inter, Sub, Offset, Onion`; `geval / peval`; `polygonize`, `project_to_surface`, `surface_point`, `sdf_normal`; `zslab, xband, cut_plane`; `v3, nrm, lerp, frame_from, smoothstep, mirror_x`; `log`, `set_log_tag`. |
| `remesh` | `sdf_object(name, node, h, target_tris, mat, sizing=fn(P)->edge length, ...)` (polygonize, QEM, isotropic remesh re-projected onto the SDF); `mesh_object, mesh_arrays, tri_count, decimate, check_manifold, join, set_sharp`; `Prims` (spheres, caps, cylinders, boxes, buckle frames); `material(name, hex, rough, metal)`. |
| `rig` | `bind_pose(rig)`, `Skel` (joint positions, `K["headb"]`, `K.side("elbow", s)`), `build_bind_rig`, `export_glb(rig, objs, path, texcoords, morph)`, `godot_xf, xf12, g2b`, paths (`FRONTIER, LIBS, BIND_LIB`), `PROVENANCE_RIG`. |
| `body_shapes` | `BodyParams()` (female base = the legacy body exactly) and `BodyParams.male()`; `FACE_FEATURES` and `face_params(P, feature)`; part SDFs `torso_shapes, neck_shape, head_shapes, arm_shapes, hand_shapes, leg_shapes, foot_shapes`; `body_groups(K, P)`, `body_node(groups)`; `body_sizing(K, max_edge)`; `brows_node`; `forearm_param, segment_param, eye_center`. |
| `regions` | `REGIONS`, `REGION_LIST`, `HAIR_ZONES`, `region_group(name)`, `WEATHER`, `encode`, `mask_bits`, `regions_json`; `border_planes(K)`, `cut_planes(ob, planes, labeler)`, `cut_borders(ob, K, groups)`, `face_regions`, `classify_faces`, `write_region_uv(ob, codes_per_polygon, h_per_loop)`. |
| `layers` | `ENVELOPES[group][layer] = (inner min, outer max)` clearance above the skin; `envelope_node(K, layer, which)` (the body SDF offset by it: build garments against the band below); `check_envelope(body, V, region_of_vertex, layer, sdf)`. Layer values are `catalog.LAYERS`. |
| `weights` | `body_weights`, `joint_plane_splits`, `helper_weights` (twist and armpit helpers), `skirt_weights(V, bones, hem, vent_top)`, `queue_weights`, `transfer_weights / transfer_from_tris`, `sleeve_factor`, `rigid_islands`, `band_smooth`, `chain_weights`, `smooth_weights`, `limit_normalize`, `write_groups`. |
| `helpers` | `HELPERS` table and skirt / queue / twist constants (single source of truth; `CharacterBodyMesh` must match, `check_body_attach.gd` verifies); `helpers_json()`; `drive_helpers` (Python twin of the game driver); `driver_reference`. `QUEUE_ROOT` = the pendulum root at the nape. |
| `shapes` | `project_shape(V, target_sdf, edges, ...)`, `add_shape_keys(ob, {name: delta})`, `shape_stats`. |
| `wrap` | `Surface(V, F, shapes, allowed)`: `nearest(P)`, `interpolate(values, tri, bary)`, `bind(P)`, `shape_delta(binding, "sex", smooth_E)`; `smooth_field`, `vertex_normals`. |
| `uv` | `Segment(name, a, b, ref, radius, v0)` (cylindrical, seam opposite `ref`), `Planar`; `segment_uvs(ob, parts, part_of_polygon)`, `write`, `ensure_layers`, `body_parts`. |
| `bands` | `boundary_verts(ob, select)`, `edge_distance(ob, sources)` (geodesic), `write_edge_uv(ob, d_hem, d_open)`. |
| `cards` | `Card(points, widths, normal_hint)`, `cards_object(name, cards, mat)` -> (object, h per vertex, card per vertex), `bezier`, `resample`. |
| `fur` | `shells(base_ob, n, max_tris)` -> (object, h per vertex); `guard_cards(base_ob, count, length, width, comb)`; `surface_samples`. |
| `materials` | `FABRICS` (bible code -> kit, tile metres), `TOKENS` (bible palette hex), `ROLES`, `token_hex`, `preview_material`. |
| `catalog` | `GarmentSpec(...)` / `Zone(...)`; `SLOTS, SETS, LAYERS, SET_TOOLTIPS`; `validate_entry` (schema, grade C licence note, grade-X and respectful-terms lint `DENY_TERMS`, budgets); `write_fragment`; `merge_catalog()` -> `assets/character/catalog.json`. |
| `context` | `BuildContext()` (rig, `K`, `bones` = weight columns, `body_sdf(P)`, `bind_rig()`, `body()`); `BodyData` (the body cache `tools/character/cache/body_v1.npz`: V, F, W, bones, vlab, freg, shapes). |
| `pipeline` | `Surface(ob, zones, regions, h, weights, uv, edge, colors)`; `finish_part(ctx, spec, {surface: Surface})`; `build_part(ctx, module)`; `body_weights_at(ctx, P, torso_only)`, `garment_body_weights(ctx, ob)`, `rigid_weights`. |
| `preview` | `setup_preview_scene`, `render_view`, `contact_sheet`, `posed_previews(src_rig, bind_rig, base, outdir, co, G, prefix, clips)`. |

## Writing a part

A module `tools/character/garments/<set>/<id>.py` (or `hair/<id>.py`) defines `SPEC` and
`build(ctx)`; the driver runs it:

```python
from lib.catalog import GarmentSpec, Zone
from lib.pipeline import Surface
from lib import layers, bands, uv as UV
from lib.sdf import Inter, Onion, Offset, zslab
from lib.remesh import sdf_object, material

SPEC = GarmentSpec(id="ew_leggings_m", name="Wool leggings, ribbon-edged", set="woodlands", slot="legs.over",
                   layer={"default": 30}, zones=[Zone(0, "cloth", "WOOL", ["stroud_blue", "stroud_red"])],
                   weights="body", evidence="A", sources=["M1", "P1"], hides_regions=[...], budget={"tris_max": 2800})

def build(ctx):
    base = layers.envelope_node(ctx.K, "mid", which=1)       # the band below: legwear sits on it
    node = Inter(Onion(Offset(base, 0.004), 0.0015), zslab(0.08, 0.62))
    ob = sdf_object(SPEC.id, node, 0.003, 2400, material(SPEC.id, "#1e2b4a"), sizing=lambda P: ...)
    return {"main": Surface(ob, uv=my_uvs, edge=(d_hem, d_open))}
```

`finish_part` then writes the Region codes (region = the nearest body triangle's region;
zone = the polygon's material slot unless `zones=` is given), transfers the body weights
(`weights="body"`: nearest point, torso-only above the waist), adds `sex` by wrap
transfer, checks the envelope of the layer, the triangle budget and the catalog rules,
exports `assets/character/garments/<set>/<id>.glb` (+ `.import` without LODs or shadow
meshes, which would merge vertices across region borders) and the catalog fragment.
Then: `Godot --headless --path . --import` and the checks (see `tools/character/README.md`).

Grade-X items of the costume bible (§3.6) never enter the catalog; `validate_entry`
rejects their names, and the UI terms the bible lists, in ids, names and descriptions.
