class_name StanceInertializer
extends SkeletonModifier3D
## Inertialized stance changes (plan WP10, crouch <-> stand; CROUCH_HANDS part ch-crouchB).
##
## A crouch toggle swaps the player tree's lower-body input for one of the other stance: the other
## stance's locomotion bank while moving (the graph's change-move-mode records 0x0002a970 /
## 0x000252f0, 0.5 s; aim-run 0x00030a50, 0.25 s), the other stance's aim idle (0x00038070,
## 0.25 s), the full-body crouch change and its exits. The graph realizes those fades as
## crossfades of two playing instances. Across a stance change that blends two gaits of different
## cadence, stride and pelvis height: the feet of the two clips drift apart (double steps), and the
## pelvis and knees move along a straight blend of two unrelated poses. Instead LocoBrain switches
## the lower selector to the target input at once, phase-matched to the current stride, and this
## modifier keeps the shown pose and its velocity continuous: per bone, the offset from the new
## pose to where the old pose would be this frame (last shown + one frame of its velocity), and
## the difference of their velocities, decay to zero over the transition's graph fade time along
## a quintic (Bollo, "Inertialization: High-Performance Animation Transitions in Gears of War",
## GDC 2018):
##   x(t) = A t^5 + B t^4 + C t^3 + a0/2 t^2 + v0 t + x0,   x(t1) = x'(t1) = x''(t1) = 0,
##   a0 = max(0, (-8 v0 t1 - 20 x0) / t1^2),  t1 = min(T, -5 x0 / v0) when v0 < 0,
## along the offset's own direction (a velocity pointing away from the new pose is dropped). With
## no velocity difference that is x0 (1 - smootherstep(t / T)): the pose eases out of the old
## stance and into the new one over the graph fade, with no overshoot. The target content plays
## at full weight from the switch, so its feet keep their own timing (no double step).
##
## Order: the first SkeletonModifier3D of the skeleton, on the AnimationTree's pose (before
## PropFlipGuard and AimStabilizer, which then work on the inertialized pose; the skinned body's
## CharacterBodyMesh keeps itself last). Its own output is the pose it remembers as "shown".
##
##   inert.start(0.5)     # LocoBrain.inertia_request: the frame the new input is applied
##   inert.tick(dt)       # PlayerAnim.manual_step, after advance(): the frame's dt
##   inert.cancel()       # snap / revive / teleport: no inertialization, forget the history
##
## Cost: the bones the lower-body inputs key (set_bones()); while nothing runs, one read of their
## poses per frame.

## Clamps of the initial offsets and of the carried velocity difference (a missed teleport must
## not fling the pose).
const MAX_OFFSET_RAD := PI
const MAX_OFFSET_M := 0.6
const MAX_VEL := 12.0
const EPS := 1e-6

## Inertialized bones (skeleton indices); empty = every bone.
var bones := PackedInt32Array()
## Bones whose offset decays WITHOUT the velocity terms (a plain eased blend from the old pose): the arms,
## hands, fingers, weapon prop bones, neck and head (user playtest 2026-09-25: "fix the elbow transition to
## crouch": standing up from a crouch-walk the carried velocity of the arm chain, stacked on a torso
## straightening by 60 deg, swung the musket to vertical and the left arm over the head).
var calm := {}
## ... and blend over this fraction of the transition (the arms re-grip quickly while the legs and pelvis
## take the graph's full fade: a long arm blend between the crouch-walk carry, gun forward, and the
## standing carry, gun across the chest, spends half a second in poses that sweep the gun past the head).
const CALM_TIME_SCALE := 0.5
## Duration of the running (or last) transition (s).
var duration := 0.5
## Bones with a non-zero offset on the last run (diagnostics).
var active_bones := 0
## usec of the last run (diagnostics).
var cost_usec := 0
## Transitions started since creation (diagnostics / tests).
var started := 0

