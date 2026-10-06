# Tidebreak round 3, the Smash layer: MOVEMENT AND THE EDGE (design, read-only)

The owner (2026-10-05): "instead of a knock back we should implement a smash bros 100% plus like arena out system we
should give everyone all movement options and in air options and combos". He chose to keep the number keys, 3 stocks,
and full recovery (double jump, air dodge, an up-recovery per element, grabbing the deck's edge; out only in the water).

This part covers every element's movement, defence and edge: the run, jumps, double jump, fast fall, air dodge, ground
dodges, the guard as a shield, crouch, the deck edge in 3D, the up-recovery per element, how key 3 fits, the camera off
the deck, mode gating in the shared player.gd, and the clips. The % and launch formula, the aerial versions of the casts,
combos, stale moves and the HUD belong to the other round-3 parts. Where this part needs them, the contract is stated.

Checked against: critic_r2/owner_answers_r3.md; skills_r2/spec.md with owner_answers.md and the four round-2 task files;
docs/bending_design.md; scripts/player/player.gd (the jump at 1293-1298, gravity, the clip speed caps, the camera, the
`arena` flag, traversal and grip installed at 449-452); scripts/bending/bend_knock.gd, bend_status.gd (can_take is the one
choke point for hurt and knock), bend_motion.gd; scripts/ring/ring_rules.gd (the edge guard in `_walls`), ring_arena.gd,
ring_water.gd and data/ring/ring.json (deck 34 x 14 m at y 0, water at -1.4, out at -0.6, tank margin 6 m, rope rails on
the long sides, the walk round the tank at deck height); scripts/npc/npc_fighter.gd (`_move`: no jump, gravity 18, the
-0.5 floor clamp); critic_r1.json (the camera item); the review images (assets_arena_noon_overview.png: the deck stands
about 1.4 m over the water). Nothing in the project was edited, and Godot and Blender were not run.

The user also asked how many moves each Smash fighter has. A Smash fighter has about 20-25 attacks: a jab (1-3 hits or
a rapid jab), three tilts, a dash attack, three smash attacks, five aerials, four specials (neutral, side, up, down), a
grab with a pummel and four throws, the ledge and getup attacks, and a Final Smash. On top of those, everyone shares the
same movement and defence set. A Tidebreak element has about 11-12 casts on the round-2 keys: Jab, 1 and its other move,
2 and its other move, 3 and its other move, 4 (plus fire's Breath on 4 tapped twice), 5 (plus Mend for earth and water),
and the E guard with earth's return. This layer adds the air versions of those casts (another part), the air dash, the
Rise, the edge attack, and the shared set below.

---

## 0. The short version (what an average player is told)

- **Space** jumps. Tap it for a small hop, hold it for a full one. **Space again in the air** jumps once more. **Space a
  third time** is your **Rise**: your element lifts you. After the Rise you can only drift until you land or grab the edge.
- **Ctrl**, the "down" key, crouches on the deck and falls fast in the air. While you hang, it lets go of the edge.
- **E** is your guard on the deck: on the beat it's yours, and late, half gets through. Keep E held and the guard stays up.
  **With the guard up, tap a direction to Roll, or press Ctrl to Duck. In the air, E is a Dodge.**
- **Fall off and you grab the edge** automatically. From there, **W climbs, Space jumps, E rolls in, and left click
  attacks**. Ctrl lets go.
- **Landing, grabbing the edge, or getting hit gives you back your air moves.** You are out only in the water.

These seven lines are the whole layer. The numbers below are starting values in a new `data/ring/movement.json`, tuned by
the soak.

---

## 1. Physics of the ring (stocks mode only)

**Rule:** in the stocks ring, everyone falls and runs on the same snappier numbers, and the open world keeps its own.

| Number | Value | Why |
|---|---|---|
| gravity | **20 m/s²** for own falls **and** launches (BendKnock.launch_gravity() returns the ring's while the stocks ring stands) | today's 9.8 with a 4.4 m/s jump gives a 1.0 m apex and 0.9 s of float; arena fighters need quick, readable arcs |
| per-element gravity | earth ×1.1, water ×1.0, fire ×1.0, air ×0.85 | weight you can feel; the % part's own weights sit on top |
| max fall | 11 m/s (air 8) | |
| fast fall | 17 m/s (earth 18, air 14) | |
| run | **5.0 m/s** (from 3.6); Shift sprint 6.5 m/s | a 34 m deck end to end takes 6.8 s at a run |
| ground accel / decel | 40 / 30 m/s² (full speed in 0.13 s, a stop in 0.17 s) | snappy; **the start and stop clips' body-speed caps are off in the stocks ring** (override_free_start_speed and override_crisp_stops behaviour), or the legs slow every dodge |
| air drift | earth 3.5 m/s at 12 m/s² · water 4.0 at 16 · fire 4.5 at 20 · air 4.5 at 16 | today's air_accel 2.5 is far too little for recovering or influencing a launch; KNOCK_AIR_CONTROL 1.0 applies only during hitstun |
| full hop | apex **2.0 m** (v0 = 8.94 m/s at g 20), the same height for every element | "Space feels the same for everyone" |
| short hop | apex **0.8 m**: let go of Space within **0.12 s** of takeoff and vy is capped to sqrt(2g·(0.8 − h)) | a variable jump (tap small, hold big) with no 3-frame jumpsquat, so it is easy |
| jumpsquat | none: the takeoff is immediate | responsive; jump out of guard is instant |

The round-2 floor rule still reads the same, with new timing. The Kick misses feet more than 0.6 m above the deck. A full
hop clears 0.6 m from 0.07 s to 0.82 s after takeoff (a 0.75 s window; today's jump gives 0.56 s). A short hop clears it
only from 0.14 s to 0.43 s (0.28 s). So the full hop is the easy answer and the short hop is the tight one. CORE's
open-world test (jump_velocity 4.4, the body missed 0.2 s before contact) stays as it is, and a stocks test is added
beside it.

**Learn:** nothing to learn. Jumps feel higher and land sooner. **Master:** short hops under a Kick wave, then a cast at
the low apex. **Risks:** the gravity change also changes the launches' arcs. The RULES part's launch scripts (smash_r3/launch_sim.py)
fit their table at G = 9.8, so they must be refit at g 20, or the parts agree on one other value. There must be ONE
gravity for own falls and launches, for both bodies, or a launched body floats and then drops. Round 2's floor-wave and Lightning tests need a stocks twin. **Code:** a new
data/ring/movement.json; RingMoves.profile(); player.gd reads it only when `ring_moves != null`; BendKnock.launch_gravity()
gets a ring override (`static var gravity_override := 0.0`) that RingMode sets and puts back.

---

## 2. The double jump

**Rule:** one extra jump in the air, refreshed by landing, grabbing the edge or getting hit.

- Height **1.6 m** from where you are: vy is SET to sqrt(2·g·1.6), not added. Earth 1.4 m, air 1.9 m.
- Horizontal: your velocity snaps toward the held direction at the element's air drift speed (a Smash-like redirect).
  With nothing held you keep 50% of it.
- Usable mid-lock: Space never drops a lock, as in round 2.
- Not during hitstun, helpless, a dodge's travel, or landing lag.
- Element flavour, on yourself only, sound and effect:
  - earth: a stone slab pops under your feet and crumbles in 0.3 s. You can't stand on it and it has no collider.
  - water: a ring of splash at your feet.
  - fire: a jet burst from both feet.
  - air: a gust ring and a whistle.

**Learn:** "Space again in the air." **Master:** a double jump that turns your drift back toward the deck; a short hop,
then a double jump for an aerial at a chosen height; saving the double jump through a recovery. **Risks:** players
burning it at once off-stage. The lesson card (§13) teaches holding it. **Code:** RingMoves.jumps_left;
`RingMoves.on_jump_pressed()` replaces player.gd 1293-1296 when ring_moves is set.

---

## 3. Fast fall

**Rule:** past the top of a jump, press Ctrl to fall at once at fast-fall speed.

- vy = −fast_fall (17 m/s; earth 18, air 14) once vy ≤ 0.5. It holds until you land, jump or dodge.
- Allowed while helpless (to reach the edge sooner), but not during hitstun.
- A Leap or Updraft glide ends on Ctrl.

**Learn:** "Ctrl is down." **Master:** short hop, cast, fast fall: the aerial's landing lag comes sooner and the string
continues. **Risks:** fast-falling past the edge off-stage. Holding Ctrl also stops you grabbing the edge, by design: down
means down. **Code:** RingMoves; crouch becomes a hold, not a toggle, in the stocks ring (player.gd 1183-1193 branch).

---

## 4. Crouch

**Rule:** Ctrl held on the deck crouches in place. It is the "down" key everywhere, with no hidden numbers.

- Standing still, with a capsule height of 1.1 m (crouch_height): you can turn, aim and cast.
- Nothing more: no crouch-cancel and no knock reduction.
- Ctrl is down everywhere: crouch on the deck, fast fall in the air, Duck with the guard up, let go while hanging.

**Learn:** obvious. **Master:** a lower body makes a standing-height Punch line miss you. A human who aims low still hits.
**Risks:** bots aiming at the chest miss a crouching player, so the bots aim at the capsule's middle (NpcBending).
**Code:** player.gd crouch branch, gated.

---

## 5. The guard as a shield (E), one button

**Rule:** E raises your element's round-2 guard after its short lock. It stands as long as E is held (up to 2.5 s), or
for its round-2 window if tapped. On the beat it's yours; after that, half gets through.

| | |
|---|---|
| raise | press E: the round-2 lock (earth 0.2, water 0.2, fire 0.15, air 0.2) and the guard stands **the moment it is up**. It no longer waits for the release (§10 for round 2) |
| perfect | a hit within **0.3 s** of it standing: round 2's per-element reward (earth's clean catch and fast return; water's Turn; fire's straight-back Parry, lightning included; air's bounce and Carried wind) |
| tapped | let go before it stands, or a click: it stands for its round-2 window (earth 1.0 s, the others 0.8 s), then drops |
| held | it stays up while E is held, **up to 2.5 s**, then drops |
| late | **half the hit's % and half its launch get through, as a slide along the deck, never a launch into the air** (no tumble while the guard stands). At high % a late-guarded hit can still slide you off the edge, so turtling at the lip loses |
| whiff | round 2's rule: a guard that took nothing makes your next guard's lock 0.5 s within 1.5 s. A held guard that took nothing counts too |
| moving | you can't walk while it stands (your choice, not a debuff). You can turn and aim |
| out of it | **Space** jumps at once (jump out of guard). **A fresh tap of W/A/S/D** Rolls. **Ctrl** Ducks. **Any cast key** drops the guard (0.1 s) and starts that key's lock, as round 2's "another key" rule |
| earth's stone | a catch ends the guard with the stone held. **E again throws it back** (round 2). With a stone in hand, E always throws, on the deck or in the air, before any dodge |
| in the air | there is no guard in the air. **E in the air is the Dodge (§7)** |

There is no shield meter and no shield-break stun: the stun would be a debuff, and lock time is the only limiter. Holding
the guard is beaten by the half-through rule, by the 2.5 s cap and the whiff rule, and by moving around it in 3D.

**Learn:** "E: on the beat it's yours. Late, half gets through. Hold E to keep it up." **Master:** a perfect guard from a
held guard needs a fresh E, so the mastery is pressing E late (0.2 s before impact) rather than holding it. Further
mastery: jump out of guard into an aerial; a guard, then a roll behind a wall. **Risks:** E carries six meanings (guard,
Roll, Duck, Dodge, edge Roll, Tech, plus earth's throw back). They are all "defend", as Smash's shield button, and each
takes its meaning from its context (deck, guard up, air, hanging, tumbling, stone in hand), which the player can see.
**Code:** SwayCaster SRC_GUARD (round 2): stand-at-fill instead of stand-at-release when RingMoves is present;
`hold_max_s` in BendZone; the late-half launch becomes a ground slide (BendKnock `slide_only` flag); RingMoves reads
guard_up for the Roll and Duck.

---

## 6. Ground dodges: Roll and Duck

**Rule:** with the guard up, tap a direction to Roll that way, or press Ctrl to Duck in place. Both pass through hits for
a moment.

| | Roll | Duck (spot dodge) |
|---|---|---|
| input | guard up (or within 0.1 s of pressing E) + a **fresh** press of W/A/S/D. Keys already held when E went down do not roll | guard up + Ctrl |
| travel | **3.5 m in 0.45 s** along the camera-relative direction tapped; your facing (the aim) does not change | none |
| intangible | 0.05–0.30 s | 0.04–0.30 s |
| end lag | 0.15 s (total 0.6 s) | 0.15 s (total 0.45 s) |
| repeat | each Roll or Duck within 1.0 s of the last one's end adds +0.1 s end lag, up to +0.3 s (felt, not shown) | same |
| edge | a Roll stops 0.3 m inside the lip and never carries you off | — |
| bodies | the roll collides with bodies (no pass-through), so 3D cross-ups stay readable | — |

Intangible means BendStatus.can_take(n, by) returns false while `RingMoves.intangible(n)`. That one check covers
BendBolt, BendEffects, hurt and knock, so bolts fly through, not into, the dodger. No glow or outline is drawn on the
dodger: the dodge reads by its clip and a short element puff at its start (dust, splash, ember, wind), on himself, as
round 2's own-body looks.

**Learn:** "Guard up, tap a direction: Roll. Ctrl: Duck." **Master:** rolling behind a slow Boulder; a Duck timed
through a Lash then a punish; not rolling twice in a row (the repeat cost). **Risks:** roll spam is held back by the
repeat cost and the 0.15 s end lag. In 3D, a roll toward the camera can hide the body, so the camera keeps its own
distance (§12). **Code:** RingMoves (moves the body itself, `owned` like traversal); BendStatus.can_take (one line);
player.gd input dict.

---

## 7. The air Dodge

**Rule:** E in the air dodges the way you hold, or in place with nothing held. You get one per airtime, it does not leave
you helpless, and it has landing lag if it lands.

| | Directional (W/A/S/D held at the press) | Neutral (nothing held) |
|---|---|---|
| travel | **3.2 m flat in 0.22 s** (14.5 m/s), gravity off during it, vy 0 after | keeps 30% of your velocity, gravity on |
| intangible | 0.04–0.30 s | 0.04–0.40 s |
| end | 0.28 s with no actions (drift and gravity on, no edge grab until the travel ends) | 0.15 s |
| landing during it or its end | **0.3 s landing lag** | 0.15 s |
| count | one per airtime, refreshed by landing, the edge or a hit | same |

- It is flat and has no up or down part: a keyboard has no vertical axis in the air, and Space and Ctrl already mean jump
  and fall. The height comes from the double jump and the Rise.
- E in the air drops a running lock, as E always does in round 2.
- With a caught stone in hand, E throws it instead (§5).

**Learn:** "In the air, E dodges." **Master:** a dodge through an edge-guarder's Spike, then the edge; a neutral dodge
to bait the guarder's swing; landing a directional dodge onto the deck early enough that its lag is over before he
arrives. **Risks:** a Dodge that is helpless too would trap new players, so it is not; one per airtime plus the 0.28 s
end keep it honest. **Code:** RingMoves.

---

## 8. The edge (the deck's whole perimeter, in 3D)

The lip is the deck's top outer rectangle (34 × 14 m, 96 m round), at deck_y. All four sides are open in the stocks ring:
**no rope rails** (owner question 2).

### 8.1 The grab

**Rule:** falling near the lip, you catch it automatically and hang facing the deck.

- **Grab point:** the body's head (origin + 1.6 m).
- **Grab box:**
  - Outward from the lip line: −0.3 m (just over the deck) to +0.9 m.
  - Height: lip − 0.5 m to lip + 0.6 m, so the feet are between lip − 2.1 m and lip − 1.0 m.
- **Allowed when:** airborne, vy ≤ 1.0 (falling or near the top), not in hitstun, not in a Dodge's travel, Ctrl not
  held, and not within 0.4 s of letting go. A Rise may grab once its startup has run plus 0.2 s.
- **Snap:** feet at lip − 2.0 m, 0.35 m out from the deck face, the body turned to face the deck. The camera is not
  turned (the aim is yours).
- **Corners:** within 0.5 m of a corner, the grab slides 0.5 m along the nearer side.
- **Walls:** a wall standing within 0.5 m of a lip spot blocks grabbing there. Earth can wall off the nearest spot.
- **Refresh:** a grab gives back every air move: the double jump, the Dodge, the air dash and the Rise.
- **The deck face:** the face under the lip is not climbable. PlayerTraversal and PlayerGrip are not installed in the
  arena, so the open world's vault, hang and grip never touch the deck (§11).

### 8.2 Hanging and the edge's invincibility

| | |
|---|---|
| first grab since you last stood on the deck | **intangible 0.6 s** from the grab |
| a regrab before you touch the deck again | **0 s**: it does not refresh until you land (Smash's rule, against planking) |
| hang time | **4.0 s**, then you let go automatically |
| settle | 0.15 s (the catch clip) before an option can start |
| hit while hanging (after the intangibility) | his hands and head stick 0.4 m over the lip. Any cast that reaches them hits: the Kick's floor wave washes over the lip, and stones, bolts and Lashes aimed at him hit too. A hit makes him let go and launches him as normal for his % |

### 8.3 Edge options

| Input while hanging | Option | Numbers |
|---|---|---|
| **W**, or any camera-relative direction within 60° of "into the deck" | **Climb** | 0.5 s, intangible 0–0.35 s, ends standing 0.6 m inside |
| **E** | **Roll in** | 0.75 s, intangible 0–0.55 s, ends 3.0 m inside |
| **Space** | **Jump up** | vy 11.8 m/s (the feet rise from lip − 2.0 to about lip + 1.5 m), 2 m/s inward drift, intangible 0–0.12 s; every air move is kept |
| **Left click** (Jab) or right click | **Edge attack** | 0.6 s, intangible 0–0.30 s; a low sweep 2.0 m into the deck at deck height, 7%, a low launch away from the edge. Per element: earth a stone sweep, water a splash sweep, fire a low flame kick, air a palm gust |
| **Ctrl**, or a direction pointing out over the water | **Let go** | the hang's intangibility ends at once; every air move is kept (refreshed by the grab) |
| nothing for 4.0 s | let go | the next grab before you land has no intangibility |

Each edge option has its own intangible time, so an edge-guarder can punish only its end, and has to guess which option
is coming.

### 8.4 One hanger per edge spot, and edge-hogging in 3D

- **Rule:** a hanger holds 1.2 m of lip on each side of him. Nobody else can grab inside that stretch; they fall past or
  grab further along. **There is no trumping** (pushing a hanger off by grabbing his spot).
- **Why:** in 2D the stage has two ledges, so whoever holds one denies the recovery. In 3D the lip is 96 m long, and a
  recoverer can always pick a point 1.3 m along, so hogging is not a strategy here and trumping would add a rule without
  a payoff.
- **What replaces hogging:**
  - covering the lip point nearest the recoverer (he has to come there);
  - hitting the hanger's hands once his 0.6 s is over;
  - waiting out his intangibility and reading his option (climb, roll, jump or attack);
  - a wall raised on his nearest spot;
  - jumping off to meet him in the air.

**Learn:** "Fall off and you grab the edge. W climbs, Space jumps, E rolls in, left click attacks." The edge options
are the same keys as on the deck (W forward, Space jump, E defend, click attack). **Master:**
- Letting go, double jumping, then an aerial (an edge drop into an attack).
- Mixing the four options and the timing.
- Regrabbing after a fake drop costs your intangibility, so you think before you let go.
- Reading which lip point he must come to, and getting there first.

**Risks:**
- **Planking** (hang, drop, regrab to run the clock): held back by no intangibility on a regrab, the 4 s hang, the 0.4 s
  regrab delay, and the match timer's sudden death (the rules part).
- **Corners:** recovering to a corner is the hardest spot to read.
- **3D readability:** the hanger is below the lip. The guarder sees only the hands and head, so the hang clip keeps
  both clearly over it.
- **The deck must be raised** (§8.5), or hanging puts the feet in the water.

**Code:**
- RingArena.nearest_lip(pos) → {point, normal (outward, flat), out_m (signed), side, along}; lip_y(); lip_free(point, who)
  for the occupancy.
- RingMoves: the grab, the hang, the options and the occupancy table on RingArena.
- BendBolt's floor_wave runs on over the lip by 0.3 m so that it reaches the hands.

### 8.5 The deck must stand higher over the water (geometry)

- **The problem:** the water is 1.4 m under the lip (ring.json water_y −1.4), and today a body is out at 0.6 m under
  the lip (out_drop_m). A hanging body's feet are at lip − 2.0 m, under the water, so recovery from below the deck
  cannot exist. The walk round the tank is at deck height, 6 m from the deck, so a sideways launch lands on dry stone.
- **The fix:** a `stocks` overlay in ring.json that RingArena and RingWater read when the stocks rules are on:

```json
"modes": {"stocks": {"water_y": -6.0, "floor_y": -9.0, "out_drop_m": 6.0, "tank_margin": 14.0, "ropes": false}}
```

  - The deck stands as a stone tower **6 m** over the water. That leaves room for the hang (2 m) and for a recovery from
    under the lip (up to about 4 m below the hang).
  - **Out is the water only:** RingWater.holds, or under water_y.
  - The tank grows to 14 m all round, so a normal launch comes down in the water.
  - **The tank wall line:** a body that crosses over the tank's outer wall in the air is out at that line ("over the
    wall"), and is never left standing on the walk. The other choice is a falling-water curtain on the tank's outer wall
    that sweeps him in, which keeps "only in the water" literal but needs its own art (owner question 3).
  - **No sky line:** a launch straight up comes back down onto the deck. The % part keeps launch angles at 65° or less
    above flat, so KOs happen sideways (owner question 4).
  - The stands and the end walls move out with the tank. The before and after need images for the owner's eye.

**Code:** ring_arena.gd (a mode overlay on num(), `_ropes()` skipped, nearest_lip), ring_water.gd (the deeper area, the
splash from height), ring_rules.gd (stocks: zones, soft walls, winded and the territory time-out off; the edge guard
replaced by the teeter of §9; is_ring_out = water or the tank wall line).

---

## 9. Walking off the edge: the teeter

**Rule:** running never carries you off the deck by accident. To leave on purpose, hold toward the water for 0.3 s
(you teeter at the lip meanwhile) or jump off.

- It replaces today's edge_guard_m (0.35 m, ring_rules `_walls`) on all four sides in the stocks ring.
- Key 3's dashes and Rolls also stop 0.3 m inside the lip, as round 2's dash test pins.
- Knocks and launches always carry you over.

**Learn:** you can't fall off by strafing while you aim (the camera is behind you, and the water to your side is easy to
forget). **Master:** stepping off on purpose to edge-guard in the air. **Risks:** a 0.3 s teeter reads as a stall; the
teeter clip shows the lean, so the opponent sees it as a commitment. **Code:** RingMoves (the teeter timer);
ring_rules.gd `_walls` keeps the soft walls for the zone rules and skips the edge guard when RingMoves is present.

---

## 10. The up-recovery: the Rise, one per element

**Rule:** Space a third time in the air (after the double jump), or key 3's other move cast in the air, is your
element's Rise. It lifts you a long way once per airtime, and you are helpless after it until you land or grab the edge.

Helpless means you can only drift (at 60% of your air drift), fast fall, and grab the edge. There are no jumps, dodges,
casts or Rises. Landing from helpless gives **0.35 s** landing lag. The helpless fall has its own clip (a loose,
arms-trailing fall), so the opponent reads it at once without a cue. The player-facing name is "Rise", with each
element's own word in its card.

| Element | Name | Startup (the tell) | Travel | Steering | Hits | Character |
|---|---|---|---|---|---|---|
| **Earth** | **Pillar** | 0.20 s: the water bulges under you (or the deck face cracks if you are within 1.5 m of it) | a stone column shoots up from the water to your feet and carries you **5.5 m straight up** in 0.45 s, then pushes you off its top (vy 3) and sinks after 0.4 s. It is never a platform | 30% drift | its top and sides strike whoever it rises through: 8%, launch up | the most height and a strong hit, almost no sideways reach, and a readable startup |
| **Water** | **Fountain** | 0.12 s: a gurgle under you | a column of water lifts you **4.5 m** in 0.55 s | full drift (4 m/s) | a wide (1.2 m) weak push away: 3%, 6 m/s, no launch up. It clears an edge-guarder; it doesn't KO | steerable and safe, middling height |
| **Fire** | **Jet** | **0.25 s hovering in place** (vy 0) while flames gather at the feet. Punishable | a burst of **7.5 m along your aim** in 0.35 s (pitch clamped from −30° to +90°) | the aim at the end of the startup | the trail behind burns: 5%, small push | the longest reach in any direction, the most obvious startup |
| **Air** | **Updraft** | 0.05 s | a whirl lifts you **3.5 m** in 0.45 s, then **a helpless glide**: falls at 3 m/s at most, drifting at 4.5 m/s, until you land, grab the edge or press Ctrl | full drift | a whirl push: 2%, no launch | the least height, the farthest across (about 1.5 m sideways per 1 m of fall in the glide), and the hardest to KO |

How it fits key 3 and round 2's travel moves:
- **On the deck, key 3 is unchanged** (round 2):
  - The first move is the dash the way you hold (Burrow, Skate, Step, Slip).
  - The other move is the travel move (Lift, Surf, Jets, Leap).
- **Lift, Jets and Leap cast from the deck use up that airtime's Rise:** they lift you into the air, but they are not
  helpless. Surf stays on the deck and uses nothing.
- **Key 3's other move cast in the air is the Rise.** It is the same move with the same rules: Lift's mid-air pillar is
  the Pillar, Jets by pitch is the Jet, Leap is the Updraft, and Surf in the air is the Fountain. So the Rise is two
  inputs (key 3 tapped twice, then right click) for those who think in keys, or one (Space a third time) for everyone.
- **Leap's hold-Space glide is dropped in the stocks ring,** because Space in the air is the double jump. The Updraft's
  glide replaces it (a note for KITS).

Recovery budget (design targets for the soak, from the end of hitstun at deck height, with the double jump, Dodge, air
dash and Rise all used):

| Element | Recovers from (below the lip) | Recovers from (out from the edge) |
|---|---|---|
| earth | about 6 m | about 7 m |
| water | about 5.5 m | about 9 m |
| fire | about 7 m | about 11 m |
| air | about 4.5 m | about 14 m |

Each has a weak side: earth goes up but not across, air goes across but is easy to reach in its glide, and fire must
survive its hover.

**Learn:** "Space, Space, Space: up, up, and your element lifts you." Mashing Space three times on the deck only makes
you float down helpless onto it (0.35 s of lag), a cheap lesson. **Master:**
- Holding the Rise until the last moment.
- Fire angling its Jet straight at the lip, or over an edge-guarder.
- Earth's Pillar hitting a guarder who jumped down after him.
- Water's push clearing a guarder off the lip.
- Air gliding round to the far side of the deck.

**Risks:**
- Mashers waste the Rise.
- Fire's hover is a sitting target (intended).
- Earth's column could become a wall-like platform, so it sinks after 0.4 s and has no top to stand on.
- The Rise's startup tells must read at 15 m and at night.

**Code:**
- RingMoves.rise(el), with its numbers in movement.json.
- The looks: BendLooks (a stone column mesh from FormRaised's kit, a water column from the Geyser look, the jet trail,
  a whirl).
- The hits through BendStatus with the % part's numbers.
- KITS: Lift, Jets, Leap and Surf get `rise_in_air` specs.

---

## 11. The air dash (key 3's first move in the air) and the existing dashes

**Rule:** key 3's dash works once in the air, flat the way you hold.

- Its round-2 speed for 0.3 s with gravity off, then you fall normally. Not helpless.
- Nothing held = back, as round 2 says. Recovering, you hold the deck's way.
- Earth's Burrow in the air is a stone slab you kick off sideways (the look only, and the same numbers).
- All the dashes keep round 2's lock times: Burrow 0.3, Skate 0.4, Step 0.2, Slip 0.15.

**Learn:** "Your dash works once in the air." **Master:** air dash, then double jump, then Rise: three separate resources
spent in the right order. Also Carried wind out of an air Slip. **Code:** BendEffects dash (round 2) with an `in_air`
branch; the count in RingMoves.

---

## 12. The camera off the deck

**Rule:** the camera never turns your view. Off the deck it pulls back and keeps its height over the lip, so the edge
stays in sight.

- **Yaw and pitch are always the player's** (the owner's rule: getting hit never hurts the aim). A launch shakes the
  camera (the feel part's kick) but does not spin it.
- **Off the deck** (feet under the lip, or outside the rectangle):
  - the arm eases from **4.1 to 6.0 m**;
  - the pivot's height eases to at least **lip + 1.2 m**;
  - the FOV eases from **52.5 to 60**.
  - It eases in over 0.35 s and back out over 0.5 s after landing.
  - At an arm of 6 m and FOV 60, the frame's lower edge reaches about 3.5 m under the pivot, so a body hanging at
    lip − 2 m stays in frame.
- **Hanging:** an arm of 5.0 m and the pivot at lip + 1.0 m, so the deck ahead and your own head and hands show.
- **The natural case:** you face your opponent, so you are launched backwards, and the deck is in front of you while
  you fly. The hard case, a sideways launch off a long side, is the one the soak and the owner's play-test watch.
- **An arrow toward the deck when it is out of view:** it is not a cue on an enemy, but it is HUD clutter. Default off;
  owner question 7.
- The spring arm keeps its collision. Looking away from the deck while hanging puts the arm against the stone face; the
  arm shortens there, which is acceptable for that moment.

**Code:**
- player.gd: cam_distance_now(), the eye target (1316-1319) and the FOV (1332-1333) add `ring_moves.cam_bias()`.
- RingMoves computes the bias from on-deck, hanging and airborne.
- The critic's camera variants (critic_r1, the camera item) sit on top of this as a profile.

---

## 13. Tech, lying down, and respawn (the movement end of the % layer)

| | |
|---|---|
| **Tech (break fall)** | tumbling (in the % part's tumble) into the deck or the deck's stone face: press **E within 0.25 s before contact**. On the deck you stand at once (intangible 0.25 s), or with a direction held you tech-roll 2.5 m. On the face you stick for 0.1 s and spring off (vy +3), with every air move still yours. A missed press locks tech out for 0.6 s, so mashing fails |
| **Missed tech** | you lie 0.4 s (intangible 0.2 s), then get up by any key: W stands up, E with a direction rolls 2.5 m, left click attacks round you (5%). Intangible 0.3 s. After 1.2 s you stand automatically |
| **Respawn** | 1.5 s after the splash, 3 m over your end's spawn spot on a floating stone slab (own asset). You stay up to 3.0 s; any move, jump or cast leaves it. Intangible until 1.5 s after you leave, or until your first cast. Every air move is yours |
| **Hitstun, fairly** | during hitstun (the % part's number, capped by it) you cannot act. When it ends, any action cuts the tumble. The hit has already given back your double jump, Dodge, air dash and Rise, so every launch short of the water can be fought back from. Drift during the launch (DI) is the % part's; afterwards your own air drift (§1) is full |

**Code:** RingMoves (the tech window, the lying state, the respawn slab); the % part's BendKnock.hitstun_t and the tumble
flag; RingMode (when to respawn).

---

## 14. Mode gating: one player.gd, the open world untouched

**Rule:** all of this exists only on a competitor in the stocks ring. Everywhere else the controller is byte-for-byte
today's.

- **Gating by existence.** `RingMoves.install(body)` is called only by RingMode (via RingRules.add) when the rules mode
  is `stocks`. player.gd gets `var ring_moves: RingMoves = null`, and every branch is `if ring_moves != null`. The open
  world, the duel, old-rules practice, a horse, a grip, a boat and a climb never see it.
- **player.gd, _physics_process, at the traversal call (1232-1238):**
  - `owned = ring_moves.pre(intent, delta)` when it is set. While it owns the body (hang, edge options, Rolls, Ducks,
    Dodge travel, Rise travel, tech, lying, respawn), the player's steering and move_and_slide are skipped, as for
    traversal.
  - **The intent is the one the BOTS part already wrote** (smash_r3/bots.md §1): `{move (flat, world), jump, jump_held,
    dodge, dodge_dir, fast_fall, up_recovery, up_dir, guard_held, ledge: ""|"climb"|"jump"|"roll"|"attack"|"drop", di}`.
    That keeps one shape for both bodies.
  - **For the player only**, a small translator, `RingMoves.intent_from_keys(keys)`, turns the raw keys into that intent
    by the context rules of this document:
    - a third Space → up_recovery, with up_dir the aim;
    - E in the air → dodge, with dodge_dir the held keys;
    - guard up + a fresh direction → dodge on the deck, which is the Roll;
    - guard up + Ctrl → dodge with dodge_dir zero on the deck, which is the Duck;
    - while hanging, W → climb, Space → jump, E → roll, a click → attack, Ctrl or away → drop;
    - Ctrl past the top of a jump → fast_fall.
  - The bots fill the semantic intent directly through NpcPad, so neither body has a move or a number the other lacks.
  - The bots part calls the mode "ring % mode" with the flag `ring_pct`; this document's "stocks ring" is the same mode.
- **When RingMoves doesn't own the body:**
  - run speed, ground and air accel, gravity, max fall and fast fall come from `ring_moves.profile`;
  - the jump at 1293-1296 calls `ring_moves.on_jump_pressed()`, which handles the hop, the double jump and the Rise;
  - KNOCK_AIR_CONTROL applies only through hitstun.
- **The crouch toggle (1183-1193)** becomes a hold while ring_moves is set.
- **No traversal or grip in the arena:**
  - `if enable_traversal and not arena` and `if enable_grip and not arena` (449-452).
  - Today both install in the ring. With a 6 m deck, PlayerTraversal's climb_hang_3m (an overhead lip over open ground)
    would grab the deck's lip by its own rules.
  - This is the one change that touches the arena outside the stocks rules. Owner question 9 asks whether old-rules
    arenas keep traversal (no use for it is known).
- **Casting:** SwayCaster asks `RingMoves.can_cast(body)`. It returns false when hanging, helpless, dodging, in landing
  lag, lying, or on the respawn slab. On the edge the click is the edge attack, handled by RingMoves.
- **NpcFighter (`_move`, 932-997):**
  - `if RingMoves.owning(self): return` first.
  - Gravity from the ring profile. The `v.y = −0.5` floor clamp is skipped while RingMoves says the body is in its own
    jump, the way it is skipped while launched.
  - Today's GRAVITY 18 for bots is replaced in the ring, so bots and the player fall alike.
  - The bot drives RingMoves with the same intent dictionary from NpcBending. **One code path for both.**
- **NpcBending:**
  - **Recovery brain:** drift to the nearest free lip point; double jump when it falls below lip − 1 m; Rise when what is
    left can't reach the lip; Dodge an incoming hit seen in time; wait out an edge-guarder.
  - **Edge options by preset:** easy always climbs; normal mixes climb, roll and jump; hard mixes all four, varies its
    timing, and edge-guards (a Kick wave across the lip, waiting for the 0.6 s to end, a wall on the nearest spot).
  - The bots also use the Roll and Duck at the round-2 perfect-guard rates.

**Code list (who touches what):**
- **New:**
  - scripts/ring/ring_moves.gd (RingMoves)
  - data/ring/movement.json
  - tests/ring/test_ring_moves.gd, tests/ring/test_ring_edge.gd, tests/ring/test_ring_recover_soak.gd
- **Changed:**
  - scripts/player/player.gd: the hooks above, all gated.
  - scripts/npc/npc_fighter.gd: the `_move` hooks.
  - scripts/npc/npc_bending.gd: recovery, the edge, dodges.
  - scripts/bending/bend_status.gd: can_take reads intangible.
  - scripts/bending/bend_knock.gd: the gravity override, the hit refreshing air moves (a call to
    RingMoves.on_launched), `slide_only` for late guards.
  - scripts/bending/bend_cast.gd and SwayCaster: can_cast, and the guard standing at fill.
  - scripts/bending/bend_effects.gd and bend_bolt.gd: the air dash, the floor wave over the lip.
  - scripts/ring/ring_arena.gd: the stocks overlay, no ropes, nearest_lip, lip occupancy.
  - scripts/ring/ring_water.gd: depth and the area.
  - scripts/ring/ring_rules.gd: stocks: no zones, no soft walls, no edge guard (the teeter instead), out = water or the
    tank wall line.
  - scripts/ring/ring_mode.gd: install RingMoves, respawn.
  - data/ring/ring.json: modes.stocks.
  - scripts/ui/match_bar.gd: nothing for movement. The % and stock numbers are the HUD part's.

---

## 15. Clips needed (our own, keyed by hand in tools/anim_author/blender/bend_clips.py, with SOURCE.md rows)

They are authored on the rig's rest pose, as round 2's own-bend-* clips, with no imported or measured reference.
Movement is played through BendPoses' full-body layer while RingMoves owns the body. Existing clips are reused where
they read right.

| Priority | Clip | Frames (30 fps) | Notes |
|---|---|---|---|
| P1 | own-ring-edge-grab | 6 | catch the lip with both hands; the body swings in under it |
| P1 | own-ring-edge-hang (loop) | 30 | hands and head clearly OVER the lip; feet against the face; a slight sway |
| P1 | own-ring-edge-climb | 15 | knee up onto the deck, stand |
| P1 | own-ring-edge-roll | 22 | pull up into a forward roll, 3 m in (root moved by code) |
| P1 | own-ring-edge-jump | 9 | a hands-push spring straight up |
| P1 | own-ring-edge-attack (+ element looks by FX) | 18 | pull up with a low sweeping leg across the lip |
| P1 | own-ring-jump-double | 12 | tucked knees-up spring; air's variant is a spin (reuse air_spin's keys as a reference start) |
| P1 | own-ring-fall (loop) / own-ring-fall-fast | 20 / 1 pose | arms out, legs loose / a tucked arrow |
| P1 | own-ring-helpless (loop) | 24 | arms trailing up, a loose slow tumble: it must read different from the normal fall at a glance |
| P1 | own-ring-airdodge | 15 | a sharp twist with the body tucked (direction from code) |
| P1 | own-ring-roll-f, -b, -side (+ mirror -l) | 18 each | low martial-arts rolls; the facing is kept |
| P1 | own-ring-duck | 14 | a deep sway down and back, a return |
| P2 | own-ring-rise-earth | 14 | crouched on the column, fists down, then thrown off the top |
| P2 | own-ring-rise-water | 18 | rising on the column, arms swirling up |
| P2 | own-ring-rise-fire | hover 8 + burst 10 | knees drawn, fists at the hips (the hover tell), then straight-legged along the burst |
| P2 | own-ring-rise-air | 14 + glide loop 30 | a spin up, then arms spread in a glide |
| P2 | own-ring-land-lag | 10 | a heavy crouched landing (the helpless and Dodge landings) |
| P2 | own-ring-teeter | 12 | the lean and windmilling arms at the lip |
| P2 | own-ring-guard-hold loops ×4 | 30 each | the four round-2 guard poses as held loops (round 2's CLIPS adds the poses) |
| P3 | own-ring-tech, -tech-roll, -lie, -getup, -getup-roll, -getup-attack | 8-20 each | knock_slide and knock_air stand in until then |
| P3 | own-ring-respawn-idle | 30 | a stance on the slab |

Stand-ins are allowed for P2 and P3 (BendPoses skips a missing clip): earth_rise for the Pillar, air_leap for the
Updraft, water_draw for the Fountain, knock_air for the helpless fall at first. **The edge and helpless clips have no
stand-in.** A wrong hang pose, with the hands under the lip, would mislead the guarder.

---

## 16. Tests

New:
- tests/ring/test_ring_moves.gd
- tests/ring/test_ring_edge.gd
- tests/ring/test_ring_recover_soak.gd
- a gating test in tests/player

Every test runs headless with movement.json numbers. The checks are listed in the structured output and repeated
here in short:
- Jumps: the full hop reaches 2.0 ± 0.05 m and the short hop (let go at 0.08 s) 0.8 ± 0.05 m.
- A third Space is a Rise, not a jump. Helpless ignores Space, E and casts. A helpless landing gives 0.35 s of lag.
- The double jump, Dodge, air dash and Rise are refreshed by landing, a grab and a hit, and by nothing else.
- Dodge:
  - Directional: 3.2 ± 0.1 m.
  - A bolt through the body at 0.15 s passes; one at 0.4 s hits.
  - One per airtime.
  - Landing in it gives 0.3 s of lag.
- Fast fall: Ctrl before the top does nothing, and after it sets vy to −17.
- Roll and Duck:
  - A Roll is 3.5 m and stops 0.3 m inside the lip.
  - W held while pressing E gives a guard, not a Roll.
  - A Duck is intangible at 0.1 s.
  - The repeat cost adds +0.1 s.
- Guard:
  - A tap stands for the round-2 window. A hold stays up until let go, at most 2.5 s.
  - A late hit adds half its % and slides along the deck, never into the air.
  - Space out of the guard jumps on the same frame.
- Edge:
  - Grabbed inside the box and not outside it; not with Ctrl held, not in hitstun.
  - The snap faces the deck and leaves the camera yaw unchanged.
  - 0.6 s intangibility on the first grab and 0 on a regrab; refreshed by standing on the deck.
  - Auto-drop at 4 s.
  - Every option's end position and intangible window.
  - A second body can't grab within 1.2 m and can at 1.5 m.
  - A wall at the spot blocks the grab.
  - The Kick's wave hits a hanger after 0.6 s.
- Teeter: a run at the lip stops; holding toward the water for 0.3 s steps off; a launch carries you over.
- Rises:
  - Heights within ±0.2 m.
  - Earth's column hits a body above.
  - Fire's direction follows the pitch.
  - Air's glide falls no faster than 3 m/s and Ctrl ends it.
  - Leap, Jets and Lift from the deck use up the Rise.
- Out: under water_y is out, and a hanging body's feet are above the water. Crossing the tank wall line is out.
- Gating:
  - A FrontierPlayer outside the ring has ring_moves == null.
  - Its jump is still 4.4 m/s at g 9.8.
  - Its crouch is still a toggle.
  - A third Space does nothing.
  - Traversal and grip are absent in the arena.
- Bot parity:
  - A bot and the player in the same RingMoves states produce the same trajectories (within 1 cm over 2 s).
  - Soak: normal bots knocked off 3 m out at lip − 1 m recover in at least 90% of 3 seeds × 4 elements; easy bots in at
    least 60%.
  - Report the recovery reach per element against the §10 table.
- Camera: off the deck, the arm is 6.0 m and the pivot at lip + 1.2 m or higher within 0.5 s. A launch never changes yaw
  or pitch.

---

## 17. Owner questions

1. **Raise the deck to 6 m over the water in the stocks ring** (a stone tower, the tank 14 m wide, the stands moved out).
   Without it there is no room to hang or recover under the lip. Before and after images first.
2. **Ropes off on the long sides in the stocks ring** (all four sides open)? Widen the deck to 18 m if the soak shows
   too many side KOs? The BOTS part's travel predictor still counts a rope rail, so the parts must agree on this.
3. A body flying over the tank's outer wall: **out at that line** (recommended), or a falling-water curtain on the wall
   that sweeps him into the water (keeps "only in the water" literal; needs its own art)?
4. **No sky line**: launches straight up come back to the deck, and KOs are sideways (launch angles at most 65°). Or a
   line high over the deck?
5. **The dodges on E**: guard up + a tapped direction = Roll, guard up + Ctrl = Duck, E in the air = Dodge, E while
   hanging = Roll in. No guard in the air, so earth catches stones only on the deck. Or a separate dodge key (Shift)?
6. **The Rise on a third Space** (and on key 3 tapped twice in the air)? It ends helpless (0.35 s landing lag even on
   the deck).
7. **An off-screen arrow toward the deck** when you are off it and it is out of view? Recommended off at first.
8. **Edges: no trumping** (a hanger's 1.2 m can't be grabbed; you grab beside him). The 0.6 s first-grab intangibility,
   none on a regrab.
9. **No traversal or grip in any arena** (today both install there)?
10. **The held guard**: no meter and no break stun; up to 2.5 s; a late hit = half its % plus a slide along the deck,
    never a launch into the air?
11. **The teeter**: running stops at the lip; hold toward the water for 0.3 s, or jump, to leave on purpose?
12. **Ring physics**: gravity 20, run 5.0, a full hop of 2.0 m, more air control, in the ring only (the open world
    unchanged)?
