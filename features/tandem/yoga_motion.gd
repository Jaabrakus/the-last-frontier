extends PalmReachIK
## Presentation-only wave/sway after the base pose; grounded lower legs remain fixed.
@export var puppy_pose := false
@export var crawl_pose := false
@export var crawl_chest_raise_degrees := 8.0
var crawl_support := 0.0
var support_chest_lift := 0.0
var support_palm_miss := 0.0
var torso_drift := 0.0
var torso_turn := 0.0
var _crawl_sway_anchor: Dictionary = {}
@export var duration := 1.8
@export var wave_gain := 1.0
@export var puppy_wave_pitch_degrees := 16.0
@export var puppy_wave_forward := 0.025
@export var puppy_torso_forward := 0.01
var kind := ""
var started_ms := 0
var pelvis_world := Transform3D.IDENTITY
var back_world := Vector3.ZERO
var chest_world := Transform3D.IDENTITY
var moving := false
var planted_error := 0.0
var length_error := 0.0
var palm_miss := 0.0
var elbow_lift := 0.0
var hand_slide := 0.0
var chest_drift := 0.0
var _poses: Array[Transform3D] = []
func play_motion(which: String, start_ms: int = -1) -> void:
	if which not in ["wave", "sway"]: return
	_crawl_sway_anchor.clear()
	kind = which
	started_ms = Time.get_ticks_msec() if start_ms < 0 else start_ms
	moving = true
func cancel() -> void:
	kind = ""
	moving = false
	_crawl_sway_anchor.clear()
func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null: return
	var pelvis := sk.find_bone("pelvis")
	var back := sk.find_bone("spineb")
	if pelvis < 0 or back < 0: return
	var t := float(Time.get_ticks_msec() - started_ms) / (duration * 1000.0)
	if moving and t >= 1.0: cancel()
	if crawl_pose:
		_raise_crawl_chest(sk)
		if moving and kind == "sway" and t >= 0.0:
			if _crawl_sway_anchor.is_empty():
				var todo: Array[int] = [sk.find_bone("upper_base")]
				while not todo.is_empty():
					var i: int = todo.pop_back()
					_crawl_sway_anchor[i] = sk.get_bone_global_pose(i)
					for child in sk.get_bone_children(i): todo.append(child)
			for i: int in _crawl_sway_anchor: sk.set_bone_global_pose(i, _crawl_sway_anchor[i])
	if moving:
		_poses.clear()
		for i in sk.get_bone_count(): _poses.append(sk.get_bone_global_pose(i))
		var envelope := pow(sin(PI * clampf(t, 0.0, 1.0)), 2.0)
		var cycle := sin(TAU * t)
		var pitch_degrees := 8.0
		if puppy_pose: pitch_degrees += (puppy_wave_pitch_degrees - 8.0) * pow(maxf(cycle, 0.0), 2.0)
		var pitch := deg_to_rad(pitch_degrees) * cycle * envelope if kind == "wave" else 0.0
		var forward := puppy_wave_forward if puppy_pose and kind == "wave" else 0.025
		if kind == "wave":
			pitch *= wave_gain
			forward *= wave_gain
		var shift := Vector3(0.025 * cycle * envelope if kind == "sway" else 0.0, 0, 0.0 if crawl_pose and kind == "sway" else forward * envelope)
		var pivot := _poses[pelvis].origin
		var y := 0.0
		var roll := 0.0
		# Solve pelvis height and roll against both fixed knees, preserving thigh lengths.
		for iteration in 12:
			var error := _leg_error(sk, pivot, shift + Vector3.UP * y, pitch, roll)
			if error.length() < 0.000001: break
			var dy := (_leg_error(sk, pivot, shift + Vector3.UP * (y + 0.0001), pitch, roll) - error) / 0.0001
			var dr := (_leg_error(sk, pivot, shift + Vector3.UP * y, pitch, roll + 0.0001) - error) / 0.0001
			var det := dy.x * dr.y - dr.x * dy.y
			if absf(det) < 0.000001: break
			y -= (error.x * dr.y - dr.x * error.y) / det
			roll -= (dy.x * error.y - error.x * dy.y) / det
		var rotation := Basis(Vector3(0, 0, 1), roll) * Basis(Vector3.RIGHT, pitch)
		for i in sk.get_bone_count():
			var pose := _poses[i]
			sk.set_bone_global_pose(i, Transform3D(rotation * pose.basis, pivot + rotation * (pose.origin - pivot) + shift + Vector3.UP * y))
		# Re-aim the thighs, then restore every bone from each knee downward.
		for side: String in ["l", "r"]:
			var hip := sk.find_bone(side + "_upper_leg")
			var knee := sk.find_bone(side + "_knee")
			var h := sk.get_bone_global_pose(hip)
			var old_direction := sk.get_bone_global_pose(knee).origin - h.origin
			var direction := _poses[knee].origin - h.origin
			sk.set_bone_global_pose(hip, Transform3D(Basis(_arc(old_direction.normalized(), direction.normalized())) * h.basis, h.origin))
			var todo: Array[int] = [knee]
			while not todo.is_empty():
				var bone: int = todo.pop_back()
				sk.set_bone_global_pose(bone, _poses[bone])
				for child in sk.get_bone_children(bone): todo.append(child)
		# In puppy, the waist moves under an almost stationary chest. Other poses
		# retain their existing upper-spine response.
		if puppy_pose: _anchor_chest(sk, envelope)
		else:
			for name: String in ["spineb", "spinec"]:
				var i := sk.find_bone(name)
				var pose := sk.get_bone_global_pose(i)
				sk.set_bone_global_pose(i, Transform3D(Basis(Vector3.RIGHT, -pitch * 0.35) * pose.basis, pose.origin))
		if puppy_pose:
			palm_miss = 0.0
			elbow_lift = 0.0
			hand_slide = 0.0
			for side: String in ["l", "r"]:
				_ground_forearm(sk, side)
		if crawl_pose:
			for side: String in ["l", "r"]:
				var wrist := sk.find_bone(side + "_wrist")
				var pose := sk.get_bone_global_pose(wrist)
				sk.set_bone_global_pose(wrist, Transform3D(_poses[wrist].basis, pose.origin))
				apply_side(sk, side, _poses[sk.find_bone(side + "_palm")].origin, 1.0)
			var chest := sk.find_bone("spined")
			torso_drift = sk.get_bone_global_pose(chest).origin.distance_to(_poses[chest].origin)
			torso_turn = sk.get_bone_global_pose(chest).basis.get_rotation_quaternion().angle_to(_poses[chest].basis.get_rotation_quaternion())
		planted_error = 0.0
		length_error = 0.0
		for i in sk.get_bone_count():
			var parent := sk.get_bone_parent(i)
			if parent >= 0:
				# The zero-length base controls translate independently; check all deforming segments.
				if crawl_pose and kind == "sway" and sk.get_bone_name(i) in ["upper_base", "lower_base"]: continue
				length_error = maxf(length_error, absf(sk.get_bone_global_pose(i).origin.distance_to(sk.get_bone_global_pose(parent).origin) - _poses[i].origin.distance_to(_poses[parent].origin)))
		for side: String in ["l", "r"]:
			for name: String in ["knee", "ankle", "ball"]:
				var i := sk.find_bone(side + "_" + name)
				planted_error = maxf(planted_error, sk.get_bone_global_pose(i).origin.distance_to(_poses[i].origin))
	pelvis_world = sk.global_transform * sk.get_bone_global_pose(pelvis)
	back_world = sk.global_transform * sk.get_bone_global_pose(back).origin
	chest_world = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("spined"))
