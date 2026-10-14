# assets/thuyvan/vanthuy: sources

Every file in this folder is **our own work**, made on 2026-10-06 by the VANTHUY builder (Claude, for the owner) with the generators in `tools/thuyvan_art/vanthuy/`: textures painted procedurally in Python (numpy, Pillow) by `paint_vanthuy.py` (the VILLAGE kit's brush engine, `tools/thuyvan_art/village/paint_village.py`, imported unchanged), meshes modelled procedurally in Blender 5.2 by `vt_kit.py` (with the VILLAGE kit's `tvkit.py` helpers). Nothing was downloaded; no photograph, scan, game asset (no Blizzard asset), font or sheet pixel is in any file. Colours come from the art director's `docs/thuyvan/plan/look/palettes.json` (albedo.van_thuy and albedo.r1) and the PROPOSAL ramps in `tools/thuyvan_art/vanthuy/materials.json` (gilt, bronze, old masonry, blue oil, hessian). The court mark and the district marks are our own drawings (`marks_vt.py`): pictures of a gate, a net knot, a sheaf, a hull, stacked tablets and umbrella ribs; no writing, no Hán, nothing from Avatar: The Last Airbender, never the sheets' roundels or seal. Licence: the project's own.

Rebuild: `docs/thuyvan/vanthuy_kit.md`. The `lock_*` pieces are the first block-in pieces of the shared lock kit (Phase 3 M2 owns them).

