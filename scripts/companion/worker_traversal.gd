class_name WorkerTraversal
extends TravPreviewActor
## Vaults, climb-ups and steps for a worker (user 2026-09-30: "rocks and logs should be able to be stepped over as well or
## mini vaults"): the player's traversal (PlayerTraversal: the TraversalController measures the world and plays the Actor_B moves
## authored for each obstacle, warped onto it) on a worker's own rig. The controller and its baked ledges are the player's
## (shared, not baked again); the moves are the same and play on her skeleton with the seam rules of TravPreviewActor.
##
## When (`want`): only when the way she walks has something in it she can get over: a knee-high ray ahead hits and the
## chest-high one (CHEST_M) does not: a rock, a log too high to step over, a low wall. The controller then picks the move
## for it as for the player (a vault at a run, a step-on at a walk, a climb-up), and owns her body while it plays; the rest
## of the time the controller is off (a worker does not climb onto whatever is beside her path).
##
##   var t := WorkerTraversal.install(spouse)      # Spouse._ready
##   Spouse._move: t.pre(input, dt) -> true while the move plays (she skips her own walk); t.post(owned, dt) after it

const KNEE_M := 0.45
const CHEST_M := 1.5
## Looks this far ahead (m) for what she can get over.
const LOOK_M := 2.4
const EXIT_INERT_S := 0.3
const RIG_RETURN_S := 0.25
## Never these: a vault over a wall too high, a hang: the moves the player's own table has switched off, and the free climbs.
const DISABLED_MOVES := ["gap_jump", "long_jump", "shimmy_enter", "shimmy_idle", "shimmy_start", "shimmy_loop",
		"shimmy_stop", "shimmy_exit", "squeeze", "climb_hang_3m", "climb_hang_3m_idle"]

var walker: Spouse
var controller: TraversalController
var world_ready := false
## A move (or its exit) is on the skeleton now.
var showing := false
## What she can get over ahead of her this frame.
var want := false
var _rig_local: Transform3D
var _rig_back := -1.0
var _rig_off: Transform3D
var _rig_last: Transform3D
var _rig_seen := false
var _rig_ret_s := RIG_RETURN_S
var _mods_off: Array = []
var _ray: PhysicsRayQueryParameters3D
## Counters for the tests.
var moves := 0
var last_move := ""


static func install(s: Spouse) -> WorkerTraversal:
	var t := WorkerTraversal.new()
	t.name = "Traversal"
	t.walker = s
	s.add_child(t)
	t.adopt()
	return t


## Instead of build(): the worker's own rig, skeleton and AnimationPlayer.
func adopt() -> void:
	lib = TravMoveLibrary.shared()
	skeleton = walker.sk
	rig = walker._model
	_rig_local = rig.transform
	anim_player = walker.ap
	BindRest.ensure(skeleton, anim_player, LIB)
	inert = TravInertializer.new()
	inert.name = "TravInertializer"
	skeleton.add_child(inert)
	var names := PackedStringArray()
	for c in lib.clips():
		names.append(_anim_name(c))
	inert.set_bones_from_clips(skeleton, anim_player, names)
	TravMomentum.measure(lib, anim_player, str(LIB) + "/", skeleton)
	ik = TraversalIK.new()
	ik.name = "TraversalIK"
	skeleton.add_child(ik)
	# (before the body mesh, which moves itself last)
	var first := 0
	for i in skeleton.get_child_count():
		if skeleton.get_child(i) is CharacterBodyMesh:
			first = i
			break
	skeleton.move_child(inert, first)
	skeleton.move_child(ik, first + 1)
	_build_tree()
	tree.active = false


## The controller, from the player's (its baked ledges and shape registry): once the player's traversal is ready.
func _connect() -> void:
	var pl := walker.player
	var pt: Variant = pl.get("traversal") if pl != null else null
	if pt == null or not pt.get("world_ready"):
		return
	var pc: TraversalController = pt.controller
	var own := TravMoveLibrary.new()
	own.load_table(TravMoveLibrary.TABLE)
	for id in DISABLED_MOVES:
		if own.moves.has(id):
			(own.moves[id] as Dictionary)["enabled"] = false
	controller = TraversalController.new()
	controller.name = "TraversalController"
	walker.add_child(controller)
	controller.setup(walker, {"library": own, "registry": pc.registry, "ledges": pc.ledges})
	controller.input_exit = true
	world_ready = true


## What she can get over ahead along `dir`: an obstacle the knee-high ray hits within LOOK_M that the chest-high one clears.
func look(dir: Vector3) -> bool:
	if dir == Vector3.ZERO or not walker.is_inside_tree():
		return false
	var space := walker.get_world_3d().direct_space_state
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
	var ex: Array[RID] = [walker.get_rid()]
	var at := walker.global_position
	var knee := _hit(space, at + Vector3.UP * KNEE_M, dir, ex)
	if knee == INF:
		return false
	var chest := _hit(space, at + Vector3.UP * CHEST_M, dir, ex)
	return chest == INF or chest > knee + 1.2


