# Thủy Vân village kit: where every file came from

Everything in this folder was made by us for the game, procedurally, from scripts in `tools/thuyvan_art/village/`
(rebuild steps: `docs/thuyvan/village_kit.md`). No downloaded art, no photographs, no pixels from the concept sheets,
nothing from any other game or show. The owner's concept sheets (Trường Sơn, Mountain Folk) were the visual target for
shape, colour and mood only; colours come from the art director's `docs/thuyvan/plan/look/palettes.json` (copied byte
for byte to `tools/thuyvan_art/village/palettes.json`).

## Textures (`textures/`)

Painted by `paint_village.py` (Python, numpy and PIL) with the style guide's brush recipe (section 3.2): fixed seeds
(CRC32 of the key), painted on a torus so every tile wraps, from one 4-stop palette ramp per material. Rebuilding gives
the same bytes.

| File | Material key | Made by | How |
| --- | --- | --- | --- |
| timber.png | timber | us (paint_village.py `p_planks`) | 0.5 m boards along U, grain strokes, knots, checks; 2 m tile |
| plank.png | plank | us (`p_planks`, gaps) | weathered 0.3 m planks with dark gaps, lit top edges, nail heads; 4 m tile |
| thatch.png | thatch | us (`p_thatch`) | 0.45 m courses of vertical straw bundles, each course's fringe over the one below; 4 m tile |
| shingle.png | shingle | us (`p_shingle`) | 0.25 m courses of split wood shingles with lit butts; 4 m tile |
| tile.png | tile | us (`p_tile`) | slate-teal barrel tiles: cover tiles over channel tiles, lit lips, moss specks; 4 m tile |
| weave.png | weave | us (`p_weave`) | 2/2 twill of split bamboo, each strip shaded round; 2 m tile |
| basket.png | basket | us (`p_weave`) | the same twill in rope colours at 1 m |
| plaster.png | plaster | us (`p_plaster`) | lime plaster: flat broad strokes, light patches, hairline cracks; 4 m tile |
| lacquer.png | lacquer | us (`p_lacquer`) | deep red lacquer, darker pools, soft vertical gloss streaks, worn spots; 2 m tile |
| rope.png | rope | us (`p_rope`) | twisted strands as diagonal stripes, fibres; circumference = 1/4 tile |
| iron.png | iron | us (`generic_ground`) | dark iron patches |
| bamboo.png | bamboo | us (`p_bamboo`) | fibres along the culm, nodes every 0.33 m, a lit stripe |
| drystone.png | drystone | us (`p_drystone`) | coursed dry-stone: rounded stones, warm dark joints, lit tops, moss on top edges; 4 m tile |
| limestone.png | limestone | us (`p_limestone`) | warm grey limestone, horizontal strata, dark water streaks; 4 m tile |
| grass.png | grass | us (`p_grass`) | grass tufts tilted +-25 degrees, clumps, flower specks; 4 m tile |
| earth.png | earth | us (`p_earth`) | dirt path with flat two-tone pebbles; 2 m tile |
| jar.png | jar | us (`p_earth`) | laterite-red earthenware |
| skin.png | skin | us (`p_earth`) | the porters' skin tone (no pebbles) |
| paper.png | paper | us (`p_paper`) | red-orange lantern paper with fibres (emission by direction) |
| cloth_indigo.png, cloth_madder.png, cloth_ochre.png, cloth_bone.png, cloth_jade.png | cloth_* | us (`p_cloth`) | homespun cloth: vertical folds, faint weave |
| banner_indigo.png, banner_ochre.png, banner_jade.png | banner_* | us (`p_banner`, `marks.py`) | 1:3 banner fields with our own clan marks (two_peaks, terrace_river, pine_ring), woven border bands |
| flags.png | flags | us (`p_flags`, `marks.py`) | prayer-flag atlas: 5 cells (indigo, madder, ochre, bone, jade), each with a small block print of our marks, frayed hems |
| waystone_face.png | waystone_face | us (`p_waystone`, `marks.py`) | the clan waystone's carved face: our two_peaks mark, four neighbour-clan marks, tally notches, moss at the foot |

**Marks** (`marks.py`): our own geometric marks built from straight cuts and at most one ring (style guide section 9).
None of them resembles the Trường Sơn sheet's swirl emblem (an Avatar emblem look-alike, deliberately not used), the
sheet's ring-and-rune banner marks, the Thạch Uyên diamond knot or the Tidebreak ring's element glyphs. No writing and no
Hán characters anywhere.

## Meshes (`*.glb`) and `manifest.json`

Modelled procedurally in Blender 5.2 by `village_kit.py` (with the helpers in `tvkit.py`, which follow the ring kit's
Builder idiom): every vertex is computed from the script's own parameters and fixed seeds. The colour attribute
(COLOR_0) is ambient occlusion baked by our own ray caster times a top-light gradient. The GLBs carry no images; their
materials are named `tvv_<key>` and use the textures above. `manifest.json` lists each piece's triangles, material keys,
size, anchors and colliders.

| File | Asset (vista spec id) | Made by |
| --- | --- | --- |
| stilt_house_small.glb, stilt_house_large.glb | V01 Mountain Folk stilt houses (thatch; wood shingle) | us (village_kit.py `stilt_house`) |
| cliff_house.glb | V02 cliff house cantilevered over the gorge | us (`cliff_house`) |
| clan_house.glb | V03 clan house, two-tier roof, lacquer columns | us (`clan_house`) |
| gate_pavilion.glb, gate_tower.glb | V04 bridge-head gate; Two Heights gate tower | us (`gate_pavilion`, `gate_tower`) |
| rope_bridge_span_30m.glb, rope_bridge_span_63m.glb, rope_bridge_span_73m.glb, rope_bridge_anchor.glb, rope_bridge_needle_platform.glb, rope_bridge_r1.glb | V05 hanging rope bridge (modules and the assembled R1 bridge D1-D4) | us (`rope_bridge_span`, `bridge_anchor`, `needle_platform`, `assemble_bridge`) |
| clan_waystone.glb | V06 clan waystone with cairn, rag offerings and flag ropes | us (`waystone`) |
| banner_indigo.glb, banner_ochre.glb, banner_jade.glb | V07 banners on poles | us (`banner`) |
| prayer_flags_4m.glb, prayer_flags_8m.glb, prayer_flags_12m.glb | V08 prayer-flag ropes | us (`flag_rope`) |
| lantern_round.glb, lantern_barrel.glb, lantern_post.glb, bridge_lamp.glb | V09 lanterns | us (`lantern_set`) |
| terrace_wall_straight_4m.glb, terrace_wall_curve_in_4m.glb, terrace_wall_curve_out_4m.glb, paddy_bund_4m.glb | V10 terrace walls and paddy bund | us (`terrace_wall`, `paddy_bund`) |
| sampan.glb | V11 sampan with woven canopy, pole and fish basket | us (`sampan`) |
| fence_bamboo_3m.glb, fence_wattle_2m.glb | V12 fences | us (`fence_bamboo`, `fence_wattle`) |
| drying_rack.glb, basket_set.glb, firewood_pile.glb, water_jars.glb | V13 village clutter | us (`drying_rack`, `basket_set`, `firewood_pile`, `water_jars`) |
| survey_camp.glb | V14 survey camp | us (`survey_camp`) |
| porter_standing.glb, porter_walking.glb, porter_pole.glb | V15 scale figures | us (`porter`) |
