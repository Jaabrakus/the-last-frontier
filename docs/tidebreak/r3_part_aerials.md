# Tidebreak % layer: AERIALS AND COMBOS (the MOVES part)

Design only. Nothing in the project was edited, and Godot and Blender were not run. The design sits on round 2's kit and keys
(skills_r2/spec.md, overridden by skills_r2/owner_answers.md, and the four round-2 task files) and on the owner's smash-layer
answers (critic_r2/owner_answers_r3.md): number keys kept, 3 lives, full recovery, out only in the water.

The sibling parts this one leans on:
- **RULES** owns %, launches, hitstun and the water. Its model (smash_r3/launch_table.py) is used here:
  - launch `L = weight × (base + growth × %after/100 × (0.5 + dmg/20))`; jabs have a set knock;
  - hitstun `= clamp(0.05 × L, 0.12, 1.2) s`;
  - a long hitstun may be left by an air dodge or jump after about 0.6 s.
- **MOVEMENT** owns jumps, the air dodge, rolls, fast fall, the up-recovery and the edge.
- **BOTS** (smash_r3/bots.md) reads the strings table below.

Where this file needs a number from them, it says "assumed". Their numbers win, and then smash_r3/combo_calc.py is re-run.
That script is mine: it is the combo-window maths behind every "true from X%" in this file.

Words: "Pop", "Slam", "Chain", "string", "steer your flight" and "break your fall" are the player-facing words. DI, tech,
meteor, L-cancel, stock and blast zone stay internal; bots.md asks the same. No show words.

---

## 0. The short version (one sentence per rule)

1. **In the air, your moves go where you aim, even straight up or down, and 2 always hits DOWN.**
2. **What you cast is fixed when you let go:** feet off the deck at the release gives the air version, even if the lock
   began on the deck.
3. **2 in the air is your Slam:** it hits the space under and just ahead of you. On the deck it bounces him up; over the
   water it drives him down.
4. **2 tapped twice, 1, and LMB are the same moves as on the deck,** aimed in full 3D. Fire's 2 in the air is the Axe
   Kick (down). Its High Kick (2 tapped twice) in the air is the crescent along your aim.
5. **4 and 5 need your feet on the deck:** in the air their lock pauses and goes on when you land.
6. **E works in the air:** catch, Turn, Parry and Wind Guard, with no landing lag. Earth can catch in the air and throw back
   in the air.
7. **Landing lag:** land while your air move is still out, and your feet are planted for 0.1-0.35 s. Land after it, or
   before you let go, and there is none. A hit halves it.
8. **Short hop:** tap Space for a low hop and full hop when held. Quick moves cast at take-off are done before you land,
   so they have no lag.
9. **Jab string:** three jabs that hit in a row make the third one a **Pop**, which lifts him up. Then hit him in the
   air.
10. **The Chain:** when your hit lands, the lock you are filling (or the next one you start within 0.5 s) fills twice as
    fast. Missed casts get no Chain.
11. **Strings end by themselves:**
    - each hit after the third in one string holds him 15% less;
    - the 6th hit always frees him;
    - a repeated move hits softer (stale);
    - he can steer his flight;
    - he can break his fall on the deck, a wall or the ropes.
12. **Hitstun is fair:**
    - your aim and camera are never moved;
    - you steer your flight;
    - one button press waits and fires the first moment you are free;
    - at 0% it lasts 0.12-0.4 s;
    - one hit never takes more than 0.6 s before you can air dodge;
    - nothing slows you afterwards.
13. **A caught stone is earth's combo tool.** Hold it, land any hit, press E, and it follows on a 0.1-0.35 s lock. A
    string's hits can never be caught (he is in hitstun), so a true string stays true.

---

## 1. The air rule, key by key

The camera is behind the player, so a target below you is hidden by your own body. That is why **only 2 has a special
air form**, and it needs no pitch aim: it covers a fixed space under you. Everything else is "the same move, wherever the
crosshair is". Up, forward and back aerials need no extra moves: the mouse already gives every direction.

