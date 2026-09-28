extends SceneTree
## The workbench, the stretching hoop, the storage chest and the hearth's fire (user 2026-09-27: "a workbench for
## moccasins, arrows and spears; a stretching hoop for wolf and fox pelts; a storage chest; making the stone hearth burn
## as a real fire indoors"), on the level with the real player and the survival bridge, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_workshop.gd -- survival=on survival_seed=7
##
##   chest      things go in and out (not the worn gear, not the knife), the screen pauses the game and moves them, the
##              lid opens, and what is in it goes in the save
##   workbench  moccasins and fur mitts into the core's kit, mending the worn pair, fletched arrows into the quiver (shafts
##              of shoots or branches, a flint, feathers), a throwing spear and darts up to what can be carried; stopping
##              gives the materials back
##   hoop       a wolf pelt stretched (the core's fur.stretch), drying on the hoop for days (the core's record, saved
##              with it), then taken down dried; deer give sinew
##   hearth     built without wood, laid and lit; its own chimney keeps the rain off; smoke from the stack top; under a
##              roof with it lit the core has the player indoors (14 C air); it cooks
## Ends with "WORKSHOP TEST OK (<n> checks)" or "WORKSHOP TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var mode: BuildMode
var spot := Vector3(24.0, 0.0, 10.0)
var built := {}


class FakeRain:
	extends Node
	var rain := 1.0

	func rain_intensity(_pos: Vector3) -> float:
		return rain


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


func station(key: String) -> CampStation:
	var p: BuiltPiece = built.get(key)
	return p.get_node_or_null("Station") as CampStation if p else null


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
	var d := BuildData.get_default()
	check(d.group_of("workbench") == "Crafting" and d.group_of("stretching_hoop") == "Crafting" and d.group_of("storage_chest") == "Furniture",
			"new pieces: workbench and stretching hoop (Crafting), storage chest (Furniture)")
	for k in [["stone", 20], ["log", 8], ["pole", 12], ["branches", 12]]:
		set_count(k[0], k[1])
	var plan := [["hearth", Vector3(-3.5, 0, 0)], ["workbench", Vector3(2.0, 0, 0)], ["stretching_hoop", Vector3(5.0, 0, 0)],
			["storage_chest", Vector3(0.0, 0, 4.0)]]
	for e in plan:
		var at: Vector3 = spot + (e[1] as Vector3)
		at.y = FrontierTerrain.height_at(at.x, at.z)
		var p := await place(String(e[0]), at)
		built[String(e[0])] = p
		check(p != null, "built: %s" % e[0])
	await _test_chest()
	await _test_workbench()
	await _test_hoop()
	await _test_hearth()
	_end()


func _test_chest() -> void:
	var cp: BuiltPiece = built.get("storage_chest")
	if cp == null:
		return
	var chest := cp.get_node_or_null("Chest") as StorageChest
	check(chest != null, "the chest has its StorageChest")
	check(StorageChest.can_store("venison") and not StorageChest.can_store("musket") and not StorageChest.can_store("skinning_knife"),
			"it takes loose things, not the worn gear or the knife")
	await stand(chest.global_position + Vector3(0, 0, 1.4))
	check(chest.interact_prompt(player) == "Open the chest (empty)", "E: '%s'" % chest.interact_prompt(player))
	set_count("venison", 3)
	set_count("stone", 5)
	var inv := InventoryState.from_player(player)
	check(chest.put(inv, "venison", 3) == 3 and chest.count_of("venison") == 3, "3 venison in")
	check(chest.take(inv, "venison", 2) == 2 and chest.count_of("venison") == 1, "2 back out")
	player.inventory_pack = inv.pack.duplicate(true)
	check(count("venison") == 2, "the pack has them (%d)" % count("venison"))
	# the screen
	chest.interact(player)
	await process_frame
	var scr: ChestScreen = null
	for c in root.get_children():
		if c is ChestScreen:
			scr = c
	check(scr != null and paused, "E opens it: the screen, the game paused")
	if scr:
		scr.move("stone", true, 1 << 30)
		await process_frame
		check(chest.count_of("stone") == 5 and count("stone") == 0, "a right-click moves all the stone in")
		check(chest.open, "the lid is open")
		scr.close()
		await process_frame
		await process_frame
		check(not paused and not chest.open, "closed: the game goes on")
	# the save
	var sb := SaveParts.save_building(current_scene)
	var saved: Array = []
	for e: Dictionary in sb.get("pieces", []):
		if String(e.type) == "storage_chest":
			saved = e.get("chest", [])
	check(saved.size() == 2, "the save holds what is in it: %s" % str(saved))
	chest.items.clear()
	chest.from_save(saved)
	check(chest.count_of("stone") == 5 and chest.count_of("venison") == 1, "and puts it back")


