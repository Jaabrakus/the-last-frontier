extends SceneTree
## The character creator (CharacterCreator, CreatorOptions, FaceExtras): option data, every
## row cycled (the look and the dressed model), the creator driven by keys and clicks, save
## and restore, and O in the game.
##
##   Godot --headless --path . -s tests/customizer/test_creator.gd
##   Godot --path . --resolution 1280x720 -s tests/customizer/test_creator.gd -- shots=DIR
##
## Exit code 0 and "CREATOR TEST OK" when every check passes. The saved look
## (user://appearance/current.json) is backed up first and restored at the end. Run it under a
## hard time limit like every Godot run (about 60 s headless).
##
## Checks:
##   - data: every people offers every row for both body types (facial hair only for body
##     type 1), every id exists (creator.json tables, hair glbs, body.json eyes), skin swatches
##     reach past the people's melanin range, 10 faces; the documented customs (Eastern
##     Woodlands men plucked; vermilion cheek spots only for Eastern Woodlands and mixed
##     Native women; no tattoo, clan or regalia ids); an emblem for every people
##   - every row of every people and body type cycles through all its choices and back
##     (CreatorOptions.step / current), without touching the other rows
##   - the model: for four peoples and both body types every choice of every row is dressed
##     on a body (PlayerAppearance.dress) and read back: skin, face shapes, hair part and
##     colour, beard shells (part and shader) and painted style, brows, iris, marks,
##     jewellery part (the Earrings, Nose, Neck and Rings rows; tests/customizer/test_jewellery.gd
##     checks the pieces); the beard shells follow the head's face shapes
##   - randomize keeps the people, body type and name; changing the people and body type
##     keeps the name; every row then holds a choice of the new lists
##   - save / restore: the creator keys survive AppearanceStore (name, rows, marks) and
##     current() finds the same choices; broken creator values fall back
##   - the creator UI (no game): keys (down / up / right / left, R, page down), the gamepad
##     (d-pad, Y, shoulders), row arrow and
##     people and body type buttons, the picker, the name field, Back (nothing saved) and
##     Accept (saved); the first-launch offer is off in tool runs
##   - in game: O opens the creator (paused, 3D of the game world off), Accept dresses the
##     player (beard shells, jewellery, marks) and saves; without a saved look the creator
##     opens by itself ("New character") and Back saves the look (no second offer); O again
##     shows the look; Esc closes without changes and unpauses

var _fails: Array[String] = []
var _checks := 0
var _shots := ""
var _backup := ""
var _had_file := false


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _shot(name: String) -> void:
	if _shots.is_empty() or _headless():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/creator_%s.png" % [_shots, name])


