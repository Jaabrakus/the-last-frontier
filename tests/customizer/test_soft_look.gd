extends SceneTree
## The Character look (SoftLook: Classic / Soft). Headless, no scene, nothing of the player's saved (its settings in a file of
## its own).
##   Godot --headless --path . -s tests/customizer/test_soft_look.gd
## Ends with "SOFT LOOK TEST OK (<n> checks)" (exit 0) or "SOFT LOOK TEST FAILED (<f> of <n>)" (exit 1).
##   setting   the default is Soft; set_mode keeps it in GameSettings [look] character and reads back; the run argument wins
##   classic   in Classic, dress() leaves every material exactly as it made it (no copy, no change)
##   swap      Soft puts a soft copy on every part surface of every kind (skin, eyes, hair, garments), each copy's shader a soft
##             copy of the classic one (the classic code whole, plus light()), one soft shader per classic shader; Classic gives
##             the SAME classic materials back with every number as it was, except what the game changed on the copy meanwhile
##             (a hide mask), which is carried back; swapping again and again changes nothing more
##   palette   a side's garment (the ring set) keeps its hue and lightness (chroma only a little less); the everyday dress moves
##             toward the study colours; a metal zone is never recoloured
##   sides     every element's home and away dress (RingSides) stay as far apart as before in value and nearly as far in colour
##   creator   a body marked META_OFF stays classic in Soft
##   child     ChildSkin works on the classic skin and the body is soft again after

const OWN_CFG := "user://soft_look_test.cfg"

var _fails: Array[String] = []
var _checks := 0
var _holder: Node3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)
		print("  FAIL ", what)


func _initialize() -> void:
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	_holder = Node3D.new()
	root.add_child(_holder)
	_run.call_deferred()


func _body() -> CharacterBodyMesh:
	var actor := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	_holder.add_child(actor)
	var sk := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	return CharacterBodyMesh.attach(sk, ap)


## Every part surface's override material: [[mesh, surface, material], ...].
static func _surfaces(b: CharacterBodyMesh) -> Array:
	var out: Array = []
	for tag: String in b.parts:
		for mi in b.parts[tag]:
			if not is_instance_valid(mi) or (mi as MeshInstance3D).mesh == null:
				continue
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				var m := (mi as MeshInstance3D).get_surface_override_material(s)
				if m != null:
					out.append([mi, s, m])
	return out


## A material's every uniform value (and its shader).
static func _snap(m: Material) -> Dictionary:
	var out := {"__shader": (m as ShaderMaterial).shader if m is ShaderMaterial else null}
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		for u: Dictionary in (m as ShaderMaterial).shader.get_shader_uniform_list():
			out[String(u.name)] = (m as ShaderMaterial).get_shader_parameter(String(u.name))
	return out


