class_name HeldFist
extends SkeletonModifier3D
## The right hand closed on what it holds (user 2026-10-03, after the saber's grip: "can we do that with all the
## throwables"): the fingers and the thumb of a fist clip (its rotations at `time`) over the animation's, eased in and
## out by `want` (a Callable -> bool: something is in the hand). The throwables' aim and throw clips hold the hand open
## (the graph's brick grip, actor_b-p-fingers-brick): the shaft lay against splayed fingers through the wind-up.
##   HeldFist.install(skeleton, anim, time, want)

const FINGER_KEYS := ["r_thumb", "r_index", "r_middle", "r_ring", "r_pinky"]
## Seconds the hand takes to close or open.
const FADE_S := 0.12

var anim: Animation
var time := 0.0
var want: Callable
var weight := 0.0

var _tracks := {}       ## bone index -> rotation track


static func install(sk: Skeleton3D, a: Animation, t: float, wants: Callable) -> HeldFist:
	var f := HeldFist.new()
	f.name = "HeldFist"
	f.anim = a
	f.time = t
	f.want = wants
	sk.add_child(f)
	return f


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or anim == null:
		return
	var on := want.is_valid() and bool(want.call())
	weight = move_toward(weight, 1.0 if on else 0.0, get_process_delta_time() / FADE_S)
	if weight <= 0.0:
		return
	if _tracks.is_empty():
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var nm := String(anim.track_get_path(i).get_concatenated_subnames())
			if nm.contains("metacarpal") or not FINGER_KEYS.any(func(k: String) -> bool: return nm.begins_with(k)):
				continue
			var b := sk.find_bone(nm)
			if b >= 0:
				_tracks[b] = i
	var t := clampf(time, 0.0, anim.length)
	for b: int in _tracks:
		var q := anim.rotation_track_interpolate(int(_tracks[b]), t)
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(q, weight).normalized())
