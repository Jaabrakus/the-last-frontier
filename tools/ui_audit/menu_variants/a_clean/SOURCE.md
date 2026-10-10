## SUPERSEDED 2026-10-10: the owner chose style B (scripts/ui/menu/broadcast_ui.gd); kept as a reference mock-up, not wired into the game.

# Menu style mock A ("Clean gold serif"): where its pictures come from

Everything in the mock screens (`artifacts/ui_audit/menu_variants/a_clean/*.png`) is made by
`tools/ui_audit/menu_variants/a_clean.gd` from this project's own scene, shaders and drawing code. Nothing was downloaded.

## Backdrops (this folder)

| File | What it is | Used by |
|---|---|---|
| `bg_night_hero_r.png` | `scenes/ring.tscn` under the game's own "night" light, the player (Fire) at his end in the countdown, an off-window camera in front of him turned 15 degrees so he stands right of centre | main, match |
| `bg_noon_behind.png` | the same ring under "noon", a fixed camera behind the player at his end looking down the deck at the opponent (Water) | pause |
| `bg_noon_hero_r.png` | "noon", the same front camera as the night frame | end |

How they were made: `part=bg` loads the ring with `MatchSetup` set (fire against water, the stock rules), waits for the
countdown, hides every `CanvasLayer` (the HUD and its hints), pauses the tree and renders through
`tools/environment/offscreen_view.gd` (the palette stills' way) at 1600 x 900. No retouching; the blur, shade and veil
you see in the screens are applied live by the mock's own shaders (`BACKDROP_SHADER`, `SPOT_SHADER` in the script).
The banners, gate, stands and fighters are the game's own models and dressing (`RingDressing`, `RingLook`).

Re-render: `GODOT_TIMEOUT=400 zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/menu_variants/a_clean.gd -- part=bg`

## Marks and type

- The element marks (flame, drop, two peaks, three winds), the key caps, the focus bar and glow, the "NEW" tag and the
  play mark are drawn by the script (`Glyph` and `draw_*` calls, `StyleBoxFlat`); no icon set or third-party art.
- Words are the game's own, read at run time from `data/ring/elements.json`, `rules.json`, `screens.json`,
  `practice.json`, `KitWords` and `MainMenu` (the highlight numbers, game lines and tally numbers are sample values).
  New labels this mock adds: "Play", "Fighter", "Class & talents", "Options", "Paused", "The ring sport", "Highlights".
- Fonts: the mock uses fonts installed with macOS through `SystemFont` (Baskerville for the serif, Avenir Next for the
  sans); nothing is bundled. A real build would bundle the SIL Open Font License pair Libre Baskerville and Nunito Sans.