| Key | On the deck (round 2) | In the air | Land lag (on a hit) |
|---|---|---|---|
| **LMB Jab** | the close poke | the same jab along the aim in full 3D. The string and the Pop work in the air too. | 0.10 (0.05) |
| **1 Strike** | the quick shot; tap twice for the big one; fire holds to grow Punch into the Fireball | the same shot along the aim in full 3D. Nothing grows in the air: a lock that grew before take-off stays grown. Earth's stones are smaller off the deck (§1.2). | quick 0.20 (0.10) · big 0.25 (0.12) · Lightning 0.35 (0.18) |
| **2 Push ▲** | Shove / Wave / Kick / Gust | **the Slam**: a downward hit under and ahead of you (§1.1). Earth holding a caught stone throws the stone instead, as the deck's Shove does. | 0.30 (0.15) |
| **2 ×2** | Column / Geyser / High Kick / Pull | the same move. Column and Geyser rise from the deck where you aim (a grate or your puddle counts; never the tank's water). High Kick is a crescent along the aim (it flips you; new clip). Pull pulls along the aim. | 0.25 (0.12) |
| **3 Dash** | the dash by the held keys; tap twice to travel | MOVEMENT's air dodge; 3 ×2 is MOVEMENT's up-recovery. This part only adds the cancel rules (§3). | MOVEMENT's |
| **4 Wall** (and fire's Breath on 4 ×2) | your wall | the lock pauses until you land (no walls in mid-air, no ice ledges over the water) | none |
| **5 Heal** | Patch / Mend | the lock pauses until you land | none |
| **E Guard** | catch, Turn, Parry, Wind Guard | the same, and in the air. Earth's held stone stays held while you fall. | none |

### 1.1 The Slam (2 in the air), one rule and four elements

**Rule: "2 in the air hits under you."**
- **Its space:** a column 2.5 m wide (water 3.2 m) from your feet to 3 m below (air 4 m). Its centre leans up to 1.5 m
  toward the yaw you aim at, so there is a little control and no pitch aim.
- **Timing:** it lands on the pose's strike, about 0.1 s after the release, and stays out for 0.12 s.
- **Lock:** 0.35 s (fire 0.3 s). The moving penalty does not apply in the air (§2.1).
- **What it does:** a downward launch at −70° (down and a little away along your facing), with a **set 0.3 s hitstun**.
  Only its speed grows with %.
- **On the deck** (he stands there, or it drives him into the deck within its hitstun): **he bounces up**.
  - Bounce speed: 0.45 × the down speed + 2 m/s (earth 0.55 ×).
  - Hitstun: 0.45 s, × the string's decay.
  - **Once per string.** A second Slam on the deck in the same string only pushes him flat, at half its launch.
- **Off the deck:** it drives him down toward the water. After the 0.3 s he may jump or up-recover. A jump *sets* the fall
  speed rather than adding to it (MOVEMENT's rule, assumed), so a low-% Slam can be survived and a high-% one is the KO.
  - **Geometry blocker** (shared with bots.md §1): with today's water at −1.4 m and out at −0.6 m, every Slam over the
    water is an instant KO with no counterplay. This part assumes RULES and ARENA lower the water to about −6 m.
  - Until they do, `slam.offdeck_deg` caps the off-deck angle at −30°.

| Element | Name (player text) | Damage % | Launch base + growth | Its own touch |
|---|---|---|---|---|
| Earth | **Stone Hammer** | 12 | 6 + 7 | The heaviest spike and the best bounce (0.55). Holding a caught stone, 2 throws the stone along the aim instead (the Shove rule). |
| Water | **Downpour** | 8 | 4 + 5 | The widest (3.2 m). It puts out fire under it, and where it meets the deck it leaves a **puddle** for 6 s (a Geyser source: twice as wide). |
| Fire | **Axe Kick** | 10 | 5 + 6.5 | The fastest (0.3 s lock). If it reaches the deck it splits into a short floor wave (6 m along your aim's yaw, 1.2 m wide; the Kick's numbers × 0.5). A miss still threatens the ground. |
| Air | **Down Gust** | 6 | 4.5 + 5.5 | The deepest (4 m). It pushes **you** up 2.5 m/s, once per time in the air (refreshed on landing, on the edge, or when hit). |

This decides the owner's question "the fire Kick in the air = the High Kick crescent?": **no**.
- In the air, 2 is the Axe Kick (down), keeping the rule "2 hits down".
- 2 tapped twice is the High Kick crescent along your aim, as on the deck.

### 1.2 Earth off the deck

Earth draws its stones from the deck.
- **Within 5 m above the deck:** Spike, Boulder, Pebbles and the Hammer are full.
- **Higher, or over the water:** they are carried stones at × 0.8 damage and launch, and still work.
- **A caught stone is always full.**

Player line: "Off the deck, earth throws smaller stones, except the ones it caught."

### 1.3 What does not change in the air

- Casting never stops your fall: no stalls, and "root: place" poses are ignored while airborne.
- The aim, the click buffer, cancel-by-letting-go, same-key switching and E-takes-over all work as on the deck.
- Every lock in % mode is aimed at a point, never stuck to a body (see §8, the CORE dependency).

---

## 2. Locks, release, landing lag, short hops

### 2.1 Numbers

| Rule (one sentence) | Number |
|---|---|
| In the air, locks fill at the standing rate: the moving penalty is off, earth's Rooted is off, and fire's Footwork is unchanged | air_fill_mult 1.0 (soak: if more than 35% of casts are released in the air, drop it to 0.85) |
| The form (deck or air) is taken at the release, and `_pending` carries it to the strike | sampled at release |
| An air move is "out" from its release until its strike + 0.15 s (the Slam: strike + 0.2 s) | active_s 0.15 / 0.2 |
| Landing while it is out plants your feet for its land lag; while planted you cannot walk, jump, dash or guard, but a lock may fill (lock time stays the only cast limit) | see the §1 table |
| A hit halves the land lag | × 0.5 |
| Landing while still locking, or after the active window, costs nothing | 0 |
| Short hop (Space let go within 0.12 s) / full hop (assumed, MOVEMENT's numbers) | 3.4 m/s: 0.69 s up, top 0.59 m. A short hop does **not** clear a Kick wave (that needs 0.6 m); a full hop (4.4 m/s: 0.9 s, 0.99 m) does. |
| Fast fall after the top (MOVEMENT's key; assumed Ctrl or C in the air) | × 1.6 fall speed |

### 2.2 Which aerials fit a short hop

The table starts each lock at take-off, at the air fill rate.

| Move | Lock | Out until | Short hop (0.69 s) | Full hop (0.9 s) | Pre-charged on the deck, hop, let go at once |
|---|---|---|---|---|---|
| Jab (fire/air 0.25, water 0.35) | 0.25-0.35 | 0.50-0.60 s | no lag | no lag | no lag, even with a fast fall |
| Punch, Gust-type 0.35 | 0.35 | 0.60 s | no lag | no lag | no lag |
| Slam (fire 0.3) | 0.35 | 0.65 s | no lag (just) | no lag | no lag |
| Lash 0.45, Slice/Ball 0.5, Pebbles 0.5 | 0.45-0.5 | 0.73-0.75 s | **lag** | no lag | no lag |
| Spike 0.9, Boulder 1.4, Lightning 2.2 | long | — | only pre-charged | only pre-charged | lag if you fast fall into it |

**Learn:** "Cast as you leave the ground and you land clean." The landing-lag pose (a heavy crouch) and a heavier thud
tell the player when he got it wrong. There is no number on screen.

**Master** (the hop, cast, fast fall loop):
- Fill the lock on the deck to the click, hop, let go at once, fast fall, and land clean ~0.5 s later.
- That is a safe aerial over a Kick wave.
- A whiffed aerial is punishable: up to 0.35 s planted with no guard.

**Risks:**
- **Bunny-hop casting** to dodge the run penalty. A hop commits you (air steering 2.5), and the soak watches the air
  share (above).
- **Pre-charged hops** that dodge every floor wave. High Kick, Pull, Slice and the Slam reach a hopper, and the land lag
  punishes a miss.

---

## 3. Cancels (what may interrupt what)

| From | Into | Rule |
|---|---|---|
| a lock | jump | always (round 2), and the lock keeps filling |
| a lock | E guard | always (round 2) |
| a release | the next lock | at once (today). A pending strike always comes out before the next action moves you. |
| a hit you landed | your next lock (any of LMB, 1, 2, 3) | the **Chain**: that lock fills × 2 (§4.2) |
| a hit you landed | 3 Dash or the air dodge | the dash lock gets the Chain too: "hit, then dash in" |
| a deck launcher (Pop, Column, Geyser, High Kick, a bounce) | jump, then an aerial | the jump is free, the aerial's lock may already be filling, and the Chain applies |
| an air move | an air dodge | allowed after its strike, so the move is never lost. Landing then takes the air dodge's lag, not the move's. |
| an air move | landing | free if the move is no longer out (the auto-cancel) |
| hitstun | your first action | one buffered press (jump, dash, E, or a click) fires on the first free frame |

---

## 4. Hitstun and combos

### 4.1 Hitstun: what it is and why it is fair

**Rule: while in hitstun you cannot walk, jump, dash, guard or let a cast go; your aim and camera are always yours.**

- **How long:**
  - RULES' 0.05 s per m/s of launch, between 0.12 s and 1.2 s;
  - the jab string's set 0.30 s;
  - the Slam's set 0.30 s and the bounce's set 0.45 s;
  - × the string decay (§4.4).
- **Escapable and fair:**
  1. **Your aim and camera are never moved by a hit.** IMPACT's jolt uses the screen offset only, and that is pinned in
     its test.
  2. **You steer your flight** (internally, DI): the keys you hold during the first 0.1 s of a launch bend its flat
     direction up to 15° (RULES' `di_max_deg`). A nearly straight-up launch instead drifts up to 1.5 m/s to that side.
     The 0.1 s window gives a human time to react; holding the keys in advance works too.
  3. **One buffered press:** jump, dash, E or a click fires on the first free frame.
  4. **A running lock is frozen, not lost.** It keeps its fill through the hitstun and goes on after. In % mode this
     replaces round 2's hit setback, so the player is not penalised twice. Lightning's charge still breaks.
  5. **Short at low %:** 0.12-0.4 s at 0%. One hit never holds you more than 0.6 s before an air dodge is allowed
     (RULES' early escape).
  6. **Nothing after:** full speed, full aim and full lock rate the moment it ends. No slow, ever.
  7. **The same for the bots, frame for frame.**
     - **The hit-stop asymmetry:** today IMPACT freezes a hit bot's knock for 40-110 ms but starts the player's at once.
       If hitstun counted from the knock's start, bots would be held up to 0.11 s longer, so strings would land on bots
       that never land on a human.
     - **Rule: hitstun counts from the hit itself, for everyone.**
- **Tumble:** a launch whose hitstun is 0.4 s or more (L ≥ 8 m/s) is a tumble: the knock-air clip, then a tumble loop.

### 4.2 The Chain (how short locks keep combos possible)

**Rule: when your hit lands, whatever is left of the lock you are filling (or of the next one you start within 0.5 s)
fills twice as fast.**

- **Only on a hit.** A miss, a guarded hit or a late guard's half never chains, so spamming gets nothing. Lock time stays
  the only limit on casts; the Chain is a lock rule earned by landing a hit.
- **It applies to** LMB, 1, 2 and 3. It never applies to 4, 5 or E, and **never to the same move again** (the jab
  string's own steps excepted).
- **One Chain per hit;** it does not stack.
- **Its look and sound:** your own lock ring visibly speeds up, and a bright tick sounds on your own hands. Nothing is drawn
  on him.

**Why it is needed:**
- Round 2's locks (0.25-1.6 s) are far longer than Smash start-ups (0.05-0.25 s).
- Without the Chain only the jab string would combo. A human starts the next lock as the first cast leaves his hand, so
  part of the lock already overlaps the flight.
- The Chain halves only what is left after the hit. Slow moves (Spike 0.9, Column 1.6) therefore stay slow and never link,
  and quick moves link.

### 4.3 The jab string and the Pop

**Rule: hit with a jab, hit again with a jab while he is still reeling, and your third jab that hits is a Pop that lifts
him.**

- **Steps 2 and 3 lock in 0.15 s** after a jab that hit. It is the same for every element, so earth's 0.5 s Pebbles still
  strings.
- **Set hitstun:** jabs 0.30 s, never growing with %. Jabs never KO (RULES' set knock).
- **The Pop:**
  - 3% damage;
  - launch 8 + 4 growth at 80° (straight up and a little away);
  - burst at the contact point in the element's look: a stone fist from the deck, a crest of water, a short flame column,
    an updraft;
  - the caster plays a rising-hand jab clip.
- **One Pop per string.** After it, jabs are plain: their normal lock, decay included. A missed or guarded jab starts over
  at step 1.
- **The jab trio is exempt from decay.** Decay starts with the Pop.

### 4.4 Ending strings (the anti-infinite rules)

| Rule | Number |
|---|---|
| **Decay:** each hit after the jab trio (the Pop and later) holds him × 0.85 of the one before it | 0.85 per counted hit |
| **The 6th hit of a string frees him:** full launch and damage, but no hitstun beyond 0.1 s | string_cap 6 |
| **Stale:** each copy of the same move among your last 6 landed hits takes 8% off its damage and launch (and so its hitstun), down to −40%. A jab string counts once. | 0.08 / 6 / 0.6 floor |
| **A string** is the run of hits that each land while he is still in hitstun from the one before. It is counted on the **victim**, so in 3v3 two attackers share one decay and one cap. | per victim |
| **The bounce** comes once per string | 1 |
| **Steering his flight** (DI) | 15° |
| **Breaking his fall:** E within 0.25 s before touching the deck, a wall or the ropes while tumbling; 0.6 s lockout after a press, so mashing fails | see §4.5 |
| **Launch grows with %:** at high % he flies out of follow-up range or out of the deck. Strings end in KOs, not loops. | RULES |

**What combo_calc.py says** (fastest human input: each next lock started as the cast before it leaves the hand; a target
3-4 m away):

| String | 0% | 30% | 60% | 100% | 140% |
|---|---|---|---|---|---|
| Pebbles, Pebbles, Pop → Shove (held or loose stone) | true | true | true | true | true |
| Pebbles, Pebbles, Pop → E return of a held stone | true | true | true | true | true |
| Pebbles, Pebbles, Pop → Spike | no | no | no | no | true (a KO read before that) |
| Splash, Splash, Pop → Lash | true | true | true | true | true |
| Embers, Embers, Pop → Punch | true | true | true | true | true |
| Kick (grounded hit) → Punch | true | true | true | true | true |
| High Kick → Punch | true | true | true | true | true |
| Palm, Palm, Pop → Wind Ball | no (0.44 s needed, 0.41 s held) | true | true | true | true |
| Palm, Palm, Pop → Slice | true | true | true | true | true |
| Column → Spike | never (Column is a trap, not a starter) | | | | |
| Slice × 4 (the same move) | breaks at hit 2 | breaks | breaks | breaks | breaks at hit 3 |
| Embers, Embers, Pop, Punch, Embers, Punch, Embers (a 7-hit probe) | breaks at 4 | breaks at 5 | breaks at 5 | breaks at 5 | breaks at 5 |

So the bread-and-butter strings are 4 hits and about 20-30%, true from 0%. Long strings die by hit 5, and the cap stops the
6th.

A human slower than "start the next lock as the cast leaves" loses the 4th hit at low %. That is the skill gap: it rewards
input timing and accuracy, not more buttons.

### 4.5 Breaking the fall and knockdowns

| Rule | Number |
|---|---|
| Tumbling into the deck, a wall (an earth wall, an ice wall) or the rope rail, E within 0.25 s before contact breaks your fall: you stand up in place | window 0.25, lockout 0.6 |
| Holding A, D, W or S as you break your fall rolls you 2.5 m that way, never off the deck's edge (the edge guard) | 2.5 m |
| Against a wall or the ropes you rebound upright with control back | — |
| A missed one leaves you down for up to 0.6 s. Any move key stands you up (after 0.25 s), A/D rolls, LMB is a getup sweep. | sweep: 2% damage, set 5 m/s, all round |
| A hit on a downed body stands him up with a set 4 m/s push and 0.2 s hitstun, so there is no lying-down lock | 4 / 0.2 |

The E key reads as "guard" in hitstun only within that window, so there is one key with one meaning: "E when it hits you".

---

## 5. The catch and the throw-back as a combo tool (the fun core, never weakened)

Round 2's catch is unchanged:
- the 1.0 s window and the 3.5 m radius;
- a late catch is a full catch, with no slide;
- the return lock is 0.35 s, or 0.1 s after a clean catch;
- the rally (+10%/+20%, capped at × 1.6);
- the stone held as long as today.

On top of it:

1. **The held stone is a loaded follow-up.** Land any hit, press E, and the return comes with the Chain: a 0.175 s lock,
   or 0.1 s off a clean catch. "Pebbles, Pebbles, Pop → E" is true at every %. This is earth's best string, and it needs
   a catch first, so the catch feeds the combos.
2. **Catch in the air, throw in the air.**
   - E catches while jumping.
   - E again (or 2, the Shove rule) throws along your aim in 3D: down at a grounded foe, or out at a recovering one.
   - An earth player at the edge can catch the stone thrown at him and hammer it back down.
3. **A string cannot be caught.** The victim is in hitstun, and a guard needs a free frame. A true string stays true. A
   stone thrown *outside* a true string can be caught and returned, so failed combos turn into rallies.
4. **The rally and %.**
   - A caught stone deals no %.
   - Each return keeps round 2's speed and damage multiplier, up to × 1.6.
   - Its launch growth takes half of it, up to × 1.3.
   - A long rally ends with a big KO launch on whoever misses. The longer the rally, the bigger the ring-out.
5. **A held stone stays held through hitstun** (never weaken the catch). Once free, E throws it: earth's comeback answer
   to a string.
6. **The other guards as starters.** Each guard's return is a hit that earns the Chain:
   - fire's perfect Parry returns at once at × 1.2;
   - water's perfect Turn swings and leaves along the aim;
   - air's perfect Wind Guard bounces it back and charges Carried wind.

   Perfect guards become combo starters for every element.

---

## 6. Bread and butter, per element

Each has one string an average player finds by accident (mash LMB on him, he pops up, press 1), one an expert extends, and a
KO finish. The "true from" values come from combo_calc.py at fastest input.

### Earth: heavy, and it combos with stones

**Accident:** Pebbles, Pebbles, Pop → Shove. True from 0% when a stone is held or loose within 6 m. With none, Shove's
kick-up adds 0.3 s, so it is a guess.

**Expert:**
- Catch first, then Pebbles, Pebbles, Pop → E (a 0.1 s return).
- Or: Pop → hop → Stone Hammer as he falls → the bounce → Shove ▲ toward his open end.
- From the edge: catch his stone in the air, then Hammer the held stone down onto him.

**KO:** a held-stone return at a long rally's × 1.6, or Shove ▲ from about 110% near an end. Pop → Spike is true only past
about 140%; before that it is a read.

### Water: the string that bends to his steering

**Accident:** Splash, Splash, Pop → Lash. True from 0%.

**Expert:**
- Flowing steers the Lash up to 15° in the first 0.25 s, which matches the victim's 15° steer. Water is the element that
  follows a launch he steered.
- Lash → hop → Downpour as he lands → bounce, leaving a puddle → Geyser from the puddle (twice as wide) → Lash up.
- A perfect Turn of his Lash starts a string.

**KO:** Wave ▲ toward his end from about 90% (a read). Over the water: Downpour.

### Fire: the fastest strings, punches up top and a kick along the floor

**Accident:** Embers, Embers, Pop → Punch. True from 0%. Kick → Punch is true at every % on a grounded hit; that is the
spec's "Kick, he jumps, Punch the jumper" turned into a true string when he does not jump.

**Expert:**
- Kick → High Kick (launcher) → Punch aimed up → hop → Axe Kick onto the deck → its floor wave and the bounce → Punch.
- A perfect Parry of his fire starts it.

**KO:** High Kick → Punch is true at every %, so at high % it carries him off. Held Punch (the Fireball) is the read on his
landing. The Axe Kick over the water is the edge KO.

### Air: momentum, pull in, push out

**Accident:** Palm, Palm, Pop → Slice. True from 0%. With the Wind Ball it is true from about 30%.

**Expert:**
- Slip past his shot (Carried wind) → Palm, Palm, Pop → Wind Ball for × 1.15 knock.
- Pull → Palm, Palm, Pop → hop → Down Gust (it lifts you) → the bounce → Gust ▲.

**KO:** Gust ▲ or Wind Ball near an end. Edge: Pull drags a recovering man out, then Down Gust over the water. Air is the
best off the deck, because Down Gust lifts you.

These feed bots.md §5's `pct.strings` (it owns the bot's choice and length per preset). The Chain changes its true
follow-up test: use `lock_for(next) × 0.5` for what is left after the hit.

---

## 7. How an average player learns it, and what mastery looks like

**Learning path** (practice cards, our own words; key hints only, no panels):

1. "Click on him three times: up he goes." (the Pop)
2. "While he's up, press 1." (the first string; the practice combo counter from bots.md §16 shows "3 hits · 21%")
3. "Jump and press 2 over him: the Slam bounces him." (the dummy stands still)
4. "Let go as you leave the ground and you land clean." (landing lag: the crouch and the thud)
5. "When your hit lands, your next lock fills twice as fast. Listen for the tick." (the Chain)
6. "When it hits you, hold a direction: you steer where you fly." (steering; the dummy throws you)
7. "Press E just as you hit the deck: back on your feet." (breaking the fall)
8. Earth only: "Catch it, keep it, and throw it after your Pop."

**What the player feels:** mashing LMB pops him; a button on him in the air hits; the 4th hit sometimes works and the
counter says why. Nothing to memorise beyond "three jabs, then 1" and "2 in the air hits down".

**Mastery:**
- Input overlap: start the next lock as the cast leaves.
- Tune strings to his % (Wind Ball after 30%, Shove ▲ late).
- Pre-charged short hops with a fast fall.
- Bounce routes.
- Edge Slams (with the water lowered).
- Steering his escape against water's steering.
- The held-stone string.
- Perfect guards as starters.
- Reading the 5th-hit drop and the read ender.

---

## 8. Risks (degenerate play, readability, 3D)

1. **Infinite strings.** Answered by decay, the cap at 6, stale, the Chain never on the same move, one Pop and one bounce
   per string, launch growth, steering and breaking the fall. combo_calc.py probes show strings dying at hit 4-5. The soak
   gate is "no string longer than 5 in 16 pairings × 3 seeds".
2. **Hitstun read as "being slowed"** (the owner's rule). See §4.1: aim untouched, steering live, one buffered press, ≤ 0.4 s
   at 0%, ≤ 0.6 s before an air dodge, nothing after. Test it.
3. **The Slam over today's 1.4 m drop is a free KO.** It needs the lowered water. Until then, the −30° off-deck cap.
4. **3D aiming at a flying target.**
   - The Pop is predictable: straight up from where he stood, so the first aerial hit is an easy one.
   - READ's shadows help with depth.
   - Every lock aims at a point, never stuck to a body. **CORE dependency:** today the lock breaks when the crosshair is
     off the target for 0.15 s (sway_caster.gd `_hold`, grace_s). A juggled man leaves the crosshair at once, so in %
     mode no lock may break on aim.
5. **The Slam can't be seen under you.** It is a fixed space, not a pitch aim. Its look reaches visibly down (stone, water,
   a flame leg, wind) and a miss has its own sound.
6. **Deck form vs air form readability.** The legs are tucked under every air cast (a new legs clip under the upper-body
   cast). The Slam and the Axe Kick are full-body clips that read as "down".
7. **Pre-charged hops** dodging every floor wave: High Kick, Pull, Slice and the Slam reach a hopper, and land lag punishes a
   miss.
8. **Bunny-hop casting:** watch air_fill_mult with the air-release share.
9. **Down Gust stalling:** once per time in the air, and it never stops the fall otherwise.
10. **The hit-stop asymmetry** (bots held longer than the player): hitstun counts from the hit (§4.1).
11. **Round 2's hit setback vs hitstun:** in % mode the lock is frozen during hitstun instead (owner question 8).
12. **Online later:** strings need the hitter's clock to be authoritative for the hitstun test. NetSession's P2 must carry the
    hit time.
13. **Earth's high-% kill confirms are weak without a stone.** That is intended (catch to combo), but watch earth's win
    share in the soak.
14. **Lightning in the air** (pre-charged): it is still a 2.2 s charge any hit breaks, and it has a 0.35 s land lag.

---

## 9. Code it touches (and who owns it)

Everything is gated by **ring % mode**: a static `BendCombo.on` set by RingRules while the % rules run. The open world,
the duel and the zone rules keep today's behaviour. Player.gd is shared with the open world, so every new branch there
checks the flag.

| File | Change |
|---|---|
| **new** `scripts/bending/bend_combo.gd` (BendCombo, static) | Per competitor: the string counter (victim side), the stale queue (hitter side, last 6 landed hits), the Chain window, `hitstun_for(L, spec, n, stale)`, `string_hit(by, victim, n)` signal (HUD counter, bots, soak), and the bounce and Pop once-per-string flags |
| **new** `data/ring/combo.json` | Every number in §2-§5: air_fill_mult, active_s, land lag classes, chain_mult/chain_s, jab_step_lock_s, jab_stun_s, pop{}, slam{} per element, bounce, decay, string_cap, stale, di window, tech window/lockout, knockdown, offdeck_deg, earth_offdeck_mult |
| `data/sway/moves.json` | An `air` block on each key-2 first-move spec (earth_shove/push, wave/push, fire_kick/kick, air_gust/gust) holding the Slam (`do: "slam"`, per-element touch), merged at cast like `grow`. `land_lag` class keys on air-usable specs. The `jabs` block gains each element's Pop look. |
| `scripts/bending/bend_cast.gd` | Merge `spec.air` when the caster was airborne at the release. Refuse 4/5 specs airborne (the lock pauses instead; in SwayCaster). |
| `scripts/bending/bend_effects.gd` | New `do: "slam"`: a box query under the caster, leaning to the aim's yaw, with a downward launch, Hammer's held-stone throw, Downpour's puddle, Axe's mini floor wave and Down Gust's self-lift. The Pop on jab step 3 (an up launch at contact, with the element burst). Earth's off-deck stone multiplier. |
| `scripts/sway/sway_caster.gd` | Airborne sampled at the release into `_pending`. The air fill rate, the pause of 4/5 in the air, the Chain multiplier in `_hold`'s rate, the jab step lock, the landing-lag state (planted, lock may fill), hitstun (no release, no new cast or guard, the lock frozen in place of round 2's setback, one buffered press), no aim-break of locks in % mode, "root: place" ignored airborne. |
| `scripts/bending/bend_knock.gd` | `hitstun_t` (replaces knock_t's formula in % mode, counted from the hit), the tumble flag, the steering read over the first 0.1 s, the deck bounce, the set spike hitstun, the fall-break window and lockout, the downed state and getup, ragdoll off in % mode. Also edited by IMPACT (its hold hook): merge on top of it. |
| `scripts/bending/bend_status.gd` | `knock(n, v, by, info := {})` carries the move id and spec for stale and the string; the existing callers are unchanged |
| `scripts/player/player.gd` | Behind `BendCombo.on`: steering keys bend the knock instead of being zeroed while reeling (today `reeling` zeroes `target`), the planted state of landing lag, E read as the fall break at contact, and the short hop (MOVEMENT's) |
| `scripts/npc/npc_fighter.gd` | In % mode, hitstun replaces the flinch path (FLINCH_KNOCK_MPS, `_flinch`), with the same landing lag, fall break and downed rules as the player |
| `scripts/npc/npc_bending.gd` + `data/npc/bend_ai.json` | (BOTS owns) on-hit follow-ups, the strings table from §6, aerials when the foe is above or below, Slam edge-guards for hard bots, and the Chain in the true-follow-up test |
| `scripts/bending/bend_poses.gd` + `data/bending/poses.json` | An air form of each pose: the `upper` mask over the new air-legs clip. New poses for the Slams, Axe Kick, the air High Kick flip, the Pop, hitstun, tumble, bounce, fall breaks, downed and getup, and land lag. |
| `scripts/ring/ring_rules.gd` + `data/ring/rules.json` | (RULES owns) sets `BendCombo.on`. % mode lifts `max_push_m`, the 3.5 m cap that would kill launches, and the ring's `ragdoll_mps`. |
| `scripts/ui/match_bar.gd` / practice | (RULES/BOTS own the HUD) The string counter reads `BendCombo.string_hit`. Nothing is drawn on the body. |
| `scripts/ring/ring_lessons.gd` + lessons data | The 8 cards in §7 |
| `tools/anim_author/blender/bend_clips.py` | The clips listed below |

### Clips needed

All are our own and keyed by hand in bend_clips.py. `-l` means the mirrored twin.

- **own-bend-air-legs:** the legs tucked under any air cast (a lower-body mask). This is the one clip that makes every
  deck cast an air cast.
- **own-bend-earth-hammer:** both fists overhead, hammered down in mid-air.
- **own-bend-water-downpour:** arms up, swept down, the body rising a little.
- **own-bend-fire-axe-kick** (and -l): one leg raised overhead, chopped down.
- **own-bend-air-down-gust:** palms driven down, the body lifted.
- **own-bend-fire-flip-kick** (and -l): the air High Kick, a back-flip crescent.
- **own-bend-jab-rise** (and -l): the Pop's rising hand (upper mask). One for all elements; the effect carries the element.
- **own-bend-knock-flinch-light** (upper), **own-bend-knock-flinch-heavy**: short hitstun.
- **own-bend-knock-tumble:** a loop. own-bend-knock-air exists and is its entry.
- **own-bend-knock-spiked:** driven down, arms up.
- **own-bend-knock-bounce:** the back meets the deck and bounces up.
- **own-bend-tech-stand**, **own-bend-tech-roll** (and -l), **own-bend-tech-wall:** a push off a wall or the ropes.
- **own-bend-down-lie** (loop), **own-bend-getup-stand**, **own-bend-getup-roll** (and -l), **own-bend-getup-sweep**.
- **own-bend-land-light**, **own-bend-land-heavy:** landing lag.

MOVEMENT may already list the tumble, fall-break and getup clips. Make each one once.

### Tests (new tests/bending/test_combo.gd and tests/ring/test_aerials.gd, plus soak metrics)

See the structured list returned with this file. In short:
- **Air form:** chosen at the release, both ways.
- **The Slam:** spikes off the deck, bounces on it once per string, never needs pitch, and has each element's touch.
- **4/5:** pause in the air.
- **Land lag:** applies, is halved on a hit, auto-cancels, and never blocks a lock filling.
- **Short hop:** clears no Kick wave; a full hop does.
- **Jab string:** steps, set stun, the Pop once, reset on a miss.
- **The Chain:** only on a hit, never on the same move, not on 4/5/E.
- **Decay, the cap at 6, stale.**
- **Steering:** 15°, read over 0.1 s.
- **Breaking the fall:** window, lockout, roll stays on the deck.
- **Downed:** no lying-down lock.
- **Hitstun fairness:** aim untouched, buffer, lock frozen, symmetric with bots, counted from the hit.
- **The held stone:** strings, air catch and throw, hitstun can't catch, held through hitstun.
- **The gate:** the open world is unchanged without % mode.
- **The soak:** longest string ≤ 5, air-release share.

---

## 10. Owner questions (this part's)

1. **Stale moves.** A move you keep landing hits up to 40% softer; you can still cast it any time. Is that inside "lock
   time is the only spam limiter"? (Recommended: yes; it limits the payoff, not the cast.)
2. **The Chain.** Your hit makes your next lock fill twice as fast. Without it only jab strings combo, because our locks are
   much longer than Smash's start-ups. OK?
3. **Keys 4 and 5 in the air.** They wait until you land: no walls in mid-air, no ice ledges over the water, no healing
   while you fall. OK?
4. **Breaking the fall.** E as you hit the deck or the ropes. A miss leaves you down up to 0.6 s with getup options. Or
   should you always land on your feet?
5. **Fire's 2 in the air is the Axe Kick (down)**, and High Kick stays the crescent. (Recommended, to keep "2 in the air
   hits down".)
6. **Air's Down Gust lifts you a little**, once per jump. Is that too much help off the deck?
7. **Earth's stones off the deck** (more than 5 m up, or over the water) are smaller (× 0.8) unless caught. OK?
8. **Hitstun replaces round 2's hit setback in % mode:** your lock freezes during hitstun and goes on after. OK?
9. **The lowered water** (shared with bots.md): the Slam needs the deck about 6 m over the water, or it is a free KO.
