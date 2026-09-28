# Terrain assets (package B): sources and processing

Everything in this folder is either generated procedurally by the project's own tools or
derived from CC0 1.0 textures by Poly Haven (https://polyhaven.com). The originals stay
untouched in `assets/polyhaven/` (see `assets/polyhaven/MANIFEST.json` and `LICENSE.txt`).
Game code loads only the files below, never `res://assets/polyhaven/...`.

## Generated (no external source)

Written by `tools/environment/terrain/bake_terrain.py` (numpy, fixed seeds, deterministic)
and packed into Godot Image / Shape resources by `tools/environment/terrain/pack_terrain.gd`.

| File | Contents |
|---|---|
| `terrain_height.res` | 833 x 833 RF height field, 1 m per texel over x, z in [-416, 416] (x = i - 416). Exactly 0 in the flat zones (fort and its clearing, range lane). Rolling fBm, pit-and-mound microrelief, the west ridge, the north backstop hill, the east draw with a dry brook bed, the outer bowl and rock outcrops (look-dev spec 5.1) |
| `terrain_collision.res` | Same grid for the TerrainBody height maps: flat-zone samples 5 cm lower so the GroundFloor box wins there |
| `terrain_splat0.res`, `terrain_splat1.res` | RGBA8 control maps, 1 m: grass, dry grass, dirt, mud / forest floor, rock, forest density, grass height |
| `terrain_normal.res` | RGBA8: normal x/z, horizon ambient occlusion, broadleaf-litter share |
| `terrain_core.res` | RGBA8, 0.25 m over x in [-32, 32], z in [-184, 32]: mud (gate ruts, puddles), wear (worn paths), dirt coverage, grass height |
| `terrain_macro.res` | 256 px tileable macro noise (anti-tiling and colour variation) |
| `terrain_bounds.res` | 13 x 13 chunk min / max heights (culling boxes) |
| `terrain_grass_cells.res` | 104 x 104 maximum grass density per 8 m grass cell |
| `terrain_overlay_dirt.res`, `terrain_overlay_stone.res` | ConcavePolygonShape3D surface overlays (paths and brook bed; rock) |

## Derived from Poly Haven textures (CC0)

`textures/terrain_albedo_array.webp` and `textures/terrain_nrm_array.webp`: 7-slice vertical
strips (2048 x 14336), imported as `CompressedTexture2DArray` (BPTC, mipmaps). Written by
`tools/environment/terrain/process_textures.py`. Albedo slices hold the graded colour in RGB
and a blend height in A (0.55 AO + 0.45 high-passed luminance). Normal slices hold the OpenGL
normal in RG, roughness in B and AO in A (from the `nor_gl` and `arm` maps, unchanged).

| Slice | Poly Haven id | Source files (2K JPG) | Grading |
|---|---|---|---|
| 0 grass | `aerial_grass_rock` | [diff](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/aerial_grass_rock/aerial_grass_rock_diff_2k.jpg), [nor_gl](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/aerial_grass_rock/aerial_grass_rock_nor_gl_2k.jpg), [arm](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/aerial_grass_rock/aerial_grass_rock_arm_2k.jpg) | hue -3 deg, saturation x0.90 |
| 1 dry grass | `aerial_grass_rock` | as above | hue +12 deg, saturation x0.80, value +12 % |
| 2 dirt | `dirt_floor` | [diff](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/dirt_floor/dirt_floor_diff_2k.jpg), [nor_gl](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/dirt_floor/dirt_floor_nor_gl_2k.jpg), [arm](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/dirt_floor/dirt_floor_arm_2k.jpg) | linear value x0.62, saturation x0.85 |
| 3 mud | `mud_forest` | [diff](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/mud_forest/mud_forest_diff_2k.jpg), [nor_gl](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/mud_forest/mud_forest_nor_gl_2k.jpg), [arm](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/mud_forest/mud_forest_arm_2k.jpg) | linear value x1.35, saturation x0.90 |
| 4 forest floor | `forest_ground_04` | [diff](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/forest_ground_04/forest_ground_04_diff_2k.jpg), [nor_gl](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/forest_ground_04/forest_ground_04_nor_gl_2k.jpg), [arm](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/forest_ground_04/forest_ground_04_arm_2k.jpg) | saturation x0.92 (also the grass layer's close detail) |
| 5 rock | `forest_ground_04` | as above | linear value x0.80, saturation x0.40 (gravel/rock proxy until a rock texture is approved) |
| 6 leaves | `forest_leaves_04` | [diff](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/forest_leaves_04/forest_leaves_04_diff_2k.jpg), [nor_gl](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/forest_leaves_04/forest_leaves_04_nor_gl_2k.jpg), [arm](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/forest_leaves_04/forest_leaves_04_arm_2k.jpg) | hue -4 deg, saturation x0.70 |

Further look tuning is done by linear tints in `shaders/terrain/terrain.gdshader`
(`grass_ground_tint`, `dry_ground_tint`, `dirt_tint`, `mud_tint`, `needle_tint`).

## Rebuild

```bash
python3 tools/environment/terrain/bake_terrain.py        # ~4 s
python3 tools/environment/terrain/process_textures.py    # a few minutes (WebP encoding)
Godot --headless --path . -s tools/environment/terrain/pack_terrain.gd
Godot --headless --path . --import                       # reimports the texture arrays
```
