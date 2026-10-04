extends SceneTree
## Screenshots of the game's own peoples in the character creator (data/customizer/world_peoples.json; the owner
## 2026-10-03, "yea lets test it"): their emblems, then each people on both body types, in its lineup outfit (the
## people's `lineup_outfit`, an OutfitTab preset: only for these shots, a new character still starts in the basic
## dress), framed on the body, on the face and, for a people with a mark in the skin, on the mark; then `extra`
## more individuals of each (the dice). Needs a window:
##
##   Godot --path . --resolution 1280x720 -s tools/character/world_peoples_shots.gd -- peoples=world out=DIR [extra=2] [seed=N]
##       [only=keelfolk,etched] [emblems=0]
##
## The creator opens on its own (no game scene; the saved look is not touched).

var _out := ""
var _extra := 2
var _seed := 5
var _only: Array = []
var _emblem_sheet := true


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("extra="):
			_extra = int(a.substr(6))
		elif a.begins_with("seed="):
			_seed = int(a.substr(5))
		elif a.begins_with("only="):
			_only = Array(a.substr(5).split(","))
		elif a == "emblems=0":
			_emblem_sheet = false
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("world_peoples_shots: needs out=DIR and a window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
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


func _emblems() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.065, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(40, 40)
	row.add_theme_constant_override("separation", 30)
	bg.add_child(row)
	for p: Dictionary in CharacterPeoples.listed_peoples():
		var vb := VBoxContainer.new()
		vb.custom_minimum_size = Vector2(260, 0)
		row.add_child(vb)
		var e := PeopleEmblem.new(String(p.id))
		e.custom_minimum_size = Vector2(240, 240)
		vb.add_child(e)
		var l := Label.new()
		l.text = "%s\n%s\n%s" % [p.label, p.group, CreatorOptions.emblem_name(String(p.id))]
		l.add_theme_font_size_override("font_size", 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(260, 0)
		vb.add_child(l)
	await _frames(6)
	await _shot("emblems")
	bg.queue_free()
	await _frames(2)


func _dress(look: Dictionary, pid: String) -> void:
	var want := String(CharacterPeoples.people(pid).get("lineup_outfit", ""))
	for pr: Array in OutfitTab.presets(float(look.get("sex", 0.0))):
		if String(pr[0]) == want:
			look["outfit"] = (pr[1] as Dictionary).duplicate(true)
			return
	look.erase("outfit")


func _run() -> void:
	if _emblem_sheet:
		await _emblems()
	var c := CharacterCreator.open(null)
	await _frames(10)
	var blink := c.stage.find_child("FaceBlink", true, false) as FaceBlink
	if blink:
		blink.process_mode = Node.PROCESS_MODE_DISABLED
		blink.set_blink(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	for p: Dictionary in CharacterPeoples.listed_peoples():
		var pid := String(p.id)
		if not _only.is_empty() and not pid in _only:
			continue
		for bt in [1, 2]:
			for k in _extra + 1:
				c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, pid), bt)
				if k > 0:
					c.look = CreatorOptions.randomized(c.look, rng)
				_dress(c.look, pid)
				c._refresh_all()
				c.stage.show_look(c.look)
				c._set_focus("people")
				await _settle(c)
				await _shot("%s_%d_%d_body" % [pid, bt, k])
				c._set_focus("face")
				await _settle(c)
				await _shot("%s_%d_%d_face" % [pid, bt, k])
				if k == 0 and "trait" in CreatorOptions.rows(c.look):
					c._set_focus("trait")
					await _settle(c)
					await _shot("%s_%d_%d_mark" % [pid, bt, k])
	c.close(false)
	await _frames(3)
	quit(0)
