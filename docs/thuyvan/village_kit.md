# Thủy Vân village kit (VILLAGE): how to rebuild

The Mountain Folk / Stone Children village kit for R1 (vista spec V01-V15), in the look of the style guide
(`docs/thuyvan/plan/look/style_guide.md`): hand-painted tiling textures, chunky silhouettes, fat roofs with upturned
eaves, thick ropes and planks. Own work only (`assets/thuyvan/village/SOURCE.md`).

| What | Where |
| --- | --- |
| Generators | `tools/thuyvan_art/village/` |
| Textures (PNG, sRGB) | `assets/thuyvan/village/textures/<key>.png` |
| Meshes (GLB, +Y up, metres) and `manifest.json` | `assets/thuyvan/village/` |
| Material table (keys, tile sizes, roughness, specular, emission) | `tools/thuyvan_art/village/materials.json` |
| Palette (the art director's file, read in place) | `docs/thuyvan/plan/look/palettes.json` |

## Rebuild, in order

All scripts are deterministic (fixed seeds); a rebuild gives the same textures byte for byte and the same meshes.
Blender runs only through the shared-lock wrapper (`tools/thuyvan/bin/blender_run.sh`, `BLENDER_TIMEOUT` at most 1100).

1. **Paint the textures** (Python 3 with numpy and Pillow; about 30 s):

       python3 tools/thuyvan_art/village/paint_village.py [--only key,key] [--check-dir DIR]

   `--check-dir` also writes each texture's 3 x 3 tiling and 1/16 squint (`<key>_check.png`) and `paint_report.json`
   (mean value per texture against the style guide's value budget).

2. **Build the meshes** (Blender 5.2, headless; about 4 min, most of it the baked vertex occlusion):

       zsh tools/thuyvan/bin/blender_run.sh -b -P tools/thuyvan_art/village/village_kit.py -- \
           --out assets/thuyvan/village [--blend /tmp/kit.blend] [--only piece,piece]

   One GLB per piece, plus `manifest.json`. `--blend` saves the built scene for the review renders.

3. **Review renders** (Eevee; lineups, silhouettes, the roof A/B/C, the rope bridge, a diorama in the three light
   directions):

       zsh tools/thuyvan/bin/blender_run.sh -b /tmp/kit.blend -P tools/thuyvan_art/village/render_village.py -- \
           --out LOOK/VILLAGE [--pages houses,halls,waystone,terrace,clutter,people,bridge,roofs,diorama] [--dirs noon,morning,dusk] [--fast]
       python3 tools/thuyvan_art/village/compose_village.py --dir LOOK/VILLAGE

   The diorama's ground, water, trees, falls, mist, far karst and sky are render-only stand-ins (PAINT and ROCK build
   the real ones); only the kit pieces in it are assets.

## Conventions the pieces follow

- **Axes:** Blender Z up, a piece's front faces Blender -Y; exported with +Y up, so the front faces Godot +Z.
  Origins sit on the ground under the piece (the cliff house: on the lip line, drop toward -Y; rope bridge modules:
  the deck surface at the span's start; prayer flags: the rope's start).
- **Materials:** one per key, named `tvv_<key>`; UVs are in tile units (1 UV = the key's `tile_m` metres, so the
  painted texel density is about 256 px/m), except the banner, flag and waystone keys (`unit_uv`), which map their
  whole texture once.
- **Vertex colour (COLOR_0):** RGB = baked occlusion x a top-light gradient (mean about 0.85, clamped 0.5-1.0), to be
  multiplied into the albedo; A = cloth pin weight (0 at the pole or rope, 1 at the free hem) on cloth, 1 elsewhere.
- **Anchors:** empties named `anchor_*` (smoke under the eaves, door, lanterns and lamps for the dusk lights, mooring).
- **Colliders:** child meshes `*-colonly` on the walkable rope-bridge decks and platforms (Godot makes them static
  trimesh bodies).