func _key(code: Key, shift := false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.shift_pressed = shift
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(2)


func _joy(button: JoyButton) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(2)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			_shots = a.substr(6)
			DirAccess.make_dir_recursive_absolute(_shots)
			if not _headless():
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_had_file = FileAccess.file_exists(AppearanceStore.current_path())
	if _had_file:
		_backup = FileAccess.get_file_as_string(AppearanceStore.current_path())
	_test_data()
	_test_cycle_all()
	await _test_model()
	_test_people_body_random()
	_test_store()
	await _test_ui()
	await _test_game()
	if _had_file:
		var f := FileAccess.open(AppearanceStore.current_path(), FileAccess.WRITE)
		f.store_string(_backup)
		f.close()
	elif FileAccess.file_exists(AppearanceStore.current_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AppearanceStore.current_path()))
	print("CREATOR TEST %s (%d checks%s)" % ["OK" if _fails.is_empty() else "FAILED", _checks,
			"" if _fails.is_empty() else ", %d failed" % _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _look(pid: String, bt: int) -> Dictionary:
	return CreatorOptions.with_body_type(CreatorOptions.with_people({"sex": 1.0 if bt == 1 else 0.0}, pid), bt)


# --- data --------------------------------------------------------------------------------------

func _test_data() -> void:
	var d := CreatorOptions.data()
	_check(d.get("format", "") == "frontier-creator", "creator.json loads")
	var eyes: Dictionary = BodyMaterials.body_info().get("eyes", {})
	var tables := {"facial_hair": d.get("facial_hair", {}), "markings": d.get("markings", {}), "jewellery": d.get("jewellery", {})}
	# every referenced id exists
	var lists := [d.get("defaults", {})]
	lists.append_array((d.get("groups", {}) as Dictionary).values())
	lists.append_array((d.get("peoples", {}) as Dictionary).values())
	var missing := []
	for l: Dictionary in lists:
		for k: String in l:
			var t := k.trim_suffix("_f").trim_suffix("_m")
			if not tables.has(t):
				continue
			for id in l[k]:
				if not (tables[t] as Dictionary).has(id):
					missing.append("%s:%s" % [t, id])
	_check(missing.is_empty(), "every listed id exists (%s)" % [missing])
	for t: String in tables:
		for id: String in tables[t]:
			for bad in ["tattoo", "war", "clan", "feather", "wampum", "bonnet"]:
				_check(not id.contains(bad), "no %s option (%s)" % [bad, id])
	var emblems: Dictionary = d.get("emblems", {})
	for p: Dictionary in CharacterPeoples.peoples():
		var pid := String(p.id)
		var em := PeopleEmblem.new(pid)
		_check(emblems.has(pid) and em.has_method("_e_" + pid), "%s has an emblem" % pid)
		em.free()
		for bt in [1, 2]:
			var lk := _look(pid, bt)
			var rows := CreatorOptions.rows(lk)
			_check(("facial_hair" in rows) == (bt == 1), "%s %d: facial hair row only for body type 1" % [pid, bt])
			for r: String in rows:
				var opts := CreatorOptions.options(r, lk)
				_check(not opts.is_empty(), "%s %d: %s has choices" % [pid, bt, r])
				_check(CreatorOptions.current(r, lk, opts) >= 0, "%s %d: %s holds a choice after with_people" % [pid, bt, r])
			_check(CreatorOptions.options("face", lk).size() == CreatorOptions.FACE_VARIANTS, "%s %d: 10 faces" % [pid, bt])
			var skin := CreatorOptions.options("skin", lk)
			var mel: Array = p.skin.melanin
			var lo := 1.0
			var hi := 0.0
			for o: Dictionary in skin:
				lo = minf(lo, float(o.melanin))
				hi = maxf(hi, float(o.melanin))
			_check(lo <= maxf(float(mel[0]) - 0.07, 0.0) + 1e-3 and hi >= minf(float(mel[1]) + 0.07, 1.0) - 1e-3,
					"%s: skin swatches %.2f-%.2f reach past the range %s" % [pid, lo, hi, mel])
			for o: Dictionary in CreatorOptions.options("hair_style", lk):
				_check(ResourceLoader.exists(BodyMaterials.HAIR_DIR + String(o.id) + ".glb"), "%s: hair %s exists" % [pid, o.id])
			for o: Dictionary in CreatorOptions.options("eyes", lk):
				_check(eyes.has(o.id), "%s: iris %s in body.json" % [pid, o.id])
			var marks := CreatorOptions.options("markings", lk).map(func(o: Dictionary) -> String: return String(o.id))
			var native := String(p.group) == "Eastern Woodlands" or pid in ["metis", "afro_native"]
			_check(("vermilion_cheeks" in marks) == (native and bt == 2),
					"%s %d: vermilion cheek spots only for Eastern Woodlands and mixed Native women" % [pid, bt])
			if String(p.group) == "Eastern Woodlands" and bt == 1:
				var fh := CreatorOptions.options("facial_hair", lk).map(func(o: Dictionary) -> String: return String(o.id))
				_check(fh == ["plucked", "stubble_light"], "%s: men plucked the beard (%s)" % [pid, fh])


# --- cycling ------------------------------------------------------------------------------------

func _test_cycle_all() -> void:
	for p: Dictionary in CharacterPeoples.peoples():
		for bt in [1, 2]:
			var lk := _look(String(p.id), bt)
			for r: String in CreatorOptions.rows(lk):
				var n := CreatorOptions.options(r, lk).size()
				var i0 := CreatorOptions.current(r, lk)
				var others := {}
				for o: String in CreatorOptions.rows(lk):
					if o != r:
						others[o] = CreatorOptions.current(o, lk)
				var ok := true
				for k in n:
					var i := CreatorOptions.step(r, lk, 1)
					if i != posmod(i0 + k + 1, n) or CreatorOptions.current(r, lk) != i:
						ok = false
				_check(ok and CreatorOptions.current(r, lk) == i0, "%s %d: %s cycles through %d choices and back" % [p.id, bt, r, n])
				var same := true
				for o: String in others:
					# the face style changes the Face row's list and shows or hides Complexion (by design)
					if r == "face_style" and o in ["face", "complexion"]:
						continue
					if CreatorOptions.current(o, lk) != others[o]:
						same = false
						print("    %s changed %s" % [r, o])
				_check(same, "%s %d: cycling %s leaves the other rows" % [p.id, bt, r])
				CreatorOptions.step(r, lk, -1)
				_check(CreatorOptions.current(r, lk) == posmod(i0 - 1, n), "%s %d: %s steps back" % [p.id, bt, r])
				CreatorOptions.step(r, lk, 1)


# --- the model ----------------------------------------------------------------------------------

var _stage_inst: Node3D


func _stage_body() -> CharacterBodyMesh:
	_stage_inst = (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_stage_inst)
	var sk := _stage_inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := _stage_inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	return CharacterBodyMesh.attach(sk, ap)


## The skin material of the head (skin.gdshader, or painted_skin.gdshader in the Stylized style).
func _skin_mat(body: CharacterBodyMesh) -> ShaderMaterial:
	var m := _mat(body, "painted_skin.gdshader")
	return m if m else _mat(body, "skin.gdshader")


func _mat(body: CharacterBodyMesh, shader_file: String) -> ShaderMaterial:
	for mi: MeshInstance3D in body.part_meshes("head") + body.part_meshes("hair"):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m and m.shader.resource_path.get_file() == shader_file:
				return m
	return null


func _test_model() -> void:
	var body := _stage_body()
	for pid in ["english", "haudenosaunee", "west_african", "south_asian"]:
		for bt in [1, 2]:
			var lk := _look(pid, bt)
			for r: String in CreatorOptions.rows(lk):
				var opts := CreatorOptions.options(r, lk)
				var bad := []
				for i in opts.size():
					CreatorOptions.select(r, lk, i, opts)
					PlayerAppearance.dress(body, lk)
					var why := _model_matches(body, lk, r, opts[i])
					if not why.is_empty():
						bad.append("%s: %s" % [opts[i].id, why])
				_check(bad.is_empty(), "%s %d: every %s choice on the model %s" % [pid, bt, r, bad])
				CreatorOptions.select(r, lk, 0, opts)
			PlayerAppearance.dress(body, lk)
	# the beard follows the face shapes: the shells carry the head's shapes and values
	var lk := _look("english", 1)
	lk["facial_hair"] = "beard_full"
	PlayerAppearance.dress(body, lk)
	var head := FaceExtras.head_mesh(body)
	var shells: Array = body.part_meshes(FaceExtras.PART_BEARD)
	_check(head != null and shells.size() == 1, "full beard: head and shells")
	if head and shells.size() == 1:
		var sm := shells[0] as MeshInstance3D
		var same: bool = sm.mesh.get_blend_shape_count() == head.mesh.get_blend_shape_count()
		for i in mini(sm.mesh.get_blend_shape_count(), head.mesh.get_blend_shape_count()):
			if not is_equal_approx(sm.get_blend_shape_value(i), head.get_blend_shape_value(i)):
				same = false
		_check(same, "beard shells carry the head's face shape values")
		_check(sm.skin == head.skin, "beard shells share the head's skin")
		var tris := (sm.mesh as ArrayMesh).surface_get_array_index_len(0) / 3
		_check(tris > 5000 and tris <= 40000, "full beard within the fur budget (%d triangles)" % tris)
	# jewellery sits at the ear lobes of the current face
	lk["jewellery"] = "gold_studs"
	lk["sex"] = 1.0
	PlayerAppearance.dress(body, lk)
	var lm := FaceExtras.landmarks(head)
	var jw: Array = body.part_meshes(FaceExtras.PART_JEWELLERY)
	_check(jw.size() == 1 and lm.has("lobe_front_l") and lm.has("lobe_front_r"), "studs: part and ear landmarks")
	if jw.size() == 1 and lm.has("lobe_front_l"):
		# (a stud sits on the front of the lobe, where it is pierced)
		var aabb := (jw[0] as MeshInstance3D).mesh.get_aabb()
		_check(aabb.grow(0.004).has_point(lm.lobe_front_l) and aabb.grow(0.004).has_point(lm.lobe_front_r),
				"studs at both ear lobes (%s, %s in %s)" % [lm.lobe_front_l, lm.lobe_front_r, aabb])
	_stage_inst.queue_free()
	await _frames(2)


## "" when the dressed body shows the row's choice, else what differs.
func _model_matches(body: CharacterBodyMesh, lk: Dictionary, row: String, o: Dictionary) -> String:
	var skin := _skin_mat(body)
	if skin == null:
		return "no skin material"
	match row:
		"face_style":
			var want := "painted_skin.gdshader" if String(o.id) == "stylized" else "skin.gdshader"
			if skin.shader.resource_path.get_file() != want:
				return "skin shader %s" % skin.shader.resource_path.get_file()
			var hm := FaceExtras.head_mesh(body)
			var si := hm.find_blend_shape_by_name(&"style")
			if si < 0 or not is_equal_approx(hm.get_blend_shape_value(si), 1.0 if String(o.id) == "stylized" else 0.0):
				return "style shape"
		"complexion":
			var c: Dictionary = CreatorOptions.data().complexion[o.id]
			if not is_equal_approx(float(skin.get_shader_parameter("lines")), float(c.lines)):
				return "complexion lines"
		"skin":
			if not is_equal_approx(float(skin.get_shader_parameter("melanin")), float(o.melanin)):
				return "melanin"
		"face":
			var hm := FaceExtras.head_mesh(body)
			for k: String in o.face:
				var i := hm.find_blend_shape_by_name(k)
				if i < 0 or absf(hm.get_blend_shape_value(i) - float(o.face[k])) > 1e-4:
					return "shape %s" % k
		"hair_style":
			if String(body.get_meta("hair_style", "")) != String(o.id) or body.part_meshes("hair").is_empty():
				return "hair part"
		"hair_color":
			var hm := _mat(body, "hair.gdshader")
			if hm == null:
				hm = _mat(body, "hair_tex.gdshader")      # hair v2: the textured strand strips
			var pr := BodyMaterials.hair_preset(String(o.id))
			if hm == null or not is_equal_approx(float(hm.get_shader_parameter("eumelanin")), float(pr.eumelanin)):
				return "hair colour"
		"facial_hair":
			var st := CreatorOptions.facial_hair_style(lk)
			var has_shells := not body.part_meshes(FaceExtras.PART_BEARD).is_empty()
			if has_shells != (st.has("regions") and float(st.get("length", 0.0)) > 0.0):
				return "shells %s" % has_shells
			if skin.get_shader_parameter("beard_style") != FaceExtras.style_regions(lk):
				return "painted style"
			if not is_equal_approx(float(skin.get_shader_parameter("stubble")), float(o.get("stubble", 0.0))):
				return "stubble"
			if has_shells:
				var sm := (body.part_meshes(FaceExtras.PART_BEARD)[0] as MeshInstance3D).material_override as ShaderMaterial
				if sm == null or sm.get_shader_parameter("style") != FaceExtras.style_regions(lk):
					return "shell style"
		"eyebrows":
			var fh := _mat(body, "face_hair.gdshader")
			if fh == null or not is_equal_approx(float(fh.get_shader_parameter("brow_thickness")), float(o.thickness)):
				return "brow thickness"
		"eyes":
			var em := _mat(body, "eye.gdshader")
			var want := Color(String(BodyMaterials.body_info().eyes[o.id]))
			if em == null or not (em.get_shader_parameter("iris_color") as Color).is_equal_approx(want):
				return "iris"
		"markings":
			if not is_equal_approx(float(skin.get_shader_parameter("freckles")), float(o.get("freckles", 0.0))) \
					or int(skin.get_shader_parameter("mark_scar")) != int(o.get("scar", 0)) \
					or not is_equal_approx(float(skin.get_shader_parameter("mark_pox")), float(o.get("pox", 0.0))) \
					or not is_equal_approx(float(skin.get_shader_parameter("mark_paint")), float(o.get("paint", 0.0))):
				return "marks"
		"jewellery", "jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands":
			var parts: Array = body.part_meshes(FaceExtras.PART_JEWELLERY)
			var want := not CreatorOptions.jewellery_items(lk).is_empty()
			if (not parts.is_empty()) != want:
				return "part %s" % (not parts.is_empty())
			if want and (parts[0] as MeshInstance3D).mesh.get_surface_count() == 0:
				return "empty jewellery mesh"
	return ""


# --- people, body type, randomize ---------------------------------------------------------------

func _test_people_body_random() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lk := _look("english", 1)
	lk["name"] = "Anne"
	lk["outfit"] = {"outer": {"id": "x"}}
	var a := CreatorOptions.with_people(lk, "lenape")
	_check(a.people == "lenape" and a.name == "Anne" and a.has("outfit") and CreatorOptions.body_type(a) == 1,
			"with_people keeps the name, clothes and body type")
	var b := CreatorOptions.with_body_type(a, 2)
	_check(b.people == "lenape" and b.name == "Anne" and CreatorOptions.body_type(b) == 2 and float(b.stubble) == 0.0,
			"with_body_type keeps people and name, no facial hair on body type 2")
	var seen := {}
	var ok := true
	for i in 30:
		var r := CreatorOptions.randomized(b, rng)
		if r.people != "lenape" or CreatorOptions.body_type(r) != 2 or r.name != "Anne":
			ok = false
		for row: String in CreatorOptions.rows(r):
			if CreatorOptions.current(row, r) < 0:
				ok = false
				print("    random %s custom" % row)
		seen[str(r.face)] = true
	_check(ok, "randomize keeps people, body type and name; every row on a choice")
	_check(seen.size() > 5, "randomize gives different faces (%d of 30)" % seen.size())


# --- store ----------------------------------------------------------------------------------------

func _test_store() -> void:
	var lk := _look("south_asian", 2)
	lk["name"] = "  Priya\n "
	for r in ["markings", "jewel_ears", "jewel_neck", "eyebrows"]:
		CreatorOptions.step(r, lk, 2)
	var want := {}
	for r: String in CreatorOptions.rows(lk):
		want[r] = CreatorOptions.current(r, lk)
	var path := "user://appearance_test/creator.json"
	_check(AppearanceStore.save_file(path, AppearanceStore.validate(lk)), "save a creator look")
	var back := AppearanceStore.load_file(path)
	_check(String(back.get("name", "")) == "Priya", "name cleaned and kept (%s)" % back.get("name"))
	var same := true
	for r: String in want:
		if CreatorOptions.current(r, back) != want[r]:
			same = false
			print("    %s %d -> %d" % [r, want[r], CreatorOptions.current(r, back)])
	_check(same, "every row restored")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": AppearanceStore.FORMAT, "version": 2,
			"look": {"jewellery": "crown_jewels", "facial_hair": 5, "marks": {"scar": 9, "pox": 3}, "name": 12}}))
	f.close()
	var v := AppearanceStore.load_file(path)
	# (an unknown old single jewellery id wears nothing: the rows hold "none", the old key is gone)
	_check(not v.has("jewellery") and v.get("jewel_ears") == "none" and not v.has("facial_hair") and int(v.marks.scar) == 3
			and is_equal_approx(float(v.marks.pox), 1.0) and v.name == "",
			"broken creator values fall back (%s)" % [[v.get("jewel_ears"), v.get("facial_hair"), v.marks, v.name]])
	DirAccess.remove_absolute(path)


