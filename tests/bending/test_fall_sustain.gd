extends SceneTree
const Rig := preload("res://tests/anim/lib/rig_fixture.gd")
const Oracle := preload("res://tests/anim/lib/pose_oracle.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var rig := Rig.actor_b(root)
	var builder := TreeBuilder.new()
	builder.data = AnimGraphData.load_files()
	builder.ap = rig.ap
	builder.sk = rig.sk
	builder.idx = TreeIndex.new()
	builder.opts = {"carry": "none"}
	for lib: String in builder.data.override_libraries():
		if not rig.ap.has_animation_library(lib):
			rig.ap.add_animation_library(lib, load(builder.data.override_libraries()[lib]))
	var bt := AnimationNodeBlendTree.new()
	var rec := {"node": "fall_test", "layers": []}
	var path := builder.data.godot_anim("actor_b-p-fall")
	assert(rig.ap.has_animation(path), "test must sample the actual runtime override")
	var source := rig.ap.get_animation(path)
	var original_loop := source.loop_mode
	var old := builder._anim("actor_b-p-fall", "norm", true)
	rig.play(old)
	rig.advance(1.0 / 120.0, 119)
	var before := Oracle.capture(rig.sk)
	rig.advance(1.0 / 120.0, 2)
	var wrapped := Oracle.capture(rig.sk)
	var seam := 0.0
	for i in before.size():
		seam = maxf(seam, before.r[i].angle_to(wrapped.r[i]))
	print("Runtime fall wrap before fix: %.6f rad" % seam)
	builder._build_single(bt, {"clip": "actor_b-p-fall", "loop": true, "layers": {}}, rec)
	rig.play(bt, {"ts/scale": 1.0})
	rig.advance(1.0 / 120.0, 120)
	var settled := Oracle.capture(rig.sk)
	var max_r := 0.0
	var max_p := 0.0
	for frame in 240:
		rig.advance(1.0 / 120.0)
		var pose := Oracle.capture(rig.sk)
		for i in pose.size():
			max_r = maxf(max_r, settled.r[i].angle_to(pose.r[i]))
			max_p = maxf(max_p, settled.p[i].distance_to(pose.p[i]))
	assert(max_r < 0.002 and max_p < 0.0001, "sustained fall must not replay its entry")
	assert(source.loop_mode == original_loop, "source animation must remain unchanged")
	assert(not rec.loop, "runtime record must agree with playback")
	assert(seam > 0.05, "fixture must reproduce an actual visible loop seam")
	print("FALL SUSTAIN PASSED: max joint drift %.6f rad, %.6f m over two wraps" % [max_r, max_p])
	rig.root.queue_free()
	await process_frame
	quit()
