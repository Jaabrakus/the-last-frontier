# R1's first vista: the Đá Trắng reach under the Two Heights (art director's spec, 2026-10-05)

This is the first thing the owner will see in the new look. It shows the Đá Trắng gorge, dressed after the Trường Sơn
sheet (the hero image, the Passes panel and the clan waystone panel), in the style of `style_guide.md`. It is rendered
in all three directions (`palettes.json` → `directions`) so he can choose.

**Two rules for everything here:**
- **Never a grey or placeholder frame.** Every surface in every frame shown to the owner is painted. If an asset is
  not ready, the frame waits for it; nothing is greyed in.
- **No layout edits.** Positions marked "dressing" are this vista's proposals, inside the layout's cells. Landmark
  positions come from `phase1/r1_layout.final.json`. Nothing here edits the layout; the lead promotes what he keeps.

**Coordinates:**
- Godot axes, metres: x east, y up, z south. North is -Z.
- Ground heights come from T4's bake: `tv/T4`, `tools/environment/terrain/build_regions/r1/<cell>/height.bin`, 833²
  float32, row = z, origin at the cell centre. `ref/sample_heights.py` reads it.
- Blender equals Godot (x, -z, y).

---

## 1. Cameras

`ref/frame_check.py` checked every camera against the bake: what falls inside each frame, at what angle and distance.

