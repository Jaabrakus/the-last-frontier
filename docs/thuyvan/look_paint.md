# Thủy Vân look: PAINT (painted surfaces, sky, foliage, water)

The PAINT look builder's work for R1 (style guide `docs/thuyvan/plan/look/style_guide.md`, asset list P01-P12 in
`vista_spec.md`): a numpy brush engine and the painters that use it, plus two Blender scripts. Everything is ours
(`assets/thuyvan/SOURCE.md`). The owner's brief: the concept sheets in a World of Warcraft Classic spirit:
hand-painted tiling textures with the light and occlusion painted in, saturated harmonious palettes, chunky
silhouettes, painted skies. Not cel shading, not the WoW interface.

## Rebuild

All painters are deterministic (fixed seeds) and read colours only from the art director's
`docs/thuyvan/plan/look/palettes.json`. Review images go to `look/PAINT/` in the plan folder (env
`TV_LOOK_DIR` overrides).

```sh
python3 tools/thuyvan_art/paint/paint_terrain.py      # P01 terrain array (12 slices, ~3 min)  [--size 1024 --only grass]
python3 tools/thuyvan_art/paint/paint_surfaces.py     # P02 rock tiling, P03 village trim sheet  [--only rock|trim]
python3 tools/thuyvan_art/paint/paint_marks.py        # P04 clan marks, banners, prayer flags, waystone and maker signs
python3 tools/thuyvan_art/paint/paint_sky.py          # P05 sky panoramas (3 directions), P06 skyline cards
python3 tools/thuyvan_art/paint/paint_foliage.py      # P07 leaf atlas + bark, P08 grass and herb cards (after P01)
python3 tools/thuyvan_art/paint/paint_water.py        # P09 falls kit, P10 mist kit, P11 river ramp / flow / foam
python3 tools/thuyvan_art/paint/paint_grade.py        # P12 grade LUTs
# Blender (only through the shared lock; never plain Blender):
zsh <plan>/bin/blender_run.sh -b --factory-startup -P tools/thuyvan_art/blender/build_foliage.py -- export=1 render=1
zsh <plan>/bin/blender_run.sh -b --factory-startup -P tools/thuyvan_art/blender/render_diorama.py -- [dirs=...] [res=1920x1080] [samples=48]
python3 tools/thuyvan_art/paint/grade_renders.py      # the diorama through each direction's LUT + the triptych
python3 tools/thuyvan_art/paint/compose_boards.py     # the review boards (foliage, swatches, skies, water)
```

## The brush engine (`tools/thuyvan_art/paint/tvp.py`)

Version 2 (2026-10-06). The first pass painted flat vector stickers (firm-edged one-colour ellipses); every dab is now
a brush stroke: a per-stroke bristle profile across its width (streaks along it, a dry-brush tail), two-colour
loading along its length, partial opacity so layers glaze, colours picked continuously along the material's ramp.
Rock is painted as chunky planes (a warped periodic Voronoi: each plane graded lighter to its top, bevelled, split by
cracks whose vertical joints thin and break) under dry-brush scrub. Then the guide's passes: cavity AO toward a cool
dark, top-edge light on rock and wood, 0.6 px blur and a luminance-only unsharp mask, a luminance clamp to the
ramp's span, the value budget, and a squint limit that holds patches above about 20 cm to a few % of the tile mean
so an 8 m tile does not show a repeat grid (the terrain shader's macro variation and anti-tiling carry the big
breathing). Deviations from the guide's value budgets: cliff face 0.52 (not 0.62) and karst rock 0.56 (0.60): at
0.62 the lit gorge walls read chalk-white next to the white stones and falls, which must stay the highlights.

## How the Godot step uses these (a swap into the existing systems)

