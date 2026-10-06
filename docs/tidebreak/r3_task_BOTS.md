# Round 3 task BOTS: the bots for the % game (the same mover through NpcPad, states over today's chooser, KO reads with range, true strings only, steering, breaking out and the fall, recovery planning, the edge, keeping him off, the spout, healing by the new rule), Practice (the % rows, the dummy's ways, the string counter and the launch readout), the lessons for the new rules (the stock guard card, the per-element String card, the hint queue), the menus (Rules row "Lives"/"Zones", best of 3), the soak and balance re-run, and the design doc.

You build round 3's BOTS for Tidebreak (Godot 4.7) in an isolated worktree.
- Merge order: LAST, after PERCENT, MOVE and AIR. Build in parallel against the SEAMS stubs, then rebase on all three
  before your integration tests and the soak.
- Your part design: smash_r3/bots.md (where it disagrees with spec.md §9, §11 and §12, spec.md v2 wins): the HUD plates
  are PERCENT's; the respawn is the water spout for everyone; steering is read at 0.1 s, yaw only; hitstun is 0.045 s per
  m/s; no Chain; Patch only takes fresh damage and never while the foe is out; walls stay 3.5 m from any lip for everyone
  (AIR's rule, not a bot rule); the clock is 8:00.
- Spec sections you own: §9, §11, §12, the menus of §7.3-7.4 and the BOTS tests in §15.

ROUND-2 FILES YOU WILL MEET (yours now):
- npc_bending.gd as KITS left it: guard chances 0.1/0.3/0.6, the earth bot's return by re-cast, floor-wave jumps,
  Kick→Punch, Column→Spike, Pull→Palm and Geyser→Wave combos, the lightning dash, Embers, the Fireball, Breath.
- bend_ai.json.
- ring_lessons.gd and lessons.json (round 2's per-element guard cards).
- how_to.gd (round 2's F1 lines).
- ring_menu.gd's Controls listing.
- match_setup.gd's scheme ids and practice throw dummy.
- test_ring_soak.gd (round 2's guard-matrix soak).

FILES YOU OWN (no one else edits them):
- scripts/npc/npc_bending.gd; data/npc/bend_ai.json
- scripts/ring/ring_practice.gd (SEAMS extracted it), ring_menu.gd, match_setup.gd, ring_lessons.gd
- new scripts/ui/practice_panel.gd; scripts/ui/first_hints.gd, lesson_card.gd, how_to.gd, how_to_key.gd,
  scripts/ui/menu/main_menu.gd (the Practice panel and Rules rows)
- data/ring/lessons.json, data/ring/practice.json
- docs/bending_design.md
- tests/npc/test_bend_bots.gd, test_duel_bender.gd, test_duel.gd; new tests/npc/test_bot_recovery.gd, test_bot_pct.gd
- tests/ring/test_practice.gd, test_match_setup.gd, test_lessons.gd, test_playcheck.gd, test_ring_soak.gd,
  test_balance.gd; tests/ui/test_how_to.gd

You do NOT edit npc_fighter.gd, npc_body.gd, npc_pad.gd, ring_moves.gd, ring_predict.gd or movement.json (MOVE);
ring_rules.gd, ring_mode.gd, the HUD, screens.json or rules.json (PERCENT); sway_caster.gd, moves.json or poses.json
(AIR).

BUILD

1. The body (spec §9.1).
- In the stock ring the bot moves only by filling NpcPad, MOVE's intent: move, jump, jump_short, jump_held, dodge,
  fast_fall, down_held, guard, ledge, di.
- `go()` and `face_point()` write `pad.move` behind the gate. `_edge_brake` is off in CHASE and RECOVER.
- Its casts go through the same SwayCaster rules as the player's (key 3 acts on press; key 2's form at lock start).
- A test pins that the bot never writes velocity in the stock ring.

2. The mind (spec §9.2).
- States NEUTRAL, PRESSURE, EDGEGUARD, LEDGETRAP, REELING, RECOVER, LEDGE and RESPAWN, picked each tick by
  `_pick_state()`. A state holds at least 0.2 s unless a hit lands.
- Today's chooser runs only in NEUTRAL and PRESSURE. think_s stays 0.25; the recovery planner re-runs every 0.1 s off the
  deck.

3. KO reads, strings, the victim, recovery, the edge, keeping him off, the spout, healing, fairness: spec §9.3-9.8, every
   number in the `bend_ai.json pct` block.
- The KO read calls `RingPredict.would_ko(tag, foe, from, dir, range_m, air)` (hard assumes the foe steers his best).
  **Finishers want range:** a KO-bonus move is ×0.6 from beyond 15 m, so the bot walks in to finish.
- True strings test `RingRules.hitstun_left(foe) >= lock_for(next) + flight − 1/60` (`hitstun_left` already counts the
  0.6 s escape).
- The string table: spec §6.9 and lead_combos.out (v2). The earth bot's accident string ends with E (the Pop's stone);
  drop round 2's Column→Spike (no longer true) and keep it only as a read.
- Steering is set once through `pad.di` at the launch; break out at 0.6 s via `RingRules.can_escape` with a fresh pad
  press; break the fall by pressing E through the pad.
- Recovery runs `RingMoves.simulate()` over six plans toward the nearest open lip; never a 4th grab without the deck.
- Edge options by preset. Keeping him off: shots from ≥ 1 m inside the lip at the predicted landing point; hard listens
  for the Rise's tell and releases a pre-filled lock as `ledge_safe_left()` reaches 0. Never hit into a safety.
- The spout: leave by preset. **Healing:** Patch only with `RingRules.fresh_pct(self) >= 6`, standing still, the foe 12 m
  or more away and not winding up at it, and only when `RingRules.heal_allowed(self)`.
- Above 120% of its own: react +0.15 and the centre pull. Hard counts the player's favourite edge option and covers it.
- Reads only %, lives, positions, poses and visible wind-ups; never inputs. The reaction_s presets are unchanged.

4. Practice (spec §11.1), in ring_practice.gd, practice_panel.gd, ring_menu.gd and match_setup.gd.
- **Rows:** Its % and Your % (0/30/60/90/120/150/200/grows; R and a fall reset to them via `RingRules.reset_pct`); the
  dummy's way on B (stand, walk, jump, guard (3 kinds), recover, throw, fight; `NpcBending.set_practice_way`) and its
  steering (none/in/out/random); "Throw me off"; Speed 1, 1/2, 1/4; Fresh moves on/off.
- **No lives and no clock.**
- **The string counter** (top centre, 32 px, white while true, grey once free; best kept) uses `RingRules.hitstun_left`
  (the escape counted) and `string_hits`.
- **The readout** (18 px, numbers only): "Launch 9.2 m · reeling 0.55 s · steered 12° · from here, out at 124%", from
  `RingPredict.ko_pct` and `RingRules.last_steer_deg`.
- A Practice-only notes line: *"Hop and let go at once: a low hop."*
- **Keys:** R and B keep their jobs, with no new keys. **Words** go in practice.json.

5. Menus.
- The Esc menu's Rules row reads **"Lives" / "Zones"** (never the ids); Zones only for this round.
- Games: 1 / best of 3 → `MatchSetup.games()`, with `rule_set()` and `practice_pct()` filled.
- The main menu's Practice panel gets the same % rows.
- The Controls listing in RMB terms: "1, 2, 4, 5 ready a move · right click casts · left click jabs · E guards · 3
  dodges · Space jumps · C is down".

6. Lessons (spec §11.2), in round 1/2's one system (ring_lessons.gd, lessons.json, lesson_card.gd, first_hints.gd). Do NOT
   add a second system.
- **Round 2's guard card, stock text:** "E: up as soon as it's ready, and it stays while you hold it. Tap a direction to
  roll. On the beat, nothing gets through." (classic keeps round 2's text).
- The six core cards (%, Out, Jumps, Dodge, Back, Edge) and three more (String, Steer, Keep him off), each done by doing
  it; Enter skips. Texts exactly as spec §11.2; **the String card per element** (earth "...and you keep a stone. Then E:
  throw it."; the others "...Then right-click your 1."); the Back card "Look at the deck, then Space, Space, Space."
- **One hint queue:** at most one hint every 20 s; the edge and recovery hints always win and pre-empt; the stale-move
  hint waits until after the first fall.
- New lesson keys: dummy_pct, player_pct, place. They listen to `RingRules.pct_changed/ko` and `RingMoves.moved(kind)`.
- FirstHints: one row, "[Space] twice · [3] in the air".
- F1 (how_to.gd): "Space jumps; again in the air; off the deck once more: your Rise", "3 in the air: dodge", "Guard up +
  tap a direction: roll; + C: duck", "C: down", "E just as you land: back on your feet", "Thrown? Hold left or right: you
  curve", "On the edge: W climbs, Space jumps, E rolls in, a click attacks, C lets go".
- No show words and no Smash names.

7. docs/bending_design.md: a "The % ring" section with the rules and the class table (lead_table.out v2); the keys (§0's
   sentence and table); the movement and edge numbers; the true strings; the bots' presets; the soak results; the
   owner's quotes kept. Ask the other tasks' reports for their final numbers.

8. The soak and balance (spec §12).
- test_ring_soak.gd with rules=stock: 16 pairings × 3 seeds, time scale 1, normal bots.
- Every METRIC line of §12 (including timeouts_level, last_life_s, ko_far_share, heal_share_of_damage,
  heal_pct_per_life, grabs_refused), plus a table in review/r3_bots_soak.md.
- Retune numbers only, never identities, in this order: bend_ai.json first. Then report, with the exact values, what
  PERCENT's knobs (pct_scale, growth_scale, range far_mult, decel_air, hitstun_k, weights, deck_w, time_s) or MOVE's Rise
  numbers should become. You do not edit their files; the integrator applies them after your merge.
- test_balance.gd for lives instead of rounds.

TESTS
- The BOTS tests of spec §15: test_bot_recovery, test_bot_pct, test_bend_bots (stock additions, gravity parity, the earth
  bot's Pop stone), test_practice, test_lessons (with the hint queue and the per-element String card), test_playcheck
  (double jump, air dodge, thrown off an end and back with the Rise; the match reaches DONE), test_match_setup,
  test_ring_soak and test_balance.
- Keep green: test_duel_bender, test_duel (the duel unchanged) and test_how_to.

REVIEW OUTPUT (prefix r3_bots_):
- soak.md (the METRIC table per pairing and element)
- practice_panel.png (rows, counter white and grey, readout with "steered")
- lesson_<card>.png for the nine cards and the stock guard card
- edge_trap.png (a hard bot keeping a recovering player off: one frame)
- METRIC lines: every §12 line, bot_recover_success per element × preset, ko_read_rate_150 / ko_read_rate_0,
  finisher_range_m (median), true_string_only_ok, steer_rate per preset, recovering_player_hit_rate_hard,
  no_velocity_write_ok, hint_queue_ok

Report the files changed, the test lines, the soak table and the knob changes you recommend for other tasks' data.

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
