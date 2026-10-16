# Fighting styles and weapon styles (design proposal, 2026-10-08)

Status: **proposal for the owner to approve.** Nothing here is built. Numbers are starting values for the soak to
retune; the identities of moves never change (docs/bending_design.md). Companion to `docs/skill_tree_design.md`
(styles and weapons become branches of that tree) and to the Spellbreak effect mapping
(`artifacts/spellbreak_fx/bending_fx_map.json`).

## The owner's direction (word for word)

- "a whole list of fighting styles where users can mix and match, with weapon styles as well and how they effect the
  type of bending as well"
- "i want more fighting styles like bruce lee jeetkune do muay thai kararte boxing kick boxing all of it caperoia and
  how it affects other blending like i wonder how it will effect the moves"
- "either that or we arrange fighting styles to elements" -> chose the hybrid: "so each element has the same moves but
  each fighting styles create vartations? maybe with weapons being its own styles too?"
- "there was a tai chi swordsmen i remember in the series" -> a fighting style and a weapon combine.

## The model

A fighter is three choices:

| Layer | Decides | Rule |
|---|---|---|
| **Element** | WHAT you bend: the moves (5 keys, jab, guard, passive, rise) | Unchanged. Every bender of an element has the same moves. |
| **Fighting style** | HOW your body throws them: stance, rhythm, footwork, arc shape, strings, defence | Each element has its own roster of 4 styles; **Jeet Kune Do** works with every element. |
| **Weapon style** | WHAT is in your hands and how it shapes the bending | Its own axis, open to every element; also fights without bending (melee), as Sokka and Piandao do in the series. |

A style or weapon makes **variations** of the element's moves; it never adds a different move or replaces one.

### Rules kept

- Never swap a move's identity: a Spike stays a Spike whatever the style.
- No slows and no aim penalties on the player who is hit (only Iron Man mode slows).
- Lock time stays the only spam limiter: no cooldowns.
- No target cues of any kind.
- Easy to learn, hard to master: a new player can ignore styles (each element starts on its canon style) and still play
  the whole kit.
- Ring (pro-bending, % game): everyone picks **one style + one weapon (or none)** on an equal budget. Every style is a
  sidegrade with matching pluses and minuses, never stronger.

## What a style can change

To keep balance readable, a style changes only the **body moves**: the jab string, key 1 STRIKE, key 2 PUSH, key 3 DASH
and the E guard. Walls (4), heals (5), the rise and the passive keep their numbers. A style only re-animates them (a
sumo raises his wall with a stomp, a capoeirista with a cartwheel).

### The six levers (each style: two +, two -; + and - are 10% at the start, the soak retunes)

| Lever | + means | - means | Data (moves.json fields it scales) |
|---|---|---|---|
| **Speed** | quick casts lock faster | quick casts lock slower | `lock_s` of tap moves and the jab |
| **Power** | grown and tap-twice moves knock harder / bigger | weaker | knock `set`/`growth` of grown and big moves, stone size |
| **Reach** | longer range, longer lines | shorter | `range_m`, bolt speed |
| **Width** | wider cones, arcs and pushes | narrower | cone and push widths, `circle_m` |
| **Mobility** | locks fill better on the move, dashes feel lighter | heavier | `moving_mult`, dash distance and recovery |
| **Defence** | a longer perfect guard window | shorter | `guard_rules.perfect_s` (0.30 s +/- 0.03) |

**Live since 2026-10-16** (the owner: "each fighting style should have different perks"), for the wearer of a live style
only, on the body moves, in `scripts/bending/bend_loadout.gd` (the section "a style's levers"; the switch
`data/bending/loadout_apply.json style_levers`; `tests/ring/test_style_perks.gd` reads each live style's four worn and not
worn): Speed scales the lock of the jab, the guard and key 1's and key 2's first mode (x0.9 / x1.1; the tap-twice casts keep
theirs); Power the knock (base and growth, never the %) of the grown and tap-twice casts of keys 1 and 2 (x1.1 / x0.9);
Reach `range_m` and `mps` of the jab's, key 1's and key 2's specs, the grow too (x1.1 / x0.9); Width `width_m` and `deg` of
the same; Mobility the dash's lock (x0.9 / x1.1) and `fwd_mps` every way (x1.1 / x0.9) and the fill on the move of every
body move (x1.1 / x0.9, never past full); Defence the guard's `perfect_s` (+0.03 / -0.03 s). The element's own style (canon)
has levers in the data too, but no canon style is live in BendLoadout (its clips are the element's own), so Classic and a
bot read today's numbers. Not soaked: the design's starting 10%.

**The pick** (the same day: "allow the ability to pick the fighting style"): the match setup's STYLE chips under the element
cards and the ring's Esc menu `Style` row (Match setup) pick a style for the element, kept in the Advancement save for
Classic and the worn loadout alike (`AdvancementStore.pick_style`); `classic_style` is on, so the pick plays with no
loadout worn. The Advancement window's class picker still does the same for a loadout.

Each style also has:
- **a jab string flavour**: the true string stays jab, jab, Pop (bending_design.md "True strings"); the style changes how
  the hits look and which way the Pop launches;
- **a guard flavour**: the element's guard rules stand (earth always catches stone, fire parries lightning only on the
  beat...); the style changes how it is done and adds one small reward on a perfect;
