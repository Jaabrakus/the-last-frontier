extends SceneTree
## The v3 head (2026-09-27, the user: a Red Dead / Assassin's Creed style head, "realistic only"):
## the MakeHuman head (CC0) in body.glb with the creator's 30 face features, the male fit and the
## blink as its shapes (tools/character/body/body_v3.py, body/mh.py). Replaces test_stylized.gd.
## Headless, about 10 s.
##
##   Godot --headless --path . -s tests/customizer/test_head_v3.gd
##
## Exit code 0 and "HEAD V3 TEST OK" when every check passes; 1 and the failures otherwise.
##
## Checks:
##   - body.glb: the Body has sex, sex_head, blink and the 30 face_* shapes and no stylized shapes;
##     every face shape moves the head (0.5 to 12 mm); the head within 12k triangles and the body
##     within 32k (body v4); the Face mesh (eye, face_hair) takes sex, sex_head, blink and the face shapes, and
##     the eyes move with sex_head as with sex (the creator's head-only male fit)
##   - body.json: the head model and its CC0 provenance
##   - realistic only: one face style, no Face style or Complexion rows, a stylized save loads as
##     realistic, the default look a realistic preset, a new look's first face a realistic preset
##   - the look on a body: the face weights and sex reach the head's shapes, the blink closes the lids
##   - step 2 (facial hair, marks, jewellery on the new face): body.json face.warp (8 h and 4 |u|
##     knots, increasing, each landmark mapped onto the v2 one by BodyMaterials.warp_face_coords and
##     set on the skin material), face.landmarks (ear lobes and rims, septum, left nostril) used by
##     FaceExtras; a full beard's shells within the fur budget

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
	_test_realistic_only()
	_test_warp()
	await _test_look()
	print("HEAD V3 TEST %s (%d checks%s)" % ["OK" if _fails.is_empty() else "FAILED", _checks,
			"" if _fails.is_empty() else ", %d failed" % _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _shape_max(mesh: ArrayMesh, name: String) -> float:
	var base: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bs: Array = mesh.surface_get_blend_shape_arrays(0)
	for i in mesh.get_blend_shape_count():
		if String(mesh.get_blend_shape_name(i)) != name:
			continue
		var pv: PackedVector3Array = bs[i][Mesh.ARRAY_VERTEX]
		var mx := 0.0
		for k in pv.size():
			mx = maxf(mx, (pv[k] - base[k]).length())
		return mx
	return -1.0


func _names(mesh: ArrayMesh) -> Array:
	var out := []
	for i in mesh.get_blend_shape_count():
		out.append(String(mesh.get_blend_shape_name(i)))
	return out


func _tris(mesh: ArrayMesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		n += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _test_glb() -> void:
	var scene := load(BODY) as PackedScene
	_check(scene != null, "body.glb loads")
	if scene == null:
		return
	var inst := scene.instantiate()
	var body: ArrayMesh = null
	var face: ArrayMesh = null
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) == "Body":
			body = mi.mesh
		elif String(mi.name) == "Face":
			face = mi.mesh
	_check(body != null and face != null, "Body and Face meshes")
	if body == null or face == null:
		inst.free()
		return
	var names := _names(body)
	for sh in ["sex", "sex_head", "blink"]:
		_check(sh in names, "Body has %s" % sh)
	for f: Dictionary in CharacterPeoples.features():
		var k := String(f.key)
		_check(k in names, "Body has %s" % k)
		var mx := _shape_max(body, k)
		_check(mx > 0.0005 and mx < 0.012, "%s moves the head 0.5 to 12 mm (%.1f mm)" % [k, mx * 1000.0])
	for sh in ["style", "style_male", "blink_style"]:
		_check(not sh in names, "no stylized shape %s on the Body" % sh)
	var blink := _shape_max(body, "blink")
	_check(blink > 0.002 and blink < 0.012, "the blink moves the lids (%.1f mm)" % (blink * 1000.0))
	_check(_tris(body) <= 32000, "Body within 32k triangles (%d)" % _tris(body))     # body v4: the MakeHuman body
	var info := BodyMaterials.body_info()
	var head_tris := int(((info.get("objects", {}) as Dictionary).get("Body", {}) as Dictionary).get("head_tris", 0))
	_check(head_tris > 3000 and head_tris <= 12000, "the head within 12k triangles (%d)" % head_tris)
	var fnames := _names(face)
	for sh in ["sex", "sex_head", "blink", "face_eye_height", "face_breadth"]:
		_check(sh in fnames, "Face has %s" % sh)
	var ms := _shape_max(face, "sex")
	var mh := _shape_max(face, "sex_head")
	_check(ms > 0.001 and absf(ms - mh) < 1e-5, "the eyes, brows and lashes move alike with sex and sex_head (%.1f / %.1f mm)" % [ms * 1000.0, mh * 1000.0])
	var surf := []
	for s in face.get_surface_count():
		var m := face.surface_get_material(s)
		surf.append(m.resource_name if m else "")
	_check("eye" in surf and "face_hair" in surf, "Face surfaces eye and face_hair (%s)" % [surf])
	inst.free()
	var fm := String((info.get("face", {}) as Dictionary).get("model", ""))
	_check(fm.contains("MakeHuman") and fm.contains("CC0"), "body.json names the head model (%s)" % fm.left(60))
	_check(String(info.get("provenance", "")).contains("CC0"), "body.json provenance credits MakeHuman (CC0)")


func _test_realistic_only() -> void:
	_check(BodyMaterials.FACE_STYLES == ["realistic"], "one face style: realistic")
	var lk := CreatorOptions.with_people({"sex": 1.0}, "korean")
	_check(not BodyMaterials.is_stylized(lk) and BodyMaterials.face_style(lk) == "realistic", "a new look is realistic")
	var rows := CreatorOptions.rows(lk)
	_check(not "face_style" in rows and not "complexion" in rows, "no Face style or Complexion row (%s)" % [rows])
	_check(String(lk.get("preset", "")) == "korean_m_a", "Korean: preset A first (%s)" % lk.get("preset", ""))
	var vn := CreatorOptions.with_people({"sex": 1.0}, "vietnamese")
	_check(String(vn.get("preset", "")) == "vietnamese_m_r1", "Vietnamese: the realistic showcase face first (%s)" % vn.get("preset", ""))
	var eng := CreatorOptions.with_people({"sex": 0.0}, "english")
	_check(String(eng.get("preset", "")) == "english_f_a", "an English woman's first face is preset A (%s)" % eng.get("preset", ""))
	var d := AppearanceStore.default_look()
	_check(not BodyMaterials.is_stylized(d) and not String(d.get("preset", "")).contains("_s"),
			"the default look is realistic (%s)" % d.get("preset", ""))
	var old := CharacterPeoples.preset_look("english_m_s1")
	_check(String(old.get("face_style", "")) == "stylized", "a stylized preset still carries its style")
	var v := AppearanceStore.validate(old)
	_check(String(v.face_style) == "realistic", "a stylized save loads as realistic")


func _test_warp() -> void:
	var face: Dictionary = BodyMaterials.body_info().get("face", {})
	var w: Dictionary = face.get("warp", {})
	var h: Array = w.get("h", [])
	var u: Array = w.get("u", [])
	_check(h.size() == 8 and u.size() == 4, "face.warp has 8 h and 4 u knots")
	if h.size() != 8 or u.size() != 4:
		return
	var inc := true
	for i in range(1, 8):
		inc = inc and float(h[i]) > float(h[i - 1])
	for i in range(1, 4):
		inc = inc and float(u[i]) > float(u[i - 1])
	_check(inc, "the knots increase")
	var hv: Array = w.get("h_v2", [])
	var uv: Array = w.get("u_v2", [])
	var ok := true
	for i in 8:
		ok = ok and absf(BodyMaterials.warp_face_coords(0.0, float(h[i])).y - float(hv[i])) < 1e-5
	for i in 4:
		ok = ok and absf(BodyMaterials.warp_face_coords(float(u[i]), 1.45).x - float(uv[i])) < 1e-5
		ok = ok and absf(BodyMaterials.warp_face_coords(-float(u[i]), 1.45).x + float(uv[i])) < 1e-5
	_check(ok, "every landmark maps onto the v2 one")
	var m := BodyMaterials.skin_material(CharacterPeoples.preset_look("english_m_a"))
	var h0: Vector4 = m.get_shader_parameter("fd_h0")
	_check(absf(h0.x - float(h[0])) < 1e-4 and absf(h0.w - float(h[3])) < 1e-4, "the skin material takes the warp")
	var lm: Dictionary = face.get("landmarks", {})
	for k in ["ear_l", "ear_r", "rim_l1", "rim_r1", "septum", "nostril_l"]:
		_check(lm.get(k) is Array and (lm[k] as Array).size() == 3, "landmark %s" % k)
	if lm.get("ear_l") is Array and lm.get("septum") is Array:
		_check(float(lm.ear_l[0]) > 0.05 and float(lm.ear_l[1]) > 1.38 and float(lm.ear_l[1]) < 1.47, "the left lobe on the head's left side (%s)" % [lm.ear_l])
		_check(absf(float(lm.septum[0])) < 0.003 and float(lm.septum[2]) > 0.1, "the septum on the midline, in front (%s)" % [lm.septum])


func _test_look() -> void:
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(inst)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var body := CharacterBodyMesh.attach(sk, ap)
	var lk := CreatorOptions.with_people({"sex": 1.0}, "arab")
	lk["face"] = (lk.face as Dictionary).duplicate()
	lk.face["face_nose_length"] = 0.8
	PlayerAppearance.dress(body, lk)
	var hm := FaceExtras.head_mesh(body)
	_check(hm != null, "the head mesh found")
	if hm:
		var i := hm.find_blend_shape_by_name(&"face_nose_length")
		_check(i >= 0 and is_equal_approx(hm.get_blend_shape_value(i), 0.8), "a face weight reaches the head's shape")
		var sx := maxf(hm.get_blend_shape_value(hm.find_blend_shape_by_name(&"sex")),
				hm.get_blend_shape_value(hm.find_blend_shape_by_name(&"sex_head")))
		_check(is_equal_approx(sx, 1.0), "the male fit reaches the head (sex or sex_head 1)")
	var fb := FaceBlink.new()
	fb.body = body
	body.add_child(fb)
	# step 2: a full beard's shells within the fur budget, the jewellery at the new landmarks
	var bl := lk.duplicate(true)
	bl["facial_hair"] = "beard_full"
	PlayerAppearance.dress(body, bl)
	var shells: Array = body.part_meshes(FaceExtras.PART_BEARD)
	var tris := 0
	for mi: MeshInstance3D in shells:
		for s in mi.mesh.get_surface_count():
			tris += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	_check(not shells.is_empty() and tris > 2000 and tris <= 40000, "a full beard within the fur budget (%d triangles)" % tris)
	if hm:
		var lmk := FaceExtras.landmarks(hm)
		var want: Dictionary = (BodyMaterials.body_info().get("face", {}) as Dictionary).get("landmarks", {})
		var near := true
		for k in ["ear_l", "septum"]:
			if lmk.has(k) and want.get(k) is Array:
				near = near and (lmk[k] as Vector3).distance_to(Vector3(want[k][0], want[k][1], want[k][2])) < 0.012
		_check(near and lmk.has("ear_l") and lmk.has("septum"), "FaceExtras finds the ear lobe and septum at the new landmarks")
	fb.set_blink(1.0)
	var closed := false
	for mi: MeshInstance3D in body.meshes:
		var j := mi.find_blend_shape_by_name(&"blink")
		if j >= 0 and is_equal_approx(mi.get_blend_shape_value(j), 1.0):
			closed = true
	_check(closed, "FaceBlink closes the lids (blink 1)")
	inst.queue_free()
	await _frames(2)
