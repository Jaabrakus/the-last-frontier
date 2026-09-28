# Structure assets: sources and processing (package D)

Everything here is derived from CC0 1.0 assets from Poly Haven (https://polyhaven.com), copied
from the read-only originals in `assets/polyhaven/` (see `assets/polyhaven/MANIFEST.json`), or
generated procedurally. Game code loads only these processed copies.

## textures/ (written by `tools/environment/structures/process_textures.py`)

| File | Source (Poly Haven id, map, URL) | Processing |
|---|---|---|
| `bark_palisade_albedo_2k.png` | `bark_brown_02` Diffuse, https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/bark_brown_02/bark_brown_02_diff_2k.jpg | linear-space grade: saturation x0.82, tint (1.04, 0.99, 0.97), mean linear luminance 0.105 |
| `bark_palisade_nor_gl_2k.jpg`, `bark_palisade_arm_2k.jpg` | `bark_brown_02` nor_gl / arm (same URL pattern) | unchanged copies |
| `boards_weathered_{albedo,nor_gl,arm}_2k.png` | `brown_planks_07` Diffuse / nor_gl / arm, https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/brown_planks_07/brown_planks_07_diff_2k.jpg | the four flat board faces (rows 285-525, 715-970, 1160-1398, 1915-2150 px) cut out between the lap grooves, each stretched to a 512 px row (normal v slope scaled to match); procedural grain streaks and drying checks added; albedo silvered (saturation x0.55, tint (1.04, 1.0, 0.94), mean linear luminance 0.18); texture AO softened |
| `shingles_riven_{albedo,nor_gl,arm}_2k.png` | `roof_planks` Diffuse / nor_gl, https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/roof_planks/roof_planks_diff_2k.jpg | desaturated to silver-brown (saturation x0.2), then cut into riven shingles along the board grain: 8 courses of 0.35 m over a 2.8 m tile, shingles 0.10-0.24 m wide with 3-6 px gaps, ragged butts, splits, per-shingle tint +-10 %; height, normal and AO/roughness generated (butt shadow under each course) and the source normal detail added |
| `fieldstone_albedo_2k.png` | `stacked_stone_wall` Diffuse, https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/stacked_stone_wall/stacked_stone_wall_diff_2k.jpg | saturation x0.3, tint (1.04, 1.0, 0.93), mean linear luminance 0.15 (was 0.072, red) |
| `fieldstone_nor_gl_2k.jpg`, `fieldstone_arm_2k.jpg` | `stacked_stone_wall` nor_gl / arm | unchanged copies |
| `straw_fibre_{albedo,nor_gl,arm}_1k.png`, `straw_fibre_grey_1k.png` | procedural (seed 1778) | tileable straw strands; golden albedo for the trusses, neutral grey (tinted by the dummy's colour) for the dummies |
| `wool_twill_{grey,nor_gl}_512.png` | procedural | tileable wool twill for the dummy coats and the flag |
| `structure_noise_512.png` | procedural | RGBA tileable noise for `shaders/structures/weathering.gdshaderinc` |

`grading_report.json` records the measured linear luminance of each graded albedo.
Import settings (`*.import`): VRAM compressed (BPTC), mipmaps, normal maps as RGTC.

## props/ (written by `tools/environment/structures/decimate_props.py`, Blender 5.2)

| File | Source | Processing |
|---|---|---|
| `stone_fire_pit_lod0.glb` | `stone_fire_pit` 2K glTF, https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/stone_fire_pit/stone_fire_pit_2k.gltf | collapse-decimated 3887 -> 2799 triangles, textures 1K |
| `wooden_axe_lod0.glb` | `wooden_axe` 2K glTF, https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/wooden_axe/wooden_axe_2k.gltf | 3348 -> 1799 triangles, textures 1K |
| `hatchet_lod0.glb` | `hatchet` 2K glTF, https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/hatchet/hatchet_2k.gltf | 5250 -> 1500 triangles, textures 1K |

The `*_lod0_*_2k.jpg` files next to the glb files are the textures Godot extracted from them on
import. They are 1K; Blender kept the original file names.
