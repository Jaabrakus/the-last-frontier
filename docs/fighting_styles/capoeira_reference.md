# Capoeira reference sheet (air's style)

Written 2026-10-09 for the Capoeira prototype (docs/fighting_styles_design.md, the Air roster's Capoeira row; the owner chose
it on 2026-10-09). The clips are keyed by hand in `tools/anim_author/blender/style_capoeira.py` and installed in
`animations_extra/Frontier_Style_Capoeira.res`.

**Parked 2026-10-09.** The owner played the first ten clips: "the animations for the caporia looks whack lets keep it
simple for now", and chose to drop Capoeira for now; air keeps its original clips. The library stays, mapped nowhere.

## Status of the reference study

No video has been watched for these clips yet. The built-in browser pane stayed hidden, so the video drew no frames, and
then the Mac restarted mid-study. The first batch is keyed from standard capoeira mechanics, as the boxing clips the owner
had skipped the video check for. Only a catalogue was found and its chapter list read (move names and the times they start;
no frame was looked at):

| Id | Channel, title | Link | Used for |
|---|---|---|---|
| C1 | Mestre Koioty, "60 movimentos de capoeira para Luta (51 Golpes e 9 esquivas)" | https://www.youtube.com/watch?v=hXyQk4LTlm8 | the moves' names (chapters: Ponteira 0:34, Queixada 1:02, Meia-Lua de Frente 1:18, Armada 1:27, Rabo de Arraia 2:22, Martelo Rodado (Parafuso) 3:25, Esquiva na cadeira 3:39, ...) |

Found for a later video pass (not watched): Howcast, "How to Do the Ginga | Capoeira" https://www.youtube.com/watch?v=HbUxXJKitS4;
Howcast, "How to Do the Armada | Capoeira" https://www.youtube.com/watch?v=1iJ_pBo-Isc; Howcast, "How to Do the Meia Lua de
Compasso | Capoeira" https://www.youtube.com/watch?v=IiLqVCyyoPs; Capoeira ATL, "Instructional Capoeira Movements with
Professor Malandro - Lesson 3 - Meia lua de frente and Armada" https://www.youtube.com/watch?v=mPVHfPh9nPU.

## The moves as keyed (first batch)

| Clip | Air move (key) | Key poses | Timing (30 fps) |
|---|---|---|---|
| `ginga` | stance; E held | the triangle step: the right foot back on its ball (the left forearm across the face, the right hand low behind the hip), both feet level, the left foot back (the arms swapped), level; the body low between the feet and bowed forward, the head up | a loop of 56 frames (1.87 s), a quarter a step |
| `meia_lua` | Palm (LMB) | the weight onto the front leg; the rear leg swung up out to the right and across the front at the head's height (a vertical crescent), the trunk leaning back; down and stepped back | anticipation f3, strike f9, follow-through f12, 24 frames |
| `meia_lua_front` | Palm's alt (the next cast within the combo window) | the same with the front leg, from left to right | as above |
| `martelo` | Slice (1) | the rear knee chambered across the front, the hips turned over and the support foot pivoted about 100 degrees, the instep snapped out flat at the chest's height, the trunk leaning away | f4, strike f8, f10; 24 frames |
| `bencao` | Wind Ball (1 twice) | the rear knee drawn up high, the body leaning back over the standing leg, the sole driven straight out (toes up) at the chest's height | f5, strike f9, f11; 26 frames |
| `armada` | Gust (2), the signature | the rear foot crossed ahead, the body turned on its ball until the back faces the mark and the head looks back over the shoulder (held: the grow), then the whole turn with the other leg swung straight round in an outside crescent at the head's height | f7, strike f12, f15; 34 frames, one turn |
| `esquiva` | Wind Guard (E) | dropped low out to the right under the shot (the knees deep, the trunk bent over the right knee, the forearm over the head, the other hand by the deck; held: the window), then up with the palm swept out ahead (the wind sent back) | dodge f6, strike f11; 26 frames |
| `au` | Slip (3) | the arms swung up overhead, a cartwheel to the left over the hands, the legs going over in a wide V, landed into the ginga | f6, upside down f12, f16; 32 frames |
| `rasteira` | Pull (2 twice) | dropped low to the left onto the left hand by the deck, the right leg slid out ahead along the deck to the ankle (the hook) and hooked back in toward the body (the pull) | f5, strike f9, f13; 30 frames |
| `compasso` | the jab string's Pop | turned to the right as the trunk folds down over the left leg and both hands go to the deck, the head looking back under the arm (held); a whole turn on the left foot with the right leg swung up round behind, the heel through the mark at the head's height | f7, strike f12, f15; 32 frames, one turn |

Not made yet: the Leap (keeps air's own clip in the play test).
