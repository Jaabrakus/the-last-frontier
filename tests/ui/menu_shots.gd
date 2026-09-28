extends SceneTree
## Look-check stills of the main menu, its screens, the loading screen and the pause menu (scripts/ui/menu); windowed,
## wrap it in a time limit:
##
##   Godot --path . --resolution 1600x900 -s tests/ui/menu_shots.gd -- out=<abs dir>
##
##   menu.png, new_game.png, load.png, settings.png, credits.png, museum.png, museum_sheet.png, loading.png, pause.png
## Ends with MENU SHOTS DONE.

var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	change_scene_to_file("res://scenes/main_menu.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(30)
	var m := current_scene as MainMenu
	await _shot("menu")
	m._open_new_game()
	await _frames(10)
	await _shot("new_game")
	m._open_load()
	await _frames(10)
	await _shot("load")
	m._open_settings()
	await _frames(10)
	await _shot("settings")
	m._open_credits()
	await _frames(10)
	await _shot("credits")
	m._close_panel()
	m._open_museum()
	await _frames(10)
	await _shot("museum")
	m._museum_show(1)
	await _frames(10)
	await _shot("museum_sheet")
	m._close_museum()
	# the loading screen into a new game
	SaveGame._launched = true
	var ls := LoadingScreen.go(self, "res://scenes/main.tscn")
	await _frames(20)
	await _shot("loading")
	while is_instance_valid(ls):
		await process_frame
	await _frames(60)
	for c in root.find_children("*", "CharacterCreator", true, false):
		c.queue_free()          # (not close(): at a first launch it saves the default look)
	paused = false
	await _frames(30)
	var level := current_scene
	var player := level.get_node_or_null("Player")
	var pm := level.get_node_or_null("PauseMenu") as PauseMenu
	if pm == null:
		pm = PauseMenu.install(level, player)
		await _frames(2)
	pm.open()
	await _frames(10)
	await _shot("pause")
	pm.close()
	print("MENU SHOTS DONE")
	quit(0)
