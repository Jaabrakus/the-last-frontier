# Thủy Vân: the world's look (style guide, art director, 2026-10-05)

**The brief, in the owner's words (2026-10-05):** "i gave you the maps pictures and everything can you not see it? i
want it like wow classic vibes." The world must look like the owner's 15 concept sheets, built in the spirit of World of
Warcraft Classic: stylized and hand-painted, saturated per-zone palettes, chunky readable silhouettes, exaggerated
landmarks, painted skies, mood from fog and light.

**What it is NOT:**

- No cel shading: no ink outlines and no banded toon light. The owner rejected these for Tidebreak. Light is ordinary,
  smooth scene light over painted textures.
- No WoW interface. The WoW-style HUD was built and rejected on 2026-10-03. The game keeps its own HUD.
- No copies. No Blizzard asset, texture, model, logo, font or UI. Nothing from Avatar: The Last Airbender: no emblem
  (see the waystone note in section 9), no show words.
- No photographs. Everything is our own: painted procedurally in Python (numpy, PIL) or modelled in Blender. The CC0
  textures already in the repo may stay, but painted textures replace them in Thủy Vân zones. One OFL font is allowed.
- No sheet pixels in game art (plan 3.3 item 27). The sheets are the target for shape, colour and mood only.

**Files in this folder:**

| File | What it is |
|---|---|
| `palettes.py` → `palettes.json` | The one machine-readable palette source: albedo ramps per zone, and the three directions' light, sky, fog and grade. Builders read the JSON; nobody retypes hex values |
| `palettes.png`, `directions.png` | Ramps and directions as swatches |
| `color_keys.png` | **Internal.** Flat colour keys of vista V1 per direction. Not for the owner: he sees renders |
| `ref/board_*.jpg` | Reference boards cropped and enlarged from the sheets: karst and cliffs, waterfalls and mist, bridges, houses and roofs, terraces, banners/waystones/lanterns, vegetation, water, skies, peoples' dress |
| `ref/swatches_families.png`, `ref/swatches_<zone>.png`, `ref/swatches.json` | Colours sampled from the sheets: 12 k-means colours per zone, plus each colour family's dark/mid/light values and median saturation |
| `ref/boards.py`, `ref/crop.py`, `ref/sample_heights.py`, `ref/frame_check.py` | The scripts that made the boards and checked the vista cameras against the T4 bake |
| `vista_spec.md` | R1's first vista: cameras, what is in frame, placements, the asset list |

---

## 1. What the sheets say, read closely

These are the observations every rule below follows from. The boards show each one.

1. **The sheets are muted, sepia-washed paintings.** Every colour family has a median saturation of 0.15-0.25: greens
   0.17, terraces 0.26, water 0.10, stone 0.04-0.21 (`ref/swatches_families.png`). Their **hues** are the target:
   - olive-to-jade greens (hue 70-75°) and yellow-green terraces (55-60°)
   - pale jade-grey water (185-190°)
   - warm grey limestone (30-35°)
   - blue-grey skies and far ranges (210-220°)
   - brick-madder reds (10°), deep indigo cloth, bone white

   Their **saturation is not the target.** We push chroma about 2-3x to a WoW Classic level and keep the hue
   relationships. `palettes.json` is that push, already done.
2. **Value structure is the sheets' real strength.** Read near to far:
   - dark, warm foreground: timber, foliage, rope
   - mid-value green-and-grey midground
   - pale, cool, misty distance
   - white falls and mist as the brightest marks

   This is aerial perspective by the book. Fog, mist cards and sky carry it in game.
3. **Karst is the signature shape** (`board_karst_cliffs`):
   - tall towers, 2.5-5 times as tall as wide, often leaning
   - built of stacked vertical slabs that step in toward the top
   - a crown of dark round pines on every top and ledge
   - mist always between the towers, never a clean horizon

   Towers come in ranks: 3-5 visible depth layers, each paler and bluer than the one before.
4. **Water is white.** The falls are oversized ribbons that break into spray, and every slope has one. The rivers are
   pale jade threaded with white water. The bible's sensory anchor for Đá Trắng: "white stones visible beneath stopped
   water; mist that holds".
5. **Hanging bridges are the hero prop** (`board_bridges`):
   - plank decks with gaps, chunky posts every few metres, rope rails
   - tall anchor posts carrying indigo banners with a bone-white mark and red streamer tails
   - rag flags on the rails
   - a deep sag, spans that look 60-150 m long, mist under the deck
6. **Architecture** (`board_houses_roofs`):
   - dark slate-teal tile or thatch roofs with strongly upturned eaves
   - timber frames and plastered gate towers
   - houses hung on cliff edges and karst tops, piers and stilts everywhere
   - a few lacquer-red accents (columns, lantern paper, banners)

   Roofs dominate each building's silhouette.
7. **Terraces** (`board_terraces`) are yellow-green contour steps wrapped around rounded hills. They are the
   brightest, warmest green in a Trường Sơn view, with houses sitting on the steps.
