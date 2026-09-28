extends AnimTestSuite
## THROW2 (user playtest 2026-09-25), its review and fix 2: the spear's and the tomahawk's own carries, in the
## real level with the real input path (graph table carry_overrides / action_overrides; Throwable).
##
## Spear, the overhand javelin carry (the graph's throw raise, throw-object-aim, at its middle key on
## the arm; crouched its last key):
##   idle / walk / run: the hand above the shoulder (idle >= 0.08 m, walk / run >= 0 m), the elbow up
##   (no more than 0.08 m below the shoulder); crouched idle / walk: the hand at about shoulder height
##   (>= -0.12 m), the elbow up (>= -0.06 m); in every one the spear level (point within 10 deg of
##   horizontal) and pointing forward (the carry turns with 0.4 of the hips' yaw: Throwable.carry_follow_hips).
##   sprint: the sprint's moving roles keep the pick-up base's own sprint arm (graph layers), and the
##   spear is held across the body as the fist drops (Throwable.carry_low_rot_deg): the hand at least 0.12 m
##   below the shoulder, the point -5..20 deg from level, across to the left (<= -0.6) and forward (>= 0.3).
##   Raised again after the sprint: back above the shoulder within 1.2 s of letting go of sprint, the hand no
##   faster than HAND_SPEED_MAX.
## Tomahawk, carried like a hatchet (the machete carry arm and the knife ready arm, the knife grip;
## crouched the ready arm and the melee guard arm at 0.6, moving crouched the crouch-walk guard arm at
## 0.4 over them):
##   every mode: head up (the haft at least 20 deg above horizontal), blade forward (the edge's forward
##   component >= 0.3); standing, the arm relaxed at the side (the hand at least 0.15 m below the
##   shoulder); the head, edge and haft at least FACE_MIN from the face bones.
##   draw: the graph's thrown-object draw from the back of the belt (actions tomahawk/<stance>/equip =
##   actor_b-p-molotov-draw^idle--part, status frontier_substitute): with the tomahawk shown in it the
##   hand reaches behind the hips at belt height, then comes forward.
## Body clearance, every carry of both (THROW2 review; fix 2 adds the direction banks, sprint transitions,
## jumps and drops the review's probes found): the parts of the object outside the fist (the spear's shaft
## beyond GRIP_HALF either side of the grip; the tomahawk's haft above TOMA_EXPOSED_Y and its head) at
## least CLEAR from the femurs (thighs), the pelvis-spined segment (torso) and the head bones, and the
## spear's shaft at least SPEAR_FACE_MIN from the face bones (the whole object is reported as well).
##   BANKS: strafes, backpedals and diagonals, walking, running, crouched and sprinting.
##   SPRINTS: sprint starts, stops and changes into the diagonals, a strafe and a backpedal: also the
##   spear's turn rate (TURN_RATE_MAX) and the hand's speed.
##   JUMPS / DROPS: standing, running and sprinting jumps, drops from 1.5 m (idle, running, sprinting) and
##   3.5 m: also the spear's turn rate (the review build's port snapped 30 deg in one frame at a take-off)
##   and the tomahawk's turn beyond the fist's own (TOMA_EXCESS_RATE_MAX: it is held in the fist).
## Carry -> wind-up and the let-down (THROW2 review: the tomahawk snapped round in the first frames of a
## standing wind-up), for the spear and the tomahawk, standing and crouched, at the run's frame rate and
## at half of it (Engine.time_scale 2 in a fixed-step run: 60 fps under --fixed-fps 120): the hand no
## faster than HAND_SPEED_MAX, the held object no faster than a half turn over the weapon's
## aim_in_time, x 2 (a snap turns 150-180 deg in one frame), checked per rendered frame against the
## frame's own delta.
## Atlatl: unchanged (the pick-up base's 1h carry arm).

const MODES := [["idle", [], false], ["walk", ["move_forward", "walk"], false], ["run", ["move_forward"], false],
		["sprint", ["move_forward", "sprint"], false], ["crouch", [], true], ["crouch_walk", ["move_forward"], true]]
