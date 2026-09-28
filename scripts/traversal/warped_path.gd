class_name TravWarpedPath
extends RefCounted
## A move's warped root trajectory (design 8.1-8.5), produced by TravMotionWarper.solve().
##
## The move's reference track (data/traversal/traversal_runtime.json) gives, per sample at
## `hz`, the align (skeleton origin) and the contact points in the move frame (+Z fwd, +X left,
## +Y up at t = 0). The warp is a per-sample offset `delta` (move frame) that is held constant
## while a limb is planted and eases between contacts, so planted limbs stay planted and every
## surface contact lands on the detected obstacle. World pose of the Actor_B root at clip time t:
##
##   root(t) = origin + basis * (align(t) + delta(t)),   basis = Basis(UP, yaw)
##
## The clip plays unchanged in skeleton space on top of that root; `pins` are the IK targets
## (TraversalIK) for the contacts, in world space.

var move_id := ""
var move: Dictionary
var hz := 60.0
var n := 0
var duration := 0.0
var origin := Vector3.ZERO
var yaw := 0.0
var basis := Basis.IDENTITY
var align := PackedVector3Array()
var delta := PackedVector3Array()
var points := {}                  ## name -> PackedVector3Array (move frame, reference)
var pins: Array = []              ## [{limb, kind, surface, t_on, t_off}]: plant windows (TravMotionWarper._pins)
var surfaces := {}                ## surface name (support / top / landing / rung) -> TravSurfaces shape
var guard_shapes: Array = []      ## shapes no hand or foot may enter during the move
## Entry ease (seam continuity): the capsule starts where the body was, moving as it moved, and
## is inertialized onto the path over `ease_s`: offset (x0 + v0 t)(1 - smoothstep(t / ease_s))
## with x0 = capsule_offset0, v0 = capsule_vel0 (TravInertializer.decay; the capsule's velocity
## no longer jumps to the clip's at the entry, 1.9-3.5 m/s before, review 2026-09-24).
var capsule_offset0 := Vector3.ZERO
var capsule_vel0 := Vector3.ZERO
var ease_s := 0.3
## A chained segment (beam / crawl / shimmy loops) starts where the previous one's root ended:
## the difference to this path's own start eases out over root_ease_s (no root pop at the seam).
var root_offset0 := Vector3.ZERO
var root_ease_s := 0.4
## Height of the surface the move ends on (the capsule settles on it over the last EXIT_EASE_S,
## so the hand-back's floor snap moves nothing); null = the lower sole.
var exit_y: Variant = null
const EXIT_EASE_S := 0.3
var windows := {}
## The move's clock (TravMomentum): per sample, the rate at which the move's time runs against real
## time (empty: 1, the clip's own timing). A vault entered faster than its clip holds ONE rate at every
## sample (vault speed push 2, 2026-09-26: a rate per sample fast-forwarded parts of the move). Everything
## here is a function of the move's time; velocities of the path are per second of the move's time
## (x rate_at(t) for real time).
var rate := PackedFloat32Array()
## Move time of the hand-back when it comes before the end (TravMomentum: a vault at speed hands back
## when its landing foot runs out of reach, the locomotion takes the run-out over); -1: at the end.
var end_t := -1.0
## Move time from which the body stands on the top for the rest of an ONTO move (both feet on it, past its
## lip): the stick hands the body back from here on (TraversalController._input_exit); -1: never.
var up_t := -1.0
var metrics := {}                 ## dh_top, dh_land, sf_w0b, lateral, max_delta ...
var ok := true
var reason := ""
var exit_kind := ""               ## "run", "idle", "fall", "hang", "climb", ...
var traversed := {}               ## shape key {rid, shape} the move may overlap
var status := "graph"


func _sample_index(t: float) -> Array:
	var x := clampf(t, 0.0, duration) * hz
	var i := mini(int(floor(x)), n - 1)
	var u := x - i
	if i >= n - 1:
		return [n - 1, n - 1, 0.0]
	return [i, i + 1, u]