8. **Skies** (`board_skies`) are bright overcast or hazy blue with big soft cumulus behind the ranges. Ảo Thành is the
   only night sheet: a moonlit indigo city of red lanterns.
9. **Each region already has its own colour identity**, the WoW zone principle:
   - Trường Sơn: jade-grey and green
   - Thạch Uyên: warm white stone, ochre and kiln orange, turquoise canals
   - Đồng Lau: reed gold, silver water, indigo heron banners
   - Vực Sen Sâu: dark teal, lotus pink, amber lanterns
   - Vạn Thủy: blue-grey water, dark tile, red lacquer, court indigo and gold
   - Lâm Uyên: deep moss green and white falls
   - Ảo Thành: indigo night, crimson and gold

## 2. The look in one paragraph

Thủy Vân looks like a painting of the sheets that you can walk through. Big shapes read from far away:
- leaning karst towers with pine crowns
- huge white falls
- fat curved roofs
- thick ropes and planks
- round cloud-puff tree crowns

Every surface is painted with a few confident strokes in 3-5 tones of one hue. Its light and its occlusion are already
in the paint, and there is no photographic grain. Colour is saturated but harmonious: one zone, one family of hues,
with warm against cool doing the work. Distance turns to coloured fog in layers. The sky is a painting with big soft
clouds. Light is smooth and soft, with coloured shadows (never black, never banded).

---

## 3. Texture painting rules (for the Python painter)

### 3.1 Texel density and tile sizes

| Surface | Texture | World size of one tile | Density | Notes |
|---|---|---|---|---|
| Terrain ground layers | 2048² per slice, in the terrain's texture-array format (RGB albedo, A = blend height) | **8 m** | 256 px/m | Today's frontier tiles are 3 m (683 px/m), which is photographic. Painted strokes need the bigger tile |
| Terrain triplanar rock (slopes over 38°) | 2048² | **16 m** | 128 px/m | Strata run horizontally; read at 50-300 m |
| Karst towers, cliff walls, bridge piers (mesh) | 2048² tiling and triplanar | **12-16 m** | 128-170 px/m | Plus vertex colour (section 5.3). Hero pieces seen within 30 m: 6 m tile |
| Boulders, white river stones | 1024² tiling | **4-6 m** | 170-256 px/m | Smooth rounded forms; few strokes |
| Buildings (village trim sheet) | 2048² trim sheet | Strips at **256 px/m** | 256 px/m | Planks 0.3 m wide = 77 px; roof tile courses 0.25 m = 64 px |
| Props (lanterns, waystone carving, flags) | 512-1024² atlas cells | — | 256-512 px/m | The waystone's carved mark gets its own 512² decal |
| Foliage cards | 2048² atlas per family | — | Crown cards ~128 px/m; grass ~512 px/m | Alpha-tested, painted dabs (section 6) |
| Sky panorama | 4096 × 2048 equirect (upper half painted; lower half = fog colour) | — | — | One per direction |
| Falls, mist, foam cards | 512 × 2048 strips, 1024² sheets | — | — | Scrolling; 3-4 tones only |

**One rule over all of these:** a stroke is measured in metres, not pixels. If a texture's tile size changes, its
strokes scale with it.

### 3.2 The brush recipe (every tiling texture)

Paint on a torus so every texture tiles. Dabs that cross an edge wrap (modulo the size). Work in linear float and
convert to sRGB at the end. Fixed seeds: a texture rebuilds bit for bit.

1. **Ramp.** Take the material's 4-stop ramp from `palettes.json` (dark, mid, light, accent). Every pixel's final
   colour comes from that ramp. There is never a colour outside the material's hue family except the accent.
2. **Base and low-frequency variation.**
   - Fill with `mid`.
   - Add 2 octaves of tileable value noise at periods of 1 and 1/2 of the tile (8 m and 4 m on the ground).
   - Amplitudes: value ±8%, hue ±5°, saturation ±10%.

   This is the "low-frequency colour variation" that makes WoW ground breathe. **No noise finer than 1/16 of the
   tile** anywhere in the texture.
3. **Big strokes** (60-120 per tile):
   - Shape: elliptical dabs 6-20% of the tile long, aspect 1.5-4.
   - Edges: a firm painter's edge, alpha = smoothstep(1.0, 0.75, r). Not a Gaussian blob.
   - Colour: each dab is one flat colour from the ramp, picked by a weight table (dark 20%, mid 45%, light 30%,
     accent 5%), jittered ±3% value.
   - Direction follows the material's flow field:
     - grass: random tufts tilted ±25° from vertical in the texture
     - rock: along the strata (horizontal ±12°) on faces, vertical on karst fluting
     - wood: along the grain
     - thatch: down-slope
     - water streaks: along the flow
