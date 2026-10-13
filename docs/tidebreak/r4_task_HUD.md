# Round 4 task HUD: a cleaner HUD and side colours. Every chip gets its own icon (our own set), the strip and its help line move off the player's body, one type system, centre words that don't collide, the plates' side colour, and in a mirror match a different trim per side, like jerseys.

You build round 4's HUD for Tidebreak (Godot 4.7) in an isolated worktree. SCRATCH below means
/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad.
- Merge order: after IMPACT, READ and LOOKS, before SHOW. Rebase on them before your final test run.
- Source:
  - the owner's FEEL list: "a cleaner HUD" and "side colours in mirror matches";
  - SCRATCH/critic_r2/backlog.md items 5 and 6;
  - the round-2 review's gaps: five of the seven chips share one placeholder icon, and the help text under the strip is cramped and overlaps the player.
- Look at these first:
  - SCRATCH/review/r2_hud_firstmatch.png, r2_hud_keys_fire.png, r2_hud_keys_air.png and r2_hud_sheet.png;
  - SCRATCH/crop_r2_hud_firstmoves.png;
  - round 3's r3_percent_plates_A.png, r3_percent_strip_air.png and r3_percent_match_screen.png, if they are there.

FACTS AT THIS HEAD:
- BendStrip draws FrontierHUD.spell_texture(id), which is assets/ui/icons/spell_<id>.svg or, when that is missing, FrontierHUD.draw_spell_circle (the placeholder).
- Only five exist: earth_wall, gust, mend, pillar and stone_form. They are the open world's Form spells: white line art on a 64 grid, tinted gold.
- hud.gd's _build_arena puts the strip at the bottom centre (6 px up) and the status words bottom-left.
- The help line (13 px) runs to two lines under the strip.
- "F1 controls" sits in the strip's corner.
- ring_team_a and ring_team_b wear identical element_dress (data/npc/factions.json), so an earth mirror is two ochre wraps.

FILES YOU OWN (no other round-4 task edits them):
- scripts/ui/bend_strip.gd, kit_words.gd, percent_bar.gd, match_bar.gd
- scripts/ui/hud.gd: the arena's layout and its labels only
- scripts/ui/first_hints.gd, lesson_card.gd, practice_panel.gd: placement only
- scripts/ring/ring_mode.gd: _build_ui and the centre words' size and place only. Its _music and _sting stay as they are: SHOW's score hangs off them unchanged.
- data/ring/hud.json, data/ring/screens.json (words)
- new tools/ui/move_icons.py; new assets/ui/icons/spell_*.svg for the ring's moves, with their .import files (the five open-world icons stay untouched); assets/ui/icons/SOURCE.md (new rows)
- new scripts/ring/ring_sides.gd (class_name RingSides), data/ring/sides.json; data/npc/factions.json (ring_team_b's away dress only); scripts/npc/npc_squad.gd (element_look's away pick only)
- tests/ring/test_ring_hud.gd, test_percent_hud.gd, test_ring_dress.gd, test_ring_screens.gd, test_player_words.gd
- new tests/ring/test_r4_hud.gd, tests/ring/test_ring_sides.gd

You do NOT edit:
- READ's files: player.gd, the camera, ring_menu.gd;
- IMPACT's files: round_screen.gd, match_screen.gd;
- LOOKS' files;
- SHOW's files: ring_dressing.gd, ring_crowd.gd, ring_level.gd;
- the round-4 "nobody" list below (hotbar.gd and moves.json are on it).

BUILD

1. An icon for every chip, from our own set.
- Enumerate every (id, mode) the strip can show for the four elements, under both rule sets, and report the count:
  - the jabs (Pebbles, Splash, Embers, Palm);
  - the guards (Catch, Turn, Parry, Wind Guard);
  - each key's first and second moves (moves.json's elements and modes);
  - fire's Fireball (1 held);
  - round 3's air chips: the Slams (Hammer, Downpour, Axe Kick, Down Gust) and "Dodge";
  - the caught stone's return.
