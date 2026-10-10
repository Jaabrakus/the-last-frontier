# Character Advancement window: art provenance

All of this is our own work, made 2026-10-09 and 2026-10-10 for the in-game Character Advancement window
(`scripts/ui/advancement/`, plan: `artifacts/ui_audit/advancement/plan.md`). Nothing here is third-party art, and
nothing is Spellbreak-derived (`artifacts/spellbreak_fx` is not read by any tool that wrote these files).

## What the owner's reference clip was used for

The owner supplied a short clip of another game's talent window (11 frames in `artifacts/ui_audit/reference/`). It was
looked at for the **layout only**: two lattices left and right, a painted picture between them, a tall rail at the right
edge, a bottom bar with dropdowns, a search box and a Save button, tabs under the frame, toasts, a Loadouts list. No
frame, icon, glyph, mark, picture, font or sound of that game was traced, copied, extracted or imported, and none of its
names appear on screen (`tests/ring/test_player_words.gd` scans the window's words).

## Painted backdrops (4)

`backdrop_earth.jpg`, `backdrop_water.jpg`, `backdrop_fire.jpg`, `backdrop_air.jpg`: 1920x1080 JPG, one per element.

- Made by `tools/menu/paint_advancement.gd` (a windowed Godot run; `-- [only=earth,water] [raw] [probe]`). It stages a view
  in our own ring (`scenes/ring.tscn`: its deck, tank, stands, banners and sky, RingLook's moods) with our own element
  effects (the raised stone of `FormRaised`/`FormModels`, `BendZone`, the flame and wind materials of `ToonFx`/`BendLooks`,
  the ring's own water-curtain shader `shaders/ring/ring_curtain.gdshader`), renders it off-window at 2560x1440
  (`tools/environment/offscreen_view.gd`) and runs it twice through our own `shaders/ui/oil_paint.gdshader` (broad masses,
  then strokes, canvas and varnish), the recipe of `tools/menu/paint_views.gd`, with smaller brushes than the menu's (7 px
  then 3 px). A last pass (the tool's `FINISH_SHADER`) brings the render's own edge detail back into the centre gap (the sides
  keep calm paint, so the trees' rank digits and plates sit on quiet ground) and holds the highlights under 0.84 with a soft
  shoulder, so the focal forms (the column's stones, the geyser's sleeve, the funnel's bands, the flames) stay crisp and no
  white blows out.
- earth: a ring of raised slabs round a stone column with boulders lifted, golden hour. water: a geyser thrown up out of
  the tank at night under the moon, standing in a pale stone basin lit teal (a torus rim, a disc of water and a light, all
  made in the tool). fire: a blaze with two lines of fire running in along the deck, dusk, embers rising. air: a whirling
  funnel of wind, dust, stones and torn cloth over the deck, noon.
- No fighters, no figures. The window darkens the tree zones at run time (`AdvancementWindow`: a fade over the picture, so
  the shade can be tuned without painting again).
- SHA-256 (2026-10-10, the second painting: crisper brushes, edge detail and the highlight cap, after the critic's note that
  the first was muddy and posterised):
  - air `df91b0c34cad95c9314e96227baaf28d569530586b02d63ba10303da9e5ad1dd`
  - earth `6d3fd291dbf8c34abe956205d1501e7fd16ab98ff6c0909756d489c3f29accfe`
  - fire `2892fc911cb0e6928adeb53c1ea4509afe7504416fcf572ef2908e0b48b61f72`
  - water `089a78f99f8c36835ce3e03024c0331c10eee159fefb1aee3bcf0d5ac46a6356`

## SVG pieces (55)

Written by hand as path data in `tools/ui/advancement_art.py` (it writes every one, and `art.json`), in the line family
of `tools/ui/move_icons.py` (round caps, strokes 3.4 / 2.8 / 1.6 on a 64 grid; white, tinted at draw time, except the
frame pieces, which carry their own gold and stone colours from `AdvancementTheme`). Rasterised at 2x by the importer.

- `frame_corner.svg` (a knot for the frame's corners, mirrored), `rail_frame.svg` and `rail_cap.svg` (the tall rail
  with diamond caps), `padlock.svg` (the gate's lock), `choice_arrow.svg`, `rank_plate.svg`, `toast_frame.svg`.
- `kind_<kind>.svg` (7): twist (a fork), technique (a star), new skill (a spark), synergy (two linked rings), skill set
  (a hexagon), passive (a ringed dot), world art (a peak).
- `set_<set>.svg` (4): sulphur (a rising puff), mud (ringed ripples), magma (a cracked seam), frostwind (a jagged
  crystal). Outline shapes, so they read without their tint.
- `style_<style>.svg` (17): one glyph per fighting style (each element's four and Jeet Kune Do).
- `emblem_<element>_<style>.svg` (20): the class emblems (a medallion ring, the style's glyph, the element's mark in a
  badge), for the portrait, the Loadouts list and the class picker.
- Every skill-tree node's picture is `assets/ui/icons/spell_<move>__<mode>.svg` (the HUD's own move icons) or one of the
  37 drawn for this window (listed in `art.json` under `drawn_for_window`, and in `assets/ui/icons/SOURCE.md`).

## Contact sheet

`artifacts/ui_audit/advancement/art_sheet.png`, made by `zsh tools/loop/godot_run.sh --path . --resolution 1600x900
-s tools/menu/paint_advancement.gd -- sheet`: the backdrops, the frame pieces, marks, glyphs, emblems and every node's
icon at the sizes the window draws them.

## Type

The window's type is Barlow Condensed and Barlow Semi Condensed (SIL Open Font License 1.1), see
`assets/fonts/barlow/SOURCE.md`.

## Drawn in code (no files; second pass, 2026-10-10)

The node plates (jewel gradient, gloss, lit rim, glow behind the picture, kind and skill-set hues), the stone bevel of the
frame and the portrait medallion's ring, the gate stubs' shade and the lattice's cross links are all drawn at run time from
gradients, polygons and lines (`AdvancementNode._draw`, `AdvancementTheme.glow_tex` / `stub_tex`, `AdvancementWindow._draw_bevel`,
`AdvancementTree._draw`). No picture was loaded or traced for them; the colours are the element colours of
`data/ring/elements.json` and `data/ui/advancement.json` colors (`kind_*`, `set_*`, `live`).

## Third pass (2026-10-10, gaps repair): drawn in code and one shader, no new files of art

- The node plates were redrawn in `AdvancementNode._draw`: the hue led by the kind and tinted by the element (turned a
  little per pick from a hash of its id), a deeper jewel with the light picture on top (a dark halo of four nudged copies of
  the same HUD picture), the kind's motif behind it (light rays or rings: polygons and arcs), the rank in a small plate inside
  the lower right corner and, under a shut newcomer gate, the padlock (`padlock.svg`, above) with the gate's number there.
- `shaders/ui/adv_backdrop.gdshader` (our own, written for this window): behind each tree and the rail the painting is
  softened (a 9-tap blur), drained of most of its colour and darkened, with a wide soft edge; the centre gap is untouched.
  It reads the four painted backdrops above as they are (no painting was changed).
- The lattice (where the nodes stand) is `tools/ui/advancement_layout.py`'s diamond packer: positions only, no art.

## Fourth pass (2026-10-10, critic's second notes): drawn in code, no new files of art

- Plates: the kind alone sets the jewel (`data/ui/advancement.json` colors `kind_*`), the element's colour is a ring inside the
  border. The HUD pictures are drawn by their inked part (`AdvancementTheme.ink_rect`, the bounding box of their visible
  pixels) at about 72% of the plate and thickened by four sub-pixel copies of the same picture. A number trade's corner mark
  is a stat glyph (shield, two-headed arrow, arrow, double chevron, clock, burst, plus) drawn as lines and polygons in
  `AdvancementTheme.draw_stat_glyph`; a shut gate's padlock is the same `padlock.svg`, larger, over the picture.
- `shaders/ui/adv_backdrop.gdshader` was rewritten (still ours): one elliptical falloff round the centre art instead of
  rectangles, and a soft dimming of the centre's brightest parts. No painting was changed.
