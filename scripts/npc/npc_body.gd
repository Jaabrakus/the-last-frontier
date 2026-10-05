class_name NpcBody
extends Node3D
## A fighter's body (NpcFighter): Actor_B dressed from a look (a peoples preset in a faction's garments: NpcFactions.look_for;
## PlayerAppearance.dress, as the player and the household), played by an AnimationPlayer of its own few clips, not the
## player's animation tree (about 2 ms a frame each: docs/multiplayer_readiness.md): walk, run, crouch, the rifle aim, the
## rifle reload (the source clips' upper-body parts over the stance held), the hit reactions, the deaths, our own axe and
## club swings, a bender's cast poses (play_cast: data/bending/poses.json's own clips, its strike timed to the launch). A
## second player lays an arms pose over the walk (the musket carried as the player carries it: his relaxed
## overlay, actor_b-p-rifle-run-arms). The musket goes to the shoulder and on the target by HuntAim, as a household hunter's.
##
## LEVEL OF DETAIL, as the animals' (WildAnimal._step_anim): the clips advance every `anim_step` (0 every frame; NpcSenses sets
## it by distance from WildlifeSpawner.anim_step_at, and coarser for the fighters past NpcSenses.MAX_ANIMATED), every
## OFFSCREEN_S out of the camera's view, never while `animate` is off (past NpcSenses.VISIBLE_M, or settled dead); the pose is
## the same when it updates (advanced by all the time since). The body's own bone drivers (CharacterBodyMesh) run only while it
## is animated close by. A skeleton with modifiers (the aim, the drivers) is otherwise updated every frame whether its pose
## changed or not: stepped less often than every frame, its modifiers are run by hand at each step (Skeleton3D's manual
## modifier mode), so a far or frozen body costs nothing between its steps. Settled dead it rests (rest(): nothing runs).
##
## HIT PARTS: a torso along the spine and a head on the head bone (StaticBody3D on WildAnimal.HIT_LAYER, which only shots and
## blows see; meta hit_part, damage_mult, surface "flesh"), placed from the bones each time the pose updates. Hit.deliver finds
## the fighter's apply_hit above them. What sticks in them (an arrow, a thrown weapon: ThrownProjectile.stuck_parent) rides on
## the nearest trunk or head bone (stuck_anchor, as WildAnimal's), not on the part, which goes when he dies. Faces -Z (the model
## turned round, as the spouse's).

