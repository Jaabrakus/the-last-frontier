extends SceneTree
## Our own ring-sport clips (animations_extra/Frontier_Bend.res, keyed and IK-solved in Blender by
## tools/anim_author/blender/bend_clips.py and installed by tools/anim_author/install_bend.gd; the owner, 2026-10-04: the
## throw-style moves on new own throw clips only, every clip our own: docs/animation_provenance.md, animations/SOURCE.md). No
## level: the library, Actor_B's own rig (assets/character/actor_b_body.glb) posed from the clips' tracks, and SOURCE.md.
##   Godot --headless --path . -s tests/bending/test_bend_clips.gd
##   first set   the library loads and holds the first set (earth stomp, push, rise; the throws overhand, sidearm, underhand,
##               the overhand's and the sidearm's left twins; the knocks slide and air)
##   second set  and the second (2026-10-05): each element's stance, the earth boulder (the owner's "left kick to stomp and
##               then push"), raise, burrow, catch, shove; fire punch, double jab, kick, sweep, breath, lightning; water whip,
##               wave, draw, shield; air palm, sweep, spin, leap, shield; the punch's, sweep's, whip's, palm's, shove's twins
##   polish      the first set's IK-clamped keys pulled in: no arm or leg locked straight past its reach (the palms and the
##               ankles where the keys put them, within 1 cm) at the throw-underhand back-swing, the knock-slide guard and
##               the knock-air flail (round 1 missed by 0.125, 0.093 and 0.068 m); the timing contracts kept (strike_s, hold_s)
##   boulder     the left foot kicks up off the ground before the hold and is planted at it; both palms out ahead at the strike
##   stances     loop (LOOP_LINEAR), mask full, the loop seamless (the first frame's palms, ankles and root the last's), the
##               feet planted through it (no gait: the ankles move under 1.5 cm), the root's sway subtle (under 6 cm: the
##               water stance's weight shift the most)
##   own         every clip is own-bend-*, has the authored meta naming bend_clips.py, and carries no native_asset_id,
##               source_attribution or original_name (nor does the library); every track is a bone of the rig
##   moments     strike_s, hold_s, back_s within the clip's length, hand and mask set; a cast holds before it strikes; a throw's
##               hold_s <= 0.2 s and its strike 0.06..0.2 s after the hold (the release never laggy); a knock's strike at the
##               hit, its hold after it; knock_air's landing (up_s) between the hold and the recovery
##   place       the root comes back within 3 cm of where it started on every clip but the stomp's (a moved stance), and
##               every clip starts and ends on the same stand (the palms and the ankles within 2 cm of the first clip's start)
##   twins       a -l twin is its clip mirrored in the world: at the hold, the strike and the end, the palms and the ankles of
##               the twin are the original's mirrored across the body's middle (within 1 cm)
##   record      animations/SOURCE.md's Frontier_Bend.res table has a row naming every clip in the library
##   third set   round 2 of the skills (2026-10-05): the Kick's low kick and its twin, the High Kick's twin (the second set's
##               kick, its keys unchanged), the Fireball's deeper chamber, the four guards (the earth catch polished, the
##               water Turn and its hold loop, the fire Parry, the air Wind Guard and its hold loop), Shove's kick-up,
##               Column's uproot, the air Pull, Slip (its twin and the back step), Wind Wall and Slice, the water Surf (a
##               loop) and Skate: each there with its metas (hand, mask, root, the moments; legs_always where the body moves)
##               and its twin where it has one; the IK's worst miss (meta ik_miss_m, from the bake) at most 5 mm
##   kept        the 39 clips before round 2 keep their lengths and their moments (hold_s, strike_s, back_s, up_s)
##   low kick    the low kick's sole at the strike under 0.35 m above the deck and its hold's foot under 0.2 m, the High
##               Kick's foot at its strike over 0.5 m (the two chambers read apart: the tell never lies)
##   fourth set  round 3's P1 air and hit states (2026-10-06): the tumble, flinch, double jump, fall, fast fall, helpless fall,
##               air dodge, air legs and the two landings, each with its metas (hand, mask, root; the moments on a one-shot;
##               meta loop on a loop), its length, the IK's worst miss at most 5 mm; none has a side, so none has a twin.
##               A loop is seamless (its first frame's palms, ankles, head and root its last's within 5 mm). The airborne
##               one-shots (the double jump, the air dodge) start and end on the fall's first pose (they hand over to it);
##               the landings end on the stand with the feet planted from the touchdown on (no slide: 1 cm). Each reads as
##               its state: the helpless fall's hands HELPLESS_OVER (0.1 m) or more above the shoulders at every frame and
##               0.15 m or more over the plain fall's on average (it reads apart); the tumble turns the whole body over (the
##               head under the hips) where the knocked slide never does; the fast fall's legs together and long (the ankles
##               within 0.2 m, under the hips by FALL_FAST_LONG or more); the double jump's and the dodge's knees drawn up
##               (the ankles 0.2 m or more over the fall's); the heavy landing's crouch 0.15 m or more deeper than the light
##               one's and held longer; both landings start on the fall's arms (2 cm); the flinch an upper-body 0.2-0.3 s
##               whose head moves 3 cm or more; the air legs only the legs' bones, no root, mask lower
##   pass 2      the critic's notes: the tumble tucked (0.12 m more compact) while its turn is fastest, the turn 2.5 times
##               the slowest there, and upright only as a ball (the ankles within 0.5 m of the hips); the fall's palms 0.45 m
##               out at the least, its bicycle 0.18 m and its arms 0.08 m; the fast fall's palms 0.2 m behind the hips; the
##               double jump's heels under the seat and its hands on the knees in the tuck; the flinch's hands up at the chin
##               in a guard at the cringe; the air legs' ankles moving 5 cm or more
##   pass 3      the critic's second notes: the helpless fall's trunk 20 degrees or more off the vertical at every frame (never
##               the upright "hooray"), its hands never level (6 cm apart in height on average) and its elbows bent; the
##               tumble's hands 0.25 m or more from the head at the seam (no hand at the ear); the double jump's push long (the
##               ankles 0.65 m under the hips) with the palms 0.25 m behind the hips, after a gather it can be seen in; the
##               fall's two arms not mirror-perfect; the fast fall's trunk pitched into the dive, its palms 0.3 m out (an
##               arrowhead from behind) and both knees bent alike under 35 degrees; the flinch's fists before the chin, clear of
##               the face; the air legs' left heel 0.15 m behind the right (two shapes); the heavy landing's push up eased (no
##               frame rising more than 6 cm) and its length 16 frames with back_s unchanged (the punish window starts as before)
##   kept r3     the third set (round 2) keeps its lengths and moments (hold_s, strike_s, back_s)
##   fifth set   round 3's P1 edge and ground dodges (2026-10-06): the edge grab, hang (a loop), climb, roll in, jump and
##               attack, the forward, back and side rolls (the side roll's twin) and the duck, each with its metas (hand,
##               mask full, root, legs_always; the moments on a one-shot), its length, the IK's worst miss at most 5 mm, its
##               twin or none. The edge clips name their lip (lip_y over the origin, at or over the hips' rest height + 0.4;
##               lip_out to the face). The hang's hands and head over the lip at every frame (the head 0.15 m or more), the
##               palms planted on the deck past the lip and the balls of the feet on the face under it, nothing moving (1 cm);
##               the grab caught high from out off the face (the ankles 0.45 m out) onto the hang's first pose (1 cm), the
##               hands on the deck from its strike; the climb, the roll in and the attack from the hang to a stand on the
##               deck end_in m in (2 cm), nothing through the deck (3 cm); the jump onto the fall with the arms flung up
##               overhead; the attack's sweep low along the deck (the ankle under 0.15 m) and in (0.7 m); the rolls and
##               the duck from the stand to the stand; the rolls low (the head under 1 m), turned over, on the deck (the
##               lowest surface -3..+4 cm), the side roll to his right; the duck's head down 0.4 m and back behind the hips,
##               the feet planted. kept r3 p1: the fourth set's lengths and moments as they shipped
##   edge pass 2 the fifth set's second pass (_fifth_pass2), the critic's notes: the
##               hang's hips 0.3 m off the face, its knees folded 70-125 degrees and its hips swaying 8 cm; the grab's sag
##               (8 cm under the hang) and its palms planted within 5 mm between the keys too; the climb's shin never at the
##               deck's height over the void, its hips over the left foot, a held load and a rise carried past the stand; the
##               jump's hands on the deck through the push in the world, a coil of 6 cm and its legs near straight at the release; every roll's
##               head 4 cm clear of the deck while it rolls; the sweep across past the left foot, slowing; the side roll's
##               leading leg landing first; the duck 0.5 m down, 0.3 m back, the head sinking through the hold
##   edge pass 3 the third pass (_fifth_pass3): the hang's right knee folded and left leg long, its hips swaying 12 cm and
##               its head turning 20 degrees; the grab's reach wide and over the head; the climb's knees not splayed; the
##               roll in's apex over the lip, face forward, and a closed ball; the jump's 10 cm coil and locked arms at the
##               strike; the sweep at 0.7 m through 140 degrees; the forward roll's eased drop and closed ball; every roll's
##               hat clear of the deck (HAT_CLEAR); the side rolls' travel meta, lean and leading shoulder; the duck's mass
##               over the feet, its sinking hold and turned shoulders (the duck's heels may lift; its balls stay planted)
##   sixth set   round 3's P2 Rises and recoveries (2026-10-06, _sixth): the four Rises, the edge scramble, the tech, its roll
##               (and twin) and the wall's, the lie (a loop), the getup, its roll (and twin) and its attack, the spiked and
##               bounce knocks: each with its metas, length, twin or none, the IK's worst miss at most 5 mm; the airborne ones
##               from the fall's first pose (the one-shots back onto it, the air Rise's glide a seamless loop from
##               loop_from_s); each Rise its own element's read (earth: a wide horse planted on the column, leant with it,
##               fists down outside the knees with the arms nearly straight, the throw frame already sweeping up, thrown
##               off with the arms up; water: the circling hands out in front of the body, both over the head at the top
##               on both feet; fire: the tucked hover with the fists at the hips, the straight-legged burst led by the
##               fist and still driving; air: the palm thrust out at the shoulder's height in the whirl with the feet
##               together and no hand overhead, the wings spread near the shoulders in the glide) and the four apart from
##               each other; the scramble from under the lip, its slap on the face, its feet never through it, its last frame
##               the hang's first (every bone end within 1 cm), its hands thrown high over the lip; the tech's palm and
##               knee on the deck, the tech roll from its slap; the wall break's palms on its wall and the balls of the
##               feet touching it (5 mm), the palms off a frame before the soles; the lie's back, head and flung palm
##               on the deck (5 mm), flat, its knee swaying; the getups from the lie's first pose to the stand, the
##               carp's feet past the head and its arch, two whole log rolls, the crab's hips up; the bounce up off the deck flat (the shoulders with
##               the hips) and onto the lie's first pose; the getup attack's sweep low and wide; the spiked knock a
##               feet-first vertical plunge with the arms straight over the head after a fold; nothing on the deck
##               through it (3 cm). kept r3 p2: the fifth set's lengths and moments as they shipped
##   sixth pass 3 the critic's pass-2 notes (_sixth_pass3 and the reads above): the earth throw asymmetric (the right fist
##               driven up over the head as the left is chambered at the hip, both fists closed, the fists 10 cm and more
##               clear of the hat); the water Rise's crane (the right palm high over the head, the left pressed by the hip,
##               the hands 0.5 m apart in height), its knees soft on flat feet; the glide's elbows bent; the scramble's right
##               hand over the lip at hold_s and on the deck at strike_s, the left slapped on the face, the head over the lip
##               by f3; the slap's head over the hips and its palm out wide; the tech roll entered from the tech's own
##               airborne frame; the wall break's hat brim 8 cm off the wall; the lie's beat early (by f12); the getup's
##               pelvis never jumping 20 cm in a frame and settling after its overshoot; the crab sweep's leg near straight
##               (12 degrees); the bounce's heels and hands left on the deck while the trunk lifts
##   seventh set round 3's P2 Pop, Slams, held guards and teeter (2026-10-07, _seventh): each with its metas, length and
##               twin or none, the IK's worst miss at most 5 mm; the Slams' strike_s at most 0.2 s and at most 0.1 s after
##               the held wind-up, from and back onto the fall's first pose, each its own read (the Hammer's fists over the
##               head then below the hips, the Downpour's wide V then its palms pressed ahead at the hips with the body
##               risen, the Axe Kick's ankle over the head then chopped down ahead, the Down Gust's tucked knees then its
##               long legs, flared palms and lift) and the four wind-ups apart; the Pop's hand from the stand over the head
##               at its strike and on the Pop stone's surface (BendR3.pop_stone's place) closing round it to the end; the
##               held guards seamless loops with planted feet, each its guard's read (earth's rock between the palms,
##               water's palms level ahead, fire's knife hand ahead with the fist at the ribs, air's palms one high and one
##               low changing over) and apart; the teeter from the stand, the balls of the feet planted, the arms
##               windmilling over the head, leaning out at its held end. kept r3 slam: the sixth set's lengths and moments
##   seventh set pass 2 (2026-10-07, the critic's pass-1 notes; _seventh_pass2): the Pop's fist straight up (0.3 m over the
##               head), its unwind from the coil 40 degrees and more, and its twin ending on the original's own held-stone
##               pose (twin_tail_s: the right hand on the stone where the code holds it, meta stone_hand); the Hammer's arch
##               at the hold (the fists behind the head) and its fists finishing ahead of and below the knees; the
##               Downpour's palms ahead of the hips with the arms long and the body lifted 0.15 m; the Axe Kick's knee long
##               at the strike (20 degrees or less), the heel chopped ahead, its twin's legs never crossing and its ankles
##               never jumping more than 0.25 m a frame over its ends' blend; the Down Gust's palms driven 0.6 m down and
##               the body lifted 0.15 m; the earth guard's horse wide (the ankles 0.55 m apart) with a breath that reads
##               (the hips 3 cm and more); the fire guard's bounce 4 cm and more; the teeter's arms never stepping more
##               than 0.45 m a frame (55 degrees of the windmill) and the hips over or ahead of the balls of the feet
##   seventh set pass 3 (2026-10-07, the critic's pass-2 notes; _seventh_pass3): the Pop's stone_s (the stone shown from the
##               moment the hand reaches it: back_s) and its twin's rising left fist kept a fist and dropped back to the
##               guard (never out toward a stone) while its right hand starts for the stone by f11; the Hammer's, the
##               Downpour's and the Down Gust's biggest hand step landing on the strike (the Downpour's falling straight
##               down), the Hammer's fists hanging clear below the knees; the Downpour's trunk folded forward over its palms
##               and its palms sinking on past the strike against the rising body; the Axe Kick's rear leg folded under at
##               the strike and its crescent swung out wide of the hip; the Down Gust's wide flared palms, its knees kept
##               half tucked (unlike the Downpour's long column) and its spiral turning on past the strike; the teeter's
##               arms starting after the lurch, the hips tipped 0.14 m and more past the start, both heels up and both
##               palms held high and wide over the head at the end (the flailing V)
## Ends with "BEND_CLIPS PASSED" or "BEND_CLIPS FAILED" (exit 0 only on a pass; a watchdog quits 2 at LIMIT s).

const LIB := "res://animations_extra/Frontier_Bend.res"
const GLB := "res://assets/character/actor_b_body.glb"
const SOURCE_MD := "res://animations/SOURCE.md"
const LIMIT := 180.0
const FIRST_SET := ["own-bend-earth-stomp", "own-bend-earth-push", "own-bend-earth-rise", "own-bend-throw-overhand",
		"own-bend-throw-overhand-l", "own-bend-throw-sidearm", "own-bend-throw-sidearm-l", "own-bend-throw-underhand",
		"own-bend-knock-slide", "own-bend-knock-air"]
const SECOND_SET := ["own-bend-stance-earth", "own-bend-stance-fire", "own-bend-stance-water", "own-bend-stance-air",
		"own-bend-earth-boulder", "own-bend-earth-raise", "own-bend-earth-burrow", "own-bend-earth-catch", "own-bend-earth-shove",
		"own-bend-earth-shove-l", "own-bend-fire-punch", "own-bend-fire-punch-l", "own-bend-fire-double", "own-bend-fire-kick",
		"own-bend-fire-sweep", "own-bend-fire-sweep-l", "own-bend-fire-breath", "own-bend-fire-lightning", "own-bend-water-whip",
		"own-bend-water-whip-l", "own-bend-water-wave", "own-bend-water-draw", "own-bend-water-shield", "own-bend-air-palm",
		"own-bend-air-palm-l", "own-bend-air-sweep", "own-bend-air-spin", "own-bend-air-leap", "own-bend-air-shield"]
## The third set (round 2 of the skills): clip -> its twin ("" when it has none).
const THIRD_SET := {"own-bend-fire-kick-low": "own-bend-fire-kick-low-l", "own-bend-fire-kick": "own-bend-fire-kick-l",
		"own-bend-fire-fireball": "own-bend-fire-fireball-l", "own-bend-fire-parry": "", "own-bend-earth-kickup": "own-bend-earth-kickup-l",
		"own-bend-earth-uproot": "", "own-bend-earth-catch": "", "own-bend-water-turn": "", "own-bend-water-turn-hold": "",
		"own-bend-water-surf": "", "own-bend-water-skate": "", "own-bend-air-pull": "", "own-bend-air-slip": "own-bend-air-slip-l",
		"own-bend-air-slip-back": "", "own-bend-air-wall": "", "own-bend-air-guard": "", "own-bend-air-shield-hold": "",
		"own-bend-air-slice": "own-bend-air-slice-l"}
## The third set's clips the body carries (the game moves it while they play): legs_always.
const LEGS_ALWAYS := ["own-bend-fire-kick-low", "own-bend-fire-kick-low-l", "own-bend-air-slip", "own-bend-air-slip-l",
		"own-bend-air-slip-back", "own-bend-water-surf", "own-bend-water-skate"]
## The 39 clips before round 2: [length in frames, hold, strike, back, up] (frames at 30 fps; -1 none). Their moments kept.
const BEFORE_R2 := {"own-bend-air-leap": [32, 6, 9, 20, -1], "own-bend-air-palm": [28, 5, 8, 16, -1],
		"own-bend-air-palm-l": [28, 5, 8, 16, -1], "own-bend-air-shield": [38, 9, 13, 24, -1], "own-bend-air-spin": [36, 5, 8, 20, -1],
		"own-bend-air-sweep": [36, 7, 11, 22, -1], "own-bend-earth-boulder": [50, 19, 23, 33, -1],
		"own-bend-earth-burrow": [34, 6, 9, 20, -1], "own-bend-earth-catch": [38, 7, 10, 26, -1], "own-bend-earth-push": [40, 9, 13, 24, -1],
		"own-bend-earth-raise": [40, 10, 14, 25, -1], "own-bend-earth-rise": [40, 10, 14, 25, -1], "own-bend-earth-shove": [34, 7, 11, 22, -1],
		"own-bend-earth-shove-l": [34, 7, 11, 22, -1], "own-bend-earth-stomp": [42, 10, 14, 27, -1],
		"own-bend-fire-breath": [40, 10, 13, 26, -1], "own-bend-fire-double": [30, 5, 8, 18, -1], "own-bend-fire-kick": [36, 6, 9, 22, -1],
		"own-bend-fire-lightning": [64, 32, 36, 47, -1], "own-bend-fire-punch": [26, 5, 8, 15, -1],
		"own-bend-fire-punch-l": [26, 5, 8, 15, -1], "own-bend-fire-sweep": [30, 6, 9, 18, -1], "own-bend-fire-sweep-l": [30, 6, 9, 18, -1],
		"own-bend-knock-air": [44, 10, 1, 30, 26], "own-bend-knock-slide": [36, 9, 1, 21, -1], "own-bend-stance-air": [96, -1, -1, -1, -1],
		"own-bend-stance-earth": [84, -1, -1, -1, -1], "own-bend-stance-fire": [40, -1, -1, -1, -1],
		"own-bend-stance-water": [108, -1, -1, -1, -1], "own-bend-throw-overhand": [36, 6, 10, 21, -1],
		"own-bend-throw-overhand-l": [36, 6, 10, 21, -1], "own-bend-throw-sidearm": [36, 6, 9, 21, -1],
		"own-bend-throw-sidearm-l": [36, 6, 9, 21, -1], "own-bend-throw-underhand": [34, 6, 9, 19, -1],
		"own-bend-water-draw": [44, 11, 15, 27, -1], "own-bend-water-shield": [36, 6, 10, 22, -1], "own-bend-water-wave": [42, 11, 15, 26, -1],
		"own-bend-water-whip": [32, 6, 10, 20, -1], "own-bend-water-whip-l": [32, 6, 10, 20, -1]}
## The IK's worst miss a third-set clip may have (m; wave 3's bar).
const IK_MISS := 0.005
## The third set (round 2): [length in frames, hold, strike, back, up] (-1 none). Their moments kept by round 3.
const BEFORE_R3 := {"own-bend-fire-kick-low": [32, 6, 9, 20, -1], "own-bend-fire-kick-low-l": [32, 6, 9, 20, -1],
		"own-bend-fire-fireball": [36, 8, 11, 22, -1], "own-bend-fire-fireball-l": [36, 8, 11, 22, -1],
		"own-bend-fire-parry": [30, 4, 8, 16, -1], "own-bend-earth-kickup": [18, 3, 6, 10, -1],
		"own-bend-earth-kickup-l": [18, 3, 6, 10, -1], "own-bend-earth-uproot": [42, 10, 14, 26, -1],
		"own-bend-water-turn": [36, 5, 14, 24, -1], "own-bend-water-turn-hold": [48, -1, -1, -1, -1],
		"own-bend-air-pull": [34, 6, 11, 22, -1], "own-bend-air-slip": [26, 3, 8, 16, -1], "own-bend-air-slip-l": [26, 3, 8, 16, -1],
		"own-bend-air-slip-back": [26, 3, 8, 16, -1], "own-bend-air-wall": [38, 7, 11, 26, -1], "own-bend-air-guard": [32, 5, 10, 18, -1],
		"own-bend-air-shield-hold": [40, -1, -1, -1, -1], "own-bend-air-slice": [28, 5, 8, 16, -1],
		"own-bend-air-slice-l": [28, 5, 8, 16, -1], "own-bend-water-surf": [48, -1, -1, -1, -1],
		"own-bend-water-skate": [30, 5, 9, 20, -1], "own-bend-fire-kick-l": [36, 6, 9, 22, -1]}
## The fourth set (round 3's P1 air and hit states): clip -> [mask, length in frames, a loop]. None has a side (no twin).
const FOURTH_SET := {"own-bend-tumble": ["full", 24, true], "own-bend-flinch": ["upper", 9, false],
		"own-bend-jump-double": ["full", 12, false], "own-bend-fall": ["full", 20, true], "own-bend-fall-fast": ["full", 16, true],
		"own-bend-helpless": ["full", 24, true], "own-bend-air-dodge": ["full", 15, false], "own-bend-air-legs": ["lower", 24, true],
		"own-bend-land-light": ["full", 10, false], "own-bend-land-heavy": ["full", 16, false]}
## Its airborne one-shots: they start and end on the fall's first pose (they hand over to the fall loop and to each other).
const FROM_AIR := ["own-bend-jump-double", "own-bend-air-dodge"]
## Its reactions: the hit or the touchdown (strike_s) comes before the hold.
const REACTIONS := ["own-bend-flinch", "own-bend-land-light", "own-bend-land-heavy"]
const LANDINGS := ["own-bend-land-light", "own-bend-land-heavy"]
## The helpless fall's hands over the shoulders at every frame (m): a tall V, not hands up at the head's height.
const HELPLESS_OVER := 0.1
## The fast fall's ankles under the hips (m): long, with the knees drawn up a little (the tucked arrow).
const FALL_FAST_LONG := 0.5
## The first set's timing contracts (s): kept through the polish.
const CONTRACTS := {"own-bend-earth-stomp": [10, 14], "own-bend-earth-push": [9, 13], "own-bend-earth-rise": [10, 14],
		"own-bend-throw-overhand": [6, 10], "own-bend-throw-sidearm": [6, 9], "own-bend-throw-underhand": [6, 9],
		"own-bend-knock-slide": [9, 1], "own-bend-knock-air": [10, 1]}
## Round 1's IK-clamped moments (frames): [clip, frame, palm or ankle bone].
const CLAMPED := [["own-bend-throw-underhand", 6, "r_palm"], ["own-bend-knock-slide", 3, "l_palm"], ["own-bend-knock-slide", 3, "r_palm"],
		["own-bend-knock-air", 9, "r_palm"], ["own-bend-knock-air", 16, "l_palm"], ["own-bend-earth-rise", 10, "r_palm"],
		["own-bend-earth-stomp", 24, "l_palm"]]
## The fourth set's lengths and moments as they shipped (frames; -1 none): kept by the fifth set's bake.
const BEFORE_R3P1EDGE := {"own-bend-tumble": [24, -1, -1, -1, -1], "own-bend-flinch": [9, 3, 1, 5, -1],
		"own-bend-jump-double": [12, 2, 3, 8, -1], "own-bend-fall": [20, -1, -1, -1, -1], "own-bend-fall-fast": [16, -1, -1, -1, -1],
		"own-bend-helpless": [24, -1, -1, -1, -1], "own-bend-air-dodge": [15, 1, 2, 9, -1], "own-bend-air-legs": [24, -1, -1, -1, -1],
		"own-bend-land-light": [10, 3, 1, 5, -1], "own-bend-land-heavy": [16, 3, 1, 8, -1]}
## The fifth set (round 3's P1 edge and ground dodges): clip -> [length in frames, a loop, its twin ("" none)]. All mask full,
## legs_always (the code moves or holds the body under them).
const FIFTH_SET := {"own-bend-edge-grab": [6, false, ""], "own-bend-edge-hang": [30, true, ""],
		"own-bend-edge-climb": [15, false, ""], "own-bend-edge-roll": [22, false, ""], "own-bend-edge-jump": [9, false, ""],
		"own-bend-edge-attack": [18, false, ""], "own-bend-roll-f": [18, false, ""], "own-bend-roll-b": [18, false, ""],
		"own-bend-roll-side": [18, false, "own-bend-roll-side-l"], "own-bend-duck": [14, false, ""]}
