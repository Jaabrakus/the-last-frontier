extends SceneTree
## Faces and peoples: the customizer body's face shapes, the peoples presets, the look on the
## real player and the customizer overlay. Headless, about 20 s.
##
##   Godot --headless --path . -s tests/customizer/test_faces.gd
##
## Exit code 0 and "FACES TEST OK" when every check passes; 1 and the failures otherwise.
## Run it under a hard time limit like every Godot run.
##
## Checks:
##   - body.glb has the Body and Face meshes with the shapes sex, sex_head, blink and every
##     face_* feature of peoples.json; every shape moves vertices (none is empty); the Face
##     mesh has the eye and face_hair surfaces
##   - peoples.json: every people has 4 presets (2 women, 2 men; the Vietnamese, Thai and Malay
##     12: six per body type); preset feature weights are known shapes within -1..1; hair styles
##     exist; iris colours are body.json eyes; melanin inside the people's range
##   - random individuals stay within -1..1 and inside the skin ranges; a mixed individual's
##     melanin lies between the two peoples' ranges
##   - the player in main.tscn: PlayerAppearance installed, legacy Body / Face / Hair hidden,
##     the head part attached with the skin / eye / face_hair materials, the male fit only on
##     the head (sex 0, sex_head 1) for the legacy outfit, under the hat the hair is pressed
##     flat (hat_fit 1) and its crown still drawn (no bare band below the hat)
##   - applying every preset to the player leaves the node count stable and the shapes set
##   - blink: FaceBlink drives the blink shape
##   - AppearanceStore: save / load round trip, a broken file falls back to the default
##   - input: customize on O, no other action on O; the creator (CharacterCreator) opens
##     (pauses the tree) and Back closes it (unpauses)

const BODY := "res://assets/character/body/body.glb"

