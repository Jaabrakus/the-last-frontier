# R1 in the game: the Đá Trắng vista (WorldRegion "r1")

The look's third Godot step: R1's real ground, water and dressing in the engine, walkable, shot from the vista spec's
cameras (`plan/look/vista_spec.md`). The shaders and look directions it uses are in `look_shaders.md`; the kits in
`rock_kit.md`, `village_kit.md` and `look_paint.md`.

## Play it

`tools/thuyvan/play_thuyvan_r1.command` (or `play_thuyvan.command r1`) opens `scenes/thuyvan_r1.tscn`: you start at the
east head of the rope bridge at 13:00 under the day cycle; F9 stills the Silent Reach. No saving.

## Rebuild, in order

```sh
python3 tools/environment/terrain/regions/bake_region.py         # T4's bake (git-ignored; ~40 s for all twelve cells)
python3 tools/thuyvan_art/terrain/r1_tv_splat.py [--preview p.png] # the painted splat per cell (~35 s)
python3 tools/thuyvan_art/terrain/write_r1_region.py [--check]     # data/world/maps/r1/region.json
zsh tools/thuyvan/bin/godot_run.sh --headless --path <wt> -s tools/thuyvan_look/pack_r1_terrain.gd
zsh tools/thuyvan/bin/godot_run.sh --path <wt> --resolution 1920x1080 -s tools/thuyvan_look/vista_shots.gd -- \
    out=<wt>/review_local/vista [dirs=..] [views=V1,V3] [perf=0] [still=1] [hour=H]
```

## How R1 loads

**The region.** `data/world/maps/r1/squares.json` is T4's baker's file (recipes and relief; its `region` is a string), so
the game's squares file is `region.json` beside it (generated): `WorldRegion.squares_path()` prefers a region's
`region.json` when there is one. Its block names the packed ground (`terrain_dir`), the grid's offset
(`terrain_origin` [0, -416]), the look (`"cycle"`), the water file and the player's start.

**The ground.** `pack_r1_terrain.gd` writes the bake in FrontierTerrain's formats to `assets/thuyvan/terrain/r1/`
(B2, square (0, 0), at the root; the other cells in `sq_X_Y/`), plus `tv_splat0-2.res`. R1's rows are centred half a
square off FrontierTerrain's grid, so FrontierTerrain moves its squares by the region's `terrain_origin` (the statics
read the grid at (x, z) − origin; `square_origin()` is in the world). A region's ground needs no detail (core) map and
no collision file (its collision is its height). With no region both are exactly as before.
`ThuyVanTerrain` (FrontierTerrain's subclass) draws the chunks with `tv_terrain.gdshader` and the painted splat, and
grows no frontier grass.

**The painted splat** (`r1_tv_splat.py`, vista_spec 4): from the bake's own six layers and the recipes' hints (re-run
through `bake_region.height_field`, which reproduces the bake exactly): grass and meadow, forest floor, karst rock,
terrace rice with laterite risers, the trails (the recipes' and the vista's, landmark to landmark), river bank silt,
white stone in the beds and within 4 m of the waterline, paddy mud in the paddies and on their bunds, moss and fern
round the falls' feet.

**The river.** `region.json`'s `river` is the main channel as WorldRiver nodes (`[z, x, level, half_width]`,
`WaterNetwork.as_world_river_block`). WorldRiver reads nodes when a block has them (`x_at`, `level_at`, `dir_at`,
`z_range`); without them it is unchanged. The player's river functions (surface, depth, flow, the still reach) work on
the main channel. The torrent and the pounds are WaterNetwork's only (plan M1 ports the callers).

**The water's look.** `ThuyVanWater`: a `tv_river` ribbon along each channel's nodes, every pound flat at its level
(paddies glassy), the torrent's falls as card falls 2.5x the stream, and the wall falls F1 and F2 (D9) down the gorge's
west wall. The main channel's material takes the still band from WorldRiver.

**The dressing.** `ThuyVanDressing` (D1-D21): the backdrop skirt to 7 km, the karst (hero towers on the rim, D13-D15,
the far ranks at the look's four fog steps, skyline cards), the gorge's cliff modules, the white stones, the rope
bridge on the needle, the Two Heights with its heads and gate towers, cliff houses, stilt houses and the clan house,
the waystone and flags, banners, lanterns, the survey camp, cairns, the mist bands per direction, and PAINT's plants
and grass cards in MultiMesh tiles.

## Cameras

V1 and V3 are the spec's. **V2 moved**: from the spec's (-380, 257, -600) the A2 plateau's rim hides the bridge (ROCK's
note). The bake was searched for a point that sees the deck's middle, both ends and a pier's upper half: the torrent's
south bank at (-540, 288, -400), 30 m over the ground, about 300 m from the bridge, yaw 79°, pitch 3°.
