# Move animation retouch — 11 October 2026

The owner, leaving for the day: "do a animation for all the moves retouch or make it smoother". Our own clips only: the same
typed key poses in `tools/anim_author/blender/bend_clips.py`, nothing imported, retargeted or measured; no solver re-author
(the 2026-10-01 rejection). What changed, how it was measured, and what was tried and dropped.

## In the game now

| What | Before | After | Where |
|---|---|---|---|
| **Hold to cast: the moving hold** | holding a lock froze the wind-up dead on its hold_s for the rest of the lock | the last 0.12 s of the wind-up is drawn out, its pace falling away smoothly (it keeps deepening, ever slower, never stopping dead); the release catches the remainder up over its first 0.05 s, so **the strike lands on the same frame as before** | `SwayPose._creep`, `HOLD_CREEP_S`, `CATCH_S`; every element cast of the player (bots never hold); the Form floor and wall presses as before |
| **Knees and elbows bend only about their hinge** (every one of the 126 own-bend clips re-baked) | the two-bone IK turned each bone by the shortest arc from the rest, so a thigh or an upper arm took whatever twist that gave, and the shin or the forearm bent off its hinge to reach: the knee or the elbow spun about itself, up to 180 deg in one frame (a knee cap or an elbow crease flicking round) | the upper bone turned so the hinge lies across the bend's plane, the lower one only folded about it (`rigkit.ik2_hinge`); **every joint in the same place as before** (3,802 frames compared: the palms within 1.4 mm, the rest exact), only the twist along the limbs decided | `tools/anim_author/blender/rigkit.py`, `bend_clips.py` (`IK2`, `--old-ik` to bake the old way) |
| **Six casts' elbows retouched** (and their mirrored twins), and the hit from behind | in fire's Kick, the Fireball, the Axe Kick and the Flip Kick, water's Skate and earth's air hit, an elbow (and the Axe Kick's knee) was keyed to point along its own limb, so its side was decided by a sliver of the pole: the Kick's right elbow flipped over the arm at the swing and crossed in front of the chest (a 34 cm jump in one frame); the Fireball's left elbow swung through the spine; the Axe Kick's balancing arms twisted whole | the pole keys retyped to keep each elbow on one side (out round the outside, or down) and carry it round over a few frames; the held poses kept. The struck-from-behind contact pose (every hit from behind) had its flung arms' elbows keyed out along the arms, so the near-straight arms twisted back and forth each frame: now down and back, as its own description has them | the clips' `pole_*` / `knee_r` keys, each marked "retouched 2026-10-11" |

Before and after sheets of the six: `artifacts/anim_try/move_retouch_1.png` and `_2.png` (front view, the frames around each
fix). The flips themselves are one frame, so the sheets show the corrected poses; they read in motion.

## Measured (`tools/anim_author/bend_smoothness.py`, all 126 clips)

| | Before | After |
|---|---|---|
| A bone spinning over 40 deg about its own length in one frame (30 fps) | 960 | 635 |
| ... of them one-frame spikes (2.5x the frames either side) | 230 | 158 |
| ... at a knee or an elbow | 76 spikes | **0** |
| An arm's or a leg's bend plane jumping (bent over 25 deg, over 40 deg in a frame, 2.5x either side) | 85 | 76 |
| Casts (poses.json clips) whose bent limb's pole lies within ~12 deg of the limb | 10 | **0** |

The remaining upper-arm twists are the shoulders now carrying the fast elbow swings the clips always had (the same elbow
places; a throwing arm does turn that fast), mostly in the rolls, get-ups and tumbles.

## Tests

The cast and pose suites pass on the shipped clips (hand-offs 30/30, clip situations 122, ring pose transitions 12/12, the
casts, the guards, the combos, the air states 82/82, bots, looks, hitstun, highlights, replay, playcheck). One check was
fragile and is now robust: `test_r3_air`'s "a Punch that hits halves its landing lag" aimed the airborne Punch at the foe's
chest from a metre up, where the bolt (leaving the hand above the camera's line) only grazed the top of his head, a hit by
under 2 cm; the re-bake's hand sits a centimetre higher in game (the forearm's twist helpers follow the new twist) and the
graze became a miss. Aimed at his belly it hits with the old clips and the new. `test_bend_poses` checks the moving hold.

## Tried and dropped

- **A rate limit on the bend's plane** (an elbow or a knee swinging round its limb at most 1,200 deg/s): it held elbows on
  their old side while the arm moved on; fire's Kick showed an elbow flared up and out for four frames, worse than the quick
  drop it replaced. Kept as `bend_clips.py --plane-rate` (off).
- **A straight-limb twist from the old IK** (the shortest arc's twist under 15 deg of bend, the hinge's over 40): more spikes,
  not fewer (206 against 166). Removed.
- **Baking every clip at 60 fps** (`--substeps 2`): the in-betweens mostly match the 30 fps keys blended (median 0 deg, 99th
  percentile 5.7 deg), but the finer bake also shows the few flips the 30 fps blend hides by taking the short way round. Not
  installed; worth it once the reaction clips' poles below are retouched too.

## Left for a next pass

- Seven reaction and movement clips still have a bent limb whose pole lies along it at some frame: `tumble`, `roll_b`,
  `getup`, `jump_double`, `air_dodge`, `tech_roll` and its twin (the double jump's and the air dodge's paths stay
  continuous all the same; the dodge's is its own fast twist).
- Then the 60 fps bake, and a look at the remaining wrist twists (the hands' facings turning fast between keys).

## The tools

- `tools/anim_author/bend_smoothness.py <bake.json> [--axes axes.json]`: snaps, twist flips and their spikes per clip.
- `tools/anim_author/bend_axes.gd`: the bones' own axes and rests on the game's skeleton, for `--axes`.
- `tools/anim_author/bend_bake_diff.gd <bake.json> [detail=1]`: a bake against the installed library (the unchanged script
  re-baked to 89 of 126 identical, 30 more differing only by a missing `ik_miss_m` meta, and 7 at one degenerate wrist
  frame).
- `tools/anim_author/install_bend.gd ... out=res://...`: install a bake into another library, to look at it beside the game's
  (`bend_preview.gd lib=`).
- `bend_clips.py --angles` now prints each limb's pole conditioning (how far the pole is off the limb's line, 0 to 1).