## Direction banks: name, keys, crouched.
const BANKS := [["run_lt", ["move_left"], false], ["run_rt", ["move_right"], false], ["run_bw", ["move_back"], false],
		["run_bw_lt", ["move_back", "move_left"], false], ["run_bw_rt", ["move_back", "move_right"], false],
		["run_fw_lt", ["move_forward", "move_left"], false], ["run_fw_rt", ["move_forward", "move_right"], false],
		["walk_lt", ["move_left", "walk"], false], ["walk_bw", ["move_back", "walk"], false],
		["crouch_lt", ["move_left"], true], ["crouch_rt", ["move_right"], true], ["crouch_bw", ["move_back"], true],
		["crouch_fw_lt", ["move_forward", "move_left"], true],
		["sprint_fw_lt", ["move_forward", "move_left", "sprint"], false], ["sprint_fw_rt", ["move_forward", "move_right", "sprint"], false]]
## Sprint starts, stops and changes: name, keys before, keys after.
const SPRINTS := [["from_idle", [], ["move_forward", "sprint"]], ["stop", ["move_forward", "sprint"], []],
		["to_diag_l", ["move_forward", "sprint"], ["move_forward", "move_left", "sprint"]],
		["to_diag_r", ["move_forward", "sprint"], ["move_forward", "move_right", "sprint"]],
		["diag_l_from_idle", [], ["move_forward", "move_left", "sprint"]],
		["diag_r_from_idle", [], ["move_forward", "move_right", "sprint"]],
		["diag_l_stop", ["move_forward", "move_left", "sprint"], []],
		["to_strafe_l", ["move_forward", "sprint"], ["move_left"]], ["to_back", ["move_forward", "sprint"], ["move_back"]]]
## Jumps (name, keys held) and drops (name, keys held, height m).
const JUMPS := [["idle", []], ["run", ["move_forward"]], ["sprint", ["move_forward", "sprint"]]]
const DROPS := [["idle_1.5", [], 1.5], ["run_1.5", ["move_forward"], 1.5], ["sprint_1.5", ["move_forward", "sprint"], 1.5],
		["idle_3.5", [], 3.5]]
## 0.08 m per frame at 120 fps (the first THROW2 limit), as a speed.
const HAND_SPEED_MAX := 9.6
## Largest turn rate (deg/s) of the spear's character-space carry (6 deg per frame at 120 fps).
const TURN_RATE_MAX := 720.0
## Largest turn rate (deg/s) of the tomahawk beyond the fist's own turn (it is held in the fist).
const TOMA_EXCESS_RATE_MAX := 600.0
## Clearance (m) of the held object from body axes: the THROW2 review's probe thresholds.
const CLEAR := {"r_thigh": 0.08, "l_thigh": 0.08, "torso": 0.12, "head": 0.10}
const PARTS := {"r_thigh": ["r_upper_leg", "r_knee"], "l_thigh": ["l_upper_leg", "l_knee"], "torso": ["pelvis", "spined"],
		"head": ["heada", "headb"]}
const FACE := ["nose_tip", "lip_upper_center", "lip_lower_center", "lower_mid_chin", "r_chin", "l_chin", "r_lip_corner",
		"r_cheek", "l_cheek", "brow_mid"]
const FACE_MIN := 0.15
## The spear's shaft from the face bones (m).
const SPEAR_FACE_MIN := 0.05
## The fist covers this much (m) of the spear's shaft either side of the grip, and the tomahawk's haft up to
## this height above the grip (the haft end below the fist is inside the hand's outline).
const GRIP_HALF := 0.06
const TOMA_EXPOSED_Y := 0.06

var _player: FrontierPlayer
var _bones := {}
var _final := {}
var _palm_q := Quaternion.IDENTITY
var _frames: Array = []
var _sampling := false
var _fast := false


class Sampler extends Node:
	var cb: Callable
	func _init() -> void:
		process_priority = 1 << 20
	func _process(_delta: float) -> void:
		cb.call_deferred()


func describe() -> String:
	return "THROW2: the spear's overhand javelin carry (above the shoulder, level; across the body while sprinting), the tomahawk's hatchet carry (head up, blade forward, arm at the side, clear of the face) and its draw from the back of the belt; body and face clearance of every carry, direction bank, sprint change, jump and drop; turn rates; wind-up and let-down continuity standing and crouched at two frame rates"


func timeout_s() -> float:
	return 1500.0


