extends SceneTree
## The creator with the three parts of 2026-10-03 together (the owner: "give everyone the ability to wear anything on
## starting", "add the missing slots", "add patterns", "add in nose and jewellery and earrings unlock for everyone", "also
## we need tattoos"): the rows in their order, the new slots in the Clothing view, nothing chosen by the people, and the
## looks saved before today still loading. The parts' own tests check each part in depth (test_slots_patterns,
## test_jewellery, test_tattoos); this one checks them in the creator, on its stage figure and through the store.
##
##   Godot --headless --path . -s tests/customizer/test_creator_integration.gd
##
## Ends with "CREATOR INTEGRATION TEST OK (<n> checks)" (exit 0) or "CREATOR INTEGRATION TEST FAILED (<f> of <n>)"
## (exit 1); about half a minute. It never writes the player's look: its files are user://appearance_test/integration_*.json,
## removed at the end.
##
##   rows       for every people and both body types the rows are, in order: skin, bust (body type 2), face, hair style,
##              hair colour, facial hair (body type 1), eyebrows, eye colour, markings, Earrings, Nose, Neck, Rings,
##              Tattoos; in the creator each has its row and title, and the camera frames the face for the earrings and
##              the nose, the bust for the neck and the tattoos, the hands for the rings (the ring's hand turned to the
##              camera, the figure facing it again off the row); Down walks from the markings through the new rows
##   everyone   every people and body type is offered every piece of each jewellery row and every tattoo design; the
##              creator's Clothing view lists the same garments in every slot for every people and both body types (with
##              the pattern row on a patternable garment), and every garment of the build is offered to both body types
##   clothing   the Clothing view has the Harness / bandolier row (the shoulder slot) for a man and a woman, in
##              PlayerOutfit.SLOTS order; choosing the harness there dresses the stage figure; the Arms row comes once the
##              catalog has an arm piece (a test entry over the sash's glb). The 2026-10-06 cleanup retired the period sets
##              with the rigging harness and the check shirt: the harness is a test entry (HARNESS_ID, the sash's glb in the
##              shoulder slot), the check shirt the tucked shirt with its check pattern, the man's plaid on his breeches
##   old looks  a look saved before the jewellery rows, the shoulder slot and the tattoos (a single jewellery id, the
##              harness as a wrap, a check shirt by its colour alone, the ears_nose slot, no tattoos; and broken values)
##              loads: its pieces in the rows, the harness in the shoulder slot, the check kept, the unknown slot dropped,
##              no tattoos; the creator shows it (row texts, the Clothing view's harness) and dresses it
##   all        a man and a woman with earrings, a nose ring and a necklace, two tattoos, a check shirt, a plaid and the
##              harness: saved and loaded unchanged; on the creator's stage the jewellery part, the check and the plaid in
##              their cloth materials, the harness part, and the skin's tattoos (the hand's showing in the clothes, both
##              on the Tattoos row, which shows the skin through the sleeve); the dice, a change of people and a
##              Fine-tune preset keep the tattoos, the clothes (and the name); a change of people or body type and a
##              Fine-tune preset keep the jewellery too (the dice choose it again)

