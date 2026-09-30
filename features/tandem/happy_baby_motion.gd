extends SkeletonModifier3D
## Rock the pelvis while the supine upper body keeps its original floor support.
var kind := ""
var moving := false
var started_ms := 0
var duration := 1.8
@export var sway_degrees := 3.0
var pelvis_world := Transform3D.IDENTITY
var eyes_world := Vector3.ZERO
func play_motion(which: String, start_ms: int = -1) -> void:
	if which not in ["wave", "sway"]: return
	kind = which
	started_ms = Time.get_ticks_msec() if start_ms < 0 else start_ms
	moving = true
func cancel() -> void:
	kind = ""
	moving = false
func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null: return
	var pelvis := sk.find_bone("pelvis")
	var t := float(Time.get_ticks_msec() - started_ms) / (duration * 1000.0)
	if moving and t >= 1.0: cancel()
	if moving:
		var amount := sin(TAU * t) * pow(sin(PI * clampf(t, 0, 1)), 2)
		var pose := sk.get_bone_global_pose(pelvis)
		var axis := Vector3.RIGHT if kind == "wave" else Vector3(0, 0, 1)
		sk.set_bone_global_pose(pelvis, Transform3D(Basis(axis, deg_to_rad(10.0 if kind == "wave" else sway_degrees) * amount) * pose.basis, pose.origin))
	pelvis_world = sk.global_transform * sk.get_bone_global_pose(pelvis)
	var eyes := (sk.get_bone_global_pose(sk.find_bone("l_eyeball")).origin + sk.get_bone_global_pose(sk.find_bone("r_eyeball")).origin) * 0.5
	eyes_world = sk.global_transform * eyes

