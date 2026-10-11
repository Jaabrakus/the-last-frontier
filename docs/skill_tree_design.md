# Bending skill trees (design proposal)

**Status: a proposal for the owner, written 2026-10-09 from the owner's direction of 2026-10-08 and revised the same day
after an adversarial review (section 14). Nothing here is built, and nothing is decided beyond the owner's own words
quoted in section 1.** The draft data is `data/sway/skill_tree.json` (not loaded by the game); the mockup page is built
from it by `artifacts/skill_tree_page/build.py`. Every number is a starting value for the soak to retune; no node changes
what a move is (the identity test, 3.3). Companions: `docs/bending_design.md` (the kits this tree grows from) and
`docs/fighting_styles_design.md` (fighting styles and weapons; the two docs disagree on how a style enters a loadout,
open question 15).

Contents: 1 the owner's ask · 2 the design in one page · 3 how a tree works · 4 the open world · 5 the ring · 6 the
four skill sets · 7 the trees, element by element · 8 synergies · 9 the build-out help · 10 visuals · 11 left out on
purpose · 12 open questions · 13 build order · 14 where this design came from.

## 1. What the owner asked for

Decided by the owner, word for word (2026-10-08):

- Scope: **"Open world + ring sidegrades"**: deep unlocks in the open world and the story; in the ring and PvP
  everyone picks from the same tree on an equal budget, so a choice is a sidegrade, not power.
- What the tree must do: **"the skill tree build outs and how we can enhance and synergize skills"**.
- The fusions, each marked "maybe": **"Water + mud goes together"**, **"Wind and Ice because wind can freeze water"**,
  **"Fire + poison we turn into magma _ lightning? maybe"**, **"earth can have poison original? maybe"**.
- Poison: **"we still have it but users can have skill sets / loadouts"**: a skill set a loadout carries, not a fifth
  element. How skill sets plug into a loadout is not decided (open question 2).

The rules this design keeps, in the owner's earlier words:

| Rule | The owner's words | How this design keeps it |
|---|---|---|
| Easy to learn, hard to master | "make the skills easy hard to master for skills and etc think human made think avg IQ" (2026-10-05); "simple like runescape but hard to master like runescape" (round 4, 2026-10-06) | Classic (no picks) stays the default; the tree opens after the first win; enhances unlock by just playing a move; three starter loadouts per element. The ring's pick list stays short (99 picks over four elements; range-for-width swaps are left to the open world), and no node adds a hidden input. The depth is timing (the Beat, perfect guards), reads, terrain and matchups, never more buttons. |
| A move stays what it is | "bring back the kick" (2026-10-05: the Kick is a floor wave again, not a flame wheel) | The fixed skeleton and the identity test (3.3): the count and shape of what a move sends, its lane, its KO role, its key's job and how it is answered. Nothing is replaced: new skills only fill a tap twice that is empty today. A node that fails the test is held for the owner (questions 3 and 4), never worn. |
| No debuffs from being hit | "we dont want movement debuffs when getting shot there remember we have to keep slows and aiming at neutral" (2026-10-04) | Nothing slows, roots, slides or trips a player, and nothing touches his aim, camera, lock or guard. Poison, mud, ice and magma work through % over time, terrain, area denial and knock. Matter ticks and live reactions don't even do today's hit set-back (3.4). |
| The lock is the cost | "bending moves are on lock so the user has to aim and target the object for x amount of time" (2026-10-02); lock time is the only spam limiter (owner answer O7) | No cooldowns anywhere; every new skill has a lock; a zone that covers its caster lasts no longer than its own lock; techniques give part-full head starts, never a zero lock (3.5). |
| No target cues | "no hud for targets at all", "no chevron over there head", "no ring on enemy hostiles" (2026-10-03) | Nothing is drawn on anyone. The fight HUD gains only your own chip's twist name and a flash on your own hands; all help lives in menus, Practice and the lobby (9). |

### What round 2 cut, and how this tree treats it