## The edge get-ups: they start on the hang's first pose and end standing on the deck (meta end_in m in from the lip).
const EDGE_GETUPS := ["own-bend-edge-climb", "own-bend-edge-roll", "own-bend-edge-attack"]
## The ground dodges: they start and end on the stand.
const GROUND_DODGES := ["own-bend-roll-f", "own-bend-roll-b", "own-bend-roll-side", "own-bend-roll-side-l", "own-bend-duck"]
## The hang's feet on the deck's face: the balls of the feet within this of its plane (m), below the lip.
const FACE_TOUCH := 0.07
## The body's surface round its joints (m; bend_clips.py's SURF): the lowest is where it meets the deck.
const SURF := {"heada": 0.11, "neck": 0.07, "spinea": 0.12, "spineb": 0.11, "spinec": 0.11, "spined": 0.11, "pelvis": 0.12,
		"l_shoulder": 0.07, "r_shoulder": 0.07, "l_elbow": 0.045, "r_elbow": 0.045, "l_wrist": 0.035, "r_wrist": 0.035,
		"l_palm": 0.025, "r_palm": 0.025, "l_upper_leg": 0.09, "r_upper_leg": 0.09, "l_knee": 0.055, "r_knee": 0.055,
		"l_ankle": 0.045, "r_ankle": 0.045, "l_heel": 0.0, "r_heel": 0.0, "l_ball": 0.02, "r_ball": 0.02}
## The parts the lie rests on (its back, its head, the flung right palm): touching the deck.
const LIE_CONTACT := ["pelvis", "spinea", "spineb", "spinec", "spined", "heada", "r_palm"]
## The ball of the foot's own radius (SURF's): a sole's ball touching a wall has its centre this far in from it (m).
const BALL_R := 0.02
## Pass 2: the hang's hips held off the face (m); the rolls' heads clear of the deck while they roll (m); the edge jump's
## lift by the code (spec 5.3: vy 11.8 m/s at once, the ring's gravity), which the clip takes back through its push.
const HANG_HIPS_OUT := 0.3
const ROLL_HEAD_CLEAR := 0.04
const EDGE_JUMP_VY := 11.8
const EDGE_JUMP_G := 19.9
## Pass 3: the tricorne's corners and crown on headb at rest (m; bend_clips.py's HAT_REST, read off the glb's Hat mesh), and
## how far its lowest point keeps off the deck while a roll turns over (the brim, not only the skull).
const HAT_REST := [Vector3(0.0, 1.54, 0.2), Vector3(0.16, 1.54, -0.02), Vector3(-0.16, 1.54, -0.02), Vector3(0.0, 1.55, -0.095),
		Vector3(0.0, 1.627, 0.03)]
const HAT_CLEAR := {"own-bend-edge-roll": 0.1, "own-bend-roll-f": 0.08, "own-bend-roll-b": 0.1, "own-bend-roll-side": 0.1,
		"own-bend-roll-side-l": 0.1}
## The sixth set (round 3's P2 Rises and recoveries): clip -> [length in frames, a loop, its twin ("" none)]. All mask full.
const SIXTH_SET := {"own-bend-rise-earth": [32, false, ""], "own-bend-rise-water": [28, false, ""],
		"own-bend-rise-fire": [24, false, ""], "own-bend-rise-air": [44, false, ""], "own-bend-edge-scramble": [18, false, ""],
		"own-bend-tech": [14, false, ""], "own-bend-tech-roll": [19, false, "own-bend-tech-roll-l"],
		"own-bend-tech-wall": [15, false, ""], "own-bend-lie": [40, true, ""], "own-bend-getup": [20, false, ""],
		"own-bend-getup-roll": [26, false, "own-bend-getup-roll-l"], "own-bend-getup-attack": [20, false, ""],
		"own-bend-knock-spiked": [22, false, ""], "own-bend-knock-bounce": [18, false, ""]}
## Its reactions (the contact or the hit, then the hold): strike_s before hold_s.
const REACTIONS6 := ["own-bend-tech", "own-bend-tech-wall", "own-bend-knock-spiked", "own-bend-knock-bounce"]
## Its airborne ones that start on the fall's first pose (they take over from it).
const FROM_AIR6 := ["own-bend-rise-earth", "own-bend-rise-water", "own-bend-rise-fire", "own-bend-rise-air", "own-bend-knock-spiked"]
## Its airborne ones that end on the fall's first pose (they hand back to it; the air Rise's glide loops instead, and the wall
## break starts from the tumble that throws him into the wall).
const TO_AIR6 := ["own-bend-rise-earth", "own-bend-rise-water", "own-bend-rise-fire", "own-bend-tech-wall", "own-bend-knock-spiked"]
## Its ones that end standing on the deck (the stand).
const TO_STAND6 := ["own-bend-tech", "own-bend-tech-roll", "own-bend-tech-roll-l", "own-bend-getup", "own-bend-getup-roll",
		"own-bend-getup-roll-l", "own-bend-getup-attack"]
## Its getups: they start on the lie's first pose.
const FROM_LIE := ["own-bend-getup", "own-bend-getup-roll", "own-bend-getup-roll-l", "own-bend-getup-attack"]
## Its ones on the deck (legs_always; never through it).
const ON_DECK := ["own-bend-tech", "own-bend-tech-roll", "own-bend-lie", "own-bend-getup", "own-bend-getup-roll",
		"own-bend-getup-attack", "own-bend-knock-bounce"]
## The fifth set's lengths and moments as they shipped (frames; -1 none): kept by the sixth set's bake.
const BEFORE_R3P2 := {"own-bend-edge-grab": [6, 1, 2, 4, -1], "own-bend-edge-hang": [30, -1, -1, -1, -1],
		"own-bend-edge-climb": [15, 3, 6, 9, -1], "own-bend-edge-roll": [22, 5, 7, 15, -1], "own-bend-edge-jump": [9, 1, 2, 5, -1],
		"own-bend-edge-attack": [18, 6, 9, 12, -1], "own-bend-roll-f": [18, 2, 7, 13, -1], "own-bend-roll-b": [18, 2, 7, 13, -1],
		"own-bend-roll-side": [18, 2, 7, 13, -1], "own-bend-roll-side-l": [18, 2, 7, 13, -1], "own-bend-duck": [14, 3, 4, 9, -1]}
## The seventh set (round 3's P2 Pop, Slams, held guards and teeter): clip -> [length in frames, a loop, its twin ("" none),
## its mask].
const SEVENTH_SET := {"own-bend-jab-rise": [24, false, "own-bend-jab-rise-l", "upper"],
		"own-bend-earth-hammer": [22, false, "", "full"], "own-bend-water-downpour": [24, false, "", "full"],
		"own-bend-fire-axe-kick": [22, false, "own-bend-fire-axe-kick-l", "full"], "own-bend-air-down-gust": [22, false, "", "full"],
		"own-bend-guard-hold-earth": [40, true, "", "full"], "own-bend-guard-hold-water": [48, true, "", "full"],
		"own-bend-guard-hold-fire": [24, true, "", "full"], "own-bend-guard-hold-air": [40, true, "", "full"],
		"own-bend-teeter": [15, false, "", "full"]}
## The Slams (spec 6.2: the strike early, lock 0.3-0.35 s, out about 0.1 s after the release): strike_s at most SLAM_STRIKE_S,
## at most SLAM_RELEASE_S after hold_s (the held wind-up).
const SLAMS := ["own-bend-earth-hammer", "own-bend-water-downpour", "own-bend-fire-axe-kick", "own-bend-fire-axe-kick-l",
		"own-bend-air-down-gust"]
const SLAM_STRIKE_S := 0.2
const SLAM_RELEASE_S := 0.1
## Earth's Pop stone where the code holds it (BendR3.pop_stone: 0.55 m ahead, 0.45 m to the right, 1.25 m up, radius 0.22 m),
## in the figure's frame (+X his left, +Z ahead): the Pop's hand ends on its surface (the palm bone within POP_TOUCH of it).
const POP_STONE := Vector3(-0.45, 1.25, 0.55)
const POP_STONE_R := 0.22
const POP_TOUCH := 0.04
const GUARDS := ["own-bend-guard-hold-earth", "own-bend-guard-hold-water", "own-bend-guard-hold-fire", "own-bend-guard-hold-air"]
## The sixth set's lengths and moments as they shipped (frames; -1 none): kept by the seventh set's bake.
const BEFORE_R3SLAM := {"own-bend-rise-earth": [32, 6, 20, 24, -1], "own-bend-rise-water": [28, 2, 4, 21, -1],
		"own-bend-rise-fire": [24, 4, 8, 18, -1], "own-bend-rise-air": [44, 2, 3, 14, -1], "own-bend-edge-scramble": [18, 2, 3, 12, -1],
		"own-bend-tech": [14, 2, 1, 4, -1], "own-bend-tech-roll": [19, 2, 8, 14, -1], "own-bend-tech-roll-l": [19, 2, 8, 14, -1],
		"own-bend-tech-wall": [15, 3, 1, 5, -1], "own-bend-lie": [40, -1, -1, -1, -1], "own-bend-getup": [20, 4, 9, 11, -1],
		"own-bend-getup-roll": [26, 2, 5, 15, -1], "own-bend-getup-roll-l": [26, 2, 5, 15, -1],
		"own-bend-getup-attack": [20, 4, 7, 10, -1], "own-bend-knock-spiked": [22, 5, 1, 14, -1],
		"own-bend-knock-bounce": [18, 2, 1, 8, -1]}
const BANNED_METAS := ["native_asset_id", "source_attribution", "original_name"]
## Clips whose stance moves for good (the root may end elsewhere).
const MOVED_STANCE := ["own-bend-earth-stomp"]
const JOINTS := ["l_palm", "r_palm", "l_ankle", "r_ankle"]

var checks := 0
var fails: Array[String] = []
var sk: Skeleton3D


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT, true, false, true).timeout.connect(func() -> void:
		print("BEND_CLIPS FAILED (watchdog)")
		quit(2))
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func _run() -> void:
	var lib := load(LIB) as AnimationLibrary
	_check(lib != null, "the library loads (%s)" % LIB)
	if lib == null:
		_end()
		return
	var body := (load(GLB) as PackedScene).instantiate() as Node3D
	root.add_child(body)
	sk = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for ap: AnimationPlayer in body.find_children("*", "AnimationPlayer", true, false):
		ap.active = false
	await process_frame
	var names: Array[String] = []
	for n: StringName in lib.get_animation_list():
		names.append(String(n))
	names.sort()
	print("BEND_CLIPS library: ", names)
	# first set
	for want: String in FIRST_SET:
		_check(want in names, "first set: %s in the library" % want)
	for want: String in SECOND_SET:
		_check(want in names, "second set: %s in the library" % want)
	for nm: String in CONTRACTS:
		if nm in names:
			var ca := lib.get_animation(StringName(nm))
			_check(is_equal_approx(float(ca.get_meta(&"hold_s", -1.0)), CONTRACTS[nm][0] / 30.0)
					and is_equal_approx(float(ca.get_meta(&"strike_s", -1.0)), CONTRACTS[nm][1] / 30.0),
					"%s: the timing contract kept (hold f%d, strike f%d)" % [nm, CONTRACTS[nm][0], CONTRACTS[nm][1]])
	for e: Array in CLAMPED:
		if String(e[0]) in names:
			var reach := _reach(lib.get_animation(StringName(String(e[0]))), int(e[1]) / 30.0, String(e[2]))
			_check(reach > 0.0, "%s f%d: the %s's arm short of straight (%.3f m to spare)" % [e[0], e[1], e[2], reach])
	if "own-bend-earth-boulder" in names:
		_boulder(lib.get_animation(&"own-bend-earth-boulder"))
	# third set
	for nm: String in THIRD_SET:
		_check(nm in names, "third set: %s in the library" % nm)
		var twin := String(THIRD_SET[nm])
		if twin != "":
			_check(twin in names, "third set: %s's twin %s in the library" % [nm, twin])
	for nm in names:
		var a := lib.get_animation(StringName(nm))
		if THIRD_SET.has(nm) or (nm.ends_with("-l") and THIRD_SET.has(nm.trim_suffix("-l"))):
			for key in ["hand", "mask", "root"]:
				_check(a.has_meta(StringName(key)), "%s: has %s" % [nm, key])
			# (the High Kick's own clip is the second set's, not re-baked: its twin carries the bake's number)
			if nm == "own-bend-fire-kick":
				continue
			_check(a.has_meta(&"ik_miss_m") and float(a.get_meta(&"ik_miss_m")) <= IK_MISS + 1e-6,
					"%s: the IK's worst miss %.4f m <= %.3f" % [nm, float(a.get_meta(&"ik_miss_m", 1.0)), IK_MISS])
			if nm in LEGS_ALWAYS:
				_check(bool(a.get_meta(&"legs_always", false)), "%s: legs_always (the body moves under it)" % nm)
	# kept r3
	for nm: String in BEFORE_R3:
		_check(nm in names, "kept r3: %s still in the library" % nm)
		if not nm in names:
			continue
		var a3 := lib.get_animation(StringName(nm))
		var want3: Array = BEFORE_R3[nm]
		var got3 := [int(round(a3.length * 30.0))]
		for key in ["hold_s", "strike_s", "back_s", "up_s"]:
			got3.append(int(round(float(a3.get_meta(key)) * 30.0)) if a3.has_meta(key) else -1)
		_check(got3 == want3, "kept r3: %s's length and moments %s (were %s)" % [nm, str(got3), str(want3)])
	# fourth set
	_fourth(lib, names)
	# kept r3 p1: the fourth set's lengths and moments as they shipped
	for nm: String in BEFORE_R3P1EDGE:
		if not nm in names:
			continue
		var a4 := lib.get_animation(StringName(nm))
		var got4 := [int(round(a4.length * 30.0))]
		for key in ["hold_s", "strike_s", "back_s", "up_s"]:
			got4.append(int(round(float(a4.get_meta(key)) * 30.0)) if a4.has_meta(key) else -1)
		_check(got4 == BEFORE_R3P1EDGE[nm], "kept r3 p1: %s's length and moments %s (were %s)" % [nm, str(got4),
				str(BEFORE_R3P1EDGE[nm])])
	# fifth set
	_fifth(lib, names)
	_fifth_pass2(lib, names)
	_fifth_pass3(lib, names)
	# kept r3 p2: the fifth set's lengths and moments as they shipped
	for nm: String in BEFORE_R3P2:
		if not nm in names:
			continue
		var a5 := lib.get_animation(StringName(nm))
		var got5 := [int(round(a5.length * 30.0))]
		for key in ["hold_s", "strike_s", "back_s", "up_s"]:
			got5.append(int(round(float(a5.get_meta(key)) * 30.0)) if a5.has_meta(key) else -1)
		_check(got5 == BEFORE_R3P2[nm], "kept r3 p2: %s's length and moments %s (were %s)" % [nm, str(got5), str(BEFORE_R3P2[nm])])
	# sixth set
	_sixth(lib, names)
	# seventh set
	_seventh(lib, names)
	# kept r3 slam: the sixth set's lengths and moments as they shipped
	for nm: String in BEFORE_R3SLAM:
		_check(nm in names, "kept r3 slam: %s still in the library" % nm)
		if not nm in names:
			continue
		var a6 := lib.get_animation(StringName(nm))
		var got6 := [int(round(a6.length * 30.0))]
		for key in ["hold_s", "strike_s", "back_s", "up_s"]:
			got6.append(int(round(float(a6.get_meta(key)) * 30.0)) if a6.has_meta(key) else -1)
		_check(got6 == BEFORE_R3SLAM[nm], "kept r3 slam: %s's length and moments %s (were %s)" % [nm, str(got6),
				str(BEFORE_R3SLAM[nm])])
	# kept
	for nm: String in BEFORE_R2:
		_check(nm in names, "kept: %s still in the library" % nm)
		if not nm in names:
			continue
		var a := lib.get_animation(StringName(nm))
		var want: Array = BEFORE_R2[nm]
		var got := [int(round(a.length * 30.0))]
		for key in ["hold_s", "strike_s", "back_s", "up_s"]:
			got.append(int(round(float(a.get_meta(key)) * 30.0)) if a.has_meta(key) else -1)
		_check(got == want, "kept: %s's length and moments %s (were %s)" % [nm, str(got), str(want)])
	if "own-bend-fire-kick-low" in names and "own-bend-fire-kick" in names:
		_low_kick(lib.get_animation(&"own-bend-fire-kick-low"), lib.get_animation(&"own-bend-fire-kick"))
	# own
	for m: String in BANNED_METAS:
		_check(not lib.has_meta(StringName(m)), "the library carries no %s" % m)
	for nm in names:
		var a := lib.get_animation(StringName(nm))
		_check(nm.begins_with("own-bend-"), "%s: an own-bend- name" % nm)
		_check(String(a.get_meta(&"authored", "")).contains("bend_clips.py"), "%s: authored names bend_clips.py" % nm)
		for m: String in BANNED_METAS:
			_check(not a.has_meta(StringName(m)), "%s: no %s meta" % [nm, m])
		var unknown := []
		for i in a.get_track_count():
			if sk.find_bone(String(a.track_get_path(i).get_concatenated_subnames())) < 0:
				unknown.append(String(a.track_get_path(i)))
		_check(unknown.is_empty(), "%s: every track a bone of the rig %s" % [nm, str(unknown)])
		if FOURTH_SET.has(nm) or _fifth_has(nm) or _sixth_has(nm) or _seventh_has(nm):
			continue                                # (its own checks: _fourth, _fifth, _sixth, _seventh)
		if a.has_meta(&"loop"):
			_stance(nm, a)
			continue
		_moments(nm, a)
		_place(nm, a)
	# a common stand at both ends (the casts and the knocks; a stance is its own)
	var casts := names.filter(func(x: String) -> bool: return not (lib.get_animation(StringName(x)).has_meta(&"loop")
			or FOURTH_SET.has(x) or _fifth_has(x) or _sixth_has(x) or _seventh_has(x)))
	if not casts.is_empty():
		var ref := _joints(lib.get_animation(StringName(casts[0])), 0.0)
		for nm: String in casts:
			var a := lib.get_animation(StringName(nm))
			for t in [0.0, a.length]:
				var j := _joints(a, t)
				var worst := 0.0
				for k: String in JOINTS:
					worst = maxf(worst, (j[k] as Vector3).distance_to(ref[k]))
				_check(worst < 0.02, "%s: on the stand at %.2f s (the palms and ankles off by %.3f m)" % [nm, t, worst])
	# twins
	for nm in names:
		if not nm.ends_with("-l"):
			continue
		var orig := nm.trim_suffix("-l")
		_check(orig in names, "%s: its original %s is there" % [nm, orig])
		if not orig in names:
			continue
		var a := lib.get_animation(StringName(orig))
		var b := lib.get_animation(StringName(nm))
		_check(is_equal_approx(a.length, b.length), "%s: the original's length" % nm)
		for key in ["hold_s", "strike_s", "back_s"]:
			_check(is_equal_approx(float(a.get_meta(key, -1.0)), float(b.get_meta(key, -1.0))), "%s: the original's %s" % [nm, key])
		_check(String(b.get_meta(&"hand", "")) == {"r": "l", "l": "r", "foot_r": "foot_l", "foot_l": "foot_r"}.get(
				String(a.get_meta(&"hand", "")), String(a.get_meta(&"hand", ""))),
				"%s: the other hand (%s)" % [nm, b.get_meta(&"hand", "")])
		for t in [float(a.get_meta(&"hold_s", 0.0)), float(a.get_meta(&"strike_s", 0.0)), a.length * 0.6, a.length]:
			# (twin_ends: the twin leaves and lands on the original's own unmirrored pose, the fall's first: its end is checked
			# against that pose in _seventh_slams instead)
			if a.has_meta(&"twin_ends") and t >= a.length - 1e-4:
				continue
			# (and past its back_s the twin_ends twin blends onto that unmirrored pose: its legs checked never to cross nor jump
			# there in _seventh_pass2 instead)
			if a.has_meta(&"twin_ends") and t > float(a.get_meta(&"back_s", a.length)) + 1e-4:
				continue
			# (twin_tail_s: from then on the twin is the original's own pose, unmirrored: the Pop's twin ends with the right
			# hand on the stone; checked in _seventh_pass2 instead)
			if a.has_meta(&"twin_tail_s") and t >= float(a.get_meta(&"twin_tail_s")) - 1e-4:
				continue
			var ja := _joints(a, t)
			var jb := _joints(b, t)
			var worst := 0.0
			for k: String in JOINTS:
				var other := ("r_" if k.begins_with("l_") else "l_") + k.substr(2)
				var mirrored := ja[other] as Vector3
				mirrored.x = -mirrored.x
				worst = maxf(worst, mirrored.distance_to(jb[k]))
			_check(worst < 0.01, "%s: the mirror of %s at %.2f s (off by %.4f m)" % [nm, orig, t, worst])
	# record
	var md := FileAccess.get_file_as_string(SOURCE_MD)
	var rows := _table_names(md)
	_check(not rows.is_empty(), "SOURCE.md has the Frontier_Bend.res table")
	for nm in names:
		_check(nm in rows, "SOURCE.md records %s" % nm)
	body.queue_free()
	_end()


func _moments(nm: String, a: Animation) -> void:
	for key in ["hold_s", "strike_s", "back_s", "hand", "mask"]:
		_check(a.has_meta(StringName(key)), "%s: has %s" % [nm, key])
	if not (a.has_meta(&"hold_s") and a.has_meta(&"strike_s") and a.has_meta(&"back_s")):
		return
	var hold := float(a.get_meta(&"hold_s"))
	var strike := float(a.get_meta(&"strike_s"))
	var back := float(a.get_meta(&"back_s"))
	for v in [hold, strike, back]:
		_check(v >= 0.0 and v <= a.length + 1e-4, "%s: %.3f s within the length %.3f" % [nm, v, a.length])
	_check(String(a.get_meta(&"mask", "")) == "full", "%s: mask full" % nm)
	_check(String(a.get_meta(&"hand", "")) in ["r", "l", "both", "foot_r", "foot_l"], "%s: hand %s" % [nm, a.get_meta(&"hand", "")])
	if nm.contains("-knock-"):
		_check(strike < hold and hold < back, "%s: the hit, then the hold, then the recovery (%.2f %.2f %.2f)" % [nm, strike, hold, back])
		if a.has_meta(&"up_s"):
			var up := float(a.get_meta(&"up_s"))
			_check(up > hold and up <= back, "%s: the landing between the hold and the recovery (%.2f)" % [nm, up])
	else:
		_check(hold <= strike and strike < back, "%s: the hold, the strike, the recovery (%.2f %.2f %.2f)" % [nm, hold, strike, back])
	if nm.contains("-throw-"):
		_check(hold <= 0.2 + 1e-4, "%s: the throw's hold %.3f <= 0.2 s" % [nm, hold])
		var gap := strike - hold
		_check(gap >= 0.06 - 1e-4 and gap <= 0.2 + 1e-4, "%s: the release %.3f s after the hold (0.06..0.2)" % [nm, gap])


## The fourth set (round 3's P1 air and hit states): each there with its metas and length; loops seamless; the airborne
## one-shots on the fall's first pose at both ends; the landings planted and ending on the stand; each reading as its state.
func _fourth(lib: AnimationLibrary, names: Array[String]) -> void:
	var stand := _joints(lib.get_animation(StringName(FIRST_SET[0])), 0.0) if FIRST_SET[0] in names else {}
	var fall: Animation = lib.get_animation(&"own-bend-fall") if "own-bend-fall" in names else null
	for nm: String in FOURTH_SET:
		_check(nm in names, "fourth set: %s in the library" % nm)
		_check(not (nm + "-l") in names, "fourth set: %s has no side (no twin)" % nm)
		if not nm in names:
			continue
		var a := lib.get_animation(StringName(nm))
		var want: Array = FOURTH_SET[nm]
		for key in ["hand", "mask", "root"]:
			_check(a.has_meta(StringName(key)), "%s: has %s" % [nm, key])
		_check(String(a.get_meta(&"mask", "")) == String(want[0]), "%s: mask %s (%s)" % [nm, want[0], a.get_meta(&"mask", "")])
		_check(int(round(a.length * 30.0)) == int(want[1]), "%s: %d frames (%d)" % [nm, want[1], int(round(a.length * 30.0))])
		_check(a.has_meta(&"ik_miss_m") and float(a.get_meta(&"ik_miss_m")) <= IK_MISS + 1e-6,
				"%s: the IK's worst miss %.4f m <= %.3f" % [nm, float(a.get_meta(&"ik_miss_m", 1.0)), IK_MISS])
		print("BEND_CLIPS %s ik_miss_m %.4f" % [nm, float(a.get_meta(&"ik_miss_m", 1.0))])
		if bool(want[2]):
			_check(a.loop_mode == Animation.LOOP_LINEAR and a.has_meta(&"loop"), "%s: loops" % nm)
			_check(not a.has_meta(&"strike_s"), "%s: a loop, no strike" % nm)
			var j0 := _at(a, 0.0, ["l_palm", "r_palm", "l_ankle", "r_ankle", "heada", "root"])
			var j1 := _at(a, a.length, ["l_palm", "r_palm", "l_ankle", "r_ankle", "heada", "root"])
			var seam := 0.0
			for k: String in j0:
				seam = maxf(seam, (j0[k] as Vector3).distance_to(j1[k]))
			_check(seam < 0.005, "%s: the loop's seam (%.4f m)" % [nm, seam])
		else:
			for key in ["hold_s", "strike_s", "back_s"]:
				_check(a.has_meta(StringName(key)) and float(a.get_meta(StringName(key))) >= 0.0
						and float(a.get_meta(StringName(key))) <= a.length + 1e-4, "%s: %s within the clip" % [nm, key])
			var hold := float(a.get_meta(&"hold_s", 0.0))
			var strike := float(a.get_meta(&"strike_s", 0.0))
			var back := float(a.get_meta(&"back_s", 0.0))
			if nm in REACTIONS:
				_check(strike < hold and hold < back, "%s: the hit / touchdown, the hold, the recovery (%.2f %.2f %.2f)"
						% [nm, strike, hold, back])
			else:
				_check(hold <= strike and strike < back, "%s: the gather, the key moment, the recovery (%.2f %.2f %.2f)"
						% [nm, hold, strike, back])
			_place(nm, a)
		if nm in FROM_AIR and fall != null:
			var f0 := _joints(fall, 0.0)
			for t in [0.0, a.length]:
				var j := _joints(a, t)
				var worst := 0.0
				for k: String in JOINTS:
					worst = maxf(worst, (j[k] as Vector3).distance_to(f0[k]))
				_check(worst < 0.02, "%s: on the fall's first pose at %.2f s (off by %.3f m)" % [nm, t, worst])
		if nm in LANDINGS and fall != null:
			# (the touchdown starts on the fall's arms, so the crossfade from the air never lifts them first)
			var fa := _joints(fall, 0.0)
			var j0 := _joints(a, 0.0)
			var arms := maxf((j0.l_palm as Vector3).distance_to(fa.l_palm), (j0.r_palm as Vector3).distance_to(fa.r_palm))
			_check(arms < 0.02, "%s: starts on the fall's arms (off by %.3f m)" % [nm, arms])
		if nm in LANDINGS and not stand.is_empty():
			var je := _joints(a, a.length)
			var worst := 0.0
			for k: String in JOINTS:
				worst = maxf(worst, (je[k] as Vector3).distance_to(stand[k]))
			_check(worst < 0.02, "%s: ends on the stand (off by %.3f m)" % [nm, worst])
			var slide := 0.0
			var strike := float(a.get_meta(&"strike_s", 0.0))
			for i in 13:
				var t := strike + (a.length - strike) * i / 12.0
				var j := _joints(a, t)
				for k: String in ["l_ankle", "r_ankle"]:
					slide = maxf(slide, (j[k] as Vector3).distance_to(je[k]))
			_check(slide < 0.01, "%s: the feet planted from the touchdown on (%.4f m)" % [nm, slide])
	_fourth_reads(lib, names)
	_fourth_pass2(lib, names)