const SCENE := "res://characters/Actor_B.tscn"
const BODY := "res://assets/character/actor_b_body.glb"
const OWN_PATH := "res://animations_extra/Frontier_Own.res"
const ACTOR_LIB := "res://animations/Actor_B.res"
## The library the clips are played from (only these: a small track cache per body).
const LIB := "npc"
const PROP := "r_hand_prop_attachment"
## Off-screen the pose updates this often (s), as the animals'.
const OFFSCREEN_S := 0.25
## The clips by what they are for; [name, looped].
const CLIPS := {
	"idle": ["actor_b-p-relax-idle", true],
	"walk": ["actor_b-p-walk-fw", true],
	"run": ["actor_b-p-run-fw", true],
	"crouch": ["actor_b-p-crouch-idle", true],
	"crouch_walk": ["actor_b-p-crouch-walk-fw", true],
	"aim": ["actor_b-p-rifle-idle-aim", true],
	"aim_crouch": ["actor_b-p-rifle-aim-crouch-idle", true],
	"aim_walk": ["actor_b-p-rifle-aim-walk-fw", true],
	"aim_crouch_walk": ["actor_b-p-rifle-aim-crouch-walk-fw", true],
	# the aimed side-steps and the step back (a peek out past cover and back: NpcSkirmish, NpcFighter.face_lock), the dash
	# between covers in the foe's sight (NpcFighter.SPRINT_SPEED); the user, 2026-10-04: "npc can find cover aim and etc"
	"aim_walk_lt": ["actor_b-p-rifle-aim-walk-fw-lt", true],
	"aim_walk_rt": ["actor_b-p-rifle-aim-walk-fw-rt", true],
	"aim_walk_bw": ["actor_b-p-rifle-aim-walk-bw", true],
	"aim_crouch_walk_lt": ["actor_b-p-rifle-aim-crouch-walk-fw-lt", true],
	"aim_crouch_walk_rt": ["actor_b-p-rifle-aim-crouch-walk-fw-rt", true],
	"aim_crouch_walk_bw": ["actor_b-p-rifle-aim-crouch-walk-bw", true],
	"sprint": ["actor_b-p-sprint-fw", true],
	"look": ["actor_b-cap-explore-look-right-loop", true],
	"reload_begin": ["actor_b-p-rifle-idle-aim-reload-begin--part", false],
	"reload_mid": ["actor_b-p-rifle-idle-aim-reload-mid--part", true],
	"reload_end": ["actor_b-p-rifle-idle-aim-reload-over--part", false],
	"reload_begin_crouch": ["actor_b-p-rifle-idle-crouch-aim-reload-begin--part", false],
	"reload_mid_crouch": ["actor_b-p-rifle-idle-crouch-aim-reload-mid--part", true],
	"reload_end_crouch": ["actor_b-p-rifle-idle-crouch-aim-reload-over--part", false],
	"hit_fw": ["actor_b-p-hr-fw", false],
	"hit_bw": ["actor_b-p-hr-bw", false],
	"hit_lt": ["actor_b-p-hr-lt", false],
	"hit_rt": ["actor_b-p-hr-rt", false],
	"hit_crouch_fw": ["actor_b-p-crouch-hr-fw", false],
	"hit_crouch_bw": ["actor_b-p-crouch-hr-bw", false],
	"hit_crouch_lt": ["actor_b-p-crouch-hr-lt", false],
	"hit_crouch_rt": ["actor_b-p-crouch-hr-rt", false],
	"death_back": ["actor_b-p-death-back", false],
	"death_front": ["actor_b-p-death-front", false],
	"death_crouch": ["actor_b-p-death-crouch-generic", false],
}
## Our own swings (animations_extra/Frontier_Own.res; data/melee/felling_axe.json "D"; the club's stab for the musket's butt).
const OWN_CLIPS := {
	"axe_intro": ["own-axe-d-intro", false],
	"axe": ["own-axe-d", false],
	"club_intro": ["own-club-stab-intro", false],
	"club": ["own-club-stab", false],
}
## A bender's casts (NpcBending: the player's own Sway push, animations_extra/Frontier_Form.res, SwayPose).
const FORM_PATH := "res://animations_extra/Frontier_Form.res"
const FORM_CLIPS := {
	"cast_push": ["own-sway-push-two", false],
}
## A bender's per-move casts (play_cast): every clip data/bending/poses.json names (BendPoses.all_clips: our own libraries
## only), in the library under its own name, played whole from its start at the rate that brings its strike to the bot's
## launch. The clip a cast plays now, its pick ({} the plain push) and its strike's moment in the clip (s; -1 none).
var cast_clip := ""
var cast_pick := {}
var cast_strike_s := -1.0
## A pose with an "alt" (data/bending/poses.json: the next hand, a throw's or a punch's mirrored twin) takes it every other
## cast of the same move and variation: left, right, left (the player's SwayPose chains them within a combo window).
## THE STANCE: an element bot's "idle" plays its element's own stance loop (poses.json "stance": own-bend-stance-<element>,
## in the library looped as "stance_<element>"); clip still reads "idle". Only while he fights: held (the countdown, a round
## over, a test's held target) he stands at the plain idle. The stance is his body as it is (the earth's horse sinks him
## 0.12 m): the hit parts and the shot's path through him follow it.
const STANCE_PREFIX := "stance_"
## The own knock reactions (play_knock): braced, sliding back on its feet; launched off them. Played while the knock lasts
## (BendKnock: its window, or until it lands), held on the clip's hold_s meanwhile.
const KNOCK_PREFIX := "own-bend-knock"
const KNOCK_SLIDE := "own-bend-knock-slide"
const KNOCK_AIR := "own-bend-knock-air"
## The own clips' strike limb (their meta "hand") as strike_point reads it.
const HANDS := {"r": "r_palm", "l": "l_palm", "both": "both", "foot_r": "r_foot", "foot_l": "l_foot"}
var _alt := {}
## The library clip "idle" plays now (its element's stance, else the idle).
var _played := ""
## A knock clip's hold (s into it; -1 none): it stops there while the knock lasts, then plays out.
var _knock_hold := -1.0
## Arms poses over the stance (the player's relaxed long-gun overlay: Musket.relaxed).
const ARMS := {
	"carry": "actor_b-p-rifle-run-arms",
	"carry_crouch": "actor_b-p-rifle-crouch-run-arms",
	"carry_crouch_idle": "actor_b-p-rifle-crouch-idle-arms",
}
## The bones what sticks in him rides on (stuck_anchor): the trunk's and the head's.
const STUCK_BONES := ["pelvis", "spineb", "spinec", "spined", "neck", "heada"]
## The hand props (the bones the musket and the axe ride on, and HuntAim lays the musket's line by): only the reload clips'
## upper-body parts key them, and the clips are blended keeping what a clip does not key (the stance held under a part), so
## after a reload they are put back as the body was built, over PROPS_BACK_S while the next clip blends in (2026-10-04, seen
## in the duel: else the musket lay where the ramming left it, 0.3 m low in the hands, its shot into the wall it peeked over).
const PROP_BONES := ["r_hand_prop_attachment", "l_hand_prop_attachment"]
const PROPS_BACK_S := 0.45