func _test_workbench() -> void:
	var st := station("workbench")
	if st == null:
		return
	await stand(st.global_position + Vector3(0, 0, 1.3))
	var core := b.core
	b.core.state.needs["stomach"] = 2000.0
	set_count("buckskin", 1)
	set_count("dried_fox_pelt", 1)
	set_count("branches", 6)
	set_count("shoots", 0)
	set_count("feathers", 3)
	set_count("flint", 3)
	set_count("pole", 2)
	SurvivalInventory.add(core, "item.material.hide_scrap", 1.0)
	SurvivalInventory._wear(core)[CampStation.MOCCASINS] = 0.5
	var spear := player.weapons.get("spear") as Throwable
	var atl := player.weapons.get("atlatl") as Throwable
	var bow := player.weapons.get("bow") as Bow
	spear.count = 1
	atl.count = 3
	var rows := st.menu_rows(player)
	var names: Array = rows.map(func(r): return "%s (%s)" % [r.text, r.ok])
	# the kit's three (moccasins, mending, mitts), the clothes of skin and fur (CampStation.SKINS), the arms (BENCH),
	# the weapons made whole (ARMS: not while the bow and the atlatl are carried), the trapper's and angler's gear
	# (CampStation.GEAR: cordage, a rod, a fish spear, deadfall stakes; tests/survival_game/test_gear.gd), the knapping
	# stone's awl and torches (STONE_AT_BENCH), the vices' stuff (Vices.BENCH: snuff, a quid, sweet cider)
	var ids: Array = rows.map(func(r): return String(r.id))
	# (ARMS: the ones this character's roster has; the guns are assembled here, BENCH_WOOD carves their stock)
	var arms: Array = CampStation.ARMS.keys().filter(func(k: String) -> bool: return player.weapons.has(String(CampStation.ARMS[k].weapon)))
	var want: Array = ["rcp.moccasins", "clothing.repair_moccasins", "rcp.mitts_fur"] + CampStation.SKINS.keys() + CampStation.BENCH.keys() \
			+ arms + CampStation.GEAR.keys() + CampStation.STONE_AT_BENCH + CampStation.BENCH_WOOD.keys() + Vices.BENCH.keys()
	var okd := {}
	for r: Dictionary in rows:
		okd[String(r.id)] = bool(r.ok)
	check(ids == want and okd["rcp.moccasins"] and okd["clothing.repair_moccasins"] and okd["rcp.mitts_fur"] and okd.arrows and okd.spear
			and okd.darts and not okd.bow and not okd.atlatl, "the bench's menu: %s" % str(names))
	# arrows, stopped half way: the branches and flint come back
	var q0 := bow.quiver
	check(st.make(player, "arrows") and count("branches") == 4 and count("flint") == 2 and count("feathers") == 2, "cutting arrows (no shoots: branches for the shafts)")
	await frames(20)
	b.work.stop()
	await wait_work()
	check(count("branches") == 6 and count("flint") == 3 and count("feathers") == 3 and bow.quiver == q0, "stopped: the branches, flint and feathers come back")
	check(st.make(player, "arrows"), "arrows again")
	await wait_work()
	check(bow.quiver == q0 + 6 and count("branches") == 4 and count("flint") == 2, "6 arrows into the quiver (%d): %s" % [bow.quiver, st.last.get("text", "")])
	set_count("feathers", 0)
	var arow: Dictionary = st.menu_rows(player).filter(func(r: Dictionary) -> bool: return String(r.id) == "arrows")[0]
	check(not bool(arow.ok) and String(arow.detail).contains("feather"), "no feathers, no arrows: '%s'" % arow.detail)
	set_count("feathers", 3)
	check(st.make(player, "spear"), "a throwing spear")
	await wait_work()
	check(spear.count == 2 and count("pole") == 1, "the spears carried: %d" % spear.count)
	var srow: Dictionary = st.menu_rows(player).filter(func(r: Dictionary) -> bool: return String(r.id) == "spear")[0]
	check(not bool(srow.ok) and String(srow.detail).contains("carry all"), "both carried: no more")
	check(st.make(player, "darts"), "atlatl darts")
	await wait_work()
	check(atl.count == 5, "the darts carried: %d" % atl.count)
	# the kit's moccasins, mending and mitts (the core's recipes: the Hidecraft check may fail)
	var pairs0 := SurvivalInventory.count(core, CampStation.MOCCASINS)
	check(st.make(player, "rcp.moccasins") and count("buckskin") == 0, "moccasins: the buckskin on the bench")
	await wait_work()
	var pairs1 := SurvivalInventory.count(core, CampStation.MOCCASINS)
	check(String(st.last.get("what", "")) == "moccasins" and (pairs1 == pairs0 + 1 or String(st.last.text).contains("will not hold")),
			"moccasins: %s (%d -> %d pairs)" % [st.last.get("text", ""), int(pairs0), int(pairs1)])
	check(SurvivalInventory.count(core, "item.skin.dressed_buckskin") >= 0.6 or pairs1 == pairs0, "two thirds of the buckskin stay for the next pairs")
	var w0 := SurvivalInventory.wear_of(core, CampStation.MOCCASINS)
	check(st.make(player, "clothing.repair_moccasins"), "mending the worn pair (%d%% worn)" % roundi(w0 * 100.0))
	await wait_work()
	var w1 := SurvivalInventory.wear_of(core, CampStation.MOCCASINS)
	check(w1 < w0 or String(st.last.get("text", "")).contains("will not hold"), "mended: %s" % st.last.get("text", ""))
	var mitts0 := SurvivalInventory.count(core, "item.cloth.mitts")
	check(st.make(player, "rcp.mitts_fur") and count("dried_fox_pelt") == 0, "fur mitts from the fox pelt")
	await wait_work()
	check(String(st.last.get("what", "")) == "mitts" and (SurvivalInventory.count(core, "item.cloth.mitts") > mitts0 or String(st.last.text).contains("come out wrong")),
			"mitts: %s" % st.last.get("text", ""))
	check(int((WildlifeSpecies.DATA.deer.butcher as Dictionary).get("sinew", 0)) == 2, "a deer's butchering gives 2 sinew")