func _fifth_has(nm: String) -> bool:
	return FIFTH_SET.has(nm) or (nm.ends_with("-l") and FIFTH_SET.has(nm.trim_suffix("-l")))


## The fifth set (round 3's P1 edge and ground dodges, 2026-10-06): each there with its metas, length and twin; the IK's
## worst miss at most 5 mm; the edge clips keyed about the lip their metas name (lip_y over the hang's origin, at or over the
## hips' rest height + 0.4 m; lip_out ahead to the face), the hang's hands and head over the lip at every frame with the hands
## planted on the deck and the balls of the feet on the face; the grab swinging in from out off the face onto the hang; the
## get-ups from the hang to a stand on the deck end_in m in, never through the deck; the jump onto the fall; the edge attack's
## sweep low and in; the rolls and the duck from the stand to the stand, the rolls turning the body over low on the deck
## (its lowest surface on the deck, never through it), the duck's head down and back with the feet planted (the numbers
## printed as METRIC lines for the review).
func _fifth(lib: AnimationLibrary, names: Array[String]) -> void:
	var stand := _joints(lib.get_animation(StringName(FIRST_SET[0])), 0.0) if FIRST_SET[0] in names else {}
	var fall: Animation = lib.get_animation(&"own-bend-fall") if "own-bend-fall" in names else null
	var hips_rest := sk.get_bone_global_rest(sk.find_bone("pelvis")).origin.y
	var all := ["l_palm", "r_palm", "l_ankle", "r_ankle", "l_ball", "r_ball", "l_knee", "r_knee", "l_elbow", "r_elbow", "heada",
			"pelvis", "root", "l_shoulder", "r_shoulder"]
	for nm: String in FIFTH_SET:
		var want: Array = FIFTH_SET[nm]
		_check(nm in names, "fifth set: %s in the library" % nm)
		var twin := String(want[2])
		if twin != "":
			_check(twin in names, "fifth set: %s's twin %s in the library" % [nm, twin])
		else:
			_check(not (nm + "-l") in names, "fifth set: %s has no side (no twin)" % nm)
		for x: String in ([nm, twin] if twin != "" else [nm]):
			if not x in names:
				continue
			var a := lib.get_animation(StringName(x))
			for key in ["hand", "mask", "root", "legs_always"]:
				_check(a.has_meta(StringName(key)), "%s: has %s" % [x, key])
			_check(String(a.get_meta(&"mask", "")) == "full", "%s: mask full" % x)
			_check(bool(a.get_meta(&"legs_always", false)), "%s: legs_always (the code moves or holds the body)" % x)
			_check(int(round(a.length * 30.0)) == int(want[0]), "%s: %d frames (%d)" % [x, want[0], int(round(a.length * 30.0))])
			_check(a.has_meta(&"ik_miss_m") and float(a.get_meta(&"ik_miss_m")) <= IK_MISS + 1e-6,
					"%s: the IK's worst miss %.4f m <= %.3f" % [x, float(a.get_meta(&"ik_miss_m", 1.0)), IK_MISS])
			print("BEND_CLIPS %s ik_miss_m %.4f" % [x, float(a.get_meta(&"ik_miss_m", 1.0))])
			if bool(want[1]):
				_check(a.loop_mode == Animation.LOOP_LINEAR and a.has_meta(&"loop"), "%s: loops" % x)
				_check(not a.has_meta(&"strike_s"), "%s: a loop, no strike" % x)
				var j0 := _at(a, 0.0, all)
				var j1 := _at(a, a.length, all)
				var seam := 0.0
				for k: String in j0:
					seam = maxf(seam, (j0[k] as Vector3).distance_to(j1[k]))
				_check(seam < 0.005, "%s: the loop's seam (%.4f m)" % [x, seam])
			else:
				for key in ["hold_s", "strike_s", "back_s"]:
					_check(a.has_meta(StringName(key)) and float(a.get_meta(StringName(key))) >= 0.0
							and float(a.get_meta(StringName(key))) <= a.length + 1e-4, "%s: %s within the clip" % [x, key])
				var hold := float(a.get_meta(&"hold_s", 0.0))
				var strike := float(a.get_meta(&"strike_s", 0.0))
				var back := float(a.get_meta(&"back_s", 0.0))
				_check(hold <= strike and strike < back, "%s: the gather, the key moment, the recovery (%.2f %.2f %.2f)"
						% [x, hold, strike, back])
			if x in GROUND_DODGES and not stand.is_empty():
				for t in [0.0, a.length]:
					var j := _joints(a, t)
					var worst := 0.0
					for k: String in JOINTS:
						worst = maxf(worst, (j[k] as Vector3).distance_to(stand[k]))
					_check(worst < 0.02, "%s: on the stand at %.2f s (off by %.3f m)" % [x, t, worst])
				_place(x, a)
	var hang: Animation = lib.get_animation(&"own-bend-edge-hang") if "own-bend-edge-hang" in names else null
	if hang == null:
		return
	var lip_y := float(hang.get_meta(&"lip_y", 0.0))
	var lip_z := float(hang.get_meta(&"lip_out", 0.0))
	print("METRIC edge_lip_y_m %.3f lip_out_m %.3f hips_rest_plus_0_4_m %.3f" % [lip_y, lip_z, hips_rest + 0.4])
	_check(lip_y >= hips_rest + 0.4 - 1e-4, "edge: the lip %.2f m over the origin, at or over the hips' rest height + 0.4 (%.2f)"
			% [lip_y, hips_rest + 0.4])
	_check(lip_z > 0.2 and lip_z < 0.6, "edge: the face %.2f m ahead of the origin" % lip_z)
	for nm: String in FIFTH_SET:
		if nm.contains("-edge-") and nm in names:
			var e := lib.get_animation(StringName(nm))
			_check(is_equal_approx(float(e.get_meta(&"lip_y", -1.0)), lip_y) and is_equal_approx(float(e.get_meta(&"lip_out", -1.0)),
					lip_z), "%s: keyed about the hang's lip (lip_y %s, lip_out %s)" % [nm, e.get_meta(&"lip_y", "?"),
					e.get_meta(&"lip_out", "?")])
	# the hang: the hands and the head over the lip at every frame (and so over the hips' rest height + 0.4), the palms
	# planted on the deck past the face, the balls of the feet on the face under the lip, none of it moving
	var n := int(round(hang.length * 30.0))
	var h0 := _at(hang, 0.0, all)
	var low_hand := INF
	var low_head := INF
	var slide := 0.0
	var face := 0.0
	var feet_under := -INF
	for i in n + 1:
		var j := _at(hang, i / 30.0, all)
		low_hand = minf(low_hand, minf((j.l_palm as Vector3).y, (j.r_palm as Vector3).y) - lip_y)
		low_head = minf(low_head, (j.heada as Vector3).y - lip_y)
		# (the palms and the balls of the feet: the stone's contacts; the ankles turn about the balls as the heels re-press)
		for k: String in ["l_palm", "r_palm", "l_ball", "r_ball"]:
			slide = maxf(slide, (j[k] as Vector3).distance_to(h0[k]))
		for s in ["l_", "r_"]:
			face = maxf(face, absf((j[s + "ball"] as Vector3).z + 0.06 - lip_z))
			feet_under = maxf(feet_under, (j[s + "ball"] as Vector3).y - lip_y)
	print("METRIC edge_hang_hands_over_lip_m %.3f head_over_lip_m %.3f hands_feet_slide_m %.4f toes_off_face_m %.3f"
			% [low_hand, low_head, slide, face])
	_check(low_hand > 0.0, "edge hang: both hands over the lip at every frame (the lowest %.3f m over)" % low_hand)
	_check(low_head > 0.15, "edge hang: the head clearly over the lip at every frame (the lowest %.3f m over)" % low_head)
	_check(slide < 0.01, "edge hang: the palms and the balls of the feet hold the stone (they move %.4f m)" % slide)
	_check(face < FACE_TOUCH and feet_under < -0.5, "edge hang: the balls of the feet on the face (%.3f m off it), under the lip"
			% face)
	_check((h0.l_palm as Vector3).z > lip_z + 0.1 and (h0.r_palm as Vector3).z > lip_z + 0.1, "edge hang: the palms on the deck past the lip")
	# the grab: from out off the face (the feet trailing out behind) swung in onto the hang's first pose; the hands on the
	# deck from its strike
	if "own-bend-edge-grab" in names:
		var g := lib.get_animation(&"own-bend-edge-grab")
		var g0 := _at(g, 0.0, all)
		var g1 := _at(g, g.length, all)
		var worst := 0.0
		for k: String in all:
			worst = maxf(worst, (g1[k] as Vector3).distance_to(h0[k]))
		var out := lip_z - maxf((g0.l_ankle as Vector3).z, (g0.r_ankle as Vector3).z)
		var planted := 0.0
		var gs := float(g.get_meta(&"strike_s", 0.0))
		# (at the keys and between them: a quarter frame apart, as the game samples the bones it interpolates)
		for i in 17:
			var j := _at(g, gs + (g.length - gs) * i / 16.0, all)
			for k: String in ["l_palm", "r_palm"]:
				planted = maxf(planted, (j[k] as Vector3).distance_to(h0[k]))
		print("METRIC edge_grab_feet_out_m %.3f hands_planted_m %.4f end_off_m %.4f" % [out, planted, worst])
		_check(worst < 0.01, "edge grab: ends on the hang's first pose (off by %.4f m)" % worst)
		_check(out > 0.45, "edge grab: the legs swing in from out off the face (the ankles %.2f m out at the start)" % out)
		_check(planted <= IK_MISS, "edge grab: the hands caught on the deck from the strike (%.4f m <= %.3f)" % [planted, IK_MISS])
		_check((g0.heada as Vector3).y > (h0.heada as Vector3).y, "edge grab: caught high, the body sags into the hang")
	# the get-ups: from the hang's first pose to a stand on the deck end_in m in, no joint ever under the deck's top
	for nm: String in EDGE_GETUPS:
		if not nm in names:
			continue
		var c := lib.get_animation(StringName(nm))
		var c0 := _at(c, 0.0, all)
		var start := 0.0
		for k: String in all:
			start = maxf(start, (c0[k] as Vector3).distance_to(h0[k]))
		_check(start < 0.01, "%s: starts on the hang's first pose (off by %.4f m)" % [nm, start])
		var end_in := float(c.get_meta(&"end_in", -1.0))
		_check(end_in > 0.0, "%s: says where it stands (end_in %.2f m)" % [nm, end_in])
		if not stand.is_empty():
			var je := _joints(c, c.length)
			var off := Vector3(0.0, lip_y, lip_z + end_in)
			var worst := 0.0
			for k: String in JOINTS:
				worst = maxf(worst, (je[k] as Vector3).distance_to((stand[k] as Vector3) + off))
			_check(worst < 0.02, "%s: ends standing on the deck %.1f m in (off by %.3f m)" % [nm, end_in, worst])
		var sink := INF
		var cn := int(round(c.length * 30.0))
		for i in cn + 1:
			sink = minf(sink, _deck_gap(c, i / 30.0, lip_y, lip_z))
		print("METRIC %s_deck_gap_min_m %.3f" % [nm.trim_prefix("own-bend-"), sink])
		_check(sink > -0.03, "%s: nothing through the deck (the deepest %.3f m)" % [nm, sink])
	# the jump: from the hang onto the fall's first pose, the arms flung up overhead on the way
	if "own-bend-edge-jump" in names:
		var ej := lib.get_animation(&"own-bend-edge-jump")
		var s0 := _at(ej, 0.0, all)
		var start := 0.0
		for k: String in all:
			start = maxf(start, (s0[k] as Vector3).distance_to(h0[k]))
		_check(start < 0.01, "edge jump: starts on the hang's first pose (off by %.4f m)" % start)
		if fall != null:
			var f0 := _joints(fall, 0.0)
			var je := _joints(ej, ej.length)
			var worst := 0.0
			for k: String in JOINTS:
				worst = maxf(worst, (je[k] as Vector3).distance_to(f0[k]))
			_check(worst < 0.02, "edge jump: ends on the fall's first pose (off by %.3f m)" % worst)
		var over := -INF
		for i in 10:
			var j := _at(ej, ej.length * i / 9.0, all)
			over = maxf(over, minf((j.l_palm as Vector3).y, (j.r_palm as Vector3).y) - (j.heada as Vector3).y)
		print("METRIC edge_jump_hands_over_head_m %.3f" % over)
		_check(over > 0.15, "edge jump: the arms flung up overhead (the hands %.2f m over the head)" % over)
	# the edge attack: the right foot sweeps low along the deck and in at the strike
	if "own-bend-edge-attack" in names:
		var ea := lib.get_animation(&"own-bend-edge-attack")
		var j := _at(ea, float(ea.get_meta(&"strike_s", 0.0)), all)
		var low := (j.r_ankle as Vector3).y - lip_y
		var reach := (j.r_ankle as Vector3).z - lip_z
		print("METRIC edge_attack_sweep_ankle_over_deck_m %.3f in_m %.3f" % [low, reach])
		_check(String(ea.get_meta(&"hand", "")) == "foot_r", "edge attack: the striking limb the right foot")
		_check(low < 0.15, "edge attack: the sweep low along the deck (the ankle %.2f m over it)" % low)
		_check(reach > 0.7, "edge attack: the sweep reaching in (the ankle %.2f m in from the lip)" % reach)
	# the rolls: low, the body turned over (the forward and back rolls' head under the hips, the side roll on its side),
	# on the deck (its lowest surface within 3 cm of it while it rolls, never through it)
	for nm: String in ["own-bend-roll-f", "own-bend-roll-b", "own-bend-roll-side", "own-bend-roll-side-l"]:
		if not nm in names:
			continue
		var r := lib.get_animation(StringName(nm))
		var hold_f := int(round(float(r.get_meta(&"hold_s", 0.0)) * 30.0))
		var back_f := int(round(float(r.get_meta(&"back_s", 0.0)) * 30.0))
		var top := -INF
		var low := INF
		var high := -INF
		# (turned over: a forward or back roll's head well under its hips at some frame of the roll, a side roll's shoulders
		# one well over the other)
		var over := -INF
		for fr in range(hold_f + 1, back_f):
			var j := _at(r, fr / 30.0, all)
			top = maxf(top, (j.heada as Vector3).y)
			var s := _surface_low()
			low = minf(low, s)
			high = maxf(high, s)
			if nm.contains("-side"):
				over = maxf(over, absf((j.l_shoulder as Vector3).y - (j.r_shoulder as Vector3).y))
			else:
				over = maxf(over, (j.pelvis as Vector3).y - (j.heada as Vector3).y)
		print("METRIC %s_head_top_m %.3f surface_low_m %.3f surface_high_m %.3f turned_m %.3f" % [nm.trim_prefix("own-bend-"),
				top, low, high, over])
		_check(top < 1.0, "%s: a low roll (the head %.2f m up at most while it rolls)" % [nm, top])
		_check(low > -0.03 and high < 0.04, "%s: rolls on the deck (its lowest surface %.3f..%.3f m)" % [nm, low, high])
		_check(over > 0.15, "%s: turned over (%.2f m)" % [nm, over])
	if "own-bend-roll-side" in names:
		var rs := lib.get_animation(&"own-bend-roll-side")
		var j := _at(rs, 5.0 / 30.0, all)
		_check((j.r_shoulder as Vector3).y < (j.l_shoulder as Vector3).y, "roll side: rolls to his right (the right shoulder down first)")
	# the duck: the head down 0.4 m or more and back behind the hips at the lowest, the feet planted through it (pass 3: the
	# balls of the feet; the heels lift as the knees drive out over the toes)
	if "own-bend-duck" in names:
		var d := lib.get_animation(&"own-bend-duck")
		var d0 := _at(d, 0.0, all)
		var js := _at(d, float(d.get_meta(&"strike_s", 0.0)), all)
		var drop := (d0.heada as Vector3).y - (js.heada as Vector3).y
		var lean := (js.pelvis as Vector3).z - (js.heada as Vector3).z
		var feet := 0.0
		for i in 15:
			var j := _at(d, d.length * i / 14.0, all)
			for k: String in ["l_ball", "r_ball"]:
				feet = maxf(feet, (j[k] as Vector3).distance_to(d0[k]))
		print("METRIC duck_head_drop_m %.3f lean_back_m %.3f feet_m %.4f" % [drop, lean, feet])
		_check(drop > 0.4, "duck: the head down %.2f m at the lowest" % drop)
		_check(lean > 0.02, "duck: swayed back (the head %.2f m behind the hips)" % lean)
		_check(feet < 0.01, "duck: the feet planted (%.4f m)" % feet)


## The fifth set's pass 2 (the critic's notes, 2026-10-06): the hang a climber's Z pressed into the stone (the hips held out
## off the face, the knees folded near a right angle) with a sway that reads (the hips 8 cm side to side); the grab's catch
## sagging under the lip; the climb's shin never floating over the void at the deck's height while the knee is down, the hips
## shifted over the left foot, a held load and a rise carried a touch past; the jump's hands on the deck through the push
## (the clip taking back the code's carry) and the legs straight off the face at the release; the roll in's and the rolls'
## heads clear of the deck while they roll (the shoulder and the back take it); the sweep carried across past the planted
## foot and slowing at its end; the side roll's legs landing one after the other; the duck down 0.5 m and back 0.3 m with the
## head still sinking through the hold (the numbers printed as METRIC lines for the review).
func _fifth_pass2(lib: AnimationLibrary, names: Array[String]) -> void:
	var all := ["l_palm", "r_palm", "l_ankle", "r_ankle", "l_ball", "r_ball", "l_knee", "r_knee", "l_upper_leg", "r_upper_leg",
			"heada", "pelvis"]
	if not "own-bend-edge-hang" in names:
		return
	var hang := lib.get_animation(&"own-bend-edge-hang")
	var lip_y := float(hang.get_meta(&"lip_y", 0.0))
	var lip_z := float(hang.get_meta(&"lip_out", 0.0))
	var h0 := _at(hang, 0.0, all)
	# the hang: the hips out off the face, the knees folded, the sway wide enough to read
	var out_min := INF
	var knee_lo := INF
	var knee_hi := -INF
	var sway_lo := INF
	var sway_hi := -INF
	for i in 31:
		var j := _at(hang, i / 30.0, all)
		out_min = minf(out_min, lip_z - (j.pelvis as Vector3).z)
		# (pass 3: the right knee folded, the left leg run long down the face; the folded one is checked here, the long one
		# in _fifth_pass3)
		var kb := _bend(j, "r_upper_leg", "r_knee", "r_ankle")
		knee_lo = minf(knee_lo, kb)
		knee_hi = maxf(knee_hi, kb)
		sway_lo = minf(sway_lo, (j.pelvis as Vector3).x)
		sway_hi = maxf(sway_hi, (j.pelvis as Vector3).x)
	print("METRIC edge_hang_hips_off_face_m %.3f knee_deg %.0f-%.0f hip_sway_m %.3f" % [out_min, knee_lo, knee_hi,
			sway_hi - sway_lo])
	_check(out_min >= HANG_HIPS_OUT, "edge hang: the hips held %.2f m or more off the face (%.3f)" % [HANG_HIPS_OUT, out_min])
	_check(knee_lo >= 70.0 and knee_hi <= 125.0, "edge hang: the right knee folded near a right angle (%.0f-%.0f deg)"
			% [knee_lo, knee_hi])
	_check(sway_hi - sway_lo >= 0.08, "edge hang: the hips sway side to side (%.3f m)" % (sway_hi - sway_lo))
	# the grab: the catch sags the body under the hang's height
	if "own-bend-edge-grab" in names:
		var g := lib.get_animation(&"own-bend-edge-grab")
		var low := INF
		for i in 7:
			low = minf(low, (_at(g, i / 30.0, all).pelvis as Vector3).y)
		print("METRIC edge_grab_sag_m %.3f" % ((h0.pelvis as Vector3).y - low))
		_check((h0.pelvis as Vector3).y - low >= 0.08, "edge grab: the catch sags the hips %.2f m under the hang's"
				% ((h0.pelvis as Vector3).y - low))
	# the climb: while the knee is down (strike to back) the right ankle past the face hangs under the deck's top, the hips
	# over the left foot, a held load, the rise carried a touch past
	if "own-bend-edge-climb" in names:
		var c := lib.get_animation(&"own-bend-edge-climb")
		var cs := int(round(float(c.get_meta(&"strike_s")) * 30.0))
		var cb := int(round(float(c.get_meta(&"back_s")) * 30.0))
		var float_worst := -INF
		for fr in range(cs, cb + 1):
			var j := _at(c, fr / 30.0, all)
			if (j.r_ankle as Vector3).z < lip_z - 0.02:
				float_worst = maxf(float_worst, (j.r_ankle as Vector3).y - lip_y)
		var j9 := _at(c, cb / 30.0, all)
		var j10 := _at(c, (cb + 1) / 30.0, all)
		var load := (j10.pelvis as Vector3).y - (j9.pelvis as Vector3).y
		var n := int(round(c.length * 30.0))
		var over := (_at(c, (n - 1) / 30.0, all).pelvis as Vector3).y - (_at(c, c.length, all).pelvis as Vector3).y
		print("METRIC edge_climb_shin_over_void_m %.3f hips_left_m %.3f load_rise_m %.3f rise_past_m %.3f"
				% [float_worst, (j9.pelvis as Vector3).x, load, over])
		_check(float_worst < -0.04, "edge climb: the shin never floats at the deck's height over the void (the ankle %.3f m)"
				% float_worst)
		_check((j9.pelvis as Vector3).x >= 0.03, "edge climb: the hips shifted over the left foot (%.3f m)" % (j9.pelvis as Vector3).x)
		_check(load < 0.02, "edge climb: a held load before the drive (the hips rise %.3f m)" % load)
		_check(over > 0.006, "edge climb: the rise carried a touch past the stand (%.3f m)" % over)
	# the jump: the hands on the deck through the push in the world (the clip's root plus the code's carry), the legs
	# straight off the face at the release
	if "own-bend-edge-jump" in names:
		var ej := lib.get_animation(&"own-bend-edge-jump")
		var es := int(round(float(ej.get_meta(&"strike_s")) * 30.0))
		var drift := 0.0
		for fr in es + 2:
			var t := fr / 30.0
			var j := _at(ej, t, all)
			var lift := Vector3.UP * (EDGE_JUMP_VY * t - 0.5 * EDGE_JUMP_G * t * t)
			for k: String in ["l_palm", "r_palm"]:
				drift = maxf(drift, ((j[k] as Vector3) + lift).distance_to(h0[k]))
		var jr := _at(ej, (es + 1) / 30.0, all)
		var knee := maxf(_bend(jr, "l_upper_leg", "l_knee", "l_ankle"), _bend(jr, "r_upper_leg", "r_knee", "r_ankle"))
		var th := float(ej.get_meta(&"hold_s"))
		var jc := _at(ej, th, all)
		var coil := (h0.pelvis as Vector3).y - ((jc.pelvis as Vector3).y + EDGE_JUMP_VY * th - 0.5 * EDGE_JUMP_G * th * th)
		print("METRIC edge_jump_hands_on_deck_m %.4f release_knee_deg %.0f coil_m %.3f" % [drift, knee, coil])
		_check(drift < 0.01, "edge jump: the hands on the deck through the push (%.4f m in the world)" % drift)
		_check(knee < 45.0, "edge jump: the legs driven near straight off the face at the release (%.0f deg)" % knee)
		_check(coil >= 0.06, "edge jump: the coil sinks the hips %.2f m" % coil)
	# the heads clear of the deck while the body rolls on it
	for nm: String in ["own-bend-edge-roll", "own-bend-roll-f", "own-bend-roll-b", "own-bend-roll-side", "own-bend-roll-side-l"]:
		if not nm in names:
			continue
		var r := lib.get_animation(StringName(nm))
		var floor_y := lip_y if nm.contains("edge") else 0.0
		var f0 := int(round(float(r.get_meta(&"hold_s")) * 30.0)) + 1
		var f1 := int(round(float(r.get_meta(&"back_s")) * 30.0)) - (3 if nm.contains("edge") else 1)
		var head := INF
		for fr in range(f0, f1 + 1):
			_at(r, fr / 30.0, all)
			head = minf(head, _head_low() - floor_y)
		print("METRIC %s_head_clear_m %.3f" % [nm.trim_prefix("own-bend-"), head])
		_check(head >= ROLL_HEAD_CLEAR, "%s: the head clear of the deck while it rolls (%.3f m)" % [nm, head])
	# the sweep: carried across past the planted left foot, slowing at its end
	if "own-bend-edge-attack" in names:
		var ea := lib.get_animation(&"own-bend-edge-attack")
		var across := -INF
		var p: Array[Vector3] = []
		for fr in range(9, 13):
			var j := _at(ea, fr / 30.0, all)
			across = maxf(across, (j.r_ankle as Vector3).x - (j.l_ankle as Vector3).x)
			p.append(j.r_ankle as Vector3)
		var fast := p[0].distance_to(p[1])
		var slow := p[2].distance_to(p[3])
		print("METRIC edge_attack_across_m %.3f step_f9_m %.3f step_f11_m %.3f" % [across, fast, slow])
		_check(across >= 0.2, "edge attack: the sweep carried across past the left foot (%.2f m)" % across)
		_check(slow < fast, "edge attack: the sweep slows at its end (%.3f < %.3f m a frame)" % [slow, fast])
	# the side roll: the leading leg lands first
	for pair: Array in [["own-bend-roll-side", "l_ball", "r_ball"], ["own-bend-roll-side-l", "r_ball", "l_ball"]]:
		if String(pair[0]) in names:
			var j := _at(lib.get_animation(StringName(String(pair[0]))), 12.0 / 30.0, all)
			print("METRIC %s_landing_m first %.3f second %.3f" % [String(pair[0]).trim_prefix("own-bend-"),
					(j[pair[1]] as Vector3).y, (j[pair[2]] as Vector3).y])
			_check((j[pair[1]] as Vector3).y < 0.03 and (j[pair[2]] as Vector3).y > 0.06,
					"%s: the leading leg lands first (f12)" % pair[0])
	# the duck: deep and back, the head still sinking through the hold
	if "own-bend-duck" in names:
		var d := lib.get_animation(&"own-bend-duck")
		var hs := _at(d, float(d.get_meta(&"strike_s")), all)
		var hb := _at(d, (float(d.get_meta(&"back_s")) - 1.0 / 30.0), all)
		var d0 := _at(d, 0.0, all)
		var drop := (d0.heada as Vector3).y - (hs.heada as Vector3).y
		var lean := (hs.pelvis as Vector3).z - (hs.heada as Vector3).z
		var sink := (hs.heada as Vector3).y - (hb.heada as Vector3).y
		print("METRIC duck_pass2_drop_m %.3f lean_m %.3f hold_sink_m %.3f" % [drop, lean, sink])
		_check(drop >= 0.5 and lean >= 0.3, "duck: down %.2f m and back %.2f m (0.5, 0.3)" % [drop, lean])
		_check(sink >= 0.01, "duck: a moving hold, the head still sinking (%.3f m)" % sink)


