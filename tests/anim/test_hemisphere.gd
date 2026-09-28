extends AnimTestSuite
## WP4 (plan sections 6.5 and 10): hemisphere switching.
##   - idle entry: stick at 90 deg enters the forward hemisphere, at 91 deg the backward one
##     (graph idle records 0x0003f290 / 0x0003f2f0 into the start states by default; with the
##     gameplay override G1 0x0003f2c0 / 0x0003f320 straight into run-fw / run-bkwd);
##   - sweeps in MOVE (stick rotating 30 deg/s, both sides): the fw -> bw switch happens exactly on
##     the frame the move direction crosses 97.5 deg (record 0x0002a880) and bw -> fw exactly on
##     the frame it crosses 82.5 deg (0x00025230), and nowhere else;
##   - the hemisphere crossfade takes the graph's 0.75 s +- 1 frame by default and 0.3 s with the
##     gameplay override G2 (override_fast_hemisphere_fade);
##   - steady W+A (45 deg), A (90 deg), S+A (135 deg) for 10 s: 0 hemisphere flips (default and
##     G1).

const LocoRig := preload("res://tests/anim/loco_rig.gd")
const RUN := 3.6


func describe() -> String:
	return "LocoBrain hemispheres: idle entry 90 / 91, switch only at 97.5 / 82.5, graph 0.75 s fade (G2 0.3 s), no flips when steady"


func timeout_s() -> float:
	return 300.0


func run(ctx: AnimTestContext) -> void:
	for cfg in [{"label": "graph default", "overrides": []}, {"label": "G1 no start/stop", "overrides": ["override_no_transition_anims"]}]:
		var h = LocoRig.new()
		if not h.setup(ctx, {"overrides": cfg.overrides}):
			return
		var g1: bool = not cfg.overrides.is_empty()
		_idle_entry(ctx, h, cfg.label, g1)
		_steady(ctx, h, cfg.label)
	var hd = LocoRig.new()
	if not hd.setup(ctx):
		return
	_sweeps(ctx, hd, "graph default", 0.75)
	var h2 = LocoRig.new()
	if not h2.setup(ctx, {"overrides": ["override_fast_hemisphere_fade"]}):
		return
	_sweeps(ctx, h2, "G2 override", 0.3)


func _reset(h) -> void:
	h.reset()


func _idle_entry(ctx: AnimTestContext, h, label: String, g1: bool) -> void:
	var cases := [[Vector2(-1.0, 0.0), 90.0, "fw", "0x0003f2c0" if g1 else "0x0003f290"],
			[LocoRig.dir(91.0), 91.0, "bw", "0x0003f320" if g1 else "0x0003f2f0"],
			[Vector2(1.0, 0.0), -90.0, "fw", "0x0003f2c0" if g1 else "0x0003f290"],
			[LocoRig.dir(-91.0), -91.0, "bw", "0x0003f320" if g1 else "0x0003f2f0"]]
	for c in cases:
		_reset(h)
		h.step(c[0], RUN)
		var t: Array = h.transitions()
		var ok: bool = t.size() == 1
		var info: Dictionary = t[0].info if ok else {}
		var want_state := LocoBrain.MOVE if g1 else LocoBrain.START
		var want_key := "idle_to_move" if g1 else "idle_to_start"
		ctx.check(ok and t[0].to == want_state and String(info.hemi) == c[2] and String(info.key) == want_key
				and String(info.record) == c[3],
				"%s: idle entry at %.0f deg -> %s %s (%s, record %s): got %s" % [label, c[1], want_state, c[2], want_key, c[3],
				[t[0].to, info.get("hemi"), info.get("key"), info.get("record"), info.get("to_graph")] if ok else t.size()])


