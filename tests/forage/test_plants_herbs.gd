extends SceneTree
## The plants for the remedies and the vices (user 2026-09-27: "we will need more plants and herbs for these new
## things"; willow, yarrow, slippery elm, elderberry, hemp, bearberry, red-osier dogwood, jimsonweed, crabapple) and the
## remedies made from them, on the level with the survival bridge, headless:
##
##   Godot --headless --path . -s tests/forage/test_plants_herbs.gd -- survival=on survival_seed=7
##
##   placed    each of the nine has patches; willow, red-osier, elder and slippery elm in the hollows (the ground
##             low_m or more below its rim), hemp and jimsonweed mostly round the fort
##   models    each plant (every variant), its fruit where it bears one, each item's icon model, the remedies' models
##   items     names and pack text; elderberries and crabapples are food to the survival core, each its own item
##   season    25 August: elderberries in, crabapples not yet, the bark all year; late September the crabapples
##   yarrow    packed into a bleeding wound: the bleeding stops within seconds
##   willow    the pain of a leg wound dulled six hours (not restless, the arm's reload as ever); the ague half a day
##             nearer mended
##   gruel     the flux: a meal nourishes in full while the gut is soothed; the flux a quarter mended
##   syrup     chilled to the bone: a quarter nearer mended
##   tonic     ginseng after a nap lengthens the rest but does not heal; after the day's sleep the healing runs on
##   recipes   the alchemy table's three new remedies, each over a fire, from the plants
## Ends with "PLANTS HERBS TEST OK (<n> checks)" or "PLANTS HERBS TEST FAILED <failures>/<n>".

const KINDS := ["willow", "yarrow", "slippery_elm", "elderberry", "hemp", "bearberry", "red_osier", "jimsonweed", "crabapple"]
const ITEMS := ["willow_bark", "yarrow", "elm_bark", "elderberries", "hemp_tops", "bearberry", "dogwood_bark", "jimsonweed", "crabapples"]
const FRUITING := ["yarrow", "elderberry", "bearberry", "red_osier", "jimsonweed", "crabapple"]
const REMEDIES := ["willow_bark_tea", "slippery_elm_gruel", "elderberry_syrup"]

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var lc: LastingConditions
var player: FrontierPlayer
var f: ForageField


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


func settle(n := 3) -> void:
	for i in n:
		await process_frame
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await settle(20)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	lc = b.lasting if b else null
	f = ForageField.find(self)
	check(b != null and lc != null and f != null, "the level has the bridge and the forage field")
	if f == null or lc == null:
		_end()
		return
	player.ignore_mouse_capture = true
	_test_placed()
	_test_models()
	_test_items()
	_test_season()
	await _test_yarrow()
	_test_willow()
	_test_gruel()
	_test_syrup()
	_test_tonic()
	_test_recipes()
	_end()


func _patches(kind: String) -> Array:
	return f.patches.filter(func(pa: Dictionary) -> bool: return String(pa.kind) == kind)


func _test_placed() -> void:
	var counts := {}
	for k: String in KINDS:
		counts[k] = _patches(k).size()
	check(KINDS.all(func(k: String) -> bool: return int(counts[k]) >= 5), "every plant has patches: %s" % [counts])
	for k: String in ["willow", "red_osier", "elderberry", "slippery_elm"]:
		var low_m := float(f.data.plants[k].get("low_m", 1.0))
		var ok := _patches(k).all(func(pa: Dictionary) -> bool:
			return ForageField.lowness((pa.pos as Vector3).x, (pa.pos as Vector3).z) <= -low_m + 0.01)
		check(ok, "%s in the hollows (%.1f m or more below the rim)" % [k, low_m])
	for k: String in ["hemp", "jimsonweed"]:
		var ps := _patches(k)
		var near := ps.filter(func(pa: Dictionary) -> bool:
			var p: Vector3 = pa.pos
			return Vector2(p.x, p.z).length() < float(f.data.plants[k].near_fort_m) + 5.0 or (absf(p.x) < 25.0 and p.z < 0.0 and p.z > -180.0))
		check(ps.size() > 0 and float(near.size()) / ps.size() >= 0.5, "%s mostly round the fort and the lane (%d of %d)" % [k, near.size(), ps.size()])