func _lerp_arr(arr: PackedVector3Array, t: float) -> Vector3:
	if arr.is_empty():
		return Vector3.ZERO
	var s := _sample_index(t)
	return arr[s[0]].lerp(arr[s[1]], s[2])


func delta_at(t: float) -> Vector3:
	return _lerp_arr(delta, t)


## Real seconds the move's clock takes from move time a to b (b - a without a rate curve).
func real_time(a: float, b: float) -> float:
	if rate.size() != n or n == 0 or b <= a:
		return maxf(b - a, 0.0)
	var steps := maxi(2, int(ceil((b - a) * hz * 2.0)))
	var h := (b - a) / steps
	var s := 0.0
	for k in steps:
		s += h / maxf(rate_at(a + (k + 0.5) * h), 1e-3)
	return s


## Move time of the hand-back (see end_t).
func end_time() -> float:
	return end_t if end_t > 0.0 and end_t < duration else duration


## The move clock's rate at move time t (1 without a rate curve).
func rate_at(t: float) -> float:
	if rate.size() != n or n == 0:
		return 1.0
	var s := _sample_index(t)
	return lerpf(rate[s[0]], rate[s[1]], s[2])


func align_at(t: float) -> Vector3:
	return _lerp_arr(align, t)


## Part joins of the move: [time, first sample] per part after the first. The root may step there
## (the table joins parts with world pelvis continuity, so the root takes the opposite of the
## clip's root-bone jump) and is not interpolated across the step (see root_at).
var _joins: Array = []
var _joins_ok := false
## A time this close to a part's start belongs to that part: the table's start times are rounded
## to 4 decimals and its samples switch parts with the same slack (build_runtime_table.gd
## PART_EPS), so the clip switches on the frame of the table's root step.
const PART_EPS := 1e-4


func joins() -> Array:
	if not _joins_ok:
		_joins_ok = true
		var parts: Array = move.get("parts", [])
		for k in range(1, parts.size()):
			var t0 := float(parts[k].get("t0", 0.0))
			var i := int(round(t0 * hz))
			if absf(t0 * hz - i) < 0.01 and i >= 2 and i < n:
				_joins.append([t0, i])
	return _joins


## World position of the Actor_B root (skeleton origin) at clip time t. Before a part join (from
## the old part's last sample up to the join time, where the clip switches) the root continues
## the old part's motion (linear extrapolation) and it steps exactly at the join: interpolated
## across the join, the root moved by the whole root-bone compensation (22 cm at the ladder top
## dismount's join) a frame before the clip switched, and the root inertialization carried that
## step as a 13 m/s velocity (a 40 cm bump).
func root_at(t: float) -> Vector3:
	var r := Vector3.INF
	for j: Array in joins():
		var tj := float(j[0])
		var ij := int(j[1])
		var tl := (ij - 1) / hz
		# (The same slack as part_at(), which switches the clip.)
		if t < tj - PART_EPS and t > tl:
			var a0 := align[ij - 1] + delta[ij - 1]
			var am := align[ij - 2] + delta[ij - 2]
			r = origin + basis * (a0 + (a0 - am) * ((t - tl) * hz))
			break
	if r == Vector3.INF:
		r = origin + basis * (align_at(t) + delta_at(t))
	if root_offset0 != Vector3.ZERO and t < root_ease_s:
		r += root_offset0 * (1.0 - smoothstep(0.0, root_ease_s, t))
	return r


func transform_at(t: float) -> Transform3D:
	return Transform3D(basis, root_at(t))


## World position of a reference point (contact point, pelvis, head_top) at clip time t.
func point_at(name: String, t: float) -> Vector3:
	if not points.has(name):
		return root_at(t)
	return origin + basis * (_lerp_arr(points[name], t) + delta_at(t))


func velocity_at(t: float, dt := 1.0 / 60.0) -> Vector3:
	var t0 := maxf(0.0, t - dt)
	var t1 := minf(duration, t + dt)
	if t1 - t0 < 1e-6:
		return Vector3.ZERO
	return (point_at("pelvis", t1) - point_at("pelvis", t0)) / (t1 - t0)


