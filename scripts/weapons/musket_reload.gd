class_name MusketReload
extends Node
## The flintlock musket's reload as this project's own animation (user 2026-09-28/29: "we need to create a new reload
## animation for ramrod and etc what musket would be like"; the ramrod worked "right hand on the tip of the gun" with
## the gun in the other hand, every reload, standing, walking or crouched; "make the animation the same time as the
## reload timer"): each of Musket.reload_stages' five steps plays tools/anim_author/author_reload.gd's clip for it over
## the animation tree on the upper body by a ToolPose, time-scaled to the step's seconds: the gun down to the priming
## position, a cartridge from the pouch bitten, the pan primed and shut, the gun cast about into the left hand slanted
## across the front, the powder poured and the ball pressed in at the muzzle, the ramrod drawn, turned, rammed in three
## strokes, back out and home, the gun brought back to the carry. Crouched, the clips' "-crouch" twins (the gun lower,
## its butt by the ground), blended over by the crouch.
##
## With it, the musket's parts: the ramrod where the clips' "Props:ramrod" tracks have it (the musket model's frame);
## the paper cartridge in the right hand from the pouch until it goes down the muzzle; and the lock: a shot leaves the
## cock down on the frizzen and the frizzen thrown open; the first step half-cocks it, the priming shuts the frizzen,
## the last step full-cocks it (an interrupted reload keeps where it got to).
## Not on the over-under (OverUnderMusket: its own rig and mechanism).

const OWN_PATH := "res://animations_extra/Frontier_Own.res"
## The step (Musket.reload_stages' index) each clip plays on.
const CLIPS := {0: "own-musket-load-bite", 1: "own-musket-load-prime", 2: "own-musket-load-pour",
		3: "own-musket-load-ram", 4: "own-musket-load-return"}
## The paper cartridge in the hand: from [step, seconds into its clip] (drawn from the pouch) to (pressed into the
## muzzle with the ball); a paper tube along the fist's thumb side.
const CARTRIDGE_FROM := [0, 0.39]
const CARTRIDGE_TO := [2, 0.97]
const CARTRIDGE_SIZE := Vector2(0.009, 0.07)
## The right fist's hole in the wrist bone's frame, where the clips close it on the rod and the cartridge
## (pose_solver.fist_rel("r", author_reload.gd FIST): the author prints it); the cartridge runs through it, out of the
## thumb's side (+Y).
const FIST_HOLE := Transform3D(Basis(Vector3(-0.209989, 0.414662, -0.885416), Vector3(0.943614, -0.151098, -0.294555),
		Vector3(-0.255924, -0.897343, -0.359552)), Vector3(-0.000327, 0.034926, -0.068744))
const FADE_IN := 0.2
const FADE_OUT := 0.25
## The crouched twins' names: the clip's with this after it; blended in over the standing ones in this many seconds.
const CROUCH_SUFFIX := "-crouch"
const CROUCH_BLEND := 0.3
const COCK_FULL := 0.0
const COCK_HALF := deg_to_rad(-18.0)
const COCK_FIRED := deg_to_rad(-40.0)
const COCK_SPEED := deg_to_rad(420.0)
const FRIZZEN_OPEN := deg_to_rad(-70.0)
const FRIZZEN_CLOSE_SPEED := deg_to_rad(500.0)
## Where in its step the lock moves (fractions of the step; the sounds' cues: WeaponAudio RELOAD["musket"]).
const HALF_COCK_AT := 0.04          ## step 1
const FRIZZEN_SHUT_AT := 0.53       ## step 2
const FULL_COCK_AT := 0.81          ## step 5

var gun: Firearm
var _lib: AnimationLibrary
var _pose: ToolPose
var _model: Node3D
var _rod: Node3D
var _cock: Node3D
var _frizzen: Node3D
var _cartridge: MeshInstance3D       ## in the right hand (a BoneAttachment3D's: it follows the pose as drawn)
var _rest := {}                      ## part -> its rest transform
var _cock_a := COCK_FULL
var _friz_a := 0.0

var _anim: Animation                 ## the step playing (null: none)
var _anim_c: Animation               ## its crouched twin (null: none)
var _c := 0.0                        ## the crouched twin's weight over it
var _t := 0.0                        ## seconds into its clip
var _rate := 1.0
var _w := 0.0                        ## the pose's weight over the tree's
var _on := false


func _ready() -> void:
	if gun == null:
		gun = get_parent() as Firearm
	if gun == null or gun is OverUnderMusket:
		set_process(false)
		return
	gun.action_started.connect(_on_action)
	gun.action_cancelled.connect(_on_cancelled)
	gun.fired.connect(_on_fired)


## The musket's parts, once the player has hung its model.
func _setup() -> bool:
	if _model != null:
		return true
	if gun.model == null or gun.player == null or gun.player.skeleton == null:
		return false
	_model = gun.model
	_rod = _model.get_node_or_null("Ramrod") as Node3D
	_cock = _model.get_node_or_null("Cock") as Node3D
	_frizzen = _model.get_node_or_null("Frizzen") as Node3D
	for n: Node3D in [_rod, _cock, _frizzen]:
		if n:
			_rest[n] = n.transform
	if ResourceLoader.exists(OWN_PATH):
		_lib = load(OWN_PATH) as AnimationLibrary
	var hand := BoneAttachment3D.new()
	hand.name = "ReloadHand"
	gun.player.skeleton.add_child(hand)
	hand.bone_name = "r_wrist"
	_cartridge = MeshInstance3D.new()
	_cartridge.name = "Cartridge"
	var cm := CylinderMesh.new()
	cm.top_radius = CARTRIDGE_SIZE.x
	cm.bottom_radius = CARTRIDGE_SIZE.x
	cm.height = CARTRIDGE_SIZE.y
	cm.radial_segments = 8
	cm.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.82, 0.72)
	mat.roughness = 0.9
	cm.material = mat
	_cartridge.mesh = cm
	_cartridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cartridge.visible = false
	_cartridge.transform = FIST_HOLE * Transform3D(Basis(), Vector3(0.0, 0.05, 0.0))
	hand.add_child(_cartridge)
	return true


