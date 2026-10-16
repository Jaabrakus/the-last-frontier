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
| Water: Thick Ice (`water.wall.thick_ice`) | **switched on** since 2026-10-11 (played in a ring by `tests/ring/test_talents_water.gd`, a bot wearing it raising it; still not soaked: the soak's bots never wall) | Ice Wall 3 hits to 4, rises in 0.7 s to 0.8 s |
| Water: Wet Trail (`water.skate.wet_trail`) | **live** since 2026-10-11 | its plus is `puddles.count` 3 to 4 and `puddles.life_s` 6 to 7.2: the Skate's puddles are made for its wearer alone (`BendEffects._wet_trail`; Classic's Skate still leaves none, the 3 is the data's dormant count); its minus travel 12 to 10.8 m/s |
| Earth: Steady Point | no, out of the set | needs new fields (`sputter_s`, `release_s`) |
| Capoeira, every style that is not `animated` | never | Capoeira is parked; `BendLoadout.style_ok` also checks the element and the library |
| Every other node, the twists, techniques, new skills, sets, levers | no | phase B3 (needs gameplay code) |

The numbers are read from `data/sway/skill_tree.json` `changes[]` (the one place they live). A node applies only when every change in it can be applied per wearer and the move's data still holds the change's `from` (so a retuned move refuses the node instead of silently applying a stale absolute). Taking the node out of `live` or flipping its switch gives the move's own numbers back.

**Removed 12 October 2026** (the owner: "we dont have that skill"; its pistol aim is the Ice Spear's now). **Added 11 October 2026: the Lightning Pistol** (`fire.lightning.pistol`, fire's Storm twist; the owner: "we want both moves
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
- `nodes.<id>`: `false` takes that node out; it then reads as the move's own numbers. Absent counts as on. A node id in place of `true` (2026-10-12) turns it on while that node is live (`BendLoadout.why_not` "waits for ...", the window's dot the same): Washout and Cleanse wait for `earth.set.sulphur`, the only maker of the gas they wash (the test forces every node on for its own checks).
- `live`: the ids that may apply at all (the plan's resolvable ones and every talent built since: the tuning, class, bind and behaviour talents).
- `styles_live`: `["boxing", "taekwondo", "muay_thai", "karate", "wing_chun"]` (2026-10-16). Empty and no style plays.
- `classic_style`: see "How a loadout becomes live" step 4. **On since 2026-10-16**: the style picked for an element
  (the match setup's STYLE chips, the ring's Esc menu `Style` row, the window; `AdvancementStore.pick_style` sets Classic's
  class and the worn slot's) plays with Classic worn.
- `style_levers` (2026-10-16): the styles' perks, the design's six levers at 10% on the wearer's body moves
  (`BendLoadout.style_lock`, `style_moving`, `style_spec`, `style_class`; `docs/fighting_styles_design.md` "Live since
  2026-10-16"; `tests/ring/test_style_perks.gd`). `false` and the clips still play, no lever does.

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
- **Switched off (2) by this soak: Thick Wall and Thick Ice** (both switched on again on 2026-10-11 after their ring tests, still unsoaked). The bots never raise an Earth Wall or an Ice Wall in these matches (0 casts in 30 earth and 60 water games; they only answer a held stone with one), so the games they play are Classic's: the water baseline with nothing worn gave exactly the node's games (9 of 30, 78/67 lives, 3605/3755 casts), and the earth baseline gave 18 of 30 against the node's 17. The numbers apply and are tested end to end (the test builds the walls); but the gate cannot see them, so their 0.567 and 0.383 are the instrument's noise and not evidence either way. Thick Ice failed the gate at 60 games by that noise; Thick Wall passed it by it. Unverified is treated as not live: both are `false` in `nodes` (still in `live`, so `BendLoadout.why_not` says "switched off"). Flip them to `true` once a duel, a scripted match or a bot that walls has measured them.
- **How strict the gate is.** A fair node falls outside 0.40-0.60 at 30 games about 27% of the time and outside 0.45-0.55 at 60 games about 45% of the time (standard deviation 0.09 and 0.065), and the unworn baselines themselves read 0.600 and 0.300. Read the table as "nothing clearly wrong", not as a measurement of strength. The same configurations in a first pass (the foe kept between games, before the harness fix below) read 0.500 / 0.500 / 0.367 / 0.400 (air: Keen Edge, Dense Ball, Full Sail, the three), 0.600 / 0.633 / 0.433 (earth: Lie Low, Thick Wall, both), 0.600 (Thick Ice) and 0.500 (Quick Step).
- **Anomalies.** No bot crashed or stalled in any of the 330 games of the final pass (the longest game was 488 s of game time; each takes about 11 s of wall time headless, more when the machine is busy). No side was ever without casts, no self ring-out, and the loadout was found on the wearer at every check (59 of 59 per row, never missing, never on the other side). Three harness findings: (1) the first pass kept the same foe between the games of a run; its stale knock credit and old mind produced `NpcRingMind._on_landed` errors on a freed bot (29 in the Quick Step row only), so the soak now drops the foe between games (no errors since); (2) one Full Sail row was void: another task's menu script had a parse error while the run started (106 SCRIPT ERRORs, every ring script failed to compile), and it was re-run whole; (3) the simulation is not bit-for-bit repeatable for earth (stones are physics bodies), so the same seed does not replay an earth game exactly; water without a node cast replays exactly.


## Decisions taken while the owner was away

1. Classic plays nothing: a class picked with Classic worn is not played (`classic_style` false). The plan's text reads the class from `AdvancementStore.style_of`, which includes that case; the brief's rule that Classic plays exactly as today won. One flag to change it.
2. A hit's cost stays the move's data lock (above). A talent that shortens the wearer's lock does not shorten what a blow costs the victim, and one that lengthens it (Full Sail) does not lengthen it.
3. Quick Step's lock change is scoped to the Step mode (`move:footwork.lock_s` names the move; the node is the Step's).
4. (2026-10-10) Skate's Wet Trail was refused (its puddles were made by nothing), the two walls switched off (unexercised), see above. All three are on since 2026-10-11 (the water and earth talents passes).
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

## Fire's behaviour talents (11 October 2026, pass 1)

The owner, 2026-10-11: "we need to make sure all the talents work and they work in game right". Fire's talents whose effect
is new code are built in `scripts/bending/fire_talents.gd` (`FireTalents`) and live through `loadout_apply.json`
`behaviour` (each id, where its code is), `live` and `nodes`. Live on that word, **not soaked**. Each is played worn and not
worn in a ring by `tests/ring/test_talents_fire.gd` (`-- mode=ring practice=stand element=fire foe=fire`). Classic reads none
of it: every seam asks `FireTalents.any(body)` (one meta lookup) first.

| Talent | What the wearer gets | The seam |
|---|---|---|
| Hot Hands | a perfect Parry: the next Punch's lock begun within 1 s starts half full; late 60% through | `BendZone.report`, `SwayCaster._try_begin` / `NpcBending.begin` (`FireTalents.head_start`) |
| Two-Hand Rhythm | a Punch let go on the Beat (within 0.2 s of its click; never a click, never a grown cast): the next Punch 30% full within 1 s; a brief flash on his own hands. A bot lets go on the Beat only as often as its difficulty's `beat_rate` (bend_ai.json presets: easy 0, normal 0.2, hard 0.5; the tree's `beat.bots`) | SwayCaster's release, `NpcBending._release` (`FireTalents.beat`, `beat_worn`, `bot_beat_rate`) |
| Chain Kicks | a Kick on the Beat: the next Kick 40% full within 0.6 s (a head start keyed by move and mode: never the High Kick's or the air Slam's lock); Kick lock 0.65 s | the same |
| Grounded Charge | a hit breaks the Lightning charge: the next Lightning begun within 1 s starts half full | `SwayCaster.took_hit`, `NpcBending.tick` |
| Hot Feet / Dancing Feet | fill x1.1 moving and x0.9 standing / x0.9 moving, and x1.15 (the whole rate, moving or standing) for 0.6 s after a Step's own dash ends (a Jets dash is no Step). A bot gets both sides: its tick multiplies by `bot_fill_mult` (the fill passives and Footwork's on-the-move change, which a bot's lock has no other seam for) | `SwayCaster._moving_mult` (tune `rules:passives.fire.moving_mult` through `FireTalents.moving_mult`), `SwayCaster._hold`, `NpcBending.tick` (`FireTalents.bot_fill_mult`), `BendMotion._dash_end` (`FireTalents.dash_ended`: the Step's end) |
| Blazing Fireball | a burst 2 m wide (1 m round: `BLAZE_R`) where the grown Punch hits (a body, a raised wall, the deck; never a flight run out in the air), on whoever it touches (his capsule within it), its own class (`class_new`), not past the wall it hit, not on the one its core struck | `BendBolt._finish` (`FireTalents.bolt_ended`), `RingRules.on_hit` (`BendLoadout.new_hit_class`) |
| Crescent Burn / Ignite Step | a 2 m patch where the crescent ends / a 2 m line where the Step leaves, 1.5 s, floor fire | `BendBolt._finish`, `BendEffects._apply` (`FireTalents.cast`) |
| Scald | his fire through steam (a fire bolt; any fire cone of his, the Breath or the Jab's flame; a Fire Wall, floor fire or seam of his touching the cloud) makes it burn 1.5 s, with its own look meanwhile (flame and embers through the cloud) | `BendZone.on_bolt`, `BendEffects.cone` (`FireTalents.fire_cone`), a fire zone's `BendZone._every` (`FireTalents.zone_every`) |
| Curved Curtain | the Fire Wall as 4 pieces along a 120 deg arc, 5 m of curtain round the point aimed at (its middle on the far side), 4 s | `FireTalents.cast` |
| Forked Lightning | the strike forks to the nearest puddle, steam or water bolt within 6 m of its line: live 0.5 s, half the strike's % to everyone in it (no launch, no stun, no set-back) | `BendEffects._strike` (`FireTalents.struck`), rules.json `reaction/live` (`d_of_strike`) |
| Hold the Storm | a perfect Parry of Lightning with E held keeps it in his arms until E is let go (0.8 s at most), then along his aim at x1.2; fire goes back x1.1 | `BendEffects._strike` (`FireTalents.hold_storm`) |
| Magma (the set) | where the Kick's or the Axe Kick's wave dies (range, a wall) a 1.5 m seam for 3 s: matter/magma, 4% at most, two at once; water on it leaves a loose obsidian stone of his; a zone of kind mud quenches it; waves 16 / 14.2 m/s | `BendBolt._finish`, `BendZone` seam (`FireTalents.seam`, `seam_bolt`, `seam_water`) |
| Lava Kick / Magma Fist / Magma Landing / Forge | the Kick's last 4 m one seam / a seam where the grown Punch lands, and doused (a perfect Turn, or any water that puts it out as steam) an obsidian stone of his drops where it went out / a 2 m seam where the Jets land / x1.15 fill on his own seam, seams 2.5 s | the same, `BendBolt._finish` (why `steam`: `FireTalents.obsidian`), `BendMotion._dash_end`, `FireTalents.fill_mult`, tune `set:magma.seam_life_s` |
| Cauterize | Patch's key tapped twice: Cauterize (2% cost no Patch takes back, then up to 12% of the fresh pool back, gas within 1.5 m ends), lock 1.2 s; his Patch 1.7 s | `FireTalents.modes_for` (`Bending.other_move`, `SwayCaster.my_modes`), `BendEffects` heal, `RingRules.patch(b, max)` / `add_pct_kept` |
| Flashfire (pass 2) | gas he lights bursts bigger: 8% and a set 8 m/s at 45 deg (6 and 6), 1 m farther than the burst's 1.5x the cloud; the burst is his whoever made the gas; his Embers 6% (7); a bot wearing it wants its Embers x2 at a foe standing in gas | `FireTalents.flash_reach` (the burst's reach), rules.json `reaction/ignited_gas` through `BendLoadout.hit_class`; the burst itself `FireTalents.ignite` (lit by `gas_bolt` from `BendBolt`'s zone pass, before any zone's `on_bolt`; `gas_cone` from `BendEffects.cone`; `gas_every` from the top of a gas cloud's `BendZone._every`); after earth's `BendGas` is merged, fire still lights a Flashfire wearer's gas first, everyone else's is `BendGas`'s; `NpcBending._choose` (`FireTalents.bot_weight`) |

The floor fire and the seams are `BendZone` MATTER (a zone with a `tick_tag`): % only through rules.json `matter/burn` and
`matter/magma` (`no_flinch`, and `no_hurt`: `BendR3.take` and `BendStatus.hurt` skip the struck one's lock, so no set-back
and no Lightning-charge break), one tick each 0.5 s from all the matter a body stands in, capped per zone (3% a patch or line,
4% a seam), never to its owner or his side, and floor fire is jumped (feet more than 0.45 m over it). The Lava Kick node's
class change was written against the Kick's old base (5.8); its `from` is today's 9.5 and its `to` 10.5 (the node's +10%).

Flashfire (pass 2) is built against the Sulphur set's interface: gas is earth's matter, a `BendZone` of kind `gas`, round, its
radius the cloud's (the water lane's Washout and Cleanse use the same). Earth's set is not in fire's branch, so the tree's world
rule Ignited Sulphur (`skill_tree.json` `synergies` `ignited_sulphur`) is built here from fire's side as a stand-in, for anyone's
fire: a fire bolt (or an air bolt carrying a fire wall's flame) inside a cloud, a fire cone reaching one, or a fire wall, floor
fire or a seam touching one burns it at once (`FireTalents.ignite`; a Scald's steam is not fire): the cloud is gone and
everyone within 1.5x its radius from its middle whom the lighter may hit takes rules.json `reaction/ignited_gas` (6%, a set
6 m/s at 45 deg, away from its middle). Whoever lights it owns it (the % and the hit are his; never on him or his side), it
stales as the move that lit it (the hit's `stale_as`, a two-line addition to `RingRules.on_hit` that Classic never sends), and
it is called out IGNITED! at the callout spot (`data/ring/callouts.json` `ignited`, `RingHighlights.moment`). Until earth's
lane makes gas in a match, only Flashfire's trade (Embers 6%) shows in one; the test makes the clouds itself.

Earth's lane (`tb/talents-earth-p2`) built the set with its own lighting, `scripts/bending/bend_gas.gd` (`BendGas.react`,
`cone`, `every`, `ignite`: the same rule, 1.5x reach, the same class), wired into `BendZone` as its constant `BendGas`. Pass 2
lined fire's side up with it so the merge keeps one burst:
- rules.json `matter/gas` and `reaction/ignited_gas` and callouts.json `ignited` are the same lines in the same places as
  earth's, so they merge cleanly into one of each.
- `FireTalents.earth_gas()` is true once `BendZone` has the constant `BendGas`; fire's stand-in hooks (`gas_bolt`, `gas_cone`,
  `gas_every`) then step aside for every lighter but a Flashfire wearer (`FireTalents.lights`), and `BendGas` lights the rest.
- A Flashfire wearer's fire still lights the cloud in fire's code, and FIRST, so his burst keeps its 1 m farther reach
  (`FireTalents.flash_reach`) and its `stale_as` (the lighting move's tag) with **no edit to `BendGas.ignite`** (fix pass,
  12 October 2026): each of fire's hooks runs before the cloud's own rules. The bolt's is in `BendBolt`'s zone pass
  (`_physics_process`: `FireTalents.gas_bolt` before each zone's `on_bolt`, where `BendGas.react` is), the cone's in
  `BendEffects.cone` before the put-out block (earth's `BendGas.cone` call is after it), the fire zones' at the TOP of the gas
  cloud's `BendZone._every` (before `BendGas.tick` and `BendGas.every`); a cloud fire burns is ended (queued) at once, and every
  `BendGas` hook skips a queued cloud. The node's 8 and 8 come through `RingRules.on_hit` (the lighter's worn class) either way.
  Keep those three hooks where they are when merging (the merge of `bend_zone.gd`'s `on_bolt` head no longer carries a fire
  gas hook; its conflict is only fire's Scald/seam lines beside earth's Kiln Stone and gas lines: keep all of them).
- The world rule's own staling for every OTHER lighter ("a reaction stales as the move that set it off") is `BendGas.ignite`'s
  after the merge (earth's lane: its hit info would carry `stale_as`, which fire's two lines in `RingRules.on_hit` read).
- Gas clouds join the group `FireTalents.GAS_GROUP` in `BendZone.make` (earth's `BendGas.make` goes through it), so Classic's
  fire cones ask one group lookup instead of scanning the zones.
- `tests/ring/test_talents_fire.gd` (`only=flashfire`) checks a merged build on this branch by setting
  `FireTalents._earth_gas` to 1 as it will read: a Classic lighter's Embers, Breath and fire wall leave the cloud (BendGas's
  then), a Flashfire wearer's light it, his burst reaching a foe 4.25 m off and staled as his Embers. Its clouds are made by
  `BendZone.make(owner, "gas", ...)`; after the merge `_gas` raises `BendGas.live_n` for them.

**Smoke soak of fire's behaviour talents (pass 2, 12 October 2026)**: `tools/ring/loadout_soak.gd` with bots wearing them
(mirror fire matches, normal bots, seed 7300), to look for errors and stalls in real bot play, not the fairness gate (30 games a
node). Run A, the 19 behaviour talents but Dancing Feet worn together, 6 games: 3 wins of 6, 729 casts by the wearer, no script
error, no stall; worn 17 of 19, because two picks are refused when worn together: Magma Fist (the tree's excludes: Magma Fist and
Blazing Fireball never together) and Forked Lightning (it and Grounded Charge both lower the Lightning's 25%, to 22 and 23; in
this branch two picks setting one number clash; earth p2's stacking rule in `BendLoadout.overlay_for` multiplies them, 20.24,
once merged). Run B, Forked Lightning, the Magma set, Magma Fist, Dancing Feet, Flashfire and Cauterize, 4 games: 2 wins of 4,
worn 7 of 7, no script error, no stall, LOADOUT SOAK DONE.

**Fix pass (12 October 2026, `tb/talents-fire-fix`)**, after the verifier's read of pass 2:
- Blazing Fireball's burst was 2 m round plus 0.35 m slack (about 4.7 m across); it is now 2 m wide (`BLAZE_R` 1 m, on whoever
  it touches: his capsule, 0.3 m round, within it), and only where the Fireball hits (a body, a raised wall, the deck), never
  where its flight runs out in the air.
- Magma Fist's "a perfect Turn douses it (an obsidian stone drops)" is built: a ball of magma put out as steam drops a loose
  obsidian stone of its caster's where it went out (`FireTalents.obsidian`, the same stone a cooled seam leaves).
- Flashfire: see the merge notes above (fire lights a wearer's gas first; no edit to `BendGas.ignite`). Gas exists in a match
  only once earth's Sulphur set is merged; on this branch alone only its trade (Embers 6%) shows in a match.
- Hot Feet and Dancing Feet now reach a bot whole (`bot_fill_mult`: a bot had the standing side only); Dancing Feet's x1.15 is the
  whole rate for 0.6 s after a Step, on the move too (it was x0.9 x 1.15), and only the Step's own dash end starts it (a Jets dash
  after a Step did too).
- Chain Kicks' head start is keyed by move and mode: a High Kick or the air Slam after a Beat Kick starts empty.
- Bots let go on the Beat as often as their difficulty's `beat_rate` (bend_ai.json presets: the same lines as the water lane's,
  so the files merge as one), not on every release.
- Scald: any fire of the wearer's through steam (a fire bolt, a fire cone, a Fire Wall, floor fire or a seam touching the cloud),
  and the scalding cloud has its own look while it burns (flame and embers through it).
- Cauterize's bot lock reads Patch's `ring_lock_s` from moves.json (it had 1.5 written in); two doc comments in `bend_zone.gd`
  are back over their own functions.
- Left as they are (general, not fire's alone): online a loadout is worn only on each machine's own player, so the matter a talent
  makes is the host's where it is decided there (seams, patches, bursts, Forked's live water, Scald's zone) and every machine's
  where the cast makes it (Ignite Step's line, Curved Curtain's pieces); making them agree needs the loadout sent over the wire.
- `tests/ring/test_loadout_apply.gd`'s lines that wear a node with the nodes it requires are now word for word earth p2's (`with`),
  so they merge with earth's cleanly; fire's own addition below them (the required nodes' spec changes counted as named, which
  Lava Kick needs beside the set's Kick speed) reads that `with`. Water's and air's versions of those lines differ: keep earth's
  and fire's at the merge.

Air's behaviour talents (Tailwind, Drift Guard, Eye of the Gale, Rebound and the rest as they are built) and Full Sail switched on again: `docs/tidebreak/talents_air.md`.

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
worn in a real ring by `tests/ring/test_talents_earth.gd` (167 checks after the fix pass of 2026-10-12, below), the bot's side
too. Live on the owner's word, not soaked. Juggle is switched off (the fix pass: its plus is the Classic Catch's).

| Node | What the wearer gets (code) |
|---|---|
| Thick Wall (switched on) | 5 hits, 2.5 m wide, raised and shot down in a ring |
| Juggle (switched OFF, the owner's call) | his Catch holds two stones of one window side by side, E throws the oldest, a third drops at his feet; full catch 0.8 s (`BendZone.held_stone`, `held_stones`; the spec's `window_s`; `stock:guard_catch_s` only in `RingRules.guard_outcome`, the spec's reference, which no game code calls) |
| Return to Sender | a clean catch thrown back with E pressed within the Beat of the catch flies x1.15; late return lock 0.4 s (`BendZone.return_stone`, `beat_return`) |
| Kick-Up | a Pebbles volley that meets nobody leaves one loose stone where it lands (`BendBolt._kick_up_end`) |
| Avalanche | the Boulder landing on the deck breaks into three low rolling stones fanned 15 degrees, one volley of 3, the first to hit knocks at base 5.9 (the class changes are marked `when: avalanche`: the Boulder's own hit before it lands keeps 7.4); a Catch holds one, the rest drop at the catcher's feet (`GustLift._avalanche`) |
| Heave | a Column let go on the Beat launches with base 11.3 (a class change marked `when: beat` in the tree: `BendLoadout` `class_when`); lock 1.7 s |
| Kiln Stone | his stone through any Fire Wall, burning ground or magma seam is heated until it lands: base x1.15, a fire trail; a stone he caught and throws back counts (its return class through `BendLoadout.hit_class` too); a Parry on the beat sends it back, a Turn douses it (`BendBolt.heat`, `GustLift._kiln_check`, `BendZone`) |
| Rubble Wall | his wall shot down or capped leaves two loose stones at its foot; rise 0.8 s (`FormRaised._rubble_stones`) |
| Quarry | his Beat Fissure into his own wall tears a chunk off and throws it on, the first chunk free; rise 0.8 s (`BendBolt._quarry`) |
| Reinforce | a mended piece takes its next two hits free (`FormRaised.take_brace`); Mend's lock 2.6 s |
| Sulphur (set) and Sulphur Spike, Sulphur Boulder, Fuming Column, Brimstone Wall, Flint Pebbles, Sulphur Heart | gas: `scripts/bending/bend_gas.gd` (loaded by path, a BendZone of kind `gas`); see its header |

**The Beat** (the tree's timing rule; the owner's answer: yes) is built once for all techniques: a held cast let go within
`beat.window_s` (0.2 s) of its lock filling, for a wearer of a technique that pays on that move and mode only
(`BendLoadout.beat_paid(body, move, mode)`: a built node whose new code names the Beat pays on its own `extends_move`/`mode`,
"A <move> let go on the Beat", unless `loadout_apply.json` `beat_on` names others: Quarry's Fissure, Return to Sender none,
its Beat being the Catch's E again). SwayCaster and a bot's release put `beat` on the hit's info (`BendR3.info_for`); a brief
glow on the caster's own hands (`BendLooks.beat_flash`). His other casts get nothing. Classic: nothing, not even the look. A
bot wearing a Beat technique (only a test's: bots wear no loadout in a match) hits it at its difficulty's `beat_rate`
(`bend_ai.json` presets, the tree's `beat.bots`: easy 0, normal 0.2, hard 0.5; `NpcBending._beat_roll`, its own dice), and on
a miss holds the full lock past the window (Return to Sender: its E again past it).

**New BendLoadout kinds** (additive): `set:<set>.<key>` tune paths (a skill set's zone rule, read from the tree's
`skill_sets`), `stock:guard_catch_s`, a class change `when: <flag>` (`class_when`: only on the wearer's hits whose info
carries the flag; `beat`, `avalanche`), `default_from` for a class's `volley_n`
beside a node's own new code, and a modeless move's lock (Mend). `test_loadout_apply.gd` wears a node with the nodes it
requires, reads a Beat class on a Beat hit and a `default_from`'s default.

Pass 2 finished the set's reactions as its text and the tree's world rules say: a cone reaches gas by its kind (Breath and a
fire Sweep or ring light it, the Lash and the Wave wash it, the air Palm carries it); a Fire Wall or burning ground on a cloud
lights it and a Wind Wall on one carries it off its face once (`BendGas.every`, the cloud's own look round); lightning through
a cloud charges it (Live Gas: half the strike's % on everyone inside, % only, the gas stays: `BendGas.live` from
`BendEffects._strike`); the burst reaches 1.5x the cloud's round; wind carries a cloud 4 m (was 3); IGNITED! is called out at
the callouts' own spot (`data/ring/callouts.json` `ignited`, a RingHighlights moment). Every hook asks `BendGas.live_n > 0`
first, so Classic (no gas ever) is untouched. Magma seams (the fire lane's Magma set, zone kind `seam`, not in this branch)
are wired by their kind alone (`BendZone.KILN_FIRES`): a seam heats a Kiln Stone skimming over it and lights gas over it; the
earth test plays it with a stand-in seam made as the fire lane's maker makes one.

## Earth's behaviour talents (pass 2, 2026-10-11): the Sulphur Vent, and new skills for every element

Branch `tb/talents-earth-p2`. **Sulphur Vent** (`earth.sulphur.vent`, worn with the set): 4 tapped twice readies it; the deck
cracks where his crosshair is (2-6 m, placed like a wall) and breathes a 3 m cloud for 4 s (the set's gas: one cloud's cap,
6%, its ticks and reactions; his own never hurts him); lock 0.9 s; one vent of his at a time (his other gas stays). Trade: his
Earth Wall rises in 0.8 s. Its spec is `moves.json` `earth_wall.talent_bend.vent`; `BendEffects.zone` hands a gas zone to
`BendGas.vent`. The vent's numbers are its own (Flint Pebbles' 2.5 s and Sulphur Heart's 2 m are the set's clouds').
`tests/ring/test_talents_earth.gd` plays it (the hotbar's own double tap, the player's real lock, the bot in a fight).

**New skills on the empty double taps, built once** (`BendLoadout`, the end of the file; the owner's yes to the draft). A
node of kind `new_skill` adds a mode of its move for its wearer alone. Its spec lives in `moves.json`
`<move>.talent_bend.<mode>`: a bend spec plus `talent` (the node id), `lock_s`, `label`, `pose_as` and `ai` (a bot's hint over
`bend_ai.json`'s). Never in `modes` or `bend`, so the static kit (`SwayCaster.modes_of`), the Classic fingerprint and every bot
of a normal match never see it. Seams, each answered with one meta lookup for a body that wears nothing:

| Seam | Callers |
|---|---|
| `modes_for(body, id, base)` | `SwayCaster.my_modes`, `Bending.other_move(key, id, mode, body)` (the hotbar's double tap and wheel step, `SwayCaster.step_other` and `_dash_switch`), `BodyBendCaster.mode_of` |
| `talent_pairs(body, el)` | `NpcBending._build_options` (rebuilt by `_talent_options` when what the bot wears changes) |
| `talent_spec(body, m, mode)` | `SwayCaster.spec_of`, `FormEffects.apply`, `BendCast.cast` |
| `talent_lock(body, m, mode, base)` | `SwayCaster._lock_time`, `NpcBending.lock_for` |
| `pose_mode(body, m, mode)` | `BendPoses.pick` |
| `talent_label(m, mode)` | `SwayCaster.mode_label`'s fallback |

The air lane's Dust Cloud (`AirTalents.extra_modes`, `talent_spec`, ... over the same `moves.json` `talent_bend` layout) and
the fire lane's Cauterize (`FireTalents.modes_for`, its spec in code) built their own copies of this seam at the same call
sites. Merging, keep these generic lines: they read any move's `talent_bend` whose `talent` is worn, so Dust Cloud works
through them as it is (its spec already has `talent`), and Cauterize once its spec moves to `patch.talent_bend.cauterize`.
`KitWords.key_moves(el, i, body)` and the radial wheel (`RadialWheel.items_for(el, body)`) take the player's body (the fix
pass, 2026-10-12): his strip and wheel show the Vent on 4's double tap; with no body (the menus, the how-to) the static kit.

**Picks worn together, as the tree says** (`BendLoadout.overlay_for`; the tree's `stacking` and `excludes`). Before, a number
two picks both set was refused for the second ("set by the first only"), so Rubble Wall with Quarry or the Vent, or Clean
Return with Return to Sender, silently lost one pick in a match. Now: two picks that change one number the same way from the
same base multiply their ratios (Rubble Wall and Quarry: the rise 0.7 x 0.8/0.7 x 0.8/0.7 = 0.914 s; Clean Return and Return
to Sender: the return lock 0.48 s), and a set twist's number is final for that move (the Vent with Rubble Wall: 0.8 s); two
that pull it opposite ways, a pose or a whole class set twice, are still refused; a pick the tree's `excludes` keeps from one
already worn (either way) is refused (Heave and Fuming Column, Thick and Brimstone Wall, Heavy and Sulphur Boulder: before,
Heave and Fuming Column both applied, one a class and the other a Beat class). Each number keeps its `from` and whether a set
twist set it beside it (`_put_n`, the resolve's `from`); `_fold_n` and `_stack` fold them. `test_loadout_apply.gd`'s clash
check now pulls the opposite way and a second check stacks the same way; `test_talents_earth.gd` (combos) plays earth's.

## Earth's fix pass (2026-10-12, the verifier's findings)

Branch `tb/talents-earth-fix` (from `tb/talents-earth-p2`). What changed, all for wearers only (Classic's fingerprint passes):

- **Kiln Stone, returns**: `RingRules.on_hit` hands a returned hit's class (`return_class`) to `BendLoadout.hit_class` too, so a
  stone a Kiln wearer caught and threw back through fire knocks with base x1.15 (it already came out heated). A return's tag
  (`<origin>.return`) is no class a node changes, so only the heat reaches it. Tested in a ring (the bot's stone caught, thrown
  back through its Fire Wall: x1.15 over Classic's same return).
- **Juggle switched off** (`nodes`: false; its code kept and tested under `config_override`): as written its plus ("hold two
  stones, E throws the first, E again the second") is the Classic Catch's, which holds every stone of its window and throws one
  an E, so worn it was only its minus (a third stone dropped, full catches 0.8 s). The owner's call: what its plus should be (a
  proposal: E throws both held stones at once as a pair; or a held stone kept past the window's end; or cut it).
- **The Beat pays only its technique's own cast** (`beat_on`, above): before, any of the wearer's held casts let go within
  0.2 s flashed, clicked and carried `info.beat` (an RTS wearer's Pebbles), and another lane's Beat node would have switched
  it on for all its wearer's casts at merge. Bots: `beat_rate` per difficulty (above).
- **Avalanche's class numbers are the rolling stones'**: the tree's two class changes are marked `when: avalanche` (the stones'
  info says avalanche), so the Boulder's own hit before it lands is Classic's (7.4), as its text and identity say ("at 80% of
  its base" is the first stone's; "one Boulder until it lands"). Tested: the Boulder's own hit equal worn and not, three stones
  rolled into the bot, one knock, at base 5.9.
- **Sulphur Boulder's trail is laid as it flies**: each puff on the deck under the Boulder as it passes its mark
  (`GustLift._trail`, the flight foreseen from the hurl: `BendGas.trail_step`), never in the air over the water
  (`BendGas.trail_puff`: no deck within 1.5 m of the hurl's deck under it, no puff); a flight cut short lays the rest where it
  stops.
- **Sulphur Heart online**: `BendGas.live_n` is counted by `BendZone.make` for every gas zone, so a joiner's machine (its gas
  made from the host's word) sees its own gas: his lock fill x1.15 there too.
- **The Vent in the kit readers**: `KitWords.key_moves` and `RadialWheel.items_for` take the player's body (his strip's key 4
  says "tap twice: Sulphur Vent", his wheel offers it); with no body, or wearing nothing, the very static kit as before.
- **The soak**: `nodes=all` wears the element's live nodes the tree lets go together (an excluded later pick named and left
  out: earth's Swift Roots, Sulphur Boulder, Fuming Column and Brimstone Wall beside Deep Roots, Heavy Boulder, Heave and
  Thick Wall), so earth's all-nodes soak no longer reports a missing loadout (`element=earth nodes=all n=2`: worn_ok 3/3,
  LOADOUT SOAK DONE).
- **Tests**: `test_talents_earth.gd` 167 checks (was 142): the above, live hits for the class numbers (Pebbles 4%, Spike 12%,
  Boulder 13%, Fuming Column base 9.3, Avalanche 5.9), the bot wearing Kick-Up and each Sulphur twist, the bot's Beat rate.
  `test_loadout_apply.gd` reads any `when` class with its flag (not only `beat`); its LIVE lists untouched.

**For the merge** (all four lanes): `BendLoadout.overlay_for` now stacks two picks that change one number the same way (ratios
multiplied, a set twist's final) and refuses the tree's `excludes` (earth p2): pairs another lane's test expected refused will
stack. `class_beat` became `class_when` (a flag layer over it). `beat_paid` takes the cast's move and mode; called with the
body alone it still answers "pays on any held cast".

## Water's talents (11 October 2026, the talents pass, lane water)

The owner, 2026-10-11: "we need to make sure all the talents work and they work in game right". Each is worn by one fighter alone,
read where the game does the thing (BendLoadout.wears, its own numbers through tune or new_class), and played in a real 1v1 %
ring by `tests/ring/test_talents_water.gd` worn, not worn and on a bot. Classic never reaches any of it (the golden fingerprint
of `test_loadout_review.gd` still passes).

| Talent | What the wearer gets | Where |
| --- | --- | --- |
| Thick Ice | switched on: his Ice Wall takes 4 hits, rises in 0.8 s (a wall raised and shot with ice in the test) | `BendEffects._wall` (as before) |
| Washout | (waits for the Sulphur set) his Splash and Lash wash out a gas cloud they fly through and fly on; Splash 3.5% | `BendZone.on_bolt` gas, `BendZone.washes`, `BendZone.wash` |
| Splashdown | where his Lash stops (on a body, a raised wall, a zone's wall: a Fire Wall it puts out, a Water Wall that drinks it, the deck) a 1.2 m puddle of his for 6 s, a Geyser source; met head-on in the air by fire, none; Lash 8% | `BendBolt.end` (`zone_wall`, set by `BendZone.on_bolt`) |
| Steamcraft | steam his water makes with fire is his, hangs 2.5 s and drifts 3 m toward his aim; Lash 8% | `BendBolt.meet`, `BendBolt.steam`, `BendZone` steam drift |
| Cleanse | (waits for the Sulphur set) while his Turn stands, its perfect part and its late part alike (the node's "perfect or late"; its change: "a standing Turn ends gas zones within its radius"), a cloud with gas within 2.2 m of him is washed out (a cloud is one zone: one whose gas begins past 2.2 m stays; not an ally's); Turn lock 0.24 s | `BendZone._every` redirect |
| Whirl Turn | E held through a perfect Turn: the water circles him up to 0.6 s, let go it leaves along his aim; late 60% | `BendZone._guard_bolt`, `BendBolt._swing`, `BendZone.whirl_held` |
| Eddy | his Lash or Spear begun within 1.2 s of a perfect Turn starts 40% full; his Turn's beat 0.25 s | `BendZone.report`, `eddy_fill`, `SwayCaster._try_begin`, `NpcBending.begin` |
| Pooling Wave | his Wave leaves a 1.2 m puddle of his for 6 s on the deck where its cone ends; Wave base 6.8 (grown 7.6) | `BendEffects._wave_talents` |
| Ride the Wave | his Wave let go on the Beat (held, let go within 0.2 s of the click) carries him 3 m on behind the water, deck only, the Beat's flash on his own hands; a hit during the ride ends it (knocked as anyone); Wave lock 0.65 s | `SwayCaster._cast` (BendR3.release beat), `BendEffects._wave_talents`, `BendMotion.ride` / `_ride_step` |
| Wet Trail | his Skate leaves 4 puddles of his for 7.2 s spread along its slide (one each 0.9 m slid, the last no later than where it stops) and travels 10.8 m/s | `BendEffects.dash`, `_wet_trail` |
| Wellspring | Patch's ring lock 1.25 s in his own puddle or at a grate, 1.6 s anywhere else (as it begins) | `SwayCaster._lock_time`, `BendZone.in_own_water`, `NpcBending.lock_for` |
| Mud (set) | his puddles (Downpour, Splashdown, Pooling Wave, Wet Trail, Mudslide) are mud pools of his for 8 s, still sources, 4 at once: a floor wave of fire dies in one, a fire wall over one burns 2 s and dries it in 1 s, a magma seam over one is quenched, a rolling stone stops; nobody is slowed; Splash 25.2, Lash 30.6 m/s | `BendZone.make`, `_mud_every`, `on_bolt` mud |
| Mud Lash | (with the set) Lash 28 m/s, adds 10%, base 5.3; fire it meets is smothered, no steam; clods off it | `BendBolt.meet`, `BendBolt.launch` |
| Mudslide | (with the set) Wave base 8.6 (grown 9.7), reach 7.5 m (10); a 2 m mud pool of his where it ends | `BendEffects._wave_talents` |
| Mud Mound | (with the set) the Geyser leaves a mud mound 1.5 x 0.7 m for 3 s where it rose (a FormRaised of mud marked `bend_mound_by`, never `bend_by`: nobody's wall for Mend, a bot, Brace, the lessons or max_walls; two at once; never a wall where any raised wall would be one: a bot's wall on its line, a Shove's chunk, `BendEffects.is_mound`): floor fire stops at it, anyone can stand on it; Geyser base 9.3 | `BendEffects.spout`, `_mud_mound` |
| Delta | (with the set) his locks fill x1.15 standing in his own mud (a bot's tick too); his mud pools last 6.5 s | `SwayCaster.passive_fill`, `BendZone.in_own_mud`, `home_fill`, `NpcBending.tick` |
| Mire | (with the set) a new skill on 4 tapped twice (the strip and the wheel show it): lock 0.9 s (the Ice Wall's 0.85), a 3 m mud pool of his for 8 s (Delta's 6.5) placed where he aims, 2-6 m like a wall, cast with the Ice Wall's pose, on the deck only; one of his at a time (a second dries the first), never one of the set's four pools; what his mud does (floor fire dies in it, his Geyser's source, Wellspring's and Delta's water); his Ice Wall rises in 0.8 s | `BendLoadout.modes_added` / `new_spec`, `SwayCaster.modes_of` / `spec_of`, `Bending.other_move`, `FormEffects.apply`, `BendCast.cast`, `BendEffects.zone`, `BendZone.make` (`MIRE_META`), `BendPoses.pick` |

Bots (never worn in a normal match): a bot wearing Whirl Turn holds the swing while the foe it aims at stands guarding and sends
it on when he cannot; a bot wearing Eddy begins its next Lash 40% full; a bot wearing Ride the Wave lets its Wave go on the Beat
when its foe is further than 4.5 m and the deck has room ahead (NpcBending._on_beat); a bot's Patch lock takes Wellspring's share;
a bot wearing Mire has it among its options (built again when what it wears changes) and lays one 4-14 m from a foe whose kit has
floor fire (fire's Kick), never against another, once in 9 s at most (its spec's own `ai` hint, `foe_floor_fire`); the rest are its
casts' own.

The Beat (skill_tree.json beat, the owner's yes): SwayCaster marks a cast held and let go within `BendLoadout.beat_s()` (the
tree's 0.2 s) of its click (never a click, a guard, key 3, Patch or a cast that goes by itself) as `beat` in `BendR3.release`
while it lands (its hits' info too), and only for a wearer of a technique it pays (`BendLoadout.beat_paid`: Ride the Wave), so a
Classic cast never carries it. Its cue is the tree's: a click and a brief flash on his own hands (`BendLooks.beat_flash`, the same
as earth's lane) where it pays (the ride), with Ride's foam at his feet. A bot wearing it takes the Beat at its difficulty's
`beat_rate` (bend_ai.json presets: easy 0, normal 0.2, hard 0.5, the tree's beat.bots). Online the beat is the caster's machine's
(the ride is his own motion).

Data fixed: Wellspring's two changes both named `stock:patch.lock_s` (a number no code reads, and one path twice can't be two
numbers): they are now `new:patch.lock_wet_s` (1.5 to 1.25) and `new:patch.lock_dry_s` (1.5 to 1.6), Patch's ring lock
(moves.json patch.ring_lock_s), with a `new` entry for the where-he-stands rule. Wet Trail is no longer refused: the Skate's
puddles are made for its wearer only (Classic's Skate still leaves none).

Washout and Cleanse act on gas, the Sulphur set's matter (earth's skill set, built in earth's lane, tb/talents-earth-p2): they are
built against its interface, a `BendZone` of kind `gas` (round, `ROUND_NEW`). Their switch in loadout_apply.json names
`earth.set.sulphur` (2026-10-12): with no Sulphur set live a match never holds gas, so they are refused whole (no trade with
nothing to wash); once it is live they are too. Gas then comes only from a Sulphur wearer: online, against a human who wears it
(bots wear no loadout). The test switches them on and makes stand-in clouds. The Washed Ground synergy's base (the tree: "a Wave
or a Geyser washes out the gas it passes", for everyone): the Geyser here (`BendEffects._wash_gas`), the Wave's cone in earth's
lane (`BendGas.cone`). **Merge note:** earth's `BendGas.react` washes gas with any water bolt, everyone's Splash and Lash: that
makes Washout's plus everyone's. Per the tree its water branch should wash only when `BendZone.washes(b)` (Washout's wearer's
Splash and Lash), else let the bolt fly on through. Cleanse's "draws on the dormant water_redirect cleanse" is the tree's source
note (each twist names the dormant mode it draws on); what is built is the gas wash its effect states. The dormant spec's own
effect (BendEffects "cleanse": a root and a slow cleared on the caster) is not cast: in the % ring a root is a bind, and lifting
one is not in the node.

BendLoadout, for these: picks worn together follow the tree's stacking (skill_tree.json same_answer_gate.stacking; 2026-10-12, the
same `_fold_n` / `_stack` / `_excluded` as earth's lane): two that change one number the same way from the same base multiply their
ratios (Splashdown and Steamcraft both worn: the Lash adds 9 x 8/9 x 8/9 = 7.1%, both trades paid), a set twist's number is final
(Mud Lash's 28 m/s over the Mud set's 30.6, Mire's 0.8 s rise beside Thick Ice's), the other way is refused (Drench's 6.5 and
Mudslide's 8.6 Wave base: the later pick applies nothing), and the tree's excludes refuse a pick either way. (The first water pass
had a node that requires others overwrite every number already worn, and an equal number set twice pass as one: both gone.) A
`set:<set>.<key>` change of a behaviour talent is read from skill_tree.json skill_sets (Delta's mud life; `set_rule(set, key)` as
earth's); a behaviour talent may set spec keys no Classic code reads (the Skate's puddles).

The Mud set's other counters are built against the other lanes' interfaces: a magma seam is a `BendZone` of kind `seam` (fire's
Magma set): over mud it ends "quenched", no stone (fire's lane, tb/talents-fire-p2, does the same from the seam's side,
`FireTalents.seam_water`: after the merge both act on one seam with one outcome, one of them redundant). Live Water's grounding:
Live Water is fire's Forked Lightning's (`FireTalents.struck`, fire's lane), whose fork reaches only zones of kind puddle and steam
and water bolts; a mud pool is kind mud, so it is never made live: grounded by construction once merged, nothing to build here (no
branch has Live Water before that merge). Rolling stones: a FormStone rolling into his mud stops (the open world's; in the % ring a hurled
stone shatters where it lands), and so does a stone bolt rolling along the deck (a low stone bolt: earth's Avalanche, built in its
lane; `BendZone.on_bolt` mud, 2026-10-12); Classic has neither in a ring. What the set does in a ring match today: his puddles are mud pools for 8 s
(the Downpour's, Splashdown's, Pooling Wave's, Mudslide's, Mire's, Wet Trail's: Classic's Skate leaves none, so the text's "from
Skate" holds only with Wet Trail worn), a Kick's floor fire dies in one, a Fire Wall over one burns 2 s and dries it, 4 pools at
most, Splash and Lash 10% slower.

The fix pass (2026-10-12, tb/talents-water-fix): Ride the Wave no longer eats a knock (the ride kept the body's velocity as its own
every frame, so a hit's launch was taken out twice: a sideways 8 m/s hit 3 frames in moved him 0.02 m; now a knock ends the ride
and the ride keeps the knock's carry in his velocity, `BendMotion._ride_step`); the Beat flag and cue as above; Washout and Cleanse
wait for the Sulphur set; the Geyser washes gas; Wet Trail's puddles spread along the slide; the Mud Mound is nobody's wall; the
tree's stacking replaces the first pass's fold; the test checks each launch against the formula with the node's own numbers, reads
the Cleanse and Wellspring locks from the player's real E and key 5, plays Mudslide grown, hits a rider and wears picks together.
Second fix pass (same branch): Splashdown's puddle where a zone's wall stops the Lash (a Fire Wall it puts out, a Water Wall), none
where it meets fire in the air; Cleanse's 2.2 m measured from him (a cloud with gas within it), checked against a cloud just inside
and one just past; the Mud Mound is no wall to a bot's wall-on-line reader or a Shove (`BendEffects.is_mound`), and its floor-fire
check now stands both fighters on the deck either side of it with a no-mound control (the Kick ends at the mound, +0%; with it gone
the same Kick hits, about +13%) and a real raised wall in its place as the readers' control.

Mire (water.mud.mire) is a NEW MODE a worn talent adds (the tree's new skills on empty double taps, the owner's yes): its spec
cannot go into moves.json (the Classic fingerprint lists every bend spec), so it is the node's own change `new:mire.spec`
{move, mode, label, lock_s, pose_as, bend}. BendLoadout reads it for the wearer alone: `modes_added(body, m)` (SwayCaster.modes_of
and Bending.other_move take an optional body: the keys, the strip, the wheel and a bot's options see the mode; with no body or
nothing worn the same array as before), `new_spec(body, m, mode)` where a cast reads its spec (SwayCaster.spec_of and needs_ground,
FormEffects.apply, BendCast.cast, NpcBending.spec_of), its lock_s in the lock part (SwayCaster._lock_time and NpcBending.lock_for
as any node's lock), pose_as (BendPoses.pick: the Ice Wall's clip) and its label (SwayCaster.mode_label). Not worn, 4 tapped twice
is the Ice Wall as ever. Its "Skate" source has nothing to act on in a ring match: no Skate reads a water source there. Online:
a remote player's loadout is not on his puppet (the older limit), so a joiner's Mire is not made on the host yet.
