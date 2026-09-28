extends SceneTree
## Windowed screenshots of the HUD and the character screen (needs a window, not --headless):
##   hud.png      play with the musket out, a few toasts
##   hud_axe.png  the felling axe out, low health
##   gear.png     Tab: the pack full of what the world gives, an item picked (its stats)
##   skills.png   K: the Skills tab
##   icons.png    every item icon on the pack's cell colour
##
##   Godot --path . --resolution 1600x900 -s tests/ui/ui_shots.gd -- out=/abs/dir

const GIVE := {"blackberries": 6, "strawberries": 9, "plantain": 4, "wintergreen": 3, "ginseng": 1, "acorns": 12,
		"hazelnuts": 7, "venison": 2, "deer_hide": 1, "antler": 2, "fox_pelt": 1, "wolf_pelt": 1, "firewood": 6,
		"stone": 3, "flint": 2, "branches": 5}

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
	var g: GatherTools = p.gather
	for k: String in GIVE:
		g.give(k, int(GIVE[k]))
	await _frames(40)
	await _shot("hud")
	g.take_out("felling_axe")
	p.health = p.max_health * 0.22
	await _frames(90)
	g.skills.award("woodcutting", 3.0)
	g.give("log", 1)
	await _frames(20)
	await _shot("hud_axe")
	g.put_away()
	p.health = p.max_health
	await _frames(40)
	for s in root.find_children("*", "InventoryScreen", true, false):
		s.close()
	var scr := InventoryScreen.open_for(p)
	await _frames(90)
	if scr.has_method("pick"):
		scr.call("pick", "strawberries")
	await _frames(10)
	await _shot("gear")
	if scr.has_method("pick"):
		scr.call("pick", "hazelnuts")
		await _frames(10)
		await _shot("gear_nuts")
		scr.call("pick", "musket")
		await _frames(10)
		await _shot("gear_musket")
	scr.show_tab("skills")
	await _frames(20)
	await _shot("skills")
	scr.close()
	await _frames(10)
	# the Condition tab: a pipe and a gill in, a bleeding wound
	var br := SurvivalBridge.find(self)
	if br and br.vices:
		br.vices.take("tobacco", 1.0)
		br.vices.take("drink", 1.0)
		br.core.advance(40.0)
		var src := Node.new()
		src.set_meta(&"damage_kind", "bleed")
		root.add_child(src)
		p.apply_hit(30.0, p.global_position, Vector3.FORWARD, src, "body")
		await _frames(20)
		scr = InventoryScreen.open_for(p, "condition")
		await _frames(30)
		await _shot("condition")
	scr.close()
	await _frames(10)
	await _icon_sheet()
	print("SHOTS DONE ", out)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		# the creator opens on a first launch (this clone's user dir has no saved look), a little after the level
		for c in root.find_children("*", "CharacterCreator", true, false):
			if not c.is_queued_for_deletion():
				c.close(false)


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("saved ", name)


## Every icon at the pack's cell size on the pack's filled-cell colour, named under it.
func _icon_sheet() -> void:
	var KINDS: Array = InventoryState.NAMES.keys()
	var icons := ItemIcons.shared(self)
	for k: String in KINDS:
		icons.get_icon(k)
	var t := 0
	while t < 1200:
		var done := true
		for k: String in KINDS:
			if not icons._cache.has(k):
				done = false
		if done:
			break
		await process_frame
		t += 1
	var cols := 9
	var cell := 128
	var rows := ceili(KINDS.size() / float(cols))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.06, 0.05, 0.04))
	for i in KINDS.size():
		var at := Vector2i((i % cols) * cell, (i / cols) * cell)
		sheet.fill_rect(Rect2i(at + Vector2i(4, 4), Vector2i(cell - 8, cell - 8)), Color(0.22, 0.18, 0.13))
		var tex: Texture2D = icons._cache.get(KINDS[i])
		if tex == null:
			continue
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(cell - 12, cell - 12, Image.INTERPOLATE_BILINEAR)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at + Vector2i(6, 6))
	sheet.save_png(out.path_join("icons.png"))
	# a few at full size, on the pack's cell colour
	var big := ["musket", "felling_axe", "powder_horn", "strawberries", "wolf_pelt", "venison", "log", "cornmeal"]
	var bs := ItemIcons.SIZE
	var zoom := Image.create(bs * 4, bs * 2, false, Image.FORMAT_RGBA8)
	zoom.fill(Color(0.2, 0.165, 0.12))
	for i in big.size():
		var t2: Texture2D = icons._cache.get(big[i])
		if t2:
			var im := t2.get_image()
			im.convert(Image.FORMAT_RGBA8)
			zoom.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i((i % 4) * bs, (i / 4) * bs))
	zoom.save_png(out.path_join("icons_big.png"))
	print("saved icons (%d)" % KINDS.size())
