extends SceneTree
## The new outfit slots and the cloth patterns (2026-10-03: "add the missing slots", "add patterns"). Headless, about
## 15 s; no scene, nothing saved.
##
##   Godot --headless --path . -s tests/customizer/test_slots_patterns.gd
##
## Ends with "SLOTS PATTERNS TEST OK (<n> checks)" (exit 0) or "SLOTS PATTERNS TEST FAILED (<f> of <n>)" (exit 1).
##
##   slots      PlayerOutfit.SLOTS has the shoulder and arms slots (named for the customizer), not ears_nose (earrings and
##              nose jewels are the creator's jewellery: FaceExtras); the rigging harness is offered in the shoulder slot
##              and no longer as a wrap, and a look that had it as a wrap moves it to the shoulder slot; the Tab screen's
##              zones (ClothesSlots) hold both slots, a start with nothing strips them, and a look stripped before they
##              existed still comes back dressed
##   dress      on a man (an NpcBody): the harness in the shoulder slot and a garment in the arms slot (a test entry over
##              an existing glb: the catalog has no arm piece yet) are parts of the body in their slots, dressed by their
##              catalog materials, in the bulk slots, alongside the basic dress; taken off ("-") they go
##   save       a look with both slots goes through AppearanceStore.validate, JSON and validate again unchanged
##   patterns   ClothMaterials.pattern_spec and the cloth material's uniforms (pat_kind, pat_scale, pat_angle, pat_start,
##              pat_count, pat_sett): the check shirt's default check (its catalog colours and 1.2 cm repeat), plain when
##              the look picks another colour or says none, a picked colour kept in a check the look chose, a stripe on a
##              waistcoat (the zone's colour first, the look's list, scale and angle), a plaid from the sett library (the
##              mirrored repeat, the widths summing to one, recoloured by the look) and from an inline sett, ticking,
##              calico and herringbone, a pattern on a zone of its own ("pattern.1"), the catalog's aliases ("stripes"),
##              check_blue alone as the blue-and-white check, and a zone's mean tint; the creator's Outfit tab shows the
##              pattern row and its picks change the look

const ARM_ID := "test_arm_band"