- tools/ui/move_icons.py writes each one as assets/ui/icons/spell_<id>[__<mode>].svg. The strip asks for the mode's file first, then the id's.
  - The path data is designed by hand in the script, in the existing family's style: a 64 grid, white round-capped strokes of 3.4, 2.8 and 1.6, tinted at draw time.
  - One motif per element: earth's angular slabs and shards, water's curls and crests, fire's tongues, air's spirals and arcs.
  - Each picture says what the move does: a shard rising for Spike, a round rock with a trail for Boulder, a slab for Wall, a crest for Wave, and so on.
  - Never the show's nation symbols, or any symbol from the show.
- The strip tints a readied chip's icon in its element's colour, and dims it otherwise (as the head does today).
- The placeholder circle stays only as a fallback that no ring chip reaches (METRIC placeholder_icons 0).
- No two chips of one element share a picture.

2. The strip off the body, and cleaner.
- Where the body is, at 1280×720, aiming at a chest 15 m away:
  - under round 3's camera, about x 545-735 and y 475-705;
  - under READ's likely default (pivot 3.4 m, arm 6.0 m), y 550-720;
  - READ reports the engine's numbers. Today's strip overlaps the body under both.
- Build and render three layouts (hud.json `strip_layout`):
  - **L1:** the whole strip bottom-left (your side, under your plate);
  - **L2:** split: LMB, E, 1 and 2 left of the body; 3, 4 and 5 to its right;
  - **L3:** a compact centre: 32 px icons, names only, 18 px from the bottom.
- Pick the default by METRIC strip_body_overlap_px = 0 under both cameras, and by the owner's eye. L1 is the expected default.
- Compact chips:
  - the key in a small keycap over the icon, and the move's name under it;
  - the "tap twice: X" lines only in the player's first match (FirstHints up) and while he holds that key;
  - the readied chip lit as now.
- The one help line:
  - 64 characters or fewer, on one line ("Right-click: hold to aim, let go to cast"; KitWords);
  - above the strip, on the same side;
  - shown in the first match and in Practice, fading after 20 casts;
  - never over the body.
- "F1 controls": 12 px, in the bottom corner away from the strip, fading after the first 20 s.
- One type system:
  - three sizes: PercentBar's own digits, 16 px for heads and names, 13 px for hints;
  - one ink outline width;
  - gold only for the readied chip and the caught stone's line.
- The owner said "those big cards are terrible": no cards behind the strip. If the deck needs it, a soft screen-edge shade is the most you add.

