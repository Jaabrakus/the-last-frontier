extends AnimTestSuite
## Engine contract (plan 6.1 build rules, probe P12): after tree_root is set and active = true,
## two advance(0) calls leave the skeleton at the tree's output (PlayerAnim.setup() and
## RigFixture.play() do exactly this). The number of advances the pose actually needs is reported.


func describe() -> String:
	return "two warm-up advance(0) calls apply the first pose"


func run(ctx: AnimTestContext) -> void:
	var r := ctx.synthetic_rig(["b"], {"A": {"len": 1.0, "yaw": {"b": [[0.0, 35.0], [1.0, 35.0]]}}})
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("clip", r.node("A"))
	bt.connect_node("output", 0, "clip")
	r.tree.tree_root = bt
	r.tree.active = true
	var needed := -1
	for i in 4:
		r.tree.advance(0.0)
		if needed < 0 and absf(r.yaw_deg("b") - 35.0) < 1e-3:
			needed = i + 1
		if i == 1:
			ctx.near(r.yaw_deg("b"), 35.0, 1e-3, "pose applied after two warm-up advance(0) calls")
	ctx.info("advance(0) calls needed before the first pose shows: %d" % needed)
	ctx.metric("warmup_advances_needed", needed)
	ctx.check(needed >= 1 and needed <= 2, "no more than two warm-up advances are needed (%d)" % needed)
