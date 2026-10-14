# Thủy Vân Reed Marches stilt kit (Đồng Lau, dl_*): where every file came from

Everything in this folder was made by us for the game, procedurally, from scripts in `tools/thuyvan_art/dong_lau/`
(rebuild steps: `docs/thuyvan/dong_lau_kit.md`). No downloaded art, no photographs, no scans, no third-party models, no
pixels from the owner's concept sheets, nothing from World of Warcraft (its principles only) or from Avatar: The Last
Airbender. The Đồng Lau sheet and the Floodborn sheet's homeland panel were the visual target for shape, colour and mood
only. Colours come from the art director's `docs/thuyvan/plan/look/palettes.json` (`albedo.dong_lau`, plus r1's rope,
iron, laterite, madder and bone dyes and limestone; the dry marsh bamboo is painted on reed gold, named in `materials.json`; no hex value retyped).

## Textures (`textures/`)

Painted by `paint_dong_lau.py` (Python, numpy and PIL) with the style guide's brush recipe (§3.2), using the village
kit's canvas and painters (`tools/thuyvan_art/village/paint_village.py`, imported) plus this kit's own; fixed seeds (CRC32
of `thuyvan-dong-lau-<key>`), painted on a torus so every tile wraps. Rebuilding gives the same bytes.

| File | Key | Made by | How |
| --- | --- | --- | --- |
| timber.png | timber | us (`p_planks`, village) | grey weathered stilt timber, 0.5 m boards, 2 m tile |
| plank.png | plank | us (`p_planks`, gaps) | weathered 0.3 m deck planks with dark gaps and lit edges, 4 m tile |
| pile.png | pile | us (`p_pile`) | round-pile grain along the length, split checks, knots, 2 m tile |
| thatch.png | thatch | us (`p_thatch`, village) | 0.45 m courses of straw bundles, 4 m tile |
| reed.png | reed | us (`p_bundle`) | bound reed bundles, rope ties every 0.5 m (burial boats, ridges), 2 m tile |
| weave.png, screen.png | weave, screen | us (`p_weave`, village) | woven wall mats (thatch ramp, 2 m) and drying screens (reed gold, 1 m) |
| rope.png | rope | us (`p_rope`, village) | twisted rope, r1 rope ramp |
| net.png | net | us (`net_rgba`) | knotted diamond net, 8 cm mesh, RGBA (alpha-scissor) |
| iron.png, bamboo.png | iron, bamboo | us (village painters) | r1 iron; dry bamboo on the reed-gold ramp |
| mud.png | mud | us (`p_earth`, village) | mudflat, 4 m tile |
| clay.png | clay | us (`p_earth`) | hearths, troughs, horns (r1 laterite) |
| bark.png | bark | us (`p_bark`) | mangrove bark: long flutes, lenticels, 3 m tile |
| leaf.png | leaf | us (`p_leaf`) | mangrove crown leaf clumps lit on top, 4 m tile |
| fish.png | fish | us (`p_fish`) | split dried fish, rib stripes, silver edge |
| paper.png | paper | us (`p_paper`, village) | lantern paper (the zone's lantern ramp); emission #ffb060 by direction |
| cloth_madder.png, cloth_bone.png, cloth_indigo.png | cloth_* | us (`p_cloth`, village) | homespun cloth: madder tails, bone, heron indigo |
| banner_heron.png, banner_heron_b.png, banner_heron_c.png | banner_heron* | us (`p_banner`, village; marks in `dl_marks.py`) | 1:3 indigo field with our own heron in bone (A standing, B in the ring, C between reeds), woven border bands |
| reedcard.png | reedcard | us (`reedcard_rgba`) | reed atlas, 4 cells (gold, green, gold with cattails, green with cattails), RGBA |
| tally.png | tally | us (`p_tally`) | the tally post's face: notches in fours with a slash, a ring cut; never writing |
| oldstone.png | oldstone | us (`p_oldstone`) | dark old dressed stone with algae (used only by a review-only object; no shipped piece uses it) |

## Meshes

Built by `dong_lau_kit.py` in Blender 5.2 (headless, procedural, through the shared lock wrapper) with the village kit's
Builder, vertex-AO bake and GLB export (`tools/thuyvan_art/village/tvkit.py`, imported, rebound by `dlkit.py`). GLBs carry
no images: materials are `tvd_<key>` and name the textures above. `manifest.json` lists every piece's triangles (LOD0 and
LOD1), the places_se.md budget, materials, size, anchors and colliders.

| File(s) | What | Made by |
| --- | --- | --- |
| dl_mooring_fort.glb, _lod1 | DL1: the mooring fort (30 x 30 m pile platform, three thatch tiers, galleries, four heron banners, lanterns, haul-out ramps) | us (`mooring_fort`) |
| dl_pile_forest_4m.glb, dl_pile_forest_6m.glb | pile clusters with boat colliders | us (`pile_forest`) |
| dl_platform_ramp.glb, dl_platform_steps.glb | plank platforms with a haul-out ramp or steps | us (`platform`) |
| dl_reed_house_a.glb, _b, _c (+ _lod1) | Floodborn-built house, public-standard house, kitchen hut | us (`reed_house`) |
| dl_raft_house.glb, _lod1 | DL6: floating house | us (`raft_house`) |
| dl_watch_tower.glb, _lod1 | DL2: reed watch tower | us (`watch_tower`) |
| dl_heron_banner.glb | heron banner on a 24 m mast | us (`banner_piece`) |
| dl_tally_post.glb, dl_causeway.glb | DL7: tally post; submerged causeway module | us |
| dl_screen_rack.glb, dl_fish_rack.glb, dl_net_rack.glb, dl_dip_net.glb, dl_soak_trough.glb | drying screens, fish, nets; the lift net; the soaking trough | us |
| dl_mangrove_gallery.glb, _lod1 | DL4: mangrove with root arches | us (`mangrove`) |
| dl_reed_clump_gold.glb, _green, _cattail | DL5: reed card clumps | us (`reed_clump`) |
| dl_reed_boat_burial.glb, _lod1 | DL8: burial reed boat on its drying frame | us (`reed_boat_burial`) |
| dl_dugout.glb, dl_ferry_flat.glb (+ _lod1) | marsh dugout, flat ferry | us (`hull`, `ferry_flat`) |
| manifest.json | the piece table | us (`dong_lau_kit.py`) |