| | V1, the hero ("the Reach") | V2, "the Two Heights" | V3, "on the bridge" |
|---|---|---|---|
| **Purpose** | The owner's main image; the one rendered in the three directions first | The landmark close: stone bridge piers and falls | Player-height check: texel density, ropes, planks, water, white stones |
| **Position (Godot)** | (938, 220.7, -1250): east lip of the C1 gorge, 8 m above the ground (212.7) | (-380, 257, -600): north bank of the torrent in A2/B2, 6 m above the ground (≈251) | (857, 199.3, -1211): a third-person camera 4 m behind and 1.8 m above a player standing mid east span, on the deck at ≈196 |
| **Look** | yaw 99° (west by a little south), pitch -8° | yaw 107°, pitch 0° | yaw -3° (north), pitch -10° |
| **Field of view** | Vertical 50° at 16:9 (horizontal 79°) | Vertical 34° (telephoto; compresses the layers the way the sheets do) | Vertical 60° (the game's third-person) |
| **Blender** | loc (938, 1250, 220.7), rot (82°, 0, 99°), `sensor_fit` VERTICAL, `angle_y` 50° | loc (-380, 600, 257), rot (90°, 0, 107°), `angle_y` 34° | loc (857, 1211, 199.3), rot (80°, 0, -3°), `angle_y` 60° |
| **Godot** | Camera3D `fov` 50, keep height, far 12000 | `fov` 34, far 12000 | `fov` 60 |

Positive yaw turns from north toward west, as Godot's `rotation.y`. In the frame tables below, "left" and "right" are as
seen in the image.

## 2. What is in frame

### V1: the Reach

Reading order: the bridge → the falls → the village → the Two Heights. This mirrors the sheet's hero: the bridge from
the lower left, the village on the hill, the terraces, and the karst in mist.

| Depth | What | Where (angle from centre, distance) |
|---|---|---|
| **Foreground** (dark, warm) | The east bridge head: two anchor posts 5 m tall with an indigo banner and red tails; the **path waystone** with its cairn and two prayer-flag ropes running to the posts; shrubs, ferns, boulders on the lip | Left of centre, 24-29° left, 40-60 m, -16° to -20° |
| **Foreground → mid** | The **hanging rope bridge** across the gorge, from the lower left to the centre, in two spans on the **white-stone needle** (a rock pillar rising from the river) | East anchor 29° left at 57 m; needle 7° left at 123 m; west anchor 2° left at 184 m |
| **Mid, below** | The gorge: limestone walls in strata, green ledges. The river 75 m below: pale jade over **white stones**, white water at the steps. The still reach upstream (right), with mist holding over it in band 1. Two **falls** off the west wall | Silent reach 34° right at 120 m, -38°; falls F1 19° left at 210 m and F2 32° right at 205 m |
| **Mid** | West lip: three **cliff houses** cantilevered over the gorge beside a small gate pavilion at the west bridge head. Beyond, B1's **terraces** (bright yellow-green contour steps) climb to **the village** (8-12 stilt houses and the clan house, curved roofs, smoke under the eaves) | Cliff houses at 190-230 m; the village 9° right at 940 m; the clan house 15° right at 880 m; paddies 3° right at 860 m |
| **Mid-far** | The survey camp's tents and rods on the near west bank (small, story-true). The rope-rite cliff above the village. The A1 high pass with **the waystones** on the skyline. The north-rim karst group K1-K4 | Survey camp 32° left at 380 m; rope-rite cliff 20° right at 1.1 km; waystones 14° right at 1.8 km |
| **Far** | **The Two Heights**: two natural stone heads (≈90 m above the rims) with the arched stone bridge strung between them on two tall piers. Mist band 3 beneath the deck. The torrent's falls (x -600 and -200) as white threads below. | 15° left at 1.9 km; tops +4.7° above the horizon. Falls at 18° and 27° left |
| **Backdrop** | The west karst ranks K5-K14 in four fog-stepped layers (2-5 km), then painted silhouettes in the sky panorama | Across the whole width |
| **Sky** | The direction's painted panorama: big soft cumulus, sun glow where the light is | Top third |

### V2: the Two Heights

| Depth | What |
|---|---|
| **Foreground** | The north-bank lip: ferns, a boulder pair, a banner pole and one prayer-flag rope crossing the frame's left |
| **Mid** | The torrent's gorge leading in. Fall F3 (x -600) in the middle distance: a 25-30 m stepped fall with a spray puff. Wall strata and ledges |
| **Hero** | The **Two Heights Bridge**: two stone piers ≈91 m tall from the torrent (≈205) to the deck (≈296). Round arches; banners on the piers; **two different maker signs** carved on the north pier; frayed offerings tied above the iron bolts (bible L16). The two stone heads beside it, carrying small gate towers with curved tile roofs. Mist band 3 under the deck |
| **Backdrop** | Karst ranks K5-K10 behind, fog-stepped; the painted sky |

### V3: on the bridge

| Depth | What |
|---|---|
| **Near** | A stand-in figure on the deck (a painted scale figure, see V15). The planks, rope rails, net side, rag flags and posts at full 256 px/m. **This is the texel-density check** |
| **Below** | The gorge running north. The **silent reach**: white stones under the clear pale jade surface. A sampan pulled up on a white-stone beach (left). Mist band 1 holding just over the water |
| **Walls** | Strata, ledges, moss and the dark streaks under seeps. Fall F2 on the left edge |
| **Far** | The burial cairns on the north-west lip; the north-rim karst K1-K4 and K13-K14 above the gorge's end; the sky |

## 3. Dressing placements (proposals)

Heights are ground heights from the bake unless given. These positions sit inside the layout's cells and touch no
layout value.

| Id | What | Position (x, y, z) | Notes |
|---|---|---|---|
| D1 | Rope bridge, west anchor | (757, 201, -1215) | Two posts 5 m tall; a small gate pavilion at (745, 206, -1215) |
| D2 | Rope bridge, the needle | (820, 135 → top 197, -1215) | A white-limestone pillar 62 m tall from the riverbed; a 4 × 4 m plank platform on top with one banner and a lantern post |
| D3 | Rope bridge, east anchor | (893, 199, -1215) | Two posts; indigo banner with red tails; lantern hooks |
| D4 | Bridge decks | D1 → D2 → D3 | Two spans of about 63 and 73 m; deck at the anchors 200, at the needle 197, sag 4.5 m per span |
| D5 | Path waystone + cairn | (905, 205, -1228) | Flag ropes to D3's posts and to a pole at (915, 207, -1240) |
| D6 | Cliff houses (3) | (735, -, -1245), (728, -, -1288), (742, -, -1180) | Floors cantilevered 4-6 m over the lip; bracing down the wall |
| D7 | Village | Centred on landmark `village` (0, 177, -1248) | 8-12 stilt houses on terrace steps between y 170 and 190; the clan house at `clan_house` (60, 182, -1330); fences, drying racks, 20 lanterns |
| D8 | Terraces | `village_paddies` (80, 168, -1150), plus B1's contour steps 165-215 m | Retaining walls on every step edge in view of V1; rice rows along the contours |
| D9 | Falls F1 (paddy spill), F2 | F1 lip (752, 205, -1150) → river 133; F2 lip (750, 203, -1330) → 135 | Both oversized (style guide 7). F1 is fed by the village paddies' overflow |
| D10 | Torrent falls F3, F4 | x -600 and -200 on the torrent (layout `falls_x`) | Stepped 25-30 m (cards at 2× the stream). F5 (x 300) is out of frame |
| D11 | Two Heights Bridge | Landmark `two_heights_bridge` (-832, -, -460) | Piers at z -480 and -445 from the torrent (≈205) to the deck (≈296); arches; the deck runs north-south across the torrent |
| D12 | The two heights (stone heads) | North (-832, 296 → top 385, -545); south (-832, 288 → top 365, -385) | Natural limestone heads beside the bridge's ends, each with a small gate tower |
| D13 | North-rim karst | K1 (-260, -1620) 160 m; K2 (130, -1700) 120 m; K3 (-640, -1560) 200 m; K4 (420, -1640) 110 m | On the region's rim band (outside the walkable ground); bases on the ground |
| D14 | West backdrop karst | K5 (-1450, -1200) 180 m; K6 (-1700, -700) 240 m; K7 (-1600, -300) 200 m; K8 (-2100, -1500) 260 m; K9 (-2400, -900) 300 m; K10 (-2600, -200) 280 m; K11 (-3200, -1300) 350 m; K12 (-3500, -500) 320 m | Outside R1, on a low-poly backdrop ground at y 260-340 that continues the rim. Past 4 km: sky-panorama silhouettes |
| D15 | North backdrop karst | K13 (600, -2100) 220 m; K14 (-200, -2300) 260 m | Seen in V3 and on V1's right edge |
| D16 | White river stones | C1 bed and banks, z -1500 to -1000, about 400 stones in groups along flow lines | Larger stones (1-3 m) at the steps; 20% just under the surface |
| D17 | Sampan | Pulled up on a white-stone beach at (818, 134, -1290) | S0 state: fishermen's; a pole and a fish basket beside it |
| D18 | Survey camp | Landmark `survey_camp` (650, 193, -1000) | Two small tents and a measuring tripod with striped rods; story-true and small |
| D19 | Burial cairns | Landmark `burial_cairns` (700, 219, -1580) | Five stacked-stone cairns with frayed rag offerings |
| D20 | Mist bands | Heights per direction (`mist_bands_m`) | Band 1 over the still reach (z -1500 to -1100); band 2 across B1's low terraces; band 3 under the Two Heights deck and round the backdrop karst waists |
| D21 | Vegetation | Bake's forest density on B1, C1's lips and ledges; pines on every karst top and ledge; bamboo clumps around the village and the cliff houses; ferns and moss in the falls' spray | Broadleaf round crowns dominate the slopes; grass cards thick on the terrace edges |

## 4. Terrain and water for the vista

**The ground mesh.** Stitch the 12 bake cells (`height.bin`) into one mesh, at three resolutions:
- 1 m within 300 m of V1 and V3
- 4 m out to 1 km
- 8-16 m beyond

The sheer cells (`sheer_cells.bin`) under the gorge walls are covered by ROCK's cliff-wall modules.

**Splat, painted slices** (`style_guide.md` 3.3). The T4 splat is frontier-layered, so the vista derives its own:

| Slice | Where |
|---|---|
| 6 rock (triplanar) | Slope over 38° |
| 7 white stone and gravel | Within 4 m of the waterline on any channel |
| 5 paddy mud | Inside paddy pounds and their bunds |
| 1 terrace rice | Terraced-slope cells' contour steps between 165 and 215 m |
| 3 dirt path | Within 2 m of the trails (landmark-to-landmark polylines; switchbacks in B2) |
| 2 forest floor | Where the bake's forest density is over 0.5 |
| 8 moss | Within 25 m of a fall's foot |
| 0 grass | Everything else |
| 4 laterite | Exposed banks over 1.5 m under a terrace edge |

**Water** is a ribbon mesh along the layout's channel nodes (x, z, half width, level), cut by the terrain:
- **The main river:** level 142 → 132 through C1, the silent reach at z -1500 to -1100.
- **The torrent:** 230 → 118 from west to east.
- **The pounds:** village paddies at 168, 1.5 m steps.

The shader follows the style guide (5.2).

**Backdrop ground.** A painted low-poly skirt from the region's rim out to 6 km, at 260-340 m to the west and north,
falling away to the south. Fog does most of its work.

## 5. Rendering the vista (Blender Eevee, then Godot)

### 5.1 Blender (now)

**Output:**
- 1920 × 1080, Eevee, AgX view transform at contrast 1.05-1.15 per direction.
- Soft shadows (light angle as `palettes.json`); bloom/glare on (threshold 0.9).
- AO off: it is painted.

**Light and sky:**
- **Sun:** azimuth, elevation, colour and energy from `palettes.json`. Blender's sun points from the compass bearing:
  azimuth 0 is north = Blender +Y.
- **World:** the direction's painted sky panorama, at strength = ambient energy.

**Fog:**
- **Depth fog:** the compositor's Mist pass (start 150 m, depth chosen so the backdrop layers step 15 / 35 / 60 /
  80%), mixed with the fog colour.