| File | What | Made by |
| --- | --- | --- |
| `textures/ashlar.png` | painted texture, material key `ashlar` | paint_vanthuy.py (own work) |
| `textures/ashlar_new.png` | painted texture, material key `ashlar_new` | paint_vanthuy.py (own work) |
| `textures/ashlar_old.png` | painted texture, material key `ashlar_old` | paint_vanthuy.py (own work) |
| `textures/bamboo.png` | painted texture, material key `bamboo` | paint_vanthuy.py (own work) |
| `textures/banner_bone.png` | painted texture, material key `banner_bone` | paint_vanthuy.py (own work) |
| `textures/banner_court.png` | painted texture, material key `banner_court` | paint_vanthuy.py (own work) |
| `textures/banner_court_b.png` | painted texture, material key `banner_court_b` | paint_vanthuy.py (own work) |
| `textures/banner_court_c.png` | painted texture, material key `banner_court_c` | paint_vanthuy.py (own work) |
| `textures/banner_indigo.png` | painted texture, material key `banner_indigo` | paint_vanthuy.py (own work) |
| `textures/banner_jade.png` | painted texture, material key `banner_jade` | paint_vanthuy.py (own work) |
| `textures/banner_madder.png` | painted texture, material key `banner_madder` | paint_vanthuy.py (own work) |
| `textures/banner_ochre.png` | painted texture, material key `banner_ochre` | paint_vanthuy.py (own work) |
| `textures/bronze.png` | painted texture, material key `bronze` | paint_vanthuy.py (own work) |
| `textures/cloth_indigo.png` | painted texture, material key `cloth_indigo` | paint_vanthuy.py (own work) |
| `textures/cloth_madder.png` | painted texture, material key `cloth_madder` | paint_vanthuy.py (own work) |
| `textures/cloth_ochre.png` | painted texture, material key `cloth_ochre` | paint_vanthuy.py (own work) |
| `textures/gate_mark.png` | painted texture, material key `gate_mark` | paint_vanthuy.py (own work) |
| `textures/gilt.png` | painted texture, material key `gilt` | paint_vanthuy.py (own work) |
| `textures/hessian.png` | painted texture, material key `hessian` | paint_vanthuy.py (own work) |
| `textures/iron.png` | painted texture, material key `iron` | paint_vanthuy.py (own work) |
| `textures/jar.png` | painted texture, material key `jar` | paint_vanthuy.py (own work) |
| `textures/lacquer.png` | painted texture, material key `lacquer` | paint_vanthuy.py (own work) |
| `textures/notice.png` | painted texture, material key `notice` | paint_vanthuy.py (own work) |
| `textures/oil_glass.png` | painted texture, material key `oil_glass` | paint_vanthuy.py (own work) |
| `textures/paper.png` | painted texture, material key `paper` | paint_vanthuy.py (own work) |
| `textures/paving.png` | painted texture, material key `paving` | paint_vanthuy.py (own work) |
| `textures/plank.png` | painted texture, material key `plank` | paint_vanthuy.py (own work) |
| `textures/plaster.png` | painted texture, material key `plaster` | paint_vanthuy.py (own work) |
| `textures/rope.png` | painted texture, material key `rope` | paint_vanthuy.py (own work) |
| `textures/sail.png` | painted texture, material key `sail` | paint_vanthuy.py (own work) |
| `textures/thatch.png` | painted texture, material key `thatch` | paint_vanthuy.py (own work) |
| `textures/tile.png` | painted texture, material key `tile` | paint_vanthuy.py (own work) |
| `textures/timber.png` | painted texture, material key `timber` | paint_vanthuy.py (own work) |
| `textures/weave.png` | painted texture, material key `weave` | paint_vanthuy.py (own work) |
| `lock_chamber_wall.glb` | 578 tris; lock | vt_kit.py (own work) |
| `lock_chamber_wall_lod1.glb` | LOD1 of `lock_chamber_wall` | vt_kit.py (own work) |
| `lock_gate_gallery.glb` | 1,776 tris; lock | vt_kit.py (own work) |
| `lock_gate_gallery_lod1.glb` | LOD1 of `lock_gate_gallery` | vt_kit.py (own work) |
| `lock_gate_leaf_pair.glb` | 1,176 tris; lock | vt_kit.py (own work) |
| `lock_gate_leaf_pair_lod1.glb` | LOD1 of `lock_gate_leaf_pair` | vt_kit.py (own work) |
| `lock_gate_leaf_pair_open.glb` | 1,176 tris; lock | vt_kit.py (own work) |
| `lock_gate_leaf_pair_open_lod1.glb` | LOD1 of `lock_gate_leaf_pair_open` | vt_kit.py (own work) |
| `lock_gate_tower.glb` | 4,856 tris; lock | vt_kit.py (own work) |
| `lock_gate_tower_lod1.glb` | LOD1 of `lock_gate_tower` | vt_kit.py (own work) |
| `lock_sluice_port.glb` | 250 tris; lock | vt_kit.py (own work) |
| `lock_winch_wheel.glb` | 960 tris; lock | vt_kit.py (own work) |
| `lock_winch_wheel_lod1.glb` | LOD1 of `lock_winch_wheel` | vt_kit.py (own work) |
| `vt_archive_wall.glb` | 1,116 tris; archive | vt_kit.py (own work) |
| `vt_archive_wall_gauge.glb` | 1,344 tris; archive | vt_kit.py (own work) |
| `vt_awning_madder.glb` | 212 tris; boats | vt_kit.py (own work) |
| `vt_awning_ochre.glb` | 212 tris; boats | vt_kit.py (own work) |
| `vt_court_banner.glb` | 348 tris; court | vt_kit.py (own work) |
| `vt_court_banner_lod1.glb` | LOD1 of `vt_court_banner` | vt_kit.py (own work) |
| `vt_court_terrace_1.glb` | 5,438 tris; court | vt_kit.py (own work) |
| `vt_court_terrace_1_lod1.glb` | LOD1 of `vt_court_terrace_1` | vt_kit.py (own work) |
| `vt_court_terrace_2.glb` | 3,234 tris; court | vt_kit.py (own work) |
| `vt_court_terrace_2_lod1.glb` | LOD1 of `vt_court_terrace_2` | vt_kit.py (own work) |
| `vt_court_terrace_3.glb` | 3,014 tris; court | vt_kit.py (own work) |
| `vt_court_terrace_3_lod1.glb` | LOD1 of `vt_court_terrace_3` | vt_kit.py (own work) |
| `vt_court_tower.glb` | 12,458 tris; court | vt_kit.py (own work) |
| `vt_court_tower_lod1.glb` | LOD1 of `vt_court_tower` | vt_kit.py (own work) |
| `vt_crates_stack.glb` | 284 tris; piers | vt_kit.py (own work) |
| `vt_district_banner_archive.glb` | 258 tris; district | vt_kit.py (own work) |
| `vt_district_banner_archive_lod1.glb` | LOD1 of `vt_district_banner_archive` | vt_kit.py (own work) |
| `vt_district_banner_grain_piers.glb` | 258 tris; district | vt_kit.py (own work) |
| `vt_district_banner_grain_piers_lod1.glb` | LOD1 of `vt_district_banner_grain_piers` | vt_kit.py (own work) |
| `vt_district_banner_lantern_ward.glb` | 258 tris; district | vt_kit.py (own work) |
| `vt_district_banner_lantern_ward_lod1.glb` | LOD1 of `vt_district_banner_lantern_ward` | vt_kit.py (own work) |
| `vt_district_banner_naval_basin.glb` | 258 tris; district | vt_kit.py (own work) |
| `vt_district_banner_naval_basin_lod1.glb` | LOD1 of `vt_district_banner_naval_basin` | vt_kit.py (own work) |
| `vt_district_banner_rain_market.glb` | 258 tris; district | vt_kit.py (own work) |
| `vt_district_banner_rain_market_lod1.glb` | LOD1 of `vt_district_banner_rain_market` | vt_kit.py (own work) |
| `vt_door_lamp.glb` | 76 tris; night | vt_kit.py (own work) |
| `vt_drain_mouth.glb` | 292 tris; quay | vt_kit.py (own work) |
| `vt_granary_hall.glb` | 3,742 tris; piers | vt_kit.py (own work) |
| `vt_granary_hall_lod1.glb` | LOD1 of `vt_granary_hall` | vt_kit.py (own work) |
| `vt_high_bridge.glb` | 3,586 tris; bridge | vt_kit.py (own work) |
| `vt_high_bridge_closed.glb` | 3,658 tris; bridge | vt_kit.py (own work) |
| `vt_high_bridge_closed_lod1.glb` | LOD1 of `vt_high_bridge_closed` | vt_kit.py (own work) |
| `vt_high_bridge_lod1.glb` | LOD1 of `vt_high_bridge` | vt_kit.py (own work) |
| `vt_jars_cluster.glb` | 882 tris; piers | vt_kit.py (own work) |
| `vt_junk_river.glb` | 1,794 tris; boats | vt_kit.py (own work) |
| `vt_junk_river_lod1.glb` | LOD1 of `vt_junk_river` | vt_kit.py (own work) |
| `vt_junk_sea.glb` | 1,828 tris; boats | vt_kit.py (own work) |
| `vt_junk_sea_lod1.glb` | LOD1 of `vt_junk_sea` | vt_kit.py (own work) |
| `vt_lacquer_tower.glb` | 8,218 tris; district | vt_kit.py (own work) |
| `vt_lacquer_tower_lod1.glb` | LOD1 of `vt_lacquer_tower` | vt_kit.py (own work) |
| `vt_lantern_net.glb` | 368 tris; night | vt_kit.py (own work) |
| `vt_market_barge.glb` | 1,230 tris; boats | vt_kit.py (own work) |
| `vt_notice_board.glb` | 410 tris; quay | vt_kit.py (own work) |
| `vt_pier_finger.glb` | 996 tris; piers | vt_kit.py (own work) |
| `vt_pier_finger_end.glb` | 1,324 tris; piers | vt_kit.py (own work) |
| `vt_quay_house_a.glb` | 4,032 tris; quay | vt_kit.py (own work) |
| `vt_quay_house_a_lod1.glb` | LOD1 of `vt_quay_house_a` | vt_kit.py (own work) |
| `vt_quay_house_b.glb` | 4,888 tris; quay | vt_kit.py (own work) |
| `vt_quay_house_b_lod1.glb` | LOD1 of `vt_quay_house_b` | vt_kit.py (own work) |
| `vt_quay_house_c.glb` | 3,976 tris; quay | vt_kit.py (own work) |
| `vt_quay_house_c_lod1.glb` | LOD1 of `vt_quay_house_c` | vt_kit.py (own work) |
| `vt_quay_steps.glb` | 278 tris; quay | vt_kit.py (own work) |
| `vt_quay_steps_patched.glb` | 302 tris; quay | vt_kit.py (own work) |
| `vt_quay_wall_20m.glb` | 292 tris; quay | vt_kit.py (own work) |
| `vt_sacks_heap.glb` | 1,104 tris; piers | vt_kit.py (own work) |
| `vt_treadwheel_crane.glb` | 1,158 tris; piers | vt_kit.py (own work) |
| `vt_treadwheel_crane_lod1.glb` | LOD1 of `vt_treadwheel_crane` | vt_kit.py (own work) |
| `manifest.json` | pieces, triangles per LOD, materials, anchors, colliders | vt_kit.py |
| `SOURCE.md` | this file | |
