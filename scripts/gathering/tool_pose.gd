class_name ToolPose
extends SkeletonModifier3D
## Poses the body for the gathering tools (GatherTools) over the animation tree's pose: layers of clips, each
## sampled at its own time on a set of bones with a weight, applied in order (a later layer over the pose the
## earlier ones left), so a cross-fade is two layers: the old at full weight, the new at the fade.
##
##   pose.layers = [{"anim": Animation, "time": s, "weight": 0..1, "mask": "arm_r" | "reach_r" | "reach_l" | "upper" | "full"}, ...]
##
## Masks (only bones the clip keys are touched):
##   arm_r   the right arm, hand and fingers and the right-hand prop bone (the draw, the stow, the one-hand carry)
##   reach_r, reach_l   above the hips without the other arm (ForagePick's grab: the torso and the head toward the reach)
##   upper   everything above the hips: the spine, neck, head, both arms and hands (a stroke while walking)
##   fingers_r   the right hand's fingers and thumb (a one-handed grip's fist held through the swings)
##   full    every keyed bone, with the root's and the pelvis's positions (a stroke standing: the footwork too)
## Rotations are slerped from the pose so far toward the clip's; positions lerped for the prop bones (the tool's
## place in the hand) and, "full" only, the root and the pelvis.
## Added last among the skeleton's modifiers (CharacterBodyMesh keeps itself behind it), so it is over the
## tree, the stance inertializer, traversal IK and the free-arm layers.
## Animation data (the clips GatherTools passes): animations_extra/Actor_B_from_A.res, retargeted to Actor_B.

const LEG_KEYS := ["upper_leg", "knee", "ankle", "heel", "ball"]
const POSITION_BONES := ["root", "pelvis"]
## The prop bones carry the weapon's place in the hand as a translation too: their positions always follow.
const PROP_BONES := ["r_hand_prop_attachment", "l_hand_prop_attachment"]

var layers: Array = []
## Bends the spine forward (+) or back (-) after the layers, rad over the whole spine (AxeMelee: the swing leaned
## toward the crosshair's height).
var lean := 0.0
const LEAN_BONES := ["spinea", "spineb", "spinec", "spined"]
## Reverses the right hand after the layers, 0..1 (GatherTools: the saber's high block turned to the left; user
## 2026-10-03: "just reverse the hand right on IK"): the hand, as an IK target, turned half round the vertical through
## its own place, so what it holds points the other way and stays as level as it was (the blade across over the head to
## the left, the grip seated in the fist: turning the blade in the fist instead mangled the fingers). The forearm takes
## FOREARM_SHARE of the roll about its own axis (at the elbow), the wrist the rest, to the target's turn exactly.
var hand_reverse := 0.0
const FOREARM_SHARE := 0.6

var _tracks := {}      ## Animation -> {bone index: [rotation track, position track]}
var _mask_cache := {}  ## mask -> PackedInt32Array of bone indices (skeleton-wide, before the clip filter)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or layers.is_empty():
		return
	for l: Dictionary in layers:
		var w := clampf(float(l.get("weight", 0.0)), 0.0, 1.0)
		var anim: Animation = l.get("anim")
		if w <= 0.0 or anim == null:
			continue
		var t := clampf(float(l.get("time", 0.0)), 0.0, anim.length)
		var mask := String(l.get("mask", "upper"))
		var tr := _clip_tracks(sk, anim)
		var allowed := _mask(sk, mask)
		for b: int in tr:
			if not allowed.has(b):
				continue
			var pair: Array = tr[b]
			if int(pair[0]) >= 0:
				var q := anim.rotation_track_interpolate(int(pair[0]), t)
				sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(q, w).normalized())
			var bn := sk.get_bone_name(b)
			if int(pair[1]) >= 0 and (bn in PROP_BONES or mask == "full" and bn in POSITION_BONES):
				var p := anim.position_track_interpolate(int(pair[1]), t)
				sk.set_bone_pose_position(b, sk.get_bone_pose_position(b).lerp(p, w))
	if absf(lean) > 1e-4:
		# (the body faces +Z: forward is a turn about +X; each spine bone takes its share about its own position)
		var share := Basis(Vector3.RIGHT, lean / float(LEAN_BONES.size()))
		for nm: String in LEAN_BONES:
			var b := sk.find_bone(nm)
			if b >= 0:
				var g := sk.get_bone_global_pose(b)
				sk.set_bone_global_pose(b, Transform3D(share * g.basis, g.origin))
	if hand_reverse > 1e-4:
		_reverse_hand(sk)


