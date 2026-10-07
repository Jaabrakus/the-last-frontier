# Round 4 task READ: incoming attacks you can read without a cue. Every shot sounds in flight (its own voice, louder as it nears, with doppler), and the ring camera stops your own body hiding a shot coming straight at you: variants, a lineup, a measured default and an Esc row.

You build round 4's READ for Tidebreak (Godot 4.7) in an isolated worktree. SCRATCH below means
/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad.
- Merge order: after IMPACT, before LOOKS, HUD and SHOW. Rebase on IMPACT before your final test run.
- Source: SCRATCH/critic_r2/backlog.md items 2 (READ) and 8 (the ring camera). The owner's FEEL list asks for "readable incoming attacks WITHOUT any target cue". LOOKS does the shots' shadows, their size at range and the puffs; you do sound and camera.
- Look at these first: SCRATCH/review/r2_hud_keys_fire.png and r2_hud_firstmatch.png. The opponent stands straight above the player's head, so his shots end behind the player's own back. Look at round 3's r3_move_offdeck_camera.png too, if it is there.

WHY (measured at this head):
- Bolts make no sound in flight. BendSounds has cast and hit sounds only, and `_setup_3d` sets doppler_tracking DISABLED (scripts/bending/bend_sounds.gd ~391).
- Round 2's guard is a timing skill ("on the beat it's yours"), and the genre times its parries from a shot's sound.
- The camera (round 3's §4.8, MOVE) is centred: on the deck, arm 5.25 m and pivot 2.6 m (eye_height 2.3 + 0.3).
  - A plain-Python model (SCRATCH/r4plan/cam_occl.py) says a chest-high shot coming straight in is hidden behind your own head and back for its last 1.2-1.9 m, from 8 to 22 m away.
  - At 20 m/s that is 60-95 ms, just when the guard's timing is decided.

FILES YOU OWN (no other round-4 task edits them):
- new scripts/ring/ring_camera.gd (class_name RingCamera), data/ring/camera.json, tools/ring/camera_lineup.gd
- scripts/player/player.gd: the camera lines only (cam_distance_now ~1759, the eye target ~1316, the spring's x ~1330, the FOV target ~1332, and where MOVE adds cam_bias)
- scripts/ring/ring_moves.gd (cam_bias() only); data/ring/movement.json (its "cam" block only)
- scripts/ring/ring_menu.gd: a Camera row, and the Screen jolt row for IMPACT's GameSettings key
- scripts/bending/bend_bolt.gd and bend_throw.gd (only the flight voice's start and release); scripts/bending/bend_sounds.gd
- tools/sfx/bend/*: a new flight.py, bend_sfx.py's SOUNDS, review.py; the new audio/sfx/bend/<flight ids>_NN.wav files with their .import files; audio/sfx/bend/levels.json
- new tests/ring/test_ring_read.gd, tests/ring/test_ring_camera.gd; tests/bending/test_bend_sounds.gd
- the camera checks in tests/ring/test_ring_moves.gd and test_ring_edge.gd, if your default moves them; tests/player/test_player_gate.gd

You do NOT edit:
- IMPACT's files: camera_shake.gd, bend_knock.gd, bend_status.gd, ring_water.gd;
- LOOKS' files: bend_looks.gd (shadows, size at range), bend_zone.gd, toon_fx*.gd, shaders;
- HUD's files: hud.gd, bend_strip.gd, percent_bar.gd, ring_mode.gd;
- SHOW's files: ring_level.gd, ring_dressing.gd, ring_crowd.gd, the music;
- the round-4 "nobody" list below.

BUILD

1. Sound in flight.
- Six new looping ids, synthesized by our own generator in tools/sfx/bend:
  - a new flight.py next to elements.py, registered in bend_sfx.py's SOUNDS;
  - each 3 variants, seamless 1.5-3 s loops with a RIFF smpl loop chunk, as the crowd murmur has;
  - each levelled like its family (bend_sfx.py's own levelling);
  - run `--import` twice, as bend_sfx.py's usage says.
- The six:
  - stone_whirr: a low tumbling whirr with a rough rotation rate;
  - ice_whistle: a thin glassy whistle with a shimmer;
  - water_rush: a rushing hiss with a slosh;
  - fire_flight: a roaring hiss with crackle;
  - air_flight: a whoosh with a pressure flutter;
  - floor_run: the Kick's floor wave crackling along the deck.
- Lightning stays instant (round 2's charge hum and crack).
- BendSounds:
  - `flight(kind, parent: Node3D) -> AudioStreamPlayer3D` and `flight_end(p)`;
  - a pool of 8 3D voices, at most 6 playing, the nearest to the listener kept;
  - doppler_tracking PHYSICS_STEP on these voices only; every other sound stays as it is;
  - a level curve (unit size and max distance in each TABLE row) so a shot inside 6 m is clearly louder;
  - a 0.04 s fade in, and a 0.08 s fade out on the hit or the end.
- Where the voices start and stop:
  - BendBolt.launch and BendThrow's flight each start one;
  - the hit and the end of flight release it;
  - the floor wave uses floor_run;
  - earth's caught stone stops its whirr while it is held and starts it again on the return. The catch's timing is untouched.
- The player's own shots play at −6 dB, so the incoming read leads.
- Bots get nothing new (no AI change).
- The listener is the player's camera (check it).
- Arenas only (the ring and the duel). The open world's bolts stay silent in flight as today (the gate).

2. The ring camera.
- RingCamera: the variants live in camera.json and apply on top of MOVE's framing. cam_bias's off-deck, hanging and respawn offsets keep working:
  - **A:** as now.
  - **B:** right shoulder 0.5 m. The model says it is no better for a shot from 20° right. The owner also said "I don't want it off centre", of the open world's guns: ask.
  - **C:** centred and higher: pivot +0.8 (3.4 m), arm 6.0 m. The model says at most 1.0 m hidden from 8 to 22 m.
  - **D:** C with a 0.25 m right shoulder.
- Measure it in the engine, not the model. METRIC hidden_m, for each variant:
  - a chest-high test bolt from 8, 15 and 22 m, straight on and at ±20°;
  - the player in his idle guard pose and in a cast pose;
  - on each physics frame, cast a ray from the camera to the bolt's centre against the player's own visual body (capsules fitted to the skeleton's bones, or a SubViewport mask), and sum the bolt's path while it is hidden;
  - report the worst and the mean.
- **The default:** C, if its worst hidden_m is at most 1.0 and about 3 m of deck still shows behind your feet at the default pitch (spec §4.8). Otherwise the best centred variant. B and D go in the lineup and the Esc row, for the owner.
- Esc rows (ring_menu.gd), applied at once:
  - "Camera: Close / High / Shoulder": words in camera.json, kept in GameSettings ring.camera;
  - "Screen jolt: On / Off": IMPACT's GameSettings section "ring", key "jolt", default on.
- Never:
  - turned by a hit;
  - following or turning toward the opponent (no lock-on);
  - touching aim help.
  The crosshair stays the camera's centre (get_aim_point). The open world's camera is today's (the gate).
- For HUD, which builds in parallel: under C the player's body sits lower in the frame. At 1280×720, aiming at a chest 15 m away, cam_screen.py puts the feet at y≈705 and the head at y≈475 under A, and the feet at y≈740 and the head at y≈550 under C. Report the engine's numbers for your default.

3. The lineup (tools/ring/camera_lineup.gd, at noon):
- A-D on three frozen moments:
  - an incoming Spike from 15 m, straight on;
  - a Fireball from 8 m at 20°;
  - the player at the lip, being thrown off.
- For each variant, a "last 3 m" strip: 6 frames of the incoming Spike.

TESTS
- Keep green: test_bend_sounds, test_bend_throw, test_flow, test_r2_cast, test_r3_air, test_quick_spell, test_playcheck, test_ring_moves, test_ring_edge, test_player_gate, tests/perf/test_ring_hitches (report its longest frames: the voices must not add a hitch).
- New tests/ring/test_ring_read.gd:
  - every bolt kind but lightning plays a flight voice with doppler on, released within 0.1 s of its hit;
  - with 20 bolts in flight, never more than 6 voices, the nearest kept;
  - a caught stone's whirr stops while it is held and restarts on the return;
  - the player's own shots are at −6 dB;
  - for every id, the level at 2 m is at least 6 dB over the level at 12 m;
  - an open-world bolt plays no flight voice (the gate).
- New tests/ring/test_ring_camera.gd:
  - variant A leaves every round-3 number unchanged, and B, C and D apply theirs;
  - the default is the chosen variant;
  - hidden_m is computed in the engine;
  - a launch never turns the camera;
  - nothing is parented to or aimed at the opponent;
  - under each variant, a bolt cast at a bot 15 m away hits as it does under A (test_quick_spell's check);
  - the open world's camera is today's;
  - the Esc rows write and read GameSettings.

REVIEW OUTPUT (prefix r4_read_)
- camera_sheet.png: A-D × the three moments, labelled.
- camera_last3m_A.png to camera_last3m_D.png.
- listen.html:
  - each flight id alone;
  - a 4 s offline pass-by of each, with the doppler and the level curve;
  - each next to the cast and hit sounds of its element.
- sheet.png.
- METRIC lines:
  - flight_voices_max, voice_rise_db per id, doppler_ok;
  - hidden_m per variant (worst and mean), camera_default, deck_behind_m;
  - aim_unchanged_ok, open_world_cam_unchanged_ok, open_world_silent_ok.

Owner question for your report, with the sheet: "The default camera is now C: higher and centred, so a shot coming at you stays in view until about a metre out. B (over the right shoulder) is in the Esc menu. You said 'not off centre' about the open world's guns. Does that hold in the ring too?"

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
