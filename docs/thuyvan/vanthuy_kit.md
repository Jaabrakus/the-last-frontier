# Thủy Vân Vạn Thủy kit (VANTHUY): how to rebuild

The lock-district kit of Vạn Thủy, Capital of the Waters (places_se.md page 1, build order 1), in the look of the
style guide (`docs/thuyvan/plan/look/style_guide.md`): World of Warcraft Classic spirit, hand-painted tiling textures,
chunky exaggerated forms (the Court Tower 95 m above the water, gate towers 46 m, winch wheels 7 m, piles and ropes
about 2x, lanterns and banners 1.3-1.5x), roofs 45-55% of a building's height with fat upturned eaves, curled ridge
ends and corner hooks (gilt on the court only). No cel shading, no outlines, no script in world art. Own work only
(`assets/thuyvan/vanthuy/SOURCE.md`).

| What | Where |
| --- | --- |
| Generators | `tools/thuyvan_art/vanthuy/` (`.gdignore`d) |
| Textures (PNG, sRGB) | `assets/thuyvan/vanthuy/textures/<key>.png` |
| Meshes (GLB, +Y up, metres), LOD1s and `manifest.json` | `assets/thuyvan/vanthuy/` |
| Material table (keys, ramps, tile sizes, roughness, specular, emission, PROPOSAL ramps) | `tools/thuyvan_art/vanthuy/materials.json` |
| Palette (the art director's file, read in place; no copy, as the kits do since 5e7518b) | `docs/thuyvan/plan/look/palettes.json` (`albedo.van_thuy`; `albedo.r1` for rope, iron, plaster, paper, cloth dyes, bamboo, thatch, laterite) |
| Our own marks (the Cửu Giang court mark A/B/C, five district marks) | `tools/thuyvan_art/vanthuy/marks_vt.py` |

## Rebuild, in order

Everything is deterministic (fixed seeds): a rebuild gives the same textures byte for byte and the same meshes.
Blender runs only through the shared-lock wrapper (`tools/thuyvan/bin/blender_run.sh`, `BLENDER_TIMEOUT` at most 1100).

1. **Paint the textures** (Python 3, numpy and Pillow; about 1 min):

       python3 tools/thuyvan_art/vanthuy/paint_vanthuy.py [--only key,key] [--check-dir DIR]

   The brush engine is the VILLAGE painter (`tools/thuyvan_art/village/paint_village.py`), imported unchanged, so the
   two kits read as one hand; this kit adds ashlar coursing with pale patched blocks, quay paving, bronze with
   verdigris, battened sail cloth, the court and district banners, the gate plaque and the blank notice sheets.
   `--check-dir` writes each texture's 3 x 3 tiling + 1/16 squint and `paint_report.json`.

2. **Build the meshes** (Blender 5.2, headless; most of the time is the baked vertex occlusion):

       zsh tools/thuyvan/bin/blender_run.sh -b -P tools/thuyvan_art/vanthuy/vt_kit.py -- \
           --out assets/thuyvan/vanthuy [--blend /tmp/vt_kit.blend] [--only piece,piece]

   One GLB per piece, `<piece>_lod1.glb` where the budget names an LOD1, and `manifest.json` (triangles per LOD against
   places_se.md's budgets, material keys, sizes, anchors, colliders). `--blend` saves the scene for the review renders.
   The geometry helpers are the VILLAGE kit's `tvkit.py`, loaded as a private module instance by `vtkit.py` and pointed
   at this kit's materials (`tvvt_<key>`), and its `roof()`, `wall()`, `cloth_sheet()` and `lantern_round()`.

3. **Review renders** (Eevee, 1920 x 1080; lineups with the 1.75 m figure and silhouettes, the A/B/C pages, and the
   diorama from three cameras in four lights):

       zsh tools/thuyvan/bin/blender_run.sh -b /tmp/vt_kit.blend -P tools/thuyvan_art/vanthuy/render_vanthuy.py -- \
           --out REVIEW [--pages landmarks,tower_abc,court,marks_abc,lock,quay,piers,boats,bridge,archive_night,diorama] \
           [--dirs morning,noon,dusk,night] [--cams steps,overview,gate] [--fast]
       python3 tools/thuyvan_art/vanthuy/compose_vanthuy.py --dir REVIEW --checks DIR

   Split the pages over several runs to stay under the 1100 s cap (the diorama renders about a minute per frame). The
   diorama's water, islands, trees, mist, smoke, birds, far karst islands (the ROCK kit's own meshes), figures and
   sampans (the VILLAGE kit's) are render-only stand-ins; the sky is PAINT's painted panorama (night: a gradient).

## The shared lock kit (lock_*): a block-in, owned by Phase 3 M2

No lock kit existed on 2026-10-06. The plan builds ONE shared lock kit for Phase 3 M2's Fifth Lock and has Vạn Thủy scale
it up, so the `lock_*` pieces here are that kit's **first block-in pieces at the Fifth Lock's own scale**: chamber wall
module, gate tower (29 m), gate leaf pair (closed and open; chamber 37.5 m, leaves 14 m), winch wheel (4.4 m), sluice
port and gate gallery. Vạn Thủy places them **x1.6** (manifest `vt_scale_for_lock_pieces`): gate towers 46 m, leaves
22 m, the chamber 60 m, winch wheels 7 m. Phase 3 M2 takes them over (and may move them to `assets/thuyvan/lock/`);
nobody builds a second lock kit. Scaling stretches their texel density 1.6x; M2's finished kit can carry VT-scale
UVs if that shows.

## Conventions the pieces follow

- **Axes:** Blender Z up, a piece's front faces Blender -Y; exported with +Y up, so the front faces Godot +Z. Origins
  sit on the ground, or on the water line for pieces standing in water (lock pieces, quay walls and steps, piers,
  boats, the high bridge, the archive walls, the canal house).
- **Materials:** one per key, named `tvvt_<key>`; UVs in tile units (1 UV = the key's `tile_m` metres: about 256 px/m
  on buildings, 170 px/m on the big ashlar), except the banners, plaque and notice (`unit_uv`). No normal maps.
  Roughness 0.85-1.0; lacquer and gilt the only gloss. `paper` and `oil_glass` carry emission (off by day; the blue oil
  #8fc8ff is the Seventh Tide's night).
- **Vertex colour (COLOR_0):** RGB = baked occlusion x a top-light gradient (mean about 0.85, clamped 0.5-1.0); the
  stone keys are darkened green-black under each piece's silt line (lock walls, quays, archive walls; the drain mouth's
  streak). A = cloth pin weight on cloth (banners, tails, awnings, sails), 1 elsewhere.
- **Cloth:** junk sails are a separate child mesh `<junk>_sails` (wind cloth); banners and awnings are cloth keys.
- **Anchors:** empties `anchor_*` for lanterns, smoke, doors, door lamps, banners, mooring points, the hoist, the bell,
  the winch, sluice spouts.
- **Colliders:** `*-colonly` children on every walkable deck: lock wall coping, gate catwalk, tower gallery, gate
  gallery, court terraces, podiums, quay walls, canal steps, pier decks and landings, the high bridge (hump and both
  stair ramps), junk decks, the market barge.
- **Doors:** public doors 2.4 x 1.3 m (places_se.md 9.2 standard); Floodborn-built places are the Reed Marches kit's.

## Canon guards in this kit

- No mark is writing: the court mark is a picture of a gate (towers, leaf, wave) in a ring; district marks are a net
  knot, a sheaf, a hull, stacked tablets and umbrella ribs. Never "Thủy Vân", the sheets' roundels or seal, a river list
  or numerals. The archive gauge is cut with tallies. The notice sheets are blank (text at run time in the approved OFL
  font).
- No piece, banner or colour belongs to a people; district colours belong to districts (institutions).
- Ids contain none of the guarded words.

## Triangles (2026-10-06 build)

Over budget: `vt_lacquer_tower` (about 8.2k against 5-7k) and `vt_court_terrace_1` (about 5.4k against 3-5k, the gate
facade's studs and voussoirs). Not built yet: the Court Tower's far card, the junks' far cards, and places_se.md's
later pieces (footbridge, boat shed, prison barge, archive and ancestor halls, eel baskets, net racks, rope walk).

| Piece | LOD0 | LOD1 | Budget (places_se.md 1) |
| --- | --- | --- | --- |
| `lock_chamber_wall` | 578 | 500 | 1-2k / 500 (shared lock kit block-in) |
| `lock_gate_gallery` | 1,776 | 500 | 1.5-2.5k / 500 (block-in) |
| `lock_gate_leaf_pair` | 1,176 | 800 | 2-3k / 800 (block-in) |
| `lock_gate_leaf_pair_open` | 1,176 | 800 | 2-3k / 800 (block-in) |
| `lock_gate_tower` | 4,856 | 1,153 | 4-6k / 1.2k |
| `lock_sluice_port` | 250 | - | 300-600 (block-in) |
| `lock_winch_wheel` | 960 | 391 | 1-1.5k / 400 (block-in) |
| `vt_archive_wall` | 1,116 | - | 1-2k per 10 m |
| `vt_archive_wall_gauge` | 1,344 | - | 1-2k per 10 m |
| `vt_awning_madder` | 212 | - | 1.5-2.5k (with barge) |
| `vt_awning_ochre` | 212 | - | 1.5-2.5k (with barge) |
| `vt_court_banner` | 348 | 79 | 300 / 80 |
| `vt_court_terrace_1` | 5,438 | 952 | 3-5k / 1k each |
| `vt_court_terrace_2` | 3,234 | 996 | 3-5k / 1k each |
| `vt_court_terrace_3` | 3,014 | 996 | 3-5k / 1k each |
| `vt_court_tower` | 12,458 | 2,818 | 10-14k / 3k / card |
| `vt_crates_stack` | 284 | - | 500-1.5k |
| `vt_district_banner_archive` | 258 | 80 | 200-400 / 80 |
| `vt_district_banner_grain_piers` | 258 | 80 | 200-400 / 80 |
| `vt_district_banner_lantern_ward` | 258 | 80 | 200-400 / 80 |
| `vt_district_banner_naval_basin` | 258 | 80 | 200-400 / 80 |
| `vt_district_banner_rain_market` | 258 | 80 | 200-400 / 80 |
| `vt_door_lamp` | 76 | - | 150 |
| `vt_drain_mouth` | 292 | - | 300 |
| `vt_granary_hall` | 3,742 | 1,191 | 4-6k / 1.2k |
| `vt_high_bridge` | 3,586 | 1,498 | 5-8k / 1.5k |
| `vt_high_bridge_closed` | 3,658 | 1,492 | 5-8k / 1.5k |
| `vt_jars_cluster` | 882 | - | 500-1.5k |
| `vt_junk_river` | 1,794 + sails 322 | 1,500 | 5-8k / 1.5k / card |
| `vt_junk_sea` | 1,828 + sails 548 | 1,500 | 5-8k / 1.5k / card |
| `vt_lacquer_tower` | 8,218 | 1,426 | 5-7k / 1.5k / 300 |
| `vt_lantern_net` | 368 | - | 200 per 10 lanterns |
| `vt_market_barge` | 1,230 | - | 1.5-2.5k |
| `vt_notice_board` | 410 | - | 300 |
| `vt_pier_finger` | 996 | - | 1-2k |
| `vt_pier_finger_end` | 1,324 | - | 1-2k |
| `vt_quay_house_a` | 4,032 | 831 | 3-5k / 900 / 150 |
| `vt_quay_house_b` | 4,888 | 758 | 3-5k / 900 / 150 |
| `vt_quay_house_c` | 3,976 | 827 | 3-5k / 900 / 150 |
| `vt_quay_steps` | 278 | - | 400-800 |
| `vt_quay_steps_patched` | 302 | - | 400-800 |
| `vt_quay_wall_20m` | 292 | - | 400-800 |
| `vt_sacks_heap` | 1,104 | - | 500-1.5k |
| `vt_treadwheel_crane` | 1,158 | 899 | 3-4k / 900 |
