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
| Skill trees | Design + data for 135 talents (4 elements, ring budget of 10 points, open-world unlocks, 14 held for owner answers), 19 open owner questions | `docs/skill_tree_design.md`, `data/sway/skill_tree.json` |
| Fighting styles | Design (20 classes = element + style), Boxing (fire) clips, Capoeira clips (PARKED: the owner did not like them), style tools | `docs/fighting_styles_design.md`, `docs/fighting_styles/`, `animations_extra/Frontier_Style_*.res`, `tools/anim_author/` |
| Advancement window | In-game "Character Advancement" window (two trees, class rail, 3 loadout slots per element, painted backdrops). Saves to `user://advancement.json` | `scripts/ui/advancement/`, `data/ui/advancement*.json`, `assets/ui/advancement/`, tests `tests/ui/test_advancement*.gd` |
| Loadouts live | The worn loadout reaches matches: Boxing per fighter (animation only) and 8 number-only talents per wearer behind a switch. Classic (nothing worn) is unchanged | `docs/tidebreak/loadouts_live.md`, `scripts/bending/bend_loadout.gd`, `data/bending/loadout_apply.json` |
| Menus | Broadcast-style menus: lobby main menu with your fighter, match setup with four fighter cards, Esc menu, match-end board; the creator ends on "Choose your element" (saved with the character) | `scripts/ui/menu/`, `scripts/ring/ring_menu.gd`, `assets/fonts/barlow/` (OFL fonts), mockups in `tools/ui_audit/menu_variants/` |
| Menu/HUD fixes | Esc menu fits 1280x720, HUD hidden under overlays, rules text follows Lives vs Zones, first-match key hints collapse, practice banner, credits | `scripts/ui/`, `data/ring/` |
| Spellbreak FX | The rebuilt Spellbreak particle runtime is in the game and **switched OFF** (the owner prefers our own particles). Only the lightning bolt uses Spellbreak shading | `docs/claude_fx_handoff.md` (Update 2026-10-10), `scripts/fx/cascade/`, `data/bending/sb_fx/` |
| Moves (late 2026-10-10) | Hold to cast (no click-and-forget); earth's 2 is the **Fissure** (a crack along the deck like fire's Kick; it throws a held stone, and a free stone it runs under); air's Gust held long is the **Air Lance** (a wind spear, thrown with the overhand spear clip), and water's Turn on the beat takes it: it becomes ice, wraps round the turner and leaves along the turner's aim (2026-10-11, `docs/tidebreak/balance_2026-10-11.md`); fire's kicks free after the strike; the edge-stand stall fixed; no deck boulders | `docs/tidebreak/unfun_notes.md`, `data/sway/moves.json` (earth_shove, air_gust), `docs/skill_tree_design.md` (the Fissure's and the Lance's nodes) |
| Tooling | Capture kit, fx lineup tools, portable lock wrappers | `tools/ui_audit/`, `tools/fx/`, `tools/loop/` |
| Look: Soft (default) | The owner's character study ("03 / softer palette + cel lighting") made the default look of the characters AND the world (owner, 2026-10-10: "this is the new default"). Characters: the study's palette (ring dress: your side teal, the other side cream, the element in the trims) and its soft three-band light. World: the study's sky, flat ambient, warm key light, linear tone curve, every surface in the study's colours, calmed textures; the world's light stays standard (not cel). Settings → Look: Classic gives back the old look exactly. Lobby plates: `assets/ui/menu/lobby_soft_<element>.jpg` | `scripts/customizer/soft_look.gd`, `scripts/world/env/soft_world.gd`, tests `tests/customizer/test_soft_look.gd`, `tests/env/test_soft_world.gd`, review shots `tools/character/soft_look_shots.gd` |

## Switches (what is on / off)

- `data/bending/sb_fx/config.json`: master + one per element for the Spellbreak effects. **All four are `false`.** Do not turn one on
  without a side-by-side the owner picks from (`tools/fx/fx_lineup.gd el=<element>`). `moves_on` switches single roles on by
  themselves: the one on is earth's Fissure (`earth_shove/push` wave: Spellbreak's ground shockwave along the crack, the
  owner's pick of 2026-10-10, without the cast's flash). `fx_lineup.gd ... shipped=1` renders what ships.
- `BendLooks.SB_BOLT` (lightning look): `true`; `false` brings the old blue bolt back exactly.
- Settings → **Look** (`GameSettings` [look] character): `soft` (the default) or `classic` (characters and world exactly as before
  2026-10-10). Script runs default to Classic unless they pass `character_look=soft` or set `SoftLook.override`.
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

## Known gaps at handoff (be honest about these)

- **Live loadouts (Boxing + the 8 talents):** independently reviewed on 2026-10-10 (`docs/tidebreak/loadouts_live.md`, "Independent
  review"; `tests/ring/test_loadout_review.gd`). Classic is byte-for-byte the code before the loadouts, a talent changes only its wearer,
  and Boxing keeps Classic's cast timings. Fixed: a damaged save could stop the read with script errors and wear the wrong slot; Classic
  reads made a new dictionary each time. Open for the owner: Boxing's High Kick and Pop leave from the boxing fist (the High Kick
  0.9 m higher than the kicking foot).
- **Menus, first pass, open items from the critic (closed 2026-10-10, branch tb/GAPS-MENUS):** the round screen and the loading screen
  were already in the broadcast look in this commit (Barlow, plates). The fighter cards were the mock-up's size in the 1600 x 900 design
  but the layouts never scaled up (`BroadcastUI.Layout` capped its fit at 1), so at 1920 x 1080 every broadcast screen was drawn about
  30% smaller in area than the mock-up; they now scale up to `MAX_UP` (1.2 at 1080p). The match card lays its rows with a breath that
  opens to the room the window has (`_lay_match`), its rules at least a pixel, Begin clear of the Controls line and "Choose your
  element" clear of the rule line (`tests/ui/test_main_menu.gd` checks it at 1280 x 720 and 1920 x 1080). The lobby's freeze was the
  first figure's dress in one frame (the cloth's chest search over the body, 0.35 s; the skin's textures): the search runs a slice a
  frame (`GarmentChest.warm_step`), the textures load on the loader's threads, and the game's first menu builds all four figures behind
  the boot splash; `tools/ui_audit/lobby_perf.gd` measures it (the first menu: no frame over 18 ms; after a ring: 25 ms; a menu
  opened cold without the boot path, which only a tool does, still has one renderer pipeline compile of about 0.1 s). Second pass (loading, practice, settings,
  credits, round screen) is not started.
- **Advancement window:** a critic scored it 6/10 against the owner's reference clip (sparse lattice, flat node art, muddy backdrops,
  long tooltips, a gate bypass, a status-line overlap); a repair pass addressed those and was not re-scored. On 2026-10-10
  (branch tb/GAPS-ADV) two more passes followed: a diamond lattice, kind-coloured jewel plates, a calm backdrop shader, short tips
  and gate padlocks. An independent critic scored pass 1 at 7/10 ("revise"); pass 2 worked through those notes and has not been
  re-scored (its builder estimates about 8). Left: line-art pictures, not painted ones; mixed plate outlines. Judge it by eye.
  It saves loadouts; only Boxing and the 8 number-only talents change play (the rest are preview).
- **Local only (git-ignored), regenerate or ask the owner:** `artifacts/` (mockup renders, reference frames, audit screenshots, the
  skill-tree web mockup generator) and `Spellbreak_Reference_Extracts/`.
- **Menu mockups** `tools/ui_audit/menu_variants/` (A clean, B broadcast, C painted, D advancement-matched) are kept for reference;
  B was chosen and built, the others are superseded.