- **Height fog:** a scatter volume, or a gradient card stack, under the direction's fog height.
- **Mist bands:** PAINT's cards.

**Output files** to `look/vista/`:
- `V1_<direction>.png` for each of the three directions, then `V2_<direction>.png` and `V3_<direction>.png`
- one `V1_triptych.png` with the three side by side and their names

### 5.2 Godot (later, in the lane, after the owner picks)

The same cameras and placements as a look scene, using the Godot materials of `style_guide.md` 5.2 and the picked
direction's Environment. Not now: the lane is merging phase 1 under the shared lock.

### 5.3 Acceptance (before the owner sees a frame)

1. **Thumbnail test.** At 240 px wide, the reading order is the bridge → the falls → the village → the Two Heights.
2. **Value layers.** Near is darker and warmer than far. The 4 karst layers step visibly paler and bluer.
3. **No grey.** Apart from the white stones, falls, mist and clouds, no surface region has median saturation below
   0.12.
4. **No black.** The darkest 1% of pixels is above 0.06 in value.
5. **Palette.** Eye-droppered targets (`palettes.json` `targets`) are within about ΔE 10 of the frame.
6. **Contents.** Every row of section 2 is visible and painted. Nothing is greyed in.
7. **Side by side.** The frame is put beside `ref/board_bridges.jpg` and `ref/board_karst_cliffs.jpg`: "does it look
   like the sheets, in WoW Classic's spirit?" If not, fix it before showing.

