extends AnimTestSuite
## WP4 (plan sections 6.6 and 10): move-bank playback rates.
##   - ratio = speed / sum(w_i v_i) (w = the graph direction weights at the blend angle, v = the
##     metrics clip speeds) within 2 %, for every move mode, fw and bw hemispheres at 6 angles and
##     5 speeds; the ratio stays inside tuning.rate_clamp [0.55, 1.75] (clamped outside);
##   - the timeline scale written is ratio * sum(w v) / sum(w v T) cycles per second, and the
##     bank's normalized phase really advances at that rate;
##   - decel floor: fading out of MOVE (not moving) at low speed the ratio is rate_floor_decel 0.6;
##   - start / reversal banks follow the graph phase callback 0x0001466c (speed / final body speed,
##     at least 0.5; WP7: the start's desired speed, raised by start_rate_boost where the clip's
##     own speed at its phase is below it, up to rate_clamp[1]) and stop banks 0x00013a6c (entry
##     speed / initial body speed ramping to real
##     time by phase 0.2, never faster), body speeds from metrics body_profile;
##   - releasing the stick at walk / run / sprint enters STOP on the release frame with the
##     release speed, and the stop clip plays phase 0 -> 0.2 in real time (+-2 frames); a second
##     stop takes the other instance slot with its own entry speed;
##   - the plan 6.6 ratio column (walk 1.27, run 1.08 / 0.99, run bw 1.34, sprint 1.32, crouch 0.86
##     / 0.79) within 0.01.

const LocoRig := preload("res://tests/anim/loco_rig.gd")
const DT := 1.0 / 60.0
const FW := Vector2(0.0, 1.0)
const MODES := ["walk", "run", "sprint", "crouch"]
const ANGLES := {"fw": [0.0, 45.0, -80.0], "bw": [180.0, 135.0, -120.0]}
const SPEED_K := [0.3, 0.8, 1.0, 1.3, 2.5]
## Plan 6.6 ratio column: [label, mode, angle, speed, ratio].
const TABLE := [["walk key bow / pistol", "walk", 0.0, 1.6, 1.27], ["walk key musket", "walk", 0.0, 1.47, 1.17],
		["run bow / pistol", "run", 0.0, 3.6, 1.08], ["run musket", "run", 0.0, 3.31, 0.99],
		["run backward musket", "run", 180.0, 3.31, 1.34], ["sprint", "sprint", 0.0, 5.6, 1.32],
		["crouch bow / pistol", "crouch", 0.0, 1.4, 0.86], ["crouch musket", "crouch", 0.0, 1.29, 0.79]]


func describe() -> String:
	return "LocoBrain rates: ratio = speed / sum(w v) +- 2 %, clamp [0.55, 1.75], timeline scale, decel floor 0.6, plan 6.6 table"


func timeout_s() -> float:
	return 240.0