var _fails: Array[String] = []
var _checks := 0
var _holder: Node3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_holder = Node3D.new()
	_holder.name = "Holder"
	root.add_child(_holder)
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	var t0 := Time.get_ticks_msec()
	_add_arm_entry()
	_test_slots()
	await _test_dress()
	_test_save()
	_test_patterns()
	await _test_outfit_tab()
	PlayerOutfit.catalog().erase(ARM_ID)
	print("(%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if _fails.is_empty():
		print("SLOTS PATTERNS TEST OK (%d checks)" % _checks)
	else:
		print("SLOTS PATTERNS TEST FAILED (%d of %d)" % [_fails.size(), _checks])
	quit(0 if _fails.is_empty() else 1)


## A garment in the arms slot for the test: the glim's catalog entry (a small cloth2 piece) under another id and slot.
func _add_arm_entry() -> void:
	var e: Dictionary = PlayerOutfit.entry("glim").duplicate(true)
	_check(not e.is_empty(), "the catalog has the glim (the test's arm piece borrows its glb)")
	e["id"] = ARM_ID
	e["name"] = "Arm band (test)"
	e["slot"] = "accessories.arms"
	e["alt_slots"] = []
	PlayerOutfit.catalog()[ARM_ID] = e


# ---------------------------------------------------------------- slots
func _test_slots() -> void:
	for slot: String in ["accessories.shoulder", "accessories.arms"]:
		_check(slot in PlayerOutfit.SLOTS, "%s is a slot" % slot)
		_check(slot in (JSON.parse_string(FileAccess.get_file_as_string(PlayerOutfit.CATALOG)) as Dictionary).get("slots", []),
				"%s is one of the catalog's slots" % slot)
	_check(not "accessories.ears_nose" in PlayerOutfit.SLOTS, "ears and nose are no garment slot (the creator's jewellery)")
	_check(CreatorOptions.data().get("jewellery") is Dictionary and not (CreatorOptions.data().jewellery as Dictionary).is_empty(),
			"the creator has its jewellery (earrings and nose jewels: FaceExtras)")
	for slot: String in PlayerOutfit.SLOTS:
		_check(PlayerOutfit.SLOT_NAMES.has(slot), "%s has a name in the customizer (%s)" % [slot, PlayerOutfit.SLOT_NAMES.get(slot, "")])
	_check(PlayerOutfit.SLOTS.find("accessories.shoulder") < PlayerOutfit.SLOTS.find("accessories.wrap")
			and PlayerOutfit.SLOTS.find("accessories.arms") < PlayerOutfit.SLOTS.find("accessories.hands"),
			"the slots in the catalog's order (shoulder before the wrap, arms before the hands)")
	var sh := PlayerOutfit.offered("accessories.shoulder", 1.0)
	_check("rigging_harness" in sh, "the rigging harness is offered in the shoulder slot (%s)" % [sh])
	_check(not "rigging_harness" in PlayerOutfit.offered("accessories.wrap", 1.0), "and no longer as a wrap")
	_check(ARM_ID in PlayerOutfit.offered("accessories.arms", 1.0) and ARM_ID in PlayerOutfit.offered("accessories.arms", 0.0),
			"a garment of the arms slot is offered there, to a man and a woman")
	_check("veste_sleeved" in PlayerOutfit.offered("outer", 1.0), "a real alternative slot stays (the veste as the outer garment)")
	var moved := PlayerOutfit.validate({"accessories.wrap": {"id": "rigging_harness", "colors": {"preset": "tarred"}}})
	_check(String((moved.get("accessories.shoulder", {}) as Dictionary).get("id", "")) == "rigging_harness"
			and not moved.has("accessories.wrap") and String(moved["accessories.shoulder"].colors.get("preset", "")) == "tarred",
			"a look with the harness as a wrap moves it to the shoulder slot, its colours kept (%s)" % [moved])
	var kept := PlayerOutfit.validate({"accessories.wrap": {"id": "rigging_harness"}, "accessories.shoulder": {"id": "-"}})
	_check(String(kept.get("accessories.wrap", {}).get("id", "")) == "rigging_harness", "but not over a shoulder slot the look chose")
	# the Tab screen's places on the figure
	var zone_slots := {}
	for z: Dictionary in ClothesSlots.ZONES:
		for s: String in z.slots:
			zone_slots[s] = String(z.id)
	_check(zone_slots.get("accessories.shoulder", "") == "shoulder" and zone_slots.get("accessories.arms", "") == "arms",
			"the Tab screen has a shoulder and an arms place (%s)" % [zone_slots])
	_check(ClothesSlots.zone_name("shoulder") == "Shoulders" and ClothesSlots.zone_name("arms") == "Arms", "named Shoulders and Arms")
	for slot: String in zone_slots:
		_check(slot in PlayerOutfit.SLOTS, "the Tab screen's %s is an outfit slot" % slot)
	var stripped := {"outfit": {"head": {"id": "-"}, "shirt": {"id": "-"}, "vest": {"id": "-"}, "outer": {"id": "-"},
			"legs.lower": {"id": "-"}, "legs.over": {"id": "-"}, "feet": {"id": "-"}, "accessories.hands": {"id": "-"},
			"accessories.wrap": {"id": "-"}}}
	var back := ClothesSlots.restored(stripped)
	_check((back.outfit as Dictionary).is_empty(), "a look stripped before the new places existed comes back dressed (%s)" % [back.outfit])
	var keep := ClothesSlots.restored({"outfit": {"accessories.shoulder": {"id": "rigging_harness"}, "shirt": {"id": "-"}}})
	_check(String(keep.outfit.get("accessories.shoulder", {}).get("id", "")) == "rigging_harness", "a dressed look is left as it is")


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


func _test_dress() -> void:
	var b := _body("english_m_a")
	await _frames(1)
	_check(b.mesh != null, "the man has a CharacterBodyMesh")
	if b.mesh == null:
		return
	var lk := AppearanceStore.validate(CharacterPeoples.preset_look("english_m_a"))
	lk["outfit"] = {"accessories.shoulder": {"id": "rigging_harness", "colors": {"preset": "aboard"}},
			"accessories.arms": {"id": ARM_ID, "colors": {}}, "shirt": {"id": "shirt_check"}, "legs.lower": {"id": "slops"}}
	var fit := PlayerAppearance.dress(b.mesh, AppearanceStore.validate(lk))
	for spec: Array in [["accessories.shoulder", "rigging_harness"], ["accessories.arms", ARM_ID], ["shirt", "shirt_check"],
			["legs.lower", "slops"]]:
		var parts: Array = b.mesh.part_meshes("outfit:" + String(spec[0]))
		_check(not parts.is_empty() and String((parts[0] as Node).get_meta("garment", "")) == String(spec[1]),
				"%s is worn in %s" % [spec[1], spec[0]])
		_check(_dressed(parts), "%s: every surface has its material" % spec[1])
		_check(String((fit.get("bulk_slots", {}) as Dictionary).get(String(spec[0]), "")) == String(spec[1]),
				"%s is in the bulk slots" % spec[1])
	_check(("outfit:accessories.shoulder" in fit.parts) and ("outfit:accessories.arms" in fit.parts), "both are parts of the dress")
	var harness: Array = b.mesh.part_meshes("outfit:accessories.shoulder")
	var m0 := (harness[0] as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial if not harness.is_empty() else null
	_check(m0 != null and m0.get_shader_parameter("tint0") is Vector4
			and (m0.get_shader_parameter("tint0") as Vector4).is_equal_approx(ClothMaterials.lin4(
				ClothMaterials.token_color(PlayerOutfit.entry("rigging_harness").zones[0], "tar_black"))),
			"the harness in its preset's tarred canvas")
	lk["outfit"]["accessories.shoulder"] = {"id": "-"}
	lk["outfit"]["accessories.arms"] = {"id": "-"}
	fit = PlayerAppearance.dress(b.mesh, AppearanceStore.validate(lk))
	_check(b.mesh.part_meshes("outfit:accessories.shoulder").is_empty() and b.mesh.part_meshes("outfit:accessories.arms").is_empty(),
			"taken off, both parts go")
	_check(not b.mesh.part_meshes("outfit:shirt").is_empty(), "and the shirt stays")
	b.queue_free()
	await _frames(1)


# ---------------------------------------------------------------- save
func _test_save() -> void:
	var lk := AppearanceStore.validate(CharacterPeoples.preset_look("english_m_a"))
	lk["outfit"] = {"accessories.shoulder": {"id": "rigging_harness", "colors": {"0": "sailcloth"}},
			"accessories.arms": {"id": ARM_ID, "colors": {}},
			"vest": {"id": "waistcoat_sb", "colors": {"pattern": "stripe", "stripe": ["madder_red", "linen_white"]}}}
	var a := AppearanceStore.validate(lk)
	var b := AppearanceStore.validate(JSON.parse_string(JSON.stringify(a)))
	for slot: String in ["accessories.shoulder", "accessories.arms", "vest"]:
		_check(String((b.outfit.get(slot, {}) as Dictionary).get("id", "")) == String(lk.outfit[slot].id),
				"saved and loaded, %s keeps its garment" % slot)
	_check(String(b.outfit["accessories.shoulder"].colors.get("0", "")) == "sailcloth", "and its colours")
	_check(String(b.outfit.vest.colors.get("pattern", "")) == "stripe" and b.outfit.vest.colors.get("stripe") is Array,
			"the waistcoat keeps its pattern and the pattern's colours")


# ---------------------------------------------------------------- patterns
func _zone(id: String, z: int) -> Dictionary:
	for zd: Dictionary in PlayerOutfit.entry(id).get("zones", []):
		if int(zd.get("zone", -1)) == z:
			return zd
	return {}


## The cloth material of garment `id`'s first surface with the look's colours `colors` (presets resolved).
func _mat(id: String, colors: Dictionary) -> ShaderMaterial:
	var mats := ClothMaterials.garment_materials(PlayerOutfit.entry(id), PlayerOutfit.resolve_colors(id, colors))
	for k: Variant in mats:
		if mats[k] is ShaderMaterial and (mats[k] as ShaderMaterial).shader == ClothMaterials.CLOTH_SHADER:
			return mats[k]
	return null


func _v(m: ShaderMaterial, p: String) -> Vector4:
	var v: Variant = m.get_shader_parameter(p) if m else null
	return v if v is Vector4 else Vector4(-1, -1, -1, -1)


## The stripe table entries of zone `z` on `m` ([Vector4 linear rgb + width]).
func _rows(m: ShaderMaterial, z: int) -> Array:
	var t: Variant = m.get_shader_parameter("pat_sett")
	var out := []
	if t == null:
		return out
	var st := int(_v(m, "pat_start")[z])
	for i in int(_v(m, "pat_count")[z]):
		out.append(t[st + i])
	return out


func _lin(zd: Dictionary, tok: String) -> Vector3:
	var l := ClothMaterials.lin4(ClothMaterials.token_color(zd, tok))
	return Vector3(l.x, l.y, l.z)


func _rgb(r: Variant) -> Vector3:
	var v := r as Vector4
	return Vector3(v.x, v.y, v.z)


func _test_patterns() -> void:
	var kinds: Dictionary = ClothMaterials.PATTERN_KIND
	var zc := _zone("shirt_check", 0)
	# the check shirt: its catalog default check, check_blue and linen_white, 1.2 cm
	var m := _mat("shirt_check", {})
	_check(m != null and int(_v(m, "pat_kind").x) == int(kinds.check), "the check shirt's zone 0 is a check (%s)" % [_v(m, "pat_kind")])
	_check(is_equal_approx(_v(m, "pat_scale").x, 0.012), "its repeat is the catalog's 1.2 cm (%.4f)" % _v(m, "pat_scale").x)
	var rows := _rows(m, 0)
	_check(rows.size() == 2 and _rgb(rows[0]).is_equal_approx(_lin(zc, "check_blue")) and _rgb(rows[1]).is_equal_approx(_lin(zc, "linen_white"))
			and is_equal_approx((rows[0] as Vector4).w, 0.5), "in check blue and linen white, half and half (%s)" % [rows])
	_check(int(_v(m, "pat_kind").y) == 0, "its collar band is plain")
	var t: Variant = m.get_shader_parameter("pat_sett")
	_check(t is PackedVector4Array and (t as PackedVector4Array).size() == ClothMaterials.PATTERN_TABLE_MAX,
			"the stripe table reaches the shader whole (%s)" % [type_string(typeof(t))])
	var mean := ClothMaterials.zone_tint(zc, "check_blue", {})
	var ca := ClothMaterials.token_color(zc, "check_blue")
	var cb := ClothMaterials.token_color(zc, "linen_white")
	_check(mean.is_equal_approx(Color((ca.r + cb.r) / 2, (ca.g + cb.g) / 2, (ca.b + cb.b) / 2)), "its tint is the check's mean colour")
	_check(_v(m, "tint0").is_equal_approx(ClothMaterials.lin4(mean)), "and the material's tint0 is that mean")
	m = _mat("shirt_check", {"0": "madder_red"})
	_check(int(_v(m, "pat_kind").x) == 0, "another colour picked, the catalog's default check gives way: a plain red shirt")
	m = _mat("shirt_check", {"pattern": "none", "0": "check_blue"})
	_check(int(_v(m, "pat_kind").x) == 0, "\"pattern\": \"none\" is plain, even in check blue")
	m = _mat("shirt_check", {"pattern": "check", "0": "madder_red"})
	rows = _rows(m, 0)
	_check(int(_v(m, "pat_kind").x) == int(kinds.check) and rows.size() == 2 and _rgb(rows[0]).is_equal_approx(_lin(zc, "madder_red"))
			and _rgb(rows[1]).is_equal_approx(_lin(zc, "linen_white")), "a check the look chose takes the picked colour: red and white")
	m = _mat("shirt_check", {"preset": "rook_tow"})
	rows = _rows(m, 0)
	_check(rows.size() == 2 and _rgb(rows[0]).is_equal_approx(_lin(zc, "tow")) and _rgb(rows[1]).is_equal_approx(_lin(zc, "linen_unbleached")),
			"Rook's preset: a check of tow and unbleached linen (the look's own list)")
	m = _mat("shirt_check", {"pattern.1": "stripe"})
	_check(int(_v(m, "pat_kind").y) == int(kinds.stripe) and int(_v(m, "pat_kind").x) == int(kinds.check),
			"a pattern on a zone of its own (\"pattern.1\"): the collar striped, the body still checked")
	# a striped waistcoat
	var zw := _zone("waistcoat_sb", ClothMaterials.pattern_zone(PlayerOutfit.entry("waistcoat_sb")))
	var pz := ClothMaterials.pattern_zone(PlayerOutfit.entry("waistcoat_sb"), {"pattern": "stripe"})
	m = _mat("waistcoat_sb", {"pattern": "stripe"})
	rows = _rows(m, pz)
	var wtok := String(zw.get("default", ""))
	_check(int(_v(m, "pat_kind")[pz]) == int(kinds.stripe) and rows.size() == 2 and _rgb(rows[0]).is_equal_approx(_lin(zw, wtok)),
			"a waistcoat striped by the look: the stripes in its own colour (%s) and the default's second" % wtok)
	m = _mat("waistcoat_sb", {"pattern": "stripe", "stripe": ["stroud_blue", "linen_white"], "pattern_scale": 0.02,
			"pattern_angle": 30.0})
	rows = _rows(m, pz)
	_check(rows.size() == 2 and _rgb(rows[0]).is_equal_approx(_lin(zw, "stroud_blue")) and _rgb(rows[1]).is_equal_approx(_lin(zw, "linen_white"))
			and is_equal_approx(_v(m, "pat_scale")[pz], 0.02) and is_equal_approx(_v(m, "pat_angle")[pz], deg_to_rad(30.0)),
			"the look's stripe colours, repeat and angle reach the shader")
	m = _mat("jacket_womens", {"preset": "striped"})
	_check(int(_v(m, "pat_kind").x) == int(kinds.stripe) and is_equal_approx(_v(m, "pat_scale").x, 0.014),
			"the catalog's \"stripes\" (the women's jacket's striped preset) are stripes, 1.4 cm")
	m = _mat("jacket_womens", {"preset": "striped", "pattern_axis": "h"})
	_check(is_equal_approx(_v(m, "pat_angle").x, deg_to_rad(90.0)), "pattern_axis h turns them across the grain")
	# plaid: a sett from the library, mirrored about its pivots
	var sett: Dictionary = ClothMaterials.setts().get("hill_green", {})
	_check(sett.get("sett") is Array and (sett.sett as Array).size() >= 3, "the sett library has hill_green")
	m = _mat("waistcoat_sb", {"pattern": "plaid", "sett": "hill_green"})
	rows = _rows(m, pz)
	var n := (sett.get("sett", []) as Array).size()
	var wsum := 0.0
	for r: Variant in rows:
		wsum += (r as Vector4).w
	_check(int(_v(m, "pat_kind")[pz]) == int(kinds.plaid) and rows.size() == 2 * n - 2,
			"a plaid waistcoat: the sett mirrored about its pivots (%d stripes of %d)" % [rows.size(), n])
	_check(is_equal_approx(wsum, 1.0), "its widths make one repeat (%.4f)" % wsum)
	_check(is_equal_approx(_v(m, "pat_scale")[pz], float(sett.get("scale_m", 0.0))), "its repeat is the sett's")
	if rows.size() == 2 * n - 2 and n >= 3:
		var s0: Array = sett.sett[0]
		var s1: Array = sett.sett[1]
		var tot := 0.0
		for r: Array in sett.sett:
			tot += float(r[1])
		var full := tot * 2.0 - float(s0[1]) - float((sett.sett as Array)[-1][1])
		_check(_rgb(rows[0]).is_equal_approx(_lin(zw, String(s0[0]))) and is_equal_approx((rows[0] as Vector4).w, float(s0[1]) / full)
				and _rgb(rows[rows.size() - 1]).is_equal_approx(_lin(zw, String(s1[0]))),
				"the pivot once, the inner stripes twice, in the sett's colours")
	m = _mat("waistcoat_sb", {"pattern": "plaid", "sett": "hill_green", "plaid": ["madder_red"]})
	rows = _rows(m, pz)
	_check(not rows.is_empty() and _rgb(rows[0]).is_equal_approx(_lin(zw, "madder_red"))
			and _rgb(rows[2]).is_equal_approx(_lin(zw, String(sett.sett[2][0]))), "the look's list recolours the sett's first colour only")
	m = _mat("petticoat", {"pattern": "tartan", "sett": [["linen_white", 4], ["logwood_black", 4], ["madder_red", 2]],
			"pattern_scale": 0.1})
	rows = _rows(m, ClothMaterials.pattern_zone(PlayerOutfit.entry("petticoat"), {"pattern": "tartan"}))
	_check(rows.size() == 4 and is_equal_approx(_v(m, "pat_scale").x, 0.1), "an inline sett on a petticoat (\"tartan\"): 4 stripes, 10 cm")
	_check(ClothMaterials.sett_table([["a", 2], ["b", 1], ["c", 1]], false).size() == 3
			and ClothMaterials.sett_table([["a", 2], ["b", 1], ["c", 1]], true).size() == 4, "an asymmetric sett repeats as it is")
	# ticking, calico, herringbone
	for spec: Array in [["ticking", 7], ["calico", 3], ["herringbone", 2], ["check", 2]]:
		m = _mat("shirt_tucked", {"pattern": String(spec[0])})
		var k := int(_v(m, "pat_kind").x)
		_check(k == int(kinds[String(spec[0])]) and _rows(m, 0).size() == int(spec[1]),
				"%s on a tucked shirt: kind %d, %d entries" % [spec[0], k, _rows(m, 0).size()])
	# check_blue alone: the neckerchief's "checked" preset (no pattern data of its own)
	m = _mat("neckerchief", {"preset": "checked"})
	_check(int(_v(m, "pat_kind").x) == int(kinds.check), "check blue alone is the blue-and-white check (the neckerchief)")
	m = _mat("neckerchief", {"preset": "checked", "pattern": "none"})
	_check(int(_v(m, "pat_kind").x) == 0, "unless the look says none")
	# names
	_check(ClothMaterials.pattern_name("stripes") == "stripe" and ClothMaterials.pattern_name("calico_small") == "calico"
			and ClothMaterials.pattern_name("tartan") == "plaid" and ClothMaterials.pattern_name("chevron") == "none",
			"the catalog's names map to the shader's (an arrow or chevron pattern is not drawn)")
	_check(ClothMaterials.zone_patterns(zc) == ["none", "check"], "the check shirt documents none and check")
	_check(not ClothMaterials.patternable(_zone("rigging_harness", 2)) and ClothMaterials.patternable(zc),
			"wood and metal take no pattern, linen does")
	# the shader has the uniforms the materials set
	var names := []
	for u: Dictionary in ClothMaterials.CLOTH_SHADER.get_shader_uniform_list():
		names.append(String(u.name))
	for u: String in ["pat_kind", "pat_scale", "pat_angle", "pat_start", "pat_count", "pat_sett"]:
		_check(u in names, "cloth.gdshader has %s" % u)


# ---------------------------------------------------------------- the Outfit tab
func _buttons(n: Node, out: Array) -> Array:
	for c in n.get_children():
		if c is Button and not c is OptionButton:
			out.append(c)
		_buttons(c, out)
	return out


func _test_outfit_tab() -> void:
	var look := AppearanceStore.validate(CharacterPeoples.preset_look("english_m_a"))
	look["outfit"] = {"shirt": {"id": "shirt_check", "colors": {}}, "accessories.shoulder": {"id": "rigging_harness", "colors": {}}}
	var changed := [0]
	var tab := OutfitTab.create(func() -> Dictionary: return look, func() -> void: changed[0] += 1)
	root.add_child(tab)
	await _frames(2)
	_check(tab._rows.has("accessories.shoulder"), "the Outfit tab has a Harness / bandolier row")
	_check(tab._rows.has("accessories.arms"), "and a Bracers / arm bands row (the test's arm band)")
	var row: Dictionary = tab._rows.get("shirt", {})
	var plaid: Button = null
	for b: Button in (_buttons(row.colors, []) if row.get("colors") is Node else []):
		if b.text == "Plaid":
			plaid = b
	_check(plaid != null, "the check shirt's colours have a pattern row with Plaid")
	if plaid != null:
		plaid.pressed.emit()
		await _frames(1)
		_check(String(look.outfit.shirt.colors.get("pattern", "")) == "plaid", "Plaid picked: the look's shirt is a plaid")
		var sett_b: Button = null
		var col_b: Button = null
		for b: Button in _buttons(row.colors, []):
			if b.text == "Madder red":
				sett_b = b
			if col_b == null and b.tooltip_text == "yellow" and b.text == "":
				col_b = b
		_check(sett_b != null, "a plaid offers the sett library (Madder red)")
		if sett_b != null:
			sett_b.pressed.emit()
			await _frames(1)
			_check(String(look.outfit.shirt.colors.get("sett", "")) == "madder_red", "a sett picked: the look's sett")
		for b: Button in _buttons(row.colors, []):
			if b.tooltip_text == "yellow" and b.text == "":
				col_b = b
		_check(col_b != null, "the plaid's colours can be picked (yellow among them)")
		if col_b != null:
			col_b.pressed.emit()
			await _frames(1)
			_check(look.outfit.shirt.colors.get("plaid") is Array and "yellow" in (look.outfit.shirt.colors.plaid as Array),
					"a colour picked goes into the look's plaid colours (%s)" % [look.outfit.shirt.colors.get("plaid")])
	_check(changed[0] >= 2, "each pick changes the look (%d)" % changed[0])
	tab.queue_free()
	await _frames(1)
