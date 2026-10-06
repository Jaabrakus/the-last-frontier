# Round 3 task MOVE: every movement option in the % ring, the same for player and bots: ring physics, the jump and the hop-cast short hop, the double jump that takes back half a throw, fast fall and the held crouch on C, the ground Roll and Duck, the air dodge on 3, the teeter, the deck edge (grab, hang, deck-relative options, occupancy, the 3-grab rule), each element's Rise (off the deck only, the Pillar's lean, the Jet's floor, the scramble) with the helpless fall, breaking the fall's motion and the getups, the spout ride, the camera (deck framing, off-deck framing, the recovery turn), your own sounds and drop shadow, the predictor the bots and Practice use, NpcPad, and the body-state clips' playback. All gated, so the open world is untouched.

You build round 3's MOVE for Tidebreak (Godot 4.7) in an isolated worktree.
- Merge order: after PERCENT, before AIR and BOTS. Rebase on PERCENT before your final test run.
- Your part design: smash_r3/movement.md (MOVEMENT). spec.md v2 wins where they differ:
  - E is the guard everywhere and is NOT the air dodge; **3 in the air is the air dodge** (AIR routes it to you);
  - **Space is always a full jump**; the short hop is Space within 0.05 s of a cast release;
  - the Rise is Space only, **off the deck only**, a fresh press ≥ 0.2 s after the double jump;
  - **the double jump keeps half the launch's remaining carry**;
  - **the edge keys are deck-relative**: every direction key climbs, only C lets go;
  - one gravity, 20, with no element gravity multipliers; the tank margin is 10 m with a water curtain (PERCENT's);
    there is no stone slab (the respawn is PERCENT's spout; you provide the ride).
- Spec sections you own: §4, §5.3-5.4, the motion of §3.3-3.4, §14.3's RingMoves/RingPredict/NpcPad, and the MOVE tests
  in §15.

ROUND-2 FILES YOU WILL MEET:
- player.gd, as round 2 left it (jumping allowed mid-lock).
- SwayCaster's SRC_GUARD (AIR adds the held guard; you only read `guard_up()`), and its `cast_released` and
  `lock_started` signals (SEAMS added them).
- BendMotion's dashes and Leap's glide (off in the ring: Space in the air is yours).
- round 2's dash edge-safety test (test_r2_cast "dash_edge_safe").
- The existing knock clips own-bend-knock-air and own-bend-knock-slide, played by sway_pose.gd and npc_body.gd.

FILES YOU OWN (no one else edits them):
- new scripts/ring/ring_moves.gd (filled from SEAMS' stub), ring_predict.gd, ring_move_looks.gd
- new scripts/npc/npc_pad.gd
- scripts/player/player.gd
- scripts/npc/npc_fighter.gd, npc_body.gd
- scripts/sway/sway_pose.gd
- data/ring/movement.json
- new tests/ring/test_ring_moves.gd, test_ring_edge.gd, test_ring_predict.gd; new tests/player/test_player_gate.gd;
  tests/npc/test_npc_fighter.gd

You do NOT edit bend_knock.gd, bend_status.gd, ring_rules.gd, ring_arena.gd, ring_mode.gd, ring_water.gd or the HUD
(PERCENT); sway_caster.gd, bend_effects.gd, bend_motion.gd or moves.json (AIR); npc_bending.gd or bend_ai.json (BOTS).

BUILD

1. RingMoves (one mover for player and bots).
- Installed by RingMode on each competitor only under stock rules; `RingMoves.of(body)` is null elsewhere.
- `pre(intent, dt) -> owned` like PlayerTraversal.pre. The intent is `{move, jump, jump_short, jump_held, dodge,
  dodge_dir, fast_fall, down_held, guard_held, guard_pressed, ledge, di}`.
- The player fills it with `intent_from_keys()` (Space, W/A/S/D, the `crouch` action (C, or Ctrl), E). `jump_short` is
  true when Space and a `SwayCaster.cast_released` of his own caster fall within 0.05 s of each other (either order).
- Bots fill it through NpcPad, the same dictionary. A bot never writes velocity directly in the stock ring.
- Every number goes in movement.json.

2. Ring physics (spec §4.1).
- Gravity 20 (read `BendKnock.gravity_override`), max fall 11 (air 8).
- Run 5.0 and sprint 6.5; accel 40 and decel 30; PlayerAnim's clip speed caps off in the ring.
- Air drift per element: earth 3.5 at 12, water 4.0 at 16, fire 4.5 at 20, air 4.5 at 16.
- **The jump is always full:** apex 2.0 m (v0 8.94), whatever the tap length. **The short hop** (`jump_short`): vy capped
  to √(2g(0.8 − h)), apex 0.8 m.
- Round 2's self-launch up speeds (Step, Jets, Lift, Leap) ×1.43 in the ring: expose `profile().self_up_mult`; AIR reads
  it in BendMotion.
- player.gd reads the profile only when `ring_moves != null` (its movement block ~1201-1298); every branch is `if
  ring_moves != null`.
- NpcFighter._move: it returns early when RingMoves owns the body, uses the ring gravity instead of GRAVITY 18, and skips
  its −0.5 floor clamp during its own jumps. The duel's path is unchanged.
- PlayerTraversal and PlayerGrip are not installed when `arena` (player.gd ~447-450).

3. Jumps (spec §4.2).
- The double jump: 1.6 m (earth 1.4, air 1.9), vy SET; **it calls `BendKnock.scale_carry(0.5)`** (the knock's remaining
  carry halves); your own horizontal speed snaps to the held direction at drift, or 50% kept. Allowed mid-lock; refused in
  hitstun (the escape aside), helpless, an air dodge's travel or landing lag.
- In the air, Space is the double jump; once it is spent, **off the deck** (feet outside the deck rectangle or more than
  0.3 m under the lip) and **at least 0.2 s after the double jump with Space released and pressed again**, the Rise (once
  per airtime). Over the deck a third Space does nothing. Walking off the deck, the first Space is the double jump.
- Refreshes: landing, an edge grab, and `BendKnock.launched` **with refresh true** (a tumbling launch class). Nothing
  else.
- The flavour on yourself only (ring_move_looks.gd): an earth slab that crumbles in 0.3 s (no collider), a water splash
  ring, fire jets, an air gust ring.

4. Fast fall and crouch: the `crouch` action (C shown; Ctrl also bound).
- A press after the apex (vy ≤ 0.5): vy −17 (earth −18, air −14), kept until you land, jump or dodge; the key need not be
  held. Allowed while helpless, not in hitstun; it ends the glide.
- Holding it blocks the edge grab. The crouch is held in the ring: capsule 1.1, stationary, casting allowed.

5. Ground Roll and Duck (spec §4.5).
- With `SwayCaster.guard_up()` (or within 0.1 s of E), a FRESH W/A/S/D press is a Roll: 3.5 m in 0.45 s,
  camera-relative, facing kept, intangible 0.05-0.30, end lag 0.15. It stops 0.3 m inside the lip and collides with
  bodies.
- C is a Duck: 0.45 s, intangible 0.04-0.30.
- Repeat cost +0.1 s, up to +0.3, within 1.0 s.
- Intangible = a BendStatus.take_filter you register: no hurt, no knock, and bolts pass unspent. Nothing glows.

6. The air dodge (spec §4.6), `dodge(dir)` called by AIR's SwayCaster when 3 is pressed airborne.
- Directional: 3.2 m in 0.22 s, gravity off, vy 0 after, the launch carry running under it; intangible 0.04-0.30; then
  0.28 s with no actions (drift on, no grab); landing lag 0.3.
- Neutral: 30% of the velocity kept, gravity on, intangible 0.04-0.40, 0.15 s end, 0.15 lag.
- One per airtime; never helpless. The element's dash look on yourself.

7. The teeter: running into the lip stops; 0.3 s toward the water steps off; launches always carry over. All four sides.

8. The edge (spec §5.3): grab box, conditions, snap, intangibility, the 4 s hang, the options, occupancy.
- Use PERCENT's `RingArena.nearest_lip(pos)`. The occupancy registry (1.2 m each side, no trumping) lives in RingMoves.
- **Three grabs, then the deck:** after 3 grabs without touching the deck, the next grab fails (a slide down the face).
- **Deck-relative keys while hanging:** ANY of W/A/S/D climbs (0.5 s → 0.6 m in); E rolls in (0.75 s → 3.0 m in); Space
  jumps (vy 11.8, air moves kept); LMB is the edge attack (0.6 s, a low sweep 2.0 m in, through BendStatus with tag
  "edge/attack"); **only C lets go** (or the 4 s limit). No direction ever lets go.
- `ledge_safe_left()` for bots and AIR.

9. The Rise (spec §5.4).
- Pillar, Fountain, Jet and Updraft with their startups, lifts and drifts. **The Pillar leans 20° toward the nearest lip**
  (5.5 m along the lean). **The Jet: aim pitch below +20° is lifted to +20°.**
- **The scramble:** a Rise (during it or within 0.1 s after) that meets the deck face with the head no more than 2.0 m
  under the grab box slides up the face to the hang in 0.3 s (clip own-bend-edge-scramble; stand-in own-bend-edge-grab).
  It counts as a grab (the 3-grab rule).
- The helpless fall: drift ×0.6, fast fall and grab only, 0.35 s landing lag. **While helpless** a press of Space, 3, E
  or a cast key plays a short dull "spent" sound on yourself; when your last air move goes, a short exhale and a dull puff
  of your element.
- Their hits go through BendStatus with tags "rise/pillar", "rise/fountain", "rise/jet" and "rise/updraft".
- Looks in ring_move_looks.gd: the leaning earth column (it sinks 0.4 s after; never a platform, no lasting collider), the
  water column, the jet trail, the whirl. **Every startup shows above the lip and has its own loud sound** (the grind, the
  surge, the roar, the howl), heard by everyone: it is the move's own tell, not a cue.
- Lift, Jets and Leap cast from the deck set `rise_ready = false` for that airtime but don't leave you helpless.

10. Hitstun, steering, breaking the fall and getups: the motion and the inputs. PERCENT owns the state.
- In hitstun: no steering, jump, dodge, fast fall or grab; one buffered press (jump, dodge, Rise) fires on the first free
  frame. **The escape:** from 0.6 s, if `RingRules.can_escape(b)`, a FRESH press (made at 0.6 s or later) of Space or 3
  ends it; the buffered press never does.
- The steering read: `apply_di(held keys, camera-relative)` 0.1 s after each launch; bots pass NpcPad.di. Your body leans
  and twists toward the held side for 0.3 s (an additive bone tilt in sway_pose.gd and npc_body.gd, not a clip).
- E (bend_guard just pressed) while `BendKnock.tumble` calls `press_break(dir)`. On `broke_fall`: "stand" (intangible
  0.25), "roll" (2.5 m in 0.4 s, never off the lip), "wall" (stick 0.1 and spring off at vy +3).
- From lying: W or Space stands (intangible 0.3); E + a direction rolls 2.5 m; LMB is the getup attack ("getup/attack",
  5%).
- **Your own sounds and shadow** (ring_move_looks.gd, the local player only): a rushing whoosh for as long as you are in
  hitstun that cuts out on your first free frame; a short rising tick at 0.6 s when the escape opens; a soft dark drop
  shadow blob under your own body, on the deck and on the water. Use the project's own sounds or our own synthesis.
- Never touch the camera or the aim during hitstun. The old `reeling` zero-steer branch stays for the open world.

11. The spout ride: `ride_spout(pos, max_s)` holds the body there, standing, until a move, jump, cast key or max_s; then
    `left_spout` fires. `leave_spout()` for AIR (a cast key on the spout calls it, then starts the lock). `on_spout()` is
    true meanwhile.

12. The camera (spec §4.8): player.gd's cam_distance_now(), eye target (~1316) and FOV (~1332) add `ring_moves.cam_bias()`.
- On the deck (stock): arm 5.25 m, pivot +0.3 m, so ≥ 3 m of deck behind the feet shows at the default pitch.
- Off the deck: pivot = the midpoint between the chest and the nearest lip point; arm = clamp(4.1 + 0.6 × distance,
  5.25, 8.0); FOV 60, or 65 beyond 4 m; in over 0.35 s, back over 0.5 s.
- Hanging: arm 5.0, pivot lip +1.0.
- **The recovery turn** (`movement.json cam.recover_turn`, default true): off the deck, not in hitstun, the nearest lip
  more than 100° from the view's yaw, the mouse still for 0.25 s: the yaw eases toward the lip at up to 120°/s until the
  lip is within 60°. Any mouse motion cancels it at once and for the rest of that airtime. Pitch never moves.
- **After a respawn** (on `ride_spout`): yaw toward the deck's middle, pitch level.
- A launch never changes yaw or pitch.

13. `can_cast()` is false when hanging, helpless, in an air dodge, in landing lag, lying, or in hitstun. AIR's SwayCaster
    asks it. `land_lag(s)` lets AIR plant the feet for an aerial's landing lag.

14. RingPredict (pure static, a GDScript mirror of smash_r3/lead_model.py v2):
- `flight(v, hitstun_s, from, element)` with the ring physics, the carry decay 8, the escape, the double jump halving the
  carry, the air dodge, the Rise (the lean, the Jet floor), the scramble, the grab box, the deck face, the water and the
  curtain plane at any height.
- `would_ko(tag, target, from, dir, range_m, air)` and `ko_pct(...)`, a binary search 0-300 over `RingRules.launch_v`
  (which applies the range and air factors).
- `RingMoves.simulate(state, plan, dt, horizon)` for the bots' six recovery plans (spec §9.6), from the same code.

15. The body-state clips (spec §13), played by sway_pose.gd (the player) and npc_body.gd (the bots) from RingMoves and
    BendKnock state.
- The movement.json `clips` block maps each state to a clip with a stand-in. Until CLIPS merges, BendPoses passes over a
  missing clip and the stand-in plays.
- States: tumble, flinch, the double jump, fall, fast fall, helpless, air dodge, edge grab/hang/climb/roll/jump/attack,
  **the scramble**, the rolls, duck, the landing-lag lights and heavies, the four Rises, the break-fall and getups, the
  teeter, the spout ride, and **own-bend-air-legs**: the lower-body mask under any cast released airborne (listen to
  AIR's `SwayCaster.air_cast`). The held guard loops are AIR's (poses.json).

TESTS
- The MOVE tests of spec §15: test_ring_moves (with the masher: Space every 60 ms from 12 off-deck spots at 120%, each
  element, recovers at least as often as no input), test_ring_edge (deck-relative keys at camera 0°/90°/180°, the 3-grab
  rule, the scramble), test_ring_predict and tests/player/test_player_gate.
- Jumps: taps of 0.08 and 0.10 s and a 0.5 s hold all reach 2.0 ± 0.05 m; the hop-cast in both orders reaches 0.8; a third
  Space over the deck does nothing.
- Parity: the player and a bot given the same intent sequence trace the same path within 1 cm over 2 s.
- The camera checks of §15 (deck framing, the off-deck framing facing the deck, the recovery turn with the mouse still
  and its cancel with the mouse moving, the respawn yaw).
- test_npc_fighter extended for the gated _move.
- Keep green: test_duel_bender and test_duel (no edits; BOTS owns them), test_bend_bots, tests/sway, the round-2
  test_r2_cast dash-edge check, and the open-world player tests (tests/player).
- RingPredict vs lead_model.py v2: the KO speeds at 25/30/35° from 17, 7 and 2 m within ±5%, and the recovery reach per
  element (earth 11.3, water 11.8, fire 15.8, air 17.4 m) within ±1 m.

REVIEW OUTPUT (prefix r3_move_):
- edge_hang_front.png and edge_hang_side.png (hands and head over the lip; noon and night), edge_scramble.png
- edge_options.png (one frame of each option)
- rise_earth.png, rise_water.png, rise_fire.png, rise_air.png (4-frame strips from startup to helpless; the earth column
  leaning; each tell seen from the deck 3 m back from the lip)
- camera_deck.png (≥ 3 m of deck behind the feet), camera_offdeck.png (facing the deck at lip −5 m, 4 m out),
  camera_recover_turn.png (before and after the turn), camera_hang.png
- roll_duck.png, air_dodge.png, teeter.png, double_jump_looks.png, drop_shadow.png
- METRIC lines: hop_apex_m, short_hop_apex_m, double_jump_m per element, dj_carry_keep, air_dodge_m, rise_m per element,
  recover_reach_m per element (engine vs lead_model), masher_vs_idle per element, parity_cm, gate_unchanged_ok,
  edge_keys_deck_relative_ok, grab_limit_ok, edge_occupancy_ok, camera_ok, recover_turn_ok

Report the files changed, the test lines and any change you need in another task's file.

---

RULES FOR EVERY ROUND-3 TASK (each task text repeats them)

- **The game:** Tidebreak, Godot 4.7 GDScript. Worktree /Users/kiwimango/Downloads/Frontier/.claude/worktrees/spellcraft
  (branch worktree-spellcraft).
- **Your base:** your own isolated worktree off its head after round 2 (CORE, CLIPS, KITS, HUD_LESSONS) **and the
  round-3 SEAMS commit** have merged. If SEAMS is missing, stop and report. Rebase on the tasks merged before yours
  before your final test run (merge order: CLIPS P1 whenever ready; PERCENT → MOVE → AIR → BOTS). Commit only your own
  files.
- **Read first:**
  - SPEC (v2): /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/smash_r3/spec.md.
    It rules over the part designs and over spec_v1.md. §0 is the controls, §1 the settled conflicts, §14.3 the API
    contract between the tasks, §17 the owner's open questions with the defaults you build, §20 why v2 changed what it
    changed.
  - The long-form part design named in your task, in the same folder. Where it disagrees with spec.md, spec.md wins.
  - docs/bending_design.md (round 2 rewrote it).
  - Round 2's kit: .../scratchpad/skills_r2/spec.md, overridden by .../skills_r2/owner_answers.md. Remember round 2's
    casting: 1/2/4/5 READY a move and right click (RMB) casts it.
  - The owner's answers: .../scratchpad/critic_r2/owner_answers_r3.md.
  - The numbers' scripts (v2): smash_r3/lead_model.py, lead_table.py (lead_table.out), lead_combos.py
    (lead_combos.out) and lead_masher.py (lead_masher.out). The `*_v1.*` files are history.
- **Godot ONLY through the lock,** one Godot at a time:
  - Run: `zsh /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/godot_run.sh <args>`.
  - Tests: `GODOT_TIMEOUT=420 FPS=60 zsh /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/run_test_fps.sh <worktree> <log name> <tests/x.gd> <args...>`.
  - Green = EXIT 0, a PASSED or OK line, and 0 SCRIPT ERROR.
  - Blender only through `zsh /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/blender_run.sh -b -P ...`.
- **Hygiene:**
  - Use simple Bash commands. The worktree guard refuses compound git commands, so write Python helpers under the
    scratchpad.
  - Run `--import` after adding class_name scripts or assets. tools/compile_check.gd must be clean.
  - Match the code's `##` doc-comment style. Every number goes in data.
- **New tests:** a watchdog, seed(1750), a last line `<NAME> PASSED` or `<NAME> FAILED`, exit 0 only on a pass,
  `MatchSetup._aim_help` pinned, `GameSettings.path` isolated. Visuals never use the global RNG.
- **Known red since baseline, not yours:** test_hud_skills 1/33, test_hud_vitals 2/16, throw_edges, throw_flesh and
  anim run_all. test_flow's catch-back flakes about 2 times in 25.
- **THE GATE:**
  - Everything new runs only while `RingRules.stock_on()` is true (a stock-rules ring match has installed its
    RingRules), or, per body, while `RingMoves.of(body) != null` (installed only then).
  - With the gate off, the open world, the duel and the classic zone rules are exactly today's, and a test pins it.
  - The shared files (player.gd, npc_fighter.gd, sway_caster.gd, bend_knock.gd) branch on the gate. They never change the
    ungated path.
- **THE CONTRACT:**
  - Never edit another task's file. Call its API (spec §14.3) through the SEAMS stubs.
  - If you need a change in another task's file, write it in your report with the exact function you need.
- **OWNER RULES (never break):**
  - The sport is "Tidebreak".
  - NO show words in player-facing text: never Avatar, bender, bend, bending, pro-bending, Korra, nation names, or the
    show's technique names. Also never Smash's own names: stock, blast zone, DI, tech, edge-guard, meteor, smash, Final
    Smash. The player's words are "lives", "steer", "break your fall", "Pop", "Slam", "Rise", "dodge", "roll", "duck" and
    "edge". Player text says "right-click" for RMB and "C" for down.
  - NO target cues on enemies of any kind: no rings, frames, chevrons, outlines, markers or map dots. Each competitor's
    own % and lives on a fixed HUD plate is a scoreboard, not a cue. Anything that tells you about YOUR OWN state (the
    pips, your drop shadow, your sounds) stays on your own plate, body or ears.
  - NO painted zone lines. NO cel shading. No guns or gun sounds.
  - Our own clips only (docs/animation_provenance.md, animations/SOURCE.md) and our own assets only.
  - Getting hit never slows the player or hurts his aim. Hitstun is the launch: the camera, the aim and the lock are
    never touched by a hit (the lock is frozen and resumed, never lost).
  - Lock time is the only spam limiter for casts. No hit shortens a lock except the jab step (spec §6.4).
  - Earth catching a stone just before it hits and throwing it back is the fun core: never weaken it.
  - The owner judges by eye: make review images and go bold.
- **Owner calls not yet made:** build the spec's defaults (spec §17) and don't decide them otherwise.
- **Review output** goes to /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/review/
  with the prefix `r3_<task>_`. Report the files changed, the test lines and the METRIC lines.
