class_name TravInertializer
extends SkeletonModifier3D
## Inertialization for traversal seams: the reusable runtime component the standalone preview
## (TravPreviewActor) uses and the player integration will use (user complaint 2026-09-24
## "snapping / teleporting"). It keeps POSITION AND VELOCITY continuous at every content switch
## (entry from locomotion, part join inside a move, chained segment, exit to locomotion, landing)
## instead of blending in a frozen last frame or jumping:
##
##   pose  (this SkeletonModifier3D, after the animation and before TraversalIK; the character
##         body modifier stays last): per bone, the offset from the new content's pose to where
##         the old pose would be this frame (last shown + one frame of its velocity) AND the
##         difference of their velocities decay to zero over `duration`:
##           x(t) = (x0 + v0 t) (1 - smoothstep(t / T))
##         so every bone's position and velocity stay continuous and the pose settles on the new
##         clip.
##   root  (plain methods; the caller places the rig with the result): the rendered root keeps
##         its position, velocity, yaw and yaw rate at a switch and the offset to the new root
##         decays the same way.
##
## Which seam uses what (TravPreviewActor, the reference for the player integration):
##   part join (a move's parts meet at the graph's 0 s joins): start(T) + root_transition(T) with
##         the SAME T. The move's path (traversal_runtime.json, TravMotionWarper) is built so the
##         root carries the opposite of the clip's root-bone jump (position and velocity) and the
##         world body is continuous; the two offsets then cancel and the body follows the path,
##         while a bend of the path at the join (a take-off right after it) is smoothed. This
##         only holds when the path's root is not low-passed across the join (the warper smooths
##         the world pelvis instead) and steps exactly on the frame the clip switches
##         (TravWarpedPath.root_at / part_at share the join times).
##   ended clip / chained segment / exit / landing: start(max(fade, 0.2)) + root_transition.
##   entry from locomotion: a crossfade of the graph's fade + root_transition (start() over the
##         fade also works; measured on the course it popped more hands, see
##         TravPreviewActor.entry_inertialize).
##   Mode NO_ROOT_TRANSLATION leaves the root bone's translation alone (for a caller whose root
##         already follows a path that absorbs the clip's root-bone jumps exactly and gets no
##         root_transition).
##
##   inert.start(0.15)                                   # the frame the new content is applied
##   inert.start(0.15, TravInertializer.NO_ROOT_TRANSLATION)
##   inert.root_transition(new_root, new_root_vel, 0.2, delta)   # at the switch
##   rig.global_transform = inert.root_place(target_root, delta) # every frame
##   inert.reset(rig.global_transform)                   # a teleport: no inertialization
##
## Cost: only the animated bones (set_bones_from_clips) are recorded and offset; while no
## inertialization runs, a frame costs one read of those bones' poses.

enum { FULL, NO_ROOT_TRANSLATION }

const MAX_OFFSET_M := 0.6          ## clamp of the initial offsets (a missed teleport must not fling the pose)
## ... of the root-motion bone's translation: a cinematic clip's root bone can stand well away from
## its align (the squeeze's starts 0.63 m from the walk's), and its offset cancels the rig root's (the
## root transition, clamped at 2 x MAX_OFFSET_M): clamped at 0.6 m the body jumped 2.7 cm.
const MAX_ROOT_OFFSET_M := 1.2
const MAX_OFFSET_RAD := 2.0
const MAX_VEL := 12.0              ## m/s or rad/s: clamp of the carried velocity difference

var duration := 0.15
var mode := FULL
var active_bones := 0
## Bones this modifier inertializes (skeleton indices); empty = every bone.
var bones := PackedInt32Array()
## The skeleton's root-motion bone (translation excluded in NO_ROOT_TRANSLATION); -1 = none.
var root_bone := -1
## Diagnostics: usec of the last run.
var cost_usec := 0

