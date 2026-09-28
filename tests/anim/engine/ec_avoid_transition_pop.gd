extends AnimTestSuite
## Avoided behaviour, informational (plan D2; probes s1, r1, r5, R4): interrupting an
## AnimationNodeTransition cross-fade with a new request pops, because the fade restarts from the
## current input and drops the blended-out one at once. The player tree therefore has no
## Transition; every choice is an XFadeSelector (script-weighted Blend2 chain). This suite measures
## the pop and passes either way; it prints CHANGED if Godot stops popping.

const DT := 1.0 / 60.0
const FADE := 0.5


func describe() -> String:
	return "measures the AnimationNodeTransition interrupt pop (informational)"


func run(ctx: AnimTestContext) -> void:
	var r := ctx.synthetic_rig(["b"], {
		"A": {"len": 1.0, "yaw": {"b": [[0.0, 0.0], [1.0, 0.0]]}},
		"B": {"len": 1.0, "yaw": {"b": [[0.0, 60.0], [1.0, 60.0]]}},
		"C": {"len": 1.0, "yaw": {"b": [[0.0, 120.0], [1.0, 120.0]]}},
	})
	var tr := AnimationNodeTransition.new()
	tr.xfade_time = FADE
	tr.input_count = 3
	var bt := AnimationNodeBlendTree.new()
	for i in 3:
		var n: String = ["A", "B", "C"][i]
		tr.set_input_name(i, n)
		bt.add_node(n, r.node(n))
	bt.add_node("t", tr)
	for i in 3:
		bt.connect_node("t", i, ["A", "B", "C"][i])
	bt.connect_node("output", 0, "t")
	r.play(bt)
	r.set_param("t/transition_request", "A")
	r.advance(0.1)
	r.set_param("t/transition_request", "B")
	var prev := r.yaw_deg("b")
	var steps := []
	for i in 6:
		r.advance(DT)
		steps.append(r.yaw_deg("b"))
	var before := r.yaw_deg("b")
	r.set_param("t/transition_request", "C")
	var max_step := 0.0
	prev = before
	for i in 40:
		r.advance(DT)
		var y := r.yaw_deg("b")
		max_step = maxf(max_step, absf(y - prev))
		steps.append(y)
		prev = y
	# A continuous fade from the current pose to C moves at most (120 - 0) / FADE deg/s.
	var bound := 120.0 / FADE * DT
	var pop := max_step
	ctx.metric("transition_interrupt_max_step_deg", snappedf(pop, 0.01))
	ctx.metric("continuous_bound_deg", snappedf(bound, 0.01))
	ctx.info("A->B fade (0.5 s) interrupted by C at %.1f deg: yaw per 1/60 s step %s" % [before,
			steps.map(func(v): return snappedf(v, 0.1))])
	if pop > 2.0 * bound:
		ctx.info("AVOIDED BEHAVIOUR PRESENT: Transition interrupt pops %.1f deg in one frame (continuous bound %.1f deg/frame)" % [pop, bound])
	else:
		ctx.info("CHANGED: Transition interrupt no longer pops (max %.1f deg/frame <= %.1f); plan D2 could be revisited" % [pop, 2.0 * bound])
	ctx.check(steps.size() == 46, "measurement completed")