static var _lib: AnimationLibrary
static var _arms_lib: AnimationLibrary
static var _keys_props_cache := {}

var sk: Skeleton3D
var ap: AnimationPlayer
var arms_ap: AnimationPlayer
var aim: HuntAim
var mesh: CharacterBodyMesh
## The right hand's prop socket (the musket, the axe).
var hand: BoneAttachment3D
## The clips advance (false: frozen by the budget, or settled dead).
var animate := true
## Seconds between pose updates (0: every frame).
var anim_step := 0.0
## The clip playing (a CLIPS key) and the arms pose over it ("" none).
var clip := ""
var arms := ""
## How many pose updates it has made (the budget's test reads it).
var steps := 0
## The hand props' pose as built ([bone, position, rotation]), a reload clip played since they were last put back, and how
## long they are still put back (PROP_BONES).
var _props: Array = []
var _props_moved := false
var _props_t := 0.0
var torso: StaticBody3D
var head: StaticBody3D
var _model: Node3D
var _acc := 0.0
var _hold := Transform3D.IDENTITY
## The skeleton's modifiers run by hand at each step (stepped less often than every frame), not every frame.
var _manual := false


## Builds the body in `look` (call once it is in the tree).
func build(look: Dictionary) -> void:
	var scene := BackgroundLoad.take(SCENE) as PackedScene
	_model = scene.instantiate() as Node3D
	_model.rotation.y = PI
	add_child(_model)
	sk = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	ap = aps[0] as AnimationPlayer if not aps.is_empty() else null
	mesh = CharacterBodyMesh.attach(sk, ap, BODY)
	if mesh:
		PlayerAppearance.dress(mesh, AppearanceStore.validate(look))
	# the aim turns the spine before the body's own drivers follow it (modifiers run in the skeleton's child order)
	aim = HuntAim.attach(sk)
	if mesh:
		sk.move_child(aim, mesh.get_index())
	hand = BoneAttachment3D.new()
	hand.bone_name = PROP
	sk.add_child(hand)
	if ap:
		# only the clips it plays (the full library is 964 clips: its track cache, for every body)
		for l in ap.get_animation_library_list():
			ap.remove_animation_library(l)
		ap.add_animation_library(LIB, library())
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		ap.deterministic = false
		arms_ap = AnimationPlayer.new()
		arms_ap.name = "ArmsPlayer"
		ap.get_parent().add_child(arms_ap)
		arms_ap.root_node = ap.root_node
		arms_ap.deterministic = false
		arms_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		arms_ap.add_animation_library(LIB, arms_library())
	torso = _part("body", 1.0, _capsule(0.2, 0.62))
	head = _part("head", 2.5, _sphere(0.13))
	play("idle", 0.0)
	_step(0.0)
	for nm: String in PROP_BONES:
		var bi := sk.find_bone(nm)
		if bi >= 0:
			_props.append([bi, sk.get_bone_pose_position(bi), sk.get_bone_pose_rotation(bi)])


