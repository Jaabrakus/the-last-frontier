extends SceneTree
## UI audit of the character creator (read-only: it never saves the player's look; a script run's AppearanceStore path is
## the test one, and this tool only writes PNGs, a log and its own round-trip file under out=). It opens the main menu as
## the player does, then the creator the way the menu opens it, and screenshots every row with its camera framing, the
## pickers, the Clothing view, the tattoo editor, the Fine-tune overlay, body type 2, the dice and a few peoples. It prints
## layout checks (panels whose content outgrows them, overlaps) and data checks (rows with one choice or none, rows that read
## "Custom", identical faces, the Clothing view's slots and preset buttons). Needs a window:
##
##   GODOT_TIMEOUT=300 zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/creator_audit.gd -- \
##       out=<abs dir> mode=look|first|small [--appearance=<path>|default]
##
##   mode=look   "Your look" (MainMenu._open_look) on the look --appearance gives (else the test run's saved look)
##   mode=first  the first-run offer before a match (MainMenu._creator(true), what _open_match calls), Back tested
##   mode=small  a few key views only (run it at --resolution 1280x720)
## Ends with "CREATOR AUDIT DONE".

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")

var out := ""
var mode := "look"
## Which parts of the full run (comma list): rows, pickers, clothing, tattoo, finetune, peoples; all by default.
var parts := "all"
## The window size every still is taken at (the OS or another agent's window can resize it: it is set back before a shot).
var win := Vector2i(1600, 900)
var m: MainMenu
var c: CharacterCreator
var _n := 0
const GarmentChest := preload("res://scripts/customizer/garment_chest.gd")


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("mode="):
			mode = a.substr(5)
		elif a.begins_with("part="):
			parts = a.substr(5)
		elif a.begins_with("size="):
			win = Vector2i(int(a.substr(5).get_slice("x", 0)), int(a.substr(5).get_slice("x", 1)))
	if not CaptureKit.begin(self, "creator_audit", out, true, true):
		return
	# (a close request mid-run is logged, not obeyed: the run ends by itself in a few minutes, and a half run left no stills)
	auto_accept_quit = false
	DisplayServer.window_set_size(win)
	change_scene_to_file("res://scenes/main_menu.tscn")
	_run.call_deferred()


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_CLOSE_REQUEST:
		print("  (a close request at %d ms: the audit goes on)" % Time.get_ticks_msec())


func _frames(n: int) -> void:
	await CaptureKit.frames(self, n)


func _part(p: String) -> bool:
	return parts == "all" or p in parts.split(",")


func _settle() -> void:
	var t0 := Time.get_ticks_msec()
	for i in 150:
		await process_frame
		if Time.get_ticks_msec() - t0 > 8000:
			break
		if is_instance_valid(c) and c.stage and c.stage.settled() and i > 20:
			break
	await _frames(4)


## A still of the window. Another agent's always-on-top window can cover this one, and macOS then stops drawing it (no
## frame_post_draw): after 1.5 s without a drawn frame the frame is drawn by hand (RenderingServer.force_draw, a few times for
## the temporal AA) and read back.
func _shot(name: String) -> void:
	# (no window_move_to_foreground: taking the keyboard focus at every still let keys meant for another window close this
	# one; always on top, it is drawn, or drawn by hand below)
	if DisplayServer.window_get_size() != win:
		print("  (window was %s: set back to %s)" % [DisplayServer.window_get_size(), win])
		DisplayServer.window_set_size(win)
		await _frames(10)
	if not await CaptureKit.drawn(self):
		print("  (forced draw for %s: the window was not drawing)" % name)
	_n += 1
	var fn := "%s_%s.png" % [mode, name]
	root.get_texture().get_image().save_png(out.path_join(fn))
	print("SHOT ", fn)


func _rect(ctl: Control) -> String:
	if not is_instance_valid(ctl):
		return "-"
	var r := ctl.get_global_rect()
	return "(%d,%d %dx%d)" % [r.position.x, r.position.y, r.size.x, r.size.y]