func run(ctx: AnimTestContext) -> void:
	var h = LocoRig.new()
	if not h.setup(ctx):
		return
	var brain: LocoBrain = h.brain
	brain.frozen = true
	var cl: Array = h.data.tuning("rate_clamp", [0.55, 1.75])
	var lo := float(cl[0])
	var hi := float(cl[1])
	ctx.check(is_equal_approx(lo, 0.55) and is_equal_approx(hi, 1.75), "tuning.rate_clamp = [0.55, 1.75] (%s)" % [cl])
	var worst_rel := 0.0
	var worst_ts := 0.0
	var clamp_bad := []
	var n := 0
	for m in MODES:
		var id: StringName = h.idx.input_for("musket/%s/move" % m)
		var rec: Dictionary = h.idx.lower_record(id)
		for hem in ["fw", "bw"]:
			var hr: Dictionary = rec.hemis[hem]
			var v0: float = h.data.clip_speed(String(hr.clips[0]))
			brain.debug_enter("run-fw" if hem == "fw" else "run-bkwd", StringName(m))
			for a: float in ANGLES[hem]:
				for k: float in SPEED_K:
					var spd := v0 * k
					_tick(h, a, spd, true)
					# The graph truncates the backward angle to int: compare at the brain's own
					# chain position of that hemisphere (a float hair below an integer truncates one
					# degree down), i.e. the direction weights it wrote.
					var exp := _expected_w(h, hr, LocoBrain.position_weights(float(brain.blend_pos[hem])), spd)
					var r: float = brain.ratio
					var want := clampf(exp.raw, lo, hi)
					n += 1
					worst_rel = maxf(worst_rel, absf(r - want) / want)
					if r < lo - 1e-9 or r > hi + 1e-9 or (exp.raw < lo and not is_equal_approx(r, lo)) or (exp.raw > hi and not is_equal_approx(r, hi)):
						clamp_bad.append("%s %s a %.0f v %.2f: raw %.3f ratio %.3f" % [m, hem, a, spd, exp.raw, r])
					var ts := float(h.tree.get(hr.ts))
					worst_ts = maxf(worst_ts, absf(ts - want * exp.sv / exp.st))
	ctx.at_most(worst_rel, 0.02, "ratio = clamp(speed / sum(w v)) over %d cases (4 modes x fw/bw x 3 angles x 5 speeds): worst relative error" % n)
	ctx.check(clamp_bad.is_empty(), "ratio inside [0.55, 1.75] and clamped exactly outside it: %s" % [clamp_bad.slice(0, 4)])
	ctx.at_most(worst_ts, 1e-6, "timeline scale written = ratio * sum(w v) / sum(w v T) cycles per second: worst abs error")

	# The normalized phase advances at the written scale.
	var id_r: StringName = h.idx.input_for("musket/run/move")
	var hr_r: Dictionary = h.idx.lower_record(id_r).hemis["fw"]
	brain.debug_enter("run-fw", &"run", 0.1)
	h.L.write()
	_tick(h, 30.0, 4.0, true)
	h.tree.advance(0.0)
	var p0 := float(h.tree.get(hr_r.position_node))
	var ts0 := float(h.tree.get(hr_r.ts))
	for i in 20:
		_tick(h, 30.0, 4.0, true)
		h.tree.advance(DT)
	var p1 := float(h.tree.get(hr_r.position_node))
	var adv := fposmod(p1 - p0, 1.0)
	ctx.near(adv, fposmod(ts0 * 20.0 * DT, 1.0), 1e-3, "run fw bank at 4.0 m/s, 30 deg: phase advances ts x t (ts %.4f cycles/s)" % ts0)

	# Decel floor: not moving (fading out of MOVE) at low speed.
	for m in MODES:
		brain.debug_enter("run-fw", StringName(m))
		brain.moving = false
		_tick(h, 0.0, 0.2, false)
		ctx.near(brain.ratio, float(h.data.tuning("rate_floor_decel", 0.6)), 1e-9, "%s: not moving at 0.2 m/s -> ratio = decel floor 0.6" % m)
		_tick(h, 0.0, 0.0, false)
		ctx.near(brain.ratio, 0.6, 1e-9, "%s: not moving at 0 m/s -> ratio 0.6 (legs never freeze)" % m)

	# Start / reversal / stop banks: the graph's speed-synced phase callbacks.
	_start_stop(ctx, h)
	_release_stop(ctx)

	# Plan 6.6 ratio column.
	for c in TABLE:
		var hem := "fw" if absf(float(c[2])) <= 90.0 else "bw"
		brain.debug_enter("run-fw" if hem == "fw" else "run-bkwd", StringName(c[1]))
		_tick(h, float(c[2]), float(c[3]), true)
		ctx.near(brain.ratio, float(c[4]), 0.01, "plan 6.6 %s: %.2f m/s in %s -> ratio %.2f" % [c[0], c[3], c[1], c[4]])


