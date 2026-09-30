extends SceneTree
## Climbing gear made at the camp stations, and quality from practice (user 2026-09-29: "most items can be obtained
## from npcs via the knowledge journal or self made but will take continued makes to make better quality"), on the level
## with the real player and the survival bridge, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_climbing_gear.gd -- survival=on survival_seed=7
##
##   rows       the knapping stone offers the stakes (wood, bone, stone); the ashiko copies are closed until know.ashiko is
##              heard of (Old Pieter teaches it), then open
##   practice   fire-hardened stakes made over and over come out plain, then good from the 4th make (StationPractice),
##              stamped on the pack's stack; the row shows the standard earned
##   worn       the good pair worn on the belt keeps its standard (InventoryState: pack state onto the body), and the grip
##              drains less than with a plain pair (PlayerGrip.stakes_drain_mult)
##   bone       a deer's butchering gives two leg bones (WildlifeSpecies)
## Ends with "CLIMBING GEAR TEST OK (<n> checks)" or "CLIMBING GEAR TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var mode: BuildMode
var spot := Vector3(24.0, 0.0, 10.0)


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func count(kind: String) -> int:
	return Campfire._pack_count(player, kind)


func set_count(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(player)
	var have := inv.pack_count(kind)
	if have > n:
		inv.take(kind, have - n)
	elif have < n:
		inv.add(kind, n - have)
	player.inventory_pack = inv.pack.duplicate(true)


func stand(p: Vector3) -> void:
	p.y = FrontierTerrain.height_at(p.x, p.z) + 0.05
	player.global_position = p
	player.velocity = Vector3.ZERO
	await frames(6)


func place(type: String, at: Vector3) -> BuiltPiece:
	await stand(at + Vector3(0, 0, 4.0))
	mode.set_active(true)
	mode.select_type(type)
	mode.aim_at = at
	for i in 6:
		await physics_frame
	mode.refresh_placement()
	var p := mode.place()
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	return p


func wait_work(limit := 45.0) -> void:
	var t0 := Time.get_ticks_msec()
	while (b.work.working or player.kneeling != null) and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await process_frame
	await frames(4)


func row(st: CampStation, id: String) -> Dictionary:
	for r: Dictionary in st.menu_rows(player):
		if String(r.get("id", "")) == id:
			return r
	return {}


func pack_state(kind: String) -> Dictionary:
	for e: Dictionary in InventoryState.from_player(player).pack:
		if String(e.kind) == kind:
			return e.get("state", {})
	return {}


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(20)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	check(b != null and player != null and b.work != null, "the level has the bridge and its work runner (survival=on)")
	if b == null:
		_end()
		return
	player.ignore_mouse_capture = true
	mode = player.get_node_or_null("BuildMode") as BuildMode
	SurvivalWeather.set_external(b.core, "clear", 2.0, 250.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	var p := await place("work_stone", spot)
	check(p != null, "a knapping stone built")
	var st := p.get_node_or_null("Station") as CampStation if p else null
	if st == null:
		_end()
		return
	await stand(st.global_position + Vector3(1.2, 0, 0))
	for k in [["branches", 20], ["rawhide", 10], ["bone", 4], ["flint", 4], ["sinew", 2], ["buckskin", 2], ["skinning_knife", 1]]:
		set_count(k[0], k[1])
	# rows: the stakes open, the ashiko closed until heard of
	check(bool(row(st, "climbing_stakes_wood").get("ok", false)), "the knapping stone offers fire-hardened stakes")
	check(bool(row(st, "climbing_stakes_bone").get("ok", false)), "and bone stakes (two leg bones)")
	check(not bool(row(st, "climbing_claws_wood").get("ok", true)) and String(row(st, "climbing_claws_wood").get("detail", "")).contains("Old Pieter"),
			"the ashiko copies are closed until taught: '%s'" % String(row(st, "climbing_claws_wood").get("detail", "")))
	SurvivalLearning.set_state(b.core, "know.ashiko", "heard_of", "talk", "", true)
	check(bool(row(st, "climbing_claws_wood").get("ok", false)), "heard of, the ashiko can be tried")
	# practice: plain x3, then good
	var got: Array = []
	for i in 4:
		var before := count("climbing_stakes_wood")
		check(st.make(player, "climbing_stakes_wood"), "make %d of the fire-hardened stakes starts" % (i + 1))
		await wait_work()
		check(count("climbing_stakes_wood") == before + 1, "make %d: one more pair in the pack" % (i + 1))
		got.append(StationPractice.standard_at(StationPractice.makes(b.core, "climbing_stakes_wood") - 1))
	check(got == ["plain", "plain", "plain", "good"], "the standard rises with practice: %s" % str(got))
	check(StationPractice.of_state(pack_state("climbing_stakes_wood")) == "good", "the pack's stack keeps its best: %s" % str(pack_state("climbing_stakes_wood")))
	check(String(row(st, "climbing_stakes_wood").get("text", "")).contains("good"), "the row shows the standard earned: '%s'" % String(row(st, "climbing_stakes_wood").get("text", "")))
	# worn: the good pair on the belt keeps its standard and eases the grip more than a plain pair
	var inv := InventoryState.from_player(player)
	check(inv.wear("climbing_stakes_wood", "back_left"), "the stakes worn behind the left hip")
	player.apply_loadout(inv.worn, inv.pack)
	player.inventory_pack = inv.pack.duplicate(true)
	var worn := (player.loadout as Loadout).first_of_kind("climbing_stakes_wood")
	check(StationPractice.of_state(worn.get("state", {})) == "good", "worn, the pair is still good: %s" % str(worn.get("state", {})))
	var m_good := player.grip.stakes_drain_mult()
	worn.state = {}
	var m_plain := player.grip.stakes_drain_mult()
	check(is_equal_approx(m_plain, 0.85) and m_good < m_plain, "a good pair eases the grip more (x%.3f) than a plain one (x%.3f)" % [m_good, m_plain])
	# the ashiko copy made once: the handed-down knowledge becomes known
	check(st.make(player, "climbing_claws_wood"), "the hardwood ashiko started")
	await wait_work()
	check(count("climbing_claws_wood") == 1 and SurvivalLearning.state_of(b.core, "know.ashiko") == "known",
			"made, and know.ashiko is known now (%s)" % SurvivalLearning.state_of(b.core, "know.ashiko"))
	# bone from a deer
	check(_deer_bone() == 2, "a deer's butchering gives two leg bones")
	_end()


func _deer_bone() -> int:
	var s := FileAccess.get_file_as_string("res://scripts/wildlife/wildlife_species.gd")
	return 2 if s.contains("\"sinew\": 2, \"bone\": 2") else 0


func _end() -> void:
	if fails.is_empty():
		print("CLIMBING GEAR TEST OK (%d checks)" % checks)
	else:
		print("CLIMBING GEAR TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
