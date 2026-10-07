# Thủy Vân character traits and features (proposal, 2026-10-06)

Our own procedural assets for the six human-shaped peoples on today's body (peoples_design 2.4 and 2.8). Nothing here
is traced from the owner's sheets or any other source; no download.

| Path | What | Made by |
|---|---|---|
| `traits/trait_order_tv.png` | Order maps in body.glb's MakeHuman UVs (CUSTOM0): R scales, G plates (one value per plate), B river sheen, A river scale patches. A texel is marked where order < amount x 255 | `tools/thuyvan_art/traits/trait_maps.py` (numpy, fixed seeds) |
| `traits/trait_detail_tv.png` | R plate crack distance (0.1 mm steps), G plate hash, B gill slits, A sheen noise | same |
| `traits/ash_marks_tv.png` | The rite's ash marks: R brow thumbprint, G cheek fingers, B backs of the hands, A powder grain | same |
| `traits/traits_maps.json` | The channel table and the texel size per region | same |
| `fox/ho_tinh_ears_{pointed,rounded,tufted}.glb/.json` | Fox ears rigid on `headb`, shape keys `ear_back`, `ear_flat`, `ear_perk`; paint in COLOR_0 (R value, G tip, B inner ear / tuft) | `tools/thuyvan_art/traits/build_fox_parts.py` (Blender, through the shared lock) |
| `fox/ho_tinh_tails_{1,3,9}.glb/.json` | 1, 3 or 9 fox tails on their own extension bones `fox_tail_<k>_<01..05>` (parent `pelvis`); paint in COLOR_0 (R value, G tip) | same |
| `../shaders/tv_traits.gdshaderinc` | The shader of trait kinds 3 scales, 4 plates, 5 river and the ash marks (included by `people_trait.gdshaderinc`) | by hand |

Data: `data/thuyvan_art/traits.json` (the people rows' `trait`, `tint`, `reflect_eye` blocks and the ash markings) and
`data/thuyvan_art/fox_features.json` (tail bones, springs, pose layer, fur colours). Visual only: nothing is a stat,
nothing is locked to a people, and every face, skin tone and hair stays a choice for every people.

Rebuild: `python3 tools/thuyvan_art/traits/trait_maps.py`; check: `python3 tools/thuyvan_art/traits/test_trait_maps.py`.