func _test_models() -> void:
	var missing: Array[String] = []
	for k: String in KINDS:
		for v in ForageModels.VARIANTS:
			if ForageModels.plant_mesh(k, v) == null:
				missing.append("%s:%d" % [k, v])
			if k in FRUITING and ForageModels.fruit_mesh(k, v) == null:
				missing.append("%s fruit:%d" % [k, v])
	check(missing.is_empty(), "every plant's model and its fruit build %s" % [missing])
	var tall := ForageModels.plant_mesh("crabapple", 0).get_aabb()
	var low := ForageModels.plant_mesh("bearberry", 0).get_aabb()
	check(tall.size.y > 1.8 and low.size.y < 0.12, "a crabapple is a small tree (%.1f m), bearberry a mat on the ground (%.2f m)" % [tall.size.y, low.size.y])
	var bad: Array[String] = []
	for it: String in ITEMS:
		check_model(ForageModels.has(it), ForageModels.build(it) if ForageModels.has(it) else null, it, bad)
	for it: String in REMEDIES:
		check_model(ProvisionModels.has(it), ProvisionModels.build(it) if ProvisionModels.has(it) else null, it, bad)
	check(bad.is_empty(), "each item's and remedy's icon model builds %s" % [bad])


func check_model(has: bool, n: Node3D, it: String, bad: Array[String]) -> void:
	var meshes := n.find_children("*", "MeshInstance3D", true, false) if n else []
	var ok := has and meshes.any(func(m: MeshInstance3D) -> bool: return m.mesh != null and m.mesh.get_surface_count() > 0)
	if not ok:
		bad.append(it)
	if n:
		n.free()


func _test_items() -> void:
	var text: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/item_text.json")).items
	var nameless := (ITEMS + REMEDIES).filter(func(it: String) -> bool:
		return not InventoryState.NAMES.has(it) or not text.has(it))
	check(nameless.is_empty(), "every item has its name and pack text %s" % [nameless])
	var eb := b.pack_item("elderberries")
	var ca := b.pack_item("crabapples")
	check(String(eb.get("item", "")) == "item.food.elderberries" and String(ca.get("item", "")) == "item.food.crabapples"
			and float(b.core.data.item("item.food.crabapples").get("kcal", 0.0)) > 0.0, "elderberries and crabapples are food, each its own")
	check(b.pack_kind_of("item.food.berries") == "blackberries" and b.pack_kind_of("item.food.elderberries") == "elderberries",
			"a handful comes back as what it was")


func _test_season() -> void:
	f.day_override = WorldClock.DEFAULT_DAY_OF_YEAR
	f._update_season(true)
	check(f.in_season("elderberry") and not f.in_season("crabapple") and f.in_season("willow") and f.in_season("slippery_elm")
			and f.in_season("hemp") and f.fruit_shown("yarrow"), "25 August: elderberries, hemp tops and the yarrow's flowers in, no crabapples yet, bark all year")
	f.day_override = 268.0
	f._update_season(true)
	check(f.in_season("crabapple") and f.fruit_shown("crabapple") and f.in_season("red_osier"), "late September: the crabapples")
	var cp := _patches("crabapple")
	var pi := f.patches.find(cp[0]) if not cp.is_empty() else -1
	check(pi >= 0 and f.take(pi, 0) > 0.0, "a handful taken from a crabapple tree")
	f.day_override = -1.0
	f._update_season(true)


func _inv(kind: String, n := 1) -> InventoryState:
	var inv := InventoryState.from_player(player)
	inv.add(kind, n)
	return inv


func _test_yarrow() -> void:
	player.health = player.max_health
	var src := Node.new()
	src.set_meta(&"damage_kind", "bleed")
	root.add_child(src)
	player.apply_hit(40.0, player.global_position + Vector3.UP, Vector3.FORWARD, src, "body")
	src.queue_free()
	check(player.wounds.bleeding(), "a bleeding wound (%.1f to lose)" % player.wounds.pool)
	var line := ForageUse.use(player, "yarrow", _inv("yarrow"))
	var t0 := Time.get_ticks_msec()
	while player.wounds.bleeding() and Time.get_ticks_msec() - t0 < 6000:
		await physics_frame
	check(not player.wounds.bleeding() and Time.get_ticks_msec() - t0 < 3500,
			"yarrow packed in: the bleeding stops within %.1f s (%s)" % [(Time.get_ticks_msec() - t0) / 1000.0, line])
	lc.wounds().clear()
	player.health = player.max_health


