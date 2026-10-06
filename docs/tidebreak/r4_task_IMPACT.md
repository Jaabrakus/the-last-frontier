# Round 4 task IMPACT: hits with weight. Hit-stop, the camera kick (an offset jolt, never a turn), the perfect guard's beat, the ring-out moment (the KO splash on every fall, a slow beat on the final fall), and a game clock under the bend timers.

You build round 4's IMPACT for Tidebreak (Godot 4.7) in an isolated worktree. SCRATCH below means
/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad.
- Merge order: FIRST in round 4. Your clock moves every BendStatus timer, so the other four rebase on you.
- Source: SCRATCH/critic_r2/backlog.md item 1 (IMPACT), rewritten here for the % ring. The owner chose these FEEL items: hit-stop, camera kick, and a ring-out moment (the splash).
- Look at these first: SCRATCH/review/r2_merged_punch.png, r2_merged_fireball.png and r2_core_perfect_flash.png (a hit and a perfect guard with no stop and no jolt). If round 3 left SCRATCH/review/r3_percent_fall_sequence.png and r3_percent_spout.png, look at those too.

WHY (measured at this head):
- Nothing in scripts/bending or scripts/ring calls CameraShake. Its only callers are the mammoth (quake) and the guns (kick). So:
  - a hit has no stop and no jolt;
  - a perfect guard gets a flash and a crack but no beat;
  - a KO is the same splash as anyone stepping in (RingWater.splash).
- BendStatus.now() is `Engine.get_physics_frames() / physics_ticks_per_second` (scripts/bending/bend_status.gd, ~line 45).
  - Under Engine.time_scale, Godot scales each physics step but still ticks at the real-time rate. Every BendStatus timer therefore drifts from game time.
  - The round-2 critic's earth-mirror soak caught 0 stones at ts 4, against 87 at ts 1.
  - The timers also run on through an Esc pause.
  - Any slow beat needs this fixed first.

FILES YOU OWN (no other round-4 task edits them):
- new scripts/bending/bend_impact.gd (class_name BendImpact), scripts/ring/ring_moment.gd (class_name RingMoment), data/ring/feel.json
- scripts/bending/bend_status.gd (now() and its clock only); scripts/bending/bend_knock.gd (the hold: a pending launch)
- scripts/ring/ring_predict.gd (the hold added to flight time only)
- scripts/player/camera_shake.gd
- scripts/player/player_anim.gd and scripts/npc/npc_body.gd: the pose's advance only (see BUILD 2)
- scripts/ring/ring_water.gd (the KO splash)
- scripts/ui/round_screen.gd, scripts/ui/match_screen.gd (only: they wait for the moment)
- new tools/ring/feel_shots.gd; new tests/bending/test_bend_clock.gd, tests/ring/test_ring_feel.gd
- tests/bending/test_knock.gd, tests/ring/test_ring_predict.gd (only where your change needs it)

You do NOT edit:
- READ's files: player.gd, ring_moves.gd, ring_menu.gd, movement.json, bend_bolt.gd, bend_throw.gd, bend_sounds.gd, tools/sfx;
- LOOKS' files: bend_looks.gd, bend_zone.gd, toon_fx*.gd, shaders/bend_fx;
- HUD's files: hud.gd, bend_strip.gd, percent_bar.gd, ring_mode.gd, ring_sides.gd, test_ring_screens.gd;
- SHOW's files: ring_level.gd, ring_dressing.gd, ring_crowd.gd, the music;
- the round-4 "nobody" list below.

Use only these existing APIs from other files:
- RingRules.stock_on(), RingRules.current() and its signals (ko, launched, respawned, pct_changed).
- BendCaster.of(body).guarded(result, what), told by BendZone.report.
- BendSounds.play/event with ids that already exist (knock_thud, ringout_splash).
- ToonFxPool.shoot/mark with their existing modes, and BendLooks.burst.
- The crowd is SHOW's: never call set_cheer.

BUILD

1. The game clock (BendStatus).
- now() returns game seconds: a static total advanced in the `_physics_process(dt)` of a tiny clock node.
  - The node is process_mode PAUSABLE, with the lowest process_physics_priority so it ticks before every reader.
  - It is made on first use under the tree's root.
  - dt is already scaled by Engine.time_scale, and a paused tree stops it.
- With no tree (pure unit tests), keep today's frame count.
- At time_scale 1 with --fixed-fps 60, the value must equal today's to 1e-6 every frame, so no round-3 timer moves. Pin it in a test.
- The header says why it changed, with the ts-4 soak numbers above.

