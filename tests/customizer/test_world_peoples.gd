extends SceneTree
## The game's own peoples (data/customizer/world_peoples.json, CharacterPeoples; the owner 2026-10-03: "maybe we dont use
## those races and we make custom ones ...", "yea lets test it"; docs/peoples_world.md), headless:
##
##   Godot --headless --path . -s tests/customizer/test_world_peoples.gd -- peoples=world
##
##   data     four world peoples in three groups, listed by the creator (listed_groups / listed_peoples), the real
##            peoples still there for the NPCs (peoples(), presets(""))
##   faces    each world people's faces come from every region of the real peoples (two a region), a different pick per
##            people; the Face row offers WORLD_FACES of them
##   looks    with_people keeps the world people's id, its own hair style, its most common eye and hair colour, its
##            weathering, its mark at its default; the dice keep it; random_look draws its eyes and hair from its lists
##   mark     the Mark row only for the Keelfolk and the Etched; its levels set `trait`; the skin material gets
##            trait_kind 1 (flecks) / 2 (veins) and the amount, in both face styles; none for the Driftborn
##   eyes     the world's eye colours resolve in the eye material and the Eye colour row's swatches
##   hair     the world's hair colours (silver, ash, copper, soot) are presets
## Ends with "WORLD PEOPLES TEST PASSED (<n> checks)" or "WORLD PEOPLES TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_run()
	print("WORLD PEOPLES TEST %s" % ("PASSED (%d checks)" % checks if fails.is_empty() else "FAILED (%d of %d)" % [fails.size(), checks]))
	quit(0 if fails.is_empty() else 1)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


