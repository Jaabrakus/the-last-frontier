# Asset comparison lab stage

`scripts/labs/asset_lab_world.gd` builds two isolated comparison areas. `build()` returns the stage report; `spawn_at("map")` and `spawn_at("arena")` return world positions 0.25 m above their floor. The arena is centered at `(80, 0, 0)`, has a 20 × 20 m stone floor at Y=0, and low boundaries. Area changes use teleportation. This arrangement and its primitive geometry were authored for the lab; it does not reproduce a source game's map layout.

The terrain uses the retained Nintendo *Breath of the Wild* Wii U sample `artifacts/world_reference/terrain_sample/5000000000.hght` (SHA-256 `dd9d671ac1b6d1c75c3675d85d9e9c923bdc7fe0f20633af81aa759bd500514c`). The local container/member record is in `terrain_sample/resource_manifest.json`. The input is a 256 × 256 little-endian uint16 array. A centered 65 × 65 crop, indices 96 through 160 inclusive, is normalized from its observed raw range 0–47555 to 0–6 m and placed on a 1 m grid. Source world scale and source map registration remain unverified. These are source heights with preview normalization, not newly authored terrain data. If the retained file is absent or its hash differs, the helper reports a flat fallback and warns explicitly.

The rendered terrain mesh and `HeightMapShape3D` use the same centered height array and cell triangles. The fixed grid spacing follows [Godot's HeightMapShape3D documentation](https://docs.godotengine.org/en/stable/classes/class_heightmapshape3d.html); mesh arrays and clockwise front-face ordering follow [ArrayMesh documentation](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/arraymesh.html). The installed engine used for validation is Godot 4.7.2 stable Mono.

Four sapling birches, fourteen mature oak/birch/hemlock trees and three moss rocks retain existing project shapes selected through `VegAssets`, with one LOD each. Their placement is new. The tree shape input record is `assets/environment/vegetation/SOURCES.md`; the processed Poly Haven rock shape input record is `assets/environment/props/SOURCES.md`. Materials are duplicated or newly created for the lab, leaving shared production materials unchanged. These references describe the particular inputs and do not establish the origin of every bundled asset.

The lab uses banded diffuse shading, ambient energy 0.28, sun energy 0.8 and Filmic tone mapping. Six actual Nintendo world albedos are decoded into `artifacts/world_reference/world_textures/textures`, with their original names, compressed/decoded bank hashes, decoded PNG hashes and texture-array indices retained in `world_textures/manifest.json`. The images were inspected before assigning these preview roles:

| Role | Retained source image | Lab use |
| --- | --- | --- |
| Ground grass | `MaterialAlb.png`, terrain array layer 0 | Terrain and authored backdrop |
| Dirt | `MaterialAlb__array_010.png`, terrain array layer 10 | Terrain and backdrop blend |
| Stone | `CmnTex_Rock_GrayCliff_A_Alb.png` | Steep terrain, project rock shapes, arena floor/boundaries and training basins |
| Bark | `Wood_MossWood_A_Alb.png` | Existing project trunks |
| Leaf RGB | `Plant_TreeLeaf_B_Alb.png` | Existing project foliage cards |
| Grass blade | `GrassAlb.png` | Authored grass blade geometry |

`reference_terrain.gdshader` samples source grass/dirt/stone with 2 m triplanar tiling and blends them by stage height and slope. This placement is authored for the comparison; original source material weights, source world texture placement and source renderer are not reconstructed. `reference_tree.gdshader` keeps project shapes, branch wind and tiling bark UVs. Existing 4 × 4 foliage-card UVs are remapped to the two upper leafy islands of the actual source atlas. The current project leaf alpha mask is retained because its spray silhouettes and the source atlas islands differ; source RGB is used directly. Each authored grass blade has explicit 0–1 UVs and samples the complete source `GrassAlb` image using `reference_toon.gdshader`. Approximately 2,600 deterministic procedural grass tufts provide detail without collision.

Runtime image loading checks each PNG SHA-256 against the retained manifest and creates `ImageTexture` directly, without depending on generated import cache. `build().texture_sources` records source bank path/hash, original texture name, selected array layer, PNG path/hash, loading status and actual material usage. Missing files, wrong hashes and malformed manifests produce labelled material fallbacks; `texture_fallback_roles` identifies affected roles. The authored vertex palette remains available for fallback and is converted from sRGB to linear RGB. Shader sampling and image upload follow [Godot's spatial shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) and [ImageTexture](https://docs.godotengine.org/en/stable/classes/class_imagetexture.html) contracts.

A broad ground plane and four primitive hill silhouettes hide the surrounding void. These visual-only surroundings are independently authored, have no collision, and do not extend or reconstruct the source terrain crop. None of these lab presentation settings changes production environment defaults. The player's model choice is owned by the separate lab controller; this world helper does not replace characters.

Two visible stone training basins join `Bending.POOLS`. Their lab-specific reach is 50 m on the map and 25 m in the arena, covering the arena's corners and the map spawn so water casting can be compared. This extended training reach does not change production water rules. The water surface is a simple presentation plane, not a fluid simulation.

Run the focused physics check with:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --log-file /private/tmp/asset-lab-world-check.log --script tools/reference_world/check_asset_lab_world.gd
```

The check passed 461 assertions: sample/hash/dimensions, loaded props, non-colliding grass/backdrop, 147 downward terrain rays at grid and fractional positions, arena floor rays, map/arena spawn clearance, and water-source reach. The maximum terrain mesh versus physics height difference was 0.0000020403 m. Terrain ray comparisons exclude props and basins to measure the height shape itself. Results are written to ignored `artifacts/world_reference/lab_world_check.json`. This test measures geometry and collision agreement; visual evaluation belongs to the combined lab render.

The first revised environment was rendered on Metal Forward+ and visually inspected in `artifacts/world_reference/lab_world_style.png`: the prior pale ground was replaced by green terrain, painted tree light/shadow bands and visible grass detail; the authored distant hills replace the empty backdrop. That initial image predates source texture binding. The final source-texture comparison is captured by `tools/reference_world/test_assets_lab.gd`; it establishes the lab presentation and current player are visible, not visual parity with the original game's world or character.