2. Hit-stop (BendImpact).
- BendKnock calls `BendImpact.on_hit(n, v, by, info, hitstun_s)` where a launch is applied.
- The hold length:
  - hold_s = lerp(hold_min 0.04, hold_max 0.11, clamp((|v| − 4) / 14, 0, 1));
  - never more than hold_share 0.4 of the hit's hitstun (a 0.12 s stun holds at most 0.048 s);
  - nothing below stop_min_mps 4.
- **The victim (the player and bots alike):**
  - his pose holds for hold_s;
  - his launch velocity waits hold_s (BendKnock keeps it pending), INSIDE his hitstun, which still counts from the hit (spec §3);
  - so his first free frame, his steering (0.1 s after the launch), his break-the-fall window and the 0.6 s escape all stay where they were;
  - his flight is the same flight, started hold_s later, so the KO % does not move.
- **The hitter:** his pose holds hold_s only if he was within melee_m 3.0 of the victim at the hit (the jab string, the Pop, the Slam, kicks). A bolt landing 15 m away holds nothing on its caster. His movement, aim, camera and lock never wait, player or bot.
- **The player:** nothing but his pose, ever. As the one hit, he is in hitstun anyway. His camera's turn, his aim point, his lock fill and his buffered press must match a run without the hold, frame for frame. Pin it.
- The pose hold:
  - player_anim.gd: the tick's `advance(dt)` (~line 961) and its arm layers' advances use `dt * BendImpact.pose_rate(player)`;
  - npc_body.gd: `dt *= BendImpact.pose_rate(body)` before `ap.advance(dt)` (~line 592), so the skeleton's advance follows;
  - pose_rate is 0 while held and 1 otherwise. Change nothing else in either file.
- RingPredict.flight adds the hold to its time, so the bots' and Practice's reads stay true.
- Sound: knock_thud, with pitch and gain from |v|, at the hold's start. Nothing new is drawn on anyone.

3. The camera kick (CameraShake).
- Add `jolt(amount, secs)` on the existing offset path (add(): h_offset and v_offset). The camera does not turn, so the aim does not move.
- For a hit, never call `kick()` or `sustain()`: they turn the camera, and so the aim. The spec's rule is that the camera's turn, the aim and the lock are never touched by a hit; the owner's "camera kick" is this offset jolt. Pin that the camera's global basis and get_aim_point() are bit-identical through a jolt.
- The player's camera jolts (numbers in feel.json):
  - when he takes a launch with |v| ≥ 6: amount 0.12-0.35 from |v|, over 0.18-0.3 s;
  - when he lands one with |v| ≥ 9: half that;
  - on a KO into the water within 30 m: 0.3;
  - on his perfect guard: 0.12.
- A jolt starts on the hold's last frame, so it lands with the release.
- Switches:
  - GameSettings section "ring", key "jolt" (default true), read only. READ adds its Esc row.
  - feel.json `enabled`.
- The quake's `_noise.seed = randi()` uses the global RNG: seed it from the camera's instance id instead.

4. The perfect guard's beat.
- On a competitor's `BendCaster.guarded("perfect", what)`:
  - the guarder's pose holds perfect_hold_s 0.07;
  - so does the sender's pose, if he is within 6 m;
  - the guarder's view jolts 0.12 if he is the player.
- Round 2's flash and crack stay as they are.
- Late and whiff get nothing new.
- The earth catch is the fun core: a perfect Catch's held stone, its E-return and the stone's flight happen on the same frames as without the beat. Pin it.

5. The ring-out moment (RingMoment).
- BendImpact makes it on first use when RingRules.stock_on(). It listens to RingRules.current().ko.
- **Every fall:**
  - RingWater gets `ko_splash(at, speed)`:
    - a water column 5-8 m tall, from the body's entry speed;
    - a ring of spray sheets;
    - a ripple ring on the tank;
    - foam that stays 3 s.
    - Use our own particles and shaders: RingWater's look, plus ToonFx kinds through ToonFxPool.shoot only.
  - The sound: ringout_splash at +3 dB, with a low layer (knock_thud at pitch 0.6).
  - The player's camera jolts (3).
  - Play goes on: no slow beat on a fall that isn't the last.
