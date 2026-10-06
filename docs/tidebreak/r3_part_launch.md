# Tidebreak round 3, the % layer: DAMAGE % AND LAUNCH (design, read-only pass)

Designer's part of the owner's 2026-10-05 ask: "instead of a knock back we should implement a smash bros 100% plus like arena
out system ... give everyone all movement options and in air options and combos". The owner's choices rule
(critic_r2/owner_answers_r3.md): **keep the number keys**, **3 stocks** (% to 0 after each KO), **full recovery**, **out
only in the water**. This sits on round 2's kit and layout (skills_r2/spec.md, overridden by skills_r2/owner_answers.md):
LMB Jab · E Guard · 1 Strike · 2 Push ▲ · 3 Dash · 4 Wall · 5 Heal, tap / double tap.

Nothing in the project was edited; Godot and Blender were not run. Numbers were calibrated with a small model of
BendKnock's physics (smash_r3/launch_sim.py, launch_fit.py: gravity 9.8, the deck 34 × 14 m, the water 1.4 m under the
deck and 6 m wide, and an ASSUMED recovery set; re-run them with the movement designer's real numbers).

Other designers own movement (jumps, air dodge, edge grab, rolls), the aerial move set and the stage. Where my numbers lean
on theirs, I say so and give the number I assumed.

---

## 0. The short version

1. **No health in the ring. Every hit adds damage %**, shown big in the HUD for every competitor. 0% at the start of each
   stock; no cap (999 shown at most).
