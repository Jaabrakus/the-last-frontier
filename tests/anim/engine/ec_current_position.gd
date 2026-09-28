extends AnimTestSuite
## Engine contract (plan 6.1 / 6.4 / 6.9, probe F4): the playback position of an
## AnimationNodeAnimation is readable through parameters/<node path>/current_position, also
## inside a nested BlendTree and while the node is frozen at zero weight. LocoBrain phase(),
## the phase matching and AimStabilizer's aim-root sampling read it.


func describe() -> String:
	return "current_position readable (top level, nested, frozen)"


func run(ctx: AnimTestContext) -> void:
	var r := ctx.synthetic_rig(["b"], {"R": {"len": 1.0, "yaw": {"b": [[0.0, 0.0], [1.0, 100.0]]}}})
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("a", r.node("R", {"length": 1.0, "stretch": true, "loop": Animation.LOOP_LINEAR}))
	var inner := AnimationNodeBlendTree.new()
	inner.add_node("clip", r.node("R", {"length": 2.0, "stretch": false, "loop": Animation.LOOP_LINEAR}))
	inner.connect_node("output", 0, "clip")
	bt.add_node("nested", inner)
	var mix := AnimationNodeBlend2.new()
	mix.sync = false
	bt.add_node("mix", mix)
	bt.connect_node("mix", 0, "a")
	bt.connect_node("mix", 1, "nested")
	bt.connect_node("output", 0, "mix")
	r.play(bt, {"mix/blend_amount": 0.0})
	var props := {}
	for p in r.tree.get_property_list():
		props[p.name] = true
	ctx.check(props.has("parameters/a/current_position"), "parameters/a/current_position is a tree property")
	ctx.check(props.has("parameters/nested/clip/current_position"), "nested parameters/nested/clip/current_position is a tree property")
	r.advance(1.0 / 60.0, 30)
	ctx.near(float(r.get_param("a/current_position")), 0.5, 1e-4, "top-level position after 0.5 s")
	ctx.near(float(r.get_param("nested/clip/current_position")), 0.0, 1e-6, "nested zero-weight input reads 0 (frozen)")
	r.set_param("mix/blend_amount", 1.0)
	r.advance(1.0 / 60.0, 24)
	ctx.near(float(r.get_param("a/current_position")), 0.5, 1e-4, "top-level input frozen at zero weight keeps its position (0.5)")
	ctx.near(float(r.get_param("nested/clip/current_position")), 0.4, 1e-4, "nested position advances once weighted (0.4)")
	r.set_param("mix/blend_amount", 0.0)
	r.advance(1.0 / 60.0, 36)
	ctx.near(float(r.get_param("a/current_position")), 0.1, 1e-4, "custom-timeline loop wraps the reported position (1.1 -> 0.1)")
	ctx.near(float(r.get_param("nested/clip/current_position")), 0.4, 1e-4, "nested input frozen again keeps 0.4")
	ctx.info("current_length a = %s, nested = %s" % [r.get_param("a/current_length"), r.get_param("nested/clip/current_length")])
