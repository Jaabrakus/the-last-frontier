# Tidebreak, the % layer: BOTS, HUD and PRACTICE (round 3 design, part "bots")

Design only. Nothing in the project was edited, and Godot and Blender were not run. Read: critic_r2/owner_answers_r3.md
(rules), skills_r2/spec.md + owner_answers.md + round2/{CORE,KITS,HUD_LESSONS,CLIPS}.md, critic_r2/round3_tasks.md
(IMPACT, READ, SHOW, ARC), critic_r1.json, docs/bending_design.md, scripts/npc/npc_bending.gd, npc_fighter.gd,
scripts/bending/bend_knock.gd, scripts/ring/{ring_rules,ring_mode,ring_arena,ring_water,ring_lessons}.gd,
scripts/ui/match_bar.gd, data/npc/bend_ai.json, data/ring/{rules,ring,lessons,screens}.json, the ring tests, and the
review images (r1_merged_play_fight_1.png, r1_merged_learn_card_keys_switch.png).

The owner (2026-10-05): "instead of a knock back we should implement a smash bros 100% plus like arena out system we
should give everyone all movement options and in air options and combos". Chosen: number keys stay, 3 lives, % back to 0
after each fall, full recovery, out only in the water.

---

## 0. The owner's side question: how many moves does each Smash fighter have?

Every fighter in Smash Bros. (Ultimate) has the **same slots**:
- a jab (often a 2-3 hit string, or a rapid jab)
- 3 tilts (forward, up, down) and a dash attack
- 3 smash attacks (forward, up, down)
- **5 aerials** (neutral, forward, back, up, down)
- 4 specials (neutral, side, up, down; the up one is the recovery)
- a grab with a pummel and 4 throws
- a ledge attack and get-up attacks
- one super move

That is about **20 attacks, or about 25 if you count the throws and get-ups**. On top of those comes the same movement and
defence set for everyone: jump, one double jump (a few fighters get more), an air dodge, a spot dodge, two rolls, a
shield, and the ledge options.

Tidebreak's number keys give each element about **11 casts on the ground**: LMB Jab, 1 ×2, 2 ×2, 3 ×2, 4, 5 (×2 for earth
and water), and E Guard. If the attacking keys each get an air version (Jab, Strike ×2, Push ×2 = 5 aerials, the same
count as Smash), an element has **about 16-18 moves**. That is close to a Smash fighter, and the shared movement set comes
on top. The moves and their aerials belong to the MOVES part. Everything below assumes only that aerials exist.

---

## 1. What this part needs from the other parts (the contract)

RULES owns %, lives, launches and the water. MOVEMENT owns jumps, dodges and the edge. MOVES owns the aerials and strings.
This part only READS their state and DRIVES their inputs. If they choose other names, map these to them. The behaviour
must stay as written.

**From RULES (RingRules, or a new RingPercent beside it):**
- `pct_of(b) -> float`
- `lives_of(b) -> int`
- `safe_until(b) -> float` (the respawn and edge safety)
- signals:
  - `pct_changed(b, pct, delta, by)`
  - `fell(b, by, lives_left)` (a fall into the water; `by` is null for a fall with no hit behind it)
  - `respawned(b)`
  - `launched(b, v, hitstun_s)`
- **A PURE static predictor** both sides can call without side effects:
  - `RingRules.launch_of(spec, pct_after, weight, stale_mult) -> {mps, up_deg, hitstun_s}`
  - `RingRules.travel_m(launch, from_pos, flat_dir) -> {m, lands: "deck"|"rope"|"water"}`, with the rope rail and the water
    plane both counted
- `hitstun_left(b)`
- `di_max_deg`

Bots, the practice readout and the soak all call the same predictor, so a bot's KO read is exactly the rule.

**From MOVEMENT (a mover node on any CharacterBody3D in ring % mode):**
- An **intent** it reads every physics frame: `{move: Vector3 (flat, world), jump: bool (just pressed), jump_held, dodge:
  bool, dodge_dir: Vector3, fast_fall: bool, up_recovery: bool, up_dir: Vector3, guard_held: bool, ledge: ""|"climb"|"jump"|
  "roll"|"attack"|"drop", di: Vector3}`.
- Its state:
  - `airborne`, `jumps_left`, `dodge_ready`, `up_ready`, `helpless`
  - `on_ledge`, `ledge_t`, `ledge_safe_left`
  - `can_act()`