var _t := -1.0
var _pending := false
var _pending_mode := FULL
var _pending_zero := {}
var _zero_vel := {}
var _frame := -1
var _start_frame := -2
var _dt := 1.0 / 120.0
var _shown_rot: Array = []   ## this modifier's output of its latest run (per entry of `bones`)
var _shown_pos: Array = []
var _last_rot: Array = []    ## the pose shown at the end of the previous frame (before the plants)
var _last_pos: Array = []
var _prev_rot: Array = []    ## and the frame before
var _prev_pos: Array = []
var _cur0_rot: Array = []    ## the new content's first pose (for its velocity next frame)
var _cur0_pos: Array = []
var _r0: Array = []          ## rotation offset (rotation vector, local)
var _p0: Array = []          ## position offset
var _wv: Array = []          ## offset angular velocity (rotation vector / s)
var _pv: Array = []          ## offset velocity
var _need_vel := false
var _idx := PackedInt32Array()

# Root (rig) inertialization state.
var _root_shown := Transform3D.IDENTITY
var _root_vel := Vector3.ZERO
var _root_yaw_vel := 0.0
var _root_init := false
var _ro_p := Vector3.ZERO
var _ro_v := Vector3.ZERO
var _ro_yaw := 0.0
var _ro_yaw_v := 0.0
var _ro_t := 1e9
var _ro_len := 0.2


# --------------------------------------------------------------------------------------------------
# Pose
# --------------------------------------------------------------------------------------------------

## Starts a pose inertialization on the next skeleton update (call it on the frame the new
## content is applied). A start while one runs replaces it (the new offsets start from the pose
## shown, which includes the old offsets).
## zero_vel: bone indices whose velocity difference is not carried (only their offset decays): the
## legs at a part join where a foot comes down on its surface (fix round 3, 2026-09-25: carried, the
## landing foot's downward velocity took the pose's foot 4-10 cm into the ground after the gap jump's
## and the standing vault's landing joins).
func start(p_duration: float, p_mode := FULL, zero_vel: Array = []) -> void:
	duration = maxf(p_duration, 0.02)
	_pending = true
	_pending_mode = p_mode
	_pending_zero = {}
	for b in zero_vel:
		_pending_zero[int(b)] = true


func running() -> bool:
	return _t >= 0.0 or _pending


## Stops any running pose inertialization and forgets the shown pose (a teleport).
func reset(root_xform := Transform3D.IDENTITY, have_root := false) -> void:
	_t = -1.0
	_pending = false
	_last_rot = []
	_prev_rot = []
	_shown_rot = []
	if have_root:
		root_reset(root_xform)


