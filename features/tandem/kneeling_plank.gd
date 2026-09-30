extends "res://features/tandem/yoga_motion.gd"
## Kneeling plank base, followed by the shared wave/sway layer.
var knees := {"l": Vector3(0.17, 0.055, -0.25), "r": Vector3(-0.17, 0.055, -0.25)}
var _lower: Dictionary = {}
var thigh_alignment_error := 0.0
@export var tuck_length := 0.65
@export var flinch_wave_gain := 2.5
var _flinch_defaults := {}
func tuck() -> void:
	cancel()
	_flinch_defaults = {"duration": duration, "wave_gain": wave_gain}
	duration = tuck_length
	wave_gain = flinch_wave_gain
	super.play_motion("wave")
func play_motion(which: String, start_ms: int = -1) -> void:
	cancel()
	super.play_motion(which, start_ms)
func cancel() -> void:
	super.cancel()
	if not _flinch_defaults.is_empty():
		duration = _flinch_defaults.duration
		wave_gain = _flinch_defaults.wave_gain
		_flinch_defaults.clear()
func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null: return
	var source: Array[Transform3D] = []
	for i in sk.get_bone_count(): source.append(sk.get_bone_global_pose(i))
	var wrist_bases := {}
	for side: String in ["l", "r"]: wrist_bases[side] = source[sk.find_bone(side + "_wrist")].basis
	var palms := {}
	for side: String in ["l", "r"]: palms[side] = source[sk.find_bone(side + "_palm")].origin
	# Keep the continuous flow centered over Happy Baby instead of letting the
	# imported fore/aft root sway drift the hip alignment.
	var recenter := 0.040579 - source[sk.find_bone("pelvis")].origin.z
	for i in source.size(): source[i].origin.z += recenter
	var center := source[sk.find_bone("pelvis")].origin
	var y := 0.0
	var roll := 0.0
	for iteration in 12:
		var error := _ground_error(sk, source, center, y, roll)
		if error.length() < 0.000001: break
		var dy := (_ground_error(sk, source, center, y + 0.0001, roll) - error) / 0.0001
		var dr := (_ground_error(sk, source, center, y, roll + 0.0001) - error) / 0.0001
		var det := dy.x * dr.y - dr.x * dy.y
		if absf(det) < 0.000001: break
		y -= (error.x * dr.y - dr.x * error.y) / det
		roll -= (dy.x * error.y - error.x * dy.y) / det
	var rotation := Basis(Vector3(0, 0, 1), roll)
	for i in sk.get_bone_count():
		var pose := source[i]
		sk.set_bone_global_pose(i, Transform3D(rotation * pose.basis, center + rotation * (pose.origin - center) + Vector3.UP * y))
	for side: String in ["l", "r"]:
		var hip := sk.find_bone(side + "_upper_leg")
		var knee := sk.find_bone(side + "_knee")
		var ankle := sk.find_bone(side + "_ankle")
		var ball := sk.find_bone(side + "_ball")
		var pose := sk.get_bone_global_pose(hip)
		var direction := sk.get_bone_global_pose(knee).origin - pose.origin
		sk.set_bone_global_pose(hip, Transform3D(Basis(_arc(direction.normalized(), (knees[side] - pose.origin).normalized())) * pose.basis, pose.origin))
		if _lower.is_empty() or not _lower.has(knee):
			var shin_length := source[knee].origin.distance_to(source[ankle].origin)
			var target: Vector3 = knees[side] + Vector3(0, 0.01, -sqrt(shin_length * shin_length - 0.0001))
			pose = sk.get_bone_global_pose(knee)
			direction = sk.get_bone_global_pose(ankle).origin - pose.origin
			sk.set_bone_global_pose(knee, Transform3D(Basis(_arc(direction.normalized(), (target - pose.origin).normalized())) * pose.basis, pose.origin))
			pose = sk.get_bone_global_pose(ankle)
			sk.set_bone_global_pose(ankle, Transform3D(source[ankle].basis, pose.origin))
			var foot_length := source[ankle].origin.distance_to(source[ball].origin)
			pose = sk.get_bone_global_pose(ankle)
			direction = sk.get_bone_global_pose(ball).origin - pose.origin
			sk.set_bone_global_pose(ankle, Transform3D(Basis(_arc(direction.normalized(), Vector3(0, -0.025, -sqrt(foot_length * foot_length - 0.000625)).normalized())) * pose.basis, pose.origin))
			var todo: Array[int] = [knee]
			while not todo.is_empty():
				var i: int = todo.pop_back()
				_lower[i] = sk.get_bone_global_pose(i)
				for child in sk.get_bone_children(i): todo.append(child)
		# Restore only this side. Restoring both knees here made the right knee
		# appear solved before its thigh was bent, leaving the right thigh in plank.
		var restore: Array[int] = [knee]
		while not restore.is_empty():
			var i: int = restore.pop_back()
			sk.set_bone_global_pose(i, _lower[i])
			for child in sk.get_bone_children(i): restore.append(child)
	# Keep both palms on the floor as the authored flow/dip changes the trunk height.
	for side: String in ["l", "r"]:
		var wrist := sk.find_bone(side + "_wrist")
		var palm := sk.find_bone(side + "_palm")
		var pose := sk.get_bone_global_pose(wrist)
		sk.set_bone_global_pose(wrist, Transform3D(wrist_bases[side], pose.origin))
		apply_side(sk, side, palms[side], 1.0)
	super._process_modification()
	thigh_alignment_error = 0.0
	for side: String in ["l", "r"]:
		var hip := sk.find_bone(side + "_upper_leg")
		var knee := sk.find_bone(side + "_knee")
		var axis := source[hip].basis.inverse() * (source[knee].origin - source[hip].origin)
		var pose := sk.get_bone_global_pose(hip)
		var expected := (pose.basis * axis).normalized()
		var actual := (sk.get_bone_global_pose(knee).origin - pose.origin).normalized()
		thigh_alignment_error = maxf(thigh_alignment_error, rad_to_deg(expected.angle_to(actual)))
func _ground_error(sk: Skeleton3D, source: Array[Transform3D], center: Vector3, y: float, roll: float) -> Vector2:
	var out := Vector2.ZERO
	for index in 2:
		var side := "l" if index == 0 else "r"
		var hip := sk.find_bone(side + "_upper_leg")
		var knee := sk.find_bone(side + "_knee")
		var at := center + Basis(Vector3(0, 0, 1), roll) * (source[hip].origin - center) + Vector3.UP * y
		out[index] = at.distance_to(knees[side]) - source[hip].origin.distance_to(source[knee].origin)
	return out