const ARM_ID := "test_integration_arm_band"
## A shoulder piece for the test (the build has none since the 2026-10-06 cleanup): the sash's glb in the shoulder slot.
const HARNESS_ID := "test_integration_harness"
const OLD_MAN := "user://appearance_test/integration_old_man.json"
const OLD_WOMAN := "user://appearance_test/integration_old_woman.json"
const FULL := "user://appearance_test/integration_full.json"

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
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	root.size = Vector2i(1280, 720)
	var he: Dictionary = PlayerOutfit.entry("sash_worsted").duplicate(true)
	he["id"] = HARNESS_ID
	he["name"] = "Harness (test)"
	he["slot"] = "accessories.shoulder"
	he["alt_slots"] = []
	he["tags"] = []
	PlayerOutfit.catalog()[HARNESS_ID] = he
	await _frames(2)
	_test_row_order()
	_test_everyone()
	await _test_creator_rows()
	await _test_clothing_view()
	await _test_old_looks()
	await _test_full_looks()
	for p: String in [OLD_MAN, OLD_WOMAN, FULL]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	PlayerOutfit.catalog().erase(ARM_ID)
	PlayerOutfit.catalog().erase(HARNESS_ID)
	print("(%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if _fails.is_empty():
		print("CREATOR INTEGRATION TEST OK (%d checks)" % _checks)
	else:
		print("CREATOR INTEGRATION TEST FAILED (%d of %d)" % [_fails.size(), _checks])
	quit(0 if _fails.is_empty() else 1)


# --- helpers ----------------------------------------------------------------------------------------------------------

func _look(pid: String, bt: int) -> Dictionary:
	return CreatorOptions.with_body_type(CreatorOptions.with_people({"sex": 1.0 if bt == 1 else 0.0}, pid), bt)


func _ids(opts: Array) -> Array:
	return opts.map(func(o: Dictionary) -> String: return String(o.id))


func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b


## The rows the creator shows for `lk`, in its order.
func _expected_rows(lk: Dictionary) -> Array:
	var male := CreatorOptions.is_male(lk)
	var out := []
	if BodyMaterials.FACE_STYLES.size() >= 2:
		out.append("face_style")
	out.append("skin")
	if not male:
		out.append("bust")
	out.append("face")
	if BodyMaterials.is_stylized(lk):
		out.append("complexion")
	out.append_array(["hair_style", "hair_color"])
	if male:
		out.append("facial_hair")
	out.append_array(["eyebrows", "eyes", "markings", "jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands", "tattoos"])
	return out


## Every piece of a jewellery place in creator.json, "none" first.
func _all_pieces(place: String) -> Array:
	var out := ["none"]
	for id: String in CreatorOptions.data().get("jewellery", {}):
		if id != "none" and CreatorOptions.jewel_place(id) == place:
			out.append(id)
	return out


func _skin_of(body: CharacterBodyMesh) -> ShaderMaterial:
	for mi: MeshInstance3D in body.part_meshes("head"):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src != null and src.resource_name == "skin":
				return mi.get_surface_override_material(s) as ShaderMaterial
	return null


## The cloth material of the garment worn in `slot` on `body` (null when none).
func _cloth_of(body: CharacterBodyMesh, slot: String) -> ShaderMaterial:
	for mi: MeshInstance3D in body.part_meshes("outfit:" + slot):
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m != null and m.shader == ClothMaterials.CLOTH_SHADER:
				return m
	return null


func _worn(body: CharacterBodyMesh, slot: String) -> String:
	var parts: Array = body.part_meshes("outfit:" + slot)
	return String((parts[0] as Node).get_meta("garment", "")) if not parts.is_empty() and is_instance_valid(parts[0]) else ""


## The pattern kind the cloth material draws on the garment's pattern zone (ClothMaterials.PATTERN_KIND), -1 without one.
func _pattern_kind(body: CharacterBodyMesh, slot: String, id: String, colors: Dictionary) -> int:
	var m := _cloth_of(body, slot)
	if m == null:
		return -1
	var pz := ClothMaterials.pattern_zone(PlayerOutfit.entry(id), PlayerOutfit.resolve_colors(id, colors))
	var k: Variant = m.get_shader_parameter("pat_kind")
	return int((k as Vector4)[pz]) if k is Vector4 and pz >= 0 and pz < 4 else -1


func _open() -> CharacterCreator:
	var c := CharacterCreator.open(null)
	await _frames(8)
	return c


func _settle(c: CharacterCreator) -> void:
	for i in 120:
		await process_frame
		if c.stage.has_method("settled") and c.stage.settled() and i > 4:
			break


# --- rows ---------------------------------------------------------------------------------------------------------------

func _test_row_order() -> void:
	var bad := []
	for p: Dictionary in CharacterPeoples.peoples():
		for bt in [1, 2]:
			var lk := _look(String(p.id), bt)
			var rows := CreatorOptions.rows(lk)
			if rows != _expected_rows(lk):
				bad.append("%s %d: %s" % [p.id, bt, rows])
	_check(bad.is_empty(), "every people's rows in the creator's order: the face and hair, the markings, then Earrings, Nose, "
			+ "Neck, Rings and Tattoos last (%s)" % [bad.slice(0, 3)])
	for r: String in ["jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands", "tattoos"]:
		_check(r in CreatorOptions.ROWS, "%s is a row" % r)
	_check(not "jewellery" in CreatorOptions.ROWS, "the single Jewellery row is gone (a saved one loads into the four)")
	var labels := ["jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands", "tattoos"].map(
			func(r: String) -> String: return String(CreatorOptions.ROW_LABELS.get(r, "")))
	_check(labels == ["Earrings", "Nose", "Neck", "Rings", "Tattoos"], "their titles (%s)" % [labels])


func _test_everyone() -> void:
	var want := {}
	for r: String in CreatorOptions.JEWEL_ROWS:
		want[r] = _sorted(_all_pieces(String(CreatorOptions.JEWEL_ROWS[r])))
	var designs := ["none"] + Tattoos.designs().map(func(d: Dictionary) -> String: return String(d.id))
	var bad_j := []
	var bad_t := []
	var first_own := []
	for p: Dictionary in CharacterPeoples.peoples():
		for bt in [1, 2]:
			var lk := _look(String(p.id), bt)
			for r: String in CreatorOptions.JEWEL_ROWS:
				var opts := CreatorOptions.options(r, lk)
				var ids := _ids(opts)
				if _sorted(ids) != want[r]:
					bad_j.append("%s %d %s (%d of %d)" % [p.id, bt, r, ids.size(), (want[r] as Array).size()])
				# the people's own pieces first (after None), the rest after
				var seen_other := false
				for k in range(1, opts.size()):
					var own := bool(opts[k].get("own", false))
					if own and seen_other:
						first_own.append("%s %d %s" % [p.id, bt, r])
						break
					seen_other = seen_other or not own
			if _ids(CreatorOptions.options("tattoos", lk)) != designs:
				bad_t.append("%s %d" % [p.id, bt])
	_check(bad_j.is_empty(), "every people and body type is offered every piece of each jewellery row (%s)" % [bad_j.slice(0, 4)])
	_check(first_own.is_empty(), "the people's own pieces are listed first, the others after (%s)" % [first_own.slice(0, 4)])
	_check(bad_t.is_empty() and designs.size() > 1, "every people and body type is offered every tattoo design (%s)" % [bad_t.slice(0, 4)])
	# every garment of the build is offered somewhere (a man's, a woman's or both), in its own slot
	var unoffered := []
	for id: String in PlayerOutfit.catalog():
		if not PlayerOutfit.usable(id):
			continue
		var slot := String(PlayerOutfit.entry(id).get("slot", ""))
		if not slot in PlayerOutfit.SLOTS:
			continue
		if not id in PlayerOutfit.offered(slot, 1.0) or not id in PlayerOutfit.offered(slot, 0.0):
			unoffered.append(id)
	_check(unoffered.is_empty(), "every garment of the build is offered in its slot to both body types (%s)" % [unoffered])
	var differ := PlayerOutfit.SLOTS.filter(func(slot: String) -> bool: return PlayerOutfit.offered(slot, 1.0) != PlayerOutfit.offered(slot, 0.0))
	_check(differ.is_empty(), "a man and a woman are offered the same garments in every slot (%s)" % [differ])
	for id: String in ["breeches", "petticoat", "shirt_tucked", "shift_linen"]:
		var slot := String(PlayerOutfit.entry(id).get("slot", ""))
		if PlayerOutfit.usable(id):
			_check(id in PlayerOutfit.offered(slot, 0.0) and id in PlayerOutfit.offered(slot, 1.0), "%s: offered to a woman and a man" % id)


## The Clothing view's garments of every slot for a look (OutfitTab: slot -> the items' ids), and whether the shirt row
## shows the pattern row.
func _tab_items(lk: Dictionary) -> Array:
	var tab := OutfitTab.create(func() -> Dictionary: return lk, func() -> void: pass)
	var out := {}
	for slot: String in tab._rows:
		var opt: OptionButton = tab._rows[slot].opt
		var ids := []
		for i in opt.item_count:
			var md: Variant = opt.get_item_metadata(i)
			if md is String:
				ids.append(String(md))
		out[slot] = ids
	var pattern := false
	if tab._rows.has("shirt"):
		for b in (tab._rows.shirt.colors as Node).find_children("*", "Button", true, false):
			if (b as Button).text == "Plaid":
				pattern = true
	tab.free()
	return [out, pattern]


func _test_creator_rows() -> void:
	var c := await _open()
	if not is_instance_valid(c):
		_check(false, "the creator opens")
		return
	for bt in [1, 2]:
		c.look = _look("english" if bt == 1 else "west_african", bt)
		c._refresh_all()
		await _frames(3)
		var shown := []
		for ch in c._rows_box.get_children():
			if not ch.is_queued_for_deletion():
				shown.append(String(ch.name).trim_prefix("Row_"))
		_check(shown == _expected_rows(c.look), "body type %d: the creator shows the rows in order (%s)" % [bt, shown])
		for r: String in ["jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands", "tattoos"]:
			var ui: Dictionary = c._row_ui.get(r, {})
			_check(not ui.is_empty() and (ui.title as Label).text == String(CreatorOptions.ROW_LABELS[r]),
					"body type %d: the %s row" % [bt, CreatorOptions.ROW_LABELS.get(r, r)])
		var frames := {"jewel_ears": "face", "jewel_nose": "face", "jewel_neck": "bust", "jewel_hands": "hands", "tattoos": "bust",
				"markings": "face", "skin": "bust"}
		for r: String in frames:
			c._set_focus(r)
			_check(c.stage.frame_name == String(frames[r]), "body type %d: the %s row frames the %s (%s)" % [bt, r, frames[r], c.stage.frame_name])
		# the Rings row turns the ring's hand to the camera, and the figure back off the row
		c.look["jewel_hands"] = "ring_gold"
		c._set_focus("jewel_hands")
		var yaw_on := float(c.stage._yaw_target)
		c._set_focus("tattoos")
		var yaw_off := float(c.stage._yaw_target)
		_check(CreatorOptions.ring_hand(c.look) == "l" and is_equal_approx(yaw_on, float(CharacterCreator.RING_YAW.l))
				and is_equal_approx(yaw_off, 0.0), "body type %d: the Rings row turns the ring's hand (the left) to the camera, "
				% bt + "and back off the row (%.2f, %.2f)" % [yaw_on, yaw_off])
		# the keys walk from the markings down the new rows, in order
		c._set_focus("markings")
		var walked := []
		for k in 5:
			c._move_focus(1)
			walked.append(c.focus_row)
		_check(walked == ["jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands", "tattoos"], "Down from the markings: %s" % [walked])
	c.close(false)
	await _frames(3)


# --- the Clothing view ----------------------------------------------------------------------------------------------------

func _test_clothing_view() -> void:
	# the same garments for every people of a body type
	for bt in [1, 2]:
		var ref: Array = _tab_items(_look("english", bt))
		var bad := []
		for p: Dictionary in CharacterPeoples.peoples():
			var got: Array = _tab_items(_look(String(p.id), bt))
			if got[0] != ref[0] or got[1] != ref[1]:
				bad.append(String(p.id))
		_check(bad.is_empty(), "body type %d: the Clothing view offers every people the same garments (%s)" % [bt, bad])
		_check(bool(ref[1]), "body type %d: the shirt row has the pattern row (Plaid ...)" % bt)
		var rows: Dictionary = ref[0]
		_check((rows.get("accessories.shoulder", []) as Array).has(HARNESS_ID),
				"body type %d: the Clothing view's Harness / bandolier row offers the rigging harness" % bt)
		_check(not (rows.get("accessories.wrap", []) as Array).has(HARNESS_ID), "body type %d: and the wrap row no longer" % bt)
		var order := rows.keys()
		var in_slots := PlayerOutfit.SLOTS.filter(func(s: String) -> bool: return s in order)
		_check(order == in_slots, "body type %d: the slot rows in PlayerOutfit.SLOTS order (%s)" % [bt, order])
	# and the same for both body types (anyone may wear anything: breeches for a woman, a petticoat for a man)
	var man: Dictionary = _tab_items(_look("english", 1))[0]
	var woman: Dictionary = _tab_items(_look("english", 2))[0]
	var unlike := man.keys().filter(func(slot: String) -> bool: return man[slot] != woman.get(slot))
	_check(unlike.is_empty() and man.size() == woman.size(), "the Clothing view lists the same garments for both body types (%s)" % [unlike])
	_check("breeches" in (woman.get("legs.lower", []) as Array) and "petticoat" in (man.get("legs.lower", []) as Array),
			"a woman may choose breeches, a man the petticoat")
	# the creator's own Clothing view: the harness chosen in its row dresses the stage figure
	var c := await _open()
	if not is_instance_valid(c):
		_check(false, "the creator opens")
		return
	c.look = _look("scots_irish", 1)
	c.look["outfit"] = {}
	c._refresh_all()
	c._show_clothing(true)
	await _frames(3)
	var tab := c._outfit_ui as OutfitTab
	_check(tab != null and tab.visible and tab._rows.has("accessories.shoulder"), "the creator's Clothing view has the shoulder slot's row")
	if tab != null and tab._rows.has("accessories.shoulder"):
		var row: Dictionary = tab._rows["accessories.shoulder"]
		var title := ""
		for ch in (row.opt as Node).get_parent().get_children():
			if ch is Label:
				title = (ch as Label).text
		_check(title == "Harness / bandolier", "titled Harness / bandolier (%s)" % title)
		var opt: OptionButton = row.opt
		var at := -1
		for i in opt.item_count:
			if opt.get_item_metadata(i) is String and String(opt.get_item_metadata(i)) == HARNESS_ID:
				at = i
		_check(at >= 0, "the row lists the harness")
		if at >= 0:
			opt.select(at)
			opt.item_selected.emit(at)
			await _frames(3)
			_check(String(((c.look.outfit as Dictionary).get("accessories.shoulder", {}) as Dictionary).get("id", "")) == HARNESS_ID,
					"choosing it puts the harness in the look's shoulder slot")
			_check(_worn(c.stage.body, "accessories.shoulder") == HARNESS_ID, "and the stage figure wears it")
	c.close(false)
	await _frames(3)
	# the Arms row: there once the catalog has an arm piece (a test entry borrowing the sash's glb)
	var e: Dictionary = PlayerOutfit.entry("sash_worsted").duplicate(true)
	e["id"] = ARM_ID
	e["name"] = "Arm band (test)"
	e["slot"] = "accessories.arms"
	e["alt_slots"] = []
	e["tags"] = []
	PlayerOutfit.catalog()[ARM_ID] = e
	for bt in [1, 2]:
		var rows: Dictionary = _tab_items(_look("english", bt))[0]
		_check((rows.get("accessories.arms", []) as Array).has(ARM_ID), "body type %d: an arm piece brings the Bracers / arm bands row" % bt)
	PlayerOutfit.catalog().erase(ARM_ID)


# --- old looks --------------------------------------------------------------------------------------------------------------

func _write(path: String, look: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": AppearanceStore.FORMAT, "version": 2, "saved": "2026-10-02T12:00:00", "look": look}, " "))
	f.close()


func _test_old_looks() -> void:
	# a man saved before the jewellery rows, the shoulder slot and the tattoos
	_write(OLD_MAN, {"people": "scots_irish", "sex": 1.0, "name": "Old Rab", "melanin": 0.14, "undertone": "neutral",
			"jewellery": "studs_nose_stud", "facial_hair": "stubble_light", "markings": "none",
			"hair": {"style": "hair_queue_ribbon", "color": "dark_brown"},
			"outfit": {"shirt": {"id": "shirt_tucked", "colors": {"0": "check_blue", "pattern": "check"}},
				"accessories.wrap": {"id": HARNESS_ID, "colors": {"preset": "plain_red"}}}})
	var m := AppearanceStore.load_file(OLD_MAN)
	_check(m.get("name", "") == "Old Rab" and m.get("people", "") == "scots_irish", "the old man's file loads (%s)" % m.get("name", ""))
	_check(not m.has("jewellery") and m.get("jewel_ears") == "gold_studs" and m.get("jewel_nose") == "nose_stud_gold"
			and m.get("jewel_neck") == "none" and m.get("jewel_hands") == "none",
			"his single jewellery set is in the rows (%s, %s, %s, %s)" % [m.get("jewel_ears"), m.get("jewel_nose"), m.get("jewel_neck"), m.get("jewel_hands")])
	var o: Dictionary = m.get("outfit", {})
	_check(String((o.get("accessories.shoulder", {}) as Dictionary).get("id", "")) == HARNESS_ID and not o.has("accessories.wrap")
			and String(o["accessories.shoulder"].colors.get("preset", "")) == "plain_red",
			"his harness, saved as a wrap, is in the shoulder slot with its colours (%s)" % [o.keys()])
	_check(m.get("tattoos") is Array and (m.tattoos as Array).is_empty(), "he has no tattoos")
	var shirt := PlayerOutfit.entry("shirt_tucked")
	var cols := PlayerOutfit.resolve_colors("shirt_tucked", o.get("shirt", {}).get("colors", {}))
	var pz := ClothMaterials.pattern_zone(shirt, cols)
	var zd := {}
	for z: Dictionary in shirt.get("zones", []):
		if int(z.get("zone", -1)) == pz:
			zd = z
	_check(String(ClothMaterials.pattern_spec(zd, String(cols.get(str(pz), zd.get("default", ""))), cols, pz, pz).get("name", "")) == "check",
			"his check shirt, saved with its pattern, is still a check")
	# a woman saved with the old slot names and broken values
	_write(OLD_WOMAN, {"people": "bengali" if not CharacterPeoples.people("bengali").is_empty() else "english", "sex": 0.0,
			"jewellery": "pearl_drops", "jewel_neck": "gold_studs", "jewel_hands": 7, "tattoos": "lots",
			"outfit": {"legs.lower": {"id": "petticoat", "colors": {"0": "walnut_brown"}}, "accessories.ears_nose": {"id": "ear_hoop"},
				"accessories.wrap": {"id": "no_such_cloak"}}})
	var w := AppearanceStore.load_file(OLD_WOMAN)
	var wo: Dictionary = w.get("outfit", {})
	_check(w.get("jewel_ears") == "pearl_drops" and not w.has("jewellery"), "the old woman's pearl drops are in the Earrings row")
	_check(w.get("jewel_neck", "none") == "none" and not w.get("jewel_hands") is int, "a piece in the wrong row and a broken one wear nothing")
	_check(w.get("tattoos") is Array and (w.tattoos as Array).is_empty(), "broken tattoos load as none")
	_check(not wo.has("accessories.ears_nose") and not wo.has("accessories.wrap")
			and String((wo.get("legs.lower", {}) as Dictionary).get("id", "")) == "petticoat",
			"the ears_nose slot and an unknown garment are dropped, the petticoat kept (%s)" % [wo.keys()])
	# a look from before the creator (sex and face only): every new row holds a choice
	var bare := AppearanceStore.validate({"sex": 0.0, "people": "english"})
	for r: String in ["jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands", "tattoos"]:
		_check(CreatorOptions.current(r, bare) == 0, "a look from before the creator: %s on None" % r)
	# the creator shows the old man and dresses him
	var c := await _open()
	if not is_instance_valid(c):
		_check(false, "the creator opens")
		return
	c.look = m
	c._refresh_all()
	await _settle(c)
	var txt := func(r: String) -> String:
		var ui: Dictionary = c._row_ui.get(r, {})
		return (ui.value as Label).text if not ui.is_empty() else ""
	_check(txt.call("jewel_ears") == "Gold studs" and txt.call("jewel_nose") == "Gold nose stud" and txt.call("jewel_neck") == "None",
			"the creator's rows show his pieces (%s, %s, %s)" % [txt.call("jewel_ears"), txt.call("jewel_nose"), txt.call("jewel_neck")])
	var tui: Dictionary = c._row_ui.get("tattoos", {})
	_check(not tui.is_empty() and (tui.value as Label).text == "None" and (tui.count as Label).text == "0/%d" % Tattoos.max_count(),
			"and no tattoos")
	var body: CharacterBodyMesh = c.stage.body
	_check(not body.part_meshes(FaceExtras.PART_JEWELLERY).is_empty(), "the stage figure wears his studs")
	_check(_worn(body, "accessories.shoulder") == HARNESS_ID and _worn(body, "shirt") == "shirt_tucked"
			and _worn(body, "accessories.wrap") == "", "and his harness over the check shirt (no wrap)")
	_check(_pattern_kind(body, "shirt", "shirt_tucked", o.get("shirt", {}).get("colors", {})) == int(ClothMaterials.PATTERN_KIND.check),
			"the shirt's cloth draws the check")
	c._show_clothing(true)
	await _frames(3)
	var tab := c._outfit_ui as OutfitTab
	if tab != null and tab._rows.has("accessories.shoulder"):
		var opt: OptionButton = tab._rows["accessories.shoulder"].opt
		_check(opt.selected >= 0 and String(opt.get_item_metadata(opt.selected)) == HARNESS_ID,
				"the Clothing view shows his harness in the shoulder row")
	else:
		_check(false, "the Clothing view has the shoulder row")
	c.close(false)
	await _frames(3)


# --- everything together ----------------------------------------------------------------------------------------------------

## A man or a woman with earrings, a nose ring, a necklace, two tattoos (one on the back of a hand, one under a sleeve), a
## check shirt, a plaid (the man's breeches, the woman's petticoat) and the harness.
static func full_look(bt: int) -> Dictionary:
	var man := bt == 1
	var lk := CreatorOptions.with_body_type(CreatorOptions.with_people({"sex": 1.0 if man else 0.0},
			"scots_irish" if man else "english"), bt)
	lk["name"] = "Rab" if man else "Mary"
	lk["jewel_ears"] = "sailor_hoop_gold" if man else "pearl_drops"
	lk["jewel_nose"] = "nose_ring_silver" if man else "nose_ring_gold"
	lk["jewel_neck"] = "chain_cross_silver" if man else "coral_beads"
	lk["jewel_hands"] = "ring_gold"
	lk["tattoos"] = []
	if man:
		Tattoos.add(lk, "keelstone_star", "hand_r")
		Tattoos.add(lk, "anchor", "forearm_l")
	else:
		Tattoos.add(lk, "wind_spiral", "hand_l")
		Tattoos.add(lk, "heart", "forearm_r")
	var outfit := {"shirt": {"id": "shirt_tucked", "colors": {"pattern": "check"}},
			"accessories.shoulder": {"id": HARNESS_ID, "colors": {"preset": "plain_red"}}}
	if man:
		outfit["legs.lower"] = {"id": "breeches", "colors": {"pattern": "plaid", "sett": "madder_red"}}
	else:
		outfit["legs.lower"] = {"id": "petticoat", "colors": {"pattern": "plaid", "sett": "hill_green"}}
	lk["outfit"] = outfit
	return lk


func _test_full_looks() -> void:
	var c := await _open()
	if not is_instance_valid(c):
		_check(false, "the creator opens")
		return
	for bt in [1, 2]:
		var who := "the man" if bt == 1 else "the woman"
		var lk := full_look(bt)
		_check(AppearanceStore.save_file(FULL, lk), "%s: saved" % who)
		var back := AppearanceStore.load_file(FULL)
		for k: String in ["jewel_ears", "jewel_nose", "jewel_neck", "jewel_hands", "name"]:
			_check(back.get(k) == lk.get(k), "%s: %s loads unchanged (%s)" % [who, k, back.get(k)])
		_check(JSON.stringify(back.get("tattoos")) == JSON.stringify(Tattoos.validate(lk.tattoos)) and (back.tattoos as Array).size() == 2,
				"%s: both tattoos load unchanged" % who)
		var bo: Dictionary = back.get("outfit", {})
		var plaid_slot := "legs.lower"
		_check(String((bo.get("accessories.shoulder", {}) as Dictionary).get("id", "")) == HARNESS_ID
				and String(bo.get(plaid_slot, {}).get("colors", {}).get("sett", "")) == String(lk.outfit[plaid_slot].colors.sett),
				"%s: the harness and the plaid's sett load unchanged" % who)
		c.look = back
		c._refresh_all()
		c._set_focus("jewel_neck")
		await _settle(c)
		var body: CharacterBodyMesh = c.stage.body
		_check(not body.part_meshes(FaceExtras.PART_JEWELLERY).is_empty() and CreatorOptions.jewellery_items(c.look).size() >= 4,
				"%s: the stage figure wears the earrings, the nose ring, the necklace and the ring" % who)
		_check(_worn(body, "shirt") == "shirt_tucked"
				and _pattern_kind(body, "shirt", "shirt_tucked", lk.outfit.shirt.colors) == int(ClothMaterials.PATTERN_KIND.check),
				"%s: the check shirt, drawn as a check" % who)
		var pid := String(lk.outfit[plaid_slot].id)
		_check(_worn(body, plaid_slot) == pid
				and _pattern_kind(body, plaid_slot, pid, lk.outfit[plaid_slot].colors) == int(ClothMaterials.PATTERN_KIND.plaid),
				"%s: the %s, drawn as a plaid" % [who, pid])
		_check(_worn(body, "accessories.shoulder") == HARNESS_ID, "%s: the harness" % who)
		# in the clothes: what their regions leave showing (the back of the hand; of the forearm, what the sleeve leaves)
		var hide := []
		var eff := PlayerOutfit.effective(back.outfit, float(back.sex))
		for slot: String in eff:
			hide.append_array(PlayerOutfit.entry(String(eff[slot].id)).get("hides_regions", []))
		var want := Tattoos.shader_rows({"tattoos": back.tattoos, "hide_regions": hide}).size()
		var skin := _skin_of(body)
		var n := int(skin.get_shader_parameter("tat_count")) if skin else -1
		_check(Tattoos.visible(back.tattoos[0], hide) and want >= 1 and n == want,
				"%s: in the clothes the skin draws the tattoos that show, the hand's among them (%d of %d)" % [who, n, want])
		c._set_focus("tattoos")
		await _settle(c)
		skin = _skin_of(c.stage.body)
		n = int(skin.get_shader_parameter("tat_count")) if skin else -1
		_check(n == 2, "%s: on the Tattoos row both show (the skin through the sleeve) (%d)" % [who, n])
		var tui: Dictionary = c._row_ui.get("tattoos", {})
		_check(not tui.is_empty() and (tui.count as Label).text == "2/%d" % Tattoos.max_count(), "%s: the Tattoos row counts two" % who)
		# the dice and a change of people keep the tattoos and the clothes; a change of people or body type keeps the
		# jewellery as well (for everyone, like the clothes), the dice choose it again
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + bt
		var r := CreatorOptions.randomized(c.look, rng)
		_check((r.tattoos as Array).size() == 2 and String(r.outfit.get("accessories.shoulder", {}).get("id", "")) == HARNESS_ID,
				"%s: the dice keep the tattoos and the clothes" % who)
		var q := CreatorOptions.with_people(c.look, "malay" if not CharacterPeoples.people("malay").is_empty() else "french")
		_check((q.tattoos as Array).size() == 2 and String(q.outfit.get(plaid_slot, {}).get("colors", {}).get("sett", "")) != "",
				"%s: so does a change of people" % who)
		var jw := func(lk2: Dictionary) -> Array:
			return CreatorOptions.JEWEL_ROWS.keys().map(func(row: String) -> String: return CreatorOptions.jewel_id(lk2, row))
		var want_j: Array = jw.call(c.look)
		_check(want_j == [lk.jewel_ears, lk.jewel_nose, lk.jewel_neck, lk.jewel_hands], "%s: wears the four pieces (%s)" % [who, want_j])
		for other: String in ["scots_irish", "lenape", "japanese", "west_african"]:
			var qp := CreatorOptions.with_people(c.look, other)
			_check(jw.call(qp) == want_j, "%s: a change of people (%s) keeps the earrings, the nose ring, the necklace and the ring (%s)"
					% [who, other, jw.call(qp)])
		var qb := CreatorOptions.with_body_type(c.look, 2 if bt == 1 else 1)
		_check(jw.call(qb) == want_j and (qb.tattoos as Array).size() == 2, "%s: so does a change of body type (%s)" % [who, jw.call(qb)])
		var old := c.look.duplicate(true)
		for row: String in CreatorOptions.JEWEL_ROWS:
			old.erase(row)
		old["jewellery"] = "studs_nose_stud"
		_check(jw.call(CreatorOptions.with_people(old, "english")) == ["gold_studs", "nose_stud_gold", "none", "none"],
				"%s: an old look's single jewellery id is kept, into the rows" % who)
		# the creator's own people buttons, as a player clicks through the peoples
		c._choose_people("haudenosaunee")
		c._choose_people(String(lk.people))
		_check(jw.call(c.look) == want_j, "%s: clicking through the peoples in the creator keeps the jewellery (%s)" % [who, jw.call(c.look)])
		# Fine-tune: a people preset picked there keeps the name, the tattoos and the clothes too
		c._open_fine_tune()
		await _frames(4)
		var ov: CustomizerOverlay = c._fine
		var picked := false
		if is_instance_valid(ov):
			for b in ov._presets_box.get_children():
				if b is Button:
					(b as Button).pressed.emit()
					picked = true
					break
			ov.close(true)
		await _frames(4)
		_check(picked and (c.look.get("tattoos", []) as Array).size() == 2 and String(c.look.get("name", "")) == String(lk.name)
				and String(c.look.outfit.get("accessories.shoulder", {}).get("id", "")) == HARNESS_ID,
				"%s: a Fine-tune preset keeps the name, the tattoos and the clothes (%s, %d tattoos)" % [who, c.look.get("name", ""),
				(c.look.get("tattoos", []) as Array).size()])
		_check(jw.call(c.look) == want_j, "%s: and the jewellery (%s)" % [who, jw.call(c.look)])
	c.close(false)
	await _frames(3)