func _run() -> void:
	if not "peoples=world" in OS.get_cmdline_user_args():
		check(false, "run with -- peoples=world (a test run lists the real peoples otherwise)")
		return
	# data
	var ids := CharacterPeoples.listed_peoples().map(func(p: Dictionary) -> String: return String(p.id))
	check(CharacterPeoples.world_listed() and ids == ["downbelower", "driftborn", "keelfolk", "etched"],
			"the creator lists the four world peoples (%s)" % str(ids))
	check(CharacterPeoples.listed_groups() == ["The Downbelow", "The Drift", "Vessary"], "in three groups (%s)" % str(CharacterPeoples.listed_groups()))
	check(CharacterPeoples.peoples().size() == 35 and CharacterPeoples.groups().size() == 9,
			"the real peoples are still there for the NPCs (%d in %d groups)" % [CharacterPeoples.peoples().size(), CharacterPeoples.groups().size()])
	check(CharacterPeoples.presets("", 1.0).all(func(pr: Dictionary) -> bool: return not CharacterPeoples.is_world(String(pr.people))),
			"the pooled presets are all real peoples' (no world duplicates)")
	check(CharacterPeoples.default_people() == "downbelower", "the default people is the Downbelowers")
	for pid: String in ids:
		var p := CharacterPeoples.people(pid)
		check(not p.is_empty() and bool(p.get("world", false)) and (p.face_mean as Dictionary).size() == CharacterPeoples.features().size(),
				"%s reads like a people (face mean over %d features)" % [pid, (p.get("face_mean", {}) as Dictionary).size()])
		check(not CreatorOptions.emblem_name(pid).is_empty() and PeopleEmblem.new(pid).has_method("_e_" + pid), "%s has its emblem" % pid)
	# faces
	var group_of := {}
	for p: Dictionary in CharacterPeoples.peoples():
		group_of[String(p.id)] = String(p.group)
	var picks := {}
	for pid: String in ids:
		for sex in [0.0, 1.0]:
			var st := CharacterPeoples.stylized_presets(pid, sex)
			var regions := {}
			for pr: Dictionary in st:
				regions[group_of.get(String(pr.people), "")] = true
			check(st.size() >= 16 and regions.size() == 9, "%s body %d: %d stylized faces from %d regions" % [pid, int(sex), st.size(), regions.size()])
			picks["%s_%d" % [pid, int(sex)]] = st.map(func(pr: Dictionary) -> String: return String(pr.id))
	check(picks.downbelower_1 != picks.driftborn_1, "each world people picks its own faces")
	var lk := CreatorOptions.with_people(AppearanceStore.default_look(), "driftborn")
	check(CreatorOptions.options("face", lk).size() == CharacterPeoples.WORLD_FACES, "the Face row offers %d faces" % CharacterPeoples.WORLD_FACES)
	# looks
	check(String(lk.people) == "driftborn", "with_people keeps the world people's id (%s)" % lk.people)
	var own: Array = CharacterPeoples.people("driftborn").hair_styles.m if CreatorOptions.is_male(lk) else CharacterPeoples.people("driftborn").hair_styles.f
	check(String(lk.hair.style) == String(own[0]), "its own first hair style (%s)" % lk.hair.style)
	check(String(lk.get("iris", "")) in ["silver", "ice"] and String(lk.hair.get("color", "")) == "silver",
			"its most common eyes and hair (%s, %s)" % [lk.get("iris"), lk.hair.get("color")])
	check(absf(float(lk.get("weathering", 0.0)) - 0.6) < 0.01, "its weathering (%.2f)" % float(lk.get("weathering", 0.0)))
	check(not "trait" in CreatorOptions.rows(lk) and not lk.has("trait"), "the Driftborn have no Mark row")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var eyes_ok := true
	var hair_ok := true
	for i in 12:
		var r := CharacterPeoples.random_look("keelfolk", float(i % 2), rng)
		eyes_ok = eyes_ok and String(r.iris) in (CharacterPeoples.people("keelfolk").eyes as Dictionary)
		hair_ok = hair_ok and String(r.hair.color) in (CharacterPeoples.people("keelfolk").hair_colors as Dictionary)
	check(eyes_ok and hair_ok, "random Keelfolk draw their eyes and hair from their own lists")
	var dice := CreatorOptions.randomized(CreatorOptions.with_people(lk, "keelfolk"), rng)
	check(String(dice.people) == "keelfolk" and dice.has("trait"), "the dice keep the people and give a mark (%s, %s)" % [dice.people, dice.get("trait")])
	# mark
	var kf := CreatorOptions.with_people(lk, "keelfolk")
	check("trait" in CreatorOptions.rows(kf) and absf(float(kf.get("trait", 0.0)) - 0.6) < 0.01, "the Keelfolk: the Mark row, marked (%.2f)" % float(kf.get("trait", -1)))
	var opts := CreatorOptions.options("trait", kf)
	check(opts.size() == 4 and String(opts[3].label).begins_with("Keelstone flecks"), "four levels, named for the flecks (%s)" % str(opts.map(func(o): return o.label)))
	CreatorOptions.select("trait", kf, 3, opts)
	check(absf(float(kf.trait) - 1.0) < 0.001 and CreatorOptions.current("trait", kf) == 3, "Strong: trait 1.0")
	for style in ["stylized", "realistic"]:
		kf["face_style"] = style
		var m := BodyMaterials.skin_material(kf)
		check(int(m.get_shader_parameter("trait_kind")) == 1 and absf(float(m.get_shader_parameter("trait_amount")) - 1.0) < 0.001,
				"%s skin: trait_kind 1 (flecks), amount 1" % style)
		var names := m.shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return String(u.name))
		check("trait_kind" in names and "trait_glow" in names, "%s skin shader has the trait uniforms (compiled)" % style)
	var et := CreatorOptions.with_people(lk, "etched")
	var me := BodyMaterials.skin_material(et)
	check(int(me.get_shader_parameter("trait_kind")) == 2 and float(me.get_shader_parameter("trait_amount")) > 0.5,
			"the Etched: trait_kind 2 (veins), %.2f" % float(me.get_shader_parameter("trait_amount")))
	var md := BodyMaterials.skin_material(lk)
	check(int(md.get_shader_parameter("trait_kind")) == 0, "the Driftborn: no mark")
	et["trait"] = 0.0
	check(int(BodyMaterials.skin_material(et).get_shader_parameter("trait_kind")) == 0, "a mark set to None draws nothing")
	# eyes
	var silver := Color(String(CharacterPeoples.world_eye_colors().silver))
	var em := BodyMaterials.eye_material({"iris": "silver"})
	check((em.get_shader_parameter("iris_color") as Color).is_equal_approx(silver), "silver eyes resolve in the eye material")
	var eo := CreatorOptions.options("eyes", lk)
	var sw: Array = eo.filter(func(o: Dictionary) -> bool: return String(o.id) == "silver")
	check(not sw.is_empty() and (sw[0].color as Color).is_equal_approx(silver), "the Eye colour row's swatch for silver")
	# hair
	for h in ["silver", "ash", "copper", "soot"]:
		check(BodyMaterials.hair_preset(h).get("id", "") == h, "hair colour %s is a preset" % h)
	# a look of a real people stays a real people's (NPCs, old saves)
	var en := CharacterPeoples.preset_look("english_m_a")
	check(String(en.get("people", "")) == "english" and CharacterPeoples.trait_of(en).is_empty(), "a real people's look is untouched")
