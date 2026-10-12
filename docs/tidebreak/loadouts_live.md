# Live loadouts: Boxing and the number-only nodes

Built 10 October 2026 for the Character Advancement window's phases B1 and B2 (`artifacts/ui_audit/advancement/plan.md`, section 7), while the owner was away. A loadout worn in the window now changes a real match (Boxing's clips and five number-only nodes are live; two more are built and switched off after the soak); wearing nothing (Classic) changes nothing. Everything below is in `BendLoadout` ([scripts/bending/bend_loadout.gd](../../scripts/bending/bend_loadout.gd)) and the switches in [data/bending/loadout_apply.json](../../data/bending/loadout_apply.json).

## What is live

| What | Live | Where it comes from |
|---|---|---|
| Boxing (fire class) | yes, animation only | `data/bending/style_poses.json`, `animations_extra/Frontier_Style_Boxing.res` |
| Air: Dense Ball (`air.ball.dense`) | yes | Wind Ball lock 0.75 s to 0.66 s, ball radius 0.35 m to 0.29 m |
| Air: Full Sail (`air.gust.full_sail`) | yes | grown Gust 3.0 m to 3.6 m wide, Gust lock 0.45 s to 0.50 s |
| Air: Keen Edge (`air.slice.keen`) | yes | Slice 45 to 54 m/s, radius 0.12 m to 0.10 m |
| Earth: Lie Low (`earth.burrow.lie_low`) | yes | Burrow stones pass over 0.30 s to 0.36 s, travel 14 to 12.6 m/s |
| Fire: Quick Step (`fire.step.quick`) | yes | Step lock 0.20 s to 0.16 s, forward/back/side carry 10 / 9 / 7 m/s to 9 / 8.1 / 6.3 m/s |
| Earth: Thick Wall (`earth.wall.thick`) | built and tested, **switched off** | Earth Wall 4 hits to 5, 3.0 m wide to 2.5 m; the soak's bots never raise a wall, so the fairness gate could not see it (see the soak) |
| Water: Thick Ice (`water.wall.thick_ice`) | built and tested, **switched off** | Ice Wall 3 hits to 4, rises in 0.7 s to 0.8 s; same reason |
| Water: Wet Trail (`water.skate.wet_trail`) | **no, refused** | its plus is `puddles.count` 3 to 4 and `puddles.life_s` 6 to 7.2, and nothing in the game reads them: the Skate leaves no puddles today. Only its minus (travel 12 to 10.8 m/s) could apply, which would be a pure nerf, so the whole node is refused until the Skate makes puddles |
| Earth: Steady Point | no, out of the set | needs new fields (`sputter_s`, `release_s`) |
| Capoeira, every style that is not `animated` | never | Capoeira is parked; `BendLoadout.style_ok` also checks the element and the library |
| Every other node, the twists, techniques, new skills, sets, levers | no | phase B3 (needs gameplay code) |

The numbers are read from `data/sway/skill_tree.json` `changes[]` (the one place they live). A node applies only when every change in it can be applied per wearer and the move's data still holds the change's `from` (so a retuned move refuses the node instead of silently applying a stale absolute). Taking the node out of `live` or flipping its switch gives the move's own numbers back.

