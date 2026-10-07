# Round 4 task LOOKS: the elements' looks, polished inside their stylized look. Flames that aren't blocky sprites, a bigger and thicker Kick wave, Breath's smoke as a lit volume, nothing of your own filling your view (the Wind Guard, your walls), and every shot with its own shadow and readable size at range.

You build round 4's LOOKS for Tidebreak (Godot 4.7) in an isolated worktree. SCRATCH below means
/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad.
- Merge order: after IMPACT and READ, before HUD and SHOW. Rebase on both before your final test run.
- Source: the round-2 review's known gaps, plus SCRATCH/critic_r2/backlog.md item 2 (READ: shadows, size at range, puffs, walls by the camera).
- Look at these first, in SCRATCH/review/:
  - r2_merged_sheet.png (all of them);
  - r2_core_kick_floor.png and r2_merged_kick_floor.png: the Kick's floor wave is nine thin quads in a line;
  - r2_merged_fireball.png and r2_merged_guard_fire.png: hard-cut flame sprites;
  - r2_merged_breath_smoke.png: a flat two-tone grey cloud;
  - r2_merged_guard_air.png: the Wind Guard's swirl fills the close view.

FACTS AT THIS HEAD:
- The flames: shaders/bend_fx/toon_flame.gdshader discards below an aastep, so every edge is a hard cut. BendLooks._fire_body draws 3 big tongue quads; floor_wave_body draws 9 "flame_low" quads and 14 embers.
- The smoke: toon_puff's lit mode, which dissolves from the edge ("never a soft fade").
- The Wind Guard: BendZone._look's band_mesh rings (~line 270).
- Bolt shadows: only the disc body casts one (bend_looks.gd ~148).
- Walls: FormRaised uses FormMatter's shaders/sway/form_matter.gdshader.

