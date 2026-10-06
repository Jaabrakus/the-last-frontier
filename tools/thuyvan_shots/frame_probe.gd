extends SceneTree
## The greybox's first water frame-time measure (plan phase 1, T5; internal: numbers for the builders, not the owner):
## the mood frames' camera at the still reach (shot_util.gd), the still band off (S0) and on (S1), each measured twice as
## tools/environment/benchmark.gd does (its segments are the fort's, so it cannot take this scene):
##   paced   the real loop for SECONDS: mean, p95 and max frame ms (on this Mac paced by the compositor at the display rate)
##   cost    the uncapped cost of the view: COST_DRAWS forced draws of the off-window view (RenderingServer.force_draw
##           without presenting), mean ms; and the logic per frame (TIME_PROCESS + 2 x TIME_PHYSICS_PROCESS, p95)
## One greppable line per state, "PROBE state=S0 ...", and out=<file.json> writes them.
##
##   zsh PLAN/bin/godot_run.sh --path <lane> --resolution 1600x900 -s tools/thuyvan_shots/frame_probe.gd -- \
##       quality=medium out=/tmp/t5_probe.json

const U := preload("res://tools/thuyvan_shots/shot_util.gd")
const SECONDS := 8.0
const COST_DRAWS := 20
## The camera turns this far either way over the paced run (deg), so the water fills the view and leaves it.
const SWEEP_DEG := 25.0


func _initialize() -> void:
	var a := U.args()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode_sleep_usec = 0
	var lv: Node = await U.load_level(self)
	if lv == null:
		print("PROBE no level")
		quit(1)
		return
	var cam := U.reach_camera(lv)
	U.set_sky(lv, 9.0, "fair")
	await U.settle(self, 120)
	var out := {"quality": String(a.get("quality", "(default)")), "adapter": RenderingServer.get_video_adapter_name(),
			"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y], "states": {}}
	var base := cam.global_transform
	for s: String in ["S0", "S1"]:
		lv.call("set_state", s, true)
		await U.settle(self, 60)
		var frames := PackedFloat32Array()
		var logic := PackedFloat32Array()
		var t0 := Time.get_ticks_usec()
		var last := t0
		while Time.get_ticks_usec() - t0 < int(SECONDS * 1e6):
			var k := float(Time.get_ticks_usec() - t0) / (SECONDS * 1e6)
			cam.global_transform = base.rotated_local(Vector3.UP, deg_to_rad(SWEEP_DEG) * sin(k * TAU))
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append((now - last) / 1000.0)
			last = now
			logic.append(1000.0 * (Performance.get_monitor(Performance.TIME_PROCESS) + 2.0 * Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)))
		cam.global_transform = base
		await U.settle(self, 10)
		var cost := _cost_ms()
		frames.sort()
		logic.sort()
		var mean := 0.0
		for v in frames:
			mean += v / frames.size()
		var r := {"frames": frames.size(), "mean_ms": mean, "p95_ms": frames[int(frames.size() * 0.95)],
				"max_ms": frames[frames.size() - 1], "render_ms": cost, "logic_p95_ms": logic[int(logic.size() * 0.95)]}
		out.states[s] = r
		print("PROBE state=%s frames=%d mean_ms=%.2f p95_ms=%.2f max_ms=%.2f render_ms=%.2f logic_p95_ms=%.2f" % [
				s, r.frames, r.mean_ms, r.p95_ms, r.max_ms, r.render_ms, r.logic_p95_ms])
	var d0: Dictionary = out.states.S0
	var d1: Dictionary = out.states.S1
	print("PROBE band render_ms S1-S0=%+.2f mean_ms S1-S0=%+.2f" % [float(d1.render_ms) - float(d0.render_ms), float(d1.mean_ms) - float(d0.mean_ms)])
	if a.has("out"):
		var f := FileAccess.open(String(a.out), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(out, "  "))
			f.close()
			print("PROBE wrote ", a.out)
	print("PROBE DONE")
	quit(0)


## Mean ms of one forced draw of the off-window view (no present, so no vsync wait).
func _cost_ms() -> float:
	for k in 6:
		RenderingServer.force_draw(false)
	var t := Time.get_ticks_usec()
	for k in COST_DRAWS:
		RenderingServer.force_draw(false)
	return (Time.get_ticks_usec() - t) / 1000.0 / COST_DRAWS
