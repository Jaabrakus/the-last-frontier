## SUPERSEDED 2026-10-10: the owner chose style B (scripts/ui/menu/broadcast_ui.gd); kept as a reference mock-up, not wired into the game.

# Menu variant D ("Advancement-matched"): art provenance

Helper art for `tools/ui_audit/menu_variants/d_advancement.gd`, a UI-audit mock that the game does not load.
This folder has a `.gdignore`. The script reads these files as raw SVG text through `Image.load_svg_from_string`.

## Drawn for this project (hand-written SVG path data, 2026-10-09)

- `knot_corner.svg`: the knot used at window corners. It is a square interlaced with a square set on its points, around a gold boss, with arms along both edges and diamond terminals. It is our own geometry and is not traced from any game.
- `medallion.svg`: the gold ring and dark well behind a glyph.
- `plate_red.svg` and `plate_red_hi.svg`: the red-brown button plate and its primary or focused state. They are drawn as 9-slice pieces.
- `crest.svg`: the divider under titles. It has the same knot, with tapering arms.
- `icon_*.svg`: the row glyphs: four (Tidebreak), flag (Start here), bolt (Quick match), post (Practice), tree (Class & talents), bust (Your look), sliders (Settings, Options), book, door (Quit), play (Resume, Begin, Watch), restart, keys (Controls), gate (Main menu), star (Perfect) and any. They are white line art tinted by the UI, in the style of `assets/ui/icons`.

## The game's own art, used as it is

- `assets/ui/icons/spell_mark__<element>.svg` (the element marks) and `assets/ui/icons/spell_<move>__<mode>.svg` (the move glyphs on the talent chips and the class rail). Their record is `assets/ui/icons/SOURCE.md`.

## Backdrops

The backdrops are renders of `scenes/ring.tscn`, the project's own ring. They use RingLook's moods (noon, golden, night) and RingDressing's banners in the element's colours. The effects come from the element's own BendZone, BendEffects and BendLooks code: the Fire Wall, the Geyser with Water streams, the Column with raised slabs and a boulder, and the tornado.

The renders are oil-painted with `shaders/ui/oil_paint.gdshader`, following the two passes of `tools/menu/paint_views.gd`. The outputs are in `artifacts/ui_audit/menu_variants/d_advancement/backdrops/`.

No Spellbreak-derived effect is used. A grep of `scripts/`, `shaders/`, `scenes/` and `assets/` finds no reference to `artifacts/spellbreak_fx`.

## The reference

The owner's clip of a third-party game's "Character Advancement" window (`artifacts/ui_audit/reference`) was used only for its layout language. That language is a stone window with a thin metal trim, knot corners, red-brown action plates and a painted scene behind. No pixel, icon, frame, font or name from that game, or from WoW or Blizzard, is copied.

## Type

The mock uses fonts installed on macOS through SystemFont: Optima for display, Copperplate for small capitals, and Seravek for the body text. No font file is bundled or downloaded.

A real build would bundle the SIL OFL faces of the skill-tree mockup (`artifacts/skill_tree_page`): Marcellus and Marcellus SC for display and small capitals, and Alegreya Sans for the body text.
