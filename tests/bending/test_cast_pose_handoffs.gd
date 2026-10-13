extends SceneTree
## Actual rig/clip regressions for cast replacement, cancellation and live locomotion masks.
## Godot --headless --path . -s tests/bending/test_cast_pose_handoffs.gd

const BONES := ["root", "pelvis", "spined", "heada", "r_palm", "l_palm", "r_ball", "l_ball"]
var checked := 0
var failed := 0
var rig: Node3D
var sk: Skeleton3D
var player: FrontierPlayer
var caster: SwayCaster
var pose: SwayPose
var strike_times: Array[float] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checked += 1
	failed += 0 if ok else 1
	print(("  ok   " if ok else "  FAIL ") + label)


func _run() -> void:
	rig = (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(rig)
	sk = rig.get_node(^"Skeleton3D") as Skeleton3D
	sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
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
	pose.struck.connect(func(_move: String) -> void: strike_times.append(pose.clip_t))
	_chain()
	_cancel()
	_strike_deadline()
	_interrupted()
	_masks_and_base()
	_landing()
	_unsampled_mask()
	_recovery_cast_visible()
	player.free()
	rig.free()
	print("CAST POSE HANDOFFS %s (%d/%d)" % ["PASSED" if failed == 0 else "FAILED", checked - failed, checked])
	quit(0 if failed == 0 else 1)


func _start(clip: StringName, at: float, mask := "full") -> void:
	pose._stop()
	pose.pick = {"mask": mask, "hold_s": at}
	pose.move = "fire_blast"
	pose._begin(clip, "press")
	pose._tick(maxf(at, 0.2))
	pose._apply()
	_sample(pose._pose.layers)


func _sample(layers: Array, moving_base := false, globals := true) -> Dictionary:
	sk.reset_bone_poses()
	if moving_base:
		var root_id := sk.find_bone("root")
		var foot_id := sk.find_bone("r_ball")
		sk.set_bone_pose_position(root_id, sk.get_bone_pose_position(root_id) + Vector3(0.12, 0.05, -0.08))
		sk.set_bone_pose_rotation(foot_id, Quaternion(Vector3.RIGHT, 0.3) * sk.get_bone_pose_rotation(foot_id))
	# Scale is not owned by ToolPose; even a temporary blend must preserve it.
	sk.set_bone_pose_scale(sk.find_bone("pelvis"), Vector3(1.03, 0.99, 1.04))
	pose._pose.layers = layers
	pose._pose._process_modification()
	var out := {}
	for bone: String in BONES:
		var id := sk.find_bone(bone)
		out[bone] = sk.get_bone_global_pose(id) if globals else sk.get_bone_pose(id)
	return out


func _distance(a: Dictionary, b: Dictionary) -> float:
	var error := 0.0
	for bone: String in BONES:
		error = maxf(error, (a[bone] as Transform3D).origin.distance_to((b[bone] as Transform3D).origin))
	return error


func _rotation_error(a: Dictionary, b: Dictionary) -> float:
	var error := 0.0
	for bone: String in BONES:
		var qa := (a[bone] as Transform3D).basis.get_rotation_quaternion().normalized()
		var qb := (b[bone] as Transform3D).basis.get_rotation_quaternion().normalized()
		error = maxf(error, 1.0 - absf(qa.dot(qb)))
	return error


func _chain() -> void:
	_start(&"own-bend-fire-punch", 0.28)
	var before := _sample(pose._pose.layers)
	pose._begin(&"own-bend-fire-punch-l", "press")
	pose._tick(0.0)
	pose._apply()
	var after := _sample(pose._pose.layers)
	var jump := _distance(before, after)
	_check(jump < 0.0001 and _rotation_error(before, after) < 0.000001,
			"alternate-hand cast starts continuously (maximum joint jump %.6f m)" % jump)
	pose._tick(0.08)
	pose._apply()
	var shown := _sample(pose._pose.layers)
	var target := _sample([{"anim": pose._anim, "time": pose.clip_time(), "weight": pose.weight, "mask": "full"}])
	_check(_distance(shown, target) < 0.0001, "new cast reaches its own pose within 80 ms")
	_check(absf(pose.clip_time() - 0.08) < 0.000001, "handoff does not retard the cast clip clock")


func _cancel() -> void:
	_start(&"own-bend-throw-overhand", 0.30)
	pose.pick["back_s"] = 0.68
	var before := _sample(pose._pose.layers)
	pose._on_end()
	pose._tick(0.0)
	pose._apply()
	var after := _sample(pose._pose.layers)
	var jump := _distance(before, after)
	_check(jump < 0.0001 and _rotation_error(before, after) < 0.000001,
			"cancelling a held Spike preserves the displayed pose (joint jump %.6f m)" % jump)
	_check(pose.phase == "up" and absf(pose.clip_time() - 0.68) < 0.000001,
			"cancel recovery keeps its existing clip-time jump")
	pose._tick(0.08)
	pose._apply()
	var shown := _sample(pose._pose.layers)
	var target := _sample([{"anim": pose._anim, "time": pose.clip_time(), "weight": pose.weight, "mask": "full"}])
	_check(_distance(shown, target) < 0.0001, "cancel blend finishes into the actual recovery sample")


func _strike_deadline() -> void:
	_start(&"own-bend-fire-punch", 0.25)
	strike_times.clear()
	pose._strike = 0.035
	pose._struck = false
	pose._begin(&"own-bend-fire-punch-l", "release", 0.0)
	pose._tick(0.02)
	pose._apply()
	_sample(pose._pose.layers)
	_check(strike_times.is_empty(), "incoming strike is not fired early")
	pose._tick(0.015)
	pose._apply()
	var shown := _sample(pose._pose.layers)
	var target := _sample([{"anim": pose._anim, "time": 0.035, "weight": pose.weight, "mask": "full"}])
	_check(strike_times.size() == 1 and absf(strike_times[0] - 0.035) < 0.000001,
			"strike fires once at its unchanged deadline")
	_check(_distance(shown, target) < 0.0001, "short strike deadline reaches the authored strike pose without blend lag")
	pose._tick(0.1)
	_check(strike_times.size() == 1, "later ticks do not repeat the strike")
	# A normal same-clip release carries on from its held time, without a new blend.
	_start(&"own-bend-fire-punch", 0.2)
	var at := pose.clip_time()
	pose._begin(&"own-bend-fire-punch", "release", at)
	pose._tick(0.02)
	pose._apply()
	shown = _sample(pose._pose.layers)
	target = _sample([{"anim": pose._anim, "time": at + 0.02, "weight": pose.weight, "mask": "full"}])
	_check(_distance(shown, target) < 0.0001, "continuous press-to-release remains direct clip playback")


func _groups(layers: Array) -> int:
	var n := 0
	for layer: Dictionary in layers:
		if layer.has("blend_from"):
			n += 1 + _groups(layer.blend_from) + _groups(layer.blend_to)
	return n


func _interrupted() -> void:
	_start(&"own-bend-fire-punch", 0.25)
	var maximum_jump := 0.0
	var maximum_groups := 0
	for i in 24:
		var before := _sample(pose._pose.layers, true)
		pose._begin(&"own-bend-fire-punch-l" if i % 2 == 0 else &"own-bend-fire-punch", "press")
		pose._tick(0.0)
		pose._apply()
		maximum_groups = maxi(maximum_groups, _groups(pose._pose.layers))
		var after := _sample(pose._pose.layers, true)
		maximum_jump = maxf(maximum_jump, _distance(before, after))
		pose._tick(0.02)
		pose._apply()
		_sample(pose._pose.layers, true)
	_check(maximum_jump < 0.0001, "24 interrupted switches preserve the visible pose (max %.6f m)" % maximum_jump)
	_check(maximum_groups <= 1, "interrupted switches retain at most one blend group (%d)" % maximum_groups)
	pose._stop()
	pose._apply()
	_check(pose._cast_layers.is_empty() and pose._pose.layers.is_empty(), "stop clears cast and transition layers")


func _masks_and_base() -> void:
	var from := [{"anim": BendPoses.animation("own-bend-earth-hammer"), "time": 0.25, "weight": 0.35, "mask": "full"}]
	var to := [{"anim": BendPoses.animation("own-bend-fire-punch-l"), "time": 0.1, "weight": 0.6, "mask": "upper"}]
	for moving in [false, true]:
		var a := _sample(from, moving, false)
		var b := _sample(to, moving, false)
		var shown := _sample([{"blend_from": from, "blend_to": to, "blend_weight": 0.5}], moving, false)
		var expected := {}
		for bone: String in BONES:
			var ta: Transform3D = a[bone]
			var tb: Transform3D = b[bone]
			var q := ta.basis.get_rotation_quaternion().slerp(tb.basis.get_rotation_quaternion(), 0.5)
			expected[bone] = Transform3D(Basis(q).scaled(ta.basis.get_scale()), ta.origin.lerp(tb.origin, 0.5))
		_check(_distance(shown, expected) < 0.0001 and _rotation_error(shown, expected) < 0.000001,
				"partial full-to-upper blend uses the same %s locomotion base on both sides" % ("moving" if moving else "still"))
		_check((shown.pelvis as Transform3D).basis.get_scale().distance_to(Vector3(1.03, 0.99, 1.04)) < 0.00001,
				"blend preserves scale on %s base" % ("moving" if moving else "still"))
		var start := _sample([{"blend_from": from, "blend_to": to, "blend_weight": 0.0}], moving, false)
		var finish := _sample([{"blend_from": from, "blend_to": to, "blend_weight": 1.0}], moving, false)
		_check(_distance(start, a) < 0.0001 and _rotation_error(start, a) < 0.000001
				and _distance(finish, b) < 0.0001 and _rotation_error(finish, b) < 0.000001,
				"group endpoints equal ordinary unmodified layer evaluation (%s base)" % ("moving" if moving else "still"))


func _landing() -> void:
	var moves := RingMoves.new()
	moves.virtual = true
	moves.body = player
	player.add_child(moves)
	player.ring_moves = moves
	pose._ring_lean = true
	for heavy in [false, true]:
		pose._clear_ring()
		moves._lag = 0.0
		moves._air = true
		moves._vfloor = false
		moves._o = Vector3(0.0, -3.0, 0.0)
		moves._t = 10.0
		_start(&"own-bend-throw-overhand", 0.30)
		pose._tick_ring(0.2, moves)
		pose._apply()
		var before := _sample(pose._pose.layers, false, false)
		moves._air = false
		moves._vfloor = true
		moves._lag = 0.15
		moves._lag_heavy = heavy
		moves._o = Vector3.ZERO
		pose._tick_ring(0.0, moves)
		pose._apply()
		var layers := pose._pose.layers.duplicate()
		var after := _sample(layers, false, false)
		var target_layers := [{"anim": pose._r_anim, "time": pose._r_t, "weight": 1.0, "mask": "full"}]
		var target := _sample(target_layers, false, false)
		var upper_error := 0.0
		for bone: String in ["spined", "heada", "r_palm", "l_palm"]:
			var qa := (before[bone] as Transform3D).basis.get_rotation_quaternion().normalized()
			var qb := (after[bone] as Transform3D).basis.get_rotation_quaternion().normalized()
			upper_error = maxf(upper_error, 1.0 - absf(qa.dot(qb)))
		_check(upper_error < 0.000001, "%s landing retains the outgoing local upper-body pose at entry" % ("heavy" if heavy else "light"))
		var shown_world := _sample(layers)
		var target_world := _sample(target_layers)
		var foot_error := maxf((shown_world.r_ball as Transform3D).origin.distance_to((target_world.r_ball as Transform3D).origin),
				(shown_world.l_ball as Transform3D).origin.distance_to((target_world.l_ball as Transform3D).origin))
		_check(foot_error < 0.0001 and (after.pelvis as Transform3D).origin.distance_to((target.pelvis as Transform3D).origin) < 0.0001,
				"%s landing keeps authored feet and hips immediate (foot error %.6f m)" % ["heavy" if heavy else "light", foot_error])
		pose._tick_ring(0.08, moves)
		pose._apply()
		var settled := _sample(pose._pose.layers)
		var expected := _sample([{"anim": pose._r_anim, "time": pose._r_t, "weight": 1.0, "mask": "full"}])
		_check(_distance(settled, expected) < 0.0001, "%s landing reaches the full authored pose by 80 ms" % ("heavy" if heavy else "light"))
	pose._clear_ring()
	player.ring_moves = null
	moves.free()


func _unsampled_mask() -> void:
	var source := [{"anim": BendPoses.animation("own-bend-earth-hammer"), "time": 0.25, "weight": 1.0, "mask": "full"}]
	# No modifier evaluation occurs between these switches. The pending landing scope must survive collapse.
	var collapsed: Array = source
	for i in 24:
		collapsed = ToolPose.collapse_layers([{"blend_from": collapsed, "blend_to": [], "blend_weight": 0.0, "blend_mask": "upper"}])
	var base := _sample([], true)
	var shown := _sample(collapsed, true)
	var foot_error := maxf((base.r_ball as Transform3D).origin.distance_to((shown.r_ball as Transform3D).origin),
			(base.l_ball as Transform3D).origin.distance_to((shown.l_ball as Transform3D).origin))
	_check(foot_error < 0.0001 and (base.pelvis as Transform3D).origin.distance_to((shown.pelvis as Transform3D).origin) < 0.0001,
			"unsampled upper-only interruptions never capture the feet/hips (foot error %.6f m)" % foot_error)
	var expected := _sample([{"anim": source[0].anim, "time": 0.25, "weight": 1.0, "mask": "upper"}], true)
	_check(_distance(shown, expected) < 0.0001 and _rotation_error(shown, expected) < 0.000001,
			"unsampled mask collapse preserves the intended upper-body sample")
	_check(_groups(collapsed) == 0 and collapsed.size() == 1 and (collapsed[0].get("scope_masks", []) as Array).size() == 1,
			"24 unsampled interruptions retain one ordinary layer and one unique mask")


func _recovery_cast_visible() -> void:
	var moves := RingMoves.new()
	moves.virtual = true
	moves.body = player
	player.add_child(moves)
	player.ring_moves = moves
	pose._ring_lean = true
	pose._stop()
	pose._clear_ring()
	moves.mode = "rise"
	moves._m = {"el": "earth"}
	moves._air = true
	moves._vfloor = false
	moves._o = Vector3.UP * 3.0
	moves._t = 10.0
	pose._tick_ring(0.3, moves)
	pose._apply()
	_sample(pose._pose.layers)
	# Recovery finishes while still travelling upward, before the ordinary fall clip becomes eligible.
	moves.mode = ""
	moves._helpless = false
	moves.rise_ready = false
	moves.jumps_left = 0
	var attack := BendPoses.animation("own-bend-air-hit-earth")
	pose.phase = "release"
	pose._cast_layers = [{"anim": attack, "time": float(attack.get_meta(&"strike_s", 0.25)), "weight": 1.0, "mask": "full"}]
	pose._tick_ring(1.0 / 60.0, moves)
	pose._apply()
	var shown := _sample(pose._pose.layers)
	var target := _sample(pose._cast_layers)
	_check(moves.clip_state() == "" and pose._r_w > 0.0 and _distance(shown, target) < 0.0001,
			"a free upward Rise exit fades beneath the follow-up aerial strike (joint error %.6f m)" % _distance(shown, target))
	pose._stop()
	pose._clear_ring()
	player.ring_moves = null
	moves.free()