func _leg_error(sk: Skeleton3D, pivot: Vector3, shift: Vector3, pitch: float, roll: float) -> Vector2:
	var rotation := Basis(Vector3(0, 0, 1), roll) * Basis(Vector3.RIGHT, pitch)
	var out := Vector2.ZERO
	for index in 2:
		var side := "l" if index == 0 else "r"
		var hip := sk.find_bone(side + "_upper_leg")
		var knee := sk.find_bone(side + "_knee")
		var at := pivot + rotation * (_poses[hip].origin - pivot) + shift
		out[index] = at.distance_to(_poses[knee].origin) - _poses[hip].origin.distance_to(_poses[knee].origin)
	return out

## Solve clavicle + upper arm to the planted elbow, then restore the complete
## forearm/hand subtree. This fixes both elbow and palm contact without stretching.
func _ground_forearm(sk: Skeleton3D, side: String) -> void:
	var c := sk.find_bone(side + "_clavicle")
	var s := sk.find_bone(side + "_shoulder")
	var e := sk.find_bone(side + "_elbow")
	var a := sk.get_bone_global_pose(c).origin
	var target := _poses[e].origin
	var upper := _poses[c].origin.distance_to(_poses[s].origin)
	var lower := _poses[s].origin.distance_to(_poses[e].origin)
	var distance := clampf(a.distance_to(target), absf(upper - lower) + 0.0001, (upper + lower) * MAX_REACH)
	var direction := (target - a).normalized()
	var pole := _poses[s].origin - _poses[c].origin
	pole = (pole - direction * pole.dot(direction)).normalized()
	var along := (upper * upper + distance * distance - lower * lower) / (2.0 * distance)
	var shoulder := a + direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along))
	var q := _arc((_poses[s].origin - _poses[c].origin).normalized(), (shoulder - a).normalized())
	sk.set_bone_global_pose(c, Transform3D(Basis(q) * _poses[c].basis, a))
	var at := sk.get_bone_global_pose(s).origin
	q = _arc((_poses[e].origin - _poses[s].origin).normalized(), (target - at).normalized())
	sk.set_bone_global_pose(s, Transform3D(Basis(q) * _poses[s].basis, at))
	elbow_lift = maxf(elbow_lift, sk.get_bone_global_pose(e).origin.distance_to(target))
	var todo: Array[int] = [e]
	while not todo.is_empty():
		var bone: int = todo.pop_back()
		sk.set_bone_global_pose(bone, _poses[bone])
		for child in sk.get_bone_children(bone): todo.append(child)