- Its numbers (gravity, double-jump speed, drift, air-dodge distance, the up-recovery's reach per element), read from
  MOVEMENT's data file and never copied.

The player's controller fills the intent from the keys. **The bot fills the same intent** (§2). Neither body gets a move or
a number the other lacks.

**From IMPACT (round 3):**
- the game clock (BendStatus.now() in game seconds)
- RingMoment (the slow-motion fall, RingWater.splash)
- the hit-stop

The HUD's fall moment plays inside RingMoment's window.

**A geometry blocker for every part of the layer:** today the deck top is y 0, the water is y −1.4 (ring.json `water_y`),
and `RingArena.is_out` calls a body out 0.6 m below the deck top (`out_drop_m`).
- That leaves about **0.6 m of room under the lip**, so nobody can recover from below the deck.
- A competitor hanging on the edge would have his feet in the water.

The % rules need:
- **out = in the water only** (RingWater.holds)
- the water **well below the deck**: for example water_y −6, so the deck stands as a raised platform on piers, with about
  0.8-1.1 s of fall before the water
- the edge grab on the deck's lip

RULES and ARENA own this. The bots' recovery (§7), the lessons (§17) and their tests assume it. It is owner question 1.

---

## 2. The bot's body: the same mover, through a virtual pad

**Rule: in ring % mode a bot moves ONLY through MOVEMENT's mover, by filling the same intent the player's keys fill, so
every jump, dodge, recovery and edge option it has is the player's own, with the player's numbers.**

- New `scripts/npc/npc_pad.gd` (class NpcPad, RefCounted): the intent dictionary, plus helpers `hold_move(dir)`,
  `tap_jump()`, `dodge(dir)`, `recover_up(dir)`, `ledge(opt)` and `set_di(dir)`. Taps last exactly one physics frame, as a
  key press does.
- `NpcFighter._move`: when `ring_pct` (set by RingMode on its fighters) is on, it hands velocity to the mover with
  `pad.intent` and skips its own walk, gravity and DECEL. `go()` and `face_point()` keep working by writing `pad.move`.
  The open world, the duel and skirmishes keep today's `_move` untouched (gated by the flag; test_duel_bender is unchanged).
- **Gravity parity fix:** today a bot falls at NpcFighter.GRAVITY 18 unless launched (9.8), while the player always falls
  at 9.8. The mover's gravity is the ONE gravity in ring % mode for both bodies.
- `_edge_brake` stays for neutral walking. It is OFF while the mind is in CHASE or RECOVER (§3), so a bot may step off the
  deck on purpose.

**Learn / master:** nothing to learn; the bots simply play by the same rules.

**Risk:** a bot driving its intent by teleporting its velocity would be a cheat. Pin in a test that the bot never writes
`velocity` in % mode, only `pad`.

---

## 3. The bot's mind: states over today's chooser

**Rule: one state at a time, picked each physics tick from what both bodies show. Today's utility chooser (`_choose`)
still picks the cast in NEUTRAL and PRESSURE, with % weights added.**

| State | When | What it does |
|---|---|---|
| NEUTRAL | both on the deck, nobody reeling | today's spacing (`keep_m`) and chooser, plus the KO read (§4), the low-% damage bias, centre-pull at its own high % (§11), and short hops over floor waves (round 2) |
| PRESSURE | its hit just left the foe reeling (`hitstun_left > 0`) | the string table (§5) |
| EDGEGUARD | foe off the deck (feet below the lip, or outside the deck's rect), alive | §9 by preset |
| LEDGETRAP | foe hanging on the edge | §9: wait out his safe time, cover his likeliest option |
| REELING | its own hitstun | DI at the hit, then the escape (§6) |
| RECOVER | itself off the deck, out of hitstun | the planner (§7) |
| LEDGE | itself hanging | §8 |
| RESPAWN | on its respawn platform | §10 |

**Code:** npc_bending.gd gets `state`, `_pick_state()` in `tick()`, and one function per state. `think()` only runs the
chooser in NEUTRAL and PRESSURE. The new numbers live in bend_ai.json's `pct` block (§12).

---

## 4. Reading %: going for the KO

**Rule: before each cast the bot asks the rule's own predictor whether this move, from here, would put the foe in the
water. Easy bots never ask, normal bots ask with a safety margin, and hard bots ask assuming his best steering.**

The KO read for an option `o` against foe `t`:
1. `p = pct_of(t) + o.damage × stale_mult(o)`.
2. `L = RingRules.launch_of(o.spec, p, weight_of(t), stale_mult(o))`.
3. `dir` is the flat direction from the bot to `t`. Columns and Geysers launch straight up (~0 flat travel) and get no KO
   bonus unless the foe stands within 1 m of an open edge.
4. `r = RingRules.travel_m(L, t.pos, dir)`. `kill = r.lands == "water"`.
   - normal requires `r.m ≥ room + ko_margin_m` (1.5 m).
   - hard uses its worst case: the travel with the launch steered by `di_max_deg` toward the nearer safety (a rope or the
     deck), with margin 0.5 m.

**Weights:**
- `kill`: × `ko_bonus` (easy 1.0, normal 2.0, hard 3.5). Among the killing options it prefers the highest
  `(r.m − room) / lock_s`: the surest finisher per second of exposure.
- Foe below `build_pct` (60): × 1.3 on the options with the best damage per lock second (build damage first).
- Normal, with no predictor result (for example a do the predictor doesn't know): a % band, × 1.5 on knock ≥ 8 options
  when `pct_of(t) ≥ 100`.
- **Hard keeps its finisher fresh:** an option whose stale count (RULES' queue) is 2 or more gets × 0.5 while the foe is
  below 80%. The best KO move is saved for the kill.

**Learn:** an average player sees the bot "go for it" with its big move when his own number is red. The colour on his
plate (§13) and the bot's heavy pose agree.

**Master:** at 120% near his end, the player stays centre-deck, baits the bot's finisher with a perfect E guard, or punishes
its long lock. Hard bots punish a player who stands at his end at high %.

**Risk:**
- A bot with perfect KO reads feels psychic. It reads only what the scoreboard and the bodies show: positions and %, never
  the player's inputs or DI before it happens.
- The hard bot's worst-case DI makes it slightly conservative, which is fair.

**Code:** npc_bending.gd `_ko_read(o, t) -> {kill, margin}` and `_choose()` weights. bend_ai.json `pct.ko_bonus`,
`ko_margin_m`, `build_pct` and `fresh_finisher`.

---

## 5. Combos: short strings that a human can escape

**Rule: the bot starts a follow-up only when the rule says the foe will still be reeling when it lands. These are TRUE
strings, escapable only by steering the launch. At most one "read" at the end of a string, which the victim can dodge.
Its length is capped by preset.**

- **True follow-up test:** start `next` at time t0 if `hitstun_left(t) ≥ lock_for(next) + flight_s(next, t) − 1/60`. A
  `next` that needs a jump first (an aerial) adds MOVEMENT's jump-squat time.
- **The read ender:** after a true string of 2 or more, the chance `read_end` (normal 0.3, hard 0.5) to throw one move that
  only lands if the victim does the expected thing (the Kick under a jumper, a Spike at the edge he must grab). Easy never
  reads.
- **Strings in bend_ai.json `pct.strings`, per element.** Each is `{first, next, pct: [lo, hi], air}`. Starting values,
  from the round-2 kits plus aerials; KITS and MOVES retune them by soak:
  - earth: Pebbles → Spike (0-60%) · Column → jump + air Spike (30-100%) · Catch → E return → Shove ▲ (any %; the KO at
    high %; the owner's core, never weakened)
  - water: Splash → Lash (0-70%) · Geyser → air Lash (20-100%) · Lash → Wave ▲ toward his end (KO from 90%)
  - fire: Embers → Punch (0-60%) · High Kick → jump + air Punch (30-90%) · Kick → read: Punch the jumper · Punch held →
    Fireball (KO)
  - air: Palm → Wind Ball (0-80%) · Pull → Palm → Gust ▲ (KO at the edge) · Leap → air Slice
- **Length by preset (hits in a string):** easy 2 (chance 0.25 to follow at all), normal 3 (0.55), hard 4 (0.85). The soak
  gates the longest string at 5 hits for any side.
- **Never a string:** two of the same move back to back. Lock time limits spam, and RULES' staleness shortens a repeat's
  hitstun, so a same-move chain drops by itself.

**Learn:** the player feels "it got me twice". The practice combo counter (§16) shows him what was true.

**Master:** steer the launch out of the second hit (§6), or guard on the beat of the read ender. A hard bot's 4-hit string
at 40-90% is the ceiling for the human to beat.

**Risk:**
- A 0-to-out string (a bot that never lets go) is degenerate. It is capped, needs hitstun ≥ the next lock, and steering
  breaks it.
- 3D: an aerial follow-up must reach a body flying in depth. The bot uses the predictor's landing point, not the chest.

**Code:** npc_bending.gd `_string_next(last_hit) -> option`, the PRESSURE state, and `_on_struck` recording the hit with
the foe's hitstun. bend_ai.json `pct.strings`, `string_max`, `string_chance` and `read_end`.

---

## 6. When the bot is hit: steering, breaking out, breaking the fall

**Rule: a bot is reeled exactly as long as the player would be. It steers its launch at the moment of the hit, as well
as its preset allows. It acts again at the same moment a player could.**

- **Steering the launch (DI)** is chosen ONCE at the hit, as a held key would be:
  - easy: none
  - normal: steers with chance 0.5, the right way 70% of the time
  - hard: chance 0.9, the right way 95% of the time
  - What "the right way" means: at foe-% (its own) of 90 or more, the survival side (the bot runs the predictor at
    −di_max, 0 and +di_max and keeps the longest way to the water; a low launch angled into a rope rail stops it). Below
    90, the combo side: perpendicular to the hitter's facing, away from his follow-up.
- **Breaking out of a long reel** (RULES' cancel: an air dodge or an aerial after cancel_after_s on long launches):
  - easy never
  - normal: 0.5, a dodge toward the deck
  - hard: 0.8, a dodge if the foe is within 5 m and coming, else an aerial at him if it would land, else drift
- **Breaking the fall** (RULES' land or rope tech window, if RULES has one): easy 0, normal 0.3, hard 0.7. The roll
  direction is random among in place, toward the deck and away; hard bots weigh it against the foe's side.
- **Guard (E)** is unchanged from round 2: react_chance per preset, and a perfect chance of 0.1 / 0.3 / 0.6. If RULES makes
  a held guard shrink, the bot guards only against a seen threat, never on idle.

**How hitstun stays fair (the assumptions this part builds on; RULES owns the numbers):**
- Hitstun stops casting, jumping and dodging ONLY. The camera, the aim and the lock UI stay live (the owner's rule: getting
  hit never hurts aim).
- `hitstun_s = hitstun_k × launch_mps` (≈ 0.045 s per m/s: a 10 m/s launch reels 0.45 s, a 25 m/s one 1.1 s), capped.
- Long launches can be broken by an air dodge or an aerial after cancel_after_s (≈ 0.6 s).
- Steering is available from the first frame.
- A repeated move's staleness shortens its hitstun.

The bots obey exactly these, and the soak measures strings (§19), so the claim "every string past 2 hits can be steered
out of" is tested, not hoped.

**Code:** npc_bending.gd `_on_launched(v, hitstun_s)` sets `pad.di`; REELING state; `on_knocked` keeps losing the lock
(round 2 made the player's a setback; check KITS' bot rule). bend_ai.json `pct.di`, `pct.break_out`, `pct.tech`.

---

## 7. The bot's own recovery

**Rule: off the deck and free to act, the bot plans its way back with the player's own resources (double jump, air dodge,
the element's up-recovery, the edge grab), by simulating its own fall a few seconds ahead. It picks the first plan that
reaches the edge or the deck in its preset's order of preference.**

**The planner** (`_plan_recovery()`, each 0.1 s while in RECOVER):
- Forward-simulate (dt 1/30 s, horizon 2.5 s; MOVEMENT's gravity, drift, fast fall off) up to 6 candidate plans:
  1. drift only
  2. drift, then double jump at its latest safe moment
  3. double jump now
  4. drift, double jump, then the up-recovery aimed at the edge grab box
  5. the same, aimed high: 1 m over the lip, onto the deck
  6. an air dodge toward the edge, then the rest
- A plan succeeds if it enters the edge grab box (MOVEMENT's) or lands on the deck before the water. It stays under 1 ms
  a plan (90 steps), only while off the deck.
- Executing a plan means filling the pad: `pad.move = toward the target`, and `tap_jump`, `recover_up(dir)` and
  `dodge(dir)` at the planned ticks. It replans if hit or if the foe comes near.
- **No plan succeeds:** use everything toward the nearest open edge (the desperate line).

**By preset:**

| | easy | normal | hard |
|---|---|---|---|
| order | 3, 4, 2 (spends early) | 2, 4, 6 | 2, then 4 or 5 mixed (low 60%, high 40%), 6 to dodge a threat |
| up-recovery aim error | ±15° (`recover_err_deg`) | ±4° | 0 |
| air dodge used | never | if the foe is within 4 m | to slip a seen threat, or to reach the edge |
| waits for the latest safe moment | no | yes, minus 0.25 s | yes, minus 0.1 s |
| target falls per life, alone (bot vs a standing dummy, 60 s neutral + 12 launches) | ≤ 0.25 | ≤ 0.05 | 0 |

**Learn:** a bot sent off the edge flaps back the way the player will learn to (jump, jump, rise, grab). It teaches by
example.

**Master:** a hard bot mixes high and low and saves its double jump, so edge-guarding it takes a read.

**Risk:**
- Water only 1.4 m down (§1) makes every plan fail. That is the blocker.
- 3D: the bot must recover to the NEAREST open edge, which is not always toward its spawn. The predictor sees the rope
  rail and the tank wall.
- Recovering onto a deck end where the foe stands is a choice: hard goes low to the edge.
- An element whose up-recovery is far better wins on recovery alone. The soak gates the success spread (§19).

**Code:** npc_bending.gd RECOVER state, `_plan_recovery()`, `_sim(plan)`. NpcPad. bend_ai.json `pct.recover`
`{order, err_deg, dodge, late_s, high_share}` by preset.

---

## 8. The bot on the edge

**Rule: hanging on the edge, the bot picks one of the player's edge options (climb, jump, roll in, attack up, or drop and
come back), by preset. It never hangs past MOVEMENT's limit.**
- easy: climb after 0.6 s.
- normal: a random weighted pick (climb 0.4, jump 0.3, roll 0.2, attack 0.1) after 0.2-1.0 s.
- hard reads the foe and the time left:
  - foe within 2 m of the lip: roll in (if the roll lands behind him) or attack up
  - foe 2-5 m: jump, or drop and double jump back to the edge
  - foe farther: climb at once
  - It always acts before its edge safety ends, never after.
- **Adapting (hard, critic item 11):** the bot also counts the player's favourite edge option over the match and covers it
  in LEDGETRAP. These are counts of what was seen, never inputs.

**Code:** npc_bending.gd LEDGE state; bend_ai.json `pct.ledge`.

---

## 9. Edge-guarding: keeping him off the deck

**Rule: when the foe is off the deck the bot tries to keep him there, by preset:**
- easy goes to the deck's middle and waits.
- normal shoots from the deck.
- hard shoots, guards the edge, and chases off the deck only when its own way back is certain.
- **No bot ever hits during a safety the rules give,** and **no bot raises a wall to block the edge.**

| Tactic | easy | normal | hard |
|---|---|---|---|
| chance to edge-guard at all | 0 | 0.5 | 0.85 |
| **Shoot** (ranged moves at the recovering body, from ≥ 1 m inside the lip; the predictor's landing point is the aim, with the preset's scatter × `air_scatter_mult`) | no | yes | yes |
| **Guard the edge** (stand 1.5-2.5 m from the lip facing out; a lock pre-filled to release as his edge safety ends: the click buffer, timed to `ledge_safe_left`) | no | no | yes |
| **Chase** (step or jump off for an aerial) | no | no | only if `_plan_recovery()` from the intercept point succeeds with one jump fewer, and his % is 60 or more |

- **Safety respected:** a hit can never deal anything while the target's `safe_until` runs, so the bot's release is timed to
  land at or after it. A bot that wastes moves into safety is a bug (test).
- **No wall on the edge:** Wall, Ice Wall, Fire Wall and Wind Wall are never placed with their centre within 2 m of an
  open edge while the foe is off the deck. **RULES should forbid any wall within 1 m of an open edge for everyone**, or
  earth walls deny the edge grab: a degenerate tactic for humans too. Flag to RULES/KITS.

**Learn:** the player learns he is vulnerable when off the deck, and that the bot comes after him on hard.

**Master:**
- recover low to the edge
- save the double jump
- dodge the shot
- roll in when the bot guards the edge
- punish a chasing hard bot that went too deep (it won't, by design, but it spends a jump)

**Risk:**
- Ranged elements (water Lash, fire Punch, air Slice) edge-guard better than earth. The soak's edge-out share per element
  (§19) watches it.
- Projectile camping is limited only by lock time (the owner's rule), so a long-lock finisher at the edge is a read, not a
  free kill.

**Code:** npc_bending.gd EDGEGUARD and LEDGETRAP states, `_edge_shot()`, `_edge_chase_safe()`; the wall options get a
`never_near_open_edge_m` check in `_cast_point`. bend_ai.json `pct.edgeguard`.

---

## 10. Respawn

**Rule: after a fall the bot comes back on the same respawn as the player** (RULES: above its end of the deck after a
pause, briefly safe). It **leaves the platform** after 0.5 s (easy), 1.0 s (normal) or, on hard, the full safe time if the
foe stands under it, else at once.
- It **keeps its match memory** (counts, what it has adapted to). Its lock, threats and string are cleared:
  `bending.reset()` as today, plus `state = RESPAWN`.
- The same bot plays the whole match (round 1's rule), so a fall is never a new bot.

---

## 11. Fair against the player and his light aim help

**Rule: a bot sees what a player sees and aims no better at a flying body than a player with the light aim help.**
- **Information:** it reads %, lives, positions, velocities, poses and the foe's lock (his visible wind-up, as today). It
  never reads the player's DI, buffered inputs or the edge option he will pick.
- **Aim at airborne targets:** scatter × `air_scatter_mult` (easy 2.0, normal 1.5, hard 1.2). Gravity-aware lead on a
  falling body only for hard (`air_lead` 0.8; normal 0.5 with straight lead, easy 0.2).
  - Target (tested): a hard bot's hit rate on a scripted recovering player (a fixed jump, jump, rise path from 6 m out) is
    ≤ 0.6. The 15 m standing-shot rates of R1-BALANCE stand (1 in 5, 3 in 5, 9 in 10).
- **Reaction:** every punish of an edge option or a landing waits the preset's `reaction_s` (0.75 / 0.35 / 0.22) after the
  option shows.
- **Centre-pull at its own high %** (hard 1.0, normal 0.5, easy 0): its spacing goal moves toward the deck's middle by
  `centre_pull × clamp((own_pct − 60) / 80, 0, 1) × 4 m`. A good player's habit, and it makes high-% bots harder to finish.
- **Easy is gentle:** no KO read, no strings past 2, no edge-guard, and it may fall in by itself about once in four lives.
  Owner question 4.

---

## 12. bend_ai.json: the new `pct` block (by preset)

| key | easy | normal | hard |
|---|---|---|---|
| ko_bonus | 1.0 | 2.0 | 3.5 |
| ko_margin_m | n/a | 1.5 | 0.5 (with worst-case steering) |
| build_pct | 60 | 60 | 60 |
| fresh_finisher | false | false | true |
| string_chance / string_max / read_end | 0.25 / 2 / 0 | 0.55 / 3 / 0.3 | 0.85 / 4 / 0.5 |
| di chance / right way | 0 / n/a | 0.5 / 0.7 | 0.9 / 0.95 |
| break_out | 0 | 0.5 | 0.8 |
| tech | 0 | 0.3 | 0.7 |
| recover.order | [3,4,2] | [2,4,6] | [2,45,6] |
| recover.err_deg / late_s / high_share | 15 / 0 / 0.5 | 4 / 0.25 / 0.3 | 0 / 0.1 / 0.4 |
| ledge | climb 0.6 s | weighted, 0.2-1.0 s | read |
| edgeguard chance / guard_edge / chase | 0 / no / no | 0.5 / no / no | 0.85 / yes / safe-only, pct ≥ 60 |
| air_scatter_mult / air_lead | 2.0 / 0.2 | 1.5 / 0.5 | 1.2 / 0.8 |
| centre_pull | 0 | 0.5 | 1.0 |
| respawn_leave_s | 0.5 | 1.0 | safe time or at once |

The existing presets (reaction_s, scatter_deg, lead, lock_mult, react_chance, rest_s, grace_s) and the round-2 guard
chances stay. A **Master** preset above hard (critic item 11) is owner question 5. Every number is a starting value; the
soak retunes numbers, never identities.

---

## 13. HUD: the competitor plates (MatchBar's replacement in % rules)

**Rule: each competitor has a fixed plate in a screen corner with his element's glyph, his name, a BIG % and his lives as
small glyphs. Nothing on the screen is attached to, follows, or points at a body.** The owner allows %, lives and the
scoreboard: a scoreboard, not a cue.

- New `scripts/ui/percent_bar.gd` (class PercentBar, a Control). FrontierHUD.set_arena lays it when RULES' rule set is %.
  MatchBar stays for the zones rules if ARC keeps them selectable.
- **Layout A (recommended), 1280×720, scaled by the UI scale:**
  - your plate top-left at (24, 16), theirs top-right, mirrored
  - plate 270 × 84 px: a dark plate (black, 45%) with a 2 px rule in the side colour (critic item 3's side colours)
  - the element glyph 40 px (our own, drawn; not the show's emblems)
  - the name 16 px ("You", or "Stone", "Tide", ... as today)
  - **the % in 46 px bold digits with a 24 px "%"**
  - lives: 3 glyphs of 14 px under the name
  - The clock, when the rules have one, stays top centre (today's Time label). The centre of the screen stays clear (SHOW).
  - **Layout B:** bottom corners flanking the strip, Smash's own place. Owner question 2; render both.
- **3v3 later:** three compact plates a side (150 × 64 px, 32 px %) in a row, the sitting-out competitor dimmed.
- **The event line** (today's, 1.5 s, small, top centre under the clock): "Stone is in the water · 2 left", "You're in the
  water · 1 left", "Last life". The round-2 rule stands: no "Pushed back" banner in the centre.
- **No damage numbers on bodies, ever,** and no plate over the foe's head.

**Learn:** "the bigger my number, the further I fly", read at a glance, top-left, in colour.

**Master:** the player reads both numbers and the position to know when he can finish.

**Risk:**
- Top corners cover the stands only, but the critic's camera variants (READ) may tighten the frame: check the plates
  against each.
- Bottom corners collide with the strip at narrow widths: test at 1280×720 and 1920×1080.

**Code:**
- scripts/ui/percent_bar.gd (new), scripts/ui/hud.gd (set_arena: pick PercentBar or MatchBar)
- data/ring/hud.json (new: layout, colours, shake, words)
- tests/ring/test_percent_hud.gd (new) and test_ring_hud.gd

---

## 14. HUD: the % colour, pop and shake as it rises

**Rule: the % takes its colour from a fixed ramp of five stops. Each hit makes the number pop and shake for a moment, in
proportion to the % the hit added. Above 200 it throbs slowly.**
- **Ramp** (interpolated in OKLab):
  - 0: ink white (0.96, 0.94, 0.88)
  - 40: pale gold (1.0, 0.86, 0.45)
  - 80: orange (1.0, 0.58, 0.2)
  - 120: red (0.92, 0.22, 0.15)
  - 180: deep red (0.55, 0.06, 0.08)
  - Above 200: a brightness throb of 0.8-1.0 at 1.2 Hz.
  - Each stop is checked for contrast on the dark plate (≥ 4.5:1). Deep red gets a 1 px light outline on the digits.
- **The roll:** the shown number counts up to the new value in 0.15 s (ease-out), never down during a string.
- **The pop:** scale 1 → `1 + min(0.05 × delta, 0.45)` → 1 over 0.2 s.
- **The shake:** the digits' offset on the plate, `clamp(1.5 + 0.35 × delta, 2, 12)` px, 30 Hz, decaying over 0.3 s. It is
  the plate's own; the body and the camera are untouched.
- **Healing** (Patch, if KITS keeps it as "% back"): the number rolls down with a short pale-green flash, and no shake.
- The same rules apply to both plates. The player sees the foe's number pop when he lands a hit: good feedback, and still
  not a cue on the body.

**Code:** percent_bar.gd `_on_pct_changed(b, pct, delta, by)`, `_ramp(pct)`, `_tick(dt)`; hud.json `ramp`, `pop`,
`shake`, `throb`.

---

## 15. HUD: the launch and the fall moment, respawn, the last life

**Rule: a fall is told by the water first** (IMPACT's RingMoment: the slow 0.35 time-scale moment and the double splash),
**then by the fallen side's plate.**

The plate's sequence, on the `fell` signal:
- t 0: the plate flashes white for 0.1 s.
- t 0-0.35 s: the % digits rise 20 px and fade.
- t 0-0.5 s: one life glyph cracks and drops out of the row; the row closes up.
- t 1.0 s: "0%" fades in, ink white.

**SHOW's fall sting plays.** On a fall with no hit behind it, the KO is credited as RULES says. The plate shows the same
sequence: there is no shame text.

**Respawn safety is shown in the world, not on the body:** the respawned competitor comes down on his element's own
platform (a stone plinth, a water column, a fire-lit plate, a wind disc rising from the water at his end). The safety ends
when he steps off, casts, or `safe_until` runs out, and then the platform sinks.
- Nothing shimmers on his body. A shimmer would sit at the edge of the no-cue rule; owner question 3.
- His plate shows a small "safe" glyph with a 2 s ring-less bar on the plate, until then.

**The last life:** his plate's single life glyph pulses slowly. The event line says "Last life". The final fall plays
IMPACT's moment longer (match_moment_s 1.0), then the centre word "Over" (or the owner's word), then the match screen.

**A high-% launch** gets no extra HUD. IMPACT's hit-stop and the body's own launch wake (dust, spray: the same class as the
skid, an effect on the air it flew through) tell it. The wake belongs to IMPACT. Owner question 3 covers it with the
shimmer.

**Sudden death** (owner_answers_r3 §6, only if matches still run long):
- both plates read 300% in deep red
- the clock is replaced by "Next one in the water loses"
- MatchScreen says why

**Code:** percent_bar.gd `_on_fell`, `_on_respawned`; ring_mode.gd forwards RULES' signals in the `ring_match` contract
(new: `pct_of`, `lives_of`, `fell`, `respawned`); round_screen.gd and match_screen.gd tallies (§18; SHOW owns their look);
data/ring/hud.json words.

---

## 16. Practice: the % training

**Rule: Practice sets the numbers, picks what the dummy does, counts true strings and shows what each hit did in
numbers, all from the Esc menu's Practice rows. R and B keep their jobs** (an owner call not yet made, so no new keys).

**The settings** (rows in RingMenu's practice section; each kept in GameSettings `practice`):
- **Its %:** 0, 30, 60, 90, 120, 150, 200, or "grows" (normal play). R puts it back to the set value; a fall resets it to
  the set value.
- **Your %:** the same list.
- **It does** (B steps this list, which grows from 3 to 8):
  - stand
  - walk (side to side)
  - jump (a hop every 1.5 s, a double jump every other one)
  - guard: always, after a hit, or on the beat. Its E guard, with the round-2 perfect chance at 1.0 for "on the beat".
  - **recover:** R and every fall puts it off a random open end, 3-7 m out and 0-1.5 m below the lip; it recovers at the
    match difficulty. This is the edge-guard drill.
  - throw (today's: its key-1 first move every 3 s)
  - fight (the bot at its preset)
  - steer: the dummy's launch steering (none / in / out / random), for every way it moves
- **Your recovery drill:** a row "Throw me off" puts the player off an end at a random spot in the recovery drill's range
  when R is pressed.
- **Speed:** 1, ½, ¼. IMPACT's game clock makes Engine.time_scale safe. **RingMoment must restore the practice's speed,
  not 1.0**: a fix to IMPACT's "always 1.0". Practice has no fall moment anyway (feel.json `practice_moment` false).
- **Fresh moves:** staleness on or off (if RULES has staleness).

**The combo counter** (practice only, right side under the lesson card; 32 px):
- "3 hits · 41%" while every hit after the first landed inside the dummy's hitstun (a TRUE string: ink white).
- It turns grey with "free" if the dummy was free for even one frame between two hits; the count then restarts at 1 for
  the next hit.
- It holds for 2 s after the string ends.
- The best string this session is kept under it ("best 4 · 57%").

**The launch readout** (under the counter, 18 px, after each hit): "Launch 9.2 m · reeling 0.55 s · from here, out at 124%".
- The last figure is the % at which the same hit, from the same spot and the same way, would land in the water: a binary
  search over 0-300% on RingRules.travel_m. With no such %: "stays on the deck".
- Numbers, no line drawn on the dummy. A drawn launch line is owner question 3.

**Learn:** set the dummy to 120%, hit it with each move, and read which moves send it out from where. That is how the
average player learns his finishers in five minutes.

**Master:**
- 0% strings until the counter stays white at 3 and 4
- the recover drill on the dummy (edge-guarding)
- "Throw me off" for his own recovery, at ½ speed first

**Code:**
- scripts/ring/ring_practice.gd (new: split the practice code out of ring_mode.gd's 1027 lines: `_practice_step`,
  `dummy_guard`, the new behaviours and the settings)
- scripts/ui/practice_panel.gd (new: the counter and the readout)
- scripts/ring/ring_menu.gd (the rows)
- scripts/ring/match_setup.gd (DUMMIES grows; the dummy % and your % kept)
- data/ring/screens.json `practice` (the ways' words, the readout words)

---

## 17. Lessons for the new rules (rewriting round 1/2's system, not a second one)

**Rule: the lessons stay one card at a time, each done by doing it, with Enter to skip.** Six new cards come after round
2's kit cards, and three "more" cards sit behind the menu's Lessons row as a second run. Lines in data/ring/lessons.json;
new `do`s in ring_lessons.gd; the dummy's % and behaviour set per card (new lesson keys `dummy_pct`, `player_pct`,
`place`). Words are ours: never "stock", "blast zone", "DI", "tech", "edge-guard" or other Smash names, and no show words.

| # | id | line (keys drawn from the bindings) | do | dummy |
|---|---|---|---|---|
| 1 | pct | "Hit the dummy. Every hit raises its number: the higher it is, the further it flies." | `pct`: dummy ≥ 40% | stand, 0% |
| 2 | out | "Its number is red now. Hit it hard toward the water: in the water, it loses a life." | `out`: dummy in the water | stand, 110%, 6 m from its end |
| 3 | jumps | "[jump], then [jump] again in the air: two jumps." | `double_jump` | stand |
| 4 | air_dodge | "In the air, [dodge] with a direction: a quick dash, safe for a moment." | `air_dodge` | stand |
| 5 | back | "You're off the deck. Jump, jump again, then {rise} to rise. Grab the edge." ({rise} is the element's up-recovery from MOVEMENT) | `recovered`: on the deck or hanging | player placed 4 m out, 0.5 m below the lip |
| 6 | edge | "On the edge: [move_forward] climbs, [jump] jumps up, [dodge] rolls in, [fire] strikes up." | `ledge_option` | stand |
| more 1 | string | "Hit it again while it's still reeling: a string of two. The counter goes white." | `string` ≥ 2 true | stand, 20% |
| more 2 | steer | "When you're thrown, hold a direction: you fly a little to that side. Hold toward a rope and stay in." | `steered`: the player's launch steered ≥ half the maximum | throw, player 100% |
| more 3 | keep_off | "Keep it off the deck: hit it while it climbs back." | `out` while the dummy is off the deck | recover, 90% |

The first-match key hints (FirstHints) get one row: "[jump] twice · [dodge] in the air". It fades once each has been used.

**Learn:** the six core cards take about 3 minutes. They teach the number, the water, the two jumps, the dodge, coming back
and the edge, which is all an average player needs for his first match.

**Code:** scripts/ring/ring_lessons.gd (`_on_pct`, `_on_fell`, `_on_mover_event(kind)`: MOVEMENT should emit `moved(kind)`
for double_jump, air_dodge, up_recovery, ledge_grab and ledge_option), data/ring/lessons.json, scripts/ui/first_hints.gd
rows, tests/ring/test_lessons.gd.

---

## 18. The match's tally (for the screens, the soak and the bots' adapting)

Per side, kept by RingMode (`round_tally` becomes `match_tally`):
- falls dealt (KOs) and falls taken, with **self-falls** (no hit within RULES' credit time)
- the % at each fall, and each life's length (s)
- % dealt
- longest true string
- times off the deck after a launch, recoveries (back on the deck or hanging), and the up-recoveries used
- edge falls dealt (the foe went in while recovering)
- guards (perfect, late, whiff; round 2)

The MatchScreen shows four of them: falls, % dealt, longest string, and the highest % survived. Their look is SHOW's.

---

## 19. What the existing tests become

**test_ring_rules.gd (the deck's rules)** → under the % rule set:
- a hit adds its damage to %
- the same hit at 0% and at 120% launches the second ≥ 2.5× farther (RingRules.travel_m) with a longer hitstun
- out only in the water: a body 1 m below the lip but off the water is NOT out
- a fall takes a life, % goes to 0, and the competitor respawns above his end after respawn_s
- a hit during the respawn safety adds no % and no knock
- the third fall ends the match (match_over once)
- a fall is credited to the last hitter within the credit time, else counted as a self-fall
- sudden death (if on) puts both at 300%

The zone, soft-wall, winded and territory checks move under `rules=zones`, if ARC keeps that rule set selectable; else
they are retired with it.

**test_ring_match.gd (a whole match against a bot)**:
- reaches DONE with match_over once and a side at 0 lives
- % never negative; % reset after every fall
- nobody dead
- every why one of fall, self_fall, time, sudden
- METRIC lines: `falls_per_min`, `median_fall_pct`, `median_life_s`, `match_s`, the bot's casts by move and its states'
  time shares (NEUTRAL, EDGEGUARD, RECOVER ...)
- the bot never writes velocity in % mode (§2)

**test_playcheck.gd (from the menu, by the player's own input)**:
- the scripted player also presses Space twice in the air, the dodge in the air, and the up-recovery when the test throws
  him off an end, and comes back
- the match reaches DONE
- the PercentBar shows from the countdown on
- the practice path sets "Its %" to 120 through the menu row, and a hit reads ≥ 120% on the plate

**test_ring_hud.gd** → keeps the arena, bar, strip, keys and words checks, plus:
- the PercentBar is laid in % rules (MatchBar in zones rules)
- both plates read "0%" and 3 lives at the start
- a 12% hit changes the foe's label within 1 frame, the colour follows the ramp at 0/40/80/120/180, and the digits' offset
  is non-zero during the shake and 0 after 0.35 s
- a fall drops one life glyph and shows 0% after respawn
- **no cues:** the bot moved 10 m in 1 s; no CanvasItem moves, shows or hides with it (the plates change only on hits and
  falls; this is pinned by moving the bot with no hits); percent_bar.gd reads no position (no unproject_position, no
  global_position)
- the player's own recovery marks (if kept) exist only on his own side
- the words hold none of the show's words and none of Smash's own names

**test_balance.gd and test_ring_soak.gd (bot against bot)**: the gates change from rounds and ring-outs to lives:
- every match DONE, no SCRIPT ERROR
- no element takes more than 0.65 of the lives it decided against the other elements (was 0.75 of rounds)
- mirrors 0.4-0.6
- median fall % at normal in 80-160
- median life 40-100 s at round time 1
- p90 match ≤ 6 min
- self-falls per life: normal ≤ 0.05, hard 0
- top move share ≤ 0.25 of a side's casts; top finisher ≤ 0.5 of an element's falls dealt
- longest true string ≤ 5, median 2
- recovery success per element within 0.15 of each other
- edge-fall share between 0.15 and 0.5
- printed: the rest of §18 per side

**test_bend_bots.gd** keeps coverage, the lock, the hit and the edge checks, and adds:
- in % mode a bot uses double jump, the air dodge, the up-recovery and the edge in 60 s of the recover drill
- its gravity equals the player's

**test_practice.gd** keeps today's ways, and adds:
- the % rows
- the eight ways
- "Throw me off"
- speed ½ survives a pause and a fall
- the counter counts a true 2-string white and a free gap grey
- the readout's "out at" equals the predictor's

**test_lessons.gd:** each new card is completed by scripted input, skipped by Enter, and resumed.

**New tests:**
- **tests/npc/test_bot_recovery.gd:** each element × preset from 12 fixed off-deck spots (each open end × 3 distances × 2
  heights × with or without the double jump spent), a passive foe. Returns: hard 100%, normal ≥ 95%, easy ≥ 75%. Self-falls
  in 60 s of neutral: 0 at normal and hard.
- **tests/npc/test_bot_pct.gd:**
  - the KO read: the foe at 150% 2 m from his end, the hard bot's next cast is a killing option in ≥ 70% of 20 seeds; at 0%
    in ≤ 20%
  - strings are true: every PRESSURE follow-up began with `hitstun_left ≥ lock + flight`
  - steering: the hard bot's launch is ≥ 10% shorter than the easy bot's from the same hit at 140%
  - the safety is respected: 0 damage dealt into `safe_until`
  - no wall within 2 m of an open edge while the foe is off the deck
  - the hard bot's hit rate on the scripted recovering player is ≤ 0.6
- **tests/ring/test_percent_hud.gd:** §13-15 in detail (the ramp stops, pop and shake numbers, the fall sequence timing,
  layouts A and B at 1280×720 and 1920×1080 without overlapping the strip).

Every new test has a watchdog, seed(1750), `<NAME> PASSED`/`FAILED`, pins MatchSetup._aim_help and isolates
GameSettings.path.

---

## 20. Risks, all in one place

1. **The water is 1.4 m below the deck (§1).** Without moving it, recovery, the edge and three lesson cards cannot exist.
2. **Steering straight up never puts you out** when the water is the only way out. Steering should turn the launch
   sideways only (yaw), or the top would need its own limit. Flag to RULES.
3. **A wall on the edge** denies the edge grab (§9). Flag to RULES/KITS.
4. **3D recovery and the camera:** a player launched back past his own end recovers facing away from the deck, and under
   the lip the deck hides the stage. READ's camera variants should include a pull-back while off the deck. The camera must
   never turn on its own (aim).
5. **The ropes:** low launches stop on the rail, high ones fly over (today's side fall). Bots and the predictor count both.
   Whether the sides stay roped is RULES'/ARC's call.
6. **Bots that feel psychic or cruel:** information and reaction limits (§11), and capped, true-only strings (§5). Easy is
   gentle.
7. **Readability:** the % ramp and pop must be read in peripheral vision. Check the plates against the noon and night
   lighting and the READ camera variants; keep the digits big.
8. **RingMoment's "always restore 1.0"** breaks practice speed (§16): a one-line fix in IMPACT's file, or a hook.
9. **Shared controllers:** NpcFighter is used by the open world and the duel; the pad path is gated by `ring_pct`. The
   player's controller is MOVEMENT's to gate.
10. **Smash's own names in player-facing text** (stock, blast zone, DI, tech, Final Smash): the words test (test_player_words)
    gets them, beside the show's words.

---

## 21. Clips this part needs (our own, keyed in tools/anim_author/blender/bend_clips.py, rows in animations/SOURCE.md)

The movement clips (jump, double jump, air dodge, edge hang, climb, edge jump, edge roll, the up-recoveries) are
MOVEMENT's and CLIPS'. Bots play the same ones through NpcBody. This part needs:
- **tumble**: a loop for a long launch (high %), arms and legs flung, readable as "this one is flying far"; distinct from the
  knocked slide and the round-2 airborne knock clip
- **helpless fall**: a loop after the up-recovery, arms up and open (it tells the edge-guarder "he has nothing left")
- **respawn stand**: per element, on its platform: a calm ready stance with a look down at the deck (4 short loops, or
  one shared clip with element hands)
- **break-fall**: on the floor (a quick roll up) and on a rope (a push-off), if RULES has them
- **edge attack up**: per element (4), if MOVES does not author them
- **victory and defeat poses** per element for the match's end (critic item 13), if SHOW has not taken them

---

## 22. Owner questions (this part's)

1. The deck must stand higher over the water (today the water is 1.4 m down; recovery needs about 5-6 m) and "out" must
   mean touching the water. May the arena change to a raised deck on piers over a deep pool?
2. The % plates: the top corners (recommended: clear of the strip and the deck) or the bottom corners like Smash? Both will
   be rendered for you.
3. Respawn safety and long launches: is the element's platform under the respawned competitor enough (no shimmer on his
   body)? And may a hard-launched body leave a short wake of dust or spray in the air, like the skid on the deck?
4. Easy bots: may they sometimes fall in by themselves (about once in four lives, like a beginner), or never?
5. With edge-guarding and strings, a fourth "Master" bot above hard (it adapts to your favourite edge option and recovery
   route)?
6. In Practice, may a launch line be drawn from the dummy (practice only, never in a match), or numbers only ("Launch 9.2 m
   · out at 124%")?
