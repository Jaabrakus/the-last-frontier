class_name TravClipSampler
extends RefCounted
## Evaluates Actor_B clips (Animation resources) on the rig's bone hierarchy without an
## AnimationPlayer: the skeleton-space pose at any time, and the traversal contact points.
## Used offline by tools/traversal/build_runtime_table.gd (reference tracks), by the tests
## (analytic alignment checks) and by the preview's cross-check against the live skeleton.
##
##   var s := TravClipSampler.from_skeleton(skeleton)      # after BindRest.ensure()
##   var p := s.points(anim, 0.25)                          # name -> Vector3 (skeleton space)
##
## Skeleton space: +Z forward, +X left, +Y up, origin at the feet (the clip's align frame; the
## game's align / trajectory channel was not exported, see clip_geometry.json meta).
## Contact points (l/r_hand, l/r_foot, l/r_knee) are the RENDERED surfaces: the lowest point of
## the mesh-calibrated probe vertices (TravContactProbes, data/traversal/contact_probes.json:
## palm / fingers, shoe sole, kneecap), its xz the soft-min centre. Without the probe file they
## fall back to the clip survey's bone-origin rule (points_from_bones()):
##   hand  = palm origin horizontally, height = lowest of palm / middle metacarpal / middle
##           knuckle origins - HAND_SKIN (bone origins sit inside the hand);
##   foot  = the lower of heel and ball (ball - BALL_SOLE), its origin with that height;
##   knee  = the knee joint origin.
## (The calibration measured the bone rule against the mesh: it was off by several cm, which is
## what made hands and feet float above or sink into the tops.)
## Nothing here writes to an Animation or to the rig.

const HAND_SKIN := 0.02
const BALL_SOLE := 0.018
const HEAD_TOP := 0.13

## Named points returned by points(). Contact points first (the tracks store these).
const CONTACT_POINTS := ["l_hand", "r_hand", "l_foot", "r_foot", "l_knee", "r_knee"]
const BODY_POINTS := ["pelvis", "spinea", "spined", "neck", "head_top", "l_shoulder", "r_shoulder",
		"l_elbow", "r_elbow", "l_wrist", "r_wrist", "l_upper_leg", "r_upper_leg", "l_knee_j", "r_knee_j",
		"l_ankle", "r_ankle", "l_heel", "r_heel", "l_ball", "r_ball", "l_palm", "r_palm"]
## Bones needed for all points.
const NEEDED_BONES := ["root", "pelvis", "spinea", "spined", "neck", "headb",
		"l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist",
		"l_palm", "r_palm", "l_middle_metacarpal", "r_middle_metacarpal", "l_middlea", "r_middlea",
		"l_upper_leg", "r_upper_leg", "l_knee", "r_knee", "l_ankle", "r_ankle",
		"l_heel", "r_heel", "l_ball", "r_ball"]

var names := PackedStringArray()
var parents := PackedInt32Array()
var rest: Array[Transform3D] = []
var _index := {}
var _depth := PackedInt32Array()
var _closure := PackedInt32Array()
var _track_cache := {}   # Animation instance id -> {bone: PackedInt32Array[pos, rot, scl]}
var probes: TravContactProbes = null
## Per-hand override of TraversalIK.GRIP_OFFSET for the l/r_grip points (a ladder move's own fist
## hole, data/traversal/ladder_grips.json; set by the table builder while it samples that move).
var grip_offsets := {}
var _probe_idx := {}     # limb -> PackedInt32Array
var use_probes := true


static func from_skeleton(sk: Skeleton3D) -> TravClipSampler:
	var s := TravClipSampler.new()
	for b in sk.get_bone_count():
		s.names.append(sk.get_bone_name(b))
		s.parents.append(sk.get_bone_parent(b))
		s.rest.append(sk.get_bone_rest(b))
		s._index[sk.get_bone_name(b)] = b
	for b in sk.get_bone_count():
		var d := 0
		var p := s.parents[b]
		while p >= 0:
			d += 1
			p = s.parents[p]
		s._depth.append(d)
	var need := PackedInt32Array()
	for n in NEEDED_BONES:
		var b := s.bone(n)
		if b >= 0:
			need.append(b)
	var cp := TravContactProbes.shared()
	if cp.ok:
		s.probes = cp
		for n in cp.bone_names():
			var b := s.bone(n)
			if b >= 0:
				need.append(b)
		for limb: String in cp.limbs:
			if not limb.ends_with("_guard"):
				s._probe_idx[limb] = cp.indices(limb, s.bone)
	s._closure = s.closure(need)
	return s


func bone(n: String) -> int:
	return _index.get(n, -1)


func bone_count() -> int:
	return names.size()


func closure(bones: PackedInt32Array) -> PackedInt32Array:
	var seen := {}
	for b in bones:
		var p := b
		while p >= 0 and not seen.has(p):
			seen[p] = true
			p = parents[p]
	var arr := seen.keys()
	arr.sort_custom(func(x, y): return _depth[x] < _depth[y] or (_depth[x] == _depth[y] and x < y))
	return PackedInt32Array(arr)


