extends PalmReachIK
## Raised crawl with both palms planted; source wrist orientation keeps palms flat.
var brace: Node
var hold := 0.0
var palm_miss := 0.0
var palms_world := {}
var arm_span := 0.0
var length_error := 0.0
var _floor_targets := {}
var _wrist_basis := {}
func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null: return
	if _wrist_basis.is_empty(): _load_floor_wrists()
	palm_miss = 0.0
	length_error = 0.0
	for side: String in ["l", "r"]:
		var ids := _bones(sk, side)
		if ids.is_empty(): continue
		if hold <= 0.0: continue
		var shoulder := sk.get_bone_global_pose(int(ids[0])).origin
		var elbow := sk.get_bone_global_pose(int(ids[1])).origin
		var wrist := sk.get_bone_global_pose(int(ids[2]))
		var upper_length := shoulder.distance_to(elbow)
		var fore_length := elbow.distance_to(wrist.origin)
		if not _floor_targets.has(side):
			_floor_targets[side] = Vector3(shoulder.x, 0.035, shoulder.z + 0.08)
		if _wrist_basis.has(side):
			sk.set_bone_global_pose(int(ids[2]), Transform3D(_wrist_basis[side], wrist.origin))
		_fit_clavicle(sk, side, ids, _floor_targets[side])
		shoulder = sk.get_bone_global_pose(int(ids[0])).origin
		apply_side(sk, side, _floor_targets[side], hold)
		var palm := sk.get_bone_global_pose(int(ids[3])).origin
		palms_world[side] = sk.global_transform * palm
		if hold > 0.999: palm_miss = maxf(palm_miss, palm.distance_to(_floor_targets[side]))
		elbow = sk.get_bone_global_pose(int(ids[1])).origin
		wrist = sk.get_bone_global_pose(int(ids[2]))
		length_error = maxf(length_error, absf(shoulder.distance_to(elbow) - upper_length))
		length_error = maxf(length_error, absf(elbow.distance_to(wrist.origin) - fore_length))
	if palms_world.has("l") and palms_world.has("r"): arm_span = palms_world.l.distance_to(palms_world.r)

## Share the floor reach across the clavicle and arm rather than stretching the arm.
func _fit_clavicle(sk: Skeleton3D, side: String, ids: Array, target: Vector3) -> void:
	var index := sk.find_bone(side + "_clavicle")
	var pose := sk.get_bone_global_pose(index)
	var shoulder := sk.get_bone_global_pose(int(ids[0])).origin
	var elbow := sk.get_bone_global_pose(int(ids[1])).origin
	var wrist := sk.get_bone_global_pose(int(ids[2])).origin
	var palm := sk.get_bone_global_pose(int(ids[3])).origin
	var wrist_target := target - (palm - wrist)
	var reach := (shoulder.distance_to(elbow) + elbow.distance_to(wrist)) * MAX_REACH
	if shoulder.distance_to(wrist_target) <= reach: return
	var turn := _arc((shoulder - pose.origin).normalized(), (wrist_target - pose.origin).normalized())
	for step in range(1, 101):
		var rotation := Quaternion.IDENTITY.slerp(turn, step / 100.0)
		var at := pose.origin + rotation * (shoulder - pose.origin)
		if at.distance_to(wrist_target) <= reach or step == 100:
			sk.set_bone_global_pose(index, Transform3D(Basis(rotation) * pose.basis, pose.origin))
			return

func _load_floor_wrists() -> void:
	var actor := (load("res://features/tandem/actor_b_crawl.glb") as PackedScene).instantiate()
	var source: Skeleton3D = actor.find_children("*", "Skeleton3D", true, false)[0]
	var animation: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	animation.play("actor_b-crawl-idle")
	animation.seek(0.0, true)
	for side: String in ["l", "r"]:
		_wrist_basis[side] = source.get_bone_global_pose(source.find_bone(side + "_wrist")).basis
	actor.free()
