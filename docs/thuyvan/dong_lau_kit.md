# Thủy Vân Reed Marches stilt kit (Đồng Lau, `dl_*`): how to rebuild

The Reed Marches kit of `places_se.md` §3 (the PLACES_SE design, in the session scratchpad's `peoples_places/`), in the
look of the style guide (`docs/thuyvan/plan/look/style_guide.md`): forests of fat piles, a three-tier thatch mooring
fort, Floodborn-built houses, haul-out ramps, reed watch towers, our own heron banners, mangroves with root arches, reed
cards, the burial reed boat, dugouts and the flat ferry, tally posts and the submerged causeway. Own work only
(`assets/thuyvan/dong_lau/SOURCE.md`).

| What | Where |
| --- | --- |
| Generators | `tools/thuyvan_art/dong_lau/` |
| Textures (PNG, sRGB; RGBA for `net`, `reedcard`) | `assets/thuyvan/dong_lau/textures/<key>.png` |
| Meshes (GLB, +Y up, metres), `<piece>_lod1.glb`, `manifest.json` | `assets/thuyvan/dong_lau/` |
| Material table (keys, ramps, tile sizes, roughness, specular, emission, alpha) | `tools/thuyvan_art/dong_lau/materials.json` |
| Heron marks (A standing, B in the ring, C between reeds) | `tools/thuyvan_art/dong_lau/dl_marks.py` |
| Review light directions (two from places_se.md §9.4, one PROPOSAL) | `tools/thuyvan_art/dong_lau/directions.json` |
| Palette (the art director's file, read in place, never copied) | `docs/thuyvan/plan/look/palettes.json` → `albedo.dong_lau` (+ r1's rope, iron, bamboo, laterite, dyes, limestone) |

The kit reuses the village kit's code without editing it: `dlkit.py` imports `tools/thuyvan_art/village/tvkit.py`
(Builder, vertex-AO bake, GLB export) and rebinds its texture folder, material table and material function to this kit
(materials `tvd_<key>`); `dong_lau_kit.py` uses `village_kit.py`'s roof, wall, deck, ladder, lantern and cloth helpers;
`paint_dong_lau.py` uses `paint_village.py`'s canvas and painters and adds the marsh's own (pile, reed bundle, mangrove
bark, leaf clumps, fish, net, reed cards, tally face, old stone); the sky stand-ins use PAINT's `paint_sky.py`.

## Rebuild, in order

All scripts are deterministic (fixed seeds: CRC32 of the key for textures, fixed per-piece seeds for meshes). Blender
runs only through the shared-lock wrapper (`tools/thuyvan/bin/blender_run.sh`, `BLENDER_TIMEOUT` at most 1100).

1. **Paint the textures** (Python 3, numpy, Pillow; about 35 s):

       python3 tools/thuyvan_art/dong_lau/paint_dong_lau.py [--only key,key] [--check-dir DIR] [--sky-dir DIR]

   `--check-dir` writes each texture's 3 x 3 tiling and 1/16 squint and `paint_report.json`; `--sky-dir` paints the
   three marsh sky panoramas the review renders use (render-only stand-ins until PAINT owns the marsh skies).

2. **Build the meshes** (Blender 5.2, headless):

       zsh tools/thuyvan/bin/blender_run.sh -b --factory-startup -P tools/thuyvan_art/dong_lau/dong_lau_kit.py -- \
           --out assets/thuyvan/dong_lau [--blend /tmp/dl_kit.blend] [--only piece,piece] [--no-lod]

   One GLB per piece, `_lod1.glb` for the pieces with a LOD1 budget (Decimate collapse to the budget), and
   `manifest.json` (triangles, LOD1 triangles, the places_se.md budget, materials, sizes, anchors, colliders). `--blend`
   also keeps the review-only objects: the A/C variants of the open choices, the 1.75 m scale figure and a Book II
   look-dev stone lintel (never exported).

3. **Review renders** (Eevee 1920 x 1080; lineups with silhouettes, the A/B/C choices, the diorama):

       zsh tools/thuyvan/bin/blender_run.sh -b /tmp/dl_kit.blend -P tools/thuyvan_art/dong_lau/render_dong_lau.py -- \
           --review REVIEW --sky-dir SKY [--pages landmarks,houses,moorings,racks,boats,fort_abc,tower_abc] \
           [--diorama --dirs silver_overcast,heron_morning,smoke_and_lantern --cams arrival,tower,yard] [--fast]
       python3 tools/thuyvan_art/dong_lau/compose_dong_lau.py --dir REVIEW

   The diorama's water, reed sea (from the kit's own reed cards), mud banks, herons, smoke, mist bands, far hills (in
   the painted sky) and figures are render-only stand-ins; fog is folded into each material by camera distance
   (the game's fog does it in the engine); a planar probe gives the water its mirror.

## Conventions the pieces follow

- **Axes:** Blender Z up, a piece's front faces Blender -Y; exported with +Y up, so the front faces Godot +Z.
- **Origins:** over-water pieces sit with their origin on the **water line** (z 0) and their piles reach the bed at
  -1.8 m; land pieces (racks, the burial boat on its frame, the soaking trough, the lift net) on the ground or deck
  under them; boats on the water line.
- **Materials:** one per key, named `tvd_<key>`; UVs in tile units (1 UV = the key's `tile_m` metres; about 256 px/m
  on buildings), except the banner, tally and reed-card keys (`unit_uv`). `net` and `reedcard` are alpha-scissor
  (threshold 0.5). Only `paper` emits (lanterns, by direction). Roughness 0.7-1.0; no gloss, no normal maps.
- **Vertex colour (COLOR_0):** RGB = baked occlusion x a top-light gradient (mean about 0.85, clamped 0.5-1.0); A =
  cloth pin weight (banners, tails, screens, nets) or reed wind weight (0 at the root, 1 at the tip), 1 elsewhere.
- **Anchors:** `anchor_lantern*`, `anchor_smoke`, `anchor_hearth_light`, `anchor_door`, `anchor_mooring`,
  `anchor_banner`, `anchor_soak_trough`, `anchor_channel` (the mangrove's boat passage), `anchor_pole`.
- **Colliders:** `*-colonly` children on every walkable deck, gallery, landing, haul-out ramp, step run and the
  submerged causeway; the pile clusters carry a box `boat_block-colonly` so boats stop at them.
- **Built for every body (places_se.md §9.2):** Floodborn-built doors 2.8 x 1.8 m with no sill (the fort's three
  doors, house a); the public standard 2.4 x 1.3 m with an 8 cm sill (house b, the raft house); benches in runs with a
  0.5 m tail gap; a haul-out ramp or steps from every platform to the water.

## Canon guards

- Peoples are not classes: no piece, colour or banner is any people's; the heron is the moorings' common sign. The
  settlement in the diorama mixes Floodborn-built and human-standard houses.
- No Floodborn figures appear in any render until the Floodborn NPC body's grey box is approved (§3 "Needs before it
  is built"); the scale figures are humans.
- Not built: the Khar-Ul pieces (`kh_*`, Book II), the toll fort, toll posts, the dig platform, the dark tablet and Sha-Ra's
  clinic. The review-only lintel is Khar-Ul look-dev: its object name has no `kh_` id, it is never exported, and the
  diorama's caption says so.
- No writing, no Hán, no Avatar: The Last Airbender form; ids contain none of the guarded words.
