extends AnimTestSuite
## WP4 (plan sections 6.7 and 10): phase matching on mode and hemisphere switches (graph
## calc-ankle-match-phase; LocoBrain matches the gait phase from the metrics plant onsets).
##   - 50 random switches while running in MOVE (walk / run / sprint mode changes through the
##     graph's change-move-mode self re-entry, and fw <-> bw hemisphere switches through the
##     graph's hemisphere records), each made while a foot is planted with >= 0.1 s of its stance
##     left in the outgoing clip: that foot stays the lowest (within 1 cm) for the next 0.1 s in
##     the blended pose; at most 1 violation per 50 switches as a rate over 6 seeds (300
##     switches; the walk -> run / sprint switches from late in walk's long stance are the
##     marginal ones: run's stance is 25 % of its cycle against walk's 56 %);
##   - the incoming bank starts at the outgoing gait phase (left plant = 0, right plant = 0.5):
##     |gait(in) - gait(out)| <= 0.05 right after the switch, every switch.

const LocoRig := preload("res://tests/anim/loco_rig.gd")
const SWITCHES := 50
const HOLD_S := 0.1
const TOL_M := 0.01
const SPEEDS := {"walk": 1.6, "run": 3.6, "sprint": 5.6}
## The original seed plus the review's five (the rate over all of them is what is checked).
const SEEDS := [20260924, 7932, 15851, 31689, 39608, 23770]


func describe() -> String:
	return "LocoBrain phase matching: 6 seeds x 50 random mode / hemisphere switches, planted foot stays lowest 0.1 s (<= 1 per 50), gait phase kept"


func timeout_s() -> float:
	return 600.0


func run(ctx: AnimTestContext) -> void:
	var h = LocoRig.new()
	if not h.setup(ctx):
		return
	var total_v := 0
	var total_n := 0
	var per_seed := []
	var all_v := []
	for sd in SEEDS:
		var r := _run_seed(ctx, h, sd)
		if r.is_empty():
			return
		ctx.check(r.done == SWITCHES, "seed %d: %d switches made (%d mode, %d hemisphere; %d attempts)" % [sd, r.done, r.kinds.mode, r.kinds.hemi, r.tries])
		ctx.check(r.unexpected.is_empty(), "seed %d: every switch is the graph's record (mode: move_mode_change, hemisphere: hemi_*): %s" % [sd, r.unexpected.slice(0, 4)])
		ctx.check(r.gait_bad.is_empty(), "seed %d: incoming bank starts at the outgoing gait phase (+- 0.05): %s" % [sd, r.gait_bad.slice(0, 4)])
		total_v += r.violations.size()
		total_n += r.done
		per_seed.append("%d: %d" % [sd, r.violations.size()])
		for v in r.violations:
			all_v.append("seed %d %s" % [sd, v])
	var allowed := int(floor(float(total_n) / float(SWITCHES)))
	ctx.at_most(total_v, allowed, "planted foot stays lowest (within %.2f m) for %.1f s after the switch: %d violations in %d switches over %d seeds (rate threshold <= 1 per %d; per seed %s): %s" % [
			TOL_M, HOLD_S, total_v, total_n, SEEDS.size(), SWITCHES, per_seed, all_v])
	ctx.metric("phase_match_violation_rate", float(total_v) / maxf(float(total_n), 1.0))


