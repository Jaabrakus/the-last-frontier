# Round 3 task PERCENT: the % rules (no health in the ring), the launch formula with its range and air factors, knocks that SET the motion, every move's class, weight, hitstun and its fairness, steering, breaking the fall, stale moves and string decay, guards as shields in %, Patch as fresh damage, 3 lives with the water-only KO and the spout respawn, the 8:00 clock and sudden death, the deep-tank stage (curtain, coping, lanterns), the HUD's % plates and pips, the strip in the air, the screens and the words.

You build round 3's PERCENT for Tidebreak (Godot 4.7) in an isolated worktree.
- Merge order: first of the four code tasks (after SEAMS).
- Your part design: smash_r3/launch.md (RULES). spec.md v2 wins where they differ: gravity 20, water 6 m down, carry decay
  8, hitstun 0.045, the v2 class table, set-not-add, the curtain, the spout, no Chain, no sinking deck, the 8:00 clock.
- Spec sections you own: §2, §3 (the rules side), §5.1-5.2, §7, §8, §10, plus the PERCENT tests in §15.

ROUND-2 FILES YOU WILL MEET:
- BendKnock and BendStatus as CORE left them (today's knock ADDS to kv and vy: bend_knock.gd ~105-109). The hit setback
  lives in SwayCaster (AIR); the guard results are signals from BendZone (AIR).
- rules.json: round 2's max_walls, one_at_a_time and knock_scale.
- match_bar.gd, bend_strip.gd (round 2's JAB and GUARD chips, the "tap twice" fade), screens.json (round 2's tips).
- test_ring_hud.gd's "nothing follows the bot" check.

FILES YOU OWN (no one else edits them):
- scripts/ring/ring_rules.gd, ring_mode.gd, ring_arena.gd, ring_water.gd, ring_dressing.gd, ring_crowd.gd, ring_level.gd,
  ring_look.gd; new scripts/ring/ring_spout.gd
- scripts/bending/bend_knock.gd, bend_status.gd
- scripts/ui/match_bar.gd, hud.gd, bend_strip.gd, round_screen.gd, match_screen.gd; new scripts/ui/percent_bar.gd
- data/ring/rules.json, ring.json, screens.json, hud.json
- tests/ring/test_ring_rules.gd, test_ring_match.gd, test_ring.gd, test_ring_teams.gd, test_ring_hud.gd,
  test_ring_screens.gd, test_player_words.gd, test_ring_assets.gd, test_ring_dress.gd, test_ring_look.gd
- tests/bending/test_knock.gd
- new tests/ring/test_ring_pct.gd, test_ring_hitstun.gd, test_ring_stage.gd, test_percent_hud.gd

You do NOT edit player.gd, npc_fighter.gd, npc_body.gd, sway_pose.gd, ring_moves.gd, ring_predict.gd or movement.json
(MOVE); sway_caster.gd, bend_zone.gd, the rest of scripts/bending or moves.json (AIR); npc_bending.gd, ring_practice.gd,
ring_menu.gd, match_setup.gd or the lessons (BOTS).

BUILD

1. The rule set.
- rules.json `rule_set` defaults to "stock". "classic" (today's zones) stays one round behind BOTS' Esc Rules row
  ("Lives" / "Zones"), unchanged and pinned by a test.
- `RingRules.stock_on()` is true while a stock RingRules is installed.
- Under stock these are off: confinement, soft walls, advancing, winded, `_refill`, territory, health_frac,
  knocked_back, the edge guard (MOVE's teeter replaces it) and knock_scale. `forward_limit` returns −INF, and
  `bounds_fn_for` clamps to the deck rectangle only.
- RingMode installs `RingMoves.install(body)` on every competitor, sets `BendKnock.gravity_override = 20` while the stock
  ring stands (restored on exit), calls `SwayCaster.ready_default()` on each competitor's caster at the countdown and
  after every respawn, calls `SwayCaster.drop_all()` on a fall, and connects each caster's `lock_started` to
  `RingRules.note_lock_started`.

2. The ledger (spec §2.1).
- A hit adds d %, never touches health, and health bars hide.
- d comes from `rules.json stock.classes[tag]` (spec §2.3, every row, including the jab volleys at 5/4/4/3, the Pop, the
  Pop's stone `rock_jab/pop_stone`, the Slam per element, the Rise hits, the edge and getup attacks, Fire Wall, Wind
  Wall, Pull, and the return rule: Spike's class or the `origin_tag`'s class if higher, ×1.2, the rally). Untagged damage
  converts by d = 13(1 − e^(−dmg/35)). pct_scale 1.
- **A volley is one hit:** the hits that share a `volley_id` add d ÷ `volley_n` each; only the first applies the knock and
  the stun and counts in the string and the stale queue.
- Read the hit info AIR sends: `tag`, `from`, `air`, `volley_id`, `volley_n`, `set_stun`, `slide_only`, `bounce_once`,
  `returned`, `ret_mult`, `origin_tag`.

3. The launch (spec §2.2).
- v = W(base + growth · R · A · p/100 · (0.5 + d/20)), with p after the hit and d after staling. Set classes launch at
  their set speed.
- **R:** `range_mult(tag, |hit point − info.from|)`: 1.0 to 10 m, linear to 0.65 at 22 m, 0.65 beyond; exempt returns
  and Lightning. **A:** 0.85 when `info.air`, except the Slam and returns.
- **Knocks SET the motion under stock** (never add): BendKnock sets kv to the knock's flat part and vy to its up part
  (cap 16). Pull's set speed is at most √(2 × 6 × distance to the caster). The open world keeps today's adding.
- The direction rules of spec §2.2. Weights: earth 0.89, water 1, fire 1.03, air 1.11. Rooted ×0.85 on base only;
  Carried wind ×1.15 on all.
- Tumble at v ≥ 9 or angle ≥ 60°; otherwise a flinch-slide on the feet.
- Carry decay 8 m/s² airborne (the open world keeps 0.8). ragdoll_mps INF, max_push off.
- BendKnock emits `launched(v, hitstun_s, refresh)`: **refresh is true only for a tumbling launch class** (not a set
  knock, a flinch or the Slam). MOVE refreshes the air moves on it.
- RingRules emits `launched(b, v, hitstun_s, by, tag)` and `pct_changed`.

4. Hitstun (spec §3).
- clamp(0.045 v, 0.12, 1.2), or the set stuns: jabs 0.30, Pull 0.40, Pop 0.60, Slam 0.30, bounce 0.45, lying 0.20.
- Counted from the hit for every body, in physics time. BendKnock.stun_t replaces knock_t's reaction window under stock.
- `hitstun_left(b)` = the time until he can act, **the 0.6 s escape counted** (min of the stun's end and 0.6 s when the
  stun is longer). `stunned(b)`, `can_escape(b)` (true from 0.6 s in a stun over 0.6 s).
- **String decay on every hit** (spec §6.7): the m-th hit's stun ×0.8^(m−1), floor 0.4, set stuns included; **the Pop
  exempt**; a jab (any jab tag) after the Pop in the same string stuns 0.10 s; the 6th hit's stun at most 0.10 s; when a
  string of 4+ hits ends, 0.4 s in which any hit stuns at most 0.10 s. Counted on the victim across attackers.
  `string_ended(by, victim, hits, pct)` on his first free frame.
- **Steering:** `apply_di(dir)` (called by MOVE 0.1 s after the hit with the held keys) turns the carry's yaw by up to 15°
  (the part across the flight only), never the pitch; the part AGAINST the flight adds 2 m/s² of carry decay for 0.3 s.
  `last_steer_deg(b)` reports the turn.

5. Breaking the fall, lying and getting up (the state is yours; the inputs and the roll motion are MOVE's).
- `press_break(dir)`: MOVE calls it for each E press while tumbling. At deck or wall contact you judge: the fall breaks
  if a press came within 0.25 s before contact and none came 0.25-0.5 s before contact (that one spoils it); presses
  earlier than 0.5 s count for nothing. Emit `broke_fall(kind, dir)` ("stand", "roll" with a held dir, "wall"); MOVE plays
  the stand, the 2.5 m roll or the wall spring (vy +3).
- Missed on the deck: a bounce if falling faster than 6 m/s (vy × −0.3), then lying_t ≥ 0.4 (the first 0.2 s intangible
  through a take_filter), auto-stand at 1.0. `getup(kind)` clears it.
- A hit on a lying body: a set 5 m/s at 20°, a 0.2 s stun, and he stands.

6. Stale moves, guards and returns in % (spec §2.5-2.6).
- The stale queue: each attacker's last 6 landed hits; a volley once; −8% d per copy, at most −40%; returns never queued
  or staled (the Pop's stone IS staled); it survives a fall and clears at the game start. `stale_count(attacker, tag)`
  feeds the strip.
- **Guards as shields:** AIR's BendZone decides perfect or late for every guard against every attack and sends it in the
  info. Perfect: 0% and no launch. Late (`slide_only`): d × 0.5 and launch × 0.5, a slide with no tumble when grounded.
  Earth's full catch: 0%.
- Returns are owned by the returner: ×1.2 and the rally (+0.1, or +0.2 clean, up to ×1.6) on d and growth; no range
  falloff.

7. Patch as fresh damage (spec §8).
- `fresh_pct(b)`: the % he took in the last 6 s. `heal_allowed(b)`: false with an empty pool, while any foe is out
  (respawning), in sudden death, or airborne. `patch(b)`: removes the pool, at most 10%, never below 0; returns it. AIR's
  Patch calls it after its 1.5 s standing-still lock.

8. Lives, KO, respawn, clock (spec §7).
- 3 lives, % to 0 after a fall.
- The KO: touching the water, or **the body's centre crossing the tank curtain's vertical plane at any height** (`is_out`).
  The credit is the last knocker within 6 s, else a self-out.
- `ko(b, by, pct, tag, stocks_left)` and a 1.4 s centre line (*"Into the water: the Tide · 2 left"*, *"Last one"*). No
  round screen per fall.
- The respawn:
  - out 1.6 s (hidden; keep the player's camera valid at the spout); `SwayCaster.drop_all()` clears his locks and stones;
  - the spout on the s = 12 m line at the grate farther from the nearest foe, 3 m up; `RingMoves.ride_spout(pos, 3.0)`
    (MOVE) holds him there until he moves, jumps, presses a cast key or 3 s pass;
  - **safe until 1.5 s after `left_spout`, or the moment any lock of his starts** (`note_lock_started`), through a
    take_filter;
  - **a hit on a safe body:** no %, launch or stun; emit `hit_safe(b, by, point)`; ring_spout.gd plays a hiss and
    splash-through at the point; bend_strip shows "safe" for 0.5 s on the attacker's own strip;
  - the spout pushes bodies within 2 m away at a set 6 m/s with 0%;
  - the look is our own procedural water column (ring_spout.gd); the drip on his body is behind `hud.json
    respawn_drip`, default false.
- No respawn after the last life.
- The clock: **8:00** (time_s 480). At 0:00 more lives wins. Level lives: sudden death at 300% with 1 life each; next
  fall wins; a draw at 60 s. `games` 1, or best of 3 from MatchSetup.games() (BOTS' menu), ends swapped, RoundScreen
  between games only.
- 3v3: 2 lives each, 8:00, three spouts per end, allies add 0% and launch nothing. Keep RingRules per competitor.

9. The stage overlay (spec §5.1-5.2), ring.json `modes.stock`:
- water_y −6, floor_y −9, out_drop_m 6, tank_margin 10, ropes false, deck_w 14
- **the curtain:** a rim channel at deck +3 m spilling a sheet of falling water down to the tank all round (our own
  procedural water; it replaces the grey tank wall in the stock overlay); the splash plays where a body crosses it
- piers under the deck and a stone deck face (grabbable, our own procedural stone)
- **the coping:** a pale stone band 0.25 m wide along all four lips, 4 cm proud with a rounded nose, collider flush with
  the deck; **lanterns** on posts at each corner and the middle of each side, on the piers' heads just outside the lip
  (our own mesh and light, warm at night)
- **the lip's sound:** within 4 m of any lip the water's lapping grows louder on that side, heard by the local player only
  (ring_water.gd)
- the walk and the stands moved out 4 m (ring_dressing.gd and ring_crowd.gd)
- the grates still feed the Geyser bonus
- `nearest_lip`, `lip_y` and `is_out` correct for the overlay; `wall_place_ok(pos)` clamps a wall to at least 3.5 m
  inside every lip
- classic keeps today's numbers. Keep round 1's stepped build and loading screen working (test_ring_assets and the
  hitches test).

10. The HUD (spec §10).
- PercentBar replaces MatchBar under stock (hud.gd's set_arena picks by rule set). Layout A (top corners) by default; B
  is a hud.json switch.
- The ramp, roll-up, pop, shake, throb and fall sequence of §10.2-10.3; the safe glyph and bar; the last-life pulse.
- **Your own plate only:** the fresh-damage band (`fresh_pct`), and three pips (jump, dodge, Rise) read from
  `RingMoves.of(player)` (`jumps_left`, `dodge_ready`, `rise_ready`); a pip dims when spent and refills with a soft tick.
  The foe's plate never shows pips or a band.
- The plates read only RingRules, RingMode and the player's own RingMoves, never any position.
- bend_strip.gd (your own strip): while `RingMoves.of(player).airborne()`, chip 2 shows the element's Slam name (Hammer,
  Downpour, Axe Kick, Down Gust), chip 3 "Dodge", chips 4 and 5 grey with "lands"; chip 3 never takes the readied
  highlight under stock; the move names dim at 2, 4 and 6 stale copies; "safe" for 0.5 s after `hit_safe` by the player.
- The launch wake behind `hud.json launch_wake` (default false): at 18 m/s or more, 0.5 s of the hitter's matter behind
  the body, our own particles. Default instead: a bigger burst at the hit point.
- MatchScreen: the lives, a line per fall (*"1:12 · the Tide into the water at 134% · Boulder"*) and the tally of §10.6
  (with the % healed).
- Every word goes in screens.json and rules.json words; the Rules labels "Lives" and "Zones".

11. Words.
- test_player_words.gd scans every player-facing VALUE (never keys or ids): screens.json, rules.json words, hud.json,
  movement.json words, moves.json labels, lessons.json and practice.json.
- It checks for show words AND Smash names: stock, blast zone, DI, tech, edge-guard, meteor, smash, Final Smash.

TESTS
- Write the PERCENT tests of spec §15: test_ring_pct, test_ring_hitstun, test_ring_stage, test_percent_hud;
  test_ring_rules and test_ring_match rewritten for lives; the classic pin and the open-world gate in test_ring_rules
  (BendKnock still ADDS with the gate off); test_ring_teams for 3v3.
- Key checks: 6 Palms leave kv ≤ 4.5 m/s on the deck; Pull ×6 from 2 m never passes the caster; a volley counts once;
  the range falloff at 10/16/22/30 m; every guard stops every attack in % (16 pairs), Lightning perfect only for fire;
  the escape refused for a buffered press and taken by a fresh press at 0.6; decay on every hit with the Pop exempt;
  the breather; refresh only on a tumbling launch class; the break-fall spoil window; a body thrown over the curtain at
  +6 m is out the frame it crosses; the coping's flush collider; a lock starting ends safety; `hit_safe` fires; Patch
  takes only the last 6 s, at most 10%, and is refused while a foe is out.
- Keep green: test_knock, test_ring, test_ring_hud (its no-cue check), test_ring_screens, test_ring_assets,
  test_ring_dress, test_ring_look, test_player_words, and every round-2 test outside your files.
- The in-engine KO check: a water-weight body at the deck's middle, with no inputs, launched toward an end by a Boulder
  cast from 8 m away (no range falloff): lands in the water at 125% and not at 100%; the same for Spike at 170/145, Punch at 245/215 and Gust ▲ at
  135/115; all within ±10% of lead_table.out (v2). Until MOVE merges, recovery is off in this test; rerun it with recovery
  after MOVE's merge and report both.

REVIEW OUTPUT (prefix r3_percent_):
- stage_before_noon.png / stage_after_noon.png, the same at night, and stage_tank_overview.png (the deep tank, piers,
  deck face, coping, lanterns, curtain, moved stands)
- stage_lip_from_back.png: the player's camera 2 m back from a lip, facing the deck's middle, with a foe hanging at lip
  −3 m behind him: what does he see and hear?
- plates_A.png and plates_B.png at 1280×720 and 1920×1080 (your plate with pips and the fresh band)
- plates_ramp.png (0/40/80/120/180/250%), fall_sequence.png (6 frames)
- spout.png (noon and night), safe_hit.png (the hiss and splash-through)
- wake_off.png and wake_on.png (the same frozen launch), drip_off.png and drip_on.png
- strip_air.png (Slam name, Dodge, "lands"), match_screen.png
- METRIC lines: launch_formula_ok, range_falloff_ok, set_not_add_ok, volley_once_ok, ko_calibration (per class: engine %
  vs lead_table %), hitstun_fair_ok, escape_fresh_press_ok, steer_yaw_only_ok, break_fall_ok, stale_ok,
  string_decay_ok, shield_all_ok, patch_fresh_ok, respawn_ok, sudden_death_ok, classic_pinned_ok,
  open_world_unchanged_ok, plates_no_cue_ok

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
