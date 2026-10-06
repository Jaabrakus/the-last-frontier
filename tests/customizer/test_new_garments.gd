extends SceneTree
## The cloth2 garments wired into the game, re-staged in the 2026-10-06 cleanup: the period sets (French-Canadian, settlers'
## and regulars', Drift sky crews) were retired, and what stays is the basic dress and the arena's (shirt_tucked,
## breeches, sash_worsted, shift_linen, petticoat, shirt_linen; salvar_mens), owner answer O5. The catalog, the dress on a
## man and a woman, the factions (now in the basic dress, ASK T6 on the factions themselves), the story people's costumes
## (what is left of them) and the customizer's Outfit tab. Headless, about a minute; no scene, nothing saved.
##
##   Godot --headless --path . -s tests/customizer/test_new_garments.gd
##
## Ends with "NEW GARMENTS TEST OK (<n> checks)" (exit 0) or "NEW GARMENTS TEST FAILED (<f> of <n>)" (exit 1).
##
##   catalog    every kept id is PlayerOutfit.usable (catalog lib_version 2, a garment) with its glb, in a set the catalog names
##   dress      each, worn alone over the basic dress on a man and on a woman (an NpcBody: Actor_B and body v4): its part is
##              there in its slot with every surface dressed, it follows the fit (sex 1 / 0), the skin under it is hidden
##              (each of its catalog hides_regions; nothing no worn garment lists; the genitals by the rule: a man's always
##              under the breeches, a woman's only under a garment closed between the legs), the hair zones it covers are
##              hidden and a hat says so (has_hat); each material zone takes its own zone's colour
##   presets    a colour "preset" resolves to the catalog's extra.presets with the look's own keys over it, and an unknown
##              one leaves the zone defaults
##   factions   an NpcFighter of each faction dresses in its faction's wants (each slot one of its wanted garments), in one of
##              its colour choices; without an rng outfit_of is the first of each; the sides' hostility is as before
##   story      every costume (data/story/costumes.json) names usable garments in their slots; Margaretha, Anna, Jost (a child),
##              Vane and Ithel dress in theirs (StoryWalker.person_look); the settlers without a costume wear the basic dress;
##              Leclerc (StoryActor.make of canadian_militia, tag leclerc) wears his red-striped sash
##   customizer the Outfit tab lists each slot's garments under their set's name (the catalog's sets), its presets offer the
##              working dress to the body types whose garments they are, and each preset validates whole
const NEW_IDS := ["shirt_tucked", "breeches", "sash_worsted", "shift_linen", "petticoat", "shirt_linen", "salvar_mens"]
const STORY_PEOPLE := [["margaretha", "palatine_f_a", false], ["anna", "palatine_f_b", false], ["jost", "palatine_m_b", true],
		["vane", "english_m_a", false], ["ithel", "english_m_a", false]]

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
	_test_catalog()
	await _test_dress()
	_test_presets()
	await _test_factions()
	await _test_story()
	_test_customizer()
	print("(%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if _fails.is_empty():
		print("NEW GARMENTS TEST OK (%d checks)" % _checks)
	else:
		print("NEW GARMENTS TEST FAILED (%d of %d)" % [_fails.size(), _checks])
	quit(0 if _fails.is_empty() else 1)


# ---------------------------------------------------------------- catalog
func _test_catalog() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PlayerOutfit.CATALOG))
	var sets: Dictionary = (raw as Dictionary).get("sets", {}) if raw is Dictionary else {}
	for id: String in NEW_IDS:
		var e := PlayerOutfit.entry(id)
		_check(PlayerOutfit.usable(id), "%s is usable (cloth2 garment in the catalog)" % id)
		_check(ResourceLoader.exists(String(e.get("glb", ""))), "%s has its glb (%s)" % [id, e.get("glb", "")])
		var st := String(e.get("set", ""))
		_check(sets.has(st) and PlayerOutfit.set_label(st) == String(sets.get(st, "")), "%s is in a set the catalog names (%s)" % [id, st])
		_check(id in PlayerOutfit.offered(String(e.get("slot", ""))), "%s is offered in its slot %s" % [id, e.get("slot", "")])