func run(ctx: AnimTestContext) -> void:
	ctx.allow_error("on a base object of type 'Nil'")    # environment_rig.gd (another workflow) in headless runs
	Engine.time_scale = 1.0
	_player = await ctx.level()
	if _player == null:
		return
	var sk := _player.skeleton
	var names: Array = ["r_hand_prop_attachment", "r_palm", "r_shoulder", "r_elbow"]
	for p in PARTS.values():
		names.append_array(p)
	names.append_array(FACE)
	for b in names:
		var i := sk.find_bone(b)
		if i >= 0:
			_bones[b] = i
	var palm := sk.find_bone("r_palm")
	sk.skeleton_updated.connect(func() -> void:
		for b in _bones:
			_final[b] = sk.global_transform * sk.get_bone_global_pose(_bones[b]).origin
		_palm_q = (sk.global_basis * sk.get_bone_global_pose(palm).basis).orthonormalized().get_rotation_quaternion())
	var sampler := Sampler.new()
	sampler.cb = _sample
	ctx.add_node(sampler)
	_fast = await AnimTestContext.faster_than_realtime(ctx.tree)
	_graph_rows(ctx)
	await _spear(ctx)
	await _tomahawk(ctx)
	await _tomahawk_draw(ctx)
	Engine.time_scale = 1.0


func _graph_rows(ctx: AnimTestContext) -> void:
	var d := _player.anim.data
	for st in ["stand", "crouch"]:
		var a := d.action("tomahawk", st, "equip")
		ctx.check(a.get("partial") == "actor_b-p-molotov-draw^idle--part" and a.get("status") == "frontier_substitute",
				"tomahawk/%s/equip: the thrown-object draw from the back of the belt (%s, %s)" % [st, a.get("partial"), a.get("status")])
		var h := d.action("tomahawk", st, "holster")
		ctx.check(h.get("partial") == "actor_b-p-molotov-draw^idle--part" and float(h.get("start_phase", 0.0)) >= 0.99,
				"tomahawk/%s/holster: the same draw played backwards (start phase %s)" % [st, h.get("start_phase")])
		ctx.check(d.action("tomahawk", st, "grab").get("partial") == "actor_b-p-molotov-idle^draw--part",
				"tomahawk/%s/grab: the reach to the back of the belt" % st)
	ctx.check(d.action("spear", "stand", "equip").get("partial") == "actor_b-lg-stealth-draw^idle--arm-r",
			"spear/stand/equip: the long-gun draw (unchanged)")
	ctx.check(d.action("atlatl", "stand", "equip").get("partial") == "actor_b-p-stealth-draw-p^idle--arm-r",
			"atlatl/stand/equip: unchanged")
	var atl := d.role("atlatl", "run", "fw").get("layers", []) as Array
	ctx.check(atl.any(func(l: Dictionary) -> bool: return l.get("clip") == "actor_b-p-1h-arm--part"),
			"atlatl/run/fw: keeps the pick-up base's 1h carry arm")
	var spr := d.role("spear", "sprint", "fw").get("layers", []) as Array
	ctx.check(spr.any(func(l: Dictionary) -> bool: return l.get("clip") == "actor_b-p-1h-arm--part" and l.get("status") == "resolved"),
			"spear/sprint/fw: the pick-up base's own sprint arm (graph layer)")


# --- sampling -----------------------------------------------------------------------------------

## Deferred after each rendered frame's skeleton update: the hand, shoulder, elbow in body space
## (right, up, forward), the held model's axes in body space, the clearance of its exposed parts (and of the
## whole object) from the body axes and the face, the fist's rotation and the frame's delta.
func _sample() -> void:
	if not _sampling or _final.is_empty():
		return
	var b := _player.global_basis.orthonormalized()
	var o: Vector3 = _final.r_shoulder
	var body := func(p: Vector3) -> Vector3:
		var v := p - o
		return Vector3(v.dot(b.x), v.dot(b.y), v.dot(-b.z))
	var rec := {"hand": body.call(_final.r_palm), "elbow": body.call(_final.r_elbow),
			"pelvis": body.call(_final.pelvis), "stage": _player.switch_stage(), "equipping": _player.weapon.is_equipping(),
			"dt": ctx_dt(), "aim": _player.weapon.aim, "palm_q": (b.inverse() * Basis(_palm_q)).get_rotation_quaternion()}
	var m: Node3D = _player.weapon.model
	if m and m.visible:
		var mb := m.global_basis.orthonormalized()
		var dirv := func(v: Vector3) -> Vector3:
			return Vector3(v.dot(b.x), v.dot(b.y), v.dot(-b.z))
		rec["y"] = dirv.call(mb.y)
		rec["fwd"] = dirv.call(-mb.z)
		rec["q"] = (b.inverse() * mb).get_rotation_quaternion()
		rec["shown"] = true
		var segs := _segments(m, true)
		var whole := _segments(m, false)
		if not segs.is_empty():
			rec["clear"] = _clear_of(segs)
			rec["clear_whole"] = _clear_of(whole)
			var face := INF
			for fb in FACE:
				if _final.has(fb):
					for s: Array in segs:
						face = minf(face, _seg_point(_final[fb], s[0], s[1]))
			rec["face"] = face
	_frames.append(rec)


