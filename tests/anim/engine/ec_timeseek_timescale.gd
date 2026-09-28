extends AnimTestSuite
## Engine contract (plan 6.1 move banks and bow charge): a TimeSeek under a TimeScale seeks in the
## child's own time (seek_request is not scaled), the TimeScale then scales advancing; and a
## TimeSeek over a TimeScale of 0 holds the sought pose (the C_seek / C_ts charge pattern).


func describe() -> String:
	return "TimeSeek under TimeScale seeks in child time; seek over scale 0 holds"


func run(ctx: AnimTestContext) -> void:
	# yaw = 50 deg/s * t, so yaw / 50 is the child's time.
	var r := ctx.synthetic_rig(["b"], {"R": {"len": 2.0, "yaw": {"b": [[0.0, 0.0], [2.0, 100.0]]}}})
	# Plan layout: output <- ts (TimeScale) <- seek (TimeSeek) <- clip
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("clip", r.node("R"))
	bt.add_node("seek", AnimationNodeTimeSeek.new())
	bt.add_node("ts", AnimationNodeTimeScale.new())
	bt.connect_node("seek", 0, "clip")
	bt.connect_node("ts", 0, "seek")
	bt.connect_node("output", 0, "ts")
	r.play(bt, {"ts/scale": 2.0})
	r.set_param("seek/seek_request", 0.5)
	r.advance(0.0)
	ctx.near(r.yaw_deg("b") / 50.0, 0.5, 1e-4, "seek 0.5 under TimeScale 2 lands at child time 0.5")
	r.advance(0.1)
	ctx.near(r.yaw_deg("b") / 50.0, 0.7, 1e-4, "then 0.1 s of advance at scale 2 moves the child 0.2 s")
	r.set_param("seek/seek_request", 1.2)
	r.advance(1.0 / 60.0)
	ctx.near(r.yaw_deg("b") / 50.0, 1.2, 1e-4, "seek applied in the same advance as a delta does not add that delta (1.2)")

	# Reverse order (seek above the scale): informational.
	var bt2 := AnimationNodeBlendTree.new()
	bt2.add_node("clip", r.node("R"))
	bt2.add_node("ts", AnimationNodeTimeScale.new())
	bt2.add_node("seek", AnimationNodeTimeSeek.new())
	bt2.connect_node("ts", 0, "clip")
	bt2.connect_node("seek", 0, "ts")
	bt2.connect_node("output", 0, "seek")
	r.play(bt2, {"ts/scale": 2.0})
	r.set_param("seek/seek_request", 0.5)
	r.advance(0.0)
	ctx.info("seek 0.5 above TimeScale 2 lands at child time %.4f" % (r.yaw_deg("b") / 50.0))

	# Charge pattern: output <- seek <- ts (scale 0) <- clip
	var bt3 := AnimationNodeBlendTree.new()
	bt3.add_node("clip", r.node("R"))
	bt3.add_node("ts", AnimationNodeTimeScale.new())
	bt3.add_node("seek", AnimationNodeTimeSeek.new())
	bt3.connect_node("ts", 0, "clip")
	bt3.connect_node("seek", 0, "ts")
	bt3.connect_node("output", 0, "seek")
	r.play(bt3, {"ts/scale": 0.0})
	r.set_param("seek/seek_request", 0.8)
	r.advance(1.0 / 60.0)
	ctx.near(r.yaw_deg("b") / 50.0, 0.8, 1e-4, "seek over TimeScale 0 places the frozen clip (0.8)")
	r.advance(1.0 / 60.0, 30)
	ctx.near(r.yaw_deg("b") / 50.0, 0.8, 1e-4, "TimeScale 0 holds the sought pose while the tree advances")
	r.set_param("seek/seek_request", 1.6)
	r.advance(1.0 / 60.0)
	ctx.near(r.yaw_deg("b") / 50.0, 1.6, 1e-4, "a new seek every frame follows the driven value (1.6)")