4. **Medium strokes with painted light** (150-400 per tile, 2-6% of the tile). Each medium stroke is painted three
   times:
   - a `dark` copy offset down by 15% of its radius (the occlusion under it)
   - the body in `mid` or `light`
   - a thin `light` sliver offset up by 20% (the top light)

   "Up" is the texture's -V on vertical surfaces (walls, cliffs, bark, planks on end) and **direction-free** on ground
   textures. On the ground, slivers point randomly with a 60/40 bias to +V, so the ground never shows a fixed sun.
5. **Height map and cavity AO.**
   - Every dab also writes height: big strokes add 1.0, medium add 0.5, in their own shape.
   - Cavity = blur(height, 1/24 of the tile) − height, clamped to [0, 1].
   - Darken by cavity × 0.35-0.5 toward the ramp's `dark`, shifted cool:
     - rock: toward blue-violet `#4a4e63`
     - foliage and grass: toward blue-green `#24492c`
     - wood: toward brown-violet

   This is the painted AO.
6. **Edge highlight** (rock, wood, stone). Where the height gradient faces up (-V), lighten by 15-20% toward `light`.
   Rims of slabs and plank edges catch it. Never on ground textures.
7. **Accent pass** (sparse, 2-5% of the area):
   - grass: flower specks (from `flowers`) and a few warm tips
   - rock: moss on top edges (from `moss`, only where the height gradient faces up)
   - dirt: pebbles as flat 2-tone ovals
   - wood: knots and dark nail heads
8. **Finish.**
   - Blur 0.6 px, then unsharp-mask at radius 1/32 of the tile (amount 0.4) so stroke edges stay crisp after mips.
   - Clamp each channel to the ramp's dark..light span; nothing reaches 0 or 255.
   - Grain: optional, at most 2% value amplitude, 2-px scale. Default off.
9. **Alpha** (terrain slices only): A = 0.6 × normalised stroke height + 0.4 × big-stroke mask. The terrain's height
   blend then makes grass tufts poke through dirt, and rock edges cut crisply.
10. **Value budget** (sRGB mean of the whole tile, ±0.05). These keep the world readable and stop any one surface
    shouting:

    | Surface | Mean | Surface | Mean |
    |---|---|---|---|
    | Grass | 0.45 | Terrace rice | 0.55 |
    | Forest floor | 0.30 | Dirt path | 0.52 |
    | Laterite | 0.45 | Paddy mud | 0.38 |
    | Karst limestone | 0.62 | White river stone | 0.82 |
    | Timber | 0.38 | Weathered plank | 0.55 |
    | Roof tile | 0.32 | Thatch | 0.55 |
    | Plaster | 0.80 | Lacquer red | 0.42 |
    | Indigo cloth | 0.28 | Bone cloth | 0.82 |

    **Contrast within a tile:** ground 0.25-0.75; rock 0.20-0.85. White river stone and the falls are the only
    things allowed above 0.85.
11. **Squint test** (automatic, every texture):
    - Downscale to 1/16 and upscale back. It must still read as its material with 2-4 visible blobs of variation.
    - Tile it 3 × 3 at 1/8 size. No visible repeat grid: no single stroke may be darker or lighter than the tile mean
      by more than 0.25.

    Every texture writes `<name>_check.png` beside itself (the 3 × 3 tile plus the squint) for the lineup.

### 3.3 Terrain slices for R1 (the Thủy Vân array)

There are 9 slices. Each is painted with the recipe above, in the existing array format (2048² RGB + A) so a Thủy Vân
copy of the terrain shader can sample it.

| Slice | Material | Ramp | Flow and notes |
|---|---|---|---|
| 0 | Lush grass | `grass` | Tufts and clumps 0.25-0.6 m; 1-2 m patches; flower specks |
| 1 | Terrace rice | `terrace_rice` | **Rows:** parallel strokes 0.25 m apart, so rice reads as rows along the terrace contour; warm yellow-green |
| 2 | Forest floor | `forest_floor` + `moss` | Leaf litter dabs in the accent; dark |
| 3 | Dirt path | `dirt_path` | Flat pebbles 5-15 cm; wheel-free (a foot and mule world) |
| 4 | Laterite (red earth) | `laterite` | Banks and cuttings; strata faint |
| 5 | Paddy mud | `paddy_mud` | Wet: two values only, with sky-glint accent specks |
| 6 | Karst limestone (also the triplanar rock) | `karst_limestone` + `cliff_stain` | Horizontal strata 0.6-1.2 m, vertical fluting, dark water streaks, moss on top edges |
| 7 | White river stone and gravel (Đá Trắng) | `white_stone` | Rounded pebbles 5-40 cm, very pale; cool-grey AO; the brightest ground |
| 8 | Moss and fern ground | `moss` + `fern` | Under the falls' spray and on wet ledges |

---

## 4. Shape language and proportions

**General rules:**
- **Exaggerate scale and thickness**, never detail.
- **Bevel only big edges:** 5-15 cm on buildings, 0.3-1 m on rock.
- **Every asset passes the silhouette test:** rendered as a flat black shape 64 px tall, it is still recognisable.
- **Smooth normals inside facets, hard between big planes.**

