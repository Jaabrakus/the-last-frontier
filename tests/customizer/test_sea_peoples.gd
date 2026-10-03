extends SceneTree
## The Vietnamese, Thai (Siamese) and Malay peoples (2026-09-26) and the Pacific Islanders (2026-09-27, in the
## Southeast Asia group as the user asked): their data, faces in both face styles, hair, the creator rows, the
## dressed model, save / restore and the creator UI.
## Headless, about 20 s.
##
##   Godot --headless --path . -s tests/customizer/test_sea_peoples.gd
##   Godot --path . --resolution 1280x720 -s tests/customizer/test_sea_peoples.gd -- shots=DIR
##
## Exit code 0 and "SEA PEOPLES TEST OK" when every check passes; 1 and the failures otherwise.
## The saved look (user://appearance/current.json) is backed up first and restored at the end.
## Run it under a hard time limit like every Godot run.
##
## Checks:
##   - peoples.json: the three in the Southeast Asia group after Filipino, with labels and notes; a
##     licence note on every East, South and Southeast Asian people and on no other; skin ranges,
##     dark eyes and hair, straight hair; each face mean lies between the Chinese and the Filipino
##     means feature by feature (a little past them at most: no feature exaggerated)
##   - faces: six stylized and six realistic example individuals per body type, the two showcase
##     faces first in both lists (and only there); a showcase face moves only the shared features
##     (never the nose, lids, epicanthus, midface or mouth projection), never past the people's own
##     tendency; realistic presets A-D; weights -1..1, melanin in range, hair a period style of the
##     people (the showcase faces) or a style made for the body type
##   - hair: hair_siamese_crop (men) and hair_siamese_short_f (women) load, carry a catalog entry, a
##     licence note and their triangle budget, and are the Thai body types' first styles
##   - creator rows: with_people gives the first showcase face in both face styles; the Face row
##     lists the six faces first and offers FACE_VARIANTS; Vietnamese and Malay men offer no
##     earrings (with the period note), the women do; an emblem each
##   - the model: every Face and Hair style choice of both body types in both face styles dressed
##     on a body (face shapes, hair part)
##   - save / restore: a look of each people (showcase face, a hair style and jewellery changed)
##     round-trips through AppearanceStore with every row restored
##   - the creator UI: the people buttons, the name, the note with the licence, the Face row on
##     the showcase face (1/10), Accept saves the chosen people