## The fifth set's pass 3 (the critic's notes on pass 2, 2026-10-06): the hang a climber's line (the right knee folded, the
## left leg run long down the face) whose loop moves enough to read at 15 m (the hips 12 cm side to side, the head turned
## 20 degrees or more to look along the deck at the check); the grab's reaching hands spread wide (0.8 m) over the head
## (0.1 m); the climb's knees not splayed as he presses up (0.6 m apart at most); the roll in's apex over the lip with the face still forward and its ball closed
## (the heels at the seat); the jump's coil 10 cm deep and its arms locked straight at the strike; the sweep at the leg's
## reach through its middle (f8-f10: 0.7 m from the planted foot) and through 140 degrees; the forward roll a ball (the heels at the seat, the knees
## together) after a drop eased over three frames; every roll's hat clear of the deck (HAT_CLEAR); the side roll leaning
## over the right foot first, its travel named, right shoulder down; the duck's mass over the feet (the head at most 0.25 m
## behind the heels), a moving hold and the shoulders turned at the bottom (the numbers printed as METRIC lines).
func _fifth_pass3(lib: AnimationLibrary, names: Array[String]) -> void:
	var all := ["l_palm", "r_palm", "l_ankle", "r_ankle", "l_ball", "r_ball", "l_knee", "r_knee", "l_upper_leg", "r_upper_leg",
			"l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "heada", "pelvis", "spinec"]
	if not "own-bend-edge-hang" in names:
		return
	var hang := lib.get_animation(&"own-bend-edge-hang")
	var lip_y := float(hang.get_meta(&"lip_y", 0.0))
	# the hang: one leg folded, one long; a loop that moves
	var long_hi := -INF
	var fold_lo := INF
	var sway_lo := INF
	var sway_hi := -INF
	var head_move := 0.0
	var h0 := _at(hang, 0.0, all)
	var look_lo := INF
	var look_hi := -INF
	for i in 31:
		var j := _at(hang, i / 30.0, all)
		long_hi = maxf(long_hi, _bend(j, "l_upper_leg", "l_knee", "l_ankle"))
		fold_lo = minf(fold_lo, _bend(j, "r_upper_leg", "r_knee", "r_ankle"))
		sway_lo = minf(sway_lo, (j.pelvis as Vector3).x)
		sway_hi = maxf(sway_hi, (j.pelvis as Vector3).x)
		head_move = maxf(head_move, (j.heada as Vector3).distance_to(h0.heada))
		var hb := sk.get_bone_global_pose(sk.find_bone("headb")).basis.get_rotation_quaternion() \
				* sk.get_bone_global_rest(sk.find_bone("headb")).basis.get_rotation_quaternion().inverse()
		var fwd := hb * Vector3.BACK
		var yaw := rad_to_deg(atan2(fwd.x, fwd.z))
		look_lo = minf(look_lo, yaw)
		look_hi = maxf(look_hi, yaw)
	print("METRIC edge_hang_p3 long_knee_deg %.0f folded_knee_deg %.0f hip_sway_m %.3f head_move_m %.3f look_deg %.0f..%.0f"
			% [long_hi, fold_lo, sway_hi - sway_lo, head_move, look_lo, look_hi])
	_check(long_hi <= 60.0 and fold_lo - long_hi >= 25.0, "edge hang: the left leg long (%.0f deg), the right folded (%.0f)"
			% [long_hi, fold_lo])
	_check(sway_hi - sway_lo >= 0.12, "edge hang: the hips sway 12 cm (%.3f m)" % (sway_hi - sway_lo))
	_check(look_hi - look_lo >= 20.0, "edge hang: the head turns to look along the deck (%.0f deg)" % (look_hi - look_lo))
	# the grab: the reaching hands spread wide, over the head
	if "own-bend-edge-grab" in names:
		var g0 := _at(lib.get_animation(&"own-bend-edge-grab"), 0.0, all)
		var spread := (g0.l_palm as Vector3).x - (g0.r_palm as Vector3).x
		var over := minf((g0.l_palm as Vector3).y, (g0.r_palm as Vector3).y) - (g0.heada as Vector3).y
		print("METRIC edge_grab_reach_spread_m %.3f hands_over_head_m %.3f" % [spread, over])
		_check(spread >= 0.8 and over >= 0.1, "edge grab: the reaching hands wide (%.2f m) and over the head (%.2f m)" % [spread, over])
	# the climb: the knees not splayed through the press (f3)
	if "own-bend-edge-climb" in names:
		var j := _at(lib.get_animation(&"own-bend-edge-climb"), 3.0 / 30.0, all)
		var knees := (j.l_knee as Vector3).x - (j.r_knee as Vector3).x
		var hips := (j.l_upper_leg as Vector3).x - (j.r_upper_leg as Vector3).x
		print("METRIC edge_climb_f3_knees_apart_m %.3f hips_apart_m %.3f" % [knees, hips])
		_check(knees <= 0.6, "edge climb: the knees not splayed in the press (%.2f m apart)" % knees)
	# the roll in: the apex over the lip (hips high, the face forward) and the ball closed through the turn
	if "own-bend-edge-roll" in names:
		var r := lib.get_animation(&"own-bend-edge-roll")
		var apex := -INF
		for fr in [4, 5]:
			var j := _at(r, fr / 30.0, all)
			apex = maxf(apex, (j.pelvis as Vector3).y - lip_y)
		var j5 := _at(r, 5.0 / 30.0, all)
		var face_fwd := (j5.heada as Vector3).y - (j5.spinec as Vector3).y
		var ball := 0.0
		for fr in range(7, 12):
			var j := _at(r, fr / 30.0, all)
			for s in ["l_", "r_"]:
				ball = maxf(ball, (j[s + "ankle"] as Vector3).distance_to(j.pelvis))
		print("METRIC edge_roll_apex_hips_over_lip_m %.3f f5_head_over_chest_m %.3f ball_heel_seat_m %.3f" % [apex, face_fwd, ball])
		_check(apex >= 0.35, "edge roll: the apex over the lip (the hips %.2f m over it)" % apex)
		_check(face_fwd > 0.0, "edge roll: the face still forward at the apex (the head %.2f m over the chest)" % face_fwd)
		_check(ball <= 0.4, "edge roll: a closed ball through the turn (the heels %.2f m from the seat)" % ball)
	# the jump: the coil deep, the arms locked at the strike
	if "own-bend-edge-jump" in names:
		var ej := lib.get_animation(&"own-bend-edge-jump")
		var t1 := 1.0 / 30.0
		var j1 := _at(ej, t1, all)
		var coil := (h0.pelvis as Vector3).y - ((j1.pelvis as Vector3).y + EDGE_JUMP_VY * t1 - 0.5 * EDGE_JUMP_G * t1 * t1)
		var js := _at(ej, float(ej.get_meta(&"strike_s")), all)
		var elbow := maxf(_bend(js, "l_shoulder", "l_elbow", "l_palm"), _bend(js, "r_shoulder", "r_elbow", "r_palm"))
		print("METRIC edge_jump_p3_coil_m %.3f strike_elbow_deg %.0f" % [coil, elbow])
		_check(coil >= 0.1, "edge jump: the coil reads (the hips %.2f m down)" % coil)
		_check(elbow <= 30.0, "edge jump: the arms locked straight at the strike (%.0f deg)" % elbow)
	# the sweep: at the leg's reach from the planted left foot, through 140 degrees
	if "own-bend-edge-attack" in names:
		var ea := lib.get_animation(&"own-bend-edge-attack")
		var rmin := INF
		var a0 := 0.0
		var a1 := 0.0
		for fr in range(7, 13):
			var j := _at(ea, fr / 30.0, all)
			var d := (j.r_ankle as Vector3) - (j.l_ankle as Vector3)
			if fr >= 8 and fr <= 10:
				rmin = minf(rmin, Vector2(d.x, d.z).length())
			var ang := rad_to_deg(atan2(d.x, d.z))
			if fr == 7:
				a0 = ang
			a1 = ang
		print("METRIC edge_attack_p3_sweep_radius_m %.3f arc_deg %.0f" % [rmin, absf(a1 - a0)])
		_check(rmin >= 0.7, "edge attack: the sweep at the leg's reach (%.2f m from the planted foot)" % rmin)
		_check(absf(a1 - a0) >= 140.0, "edge attack: the sweep through 140 degrees (%.0f)" % absf(a1 - a0))
	# the forward roll: the drop eased over f1-f3 and a closed ball at f5 and f7
	if "own-bend-roll-f" in names:
		var rf := lib.get_animation(&"own-bend-roll-f")
		var p: Array[float] = []
		for fr in 4:
			p.append((_at(rf, fr / 30.0, all).pelvis as Vector3).y)
		var steps := [p[0] - p[1], p[1] - p[2], p[2] - p[3]]
		var ball := 0.0
		var knees := 0.0
		for fr in [5, 7]:
			var j := _at(rf, fr / 30.0, all)
			for s in ["l_", "r_"]:
				ball = maxf(ball, (j[s + "ankle"] as Vector3).distance_to(j.pelvis))
			knees = maxf(knees, (j.l_knee as Vector3).distance_to(j.r_knee))
		print("METRIC roll_f_p3_drop_steps_m %.3f %.3f %.3f ball_heel_seat_m %.3f knees_apart_m %.3f" % [steps[0], steps[1],
				steps[2], ball, knees])
		_check(steps[0] < steps[1] and maxf(steps[1], steps[2]) <= 0.25, "roll f: the drop eased in (%.2f, %.2f, %.2f m)"
				% steps)
		_check(ball <= 0.4 and knees <= 0.45, "roll f: a closed ball (the heels %.2f m from the seat, the knees %.2f m apart)"
				% [ball, knees])
	# the hats clear of the deck while the rolls turn over
	for nm: String in HAT_CLEAR:
		if not nm in names:
			continue
		var r := lib.get_animation(StringName(nm))
		var floor_y := lip_y if nm.contains("edge") else 0.0
		var f0 := int(round(float(r.get_meta(&"hold_s")) * 30.0)) + 1
		var f1 := int(round(float(r.get_meta(&"back_s")) * 30.0)) - (3 if nm.contains("edge") else 1)
		var hat := INF
		for fr in range(f0, f1 + 1):
			_at(r, fr / 30.0, all)
			hat = minf(hat, _hat_low() - floor_y)
		print("METRIC %s_hat_clear_m %.3f" % [nm.trim_prefix("own-bend-"), hat])
		_check(hat >= float(HAT_CLEAR[nm]), "%s: the hat %.2f m or more off the deck while it rolls (%.3f)" % [nm, HAT_CLEAR[nm], hat])
	# the side roll: the lean over the right foot first, its travel named, the right shoulder down as it tips
	for pair: Array in [["own-bend-roll-side", "right", -1.0], ["own-bend-roll-side-l", "left", 1.0]]:
		var nm := String(pair[0])
		if not nm in names:
			continue
		var rs := lib.get_animation(StringName(nm))
		var j2 := _at(rs, 2.0 / 30.0, all)
		var lean := (j2.pelvis as Vector3).x * float(pair[2])
		var down := INF
		for fr in range(4, 8):
			var j := _at(rs, fr / 30.0, all)
			var d := ((j.l_shoulder as Vector3).y - (j.r_shoulder as Vector3).y) * -float(pair[2])
			down = minf(down, d)
		var travel := str(rs.get_meta(&"travel", ""))
		print("METRIC %s_p3_lean_m %.3f lead_shoulder_down_m %.3f travel %s" % [nm.trim_prefix("own-bend-"), lean, down, travel])
		_check(travel == String(pair[1]), "%s: rolls to his %s (meta travel %s)" % [nm, pair[1], travel])
		_check(lean >= 0.15, "%s: the weight shifted over the leading foot first (%.2f m)" % [nm, lean])
		_check(down >= 0.0, "%s: the leading shoulder down through f4-f7 (%.3f m)" % [nm, down])
	# the duck: the mass over the feet, a moving hold, the shoulders turned at the bottom
	if "own-bend-duck" in names:
		var d := lib.get_animation(&"own-bend-duck")
		var j0 := _at(d, 0.0, all)
		var heel_z := minf((j0.l_ankle as Vector3).z, (j0.r_ankle as Vector3).z)
		var j4 := _at(d, 4.0 / 30.0, all)
		var j8 := _at(d, 8.0 / 30.0, all)
		var j7 := _at(d, 7.0 / 30.0, all)
		var behind := heel_z - (j4.heada as Vector3).z
		var hips := (j4.pelvis as Vector3).z - heel_z
		var sink := (j4.pelvis as Vector3).y - (j8.pelvis as Vector3).y
		var sh := (j7.l_shoulder as Vector3) - (j7.r_shoulder as Vector3)
		var turn := absf(rad_to_deg(atan2(sh.z, sh.x)))
		print("METRIC duck_p3_head_behind_heels_m %.3f hips_ahead_of_heels_m %.3f hold_sink_m %.3f shoulders_turn_deg %.0f"
				% [behind, hips, sink, turn])
		_check(behind <= 0.25, "duck: the head at most 0.25 m behind the heels (%.2f m)" % behind)
		_check(hips >= 0.1, "duck: the hips carried forward over the feet (%.2f m ahead of the heels)" % hips)
		_check(sink >= 0.02, "duck: a moving hold, the hips still sinking f4-f8 (%.3f m)" % sink)
		_check(turn >= 8.0, "duck: the shoulders turned at the bottom, a slip (%.0f deg)" % turn)


## The hat's lowest point (m) now (the skeleton as last posed): HAT_REST carried by headb from its rest.
func _hat_low() -> float:
	var b := sk.find_bone("headb")
	if b < 0:
		return INF
	var rest := sk.get_bone_global_rest(b)
	var pose := sk.get_bone_global_pose(b)
	var low := INF
	for v: Vector3 in HAT_REST:
		low = minf(low, (pose * (rest.affine_inverse() * v)).y)
	return low


## How near either palm comes to the hat (m) now (the skeleton as last posed): HAT_REST carried by headb from its rest.
func _palm_hat() -> float:
	var b := sk.find_bone("headb")
	if b < 0:
		return INF
	var rest := sk.get_bone_global_rest(b)
	var pose := sk.get_bone_global_pose(b)
	var near := INF
	for v: Vector3 in HAT_REST:
		var p := pose * (rest.affine_inverse() * v)
		for s: String in ["r_palm", "l_palm"]:
			near = minf(near, p.distance_to(sk.get_bone_global_pose(sk.find_bone(s)).origin))
	return near


## A hand's index finger's curl at t (deg: its knuckles' bends summed; a fist well over 60, an open hand under 30).
func _grip(a: Animation, t: float, side: String) -> float:
	var j := _at(a, t, [side + "_palm", side + "_indexa", side + "_indexb", side + "_indexc"])
	return _bend(j, side + "_palm", side + "_indexa", side + "_indexb") + _bend(j, side + "_indexa", side + "_indexb", side + "_indexc")


## The head's lowest point (m) now (the skeleton as last posed): its sphere (SURF) about the skull's middle.
func _head_low() -> float:
	var p := sk.get_bone_global_pose(sk.find_bone("heada")).origin
	if sk.find_bone("headb") >= 0:
		var hb := sk.get_bone_global_pose(sk.find_bone("headb")).origin
		var nk := sk.get_bone_global_pose(sk.find_bone("neck")).origin
		p = p + (hb - p) * 0.5 + (hb - nk).normalized() * 0.03
	return p.y - float(SURF["heada"])


## The body's lowest surface (m) now (the skeleton as last posed): SURF round each joint, the head's about its middle.
func _surface_low() -> float:
	var low := INF
	for k: String in SURF:
		var b := sk.find_bone(k)
		if b < 0:
			continue
		var p := sk.get_bone_global_pose(b).origin
		if k == "heada" and sk.find_bone("headb") >= 0:
			var hb := sk.get_bone_global_pose(sk.find_bone("headb")).origin
			var nk := sk.get_bone_global_pose(sk.find_bone("neck")).origin
			p = p + (hb - p) * 0.5 + (hb - nk).normalized() * 0.03
		low = minf(low, p.y - float(SURF[k]))
	return low


## The lowest surface (m over the floor) of only the bones named (SURF's radii; the head as _surface_low takes it).
func _surface_low_of(bones: Array) -> float:
	var low := INF
	for k: String in bones:
		var b := sk.find_bone(k)
		if b < 0:
			continue
		var p := sk.get_bone_global_pose(b).origin
		if k == "heada" and sk.find_bone("headb") >= 0:
			var hb := sk.get_bone_global_pose(sk.find_bone("headb")).origin
			var nk := sk.get_bone_global_pose(sk.find_bone("neck")).origin
			p = p + (hb - p) * 0.5 + (hb - nk).normalized() * 0.03
		low = minf(low, p.y - float(SURF[k]))
	return low


## How far the body's surface is over the deck's top where it is over the deck (past the lip): the least (m; < 0 through it).
func _deck_gap(a: Animation, t: float, lip_y: float, lip_z: float) -> float:
	_joints(a, t)
	var gap := INF
	for k: String in SURF:
		var b := sk.find_bone(k)
		if b < 0:
			continue
		var p := sk.get_bone_global_pose(b).origin
		if p.z > lip_z + 0.03:
			gap = minf(gap, p.y - float(SURF[k]) - lip_y)
	return gap if gap < INF else 1.0


## Each of the fourth set reads as its state (the numbers printed as METRIC lines for the review).
func _fourth_reads(lib: AnimationLibrary, names: Array[String]) -> void:
	var bones := ["l_palm", "r_palm", "l_shoulder", "r_shoulder", "l_ankle", "r_ankle", "pelvis", "heada"]
	if "own-bend-helpless" in names and "own-bend-fall" in names:
		var h := lib.get_animation(&"own-bend-helpless")
		var f := lib.get_animation(&"own-bend-fall")
		var low := INF
		var hy := 0.0
		var fy := 0.0
		for i in 24:
			var jh := _at(h, h.length * i / 24.0, bones)
			var jf := _at(f, f.length * i / 24.0, bones)
			for s in ["l_", "r_"]:
				low = minf(low, (jh[s + "palm"] as Vector3).y - (jh[s + "shoulder"] as Vector3).y)
				hy += (jh[s + "palm"] as Vector3).y / 48.0
				fy += (jf[s + "palm"] as Vector3).y / 48.0
		print("METRIC helpless_hands_over_shoulders_min_m %.3f" % low)
		print("METRIC helpless_vs_fall_hands_m %.3f" % (hy - fy))
		_check(low > HELPLESS_OVER, "helpless: both hands %.2f m or more above the shoulders at every frame (the lowest %.3f m over)"
				% [HELPLESS_OVER, low])
		_check(hy - fy > 0.15, "helpless: the hands %.2f m over the plain fall's on average (reads apart)" % (hy - fy))
	if "own-bend-tumble" in names:
		var tu := lib.get_animation(&"own-bend-tumble")
		var under := -INF
		for i in 24:
			var j := _at(tu, tu.length * i / 24.0, bones)
			under = maxf(under, (j.pelvis as Vector3).y - (j.heada as Vector3).y)
		print("METRIC tumble_head_under_hips_m %.3f" % under)
		_check(under > 0.3, "tumble: the whole body turns over (the head %.2f m under the hips at its lowest)" % under)
	if "own-bend-knock-slide" in names:
		var ks := lib.get_animation(&"own-bend-knock-slide")
		var worst := -INF
		for i in 24:
			var j := _at(ks, ks.length * i / 24.0, bones)
			worst = maxf(worst, (j.pelvis as Vector3).y - (j.heada as Vector3).y)
		_check(worst < 0.0, "the knocked slide stays upright (the tumble reads apart from it)")
	if "own-bend-fall-fast" in names:
		var ff := lib.get_animation(&"own-bend-fall-fast")
		var apart := 0.0
		var long := INF
		for i in 16:
			var j := _at(ff, ff.length * i / 16.0, bones)
			apart = maxf(apart, (j.l_ankle as Vector3).distance_to(j.r_ankle))
			long = minf(long, (j.pelvis as Vector3).y - maxf((j.l_ankle as Vector3).y, (j.r_ankle as Vector3).y))
		print("METRIC fall_fast_ankles_apart_m %.3f under_hips_m %.3f" % [apart, long])
		_check(apart < 0.2, "fast fall: the legs together (the ankles %.2f m apart at most)" % apart)
		_check(long > FALL_FAST_LONG, "fast fall: long, the ankles %.2f m under the hips" % long)
	if "own-bend-fall" in names:
		var f0 := _at(lib.get_animation(&"own-bend-fall"), 0.0, bones)
		for nm: String in ["own-bend-jump-double", "own-bend-air-dodge"]:
			if not nm in names:
				continue
			var a := lib.get_animation(StringName(nm))
			var up := 0.0
			for i in 16:
				var j := _at(a, a.length * i / 16.0, bones)
				up = maxf(up, minf((j.l_ankle as Vector3).y - (f0.l_ankle as Vector3).y, (j.r_ankle as Vector3).y - (f0.r_ankle as Vector3).y))
			print("METRIC %s_knees_up_m %.3f" % [nm.trim_prefix("own-bend-"), up])
			_check(up > 0.2, "%s: both knees drawn up (the ankles %.2f m over the fall's)" % [nm, up])
	if "own-bend-land-light" in names and "own-bend-land-heavy" in names:
		var depth := {}
		var held := {}
		for nm: String in ["own-bend-land-light", "own-bend-land-heavy"]:
			var a := lib.get_animation(StringName(nm))
			var y0 := (_at(a, a.length, bones).pelvis as Vector3).y
			var lowest := INF
			var n_low := 0
			var ys: Array[float] = []
			for i in 31:
				ys.append((_at(a, a.length * i / 30.0, bones).pelvis as Vector3).y)
				lowest = minf(lowest, ys[-1])
			for y in ys:
				if y < lowest + 0.03:
					n_low += 1
			depth[nm] = y0 - lowest
			held[nm] = a.length * n_low / 31.0
			print("METRIC %s_crouch_m %.3f held_s %.2f" % [nm.trim_prefix("own-bend-"), depth[nm], held[nm]])
		_check(float(depth["own-bend-land-heavy"]) - float(depth["own-bend-land-light"]) > 0.15,
				"heavy landing: the crouch %.2f m deeper than the light one's" % (float(depth["own-bend-land-heavy"]) - float(depth["own-bend-land-light"])))
		_check(float(held["own-bend-land-heavy"]) > float(held["own-bend-land-light"]), "heavy landing: held at the bottom longer")
	if "own-bend-flinch" in names:
		var fl := lib.get_animation(&"own-bend-flinch")
		var h0 := _at(fl, 0.0, bones).heada as Vector3
		var moved := 0.0
		for i in 9:
			moved = maxf(moved, (_at(fl, fl.length * i / 8.0, bones).heada as Vector3).distance_to(h0))
		print("METRIC flinch_head_moves_m %.3f" % moved)
		_check(fl.length >= 0.2 - 1e-4 and fl.length <= 0.3 + 1e-4, "flinch: about 0.25 s (%.2f)" % fl.length)
		_check(moved > 0.03, "flinch: the head jolted %.3f m" % moved)
	if "own-bend-air-legs" in names:
		var al := lib.get_animation(&"own-bend-air-legs")
		var bad := []
		for i in al.get_track_count():
			var bn := String(al.track_get_path(i).get_concatenated_subnames())
			if al.track_get_type(i) != Animation.TYPE_ROTATION_3D or not (bn.begins_with("l_") or bn.begins_with("r_")) \
					or not (bn.ends_with("upper_leg") or bn.ends_with("knee") or bn.ends_with("ankle") or bn.ends_with("heel")
					or bn.ends_with("ball")):
				bad.append(bn)
		_check(bad.is_empty() and al.get_track_count() > 0, "air legs: only the legs' bones, no root %s" % str(bad))


## The fourth set's second pass (the critic's notes, 2026-10-06): the tumble tucks while it turns fastest and passes upright
## as a ball; the fall's arms open wide and its loop moving enough to read from the stands; the fast fall's arms swept back
## behind the hips; the double jump's heels tucked under the seat and its hands on the knees; the flinch's hands up before
## the face; the air legs moving (the numbers printed as METRIC lines for the review).
func _fourth_pass2(lib: AnimationLibrary, names: Array[String]) -> void:
	var bones := ["l_palm", "r_palm", "l_ankle", "r_ankle", "l_knee", "r_knee", "pelvis", "heada"]
	if "own-bend-tumble" in names:
		var tu := lib.get_animation(&"own-bend-tumble")
		var n := int(round(tu.length * 30.0))
		var js: Array[Dictionary] = []
		for i in n + 1:
			js.append(_at(tu, i / 30.0, bones))
		var rows: Array = []                               # [the turn's speed (deg a frame), the compactness (m)]
		var upright_low := INF
		for i in n:
			var v0 := (js[i].heada as Vector3) - (js[i].pelvis as Vector3)
			var v1 := (js[i + 1].heada as Vector3) - (js[i + 1].pelvis as Vector3)
			var d := rad_to_deg(absf(angle_difference(atan2(v0.z, v0.y), atan2(v1.z, v1.y))))
			var c := 0.0
			for k: String in ["l_palm", "r_palm", "l_ankle", "r_ankle"]:
				c += (js[i][k] as Vector3).distance_to(js[i].pelvis) / 4.0
			rows.append([d, c])
			if v0.y > 0.8 * v0.length():
				upright_low = minf(upright_low, minf((js[i].l_ankle as Vector3).y, (js[i].r_ankle as Vector3).y)
						- (js[i].pelvis as Vector3).y)
		rows.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) > float(q[0]))
		var third := n / 3
		var fast := 0.0
		var slow := 0.0
		for i in third:
			fast += float(rows[i][1]) / third
			slow += float(rows[n - 1 - i][1]) / third
		print("METRIC tumble_compact_fast_m %.3f slow_m %.3f turn_fastest_deg %.1f slowest_deg %.1f upright_ankles_m %.3f"
				% [fast, slow, float(rows[0][0]), float(rows[n - 1][0]), upright_low])
		_check(fast < slow - 0.12, "tumble: tucked while the turn is fastest (%.2f m against %.2f open)" % [fast, slow])
		_check(float(rows[0][0]) > 2.5 * float(rows[n - 1][0]), "tumble: the turn quickens in the tuck (%.0f against %.0f deg a frame)"
				% [float(rows[0][0]), float(rows[n - 1][0])])
		_check(upright_low > -0.5, "tumble: upright only as a ball, the knees up (the ankles %.2f m from the hips)" % upright_low)
	if "own-bend-fall" in names:
		var f := lib.get_animation(&"own-bend-fall")
		var narrow := INF
		var zr := Vector2(INF, -INF)
		var yr := Vector2(INF, -INF)
		for i in 20:
			var j := _at(f, f.length * i / 20.0, bones)
			narrow = minf(narrow, minf(absf((j.l_palm as Vector3).x), absf((j.r_palm as Vector3).x)))
			zr = Vector2(minf(zr.x, (j.r_ankle as Vector3).z), maxf(zr.y, (j.r_ankle as Vector3).z))
			yr = Vector2(minf(yr.x, (j.r_palm as Vector3).y), maxf(yr.y, (j.r_palm as Vector3).y))
		print("METRIC fall_palms_out_min_m %.3f ankle_swing_m %.3f palm_rise_m %.3f" % [narrow, zr.y - zr.x, yr.y - yr.x])
		_check(narrow > 0.45, "fall: the arms open wide (the palms %.2f m out at the least)" % narrow)
		_check(zr.y - zr.x > 0.18, "fall: the legs' bicycle reads (%.2f m)" % (zr.y - zr.x))
		_check(yr.y - yr.x > 0.08, "fall: the arms answer it (%.2f m)" % (yr.y - yr.x))
	if "own-bend-fall-fast" in names:
		var ff := lib.get_animation(&"own-bend-fall-fast")
		var back := -INF
		for i in 16:
			var j := _at(ff, ff.length * i / 16.0, bones)
			back = maxf(back, maxf((j.l_palm as Vector3).z, (j.r_palm as Vector3).z) - (j.pelvis as Vector3).z)
		print("METRIC fall_fast_palms_behind_hips_m %.3f" % -back)
		_check(back < -0.2, "fast fall: the arms swept back (the palms %.2f m behind the hips)" % -back)
	if "own-bend-jump-double" in names:
		var jd := lib.get_animation(&"own-bend-jump-double")
		var j := _at(jd, 7.0 / 30.0, bones)
		var heel := maxf((j.l_ankle as Vector3).z, (j.r_ankle as Vector3).z) - (j.pelvis as Vector3).z
		var hands := maxf((j.l_palm as Vector3).distance_to(j.l_knee), (j.r_palm as Vector3).distance_to(j.r_knee))
		print("METRIC jump_double_heels_ahead_m %.3f hands_to_knees_m %.3f" % [heel, hands])
		_check(heel < 0.15, "double jump: the heels under the seat in the tuck (%.2f m ahead of the hips)" % heel)
		_check(hands < 0.2, "double jump: the hands in on the knees (%.2f m)" % hands)
	if "own-bend-flinch" in names:
		var fl := lib.get_animation(&"own-bend-flinch")
		var j := _at(fl, float(fl.get_meta(&"hold_s", 0.0)), bones)
		var up := minf((j.l_palm as Vector3).y, (j.r_palm as Vector3).y) - (j.heada as Vector3).y
		print("METRIC flinch_hands_to_head_m %.3f" % up)
		# (pass 3: the cringe is a forearm guard, the fists at the chin, so the bar is the chin's height, not the face's)
		_check(up > -0.16, "flinch: the hands up at the chin at the cringe (%.2f m from the head)" % up)
	if "own-bend-air-legs" in names:
		var al := lib.get_animation(&"own-bend-air-legs")
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for i in 24:
			var j := _at(al, al.length * i / 24.0, bones)
			var y := Vector2((j.l_ankle as Vector3).y, (j.r_ankle as Vector3).y)
			lo = Vector2(minf(lo.x, y.x), minf(lo.y, y.y))
			hi = Vector2(maxf(hi.x, y.x), maxf(hi.y, y.y))
		print("METRIC air_legs_ankle_swing_m l %.3f r %.3f" % [hi.x - lo.x, hi.y - lo.y])
		_check(minf(hi.x - lo.x, hi.y - lo.y) > 0.05, "air legs: both legs move (%.2f m)" % minf(hi.x - lo.x, hi.y - lo.y))
	_fourth_pass3(lib, names)