- **a signature**: the one move it transforms most (still the same move).

## The rosters

Real-art notes are what each style is known for; the game takes its feel, not its rules.

### Earth: rooted, heavy, catch-and-return

| Style | Known for | + / - | Jab string | Signature | Guard (Catch) |
|---|---|---|---|---|---|
| **Hung Gar** (canon) | low horse stance, tiger and crane hands | Power+ Defence+ / Speed- Mobility- | tiger-claw flicks; the Pop is a crane strike, straight up | **Shove** grown: a double tiger-palm, the biggest chunk, slowest | a two-hand catch from the horse stance |
| **Karate** | deep stances, straight strikes, kime (one decisive blow) | Power+ Reach+ / Width- Mobility- | snapping straight punches; the Pop is a reverse punch, flat and far | **Spike**: a reverse punch drives it straighter and farther | a sharp block-and-catch, then the throw comes back faster on a perfect |
| **Sumo** | pushing and thrusting (tsuppari), forcing the foe out of the ring | Power+ Width+ / Reach- Speed- | open-hand thrusts; the Pop shoves level (best toward the edge) | **Shove**: rapid thrusting palms, a wide push built for ring-outs | a belly-and-arms catch (whole body) |
| **Wrestling** | takedowns, lifts, slams | Speed+ Power+ / Reach- Width- | quick shots in close; the Pop is a lift | **Column / Slam**: the column launches higher, the Slam spikes down harder | a sprawl catch low to the deck |

### Water: flow, redirect, counter

| Style | Known for | + / - | Jab string | Signature | Guard (Turn) |
|---|---|---|---|---|---|
| **Tai Chi** (canon) | slow continuous circles, push hands, yielding | Defence+ Width+ / Speed- Power- | circling splashes; the Pop rolls them up and over | **Wave**: push-hands, a wider slower arc | a yielding circle; a perfect Turn's return keeps curving (Flowing) |
| **Aikido** | redirecting the attacker's own momentum | Defence+ Reach+ / Power- Speed- | small entering strikes; the Pop is a turning throw | **Turn**: a perfect sends the shot back farther | a step off the line; perfect returns travel +10% |
| **Judo** | throws from off-balancing (kuzushi) | Power+ Defence+ / Reach- Width- | grips of water; the Pop is a hip-throw angle | **Geyser**: the launch throws sideways at a set angle | a grip-and-turn; a perfect readies your jab at once |
| **Wing Chun** | centreline, chain punches, sticky hands, trapping | Speed+ Defence+ / Reach- Power- | chain punches: 4 small splashes before the Pop (strings still decay x0.8, the 6th hit frees) | **Splash / Lash**: rapid centreline chains | sticky hands: a perfect Turn keeps you in range to string |

### Fire: aggressive, rhythmic strikes

| Style | Known for | + / - | Jab string | Signature | Guard (Parry) |
|---|---|---|---|---|---|
| **Northern Shaolin** (canon) | long-range kicks and extended strikes | Reach+ Power+ / Defence- Width- | long punches; the Pop is a flying kick | **High Kick**: a long flying kick, the farthest fire arc | an extended forearm parry |
| **Boxing** | jab, cross, hook, uppercut; head movement; footwork | Speed+ Mobility+ / Reach- Width- | 1-2 and a hook: the hook is the Pop | **Punch / Embers**: the fastest fire; the Fireball still grows, a little slower | a slip: a perfect Parry readies a counter jab at once |
| **Muay Thai** | "art of eight limbs": fists, elbows, knees, shins; the clinch; the teep | Power+ Defence+ / Reach- Mobility- | elbows in close; the Pop is a clinch knee, straight up | **Kick**: a shin roundhouse arc; grown, it becomes a teep (a straight push kick) | a shin check (the parry from a raised knee) |
| **Kickboxing** | punch-kick combinations, low kicks | Speed+ Reach+ / Defence- Power- | punches that finish in a kick: the Pop is a round kick | **Kick**: punch-kick flurries, a low fire wave along the floor | a high guard parry |

### Air: evasive, acrobatic, circling

