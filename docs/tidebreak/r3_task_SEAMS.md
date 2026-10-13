# Round 3 task SEAMS: the API stubs every round-3 task builds against, the practice code moved out of RingMode, and the empty data files. Behaviour unchanged, everything green. Runs ALONE and merges BEFORE the five round-3 tasks fork.

You make the seams for Tidebreak's round 3 (the % layer, spec v2) in an isolated worktree. A short job, about an hour.
- Base: the spellcraft branch after round 2 (CORE, CLIPS, KITS, HUD_LESSONS) has merged.
- Contract: smash_r3/spec.md §14.3 (the APIs) and §19.

FILES YOU TOUCH (each becomes its owner's after you merge):
- scripts/ring/ring_rules.gd, scripts/bending/bend_knock.gd, bend_status.gd, scripts/ring/ring_arena.gd,
  scripts/ring/ring_mode.gd, data/ring/rules.json (all PERCENT's after you)
- NEW scripts/ring/ring_practice.gd, scripts/ring/match_setup.gd (BOTS')
- NEW scripts/ring/ring_moves.gd, scripts/ring/ring_predict.gd, scripts/npc/npc_pad.gd (MOVE's)
- scripts/sway/sway_caster.gd: only the getters, the two methods and the signals listed below (AIR's)
- NEW data/ring/movement.json (MOVE), data/ring/hud.json (PERCENT), data/ring/practice.json (BOTS)
- NEW tests/ring/test_r3_seams.gd

BUILD (stubs return today's behaviour; no gameplay change)

1. RingRules:
- `static func stock_on() -> bool`: false unless an installed RingRules has rule_set "stock". rules.json gets
  `"rule_set": "classic"`, so it stays false.
- `static func class_of(tag: String) -> Dictionary`: {} for now.
- `static func range_mult(tag: String, range_m: float) -> float`: the real formula (1.0 to 10 m, linear to 0.65 at 22 m,
  0.65 beyond; 1.0 for a tag in an exempt list you leave empty for PERCENT to fill).
- `static func launch_v(cls: Dictionary, pct_after: float, d: float, w: float, range_m := 0.0, air := false) -> float`:
  the formula w × (base + growth × range_mult × (0.85 if air else 1.0) × p/100 × (0.5 + d/20)), or base when cls.set.
- `static func weight_of(element: String) -> float`: 1.0.
- `pct_of(b)` 0, `stocks_of(b)` 0, `safe_until(b)` -INF, `hitstun_left(b)` 0, `stunned(b)` false, `string_hits(b)` 0,
  `stale_count(attacker, tag)` 0, `can_escape(b)` false, `last_steer_deg(b)` 0, `fresh_pct(b)` 0,
  `heal_allowed(b)` true, `add_pct(b, delta, by, tag)` no-op, `reset_pct(b, to := 0.0)` no-op, `patch(b) -> float` 0,
  `note_lock_started(b)` no-op, `on_hit(n, by, info) -> Dictionary` {}.
- Signals `pct_changed(b, pct, delta)`, `launched(b, v, hitstun_s, by, tag)`, `ko(b, by, pct, tag, stocks_left)`,
  `respawned(b)`, `string_ended(by, victim, hits, pct)`, `hit_safe(b, by, point)`.

2. BendKnock:
- `static var gravity_override := 0.0`
- `var stun_t := 0.0`, `var tumble := false`, `var lying_t := 0.0`
- `func apply_di(dir: Vector3) -> void` (no-op), `func press_break(dir: Vector3) -> void` (no-op),
  `func getup(kind: String) -> void` (no-op), `func scale_carry(k: float) -> void` (real: kv *= k)
- `signal launched(v: Vector3, hitstun_s: float, refresh: bool)`, `signal broke_fall(kind: String, dir: Vector3)`
- `knock(...)` gains a trailing `info := {}` that it ignores. Today's knock still ADDS; PERCENT makes it set under stock.

3. BendStatus:
- `static var take_filters: Array[Callable] = []`; can_take is false if any filter returns false (none registered).
- `knock(n, v, by, info := {})` passes info to BendKnock; `hurt` gains the same trailing `info := {}`.

4. RingArena:
- `nearest_lip(pos) -> Dictionary {point, normal, out_m, side, along}` (real, from the deck rectangle: pure geometry)
- `lip_y() -> float` (the deck top)
- `spout_at(side, slot) -> Vector3` (the s = 12 m line, grate z)
- `is_out(pos) -> bool` (today's rule, unchanged)
- `wall_place_ok(pos) -> Vector3` (returns pos unchanged for now)

5. RingMoves (NEW, `class_name RingMoves extends Node`, a child named "RingMoves"):
- `static install(body) -> RingMoves`, `static of(body) -> RingMoves` (null when absent)
- `pre(intent, dt) -> bool` (false), `intent_from_keys() -> Dictionary` ({}), `profile() -> Dictionary`
  ({"self_up_mult": 1.0})
- `can_cast()` true; `airborne()`, `off_deck()`, `helpless()`, `on_ledge()`, `on_spout()`, `intangible()`,
  `in_landing_lag()` false
- `jumps_left` 0, `dodge_ready` false, `rise_ready` false, `ledge_safe_left()` 0
- `dodge(dir)`, `land_lag(s)`, `ride_spout(pos, max_s)`, `leave_spout()` no-ops; `cam_bias() -> Dictionary` ({})
- `static simulate(state, plan, dt, horizon) -> Dictionary` ({})
- `signal moved(kind)`, `signal left_spout`

6. RingPredict (NEW, `class_name RingPredict`, static only):
- `flight(v, hitstun_s, from, element) -> {lands: "deck", travel_m: 0, t: 0}`
- `would_ko(tag, target, from, dir, range_m := 0.0, air := false) -> false`
- `ko_pct(tag, target, from, dir, range_m := 0.0, air := false) -> INF`

7. NpcPad (NEW, `class_name NpcPad extends RefCounted`): `press(key)`, `hold(key, on)`, `move: Vector3`, `di: Vector3`,
   `intent() -> Dictionary` with the keys `{move, jump, jump_short, jump_held, dodge, dodge_dir, fast_fall, down_held,
   guard_held, guard_pressed, ledge, di}`.

8. The practice extract:
- Move RingMode's practice code (the `practice` section from ~line 872, `_practice_step`, the dummy's way and keys, the
  practice hint and tally lines) into scripts/ring/ring_practice.gd (`class_name RingPractice`).
- RingMode keeps one-line calls into it: `reset()`, `step(dt)`, `set_way(way)`, `paint()`.
- Behaviour unchanged; test_practice and test_lessons stay green.

9. SwayCaster (AIR's file; only these):
- `func guard_up() -> bool`: true while round 2's guard zone stands (a real one-liner over its existing state).
- `func ready_default() -> void` and `func drop_all() -> void`: no-ops (AIR fills them).
- `signal air_cast(m, mode)` (never emitted yet), `signal lock_started(m, mode)` and `signal cast_released(m, mode)`:
  emit these two at the existing points where a lock starts and where a cast is released (one line each, no other change).

10. MatchSetup: `rule_set() -> String` ("classic"), `games() -> int` (1), `practice_pct() -> Dictionary` ({}).

11. Data files: movement.json, hud.json and practice.json, each `{"_about": "..."}`, naming its owner task and spec
    section.

TESTS
- Keep green: the whole round-2 suite. At least tests/bending, tests/ring (test_ring_rules, test_ring_match,
  test_practice, test_lessons, test_playcheck, test_ring_hud), tests/npc (test_bend_bots, test_duel_bender) and
  tests/sway.
- New tests/ring/test_r3_seams.gd:
  - every §14.3 symbol exists (methods, static vars and signals, with their argument counts);
  - stock_on() is false;
  - launch_v matches the formula for one class at range 0, 16 and 30 m and with air true;
  - nearest_lip is right on each side and at a corner;
  - RingMoves.of(player) is null in an open-world scene;
  - lock_started and cast_released each fire once for one RMB cast in a test scene.

Report the files changed and the test lines. Merge at once; the five tasks fork from your commit.

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
