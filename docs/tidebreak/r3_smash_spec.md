# Tidebreak round 3: the % layer, the lead designer's merged spec (v2)

Date: 2026-10-05. The owner's ask, word for word: *"instead of a knock back we should implement a smash bros 100% plus like
arena out system we should give everyone all movement options and in air options and combos"*. He then chose: **keep
the number keys**, **3 lives** with the % reset after each fall, and **full recovery** (double jump, air dodge, an
up-recovery per element, grabbing the deck's edge; out only in the water).

v1 (kept as `spec_v1.md`, task files in `round3_v1/`) merged the four part designs: RULES (`launch.md`), MOVEMENT
(`movement.md`), MOVES (`aerials_v1_prev.md`) and BOTS (`bots.md`). Two judges sent it back. **This v2 fixes every
problem they rated 3 or higher**, and most of the 1s and 2s; §20 maps each problem to its fix, or says why not. Where
this file differs from the part designs, **this file rules**.

It sits ON TOP of round 2's kit, which merges before round 3 starts: `skills_r2/spec.md`, overridden by
`skills_r2/owner_answers.md`. The keys are LMB Jab · E Guard · 1 Strike · 2 Push ▲ · 3 Dash · 4 Wall · 5 Heal. **A tap
readies a key's first move and a double tap its second, and right click (RMB) casts the readied move** (hold to aim
while it fills, let go to cast; a click casts as soon as it is ready). Fire's Jab is **Embers**, fire's 1 held grows
into the **Fireball**, and fire's 4 tapped twice is **Breath**.

The numbers were checked with plain-Python scripts in this folder (no Godot), all updated for v2:
- `lead_model.py` → `lead_model.out`: the flight and recovery physics;
- `lead_table.py` → `lead_table.out`: every move's class and KO %;
- `lead_combos.py` → `lead_combos.out`: which strings are true, and the self-loop probes;
- `lead_masher.py` → `lead_masher.out`: a Space-masher against a player who does nothing.

The v1 outputs are kept as `*_v1.*`. Ignore `launch_model2.py`, `launch_refit2.*`, `move_sim.py`, `spec_fit*`,
`spec_sweep.py`, `aerial_calc.*` and `combo_calc.*` (a forked session's scratch).

Owner rules that bind every line below:
- Player-facing text never uses show words (Avatar, bender, bend, bending, pro-bending, Korra, nation names, the show's
  technique names).
- It also avoids Smash's own names: stock, blast zone, DI, tech, edge-guard, meteor, smash, Final Smash. We say "lives",
  "into the water", "steer", "break your fall" and "keep him off".
- No target cues on enemies: no rings, outlines, markers or map dots. Each competitor's own % and lives in the HUD are a
  scoreboard, and that is allowed.
- No painted zone lines, no cel shading, no guns.
- Only our own clips, keyed by hand in `tools/anim_author/blender/bend_clips.py`. Only our own assets.
- Getting hit never slows the player or hurts his aim. Launches and hitstun are the sport; §3 says how hitstun stays fair.
- Lock time is the only spam limiter for casts.
- Earth catching a stone just before it hits and throwing it back is the fun core: never weaken it.

---

## 0. The short version

**The judge.** There is no health in the ring. Every hit adds **%**. The higher your %, the farther and longer the next
hit throws you. You are out only when you **touch the water**: the water under the deck, or the curtain of falling water
round the tank. You have **3 lives**, and your % goes back to 0 after each fall. The last one standing wins. A game is
**8:00**; if the lives are level at the bell, sudden death starts at 300%.

**The stage.** In the % ring the deck stays where it is, but the water drops to **6 m below it**: the deck stands on
piers over a deep tank, 10 m wide on every side, edged by a curtain of falling water. All four sides are open, with no
ropes. The deck's edge is a pale stone coping with lanterns at the corners and mid-sides, so you can read the edge as a
building, not a painted line.

**The controls.** One sentence: **the numbers ready a move and right click casts it; left click, E, 3 and Space act at
once.** Nothing new to bind.

| Idea | Input | The one line the player reads |
|---|---|---|
| Move, run | W/A/S/D, Shift | |
| Ready a move | 1, 2, 4, 5: tap for the first move, tap twice for the second (round 2). **1 is ready at the start and after every fall.** | |
| Cast | RMB: hold to aim while it fills, let go to cast; a click casts as soon as it is ready (round 2) | "Hold right click: aim while it fills, let go to cast." (round 2's line) |
| Jab | LMB, at once | |
| Guard (shield) | E, at once. Tapped: round 2's timed guard. Held: it stays up, 2.5 s at most. In the air too. | "E: on the beat it's yours. Late, half gets through. Hold E to keep it up." |
| Dash, dodge | **3, at once.** On the deck: round 2's Dash (tap twice for your travel move). In the air: an instant air dodge, once per airtime. **3 never changes the readied move.** | "3 dodges: a dash on the deck, a dodge in the air." |
| Jump | Space: always a full jump | "Space jumps." |
| In the air | Space again: the double jump. Once more, **off the deck only**: your **Rise** (then helpless until you land or grab the edge) | "Off the deck: Space, Space, Space. Up, up, and your element lifts you." |
| Short hop (mastery) | Space within 0.05 s of letting go of a cast (LMB or RMB) | Practice's notes only |
| Down | **C** (Ctrl also works): crouch (held) on the deck, fast fall after the top of a jump, held: no edge grab, on the edge: let go | "C is down." |
| Roll, duck | Guard up + tap a direction = Roll; guard up + C = Duck | "Guard up, tap a direction: roll. C: duck." |
| Edge | Fall near the lip and you grab it. **Any direction key climbs**, Space jumps, E rolls in, a click attacks, C lets go. | "Fall off and you grab the edge. W climbs, Space jumps, E rolls in, a click attacks." |
| Break your fall | E just before you hit the deck or a wall while tumbling (add a direction to roll) | "E just as you land: back on your feet." |
| Steer a flight | Hold left or right as you are thrown | "Thrown? Hold left or right: you curve." |
| Attacks in the air | The same keys. They go where you aim. **A lock on 2 started in the air is the Slam**, under you. | "Jump, then right-click with 2 ready: you hit under you." |

**What you can always see about yourself** (your own plate, never his body): your %, your lives, and three small pips
(jump, dodge, Rise) that dim when spent.

**The skill ceiling:**
- strings that grow with %: the jab string and its Pop, launchers, and follow-ups that land while he is still reeling
- the Slam's spike off the edge
- steering your flight, breaking your fall, and the 0.6 s escape
- the edge's options and covering them
- each element's Rise
- short-hop aerials and landing lag
- keeping your finisher fresh, and finishing up close (long shots build %, close hits finish)
- earth's catch and throw-back as a combo tool and a late-match KO threat, never weakened

---

## 1. How the four parts' conflicts were settled (v1, still standing unless §20 says otherwise)

| Topic | The parts said | Decision | Why |
|---|---|---|---|
| Gravity | RULES fitted at 9.8. MOVEMENT wants 20. BOTS: one gravity for player and bots (bots fall at 18 today). | **One ring gravity, 20 m/s², for every body's own falls and every launch** (stock ring only). The class table is refitted at 20. | Snappy jumps, and launches that don't float. One number for everyone. |
| Water depth | All four flag that water 1.4 m down allows no recovery. | **Water 6 m below the deck top (water_y −6), tank margin 10 m (from 6), ropes off.** | A 10 m margin gives the same KO speeds as 12-14 m with less art change. |
| Launch carry decay | RULES: 3.0 m/s². | **8 m/s²** while airborne after a launch (open world keeps 0.8). | At 8 the edge fight matters. |
| Hitstun | RULES 0.05 s per m/s; BOTS 0.045. | **0.045 s per m/s, clamped 0.12-1.2 s.** | Fits the refit's speeds. |
| Air dodge key | MOVEMENT: E in the air. MOVES: 3 in the air. | **3 in the air = air dodge, instant.** E stays the guard everywhere. | 3 is the existing dodge; E keeps one meaning. |
| Up-recovery input | A third Space, or 3 tapped twice in the air. | **Space only,** off the deck only (v2). | The most discoverable rule. |
| Guard | Round 2: hold to raise, let go to stand it. MOVEMENT: stands at fill, held up to 2.5 s. | **The held guard in the % ring**; classic and the open world keep round 2's. | The owner listed "shield (the E Guard)". |
| The Chain (a hit halves your next lock) | MOVES: needed. RULES: never cut lock times. | **Not built.** | Every element has true strings at 0% without it (`lead_combos.out`); lock time stays the only cast limiter. |
| Lock when hit | Round 2: pushed back. RULES: keeps filling. MOVES: frozen. | **Frozen during hitstun (every lock timer), then resumes.** Lightning's charge still breaks. | "Your lock waits while you're thrown." |
| Steering | Read at 0.05 s, 0.1 s, or at the hit. | **Read once, 0.1 s after the hit: up to 15° of yaw, never pitch.** | Humans pre-hold; yaw only, so steering up is never a free save. |
| Breaking the fall | Window 0.25-0.3; lockout 0.6-0.7; lie 0.4-0.6. | **Window 0.25 s; a press 0.25-0.5 s early spoils it (v2); lie at least 0.4 s.** Rolls are **E + a direction** everywhere. | One roll input everywhere. |
| Stale moves | RULES: a 9-move queue. MOVES: −8% a copy among the last 6, floor −40%. | **MOVES' version, on d only.** | Simpler. |
| String limits | ×0.8 per extra hit or launch; a 6th-hit cap. | **×0.8 for every extra hit, set stuns included (v2; the Pop exempt), floor 0.4, counted on the victim; the 6th hit frees him; a 0.4 s breather after a 4+ hit string.** | §6.7. |
| Respawn | A water spout, a stone slab, or the element's platform. | **The water spout, the same for everyone.** | The arena's own water; one look. |
| Sudden death | 300%, then the deck's ends sink. | **300%, one life, next fall wins; a draw after 60 s. No sinking deck.** | The owner retired the closing tide. |
| Earth off the deck | MOVES: smaller stones over the water. | **Not taken.** | Earth recovers worst already. |
| Launch wake, respawn drip | RULES: on. BOTS: owner question. | **Both built behind flags, default OFF** (v2: the drip joins the wake). | Both ride on an enemy's body. |
| HUD place | RULES: bottom. BOTS: top corners. | **Top corners (A) by default; B rendered.** | Keeps the strip clear. |
| Teeter vs the edge guard | | **The teeter**, all four sides. | All sides are open. |
| Element gravity multipliers | MOVEMENT: earth ×1.1, air ×0.85. | **Not taken.** | One gravity. |
| Keys 4 and 5 in the air | MOVES: the lock waits until you land. | **Taken.** | No walls over the water, no healing while falling. |

---

## 2. The % and the launch (stock rules only)

### 2.1 The ledger

- In the stock ring a hit adds **d %** to the struck competitor and never touches his health. There is no cap; the HUD
  shows up to 999.
- **d** comes from the move's class (§2.3). The table is keyed `id/mode`, and `id/mode.grown` for ▲ (and fire's Punch
  held into the Fireball).
- **A volley is one hit** (Pebbles' 3 stones, Embers' 7 sparks): every projectile of the volley carries one `volley_id`.
  Each projectile that lands adds the volley's d ÷ n %; **only the first one applies the knock and the stun** and counts
  in the string and the stale queue.
- Untagged damage (form_spikes, GustLift, anything else) converts by **d = 13 × (1 − e^(−dmg/35))**:
  7 → 2.4, 20 → 5.6, 55 → 10.2, 110 → 12.4.
- **pct_scale** (1.0) multiplies every d. It is the match-length knob.
- Health bars are hidden in the stock ring. Health stays full and untouched, so the open world and the duel are
  unchanged.

### 2.2 The launch

- **v = W × (base + growth × R × A × p/100 × (0.5 + d/20)) m/s**
  - p = the target's % **after** the hit; d = the hit's % after staling; W = the target's weight multiplier (§2.4).
  - **R, the range falloff** (v2): 1.0 when the hit lands 10 m or less from where it was cast, sliding to **0.65 at 22 m**
    and beyond. Long shots build % and shove; finishing happens up close. **Exempt:** returned stones (the fun core) and
    Lightning (its 2.2 s breakable charge is its cost).
  - **A, the air factor** (v2): 0.85 for a launch class released while the caster is airborne; 1.0 otherwise. The Slam
    and returns are exempt.
- **Set knocks** (jabs, the Pop, Pull, the Rise's hits, walls, getup and edge attacks) always launch at their set speed
  and never KO.
- **A knock SETS the motion, it never adds** (v2). In the stock ring a knock sets the carry to its own flat part and the
  vertical speed to its own up part (capped at 16 m/s). Six Palms in a row leave him sliding at one Palm's speed, never
  six. **Pull** sets its speed no higher than √(2 × 6 × distance to the caster), so its slide ends at the caster and
  never carries him past.
- **Direction:** the hit's travel made flat, raised by the class angle.
  - Cones: caster to target.
  - Column, Geyser, the Pop: straight up (80-85°).
  - Pull: toward the caster at 15°.
  - The Slam: −70° (down).
  - Steering (§3.3) turns the yaw only.
- **vy cap** 16 m/s. There is no line in the sky, so straight-up launches come back down. KO classes stay at 65° or
  less.
- **Tumble:** v ≥ **9 m/s**, or an angle of 60° or more, throws the body into the air tumbling. Under that he flinches
  and slides on his feet, still in hitstun.
- **The carry** decays at **8 m/s²** in the air and at GROUND_DECEL 6 on the deck.
- **Off in the stock ring:** knock_scale, element_factor, max_push_m, the ragdoll (ragdoll_mps INF), the zone judging and
  BendKnock's old reaction window (knock_t is replaced by hitstun).
- **Physics** (lead_model.py v2): gravity 20, water 6 m down, the tank's curtain 10 m out, MOVEMENT's recovery with the
  v2 changes (§4.2: a double jump keeps half the launch's carry; §5.4: the Pillar's lean and the scramble). The KO speed
  from the deck's middle toward an open end is about **29-30 m/s at 20-35°**. Toward a long side (7 m) it is 23-24 m/s,
  and from 8 m short of an end 24-25 m/s. With no recovery the end figure is 22-23 m/s, and from 2 m inside a lip
  recovery lifts it from 8 to about 20 m/s: **recovery matters**.

### 2.3 Every move's class (lead_table.py v2)

The bases are RULES' × 1.15; the growths are refitted so the KO % from the deck's middle toward an end (water body, no
steering, cast from 10 m or less, on the deck) meets RULES' targets. "Side" is toward a long side from the middle; "near"
is from 8 m short of an end; "near, 22 m" is the same hit cast from 22 m or more away (R 0.65); "air" is the end figure
released in the air (A 0.85). Earth, air and fire end figures include their weight and their own recovery.

**Jabs (set knocks: they build strings, never KO)**

| Move | d % | set m/s | angle | set hitstun |
|---|---|---|---|---|
| Pebbles (the volley of 3) | 5 | 3.0 | 10° | 0.30 |
| Splash | 4 | 3.5 | 10° | 0.30 |
| Embers (the volley of 7) | 4 | 1.5 | 5° | 0.30 |
| Palm | 3 | 4.5 | 10° | 0.30 |
| **Pop** (the third jab that hits in a string, §6.4) | 3 | 9.0 | 80° | **0.60** |

Per lock second jabs build about 10-16%, a Strike about 30%: a jab never out-damages a Strike.

**Launch classes**

| Move (`id/mode`) | d % | base | growth | angle | KO end | side | near | near, 22 m | air | earth end | air end | fire end | v at 0/60/120% | hitstun at 0/60/120% |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Spike `stone_form/spike` | 14 | 5.8 | 12.2 | 30 | 159% | 121% | 125% | 193% | 188% | 181% | 141% | 158% | 7.8/16.6/25.4 | 0.35/0.75/1.14 |
| Lash `water_whip/whip` | 10 | 4.6 | 11.6 | 25 | 210% | 160% | 166% | 255% | 247% | 237% | 192% | 212% | 5.8/12.7/19.7 | 0.26/0.57/0.89 |
| Punch `fire_blast/punch` | 11 | 4.0 | 10.3 | 25 | 231% | 177% | 183% | 282% | 271% | 259% | 212% | 233% | 5.2/11.7/18.2 | 0.23/0.53/0.82 |
| Slice `air_blast/slice` | 6 | 3.4 | 14.5 | 25 | 220% | 170% | 176% | 271% | 259% | 247% | 202% | 223% | 4.1/11.1/18.0 | 0.18/0.50/0.81 |
| Boulder `stone_form/cannonball` | 22 | 8.0 | 12.1 | 35 | 115% | 83% | 86% | 132% | 135% | 131% | 99% | 114% | 12.3/23.9/35.5 | 0.55/1.07/1.20 |
| Spear `ice/spear` | 16 | 5.2 | 12.2 | 25 | 150% | 113% | 117% | 181% | 176% | 169% | 137% | 151% | 7.7/17.3/26.8 | 0.35/0.78/1.20 |
| Fireball `fire_blast/punch.grown` | 18 | 5.8 | 12.4 | 30 | 134% | 102% | 106% | 163% | 158% | 152% | 119% | 134% | 8.9/19.3/29.8 | 0.40/0.87/1.20 |
| Lightning `fire_arc/lightning` | 25 | 6.9 | 12.1 | 30 | 105% | 78% | 81% | exempt | 124% | 120% | 92% | 104% | 12.2/24.9/37.6 | 0.55/1.12/1.20 |
| Wind Ball `air_blast/ball` | 7 | 8.0 | 18.7 | 35 | 140% | 101% | 105% | 161% | 165% | 159% | 121% | 139% | 9.1/18.6/28.2 | 0.41/0.84/1.20 |
| Shove `earth_shove/push` | 12 | 6.9 | 12.6 | 30 | 160% | 120% | 124% | 191% | 189% | 183% | 141% | 159% | 8.6/16.9/25.2 | 0.39/0.76/1.13 |
| Shove ▲ `earth_shove/push.grown` | 16 | 8.0 | 13.6 | 30 | 120% | 88% | 91% | 140% | 141% | 137% | 104% | 119% | 10.8/21.4/32.0 | 0.49/0.96/1.20 |
| Wave `wave/push` | 9 | 8.0 | 13.5 | 30 | 165% | 121% | 126% | 194% | 194% | 189% | 144% | 164% | 9.2/16.8/24.5 | 0.41/0.76/1.10 |
| Wave ▲ `wave/push.grown` | 12 | 9.2 | 14.5 | 30 | 125% | 90% | 94% | 144% | 147% | 144% | 108% | 124% | 11.1/20.7/30.3 | 0.50/0.93/1.20 |
| Kick `fire_kick/kick` | 12 | 5.8 | 12.7 | 40 | 190% | 137% | 143% | 220% | 224% | 214% | 167% | 188% | 7.5/15.9/24.2 | 0.34/0.71/1.09 |
| Kick ▲ `fire_kick/kick.grown` | 16 | 6.9 | 14.0 | 40 | 140% | 99% | 104% | 159% | 165% | 158% | 122% | 138% | 9.8/20.7/31.7 | 0.44/0.93/1.20 |
| Gust `air_gust/gust` | 5 | 7.5 | 16.5 | 30 | 175% | 129% | 134% | 207% | 206% | 200% | 153% | 174% | 8.1/15.5/23.0 | 0.37/0.70/1.03 |
| Gust ▲ `air_gust/gust.grown` | 7 | 8.6 | 19.3 | 30 | 125% | 91% | 95% | 146% | 147% | 144% | 109% | 124% | 9.7/19.6/29.4 | 0.44/0.88/1.20 |
| Column `earth_shove/column` (launcher) | 11 | 10.3 | 5 | 85 | never | | | | | | | | 10.9/14.0/17.2 | 0.49/0.63/0.77 |
| Geyser `wave/spout` (launcher; growth ×1.33 from a grate or your puddle) | 11 | 10.9 | 5 | 85 | never | | | | | | | | 11.5/14.6/17.8 | 0.52/0.66/0.80 |
| High Kick `fire_kick/high_kick` (launcher) | 10 | 6.9 | 8 | 65 | never in practice | | | | | | | | 7.7/12.5/17.3 | 0.35/0.56/0.78 |
| Surf (contact) `flow/surf` | 7 | 6.9 | 8.8 | 20 | 299% | 219% | | | | | | | 7.4/11.9/16.4 | |
| Breath `fire_breath/breath` | 10 | 3.4 | 9.9 | 20 | 261% | 201% | | | | | | | 4.4/10.3/16.3 | |
| **Caught stone thrown back** (`.return`: Spike's class or the caught move's if higher, ×1.2) | 16.8 | 5.8 | 14.6 | 30 | 119% | 90% | 93% | exempt | exempt | 135% | 105% | 118% | 9.1/20.9/32.6 | 0.41/0.94/1.20 |
| ... at the rally's cap (×1.6) | 22.4 | 5.8 | 19.5 | 30 | 74% | 56% | 58% | exempt | exempt | 84% | 65% | 73% | 12.9/31.9/50.8 | 0.58/1.20/1.20 |
| **The Pop's stone** thrown with E (`rock_jab/pop_stone`; Spike's class, not a return, stales) | 14 | 5.8 | 12.2 | 30 | 159% | 121% | 125% | | | | | | as Spike | as Spike |

**Tags for the classes below** (AIR and MOVE send them in the hit's info):
- the Slams: `earth_shove/slam`, `wave/slam`, `fire_kick/slam`, `air_gust/slam`;
- `jab/pop`, `rock_jab/pop_stone`;
- `rise/pillar`, `rise/fountain`, `rise/jet`, `rise/updraft`;
- `edge/attack`, `getup/attack`.

**Other classes (set or fixed)**
- **Pull** `air_gust/pull`: 4%, set 6 m/s toward the caster at 15° (capped so the slide ends at the caster), set hitstun
  0.40.
- **Fire Wall:** on entry (at most once a second), 4% and a set 5 m/s pop at 50°; then 2% every 0.25 s with **no
  flinch**, so standing in it is never a lock.
- **Wind Wall:** walking in, a set 4 m/s, 0%.
- **The Slam** (§6.2): earth Hammer 12% (6.9 + 7.0), water Downpour 8% (4.6 + 5.0), fire Axe Kick 10% (5.8 + 6.5), air
  Down Gust 6% (5.2 + 5.5), all at −70° with a set 0.30 s hitstun. On a body off the deck it KOs from about **130%** for
  the Hammer, **170%** for the Axe Kick, and 265% or more for the other two (lead_model v2: a −70° spike just off the lip
  is out from 16.9 m/s).
- **The Rise's hits** (§5.4): Pillar 8%, set 9 m/s at 80°; Fountain 3%, set 6 m/s away; Jet trail 5%, set 5 m/s;
  Updraft 2%, set 4 m/s.
- **Edge attack** 7%, set 6 m/s at 20° away from the lip.
- **Getup attack** 5%, set 5 m/s at 20° all round.

**Identity in the numbers:**
- Fire builds the most % per lock second (Embers 16%/s) and has the lowest growth, and recovers second best.
- Air takes the least % and has the most growth; it is light, so it dies earliest (Spike end 141%) but comes back
  from farthest (17.4 m).
- Earth has heavy d and base, is the heaviest body (Spike end 181%), and recovers least far (11.3 m).
- Water is the middle, with Geyser juggles.

**Calibration:** round 1's soaks landed about 9 hits a minute per side. With Patch as fresh-damage only (§8), lives run
about 60-90 s, so a full 3-life game runs 4-7 minutes: the clock is **8:00** (§7.3).

### 2.4 Weight and the passives

- **Weights:** earth 1.25 (W 0.89), water 1.0 (W 1.0), fire 0.95 (W 1.03), air 0.8 (W 1.11), with W = 2/(1 + w).
- **Earth's Rooted:** ×0.85 on **base** only. **Air's Carried wind:** ×1.15 on the whole launch. Both move out of
  knock_scale and into the launch.
- At the element pick: earth *"Heavy: hard to throw out."*; air *"Light: flies far, comes back far."*

### 2.5 Guards and returns in % (v2: every guard is a shield)

- **In the stock ring every guard stops every attack.** The round-2 matrix decides only the **reward**:
  - **Perfect** (a hit within 0.3 s of the guard standing): 0%, no launch. The element's reward fires only in its own
    matrix cell (earth catches and holds stone, water Turns, fire Parries, air bounces back; douse, melt, drop as round 2
    lists them). In a cell where round 2 said "passes", a perfect guard is still 0% and no launch, with no reward.
  - **Late:** half the d and half the launch get through. On the deck the late half is a slide on the feet, never a
    tumble (at high % it can still slide you off the lip).
  - **One exception, Lightning:** only fire's Parry can be perfect against it. Every other guard takes it as late (half,
    a slide). Fire's identity ("the only answer to lightning") stays.
- **Earth catching stone:** a full catch, 0%, **within round 2's 1.0 s window from the moment the guard stands** (a late
  catch inside it is still a full catch, as round 2). A guard held past the window takes a stone as late: half gets
  through, and the stone drops at his feet as a loose stone. The catch is untouched; holding E no longer replaces timing.