| Asset | Shape language | Proportion and exaggeration |
|---|---|---|
| Karst tower | Leaning 5-15°; 3-6 stacked slab tiers stepping in toward the top; vertical fluting; undercut waist or foot on a third of them; a flat-ish crown with 3-9 round pine puffs; ledges with shrub rows. Never a cone or a smooth spike | Height 2.5-5 × width. R1's hero towers are 110-240 m. Real Guilin-style towers are about 1.5-2 × as tall as wide, so this is about 2× real |
| Gorge and cliff walls | Vertical faces broken into 5-8 m strata bands (the terrain's `strata_m` 7); every third band a ledge with green; dark wet streaks under every seep; waterfall notches | Walls read steeper than the height field (meshes over the sheer cells) |
| Boulder | 2-3 big planes and a pillowy top; sits sunk 20% into the ground with a moss cap | 1-6 m |
| White river stone | Rounded, smooth, pale cream-white, almost no strokes; dark jade water between | 0.3-3 m, grouped along flow lines; several sit just under the surface so they read through the water |
| Stone bridge and piers (Two Heights) | Massive tapered piers of oversized ashlar (blocks 1.2-2 m); round arches; a chunky parapet; banners on the piers; **two different maker signs on one pier** (bible L16); frayed offerings tied above serviced bolts | Piers 1.3× as thick as engineering needs; deck parapet 1.2 m |
| Stilt house (Mountain Folk) | Raised on 1.5-3 m piles; bamboo-weave or plank walls; **the roof is 45-55% of the total height**; eaves overhang 1.0-1.5 m; corners turned up 0.4-0.8 m; ridge with curled ends; thatch or wood shingle | Doors 2.2 m; planks 0.3 m wide; roof edge 0.25-0.35 m thick (about 2× real) |
| Cliff house | Cantilevered over the drop on 2-4 visible beams with diagonal braces; a balcony rail; tile roof with upturned eaves | Beams 0.35 m; braces read from 300 m |
| Clan house | Two-tier hip roof with upturned corners; carved ridge; red lacquer columns at the front; raised on a stone plinth | Footprint about 12 × 9 m; total height about 11 m |
| Hanging rope bridge | Deck planks 0.3 × 0.08 m with 3-6 cm gaps; posts every 3-4 m with rope rails at hip height (1.1 m); a net side; tall anchor posts (4-5 m) with banners; rag flags on the rails | Rope 8-12 cm (about 2× real); sag 1/12-1/15 of the span |
| Clan waystone | A leaning slab menhir, tapered, slightly twisted; carved clan mark in the top third; tally notches down one edge; base cairn of rounded stones; two prayer-flag ropes running to poles | 3.5-5 m tall, 1.2 m wide |
| Banner | Tall vertical cloth (1:3) on a pole with a crossbar; indigo field, bone-white clan mark (ours), madder-red tails and streamers | 1.5× real; on the bridge heads and waystones |
| Prayer flags | Rectangular rags 30 × 45 cm on ropes, ragged hems; colours from `indigo_cloth`, `madder_cloth`, `ochre_cloth`, `bone_cloth`, `jade_cloth` | Ropes 3 cm |
| Paper lantern | Round or barrel ribs, dark caps, red-orange paper, a short tassel | 1.3× real (0.6-0.8 m) |
| Terrace walls | Dry-stone retaining walls 0.8-1.5 m following the contour, slight batter, a grass lip on top; earthen bunds on paddies | Stones 0.3-0.6 m |
| Sampan | Low curved hull, upswept bow and stern, woven bamboo canopy, one pole | About 7 m long |
| Fences | Bamboo rails and wattle panels, slightly leaning, irregular | Posts 10-14 cm |
| Broadleaf tree | Thick, slightly twisted trunk; crown of 3-7 big round cloud puffs; the WoW lollipop cluster, never a realistic leaf mass | 8-18 m; crown 60-75% of the height |
| Karst pine | Flat-tiered umbrella crown (2-4 horizontal puff layers), sinuous trunk growing out of cracks | 4-12 m; on every karst top and ledge |
| Bamboo | Clumps of 8-20 culms, curving outward; leaf masses as soft blobs at the tops | 6-12 m |
| Fern, banana, shrubs | Big readable fronds and leaves | Fronds 1-2 m |
| Waterfall | Ribbon cards: body, edge foam, base mist puff; white with cool shade streaks | Flow drawn **2-3× real**: a 3 m stream reads as an 8 m fall |
| Mist band | Long soft horizontal cards at set heights | 200-800 m wide, 20-60 m tall |

**Architecture palette rules:**
- Mountain Folk build in timber, thatch and wood shingle, with indigo, madder and bone cloth.
- Stone Children build in dressed white limestone and dark tile, with ochre banners and a carved maker's mark.
- Red lacquer appears only on a clan house's columns, lantern paper and banner tails, at most about 5% of any view.

## 5. Polygon budgets and materials

### 5.1 Triangle budgets (LOD0 / LOD1 / far)

| Asset | LOD0 | LOD1 | Far |
|---|---|---|---|
| Karst hero tower (110-240 m) | 4-8k | 1.5k | 300 or a skyline card past 2.5 km |
| Karst backdrop tower | 1-2k | 400 | Card |
| Cliff wall module (40 × 30-75 m) | 1.5-3k | 600 | — |
| Boulder | 150-600 | 80 | — |
| White river stone (instanced) | 60-200 | 24 | — |
| Two Heights bridge (whole) | 8-14k | 3k | 600 |
| Bridge needle (rock pillar) | 1.5-2.5k | 500 | — |
| Stilt house | 2.5-5k (roof 1-1.5k) | 800 | 150 |
| Cliff house | 3-5k | 900 | 150 |
| Clan house | 5-8k | 1.5k | 300 |
| Rope bridge (per 70 m span) | 4-6k (planks merged) | 1.2k | Rope lines only |
| Waystone + cairn + flags | 0.8-1.4k | 300 | — |
| Banner on pole | 200-400 | 80 | — |
| Lantern | 150-300 | 40 | — |
| Terrace wall (per 10 m) | 300-600 | 120 | — |
| Sampan | 1.5-2.5k | 500 | — |
| Fence (per 3 m) | 100-200 | 40 | — |
| Broadleaf tree | 1.5-3k (puff cards) | 600 | Impostor |
| Karst pine | 1-2k | 400 | Impostor |
| Bamboo clump | 1-2k | 400 | Impostor |
| Fern | 100-300 | — | — |
| Grass tuft card | 4-8 | — | — |

**Frame budget for the vista on medium:** at most about 1.8M triangles visible, at most about 1,500 draw calls. Kit
pieces merge per material key, as RingDressing does, so a village is a handful of draws. At most about 600 MB of
textures resident for R1.

### 5.2 Godot 4.7 materials: keep the paint

The paint carries the light. Godot adds only soft sun, coloured ambient and contact shadow, so the two never fight.

**World geometry is lit.** Only effects and far painted cards are unshaded.

| Class | Godot 4.7 setup |
|---|---|
| Common to all lit surfaces | `diffuse_mode = DIFFUSE_LAMBERT_WRAP`; `specular_mode = SPECULAR_SCHLICK_GGX` with `specular` 0.1-0.2 and `roughness` 0.85-1.0; `metallic` 0. **No normal maps**, or one soft normal (strength 0.2-0.35) derived from the painted stroke height, on rock only. No ORM or detail maps. `vertex_color_use_as_albedo = true` (section 5.3) |
| Terrain | A Thủy Vân copy of the terrain shader (new file under `shaders/thuyvan/`; never edit `shaders/terrain/terrain.gdshader`), with these changes: the normal-array fetch dropped (flat); roughness 0.95; tile 8 m; triplanar rock at 16 m over 38°; anti-tiling kept at 2.7× (it suits painted tiles); macro variation raised to ±12% value and ±8° hue over 60-250 m; height-blend depth 0.25 |
| Rock and karst | A painted-rock shader. World-space triplanar of the painted limestone (16 m tile on karst, 6 m on boulders), multiplied by vertex colour RGB. A moss mask from vertex colour A × smoothstep(0.55, 0.8, world normal y) blends in `moss`. Lambert wrap 0.3 |
| Village kit | A StandardMaterial3D per material key (wood, plank, thatch, tile, plaster, lacquer, cloth, rope, iron, paper), with albedo from the trim sheet × vertex colour. Lacquer alone has roughness 0.55 and specular 0.35 (the one gloss in the village). Lantern paper has emission (off by day, on by direction). Cloth uses a wind-waving cloth shader, as the ring's banner shader does (a Thủy Vân copy) |
| Foliage | Alpha-scissor cards (threshold 0.5, `alpha_antialiasing_mode` alpha-to-coverage). Normals bent to the crown sphere, so a crown shades as one soft ball, as the existing painted trees do. Lambert wrap 0.45; back-light transmission 0.25 in a warm yellow-green; vertex colour AO dark at the crown's core. **No banded `painted_light.gdshaderinc` light** (that is the toon band the owner rejected). If a painted-tree shader is reused, `band_soft` is at least 0.4 so the terminator is smooth |
| Water | Custom river shader (Thủy Vân copy):<br>• albedo from the depth ramp `water_depth` (deep → mid → shallow → over white stones), so the shallows are pale jade<br>• alpha by depth, 0.5 at 0 m to 0.92 at 3 m, so white stones show through<br>• a painted flow-streak texture scrolling along the channel's flow UV<br>• foam where the depth fade under 0.25 m meets rocks, banks and the falls' feet<br>• fresnel sky tint 0.3; roughness 0.15; one sun glint; refraction off |
| Falls, foam, mist, lantern halos | `shading_mode = UNSHADED`, alpha blend, colour × a per-direction `light_tint` uniform (sun colour × 0.6 + ambient × 0.4), so they track the mood. `proximity_fade` 4-20 m and `distance_fade` near the camera. Falls scroll at 0.6-1.2 m/s in three layers (body, streaks, edge foam) |
| Far skyline cards (karst past 2.5 km) | Unshaded, painted already lit, tinted toward the fog colour by distance |
| Sky | A painted panorama (`PanoramaSkyMaterial`, or a Thủy Vân sky shader that adds the sun glow and blends the horizon to the fog colour). Never the frontier HDRI |

### 5.3 Vertex colour convention (every Blender mesh)

| Channel | Meaning |
|---|---|
| RGB | Baked occlusion × top-light gradient, multiplied into the albedo. Mean about 0.85; crevices and under-eaves 0.5-0.6; ground contact 0.65; top surfaces 1.0 |
| A | A mask. Rock: moss amount. Foliage: wind weight (0 at the trunk, 1 at the tips). Cloth: pin weight. Everything else: 1 |

In Blender, bake RGB from Cycles AO (distance 2 m for props and houses, 15 m for karst) mixed 70/30 with a world-Z
gradient. Clamp to 0.5-1.0 so nothing goes black.

### 5.4 Light, shadow, fog and sky

**Light ratio.** The sunlit-to-shade luminance ratio is about 2-2.5 : 1 (WoW-flat; realism is about 6 : 1). Achieve it
with a high, **coloured** ambient (sky contribution 0.5-0.6 plus an ambient colour), so shadows keep hue: blue-violet
by day, violet at dusk. Shadows are never black or grey.

**Renderer settings:**
- **Shadows:** soft (angular 0.8-2°), PSSM 4 splits on medium and high.
- **SSAO:** contact only: radius 1 m, intensity 0.6. The rest of the occlusion is painted in.
- **SDFGI:** off in the look, so painted AO stays the authority.
- **Glow:** threshold 0.9, intensity 0.4, bloom 0.05, so falls, lanterns and sun-rims halo softly.

**Tonemap and grade:**
- AgX at contrast 1.05-1.15 (the frontier uses 1.45, too hard for paint).
- A new Thủy Vân 3D LUT. The frontier's grade pulls greens toward olive; ours never does.
- Saturation is set per direction. Mid-grey albedo (0.5 sRGB) under noon light must render at 0.55-0.60, so the paint
  reads as painted.

**Fog:**
- Exponential depth fog with aerial perspective 0.4-0.7, coloured per direction.
- Height fog fills the valleys (layered under the mist cards).
- `fog_sun_scatter` glows toward the sun at dusk.
- The far karst layers must fade in steps: 15%, 35%, 60%, 80% fog at the 4 depth layers.

**Mist bands.** Godot's fog alone cannot draw bands. Mist is cards at fixed heights per direction (`palettes.json`
`mist_bands_m`), with soft painted edges, crossing behind towers and under bridges. The sheets always have mist
between near and far.