var _dt := 1.0 / 60.0
var _tick := 0                  ## PlayerAnim frames (tick())
var _run_tick := -1             ## tick of the last run (several runs in one frame redo the same output)
var _pending := -1.0            ## requested duration (> 0) for the next run
var _t := -1.0                  ## time since the switch (< 0: nothing runs)
var _start_tick := -2
var _need_vel := false
var _idx := PackedInt32Array()
var _shown_r: Array[Quaternion] = []   ## this modifier's output of its latest run
var _shown_p := PackedVector3Array()
var _last_r: Array[Quaternion] = []    ## shown at the end of the previous frame
var _last_p := PackedVector3Array()
var _prev_r: Array[Quaternion] = []    ## and the frame before
var _prev_p := PackedVector3Array()
var _cur0_r: Array[Quaternion] = []    ## the new content's first pose (its velocity next frame)
var _cur0_p := PackedVector3Array()
var _rdir := PackedVector3Array()      ## unit direction of each rotation offset (rotation vector)
var _pdir := PackedVector3Array()      ## ... of each position offset
var _rx := PackedFloat64Array()        ## per bone: x0, v0, a0, A, B, C, t1 (rotation, rad)
var _px := PackedFloat64Array()        ## ... (position, m)
var _wv_old := PackedVector3Array()    ## old content's velocities at the switch
var _pv_old := PackedVector3Array()


## Adds the modifier as the first SkeletonModifier3D child of `sk` (before PropFlipGuard and the
## AimStabilizer).
static func create(sk: Skeleton3D, p_bones := PackedInt32Array()) -> StanceInertializer:
	var m := StanceInertializer.new()
	m.name = "StanceInertializer"
	m.bones = p_bones
	m.influence = 1.0
	sk.add_child(m)
	var first := -1
	for i in sk.get_child_count():
		if sk.get_child(i) is SkeletonModifier3D:
			first = i
			break
	if first >= 0 and first < m.get_index():
		sk.move_child(m, first)
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.begins_with("neck") or n.begins_with("head") or n.contains("clavicle") or n.contains("shoulder") \
				or n.contains("elbow") or n.contains("wrist") or n.contains("forarm") or n.contains("hand") \
				or n.contains("palm") or n.contains("prop") or n.contains("thumb") or n.contains("index") \
				or n.contains("middle") or n.contains("ring") or n.contains("pinky") or n.contains("bicep"):
			m.calm[i] = true
	return m


## The union of the bones the given animations key (rotation / position tracks).
static func bones_of(sk: Skeleton3D, anims: Array) -> PackedInt32Array:
	var seen := {}
	for a in anims:
		if not a is Animation:
			continue
		for t in (a as Animation).get_track_count():
			var ty := (a as Animation).track_get_type(t)
			if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
				continue
			var bi := sk.find_bone(String((a as Animation).track_get_path(t)).get_slice(":", 1))
			if bi >= 0:
				seen[bi] = true
	var ids := seen.keys()
	ids.sort()
	return PackedInt32Array(ids)


## Starts an inertialized transition of `p_duration` s on the next run (call it on the frame the
## new content is applied, before its advance). A start while one runs replaces it: the new
## offsets start from the pose shown, which includes the old offsets.
func start(p_duration: float) -> void:
	_pending = maxf(p_duration, 0.02)


## True while a transition runs or is pending.
func running() -> bool:
	return _t >= 0.0 or _pending > 0.0


## Seconds left of the running transition (0 when none).
func remaining() -> float:
	if _pending > 0.0:
		return _pending
	return maxf(duration - _t, 0.0) if _t >= 0.0 else 0.0


## No inertialization; forget the shown pose (spawn, respawn, a teleport).
func cancel() -> void:
	_t = -1.0
	_pending = -1.0
	_need_vel = false
	_last_r = []
	_prev_r = []
	_shown_r = []


