# Tidebreak

A playable local demo of a third-person elemental arena game built in Godot 4.7 with GDScript. Earth, Water, Fire and Air fighters battle on a raised deck over water. Build damage, launch your opponent and send them into the water to take a life.

Open this project in Godot and press **F5**. Choose **Quick match**, or use the **Tidebreak** match setup to select your element and opponent. **Practice** has a training opponent with no round timer or score; **Lessons** teaches the controls one move at a time.

The default Lives rules give each fighter three lives and an eight-minute match limit. Basic controls are the default for new players. Full controls and the older Zones rules are available from the game menus.

| Input | Action |
|---|---|
| WASD / Shift | Move / sprint |
| Mouse | Look and aim |
| Left click | Quick attack |
| 1 / 2 | Select your strike / push; right-click to cast |
| Right click | Tap to queue a cast, or hold and release to charge; supported moves grow when held longer |
| E | Guard; hold to keep the shield up |
| Space | Jump, then double jump; hold for recovery help with Basic controls |
| 2 while airborne, then right-click | Your element's downward attack; Earth's is Hammer |
| 3 | Dash; air dodge with Full controls |
| 4 / 5 | Wall / heal with Full controls, or after unlocking them with Basic controls |
| F1 / Esc | Help / game menu |

## Current presentation

The title screen, loading views and application name use Tidebreak. The arena palette uses slate blues, warm cream, clay and brass, with softer noon lighting. The colors are our interpretation of the owner's Planetes reference; reference stills are not bundled as game assets.

- [Palette comparison and validation](docs/tidebreak/planetes_palette.md)
- [One-minute gameplay trailer](docs/tidebreak/one_minute_trailer.md)
- [Latest combat timing and rebrand checks](docs/tidebreak/air_cast_and_branding.md)
- [Animation fluidity changes and verification](docs/tidebreak/animation_fluidity.md)

## Project map

| Area | Location |
|---|---|
| Arena, movement, lives, recovery and replay | `scripts/ring/`, `data/ring/` |
| Elemental casting and effects | `scripts/bending/`, `scripts/sway/`, `data/sway/moves.json` |
| Opponents | `scripts/npc/`, `data/npc/bend_ai.json` |
| Title screen and player interface | `scripts/ui/`, `assets/ui/tidebreak/` |
| Focused regressions | `tests/ring/`, `tests/bending/`, `tests/ui/` |
| Local run wrapper | `tools/loop/godot_run.sh` |

The game is a local demo; this repository does not provide a public download or a deployed multiplayer service. Technical resource keys and existing profile-storage paths remain compatible with earlier builds. Historical prototype documentation is preserved in [the archived README](docs/archive/prototype_readme.md). Animation provenance records remain in `animations/SOURCE.md` and `docs/animation_provenance.md`.
