extends SceneTree
## Windowed screenshots of the classic HUD's frames (ClassicFrames; needs a window, not --headless):
##   classic.png         in play: the musket out, a French marine in the crosshair (the target frame), well rested and wet
##                       (the status icons), Gust on slot 9 readied with its lock half full, the settlers' standing up
##   minimal.png         the same with hud=minimal (the HUD before; minimal_zoom.png its corners)
##   classic_zoom.png    the top left (the player and target frames) and the bottom (the renown and action bars, the
##                       micro menu and the bags) at twice the size
##
##   Godot --path . --resolution 1600x900 -s tests/ui/hud_classic_shots.gd -- survival=on hud=classic out=/abs/dir

var out := ""
var p: FrontierPlayer


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	p = current_scene.get_node("Player")
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close(false)
	paused = false
	await _frames(200)
	var hud: FrontierHUD = p.hud
	var fr := hud.classic
	var tag := "classic" if fr != null else "minimal"
	var b := SurvivalBridge.find(self)
	if b != null and b.core != null:
		b.core.state.flags["well_rested_until"] = b.core.state.minutes + 6.0 * 60.0
		b.core.state.needs["wetness"] = 70.0
		SurvivalEconomy.add_standing(b.core, "faction.settlers_valley", 25.0)
	p.health = p.max_health * 0.72
	var c := SwayCaster.install(p)
	c.grant("gust", false)
	c.set_motes(2)
	p.hotbar.assign(8, Hotbar.make(Hotbar.SPELL, "gust"))
	# a marine 14 m off, standing still, in the crosshair
	var pp := p.global_position
	var fwd := Vector3(-sin(p.yaw), 0.0, -cos(p.yaw))
	var at := pp + fwd * 14.0 + Vector3(fwd.z, 0, -fwd.x) * 1.5
	at.y = FrontierTerrain.height_at(at.x, at.z)
	var sq := NpcSquad.spawn(current_scene, "french_marine", 1, at, {"face": pp, "seed": 5})
	var f: NpcFighter = null
	for i in 90:
		await process_frame
		for n in get_nodes_in_group(NpcFighter.GROUP):
			if n is NpcFighter and (n as NpcFighter).squad == sq:
				f = n
		if f != null:
			break
	await _frames(30)
	if f != null:
		f.set_physics_process(false)
		f.set_process(false)
		f.health = f.health_max * 0.64
		for i in 3:
			var cam := root.get_viewport().get_camera_3d()
			var d := f.global_position + Vector3(0, 1.1, 0) - cam.global_position
			p.yaw = atan2(-d.x, -d.z)
			p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			await _frames(6)
	p.hotbar.select(8)
	await _frames(30)
	c.set_physics_process(false)
	c.state = SwayCaster.State.LOCKING
	c.move = "gust"
	c.target = f
	c.fill = 0.55
	await _frames(120)        # (the portrait's picture is taken a moment in)
	if fr != null:
		print("CLASSIC SHOTS: portrait %s, target %s (%s)" % ["pictured" if fr.player_frame.portrait.texture != null else "stand-in",
				fr.target, fr.target_why])
	var img := await _shot(tag)
	var vp := Vector2(img.get_width(), img.get_height())
	img.convert(Image.FORMAT_RGBA8)
	var top := img.get_region(Rect2i(0, 0, 680, 150))
	top.resize(top.get_width() * 2, top.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	var bw := 1060
	var bot := img.get_region(Rect2i(int(vp.x) - bw, int(vp.y) - 110, bw, 110))
	bot.resize(bot.get_width() * 2, bot.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	var sheet := Image.create(maxi(top.get_width(), bot.get_width()), top.get_height() + bot.get_height() + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	sheet.blit_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i.ZERO)
	sheet.blit_rect(bot, Rect2i(Vector2i.ZERO, bot.get_size()), Vector2i(0, top.get_height() + 8))
	sheet.save_png(out.path_join(tag + "_zoom.png"))
	c.state = SwayCaster.State.IDLE
	c.set_physics_process(true)
	print("CLASSIC SHOTS DONE")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	return img