**Sky:**
- A painted 4096 × 2048 panorama per direction.
- Big soft cumulus, 2-3 values each (lit top, body, cool base), and a sun glow painted where the light is.
- A far range of karst silhouettes painted into the lower sky in 2 fog-tinted layers. They continue the backdrop
  meshes, so the skyline never ends in a flat horizon.

---

## 6. Foliage painting (cards and crowns)

**Crowns:**
- Each card is a cluster of 6-15 rounded leaf dabs in one atlas cell. Its alpha is the union of the dabs, cut by a
  firm edge.
- Colour comes from the species ramp: `dark` inside, `mid` body, `light` on the dabs' upper halves.
- The atlas cell already holds the crown's lighting: lighter on top, darker beneath and inside.

**Puffs.** A tree is 3-7 puffs. Each puff is 8-20 cards on a sphere, with normals bent to that sphere. Like this, a
tree reads as 3-7 soft balls. That is the WoW crown, and it matches the sheets' round pine crowns.

**Karst pines:** puffs flattened into horizontal tiers, darker (`pine`).

**Ground cover:**
- **Bamboo:** cards of leaf sprays on thin culm meshes. Culm colour `bamboo` with darker nodes every 0.3-0.4 m.
- **Grass cards:**
  - wide-bladed tufts, 3-5 blades per card, colour gradient from the ground's `grass` dark at the root to the
    light/accent at the tip
  - the root colour equals the terrain slice's mean, so grass melts into the ground
  - heights 0.3-0.8 m; density highest at terrace edges and paths' shoulders
