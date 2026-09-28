extends AnimTestSuite
## Engine contract (plan D2 / 6.2, probes F4 and r4): a zero-weight input under a sync=false
## Blend2 is frozen (its time does not advance), a TimeSeek on that input places it on re-entry,
## and a sync=false BlendSpace1D freezes its zero-weight points while sync=true advances them.
## XFadeSelector chains rely on the freeze plus explicit re-entry seeks.


func describe() -> String:
	return "sync=false zero-weight freeze, TimeSeek re-entry, BlendSpace1D sync"


func run(ctx: AnimTestContext) -> void:
	# B turns bone b at 50 deg/s, so its yaw encodes its playback time.
	var r := ctx.synthetic_rig(["b"], {
		"A": {"len": 1.0, "yaw": {"b": [[0.0, 0.0], [1.0, 0.0]]}},
		"B": {"len": 2.0, "yaw": {"b": [[0.0, 0.0], [2.0, 100.0]]}},
	})
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("A", r.node("A"))
	bt.add_node("B", r.node("B"))
	bt.add_node("seekB", AnimationNodeTimeSeek.new())
	bt.connect_node("seekB", 0, "B")
	var b2 := AnimationNodeBlend2.new()
	b2.sync = false
	bt.add_node("mix", b2)
	bt.connect_node("mix", 0, "A")
	bt.connect_node("mix", 1, "seekB")
	bt.connect_node("output", 0, "mix")
	r.play(bt, {"mix/blend_amount": 0.0})
	r.advance(1.0 / 60.0, 30)
	ctx.near(float(r.get_param("B/current_position")), 0.0, 1e-6,
			"sync=false Blend2: zero-weight input's current_position stays 0 while its sibling plays 0.5 s")
	r.set_param("mix/blend_amount", 1.0)
	r.advance(0.0)
	ctx.near(r.yaw_deg("b"), 0.0, 0.01, "frozen input resumes at t = 0 when weighted (yaw 0; 25 if it had advanced)")
	r.advance(1.0 / 60.0, 12)
	ctx.near(r.yaw_deg("b"), 10.0, 0.05, "weighted input advances normally (0.2 s -> yaw 10)")
	r.set_param("seekB/seek_request", 1.0)
	r.advance(0.0)
	ctx.near(r.yaw_deg("b"), 50.0, 0.01, "TimeSeek seek_request places the input (1.0 s -> yaw 50)")
	r.set_param("mix/blend_amount", 0.0)
	r.advance(1.0 / 60.0, 30)
	r.set_param("seekB/seek_request", 0.4)
	r.set_param("mix/blend_amount", 1.0)
	r.advance(0.0)
	ctx.near(r.yaw_deg("b"), 20.0, 0.01, "re-entry seek written in the same frame as the weight change is exact (0.4 s -> yaw 20)")

	# BlendSpace1D: points 0 = A, 1 = B.
	for sync in [false, true]:
		var bs := AnimationNodeBlendSpace1D.new()
		bs.sync = sync
		bs.min_space = 0.0
		bs.max_space = 1.0
		bs.add_blend_point(r.node("A"), 0.0, -1, &"A")
		bs.add_blend_point(r.node("B"), 1.0, -1, &"B")
		var t2 := AnimationNodeBlendTree.new()
		t2.add_node("bs", bs)
		t2.connect_node("output", 0, "bs")
		r.play(t2, {"bs/blend_position": 0.0})
		r.advance(1.0 / 60.0, 18)
		r.set_param("bs/blend_position", 1.0)
		r.advance(0.0)
		var expect := 15.0 if sync else 0.0
		ctx.near(r.yaw_deg("b"), expect, 0.05, "BlendSpace1D sync=%s: zero-weight point %s (yaw %.0f after 0.3 s)" % [
				sync, "advances with the space" if sync else "is frozen", expect])
