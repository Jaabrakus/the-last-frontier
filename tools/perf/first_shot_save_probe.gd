extends SceneTree
## The first musket shot from a played game (user 2026-10-02: "first shot freeze when i click fire instantly"): the level
## with the survival rules and the saves on, the test folder's "auto" slot loaded (a copy of the player's own), then the
## musket drawn by its key and fired at once from the hip; prints the frames over 25 ms after the draw and the shot.
##   Godot --path . --resolution 1280x720 -s tools/perf/first_shot_save_probe.gd -- survival=on save=on
var _last := 0


func _initialize() -> void:
	OS.low_processor_usage_mode_sleep_usec = 0
	change_scene_to_file("res://scenes/main.tscn")
	for i in 60:
		await process_frame
	var sg := get_first_node_in_group(SaveGame.GROUP)
	print("LOAD ", sg.load_slot("auto") if sg else "no SaveGame")
	for i in 600:
		await process_frame
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	print("WEAPON before ", player.weapon_key, " usable musket ", player.is_usable("musket"))
	var slow := []
	_last = Time.get_ticks_usec()
	var ev := InputEventAction.new()
	ev.action = "weapon_2"
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 240:
		await process_frame
		if i == 3 or i == 90:
			Input.action_press("fire")
		if i == 6 or i == 93:
			Input.action_release("fire")
		var now := Time.get_ticks_usec()
		var ms := (now - _last) / 1000.0
		_last = now
		if ms > 25.0:
			slow.append("f%d %.0fms" % [i, ms])
	print("WEAPON after ", player.weapon_key)
	print("FRAMES over 25 ms: ", slow)
	print("SAVE PROBE DONE")
	quit()
