# Package C natural props: sources and processing

Decimated copies of approved Poly Haven models (CC0 1.0, see `assets/polyhaven/LICENSE.txt` and
`MANIFEST.json`), made by `tools/environment/vegetation/process_props.py` (Blender: node transforms
applied, vertices welded, origin at the bottom centre, Decimate (collapse) to the LOD budgets of the
look-dev spec, section 7.1) and `make_textures.py` (`props()`: 1K copies of the textures; the
rock sets' separate roughness map is packed into an ORM "arm" map). `props.json` lists per variant
the size, the triangles per LOD and a convex hull (from LOD2) used for the rock colliders.

| Folder | Variants (LOD triangles) | Processing notes |
|---|---|---|
| `tree_stump_01` | stump_a (3000 / 800 / 200) | |
| `tree_stump_02` | stump_b (3000 / 800 / 200) | |
| `rock_moss_set_01` | rock_a = rock02, rock_b = rock04, rock_c = rock06 (2000 / 700 / 200) | 3 of the 6 rocks |
| `rock_moss_set_02` | rock_d = rock09, rock_e = rock12 (2000 / 700 / 200) | 2 of the 7 rocks |
| `boulder_01` | boulder (3000 / 800 / 200) | |
| `dead_tree_trunk` | log (4000 / 1000 / 250) | |
| `root_cluster_01` | roots (3000 / 800 / 300) | |
| `dry_branches_medium_01` | brush (4000 / 1000 / 250) | the three pieces stacked 6x into a brush pile |
| `fern_02` | fern_a..d (784-1500 / 400) | alpha rebuilt from the ARM map: alpha = roughness < 0.97 (ARM is pure yellow outside the fronds) |
| `shrub_04` | textures only (the sprig is rendered into the foliage atlas) | alpha rebuilt: alpha = AO > 0.1 (ARM is green with R = 0 outside the leaves). The model's leaf islands cannot be decimated below ~700 triangles per sprig, so it is not used as a mesh |

`shrub_02` is not used: its maps carry no usable mask (the padding is a horizontal smear; the
detector in `make_textures.py` could not separate it from the leaves). The 2K diffuse PNG with
alpha would fix that (owner approval needed; see the package C report).

Poly Haven source URLs:
- tree_stump_01
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/tree_stump_01/tree_stump_01_2k.gltf
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/tree_stump_01/tree_stump_01.bin
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/tree_stump_01/tree_stump_01_nor_gl_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/tree_stump_01/tree_stump_01_diff_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/tree_stump_01/tree_stump_01_arm_2k.jpg
- tree_stump_02
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/tree_stump_02/tree_stump_02_2k.gltf
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/tree_stump_02/tree_stump_02_diff_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/tree_stump_02/tree_stump_02_arm_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/tree_stump_02/tree_stump_02.bin
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/tree_stump_02/tree_stump_02_nor_gl_2k.jpg
- rock_moss_set_01
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/rock_moss_set_01/rock_moss_set_01_2k.gltf
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/rock_moss_set_01/rock_moss_set_01.bin
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/rock_moss_set_01/rock_moss_set_01_diff_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/rock_moss_set_01/rock_moss_set_01_nor_gl_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/rock_moss_set_01/rock_moss_set_01_rough_2k.jpg
- rock_moss_set_02
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/rock_moss_set_02/rock_moss_set_02_2k.gltf
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/rock_moss_set_02/rock_moss_set_02_diff_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/rock_moss_set_02/rock_moss_set_02.bin
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/rock_moss_set_02/rock_moss_set_02_nor_gl_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/rock_moss_set_02/rock_moss_set_02_rough_2k.jpg
- boulder_01
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/boulder_01/boulder_01_2k.gltf
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/boulder_01/boulder_01_nor_gl_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/boulder_01/boulder_01_diff_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/boulder_01/boulder_01.bin
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/boulder_01/boulder_01_arm_2k.jpg
- dead_tree_trunk
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/dead_tree_trunk/dead_tree_trunk_2k.gltf
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/dead_tree_trunk/dead_tree_trunk_diff_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/dead_tree_trunk/dead_tree_trunk_arm_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/dead_tree_trunk/dead_tree_trunk_nor_gl_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/dead_tree_trunk/dead_tree_trunk.bin
- root_cluster_01
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/root_cluster_01/root_cluster_01_2k.gltf
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/root_cluster_01/root_cluster_01_nor_gl_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/root_cluster_01/root_cluster_01_arm_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/root_cluster_01/root_cluster_01_diff_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/root_cluster_01/root_cluster_01.bin
- dry_branches_medium_01
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/dry_branches_medium_01/dry_branches_medium_01_2k.gltf
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/dry_branches_medium_01/dry_branches_medium_01_nor_gl_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/dry_branches_medium_01/dry_branches_medium_01_arm_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/dry_branches_medium_01/dry_branches_medium_01_diff_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/dry_branches_medium_01/dry_branches_medium_01.bin
- fern_02
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/fern_02/fern_02_2k.gltf
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/fern_02/fern_02_diff_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/fern_02/fern_02_arm_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/fern_02/fern_02.bin
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/fern_02/fern_02_nor_gl_2k.jpg
- shrub_04
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/shrub_04/shrub_04_2k.gltf
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/shrub_04/shrub_04_arm_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/gltf/4k/shrub_04/shrub_04.bin
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/shrub_04/shrub_04_nor_gl_2k.jpg
  - https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/shrub_04/shrub_04_diff_2k.jpg