## The animated bones of `clips` (an AnimationPlayer's animation names) as the bone set, plus the
## skeleton's root-motion bone `root_name`. Bones without tracks (the helper bones the body
## modifier drives, face bones) are left alone: they cost time and carry no seam.
func set_bones_from_clips(sk: Skeleton3D, ap: AnimationPlayer, clips: PackedStringArray, root_name := "root") -> void:
	var seen := {}
	for c in clips:
		var a := ap.get_animation(c)
		if a == null:
			continue
		for t in a.get_track_count():
			var ty := a.track_get_type(t)
			if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
				continue
			var bi := sk.find_bone(str(a.track_get_path(t)).get_slice(":", 1))
			if bi >= 0:
				seen[bi] = true
	var ids := seen.keys()
	ids.sort()
	bones = PackedInt32Array(ids)
	root_bone = sk.find_bone(root_name)
	_shown_rot = []
	_last_rot = []
	_prev_rot = []


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var t_us := Time.get_ticks_usec()
	if _idx.size() != (bones.size() if not bones.is_empty() else sk.get_bone_count()):
		if bones.is_empty():
			_idx.resize(sk.get_bone_count())
			for b in _idx.size():
				_idx[b] = b
		else:
			_idx = bones.duplicate()
		_shown_rot = []
		_last_rot = []
		_prev_rot = []
	var n := _idx.size()
	var new_frame := Engine.get_process_frames() != _frame
	if new_frame:
		_frame = Engine.get_process_frames()
		_dt = maxf(get_process_delta_time(), 1.0 / 240.0)
		# The skeleton can update several times in a frame (seeks): the pose "shown" in a frame
		# is the output of its last run.
		_prev_rot = _last_rot
		_prev_pos = _last_pos
		_last_rot = _shown_rot.duplicate()
		_last_pos = _shown_pos.duplicate()
	if _pending:
		_pending = false
		if _last_rot.size() == n and _prev_rot.size() == n:
			_start_frame = _frame
			_t = 0.0
			mode = _pending_mode
			_zero_vel = _pending_zero
	if _start_frame == _frame and _t >= 0.0:
		# Every run of the start frame recomputes the offsets from its input, so the run that
		# carries the new content (after the switch) is the one that counts.
		_r0.resize(n)
		_p0.resize(n)
		_wv.resize(n)
		_pv.resize(n)
		_cur0_rot.resize(n)
		_cur0_pos.resize(n)
		for k in n:
			var b := _idx[k]
			var cr := sk.get_bone_pose_rotation(b)
			var cp := sk.get_bone_pose_position(b)
			_cur0_rot[k] = cr
			_cur0_pos[k] = cp
			# The old content's velocity; the new one's is known next frame (_need_vel).
			var wv_old := _clampv(_rotvec((_last_rot[k] as Quaternion) * (_prev_rot[k] as Quaternion).inverse()) / _dt, MAX_VEL)
			var pv_old := _clampv(((_last_pos[k] as Vector3) - (_prev_pos[k] as Vector3)) / _dt, MAX_VEL)
			_wv[k] = wv_old
			_pv[k] = pv_old
			# Where the old content would be this frame (last shown + one frame of its velocity):
			# holding the last pose for a frame would stop the motion for that frame.
			_r0[k] = _clampv(_rotvec(_quat(wv_old * _dt) * (_last_rot[k] as Quaternion) * cr.inverse()), MAX_OFFSET_RAD)
			_p0[k] = _clampv((_last_pos[k] as Vector3) + pv_old * _dt - cp, MAX_ROOT_OFFSET_M if b == root_bone else MAX_OFFSET_M)
			if mode == NO_ROOT_TRANSLATION and b == root_bone:
				_p0[k] = Vector3.ZERO
				_pv[k] = Vector3.ZERO
			if _zero_vel.has(b):
				_wv[k] = Vector3.ZERO
				_pv[k] = Vector3.ZERO
		_need_vel = true
	elif _need_vel and new_frame and _t >= 0.0:
		_need_vel = false
		for k in n:
			var b := _idx[k]
			var cr := sk.get_bone_pose_rotation(b)
			var cp := sk.get_bone_pose_position(b)
			if _zero_vel.has(b):
				continue
			_wv[k] = _clampv((_wv[k] as Vector3) - _rotvec(cr * (_cur0_rot[k] as Quaternion).inverse()) / _dt, MAX_VEL)
			_pv[k] = _clampv((_pv[k] as Vector3) - (cp - (_cur0_pos[k] as Vector3)) / _dt, MAX_VEL)
			if mode == NO_ROOT_TRANSLATION and b == root_bone:
				_pv[k] = Vector3.ZERO
		_t += _dt
	elif new_frame and _t >= 0.0:
		_t += _dt
	if _t >= 0.0:
		var kk := 1.0 - smoothstep(0.0, 1.0, _t / duration)
		var tt := minf(_t, duration)
		active_bones = 0
		for k in n:
			var r: Vector3 = ((_r0[k] as Vector3) + (_wv[k] as Vector3) * tt) * kk
			var pofs: Vector3 = ((_p0[k] as Vector3) + (_pv[k] as Vector3) * tt) * kk
			var b := _idx[k]
			if r.length_squared() > 1e-12:
				sk.set_bone_pose_rotation(b, (_quat(r) * sk.get_bone_pose_rotation(b)).normalized())
				active_bones += 1
			if pofs.length_squared() > 1e-12:
				sk.set_bone_pose_position(b, sk.get_bone_pose_position(b) + pofs)
		if _t >= duration:
			_t = -1.0
			active_bones = 0
	# This run's output (before the plants and the body modifier).
	if _shown_rot.size() != n:
		_shown_rot.resize(n)
		_shown_pos.resize(n)
	for k in n:
		var b := _idx[k]
		_shown_rot[k] = sk.get_bone_pose_rotation(b)
		_shown_pos[k] = sk.get_bone_pose_position(b)
	cost_usec = Time.get_ticks_usec() - t_us


# --------------------------------------------------------------------------------------------------
# Root (rig transform)
# --------------------------------------------------------------------------------------------------