# --- the creator UI -----------------------------------------------------------------------------

func _row_text(c: CharacterCreator, row: String) -> String:
	var ui: Dictionary = c._row_ui.get(row, {})
	return "%s %s" % [(ui.value as Label).text, (ui.count as Label).text] if not ui.is_empty() else ""


func _test_ui() -> void:
	_check(not PlayerAppearance.offer_creator(), "no first-launch creator in a tool run")
	if FileAccess.file_exists(AppearanceStore.current_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AppearanceStore.current_path()))
	var c := CharacterCreator.open(null)
	await _frames(5)
	_check(paused and is_instance_valid(c) and root.disable_3d, "the creator pauses and hides the world's 3D")
	c.look = _look("english", 1)
	c._refresh_all()
	c._set_focus("face")
	await _frames(2)
	await _shot("1_open")
	# keys: down from Face to hair style (realistic only since the v3 head: no Face style or
	# Complexion rows), right changes it
	var before := String(c.look.hair.style)
	await _key(KEY_DOWN)
	_check(c.focus_row == "hair_style", "Down focuses the next row, the hair style (%s)" % c.focus_row)
	_check(c.stage.frame_name == "face", "face rows frame the face")
	await _key(KEY_RIGHT)
	_check(String(c.look.hair.style) != before, "Right changes the hair style")
	_check(_row_text(c, "hair_style").begins_with(CreatorOptions.label("hair_style", c.look, CreatorOptions.current("hair_style", c.look))),
			"the row shows the new style (%s)" % _row_text(c, "hair_style"))
	await _key(KEY_LEFT)
	_check(String(c.look.hair.style) == before, "Left changes it back")
	# up to the people row (past face, skin and body type): the camera frames the body; right =
	# next people
	for i in 4:
		await _key(KEY_UP)
	_check(c.focus_row == "people" and c.stage.frame_name == "body", "Up reaches the people row, framed on the body (%s)" % c.focus_row)
	await _key(KEY_RIGHT)
	_check(c.look.people == "scots_irish", "Right on the people row: the next people (%s)" % c.look.people)
	await _key(KEY_PAGEDOWN)
	_check(c.look.people == "french", "Page down: the next people (%s)" % c.look.people)
	# body type row
	await _key(KEY_DOWN)
	await _key(KEY_RIGHT)
	_check(CreatorOptions.body_type(c.look) == 2 and not c._row_ui.has("facial_hair"),
			"body type 2: no facial hair row")
	(c._body_buttons[0] as Button).pressed.emit()
	await _frames(2)
	_check(CreatorOptions.body_type(c.look) == 1 and c._row_ui.has("facial_hair"), "body type 1 button: the facial hair row back")
	# an emblem click
	(c._people_buttons["haudenosaunee"] as Button).pressed.emit()
	await _frames(2)
	_check(c.look.people == "haudenosaunee" and (c._emblems["haudenosaunee"] as PeopleEmblem).selected
			and c._people_name.text == "Haudenosaunee", "emblem click chooses the people")
	# row arrows (the buttons of the markings row)
	var mk_panel: Control = c._row_ui.markings.panel
	var nxt := mk_panel.find_child("Next", true, false) as Button
	var m0 := CreatorOptions.current("markings", c.look)
	nxt.pressed.emit()
	await _frames(2)
	_check(CreatorOptions.current("markings", c.look) == m0 + 1 and c.focus_row == "markings", "the > arrow steps the markings row")
	# every row through the keyboard: one right step each changes the look's row (the face style
	# last: it changes the row list itself)
	c._set_focus("skin")
	var changed := []
	var rows_all: Array = CreatorOptions.rows(c.look)
	for r: String in rows_all:
		if r == "face_style":
			continue
		c._set_focus(r)
		var i0 := CreatorOptions.current(r, c.look)
		var n := CreatorOptions.options(r, c.look).size()
		await _key(KEY_RIGHT)
		if n > 1 and CreatorOptions.current(r, c.look) == posmod(i0 + 1, n):
			changed.append(r)
		elif n == 1:
			changed.append(r)
	_check(changed.size() == rows_all.size(), "Right changes every row (%s)" % [changed])
	_check(not "face_style" in rows_all and not "complexion" in rows_all and BodyMaterials.face_style(c.look) == "realistic",
			"realistic only: no Face style or Complexion row (%s)" % [rows_all])
	# gamepad: d-pad up / right, Y randomizes, the right shoulder the next people
	c._set_focus("hair_color")
	var hc0 := CreatorOptions.current("hair_color", c.look)
	await _joy(JOY_BUTTON_DPAD_UP)
	_check(c.focus_row == "hair_style", "d-pad up focuses the row above (%s)" % c.focus_row)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_check(CreatorOptions.current("hair_color", c.look) == posmod(hc0 + 1, CreatorOptions.options("hair_color", c.look).size()),
			"d-pad right changes the hair colour")
	var pj := String(c.look.people)
	await _joy(JOY_BUTTON_RIGHT_SHOULDER)
	_check(String(c.look.people) != pj, "the right shoulder: the next people (%s)" % c.look.people)
	await _joy(JOY_BUTTON_LEFT_SHOULDER)
	_check(String(c.look.people) == pj, "the left shoulder: back (%s)" % c.look.people)
	# (a random face can repeat, 1 in 10: a few tries)
	var fj := str(c.look.face)
	for k in 4:
		await _joy(JOY_BUTTON_Y)
		if str(c.look.face) != fj:
			break
	_check(str(c.look.face) != fj, "Y randomizes")
	# clothing: with the garments tab in the build (OutfitTab), the Clothing button swaps the rows
	# for the garment rows, frames the whole figure and puts the hat on; a face row goes back
	var has_outfit := false
	for gc: Dictionary in ProjectSettings.get_global_class_list():
		if String(gc.get("class", "")) == "OutfitTab":
			has_outfit = true
	var clothing := c._root.find_child("Clothing", true, false) as Button
	# (the garments are off until the garments pass: PlayerOutfit.ENABLED)
	_check((clothing != null) == (has_outfit and PlayerOutfit.enabled()),
			"a Clothing button exactly when the build has OutfitTab and the garments are on (%s, %s)" % [has_outfit, PlayerOutfit.enabled()])
	if clothing:
		clothing.pressed.emit()
		await _frames(2)
		_check(c._clothing and c._outfit_ui.visible and not c._rows_box.visible and c.stage.frame_name == "body",
				"Clothing shows the garment rows on the whole figure")
		c._set_focus("hair_style")
		await _frames(2)
		_check(not c._clothing and c._rows_box.visible and c.focus_row == "hair_style" and c.stage.frame_name == "face",
				"a face row leaves the clothing view")
	# picker
	c._open_picker("eyes")
	await _frames(2)
	_check(c._picker.visible, "clicking a value opens the picker")
	var btns := c._picker.find_children("*", "Button", true, false)
	var eo := CreatorOptions.options("eyes", c.look)
	_check(btns.size() == eo.size(), "the picker shows every choice (%d)" % btns.size())
	if btns.size() > 1:
		(btns[btns.size() - 1] as Button).pressed.emit()
		await _frames(2)
		_check(CreatorOptions.current("eyes", c.look) == eo.size() - 1 and not c._picker.visible, "a picker choice applies and closes")
	# randomize
	var face0 := str(c.look.face)
	for k in 4:
		await _key(KEY_R)
		if str(c.look.face) != face0:
			break
	_check(str(c.look.face) != face0 and c.look.people == "haudenosaunee", "R randomizes within the people")
	# name
	c._name_edit.grab_focus()
	c._name_edit.text = "Kanerahtens"
	c._name_edit.text_changed.emit("Kanerahtens")
	await _key(KEY_ENTER)
	_check(c.look.get("name", "") == "Kanerahtens" and not c._name_edit.has_focus() and is_instance_valid(c),
			"name typed; Enter leaves the field, not the creator")
	await _frames(20)
	await _shot("2_changed")
	# Back: nothing saved
	await _key(KEY_ESCAPE)
	await _frames(2)
	_check(not is_instance_valid(c) and not paused and not root.disable_3d, "Esc (Back) closes, unpauses, 3D back")
	_check(not FileAccess.file_exists(AppearanceStore.current_path()), "Back saves nothing")
	# Accept saves
	c = CharacterCreator.open(null)
	await _frames(3)
	c.look = _look("japanese", 2)
	c.look["name"] = "Oyo"
	c._refresh_all()
	var accept := c._root.find_child("Accept", true, false) as Button
	accept.pressed.emit()
	await _frames(2)
	_check(not is_instance_valid(c) and FileAccess.file_exists(AppearanceStore.current_path())
			and AppearanceStore.load_file(AppearanceStore.current_path()).get("name", "") == "Oyo", "Accept saves the look")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AppearanceStore.current_path()))


