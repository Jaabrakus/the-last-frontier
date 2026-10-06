extends SceneTree
## Clothing: the fabric kits, the cloth attributes baked into the legacy outfit and every garment
## glb, the cloth materials on the player, and the kept garments of the catalog (PlayerOutfit; the period sets and the
## winter furs were retired in the 2026-10-06 cleanup), with the customizer's Outfit tab. Headless, about 20 s.
##
##   Godot --headless --path . -s tests/customizer/test_clothing.gd
##
## Exit code 0 and "CLOTHING TEST OK" when every check passes; 1 and the failures otherwise.
## Run it under a hard time limit like every Godot run. It never writes the saved look
## (user://appearance/current.json); the overlay step is cancelled.
##
## Checks:
##   - assets/character/fabrics: the detail and normal arrays load as TextureLayered with one layer
##     per fabric code of fabrics.json
##   - actor_b_body.glb (tools/character/cloth_bake.py): every Clothes / Gear / Hat surface has UV
##     (metres, a sane range), UV2 piece codes (the coat 1, the shoes 8, the shoe buckles 24...),
##     CUSTOM0 (edge distances, dirt, wear), CUSTOM1 (sweat, push class, seam distance) and
##     CUSTOM2 (cavity, folds); the Gear's pouch and horn have a push direction in TANGENT
##   - every garment glb has CUSTOM0..2 (dirt / wear / sweat / seams / folds) on every surface
##   - the player (the bare body v4 since 2026-09-28, the garments off until the garments pass): no legacy
##     outfit mesh drawn, no garment worn even with an outfit in the look, the whole skin drawn, the slung
##     gear on the skin

const FABRICS := "res://assets/character/fabrics/fabrics.json"
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
	_test_fabrics()
	_test_legacy_glb()
	_test_garment_glbs()
	await _test_player()
	print("CLOTHING TEST %s (%d checks%s)" % ["OK" if _fails.is_empty() else "FAILED", _checks,
			"" if _fails.is_empty() else ", %d failed" % _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _test_fabrics() -> void:
	var f := ClothMaterials.fabrics()
	_check(f.size() == 9, "fabrics.json has 9 fabric codes (%d)" % f.size())
	for p in [ClothMaterials.DETAIL, ClothMaterials.NORMAL]:
		var t = load(p)
		_check(t is TextureLayered, "%s loads as a TextureLayered" % p.get_file())
		if t is TextureLayered:
			_check((t as TextureLayered).get_layers() == f.size(), "%s has a layer per fabric" % p.get_file())


func _surfaces(scene_path: String) -> Array:
	var out := []
	var inst := (load(scene_path) as PackedScene).instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var name: String = mesh.surface_get_material(s).resource_name if mesh.surface_get_material(s) else mesh.surface_get_name(s)
			out.append([String(mi.name), name, mesh.surface_get_arrays(s), mesh.surface_get_format(s)])
	inst.free()
	return out


func _test_legacy_glb() -> void:
	var codes := {}
	for sf: Array in _surfaces(CharacterBodyMesh.DEFAULT_PATH):
		if not String(sf[0]) in ClothMaterials.LEGACY_MESHES:
			continue
		var tag := "%s/%s" % [sf[0], sf[1]]
		var a: Array = sf[2]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
		_check(uv.size() > 0 and uv2.size() == uv.size(), "%s has UV and UV2" % tag)
		if uv.is_empty():
			continue
		var lo := Vector2(INF, INF)
		var hi := -lo
		for p in uv:
			lo = lo.min(p)
			hi = hi.max(p)
		_check((hi - lo).x < 3.0 and (hi - lo).y < 3.0 and (hi - lo).x > 0.01, "%s UV in metres (%s)" % [tag, hi - lo])
		for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2]:
			_check(a[c] != null and (a[c] as PackedFloat32Array).size() >= uv.size() * 2, "%s has CUSTOM%d" % [tag, c - Mesh.ARRAY_CUSTOM0])
		var fmt: int = sf[3]
		_check(((fmt >> Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) & Mesh.ARRAY_FORMAT_CUSTOM_MASK) == Mesh.ARRAY_CUSTOM_RGBA_FLOAT,
				"%s CUSTOM0 is RGBA float (edges, dirt, wear)" % tag)
		for p in uv2:
			var c := int(p.x + 0.5)
			if not codes.has(c):
				codes[c] = []
			if not String(sf[1]) in codes[c]:
				(codes[c] as Array).append(String(sf[1]))
		if String(sf[0]) == "Gear" and String(sf[1]) in ["pouch", "horn"]:
			var tan: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
			_check(tan.size() >= 4 and Vector3(tan[0], tan[1], tan[2]).length() > 0.9, "Gear/%s has a push direction" % sf[1])
	var P := ClothMaterials.LEGACY_PIECES
	for want in [["coat", P.coat], ["shoe", P.shoe], ["brass", ClothMaterials.BRASS_BASE + P.shoe],
			["brass", ClothMaterials.BRASS_BASE + P.waistcoat], ["belt", P.belt], ["felt", P.felt]]:
		_check(codes.has(want[1]) and String(want[0]) in codes[want[1]], "piece code %d on %s (%s)" % [want[1], want[0], codes.get(want[1], [])])


func _test_garment_glbs() -> void:
	var n := 0
	for dir in DirAccess.get_directories_at("res://assets/character/garments"):
		var base := "res://assets/character/garments/%s/" % dir
		for f in DirAccess.get_files_at(base):
			if not f.ends_with(".glb"):
				continue
			n += 1
			var ok := true
			for sf: Array in _surfaces(base + f):
				var a: Array = sf[2]
				for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2]:
					if a[c] == null:
						ok = false
			_check(ok, "%s%s has the cloth masks (CUSTOM0..2)" % [dir + "/", f])
	_check(n >= 20, "garment glbs found (%d)" % n)
	# the kept garments: the basic dress and the arena's (2026-10-06: the period sets retired, these six and salvar_mens
	# kept as the defaults, owner answer O5), and the ring dress
	for id in ["shirt_tucked", "breeches", "sash_worsted", "shift_linen", "petticoat", "shirt_linen", "salvar_mens",
			"ring_earth_tunic", "ring_trousers_wrapped", "ring_arm_wraps"]:
		var e := PlayerOutfit.entry(id)
		_check(not e.is_empty() and ResourceLoader.exists(String(e.get("glb", ""))), "catalog has %s with its glb" % id)


