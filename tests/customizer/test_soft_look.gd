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
##   palette   every cloth zone takes one of the study's colours (the ring dress too: the player's side dark, the other light);
##             a metal zone is never recoloured
##   sides     every element's home and away dress (RingSides) stay as far apart as before in value and nearly as far in colour
##   off       a body marked META_OFF stays classic in Soft (the creator's figure no longer is: it shows the chosen look)
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
	_check(rows.find_child("Look", true, false) != null, "the Settings rows hold the Look")
	rows.free()
	var rows2 := GameSettings.rows(null, false)
	_check(rows2.find_child("Look", true, false) != null, "the serif Settings rows hold the Look")
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
		var swapped := cs.code
		for swap: Array in SoftLook.STUDY_SWAPS:
			swapped = swapped.replace(String(swap[0]), String(swap[1]))
		_check(SoftLook.is_soft(sm.shader) and sm.shader.code == SoftLook.with_ambient_share(swapped) + "\n" + SoftLook.STUDY_LIGHT,
				"the soft shader is the classic code with the study's swaps, its ambient share and its light()")
		_check(not sm.shader.code.contains("specular_schlick_ggx"), "no GGX specular in a soft shader (no plastic shine)")
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
			var l1 := _lab(t1)
			var is_study := false
			for k: String in SoftLook.PALETTE:
				if (t1 as Vector4).is_equal_approx(ClothMaterials.lin4(Color(SoftLook.PALETTE[k]))):
					is_study = true
			_check(is_study, "every cloth zone takes a study colour (%s z%d)" % [(e[0] as Node).name, z])
			if team:
				team_n += 1
			else:
				every_n += 1
				print("  palette %s z%d %s -> %s" % [(e[0] as Node).name, z, Color(t0.x, t0.y, t0.z).linear_to_srgb().to_html(false),
						Color(t1.x, t1.y, t1.z).linear_to_srgb().to_html(false)])
			if l1.x < 0.0:
				_check(false, "a soft tint is a colour")
	_check(team_n > 0, "the ring dress was measured (%d zones)" % team_n)
	_check(every_n > 0, "the everyday dress was measured (%d zones)" % every_n)

	# ---- sides: in the ring the player's side wears the study's dark main colour, the other side its light one (the owner chose
	# "study colours, light vs dark", 2026-10-10); the element is in the trims. (In a match: RingSides.sides_override stands in
	# for one; outside a match everyone wears the player's dark side, checked after.)
	for el: String in Bending.ELEMENTS:
		RingSides.sides_override = [[el], [el]]
		var means := []
		for dark in [true, false]:
			var holder := Node3D.new()
			root.add_child(holder)
			if dark:
				holder.add_to_group("player")
			var sb := _body()
			var actor: Node = sb
			while actor.get_parent() != _holder:
				actor = actor.get_parent()
			actor.reparent(holder)
			var lk := look.duplicate(true)
			lk["outfit"] = PlayerAppearance.arena_outfit(el, float(lk.get("sex", 0.0)))
			PlayerAppearance.dress(sb, lk)
			var acc := Vector3.ZERO
			var n := 0
			for e: Array in _surfaces(sb):
				var m := e[2] as Material
				var gid := String((e[0] as Node).get_meta("garment", ""))
				if not m.has_meta(SoftLook.META_CLASSIC) or not SoftLook.team_garment(gid):
					continue
				if not ("tunic" in gid or "top" in gid or "parka" in gid):
					continue
				var t: Variant = (m as ShaderMaterial).get_shader_parameter("tint0")
				if t is Vector4:
					acc += _lab(t)
					n += 1
			means.append([acc / maxf(n, 1), n])
			holder.queue_free()
		if means[0][1] == 0 or means[1][1] == 0:
			continue
		var dv: float = (means[1][0] as Vector3).x - (means[0][0] as Vector3).x
		print("  sides %s: main garment lightness dark %.3f, light %.3f" % [el, (means[0][0] as Vector3).x, (means[1][0] as Vector3).x])
		_check(dv > 0.15, "%s: the other side's main garment is clearly lighter than the player's (%.3f)" % [el, dv])
	RingSides.sides_override = null
	# outside a match (the lobby's figure): the player's side, the study's teal, whoever wears it
	var lb := _body()
	var llk := look.duplicate(true)
	llk["outfit"] = PlayerAppearance.arena_outfit("earth", float(llk.get("sex", 0.0)))
	PlayerAppearance.dress(lb, llk)
	var teal := ClothMaterials.lin4(Color(SoftLook.PALETTE["teal"]))
	var main_teal := 0
	for e: Array in _surfaces(lb):
		var gid := String((e[0] as Node).get_meta("garment", ""))
		if (e[2] as Material).has_meta(SoftLook.META_CLASSIC) and SoftLook.team_garment(gid) and ("tunic" in gid or "top" in gid or "parka" in gid):
			var t: Variant = ((e[2] as ShaderMaterial).get_shader_parameter("tint0"))
			if t is Vector4 and (t as Vector4).is_equal_approx(teal):
				main_teal += 1
	_check(main_teal > 0, "outside a match a fighter's main garment is the study's teal")

	# ---- creator's figure
	var cb := _body()
	cb.set_meta(SoftLook.META_OFF, true)
	PlayerAppearance.dress(cb, look)
	var any_soft := false
	for e: Array in _surfaces(cb):
		any_soft = any_soft or (e[2] as Material).has_meta(SoftLook.META_CLASSIC)
	_check(not any_soft, "a body marked META_OFF stays classic in Soft")

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
