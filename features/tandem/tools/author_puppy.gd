extends SceneTree
## Puppy pose derived from crawl; radians rotate the chest down toward the floor.
const CHEST_DROP_DEG := 55.0
const NECK_LIFT_DEG := 50.0
const HAND_FLATTEN_DEG := 24.0
const KNEE_HALF_WIDTH := 0.28
const LOWER_BACK_ARCH_DEG := 26.0
const PELVIS_TILT_DEG := 15.0
const UPPER_BACK_EXTENSION_DEG := 15.0
const SHIN_FLARE_DEG := 20.0
const ANKLE_HEIGHT := 0.065
const TOE_DROP := 0.025
const FLINCH_FORWARD := 0.045
const FLINCH_LENGTH := 0.55
const FLINCH_PEAK_TIME := 0.12
const WRIST_HEIGHT := 0.05
const ELBOW_HEIGHT := 0.04
var sk: Skeleton3D
var ref: Array[Transform3D] = []
var pose: Array[Transform3D] = []
func _initialize() -> void:
	call_deferred("bake")
func bone(n: String) -> int:
	return sk.find_bone(n)
func rotate_branch(b: int, q: Quaternion) -> void:
	rotate_branch_at(b, q, pose[b].origin)
func rotate_branch_at(b: int, q: Quaternion, origin: Vector3) -> void:
	var todo: Array[int] = [b]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		pose[i].origin = origin + q * (pose[i].origin - origin)
		pose[i].basis = Basis(q) * pose[i].basis
		for c in sk.get_bone_children(i): todo.append(c)
func aim(n: String, child: String, direction: Vector3) -> void:
	var b := bone(n)
	var v := pose[bone(child)].origin - pose[b].origin
	rotate_branch(b, Quaternion(v.normalized(), direction.normalized()))
