# Round 4 task SHOW: Tidebreak's own music and a crowd in the round. A ring score in three layers that rises with the match (rendered by our own pipeline from VSCO 2 CE, horns at or below D4), its stingers on every fall and at the end, and fuller, lit, reacting crowds instead of flat cut-outs.

You build round 4's SHOW for Tidebreak (Godot 4.7, plus the Python music pipeline) in an isolated worktree. SCRATCH below means
/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad.
- Merge order: LAST in round 4. Rebase on IMPACT, READ, LOOKS and HUD before your final tests and perf numbers.
- Source:
  - the owner's FEEL list: "Tidebreak's own music";
  - the round-2 review's gap: "the crowd is flat cut-outs";
  - SCRATCH/critic_r2/backlog.md item 4 (SHOW).
- Look at these first:
  - SCRATCH/review/r2_core_kick_floor.png and r2_hud_firstmatch.png: the crowd as blocky flat figures;
  - SCRATCH/review/r2_merged_sheet.png;
  - tools/music/listen.html: the existing cues, by ear.

FACTS AT THIS HEAD:
- **The music:**
  - RingMode._music walks rules.json fight_cues ["ring_fight", "giant_battle"] and calls MusicDirector.play_story with the first that scripts/audio/music_manifest.gd has.
  - ring_fight does not exist, so the ring plays the open world's mammoth fight (giant_battle, 144 BPM).
  - RingMode._sting already plays the ring's own BendSounds (count_tick, round_gong, round_bell, match_gong).
- **The crowd:**
  - RingCrowd builds about 900 low-poly fans in 3 poses (one MultiMesh each). Its shader says "Flat, simple shading (cel friendly)".
  - RingDressing loops the murmur and plays reactions on set_cheer.
  - ring_level.gd's _follow wires the classic rules' knocked_back and rang_out to cheer().

FILES YOU OWN (no other round-4 task edits them):
- **The music:**
  - new tools/music/cues/ring_fight.py and ring_stings.py;
  - audio/music/ring_*.wav, with their .import files;
  - scripts/audio/music_manifest.gd (render.py writes it);
  - scripts/audio/music_director.gd;
  - tools/music/SOURCE.md and listen.html;
  - new scripts/ring/ring_music.gd (class_name RingMusic), data/ring/music.json.
- **The crowd:**
  - scripts/ring/ring_crowd.gd, shaders/ring/ring_crowd.gdshader;
  - scripts/ring/ring_dressing.gd: the crowd's build call, its sound and its reactions only;
  - scripts/ring/ring_level.gd: _follow and cheer only;
  - new data/ring/crowd.json, tools/ring/crowd_shots.gd.
- **Tests:** tests/audio/test_music_director.gd; new tests/ring/test_ring_music.gd and test_ring_crowd.gd.
- docs/bending_design.md: a short new "Round 4: feel and polish" section only, written last, from the five merged reports.

You do NOT edit:
- HUD's files: ring_mode.gd (its _music() already picks ring_fight once the manifest has it, and _music(false) stops it), RingSides;
- READ's files: bend_sounds.gd and tools/sfx. Use the crowd ids that exist: crowd_murmur, crowd_cheer, crowd_ooh, crowd_roar, crowd_groan;
- IMPACT's files: ring_water.gd, feel.json;
- LOOKS' files: ring_flame.gdshader (the braziers' look);
- the round-4 "nobody" list below.

BUILD

1. The score (tools/music). Read SOURCE.md, render.py, orch.py, choir.py, levels.py, cues/_lib.py and cues/giant_battle.py first. The samples are at ~/Downloads/VSCO-2-CE.
- **ring_fight:** three stems of IDENTICAL length and loop points:
  - base: big drums, frame and log drums from VSCO 1's percussion, a low strings ostinato, the sub;
  - drive: a brass ostinato (horns at or below D4, trombones, tuba) and spiccato strings;
  - peak: high strings, woodwind runs, the synthesized choir, timpani rolls and cymbals.
  - 120-132 BPM, 4/4, 32 bars, a clean loop.
  - Its own motif (4-6 notes), which every stinger quotes. A festival sport on the water: bright, not the giants' dread.
  - A = 432, as every cue.
- **ring_stings:**
  - ko_dealt 2 s, ko_taken 2 s;
  - last_life 1.5 s (a low swell);
  - sudden_death 3 s;
  - game_won 4 s, game_lost 4 s;
  - match_won 6 s, match_lost 5 s;
  - the countdown bed, 2.5 s under the count.
- Assert horns ≤ D4 in the cue code.
- Keep the new audio at 40 MB or less in the repo, and report the size. Trim the loop's length or the stems before lowering quality. Set their imports to stream (with QOA compression if the size needs it).
- render.py rewrites music_manifest.gd: check that its diff touches only the new rows.

2. MusicDirector's ring mode.
- `play_story("ring_fight")`, which RingMode._music already calls, starts the ring score:
  - the three stems in one AudioStreamSynchronized, or three players started on the same mix tick;
  - base audible, drive and peak silent.
- `play_story("")`, from RingMode._music(false), ends it. The mode stays STORY, so RingMode's stop works unchanged.
- `set_ring_level(0..2)`:
  - a change lands on the next bar line (the existing _cross_on_bar idea);
  - never more than one step down per 8 bars.
