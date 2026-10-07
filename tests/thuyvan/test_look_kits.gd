extends SceneTree
## The Thủy Vân look's kits as imported (tools/thuyvan_art/godot/write_godot_import.py, ThuyVanKit). Headless:
##
##   Godot --headless --path . -s tests/thuyvan/test_look_kits.gd
##
##   rock       every piece in rock_kit.json loads with its _lod1, and every surface wears its key's shared material
##              from assets/thuyvan/rock/materials (set at import)
##   village    every piece in manifest.json loads, every surface wears its tvv_<key> material, and the rope bridge's
##              "-colonly" decks are static collision bodies (as many as the manifest lists), with no deck mesh drawn
##   plants     every species and variant in vegetation.json gives a near and a far mesh with its foliage material
##   textures   the terrain array is a 2D array of terrain_slices.json's slices; the grade LUTs are 64³ Texture3Ds; the
##              sky panoramas and painted textures import VRAM-compressed with mipmaps
##   font       UiFonts' sans is the shipped Be Vietnam Pro
## Ends with "LOOK KITS TEST PASSED (<n> checks)" or "LOOK KITS TEST FAILED (<f> of <n>)".

const Kit := preload("res://scripts/thuyvan/look/thuyvan_kit.gd")
const TV := "res://assets/thuyvan/"

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_rock()
	_village()
	_plants()
	_textures()
	_font()
	if fails.is_empty():
		print("LOOK KITS TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("LOOK KITS TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		print("  FAIL " + what)
		fails.append(what)


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Every surface of every mesh under `n` wears a material saved under `dir` named as its key (resource_name).
func _materials_from(n: Node, dir: String, what: String) -> int:
	var bad := []
	var surfaces := 0
	for mi in Kit._meshes(n):
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			var m := mi.get_active_material(s)
			if m == null or not m.resource_path.begins_with(dir):
				bad.append("%s#%d %s" % [mi.name, s, m.resource_path if m else "(none)"])
	_expect(bad.is_empty() and surfaces > 0, "%s: %d surfaces all wear %s materials %s" % [what, surfaces, dir, str(bad)])
	return surfaces


func _rock() -> void:
	var meta: Dictionary = _json(TV + "rock/rock_kit.json")
	var pieces: Dictionary = meta["pieces"]
	for piece: String in pieces:
		var n := Kit.rock(piece)
		_expect(n != null, "rock: %s loads" % piece)
		if n == null:
			continue
		_materials_from(n, TV + "rock/materials/", "rock " + piece)
		n.free()
	_expect(pieces.size() >= 30, "rock: %d pieces in rock_kit.json" % pieces.size())


func _village() -> void:
	var man: Dictionary = _json(TV + "village/manifest.json")
	var pieces: Dictionary = man["pieces"]
	for piece: String in pieces:
		var n := Kit.village(piece)
		_expect(n != null, "village: %s loads" % piece)
		if n == null:
			continue
		_materials_from(n, TV + "village/materials/", "village " + piece)
		var cols: Array = pieces[piece]["colliders"]
		var bodies := n.find_children("*", "StaticBody3D", true, false)
		var shapes := n.find_children("*", "CollisionShape3D", true, false)
		var deck_meshes := Kit._meshes(n).filter(func(mi: MeshInstance3D) -> bool: return "colonly" in String(mi.name))
		_expect(bodies.size() == cols.size() and shapes.size() == cols.size() and deck_meshes.is_empty(),
				"village: %s has %d static deck bodies (%d shapes, %d deck meshes left), the manifest lists %d"
				% [piece, bodies.size(), shapes.size(), deck_meshes.size(), cols.size()])
		n.free()
	_expect(pieces.size() >= 38, "village: %d pieces in manifest.json" % pieces.size())


func _plants() -> void:
	var veg: Dictionary = _json(TV + "vegetation/vegetation.json")
	for sp: String in veg["species"]:
		var n_var := Kit.plant_variants(sp)
		_expect(n_var == (veg["species"][sp]["variants"] as Array).size() and n_var > 0, "plants: %s has %d variants" % [sp, n_var])
		for v in n_var:
			for lod in 2:
				var mi := Kit.plant(sp, v, lod)
				var ok := mi != null and mi.mesh != null and mi.material_override != null \
						and mi.material_override.resource_path == Kit.VEG_MATERIALS + sp + ".tres"
				_expect(ok, "plants: %s v%d lod%d has a mesh and its foliage material" % [sp, v, lod])
				if mi:
					mi.free()


func _textures() -> void:
	var meta: Dictionary = _json(TV + "paint/terrain/terrain_slices.json")
	var n_slices := (meta["slices"] as Array).size()
	var arr := load(TV + "paint/terrain/tv_terrain_albedo_array.webp") as Texture2DArray
	_expect(arr != null and arr.get_layers() == n_slices, "textures: the terrain array is a Texture2DArray of %d slices (%s)"
			% [n_slices, str(arr.get_layers()) if arr else "not one"])
	_expect(_imported(TV + "paint/terrain/tv_terrain_albedo_array.webp", true, true)
			and "s3tc_bptc" in str(_import_cfg(TV + "paint/terrain/tv_terrain_albedo_array.webp").get_value("remap", "metadata", {})),
			"textures: the terrain array imported as BPTC with mipmaps")
	for d in ["jade_mist_morning", "bright_saturated_noon", "golden_lantern_dusk"]:
		var lut := load(TV + "paint/grade/tv_grade_%s_64.png" % d) as Texture3D
		_expect(lut != null and lut.get_depth() == 64, "textures: the %s grade LUT is a 64-deep Texture3D" % d)
		_expect(_imported(TV + "paint/sky/tv_sky_%s.png" % d, true, true), "textures: the %s sky is compressed with mipmaps" % d)
	for p in ["village/textures/thatch.png", "rock/textures/karst_face.png", "paint/foliage/tv_foliage_atlas.png",
			"paint/water/tv_fall_body.png"]:
		_expect(_imported(TV + p, true, true), "textures: %s is VRAM-compressed with mipmaps" % p)
	_expect(_imported(TV + "paint/water/tv_river_ramp.png", false, false), "textures: the river ramp is lossless, no mipmaps")


func _import_cfg(path: String) -> ConfigFile:
	var c := ConfigFile.new()
	c.load(path + ".import")
	return c


## Whether `path` was imported (its .import names a destination) with VRAM compression and mipmaps as asked.
func _imported(path: String, vram: bool, mips: bool) -> bool:
	var c := _import_cfg(path)
	return c.has_section_key("deps", "dest_files") and (int(c.get_value("params", "compress/mode", -1)) == 2) == vram \
			and bool(c.get_value("params", "mipmaps/generate", false)) == mips


func _font() -> void:
	UiFonts.reset()
	var f := UiFonts.sans() as FontVariation
	_expect(f != null and f.base_font != null and f.base_font.resource_path.ends_with("BeVietnamPro-Medium.ttf"),
			"font: UiFonts.sans() is Be Vietnam Pro Medium (%s)" % (f.base_font.resource_path if f and f.base_font else "no"))
