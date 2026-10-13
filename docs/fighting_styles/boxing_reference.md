# Boxing reference sheet (fire's first fighting style)

Written 2026-10-09 for the Boxing prototype (docs/fighting_styles_design.md, the Fire roster's Boxing row; the owner,
2026-10-08: "we need to watch videos on martial art styles and create animations for them"). The clips it informs are keyed
by hand in `tools/anim_author/blender/style_boxing.py` and installed in `animations_extra/Frontier_Style_Boxing.res`.

## How the references were used

- Watched in the built-in browser (YouTube, not signed in). Each video was paused at the timestamps listed below and the
  paused frames were looked at, several side by side (the paused frame drawn onto a canvas on the page, because the
  browser pane's screenshot leaves the video layer out). Timing was read by stepping the paused player in 1/30 to 1/4 s
  steps.
- Visual reference only. No video was downloaded, no frame was saved for use, and nothing was traced, motion-captured or
  pose-estimated. Only the idea of each move was taken: what the feet, the hips, the trunk, the hands and the head do,
  and roughly when. Every key in the generator is typed by hand on the project's own rig (Actor_B, its rest pose).
- Orthodox throughout (left foot and left hand lead). A southpaw is not a mirror the generator makes.

## Videos

| Id | Channel, title | Link | Used for | Timestamps used |
|---|---|---|---|---|
| V1 | FightCamp (Tommy Duquette), "Boxing Stance \| Beginner Step-By-Step Tutorial" | https://www.youtube.com/watch?v=SjLXzCpRS8U | stance, guard | 0:40, 0:45, 0:46, 1:00, 1:15, 1:30-1:40, 1:45, 2:00, 2:15 |
| V2 | FightCamp (Tommy Duquette), "How to Punch: Jab & Cross Beginner Boxing Tutorial" | https://www.youtube.com/watch?v=YsFK1MMDQgk | jab, cross, the 1-2 | 0:50-1:54 (every 8 s), 1:56-2:12 (every 2 s), 3:20, 3:24, 3:28, 4:40-5:28 (every 6 s), 5:18-5:40 (every 2 s), 5:24.5-5:26.0 (every 0.1 s) |
| V3 | FightCamp, "LEARN BEGINNER BOXING FOOTWORK IN 5 MINUTES \| Beginner Boxing" | https://www.youtube.com/watch?v=dg2Jp3F30Lw | the stance in motion, the bounce, lateral movement | 0:30-3:15 (every 15 s), 3:48-4:43 (every 5 s), 4:04-4:06.2 (every 0.2 s) |
| V4 | Tony Jeffries, "Basics of Boxing - Training for Beginners at Home" | https://www.youtube.com/watch?v=kKDHdsVN0b8 | lead hook, real-speed timing of the 1-2-hook (filmed from the front, the opponent's place) | 3:53-4:37 (every 4 s), 4:19.50-4:21.50 (every 0.25 s) |

## Techniques

Times are seconds from the start of the move; frames are the clip's own at 30 fps.

### Stance and guard (V1; the bounce from V3)

- Feet: lead (left) foot ahead pointing at the target, rear foot behind and out to the right, turned out about 45 degrees,
  rear heel up; about shoulder width apart side to side and staggered so the feet are not on one line (V1 0:40-0:46, 1:15;
  overhead 1:30-1:40).
- Hips and trunk: side-on about 30-45 degrees, knees soft, trunk a touch forward (V1 1:45, 2:00).
- Hands: rear fist at the right cheek and jaw, lead fist "three to four inches off" the face, a little ahead at chin to
  eye height, forearms upright, elbows down on the ribs ("your elbows should be tucked in to protect your body") (V1 1:45,
  2:00, 2:15).
- Head: chin down behind the lead shoulder (V1 2:15).
- The bounce: up on the balls of the feet, one foot off the floor at a time while moving (V3 0:45).
- Clip: `stance` (36 frames, a loop): two bounces a loop (about 1.7 a second) on the balls of the feet, a rock onto the
  lead foot and back once a loop, the shoulders and the fists a beat behind the bounce, the lead fist pawing a small circle.

### Jab (V2; timing V4)

- Key poses: from the guard, no wind-up; the lead fist goes straight out from the chin, turning over at the end (palm down,
  "ROTATE FIST", "TOP TWO KNUCKLES MAKE CONTACT", "ARM FULLY EXTENDED", V2 1:46-1:54); the lead shoulder rises to the chin
  and the head stays behind it (V2 1:30, 5:30); the rear fist stays at the cheek ("keep your rear hand up", V2 1:50).
- Weight: a little onto the rear leg, "which loads my rear leg to save it as ammunition for the cross" (V2 narration ~5:20).
- Return: back along the same line.
- Timing: out and back about 0.25 s at full speed (V4 4:20.25-4:20.75, the straight right of the same string; V2's
  demonstrations are slow).
- Clip: `jab` (16 frames): ready f2, strike f5 (0.17 s), recoil f8, back to the guard by f16.

### Cross, the 1-2 (V2; timing V4)

- Key poses: the hips turn first, then the shoulders; the rear arm goes straight out at shoulder height, fist turned over;
  the rear shoulder comes through to the chin and the chest turns square; the head moves forward over the lead knee; the
  rear heel turns out (V2 3:20-3:28, 5:24.5-5:28 side view). The lead hand comes home to the chin.
- Weight: from the rear leg (loaded by the jab) onto the lead leg.
- Timing: out and back about 0.25 s (V4 4:20.25 guard, 4:20.50 the cross out, 4:20.75 back in the guard).
- Clip: `cross` (20 frames): loaded on the rear leg f3, strike f6 (0.2 s), follow-through f8.

### Lead hook, the Pop (V4)

- Key poses (from the front, V4 4:21.00-4:21.50): the left arm swung across at shoulder height with the elbow up and bent,
  the forearm flat; the body turned hard to the right behind it; the lead heel off the floor, turning out; the turn carries
  on after the fist crosses the line (4:21.50).
- Timing: guard to across about 0.25 s, the follow-through about 0.25 s more (V4 4:21.00-4:21.50).
- Clip: `hook` (24 frames): load f3 (the weight onto the lead leg, the lead shoulder dipped), strike f7 (0.23 s),
  follow-through f10.

### Not checked against a video

These clips are keyed from standard boxing mechanics and the stance, jab, cross and hook references above. The browser
pane could not draw the videos for the rest of the session, and the owner chose to skip their video check (2026-10-09):

- slip and roll: `slip` (fire's Parry: the head a head's width off the line to the right, then the counter jab);
- footwork: `step_in`, `step_back` (step-drag), `step_left`, `step_right` (the leading foot first, the other drawn after);
  the pivot and the shuffle were not made;
- the uppercut (`uppercut`, the High Kick), the overhand (`fireball`), the level change under the ground punch
  (`ground_punch`, the Kick);
- the charged straight (`lightning`) and the 1-2 flurry (`flurry`) are the project's own: a deep load before a lunging
  straight, and short 1-2-1-2 punches, built from the jab and cross above.

## The owner's choices (2026-10-09)

- Key 2's Kick (the floor wave): a ground punch (the boxer drops level and drives the right hand into the deck; the wave
  runs from the fist).
- Key 2's High Kick (the crescent over walls): a rising uppercut.
- The first pass: "Bolder" (deeper loads, bigger turns, longer follow-throughs), applied to every clip.
- The second pass: "these are okay make sure the hand ik is closed": every hand is a closed fist (the fingers curled a little
  past bend_clips' own and the thumb wrapped across the fist by its own two-bone IK, where it had hung below it), Lightning's
  measuring lead hand included.
- The video check of the clips above: skipped. Fire Wall, Breath and Patch: not re-animated for now.
