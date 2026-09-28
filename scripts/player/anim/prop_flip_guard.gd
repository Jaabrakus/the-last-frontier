class_name PropFlipGuard
extends SkeletonModifier3D
## Plays the action partials on the weapon prop bones (WP6 review follow-ups): a crossfade from
## the pose under the partials to each partial's clip, along the path the clip itself turns.
##
## Why: the weapon models hang off l_ / r_hand_prop_attachment, and several action clips turn those
## bones through half a turn, from the bind pose and from the carry pose, while their OneShot fades
## in or out (the musket draw lg-stealth-draw^idle--arm-r: 178 deg from the bind pose at clip
## 0.13 s and 179 deg from the carry pose at 0.17 s, inside its fade-in; the bow nock
## bow-reload--part: 164 / 176 deg from the bind pose). A crossfade that takes the shortest arc flips there: Godot's rest-relative blend
## (rest * slerp(I, rest^-1 * clip, w)) turned the musket round by up to 175 deg in one frame on
## every draw, and a plain slerp(under, clip, w) from the pose under the partials flips one frame
## later (measured 168 / 180 rad/s). Keeping whichever branch continued the last frame best (this
## class's first version) followed the clip through the flip, but when the draw was cut short
## (a second weapon switch, death) it unwound the extra half turn on the way out (78-99 rad/s).
##
## How: TreeBuilder leaves the prop bones out of every action partial's filter (TreeBuilder.
## PROP_BONES), so the tree's pose of these bones is the pose under the partials. UpperBody hands
## over, per prop bone, the partials that key it in chain order (lowest first): the clip's local
## rotation / position / scale at the time the advance sampled and the OneShot's blend weight in
## that advance. Each partial k is a crossfade over the result of those below it, as Godot blends
## the partial's other bones (the pose under it at 1 - w, the clip at w):
##   q_k = q_(k-1) * pow(R_k, w_k),  R_k = q_(k-1)^-1 * clip_k;
## positions and scales lerp the same way, to the rest value where the clip keys no such track (as
## a filtered bone does). R_k's quaternion sign follows R_k's own last frame, so the weapon turns
## the way the clip turns it through the half-turn point, with no flip; and it is reset to the
## shortest arc whenever the choice changes nothing: while the partial is at full weight (then
## q_k is the clip's pose on either branch), at zero weight and on its first frame. OneShots only
## fade out from full weight (UpperBody never fades a partial out during its fade-in), so every
## fade-out starts on the shortest arc and returns to the pose under it without an extra turn.
##
## Runs first among the Skeleton3D's modifiers (before the AimStabilizer, which does not touch
## these bones); BoneAttachment3D (the weapon sockets) sees the result. Code that reads the prop
## bones outside Skeleton3D.skeleton_updated sees the pose under the partials. Without this
## modifier (a tree built by TreeBuilder but no UpperBody.attach_stabilizer()) an action does
## not move the prop bones.

## Weights within this of 0 or 1 count as 0 / 1 (the branch choice changes the pose by at most
## 360 deg x this: 0.04 deg).
const EDGE := 1e-4

## Blended bones (the prop bones).
var bones := PackedInt32Array()
## bone -> [[key (int, the partial), rotation (Quaternion), position (Vector3), scale (Vector3),
## weight (float)], ...] in chain order (lowest first); set by UpperBody.post_advance() every
## frame (absent / empty: no partial plays on that bone).
var entries := {}

var _rel := {}      ## Vector2i(bone, key) -> last R (sign followed from frame to frame)
var _long := 0      ## frames on which a partial turned the long way round (debug / tests)
var _frames := 0    ## frames on which a partial was blended here


## Adds the modifier for the l_ / r_hand_prop_attachment bones as a child of `sk`.
static func create(sk: Skeleton3D) -> PropFlipGuard:
	var g := PropFlipGuard.new()
	g.name = "PropFlipGuard"
	for n in TreeBuilder.PROP_BONES:
		var b := sk.find_bone(n)
		if b >= 0:
			g.bones.append(b)
	g.influence = 1.0
	g.active = not g.bones.is_empty()
	sk.add_child(g)
	return g


## Frames on which a fading partial turned a prop bone the long way round (along its clip's path
## through the half-turn point) since creation.
func flipped_frames() -> int:
	return _long


## Frames on which any partial was blended on a prop bone since creation.
func blended_frames() -> int:
	return _frames


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var rel := {}
	var blended := false
	var long := false
	for b in bones:
		var list: Variant = entries.get(b)
		if not list is Array or (list as Array).is_empty():
			continue
		var q := sk.get_bone_pose_rotation(b)
		var p := sk.get_bone_pose_position(b)
		var s := sk.get_bone_pose_scale(b)
		for e: Array in list:
			var w := float(e[4])
			if w <= 0.0:
				continue
			var key := Vector2i(b, int(e[0]))
			var r := (q.inverse() * Quaternion(e[1])).normalized()
			var last: Variant = _rel.get(key)
			if last == null or w <= EDGE or w >= 1.0 - EDGE:
				if r.w < 0.0:
					r = -r
			elif (last as Quaternion).dot(r) < 0.0:
				r = -r
			rel[key] = r
			if r.w < 0.0:
				long = true
			q = (q * _pow(r, minf(w, 1.0))).normalized()
			p = p.lerp(e[2], w)
			s = s.lerp(e[3], w)
			blended = true
		sk.set_bone_pose_rotation(b, q)
		sk.set_bone_pose_position(b, p)
		sk.set_bone_pose_scale(b, s)
	_rel = rel
	if blended:
		_frames += 1
	if long:
		_long += 1


## r^w along r's own arc: angle 2 atan2(|v|, w) in [0, 2 pi) (beyond pi when r.w < 0: the long
## way round), scaled by w.
static func _pow(r: Quaternion, w: float) -> Quaternion:
	var v := Vector3(r.x, r.y, r.z)
	var n := v.length()
	if n < 1e-8:
		return Quaternion.IDENTITY
	return Quaternion(v / n, 2.0 * atan2(n, r.w) * w)
