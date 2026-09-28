extends AnimTestSuite
## Avoided behaviour, informational (plan D2; probes s2, r2, r7): an AnimationNodeStateMachine
## does not act on a transition that becomes valid while a cross-fade is running; it waits for the
## fade to end, and a request held for a short time can be lost entirely. The player tree has no
## StateMachine (a lint in test_tree_build enforces it). This suite measures the deferral and the
## lost request and passes either way; it prints CHANGED if Godot reacts at once.

const DT := 1.0 / 60.0


func describe() -> String:
	return "measures StateMachine fade deferral and held-request loss (informational)"


func run(ctx: AnimTestContext) -> void:
	var r := ctx.synthetic_rig(["b"], {
		"A": {"len": 1.0, "yaw": {"b": [[0.0, 0.0], [1.0, 0.0]]}},
		"B": {"len": 1.0, "yaw": {"b": [[0.0, 90.0], [1.0, 90.0]]}},
		"C": {"len": 1.0, "yaw": {"b": [[0.0, -90.0], [1.0, -90.0]]}},
	})
	var vars := _vars(ctx, r, "var go := false\nvar req_fall := false\nvar req_land := false\n")
	r.tree.advance_expression_base_node = r.tree.get_path_to(vars)

	# 1) A -> B (go, 0.5 s) then B -> A (not go, 0.5 s) flipped 0.1 s into the first fade.
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("A", r.node("A"))
	sm.add_node("B", r.node("B"))
	sm.add_transition("Start", "A", _tr("", 0.0))
	sm.add_transition("A", "B", _tr("go", 0.5))
	sm.add_transition("B", "A", _tr("not go", 0.5))
	r.play(sm)
	r.advance(0.1)
	vars.go = true
	var t := 0.0
	var peak_t := -1.0
	var peak := -INF
	var flipped_at := -1.0
	var trace := []
	for i in 90:
		r.advance(DT)
		t += DT
		var y := r.yaw_deg("b")
		trace.append(snappedf(y, 0.1))
		if flipped_at < 0.0 and t >= 0.1 - 1e-6:
			vars.go = false
			flipped_at = t
		if y > peak + 1e-4:
			peak = y
			peak_t = t
	var deferral := peak_t - flipped_at
	ctx.metric("sm_deferral_s", snappedf(deferral, 0.001))
	ctx.info("go=true, then go=false after %.3f s: yaw keeps rising until %.3f s (%.1f deg); trace %s" % [
			flipped_at, peak_t, peak, trace.slice(0, 50)])
	if deferral > 2.0 * DT:
		ctx.info("AVOIDED BEHAVIOUR PRESENT: StateMachine defers the reverse transition %.3f s (until the running fade ends)" % deferral)
	else:
		ctx.info("CHANGED: StateMachine reverses within %.3f s of the condition change" % deferral)

	# 2) Held request (r7): loco -(req_fall, 0.2)-> fall -(req_land, 0.1)-> land; land requested
	#    2 frames after the fall request and held 0.15 s. Is land ever reached?
	var sm2 := AnimationNodeStateMachine.new()
	sm2.add_node("loco", r.node("A"))
	sm2.add_node("fall", r.node("B"))
	sm2.add_node("land", r.node("C"))
	sm2.add_transition("Start", "loco", _tr("", 0.0))
	sm2.add_transition("loco", "fall", _tr("req_fall", 0.2))
	sm2.add_transition("fall", "land", _tr("req_land", 0.1))
	vars.go = false
	r.play(sm2)
	r.advance(0.1)
	var pb: AnimationNodeStateMachinePlayback = r.get_param("playback")
	vars.req_fall = true
	var cur_prev := pb.get_current_node()
	var reached := false
	var land_at := -1.0
	t = 0.0
	var changes := []
	for i in 60:
		if i == 2:
			vars.req_land = true
			land_at = t
		r.advance(DT)
		t += DT
		var cur := pb.get_current_node()
		if cur != cur_prev:
			changes.append("%.3f:%s" % [t, cur])
			if vars.req_fall:
				vars.req_fall = false
		if vars.req_land and (cur != cur_prev or t - land_at >= 0.15):
			vars.req_land = false
		if cur == &"land":
			reached = true
		cur_prev = cur
	ctx.metric("sm_held_request_reached_land", reached)
	ctx.info("held request: state changes %s, final %s" % [changes, pb.get_current_node()])
	if reached:
		ctx.info("CHANGED: a 0.15 s held request during a running fade now reaches 'land'")
	else:
		ctx.info("AVOIDED BEHAVIOUR PRESENT: the land request held 0.15 s during the 0.2 s fall fade is lost (stuck in %s)" % pb.get_current_node())
	ctx.check(trace.size() == 90, "measurement completed")


func _tr(expr: String, xf: float) -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xf
	t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	if expr != "":
		t.advance_expression = expr
	return t


func _vars(ctx: AnimTestContext, r: RigFixture, src: String) -> Node:
	var s := GDScript.new()
	s.source_code = "extends Node\n" + src
	s.reload()
	var n := Node.new()
	n.name = "Vars"
	n.set_script(s)
	r.root.add_child(n)
	return n