func bake() -> void:
	var actor: Node3D = load("res://features/tandem/actor_b_crawl.glb").instantiate()
	root.add_child(actor)
	sk = actor.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play("actor_b-crawl-idle")
	ap.seek(0.0, true)
	ap.pause()
	for i in sk.get_bone_count(): ref.append(sk.get_bone_global_pose(i))
	pose = ref.duplicate()
	# Tilt the pelvis at the peak of the torso/thigh V, then re-solve planted legs.
	rotate_branch(bone("pelvis"), Quaternion(Vector3.RIGHT, deg_to_rad(PELVIS_TILT_DEG)))
	# Center the crawl's small sideways sway before widening the grounded knees.
	var center_x := (pose[bone("l_upper_leg")].origin.x + pose[bone("r_upper_leg")].origin.x) * 0.5
	for i in pose.size(): pose[i].origin.x -= center_x
	var knee_y := ref[bone("l_knee")].origin.y
	var hip := pose[bone("l_upper_leg")].origin
	var thigh_length := hip.distance_to(pose[bone("l_knee")].origin)
	var dx := KNEE_HALF_WIDTH - hip.x
	# Lower the hips only as much as the spread requires, preserving thigh length.
	var hip_drop := knee_y + sqrt(thigh_length * thigh_length - dx * dx) - hip.y
	for i in pose.size(): pose[i].origin.y += hip_drop
	for side: String in ["l", "r"]:
		var h := bone(side + "_upper_leg")
		var k := bone(side + "_knee")
		var a := bone(side + "_ankle")
		var sign_x := 1.0 if side == "l" else -1.0
		var target := Vector3(sign_x * KNEE_HALF_WIDTH, knee_y, pose[h].origin.z)
		aim(side + "_upper_leg", side + "_knee", target - pose[h].origin)
		# Relaxed, outward-flared shins instead of parallel shins and tucked toes.
		var shin_length := ref[a].origin.distance_to(ref[k].origin)
		var shin_rise := ANKLE_HEIGHT - knee_y
		var shin_reach := sqrt(shin_length * shin_length - shin_rise * shin_rise)
		var flare := deg_to_rad(SHIN_FLARE_DEG)
		var back := Vector3(sign_x * sin(flare), 0, -cos(flare))
		aim(side + "_knee", side + "_ankle", back * shin_reach + Vector3.UP * shin_rise)
		rotate_branch(a, ref[a].basis.get_rotation_quaternion() * pose[a].basis.get_rotation_quaternion().inverse())
		var ball := bone(side + "_ball")
		var foot_length := pose[ball].origin.distance_to(pose[a].origin)
		var foot_reach := sqrt(foot_length * foot_length - TOE_DROP * TOE_DROP)
		aim(side + "_ankle", side + "_ball", back * foot_reach - Vector3.UP * TOE_DROP)
		assert(absf(pose[a].origin.y - ANKLE_HEIGHT) < 0.003, "Ankle grounding changed")
		assert(absf(pose[ball].origin.y - (ANKLE_HEIGHT - TOE_DROP)) < 0.003, "Toe grounding changed")
		assert(absf(pose[k].origin.y - knee_y) < 0.003, "Knee grounding changed")
		assert(absf(pose[k].origin.x - sign_x * KNEE_HALF_WIDTH) < 0.003, "Knee spread incorrect")
	rotate_branch(bone("spinea"), Quaternion(Vector3.RIGHT, deg_to_rad(CHEST_DROP_DEG)))
	# Extend the upper back gently so the chest reaches forward instead of folding at one joint.
	rotate_branch(bone("spinec"), Quaternion(Vector3.RIGHT, deg_to_rad(-UPPER_BACK_EXTENSION_DEG)))
	# Hollow starts at the pelvis-to-spinea connection, not farther up the torso.
	# Include upper_base itself so the waist surface curves at the confirmed small-of-back spot.
	var lower_before := pose[bone("spinea")].origin
	var pelvis_before := pose[bone("pelvis")]
	rotate_branch(bone("upper_base"), Quaternion(Vector3.RIGHT, deg_to_rad(LOWER_BACK_ARCH_DEG)))
	# Bring the upper spine back to its established chest angle after the low arch.
	rotate_branch(bone("spineb"), Quaternion(Vector3.RIGHT, deg_to_rad(-LOWER_BACK_ARCH_DEG)))
	assert(pose[bone("pelvis")] == pelvis_before, "Pelvis anchor moved")
	print("PUPPY pelvis-spine junction dip metres=", lower_before.y - pose[bone("spinea")].origin.y)
	# Lift the chest only enough for near-vertical upper arms over grounded elbows.
	var chest_raise := 0.0
	var upper_length := pose[bone("l_shoulder")].origin.distance_to(pose[bone("l_elbow")].origin)
	var shoulder_height := ELBOW_HEIGHT + upper_length - 0.005
	while (pose[bone("l_shoulder")].origin.y + pose[bone("r_shoulder")].origin.y) * 0.5 < shoulder_height and chest_raise < 60.0:
		rotate_branch(bone("spinea"), Quaternion(Vector3.RIGHT, deg_to_rad(-0.25)))
		chest_raise += 0.25
	print("PUPPY forearm-supported chest raise degrees=", chest_raise)
	# Counter-rotate the neck so the chin faces forward rather than tucking into the floor.
	rotate_branch(bone("neck"), Quaternion(Vector3.RIGHT, deg_to_rad(-NECK_LIFT_DEG + chest_raise)))
	for side: String in ["l", "r"]:
		var s := bone(side + "_shoulder")
		var e := bone(side + "_elbow")
		var w := bone(side + "_wrist")
		var upper := pose[s].origin.distance_to(pose[e].origin)
		var lower := pose[e].origin.distance_to(pose[w].origin)
		# Forearm-supported hold: elbow and wrist on the floor, reaching forward.
		var elbow_drop := ELBOW_HEIGHT - pose[s].origin.y
		var elbow := pose[s].origin + Vector3(0, elbow_drop, sqrt(maxf(0.0, upper * upper - elbow_drop * elbow_drop)))
		aim(side + "_shoulder", side + "_elbow", elbow - pose[s].origin)
		var wrist_rise := WRIST_HEIGHT - ELBOW_HEIGHT
		var target := pose[e].origin + Vector3(0, wrist_rise, sqrt(lower * lower - wrist_rise * wrist_rise))
		aim(side + "_elbow", side + "_wrist", target - pose[e].origin)
		# Keep the crawl's palm/finger orientation instead of rotating hands with the arm.
		rotate_branch(w, ref[w].basis.get_rotation_quaternion() * pose[w].basis.get_rotation_quaternion().inverse())
		rotate_branch(w, Quaternion(Vector3.RIGHT, deg_to_rad(HAND_FLATTEN_DEG)))
		assert(absf(pose[w].origin.y - WRIST_HEIGHT) < 0.001)
		assert(absf(pose[e].origin.y - ELBOW_HEIGHT) < 0.001)
	for i in sk.get_bone_count():
		var parent := sk.get_bone_parent(i)
		if parent >= 0:
			assert(absf(pose[i].origin.distance_to(pose[parent].origin) - ref[i].origin.distance_to(ref[parent].origin)) < 0.001, "Bone length changed: " + sk.get_bone_name(i) + " parent=" + sk.get_bone_name(parent))
	var idle := pose.duplicate()
	var path := ap.get_node(ap.root_node).get_path_to(sk)
	for kind: String in ["idle", "flinch"]:
		var clip := Animation.new()
		clip.length = 2.0 if kind == "idle" else FLINCH_LENGTH
		clip.loop_mode = Animation.LOOP_LINEAR if kind == "idle" else Animation.LOOP_NONE
		for i in sk.get_bone_count():
			for type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				var t := clip.add_track(type)
				clip.track_set_path(t, NodePath(String(path) + ":" + sk.get_bone_name(i)))
		var times: Array[float] = []
		if kind == "idle": times.assign([0.0, 2.0])
		if kind == "flinch":
			for frame in 25: times.append(frame * FLINCH_LENGTH / 24.0)
			times.append(FLINCH_PEAK_TIME)
			times.sort()
		for time: float in times:
			pose = idle.duplicate()
			if kind == "flinch":
				var u := time / FLINCH_PEAK_TIME if time <= FLINCH_PEAK_TIME else (time - FLINCH_PEAK_TIME) / (FLINCH_LENGTH - FLINCH_PEAK_TIME)
				var ease := u * u * (3.0 - 2.0 * u)
				make_flinch(idle, FLINCH_FORWARD * (ease if time <= FLINCH_PEAK_TIME else 1.0 - ease))
			for i in sk.get_bone_count():
				var parent := sk.get_bone_parent(i)
				if parent >= 0:
					assert(absf(pose[i].origin.distance_to(pose[parent].origin) - idle[i].origin.distance_to(idle[parent].origin)) < 0.001, "Flinch bone length changed: " + sk.get_bone_name(i))
				var local := pose[i] if parent < 0 else pose[parent].affine_inverse() * pose[i]
				clip.position_track_insert_key(i * 3, time, local.origin)
				clip.rotation_track_insert_key(i * 3 + 1, time, local.basis.get_rotation_quaternion())
				clip.scale_track_insert_key(i * 3 + 2, time, local.basis.get_scale())
		assert(ResourceSaver.save(clip, "res://features/tandem/puppy_" + kind + ".tres") == OK)
		print("PUPPY_BAKED ", kind, " grounded knees/shins/feet and unchanged bone lengths")
	quit()
