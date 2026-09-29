extends SceneTree
## Wide upright kneel. Dimensions in metres, measured in the imported skeleton space.
const KNEE_X := 0.28
const KNEE_Z := 0.06
const HIP_BACK := 0.11
const BOUNCE := 0.015
const TORSO_FORWARD_DEG := 18.0
const CHEST_CURVE_DEG := 6.0
const WAVE_CURL_DEG := {"spineb": 6.0, "spinec": 9.0, "spined": 9.0, "neck": 8.0}
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
func make_pose(drop: float, rock: float = 0.0, curl: float = 0.0) -> void:
	pose = ref.duplicate()
	var hip := ref[bone("l_upper_leg")].origin
	var knee := ref[bone("l_knee")].origin
	var length := hip.distance_to(knee)
	var dx := KNEE_X - hip.x
	var height := sqrt(length * length - dx * dx - HIP_BACK * HIP_BACK) - drop
	var back := sqrt(maxf(0.0, length * length - dx * dx - height * height))
	var shift := Vector3(0, knee.y + height - hip.y, KNEE_Z - back - hip.z)
	# Move the complete pose before re-solving each planted leg.
	for i in pose.size(): pose[i].origin += shift
	var pivot := Vector3(0, knee.y, KNEE_Z)
	var rocking := Basis(Vector3.RIGHT, rock)
	for i in pose.size():
		pose[i].origin = pivot + rocking * (pose[i].origin - pivot)
		pose[i].basis = rocking * pose[i].basis
	var up := pose[bone("neck")].origin - pose[bone("spinea")].origin
	var lean := deg_to_rad(TORSO_FORWARD_DEG)
	rotate_branch(bone("spinea"), Quaternion(up.normalized(), Vector3(0, cos(lean), sin(lean))))
	rotate_branch(bone("spinec"), Quaternion(Vector3.RIGHT, deg_to_rad(CHEST_CURVE_DEG)))
	# Spread the rounding over the spine, with a gentle chin tuck.
	for n: String in WAVE_CURL_DEG:
		rotate_branch(bone(n), Quaternion(Vector3.RIGHT, deg_to_rad(WAVE_CURL_DEG[n]) * curl))
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var h := side + "_upper_leg"
		var k := side + "_knee"
		var a := side + "_ankle"
		var target := Vector3(sign_x * KNEE_X, knee.y, KNEE_Z)
		aim(h, k, target - pose[bone(h)].origin)
		# Same shin direction/length as source: knees and feet fixed throughout bounce.
		aim(k, a, ref[bone(a)].origin - ref[bone(k)].origin)
		aim(side + "_shoulder", side + "_elbow", Vector3(sign_x * 0.12, -1, 0))
		aim(side + "_elbow", side + "_wrist", Vector3(sign_x * 0.04, -1, 0.03))
func bake() -> void:
	var actor: Node3D = load("res://features/tandem/actor_b_kneel.glb").instantiate()
	root.add_child(actor)
	sk = actor.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play("actor_b-kneel-stick")
	ap.seek(0.0, true)
	ap.pause()
	for i in sk.get_bone_count(): ref.append(sk.get_bone_global_pose(i))
	var path := ap.get_node(ap.root_node).get_path_to(sk)
	for kind: String in ["idle", "bounce", "wave"]:
		var reaction := kind != "idle"
		var clip := Animation.new()
		clip.length = 0.9 if kind == "wave" else (0.65 if reaction else 2.0)
		clip.loop_mode = Animation.LOOP_NONE if reaction else Animation.LOOP_LINEAR
		for i in sk.get_bone_count():
			for type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				var t := clip.add_track(type)
				clip.track_set_path(t, NodePath(String(path) + ":" + sk.get_bone_name(i)))
		var fixed: Array[Vector3] = []
		for frame in 40:
			var phase := frame / 39.0
			var drop := -BOUNCE * pow(sin(PI * phase), 2.0) if kind == "bounce" else 0.0
			var rock := deg_to_rad(2.0) * sin(TAU * phase) * sin(PI * phase) if kind == "wave" else 0.0
			var curl := pow(sin(PI * phase), 2.0) if kind == "wave" else 0.0
			make_pose(drop, rock, curl)
			for n in ["l_knee", "r_knee", "l_ankle", "r_ankle"]:
				if frame == 0: fixed.append(pose[bone(n)].origin)
				assert(pose[bone(n)].origin.distance_to(fixed[["l_knee", "r_knee", "l_ankle", "r_ankle"].find(n)]) < 0.001, "Ground contact drift")
			for i in sk.get_bone_count():
				var parent := sk.get_bone_parent(i)
				var local := pose[i] if parent < 0 else pose[parent].affine_inverse() * pose[i]
				clip.position_track_insert_key(i * 3, phase * clip.length, local.origin)
				clip.rotation_track_insert_key(i * 3 + 1, phase * clip.length, local.basis.get_rotation_quaternion())
				clip.scale_track_insert_key(i * 3 + 2, phase * clip.length, local.basis.get_scale())
		var out := "wide_kneel_" + kind
		assert(ResourceSaver.save(clip, "res://features/tandem/" + out + ".tres") == OK)
		print("BAKED ", out, " grounded knees/feet verified")
	quit()
