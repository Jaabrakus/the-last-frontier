extends SceneTree
## The woodpile and the smokehouse (user 2026-09-27: "a woodpile that feeds a fire by itself overnight, and a smokehouse
## for storing jerky"), and the chest screen clicked through with real mouse and key events, on the level with the
## survival bridge, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_woodpile_smokehouse.gd -- survival=on survival_seed=7
##
##   woodpile    firewood stacked on it; beside a campfire it feeds it: the fire burns on for hours past its own wood
##               and the pile goes down; a night's sleep by it and the fire does not die; a stick taken back; saved
##   smokehouse  a larder of food only; firewood on the smudge; raw venison in it turns to jerky after 20 game hours of
##               smoke, a woodpile beside it keeping the smudge going; saved
##   the screen  the chest opened, a click moves one, a right-click all, Esc closes it and the game goes on with the
##               player's weapon as it was
## Ends with "WOODPILE SMOKEHOUSE TEST OK (<n> checks)" or "... FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var mode: BuildMode
var spot := Vector3(24.0, 0.0, 10.0)
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


func settle(n := 3) -> void:
	for i in n:
		await process_frame
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
	await stand(at + Vector3(0, 0, 4.5))
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
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	for k in [["stone", 20], ["log", 10], ["pole", 12], ["branches", 14], ["firewood", 8]]:
		set_count(k[0], k[1])
	var plan := [["campfire", Vector3(0, 0, 0)], ["woodpile", Vector3(0, 0, -2.0)], ["smokehouse", Vector3(6.0, 0, 0)],
			["woodpile", Vector3(8.8, 0, 0.6)], ["storage_chest", Vector3(-4.0, 0, 3.0)]]
	var n := 0
	for e in plan:
		var at: Vector3 = spot + (e[1] as Vector3)
		at.y = FrontierTerrain.height_at(at.x, at.z)
		var p := await place(String(e[0]), at)
		built["%s%d" % [e[0], n]] = p
		n += 1
		check(p != null, "built: %s" % e[0])
	await _test_woodpile()
	await _test_smokehouse()
	await _test_screen()
	_end()


func _test_woodpile() -> void:
	var cfp: BuiltPiece = built.get("campfire0")
	var wpp: BuiltPiece = built.get("woodpile1")
	if cfp == null or wpp == null:
		return
	var cf := cfp.get_node("Campfire") as Campfire
	var pile := wpp.get_node_or_null("Woodpile") as Woodpile
	check(pile != null and pile.count == 0, "an empty woodpile")
	await stand(pile.global_position + Vector3(0, 0, 1.3))
	set_count("firewood", 12)
	check(pile.interact_prompt(player).begins_with("Stack firewood"), "E: '%s'" % pile.interact_prompt(player))
	pile.interact(player)
	b.camp.refresh()
	check(pile.count == 12 and count("firewood") == 0, "12 sticks stacked")
	check(pile.fire == cf, "beside the campfire: it feeds it")
	check(pile.interact_prompt(player).contains("it feeds the fire"), "the prompt says so: '%s'" % pile.interact_prompt(player))
	# the fire's own wood: one stick (the build's four burnt down first)
	cf.record()["fuel_min"] = Campfire.FUEL_MIN_PER_WOOD
	cf.light()
	await settle(2)
	for i in 18:                                          # six game hours, the pile watching every 20 minutes
		b.core.advance(20.0)
		b.camp.refresh()
	check(cf.is_lit(), "six game hours on one stick of its own: still burning")
	check(pile.count <= 10 and pile.count >= 8, "the pile went down as it fed it (%d left)" % pile.count)
	# a night's sleep by it: the fire does not die
	await stand(cf.global_position + Vector3(1.4, 0, 0.8))
	b.core.state.needs["stomach"] = 3000.0
	b.core.state.needs["reserve"] = 2500.0
	cf.record()["fuel_min"] = 50.0                         # its own wood nearly gone: the pile must carry it
	var pile0 := pile.count
	check(b.sleeper.start(), "asleep by the fire, its own wood nearly gone (the pile %d)" % pile0)
	var t0 := Time.get_ticks_msec()
	while b.sleeper.sleeping and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	await frames(30)
	check(not b.sleeper.why_woke.begins_with("the fire") and b.sleeper.slept_h >= 5.0, "woke for '%s' after %.1f h, not the fire" % [b.sleeper.why_woke, b.sleeper.slept_h])
	check(cf.is_lit() and pile.count < pile0, "the fire burns on, the pile fed it through the night (%d -> %d)" % [pile0, pile.count])
	# a stick taken back, and the save
	await stand(pile.global_position + Vector3(0, 0, 1.3))
	var before := pile.count
	if before > 0:
		pile.interact(player)
		b.camp.refresh()
		check(count("firewood") == mini(Woodpile.FETCH, before) and pile.count == before - mini(Woodpile.FETCH, before), "E with none in the pack: two back")
	var saved := -1
	for e: Dictionary in SaveParts.save_building(current_scene).get("pieces", []):
		if String(e.type) == "woodpile" and e.has("woodpile"):
			saved = maxi(saved, int(e.woodpile))
	check(saved == pile.count, "the pile is in the save (%d)" % saved)


