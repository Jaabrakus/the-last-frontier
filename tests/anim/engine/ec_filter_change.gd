extends AnimTestSuite
## Engine contract (probe r8): changing a Blend2 filter while the tree is active takes effect at
## the next advance(). The plan never mutates filters at runtime (D5, lint in test_tree_build);
## this records the engine behaviour the old tree depended on.


func describe() -> String:
	return "Blend2 filter change applies at the next advance"


func run(ctx: AnimTestContext) -> void:
	var r := ctx.synthetic_rig(["b", "c"], {
		"A": {"len": 1.0, "yaw": {"b": [[0.0, 0.0], [1.0, 0.0]], "c": [[0.0, 0.0], [1.0, 0.0]]}},
		"B": {"len": 1.0, "yaw": {"b": [[0.0, 90.0], [1.0, 90.0]], "c": [[0.0, 90.0], [1.0, 90.0]]}},
	})
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("A", r.node("A"))
	bt.add_node("B", r.node("B"))
	var b2 := AnimationNodeBlend2.new()
	r.filter_bones(b2, ["b"])
	bt.add_node("b2", b2)
	bt.connect_node("b2", 0, "A")
	bt.connect_node("b2", 1, "B")
	bt.connect_node("output", 0, "b2")
	r.play(bt, {"b2/blend_amount": 1.0})
	r.advance(1.0 / 60.0)
	ctx.near(r.yaw_deg("b"), 90.0, 1e-3, "filter {b}: b from input 1")
	ctx.near(r.yaw_deg("c"), 0.0, 1e-3, "filter {b}: c from input 0")
	b2.set_filter_path(NodePath("Skeleton3D:b"), false)
	b2.set_filter_path(NodePath("Skeleton3D:c"), true)
	r.advance(1.0 / 60.0)
	ctx.near(r.yaw_deg("b"), 0.0, 1e-3, "after switching the filter to {c}: b from input 0 at the next advance")
	ctx.near(r.yaw_deg("c"), 90.0, 1e-3, "after switching the filter to {c}: c from input 1 at the next advance")