static func _same_snap(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or typeof(a[k]) != typeof(b[k]) or a[k] != b[k]:
			return false
	return true


static func _lab(v: Vector4) -> Vector3:
	return SoftLook.lin_to_oklab(Vector3(v.x, v.y, v.z))


static func _hue(l: Vector3) -> float:
	return atan2(l.z, l.y)


func _run() -> void:
	await process_frame
	# ---- setting
	SoftLook.override = ""
	_check(SoftLook.default_mode(false) == SoftLook.SOFT, "the game's default look is Soft")
	_check(SoftLook.default_mode(true) == SoftLook.CLASSIC and SoftLook.mode() == SoftLook.CLASSIC,
			"a script run that has not chosen is Classic (got %s)" % SoftLook.mode())
	SoftLook.set_mode(SoftLook.CLASSIC, self)
	_check(String(GameSettings.get_value("look", "character")) == "classic" and SoftLook.mode() == SoftLook.CLASSIC,
			"set_mode(classic) is kept in GameSettings")
	SoftLook.set_mode(SoftLook.SOFT, self)
	_check(String(GameSettings.get_value("look", "character")) == "soft" and SoftLook.mode() == SoftLook.SOFT,
			"set_mode(soft) is kept")
	var rows := GameSettings.rows(null, true)
	_check(rows.find_child("Characterlook", true, false) != null, "the Settings rows hold the Character look")
	rows.free()
	var rows2 := GameSettings.rows(null, false)
	_check(rows2.find_child("Characterlook", true, false) != null, "the serif Settings rows hold the Character look")
	rows2.free()

	# ---- classic: dress leaves the materials as made
	SoftLook.override = SoftLook.CLASSIC
	var look := AppearanceStore.validate(CharacterPeoples.preset_look("vietnamese_f_a"))
	var b := _body()
	PlayerAppearance.dress(b, look)
	var classic := _surfaces(b)
	_check(classic.size() >= 6, "the dressed body has its surfaces (%d)" % classic.size())
	var snaps := {}
	for e: Array in classic:
		_check(not (e[2] as Material).has_meta(SoftLook.META_CLASSIC), "Classic puts no soft copy on %s/%d" % [(e[0] as Node).name, e[1]])
		snaps[e[2]] = _snap(e[2])
		var sh: Shader = (e[2] as ShaderMaterial).shader if e[2] is ShaderMaterial else null
		_check(sh == null or not SoftLook.is_soft(sh), "Classic draws with the classic shader")
	_check(b.is_in_group(SoftLook.GROUP), "a dressed body joins the look's group")

	# ---- swap to soft
	SoftLook.override = SoftLook.SOFT
	SoftLook.refresh(self)
	var kinds := {}
	var per_shader := {}
	var soft_set := _surfaces(b)
	for i in soft_set.size():
		var m := soft_set[i][2] as Material
		var was := classic[i][2] as Material
		if not SoftLook.softenable(was):
			_check(m == was, "a surface the look does not take stays as it was")
			continue
		_check(m != was and m.get_meta(SoftLook.META_CLASSIC) == was, "Soft puts a soft copy over its classic material")
		var sm := m as ShaderMaterial
		var cs := (was as ShaderMaterial).shader
		_check(SoftLook.is_soft(sm.shader) and sm.shader.code.begins_with(cs.code) \
				and sm.shader.code.contains("void light()"), "the soft shader is the classic code whole plus light()")
		kinds[SoftLook.kind_of(cs)] = true
		if per_shader.has(cs):
			_check(per_shader[cs] == sm.shader, "one soft shader per classic shader")
		per_shader[cs] = sm.shader
		_check(_same_snap(snaps[was], _snap(was)), "the classic material itself is untouched by Soft")
	for k: String in ["skin", "eye", "hair", "cloth"]:
		_check(kinds.has(k), "Soft takes the %s" % k)

	# the game changes a number on what it finds (a hide mask, as PlayerAppearance._set_hide does)
	var cloth_mi: MeshInstance3D = null
	var cloth_s := -1
	for e: Array in soft_set:
		if e[2] is ShaderMaterial and SoftLook.kind_of(((e[2] as Material).get_meta(SoftLook.META_CLASSIC) as ShaderMaterial).shader) == "cloth":
			cloth_mi = e[0]
			cloth_s = e[1]
			break
	_check(cloth_mi != null, "a garment surface is there")
	var new_mask := Vector2i(5, 9)
	if cloth_mi != null:
		(cloth_mi.get_surface_override_material(cloth_s) as ShaderMaterial).set_shader_parameter("hide_mask", new_mask)

	# ---- back to classic: the same materials, the same numbers, the game's change carried back
	SoftLook.override = SoftLook.CLASSIC
	SoftLook.refresh(self)
	var back := _surfaces(b)
	for i in back.size():
		var was := classic[i][2] as Material
		_check(back[i][2] == was, "Classic gives the same classic material back (%s/%d)" % [(back[i][0] as Node).name, back[i][1]])
		var exp: Dictionary = snaps[was].duplicate()
		if back[i][0] == cloth_mi and back[i][1] == cloth_s:
			exp["hide_mask"] = new_mask
		_check(_same_snap(exp, _snap(was)), "Classic's numbers are as before (%s/%d)" % [(back[i][0] as Node).name, back[i][1]])
	# again and again
	for n in 3:
		SoftLook.override = SoftLook.SOFT
		SoftLook.refresh(self)
		SoftLook.override = SoftLook.CLASSIC
		SoftLook.refresh(self)
	var again := _surfaces(b)
	var still := true
	for i in again.size():
		still = still and again[i][2] == classic[i][2]
	_check(still, "swapping again and again ends on the same classic materials")
	# a fresh dress in Classic after all of that: identical numbers to the first dress (Classic is bit for bit the old look)
	var b2 := _body()
	PlayerAppearance.dress(b2, look)
	var fresh := _surfaces(b2)
	_check(fresh.size() == classic.size(), "a second classic dress has the same surfaces")
	for i in mini(fresh.size(), classic.size()):
		var a := _snap(fresh[i][2])
		var o := _snap(classic[i][2])
		a.erase("seed")
		o.erase("seed")
		var mi_c := classic[i][0] as MeshInstance3D
		if mi_c == cloth_mi and classic[i][1] == cloth_s:
			o.erase("hide_mask")
			a.erase("hide_mask")
		_check(_same_snap(a, o), "a fresh classic dress has the first one's numbers (%s/%d)" % [(fresh[i][0] as Node).name, fresh[i][1]])

	# ---- palette
	SoftLook.override = SoftLook.SOFT
	var ring := _body()
	var rlook := look.duplicate(true)
	rlook["outfit"] = PlayerAppearance.arena_outfit("earth", float(rlook.get("sex", 0.0)))
	PlayerAppearance.dress(ring, rlook)
	var everyday := _body()
	PlayerAppearance.dress(everyday, look)
	var team_n := 0
	var every_n := 0
	for e: Array in _surfaces(ring) + _surfaces(everyday):
		var m := e[2] as Material
		if not m.has_meta(SoftLook.META_CLASSIC):
			continue
		var cm := m.get_meta(SoftLook.META_CLASSIC) as ShaderMaterial
		if SoftLook.kind_of(cm.shader) != "cloth" or cm.get_shader_parameter("tint0") == null:
			continue
		var team := SoftLook.team_garment(String((e[0] as Node).get_meta("garment", "")))
		var metal: Variant = cm.get_shader_parameter("metal")
		for z in 4:
			var t0: Variant = cm.get_shader_parameter("tint%d" % z)
			var t1: Variant = (m as ShaderMaterial).get_shader_parameter("tint%d" % z)
			if not (t0 is Vector4 and t1 is Vector4):
				continue
			if metal is Vector4 and (metal as Vector4)[z] > 0.5:
				_check(t0 == t1, "a metal zone keeps its colour")
				continue
			var l0 := _lab(t0)
			var l1 := _lab(t1)
			if team:
				team_n += 1
				var c0 := Vector2(l0.y, l0.z).length()
				_check(absf(l0.x - l1.x) < 0.004, "a side's garment keeps its lightness (%.3f -> %.3f)" % [l0.x, l1.x])
				_check(c0 < 0.02 or absf(angle_difference(_hue(l0), _hue(l1))) < deg_to_rad(2.0), "a side's garment keeps its hue")
				_check(Vector2(l1.y, l1.z).length() <= c0 + 0.0005, "a side's garment is no more saturated")
			else:
				every_n += 1
				var sw := SoftLook.nearest_swatch(l0)
				_check(l1.distance_to(sw) <= l0.distance_to(sw) + 0.0005, "the everyday dress moves toward the study colours")
				print("  palette %s z%d %s -> %s" % [(e[0] as Node).name, z, Color(t0.x, t0.y, t0.z).linear_to_srgb().to_html(false),
						Color(t1.x, t1.y, t1.z).linear_to_srgb().to_html(false)])
	_check(team_n > 0, "the ring dress was measured (%d zones)" % team_n)
	_check(every_n > 0, "the everyday dress was measured (%d zones)" % every_n)

	# ---- sides: home and away of every element, as the soft look draws them (the zone-0 tints of each garment, averaged)
	for el: String in Bending.ELEMENTS:
		RingSides.sides_override = [[el], [el]]
		var means := []
		for team in 2:
			var dress: Dictionary = RingSides.dress(team, el)
			var acc0 := Vector3.ZERO
			var acc1 := Vector3.ZERO
			var n := 0
			for slot: String in dress:
				var v: Variant = dress[slot]
				if not (v is Dictionary and String((v as Dictionary).get("id", "-")) != "-"):
					continue
				var id := String(v.id)
				var mats := ClothMaterials.garment_materials(PlayerOutfit.entry(id), PlayerOutfit.resolve_colors(id, v.get("colors", {})))
				for k in mats:
					var cm := mats[k] as ShaderMaterial
					var t: Variant = cm.get_shader_parameter("tint0")
					if t is Vector4:
						acc0 += _lab(t)
						acc1 += _lab(SoftLook.soften_lin(t, SoftLook.team_garment(id)))
						n += 1
			means.append([acc0 / maxf(n, 1), acc1 / maxf(n, 1), n])
		RingSides.sides_override = null
		if means[0][2] == 0 or means[1][2] == 0:
			continue
		var d0: float = (means[0][0] as Vector3).distance_to(means[1][0])
		var d1: float = (means[0][1] as Vector3).distance_to(means[1][1])
		var v0: float = absf((means[0][0] as Vector3).x - (means[1][0] as Vector3).x)
		var v1: float = absf((means[0][1] as Vector3).x - (means[1][1] as Vector3).x)
		print("  sides %s: dE %.1f -> %.1f, value %.3f -> %.3f" % [el, d0 * 100.0, d1 * 100.0, v0, v1])
		_check(d1 >= 0.84 * d0, "%s's sides stay apart in colour (dE %.1f -> %.1f)" % [el, d0 * 100.0, d1 * 100.0])
		_check(absf(v1 - v0) < 0.005, "%s's sides keep their value difference (%.3f -> %.3f)" % [el, v0, v1])

	# ---- creator's figure
	var cb := _body()
	cb.set_meta(SoftLook.META_OFF, true)
	PlayerAppearance.dress(cb, look)
	var any_soft := false
	for e: Array in _surfaces(cb):
		any_soft = any_soft or (e[2] as Material).has_meta(SoftLook.META_CLASSIC)
	_check(not any_soft, "the creator's figure (META_OFF) stays classic in Soft")

	# ---- a child's skin
	var kid := _body()
	PlayerAppearance.dress(kid, look)
	ChildSkin.apply(kid, 0.8)
	var skins := 0
	var fuzz := 0
	for e: Array in _surfaces(kid):
		var m := e[2] as Material
		if m.has_meta(SoftLook.META_CLASSIC):
			var cm := m.get_meta(SoftLook.META_CLASSIC) as ShaderMaterial
			if SoftLook.kind_of(cm.shader) == "skin":
				skins += 1
				if cm.shader == ChildSkin.fuzz_shader():
					fuzz += 1
	_check(skins > 0 and fuzz == skins, "ChildSkin softens the classic skin (%d of %d) and the body is soft again" % [fuzz, skins])

	SoftLook.override = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	_holder.queue_free()
	await process_frame
	if _fails.is_empty():
		print("SOFT LOOK TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("SOFT LOOK TEST FAILED (%d of %d)" % [_fails.size(), _checks])
		quit(1)