func _on_action(key: String, duration: float) -> void:
	if not key.begins_with("reload") or not _setup():
		return
	var nm: String = CLIPS.get(gun._stage, "")
	var a := _lib.get_animation(nm) if _lib and nm != "" and _lib.has_animation(nm) else null
	if a == null:
		_on = false
		return
	_anim = a
	_anim_c = _lib.get_animation(nm + CROUCH_SUFFIX) if _lib.has_animation(nm + CROUCH_SUFFIX) else null
	_t = 0.0
	_rate = a.length / maxf(duration, 0.05)
	_on = true


func _on_cancelled() -> void:
	_on = false


## A shot: the flint comes down on the frizzen and throws it open.
func _on_fired() -> void:
	_cock_a = COCK_FIRED
	_friz_a = FRIZZEN_OPEN
	_pose_lock()


func _process(delta: float) -> void:
	if not _setup():
		return
	if _on and gun.state != Firearm.State.RELOADING:
		_on = false
	if _on and _anim:
		_t = minf(_t + delta * _rate, _anim.length)
	_w = move_toward(_w, 1.0 if _on else 0.0, delta / (FADE_IN if _on else FADE_OUT))
	var crouched := 1.0 if gun.player.is_crouching else 0.0
	# (not showing: the stance as it is; showing: into it over CROUCH_BLEND)
	_c = crouched if _w <= 0.0 else move_toward(_c, crouched, delta / CROUCH_BLEND)
	_apply_pose()
	_apply_rod()
	_apply_cartridge()
	_lock(delta)


func _apply_pose() -> void:
	if _pose == null:
		_pose = ToolPose.new()
		_pose.name = "MusketReloadPose"
		gun.player.skeleton.add_child(_pose)
	var ls := []
	if _w > 0.0 and _anim:
		ls.append({"anim": _anim, "time": _t, "weight": _w, "mask": "upper"})
		if _anim_c and _c > 0.0:
			ls.append({"anim": _anim_c, "time": _t, "weight": _w * _c, "mask": "upper"})
	_pose.layers = ls


## The ramrod where the step has it (home when no step plays).
func _apply_rod() -> void:
	if _rod == null:
		return
	var at: Transform3D = _rest[_rod]
	if _w > 0.5 and _anim:
		var x: Variant = _prop(_anim, "ramrod", _t)
		if x != null:
			at = x
	_rod.transform = at


## The paper cartridge in the right hand while the reload has it there.
func _apply_cartridge() -> void:
	if _cartridge == null:
		return
	var at := [gun._stage, _t]
	_cartridge.visible = _on and _w > 0.5 and _anim != null and _after(at, CARTRIDGE_FROM) and not _after(at, CARTRIDGE_TO)


## [step, seconds] at or after [step, seconds].
static func _after(a: Array, b: Array) -> bool:
	return int(a[0]) > int(b[0]) or int(a[0]) == int(b[0]) and float(a[1]) >= float(b[1])


## A prop's transform from the clip's "Props:<name>" tracks at `t` (null: none).
static func _prop(a: Animation, nm: String, t: float) -> Variant:
	var path := NodePath("Props:" + nm)
	var pi := a.find_track(path, Animation.TYPE_POSITION_3D)
	var ri := a.find_track(path, Animation.TYPE_ROTATION_3D)
	if pi < 0 or ri < 0:
		return null
	return Transform3D(Basis(a.rotation_track_interpolate(ri, t)), a.position_track_interpolate(pi, t))


## Where the lock should be for the gun's state and the reload's progress.
func _lock_goal() -> Array:
	if gun.loaded:
		return [COCK_FULL, 0.0]
	var step := gun._stage
	var u := 0.0
	if gun.state == Firearm.State.RELOADING:
		var s: Array = gun.reload_stages[step]
		var total := float(s[1]) * (gun.player.reload_time_mult if gun.player else 1.0)
		u = 1.0 - gun._stage_left / maxf(total, 1e-3)
	else:
		# (an interrupted reload: where it got to; a fresh one: as the shot left it)
		if step == 0:
			return [COCK_FIRED, FRIZZEN_OPEN]
		u = 1.0
		step -= 1
	var cock := COCK_HALF
	if step == 0 and u < HALF_COCK_AT:
		cock = COCK_FIRED
	elif step >= gun.reload_stages.size() - 1 and u >= FULL_COCK_AT:
		cock = COCK_FULL
	var shut := step >= 2 or (step == 1 and u >= FRIZZEN_SHUT_AT)
	return [cock, 0.0 if shut else FRIZZEN_OPEN]


func _lock(delta: float) -> void:
	var goal := _lock_goal()
	_cock_a = move_toward(_cock_a, float(goal[0]), COCK_SPEED * delta)
	_friz_a = move_toward(_friz_a, float(goal[1]), FRIZZEN_CLOSE_SPEED * delta)
	_pose_lock()


func _pose_lock() -> void:
	for pair: Array in [[_cock, _cock_a], [_frizzen, _friz_a]]:
		var n: Node3D = pair[0]
		if n and _rest.has(n):
			var r: Transform3D = _rest[n]
			n.transform = Transform3D(r.basis * Basis(Vector3.RIGHT, float(pair[1])), r.origin)