## 6. The asset list

Builders:
- **ROCK:** Blender rock kit.
- **VILLAGE:** Blender village kit; reuse `tools/asset_author/blender/ring_kit.py`'s Builder/roof/lantern idiom in a new
  Thủy Vân file, never editing the ring kit.
- **PAINT:** Python/numpy/PIL textures, cards and sky, plus Blender only where a card needs geometry baked.

Each renders its lineup to `look/<id>/` as `style_guide.md` section 11.

| Id | Asset | Builder | Sheet reference |
|---|---|---|---|
| R01 | Karst hero towers: 3 variants (110, 170, 240 m), leaning, tiered slabs, pine-crown seats, undercut option; LOD0-1 | ROCK | Trường Sơn hero (towers), `board_karst_cliffs` |
| R02 | Karst backdrop towers: 6 low-poly variants (1-2k tris) for K5-K15 | ROCK | Trường Sơn hero (far ranks); Vạn Thủy far karst |
| R03 | Gorge cliff-wall modules: straight 40 m, convex, concave, waterfall notch, ledge-with-house-seat; heights 30, 60, 75 m; strata 7 m | ROCK | Trường Sơn bridge panel (cliff under the village); Mountain Folk landscape |
| R04 | Boulders: 6 rounded limestone variants (1-6 m), moss caps | ROCK | Trường Sơn waystone panel (base rocks) |
| R05 | White river stones (Đá Trắng): 12 variants (0.3-3 m), smooth and pale, plus a scatter script for D16 | ROCK | Trường Sơn river; bible L03 ("white stones visible beneath stopped water") |
| R06 | The Two Heights: two natural stone heads, the arched stone bridge, two piers with two different maker signs, bolt plates with frayed offerings | ROCK | Map sheet (Two Heights Bridge); Thạch Uyên bridges and maker's mark; bible L16 |
| R07 | The bridge needle (D2): a white-limestone pillar 62 m tall, with a cap for the platform | ROCK | Trường Sơn bridge panel (the rock under the bridge in the fall) |
| R08 | Burial cairns (D19): 5 stacked-stone cairns | ROCK | Trường Sơn waystone panel (cairn base) |
| V01 | Stilt house (Mountain Folk): 2 sizes, thatch or wood shingle, upturned eaves, bamboo-weave walls | VILLAGE | Trường Sơn hero (terrace houses); Mountain Folk landscape |
| V02 | Cliff house: cantilevered on beams with braces, tile roof, balcony | VILLAGE | Trường Sơn bridge panel (cliff village); `board_houses_roofs` |
| V03 | Clan house: two-tier curved hip roof, red lacquer columns, stone plinth | VILLAGE | Trường Sơn hero (gate tower, village) |
| V04 | Bridge-head gate pavilion and the Two Heights gate towers: a small curved-roof gate in two sizes | VILLAGE | Trường Sơn Passes panel (gate pavilion) |
| V05 | Hanging rope bridge: parametric span and sag, planks with gaps, posts, rope rails, net sides, anchor posts, the needle platform | VILLAGE | Trường Sơn hero and Passes panel, `board_bridges` |
| V06 | Clan waystone: leaning slab, our own carved clan mark and tally notches, cairn base, two flag poles | VILLAGE | Trường Sơn clan waystone panel (shape only; NOT its swirl emblem) |
| V07 | Banners on poles: 3 variants with our own clan marks, indigo / ochre / jade fields, red tails | VILLAGE | Trường Sơn bridge and Passes banners; Thạch Uyên ochre banner |
| V08 | Prayer-flag ropes: a parametric rope between two points with 30 × 45 cm rag flags | VILLAGE | Trường Sơn waystone panel and bridge rails |
| V09 | Lanterns: paper round and barrel, a lantern post, bridge-head lamp | VILLAGE | Trường Sơn village; Vực Sen Sâu and Ảo Thành lanterns (for dusk) |
| V10 | Terrace retaining walls and paddy bunds: curved dry-stone modules 0.8-1.5 m | VILLAGE | Trường Sơn terraces; Thạch Uyên terraces and water |
| V11 | Sampan with bamboo canopy, plus pole and fish basket | VILLAGE | Đồng Lau and Vạn Thủy boats; Vực Sen Sâu pilot boat |
| V12 | Fences and rails: bamboo rail, wattle panel | VILLAGE | Trường Sơn village; Đồng Lau moorings |
| V13 | Village clutter set: drying racks, baskets, firewood, water jars, a smoke-under-eaves anchor | VILLAGE | Trường Sơn terraces-and-provisions panel; Common Folk details strip |
| V14 | Survey camp: two tents, measuring tripod, striped rods | VILLAGE | — (story: Dương's survey; no sheet) |
| V15 | Scale figures: 3-4 simple painted porters (conical hat, pack), standing and walking; a pack-buffalo optional | VILLAGE | Trường Sơn bridge panel and Passes panel (porters, pack animals); Common Folk lineup |
| P01 | Terrain painted array: 9 slices (grass, terrace rice, forest floor, dirt path, laterite, paddy mud, karst limestone, white stone and gravel, moss); 2048² over 8 m | PAINT | Trường Sơn hero (ground, terraces); `board_terraces`, swatches |
| P02 | Rock tiling for meshes: karst face with strata and stains (16 m), white river stone (4 m), cliff moss blend | PAINT | `board_karst_cliffs`; Thạch Uyên quarry |
| P03 | Village trim sheet (2048², 256 px/m): timber, weathered plank, roof tile courses, thatch, wood shingle, bamboo weave, plaster, rope, lacquer, iron | PAINT | `board_houses_roofs`; Trường Sơn bridge panel |
| P04 | Cloth and mark textures: banner fields with our clan marks, prayer-flag rags, the waystone's carved-mark decal, the two Two Heights maker signs | PAINT | Trường Sơn banners and waystone; Thạch Uyên maker's mark (as kind, not shape) |
| P05 | Painted sky panoramas: 3 (one per direction), 4096 × 2048, cumulus and a far karst silhouette band | PAINT | `board_skies`; Trường Sơn hero sky |
| P06 | Skyline cards: far karst silhouettes in 3 fog-tinted layers, for past 4 km | PAINT | Trường Sơn hero (far ranks); Vạn Thủy far karst |
| P07 | Trees: round-crown broadleaf (3 sizes), karst umbrella pine (3), bamboo clump (2), banana (1), fern (3), shrubs (3). Painted dab atlases and puff-card meshes | PAINT | Trường Sơn crowns and pines; `board_vegetation` |
| P08 | Grass, flower and rice cards | PAINT | Trường Sơn terraces and near slope |
| P09 | Waterfall kit: body ribbon, edge foam, lip, base spray puffs, pool foam ring, wet-stain decal; scrolling textures | PAINT | `board_waterfalls_mist`; Trường Sơn falls |
| P10 | Mist kit: horizontal band cards (3 shapes), drifting puffs, smoke-under-roof wisps | PAINT | `board_waterfalls_mist`; Trường Sơn mist bands |
| P11 | River surface: depth colour ramp, flow-streak texture, foam texture, still-state variant (S1, flow 0) | PAINT | `board_water`; Trường Sơn river; bible L03 |
| P12 | Grade LUTs: one 3D LUT per direction (Thủy Vân grade; no olive pull on greens) | PAINT | `palettes.json` directions |

### Build order

The vista needs all of these. Builders run in parallel, with Blender one at a time under the lock.

1. **P01, P02, P03 first.** ROCK and VILLAGE apply these textures; until they exist, builders use flat ramp colours
   and painted vertex colour, never grey.
2. **R01, R03, R05, V05, V06, V01 and P07, P09, P10.** The hero set of V1.
3. **R06, R07, V02, V03, V04, V07, V08, V09, V10.** The landmarks and dressing.
4. **P05, P06, P11, P12, R02.** Sky, backdrop and grade.
5. **Then the rest** (V11-V15, R04, R08, P04 finishing, P08).