## The right hand turned hand_reverse of half round the vertical through the wrist (the body faces +Z: the turn takes
## what it holds from the right round in front to the left); the forearm rolls its share of that about its own axis and
## the wrist is set to the target's turn exactly (the hand and the prop on it follow; the wrist stays where it was).
func _reverse_hand(sk: Skeleton3D) -> void:
	var e := sk.find_bone("r_elbow")
	var wr := sk.find_bone("r_wrist")
	if e < 0 or wr < 0:
		return
	var w0 := sk.get_bone_global_pose(wr)
	var axis := w0.origin - sk.get_bone_global_pose(e).origin
	if axis.length_squared() < 1e-8:
		return
	axis = axis.normalized()
	var turn := Basis(Vector3.UP, PI * clampf(hand_reverse, 0.0, 1.0))
	var target := turn * w0.basis
	# the turn's twist about the forearm (swing-twist): the forearm takes its share, so the wrist is not wrung the whole way
	var q := turn.get_rotation_quaternion()
	var qv := Vector3(q.x, q.y, q.z)
	var tw := Quaternion(axis.x * qv.dot(axis), axis.y * qv.dot(axis), axis.z * qv.dot(axis), q.w)
	if tw.length_squared() > 1e-10:
		tw = tw.normalized()
		var ang := 2.0 * atan2(Vector3(tw.x, tw.y, tw.z).dot(axis), tw.w)
		var g := sk.get_bone_global_pose(e)
		sk.set_bone_global_pose(e, Transform3D(Basis(axis, ang * FOREARM_SHARE) * g.basis, g.origin))
	sk.set_bone_global_pose(wr, Transform3D(target, sk.get_bone_global_pose(wr).origin))


func _clip_tracks(sk: Skeleton3D, anim: Animation) -> Dictionary:
	if _tracks.has(anim):
		return _tracks[anim]
	var out := {}
	for i in anim.get_track_count():
		var tt := anim.track_get_type(i)
		if tt != Animation.TYPE_ROTATION_3D and tt != Animation.TYPE_POSITION_3D:
			continue
		var b := sk.find_bone(String(anim.track_get_path(i).get_concatenated_subnames()))
		if b < 0:
			continue
		if not out.has(b):
			out[b] = [-1, -1]
		(out[b] as Array)[0 if tt == Animation.TYPE_ROTATION_3D else 1] = i
	_tracks[anim] = out
	return out


## Bone indices a mask allows, as a set (Dictionary).
func _mask(sk: Skeleton3D, mask: String) -> Dictionary:
	if _mask_cache.has(mask):
		return _mask_cache[mask]
	var out := {}
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b)
		if n.contains("helper") or n.contains("twist") or n.contains("offset") or n.contains("_grp"):
			continue
		var leg := false
		for k: String in LEG_KEYS:
			if n.contains(k):
				leg = true
				break
		match mask:
			"arm_r":
				if n.begins_with("r_") and not leg and not n in ["r_chest", "r_breast", "r_breast_end"]:
					out[b] = true
			"reach_r", "reach_l":
				# above the hips without the other arm (ForagePick's grab: the spine and the head toward the reaching arm)
				var other := "l_" if mask == "reach_r" else "r_"
				var other_arm := n.begins_with(other) and not n in [other + "chest", other + "breast", other + "breast_end"]
				if not leg and not other_arm and not n in POSITION_BONES:
					out[b] = true
			"upper":
				if not leg and not n in POSITION_BONES:
					out[b] = true
			"fingers_r":
				# the right hand's fingers and thumb only (GatherTools: the carry's fist kept round a one-handed grip
				# through the swings; user 2026-10-03, the hand holding the grip throughout the motion)
				for k: String in ["r_thumb", "r_index", "r_middle", "r_ring", "r_pinky"]:
					if n.begins_with(k) and not n.contains("metacarpal"):
						out[b] = true
						break
			"upper_one_hand", "full_one_hand":
				# a one-handed weapon on two-handed clips (the saber on the axe's swings): the left arm left out, to its own motion
				var l_arm := n.begins_with("l_") and not leg and not n in ["l_chest", "l_breast", "l_breast_end"]
				# (nor the prop bones: the two-handed clips slide the haft through the hand, and a one-handed grip stays where
				# the carry holds it, in the fist; user 2026-10-03, the hand holding the grip throughout the motion)
				if not l_arm and not n in PROP_BONES and (mask == "full_one_hand" or (not leg and not n in POSITION_BONES)):
					out[b] = true
			_:
				out[b] = true
	_mask_cache[mask] = out
	return out


## The pose `anim` gives bone `bone` at `t` in the frame of its ancestor `frame_bone`: the clip's own local
## transforms down the chain (the skeleton's current pose where the clip keys nothing). GatherTools uses it for
## the tool's place on the pack (the hand's prop bone at the draw's grab, in the upper spine's frame).
static func clip_relative(sk: Skeleton3D, anim: Animation, t: float, bone: String, frame_bone: String) -> Transform3D:
	var b := sk.find_bone(bone)
	var f := sk.find_bone(frame_bone)
	var chain: Array[int] = []
	while b >= 0 and b != f:
		chain.push_front(b)
		b = sk.get_bone_parent(b)
	var xf := Transform3D()
	for c in chain:
		var pos := sk.get_bone_pose_position(c)
		var rot := sk.get_bone_pose_rotation(c)
		var name := sk.get_bone_name(c)
		for i in anim.get_track_count():
			if String(anim.track_get_path(i).get_concatenated_subnames()) != name:
				continue
			match anim.track_get_type(i):
				Animation.TYPE_POSITION_3D:
					pos = anim.position_track_interpolate(i, t)
				Animation.TYPE_ROTATION_3D:
					rot = anim.rotation_track_interpolate(i, t)
		xf = xf * Transform3D(Basis(rot), pos)
	return xf