- **A returned stone** (caught, then thrown with E) is its own class, owned by the returner:
  - the Spike's class, or the caught move's class if higher, ×1.2 on d and growth;
  - earth's rally adds +0.1 a return (+0.2 off a clean catch), up to ×1.6;
  - returns are **never staled**, never enter the stale queue, and have no range falloff;
  - a return at ×1.6 KOs from the middle at about 74% (the late-match climax; both sides can catch).
- **The Pop's stone** (§6.4) is not a return: the Spike's class, its own tag, staled like any move.

### 2.6 Stale moves (the payoff shrinks, never the cast)

- Each competitor keeps a queue of his **last 6 hits landed on an opponent**. A volley counts as one.
- Each copy of a move already in the queue takes **8% off its d**, up to **40%**. The launch follows through the
  formula.
- Guarded, whiffed and wall hits don't count. Returns are never staled.
- The queue survives a fall and clears at the game's start. Casting is never limited.
- What the player sees: your own strip's move name dims a shade at 2, 4 and 6 copies, and the hit sounds duller.
  Hint after your first fall: *"The same move again and again hits softer: mix them."*

---

## 3. Hitstun, and how it stays fair and escapable

### 3.1 Hitstun

**Hitstun s = clamp(0.045 × v, 0.12, 1.2)**, counted from the hit for the player and the bots alike. The set stuns:

| Set stun | s |
|---|---|
| Jabs | 0.30 |
| Pull | 0.40 |
| The Pop | 0.60 |
| The Slam's spike | 0.30 |
| A Slam bounce on the deck | 0.45 |
| A hit on a lying body | 0.20 |

String decay and the caps (§6.7) shorten them inside a string.

### 3.2 What waits and what is always yours

| While in hitstun | |
|---|---|
| **Always yours** | The mouse (camera yaw and pitch), the aim ray, your lock (frozen, not lost: **every lock timer freezes**, the fill, the sputter and fizzle, ▲'s growth and its self-cast at 1.0 s; it resumes from the same point when hitstun ends; Lightning's charge still breaks), steering the flight (§3.3), and **one buffered press**: a jump, 3, Space's Rise, or a cast release fires on the first free frame. |
| **Waits** | Walking, jumping, dashing and dodging, guarding, releasing a cast, fast fall, the edge grab. |
| **After it** | Full control at once: full air drift, full run, no slow of any kind. |

- **E while tumbling** is only a try at breaking your fall (§3.4). It never fills the buffer and never raises the guard.
- **The 0.6 s escape:** in any hitstun longer than 0.6 s, a **fresh press at 0.6 s or later** of Space (the double jump,
  or off the deck the Rise if the double jump is spent), or 3 (the air dodge), ends it. **The buffered press never fires
  the escape**: a key pressed before 0.6 s waits for hitstun's real end. Hitstun only runs past 0.6 s above 13 m/s,
  which is high %.
- **A tumbling launch refreshes your air moves** (the double jump, the air dodge and the Rise), so every big throw short
  of the water can be fought back from. Set knocks, flinches and the Slam refresh nothing, so a poke on a helpless
  recoverer never saves him.

**You can hear it end** (your own sounds only, heard by you alone): a rushing whoosh plays for as long as you are in
hitstun and cuts out on your first free frame; a short rising tick at 0.6 s says the escape is open.

**Why this is "the sport, not a debuff"** (owner question 1):
- It is short at low % (0.12-0.4 s at 0%), and you can act from 0.6 s at the latest.
- The aim and the camera are never touched; your lock waits; the press you make is kept.
- You steer the flight, can break your fall, and the double jump takes back half the throw's carry.
- Strings end by themselves (§6.7).
- The fallback if the owner disagrees: the player's hitstun ×0.6 with half drift allowed (combos shrink).

### 3.3 Steer your flight

- The movement keys held **0.1 s after the hit** turn the launch's flat direction by up to **15°**, by the part
  **across** the flight. Pitch never changes. The keys are camera-relative.
- **Holding against the flight** (v2) adds 2 m/s² to the carry's decay for the first 0.3 s (about 0.6 m/s less). Holding
  with it does nothing. So the instinct to hold "back toward the deck" counts a little.
- 15° at 15 m/s moves the landing about 3 m.
- Your body leans and twists toward the held side for 0.3 s (your own pose), so steering is felt.
- Bots use the same read, at their preset's chance (§9).
- Hint the first time you are thrown over 10 m/s: *"Thrown? Hold left or right: you curve."* Practice shows
  "steered 12°" in its readout.

### 3.4 Breaking your fall, lying down, getting up

- **Break your fall:** tumbling into the deck or a wall (the deck face, an earth or ice wall, a Column), press **E within
  0.25 s before contact**.
  - **Deck:** you stand at once, intangible for 0.25 s. With a direction held, you **roll 2.5 m** that way in 0.4 s
    (intangible for its first 0.25 s; never off the lip).
  - **Wall:** you stick for 0.1 s, then spring off at vy +3 with your air moves kept.
- **Too early spoils it** (v2): an E press 0.25-0.5 s before contact spoils that contact's break, so mashing loses. A
  press more than 0.5 s before contact does nothing at all, so a newcomer pressing E early while thrown is not punished.
