extends SceneTree
## Focused presentation regressions using the game's SwayPose, ToolPose, rig and clips.
## The movement state is virtual; the skeleton is real. No level, rendering or AI is needed.
## Run: Godot --headless --path . -s tests/bending/test_ring_pose_transitions.gd

const BONES := ["root", "pelvis", "spined", "heada", "r_palm", "l_palm", "r_ball", "l_ball"]
var failed := 0
var checked := 0
var rig: Node3D
var sk: Skeleton3D
var player: FrontierPlayer
var caster: SwayCaster
var pose: SwayPose
var moves: RingMoves


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checked += 1
	if not ok:
		failed += 1
	print(("  ok   " if ok else "  FAIL ") + message)


func _run() -> void:
	rig = (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(rig)
	sk = rig.get_node(^"Skeleton3D") as Skeleton3D
	sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	# Keep the player/caster off-tree so their level setup and automatic ticks never run.
	player = FrontierPlayer.new()
	player.skeleton = sk
	caster = SwayCaster.new()
	caster.player = player
	player.add_child(caster)
	pose = SwayPose.new()
	pose.caster = caster
	caster.add_child(pose)
	caster.pose = pose
	pose._pose = ToolPose.new()
	sk.add_child(pose._pose)
	pose._ring_lean = true
	moves = RingMoves.new()
	moves.virtual = true
	moves.body = player
	player.add_child(moves)
	player.ring_moves = moves
	_normal_transition()
	_interrupted_and_finished_transition()
	_air_cast_visible()
	_air_legs_visible()
	_recovery_contact()
	_contact_and_reset()
	player.free()
	rig.free()
	print("RING POSE TRANSITIONS %s (%d/%d)" % ["PASSED" if failed == 0 else "FAILED", checked - failed, checked])
	quit(0 if failed == 0 else 1)


func _air_fall() -> void:
	moves.mode = ""
	moves._air = true
	moves._helpless = false
	moves._ff = false
	moves._o = Vector3(0.0, -3.0, 0.0)
	moves._t = 10.0
	moves._vstun = 0.0
	moves._vfloor = false
	pose.phase = ""
	pose._cast_layers = []
	pose._tick_ring(0.2, moves)
	pose._apply()


func _globals() -> Dictionary:
	sk.reset_bone_poses()
	pose._pose._process_modification()
	var values := {}
	for name: String in BONES:
		values[name] = sk.get_bone_global_pose(sk.find_bone(name))
	return values


func _locals() -> Dictionary:
	_globals()
	var values := {}
	for name: String in BONES:
		values[name] = sk.get_bone_pose(sk.find_bone(name))
	return values


func _normal_transition() -> void:
	_air_fall()
	var before := _globals()
	var before_local := _locals()
	moves._helpless = true
	# A state change itself must not change the displayed pose before blend time advances.
	pose._tick_ring(0.0, moves)
	pose._apply()
	var after := _globals()
	var position_jump := 0.0
	var rotation_jump := 0.0
	var rotation_dot_error := 0.0
	for name: String in BONES:
		var a: Transform3D = before[name]
		var b: Transform3D = after[name]
		position_jump = maxf(position_jump, a.origin.distance_to(b.origin))
		var qa := a.basis.get_rotation_quaternion().normalized()
		var qb := b.basis.get_rotation_quaternion().normalized()
		rotation_jump = maxf(rotation_jump, qa.angle_to(qb))
		rotation_dot_error = maxf(rotation_dot_error, 1.0 - absf(qa.dot(qb)))
	# angle_to's acos amplifies float noise near 1; compare the quaternion dot directly for equality.
	_check(position_jump < 0.0001 and rotation_dot_error < 0.000001,
			"fall to helpless begins continuously, including root translation (jump %.4f m, %.2f deg)" %
			[position_jump, rad_to_deg(rotation_jump)])
	pose._tick_ring(SwayPose.RING_IN_S * 0.5, moves)
	pose._apply()
	var middle := _locals()
	var middle_layers := pose._pose.layers.duplicate()
	pose._pose.layers = [{"anim": pose._r_anim, "time": pose._r_t, "weight": 1.0, "mask": "full"}]
	var incoming := _locals()
	pose._pose.layers = middle_layers
	var middle_position_error := 0.0
	var middle_rotation_error := 0.0
	for name: String in BONES:
		var a: Transform3D = before_local[name]
		var b: Transform3D = incoming[name]
		var shown: Transform3D = middle[name]
		var want_rotation := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), 0.5).normalized()
		middle_rotation_error = maxf(middle_rotation_error,
				1.0 - absf(want_rotation.dot(shown.basis.get_rotation_quaternion().normalized())))
		if name in ["root", "pelvis"]:
			middle_position_error = maxf(middle_position_error, shown.origin.distance_to(a.origin.lerp(b.origin, 0.5)))
	_check(middle_position_error < 0.0001 and middle_rotation_error < 0.000001,
			"handoff midpoint blends old to new without exposing the base pose (position error %.4f m, quaternion error %.7f)" %
			[middle_position_error, middle_rotation_error])
	# The blend must actually complete, so retaining the old pose forever cannot satisfy the first assertion.
	pose._tick_ring(0.2, moves)
	pose._apply()
	var settled := _globals()
	var layers := pose._pose.layers.duplicate()
	pose._pose.layers = [{"anim": pose._r_anim, "time": pose._r_t, "weight": 1.0, "mask": "full"}]
	var expected := _globals()
	pose._pose.layers = layers
	var error := (settled.heada as Transform3D).origin.distance_to((expected.heada as Transform3D).origin)
	_check(error < 0.0001, "normal transition reaches the next pose (head error %.4f m)" % error)