- **Rice:** row-aligned clumps on the paddy steps, bright `terrace_rice`.

## 7. Waterfalls, foam, mist and the river

**Falls** are three layers of cards:
1. **Body ribbon:** a vertical 512 × 2048 texture of painted streaks in `foam_fall`, scrolling.
2. **Edge foam:** a lumpy white outline at the lip and down both edges.
3. **Base:** 3-6 billboard puffs of spray, plus a ring of foam cards on the pool.

Every fall also gets a mist card at its foot and a dark wet stain on the rock behind it (vertex colour B, or a decal).

**The river:**
- Pale jade over the white stones; jade-teal in the channel; deep blue-green in pools.
- White water (foam streak cards) wherever the bed steps or stones break the surface.
- In the S1 still state, the flow streaks and foam stop. Everything else is unchanged: the white stones stay visible
  under a glassy surface (sensory anchor). The shader needs only a flow-scale uniform.

**Mist cards:**
- 1024² soft cloud-shape textures: 3 values; the lit top is lighter.
- Horizontal bands, 200-800 m wide, at set heights.
- Plus drifting puffs (8-30 m) along the gorge.
- They scroll slowly (0.3-1 m/s) and fade by distance, so the camera never sees a card edge.

## 8. Per-zone palettes

Full ramps are in `palettes.json` and `palettes.png`. The key colours per zone follow. Sun, fog and sky per direction
are in section 10.

