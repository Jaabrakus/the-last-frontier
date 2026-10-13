# Menu style B, "Arena broadcast": sources

The mock of the style the owner chose on 2026-10-10 ("Arena broadcast"); the game's own version of it is `scripts/ui/menu/broadcast_ui.gd` (BroadcastUI). This folder is the reference mock-up: nothing here is wired into the game. `stage.gd` now only extends `tools/ui_audit/ring_stage.gd`, the ring stager `tools/ui_audit/lobby_backdrops.gd` (a live tool that writes `assets/ui/menu/lobby_*.jpg`) uses too.

| File | What it is | Source |
|---|---|---|
| `../b_broadcast.gd` | The run: renders the ring, then builds and saves the screens | Written for this mock |
| `stage.gd` (now `../../ring_stage.gd`) | Stages `scenes/ring.tscn` (the player in each element's ring dress, the bot held, every CanvasLayer hidden) and takes stills through off-window views, as `tools/ring/palette_shots.gd` does. It also cuts the fighter out: colour from the full render, alpha from a render of the fighter's own meshes on a clear background | Our scene, our characters, our light |
| `screens.gd` | The four screens: the lobby, the match setup, the Esc menu and the match end | Words read from the game's own data at run time |
| `kit.gd` | The style's vocabulary: palette, leaning plates, rows, chips, key caps and gradients | Written for this mock |
| `glyph.gd` | The element marks (peaks, waves, flame, winds), the Any diamonds, the play triangle and the chevrons | Drawn in code with polygons and lines. No icon font and no third-party art |
| `stripes.gd` | The diagonal broadcast hatching | Drawn in code |

Fonts: the mock uses fonts already installed on this Mac through Godot's `SystemFont`: DIN Condensed Bold for headlines and numerals, and Avenir Next Condensed for text. Nothing was downloaded and nothing is bundled. A real build would bundle **Barlow Condensed** (ExtraBold and Bold) and **Barlow Semi Condensed** (Medium), both under the SIL Open Font License 1.1.

Words: the menu rows and their lines come from `MainMenu`, `MatchSetup` (`data/ring/elements.json`, `practice.json`), `KitWords` (`screens.json` kit), `data/ring/rules.json` words, `screens.json` match, `highlights.json`, and the Esc menu's option rows (`RingCamera`, `RingReplay`, `FirstHints`, `Callouts`, `PhotoMode`). The new Fighter area follows `docs/skill_tree_design.md`: class = element + fighting style, 10 points in the ring. The styles shown per element (Sumo, Aikido, Boxing, Capoeira) are from each element's roster in `docs/fighting_styles_design.md`. The match-end numbers come from an invented match written in the game's own formats.

Run (Godot only through the lock):

    zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --fixed-fps 60 \
        -s tools/ui_audit/menu_variants/b_broadcast.gd -- part=all

The outputs, with their own SOURCE.md, are in `artifacts/ui_audit/menu_variants/b_broadcast/`.