## Panels whose content needs more room than they have, and controls that overlap.
func _layout_check(tag: String) -> void:
	var vp := root.get_visible_rect().size
	print("LAYOUT %s viewport %dx%d" % [tag, vp.x, vp.y])
	var named := {"left": c._left_panel, "right": c._right_panel, "name": c._name_edit,
			"back": c._root.find_child("Back", false, false), "accept": c._root.find_child("Accept", false, false),
			"dice": c._root.find_child("Randomize", false, false)}
	if is_instance_valid(c._tattoos):
		named["tattoos"] = c._tattoos
	for k: String in named:
		var ctl := named[k] as Control
		if ctl == null or not ctl.is_visible_in_tree():
			continue
		var need := ctl.get_combined_minimum_size()
		var r := ctl.get_global_rect()
		var flag := ""
		if need.y > r.size.y + 0.5 or need.x > r.size.x + 0.5:
			flag = "  OVERFLOW need %dx%d" % [need.x, need.y]
		if r.end.x > vp.x + 0.5 or r.end.y > vp.y + 0.5 or r.position.x < -0.5 or r.position.y < -0.5:
			flag += "  OFFSCREEN"
		print("  %s %s%s" % [k, _rect(ctl), flag])
	var keys := named.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a := named[keys[i]] as Control
			var b := named[keys[j]] as Control
			if a and b and a.is_visible_in_tree() and b.is_visible_in_tree() and a.get_global_rect().intersects(b.get_global_rect()):
				print("  OVERLAP %s x %s" % [keys[i], keys[j]])
	# labels cut off (clip_text with an ellipsis): the row values
	for r: String in c._row_ui:
		var v := c._row_ui[r].value as Label
		if v and v.is_visible_in_tree():
			var f := v.get_theme_font("font")
			var w := f.get_string_size(v.text, HORIZONTAL_ALIGNMENT_LEFT, -1, v.get_theme_font_size("font_size")).x
			if w > v.size.x + 1.0:
				print("  CLIPPED row %s value '%s' (%d px in %d)" % [r, v.text, w, v.size.x])
	# the people's note: lines and whether the left panel's column has room for it
	if is_instance_valid(c._people_note) and c._people_note.is_visible_in_tree():
		print("  people note lines %d, rect %s" % [c._people_note.get_line_count(), _rect(c._people_note)])


func _rows_state(tag: String) -> void:
	var parts := []
	for r: String in c._row_ui:
		var opts := CreatorOptions.options(r, c.look)
		var i := CreatorOptions.current(r, c.look, opts)
		parts.append("%s=%s(%d/%d)" % [r, CreatorOptions.label(r, c.look, i, opts), i + 1, opts.size()])
	print("ROWS %s people=%s bt=%d: %s" % [tag, String(c.look.get("people", "")), CreatorOptions.body_type(c.look), ", ".join(parts)])


func _no_blink() -> void:
	var blink := c.stage.find_child("FaceBlink", true, false) as FaceBlink
	if blink:
		blink.process_mode = Node.PROCESS_MODE_DISABLED
		blink.set_blink(0.0)


func _find_creator() -> CharacterCreator:
	for n in root.get_children():
		if n is CharacterCreator:
			return n
	return null


