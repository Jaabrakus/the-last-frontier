# Thủy Vân ROCK kit: how to rebuild

The kit covers R01-R08 of the vista spec (`docs/thuyvan/plan/look/vista_spec.md`):
- karst hero and backdrop towers
- gorge-wall modules
- boulders
- the white stones of Đá Trắng and their C1 scatter
- the Two Heights bridge and its stone heads
- the bridge needle
- burial cairns

Each script is deterministic, with fixed seeds. Run them from the repo root, in this order.

1. **Textures** (plain python3, numpy and PIL; about 1 minute):

   ```
   python3 tools/thuyvan_art/rock/rock_paint.py
   ```

   This writes `assets/thuyvan/rock/textures/*.png`, each with its `_check.png` (3×3 tiling and squint), and
   `rock_textures.json`.
2. **Meshes and lineup renders** (Blender 5.x, headless, only through the shared lock wrapper):

   ```
   zsh tools/thuyvan/bin/blender_run.sh -b -P tools/thuyvan_art/rock/rock_render.py -- \
       --out assets/thuyvan/rock --look <plan>/look/ROCK [--bake <build_regions/r1>]
   ```

   `--bake` puts the Two Heights renders on the real T4 ground. Without it, they use a stand-in gorge.

   This builds the kit, exports every piece and its `_lod1` as GLB (+Y up), writes `rock_kit.json`, and renders the
   lineups and the diorama to `<look>/raw/`. To export without rendering, use `rock_kit.py -- --out
   assets/thuyvan/rock` instead.
3. **Captions** (plain python3):

   ```
   python3 tools/thuyvan_art/rock/rock_compose.py --look <plan>/look/ROCK
   ```

   This writes the captioned lineups `<look>/*.png` and `ROCK_contact.png`.
4. **Godot materials:**

   ```
   python3 tools/thuyvan_art/rock/write_godot_materials.py
   ```

   This writes `assets/thuyvan/rock/materials/<key>.tres` from `rock_kit.json`.
5. **White-stone scatter:**

   ```
   python3 tools/thuyvan_art/rock/scatter_white_stones.py --bake <build_regions/r1>
   ```

   The bake is the T4 R1 bake, which `tools/environment/terrain/build_regions/r1` holds once
   `tools/environment/terrain/regions/bake_region.py` has run. The script writes
   `assets/thuyvan/rock/white_stones_c1.json`. It needs `rock_kit.json` for the stones' sizes.

Colours come only from `docs/thuyvan/plan/look/palettes.json`, the art director's file; no script retypes a hex
value.

## Conventions

**Frames.** Blender (x, y, z) maps to Godot (x, z up, -y), and every piece's front faces Godot +Z.

**Origins:**
- Towers, boulders, stones and cairns: on the ground at the foot. Each has a 6 m buried foot, or about 20-25% of its
  height sunk.
- Cliff modules: on the top lip's centre. The face hangs to -h.
- The Two Heights bridge: on the deck surface between the piers.

**Material keys** are the surface material names, listed in `rock_kit.json` under `materials`.

| Key | Use |
|---|---|
| `rock_karst` | Karst limestone |
| `rock_boulder` | Boulders |
| `rock_pale` | The needle |
| `stone_white` | The white river stones |
| `ashlar` | The bridge's dressed stone |
| `moss` | Ledge tops and the shrub mounds |
| `carve` | The maker signs |
| `iron` | The bolt plates |
| `cloth_*` | The offering rags |

**Vertex colour `Col`** (glTF `COLOR_0`):
- RGB: baked occlusion × a top-light gradient, linear, mean 0.85, clamped 0.5-1.0.
- A: the moss mask.

**Seats** are listed in `rock_kit.json` for each piece. They are in the piece's local Godot frame.

| Seat | What sits there |
|---|---|
| `pine` | Trees on ledges and mounds; `crown: true` marks the top |
| `house` | Wide ledges |
| `platform` | The needle's cap, for the rope bridge's mid platform |
| `gate_tower` | The tops of the stone heads |
| `banner` | Banners, with the cloth's facing |
| `rag_tie` | Offering rags |
| `maker_signs` | The two maker signs |
| `fall_lip` | The notch module's waterfall lip |

## In Godot (the vista step)

The Godot import and setup steps are listed below.

1. **Import** each `.glb` as a scene, with these import settings:
   - Root type `Node3D`
   - `meshes/generate_lods` on. Our `_lod1` files are the hand-made far LODs; use them as the Visibility Range far
     model.
   - Light baking off
   - `nodes/apply_root_scale` 1
2. **Materials:** run `write_godot_materials.py`, then map each surface to its key's `.tres`. There are two ways:
   - Per GLB: Advanced Import Settings > Materials > each name > Use External >
     `res://assets/thuyvan/rock/materials/<name>.tres`.
   - Or the RingDressing idiom: read `mesh.surface_get_material(i).resource_name` and set a surface override from the
     same folder.
3. **Painted-rock shader:** `assets/thuyvan/rock/painted_rock.gdshader` takes these uniforms:
   - `rock_tex`, `tile_m`
   - `moss_tex`, `moss_tile_m`, `moss_amount`
   - `object_space`, `macro_var`

   It multiplies the albedo by `COLOR.rgb` and blends moss by `COLOR.a` on up-facing faces. The kit's vertex colour
   is linear, so set no sRGB flag. The shader is Lambert-wrap lit, never unshaded, with no normal map.
4. **Placement:** use the frames and origins above, with the positions from `vista_spec.md` D7-D19.
   - Karst towers stand on the ground with their 6 m foot buried. Scale the backdrop towers uniformly to the K
     heights; they are modelled 200 m tall.
   - Cliff modules hang from the rim: put each origin on the lip, and chain modules by their 40 m width. Concave and
     convex modules curve on a 70 m radius.
   - The white stones come from `white_stones_c1.json`, one MultiMesh per node.
5. **Trees** go on the `pine` seats: PAINT's P07 karst pines and broadleaf puffs. The renders use stand-ins.

**Budgets (LOD0 / LOD1 triangles):**

| Piece | LOD0 | LOD1 |
|---|---|---|
| Hero towers | 2.0-5.4k | 0.8-2.4k |
| Backdrop towers | 1.2-1.7k | 0.8-1.4k |
| Cliff modules | 1.8-3.8k | 0.5-1.1k |
| Boulders | 320 | 80 |
| White stones | 60-200 each | — |
| Two Heights bridge | 3.0k | 1.5k |
| Stone heads | 2.5k | 1.0k |
| Needle | 0.7k | 0.3k |

All piece counts are in `rock_kit.json`.

## Known issues and findings

**V2 camera.** On the T4 bake, the Two Heights stand on a plateau (about 296 m) that is cut by a slot gorge about
40 m wide. From V2's spec camera (-380, 257, -600), the plateau rim hides the bridge. The R06 render raises the
camera 45 m. The vista step should move V2 or reshape the ground there.

**Head placement.** The stone heads are placed beside the deck's ends, offset 40 m east and west. This is the
earlier builder's proposal. D12 puts them on the deck's line, which would bury the road in them.
