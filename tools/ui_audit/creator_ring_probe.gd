extends SceneTree
## Does the ring's player wear the look the creator saved? From the main menu, a match is begun (the sport's panel, Begin)
## with --appearance=<file> standing in for the saved look (AppearanceStore.load_current reads it; nothing is written: the
## settings go to this tool's own file under out=). In the ring, the player's look is compared with that file key by key,
## and stills are taken: the ring camera as the player sees it, and a close camera on the player's head and body.
##
##   GODOT_TIMEOUT=240 zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/creator_ring_probe.gd -- \
##       out=<abs dir> --appearance=<abs path> [el=fire]
## Ends with "RING PROBE DONE".

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")

var out := ""
var el := "fire"
var src := ""
var win := Vector2i(1600, 900)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("el="):
			el = a.substr(3)
		elif a.begins_with("--appearance="):
			src = a.substr(13)
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.path = out.path_join("ring_probe_settings.cfg")
	CaptureKit.window()
	DisplayServer.window_set_size(win)
	change_scene_to_file("res://scenes/main_menu.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	await CaptureKit.frames(self, n)


func _shot(name: String) -> void:
	if CaptureKit.on_top():
		DisplayServer.window_move_to_foreground()
	if DisplayServer.window_get_size() != win:
		DisplayServer.window_set_size(win)
		await _frames(10)
	await CaptureKit.drawn(self)
	root.get_texture().get_image().save_png(out.path_join("ring_" + name + ".png"))
	print("SHOT ring_%s.png" % name)


func _until(cond: Callable, limit_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await process_frame
		if Time.get_ticks_msec() - t0 > limit_s * 1000.0:
			return false
	return true


func _run() -> void:
	await _frames(30)
	var m := current_scene as MainMenu
	MainMenu._look_offered = true
	m._open_match()
	await _frames(3)
	(m._element_rows[el] as Button).pressed.emit()
	await _frames(3)
	var begin := m._panel.find_child("Begin", true, false) as Button
	begin.pressed.emit()
	var ok: bool = await _until(func() -> bool: return current_scene is RingLevel, 60.0)
	if not ok:
		print("RING PROBE: the ring did not load")
		quit(1)
		return
	var lvl := current_scene as RingLevel
	await _until(func() -> bool: return lvl.player != null and lvl.player.arena_element != "" and not LoadingScreen.covering(), 40.0)
	await _frames(30)
	var p: FrontierPlayer = lvl.player
	var saved := AppearanceStore.load_file(src) if src != "" else AppearanceStore.load_current()
	var worn: Dictionary = p.appearance.look if p.appearance else {}
	var same := []
	var differ := []
	for k in saved:
		if JSON.stringify(saved[k]) == JSON.stringify(worn.get(k)):
			same.append(k)
		else:
			differ.append(k)
	print("RING PLAYER LOOK same: %s" % [same])
	print("RING PLAYER LOOK differs: %s" % [differ])
	print("RING outfit worn: %s" % JSON.stringify(worn.get("outfit", {})))
	print("RING outfit saved: %s" % JSON.stringify(saved.get("outfit", {})))
	await _shot("view")
	# a close camera on the player (the ring's own stays as it was)
	var cam := Camera3D.new()
	p.add_child(cam)
	var head := p.global_position + Vector3(0, 1.6, 0)
	var fwd := -p.global_transform.basis.z
	var vis := p.get_node_or_null("Visual") as Node3D
	if vis:
		fwd = vis.global_transform.basis.z
	cam.global_position = head + fwd.normalized() * 1.1 + Vector3(0, 0.05, 0)
	cam.look_at(head, Vector3.UP)
	cam.fov = 35.0
	cam.current = true
	await _frames(6)
	await _shot("player_face")
	cam.global_position = head + fwd.normalized() * 3.2 + Vector3(0, -0.5, 0)
	cam.look_at(p.global_position + Vector3(0, 0.95, 0), Vector3.UP)
	await _frames(6)
	await _shot("player_body")
	print("RING PROBE DONE")
	quit(0)