func _run() -> void:
	await _frames(40)
	m = current_scene as MainMenu
	if m == null:
		print("AUDIT: the main menu did not load")
		quit(1)
		return
	await _shot("menu")
	var test_path := AppearanceStore.current_path()
	var t_before := FileAccess.get_modified_time(test_path) if FileAccess.file_exists(test_path) else -1
	if mode == "first":
		# exactly what MainMenu._open_match does on the sport's first press with no look saved
		MainMenu._look_offered = true
		m._close_panel()
		c = MainMenu._creator(true)
		c.closed.connect(func(_ok: bool) -> void: m._open_match.call_deferred())
	else:
		m._open_look()
		c = _find_creator()
	if c == null:
		print("AUDIT: no creator opened")
		quit(1)
		return
	await _frames(10)
	_no_blink()
	await _settle()
	print("OPENED title='%s' focus=%s people=%s first=%s" % [c._title.text, c.focus_row, c.look.get("people"), c.first_launch])
	_layout_check("open")
	_rows_state("open")
	await _shot("open")
	if mode == "small":
		await _small()
	else:
		await _full()
	if mode == "first":
		c.close(false)
		await _frames(5)
		var t_after := FileAccess.get_modified_time(test_path) if FileAccess.file_exists(test_path) else -1
		print("FIRST-RUN BACK: saved file %s (modified %d -> %d): %s" % [test_path, t_before, t_after,
				"WROTE" if t_after != t_before else "NOTHING WRITTEN (the offer comes back next launch)"])
		await _frames(20)
		await _shot("after_back")
	else:
		# Accept's save, checked on a file of its own (the player's and the test run's looks untouched)
		var lk := AppearanceStore.validate(c.look)
		var p := out.path_join("accept_roundtrip.json")
		var ok := AppearanceStore.save_file(p, lk)
		var back := AppearanceStore.load_file(p)
		var diffs := []
		for k in lk:
			if JSON.stringify(lk[k]) != JSON.stringify(back.get(k)):
				diffs.append(k)
		print("ROUNDTRIP saved=%s diffs=%s" % [ok, diffs])
		c.close(false)
		await _frames(10)
		await _shot("after_back")
	if mode == "look" and _part("data"):
		_data_checks()
	print("CREATOR AUDIT DONE")
	quit(0)


func _small() -> void:
	c._set_focus("people")
	await _settle()
	_layout_check("people")
	await _shot("people")
	c._set_focus("face")
	await _settle()
	await _shot("face")
	c._set_focus("jewel_hands")
	await _settle()
	_layout_check("rings")
	await _shot("rings_row")
	c._set_focus("face")
	c._open_picker("face")
	await _frames(8)
	await _shot("picker_face")
	c._picker.hide()
	if c._outfit_ui:
		c._show_clothing(true)
		await _settle()
		_layout_check("clothing")
		await _shot("clothing")
		c._show_clothing(false)
		await _settle()
	c._set_focus("tattoos")
	c._open_tattoos()
	await _settle()
	_layout_check("tattoos")
	await _shot("tattoo_editor")
	c._close_tattoos()
	await _settle()
	c._open_fine_tune()
	await _frames(40)
	await _shot("finetune")
	if is_instance_valid(c._fine):
		c._fine.close(false)
	await _frames(10)