func _test_hoop() -> void:
	var st := station("stretching_hoop")
	if st == null:
		return
	await stand(st.global_position + Vector3(0, 0, 1.3))
	b.core.state.needs["stomach"] = 2000.0
	set_count("wolf_pelt", 1)
	check(st.interact_prompt(player).begins_with("Stretch a wolf pelt"), "E: '%s'" % st.interact_prompt(player))
	st.interact(player)
	await frames(4)
	check(b.work.working and count("wolf_pelt") == 0, "lacing the pelt into the hoop")
	await wait_work()
	var rec := st.hoop_record()
	check(rec.size() == 1 and float(rec[0].ready_at) > b.core.state.minutes + 24.0 * 60.0, "on the hoop, drying for days: %s" % st.last.get("text", ""))
	var left := 0.0
	for s2 in b.core.state.inventory:
		if String(s2.id) == "item.pelt.wolf":
			left += float(s2.qty)
	check(left == 0.0, "not left in the core's kit")
	check(st.interact_prompt(player).contains("dries on the hoop"), "the prompt: '%s'" % st.interact_prompt(player))
	check(JSON.stringify(b.save_state()).contains(st.tag()), "the hoop's pelt is in the survival save")
	b.core.advance(3.2 * SurvivalClock.MIN_PER_DAY)
	await settle(3)
	check(st.hoop_ready() == "wolf_pelt" and st.interact_prompt(player).begins_with("Take down"), "three days on: '%s'" % st.interact_prompt(player))
	st.interact(player)
	check(count("dried_wolf_pelt") == 1 and st.hoop_record().is_empty(), "taken down: a dried wolf pelt")