## PlayerAnim: a new animation frame of `dt` s was advanced (runs until the next tick() redo the
## same frame).
func tick(dt: float) -> void:
	_tick += 1
	if dt > 0.0:
		_dt = dt


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var t_us := Time.get_ticks_usec()
	var nb := bones.size() if not bones.is_empty() else sk.get_bone_count()
	if _idx.size() != nb:
		_idx = bones.duplicate() if not bones.is_empty() else PackedInt32Array(range(nb))
		_shown_r = []
		_last_r = []
		_prev_r = []
		_t = -1.0
		_need_vel = false
	var n := _idx.size()
	var new_frame := _tick != _run_tick
	if new_frame:
		_run_tick = _tick
		# Several runs in one frame (a forced update): each redoes the frame from its input; the
		# history moves on once per frame.
		_prev_r = _last_r
		_prev_p = _last_p
		_last_r = _shown_r.duplicate()
		_last_p = _shown_p.duplicate()
		if _t >= 0.0 and _start_tick != _tick:
			_t += _dt
	if _pending > 0.0 and new_frame:
		if _last_r.size() == n:
			duration = _pending
			_start_tick = _tick
			_t = 0.0
			started += 1
		_pending = -1.0
	if _start_tick == _tick and _t >= 0.0:
		_begin(sk, n)
	elif _need_vel and new_frame and _t >= 0.0:
		_need_vel = false
		_fit(sk, n)
	if _t >= 0.0:
		if _t >= duration:
			_t = -1.0
			active_bones = 0
		else:
			_apply(sk, n)
	# This run's output (what the next frame continues from).
	if _shown_r.size() != n:
		_shown_r.resize(n)
		_shown_p.resize(n)
	for k in n:
		var b := _idx[k]
		_shown_r[k] = sk.get_bone_pose_rotation(b)
		_shown_p[k] = sk.get_bone_pose_position(b)
	cost_usec = Time.get_ticks_usec() - t_us


## The switch frame: offsets from the new content's first pose to where the old one would be now.
func _begin(sk: Skeleton3D, n: int) -> void:
	var have_prev := _prev_r.size() == n
	_rdir.resize(n)
	_pdir.resize(n)
	_rx.resize(n * 7)
	_px.resize(n * 7)
	_cur0_r.resize(n)
	_cur0_p.resize(n)
	_wv_old.resize(n)
	_pv_old.resize(n)
	for k in n:
		var b := _idx[k]
		var cr := sk.get_bone_pose_rotation(b)
		var cp := sk.get_bone_pose_position(b)
		_cur0_r[k] = cr
		_cur0_p[k] = cp
		var wv := Vector3.ZERO
		var pv := Vector3.ZERO
		if have_prev:
			wv = _clampv(_rotvec(_last_r[k] * _prev_r[k].inverse()) / _dt, MAX_VEL)
			pv = _clampv((_last_p[k] - _prev_p[k]) / _dt, MAX_VEL)
		_wv_old[k] = wv
		_pv_old[k] = pv
		if calm.has(b):
			wv = Vector3.ZERO    # from where it was shown, not where its motion would have taken it
			pv = Vector3.ZERO
		var r0 := _clampv(_rotvec(_quat(wv * _dt) * _last_r[k] * cr.inverse()), MAX_OFFSET_RAD)
		var p0 := _clampv(_last_p[k] + pv * _dt - cp, MAX_OFFSET_M)
		var ts := CALM_TIME_SCALE if calm.has(b) else 1.0
		_set_curve(_rx, _rdir, k, r0, Vector3.ZERO, ts)
		_set_curve(_px, _pdir, k, p0, Vector3.ZERO, ts)
	_need_vel = true


