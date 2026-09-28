extends AnimTestSuite
## Engine contract (plan D5, 6.1; probe P5): with a filtered OneShot, a filtered bone that the shot
## clip does not key falls to the REST pose (so every OneShot filter must equal its clip's keyed
## bones; a union filter is unsafe). A MIX_MODE_ADD OneShot without a filter adds its clip exactly
## like Add2 and leaves bones the clip does not key untouched (the F / XA / HA chains).

const DT := 1.0 / 60.0


func describe() -> String:
	return "OneShot filter on an unkeyed bone -> rest; ADD OneShot == Add2"


func run(ctx: AnimTestContext) -> void:
	var r := ctx.synthetic_rig(["b", "c"], {
		"BASE": {"len": 1.0, "yaw": {"b": [[0.0, 30.0], [1.0, 30.0]], "c": [[0.0, 30.0], [1.0, 30.0]]}},
		"SHOT": {"len": 1.0, "yaw": {"b": [[0.0, 90.0], [1.0, 90.0]]}},
		"ADDC": {"len": 1.0, "yaw": {"b": [[0.0, 20.0], [1.0, 20.0]]}},
	})
	for filt in [["b", "c"], ["b"]]:
		var bt := _oneshot_tree(r, "SHOT", false)
		var os: AnimationNodeOneShot = bt.get_node("os")
		r.filter_bones(os, filt)
		r.play(bt)
		r.set_param("os/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		r.advance(DT, 15)
		ctx.check(bool(r.get_param("os/active")), "OneShot active 0.25 s after FIRE")
		ctx.near(r.yaw_deg("b"), 90.0, 1e-3, "filter %s: keyed filtered bone b takes the shot pose (90)" % [filt])
		if filt.size() == 2:
			ctx.near(r.yaw_deg("c"), 0.0, 1e-3, "filter [b, c]: filtered bone c, not keyed by the shot, falls to rest (0), not base (30)")
		else:
			ctx.near(r.yaw_deg("c"), 30.0, 1e-3, "filter [b]: unfiltered bone c keeps the base pose (30)")

	var add := _oneshot_tree(r, "ADDC", true)
	r.play(add)
	r.set_param("os/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	r.advance(DT, 15)
	ctx.near(r.yaw_deg("b"), 50.0, 1e-3, "MIX_MODE_ADD, no filter: b = base 30 + additive 20")
	ctx.near(r.yaw_deg("c"), 30.0, 1e-3, "MIX_MODE_ADD: bone c (not keyed by the additive) unchanged")
	var qb := r.bone_rot("b")
	var a2 := AnimationNodeBlendTree.new()
	a2.add_node("base", r.node("BASE"))
	a2.add_node("add", r.node("ADDC"))
	a2.add_node("add2", AnimationNodeAdd2.new())
	a2.connect_node("add2", 0, "base")
	a2.connect_node("add2", 1, "add")
	a2.connect_node("output", 0, "add2")
	r.play(a2, {"add2/add_amount": 1.0})
	ctx.near(r.bone_rot("b"), qb, 1e-6, "ADD OneShot at full fade == Add2 at amount 1")


func _oneshot_tree(r: RigFixture, shot: String, add: bool) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("base", r.node("BASE"))
	bt.add_node("shot", r.node(shot))
	var os := AnimationNodeOneShot.new()
	os.fadein_time = 0.1
	os.fadeout_time = 0.1
	if add:
		os.mix_mode = AnimationNodeOneShot.MIX_MODE_ADD
	bt.add_node("os", os)
	bt.connect_node("os", 0, "base")
	bt.connect_node("os", 1, "shot")
	bt.connect_node("output", 0, "os")
	return bt
