extends SceneTree
## Windowed screenshots of the survival bridge (needs a window, not --headless):
##   morning.png   the gameplay camera at the start: Early September 1765, the needs bottom left
##   hungry.png    hungry and tired: the rows amber, the notice
##   pack.png      the pack after a right-click on the jerky (its icon, the cornmeal's, the line)
##   night.png     late evening, the sky dark
##   sleep.png     Z: sitting down to sleep, the screen dimmed, the clock running
##   dawn.png      waking at sunrise
##   sheet.png     all of them
## and prints what the bridge costs a frame.
##
##   Godot --path . --resolution 1280x720 -s tests/survival_game/survival_shots.gd -- out=/abs/dir survival=on

const CELL := Vector2i(640, 360)

var out := ""
var b: SurvivalBridge
var player: FrontierPlayer
var shots: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	await _frames(200)
	b = SurvivalBridge.find(self)
	# the cost: the bridge's frame with the core's step in it
	var t0 := Time.get_ticks_usec()
	for i in 200:
		b._process(1.0 / 60.0)
	print("cost: %.3f ms a frame (bridge + core, 200 frames)" % ((Time.get_ticks_usec() - t0) / 200000.0))
	await _shot("morning")
	b.core.advance(9.0 * 60.0)
	b.core.state.needs["stomach"] = 600.0
	b.core.state.needs["fatigue"] = 60.0
	b.core.advance(10.0)
	await _frames(30)
	await _shot("hungry")
	var scr := InventoryScreen.open_for(player)
	await _frames(60)
	scr.use_item("jerky")
	await _frames(10)
	await _shot("pack")
	scr.close()
	await _frames(10)
	b.core.advance(fposmod(21.5 - SurvivalClock.hour(b.core), 24.0) * 60.0)
	b.core.state.needs["stomach"] = 2300.0          # supper before bed: hunger wakes a sleeper
	b.core.advance(10.0)
	await _frames(40)
	await _shot("night")
	b.sleeper.start()
	await _frames(int(60 * 4.5))
	await _shot("sleep")
	while b.sleeper.sleeping:
		await process_frame
	print("woke: ", b.sleeper.why_woke, " after %.1f h" % b.sleeper.slept_h)
	await _frames(60)
	await _shot("dawn")
	_sheet()
	print("SHOTS DONE ", out)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	var cell := img.duplicate() as Image
	cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	shots.append(cell)
	print("saved %s at %s %s" % [name, SurvivalClock.date_string(b.core), SurvivalClock.time_string(b.core)])


func _sheet() -> void:
	var cols := 3
	var rows := ceili(shots.size() / float(cols))
	var grid := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		grid.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	grid.save_png(out.path_join("sheet.png"))
