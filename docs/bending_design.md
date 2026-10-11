# Bending: the spells (design, v5: round 2 of the skills)

The owner's direction (2026-10-04): an Avatar-style elemental game; a 1v1 that becomes a pro-bending match. Each player is one
element; everyone of that element has the same moves. Round 2 of the skills (2026-10-05: "bring back the kick make it easy to
use and correct to adjust and etc... make the skills easy hard to master for skills and etc think human made think avg IQ";
the spec and the owner's answers: the improvement loop's skills_r2/spec.md and owner_answers.md) gave every element the same
buttons, one job each, and cut the "two skills x three variations" layer. The kits' data lives in `data/sway/moves.json`
(`elements`, `jabs`, `guards`, `passives`, `guard_rules`); what the player reads about them in `data/ring/screens.json` "kit"
(KitWords).

## Controls (round 2; the owner, 2026-10-04: "left click and right click are the same no fast or slow its all the same just
## different skills"; 2026-10-05: "the user needs to be able to put hot spells on left click ... this action can be right after")

| Button | Role (the strip's word) | For every element |
|---|---|---|
| **LMB** | **JAB** | the close poke (10 m or less): the shortest lock, a little knockback. **Q** puts the readied move on LMB instead; holding Q 0.5 s brings the jab back. The chip always says what the next Q does ("Q: put Spike on left click", "hold Q: Pebbles back"). |
| **E** (and the fourth mouse button; `bend_guard`) | **GUARD** | the element's timed guard, no readying. Tap it, or hold to raise and let go to stand it. E again while you hold a stone you caught throws it back. |
| **1** | **STRIKE** | your shot: a tap readies the quick one, a tap twice the big one. Fire's grows too (▲): Punch held past the second click becomes the Fireball. |
| **2** | **PUSH ▲** | your body move; it **grows** if you keep holding (a second, deeper click at 0.45 s; it goes by itself at 1.0 s). Tap twice: up or in (Column, Geyser, High Kick, Pull). |
| **3** | **DASH** | the way you hold W/A/S/D (nothing held: back); tap twice: your element's way of travelling, where you look. |
| **4** | **WALL** | your wall, raised 2-6 m where you aim, facing you (fire's tap twice: Breath). |
| **5** | **HEAL** | Patch; earth and water tap twice: Mend one of your own walls. |
| **Space** | | jump, even while you hold a cast (the lock keeps filling). |

- **How it came to this.** v4 had 4 keys x 2 skills x 3 variations (the owner, 2026-10-04: "have 1 and the user can toggle
  between the 1s and then roll the wheel to change that spell to make it easy"); after playing (2026-10-05): "still difficult
  for a human to switch spells, there's a lot of things going on", hence the schemes, then round 2's one-job buttons. The
  owner's answers to round 2: "one is good but dont forget the other elements" (one guard key, every element's guard with the
  same care as earth's catch); fire keeps the Fireball, Embers and Breath ("Keep them all").
- **No memory.** A tap readies the key's first move, a tap twice within 0.3 s its second; 1 is always Spike, 4 always your
  wall, E always your guard. The mouse wheel steps between a key's two moves, nothing more.
- **The click buffer.** A click (pressed and let go within 0.2 s) casts the move as soon as its lock is full, aimed where you
  look then. A hold fills the lock and casts on the let go; let go before the click and it is called off, nothing spent (the
  feint). While you hold, the aim steers the cast and the body turns with it; a tap of the same key switches to its other move
  with the time kept (the new pose shows 0.2 s at least); another key starts over; E drops the lock and guards at once.
- **▲ grow** on key 2's first move for every element (Shove a bigger stone, Wave farther, the Kick wider and longer, Gust wider
  and stronger) and on fire's 1 (the Fireball). Other moves sputter from 0.7 s held and fizzle at 1.0 s.
- **A hit sets a lock back**, it never wipes it: back by what the hitter's move cost him (0.25 s at least). Dashes and guards
  are never set back; Lightning's charge breaks on any hit. Lock time is the only spam limiter.
- **One passive each**, told in one line at the element pick: earth **Rooted** (stand still: locks fill faster, pushed less),
  water **Flowing** (your water curves toward where you look just after it leaves), fire **Footwork** (locks fill at full speed
  on the move), air **Carried wind** (hit straight out of a dash and you knock harder).
- **Control schemes** (`data/bending/schemes.json`; the player only, bots never): **Keys** is the default. The others sit under
  **Controls › Other ways to pick moves** (the main menu's Tidebreak and Practice panels, the ring's and the duel's Esc menus;
  no four-way choice before a match): **First moves only** (1-4 their first moves, no tap twice), **Direction** (the key held as
  RMB is pressed: W key 1's first move, S your wall, A/D key 3's first move; kept for the lock, laid out for swipes later) and
  the **Wheel** (hold Tab: the key moves plus Patch and Mend round the screen, earth and water 9, air 8, fire 9 with Breath;
  point and let go). The JAB and GUARD chips and the rules are the same under all of them.
- **What the player reads** (BendStrip; the owner: "those big cards are terrible", no target cues of any kind): seven chips at
  the bottom, `LMB · JAB  E · GUARD  1 · STRIKE  2 · PUSH ▲  3 · DASH  4 · WALL  5 · HEAL`, under each the readied move's plain
  name and "tap twice: Boulder"; in the player's first match each "tap twice" line fades in once that key has been cast twice.
  One help line under them. Holding a caught stone the GUARD chip says "E again: throw it back" (his own strip only).

## The kits (spec §3; numbers are starting values, the soak retunes them, never the identities)

### Earth: rooted, heavy, catch-and-return

| Button | Move | What it does |
|---|---|---|
| LMB | **Pebbles** | 3 flicked stones, 10 m |
| 1 | **Spike** · tap twice **Boulder** | the stone rises at 60% of the lock and hangs, its point on the crosshair; let go: it lances (pierces). The Boulder (the owner's "left kick, stamp, push") arcs, lands and rolls along the floor |
| 2 ▲ | **Shove** · tap twice **Column** | Shove throws the stone you hold, else the loose stone or wall chunk on the crosshair (6 m of you), else kicks one up and pushes it in one go; ▲ a bigger stone. Column: a pillar rises where you aim, low and weak, peaking 0.35 s later, and sinks 1.5 s after |
| 3 | **Burrow** · tap twice **Lift** | into the deck and up the way you hold (stones pass over you 0.3 s); Lift throws you up and forward |
| 4 | **Wall** | 3x2 m, 2-6 m where you aim; tear chunks from it |
| E | **Catch** | stones are always caught and held (a late catch is a full catch, no slide); E again throws it back: 0.35 s, or 0.1 s and x1.2 after a clean catch; every return of the same stone faster (to x1.6) |
| 5 | **Patch** · tap twice **Mend** | |

### Water: flowing, redirecting, pools

| Button | Move | What it does |
|---|---|---|
| LMB | **Splash** | a small bolt, 10 m |
| 1 | **Lash** · tap twice **Spear** | a long lash, 16 m (steered by Flowing); the Spear a heavy point-first ice throw |
| 2 ▲ | **Wave** · tap twice **Geyser** | today's cone (it cannot be jumped; ▲ 12 m, 65°); Geyser rises where you aim, twice as wide from a grate or your own puddle |
| 3 | **Skate** · tap twice **Surf** | a slide the way you hold, leaving puddles; Surf rides a wave where you look |
| 4 | **Ice Wall** | 2-6 m where you aim |
| E | **Turn** | on the beat a water or ice bolt swings once round you and leaves along your aim (x1.2); an Air Lance on the beat wraps round you and leaves as an ice lance along your aim (x1.2); fire on the beat is doused; a Wave on the beat parts round you |
| 5 | **Patch** · tap twice **Mend** | |

The water meter's spending is retired (lock time is the only limit; the pools feed Geyser and Skate); the HUD shows no meter
while `water_meter.spend` is false.

### Fire: aggressive, fast, footwork, kicks and punches

| Button | Move | What it does |
|---|---|---|
| LMB | **Embers** | a short spray of small bolts from the fist |
| 1 ▲ | **Punch** · tap twice **Lightning** | Punch the fast bolt; held past the second click it grows into the **Fireball**. Lightning: a long charge, a 0.25 s flash and crack on your own hand, then it strikes along the aim you let go on |
| 2 ▲ | **Kick** · tap twice **High Kick** | the Kick is **always a wave of fire along the floor** from the kicking foot, toward where you aim; jump it, a wall stops it; ▲ wider and longer. The High Kick is a flame crescent kicked over walls and into jumpers |
| 3 | **Step** · tap twice **Jets** | a hop to the side held, a back-flip with nothing held, a step in on W; Jets fly where you look |
| 4 | **Fire Wall** · tap twice **Breath** | a burning curtain 2-6 m where you aim, 5 s, one at a time; Breath a short cone of fire that leaves smoke (sight blocked for bots; no slow) |
| E | **Parry** | on the beat any fire goes straight back along your aim (x1.2); the only answer to lightning (a perfect Parry); ice on the beat melts |
| 5 | **Patch** | |

### Air: evasive, pushing, momentum

| Button | Move | What it does |
|---|---|---|
| LMB | **Palm** | a 3.5 m cone push, a little knock |
| 1 | **Slice** · tap twice **Wind Ball** | a thin fast blade; the Wind Ball air's big knock |
| 2 ▲ | **Gust** · tap twice **Pull** | a visible wind wave you can grow (▲) and dodge; Pull drags whoever it meets toward you |
| 3 | **Slip** · tap twice **Leap** | a light step the way you hold (a near miss charges Carried wind); a high jump, glide on Space |
| 4 | **Wind Wall** | moving wind 2-6 m where you aim, 4 s, one at a time: light shots blown aside, stone and lightning pass |
| E | **Wind Guard** | on the beat air bounces straight back along your aim (x1.2, Carried wind charged); stone on the beat is dropped at your feet |
| 5 | **Patch** | |

## The guard (E)

A short lock (0.15-0.2 s), then the guard stands for its window. **Perfect**: a hit in its first 0.3 s (a flash, a crack and
"Clean" on your own screen; nothing drawn on him). **Late**: after that, half its damage and knock get through (earth's catch of
stone excepted: always whole). **Whiff**: a guard that took nothing makes your next guard's lock 0.5 s if begun within 1.5 s.
The one line every player learns: *"E: on the beat it's yours. Late, half gets through. Earth always catches stone."*

| Arrives -> / Guard | Stone | Fire | Water / ice | Air | Lightning |
|---|---|---|---|---|---|
| **Earth Catch** (1.0 s, 3.5 m) | always caught and held; perfect = a clean catch (the faster return) | passes | passes | passes | passes |
| **Water Turn** (0.8 s, 2.2 m) | passes | perfect: doused to steam; late: half | perfect: swings round you and back along your aim; a Wave parts; late: half | the Air Lance: perfect, wraps round you and leaves as ice along your aim; late: half; other air passes | passes |
| **Fire Parry** (0.8 s, 2.5 m) | passes | perfect: straight back along your aim; late: half | ice, perfect: melted; water passes | passes | perfect only: sent back |
| **Air Wind Guard** (0.8 s, 2.2 m) | perfect: dropped at your feet; late: half | passes | passes | perfect: bounced back, Carried wind; late: half | passes |

## How moves meet (the counter web)

The second line, at the element pick and in F1: *"Water douses fire, fire melts ice, air drops stone."*

- **Floor, air and under you** (F1 and the first-time panels: "Fire along the floor? Jump. Through the air: dash or guard.
  Rising under you: step off."):

  | How it comes | Which | The answer |
  |---|---|---|
  | along the floor | the Kick's wave, the Boulder's roll | jump (feet more than 0.6 m up are missed); any wall stops it |
  | through the air | bolts, throws, the Wave, the Gust and Pull, the High Kick | dash aside, guard, or a wall |
  | up from under you | Column, Geyser | step off as it starts: low and weak, it peaks 0.35 s later (no mark on the deck) |

- **Attack against attack**: water vs fire makes steam (it hides a man from a bot); fire vs ice melts it (it falls short as a
  puddle); stone vs anything but stone goes on; **stone vs stone: the bigger stone wins** (pebbles < spike and chunk < boulder;
  equal ones both break).
- **Walls**: two each, a third breaks your oldest; only key 4 makes walls; fire and wind walls are short (5 s, 4 s) and stand one
  at a time. Every wall rises 2-6 m where you aim, facing you (nothing painted on the deck: the lock ring at the crosshair is the
  only preview). Column and Lift's pillar are not walls: they rise, throw and sink 1.5 s later. Mend mends your own pieces; a
  mended piece takes its next hit free.

  | Wall | Stops | Weak to | Lets through |
  |---|---|---|---|
  | Earth wall | stone, ice, fire, air | water wears it fast (Lash x3); a Boulder breaks it; Shove tears chunks from it | nothing |
  | Ice wall | water, air | fire melts it fast (a puddle left); a Boulder smashes it | a Spike pierces it |
  | Fire wall | burns whoever passes | water puts it out; air blows through | stone |
  | Wind wall | fire, water, ice, air: blown up and aside, not returned | a wait of 4 s | stone, lightning |
- **Stones on the deck** (earth's ammo, fair for both sides): a raised or held stone belongs to its earth player; a loose stone
  (dropped by a cancel, a set-back lock, a Wind Guard, a wall hit) can be shoved by any earth player within 6 m of himself; three
  loose stones each at most.

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

Round 2 (wave 3, 2026-10-05; animations_extra/Frontier_Bend.res, 39 clips, every one keyed by hand in
tools/anim_author/blender/bend_clips.py on the rig's rest pose, rows in animations/SOURCE.md):
- The first ten (approved) polished: the keys the IK clamped straight pulled back into reach (worst miss now 5 mm), their
  hold_s / strike_s unchanged.
- **The boulder** (stone_form cannonball, `own-bend-earth-boulder`; the owner: "a left kick to stomp and then push"): the
  left foot kicks the rock up, the knee high, the foot stamps ahead, the palms drawn to the ribs (the hold, 0.63 s), a
  two-hand push (the strike, 0.77 s); whole body, the caster rooted.
- **Stances** (poses.json `stance`; idle only): earth a low wide horse stance, fire on the balls of the feet with a bounce,
  water weight flowing forward and back, air light and turning at the waist. The player's plays under the casts while he
  stands in element mode (fades in over 0.35 s, gives way to walking, crouching, climbing, riding); a bot's while it fights
  (not while held: countdown, round over).
- **Cast sets** for every element's moves (poses.json maps each bending move to an own clip); five have left-hand twins: a
  move cast again within 0.6 s plays the twin (right, left, right), bots alternate.

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

## The match's screens, practice and the teams groundwork (wave 4, SCREENS)

- **Round screen** (RoundScreen, over the ring in the pause after a round): who took it and why (into the water, winded in
  the last zone, ground held at the bell, stronger at the bell, level at the bell, a knockout), the score, and the round's
  tally with no replay: your casts, catches (what your guards took) and knock-backs, the other side's under it.
- **Match screen** (MatchScreen, at the match's end): Victory / Defeat / a drawn match, the score, a line per round ("Round 1
  · yours · into the water at 1:12"), the match's tally; Rematch, your element and the opponent (both for the rematch, nothing
  restarts until then), Main menu. The game is not paused under it; the player is held and the mouse is free.
- **Loading tips**: on the way into the ring the loading screen tells one of the sport's rules or answers in a line.
- **Quick match** (`MatchSetup.quick_match()`): your last element and setup, the opponent's element drawn at random; the
  kept setup's opponent is not overwritten. **Practice** (`MatchSetup.set_practice(element, way)`, or the user arg
  `practice=stand|block|throw`): a dummy of the chosen element held at its end that stands, blocks (its element's guards
  every time its lock fits what comes, and its cover when you begin a lock) or throws (its throw every 3 s: earth a stone
  spike, to practise catching and sending it back). No timer, no rounds, the soft walls off; R puts both back at their
  ends, B steps the dummy's way, a fall into the water resets both after 1.6 s. Every word and number in
  data/ring/screens.json. The main menu: **Quick match** (its line `MatchSetup.quick_line()`) plays `quick_match()` at
  once; **Practice** opens a small panel (your element, the dummy's element, what it does, the control scheme; Begin
  practice: `set_practice()`); the Tidebreak panel's Begin calls `set_match()` first.
- **Teams (3 v 3 groundwork)**: RingRules marks each competitor's side (BendCaster.TEAM_META); BendStatus never lets a bend
  reach the caster's allies, an ally's bolt flies through them, and an ally's guard lets it through (a teammate's shield
  never sends a teammate's bolt back, and still takes the other side's). With more than one a side: advance only once every
  opponent still in is pushed back, a competitor rung out sits the round out, the whole side out in one round is a
  knockout that ends the match at once. Not yet: spawning three a side, team bots' coordination, team HUD.

## Throws, the bots' answers and the balance (wave 3, PLAY)

- **Throw-style moves** (BendThrow, spec `do: "throw"`): a BendBolt launched on the arc that lands it on the aim
  (Weapon.ballistic_dir), the strike deferral the only wait. Flights: `point_first` (the ice spear), `spinning` (the stone
  disc flat like a side-arm throw), `flick` (pebbles, each tumbling).
  The stone spike stays on the GustLift throw, so earth's catch-and-send-back is untouched. Round 2 (the owner, 2026-10-05:
  "bring back the kick"): the flame wheel is gone; fire's **Kick** is restored as the wave of fire along the floor (`fire_kick`
  kick, `do: floor_wave`: jump it, walls stop it, ▲ wider and longer, its line the crosshair's direction while held, the knee
  chambered low on our own low kick clip) and the **High Kick** is its tap twice, a flame crescent over walls and into jumpers
  (`do: throw`, shape crescent, the waist-high kick clip).
- **The bots' reaction layer** (NpcBending; data/npc/bend_ai.json): an opening grace from the round's start
  (`grace_s`: easy 3, normal 2, hard 1.2) with no attack and nothing that knocks; a caught stone shoved straight back; the
  opponent's wind-up read as a threat (his lock on a throw or a bolt raises the guard before it lands); one guard cooldown
  (`guard_cool_s` 1.2) and a per-element `react` share; Gust lift cast on stones only.
- **Clouds and dazzle**: water meeting fire leaves steam (BendZone `steam`, 2.2 m, 1.5 s) that hides a man from a bot; the
  flare's `dazzle_s` 2 doubles a bot's scatter and reaction time; smoke hides the player from a bot. A zone ends when its
  caster is freed.
- **Balance, by data** (rules.json knock_scale 0.7, element_factor air 0.65 / water 1.25, and the moves' damage, knock and
  lock numbers): bot against bot at time scale 1 (16 pairings x 3 seeds, 122 rounds) ends 0.58 of the rounds by ring-out;
  no move above 0.17 of its element's casts; earth caught 85 stones. Cross-element wins are still uneven (air 15/18, fire
  10/18, water 6/18, earth 5/18). Walls capped at 2 per caster: bots reached the cap once in 48 matches.
- **The soak** (tests/ring/test_ring_soak.gd): one pairing a run, a bot of the player's element fighting in his place,
  METRIC lines for the ring-outs, casts, catches, answers and walls. Known: BendStatus.now() counts physics frames, so at
  Engine.time_scale 4 its timers last 4x longer in game time.

## The ring's dress and the arena kit (wave 3, ASSETS)

Our own, in the spirit of the inspiration and copying none of its characters, outfits, emblems or symbols: 15 cloth2
garments (catalog set `ring`, tools/asset_author/build_ring_garments.py and ring_garments/), one dress per element for
both bodies (earth an ochre wrap tunic with moss bands and wrapped shins; water a hooded blue pull-over parka with fur
trim and fur-topped boots; fire a red sleeveless top with a high gold collar, shoulder caps and wrist guards; air a
marigold knee-length tunic with wide sleeves and tangerine wide trousers), put on the bots (NpcSquad.element_look) and the
player (PlayerAppearance.ring_dress) from data/npc/factions.json. The arena kit (assets/ring_kit,
tools/asset_author/blender/ring_kit.py): gateways over the tunnels, lacquered pillars, curved roofs with upturned eaves,
paper lanterns, tile canopies, and four simple glyphs of our own (a mountain, a drop over ripples, three embers, three wind
strokes); merged into the dressing's mesh (no new draw calls).

## Improvement round 1 (2026-10-05: PERF, BALANCE, SOUND, LEARN)

- **The load and the restarts** (PERF): behind the loading screen the ring is built a part a frame (RingLevel._build: the
  sky, the deck, the stands, the light, the competitors, the crowd, the match, the elements), each part's files read on
  worker threads first (data/ring/prefetch.json, tools/perf/ring_prefetch_list.py; not the ring's own sounds: with their 18 MB
  read alongside, the player's frame measured 1.2-1.4 s in three runs (0.6-0.67 s in four of five without; a Mac hot from a
  test batch swings it too), so BendSounds.warm() reads them in the crowd's frame, ~0.1 s) and
  drawn through a camera where the player's will stand, so each part's shaders compile on its own frame; the loading
  screen's bar glides to the build's progress with a line saying what is being built. Longest frame after the loading
  screen shows 2.1 s -> 0.55-0.6 s (warm shader cache; 7.5 s -> 2.9 s on a first launch), the rest the player's own build
  (FrontierPlayer._ready). One bot the match long: RingMode._keep_foe / _ready_foe make last round's whole at its new end
  with a new mind (a new one only when hurt past whole or a rematch asks for another element or difficulty); a restart
  14-34 ms at medium (was 36-46 ms plus the new bot's first draw). tests/perf/test_ring_hitches.gd measures both.
- **The balance** (BALANCE; scratchpad review r1_balance_before/after): air had won on the deck's socket cannonballs it
  lifted (about 110 a strike) and on its guard rolling once a bolt. Now one roll a volley (NpcBending.VOLLEY_S); any option
  whose hint `answers` is a guard (Earth Grip anchor, Footwork hop, Water Shield's ice wall; min_knock, guard_when, a dash
  only inside the ropes); held stones and tornadoes read as threats; air lifts back a stone its cushion stopped. Numbers:
  Stone Form lock 1.1 s (bot ai_factor 1.15), bubble lock 0.45 s, heal 35, whip knock 8, wave push lock 0.6 s, slice 10,
  tornado 2.2 s, element_factor air 0.6 / water 1.5, hard aim 1.3 deg and 0.9 lead. tests/ring/test_balance.gd (12
  cross-element pairings): every element 0.46-0.54 of its rounds (air was 0.84). Earth's catch per stone unchanged.
- **The sounds** (SOUND): the ring's own, synthesized (tools/sfx/bend/, audio/sfx/bend/: 38 ids, 142 variants; nothing
  recorded or downloaded) and played by BendSounds (a voice pool, per-id caps, its own dice; warm() loads them behind the
  loading screen); a cast's sound from the move being cast, a catch and a fall into the pool told by where they land; the
  crowd's murmur at the stands, its level the mood, cheers, gasps, a roar and a groan on a ring-out. The ring's stings
  (count, go, bell) borrowed frontier sounds until round 2 (now the gong, bell and tick: BendSounds).
- **Learning** (LEARN): Practice's Lessons row (RingLessons, LessonCard, data/ring/lessons.json): 11 cards (9 under
  simple), each done by doing it, keys from the bindings now, per scheme and element; Enter skips; the place kept in
  GameSettings' lessons section. A first Quick match's key hints top left (FirstHints; the ring's Esc row turns them on
  and off). Screen overlays only: nothing on the dummy, nothing on the deck.