const NEW := ["vietnamese", "thai", "malay"]
## The peoples with six faces per body type in both face styles (the three and the Pacific Islanders).
const SIX := ["vietnamese", "thai", "malay", "pacific_islander"]
const WIDER := ["japanese", "chinese", "korean", "south_asian", "filipino", "vietnamese", "thai", "malay", "pacific_islander"]

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
	root.get_texture().get_image().save_png("%s/sea_%s.png" % [_shots, name])


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
	_test_peoples()
	_test_pacific()
	_test_faces()
	_test_hair()
	_test_rows()
	await _test_model()
	_test_store()
	await _test_ui()
	if _had_file:
		var f := FileAccess.open(AppearanceStore.current_path(), FileAccess.WRITE)
		f.store_string(_backup)
		f.close()
	elif FileAccess.file_exists(AppearanceStore.current_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AppearanceStore.current_path()))
	print("SEA PEOPLES TEST %s (%d checks%s)" % ["OK" if _fails.is_empty() else "FAILED", _checks,
			"" if _fails.is_empty() else ", %d failed" % _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _look(pid: String, bt: int, style := "realistic") -> Dictionary:
	return CreatorOptions.with_people({"sex": 1.0 if bt == 1 else 0.0, "face_style": style}, pid)


# --- peoples ----------------------------------------------------------------------------------------

func _test_peoples() -> void:
	var sea: Array = CharacterPeoples.peoples("Southeast Asia").map(func(p: Dictionary) -> String: return String(p.id))
	_check(sea == ["filipino", "vietnamese", "thai", "malay", "pacific_islander"],
			"Southeast Asia: Filipino, the three, then the Pacific Islanders (%s)" % [sea])
	var labels := {"vietnamese": "Vietnamese", "thai": "Thai (Siamese)", "malay": "Malay"}
	for p: Dictionary in CharacterPeoples.peoples():
		var pid := String(p.id)
		_check((p.get("licence_note") is String) == (pid in WIDER), "%s: licence note only for the wider cast" % pid)
	var cn := CharacterPeoples.people("chinese")
	var fp := CharacterPeoples.people("filipino")
	for pid: String in NEW:
		var p := CharacterPeoples.people(pid)
		_check(String(p.get("label", "")) == labels[pid], "%s: label %s" % [pid, p.get("label")])
		_check(String(p.get("note", "")).length() > 40, "%s: a period note" % pid)
		var mel: Array = p.skin.melanin
		_check(float(mel[0]) >= 0.15 and float(mel[1]) <= 0.7 and float(mel[1]) - float(mel[0]) >= 0.28,
				"%s: a plausible, wide skin range %s" % [pid, mel])
		_check(String(p.hair_texture) == "straight", "%s: straight hair" % pid)
		_check(float((p.eyes as Dictionary).get("dark_brown", 0.0)) >= 0.5, "%s: mostly dark brown eyes" % pid)
		var dark := 0.0
		for c in ["black", "blue_black", "dark_brown"]:
			dark += float((p.hair_colors as Dictionary).get(c, 0.0))
		_check(dark >= 0.99, "%s: black to dark brown hair" % pid)
		var off := []
		for k: String in CharacterPeoples.feature_keys():
			var v := float((p.face_mean as Dictionary).get(k, 0.0))
			var a := float((cn.face_mean as Dictionary).get(k, 0.0))
			var b := float((fp.face_mean as Dictionary).get(k, 0.0))
			if v < minf(a, b) - 0.12 or v > maxf(a, b) + 0.12:
				off.append("%s %.2f (%.2f..%.2f)" % [k, v, a, b])
			if absf(v) > 0.9:
				off.append("%s %.2f past 0.9" % [k, v])
		_check(off.is_empty(), "%s: the mean between the Chinese and Filipino means %s" % [pid, off])


## The Pacific Islanders: label, note, skin, eyes, hair (straight to wavy, dark), a longer, stronger face than the
## Malay mean with the lid crease more often present and the epicanthus less, no feature pushed past 0.9; the
## period hair styles first; the emblem; pearl drops for both sexes with the note (tatau left out).
func _test_pacific() -> void:
	var p := CharacterPeoples.people("pacific_islander")
	_check(not p.is_empty() and String(p.get("label", "")) == "Pacific Islander", "pacific_islander: the people, labelled")
	if p.is_empty():
		return
	_check(String(p.get("note", "")).contains("Tahiti") and String(p.get("note", "")).contains("Mai"), "pacific_islander: a period note")
	var mel: Array = p.skin.melanin
	_check(float(mel[0]) >= 0.25 and float(mel[1]) <= 0.7 and float(mel[1]) - float(mel[0]) >= 0.28, "pacific_islander: skin %s" % [mel])
	_check(String(p.hair_texture) == "wavy", "pacific_islander: straight to wavy hair")
	_check(float((p.eyes as Dictionary).get("dark_brown", 0.0)) >= 0.5, "pacific_islander: mostly dark brown eyes")
	var ml := CharacterPeoples.people("malay")
	var fm: Dictionary = p.face_mean
	var mm: Dictionary = ml.face_mean
	var f := func(d: Dictionary, k: String) -> float: return float(d.get("face_" + k, d.get(k, 0.0)))
	_check(f.call(fm, "length") > f.call(mm, "length") and f.call(fm, "jaw_width") > f.call(mm, "jaw_width")
			and f.call(fm, "chin_projection") > f.call(mm, "chin_projection"), "pacific_islander: a longer, stronger face than the Malay")
	_check(f.call(fm, "lid_crease") > f.call(mm, "lid_crease") and f.call(fm, "epicanthus") < f.call(mm, "epicanthus"),
			"pacific_islander: the lid crease more often, the epicanthus less than the Malay")
	var past := []
	for k: String in CharacterPeoples.feature_keys():
		if absf(float(fm.get(k, 0.0))) > 0.9:
			past.append(k)
	_check(past.is_empty(), "pacific_islander: no feature past 0.9 %s" % [past])
	var hs: Dictionary = p.hair_styles
	_check(String((hs.m as Array)[0]) == "hair_topknot" and String((hs.f as Array)[0]) == "hair_natural_short",
			"pacific_islander: the knot on the crown (men) and the short cut (women) first (%s, %s)" % [hs.m, hs.f])
	var d := CreatorOptions.data()
	_check(String((d.get("emblems", {}) as Dictionary).get("pacific_islander", "")).begins_with("Breadfruit"), "pacific_islander: the breadfruit leaf")
	var po: Dictionary = (d.get("peoples", {}) as Dictionary).get("pacific_islander", {})
	_check("pearl_drops" in (po.get("jewellery_m", []) as Array) and "pearl_drops" in (po.get("jewellery_f", []) as Array)
			and String(po.get("note_jewellery", "")).contains("Tatau"), "pacific_islander: pearl drops for both, the tatau note")


# --- faces --------------------------------------------------------------------------------------------

func _test_faces() -> void:
	var shared: Array = CharacterPeoples.data().get("stylized_shared", [])
	var eyes: Dictionary = BodyMaterials.body_info().get("eyes", {})
	for pid: String in SIX:
		var p := CharacterPeoples.people(pid)
		var mean: Dictionary = p.face_mean
		var mel: Array = p.skin.melanin
		for sex in [0.0, 1.0]:
			var sx := "m" if sex > 0.5 else "f"
			var st := CharacterPeoples.stylized_presets(pid, sex)
			var re := CharacterPeoples.presets(pid, sex)
			_check(st.size() == 6 and re.size() == 6, "%s %s: six stylized and six realistic faces (%d, %d)" % [pid, sx, st.size(), re.size()])
			var re_ids: Array = re.map(func(pr: Dictionary) -> String: return String(pr.id))
			var want_ids := []
			for t in ["r1", "r2", "a", "b", "c", "d"]:
				want_ids.append("%s_%s_%s" % [pid, sx, t])
			_check(re_ids == want_ids, "%s %s: realistic order %s" % [pid, sx, re_ids])
			for list: Array in [st, re]:
				for i in list.size():
					var pr: Dictionary = list[i]
					_check(bool(pr.get("showcase", false)) == (i < 2), "%s: showcase faces first, and only those" % pr.id)
					_check((list == st) == pr.has("face_style"), "%s: face_style only on the stylized faces" % pr.id)
					_check(float(pr.melanin) >= float(mel[0]) - 1e-3 and float(pr.melanin) <= float(mel[1]) + 1e-3,
							"%s: melanin in range" % pr.id)
					_check(eyes.has(String(pr.iris)), "%s: iris %s" % [pr.id, pr.iris])
					var style := String(pr.hair.style)
					_check(ResourceLoader.exists(BodyMaterials.HAIR_DIR + style + ".glb"), "%s: hair %s exists" % [pr.id, style])
					_check(style in (p.hair_styles as Dictionary)[sx], "%s: hair %s a period style of the people" % [pr.id, style])
					var bad := []
					for k: String in CharacterPeoples.feature_keys():
						var m := float(mean.get(k, 0.0))
						var w := float((pr.face as Dictionary).get(k, 0.0))
						if absf(w) > 1.0:
							bad.append("%s out of range" % k)
						if not pr.get("showcase", false):
							continue
						if not k in shared and absf(w - m) > 0.002:
							bad.append("%s moved (%.3f vs %.3f)" % [k, w, m])
						elif absf(m) > 0.05 and signf(w - m) == signf(m) and absf(w) > absf(m) + 0.5 * (1.0 - absf(m)) + 0.002:
							bad.append("%s pushed past the tendency (%.3f, mean %.3f)" % [k, w, m])
					_check(bad.is_empty(), "%s: face weights %s" % [pr.id, bad])
					if pr.get("showcase", false):
						_check(float(pr.stubble) <= 0.05 and float(pr.brows.thickness) > 0.5, "%s: a clean shave and bold brows" % pr.id)
					_check(not CharacterPeoples.preset_look(String(pr.id)).is_empty(), "%s: preset_look finds it" % pr.id)
	# the other peoples keep n07's two realistic presets per body type
	for pid in ["japanese", "filipino", "english"]:
		_check(CharacterPeoples.presets(pid, 1.0).size() == 2 and CharacterPeoples.presets(pid, 1.0)[0].id == pid + "_m_a",
				"%s: n07's realistic presets unchanged" % pid)


# --- hair ---------------------------------------------------------------------------------------------

func _test_hair() -> void:
	var cat: Dictionary = BodyMaterials.load_json("res://assets/character/catalog.json").get("items", {})
	for st: String in ["hair_siamese_crop", "hair_siamese_short_f"]:
		var scene := load(BodyMaterials.HAIR_DIR + st + ".glb") as PackedScene
		_check(scene != null, "%s loads" % st)
		var info := BodyMaterials.hair_info(st)
		_check(info.get("licence_note") is String and String(info.get("evidence", "")) == "C", "%s: grade C with a licence note" % st)
		_check(cat.has(st), "%s: in catalog.json" % st)
		if scene:
			var inst := scene.instantiate()
			var tris := 0
			for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
				for s in mi.mesh.get_surface_count():
					tris += (mi.mesh as ArrayMesh).surface_get_array_index_len(s) / 3
			var budget := int((info.get("budget", {}) as Dictionary).get("tris_max", 0))
			_check(tris > 1000 and budget > 0 and tris <= budget, "%s: %d triangles within the budget %d" % [st, tris, budget])
			inst.free()
	_check("men" in BodyMaterials.hair_info("hair_siamese_crop").get("tags", []), "the crop is made for men")
	_check("women" in BodyMaterials.hair_info("hair_siamese_short_f").get("tags", []), "the short style is made for women")
	for bt in [1, 2]:
		var opts := CreatorOptions.options("hair_style", _look("thai", bt))
		var want := "hair_siamese_crop" if bt == 1 else "hair_siamese_short_f"
		_check(not opts.is_empty() and String(opts[0].id) == want and String(opts[0].note).contains("Artistic licence"),
				"thai %d: %s first, with its licence note" % [bt, want])


# --- creator rows -------------------------------------------------------------------------------------

func _test_rows() -> void:
	var d := CreatorOptions.data()
	for pid: String in SIX:
		var em := PeopleEmblem.new(pid)
		_check((d.get("emblems", {}) as Dictionary).has(pid) and em.has_method("_e_" + pid), "%s has an emblem" % pid)
		em.free()
		for bt in [1, 2]:
			var sx := "m" if bt == 1 else "f"
			for style in ["realistic"]:      # realistic only since the v3 head (2026-09-27)
				var lk := _look(pid, bt, style)
				var first := "%s_%s_%s1" % [pid, sx, "s" if style == "stylized" else "r"]
				_check(String(lk.get("preset", "")) == first and BodyMaterials.face_style(lk) == style,
						"%s %d %s: the first face is the showcase face %s (%s)" % [pid, bt, style, first, lk.get("preset")])
				var faces := CreatorOptions.options("face", lk)
				_check(faces.size() == CreatorOptions.FACE_VARIANTS, "%s %d %s: %d faces" % [pid, bt, style, faces.size()])
				var six := CharacterPeoples.stylized_presets(pid, 2 - bt) if style == "stylized" else CharacterPeoples.presets(pid, 2 - bt)
				var ok := true
				for i in 6:
					if String(faces[i].get("preset", "")) != String(six[i].id):
						ok = false
				_check(ok, "%s %d %s: the six faces lead the Face row" % [pid, bt, style])
				_check(String(faces[0].get("note", "")).begins_with("Showcase face") and not faces[2].has("note"),
						"%s %d %s: the showcase note on the showcase faces" % [pid, bt, style])
				_check(CreatorOptions.current("face", lk) == 0, "%s %d %s: the Face row on face 1" % [pid, bt, style])
			# every earring offered to everyone (2026-10-03); the documented ones are the people's own (first, the dice's)
			var jw := CreatorOptions.options("jewel_ears", _look(pid, bt)).map(func(o: Dictionary) -> String: return String(o.id))
			var own := CreatorOptions.jewel_own(_look(pid, bt), "ears")
			_check(jw.size() > 10 and jw[0] == "none", "%s %d: every earring offered (%d)" % [pid, bt, jw.size()])
			if pid in ["vietnamese", "malay"] and bt == 1:
				_check(own.is_empty(), "%s men: no earrings of their own (%s)" % [pid, own])
				_check(String((d.peoples[pid] as Dictionary).get("note_jewellery", "")).contains("women"), "%s: the jewellery note" % pid)
			elif pid == "pacific_islander":
				_check(own == ["pearl_drops"], "%s %d: pearls in the ears their own (%s)" % [pid, bt, own])
			else:
				_check(not own.is_empty(), "%s %d: earrings of their own (%s)" % [pid, bt, own])


# --- the model ----------------------------------------------------------------------------------------

func _test_model() -> void:
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(inst)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var body := CharacterBodyMesh.attach(sk, ap)
	for pid: String in SIX:
		for bt in [1, 2]:
			for style in ["realistic"]:
				var lk := _look(pid, bt, style)
				var bad := []
				for row in ["face", "hair_style"]:
					var opts := CreatorOptions.options(row, lk)
					for i in opts.size():
						CreatorOptions.select(row, lk, i, opts)
						PlayerAppearance.dress(body, lk)
						var hm := FaceExtras.head_mesh(body)
						if row == "face":
							for k: String in opts[i].face:
								var si := hm.find_blend_shape_by_name(k)
								if si < 0 or absf(hm.get_blend_shape_value(si) - float(opts[i].face[k])) > 1e-4:
									bad.append("%s %s" % [opts[i].id, k])
						elif String(body.get_meta("hair_style", "")) != String(opts[i].id) or body.part_meshes("hair").is_empty():
							bad.append("hair %s" % opts[i].id)
						if hm.find_blend_shape_by_name(&"style") >= 0:
							bad.append("a style shape on the v3 head")
					CreatorOptions.select(row, lk, 0, opts)
				_check(bad.is_empty(), "%s %d %s: every face and hair style on the model %s" % [pid, bt, style, bad.slice(0, 5)])
	inst.queue_free()
	await _frames(2)


# --- save / restore -------------------------------------------------------------------------------------

func _test_store() -> void:
	var path := "user://appearance_test/sea.json"
	for pid: String in SIX:
		var lk := _look(pid, 2 if pid == "thai" else 1)
		lk["name"] = pid.capitalize()
		CreatorOptions.step("face", lk, 1)
		CreatorOptions.step("hair_style", lk, 1)
		CreatorOptions.step("jewel_ears", lk, 1)
		var want := {}
		for r: String in CreatorOptions.rows(lk):
			want[r] = CreatorOptions.current(r, lk)
		_check(AppearanceStore.save_file(path, AppearanceStore.validate(lk)), "%s: save" % pid)
		var back := AppearanceStore.load_file(path)
		_check(String(back.get("people", "")) == pid and String(back.get("preset", "")) == String(lk.get("preset", "")),
				"%s: people and face kept (%s)" % [pid, back.get("preset")])
		_check(String(back.hair.style) == String(lk.hair.style), "%s: hair style kept (%s)" % [pid, back.hair.style])
		var same := true
		for r: String in want:
			if CreatorOptions.current(r, back) != want[r]:
				same = false
				print("    %s %s %d -> %d" % [pid, r, want[r], CreatorOptions.current(r, back)])
		_check(same, "%s: every row restored" % pid)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- the creator UI -------------------------------------------------------------------------------------

func _test_ui() -> void:
	if FileAccess.file_exists(AppearanceStore.current_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AppearanceStore.current_path()))
	var c := CharacterCreator.open(null)
	await _frames(5)
	c.look = _look("english", 2)
	c._refresh_all()
	await _frames(2)
	for pid: String in SIX:
		_check(c._people_buttons.has(pid), "%s: a people button" % pid)
		if not c._people_buttons.has(pid):
			continue
		(c._people_buttons[pid] as Button).pressed.emit()
		await _frames(3)
		var p := CharacterPeoples.people(pid)
		_check(c.look.people == pid and c._people_name.text == String(p.label), "%s: chosen, named %s" % [pid, c._people_name.text])
		_check(c._people_note.text.contains("Artistic licence") and c._people_note.text.contains("Emblem"),
				"%s: the note with the emblem and the licence" % pid)
		var ui: Dictionary = c._row_ui.get("face", {})
		_check(not ui.is_empty() and (ui.count as Label).text == "1/%d" % CreatorOptions.FACE_VARIANTS,
				"%s: the Face row on the showcase face (%s)" % [pid, (ui.count as Label).text if not ui.is_empty() else ""])
		c._set_focus("face")
		await _frames(2)
		await _shot(pid)
	c.close(true)
	await _frames(3)
	var saved := AppearanceStore.load_file(AppearanceStore.current_path())
	_check(String(saved.get("people", "")) == SIX[-1] and String(saved.get("preset", "")) == SIX[-1] + "_f_r1",
			"Accept saves the chosen people and face (%s, %s)" % [saved.get("people"), saved.get("preset")])