3. The plates (round 3's PercentBar, Layout A).
- Keep the % look of spec §10.2-10.3.
- The 2 px side rule and the life glyphs take RingSides.colour(team).
- The element glyph comes from the new set's element marks (our own).
- The plates read nothing about anyone's position (no cue): pin it.

4. The centre words (RingMode._build_ui).
- The 54 px banner becomes 44 px, at 30% of the height, with the sub line under it.
- The top line clears the plates and the clock.
- The KO line and "Over" (round 3's words) share that style.
- At 1280×720, 1440×900 and 1920×1080, nothing overlaps the plates, the clock or the event line (METRIC label_overlap_px 0).

5. Side colours in a mirror match.
- data/ring/sides.json:
  - per element, a "home" dress (today's) and an "away" dress that keeps the element's family but changes its trims and value (for example, earth's umber and bone against ochre and moss);
  - a side colour per team for the plates: home is the element's, away is its away trim.
- RingSides:
  - `mirror() -> bool`: an element is worn on both sides;
  - `away(team) -> bool`: team 1 wears away when its element is also on team 0. The player's side is always home;
  - `colour(team) -> Color` and `dress(team, element) -> Dictionary`;
  - sides.json `always` (default false: mirror matches only).
- NpcSquad.element_look takes the away dress through RingSides when it applies. Keep the away dress in one place: sides.json, or ring_team_b in factions.json.
- The player's own dress never changes.
- Only cloth colours change. Nothing is drawn on anyone. Use only the existing catalog set ring (no new garment).
- A lineup: each element's mirror at 8, 15 and 25 m, noon and night, from the player's camera.
- METRIC sides_deltaE per element: the OKLab ΔE between the two sides' average garment colour at 25 m is 25 or more, with a value difference of 0.12 or more.

6. Words: every new word goes in screens.json, hud.json or sides.json. test_player_words scans them for show words and Smash names.

TESTS
- Keep green:
  - tests/ring: test_ring_hud (its no-cue check), test_percent_hud, test_ring_screens, test_ring_dress, test_player_words, test_lessons, test_practice;
  - tests/ui: test_how_to, test_hotbar, test_main_menu;
  - test_hud_skills and test_hud_vitals at their known lines.
- New tests/ring/test_r4_hud.gd:
  - every chip of each element, under both rule sets, resolves to a real svg (placeholder_icons 0), unique within the element;
  - the strip's rect never meets the body box, under both cameras and at the three resolutions;
  - no two HUD labels overlap;
  - text contrast is 4.5:1 or more on the noon deck and at night;
  - the help line is 64 characters or fewer, on one line, and hidden after 20 casts outside the first match and Practice;
  - nothing follows or is parented to a body;
  - the classic rules' MatchBar still builds.
- New tests/ring/test_ring_sides.gd:
  - in an earth, water, fire and air mirror, team 1 wears the away dress and team 0 home;
  - non-mirror matches are unchanged (pinned equal to round 3's dress);
  - the plates' rule colour is RingSides.colour;
  - the player's dress never changes;
  - 3v3 with mixed elements.

REVIEW OUTPUT (prefix r4_hud_)
- firstmatch_before.png / after: r2_hud_firstmatch's frame.
- keys_earth, keys_water, keys_fire and keys_air, each before/after.
- air_strip.png.
- layouts_L1.png, layouts_L2.png, layouts_L3.png, under both cameras.
- res_1280.png, res_1440.png, res_1920.png.
- icons_sheet.png: every icon on dark and on the noon deck, at 40 px and 80 px.
- sides_<element>_noon.png and sides_<element>_night.png, and sides_sheet.png.
- plates.png, centre_words.png, sheet.png.
- METRIC lines:
  - icon_count, placeholder_icons, icons_unique_ok;
  - strip_layout, strip_body_overlap_px under cameras A and C;
  - label_overlap_px, contrast_min, help_line_chars, hud_no_cue_ok;
  - sides_deltaE per element, sides_value_diff, sides_nonmirror_unchanged_ok;
  - words_ok.

Owner questions for your report:
- Side colours in mirror matches only (the default), or always?
- Which strip layout, with the L1-L3 images?

---

RULES FOR EVERY ROUND-4 TASK (each task text repeats them)

- **The game:** Tidebreak, Godot 4.7 GDScript.
  - Worktree: /Users/kiwimango/Downloads/Frontier/.claude/worktrees/spellcraft (branch worktree-spellcraft).
  - Round 4 is FEEL + POLISH, which the owner chose to come next.
  - The bar is "triple-A quality", judged by the owner's eye and ear.
- **Your base:** your own isolated worktree off the branch head AFTER round 3 has merged (SEAMS, PERCENT, MOVE, AIR, BOTS and CLIPS' parts).
  - Check first: `RingRules.stock_on()` is true in a default ring match, and scripts/ui/percent_bar.gd, scripts/ring/ring_spout.gd and tests/ring/test_ring_pct.gd exist. If not, stop and report.
  - Merge order: IMPACT → READ → LOOKS → HUD → SHOW.
  - Build in parallel. Before your final test run, rebase on the round-4 tasks merged before you.
  - Commit only your own files (git add by path).
- **Read first** (SCRATCH = /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad):
  - SCRATCH/smash_r3/spec.md (v2): §0 controls, §3 hitstun, §4.8 camera, §7 lives, KO and respawn, §10 HUD, §14.3 the APIs between files.
  - docs/bending_design.md, as round 3 left it.
  - SCRATCH/critic_r2/backlog.md (the items your task names), and SCRATCH/critic_r2/owner_answers_r3.md ("Still standing": the FEEL + POLISH list).
  - The review images your task names, in SCRATCH/review/. Look at them.
  - `git log --oneline -40` at your base: round 3's merge commits say what was built and what was left red.
- **Godot ONLY through the lock, and sparingly.** Four builders and the animation lane share one Godot, and the Mac overheats.
  - Run: `zsh SCRATCH/godot_run.sh <args>`.
  - Tests: `GODOT_TIMEOUT=420 FPS=60 zsh SCRATCH/run_test_fps.sh <worktree> <log name> <tests/x.gd> <args...>`.
  - Green = EXIT 0, a PASSED or OK line, and 0 SCRIPT ERROR.
  - Queue your test runs as one script, one after another. Render review images in one windowed batch near the end. Never start a second Godot while yours runs.
  - No round-4 task needs Blender.
- **Hygiene:**
  - Use simple Bash commands. The worktree guard refuses compound git commands, so write Python helpers under SCRATCH.
  - Run `--import` after adding class_name scripts or assets. tools/compile_check.gd must be clean.
  - Match the code's `##` doc-comment style: say why, with the owner's words where they apply. Every number goes in data.
- **New tests:**
  - a watchdog and seed(1750);
  - a last line `<NAME> PASSED` or `<NAME> FAILED`, and exit 0 only on a pass;
  - `MatchSetup._aim_help` pinned and `GameSettings.path` isolated;
  - visuals and sounds roll ToonFx.vis_rng or BendSounds' dice, never the global RNG.
- **Known red, not yours:**
  - test_hud_skills 1/33, test_hud_vitals 2/16, throw_edges, throw_flesh, anim run_all;
  - test_flow's catch-back, which flakes about 2 times in 25;
  - anything round 3's merge commits list as red.
  - If a test you must keep green is already red at your base, record its line at the base before you change anything.
- **THE GATE:** the open world, the duel and the classic ring rules look, sound and play exactly as today, unless your task says a change reaches them. A test pins it.
- **THE FILES:**
  - Each file belongs to ONE round-4 task, and your task lists yours. Never edit another task's file. If you need a change in one, write the exact function you need in your report.
  - Nobody edits these in round 4:
    - data: data/ring/rules.json, ring.json, practice.json, lessons.json; data/sway/moves.json; data/bending/poses.json; data/npc/bend_ai.json;
    - scripts: scripts/ring/ring_rules.gd, ring_arena.gd, ring_spout.gd, ring_practice.gd, ring_move_looks.gd; scripts/sway/sway_caster.gd, sway_pose.gd; scripts/npc/npc_bending.gd, npc_fighter.gd, npc_pad.gd; scripts/ui/hotbar.gd;
    - every clip file (tools/anim_author/**, animations_extra/**, animations/SOURCE.md), which belong to the animation lane.
  - No gameplay number changes: no lock time, % class, launch, hitstun, hitbox, guard window, movement or bot number. Round 4 changes how the game looks, sounds and feels, not what it does, except where your task says so.
- **OWNER RULES (never break):**
  - The sport is "Tidebreak".
  - NO show words anywhere a player can see or hear them (text, cue titles, captions): never Avatar, bender, bend, bending, pro-bending, Korra, nation names, the show's technique names, or its symbols. Never Smash's names either: stock, blast zone, DI, tech, edge-guard, meteor, smash, Final Smash.
  - NO target cues of any kind: nothing drawn on, around, attached to, following or pointing at an opponent. That means no rings, frames, chevrons, outlines, markers, map dots, highlights or tints.
    - What a shot shows by itself (its look, its shadow, its sound) is not a cue.
    - Your own state stays on your own plate, body or ears.
    - Each competitor's % and lives on a fixed plate are a scoreboard, which is allowed.
  - NO painted zone lines. NO cel shading of the world (the bend effects keep their stylized look). No guns or gun sounds.
  - Our own assets only: procedural, synthesized (tools/sfx), rendered by our own music pipeline from the VSCO 2 CE samples, or authored by us. No downloads, and nothing copied from the show or from Smash.
  - Our own clips only, and round 4 adds none: the animation lane owns clips. Ask in your report for any clip you need.
  - Getting hit never slows the player or hurts his aim: a hit never touches the camera's turn, the aim or the lock (spec §3).
  - Lock time is the only spam limiter for casts.
  - Earth catching a stone just before it hits and throwing it back is the fun core: never weaken it.
  - Music: horns at or below D4.
  - The owner judges by eye and ear: make before/after images, lineups and listen pages, and go bold.
- **Review output** goes to SCRATCH/review/ with the prefix `r4_<task>_`.
  - "before" is your base, rendered first at the same frozen moment as "after".
  - Show noon and night wherever the light matters, at 1280×720 unless your task says more.
  - Make a contact sheet `r4_<task>_sheet.png`.
  - No films unless asked: use frame strips. The owner plays the result himself.
- **Report:** the files changed, the test lines (at the base and yours), the METRIC lines, each review image with one line on what to look at, your owner questions, and any change you need in another task's file.