func _full() -> void:
	# every row the player walks with Up / Down, with its framing
	var nav: Array = c._nav.duplicate() if _part("rows") else []
	for r: String in nav:
		c._set_focus(r)
		await _settle()
		await _shot("row_" + r)
	_layout_check("rows")
	# the value pickers
	for r: String in ["face", "skin", "hair_style", "hair_color", "jewel_ears", "markings"]:
		if not r in c._row_ui or not _part("pickers"):
			continue
		c._set_focus(r)
		await _settle()
		c._open_picker(r)
		await _frames(8)
		await _shot("picker_" + r)
		c._picker.hide()
		await _frames(2)
	# the Clothing view, its presets and the bottom of its list
	if c._outfit_ui and _part("clothing"):
		c._show_clothing(true)
		await _settle()
		_layout_check("clothing")
		await _shot("clothing")
		var names := []
		for b in c._outfit_ui.find_children("*", "Button", true, false):
			if b is Button and not b is OptionButton and (b as Button).text != "" and (b as Button).get_parent() is HFlowContainer \
					and (b as Button).get_parent().get_index() <= 2:
				names.append((b as Button).text)
		print("CLOTHING presets: %s" % [names])
		var rows := []
		for s: String in PlayerOutfit.SLOTS:
			var ids := PlayerOutfit.offered(s, float(c.look.get("sex", 1.0)))
			rows.append("%s:%d%s" % [s, ids.size(), "" if ids.size() >= 3 else "(hidden)"])
		print("CLOTHING slots offered: %s" % [rows])
		(c._outfit_ui as ScrollContainer).scroll_vertical = 100000
		await _frames(6)
		await _shot("clothing_bottom")
		(c._outfit_ui as ScrollContainer).scroll_vertical = 0
		# a fighters' preset: what it dresses now
		for b in c._outfit_ui.find_children("*", "Button", true, false):
			if b is Button and (b as Button).text == "French marine, campaign":
				(b as Button).pressed.emit()
				await _settle()
				print("CLOTHING 'French marine, campaign' -> %s" % [JSON.stringify(c.look.get("outfit", {}))])
				await _shot("clothing_french_marine")
				break
		c._show_clothing(false)
		await _settle()
	if _part("tattoo"):
		c._set_focus("tattoos")
		c._open_tattoos()
		await _settle()
		_layout_check("tattoos")
		await _shot("tattoo_editor")
		c._close_tattoos()
		await _settle()
	if _part("finetune"):
		await _finetune()
	if _part("chest"):
		await _chest()
	if _part("peoples"):
		await _peoples()
	if _part("faces"):
		await _face_sheet()


## Body type 2 in the look's top (the fire side top when the look wears no shirt): the chest close from the front and
## turned, and the whole figure (the audit's zoom_bt2_chest.png came from that framing), at Average and Full bust; each
## with the cloth over the nipples as built ("_raw", garment_chest.gd off) and as the game now dresses it.
func _chest() -> void:
	c._choose_body(2)
	var o: Dictionary = c.look.get("outfit", {}) if c.look.get("outfit") is Dictionary else {}
	if String((o.get("shirt", {}) as Dictionary).get("id", "")) in ["", "-"]:
		o["shirt"] = {"id": "ring_fire_top", "colors": {}}
		c.look["outfit"] = o
	for b: Array in [[0.0, "avg"], [0.5, "full"]]:
		c.look["bust"] = float(b[0])
		for on in [false, true]:
			GarmentChest.enabled = on
			# (the shirt put on again: a garment already worn keeps its mesh)
			c.stage.body.remove_part("outfit:shirt")
			c._refresh_all()
			c._set_focus("skin")
			# (a close view of the breastbone, as the tattoo editor's: the chest fills the middle of the window)
			c.stage.focus_skin("spinec", Vector3(0.0, 1.15, 0.12), Vector3(0.0, 0.0, 1.0), 0.75)
			await _settle()
			var tag := "" if on else "_raw"
			for v: Array in [[0.0, "front"], [0.75, "side"]]:
				c.stage.set_yaw(float(v[0]))
				await _frames(30)
				await _shot("bt2_chest_%s_%s%s" % [b[1], v[1], tag])
			c.stage.set_yaw(0.0)
			c._set_focus("people")
			await _settle()
			await _shot("bt2_body_%s%s" % [b[1], tag])
	GarmentChest.enabled = true
	c._choose_body(1)
	await _settle()