The approved round-2 spec (`docs/tidebreak/r2_skills_owner_summary.md`, "What got cut"; answer 5, as the answers file
records it: "the spec's recommendations stand") cut a list of moves on 2026-10-05. Answer 4 kept the Fireball, Embers and Breath ("Keep
them all"), and the answers file records under it that "the other fire cuts in the spec — sweep, ring, inferno,
stream, double jab, flare, the flame wheel — stand". The first draft of this tree brought several cuts back without
saying so. Now:

| Round 2 cut | In this tree |
|---|---|
| Stream and Double Jab (fire) | Left out (11). |
| The shell and the ramp (earth) | Held for your answer (question 3): Shell (a new skill on 4) and Ramp (a Lift twist). The open world keeps its own shell and ramp world modes, as today. |
| The bubble, the shards and the Lash jet (water) | Held (question 3): Bubble, Shatter (your Ice Wall bursts into shards), Jet (Splash as six bolts). |
| Breath's smoke, which you kept ("leaves a SMOKE screen where it burned") | Clean Burn, which takes it away, is held (question 3). |
| The "skill with three variations" layer (the wheel) | Not back. A twist is one pre-match pick per move, worn all game, never switched in a fight. A few twists draw on a dormant mode of that layer and say so (Hold the Storm, Ignite Step, Cleanse, Dust Cloud). |
| Hidden rules (the kick picked by where the crosshair points, Lift's footstep timing) | Shear (A or D held at release bends the Gust) is left out for the same reason. The Beat is a timing you see on your own lock, widened to 0.2 s (3.6). |
| Every root and slow that can land on a player | Never wired into a node (11). |

## 2. The design in one page

- **One tree per element, drawn as the BendStrip on its side**: seven chip columns (LMB, E, 1 to 5), each move's line
  growing up from its chip: enhances, then a twist fork, then a technique. Branches are named groups of chips.
- **Node kinds** (the player's words; 3.2): Enhance (a number trade, 1 point), Twist (what a move does after it leaves
  or lands, 2), Technique (a timing technique, 2), New skill (a move on a tap twice that is empty today, 3), Passive (the
  element's passive retuned, or a set's home ground, 2), Synergy (another element's matter, 1), Skill set (2, opens its
  nodes), and World only (open world, never in the ring). In all: **133 nodes: 99 ring picks,
  14 held for your answer, 11 number swaps for the open world only, 9 world arts.**
- **One skill set per element** (one per loadout; a proposal, question 2): earth **Sulphur** (the poison), water
  **Mud**, fire **Magma**, air **Frostwind** (ice). Fire's lightning is its **Storm** branch: Lightning is already
  fire key 1's tap twice, so it grows a family instead of becoming a second set.
- **Open world: deep.** Learning by doing: practise a move and its enhances open; a teacher teaches twists; a trial
  opens a technique; a story quest opens a set. Ranks II and III, a budget that grows from 6 to 20 points, and the
  range-for-width enhances are open-world depth only.
- **Ring and PvP: flat.** Every ring pick is open to everyone on the same 10 points, and every pick gives something up
  (synergies and new skills included). Loadouts are soaked against Classic and against each other at 0.47-0.53, so
  wearing nothing is never behind. Game 1 is picked blind; after that the loser counter-picks. Classic stays every new
  player's default.
- **Synergies**: world rules that act only on matter a pick makes (fire lights gas, lightning charges it, water washes
  gas and cools magma, wind carries gas and snow, mud stops floor fire, fire bakes mud and melts frost), so Classic plays
  exactly as today; 8 synergy nodes, each with a trade. Whoever sets a reaction off owns it.
- **The help**: starter loadouts, node cards with previews, Try it in Practice, a Coach with at most three suggestions
  from your own tally, Build for me, synergy threads, a 3v3 team web, a threat row, a counter card. Nothing in the
  fight.

## 3. How a tree works

### 3.1 The shape

The tree screen is the BendStrip on its side: seven columns under the chips the player already knows (`LMB · JAB`,
`E · GUARD`, `1 · STRIKE`, `2 · PUSH`, `3 · DASH`, `4 · WALL`, `5 · HEAL`), plus the passive. Each move-mode has its
own line up its column (Spike and Boulder are two lines, as are Fissure and Column): enhances at the bottom, the twist
fork above them, the technique at the top. Branches are named threads through the columns; the skill set is a band
along the bottom that tints the chips it touches; the world arts are listed apart and greyed out in the ring.

| Element | Kit branches (chips) | Skill set | World arts |
|---|---|---|---|
| Earth | Rally (LMB, E) · Quake (1, 2) · Bulwark (3, 4, 5, passive) | Sulphur | Stone Disc, Raised Column and Shell, Free Pillar and Ramp |
| Water | Lash and Turn (LMB, 1 Lash, E, passive) · Surge (2, 3) · Ice (1 Spear, 4, 5) | Mud | Freeze the River, Healing Water |
| Fire | Blaze (LMB, 1 Punch, E) · Kicks and Steps (2, 3, passive) · Cover and Heal (4, 5) · Storm (1 Lightning, E against Lightning) | Magma | Hover, Heat |
| Air | Blade (LMB, 1, E) · Squall (2, passive) · Drift (3, 4, 5) | Frostwind | Wind Run and Whirl Ride, Glide Landing |

Branch names avoid the Thủy Vân art names (Current, Stone, Hearth, Wind), the `moves.json` art ids (`tide`, `gale`,
`ember`, `earth` and the rest) and the passives' names, so nothing reads twice once the world's dress lands.

**New skills fill only the tap twice that is empty today** (`moves.json` "elements"): earth, water and air key 4, and
fire and air key 5. Fire uses 5 because its 4 already holds Breath. Each new skill keeps its key's word: on 4 (WALL) it
is cover or ground you place, on 5 (HEAL) it is recovery. Air's 5 stays empty in this draft. Every element tops out at
10 moves on its keys (air 9). A one-id key with two modes already works (`Bending.other_move` flips the mode), so each
new skill is a second mode on the key's own move **for its wearer only** (per-body modes): `patch` is one move id that
every element shares, and air's key 5 is the same one-id key, so Cauterize added to `patch` for everyone would land on
air too. No change to `Bending.keys`, nothing replaced, every true string kept.

| Element | Slot | Its word | The choices |
|---|---|---|---|
| Earth | 4 tap twice (`earth_wall`) | WALL | Sulphur Vent (needs Sulphur); Shell is held (question 3) |
| Water | 4 tap twice (`water_shield`) | WALL | Mire (needs Mud); Bubble is held (question 3) |
| Fire | 5 tap twice (`patch`) | HEAL | Cauterize |
| Air | 4 tap twice (`air_wall`) | WALL | Dust Cloud, or Blizzard (needs Frostwind) |

### 3.2 Node kinds and costs (proposal)

| Kind (the player's word; data id) | Ring cost | What it is | Ring limit |
|---|---|---|---|
| Enhance (`enhance`) | 1 | A number trade: one plus, one stated minus, each number within 20% (an integer count moves one step). The ring keeps the ones you can feel; range-for-width swaps are open world only. | Any, within the move-mode cap. |
| Twist (`variation`) | 2 | What a move does after it leaves or lands, inside the identity test (3.3); sometimes a dormant mode spec, named. A skill set's twists share this slot. | One per move-mode (a fighting style's signature counts as it: 5). |
| Technique (`mastery`) | 2 | A timing technique, paid by the Beat (3.6) or by a perfect guard, always with a trade. With passives, the only kind that may start a lock part-full. | One per loadout (a style's perfect-guard reward counts as it). |
| New skill (`new_skill`) | 3 | A move on the empty tap twice (3.1), with a trade on its key's first move. | One per loadout. |
| Passive (`passive`) | 2 | The element's passive with retuned numbers (its rule stays), or a set's home ground: an aura in your own matter. | One per loadout. |
| Synergy (`synergy`) | 1 | Makes a cross-element reaction yours, bigger, or solo, with a trade. | Any; team-only ones greyed out in 1v1. |
| Skill set (`skill_set`) | 2 | The set's matter rule (6); opens its nodes. | One per loadout (a proposal: question 2). |
| World only (`world_only`) | none | Open-world travel and work. | Never in the ring. |

The words are the player's; the data ids stay what the loader and the page key on (`kind_labels` in the data).
"Variation" was the name of the round-2 layer the owner cut, and "Mastery" is the per-move practice tier (untrained,
practised, expert) the HUD already shows, so a player never reads either for a node. The four home-ground nodes (Sulphur
Heart, Delta, Forge, Whiteout) are auras, not techniques, so they are passives.

Also: at most **4 points on any one move-mode** (passives, sets and synergies are capped by their kind instead), and
two nodes that pull one number opposite ways can't be worn together (3.7). Every node carries one help line of 64
characters or fewer.

### 3.3 The fixed skeleton and the identity test

**Fixed skeleton.** Which move sits on each key, the jab, the guard and each passive's rule never change. 1 is always
Spike, Lash, Punch or Slice; E is always the element's guard. Column, Geyser, High Kick and Mend stay where they are.
Every true string stays true (Column then Pebbles, Geyser then Lash or Spear, Kick or High Kick then Punch, Embers then
Punch, Pull then Palm, Gust then Slice, and every jab, jab, Pop): a node that touches a string's lead or follow-up is
re-checked before ranked (5). Only key 4 makes walls (round-2 spec 2.7, `rules.json` `_max_walls`).

**The identity test** (one test per node; a node that fails any check is held for the owner or rescoped, never worn;
each node's verdict is its `identity` in the data):

1. **Delivery**: what the move sends keeps its count and shape until it lands or hits (one bolt stays one bolt, a spray
   a spray, a cone a cone, one rise one rise). What it leaves where it stops may be new: a burst, a puddle, a cloud, a
   seam, loose stones.
2. **Lane**: along the floor, through the air, or up from under you, as today.
3. **KO role**: a KO move stays a KO move (it may KO sooner or later), a launcher stays a launcher, a move that never
   KOs never does; every true string it leads or follows stays true (re-checked).
4. **The key's job**: LMB a close poke, 1 a shot, 2 a push or a launcher, 3 travel that never hits on its own path (it
   may leave matter behind, as Skate leaves puddles), 4 cover or placed ground, 5 recovery, E the guard table.
5. **The answer**: the guard that takes it and what that guard does with it ("E: on the beat it's yours. Late, half gets
   through. Earth always catches stone." stays true), the wall cell that stops it (each wall's stops / weak to / lets
   through row), its tell (the Column and Geyser 0.35 s rise, Lightning's 0.25 s hand flash, the Spike rising at 60% of
   the lock, the Kick's crest that a jump clears), its wind-up pose and limb (a twist may swap the release clip within
   the same limb) and its flight sound.

A node may **add** an answer (mud stops his floor fire; Frost Gust snuffs his fire wall; a Kiln-heated stone can be
parried). No node removes or changes an answer he already relies on.

What the test changed in the first draft: **held** (question 4) a volley in place of one move (Forked Fissure, Twin
Geyser, Twin Wave, Twin Slice), a dash that hits (Surfacing Stomp, Breaker, Gust Step), and Reel (the Lash, a KO strike,
made a set pull that never KOs, copying air's Pull); **rescoped** Aftershock (its stomp ring added a hit and a new
answer, "step away or jump") into Heave, and Magma Fist (its arc changed the Fireball's flight) into a straight shot;
**dropped** Slingshot (it loses Pull then Palm).

### 3.4 No debuffs: the tick contract

What the code does today (checked): `BendR3.deliver` calls `SwayCaster.took_hit` on every delivered hit, which breaks a
Lightning charge; in the classic zones ring `_on_hurt` also sets a running lock back; in the % ring every launch has a
hitstun of at least 0.12 s (`stock.hitstun_min`). A gas cloud that ticked through that path would break Lightning and
stun whoever stood in it. `BendStatus.root` and `slow` already do nothing to element casters, but several dormant specs
still carry roots and slows (section 11), and the ice patch and vacuum zones call `BendStatus.slow`.

The contract (proposal) for every matter tick (gas, magma seams, burning lines, a Blizzard's cold):

- it adds % only: 1% each 0.5 s, capped per zone (a gas cloud 6%, a puff 3%, a seam 4%, a burning line or patch 3%,
  a Blizzard 6%), and a body gains at most one tick each 0.5 s however many zones it stands in;
- it never slows, roots, touches aim or camera, sets back or freezes a lock, breaks a Lightning charge, touches a guard
  window, causes hitstun, adds a string hit or string decay, or counts as a stale move;
- your own matter never hurts you; a reaction (a burst, live water or gas) hurts everyone in it;
- in data: a `no_flinch` class (today's flag: % only, no knock, no stun, as `fire_wall/tick`) plus a new `no_hurt`
  flag that skips the hurt path above. The live reactions (Live Gas, Forked Lightning's live water) carry `no_hurt` too,
  so "nothing touches his lock" holds for them.

Open: today Fire Wall's own tick does break a Lightning charge; whether it should follow the same contract is the
owner's call (question 16).

Terrain stays terrain: mud never slides or roots, frost crust is never slippery, nothing changes a launch for the one
who was hit (no "knock x1.15 on ice", no "launch x0.85 in mud").

### 3.5 Lock time stays the only limiter

- No cooldown timers anywhere in the tree.
- Every new skill has a lock; "one at a time" (a new zone ends your old one) is a cap, not a timer.
- A zone that covers its own caster lasts no longer than its own lock, lets no lock start while it stands, and pops
  after 2 hits (Shell and Bubble, both held). The first draft's 1.5 s Bubble on a 0.45 s lock could be kept up for
  good by locking the next one while it stood; now one lock buys at most its own length of cover, with nothing to
  shoot from inside.
- Lock changes are the caster's own: techniques and passives may start a lock part-full (30% to 50%) or fill it
  faster; never a zero lock, never a follow-up with no lock. Enhances and twists never do (Hot Hands moved to the
  techniques for this).
- Nothing adds lock time to the one who was hit.

### 3.6 The Beat (proposal)

One shared timing rule pays for most techniques: **let a held cast go within 0.2 s after its lock fills**. For a
Catch, E again within 0.2 s of a clean catch. A click never counts (the click buffer casts the moment the lock is
full), and neither does a cast that goes by itself. The cue is a click and a brief glow on **your own hands** only.
The first draft's 0.12 s sat under human reaction time; 0.2 s is still tighter than the perfect guard (0.3 s), and you
see it coming on your own lock's fill. It sits well inside the sputter (0.7 s), so waiting for the Beat risks nothing.
The guards already teach "on the beat". With no technique worn the Beat does nothing, so nobody has to learn it. Hard
bots hit it at a rate set in `bend_ai.json` (proposal: easy 0, normal 0.2, hard 0.5). Techniques gate on expert plus a
trial; there is no fourth practice tier (mastery has three tiers in data and code).

### 3.7 Rules the new nodes need

- **Guards in the % ring.** The % ring reads the stock numbers: `RingRules.guard_outcome` takes `guard_perfect_s` (0.3)
  and `guard_catch_s` (1.0), its hit path takes `late_mult` (0.5), and a held guard stays up while E is held, up to
  `guard.hold_max_s` (2.5 s). A guard spec's
  `window_s`, `life_s` and `late_mult` never reach it, so the first draft's guard trades did nothing there. Every guard
  node now trades in those terms, as the wearer's own copy: the beat's length (Patient Turn, Eddy, Reaching Parry, Drift
  Guard), the full-catch time (Juggle), what a late guard lets through (Patient Turn, Whirl Turn, Hot Hands), how long a
  held guard stays (Rebound), walking with the guard up (Drift Guard), or what a perfect sends back (Clean Return, Hold
  the Storm). Each guard node gets a % ring test, tapped and held.
- **Several stones in one Catch window** (Avalanche, Carrying Wind; Pebbles is already a three-stone volley): the Catch
  holds one stone (two with Juggle) and the rest drop at the catcher's feet as the thrower's loose stones. Earth still
  always catches stone. Confirm what today's Catch does with Pebbles and keep it if it matches.
- **Stacking and opposite pulls**: two nodes changing one number the same way multiply their ratios (0.8 s x 0.95/0.8 x
  0.7/0.8). Two nodes that pull one number opposite ways can't be worn together, so a pick's cost is never bought back
  by another pick. The loader computes these from `changes[]` (a class change counts on its base tag); the excludes in
  the data are that computation, checked (20 pairs added in this revision, among them Long Kick and Lava
  Kick, Heavy and Sulphur Boulder, Thick Wall and Brimstone Wall, Thick Ice and Shatter, Standing Wind and Frostwind,
  Full Sail and Frost Gust, Lazy River and Long Reach, Twin Slice and Carry the Edge, Heave and Fuming Column, Second Wind
  and Whiteout). A set twist's number is final for that move.
- **Per wearer**: every change applies to the wearer only. Today `Bending.passive()` and `Bending.rules()` are shared
  per element, `SwayCaster.modes_of` is per move, and the stock guard and Patch numbers are shared, so the tree needs
  per-body copies of all of them.
- **The % ring's numbers**: the live table is `rules.json` stock.classes (`bending_design.md`'s % table is older: the
  Punch adds 15, not 11; the Boulder 16, not 22; the Slice 11, not 6). Each twist and class-changing enhance sends its
  own tag (the base tag plus `+name`, with its own class). Every consumer of a tag reads it through **one shared lookup
  that strips the `+name`**, with a test: stale-move counting, `stock.range.exempt` (so Short Fuse's Lightning keeps its
  range exemption), `air_rules.lag_class`, `stock.return_base_tag`, the highlights and `bend_ai.json` pct.strings.
- **What a node applies to**: passives, sets and synergies list what they change in `applies_to` (move/mode tags,
  `passive:<id>`, `zone:<kind>`, `pool:grate`); their `extends_move` only anchors them under a chip, so a loader or
  page never files Deep Roots under the Spike.
- **Terrain ownership**: terrain made from someone's matter stays his. A melted crust's puddle is the water's owner's
  (a grate's crust melts back into the grate); an obsidian stone counts toward the seam owner's three loose stones (his
  oldest crumbles); the extra Avalanche stones that drop at a catcher's feet are the thrower's.
- **Practice counts**: `SwayCaster` counts uses per move id, so Spike and Boulder share `stone_form`'s count. The
  gates here use move ids; per-mode counts are not needed.

### 3.8 Where the tree applies

- **The % ring and every PvP mode** (5): the picks apply under the % rules (`RingRules.stock_on()`).
- **The classic Zones ring** (Esc, Rules: Zones) plays Classic (no picks): several trades exist only as % classes
  (Swift Lance, Snap Punch, Cold Hands, Short Fuse and others put their minus there), and the Zones ring never reads
  them, so they would turn into pure upgrades or downgrades.
- **The open world** reads a class change as the same ratio on the spec's damage (from `d`) and `knock_mps` (from
  `base`), so a trade made of a spec plus and a class minus stays a trade there.

### 3.9 Control schemes

Keys, Basic (which plays the Keys routing: `schemes.json` controls) and the Wheel reach every node; the Wheel gains one
entry for a worn new skill (earth and water 9 to 10, fire 9 to 10, air 8 to 9). First moves only and Direction reach
only each key's first move, so under them the loadout screen greys out every node on a tap-twice move (the new skills,
and nodes on Boulder, Column, Lift, Spear, Geyser, Surf, Lightning, High Kick, Jets, Breath, Wind Ball, Pull, Leap or
Mend) with one line saying why.

## 4. The open world: deep (proposal)

- **You learn by doing.** An enhance opens when its move reaches *practised* (8 landed uses, `moves.json` mastery). A
  twist needs *expert* (30) and the element's teacher, who teaches it as a short drill done by doing it (the
  RingLessons pattern, logged in the knowledge journal). A technique needs expert and a trial (a short quest drill). A
  passive needs expert in any three of the element's moves and the teacher (a home ground: expert in any two of its
  set's moves and a trial). A new skill needs expert in its key's move and the teacher (a set's new skill: its set
  teacher). A skill set comes from its story quest and its teacher. A synergy is discovered: it shows as "???" with a
  hint of the two matters until you have seen the reaction once. A held node waits for the owner's answer.
- **Ranks.** An enhance grows to rank II when its move reaches expert and to rank III through its teacher: the plus
  side x1.5 at II and x2 at III, the minus unchanged. The ring always reads rank I. While `free_use` is on (every spell
  counts as expert), ranks stay at I: free_use makes nodes known, not ranked.
- **Budget.** The points you may wear grow with the story: 6 at the first lesson, then 10, 14 and 20 by the last
  chapter. Unlocks are permanent; only what you wear changes. The open world keeps mastery's lock_mult by practice
  tier (1.4 / 1.0 / 0.8): there, practice is power.
- **Open-world depth.** The range-for-width enhances (Broad Column, Long Reach, Broad Wave, Long Kick, Long Curtain,
  Long Lightning, Wide Palm, Long Gust, Long Pull, Standing Wind) and Featherfall are worn only here, where the
  ranks grow them.
- **Open-world PvP** (question 13): when two players meet in the open world (the co-op and PvPvE direction), this
  draft proposes open-world power (the budget, ranks and practice lock times), because that world is the progression;
  arranged and ranked PvP use the ring's flat 10 points.
- **Respec** is free at any rest (a camp, a bed, a shrine, a teacher, the ring's locker), never in a fight. Three saved
  loadouts per element. Practice counts never reset.
- **Teachers and quest homes**: one teacher per element, one per skill set, and a storm teacher for fire's Storm
  branch. Names and places are the Thủy Vân world session's to make; this draft names only roles and suggests homes
  (sulphur springs, river-delta mud flats, a forge mountain, a high snow pass, a storm watch).
- **free_use** is on today, so every node is known and the open world uses the ring's 10 points: the tree can be played
  now, and the gates return when free_use goes off.
- **Ring practice** earns only cosmetic mastery badges, never open-world unlocks, so nobody grinds unlocks in PvP (an
  owner call, question 14).
- **World arts** are the open world's existing modes and dormant travel specs (the stone disc, the wall's column and
  shell, free pillars and ramps, freezing a river, healing water, hover, heat, wind run, a safe glide landing): listed
  so the tree shows them, never in the ring.

## 5. The ring and PvP: flat and equal (proposal)

- **Everything open, same budget.** Every ring pick is open to everyone in the ring and in every PvP mode, whatever
  they have learned in the open world. Everyone wears **10 points**, with the limits in 3.2. Held nodes are never worn.
- **Same tier.** Everyone casts at lock_mult 1.0. The % ring already does (`SwayCaster.tier_mult` returns 1.0 under
  round 3, whatever the tier); the classic zones ring needs the same gate once free_use goes off, or open-world
  practice would shorten its locks. Each node's ring numbers are its own and never read ranks II and III.
- **Caps per player**: 4 gas zones (clouds and puffs), 4 puddles and mud pools, 2 magma seams, 2 pieces of low terrain
  (frost crust ridges and Mud Mounds), and 2 walls (the earth wall and the ice wall: only key 4 makes walls, so
  `rules.json` wall_moves gains nothing). Fire Wall, Wind Wall, Dust Cloud, Sulphur Vent, Mire and Blizzard stand one
  at a time (a new one ends your old one).
- **Cover and sight.** A zone that covers its own caster lasts no longer than its own lock, lets no lock start while it
  stands and pops after 2 hits (3.5). Sight blockers are placed where you aim or left where a move ended, never centred
  on the caster (Dust Cloud is placed 2-6 m).
- **Nothing hidden, nothing on him.** Both loadouts are on the versus card before the countdown (one line each) and in
  F1 and Esc at any time; a counter card gives one "how to answer" line per pick. In the fight, only your own chip names
  your twist (`1 · Boulder: Avalanche`).
- **When to change**: game 1, both players pick blind and lock at the same moment. In a set, the winner of the last
  game locks first and the loser may then change (the counter-pick fighting games give the loser). One loadout for all
  three lives; never mid-game.
- **New players**: Classic (no picks) is the default. The tree opens after the first ring win, the moment Basic
  controls unlock Wall and Heal, showing enhances and the starter loadouts first; twists, sets and techniques open
  after the Full lessons. A player's first 5 Quick matches meet Classic or easy bots.
- **Starter loadouts**: three per element, each exactly 10 points and inside every limit (checked by the validator),
  one click to wear (7).
- **Balance gate** before a node reaches ranked: the soak (`tests/ring/test_ring_soak.gd`, 16 pairings x 3 seeds) on
  starter loadouts, then on random legal loadouts. A node's win share must land at 0.47 to 0.53 against the same kit
  without it, and against the other picks of its cost on the same key. **Every loadout** (the starters and the random
  ones) must land at 0.47 to 0.53 against Classic and against the others in the soak: a loadout is a sidegrade, never a
  power gain over wearing nothing. A node in more than 60% of its element's ranked loadouts, or with a win delta above
  3%, gets its ring numbers retuned, never its identity. A node that fails two soaks leaves ranked (it stays in
  Practice and casual). The soak also measures the share of each player's game spent shielded or unseen (inside his own
  Shell, Bubble, Dust Cloud, Blizzard, smoke or steam): no loadout above 20% (proposal).
- **True strings**: before ranked, every node that changes a string's lead launch or a follow-up's lock or speed is
  re-checked against `bend_ai.json` pct.strings and the result recorded in the data (`ring.string_recheck`):
  Fuming Column, Heave, Mud, Mud Lash, Mud Mound, Heavy Spear, Cold Hands, Crescent Burn, Lava Kick, Snap Punch, Tight Embers, Shoving Palm, Rising Gust, Keen Edge. Round 3's `lead_combos.py` is not in this checkout or its history (it lived in the round-3
  scratchpad), so this is **not run yet**: rebuild the tool, or measure with RingPredict through Practice's string
  counter, which uses the same functions the bots use.
- **Recovery**: no ring node changes anything you do off the deck (the Rise, the double jump, the air dodge, the Slam's
  self-lift, the edge) or lengthens an element's recovery reach (earth 11.3 m, water 11.8, fire 15.8, air 17.4). Key 3's
  travel moves start only on the deck (in the air key 3 is the air dodge, `SwayCaster.key3_press`), so nodes on them are
  measured by the recovery soak instead. By this rule Hover and Lifting Down Gust stay out, Ride the Updraft became Peak
  Wind (no extra height), and Featherfall is open world only (the % ring has no Leap glide: `BendEffects` glides only
  when `RingMoves` is absent).
- **Bots**: easy bots wear Classic, normal bots one starter loadout per element, hard bots all three, with a Beat
  rate. Before any set reaches ranked, bots must read the zones (step out of gas, seams and Blizzards; wash, blow or
  light gas; dry mud; jump crust and mounds) and cast the new skills they wear (Sulphur Vent, Mire, Dust Cloud,
  Blizzard, Cauterize; Shell and Bubble only if the owner brings them back, and then answer them too). Bots read tags
  through the shared `+name` lookup, so a varied lead still matches pct.strings.
- **3v3**: the same 10 points each. No limit on duplicate sets per side at first; "one of each set per side" only if
  the soak shows stacking. Team-only synergy nodes are greyed out in 1v1 queues so no point is wasted.
- **Fighting styles and weapons** (open, question 15): this draft kept them outside the 10 points, but
  `docs/fighting_styles_design.md` says a ring loadout is style + weapon, both on the budget, each a branch of this
  tree. Until the owner rules: weapons stay out (on hold since 2026-10-08); a style's signature counts as its
  move-mode's one twist, and its perfect-guard reward (Boxing's, Judo's) as that guard's technique, so it never stacks
  with Hot Hands, Eddy or Rebound; where a style lever and tree nodes touch the same number (the Defence lever and a
  guard node's beat, for one), their total change is clamped to 25%.
- **Online**: zones, terrain and reactions must be host-authoritative and synced; NetSession has nothing for bending
  zones yet.

## 6. The four skill sets (proposal)

Every set is one entry node (2 points) that changes the matter your existing moves leave, plus its own twists and a
home-ground passive; earth, water and air also get a set skill for their empty tap twice on 4 (fire's free slot is
5, HEAL, so Magma has none and fire wears Cauterize or nothing there). Every set prints three counter lines at the
element pick and on the counter card, so any element can answer it with no points spent. The home-ground passives share
one rule: **in your own matter your locks fill x1.15** (caster only; with Rooted the higher counts, they never
multiply), each with its own trade. **One set per element and one per loadout are this draft's reading, not the
owner's** (question 2): he has not said whether a set sits inside the 10 points, whether a loadout may carry several,
or whether a set can cross elements.

### Sulphur (earth): the poison

- **The owner's words**: "earth can have poison original? maybe"; "we still have it but users can have skill sets / loadouts".
- **What it is**: poison, as an earth skill set (never a fifth element).
- **The rule**: Your stones carry sulphur: your Boulder vents a cloud where its roll ends, and a cloud rises where your stones clash with his. Set twists add more sources (Spike, Boulder trail, Column, Wall) and the Sulphur Vent places one.
- **Three counters** (printed at the pick and on the counter card): Fire lights it. Wind carries it. Water washes it.
- **No debuffs**: Gas adds % over time and nothing else: no slow, no root, no aim sway, no lock or guard change, no hitstun, no lock set-back, no Lightning break, no stale-move count. Its levers are area denial and the reactions (a burst when lit, half a strike when charged).
- **Nodes**: Sulphur (skill set, 2); Sulphur Spike (twist, 2); Sulphur Boulder (twist, 2); Fuming Column (twist, 2); Brimstone Wall (twist, 2); Sulphur Vent (new skill, 3); Flint Pebbles (synergy, 1); Sulphur Heart (passive: home ground, 2).
- **Learned**: its story quest and teacher; quest home: hot springs and sulphur vents (for the Thủy Vân world session to place).
- **Look**: yellow-green clouds and bubbling vents; sulphur veins on stones (159 FX_PoisonCloud*, 161 FX_PoisonCloud_RevA*, 17 P_Poison_Primary_Dissipate, 164 FX_Poison_Bubbles, 168 P_PoisonCloud_Dissipate, 845 ShrineB_Toxic_FxP).

### Mud (water): water and earth

- **The owner's words**: "Water + mud goes together".
- **What it is**: water and earth, as a water skill set.
- **The rule**: Your puddles are mud pools: they last 8 s, are still your sources, and stop what runs along the floor (fire's floor waves, rolling stones) while lightning grounds in them and magma is quenched.
- **Three counters** (printed at the pick and on the counter card): Fire dries it. Shots through the air pass over it. Rising moves (Column, Geyser) still come up through it.
- **No debuffs**: Mud never slows, slides or roots anyone, and never changes a launch. It is terrain: it stops things that run along the floor.
- **Nodes**: Mud (skill set, 2); Mud Lash (twist, 2); Mudslide (twist, 2); Mud Mound (twist, 2); Mire (new skill, 3); Delta (passive: home ground, 2).
- **Learned**: its story quest and teacher; quest home: river-delta mud flats (for the Thủy Vân world session to place).
- **Look**: brown pools with slow bubbles; brown, clod-flinging water (164 FX_Poison_Bubbles, 227 AG_CauldronBubbles_FxP, 523 CB_SlimySeepage02_FxP, 281 AG_StreamOfOoze01_FxP); to author: mud: Spellbreak has no mud; recolour bubbles and ooze, author a mud splat.

### Magma (fire): fire and earth

- **The owner's words**: "Fire + poison we turn into magma _ lightning? maybe".
- **What it is**: fire and earth, as a fire skill set.
- **The rule**: Your floor fire runs molten: where a Kick's wave (or the Axe Kick's) dies it leaves a seam that burns whoever stands in it and cools into earth's ammo under water.
- **Three counters** (printed at the pick and on the counter card): Water cools it to stone. Jump it or step off. Mud quenches it.
- **No debuffs**: A seam adds % to whoever stands in it and nothing else: jump it or step off; no slow, ever.
- **Nodes**: Magma (skill set, 2); Magma Fist (twist, 2); Lava Kick (twist, 2); Magma Landing (twist, 2); Forge (passive: home ground, 2).
- **Learned**: its story quest and teacher; quest home: a forge mountain (for the Thủy Vân world session to place).
- **Look**: glowing cracked rock; molten splashes; obsidian stones (74 DragonFire_PuddleIgniteFX_ScaleFX, 404 ChestLava_FxP, 521 CB_SinkingInferno01_FxP, 81 Flame_Boulder_FX, 33 CB_ObsidianPlummet_Unified_FX); to author: the seam: recolour the DragonFire puddle flames orange-black over a dark crust.

### Frostwind (air): the ice

- **The owner's words**: "Wind and Ice because wind can freeze water".
- **What it is**: air's ice, as an air skill set (air freezes the water that is there; water keeps shaped ice).
- **The rule**: Your wind freezes water it crosses: puddles and the deck's grates become frost crust ridges, steam falls as snow, water and ice blown aside by your Wind Wall fall as shards.
- **Three counters** (printed at the pick and on the counter card): Fire melts it. Jump the crust. Mud never freezes.
- **No debuffs**: Crust is never slippery and never slows; it is a low ridge you jump. The Blizzard's cold adds % only, and its sight block works both ways.
- **Nodes**: Frostwind (skill set, 2); Hail Ball (twist, 2); Frost Gust (twist, 2); Rime Wall (twist, 2); Blizzard (new skill, 3); Whiteout (passive: home ground, 2).
- **Learned**: its story quest and teacher; quest home: a high snow pass (for the Thủy Vân world session to place).
- **Look**: frost on the hands; low ice ridges; snow columns (122 Blizzard_Cyl1_FX1, 123 Blizzard_Cyl1_FX2, 12 P_Frozen_Explosion, 9 P_Earth_Primary_AOE_Frozen, 125 BoulderFrozen_Mist_FxP, 753 P_Chapter2_Snowflakes); to author: the crust ridge: an ice-wall look kept low; the Blizzard column: 122 and 123 are a ~50 m stationary cylinder, cut down to 2.5 m.

### Storm (fire): the lightning

- **The owner's words**: "Fire + poison we turn into magma _ lightning? maybe".
- **What it is**: the owner's 'lightning', kept as a fire kit branch (Lightning is already fire key 1's tap twice), not
  a second fire skill set (one set per element is this draft's proposal).
- **Portable**: the Lightning nodes extend `fire_arc`, so they move with Lightning if the Thủy Vân dress gives Thunder
  to the Wind art (mechanics unchanged). Hold the Storm extends `fire_parry`: it stays with fire's Parry, the only guard
  answer to Lightning, wherever Lightning goes.
- **Nodes**: Short Fuse (enhance; Long Lightning is open world only), Forked Lightning and Hold the Storm (twists),
  Grounded Charge (technique). A perfect Parry stays the only guard answer to Lightning; its 0.25 s hand flash stays the
  tell.
- **Meets poison**: Live Gas (8): lightning through gas charges it instead of lighting it.

## 7. The trees, element by element (proposal)

How to read the tables: the node, the move and mode it extends (`moves.json` id), its kind and cost (held nodes wait
for your answer; "open world only" nodes are never in the ring), what it does (with its plus and its minus, and for a
twist or new skill the line that says how he answers it), how the open world teaches it, and the look it needs (a
visual kind, then Spellbreak references as index and name in `artifacts/spellbreak_fx/specs/index.json`; `*` marks an
effect the sweep found faint, static or approximated, to check first). The full numbers, with every "from" value
checked against `moves.json` and `rules.json`, and each node's identity verdict are in the data file.

### 7.1 Earth: rooted, heavy, catch-and-return

Skill set Sulphur; the free tap twice is 4 (Sulphur Vent, which needs Sulphur; Shell is held); passive Rooted. The earth mirror's catch-and-send-back is the fun core the owner named, so the Rally branch deepens it and never touches "earth always catches stone". Left plain on purpose: Shove (earth's ammo engine: the Rally and Quarry nodes play with its stones; Forked Fissure is held), Lift (Ramp is held) and Patch.

#### Rally (LMB, E)

Catch and send back: the earth mirror's fun core, timing over reach. The Catch's identity never changes: stone is always caught and held.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Clean Return** `stone_catch/catch` | Enhance, 1 pt | A clean catch's throw-back leaves at x1.3 (from x1.2). A late catch's throw-back readies in 0.42 s (from 0.35). | practised Catch | hands: a brighter crack flash on your own hands at a clean catch (84 P_EarthShockwaveMuzzleFire, 839 SmkObscureS_FxP1, 83 Gauntlet_Stoneshaper_Idle01_FxP) |
| **Open Hands** `stone_catch/catch` | Enhance, 1 pt | The Catch reaches 4.2 m (from 3.5). Each return of the same stone adds 0.08 (from 0.1; clean 0.16 from 0.2), so a rally reaches x1.6 later. | practised Catch | hands: a wider dust ring round the catcher only (nothing drawn on the thrower) (841 ShrineB_Earth_FxP, 86 Stoneskin02_FxP) |
| **Juggle** `stone_catch/catch` | Twist, 2 pt | Your Catch can hold two stones from one window. E throws the first, E again the second. A stone that reaches your Catch after 0.8 s (from 1.0) is a late catch. *Answer:* Unchanged for him: his stones are still always caught and held. | expert Catch, the earth teacher | hands: two stones orbiting the hands (83 Gauntlet_Stoneshaper_Idle01_FxP, 80 FX_RocksTravelCharge*) |
| **Return to Sender** `stone_catch/catch` | Technique, 2 pt | Throw a cleanly caught stone back on the Beat (E within 0.2 s of the clean catch) and it flies 15% faster. A late catch's throw-back readies in 0.4 s (from 0.35). | expert Catch, a trial | projectile: a sharper dust streak on the return; the Beat flash on your own hands (539 CB_StonShaper_Unified, 84 P_EarthShockwaveMuzzleFire, 825 ChronoHands_FxP) |
| **Kick-Up** `rock_jab/pebbles` | Enhance, 1 pt | A Pebbles volley that hits nobody leaves one loose stone where its last pebble lands (still three loose stones at most). A Fissure that runs under a loose stone throws it on along the crack, whoever's it is. The spread is 3.6 deg (from 3). | practised Pebbles | impact: a pebble landing and swelling into a fist-sized stone (157 LandingDust_FX, 53 P_Default_Primary_ImpactA) |

#### Quake (1, 2)

The stone you throw and the stone you raise: Spike, Boulder, Fissure, Column. (Earth's 2 was the Shove until 2026-10-10; the owner made it the Fissure, a crack along the deck like fire's Kick, and a loose stone the crack runs under is thrown on: the Shove's ammo kept.)

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Steady Point** `stone_form/spike` | Enhance, 1 pt | A raised Spike hangs longer: it sputters from 0.84 s held (from 0.7) and drops at 1.2 s (from 1.0), so you can wait out a guard. Its lock is 1.2 s (from 1.1). | practised Spike/Boulder | hands: the hanging spike trembles and sheds dust from 0.7 s: a tell on your own stone, nothing on him (83 Gauntlet_Stoneshaper_Idle01_FxP, 841 ShrineB_Earth_FxP) |
| **Swift Lance** `stone_form/spike` | Enhance, 1 pt | The Spike flies at 40 m/s (from 34): less time to see it coming. It adds 12% (from 14). | practised Spike/Boulder | projectile: a thinner streak with a stone-dust contrail (539 CB_StonShaper_Unified, 187 CBTrail01_FX) |
| **Heavy Boulder** `stone_form/cannonball` | Enhance, 1 pt | A bigger Boulder: 0.31 m (from 0.26) and 17% (from 16). It flies at 20 m/s (from 22) and its lock is 1.25 s (from 1.1). *Not with:* Sulphur Boulder. | practised Spike/Boulder | projectile: boulder flight and a heavier landing (76 BoulderMedium_FX, 78 EarthImpactAOE_FX_Meteor*, 190 DropImpact_FX) |
| **Avalanche** `stone_form/cannonball` | Twist, 2 pt | Where the Boulder lands it breaks into three stones that roll on, fanned 15 deg. They are one volley: together they add the Boulder's 16%, and only the first to hit knocks, at 80% of its base. *Answer:* Same answer: along the floor, jump it; walls stop it; a Catch holds stone (the rest drop at the catcher's feet). | expert Spike/Boulder, the earth teacher | impact: a boulder cracking into three with a dust burst (76 BoulderMedium_FX, 77 BoulderSmall_FX*, 157 LandingDust_FX) |
| **Forked Fissure** `earth_shove/push` | Twist, 2 pt · **held** (question 4) | Held for the owner (question 4): one Fissure forks into three cracks (a volley in place of the Fissure). The crack splits as it leaves you, 15 deg apart, each 1.6 m wide (from 2.4; grown 2.4 from 3.6): one volley that adds the Fissure's 12% (16% grown), only the first crack to reach him knocks, at 80% of the Fissure's base. *Answer:* Same answer: jump the cracks, guard, or wall them. | your answer first, expert Fissure/Column, the earth teacher | floor: one crack splitting into three as it leaves the hands (85 P_Shockwave_Earth_Fast_ToonUnlit) |
| **Deep Fissure** `earth_shove/push` | Twist, 2 pt | Your Fissure runs 12.5 m/s (from 15) but throws him at 45 deg (from 30), grown too: slower to reach him and easier to jump, but he goes up more than out. It rings out later and sets up your air game. *Answer:* Same crack, same answers: jump it, guard it or wall it. | expert Fissure/Column, the earth teacher | floor: a slower crack heaving bigger slabs (85 P_Shockwave_Earth_Fast_ToonUnlit) |
| **Fault Line** `earth_shove/push` | Enhance, 1 pt · open world only | The Fissure runs 19.2 m (from 16; grown 25.2 from 21) but is 2 m wide (from 2.4; grown 3 from 3.6). Still a crack you can see and jump. | practised Fissure/Column | floor: a long narrow crack (85 P_Shockwave_Earth_Fast_ToonUnlit) |
| **Broad Column** `earth_shove/column` | Enhance, 1 pt · open world only | The Column is 1.55 m wide (from 1.3) but launches with base 9.3 (from 10.3). The rise is unchanged: low and weak, peaking 0.35 s later. *Not with:* Heave. | practised Shove/Column | rise: a wider ground burst (85 P_Shockwave_Earth_Fast_ToonUnlit, 694 Triump_Earth01_Ground_FxP) |
| **Heave** `earth_shove/column` | Technique, 2 pt | A Column let go on the Beat throws harder: its launch base is 11.3 (from 10.3). The rise and its tell are unchanged. Column's lock is 1.7 s (from 1.6). *Answer:* Same rise and tell: low and weak, peaking 0.35 s later; step off as it starts. *Not with:* Broad Column, Fuming Column. | expert Shove/Column, a trial | rise: the pillar heaves up harder; the Beat flash on your own hands (694 Triump_Earth01_Ground_FxP, 85 P_Shockwave_Earth_Fast_ToonUnlit, 825 ChronoHands_FxP) |
| **Kiln Stone** `stone_form` | Synergy, 1 pt | A stone of yours that passes through fire (any Fire Wall, burning ground or magma seam, his or an ally's) comes out heated: its launch base is 15% higher and it trails fire. But a heated stone burns: a Parry on the beat sends it back and a Turn douses it to a plain stone. | seen once | projectile: a burning stone (81 Flame_Boulder_FX, 97 FireBoulderImpact_FX) |

#### Bulwark (3, 4, 5, passive)

Holding ground without slowing anyone: Burrow, Lift, the Wall, Mend and Rooted.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Lie Low** `earth_skate/burrow` | Enhance, 1 pt | Stones pass over you for 0.36 s (from 0.3), but Burrow travels at 12.6 m/s (from 14). | practised Burrow | body: a longer travelling mound (85 P_Shockwave_Earth_Fast_ToonUnlit, 157 LandingDust_FX) |
| **Surfacing Stomp** `earth_skate/burrow` | Twist, 2 pt · **held** (question 4) | Held for the owner (question 4): a dash that hits (key 3 is travel). You come up hitting: a 2.5 m stomp ring where you surface (adds 4%, set knock 6 up). If it hits nobody, you land with 0.15 s more lag. *Answer:* The travelling mound shows where you will rise: step away or jump. | your answer first, expert Burrow, the earth teacher | rise: rock bursting out of the deck (694 Triump_Earth01_Ground_FxP, 84 P_EarthShockwaveMuzzleFire, 157 LandingDust_FX) |
| **Ramp** `pillar/self` | Twist, 2 pt · **held** (question 3) | Held for the owner (question 3): you cut the ramp on 2026-10-05 (round 2). Lift raises a tilted slab under you and throws you along it: 20% farther forward and 20% lower. The slab stands 1.5 s and anyone may run up it (it is not a wall). Draws on the pillar's ramp world mode. *Answer:* Your own travel move: nothing for him to answer; the slab is not a wall and sinks in 1.5 s. | your answer first, expert Lift, the earth teacher | rise: a sloped slab rising under the feet (694 Triump_Earth01_Ground_FxP, 145 Springstep_Start01_FxP, 144 Springstep_Finish02_FxP) |
| **Thick Wall** `earth_wall/wall` | Enhance, 1 pt | Your wall takes 5 hits (from 4) but is 2.5 m wide (from 3). *Not with:* Brimstone Wall. | practised Wall | rise: a denser face with deeper crack stages (828 DeepEarthConveyor_Barrier_FxP, 86 Stoneskin02_FxP) |
| **Rubble Wall** `earth_wall/wall` | Twist, 2 pt | When your wall crumbles (shot down, or broken by your third) it leaves 2 loose stones (still three at most). A Fissure that runs under them throws them on, whoever's they are, so in a mirror he can take them. It rises in 0.8 s (from 0.7). *Answer:* Same wall: what it stops and what breaks it are unchanged. | expert Wall, the earth teacher | rise: the wall crumbling into stones (827 DeepEarthConveyor_Barrier_Explode_FxP, 157 LandingDust_FX, 77 BoulderSmall_FX*) |
| **Quarry** `earth_wall/wall` | Technique, 2 pt | A Fissure let go on the Beat that runs into your own wall tears a chunk off it and throws the chunk on along the crack, without wearing the wall (the first chunk each wall). Your walls rise in 0.8 s (from 0.7). | expert Wall, a trial | impact: a chunk ripping free of the wall and flying on along the crack (828 DeepEarthConveyor_Barrier_FxP, 80 FX_RocksTravelCharge*, 53 P_Default_Primary_ImpactA) |
| **Shell** `earth_wall/shell` | New skill, 3 pt · **held** (question 3) | Held for the owner (question 3): you cut the shell on 2026-10-05 (round 2). Four short slabs close round you for 0.8 s: every shot stops on them. Lock 1.0 s. You can't start a lock while it stands, it pops after 2 hits of any kind, and a Boulder breaks it at once; one at a time; it never counts toward your two walls. Trade: your Earth Wall rises in 0.8 s (from 0.7). Brings back the dormant earth_wall shell (3 s in the open world). *Answer:* A read, not a reaction: its 1.0 s lock shows it coming. Two hits pop it, a Boulder breaks it, or wait 0.8 s. | your answer first, expert Wall, the earth teacher | rise: stone plates closing into a dome; a crumble burst when it opens (86 Stoneskin02_FxP, 828 DeepEarthConveyor_Barrier_FxP, 827 DeepEarthConveyor_Barrier_Explode_FxP) |
| **Reinforce** `mend` | Enhance, 1 pt | A mended piece takes its next two hits free (from one). Mend's lock is 2.6 s (from 2.2). | practised Mend | rise: stone seams knitting on the mended wall (86 Stoneskin02_FxP, 738 LobbyShrine_Stoneshaper01_In_FxP*) |
| **Deep Roots** `stone_form` | Passive, 2 pt | Rooted: standing still, knock you take is x0.8 (from x0.85), but your locks fill x1.1 (from x1.2). *Not with:* Swift Roots. | expert in any 3 Earth moves, the earth teacher | hands: dust settling round the stance (841 ShrineB_Earth_FxP, 694 Triump_Earth01_Ground_FxP) |
| **Swift Roots** `stone_form` | Passive, 2 pt | Rooted: standing still, your locks fill x1.3 (from x1.2), but knock you take is x0.92 (from x0.85). *Not with:* Deep Roots. | expert in any 3 Earth moves, the earth teacher | hands: pebbles rattling at the feet while a lock fills (83 Gauntlet_Stoneshaper_Idle01_FxP, 841 ShrineB_Earth_FxP) |

#### Sulphur (skill set: earth's poison) (LMB, 1, 2, 4)

The owner's 'earth can have poison original': toxic stone and gas that hold ground and add % over time, never a slow. Poison stays a skill set, not a fifth element.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Sulphur** `stone_form` | Skill set, 2 pt | Earth's poison, as a skill set. Your Boulder vents a 2.5 m cloud where its roll ends, and where your stones clash with his a cloud rises. A foe in your cloud gains 1% each 0.5 s (at most 6% from one cloud); your own gas never hurts you. Fire lights it, lightning charges it, wind carries it, water washes it. It never slows anyone or touches aim, lock or guard. Opens the Sulphur nodes. Trade: your Pebbles are crumbly sulphur and add 4% (from 5). | the sulphur quest, the sulphur teacher | floor: yellow-green haze on your hands in stance, sulphur veins on your stones, clouds on the deck (159 FX_PoisonCloud*, 17 P_Poison_Primary_Dissipate, 164 FX_Poison_Bubbles, 845 ShrineB_Toxic_FxP) |
| **Sulphur Spike** `stone_form/spike` | Twist, 2 pt | Where your Spike stops (a body, the deck, a wall) it bursts into a 1.5 m puff for 2.5 s (at most 3% to a foe who stays). It adds 12% (from 14). *Answer:* Same flight, same answers; the puff is a cloud on the deck: step out, wash it, blow it or light it. *Needs:* Sulphur. | Sulphur, expert Spike/Boulder | impact: a sulphur-yellow spike splitting into a puff (170 PoisonSpray_Base_Impact01_FxP, 17 P_Poison_Primary_Dissipate, 161 FX_PoisonCloud_RevA*) |
| **Sulphur Boulder** `stone_form/cannonball` | Twist, 2 pt | The Boulder's roll leaves 3 puffs behind it (1.5 m, 2.5 s, at most 3% each). It adds 13% (from 16). *Answer:* Same answer: along the floor, jump it; walls stop it. The puffs are clouds: step out of them. *Not with:* Heavy Boulder. *Needs:* Sulphur. | Sulphur, expert Spike/Boulder | floor: a boulder rolling a toxic trail (76 BoulderMedium_FX, 165 FX_projectile_Poison_cloud, 17 P_Poison_Primary_Dissipate) |
| **Fuming Column** `earth_shove/column` | Twist, 2 pt | Your Column leaves a 2 m gas plume for 3 s where it rose. It launches with base 9.3 (from 10.3); the rise is unchanged. *Answer:* Same tell: low and weak, peaking 0.35 s later; step off, then step out of the plume. *Not with:* Heave. *Needs:* Sulphur. | Sulphur, expert Shove/Column | floor: a bubbling crack and a rising plume (164 FX_Poison_Bubbles, 159 FX_PoisonCloud*, 85 P_Shockwave_Earth_Fast_ToonUnlit) |
| **Brimstone Wall** `earth_wall/wall` | Twist, 2 pt | A wall of yours that is shot down vents a 2.5 m cloud for 3 s on the side it was hit from. It takes 3 hits (from 4). *Answer:* Same wall; its gas is a cloud like any other: step out, wash it, blow it or light it. *Not with:* Thick Wall. *Needs:* Sulphur. | Sulphur, expert Wall | rise: a wall crumbling into a yellow cloud (827 DeepEarthConveyor_Barrier_Explode_FxP, 159 FX_PoisonCloud*, 106 FireWall_Toxic_Sm_FX) |
| **Sulphur Vent** `earth_wall/vent` | New skill, 3 pt | The deck cracks where you aim (2-6 m, placed like a wall) and breathes a 3 m cloud for 4 s. Lock 0.9 s; one at a time. Trade: your Earth Wall rises in 0.8 s (from 0.7). *Answer:* A cloud you can see on the deck: step out, wash it, blow it or light it. *Needs:* Sulphur. | Sulphur, the sulphur teacher | floor: a crack, then a bubbling vent and a rolling cloud (85 P_Shockwave_Earth_Fast_ToonUnlit, 164 FX_Poison_Bubbles, 159 FX_PoisonCloud*, 168 P_PoisonCloud_Dissipate) |
| **Flint Pebbles** `rock_jab/pebbles` | Synergy, 1 pt | Your Pebbles spark your own gas: a pebble that enters one of your clouds lights it (the Ignited Sulphur burst, yours). Earth's own detonator; his gas it leaves alone. Trade: your clouds last 2.5 s (from 3). *Needs:* Sulphur. | Sulphur, practised Pebbles | reaction: a spark flick into a fire splash on the gas (16 P_Ignited_Poison_Splash, 71 DragonFire_CloudIgniteFX_ScaleFX_RevA*) |
| **Sulphur Heart** `stone_form` | Passive, 2 pt (home ground) | Home ground: standing in your own gas, your locks fill x1.15 (with Rooted the higher one counts; they never multiply). Your clouds are 2 m (from 2.5). *Needs:* Sulphur. | Sulphur, expert in any 2 Sulphur moves, a trial | hands: gas parting round your body, a faint haze on your hands (163 FX_PoisonCloud_WindExplosion, 83 Gauntlet_Stoneshaper_Idle01_FxP) |

#### World arts (open world only) (1, 3, 4)

The open world's Form modes as they are today; listed so the tree shows them. Never in the ring.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Stone Disc** `stone_form/disc` | World only, not in the ring | The open world's spinning stone disc (Stone Form's disc world mode today): a cutter for work and hunting. Never in the ring. | as today | projectile: a spinning disc with a dust streak (539 CB_StonShaper_Unified, 187 CBTrail01_FX) |
| **Raised Column and Shell** `earth_wall/column` | World only, not in the ring | The Earth Wall's column and shell world modes as they are today (a column 20 m out; a shell of four walls for 3 s). Never in the ring (the ring's Shell, held for the owner, would be its own short skill). | as today | rise: a column or a ring of slabs rising (85 P_Shockwave_Earth_Fast_ToonUnlit, 828 DeepEarthConveyor_Barrier_FxP) |
| **Free Pillar and Ramp** `pillar/free` | World only, not in the ring | The pillar's free and ramp world modes as they are today (a pillar anywhere within 10 m; a ramp within 6 m). Never in the ring. | as today | rise: a pillar or a ramp rising (85 P_Shockwave_Earth_Fast_ToonUnlit, 694 Triump_Earth01_Ground_FxP) |

Starter loadouts (10 points each):

- **Rally**: Catch everything, send it back on the Beat, own the earth mirror. (Juggle 2, Return to Sender 2, Kick-Up 1, Thick Wall 1, Steady Point 1, Swift Lance 1, Lie Low 1, Reinforce 1)
- **Quake**: Big stones along the floor, a wall that turns to ammo, a Column that throws harder on the Beat. (Heavy Boulder 1, Avalanche 2, Heave 2, Thick Wall 1, Rubble Wall 2, Lie Low 1, Steady Point 1)
- **Sulphur Pit**: Gas where he must stand; your own Pebbles light it when he is in it. (Sulphur 2, Sulphur Vent 3, Sulphur Boulder 2, Flint Pebbles 1, Thick Wall 1, Steady Point 1)

### 7.2 Water: flowing, redirecting, pools

Skill set Mud; the free tap twice is 4 (Mire, which needs Mud; Bubble is held); passive Flowing. Water shapes ice (Spear, Ice Wall); air's Frostwind only freezes what is already there, so the two never overlap. Left plain on purpose: Surf (Breaker is held), the Geyser outside Mud (Twin Geyser is held) and Mend.

#### Lash and Turn (LMB, 1, E, passive)

Steering and turning: Splash, Lash, the Turn and Flowing.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Jet** `water_jet/splash` | Twist, 2 pt · **held** (question 3) | Held for the owner (question 3): you cut the jet on 2026-10-05 (round 2), and six bolts replace the one Splash. Splash becomes a stream of 6 small bolts (still 10 m: the jab's reach) that wear earth walls x3. One volley: it adds Splash's 4% and only the first knocks, at base 2.8 (from 3.5). Brings back the dormant water_jet jet. *Answer:* Same answer: through the air; Turn takes water; walls stop it (earth walls wear faster). | your answer first, expert Splash, the water teacher | projectile: a thin pressurised stream with droplets (516 CB_RiversReflection_FxP, 133 Ice_Lance_IceProjectile_Trail, 137 Ice_Lance_Squib) |
| **Washout** `water_jet/splash` | Synergy, 1 pt | Your Splash and Lash wash out any gas they pass through (the Wave and Geyser already do, for everyone). Trade: your Splash adds 3.5% (from 4). | seen once | reaction: a cloud dispersing in a ring of spray (168 P_PoisonCloud_Dissipate, 21 P_Water_Dissipate*) |
| **Long Reach** `water_whip/whip` | Enhance, 1 pt · open world only | The Lash reaches 19 m (from 16), but Flowing bends it 12 deg at most (from 15). *Not with:* Lazy River. | practised Lash | projectile: a longer ribbon tail (516 CB_RiversReflection_FxP, 133 Ice_Lance_IceProjectile_Trail) |
| **Reel** `water_whip/whip` | Twist, 2 pt · **held** (question 4) | Held for the owner (question 4): the Lash, a KO strike (KO end 210%), becomes a set pull that never KOs, copying air's Pull. On a hit the Lash pulls him 2-3 m toward you instead of pushing (a set pull, as air's Pull does). It adds 7% (from 9) and never KOs. Draws on the dormant water_whip grab. *Answer:* Same answer: through the air; Turn takes water; walls stop it. | your answer first, expert Lash, the water teacher | projectile: a ribbon from your own hands that snaps back toward you (nothing drawn on him) (516 CB_RiversReflection_FxP, 527 CloudBurst_Spiral01_Cerulean_Trail_FxP, 21 P_Water_Dissipate*) |
| **Splashdown** `water_whip/whip` | Twist, 2 pt | Where your Lash stops (a body, a wall or the deck) it leaves a 1.2 m puddle for 6 s: your water, a source for Geyser and Skate. It adds 8% (from 9). *Answer:* Same answer: through the air; Turn takes water; walls stop it. The puddle is your water, not a hit. *Not with:* Mud Lash. | expert Lash, the water teacher | impact: a lash splashing down into a puddle (516 CB_RiversReflection_FxP, 190 DropImpact_FX, 755 RainDrops_SmallAreaFlat) |
| **Steamcraft** `water_whip/whip` | Synergy, 1 pt | When your water meets fire, the steam lasts 2.5 s (from 1.5) and drifts 3 m toward where you aim. Trade: your Lash adds 8% (from 9). *Not with:* Mud Lash. | seen once | cloud: a drifting cloud of steam (20 P_Steam_Cloud_Dissipate, 192 VaporCloud_FX) |
| **Patient Turn** `water_redirect/redirect` | Enhance, 1 pt | Your Turn's beat is 0.36 s (from 0.3): more of your Turns are perfect. A late Turn lets 60% through (from 50%). *Not with:* Whirl Turn, Eddy. | practised Turn | hands: the Turn's ring glows a beat longer on your own hands (516 CB_RiversReflection_FxP, 13 P_Ice_Flashes) |
| **Cleanse** `water_redirect/redirect` | Enhance, 1 pt | Your Turn, perfect or late, clears gas within 2.2 m of you. Turn's lock is 0.24 s (from 0.2). Draws on the dormant water_redirect cleanse. | practised Turn | reaction: a water ring sweeping a cloud away (168 P_PoisonCloud_Dissipate, 21 P_Water_Dissipate*) |
| **Whirl Turn** `water_redirect/redirect` | Twist, 2 pt | Hold E through a perfect Turn and the water or ice keeps circling you, up to 0.6 s (the swing is 0.3 s); let go to send it along your aim (x1.2 as before). A late Turn lets 60% through (from 50%). *Answer:* His shot still comes back along your aim; only the moment it leaves is yours to choose. *Not with:* Patient Turn. | expert Turn, the water teacher | hands: a spiral of water circling the body (198 TornadoNewSimple, 527 CloudBurst_Spiral01_Cerulean_Trail_FxP, 516 CB_RiversReflection_FxP) |
| **Eddy** `water_redirect/redirect` | Technique, 2 pt | After a perfect Turn, your next Lash or Spear begun within 1.2 s starts its lock 40% full. Your Turn's beat is 0.25 s (from 0.3). *Not with:* Patient Turn. | expert Turn, a trial | hands: charged hands after a perfect Turn (129 Ice_Lance_ChargedLoop01_FxP, 825 ChronoHands_FxP) |
| **Lazy River** `water_whip` | Passive, 2 pt | Flowing: your water bends up to 18 deg (from 15) for 0.3 s (from 0.25), but turns at 36 deg/s (from 45). *Not with:* Rapids, Long Reach. | expert in any 3 Water moves, the water teacher | projectile: a longer curling trail (133 Ice_Lance_IceProjectile_Trail, 527 CloudBurst_Spiral01_Cerulean_Trail_FxP) |
| **Rapids** `water_whip` | Passive, 2 pt | Flowing: your water turns at 54 deg/s (from 45), but bends 12 deg at most (from 15). *Not with:* Lazy River. | expert in any 3 Water moves, the water teacher | projectile: a tight, snapping trail (516 CB_RiversReflection_FxP, 133 Ice_Lance_IceProjectile_Trail) |

#### Surge (2, 3)

Water from its sources: Wave, Geyser, the Downpour, Skate and Surf, and the puddles that feed them.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Broad Wave** `wave/push` | Enhance, 1 pt · open world only | The Wave is 60 deg wide (from 50) but reaches 7.5 m (from 9); grown, 75 deg (from 65) and 10 m (from 12). It still can't be jumped. | practised Wave/Geyser | projectile: a wide sheet of water (shape donor recoloured blue) (173 PoisonSpray_Toxic_Projectile01_FxP, 21 P_Water_Dissipate*); to author: a liquid cone: Spellbreak has none; 173's liquid sheet is only a shape donor |
| **Pooling Wave** `wave/push` | Twist, 2 pt | Where the Wave's cone ends it leaves a 1.2 m puddle for 6 s: a source for Geyser and Skate. It launches with base 6.8 (from 7.5; grown 7.6 from 8.4). *Answer:* Same answer: it can't be jumped; dash, guard or wall it; Turn parts it. *Not with:* Mudslide. | expert Wave/Geyser, the water teacher | floor: a splash and a puddle where the crest falls (190 DropImpact_FX, 755 RainDrops_SmallAreaFlat) |
| **Ride the Wave** `wave/push` | Technique, 2 pt | A Wave let go on the Beat carries you 3 m forward with it: you lunge in behind the water (the Wave is still today's cone). Wave's lock is 0.65 s (from 0.6). Deck only: key 2 in the air is the Downpour. *Answer:* Same cone and answers; the caster comes 3 m closer. | expert Wave/Geyser, a trial | body: foam under the feet as you lunge in behind the Wave (140 Ice_Skate_Footstep01_FxP, 21 P_Water_Dissipate*) |
| **Twin Geyser** `wave/spout` | Twist, 2 pt · **held** (question 4) | Held for the owner (question 4): one cast raises two Geysers (a volley of rises). A Geyser cast from your own puddle raises a second one 0.4 s later from your nearest other puddle within 6 m. Each launches with base 9.3 (from 10.9). Each keeps the tell: low first, peaking 0.35 s later. *Answer:* Same answer for each: step off as it starts. | your answer first, expert Wave/Geyser, the water teacher | rise: two columns of water (192 VaporCloud_FX, 158 ManaJump_FX) |
| **Pooling Downpour** `wave/slam` | Enhance, 1 pt | The Downpour's puddle is 1.9 m (from 1.6) and lasts 7.2 s (from 6). It adds 7% (from 8). | practised Wave/Geyser | floor: a bigger wet decal and rain (755 RainDrops_SmallAreaFlat, 190 DropImpact_FX) |
| **Wet Trail** `flow/skate` | Enhance, 1 pt | Skate leaves 4 puddles (from 3) that last 7.2 s (from 6), but it travels at 10.8 m/s (from 12). | practised Skate/Surf | floor: puddle decals along the path (140 Ice_Skate_Footstep01_FxP, 190 DropImpact_FX) |
| **Breaker** `flow/surf` | Twist, 2 pt · **held** (question 4) | Held for the owner (question 4): a dash that hits (key 3 is travel). Surf ends in a small wave where you stop (a 4 m, 40 deg cone that adds 6%, set knock 6). Surf's own push is base 5.5 (from 6.9). *Answer:* The crest is a Wave: it can't be jumped; dash, guard or wall it. | your answer first, expert Skate/Surf, the water teacher | impact: a crest collapsing where you stop (21 P_Water_Dissipate*, 173 PoisonSpray_Toxic_Projectile01_FxP) |

#### Ice (1, 4, 5)

Shaped ice and cover: the Spear, the Ice Wall, Patch. Water shapes ice; air only freezes what is there.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Cold Hands** `ice/spear` | Enhance, 1 pt | The Spear's lock is 0.52 s (from 0.6). It adds 13% (from 14). *Not with:* Heavy Spear. | practised Spear | hands: frost forming at the fingertips (129 Ice_Lance_ChargedLoop01_FxP, 128 Ice_Lance_ChargeUp01_FxP*) |
| **Heavy Spear** `ice/spear` | Enhance, 1 pt | A thicker Spear: it adds 16% (from 14) but flies 35 m/s (from 42). *Not with:* Cold Hands. | practised Spear | projectile: a thick lance of ice (132 Ice_Lance_IceProjectile*, 133 Ice_Lance_IceProjectile_Trail, 14 P_Ice_Primary_Impact) |
| **Thick Ice** `water_shield/ice_wall` | Enhance, 1 pt | Your Ice Wall takes 4 hits (from 3) but rises in 0.8 s (from 0.7). *Not with:* Shatter. | practised Ice Wall | rise: denser crystal with frost at the foot (125 BoulderFrozen_Mist_FxP, 9 P_Earth_Primary_AOE_Frozen) |
| **Shatter** `water_shield/ice_wall` | Technique, 2 pt · **held** (question 3) | Held for the owner (question 3): you cut the ice shards on 2026-10-05 (round 2), and the wall becomes a volley. Lash your own Ice Wall on the Beat and it bursts into 4 ice shards along your aim (one volley: adds 8%, set knock 4); the wall is gone. Your Ice Wall takes 2 hits (from 3). *Answer:* The shards are ice: Turn takes them, a perfect Parry melts them, walls stop them. *Not with:* Thick Ice. | your answer first, expert Ice Wall, a trial | impact: the wall bursting into flying shards (12 P_Frozen_Explosion, 15 P_Ice_Primary_Projectile*, 13 P_Ice_Flashes) |
| **Bubble** `water_shield/bubble` | New skill, 3 pt · **held** (question 3) | Held for the owner (question 3): you cut the bubble on 2026-10-05 (round 2). A 1.6 m sphere of water round you for 0.8 s (2.5 s in the open world): fire is doused to steam, water and air are swallowed; stone and lightning pass. Lock 0.8 s. You can't start a lock while it stands, and it pops after 2 hits; one at a time. Trade: your Ice Wall rises in 0.8 s (from 0.7). Brings back the dormant water_shield bubble. *Answer:* Stone and lightning pass it; two hits pop it; or wait 0.8 s. | your answer first, expert Ice Wall, the water teacher | rise: a wobbling sphere of water; steam where fire meets it (192 VaporCloud_FX, 516 CB_RiversReflection_FxP, 21 P_Water_Dissipate*); to author: a water sphere: Spellbreak has none (ToonFx's water head scaled up) |
| **Wellspring** `patch/patch` | Enhance, 1 pt | Standing in your own puddle or at a grate, Patch's lock is 1.25 s (from 1.5). Anywhere else it is 1.6 s. | practised Patch | hands: water drawn up into the hands (516 CB_RiversReflection_FxP, 184 Health_Regen01_Burst_FxP) |

#### Mud (skill set: water and earth) (1, 2, 3, 4)

The owner's 'water + mud goes together': heavy water that stops floor fire and rolling stones and holds ground, never a slow.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Mud** `flow` | Skill set, 2 pt | Water and earth, as a skill set. Your puddles are mud pools (from Skate, the Downpour, Pooling Wave): they last 8 s (from 6) and are still your sources. In a mud pool a floor wave of fire dies, a fire wall over it burns 2 s, a rolling stone stops, magma is quenched with no stone, and lightning is grounded. Mud never slows, slides or roots anyone. Opens the Mud nodes. Trade: heavy water, your Splash and Lash fly 10% slower. | the mud quest, the mud teacher | floor: brown water with clods; mud pools with slow bubbles (164 FX_Poison_Bubbles, 227 AG_CauldronBubbles_FxP, 523 CB_SlimySeepage02_FxP, 281 AG_StreamOfOoze01_FxP); to author: mud: Spellbreak has none (bubbles recoloured brown on a stripped 719 puddle base) |
| **Mud Lash** `water_whip/whip` | Twist, 2 pt | A heavy lash of mud: it adds 10% (from 9) and knocks with base 5.3 (from 4.6), but flies 28 m/s (34 today; the set's heavier water included). Fire it meets is smothered (no steam). *Answer:* Same answer: through the air; Turn swings it (it is water); walls stop it. *Not with:* Steamcraft, Splashdown. *Needs:* Mud. | Mud, expert Lash | projectile: a brown ribbon flinging clods (281 AG_StreamOfOoze01_FxP, 170 PoisonSpray_Base_Impact01_FxP) |
| **Mudslide** `wave/push` | Twist, 2 pt | The Wave drags silt: it knocks 15% harder (base 8.6 from 7.5; grown 9.7 from 8.4) but reaches 7.5 m (from 9; grown 10 from 12), and leaves a 2 m mud pool where it ends. *Answer:* Same answer: it can't be jumped; dash, guard or wall it; Turn parts it. *Not with:* Pooling Wave. *Needs:* Mud. | Mud, expert Wave/Geyser | projectile: a brown crest carrying clods, then a mud splat (173 PoisonSpray_Toxic_Projectile01_FxP, 170 PoisonSpray_Base_Impact01_FxP) |
| **Mud Mound** `wave/spout` | Twist, 2 pt | The Geyser throws up a mud plug that settles as a low mound 1.5 m wide and 0.7 m high for 3 s: floor fire and rolling stones stop at it and anyone can jump onto it. It is low terrain like frost crust, never a wall (two mounds and ridges of yours at once). The launch is base 9.3 (from 10.9); the rise is unchanged. *Answer:* The Geyser's tell is unchanged (step off). The mound is low terrain: jump it. *Needs:* Mud. | Mud, expert Wave/Geyser | rise: a brown spout, then a settling mound (192 VaporCloud_FX, 157 LandingDust_FX, 190 DropImpact_FX) |
| **Mire** `water_shield/mire` | New skill, 3 pt | A 3 m mud pool where you aim (2-6 m, placed like a wall) for 8 s. Floor fire and rolling stones stop in it, and it is your water for Geyser and Skate (a source like a grate). Lock 0.9 s; one at a time. Trade: your Ice Wall rises in 0.8 s (from 0.7). *Answer:* It only stops what runs along the floor: shots through the air pass over it; fire dries it. *Needs:* Mud. | Mud, the mud teacher | floor: a brown pool with bubbles and slow ripples (164 FX_Poison_Bubbles, 227 AG_CauldronBubbles_FxP, 755 RainDrops_SmallAreaFlat); to author: the mud pool look (Spellbreak has no mud) |
| **Delta** `flow` | Passive, 2 pt (home ground) | Home ground: standing in your own mud, your locks fill x1.15. Your mud pools last 6.5 s (from 8). *Needs:* Mud. | Mud, expert in any 2 Mud moves, a trial | hands: ripples at your feet in your own mud (755 RainDrops_SmallAreaFlat, 516 CB_RiversReflection_FxP) |

#### World arts (open world only) (4, 5)

Travel and care in the open world, from dormant water specs. Never in the ring.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Freeze the River** `frost/freeze_water` | World only, not in the ring | Freeze still or running water into a walkable sheet, or thaw ice (the frost move's world modes). Never in the ring, and never an ice patch under people (its slow stays cut). | as today | floor: a sheet of ice spreading over water (131 Ice_Lance_IcePatch_FX_Z*, 140 Ice_Skate_Footstep01_FxP) |
| **Healing Water** `water_shield/heal` | World only, not in the ring | Heal with water you hold (the dormant water_shield heal, 35). The ring has Patch. | as today | hands: water drawn up into the hands, then a glow (516 CB_RiversReflection_FxP, 184 Health_Regen01_Burst_FxP) |

Starter loadouts (10 points each):

- **Riptide**: Turn his water back when you choose, bend what you throw, own the steam. (Whirl Turn 2, Eddy 2, Lazy River 2, Cold Hands 1, Washout 1, Steamcraft 1, Wellspring 1)
- **Pools**: Lay puddles everywhere, lunge in behind your Wave, heal standing in your own water. (Pooling Wave 2, Ride the Wave 2, Splashdown 2, Wet Trail 1, Pooling Downpour 1, Thick Ice 1, Wellspring 1)
- **Mudflat**: Mire the ground he kicks along; push with Mudslide; mound up against floor fire. (Mud 2, Mire 3, Mudslide 2, Mud Mound 2, Cleanse 1)

### 7.3 Fire: aggressive, fast, footwork, kicks and punches

Skill set Magma; Storm is a fourth kit branch for Lightning; the free tap twice is 5 (Cauterize), because 4 already holds Breath; passive Footwork. The Kick stays a floor wave and the flame wheel stays retired. Left plain on purpose: Jets outside Magma, and Breath keeps its smoke (Clean Burn is held).

#### Blaze (LMB, 1, E)

The shot: Embers, Punch and Fireball, and the Parry that sends fire back.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Tight Embers** `fire_jab/embers` | Enhance, 1 pt | Embers spread 7.2 deg (from 9) with 6 sparks (from 7): easier to land at range, harder up close. | practised Embers | projectile: a narrower spray of small bolts (702 Triumph_Fire01_Ball01_FxP, 703 Triumph_Fire01_Ball02_FxP, 98 FireIgniteSh_FX) |
| **Flashfire** `fire_jab/embers` | Synergy, 1 pt | Gas you light burns bigger: the Ignited Sulphur burst adds 8% (from 6), reaches 1 m farther and knocks 8 m/s (from 6). Whoever lights it owns it, whoever made the gas. Trade: your Embers add 6% (from 7). | seen once | reaction: a cloud igniting in a fire splash (16 P_Ignited_Poison_Splash, 71 DragonFire_CloudIgniteFX_ScaleFX_RevA*, 106 FireWall_Toxic_Sm_FX) |
| **Snap Punch** `fire_blast/punch` | Enhance, 1 pt | The Punch flies 38 m/s (from 32) but adds 13% (from 15). The Fireball is unchanged. | practised Punch | projectile: a tight, fast bolt from the fist (112 Fireball_Base_Projectile01_FxP, 107 Fire_Firefly_End01_FxP) |
| **Blazing Fireball** `fire_blast/punch` | Twist, 2 pt | The Fireball bursts 2 m wide where it hits (a 6% splash, set knock 5 outward). The burst stays on the side it hit, so a wall still covers you. Its core adds 16% (from 20). *Answer:* Same answer: Parry sends it back, Turn douses it, walls stop it (the burst stays on their side). *Not with:* Magma Fist. | expert Punch, the fire teacher | impact: a big fireball and a wide burst (115 Fireball_Pyro_Projectile01_Translucent_FxP, 114 Fireball_Pyro_Impact01_FxP) |
| **Reaching Parry** `fire_parry/parry` | Enhance, 1 pt | Your Parry reaches 3 m (from 2.5), but its beat is 0.25 s (from 0.3). | practised Parry | hands: a wider flame arc from the forearm (95 ExplosionGauntlet_VfxP_ConflagAmulet, 98 FireIgniteSh_FX) |
| **Hot Hands** `fire_parry/parry` | Technique, 2 pt | A perfect Parry starts your next Punch's lock half full (begun within 1 s). A late Parry lets 60% through (from 50%). *Answer:* Unchanged for him: his fire is still sent back on the beat, half gets through late. | expert Parry, a trial | hands: the fists flare after the parry (116 GauntletFireballMuzzle_FX*, 117 Gauntlet_Pyromancer_Idle01_FxP) |
| **Two-Hand Rhythm** `fire_blast/punch` | Technique, 2 pt | A Punch let go on the Beat starts your next Punch's lock 30% full (begun within 1 s): rhythm, not more damage. Punch adds 14% (from 15). | expert Punch, a trial | hands: alternating fist flares; the Beat flash on your own hands (702 Triumph_Fire01_Ball01_FxP, 703 Triumph_Fire01_Ball02_FxP, 825 ChronoHands_FxP) |

#### Kicks and Steps (2, 3, passive)

Fire along the floor and on the feet: Kick, High Kick, Step, Footwork. The Kick stays a floor wave; the flame wheel stays retired.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Long Kick** `fire_kick/kick` | Enhance, 1 pt · open world only | The floor wave runs 19 m (from 16; grown 26 from 22) but is 1.9 m wide (from 2.2; grown 3.0 from 3.5). Jump it; walls stop it. *Not with:* Lava Kick. | practised Kick | floor: longer flame rows along the floor (103 FireWall_FX_PyrolysisTranslucentSmoke, 104 FireWall_FX_TranslucentSmoke) |
| **Twin Wave** `fire_kick/kick` | Twist, 2 pt · **held** (question 4) | Held for the owner (question 4): one Kick sends two floor waves (a volley in place of the Kick). Two narrower floor waves (1.2 m each) 20 deg apart. One volley: they add the Kick's 14% (17% grown); only the first to hit knocks, at base 5.2 (from 5.8). *Answer:* Same answer: along the floor; jump it; walls stop it. *Not with:* Lava Kick. | your answer first, expert Kick, the fire teacher | floor: two flame waves fanning from the foot (103 FireWall_FX_PyrolysisTranslucentSmoke, 107 Fire_Firefly_End01_FxP) |
| **Crescent Burn** `fire_kick/high_kick` | Twist, 2 pt | The crescent lands as a 2 m patch of flame for 1.5 s (at most 3% to a foe who stays: step off or jump). The crescent adds 10% (from 12). *Answer:* Same answer: over walls and into jumpers. The patch is floor fire: step off or jump. | expert Kick, the fire teacher | floor: a crescent, then floor flames (104 FireWall_FX_TranslucentSmoke, 74 DragonFire_PuddleIgniteFX_ScaleFX, 99 FireIgnite_FX) |
| **Quick Step** `footwork/step` | Enhance, 1 pt | Step's lock is 0.16 s (from 0.2) but it carries you 10% less far. | practised Step | body: a short ember trail at the feet (65 DashTrail_FX, 513 CB_Pyromancer_TrailFillBFX) |
| **Ignite Step** `footwork/step` | Twist, 2 pt | Your Step leaves a 2 m line of fire for 1.5 s (at most 3% to a foe who stands in it: jump it). Stepping in goes 9 m/s (from 10). Brings back the dormant footwork ignite_step (a dash with burn). *Answer:* Floor fire: jump it or go round. | expert Step, the fire teacher | floor: burning footprints (99 FireIgnite_FX, 513 CB_Pyromancer_TrailFillBFX) |
| **Chain Kicks** `fire_kick/kick` | Technique, 2 pt | A Kick let go on the Beat starts your next Kick's lock 40% full (begun within 0.6 s): the double kick. Kick's lock is 0.65 s (from 0.6). | expert Kick, a trial | floor: a flame wave from the second foot (103 FireWall_FX_PyrolysisTranslucentSmoke, 99 FireIgnite_FX, 825 ChronoHands_FxP) |
| **Dancing Feet** `footwork` | Passive, 2 pt | Footwork: on the move your locks fill x0.9 (from x1.0), but for 0.6 s after a Step they fill x1.15. *Not with:* Hot Feet. | expert in any 3 Fire moves, the fire teacher | body: embers trailing the feet after a Step (513 CB_Pyromancer_TrailFillBFX, 263 PlunderingBlast_AG_FxP) |
| **Hot Feet** `footwork` | Passive, 2 pt | Footwork: on the move your locks fill x1.1 (from x1.0), but standing still x0.9 (from x1.0). *Not with:* Dancing Feet. | expert in any 3 Fire moves, the fire teacher | body: a moving aura on the hands and feet (263 PlunderingBlast_AG_FxP, 117 Gauntlet_Pyromancer_Idle01_FxP) |

#### Cover and Heal (4, 5)

Cover and recovery: Fire Wall, Breath, Patch and the free tap twice on 5.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Long Curtain** `fire_wall/wall` | Enhance, 1 pt · open world only | Your Fire Wall is 4.8 m wide (from 4) but stands 4.5 s (from 5). | practised Fire Wall | rise: the fire wall, widened (104 FireWall_FX_TranslucentSmoke, 103 FireWall_FX_PyrolysisTranslucentSmoke) |
| **Curved Curtain** `fire_wall/wall` | Twist, 2 pt | Your Fire Wall curves 120 deg round the point you aim at (5 m of curtain), but stands 4 s (from 5). *Answer:* Same answer: it burns who passes; water puts it out; air blows through; stone passes. | expert Fire Wall, the fire teacher | rise: a curved burning curtain (104 FireWall_FX_TranslucentSmoke, 98 FireIgniteSh_FX) |
| **Clean Burn** `fire_breath/breath` | Twist, 2 pt · **held** (question 3) | Held for the owner (question 3): it removes the smoke screen you named as part of Breath (answer 4, 2026-10-05). Breath leaves no smoke and is 54 deg wide (from 45), adding 13% (from 12). You lose the smoke's cover. *Answer:* Same answer: a short cone of fire; Parry and Turn as before; there is just no smoke. *Not with:* Scald. | your answer first, expert Breath, the fire teacher | projectile: a clean cone of flame with no smoke (109 Fire_Firefly_Launch01_FxP*, 196 TempestPyro_FX) |
| **Scald** `fire_breath/breath` | Synergy, 1 pt | Your fire through steam makes it scald for 1.5 s: a foe inside gains 1% each 0.5 s (at most 3%). Trade: your Breath adds 11% (from 12). *Not with:* Clean Burn. | seen once | cloud: steam licked by flame (20 P_Steam_Cloud_Dissipate, 98 FireIgniteSh_FX) |
| **Cauterize** `patch/cauterize` | New skill, 3 pt | Burn the wound shut: it costs 2% first (no Patch or Cauterize ever takes that back), then takes back up to 12% of fresh damage (Patch: 10%) from the same pool as Patch (the last 6 s), and clears the gas round you. Lock 1.2 s. Trade: your Patch's lock is 1.7 s (from 1.5). *Answer:* A heal, not a hit. | expert Patch, the fire teacher | hands: flame running along the body, then a glow (99 FireIgnite_FX, 184 Health_Regen01_Burst_FxP, 570 Emote_SummonFIre01_F_Rhand_FxP*) |

#### Storm (lightning) (1, E)

The owner's 'lightning': fire key 1's tap twice grows a family. A perfect Parry stays the only guard answer. The Lightning nodes are keyed to fire_arc, so they move with Lightning if the Thủy Vân dress gives Thunder to the Wind art; Hold the Storm stays with fire's Parry.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Short Fuse** `fire_arc/lightning` | Enhance, 1 pt | Lightning charges in 1.9 s (from 2.2) but adds 22% (from 25). The 0.25 s flash on your hand is unchanged: it is the tell. *Not with:* Long Lightning. | practised Lightning | hands: the charge crackling on your hands (567 Emote_StaffSlam_Lightning_Orb_FxP, 706 Triumph_Lightning01_LHand_FxP, 146 GauntletLightningMuzzle_FX) |
| **Long Lightning** `fire_arc/lightning` | Enhance, 1 pt · open world only | Lightning reaches 54 m (from 45) but charges in 2.4 s (from 2.2). *Not with:* Short Fuse. | practised Lightning | projectile: a longer bolt along the aim (148 LBolt_ProjectileBeam_WildRev2FX, 152 Shock2StrikeNew_FX) |
| **Forked Lightning** `fire_arc/lightning` | Twist, 2 pt | As it strikes, a fork jumps to the nearest water within 6 m of its path (a puddle, steam, a water shot in flight) and makes it live for 0.5 s: anyone in it takes half the strike's % with no launch, no stun and no lock set-back (Live Water: this node's own rule; mud grounds it). The main strike adds 22% (from 25). *Answer:* Same answer: only a perfect Parry sends it back; step out of water when you see the flash. | expert Lightning, the storm teacher | projectile: a branching bolt; a crackling puddle (148 LBolt_ProjectileBeam_WildRev2FX, 152 Shock2StrikeNew_FX, 719 FX_ElectrifiedPuddle, 191 FX_VaporCloud_Electrified) |
| **Hold the Storm** `fire_parry/parry` | Twist, 2 pt | After a perfect Parry of Lightning, hold E up to 0.8 s: the bolt waits in your arms and leaves along your aim when you let go (x1.2 as before). A perfect Parry of fire now goes back at x1.1 (from x1.2). Brings back the dormant fire_parry redirect_lightning. *Answer:* His Lightning still comes back along your aim; only the moment it leaves is yours. | expert Parry, the storm teacher | hands: lightning held, coursing through the arms (706 Triumph_Lightning01_LHand_FxP, 707 Triumph_Lightning01_RHand_FxP, 150 Lightning_Shocked01_FxP) |
| **Grounded Charge** `fire_arc/lightning` | Technique, 2 pt | A hit still breaks your Lightning charge, but you keep half of it: lock again within 1 s and it starts half full. Lightning adds 23% (from 25). | expert Lightning, a trial | hands: crackle sinking into the feet (705 Triumph_Lightning01_Ground_FxP, 720 FX_ElectrifiedPuddle_LoopedCenter) |

#### Magma (skill set: fire and earth) (1, 2, 3)

The owner's 'fire ... magma': molten stone that burns on the floor and cools into earth's ammo, never a slow.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Magma** `fire_kick` | Skill set, 2 pt | Fire and earth, as a skill set. Where your Kick's wave or the Axe Kick's wave dies (its range's end, or a wall) it leaves a molten seam 1.5 m wide for 3 s (two of yours at once). A foe in a seam gains 1% each 0.5 s, at most 4% from one seam: jump it or step off; it never slows. Water on a seam cools it into a loose obsidian stone that any earth player within 6 m may Shove; mud quenches it with no stone. Opens the Magma nodes. Trade: your floor waves run 16 m/s (from 18). | the magma quest, the magma teacher | floor: glowing cracked rock on the deck; molten fists in stance (74 DragonFire_PuddleIgniteFX_ScaleFX, 404 ChestLava_FxP, 521 CB_SinkingInferno01_FxP, 117 Gauntlet_Pyromancer_Idle01_FxP); to author: the seam: DragonFire puddle flames recoloured orange-black over a dark crust |
| **Magma Fist** `fire_blast/punch` | Twist, 2 pt | The Fireball is a ball of magma: it adds 22% (from 20) and splashes a seam where it hits or lands, but flies 19 m/s (from 22). It flies straight, as the Fireball does. It is still fire: Parry sends it back, a perfect Turn douses it (an obsidian stone drops), walls stop it. *Answer:* Same answer as the Fireball; the seam it leaves is floor fire: jump it. *Not with:* Blazing Fireball. *Needs:* Magma. | Magma, expert Punch | projectile: a flaming boulder and a molten splash (81 Flame_Boulder_FX, 97 FireBoulderImpact_FX, 74 DragonFire_PuddleIgniteFX_ScaleFX) |
| **Lava Kick** `fire_kick/kick` | Twist, 2 pt | The Kick's wave leaves its last 4 m molten for 3 s (a long seam in place of a small one) and knocks with base 6.4 (from 5.8), but runs 13.6 m (from 16; grown 18.7 from 22). *Answer:* Same answer: along the floor; jump it; walls stop it. The strip it leaves is floor fire. *Not with:* Long Kick, Twin Wave. *Needs:* Magma. | Magma, expert Kick | floor: a flame wave over a glowing crack line (103 FireWall_FX_PyrolysisTranslucentSmoke, 404 ChestLava_FxP, 85 P_Shockwave_Earth_Fast_ToonUnlit) |
| **Magma Landing** `fire_jets/jets` | Twist, 2 pt | Where your Jets land they splash a 2 m seam. Jets fly 13.5 m/s (from 15). *Answer:* Floor fire where you land: step off or jump. *Needs:* Magma. | Magma, expert Jets | floor: a molten splash ring at the landing (97 FireBoulderImpact_FX, 74 DragonFire_PuddleIgniteFX_ScaleFX) |
| **Forge** `fire_kick` | Passive, 2 pt (home ground) | Home ground: standing on your own seam, your locks fill x1.15 (your seams never burn you). Your seams last 2.5 s (from 3). *Needs:* Magma. | Magma, expert in any 2 Magma moves, a trial | hands: heat shimmer at the feet (404 ChestLava_FxP, 74 DragonFire_PuddleIgniteFX_ScaleFX) |

#### World arts (open world only) (3, 4)

Travel and work in the open world, from dormant fire specs. Never in the ring.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Hover** `fire_jets/hover` | World only, not in the ring | Hold Space as the Jets end to hover 2 s, falling at 1 m/s (the dormant fire_jets hover): for gaps and ledges. Never in the ring (it would change the % ring's recovery reach). | as today | body: downward flame jets at the feet (108 Fire_Firefly_Hands01_FxP*, 109 Fire_Firefly_Launch01_FxP*) |
| **Heat** `fire_breath/heat` | World only, not in the ring | Melt ice and dry ground within 6 m (the dormant fire_breath heat): for frozen rivers and doors. Never in the ring. | as today | hands: heat shimmer and steam off ice (20 P_Steam_Cloud_Dissipate, 192 VaporCloud_FX) |

Starter loadouts (10 points each):

- **Blaze**: Punch in rhythm, burst the Fireball, burn the floor you leave. (Two-Hand Rhythm 2, Blazing Fireball 2, Tight Embers 1, Reaching Parry 1, Ignite Step 2, Crescent Burn 2)
- **Storm**: Fork Lightning into his water; hold his Lightning and send it back late; curve your fire round him. (Forked Lightning 2, Grounded Charge 2, Hold the Storm 2, Snap Punch 1, Tight Embers 1, Curved Curtain 2)
- **Forge**: Floor the deck with magma, burn your wounds shut, step off your own seams. (Magma 2, Magma Fist 2, Lava Kick 2, Cauterize 3, Quick Step 1)

### 7.4 Air: evasive, pushing, momentum

Skill set Frostwind; the free tap twice is 4 (Dust Cloud, or Blizzard with Frostwind); key 5 tap twice stays empty; passive Carried wind. The Wind Guard gets the same care as the other guards (Drift Guard, Eye of the Gale, Rebound), and Patch has Second Wind. Left plain on purpose: Pull (its string Pull then Palm is in the skeleton) and the Slam's lift (recovery).

#### Blade (LMB, 1, E)

The shot and the guard: Palm, Slice, Wind Ball, Wind Guard.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Wide Palm** `air_palm/palm` | Enhance, 1 pt · open world only | Palm is 48 deg wide (from 40) but reaches 3 m (from 3.5). | practised Palm | projectile: a wider palm blast (202 WindMBlast_FX, 201 WindExplode_Small_FX) |
| **Shoving Palm** `air_palm/palm` | Enhance, 1 pt | Your Palm shoves harder: a set knock of 5.4 (from 4.5), so it makes room, but your jab string reaches him less often. It adds 4% (from 5). | practised Palm | projectile: a heavier palm blast (202 WindMBlast_FX, 201 WindExplode_Small_FX) |
| **Keen Edge** `air_blast/slice` | Enhance, 1 pt | Slice flies 54 m/s (from 45) but is thinner, 0.10 m (from 0.12): harder to see, harder to land. | practised Slice/Wind Ball | projectile: a thinner, brighter blade (204 WindProj_FX, 187 CBTrail01_FX) |
| **Tailwind** `air_blast/slice` | Twist, 2 pt | A Slice that hits charges your Carried wind (0.8 s), as a dash does: your next hit knocks harder. Slice adds 10% (from 11). *Answer:* Same answer: through the air; Wind Guard bounces air; walls stop it. *Not with:* Twin Slice. | expert Slice/Wind Ball, the air teacher | hands: a wind ribbon wraps your arm when a Slice lands (204 WindProj_FX, 193 Gauntlet_Tempest_Idle01_FxP) |
| **Twin Slice** `air_blast/slice` | Twist, 2 pt · **held** (question 4) | Held for the owner (question 4): one Slice sends two blades (a volley in place of the Slice). Two blades 0.1 s apart. One volley: they add 12% (from 11) and only the first knocks; growth is 10.4 (from 13), so it builds % but KOs later. *Answer:* Same answer: through the air; Wind Guard bounces air; walls stop it. *Not with:* Carry the Edge, Tailwind. | your answer first, expert Slice/Wind Ball, the air teacher | projectile: two blades, one after the other (204 WindProj_FX, 201 WindExplode_Small_FX) |
| **Dense Ball** `air_blast/ball` | Enhance, 1 pt | Wind Ball's lock is 0.66 s (from 0.75) but it is smaller, 0.29 m (from 0.35). | practised Slice/Wind Ball | projectile: tighter swirl bands (204 WindProj_FX, 69 DownBurst_X_FX) |
| **Toxic Gale** `air_blast/ball` | Synergy, 1 pt | Your Wind Ball through gas bursts it into a 4 m puff on the far side, and the cloud is now yours: blow a foe's gas back at him, or spread an ally's. Trade: your Wind Ball adds 10% (from 11). | seen once | reaction: a cloud burst on by wind (163 FX_PoisonCloud_WindExplosion, 205 WindProj_Toxic_FX) |
| **Drift Guard** `air_shield/shield` | Enhance, 1 pt | You can walk at 1.5 m/s with your Wind Guard up (today you stand still while it is up), but its beat is 0.25 s (from 0.3). | practised Wind Guard | hands: the guard's wind moving with you as you walk (193 Gauntlet_Tempest_Idle01_FxP, 701 Triump_Wind01_Ground_FxP) |
| **Eye of the Gale** `air_shield/shield` | Twist, 2 pt | Hold E through a perfect Wind Guard and the air you bounced circles you, up to 0.6 s; let go to send it along your aim (x1.2 as before). The Carried wind a perfect Wind Guard gives you lasts 0.4 s (from 0.8). *Answer:* His air still comes back along your aim; only the moment it leaves is yours. | expert Wind Guard, the air teacher | hands: a ring of wind circling the body with the caught shot in it (198 TornadoNewSimple, 701 Triump_Wind01_Ground_FxP, 201 WindExplode_Small_FX) |
| **Rebound** `air_shield/shield` | Technique, 2 pt | After a perfect Wind Guard, your next Slice or Wind Ball begun within 1 s starts its lock 40% full. Your held Wind Guard drops after 2.0 s (from 2.5). | expert Wind Guard, a trial | hands: charged wind on the arms after a perfect guard (193 Gauntlet_Tempest_Idle01_FxP, 825 ChronoHands_FxP) |
| **Carry the Edge** `air_blast/slice` | Technique, 2 pt | A Slice let go on the Beat while Carried wind is charged doesn't spend it. Slice adds 10% (from 11). *Not with:* Twin Slice. | expert Slice/Wind Ball, a trial | hands: a wind ribbon that stays on the arm; the Beat flash on your own hands (193 Gauntlet_Tempest_Idle01_FxP, 187 CBTrail01_FX, 825 ChronoHands_FxP) |

#### Squall (2, passive)

Pushing, pulling and momentum: Gust, Pull, Down Gust, Carried wind.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Long Gust** `air_gust/gust` | Enhance, 1 pt · open world only | The Gust reaches 16.8 m (from 14) but is 1.6 m wide (from 2). Still a wave you can see and dodge; the Air Lance (the Gust held long, 2026-10-10) is the same spear. *Not with:* Full Sail. | practised Gust/Pull | projectile: a long travelling band of wind (121 Flight_D_FX*, 202 WindMBlast_FX) |
| **Full Sail** `air_gust/gust` | Enhance, 1 pt | Your Gust is 2.4 m wide (from 2), but its lock is 0.5 s (from 0.45). The Air Lance (the Gust held long) is the same spear. *Not with:* Long Gust, Frost Gust. (Until 2026-10-10 it widened the grown Gust, which is now the Lance; switched off in the live loadouts until a soak measures the new numbers.) | practised Gust/Pull | projectile: wider wave bands (202 WindMBlast_FX, 701 Triump_Wind01_Ground_FxP) |
| **Rising Gust** `air_gust/gust` | Twist, 2 pt | Your Gust lifts as it pushes: it throws him at 55 deg (from 30), and so does your Air Lance (the Gust held long), so he goes up more than out. It rings him out later but sets up your air game. *Answer:* Same wave, same answers: dash, guard or wall it. | expert Gust/Pull, the air teacher | projectile: a wind wave curling upward as it goes (121 Flight_D_FX*, 701 Triump_Wind01_Ground_FxP) |
| **Long Pull** `air_gust/pull` | Enhance, 1 pt · open world only | Pull reaches 16.8 m (from 14) but drags with a set 5.4 (from 6). | practised Gust/Pull | projectile: a longer inward wave (121 Flight_D_FX*, 202 WindMBlast_FX) |
| **Dragon Fire** `air_gust/gust` | Synergy, 1 pt | Your Gust through an ally's Fire Wall or Breath carries the flame 6 m on as a fire front (adds 6%, set knock 6). Team only (greyed out in 1v1). Through a foe's fire wall your air already takes the flame (today's rule). Trade: your Gust adds 9% (from 10). | seen once | reaction: a wind-driven flame front (22 P_Wind_Secondary_DragonFire_Explosion, 196 TempestPyro_FX) |
| **Carrying Wind** `air_gust/gust` | Technique, 2 pt | A Gust let go on the Beat picks up the loose stones it crosses and throws them 6 m along its path (each a pebble: adds 5%, set knock 3). Gust's lock is 0.5 s (from 0.45). *Answer:* The stones are stone: a Catch holds them, walls stop them. | expert Gust/Pull, a trial | projectile: debris riding the wave (724 FX_Environment_WindBits, 80 FX_RocksTravelCharge*, 825 ChronoHands_FxP) |
| **Long Carry** `evade` | Passive, 2 pt | Carried wind lasts 0.96 s after a dash (from 0.8), but knocks x1.1 (from x1.15). *Not with:* Gale Force. | expert in any 3 Air moves, the air teacher | body: a charged trail held a moment longer (65 DashTrail_FX, 193 Gauntlet_Tempest_Idle01_FxP) |
| **Gale Force** `evade` | Passive, 2 pt | Carried wind knocks x1.2 (from x1.15), but lasts 0.64 s after a dash (from 0.8). *Not with:* Long Carry. | expert in any 3 Air moves, the air teacher | body: a brief, bright gust off the shoulders (193 Gauntlet_Tempest_Idle01_FxP, 202 WindMBlast_FX) |

#### Drift (3, 4, 5)

Evasion, cover and recovery: Slip, Leap, Wind Wall, Patch and the free tap twice on 4.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Near Miss** `evade/slip` | Enhance, 1 pt | A Slip charges Carried wind on a near miss within 1.44 m (from 1.2), but slips at 8.5 m/s (from 9.5). | practised Slip | body: a wind ring flashing on your own shoulder at a near miss (65 DashTrail_FX, 201 WindExplode_Small_FX) |
| **Gust Step** `evade/slip` | Twist, 2 pt · **held** (question 4) | Held for the owner (question 4): a dash that hits (key 3 is travel). Your Slip shoves whoever you pass within 1.2 m aside (adds 2%, set knock 4). It slips at 8.5 m/s (from 9.5). Brings back the dormant air_redirect gust_step. *Answer:* A dash he sees coming: step back or guard it (it is air). | your answer first, expert Slip, the air teacher | body: a side burst as you pass (201 WindExplode_Small_FX, 65 DashTrail_FX) |
| **Featherfall** `air_jump/leap` | Enhance, 1 pt · open world only | Leap's glide falls at 2.0 m/s (from 2.5), but the Leap rises at 11 m/s (from 12). | practised Leap | body: the featherfall rune (94 FeatherFall02_FX, 242 Featherfall_AG_FxP) |
| **Peak Wind** `air_jump/leap` | Technique, 2 pt | A Leap let go on the Beat charges your Carried wind at its top: your first hit within 0.8 s of the peak knocks harder (x1.15). The Leap rises as high as ever. Leap's lock is 0.3 s (from 0.25). | expert Leap, a trial | body: a burst of wind at the top of the Leap; the Beat flash on your own hands (274 SoaringAura_AG_FxP, 201 WindExplode_Small_FX, 825 ChronoHands_FxP) |
| **Standing Wind** `air_wall/wall` | Enhance, 1 pt · open world only | Your Wind Wall stands 4.8 s (from 4) but is 2.4 m wide (from 3). *Not with:* Dust Cloud, Frostwind, Blizzard. | practised Wind Wall | rise: a narrow column of streaming wind (198 TornadoNewSimple, 701 Triump_Wind01_Ground_FxP) |
| **Dust Cloud** `air_wall/dust` | New skill, 3 pt | A 3 m cloud of dust where you aim (2-6 m, placed like a wall, never round you) for 2.5 s that blocks sight both ways, like Breath's smoke. Lock 0.9 s; a new one ends your old one. Trade: your Wind Wall stands 3.5 s (from 4). Draws on the dormant air_redirect dust (a mode of a move round 2 dropped with the variations layer; 4 s in the open world). *Answer:* Sight only: go round it, or blow it away with a Gust. *Not with:* Standing Wind. | expert Wind Wall, the air teacher | cloud: a cloud of swirling dust where you aim (157 LandingDust_FX, 839 SmkObscureS_FxP1, 61 Backplate_Dust) |
| **Second Wind** `patch/patch` | Enhance, 1 pt | Begun within 0.8 s after a dash, your Patch's lock is 1.25 s (from 1.5). Begun any other time it is 1.6 s. *Not with:* Whiteout. | practised Patch | hands: wind drawn in round the body, then a glow (184 Health_Regen01_Burst_FxP, 701 Triump_Wind01_Ground_FxP) |

#### Frostwind (skill set: air's ice) (1, 2, 4)

The owner's 'wind and ice because wind can freeze water': air freezes the water that is there; water keeps shaped ice. Cover, never slippery, never a slow.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Frostwind** `air_gust` | Skill set, 2 pt | Wind that freezes, as a skill set: air freezes the water that is already there; water keeps shaped ice. Your Gust or Wind Ball turns a puddle or a grate it crosses into frost crust: a ridge of ice 0.4 m high and 3 m long for 4 s; floor waves and rolling stones stop at it, anyone can jump it, it is never slippery (two ridges and mounds of yours at once). A frozen grate is no water source until the crust melts. Steam it crosses falls as snow and clears. Water and ice your Wind Wall blows aside fall as shards. Fire melts crust back into a puddle (a grate's back into the grate); mud never freezes. Opens the Frostwind nodes. Trade: your Wind Wall stands 3.5 s (from 4). *Not with:* Standing Wind. | the frostwind quest, the frostwind teacher | floor: frost breath on the hands; low ice ridges on the deck (125 BoulderFrozen_Mist_FxP, 12 P_Frozen_Explosion, 9 P_Earth_Primary_AOE_Frozen, 753 P_Chapter2_Snowflakes); to author: the crust ridge: an ice-wall look kept low (Spellbreak's ice patch only as a colour reference) |
| **Hail Ball** `air_blast/ball` | Twist, 2 pt | The Wind Ball carries a hail core: where it hits or ends its flight it bursts into 3 hailstones within 2 m (2% each, no knock). Its knock is base 7 (from 8). It is still air: a Wind Guard bounces it whole, a Wind Wall blows it aside, walls stop it. *Answer:* Same answer: Wind Guard bounces it whole; a Wind Wall blows it aside; walls stop it. *Needs:* Frostwind. | Frostwind, expert Slice/Wind Ball | impact: a ball of wind with a hail core; hail bursting (204 WindProj_FX, 403 Permafrost_Swing_SnowBall_Hit_FxP) |
| **Frost Gust** `air_gust/gust` | Twist, 2 pt | Your Gust puts out a fire wall or burning ground it crosses (today air blows through a fire wall). It is 1.8 m wide (from 2). *Answer:* Same wave, same answers: dash, guard or wall it. *Not with:* Full Sail. *Needs:* Frostwind. | Frostwind, expert Gust/Pull | reaction: a fire wall snuffed by cold wind (102 FireWall_Extinguish_Wind_FxP, 101 FireWall_Extinguish_Ice_FxP, 125 BoulderFrozen_Mist_FxP) |
| **Rime Wall** `air_wall/wall` | Twist, 2 pt | When your Wind Wall ends it drops a frost crust ridge where it stood (3 m, 3 s). While it stands it works exactly as before. It pushes at 3.2 m/s (from 4). *Answer:* While it stands it is a Wind Wall; the ridge it leaves is low: jump it. *Needs:* Frostwind. | Frostwind, expert Wind Wall | rise: a frosted column of wind collapsing into a ridge (198 TornadoNewSimple, 125 BoulderFrozen_Mist_FxP, 9 P_Earth_Primary_AOE_Frozen) |
| **Blizzard** `air_wall/blizzard` | New skill, 3 pt | A 2.5 m column of snow where you aim (2-10 m) for 3 s: it blocks sight both ways, freezes the water in it into crust, and a foe inside gains 1% each 0.5 s (cold; at most 6%; no knock, no slow). Fire melts it out in 1 s. Lock 0.9 s; a new one ends your old one. Trade: your Wind Wall stands 15% shorter (3 s with the set's 3.5 s). *Answer:* Step out of it; fire melts it. *Not with:* Standing Wind. *Needs:* Frostwind. | Frostwind, the frostwind teacher | cloud: a column of driving snow (122 Blizzard_Cyl1_FX1, 123 Blizzard_Cyl1_FX2, 753 P_Chapter2_Snowflakes); to author: scale: 122 and 123 are a ~50 m stationary blizzard cylinder; cut them down to a 2.5 m column |
| **Whiteout** `air_gust` | Passive, 2 pt (home ground) | Home ground: standing on your own crust or in your Blizzard, your locks fill x1.15. Patch's lock is 1.7 s (from 1.5). *Not with:* Second Wind. *Needs:* Frostwind. | Frostwind, expert in any 2 Frostwind moves, a trial | hands: snow swirling round the caster (125 BoulderFrozen_Mist_FxP, 753 P_Chapter2_Snowflakes) |

#### World arts (open world only) (3)

Travel in the open world, from dormant air specs. Never in the ring.

| Node | Kind, cost | What it does | Open world | Look (Spellbreak refs) |
|---|---|---|---|---|
| **Wind Run and Whirl Ride** `wind_run/wind_run` | World only, not in the ring | Wind run (3 s at 10 m/s) and whirl ride (4 s at 13 m/s), the wind_run move's modes, for travel. Never in the ring. | as today | body: speed lines and a ride of wind (724 FX_Environment_WindBits, 118 Flight2Anim_FX) |
| **Glide Landing** `air_jump/glide` | World only, not in the ring | The Leap's 4 s glide lands with no fall damage. The ring keeps its own glide and Updraft rules. | as today | body: the featherfall rune (94 FeatherFall02_FX, 242 Featherfall_AG_FxP) |

Starter loadouts (10 points each):

- **Momentum**: Keep moving: Slices that charge your wind and keep it charged; heal on the move. (Long Carry 2, Near Miss 1, Carry the Edge 2, Tailwind 2, Shoving Palm 1, Drift Guard 1, Second Wind 1)
- **Squall**: Bounce his shots back when you choose, lift him on the Gust, push him off with a full sail. (Eye of the Gale 2, Rebound 2, Rising Gust 2, Full Sail 1, Dense Ball 1, Keen Edge 1, Shoving Palm 1)
- **White-out**: Snow where he stands, hail where it lands, ridges against his floor waves, frozen grates against water. (Frostwind 2, Blizzard 3, Hail Ball 2, Frost Gust 2, Dense Ball 1)

## 8. Synergies (proposal)

The universal line, at the element pick and in F1, next to today's "Water douses fire, fire melts ice, air drops
stone": **"Fire lights gas; lightning charges it. Water washes gas and cools magma. Wind carries gas and snow. Mud stops floor fire. Fire melts frost."** It keeps every set answerable with zero points in synergies; the nodes only deepen it.

How reactions work (proposal):

- World rules act only on matter a pick makes (gas, mud, seams, crust, snow, dust), so Classic (no picks) plays exactly as today; a reaction that touches today's matter (steam, smoke, puddles, grates, fire walls) needs a node (Forked Lightning, Steamcraft, Scald, Frostwind).
- A reaction has a fixed % that never stacks (two bursts in one spot are two separate hits, each owned).
- Whoever sets a reaction off owns it: its % and its KO credit. A moved cloud belongs to the mover.
- Terrain made from someone's matter stays his: a melted crust's puddle is the water's owner's (a grate's goes back to the grate); an obsidian stone counts toward the seam owner's three loose stones; the extra Avalanche stones that drop at a catcher's feet are the thrower's loose stones.
- A reaction stales as the move that set it off.
- Allies stay immune, as today (BendStatus never lets a bend reach the caster's allies).
- Reactions are announced only at the existing callout spot (for example IGNITED!, OBSIDIAN!) with their own sound; nothing is drawn on anyone.

| Synergy | Elements | How it works | Solo or team | Nodes |
|---|---|---|---|---|
| **Ignited Sulphur** (proposed, building on the owner's 'Fire + poison') | earth, fire | Any fire that enters a gas cloud lights it (Embers, Punch, the Kick's wave, Fire Wall, Breath, a seam, a burning line): a burst 1.5x the cloud's size adds 6% and knocks 6 m/s outward (a set knock, never a KO), and the cloud is gone. It hits everyone in it, the earth player too. Whoever lit it owns it. Look: a cloud igniting (16 P_Ignited_Poison_Splash, 71 DragonFire_CloudIgniteFX_ScaleFX_RevA*, 106 FireWall_Toxic_Sm_FX). | team (fire lights an ally's gas), versus (light his gas while he stands in it), solo (Flint Pebbles) | Flint Pebbles, Flashfire |
| **Live Gas** (proposed, building on the owner's 'magma _ lightning? maybe') | fire, earth | Lightning through a gas cloud charges it instead of lighting it: everyone inside takes half the strike's % (no launch, no stun, no lock set-back: reaction/live is no_hurt) and the gas stays. Burn the gas or charge it. Look: an electrified cloud (160 FX_PoisonCloud_Electrified). | versus, team | none needed |
| **Wind Carries Clouds** | air, any | A Gust or a Wind Wall moves a gas, dust or snow cloud 4 m along its way, and a moved cloud belongs to the mover. Only clouds a pick makes move: today's steam and Breath's smoke stay where they are, so Classic plays as today. Toxic Gale goes farther. Look: a cloud carried by wind (163 FX_PoisonCloud_WindExplosion, 197 TempestToxic_FX). | versus (blow his gas back), team (spread an ally's) | Toxic Gale |
| **Washed Ground** | water, earth | A Wave or a Geyser washes out the gas it passes. Washout adds Splash and Lash; Cleanse adds the Turn. Look: a cloud dispersing in spray (168 P_PoisonCloud_Dissipate, 21 P_Water_Dissipate*). | versus (water's answer to Sulphur), team | Washout, Cleanse |
| **Obsidian** (proposed, building on the owner's 'magma') | fire, water, earth | Water on a magma seam cools it into a loose obsidian stone; a perfect Turn of a Magma Fist drops one. The stone counts toward the seam owner's three loose stones, and any earth player within 6 m may Shove it (stones on the deck are fair for both sides). Mud quenches a seam with no stone. In 3v3: fire floors the deck, water cools it, earth throws it. Look: steam off cooling magma; a black glass stone (10 P_Fire_Extinguish, 20 P_Steam_Cloud_Dissipate, 33 CB_ObsidianPlummet_Unified_FX). | team (all three), versus (water clears seams; an earth foe takes your stones) | none needed |
| **Brick** (proposed, building on the owner's 'Water + mud goes together') | water, fire | Fire bakes mud: a Mud Mound hit by fire turns to brick and stands 3 s more; a mud pool under fire dries in 1 s (it stops nothing and is no longer a source). A careless fire player bakes your cover; a careful one dries your pools. Look: mud baking to brick with smoke (99 FireIgnite_FX, 98 FireIgniteSh_FX); to author: the brick look on the mud mound. | versus, team | none needed |
| **Steam and its new branches** | water, fire | Water meeting fire makes steam (2.2 m, 1.5 s; it hides a man from a bot): today's rule, unchanged for everyone. With picks: Mud smothers fire with no steam; Frostwind freezes steam into snow that clears; Forked Lightning makes it live; Scald makes it burn; Steamcraft makes it last and drift. Look: steam; electrified vapour (20 P_Steam_Cloud_Dissipate, 192 VaporCloud_FX, 191 FX_VaporCloud_Electrified). | versus, team | Scald, Steamcraft |
| **Live Water** (a node) | fire, water | Only with Forked Lightning: its fork reaches water within 6 m of its path (a puddle, steam, a water shot in flight) and makes it live for 0.5 s: anyone in it takes half the strike's % with no launch, no stun and no lock set-back. Mud grounds it. Without the node, lightning and water meet as today. Look: a crackling puddle (719 FX_ElectrifiedPuddle, 720 FX_ElectrifiedPuddle_LoopedCenter, 191 FX_VaporCloud_Electrified). | versus (a water player weighs his own puddles), team | Forked Lightning |
| **Frost Melts** | air, fire, water | Fire melts frost crust back into a puddle (a water ally's source; a grate's crust melts back into the grate) and a Blizzard in 1 s. The puddle belongs to whoever owned the water. Steam to snow, puddle to crust, crust to puddle: a terrain loop across three elements. Look: ice melting in steam (192 VaporCloud_FX, 20 P_Steam_Cloud_Dissipate). | versus, team | none needed |
| **Ice Sheet** (proposed, building on the owner's 'Wind and Ice because wind can freeze water') | air, water | A Frostwind Gust that crosses an ally's Ice Wall hardens it: it takes 2 more hits (fire still melts it fast). No new wall: only key 4 makes walls, and the Ice Wall already counts as the water ally's. Team only. Look: an ice wall frosting over as the wind crosses it (125 BoulderFrozen_Mist_FxP, 12 P_Frozen_Explosion, 9 P_Earth_Primary_AOE_Frozen). | team | none needed |
| **Mudbank** | earth, water | An earth ally's Column rising out of your mud pool comes up 20% wider. Team only. Look: a pillar bursting out of mud (85 P_Shockwave_Earth_Fast_ToonUnlit, 523 CB_SlimySeepage02_FxP). | team | none needed |
| **Kiln Stone** (a node) | earth, fire | Your stone through any fire (his Fire Wall, an ally's, a seam, a burning line) comes out heated: base +15% and a fire trail. A heated stone burns: a Parry on the beat sends it back, a Turn douses it to a plain stone. Look: a burning stone (81 Flame_Boulder_FX, 97 FireBoulderImpact_FX). | versus (shoot through his wall), team | Kiln Stone |
| **Dragon Fire** (a node) | air, fire | Your Gust through an ally's Fire Wall or Breath carries it 6 m on as a fire front. Against a foe's fire wall, today's rule already sets your air shot burning. Look: a wind-driven flame front (22 P_Wind_Secondary_DragonFire_Explosion, 196 TempestPyro_FX). | team | Dragon Fire |

The owner's four fusions, where they live: **fire + poison** is Ignited Sulphur (burn it) and Live Gas (charge it),
the "magma _ lightning" fork; **water + mud** is the Mud set, Brick and Mudbank; **wind and ice** is the Frostwind set,
Frost Melts and Ice Sheet; **earth's poison** is the Sulphur set. Every named reaction past the four sets is this
draft's proposal, built on his words, not his idea. In-kit loops a single player builds for: Sulphur Vent with Flint
Pebbles (light your own gas); Pooling Wave, Wet Trail and Splashdown (lay puddles, feed the Geyser); Rubble Wall and
Quarry (your wall is your ammo); Two-Hand Rhythm with Blazing Fireball (punches in rhythm, a burst to finish);
Tailwind, Near Miss and Carry the Edge (Carried wind kept charged while you keep hitting the Beat); Eye of the Gale with
Rebound (bounce it back when you choose, then strike first); Frostwind's crust with Whiteout (fight from your own
frost).

## 9. The build-out help: the "intelligent" layer (proposal)

All of it is rule-based and reads only your own play; none of it reads live enemy state or draws on targets.

1. **The tree is the strip.** The tree screen is the BendStrip on its side: seven chip columns (LMB JAB, E GUARD, 1 STRIKE, 2 PUSH, 3 DASH, 4 WALL, 5 HEAL) with each move's line growing up from its chip: enhances, the twist fork, the technique. Branches are coloured threads through the columns; the skill set is a band along the bottom that tints the chips it touches. Hover a chip and every node touching that move lights in order, each with its cost and its '+ / -' line.
2. **Node cards.** One help line of 64 characters or fewer, the trade chips straight from the node's data, old and new numbers side by side, and a 4 s looping preview recorded against the practice dummy (tools/bending/vfx_lineup.gd style).
3. **Try it.** Every node has Try: Practice opens wearing it (even unlearned) through MatchSetup.set_practice with a temporary loadout, the dummy set for it (throwing stones for Catch nodes, kicking floor waves for Mud and Frostwind, standing in a gas cloud for Flashfire). The open-world gate still applies outside Practice.
4. **Starter loadouts and build paths.** Three named starter loadouts per element, each shown as a route through the tree with a one-line plan; one click wears it.
5. **Coach.** After a match, at most three suggestions from your own tally only (casts per move, catches, perfect guards, falls by lane, reactions you caused), each with a why line: 'You held 80% of your casts and hit the Beat 1 in 4: Return to Sender pays for it.' '6 of your last 10 falls came off floor waves: Mud, Thick Wall or Frostwind.' It never equips anything. Rules as data (proposal: data/bending/coach.json).
6. **Build for me / explain this loadout.** One button fills a coherent 10-point loadout from your most-used moves; every pick gets one line, the whole loadout three ('Hold ground with Mire, push with Mudslide, mound up for cover').
7. **Synergy threads and the team web.** Worn nodes that combo draw a thread with its name ('Sulphur Vent + Flint Pebbles: your Pebbles light your own gas'); warnings too ('Forked Lightning: your puddles conduct his Lightning'). In a 3v3 lobby, before the match only, the team web lists what your three loadouts make together and the gaps ('No one can wash gas'), with the cheapest node that fills one.
8. **Threat coverage.** Five icons (along the floor, through the air, up from under, stone, lightning) show which threats your loadout answers, computed from the interactions table; with a known foe element one line more ('vs fire: Mud stops the Kick's wave; Frost Gust snuffs his Fire Wall').
9. **Counter card.** Before the countdown, both loadouts with one 'how to answer' line per pick, from each set's three counter lines and each node's answer line.
10. **Path planner (open world).** Pick a node; the planner names the steps in words (the practice target, the teacher, the trial) as a journal line. No map markers.
11. **Lessons.** One Combo Lab card per world rule and per set ('Light the dummy's gas with Embers'), done by doing it, in the RingLessons pattern.
12. **Loadout codes.** Short codes to share a loadout.
13. **In the fight: nothing new.** The fight HUD gains nothing: your own strip chip names your twist and your own hands flash on the Beat. No markers, rings, frames, dots or highlights on anyone, and no 'combo ready' prompts. Reactions are announced only at the existing callout spot.

## 10. Visuals (references, to be checked by eye)

Every node names the kind of visual it needs and two or three Spellbreak references (section 7, and `visual` in the
data). The kinds:

| Kind | What it needs |
|---|---|
| hands | a flash or loop on the caster's own hands and arms (charge, the Beat, a stance aura) |
| projectile | flight and trail |
| impact | a burst where it lands or breaks |
| floor | a lasting zone or line on the deck (cloud, pool, seam, crust, fire line) |
| rise | something raised from the deck (wall, column, mound, slab, dome) and its break |
| body | a dash or travel trail on the caster |
| cloud | a lingering volume (gas, steam, dust, snow) |
| reaction | two matters meeting (a two-colour burst) |

Notes:

- **Source and attribution.** Spellbreak effects (Proletariat), converted in `artifacts/spellbreak_fx` (853 systems;
  each base move's reviewed picks are in `bending_fx_map.json`, and the nodes add only what changes). Keep Spellbreak
  attribution on anything taken from there. The owner reports a licence for their use in Tidebreak
  (`animations/SOURCE.md`); this draft does not verify it, and the owner's task authorization is not a third-party
  licence.
- **Checked against the reviewer's rejections.** Every pick was checked against `bending_fx_map.json`
  reviewer_rejections and moved to the "better" index where the role matched: 189 (a landing cloudburst with 10-14 m
  smoke), 120 and 199 (stationary takeoff rings, a stationary tornado; 121 is the asset that travels), 110 (black smoke
  in the sweep), 264 (its flame ribbons are off: a smoke trail), 101 where fire melts frost (it is fire put out by ice;
  kept for Frost Gust, where the fire loses), 11 (a prototype weapon on Matra materials), 732 and 733 (lobby decor) and
  154 (purple mana). 122 and 123 (a ~50 m stationary blizzard cylinder) are kept only for the Blizzard, cut to size.
- **They are references, not finished effects.** The browser's shader math is authored, and the four-element lab was
  rejected as not one-to-one (`docs/claude_fx_handoff.md`). Each pick is checked by eye before use; the `*` picks
  first.
- **Never as cues.** Targeting systems (`P_Trajectory_*`, `FX_TargetBeam*`) are never used, systems with no particles
  are never picked, and no effect is drawn on a target as a marker. Gas round a body is the cloud itself, not a mark.
- **Readable without colour.** Each new zone carries its own outline shape for colour-blind players (gas a soft rolling
  edge, mud ringed ripples, a seam a cracked line, crust a jagged ridge, snow a slanted fall) and its own loop sound (a
  hiss, a slow bubble, a crackle, a creak, a howl), as today's arts carry ring shapes and every shot its own flight
  voice. Never colour alone.
- **Gaps to author** (Spellbreak has none): mud (pools, splats, a mud mound), a plain puddle, a liquid cone for the Wave family, a water sphere (Bubble, if the owner brings it back), the magma seam, the frost crust ridge and a frozen grate, the Blizzard column (122 and 123 cut from ~50 m to 2.5 m), the Beat's hands glow per element, an outline shape and a loop sound for each new zone.
- **Cost.** `BendLooks.warm_up` must compile every new effect behind the loading screen, or the first Ignited Sulphur
  will freeze a frame; ToonFxPool's per-kind caps cover the new zones.

## 11. Left out on purpose

| Left out | Why |
|---|---|
| ice freeze (root_s 1.5), air_palm trip (root_s 0.6), fire_parry flare (slow_s 1.2), the frost ice_patch and air_blast vacuum zones (BendZone calls BendStatus.slow), and earth_grip trap and sink (holds by name and intent) | they root, slow or hold: never wired into a node |
| stone_form disc in the ring; fire_arc kick (the flame wheel) and sweep | identity: the disc was cut from the ring, and the owner replaced the flame wheel with the Kick |
| stone_catch deflect | earth always catches and holds stone |
| water_whip lash (a 5.5 m cone), ice shards (a volley in place of the Spear), fire_jab jab (the 3 m fist cone) | each turns the move into something else (the identity test's delivery check); the owner replaced the fist cone with Embers |
| water_redirect absorb, air_redirect redirect, air_palm cushion | each changes what a guard does with what it takes |
| air_shield cyclone and tornado in the ring | air's free key 5 says HEAL and its key 4 slot is for cover; kept as an open question |
| Hover in the ring | it would change the % ring's recovery reach (ring.recovery); open world only |
| Tremor Sense (louder, directional enemy footsteps) | an audio target cue |
| Coats on bodies (Wet, Caked, Toxic, Rimed, Charged) | hidden state drawn on the target that changes the next hit: near a mark on targets and heavy to learn |
| Slick ground (knock x1.15) and Mire's launch x0.85 | knock levers on the one who was hit |
| Vortex Ball (a 0.8 s pull at 4 m/s) | a sustained pull reads as a slow |
| Cooldowns (Shell 6 s, Anchor 8 s, Cyclone 6 s, Mole Run, Wrapping Lash) | lock time is the only spam limiter |
| Zero-lock follow-ups (Pull and Palm with no lock, Absorb, Chain Kicks with no lock) | every cast keeps a lock; techniques give part-full head starts instead |
| Slot replacement (Vent for Column, Bog Spout for Geyser, Eruption for High Kick, Brace or Bubble for Mend) | it removes moves and their true strings; only empty tap twice slots are filled |
| Guard-table rewrites (Silt Turn, Cushion, a Frost Wall that stops fire passing, Lightning Rod, Grounding, True Lance's late-Catch drop, Twin Spikes past a Catch, Return as a reflector) | the guard line every player learns must stay true |
| Lane changes (Packed Return, Meteor, Tall Wave, Flat Crescent, a stomp ring added to the Hammer) | the floor / air / under answer must stay true |
| Wall-row changes (Tide Wall, Mud Wall in place of the Ice Wall, Magma Berm or Lava Wall, Prism Wall, Return Wind) | each wall's stops / weak to / lets through row must stay true |
| A fourth mastery tier ('master' at 100 uses) | mastery has three tiers in data and code (TIERS, clips); techniques gate on expert plus a trial instead |
| Storm Call (a cloud over a spot that strikes later) | fire's free slot is HEAL, and a cloud parked over a spot reads close to a placed marker |
| Forged Catch (earth catching magma) | it adds a new guard answer to fire; Obsidian gives earth the cooled stone instead |
| A 'toxic magma' fire set | two elements owning poison blurs earth's set; fire meets poison through Ignited Sulphur and Live Gas |
| Stream (fire_blast stream) and Double Jab (fire_jab double_jab) | round-2 cuts: the answers file records under answer 4 that the other fire cuts in the spec, stream and double jab among them, stand, and answer 5 accepted the spec's other recommendations |
| Shear (A or D held at release bends the Gust 30 deg) | a hidden rule, like the ones round 2 cut (the kick picked by where the crosshair points, Lift's footstep timing) |
| Slingshot (Pull drags him past you) | it loses the true string Pull then Palm, which the fixed skeleton keeps |
| Lifting Down Gust (the Slam lifts you higher) | it lengthens air's recovery, already the longest (17.4 m); no ring node changes recovery |
| The % ring's shared layer: each Rise, the close air hits, the Pop, the edge and get-up attacks, and the Slams' hits | recovery and the edge game stay the same for everyone (as Hover), and the Pop and the air hits carry every element's strings; a Slam's matter may change (Pooling Downpour's puddle), its hit may not |
| Range-for-width number swaps in the ring (Broad Column, Long Reach, Broad Wave, Long Kick, Long Curtain, Long Lightning, Wide Palm, Long Gust, Long Pull, Standing Wind) and Featherfall | kept for the open world's depth, out of the ring's pick list so it stays short and every pick is a change you can feel; Featherfall because the % ring has no Leap glide |
| Wind moving today's steam and smoke, and lightning in today's water, for everyone (the draft's Wind Carries Clouds and Live Water world rules) | Classic (no picks) must play exactly as today: Live Water is Forked Lightning's own rule, and wind moves only clouds a pick makes |

## 12. Open questions for the owner

1. The pairings: earth Sulphur (poison), water Mud, air Frostwind (ice), fire Magma, with lightning as fire's Storm branch rather than a second set. Is that the reading you meant? Frostwind now freezes the deck's grates as well as puddles, so it has water in every match; or should air make its own frost?
2. The loadout shape for skill sets: inside the 10 points or outside; one set per loadout or several; one set per element, or sets any element can carry (a water player wearing Sulphur); poison earth's alone? This draft's answers (one per element, one per loadout, 2 points inside the budget) are proposals.
3. The round-2 cuts. You cut the shell, the ramp, the bubble, the shards and the Lash jet on 2026-10-05, and you kept Breath with its smoke. Held until you answer: Shell, Ramp, Bubble, Jet, Shatter (the shards) and Clean Burn (Breath with no smoke). Bring any back as pre-match picks? Stream and Double Jab are left out, as the answers file records them standing; say so if you want them back too.
4. Twists held by the identity test: a volley in place of one move (Forked Fissure, Twin Geyser, Twin Wave, Twin Slice), a dash that hits (Surfacing Stomp, Breaker, Gust Step), and Reel (the Lash pulls him in and never KOs). Any of these as pre-match picks, or none?
5. Walls: only key 4 makes walls (round-2 spec 2.7). This draft keeps that (Mud Mound is low terrain; Ice Sheet hardens an ally's Ice Wall). Relax it for set terrain, or keep it?
6. New skills on the empty tap twice: Sulphur Vent, Mire, Dust Cloud, Blizzard, Cauterize (and Shell or Bubble if question 3 is yes). Yes, or twists only with no new moves? Air's key 5 stays empty: leave it, or Tornado or Cyclone later?
7. The Beat (let go within 0.2 s of the lock filling; a flash on your own hands) as the one timing rule techniques pay for. Yes? Without it, techniques need other triggers.
8. World rules act only on matter a pick makes, so Classic (no picks) plays exactly as today: Live Water became Forked Lightning's own rule, and wind moves gas, dust and snow but not today's steam or smoke. Agreed, or should some reactions be for everyone?
9. Forked Lightning makes a water player's own puddles a risk against fire. Fine, given water's current strength in the soak?
10. Sight blockers: Dust Cloud and Blizzard (placed, with a soak cap on time unseen) and Steamcraft add to the cover that already lets Breath's smoke stall a bot. Accept and teach the bots, or fewer sight zones?
11. Mud pools, Mud Mounds and frost crust stop floor waves and rolling stones: new counters to the Kick and the Boulder. The right amount of counterplay?
12. Budget: 10 points in the ring, and 6 growing to 20 in the open world. Smaller (fewer choices, easier) or larger?
13. Open-world PvP (co-op and PvPvE): when two players meet in the open world, open-world power (budget, ranks, practice lock times) or the ring's flat 10 points?
14. Should ring and PvP practice count toward open-world unlocks? This draft says no (cosmetic badges only).
15. Fighting styles and the tree: docs/fighting_styles_design.md puts style and weapon on the ring budget, each a branch of this tree; this draft kept them outside the 10 points. Which do you want? Weapons stay out while they are on hold. Until you rule: a style's signature counts as its move's twist, its perfect-guard reward as that guard's technique, and a 25% clamp where they touch the same number.
16. Should Fire Wall's own tick stop breaking a Lightning charge, like the new matter ticks? (Today it breaks it.)
17. Teachers and quest homes: may the Thủy Vân world session name and place them (sulphur springs, mud flats, a snow pass, a forge mountain, a storm watch)?
18. Visuals: use the converted Spellbreak effects as the look references, attribution kept, each checked by eye?
19. Player-facing words: Enhance, Twist, Technique, New skill, Passive, Synergy, Skill set. Plain enough? ('Variation' was the name of the round-2 layer you cut, and 'Mastery' is the practice tier the HUD shows, so this draft avoids both.)

## 13. Build order (proposal)

0. Owner answers to the open questions; nothing is built before the pairings (1), the loadout shape (2), the round-2 cuts (3), the identity twists (4) and the styles conflict (15) are settled.
1. Data and loader only: read data/sway/skill_tree.json, validate it (extends_move and applies_to, costs, limits, excludes recomputed from changes[], starter loadouts, held nodes never worn), save a per-body loadout. Tests: the identity test per node, a % ring guard test per guard node (perfect, late and catch through RingRules.guard_outcome with the wearer's numbers, tapped and held), and the no-debuff contract (no node writes a victim's speed, aim, camera, lock or guard). On its own branch: several sessions share main.
2. The merge hook: a node's numbers merged over the bend spec in BendEffects.apply next to the existing grow merge; per-wearer copies of the stock guard and Patch numbers (guard_perfect_s, guard_catch_s, late_mult, return_mult, patch.lock_s) and of Bending.passive(), rules() and SwayCaster.modes_of() (the new modes and Cauterize only through per-body modes: air's key 5 is the same one-id patch key); variation tags with their stock.classes entries; one shared tag lookup that strips '+name' for every consumer (stale moves, stock.range.exempt, air_rules.lag_class, return_base_tag, the highlights, bend_ai.json pct.strings), with a test.
3. Enhances only, all four elements, plus starter loadouts made of enhances; soak, and the string re-check for the enhances on its list.
4. The loadout screen (the strip on its side), node cards, Try it, the versus-card loadout line, greying by control scheme.
5. Twists: first those on dormant specs that already dispatch (Hold the Storm's redirect_lightning, Ignite Step's burn line, Cleanse), then the new-code ones (Juggle, Avalanche, Rubble Wall, Whirl Turn, Pooling Wave, Splashdown, Blazing Fireball, Crescent Burn, Curved Curtain, Forked Lightning, Tailwind, Eye of the Gale, Rising Gust). Held twists only if the owner says yes. Soak.
6. New skills on the empty tap twice via per-body modes: Dust Cloud and Cauterize (Shell and Bubble only if question 3 is yes). Soak, with the shielded-or-unseen metric.
7. One skill set end to end, its visual gaps authored in the same step and judged by eye before the next: Sulphur first (the gas zone kind, the tick contract, Ignited Sulphur, Live Gas, bot answers, a Combo Lab card, the gas look with its outline and sound), then Magma (the seam), Mud (mud pools, the mound), Frostwind (the crust ridge, frozen grates, the Blizzard column cut to size). Soak each.
8. The Beat and the techniques (SwayCaster release window 0.2 s, own-hands flash, bend_ai beat_rate). Soak.
9. Synergy nodes, the Coach, Build for me, the team web, the path planner; the open-world gates (teachers, trials, ranks) when free_use goes off.
10. The remaining per-node visuals from the reviewed picks; BendLooks.warm_up must compile every new effect behind the loading screen.

The twelve starter loadouts use 67 distinct nodes: a natural first wave once the enhance-only round is
green.

## 14. Where this design came from

Three designs were drafted (BUILD-OUT DEPTH, SYNERGY WEB, RING FAIRNESS) and scored by three judges (fun and synergy
depth; the owner's rules and fairness; implementability against the code). The base is **RING FAIRNESS**, the highest
total (22 of 30), for its fixed skeleton, its same-answer gate and its clean reading of the owner's rules. Grafted onto
it:

- from BUILD-OUT DEPTH: new skills only on the empty tap twice; a move's line growing up from its chip; set twists
  sharing a move's single twist slot; the Beat as the one timing rule; the tick contract written as data; the Coach,
  Try it with a temporary loadout, Build for me and the threat row; the Obsidian and Brick exchanges (Forged Catch left
  out: it adds a guard answer);
- from SYNERGY WEB: synergy nodes that act on the foe's matter as well as an ally's (Kiln Stone, Toxic Gale); the
  ownership rule; the universal matter line and three counter lines per set; per-player zone caps in place of
  cooldowns; one shared rule for the home grounds; three starter loadouts per element; the 3v3 team web; Combo Lab
  cards;
- from the judges: the live `rules.json` classes as the % baseline, variation tags with their own classes, per-body
  overrides, `tier_mult` already 1.0 in the % ring, gates by move id, dormant modes that already dispatch built first,
  and a portable Storm branch.

The judges' fixes: the cooldowns (Shell, Anchor, Cyclone, Mole Run, Wrapping Lash) and the zero-lock follow-ups went;
slot replacement went (only empty slots are filled); guard rewrites and lane or wall-row changes went; matter ticks
skip the hurt path; the knock levers on victims and the sustained Vortex pull went; Tremor Sense and the body coats
(target cues) went; Rally keeps `hold_drop_s` 0 (owner answer 6b); fire's two sets became one set plus the Storm
branch; Hover stays out of the ring.

### The review round (2026-10-09)

An adversarial critic then checked the draft against the owner's answers, the code and the data
(`artifacts/skill_tree_page/critic_findings.json`: 21 issues, 10 major, and 15 missing items). Each was checked against
the sources before acting.

| # | Finding | Verdict | What changed |
|---|---|---|---|
| 1 | Moves cut in round 2 came back unannounced (major) | Applied, one point corrected | Stream and Double Jab left out; Shell, Ramp, Bubble, Jet, Shatter and Clean Burn held (question 3); the kind renamed Twist; the cut history in section 1. Corrected: the owner's own words in answer 4 were "Keep them all" about the Fireball, Embers and Breath; that the other fire cuts stand is the answers file's note under it, backed by answer 5, not a separate re-confirmation in his words. |
| 2 | The same-answer gate gave opposite verdicts on matching cases (major) | Applied | The identity test on every node (3.3): volleys, dashes that hit and Reel held (question 4); Aftershock became Heave; Magma Fist flies straight; Slingshot dropped. |
| 3 | The fixed skeleton's promises broken (major) | Applied | (a) Slingshot dropped. (b) Mud Mound is low terrain and Ice Sheet hardens an ally's Ice Wall: nothing but key 4 makes walls. (c) World rules act only on matter a pick makes: Live Water is Forked Lightning's own rule, wind moves only gas, dust and snow (checked: no wind or lightning handling of clouds or water exists today). (d) The string re-check is a gate with its node list; `lead_combos.py` is not on disk or in git, so it is recorded as not run. |
| 4 | Guard trades target numbers the % ring ignores (major) | Applied | Confirmed in `ring_rules.gd` (`guard_outcome` and the late hit) and `SwayCaster`'s held guard. Every guard node trades in stock terms per wearer (3.7); a % ring test per guard node. |
| 5 | Self-protecting zones can be kept up with no gap (major) | Applied | Life no longer than the lock, no lock while it stands, pops after 2 hits (Shell, Bubble); Dust Cloud placed 2-6 m; a shielded-or-unseen soak metric capped at 20%; the Clean Burn bot-stall claim dropped. |
| 6 | Several ring nodes give nothing up (major) | Applied | Every synergy and new skill states a trade; nodes and loadouts gated at 0.47-0.53 against Classic, each other and same-cost picks; Cauterize's 2% is never taken back. |
| 7 | Opposite pulls not excluded; the Forge starter wore one (major) | Applied | Excludes computed from `changes[]` (20 pairs, covering all eight of the critic's that still exist); Forge rebuilt; the loader recomputes them. |
| 8 | Ice Sheet needs a travelling Wave; Frostwind needs water (major) | Applied in part, one claim rejected | Confirmed: the Wave is one area check at cast time (`BendEffects.cone`). Ice Sheet re-anchored on an ally's Ice Wall; Ride the Wave reworded as a lunge. Rejected: "air vs earth, fire or air has no water". Every deck has grates over water on its zone lines (`ring_arena.gd`), and only the set's entry needed water (Hail Ball, Frost Gust, Rime Wall and Blizzard never did). The entry now freezes grates too; question 1 asks whether air should make its own frost. |
| 9 | Air is thinner (major) | Applied | Wind Guard: Drift Guard rewritten, Eye of the Gale (twist), Rebound (technique); Palm: Shoving Palm; Patch: Second Wind; Slice: Tailwind; Gust: Rising Gust; the Squall starter wears Rebound in place of Carrying Wind, which needs earth's stones. |
| 10 | Too much to learn; hidden rules (major) | Applied in part | Shear dropped; the Beat widened to 0.2 s; world rules limited to matter a pick makes; stock names renamed; range-for-width swaps moved to the open world (ring enhances 39 to 29). Not cut to 3-4 enhances per element: the guard, Palm and heal nodes asked for in finding 9 are enhances too, and each one left is a change you can feel. |
| 11 | Class-only trades in the Zones ring and open world (minor) | Applied | The Zones ring plays Classic; the open world reads class changes as spec ratios (3.8). |
| 12 | Effect picks the FX map already rejected (minor) | Applied | Moved to the reviewed "better" picks (also 110, 264, 732, 733 and 154 in the same roles); each set's visual gaps authored in its own build step (7). |
| 13 | Recovery nodes against the Hover rule (minor) | Applied in part, one claim rejected | One rule (5): Lifting Down Gust dropped, Ride the Updraft became Peak Wind. Rejected: Featherfall cannot lengthen recovery in the % ring, which has no Leap glide, so its plus did nothing there (it is open world only for that); Ramp, Ride the Updraft and Ride the Wave are deck-only moves (key 3 in the air is the air dodge). |
| 14 | The two design docs disagree (minor) | Owner question 15 | Recorded; weapons out while on hold; a style's signature and guard reward count against the twist and technique limits; the styles doc not edited. |
| 15 | Lock-in order favours the winner (minor) | Applied | Game 1 blind; then the winner locks first and the loser counter-picks. |
| 16 | Small contradictions (minor) | Applied | Hot Hands a technique; Carry the Edge's loop worded honestly; Cleanse and Cauterize clear gas round you (no gas on bodies); Reel's look stays on the caster; Storm portability reworded; the HUD example names a twist; `reaction/live` gets `no_hurt`; dates aligned. |
| 17 | Names that collide or misattribute (minor) | Applied | Twist and Technique; home grounds are passives; Crescent Burn and Curved Curtain; Surge and Squall; inventions captioned "proposed, building on the owner's ...". |
| 18 | `+name` tags break exact-match consumers (minor) | Applied | One shared lookup strips `+name` for every consumer, with a test (3.7, build step 2). |
| 19 | Some control schemes can't reach new moves (minor) | Applied | Access per scheme, unreachable nodes greyed (3.9). |
| 20 | Skill-set rules stated as decided (minor) | Applied | Marked proposals; question 2 asks the loadout shape. |
| 21 | Data model: anchors misfile what nodes modify (minor) | Applied | `applies_to` on passives, sets and synergies (`extends_move` stays a real move id, as an anchor); per-body modes for the new modes and Cauterize. |

The missing items: open-world PvP (question 13 and section 4); air's depth (finding 9); the heal key (Second Wind for
air beside Wellspring, Cauterize and Reinforce; earth's Patch and water's Mend stay plain); thin moves (each element's
"left plain on purpose" line in section 7); the % ring's Rise, air hits, Pop and edge attacks (section 11); control
schemes (3.9); the Zones ring (3.8); the lock-in order (5); the string re-check and the bots' tags (5, 3.7); bots
casting the new skills (5); terrain ownership (3.7); colour-blind and audio readability (10); styles against nodes on
one move (5, question 15); the unasked owner questions (2, 3, 4, 5, 8); ranks under free_use (4).

Sources read:

- docs/bending_design.md (round 2 kits, the guard table, the counter web, walls only on key 4, the % ring, true strings, recovery reach, round 4)
- docs/tidebreak/r2_skills_owner_answers.md (answers 1-5, 2026-10-05) and r2_skills_owner_summary.md ('What got cut')
- data/sway/moves.json (elements, jabs, guards, passives, guard_rules, air_rules.guard, mastery, every move's bend specs)
- data/ring/rules.json (stock.classes, guard_perfect_s, guard_catch_s, late_mult, rally, return_mult, return_base_tag, range.exempt, patch, rooted_base, carried_mult, _max_walls, max_walls, wall_moves)
- scripts/bending/bending.gd (keys, other_move, passive, rules)
- scripts/sway/sway_caster.gd (tier, tier_mult, grant, took_hit, _on_hurt, hit_setback; the held guard up to guard.hold_max_s; key3_press: key 3 in the air is the air dodge)
- scripts/ring/ring_rules.gd (guard_outcome reads stock guard_perfect_s and guard_catch_s, the late hit stock late_mult: never a guard spec's window_s or late_mult; no_flinch)
- scripts/bending/bend_r3.gd (deliver), bend_zone.gd (zones, on_bolt, the wind wall pushes bodies and light bolts, never clouds), bend_effects.gd (cone: one area check at cast time; dash: Leap's glide off in the % ring; slam: Down Gust's self-lift; shell, brace, ramp, ice_wall), bend_bolt.gd (wear, meet), bend_status.gd (root, slow)
- scripts/ring/ring_arena.gd (grates over water on every zone line), data/bending/schemes.json (First moves only, Direction, the Wheel, Basic's Keys routing)
- data/bending/poses.json (clips for dormant modes), data/npc/bend_ai.json (pct.strings)
- artifacts/spellbreak_fx/specs/index.json, bending_fx_map.json (reviewer_rejections), captures/sweep_summary.json
- docs/fighting_styles_design.md (it puts style and weapon on the ring budget, each a branch of this tree: open question 15)
- artifacts/skill_tree_page/critic_findings.json (the adversarial review this revision answers)
