extends SceneTree
## Making your gear (user 2026-09-28: "making your gear": the rod and spear, trapping gear),
## on the level with the real player and the survival bridge, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_gear.gd -- survival=on survival_seed=7
##
##   kit        a new game's backcountry hunter has his kit's gear in the pack (game_items.json start_gear): two steel
##              traps, three pounds of bar lead, the bullet mould, hooks and line, sinew; the powder stays with the kit
##   workbench  cordage twisted from sinew; a fishing rod from a pole and the hooks and line (or cordage, with none);
##              a fish spear from a pole and antler (or flint); deadfall stakes from branches; stopping gives them back
##   rod        the rod from the bench comes out on the gear key (FishingGear)
##   fire       a lit campfire offers no ball casting (ShotMaking was retired in the 2026-10-06 cleanup)
## Ends with "GEAR TEST OK (<n> checks)" or "GEAR TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var mode: BuildMode
var spot := Vector3(-24.0, 0.0, 12.0)
var built := {}


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
	b.camp.refresh()


func place(type: String, at: Vector3) -> BuiltPiece:
	await stand(at + Vector3(0, 0, 4.0))
	mode.set_active(true)
	mode.select_type(type)
	mode.aim_at = at
	for i in 6:
		await physics_frame
	mode.refresh_placement()
	var p := mode.place()
	if p == null:
		print("    place %s: %s" % [type, mode.verdict.get("reason", "-")])
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	return p


func wait_work(limit := 45.0) -> void:
	var t0 := Time.get_ticks_msec()
	while (b.work.working or player.kneeling != null) and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await process_frame
	await frames(4)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(20)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	check(b != null and player != null, "the level has the survival bridge (survival=on)")
	if b == null:
		_end()
		return
	player.ignore_mouse_capture = true
	mode = player.get_node_or_null("BuildMode") as BuildMode
	SurvivalWeather.set_external(b.core, "clear", 2.0, 250.0)
	_kit()
	for k in [["stone", 20], ["log", 8], ["pole", 12], ["branches", 12], ["firewood", 6]]:
		set_count(k[0], k[1])
	for e in [["workbench", Vector3(2.0, 0, 0)], ["campfire", Vector3(-3.0, 0, 0)]]:
		var at: Vector3 = spot + (e[1] as Vector3)
		at.y = FrontierTerrain.height_at(at.x, at.z)
		built[String(e[0])] = await place(String(e[0]), at)
		check(built[String(e[0])] != null, "built: %s" % e[0])
	await _workbench()
	await _rod()
	await _fire()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("GEAR TEST OK (%d checks)" % checks)
	else:
		print("GEAR TEST FAILED %d/%d: %s" % [fails.size(), checks, str(fails)])
	quit(0 if fails.is_empty() else 1)


func _kit() -> void:
	var powder := SurvivalInventory.count(b.core, "item.ammo.powder")
	check(count("steel_trap") == 2 and count("bar_lead") == 3 and count("bullet_mould") == 1 and count("hooks_line") == 1
			and count("sinew") >= 2 and SurvivalInventory.count(b.core, "item.trap.steel") == 0.0 and powder >= 1.9,
			"kit: 2 steel traps, 3 bar lead, the mould, hooks and line, %d sinew in the pack; %.1f lb powder with the kit" % [count("sinew"), powder])


func _make(st: CampStation, id: String) -> bool:
	var ok := st.make(player, id)
	await wait_work()
	return ok


func _workbench() -> void:
	var bp: BuiltPiece = built.get("workbench")
	var st := bp.get_node_or_null("Station") as CampStation if bp else null
	if st == null:
		return
	await stand(st.global_position + Vector3(0, 0, 1.3))
	var ids := st.menu_rows(player).map(func(r: Dictionary) -> String: return String(r.id))
	check(ids.has("cordage") and ids.has("fishing_rod") and ids.has("fish_spear") and ids.has("stake_set"),
			"the bench offers cordage, a fishing rod, a fish spear and deadfall stakes")
	set_count("sinew", 2)
	check(await _make(st, "cordage") and count("cordage") == 2 and count("sinew") == 1, "cordage: a sinew twisted into 2 lengths (%d)" % count("cordage"))
	set_count("pole", 3)
	check(await _make(st, "fishing_rod") and count("fishing_rod") == 1 and count("hooks_line") == 0 and count("pole") == 2,
			"a fishing rod: a pole and the hooks and line")
	check(await _make(st, "fishing_rod") and count("fishing_rod") == 2 and count("cordage") == 1,
			"no hooks and line: the rod's line from cordage")
	set_count("pole", 2)
	set_count("antler", 1)
	check(await _make(st, "fish_spear") and count("fish_spear") == 1 and count("antler") == 0, "a fish spear: a pole and antler barbs")
	set_count("flint", 1)
	check(await _make(st, "fish_spear") and count("fish_spear") == 2 and count("flint") == 0, "no antler: flint barbs")
	set_count("pole", 0)
	var why := ""
	for r: Dictionary in st.menu_rows(player):
		if String(r.id) == "fish_spear":
			why = String(r.detail) if not bool(r.ok) else ""
	check(why.begins_with("needs 1 pole"), "no pole: '%s'" % why)
	set_count("branches", 4)
	check(await _make(st, "stake_set") and count("stake_set") == 1 and count("branches") == 1, "deadfall stakes: 3 branches")
	# stopped: the things come back
	set_count("sinew", 1)
	var c0 := count("cordage")
	st.make(player, "cordage")
	await frames(10)
	check(count("sinew") == 0, "at work: the sinew is taken")
	b.work.stop()
	await wait_work()
	check(count("sinew") == 1 and count("cordage") == c0, "stopped: the sinew back, no cordage")


func _rod() -> void:
	var g := FishingGear.find(player)
	check(g != null and g.take_out("fishing_rod") and g.gear == "fishing_rod", "the bench's rod comes out on the gear key")
	if g:
		g.put_away()
	await frames(4)


func _fire() -> void:
	var fp: BuiltPiece = built.get("campfire")
	var fire := fp.get_node_or_null("Campfire") as Campfire if fp else null
	if fire == null:
		check(false, "the campfire has its Campfire")
		return
	await stand(fire.global_position + Vector3(0, 0, 1.5))
	set_count("firewood", 3)
	for i in 3:
		fire.interact(player)
	await frames(6)
	check(fire.is_lit(), "the fire laid and lit")
	var ids := []
	for r: Dictionary in fire.interact_actions(player):
		ids.append(String(r.id))
	check(not ids.has("cast"), "no ball casting at the lit fire (%s)" % [ids])
