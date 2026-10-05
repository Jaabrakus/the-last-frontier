extends SceneTree
## The Tidebreak ring's own assets (2026-10-05; tools/asset_author): the four element sides' ring dress (the catalog's set
## "ring", cloth2 garments) and the arena kit (assets/ring_kit, authored in Blender). Headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_assets.gd
##   catalog   every ring garment is PlayerOutfit.usable with its glb loading, in the set "ring" the catalog names, cut for
##             both bodies (body_fit male and female, the sex / bust morph targets in its mesh)
##   dress     each element's arena dress (PlayerAppearance.arena_outfit) is the ring dress, slot by slot as
##             data/npc/factions.json ring_team_a's element_dress says; worn on a woman and a man (NpcBody: Actor_B and
##             body v4) every garment's part is there in its slot with every surface dressed, following the fit (its sex
##             morph at the body's); the slots it leaves empty carry nothing (no basic shirt under the parka or the tunics);
##             the genitals hidden under the trousers on both
##   bots      NpcSquad.element_look of ring_team_a and ring_team_b in each element wears the same garments
##   kit       every piece of assets/ring_kit loads (RingDressing.kit_piece) with surfaces whose materials map to the
##             dressing's keys, the glyph atlas (512 px at most) and the banner shader load; triangle budgets
##   ring      scenes/ring.tscn loads; the dressing built with visuals forced on (headless draws nothing otherwise) uses the
##             kit: the gateways, canopies, pillars and lanterns merged into DressingMesh (no extra mesh), the cloth on the
##             kit's banner shader with the atlas set, the glyph following set_sides; no collider added
##   words     no show words in the ring dress's names and texts, the set's label and tip, the kit's file names, the factions'
##             ring entries
## The last line: "RING ASSETS TEST PASSED" or "RING ASSETS TEST FAILED". Exit 0 only on a pass.

const ELEMENTS := ["earth", "water", "fire", "air"]
const RING_IDS := ["ring_trousers_fitted", "ring_trousers_wide", "ring_trousers_wrapped", "ring_earth_tunic",
		"ring_water_parka", "ring_fire_top", "ring_air_tunic", "ring_sash_earth", "ring_sash_fire", "ring_sash_air",
		"ring_water_belt", "ring_shoes", "ring_water_boots", "ring_arm_wraps", "ring_wrist_guards"]
const KIT_PIECES := {"gate_pavilion": 20000, "roof_hip": 6500, "roof_pyramid": 4500, "pillar_shaft": 200,
		"pillar_base": 400, "pillar_cap": 400, "lantern_paper": 500, "awning_canopy": 1800}
const SHOW_WORDS := ["avatar", "bender", "bending", "korra", "aang", "katara", "sokka", "zuko", "toph", "iroh", "azula",
		"appa", "momo", "nation", "water tribe", "earth kingdom", "air nomad", "fire lord", "ba sing se", "omashu",
		"republic city", "chi block", "last airbender"]

var checks := 0
var fails: Array[String] = []
var _holder: Node3D


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	seed(1750)
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RING ASSETS TEST FAILED (watchdog)")
		quit(2))
	InputSetup.ensure()
	_holder = Node3D.new()
	_holder.name = "Holder"
	root.add_child(_holder)
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	_test_catalog()
	await _test_dress()
	_test_bots()
	_test_kit()
	await _test_ring()
	_test_words()
	_end()


# ---------------------------------------------------------------- catalog
func _test_catalog() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PlayerOutfit.CATALOG))
	var sets: Dictionary = (raw as Dictionary).get("sets", {}) if raw is Dictionary else {}
	_expect(sets.has("ring") and PlayerOutfit.set_label("ring") != "", "the catalog names the set ring (%s)" % PlayerOutfit.set_label("ring"))
	for id: String in RING_IDS:
		var e := PlayerOutfit.entry(id)
		_expect(PlayerOutfit.usable(id) and String(e.get("set", "")) == "ring", "%s is a usable garment of the ring set" % id)
		var sc := PlayerOutfit.scene_of(String(e.get("glb", "")))
		_expect(sc != null, "%s's glb loads (%s)" % [id, e.get("glb", "")])
		var bf: Dictionary = e.get("body_fit", {})
		_expect(bool(bf.get("female", false)) and bool(bf.get("male", false)), "%s is cut for both bodies" % id)
		if sc == null:
			continue
		var inst := sc.instantiate()
		var shapes := {}
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh is ArrayMesh:
				for k in (mi.mesh as ArrayMesh).get_blend_shape_count():
					shapes[String((mi.mesh as ArrayMesh).get_blend_shape_name(k))] = true
		inst.free()
		_expect(shapes.has("sex") and shapes.has("breast_large") and shapes.has("breast_small"),
				"%s has the body fit morphs (%s)" % [id, shapes.keys()])
		var tris := int((e.get("stats", {}) as Dictionary).get("tris", 0))
		_expect(tris > 0 and tris <= 10000, "%s within 10k triangles (%d)" % [id, tris])


