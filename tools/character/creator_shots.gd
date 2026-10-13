extends SceneTree
## Screenshots of the character creator (CharacterCreator) for several peoples, both body
## types, framed on the body and on the face, plus close-ups of the facial hair, markings
## and jewellery rows. Needs a window:
##
##   Godot --path . --resolution 1280x720 -s tools/character/creator_shots.gd -- out=DIR
##       [peoples=english,haudenosaunee,...] [set=peoples|styles|emblems|clothing|facestyle|all] [seed=N]
##
## set=facestyle: each people's first face (the showcase face for the East and Southeast Asian
## peoples) on both body types, in the Stylized style and then the Realistic one, and the three
## complexions on one face (<people>_<bt>_stylized.png, _realistic.png, complexion_<id>.png).
##
## The creator opens on its own (no game scene; the saved look is not touched). Each shot
## waits for the camera to settle. Run it under a hard time limit like every Godot run.

var _out := ""
var _peoples := ["english", "haudenosaunee", "west_african", "japanese", "south_asian", "north_african", "metis",
		"shawnee", "korean", "african_american"]
var _set := "all"
var _seed := 7


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("peoples="):
			_peoples = Array(a.substr(8).split(","))
		elif a.begins_with("set="):
			_set = a.substr(4)
		elif a.begins_with("seed="):
			_seed = int(a.substr(5))
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("creator_shots: needs out=DIR and a window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	# a window behind others is throttled by the OS (the shots stall)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, OS.has_environment("TB_ON_TOP"))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(c: CharacterCreator) -> void:
	for i in 240:
		await process_frame
		if c.stage.settled() and i > 20:
			break
	await _frames(4)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("shot ", name)


## Every people's emblem large, with its name and motif (a review sheet).
func _emblem_sheet() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.065, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 10         # 35 peoples in four rows at 1280 x 720
	grid.position = Vector2(12, 12)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	bg.add_child(grid)
	var names: Dictionary = CreatorOptions.data().get("emblems", {})
	for p: Dictionary in CharacterPeoples.peoples():
		var vb := VBoxContainer.new()
		vb.custom_minimum_size = Vector2(116, 0)
		grid.add_child(vb)
		var e := PeopleEmblem.new(String(p.id))
		e.custom_minimum_size = Vector2(112, 112)
		vb.add_child(e)
		var l := Label.new()
		l.text = "%s\n%s" % [p.label, String(names.get(p.id, "")).get_slice(" (", 0)]
		l.add_theme_font_size_override("font_size", 11)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(116, 0)
		vb.add_child(l)
	await _frames(6)
	await _shot("emblems")
	bg.queue_free()
	await _frames(2)


func _run() -> void:
	if _set in ["emblems", "all"]:
		await _emblem_sheet()
	var c := CharacterCreator.open(null)
	await _frames(10)
	# eyes open in every shot
	var blink := c.stage.find_child("FaceBlink", true, false) as FaceBlink
	if blink:
		blink.process_mode = Node.PROCESS_MODE_DISABLED
		blink.set_blink(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	if _set in ["peoples", "all"]:
		for pid: String in _peoples:
			for bt in [1, 2]:
				c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, pid), bt)
				if pid != _peoples[0]:
					c.look = CreatorOptions.randomized(c.look, rng)
				c._refresh_all()
				c._set_focus("people")
				await _settle(c)
				await _shot("%s_%d_body" % [pid, bt])
				c._set_focus("face")
				await _settle(c)
				await _shot("%s_%d_face" % [pid, bt])
	if _set in ["styles", "all"]:
		c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, "english"), 1)
		c._refresh_all()
		c._set_focus("facial_hair")
		await _settle(c)
		for fh in ["stubble", "sideburns", "moustache", "chin_beard", "beard_short", "beard_full"]:
			var opts := CreatorOptions.options("facial_hair", c.look)
			var i := opts.map(func(o: Dictionary) -> String: return String(o.id)).find(fh)
			CreatorOptions.select("facial_hair", c.look, i, opts)
			c._refresh_all()
			await _frames(8)
			await _shot("style_facial_hair_%s" % fh)
			c.stage.set_yaw(0.7)
			await _frames(50)
			await _shot("style_facial_hair_%s_34" % fh)
			c.stage.set_yaw(0.0)
			await _frames(50)
		c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, "palatine"), 1)
		c.look["facial_hair"] = "chin_curtain"
		c._refresh_all()
		c._set_focus("facial_hair")
		await _settle(c)
		await _shot("style_facial_hair_chin_curtain_palatine")
		for pair: Array in [["haudenosaunee", 2, "markings", "vermilion_cheeks"], ["english", 1, "markings", "pox"],
				["english", 1, "markings", "scar_cheek"], ["english", 2, "markings", "scar_brow"],
				["haudenosaunee", 1, "jewellery", "ear_bobs_nose"], ["shawnee", 2, "jewellery", "ear_bobs_several"],
				["south_asian", 2, "jewellery", "studs_nose_stud"], ["english", 2, "jewellery", "pearl_drops"],
				["west_african", 2, "jewellery", "gold_hoops"]]:
			c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, pair[0]), pair[1])
			var opts := CreatorOptions.options(pair[2], c.look)
			var i := opts.map(func(o: Dictionary) -> String: return String(o.id)).find(pair[3])
			CreatorOptions.select(pair[2], c.look, i, opts)
			c._refresh_all()
			c._set_focus(pair[2])
			await _settle(c)
			await _shot("style_%s_%s_%s_%d" % [pair[2], pair[3], pair[0], pair[1]])
		# turned three-quarter for the ears
		c.stage.set_yaw(0.8)
		await _frames(60)
		await _shot("style_jewellery_turned")
	if _set in ["facestyle", "all"]:
		for pid: String in _peoples:
			for bt in [1, 2]:
				c.look["face_style"] = "stylized"
				c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, pid), bt)
				c._refresh_all()
				c._set_focus("face")
				await _settle(c)
				await _shot("%s_%d_stylized" % [pid, bt])
				var fs := CreatorOptions.options("face_style", c.look)
				CreatorOptions.select("face_style", c.look, fs.map(func(o: Dictionary) -> String: return String(o.id)).find("realistic"), fs)
				c._refresh_all()
				c.stage.show_look(c.look)
				await _settle(c)
				await _shot("%s_%d_realistic" % [pid, bt])
		c.look["face_style"] = "stylized"
		c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, _peoples[0]), 1)
		for cx in ["smooth", "lined", "weathered"]:
			c.look["complexion"] = cx
			c._refresh_all()
			c.stage.show_look(c.look)
			c._set_focus("complexion")
			await _settle(c)
			await _shot("complexion_%s" % cx)
	if _set in ["clothing", "all"] and c._outfit_ui != null:
		# the garments view (with the outfit build): a winter outfit, whole figure, hat on; then
		# a face row: bare-headed again
		var presets = c._outfit_ui.get_script().get("PRESETS") if c._outfit_ui.get_script() else null
		c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, "french"), 1)
		if presets is Array and (presets as Array).size() > 1:
			c.look["outfit"] = (presets[1][1] as Dictionary).duplicate(true)
		c._refresh_all()
		c._show_clothing(true)
		await _settle(c)
		await _shot("clothing_on")
		c._set_focus("hair_style")
		await _settle(c)
		await _shot("clothing_face_row")
	c.close(false)
	await _frames(3)
	quit(0)
