# Thủy Vân art assets: sources

Everything under `assets/thuyvan/` is **made by us**: painted procedurally in Python (numpy, PIL) by the PAINT
look builder's brush engine (`tools/thuyvan_art/paint/tvp.py`), or modelled procedurally in Blender 5.2
(`tools/thuyvan_art/blender/`). No photographs, no downloaded art, no pixels from the owner's concept sheets (the
sheets are the target for shape, colour and mood only), nothing from World of Warcraft (principles only) or from
Avatar: The Last Airbender. Every generator is deterministic (fixed seeds) and re-runnable; colours come only from
the art director's `docs/thuyvan/plan/look/palettes.json`. Rebuild steps:
`docs/thuyvan/look_paint.md`.

| Asset | What | Made by (how) |
|---|---|---|
| `paint/terrain/tv_terrain_albedo_array.webp`, `terrain_slices.json` | P01: 12 painted terrain slices, 2048² each (8 m tiles, 256 px/m; the cliff face 16 m), 3 x 4 grid (6144 x 8192, lossless WebP), RGB albedo with painted light and AO, A = blend height. Slices: grass, terrace rice, forest floor, dirt path, laterite, paddy mud, karst rock, white stone gravel, moss and fern, wet river bank, cliff face, upland meadow | `paint/paint_terrain.py` (brush strokes with bristle streaks, three-pass strokes with painted light, warped Voronoi rock planes, cavity AO, squint limit) |
| `paint/rock/tv_karst_face_16m.png`, `tv_karst_face_16m_normal.png`, `tv_river_stone_4m.png`, `tv_cliff_moss_6m.png` | P02: rock tiling for meshes (karst face, the one soft normal from the painted height, white river stone, cliff moss) | `paint/paint_surfaces.py` (`rock()`) |
| `paint/trim/tv_village_trim.png`, `tv_village_trim.json` | P03: village trim sheet 2048² at 256 px/m: timber, weathered plank, roof tile, thatch, wood shingle, bamboo weave, plaster, rope, lacquer, iron | `paint/paint_surfaces.py` (`trim()`) |
| `paint/cloth/*` | P04: three clan marks (our own: straight cuts and one ring at most), banners (indigo, ochre, jade), prayer-flag rags, the waystone's carved-mark decal, the two Two Heights maker signs (bible L16) | `paint/paint_marks.py` |
| `paint/sky/tv_sky_<direction>.png`, `tv_skyline_karst_{0,1,2}.png`, `sky.json` | P05 painted sky panoramas (4096 x 2048 equirect) for Jade Mist Morning, Bright Saturated Noon, Golden Lantern Dusk; P06 far karst skyline cards (4096 x 512) | `paint/paint_sky.py` |
| `paint/foliage/tv_foliage_atlas.png`, `tv_foliage_tiles.json` | P07: painted leaf-dab cards, 16 tiles of 512 (broadleaf clumps, karst pine pads, bamboo sprays, banana leaf, fern fronds, flowering shrubs), the frontier's foliage_tiles.json format | `paint/paint_foliage.py` |
| `paint/foliage/tv_bark_broadleaf.png`, `tv_bark_pine.png`, `tv_bamboo_culm.png`, `tv_banana_trunk.png` | P07: painted bark, culm and trunk tiles | `paint/paint_foliage.py` (`bark()`) |
| `paint/foliage/tv_grass_atlas.png`, `tv_grass_variants.json`, `tv_herb_atlas.png`, `tv_herb_variants.json` | P08: grass, rice, meadow and moss tufts; flowers, fern sprigs and herbs; the frontier's grass_variants.json format; blade roots in the terrain slices' mean colours | `paint/paint_foliage.py` (`blade_card()`) |
| `paint/water/tv_fall_*.png`, `tv_pool_foam_ring.png`, `tv_wet_stain.png` | P09: waterfall kit (body and streak ribbons tiling in V, edge foam, spray puffs, pool foam ring, wet stain decal) | `paint/paint_water.py` |
| `paint/water/tv_mist_band_{a,b,c}.png`, `tv_mist_puffs.png`, `tv_smoke_wisps.png` | P10: mist band cards (tile in U), drifting puffs, smoke wisps | `paint/paint_water.py` |
| `paint/water/tv_river_ramp.png`, `tv_river_flow.png`, `tv_river_foam.png`, `water.json` | P11: river depth colour ramp (day and the still state S1), painted flow streaks and foam (tiling), per-direction river.gdshader tints | `paint/paint_water.py` |
| `paint/grade/tv_grade_<direction>_64.png`, `grade.json` | P12: one 64³ grade LUT per direction (the frontier GradeLut layout: 8 x 8 slices of 64²); greens never pulled to olive | `paint/paint_grade.py` |
| `vegetation/tv_broadleaf.glb`, `tv_karst_pine.glb`, `tv_bamboo.glb`, `tv_banana.glb`, `tv_fern.glb`, `tv_shrub.glb`, `vegetation.json` | P07 meshes: round-crowned broadleaf (8, 12, 17 m), karst umbrella pines (4, 7, 11 m), bamboo clumps (6.5, 10 m), banana (4.2 m), ferns (0.8-1.6 m), flowering shrubs (1.2-2.4 m); LOD0 and LOD1 each; puff-sphere cards with bent normals, painted bark tubes; the frontier tree format (COLOR r AO, g outer, b random, a foliage flag; UV2 wind) | `blender/build_foliage.py` (Blender 5.2, procedural, through the shared lock) |
