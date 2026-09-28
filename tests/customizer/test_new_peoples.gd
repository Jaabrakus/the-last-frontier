extends SceneTree
## The peoples added on 2026-09-27 (the user: "middle eastern people", "the moor people", "the spanish as
## well", "egpytian and ehtiopian, Ottoman Turkish, Persian, Arab, Armenian" and "what every else was
## during that time period"): Spanish (Europe); the Middle East group (Levantine moved in, Ottoman
## Turkish, Persian, Arab, Armenian, Kurdish); the North Africa group (North African, now the Amazigh,
## Moorish (Morocco), Egyptian); Ethiopian (Africa). The old "West Asia and North Africa" group is gone.
## Headless, about 20 s.
##
##   Godot --headless --path . -s tests/customizer/test_new_peoples.gd
##   Godot --path . --resolution 1280x720 -s tests/customizer/test_new_peoples.gd -- shots=DIR
##
## Exit code 0 and "NEW PEOPLES TEST OK" when every check passes; 1 and the failures otherwise.
## The saved look (user://appearance/current.json) is backed up first and restored at the end.
## Run it under a hard time limit like every Godot run.
##
## Checks:
##   - peoples.json: the group order and members; label, note, skin range, eyes and hair colours of
##     each new people; no face feature past 0.9; two realistic and four stylized faces per body type
##   - facial hair: the men's faces of the peoples whose men wore a moustache or a beard carry one
##     (a creator.json id), with_people puts it on the look and the Facial hair row shows it; the
##     women carry none; face 1 of the Middle Eastern and North African peoples has the people's
##     commonest hair colour
##   - creator rows: an emblem each; nose rings offered to Arab, Kurdish and Egyptian women, no
##     earrings for Ethiopian men; every jewellery id exists
##   - the model: every face and hair style choice of both body types in both face styles dressed on
##     a body (face shapes, hair part, facial hair shells for the bearded)
##   - save / restore: a look of each new people round-trips with every row (the facial hair too)
##   - the creator UI: a button per people, six on the widest rows inside the panel, the panel inside
##     its space with the longest note shown; choosing a people names it and shows its note

const NEW := ["spanish", "ottoman_turkish", "persian", "arab", "armenian", "kurdish", "moorish", "egyptian", "ethiopian"]
const GROUPS := ["Europe", "Eastern Woodlands", "Africa", "East Asia", "South Asia", "Southeast Asia", "Middle East",
		"North Africa", "Mixed ancestry"]
