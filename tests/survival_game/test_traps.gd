extends SceneTree
## The trap line (user 2026-09-28, "trapping lines": "set snares and steel traps, walk the line each morning, and carry
## the pelts to trade"), on the level with the real player and the survival bridge, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_traps.gd -- survival=on wildlife=on save=on survival_seed=7
##
## (wildlife=on: the spawner's cover map, where young trees stand for a snare)
##
##   steel      a steel trap placed (the build menu's Traps) and set with E: the pack's steel trap goes into it, the
##              rules' record keeps its place, cell and site; a marten in it (the dawn's catch, forced): the sprung
##              mesh and the catch show; E takes it: skinned and dressed, the pelt and the meat in the pack, set again
##   sprung     sprung empty: E sets it again
##   load       a piece finds its record again by its place (after a load)
##   snare      set with cordage among young trees; a hare hung in it: its meat, no pelt; in the open it will not set
##   deadfall   set with deadfall stakes (and the kit's hatchet); a raccoon under it: its pelt and two small game
##   take up    hold E takes a steel trap up (back to the pack, the record gone); build mode's take-down the same
##   after      the new pelts go on the stretching hoop; small game roasts on the fire
##   save       (with save=on) a steel trap holding a fox is saved and loaded: the piece finds its record, the fox in it
## Ends with "TRAPS TEST OK (<n> checks)" or "TRAPS TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var mode: BuildMode
var spot := Vector3(-24.0, 0.0, 12.0)


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
	at.y = FrontierTerrain.height_at(at.x, at.z)
	await stand(at + Vector3(0, 0, 3.0))
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


func wait_work(limit := 60.0) -> void:
	var t0 := Time.get_ticks_msec()
	while (b.work.working or player.kneeling != null) and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await process_frame
	await frames(4)


func trap_of(p: BuiltPiece) -> TrapStation:
	return p.get_node_or_null("Trap") as TrapStation if p else null


## Sets `ts` (a failed check keeps what went in: tries again, up to 6 times).
func set_it(ts: TrapStation) -> bool:
	for i in 6:
		await stand(ts.global_position + Vector3(0, 0, 1.0))
		if not ts.set_trap(player):
			return false
		await wait_work()
		if ts.state() == "set":
			return true
	return false


## The dawn's catch, forced: `sp` in the trap.
func catch(ts: TrapStation, sp: String) -> void:
	var r := ts.record()
	r["state"] = "holding"
	r["catch"] = sp
	r["catch_day"] = SurvivalClock.abs_day(b.core)
	ts.refresh_look()


func take(ts: TrapStation) -> void:
	await stand(ts.global_position + Vector3(0, 0, 1.0))
	ts.take_catch(player)
	await wait_work(90.0)


## A place near `from` with young trees about (WildlifeSpawner.cover at `least`), on ground a trap can stand on.
func wooded(from: Vector3, least: float) -> Vector3:
	var best := Vector3.INF
	var best_c := -1.0
	for r in [8.0, 16.0, 24.0, 32.0, 48.0, 64.0]:
		for a in 16:
			var q: Vector3 = from + Vector3(cos(a * TAU / 16.0), 0.0, sin(a * TAU / 16.0)) * float(r)
			var c := TrapStation.cover_at(self, q)
			if c >= least and c > best_c and not TrapStation.water_near(q, 2.0):
				best = q
				best_c = c
		if best != Vector3.INF:
			return best
	return best


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
	check(SurvivalInventory.count(b.core, "item.tool.knife") >= 1.0 and SurvivalInventory.count(b.core, "item.tool.hatchet") >= 1.0,
			"the kit has the knife and the hatchet")
	await _steel()
	await _snare()
	await _deadfall()
	await _take_up()
	_after()
	await _save_load()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("TRAPS TEST OK (%d checks)" % checks)
	else:
		print("TRAPS TEST FAILED %d/%d: %s" % [fails.size(), checks, str(fails)])
	quit(0 if fails.is_empty() else 1)