**Terrain** (`assets/thuyvan/paint/terrain/tv_terrain_albedo_array.webp`): import as `2d_array_texture`
(CompressedTexture2DArray, `slices/horizontal=3`, `slices/vertical=4`, `compress/mode=2` BPTC, mipmaps on), the same
importer settings as `assets/environment/terrain/textures/terrain_albedo_array.webp` except the grid. Slice order
and tile metres: `terrain_slices.json`. RGB = albedo, A = blend height (same meaning as the frontier array). No
normal array: the Thủy Vân terrain shader (a copy under `shaders/thuyvan/`, never `shaders/terrain/terrain.gdshader`)
drops the `nrm_array` fetch, tiles at 8 m (cliff face triplanar at 16 m over 38 deg), keeps the 2.7 x / 37 deg
anti-tiling, and raises macro variation to +-12 % value over 60-250 m.

**Rock meshes**: `rock/tv_karst_face_16m.png` world-space triplanar at 16 m (6 m on boulders) x vertex colour RGB;
optional `tv_karst_face_16m_normal.png` (OpenGL) at strength 0.2-0.35; `tv_cliff_moss_6m.png` blended by
vertex colour A x smoothstep(0.55, 0.8, normal.y); `tv_river_stone_4m.png` on the white stones.

**Vegetation** (`assets/thuyvan/vegetation/*.glb`): the frontier tree format (`tools/environment/vegetation/
build_trees.py`): objects `<species>_v<k>_lod<n>`, one surface, COLOR r = AO, g = outer crown, b = random, a = 1
foliage / 0 bark; UV = atlas tile rect or tiling bark UVs; UV2 = wind (x metres from the trunk, y phase). Load like
`veg_assets.gd` does, but with `leaf_albedo = tv_foliage_atlas.png` and the species' bark from `vegetation.json`.
Use a lit material (Lambert wrap 0.45, alpha scissor 0.5, alpha-to-coverage); never the banded
`painted_light.gdshaderinc`.

**Grass and herbs**: `tv_grass_atlas.png` + `tv_grass_variants.json`, `tv_herb_atlas.png` + `tv_herb_variants.json`
are in exactly the format `scripts/world/terrain/grass.gd` reads (`ATLAS_PATH`, `VARIANTS_PATH`, `HERB_ATLAS_PATH`,
`HERBS_PATH`): point a Thủy Vân copy of those constants at them.

**Sky**: `sky/tv_sky_<direction>.png` (4096 x 2048 equirect): `PanoramaSkyMaterial` (filter on) or the Thủy Vân sky
shader; convention u = fract(0.5 + atan(dir.x, -dir.z) / 2 pi) (north, -Z, at u 0.5), v = acos(dir.y) / pi
(`sky.json` holds each sun's uv). Skyline cards `tv_skyline_karst_{0,1,2}.png` unshaded, colour lerped toward the
fog colour by distance.

**Falls, foam, mist** (`water/`): unshaded, alpha blend, colour x `light_tint` (sun x 0.6 + ambient x 0.4),
proximity fade 4-20 m; scroll the fall body at 0.8 m/s and the streaks at 1.4 m/s down V; mist bands scroll 0.5 m/s
in U at the direction's `mist_bands_m` heights.

**River**: `tv_river_ramp.png` (x = depth 0-4 m; rows 0-3 day, 4-7 the still state S1) for the depth colour, or set
the existing `river.gdshader` uniforms from `water.json` (`shallow_tint`, `deep_color`, `absorb`, `still_absorb`
per direction); `tv_river_flow.png` scrolls along UV2 (flow), `tv_river_foam.png` replaces `foam_noise`.

**Grade**: `grade/tv_grade_<direction>_64.png` imported as Texture3D (`slices/horizontal=8`, `slices/vertical=8`,
the `bake_lut.gd` import), set as `Environment.adjustment_color_correction`, AgX contrast per `grade.json`.

## Review images (plan folder `look/PAINT/`)

`board_diorama_triptych.png` (every surface together in the three directions), `diorama/diorama_<direction>.png`,
`board_terrain_swatches.png`, `board_rock_trim.png`, `board_foliage_lineup.png`, `board_foliage_cards.png`,
`board_skies.png`, `board_water_mist.png`, `checks/*_check.png` (3 x 3 tiling and squint per texture).