**R1, Đá Trắng and the Two Heights** (Trường Sơn foothills; Mountain Folk and Stone Children). This is the first
zone, and it is built now.

| Group | Colours |
|---|---|
| Greens | grass `#4e8a36` / `#84b546`; terraces `#86ae3c` / `#b9cf55` / `#e2d873`; broadleaf `#3b7036` / `#67a043`; pine `#2f634a` / `#4f8a5a`; moss `#4f7a33` |
| Stone | karst limestone `#8e8c88` / `#c9c2b2` with shade `#4a4e63`; white stone `#e8e3d3` / `#fbf7ec` |
| Earth | dirt `#8c6a47`; laterite `#9a4e30` |
| Water | `#12404a` → `#1f6e6c` → `#3fa294` → `#8fd1c2`; falls and foam `#eef3f0` |
| Built | timber `#64472f`; weathered plank `#a39173`; roof tile `#3a5460`; thatch `#8e7342`; plaster `#e3dac2` |
| Cloth and colour accents | indigo `#2d3d6e`; madder `#a33a28`; ochre `#b07f2e`; bone `#e9e0c6`; jade cloth `#4e8577`; lacquer `#8e2e22`; lantern `#f08a44` / `#ffb45a` |
| Mood | cool jade and moss greens against warm cream stone; the white stones and falls are the highlights |

**The other regions, from their sheets.** Each zone is one hue family and one mood. Its own landmark reads from 1 km.

| Region | Identity and key colours | Landmark and mood |
|---|---|---|
| Thạch Uyên (Stone Valleys) | Warm white quarry stone `#e6dccb` / `#b9aa95` with violet shade `#6f6a78`; ochre banners `#c7962f`; kiln brick `#9a4a2c` and fire `#ff8a3a`; smoke `#a29c96`; turquoise canal `#3fb0a8` / `#1f7a80`; crane timber `#5a3e2a` | Arched aqueducts, cliff sanctuaries with carved figures, cranes. Hazy bright noon; warm dust; smoke columns |
| Đồng Lau (Reed Marches, Khar-Ul) | Reed gold `#c7b36a` and green `#7f9a48`; silver marsh water `#6e8e8a` / `#a9c2bc`; mud `#6b5e46`; grey stilt timber `#8a8070`; thatch `#a88c55`; indigo heron banners `#2f416a` with bone `#e6ddc6`; lanterns `#ffb060` | Stilt forts on forests of piles. Low overcast, flat silver light, fog close, white birds |
| Vực Sen Sâu (Deep Lotus Reaches) | Cave rock `#2b3a3a` / `#4e6460`; dark teal water `#0f3b40` with glow `#2d8c88`; lotus pink `#e67fa0` / `#f7b9c9`; pads `#3f7a3c`; amber lanterns `#ffb24e`; ceramic blue `#3f7a8c` | Light-shaft caverns, curtain falls. Dark with pools of warm light; the only zone where lanterns lead by day |
| Vạn Thủy (lock city, Cửu Giang delta) | River blue-grey `#5f8fa0` / `#2e5e70`; quay stone `#cfc6b4`; dark tile `#2e3a44`; red lacquer towers `#a33a2c`; court indigo `#24386e` with gold `#d8a743`; dock timber `#6a4c34`; sails `#d8c9a6`; rice `#9dc24e` | Floodgates and lock towers in water to the horizon. High bright sky, many sails, glittering water |
| Lâm Uyên (Verdant Deep) | Deep canopy `#1f4a2e` / `#3e7a3c` / `#77a84a`; moss `#8db04a`; bark `#3a3226`; root wood `#5a4632`; falls white `#eef2ec`; green mist `#bfd0c4`; white flowers `#f2eedc` | Giant root bridges and stepped falls. Green-filtered light, shafts through mist |
| Ảo Thành (City of Illusions) | Night sky indigo `#1b2246` / `#2e3a6e`; moon `#f4ebd0`; lantern red `#c23a2a` with paper glow `#ffb45a` and gold `#e0a83e`; lacquer black `#2a1a16`; crimson banners `#9e2a2a`; reflecting water `#2c3550` with gold glints | The night city of lanterns, bridges and theatres. Moonlit; warm against indigo |

