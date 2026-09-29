extends SceneTree
## Face-up reverse plank with a shallow pelvis dip. Limb lengths and support contacts are preserved.
var sk: Skeleton3D
var ref: Array[Transform3D] = []
var pose: Array[Transform3D] = []
func _initialize() -> void:
	call_deferred("bake")
func bone(n: String) -> int:
	return sk.find_bone(n)
func rotate_branch(b: int, q: Quaternion) -> void:
	var origin := pose[b].origin
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
const HIP_HEIGHT := 0.37
const DIP := 0.045
var targets: Dictionary = {}
func solve_chain(a: String, b: String, c: String, target: Vector3, pole: Vector3) -> void:
	var origin := pose[bone(a)].origin
	var upper := ref[bone(a)].origin.distance_to(ref[bone(b)].origin)
	var lower := ref[bone(b)].origin.distance_to(ref[bone(c)].origin)
	var offset := target - origin
	var distance := offset.length()
	assert(distance < upper + lower and distance > absf(upper - lower), "Unreachable support " + c)
	var along := offset / distance
	var across := (pole - along * pole.dot(along)).normalized()
	var x := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper * upper - x * x))
	var joint := origin + along * x + across * height
	aim(a, b, joint - origin)
	aim(b, c, target - pose[bone(b)].origin)
func make_pose(drop: float, _rock: float = 0.0) -> void:
	pose = ref.duplicate()
	var pivot := ref[bone("pelvis")].origin
	var flip := Basis(Vector3.FORWARD, PI)
	var body_direction := flip * (ref[bone("neck")].origin - pivot)
	var slope := Vector3(0, 0.18 + drop * 2.4, 1).normalized()
	var turn := Basis(Quaternion(body_direction.normalized(), slope)) * flip
	for i in pose.size():
		pose[i].origin = Vector3(0, HIP_HEIGHT - drop, 0) + turn * (ref[i].origin - pivot)
		pose[i].basis = turn * ref[i].basis
	for side: String in ["l", "r"]:
		var shoulder := side + "_shoulder"
		var elbow := side + "_elbow"
		var wrist := side + "_wrist"
		var hip := side + "_upper_leg"
		var knee := side + "_knee"
		var ankle := side + "_ankle"
		if not targets.has(wrist):
			var at := pose[bone(shoulder)].origin
			var reach := (ref[bone(shoulder)].origin.distance_to(ref[bone(elbow)].origin) + ref[bone(elbow)].origin.distance_to(ref[bone(wrist)].origin)) * 0.975
			var sideways := -0.025 if at.x < 0 else 0.025
			var back := sqrt(reach * reach - pow(at.y - 0.05, 2) - sideways * sideways)
			targets[wrist] = Vector3(at.x + sideways, 0.05, at.z + back)
			at = pose[bone(hip)].origin
			reach = (ref[bone(hip)].origin.distance_to(ref[bone(knee)].origin) + ref[bone(knee)].origin.distance_to(ref[bone(ankle)].origin)) * 0.994
			targets[ankle] = Vector3(at.x, 0.095, at.z - sqrt(reach * reach - pow(at.y - 0.095, 2)))
		solve_chain(shoulder, elbow, wrist, targets[wrist], Vector3(0, 0, 1))
		solve_chain(hip, knee, ankle, targets[ankle], Vector3.UP)
		# Keep palms flat and heels in their fixed orientation through the whole recoil.
		var palm_basis := Basis(Vector3.UP, PI) * ref[bone(wrist)].basis
		rotate_branch(bone(wrist), (palm_basis * pose[bone(wrist)].basis.inverse()).get_rotation_quaternion())
		# Uncurl the fingers and lower the palm toward the floor, fingers toward the feet.
		aim(wrist, side + "_palm", Vector3(0, -0.18, -1))
		for finger: String in ["index", "middle", "ring"]:
			var stem := side + "_" + finger
			aim(stem + "_metacarpal", stem + "a", Vector3(0, -0.03, -1))
			aim(stem + "a", stem + "b", Vector3(0, 0, -1))
			aim(stem + "b", stem + "c", Vector3(0, 0, -1))
		for segment: String in ["a", "b", "c"]:
			var next: String = {"a": "b", "b": "c", "c": "d"}[segment]
			aim(side + "_pinky" + segment, side + "_pinky" + next, Vector3(0, 0, -1))
		var thumb_direction := Vector3(0.75 if side == "l" else -0.75, 0, -0.65)
		aim(side + "_thumba", side + "_thumbb", thumb_direction)
		aim(side + "_thumbb", side + "_thumbc", thumb_direction)
		var toe_axis := ref[bone(side + "_ball")].origin - ref[bone(side + "_heel")].origin
		var foot_basis := Basis(Quaternion(toe_axis.normalized(), Vector3.UP)) * ref[bone(ankle)].basis
		rotate_branch(bone(ankle), (foot_basis * pose[bone(ankle)].basis.inverse()).get_rotation_quaternion())
func bake() -> void:
	var actor: Node3D = load("res://features/tandem/actor_b_yoga.glb").instantiate()
	root.add_child(actor)
	sk = actor.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play("actor_b-yoga-plank-flow")
	ap.seek(0.0, true)
	ap.pause()
	for i in sk.get_bone_count(): ref.append(sk.get_bone_global_pose(i))
	var path := ap.get_node(ap.root_node).get_path_to(sk)
	for kind: String in ["idle", "dip"]:
		var reaction := kind != "idle"
		var clip := Animation.new()
		clip.length = 0.8 if reaction else 2.0
		clip.loop_mode = Animation.LOOP_NONE if reaction else Animation.LOOP_LINEAR
		for i in sk.get_bone_count():
			for type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				var t := clip.add_track(type)
				clip.track_set_path(t, NodePath(String(path) + ":" + sk.get_bone_name(i)))
		var fixed: Array[Vector3] = []
		for frame in 40:
			var phase := frame / 39.0
			var drop := DIP * pow(sin(PI * phase), 2.0) if reaction else 0.0
			make_pose(drop)
			for n in ["l_wrist", "r_wrist", "l_ankle", "r_ankle"]:
				if frame == 0: fixed.append(pose[bone(n)].origin)
				assert(pose[bone(n)].origin.distance_to(fixed[["l_wrist", "r_wrist", "l_ankle", "r_ankle"].find(n)]) < 0.001, "Ground contact drift")
			for i in sk.get_bone_count():
				var parent := sk.get_bone_parent(i)
				var local := pose[i] if parent < 0 else pose[parent].affine_inverse() * pose[i]
				clip.position_track_insert_key(i * 3, phase * clip.length, local.origin)
				clip.rotation_track_insert_key(i * 3 + 1, phase * clip.length, local.basis.get_rotation_quaternion())
				clip.scale_track_insert_key(i * 3 + 2, phase * clip.length, local.basis.get_scale())
		var out := "reverse_plank_" + kind
		assert(ResourceSaver.save(clip, "res://features/tandem/" + out + ".tres") == OK)
		print("BAKED ", out, " grounded palms/heels verified")
	quit()