func _clear_of(segs: Array) -> Dictionary:
	var clear := {}
	for part in PARTS:
		var ends: Array = PARTS[part]
		if not (_final.has(ends[0]) and _final.has(ends[1])):
			continue
		var d := INF
		for s: Array in segs:
			d = minf(d, _seg_seg(s[0], s[1], _final[ends[0]], _final[ends[1]]))
		clear[part] = d
	return clear


func ctx_dt() -> float:
	return _player.get_process_delta_time() if _player else 0.0


## The held object as world segments: the spear's shaft (Tip-Butt), the tomahawk's haft and head (Butt-Head,
## Head-Edge). exposed: only the parts outside the fist (the carry holds both at their model origin): the shaft
## beyond GRIP_HALF either side of it, the haft from TOMA_EXPOSED_Y above it.
static func _segments(m: Node3D, exposed: bool) -> Array:
	var n := func(name: String) -> Variant:
		var x := m.get_node_or_null(name) as Node3D
		return x.global_position if x else null
	var tip: Variant = n.call("Tip")
	var butt: Variant = n.call("Butt")
	var head: Variant = n.call("Head")
	var edge: Variant = n.call("Edge")
	var xf := m.global_transform
	if head != null and edge != null and butt != null:
		return [[xf * Vector3(0.0, TOMA_EXPOSED_Y, 0.0) if exposed else butt, head], [head, edge]]
	if tip != null and butt != null:
		if exposed:
			return [[tip, xf * Vector3(0.0, 0.0, -GRIP_HALF)], [xf * Vector3(0.0, 0.0, GRIP_HALF), butt]]
		return [[tip, butt]]
	return []