func _test_willow() -> void:
	lc.wounds().clear()
	lc.hit("l_leg", "front", "bleed", 20.0)
	lc.hit("r_arm", "front", "bleed", 20.0)
	lc.state("ague")["on"] = true
	lc.state("ague")["recover"] = 0.0
	check(lc.restless() and lc.reload_mult() > 1.0, "a leg and an arm wound: restless, a slower reload")
	var line := Remedies.use(player, "willow_bark_tea", _inv("willow_bark_tea"))
	check(not lc.restless() or lc.is_on("ague"), "the tea taken (%s)" % line)
	check(lc.reload_mult() == 1.0 and absf(lc.numb_h() - LastingConditions.WILLOW_NUMB_H) < 0.01, "the pain dulled for six hours: the reload as ever")
	check(absf(lc.recovery("ague") - 0.5) < 0.01, "the fever down: the ague half mended (%.2f)" % lc.recovery("ague"))
	lc.state("ague")["on"] = false
	check(not lc.restless() and lc.has_wound("l_leg"), "the leg's pain dulled: not restless, though the wound is still there")
	check(lc.wound_rows().any(func(r: Array) -> bool: return String(r[1]).contains("dulled")), "the Condition tab says so")
	b.core.state.flags["numb_until"] = b.core.state.minutes - 1.0
	check(lc.restless() and lc.reload_mult() > 1.0, "six hours on: the pain back")
	lc.wounds().clear()


func _test_gruel() -> void:
	lc.state("flux")["on"] = true
	lc.state("flux")["recover"] = 0.0
	lc.hit("stomach", "front", "bleed", 20.0)
	check(absf(lc.food_mult() - 0.5) < 0.001, "the flux and a stomach wound: a meal nourishes half")
	var line := Remedies.use(player, "slippery_elm_gruel", _inv("slippery_elm_gruel"))
	check(lc.food_mult() == 1.0 and absf(lc.gut_h() - LastingConditions.GRUEL_GUT_H) < 0.01, "the gruel: a meal nourishes in full, half a day (%s)" % line)
	check(absf(lc.recovery("flux") - 0.25) < 0.01, "the flux a quarter mended (%.2f)" % lc.recovery("flux"))
	b.core.state.flags["gut_until"] = b.core.state.minutes - 1.0
	check(absf(lc.food_mult() - 0.5) < 0.001, "worn off: half again")
	lc.state("flux")["on"] = false
	lc.wounds().clear()


func _test_syrup() -> void:
	b.chill.state()["on"] = true
	b.chill.state()["recover"] = 0.0
	var line := Remedies.use(player, "elderberry_syrup", _inv("elderberry_syrup"))
	check(absf(b.chill.recovery() - 0.25) < 0.01, "the syrup: chilled to the bone a quarter mended (%.2f; %s)" % [b.chill.recovery(), line])
	b.chill.state()["on"] = false
	b.chill.state()["recover"] = 0.0


func _test_tonic() -> void:
	var fl := b.core.state.flags
	var now := b.core.state.minutes
	b.core.state.needs["stomach"] = 2500.0
	fl["heal_rest_until"] = now - 1.0
	fl["well_rested_until"] = now + 60.0
	Remedies.use(player, "ginseng_tonic", _inv("ginseng"))
	var line := Remedies.use(player, "ginseng_tonic", _inv("ginseng_tonic"))
	check(b.rested_hours_left() > 4.5 and not b.is_healing_rest(), "a tonic on a nap's rest: longer rested, no healing (%s)" % line)
	fl["heal_rest_until"] = now + 60.0
	fl["well_rested_until"] = now + 60.0
	Remedies.use(player, "ginseng_tonic", _inv("ginseng_tonic"))
	check(b.is_healing_rest() and absf(float(fl.heal_rest_until) - float(fl.well_rested_until)) < 0.01, "on the day's healing rest: the healing runs on with it")
	fl.erase("well_rested_until")
	fl.erase("heal_rest_until")


func _test_recipes() -> void:
	var want := {"willow_bark_tea": "willow_bark", "slippery_elm_gruel": "elm_bark", "elderberry_syrup": "elderberries"}
	var ok := want.keys().all(func(r: String) -> bool:
		var rc: Dictionary = Remedies.RECIPES.get(r, {})
		return bool(rc.get("fire", false)) and (rc.get("inputs", {}) as Dictionary).has(want[r]) and Remedies.can_use(r))
	check(ok, "the alchemy table makes the three over a fire, from the plants")


func _end() -> void:
	if fails.is_empty():
		print("PLANTS HERBS TEST OK (%d checks)" % checks)
	else:
		print("PLANTS HERBS TEST FAILED (%d of %d): %s" % [fails.size(), checks, fails])
	quit(0 if fails.is_empty() else 1)
