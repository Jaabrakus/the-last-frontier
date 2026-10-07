# Thủy Vân peoples' dress: what is built (2026-10-06, branch tv/PP-DRESS)

The dress half of `peoples_design.md` (scratchpad `peoples_places/`), built with cloth2 on today's body and rendered for
the owner. Status: **proposal** for the owner's eye; nothing here is a stat, nothing is locked to a people, every face,
skin and hair stays open.

## Review pages

`scratchpad/peoples_places/review/DRESS/` (3000 x 1820 pages; the raw 1920 x 1080 Eevee renders in `raw/`):

| Page | What |
|---|---|
| 01 / 02 | Mountain Folk everyday dress, female (short robe) and male (wrap vest, basket), front / 3/4 / back, and a closer view |
| 03 | Mantle fringe A/B/C: strips 10-19 cm (default), long 14-24 cm, two tiers |
| 04 | Hip-panel layers A/B/C: 3 / 2 / 4 wound layers |
| 05 | Clan dyes A/B/C: Stone-Ridge, Cloud-Pass, High-Pine (owner question 5) |
| 06 / 07 | Stone Children work dress (quarry hat on the female, carry frame and block on the male), and closer |
| 08 | Quarry hat brim A/B/C |
| 09 | Dragon-Sea dock woman and dock worker |
| 10 | R1 NPCs: the imperial levy soldier (owner question 6) and the clerk |
| 11 | Conical hat brim A/B/C |

Every page sets the render beside the matching crops of the owner's sheets (comparison only), the flat black silhouette
inset, and under it each garment's triangles against its budget and its zone dyes.

## Garments (cloth2, `tools/character/cloth2/garments/tv_*.py`; glbs in `assets/character/garments/<set>/`)

- **tv_highland** (Mountain Folk): `tv_mf_wrap_vest`, `tv_mf_short_robe`, `tv_mf_trousers`, `tv_mf_hip_panels`,
  `tv_mf_sash` (bronze mark disc, teeth, bone beads, tassel), `tv_mf_leg_wraps`, `tv_mf_sandals`, `tv_mf_brow_band`,
  `tv_mf_shoulder_mantle` (fringe strips, fur ruff, hawk feathers), `tv_mf_back_basket`.
- **tv_stone** (Stone Children): `tv_sc_work_tunic`, `tv_sc_shade_cloth`, `tv_sc_trousers`, `tv_sc_leg_wraps`,
  `tv_sc_apron_sash` (chisels in kiln-red cord, jade disc, tassel), `tv_sc_sandals`, `tv_sc_quarry_hat`,
  `tv_sc_carry_frame` (A-frame, shelf, dressed block).
- **tv_delta** (Dragon-Sea): `tv_ds_dock_jacket`, `tv_ds_rolled_trousers`, `tv_ds_short_robe` (tide-scroll weave),
  `tv_ds_long_skirt`, `tv_ds_sash_strings` (shells, pearls, tassel), `tv_ds_sandals`, `tv_ds_levy_coat` (quilting),
  `tv_ds_levy_hat`, `tv_ds_clerk_robe`, `tv_ds_clerk_cap`.
- **tv_common**: `tv_conical_hat`.

## New cloth2 pieces

- `cloth2/tv_dress.py` (re-exported by `recipes.py`): `leg_wraps`, `sandals` (rope / toe / heavy / slippers),
  `fringe_mantle`, `dangles` (beads, discs, teeth, tassels, shells, coins, chisels, jade discs, feathers, our mark disc),
  `carry` (tall basket, round basket with lid, carry frame), `hip_panels`.
- `dress.ROBE` `sleeves: None` (round armholes; `recipes.coat` "sleeveless").
- The `tv_*` dyes in `cloth2/palette.json` (each `peoples_dyes.json` mid).
- Painted cloth: `tools/thuyvan_art/dress/paint_dress.py` -> `assets/thuyvan/dress/paint/*.png` (value maps on the dye's
  4-stop ramp: weave, hemp, felt, leather, fur, straw, cord, metal, bone) and `motifs/*.png` (band_motif, quilting,
  house_mark, tide_scroll; our own straight-cut marks and one ring form). Garments name them in `extra.tv_paint` /
  `extra.tv_motif`; the frontier cloth shader ignores those keys (wiring them into a Thủy Vân cloth material is the
  lead's lane).
- `data/thuyvan_art/peoples_dyes.json` (the ramps), `data/thuyvan_art/peoples_dress.json` (lineup outfits, clan dyes,
  NPC outfits per people: the dress half of `thuyvan_peoples.json`).

## Tools

- `dress_session.py`: builds and exports garments through the lock on a rig copy, builds A/B/C variants in memory
  (`variants.py`), caches every mesh for the renders.
- `dress_render.py`: the lineup renders (Eevee, sun 40 deg front-left, sky 0.6, AgX, painted grass, silhouette pass);
  hides the body regions the garments hide, as the game's hide mask does.
- `compose_dress.py`: the review pages.

## Known gaps

- Not built yet: the formal Mountain Folk pieces (oath robe, oath mantle, pectoral), the tattoo atlas page, the new hair
  styles and hair ornaments, W4-W7 (Ancestor-Bound, Hồ Tinh, Dragon-Sea court and SHEER kit, Riverborn), the Stone
  Children formal pieces, `tags`, `BOARD_CROWN`, `tail_slit`.
- Traits are not in the renders (plates, scales, water tint: the shader lane), nor tattoos.
- The male fit's crotch on every wide trouser reports vertices inside the skin (the same -18 mm as the frontier
  `slops`: the genitals are hidden under legwear by design). Some `bl` (bust gauge) fits report small insets on long
  robes, and the cone hats report a spurious -150 mm on `bl` (a brim far from the body measured against the bust).
- Not run in Godot (no deform check in-engine): the lead runs `check_body_deform.gd` and the outfit shots.