## Two spine segments bend beneath the chest; preserve their lengths and the
## chest's original orientation instead of carrying the torso with the pelvis.
func _anchor_chest(sk: Skeleton3D, envelope: float) -> void:
	var a := sk.find_bone("spinea")
	var b := sk.find_bone("spineb")
	var c := sk.find_bone("spinec")
	var origin := sk.get_bone_global_pose(a).origin
	var target := _poses[c].origin + Vector3(0, 0, puppy_torso_forward * envelope)
	var upper := _poses[a].origin.distance_to(_poses[b].origin)
	var lower := _poses[b].origin.distance_to(_poses[c].origin)
	var distance := clampf(origin.distance_to(target), absf(upper - lower) + 0.0001, (upper + lower) * 0.9999)
	var direction := (target - origin).normalized()
	var pole := _poses[b].origin - _poses[a].origin
	pole -= direction * pole.dot(direction)
	if pole.length_squared() < 0.000001:
		pole = Vector3.DOWN - direction * Vector3.DOWN.dot(direction)
	pole = pole.normalized()
	var along := (upper * upper + distance * distance - lower * lower) / (2.0 * distance)
	var middle := origin + direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along))
	var q := _arc((_poses[b].origin - _poses[a].origin).normalized(), (middle - origin).normalized())
	sk.set_bone_global_pose(a, Transform3D(Basis(q) * _poses[a].basis, origin))
	var at := sk.get_bone_global_pose(b).origin
	var end := origin + direction * distance
	q = _arc((_poses[c].origin - _poses[b].origin).normalized(), (end - at).normalized())
	sk.set_bone_global_pose(b, Transform3D(Basis(q) * _poses[b].basis, at))
	at = sk.get_bone_global_pose(c).origin
	sk.set_bone_global_pose(c, Transform3D(_poses[c].basis, at))
	chest_drift = at.distance_to(_poses[c].origin)

## Lift the crawl chest over the planted palms by extending the supporting arms.
## This is specific to crawl; the puppy forearms and pose remain unchanged.
func _raise_crawl_chest(sk: Skeleton3D) -> void:
	if crawl_support <= 0.0: return
	var spine := sk.find_bone("spinea")
	var chest := sk.find_bone("spined")
	var before := sk.get_bone_global_pose(chest).origin
	var hands := {}
	var wrists := {}
	for side: String in ["l", "r"]:
		hands[side] = sk.get_bone_global_pose(sk.find_bone(side + "_palm")).origin
		wrists[side] = sk.get_bone_global_pose(sk.find_bone(side + "_wrist")).basis
	var pose := sk.get_bone_global_pose(spine)
	var angle := 0.0
	# Choose the highest lift both arms can support without losing palm contact.
	for step in range(int(crawl_chest_raise_degrees * 2.0) + 1):
		var candidate := -deg_to_rad(float(step) * 0.5) * crawl_support
		var reachable := true
		for side: String in ["l", "r"]:
			var shoulder := sk.get_bone_global_pose(sk.find_bone(side + "_shoulder")).origin
			var elbow := sk.get_bone_global_pose(sk.find_bone(side + "_elbow")).origin
			var wrist := sk.get_bone_global_pose(sk.find_bone(side + "_wrist")).origin
			var raised := pose.origin + Basis(Vector3.RIGHT, candidate) * (shoulder - pose.origin)
			if raised.distance_to(wrist) > (shoulder.distance_to(elbow) + elbow.distance_to(wrist)) * MAX_REACH: reachable = false
		if reachable: angle = candidate
	sk.set_bone_global_pose(spine, Transform3D(Basis(Vector3.RIGHT, angle) * pose.basis, pose.origin))
	support_chest_lift = sk.get_bone_global_pose(chest).origin.y - before.y
	support_palm_miss = 0.0
	for side: String in ["l", "r"]:
		var i := sk.find_bone(side + "_wrist")
		pose = sk.get_bone_global_pose(i)
		sk.set_bone_global_pose(i, Transform3D(wrists[side], pose.origin))
		apply_side(sk, side, hands[side], 1.0)
		support_palm_miss = maxf(support_palm_miss, sk.get_bone_global_pose(sk.find_bone(side + "_palm")).origin.distance_to(hands[side]))
