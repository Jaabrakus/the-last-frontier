extends SceneTree
## The detailed customizer (the character creator's Fine-tune) driven like a player: key and
## mouse events on the real game (main.tscn), then the look on the player, on disk and on the
## inventory doll. (tests/customizer/test_creator.gd drives the creator's own rows.) Windowed,
## the clicks warp the OS pointer to their target; leave the pointer alone while it runs
## (another process moving it can steal a click).
##
##   Godot --headless --path . -s tests/customizer/test_customizer_ui.gd
##   Godot --path . --resolution 1280x720 -s tests/customizer/test_customizer_ui.gd -- shots=DIR
##
## Exit code 0 and "CUSTOMIZER UI TEST OK" when every check passes. With a window the
## buttons and the hair list get real mouse clicks and shots=DIR saves a screenshot of each
## step; headless (no mouse routing) the same controls get their pressed / item_selected
## signals instead. The saved look (user://appearance/current.json) is backed
## up first and restored at the end. Run it under a hard time limit like every Godot run.
##
## Steps: O opens the creator (tree paused), its Fine-tune button the overlay on the creator's
## look; group and people picked (the option button and list signals), a preset button clicked
## with the mouse; Skin tab: the Tone 12 swatch clicked; Face tab: a slider moved; Hair tab: a
## style clicked in the list; Apply clicked: the overlay closes back to the creator (still
## paused) with the choice; Accept clicked: the creator closes and unpauses, the player's look,
## head skin material, hair part and the saved file carry the choice; O again and Fine-tune:
## the overlay shows it; Esc closes the overlay, Esc again the creator, without changes; Tab
## opens the inventory, whose doll wears the look.

var _fails: Array[String] = []
var _checks := 0
var _shots := ""
var _backup := ""


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if _shots.is_empty() or _headless():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/ui_%s.png" % [_shots, name])


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(2)


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _click(c: Control) -> void:
	if _headless() and c is BaseButton:
		(c as BaseButton).pressed.emit()
		await _frames(2)
		return
	await _click_at(c.get_global_rect().get_center())


func _click_at(p: Vector2) -> void:
	for pressed in [true, false]:
		# the pointer moves there first: a button takes a click only under the hovered pointer,
		# and the OS pointer over the window sends its own motion (it is warped there too)
		if not _headless():
			Input.warp_mouse(p)
		var m := InputEventMouseMotion.new()
		m.position = p
		m.global_position = p
		Input.parse_input_event(m)
		await _frames(3)
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		Input.parse_input_event(e)
		await _frames(2)


