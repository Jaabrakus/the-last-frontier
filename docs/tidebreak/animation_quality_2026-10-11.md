# Animation quality pass — night of 10–11 October 2026

The owner, going to sleep: "a animation quality re run make sure they are smooth". This pass re-ran the 8 October fluidity
checks on the evening's code (hold to cast, the Fissure, the Air Lance and its spear throw, fire's kicks freed at the
strike), measured what was left, and fixed what popped. Our own clips only; nothing imported or retargeted; no clip file on
disk was edited.

## Fixed

| What | Before | After | How |
|---|---|---|---|
| Bots' casts cut in when sped up: a bot plays its cast clip faster to strike on time (up to 20x), and the blend ran on the clip's clock, so a 0.1 s blend could finish in one frame | 0.076 m jump at a short wind-up (0.026 around it) | 0.022 m | `NpcBody._real_blend`: a blend is the same real time at any playback speed (loops too) |
| Three movement loops popped at every wrap (walk forward-right, backward sprint right and left) | 0.12, 0.15 and 0.24 rad jumps at a foot joint each cycle (the tree builder warned on every load) | ends meet (≤ 0.001 rad), no key step steeper than the clip's own | `TreeBuilder.close_seam`: the last 0.2 s of a looped clip whose ends differ eases into its first frame, in the loaded clip only (the file untouched); the additive bank takes its difference after the closing. `tests/anim/test_loop_seams.gd` |
| Fire's Kick and High Kick: after the strike the caster walks off, but the kick's legs kept playing (full-body clip) — the feet slid | legs layer 1.0 while walking | legs give way to the walk's with speed (0.30 at 0.9 m/s), the upper body's recovery kept | `SwayPose`: a pose rooted to its strike that has struck splits into upper body + legs-by-speed, like every other cast. `tests/bending/test_bend_poses.gd` (walking off) |
| The Air Lance used the Gust's two-hand sweep | — | when the Gust grows, the hold winds up into the overhand spear throw (the Ice Spear's clip; the 80 ms cast hand-off blends it); bots throw it the same way | `SwayPose._on_grew`, `NpcBody.play_cast(grown)`, poses.json `air_gust.gust.grow` |

## Re-run of the 8 October checks

| Check | Result |
|---|---|
| Cast hand-offs, interrupted blends, masks, landing contacts (`tests/bending/test_cast_pose_handoffs.gd`) | 30/30 |
| Ring pose transitions (`tests/bending/test_ring_pose_transitions.gd`) | 12/12 |
| Bending pose integration (`tests/bending/test_bend_poses.gd`) | pass (with the kicks' walk-off) |
| Tree build (`tests/anim/test_tree_build.gd`) | 97/97 (its seam check updated: the fall clip no longer loops in the graph) |
| Loop seams (`tests/anim/test_loop_seams.gd`, new) | 19/19 |

## Pop hunt (new tool: `tools/anim/pop_hunt.gd`)

Real % ring matches, headless, the player played by the film's expert input against a bot of another element, one minute per
element; every drawn frame each fighter's key bones are sampled in the skeleton's own space, and a pop is a one-frame jump
(over 6 cm and 3x the steps either side). Sampled per drawn frame, not per physics tick: the physics runs at 120 Hz and
poses update at 60, so a per-tick sample reads every move as a spike (the first run's 35,000 "pops" were that).

| Who | One-frame jumps a minute | What they are |
|---|---|---|
| The player | about 1-2 (4-8 in a 4-6 minute run, all elements) | small (≤ 0.19 m), scattered over casts; nothing systematic |
| Bots | about 200-360 | about half the struck contact pose (below); gait switches (walk to run, run to sprint), mostly 0.06-0.15 m; a few cast starts |

Left as they are, with the reasons:

- **The struck contact pose snaps in by design** (a hit shows its contact frame at once, the player's the same). Tried a
  0.06 s blend into it: worse (0.27 m steps instead of 0.09), because it eases toward a pose that is moving. If the owner
  wants the snap softer, the contact clips themselves need a lead-in.
- **Bots' gait switches** (walk to run) jump up to about 0.15 m on the switch frame in a match, but the same switch made by
  hand on the AnimationPlayer (with the bot's speeds and its phase-matched entry) is smooth; the cause is still to be found.
  Small and brief at play distance.
- The older weapon suites (musket, pistol, bow: shot cancels, holster switches, run rates) fail as they did before tonight:
  the same failures with and without these changes (tests/anim: continuity 7, rates 4; loco continuity, phase match, loco
  graph and direction weights pass both ways). Weapons are on hold. The foot-slip suite (`test_locomotion_feet`) takes over
  30 minutes and was not compared both ways: its bow and musket walk failures were seen in the full run, not checked
  against the old builder.

Probes kept for the next pass: `tools/anim/root_jitter_probe.gd` (feet while a cast roots you: smooth),
`tools/anim/npc_blend_probe.gd` (a bot's clip hand-offs on its AnimationPlayer).
