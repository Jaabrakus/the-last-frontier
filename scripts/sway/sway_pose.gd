class_name SwayPose
extends Node
## The body of a Sway cast (the Sway v2; SwayCaster's child `pose`; docs/main_story.md 11.10, the owner's rules): every spell is
## cast with our own clips (animations_extra/Frontier_Form.res: tools/anim_author/blender/form_clips.py, install_form.gd), the
## clip by the caster's mastery of the spell (SwayCaster.tier; data/sway/moves.json mastery.clips):
##   untrained  the floor cast, for every spell (Gust too): the hands clap at the chest, the body sinks into a deep squat and the
##              palms press flat to the ground (own-form-clap-press, held at its end while the lock fills); the cast: the palms
##              push down and the body stands (own-form-release). A circle on an upright (mend on a wall): the palms onto it
##              (own-form-press-wall, held at hold_s; its shove on the cast)
##   practised  a two-handed standing push (own-sway-push-two): the wind-up (both palms drawn back to the chest) held while the
##              lock fills, the push from the chest on the cast, a beat, and back to the stand
##   expert     the same with the left palm alone (own-sway-push-one), played without the right arm (ToolPose "reach_l"): the
##              right hand keeps what it holds (a pistol, a tomahawk, a saber)
## A hold (Gust's stone held up, Gust in a sail) keeps the held part of the clip until it is let go (the push) or broken.
## Played over the game's pose by a ToolPose of our own, after every other modifier but the body (put_last: CharacterBodyMesh's
## helpers follow the clip's pose): "upper" always and "full" (the squat, the root's place) as far as the player stands still;
## an untrained caster is held still while the floor cast plays (SwayCaster roots them), so the squat is whole; the one-handed
## push "reach_l" only. A lock broken or fizzled: the body stands (the release from its up_s; a push eased out from back_s).
## The first lock (the wreck's scripted lock, no spell) plays none: SwayArm points the arm.

const CLIPS := "res://animations_extra/Frontier_Form.res"
const CLAP_PRESS := &"own-form-clap-press"
const RELEASE := &"own-form-release"
const PRESS_WALL := &"own-form-press-wall"
const PUSH_TWO := &"own-sway-push-two"
const PUSH_ONE := &"own-sway-push-one"
const BLEND_IN_S := 0.12
const BLEND_OUT_S := 0.22
## Body speeds (m/s) over which the squat ("full") gives way to the upper body alone (the legs the player's).
const STILL_MPS := Vector2(0.35, 1.2)

var caster: SwayCaster
## The clip playing: "" none, "press" (the clap and press, or the wind-up: held), "release" (the push, or the push down and
## stand), "up" (the stand after a broken lock).
var phase := ""
var clip_t := 0.0
var weight := 0.0
## The clip's name ("" none) and the tier it was chosen for (-1 none).
var anim_name := ""
var tier := -1
## The palms (world; after every modifier: the clip's pose): their midpoint, or the left palm for the one-handed push. INF
## before.
var palms := Vector3.INF
## The palms pressed to the ground (or the wall), the clap heard: the floor cast's moments.
var pressed := false
var clapped := false

var _lib: AnimationLibrary
var _pose: ToolPose
var _anim: Animation
var _hold := 0.0
var _from_t := 0.0
var _w0 := 0.0
var _floor := false
var _palm_ids := Vector2i(-2, -2)


func _ready() -> void:
	if caster == null:
		caster = get_parent() as SwayCaster
	if caster == null:
		return
	caster.lock_started.connect(_on_started)
	caster.cast.connect(_on_cast)
	caster.lock_broken.connect(func(_m: String, _t: Node3D, _why: String) -> void: _on_end())
	caster.fizzled.connect(func(_m: String, _t: Node3D) -> void: _on_end())
	if caster.player != null and caster.player.skeleton != null:
		caster.player.skeleton.skeleton_updated.connect(_on_skeleton_updated)


## The clips (null until they load; null when the library is missing).
func clips() -> AnimationLibrary:
	if _lib == null and ResourceLoader.exists(CLIPS):
		_lib = load(CLIPS) as AnimationLibrary
	return _lib


## A clip is on the body now (the lock's press or wind-up, or the push and the stand after it).
func posing() -> bool:
	return phase != ""


## The clip a spell's lock plays at mastery tier `t` (0 untrained, 1 practised, 2 expert); on an upright (the floor cast only).
static func clip_for(t: int, on_wall := false) -> StringName:
	match t:
		1:
			return PUSH_TWO
		2:
			return PUSH_ONE
	return PRESS_WALL if on_wall else CLAP_PRESS


func _on_skeleton_updated() -> void:
	if phase == "":
		return
	var sk := caster.player.skeleton
	if _palm_ids.x == -2:
		_palm_ids = Vector2i(sk.find_bone("l_palm"), sk.find_bone("r_palm"))
	if _palm_ids.x < 0 or _palm_ids.y < 0:
		return
	var l := sk.get_bone_global_pose(_palm_ids.x).origin
	var mid := l if anim_name == String(PUSH_ONE) else (l + sk.get_bone_global_pose(_palm_ids.y).origin) * 0.5
	palms = sk.global_transform * mid