- **Missed, on the deck:** you bounce if falling faster than 6 m/s (vy × −0.3), then lie for **at least 0.4 s**
  (intangible for the first 0.2 s). Then: **W or Space** stands (intangible 0.3 s); **E + a direction** rolls 2.5 m;
  **LMB** is a getup attack (5%, 0.6 s); nothing: you stand by yourself at 1.0 s.
- **Missed, on a wall:** you bounce off at half the flat speed.
- **A hit on a lying body:** a set 5 m/s at 20° and a 0.2 s stun. It stands him up and never knocks him down again.
- **Your own drop shadow** (v2): a soft dark blob under your own body only, on the deck and on the water, so you can judge
  the landing and see whether you are over the deck or the water. Nobody else's body gets one.
- Words: *"E just as you land: back on your feet."* (never "tech").

---

## 4. The movement set (stock ring only; `data/ring/movement.json`; the open world unchanged)

### 4.1 Ring physics

| | |
|---|---|
| Gravity | 20 m/s² for every body, own falls and launches |
| Max fall | 11 m/s (air 8) |
| Run | 5.0 m/s (from 3.6); Shift sprint 6.5; ground accel 40 and decel 30 m/s²; no start/stop clip speed caps in the ring |
| Air drift | earth 3.5 m/s at 12 m/s² · water 4.0 at 16 · fire 4.5 at 20 · air 4.5 at 16 |
| Jump | **Space is always a full jump:** apex 2.0 m (v0 8.94), airtime 0.89 s. A quick tap and a long hold jump the same. |
| Short hop | **Space pressed within 0.05 s of letting go of a cast** (LMB or RMB, either order): vy capped to √(2g(0.8 − h)), apex 0.8 m, airtime 0.57 s. It is the mastery route's own gesture (pre-charge, hop and let go at once), so nobody short-hops by accident. |
| Self-launches | round 2's Step, Jets, Lift and Leap have their up speeds ×1.43 (= √(20/9.8)) in the ring, so their heights stay as today |

**Round 2's floor rule still holds, for every jump:** the Kick's floor wave misses feet more than 0.6 m up; a jump
clears it from 0.07 to 0.82 s after takeoff (a short hop from 0.14 to 0.43 s). *"Fire along the floor? Jump."* is true
for any tap of Space.

### 4.2 Double jump

- One extra jump in the air, refreshed by landing, grabbing the edge or a tumbling launch (§3.2).
- **1.6 m** from where you are (vy SET to 8.0); earth 1.4 m, air 1.9 m.
- **It keeps half the launch's remaining carry** (v2): the body takes over. Your own horizontal speed snaps toward the
  held direction at your air drift; with nothing held you keep 50% of it.
- Allowed mid-lock. Not in hitstun (the 0.6 s escape aside), not while helpless, during an air dodge's travel or in
  landing lag.
- **Why the carry rule** (lead_masher.out): without it, a newcomer mashing Space flew farther than one who did nothing.
  With it, the masher survives 43-55% of a sweep of launches against 36% for doing nothing, every element.
- Flavour on yourself only: earth a stone slab under the feet that crumbles in 0.3 s (no collider); water a splash ring;
  fire a jet burst from both feet; air a gust ring and a whistle.

### 4.3 Fast fall and crouch: C is down

- **The key:** the existing `crouch` action, **C** (shown in every hint) or Ctrl. C is shown because on macOS Ctrl+click
  can arrive as a right click and Ctrl+Space can be taken by the system's input-source switch.
- **Fast fall:** a press of C after the top of a jump (vy ≤ 0.5) sets vy to −17 m/s (earth −18, air −14). It is kept
  until you land, jump or dodge; you need not hold C. It works while helpless, not in hitstun, and it ends the
  Updraft's glide.
- **Holding C** stops edge grabs.
- **Crouch** is held (not a toggle) in the ring: capsule 1.1 m, stationary, aim and cast allowed. Bots aim at the
  capsule's middle.
- **macOS:** while a body has RingMoves, an RMB press event that carries `ctrl_pressed` is read as LMB (the Jab).

### 4.4 The guard as a shield (E)

| | |
|---|---|
| Lock | earth, water, air 0.2 s; fire 0.15 s. The guard **stands when the lock fills** (% ring only). |
| Tapped | It stands for round 2's window (earth 1.0 s, the others 0.8 s). |
| Held | It stays up while E is held, **2.5 s at most**. No meter, no break stun. |
| What it stops | **Everything** (§2.5); the element's reward only in its own cells; Lightning only by fire. |
| Perfect | A hit within 0.3 s of standing. |
| Late | Half the % and half the launch, as a slide on your feet on the deck. |
| Earth vs stone | A full catch within 1.0 s of standing; held past that, a stone is late and drops loose. |
| Whiff | A guard that stood and took nothing makes the next guard's lock 0.5 s if you start it within 1.5 s. |
| While up | No walking; turning and aiming are free. |
| Out of it | Space jumps on the same frame; a **fresh** direction press rolls; C ducks; any cast key drops it in 0.1 s and starts that key's lock. |
| With a stone in hand | E throws it, on the deck and in the air. |
| In the air | E is the same guard (no landing lag from it); earth catches in the air. |

**The tell is the guard's own pose:** round 2's four guard poses, held as loops.

### 4.5 Ground dodges: Roll and Duck (3 stays round 2's Dash)

- **Roll:** guard up (or within 0.1 s of pressing E) plus a **fresh** press of W/A/S/D. Keys already held when E went
  down don't roll.
  - 3.5 m in 0.45 s, camera-relative, facing kept; intangible 0.05-0.30 s; end lag 0.15 s.
  - It stops 0.3 m inside the lip and collides with bodies.
- **Duck:** guard up plus C. 0.45 s in all, intangible 0.04-0.30 s.
- **Repeat cost:** each Roll or Duck within 1.0 s of the last one's end adds 0.1 s of end lag, up to 0.3 s.
- **Intangible** means BendStatus.can_take is false: no hurt, no knock, and bolts fly through without being spent.
- **Nothing glows** on the dodger; only the clip and a short element puff on himself.
- **3 on the deck** is round 2's Dash, now **acting on press** in the stock ring: it goes as soon as its lock fills, but
  not before 0.22 s after the press, so a second tap of 3 inside that time turns it into the key's travel move (Lift,
  Surf, Jets, Leap; round 2's same-key switch, time kept). Direction, element look and "nothing held = back" are round
  2's. It stops 0.3 m inside the lip. **It never changes the readied move**, and it drops a running lock (free before
  its click).

### 4.6 Air dodge: 3 in the air

| | |
|---|---|
| Who | Every element, the same numbers; the element's dash look on yourself. |
| Start | **Instant** (no lock). It drops a running lock (free if before its click). It never changes the readied move. |
| Directional | The held keys, camera-relative and flat: **3.2 m in 0.22 s**, gravity off, vy 0 after. The launch's carry keeps running under it. Intangible 0.04-0.30 s, then 0.28 s with no actions (drift on, no grab). |
| Neutral | Nothing held: keeps 30% of your velocity, gravity on, intangible 0.04-0.40 s, 0.15 s end. |
| Landing lag | 0.3 s if it lands during its travel or end (neutral 0.15 s). |
| Count | **One per airtime;** refreshed by landing, the edge or a tumbling launch. It never leaves you helpless. |

A second tap of 3 does nothing in the air. Lift, Jets and Leap cast from the deck use up that airtime's Rise but don't
leave you helpless. Leap's hold-Space glide is off in the ring.

### 4.7 The teeter

- Running never carries you off the deck. To leave on purpose, hold toward the water for 0.3 s at the lip (a
  lean-and-windmill clip), or jump.
- Rolls and dashes stop 0.3 m inside the lip. Knocks and launches always carry you over.
- It replaces edge_guard_m on all four sides in the stock ring.

### 4.8 The camera (never turned by a hit)

| Where | Camera |
|---|---|
| On the deck (stock ring) | Arm **5.25 m** (from 4.1) and the pivot 0.3 m higher, so about 3 m of deck behind your feet shows at the default pitch |
| Off the deck (feet under the lip, or outside the deck rectangle) | **Pivot = the midpoint between your chest and the nearest lip point.** Arm = clamp(4.1 + 0.6 × body-to-lip distance, 5.25, 8.0) m. FOV 60, or **65** when the body is more than 4 m from the lip. Eases in over 0.35 s, back over 0.5 s after landing. Your body and the lip are both in frame whenever you face the deck. |
| Hanging | Arm 5.0 m, pivot at lip +1.0 m |
| After a respawn | The yaw is set toward the deck's middle and the pitch level. You were out, not hit. |

**The recovery turn** (owner question 2; `movement.json cam.recover_turn`, default on): off the deck, not in hitstun,
when the nearest lip is more than 100° from the view's yaw and the mouse has been still for 0.25 s, the yaw eases toward
the lip at up to 120°/s until the lip is within 60° of the view. **Any mouse motion cancels it at once and for the rest
of that airtime.** Pitch never moves. A hit never starts it (it waits for hitstun's end). It answers the case the
framing can't: a Pull or a cross-up that throws you off facing out to sea.

### 4.9 Mode gating (player.gd is shared with the open world)

- **One gate:** `RingRules.stock_on()`, true while a stock-rules ring match has installed its RingRules.
- **RingMoves:**
  - `RingMoves.install(body)` is called by RingMode for every competitor only then.
  - player.gd gets `var ring_moves = null`, and every new branch is `if ring_moves != null`.
  - `RingMoves.pre(intent, dt)` returns `owned`, as PlayerTraversal.pre does today (player.gd ~1235).
- **One intent for player and bots:** `{move, jump, jump_short, jump_held, dodge, dodge_dir, fast_fall, down_held,
  guard_held, guard_pressed, ledge, di}`. The player's keys fill it (`RingMoves.intent_from_keys()`); bots fill the same
  dictionary through **NpcPad** (§9.1).
- **NpcFighter._move** returns early when RingMoves owns the body; it uses the ring gravity instead of GRAVITY 18 and
  skips its −0.5 floor clamp during its own jumps.
- **PlayerTraversal and PlayerGrip** are not installed in any arena (player.gd ~447-450).
- **SwayCaster** asks `RingMoves.can_cast()`, false when hanging, helpless, dodging, in landing lag, lying or in hitstun.
- **Gate test:** with the gate off, the open world's jump (4.4 at 9.8), crouch toggle, BendKnock (adds its knocks, air
  decel 0.8, ragdoll_mps 9, knock_t) and casting are exactly today's.

---

## 5. The edge, recovery and the KO

### 5.1 The stage (stock overlay in `data/ring/ring.json` `modes.stock`)

- **The deck** stays 34 × 14 m with its top at y 0.
- **The water** sits at **y −6.0** (floor_y −9.0). The deck stands on piers over a deep tank; its face is stone.
- **The tank** margin is **10 m** on every side (from 6). The walk round it and the stands move out 4 m.
- **The tank's edge is a curtain of falling water** (v2): a rim channel at deck +3 m spills a sheet of water down to the
  tank all round. Touching it IS touching water, so the out rule needs no explanation, and from the air it can't be
  mistaken for the deck's stone face.
- **The lip reads as architecture** (v2): a pale stone coping 0.25 m wide along all four lips, 4 cm proud with a rounded
  nose (its collider is flush, so it never trips a slide or a run), and a lantern post at each corner and the middle of
  each side, standing on the piers' heads just outside the lip. Our own procedural stone and our own lantern mesh. It is
  the deck's edge stone, modelled, not a painted line.
- **The water's sound tells you the lip** (v2): within 4 m of any lip the lapping water grows louder on that side, for
  your own ears only.
- **Ropes off:** all four sides are open, giving 96 m of lip. `deck_w` stays a knob: 18 m if the soak shows too many
  side KOs.
- **The grates** still feed the Geyser bonus. Sockets and loose stones are unchanged.
- **The classic rule set** keeps today's ring.json numbers.
- **Images first:** a before/after at noon and at night, and the "from 2 m back, can I see a foe at lip −3 m?" view.

### 5.2 Out

- **KO:** touching the water (feet below water_y anywhere off the deck), **or the body's centre crossing the tank
  curtain's vertical plane at any height** (v2: a launch that would clear the old 3 m wall is out the moment it crosses).
  You are out at once; the splash plays at the curtain or the water.
- There is no top line. Straight-up launches come back to the deck.
- **Credit:** the last knocker within knock_credit_s 6; otherwise it is a self-out. The life is lost either way.
- **Walls** (key 4) can't stand within **3.5 m** of a lip (v2: the edge roll-in's 3.0 m plus 0.5 m): the placement clamps
  inward. No wall can seal a grab spot or push a climber back off.

### 5.3 Grabbing the edge, hanging, and the edge options

**The grab**
- **Grab point:** the head (origin + 1.6 m).
- **Box:** from 0.3 m inside to 0.9 m out from the lip line, and from lip −0.5 to lip +0.6 m high.
- **Automatic when:** airborne and vy ≤ 1.0; not in hitstun and not in an air dodge's travel; C not held; not within
  0.4 s of letting go; a Rise can grab after its startup + 0.2 s.
- **Three grabs, then the deck** (v2): after 3 grabs without touching the deck, the next grab fails (you slide off the
  face). It stops planking out the clock.
- **Snap:** feet at lip −2.0, 0.35 m from the face, the body facing the deck; the camera is not turned; corners slide
  0.5 m along the nearer side.

**Hanging**
- **Intangible 0.6 s** on the first grab since you last stood on the deck; **0 on a regrab**.
- **Hang 4.0 s at most**, then you drop. Settle 0.15 s. A grab refreshes every air move.
- **Hands and head sit 0.4 m over the lip**, so a hanger can be hit once his 0.6 s is over, including by the Kick's
  floor wave running 0.3 m over the lip.
- **Occupancy, no trumping:** a hanger holds 1.2 m of lip on each side, and nobody can grab inside it.

**The options** (v2: **deck-relative**, whatever the camera faces)

| Option | Key | Time | Intangible | Result |
|---|---|---|---|---|
| Climb | **any of W/A/S/D** | 0.5 s | 0-0.35 s | stands 0.6 m in |
| Roll in | E | 0.75 s | 0-0.55 s | ends 3.0 m in |
| Jump | Space | | 0-0.12 s | vy 11.8, feet to about lip +1.5 m, inward drift 2 m/s, air moves kept |
| Edge attack | LMB | 0.6 s | 0-0.30 s | a low sweep 2.0 m in: 7%, set 6 m/s at 20° away |
| Let go | **C only** (or the 4 s limit) | | ends at once | no regrab for 0.4 s |

No direction key ever lets go, so a hanger whose camera looks along the lip or out to sea never drops by pressing
"W climbs".

**Words:** *"Fall off and you grab the edge. W climbs, Space jumps, E rolls in, a click attacks."*

### 5.4 The Rise (up-recovery): Space once the double jump is spent

- **Off the deck only** (v2): your feet outside the deck rectangle, or below the lip by more than 0.3 m. Over the deck a
  third Space does nothing, so nobody makes himself helpless on the deck.