func _run_seed(ctx: AnimTestContext, h, sd: int) -> Dictionary:
	h.reset()
	var brain: LocoBrain = h.brain
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var mode := "run"
	var dir_a := 0.0
	var n0: int = h.until(func() -> bool: return brain.state == LocoBrain.MOVE, 600, LocoRig.dir(dir_a), SPEEDS[mode])
	if not ctx.check(n0 > 0, "seed %d: reaches MOVE running forward" % sd):
		return {}
	var done := 0
	var tries := 0
	var violations := []
	var gait_bad := []
	var kinds := {"mode": 0, "hemi": 0}
	var unexpected := []
	while done < SWITCHES and tries < 300:
		tries += 1
		# Next configuration.
		var kind := "mode" if rng.randf() < 0.5 else "hemi"
		var new_mode := mode
		var new_dir := dir_a
		if kind == "hemi" and mode == "sprint":
			kind = "mode"
		if kind == "mode":
			var opts := ["walk", "run"] if dir_a != 0.0 else ["walk", "run", "sprint"]
			opts.erase(mode)
			new_mode = opts[rng.randi() % opts.size()]
		else:
			new_dir = 0.0 if dir_a != 0.0 else (100.0 if rng.randf() < 0.5 else -100.0)
		# Hold the current configuration, then wait for a planted foot with >= 0.1 s of stance left.
		h.sprinting = mode == "sprint"
		h.run(rng.randi_range(24, 60), LocoRig.dir(dir_a), SPEEDS[mode])
		var foot := ""
		for i in 180:
			foot = _planted(h)
			if foot != "":
				break
			h.step(LocoRig.dir(dir_a), SPEEDS[mode])
		if foot == "":
			continue
		var out_id: StringName = brain.input_id
		var out_h := String(brain.hemi)
		var g_out := brain.gait_phase_of(out_id, out_h)
		# Switch.
		h.log.clear()
		h.sprinting = new_mode == "sprint"
		h.step(LocoRig.dir(new_dir), SPEEDS[new_mode])
		var t: Array = h.transitions()
		var want_key := "move_mode_change" if kind == "mode" else ("hemi_fw_to_bw" if new_dir != 0.0 else "hemi_bw_to_fw")
		if t.size() != 1 or String(t[0].info.key) != want_key or brain.state != LocoBrain.MOVE:
			unexpected.append("%s -> %s: %s" % [kind, want_key, t.map(func(e): return [e.info.key, e.info.to_graph])])
			mode = new_mode
			dir_a = new_dir
			h.run(90, LocoRig.dir(dir_a), SPEEDS[mode])
			continue
		kinds[kind] += 1
		var g_in := brain.gait_phase_of(brain.input_id, String(brain.hemi))
		# One frame of playback (<= 1.75 cycles/s x 1/60 s) separates the seek from the reading.
		var gd := absf(wrapf(g_in - g_out, -0.5, 0.5))
		if gd > 0.05:
			gait_bad.append("%s %s->%s %s->%s: gait out %.3f in %.3f" % [kind, mode, new_mode, out_h, brain.hemi, g_out, g_in])
		var worst := -INF
		for i in roundi(HOLD_S / h.dt):
			var other := "r" if foot == "l" else "l"
			worst = maxf(worst, h.foot_height(foot) - h.foot_height(other))
			if i < roundi(HOLD_S / h.dt) - 1:
				h.step(LocoRig.dir(new_dir), SPEEDS[new_mode])
		if worst > TOL_M:
			violations.append("%s %s->%s (%s->%s) foot %s: up to %.3f m above the other" % [kind, mode, new_mode, out_h, brain.hemi, foot, worst])
		done += 1
		mode = new_mode
		dir_a = new_dir
	h.sprinting = false
	return {"done": done, "tries": tries, "kinds": kinds, "violations": violations, "gait_bad": gait_bad, "unexpected": unexpected}


## "l" / "r" when that foot is in a stance of the current bank hemisphere's center clip with at
## least HOLD_S + 2 frames of it left, it is the lowest foot, and no fade is running; else "".
func _planted(h) -> String:
	var brain: LocoBrain = h.brain
	if brain.state != LocoBrain.MOVE or h.L.weight(brain.input_id) < 1.0:
		return ""
	var hw: Dictionary = h.hemi_weights(brain.input_id)
	if float(hw.get(String(brain.hemi), 0.0)) < 1.0:
		return ""
	var rec: Dictionary = h.idx.lower_record(brain.input_id)
	var hr: Dictionary = rec.hemis[String(brain.hemi)]
	var clip := String(hr.clips[0])
	var u := brain.phase()
	var rate := float(h.tree.get(hr.ts))
	var p: Dictionary = h.data.plants(clip)
	for foot in ["l", "r"]:
		for iv in p.get(foot + "_contact", []):
			for off in [0.0, 1.0]:
				var uu: float = u + float(off)
				if uu >= float(iv[0]) and uu <= float(iv[1]):
					var left_s: float = (float(iv[1]) - uu) / maxf(rate, 1e-6)
					if left_s >= HOLD_S + 2.0 * h.dt and h.lowest_foot() == foot:
						return foot
	return ""