## The capsule path, precomputed per sample: horizontally the pelvis (design 8.1), vertically the
## lower of the two soles (so a move that ends on a top hands the capsule back on that
## top), low-passed like the root so the body never jerks; at the start eased from where the
## body was (capsule_offset0).
var _capsule := PackedVector3Array()


func build_capsule() -> void:
	_capsule.resize(n)
	var lf: PackedVector3Array = points.get("l_foot", PackedVector3Array())
	var rf: PackedVector3Array = points.get("r_foot", PackedVector3Array())
	var pl: PackedVector3Array = points.get("pelvis", PackedVector3Array())
	for i in n:
		var w := origin + basis * ((pl[i] if not pl.is_empty() else align[i]) + delta[i])
		var y := w.y
		if not lf.is_empty() and not rf.is_empty():
			var a := (origin + basis * (lf[i] + delta[i])).y
			var b := (origin + basis * (rf[i] + delta[i])).y
			y = minf(a, b)
		_capsule[i] = Vector3(w.x, y, w.z)
	for pass_i in 3:
		var S := _capsule.duplicate()
		for i in range(1, n - 1):
			S[i] = (_capsule[i - 1] + _capsule[i] * 2.0 + _capsule[i + 1]) * 0.25
		_capsule = S
	# (The settle ends at the hand-back: a move handed back before its end, TravMomentum, settles by then;
	# settled at its end, the body was dropped 13 cm onto the ground at an early hand-back.)
	var te := end_time()
	if exit_y != null:
		for i in n:
			var t := i / hz
			var w := smoothstep(te - EXIT_EASE_S, te, t)
			if w > 0.0:
				_capsule[i].y = lerpf(_capsule[i].y, float(exit_y), w)
	# A standing exit: the capsule (the idle loop's root after the hand-back) ends where the idle
	# pose's feet land on the move's last feet (move exit_idle_shift, the table), eased in over the
	# last EXIT_EASE_S (fix round 3, 2026-09-25: the hand-back slid the standing feet 4.5-5.7 cm).
	var sh: Array = move.get("exit_idle_shift", [])
	if exit_kind == "idle" and sh.size() == 2 and n > 1:
		var ra := origin + basis * (align[n - 1] + delta[n - 1])
		var tgt := ra + basis * Vector3(float(sh[0]), 0.0, float(sh[1]))
		for i in n:
			var t2 := i / hz
			var w2 := smoothstep(te - EXIT_EASE_S, te, t2)
			if w2 > 0.0:
				_capsule[i].x = lerpf(_capsule[i].x, tgt.x, w2)
				_capsule[i].z = lerpf(_capsule[i].z, tgt.z, w2)


func capsule_at(t: float) -> Vector3:
	if _capsule.size() != n:
		build_capsule()
	var c := _lerp_arr(_capsule, t)
	if t < ease_s and (capsule_offset0 != Vector3.ZERO or capsule_vel0 != Vector3.ZERO):
		c += TravInertializer.decay(capsule_offset0, capsule_vel0, t, ease_s)
	return c


## The capsule path's own velocity at t (one-sided at the ends; without the entry offset).
func capsule_velocity_at(t: float, dt := 1.0 / 60.0) -> Vector3:
	if _capsule.size() != n:
		build_capsule()
	var t0 := clampf(t - dt * 0.5, 0.0, maxf(duration - dt, 0.0))
	return (_lerp_arr(_capsule, t0 + dt) - _lerp_arr(_capsule, t0)) / dt


