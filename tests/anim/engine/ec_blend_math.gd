extends AnimTestSuite
## Engine contract + oracle acceptance (plan D7, D11, section 10; WPT acceptance), on the real
## Actor_B rig (rest = null-add):
##   - Godot Add2 == the graph's additive composition base * (null-add^-1 * add)^w:
##     Add2(rifle-idle-aim, rifle-idle-aim-up--add) vs PoseOracle.additive <= 0.001 rad.
##   - A filtered Blend2 matches PoseOracle's Godot-semantics evaluator <= 1e-4 rad at any amount,
##     and the graph partial override at amount 1.
##   - Unfiltered Blend2 and BlendSpace1D match the Godot-semantics evaluator <= 1e-4 rad; the
##     difference to graph slerp crossfades is reported (the accumulation is rest-relative).
##   - deterministic = true is required: with false the mixer normalises weights and Add2 is no
##     longer additive (reported; the tree builder sets deterministic = true).

const AIM := "actor_b-p-rifle-idle-aim"
const UP := "actor_b-p-rifle-idle-aim-up--add"
const IDLE := "actor_b-p-stealth-idle"
const ARMS := "actor_b-p-rifle-run-arms"
const FW := "actor_b-p-walk-fw"
const LT := "actor_b-p-walk-fw-lt"
const RT := "actor_b-p-walk-fw-rt"


func timeout_s() -> float:
	return 240.0


func describe() -> String:
	return "Godot blend math vs PoseOracle (Add2 = graph additive; filtered Blend2 exact)"


func run(ctx: AnimTestContext) -> void:
	var r := ctx.rig()
	if r == null:
		return
	for c in [AIM, UP, IDLE, ARMS, FW, LT, RT]:
		if not r.has_clip(c):
			ctx.fail("clip missing from actor_b: " + c)
			return
	ctx.check(bool(r.rest_report.get("ok", false)), "rig rest == null-add (%s: rot %s rad, pos %s m)" % [
			r.rest_report.get("source", "?"), AnimTestContext.fmt(float(r.rest_report.get("max_rot", INF))),
			AnimTestContext.fmt(float(r.rest_report.get("max_pos", INF)))])
	var o := ctx.oracle(r)

	# Single clip leaf and model space: oracle vs Godot.
	var leaf := r.pose_of(AIM, 1.7)
	var dl := o.compare(o.clip(AIM, 1.7), leaf)
	ctx.at_most(dl.max_rot, 1e-5, "single clip %s @1.7 s: oracle leaf vs Godot, max rot error (rad)" % AIM)
	var model := o.model_transforms(o.clip(AIM, 1.7))
	var worst := 0.0
	for i in r.sk.get_bone_count():
		worst = maxf(worst, model[i].origin.distance_to(r.sk.get_bone_global_pose(i).origin))
	ctx.at_most(worst, 1e-5, "oracle model_transforms vs Skeleton3D.get_bone_global_pose, max joint error (m)")

	# Add2(rifle-idle-aim, rifle-idle-aim-up--add)
	for t in [0.0, 1.7]:
		for w in [1.0, 0.5]:
			var got := _add2_pose(r, AIM, UP, w, t)
			var graph := o.additive(o.clip(AIM, t), o.clip(UP, 0.0), w)
			var d := o.compare(graph, got)
			ctx.at_most(d.max_rot, 0.001, "Add2(%s @%.1f, %s, %.1f) vs graph additive: max rot error (rad, bone %s)" % [
					AIM, t, UP, w, d.max_rot_bone])
			ctx.at_most(d.max_pos, 1e-4, "  ... max position error (m)")
			var godot := o.g_eval(o.g_add2(o.g_clip(AIM, t), o.g_clip(UP, 0.0), w))
			ctx.at_most(o.compare(godot, got).max_rot, 1e-4, "  ... vs oracle Godot semantics (rad)")
			if t == 0.0 and w == 1.0:
				ctx.metric("add2_vs_graph_max_rot", d.max_rot)
				var change := o.compare(o.clip(AIM, t), got)
				ctx.at_least(change.max_rot, 0.1, "  the aim-up additive visibly changes the pose (max %s rad)" % AnimTestContext.fmt(change.max_rot))

	# Filtered Blend2: stealth-idle + rifle-run-arms on the arms' keyed bones.
	var arms_bones := r.keyed_bones(ARMS)
	for w in [1.0, 0.5, 0.3]:
		var got := _filtered_pose(r, IDLE, ARMS, w)
		var godot := o.g_eval(o.g_blend2(o.g_clip(IDLE), o.g_clip(ARMS), w, arms_bones))
		var d := o.compare(godot, got)
		ctx.at_most(d.max_rot, 1e-4, "filtered Blend2(%s, %s, %.1f) vs oracle Godot semantics: max rot error (rad, %s)" % [
				IDLE, ARMS, w, d.max_rot_bone])
		ctx.at_most(d.max_pos, 1e-5, "  ... max position error (m)")
		var graph := o.partial(o.clip(IDLE), o.clip(ARMS), w)
		var dg := o.compare(graph, got)
		if w == 1.0:
			ctx.at_most(dg.max_rot, 1e-4, "  ... amount 1 vs graph partial override (rad)")
			ctx.metric("filtered_blend2_vs_oracle_max_rot", d.max_rot)
		else:
			ctx.info("filtered Blend2 %.1f: Godot (rest-relative) vs graph slerp partial: max %.4f rad (%s), mean %.4f" % [
					w, dg.max_rot, dg.max_rot_bone, dg.mean_rot])

	# Unfiltered Blend2 crossfade and BlendSpace1D (direction bank shape).
	var cf := _blend2_pose(r, FW, LT, 0.3, 0.4)
	var cf_g := o.g_eval(o.g_blend2(o.g_clip(FW, 0.4), o.g_clip(LT, 0.4), 0.3))
	ctx.at_most(o.compare(cf_g, cf).max_rot, 1e-4, "Blend2(walk-fw, walk-fw-lt, 0.3) vs oracle Godot semantics (rad)")
	var cf_graph := o.crossfade(o.clip(FW, 0.4), o.clip(LT, 0.4), 0.3)
	var dcf := o.compare(cf_graph, cf)
	ctx.info("Blend2 0.3 vs graph slerp crossfade: max %.4f rad (%s), mean %.4f" % [dcf.max_rot, dcf.max_rot_bone, dcf.mean_rot])
	for x in [-45.0, 30.0]:
		var bs := _bs1d_pose(r, x, 0.2)
		var pts := [[-90.0, o.g_clip(RT, 0.2)], [0.0, o.g_clip(FW, 0.2)], [90.0, o.g_clip(LT, 0.2)]]
		var bs_g := o.g_eval(o.g_blend_space_1d(pts, x))
		ctx.at_most(o.compare(bs_g, bs).max_rot, 1e-4, "BlendSpace1D(rt, fw, lt) at %+.0f deg vs oracle Godot semantics (rad)" % x)
		var dir := o.direction_fw(o.clip(FW, 0.2), o.clip(RT, 0.2), o.clip(LT, 0.2), x)
		var dd := o.compare(dir, bs)
		ctx.info("BlendSpace1D %+.0f deg vs graph lerp-scale direction chain: max %.4f rad (%s), mean %.4f" % [
				x, dd.max_rot, dd.max_rot_bone, dd.mean_rot])

	# deterministic = false breaks additive composition (informational; the builder sets true).
	r.tree.deterministic = false
	var nd := _add2_pose(r, AIM, UP, 1.0, 0.0)
	r.tree.deterministic = true
	var dn := o.compare(o.additive(o.clip(AIM), o.clip(UP), 1.0), nd)
	ctx.metric("add2_nondeterministic_max_rot", dn.max_rot)
	if dn.max_rot > 0.01:
		ctx.info("deterministic = false: Add2 deviates %.3f rad from the additive composition (normalised weights); keep deterministic = true" % dn.max_rot)
	else:
		ctx.info("CHANGED: deterministic = false no longer affects Add2 (%.5f rad)" % dn.max_rot)


