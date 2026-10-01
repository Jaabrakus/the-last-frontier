class_name PoseOracle
extends RefCounted
## Reference pose evaluator for the animation tests (plan section 10). It computes local bone
## poses directly from Animation resources, without an AnimationTree, in two semantics:
##
## Graph semantics (what the bundled player graph means; rest = null-add, plan D7):
##   clip(c, t)               keyed channels from the clip, rest (bind pose) elsewhere
##   crossfade(a, b, w)       binary crossfade: per-bone slerp (rotation) / lerp (position, scale)
##   partial(base, layer, w)  override of the channels the layer keys, with weight w
##   additive(base, add, w)   base * (rest^-1 * add)^w on the channels `add` keys
##   direction_fw / _bw       the graph's lerp-scale direction chains (run-fw / run-bkwd trees)
##
## Godot semantics (AnimationMixer with deterministic = true), to check tree wiring exactly:
##   g_clip / g_blend2 / g_add2 / g_oneshot / g_blend_space_1d build a flat, ordered list of
##   (animation, time, per-bone weight) instances; g_eval() accumulates them as the mixer does:
##     rot   = rest * prod_i slerp(I, rest^-1 * q_i, w_i)   (in processing order)
##     pos   = rest + sum_i (p_i - rest) * w_i ;  scale likewise
##   Filters follow AnimationNode: Blend2 input 0 = FILTER_BLEND, input 1 = FILTER_PASS;
##   Add2 input 0 = FILTER_IGNORE (weight 1), input 1 = FILTER_PASS.
##
## Both agree on additive layers and on full-weight partial overrides; plain crossfades differ
## (Godot accumulates rest-relative deltas instead of slerping between inputs).
##
## Poses are PoseOracle.Pose (arrays indexed by bone). compare() reports max / mean errors;
## qdist() is an angle that stays accurate below float32 acos noise (~1e-3 rad).

class Pose:
	extends RefCounted
	var r: Array[Quaternion] = []
	var p := PackedVector3Array()
	var s := PackedVector3Array()
	## 1 where a source keyed the channel (rotation / position / scale).
	var kr := PackedByteArray()
	var kp := PackedByteArray()
	var ks := PackedByteArray()

	func size() -> int:
		return r.size()

	func copy() -> Pose:
		var o := Pose.new()
		o.r = r.duplicate()
		o.p = p.duplicate()
		o.s = s.duplicate()
		o.kr = kr.duplicate()
		o.kp = kp.duplicate()
		o.ks = ks.duplicate()
		return o

	func xform(i: int) -> Transform3D:
		return Transform3D(Basis(r[i]).scaled(s[i]), p[i])


var bone_names := PackedStringArray()
var bone_index := {}
var parents := PackedInt32Array()
var rest_r: Array[Quaternion] = []
var rest_p := PackedVector3Array()
var rest_s := PackedVector3Array()
var _resolve: Callable
var _tracks := {}


## sk: skeleton providing bone names, parents and rests (rest = null-add on Actor_B).
## source: AnimationMixer / AnimationPlayer, AnimationLibrary, or Callable(name) -> Animation.
func _init(sk: Skeleton3D, source: Variant) -> void:
	for i in sk.get_bone_count():
		bone_names.append(sk.get_bone_name(i))
		bone_index[sk.get_bone_name(i)] = i
		parents.append(sk.get_bone_parent(i))
		var rest := sk.get_bone_rest(i)
		rest_r.append(rest.basis.get_rotation_quaternion())
		rest_p.append(rest.origin)
		rest_s.append(rest.basis.get_scale())
	if source is Callable:
		_resolve = source
	elif source is AnimationMixer:
		var m: AnimationMixer = source
		_resolve = func(c: Variant) -> Animation:
			if c is Animation:
				return c
			var n := String(c)
			if m.has_animation(n):
				return m.get_animation(n)
			return m.get_animation("actor_b/" + n) if m.has_animation("actor_b/" + n) else null
	elif source is AnimationLibrary:
		var lib: AnimationLibrary = source
		_resolve = func(c: Variant) -> Animation:
			if c is Animation:
				return c
			return lib.get_animation(String(c)) if lib.has_animation(String(c)) else null