## The fourth set's third pass (the critic's second notes, 2026-10-06; the numbers printed as METRIC lines for the review).
func _fourth_pass3(lib: AnimationLibrary, names: Array[String]) -> void:
	var bones := ["l_palm", "r_palm", "l_shoulder", "r_shoulder", "l_upper_leg", "r_upper_leg", "l_knee", "r_knee", "l_ankle",
			"r_ankle", "l_elbow", "r_elbow", "l_wrist", "r_wrist", "pelvis", "neck", "heada"]
	if "own-bend-helpless" in names:
		# never the upright "hooray": the trunk (the pelvis to the neck) 20 degrees or more off the vertical at every frame;
		# the hands never level; the elbows bent (a limp arm, not a reach)
		var h := lib.get_animation(&"own-bend-helpless")
		var lean := INF
		var uneven := 0.0
		var elbow := Vector2(INF, -INF)
		for i in 24:
			var j := _at(h, h.length * i / 24.0, bones)
			var trunk := (j.neck as Vector3) - (j.pelvis as Vector3)
			lean = minf(lean, rad_to_deg(trunk.angle_to(Vector3.UP)))
			uneven += absf((j.l_palm as Vector3).y - (j.r_palm as Vector3).y) / 24.0
			for s in ["l_", "r_"]:
				var e := _bend(j, s + "shoulder", s + "elbow", s + "wrist")
				elbow = Vector2(minf(elbow.x, e), maxf(elbow.y, e))
		print("METRIC helpless_lean_min_deg %.1f hands_uneven_m %.3f elbow_deg %.0f-%.0f" % [lean, uneven, elbow.x, elbow.y])
		_check(lean >= 20.0, "helpless: lying back 20 degrees or more at every frame (%.1f)" % lean)
		_check(uneven > 0.06, "helpless: the hands never level (%.3f m apart on average)" % uneven)
		_check(elbow.x > 15.0, "helpless: the elbows bent at every frame (%.0f degrees at the least)" % elbow.x)
	if "own-bend-tumble" in names:
		var tu := lib.get_animation(&"own-bend-tumble")
		var near := INF
		for t in [0.0, tu.length]:
			var j := _at(tu, t, bones)
			for s in ["l_", "r_"]:
				near = minf(near, (j[s + "palm"] as Vector3).distance_to(j.heada))
		print("METRIC tumble_seam_hand_to_head_m %.3f" % near)
		_check(near > 0.25, "tumble: the arms flung clear at the seam (a hand %.2f m from the head)" % near)
	if "own-bend-jump-double" in names:
		var jd := lib.get_animation(&"own-bend-jump-double")
		var j := _at(jd, float(jd.get_meta(&"strike_s", 0.0)), bones)
		var long := (j.pelvis as Vector3).y - maxf((j.l_ankle as Vector3).y, (j.r_ankle as Vector3).y)
		var back := (j.pelvis as Vector3).z - maxf((j.l_palm as Vector3).z, (j.r_palm as Vector3).z)
		print("METRIC jump_double_push_long_m %.3f palms_behind_m %.3f strike_f %d" % [long, back,
				int(round(float(jd.get_meta(&"strike_s", 0.0)) * 30.0))])
		_check(long > 0.65, "double jump: the push long (the ankles %.2f m under the hips)" % long)
		_check(back > 0.25, "double jump: the arms swept back in the push (the palms %.2f m behind the hips)" % back)
		_check(float(jd.get_meta(&"hold_s", 0.0)) >= 2.0 / 30.0 - 1e-4, "double jump: a gather of two frames or more")
	if "own-bend-fall" in names:
		var f := lib.get_animation(&"own-bend-fall")
		var apart := 0.0
		for i in 20:
			var j := _at(f, f.length * i / 20.0, bones)
			apart = maxf(apart, absf((j.l_palm as Vector3).y - (j.r_palm as Vector3).y))
		print("METRIC fall_hands_unmirrored_m %.3f" % apart)
		_check(apart > 0.03, "fall: the arms not mirror-perfect (the palms up to %.3f m apart in height)" % apart)
	if "own-bend-fall-fast" in names:
		var ff := lib.get_animation(&"own-bend-fall-fast")
		var pitch := INF
		var out := INF
		var knees := Vector2(-INF, 0.0)
		for i in 16:
			var j := _at(ff, ff.length * i / 16.0, bones)
			pitch = minf(pitch, (j.heada as Vector3).z - (j.pelvis as Vector3).z)
			out = minf(out, minf(absf((j.l_palm as Vector3).x), absf((j.r_palm as Vector3).x)))
			var kl := _bend(j, "l_upper_leg", "l_knee", "l_ankle")
			var kr := _bend(j, "r_upper_leg", "r_knee", "r_ankle")
			knees = Vector2(maxf(knees.x, maxf(kl, kr)), maxf(knees.y, absf(kl - kr)))
		print("METRIC fall_fast_head_ahead_m %.3f palms_out_m %.3f knee_max_deg %.0f knee_diff_deg %.0f" % [pitch, out,
				knees.x, knees.y])
		_check(pitch > 0.05, "fast fall: pitched into the dive (the head %.2f m ahead of the hips)" % pitch)
		_check(out > 0.3, "fast fall: the arms swept back and out (the palms %.2f m out)" % out)
		_check(knees.x < 35.0 and knees.y < 15.0, "fast fall: the legs long and alike (the knees %.0f degrees at most, %.0f apart)"
				% [knees.x, knees.y])
	if "own-bend-flinch" in names:
		var fl := lib.get_animation(&"own-bend-flinch")
		var j := _at(fl, float(fl.get_meta(&"hold_s", 0.0)), bones)
		var ahead := minf((j.l_palm as Vector3).z, (j.r_palm as Vector3).z) - (j.heada as Vector3).z
		var mid := maxf(absf((j.l_palm as Vector3).x), absf((j.r_palm as Vector3).x))
		print("METRIC flinch_guard_ahead_m %.3f guard_half_width_m %.3f" % [ahead, mid])
		_check(ahead > 0.15, "flinch: the guard clear before the face (%.2f m ahead of the head)" % ahead)
		_check(mid < 0.15, "flinch: the fists together before the chin (%.2f m from the middle)" % mid)
	if "own-bend-air-legs" in names:
		var al := lib.get_animation(&"own-bend-air-legs")
		var gap := INF
		for i in 24:
			var j := _at(al, al.length * i / 24.0, bones)
			gap = minf(gap, (j.r_ankle as Vector3).z - (j.l_ankle as Vector3).z)
		print("METRIC air_legs_heel_behind_m %.3f" % gap)
		_check(gap > 0.15, "air legs: two shapes, the left heel drawn back (%.2f m behind the right)" % gap)
	if "own-bend-land-heavy" in names:
		var lh := lib.get_animation(&"own-bend-land-heavy")
		var n := int(round(lh.length * 30.0))
		var step := 0.0
		var prev := INF
		for fr in range(int(round(float(lh.get_meta(&"back_s", 0.0)) * 30.0)), n + 1):
			var y := (_at(lh, fr / 30.0, bones).pelvis as Vector3).y
			if prev < INF:
				step = maxf(step, y - prev)
			prev = y
		print("METRIC land_heavy_rise_step_max_m %.3f" % step)
		_check(step < 0.06, "heavy landing: the push up eased (%.3f m in one frame at most)" % step)
		_check(absf(float(lh.get_meta(&"back_s", 0.0)) - 8.0 / 30.0) < 1e-4, "heavy landing: the punish window's end kept (back_s 8 f)")


func _sixth_has(nm: String) -> bool:
	return SIXTH_SET.has(nm) or (nm.ends_with("-l") and SIXTH_SET.has(nm.trim_suffix("-l")))


## Every bone's skeleton-space place (its head) with the clip's keyed bones set at t.
func _all_bones(a: Animation, t: float) -> Array[Vector3]:
	_joints(a, t)
	var out: Array[Vector3] = []
	for b in sk.get_bone_count():
		out.append(sk.get_bone_global_pose(b).origin)
	return out


## The worst distance (m) between two poses' JOINTS (the palms and the ankles).
func _off(j: Dictionary, k: Dictionary) -> float:
	var worst := 0.0
	for n: String in JOINTS:
		worst = maxf(worst, (j[n] as Vector3).distance_to(k[n]))
	return worst


## The sixth set (round 3's P2 Rises and recoveries, 2026-10-06): each there with its metas, length and twin; the IK's worst
## miss at most 5 mm; the Rises from the fall's first pose (the three one-shots back onto it, the air Rise's glide a loop from
## loop_from_s to its end), each reading as its element's own recovery; the scramble from under the lip onto the hang's first
## pose exactly (1 cm, every bone); the breaks to the stand, the tech's palm and knee on the deck at the slap, the wall break's
## palms and soles on the wall; the lie a seamless loop lying on the deck (its surface within 2.5 cm of it); the getups from
## the lie's first pose to the stand, never through the deck; the bounce from the deck up and back onto the lie's first pose;
## the spiked knock a plunging line with the hands over the head (the numbers printed as METRIC lines for the review).
func _sixth(lib: AnimationLibrary, names: Array[String]) -> void:
	var stand := _joints(lib.get_animation(StringName(FIRST_SET[0])), 0.0) if FIRST_SET[0] in names else {}
	var fall: Animation = lib.get_animation(&"own-bend-fall") if "own-bend-fall" in names else null
	var air0 := _joints(fall, 0.0) if fall != null else {}
	var lie: Animation = lib.get_animation(&"own-bend-lie") if "own-bend-lie" in names else null
	var lie0 := _joints(lie, 0.0) if lie != null else {}
	for nm: String in SIXTH_SET:
		var want: Array = SIXTH_SET[nm]
		_check(nm in names, "sixth set: %s in the library" % nm)
		var twin := String(want[2])
		if twin != "":
			_check(twin in names, "sixth set: %s's twin %s in the library" % [nm, twin])
		else:
			_check(not (nm + "-l") in names, "sixth set: %s has no side (no twin)" % nm)
		for x: String in ([nm, twin] if twin != "" else [nm]):
			if not x in names:
				continue
			var a := lib.get_animation(StringName(x))
			for key in ["hand", "mask", "root"]:
				_check(a.has_meta(StringName(key)), "%s: has %s" % [x, key])
			_check(String(a.get_meta(&"mask", "")) == "full", "%s: mask full" % x)
			if nm in ON_DECK:
				_check(bool(a.get_meta(&"legs_always", false)), "%s: legs_always (on the deck)" % x)
			_check(int(round(a.length * 30.0)) == int(want[0]), "%s: %d frames (%d)" % [x, want[0], int(round(a.length * 30.0))])
			_check(a.has_meta(&"ik_miss_m") and float(a.get_meta(&"ik_miss_m")) <= IK_MISS + 1e-6,
					"%s: the IK's worst miss %.4f m <= %.3f" % [x, float(a.get_meta(&"ik_miss_m", 1.0)), IK_MISS])
			print("BEND_CLIPS %s ik_miss_m %.4f" % [x, float(a.get_meta(&"ik_miss_m", 1.0))])
			if bool(want[1]):
				_check(a.loop_mode == Animation.LOOP_LINEAR and a.has_meta(&"loop"), "%s: loops" % x)
				_check(not a.has_meta(&"strike_s"), "%s: a loop, no strike" % x)
				var b0 := _all_bones(a, 0.0)
				var b1 := _all_bones(a, a.length)
				var seam := 0.0
				for i in b0.size():
					seam = maxf(seam, b0[i].distance_to(b1[i]))
				_check(seam < 0.005, "%s: the loop's seam (every bone, %.4f m)" % [x, seam])
				continue
			for key in ["hold_s", "strike_s", "back_s"]:
				_check(a.has_meta(StringName(key)) and float(a.get_meta(StringName(key))) >= 0.0
						and float(a.get_meta(StringName(key))) <= a.length + 1e-4, "%s: %s within the clip" % [x, key])
			var hold := float(a.get_meta(&"hold_s", 0.0))
			var strike := float(a.get_meta(&"strike_s", 0.0))
			var back := float(a.get_meta(&"back_s", 0.0))
			if nm in REACTIONS6:
				_check(strike < hold and hold < back, "%s: the hit / contact, the hold, the recovery (%.2f %.2f %.2f)"
						% [x, strike, hold, back])
			else:
				_check(hold <= strike and strike < back, "%s: the gather, the key moment, the recovery (%.2f %.2f %.2f)"
						% [x, hold, strike, back])
			if nm in FROM_AIR6 and not air0.is_empty():
				var d0 := _off(_joints(a, 0.0), air0)
				_check(d0 < 0.02, "%s: starts on the fall's first pose (off by %.3f m)" % [x, d0])
			if nm in TO_AIR6 and not air0.is_empty():
				var d1 := _off(_joints(a, a.length), air0)
				_check(d1 < 0.02, "%s: ends on the fall's first pose (off by %.3f m)" % [x, d1])
			if nm in TO_STAND6 and not stand.is_empty():
				var d2 := _off(_joints(a, a.length), stand)
				_check(d2 < 0.02, "%s: ends on the stand (off by %.3f m)" % [x, d2])
			if nm in FROM_LIE and not lie0.is_empty():
				var d3 := _off(_joints(a, 0.0), lie0)
				_check(d3 < 0.01, "%s: starts on the lie's first pose (off by %.4f m)" % [x, d3])
			if nm in ON_DECK:
				var low := INF
				for i in int(round(a.length * 30.0)) + 1:
					_joints(a, i / 30.0)
					low = minf(low, _surface_low())
				print("METRIC %s deck_low_m %.3f" % [x, low])
				_check(low > -0.03, "%s: never through the deck (its lowest surface %.3f m)" % [x, low])
	_sixth_rises(lib, names)
	_sixth_recoveries(lib, names, lie)
	_sixth_pass3(lib, names, lie)


func _seventh_has(nm: String) -> bool:
	return SEVENTH_SET.has(nm) or (nm.ends_with("-l") and SEVENTH_SET.has(nm.trim_suffix("-l")))


## The seventh set (round 3's P2 Pop, Slams, held guards and teeter, 2026-10-07): each there with its metas, length, mask and
## twin; the IK's worst miss at most 5 mm; the loops seamless; then each clip's own read (_seventh_slams, _seventh_pop,
## _seventh_guards, _seventh_teeter; the numbers printed as METRIC lines for the review).
func _seventh(lib: AnimationLibrary, names: Array[String]) -> void:
	for nm: String in SEVENTH_SET:
		var want: Array = SEVENTH_SET[nm]
		_check(nm in names, "seventh set: %s in the library" % nm)
		var twin := String(want[2])
		if twin != "":
			_check(twin in names, "seventh set: %s's twin %s in the library" % [nm, twin])
		else:
			_check(not (nm + "-l") in names, "seventh set: %s has no side (no twin)" % nm)
		for x: String in ([nm, twin] if twin != "" else [nm]):
			if not x in names:
				continue
			var a := lib.get_animation(StringName(x))
			for key in ["hand", "mask", "root"]:
				_check(a.has_meta(StringName(key)), "%s: has %s" % [x, key])
			_check(String(a.get_meta(&"mask", "")) == String(want[3]), "%s: mask %s" % [x, want[3]])
			_check(int(round(a.length * 30.0)) == int(want[0]), "%s: %d frames (%d)" % [x, want[0], int(round(a.length * 30.0))])
			_check(a.has_meta(&"ik_miss_m") and float(a.get_meta(&"ik_miss_m")) <= IK_MISS + 1e-6,
					"%s: the IK's worst miss %.4f m <= %.3f" % [x, float(a.get_meta(&"ik_miss_m", 1.0)), IK_MISS])
			print("BEND_CLIPS %s ik_miss_m %.4f" % [x, float(a.get_meta(&"ik_miss_m", 1.0))])
			if bool(want[1]):
				_check(a.loop_mode == Animation.LOOP_LINEAR and a.has_meta(&"loop"), "%s: loops" % x)
				_check(not a.has_meta(&"strike_s"), "%s: a loop, no strike" % x)
				var b0 := _all_bones(a, 0.0)
				var b1 := _all_bones(a, a.length)
				var seam := 0.0
				for i in b0.size():
					seam = maxf(seam, b0[i].distance_to(b1[i]))
				_check(seam < 0.005, "%s: the loop's seam (every bone, %.4f m)" % [x, seam])
				continue
			_check(a.loop_mode == Animation.LOOP_NONE, "%s: a one-shot" % x)
			for key in ["hold_s", "strike_s"]:
				_check(a.has_meta(StringName(key)) and float(a.get_meta(StringName(key))) >= 0.0
						and float(a.get_meta(StringName(key))) <= a.length + 1e-4, "%s: %s within the clip" % [x, key])
	_seventh_slams(lib, names)
	_seventh_pop(lib, names)
	_seventh_guards(lib, names)
	_seventh_teeter(lib, names)
	_seventh_pass2(lib, names)
	_seventh_pass3(lib, names)


## The Slams: the strike early (strike_s <= 0.2 s, at most 0.1 s after the held wind-up), the recovery after it, from and back
## onto the fall's first pose; each its own read at the hold (the wind-up the foe sees through the lock) and at the strike, and
## the four wind-ups apart at a glance.
func _seventh_slams(lib: AnimationLibrary, names: Array[String]) -> void:
	var fall: Animation = lib.get_animation(&"own-bend-fall") if "own-bend-fall" in names else null
	var air0 := _joints(fall, 0.0) if fall != null else {}
	var holds := {}
	for x: String in SLAMS:
		if not x in names:
			continue
		var a := lib.get_animation(StringName(x))
		var hold := float(a.get_meta(&"hold_s", -1.0))
		var strike := float(a.get_meta(&"strike_s", -1.0))
		var back := float(a.get_meta(&"back_s", -1.0))
		print("METRIC %s strike_s %.3f hold_s %.3f back_s %.3f" % [x, strike, hold, back])
		_check(strike > 0.0 and strike <= SLAM_STRIKE_S + 1e-4, "%s: strikes early (strike_s %.3f <= %.2f)" % [x, strike, SLAM_STRIKE_S])
		_check(hold > 0.0 and hold < strike and strike - hold <= SLAM_RELEASE_S + 1e-4,
				"%s: the held wind-up, the strike %.3f s after it (<= %.2f)" % [x, strike - hold, SLAM_RELEASE_S])
		_check(back > strike, "%s: the recovery after the strike (%.2f > %.2f)" % [x, back, strike])
		if not air0.is_empty():
			var d0 := _off(_joints(a, 0.0), air0)
			var d1 := _off(_joints(a, a.length), air0)
			_check(d0 < 0.02 and d1 < 0.02, "%s: from and back onto the fall's first pose (%.3f, %.3f m)" % [x, d0, d1])
		var h := _at(a, hold, ["heada", "pelvis", "r_palm", "l_palm", "r_ankle", "l_ankle", "r_shoulder", "l_shoulder"])
		var k := _at(a, strike, ["heada", "pelvis", "r_palm", "l_palm", "r_ankle", "l_ankle", "r_shoulder", "l_shoulder"])
		holds[x] = h
		var head_y: float = (h.heada as Vector3).y
		match x:
			"own-bend-earth-hammer":
				# (the fists clasped high over the head, then driven down below the hips between the knees)
				var over := minf((h.r_palm as Vector3).y, (h.l_palm as Vector3).y) - head_y
				var gap := (h.r_palm as Vector3).distance_to(h.l_palm)
				var under := (k.pelvis as Vector3).y - maxf((k.r_palm as Vector3).y, (k.l_palm as Vector3).y)
				print("METRIC %s fists_over_head_m %.3f fists_apart_m %.3f fists_under_hips_m %.3f" % [x, over, gap, under])
				_check(over > 0.25, "%s: the fists high over the head at the hold (%.3f m)" % [x, over])
				_check(gap < 0.12, "%s: the fists clasped together (%.3f m apart)" % [x, gap])
				_check(under > 0.0, "%s: the fists driven below the hips at the strike (%.3f m)" % [x, under])
			"own-bend-water-downpour":
				# (a tall wide V, then the palms pressed down ahead at the hips with the body risen)
				var over := minf((h.r_palm as Vector3).y, (h.l_palm as Vector3).y) - head_y
				var wide := (h.l_palm as Vector3).x - (h.r_palm as Vector3).x
				var low := maxf((k.r_palm as Vector3).y, (k.l_palm as Vector3).y) - (k.pelvis as Vector3).y
				var ahead := minf((k.r_palm as Vector3).z, (k.l_palm as Vector3).z)
				var rise := (_bone(a, 8 / 30.0, "pelvis")).y - (h.pelvis as Vector3).y
				print("METRIC %s palms_over_head_m %.3f v_width_m %.3f press_over_hips_m %.3f press_ahead_m %.3f rise_m %.3f"
						% [x, over, wide, low, ahead, rise])
				_check(over > 0.15 and wide > 0.7, "%s: a tall wide V at the hold (%.3f over the head, %.3f wide)" % [x, over, wide])
				_check(low < 0.15 and ahead > 0.25, "%s: the palms pressed down ahead at the hips (%.3f over, %.3f ahead)"
						% [x, low, ahead])
				_check(rise > 0.06, "%s: the body rises on the press (%.3f m)" % [x, rise])
			"own-bend-fire-axe-kick", "own-bend-fire-axe-kick-l":
				# (the kicking ankle over the head, then chopped down ahead below the hips)
				var kick := "r_ankle" if x == "own-bend-fire-axe-kick" else "l_ankle"
				var up := (h[kick] as Vector3).y - head_y
				var down := (k.pelvis as Vector3).y - (k[kick] as Vector3).y
				var fwd := (k[kick] as Vector3).z
				print("METRIC %s ankle_over_head_m %.3f ankle_under_hips_m %.3f ankle_ahead_m %.3f" % [x, up, down, fwd])
				_check(up > 0.0, "%s: the leg up over the head at the hold (the ankle %.3f m over it)" % [x, up])
				_check(down > 0.25 and fwd > 0.4, "%s: chopped down ahead at the strike (%.3f under the hips, %.3f ahead)"
						% [x, down, fwd])
			"own-bend-air-down-gust":
				# (tucked small, then long: the palms flared down beside the hips, the legs long, the body lifted)
				var tuck := minf((h.r_ankle as Vector3).y, (h.l_ankle as Vector3).y)
				var flare := (k.l_palm as Vector3).x - (k.r_palm as Vector3).x
				var palms := maxf((k.r_palm as Vector3).y, (k.l_palm as Vector3).y) - (k.pelvis as Vector3).y
				var long := (k.pelvis as Vector3).y - maxf((k.r_ankle as Vector3).y, (k.l_ankle as Vector3).y)
				var lift := _bone(a, 8 / 30.0, "pelvis").y - (_bone(fall, 0.0, "pelvis").y if fall != null else 0.0)
				print("METRIC %s tuck_ankles_m %.3f flare_m %.3f palms_over_hips_m %.3f legs_long_m %.3f lift_m %.3f"
						% [x, tuck, flare, palms, long, lift])
				_check(tuck > 0.5, "%s: the knees tucked up at the hold (the ankles %.3f m up)" % [x, tuck])
				_check(flare > 0.7 and palms < 0.2, "%s: the palms flared down beside the hips (%.3f wide, %.3f over the hips)"
						% [x, flare, palms])
				# (pass 3: the legs let down out of the tuck but kept half tucked under him, the body riding the gust compact)
				_check(long > 0.45, "%s: the legs let down under him at the strike (%.3f m)" % [x, long])

				_check(lift > 0.08, "%s: the body lifted on the gust (%.3f m)" % [x, lift])
	# the four Slams' wind-ups apart at a glance (the palms and the ankles 0.25 m and more apart, pairwise)
	var ks := ["own-bend-earth-hammer", "own-bend-water-downpour", "own-bend-fire-axe-kick", "own-bend-air-down-gust"]
	for i in ks.size():
		for j in range(i + 1, ks.size()):
			if not (holds.has(ks[i]) and holds.has(ks[j])):
				continue
			var d := 0.0
			for b: String in ["r_palm", "l_palm", "r_ankle", "l_ankle"]:
				d = maxf(d, (holds[ks[i]][b] as Vector3).distance_to(holds[ks[j]][b]))
			_check(d > 0.25, "%s and %s: the wind-ups apart (%.3f m)" % [ks[i], ks[j], d])


