extends AnimTestSuite
## Engine contract (plan 6.10, probe F3): a OneShot over a looping custom-timeline input (the
## reload "mid" stage under its TimeScale) with break_loop_at_end = false stays active until a
## FADE_OUT request and ends fadeout_time later; with break_loop_at_end = true it ends at the
## first loop boundary. The loop wraps inside the OneShot.

const DT := 1.0 / 60.0


func describe() -> String:
	return "OneShot + looping custom timeline + break_loop_at_end"


func run(ctx: AnimTestContext) -> void:
	# MID turns bone b 0 -> 70 deg over its 0.7 s, so yaw = 100 * clip time.
	var r := ctx.synthetic_rig(["b"], {
		"BASE": {"len": 1.0, "yaw": {"b": [[0.0, 0.0], [1.0, 0.0]]}},
		"MID": {"len": 0.7, "yaw": {"b": [[0.0, 0.0], [0.7, 70.0]]}},
	})
	var rate := 2.0 * 0.7 / 1.6   # 0.875: n = 2 whole loops in a 1.6 s stage (plan 6.10)
	for brk in [false, true]:
		var bt := AnimationNodeBlendTree.new()
		bt.add_node("base", r.node("BASE", {"length": 1.0, "loop": Animation.LOOP_LINEAR}))
		bt.add_node("mid", r.node("MID", {"length": 0.7, "stretch": false, "loop": Animation.LOOP_LINEAR}))
		bt.add_node("ts", AnimationNodeTimeScale.new())
		bt.connect_node("ts", 0, "mid")
		var os := AnimationNodeOneShot.new()
		os.fadein_time = 0.1
		os.fadeout_time = 0.2
		os.break_loop_at_end = brk
		bt.add_node("os", os)
		bt.connect_node("os", 0, "base")
		bt.connect_node("os", 1, "ts")
		bt.connect_node("output", 0, "os")
		r.play(bt, {"ts/scale": rate})
		r.set_param("os/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		var t := 0.0
		var fade_at := 2.5
		var requested := false
		var ended_at := -1.0
		var prev_pos := -1.0
		var wraps := 0
		var wrap_err := 0.0
		var first_pos := -1.0
		while t < 4.0:
			r.advance(DT)
			t += DT
			var pos := float(r.get_param("mid/current_position"))
			if first_pos < 0.0:
				first_pos = pos
			if bool(r.get_param("os/active")) and float(r.get_param("os/fade_in_remaining")) <= 0.0 \
					and float(r.get_param("os/fade_out_remaining")) <= 0.0:
				if prev_pos >= 0.0 and pos < prev_pos:
					wraps += 1
				wrap_err = maxf(wrap_err, absf(r.yaw_deg("b") - pos * 100.0))
			prev_pos = pos
			if not brk and not requested and t >= fade_at - 1e-6:
				r.set_param("os/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
				requested = true
				fade_at = t
			if ended_at < 0.0 and not bool(r.get_param("os/active")):
				ended_at = t
				break
		if brk:
			ctx.near(ended_at, 0.7 / rate, 1.5 * DT, "break_loop_at_end=true: ends at the first loop boundary (%.3f s at rate %.3f)" % [0.7 / rate, rate])
			ctx.check(wraps == 0, "break_loop_at_end=true: no wrap before the end (%d)" % wraps)
		else:
			ctx.near(ended_at - fade_at, 0.2, 1.5 * DT, "break_loop_at_end=false: active until FADE_OUT, ends fadeout_time (0.2 s) after it (%.4f s)" % (ended_at - fade_at))
			ctx.check(wraps >= 3, "break_loop_at_end=false: the looping input wraps inside the OneShot (%d wraps in %.2f s)" % [wraps, fade_at])
			ctx.at_most(wrap_err, 0.01, "at full weight the pose follows the looping input's current_position (max yaw error, deg)")
		ctx.info("break_loop_at_end=%s: clip position after the first advance following FIRE = %.4f s (the shot starts on that tick)" % [brk, first_pos])
		ctx.metric("ended_at_brk_%s" % brk, ended_at)
