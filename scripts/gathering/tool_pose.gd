class_name ToolPose
extends SkeletonModifier3D
## Poses the body for the gathering tools (GatherTools) over the animation tree's pose: layers of clips, each
## sampled at its own time on a set of bones with a weight, applied in order (a later layer over the pose the
## earlier ones left), so a cross-fade is two layers: the old at full weight, the new at the fade.
##
##   pose.layers = [{"anim": Animation, "time": s, "weight": 0..1, "mask": "arm_r" | "upper" | "full"}, ...]
##
## Masks (only bones the clip keys are touched):
##   arm_r   the right arm, hand and fingers and the right-hand prop bone (the draw, the stow, the one-hand carry)
##   upper   everything above the hips: the spine, neck, head, both arms and hands (a stroke while walking)
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
			"upper":
				if not leg and not n in POSITION_BONES:
					out[b] = true
			"upper_one_hand", "full_one_hand":
				# a one-handed weapon on two-handed clips (the saber on the axe's swings): the left arm left out, to its own motion
				var l_arm := n.begins_with("l_") and not leg and not n in ["l_chest", "l_breast", "l_breast_end"]
				if not l_arm and (mask == "full_one_hand" or (not leg and not n in POSITION_BONES)):
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
