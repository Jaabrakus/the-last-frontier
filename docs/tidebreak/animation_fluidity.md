# Animation fluidity — 8 October 2026

Cast chaining and cancellation now carry the outgoing pose into the next animation over at most 80 ms. Landings keep their immediate foot and hip placement while the upper body settles. Unarmed arena opponents use directional footwork when circling or retreating, and player footsteps exclude knockback sliding and body-state moves such as rolls.

This pass changes five presentation scripts: `SwayPose`, `ToolPose`, `NpcFighter`, `NpcBody` and `Footsteps`. The work started from the existing modified workspace; the evidence contains snapshots and diffs against that starting point. It does not attribute earlier changes to this pass.

## Changes

- **Cast transitions:** replacing the active clip used to retain its weight while immediately changing its sample. The new handoff evaluates both poses against the same current underlying animation. Interrupted handoffs collapse to one bounded pose layer, including when interrupted before the first rendered frame. Upper-body masks remain in force. A continuous press-to-release of the same clip retains its existing timeline.
- **Landing transitions:** light and heavy landings still establish lower-body contact immediately. Only the upper body blends from the outgoing pose, for at most 80 ms. A pending strike can shorten that interval; hit reactions remain above it.
- **Opponent footwork:** unarmed arena opponents select the existing forward, sideways or backward gait from their own local movement, excluding knock carry. Playback follows the selected clip's measured speed. Changes preserve the planted foot and progress toward the next plant; a small direction margin prevents switching repeatedly near diagonals. Measurements load with the animation library, before live movement.
- **Footstep sounds:** knock-only slides and special movement states no longer generate ordinary running steps. Normal distance-based cadence, jumping, landing and world movement retain their prior behavior.

The cast clock, strike deadlines, player movement, charge durations, AI decisions, damage, launch rules and knockout timing are not retuned. Animation libraries, graph data and move/rule data remain as captured before this pass. No multiplayer work is included.

## Verification

The focused tests instantiate actual game bodies, rigs and clips. They exercise a failure demonstrated on the saved baseline, rather than testing only new helper functions.

| Check | Result | Evidence |
| --- | --- | --- |
| Cast handoffs, interrupted blends, masks and landing contacts | 29/29 | [Final focused log](../../artifacts/tidebreak_pose_fluidity/checks/cast_final.log) |
| Existing ring pose transitions | 12/12 | [Transition log](../../artifacts/tidebreak_pose_fluidity/checks/ring_transitions.log) |
| Existing bending pose integration | 54/54 | [Pose integration log](../../artifacts/tidebreak_pose_fluidity/checks/bend_poses.log) |
| Directional opponent gait and footsteps | 31/31 | [Grounded log](../../artifacts/tidebreak_fluidity/grounded/test_after.log) |
| Existing opponent casts | 10/10 | [Opponent log](../../artifacts/tidebreak_fluidity/grounded/test_existing_npc_casts.log) |
| Real airborne combat state and release gates | 56/56 | [Airborne log](../../artifacts/tidebreak_fluidity/final_checks/airborne.log) |
| Full script compile | 868 passed, 0 failed | [Compile log](../../artifacts/tidebreak_fluidity/final_checks/compile.log) |

The 12- and 54-check suites ran before the final narrow correction for an interrupted, unsampled mask. The final 29-check suite covers that correction. The compile and airborne checks ran after the final runtime changes. No listed run contains a script error. Logs retain sandbox logger/certificate diagnostics, animation loop warnings where applicable, and the existing shutdown warnings for nine ObjectDB instances and five resources.

The isolated zero-time cast-switch test measured maximum sampled-joint discontinuities of 0.848632 m for alternating hands and 0.768158 m for cancellation before the repair, both below 0.0001 m afterward. These are continuity tests at the transition instant, not ordinary per-frame travel. The short-deadline strike still fires exactly once at 0.035 s. Both landing types retain their authored foot positions immediately and reach the complete landing pose by 80 ms.

The original grounded suite failed seven checks on the saved source. It exposed forward gait during sideways/backward travel and ordinary footstep sounds during knock-only slides and rolls. The final suite also checks physical movement preservation, cast priority, planted-foot phase and directional stability.