func _steel() -> void:
	var p := await place("trap_steel", spot)
	var ts := trap_of(p)
	check(ts != null and ts.state() == "", "a steel trap placed: the piece has its trap, not yet set")
	if ts == null:
		return
	set_count("steel_trap", 2)
	await stand(ts.global_position + Vector3(0, 0, 1.0))
	var pr := ts.interact_prompt(player)
	check(pr.begins_with("Set the steel trap ("), "E: '%s'" % pr)
	check(await set_it(ts), "set: %s" % ts.last.get("text", "-"))
	var r := ts.record()
	var pos: Array = r.get("pos", [])
	check(count("steel_trap") == 1 and String(r.get("type", "")) == "steel_land" and pos.size() == 3
			and int(r.get("cell", -1)) == TrapStation.cell_at(ts.global_position) and String(r.get("site", "")) != "",
			"the pack's steel trap in it; the record: %s, cell %d, a %s site, its place kept" % [r.get("type"), int(r.get("cell", -1)), r.get("site")])
	check(ts.interact_prompt(player) == "Check the steel trap", "set: '%s'" % ts.interact_prompt(player))
	catch(ts, "marten")
	var sprung := ts.get_node_or_null("Sprung") as MeshInstance3D
	var body_hidden := true
	for v: Variant in ts.piece().highlight_targets():
		if v is GeometryInstance3D and (v as GeometryInstance3D).visible:
			body_hidden = false
	check(sprung != null and sprung.visible and body_hidden and ts.get_node_or_null("Catch") != null,
			"a marten in it: the jaws shut, the catch in them")
	check(ts.interact_prompt(player) == "Take the marten from the steel trap", "E: '%s'" % ts.interact_prompt(player))
	var pelts0 := count("marten_pelt")
	var meat0 := count("small_game")
	await take(ts)
	check(count("marten_pelt") == pelts0 + 1 and count("small_game") == meat0 + 1 and ts.last.get("what") == "catch",
			"taken: '%s' (pelts %d, small game %d)" % [ts.last.get("text", "-"), count("marten_pelt"), count("small_game")])
	var st := ts.state()
	check(st == "set" or st == "sprung", "after: %s" % st)
	await frames(40)
	check(ts.get_node_or_null("Catch") == null, "the catch gone from the trap")
	# sprung empty: set again
	ts.record()["state"] = "sprung"
	var ok := false
	for i in 4:
		await stand(ts.global_position + Vector3(0, 0, 1.0))
		check(ts.interact_prompt(player).begins_with("Set the steel trap again") if i == 0 else true, "sprung: '%s'" % ts.interact_prompt(player))
		ts.interact(player)
		await wait_work()
		if ts.state() == "set":
			ok = true
			break
	check(ok, "sprung empty: set again (%s)" % ts.last.get("text", "-"))
	# a load: the piece finds its record by its place
	var tid := ts.trap_id
	ts.trap_id = ""
	ts._relink()
	check(ts.trap_id == tid and tid != "", "after a load: the piece finds its record (%s)" % tid)


func _snare() -> void:
	set_count("cordage", 3)
	var open_at := Vector3.INF
	for r in [6.0, 12.0, 20.0, 30.0, 45.0, 60.0]:
		for a in 16:
			var q: Vector3 = spot + Vector3(cos(a * TAU / 16.0), 0.0, sin(a * TAU / 16.0)) * float(r)
			if open_at == Vector3.INF and TrapStation.cover_at(self, q) < TrapStation.SAPLINGS - 0.05 and not TrapStation.water_near(q, 2.0):
				open_at = q
	check(open_at != Vector3.INF, "an open place (cover %.2f)" % (TrapStation.cover_at(self, open_at) if open_at != Vector3.INF else -1.0))
	if open_at != Vector3.INF:
		var po := await place("trap_snare", open_at)
		var to := trap_of(po)
		await stand(open_at + Vector3(0, 0, 1.0))
		check(to != null and not to.set_trap(player) and count("cordage") == 3, "a snare in the open: no young trees to bend")
		if po:
			BuildWorld.of(self, false).remove_piece(po)
	var at := wooded(spot, 0.35)
	check(at != Vector3.INF, "a wooded place for the snare (cover %.2f)" % (TrapStation.cover_at(self, at) if at != Vector3.INF else -1.0))
	if at == Vector3.INF:
		return
	var p := await place("trap_snare", at)
	var ts := trap_of(p)
	check(ts != null, "a snare placed among young trees")
	if ts == null:
		return
	check(await set_it(ts), "set with cordage: %s" % ts.last.get("text", "-"))
	check(count("cordage") == 2, "a cordage in it (%d left)" % count("cordage"))
	catch(ts, "small")
	var c := ts.get_node_or_null("Catch") as Node3D
	check(c != null and c.position.y > 0.8, "a hare hung from the sprung pole (%.2f m up)" % (c.position.y if c else -1.0))
	var meat0 := count("small_game")
	await take(ts)
	check(count("small_game") == meat0 + 1 and ts.last.get("got", {}).size() == 1, "the hare: '%s'" % ts.last.get("text", "-"))