- **A fresh press** (v2): Space released and pressed again at least 0.2 s after the double jump, so a mash spreads the
  two apart instead of cancelling the double jump's height.
- Once per airtime. Afterwards you are **helpless**: drift ×0.6, fast fall and the edge grab only, 0.35 s of landing lag,
  and a loose falling clip that reads apart from the normal fall.
- **Helpless says so** (v2): a press of Space, 3, E or a cast key while helpless plays a short dull "spent" sound on
  yourself; when your last air move goes, a short exhale and a dull puff of your element.
- **The scramble** (v2): a Rise that meets the deck's face (during it, or within 0.1 s after it) with the head no more
  than 2.0 m under the grab box slides up the face to the hang in 0.3 s (its own clip). A slightly low Rise still
  catches the edge.

| Element | Name | Startup (the tell) | Lift | Drift | Its hit |
|---|---|---|---|---|---|
| Earth | **Pillar** | 0.20 s: the water bulges with a deep grind (or the deck face cracks within 1.5 m) | a stone column from the water carries you 5.5 m **leaning 20° toward the nearest lip** in 0.45 s, pushes you off its top (vy 3) and sinks 0.4 s later (never a platform) | 30% | 8%, set 9 m/s up |
| Water | **Fountain** | 0.12 s | 4.5 m up in 0.55 s | full (4 m/s) | 1.2 m wide push away: 3%, set 6 m/s |
| Fire | **Jet** | a 0.25 s hover in place with a roar (punishable) | 7.5 m along the aim in 0.35 s; **aim pitch below +20° is lifted to +20°** | none during it | the trail: 5%, set 5 m/s |
| Air | **Updraft** | 0.05 s | 3.5 m up in 0.45 s, then a helpless glide falling 3 m/s at most until you land, grab or press C | full (4.5 m/s) | a whirl push: 2%, set 4 m/s |

**The tells are tall and loud** (v2): every Rise's startup shows above the lip (the column's top, the water column, the
jet's flame, the whirl) and has its own sound, so a player on the deck hears and sees a recovery coming even when the
body is hidden under the lip.

**Recovery reach** (lead_model.py v2; at rest at deck height, every air move used): earth 11.3 m, water 11.8 m, fire
15.8 m, air 17.4 m. The tank curtain is 10 m out, so every element can come back from anywhere short of it when free;
fire and air pay for their reach with a punishable tell (the hover, the slow glide). The soak gates the spread (§12).

**The Rise's looks:** the column, from FormRaised's kit; the water column, from the Geyser look; the jet trail; a whirl.
All are our own procedural FX, on yourself only.

---

## 6. Aerials and combos

### 6.1 The air rule, key by key

*"In the air your moves go where you aim, and 2 hits under you."*