## The Pop's rising hand: from the stand, the striking palm over the head at the strike, and from back_s to the end on the Pop
## stone's surface (BendR3.pop_stone's place), the fingers closing round it; the twin the mirror (checked with every twin).
func _seventh_pop(lib: AnimationLibrary, names: Array[String]) -> void:
	var stand := _joints(lib.get_animation(StringName(FIRST_SET[0])), 0.0) if FIRST_SET[0] in names else {}
	for x: String in ["own-bend-jab-rise", "own-bend-jab-rise-l"]:
		if not x in names:
			continue
		var a := lib.get_animation(StringName(x))
		var s := "r" if x == "own-bend-jab-rise" else "l"
		_check(String(a.get_meta(&"hand", "")) == s, "%s: the %s hand strikes" % [x, s])
		if not stand.is_empty():
			var d0 := _off(_joints(a, 0.0), stand)
			_check(d0 < 0.02, "%s: starts on the stand (%.3f m)" % [x, d0])
		var strike := float(a.get_meta(&"strike_s", 0.0))
		var top := _bone(a, strike, s + "_palm").y - _bone(a, strike, "heada").y
		print("METRIC %s palm_over_head_m %.3f" % [x, top])
		_check(top > 0.15, "%s: the rising hand over the head at the strike (%.3f m)" % [x, top])
		# (the hand on the stone is the right for both: the code holds the stone on his right, BendR3.pop_stone)
		var sh := String(a.get_meta(&"stone_hand", ""))
		_check(sh == "r", "%s: the stone in the right hand (meta stone_hand %s)" % [x, sh])
		if sh != "r":
			sh = "r"
		var stone := POP_STONE
		var worst := 0.0
		var t := float(a.get_meta(&"back_s", a.length))
		while t <= a.length + 1e-4:
			worst = maxf(worst, absf(_bone(a, t, sh + "_palm").distance_to(stone) - POP_STONE_R))
			t += 1.0 / 30.0
		print("METRIC %s stone_touch_m %.3f" % [x, worst])
		_check(worst < POP_TOUCH, "%s: the hand on the Pop stone from back_s to the end (off its surface by %.3f m)" % [x, worst])
		var g0 := _grip(a, float(a.get_meta(&"back_s", 0.0)), sh)
		var g1 := _grip(a, a.length, sh)
		print("METRIC %s grip_back_deg %.1f grip_end_deg %.1f" % [x, g0, g1])
		_check(g1 > g0 + 10.0, "%s: the fingers close round the stone (%.0f -> %.0f deg)" % [x, g0, g1])


## The held guards: the feet planted through the loop (each ball of the foot within 1 cm), each its guard's read at a glance, the four apart.
func _seventh_guards(lib: AnimationLibrary, names: Array[String]) -> void:
	var firsts := {}
	for x: String in GUARDS:
		if not x in names:
			continue
		var a := lib.get_animation(StringName(x))
		var n := int(round(a.length * 30.0))
		var a0 := _at(a, 0.0, ["r_ball", "l_ball"])
		var slide := 0.0
		var hmin := INF
		var hmax := -INF
		for i in n + 1:
			var j := _at(a, i / 30.0, ["r_ball", "l_ball", "r_palm"])
			slide = maxf(slide, maxf((j.r_ball as Vector3).distance_to(a0.r_ball), (j.l_ball as Vector3).distance_to(a0.l_ball)))
			hmin = minf(hmin, (j.r_palm as Vector3).y)
			hmax = maxf(hmax, (j.r_palm as Vector3).y)
		print("METRIC %s ball_slide_m %.4f palm_travel_m %.3f" % [x, slide, hmax - hmin])
		_check(slide < 0.01, "%s: the feet planted (the balls of the feet move %.4f m; the heels may lift)" % [x, slide])
		_check(hmax - hmin > 0.01, "%s: alive (the right palm moves %.3f m)" % [x, hmax - hmin])
		var j0 := _at(a, 0.0, ["heada", "pelvis", "r_palm", "l_palm", "r_shoulder"])
		firsts[x] = _joints(a, 0.0)
		var r: Vector3 = j0.r_palm
		var l: Vector3 = j0.l_palm
		match x:
			"own-bend-guard-hold-earth":
				print("METRIC %s rock_gap_m %.3f hips_y %.3f" % [x, r.y - l.y, (j0.pelvis as Vector3).y])
				_check(r.y - l.y > 0.25 and r.z > 0.2 and l.z > 0.2, "%s: the rock between the palms, the right on top (%.3f m apart)"
						% [x, r.y - l.y])
				_check((j0.pelvis as Vector3).y < 0.75, "%s: sunk low in the horse (the hips %.3f m)" % [x, (j0.pelvis as Vector3).y])
			"own-bend-guard-hold-water":
				var lvl := absf(r.y - l.y)
				print("METRIC %s palms_level_m %.3f palms_ahead_m %.3f" % [x, lvl, minf(r.z, l.z)])
				_check(lvl < 0.08 and minf(r.z, l.z) > 0.45, "%s: both palms level ahead (%.3f apart in height, %.3f ahead)"
						% [x, lvl, minf(r.z, l.z)])
			"own-bend-guard-hold-fire":
				print("METRIC %s knife_ahead_m %.3f fist_ahead_m %.3f" % [x, r.z, l.z])
				_check(r.z > 0.5 and l.z < 0.2, "%s: the knife hand ahead (%.3f), the fist at the ribs (%.3f)" % [x, r.z, l.z])
			"own-bend-guard-hold-air":
				var half := _at(a, a.length * 0.5, ["r_palm", "l_palm"])
				var d0 := r.y - l.y
				var d1 := (half.r_palm as Vector3).y - (half.l_palm as Vector3).y
				print("METRIC %s high_low_m %.3f at_half %.3f" % [x, d0, d1])
				_check(d0 > 0.25 and d1 < -0.25, "%s: one palm high and one low, changing over (%.3f, %.3f m)" % [x, d0, d1])
	for i in GUARDS.size():
		for j in range(i + 1, GUARDS.size()):
			if not (firsts.has(GUARDS[i]) and firsts.has(GUARDS[j])):
				continue
			var d := 0.0
			for b: String in ["r_palm", "l_palm"]:
				d = maxf(d, (firsts[GUARDS[i]][b] as Vector3).distance_to(firsts[GUARDS[j]][b]))
			_check(d > 0.15, "%s and %s: apart at a glance (a palm %.3f m off)" % [GUARDS[i], GUARDS[j], d])


## The teeter: from the stand, the balls of the feet planted on the deck (they never slide: 1 cm), the arms windmilling (each palm
## over the head at some frame and down by the hips at another), held leaning out over the toes at its end (legs_always).
func _seventh_teeter(lib: AnimationLibrary, names: Array[String]) -> void:
	if not "own-bend-teeter" in names:
		return
	var a := lib.get_animation(&"own-bend-teeter")
	_check(bool(a.get_meta(&"legs_always", false)), "own-bend-teeter: legs_always")
	_check(is_equal_approx(float(a.get_meta(&"hold_s", 0.0)), a.length), "own-bend-teeter: held at its end (hold_s the length)")
	_check(float(a.get_meta(&"strike_s", 1.0)) <= 0.1 + 1e-4, "own-bend-teeter: the lurch at once, eased in (strike_s %.3f <= 0.1)"
			% float(a.get_meta(&"strike_s", 1.0)))
	var stand := _joints(lib.get_animation(StringName(FIRST_SET[0])), 0.0) if FIRST_SET[0] in names else {}
	if not stand.is_empty():
		var d0 := _off(_joints(a, 0.0), stand)
		_check(d0 < 0.02, "own-bend-teeter: starts on the stand (%.3f m)" % d0)
	var b0 := _at(a, 0.0, ["r_ball", "l_ball"])
	var slide := 0.0
	var over := {"r": -INF, "l": -INF}
	var under := {"r": INF, "l": INF}
	for i in int(round(a.length * 30.0)) + 1:
		var j := _at(a, i / 30.0, ["r_ball", "l_ball", "r_palm", "l_palm", "heada", "pelvis"])
		slide = maxf(slide, maxf((j.r_ball as Vector3).distance_to(b0.r_ball), (j.l_ball as Vector3).distance_to(b0.l_ball)))
		for s: String in ["r", "l"]:
			over[s] = maxf(over[s], (j[s + "_palm"] as Vector3).y - (j.heada as Vector3).y)
			under[s] = minf(under[s], (j[s + "_palm"] as Vector3).y - (j.pelvis as Vector3).y)
	var e := _at(a, a.length, ["heada", "r_ball", "l_ball"])
	var lean := (e.heada as Vector3).z - maxf((e.r_ball as Vector3).z, (e.l_ball as Vector3).z)
	print("METRIC own-bend-teeter ball_slide_m %.4f palm_over_head r %.3f l %.3f palm_under_hips r %.3f l %.3f lean_m %.3f"
			% [slide, over.r, over.l, under.r, under.l, lean])
	_check(slide < 0.01, "own-bend-teeter: the balls of the feet planted (%.4f m)" % slide)
	_check(over.r > 0.1 and over.l > 0.1, "own-bend-teeter: each arm windmills over the head (%.3f, %.3f m)" % [over.r, over.l])
	_check(under.r < 0.3 and under.l < 0.3, "own-bend-teeter: and down by the hips (%.3f, %.3f m over them)" % [under.r, under.l])
	_check(lean > 0.1, "own-bend-teeter: leaning out over the toes at the end (the head %.3f m past the balls)" % lean)

## The sixth set's pass-3 reads (the critic's pass-2 notes) not covered above.
## The seventh set's pass 2 (the critic's pass-1 notes): each clip's fixed read as numbers (METRIC lines for the review).
func _seventh_pass2(lib: AnimationLibrary, names: Array[String]) -> void:
	# the Pop: the fist straight up over the head, the coil's unwind, the twin ending on the original's own held-stone pose
	if "own-bend-jab-rise" in names:
		var a := lib.get_animation(&"own-bend-jab-rise")
		var k := _at(a, float(a.get_meta(&"strike_s")), ["r_palm", "heada", "r_shoulder", "l_shoulder"])
		var h := _at(a, float(a.get_meta(&"hold_s")), ["r_shoulder", "l_shoulder"])
		var over := (k.r_palm as Vector3).y - (k.heada as Vector3).y
		var yaw0 := rad_to_deg(atan2((h.l_shoulder as Vector3).z - (h.r_shoulder as Vector3).z,
				(h.l_shoulder as Vector3).x - (h.r_shoulder as Vector3).x))
		var yaw1 := rad_to_deg(atan2((k.l_shoulder as Vector3).z - (k.r_shoulder as Vector3).z,
				(k.l_shoulder as Vector3).x - (k.r_shoulder as Vector3).x))
		print("METRIC own-bend-jab-rise fist_over_head_m %.3f unwind_deg %.1f" % [over, absf(yaw1 - yaw0)])
		_check(over > 0.3, "own-bend-jab-rise: the fist driven straight up over the head (%.3f m)" % over)
		_check(absf(yaw1 - yaw0) > 40.0, "own-bend-jab-rise: the shoulders unwind from the coil (%.1f deg)" % absf(yaw1 - yaw0))
		if "own-bend-jab-rise-l" in names:
			var b := lib.get_animation(&"own-bend-jab-rise-l")
			_check(b.has_meta(&"twin_tail_s"), "own-bend-jab-rise-l: twin_tail_s (its tail the original's own)")
			var e := 0.0
			var ba := _all_bones(a, a.length)
			var bb := _all_bones(b, b.length)
			for i in ba.size():
				e = maxf(e, ba[i].distance_to(bb[i]))
			print("METRIC own-bend-jab-rise-l end_off_original_m %.4f" % e)
			_check(e < 0.01, "own-bend-jab-rise-l: ends on the original's held-stone pose (every bone %.4f m)" % e)
			var top := _bone(b, float(b.get_meta(&"strike_s")), "l_palm").y - _bone(b, float(b.get_meta(&"strike_s")), "heada").y
			_check(top > 0.3, "own-bend-jab-rise-l: the left fist straight up over the head (%.3f m)" % top)
	# the Hammer: arched at the hold (the fists behind the head), the fists ahead of and below the knees at the strike
	if "own-bend-earth-hammer" in names:
		var a := lib.get_animation(&"own-bend-earth-hammer")
		var h := _at(a, float(a.get_meta(&"hold_s")), ["r_palm", "l_palm", "heada"])
		var k := _at(a, float(a.get_meta(&"strike_s")), ["r_palm", "l_palm", "r_knee", "l_knee"])
		var behind := (h.heada as Vector3).z - maxf((h.r_palm as Vector3).z, (h.l_palm as Vector3).z)
		var below := minf((k.r_knee as Vector3).y, (k.l_knee as Vector3).y) - maxf((k.r_palm as Vector3).y, (k.l_palm as Vector3).y)
		var ahead := minf((k.r_palm as Vector3).z, (k.l_palm as Vector3).z) - maxf((k.r_knee as Vector3).z, (k.l_knee as Vector3).z)
		var wide := (k.l_knee as Vector3).x - (k.r_knee as Vector3).x
		print("METRIC own-bend-earth-hammer fists_behind_head_m %.3f fists_under_knees_m %.3f fists_ahead_knees_m %.3f knees_apart_m %.3f"
				% [behind, below, ahead, wide])
		_check(behind > 0.1, "own-bend-earth-hammer: the fists cocked behind the head at the hold (%.3f m)" % behind)
		_check(below > 0.0 and ahead > 0.2, "own-bend-earth-hammer: the fists ahead of and below the knees (%.3f under, %.3f ahead)"
				% [below, ahead])
		_check(wide > 0.6, "own-bend-earth-hammer: the knees spread wide in the air horse (%.3f m)" % wide)
	# the Downpour: the palms ahead of the hips, the arms long, the body lifted
	if "own-bend-water-downpour" in names:
		var a := lib.get_animation(&"own-bend-water-downpour")
		var st := float(a.get_meta(&"strike_s"))
		var k := _at(a, st, ["r_palm", "l_palm", "pelvis"])
		var lift := _bone(a, 8 / 30.0, "pelvis").y - _bone(a, float(a.get_meta(&"hold_s")), "pelvis").y
		var slack := maxf(_reach(a, st, "r_palm"), _reach(a, st, "l_palm"))
		var ahead := minf((k.r_palm as Vector3).z, (k.l_palm as Vector3).z) - (k.pelvis as Vector3).z
		print("METRIC own-bend-water-downpour palms_ahead_of_hips_m %.3f arm_slack_m %.3f lift_m %.3f" % [ahead, slack, lift])
		_check(ahead > 0.25, "own-bend-water-downpour: the palms pressed ahead of the hips (%.3f m)" % ahead)
		_check(slack < 0.05, "own-bend-water-downpour: the arms long at the press (%.3f m short of straight)" % slack)
		_check(lift > 0.15, "own-bend-water-downpour: the body lifted on the press (%.3f m)" % lift)
	# the Axe Kick: the knee locked at the strike, the heel ahead; the twin's legs never crossing in its ends' blend
	for x: String in ["own-bend-fire-axe-kick", "own-bend-fire-axe-kick-l"]:
		if not x in names:
			continue
		var a := lib.get_animation(StringName(x))
		var s := "r" if x == "own-bend-fire-axe-kick" else "l"
		var j := _at(a, float(a.get_meta(&"strike_s")), [s + "_upper_leg", s + "_knee", s + "_ankle"])
		var knee := _bend(j, s + "_upper_leg", s + "_knee", s + "_ankle")
		print("METRIC %s strike_knee_deg %.1f" % [x, knee])
		_check(knee <= 20.0, "%s: the knee long at the strike, not locked (%.1f deg <= 20)" % [x, knee])
		var n := int(round(a.length * 30.0))
		var hop := 0.0
		var cross := INF
		var prev := {}
		for i in n + 1:
			var p := _at(a, i / 30.0, ["r_ankle", "l_ankle", "r_knee", "l_knee"])
			cross = minf(cross, minf((p.l_ankle as Vector3).x - (p.r_ankle as Vector3).x, (p.l_knee as Vector3).x - (p.r_knee as Vector3).x))
			if i >= 14 and not prev.is_empty():
				hop = maxf(hop, maxf((p.r_ankle as Vector3).distance_to(prev.r_ankle), (p.l_ankle as Vector3).distance_to(prev.l_ankle)))
			prev = p
		print("METRIC %s legs_apart_min_m %.3f tail_ankle_step_m %.3f" % [x, cross, hop])
		_check(cross > 0.05, "%s: the legs never cross (the knees and ankles %.3f m apart at the closest)" % [x, cross])
		_check(hop <= 0.25, "%s: no ankle jumps over f13-f22 (%.3f m a frame <= 0.25)" % [x, hop])
	# the Down Gust: the palms driven down, the body lifted
	if "own-bend-air-down-gust" in names:
		var a := lib.get_animation(&"own-bend-air-down-gust")
		var hy := _bone(a, float(a.get_meta(&"hold_s")), "r_palm").y
		var ky := _bone(a, float(a.get_meta(&"strike_s")), "r_palm").y
		var lift := _bone(a, 8 / 30.0, "pelvis").y - _bone(a, 0.0, "pelvis").y
		print("METRIC own-bend-air-down-gust palm_drive_m %.3f lift_m %.3f" % [hy - ky, lift])
		_check(hy - ky > 0.6, "own-bend-air-down-gust: the palms driven down (%.3f m)" % (hy - ky))
		_check(lift > 0.15, "own-bend-air-down-gust: the body lifted on the gust (%.3f m)" % lift)
	# the guards: earth's wide horse and its breath, fire's bounce
	for x: String in ["own-bend-guard-hold-earth", "own-bend-guard-hold-fire"]:
		if not x in names:
			continue
		var a := lib.get_animation(StringName(x))
		var lo := INF
		var hi := -INF
		for i in int(round(a.length * 30.0)) + 1:
			var y := _bone(a, i / 30.0, "pelvis").y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		var j := _at(a, 0.0, ["r_ankle", "l_ankle"])
		var stance := (j.l_ankle as Vector3).x - (j.r_ankle as Vector3).x
		print("METRIC %s hips_travel_m %.3f stance_m %.3f" % [x, hi - lo, stance])
		if x == "own-bend-guard-hold-earth":
			_check(stance > 0.55, "%s: the horse wide (the ankles %.3f m apart)" % [x, stance])
			_check(hi - lo > 0.03, "%s: the breath reads (the hips %.3f m)" % [x, hi - lo])
		else:
			_check(hi - lo > 0.04, "%s: the bounce reads (the hips %.3f m)" % [x, hi - lo])
	# the teeter: the arms never strobing, the hips over or ahead of the balls of the feet once tipped
	if "own-bend-teeter" in names:
		var a := lib.get_animation(&"own-bend-teeter")
		var n := int(round(a.length * 30.0))
		var step := 0.0
		var back := INF
		var prev := {}
		for i in n + 1:
			var p := _at(a, i / 30.0, ["r_palm", "l_palm", "pelvis", "r_ball", "l_ball"])
			if not prev.is_empty():
				step = maxf(step, maxf((p.r_palm as Vector3).distance_to(prev.r_palm), (p.l_palm as Vector3).distance_to(prev.l_palm)))
			if i >= 3:
				back = minf(back, (p.pelvis as Vector3).z - maxf((p.r_ball as Vector3).z, (p.l_ball as Vector3).z))
			prev = p
		print("METRIC own-bend-teeter palm_step_max_m %.3f hips_past_balls_min_m %.3f" % [step, back])
		_check(step <= 0.45, "own-bend-teeter: the windmill never strobes (a palm %.3f m a frame <= 0.45)" % step)
		_check(back >= -0.01, "own-bend-teeter: the hips over or ahead of the balls of the feet once tipped (%.3f m)" % back)


