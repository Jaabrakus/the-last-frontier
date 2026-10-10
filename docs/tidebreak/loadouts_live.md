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

## Tests and commands

```
# the test (headless): the switches, every live node's numbers on a wearer and on a bot, Classic's identity, the styles, the
# ring scene with a worn slot (real casts), the save never written
zsh tools/loop/run_test_fps.sh /Users/kiwimango/Downloads/Frontier loadout_apply tests/ring/test_loadout_apply.gd

# the soak: one config per run; n games, the wearer alternating sides; nodes=all for the element's live set
zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path /Users/kiwimango/Downloads/Frontier -s tools/ring/loadout_soak.gd -- element=air nodes=air.slice.keen n=30 seed=7300
grep "LSOAK RESULT" <log>

# a Classic-vs-Classic baseline (nodes= empty)
zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path /Users/kiwimango/Downloads/Frontier -s tools/ring/loadout_soak.gd -- element=air nodes= n=20
```

A game is about 11 s of wall time headless. `GODOT_TIMEOUT=1500` for 30 games per run. The soak forces on the nodes it is asked for (so a switched-off node can be re-measured) and takes the seeds from `seed=` (game `g` uses `seed + 101 g`).