func bone_count() -> int:
	return bone_names.size()


func animation(c: Variant) -> Animation:
	var a: Animation = _resolve.call(c)
	if a == null:
		push_error("PoseOracle: unknown animation %s" % c)
	return a


# --- leaves ---------------------------------------------------------------------------------

func rest() -> Pose:
	var o := Pose.new()
	o.r = rest_r.duplicate()
	o.p = rest_p.duplicate()
	o.s = rest_s.duplicate()
	var n := bone_count()
	o.kr.resize(n)
	o.kp.resize(n)
	o.ks.resize(n)
	return o


## Graph leaf: the clip's keyed channels at time t (the Animation's interpolation), rest elsewhere.
func clip(c: Variant, t := 0.0) -> Pose:
	var o := rest()
	var a := animation(c)
	if a == null:
		return o
	for e: Array in _track_map(a):
		var b: int = e[0]
		match int(e[1]):
			Animation.TYPE_ROTATION_3D:
				o.r[b] = a.rotation_track_interpolate(e[2], t)
				o.kr[b] = 1
			Animation.TYPE_POSITION_3D:
				o.p[b] = a.position_track_interpolate(e[2], t)
				o.kp[b] = 1
			Animation.TYPE_SCALE_3D:
				o.s[b] = a.scale_track_interpolate(e[2], t)
				o.ks[b] = 1
	return o


## Current local pose of a skeleton (pre-modifier outside Skeleton3D.skeleton_updated, P13).
static func capture(sk: Skeleton3D) -> Pose:
	var o := Pose.new()
	var n := sk.get_bone_count()
	o.kr.resize(n)
	o.kp.resize(n)
	o.ks.resize(n)
	for i in n:
		o.r.append(sk.get_bone_pose_rotation(i))
		o.p.append(sk.get_bone_pose_position(i))
		o.s.append(sk.get_bone_pose_scale(i))
	return o


# --- graph semantics ----------------------------------------------------------------------

## Binary crossfade (graph BLEND node): w = 0 gives a, w = 1 gives b; every bone.
func crossfade(a: Pose, b: Pose, w: float) -> Pose:
	var o := a.copy()
	for i in o.size():
		o.r[i] = a.r[i].slerp(b.r[i], w)
		o.p[i] = a.p[i].lerp(b.p[i], w)
		o.s[i] = a.s[i].lerp(b.s[i], w)
		o.kr[i] = a.kr[i] | b.kr[i]
		o.kp[i] = a.kp[i] | b.kp[i]
		o.ks[i] = a.ks[i] | b.ks[i]
	return o


## Partial override (partial layer / masked blend). With bones == null the mask is the
## channels `layer` keys; with a bone list every channel of those bones is taken from `layer`
## (an unkeyed channel there is the rest value, which is what a filtered Godot input gives, P5).
func partial(base: Pose, layer: Pose, w: float, bones: Variant = null) -> Pose:
	var o := base.copy()
	var mask := _mask(bones)
	for i in o.size():
		var all := not mask.is_empty() and mask[i] == 1
		if all or (mask.is_empty() and layer.kr[i]):
			o.r[i] = base.r[i].slerp(layer.r[i], w)
			o.kr[i] = 1
		if all or (mask.is_empty() and layer.kp[i]):
			o.p[i] = base.p[i].lerp(layer.p[i], w)
			o.kp[i] = 1
		if all or (mask.is_empty() and layer.ks[i]):
			o.s[i] = base.s[i].lerp(layer.s[i], w)
			o.ks[i] = 1
	return o


## Additive layer: base * (rest^-1 * add)^w on the channels `add` keys (rest = null-add).
func additive(base: Pose, add: Pose, w: float) -> Pose:
	var o := base.copy()
	for i in o.size():
		if add.kr[i]:
			o.r[i] = (base.r[i] * Quaternion.IDENTITY.slerp(rest_r[i].inverse() * add.r[i], w)).normalized()
			o.kr[i] = 1
		if add.kp[i]:
			o.p[i] = base.p[i] + (add.p[i] - rest_p[i]) * w
			o.kp[i] = 1
		if add.ks[i]:
			o.s[i] = base.s[i] + (add.s[i] - rest_s[i]) * w
			o.ks[i] = 1
	return o