const MIDDLE_EAST := ["levantine", "ottoman_turkish", "persian", "arab", "armenian", "kurdish"]
const NORTH_AFRICA := ["north_african", "moorish", "egyptian"]
## Peoples whose men's faces carry a moustache or a beard.
const BEARDED := ["ottoman_turkish", "persian", "arab", "armenian", "kurdish", "moorish", "egyptian"]
const FACIAL_HAIR := ["moustache", "beard_short", "chin_beard"]

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
	root.get_texture().get_image().save_png("%s/new_%s.png" % [_shots, name])


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			_shots = a.substr(6)
			DirAccess.make_dir_recursive_absolute(_shots)
			if not _headless():
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_had_file = FileAccess.file_exists(AppearanceStore.CURRENT)
	if _had_file:
		_backup = FileAccess.get_file_as_string(AppearanceStore.CURRENT)
	_test_peoples()
	_test_facial_hair()
	_test_rows()
	await _test_model()
	_test_store()
	await _test_ui()
	if _had_file:
		var f := FileAccess.open(AppearanceStore.CURRENT, FileAccess.WRITE)
		f.store_string(_backup)
		f.close()
	elif FileAccess.file_exists(AppearanceStore.CURRENT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AppearanceStore.CURRENT))
	print("NEW PEOPLES TEST %s (%d checks%s)" % ["OK" if _fails.is_empty() else "FAILED", _checks,
			"" if _fails.is_empty() else ", %d failed" % _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _look(pid: String, bt: int, style := "stylized") -> Dictionary:
	return CreatorOptions.with_people({"sex": 1.0 if bt == 1 else 0.0, "face_style": style}, pid)


func _ids(list: Array) -> Array:
	return list.map(func(p: Dictionary) -> String: return String(p.id))


# --- peoples ----------------------------------------------------------------------------------------

func _test_peoples() -> void:
	_check(CharacterPeoples.groups() == GROUPS, "the groups in order (%s)" % [CharacterPeoples.groups()])
	_check(_ids(CharacterPeoples.peoples("Middle East")) == MIDDLE_EAST,
			"Middle East: %s" % [_ids(CharacterPeoples.peoples("Middle East"))])
	_check(_ids(CharacterPeoples.peoples("North Africa")) == NORTH_AFRICA,
			"North Africa: %s" % [_ids(CharacterPeoples.peoples("North Africa"))])
	_check(_ids(CharacterPeoples.peoples("Europe")).back() == "spanish", "Spanish last in Europe")
	_check(_ids(CharacterPeoples.peoples("Africa")).back() == "ethiopian", "Ethiopian last in Africa")
	_check(CharacterPeoples.peoples().size() == 35, "35 peoples (%d)" % CharacterPeoples.peoples().size())
	_check(String(CharacterPeoples.people("north_african").get("note", "")).begins_with("Amazigh"),
			"North African: the Amazigh now that the Moors are their own people")
	var labels := {"spanish": "Spanish", "ottoman_turkish": "Ottoman Turkish", "persian": "Persian", "arab": "Arab",
			"armenian": "Armenian", "kurdish": "Kurdish", "moorish": "Moorish (Morocco)", "egyptian": "Egyptian",
			"ethiopian": "Ethiopian"}
	for pid: String in NEW:
		var p := CharacterPeoples.people(pid)
		_check(String(p.get("label", "")) == labels[pid], "%s: label %s" % [pid, p.get("label")])
		_check(String(p.get("note", "")).length() > 60, "%s: a period note" % pid)
		_check(not p.has("licence_note"), "%s: no licence note (only the East, South and Southeast Asian peoples)" % pid)
		var mel: Array = p.skin.melanin
		_check(float(mel[0]) >= 0.0 and float(mel[1]) <= 1.0 and float(mel[1]) - float(mel[0]) >= 0.3,
				"%s: a wide skin range %s" % [pid, mel])
		var eyes := 0.0
		for v in (p.eyes as Dictionary).values():
			eyes += float(v)
		_check(absf(eyes - 1.0) < 0.02, "%s: eye colours sum to 1 (%.2f)" % [pid, eyes])
		var hair := 0.0
		for v in (p.hair_colors as Dictionary).values():
			hair += float(v)
		_check(absf(hair - 1.0) < 0.02, "%s: hair colours sum to 1 (%.2f)" % [pid, hair])
		var past := []
		for k: String in (p.face_mean as Dictionary):
			if absf(float(p.face_mean[k])) > 0.9:
				past.append(k)
		_check(past.is_empty(), "%s: no face feature past 0.9 %s" % [pid, past])
		for sex in [0.0, 1.0]:
			_check(CharacterPeoples.presets(pid, sex).size() == 2 and CharacterPeoples.stylized_presets(pid, sex).size() == 4,
					"%s %s: two realistic and four stylized faces" % [pid, sex])
	_check(float(CharacterPeoples.people("ethiopian").skin.melanin[0]) >= 0.5, "Ethiopian: medium to dark brown skin")
	_check(String(CharacterPeoples.people("ethiopian").hair_texture) == "curly", "Ethiopian: curly hair")


# --- facial hair ------------------------------------------------------------------------------------

func _test_facial_hair() -> void:
	var table: Dictionary = CreatorOptions.data().get("facial_hair", {})
	for pid: String in NEW:
		for pr: Dictionary in CharacterPeoples.presets(pid) + CharacterPeoples.stylized_presets(pid):
			var man := float(pr.sex) > 0.5
			if pid in BEARDED and man:
				_check(String(pr.get("facial_hair", "")) in FACIAL_HAIR and table.has(String(pr.facial_hair)),
						"%s: the man's face carries a moustache or beard (%s)" % [pr.id, pr.get("facial_hair")])
			else:
				_check(not pr.has("facial_hair"), "%s: no facial hair set" % pr.id)
		for style in ["stylized", "realistic"]:
			var lk := _look(pid, 1, style)
			var pr := CharacterPeoples.preset(String(lk.get("preset", "")))
			if pid in BEARDED:
				_check(String(lk.get("facial_hair", "")) == String(pr.get("facial_hair", "-")),
						"%s %s: the look wears the face's %s (%s)" % [pid, style, pr.get("facial_hair"), lk.get("facial_hair")])
				var opts := CreatorOptions.options("facial_hair", lk)
				var i := CreatorOptions.current("facial_hair", lk)
				_check(i >= 0 and String(opts[i].id) == String(lk.facial_hair), "%s %s: the Facial hair row shows it" % [pid, style])
				_check(is_equal_approx(float(lk.get("stubble", -1.0)), float((table[String(lk.facial_hair)] as Dictionary).get("stubble", 0.0))),
						"%s %s: the stubble of the style" % [pid, style])
			_check(String(_look(pid, 2, style).get("facial_hair", "")) == "", "%s %s: none on the women" % [pid, style])
		var p := CharacterPeoples.people(pid)
		if String(p.group) in ["Middle East", "North Africa"]:
			var hc: Dictionary = p.hair_colors
			var top := ""
			for c: String in hc:
				if top.is_empty() or float(hc[c]) > float(hc[top]) or (is_equal_approx(float(hc[c]), float(hc[top])) and c < top):
					top = c
			for sx in ["f", "m"]:
				var s1 := CharacterPeoples.preset("%s_%s_s1" % [pid, sx])
				_check(String(s1.hair.color) == top, "%s %s: face 1 in the commonest hair colour %s (%s)" % [pid, sx, top, s1.hair.color])


# --- creator rows -----------------------------------------------------------------------------------

func _test_rows() -> void:
	var d := CreatorOptions.data()
	var jw_ids: Dictionary = d.get("jewellery", {})
	_check(not (d.get("groups", {}) as Dictionary).has("West Asia and North Africa"), "the old group is gone from creator.json")
	for g in ["Middle East", "North Africa"]:
		_check((d.get("groups", {}) as Dictionary).has(g), "creator.json has the %s group" % g)
	for pid: String in NEW:
		var em := PeopleEmblem.new(pid)
		_check(String((d.get("emblems", {}) as Dictionary).get(pid, "")).length() > 4 and em.has_method("_e_" + pid),
				"%s has an emblem" % pid)
		em.free()
		for bt in [1, 2]:
			var jw: Array = CreatorOptions.options("jewellery", _look(pid, bt)).map(func(o: Dictionary) -> String: return String(o.id))
			_check(jw.size() >= 1 and jw[0] == "none", "%s %d: jewellery starts with none (%s)" % [pid, bt, jw])
			for j: String in jw:
				_check(jw_ids.has(j), "%s: jewellery %s exists" % [pid, j])
			if bt == 2 and pid in ["arab", "kurdish", "egyptian"]:
				_check("nose_ring_gold" in jw, "%s women: a nose ring offered (%s)" % [pid, jw])
			if bt == 1 and pid == "ethiopian":
				_check(jw == ["none"], "Ethiopian men: no earrings (%s)" % [jw])


# --- the model ----------------------------------------------------------------------------------------

func _test_model() -> void:
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(inst)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var body := CharacterBodyMesh.attach(sk, ap)
	for pid: String in NEW:
		for bt in [1, 2]:
			for style in ["stylized", "realistic"]:
				var lk := _look(pid, bt, style)
				var bad := []
				for row in ["face", "hair_style"]:
					var opts := CreatorOptions.options(row, lk)
					for i in opts.size():
						CreatorOptions.select(row, lk, i, opts)
						PlayerAppearance.dress(body, lk)
						var hm := FaceExtras.head_mesh(body)
						if hm == null:
							bad.append("no head")
							continue
						if row == "face":
							for k: String in opts[i].face:
								var si := hm.find_blend_shape_by_name(k)
								if si < 0 or absf(hm.get_blend_shape_value(si) - float(opts[i].face[k])) > 1e-4:
									bad.append("%s %s" % [opts[i].id, k])
						elif String(body.get_meta("hair_style", "")) != String(opts[i].id) or body.part_meshes("hair").is_empty():
							bad.append("hair %s" % opts[i].id)
					CreatorOptions.select(row, lk, 0, opts)
				_check(bad.is_empty(), "%s %d %s: every face and hair style on the model %s" % [pid, bt, style, bad.slice(0, 5)])
	inst.queue_free()
	await _frames(2)


# --- save / restore -------------------------------------------------------------------------------------

func _test_store() -> void:
	var path := "user://appearance_test/new_peoples.json"
	for pid: String in NEW:
		for bt in [1, 2]:
			var lk := _look(pid, bt)
			lk["name"] = pid.capitalize()
			CreatorOptions.step("face", lk, 1)
			CreatorOptions.step("hair_style", lk, 1)
			CreatorOptions.step("jewellery", lk, 1)
			var want := {}
			for r: String in CreatorOptions.rows(lk):
				want[r] = CreatorOptions.current(r, lk)
			_check(AppearanceStore.save_file(path, AppearanceStore.validate(lk)), "%s %d: save" % [pid, bt])
			var back := AppearanceStore.load_file(path)
			_check(String(back.get("people", "")) == pid and String(back.get("preset", "")) == String(lk.get("preset", "")),
					"%s %d: people and face kept (%s)" % [pid, bt, back.get("preset")])
			_check(String(back.get("facial_hair", "")) == String(lk.get("facial_hair", "")),
					"%s %d: facial hair kept (%s)" % [pid, bt, back.get("facial_hair")])
			var same := true
			for r: String in want:
				if CreatorOptions.current(r, back) != want[r]:
					same = false
					print("    %s %s %d -> %d" % [pid, r, want[r], CreatorOptions.current(r, back)])
			_check(same, "%s %d: every row restored" % [pid, bt])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- the creator UI -------------------------------------------------------------------------------------

func _test_ui() -> void:
	if FileAccess.file_exists(AppearanceStore.CURRENT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AppearanceStore.CURRENT))
	var c := CharacterCreator.open(null)
	await _frames(5)
	c.look = _look("english", 1)
	c._refresh_all()
	await _frames(3)
	_check(c._people_buttons.size() == 35, "a button per people (%d)" % c._people_buttons.size())
	# the longest note, so the panel's tallest content is measured
	var longest := ""
	for p: Dictionary in CharacterPeoples.peoples():
		if longest.is_empty() or String(p.note).length() > String(CharacterPeoples.people(longest).note).length():
			longest = String(p.id)
	for pid: String in NEW + [longest]:
		_check(c._people_buttons.has(pid), "%s: a people button" % pid)
		if not c._people_buttons.has(pid):
			continue
		(c._people_buttons[pid] as Button).pressed.emit()
		await _frames(4)
		var p := CharacterPeoples.people(pid)
		_check(c.look.people == pid and c._people_name.text == String(p.label), "%s: chosen, named %s" % [pid, c._people_name.text])
		_check(c._people_note.text.contains(String(p.note).substr(0, 30)) and c._people_note.text.contains("Emblem"),
				"%s: the note with the emblem" % pid)
		# the panel spans the window from 16 px to 92 px above the bottom: its content must fit at 720 px
		var need := c._left_panel.get_combined_minimum_size().y
		_check(need <= 720.0 - 16.0 - 92.0, "%s: the people panel fits a 1280 x 720 window (%.0f of 612 px)" % [pid, need])
		await _shot(pid)
	var panel := c._left_panel.get_global_rect()
	var inside := true
	for pid: String in c._people_buttons:
		var r := (c._people_buttons[pid] as Button).get_global_rect()
		if r.end.x > panel.end.x - 8.0 or r.position.x < panel.position.x:
			inside = false
			print("    button %s at %s, panel %s" % [pid, r, panel])
	_check(inside, "every people button inside the panel (six on the Europe and Middle East rows)")
	_check(is_equal_approx(panel.size.x, 372.0), "the panel keeps its width (%.0f)" % panel.size.x)
	c.close(true)
	await _frames(3)
	var saved := AppearanceStore.load_file(AppearanceStore.CURRENT)
	_check(String(saved.get("people", "")) == longest, "Accept saves the chosen people (%s)" % saved.get("people"))