## The clips the bodies share (built once): Actor_B's and our own swings, each looped or not as CLIPS has it (a copy where the
## library's own differs, so the player's are never changed).
static func library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	var src := load(ACTOR_LIB) as AnimationLibrary
	var own := load(OWN_PATH) as AnimationLibrary
	var form := load(FORM_PATH) as AnimationLibrary
	for key: String in CLIPS:
		_add(_lib, src, key, CLIPS[key])
	for key: String in OWN_CLIPS:
		_add(_lib, own, key, OWN_CLIPS[key])
	for key: String in FORM_CLIPS:
		_add(_lib, form, key, FORM_CLIPS[key])
	for nm: String in BendPoses.all_clips():
		_add_pose(nm)
	# each element's stance, looped, for an element bot's idle
	var stances: Dictionary = BendPoses.data().get("stance", {})
	for el: String in stances:
		var snm := String(BendPoses._as_pose(stances[el]).get("clip", ""))
		if snm != "" and BendPoses.usable(snm):
			var sa := BendPoses.animation(snm)
			if sa.loop_mode != Animation.LOOP_LINEAR:
				sa = sa.duplicate() as Animation
				sa.loop_mode = Animation.LOOP_LINEAR
			_lib.add_animation(STANCE_PREFIX + el, sa)
	return _lib


## Pose clip `nm` (BendPoses: ours, not excluded) into the shared library under its own name; false when it cannot be.
static func _add_pose(nm: String) -> bool:
	if _lib == null or nm == "" or not BendPoses.usable(nm):
		return false
	if _lib.has_animation(nm):
		return true
	var a := BendPoses.animation(nm)
	if a.loop_mode != Animation.LOOP_NONE:
		a = a.duplicate() as Animation
		a.loop_mode = Animation.LOOP_NONE
	return _lib.add_animation(nm, a) == OK


static func arms_library() -> AnimationLibrary:
	if _arms_lib != null:
		return _arms_lib
	_arms_lib = AnimationLibrary.new()
	var src := load(ACTOR_LIB) as AnimationLibrary
	for key: String in ARMS:
		if src != null and src.has_animation(ARMS[key]):
			_arms_lib.add_animation(key, src.get_animation(ARMS[key]))
	return _arms_lib


static func _add(lib: AnimationLibrary, src: AnimationLibrary, key: String, spec: Array) -> void:
	if src == null or not src.has_animation(String(spec[0])):
		return
	var a := src.get_animation(String(spec[0]))
	var want := Animation.LOOP_LINEAR if bool(spec[1]) else Animation.LOOP_NONE
	if a.loop_mode != want:
		a = a.duplicate() as Animation
		a.loop_mode = want
	lib.add_animation(key, a)


func has_clip(key: String) -> bool:
	return ap != null and ap.has_animation(LIB + "/" + key)


func clip_length(key: String) -> float:
	return ap.get_animation(LIB + "/" + key).length if has_clip(key) else 0.0


## Plays clip `key` (blended in over `blend` s) at `speed`; the same clip again only takes the new speed.
func play(key: String, blend := 0.2, speed := 1.0) -> void:
	var real := _stance_key() if key == "idle" else key
	if not has_clip(real):
		real = key
	if not has_clip(real):
		return
	ap.speed_scale = speed
	if clip == key and _played == real:
		return
	clip = key
	_played = real
	_props_after(real)
	ap.play(LIB + "/" + real, blend)


## The stance an element bot idles in ("" none: not a bender, or no stance clip): its fighter's own element's.
func _stance_key() -> String:
	var f := get_parent()
	var e: Variant = f.get(&"element") if f != null else null
	if not (e is String or e is StringName) or String(e) == "" or f.get(&"held") == true:
		return ""
	var k := STANCE_PREFIX + String(e)
	return k if has_clip(k) else ""


## Plays one-shot clip `key` from its start (a flinch, a swing, a death); returns its length (0: no such clip).
func play_once(key: String, blend := 0.1, speed := 1.0) -> float:
	if not has_clip(key):
		return 0.0
	ap.speed_scale = speed
	clip = key
	_played = key
	_props_after(key)
	ap.play(LIB + "/" + key, blend)
	ap.seek(0.0, false)
	return clip_length(key) / maxf(speed, 0.01)