# --- in game ---------------------------------------------------------------------------------------

func _test_game() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(20)
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	var app := player.appearance
	_check(app != null, "player has a PlayerAppearance")
	if app == null:
		return
	_check(not is_instance_valid(app.overlay), "no creator at start in a tool run")
	await _key(KEY_O)
	var c := app.overlay as CharacterCreator
	_check(is_instance_valid(c) and paused, "O opens the creator and pauses")
	if not is_instance_valid(c):
		return
	await _frames(5)
	c.look = _look("west_african", 1)
	for r_id: Array in [["facial_hair", "beard_short"], ["jewel_ears", "gold_studs"], ["markings", "scar_cheek"]]:
		var opts := CreatorOptions.options(r_id[0], c.look)
		CreatorOptions.select(r_id[0], c.look, opts.map(func(o: Dictionary) -> String: return String(o.id)).find(r_id[1]), opts)
	c.look["name"] = "Kofi"
	c._refresh_all()
	c._set_focus("facial_hair")
	await _frames(30)
	await _shot("3_game_creator")
	await _key(KEY_ENTER)
	await _frames(3)
	_check(not is_instance_valid(app.overlay) and not paused, "Enter accepts, closes and unpauses")
	_check(app.look.get("people", "") == "west_african" and app.look.get("facial_hair", "") == "beard_short"
			and app.look.get("name", "") == "Kofi", "the player's look carries the choice")
	_check(not app.body.part_meshes(FaceExtras.PART_BEARD).is_empty() and not app.body.part_meshes(FaceExtras.PART_JEWELLERY).is_empty(),
			"the player wears the beard shells and the studs")
	var skin := _skin_mat(app.body)
	_check(skin != null and int(skin.get_shader_parameter("mark_scar")) == 2, "the player's skin has the cheek scar")
	var saved := AppearanceStore.load_file(AppearanceStore.current_path())
	_check(saved.get("facial_hair", "") == "beard_short" and saved.get("jewel_ears", "") == "gold_studs", "saved")
	await _frames(10)
	await _shot("4_game_player")
	# the first launch: no saved look -> the creator opens by itself ("New character"); Back
	# keeps the look and saves it, so it is not offered again
	var saved_text := FileAccess.get_file_as_string(AppearanceStore.current_path())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AppearanceStore.current_path()))
	_check(PlayerAppearance.offer_creator(false) and not PlayerAppearance.offer_creator(), "offered without a saved look (not in tool runs)")
	await app._offer_creator()
	c = app.overlay as CharacterCreator
	_check(is_instance_valid(c) and c.first_launch and c._title.text == "New character" and paused, "first launch: the creator opens")
	if is_instance_valid(c):
		await _frames(5)
		await _shot("5_first_launch")
		await _key(KEY_ESCAPE)
		await _frames(2)
	_check(not is_instance_valid(app.overlay) and not paused and FileAccess.file_exists(AppearanceStore.current_path())
			and not PlayerAppearance.offer_creator(false), "first launch: Back saves the look, no second offer")
	_check(AppearanceStore.load_file(AppearanceStore.current_path()).get("facial_hair", "") == "beard_short", "first launch: Back keeps the look")
	var fw := FileAccess.open(AppearanceStore.current_path(), FileAccess.WRITE)
	fw.store_string(saved_text)
	fw.close()
	# O again: the creator shows the look; Esc closes without changes
	await _key(KEY_O)
	c = app.overlay as CharacterCreator
	_check(is_instance_valid(c) and _row_text(c, "facial_hair").begins_with("Short beard"), "O again shows the look (%s)" %
			(_row_text(c, "facial_hair") if is_instance_valid(c) else "-"))
	if is_instance_valid(c):
		c.look["facial_hair"] = "clean"
		await _key(KEY_ESCAPE)
		await _frames(2)
		_check(not is_instance_valid(app.overlay) and not paused and app.look.facial_hair == "beard_short", "Esc keeps the applied look")