## The seventh set's pass 3 (the critic's pass-2 notes): each fixed read as numbers (METRIC lines for the review).
func _seventh_pass3(lib: AnimationLibrary, names: Array[String]) -> void:
	# the Pop: the stone shown from back_s (stone_s), the twin's left fist rising and dropping straight back, its right
	# hand reaching for the stone early
	for x: String in ["own-bend-jab-rise", "own-bend-jab-rise-l"]:
		if not x in names:
			continue
		var a := lib.get_animation(StringName(x))
		var ss := float(a.get_meta(&"stone_s", -1.0))
		print("METRIC %s stone_s %.3f back_s %.3f" % [x, ss, float(a.get_meta(&"back_s", -1.0))])
		_check(is_equal_approx(ss, float(a.get_meta(&"back_s", -2.0))), "%s: the stone shown from the hand's arrival (stone_s %.3f = back_s)"
				% [x, ss])
	if "own-bend-jab-rise-l" in names:
		var b := lib.get_animation(&"own-bend-jab-rise-l")
		var g5 := _grip(b, 5 / 30.0, "l")
		var gmin := INF
		var xmax := -INF
		for i in range(5, 14):
			gmin = minf(gmin, _grip(b, i / 30.0, "l"))
			if i >= 8:
				xmax = maxf(xmax, _bone(b, i / 30.0, "l_palm").x)
		var reach := _bone(b, 11 / 30.0, "r_palm").distance_to(POP_STONE) - POP_STONE_R
		print("METRIC own-bend-jab-rise-l fist_grip_f5 %.1f fist_grip_min %.1f left_palm_x_max %.3f right_to_stone_f11_m %.3f"
				% [g5, gmin, xmax, reach])
		_check(gmin > g5 - 10.0, "own-bend-jab-rise-l: the rising left fist stays a fist to f13 (%.0f -> %.0f deg)" % [g5, gmin])
		_check(xmax < 0.3, "own-bend-jab-rise-l: the left hand drops back to the guard, never out for a stone (x %.3f m)" % xmax)
		_check(reach < 0.12, "own-bend-jab-rise-l: the right hand on its way to the stone by f11 (%.3f m off it)" % reach)
	# the Slams' hand drive: the biggest step on the strike frame
	for x: String in ["own-bend-earth-hammer", "own-bend-water-downpour", "own-bend-air-down-gust"]:
		if not x in names:
			continue
		var a := lib.get_animation(StringName(x))
		var f := int(round(float(a.get_meta(&"strike_s")) * 30.0))
		var p3 := _bone(a, (f - 3) / 30.0, "r_palm")
		var p4 := _bone(a, (f - 2) / 30.0, "r_palm")
		var p5 := _bone(a, (f - 1) / 30.0, "r_palm")
		var p6 := _bone(a, f / 30.0, "r_palm")
		var d4 := p4.distance_to(p3)
		var d5 := p5.distance_to(p4)
		var d6 := p6.distance_to(p5)
		print("METRIC %s palm_steps_m %.3f %.3f %.3f (the last onto the strike) drop %.3f" % [x, d4, d5, d6, p5.y - p6.y])
		_check(d6 > d5 and d6 > d4, "%s: the biggest hand step lands on the strike (%.3f, %.3f, %.3f m)" % [x, d4, d5, d6])
	if "own-bend-earth-hammer" in names:
		var a := lib.get_animation(&"own-bend-earth-hammer")
		var worst := INF
		for i in range(6, 11):
			var j := _at(a, i / 30.0, ["r_palm", "l_palm", "r_knee", "l_knee"])
			worst = minf(worst, minf((j.r_knee as Vector3).y, (j.l_knee as Vector3).y)
					- maxf((j.r_palm as Vector3).y, (j.l_palm as Vector3).y))
		print("METRIC own-bend-earth-hammer fists_under_knees_min_m %.3f" % worst)
		_check(worst > 0.06, "own-bend-earth-hammer: the fists hang clear below the knees over f6-f10 (%.3f m)" % worst)
	if "own-bend-water-downpour" in names:
		var a := lib.get_animation(&"own-bend-water-downpour")
		var f := int(round(float(a.get_meta(&"strike_s")) * 30.0))
		var p5 := _bone(a, (f - 1) / 30.0, "r_palm")
		var p6 := _bone(a, f / 30.0, "r_palm")
		var vert := (p5.y - p6.y) / maxf(p5.distance_to(p6), 1e-4)
		var k := _at(a, f / 30.0, ["heada", "pelvis", "r_ankle", "l_ankle"])
		var lean := (k.heada as Vector3).z - (k.pelvis as Vector3).z
		var pike := ((k.r_ankle as Vector3).z + (k.l_ankle as Vector3).z) * 0.5 - (k.pelvis as Vector3).z
		var s0 := _bone(a, f / 30.0, "r_palm").y - _bone(a, f / 30.0, "pelvis").y
		var s1 := _bone(a, (f + 3) / 30.0, "r_palm").y - _bone(a, (f + 3) / 30.0, "pelvis").y
		print("METRIC own-bend-water-downpour strike_step_vertical %.2f head_ahead_of_hips_m %.3f feet_ahead_of_hips_m %.3f palm_sink_m %.3f"
				% [vert, lean, pike, s0 - s1])
		_check(vert > 0.8, "own-bend-water-downpour: the strike frame falls nearly straight down (%.2f of it vertical)" % vert)
		_check(lean > 0.12, "own-bend-water-downpour: the trunk folded forward over the press (the head %.3f m ahead of the hips)" % lean)
		_check(pike > 0.05, "own-bend-water-downpour: the legs swung ahead into a shallow pike (the feet %.3f m ahead)" % pike)
		_check(s0 - s1 > 0.02, "own-bend-water-downpour: the palms press on down past the strike (%.3f m against the body)" % (s0 - s1))
	for x: String in ["own-bend-fire-axe-kick", "own-bend-fire-axe-kick-l"]:
		if not x in names:
			continue
		var a := lib.get_animation(StringName(x))
		var s := "r" if x == "own-bend-fire-axe-kick" else "l"
		var o := "l" if s == "r" else "r"
		var k := _at(a, float(a.get_meta(&"strike_s")), ["pelvis", o + "_ankle", o + "_knee"])
		var back := (k.pelvis as Vector3).z - (k[o + "_ankle"] as Vector3).z
		var high := (k[o + "_ankle"] as Vector3).y - ((k.pelvis as Vector3).y - 0.9)
		var j2 := _at(a, 2 / 30.0, [s + "_ankle", s + "_upper_leg"])
		var out := absf((j2[s + "_ankle"] as Vector3).x - (j2[s + "_upper_leg"] as Vector3).x)
		var n := int(round(a.length * 30.0))
		var apart := INF
		for i in range(13, n + 1):
			var p := _at(a, i / 30.0, ["r_ankle", "l_ankle"])
			apart = minf(apart, (p.r_ankle as Vector3).distance_to(p.l_ankle))
		print("METRIC %s rear_ankle_behind_hips_m %.3f rear_ankle_raised_m %.3f crescent_out_f2_m %.3f tail_ankles_apart_min_m %.3f"
				% [x, back, high, out, apart])
		_check(back < 0.3 and high > 0.35, "%s: the rear leg folded up under him at the strike (%.3f behind, %.3f up)" % [x, back, high])
		_check(out > 0.25, "%s: the crescent swung out wide of the hip on the way up (%.3f m)" % [x, out])
		_check(apart >= 0.2, "%s: the ankles 0.2 m and more apart over f13 to the end (%.3f m)" % [x, apart])
	if "own-bend-air-down-gust" in names:
		var a := lib.get_animation(&"own-bend-air-down-gust")
		var f := int(round(float(a.get_meta(&"strike_s")) * 30.0))
		var k := _at(a, f / 30.0, ["r_palm", "l_palm", "pelvis", "r_ankle", "l_ankle"])
		var flare := (k.l_palm as Vector3).x - (k.r_palm as Vector3).x
		var tuck := (k.pelvis as Vector3).y - maxf((k.r_ankle as Vector3).y, (k.l_ankle as Vector3).y)
		var yaw := func(t: float) -> float:
			var q := _at(a, t, ["r_shoulder", "l_shoulder"])
			return rad_to_deg(atan2((q.l_shoulder as Vector3).z - (q.r_shoulder as Vector3).z,
					(q.l_shoulder as Vector3).x - (q.r_shoulder as Vector3).x))
		var y6: float = yaw.call(f / 30.0)
		var y8: float = yaw.call((f + 2) / 30.0)
		print("METRIC own-bend-air-down-gust flare_m %.3f hips_over_ankles_m %.3f shoulder_turn_strike %.1f f+2 %.1f"
				% [flare, tuck, y6, y8])
		_check(flare > 0.9, "own-bend-air-down-gust: the palms flared wide at the strike (%.3f m)" % flare)
		_check(tuck < 0.6, "own-bend-air-down-gust: the knees kept half tucked, compact (the hips %.3f m over the ankles)" % tuck)
		_check(absf(y8) > absf(y6) + 2.0, "own-bend-air-down-gust: the spiral turns on past the strike (%.1f -> %.1f deg)" % [y6, y8])
		if "own-bend-water-downpour" in names:
			var w := lib.get_animation(&"own-bend-water-downpour")
			var kw := _at(w, float(w.get_meta(&"strike_s")), ["r_palm", "l_palm", "r_ankle", "l_ankle"])
			var d := 0.0
			for bn: String in ["r_palm", "l_palm", "r_ankle", "l_ankle"]:
				d = maxf(d, (k[bn] as Vector3).distance_to(kw[bn]))
			print("METRIC down_gust_vs_downpour strike_apart_m %.3f" % d)
			_check(d > 0.3, "the Down Gust's and the Downpour's strikes apart at a glance (%.3f m)" % d)
	if "own-bend-teeter" in names:
		var a := lib.get_animation(&"own-bend-teeter")
		var j0 := _at(a, 0.0, ["r_palm", "l_palm", "pelvis", "r_ankle", "l_ankle"])
		var j2 := _at(a, 2 / 30.0, ["r_palm", "l_palm"])
		var e := _at(a, a.length, ["r_palm", "l_palm", "pelvis", "r_ankle", "l_ankle", "heada"])
		var early := maxf((j2.r_palm as Vector3).distance_to(j0.r_palm), (j2.l_palm as Vector3).distance_to(j0.l_palm))
		var tip := (e.pelvis as Vector3).z - (j0.pelvis as Vector3).z
		var heel := minf((e.r_ankle as Vector3).y - (j0.r_ankle as Vector3).y, (e.l_ankle as Vector3).y - (j0.l_ankle as Vector3).y)
		var over := minf((e.r_palm as Vector3).y, (e.l_palm as Vector3).y) - (e.heada as Vector3).y
		var wide := (e.l_palm as Vector3).x - (e.r_palm as Vector3).x
		print("METRIC own-bend-teeter palms_moved_by_f2_m %.3f hips_tipped_m %.3f heels_up_m %.3f end_palms_over_head_m %.3f end_palms_apart_m %.3f"
				% [early, tip, heel, over, wide])
		_check(early < 0.1, "own-bend-teeter: the arms start after the lurch (the palms %.3f m off the stand by f2)" % early)
		_check(tip >= 0.14, "own-bend-teeter: tipped out from the ankles (the hips %.3f m past the start)" % tip)
		_check(heel > 0.03, "own-bend-teeter: up on both toes at the end (the ankles %.3f m up)" % heel)
		_check(over > 0.1 and wide > 0.7, "own-bend-teeter: held in a wide V over the head (%.3f over, %.3f apart)" % [over, wide])


func _sixth_pass3(lib: AnimationLibrary, names: Array[String], lie: Animation) -> void:

	if "own-bend-tech-wall" in names:
		# (the hat brim kept 8 cm and more off the wall while the palms and the balls of the feet are on it)
		var a := lib.get_animation(&"own-bend-tech-wall")
		var wz := float(a.get_meta(&"wall_z", 0.0))
		var b := sk.find_bone("headb")
		var front := -INF
		for i in range(1, 5):
			_joints(a, i / 30.0)
			var rest := sk.get_bone_global_rest(b)
			var pose := sk.get_bone_global_pose(b)
			for v: Vector3 in HAT_REST:
				front = maxf(front, (pose * (rest.affine_inverse() * v)).z)
		print("METRIC tech_wall hat_brim_off_wall_m %.3f" % (wz - front))
		_check(wz - front >= 0.08, "tech-wall: the hat brim 8 cm and more off the wall (%.3f m)" % (wz - front))
	if lie != null:
		# (the daze's beat early, inside the 0.4 s a getup may wait: the flung hand up 8 cm and more and the head lifted by f12)
		var j0 := _at(lie, 0.0, ["r_palm", "heada"])
		var hand := 0.0
		var peak := -1
		for i in range(0, 13):
			var j := _at(lie, i / 30.0, ["r_palm"])
			var up := (j.r_palm as Vector3).y - (j0.r_palm as Vector3).y
			if up > hand:
				hand = up
				peak = i
		print("METRIC lie stir_hand_up_m %.3f at f%d" % [hand, peak])
		_check(hand >= 0.08 and peak <= 12, "lie: the hand's stir by f12 (%.2f m at f%d)" % [hand, peak])
	if "own-bend-getup" in names:
		# (no pop: the pelvis never moves 0.2 m in a frame; the landing ridden: up onto the toes past the stand, then a settle)
		var a := lib.get_animation(&"own-bend-getup")
		var jump := 0.0
		var prev := _at(a, 0.0, ["pelvis"])
		for i in range(1, 21):
			var j := _at(a, i / 30.0, ["pelvis"])
			jump = maxf(jump, (j.pelvis as Vector3).distance_to(prev.pelvis))
			prev = j
		var p15 := (_at(a, 15.0 / 30.0, ["pelvis"]).pelvis as Vector3).y
		var p17 := (_at(a, 17.0 / 30.0, ["pelvis"]).pelvis as Vector3).y
		print("METRIC getup pelvis_step_max_m %.3f overshoot_settle_m %.3f" % [jump, p15 - p17])
		_check(jump < 0.2, "getup: the pelvis never jumps 0.2 m in a frame (%.3f m)" % jump)
		_check(p15 - p17 > 0.01, "getup: up past the stand, then settled (%.3f m)" % (p15 - p17))
	if "own-bend-getup-attack" in names:
		# (the sweeping leg straight from the wind-up through the held end of the arc)
		var a := lib.get_animation(&"own-bend-getup-attack")
		var worst := 0.0
		for i in range(5, 10):
			var j := _at(a, i / 30.0, ["r_upper_leg", "r_knee", "r_ankle"])
			worst = maxf(worst, _bend(j, "r_upper_leg", "r_knee", "r_ankle"))
		print("METRIC getup_attack sweep_knee_max_deg %.1f" % worst)
		_check(worst < 12.0, "getup-attack: the sweeping leg straight (the knee %.1f deg off)" % worst)
	if "own-bend-knock-bounce" in names:
		# (the limbs trail: the heels and the hands left on the deck while the trunk lifts, f4-f6)
		var a := lib.get_animation(&"own-bend-knock-bounce")
		var high := 0.0
		for i in range(4, 7):
			var j := _at(a, i / 30.0, ["r_palm", "l_palm", "r_heel", "l_heel"])
			for n: String in ["r_palm", "l_palm", "r_heel", "l_heel"]:
				high = maxf(high, (j[n] as Vector3).y)
		print("METRIC knock_bounce limbs_trailing_max_y_m %.3f" % high)
		_check(high <= 0.1, "knock-bounce: the hands and heels left on the deck as the trunk lifts (%.3f m)" % high)


## The four Rises read as their elements' own recoveries, and apart from each other at a glance.
func _sixth_rises(lib: AnimationLibrary, names: Array[String]) -> void:
	var bones := ["l_palm", "r_palm", "l_ankle", "r_ankle", "heada", "pelvis", "l_knee", "r_knee"]
	var key_pose := {}
	if "own-bend-rise-earth" in names:
		var a := lib.get_animation(&"own-bend-rise-earth")
		var hold := float(a.get_meta(&"hold_s"))
		var strike := float(a.get_meta(&"strike_s"))
		# (the feet planted on the column's top from the horse to the throw)
		var j0 := _at(a, hold, ["l_ankle", "r_ankle"])
		var slide := 0.0
		for i in 13:
			# (to the frame before the throw: at the throw the heels lift as the legs drive)
			var j := _at(a, hold + (strike - 1.0 / 30.0 - hold) * i / 12.0, ["l_ankle", "r_ankle"])
			slide = maxf(slide, maxf((j.l_ankle as Vector3).distance_to(j0.l_ankle), (j.r_ankle as Vector3).distance_to(j0.r_ankle)))
		var mid := (hold + strike) * 0.5
		var m := _at(a, mid, bones)
		var feet := ((m.l_ankle as Vector3) + (m.r_ankle as Vector3)) * 0.5
		var lean := rad_to_deg(Vector3.UP.angle_to((m.pelvis as Vector3) - feet))
		var fists := maxf((m.l_palm as Vector3).y, (m.r_palm as Vector3).y) - (m.pelvis as Vector3).y
		var wide := absf((m.l_ankle as Vector3).x - (m.r_ankle as Vector3).x)
		# (pass 3: the throw asymmetric: the right fist driven up over the head as the bridge hand, the left at the hip)
		var up := _at(a, strike + 3.0 / 30.0, bones)
		var over := (up.r_palm as Vector3).y - (up.heada as Vector3).y
		# (pass 2: the fists driven down outside the knees, the arms nearly straight; the throw's frame already sweeping up)
		var outside := minf(absf((m.r_palm as Vector3).x) - absf((m.r_knee as Vector3).x),
				absf((m.l_palm as Vector3).x) - absf((m.l_knee as Vector3).x))
		var sh := _at(a, mid, ["r_shoulder", "r_palm", "l_shoulder", "l_palm"])
		var reach := minf((sh.r_palm as Vector3).distance_to(sh.r_shoulder), (sh.l_palm as Vector3).distance_to(sh.l_shoulder))
		var th := _at(a, strike + 2.0 / 30.0, ["r_shoulder", "r_palm"])
		var sweep := (th.r_palm as Vector3).y - (th.r_shoulder as Vector3).y
		print("METRIC rise_earth feet_slide_m %.4f lean_deg %.1f fists_under_hips_m %.3f stance_m %.2f palms_over_head_m %.2f"
				% [slide, lean, -fists, wide, over])
		print("METRIC rise_earth fists_outside_knees_m %.3f fist_reach_m %.3f throw_palm_over_shoulder_m %.3f"
				% [outside, reach, sweep])
		_check(outside > 0.02, "rise-earth: the fists driven down outside the knees (%.3f m)" % outside)
		_check(reach > 0.42, "rise-earth: the arms nearly straight into the stone (palm %.2f m from the shoulder)" % reach)
		_check(sweep > 0.12, "rise-earth: two frames into the throw the fist sweeps up past the shoulder (%.2f m over it)" % sweep)
		var hip := (up.l_palm as Vector3).y - (up.pelvis as Vector3).y
		var clear := INF
		for i in range(18, 27):
			_joints(a, i / 30.0)
			clear = minf(clear, _palm_hat())
		var grip_r := _grip(a, strike + 3.0 / 30.0, "r")
		print("METRIC rise_earth bridge_fist_over_head_m %.3f left_fist_over_hips_m %.3f fist_hat_clear_m %.3f right_curl_deg %.0f"
				% [over, hip, clear, grip_r])
		_check(hip < 0.25, "rise-earth: the left fist chambered at the hip at the throw (%.2f m over the hips)" % hip)
		_check(clear >= 0.1, "rise-earth: the fists 10 cm and more clear of the hat through the throw (%.3f m)" % clear)
		_check(grip_r > 60.0, "rise-earth: the bridge hand a closed fist (the index curled %.0f deg)" % grip_r)
		_check(slide < 0.01, "rise-earth: the feet planted on the column from the horse to the throw (%.4f m)" % slide)
		_check(lean >= 12.0 and lean <= 40.0, "rise-earth: leant forward with the column (%.1f deg)" % lean)
		_check(fists < -0.15, "rise-earth: both fists driven down under the hips (%.2f m)" % fists)
		_check(wide > 0.5, "rise-earth: a wide horse (the ankles %.2f m apart)" % wide)
		_check(over > 0.1, "rise-earth: thrown off with the right fist up over the head (%.2f m)" % over)
		key_pose["earth"] = m
	if "own-bend-rise-water" in names:
		var a := lib.get_animation(&"own-bend-rise-water")
		var strike := float(a.get_meta(&"strike_s"))
		var back := float(a.get_meta(&"back_s"))
		var path := 0.0
		var prev := _at(a, strike, bones)
		for i in range(1, 25):
			var j := _at(a, strike + (back - strike) * i / 24.0, bones)
			path += (j.r_palm as Vector3).distance_to(prev.r_palm)
			prev = j
		var top := _at(a, back - 1.0 / 30.0, bones)
		# (pass 2: the peak both hands floating over the head in a wide oval, standing tall on both feet; the circles
		# bulging out in front of the body so they read from the camera)
		# (pass 3: the crane: the right palm high over the head and out, the left pressed down by the hip: a spiral, not a V)
		var over := (top.r_palm as Vector3).y - (top.heada as Vector3).y
		var oval := (top.r_palm as Vector3).y - (top.l_palm as Vector3).y
		var low_hand := (top.l_palm as Vector3).y - (top.pelvis as Vector3).y
		var feet := absf((top.l_ankle as Vector3).y - (top.r_ankle as Vector3).y)
		var bulge := 0.0
		for i in 25:
			var j := _at(a, strike + (back - strike) * i / 24.0, ["r_palm", "l_palm", "pelvis"])
			bulge = maxf(bulge, maxf((j.r_palm as Vector3).z, (j.l_palm as Vector3).z) - (j.pelvis as Vector3).z)
		print("METRIC rise_water swirl_path_m %.2f top_hands_over_head_m %.3f top_oval_m %.2f feet_level_m %.3f swirl_ahead_m %.2f"
				% [path, over, oval, feet, bulge])
		_check(path > 1.5, "rise-water: the hand swirls round (its path %.2f m)" % path)
		var kn := _at(a, 10.0 / 30.0, ["r_upper_leg", "r_knee", "r_ankle", "l_upper_leg", "l_knee", "l_ankle"])
		var soft := (_bend(kn, "r_upper_leg", "r_knee", "r_ankle") + _bend(kn, "l_upper_leg", "l_knee", "l_ankle")) * 0.5
		print("METRIC rise_water crane_low_hand_over_hips_m %.3f swirl_knees_deg %.1f" % [low_hand, soft])
		_check(over > 0.15, "rise-water: the crane's right palm high over the head (%.2f m)" % over)
		_check(oval > 0.5, "rise-water: the crane's hands 0.5 m and more apart in height (%.2f m)" % oval)
		_check(low_hand < 0.2, "rise-water: the crane's left palm pressed down by the hip (%.2f m over the hips)" % low_hand)
		_check(soft > 15.0 and soft < 50.0, "rise-water: the knees soft riding the column (%.1f deg)" % soft)
		_check(feet < 0.06, "rise-water: standing on both feet on the column (the ankles %.3f m apart in height)" % feet)
		_check(bulge > 0.3, "rise-water: the circles swept out in front of the body (%.2f m ahead of the hips)" % bulge)
		key_pose["water"] = _at(a, (strike + back) * 0.5, bones)
	if "own-bend-rise-fire" in names:
		var a := lib.get_animation(&"own-bend-rise-fire")
		var hold := float(a.get_meta(&"hold_s"))
		var strike := float(a.get_meta(&"strike_s"))
		var back := float(a.get_meta(&"back_s"))
		var h := _at(a, hold, bones)
		var b := _at(a, (strike + back) * 0.5, bones)
		var tuck := ((h.l_ankle as Vector3).y + (h.r_ankle as Vector3).y - (b.l_ankle as Vector3).y - (b.r_ankle as Vector3).y) * 0.5
		var j := _at(a, (strike + back) * 0.5, ["r_upper_leg", "r_knee", "r_ankle", "l_upper_leg", "l_knee", "l_ankle"])
		var knee := maxf(_bend(j, "r_upper_leg", "r_knee", "r_ankle"), _bend(j, "l_upper_leg", "l_knee", "l_ankle"))
		var fist := (b.r_palm as Vector3).y - (b.heada as Vector3).y
		var hips := maxf(absf((h.l_palm as Vector3).y - (h.pelvis as Vector3).y), absf((h.r_palm as Vector3).y - (h.pelvis as Vector3).y))
		var f0 := _at(a, strike + 1.0 / 30.0, ["r_palm"])
		var f1 := _at(a, back, ["r_palm"])
		var drive := (f1.r_palm as Vector3).distance_to(f0.r_palm)
		print("METRIC rise_fire hover_tuck_m %.3f burst_knee_deg %.1f fist_over_head_m %.3f hover_fists_by_hips_m %.3f burst_drive_m %.3f"
				% [tuck, knee, fist, hips, drive])
		_check(drive > 0.03, "rise-fire: the fist keeps driving through the burst (a moving hold, %.3f m)" % drive)
		_check(tuck > 0.25, "rise-fire: the knees drawn in the hover (%.2f m over the burst's)" % tuck)
		_check(knee < 20.0, "rise-fire: straight-legged along the burst (%.1f deg)" % knee)
		_check(fist > 0.15, "rise-fire: the fist leads the burst over the head (%.2f m)" % fist)
		_check(hips < 0.15, "rise-fire: the fists at the hips in the hover (%.2f m)" % hips)
		key_pose["fire"] = b
	if "own-bend-rise-air" in names:
		var a := lib.get_animation(&"own-bend-rise-air")
		_check(a.has_meta(&"loop_from_s"), "rise-air: names where its glide loop starts (loop_from_s)")
		var lf := float(a.get_meta(&"loop_from_s", 0.0))
		var b0 := _all_bones(a, lf)
		var b1 := _all_bones(a, a.length)
		var seam := 0.0
		for i in b0.size():
			seam = maxf(seam, b0[i].distance_to(b1[i]))
		var g := _at(a, (lf + a.length) * 0.5, bones)
		var span := absf((g.l_palm as Vector3).x - (g.r_palm as Vector3).x)
		var s := _at(a, 7.0 / 30.0, bones + ["r_shoulder"])
		# (pass 2: the whirl a palm change: the right palm thrust out flat at the shoulder's height, no hand over the head,
		# the feet tucked up together)
		var out := Vector2((s.r_palm as Vector3).x - (s.pelvis as Vector3).x, (s.r_palm as Vector3).z - (s.pelvis as Vector3).z).length()
		var level := absf((s.r_palm as Vector3).y - (s.r_shoulder as Vector3).y)
		var high := maxf((s.l_palm as Vector3).y, (s.r_palm as Vector3).y) - (s.heada as Vector3).y
		var tuck := absf((s.l_ankle as Vector3).y - (s.r_ankle as Vector3).y)
		var gw := _at(a, (lf + a.length) * 0.5, ["r_palm", "l_palm", "r_shoulder", "l_shoulder"])
		var wing := minf((gw.r_palm as Vector3).y - (gw.r_shoulder as Vector3).y, (gw.l_palm as Vector3).y - (gw.l_shoulder as Vector3).y)
		print("METRIC rise_air glide_seam_m %.4f wing_span_m %.2f spin_palm_out_m %.2f spin_palm_vs_shoulder_m %.3f spin_hand_over_head_m %.3f spin_feet_m %.3f wing_vs_shoulder_m %.3f"
				% [seam, span, out, level, high, tuck, wing])
		_check(lf > 0.3 and lf < a.length - 0.5, "rise-air: the glide loop from %.2f s" % lf)
		_check(seam < 0.005, "rise-air: the glide loop's seam (every bone, %.4f m)" % seam)
		_check(span > 1.1, "rise-air: the arms spread as wings in the glide (%.2f m palm to palm)" % span)
		_check(wing > -0.15, "rise-air: the wings near the shoulders' height (%.2f m)" % wing)
		_check(out > 0.52, "rise-air: the palm thrust out wide in the whirl (%.2f m from the hips)" % out)
		_check(level < 0.15, "rise-air: the thrust palm at the shoulder's height (%.3f m off it)" % level)
		_check(high < 0.1, "rise-air: no hand over the head in the whirl (apart from the water Rise: %.2f m)" % high)
		_check(tuck < 0.08, "rise-air: the feet tucked up together in the whirl (%.3f m)" % tuck)
		# (pass 3: the wings' elbows bent and dropped through the glide, never locked straight (the T pose))
		var el := Vector2(INF, -INF)
		for i in range(int(round(lf * 30.0)), int(round(a.length * 30.0)) + 1):
			var e := _at(a, i / 30.0, ["r_shoulder", "r_elbow", "r_wrist", "l_shoulder", "l_elbow", "l_wrist"])
			var m := (_bend(e, "r_shoulder", "r_elbow", "r_wrist") + _bend(e, "l_shoulder", "l_elbow", "l_wrist")) * 0.5
			el = Vector2(minf(el.x, m), maxf(el.y, m))
		print("METRIC rise_air glide_elbows_deg %.0f..%.0f" % [el.x, el.y])
		_check(el.x > 10.0 and el.y < 55.0, "rise-air: the wings' elbows bent through the glide (%.0f..%.0f deg)" % [el.x, el.y])
		key_pose["air"] = s
	# (apart at a glance: each pair of the four key poses differs somewhere by 0.4 m or more, the palms and the ankles
	# measured from the pelvis)
	var els := key_pose.keys()
	for i in els.size():
		for k in range(i + 1, els.size()):
			var p: Dictionary = key_pose[els[i]]
			var q: Dictionary = key_pose[els[k]]
			var d := 0.0
			for n: String in ["l_palm", "r_palm", "l_ankle", "r_ankle"]:
				d = maxf(d, ((p[n] as Vector3) - (p.pelvis as Vector3)).distance_to((q[n] as Vector3) - (q.pelvis as Vector3)))
			_check(d >= 0.4, "rises: %s and %s read apart (%.2f m)" % [els[i], els[k], d])