## A switch of the root: from this frame on the rig is placed from `target` (moving at
## `target_vel`); the rendered root keeps where the old one would be this frame (last placed + one
## frame of its velocity), its velocity, yaw and yaw rate, and the offset decays over p_duration.
## Call it on the switch frame before root_place().
## carry: how much of the old root velocity continues (1; 0 for an impact such as a landing,
## whose momentum the landing clip absorbs: carried, a fast fall would overshoot the landing pose
## and come back).
func root_transition(target: Transform3D, target_vel: Vector3, p_duration: float, dt: float, carry := 1.0, carry_v := -1.0) -> void:
	if not _root_init:
		root_reset(target)
		return
	# carry_v: a separate share for the vertical velocity (-1 = carry).
	var c := Vector3(carry, carry if carry_v < 0.0 else carry_v, carry)
	_ro_p = _clampv(_root_shown.origin + _root_vel * c * dt - target.origin, MAX_OFFSET_M * 2.0)
	_ro_v = _clampv((_root_vel - target_vel) * c, MAX_VEL)
	_ro_yaw = wrapf(yaw_of(_root_shown.basis) + _root_yaw_vel * dt - yaw_of(target.basis), -PI, PI)
	_ro_yaw_v = clampf(_root_yaw_vel, -MAX_VEL, MAX_VEL)
	# The offset's clock starts at 0 on this frame (root_place advances it by dt first).
	_ro_t = -dt
	_ro_len = maxf(p_duration, 0.02)


func root_running() -> bool:
	return _ro_t < _ro_len


## The rendered root for this frame: `target` plus the decaying offset of the running transition.
func root_place(target: Transform3D, dt: float) -> Transform3D:
	if not _root_init:
		root_reset(target)
		return target
	_ro_t += dt
	var out := target
	if _ro_t < _ro_len:
		var k := 1.0 - smoothstep(0.0, 1.0, _ro_t / _ro_len)
		var tt := clampf(_ro_t, 0.0, _ro_len)
		var yaw := yaw_of(target.basis) + (_ro_yaw + _ro_yaw_v * tt) * k
		out = Transform3D(Basis(Vector3.UP, yaw), target.origin + (_ro_p + _ro_v * tt) * k)
	if dt > 0.0:
		_root_vel = (out.origin - _root_shown.origin) / dt
		_root_yaw_vel = wrapf(yaw_of(out.basis) - yaw_of(_root_shown.basis), -PI, PI) / dt
	_root_shown = out
	return out


## Places the root at `x` with no inertialization and zero velocity (a teleport), or moving at `vel`
## (a root that was moving with the body until now: the player's rig when a move takes over; with a
## zero velocity the next transition started the rendered root from rest, the model stopped for the
## first frames of every move, vault speed push 2026-09-26).
func root_reset(x: Transform3D, vel := Vector3.ZERO) -> void:
	_root_shown = x
	_root_vel = vel
	_root_yaw_vel = 0.0
	_ro_t = 1e9
	_root_init = true


func root_velocity() -> Vector3:
	return _root_vel


# --------------------------------------------------------------------------------------------------
# Helpers (also used by the controller's capsule and path offsets)
# --------------------------------------------------------------------------------------------------

## The extracted clips are key-reduced (about 10 keys a second on the root and limbs) and stored
## with LINEAR interpolation: every key is a velocity kink of every bone (1-2 cm per frame^2 of
## the pelvis at 120 fps, "micro-pops" at 10 Hz inside every move). Cubic interpolation in time
## through the same keys keeps every key and makes the motion between them continuous in velocity.
## Changes the loaded Animation resources (in memory, not saved): call once per library, for the
## clips the traversal plays (and the locomotion loops it blends with). Returns the tracks changed.
static func smooth_clip_tracks(ap: AnimationPlayer, clips: PackedStringArray) -> int:
	var changed := 0
	for c in clips:
		var a := ap.get_animation(c)
		if a == null:
			continue
		var quiet := _quiet_begin(a)
		var n := 0
		for t in a.get_track_count():
			var ty := a.track_get_type(t)
			if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
				continue
			if a.track_get_key_count(t) < 3 or a.track_get_interpolation_type(t) != Animation.INTERPOLATION_LINEAR:
				continue
			a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
			n += 1
		_quiet_end(a, quiet, n > 0)
		changed += n
	return changed