func _deadfall() -> void:
	set_count("stake_set", 1)
	var p := await place("trap_deadfall", spot + Vector3(-7.0, 0.0, -6.0))
	var ts := trap_of(p)
	check(ts != null, "a deadfall placed")
	if ts == null:
		return
	check(await set_it(ts), "set with the stakes and the hatchet: %s" % ts.last.get("text", "-"))
	check(count("stake_set") == 0, "the stakes in it")
	catch(ts, "raccoon")
	var pelts0 := count("raccoon_pelt")
	var meat0 := count("small_game")
	await take(ts)
	check(count("raccoon_pelt") == pelts0 + 1 and count("small_game") == meat0 + 2, "the raccoon: '%s'" % ts.last.get("text", "-"))


func _take_up() -> void:
	var ts: TrapStation = null
	for n in get_nodes_in_group(&"trap_line"):
		if n is TrapStation and (n as TrapStation).kind == "trap_steel":
			ts = n
	if ts == null:
		check(false, "the steel trap is on the line")
		return
	var tid := ts.trap_id
	var n0 := count("steel_trap")
	var acts := ts.interact_actions(player)
	check(acts.size() == 2 and String(acts[1].id) == "take_up", "hold E: %s" % str(acts.map(func(x: Dictionary) -> String: return String(x.text))))
	ts.interact_action(player, "take_up")
	await frames(4)
	check(count("steel_trap") == n0 + 1 and SurvivalTrapLine.trap(b.core, tid).is_empty() and not is_instance_valid(ts) or not ts.is_inside_tree(),
			"taken up: the steel trap back (%d), the record gone, the piece down" % count("steel_trap"))
	# build mode's take-down: the same
	var p := await place("trap_steel", spot + Vector3(4.0, 0.0, 6.0))
	var t2 := trap_of(p)
	if t2 == null or not await set_it(t2):
		check(false, "a second steel trap set")
		return
	var tid2 := t2.trap_id
	var n1 := count("steel_trap")
	BuildWorld.of(self, false).remove_piece(p)
	await frames(4)
	check(count("steel_trap") == n1 + 1 and SurvivalTrapLine.trap(b.core, tid2).is_empty(), "taken down in build mode: the trap back, the record gone")


func _after() -> void:
	check(CampStation.PELTS.has("marten_pelt") and CampStation.PELTS.has("raccoon_pelt") and CampStation.PELTS.has("mink_pelt")
			and CampStation.PELTS.has("fisher_pelt"), "the stretching hoop takes the new pelts")
	var inv := InventoryState.from_player(player)
	for k in CampCooking.RAW:
		if k != "small_game":
			inv.take(k, inv.pack_count(k))
	player.inventory_pack = inv.pack.duplicate(true)
	check(b.cook != null and b.cook.raw_kind(player) == "small_game", "small game goes on the fire")
	var icons := ItemIcons.shared(self)
	for k in ["marten_pelt", "dried_raccoon_pelt", "small_game", "roast_small_game"]:
		var m := icons._model(k)
		check(m != null, "an icon model for %s" % k)
		if m:
			m.free()


func _save_load() -> void:
	var sg := SaveGame.find(self)
	if sg == null:
		print("  (no save=on: the save and load not tried)")
		return
	set_count("steel_trap", 1)
	var p := await place("trap_steel", spot + Vector3(8.0, 0.0, -4.0))
	var ts := trap_of(p)
	if ts == null or not await set_it(ts):
		check(false, "a steel trap set to save")
		return
	catch(ts, "fox")
	var at := ts.global_position
	check(sg.save_game("quick") == OK, "saved with a fox in the trap")
	check(sg.load_slot("quick"), "the load starts")
	var sg2: SaveGame = null
	for i in 60 * 12:
		await process_frame
		sg2 = SaveGame.find(self)
		if sg2 != null and sg2 != sg and not sg2.loading and sg2.level != null and sg2.level.is_inside_tree():
			break
	await frames(20)
	b = SurvivalBridge.find(self)
	var t2: TrapStation = null
	for n in get_nodes_in_group(&"trap_line"):
		if n is TrapStation and (n as TrapStation).global_position.distance_to(at) < 0.3:
			t2 = n
	check(t2 != null, "after the load the steel trap stands where it was")
	if t2 == null:
		return
	t2.refresh_look()
	check(t2.trap_id != "" and t2.state() == "holding" and t2.catch_species() == "fox" and t2.get_node_or_null("Catch") != null,
			"its record found again: %s, %s, the fox in it" % [t2.trap_id, t2.state()])