## Improvement round 2: what the player reads (HUD_LESSONS, 2026-10-05)

- **The strip** (BendStrip, KitWords): the seven chips above under every scheme and element, one help line in place of three
  (the ready line, the quick spell's and the scheme's lines folded into the lit chip, the JAB chip and that line). The water
  bar shows only while the water is spent. Nothing on or about the opponent.
- **F1 and the first-time panels** (FrontierHUD.ARENA_HELP / ARENA_KEYS, HowTo): per scheme, the four rules: "Click: it goes
  when ready. Hold: aim while it fills, let go to cast; let go early to call it off. Hold 2 longer: ▲ it grows.", the guard's
  line, the counter line and the floor and air line. The Q line never reads "no key bound" (the keys as bound, "(no key)").
  A first Quick match's key hints (FirstHints) **replace** the ring's first-time panel (the owner's answer to round 1): as they
  come up the panel's ring topics count as seen and the one up goes.
- **The element pick** (the Tidebreak and Practice panels, the ring's and the duel's Esc menus): the passive in one line, what
  the guard does, and the buttons by their plain names ("1   STRIKE ▲   Punch  ·  hold to grow it: Fireball  ·  tap twice:
  Lightning").
- **Loading**: the ring has its own still (assets/ui/loading/ring_still.jpg: the dressed ring at golden light, both competitors
  in their dress, rendered by tools/ring/ring_still.gd) with Tidebreak's title and captions (screens.json "loading"), not the open
  world's paintings and lore; the tips tell round 2's rules ("The Kick runs along the floor: jump it.", "Catch just before it
  hits: your throw back is faster.", "A hit on the beat is yours.", "A click goes when ready; let go of a hold early and nothing
  is spent.", "Two walls each.").
- **The stings** are the ring's own now (rules.json stings, BendSounds): the countdown's tick, the gong at the go, the bell at a
  round's end, the match's gong.
- **The lessons** (RingLessons, data/ring/lessons.json; Enter skips): move, jab, strike, push ▲, dash, wall, then the guard drill
  against the practice dummy on E (earth: catch and throw back with E again; water Turn, fire Parry, air Wind Guard on the
  beat; the dummy is the player's own element, so each guard meets its own strike), "Fire along the floor? Jump." (a fire
  player's dummy kicks the floor wave), the quick spell, heal, the zones and the water. Through the drill and the jump the
  dummy throws slowly (a throw each 5 s, its shots at 0.6 of their speed on the same path; the owner's answer to round 1).

## Improvement round 2: the merge and its gate (2026-10-05)

CLIPS, CORE, KITS and HUD_LESSONS merged in that order on worktree-spellcraft, then made to fit:

- **The open world keeps its Form spells.** moves.json's `modes` are the ring's kits; where the open world shares a spell and
  offers more (Stone Form's disc, the earth wall's column and shell, the pillar's free and ramp) it keeps them in
  `world_modes` / `world_mode_labels` (SwayCaster.world_modes_of: a caster without an element reads those), with their
  reaches and the pillar's footfall boost (the ring's Lift reads its own sink_s and run_mult).
- **One source for the kit.** The HUD's words (KitWords) and the bots (NpcBending) read the jab, the guard and the shared rules
  from Bending, as the player's caster does; the guard's action is InputSetup's (E and mouse button 4).
- **Bots as the player.** A hit sets a bot's lock back by what the blow cost (BendStatus' HIT_LOCK_META), as the player's; a
  blind bot (out of sight, or a smoke or a steam on the line) steps out to the side instead of standing behind its own wall.
- **The guard drill is the guard.** The lessons' water, fire and air drills are done only on the beat (a perfect guard, CORE's
  guarded signal), earth's by a stone caught and thrown back; the player's own walls come down as a drill against the
  dummy's throws begins; the earth dummy's spike is slowed with the rest. tests/ring/test_practice_guards.gd drives each
  element's guard on E against its practice dummy (perfect, late, whiff, earth's throw back).
- **A blind bot goes on.** Out of sight, a bot goes on toward where it saw the player last, out to its strafe side (the
  first gate capped that at 2 m on, and the earth bot never came back into its jab's reach: tests/npc/test_bend_bots.gd's
  earth cast 4 kinds of move in 40 s, 6 now).
- The gate (after a reboot emptied the scratchpad, gate R2 was run again whole: 80 rows): every round-2, round-1 and wave
  row green but the known reds (test_hud_skills 1/33, test_hud_vitals 2/16) and tests/npc/test_duel.gd, the open world's
  musket duel, red at the round-1 head too: one check of its marine's cover search fails or passes as unrelated code
  moves (the flank check at 0582fa5, green at 8e359b7, the hidden-player check since: the marine's seek finds no cover to
  flank or advance to and waits on, NpcSkirmish's "nowhere better to go"). A farther seek made that check pass and broke
  the flank check, so it is left for the open world's duel work. test_ring_hud clears what the held bot had sent before
  its body checks (the bot that goes on reached the player first in 3 of 5 runs).
- Open for the owner: Breath's smoke (5 s from a 0.5 s lock) can keep a bot from ever attacking; the bots' timers run on
  BendStatus' frame clock (slow under a time scale); the KITS soak's mirrors went to side 0 every time.

## The % ring (round 3, 2026-10-05/06: the Smash layer; smash_r3/spec.md v2)

The owner, word for word: *"instead of a knock back we should implement a smash bros 100% plus like arena out system we should
give everyone all movement options and in air options and combos"*. He then chose: **keep the number keys**, **3 lives** with
the % back to 0 after each fall, and **full recovery** (double jump, air dodge, an up-recovery per element, grabbing the
deck's edge; out only in the water). His answers on 2026-10-05 (smash_r3/owner_answers.md): hitstun **yes, as built**; the
camera **turns toward the deck** when you are thrown off facing away with the mouse still; stale moves **yes**; **one air-only
close hit per element: yes** (left click in the air); the arena change **as built**.

Everything here runs only under the stock rules (`RingRules.stock_on()`, rules.json `rule_set` "stock"; the Esc menu's Rules
row reads **Lives** / **Zones**). The open world, the duel and the classic zones ring are unchanged, and a test pins that.

### The rules in one paragraph

Every hit adds **%** instead of taking health. The higher your %, the farther and longer the next hit throws you: **v = W ×
(base + growth × R × A × p/100 × (0.5 + d/20)) m/s** (p your % after the hit, d the hit's %, W your weight, R the range falloff
1.0 to 10 m → 0.65 at 22 m, A 0.85 for a launch released in the air). You are out only when you touch the water (6 m below
the deck; the tank's curtain 10 m out). Three lives; a game is 8:00; level lives at the bell: sudden death at 300%. Hitstun is
clamp(0.045 × v, 0.12, 1.2) s, escapable from 0.6 s by a fresh Space or 3; your aim, camera and lock are never touched by a hit
(the lock freezes and resumes). Steering: hold left or right 0.1 s after the hit, up to 15° of yaw. Breaking your fall: E within
0.25 s before you meet the deck. Strings decay ×0.8 a hit (the Pop exempt), the 6th hit frees you, a 0.4 s breather after a
4-hit string. Stale moves: −8% d a copy among your last 6 hits, at most −40%. Patch takes back only fresh damage (the last 6 s,
at most 10%). The respawn is a water spout, safe until 1.5 s after you leave it or your first lock.

### The keys (spec §0)

**The numbers ready a move and right click casts it; left click, E, 3 and Space act at once.**

| Idea | Input |
|---|---|
| Ready a move | 1, 2, 4, 5 (tap: the first, twice: the second); 1 is ready at the start and after every fall |
| Cast | right click: hold to aim while it fills, let go to cast |
| Jab | left click; in the air, your element's close air hit |
| Guard (shield) | E: on the beat it's yours, late half gets through; held, up to 2.5 s |
| Dash, dodge | 3: a dash on the deck, an instant dodge in the air (once per airtime) |
| Jump | Space; again in the air (double jump); off the deck once more: your **Rise** |
| Down | C: crouch, fast fall, no edge grab, let go of the edge |
| Roll, duck | guard up + tap a direction: roll; guard up + C: duck |
| Edge | fall near the lip and you grab it: any direction key climbs, Space jumps, E rolls in, a click attacks, C lets go |

### Every move's class (spec §2.3, lead_table.py v2; the end figure is the KO % from the deck's middle toward an end)

| Move | d % | base | growth | angle | KO end |
|---|---|---|---|---|---|
| Pebbles / Splash / Embers / Palm (jabs, set) | 5 / 4 / 4 / 3 | set 3.0 / 3.5 / 1.5 / 4.5 | | 10, 10, 5, 10 | never |
| The Pop (the 3rd jab that hits) | 3 | set 9.0 | | 80 | never |
| Spike | 14 | 5.8 | 12.2 | 30 | 159% |
| Lash | 10 | 4.6 | 11.6 | 25 | 210% |
| Punch | 11 | 4.0 | 10.3 | 25 | 231% |
| Slice | 6 | 3.4 | 14.5 | 25 | 220% |
| Boulder | 22 | 8.0 | 12.1 | 35 | 115% |
| Spear | 16 | 5.2 | 12.2 | 25 | 150% |
| Fireball (Punch grown) | 18 | 5.8 | 12.4 | 30 | 134% |
| Lightning | 25 | 6.9 | 12.1 | 30 | 105% |
| Wind Ball | 7 | 8.0 | 18.7 | 35 | 140% |
| Shove / Shove ▲ | 12 / 16 | 6.9 / 8.0 | 12.6 / 13.6 | 30 | 160% / 120% |
| Wave / Wave ▲ | 9 / 12 | 8.0 / 9.2 | 13.5 / 14.5 | 30 | 165% / 125% |
| Kick / Kick ▲ | 12 / 16 | 5.8 / 6.9 | 12.7 / 14.0 | 40 | 190% / 140% |
| Gust / Gust ▲ | 5 / 7 | 7.5 / 8.6 | 16.5 / 19.3 | 30 | 175% / 125% |
| Column, Geyser, High Kick (launchers) | 11 / 11 / 10 | 10.3 / 10.9 / 6.9 | 5 / 5 / 8 | 85 / 85 / 65 | never |
| A caught stone thrown back (×1.2; the rally to ×1.6) | 16.8 | 5.8 | 14.6 | 30 | 119% (74% at ×1.6) |
| The Pop's stone (earth, E) | 14 | 5.8 | 12.2 | 30 | 159% |

Weights: earth 1.25 (W 0.89), water 1.0, fire 0.95 (W 1.03), air 0.8 (W 1.11).

### Movement and the edge (spec §4-§5; data/ring/movement.json, MOVE's)

Gravity 20 for everyone; run 5.0 m/s; a jump 2.0 m (Space is always a full jump; a short hop is Space within 0.05 s of letting
go of a cast); the double jump 1.6 m (earth 1.4, air 1.9), keeping half the launch's carry; the air dodge 3.2 m in 0.22 s;
fast fall −17 m/s. The grab box: the head from 0.3 m inside to 0.9 m out, lip −0.5 to +0.6 m; three grabs, then the deck;
0.6 s intangible on a first grab, 4 s at most. The Rise: earth's **Pillar** (5.5 m, leaning 20° to the lip), water's
**Fountain** (4.5 m), fire's **Jet** (7.5 m along the aim, at least 20° up), air's **Updraft** (3.5 m, then a glide). Recovery
reach: earth 11.3 m, water 11.8, fire 15.8, air 17.4.

### True strings (spec §6.6, lead_combos.py v2; the bots' string table, bend_ai.json pct.strings)

The accident string for everyone: **jab, jab, Pop, then the String card's follow-up**, true at every %: earth the Pop's stone
thrown with E (or a Shove of a held stone), water Lash, fire Punch, air Slice or Gust. True from 0%: Column → Pebbles, Geyser
→ Lash or Spear, Kick → Punch, High Kick → Punch, Embers → Punch, Pull → Palm, Gust → Slice. Reads, not strings: Column →
Spike, Lash → Spear or Wave, Wind Ball → Gust, anything after the Pop but the card's follow-up.

### The bots in the % ring (BOTS; scripts/npc/npc_ring_mind.gd, data/npc/bend_ai.json "pct")

A bot moves only through the same intent as the player's keys (NpcPad, read by MOVE's RingMoves), so it has exactly his jumps,
dodges, Rise, edge options and gravity, and it never writes its own velocity (a test pins it). Its mind picks a state each tick
(NEUTRAL, PRESSURE, EDGEGUARD, LEDGETRAP, REELING, RECOVER, LEDGE, RESPAWN); round 2's chooser picks casts only in NEUTRAL and
PRESSURE, its options weighed by the KO read (the rules' own launch flown by RingPredict). It reads only %, lives, positions,
poses and visible wind-ups, never inputs.

| | Easy | Normal | Hard |
|---|---|---|---|
| KO read / bonus / margin | never / ×1.0 | yes / ×2.0 / 1.5 m | his best steering / ×3.5 / 0.5 m |
| Finisher from past 15 m | ×0.6 (it walks in) | ×0.6 | ×0.6; a fresh finisher kept (×0.5 on a KO move staled twice under 80%) |
| Strings: chance / most hits / a read to end | 0.25 / 2 / 0 | 0.55 / 3 / 0.3 | 0.85 / 4 / 0.5 |
| Steering: chance / the right way | 0 | 0.5 / 0.7 | 0.9 / 0.95 |
| Break out at 0.6 s / break the fall | 0 / 0 | 0.5 / 0.3 | 0.8 / 0.7 |
| Recovery: plans / Rise aim error / late margin / air dodge | 3, 4, 2 / 15° / 0 / never | 2, 4, 6 / 4° / 0.25 s / foe within 4 m | 2, 4 or 5, 6 / 0° / 0.1 s / a seen threat |
| On the edge | climbs after 0.6 s | climb 0.4, jump 0.3, roll 0.2, attack 0.1 after 0.2-1.0 s | reads the foe; counts your favourite option |
| Keeping him off | waits mid-deck | 0.5: shots from inside the lip | 0.85: shots, a pre-filled lock let go as his safety ends, a safe-only chase |
| The spout | leaves after 0.5 s | after 1.0 s | the full time with you under it, else at once |
| Air scatter / lead | ×2.0 / 0.2 | ×1.5 / 0.5 | ×1.2 / 0.8 |
| Its own % above 120 | | reaction +0.15 s, 3 m further from its end | reaction +0.15 s, 6 m further |

Every string follow-up begins only while `RingRules.hitstun_left(foe) ≥ lock + flight − 1/60` (true strings only); no bot ever
lets a hit go into a safety (its full lock is held, then called off); Patch only with 6% or more of fresh damage, standing, the
foe 12 m away and not winding up at it. Recovery runs six plans through the mover's look-ahead every 0.1 s toward the nearest
open lip and never grabs a 4th time without the deck.

### Practice and lessons in the % ring

Practice's rows (Esc menu, and the main menu's Practice panel): its % and yours (0 to 200, or grows), the dummy's way on B
(stand, walk, jump, guard on the beat / held / after a hit, recover, throw, fight), its steering (none, in, out, random), Throw
me off (R puts you off an end), speed 1, ½, ¼, fresh moves on/off. No lives, no clock. The string counter (32 px, white while
true, grey once he was free, the best kept) and the readout ("Launch 9.2 m · reeling 0.55 s · steered 12° · from here, out at
124%") use the same functions the bots use. The lessons: round 2's guard card in the % ring's words ("E: up as soon as it's
ready, and it stays while you hold it. Tap a direction to roll. On the beat, nothing gets through."), then six cards (%, Out,
Jumps, Dodge, Back, Edge) and three more (String, per element; Steer; Keep him off), each done by doing it. One hint queue in a
match: one hint every 20 s at most; the edge and recovery hints pre-empt; the stale-move hint waits for the first fall.

### The soak (spec §12)

tests/ring/test_ring_soak.gd with rules=stock (16 pairings × 3 seeds, normal bots, time scale 1:
`zsh tools/ring/r3_soak_run.sh <worktree> <scratchpad> review/r3_bots_soak.md`) prints every METRIC line of §12 and the table
checks each target. **Not yet run on the merged % layer**: in BOTS' own worktree (before PERCENT and MOVE merge) the ring plays
its rules.json rule set and the stock lines read n/a; the bots' parts were measured with stand-ins (tests/npc/r3_standins.gd):
recovery from 12 off-deck spots 100% for every element at normal and hard, 83-100% at easy (it never air dodges), the KO read
at 150% 100% (0% at 0%), true strings only, the
steering and break rates within 0.02-0.05 of bend_ai.json, no velocity written, a hard bot hitting a scripted recovering player
0.38 of its casts.

## Round 4: feel, viral, simple (2026-10-06)

The owner: "do what you think would make a viral round 4", "simple like runescape but hard to master like runescape". Eight
parts, merged in this order and gated together (gate R4: no new red against gate R3). Everything runs only under the % rules
(RingRules.stock_on()) unless said; the open world, the duel and the classic ring play as before (tests pin it).

- **IMPACT: hits with weight** (data/ring/feel.json; BendImpact, RingMoment). A launch holds the struck body's pose and its
  launch 0.04-0.11 s by its speed (never more than 0.4 of the hitstun, which still counts from the hit; the hitter's pose holds
  within 3 m), then plays the pose at 2x until caught up, so strike points and a perfect Catch's return fly as before. The
  "camera kick" is CameraShake.jolt: screen offsets only, never a turn, so the aim never moves (Esc: Screen jolt On/Off). Every
  fall gets the KO splash (a water column, spray, ripples, foam); a game's last fall eases time to 0.35 for 0.6 s of real time
  and back. BendStatus.now() is now game time (BendClock: Engine.time_scale per physics step, nothing while paused), so the
  bend's timers keep pace under a slow beat, a soak at ts 4 and an Esc pause. The player's own visible ring pose does not hold
  yet (sway_pose.gd: next round's one-line hunk).
- **READ: what you can read without a cue**. Every shot carries its own looping voice in flight (tools/sfx/bend/flight.py:
  stone whirr, ice whistle, water rush, fire, air, the Kick's floor run), nearest six heard, a steep level curve, doppler,
  your own shots 6 dB under; arenas only. The ring's camera C (higher, centred, +4.5° field, no tilt: each degree of tilt hid
  more of an incoming shot) is the default; A Close, B Shoulder, D High shoulder in Esc (data/ring/camera.json, RingCamera).
- **LOOKS**: soft licking flames over a glow, the Kick as a three-row wave whose crest is the height a jump clears, Breath's
  smoke as a lit volume, nothing of your own filling your view (a near fade; your Wind Guard thinner; your own walls dithered
  when they hide you, still solid to shots), a shadow under every shot, cores drawn larger at range (hitboxes unchanged).
  data/bending/fx_looks.json.
- **HUD**: a picture for every chip (53 icons, tools/ui/move_icons.py), the strip off the body (L1 bottom-left; L2 and L3 in
  hud.json), one help line of 64 characters or fewer, one type system, the centre words at 30% of the height, and side
  colours in mirror matches only: team 1 wears its element's away dress (RingSides, data/ring/sides.json; cloth only).
- **SHOW**: Tidebreak has its own score (tools/music/cues/ring_fight.py: D major, 132 BPM, its five-note motif A D E F# A),
  three stems of one loop that MusicDirector lays over each other as a match rises (1 at 60 %, 2:00 left or two falls; 2 on a
  last life at 80 %, 0:30 left or sudden death), always on a bar line, with stingers quoting the motif on every fall, last life,
  sudden death and end (RingMusic, data/ring/music.json). The stands are built figures in six poses, lit like the world, that
  ooh at big launches, rise in a ripple from a fall's end, and stand and clap on the beat in sudden death. Lanterns at the
  deck's corners only.
- **VIRAL**: the Splash Cam (RingReplay: an 8 s buffer, ghost puppets, a side dolly, 0.4x at the decisive hit) replays every
  fall after its live splash and slow beat, the tree held and the match resumed exactly; highlight cards (the match's best
  plays, each with Watch) on the match screen; clashes (two attacks meeting: a two-colour burst and rings at the meeting
  point); callouts (SPLASH!, CAUGHT!, PERFECT!, RISE!, CLASH!, COMEBACK!, LAST LIFE) at a fixed spot above the strip; photo
  mode. Esc: Replays (Every fall / Last life only / Off), Callouts, Photo.
- **SIMPLE**: the Basic controls are a new player's default (LMB, right-click, 1, 2, E, Space, 3; Wall and Heal after the first
  win); RingAssist drives the player's own keys only (held Space brings him back, a light steer, the edge climbs by itself,
  Full-only keys held back), never the camera, aim or lock; Full keeps everything. A Basics track of five lessons and a
  first-launch offer. Measured newcomer v easy bot on the merged build: 75% games won, 100% of survivable launches recovered
  (Full, round 3's game: 35% and 31%).
- **BOTS2**: the bots play the whole % game (the Slam, the air close hit, the held shield, true strings) and the soak's
  player-side bot plays with RingMoves (round 3's soak measured a crippled bot). rules.json stock.pct_scale 0.86 sets the pace:
  the merged 48-game soak reads game 264 s, life 99 s, falls at 150%.

The merge's own fixes: the Splash Cam waits for the live splash, the slow beat and its tail; no screen opens under a replay;
the flight voices hold with the tree; per-frame disk and engine-error spam removed (RingAssist.won_once, the flight pool's
meta); round-3 tests that assumed pct_scale 1 pin it or read it. Review: scratchpad review/r4_index.html.

## Build order (proposed)

1. Controls: the keys and their two skills (the same key again switches), the wheel through a skill's variations; the
   element loadout; Mend on 5.
2. Earth, all faces (most of its pieces exist), with catch and throw-back.
3. The interactions engine (kinds of attack, barriers, attack vs attack).
4. Water, then fire, then air, each played before the next.
5. The pro-bending ring and its zones; a bot for each element.
6. Animations, element by element.