## A bender's cast of `move` in `mode` (NpcBending; the user, 2026-10-04: an element bot casts the player's moves): the clip
## its element's pose names (BendPoses.pick: the fighter's own element by default, `element` to say it), else "cast_push",
## played from its start at the rate that brings its strike (BendPoses.body_strike_s: the pose's strike_s, a floor cast's
## press_s, else the clip's push_s) to `wind_s` from now, so the hands strike as the bot launches. Returns that rate (0:
## nothing played). Also takes the order (move, mode, element, wind_s).
func play_cast(move: String, mode: String, wind_s: Variant = 0.8, element: Variant = "") -> float:
	var wind: Variant = wind_s
	var el: Variant = element
	if wind_s is String or wind_s is StringName:
		el = wind_s
		wind = element if element is float or element is int else 0.8
	var e := String(el) if el is String or el is StringName else ""
	if e == "":
		e = BendPoses.element_of(get_parent())
	var pk := _pick_turn(move, mode, e) if e != "" else {}
	var key := "cast_push"
	var strike := -1.0
	if not pk.is_empty() and (has_clip(String(pk.clip)) or (_add_pose(String(pk.clip)) and has_clip(String(pk.clip)))):
		key = String(pk.clip)
		strike = BendPoses.body_strike_s(pk)
	else:
		pk = {}
	if not has_clip(key):
		cast_clip = ""
		cast_pick = {}
		cast_strike_s = -1.0
		return 0.0
	var a := ap.get_animation(LIB + "/" + key)
	if strike < 0.0:
		strike = float(a.get_meta(&"strike_s", a.get_meta(&"push_s", a.length * 0.5)))
	var rate := clampf(strike / maxf(float(wind), 0.01), 0.05, 20.0)
	cast_clip = key
	cast_pick = pk
	cast_strike_s = strike
	play_once(key, 0.1, rate)
	return rate


## The pose for (move, mode) as an `element` caster (BendPoses.pick), its alt every other cast (the right hand, then the
## left, in turn); {} none. A limb named the clips' way (r, l, both, foot_r) is put the game's way (HANDS).
func _pick_turn(move: String, mode: String, element: String) -> Dictionary:
	var pk := BendPoses.pick(move, mode, element)
	if not pk.is_empty() and pk.has("alt"):
		var k := move + "/" + mode
		var turn := bool(_alt.get(k, false))
		_alt[k] = not turn
		var alt := BendPoses._as_pose(pk.alt)
		if turn and not alt.is_empty() and BendPoses.usable(String(alt.clip)):
			alt["from"] = pk.get("from", "mode")
			pk = BendPoses._filled(alt, BendPoses.data())
	if pk.has("hand"):
		pk["hand"] = HANDS.get(String(pk.hand), String(pk.hand))
	return pk


## Its own knock reaction (NpcFighter.on_bend_knock): launched (`v` lifts it at BendKnock.LAUNCH_UP_MPS or more) the airborne
## clip, else the braced slide; from its start, held at its hold_s while the knock lasts (_step). The length played (0: none).
func play_knock(v: Vector3) -> float:
	var nm := KNOCK_AIR if v.y >= BendKnock.LAUNCH_UP_MPS else KNOCK_SLIDE
	if not has_clip(nm) and not (_add_pose(nm) and has_clip(nm)):
		return 0.0
	var a := ap.get_animation(LIB + "/" + nm)
	_knock_hold = float(a.get_meta(&"hold_s", -1.0))
	set_arms("")
	return play_once(nm, 0.08, 1.0)


## Where a cast leaves the body (world): the pose's limb (its "hand": l_palm, r_palm, both, l_foot, r_foot), else the
## right palm.
func strike_point() -> Vector3:
	var hand := String(cast_pick.get("hand", "r_palm"))
	match hand:
		"both":
			return (bone_pos("l_palm") + bone_pos("r_palm")) * 0.5
		"l_foot":
			return bone_pos("l_ball")
		"r_foot":
			return bone_pos("r_ball")
	return bone_pos(hand)


## A reload clip moves the hand props; the next clip that does not puts them back as built (PROP_BONES).
func _props_after(key: String) -> void:
	if key.begins_with("reload") or (key.begins_with(BendPoses.OWN_PREFIX) and _keys_props(key)):
		_props_moved = true
		_props_t = 0.0
	elif _props_moved:
		_props_moved = false
		_props_t = PROPS_BACK_S