# ---------------------------------------------------------------- dress
func _body(preset: String) -> NpcBody:
	var b := NpcBody.new()
	b.name = "Body_" + preset
	_holder.add_child(b)
	b.build(AppearanceStore.validate(CharacterPeoples.preset_look(preset)))
	return b


func _skin(b: NpcBody) -> ShaderMaterial:
	for mi: MeshInstance3D in b.mesh.part_meshes("head"):
		var m := mi.get_surface_override_material(0) as ShaderMaterial
		if m and m.shader and m.shader.resource_path.ends_with("skin.gdshader"):
			return m
	return null


## Every surface of the meshes has its material from the catalog entry (the cloth or the fur shader).
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
	for spec: Array in [["english_m_a", 1.0], ["english_f_a", 0.0]]:
		var b := _body(String(spec[0]))
		await _frames(1)
		var sex := float(spec[1])
		var who := "a man" if sex >= 0.5 else "a woman"
		_check(b.mesh != null, "%s's body has a CharacterBodyMesh" % who)
		if b.mesh == null:
			continue
		var base := AppearanceStore.validate(CharacterPeoples.preset_look(String(spec[0])))
		for id: String in NEW_IDS:
			var e := PlayerOutfit.entry(id)
			var slot := String(e.get("slot", ""))
			if not slot in PlayerOutfit.SLOTS:
				slot = String((e.get("alt_slots", [""]) as Array)[0])
			var lk := base.duplicate(true)
			lk["outfit"] = {slot: {"id": id, "colors": {}}}
			var fit := PlayerAppearance.dress(b.mesh, AppearanceStore.validate(lk))
			var parts: Array = b.mesh.part_meshes("outfit:" + slot)
			var tag := "%s on %s" % [id, who]
			_check(not parts.is_empty() and String((parts[0] as Node).get_meta("garment", "")) == id, "%s: its part is in %s" % [tag, slot])
			_check(_dressed(parts), "%s: every surface has its material" % tag)
			var tints := _tints_ok(parts, id, {}) if not parts.is_empty() else "no part"
			_check(tints == "", "%s: each zone in its default colour, by its own index (%s)" % [tag, tints])
			_check(absf(_sex_of(parts) - float(base.get("sex", sex))) < 0.01, "%s follows the fit (sex %.2f)" % [tag, _sex_of(parts)])
			var hidden: Array = fit.get("hide_regions", [])
			var listed := {}
			var eff := PlayerOutfit.effective(lk.outfit, sex)
			for s: String in eff:
				for r: String in PlayerOutfit.entry(String(eff[s].id)).get("hides_regions", []):
					listed[r] = true
			var missing := (e.get("hides_regions", []) as Array).filter(func(r: String) -> bool:
				return r != PlayerOutfit.GENITALS and not r in hidden)
			_check(missing.is_empty(), "%s hides the skin it covers (missing %s)" % [tag, missing])
			var extra := hidden.filter(func(r: String) -> bool: return not listed.has(r) and r != PlayerOutfit.GENITALS)
			_check(extra.is_empty(), "%s hides nothing no worn garment covers (%s)" % [tag, extra])
			var closed := id in PlayerOutfit.CLOSED_IDS
			for t: String in e.get("tags", []):
				closed = closed or t in PlayerOutfit.CLOSED_TAGS
			var gen_want := sex >= 0.5 or (closed and slot == "legs.lower")
			_check((PlayerOutfit.GENITALS in hidden) == gen_want, "%s: the genitals %s" % [tag, "hidden" if gen_want else "left"])
			var skin := _skin(b)
			_check(skin != null and skin.get_shader_parameter("hide_mask") == BodyMaterials.hide_mask(hidden),
					"%s: the skin's hide mask is the regions hidden" % tag)
			var hz: Array = fit.get("hide_hair_zones", [])
			var hz_missing := (e.get("hides_hair_zones", []) as Array).filter(func(z: String) -> bool: return not z in hz)
			_check(hz_missing.is_empty(), "%s hides the hair zones it covers (missing %s)" % [tag, hz_missing])
			_check(bool(fit.get("has_hat", false)) == (slot == "head"), "%s: has_hat only for a hat" % tag)
		b.queue_free()
		await _frames(1)