**Not drawn yet:**
- The Buried Kingdom (Book V material).
- The map sheet's legend, rivers I-VIII and the Convergence (plan 3.3 items 25 and 27).

## 9. Marks, text and what not to copy from the sheets

**Marks:**
- The Trường Sơn waystone in the sheet carries a swirl emblem that resembles a well-known emblem from Avatar: The Last
  Airbender. **Do not reproduce it or anything like it.** Our clan marks are our own: geometric knot, mountain and
  tally forms built from straight cuts and one ring, as a stonemason would cut them.
- The Thạch Uyên diamond-knot "maker's mark" and the bridge banners' ring-and-rune marks are inspiration for the kind
  of mark, not shapes to copy. The Two Heights pier carries two different maker signs (bible L16), both ours.
- The Tidebreak ring's element glyphs (`assets/ring_kit/glyphs.png`) belong to the sport. Never use them as clan or
  place marks.

**Text:**
- No Hán characters anywhere in world art (plan section 2: no CJK font). The sheets' Hán labels are also misread
  (plan 3.4).
- Carvings are marks and tallies, not writing.
- Any Latin-script text in the world (signboards) uses the one approved OFL family, with Vietnamese diacritics.

**WoW:**
- Take its principles only: painted tiling textures, chunky forms, zone palettes, painted skies, fog mood.
- Never its specific forms: no orc spikes, Alliance or Horde motifs, WoW trees, rock meshes, icons or fonts.

## 10. Three directions for the owner

Each direction uses the same albedo and changes only light, sky, fog, mist and grade (`palettes.json` →
`directions`). The vista builder renders V1 in all three for the owner to choose from.

1. **Jade Mist Morning.** The closest to the sheets.
   - **Sun:** low from the east-north-east (azimuth 75°, elevation 14°), cream `#ffe2b8`, energy 1.6.
   - **Sky:** pale blue-grey `#8fb4cf` → `#e4ebe6`, with low cloud banks round the peaks.
   - **Ambient:** `#a9c4cc`.
   - **Fog:** `#cfdcda`, density 0.0007, aerial perspective 0.6; height fog thick under 175 m.
   - **Mist:** three bands at 145-165, 185-200 and 265-285 m.
   - **Grade:** contrast 1.05, saturation 1.10.
   - **Feel:** cool and quiet, jade and moss; the white stones and falls glow.
2. **Bright Saturated Noon.** The closest to WoW Classic (Elwynn's green meets Stranglethorn's lush).
   - **Sun:** high from the south-south-west (200°, 58°), `#fff3d9`, energy 2.4.
   - **Sky:** deep cerulean `#2f7fd6` → `#cde9f4`, with big white cumulus.
   - **Ambient:** `#9ec3e6` at 1.25.
   - **Fog:** light blue `#b5d3ec` at 0.00035; only a thin gorge mist.
   - **Grade:** contrast 1.15, saturation 1.25; shadows blue-violet.
   - **Feel:** vivid greens, crisp silhouettes, the flags pop.
3. **Golden Lantern Dusk.**
   - **Sun:** setting behind the Two Heights (285°, 5°), orange `#ff9a45`, energy 1.3; backlight.
   - **Sky:** peach and violet `#4b4a8c` → `#8e6fa6` → `#f2a66b` → `#ffd08a`, with clouds lit from beneath.
   - **Ambient:** violet `#6e6a9e` at 0.7.
   - **Fog:** warm `#d99a7a` toward the sun, violet `#7a6e9c` in the valleys; sun scatter 0.35.
   - **Lanterns:** village lanterns, windows and bridge-head lamps lit; smoke under the roofs.
   - **Grade:** a warm/cool split.

## 11. Every builder's lineup

**The render:**
- Blender Eevee, 1920 × 1080, to `look/<builder id>/`.
- Lit like a bright game scene: sun at elevation 40° from the front-left, a sky-coloured world light at 0.6, soft
  shadows, AgX contrast 1.05.
- On a neutral painted ground plane, using the grass slice when PAINT has made it, otherwise flat `#84b546` with a
  painted-noise variation.
- A human-height marker (1.75 m figure silhouette) beside every asset.

**What every lineup shows:**
- the asset's variants side by side
- one 3/4 view with its silhouette (flat black) inset
- its triangle count and material keys printed under it
- its textures' squint checks for PAINT

**Bold variants:** wherever a choice is open (tower lean, roof curve, rope thickness), show A/B/C side by side, as the
owner judges by eye.