## Whether library clip `key` keys a hand prop bone (a cast's pose made from a swing: own-axe-stab moves the haft's socket).
func _keys_props(key: String) -> bool:
	if _keys_props_cache.has(key):
		return _keys_props_cache[key]
	var out := false
	var a := ap.get_animation(LIB + "/" + key) if has_clip(key) else null
	if a != null:
		for i in a.get_track_count():
			if String(a.track_get_path(i).get_concatenated_subnames()) in PROP_BONES:
				out = true
				break
	_keys_props_cache[key] = out
	return out


func _props_back() -> void:
	for e: Array in _props:
		sk.set_bone_pose_position(int(e[0]), e[1])
		sk.set_bone_pose_rotation(int(e[0]), e[2])


## The arms pose laid over the stance ("" none).
func set_arms(key: String) -> void:
	if arms_ap == null or key == arms:
		return
	arms = key
	if key == "" or not arms_ap.has_animation(LIB + "/" + key):
		arms = ""
		arms_ap.stop()
		return
	arms_ap.play(LIB + "/" + key, 0.0)


## The weapon model in the right hand at `xf` (its grip at the hand's prop socket).
func hold(model: Node3D, xf := Transform3D.IDENTITY) -> void:
	_hold = xf
	if model.get_parent() != hand:
		if model.get_parent() != null:
			model.get_parent().remove_child(model)
		hand.add_child(model)
	model.top_level = false
	model.transform = xf


## The musket to the shoulder and laid on `p` (HuntAim; the aim clip is the caller's).
func aim_at(p: Vector3, gun: Node3D) -> void:
	if aim == null or gun == null:
		return
	gun.top_level = true
	aim.gun = gun
	aim.target = p
	aim.want = true


## The musket down from the shoulder, carried in the hand again.
func aim_off(gun: Node3D) -> void:
	if aim != null:
		aim.want = false
	if gun != null and is_instance_valid(gun) and gun.get_parent() == hand:
		gun.top_level = false
		gun.transform = _hold


## How far the aim is in (0..1).
func aim_weight() -> float:
	return aim.weight if aim != null else 0.0


## A bone's place in the world (the body's origin when there is no such bone).
func bone_pos(bone: String) -> Vector3:
	var i := sk.find_bone(bone) if sk else -1
	return sk.global_transform * sk.get_bone_global_pose(i).origin if i >= 0 else global_position


## What sticks in him at `point` rides on the nearest of STUCK_BONES (a BoneAttachment3D made once per bone), so it moves with
## him alive and falls with him dead (the hit part it went into is freed when he dies). As WildAnimal.stuck_anchor.
func stuck_anchor(point: Vector3) -> Node3D:
	if sk == null or not is_instance_valid(sk):
		return self
	var best := -1
	var bd := INF
	for nm: String in STUCK_BONES:
		var i := sk.find_bone(nm)
		if i < 0:
			continue
		var d := (sk.global_transform * sk.get_bone_global_pose(i).origin).distance_squared_to(point)
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return self
	var nm := "Stuck_%d" % best
	var ba := sk.get_node_or_null(nm) as BoneAttachment3D
	if ba == null:
		ba = BoneAttachment3D.new()
		ba.name = nm
		sk.add_child(ba)
		ba.bone_idx = best
	# (placed now: it follows its bone from the skeleton's next update; what is parented to it keeps where it is)
	ba.global_transform = sk.global_transform * sk.get_bone_global_pose(best)
	return ba


## The clip playing run on to its end and shown there (a death that played while the body was stepped seldom, or not at all:
## he ends lying down).
func finish_clip() -> void:
	if ap == null or ap.current_animation == "":
		return
	ap.advance(maxf(ap.current_animation_length - ap.current_animation_position, 0.0) + 0.2)
	if _manual and sk != null:
		sk.advance(0.0)
	steps += 1


## At rest for good (settled dead): no pose steps, the aim and the body's own drivers off, the skeleton's modifiers never run
## again (it is not updated at all), this node's own frame off.
func rest() -> void:
	animate = false
	if aim != null:
		aim.want = false
		aim.active = false
	if sk != null:
		sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
		_manual = true
		# the body's own drivers once more on the pose he lies in (2026-10-03, seen in the inspect view): a man who fell far off or
		# out of sight had them off, and his arms' skin stayed pulled to the twist bones where a standing man's arms would be. Run
		# outside the modifier pass, what they set stays (a modifier's own work is undone after each update; nothing animates
		# this body again)
		if mesh != null and mesh.has_method(&"_process_modification"):
			mesh.call(&"_process_modification")
	if mesh != null:
		mesh.active = false
	set_process(false)