# ---------------------------------------------------------------- presets
func _test_presets() -> void:
	var r := PlayerOutfit.resolve_colors("sash_worsted", {"preset": "red_striped", "2": "brass"})
	_check(String(r.get("0", "")) == "ribbon_red" and String(r.get("1", "")) == "ribbon_yellow" and String(r.get("2", "")) == "brass"
			and not r.has("preset"), "a sash's red_striped preset resolves, the look's own zone colour over it (%s)" % [r])
	var plain := {"0": "drab"}
	_check(PlayerOutfit.resolve_colors("sash_worsted", plain) == plain, "colours without a preset are kept as they are")
	var bad := PlayerOutfit.resolve_colors("sash_worsted", {"preset": "no_such", "0": "drab"})
	_check(bad == {"0": "drab"}, "an unknown preset leaves the zone defaults (%s)" % [bad])


## "" when the zone tints of the cloth materials on `meshes` are those of `colors` (resolved; a zone it does not name: its
## catalog default), each zone by its own index (the shader's tint<zone>: an entry's zones may skip one), else what differs.
func _tints_ok(meshes: Array, id: String, colors: Dictionary) -> String:
	var e := PlayerOutfit.entry(id)
	var col := PlayerOutfit.resolve_colors(id, colors)
	var zones: Array = e.get("zones", [])
	for mi: MeshInstance3D in meshes:
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m == null or m.get_shader_parameter("tint0") == null:
				continue                                # (a fur surface)
			for zd: Dictionary in zones:
				var z := int(zd.get("zone", 0))
				if z > 3 or String(zd.get("role", "")) == "fur":
					continue
				var tok := String(col.get(str(z), zd.get("default", "")))
				if tok == "" or tok.begins_with("fur_"):
					continue
				var want := ClothMaterials.lin4(ClothMaterials.zone_tint(zd, tok, col))
				var got: Variant = m.get_shader_parameter("tint%d" % z)
				if not (got is Vector4 and (got as Vector4).is_equal_approx(want)):
					return "zone %d %s" % [z, tok]
	return ""


# ---------------------------------------------------------------- factions
## The garments a faction may put in `slot` (its wants and its mix, usable ones; "-" when the mix allows none).
func _slot_choices(fd: Dictionary, slot: String) -> Array:
	var out := []
	for gid: Variant in fd.get("outfit", {}).get(slot, []):
		if PlayerOutfit.usable(String(gid)):
			out.append(String(gid))
	var mix: Variant = (fd.get("outfit_mix", {}) as Dictionary).get(slot)
	if mix is Dictionary:
		out = []
		for gid: Variant in mix:
			if String(gid) == "-" or PlayerOutfit.usable(String(gid)):
				out.append(String(gid))
	return out