func _test_hearth() -> void:
	var hp: BuiltPiece = built.get("hearth")
	if hp == null:
		return
	var hf := hp.get_node_or_null("Campfire") as Campfire
	check(hf != null and hf.hearth and not hf.is_lit() and hf.fuel_min() <= 0.0, "the hearth has a fire of its own, no wood laid")
	if hf == null:
		return
	check(hf.fire.smoke.position.y > 4.5, "its smoke comes out of the stack top (%.1f m up)" % hf.fire.smoke.position.y)
	var front := hp.global_transform * Vector3(0, 0, BuildGeometry.HEARTH_D + 1.3)
	await stand(front)
	set_count("firewood", 4)
	check(hf.interact_prompt(player).begins_with("Lay firewood"), "E: '%s'" % hf.interact_prompt(player))
	hf.interact(player)
	hf.interact(player)
	hf.interact(player)
	await settle(3)
	check(hf.is_lit() and hf.fire_id != "" and str(SurvivalCamp.fire(b.core, hf.fire_id).get("state", "")) == "lit", "laid and lit, a fire in the core")
	# the rain: its chimney keeps it off
	var rain := FakeRain.new()
	rain.add_to_group(TorchState.WEATHER_GROUP)
	current_scene.add_child(rain)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 14000:
		await process_frame
	rain.queue_free()
	check(hf.is_lit(), "heavy rain: still burning under its chimney")
	# indoors: a roof over the room in front of it, then its walls
	b.camp.refresh()
	check(not bool(b.core.state.context.get("indoors", true)), "no roof: not indoors")
	var w := BuildWorld.of(self)
	var roof: BuiltPiece = w.add_piece("roof", Transform3D(hp.global_basis, hp.global_transform * Vector3(0, BuildGeometry.WALL_H + 0.02, 2.2)), false, -1)
	await frames(4)
	b.camp.refresh()
	check(not bool(b.core.state.context.get("indoors", true)) and b.camp.shelter_word() == "under your roof",
			"a roof on open sides, the hearth lit: '%s', not indoors (walls %.2f)" % [b.camp.shelter_word(), b.camp.enclosure(player.global_position)])
	var walls: Array = []
	var yb := hp.global_basis
	for e2 in [[Vector3(0, 0, 0.7), 0.0], [Vector3(0, 0, 3.7), 0.0], [Vector3(-1.5, 0, 2.2), PI * 0.5], [Vector3(1.5, 0, 2.2), PI * 0.5]]:
		walls.append(w.add_piece("wall_door" if walls.size() == 1 else "wall", Transform3D(yb * Basis(Vector3.UP, float(e2[1])), hp.global_transform * (e2[0] as Vector3)), true, -1))
	await frames(4)
	b.camp.refresh()
	var e := SurvivalNeeds.env(b.core)
	check(b.camp.enclosure(player.global_position) >= CampLink.ENCLOSED, "four walls round (a door in one): walled %.2f" % b.camp.enclosure(player.global_position))
	check(bool(b.core.state.context.get("indoors", false)) and float(e.air_c) == SurvivalNeeds.INDOOR_AIR_C, "a walled cabin with the hearth lit: indoors (%.0f C)" % float(e.air_c))
	check(b.camp.shelter_word() == "in your cabin, warm by the hearth", "'%s'" % b.camp.shelter_word())
	var sh: Dictionary = SurvivalCamp.shelters(b.core).get(str(b.core.state.context.get("shelter_id", "")), {})
	check(str(sh.get("type", "")) == CampLink.CABIN_KIND and float(sh.get("quality", 0.0)) == CampLink.CABIN_Q, "the roof's record is a cabin now (%s)" % str(sh))
	hf.smother()
	await settle(2)
	b.camp.refresh()
	check(not bool(b.core.state.context.get("indoors", true)), "the hearth out: a roof, no longer indoors")
	# it cooks
	set_count("firewood", 2)
	hf.interact(player)
	hf.interact(player)
	await settle(2)
	b.core.state.needs["stomach"] = 0.0
	set_count("venison", 1)
	set_count("roast_venison", 0)
	check(b.cook.start(hf), "F at the hearth: venison on the fire")
	var t1 := Time.get_ticks_msec()
	while (b.cook.cooking or player.kneeling != null) and Time.get_ticks_msec() - t1 < 40000:
		await process_frame
	check(count("roast_venison") + count("charred_venison") == 1, "cooked at the hearth: %s" % b.cook.last.get("text", ""))
	var sb := SaveParts.save_building(current_scene)
	var has_fire := false
	for p2: Dictionary in sb.get("pieces", []):
		if String(p2.type) == "hearth" and p2.has("fire"):
			has_fire = true
	check(has_fire, "the hearth's fire is in the save")


func _end() -> void:
	if fails.is_empty():
		print("WORKSHOP TEST OK (%d checks)" % checks)
	else:
		print("WORKSHOP TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