## The Face row's ten faces side by side, a row per people and body type (left to right Face 1 .. 10): one PNG,
## look_face_sheet.png (the picker shows only "Face N" words).
func _face_sheet() -> void:
	var rows := [["english", 1], ["english", 2], ["vietnamese", 1], ["vietnamese", 2], ["west_african", 1], ["haudenosaunee", 2]]
	var cell := Vector2i(150, 190)
	var sheet := Image.create(cell.x * 10, cell.y * rows.size(), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.05, 0.05, 0.05))
	for ri in rows.size():
		c.look = CreatorOptions.with_body_type(CreatorOptions.with_people(c.look, String(rows[ri][0])), int(rows[ri][1]))
		c._refresh_all()
		c._set_focus("face")
		await _settle()
		var opts := CreatorOptions.options("face", c.look)
		for i in opts.size():
			CreatorOptions.select("face", c.look, i, opts)
			c.stage.show_look(c.look)
			await _frames(20)
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var vp := img.get_size()
			# the face framing: the head a little left of centre, about 40% of the height
			var r := Rect2i(int(vp.x * 0.33), int(vp.y * 0.30), int(vp.x * 0.26), int(vp.y * 0.58))
			var crop := img.get_region(r)
			crop.convert(Image.FORMAT_RGB8)
			crop.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, cell), Vector2i(i * cell.x, ri * cell.y))
		print("FACES row %d: %s bt%d (%d faces)" % [ri, rows[ri][0], rows[ri][1], opts.size()])
	sheet.save_png(out.path_join("%s_face_sheet.png" % mode))
	print("SHOT %s_face_sheet.png" % mode)


func _finetune() -> void:
	c._open_fine_tune()
	await _frames(40)
	if is_instance_valid(c._fine):
		for tc in c._fine.find_children("*", "TabContainer", true, false):
			var t := tc as TabContainer
			for i in t.get_tab_count():
				t.current_tab = i
				await _frames(20)
				await _shot("finetune_" + t.get_tab_title(i).to_lower())
			break
		c._fine.close(false)
	await _frames(10)
	await _settle()


func _peoples() -> void:
	# body type 2, the dice, a few peoples (the Thủy Vân world's Vietnamese, Thai, Malay first)
	c._choose_body(2)
	c._set_focus("people")
	await _settle()
	_rows_state("bt2")
	await _shot("bt2_body")
	c._set_focus("face")
	await _settle()
	await _shot("bt2_face")
	c._randomize()
	await _settle()
	_rows_state("dice")
	await _shot("bt2_dice_face")
	c._choose_body(1)
	for pid: String in ["vietnamese", "haudenosaunee", "west_african", "english"]:
		c._choose_people(pid)
		c._set_focus("people")
		await _settle()
		_layout_check("people_" + pid)
		_rows_state(pid)
		await _shot("people_" + pid)
		c._set_focus("face")
		await _settle()
		await _shot("face_" + pid)


## Data checks over every listed people and both body types (no nodes).
func _data_checks() -> void:
	var one := {}
	var custom := {}
	var dup_faces := []
	for p: Dictionary in CharacterPeoples.listed_peoples():
		for bt in [1, 2]:
			var lk := CreatorOptions.with_body_type(CreatorOptions.with_people(AppearanceStore.default_look(), String(p.id)), bt)
			for r: String in CreatorOptions.rows(lk):
				var opts := CreatorOptions.options(r, lk)
				if opts.size() <= 1:
					one["%s/%s" % [r, opts.size()]] = int(one.get("%s/%s" % [r, opts.size()], 0)) + 1
				if r != "tattoos" and CreatorOptions.current(r, lk, opts) < 0:
					custom["%s" % r] = (custom.get(r, []) as Array) + ["%s_%d" % [p.id, bt]]
			var faces := CreatorOptions.options("face", lk)
			var seen := {}
			for f: Dictionary in faces:
				seen[JSON.stringify(f.face)] = true
			if seen.size() < faces.size():
				dup_faces.append("%s_%d: %d of %d distinct" % [p.id, bt, seen.size(), faces.size()])
	print("DATA rows with <=1 choice (row/count: peoples x bt): %s" % [one])
	print("DATA rows reading Custom right after choosing the people: %s" % [custom])
	print("DATA duplicate faces: %s" % [dup_faces])
	print("DATA peoples listed: %d in %d groups" % [CharacterPeoples.listed_peoples().size(), CharacterPeoples.listed_groups().size()])
	for sx in [1.0, 0.0]:
		var names := []
		for pr: Array in OutfitTab.presets(sx):
			names.append(String(pr[0]) + " " + JSON.stringify(pr[1]))
		print("DATA outfit presets sex=%s: %s" % [sx, names])