func _add2_pose(r: RigFixture, base: String, add: String, w: float, t: float) -> PoseOracle.Pose:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("base", r.node(base))
	bt.add_node("seek", AnimationNodeTimeSeek.new())
	bt.connect_node("seek", 0, "base")
	bt.add_node("add", r.node(add))
	bt.add_node("add2", AnimationNodeAdd2.new())
	bt.connect_node("add2", 0, "seek")
	bt.connect_node("add2", 1, "add")
	bt.connect_node("output", 0, "add2")
	r.play(bt, {"add2/add_amount": w})
	r.set_param("seek/seek_request", t)
	r.advance(0.0)
	return r.capture()


func _filtered_pose(r: RigFixture, base: String, over: String, w: float) -> PoseOracle.Pose:
	r.layer_tree(base, over, w)
	return r.capture()


func _blend2_pose(r: RigFixture, a: String, b: String, w: float, t: float) -> PoseOracle.Pose:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("a", r.node(a))
	bt.add_node("b", r.node(b))
	var b2 := AnimationNodeBlend2.new()
	bt.add_node("mix", b2)
	bt.connect_node("mix", 0, "a")
	bt.connect_node("mix", 1, "b")
	bt.add_node("seek", AnimationNodeTimeSeek.new())
	bt.connect_node("seek", 0, "mix")
	bt.connect_node("output", 0, "seek")
	r.play(bt, {"mix/blend_amount": w})
	r.set_param("seek/seek_request", t)
	r.advance(0.0)
	return r.capture()


func _bs1d_pose(r: RigFixture, x: float, t: float) -> PoseOracle.Pose:
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = -90.0
	bs.max_space = 90.0
	bs.add_blend_point(r.node(RT), -90.0, -1, &"rt")
	bs.add_blend_point(r.node(FW), 0.0, -1, &"fw")
	bs.add_blend_point(r.node(LT), 90.0, -1, &"lt")
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("bs", bs)
	bt.add_node("seek", AnimationNodeTimeSeek.new())
	bt.connect_node("seek", 0, "bs")
	bt.connect_node("output", 0, "seek")
	r.play(bt, {"bs/blend_position": x})
	r.set_param("seek/seek_request", t)
	r.advance(0.0)
	return r.capture()