# ---------------------------------------------------------------- the caster's lock
func _on_started(m: String, _t: Node3D) -> void:
	if not caster.is_spell(m):
		return                              # (the first lock: the pointing arm)
	tier = caster.tier(m)
	var wall := caster.form != null and caster.form.on_wall and FormCast.is_form(m)
	_floor = tier == 0
	_begin(clip_for(tier, wall), "press")


func _on_cast(m: String, _t: Node3D) -> void:
	if phase == "" or not caster.is_spell(m):
		return
	match anim_name:
		String(CLAP_PRESS):
			_begin(RELEASE, "release", 0.0)
		_:
			_begin(StringName(anim_name), "release", _hold)       # (the wall's shove, the push: on from the held moment)


func _on_end() -> void:
	if phase != "press":
		return
	var a := clips()
	if a == null:
		return
	match anim_name:
		String(CLAP_PRESS):
			var r := a.get_animation(RELEASE)
			_begin(RELEASE, "up", float(r.get_meta(&"up_s", 0.2)) if r else 0.2)
		String(PRESS_WALL):
			_begin(PRESS_WALL, "up", float(_anim.get_meta(&"push_s", _hold)))
		_:
			_begin(StringName(anim_name), "up", float(_anim.get_meta(&"back_s", _hold)))


# ---------------------------------------------------------------- the clip
func _begin(clip: StringName, p_phase: String, from_t := 0.0) -> void:
	var lib := clips()
	if lib == null or not lib.has_animation(clip):
		phase = ""
		return
	_anim = lib.get_animation(clip)
	anim_name = String(clip)
	phase = p_phase
	clip_t = 0.0
	_from_t = from_t
	_w0 = weight
	if p_phase == "press":
		_hold = float(_anim.get_meta(&"hold_s", _anim.length))
		clapped = false
		pressed = false
	var sk := caster.player.skeleton
	if sk == null:
		return
	if _pose == null or not is_instance_valid(_pose):
		_pose = ToolPose.new()
		_pose.name = "SwayCastPose"
	if _pose.get_parent() != sk:
		if _pose.get_parent():
			_pose.get_parent().remove_child(_pose)
		sk.add_child(_pose)
	put_last(sk, _pose)
	_pose.active = true


## `pose` moved over the tree and every other modifier, but the body (CharacterBodyMesh) put back behind it: its helpers (the
## shoulder and forearm twist, the armpit, the skirt) follow the final pose. Moving a child does not tell the body (it sorts
## itself last only as a modifier enters the tree), so a second cast would otherwise run after it: the skin stretched from
## the pose before the cast (the forearm a noodle, the sleeve a sheet). ForagePick's grab does the same.
static func put_last(sk: Skeleton3D, pose: Node) -> void:
	sk.move_child(pose, -1)
	for n in sk.get_children():
		if n is CharacterBodyMesh and n != pose:
			sk.move_child(n, -1)


## The clip's time now (s).
func clip_time() -> float:
	if _anim == null:
		return 0.0
	match phase:
		"press":
			return minf(clip_t, _hold)
		"release", "up":
			return minf(_from_t + clip_t, _anim.length)
	return 0.0


func _process(dt: float) -> void:
	if caster == null or caster.player == null or not is_instance_valid(caster.player):
		return
	_tick(dt)


func _tick(dt: float) -> void:
	if phase == "" or _anim == null:
		return
	clip_t += dt
	var t := clip_time()
	var w := 1.0
	match phase:
		"press":
			w = lerpf(_w0, 1.0, clampf(clip_t / BLEND_IN_S, 0.0, 1.0))
			if _floor or anim_name == String(PRESS_WALL):
				if not clapped and t >= float(_anim.get_meta(&"clap_s", 0.23)):
					clapped = true
					FormEffects.sfx("clap", caster.hand_point(), -8.0, 1.5)
				var press_at := float(_anim.get_meta(&"press_s", _anim.get_meta(&"hold_s", 0.66)))
				if not pressed and t >= press_at:
					pressed = true
					FormEffects.sfx("press", caster.hand_point(), -4.0, 0.9)
			elif not pressed and t >= _hold:
				pressed = true                                          # (the wind-up drawn: the palms ready)
		"release", "up":
			w = minf(lerpf(_w0, 1.0, clampf(clip_t / 0.06, 0.0, 1.0)), clampf((_anim.length - t) / BLEND_OUT_S, 0.0, 1.0))
			if t >= _anim.length:
				_stop()
				return
	weight = w
	if _pose == null or not is_instance_valid(_pose):
		return
	if anim_name == String(PUSH_ONE):
		_pose.layers = [{"anim": _anim, "time": t, "weight": w, "mask": "reach_l"}]
		return
	var still := 1.0 - smoothstep(STILL_MPS.x, STILL_MPS.y, caster.player.horizontal_speed())
	_pose.layers = [{"anim": _anim, "time": t, "weight": w, "mask": "upper"}, {"anim": _anim, "time": t, "weight": w * still, "mask": "full"}]


func _stop() -> void:
	phase = ""
	anim_name = ""
	weight = 0.0
	tier = -1
	if _pose != null and is_instance_valid(_pose):
		_pose.layers = []
		_pose.active = false


func _exit_tree() -> void:
	_stop()
