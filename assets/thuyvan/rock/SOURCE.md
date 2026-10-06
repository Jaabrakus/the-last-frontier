# Thủy Vân ROCK kit (R01-R08): sources

Everything here is made by us. The meshes are built by our own Python scripts in Blender. The textures are painted
by our own Python script (numpy + PIL) to the brush recipe in `docs/thuyvan/plan/look/style_guide.md` §3.2. Colours
come from `docs/thuyvan/plan/look/palettes.json`. No photographs, downloaded art, scans or third-party models are
used, and no Blizzard or Avatar: The Last Airbender asset, form or emblem.

The owner's concept sheets (Trường Sơn, Thạch Uyên) were the visual target for shape, colour and mood only. No sheet
pixels are in any file here. The two maker signs on the Two Heights pier are our own marks:
- A: "plumb and ring"
- B: "square and three steps"

They are not the sheets' diamond-knot mark.

How to rebuild: `docs/thuyvan/rock_kit.md`.

| File(s) | What | Made by |
| --- | --- | --- |
| `textures/karst_face.png`, `karst_face_height.png`, `karst_face_check.png` | Karst limestone, 16 m tile, 2048²: strata, vertical flutes and fissures, seep stains, moss clumps; the stroke height; the 3×3 / squint check | `tools/thuyvan_art/rock/rock_paint.py` (seed 1601) |
| `textures/karst_pale.png`, `_check` | The same recipe on the white-stone ramp (the bridge needle) | `rock_paint.py` (seed 1611) |
| `textures/white_stone.png`, `_check` | Đá Trắng's smooth pale river stone, 4 m tile, 1024² | `rock_paint.py` (seed 1702) |
| `textures/ashlar.png`, `_check` | Dressed white limestone courses for the Two Heights, 8 m tile | `rock_paint.py` (seed 1803) |
| `textures/moss_cap.png`, `_check` | Moss and fern for ledges, mounds and boulder caps, 4 m tile | `rock_paint.py` (seed 1904) |
| `textures/lineup_grass.png`, `_check` | The lineup renders' painted ground (stand-in until PAINT's grass slice) | `rock_paint.py` (seed 2005) |
| `textures/mist_card.png` | A soft mist band card, for the internal diorama only (PAINT's P10 replaces it) | `rock_paint.py` (seed 2106) |
| `textures/rock_textures.json` | Per texture: tile size, mean value and budget, squint and stroke check numbers | `rock_paint.py` |
| `karst_hero_a..e.glb` (+ `_lod1`) | R01 hero karst towers, 110-240 m: clusters of faceted slab columns, leaning, stepped ledges, shrub mounds | `tools/thuyvan_art/rock/rock_kit.py` in Blender |
| `karst_far_a..f.glb` (+ `_lod1`) | R02 backdrop towers, modelled 200 m tall | `rock_kit.py` |
| `cliff_<kind>_<h>.glb` (+ `_lod1`) | R03 gorge-wall modules, 40 m wide, 30/60/75 m: straight, convex, concave, notch, ledge | `rock_kit.py` |
| `boulder_a..f.glb` (+ `_lod1`) | R04 limestone boulders, 1-6 m | `rock_kit.py` |
| `white_stones.glb` (+ `_lod1`) | R05 the 12 white river stones, 0.3-3 m, one node each | `rock_kit.py` |
| `white_stones_c1.json` | R05 scatter: 400 stones along C1's bed and banks, 20% just under the surface | `tools/thuyvan_art/rock/scatter_white_stones.py` (seed 1603) over the T4 bake and the R1 layout |
| `two_heights_bridge.glb` (+ `_lod1`), `two_heights_head_n/_s.glb` (+ `_lod1`) | R06 the arched stone bridge: two piers, two maker signs, bolt plates with frayed offerings; the two natural stone heads | `rock_kit.py` |
| `bridge_needle.glb` (+ `_lod1`) | R07 the 62 m white-limestone needle under the rope bridge | `rock_kit.py` |
| `cairn_a..e.glb` | R08 burial cairns | `rock_kit.py` |
| `rock_kit.json` | Per piece: Godot-frame size, triangles per LOD, material keys, seats | `rock_kit.py` |
| `painted_rock.gdshader` | The painted-rock shader: triplanar paint × vertex colour, moss by vertex alpha | Written by hand for this kit |
| `materials/*.tres` | One Godot material per material key | `tools/thuyvan_art/rock/write_godot_materials.py` |