- **The final fall** (a game's last life, or sudden death):
  - Engine.time_scale eases to 0.35 over 0.08 s and holds there for 0.6 s of real time, then returns to 1 over 0.25 s;
  - the splash plays at twice its size;
  - round 3's "Over", the MatchScreen and the RoundScreen between games wait until the moment ends (round_screen.gd and match_screen.gd gate on `RingMoment.busy()` wherever RingMode's own timers don't already wait).
- Engine.time_scale is ALWAYS restored:
  - when the moment ends;
  - on the scene's exit;
  - on RingMode's restart;
  - through an Esc pause;
  - on a second KO during the moment.
  Test each.
- Practice: no moment and no jolt (feel.json practice_moment false, practice_jolt false). The hit-stop stays: the feel of a hit is the lesson.
- Classic rules: the same splash on a rang_out, nothing else new.

6. data/ring/feel.json holds every number above, `enabled`, and an `_about` for each block.

Nothing else changes: lock times, launches, hitstun lengths, the catch, the guards' windows and the bots' minds.

TESTS
- Keep green:
  - tests/bending/*: test_knock, test_r2_cast, test_r2_guards, test_r3_air, test_r3_combo, test_r3_guard;
  - tests/ring: test_ring_pct, test_ring_hitstun, test_ring_stage, test_ring_match, test_ring_rules, test_ring_screens, test_ring_moves, test_ring_edge, test_ring_predict, test_practice, test_balance;
  - tests/npc: test_bend_bots, test_bot_recovery, test_bot_pct;
  - tests/perf/test_ring_hitches;
  - tests/climb/test_mammoth_knee and test_mammoth_temper (CameraShake's other users).
- New tests/bending/test_bend_clock.gd:
  - at ts 1, now() advances 1.0 per 60 physics frames at 60 ticks, and equals the frame clock to 1e-6;
  - at ts 4, a 1.0 s BendStatus timer ends after 1.0 s of game time (15 frames at --fixed-fps 60);
  - while paused, now() does not advance;
  - with no tree, the frame fallback.
- New tests/ring/test_ring_feel.gd:
  - **A bot hit at 12 m/s:**
    - its pose holds about hold_s;
    - its velocity starts hold_s later;
    - its stun ends on the same physics frame as with feel off.
  - **The player hit at 12 m/s:**
    - his pose holds;
    - his camera basis, aim point, lock fill and a buffered jump are identical to feel off, frame by frame.
  - **The hitter** holds only within melee_m.
  - **PERCENT's in-engine KO check** gives the same answers with feel on and off:
    - a water-weight body launched by the Boulder: in the water at 125%, not at 100%;
    - Spike 170/145, Punch 245/215 and Gust ▲ 135/115.
  - **A jolt** moves h_offset and v_offset, never the camera's basis.
  - **A perfect guard:**
    - holds both poses 0.07 s; a late one doesn't;
    - leaves a perfect Catch's stone and return frames unchanged.
  - **The final fall:**
    - sets time_scale 0.35;
    - time_scale is back to 1.0 within 1.0 s real;
    - it is restored after RingMode.restart mid-moment, on the scene's exit and through an Esc pause.
  - **Practice:** no moment and no jolt.
  - **feel.json `enabled` false:** no hold, no jolt and no moment.
  - **The gate:** open-world knocks (the mammoth's stomp, a Gust in the open) hold nothing and jolt as today.
- The soak: run test_ring_soak (rules=stock, an earth mirror, seed 7300) at ts=1 and at ts=4, and print METRIC catches for both. With the clock fixed they should be of the same order.

REVIEW OUTPUT (prefix r4_impact_; tools/ring/feel_shots.gd, windowed, in one batch)
- knock_strip_before.png and knock_strip_after.png:
  - 8 frames, one every 20 ms, of an earth Spike landing on the bot at 10 m;
  - one row from the player's camera, one row from the gate tower.
- jab_pop_strip_before.png / after: the jab string into the Pop at 2 m (the hitter's hold).
- perfect_strip_before.png / after: a perfect Catch.
- ko_splash_before.png (a fall at the base), ko_splash_noon.png and ko_splash_night.png.
- final_moment_strip.png: 8 frames over the 0.6 s.
- sheet.png, with each strip's feel.json numbers under it.
- METRIC lines:
  - hold_ms at 6, 12 and 18 m/s;
  - stun_end_unchanged_ok, player_cam_aim_lock_unchanged_ok, ko_calibration_unchanged_ok;
  - perfect_hold_ms, catch_unchanged_ok, jolt_basis_unchanged_ok;
  - timescale_restored_ok, clock_ts4_ok, clock_paused_ok, open_world_unchanged_ok;
  - soak catches at ts1 and ts4.

Owner questions for your report (each with the default you built):
- Hit-stop also holds YOUR launch for up to 0.1 s, though your stun still ends when it would. Keep it? Default: yes.
- The slow beat only on a game's last fall, or on every fall? Default: the last only.
- Ask the animation lane, in your report, for any hit-reaction clip your strips show is missing. Round 4 adds no clips.

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