## Graph lerp-scale(in_min, in_max, out_min, out_max, x), clamped (inferred; see
## graph_understanding.json).
static func lerp_scale(in_min: float, in_max: float, out_min: float, out_max: float, x: float) -> float:
	var u := clampf((x - in_min) / (in_max - in_min), 0.0, 1.0)
	return out_min + (out_max - out_min) * u


## Graph angle-mod: wraps degrees into [-180, 180).
static func angle_mod(deg: float) -> float:
	return fposmod(deg + 180.0, 360.0) - 180.0


## run-fw chain weights at blend angle a (deg, + = left): {right, left}.
##   BLEND(fw_left)[ BLEND(fw_right)[fw, fw-rt], fw-lt ]
static func fw_weights(a_deg: float) -> Dictionary:
	return {"right": lerp_scale(-90.0, 0.0, 1.0, 0.0, a_deg), "left": lerp_scale(0.0, 90.0, 0.0, 1.0, a_deg)}


## run-bkwd chain weights: a' = angle-mod(int(a) + 180) (the graph truncates to int; pass
## truncate = false for the continuous form). {left, right, a2}.
##   BLEND(bw_right)[ BLEND(bw_left)[bw, bw-lt], bw-rt ]
static func bw_weights(a_deg: float, truncate := true) -> Dictionary:
	var a2 := angle_mod((float(int(a_deg)) if truncate else a_deg) + 180.0)
	return {"left": lerp_scale(-90.0, 0.0, 1.0, 0.0, a2), "right": lerp_scale(0.0, 90.0, 0.0, 1.0, a2), "a2": a2}


func direction_fw(fw: Pose, rt: Pose, lt: Pose, a_deg: float) -> Pose:
	var w := fw_weights(a_deg)
	return crossfade(crossfade(fw, rt, w.right), lt, w.left)


func direction_bw(bw: Pose, lt: Pose, rt: Pose, a_deg: float, truncate := true) -> Pose:
	var w := bw_weights(a_deg, truncate)
	return crossfade(crossfade(bw, lt, w.left), rt, w.right)


## The graph direction chain at bank position x in [-90, 90]:
##   crossfade(crossfade(center, neg, lerp_scale(-90, 0, 1, 0, x)), pos, lerp_scale(0, 90, 0, 1, x))
## fw bank: center fw, neg rt, pos lt, x = blend angle (== direction_fw).
## bw bank: center bw, neg lt, pos rt, x = a' (== direction_bw with truncate = false).
func bank_chain(center: Pose, neg: Pose, pos: Pose, x: float) -> Pose:
	return crossfade(crossfade(center, neg, lerp_scale(-90.0, 0.0, 1.0, 0.0, x)), pos, lerp_scale(0.0, 90.0, 0.0, 1.0, x))


## Gap between what a Godot direction bank computes and the graph's slerp chain, for one bank:
## a BlendSpace1D with points -90 neg, 0 center, +90 pos (plan 6.2: stretched unit timelines,
## sync = true, so every clip plays at the same normalized phase u, i.e. at u * its length)
## accumulates rest-relative deltas (g_eval), while the graph slerps between the inputs.
## Sampled at bank positions xs (deg) and phases us; bones = null compares the bones the three
## clips key (the 53 core bones for the locomotion banks).
## Returns {max_rot, max_rot_bone, x, u, mean_rot (mean over samples of the per-sample mean),
## max_pos, samples, bones}.
func bank_gap(center: Variant, neg: Variant, pos: Variant, xs: Array = [], us: Array = [], bones: Variant = null) -> Dictionary:
	if xs.is_empty():
		xs = range(-90, 91, 5)
	if us.is_empty():
		us = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]
	var clips := [animation(center), animation(neg), animation(pos)]
	if clips.has(null):
		return {"error": "missing clip"}
	if bones == null:
		var keyed_all := {}
		for a in clips:
			for n in keyed(a):
				keyed_all[n] = true
		bones = keyed_all.keys()
	var res := {"max_rot": 0.0, "max_rot_bone": "", "x": 0.0, "u": 0.0, "mean_rot": 0.0, "max_pos": 0.0,
			"samples": 0, "bones": bones.size()}
	var sum := 0.0
	for u: float in us:
		var t: Array[float] = []
		for a: Animation in clips:
			t.append(u * a.length)
		var g_pts := [[0.0, g_clip(clips[0], t[0])], [-90.0, g_clip(clips[1], t[1])], [90.0, g_clip(clips[2], t[2])]]
		var c0 := clip(clips[0], t[0])
		var cn := clip(clips[1], t[1])
		var cp := clip(clips[2], t[2])
		for x in xs:
			var d := compare(bank_chain(c0, cn, cp, float(x)), g_eval(g_blend_space_1d(g_pts, float(x))), bones)
			sum += d.mean_rot
			res.samples += 1
			res.max_pos = maxf(res.max_pos, d.max_pos)
			if d.max_rot > res.max_rot:
				res.max_rot = d.max_rot
				res.max_rot_bone = d.max_rot_bone
				res.x = float(x)
				res.u = u
	res.mean_rot = sum / maxi(1, res.samples)
	return res


