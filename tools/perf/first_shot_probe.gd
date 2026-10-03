extends SceneTree
## The first musket shot's hitch (user 2026-10-02: "fix the game freeze on first musket shot"): the level loaded and settled,
## the musket drawn, then two shots a few seconds apart; prints the worst frame (ms) in the half second after each, and the
## frames over 25 ms with what the engine was doing. Needs a window (shader compiles only happen on a real GPU).
##   Godot --path . --resolution 1280x720 -s tools/perf/first_shot_probe.gd -- [quality=medium] [hip=1: fire at once, no aim]

var _times: Array = []
var _last := 0


func _initialize() -> void:
	OS.low_processor_usage_mode_sleep_usec = 0
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	for i in 300:
		await process_frame
	player.switch_weapon("musket")
	for i in 180:
		await process_frame
	var hip := "hip=1" in OS.get_cmdline_user_args()
	for shot in 2:
		if not hip:
			Input.action_press("aim")
			for i in 40:
				await process_frame
		var worst := 0.0
		var slow := []
		_last = Time.get_ticks_usec()
		Input.action_press("fire")
		for i in 30:
			await process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - _last) / 1000.0
			_last = now
			worst = maxf(worst, ms)
			if ms > 25.0:
				slow.append("f%d %.0fms" % [i, ms])
				if ms > 120.0:
					print("  BIG f%d %.0f ms  objects %d  nodes %d  draw calls %d" % [i, ms, Performance.get_monitor(Performance.OBJECT_COUNT),
							Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
			if i == 2:
				Input.action_release("fire")
		Input.action_release("aim")
		print("SHOT %d worst %.1f ms  slow %s  (weapon %s)" % [shot + 1, worst, slow, player.weapon_key if "weapon_key" in player else "?"])
		for i in 600:   # the reload
			await process_frame
	print("FIRST SHOT PROBE DONE")
	quit()
