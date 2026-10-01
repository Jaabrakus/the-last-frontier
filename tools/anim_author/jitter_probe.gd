extends SceneTree
## Measures mocap jitter in clips: per bone, the mean angle (degrees) between the rotation and a lightly smoothed copy of it (Gaussian,
## 1.5 frames at 30 fps): the high-frequency shake, what a smooth motion has little of. Prints the upper-body and leg means and the
## shakiest bones.
##   Godot --headless --path . -s tools/anim_author/jitter_probe.gd -- <lib path>|<clip>[,...]
const UPPER := ["pelvis", "spinea", "spineb", "spinec", "spined", "neck", "heada", "headb", "l_clavicle", "r_clavicle", "l_shoulder", "r_shoulder",
		"l_elbow", "r_elbow", "l_wrist", "r_wrist"]
const LEGS := ["l_upper_leg", "r_upper_leg", "l_knee", "r_knee", "l_ankle", "r_ankle"]


const MD := preload("res://tools/anim_author/mocap_downgrade.gd")


static func jitter(a: Animation, bone: String, fps := 30.0) -> float:
	var ti := -1
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D and String(a.track_get_path(i).get_concatenated_subnames()) == bone:
			ti = i
	if ti < 0:
		return 0.0
	var n := int(round(a.length * fps))
	if n < 6:
		return 0.0
	var q: Array[Quaternion] = []
	for i in n + 1:
		var s := a.rotation_track_interpolate(ti, minf(i / fps, a.length)).normalized()
		if i > 0 and q[i - 1].dot(s) < 0.0:
			s = -s
		q.append(s)
	var sm := MD.smooth_samples(q, 1.5, false)
	var acc := 0.0
	for i in n + 1:
		acc += rad_to_deg(q[i].angle_to(sm[i]))
	return acc / float(n + 1)


func _init() -> void:
	for spec in OS.get_cmdline_user_args():
		for item in spec.split(","):
			var lp := item.get_slice("|", 0)
			var cn := item.substr(lp.length() + 1)
			var lib := load(lp) as AnimationLibrary
			if lib == null or not lib.has_animation(cn):
				print("JIT missing ", item)
				continue
			var a := lib.get_animation(cn)
			var up := 0.0
			var lg := 0.0
			var rows := []
			for b in UPPER:
				var j := jitter(a, b)
				up += j
				rows.append([j, b])
			for b in LEGS:
				lg += jitter(a, b)
			rows.sort_custom(func(x, y): return x[0] > y[0])
			print("JIT %-45s upper %.2f legs %.2f  shakiest %s" % [cn, up / UPPER.size(), lg / LEGS.size(), rows.slice(0, 3).map(func(r): return "%s %.2f" % [r[1], r[0]])])
	quit()