## The scramble, the breaks, the getups and the knocks.
func _sixth_recoveries(lib: AnimationLibrary, names: Array[String], lie: Animation) -> void:
	if "own-bend-edge-scramble" in names and "own-bend-edge-hang" in names:
		var a := lib.get_animation(&"own-bend-edge-scramble")
		var hang := lib.get_animation(&"own-bend-edge-hang")
		var lip_y := float(hang.get_meta(&"lip_y", 2.0))
		var lip_z := float(hang.get_meta(&"lip_out", 0.35))
		var e := _all_bones(a, a.length)
		var h := _all_bones(hang, 0.0)
		var worst := 0.0
		for i in e.size():
			worst = maxf(worst, e[i].distance_to(h[i]))
		print("METRIC edge_scramble end_vs_hang_m %.5f" % worst)
		_check(worst < 0.01, "scramble: the last frame is the hang's first (every bone end within 1 cm: %.4f m)" % worst)
		_check(is_equal_approx(float(a.get_meta(&"lip_y", -1.0)), lip_y), "scramble: keyed about the hang's lip (lip_y)")
		var s := _at(a, 0.0, ["heada", "l_palm", "r_palm"])
		_check((s.heada as Vector3).y < lip_y, "scramble: starts with the head under the lip (%.2f m)" % ((s.heada as Vector3).y - lip_y))
		# (pass 3: the right hand thrown over the lip at hold_s and slapped on the deck at strike_s, so a foe on the deck sees
		# it land in the first 0.1 s; the left palm slapped on the face under the lip as the brace)
		var over := _at(a, float(a.get_meta(&"hold_s")), ["r_palm"])
		var deck := _at(a, float(a.get_meta(&"strike_s")), ["r_palm", "heada"])
		var slap := _at(a, 4.0 / 30.0, ["l_palm"])
		var face := absf((slap.l_palm as Vector3).z - lip_z)
		print("METRIC edge_scramble hold_r_over_lip_m %.3f strike_r_on_deck_m %.3f strike_s %.3f head_f3_over_lip_m %.3f" % [
				(over.r_palm as Vector3).y - lip_y, (deck.r_palm as Vector3).y - lip_y, float(a.get_meta(&"strike_s")),
				(deck.heada as Vector3).y - lip_y])
		_check((over.r_palm as Vector3).y > lip_y + 0.15 and (over.r_palm as Vector3).z > lip_z, "scramble: the right hand over the lip at hold_s")
		_check(absf((deck.r_palm as Vector3).y - lip_y - 0.03) < 0.02 and (deck.r_palm as Vector3).z > lip_z + 0.1,
				"scramble: the right palm on the deck at strike_s (%.3f m)" % ((deck.r_palm as Vector3).y - lip_y))
		_check(float(a.get_meta(&"strike_s")) <= 0.1 + 1e-4, "scramble: the hand on the deck in the first 0.1 s")
		_check((deck.heada as Vector3).y > lip_y + 0.1, "scramble: the head up over the lip by the slap (f3)")
		_check(face < 0.05 and (slap.l_palm as Vector3).y < lip_y, "scramble: the left hand slapped on the face under the lip (%.3f m off it)" % face)
		var top := 0.0
		for i in 19:
			var j := _at(a, i / 30.0, ["r_ball", "l_ball"])
			for n: String in ["r_ball", "l_ball"]:
				top = maxf(top, (j[n] as Vector3).z - lip_z)
		_check(top < 0.02, "scramble: the feet never through the face (%.3f m)" % top)
		# (pass 2: each hand thrown high over the lip before it lands on the deck, and the head over the lip early)
		var throw_l := _at(a, 7.0 / 30.0, ["l_palm"])
		print("METRIC edge_scramble throw_l_over_lip_m %.3f" % ((throw_l.l_palm as Vector3).y - lip_y))
		_check((throw_l.l_palm as Vector3).y > lip_y + 0.15 and (throw_l.l_palm as Vector3).z > lip_z,
				"scramble: the left hand thrown high over the lip (f7)")
		# (pass 3: each hand's last frame before the deck its apex over the place it lands: an arc over the lip and down)
		for sd: String in ["r", "l"]:
			var f_on := 3 if sd == "r" else 8
			var ap := _at(a, (f_on - 1) / 30.0, [sd + "_palm"])
			var on := _at(a, f_on / 30.0, [sd + "_palm"])
			var dz := (on[sd + "_palm"] as Vector3).z - (ap[sd + "_palm"] as Vector3).z
			_check((ap[sd + "_palm"] as Vector3).y > (on[sd + "_palm"] as Vector3).y + 0.15 and dz > -0.02 and dz < 0.15,
					"scramble: the %s hand's apex over its landing (dz %.2f m)" % [sd, dz])
	if "own-bend-tech" in names:
		var a := lib.get_animation(&"own-bend-tech")
		var j := _at(a, float(a.get_meta(&"strike_s")), ["r_palm", "r_knee"])
		print("METRIC tech slap_palm_y_m %.3f knee_y_m %.3f" % [(j.r_palm as Vector3).y, (j.r_knee as Vector3).y])
		_check((j.r_palm as Vector3).y < 0.06, "tech: the palm slapped on the deck (%.3f m)" % (j.r_palm as Vector3).y)
		_check((j.r_knee as Vector3).y < 0.1, "tech: the knee down on the deck (%.3f m)" % (j.r_knee as Vector3).y)
		# (pass 3: a controlled skill, not a collapse: the head kept up over the hips, the slapping arm out wide)
		var sk1 := _at(a, float(a.get_meta(&"strike_s")), ["heada", "pelvis", "r_palm", "r_shoulder"])
		var sk2 := _at(a, float(a.get_meta(&"hold_s")), ["heada", "pelvis"])
		var head_up := minf((sk1.heada as Vector3).y - (sk1.pelvis as Vector3).y, (sk2.heada as Vector3).y - (sk2.pelvis as Vector3).y)
		var wide := (sk1.pelvis as Vector3).x - (sk1.r_palm as Vector3).x
		print("METRIC tech head_over_hips_m %.3f slap_palm_out_m %.3f" % [head_up, wide])
		_check(head_up > 0.2, "tech: the head kept up over the hips at the slap and its rebound (%.2f m)" % head_up)
		_check(wide > 0.35, "tech: the slapping palm out wide to the side (%.2f m)" % wide)
		if "own-bend-tech-roll" in names:
			var tr := lib.get_animation(&"own-bend-tech-roll")
			var d := _off(_joints(tr, 1.0 / 30.0), _joints(a, float(a.get_meta(&"strike_s"))))
			_check(d < 0.02, "tech-roll: its second frame the tech's slap (off by %.3f m)" % d)
			var d0 := _off(_joints(tr, 0.0), _joints(a, 0.0))
			_check(d0 < 0.02, "tech-roll: enters from the tech's own airborne frame (off by %.3f m)" % d0)
	for x: String in ["own-bend-tech-roll", "own-bend-getup-roll"]:
		if x in names:
			_check(String(lib.get_animation(StringName(x)).get_meta(&"travel", "")) == "right", "%s: rolls to his right (travel)" % x)
			if (x + "-l") in names:
				_check(String(lib.get_animation(StringName(x + "-l")).get_meta(&"travel", "")) == "left", "%s-l: rolls to his left" % x)
	if "own-bend-tech-wall" in names:
		var a := lib.get_animation(&"own-bend-tech-wall")
		var wz := float(a.get_meta(&"wall_z", 0.0))
		var j := _at(a, float(a.get_meta(&"hold_s")), ["r_palm", "l_palm", "r_ball", "l_ball", "r_heel", "l_heel"])
		var off := 0.0
		for n: String in ["r_palm", "l_palm"]:
			off = maxf(off, absf((j[n] as Vector3).z - wz + 0.03))
		# (pass 2: the balls of the feet touching the wall: the ball's centre its own radius, BALL_R, in from it; + off it,
		# - through it)
		var sole := 0.0
		for n: String in ["r_ball", "l_ball"]:
			sole = maxf(sole, absf(wz - BALL_R - (j[n] as Vector3).z))
		var hips := _at(a, float(a.get_meta(&"hold_s")), ["pelvis"])
		var push := _at(a, 5.0 / 30.0, ["r_palm", "l_palm", "r_ball", "l_ball"])
		var palm_off := wz - maxf((push.r_palm as Vector3).z, (push.l_palm as Vector3).z)
		var ball_off := wz - BALL_R - maxf((push.r_ball as Vector3).z, (push.l_ball as Vector3).z)
		print("METRIC tech_wall palms_off_wall_m %.3f balls_off_wall_m %.4f hips_from_wall_m %.3f f5_palms_off_m %.3f f5_balls_off_m %.4f"
				% [off, sole, wz - (hips.pelvis as Vector3).z, palm_off, ball_off])
		_check(wz > 0.3, "tech-wall: names its wall (wall_z %.2f)" % wz)
		_check(off < 0.05, "tech-wall: the palms flat on the wall while stuck (%.3f m)" % off)
		_check(sole <= IK_MISS, "tech-wall: the balls of the feet on the wall while stuck (%.4f m)" % sole)
		_check(palm_off > 0.08 and absf(ball_off) <= IK_MISS, "tech-wall: the palms push off first, the soles a frame later (f5: palms %.2f m off, balls %.4f m)"
				% [palm_off, ball_off])
	if lie != null:
		var worst := 0.0
		var head := 0.0
		# (pass 2: the parts he lies on, the back, the head and the flung right palm, touching the deck within 5 mm at
		# every frame; the rest of the body never more than 1.2 cm into it (SURF's round thighs are a rough model))
		var contact := 0.0
		var crange := Vector2(INF, -INF)
		for i in 41:
			_joints(lie, lie.length * i / 40.0)
			worst = maxf(worst, absf(_surface_low()))
			head = maxf(head, sk.get_bone_global_pose(sk.find_bone("heada")).origin.y)
			var c := _surface_low_of(LIE_CONTACT)
			contact = maxf(contact, absf(c))
			crange = Vector2(minf(crange.x, c), maxf(crange.y, c))
		var kx := Vector2(INF, -INF)
		# (pass 2's last fix: the raised thigh lies back at a slant, the knee ahead of the seat and not stood straight up
		# over it, where the period coat's skirt stood beside the shin as a slab)
		var knee_high := 0.0
		var knee_ahead := INF
		for i in 41:
			var j := _at(lie, lie.length * i / 40.0, ["r_knee", "pelvis"])
			kx = Vector2(minf(kx.x, (j.r_knee as Vector3).x), maxf(kx.y, (j.r_knee as Vector3).x))
			knee_high = maxf(knee_high, (j.r_knee as Vector3).y)
			knee_ahead = minf(knee_ahead, (j.r_knee as Vector3).z - (j.pelvis as Vector3).z)
		print("METRIC lie knee_high_m %.3f knee_ahead_of_seat_m %.3f" % [knee_high, knee_ahead])
		_check(knee_high < 0.4 and knee_ahead > 0.12, "lie: the raised thigh lies back at a slant (the knee %.2f m up, %.2f m ahead of the seat)"
				% [knee_high, knee_ahead])
		print("METRIC lie surface_off_deck_m %.4f contact_off_deck_m %.4f (%.4f..%.4f) head_y_m %.3f knee_sway_m %.3f"
				% [worst, contact, crange.x, crange.y, head, kx.y - kx.x])
		_check(contact <= 0.005, "lie: the back, the head and the flung palm on the deck (within %.4f m of it)" % contact)
		_check(worst <= 0.012, "lie: lying on the deck (its lowest surface within %.4f m of it)" % worst)
		_check(kx.y - kx.x > 0.1, "lie: the raised knee sways so the daze reads (%.2f m)" % (kx.y - kx.x))
		_check(head < 0.3, "lie: flat on his back (the head %.2f m up)" % head)
	if "own-bend-knock-bounce" in names and lie != null:
		var a := lib.get_animation(&"own-bend-knock-bounce")
		var d := _off(_joints(a, a.length), _joints(lie, 0.0))
		_check(d < 0.01, "knock-bounce: ends on the lie's first pose (off by %.4f m)" % d)
		var p0 := _at(a, float(a.get_meta(&"strike_s")), ["pelvis"])
		var up := 0.0
		for i in 13:
			var j := _at(a, float(a.get_meta(&"strike_s")) + (float(a.get_meta(&"back_s")) - float(a.get_meta(&"strike_s"))) * i / 12.0, ["pelvis"])
			up = maxf(up, (j.pelvis as Vector3).y - (p0.pelvis as Vector3).y)
		# (pass 2: the whole back lifted flat off the deck, not a V-sit: the shoulders up with the pelvis)
		var pk := _at(a, 6.0 / 30.0, ["pelvis", "r_shoulder", "l_shoulder"])
		var sh := ((pk.r_shoulder as Vector3).y + (pk.l_shoulder as Vector3).y) * 0.5
		print("METRIC knock_bounce lift_m %.3f peak_shoulders_y_m %.3f peak_pelvis_y_m %.3f" % [up, sh, (pk.pelvis as Vector3).y])
		_check(up > 0.12, "knock-bounce: bounces up off the deck (%.2f m)" % up)
		_check(sh - 0.07 > 0.2, "knock-bounce: the shoulders lifted off the deck too (%.2f m)" % sh)
		_check(sh - (pk.pelvis as Vector3).y < 0.15, "knock-bounce: flat, not folded into a V (the shoulders %.2f m over the hips)"
				% (sh - (pk.pelvis as Vector3).y))
	if "own-bend-getup" in names:
		# (pass 2: the coil's feet piked over beyond the head; the arch its own frame, the hips at their highest)
		var a := lib.get_animation(&"own-bend-getup")
		var c := _at(a, float(a.get_meta(&"hold_s")), ["r_ankle", "l_ankle", "heada"])
		var beyond := (c.heada as Vector3).z - maxf((c.r_ankle as Vector3).z, (c.l_ankle as Vector3).z)
		var arch := _at(a, 6.0 / 30.0, ["pelvis"])
		print("METRIC getup coil_feet_past_head_m %.3f arch_pelvis_y_m %.3f" % [beyond, (arch.pelvis as Vector3).y])
		_check(beyond > 0.05, "getup: the coil's feet piked over beyond the head (%.2f m)" % beyond)
		_check((arch.pelvis as Vector3).y > 0.35, "getup: the arch with the hips high (%.2f m)" % (arch.pelvis as Vector3).y)
	for x: String in ["own-bend-getup-roll", "own-bend-getup-roll-l"]:
		if not x in names:
			continue
		# (pass 2: two whole log rolls, for the code's 2.5 m: the line across the shoulders turned about the roll's axis)
		var a := lib.get_animation(StringName(x))
		var turned := 0.0
		var prev := 0.0
		for i in 27:
			var j := _at(a, i / 30.0, ["r_shoulder", "l_shoulder"])
			var v := (j.l_shoulder as Vector3) - (j.r_shoulder as Vector3)
			var ang := atan2(v.y, v.x)
			if i > 0:
				turned += wrapf(ang - prev, -PI, PI)
			prev = ang
		print("METRIC %s log_roll_turns %.2f" % [x, absf(turned) / TAU])
		_check(absf(turned) / TAU > 1.8 and absf(turned) / TAU < 2.2, "%s: two whole log rolls (%.2f turns)" % [x, absf(turned) / TAU])
	if "own-bend-getup-attack" in names:
		var a := lib.get_animation(&"own-bend-getup-attack")
		var hp := 0.0
		for i in range(4, 11):
			hp = maxf(hp, (_at(a, i / 30.0, ["pelvis"]).pelvis as Vector3).y)
		var lo := INF
		for i in range(4, 11):
			lo = minf(lo, (_at(a, i / 30.0, ["pelvis"]).pelvis as Vector3).y)
		print("METRIC getup_attack crab_hips_y_m %.3f..%.3f" % [lo, hp])
		_check(lo > 0.3, "getup-attack: the hips lifted off the deck in the crab through the sweep (%.2f m)" % lo)
		var j := _at(a, float(a.get_meta(&"strike_s")), ["r_ankle", "pelvis"])
		var reach := Vector2((j.r_ankle as Vector3).x - (j.pelvis as Vector3).x, (j.r_ankle as Vector3).z - (j.pelvis as Vector3).z).length()
		print("METRIC getup_attack sweep_ankle_y_m %.3f reach_m %.2f" % [(j.r_ankle as Vector3).y, reach])
		_check((j.r_ankle as Vector3).y < 0.16, "getup-attack: the sweep low along the deck (%.3f m)" % (j.r_ankle as Vector3).y)
		_check(reach > 0.55, "getup-attack: the leg swept out wide (%.2f m from the hips)" % reach)
	if "own-bend-knock-spiked" in names:
		var a := lib.get_animation(&"own-bend-knock-spiked")
		var j := _at(a, (float(a.get_meta(&"hold_s")) + float(a.get_meta(&"back_s"))) * 0.5, ["l_palm", "r_palm", "heada", "l_ankle", "r_ankle", "pelvis"])
		var over := minf((j.l_palm as Vector3).y, (j.r_palm as Vector3).y) - (j.heada as Vector3).y
		var dive := (j.heada as Vector3).z - (j.pelvis as Vector3).z
		# (pass 2: a feet-first plunge, one straight vertical line: the head over the hips, the feet straight under them)
		var under := (j.pelvis as Vector3).y - ((j.l_ankle as Vector3).y + (j.r_ankle as Vector3).y) * 0.5
		var fold := _at(a, 2.0 / 30.0, ["heada", "pelvis"])
		var bowed := (fold.heada as Vector3).y - (fold.pelvis as Vector3).y
		print("METRIC knock_spiked palms_over_head_m %.3f head_ahead_of_hips_m %.3f feet_under_hips_m %.3f fold_head_over_hips_m %.3f"
				% [over, dive, under, bowed])
		_check(over > 0.25, "knock-spiked: the arms dragged straight up over the head (%.2f m)" % over)
		_check(absf(dive) < 0.15, "knock-spiked: a straight vertical plunge (the head %.2f m off over the hips)" % dive)
		_check(under > 0.6, "knock-spiked: the legs straight under him (the ankles %.2f m under the hips)" % under)
		_check(bowed < 0.3, "knock-spiked: the hit folds him over first (the head %.2f m over the hips)" % bowed)

## A joint's bend in degrees (0 straight) from three bones' places.
func _bend(j: Dictionary, a: String, b: String, c: String) -> float:
	return rad_to_deg(((j[b] as Vector3) - (j[a] as Vector3)).angle_to((j[c] as Vector3) - (j[b] as Vector3)))


## Bones' skeleton-space places with the clip's keyed bones set at t (the rest elsewhere).
func _at(a: Animation, t: float, bones: Array) -> Dictionary:
	_joints(a, t)
	var out := {}
	for k: String in bones:
		out[k] = sk.get_bone_global_pose(sk.find_bone(k)).origin
	return out


## A stance: a seamless loop, whole, the feet planted, the sway subtle.
func _stance(nm: String, a: Animation) -> void:
	_check(a.loop_mode == Animation.LOOP_LINEAR, "%s: loops" % nm)
	_check(String(a.get_meta(&"mask", "")) == "full", "%s: mask full" % nm)
	var j0 := _joints(a, 0.0)
	var j1 := _joints(a, a.length)
	var seam := 0.0
	for k: String in JOINTS:
		seam = maxf(seam, (j0[k] as Vector3).distance_to(j1[k]))
	_check(seam < 0.005, "%s: the loop's seam (%.4f m)" % [nm, seam])
	var feet := 0.0
	var sway := 0.0
	var tr := -1
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D and String(a.track_get_path(i).get_concatenated_subnames()) == "root":
			tr = i
	var r0 := a.position_track_interpolate(tr, 0.0) if tr >= 0 else Vector3.ZERO
	for i in 24:
		var t := a.length * i / 24.0
		var j := _joints(a, t)
		for k: String in ["l_ankle", "r_ankle"]:
			feet = maxf(feet, (j[k] as Vector3).distance_to(j0[k]))
		if tr >= 0:
			sway = maxf(sway, a.position_track_interpolate(tr, t).distance_to(r0))
	_check(feet < 0.015, "%s: the feet planted through the loop (no gait: %.4f m)" % [nm, feet])
	_check(sway < 0.06, "%s: the sway subtle (the root within %.3f m)" % [nm, sway])
	_check(not a.has_meta(&"strike_s"), "%s: no strike (an idle, not a cast)" % nm)


## The boulder: the left foot kicked up off the ground before the hold and planted at it; both palms out ahead at the strike.
func _boulder(a: Animation) -> void:
	var hold := float(a.get_meta(&"hold_s", 0.0))
	var strike := float(a.get_meta(&"strike_s", 0.0))
	var start := _joints(a, 0.0)
	var top := 0.0
	for i in 20:
		var j := _joints(a, hold * i / 20.0)
		top = maxf(top, (j.l_ankle as Vector3).y - (start.l_ankle as Vector3).y)
	var at_hold := _joints(a, hold)
	var at_strike := _joints(a, strike)
	_check(top > 0.25, "boulder: the left foot kicks up before the hold (%.2f m off the ground)" % top)
	_check(absf((at_hold.l_ankle as Vector3).y - (start.l_ankle as Vector3).y) < 0.02, "boulder: the left foot stamped down by the hold")
	# (the skeleton's +Z the body's forward: the palms out ahead of the stand's by 0.4 m or more)
	var ahead := minf((at_strike.l_palm as Vector3).z - (start.l_palm as Vector3).z, (at_strike.r_palm as Vector3).z - (start.r_palm as Vector3).z)
	_check(ahead > 0.4, "boulder: both palms pushed out ahead at the strike (%.2f m)" % ahead)
	_check(String(a.get_meta(&"hand", "")) == "both", "boulder: the strike from both hands")


## The low kick against the High Kick: the low one's sole skims the deck at its strike (its ankle's lift over its stand, the
## sole's height when the foot is flat) and its hold's foot is low (the chamber the opponent reads); the high one's foot is up
## at the waist at its strike.
func _low_kick(low: Animation, high: Animation) -> void:
	var deck := _bone(low, 0.0, "r_ankle").y          # (the ankle's height on the stand: the sole on the deck)
	var sole := _bone(low, float(low.get_meta(&"strike_s")), "r_ankle").y - deck
	var hold := _bone(low, float(low.get_meta(&"hold_s")), "r_ankle").y - deck
	var high_foot := _bone(high, float(high.get_meta(&"strike_s")), "r_ankle").y
	print("BEND_CLIPS low kick: its sole %.3f m over the deck at the strike, %.3f m at the hold; the High Kick's ankle %.3f m up"
			% [sole, hold, high_foot])
	_check(sole < 0.35, "low kick: the sole at the strike %.3f m over the deck (< 0.35)" % sole)
	_check(hold < 0.2, "low kick: the foot at the hold %.3f m over the deck (< 0.2: the low chamber)" % hold)
	_check(high_foot > 0.5, "High Kick: the foot at the strike %.3f m up (> 0.5)" % high_foot)
	_check(high_foot - deck - sole > 0.35, "the two kicks' strikes %.2f m apart in height" % (high_foot - deck - sole))


## A bone's skeleton-space place with the clip's keyed bones set at t (the rest elsewhere).
func _bone(a: Animation, t: float, bone: String) -> Vector3:
	_joints(a, t)
	return sk.get_bone_global_pose(sk.find_bone(bone)).origin


## How far the arm (or the leg) whose tip is `tip` (l_palm, r_palm) is short of straight at t: its reach (upper + lower) less
## the shoulder-to-wrist distance (m; > 0 bent).
func _reach(a: Animation, t: float, tip: String) -> float:
	_joints(a, t)
	var side := tip.substr(0, 2)
	var ids := [sk.find_bone(side + "shoulder"), sk.find_bone(side + "elbow"), sk.find_bone(side + "wrist")]
	var rest := [] as Array[Vector3]
	var now := [] as Array[Vector3]
	for b: int in ids:
		rest.append(sk.get_bone_global_rest(b).origin)
		now.append(sk.get_bone_global_pose(b).origin)
	return rest[0].distance_to(rest[1]) + rest[1].distance_to(rest[2]) - now[0].distance_to(now[2]) - 0.002


func _place(nm: String, a: Animation) -> void:
	var tr := -1
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D and String(a.track_get_path(i).get_concatenated_subnames()) == "root":
			tr = i
	_check(tr >= 0, "%s: keys the root's place" % nm)
	if tr < 0 or nm in MOVED_STANCE:
		return
	var d := a.position_track_interpolate(tr, 0.0).distance_to(a.position_track_interpolate(tr, a.length))
	_check(d < 0.03, "%s: the root back within 3 cm (%.3f m)" % [nm, d])


## The joints' skeleton-space places with the clip's keyed bones set at t (the rest elsewhere).
func _joints(a: Animation, t: float) -> Dictionary:
	sk.reset_bone_poses()
	for i in a.get_track_count():
		var b := sk.find_bone(String(a.track_get_path(i).get_concatenated_subnames()))
		if b < 0:
			continue
		match a.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(b, a.rotation_track_interpolate(i, t))
			Animation.TYPE_POSITION_3D:
				sk.set_bone_pose_position(b, a.position_track_interpolate(i, t))
	var out := {}
	for k: String in JOINTS:
		out[k] = sk.get_bone_global_pose(sk.find_bone(k)).origin
	return out


## The own-bend-* names in SOURCE.md's Frontier_Bend.res section (its table's rows).
func _table_names(md: String) -> Array[String]:
	var out: Array[String] = []
	var inside := false
	var re := RegEx.create_from_string("`(own-bend-[a-z0-9-]+)`")
	for line in md.split("\n"):
		if line.begins_with("## "):
			inside = line.contains("Frontier_Bend.res")
			continue
		if inside and line.begins_with("|"):
			for m in re.search_all(line):
				out.append(m.get_string(1))
	return out


func _end() -> void:
	if fails.is_empty():
		print("BEND_CLIPS: %d checks" % checks)
		print("BEND_CLIPS PASSED")
		quit(0)
	else:
		print("BEND_CLIPS: %d of %d checks failed" % [fails.size(), checks])
		print("BEND_CLIPS FAILED")
		quit(1)
