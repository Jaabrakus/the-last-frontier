# Bending: the spells (design, v4)

The owner's direction (2026-10-04): an Avatar-style elemental game; a 1v1 that becomes a pro-bending match. Each player is one
element; everyone of that element has the same moves. Status: **plan, not built** (a draft of an older version sits in
`data/sway/moves.json` and will be redone to match this).

## Controls (the owner, 2026-10-04: "left click and right click are the same no fast or slow its all the same just different
## skills ... have 1 and the user can toggle between the 1s and then roll the wheel to change that spell to make it easy")

- **1-4** pick a slot; **the same key again** switches between the slot's **two skills** (A / B). **5** is Mend.
- **The scroll wheel** steps through the selected skill's **three variations**.
- **Every move casts the same way:** hold RMB on the aim, the lock fills, release to cast. No fast or slow buttons: the moves
  differ by what they do, not how they are cast. Lock time is the only limit (no meter, no cooldowns); a hit taken breaks
  a lock.
- The HUD says what is ready: `2 · Earth Wall · column (2/3)`.
- **The quick spell on LMB** (the owner, 2026-10-05: "the user needs to be able to put hot spells on left click ... this
  action can be right after"): **Q** (rebindable: `bend_quick_bind`) puts the readied skill at its variation on the left
  button, frozen there (the wheel stepping the key later leaves it): "Left click: Rock Jab (pebbles)". Hold LMB: the same
  lock as RMB's (the same time, circle, pose and aim); let go to cast. Keys 1-5 and their variations are never touched by
  it. One lock at a time: a lock on one button ignores the other, and the other can start the moment the cast is out.
  Defaults: earth Rock Jab (pebbles), water Water Jet (splash), fire Fire Jab (jab), air Air Palm (palm); each element's
  remembered (GameSettings' `quick`). The arena strip shows an `LMB` chip with it; outside the arena (the duel) the same
  chip and help line sit under the hotbar, and F1 tells Q and LMB as they are then. Q with nothing readied says to ready a
  move first. Only a click on the game counts: the click that takes the mouse back (Esc's free mouse) or that picks on the
  equip wheel starts no lock. The readied key's line (HUD, hotbar, Tab screen) keeps the key's variation while the quick
  lock runs. The open world without an element keeps its LMB.
- Moves read and answer each other (the matrix below): blocking, eroding, melting, cancelling, catching and throwing back.

So each element has 4 slots x 2 skills x 3 variations = 24 moves, plus Mend.

## Earth: slow and heavy; cover, knockback, its own stones reused as ammo

| Key | Skill A (variations) | Skill B (variations) |
|---|---|---|
| 1 | **Stone**: spike (fast, pierces) · boulder (slow, huge knockback, rolls) · disc (flat, fast, medium knockback) | **Rock Jab**: pebbles (3 small fast stones) · kick-up (a rock up out of the ground at your feet: cover, or ammo for Shove) · stomp (a knock-up all round you) |
| 2 | **Earth Wall**: wall (cover) · column (rises under the enemy, throws them up) · shell (a dome round you, 2 s) | **Earth Grip**: anchor (you can't be knocked back, 1.5 s) · trap (the enemy's feet held 1 s, on earth) · sink (the ground under the enemy drops: slowed) |
| 3 | **Pillar**: self (launched up and forward) · free (where you aim: a step, a block) · ramp (a slope to run up and leap from) | **Earth Skate**: skate (a dash along the ground) · slide (a low dodge to the side held, the right when none) · burrow-step (a short dash under the ground, to the side as the slide) |
| 4 | **Earth Shove**: push (a stone hurled along the aim; a wall or pillar has a chunk torn out and fired through it) · pull (a stone or chunk yanked to your feet) · split (a chunk broken into 3 that fly in a spread) | **Catch**: catch (a stone flying at you within 6 m caught and held, then Shove sends it back) · deflect (a stone flying at you knocked aside) · brace (your wall takes the next hit for free) |

## Water: control and staying alive; needs water from the pools

The pools refill your water; water moves spend it; standing at a pool fills it fast.

| Key | Skill A | Skill B |
|---|---|---|
| 1 | **Water Whip**: whip (a fast ranged lash) · lash (a close sweep, knockback) · grab (pulls the enemy to you) | **Water Jet**: splash (a short bolt) · jet (a thin pressure stream: little damage, **erodes earth walls** fast) · spray (a mist cone: puts fire out, hides you) |
| 2 | **Ice**: shards (a spread of 5) · spear (one heavy shard) · freeze (the enemy's feet rooted 1.5 s) | **Frost**: ice patch (the ground freezes, the enemy slips) · freeze water (a pool or water wall turned to an ice platform) · thaw (ice melted back to water) |
| 3 | **Wave**: push (a wide knockback wave) · surf (ride a wave forward) · tide (a wall of water; fire dies in it) | **Flow**: water skate (a dash) · geyser (from a pool, the enemy knocked up) · draw (refill fast from a pool) |
| 4 | **Water Shield**: ice wall (cover) · bubble (catches fire and air, 2 s) · heal (stand still to heal) | **Redirect**: redirect (a water or ice bolt caught and sent back) · absorb (a water attack drunk in: refills you) · cleanse (freed from a root, put out if burning) |

## Fire: pure offence; fastest damage, weakest defence

| Key | Skill A | Skill B |
|---|---|---|
| 1 | **Fire Blast**: punch (a fast bolt) · stream (3 rapid bolts) · fireball (a big hit) | **Fire Jab**: jab (a close flame) · double jab · embers (a scatter of small sparks) |
| 2 | **Fire Arc**: sweep (a wide close cone) · kick (a fire wave along the ground) · lightning (huge damage, the longest lock; a hit breaks it) | **Breath**: breath (a short fire cone) · smoke (a screen that blocks sight) · heat (melts ice near you) |
| 3 | **Fire Jets**: jump (up) · dash (forward) · hover (slow your fall, 2 s) | **Footwork**: hop (a short dodge) · back-flip (a dodge backwards) · ignite-step (a dash that leaves the ground burning) |
| 4 | **Fire Wall**: wall (a curtain that burns whoever passes) · ring (a burst all round, knockback) · inferno (the ground before you burns, 4 s) | **Parry**: parry (a fire bolt knocked aside) · **redirect lightning** (lightning that hits you sent back: firebenders only, a tight window) · flare (a flash that dazzles close) |

## Air: movement and pushing; the most knockback, deflection; little damage

| Key | Skill A | Skill B |
|---|---|---|
| 1 | **Gust**: push (people, stones and props away) · pull (yanked toward you) · lift (a stone held and hurled: Gust as it is now) | **Air Palm**: palm (a small knockback) · trip (a sweep at the feet: knockdown) · **cushion** (a stone flying at you slowed to a stop and dropped) |
| 2 | **Air Blast**: ball (huge knockback, little damage) · slice (fast, more damage, little knockback) · vacuum (the air pulled out round the enemy: slowed) | **Evade**: sidestep (a quick dodge left or right) · backstep · spin (light bolts deflected for a moment) |
| 3 | **Air Jump**: leap (high) · dash (long) · glide (a slow fall, steerable) | **Wind Run**: wind run (a speed burst) · whirl ride (ride a ball of air, fast; id air_scooter) · updraft (a hop in the air) |
| 4 | **Air Shield**: shield (projectiles sent back, 2.5 s) · cyclone (knocks back everyone round you) · tornado (a moving vortex that carries the enemy) | **Redirect**: redirect (a light bolt sent back) · gust-step (a dash that knocks aside what you pass) · dust (a cloud that hides you) |

## Mend (5, every element)

Two skills as the others: **Mend** (a wall, pillar or ice wall packed whole again: Mend as it is now) and **Patch** (a little
of your health back).

## How moves meet (the strategy)

**Kinds of attack:** stone (spike, boulder, disc, chunks, pebbles), ice (shards, spear), water (whip, jet, splash, wave),
fire (bolts, arcs, lightning), air (ball, slice, gusts).

**Barriers:**

| Barrier | Stops | Weak to | Lets through |
|---|---|---|---|
| Earth wall / shell | stone, ice, fire, air | **water jet erodes it** (3x wear); a wave turns it to mud (weaker); a boulder breaks it in 2 | nothing |
| Ice wall | water, air, ice shards | **fire melts it fast** (and leaves water: a source); a boulder smashes it | a spike pierces it |
| Water bubble | fire (put out: steam), air; water is absorbed | — | stone, ice, lightning |
| Air shield | sends back fire, water, ice shards, air | — | stone (spike, boulder), lightning |
| Fire wall | burns those passing | water puts it out (wave, tide, spray); air blown through carries the flames on | stone; ice melts going through |

**Attack against attack:**
- water vs fire: both gone in a burst of steam (it blocks sight for a moment)
- water vs water: they cancel
- fire vs ice: the ice melts into water (it falls short)
- stone vs anything but stone: the stone goes on
- stone vs stone: both break
- air vs fire: the air carries the flame (the air ball burns)
- air vs water: the water scatters to spray

**Catching and sending back:**
- **Earth** catches stone (Catch: catch; Shove: pull) and pushes it back with its own speed. **Air** cushions or lifts
  stone.
- **Water** redirects water and ice. **Fire** parries fire bolts, and **only fire redirects lightning**.
- The **air shield** sends back light projectiles (not stone).

**The ground:** ice patches make you slip; water left by melted ice is a source; an earth wall hit by water turns to mud;
fire on the ground burns for a while.

**Pro-bending:** knockback wins. A hit pushes the enemy back through the three zones, and off the edge into the water wins
the round. Health is the backup.

## Animations

Our own clips, authored in Blender. Real martial-arts forms are a reference only: no animation files from the show or other
games are imported.

| Element | Martial art | Feel |
|---|---|---|
| water | tai chi | flowing arcs |
| fire | Northern Shaolin | punches, kicks |
| earth | Hung Gar | stomps, heavy pushes |
| air | Baguazhang | circles, spins |

A stance per element and about one clip per move (about 100 in all, built a little at a time).

## The look of the elements (cel VFX)

2D animated effects stood up in 3D: hard colour bands, bold shapes, no soft dots (BendLooks, BendZone._look; the materials,
meshes and particle recipes in ToonFx, scripts/fx/toon_fx.gd; the shaders in shaders/bend_fx/; all our own, made in code).
Fire is a boiling orb with banded flame tongues and a flame ribbon; water a wobbling head with a stream and two coiling
strands; ice a faceted crystal with a glint; air swirl bands and corkscrew speed lines; stone cel-faceted rock with a dust
streak; lightning forks with a white core in a blue sheath. Hits flash, fling cel puffs, sparks, shards or chunks and leave a
mark on the deck (scorch, wet, frost, cracks). `ToonFx.style` "cel" (default) or "ink" (a dark outline round every shape).
Cheap by construction: ToonFxPool (one per scene) reuses every emitter, shape, mark, light and trail with a cap per kind.
For the integrator: `BendLooks.warm_up(camera)` once the ring stands (it compiles every effect up front: without it the
first fire wall or tornado can freeze a frame for seconds on a Mac); `BendLooks.rise(foot, size, way, matter)` when an earth
or ice wall comes up and `BendLooks.shatter(foot, size, way, matter)` when one breaks (FormRaised raise / crumble).
Stills: tools/bending/vfx_lineup.gd; load: tools/bending/vfx_stress.gd.
Wired (wave 3, 2026-10-05): RingLevel runs warm_up behind the loading screen (the level's meta loading_hold; LoadingScreen
waits on it, RingMode holds its countdown while the painting covers the window): about 0.3 s with Godot's shader cache warm,
35 s in one frame with it cold (behind the painting); after it no effect cast in a fight froze a frame over 60 ms (the round
restarts' bot spawn still costs about 1 s at a countdown). FormRaised plays rise as an earth or ice wall comes up and
shatter when one is shot down. The effects roll their own dice (ToonFx.vis_rng: drawing them never shifts the game's rolls)
and take a brightness per light (ToonFx.set_gain, the shaders' fx_gain; RingLook: night 0.5). Walls are capped in the ring
(rules.json max_walls 2 per caster, earth and ice walls alike: a third crumbles the oldest; FormRaised.count_wall).

## Build order (proposed)

1. Controls: the keys and their two skills (the same key again switches), the wheel through a skill's variations; the
   element loadout; Mend on 5.
2. Earth, all faces (most of its pieces exist), with catch and throw-back.
3. The interactions engine (kinds of attack, barriers, attack vs attack).
4. Water, then fire, then air, each played before the next.
5. The pro-bending ring and its zones; a bot for each element.
6. Animations, element by element.