## IK constraints active at time t (TraversalIK.pins): [{limb, weight, mode, surface, shape}],
## blended in over `blend_in` before t_on and out over `blend_out` after t_off (design 8.4).
## Two windows of the same limb that overlap in their blends (a re-grip: one plant fading out while
## the next fades in) are both returned, so the IK crossfades their corrections (fix round 3,
## 2026-09-25: switched to the stronger one at the crossover, the standing 1.5 m mantle's palm
## correction dropped from 3.0 to 0.7 cm in one frame).
func pins_at(t: float, blend_in := 0.08, blend_out := 0.1) -> Array:
	var best := {}
	var extra := []
	var lifts := []
	for p: Dictionary in pins:
		var w := 0.0
		if t >= float(p.t_on) and t <= float(p.t_off):
			w = 1.0
		elif t < float(p.t_on) and t > float(p.t_on) - blend_in:
			w = 1.0 - (float(p.t_on) - t) / blend_in
		elif t > float(p.t_off) and t < float(p.t_off) + blend_out:
			w = 1.0 - (t - float(p.t_off)) / blend_out
		if w <= 0.0:
			continue
		var shape: Variant = p.get("shape", surfaces.get(str(p.surface)))
		if shape == null:
			continue
		w = smoothstep(0.0, 1.0, w)
		var limb := str(p.limb)
		var q := {"limb": limb, "weight": w, "mode": str(p.get("mode", "plant")), "surface": str(p.surface), "shape": shape,
				"into": p.get("into", Vector3.ZERO), "id": "%s:%s@%.3f" % [move_id, limb, float(p.t_on)]}
		if p.has("footprint"):
			q["footprint"] = p.footprint
		if p.has("hold_max"):
			q["hold_max"] = p.hold_max
		if str(q.mode) == "lift":
			# (A lift, TravMomentum: an offset on top of the limb's plant as it fades, not a plant that covers it.)
			q["lift"] = float(p.get("lift", 0.0))
			lifts.append(q)
			continue
		if best.has(limb):
			var b: Dictionary = best[limb]
			# (Both blending: the weaker one is kept as a second pin of the limb when the two are
			# partial; a full-weight pin covers the other.)
			var lo: Dictionary = b if float(b.weight) < w else q
			var hi: Dictionary = q if float(b.weight) < w else b
			best[limb] = hi
			if float(hi.weight) < 0.999 and float(lo.weight) > 0.0:
				extra.append(lo)
			continue
		best[limb] = q
	var out: Array = best.values()
	for e: Dictionary in extra:
		var hi2: Dictionary = best.get(str(e.limb), {})
		if not hi2.is_empty() and float(hi2.weight) < 0.999 and str(hi2.id) != str(e.id):
			out.append(e)
	out.append_array(lifts)
	return out


## Planted windows (full weight) at time t: {limb: surface}.
func planted_at(t: float) -> Dictionary:
	var out := {}
	for p: Dictionary in pins:
		if str(p.get("mode", "plant")) == "lift":
			continue
		if t >= float(p.t_on) and t <= float(p.t_off):
			out[str(p.limb)] = str(p.surface)
	return out


## Graph state and clip at clip time t: {part, state, clip, local_t, clip_t, reverse}.
func part_at(t: float) -> Dictionary:
	var parts: Array = move.get("parts", [])
	var k := 0
	while k < parts.size() - 1 and t >= float(parts[k + 1].t0) - PART_EPS:
		k += 1
	var p: Dictionary = parts[k]
	# (clip_t0: a part the move starts into, TravMomentum's trimmed start, plays from that far into its clip)
	var lt := t - float(p.t0) + float(p.get("clip_t0", 0.0))
	var clen := float(p.get("clip_length", p.length))
	if bool(p.get("hold", false)):
		lt = clen
	var ct := clampf(clen - lt if bool(p.get("reverse", false)) else lt, 0.0, clen)
	return {"part": k, "state": p.get("state", ""), "clip": p.clip, "local_t": lt, "clip_t": ct,
			"reverse": bool(p.get("reverse", false)), "fade_s": float(p.get("fade_s", 0.0))}


func to_dict() -> Dictionary:
	return {"move": move_id, "origin": [origin.x, origin.y, origin.z], "yaw": yaw, "ok": ok, "reason": reason,
			"metrics": metrics, "exit": exit_kind, "status": status, "duration": duration}