## The hit parts off (the dead take no hits: the shots go on past to what is behind).
func drop_parts() -> void:
	for p in [torso, head]:
		if p != null and is_instance_valid(p):
			p.queue_free()
	torso = null
	head = null


## The physics bodies of its hit parts (a fighter's own shots and rays leave them out).
func part_rids() -> Array[RID]:
	var out: Array[RID] = []
	for p in [torso, head]:
		if p != null and is_instance_valid(p):
			out.append((p as StaticBody3D).get_rid())
	return out


func _process(delta: float) -> void:
	if ap == null:
		return
	if not animate:
		_acc = 0.0
		if mesh and mesh.active:
			mesh.active = false
		_set_manual(true)
		return
	_acc += delta
	var st := anim_step
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var seen := cam == null or cam.is_position_in_frustum(global_position + Vector3.UP)
	if not seen:
		st = maxf(st, OFFSCREEN_S)
	# the body's own bone drivers only near and in view (far off nobody sees the helper bones)
	var drive := seen and anim_step <= 1.0 / 30.0 + 0.001
	if mesh and mesh.active != drive:
		mesh.active = drive
	# (stepped every frame: the modifiers with the skeleton's own frame; less often: by hand at each step)
	_set_manual(st > 0.0)
	if _acc >= st:
		_step(_acc)
		_acc = 0.0


func _step(dt: float) -> void:
	if _knock_hold >= 0.0:
		if not clip.begins_with(KNOCK_PREFIX):
			_knock_hold = -1.0
		elif ap.current_animation_position >= _knock_hold and _knocked():
			dt = 0.0                                # (held on the knock's pose while it lasts)
		elif not _knocked():
			_knock_hold = -1.0
	ap.advance(dt)
	if _props_t > 0.0 and sk != null:
		_props_back()
		_props_t = maxf(_props_t - maxf(dt, 0.001), 0.0)
	if arms != "" and arms_ap != null:
		arms_ap.advance(0.0)
	if _manual and sk != null:
		sk.advance(dt)
	steps += 1
	_place_parts()


## Its fighter still taking a knock (BendKnock's window, or in the air from it).
func _knocked() -> bool:
	var f := get_parent()
	if f == null or not f.has_method(&"knock_t"):
		return false
	return float(f.call(&"knock_t")) > 0.0 or bool(f.call(&"is_launched"))


func _set_manual(on: bool) -> void:
	if on == _manual or sk == null:
		return
	_manual = on
	sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL if on \
			else Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE


## The torso along the spine (pelvis to neck) and the head on its bone, in this body's frame.
func _place_parts() -> void:
	if sk == null or torso == null or not is_inside_tree():
		return
	var to_me := global_transform.affine_inverse() * sk.global_transform
	var bp := sk.find_bone("pelvis")
	var bn := sk.find_bone("neck")
	var bh := sk.find_bone("heada")
	if bp < 0 or bn < 0:
		return
	var a := to_me * sk.get_bone_global_pose(bp).origin
	var b := to_me * sk.get_bone_global_pose(bn).origin
	var up := (b - a).normalized()
	if up.length() < 0.5:
		up = Vector3.UP
	var x := up.cross(Vector3.FORWARD) if absf(up.dot(Vector3.FORWARD)) < 0.95 else up.cross(Vector3.RIGHT)
	x = x.normalized()
	torso.transform = Transform3D(Basis(x, up, x.cross(up).normalized()), (a + b) * 0.5)
	if head != null and bh >= 0:
		head.transform = Transform3D(Basis.IDENTITY, to_me * sk.get_bone_global_pose(bh).origin + up * 0.08)


func _part(part: String, mult: float, shape: Shape3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Hit_" + part
	b.collision_layer = WildAnimal.HIT_LAYER
	b.collision_mask = 0
	b.set_meta("hit_part", part)
	b.set_meta("damage_mult", mult)
	b.set_meta("surface", "flesh")
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	add_child(b)
	return b


static func _capsule(r: float, h: float) -> CapsuleShape3D:
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = h
	return c


static func _sphere(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s