| Key | In the air |
|---|---|
| LMB | The Jab, along the full 3D aim. |
| 1 (and 1 tapped twice), readied, RMB | The same move along the full 3D aim. Nothing grows in the air: a lock that grew before takeoff stays grown, and fire's Punch doesn't become the Fireball in the air. |
| 2, readied, RMB | **Key 2's form is decided when its lock STARTS** (v2). A lock started in the air is **the Slam** (§6.2); if you land before releasing it, it is called off for free. A lock started on the deck stays the Push (or Push ▲) even if you jump and let go in the air, aimed along the 3D aim. |
| 2 tapped twice, readied, RMB | The same move: Column and Geyser rise from the deck at the aim (never from the tank's water); the High Kick is a crescent along the aim (its own air clip); Pull along the aim. |
| 3 | The air dodge (§4.6), at once. |
| 4, 5 | The lock pauses in the air and goes on from the same fill when you land. Their strip chips grey out with "lands" while you are airborne. |
| E | The guard (the earth catch included); with a stone in hand, E throws it along the 3D aim. |

- For LMB and 1 the form is decided at the release (they are the same move either way; only the pose's legs differ).
- **Locks fill in the air at the moving rate** (v2): round 2's moving_mult by your horizontal speed, exactly as on the
  deck. Fire keeps Footwork (full rate). Hopping is no faster way to charge.
- **Launch classes released in the air** grow ×0.85 (§2.2): KOs come from the deck, the Slam and returns.
- Casting never stops your fall, and 'root: place' is ignored while airborne.
- An **air-legs clip** (lower-body mask) plays under every air cast, so deck and air forms read apart.
- **Earth's air stones** tear from the nearest deck face within 12 m and fly to the hand during the lock (a visible
  rise), with the same numbers. The Hammer holding a stone throws that stone instead.
- **The readied move never changes in the air** except by the number keys: an air dodge, landing, then RMB casts the move
  readied before the jump.

### 6.2 The Slam (a 2 lock started in the air)

- **Space:** a column 2.5 m wide (water 3.2) from your feet to 3 m below you (air 4). Its centre leans up to 1.5 m toward
  the aim's yaw. It is out for 0.12 s at the strike (about 0.1 s after release). It needs no pitch aim.
- **Lock** 0.35 s (fire 0.3).
- **Launch** at −70° with a set 0.30 s hitstun (§2.3). Only its speed grows.
- **On a grounded body:** it **bounces** him up at 0.45 × the down speed + 2 m/s (earth 0.55), with 0.45 s hitstun ×
  string decay, **once per string**. A second Slam on the deck in the same string pushes flat at half launch.
- **Off the deck:** it drives him down toward the water: a read that KOs from about 130% (the Hammer).

| Element | Slam | Its touch |
|---|---|---|
| Earth | **Hammer** | holding a stone, it throws the stone instead |
| Water | **Downpour** | widest; puts out fire; leaves a 6 s puddle (a Geyser source) |
| Fire | **Axe Kick** | on the deck it splits into a 6 m mini floor wave (a safe miss) |
| Air | **Down Gust** | deepest; lifts you 2.5 m/s once per airtime |

**Land lag** 0.30 s (0.15 on a hit). Words: *"Jump, then right-click with 2 ready: you hit under you. On him: he
bounces."*

### 6.3 Landing lag, auto-cancel, short hops

- **A move is "out"** from its release until its strike + 0.15 s (Slam: + 0.2). **A Strike (key 1's moves) is out for
  at least 0.35 s after its release** (v2), so a clean short-hop Strike is a timing skill, not free.
- **Land while it is out** and your feet plant for its landing lag:

  | Move | Landing lag (s) |
  |---|---|
  | Jab | 0.10 |
  | Quick Strike | 0.20 |
  | Big Strike | 0.25 |
  | Lightning | 0.35 |
  | Slam | 0.30 |
  | 2 tapped twice | 0.25 |
  | E | 0 |

  A hit halves it. No walk, jump, dash or guard during it; a lock may fill.
- **Land after the move, or before you let go**, and there is no lag.
- **Short hop (0.57 s airtime):** Space within 0.05 s of a release. A jab lands clean; a Strike released at takeoff lands
  inside its 0.35 s and takes its lag unless released at the very top of a full jump.
- **Mastery:** pre-charge to the click, hop and let go at once (the short hop), fast fall: a safe jab or Slam over a
  floor wave.
- **Feel:** a heavy crouch and thud tell you that you landed in lag.

### 6.4 The jab string and the Pop

- **The step:** a jab that hits makes your **next jab ready 0.15 s after the last one left your hand** (all elements).
  It is decided when the previous jab lands.
- **The Pop:** the **third jab that hits** in a string. 3%, a set 9 m/s at 80°, a **set 0.60 s hitstun** (exempt from
  string decay), an element burst at contact and the caster's rising-hand clip.
  - **Earth's Pop gives you a stone** (v2): its stone fist stays in your hand as a held stone. E throws it (the Pop's
    stone, §2.3). So *"click three times, then E"* works for earth against every element, and the catch-and-throw is in
    every earth game, not only the mirror. If you already hold a stone, the Pop gives no second one.
  - Water: a crest. Fire: a flame column. Air: an updraft.
- **One Pop per string.** A jab that lands after the Pop in the same string stuns only 0.10 s, so jabs never chain past
  it. A miss or a guard resets to step 1.
- Jabs never KO.
- **Words** (the String card, per element):
  - earth: *"Click on him three times: up he goes, and you keep a stone. Then E: throw it."*
  - water, fire, air: *"Click on him three times: up he goes. Then right-click your 1."*

  1 is ready at the start and after every fall, so the line is true from the first second. Mashing LMB finds the Pop
  by accident.

### 6.5 Cancels

| You can always… | |
|---|---|
| jump out of a lock, or guard out of it | |
| start the next lock the moment a cast leaves your hand | the cast's strike still comes out |
| launcher → jump → aerial | |
| air move → air dodge | after its strike |
| air move → landing | free once it is no longer out |
| hitstun → | one buffered press on the first free frame |

There are no other cancels and **no lock is shortened by a hit** (except the jab step, §6.4).

### 6.6 What is true (lead_combos.py v2)

The next lock starts as the first move leaves the hand; the target's carry is counted; a stun over 0.6 s counts only to
0.6 s (he can escape there); water body, no steering.

| String | True from |
|---|---|
| Jab, jab (the step) | every % |
| Jab, jab, Pop → the Pop's stone (E), earth | every % |
| Jab, jab, Pop → Shove (a held or loose stone), earth | every % |
| Jab, jab, Pop → E return (a caught stone in hand), earth | every % |
| Jab, jab, Pop → Lash, water | every % |
| Jab, jab, Pop → Punch, fire | every % |
| Jab, jab, Pop → Slice or Gust, air | every % |
| Pop → Wind Ball, Pop → Spike, Pop → Kick | never (they miss by 0.03, 0.30 and 0.09 s): reads, not strings |
| Column → Pebbles, Column → Shove (stone) | 0% |
| Spike → E return (held stone) | about 25% |
| Geyser → Lash, Geyser → Spear | 0% |
| Lash → Lash | about 60% |
| Kick → Punch, High Kick → Punch, Embers → Punch | 0% |
| Punch → Punch (stales) | about 45% |
| Pull → Palm, Gust → Slice | 0% |
| Pull → Pull | a 2-hit string at most (the decay drops the 3rd) |
| Column → Spike, Lash → Spear/Wave, Spike → Shove, Wind Ball → Gust, Slice → Wind Ball | never: reads, not strings |

**Self-loop probes** (the same move ×12 as fast as the rules allow, 3 m, at 0% and 150%): Embers, Palm, Pebbles and
Splash all stop at 4 true hits (jab, jab, Pop, one 0.10 s jab), then the victim is free for 0.20-0.45 s before every
later hit, enough to jump out (instant) or guard. Pull stops at 2. Punch at 150% runs to the 6th-hit cap, by which time
the first Punch has already sent him toward the water.

### 6.7 Strings end by themselves

- **A string** is every hit on a body that has not had a free frame since the first, by **any** attacker. It is counted
  on the **victim**, so in 3v3 attackers share it.
- **Decay** (v2: every hit): the m-th hit in a string has its hitstun ×0.8^(m−1), floor ×0.4 (1, 0.8, 0.64, 0.51…), set
  stuns included. **The Pop is exempt** (its 0.60 s is the string's designed payoff).
- **After the Pop**, a jab stuns 0.10 s.
- **The 6th hit frees him:** its % and launch are full, but its hitstun is at most 0.10 s.
- **The breather** (v2): when a string of 4 or more hits ends, for 0.4 s any hit stuns at most 0.10 s, so a long string
  can't restart the moment it drops.
- One Pop and one bounce per string.
- Stale moves (§2.6), steering, breaking your fall, the range falloff and % growth carrying him out of reach.
- **Soak gate:** the longest true string is 6 hits or fewer, the median 2.

### 6.8 The catch as a combo tool (the fun core, never weakened)

- Round 2's catch is unchanged: 1.0 s from standing, 3.5 m, a late catch inside the window is a full catch, no slide, the
  return 0.35 s or 0.1 s off a clean catch, and the rally. The held guard adds time after the window, where a stone is
  late and drops loose (§2.5).
- **Pebbles, Pebbles, Pop → E** is true at every % in every matchup (the Pop's stone, or a caught stone already in hand).
- A caught stone deals no %.
- A body in hitstun can't catch, and a held stone stays held through hitstun; once free, E throws it. **A fall drops
  every held stone and clears every lock** (§7.2).
- Air catch, air throw along the aim.
- Mastery: hold a stone to bait and to confirm; catch at the edge and Hammer it down; long rallies set up the late KO.

### 6.9 Bread and butter per element

**The accident string for everyone:** *jab, jab, Pop, then the follow-up the String card names.*

| Element | Accident string (true from 0%) | Expert routes |
|---|---|---|
| Earth | Pebbles ×2, Pop → E (the Pop's stone); or → Shove | Column → Pebbles → Pop → E; hop, Hammer, bounce, Shove ▲; catch at the edge and Hammer it |
| Water | Splash ×2, Pop → Lash (Flowing's 15° steer matches his 15°) | Lash, hop, Downpour, bounce, puddle, Geyser, Lash or Spear |
| Fire | Embers ×2, Pop → Punch; Kick → Punch | High Kick → Punch; Axe Kick wave → Punch; Kick ▲ to finish up close |
| Air | Palm ×2, Pop → Slice or Gust | Slip (Carried wind) → Pull → Palm ×2 → Pop → Gust ▲; Down Gust bounce |

These are the strings `bend_ai.json pct.strings` feeds the bots.

---

## 7. Lives, the KO, the respawn, the clock

### 7.1 Lives

- **3 lives** each. The % goes to 0 after each fall. The last one standing wins.
- **No round screen per fall:** a 1.4 s centre line, then play goes on: *"Into the water: the Tide · 2 left"*, *"Last
  one"*.

### 7.2 Respawn: the water spout

| Step | Time |
|---|---|
| Out (hidden; the camera kept valid at the spout) | 1.6 s of game time |
| On the spout, 3 m above the deck | up to 3.0 s |
| Safe | until 1.5 s after leaving the spout, **or the moment any lock starts** (the guard included), whichever is first |

- **A fall clears every lock and drops every held stone** (v2), so nobody brings a charged finisher back.
- **Where:** a spout rises from the grate on your end's s = 12 m line, on the grate (z ±4) farther from the nearest foe.
  Your camera faces the deck's middle (§4.8).
- **On the spout:** you leave it with any move, jump or cast key, or at 3.0 s. A cast key leaves the spout and starts
  its lock at once, and that lock's start ends your safety, so **no lock can be charged while safe**. The spout pushes
  anyone under it within 2.0 m away (a set 6 m/s, 0%).
- **While safe**, hits pass through with no %, launch or stun. **The attacker knows** (v2): a hit on a safe body plays a
  distinct hiss and splash-through at the hit point (an effect of the hit, not a mark on him), and the attacker's own
  strip says "safe" for 0.5 s. His plate shows the safe glyph and bar (a scoreboard).
- **The look:** our own procedural water column. The wet drip on the respawned body is built behind `hud.json
  respawn_drip`, **default off** (v2: it rides on an enemy's body, like the launch wake).
- You are back in the fight 2.2-6.7 s after the splash. Nobody respawns after the last life.

### 7.3 The clock and sudden death

- **A game** is 3 lives on an **8:00** clock (v2: a close 3-2 game loses 5 lives at 60-90 s each, which 6:00 cut short).
  A match is one game by default; the Esc menu offers best of 3 (to_win 2, ends swapped).
- **At 0:00** more lives wins. If the lives are level: **sudden death**. Both start at **300%** with one life, and the
  next fall wins; a draw after 60 s. Its line: *"Next one in the water loses."*
- **3v3 later:** 2 lives each (6 a side), also 8:00. A side is out when all its competitors are. Allies never add % or
  launch each other. Three spouts per end (z −4, 0, +4).

### 7.4 What replaces the zones in RingRules

- **A rule set picks the judge.** `stock` (the new default) judges %, lives and the water. `classic` (today's zones) stays
  unchanged for one round behind the Esc menu's Rules row, pinned by a test, and is deleted after the owner's look. The
  Rules row reads **"Lives"** and **"Zones"**, never the ids.
- **Off under stock:** confinement, soft walls, advancing, winded, `_refill`, territory, health_frac, knocked_back;
  `forward_limit` returns −INF; the bots' `bounds_fn_for` clamps to the deck's rectangle only; the edge guard (the
  teeter replaces it); knock_scale (the launch replaces it).
- **New signals** (§14.3): `pct_changed`, `launched`, `ko`, `respawned`, `string_ended`, `hit_safe`.

---

## 8. Heal (5) in a % game (v2: fresh damage only)

- **Patch** in the stock ring takes back only **fresh damage**: the % you took in the **last 6 s**, at most 10%, after
  its **1.5 s** lock.
- **It fills only while you stand still** (moving_mult 0 in the stock ring; fire's Footwork does not apply to Patch). A
  hit freezes its lock like any other (§3.2).
- **It can't start** while your fresh pool is empty (its chip greys), while any foe is out (respawning), in sudden death,
  or in the air.
- **Your own plate** shows the fresh pool as a lighter band at the end of your %, shrinking as it ages.
- So Patch is a choice after a string lands, not a ritual: it never undoes a whole life's damage and it is never free
  while the foe respawns.
- **Mend** (earth and water, tap twice) is unchanged.
- Soak gates: `heal_share_of_damage` ≤ 0.15, `heal_pct_per_life` printed.

---

## 9. The bots (aligned to the numbers above)

### 9.1 The body: the same mover, through a virtual pad

- In the stock ring a bot moves **only** by filling the same intent dictionary as the player's keys (NpcPad, §4.9). It
  has exactly the player's jumps, dodges, Rise, edge options and numbers, and one gravity (20).
- Pad taps last one physics frame. `_edge_brake` is off in CHASE and RECOVER.
- **A bot never writes velocity directly** in the stock ring (a test pins it).
- NpcFighter is shared with the open world and the duel, so the pad path is behind the gate.

### 9.2 The mind: states over today's chooser

- **States:** NEUTRAL, PRESSURE, EDGEGUARD, LEDGETRAP, REELING, RECOVER, LEDGE, RESPAWN, picked each tick from what both
  bodies show.
- Today's utility chooser picks casts only in NEUTRAL and PRESSURE.
- A state holds for at least 0.2 s unless a hit lands.
- think_s stays 0.25; the recovery planner re-runs every 0.1 s while off the deck.

### 9.3 Reading % and finishing

- Before each cast, the bot asks `RingPredict.would_ko(tag, foe, from, dir)` (the range falloff and the air factor
  included).

| Preset | Reads the KO? | ko_bonus | ko_margin_m |
|---|---|---|---|
| Easy | never asks | 1.0 | |
| Normal | yes, with a margin | 2.0 | 1.5 |
| Hard | yes, assuming the foe steers his best | 3.5 | 0.5 |

- Below 60%: ×1.3 on the moves with the best % per lock second.
- Finishers want range: a KO-bonus move is ×0.6 when cast from more than 15 m (it walks in first).
- Hard saves a fresh finisher (×0.5 on a KO move with a stale count of 2 or more while the foe is under 80%).
- Up-launchers get no KO bonus.
- A bot reads only %, lives, positions, poses and visible wind-ups, never inputs.

### 9.4 Strings (as attacker)

- A follow-up starts only if `RingRules.hitstun_left(foe) ≥ lock + flight − 1/60` (a true string; `hitstun_left` counts
  the 0.6 s escape); at most one read ends a string; never the same move twice in a row.

| Preset | chance | max hits | read_end |
|---|---|---|---|
| Easy | 0.25 | 2 | 0 |
| Normal | 0.55 | 3 | 0.3 |
| Hard | 0.85 | 4 | 0.5 |

- The string table (`bend_ai.json pct.strings`) is §6.9 plus §6.6's true pairs. The earth bot throws the Pop's stone
  with E.
- Aerials aim at the predicted landing point. Hard bots start the follow-up lock while the first shot flies.

### 9.5 As the victim

| Preset | Steering (chance / right way) | Break out at 0.6 s | Break the fall |
|---|---|---|---|
| Easy | 0 | 0 | 0 |
| Normal | 0.5 / 0.7 | 0.5 | 0.3 |
| Hard | 0.9 / 0.95 | 0.8 | 0.7 |

- At its own % ≥ 90 it steers to survive: of −15°, 0 and +15° it keeps the one with the longest way to the water.
  Below 90 it steers away from the follow-up.
- Round 2's perfect-guard chances (0.1 / 0.3 / 0.6) stand; the held guard is used by normal and hard against a seen
  wind-up (hold until the shot passes, 2.5 s at most).
- Above 120% of its own: reaction +0.15 s, and it keeps 6 m more from an end (centre_pull 0 / 0.5 / 1.0).

### 9.6 Recovery

- Off the deck and free, the bot simulates its fall under 6 plans with `RingMoves.simulate`: dt 1/30, horizon 2.5 s.
  1. drift; 2. a late double jump; 3. double jump now; 4. double jump + Rise to the edge; 5. the same aimed 1 m over the
  lip; 6. air dodge first.
- It runs the first that reaches the grab box or the deck, in its preset's order, toward the **nearest open lip**.

| Preset | Order | Rise aim error | Late margin | Air dodge | Self-falls per life, alone |
|---|---|---|---|---|---|
| Easy | 3, 4, 2 | 15° | 0 | never | ≤ 0.25 |
| Normal | 2, 4, 6 | 4° | 0.25 s | foe within 4 m | ≤ 0.05 |
| Hard | 2, 4 or 5 (mixed low 0.6 / high 0.4), 6 | 0° | 0.1 s | to slip a seen threat | 0 |

### 9.7 The edge, keeping him off, the spout, healing

**On the edge**

| Preset | |
|---|---|
| Easy | climbs after 0.6 s |
| Normal | climb 0.4 / jump 0.3 / roll 0.2 / attack 0.1, after 0.2-1.0 s |
| Hard | within 2 m roll (if it lands behind him) or attack; 2-5 m jump, or drop and double jump; farther, climb at once. It counts the player's favourite edge option and covers it. |

Every bot acts before its intangibility ends, before the 4 s limit, and never grabs a 4th time without touching the deck.

**Keeping him off** (the foe off the deck)

| Preset | Chance | What it does |
|---|---|---|
| Easy | 0 | waits mid-deck |
| Normal | 0.5 | shoots from ≥ 1 m inside the lip at the predicted landing point |
| Hard | 0.85 | shoots, waits at the lip 1.5-2.5 m back with a lock pre-filled to release as his intangibility ends, listens for the Rise's tell, and chases off the deck only if its own plan from the intercept point succeeds with one jump fewer and the foe is at 60%+ |

- No bot hits into a safety.

**The spout:** easy leaves after 0.5 s, normal after 1.0 s; hard waits the full time if the foe stands under it, else
leaves at once. The bot keeps its match memory and clears its threats and string.

**Healing:** a bot Patches only with a fresh pool of 6% or more, standing still, the foe 12 m or more away and not
casting at it (never while the foe is out: the rule forbids it).

### 9.8 Fairness

| | Easy | Normal | Hard |
|---|---|---|---|
| air_scatter_mult | 2.0 | 1.5 | 1.2 |
| air_lead | 0.2 | 0.5 (straight) | 0.8 (gravity-aware) |
| reaction_s (unchanged) | 0.75 | 0.35 | 0.22 |

- Hard hits a scripted recovering player at most 0.6 of the time. Round 1's standing 15 m rates stand.

---

## 10. The HUD (a scoreboard, never a cue on a body)

### 10.1 The plates (PercentBar replaces MatchBar under the stock rules)

**Layout A (default)**, at 1280×720:
- Your plate top-left at (24, 16); theirs top-right, mirrored.
- 270 × 84 px; a dark plate at 45% with a 2 px side-colour rule.
- The element glyph (40 px, our own), the name (16 px), the **% in 46 px bold digits** with a 24 px "%", and 3 life
  glyphs at 14 px.
- **Your plate only** (v2): the fresh-damage band (§8) and **three pips** under your % (jump, dodge, Rise; our own small
  glyphs). A pip dims when spent and refills with a soft tick on landing, a grab or a tumbling launch. Theirs never shows
  pips or a band.
- The clock top-centre. The event line, small for 1.5 s under the clock: *"Stone is in the water · 2 left"*.
- **Layout B** (the bottom corners) is rendered for the owner.
- 3v3: three 150 × 64 plates a side, with 32 px digits.

**The no-cue rule:** the plates change only on hits, falls, heals, your own air moves and the clock, never with anyone's
position. Nothing is attached to, follows or points at a body. There are no damage numbers on bodies.

### 10.2 Colour, pop, shake

| % | Colour (RGB) |
|---|---|
| 0 | ink (0.96, 0.94, 0.88) |
| 40 | gold (1, 0.86, 0.45) |
| 80 | orange (1, 0.58, 0.2) |
| 120 | red (0.92, 0.22, 0.15) |
| 180 | deep red (0.55, 0.06, 0.08), with a 1 px light outline |

- OKLab blend. Above 200 the digits throb at 0.8-1.0 brightness at 1.2 Hz. Contrast ≥ 4.5:1.
- **On a hit:** the digits roll up over 0.15 s, pop (scale 1 + min(0.05 × delta, 0.45) over 0.2 s) and shake
  (clamp(1.5 + 0.35 × delta, 2, 12) px at 30 Hz, decaying over 0.3 s).
- **On a heal:** they roll down with a pale-green flash.
- The body and the camera are never touched.

### 10.3 A fall on the plate

| Time after the fall | |
|---|---|
| 0.1 s | white flash |
| by 0.35 s | the digits rise 20 px and fade |
| by 0.5 s | a life glyph cracks and drops; the row closes up |
| 1.0 s | "0%" fades in |

- **Safe** after a respawn: a small glyph with a 1.5 s bar on the plate. **Last life:** the single glyph pulses. **The
  final fall:** the splash, then the centre word *"Over"*.

### 10.4 The strip says what each key does now

Round 2's strip (bend_strip.gd), your own only:
- While airborne: chip 2 shows your Slam's name (Hammer, Downpour, Axe Kick, Down Gust), chip 3 shows "Dodge", and chips
  4 and 5 grey out with "lands".
- Chip 3 never takes the readied highlight in the stock ring (3 acts at once).
- Your own move names dim at 2, 4 and 6 stale copies (§2.6).
- After a hit on a safe body, "safe" for 0.5 s.

### 10.5 The launch wake and the respawn drip (both default OFF)

A short streak of the hitter's matter behind a body flying at 18 m/s or more for its first 0.5 s, and the respawned
body's drip: **built behind `hud.json launch_wake` and `respawn_drip`, both default OFF.** The default for the wake is a
bigger burst at the hit point only. All of them are rendered for the owner.

### 10.6 Screens

- **MatchScreen:** the lives, a line per fall (*"1:12 · the Tide into the water at 134% · Boulder"*), and the tally:
  falls dealt and taken (self-falls apart), % dealt, longest true string (hits and %), catches and clean catches, perfect
  guards, falls broken, edge saves, the highest % survived, the % healed, and the move that took each life.
- **RoundScreen** shows only between games (best of 3).
- All words live in screens.json and rules.json words, with no show words and no Smash names.

---

## 11. Practice and lessons

### 11.1 Practice (the Esc menu's Practice rows; R and B keep their jobs, no new keys)

| Row or key | Choices |
|---|---|
| **Its %** and **your %** | 0 / 30 / 60 / 90 / 120 / 150 / 200 / grows; R and a fall reset to the set value |
| **The dummy's way** (B steps it) | stand, walk, jump, guard (always / after a hit / on the beat), recover (placed 3-7 m out and 0-1.5 m below the lip), throw (its key-1 first move every 3 s), fight |
| **Its steering** | none / in / out / random |
| **"Throw me off"** | your recovery drill |
| **Speed** | 1, 1/2, 1/4 (Engine.time_scale; the KO moment restores Practice's speed, not 1.0) |
| **Fresh moves** | on / off (stale off) |
| **R** | puts both back and sets both % to the rows' values |

**Practice has no lives and no clock.**

**The string counter** (Practice only): 32 px, top centre, e.g. *"3 hits · 41%"*, held 2 s; white while every hit landed
inside the dummy's hitstun (the 0.6 s escape counted), grey ("free") once the dummy was free between hits; the best kept:
*"best 4 · 57%"*.

**The readout** after each hit (18 px), numbers only: *"Launch 9.2 m · reeling 0.55 s · steered 12° · from here, out at
124%"*, or *"stays on the deck"*. Both use RingRules' `hitstun_left`, `last_steer_deg` and `RingPredict`, the same
functions the bots use. No line is drawn on the dummy. A Practice-only notes line explains the short hop: *"Hop and let
go at once: a low hop."*

### 11.2 Lessons (round 1 and 2's one system: ring_lessons.gd, lessons.json, lesson_card.gd, first_hints.gd)

**Round 2's guard card, rewritten for the stock ring** (v2): *"E: up as soon as it's ready, and it stays while you hold
it. Tap a direction to roll. On the beat, nothing gets through."*

**Six core cards** after round 2's kit and guard cards. Each is done by doing it; Enter skips. About 3 minutes.

| Card | Done when |
|---|---|
| **%** | the dummy reaches ≥ 40%: *"Every hit raises the number. The higher it is, the farther you fly."* |
| **Out** | the dummy at 110%, 6 m from its end, goes into the water: *"Only the water puts you out."* |
| **Jumps** | you double jump: *"Space jumps. Space again in the air."* |
| **Dodge** | you air dodge: *"3 in the air dodges."* |
| **Back** | placed 4 m out and 0.5 m below the lip, you grab the edge or land: *"Look at the deck, then Space, Space, Space."* |
| **Edge** | you use any edge option: *"W climbs, Space jumps, E rolls in, a click attacks."* |

**Three "more" cards**

| Card | Done when |
|---|---|
| **String** | you land ≥ 3 true hits: the per-element lines of §6.4 |
| **Steer** | at 100%, you steer a launch by at least half the maximum: *"Thrown? Hold left or right: you curve."* |
| **Keep him off** | the dummy recovering at 90% goes in: *"Hit him while he climbs back. Not while he's safe."* |

**One hint queue** (v2): at most one hint every 20 s; the edge and recovery hints always win and pre-empt; the
stale-move hint waits until after the first fall. Hints: *"E just as you land: back on your feet"*, *"The same move
again hits softer"*, *"Thrown? Hold left or right: you curve."*
- FirstHints gets one row: *"[Space] twice · [3] in the air"*.
- New lesson keys: `dummy_pct`, `player_pct`, `place`. RingMoves emits `moved(kind)` for the cards to listen to.

---

## 12. Soak targets and knobs

`test_ring_soak.gd` with `rules=stock`: 16 pairings × 3 seeds, time scale 1, normal bots. It prints METRIC lines for:

| Metric | Target |
|---|---|
| median_game_s | 240-420 (4-7 min) |
| timeout_share | ≤ 0.10 |
| timeouts_level (games reaching 0:00 with lives level) | printed; ≤ 0.05 |
| last_life_s (median length of the last life) | printed |
| life_s (median) | 50-90 |
| median_fall_pct | 80-160 |
| self_falls_per_life | ≤ 0.05 (hard 0) |
| water_ko_share | 1.0 (no other way out) |
| ko_by_move | top finisher ≤ 0.5 of an element's falls dealt |
| ko_far_share (KOs from hits cast more than 15 m away) | ≤ 0.3 |
| top_move_share | ≤ 0.25 of a side's casts |
| longest_true_string | ≤ 6; median 2 |
| recover_success per element | within 0.15 of each other |
| edge_fall_share | 0.15-0.5 |
| air_release_share | 0.15-0.35 |
| heal_share_of_damage | ≤ 0.15 |
| heal_pct_per_life | printed |
| element non-mirror win share | 0.40-0.60 each; mirrors near 0.5 |
| helpless_kos, breaks, catches, clean_catches, perfect_guards, grabs_refused (the 3-grab rule) | printed |

**Knobs**, retuned in this order (numbers, never identities): pct_scale, growth_scale, range_far (0.65), decel_air,
hitstun_k, weights, the Rise numbers, deck_w (18 m), time_s.

---

## 13. Clips (our own, keyed by hand in `tools/anim_author/blender/bend_clips.py`)

Every clip:
- is keyed on the rig's rest pose, with its metas (hand, mask, root, hold_s, strike_s, back_s, legs_always as needed)
  and its mirror (-l) where it has a side;
- gets a SOURCE.md row (date, key, "the rig's rest pose; keys in CLIPS"; the provenance column left for the owner) and a
  contact sheet;
- uses Blender only through `blender_run.sh`.

No imported, retargeted or measured reference animation. Real martial arts are a visual reference only.

Until a clip lands, BendPoses passes over a missing name and the stand-in plays. Names are exact; MOVE maps the movement
and knock-state clips in `movement.json clips`, and AIR maps the cast clips in `poses.json`.

**P1: the first playable**
- `own-bend-tumble` (loop; extends own-bend-knock-air)
- `own-bend-flinch` (upper mask, 0.25 s)
- `own-bend-jump-double` (tucked knees-up spring)
- `own-bend-fall` (loop) and `own-bend-fall-fast` (a tucked arrow pose)
- `own-bend-helpless` (loop; arms trailing up, reads apart from the fall)
- `own-bend-air-dodge` (a sharp tucked twist)
- `own-bend-edge-grab`, `own-bend-edge-hang` (loop, hands and head clearly OVER the lip), `own-bend-edge-climb`,
  `own-bend-edge-roll`, `own-bend-edge-jump`, `own-bend-edge-attack`
- `own-bend-roll-f`, `own-bend-roll-b`, `own-bend-roll-side` (+ `-l`), `own-bend-duck`
- `own-bend-air-legs` (lower-body mask under every air cast)
- `own-bend-land-light`, `own-bend-land-heavy`

**P2**
- `own-bend-rise-earth` (crouched on the leaning column, thrown off the top), `own-bend-rise-water`, `own-bend-rise-fire`
  (hover tell, then straight-legged along the burst), `own-bend-rise-air` (spin up, then a glide loop)
- **`own-bend-edge-scramble`** (v2): hands slap the face and haul the body up it to the hang, about 18 f
- `own-bend-tech`, `own-bend-tech-roll` (+ `-l`), `own-bend-tech-wall`
- `own-bend-lie` (loop), `own-bend-getup`, `own-bend-getup-roll` (+ `-l`), `own-bend-getup-attack`
- `own-bend-knock-spiked`, `own-bend-knock-bounce`
- `own-bend-jab-rise` (+ `-l`; the Pop's rising hand, upper mask)
- `own-bend-earth-hammer`, `own-bend-water-downpour`, `own-bend-fire-axe-kick` (+ `-l`), `own-bend-air-down-gust`
- `own-bend-guard-hold-earth/-water/-fire/-air`
- `own-bend-teeter`

**P3**
- `own-bend-spout-ride` (an idle loop and the step-off)
- `own-bend-fire-flip-kick` (+ `-l`; the air High Kick crescent)

The steering lean (§3.3) is an additive bone tilt in code, not a clip. NpcBody plays the same clips from the same state.

---

## 14. Data, code and the contract between tasks

### 14.1 The gate

- **`RingRules.stock_on()`** (static) is true while a stock-rules RingRules is installed. Everything new in the % ring
  checks it, or checks a RingMoves node on the body, which exists only then.
- **The open world, the duel and the classic rule set are unchanged** with the gate off. A gate test pins it (§15).

### 14.2 Data files and their one owner

| File | Owner | New blocks |
|---|---|---|
| `data/ring/rules.json` | PERCENT | `rule_set` ("stock"), `stock {stocks 3, pct_scale 1, curve_k 13, curve_s 35, growth_scale 1, range {full_m 10, far_m 22, far_mult 0.65, exempt [...]}, air_growth 0.85, decel_air 8, hitstun_k 0.045, hitstun_min 0.12, hitstun_max 1.2, tumble_mps 9, vy_cap 16, set_stun {...}, escape_s 0.6, string_decay 0.8, string_floor 0.4, string_cap 6, cap_stun_s 0.1, after_pop_jab_s 0.1, breather {min_hits 4, s 0.4, stun_s 0.1}, di_deg 15, di_read_s 0.1, di_against_decel 2, di_against_s 0.3, tech_s 0.25, tech_spoil_s 0.5, tech_roll_m 2.5, lie_s 0.4, lie_auto_s 1.0, late_mult 0.5, return_mult 1.2, rally {step 0.1, clean 0.2, max 1.6}, stale {n 6, step 0.08, max 0.4}, weights {...}, classes {...}, patch {fresh_s 6, max_pct 10, lock_s 1.5}, respawn {out_wait_s 1.6, spout_s 3.0, safe_after_s 1.5, spout_up_m 3.0, clear_m 2.0, clear_mps 6}, knock_credit_s 6, time_s 480, games 1, sudden {pct 300, draw_s 60}, team {stocks 2, time_s 480}, words {...}}` |
| `data/ring/ring.json` | PERCENT | `modes.stock {water_y −6, floor_y −9, out_drop_m 6, tank_margin 10, curtain_up_m 3, ropes false, deck_w 14, coping {w 0.25, proud 0.04}, lanterns, wall_lip_clear_m 3.5}` |
| `data/ring/hud.json` (new) | PERCENT | layout A/B, ramp, pop, shake, throb, pips, fresh band, launch_wake (false), respawn_drip (false), fall sequence |
| `data/ring/screens.json` | PERCENT | KO line, the match screen's per-fall line and tally words, "Lives"/"Zones" |
| `data/ring/movement.json` (new) | MOVE | physics, jumps (hop-cast window 0.05), double jump (carry keep 0.5), drift, fast fall, guard roll/duck, air dodge, teeter, edge (deck-relative keys, grab limit 3), the Rise per element (only off the deck, re-press 0.2 s, Pillar lean 20°, Jet pitch floor 20°, scramble 2.0 m), camera (deck, off-deck, hang, recover_turn), sounds on yourself, clips |
| `data/sway/moves.json`, `data/bending/poses.json`, `data/bending/schemes.json` | AIR | `air` block on key 2's first-move specs (the Slam), the `pop` look and earth's pop stone, the landing-lag table and the Strike's 0.35 s out window, the jab step, walls' 3.5 m lip clearance, Patch's stock lock (1.5 s, moving_mult 0), key 3's stock press rule (min 0.22 s); cast clips in poses.json |
| `data/npc/bend_ai.json` | BOTS | `pct {ko_bonus, ko_margin_m, far_finisher_mult, build_pct, fresh_finisher, strings, string_max, string_chance, read_end, di, break_out, tech, recover {order, err_deg, dodge, late_s, high_share}, ledge, edgeguard, air_scatter_mult, air_lead, centre_pull, spout_leave_s, heal {min_fresh, min_dist_m}}` |
| `data/ring/lessons.json`, `data/ring/practice.json` | BOTS | the cards, the stock guard card, the hint queue, Practice rows and words |

### 14.3 The APIs (stubbed by SEAMS, filled by each owner)

**RingRules** (PERCENT, `scripts/ring/ring_rules.gd`)
- static: `stock_on() -> bool`, `class_of(tag) -> Dictionary {d, base, growth, angle, set, set_stun}`,
  `launch_v(cls, pct_after, d, W, range_m := 0.0, air := false) -> float`, `range_mult(tag, range_m) -> float`,
  `weight_of(element) -> float`
- per competitor: `pct_of(b)`, `stocks_of(b)`, `safe_until(b)`, `hitstun_left(b)` (time until he can act, the 0.6 s
  escape counted), `stunned(b)`, `can_escape(b)`, `string_hits(b)`, `stale_count(attacker, tag)`, `last_steer_deg(b)`,
  `fresh_pct(b)`, `heal_allowed(b) -> bool`
- `add_pct(b, delta, by, tag)`, `reset_pct(b, to := 0.0)`, `patch(b) -> float` (takes the fresh pool, at most 10%;
  returns the % removed)
- `on_hit(n, by, info) -> Dictionary` (returns the launch to apply; called from BendStatus)
- `note_lock_started(b)` (ends safety; called by AIR's SwayCaster through its `lock_started` signal, which RingRules
  connects)
- signals: `pct_changed(b, pct, delta)`, `launched(b, v: Vector3, hitstun_s, by, tag)`,
  `ko(b, by, pct, tag, stocks_left)`, `respawned(b)`, `string_ended(by, victim, hits, pct)`,
  `hit_safe(b, by, point: Vector3)`

**Hit info keys** (AIR fills them; PERCENT reads them): `tag`, `from` (the cast's origin, for the range), `air`
(released airborne), `volley_id`, `volley_n`, `set_stun`, `slide_only` (a late guard), `bounce_once` (a Slam on the
deck), `returned`, `ret_mult`, `origin_tag` (the caught move's tag).

**BendKnock** (PERCENT, `scripts/bending/bend_knock.gd`)
- `static var gravity_override := 0.0` (0 = as today)
- `var stun_t`, `var tumble`, `var lying_t`
- `func apply_di(dir: Vector3)`, `func press_break(dir: Vector3)` (an E press while tumbling; judged at contact),
  `func getup(kind: String)`, `func scale_carry(k: float)` (MOVE's double jump calls it with 0.5)
- `knock(n, v, by, info := {})`: under stock it SETS the motion (§2.2)
- signals `launched(v, hitstun_s, refresh: bool)` (refresh: a tumbling launch class, §3.2; MOVE refreshes the air moves
  only then), `broke_fall(kind: String, dir: Vector3)` (kind "stand", "roll", "wall")

**BendStatus** (PERCENT, `scripts/bending/bend_status.gd`)
- `static var take_filters: Array[Callable]` (can_take is false if any returns false)
- `knock(n, v, by, info := {})` passes info through

**RingArena** (PERCENT)
- `nearest_lip(pos) -> {point, normal, out_m, side, along}`, `lip_y()`, `spout_at(side, slot)`, `is_out(pos)` (the
  stock overlay, the curtain plane at any height), `wall_place_ok(pos) -> Vector3` (clamped 3.5 m inside)

**RingMoves** (MOVE, `scripts/ring/ring_moves.gd`, a Node child named "RingMoves")
- `static install(body)`, `static of(body)`
- `pre(intent, dt) -> bool`, `intent_from_keys() -> Dictionary`, `profile() -> Dictionary` (includes `self_up_mult`)
- `can_cast()`, `airborne()`, `off_deck()`, `helpless()`, `on_ledge()`, `on_spout()`, `intangible()`,
  `in_landing_lag()`
- `jumps_left`, `dodge_ready`, `rise_ready`, `ledge_safe_left()`
- `dodge(dir)`, `land_lag(s)`, `ride_spout(pos, max_s)` (signal `left_spout`), `leave_spout()`, `cam_bias() ->
  Dictionary`
- `static simulate(state, plan, dt, horizon) -> Dictionary`
- `signal moved(kind)` (jump, double_jump, dodge, rise, grab, climb, ledge_jump, ledge_roll, ledge_attack, break_fall,
  roll, duck, scramble)

**RingPredict** (MOVE, `scripts/ring/ring_predict.gd`, pure static; mirrors lead_model.py v2)
- `flight(v: Vector3, hitstun_s, from: Vector3, element) -> {lands: "deck"|"edge"|"water", travel_m, t}`
- `would_ko(tag, target, from, dir, range_m := 0.0, air := false) -> bool`
- `ko_pct(tag, target, from, dir, range_m := 0.0, air := false) -> float` (a binary search 0-300 over
  `RingRules.launch_v`)

**NpcPad** (MOVE, `scripts/npc/npc_pad.gd`): the intent the bot fills (`press(key)`, `hold(key, on)`, `move`, `di`,
`intent()`).

**SwayCaster** (AIR)
- reads `RingMoves.can_cast()` and `RingRules.hitstun_left()`
- `func guard_up() -> bool`
- `func ready_default()` (readies key 1's first move; PERCENT's RingMode calls it at the countdown and on every respawn)
- `func drop_all()` (drops every lock and held stone; PERCENT's RingMode calls it on a fall)
- signals `air_cast(m, mode)`, `lock_started(m, mode)`, `cast_released(m, mode)`

**MatchSetup** (BOTS): `rule_set()`, `games()`, `practice_pct()`. **RingPractice** (BOTS): `reset()`, `step(dt)`,
`set_way(way)`, `paint()`. **NpcBending** (BOTS): `set_practice_way(way)`.

---

## 15. Tests (every new test has a watchdog, seed(1750), a last line `<NAME> PASSED`/`FAILED`, exit 0 only on a pass, `MatchSetup._aim_help` pinned and `GameSettings.path` isolated)

**PERCENT**
- `test_ring_pct.gd` (new):
  - `launch_v` matches the formula for 10 classes at 0/60/120% within 0.01 m/s; the range falloff at 10/16/22/30 m
    (1.0/0.825/0.65/0.65); returns and Lightning exempt; the air factor 0.85 (the Slam and returns exempt);
  - the curve maps 7/20/55/110 damage to 2.4/5.6/10.2/12.4%; pct_scale scales every d; a stock hit leaves health
    unchanged;
  - a volley: 7 Embers landing give 4% in all, one knock, one string hit, one stale entry; 3 of 7 landing give 4 × 3/7;
  - weights ×0.89/×1.11; Rooted on base only; Carried wind on all;
  - stale −8% a copy, floor −40%, returns never staled, the queue survives a fall;
  - **every guard stops every attack in the stock ring** (16 element pairs: perfect 0%, late half as a slide); Lightning
    perfect only for fire; earth's catch full within 1.0 s of standing and late (half, the stone dropped loose) after;
    returns ×1.2 owned by the guarder, the rally capped at ×1.6; the Pop's stone is Spike's class and stales;
  - Patch: takes the last 6 s of % (at most 10%), refused with an empty pool, while a foe is out, in sudden death and in
    the air.
- `test_ring_hitstun.gd` (new):
  - hitstun = clamp(0.045 v); the set stuns;
  - **knocks set, never add:** 6 Palms at 0.25 s spacing leave kv ≤ 4.5 m/s and the body on the deck; Pull ×6 from 2 m
    never carries him past the caster;
  - during hitstun the camera basis, aim ray and lock fill are identical to a run with no hit;
  - `hitstun_left` counts the escape; the escape refused at 0.55, refused for a press made at 0.4, taken by a fresh press
    at 0.6;
  - steering at 0.1 s turns yaw 15° (pitch unchanged); holding against the flight removes 0.6 ± 0.05 m/s; for the player
    and a bot; `last_steer_deg` reports it;
  - decay on every hit (1, 0.8, 0.64…, floor 0.4), the Pop exempt, a jab after the Pop 0.10 s, the 6th hit ≤ 0.10 s, the
    0.4 s breather after a 4-hit string, counted on the victim with two attackers;
  - a tumbling launch refreshes the air moves; a jab, a flinch and the Slam don't;
  - breaking the fall: E 0.2 s before contact stands, with D rolls 2.5 m; E 0.4 s before spoils it; E 0.8 s before and
    again 0.1 s before stands; a missed fall lies ≥ 0.4 s; a hit on a lying body gives a set 5 m/s, 0.2 s and stands him;
  - a tumble begins at 9 m/s or 60°.
- `test_ring_stage.gd` (new):
  - the stock overlay: water at −6, out on touching the water; **a body thrown over the curtain at +6 m is out the frame
    it crosses**; nothing out at lip −0.6;
  - nearest_lip on all four sides and the corners; the coping's collider is flush (a slide crosses it unchanged);
  - ropes absent in stock and present in classic; walls clamp 3.5 m inside the lip.
- `test_ring_rules.gd` and `test_ring_match.gd`:
  - three lives, % to 0 after a fall, the respawn on the spout (hidden 1.6 s, the grate farther from the foe); **a fall
    clears the locks and drops the stones; a cast key on the spout leaves it and its lock's start ends the safety; no %
    on a safe body and `hit_safe` fires**; the 2 m push; credit or self-out; the last life ends the game;
  - 8:00 → more lives wins; level → sudden death at 300%, a draw at 60 s; best of 3;
  - **classic pinned:** rule_set classic gives today's knock_scale numbers for 10 sample knocks and today's zone judging;
  - **gate:** with RingRules uninstalled, apply_hit lowers health, BendKnock adds its knocks, air decel 0.8, ragdoll_mps
    9, knock_t today's, no stun gate.
- `test_ring_hud.gd`, `test_percent_hud.gd` (new): the PercentBar in stock and the MatchBar in classic; a 12% hit updates
  within one frame; the ramp; the shake decays by 0.35 s; the fall sequence; layouts A and B at 1280×720 and 1920×1080;
  **no cues:** a bot moved 10 m in 1 s with no hits moves, shows or hides no CanvasItem, percent_bar.gd reads no
  position; the pips and the fresh band on your plate only; the wake and the drip off by default; the strip's air names,
  "lands", "safe" and the stale dimming.
- `test_ring_screens.gd`, `test_ring_teams.gd` (2 lives each, an ally adds 0%, three spouts), `test_knock.gd` kept green.
- `test_player_words.gd`: every player-facing VALUE (words, labels, card and hint text; never keys or ids) in
  screens.json, rules.json words, hud.json, lessons.json, practice.json, movement.json words and moves.json labels is
  free of show words **and** Smash names.

**MOVE**
- `test_ring_moves.gd` (new):
  - **Jumps:** taps of 0.08 s and 0.10 s and a 0.5 s hold all reach 2.0 ± 0.05 m; Space 0.03 s after an RMB release
    reaches 0.8 ± 0.05 m, and so does an RMB release 0.03 s after Space; the second Space is a 1.6 m double jump
    (earth 1.4, air 1.9) that halves the launch carry; the third, off the deck and ≥ 0.2 s after, is the Rise; a third
    Space over the deck does nothing; walking off, the first Space is the double jump.
  - **Masher:** Space every 60 ms from 12 off-deck spots at 120% (each element): it recovers at least as often as no
    input (lead_masher.out).
  - **Helpless:** it ignores Space, 3, E and casts with the "spent" sound; 0.35 s of landing lag.
  - **Refresh:** landing, a grab and a tumbling launch; nothing else.
  - **Air dodge:** 3.2 ± 0.1 m; a bolt at 0.15 s passes unspent, one at 0.40 s hits; a second 3 does nothing; landing
    in it gives 0.3 s.
  - **Fast fall:** a press of C after the apex gives −17 and holds without C held; it ends the glide.
  - **Roll and Duck:** a fresh A rolls 3.5 m, W held before E does not; from 1 m inside any lip a roll ends 0.3 m
    inside; the Duck is intangible at 0.1 s; a repeat within 1.0 s adds 0.1 s.
  - **Held guard + Space** jumps on that frame.
  - **The teeter:** 0.3 s toward the water steps off; a launch carries over at once.
  - **The Rise:** heights ±0.2 m (earth 5.5 along a 20° lean toward the lip, water 4.5, air 3.5; fire 7.5 m along the
    aim, a level aim lifted to +20°); the scramble from 1.8 m under the grab box reaches the hang, from 2.4 m it doesn't;
    the Pillar hits a body above it; the glide ≤ 3 m/s; Lift, Jets and Leap from the deck use up the Rise.
  - **Sounds on yourself:** the hitstun whoosh stops on the free frame; the escape tick at 0.6 s; heard by the player
    only.
- `test_ring_edge.gd` (new):
  - **The grab:** inside the box he grabs; outside it, with C held, in hitstun, or on a 4th grab without the deck, he
    doesn't. The snap faces the deck, the camera unchanged.
  - **The hang:** 0.6 s intangible on the first grab, 0 on a regrab; the drop at 4 s; regrab blocked for 0.4 s.
  - **Deck-relative keys:** with the camera at 0°, 90° and 180° to the lip, each of W/A/S/D climbs; none lets go; C lets
    go.
  - **The options:** Climb 0.6 m in, Roll in 3.0 m, the Jump to about lip +1.5 with the double jump kept, the Edge attack
    hits a body 1.5 m in; each intangible window exact.
  - **Occupancy:** no grab within 1.2 m of a hanger; a grab at 1.5 m. Corners slide 0.5 m.
  - **The Kick's wave** hits a hanger only after his 0.6 s.
- `test_ring_predict.gd` (new): RingPredict's KO speeds match lead_model.py v2 within ±5% at 25/30/35° from 17, 7 and 2
  m; the reach per element within ±1 m (11.3/11.8/15.8/17.4); the engine check: a water body at the deck's middle,
  Boulder at 100% → no KO, at 125% → KO.
- `tests/player/test_player_gate.gd` (new): outside the ring ring_moves is null, the jump is 4.4 under 9.8, the crouch a
  toggle, a third Space does nothing; in an arena traversal and grip are absent; the duel's NpcFighter._move unchanged.
- **Parity:** a bot and the player given the same intent sequence trace the same path within 1 cm over 2 s; the bot never
  writes velocity.
- **Camera:** on the deck the arm is 5.25 m and ≥ 3 m of deck behind the feet is in frame; a body at lip −5 m, 4 m out,
  facing the deck: body and lip both in the viewport; facing away with the mouse still: both in the viewport within 1.2 s;
  facing away with the mouse moving: the yaw untouched; no launch changes yaw or pitch; a respawn faces the deck's middle.

**AIR**
- `test_r3_air.gd` (new):
  - **Forms:** a key-2 lock started on the deck and released airborne is the Push (▲ if grown), not the Slam; a key-2
    lock started airborne is the Slam; landing during it calls it off for free; LMB and 1 decided at release.
  - **Key 3:** in the air it calls `RingMoves.dodge` at once; on the deck the Dash goes at max(lock, 0.22 s) and a second
    tap inside that turns it into the travel move; neither changes the readied move; **air dodge, land, RMB casts the
    move readied before the jump**; 1 is readied at the start and after a respawn.
  - **The Slam:** −70° with a set 0.30 s at 0% and 120%; a bounce at 0.45 × down + 2 (earth 0.55) with 0.45 s, once per
    string, then a flat half push; the same space at pitch +30 and −60; Downpour's puddle, the Axe Kick's wave, Down
    Gust's lift once per airtime, the Hammer with a held stone throws it.
  - **4 and 5** pause in the air and resume on landing.
  - **Landing lag:** a Punch landing within 0.35 s of its release plants 0.20 (0.10 on a hit); after it, or still
    locking, 0; during it a lock may fill but jump, dash and E don't.
  - **Air fill:** at 4.5 m/s of drift a water Lash fills at moving_mult; fire's Punch at full.
  - **Hit info:** `from`, `air`, `volley_id` and `volley_n` on every hit.
  - **Air guard:** an airborne earth catches a stone and throws it along the 3D aim, no lag from E.
  - **Walls:** they clamp 3.5 m inside the lip.
  - **Timers frozen:** a ▲ lock held past its growth when hit at 0.9 s does not self-cast during a 1.0 s hitstun; a
    sputtering lock does not fizzle during it.
  - **Tumbling E:** never raises the guard and never fills the buffer.
- `test_r3_combo.gd` (new):
  - **The jab string:** the step's 0.15 s; the third hitting jab is the Pop (80°, set 0.60 s); one Pop per string; a
    jab after the Pop stuns 0.10 s; a miss or guard resets to step 1; **earth's Pop leaves a held stone and E throws it
    (`rock_jab/pop_stone`)**.
  - **The engine probes:** Embers, Embers, Pop, Punch at 0% and 150% true; Pebbles, Pebbles, Pop, E true at 0% and 150%
    against a water dummy; Palm, Palm, Pop, Slice true; Spike after the Pop is not.
  - **Self-loops:** Embers ×12, Palm ×12, Pebbles ×12 and Pull ×12 at 0% and 150%: the longest true run ≤ 4 (Pull ≤ 2),
    and every later gap ≥ 0.15 s.
  - **No Chain:** a landed hit never shortens a lock other than the jab step.
- `test_r3_guard.gd` (new): the stock guard stands at fill; per element: perfect at 0.2 s after standing, late at 0.6 s
  with half % and half launch, the whiff penalty, the held 2.5 s; against a shot its matrix cell says "passes", a perfect
  is still 0% with no reward; Lightning perfect only for fire; earth's catch window 1.0 s then late with the stone
  dropped; E mid-lock drops the lock; in the classic ring and the open world round 2's stand-at-release is unchanged.
- **Patch:** stands still to fill; calls `RingRules.patch`; refused when `heal_allowed` is false.
- **macOS:** a synthetic RMB press with ctrl_pressed reads as LMB while RingMoves is installed on the caster, and as RMB
  without it.
- **A fall:** `drop_all()` clears the locks and drops the stones; `ready_default()` readies key 1.
- **Kept green:** test_r2_cast/test_r2_guards (their stock twins where the rules differ), test_bend_cast,
  test_bend_caster, test_bend_throw, test_flow, test_bend_poses, test_bend_sounds, test_quick_spell, test_hotbar and
  test_schemes. Kick floor-wave tests at ring gravity: a jump is missed from 0.07 to 0.82 s after takeoff; a short hop
  from 0.14 to 0.43 s.

**BOTS**
- `tests/npc/test_bot_recovery.gd` (new): each element × preset from 12 fixed off-deck spots; returns: hard 100%,
  normal ≥ 95%, easy ≥ 75%; no self-falls in 60 s of neutral at normal and hard; no 4th grab.
- `tests/npc/test_bot_pct.gd` (new): the KO read (foe at 150% 2 m from his end: a killing option in ≥ 70% of 20 seeds;
  at 0% ≤ 20%); finishers walk in from beyond 15 m; strings only when `hitstun_left ≥ lock + flight`; the hard bot's
  steered launch at 140% ≥ 10% shorter than the easy bot's; no % into a safety; the hard bot hits a scripted recovering
  player ≤ 0.6 of the time; the confirm, steering and break-fall rates within ±0.1 over 200 trials; Patch only by its
  rule.
- `test_bend_bots.gd`: in the stock ring the bot uses the double jump, air dodge, Rise and the edge within 60 s of the
  recover drill; its gravity equals the player's; the earth bot throws its Pop stone.
- `test_practice.gd`: the % rows, the dummy's ways, "Throw me off"; speed 1/2 survives a pause and a fall; the counter
  white for a true 2-string and grey for a free gap (the escape counted); the readout's "out at" equals RingPredict and
  "steered" equals `last_steer_deg`.
- `test_lessons.gd`: each new card done by scripted input, skipped by Enter, resumed; the String card's earth line vs
  the others; the stock guard card; **the hint queue** (one per 20 s, the edge hint pre-empts, stale after the first
  fall).
- `test_playcheck.gd`: the scripted player double jumps, air dodges, is thrown off an end and comes back with the Rise;
  the match reaches DONE; the PercentBar shows from the countdown on.
- `test_match_setup.gd`: rule_set ("Lives"/"Zones" labels), games and practice %.
- `test_ring_soak.gd` and `test_balance.gd`: the §12 METRIC lines and targets, with lives instead of rounds; 0 SCRIPT
  ERROR.

**CLIPS**
- `test_bend_clips.gd`: every new clip exists in Frontier_Bend.res with its metas and its mirrored twin; the worst IK
  miss ≤ 5 mm; the existing clips' timing metas unchanged; the hang clip's hands and head above the lip height at every
  frame; the helpless loop's hands above the shoulders; the Slams' strike_s ≤ 0.2 s; the scramble ends in the hang pose.

---

## 16. The first match: an average player, earth, against an easy water bot

1. **Element pick.** He reads *"Earth: heavy, hard to throw out."* The countdown shows two plates in the top corners,
   both 0% with three small glyphs; under his own, three pips. His strip shows 1 · Spike ready.
2. **First exchange.** He clicks LMB: Pebbles. The bot's plate pops to 5%. He clicks twice more and the third volley
   that hits throws the bot up with a stone fist: the Pop. The fist's stone stays in his hand. The String card he saw
   said "Then E: throw it", so he presses E, and the stone catches the bot in the air. He has found a true string by
   mashing and one key.
3. **Getting hit.** The bot's Lash hits him at 30%. He slides back on his feet for a quarter second, hears a short
   whoosh stop, and moves. His aim never moved. His Spike lock, half full, waits and then finishes.
4. **The edge.** At 95% a Wave carries him over the end, his back to the water, the deck in front. The camera pulls back
   so the lip and he are both in frame. He mashes Space: the double jump takes half the throw's speed away, and his
   next press, a beat later, is the Rise. A leaning stone column bursts out of the water and throws him at the lip; he
   comes up a little low, but his hands slap the face and haul him up to the hang. The hint reads *"W climbs, Space
   jumps, E rolls in."* The camera faces along the lip; he presses W anyway, and climbs.
5. **The KO.** The bot's plate is red at 130%. Its Spear comes in and he presses E a little late: half gets through, a
   slide on his feet. He walks in to 8 m, waits for the bot to stand near its end, and lets a Spike go. The bot flies,
   steers a little, double jumps, and its Fountain falls short. Splash. *"Into the water: the Tide · 2 left."*
6. **The respawn.** A spout lifts the bot back over its end. He can't Patch while the bot is out; his own plate's pale
   band has already faded.
7. **The finish.** Six minutes in, it is 1 life to 1. The bot is at 140% near its end. Pebbles, Pebbles, Pop, E: the
   Pop's stone is true at any %, and from 8 m short of the end it puts the bot in the water.
8. **The match screen.** *"6:12 · the Tide into the water at 146% · your Pop stone"*, and his longest string, 4 hits ·
   27%.

**What he learned without reading anything:** the number; the water; Space, Space, Space; grabbing the edge; the
three-click Pop; E throws the stone.

---

## 17. Owner questions (only the ones that need you; each with the default round 3 builds)

1. **Hitstun is the sport.** While you are thrown you can't act for a moment: 0.12-0.4 s at low %, and never more than
   0.6 s before you can break out. Your aim, camera and charge are never touched, your press is kept, and you can steer
   and break your fall. Does that sit with your rule "getting hit never slows the player"? *Default: yes.*
2. **The recovery turn.** Thrown off facing away from the deck, with your mouse still, the view turns toward the deck
   (any mouse move takes it back for good). Or should the view never turn? *Default: it turns; one switch in
   movement.json.*
3. **Stale moves.** The same move landed again and again gives up to 40% less % (your own strip dims it). Casting is
   never limited. Is that inside "lock time is the only spam limiter"? *Default: yes.*
4. **A real air-only hit per element** (its own clip), next round: today the air moves are the same moves along your aim,
   plus the Slam under you and the High Kick crescent. *Default: yes, next round.*
5. **The arena's new look:** water 6 m below the deck on piers, a curtain of falling water round the tank, a pale stone
   edge with lanterns, the stands 4 m back. *Default: built; noon and night images first.*

**Decided by the lead (the owner may still overrule):** open sides at 14 m (18 m if the soak asks); Patch as fresh damage
only; the launch wake and the respawn drip off (images of both); the keys of §0; the Rise's names (Pillar, Fountain, Jet,
Updraft); the 8:00 clock with sudden death at 300%; easy bots may fall in about once in four lives; a "Master" bot in a
later round; plates in the top corners (B rendered); Practice's readout numbers only; ring physics (gravity 20, run 5.0,
a 2.0 m jump, 0.8 m short hop); no open-world vaulting or grip in any arena; 3v3 at 2 lives each on 8:00.

---

## 18. Not taken, and why

- **The Chain** (a hit halves your next lock). Combos are true without it (§6.6); it bends "lock time is the only spam
  limiter". It returns only if the soak's median true string falls under 2.
- **A separate dodge key (Shift).** Shift is sprint; 3 is already the dodge.
- **Element gravity multipliers.** One gravity.
- **The sinking deck in sudden death.** The owner retired the closing tide.
- **A sky line.** Launches straight up come back; KO classes stay at 65° or less.
- **Earth's smaller stones off the deck.** Earth already recovers least far.
- **The fresh-move bonus (×1.05).** Staling alone teaches mixing.
- **E lifting a loose stone with nothing incoming** (judge 2). Round 2 cut "the nearest-stone search" as a hidden rule;
  the Pop's stone gives earth a stone in every matchup instead.
- **An off-screen arrow to the deck.** The framing (§4.8) and the recovery turn cover it without a pointer.
- **A raised kerb.** The coping stands 4 cm proud for the eye with a flush collider, so it never trips a slide.

---

## 19. The round-3 build: SEAMS, then five tasks with no shared file

**Base.** The spellcraft branch AFTER round 2 (CORE, CLIPS, KITS, HUD_LESSONS) has merged. Round 3 meets these round-2
files: SwayCaster's SRC_GUARD, click buffer, hit setback and ▲ grow; BendZone's guards and earth's held stone;
BendEffects' floor_wave, crescent and walls; moves.json's `jabs`/`guards`/`passives`; the strip's JAB and GUARD chips;
the lessons; NpcBending's guard chances and combos; test_r2_cast, test_r2_guards and the round-2 soak.

**SEAMS first** (one short task, merged before the five fork): the API stubs of §14.3 in their owners' files, returning
today's behaviour; the empty `movement.json`, `hud.json` and `practice.json`; the extract of RingMode's practice code into
`scripts/ring/ring_practice.gd`; `rules.json rule_set "classic"` (PERCENT flips the default to "stock").

**The five tasks, in parallel worktrees:**

| Task | Owns |
|---|---|
| PERCENT | the % rules, launches (set not add, range, air factor), hitstun and breaking the fall, guards and Patch in %, lives, respawn, clock, the stage overlay (curtain, coping, lanterns, lip sound), the HUD plates and pips, screens, words |
| MOVE | the movement set, the edge (deck-relative keys, the 3-grab rule), the Rise (lean, Jet floor, scramble), the camera (framing, recovery turn), the gated player controller and NpcFighter body, sounds and shadow on yourself, the predictor, NpcPad, the body-state clips' playback |
| AIR | the cast layer: key 3 on press, 1 readied at spawn, key 2's form at lock start, the Slam, landing lag, air fill, the jab step, the Pop and earth's Pop stone, the shield guard, the lock frozen in hitstun, hit info, walls off the lip, Patch's lock |
| BOTS | the bot AI for the % game, Practice, lessons and the hint queue, menus, the soak and balance, docs/bending_design.md |
| CLIPS | every new own clip |

**Merge order:** CLIPS P1 whenever ready; PERCENT → MOVE → AIR → BOTS. Each rebases on the previous merges before its
final test run, and BOTS runs the soak last. One Godot at a time through the lock. The task files are in `round3/`;
`round3/COMMON.md` holds the rules every task shares.

---

## 20. Judges' notes (v2): every problem and what was done

Severity in brackets. "Fixed" names the section; "not taken" says why.

**Judge 1 (the average player)**

| Problem | Done |
|---|---|
| [4] The spec forgot right click; 3 means two kinds of thing | **Fixed.** §0's one sentence and RMB rows; 3 acts at once everywhere in the stock ring and never changes the readied move (§4.5, §4.6); 1 readied at the start and after a fall; every player line in RMB terms (§6.2, §6.4, §11.2); tests in test_r3_air. |
| [4] Earth's taught string (Pop → 1) can't land | **Fixed.** Earth's Pop leaves a stone in the hand; the earth String card says E (§6.4); Pop → Spike is listed as never true. |
| [5] Off the deck I can't see myself and the lip | **Fixed.** Midpoint pivot, arm 4.1 + 0.6 × separation (cap 8), FOV 65 beyond 4 m (§4.8). The sideways arm slide was replaced by the recovery turn (mouse idle, cancelled by any mouse move), because a sideways slide can't show a lip that is behind the lens; it is owner question 2. Camera tests. |
| [4] Edge keys are camera-relative | **Fixed.** Deck-relative: every direction key climbs, only C lets go (§5.3); tests at 0/90/180°. (Judge 2's version, since S letting go could still drop a newcomer.) |
| [4] Mashing Space kills | **Fixed.** The buffer never fires the escape; the Rise needs a fresh press 0.2 s after the double jump and only off the deck; "spent" sound while helpless (§3.2, §5.4). Added: a double jump keeps half the launch's carry, because the model showed a masher still flew farther than a still player without it (§4.2, lead_masher.out). Masher test in test_ring_moves. |
| [4] The Rise depends on aim with no feedback | **Fixed.** The scramble (2.0 m), the Jet's +20° floor off the deck, the Pillar's 20° lean toward the lip, the Back card "Look at the deck, then Space, Space, Space" (§5.4, §11.2). Earth's reach rises from 9.9 to 11.3 m. |
| [3] The air form flips at release (Shove ▲ becomes a Slam) | **Fixed.** Key 2's form is decided at lock start; LMB and 1 at release (§6.1); test. |
| [3] Short hop on a 0.12 s release makes jump height random | **Fixed.** Space is always a full jump; the short hop is Space within 0.05 s of a cast release (§4.1); tests with 0.08/0.10 s taps. |
| [3] Holding W against the throw does nothing | **Fixed.** Holding against the flight adds 2 m/s² of decay for 0.3 s; the hint says "left or right"; the body leans; Practice shows "steered" (§3.3). |
| [3] Can't see the edge behind you on the deck | **Fixed.** Deck arm 5.25 m and a higher pivot; the pale stone coping and lanterns; the lip's water sound; tall, loud Rise tells; the "from 2 m back" image (§4.8, §5.1, §5.4). |
| [3] Can't tell what air moves are left | **Fixed.** Three pips on your own plate; the "spent" beat (§10.1, §5.4). |
| [3] macOS Ctrl+click and Ctrl+Space | **Fixed.** C is the shown down key, fast fall needs no held key, Ctrl+RMB reads as LMB in the ring (§4.3); test. |
| [2] Round 2's guard card teaches the wrong E | **Fixed** (§11.2). The "short hold under the guard turns, only a tap rolls" part **not taken**: a roll that waits for the key's release adds up to 0.15 s to a defensive move; the card says "tap". |
| [2] Hitstun has no end you can sense; early E locks out | **Fixed.** The whoosh and the 0.6 s tick; your own drop shadow; presses more than 0.5 s early never spoil (§3.2, §3.4). |
| [2] Two stone walls, two rules | **Fixed.** The tank's edge is a curtain of falling water (§5.1). |
| [2] Respawn camera yaw; hits on a safe body feel like bugs | **Fixed** (§4.8, §7.2). |
| [2] Too many hints at once | **Fixed.** One hint queue (§11.2). |
| [1] Keys 4 and 5 in the air feel broken | **Fixed.** "lands" on their chips (§6.1, §10.4). The hollow ring on the hands **not taken** (a ring shape is too close to a cue, even on yourself); the chip says it. |

**Judge 2 (the systems designer)**

| Problem | Done |
|---|---|
| [5] Knocks add, so Palms and Pulls stack to a 0% KO | **Fixed.** A knock sets the motion; a volley is one knock and one d; Pull capped to end at the caster (§2.1, §2.2); tests. |
| [5] Jab self-loops are true at every % | **Fixed.** Decay on every hit (the Pop exempt), a jab after the Pop 0.10 s, the 0.4 s breather after a 4+ hit string, volley d cut (Embers 11.2 → 4%) (§2.3, §6.7); self-pair probes in lead_combos and test_r3_combo; the gate is now ≤ 6, median 2. |
| [5] Patch breaks the % economy | **Fixed.** Fresh damage only (last 6 s, at most 10%), standing still, never while the foe is out or in sudden death; soak gates (§8). Removed from the owner's questions. |
| [4] A launch can clear the tank wall | **Fixed.** Out at the curtain's plane at any height (§5.2); the model already counted it so; test. |
| [4] The guard is not a shield across elements | **Fixed.** Every guard stops everything in the stock ring; the matrix decides rewards; Lightning only by fire (§2.5); 16-cell test. |
| [4] The fun core exists only in the earth mirror; the held stone's class undefined | **Fixed.** The Pop's stone in every matchup; a returned stone is Spike's class or the caught move's if higher, ×1.2 + rally; the Pop's stone is Spike's class and stales (§2.3, §2.5, §6.4); §16 rewritten so its finish is reachable. The "E lifts a loose stone" part **not taken** (§18). |
| [4] Ranged zoning beats approach | **Fixed.** Range falloff on growth (full to 10 m, ×0.65 at 22 m), returns and Lightning exempt; `ko_far_share` ≤ 0.3; bots walk in to finish (§2.2, §9.3, §12). |
| [4] The clock contradicts the calibration | **Fixed** with option (b): 8:00, the % numbers kept; `timeouts_level` and `last_life_s` metrics (§7.3, §12). |
| [3] Aerials are strictly better | **Fixed.** Air fill at the moving rate; launch classes released in the air ×0.85; a Strike is out for 0.35 s after its release (§6.1, §6.3). The air-only close hit is owner question 4. |
| [3] Walls can seal the edge | **Fixed.** 3.5 m from any lip (§5.2). The "a wall over a hanger sinks" rule is not needed: no wall can reach a hanger's span. |
| [3] A poke refreshes a helpless recoverer; Space ×3 on the deck makes you helpless | **Fixed in part.** Set knocks, flinches and the Slam refresh nothing; a tumbling launch still refreshes all three air moves (judge 1 asked to keep "every launch refreshes", and the masher model shows the double jump is what saves a thrown newcomer). The Rise only off the deck (§3.2, §5.4). |
| [3] Hanging keys are camera-relative | **Fixed** (see judge 1). |
| [3] The held guard makes earth a turtle | **Fixed.** The full catch stays round 2's 1.0 s window; held past it a stone is late and drops loose (§2.5). |
| [3] A free charged KO after respawn | **Fixed.** A fall clears locks and stones; any lock's start ends safety; a cast key leaves the spout (§7.2); tests. |
| [3] The lip behind you is invisible | **Fixed.** The coping (proud for the eye, flush collider) and lanterns, the lip's water sound on your own side (§5.1). Rumble: no controller support yet; the sound covers it. |
| [2] Combos counted on stuns past the escape; the Pop as a launch class; the gate contradicts the cap | **Fixed.** min(stun, 0.6) everywhere (lead_combos, `hitstun_left`, Practice); the Pop set in lead_table; the gate ≤ 6. |
| [2] Frozen-lock timers; E while tumbling | **Fixed.** Every lock timer freezes; tumbling E is only a break-fall try (§3.2). |
| [2] macOS Ctrl+Space and Ctrl+click | **Fixed** (§4.3). |
| [2] Timeout planking | **Fixed.** Three grabs, then the deck (§5.3). |
| [1] The drip vs the wake; the Rules row's ids; the words test flags keys | **Fixed.** Both off by default with images (§7.2, §10.5); "Lives"/"Zones"; the test scans values only. |

**Kept, as both judges asked:** out only by touching the water; the double jump, dodge and Rise refreshed by a real
launch; the automatic grab with first-grab safety and the 4 s hang; the teeter; hitstun never touching aim, camera or the
lock; strings that end by themselves; the % ramp, roll-up and pop; no Smash names; the water spout; lessons done by
doing; Practice's numbers-only readout and "Throw me off"; earth's catch whole, with returns never staled; stale moves on
the payoff only; sudden death at 300%; one gravity; steering at 0.1 s, yaw only; the 0.6 s escape; no Chain; edge
occupancy with no trumping; the Slam's one-press spike; Space as "up" and 3 as the dodge; water at −6 with the 10 m tank
and the 8 m/s² carry decay; bots only through NpcPad with the parity test; one gate with its test; late guards as a
slide on the feet.