func _air_cast_visible() -> void:
	_air_fall()
	var clip := BendPoses.animation("own-bend-air-hit-fire")
	var time := float(clip.get_meta(&"strike_s", clip.length * 0.5))
	pose.phase = "release"
	pose._cast_layers = [{"anim": clip, "time": time, "weight": 1.0, "mask": "full"}]
	pose._pose.layers = pose._cast_layers
	var expected := _globals()
	pose._apply()
	var shown := _globals()
	var kick_error := (shown.r_ball as Transform3D).origin.distance_to((expected.r_ball as Transform3D).origin)
	_check(kick_error < 0.0001, "air kick remains visible over ordinary falling (striking foot error %.4f m)" % kick_error)
	pose.phase = ""
	pose._cast_layers = []


func _interrupted_and_finished_transition() -> void:
	_air_fall()
	moves._helpless = true
	pose._tick_ring(0.03, moves)
	pose._apply()
	var before := _globals()
	moves._helpless = false
	moves._ff = true
	pose._tick_ring(0.0, moves)
	pose._apply()
	var after := _globals()
	var jump := 0.0
	for name: String in BONES:
		jump = maxf(jump, (before[name] as Transform3D).origin.distance_to((after[name] as Transform3D).origin))
	_check(jump < 0.0001, "interrupting a handoff preserves the currently displayed pose (jump %.4f m)" % jump)
	moves._air = false
	moves._ff = false
	moves._vfloor = true
	pose._tick_ring(0.3, moves)
	pose._apply()
	_check(pose._ring_layers().is_empty() and pose._r_from.is_empty(), "return to locomotion clears every outgoing ring layer")
	_air_fall()
	moves._helpless = true
	pose._tick_ring(0.03, moves)
	player.is_dead = true
	pose._tick_ring(0.0, moves)
	pose._apply()
	_check(pose._ring_layers().is_empty() and pose._r_from.is_empty(), "death clears an interrupted handoff")
	player.is_dead = false
	_air_fall()
	moves._helpless = true
	pose._tick_ring(0.03, moves)
	moves.mode = "spout"
	pose._tick_ring(0.0, moves)
	pose._apply()
	_check(pose._r_from.is_empty() and pose._r_mix == 1.0 and pose.ring_clip() == &"own-bend-spout-ride",
			"respawn spout clears the previous airborne handoff immediately")
	moves.mode = ""


func _recovery_contact() -> void:
	_air_fall()
	var kick := BendPoses.animation("own-bend-air-hit-fire")
	pose.phase = "release"
	pose._cast_layers = [{"anim": kick, "time": float(kick.get_meta(&"strike_s", 0.0)), "weight": 1.0, "mask": "full"}]
	moves.mode = "wall"
	# The wall tech plants its hands/feet at 1/30 s; an 80 ms entry fade would miss that contact.
	pose._tick_ring(1.0 / 30.0, moves)
	pose._apply()
	var shown := _globals()
	var layers := pose._pose.layers.duplicate()
	pose._pose.layers = [{"anim": pose._r_anim, "time": pose._r_t, "weight": 1.0, "mask": "full"}]
	var expected := _globals()
	pose._pose.layers = layers
	var error := (shown.r_palm as Transform3D).origin.distance_to((expected.r_palm as Transform3D).origin)
	_check(error < 0.0001, "wall recovery owns the body and reaches its authored contact on time (palm error %.4f m)" % error)
	pose.phase = ""
	pose._cast_layers = []
	moves.mode = ""


func _air_legs_visible() -> void:
	_air_fall()
	pose.phase = "release"
	pose._al_anim = BendPoses.animation("own-bend-air-legs")
	pose._al_t = 0.2
	pose._al_w = 1.0
	var cast := BendPoses.animation("own-bend-air-palm")
	pose._cast_layers = [{"anim": cast, "time": float(cast.get_meta(&"strike_s", 0.0)), "weight": 1.0, "mask": "upper"}]
	pose._pose.layers = [{"anim": pose._r_anim, "time": pose._r_t, "weight": 1.0, "mask": "full"},
			{"anim": pose._al_anim, "time": pose._al_t, "weight": 1.0, "mask": "full"}]
	var expected := _globals()
	pose._apply()
	var shown := _globals()
	var error := (shown.r_ball as Transform3D).origin.distance_to((expected.r_ball as Transform3D).origin)
	_check(error < 0.0001, "airborne upper-body cast keeps its leg tuck over falling (foot error %.4f m)" % error)
	pose._al_anim = null
	pose._al_w = 0.0
	pose.phase = ""
	pose._cast_layers = []


func _contact_and_reset() -> void:
	var clip := BendPoses.animation("own-bend-hit-impact-front")
	var at := float(clip.get_meta(&"hold_s", 0.0))
	player.set_meta(BendImpact.STRUCK_META, {"clip": "own-bend-hit-impact-front", "at": 1.0, "until": 2.0})
	pose._tick_struck(0.0)
	pose._apply()
	var shown := _globals()
	var layers := pose._pose.layers.duplicate()
	pose._pose.layers = [{"anim": clip, "time": at, "weight": 1.0, "mask": "full"}]
	var expected := _globals()
	pose._pose.layers = layers
	var contact_error := (shown.heada as Transform3D).origin.distance_to((expected.heada as Transform3D).origin)
	_check(contact_error < 0.0001 and pose.struck_weight() == 1.0,
			"hit contact remains immediate, over the movement pose (head error %.4f m)" % contact_error)
	BendImpact.clear_pose(player)
	pose._tick_struck(0.0)
	pose._apply()
	_check(pose.struck_clip() == &"" and pose.struck_weight() == 0.0,
			"reset clears the cached struck layer immediately (weight %.3f)" % pose.struck_weight())
