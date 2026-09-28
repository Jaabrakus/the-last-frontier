extends SceneTree
## Game-logic cost probe (forest performance pass, 2026-09-25): scripts, animation, physics and
## audio per 60 fps frame, WITHOUT rendering, so the number is not polluted by force_draw() calls
## (benchmark.gd's logic_ms reads Performance.TIME_PROCESS, the engine's max over the last second,
## which includes the benchmark's own probe draws). Headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tools/environment/perf/logic_probe.gd [-- frames=600]
##
## With --fixed-fps 60 every iteration advances exactly 1/60 s (2 physics ticks at 120 Hz) and does
## not sleep, so the wall time of an iteration is the logic cost of a 60 fps frame. Segments:
##   fort_idle    player standing at spawn (0, 0.1, 6)
##   fort_walk    walking north over the parade ground
##   forest_walk  walking (Alt) along benchmark.gd's forest heading from (-70, -55)
##   forest_run   sprinting along the same heading
## The vegetation colliders (trunks, rocks, logs, stumps) are built headless as in game.
## Lines: LOGIC seg=<name> frames= mean_ms= p50_ms= p95_ms= max_ms= ; ends with LOGIC PROBE DONE.

var player: Node3D
var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.set("ignore_mouse_capture", true)
	for i in 120:
		await process_frame
	var n := int(args.get("frames", "600"))
	var heading := Vector3(-0.766, 0.0, 0.643)
	var yaw := atan2(-heading.x, -heading.z)
	for seg: Array in [["fort_idle", Vector3(0, 0.1, 6), 0.0, []], ["fort_walk", Vector3(0, 0.1, 6), 0.0, ["move_forward", "walk"]],
			["forest_walk", Vector3(-70, 0, -55), yaw, ["move_forward", "walk"]], ["forest_run", Vector3(-70, 0, -55), yaw, ["move_forward", "sprint"]]]:
		var p: Vector3 = seg[1]
		if p.y == 0.0:
			p.y = FrontierTerrain.height_at(p.x, p.z) + 0.1
		player.global_position = p
		player.set("velocity", Vector3.ZERO)
		player.set("yaw", float(seg[2]))
		for a: String in seg[3]:
			Input.action_press(a)
		for i in 30:
			await process_frame
		var ms := PackedFloat32Array()
		var last := Time.get_ticks_usec()
		for i in n:
			await process_frame
			var now := Time.get_ticks_usec()
			ms.append((now - last) / 1000.0)
			last = now
		for a: String in seg[3]:
			Input.action_release(a)
		var s := ms.duplicate()
		s.sort()
		var mean := 0.0
		for v in ms:
			mean += v / ms.size()
		print("LOGIC seg=%-12s frames=%4d mean_ms=%6.3f p50_ms=%6.3f p95_ms=%6.3f max_ms=%7.3f end=%s" % [seg[0], n, mean,
				s[s.size() / 2], s[int(s.size() * 0.95)], s[s.size() - 1], str(player.global_position.snapped(Vector3.ONE * 0.1))])
	print("LOGIC PROBE DONE")
	quit()