## Clicks the creator's Fine-tune button; returns the overlay it opens.
func _fine_tune(cr: CharacterCreator) -> CustomizerOverlay:
	var fine: Button = null
	for b in cr.find_children("*", "Button", true, false):
		if (b as Button).text == "Fine-tune...":
			fine = b
	_check(fine != null, "the creator has a Fine-tune button")
	if fine == null:
		return null
	# windowed, another process (or a person) moving the OS pointer can steal a click: retry
	for attempt in 3:
		await _click(fine)
		await _frames(5)
		if is_instance_valid(cr._fine):
			break
		var hov := root.gui_get_hovered_control()
		print("  Fine-tune click missed; under the pointer: %s, OS pointer at %s" % [hov.get_path() if hov else "nothing", root.get_mouse_position()])
	return cr._fine


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			_shots = a.substr(6)
			DirAccess.make_dir_recursive_absolute(_shots)
			if not _headless():
				# a window behind others is throttled by the OS
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	if FileAccess.file_exists(AppearanceStore.current_path()):
		_backup = FileAccess.get_file_as_string(AppearanceStore.current_path())
	await _run()
	# restore the saved look
	if _backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AppearanceStore.current_path()))
	else:
		var f := FileAccess.open(AppearanceStore.current_path(), FileAccess.WRITE)
		f.store_string(_backup)
		f.close()
	print("CUSTOMIZER UI TEST %s (%d checks%s)" % ["OK" if _fails.is_empty() else "FAILED", _checks,
			"" if _fails.is_empty() else ", %d failed" % _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(20)
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	var app := player.appearance
	_check(app != null, "player has a PlayerAppearance")
	if app == null:
		return
	# --- O opens the creator, Fine-tune the overlay
	await _key(KEY_O)
	var cr := app.overlay as CharacterCreator
	_check(is_instance_valid(cr) and paused, "O opens the creator and pauses the game")
	if not is_instance_valid(cr):
		return
	await _frames(5)
	var ov := await _fine_tune(cr)
	_check(is_instance_valid(ov) and paused and not cr.visible, "Fine-tune opens the overlay over the hidden creator")
	if not is_instance_valid(ov):
		return
	await _frames(5)
	await _shot("1_open")
	# --- People: East Asia / Japanese, first preset of the current body fit (clicked)
	var gi := CharacterPeoples.groups().find("East Asia")
	ov._group_opt.select(gi)
	ov._group_opt.item_selected.emit(gi)
	var pi := -1
	for i in ov._people_list.item_count:
		if ov._people_list.get_item_metadata(i) == "japanese":
			pi = i
	_check(pi >= 0, "Japanese listed under East Asia")
	ov._people_list.select(pi)
	ov._people_list.item_selected.emit(pi)
	await _frames(3)
	var buttons := ov._presets_box.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	_check(buttons.size() == 2, "two presets for the body fit (%d)" % buttons.size())
	if buttons.is_empty():
		return
	var want_sex := 1.0 if float(ov.look.get("sex", 0.0)) >= 0.5 else 0.0
	var want_preset := String(CharacterPeoples.presets("japanese", want_sex)[0].id)
	await _click(buttons[0] as Control)
	_check(String(ov.look.get("preset", "")) == want_preset, "preset clicked: %s (%s)" % [want_preset, ov.look.get("preset", "")])
	await _frames(3)
	await _shot("2_preset")
	var tabs := ov.find_children("*", "TabContainer", true, false)[0] as TabContainer
	# --- Skin: Tone 12 swatch
	tabs.current_tab = 2
	await _frames(3)
	var tone12: Button = null
	for b in tabs.get_current_tab_control().find_children("*", "Button", true, false):
		if (b as Button).text == "12":
			tone12 = b
	_check(tone12 != null and tone12.is_visible_in_tree(), "Tone 12 swatch shown")
	if tone12:
		await _click(tone12)
	_check(is_equal_approx(float(ov.look.get("melanin", 0.0)), 1.0), "Tone 12 clicked: melanin 1 (%s)" % ov.look.get("melanin"))
	await _shot("3_skin")
	# --- Face: a slider
	tabs.current_tab = 1
	await _frames(3)
	var s: HSlider = ov._sliders.get("face_nose_width")
	_check(s != null and s.is_visible_in_tree(), "nose width slider shown")
	if s:
		s.value = -0.6
	_check(ov.look.get("face") is Dictionary and is_equal_approx(float(ov.look.face.get("face_nose_width", 0.0)), -0.6),
			"slider sets face_nose_width")
	await _shot("4_face")
	# --- Hair: click a style in the list
	tabs.current_tab = 4
	await _frames(3)
	var hl := ov._hair_list
	var hi := -1
	for i in hl.item_count:
		if hl.get_item_metadata(i) == "hair_long_loose":
			hi = i
	_check(hi >= 0, "hair_long_loose listed")
	if hi >= 0 and _headless():
		hl.select(hi)
		hl.item_selected.emit(hi)
	elif hi >= 0:
		# scroll the style into view first, as a player would (the list shows about 8 of 15
		# styles; where it starts depends on the saved look's style)
		var r := hl.get_item_rect(hi)
		var sb := hl.get_v_scroll_bar()
		sb.value = r.get_center().y - hl.size.y * 0.5
		await _frames(3)
		await _click_at(hl.get_global_transform() * (r.get_center() - Vector2(0, sb.value)))
	_check(String((ov.look.get("hair", {}) as Dictionary).get("style", "")) == "hair_long_loose",
			"hair style clicked (%s)" % (ov.look.get("hair", {}) as Dictionary).get("style", ""))
	await _frames(3)
	await _shot("5_hair")
	# --- Apply
	var apply_b: Button = null
	for b in ov.find_children("*", "Button", true, false):
		if (b as Button).text == "Apply":
			apply_b = b
	await _click(apply_b)
	await _frames(3)
	_check(not is_instance_valid(cr._fine) and cr.visible and paused, "Apply returns to the creator, still paused")
	_check(String(cr.look.get("preset", "")) == want_preset and is_equal_approx(float(cr.look.melanin), 1.0),
			"the creator holds the fine-tuned look")
	await _frames(3)
	await _shot("5b_creator")
	await _click(cr._root.find_child("Accept", true, false) as Button)
	await _frames(3)
	_check(not is_instance_valid(app.overlay) and not paused, "Accept closes and unpauses")
	var lk := app.look
	_check(String(lk.get("preset", "")) == want_preset and is_equal_approx(float(lk.melanin), 1.0)
			and String(lk.hair.style) == "hair_long_loose" and is_equal_approx(float(lk.face.get("face_nose_width", 0.0)), -0.6),
			"the player's look carries the choice")
	var skin_ok := false
	for mi: MeshInstance3D in app.body.part_meshes("head"):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m and m.shader.resource_path.ends_with("skin.gdshader"):
				skin_ok = is_equal_approx(float(m.get_shader_parameter("melanin")), 1.0)
		var nw := mi.find_blend_shape_by_name(&"face_nose_width")
		if nw >= 0:
			_check(is_equal_approx(mi.get_blend_shape_value(nw), -0.6), "%s: face_nose_width on the player" % mi.name)
	_check(skin_ok, "the player's head skin has melanin 1")
	_check(String(app.body.get_meta("hair_style", "")) == "hair_long_loose" and not app.body.part_meshes("hair").is_empty(),
			"the player's hair part is the new style")
	var saved := AppearanceStore.load_file(AppearanceStore.current_path())
	_check(String(saved.get("preset", "")) == want_preset and is_equal_approx(float(saved.melanin), 1.0),
			"saved to %s" % AppearanceStore.current_path())
	await _frames(10)
	await _shot("6_applied")
	# --- O again shows the look; Esc closes without changes
	await _key(KEY_O)
	cr = app.overlay as CharacterCreator
	_check(is_instance_valid(cr), "O opens it again")
	if is_instance_valid(cr):
		await _frames(3)
		ov = await _fine_tune(cr)
	if is_instance_valid(ov):
		_check(ov._group_opt.get_item_text(ov._group_opt.selected) == "East Asia", "reopened on the chosen group")
		_check(is_equal_approx((ov._sliders.melanin as HSlider).value, 1.0), "reopened with the chosen tone")
		ov.look.melanin = 0.2
		await _key(KEY_ESCAPE)
		await _frames(2)
		_check(not is_instance_valid(ov) and is_instance_valid(cr) and cr.visible and paused, "Esc closes the overlay back to the creator")
		_check(is_equal_approx(float(cr.look.melanin), 1.0), "the overlay's Esc keeps the creator's look")
		await _key(KEY_ESCAPE)
		await _frames(2)
		_check(not is_instance_valid(app.overlay) and not paused, "Esc closes the creator and unpauses")
		_check(is_equal_approx(float(app.look.melanin), 1.0), "Esc keeps the applied look")
	# --- the inventory doll wears the look
	await _key(KEY_TAB)
	await _frames(5)
	var inv: Node = null
	for c in root.get_children():
		if c is InventoryScreen:
			inv = c
	_check(inv != null, "Tab opens the inventory")
	if inv:
		var doll: CharacterBodyMesh = inv.get("_body")
		var doll_ok := false
		if doll:
			for mi: MeshInstance3D in doll.part_meshes("head"):
				for i in mi.mesh.get_surface_count():
					var m := mi.get_surface_override_material(i) as ShaderMaterial
					if m and m.shader.resource_path.ends_with("skin.gdshader"):
						doll_ok = is_equal_approx(float(m.get_shader_parameter("melanin")), 1.0)
		_check(doll_ok, "the inventory doll wears the look")
		await _frames(5)
		await _shot("7_inventory")
		await _key(KEY_TAB)
		await _frames(2)