func _hit(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, ex: Array[RID]) -> float:
	_ray.from = from
	_ray.to = from + dir * LOOK_M
	_ray.exclude = ex
	for _try in 3:
		var h := space.intersect_ray(_ray)
		if h.is_empty():
			return INF
		var col := h.collider as Node
		if col != null and (col is CharacterBody3D or col is AnimatableBody3D or col.is_in_group(&"terrain")):
			ex.append(h.rid)
			_ray.exclude = ex
			continue
		return from.distance_to(h.position)
	return INF


## Per physics tick before the walk: the controller's input step; true while it owns the body (she skips her own walk).
func pre(input: Dictionary, delta: float) -> bool:
	if not world_ready:
		_connect()
		return false
	var dir := Basis(Vector3.UP, float(input.get("yaw", walker.rotation.y))) * Vector3(0.0, 0.0, -1.0)
	var moving := Vector2(walker.velocity.x, walker.velocity.z).length() > 0.3 or (input.get("move", Vector2.ZERO) as Vector2).length() > 0.1
	want = moving and (look(dir) if not controller.owns_body() else true)
	controller.enabled = want or controller.owns_body() or showing
	if not controller.enabled:
		return false
	var mv := Vector2(0.0, -1.0) if want else Vector2.ZERO
	var inp := {"move": mv, "sprint": want, "walk": false, "jump": false, "crouch": false, "crouched": false, "yaw": input.get("yaw", walker.rotation.y)}
	controller.pre_step(inp, delta)
	return controller.owns_body()


## After her walk (or instead of it): the controller advances and its state is shown on her rig.
func post(owned: bool, delta: float) -> void:
	if not world_ready or not controller.enabled:
		if showing:
			_end({})
		return
	if owned:
		controller.physics_step(delta)
	else:
		controller.tick(delta)
	var st := controller.anim_state()
	var on := str(st.get("mode", "OFF")) != "OFF" and st.has("clip") and str(st.clip) != ""
	if on and not showing:
		_begin()
	elif not on and showing:
		_end(st)
	if showing:
		pending_plan = controller.pending
		approach = controller.approach()
		show_state(st, walker, delta)
	else:
		if _rig_back >= 0.0:
			_rig_back += delta
			var u := smoothstep(0.0, 1.0, clampf(_rig_back / _rig_ret_s, 0.0, 1.0))
			var to: Transform3D = rig.get_parent().global_transform * _rig_local
			rig.global_transform = to * _rig_off.interpolate_with(Transform3D.IDENTITY, u)
			if u >= 1.0:
				rig.transform = _rig_local
				_rig_back = -1.0
		time_scale = 1.0
		_apply_ik(st.get("pins", []), st.get("guards", []))
		_rig_last = rig.global_transform
		_rig_seen = true


func _begin() -> void:
	showing = true
	moves += 1
	_rig_back = -1.0
	walker.trav_busy = true
	anim_player.active = false
	_mods_off.clear()
	for c in skeleton.get_children():
		if c is SkeletonModifier3D and c != inert and c != ik and not (c is CharacterBodyMesh) and (c as SkeletonModifier3D).active:
			(c as SkeletonModifier3D).active = false
			_mods_off.append(c)
	_stack = [{"clip": "actor_b-p-relax-idle", "t": 0.0, "rate": 1.0, "loop": true, "fade": 0.0, "w_t": 0.0, "key": "loco:worker"}]
	_key = "loco:worker"
	_move_key = ""
	_fade_pins = []
	_ramp_t = 1.0
	_ramp_len = 0.0
	_yaw = TravInertializer.yaw_of(rig.global_transform.basis)
	inert.root_reset(_rig_last if _rig_seen else rig.global_transform, Vector3.ZERO)
	entry_inertialize = true
	tree.active = true


func _end(st: Dictionary) -> void:
	showing = false
	last_move = str(st.get("move", ""))
	tree.active = false
	anim_player.active = true
	walker.trav_busy = false
	walker.set("_clip", "")
	for c in _mods_off:
		if is_instance_valid(c):
			(c as SkeletonModifier3D).active = true
	_mods_off.clear()
	inert.start(EXIT_INERT_S, TravInertializer.FULL, _root_bones())
	var to: Transform3D = rig.get_parent().global_transform * _rig_local
	_rig_off = to.affine_inverse() * rig.global_transform
	_rig_back = 0.0
	_rig_ret_s = EXIT_INERT_S
	_stack.clear()
	_key = ""


func _root_bones() -> Array:
	var out := []
	for bn in ["root", "pelvis"]:
		var b := skeleton.find_bone(bn)
		if b >= 0:
			out.append(b)
	return out