## smooth_clip_tracks() for the animations of a library by name (the runtime table's builder,
## which samples the clips on the rig through the same tracks). Returns the tracks changed.
static func smooth_library_clips(lib: AnimationLibrary, names: PackedStringArray) -> int:
	var changed := 0
	for c in names:
		if not lib.has_animation(c):
			continue
		var a := lib.get_animation(c)
		var quiet := _quiet_begin(a)
		var n := 0
		for t in a.get_track_count():
			var ty := a.track_get_type(t)
			if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
				continue
			if a.track_get_key_count(t) < 3 or a.track_get_interpolation_type(t) != Animation.INTERPOLATION_LINEAR:
				continue
			a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
			n += 1
		_quiet_end(a, quiet, n > 0)
		changed += n
	return changed


## Edits of an Animation in a library send `changed` once, when they are done (faster-loading push,
## 2026-09-26). Every key insert, key removal and interpolation change emits the animation's `changed`,
## and the AnimationPlayer / AnimationTree it is in answer each one with deferred work over the whole
## library: resample_player_hermite() at the player's spawn (about 7,000 key edits per clip, e.g.
## actor_b-p-land-med^idle 713 keys out, 6,201 in) cost 50-60 s of deferred calls before the first frame
## (tests/perf/test_startup.gd). The data is the same; only the signals wait.
## Returns whether the signals were already blocked (for _quiet_end()).
static func _quiet_begin(a: Animation) -> bool:
	var was := a.is_blocking_signals()
	a.set_block_signals(true)
	return was


static func _quiet_end(a: Animation, was_blocked: bool, edited: bool) -> void:
	a.set_block_signals(was_blocked)
	if edited and not was_blocked:
		a.emit_changed()


## A velocity-continuous resample of a key-reduced LINEAR clip (contact pass 2026-09-25; the moves
## that opt in with clip_interpolation "hermite", traversal_moves.json): every position and
## rotation track is replaced (in memory, nothing saved) by dense samples (`hz`) of a monotone cubic
## Hermite curve through the SAME keys. Unlike Godot's cubic interpolation (flat tangents at the
## first and last key, overshoot between sparse keys, see settings.clip_interpolation_note) the
## tangents are the keys' own slopes (one-sided at the ends, Fritsch-Butland in between, zero where
## the motion turns), so the clip keeps its start and end velocities, never passes a key's value,
## and loses the velocity kinks at its keys (the soft landing's heel went from 10.2 to 3.5 m/s at its
## 0.1 s key: a 5.8 cm one-frame jump). An Animation is resampled once (meta "trav_hermite").
## Returns the tracks changed.
static func resample_hermite(a: Animation, hz := 120.0) -> int:
	if a == null or a.has_meta("trav_hermite"):
		return 0
	a.set_meta("trav_hermite", true)
	var changed := 0
	var quiet := _quiet_begin(a)
	for t in a.get_track_count():
		var ty := a.track_get_type(t)
		if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
			continue
		var nk := a.track_get_key_count(t)
		if nk < 3 or a.track_get_interpolation_type(t) != Animation.INTERPOLATION_LINEAR:
			continue
		var rot := ty == Animation.TYPE_ROTATION_3D
		var nc := 4 if rot else 3
		var ts := PackedFloat64Array()
		var comp: Array[PackedFloat64Array] = []
		for c in nc:
			comp.append(PackedFloat64Array())
		var prev_q := Quaternion.IDENTITY
		for k in nk:
			ts.append(a.track_get_key_time(t, k))
			if rot:
				var q: Quaternion = (a.track_get_key_value(t, k) as Quaternion).normalized()
				if k > 0 and q.dot(prev_q) < 0.0:
					q = -q
				prev_q = q
				comp[0].append(q.x)
				comp[1].append(q.y)
				comp[2].append(q.z)
				comp[3].append(q.w)
			else:
				var v: Vector3 = a.track_get_key_value(t, k)
				for c in 3:
					comp[c].append(v[c])
		var tan: Array[PackedFloat64Array] = []
		for c in nc:
			tan.append(_monotone_tangents(ts, comp[c]))
		var samples := []
		var t0 := ts[0]
		var t1 := ts[nk - 1]
		var n := maxi(1, int(ceil((t1 - t0) * hz - 1e-6)))
		var seg := 0
		for i in n + 1:
			var x := minf(t0 + i / hz, t1)
			while seg < nk - 2 and x > ts[seg + 1]:
				seg += 1
			var h := ts[seg + 1] - ts[seg]
			var u := (x - ts[seg]) / h if h > 1e-9 else 0.0
			var u2 := u * u
			var u3 := u2 * u
			var h00 := 2.0 * u3 - 3.0 * u2 + 1.0
			var h10 := u3 - 2.0 * u2 + u
			var h01 := -2.0 * u3 + 3.0 * u2
			var h11 := u3 - u2
			var vals := []
			for c in nc:
				vals.append(h00 * comp[c][seg] + h10 * h * tan[c][seg] + h01 * comp[c][seg + 1] + h11 * h * tan[c][seg + 1])
			samples.append([x, Quaternion(vals[0], vals[1], vals[2], vals[3]).normalized() if rot else Vector3(vals[0], vals[1], vals[2])])
		for k in range(nk - 1, -1, -1):
			a.track_remove_key(t, k)
		for s: Array in samples:
			a.track_insert_key(t, float(s[0]), s[1])
		changed += 1
	_quiet_end(a, quiet, changed > 0)
	return changed