func _tracks(a: Animation) -> Dictionary:
	var key := a.get_instance_id()
	if _track_cache.has(key):
		return _track_cache[key]
	var keyed := {}
	for t in a.get_track_count():
		var slot := -1
		match a.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				slot = 0
			Animation.TYPE_ROTATION_3D:
				slot = 1
			Animation.TYPE_SCALE_3D:
				slot = 2
		if slot < 0:
			continue
		var b := bone(str(a.track_get_path(t).get_concatenated_subnames()))
		if b < 0:
			continue
		if not keyed.has(b):
			keyed[b] = PackedInt32Array([-1, -1, -1])
		var m: PackedInt32Array = keyed[b]
		m[slot] = t
		keyed[b] = m
	_track_cache[key] = keyed
	return keyed


## Local transform of bone b at time t (the bone's rest where the clip does not key it; the
## same rule the AnimationMixer applies with the null-add rest from BindRest).
func local(a: Animation, b: int, t: float) -> Transform3D:
	var r: Transform3D = rest[b]
	var keyed := _tracks(a)
	if not keyed.has(b):
		return r
	var m: PackedInt32Array = keyed[b]
	var pos := a.position_track_interpolate(m[0], t) if m[0] >= 0 else r.origin
	var rot := a.rotation_track_interpolate(m[1], t).normalized() if m[1] >= 0 else r.basis.get_rotation_quaternion()
	var scl := a.scale_track_interpolate(m[2], t) if m[2] >= 0 else r.basis.get_scale()
	return Transform3D(Basis(rot) * Basis.from_scale(scl), pos)


## Skeleton-space transforms of the point bones (and their ancestors) at time t.
func globals(a: Animation, t: float, bones := PackedInt32Array()) -> Dictionary:
	var order := _closure if bones.is_empty() else closure(bones)
	var g := {}
	for b in order:
		var p := parents[b]
		g[b] = (g[p] as Transform3D) * local(a, b, t) if p >= 0 and g.has(p) else local(a, b, t)
	return g


## Contact and body points (skeleton space) from a globals() dictionary: contacts from the
## mesh-calibrated probes when available.
func points_from(g: Dictionary) -> Dictionary:
	var out := points_from_bones(g)
	if probes != null and use_probes:
		for limb: String in _probe_idx:
			var c := TravContactProbes.contact_of(probes.eval_globals(limb, g, _probe_idx[limb]))
			out[limb] = c.p
	return out


## Probe positions of a limb (skeleton space) from a globals() dictionary / pose array.
func probe_points(limb: String, g) -> PackedVector3Array:
	if probes == null or not _probe_idx.has(limb):
		return PackedVector3Array()
	return probes.eval_globals(limb, g, _probe_idx[limb])


## The survey's bone-origin contact rule (the pre-calibration definition).
func points_from_bones(g: Dictionary) -> Dictionary:
	var o := func(n: String) -> Vector3:
		var b := bone(n)
		return (g[b] as Transform3D).origin if b >= 0 and g.has(b) else Vector3.ZERO
	var out := {}
	for side in ["l", "r"]:
		var palm: Vector3 = o.call(side + "_palm")
		var mm: Vector3 = o.call(side + "_middle_metacarpal")
		var ma: Vector3 = o.call(side + "_middlea")
		out[side + "_hand"] = Vector3(palm.x, minf(palm.y, minf(mm.y, ma.y)) - HAND_SKIN, palm.z)
		var heel: Vector3 = o.call(side + "_heel")
		var ball: Vector3 = o.call(side + "_ball")
		var ball_sole := ball.y - BALL_SOLE
		out[side + "_foot"] = Vector3(heel.x, heel.y, heel.z) if heel.y <= ball_sole else Vector3(ball.x, ball_sole, ball.z)
		out[side + "_knee"] = o.call(side + "_knee")
		out[side + "_knee_j"] = out[side + "_knee"]
		for n in ["shoulder", "elbow", "wrist", "upper_leg", "ankle", "heel", "ball", "palm"]:
			out[side + "_" + n] = o.call(side + "_" + n)
		# The closed fist's hole (TraversalIK.GRIP_OFFSET in the wrist frame): where a rung sits in
		# the hand (the ladder clips' held hand carries their align, traversal_moves.json).
		var wb := bone(side + "_wrist")
		if wb >= 0 and g.has(wb):
			out[side + "_grip"] = (g[wb] as Transform3D) * (grip_offsets.get(side + "_hand", TraversalIK.GRIP_OFFSET[side + "_hand"]) as Vector3)
	out["pelvis"] = o.call("pelvis")
	out["spinea"] = o.call("spinea")
	out["spined"] = o.call("spined")
	out["neck"] = o.call("neck")
	out["head_top"] = o.call("headb") + Vector3(0, HEAD_TOP, 0)
	return out


func points(a: Animation, t: float) -> Dictionary:
	return points_from(globals(a, clampf(t, 0.0, a.length)))


## Full-skeleton pose (every bone, skeleton space) at time t; for the IK solver in tests.
func pose(a: Animation, t: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.resize(names.size())
	var order := closure(PackedInt32Array(range(names.size())))
	for b in order:
		var p := parents[b]
		out[b] = out[p] * local(a, b, t) if p >= 0 else local(a, b, t)
	return out