Matched rendered cases cover movement and two airborne attacks for each element, plus alternating Fire casts, Earth charge cancellation and opponent side/back travel. All fifteen cases retain their event sequences and exact logged event times; this includes releases, strikes, contacts and landings where present. Recorded player velocity samples match exactly. Casting-case body positions match exactly; movement/cancellation cases differ by at most 1.7 mm.

The final side-view and player-view takes each passed 24 checks (21 core, three additional), for **48/48 rendered checks**. These are controlled Practice cases using real input and combat paths. A [16.95-second normal-speed proof clip](../../artifacts/tidebreak_fluidity/after_normal_speed.mp4) shows movement, all four elements, chained casting, cancellation and opponent footwork, with native game audio.

| Demonstrated transition | Before: sampled hand travel | After: sampled hand travel |
| --- | --- | --- |
| First alternating Fire cast | 0.413 m | 0.078 m |
| Second alternating Fire cast | 0.412 m | 0.078 m |
| Earth charge cancellation | 1.057 m | 0.363 m |
| Earth Spike landing, right hand | 0.786 m | 0.269 m |

These distances describe the corresponding one-frame changes in final rendered skeleton positions relative to the body, at 60 frames per second. They establish smaller jumps in these demonstrated transitions, not a percentage improvement for all animation. On the landing frame, pelvis and foot changes remain exactly as before; the lower body deliberately establishes contact immediately. Sampled blend-group processing stayed below 0.35 ms on this host in the side-view cases. Fixed-rate recording does not establish live gameplay frame rate on other hardware.

In 167 matched moving opponent samples, median mismatch between the selected gait direction and actual travel fell from 101.44° to 11.44°. Samples with a mismatch above 90° fell from 114 to zero. Opponent position differences stayed below 0.4 mm. These are improved direction and pace matches, not perfect foot locking: the low-foot speed proxy improves in the median but still has peaks. See the [opponent comparison and its limits](../../artifacts/tidebreak_fluidity/grounded/npc_direction_comparison.json).

## Loop investigation

The read-only [loop measurement tool](../../tools/ring/measure_fluidity_loops.gd) resolves the active graph aliases and override libraries. Fifteen arena-specific looping poses have effectively closed endpoints (no translation difference and at most about 0.001 rad of rotation noise). Forward run and sprint are also effectively closed. Some other locomotion clips have endpoint warnings; an endpoint warning alone does not establish a visible discontinuity in the active blend.

A separate in-game probe followed the active slow right-walk leaf through four wraps. Its first three foot displacements at the wrap were 0.05095–0.05251 m per rendered frame; ordinary samples in the same gait reached 0.06159 m. The active leaf contributed 50%. The held backward-sprint input selected the run bank rather than the warned sprint leaves. These observations did not justify rewriting the animation resources in this pass. They do not establish that every clip or outfit is seamless.

See [endpoint measurements](../../artifacts/tidebreak_fluidity/loop_audit/tidebreak-fluidity-loops-before.json) and [active wrap measurements](../../artifacts/tidebreak_fluidity/loop_diagnostic/wrap_metrics.json). Initial failed loop-probe attempts remain recorded as harness failures; the corrected diagnostic passed four checks. They are not game regressions.

## Evidence and reproduction

- [Rendered capture evidence](../../artifacts/tidebreak_fluidity/README.md): before/after inputs, final-skin measurements, event timing and normal-speed footage.
- [Cast and landing repair](../../artifacts/tidebreak_pose_fluidity/README.md): source snapshots, exact diff, commands and test limitations.
- [Grounded movement repair](../../artifacts/tidebreak_fluidity/grounded/README.md): source snapshots, exact diff and test results.
- [Delivery manifest](../../artifacts/tidebreak_fluidity/delivery.json): final hashes and verification references.

All engine runs use `tools/loop/godot_run.sh` with the installed Godot 4.7.2 runtime. Official references consulted: [SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html), [Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html), [AnimationPlayer](https://docs.godotengine.org/en/4.7/classes/class_animationplayer.html) and [AnimationMixer](https://docs.godotengine.org/en/4.7/classes/class_animationmixer.html).
