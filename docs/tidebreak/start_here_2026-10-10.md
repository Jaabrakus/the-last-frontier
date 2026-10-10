# Start here (addendum to HANDOFF.md, 2026-10-10)

Read `HANDOFF.md` first (the game, the rules, the code map). This page covers what was built after it was written, how to set
up on a new machine, what is switched off, and what is waiting on the owner.

## Set up

- **Engine:** Godot 4.7 (the project says `config/features = 4.7`), GDScript only. The tools and wrappers below are written
  for macOS; the game itself is not tied to it.
- **Open / run:** `Godot --path <repo>` (main scene `scenes/main_menu.tscn`), then Tidebreak, Quick match or Practice.
- **First run on a fresh checkout:** `Godot --headless --path <repo> --import` once (builds `.godot/`, registers the
  `class_name` scripts), then `Godot --headless --path <repo> -s tools/compile_check.gd` (every script must say "0 bad").
- **Lock wrappers (use them for every Godot/Blender run):** `tools/loop/godot_run.sh`, `blender_run.sh`, and the test runner
  `tools/loop/run_test_fps.sh <repo> <log name> <tests/x.gd> [args]`. They keep at most 3 runs going at once and time-limit
  each run. Overrides: `GODOT_BIN` (the Godot binary), `GODOT_SLOTS`, `GODOT_TIMEOUT`, `TB_LOCK_DIR`, `TB_SCRATCH` (logs).
  A green test is EXIT 0 + a PASSED/OK line + `SCRIPT ERROR count: 0`.
- **Windows opened by tools are normal windows** (never always-on-top): the owner keeps video in front. Do not set the
  always-on-top flag or move a window to the foreground in new scripts; `tools/ui_audit/capture_kit.gd` has the shared
  window policy (`TB_ON_TOP=1` pins a window on purpose).
- **Known failing tests (before this work, not new):** `test_hud_skills` 1/33, `test_hud_vitals` 2/16, `test_fishing` 2/17,
  `test_story` 1/30, `test_mammoth_knee` 1/19.

## What was built since HANDOFF.md (all in `main`)

| Area | What | Where to read |
|---|---|---|
| Skill trees | Design + data for 133 talents (4 elements, ring budget of 10 points, open-world unlocks, 14 held for owner answers), 19 open owner questions | `docs/skill_tree_design.md`, `data/sway/skill_tree.json` |
| Fighting styles | Design (20 classes = element + style), Boxing (fire) clips, Capoeira clips (PARKED: the owner did not like them), style tools | `docs/fighting_styles_design.md`, `docs/fighting_styles/`, `animations_extra/Frontier_Style_*.res`, `tools/anim_author/` |
| Advancement window | In-game "Character Advancement" window (two trees, class rail, 3 loadout slots per element, painted backdrops). Saves to `user://advancement.json` | `scripts/ui/advancement/`, `data/ui/advancement*.json`, `assets/ui/advancement/`, tests `tests/ui/test_advancement*.gd` |
| Loadouts live | The worn loadout reaches matches: Boxing per fighter (animation only) and 8 number-only talents per wearer behind a switch. Classic (nothing worn) is unchanged | `docs/tidebreak/loadouts_live.md`, `scripts/bending/bend_loadout.gd`, `data/bending/loadout_apply.json` |
| Menus | Broadcast-style menus: lobby main menu with your fighter, match setup with four fighter cards, Esc menu, match-end board; the creator ends on "Choose your element" (saved with the character) | `scripts/ui/menu/`, `scripts/ring/ring_menu.gd`, `assets/fonts/barlow/` (OFL fonts), mockups in `tools/ui_audit/menu_variants/` |
| Menu/HUD fixes | Esc menu fits 1280x720, HUD hidden under overlays, rules text follows Lives vs Zones, first-match key hints collapse, practice banner, credits | `scripts/ui/`, `data/ring/` |
| Spellbreak FX | The rebuilt Spellbreak particle runtime is in the game and **switched OFF** (the owner prefers our own particles). Only the lightning bolt uses Spellbreak shading | `docs/claude_fx_handoff.md` (Update 2026-10-10), `scripts/fx/cascade/`, `data/bending/sb_fx/` |
| Tooling | Capture kit, fx lineup tools, portable lock wrappers | `tools/ui_audit/`, `tools/fx/`, `tools/loop/` |

