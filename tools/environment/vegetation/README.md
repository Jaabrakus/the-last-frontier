# Package C: vegetation tools

Everything under `assets/environment/vegetation/` and `assets/environment/props/` is generated
by these scripts (deterministic; re-run in this order after changing a generator). `$B` is
`/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P`, `$G` is
`/Applications/Godot_mono.app/Contents/MacOS/Godot --path <Frontier>`. Wrap every Godot run in a
time limit (a script error leaves it running).

| Step | Command | Output |
|---|---|---|
| 1 | `python3 make_textures.py` | graded bark, procedural birch bark, 1K prop textures with rebuilt alpha (contact sheet at `$VEG_SHEET`) |
| 2 | `$B build_atlas.py -- work=<dir>` then `python3 assemble_atlas.py work=<dir>` | foliage card atlas + `foliage_tiles.json` (tile rects, sizes, hexagonal cutouts) |
| 3 | `$B build_trees.py` | `trees/<species>.glb` (LOD0-2 drawn, LOD3 / LOD4 shadow proxies), `trees.json` |
| 4 | `$B process_props.py` | decimated Poly Haven props, `props.json` (sizes, LOD triangles, rock hulls) |
| 5 | `python3 import_settings.py` then `$G --headless --import` | VRAM compression, mipmaps, normal maps; glb without auto-LOD / shadow meshes |
| 6 | `$G -s tools/environment/vegetation/bake_impostors.gd -- work=<dir>` (windowed), `python3 assemble_impostors.py work=<dir>`, then step 5 again | 8-view impostor atlas + `impostors.json` |

Checks and measurements:

- `$G --headless -s tools/environment/vegetation/check_vegetation.gd` -> `VEGETATION CHECK PASSED`
  (protected sun rays, protected zones, collider / audio contract, determinism, counts).
- `$G --resolution 1280x720 -s tools/environment/vegetation/veg_shots.gd -- out=<dir> set=scenic|lod|close|lineup|all`
  (look-dev captures; `lineup` = neighbouring LODs side by side at each switch distance).
- `$G --resolution 1600x900 -s tools/environment/vegetation/veg_cost.gd -- poses=fort,aim,forest,lookback,aerial`
  (render cost, draws and primitives per vegetation category, interleaved A/B).
- `$G --headless -s tools/environment/vegetation/veg_probe.gd` (headless build time and collider counts).
- Runtime switches read by `scripts/world/vegetation/vegetation.gd`: `vegetation=off|notrees|noimpostors`,
  `veg_lod=<lod0>,<lod1>,<lod2>`, `veg_log=1`.