## "" when every zone tint of the materials on `meshes` is one of the faction's colour choices for garment `id`
## (`gc`: a colour dictionary or a list of them, zone values a token or a list of tokens; presets resolved), else what is not.
func _tints_one_of(meshes: Array, id: String, gc: Variant) -> String:
	var choices: Array = gc if gc is Array else [gc]
	var e := PlayerOutfit.entry(id)
	for mi: MeshInstance3D in meshes:
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m == null or m.get_shader_parameter("tint0") == null:
				continue
			for zd: Dictionary in e.get("zones", []):
				var z := int(zd.get("zone", 0))
				if z > 3 or String(zd.get("role", "")) == "fur":
					continue
				var got: Variant = m.get_shader_parameter("tint%d" % z)
				var ok := false
				for ch: Variant in choices:
					var raw: Dictionary = (ch as Dictionary).duplicate() if ch is Dictionary else {}
					var toks: Array = raw.get(str(z), []) if raw.get(str(z)) is Array else [raw.get(str(z), "")]
					for t: Variant in toks:
						var one := raw.duplicate()
						if String(t) != "":
							one[str(z)] = t
						var col := PlayerOutfit.resolve_colors(id, one)
						var tok := String(col.get(str(z), zd.get("default", "")))
						if tok == "" or tok.begins_with("fur_"):
							ok = true
							continue
						var want := ClothMaterials.lin4(ClothMaterials.zone_tint(zd, tok, col))
						if got is Vector4 and (got as Vector4).is_equal_approx(want):
							ok = true
				if not ok:
					return "zone %d" % z
	return ""


func _test_factions() -> void:
	var basic_ids := []
	for bt: String in PlayerOutfit.BASIC:
		basic_ids.append_array((PlayerOutfit.BASIC[bt] as Dictionary).values())
	var fighters := {}
	for fid: String in NpcFactions.all():
		var f := NpcFighter.new()
		f.faction = fid
		f.rng_seed = 11
		f.name = "Fighter_" + fid
		f.process_mode = Node.PROCESS_MODE_DISABLED
		_holder.add_child(f)
		fighters[fid] = f
	await _frames(2)
	for fid: String in fighters:
		var f: NpcFighter = fighters[fid]
		var fd := NpcFactions.get_faction(fid)
		var want := NpcFactions.outfit_of(fid, 1.0)
		var gcol: Dictionary = fd.get("garment_colors", {})
		var drop: Dictionary = fd.get("drop_under", {})
		var outer_parts: Array = f.body.mesh.part_meshes("outfit:outer") if f.body and f.body.mesh else []
		var outer := String((outer_parts[0] as Node).get_meta("garment", "")) if not outer_parts.is_empty() else ""
		var dropped: Array = drop.get(outer, [])
		for slot: String in fd.get("outfit", {}):
			var choices := _slot_choices(fd, slot)
			_check(not choices.is_empty() or (fd.outfit[slot] as Array).is_empty(), "%s: a garment this build has for %s (%s)" % [fid, slot, fd.outfit[slot]])
			var parts: Array = f.body.mesh.part_meshes("outfit:" + slot) if f.body and f.body.mesh else []
			var worn := String((parts[0] as Node).get_meta("garment", "")) if not parts.is_empty() else ""
			if slot in dropped:
				_check(worn == "" or worn in basic_ids, "a %s fighter in %s wears nothing it hides in %s (%s)" % [fid, outer, slot, worn])
				continue
			var ok_worn := worn in choices or (worn == "" and "-" in choices) or (worn in basic_ids and "-" in choices)
			_check(ok_worn, "a %s fighter wears one of %s in %s (%s)" % [fid, choices, slot, worn])
			if worn == "" or not worn in choices:
				continue
			if gcol.has(worn):
				var bad := _tints_one_of(parts, worn, gcol[worn])
				_check(bad == "", "a %s fighter's %s is in one of the faction's colours (%s)" % [fid, worn, bad])
		_check(want.has("shirt") and want.has("legs.lower"), "%s's outfit has the shirt and the legs (%s)" % [fid, want.keys()])
		# without an rng: the first usable garment of each slot (a mix: its heaviest), the first colour choice
		for slot: String in fd.get("outfit", {}):
			var mix: Variant = (fd.get("outfit_mix", {}) as Dictionary).get(slot)
			if mix is Dictionary:
				continue
			var first := ""
			for gid: Variant in fd.outfit[slot]:
				if PlayerOutfit.usable(String(gid)):
					first = String(gid)
					break
			var got := String((want.get(slot, {}) as Dictionary).get("id", ""))
			if first != "" and not slot in (drop.get(String((want.get("outer", {}) as Dictionary).get("id", "")), []) as Array):
				_check(got == first, "%s's deterministic uniform wears %s in %s (%s)" % [fid, first, slot, got])
	_check(NpcFactions.side_of("sky_crew") == "sky" and not NpcFactions.hostile("sky_crew", "player")
			and not NpcFactions.hostile("sky_crew", "french_marine") and not NpcFactions.hostile("militia", "sky_crew"),
			"the sky crew is on its own side, hostile to no one")
	_check(NpcFactions.hostile("french_marine", "militia") and NpcFactions.hostile("toughs", "player"),
			"the raid's and the toughs' hostility is as before")
	for fid: String in fighters:
		(fighters[fid] as Node).queue_free()
	await _frames(1)