# --- Godot AnimationMixer emulation (deterministic = true) ---------------------------------

## One animation instance: [{anim, t, w: PackedFloat32Array per bone}].
func g_clip(c: Variant, t := 0.0, weight := 1.0) -> Array:
	var w := PackedFloat32Array()
	w.resize(bone_count())
	w.fill(weight)
	return [{"anim": animation(c), "t": t, "w": w}]


## AnimationNodeBlend2. filter: null (filter disabled) or bone names (Array / Dictionary keys).
func g_blend2(a: Array, b: Array, amount: float, filter: Variant = null) -> Array:
	var mask := _mask(filter)
	return _scaled(a, 1.0 - amount, mask, "blend") + _scaled(b, amount, mask, "pass")


## AnimationNodeAdd2 (input 0 at weight 1, input 1 at amount).
func g_add2(a: Array, b: Array, amount: float, filter: Variant = null) -> Array:
	return _scaled(a, 1.0, PackedByteArray(), "ignore") + _scaled(b, amount, _mask(filter), "pass")


## AnimationNodeOneShot at fade weight `blend` (MIX_MODE_BLEND or, with add, MIX_MODE_ADD).
func g_oneshot(a: Array, b: Array, blend: float, filter: Variant = null, add := false) -> Array:
	return g_add2(a, b, blend, filter) if add else g_blend2(a, b, blend, filter)


## AnimationNodeBlendSpace1D (interpolated): points = [[position, instances], ...] in blend-point
## index order; x = blend_position.
func g_blend_space_1d(points: Array, x: float) -> Array:
	var ws := PackedFloat32Array()
	ws.resize(points.size())
	var order := range(points.size())
	order.sort_custom(func(i, j): return points[i][0] < points[j][0])
	if x <= points[order[0]][0]:
		ws[order[0]] = 1.0
	elif x >= points[order[-1]][0]:
		ws[order[-1]] = 1.0
	else:
		for k in order.size() - 1:
			var lo: float = points[order[k]][0]
			var hi: float = points[order[k + 1]][0]
			if x >= lo and x <= hi:
				var u := (x - lo) / (hi - lo)
				ws[order[k]] = 1.0 - u
				ws[order[k + 1]] = u
				break
	var out := []
	for i in points.size():
		out += _scaled(points[i][1], ws[i], PackedByteArray(), "ignore")
	return out


## Accumulates instances in order, as AnimationMixer::_blend_process does (deterministic).
func g_eval(instances: Array) -> Pose:
	var o := rest()
	for inst: Dictionary in instances:
		var a: Animation = inst.anim
		if a == null:
			continue
		var w: PackedFloat32Array = inst.w
		var t: float = inst.t
		for e: Array in _track_map(a):
			var b: int = e[0]
			var bw := w[b]
			if bw == 0.0:
				continue
			match int(e[1]):
				Animation.TYPE_ROTATION_3D:
					var q := a.rotation_track_interpolate(e[2], t)
					o.r[b] = (o.r[b] * Quaternion.IDENTITY.slerp(rest_r[b].inverse() * q, bw)).normalized()
					o.kr[b] = 1
				Animation.TYPE_POSITION_3D:
					o.p[b] += (a.position_track_interpolate(e[2], t) - rest_p[b]) * bw
					o.kp[b] = 1
				Animation.TYPE_SCALE_3D:
					o.s[b] += (a.scale_track_interpolate(e[2], t) - rest_s[b]) * bw
					o.ks[b] = 1
	return o


