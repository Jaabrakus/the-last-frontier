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
## Ends with "BEND_CLIPS PASSED" or "BEND_CLIPS FAILED" (exit 0 only on a pass; a watchdog quits 2 at LIMIT s).

const LIB := "res://animations_extra/Frontier_Bend.res"
const GLB := "res://assets/character/actor_b_body.glb"
const SOURCE_MD := "res://animations/SOURCE.md"
const LIMIT := 60.0
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
		if FOURTH_SET.has(nm) or _fifth_has(nm):
			continue                                # (its own checks: _fourth, _fifth)
		if a.has_meta(&"loop"):
			_stance(nm, a)
			continue
		_moments(nm, a)
		_place(nm, a)
	# a common stand at both ends (the casts and the knocks; a stance is its own)
	var casts := names.filter(func(x: String) -> bool: return not (lib.get_animation(StringName(x)).has_meta(&"loop")
			or FOURTH_SET.has(x) or _fifth_has(x)))
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
		for k: String in ["l_palm", "r_palm", "l_ball", "r_ball", "l_ankle", "r_ankle"]:
			slide = maxf(slide, (j[k] as Vector3).distance_to(h0[k]))
		for s in ["l_", "r_"]:
			face = maxf(face, absf((j[s + "ball"] as Vector3).z + 0.06 - lip_z))
			feet_under = maxf(feet_under, (j[s + "ball"] as Vector3).y - lip_y)
	print("METRIC edge_hang_hands_over_lip_m %.3f head_over_lip_m %.3f hands_feet_slide_m %.4f toes_off_face_m %.3f"
			% [low_hand, low_head, slide, face])
	_check(low_hand > 0.0, "edge hang: both hands over the lip at every frame (the lowest %.3f m over)" % low_hand)
	_check(low_head > 0.15, "edge hang: the head clearly over the lip at every frame (the lowest %.3f m over)" % low_head)
	_check(slide < 0.01, "edge hang: the hands and the feet hold the stone (they move %.4f m)" % slide)
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
		for i in 7:
			var j := _at(g, gs + (g.length - gs) * i / 6.0, all)
			for k: String in ["l_palm", "r_palm"]:
				planted = maxf(planted, (j[k] as Vector3).distance_to(h0[k]))
		print("METRIC edge_grab_feet_out_m %.3f hands_planted_m %.4f end_off_m %.4f" % [out, planted, worst])
		_check(worst < 0.01, "edge grab: ends on the hang's first pose (off by %.4f m)" % worst)
		_check(out > 0.45, "edge grab: the legs swing in from out off the face (the ankles %.2f m out at the start)" % out)
		_check(planted < 0.01, "edge grab: the hands caught on the deck from the strike (%.4f m)" % planted)
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
	# the duck: the head down 0.4 m or more and back behind the hips at the lowest, the feet planted through it
	if "own-bend-duck" in names:
		var d := lib.get_animation(&"own-bend-duck")
		var d0 := _at(d, 0.0, all)
		var js := _at(d, float(d.get_meta(&"strike_s", 0.0)), all)
		var drop := (d0.heada as Vector3).y - (js.heada as Vector3).y
		var lean := (js.pelvis as Vector3).z - (js.heada as Vector3).z
		var feet := 0.0
		for i in 15:
			var j := _at(d, d.length * i / 14.0, all)
			for k: String in ["l_ankle", "r_ankle", "l_ball", "r_ball"]:
				feet = maxf(feet, (j[k] as Vector3).distance_to(d0[k]))
		print("METRIC duck_head_drop_m %.3f lean_back_m %.3f feet_m %.4f" % [drop, lean, feet])
		_check(drop > 0.4, "duck: the head down %.2f m at the lowest" % drop)
		_check(lean > 0.02, "duck: swayed back (the head %.2f m behind the hips)" % lean)
		_check(feet < 0.01, "duck: the feet planted (%.4f m)" % feet)


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
