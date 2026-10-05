# Tidebreak assets (tools/asset_author)

The ring sport's own assets (2026-10-05). The owner: the elemental cartoon "is the inspiration, can we get assets designed
on blender to match that". These are our own designs in that spirit (East and South Asian martial-arts clothing, Arctic
fur-trimmed coats, mountain-monastery robes, curved-roof timber architecture, paper lanterns). No character, outfit,
emblem, insignia or nation symbol is copied, and no show words appear in player-facing text.

## The ring dress (cloth2 garments, catalog set `ring`)

`build_ring_garments.py` builds the garments in Blender on a copy of the Actor_B rig library, the same way
`tools/character/build_cloth2.sh` does. Each garment is a recipe module in `ring_garments/` that uses cloth2's garment
API. It writes `assets/character/garments/ring/<id>.glb` and `.json` and merges only the ring entries into
`assets/character/catalog.json`.

    Blender -b <copy of Actor_B_001.blend> --python-exit-code 1 --python tools/asset_author/build_ring_garments.py -- all
    python3 tools/character/cloth_bake.py <each new glb>
    Godot --headless --path . --import

The build needs `ANIMATION_SOURCE_ROOT`, which points to the rig backup (see `tools/character/README.md`). It also needs
the body cache. Every garment is grown from the MakeHuman body, so it dresses both bodies (the `sex` and bust morphs).

| Side | Garments |
| --- | --- |
| earth | `ring_earth_tunic` (ochre wrap tunic, moss bands), `ring_trousers_wrapped` (shins bound), `ring_sash_earth`, `ring_arm_wraps`, `ring_shoes` |
| water | `ring_water_parka` (blue pull-over with a hood, fur collar, cuffs and hem, an ice chest band), `ring_trousers_fitted`, `ring_water_belt`, `ring_water_boots` (fur-topped) |
| fire | `ring_fire_top` (red sleeveless top, gold stand collar, stiffened shoulder caps, slanting placket), `ring_trousers_fitted`, `ring_sash_fire`, `ring_wrist_guards`, `ring_shoes` |
| air | `ring_air_tunic` (marigold knee-length tunic, wide sleeves, high side slits), `ring_trousers_wide`, `ring_sash_air`, `ring_shoes` |

Each garment has a colour preset per element (`extra.presets`). The wiring is in `data/npc/factions.json`: `ring_team_a`
and `ring_team_b` have `element_dress[element]`, which maps a slot to `{id, colors: {preset}}` (NpcSquad.element_look).
The player's arena dress is the same as `ring_team_a`'s (PlayerAppearance.ring_dress / arena_outfit).

Lineups: `tools/asset_author/ring_outfit_shots.gd` (windowed).

## The arena kit (assets/ring_kit)

`blender/ring_kit.py` authors the pieces procedurally in Blender and exports them as glb. The pieces are the gateway,
curved hip and pyramid roofs, the pillar shaft, base and cap, the paper lantern, the stand canopy, and the glyph atlas
`glyphs.png` with our own element glyphs (earth a mountain over a ground line, water a drop over ripples, fire three
embers, air three wind strokes).

    Blender -b --python tools/asset_author/blender/ring_kit.py -- --out assets/ring_kit

RingDressing (`scripts/ring/ring_dressing.gd`) loads the pieces with `kit_piece`. `place` merges them into its one
DressingMesh by material key (KIT_KEYS), so they add no draw calls. `assets/ring_kit/ring_banner.gdshader` is the ring's
cloth shader drawing the atlas's glyphs on the banners, flags and plaques. Without the kit, the old primitives are drawn.
Renders: `tools/ring/look_c_shots.gd` (variants noon and night). Check: `tests/ring/test_ring_assets.gd`.