# --- model space and comparison -----------------------------------------------------------

## Skeleton-space transform of every bone.
func model_transforms(pose: Pose) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.resize(bone_count())
	var done := PackedByteArray()
	done.resize(bone_count())
	for i in bone_count():
		_model(pose, i, out, done)
	return out


## {max_rot, max_rot_bone, mean_rot, max_pos, max_pos_bone, n}. bones: null = all, or names.
## channels: "r", "p", "s" letters to compare.
func compare(expected: Pose, actual: Pose, bones: Variant = null, channels := "rp") -> Dictionary:
	var res := {"max_rot": 0.0, "max_rot_bone": "", "mean_rot": 0.0, "max_pos": 0.0, "max_pos_bone": "",
			"max_scale": 0.0, "n": 0}
	var mask := _mask(bones)
	var sum := 0.0
	for i in expected.size():
		if not mask.is_empty() and mask[i] == 0:
			continue
		res.n += 1
		if "r" in channels:
			var d := qdist(expected.r[i], actual.r[i])
			sum += d
			if d > res.max_rot:
				res.max_rot = d
				res.max_rot_bone = bone_names[i]
		if "p" in channels:
			var dp := expected.p[i].distance_to(actual.p[i])
			if dp > res.max_pos:
				res.max_pos = dp
				res.max_pos_bone = bone_names[i]
		if "s" in channels:
			res.max_scale = maxf(res.max_scale, expected.s[i].distance_to(actual.s[i]))
	res.mean_rot = sum / maxi(1, res.n)
	return res


## Rotation angle between two quaternions (rad), accurate for tiny angles.
static func qdist(a: Quaternion, b: Quaternion) -> float:
	var d := a.inverse() * b
	return 2.0 * atan2(Vector3(d.x, d.y, d.z).length(), absf(d.w))


## Bone names keyed by an animation.
func keyed(c: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	var a := animation(c)
	if a:
		for e: Array in _track_map(a):
			if not out.has(bone_names[e[0]]):
				out.append(bone_names[e[0]])
	return out


# --- internals ----------------------------------------------------------------------------

func _track_map(a: Animation) -> Array:
	var id := a.get_instance_id()
	if _tracks.has(id):
		return _tracks[id]
	var out := []
	for t in a.get_track_count():
		var ty := a.track_get_type(t)
		if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D and ty != Animation.TYPE_SCALE_3D:
			continue
		var bn := String(a.track_get_path(t).get_concatenated_subnames())
		if bone_index.has(bn):
			out.append([bone_index[bn], ty, t])
	_tracks[id] = out
	return out


func _mask(bones: Variant) -> PackedByteArray:
	var m := PackedByteArray()
	if bones == null:
		return m
	m.resize(bone_count())
	var names: Array = bones.keys() if bones is Dictionary else Array(bones)
	for n in names:
		var s := String(n)
		if s.contains(":"):
			s = s.get_slice(":", 1)
		if bone_index.has(s):
			m[bone_index[s]] = 1
	return m


## mode: "ignore" (all bones * k), "blend" (filtered * k, others 1), "pass" (filtered * k, others 0).
func _scaled(insts: Array, k: float, mask: PackedByteArray, mode: String) -> Array:
	var out := []
	for inst: Dictionary in insts:
		var w: PackedFloat32Array = inst.w.duplicate()
		for i in w.size():
			if mask.is_empty() or mode == "ignore":
				w[i] *= k
			elif mask[i] == 1:
				w[i] *= k
			elif mode == "pass":
				w[i] = 0.0
		out.append({"anim": inst.anim, "t": inst.t, "w": w})
	return out


func _model(pose: Pose, i: int, out: Array[Transform3D], done: PackedByteArray) -> Transform3D:
	if done[i]:
		return out[i]
	var local := pose.xform(i)
	var par := parents[i]
	out[i] = local if par < 0 else _model(pose, par, out, done) * local
	done[i] = 1
	return out[i]