| Style | Known for | + / - | Jab string | Signature | Guard (Wind Guard) |
|---|---|---|---|---|---|
| **Baguazhang** (canon) | circle walking, palm changes, spiralling evasion | Mobility+ Width+ / Power- Reach- | spiralling palms; the Pop is a turning palm | **Slip**: the dash curves round the foe | a turning palm; a perfect bounce-back carries wind |
| **Capoeira** | ginga (constant rocking footwork), acrobatics, spinning kicks | Mobility+ Power+ / Speed- Defence- | swinging kicks; the Pop is a meia-lua (half-moon) spin | **Gust**: a full spinning crescent of wind | a dodge in the ginga sway |
| **Taekwondo** | high, spinning and jumping kicks | Reach+ Mobility+ / Defence- Width- | fast snap kicks; the Pop is a jumping kick | **Leap**: the air close hit becomes a jumping spin kick with more reach | a lifted-knee wind guard |
| **Drunken Boxing** | a drunkard's sway, deceptive feints | Defence+ Mobility+ / Speed- Reach- | lurching swipes; the Pop is a falling strike | **Slip**: shorter but you recover faster | a stumbling evasion: perfect drops the stone at your feet as usual, with a sway |

### Any element: Jeet Kune Do

| Style | Known for | + / - | Jab string | Signature | Guard |
|---|---|---|---|---|---|
| **Jeet Kune Do** (Bruce Lee) | "the way of the intercepting fist": stop-hits, economy of motion, the straight lead; "using no way as way" | Speed+ Defence+ / Power- Width- | straight leads; the Pop is a stop-kick | **the jab** intercepts: a jab that lands while the foe holds a lock sets it back (the existing rule "a hit sets a lock back"), by its full cost | your element's guard, cast from a narrower, faster stance |

JKD sets a lock back only through the existing bending rule; it never slows movement or aim (the no-debuff rule).
Bruce Lee's "be water" line makes it a natural favourite for waterbenders, but it suits every element: that is its point.

## Weapon styles

**ON HOLD (owner, 2026-10-08): "for weapons i say we wait we have a animater for weapons".** Kept here as the
proposal for when weapons resume; nothing in this section is scheduled. Fighting styles go first.

A weapon is the channel the bending goes through. It shapes casts (and has its own melee moves, so it also works with
no bending). Weapons are open to every element; some fits are more natural than others.

| Weapon | Known from | Shapes the bending | Earth | Water | Fire | Air |
|---|---|---|---|---|---|---|
| **Straight sword (jian)** | Tai Chi sword; the series' swordmaster who trains Sokka | cuts: narrower, longer slices that follow the blade | stone shards flicked off the edge | a water blade (Lash follows the cut) | flame trails each cut | air slices along the cut (Slice) |
| **Broadsword / dual dao** | Zuko as the Blue Spirit; Bagua's big broadsword | heavy chops, wide arcs | chops raise chunks | wide water arcs | wide fire arcs | wide wind arcs |
| **Staff** | Aang's glider staff; Shaolin staff; Karate's bo | sweeps, spins, vaults | strike the deck to raise Column; vault on Pillar | a spinning water shield | fire spin arcs | vortex sweeps (Gust wider), a vaulting Leap |
| **War fans** | the Kyoshi Warriors | wide cones | a dust fan (a weak fit) | mist sprays | fanned flames (Breath wider) | wide cone gusts |
| **Spear** | Shaolin spear | thrusts: long straight strikes | a stone-tipped lance (Spike) | an ice lance (Spear longer) | a flame thrust | a piercing air bolt |
| **Whip / rope dart** | meteor hammer, rope dart | long reach on lashing moves | a chained stone flail | a longer Lash | a fire whip | cracking air |
| **Hook swords** | Jet in the series | hook and pull | pull stones in | pull with water | hooked fire arcs | Pull stronger |
| **Shield** | (Kyoshi Warrior style defence) | blocks and bashes | a rock-faced Catch | an ice shield | a flame-boss parry | a deflecting wind guard |
| **Gauntlets / knuckles** | boxing, Wing Chun's close range | heavier hand strikes | heavier Pebbles | dense splashes | flame knuckles | compressed palms |
| **Frontier weapons** (saber, felling axe, tomahawk, spear) | the open world's existing melee (data/melee/saber.json, felling_axe.json) | map onto the styles above: saber ~ broadsword, tomahawk ~ a throwing hand axe, spear ~ spear | | | | |

A weapon's own pluses and minuses use the same six levers (for example the spear Reach+ Power+ / Width- Mobility-),
so a ring loadout is style + weapon, both on the budget.

### Style + weapon = a combined form

Most real arts carry their own weapons, so some pairings get their own combined clips (the "home" pairings); every
other pairing uses the shared weapon layer:

