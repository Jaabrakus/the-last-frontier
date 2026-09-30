extends PalmReachIK
## Presentation-only wave/sway after the base pose; grounded lower legs remain fixed.
@export var puppy_pose := false
@export var crawl_pose := true
@export var crawl_chest_raise_degrees := 20.0
@export var crawl_knee_half_width := 0.28
@export var crawl_shin_flare_degrees := 20.0
var knee_span := 0.0
var ground_height_error := 0.0
var _wide_knees: Dictionary = {}
var crawl_support := 0.0
var support_chest_lift := 0.0
var support_palm_miss := 0.0
var torso_drift := 0.0
var torso_turn := 0.0
var _crawl_sway_anchor: Dictionary = {}
var wrap: Node
@export var duration := 1.8
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
		_widen_crawl_legs(sk)
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
		if crawl_pose and kind == "sway":
			var lower := sk.find_bone("lower_base")
			var lower_pose := sk.get_bone_global_pose(lower)
			sk.set_bone_global_pose(sk.find_bone("root"), _poses[sk.find_bone("root")])
			sk.set_bone_global_pose(lower, lower_pose)
			for i: int in _crawl_sway_anchor: sk.set_bone_global_pose(i, _crawl_sway_anchor[i])
		elif puppy_pose: _anchor_chest(sk, envelope)
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
	var pose := sk.get_bone_global_pose(spine)
	var angle := -deg_to_rad(crawl_chest_raise_degrees) * crawl_support
	sk.set_bone_global_pose(spine, Transform3D(Basis(Vector3.RIGHT, angle) * pose.basis, pose.origin))
	support_chest_lift = sk.get_bone_global_pose(chest).origin.y - before.y

## Puppy-style saddle legs beneath the raised crawl torso. This runs before the
## wave solver, so the solver anchors the widened knees and relaxed feet.
func _widen_crawl_legs(sk: Skeleton3D) -> void:
	if crawl_support <= 0.0: return
	var hips: Array[Vector3] = []
	var targets: Array[Vector3] = []
	var lengths: Array[float] = []
	var shift_y := 0.0
	for side: String in ["l", "r"]:
		var hip := sk.get_bone_global_pose(sk.find_bone(side + "_upper_leg")).origin
		var knee := sk.get_bone_global_pose(sk.find_bone(side + "_knee")).origin
		if not _wide_knees.has(side):
			_wide_knees[side] = Vector3(crawl_knee_half_width if side == "l" else -crawl_knee_half_width, knee.y, hip.z)
		var target := knee.lerp(_wide_knees[side], crawl_support)
		var length := hip.distance_to(knee)
		var horizontal := Vector2(hip.x - target.x, hip.z - target.z).length_squared()
		shift_y += target.y + sqrt(maxf(0.0001, length * length - horizontal)) - hip.y
		hips.append(hip)
		lengths.append(length)
		targets.append(target)
	shift_y *= 0.5
	var root := sk.find_bone("root")
	var root_pose := sk.get_bone_global_pose(root)
	var pivot := root_pose.origin
	var roll := 0.0
	# The source breathes sideways. Solve height and a small pelvis roll together
	# so both widened knees stay planted without changing either thigh length.
	for iteration in 12:
		var error := _wide_leg_error(hips, targets, lengths, pivot, shift_y, roll)
		if error.length() < 0.000001: break
		var dy := (_wide_leg_error(hips, targets, lengths, pivot, shift_y + 0.0001, roll) - error) / 0.0001
		var dr := (_wide_leg_error(hips, targets, lengths, pivot, shift_y, roll + 0.0001) - error) / 0.0001
		var determinant := dy.x * dr.y - dr.x * dy.y
		if absf(determinant) < 0.000001: break
		shift_y -= (error.x * dr.y - dr.x * error.y) / determinant
		roll -= (dy.x * error.y - error.x * dy.y) / determinant
	root_pose.basis = Basis(Vector3(0, 0, 1), roll) * root_pose.basis
	root_pose.origin.y += shift_y
	sk.set_bone_global_pose(root, root_pose)
	ground_height_error = 0.0
	for index in 2:
		var side: String = ["l", "r"][index]
		_aim_leg(sk, side + "_upper_leg", side + "_knee", targets[index])
		var knee := sk.get_bone_global_pose(sk.find_bone(side + "_knee")).origin
		var ankle := sk.get_bone_global_pose(sk.find_bone(side + "_ankle")).origin
		var shin_length := knee.distance_to(ankle)
		var rise := 0.065 - knee.y
		var reach := sqrt(maxf(0.0001, shin_length * shin_length - rise * rise))
		var sign_x := 1.0 if side == "l" else -1.0
		var flare := deg_to_rad(crawl_shin_flare_degrees)
		var back := Vector3(sign_x * sin(flare), 0, -cos(flare))
		var ankle_target := knee + back * reach + Vector3.UP * rise
		# Blend from the source shin orientation as the wide stance comes in.
		var source_ankle := ankle - Vector3.UP * shift_y
		_aim_leg(sk, side + "_knee", side + "_ankle", source_ankle.lerp(ankle_target, crawl_support))
		ankle = sk.get_bone_global_pose(sk.find_bone(side + "_ankle")).origin
		var ball := sk.get_bone_global_pose(sk.find_bone(side + "_ball")).origin
		var foot_length := ankle.distance_to(ball)
		var foot_target := ankle + back * sqrt(maxf(0.0001, foot_length * foot_length - 0.025 * 0.025)) - Vector3.UP * 0.025
		_aim_leg(sk, side + "_ankle", side + "_ball", ball.lerp(foot_target, crawl_support))
		if crawl_support > 0.999:
			ground_height_error = maxf(ground_height_error, absf(knee.y - targets[index].y))
			ground_height_error = maxf(ground_height_error, absf(ankle.y - 0.065))
	knee_span = sk.get_bone_global_pose(sk.find_bone("l_knee")).origin.distance_to(sk.get_bone_global_pose(sk.find_bone("r_knee")).origin)

func _aim_leg(sk: Skeleton3D, name: String, child: String, target: Vector3) -> void:
	var bone := sk.find_bone(name)
	var pose := sk.get_bone_global_pose(bone)
	var direction := sk.get_bone_global_pose(sk.find_bone(child)).origin - pose.origin
	var turn := _arc(direction.normalized(), (target - pose.origin).normalized())
	sk.set_bone_global_pose(bone, Transform3D(Basis(turn) * pose.basis, pose.origin))

func _wide_leg_error(hips: Array[Vector3], targets: Array[Vector3], lengths: Array[float], pivot: Vector3, height: float, roll: float) -> Vector2:
	var rotation := Basis(Vector3(0, 0, 1), roll)
	var result := Vector2.ZERO
	for i in 2:
		var hip := pivot + rotation * (hips[i] - pivot) + Vector3.UP * height
		result[i] = hip.distance_to(targets[i]) - lengths[i]
	return result