2. **The higher your %, the farther you fly and the longer you tumble.** Launch speed = your weight × (the move's base +
   its growth × your % × the hit's size). Heavy earth flies least, light air the most.
3. **You are out only when you touch the water** (or fly past the tank's far wall). 3 stocks; last one standing wins.
4. **Hitstun is short at low %, long at high %, and always escapable:** bend your flight with the movement keys (up to
   15°), land on your feet with **E** just before you hit the deck or a wall, and from 0.6 s into a long tumble you may
   air-dodge or jump out. Your camera and aim are never touched.
5. **Jabs never KO.** Quick shots KO around 210-230%, big shots around 135-150%, pushes around 160-190% (grown ▲ ~120-140%),
   the heaviest (Boulder, Lightning) around 105-115%: all from the deck's middle toward an open end on a medium body.
   Launchers (Column, Geyser, High Kick) throw up for juggles and never KO alone.
6. **Fresh moves hit harder.** The same move landed again and again loses up to 45% of its % (never its cast: the lock
   is untouched). Your own strip dims a worn move. Returns (earth's catch, Turn, Parry, Wind Guard) are never worn.
7. **Patch (5) takes 8% off** after a 1.5 s lock, on the deck only (owner question).
8. **KO → a splash → 1.6 s → you rise on a water spout above your end**; up to 3 s on it; safe until 1.5 s after you
   step off or until your first cast, whichever is first. The spout pushes away anyone standing under it.
9. **6:00 clock.** More stocks at the bell wins; level stocks → **sudden death**: both at 300%, one stock, the next KO
   wins, and after 20 s the ends of the deck start to sink.
10. **RingRules' zones retire** in the new default rule set "stock"; the old rules stay as "classic" behind the Esc
    Rules row for one round of comparison.

---

## 1. The damage % ledger

**Rule:** in the ring's stock rules, a hit adds `d` % to the struck competitor's %, and never touches his health.

- The ledger lives in RingRules.state per competitor: `pct`, `stocks`, `safe_until`, the attacker's stale queue, the
  string count (§7). BendKnock stays physics only, because it is shared with the open world.
- `d` comes from the move's **class** (§3, data/ring/rules.json `stock.classes`, keyed `id/mode` and `id/mode.grown`).
- Untagged damage (any path not yet passing a class: GustLift's Hit.deliver, form_spikes, BendZone ticks) converts by one
  curve: **d = 13 × (1 − e^(−dmg/35))** (7 → 2.4, 20 → 5.6, 30 → 7.2, 55 → 10.2, 70 → 11.2, 110 → 12.4). Big old
  numbers (a 70-damage hurled spike) can't jump to 70%.
- `pct_scale` (1.0) multiplies every d: the one knob the first soak turns to hit the match length (§13).
- No cap; the HUD shows up to 999%.
- Health bars are hidden in the ring under stock rules; `no_death` stays; "winded" never happens.

**Why these d values:** round 1's soaks land few hits: water against fire had 107 knocks in 360 s (about 9 a minute per
side); the earth mirror's damage came from about 3 stone hits a minute per side. Smash's 8-20% a hit assumes many more
hits a minute. Here a hit is rarer, so each is worth more (quick shots 10-11%, big shots 16-25%) to bring a stock to
about 60-80 s. The new movement and combos will raise the hit rate; `pct_scale` takes it back down.

---

## 2. The launch formula

**Rule:** a hit launches its target at

    v = W × (base + growth × (p / 100) × (0.5 + d / 20))      [m/s]

with p the target's % **after** this hit, d the hit's % (after staling, §10), base and growth the move class's, and W the
target's weight multiplier (§4). A set-knock class (jabs, Pull, walls) launches at exactly its base whatever the %.

- **Direction:** the hit's travel direction made flat, then raised by the class's angle. For cones, the direction is from
  the caster to the target; for Column and Geyser it is straight up; Pull points toward the caster, 15° up.
- **Ground or air:** under **tumble_mps 6** a grounded target is pushed flat along the deck on his feet (a flinch-slide,
  no tumble). At 6 m/s or more he tumbles: he leaves the deck at the class angle (BendKnock's launch, the airborne knock
  clip). Launchers (angle ≥ 60°) always launch.
- **Vertical cap:** the up part is capped at **vy_cap 14 m/s** (10 m high), so a juggle at 300% doesn't take 5 s.
- **Air decel while tumbling: 3.0 m/s²** (BendKnock's AIR_DECEL 0.8 is kept for the open world). With 0.8, the model's
  recovery only bought about 1-2 m/s of survival. With 3.0 it buys about 4 m/s from the middle and nearly doubles what
  you survive near an edge, so recovery and DI matter (launch_sweep.py).
- **The cap goes:** max_push_m (3.5 m), knock_scale (0.7) and element_factor (the knocker's element) are the zone game's
  limits. They are off in stock rules. The moves' own base and growth carry each element's identity now.
- **Ragdoll goes:** BendKnock.ragdoll_mps is INF under stock rules. The tumble clip plays instead, so nobody ever lies
  limp in a sport.

**Worked examples** (a water body, weight 1.0):
- **Boulder at 100%:** p after = 122. v = 7 + 6.6 × 1.22 × 1.6 = 19.9 m/s at 35°. The model's KO speed from the deck's
  middle toward an end is 19.1, so it is a KO.
- **Spike at 40%:** p = 54. v = 5 + 6.6 × 0.54 × 1.2 = 9.3 m/s, with 0.47 s of hitstun and 0.95 s in the air. A Punch
  started at the Spike's release (lock 0.35 s, plus 10 m of flight at 32 m/s) lands 0.36 s after the Spike: **a true
  combo at 40%**.
- **The same at 0%:** v = 6.1 m/s and 0.31 s of hitstun, so the Punch lands after he can act. **That is a read, not a
  combo.**

Combos open at mid %, then the launch carries him out of reach at high %. That is Smash's shape.

**How far "KO speed" is** (the model, with the assumed recovery; KO = touching the water or passing the tank's far wall):

| Launch angle | From the middle toward an end (17 m) | From the middle toward a long side (7 m) | 8 m short of an end | Same 3 cases, no recovery |
|---|---|---|---|---|
| 25° | 17.7 m/s | 13.5 | 13.9 | 30°: 15.3 / 9.8 / 10.5 |
| 30° | 17.6 | 14.2 | 14.6 | |
| 35° | 19.1 | 15.0 | 15.5 | |
| 40° | 20.4 | 16.0 | 16.6 | |

Assumed recovery (movement designer to replace):
- air drift 5 m/s at 10 m/s²
- double jump vy 6.5
- up-recovery vy 9 with 5 m/s toward the deck for 0.35 s, then helpless
- edge grab within 1.0 m of the lip, from 1.2 m below to 0.4 m above it

---

## 3. The move classes: numbers for every move of the round-2 kits

d = % per hit; base and growth in m/s; angle up from flat. KO % is for a water body (weight 1.0) with no DI, from the
deck's middle toward an open end ("end"), toward a long side ("side"), and from 8 m short of an end ("near"), then "end"
for earth (W 0.89) and air (W 1.11). Hitstun = 0.05 s per m/s (§5). A set knock always launches at its base.

| Move (id/mode) | d % | base | growth | angle | KO end | KO side | KO near | earth end | air end | launch at 0 / 60 / 120 % | stun at 120 % |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Jabs** (set knock: strings, never a KO) | | | | | | | | | | | |
| Pebbles, each of 3 (`rock_jab/pebbles`) | 3.5 | set 3 | — | 10° | never | never | never | never | never | 3 | 0.28 |
| Splash (`water_jet/splash`) | 6 | set 3.5 | — | 10° | never | never | never | never | never | 3.5 | 0.28 |
| Embers, each of 7 (`fire_jab/embers`) | 1.6 | set 1.5 | — | 5° | never | never | never | never | never | 1.5 | 0.28 |
| Palm (`air_palm/palm`) | 3 | set 4.5 | — | 10° | never | never | never | never | never | 4.5 | 0.28 |
| **Quick shots** (1, first move) | | | | | | | | | | | |
| Spike (`stone_form/spike`) | 14 | 5 | 6.6 | 30° | 159% | 116% | 122% | 187% | 137% | 6.1 / 10.9 / 15.6 | 0.78 |
| Lash (`water_whip/whip`) | 10 | 4 | 6.5 | 25° | 210% | 147% | 152% | 244% | 183% | 4.7 / 8.6 / 12.4 | 0.62 |
| Punch (`fire_blast/punch`) | 11 | 3.5 | 5.9 | 25° | 228% | 162% | 167% | 264% | 200% | 4.2 / 7.9 / 11.6 | 0.58 |
| Slice (`air_blast/slice`) | 6 | 3 | 8.3 | 25° | 221% | 159% | 164% | 254% | 194% | 3.4 / 7.4 / 11.4 | 0.57 |
| **Big shots** (1 twice, or Punch held) | | | | | | | | | | | |
| Boulder (`stone_form/cannonball`) | 22 | 7 | 6.6 | 35° | 114% | 76% | 80% | 137% | 97% | 9.3 / 15.7 / 22.0 | 1.10 |
| Spear (`ice/spear`) | 16 | 4.5 | 6.7 | 25° | 151% | 104% | 108% | 176% | 131% | 5.9 / 11.1 / 16.3 | 0.82 |
| Fireball, Punch held (`fire_blast/fireball`) | 18 | 5 | 6.7 | 30° | 134% | 98% | 103% | 158% | 116% | 6.7 / 12.3 / 17.9 | 0.90 |
| Lightning (`fire_arc/lightning`) | 25 | 6 | 6.3 | 30° | 105% | 74% | 78% | 125% | 89% | 8.8 / 15.4 / 22.0 | 1.10 |
| Wind Ball (`air_blast/ball`) | 7 | 7 | 10.2 | 35° | 139% | 92% | 98% | 167% | 118% | 7.6 / 12.8 / 18.0 | 0.90 |
| **Pushes** (2, first move) and **grown ▲** | | | | | | | | | | | |
| Shove (`earth_shove/push`) | 12 | 6 | 6.6 | 30° | 160% | 113% | 119% | 190% | 136% | 6.9 / 11.2 / 15.6 | 0.78 |
| Shove grown (`earth_shove/push.grown`) | 16 | 7 | 6.8 | 30° | 120% | 81% | 87% | 145% | 100% | 8.4 / 13.7 / 19.0 | 0.95 |
| Wave (`wave/push`) | 9 | 7 | 6.8 | 30° | 164% | 111% | 118% | 198% | 137% | 7.6 / 11.5 / 15.3 | 0.77 |
| Wave grown (`wave/push.grown`) | 12 | 8 | 7.0 | 30° | 125% | 80% | 86% | 153% | 102% | 8.9 / 13.5 / 18.2 | 0.91 |
| Kick, floor wave (`fire_kick/kick`) | 12 | 5 | 7.4 | 40° | 189% | 136% | 142% | 220% | 164% | 6.0 / 10.9 / 15.7 | 0.79 |
| Kick grown (`fire_kick/kick.grown`) | 16 | 6 | 7.9 | 40° | 140% | 98% | 103% | 165% | 121% | 7.6 / 13.8 / 20.0 | 1.00 |
| Gust (`air_gust/gust`) | 5 | 6.5 | 8.5 | 30° | 174% | 121% | 128% | 208% | 147% | 6.8 / 10.6 / 14.5 | 0.72 |
| Gust grown (`air_gust/gust.grown`) | 7 | 7.5 | 9.5 | 30° | 125% | 83% | 89% | 152% | 104% | 8.1 / 12.9 / 17.8 | 0.89 |
| **Launchers** (2 twice): up, combo starters | | | | | | | | | | | |
| Column (`earth_shove/column`) | 11 | 9 | 4 | 85° | never | never | never | never | never | 9.5 / 12.0 / 14.5 | 0.73 |
| Geyser (`wave/spout`; from a grate or puddle: growth ×1.33) | 11 | 9.5 | 4 | 85° | never | never | never | never | never | 10.0 / 12.5 / 15.0 | 0.75 |
| High Kick (`fire_kick/high_kick`) | 10 | 6 | 6 | 65° | 517% | 384% | 400% | 593% | 456% | 6.6 / 10.2 / 13.8 | 0.69 |
| Pull (`air_gust/pull`; toward the caster, 15° up) | 4 | set 6 | — | 15° | never | never | never | never | never | 6 | 0.28 |
| **Contact and zones** | | | | | | | | | | | |
| Surf, run into (`flow/surf`) | 7 | 6 | 5 | 20° | 294% | 156% | 164% | 348% | 251% | 6.3 / 8.8 / 11.4 | 0.57 |
| Breath (`fire_breath/breath`) | 10 | 3 | 6 | 20° | 259% | 161% | 166% | 297% | 228% | 3.6 / 7.2 / 10.8 | 0.54 |
| Fire Wall: on entering, then each 0.25 s inside | 4, then 2 a tick | set 5 at entry | — | 50° | never | never | never | never | never | 5 (at entry only, once a second) | 0.28, then none |
| Wind Wall, walking in (`air_wall/wall`) | 0 | set 4 | — | 0° | never | never | never | never | never | 4 | 0.28 |
| Burrow, Skate, Step, Jets, Slip, Leap, Lift, walls, guards | 0 | — | — | — | | | | | | no hit | |

**Each element's identity in the numbers:**
- **Fire** has the most % per lock second (Punch 11 on a 0.35 s lock, Embers up to 11) and the lowest growth: it builds %
  fast and needs Lightning, the Fireball or a grown Kick to finish.
- **Air** has the least % (Slice 6, Gust 5) and the most growth (Wind Ball 10.2): it pushes hardest and takes longest to
  build.
- **Earth** is heavy on both d and base (Spike 14, Boulder 22) on long locks.
- **Water** sits in the middle, with Geyser's pools as its juggle tool.

### 3.1 Guards and returns (§2.5 of round 2 in %)

**Rule:** a guarded hit gives the guarder nothing on a perfect, and on a late guard the d and the launch are both halved.
A returned shot is its own class, owned by the returner, at ×1.2.

- **Perfect** (first 0.3 s): 0% and no launch. Earth holds the stone. Turn, Parry and Wind Guard send it back.
- **Late:** d × 0.5, then the launch is computed with that d and multiplied by 0.5. Earth's late catch is still a full
  catch: 0%, as round 2 says.
- **Returns** (earth's E return, Shove's held stone, Turn, Parry, Wind Guard's bounce, lightning parried back): the shot's
  own class with d and growth × the return multiplier:
  - 1.2 after a perfect;
  - earth's rally steps on top (+0.1 a return, +0.2 if clean, up to ×1.6).
  - **Returns are never staled** (§10). So a long earth rally turns the stone into a KO threat: a Spike at ×1.6 KOs at
    about 77% from the middle. That is the climax of the owner's favourite exchange, and it never weakens the catch.
- **Aerial down hits** (an aerial designer's hook; owner-facing name "down hit"): a strong or heavy class cast while the
  caster is airborne, aimed 35° or more below level, at an airborne target. It launches at −45° × 0.8 and drives him
  toward the water. A grounded target it hits pops up at 20° instead and can tech.

---

## 4. Weight (the target's element) and the passives

**Rule:** the struck body's element sets W, the multiplier on everything that launches it. Earth is heavy, air is light.

| Element | weight w | W = 2 / (1 + w) | Effect (KO % from the middle, the Boulder) |
|---|---|---|---|
| Earth | 1.25 | 0.89 | 137% (lives about 20% longer) |
| Water | 1.0 | 1.00 | 114% |
| Fire | 0.95 | 1.03 | about 110% |
| Air | 0.8 | 1.11 | 97% (lives about 15% shorter) |

Gravity is the same for all, so jumps and recoveries need no per-element numbers. Fall speed by weight is the movement
designer's call.

**Passives in % (round 2's numbers, re-aimed so neither breaks the KO game):**
- **Earth Rooted** (standing still: knock taken ×0.85) applies to **base only**. Standing still shrugs off pokes, but
  never makes earth unkillable at high %.
- **Air Carried wind** (×1.15 on `carry` specs out of a dash) applies to the whole launch. It is air's kill boost.

---

## 5. Hitstun, and how it stays fair (the owner's rule)

**Rule:** a launch of v m/s holds the struck body in hitstun for clamp(0.05 × v, 0.12, 1.2) s. A set knock (jabs, Pull,
walls) holds it 0.28 s.

**During hitstun:**
- **Never touched:** the camera, the aim and your lock. It keeps filling at the moving rate, and round 2's setback (the
  hitter's lock time, at least 0.25 s) applies once per hit.
- **Held:** walking and steering, jumping, dashing, and letting a cast go.
  - A release made during hitstun is **kept and fires the instant hitstun ends**, aimed where you look then. You lose no
    input and no aim, only a short wait.
  - The guard can't start, except as the tech (§8).
- **The movement keys DI the flight** (§6).

**Why this is not a debuff** (the owner's words: getting hit never slows the player or hurts his aim):
- Hitstun is the launch itself, the sport's knock. It ends in 0.15-0.4 s at low % and lasts up to 1.2 s only at KO-range %.
- After it, the body has every option at full speed at once. No slow, no limp, no lingering cap.
- The aim is never moved: IMPACT's offset jolt is never `kick()`.

**Escapes, so no string is endless:**
- **Early escape:** in a hitstun longer than 0.6 s, from 0.6 s on you may **air-dodge, double-jump or up-recover**, and the
  rest of the hitstun ends. This is Smash's hitstun cancel, re-timed.
- **String decay:** a hit on a body already in hitstun belongs to a *string*. Each extra hit in the string has its
  hitstun ×0.8^(n−1), down to ×0.4 at most. So 3-5 hits are the practical limit, whoever hits.
- **Jabs end themselves:** each jab pushes 1.5-4.5 m, so a jab string walks him out of range in 2-3 hits.
- **Downed hits:** a hit on a body lying after a missed tech launches at set 5 m/s at 20° and stands him up (no "jab
  lock").
- **Hit-stop** (round 3 IMPACT, unchanged):
  - **The player:** only his pose holds. His launch starts at once, so his DI and aim are live from the first frame.
  - **A bot:** its hitstun starts after its pose hold, so the attacker's follow-up timing is the same against both.

---

## 6. DI: bend your flight

**Rule:** hold a movement key while you are launched and your flight turns toward it, up to 15°.

- **The direction:** the camera-relative world direction of W/A/S/D held is read **0.05 s after the hit**. Players get
  the same window: a player's launch starts at once, and a bot's after its hold.
- **The amount:** its part *across* the flight turns the flight's yaw by up to **di_deg 15°**. Its part along the flight
  does nothing.
- **Pitch:** never DI'd. The mouse is the aim and is never read for this.
- **3D meaning:**
  - Launched toward an end: DI toward the deck's long axis, so the flight runs along the deck instead of off it.
  - Launched toward a long side: DI along the deck. A 15° turn at 15 m/s moves the landing about 3 m.
  - DI into a wall (an earth wall, a pillar, a rope rail if the stage keeps it) gives a wall tech chance (§8).
- **Bots:**
  - Easy: DI 20% of the time, in a random direction.
  - Normal: 50% the right way (survival: toward the deck's middle).
  - Hard: 90%.

---

## 7. Combos: what makes a string

**Rule:** a combo is every hit landed on someone who has not yet left hitstun. The attacker's string counter counts hits
and %, and ends when the target acts.

- **True-combo windows** come from hitstun against the next move's lock plus its travel. Starting a lock the moment a
  shot leaves overlaps its flight, as in the Spike → Punch example in §2.
- **Starters by element** (round 2's bot combos, now real):
  - Kick → Punch (the jumper or the tumble);
  - Column → Spike;
  - Pull → Palm (Pull's set 6 m/s toward you, 0.28 s);
  - Geyser → Wave;
  - Wind Ball → Gust.
- **The counter is shown** on the attacker's own screen in Practice ("4 hits · 41%"), and in the match screen's tally
  ("longest string"). It is never drawn on anyone's body.

---

## 8. Tech: land on your feet

**Rule:** tumbling into the deck or a wall, press **E** within 0.3 s before contact and you tech. Miss it and you bounce
or lie down.

- **Deck tech:**
  - In place: stand at once, safe 0.25 s.
  - With A or D held: a tech roll 2.5 m that way, 0.4 s, safe for its first 0.25 s.
- **Wall tech** (an earth or ice wall, a pillar, a Column, a rope rail): stick and hop off (vy 3 m/s), safe 0.25 s.
- **Missed:**
  - Deck: bounce if falling faster than 6 m/s (vy × −0.3). Then lie 0.6 s, then get up: in place; or roll 2.5 m with
    W/A/S/D; or a get-up jab with LMB.
  - Wall: bounce off at half the flat speed, reflected. That is a combo chance for him.
- **No mashing:** an E press in tumble that didn't tech locks the tech out for 0.7 s.
- **Why E:** E is the guard. "E on the beat" is already the one timing every player learns, and in tumble there is
  nothing else to guard.
- **Bots:** tech 10% (easy), 40% (normal), 75% (hard).

---

## 9. What the % looks like (readability without cues)

- **The HUD** (a scoreboard, not a cue; the owner allows each competitor's own % and stocks):
  - One card per competitor along the bottom, yours on the left: the element's glyph, a big % figure and stock pips.
  - The figure warms from white (0) to yellow (60), orange (120) and red (180+), and grows a size above 120.
  - It shakes for 0.15 s when hit (on the HUD only).
  - The cleaner-HUD task builds the look. This part fixes what it shows.
- **Launch trails** (owner question 2): a launch of **trail_mps 15** or more (KO class) leaves a streak of the hitter's
  matter for the flight's first 0.5 s: dust for earth, spray for water, smoke for fire, wind lines for air. It comes with
  a deeper whoosh, the same for the player and the bots.
  - It is the hit's effect, like IMPACT's skid marks on the deck, and is meant to show "that one could KO".
  - It never follows a standing body. If the owner reads it as a cue on the enemy, the fallback is a bigger burst at the
    hit point only.
- **The KO moment:** IMPACT's RingMoment (0.6 s real at time scale 0.35, the splash at twice the speed) on every KO,
  plus a crowd roar. It is not repeated on the last stock's splash, where the match screen follows.

---

## 10. Stale-move decay: fresh moves hit harder

**Rule:** each competitor keeps the last 9 moves he landed on an opponent. Each copy of this move in that queue takes
part of its d away: 9%, 8%, 7%, ... 1% by its place in the queue, so 45% at most. A move not in the queue is fresh: ×1.05.

- **What counts:** only hits on an opponent count. Guards, whiffs and walls don't. A volley (3 Pebbles, 7 Embers) counts
  once.
- **It never touches a cast:**
  - the lock, the cast and the move's speed are unchanged;
  - only its % and, through d, a little of its launch fall (a Spike fully staled launches about 20% weaker);
  - "lock time is the only spam limiter" stands. This limits the payoff, not the button.
- **Never staled:** returns (earth's catch-return and the rally, Turn, Parry, Wind Guard), so the fun core is never worn.
- **Not hidden:**
  - the move's name on **your own strip** dims a shade at 2, 4 and 6 copies;
  - its hit sound is duller;
  - the lesson card says it in a line.
  - The queue survives a KO (Smash's rule) and resets at the match's start.

---

## 11. Heal (5) in a % game

**Rule (recommended; owner question 1):** **Patch takes 8% off your %** after a **1.5 s** lock, on the deck only (not in
the air), never below 0.

- It is a lock like any other: moving fills it slower, and a hit pushes it back by the hitter's lock time.
- At most it heals about 5% a second, against about 10%+ a second when someone presses you, so it can't stall.
- Its real use: while the opponent waits to respawn (about 2-5 s), two Patches take 16% off. That is a reward for the
  KO, not a turtle.
- Mend (earth and water, 5 tap twice) is unchanged.
- **Alternatives:**
  - cut Patch from ring play, so fire's and air's 5 is empty;
  - heal only the % taken in the last 8 s (a "grey %" in the card). Better for comebacks, but one more rule to read.

---

## 12. Stocks, the KO and the respawn

**Rules:**
1. **Each competitor has 3 stocks.** The % resets to 0 after each KO. The last one standing wins.
2. **KO:** touching the tank's water (RingWater.holds), or flying past the tank's far wall (RingArena.is_out). No other
   KO exists: no top line, no health, no winding.
3. **Credit:** the KO is the last knocker's within knock_credit_s (6 s). Otherwise it is a self-out. The stock is lost
   either way. Credit only feeds the stats, and later the team score.
4. **Respawn** (not after the last stock):
   - the splash and RingMoment;
   - **out_wait_s 1.6 s** (game time), with the body hidden and held;
   - he appears on a **water spout** rising out of the grate on his end's last line (s = 12 m, 5 m inside the open end),
     on whichever grate (z ±4 m) is farther from the nearest opponent, standing **3.0 m above the deck**;
   - he may stay up to **spout_s 3.0 s**, and drops as soon as he moves, jumps or casts.
5. **Safe window:** from appearing until **1.5 s after leaving the spout**, or until **his first cast leaves his
   hands**, whichever comes first.
   - While safe, hits pass through him: no %, no launch, no hitstun.
   - He looks **wet and dripping** (water running off his own body and a drip sound). It reads as "just out of the
     water", with no ring, outline or marker.
6. **No camping:**
   - the rising spout pushes anyone within 2.0 m of its foot out at a set 6 m/s (no %);
   - the respawner chooses when to drop, within 3 s, and onto which side;
   - he is safe 1.5 s after the drop;
   - the spout stands 5 m inside his end, not at the edge.
7. **The survivor** keeps his %.

**Timeline:** KO → 0.6 s real (moment) → 1.6 s → on the spout 0-3 s → 1.5 s safe. He is back in the fight 2.2 s to 6.7 s
after the splash.

---

## 13. The clock and sudden death

**Rules:**
1. **A game is 3 stocks on a 6:00 clock** (`stock.time_s` 360; Smash's 3-stock clock is 7:00). Default: one game a match.
   The Esc menu offers best of 3 games (to_win 2), with the ends swapped each game.
2. **At 0:00, more stocks wins.** Level stocks → **sudden death**:
   - both back at their spawns, 1 stock each, at **300%**, a 3-2-1;
   - the next KO wins;
   - at 300%, every class that grows KOs from anywhere (Punch: about 20 m/s), and jabs still don't.
3. **Stalemate breaker:** 20 s into sudden death with no KO, the deck's ends sink row by row toward the middle every 2 s,
   up to 10 m each end.
   - This is ARC's "closing tide" mechanic, reused here only; the owner's r3 answers superseded it as a match rule.
   - Only the deck's own boards move. No painted lines.
   - If sudden death reaches 60 s, it is a drawn match. That should never happen.
4. **Targets for the soak** (one knob each, never identities):
   - median game length 3-5 min;
   - time-outs ≤ 10%;
   - median stock life 50-90 s;
   - KOs in the water ≥ 90% of stock losses (the rest past the far wall);
   - each element's non-mirror win share 0.40-0.60;
   - the top KO move per element ≤ 0.35 of its KOs.

   **The knobs:** `pct_scale` (match length), `growth_scale` (KO %) and `decel_air` (recovery).

---

## 14. RingRules: what replaces the zones

**Rule:** a rule set picks the judge. **"stock"** (new default) judges %, stocks and the water. **"classic"** (today's
zones) is kept unchanged for one round, behind the Esc menu's Rules row, then deleted.

| Today (classic) | Under "stock" |
|---|---|
| zones, confined, soft walls, advancing (`_judge` confine, `_walls` soft wall, `forward_limit`, `may_enter`) | off: anyone may stand anywhere on the deck; `forward_limit` returns −INF; bots' `bounds_fn_for` clamps to the deck's ropes and ends only |
| the edge guard (walking never takes you off your end) | kept for **walking and running** (no accidental walk-off for the average player); a jump, a dash or a knock may leave the deck (the stage designer's call) |
| knock_scale × element_factor, max_push_m cap | `launch()`, §2-§4 |
| winded at 0 health, `_on_winded`, `_refill` | gone (no health in the ring) |
| ring-out = round over | `_ko()`: stocks − 1, respawn (§12), or the side out when every competitor of a side has 0 stocks |
| `territory()`, `health_frac()` at the time-out | `stocks_left(team)`, then sudden death (§13) |
| `knocked_back` signal, "Pushed back: zone 2" | `pct_changed(who, pct)`, `ko(who, by, pct, move, stocks_left)`, `respawned(who)`, `string_ended(by, hits, pct)` |

**The ring stays** `RingArena`: the zones' different stone and wood stay as the deck's look, and `zone_of` and `line_s`
are still used to place the spouts. Ring-out judging stays `is_ring_out`.

---

## 15. The screens

- **No round screen per KO.** A centre line for 1.4 s says *"Into the water: the Tide · 2 left"* (words in rules.json).
  The fight goes on.
- **Between games** (best of 3 only), RoundScreen shows:
  - "Game 1 · yours · 2 stocks left";
  - each KO's line: "1:12 · the Tide into the water at 134% · Boulder";
  - the tally.
- **MatchScreen:**
  - Victory / Defeat, stocks left on each side, a line per KO as above.
  - The tally: % dealt, KOs, self-outs, catches and clean catches, perfect guards, longest string (hits and %), techs,
    edge saves (from the movement designer's events), the move that took each stock.
  - Rematch, element, opponent and Main menu as today.
- **Every word** goes in data/ring/screens.json and rules.json words, with no show words (test_player_words reads them).

---

## 16. The bots in a % game (NpcBending, bend_ai.json)

- **Kill confirms:** a bot reads the foe's %, then picks a finisher (big shot, grown ▲, Boulder, Lightning) once
  `RingRules.ko_pct(tag, foe, dir)` is at or below the foe's %. Below that it builds % with quick shots and launchers.
  - Hard: always.
  - Normal: 60%.
  - Easy: never on purpose.
- **Combos:** its round-2 combos run only while the foe is in hitstun (`RingRules.stunned(foe)`). Hard bots start the
  next lock as the first shot leaves.
- **Its own %:** above 120% it guards more (+0.15 react), keeps 6 m more from an end, and patches when the foe is waiting
  to respawn.
- **DI and tech chances:** §6 and §8.
- **Threat size:** `threats()` rates a shot by `launch_preview(tag, me)` at its own %, instead of the spec's flat
  knock_mps.
- **On the spout** it drops after 0.4-1.2 s (preset) toward the side away from the foe.
- Recovery and edge play are the movement designer's (`edge_fn` and `bounds_fn` stay the contract).

---

## 17. 3 v 3 later

- **Stocks:** each competitor has his own, **2 each** in 3v3 (6 a side), with a 7:00 clock. A competitor with none left
  spectates. A side with none left is out: today's knockout and side_out.
- **Allies:** they never add % or launch each other (BendStatus.can_take, as now). Ally bolts pass.
- **Spouts:** three at each end, one per slot (z −4, 0, +4 m on the s = 12 m line); each respawner gets the one farthest
  from the nearest foe.
- **Strings and staleness:**
  - string decay counts **every attacker** on that body, so two can't juggle one forever;
  - each competitor keeps his own stale queue.
- **HUD:** six cards, your side's left. Sudden death: the survivors only, at 300%.
- **The ledger is per competitor** in RingRules.state, so nothing changes shape between 1v1 and 3v3.

---

## 18. Practice

- **Practice:** % shown, no stocks and no clock.
  - R puts both back and zeroes both % (R and B are the owner's, unchanged).
  - The practice panel gets "Dummy at: 0% / 60% / 120% / 180%", applied at each R, so a player can feel KO launches and
    try DI against the throw dummy.
- **The string counter** shows top centre in practice only.
- **Lesson cards:**
  1. "Every hit raises your %. The higher it is, the farther you fly. Into the water and you lose one of 3."
  2. "Flying? Hold A or D to bend your flight."
  3. "Press E just before you hit the deck to land on your feet."
  4. "The same move again and again hits softer: mix them."

---

## 19. How an average player learns it, and what mastery looks like

**Learning (first match):**
- the big % under his card climbing, and the bot flying farther as its number reddens;
- being KO'd once;
- rising on the spout wet;
- a hint "Hold A or D while flying to bend your flight" the first time he is launched over 10 m/s;
- "E just before you land" the first time he lies down.

Easy bots barely DI or tech, so his first KOs come at the table's %.

**Mastery:**
- **DI** for 15-25% more life;
- **techs and wall techs**, so a combo never starts;
- **the early escape** from long tumbles;
- **knowing KO %** (when the grown Shove kills, saving the Boulder fresh);
- **true strings** inside hitstun (Kick → Punch at 40-90%, Column → Spike);
- **stale management;**
- **rally stones** as KO threats;
- **down hits** off the edge;
- **Rooted** to shrug pokes at the lip;
- **Carried wind** kills;
- **choosing** when to drop off the spout.

---

## 20. Risks

1. **Side KOs dominate.** The deck is 14 m wide and 34 m long. KO % toward a long side from the middle is about 70% of
   the toward-an-end figure (Boulder 76% vs 114%). Players will aim launches sideways.
   - Accept it as a narrow stage (DI along the deck answers it), or the stage designer widens the deck to about 18 m.
   - Long-side rope rails don't stop KO-speed launches: they pass above 2.5 m at the rail.
2. **Shallow water.** The water is 1.4 m under the deck: a body falling past the lip has about 0.5 s. Recovery from
   below the lip lives on the edge grab's reach (1.2 m down assumed).
   - If the stage designer lowers the water or counts the KO only deeper, every KO % here rises and needs a re-run.
3. **Projectile edge-guards** (Spear, Lightning, Slice at a helpless recoverer) may feel oppressive. Counters:
   - the edge grab's own safe frames (movement designer);
   - DI;
   - Lightning's 0.25 s flash;
   - stale decay on spammed shots.
   Watch "KOs on helpless bodies" in the soak.
4. **Juggle loops** (Column / Geyser at 85°) are answered by:
   - string decay (×0.8 a hit);
   - vy_cap 14;
   - the early escape at 0.6 s;
   - Column's 1.6 s lock.
   Test a scripted Column → Spike → Column loop: it must break by the 4th hit.
5. **Readability in 3D.**
   - A body launched toward the camera fills the screen. The camera must keep the mouse's yaw while you tumble (never
     spin with the body) and pull back with the launch speed (READ / IMPACT).
   - Judging the foe's % needs the HUD: big, warm-coloured figures.
6. **Hitstun versus the owner's rule.** Stated plainly (§5). If the owner still reads hitstun as "slowing the player",
   the fallback is player hitstun ×0.6 with movement keys allowed at half drift. Combos then shrink.
7. **Match length.** At round 1's hit rates (about 9 hits a minute a side), 3 stocks could run 6+ min. `pct_scale` is
   the knob. Measure first.
8. **Hidden numbers.** Stale decay and weights are new numbers. Stale decay shows on the strip, and weights go in the
   element pick's one line ("Earth: heavy, hard to throw out").
9. **Shared player controller.** Every ring behaviour is gated by the ring's installed rules: BendKnock.rules is a
   RingRules with `stock_rules()` true. With the rules gone, the open world is byte-for-byte as before. Pin this in a
   test.

---

## 21. Code it touches (by file; who owns each is the round-3 planner's call)

- **data/ring/rules.json:** a `rule_set` ("stock" default, "classic") and a `stock` block holding:
  - stocks, time_s, sudden_pct 300, sudden_tide_after_s 20, sudden_cap_s 60;
  - the curve and scales: pct_scale, growth_scale, curve_k 13, curve_s 35;
  - tumble_mps 6, vy_cap 14, decel_air 3.0;
  - hitstun_k 0.05, hitstun_min 0.12, hitstun_max 1.2, set_stun 0.28, escape_s 0.6;
  - string_decay 0.8, string_floor 0.4, di_deg 15, di_read_s 0.05;
  - tech_s 0.3, tech_lock_s 0.7, tech_roll_m 2.5, lie_s 0.6;
  - trail_mps 15;
  - weights {earth 1.25, water 1.0, fire 0.95, air 0.8};
  - stale [0.09 … 0.01], fresh 1.05;
  - classes {§3 table}, late_mult 0.5, return_mult 1.2;
  - patch_pct 8, patch_lock_s 1.5;
  - respawn {out_wait_s 1.6, spout_s 3.0, safe_after_s 1.5, spout_up_m 3.0, spout_s_m 12, clear_m 2.0, clear_mps 6};
  - words.
- **scripts/ring/ring_rules.gd:**
  - The ledger: `pct_of`, `stocks_of`, `add_pct`, `on_hurt` (the untagged curve), `on_hit(n, dmg, v, by, tag, mult,
    returned)`.
  - `launch()`, `launch_preview(tag, body)`, `ko_pct(tag, body, dir)`, the stale queues, strings.
  - `stunned(body)`, `_ko`, the respawn and safe state, `stocks_left`.
  - The rule-set switch, which skips confinement, soft walls, advancing, winding and territory under "stock".
  - `knock_scale` stays for classic.
- **scripts/ring/ring_mode.gd:**
  - the stock game flow: KO lines, the respawn timer and the spout, the 6:00 clock, sudden death and its tide;
  - best-of-games, history per KO, the new signals;
  - the contract adds `pct_of`, `stocks_of` and `safe_of`.
- **scripts/ring/ring_arena.gd:** `spout_at(side, slot)` (the grates on the s = 12 line), the spout visual (water column,
  own procedural FX via BendLooks/ToonFx), and the sinking end rows for sudden death (from ARC if built).
- **scripts/ring/ring_water.gd:** unchanged API. `splash()` per KO.
- **scripts/bending/bend_knock.gd:**
  - `stun_t` (hitstun) next to knock_t;
  - a per-launch `air_decel` (from `rules.air_decel()`, default AIR_DECEL);
  - `tumble`, `di_at` and `apply_di(dir)` (a one-shot yaw turn), tech (`tech_until`, `tech_lock_until`, `on_contact()`
    from after_slide when tumbling), `lying_t`;
  - `knock()` asks `rules.launch_for(n, v, by)` when present.
  - IMPACT's `hold(s)` delays the stun start for bots.
- **scripts/bending/bend_status.gd:**
  - `strike(n, dmg, v, at, dir, by, tag := "", mult := 1.0, returned := false)`: the one entry that hands both to
    `BendKnock.rules.on_hit` in the stock ring (the % first, then the launch reads the % after). Elsewhere it is exactly
    `hurt()` then `knock()`.
  - `can_take` also refuses a body that is safe (RingRules.safe).
- **scripts/bending/bend_bolt.gd, bend_effects.gd, bend_zone.gd, bend_throw.gd; sway/gust_lift.gd, form_effects.gd,
  form_stone.gd:**
  - every hurt + knock pair becomes `BendStatus.strike` with the class tag `id/mode` (`.grown` when grown);
  - bolts and stones carry `tag`, `ret_mult` and `returned` through `redirect()` and the earth return;
  - the late guard passes mult 0.5;
  - the Fire Wall's entry pop and its % ticks.
- **scripts/bending/bend_cast.gd:** passes the tag through to BendEffects (it already records the move and mode in
  `last_of`).
- **scripts/player/player.gd** (SHARED, so everything is gated on `RingRules.stock_active()`):
  - `apply_hit` routes to `rules.on_hurt` (health untouched) under no_death;
  - while `kn.stun_t > 0`: no steering (today's `reeling` already zeroes the target), no jump, the DI read;
  - E in tumble techs;
  - lying and get-up;
  - the spout hold;
  - hiding and holding while out.
- **scripts/npc/npc_fighter.gd:** the same as the player (`apply_hit` → `on_hurt`; stun, tech and lying by chance; the spout).
- **scripts/sway/sway_caster.gd:** a release during hitstun is kept and fires at its end; the lock keeps filling.
- **scripts/npc/npc_bending.gd:** kill confirms, string timing on `stunned`, DI and tech chances, `launch_preview`
  threats, its own-% caution, the spout drop.
- **data/npc/bend_ai.json:** di_chance, tech_chance, confirm_chance by preset.
- **scripts/ui/match_bar.gd:** the zone strip is hidden under stock rules. The clock stays, and the % cards plus stock
  pips appear (or the HUD task's new panel reads the same contract).
- **scripts/ui/bend_strip.gd:** the stale dimming.
- **scripts/ui/round_screen.gd and match_screen.gd, data/ring/screens.json:** §15.
- **scripts/ring/match_setup.gd, ring_menu.gd:** rule_set, games (1 or best of 3), the practice "Dummy at %" row.
- **data/sway/moves.json:** Patch's `pct` 8 and the stock lock. Everything else is read from rules.json's classes, so
  moves.json keeps its open-world numbers.

---

## 22. Owner questions (this part)

1. **Heal (5):** Patch −8% after a 1.5 s lock (recommended), cut from ring play, or "heal only recent %"?
2. **Launch trail** on a body flying at KO speed: an effect of the hit (recommended), or too close to a cue on the enemy
   (fallback: a bigger burst at the hit point only)?
3. **Stale decay** (the same move landed again and again gives less %, shown by your strip dimming; casting is never
   limited): OK, given "lock time is the only spam limiter"?
4. **Hitstun:** you can't steer, jump or let a cast go while launched (0.15-0.4 s at low %, up to 1.2 s near KO); camera,
   aim and your lock are never touched; a release fires the instant it ends; DI, tech and the 0.6 s escape always work.
   Is that "the sport, not a debuff"?
5. **The clock:** 6:00 for 3 stocks (instead of 180 s rounds), one game a match, best of 3 on the Esc menu?
6. **Sudden death** at level stocks (both at 300%), or "lower % wins" first as Smash's competitive rule?
7. **Weights:** earth heavy (lives about 20% longer), air light (about 15% shorter). OK? The earth mirror gets longer.
8. **The narrow deck:** side KOs come at about 70% of end KOs. Keep 14 m, or widen it (with the stage designer)?
9. **3v3:** 2 stocks each, 7:00?