func _test_smokehouse() -> void:
	var sp: BuiltPiece = built.get("smokehouse2")
	var wp2: BuiltPiece = built.get("woodpile3")
	if sp == null:
		return
	var sh := sp.get_node_or_null("Smokehouse") as Smokehouse
	check(sh != null and sh.accepts("venison") and sh.accepts("jerky") and not sh.accepts("stone"), "the smokehouse's larder takes food only")
	await stand(sh.interact_point() + Vector3(0, 0, 1.0))
	set_count("firewood", 2)
	var rows := sh.menu_rows(player)
	check(rows.size() == 2 and bool(rows[1].ok), "its menu: %s" % str(rows.map(func(r): return "%s (%s)" % [r.text, r.ok])))
	check(sh.lay_wood(player) == 2 and sh.smudge_lit(), "two sticks on the smudge: %.0f game minutes" % sh.smudge_min)
	set_count("venison", 3)
	var inv := InventoryState.from_player(player)
	check(sh.put(inv, "venison", 2) == 2 and sh.smoke.size() == 2, "two venison hung in it")
	player.inventory_pack = inv.pack.duplicate(true)
	# a woodpile beside it keeps the smudge going
	var pile := wp2.get_node_or_null("Woodpile") as Woodpile if wp2 else null
	if pile:
		await stand(pile.global_position + Vector3(0, 0, 1.3))
		set_count("firewood", 6)
		pile.interact(player)
	check(pile != null and pile.count == 6 and pile.fire == null, "a woodpile beside it (6), no fire to feed")
	sh.tick()
	b.core.advance(10.0 * 60.0)
	await settle(2)
	sh.tick()
	check(sh.smudge_lit() and sh.count_of("venison") == 2, "ten hours on: still smoking (the pile fed it: %d left)" % (pile.count if pile else -1))
	b.core.advance(11.0 * 60.0)
	await settle(2)
	sh.tick()
	check(sh.count_of("venison") == 0 and sh.count_of("jerky") == 5, "twenty-one hours: two venison smoked into %d jerky" % sh.count_of("jerky"))
	check(sh.interact_prompt(player).contains("larder"), "'%s'" % sh.interact_prompt(player))
	var d := sh.to_save_all()
	sh.items.clear()
	sh.smudge_min = 0.0
	sh.from_save_all(d)
	check(sh.count_of("jerky") == 5 and absf(sh.smudge_min - float(d.smudge)) < 0.01, "the larder and the smudge in the save")


func _test_screen() -> void:
	var cp: BuiltPiece = built.get("storage_chest4")
	if cp == null:
		return
	var chest := cp.get_node("Chest") as StorageChest
	await stand(chest.global_position + Vector3(0, 0, 1.4))
	set_count("stone", 4)
	set_count("branches", 3)
	var wkey := String(player.weapon_key)
	chest.interact(player)
	await process_frame
	await process_frame
	var scr: ChestScreen = null
	for c in root.get_children():
		if c is ChestScreen:
			scr = c
	check(scr != null and paused, "the chest's screen is open, the game paused")
	if scr == null:
		return
	var row := _row(scr, "stone", true)
	check(row != null, "the pack's stone has a row")
	if row:
		_click(row, MOUSE_BUTTON_LEFT)
		await process_frame
		await process_frame
		check(chest.count_of("stone") == 1 and count("stone") == 3, "a click: one stone in (%d, %d)" % [chest.count_of("stone"), count("stone")])
		row = _row(scr, "stone", true)
		_click(row, MOUSE_BUTTON_RIGHT)
		await process_frame
		await process_frame
		check(chest.count_of("stone") == 4 and count("stone") == 0, "a right-click: all the stone in")
		var back := _row(scr, "stone", false)
		_click(back, MOUSE_BUTTON_LEFT)
		await process_frame
		await process_frame
		check(chest.count_of("stone") == 3 and count("stone") == 1, "a click on the chest's side: one back")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await process_frame
	var up := esc.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	for i in 4:
		await process_frame
	check(not paused and not is_instance_valid(scr), "Esc closes it, the game goes on")
	await frames(10)
	check(String(player.weapon_key) == wkey, "the player's weapon as it was (%s)" % player.weapon_key)


## The button of `kind` on the pack's side (or the chest's).
func _row(scr: ChestScreen, kind: String, pack: bool) -> Button:
	var box: VBoxContainer = scr._pack_box if pack else scr._chest_box
	for c in box.get_children():
		if c is Button and String(c.get_meta(&"kind", "")) == kind and not c.is_queued_for_deletion():
			return c
	return null


## A real click on `b`: the mouse moved there, the button pressed and let go, through the viewport's input.
func _click(b: Button, button: MouseButton) -> void:
	var at := b.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		ev.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
		root.push_input(ev)


func _end() -> void:
	if fails.is_empty():
		print("WOODPILE SMOKEHOUSE TEST OK (%d checks)" % checks)
	else:
		print("WOODPILE SMOKEHOUSE TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
