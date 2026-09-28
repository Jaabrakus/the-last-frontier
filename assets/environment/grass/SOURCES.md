# Grass card atlas (package B): sources and processing

`grass_atlas.png` (2048 x 1024 RGBA, 4 x 4 cells of 512 x 256, imported BPTC with mipmaps) and
`grass_variants.json` (per cell: uv rect of the content, aspect, kind) are written by
`tools/environment/terrain/make_grass_atlas.py` (deterministic). Used by
`shaders/grass/grass.gdshader` through `scripts/world/terrain/grass.gd`.

| Cells | Source | Processing |
|---|---|---|
| 0-4 | Poly Haven `grass_medium_01` (CC0 1.0), the five photographed tuft renders at the bottom of [grass_medium_01_diff_2k.jpg](https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/grass_medium_01/grass_medium_01_diff_2k.jpg) | Cropped at each tuft's base line (the UV-padding smears below are cut off). The JPG has no alpha: alpha = smoothstep(0.02, 0.08, max(rgb)) (look-dev spec 7.1); edge colours divided by a soft coverage to remove the dark JPG fringe; scaled into the cell, bottom-aligned; colours dilated into the transparent texels for clean mipmaps |
| 5-7 | procedural | seed-head clumps: leafy base plus 5-8 stems with straw-coloured panicles |
| 8-10 | procedural | dry late-summer blade clumps (straw, tan, olive) |
| 11-12 | procedural | short dense tufts (mowed range turf) |
| 13-15 | procedural | sparse woodland sedge (forest floor) |

The original model and textures stay untouched in `assets/polyhaven/models/grass_medium_01/`
(see `assets/polyhaven/MANIFEST.json`).