## Start (0x0001466c): scale = max(speed / final body speed, 0.5) / T; stop (0x00013a6c): scale =
## min(1, lerp-scale(0, 0.2, max(entry speed / initial body speed, 0.01), 1, phase)) / T.
func _start_stop(ctx: AnimTestContext, h) -> void:
	var brain: LocoBrain = h.brain
	for g in [["start", "idle^run-fwd"], ["rev", "run-bw^run-fwd"]]:
		var id: StringName = h.idx.input_for("musket/run/%s" % g[0])
		var hr: Dictionary = h.idx.lower_record(id).hemis["fw"]
		var bp: Dictionary = h.data.clip_metrics(String(hr.clips[0])).get("body_profile", {})
		var v_end := float(bp.speed[bp.speed.size() - 1])
		# WP7: the start's speed is the desired one (the wish; equal to the body speed here), and by
		# default (start_rate_boost) the start plays faster where its clip's own speed at the
		# phase (v1, metrics body_profile displacement) is below it, up to rate_clamp[1].
		var v1 := brain._profile_velocity(String(hr.clips[0]), 0.0).length()
		var rmax := float(h.data.tuning("rate_clamp", [0.55, 1.75])[1])
		for boost in ([true, false] if g[0] == "start" else [true]):
			brain.start_rate_boost = boost
			var bad := []
			for spd in [0.0, 0.5, 1.2, v_end, 3.6, 5.0]:
				brain.debug_enter(g[1], &"run")
				_tick(h, 0.0, spd, true)
				var q := maxf(spd / v_end, 0.5)
				if boost and g[0] == "start" and v1 > 1e-3:
					q = maxf(q, minf(spd / v1, rmax))
				var want := q / float(hr.lengths[0])
				var got := float(h.tree.get(hr.ts))
				if absf(got - want) > 1e-6:
					bad.append("%.2f m/s: %.4f (want %.4f)" % [spd, got, want])
			ctx.check(bad.is_empty(), "%s bank %s: scale = max(speed / final body speed %.3f, 0.5%s) / %.2f s (graph 0x0001466c%s): %s" % [
					g[0], hr.clips[0], v_end, (", min(speed / its speed at the phase %.3f, %.2f)" % [v1, rmax]) if boost and g[0] == "start" else "",
					float(hr.lengths[0]), "; start_rate_boost" if boost and g[0] == "start" else "", bad])
		brain.start_rate_boost = true
	var sid: StringName = h.idx.input_for("musket/run/stop")
	var shr: Dictionary = h.idx.lower_record(sid).hemis["fw"]
	var sbp: Dictionary = h.data.clip_metrics(String(shr.clips[0])).get("body_profile", {})
	var v0 := float(sbp.speed[0])
	var bad := []
	for e in [0.3, 0.6, 1.5, v0 * 1.5]:
		for ph in [0.0, 0.1, 0.3]:
			_tick(h, 0.0, e, false)
			brain.debug_enter("run-fw^idle", &"run", ph)
			h.L.write()
			h.tree.advance(0.0)
			_tick(h, 0.0, 0.0, false)
			var k := maxf(e / v0, 0.01)
			var m := k + (1.0 - k) * clampf(ph / 0.2, 0.0, 1.0)
			var want := minf(m, 1.0) / float(shr.lengths[0])
			var got := float(h.tree.get(shr.ts))
			if absf(got - want) > 1e-4:
				bad.append("entry %.2f phase %.1f: %.4f (want %.4f)" % [e, ph, got, want])
	ctx.check(bad.is_empty(), "stop bank %s: scale = min(1, lerp(entry / initial body speed %.3f, 1, phase / 0.2)) / %.2f s (graph 0x00013a6c): %s" % [
			shr.clips[0], v0, float(shr.lengths[0]), bad])