func _cloth_mats(body: CharacterBodyMesh, names: Array) -> Array:
	var out := []
	for mi: MeshInstance3D in body.meshes:
		if is_instance_valid(mi) and String(mi.name) in names and mi.mesh:
			for s in mi.mesh.get_surface_count():
				out.append(mi.get_surface_override_material(s))
	return out


func _test_player() -> void:
	# cloth2 (2026-09-28): everyone wears the basic dress unless the look chooses: a shirt and breeches, a shift and a
	# petticoat; "-" takes a slot off; the garments follow the male fit and the bust gauge
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	var player: FrontierPlayer = current_scene.get_node("Player")
	var app := player.appearance
	_check(app != null, "player has a PlayerAppearance")
	if app == null:
		return
	var body := app.body
	var lk := AppearanceStore.default_look()
	app.apply(lk)
	await _frames(2)
	var own := {}
	for t in body.parts:
		for pm in body.parts[t]:
			own[pm] = true
	var shown := []
	for mi: MeshInstance3D in body.meshes:
		if not own.has(mi) and mi.visible:
			shown.append(String(mi.name))
	_check(shown.is_empty(), "no legacy outfit mesh drawn (%s)" % [shown])
	var man := PlayerOutfit.effective({}, 1.0)
	var woman := PlayerOutfit.effective({}, 0.0)
	_check(String(man.get("shirt", {}).get("id", "")) == "shirt_tucked" and String(man.get("legs.lower", {}).get("id", "")) == "breeches",
			"a man's basic dress: a shirt tucked into breeches (%s)" % [man.keys()])
	_check(String(woman.get("shirt", {}).get("id", "")) == "shift_linen" and String(woman.get("legs.lower", {}).get("id", "")) == "petticoat",
			"a woman's basic dress: a shift and a petticoat (%s)" % [woman.keys()])
	_check(not body.part_meshes("outfit:shirt").is_empty() and not body.part_meshes("outfit:legs.lower").is_empty(),
			"the default look wears its basic dress")
	_check(PlayerOutfit.bulk_key(app.outfit_slots) == "shirt_only", "the slung gear rests on the shirt (%s)" % PlayerOutfit.bulk_key(app.outfit_slots))
	var skin: ShaderMaterial = null
	for mi: MeshInstance3D in body.part_meshes("head"):
		var m := mi.get_surface_override_material(0) as ShaderMaterial
		if m and m.shader.resource_path.ends_with("skin.gdshader"):
			skin = m
	var hidden: Array = []
	for slot: String in ["shirt", "legs.lower"]:
		hidden.append_array(PlayerOutfit.entry(String(man[slot].id)).get("hides_regions", []))
	_check(skin != null and skin.get_shader_parameter("hide_mask") == BodyMaterials.hide_mask(hidden),
			"the skin under the garments is hidden (the regions they cover)")
	_check(body.part_meshes("body_hair").is_empty(), "the pubic hair is under the breeches, not drawn")
	# the garments follow the body: the male fit, the bust gauge
	for slot: String in ["shirt", "legs.lower"]:
		var gm: MeshInstance3D = body.part_meshes("outfit:" + slot)[0]
		var si := gm.find_blend_shape_by_name("sex")
		_check(si >= 0 and is_equal_approx(gm.get_blend_shape_value(si), 1.0), "%s follows the male fit (sex 1)" % slot)
	var wl := AppearanceStore.validate(CharacterPeoples.preset_look("english_f_a"))
	wl["bust"] = 0.8
	app.apply(wl)
	await _frames(2)
	var shift: MeshInstance3D = body.part_meshes("outfit:shirt")[0]
	var bi := shift.find_blend_shape_by_name("breast_large")
	_check(bi >= 0 and shift.get_blend_shape_value(bi) > 0.7, "a woman's shift follows the bust gauge (breast_large %.2f)" % (shift.get_blend_shape_value(bi) if bi >= 0 else -1.0))
	_check(String((shift.get_meta("garment", ""))) == "shift_linen", "she wears the shift, not the shirt")
	_check(app.body.soft_support >= 1.0, "a garment over the chest holds the breasts steadier (soft_support %.1f)" % app.body.soft_support)
	# taking everything off: bare, the gear on the skin, the pubic hair drawn
	var bare := AppearanceStore.validate(CharacterPeoples.preset_look("english_m_a"))
	bare["outfit"] = {"shirt": {"id": "-"}, "legs.lower": {"id": "-"}}
	app.apply(bare)
	await _frames(2)
	_check(body.part_meshes("outfit:shirt").is_empty() and body.part_meshes("outfit:legs.lower").is_empty(), "\"-\" takes the garments off")
	_check(PlayerOutfit.bulk_key(app.outfit_slots) == "bare", "bare: the gear rests on the skin")
	_check(not body.part_meshes("body_hair").is_empty(), "bare: the pubic hair is drawn")
	# a slot's choices: the basic piece first, none last, every garment for both body types (the owner, 2026-10-03: "give
	# everyone the ability to wear anything on starting"); the basic piece stays the body type's
	var sh_m := PlayerOutfit.offered("legs.lower", 1.0)
	var sh_f := PlayerOutfit.offered("legs.lower", 0.0)
	_check(sh_m[0] == "" and sh_m[sh_m.size() - 1] == "-" and "breeches" in sh_m and "petticoat" in sh_m, "men are offered breeches and the petticoat (%s)" % [sh_m])
	_check(sh_f == sh_m, "women the same (%s)" % [sh_f])
	_check(PlayerOutfit.cut_for("breeches", 1.0) and not PlayerOutfit.cut_for("breeches", 0.0) and PlayerOutfit.cut_for("petticoat", 0.0)
			and not PlayerOutfit.cut_for("petticoat", 1.0), "cut_for: breeches cut for men, the petticoat for women")
	_check(PlayerOutfit.item_name("legs.lower", "", 1.0).contains(String(PlayerOutfit.entry("breeches").get("name", "?")))
			and PlayerOutfit.item_name("legs.lower", "", 0.0).contains(String(PlayerOutfit.entry("petticoat").get("name", "?"))),
			"the basic piece stays the body type's (%s / %s)" % [PlayerOutfit.item_name("legs.lower", "", 1.0), PlayerOutfit.item_name("legs.lower", "", 0.0)])
	# a woman in breeches and a man in the petticoat dress (cloth2 builds every cut on both fits)
	var wb := AppearanceStore.validate(CharacterPeoples.preset_look("english_f_a"))
	wb["outfit"] = {"legs.lower": {"id": "breeches", "colors": {}}, "shirt": {"id": "shirt_tucked", "colors": {}}}
	app.apply(wb)
	await _frames(2)
	var br: Array = body.part_meshes("outfit:legs.lower")
	_check(not br.is_empty() and String((br[0] as Node).get_meta("garment", "")) == "breeches", "a woman wears breeches")
	var mp := AppearanceStore.validate(CharacterPeoples.preset_look("english_m_a"))
	mp["outfit"] = {"legs.lower": {"id": "petticoat", "colors": {}}}
	app.apply(mp)
	await _frames(2)
	var pc: Array = body.part_meshes("outfit:legs.lower")
	var psi := (pc[0] as MeshInstance3D).find_blend_shape_by_name("sex") if not pc.is_empty() else -1
	_check(not pc.is_empty() and String((pc[0] as Node).get_meta("garment", "")) == "petticoat" and psi >= 0
			and is_equal_approx((pc[0] as MeshInstance3D).get_blend_shape_value(psi), 1.0), "a man wears the petticoat, on the male fit")