FILES YOU OWN (no other round-4 task edits them):
- scripts/bending/bend_looks.gd
- scripts/bending/bend_zone.gd: `_look()` and the look helpers only. The guards' logic, timing and results stay untouched.
- scripts/fx/toon_fx.gd, toon_fx_pool.gd, toon_ribbon.gd
- shaders/bend_fx/* (all), and shaders/ring/ring_flame.gdshader (the braziers' flame; its nodes are SHOW's ring_dressing.gd, so change only the shader)
- scripts/sway/form_raised.gd (the near-camera fade only), shaders/sway/form_matter.gdshader (the fade uniform)
- tools/bending/vfx_lineup.gd, vfx_stress.gd
- new tests/bending/test_r4_looks.gd

You do NOT edit:
- READ's files: bend_bolt.gd, bend_throw.gd, bend_sounds.gd, player.gd;
- IMPACT's files: bend_knock.gd, ring_water.gd, camera_shake.gd;
- HUD's files;
- SHOW's files: ring_dressing.gd, ring_crowd.gd;
- the round-4 "nobody" list below, which includes moves.json. Never change a hitbox, a speed or a zone's radius.

These looks are the same effects wherever they are cast: the open world's Form spells and the duel get them too. That is intended. Their sizes and hitboxes stay the same.

BUILD (in this order: 1-4 are the owner's gaps, 5-7 come from the read)

1. Flames that aren't blocky sprites.
- Keep the stylized banded palette (core, hot, mid, edge), but:
  - soft anti-aliased edges: alpha blended over fwidth instead of discard, sorted so they don't pop;
  - two octaves of noise with a domain warp, so the tongues lick and split;
  - tips that break into embers;
  - a soft additive glow underlay behind every flame cluster (a new "flame_glow" kind: a soft radial quad, no hard edge anywhere);
  - more, smaller tongues, each with its own phase: the fireball's 3 become 7-9, and the fire wall's MultiMesh doubles in count at 0.6 size;
  - a proximity fade where flames meet the deck, so there is no hard line where they cross it.
- The braziers (ring_flame.gdshader) get the same treatment, so the ring's own fire matches the moves' fire.

2. The Kick's floor wave: bigger and thicker.
- Three rows: a bright crest at the front, a body, and a low trail. 21-27 tongues in all, 1.0-1.4 m deep, as wide as now.
- Its visible top matches its hitbox's height (read the height from the bolt's spec; never change the hitbox). A player jumping it must see what he clears. METRIC top_vs_hitbox_m within 0.1.
- Under the crest, a bright lip along the deck (a ToonRibbon).
- Sparks thrown ahead.
- Scorch marks left along its path, fading over 2 s (ToonFxPool.mark "scorch").
- The travelling light, kept.
- Past the lip (AIR's 0.3 m), embers spill and fall.

3. Breath's smoke: a lit volume, not a flat two-tone cloud.
- On the smoke kind only:
  - 4 lit bands with soft transitions;
  - a soft erosion instead of the hard dissolve cut;
  - a slow curl (rotation and rise) and growth over its life;
  - grey-brown tints varied per puff;
  - a warm under-glow from the flame for its first 0.5 s;
  - soft where it meets the deck and the camera.
- The screen it makes is unchanged: BendZone's smoke zone keeps the same radius, life and block on the bots' sight. Pin it.

4. Nothing of your own fills your view.
- A near-camera fade in fx_common.gdshaderinc:
  - a screen-door dither, so there is no sorting;
  - an effect's pixels fade from 4 m to near_alpha 0.25 at near_m 2.5 from the camera;
  - every bend_fx shader uses it: wind bands, smoke, water, flames and puffs.
- The Wind Guard, seen from its own guarder's camera:
  - its bands are drawn thinner (band width × 0.6) and keep their silhouette edge;
  - everyone else sees it as now, because it is their read of his guard;
  - METRIC own_guard_coverage, the share of screen pixels it covers from the player's default camera: about 0.9 before, 0.35 or less after.
- Your own walls and pillars (FormRaised and form_matter.gdshader):
  - those between the camera and your head, or within 2.5 m of the camera, dither to 35%;
  - they still block shots, movement and the bots' sight (test it);
  - pieces in front of you, between you and the opponent, are cover and stay solid;
  - the ice wall and the fire and wind walls (BendZone's looks) fade the same way through fx_common.

5. Every shot casts its own shadow.
- Shadow-only proxy spheres, sized to each bolt's core: the rock, the ice crystal, the water head and the fire orb.
- Under an air bolt within 1.5 m of the deck, a thin line of dust rises (ToonFxPool.shoot "puff_dust").
- Check noon, golden and night. If night's lamps cast no shadows, report what it would cost to make them.
- No decal, no marker.

6. Size at range.
- A bolt's drawn core scales in the vertex shader with its distance from the camera past 14 m, up to ×2.2, so it never covers less than about 6 px at 1280×720.
- The hitbox, the speed and the damage do not change. METRIC core_px_25m.

7. Puffs that don't hide the struck body.
- A hit's burst on a body stays within 0.6 of the body's height, in count and in size.
- Puffs between the camera and the struck body are drawn at half opacity.

PERFORMANCE
- tools/bending/vfx_stress.gd, before and after: frame ms, draw calls and GPU particles at the stress scene's worst moment. Target: no worse than the base by more than 10%.
- No node made per hit once warm (the pool).
- warm_up() covers every new material, so there is no first-hit hitch (test_ring_hitches).

TESTS
- Keep green: tests/bending/* (test_r2_guards and test_r3_guard above all), tests/ring/test_guard_matrix, test_ring_look, test_ring_assets, test_playcheck, tests/perf/test_ring_hitches.
- New tests/bending/test_r4_looks.gd:
  - **Flames:** the flame kinds blend soft alpha (no discard path), with a glow underlay for each flame cluster.
  - **The floor wave:**
    - builds 21 or more tongues in 3 rows, 1.0 m deep or more;
    - its top is within 0.1 m of its hitbox's height.
  - **Breath's smoke:** its zone's radius, life and sight block equal the base's.
  - **The near fade:** alpha 0.3 or less at 1.0 m from the camera, and 1.0 at 6 m.
  - **Your own Wind Guard:** its band width is × 0.6 from its own camera only.
  - **Your own walls:**
    - one between the camera and your head dithers, and still stops a stone bolt and the bot's sight ray;
    - one in front of you stays solid.
  - **Shadows:** every bolt kind but air and lightning has a shadow caster, and air has its dust line.
  - **Size at range:** the core's drawn scale at 25 m is at least 2× its scale at 8 m, with the collision shape unchanged.
  - **Puffs:** a burst stays within 0.6 of the body's height.
  - **No cues:** nothing new is parented to anyone but the caster's own effects.

REVIEW OUTPUT (prefix r4_looks_; before and after at the same frozen frames, noon and night)
- fire_sheet_before.png / after: the fireball, the Punch, the fire wall, a brazier and Embers, close up (3 m) and far (15 m).
- kick_wave_strip_before.png / after: 6 frames side-on, and 6 from the player's camera as he jumps it.
- breath_smoke_before.png / after: 3 frames over its life.
- guard_air_own_before.png / after: r2_merged_guard_air's frame.
- wall_fade_before.png / after.
- shadows_noon.png, shadows_golden.png, shadows_night.png.
- range_sheet.png: every bolt at 8, 14, 20 and 25 m.
- puffs_before.png / after.
- sheet.png.
- METRIC lines:
  - flame_soft_ok;
  - floor_wave_tongues, floor_wave_depth_m, top_vs_hitbox_m;
  - smoke_screen_unchanged_ok;
  - own_guard_coverage before and after;
  - wall_fade_blocks_ok, shadow_kinds_ok, core_px_25m, puff_height_ratio;
  - stress_frame_ms and stress_draws, before and after.

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