## The frame after the switch: the new content's velocity is known; fit the curves with the
## velocity difference (the offsets at t = 0 are unchanged, so nothing jumps).
func _fit(sk: Skeleton3D, n: int) -> void:
	for k in n:
		var b := _idx[k]
		var wv_new := _rotvec(sk.get_bone_pose_rotation(b) * _cur0_r[k].inverse()) / _dt
		var pv_new := (sk.get_bone_pose_position(b) - _cur0_p[k]) / _dt
		var r0 := _rdir[k] * _rx[k * 7]
		var p0 := _pdir[k] * _px[k * 7]
		if calm.has(b):
			continue    # a plain eased blend (no velocity terms): see `calm`
		_set_curve(_rx, _rdir, k, r0, _clampv(_wv_old[k] - wv_new, MAX_VEL))
		_set_curve(_px, _pdir, k, p0, _clampv(_pv_old[k] - pv_new, MAX_VEL))


func _apply(sk: Skeleton3D, n: int) -> void:
	active_bones = 0
	for k in n:
		var b := _idx[k]
		var xr := _eval(_rx, k, _t)
		var xp := _eval(_px, k, _t)
		if absf(xr) > EPS:
			sk.set_bone_pose_rotation(b, (_quat(_rdir[k] * xr) * sk.get_bone_pose_rotation(b)).normalized())
			active_bones += 1
		if absf(xp) > EPS:
			sk.set_bone_pose_position(b, sk.get_bone_pose_position(b) + _pdir[k] * xp)


## Offset curve of entry k: x0 = |x|, direction x / |x|, v0 = v along it (dropped when it points
## away from the new pose), t1 and the quintic's coefficients.
func _set_curve(c: PackedFloat64Array, dirs: PackedVector3Array, k: int, x: Vector3, v: Vector3, t_scale := 1.0) -> void:
	var x0 := x.length()
	var o := k * 7
	if x0 < EPS:
		dirs[k] = Vector3.ZERO
		for i in 7:
			c[o + i] = 0.0
		return
	var d := x / x0
	dirs[k] = d
	var v0 := v.dot(d)
	if v0 > 0.0:
		v0 = 0.0
	var t1 := duration * t_scale
	if v0 < 0.0:
		t1 = minf(t1, -5.0 * x0 / v0)
	t1 = maxf(t1, 1e-3)
	var a0 := maxf(0.0, (-8.0 * v0 * t1 - 20.0 * x0) / (t1 * t1))
	c[o] = x0
	c[o + 1] = v0
	c[o + 2] = a0
	c[o + 3] = -(a0 * t1 * t1 + 6.0 * v0 * t1 + 12.0 * x0) / (2.0 * pow(t1, 5.0))
	c[o + 4] = (3.0 * a0 * t1 * t1 + 16.0 * v0 * t1 + 30.0 * x0) / (2.0 * pow(t1, 4.0))
	c[o + 5] = -(3.0 * a0 * t1 * t1 + 12.0 * v0 * t1 + 20.0 * x0) / (2.0 * pow(t1, 3.0))
	c[o + 6] = t1


static func _eval(c: PackedFloat64Array, k: int, t: float) -> float:
	var o := k * 7
	var t1 := c[o + 6]
	if t1 <= 0.0 or t >= t1:
		return 0.0
	var tt := maxf(t, 0.0)
	return (((c[o + 3] * tt + c[o + 4]) * tt + c[o + 5]) * tt + 0.5 * c[o + 2]) * tt * tt + c[o + 1] * tt + c[o]


static func _clampv(v: Vector3, m: float) -> Vector3:
	var l := v.length()
	return v * (m / l) if l > m else v


static func _rotvec(q: Quaternion) -> Vector3:
	q = q.normalized()
	if q.w < 0.0:
		q = -q
	var s := Vector3(q.x, q.y, q.z).length()
	if s < 1e-9:
		return Vector3.ZERO
	return Vector3(q.x, q.y, q.z) / s * (2.0 * atan2(s, q.w))


static func _quat(r: Vector3) -> Quaternion:
	var a := r.length()
	if a < 1e-9:
		return Quaternion.IDENTITY
	return Quaternion(r / a, a)