- `ring_sting(id)` ducks the loop 9 dB under a stinger and brings it back over one beat.
- The open world's modes are untouched (test_music_director stays green).

3. RingMusic.
- MusicDirector makes it when the ring score starts. It reads RingRules.current() and RingMode's signals, never a position.
- **Levels under stock rules:**
  - 0 at the start;
  - 1 when any competitor is at 60% or more, the clock reads 2:00 or less, or 2 falls have happened;
  - 2 when anyone is on his last life at 80% or more, in sudden death, or with the clock at 0:30 or less.
- **Levels under classic rules:** 1 with a side in zone 2 or deeper, or 60 s left; 2 with a side in its last zone, or 30 s left.
- **Stingers:**
  - ko_dealt or ko_taken on RingRules.ko, by side, with the credit as round 3 gives it (a self-fall is ko_taken for his side);
  - last_life when either side starts its last life;
  - sudden_death when it starts;
  - game and match won or lost on RingMode's ends;
  - never two within 1.5 s: if they collide, the bigger one wins.
- **Practice:** music.json practice_level. By default, the base stem at −6 dB and no stingers.
- giant_battle never plays in the ring. Pin it.

4. The crowd (RingCrowd).
- **Fuller figures**, built in code as today, one MultiMesh per pose:
  - a head with a jaw and hair or a hat, a torso with shoulders and chest, two-segment arms with hands, seated thighs and shins;
  - 6 poses: sitting idle, leaning forward, arms up, clapping, standing and waving a cloth flag in its side's colour, and sitting with a parasol or a hat;
  - each fan's height and build varied by ±8%;
  - skin, hair and clothes from the festival palette, as now, with the near side's colour worn more on its own half (the `sides` RingDressing passes);
  - a seeded build: the same crowd on every load.
- **Lit like the world, not cel:**
  - lambert with wrap;
  - a sky and deck ambient;
  - an occlusion term (laps, under the arms, the seat);
  - receiving the awnings' shadows;
  - the lanterns' light at night;
  - no outline.
- **LOD:** the far tiers use a lighter mesh of the same pose, through visibility ranges.
- **Motion** stays in the shader, as now (no per-frame CPU work per fan). Reactions come through set_cheer and a new `react(kind, side, strength)`, driven by RingMusic, RingRules and RingMode:
  - a launch of 12 m/s or more: an "ooh", heads up, a lean forward;
  - a fall: the near stands rise in a ripple outward from the side it happened on, with crowd_roar, then sit back over 3 s;
  - a last life or sudden death: half the crowd stands. In sudden death they clap on the music's beat (MusicDirector.position() and the cue's BPM).
  - The crowd's sounds (RingDressing's murmur and reactions) follow the same events.
  - ring_level.gd's knocked_back and rang_out wiring stays, for the classic rules.
- **Budget:**
  - crowd triangles at most 2.5× today's (report both);
  - 8 draws or fewer;
  - at noon, the gate tower's view at most 1.0 ms slower per frame than the base (report the Mac's numbers);
  - no new hitch: report test_ring_hitches' longest frames before and after;
  - the build stays inside RingLevel's "crowd" step.

5. The design doc. Last, once HUD has merged: add a short "Round 4: feel and polish" section to docs/bending_design.md, one paragraph per task, taken from the five reports.

TESTS
- Keep green: test_music_director, test_ring_match, test_practice, test_playcheck, test_ring_dress, test_ring_look, test_ring_assets, tests/perf/test_ring_hitches, tests/ui/test_main_menu.
- New tests/ring/test_ring_music.gd:
  - the manifest has ring_fight_base, ring_fight_drive and ring_fight_peak, of equal length and loop points, and every stinger;
  - a stock match plays the ring score and never giant_battle;
  - the levels go 0 → 1 → 2 at the conditions above (forced %, clock and lives), and change only on bar lines;
  - a KO dealt and a KO taken each play their stinger and duck the loop;
  - Practice uses its level;
  - the classic rules' levels;
  - RingMode's restart and exit stop the score.
- New tests/ring/test_ring_crowd.gd:
  - 6 pose MultiMeshes, 8 draws or fewer, the triangle count within budget;
  - reactions set the shader's params on a launch, on a fall (the ripple starts on the fall's side) and in sudden death (the clap's phase locked to the beat);
  - the crowd never reads a competitor's position, except which side a fall happened on;
  - the build is seeded.

REVIEW OUTPUT (prefix r4_show_)
- listen.html:
  - each stem alone;
  - the loop at levels 0, 1 and 2;
  - a 90 s "game" render climbing 0 → 1 → 2, with a ko_dealt, a last_life and the match_won;
  - every stinger.
- crowd_before.png / after: from the player's camera and from the gate tower, at noon and at night.
- crowd_poses.png: the 6 poses close up.
- crowd_react_strip.png: 8 frames of the ripple after a fall.
- sheet.png.
- METRIC lines:
  - ring_cue_ok, no_giant_battle_ok, stems_equal_ok, levels_ok, stingers_ok;
  - horns_max_note, music_mb;
  - crowd_tris before and after, crowd_draws, crowd_frame_ms before and after;
  - longest_frame_ms before and after;
  - crowd_react_ok.

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