func _steady(ctx: AnimTestContext, h, label: String) -> void:
	for a in [45.0, 90.0, 135.0]:
		_reset(h)
		var hemis := {}
		var flips := 0
		var last := &""
		for i in 600:
			h.step(LocoRig.dir(a), RUN)
			if h.brain.state in [LocoBrain.START, LocoBrain.MOVE]:
				if last != &"" and h.brain.hemi != last:
					flips += 1
				last = h.brain.hemi
				hemis[String(last)] = true
		var hemi_keys := 0
		for e in h.log:
			if String(e.info.key) in ["hemi_fw_to_bw", "hemi_bw_to_fw", "start_hemi_switch", "move_reversal"]:
				hemi_keys += 1
		ctx.check(flips == 0 and hemi_keys == 0 and h.brain.state == LocoBrain.MOVE,
				"%s: steady %.0f deg for 10 s: %d hemisphere flips, %d hemisphere transitions, ends in %s %s (hemi %s)" % [
				label, a, flips, hemi_keys, h.brain.state, h.brain.graph_state, hemis.keys()])


## Sweeps the stick through a side (sign +1 left, -1 right) and back, 30 deg/s.
func _sweeps(ctx: AnimTestContext, h, label: String, fade: float) -> void:
	for side in [1.0, -1.0]:
		_reset(h)
		var n: int = h.until(func() -> bool: return h.brain.state == LocoBrain.MOVE, 400, Vector2(0.0, 1.0), RUN)
		if not ctx.check(n > 0, "%s: reaches MOVE running forward (%d frames)" % [label, n]):
			return
		h.log.clear()
		var a := 0.0
		var prev_dir: float = h.brain.move_dir_deg
		var prev_hemi: StringName = h.brain.hemi
		var flips: Array = []
		var fade_frames := {}
		var watching := ""
		var watch_n := 0
		for leg in [180.0, 0.0]:
			var step := 0.5 if leg > a else -0.5
			while (step > 0.0 and a < leg) or (step < 0.0 and a > leg):
				a += step
				h.step(LocoRig.dir(side * a), RUN)
				var d: float = h.brain.move_dir_deg
				if h.brain.hemi != prev_hemi:
					flips.append({"to": String(h.brain.hemi), "dir": d, "prev_dir": prev_dir, "frame": h.frame})
					watching = String(h.brain.hemi)
					watch_n = 0
				if watching != "":
					watch_n += 1
					var hw: Dictionary = h.hemi_weights(h.brain.input_id)
					if float(hw.get(watching, 0.0)) >= 1.0:
						fade_frames[watching] = watch_n
						watching = ""
				prev_dir = d
				prev_hemi = h.brain.hemi
			for i in 60:
				h.step(LocoRig.dir(side * a), RUN)
		var s := "left" if side > 0.0 else "right"
		ctx.check(flips.size() == 2, "%s, %s sweep 0 -> 180 -> 0: exactly 2 hemisphere switches (%s)" % [label, s, flips])
		if flips.size() == 2:
			var f0: Dictionary = flips[0]
			var f1: Dictionary = flips[1]
			ctx.check(f0.to == "bw" and absf(f0.dir) > 97.5 and absf(f0.prev_dir) <= 97.5,
					"%s, %s: fw -> bw on the frame |dir| crosses 97.5 (%.2f -> %.2f)" % [label, s, f0.prev_dir, f0.dir])
			ctx.check(f1.to == "fw" and absf(f1.dir) < 82.5 and absf(f1.prev_dir) >= 82.5,
					"%s, %s: bw -> fw on the frame |dir| crosses 82.5 (%.2f -> %.2f)" % [label, s, f1.prev_dir, f1.dir])
		var keys: Array = []
		for e in h.log:
			keys.append([String(e.info.key), String(e.info.get("record", "")), snappedf(float(e.info.fade_used), 0.001)])
		ctx.check(keys == [["hemi_fw_to_bw", "0x0002a880", fade], ["hemi_bw_to_fw", "0x00025230", fade]],
				"%s, %s: transitions are the graph hemisphere records with fade %.2f s: %s" % [label, s, fade, keys])
		var want := roundi(fade / h.dt)
		for hm in ["bw", "fw"]:
			var got := int(fade_frames.get(hm, -1))
			ctx.check(absi(got - want) <= 1, "%s, %s: hemisphere fade into %s takes %d frames (%.2f s, %d +- 1 expected)" % [
					label, s, hm, got, got * h.dt, want])