## Releasing the stick (not frozen; the kinematic player decelerates at 18 m/s^2): STOP starts on
## the release frame (move_speed follows the stick) with the speed at the release as its entry
## speed, so the stop clip plays phase 0 -> 0.2 in real time (0.2 x its length, +-2 frames) at
## walk, run and sprint; a second stop takes the other instance slot with its own entry speed.
func _release_stop(ctx: AnimTestContext) -> void:
	var h = LocoRig.new()
	if not h.setup(ctx):
		return
	var brain: LocoBrain = h.brain
	for c in [["walk", 1.6, false], ["run", 3.6, false], ["sprint", 5.6, true]]:
		h.reset()
		h.sprinting = c[2]
		h.run(150, FW, c[1])
		h.sprinting = false
		var v_rel: float = h.vel.length()
		var n: int = h.until(func() -> bool: return brain.state == LocoBrain.STOP, 60)
		var v_entry: float = h.vel.length()
		var stop_id: StringName = brain.input_id
		var hr: Dictionary = h.idx.lower_record(stop_id).hemis[String(brain.hemi)]
		var T := float(hr.lengths[0])
		var bp: Dictionary = h.data.clip_metrics(String(hr.clips[0])).get("body_profile", {})
		var v0 := float(bp.speed[0]) if not bp.is_empty() else 0.0
		var entry: float = float(brain._stop_entry.get(String(stop_id), -1.0))
		var f := 0
		while brain.phase() < 0.2 - 1e-6 and f < 600:
			h.step()
			f += 1
		var want: float = 0.2 * T / float(h.dt)
		ctx.check(n == 1 and absf(entry - v_rel) < 1e-6 and absf(float(f) - want) <= 2.0,
				"%s: release at %.2f m/s -> %s after %d frame(s) (<= 1), entry speed %.2f (initial body speed %.2f), phase 0 -> 0.2 in %d frames (real time %.1f +- 2; body %.2f m/s at entry)" % [
				c[0], v_rel, brain.graph_state, n, entry, v0, f, want, v_entry])
	# Per instance slot: stop (3.6 m/s), start again at 2.5 m/s and release as soon as the start
	# state's stop record (gated at its phase 0.2) can fire, while the first stop still fades out:
	# the second stop takes the other slot with its own entry speed, the first keeps its own.
	h.reset()
	h.run(150, FW, 3.6)
	h.until(func() -> bool: return brain.state == LocoBrain.STOP, 60)
	var a: StringName = brain.input_id
	var ea: float = float(brain._stop_entry.get(String(a), -1.0))
	h.run(40)
	h.until(func() -> bool: return brain.state == LocoBrain.START, 30, FW, 2.5)
	h.until(func() -> bool: return brain.phase() >= 0.2, 90, FW, 2.5)
	var v_rel2: float = h.vel.length()
	var nb: int = h.until(func() -> bool: return brain.state == LocoBrain.STOP, 60)
	var b: StringName = brain.input_id
	var eb: float = float(brain._stop_entry.get(String(b), -1.0))
	var wa: float = h.L.weight(a)
	ctx.check(nb == 1 and wa > 0.0 and a != b and _primary_of(h, a) == _primary_of(h, b)
			and absf(float(brain._stop_entry.get(String(a), -1.0)) - ea) < 1e-9 and absf(eb - v_rel2) < 1e-6 and absf(eb - ea) > 0.5,
			"stop -> start -> stop: the second stop (%s, entry %.2f m/s = its release speed %.2f) takes the other slot while the first (%s, L weight %.2f) keeps its entry %.2f" % [
			b, eb, v_rel2, a, wa, ea])


func _primary_of(h, id: StringName) -> String:
	var r: Dictionary = h.idx.lower_record(id)
	return String(r.get("instance_of", id))


## One frozen tick with velocity = wish = the direction at `spd`, blend angle snapped to a.
func _tick(h, a: float, spd: float, moving: bool) -> void:
	h.brain.set_blend_deg(a)
	var inp := AnimInputs.new()
	var d := LocoRig.dir(a)
	inp.velocity_local = d * spd
	inp.wish_local = d * spd if moving else Vector2.ZERO
	inp.speed = spd
	inp.target_speed = spd if moving else 0.0
	if moving:
		h.brain.moving = true
	h.brain.tick(inp, [], DT, &"musket", false)


## Expected raw ratio and sums for a bank hemisphere at angle a and speed spd.
func _expected(h, hr: Dictionary, hem: String, a: float, spd: float) -> Dictionary:
	return _expected_w(h, hr, LocoBrain.dir_weights(hem, a), spd)


## The same for direction weights w2 = (w_neg, w_pos).
func _expected_w(h, hr: Dictionary, w2: Vector2, spd: float) -> Dictionary:
	var w := [1.0 - w2.x - w2.y, w2.x, w2.y]
	var sv := 0.0
	var st := 0.0
	for i in 3:
		var c := String(hr.clips[i]) if String(hr.clips[i]) != "" else String(hr.clips[0])
		var v: float = h.data.clip_speed(c)
		sv += w[i] * v
		st += w[i] * v * float(hr.lengths[i])
	return {"raw": spd / sv, "sv": sv, "st": st}