# ---------------------------------------------------------------- dress
func _body(preset: String) -> NpcBody:
	var b := NpcBody.new()
	b.name = "Body_" + preset
	_holder.add_child(b)
	b.build(AppearanceStore.validate(CharacterPeoples.preset_look(preset)))
	return b


func _dressed(meshes: Array) -> bool:
	if meshes.is_empty():
		return false
	for mi: MeshInstance3D in meshes:
		if not is_instance_valid(mi) or mi.mesh == null:
			return false
		for s in mi.mesh.get_surface_count():
			if not mi.get_surface_override_material(s) is ShaderMaterial:
				return false
	return true


func _sex_of(meshes: Array) -> float:
	for mi: MeshInstance3D in meshes:
		var si := mi.find_blend_shape_by_name("sex")
		if si >= 0:
			return mi.get_blend_shape_value(si)
	return -1.0


func _test_dress() -> void:
	var fac: Dictionary = NpcFactions.get_faction("ring_team_a").get("element_dress", {})
	for el: String in ELEMENTS:
		var want: Dictionary = fac.get(el, {})
		for sex: float in [0.0, 1.0]:
			var o := PlayerAppearance.arena_outfit(el, sex)
			var same := not o.is_empty()
			for slot: String in PlayerOutfit.SLOTS:
				var w: Variant = want.get(slot)
				var wid := String((w as Dictionary).get("id", "-")) if w is Dictionary else "-"
				same = same and String((o.get(slot, {}) as Dictionary).get("id", "")) == wid
			_expect(same, "the %s arena dress (sex %d) is ring_team_a's %s dress" % [el, int(sex), el])
	for spec: Array in [["english_f_a", 0.0], ["english_m_a", 1.0]]:
		var b := _body(String(spec[0]))
		await _frames(1)
		var sex := float(spec[1])
		var who := "a man" if sex >= 0.5 else "a woman"
		_expect(b.mesh != null, "%s's body is built" % who)
		if b.mesh == null:
			continue
		var base := AppearanceStore.validate(CharacterPeoples.preset_look(String(spec[0])))
		for el: String in ELEMENTS:
			var lk := base.duplicate(true)
			lk["outfit"] = PlayerAppearance.arena_outfit(el, sex)
			var fit := PlayerAppearance.dress(b.mesh, AppearanceStore.validate(lk))
			for slot: String in PlayerOutfit.SLOTS:
				var id := String((lk.outfit.get(slot, {}) as Dictionary).get("id", "-"))
				var parts: Array = b.mesh.part_meshes("outfit:" + slot)
				var tag := "%s %s on %s" % [el, slot, who]
				if id == "-":
					_expect(parts.is_empty(), "%s: nothing worn there" % tag)
					continue
				_expect(not parts.is_empty() and String((parts[0] as Node).get_meta("garment", "")) == id, "%s: %s worn" % [tag, id])
				_expect(_dressed(parts), "%s: every surface has its material" % tag)
				_expect(absf(_sex_of(parts) - float(base.get("sex", sex))) < 0.01, "%s follows the fit (sex %.2f)" % [tag, _sex_of(parts)])
			_expect(PlayerOutfit.GENITALS in (fit.get("hide_regions", []) as Array), "%s on %s: the genitals hidden under the trousers" % [el, who])
			_expect(not bool(fit.get("has_hat", false)), "%s on %s: no hat" % [el, who])
		b.queue_free()
		await _frames(1)


# ---------------------------------------------------------------- bots
func _test_bots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1750
	for fac: String in ["ring_team_a", "ring_team_b"]:
		var want: Dictionary = NpcFactions.get_faction(fac).get("element_dress", {})
		for el: String in ELEMENTS:
			var lk := NpcSquad.element_look(fac, el, rng)
			var eff := PlayerOutfit.effective(lk.get("outfit", {}), float(lk.get("sex", 1.0)))
			var ok := not lk.is_empty()
			for slot: String in (want.get(el, {}) as Dictionary):
				var wid := String(((want[el] as Dictionary)[slot] as Dictionary).get("id", "-"))
				var got := String((eff.get(slot, {}) as Dictionary).get("id", "-"))
				ok = ok and got == wid
			_expect(ok, "a %s bot of %s wears the %s ring dress" % [el, fac, el])


