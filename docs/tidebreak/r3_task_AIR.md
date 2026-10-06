# Round 3 task AIR: the cast layer for the % ring: "the numbers ready, right click casts; left click, E, 3 and Space act at once" made true (3 on press, 1 readied at the start and after every fall), every key in the air (key 2's form decided at lock start, the Slam with its spike and bounce, 4 and 5 waiting for the ground, 3 routed to the air dodge), landing lag and air fill, the jab step, the Pop and earth's Pop stone, the guard as a shield against everything, the lock frozen in hitstun, hit info for the % rules (tag, range, air, volley), walls 3.5 m off the lip, Patch's lock, and the Kick's wave over the lip.

You build round 3's AIR for Tidebreak (Godot 4.7) in an isolated worktree.
- Merge order: after PERCENT and MOVE, before BOTS. Rebase on both before your final test run.
- Your part design: smash_r3/aerials_v1_prev.md (the original MOVES write-up; aerials.md is a forked duplicate).
  spec.md v2 wins where they differ:
  - **No Chain** (no hit halves a lock; combos come from overlapping locks, the jab step and the Pop's set stun);
  - 3 in the air is MOVE's air dodge, and the Rise is MOVE's on Space;
  - **key 2's form is decided when its lock starts** (not at release);
  - **every guard is a shield against every attack** in the stock ring;
  - **earth's Pop leaves a stone in the hand**;
  - locks fill in the air at the moving rate (not the standing rate);
  - earth's stones off the deck are NOT smaller; the stale and string rules are PERCENT's;
  - the Pop is a set 9 m/s at 80° with a set 0.60 s stun; the Slam's angle is −70°.
- Spec sections you own: §0's cast rows, §4.4 (the cast side of the guard), §4.5's key 3, §6 (all of it), §8's lock,
  and the AIR tests in §15.

ROUND-2 FILES YOU WILL MEET (all yours now):
- sway_caster.gd: readying (tap / tap twice), RMB's click and hold, SRC_GUARD, the click buffer, the same-key switch, ▲
  grow at 0.45 s, the sputter, the hit setback, the guard whiff; and SEAMS' `guard_up`, `ready_default`, `drop_all`,
  `air_cast`, `lock_started`, `cast_released`.
- bend_zone.gd: perfect_s 0.3, late_mult 0.5, the guard matrix, earth's held stone and the return, water Turn, fire
  Parry, air Wind Guard.
- bend_effects.gd: floor_wave, crescent, walls with place 2-6 m, Shove's order, Column/Geyser rise_s, Breath and smoke,
  Embers, the Fireball as Punch grown.
- moves.json's `jabs`, `guards` and `passives` blocks; poses.json; schemes.json.
- test_r2_cast.gd and test_r2_guards.gd.

FILES YOU OWN (no one else edits them):
- scripts/sway/sway_caster.gd, form_cast.gd, form_effects.gd, form_raised.gd, form_stone.gd
- scripts/bending/ bend_cast, bend_caster, player_bend_caster, body_bend_caster, bend_effects, bend_zone, bend_bolt,
  bend_throw, bend_motion, bend_looks, bend_poses, bending, bend_sounds (NOT bend_knock or bend_status: PERCENT)
- scripts/ui/hotbar.gd
- data/sway/moves.json, data/bending/poses.json, data/bending/schemes.json
- tests/bending/test_bend_cast.gd, test_bend_caster.gd, test_bend_throw.gd, test_flow.gd, test_r2_cast.gd,
  test_r2_guards.gd, test_bend_poses.gd, test_bend_sounds.gd
- tests/ui/test_hotbar.gd; tests/ring/test_quick_spell.gd, test_schemes.gd
- new tests/bending/test_r3_air.gd, test_r3_combo.gd, test_r3_guard.gd

You do NOT edit bend_knock.gd, bend_status.gd, the ring scripts, rules.json or the HUD and strip (PERCENT); player.gd,
npc_fighter.gd, sway_pose.gd, ring_moves.gd or movement.json (MOVE); npc_bending.gd or bend_ai.json (BOTS).

BUILD (everything branches on `RingRules.stock_on()`; the open world, the duel and classic are unchanged)

1. The keys (spec §0).
- **3 acts on press** in the stock ring and **never changes the readied move**:
  - airborne: no lock; call `RingMoves.of(caster).dodge(held dir)` at once and drop any running lock (free before its
    click);
  - on the deck: round 2's Dash goes as soon as its lock fills, but not before 0.22 s after the press; a second tap of 3
    inside that time is round 2's same-key switch to the travel move (Lift, Surf, Jets, Leap; time kept, pose ≥ 0.2 s).
    It drops a running RMB lock (free before its click). Direction and "nothing held = back" as round 2. The other
    schemes keep their routes; key 3's press acts the same in all of them.
- **`ready_default()`** readies key 1's first move; PERCENT's RingMode calls it at the countdown and after every respawn.
- **`drop_all()`** drops every lock (free) and every held stone (it falls as a loose stone where he was); RingMode calls
  it on a fall.
- **macOS:** while the caster has RingMoves, an RMB press event that carries `ctrl_pressed` is read as LMB.
- **E while `BendKnock.tumble`** never raises the guard and never fills the buffer (it is MOVE's break-fall press).
- **On the spout** (`RingMoves.on_spout()`): a cast key calls `RingMoves.leave_spout()` and starts its lock at once.
- Emit `lock_started(m, mode)` whenever any lock starts (the guard's included) and `cast_released(m, mode)` at every
  release (LMB, RMB, E's throw).

2. Hit info for the % rules.
- Every hit from BendEffects, BendBolt, BendThrow, FormStone and BendZone returns passes info to `BendStatus.knock/hurt`:
  `tag` ("id/mode", + ".grown" for ▲ and the Fireball), **`from`** (the cast's origin point), **`air`** (released while
  airborne), `set_stun` where the spec sets one, `slide_only` on a late guard, `bounce_once` for the Slam on the deck,
  `returned` / `ret_mult` / `origin_tag` on returns.
- **A volley** (Pebbles' 3, Embers' 7) carries one `volley_id` and `volley_n` on every projectile. PERCENT applies one
  knock and splits the d.

3. The air forms (spec §6.1).
- LMB and 1 (and 1 tapped twice): the same move along the full 3D aim; their form is decided at release. Nothing grows in
  the air: a lock grown before takeoff stays grown, and Punch doesn't become the Fireball in the air.
- **Key 2: the form is decided when its lock STARTS** (`RingMoves.of(caster).airborne()` at the start):
  - started airborne: the Slam (an `air` block on key 2's first-move specs in moves.json); landing before its release
    calls it off for free;
  - started on the deck: the Push or Push ▲, released along the 3D aim even if airborne by then.
- 2 tapped twice: Column and Geyser from the deck at the aim (never the tank's water); the High Kick as a crescent along
  the aim (pose own-bend-fire-flip-kick, stand-in fire-kick); Pull along the aim.
- 4 and 5: the lock pauses while airborne and resumes from the same fill on landing.
- E: the same guard, the earth catch included. With a stone in hand, E throws it along the 3D aim. No landing lag from E.
- 3 on the deck: BendMotion multiplies its up speeds by MOVE's `profile().self_up_mult` in the ring, and Leap's glide is
  off.
- **Air fill:** a lock fills in the air at round 2's moving_mult by horizontal speed, exactly as on the deck (fire's
  Footwork keeps full rate). air_fill_mult is retired.
- Casting never stops the fall; 'root: place' is ignored airborne.
- Earth's air stones tear from the nearest deck face within 12 m and fly to the hand during the lock (form_stone), with
  the same numbers.
- Emit `air_cast(m, mode)` when a cast is released airborne (MOVE plays the air-legs mask).
- **The readied move never changes except by the number keys:** an air dodge, a landing, a dash: RMB still casts what was
  readied before.

4. The Slam (spec §6.2).
- A new BendEffects `do: "slam"`: a box query under the caster, 2.5 m wide (water 3.2), from the feet to 3 m below (air
  4), leaning up to 1.5 m toward the aim's yaw, out 0.12 s at the strike. Lock 0.35 (fire 0.3).
- The hit: tag "<id>/slam", set_stun 0.30, launch at −70°.
- On a grounded body: `bounce_once` (PERCENT bounces him at 0.45 × the down speed + 2, earth 0.55, once per string); a
  second Slam in a string pushes flat at half.
- Per element: Hammer (with a held stone it throws that stone instead); Downpour (widest; puts out fire; a 6 s puddle that
  counts as a Geyser source); Axe Kick (on reaching the deck it splits into a 6 m mini floor wave); Down Gust (deepest;
  lifts the caster 2.5 m/s once per airtime).
- Clips: own-bend-earth-hammer, own-bend-water-downpour, own-bend-fire-axe-kick (+ -l), own-bend-air-down-gust, with
  stand-ins from round 2's poses.
- Land lag 0.30 (0.15 on a hit).

5. Landing lag and short hops (spec §6.3).
- A move is "out" from release to strike + 0.15 (Slam + 0.2); **a Strike (key 1's moves) is out for at least 0.35 s after
  its release**. Landing while out calls `RingMoves.land_lag(s)`:

  | Move | Lag (s) |
  |---|---|
  | Jab | 0.10 |
  | Quick Strike | 0.20 |
  | Big Strike | 0.25 |
  | Lightning | 0.35 |
  | Slam | 0.30 |
  | 2 tapped twice | 0.25 |
  | E | 0 |

  A hit halves it. During it a lock may fill, but jump, dash and E wait.
- The landing clips own-bend-land-light and own-bend-land-heavy are played by MOVE from the lag length.
- The short hop itself is MOVE's (Space within 0.05 s of your `cast_released`).

6. The jab step and the Pop (spec §6.4).
- After a jab that hits, the next jab is ready 0.15 s after the last one's release (decided at the hit; every element).
- The third jab that hits in a string (`RingRules.string_hits(victim)` and your own count) is the Pop: tag "jab/pop", a
  set 9 m/s at 80°, set_stun 0.60, an element burst at contact, and the caster's own-bend-jab-rise (+ -l) clip.
  - **Earth's Pop leaves a held stone in the caster's hand** (the stone fist's stone, held as round 2 holds a caught
    stone; none if he already holds one). E throws it: tag `rock_jab/pop_stone`, not `returned` (PERCENT gives it the
    Spike's class and stales it).
  - Water a crest, fire a flame column, air an updraft.
- One Pop per string. After it, jabs are plain (round 2's locks; PERCENT stuns them 0.10 s); a miss or a guard resets to
  step 1.

7. The guard as a shield (spec §2.5, §4.4; % ring only).
- SRC_GUARD stands the guard WHEN ITS LOCK FILLS (earth, water, air 0.2; fire 0.15). A tap keeps round 2's window (earth
  1.0, others 0.8). Held, it stays up while E is held, up to 2.5 s.
- **Every guard stops every attack** under stock: perfect (within 0.3 s of standing) = 0% and no launch; late = half
  (`slide_only`). The round-2 matrix decides only the **reward** (catch and hold, Turn, Parry, bounce back; douse, melt,
  drop): in a cell round 2 marked "passes", a perfect is 0% with no reward. **Lightning:** only fire's Parry can be
  perfect; every other guard takes it as late.
- **Earth vs stone:** a full catch within round 2's 1.0 s window from standing (a late catch inside it still full); held
  past the window, a stone is late (half through) and drops at his feet as a loose stone.
- The whiff rule as round 2.
- While up: no walking. Space jumps on the same frame; MOVE's Roll and Duck read `guard_up()`; any cast key drops it in
  0.1 s and starts that key's lock. E with a stone in hand always throws.
- The held loops: own-bend-guard-hold-<element> (stand-ins: round 2's guard poses).
- Classic and the open world keep round 2's stand-at-release and the matrix's "passes", pinned by a test.

8. The lock in hitstun (spec §3.2).
- While `RingRules.hitstun_left(caster) > 0` **every lock timer is frozen** (the fill, the sputter and fizzle, ▲'s growth
  and its self-cast at 1.0 s) and resumes after; round 2's hit setback is skipped under stock.
- Lightning's charge still breaks on a hit.
- One buffered release made during hitstun fires on the first free frame.
- No cast while `RingMoves.can_cast()` is false.

9. Walls and the edge.
- Key 4's walls (earth, ice, fire, wind) clamp their place through `RingArena.wall_place_ok(pos)` (at least 3.5 m inside
  every lip).
- The Kick's floor wave runs on 0.3 m past the lip, so it hits a hanger's hands once his intangibility is over.
- Column and Geyser never rise from the tank's water.

10. Patch under stock (spec §8): its lock is 1.5 s (moves.json `ring_lock_s`) with moving_mult 0 (it fills only standing
    still; Footwork doesn't apply); it can't start while `RingRules.heal_allowed(caster)` is false (the chip greys via
    PERCENT's strip); at full it calls `RingRules.patch(caster)`.

11. Combos are true by design.
- Do not shorten any lock other than the jab step. lead_combos.out (v2) is the target: jab, jab, Pop → the Pop's stone
  (earth), Shove, Lash, Punch, Slice, Gust true at every %; Pop → Wind Ball, Spike, Kick never; Kick → Punch, High Kick →
  Punch, Geyser → Lash, Column → Pebbles, Pull → Palm true from 0%; Spike → E return from about 25%.

TESTS
- The AIR tests of spec §15: test_r3_air (key 3 on press both ways, the readied move kept through a dodge and a landing,
  1 readied at the start and after a respawn, key 2's form at lock start, the Slam, 4/5 paused, landing lag with the
  Strike's 0.35 s, air fill at the moving rate, hit info, walls 3.5 m, frozen timers, tumbling E, macOS ctrl+RMB, Patch,
  `drop_all`), test_r3_combo (the jab string, earth's Pop stone, the engine probes, the self-loops Embers/Palm/Pebbles/Pull
  ×12 at 0% and 150%: longest true run ≤ 4 (Pull ≤ 2) and every later gap ≥ 0.15 s, no Chain) and test_r3_guard (the
  four guards against all four elements' attacks in the stock ring: perfect 0% with or without a reward, late half,
  Lightning perfect only for fire, earth's 1.0 s window then late with the stone dropped, the held 2.5 s, the whiff;
  classic unchanged).
- Keep green: test_r2_cast and test_r2_guards (their stock twins where the rules differ), test_bend_cast,
  test_bend_caster, test_bend_throw, test_flow, test_bend_poses, test_bend_sounds, test_quick_spell, test_hotbar,
  test_schemes, and tests/sway.
- Kick floor-wave tests at ring gravity: a jump (apex 2.0) is missed from 0.07 to 0.82 s after takeoff; a short hop (0.8)
  from 0.14 to 0.43 s.

REVIEW OUTPUT (prefix r3_air_):
- slam_earth.png, slam_water.png, slam_fire.png, slam_air.png (the caster's strike frame and the bounce)
- pop_<element>.png (the burst at contact, on the caster's side only; earth's with the stone kept in hand)
- air_legs.png (one deck and one air cast of the same move)
- land_lag.png (light vs heavy)
- guard_hold_<element>.png; guard_late_slide.png
- METRIC lines: bnb_true_0pct per element (the engine probe), bnb_true_150pct per element, self_loop_max_run per jab,
  slice4_drops_by_hit, no_chain_ok, jab_step_s, pop_once_ok, earth_pop_stone_ok, key3_keeps_ready_ok,
  key2_form_at_start_ok, guard_stand_at_fill_ok, shield_all_ok, lock_frozen_in_hitstun_ok, walls_off_lip_ok,
  air_release_share (from a scripted bot fight)

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
