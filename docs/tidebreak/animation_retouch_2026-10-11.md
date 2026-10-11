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

## The elastic glitch (afternoon)

The owner: "sometime the body like glitches it turns elastic why is this", then "fix them". What he saw is the skin along a
forearm or an upper arm wrung round in one frame. The skin's twist bones (`CharacterBodyMesh`: the forearm's at 30, 60 and 90%
of the wrist's roll, the upper arm's at a third and two thirds of its twist) follow the limb's twist; when that twist jumps,
the skin jumps with it. It had four sources, and `tools/anim/stretch_hunt.gd` counts them in real matches (SNAP: a twist bone
turned over 60 deg about its limb in one drawn frame; 45 s a match, four elements, the player and a bot):

| Source | Fix | Where |
|---|---|---|
| A roll crossing the twist bones' wrap jumped a whole turn | the twist kept continuous with its last frame (committed 2d99bbba) | `CharacterBodyMesh._twist_of` |
| Knees and elbows flipping side in one frame (a pole across the limb's line, or the limb swung across it): thighs and upper arms turned 140-178 deg at once in the rolls, get-ups, double jump | **the flip guard** on every clip but a loop: a bend side the keys would move over 100 deg at once swings round at 900 deg/s instead, then follows the keys again; a side that moves less is the keys' own. All 130 clips re-baked (the Stone Knee and its twin refuse it: its elbow is driven onto the knee at the strike in two frames, which the guard would land late) | `rigkit.ik2_hinge` (`GUARD_DPS`, `GUARD_FLIP_DEG`), `bend_clips.py` (`POLE_GUARD_DPS`, a clip's `"pole_guard": False`) |
| A hand folded far back on the forearm, where its roll about the forearm has no clear value and swings half a turn for a small move of the hand; struck poses snapped in; keyed rolls that flip | **the twist step cap**: in the game a twist bone turns at most 40 deg a drawn frame and catches up over the next frames (a hard throw's forearm roll is about 25 deg a frame at 60 fps, so no real motion is held back) | `CharacterBodyMesh.TWIST_STEP_MAX` |
| An outfit or hair change mid-match rebuilt the twist bones and forgot their last twist, so every arm's twist bone jumped at once | the last twists kept through a part added or taken off (cleared only for a new skeleton) | `CharacterBodyMesh._begin` |

| Stretch hunt, same seed | Bot SNAPs | Player SNAPs |
|---|---|---|
| this morning | 590 | 866 |
| after the wrap fix | 474 | 681 |
| the flip guard on every clip, no cap | 490 | 731 |
| + the twist step cap | 77 | 24 |
| + the last twists kept through part changes (in the game now) | **15** | **7** |

The flip guard's bake (`bend_smoothness.py --axes`, all 130 clips, against the clips before it): snaps 1,408 to 1,384, twist
flips 637 to 598, one-frame twist spikes 160 to 142 (the shoulders 66 to 56, the thighs 15 to 11). Gone: the back roll's
178 deg thigh flip, the get-up's 164, the tech roll's 171 and 176 deg shoulder flips, the spiked knock's 171. Some fast turns
remain (the back roll's shoulder 172, the double jump's wrist 168): keyed motion, which the step cap now eases in the skin. A fresh bake of the
final script matches the installed library to 0.06 deg (the library's own rounding). The stretch hunt's TWIST count (a forearm
or a shin twisted over 150 deg against the bone above: poses that hold a hand rolled far, like water's Wave press) did not
change; those are held poses, not snaps, and a look at them is for the next pass.

Tried and dropped: **a wrist roll limit in the bake** (the hand's roll about the forearm kept continuous and at most 1,200 or
1,800 deg/s). Where the hand is folded far back the roll is ill-defined, so holding it back turned the hands further off their
keys (the duck's wrist 122 to 171 deg in a frame) for little less wringing; the twist step cap does that job in the game for
every source at once.

## The tools

- `tools/anim/stretch_hunt.gd [seconds=45] [continuity=0] [cap=0]`: real matches, the stretch kinds and SNAPs by clip; `cap=0`
  and `continuity=0` drive the twist bones as before those fixes, to compare.
- `tools/anim_author/bend_smoothness.py <bake.json> [--axes axes.json]`: snaps, twist flips and their spikes per clip.
- `tools/anim_author/bend_axes.gd`: the bones' own axes and rests on the game's skeleton, for `--axes`.
- `tools/anim_author/bend_bake_diff.gd <bake.json> [detail=1]`: a bake against the installed library (the unchanged script
  re-baked to 89 of 126 identical, 30 more differing only by a missing `ik_miss_m` meta, and 7 at one degenerate wrist
  frame).
- `tools/anim_author/install_bend.gd ... out=res://...`: install a bake into another library, to look at it beside the game's
  (`bend_preview.gd lib=`).
- `bend_clips.py --angles` now prints each limb's pole conditioning (how far the pole is off the limb's line, 0 to 1).