## Switches (what is on / off)

- `data/bending/sb_fx/config.json`: master + one per element for the Spellbreak effects. **All four are `false`.** Do not turn one on
  without a side-by-side the owner picks from (`tools/fx/fx_lineup.gd el=<element>`).
- `BendLooks.SB_BOLT` (lightning look): `true`; `false` brings the old blue bolt back exactly.
- `data/bending/loadout_apply.json`: `enabled` and per-node switches for the 8 live talents. Nothing applies unless the
  player has worn a loadout in the window (the default is Classic).

## Third-party material and what is deliberately NOT in this repository

- **Spellbreak (Proletariat):** the owner states Proletariat licensed the Spellbreak assets for Tidebreak. The written grant's
  location is still blank in `animations/SOURCE.md` (line ~548: "Written grant: [where you keep it]"): the owner has to fill
  it in. Everything taken from Spellbreak keeps its attribution (`assets/fx/spellbreak/SOURCE.md`).
- **Left out on purpose:** the Unreal Marketplace pack files found inside the Spellbreak client
  (`assets/fx/spellbreak/assets/MarketplaceAssets/`, git-ignored; another vendor's, not covered by that note). One dormant
  water effect needs them and the tests skip it when they are absent.
- **Left out on purpose:** another session's WIP that extracts assets from a Nintendo (Wii U) disc image
  (`tools/reference_world/`, `scripts/labs/`, `shaders/labs/`, `docs/asset_lab_world.md`, `docs/extracted_assets_lab.md`,
  `docs/expedition_world_slice.md`, `docs/character_rig_style_probe.md`, `data/retarget/botw_*`,
  `tools/character/botw_style_preview.gd`). It is unreviewed and not ours to publish: it stays local until the owner decides.
- **Not in git (local only):** `artifacts/` (rebuild outputs, mockups, screenshots; the skill-tree web mockup generator is
  `artifacts/skill_tree_page/build.py`) and `Spellbreak_Reference_Extracts/`. The 10 GB Spellbreak client backup zip is on the
  owner's external drive "The one" (`/Volumes/The one/Frontier_offload/Spellbreak_source_backup/`); the effect extraction
  tools in `tools/reference_animation/` read it.

## Working rules (the owner's, keep them)

- No target cues of any kind (no ring / marker / outline on opponents). Nothing slows the player or hurts their aim when hit.
- A talent extends a move and never swaps its identity. Easy to learn, hard to master.
- Fonts / art / sounds: our own or properly licensed; record provenance in the folder's SOURCE.md.
- Several people and tools share one checkout: commit only your own hunks, run Godot only through the lock wrappers, never
  open the character creator from automated runs (the owner is tired of it popping up), show before/after images for art
  changes (the owner judges by eye).
- Weapons are ON HOLD (a separate animator is making them).

## Waiting on the owner

1. The 19 skill-tree design questions (`data/sway/skill_tree.json` `open_questions`, end of `docs/skill_tree_design.md`) and the
   14 "held" talents.
2. Menus, second pass: loading screen, practice, settings, credits, round screen (the first pass did the lobby, match setup, Esc
   menu and match end).
3. Whether to extend live loadouts beyond Boxing and the 8 number-only talents (the plan is in
   `artifacts/ui_audit/advancement/plan.md` Phase B3, local only; the summary is in `loadouts_live.md`).
4. The Proletariat written-grant location (above), and whether to publish the Spellbreak-derived files (`assets/fx/spellbreak/`,
   ~88 MB, dormant) outside the private repository.