# ---------------------------------------------------------------- story
func _test_story() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(StoryWalker.COSTUMES))
	var costumes: Dictionary = (raw as Dictionary).get("costumes", {}) if raw is Dictionary else {}
	_check(costumes.size() >= 7, "costumes.json has the story people (%s)" % [costumes.keys()])
	for tag: String in costumes:
		var outfit: Dictionary = ((costumes[tag] as Dictionary).get("outfit", {}) as Dictionary).duplicate()
		var bm: Dictionary = (costumes[tag] as Dictionary).get("by_mission", {})
		for mid: String in bm:
			for slot: String in bm[mid]:
				outfit["%s@%s" % [slot, mid]] = bm[mid][slot]
		for key: String in outfit:
			var slot := key.get_slice("@", 0)
			var id := String(outfit[key].get("id", ""))
			var e := PlayerOutfit.entry(id)
			_check(PlayerOutfit.usable(id) and (String(e.get("slot", "")) == slot or slot in (e.get("alt_slots", []) as Array)),
					"%s's %s is a usable garment of that slot (%s)" % [tag, key, id])
			var pr: Variant = (outfit[key].get("colors", {}) as Dictionary).get("preset")
			if pr != null:
				var presets: Dictionary = (e.get("extra", {}) as Dictionary).get("presets", {})
				_check(presets.has(String(pr)), "%s's %s preset %s is the catalog's" % [tag, id, pr])
	for p: Array in STORY_PEOPLE:
		var tag := String(p[0])
		var lk := StoryWalker.person_look(String(p[1]), tag, bool(p[2]))
		var want: Dictionary = (costumes.get(tag, {}) as Dictionary).get("outfit", {})
		var b := NpcBody.new()
		b.name = "Story_" + tag
		_holder.add_child(b)
		b.build(lk)
		await _frames(1)
		var wrong := []
		for slot: String in want:
			var parts: Array = b.mesh.part_meshes("outfit:" + slot) if b.mesh else []
			var worn := String((parts[0] as Node).get_meta("garment", "")) if not parts.is_empty() else ""
			if worn != String(want[slot].id):
				wrong.append("%s=%s" % [slot, worn])
			elif not _tints_ok(parts, worn, want[slot].get("colors", {})).is_empty():
				wrong.append("%s colours" % worn)
		_check(wrong.is_empty() and not want.is_empty(), "%s wears her or his costume (%s)" % [tag, wrong])
		if String((costumes.get(tag, {}) as Dictionary).get("hair_style", "")) != "":
			_check(String(lk.get("hair", {}).get("style", "")) == String(costumes[tag].hair_style), "%s's hair style is the costume's" % tag)
		b.queue_free()
	# Margaretha by the mission: her by_mission jacket and cloak went with the period dress: the same dress every mission
	var m0 := StoryWalker.person_look("palatine_f_a", "margaretha")
	var m2 := StoryWalker.person_look("palatine_f_a", "margaretha", false, "m.tf.raid")
	_check(JSON.stringify(m0.outfit) == JSON.stringify(m2.outfit), "Margaretha wears the same on the raid's night (%s)" % [m2.outfit.keys()])
	# the settlers without a costume: the basic dress (no costume garments leak in)
	var plain := StoryWalker.person_look("dutch_f_a", "wendel")
	_check(not plain.outfit.has("head") and String(plain.outfit.get("shirt", {}).get("id", "shift_linen")) == "shift_linen",
			"a settler woman with no costume wears the basic shift (%s)" % [plain.outfit.keys()])
	var man := StoryWalker.person_look("palatine_m_a", "brenner")
	_check(not man.outfit.has("head") and not man.outfit.has("vest") and String(man.outfit.get("shirt", {}).get("id", "")) == "shirt_tucked",
			"a settler man with no costume wears the tucked shirt (%s)" % [man.outfit.keys()])
	var rook := StoryWalker.person_look("palatine_m_b", "rook")
	_check(not rook.outfit.has("head") and not rook.outfit.has("legs.over"), "Rook wears no settler's hat or stockings (%s)" % [rook.outfit.keys()])
	# Leclerc: a StoryActor of the Canadians in his own clothes; a marine of the party in the faction's
	var lec := StoryActor.make(_holder, "canadian_militia", Vector3(3, 0, 0), {"name": "Toussaint Leclerc", "tag": "leclerc", "seed": 1757})
	lec.process_mode = Node.PROCESS_MODE_DISABLED
	var mar := StoryActor.make(_holder, "french_marine", Vector3(5, 0, 0), {"tag": "raid_marine", "seed": 1758})
	mar.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)
	var sash: Array = lec.body.mesh.part_meshes("outfit:accessories.waist") if lec.body and lec.body.mesh else []
	_check(not sash.is_empty() and String((sash[0] as Node).get_meta("garment", "")) == "sash_worsted"
			and _tints_ok(sash, "sash_worsted", {"preset": "red_striped"}) == "", "Leclerc wears his red-striped sash")
	var mshirt: Array = mar.body.mesh.part_meshes("outfit:shirt") if mar.body and mar.body.mesh else []
	_check(not mshirt.is_empty() and String((mshirt[0] as Node).get_meta("garment", "")) == "shirt_tucked",
			"a marine of the party wears the faction's shirt")
	lec.queue_free()
	mar.queue_free()
	await _frames(1)