static func _seg_point(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Closest distance between segments p1-q1 and p2-q2.
static func _seg_seg(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-9 and e <= 1e-9:
		return p1.distance_to(p2)
	if a <= 1e-9:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 1e-9:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var bb := d1.dot(d2)
			var den := a * e - bb * bb
			s = clampf((bb * f - c * e) / den, 0.0, 1.0) if den != 0.0 else 0.0
			t = (bb * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((bb - c) / a, 0.0, 1.0)
	return (p1 + d1 * s).distance_to(p2 + d2 * t)


func _collect(ctx: AnimTestContext, n: int) -> Array:
	_frames.clear()
	_sampling = true
	await ctx.idle_frames(n)
	_sampling = false
	return _frames.duplicate()


static func _mean(frames: Array, key: String) -> Vector3:
	var s := Vector3.ZERO
	var k := 0
	for f: Dictionary in frames:
		if f.has(key):
			s += f[key]
			k += 1
	return s / maxf(k, 1)


## Largest speed (m/s) of `key` between consecutive frames (each over the later frame's delta).
static func _max_speed(frames: Array, key: String) -> float:
	var m := 0.0
	for i in range(1, frames.size()):
		if frames[i].has(key) and frames[i - 1].has(key) and float(frames[i].dt) > 0.0:
			m = maxf(m, (frames[i][key] - frames[i - 1][key]).length() / float(frames[i].dt))
	return m


## Largest turn rate (deg/s) of the held object between consecutive frames; excess: beyond the fist's own.
static func _max_turn_rate(frames: Array, excess := false) -> float:
	var m := 0.0
	for i in range(1, frames.size()):
		if frames[i].has("q") and frames[i - 1].has("q") and float(frames[i].dt) > 0.0:
			var d := rad_to_deg((frames[i].q as Quaternion).angle_to(frames[i - 1].q))
			if excess:
				d -= rad_to_deg((frames[i].palm_q as Quaternion).angle_to(frames[i - 1].palm_q))
			m = maxf(m, d / float(frames[i].dt))
	return m


## Smallest clearance per body part over the frames, and how many frames were inside CLEAR.
static func _clearance(frames: Array, key := "clear") -> Dictionary:
	var out := {}
	for f: Dictionary in frames:
		for part in f.get(key, {}):
			var d := float(f[key][part])
			var cur: Array = out.get(part, [INF, 0])
			cur[0] = minf(cur[0], d)
			if d < float(CLEAR[part]):
				cur[1] += 1
			out[part] = cur
	return out


static func _min_face(frames: Array) -> float:
	var face := INF
	for f: Dictionary in frames:
		face = minf(face, float(f.get("face", INF)))
	return face


func _check_clear(ctx: AnimTestContext, what: String, frames: Array, spear := false) -> void:
	var c := _clearance(frames)
	var w := _clearance(frames, "clear_whole")
	var parts := []
	var bad := []
	for part in PARTS:
		if not c.has(part):
			continue
		parts.append("%s %.3f (whole %.3f)" % [part, c[part][0], float(w.get(part, [INF])[0])])
		if int(c[part][1]) > 0:
			bad.append("%s %d frames" % [part, c[part][1]])
	var face := _min_face(frames)
	if spear and face < SPEAR_FACE_MIN:
		bad.append("face %.3f m" % face)
	ctx.check(not c.is_empty() and bad.is_empty(), "%s: clear of the body (closest: %s; face %.3f; limits thighs 0.08, torso 0.12, head 0.10%s m)%s" % [
			what, ", ".join(parts), face, ", face %.2f" % SPEAR_FACE_MIN if spear else "", (" INSIDE: " + ", ".join(bad)) if not bad.is_empty() else ""])


# --- helpers ------------------------------------------------------------------------------------

func _place(z := 30.0) -> void:
	_player.global_position = Vector3(0.0, 0.3, z)
	_player.velocity = Vector3.ZERO
	_player.yaw = 0.0
	_player.pitch = deg_to_rad(-4.0)


func _crouch(ctx: AnimTestContext, on: bool) -> void:
	if _player.is_crouching != on:
		Input.action_press("crouch")
		await ctx.frames(3)
		Input.action_release("crouch")
		await ctx.frames(3)


func _equip(ctx: AnimTestContext, key: String) -> void:
	ctx.release_inputs()
	_place()
	await _crouch(ctx, false)
	if _player.weapon_key != key:
		_player.switch_weapon(key)
	for i in 900:
		await ctx.frames(1)
		if _player.weapon_key == key and not _player.is_switching() and not _player.weapon.is_equipping():
			break
	await ctx.frames(60)


## Holds the mode's keys, waits for the gait to settle (and a landing after _place() to end), and
## returns `n` rendered frames.
func _mode(ctx: AnimTestContext, mode: Array, settle := 150, n := 90, z := 30.0) -> Array:
	ctx.release_inputs()
	_place(z)
	await _crouch(ctx, mode[2])
	await ctx.frames(settle)
	for k in mode[1]:
		Input.action_press(k)
	await ctx.frames(settle)
	var frames := await _collect(ctx, n)
	for k in mode[1]:
		Input.action_release(k)
	return frames


## Point direction of the held object (body space: right, up, forward), mean over the frames: pitch (deg, +
## up), yaw (deg, + left of the character's facing).
static func _point(frames: Array) -> Vector2:
	var pt := _mean(frames, "fwd").normalized()
	return Vector2(rad_to_deg(asin(clampf(pt.y, -1.0, 1.0))), rad_to_deg(atan2(-pt.x, pt.z)))


# --- spear --------------------------------------------------------------------------------------

func _spear(ctx: AnimTestContext) -> void:
	await _equip(ctx, "spear")
	for mode: Array in MODES:
		var f := await _mode(ctx, mode)
		var hand := _mean(f, "hand")
		var elbow := _mean(f, "elbow")
		var pt := _mean(f, "fwd").normalized()
		var pitch := rad_to_deg(asin(clampf(pt.y, -1.0, 1.0)))
		var name: String = mode[0]
		ctx.info("spear %s: hand %.3f m above the shoulder, %.3f m in front, %.3f m out; elbow %.3f m; point %.1f deg up, forward %.2f, across %.2f" % [
				name, hand.y, hand.z, hand.x, elbow.y, pitch, pt.z, pt.x])
		_check_clear(ctx, "spear %s" % name, f, true)
		match name:
			"idle":
				ctx.check(hand.y >= 0.08 and elbow.y >= -0.08, "spear idle: overhand, the hand %.3f m above the shoulder (>= 0.08), the elbow up (%.3f m, >= -0.08)" % [hand.y, elbow.y])
			"walk", "run":
				ctx.check(hand.y >= 0.0 and elbow.y >= -0.08, "spear %s: overhand, the hand %.3f m above the shoulder (>= 0), the elbow up (%.3f m, >= -0.08)" % [name, hand.y, elbow.y])
			"crouch", "crouch_walk":
				ctx.check(hand.y >= -0.12 and elbow.y >= -0.06, "spear %s: the hand at about shoulder height (%.3f m, >= -0.12), the elbow up (%.3f m, >= -0.06)" % [name, hand.y, elbow.y])
			"sprint":
				ctx.check(hand.y <= -0.12, "spear sprint: lowered (the pick-up base's sprint arm), the hand %.3f m below the shoulder (>= 0.12)" % -hand.y)
				ctx.check(pitch >= -5.0 and pitch <= 20.0 and pt.x <= -0.6 and pt.z >= 0.3,
						"spear sprint: across the body, the point %.1f deg from level (-5..20), across to the left (%.2f, <= -0.6), forward %.2f (>= 0.3)" % [pitch, pt.x, pt.z])
		if name != "sprint":
			ctx.check(absf(pitch) <= 10.0 and pt.z >= 0.95, "spear %s: level (%.1f deg), point forward (%.2f)" % [name, pitch, pt.z])
	await _banks(ctx, "spear")
	# Sprint -> run: raised again, smoothly.
	ctx.release_inputs()
	_place()
	await ctx.frames(150)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await ctx.frames(150)
	_frames.clear()
	_sampling = true
	Input.action_release("sprint")
	var t0 := Engine.get_physics_frames()
	var up_s := -1.0
	for i in 400:
		await ctx.idle_frames(1)
		if up_s < 0.0 and not _frames.is_empty() and float(_frames[_frames.size() - 1].hand.y) >= 0.0:
			up_s = float(Engine.get_physics_frames() - t0) / float(Engine.physics_ticks_per_second)
		if up_s >= 0.0 and i > 60:
			break
	_sampling = false
	Input.action_release("move_forward")
	var speed := _max_speed(_frames, "hand")
	var turn := _max_turn_rate(_frames)
	ctx.check(up_s >= 0.0 and up_s <= 1.2, "spear: back above the shoulder %.2f s after the sprint ends (<= 1.2 s)" % (up_s if up_s >= 0.0 else INF))
	ctx.check(speed <= HAND_SPEED_MAX, "spear: sprint -> run raise without a jump (the hand at most %.2f m/s, <= %.1f)" % [speed, HAND_SPEED_MAX])
	ctx.check(turn <= TURN_RATE_MAX, "spear: across -> level over the raise at most %.0f deg/s (<= %.0f: 6 deg per frame at 120 fps)" % [turn, TURN_RATE_MAX])
	_check_clear(ctx, "spear sprint -> run", _frames, true)
	await _sprints(ctx, "spear")
	await _jumps(ctx, "spear")
	# Carry -> wind-up and back, standing and crouched, at two frame rates.
	await ctx.frames(60)
	await _windups(ctx, "spear")


## Direction banks: clearance, and the spear's carry level (away from the sprint's across-the-body carry)
## within 45 deg of the facing (it turns with 0.4 of the hips' yaw).
func _banks(ctx: AnimTestContext, key: String) -> void:
	for bank: Array in BANKS:
		var f := await _mode(ctx, bank, 90, 90, 60.0)
		var name: String = bank[0]
		var p := _point(f)
		ctx.info("%s %s: point %.1f deg up, %.1f deg left of the facing; hand %s" % [key, name, p.x, p.y, str(_mean(f, "hand"))])
		_check_clear(ctx, "%s %s" % [key, name], f, key == "spear")
		if key == "spear" and not name.begins_with("sprint"):
			ctx.check(absf(p.x) <= 10.0 and absf(p.y) <= 45.0, "spear %s: level (%.1f deg) and within 45 deg of the facing (%.1f deg)" % [name, p.x, p.y])
	ctx.release_inputs()
	await _crouch(ctx, false)


## Sprint starts, stops and changes: clearance; the spear's turn rate and the hand's speed.
func _sprints(ctx: AnimTestContext, key: String) -> void:
	for c: Array in SPRINTS:
		ctx.release_inputs()
		_place(60.0)
		await ctx.frames(60)
		for k in c[1]:
			Input.action_press(k)
		await ctx.frames(150)
		_frames.clear()
		_sampling = true
		ctx.release_inputs()
		for k in c[2]:
			Input.action_press(k)
		await ctx.idle_frames(200)
		_sampling = false
		ctx.release_inputs()
		var what := "%s sprint %s" % [key, c[0]]
		_check_clear(ctx, what, _frames, key == "spear")
		if key == "spear":
			var turn := _max_turn_rate(_frames)
			ctx.check(turn <= TURN_RATE_MAX, "%s: the carry turns at most %.0f deg/s (<= %.0f)" % [what, turn, TURN_RATE_MAX])
		var speed := _max_speed(_frames, "hand")
		ctx.check(speed <= HAND_SPEED_MAX, "%s: the hand at most %.2f m/s (<= %.1f)" % [what, speed, HAND_SPEED_MAX])


## Jumps and drops: clearance; the spear's turn rate (a take-off's fast arm drop snapped the review build's port
## round in one frame), the tomahawk's turn beyond the fist's own.
func _jumps(ctx: AnimTestContext, key: String) -> void:
	var cases := []
	for j: Array in JUMPS:
		cases.append(["jump " + j[0], j[1], 0.0])
	for d: Array in DROPS:
		cases.append(["drop " + d[0], d[1], d[2]])
	for c: Array in cases:
		ctx.release_inputs()
		_place()
		await ctx.frames(60)
		for k in c[1]:
			Input.action_press(k)
		await ctx.frames(150)
		_frames.clear()
		_sampling = true
		if float(c[2]) > 0.0:
			_player.global_position += Vector3.UP * float(c[2])
		else:
			Input.action_press("jump")
			await ctx.frames(4)
			Input.action_release("jump")
		await ctx.idle_frames(220)
		_sampling = false
		ctx.release_inputs()
		var what := "%s %s" % [key, c[0]]
		_check_clear(ctx, what, _frames, key == "spear")
		if key == "spear":
			var turn := _max_turn_rate(_frames)
			ctx.check(turn <= TURN_RATE_MAX, "%s: the carry turns at most %.0f deg/s (<= %.0f)" % [what, turn, TURN_RATE_MAX])
		else:
			var ex := _max_turn_rate(_frames, true)
			ctx.check(ex <= TOMA_EXCESS_RATE_MAX, "%s: turns with the fist (at most %.0f deg/s beyond it, <= %.0f)" % [what, ex, TOMA_EXCESS_RATE_MAX])
	await ctx.frames(60)


## The wind-up and the let-down, standing and crouched, at the run's frame rate and (fixed-step runs) at
## half of it.
func _windups(ctx: AnimTestContext, key: String) -> void:
	var scales := [1.0, 2.0] if _fast else [1.0]
	for crouched in [false, true]:
		for ts in scales:
			Engine.time_scale = ts
			await _windup(ctx, key, crouched)
			Engine.time_scale = 1.0
	await _crouch(ctx, false)


func _windup(ctx: AnimTestContext, key: String, crouched: bool) -> void:
	ctx.release_inputs()
	_place()
	await _crouch(ctx, crouched)
	await ctx.frames(150)
	var w: Throwable = _player.weapon
	var up: Array = []
	var down: Array = []
	_frames.clear()
	_sampling = true
	Input.action_press("fire")
	for i in 240:
		await ctx.idle_frames(1)
		if w.state == Throwable.State.HOLDING:
			break
	await ctx.idle_frames(20)
	up = _frames.duplicate()
	_frames.clear()
	Input.action_press("aim")      # RMB lets it down without a throw
	await ctx.idle_frames(2)
	Input.action_release("aim")
	Input.action_release("fire")
	await ctx.idle_frames(90)
	_sampling = false
	down = _frames.duplicate()
	var fps := 1.0 / maxf(float(up[up.size() - 1].dt), 1e-4) if not up.is_empty() else 0.0
	var turn_max := 2.0 * 180.0 / maxf(w.aim_in_time, 0.05)
	var what := "%s %s wind-up at %.0f fps" % [key, "crouched" if crouched else "standing", fps]
	var hs := _max_speed(up, "hand")
	var tr := _max_turn_rate(up)
	var hd := _max_speed(down, "hand")
	var td := _max_turn_rate(down)
	var first: Dictionary = up[0] if not up.is_empty() else {}
	var last: Dictionary = up[up.size() - 1] if not up.is_empty() else {}
	ctx.info("%s: hand from (%.2f, %.2f, %.2f) to (%.2f, %.2f, %.2f) m (right, up, fwd of the shoulder); up: hand %.2f m/s, object %.0f deg/s; let-down: hand %.2f m/s, object %.0f deg/s (%.1f / %.1f deg per frame)" % [
			what, first.get("hand", Vector3.ZERO).x, first.get("hand", Vector3.ZERO).y, first.get("hand", Vector3.ZERO).z,
			last.get("hand", Vector3.ZERO).x, last.get("hand", Vector3.ZERO).y, last.get("hand", Vector3.ZERO).z, hs, tr, hd, td,
			tr / maxf(fps, 1.0), td / maxf(fps, 1.0)])
	ctx.check(not up.is_empty() and hs <= HAND_SPEED_MAX and tr <= turn_max,
			"%s: carry -> wind-up continuous (hand %.2f m/s <= %.1f; held object %.0f deg/s <= %.0f: a half turn over aim_in_time %.2f s x 2)" % [
			what, hs, HAND_SPEED_MAX, tr, turn_max, w.aim_in_time])
	ctx.check(not down.is_empty() and hd <= HAND_SPEED_MAX and td <= turn_max,
			"%s: let-down continuous (hand %.2f m/s <= %.1f; held object %.0f deg/s <= %.0f)" % [what, hd, HAND_SPEED_MAX, td, turn_max])
	await ctx.frames(30)


# --- tomahawk -----------------------------------------------------------------------------------

func _tomahawk(ctx: AnimTestContext) -> void:
	await _equip(ctx, "tomahawk")
	for mode: Array in MODES:
		var f := await _mode(ctx, mode)
		var hy := _mean(f, "y").normalized()
		var edge := _mean(f, "fwd").normalized()
		var hand := _mean(f, "hand")
		var name: String = mode[0]
		var face := _min_face(f)
		var up_deg := rad_to_deg(asin(clampf(hy.y, -1.0, 1.0)))
		ctx.info("tomahawk %s: haft %.1f deg above horizontal (up %.2f, fwd %.2f, out %.2f); edge forward %.2f; hand %.3f m below the shoulder; %.3f m from the face" % [
				name, up_deg, hy.y, hy.z, hy.x, edge.z, -hand.y, face])
		ctx.check(up_deg >= 20.0 and edge.z >= 0.3, "tomahawk %s: head up (the haft %.1f deg above horizontal, >= 20), blade forward (%.2f, >= 0.3)" % [name, up_deg, edge.z])
		ctx.check(face >= FACE_MIN, "tomahawk %s: the head, edge and haft %.3f m from the face (>= %.2f)" % [name, face, FACE_MIN])
		_check_clear(ctx, "tomahawk %s" % name, f)
		if not mode[2]:
			ctx.check(hand.y <= -0.15, "tomahawk %s: the arm relaxed at the side (the hand %.3f m below the shoulder, >= 0.15)" % [name, -hand.y])
	await _banks(ctx, "tomahawk")
	await _sprints(ctx, "tomahawk")
	await _jumps(ctx, "tomahawk")
	await _windups(ctx, "tomahawk")


## The tomahawk comes from the back of the belt: when it shows in the hand (the draw's first frames)
## the hand is behind the pelvis at belt height; by the draw's end it is in front.
func _tomahawk_draw(ctx: AnimTestContext) -> void:
	await _equip(ctx, "musket")
	_frames.clear()
	_sampling = true
	_player.switch_weapon("tomahawk")
	for i in 900:
		await ctx.idle_frames(1)
		if _player.weapon_key == "tomahawk" and not _player.is_switching() and not _player.weapon.is_equipping() and i > 20:
			break
	_sampling = false
	# The hand's point furthest behind the pelvis while the tomahawk is shown in it during the draw.
	var back := {}
	for f: Dictionary in _frames:
		if f.get("shown", false) and bool(f.equipping):
			var rel: Vector3 = f.hand - f.pelvis
			if back.is_empty() or rel.z < float(back.z):
				back = {"z": rel.z, "y": rel.y, "x": rel.x}
	var last: Dictionary = _frames[_frames.size() - 1] if not _frames.is_empty() else {}
	if back.is_empty():
		ctx.fail("tomahawk draw: the tomahawk never showed during the draw")
		return
	ctx.info("tomahawk draw: with the tomahawk in it the hand reaches %.3f m behind the pelvis, %.3f m above it, %.3f m to the right; at the end %.3f m in front of the shoulder" % [
			-float(back.z), float(back.y), float(back.x), last.hand.z])
	ctx.check(float(back.z) <= -0.05 and absf(float(back.y)) <= 0.25, "tomahawk draw: taken from the back of the belt (the hand %.3f m behind the pelvis, %.3f m above it)" % [-float(back.z), float(back.y)])
	ctx.check(float(last.hand.z) > 0.0, "tomahawk draw: ends in front (%.3f m in front of the shoulder)" % last.hand.z)