**Added 11 October 2026: the Lightning Pistol** (`fire.lightning.pistol`, fire's Storm twist; the owner: "we want both moves
the orignal one and the lightning pistol it will be a skill tree thing have this or that and each has it perks and cons").
Live, not yet soaked. Its changes: `pose:fire_arc/lightning` from `own-bend-fire-lightning` to `frontier-pistol-lightning`
(a new change kind: `BendLoadout`'s `pose` overlay, read by `BendPoses.pick` for the wearer before his fighting style), the
charge 2.2 s to 1.5 s (`move:fire_arc.mode_lock_s.lightning`), the flash before the strike 0.25 s to 0.4 s
(`spec:fire_arc/lightning.flash_s`). It excludes Short Fuse and Long Lightning (the same charge) and is the other choice of
the twist slot with Forked Lightning. Not worn, Lightning is the original. Details: `docs/tidebreak/gun_casts_2026-10-11.md`.
The same day Classic's fingerprint (`tests/ring/fixtures/loadout_classic_golden.json`) was re-taken on purpose (the gun-style
Embers and Ice Spear clips, and the moving hold's visual traces); every lock, real cast and strike, end, root and wait frame is
as before (that document has the diff).

**Added 11 October 2026: the class numbers** (the owner, on "only 5 change anything in a match": "fix it"). A new change kind,
`class:<tag>+<variant>.<key>`, sets one number of the % ring class (`data/ring/rules.json` `stock.classes`) of the wearer's own
hits with that tag: `d`, `base`, `growth`, `angle`, `set_stun`, and `volley_n` only when the same node also changes that move's
spec `count` (the cast writes its count on every hit; the class's count only stands in where a hit carries none). The overlay's
`class` part is read in one place, `RingRules.on_hit`, through `BendLoadout.hit_class(by, cls)` right after `class_of(tag)`; a
growth is scaled by `growth_scale` as `class_of` scales the data's. The hit keeps the move's own tag, so staling, the range
exemption, the highlights and the bots' string tables see the move it is (the tree's `proposed_classes` asked for the variant
tag to fold back to its base; keeping the base tag does that without touching any reader). Refused: a whole new class (a hit the
node adds, such as Surfacing or the Reel), a key that says what the hit is (`set`, `dir`, `pull`), and a number whose data
drifted from the node's `from`. Also new: a node whose `requires` names a node that is not live is not live itself, and a pick
worn without the node it requires applies nothing (Mud Lash's numbers resolve, but its Mud set is new matter, not numbers).

That made nine more nodes whole. They are live on the owner's word and not yet soaked (the tree's starting values):

| Node | What it changes for the wearer |
|---|---|
| Earth: Deep Fissure (`earth.fissure.deep`) | Fissure 17 to 14.5 m/s; launch angle 40 to 55 degrees, grown too |
| Water: Cold Hands (`water.spear.cold_hands`) | Spear lock 0.6 to 0.52 s; adds 13% (from 14) |
| Water: Heavy Spear (`water.spear.heavy`) | adds 16% (from 14); flies 35 m/s (from 42), radius 0.19 m (from 0.16) |
| Water: Pooling Downpour (`water.downpour.pooling`) | puddle 1.9 m (from 1.6) for 7.2 s (from 6); adds 7% (from 8) |
| Fire: Snap Punch (`fire.punch.snap`) | Punch 38 m/s (from 32); adds 13% (from 15); the Fireball unchanged |
| Fire: Short Fuse (`fire.lightning.short_fuse`) | Lightning charges in 1.9 s (from 2.2); adds 22% (from 25) |
| Fire: Tight Embers (`fire.embers.tight`) | spread 7.2 degrees (from 9), 6 sparks (from 7), the volley's % over 6 |
| Air: Shoving Palm (`air.palm.shoving`) | set knock 5.4 (from 4.5); adds 4% (from 5) |
| Air: Rising Gust (`air.gust.rising`) | launch angle 30 to 55 degrees, the Air Lance too |

The test (`tests/ring/test_loadout_apply.gd`) checks every class change on a wearer and on a body that wears nothing, the
refusals, the requires rule, and one real hit: with Short Fuse worn the player's Lightning adds 20.90% where the bot's adds 23.75
(22 against 25, x the ring's `pct_scale` 0.95), the tag `fire_arc/lightning` either way. Limit: the practice ring's readout
(`RingPredict.ko_pct`) still reads the move's own class, so its "out at" figure ignores a worn class node.

**Added 11 October 2026: the binds** (the owner: "each element should have binds and finishers"; the feet only, as a
skill tree twist). Four twists, Stone Grip (`earth.column.grip`), Frost Geyser (`water.geyser.frost`), Static Shock
(`fire.lightning.shock`) and Tripwind (`air.pull.trip`), each set a spec key Classic does not have, `bind_s`, from none to 0.7
(`BendLoadout.NEW_SPEC_KEYS`: a node's change may start from null for these keys only), plus their class's lower % and, for
Static Shock, a 1.4 s charge. Their hit holds the feet in place of the launch. Live on the owner's word, not soaked. Everything
about them: `docs/tidebreak/binds_2026-10-11.md`. The same day, two more on the same keys: Wind Prison (`air.wall.prison`,
`prison_s`) and Drenching Wave (`water.wave.drench`, `drench_s`), with the knock-ups in the base kit:
`docs/tidebreak/knockups_2026-10-11.md`.

## How a loadout becomes live

1. The player wears a slot in the Advancement window; `AdvancementStore` saves `user://advancement.json` (the window does the saving, the match never does).
2. A match starts (or restarts, a rematch) and `RingMode.restart` calls `BendLoadout.wear_player(player, element)`. It reads `AdvancementStore.worn_index/slot_state/worn_loadout` (read only) for the player's element and puts two things on the player's body:
   - meta `loadout_overlay` / `loadout_picks`: the resolved numbers of the slot's live nodes;
   - meta `fighting_style`: the slot's class, if it is live (`styles_live`, state `animated`, of that element).
3. Readers ask the body: nothing worn means no meta, and every reader gets exactly the dictionary and number it always did. A pick that is unknown, held, world-only, another element's, repeated, not in `live`, switched off, or refused applies nothing. A slot that breaks a rule is read by the store as Classic.
4. **Classic is nothing**: worn index -1 puts nothing on the body, even if a class was picked with Classic (`AdvancementStore.set_style`). `classic_style` in `loadout_apply.json` is `false` for that reason; set it `true` if the Tidebreak panel's Class row should play its clips with Classic worn (still animation only).
5. **A script run (`-s`, every test and tool) does not read the save** unless `BendLoadout.read_store_in_scripts` is set, because a script run's store is the shared test file; this keeps every other test playing Classic whatever that file holds. The game itself (no `-s`) reads the player's own file.
6. Bots never get a style and never read the save. A test or the soak gives a bot an overlay with `BendLoadout.wear(body, picks, "", element)`.

## Where the numbers are read (the seams)

| Number | Seam | Wearer only because |
|---|---|---|
| spec keys (`mps`, `radius_m`, `fwd_mps`, `under_s`, `grow.width_m`, `fwd`/`back`/`side` carries) | `BendEffects.apply`, right after `resolved()` and before the grow merge: `spec = BendLoadout.spec(bc.body, m, mode, spec)` | the overlay is the caster body's meta; the copy is merged, the shared data never |
| the mode's lock | `SwayCaster._lock_time` (the player) and `NpcBending.lock_for(..., who)` (a bot): `BendLoadout.lock(body, m, mode, base)` replaces the data's base before the stretch, the tier and `lock_mult` | same; `move:footwork.lock_s` is scoped to the node's own mode (Step) |
| Earth Wall hits and width | `FormEffects.earth_wall`, `FormEffects.tree_wall`, `NpcBending._wall`: `BendLoadout.wall_numbers(body, "wall", ...)` over `FormMatter.numbers` | stone and mud keep their own strength (`hits` 7 and 2 override the base, as before); shell and ramp are not touched |
| Ice Wall hits and rise | `BendEffects.ice_wall` through `_wall(..., ice = true)`: `wall_numbers(body, "ice", ...)` | Freeze (frost) and the other snow walls keep the move's numbers |
| a hit's % ring class (`d`, `base`, `growth`, `angle`, `set_stun`, `volley_n`) | `RingRules.on_hit`: `cls = BendLoadout.hit_class(by, class_of(tag))` | the class is the hitter's (`by`); a returned stone keeps its return class |
| the cast pose | `BendPoses.pick(m, mode, element, body)`, `BendPoses.stance_pose`, `BendPoses.guard_hold_pose`; `SwayPose` passes `caster.player` | a body without the meta gets the element's pick unchanged |

Nothing else reads these numbers: the HUD and labels do not show them, the ring rules read `info` tags and `%` classes, not the specs. Two readers keep the data's numbers on purpose:

- **What a blow costs whom it hits** (`spec._lock_s`, the victim's lock set-back) stays the move's own data lock, as it already ignores mastery tier and stretch. A talent changes its wearer's lock and never what a hit does to someone else (the tree's lock contract).
- **Bot planning estimates** (`NpcBending.shot_of`, the dash reach guesses, `NpcRingMind.pct_rate`) read the data's numbers. A bot wearing a node still moves and shoots with the node's real numbers; only its guesses are the move's own.

## Boxing (B1): animation only, the Classic time

`BendPoses.pick` reads the body's `fighting_style` first; the style's entry in `style_poses.json` is tried before the element's own, and a move or mode the style leaves out (the air hit, the fire wall, Breath, Jets) plays the element's clip. The stance and the held guard follow the same rule. The Boxing library is loaded the first time one of its clips is asked for (`BendPoses.animation` finds `own-style-<style>-*` clips through `style_poses.json`'s `library`); a body that wears no style never loads it, and `BendPoses.LIBRARIES` is unchanged.

**Timing.** A cast is timed on its pick's `hold_s`, `strike_s`, `back_s`, `root` and the clip's length (the strike waits `strike_s - clip time`, a rooted kick holds the caster until the clip ends). Every Boxing clip's own times differ from the element clip it replaces (table below), so a Boxing pick is *timed as the element's own pick* (`BendPoses._timed_as`): the element's `hold_s`, `strike_s`, `back_s`, `root`, and `end_s` = the element clip's length. `SwayPose` then shows the Boxing clip on that timeline with a warp (element times mapped to the clip's own hold, strike, back and end): the fist lands where the element's strike is, the wind-up and recovery are stretched or squeezed between. Cast time, hit time and how long a kick roots the caster are therefore exactly Classic's, by construction, for any lock length. Nothing was retimed in the clip library or the data; the style entries stay descriptive. No clip was edited.

| Pick | Boxing clip (hold / strike / back / length, s) | Element clip it replaces (same) |
|---|---|---|
| `fire_jab` embers, jab | `jab` .067 / .167 / .267 / .533 (other hand `cross` .100 / .200 / .333 / .667) | `fire-sweep` .200 / .300 / .600 / 1.000 (embers); `fire-punch` .167 / .267 / .500 / .867 (jab) |
| `fire_jab` pop | `hook` .100 / .233 / .400 / .800 | `jab-rise` .067 / .167 / .433 / .800 |
| `fire_jab` double_jab, `fire_blast` stream | `flurry` .067 / .133 / .600 / .933 | `fire-double` .167 / .267 / .600 / 1.000 |
| `fire_blast` punch | `punch` .133 / .267 / .500 / .933 | `fire-punch` .167 / .267 / .500 / .867 |
| `fire_blast` fireball | `fireball` .267 / .400 / .633 / 1.200 | `fire-punch` .167 / .267 / .500 / .867 |
| `fire_arc` lightning | `lightning` 1.000 / 1.133 / 1.433 / 2.067 | `fire-lightning` 1.067 / 1.200 / 1.567 / 2.133 |
| `fire_kick` kick (rooted) | `ground-punch` .200 / .333 / .567 / 1.200 | `fire-kick-low` .200 / .300 / .667 / 1.067 |
| `fire_kick` high_kick (rooted) | `uppercut` .200 / .333 / .533 / 1.067 | `fire-kick` .200 / .300 / .733 / 1.200 |
| `fire_parry` parry | `slip` .167 / .400 / .533 / 1.000 | `fire-parry` .133 / .267 / .533 / 1.000 |
| `footwork` step, hop, back_flip, ignite_step | `step-back`, `step-right`, `step-back`, `step-in` .067 / .233 / .367 / .600 | `air-leap` .200 / .300 / .667 / 1.067 |
| stance, held guard | `stance` (loop) | `stance-fire`, `guard-hold-fire` |

The jab's other hand (`alt`, the combo window) is timed the same way against the element's alt; picks whose element pose has no other hand get none. The overhand Fireball's grow clip and the 1-2 flurry on a key are not reached by any key (the game plays a pose's grow clip nowhere), as before. What the warp costs: where a Boxing clip's own beat is far from the element's (the Step's 0.60 s clip on the 1.07 s Leap timeline, the Jab's wind-up), the wind-up and recovery play slower than the clip was keyed; the strike itself is in step. Re-keying the clips to the element's times would remove the stretch; that is the animation lane's call.

The `root` key of a Boxing pick is the element's (the kick and high kick root the caster, the punches do not). The Boxing clips carry `mask = full`, so they pose the whole body (the owner has seen exactly this in the style launcher).

## Switches and how to flip them

`data/bending/loadout_apply.json`:

- `enabled` (master): `false` and no node number and no style applies anywhere.
- `nodes.<id>`: `false` takes that node out; it then reads as the move's own numbers. Absent counts as on. To turn Thick Wall or Thick Ice on, set it to `true` (the test forces every node on for its own checks).
- `live`: the ids that may apply at all (the seven resolvable ones; five are on, the two walls are `false` in `nodes`). `water.skate.wet_trail` is not in it.
- `styles_live`: `["boxing"]`. Empty and no style plays.
- `classic_style`: see "How a loadout becomes live" step 4.

`BendLoadout.live_ids()` and `BendLoadout.live_styles()` return what is live now (switches on, numbers resolved) so the window can mark them; `BendLoadout.why_not(id)` says why a node is not.

## The fairness soak

`tools/ring/loadout_soak.gd` plays mirror matches in the % ring (lives; normal bots; the same element on both sides; 3 lives each, one game per match, headless at the game's own pace). One side wears the node (or all the live nodes of its element together) and the other is Classic; the wearer alternates sides game by game to cancel side bias; each game has its own seeds and a fresh foe. The gate from the plan: the wearer's win rate within 0.40-0.60 at 30 games; a node outside it is raised to 60 games (30 more on new seeds) and must be within 0.45-0.55, else it is switched off in `loadout_apply.json`. Draws count half (there were none). Run 2026-10-10, seed 7300 (extension 8400), 30 games per row unless shown.

| Node(s) worn | Games | Wearer wins | Rate | 95% interval | Wins as side 0, side 1 | Lives lost wearer / other | Casts of the node's move | Gate |
|---|---|---|---|---|---|---|---|---|
| air.slice.keen (Keen Edge) | 30 | 14 | 0.467 | 0.30-0.64 | 7/15, 7/15 | 75 / 69 | 652 | in |
| air.ball.dense (Dense Ball) | 30 + 30 | 19, then 29 of 60 | 0.633, then 0.483 | 0.36-0.61 at 60 | 11/30, 18/30 | 146 / 143 | 1055 | out at 30, **in at 60** |
| air.gust.full_sail (Full Sail) | 30 | 16 | 0.533 | 0.36-0.70 | 10/15, 6/15 | 67 / 72 | 966 | in |
| air: the three together | 30 | 13 | 0.433 | 0.27-0.61 | 7/15, 6/15 | 74 / 67 | 2136 | in |
| earth.burrow.lie_low (Lie Low) | 30 | 18 | 0.600 | 0.42-0.75 | 7/15, 11/15 | 69 / 76 | 113 | in (the limit) |
| earth.wall.thick (Thick Wall) | 30 | 17 | 0.567 | 0.39-0.73 | 10/15, 7/15 | 68 / 73 | **0** | in, but unexercised |
| earth: both together | 30 | 15 | 0.500 | 0.33-0.67 | 10/15, 5/15 | 73 / 73 | 129 | in |
| water.wall.thick_ice (Thick Ice) | 30 + 30 | 9, then 23 of 60 | 0.300, then 0.383 | 0.27-0.51 at 60 | 12/30, 11/30 | 151 / 140 | **0** | out at 30, out at 60, unexercised |
| fire.step.quick (Quick Step) | 30 | 14 | 0.467 | 0.30-0.64 | 6/15, 8/15 | 72 / 71 | 374 | in |
| (baseline: earth, nothing worn) | 30 | 18 | 0.600 | 0.42-0.75 | 10/15, 8/15 | 71 / 73 | 0 | |
| (baseline: water, nothing worn) | 30 | 9 | 0.300 | 0.17-0.48 | 5/15, 4/15 | 78 / 67 | 0 | |

What this says:

- **Live and passing (5):** Keen Edge, Dense Ball (after the extension), Full Sail, Lie Low, Quick Step; the air set and the earth set together are within the gate too. None wins or loses clearly: no node is too strong or a trap in bot mirrors. Lie Low sits on the 0.60 limit, but the Burrow is cast about 4 times a game and the interval is wide.
- **Switched off (2): Thick Wall and Thick Ice.** The bots never raise an Earth Wall or an Ice Wall in these matches (0 casts in 30 earth and 60 water games; they only answer a held stone with one), so the games they play are Classic's: the water baseline with nothing worn gave exactly the node's games (9 of 30, 78/67 lives, 3605/3755 casts), and the earth baseline gave 18 of 30 against the node's 17. The numbers apply and are tested end to end (the test builds the walls); but the gate cannot see them, so their 0.567 and 0.383 are the instrument's noise and not evidence either way. Thick Ice failed the gate at 60 games by that noise; Thick Wall passed it by it. Unverified is treated as not live: both are `false` in `nodes` (still in `live`, so `BendLoadout.why_not` says "switched off"). Flip them to `true` once a duel, a scripted match or a bot that walls has measured them.
- **How strict the gate is.** A fair node falls outside 0.40-0.60 at 30 games about 27% of the time and outside 0.45-0.55 at 60 games about 45% of the time (standard deviation 0.09 and 0.065), and the unworn baselines themselves read 0.600 and 0.300. Read the table as "nothing clearly wrong", not as a measurement of strength. The same configurations in a first pass (the foe kept between games, before the harness fix below) read 0.500 / 0.500 / 0.367 / 0.400 (air: Keen Edge, Dense Ball, Full Sail, the three), 0.600 / 0.633 / 0.433 (earth: Lie Low, Thick Wall, both), 0.600 (Thick Ice) and 0.500 (Quick Step).
- **Anomalies.** No bot crashed or stalled in any of the 330 games of the final pass (the longest game was 488 s of game time; each takes about 11 s of wall time headless, more when the machine is busy). No side was ever without casts, no self ring-out, and the loadout was found on the wearer at every check (59 of 59 per row, never missing, never on the other side). Three harness findings: (1) the first pass kept the same foe between the games of a run; its stale knock credit and old mind produced `NpcRingMind._on_landed` errors on a freed bot (29 in the Quick Step row only), so the soak now drops the foe between games (no errors since); (2) one Full Sail row was void: another task's menu script had a parse error while the run started (106 SCRIPT ERRORs, every ring script failed to compile), and it was re-run whole; (3) the simulation is not bit-for-bit repeatable for earth (stones are physics bodies), so the same seed does not replay an earth game exactly; water without a node cast replays exactly.


## Decisions taken while the owner was away

1. Classic plays nothing: a class picked with Classic worn is not played (`classic_style` false). The plan's text reads the class from `AdvancementStore.style_of`, which includes that case; the brief's rule that Classic plays exactly as today won. One flag to change it.
2. A hit's cost stays the move's data lock (above). A talent that shortens the wearer's lock does not shorten what a blow costs the victim, and one that lengthens it (Full Sail) does not lengthen it.
3. Quick Step's lock change is scoped to the Step mode (`move:footwork.lock_s` names the move; the node is the Step's).
4. Skate's Wet Trail is refused (its puddles are made by nothing), the two walls are switched off (unexercised), see above.
5. Boxing is timed as the element's pick at pick time (`BendPoses._timed_as`) rather than by writing retimed numbers into `style_poses.json`: it cannot drift from Classic if the element's clips change, and no clip or library was edited. Where Boxing has no pose, or the element has none, the element's clip plays (the tier clip when the element has none).
6. A script run does not read the save (see "How a loadout becomes live").
7. Files touched outside the list, each by a few lines and only where a number or a clip is read: `scripts/sway/sway_pose.gd` (the body into the pick and the stance, `end_s` and the warp), `scripts/sway/sway_caster.gd` (`_lock_time`, `guard_hold_clip`), `scripts/sway/form_effects.gd` (`earth_wall`, `tree_wall`), `scripts/npc/npc_bending.gd` (`lock_for` takes the body, the bot's `_wall`), `data/bending/style_poses.json` (its doc line only). Planning estimates in `npc_ring_mind.gd` and `ring_practice.gd` were left alone.
8. The soak's gate was applied as written (30 games, 60 for an outside node, 0.45-0.55); a node the soak could not exercise is treated as unverified and switched off rather than judged by noise.

## Known limits

- **Online play.** The match reads the loadout of the local player only. A host would have to read both loadouts (and send the guest's) before the match for both sides to agree on the numbers; nothing is sent today, and the soak did not cover it.
- **Bots do not wear loadouts.** Only a test or the soak gives one a loadout; `BendLoadout.wear` is the way.
- Planning estimates in the bots (above) and `NpcRingMind.pct_rate`, `ring_practice` read the data's locks; they do not affect any number in play.
- Nodes work in Practice too (the same `RingMode.restart`), so a player can try a loadout there.
- The window should mark the live ones from `BendLoadout.live_ids()`; the plan's `GameSettings advancement.apply` is not used: the switch is the JSON.
- Freeze (the frost ice wall) is not a Thick Ice wall; shell and ramp are not Thick Wall walls (the nodes extend the Wall and the Ice Wall modes only).
- A style or node that does not fit the worn element (another element's id in a slot) applies nothing for that body.

## Independent review (10 October 2026, second pass)

The review the usage limit cut off, done again. Each point has a test, `tests/ring/test_loadout_review.gd`, and each test checks against something that does not come from `BendLoadout`. The "Classic before" side is a fingerprint taken from the code BEFORE the loadouts commit (`c0a631a0^`) with `tools/ring/loadout_classic_print_run.gd` and kept in `tests/ring/fixtures/loadout_classic_golden.json`. That fingerprint covers 123 move/mode locks for the player and the bot (near and far, every difficulty), the ranges, what a hit costs, 480 cast poses, 386 cast timelines (three lock lengths and the other hand, frame by frame), and 47 real casts (speed, size, damage, knock, lift, dashes, the walls).

| # | Claim | Verdict | Proof |
|---|---|---|---|
| 1 | Classic is unchanged | **CLEARED** | Today's fingerprint matches the code before the loadouts byte for byte. It also matches with the master switch off, with every node and Boxing switched on and nothing worn, and in the next match after one played wearing a loadout (test part 1, 16 checks). |
| 2 | A talent changes only its wearer | **CLEARED** | For every element: while the player wears all its nodes, the bot's casts and all its locks are Classic's. While the bot wears them, the player's are Classic's. The wearer's own casts do change. The loadout persists through rounds of a match and is gone in the next match without it, also for a new bot (part 2 and the end of part 5). |
| 3 | Boxing keeps Classic's cast timings | **CLEARED** (timing) | 52 driven casts: every Boxing pick at 0.03 s, hold + 0.15 s and hold + 0.7 s of lock, plus the other hand, with Quick Step worn alongside. Every one strikes, ends, roots and waits on Classic's frames, and on the strike frame the Boxing clip shows its own strike (within one frame). A bot given Boxing by hand plays the element's own clips (part 3). |
| 3b | Boxing is "animation only" | **CONFIRMED, not fixed (owner's call)** | A bolt, a cone, a throw or a floor wave leaves from the pose's limb on the strike frame (`SwayPose.strike_point`, `PlayerBendCaster.launch_point`), so it leaves from Boxing's fist rather than the element clip's limb. Measured in the player's own frame: the **High Kick** (a throw) leaves 0.94 m from where it did before, **0.90 m higher** (the uppercut's fist instead of the kicking foot). The **Pop** leaves 0.52 m away, 0.44 m lower. The other 13 picks are within 0.06 to 0.30 m. The timing is Classic's, but the starting point of the shot is not. Pinned in part 3 (`KNOWN_LAUNCH`) so any change is seen. |
| 4 | The save is robust and isolated | **CONFIRMED and FIXED** | A hand-edited or damaged `user://advancement.json` stopped the read with a script error and misread the save. `"worn": "x"` or `0.7` wore slot 0. A `null` name or time, a `"yes"` padlock, or a non-string id lost the slot's picks. An empty or broken file printed an engine "Parse JSON failed" error. `AdvancementStore` now reads every field by its type (`_str`, `_int`, `_bool`; a value of the wrong type is read as the default, a non-string id is dropped and named) and parses with `JSON.new()`. Test part 4 has 16 cases: before the fix, 4 failed with 4 SCRIPT ERRORs; after it, all pass. A missing file, an old format, an unknown style and a removed node id were already handled (CLEARED). Reading never writes. The test proves the player's own save is untouched (its modified time is the same before and after). |
| 5 | The switches gate everything | **CLEARED** | Through `RingMode.restart` (the match start): `enabled` false takes away the node and the class, `nodes.<id>` false or the id left out of `live` takes away the node, `styles_live` empty takes away the class, and `classic_style` works both ways. The window's green dots (`AdvancementData.is_live` / `is_live_style`) agree with `BendLoadout` for all 133 nodes and every style (part 5). The switches are read at the match start; the file is read once per run, so in the game a switch only changes with a new run. |
| 6 | No per-frame allocation or lookup in hot paths | **CONFIRMED (minor) and FIXED** | Every Classic read made a new empty dictionary (`overlay_of` returned `{}`; a bot's `NpcBending.lock_for` calls it several times per think). A Boxing body ran `style_ok` again every frame (the stance, the held guard) through config and data lookups with default `[]`/`{}` arguments. Now a body that wears nothing is answered by one `has_meta`, and the shared read-only empty overlay is returned. `style_ok` is kept per config (a new `config_override` or `reload_data` asks again). Measured 0.28 µs per Classic `lock()` call and 0.78 µs per Boxing `style_of` call (part 6). The Boxing library (345 KB) still loads on first use: the first stance frame of a styled match, in the countdown. |

Also checked and cleared: the soak's wall keys (`earth_wall/wall`, `water_shield/ice_wall`) are the bots' real cast keys, so "0 casts" means the bots really never wall. No body is ever duplicated with its metas. The ring has no online path today, so the online limit above cannot arise yet. Changing the element in the Esc menu during a match leaves the old element's overlay on the body; it has no effect, because its keys are another element's moves, and it is replaced at the next restart.

**Soak after the fixes** (n = 10 per element, seed 7300, nodes=all, the same command as above):

| Element (nodes worn) | Wearer wins | Rate | Lives lost wearer / other | Casts of the nodes' moves | Same seeds before the fixes |
|---|---|---|---|---|---|
| air (Dense Ball, Full Sail, Keen Edge) | 4 of 10 | 0.400 | 26 / 23 | 688 | identical, game by game |
| earth (Lie Low, Thick Wall forced on) | 5 of 10 | 0.500 | 24 / 24 | 33 | (earth does not replay bit for bit: stones are physics bodies) |
| fire (Quick Step) | 5 of 10 | 0.500 | 24 / 24 | 123 | identical, game by game |
| water (Thick Ice forced on) | 3 of 10 | 0.300 | 27 / 22 | 0 (the bots never wall) | identical, game by game |

The fixes moved nothing: air, fire and water played the same ten games, line for line, on the code before the fixes and after them. The loadout was found on the wearer at every check (19 of 19 per run), with no anomaly and no script error. Ten games is a smoke run, not a fairness measure (see "How strict the gate is"). These are mirror matches, so they say nothing about one element against another.

## Tests and commands

```
# the test (headless): the switches, every live node's numbers on a wearer and on a bot, Classic's identity, the styles, the
# ring scene with a worn slot (real casts), the save never written
zsh tools/loop/run_test_fps.sh /Users/kiwimango/Downloads/Frontier loadout_apply tests/ring/test_loadout_apply.gd

# the independent review (headless): Classic against the code before the loadouts (the golden fingerprint), the wearer only,
# Boxing's frames and launch points, the damaged saves, the switches through the match start, the hot paths
zsh tools/loop/run_test_fps.sh /Users/kiwimango/Downloads/Frontier loadout_review tests/ring/test_loadout_review.gd

# re-take Classic's fingerprint (only when Classic is changed on purpose: then replace tests/ring/fixtures/loadout_classic_golden.json)
zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path /Users/kiwimango/Downloads/Frontier -s tools/ring/loadout_classic_print_run.gd -- out=<file.json>

# the soak: one config per run; n games, the wearer alternating sides; nodes=all for the element's live set
zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path /Users/kiwimango/Downloads/Frontier -s tools/ring/loadout_soak.gd -- element=air nodes=air.slice.keen n=30 seed=7300
grep "LSOAK RESULT" <log>

# a Classic-vs-Classic baseline (nodes= empty)
zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path /Users/kiwimango/Downloads/Frontier -s tools/ring/loadout_soak.gd -- element=air nodes= n=20
```

A game is about 11 s of wall time headless. `GODOT_TIMEOUT=1500` for 30 games per run. The soak forces on the nodes it is asked for (so a switched-off node can be re-measured) and takes the seeds from `seed=` (game `g` uses `seed + 101 g`).

## Earth's behaviour talents (pass 1, 2026-10-11)

The owner: "we need to make sure all the talents work and they work in game right". Branch `tb/talents-earth-p1`. Each node
below is in `loadout_apply.json` `behaviour` (where its code is), at the end of `live`, on in `nodes`, and played worn and not
worn in a real ring by `tests/ring/test_talents_earth.gd` (105 checks), the bot's side too. Live on the owner's word, not soaked.

| Node | What the wearer gets (code) |
|---|---|
| Thick Wall (switched on) | 5 hits, 2.5 m wide, raised and shot down in a ring |
| Juggle | his Catch holds two stones of one window side by side, E throws the oldest, a third drops at his feet; full catch 0.8 s (`BendZone.held_stone`, `held_stones`; `stock:guard_catch_s` in `RingRules.guard_outcome`) |
| Return to Sender | a clean catch thrown back with E pressed within the Beat of the catch flies x1.15; late return lock 0.4 s (`BendZone.return_stone`, `beat_return`) |
| Kick-Up | a Pebbles volley that meets nobody leaves one loose stone where it lands (`BendBolt._kick_up_end`) |
| Avalanche | the Boulder landing on the deck breaks into three low rolling stones fanned 15 degrees, one volley of 3, base 5.9; a Catch holds one, the rest drop at the catcher's feet (`GustLift._avalanche`) |
| Heave | a Column let go on the Beat launches with base 11.3 (a class change marked `when: beat` in the tree: `BendLoadout` `class_beat`); lock 1.7 s |
| Kiln Stone | his stone through any Fire Wall or burning ground is heated until it lands: base x1.15, a fire trail; a Parry on the beat sends it back, a Turn douses it (`BendBolt.heat`, `GustLift._kiln_check`, `BendZone`) |
| Rubble Wall | his wall shot down or capped leaves two loose stones at its foot; rise 0.8 s (`FormRaised._rubble_stones`) |
| Quarry | his Beat Fissure into his own wall tears a chunk off and throws it on, the first chunk free; rise 0.8 s (`BendBolt._quarry`) |
| Reinforce | a mended piece takes its next two hits free (`FormRaised.take_brace`); Mend's lock 2.6 s |
| Sulphur (set) and Sulphur Spike, Sulphur Boulder, Fuming Column, Brimstone Wall, Flint Pebbles, Sulphur Heart | gas: `scripts/bending/bend_gas.gd` (loaded by path, a BendZone of kind `gas`); see its header |

**The Beat** (the tree's timing rule; the owner's answer: yes) is built once for all techniques: a held cast let go within
`beat.window_s` (0.2 s) of its lock filling, for a wearer of a technique it pays only (`BendLoadout.beat_paid`: a built node
whose new code names the Beat). SwayCaster and a bot's release put `beat` on the hit's info (`BendR3.info_for`); a brief
glow on the caster's own hands (`BendLooks.beat_flash`). Classic: nothing, not even the look.

**New BendLoadout kinds** (additive): `set:<set>.<key>` tune paths (a skill set's zone rule, read from the tree's
`skill_sets`), `stock:guard_catch_s`, a class change `when: beat` (`class_beat`), `default_from` for a class's `volley_n`
beside a node's own new code, and a modeless move's lock (Mend). `test_loadout_apply.gd` wears a node with the nodes it
requires, reads a Beat class on a Beat hit and a `default_from`'s default.

**Not built (next pass): the Sulphur Vent** (a new skill on key 4 tapped twice). It needs a per-body mode the key's double
tap reaches (`Bending.other_move` and `SwayCaster.step_other` are per element, not per wearer), its spec kept out of
`moves.json` (the Classic fingerprint enumerates every bend key as a mode), its pose and a bot option. The water, fire and air
lanes' new skills on empty double taps need the same seam: build it once. Also not built: lightning's Live Gas and the
reactions of cone moves (Breath, the Wave) on gas; magma seams heating a Kiln Stone (the Magma set).