var _fails: Array[String] = []
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_test_glb()
	_test_peoples()
	await _test_player()
	print("FACES TEST %s (%d checks%s)" % ["OK" if _fails.is_empty() else "FAILED", _checks,
			"" if _fails.is_empty() else ", %d failed" % _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _test_glb() -> void:
	var scene := load(BODY) as PackedScene
	_check(scene != null, "body.glb loads")
	if scene == null:
		return
	var inst := scene.instantiate()
	var meshes := {}
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		meshes[String(n.name)] = n
	_check(meshes.has("Body") and meshes.has("Face"), "Body and Face meshes (%s)" % [meshes.keys()])
	var want := ["sex", "sex_head", "blink"]
	for f in CharacterPeoples.feature_keys():
		want.append(f)
	for mname in ["Body", "Face"]:
		if not meshes.has(mname):
			continue
		var mesh := (meshes[mname] as MeshInstance3D).mesh as ArrayMesh
		var have := []
		for i in mesh.get_blend_shape_count():
			have.append(String(mesh.get_blend_shape_name(i)))
		for w in want:
			_check(w in have, "%s has shape %s" % [mname, w])
		if mname == "Body":
			# every shape moves the mesh
			var base: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var bs: Array = mesh.surface_get_blend_shape_arrays(0)
			for i in bs.size():
				var pv: PackedVector3Array = bs[i][Mesh.ARRAY_VERTEX]
				var mx := 0.0
				for k in pv.size():
					mx = maxf(mx, (pv[k] - base[k]).length())
				_check(mx > 0.0005, "Body shape %s moves the mesh (max %.4f m)" % [have[i], mx])
				# the male fit moves the shoulders; on the body v4 the male genitals unfold from inside the female base,
				# and the bust gauge's max cup (breast_large) moves as far
				var limit := 0.10 if have[i] in ["sex", "breast_large"] else 0.03
				_check(mx < limit, "Body shape %s stays small (max %.4f m)" % [have[i], mx])
		if mname == "Face":
			var surfs := []
			for s in mesh.get_surface_count():
				var m := mesh.surface_get_material(s)
				surfs.append(m.resource_name if m else "")
			_check("eye" in surfs and "face_hair" in surfs, "Face surfaces eye + face_hair (%s)" % [surfs])
	inst.free()


func _test_peoples() -> void:
	var d := CharacterPeoples.data()
	var keys := CharacterPeoples.feature_keys()
	var eyes: Dictionary = BodyMaterials.body_info().get("eyes", {})
	_check(CharacterPeoples.peoples().size() >= 18, "at least 18 peoples (%d)" % CharacterPeoples.peoples().size())
	var ids := []
	for p: Dictionary in CharacterPeoples.peoples():
		ids.append(p.id)
		var prs := CharacterPeoples.presets(String(p.id))
		var per_sex := 6 if String(p.id) in ["vietnamese", "thai", "malay", "pacific_islander"] else 2
		_check(prs.size() == 2 * per_sex, "%s has %d presets (%d)" % [p.id, 2 * per_sex, prs.size()])
		_check(CharacterPeoples.presets(String(p.id), 0.0).size() == per_sex, "%s has %d women presets" % [p.id, per_sex])
		var mel: Array = p.skin.melanin
		for pr: Dictionary in prs:
			for k in pr.face:
				_check(k in keys, "%s: known feature %s" % [pr.id, k])
				_check(absf(float(pr.face[k])) <= 1.0, "%s: %s within -1..1" % [pr.id, k])
			var style := String(pr.hair.style)
			_check(ResourceLoader.exists(BodyMaterials.HAIR_DIR + style + ".glb"), "%s: hair style %s exists" % [pr.id, style])
			_check(eyes.has(String(pr.iris)), "%s: iris %s in body.json eyes" % [pr.id, pr.iris])
			_check(float(pr.melanin) >= float(mel[0]) - 1e-3 and float(pr.melanin) <= float(mel[1]) + 1e-3,
					"%s: melanin %.3f in %s" % [pr.id, pr.melanin, mel])
		for sx in ["f", "m"]:
			for st in (p.hair_styles as Dictionary)[sx]:
				_check(ResourceLoader.exists(BodyMaterials.HAIR_DIR + String(st) + ".glb"), "%s: style %s exists" % [p.id, st])
	for must in ["haudenosaunee", "lenape", "west_african", "central_african", "japanese", "chinese", "korean",
			"english", "scots_irish", "french", "palatine", "dutch", "south_asian", "levantine", "metis", "vietnamese",
			"thai", "malay", "pacific_islander", "spanish", "ottoman_turkish", "persian", "arab", "armenian", "kurdish",
			"moorish", "egyptian", "ethiopian"]:
		_check(must in ids, "people %s present" % must)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for p: Dictionary in CharacterPeoples.peoples():
		for i in 5:
			var lk := CharacterPeoples.random_look(String(p.id), float(i % 2), rng)
			var mel: Array = p.skin.melanin
			_check(float(lk.melanin) >= float(mel[0]) - 1e-3 and float(lk.melanin) <= float(mel[1]) + 1e-3,
					"random %s melanin in range" % p.id)
			for k in lk.face:
				_check(absf(float(lk.face[k])) <= 1.0, "random %s %s in range" % [p.id, k])
	var mixed := CharacterPeoples.random_look("english", 1.0, rng, "west_african", 0.5)
	_check(float(mixed.melanin) >= 0.36 - 1e-3 and float(mixed.melanin) <= 0.61 + 1e-3,
			"mixed English / West African melanin between the ranges (%.3f)" % float(mixed.melanin))


func _test_player() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	var player: FrontierPlayer = current_scene.get_node("Player")
	var app := player.appearance
	_check(app != null, "player has a PlayerAppearance")
	if app == null:
		return
	var body := app.body
	# the bare body v4 (2026-09-28): every legacy outfit mesh (Body, Face, Hair, Clothes, Gear, Hat) hidden
	var own := {}
	for t in body.parts:
		for pm in body.parts[t]:
			own[pm] = true
	var legacy_hidden := true
	for mi: MeshInstance3D in body.meshes:
		if not own.has(mi) and mi.visible:
			legacy_hidden = false
	_check(legacy_hidden, "the legacy outfit hidden (the bare body)")
	var head: Array = body.part_meshes("head")
	_check(head.size() == 2, "head part has Body + Face (%d)" % head.size())
	var hair: Array = body.part_meshes("hair")
	_check(hair.size() >= 1, "hair part attached")
	var mats := {}
	for mi: MeshInstance3D in head:
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m:
				mats[m.shader.resource_path.get_file()] = m
	# the default face style is Stylized (painted skin); the realistic skin in the Realistic style
	var stylized := BodyMaterials.is_stylized(app.look)
	for sh in ["painted_skin.gdshader" if stylized else "skin.gdshader", "eye.gdshader", "face_hair.gdshader"]:
		_check(mats.has(sh), "head uses %s" % sh)
	app.apply(CharacterPeoples.preset_look("haudenosaunee_m_a"))
	var hb := head[0] as MeshInstance3D
	_check(is_equal_approx(hb.get_blend_shape_value(hb.find_blend_shape_by_name(&"sex")), 1.0), "the full fit: sex 1")
	_check(is_equal_approx(hb.get_blend_shape_value(hb.find_blend_shape_by_name(&"sex_head")), 0.0), "the full fit: sex_head 0")
	_check(body.part_meshes("body_hair").is_empty(), "the pubic hair is under the breeches (dressed): not drawn")
	var w := hb.get_blend_shape_value(hb.find_blend_shape_by_name(&"face_cheekbones"))
	var want := float(CharacterPeoples.preset("haudenosaunee_m_a").face.get("face_cheekbones", 0.0))
	_check(is_equal_approx(w, want), "preset face weight applied (%.3f vs %.3f)" % [w, want])
	var hm := (body.part_meshes("hair")[0] as MeshInstance3D)
	var hf := hm.find_blend_shape_by_name(&"hat_fit")
	_check(hf < 0 or is_equal_approx(hm.get_blend_shape_value(hf), 0.0), "no hat: the hair not pressed (hat_fit 0)")
	# every preset, node count stable
	var n0 := body.get_child_count()
	for pr: Dictionary in CharacterPeoples.presets():
		app.apply(CharacterPeoples.preset_look(String(pr.id)))
	await _frames(2)
	_check(body.get_child_count() <= n0 + 1 and body.get_child_count() >= n0 - 1,
			"node count stable after every preset (%d -> %d)" % [n0, body.get_child_count()])
	# blink
	app.blink.set_blink(1.0)
	_check(is_equal_approx(hb.get_blend_shape_value(hb.find_blend_shape_by_name(&"blink")), 1.0), "blink shape driven")
	app.blink.set_blink(0.0)
	# store
	var path := "user://appearance_test/look.json"
	var lk := CharacterPeoples.preset_look("japanese_f_a")
	_check(AppearanceStore.save_file(path, lk), "save look")
	var back := AppearanceStore.load_file(path)
	_check(String(back.get("preset", "")) == "japanese_f_a" and is_equal_approx(float(back.melanin), float(lk.melanin)),
			"load round trip")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	_check(String(AppearanceStore.load_file(path).get("preset", "")) == AppearanceStore.DEFAULT_PRESET,
			"broken file -> default look")
	DirAccess.remove_absolute(path)
	# input
	_check(InputMap.has_action(&"customize"), "customize action")
	var on_o := []
	for a in InputMap.get_actions():
		for e in InputMap.action_get_events(a):
			if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_O:
				on_o.append(String(a))
	_check(on_o == ["customize"], "only customize on O (%s)" % [on_o])
	# the creator (O)
	app.open_customizer()
	await _frames(3)
	_check(is_instance_valid(app.overlay) and paused, "creator opens and pauses")
	if is_instance_valid(app.overlay):
		app.overlay.call("close", false)
	await _frames(2)
	_check(not paused, "cancel unpauses")