# ---------------------------------------------------------------- kit
func _test_kit() -> void:
	var keys := {&"paint": true, &"gold": true, &"tile": true, &"ring_walk": true, &"lamp_red": true, &"metal": true}
	for p: String in KIT_PIECES:
		var parts := RingDressing.kit_piece(p)
		var tris := 0
		var mapped := true
		for s: Dictionary in parts:
			tris += (s.i as PackedInt32Array).size() / 3
			mapped = mapped and keys.has(s.key) and RingDressing.KIT_KEYS.has(String(s.mat))
		_expect(not parts.is_empty(), "the kit's %s loads" % p)
		_expect(mapped, "%s's materials map to the dressing's keys" % p)
		_expect(tris > 0 and tris <= int(KIT_PIECES[p]), "%s within %d triangles (%d)" % [p, int(KIT_PIECES[p]), tris])
	var tex := load(RingDressing.KIT_GLYPHS) as Texture2D
	_expect(tex != null and tex.get_width() <= 512 and tex.get_height() <= 512, "the glyph atlas loads, 512 px at most")
	_expect(load(RingDressing.KIT_SHADER) is Shader, "the banner shader loads")
	_expect(RingDressing.has_kit(), "RingDressing.has_kit()")


# ---------------------------------------------------------------- ring
func _test_ring() -> void:
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 10:
		await process_frame
	var lvl := current_scene as RingLevel
	_expect(lvl != null and lvl.ring != null, "the ring's level loads")
	if lvl == null or lvl.ring == null:
		return
	var shapes_before := lvl.ring.find_children("*", "CollisionShape3D", true, false).size()
	var old := RingDressing.find_in(lvl)
	if old != null:
		old.get_parent().remove_child(old)
		old.free()
	lvl.ring.visuals = true
	lvl.ring.call(&"_materials")
	var t0 := Time.get_ticks_msec()
	var d := RingDressing.build(lvl, "night")
	var ms := Time.get_ticks_msec() - t0
	_expect(d != null and d.mood == "night", "the dressing builds with visuals on (%d ms)" % ms)
	if d == null:
		return
	var dm := d.get_node_or_null("DressingMesh") as MeshInstance3D
	_expect(dm != null and dm.mesh != null, "DressingMesh is there")
	var meshes := d.find_children("*", "MeshInstance3D", true, false).size()
	_expect(meshes <= 40, "the kit adds no meshes of its own (%d mesh instances in the dressing)" % meshes)
	if dm != null and dm.mesh != null:
		var tris := 0
		for s in dm.mesh.get_surface_count():
			var arr := dm.mesh.surface_get_arrays(s)
			tris += ((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3) if arr[Mesh.ARRAY_INDEX] != null else 0
		_expect(tris > 2 * 16000 + 20 * 1400, "the gateways and canopies are in it (%d triangles)" % tris)
	var cloth := d.get_node_or_null("Cloth/banner_0") as MeshInstance3D
	var mat := cloth.material_override as ShaderMaterial if cloth != null else null
	_expect(mat != null and mat.shader != null and mat.shader.resource_path == RingDressing.KIT_SHADER
			and mat.get_shader_parameter(&"glyphs") is Texture2D, "the banners use the kit's shader and glyph atlas")
	d.set_sides("fire", "air")
	_expect(mat != null and int(mat.get_shader_parameter(&"glyph")) == 2, "the side's glyph follows set_sides (fire: 2)")
	_expect(lvl.ring.find_children("*", "CollisionShape3D", true, false).size() == shapes_before, "the dressing adds no collider")


# ---------------------------------------------------------------- words
func _words_in(text: String) -> Array:
	var low := text.to_lower()
	return SHOW_WORDS.filter(func(w: String) -> bool: return w in low)


func _test_words() -> void:
	var bad := []
	for id: String in RING_IDS:
		var e := PlayerOutfit.entry(id)
		for k: String in ["id", "name", "description", "history"]:
			bad.append_array(_words_in(String(e.get(k, ""))))
		bad.append_array(_words_in(JSON.stringify(e.get("extra", {}))))
		for z: Dictionary in e.get("zones", []):
			bad.append_array(_words_in(String(z.get("name", ""))))
	bad.append_array(_words_in(PlayerOutfit.set_label("ring") + " " + PlayerOutfit.set_tip("ring")))
	for f: String in DirAccess.get_files_at("res://assets/ring_kit"):
		bad.append_array(_words_in(f))
	for fac: String in ["ring_team_a", "ring_team_b"]:
		bad.append_array(_words_in(JSON.stringify(NpcFactions.get_faction(fac))))
	_expect(bad.is_empty(), "no show words in the ring dress, the kit or the ring factions (%s)" % [bad])


func _end() -> void:
	print("%d checks, %d failed" % [checks, fails.size()])
	for f in fails:
		print("  failed: ", f)
	print("RING ASSETS TEST " + ("PASSED" if fails.is_empty() else "FAILED"))
	quit(0 if fails.is_empty() else 1)
