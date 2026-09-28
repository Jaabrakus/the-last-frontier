extends AnimTestSuite
## Engine contract (plan D9, 6.1; correction 5): AnimationNodeAnimation custom timelines.
## stretch_time_scale = true maps the clip onto timeline_length (normalized phase for the
## locomotion banks); loop_mode LINEAR on the node loops a LOOP_NONE clip; with stretch off the
## clip plays at its own speed and holds its last frame until the timeline wraps. The node's
## loop_mode only acts with use_custom_timeline = true (informational).

const DT := 1.0 / 60.0
const LEN := 0.733


func describe() -> String:
	return "custom timeline stretch / loop / length"


func run(ctx: AnimTestContext) -> void:
	# yaw = 100 * t / LEN, so the pose encodes the clip time.
	var r := ctx.synthetic_rig(["b"], {"R": {"len": LEN, "yaw": {"b": [[0.0, 0.0], [LEN, 100.0]]}}})
	var clip := r.anim("R")
	ctx.check(clip.loop_mode == Animation.LOOP_NONE, "test clip is LOOP_NONE (as every Actor_B clip)")

	# (a) stretch to 1.0, loop.
	r.play(_single(r.node("R", {"length": 1.0, "stretch": true, "loop": Animation.LOOP_LINEAR})))
	r.advance(DT, 30)
	ctx.near(r.yaw_deg("b"), 50.0, 0.05, "stretch: 0.5 s on a 1.0 timeline -> half the clip (yaw 50)")
	ctx.near(float(r.get_param("clip/current_position")), 0.5, 1e-4, "current_position is in timeline units (0.5)")
	r.advance(DT, 45)
	ctx.near(r.yaw_deg("b"), 25.0, 0.05, "loop LINEAR wraps a LOOP_NONE clip (1.25 -> 0.25 -> yaw 25)")
	ctx.check(is_equal_approx(clip.length, LEN) and clip.loop_mode == Animation.LOOP_NONE,
			"the Animation resource is not modified by the node settings")

	# (b) no stretch, timeline = clip length (the reload "mid" stages): loops at the clip length.
	r.play(_single(r.node("R", {"length": LEN, "stretch": false, "loop": Animation.LOOP_LINEAR})))
	r.advance(DT, 24)
	ctx.near(r.yaw_deg("b"), 0.4 / LEN * 100.0, 0.05, "no stretch: clip time = real time (0.4 s)")
	r.advance(DT, 36)
	ctx.near(r.yaw_deg("b"), (1.0 - LEN) / LEN * 100.0, 0.05, "no stretch, timeline = clip length: loops at the clip end (1.0 -> %.3f s)" % (1.0 - LEN))

	# (b2) no stretch, timeline longer than the clip (informational).
	r.play(_single(r.node("R", {"length": 1.0, "stretch": false, "loop": Animation.LOOP_LINEAR})))
	r.advance(DT, 54)
	var y09 := r.yaw_deg("b")
	r.advance(DT, 12)
	ctx.info("no stretch, 1.0 timeline on a %.3f s clip: clip time %.3f at 0.9 s, %.3f at 1.1 s (%s)" % [LEN, y09 / 100.0 * LEN,
			r.yaw_deg("b") / 100.0 * LEN, "the clip loops inside the timeline and restarts at timeline_length" if y09 < 99.0 else "holds its end"])

	# (c) start_offset with a stretched timeline (informational, P12).
	r.play(_single(r.node("R", {"length": 1.0, "stretch": true, "loop": Animation.LOOP_LINEAR, "start_offset": 0.25})))
	ctx.info("start_offset 0.25 on a stretched 1.0 timeline: yaw at t=0 = %.2f (25 if it shifts the normalized phase)" % r.yaw_deg("b"))

	# (d) node loop_mode without a custom timeline (informational).
	var n := r.node("R")
	n.loop_mode = Animation.LOOP_LINEAR
	r.play(_single(n))
	r.advance(DT, 60)
	var y := r.yaw_deg("b")
	if absf(y - 100.0) < 0.1:
		ctx.info("loop_mode without use_custom_timeline is ignored (clip holds its end, yaw %.1f): keep use_custom_timeline for loops" % y)
	else:
		ctx.info("CHANGED: loop_mode now acts without use_custom_timeline (yaw %.1f after 1.0 s)" % y)


func _single(n: AnimationNode) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("clip", n)
	bt.connect_node("output", 0, "clip")
	return bt