func make_flinch(idle: Array, forward: float) -> void:
	var hip := idle[bone("l_upper_leg")].origin as Vector3
	var knee := idle[bone("l_knee")].origin as Vector3
	var length := hip.distance_to(knee)
	var dx := hip.x - knee.x
	var dz := hip.z + forward - knee.z
	var hip_y := knee.y + sqrt(length * length - dx * dx - dz * dz)
	var shift := Vector3(0, hip_y - hip.y, forward)
	for i in pose.size(): pose[i].origin += shift
	for side: String in ["l", "r"]:
		var h := bone(side + "_upper_leg")
		var k := bone(side + "_knee")
		aim(side + "_upper_leg", side + "_knee", idle[k].origin - pose[h].origin)
		# Restore the whole knee subtree, including shin, ankle, foot and toes, in world rig space.
		var todo: Array[int] = [k]
		while not todo.is_empty():
			var i: int = todo.pop_back()
			pose[i] = idle[i]
			for child in sk.get_bone_children(i): todo.append(child)

	# The forearms stay planted through the forward flinch, just like the lower legs.
	for side: String in ["l", "r"]:
		var c := bone(side + "_clavicle")
		var s := bone(side + "_shoulder")
		var e := bone(side + "_elbow")
		var a := pose[c].origin
		var target := idle[e].origin as Vector3
		var upper := pose[c].origin.distance_to(pose[s].origin)
		var lower := pose[s].origin.distance_to(pose[e].origin)
		var distance := a.distance_to(target)
		assert(distance < upper + lower and distance > absf(upper - lower), "Elbow support out of reach")
		var direction := (target - a).normalized()
		var pole := (idle[s].origin - idle[c].origin) as Vector3
		pole = (pole - direction * pole.dot(direction)).normalized()
		var along := (upper * upper + distance * distance - lower * lower) / (2.0 * distance)
		var shoulder := a + direction * along + pole * sqrt(maxf(0, upper * upper - along * along))
		aim(side + "_clavicle", side + "_shoulder", shoulder - a)
		aim(side + "_shoulder", side + "_elbow", target - pose[s].origin)
		var todo: Array[int] = [e]
		while not todo.is_empty():
			var i: int = todo.pop_back()
			pose[i] = idle[i]
			for child in sk.get_bone_children(i): todo.append(child)