# ---------------------------------------------------------------- customizer
func _test_customizer() -> void:
	for sex: float in [1.0, 0.0]:
		var look := AppearanceStore.validate(CharacterPeoples.preset_look("english_m_a" if sex >= 0.5 else "english_f_a"))
		var tab := OutfitTab.create(func() -> Dictionary: return look, func() -> void: pass)
		var who := "a man" if sex >= 0.5 else "a woman"
		var rows: Dictionary = tab._rows
		for slot: String in rows:
			var opt: OptionButton = rows[slot].opt
			var under := ""
			var bad := []
			var seen := 0
			for i in opt.item_count:
				if opt.is_item_separator(i):
					under = opt.get_item_text(i)
					continue
				var id := String(opt.get_item_metadata(i))
				if id == "" or id == "-":
					continue
				seen += 1
				if under != PlayerOutfit.set_label(String(PlayerOutfit.entry(id).get("set", ""))):
					bad.append(id)
			_check(seen == PlayerOutfit.offered(slot, sex).size() - 2, "%s's %s row lists each garment offered (%d)" % [who, slot, seen])
			_check(bad.is_empty(), "%s's %s row lists its garments under their set's name (%s)" % [who, slot, bad])
		var names := {}
		for p: Array in OutfitTab.presets(sex):
			names[String(p[0])] = true
			var o: Dictionary = p[1]
			_check(PlayerOutfit.validate(o.duplicate(true)).size() == o.size(), "the %s preset validates whole for %s" % [p[0], who])
		var want := ["Basic dress", "Working dress"]
		var missing := want.filter(func(n: String) -> bool: return not names.has(n))
		_check(missing.is_empty(), "%s is offered the basic and the working dress (missing %s)" % [who, missing])
		tab.free()