| Style | Home weapons (real-world) |
|---|---|
| Tai Chi | straight sword, saber (the owner's "Tai Chi swordsman") |
| Wing Chun | butterfly swords, long pole |
| Baguazhang | the big broadsword |
| Aikido | the jo staff, the wooden sword |
| Karate | Okinawan weapons: bo, sai, tonfa |
| Muay Thai | Krabi-krabong (its sister weapon art: sword and staff) |
| Northern Shaolin | staff, spear |
| Jeet Kune Do | nunchaku, sticks (via Filipino arts) |

Home pairings are a look, not a bonus: the budget stays equal.

## Skill tree, open world and ring

- **Open world:** you start on your element's canon style. Others are taught by teachers (the NPC-taught knowledge
  direction) and deepened by practice (moves.json `mastery`). Weapons come from NPCs or are made (project direction:
  items from NPCs or crafted).
- **Skill tree:** each style and each weapon is a branch (`docs/skill_tree_design.md`): early nodes unlock the stance
  and jab string, later nodes the signature and the guard flavour.
- **Ring:** loadout = element + style + weapon (or none), equal budget, sidegrades only.
- **Later, optional:** a rare open-world unlock lets a master learn one off-element style. It's not in the first build.

## Animation plan (the real cost)

Layered, so the cost is per style and not per combination:

| Per style | Clips |
|---|---|
| stance idle, guard, locomotion overlay | 3 |
| jab string (jab, jab, Pop) | 3 |
| signature | 1-2 |
| flavour layers for the other casts (upper-body additive over the element's existing cast clips) | 3-4 |
| **total** | **about 10-12** |

17 styles: about 170-200 clips. Weapons: a grip layer plus about 6 swings or thrusts each, about 60 for 10 weapons,
plus the home pairings. All are our own clips authored in Blender (the existing scripted pipeline,
`tools/anim_author/blender/`; Blender MCP optional for blocking out stances). Real martial-arts forms are reference
only (animations/SOURCE.md provenance rules).

**Build order (proposed):** design sign-off -> one style end to end, judged by eye, before scaling -> the canon four
(their stances exist already) -> the rest of each roster -> JKD. Weapons wait (on hold, above).

### How each style's clips are made (the owner, 2026-10-08: "we need to watch videos on martial art styles and create animations for them")

The project's existing method (animations/SOURCE.md, docs/animation_provenance.md): videos are watched as visual
references only; nothing is taken but the idea of the move; every clip is keyed by hand in Blender by a generator
script on the Actor_B rig and gets its row in animations/SOURCE.md. No animation files, motion capture or pose
estimation are taken from someone else's video.

1. **Reference study:** per style, watch instructional videos of its stance, guard, footwork, jab string and signature
   technique. Write a reference sheet: key poses (what the feet, hips, hands and head do), their timing, the rhythm.
   **Record each video's link** in the sheet and the generator header (closing the gap SOURCE.md notes for the forage
   clips).
2. **Author:** hand-key the ~10-12 clips in a generator script under `tools/anim_author/blender/` (as bend_clips.py),
   bake, install, add the SOURCE.md rows.
3. **Review:** stills and a preview for the owner to judge by eye, a critic pass on the notes, then the owner plays it.
4. Next style only after the first is approved.

## Effects

Style variants can pull different Spellbreak effects for the same move (tight muzzle flashes for boxing's quick fire,
sweeping crescents for capoeira's spins) from `artifacts/spellbreak_fx/bending_fx_map.json`.

## Data shape (draft, not created yet)

```json
{"format": "tidebreak-fighting-styles", "version": 1,
 "styles": {
  "muay_thai": {"element": "fire", "label": "Muay Thai", "canon": false,
                "levers": {"power": 1, "defence": 1, "reach": -1, "mobility": -1},
                "jab_string": {"pop": "clinch_knee", "pop_angle_deg": 85},
                "signature": {"move": "fire_kick", "grown_mode": "teep"},
                "guard": {"look": "shin_check"},
                "home_weapons": ["krabi_sword", "krabi_staff"]}},
 "weapons": {"spear": {"levers": {"reach": 1, "power": 1, "width": -1, "mobility": -1}, "shape": "thrust"}}}
```

## Open questions for the owner

1. Are the rosters right? Swap any style to another element? Add more (Savate, Krav Maga, Kendo, Eskrima/Kali,
   Sambo, Silat, Lethwei)?
2. Weapons: deferred by the owner (an animator handles weapons); revisit the list, element fit and no-bending melee then.
3. Jeet Kune Do as the one all-element style, with interception through the existing lock set-back: yes?
4. Which style to prototype first? (Suggested: fire + Boxing, the quickest to read and to reference.)
5. References: the owner picks the videos, or Claude searches and studies them in the built-in browser (links recorded)?