## resample_hermite() for the animations of a library / an AnimationPlayer by name.
static func resample_library_hermite(lib: AnimationLibrary, names: PackedStringArray, hz := 120.0) -> int:
	var changed := 0
	for c in names:
		if lib.has_animation(c):
			changed += resample_hermite(lib.get_animation(c), hz)
	return changed


static func resample_player_hermite(ap: AnimationPlayer, names: PackedStringArray, hz := 120.0) -> int:
	var changed := 0
	for c in names:
		if ap.has_animation(c):
			changed += resample_hermite(ap.get_animation(c), hz)
	return changed


## Tangents of a monotone piecewise cubic through (ts, ys): one-sided slopes at the ends, the
## Fritsch-Butland weighted harmonic mean of the neighbouring slopes inside, zero where they differ
## in sign (the curve never passes a key's value).
static func _monotone_tangents(ts: PackedFloat64Array, ys: PackedFloat64Array) -> PackedFloat64Array:
	var n := ts.size()
	var d := PackedFloat64Array()
	var hs := PackedFloat64Array()
	for k in n - 1:
		var h := maxf(ts[k + 1] - ts[k], 1e-9)
		hs.append(h)
		d.append((ys[k + 1] - ys[k]) / h)
	var m := PackedFloat64Array()
	m.resize(n)
	m[0] = d[0]
	m[n - 1] = d[n - 2]
	for k in range(1, n - 1):
		if d[k - 1] * d[k] <= 0.0:
			m[k] = 0.0
		else:
			var h0 := hs[k - 1]
			var h1 := hs[k]
			m[k] = 3.0 * (h0 + h1) / ((2.0 * h1 + h0) / d[k - 1] + (h1 + 2.0 * h0) / d[k])
	# The end tangents are kept within the monotone bound of their interval.
	for k in [0, n - 1]:
		var dk := d[0] if k == 0 else d[n - 2]
		if dk == 0.0 or m[k] * dk < 0.0:
			m[k] = 0.0
		elif absf(m[k]) > 3.0 * absf(dk):
			m[k] = 3.0 * dk
	return m


## The inertialization curve: the offset at time t of an offset x0 with velocity v0 that decays
## to zero with zero velocity at T: (x0 + v0 t) (1 - smoothstep(t / T)).
static func decay(x0: Vector3, v0: Vector3, t: float, T: float) -> Vector3:
	if t >= T or T <= 0.0:
		return Vector3.ZERO
	var tt := maxf(t, 0.0)
	return (x0 + v0 * tt) * (1.0 - smoothstep(0.0, 1.0, tt / T))


## The velocity of decay(): d/dt [(x0 + v0 t)(1 - smoothstep(t / T))].
static func decay_vel(x0: Vector3, v0: Vector3, t: float, T: float) -> Vector3:
	if t >= T or T <= 0.0:
		return Vector3.ZERO
	var tt := maxf(t, 0.0)
	var u := tt / T
	var s := u * u * (3.0 - 2.0 * u)
	var ds := 6.0 * u * (1.0 - u) / T
	return v0 * (1.0 - s) - (x0 + v0 * tt) * ds


## Heading of a (yaw-only) basis; Basis.get_euler() is unreliable at 180 deg.
static func yaw_of(b: Basis) -> float:
	var z := b.z
	return atan2(z.x, z.z)


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
