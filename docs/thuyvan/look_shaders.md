# Thủy Vân look in Godot: the shaders and the three directions

The engine side of `plan/look/style_guide.md` 5.2 and 5.4: the Thủy Vân shaders (all under `shaders/thuyvan/`; the
frontier's shaders are untouched), the look directions as data, and ThuyVanLook, which applies them. The kits that use
them are in `look_paint.md`, `rock_kit.md` and `village_kit.md`.

## Shaders

| File | For | What it does |
|---|---|---|
| `tv_terrain.gdshader` | Ground | PAINT's 12-slice array (`terrain_slices.json`), all at 8 m except the cliff face at 16 m. Splat: three RGBA weight maps over `splat_rect` (slices 0-3, 4-7, 8-11; normalised), `fallback_slice` outside. Cliff face triplanar over 38 deg, except where terrace rice, laterite or paddy mud own the riser. Height blend by the array's A (depth 0.25). Anti-tiling 2.7x rotated 37 deg. Macro variation ±12 % value, ±8 deg hue over 60-250 m (procedural, no texture). Flat: no normal array, roughness 0.95. `use_height_map` lifts the frontier's flat chunk grids exactly as `terrain.gdshader` does. |
| `tv_rock.gdshader` (+ `tv_rock.gdshaderinc`) | Every rock kit material | The kit's painted-rock shader, moved here from `assets/thuyvan/rock/`: triplanar paint × vertex colour RGB, moss by vertex A on up faces. Adds an optional soft stroke normal (`normal_tex`, `normal_strength` ≤ 0.3). |
| `tv_rock_far.gdshader` | Backdrop karst ranks | The same paint. The scene fog is replaced on it by the instance uniform `rank_fog` toward `rank_fog_color`, so the four ranks step 15 / 35 / 60 / 80 % fog whatever their exact distance. Register the material with `ThuyVanLook.register_rank` so the colour follows the light. |
| `tv_river.gdshader` | Rivers, pools | The frontier river's mesh contract (UV2 = flow direction, COLOR.r = rapids), plus COLOR.g = white water by hand. Colour and alpha come from the depth behind the surface through `tv_river_ramp.png`: alpha 0.5 → 0.92 at 3 m, so the white stones show. Painted flow streaks are flow-mapped. Foam shows under 0.25 m, at rapids and at falls' feet. Lit: roughness 0.15, a soft glint, fresnel sky tint 0.3. No refraction. **`flow_scale`**: 1 running, 0 still (S1). It scales the speed and fades the streaks and foam, and the water turns glassy and clearer (the ramp's still row). `still_band` is the frontier's (RiverWater can drive it as today). |
| `tv_card.gdshader` | Falls, spray, mist, foam rings, smoke, skyline cards | Unshaded, alpha blend, colour × `light_tint` (sun × 0.6 + ambient × 0.4). `scroll` (UV/s) is stopped by `flow_scale`. Fades: `proximity_fade`, `near_fade` and `end_fade`. `atlas_grid` + instance `atlas_cell` select a cell; `billboard` / `billboard_y`; `fog_mix` for far cards. Register the material with `ThuyVanLook.register_card` so its tint follows the light. |
| `tv_sky.gdshader` | Sky | PAINT's panorama in its own u/v convention. Adds `panorama_b` + `blend` (the day cycle's cross-fade) and `tint` (the night proposal). |
| `tv_foliage.gdshader`, `tv_cloth.gdshader` | Plants, cloth | From the previous step, unchanged. |

## Look directions

`data/thuyvan/look_directions.json` is written by `tools/thuyvan_art/godot/write_look_directions.py` (`--check`
verifies it). Edit the generator, not the JSON.

**Sources:**
- Colours, angles, fog, height fog and mist heights come from `plan/look/palettes.json`.
- Sky, grade and water come from PAINT's `sky.json`, `grade.json` and `water.json`.

**What the generator adds:**
- The engine calibration (`ENGINE`: sun and ambient scale, exposure, sky energy, fog sky-affect).
- The renderer settings: AgX, SSAO contact only (radius 1, intensity 0.6), SDFGI/SSIL/SSR off, glow threshold 0.9 /
  intensity 0.4 / bloom 0.05, PSSM 4 splits.
- The four karst ranks.
- The lantern materials and their energies per direction.
- The night proposal, which has no painted night sky yet: it uses the dusk panorama tinted dark blue.
- The day cycle, keyed by hour:

| Hours | Look |
|---|---|
| 0-4.75 | night |
| 6-8.75 | jade mist morning |
| 10.75-16 | bright noon |
| 17.75-19.25 | golden dusk |
| 20.5-24 | night |

Between keys the looks blend by smoothstep. This follows owner_answers.md 7.

## ThuyVanLook (`scripts/thuyvan/look/thuyvan_look.gd`)

**As data:**
- `resolve(direction)` gives one direction's look.
- `at_hour(h)` gives the day cycle's look at that hour.
- `mix_looks(a, b, t)` blends two looks.
- `apply(look, env, sun)` sets the sun, the sky (making it `tv_sky`), ambient, fog and height fog, AgX, SSAO, glow and
  the LUT. Between directions the LUT is blended at 8 steps on a worker thread. It also sets the lanterns' emission and
  every registered card's and rank's colours.

**In the game:** call `ThuyVanLook.attach(environment_rig)` after `EnvironmentRig.build()`; ThuyVanLevel does.
- It is **region-gated**. It returns null and changes nothing unless the region block (`squares.json` "region") has
  `"look"`: either a direction key or `"cycle"`.
- Today's world (no region) and r1_grey (no "look") are untouched.
- When attached, it runs after DayNight every frame and overrides the sky, sun, fog, ambient, tonemap and grade. The
  clock and weather keep running underneath.
- The EnvironmentRig's defaults are not edited.

## The look test

```sh
zsh tools/thuyvan/bin/godot_run.sh --path <wt> --resolution 1920x1080 -s tools/thuyvan_look/look_test.gd -- \
    out=review_local/vista [dirs=...] [karst=rock|paint] [still=1] [hour=H]
```

**The scene** is a stand-in landform at R1's heights (plateau about 212 m, river at 140). It holds:
- a gorge with its river over the white stones
- a fall off the headwall
- the direction's mist bands
- five hero karst towers with pines on their seats, and the needle
- four backdrop ranks
- two stilt houses with clutter
- trees, ferns and shrubs

**Outputs** go to `shader_test_<direction>.png` and `shader_test_triptych.png`.

**Mid-grey check:** each run prints `GREY <direction> <value>` for a 0.5 sRGB card on the plateau.

## Calibration and choices (from the look test)

**Mid-grey check** (a 0.5 sRGB card on the plateau; the style guide's target at noon is 0.55-0.60):

| Direction | Exposure | Fog | Reading |
|---|---|---|---|
| Noon | 0.95 | the palette's | 0.596 |
| Morning | 1.08 | × 0.7 (Godot's exponential fog starts at the camera; Blender's mist pass started at 150 m) | 0.453 |
| Dusk | 1.0 | × 0.85 | 0.221 |

The sun and ambient energies are the palette's as they are.

**Karst:** `rock_karst` wears PAINT's karst face (value 0.52) with its soft normal at 0.25, chosen by eye against
ROCK's 0.62. It matches the terrain's cliff slice and keeps the falls and white stones the brightest things in frame.
`look_test.gd karst=rock` shows ROCK's for an A/B.

**Mist:** bands below the plateau lie in the gorge as flat layers of soft puffs. Seen from above, a standing band card is
cut by both walls into a hard V. Bands above the plateau stand as long cards round the far towers' waists. Mist uses
the direction's `targets.mist` colour (`light_tint_amount` 0), as the Blender diorama did. Falls and foam use
`light_tint`.

**Falls:** a fall's cards hang 2-3 m off the rock, so their proximity fade is 0.6 m. At the 4 m default the rock showed
through the falls.

## Tests

`tests/thuyvan/test_look_directions.gd` (headless) checks:
- the data
- applying a look
- the day cycle and the blended LUT
- the region gate
- that the shaders load
