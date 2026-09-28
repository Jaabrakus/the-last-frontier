extends SceneTree
## Beds, racks and crafting stations in build mode (user 2026-09-27: "add in beds and other craftables in the build
## option like useful things like spear barrels, musket racks, leather and tanning stations ... Alchemy"), on the level
## with the real player and the survival bridge, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_camp_stations.gd -- survival=on survival_seed=7
##
##   menu      the build menu in groups (Cabin, Camp, Furniture, Crafting, Traps, Fort); every cost shows (poles,
##             branches, a deer hide), and a piece is dimmed only for what it really lacks
##   racks     a musket rack (6) and a spear barrel (5) take weapons in their slots; taken down, the weapons lie on
##             the ground
##   beds      in a bough bed or a pole bed the core has its bedding (warmer, a better sleep); under a built roof, a
##             cabin's shelter; E sleeps in the bed; the waking line says where
##   jerky     the drying rack over a lit campfire: venison hung (10 lb a batch), a day or two on the rack, taken down
##             as jerky
##   tanning   the tanning frame: a deer hide and brains, by a lit fire, dressed into buckskin (or rawhide when it goes
##             hard); a hide scraped into rawhide; brains come from butchering a deer; a buffalo robe dressed with the
##             hair on into the rules' fur robe, worn (its warmth on), a bed by night when taken off
##   alchemy   the alchemy table: plantain salve, wintergreen tea (by a fire), ginseng tonic; each used from the pack
##             (heals, warms, well rested); stopping the work gives the herbs back
##   the menu  StationMenu pauses the game and gives the row picked
## Ends with "CAMP STATIONS TEST OK (<n> checks)" or "CAMP STATIONS TEST FAILED <failures>/<n>".

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


## The campfire fed and lit (game days pass in these tests: it burns down), the player back at `back_to`.
func stoke(back_to: Vector3) -> void:
	var cf: BuiltPiece = built.get("campfire")
	if cf == null:
		return
	var fire := cf.get_node("Campfire") as Campfire
	await stand(fire.global_position + Vector3(1.3, 0, 0))
	set_count("firewood", 6)
	while fire.wood_left() < Campfire.MAX_WOOD and count("firewood") > 0:
		fire.add_wood(player)
	fire.state.wet = 0.0
	if not fire.is_lit():
		fire.light()
	await settle(2)
	await stand(back_to)


func station(key: String) -> CampStation:
	var p: BuiltPiece = built.get(key)
	return p.get_node_or_null("Station") as CampStation if p else null


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
	check(b != null and player != null and b.work != null, "the level has the bridge and its work runner (survival=on)")
	if b == null:
		_end()
		return
	player.ignore_mouse_capture = true
	mode = player.get_node_or_null("BuildMode") as BuildMode
	SurvivalWeather.set_external(b.core, "clear", 2.0, 250.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	_test_menu()
	await _test_build()
	await _test_racks()
	await _test_beds()
	await _test_jerky()
	await _test_tanning()
	await _test_alchemy()
	await _test_station_menu()
	_end()


func _test_menu() -> void:
	var d := BuildData.get_default()
	var heads: Array = []
	for l: Array in BuildHud.menu_lines(d):
		if int(l[1]) < 0:
			heads.append(String(l[0]))
	check(heads == ["Cabin", "Camp", "Furniture", "Crafting", "Traps", "Fort"], "the build menu in groups: %s" % str(heads))
	for k in ["bough_bed", "pole_bed", "drying_rack", "musket_rack", "spear_barrel", "tanning_frame", "alchemy_table"]:
		check(d.has(k) and d.order.has(k), "%s is a build piece (%s: %s)" % [k, d.group_of(k), BuildData.cost_text(d.cost(k))])
	check(BuildData.cost_text(d.cost("lean_to")) == "5 poles, 10 branches" and BuildData.cost_text(d.cost("campfire")) == "6 stone, 4 firewood",
			"every cost shows: '%s', '%s'" % [BuildData.cost_text(d.cost("lean_to")), BuildData.cost_text(d.cost("campfire"))])
	check(BuildData.cost_text(d.cost("pole_bed")).contains("1 deer hide"), "the pole bed wants a deer hide: '%s'" % BuildData.cost_text(d.cost("pole_bed")))


func _test_build() -> void:
	for k in [["stone", 12], ["firewood", 12], ["pole", 40], ["branches", 40], ["log", 8], ["deer_hide", 3]]:
		set_count(k[0], k[1])
	var plan := [["campfire", Vector3(0, 0, 0)], ["drying_rack", Vector3(0, 0, 0)], ["tanning_frame", Vector3(4.0, 0, -0.5)],
			["alchemy_table", Vector3(-3.2, 0, 0)], ["bough_bed", Vector3(-1.5, 0, 6.0)], ["pole_bed", Vector3(1.5, 0, 6.0)],
			["musket_rack", Vector3(6.5, 0, 5.0)], ["spear_barrel", Vector3(8.6, 0, 5.0)]]
	for e in plan:
		var at: Vector3 = spot + (e[1] as Vector3)
		at.y = FrontierTerrain.height_at(at.x, at.z)
		var p := await place(String(e[0]), at)
		built[String(e[0])] = p
		check(p != null and p.type == String(e[0]), "built: %s" % e[0])
	check(count("deer_hide") == 2, "the pole bed took a deer hide (%d left)" % count("deer_hide"))
	var cf: BuiltPiece = built.get("campfire")
	if cf:
		(cf.get_node("Campfire") as Campfire).light()
	var dr: BuiltPiece = built.get("drying_rack")
	check(dr != null and dr.global_position.distance_to((built.get("campfire") as Node3D).global_position) < 0.5 if dr else false,
			"the drying rack stands over the campfire")


func _test_racks() -> void:
	var mr: BuiltPiece = built.get("musket_rack")
	var sb: BuiltPiece = built.get("spear_barrel")
	if mr == null or sb == null:
		return
	var rack := mr.get_node_or_null("Rack") as WeaponRack
	var barrel := sb.get_node_or_null("Rack") as WeaponRack
	check(rack != null and rack.bare and rack.slots == 6 and rack.style == "rack" and rack.is_in_group(WeaponRack.GROUP), "the musket rack holds 6")
	check(barrel != null and barrel.slots == 5 and barrel.style == "barrel", "the spear barrel holds 5")
	var w: Weapon = player.weapons.get("musket")
	var pw := PlacedWeapon.from_weapon(w, "musket")
	pw.state = WeaponState.capture(w)
	current_scene.add_child(pw)
	rack.place(pw, 2)
	check(rack.held().size() == 1 and pw.rack == rack, "a musket stands in it")
	# a ray from the front finds the rack (the interactor stands weapons in it that way)
	var from := rack.global_transform * Vector3(0, 0.7, 1.5)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, rack.global_transform * Vector3(0, 0.7, -0.5)))
	check(not hit.is_empty() and (hit.collider == rack or hit.collider == pw or (hit.collider as Node).get_parent() == rack), "the rack is there to aim at")
	var y0 := mr.global_position.y
	check(mode.take_down(mr), "the rack comes down")
	await frames(3)
	check(is_instance_valid(pw) and pw.rack == null and pw.global_position.y < y0 + 0.3, "the musket lies on the ground")
	if is_instance_valid(pw):
		pw.queue_free()


func _test_beds() -> void:
	var bb := station("bough_bed")
	var pb := station("pole_bed")
	if bb == null or pb == null:
		return
	await stand(spot + Vector3(-1.5, 0, 12.0))
	check(str(b.camp.told.get("bedding", "x")) == "", "off the beds: no bedding")
	var q0 := b.rest_quality()
	await stand(bb.global_position)
	check(str(b.core.state.context.get("bedding", "")) == "bough_bed", "in the bough bed: the core's bough bed")
	var q_bough := b.rest_quality()
	player.global_position = pb.global_transform * Vector3(0, BuildGeometry.POLE_BED_H + 0.02, 0.2)
	await frames(4)
	b.camp.refresh()
	check(str(b.core.state.context.get("bedding", "")) == "pole_bed", "in the pole bed: its bedding")
	var q_pole := b.rest_quality()
	b.core.set_activity("rest")
	var e := SurvivalNeeds.env(b.core)
	check(float(e.bedding_c) == 3.0, "resting in the pole bed: +%.0f C" % float(e.bedding_c))
	check(q0 < q_bough and q_bough < q_pole, "sleep: the ground %.2f < a bough bed %.2f < a pole bed %.2f" % [q0, q_bough, q_pole])
	# a roof over the bed, no walls: an open shelter, out of the rain (a roof bay put up over it directly)
	var roof: BuiltPiece = BuildWorld.of(self).add_piece("roof", Transform3D(pb.global_basis, pb.global_position + Vector3.UP * (BuildGeometry.WALL_H + 0.02)), false, -1)
	await frames(4)
	b.camp.refresh()
	var sid := str(b.core.state.context.get("shelter_id", ""))
	var sh: Dictionary = SurvivalCamp.shelters(b.core).get(sid, {})
	check(bool(b.core.state.context.get("in_shelter", false)) and str(sh.get("type", "")) == CampLink.ROOF_KIND and float(sh.get("quality", 0.0)) == CampLink.ROOF_Q,
			"under a roof on open sides: an open shelter (%s)" % str(sh))
	check(not bool(b.core.state.context.get("indoors", true)), "not indoors (no walls)")
	var q_cabin := b.rest_quality()
	check(q_cabin >= 1.0 and q_cabin > q_pole, "a pole bed under a roof: a full night's rest (%.2f)" % q_cabin)
	# E: sleep in it
	b.core.state.flags.erase("well_rested_until")
	await stand(spot + Vector3(1.5, 0, 9.0))
	check(pb.interact_prompt(player) == "Sleep in the pole bed", "E at the pole bed: '%s'" % pb.interact_prompt(player))
	pb.interact(player)
	await frames(4)
	check(b.sleeper.sleeping, "E: asleep in the bed")
	var t0 := Time.get_ticks_msec()
	while b.sleeper.sleeping and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	check(b.sleeper.where.begins_with("in the pole bed under your roof"), "the waking line: '%s' (quality %.2f, %.1f h well rested)" % [b.sleeper.where, b.sleeper.quality, b.sleeper.earned_h])
	mode.take_down(roof)
	await frames(30)


func _test_jerky() -> void:
	var st := station("drying_rack")
	var cf: BuiltPiece = built.get("campfire")
	if st == null or cf == null:
		return
	var fire := cf.get_node("Campfire") as Campfire
	await stand(st.global_position + Vector3(0, 0, 1.6))
	set_count("venison", 3)
	# the night's sleep burnt the fire down: wood on, lit again
	await stand(fire.global_position + Vector3(1.3, 0, 0))
	set_count("firewood", 6)
	while fire.wood_left() < Campfire.MAX_WOOD and count("firewood") > 0:
		fire.add_wood(player)
	fire.state.wet = 0.0
	if not fire.is_lit():
		fire.light()
	await stand(st.global_position + Vector3(0, 0, 1.6))
	await settle(2)
	b.camp.refresh()
	check(st.interact_prompt(player).begins_with("Hang venison to dry (2 venison)"), "E at the rack: '%s'" % st.interact_prompt(player))
	var raw0 := SurvivalInventory.count(b.core, "item.food.venison_raw")
	st.interact(player)
	await frames(4)
	check(b.work.working and player.kneeling == b.work, "hanging the strips over the fire")
	await wait_work()
	check(st.hanging_lb() >= 1.9 and count("venison") == 1, "on the rack: %.1f lb of jerky drying; two venison used (%d left) (%s)" % [st.hanging_lb(), count("venison"), st.last.get("text", "")])
	check(absf(SurvivalInventory.count(b.core, "item.food.venison_raw") - raw0 - 4.0) < 0.01, "the 4 lb over the batch stay with the kit")
	check(st.interact_prompt(player).contains("Drying:"), "the prompt tells the drying: '%s'" % st.interact_prompt(player))
	b.core.advance(2.2 * SurvivalClock.MIN_PER_DAY)
	await settle(3)
	var rd := st.ready_units()
	check(rd >= 1 and st.interact_prompt(player).begins_with("Take down"), "two days on: '%s'" % st.interact_prompt(player))
	var j0 := count("jerky")
	st.interact(player)
	check(count("jerky") == j0 + rd and st.hanging_lb() < 1.0, "E takes down %d jerky" % rd)


func _test_tanning() -> void:
	var st := station("tanning_frame")
	if st == null:
		return
	await stoke(st.global_position + Vector3(0, 0, 1.4))
	set_count("deer_hide", 2)
	set_count("brains", 1)
	var rows := st.menu_rows(player)
	check(rows.size() == 3 and bool(rows[0].ok) and bool(rows[1].ok) and not bool(rows[2].ok) and String(rows[2].detail).contains("buffalo robe"),
			"the frame's menu: %s" % str(rows.map(func(r): return "%s (%s)" % [r.text, r.ok])))
	check(st.make(player, "rcp.dress_hide") and b.work.working, "dressing a hide with brains, by the fire")
	check(count("deer_hide") == 1 and count("brains") == 0, "the hide and the brains on the frame")
	await wait_work()
	var got: Dictionary = st.last.get("got", {})
	check(got.has("buckskin") or got.has("rawhide"), "the hide dressed: %s (%s)" % [str(got), st.last.get("text", "")])
	check(count("buckskin") + count("rawhide") >= 1, "in the pack")
	var raw0 := count("rawhide")
	check(st.make(player, "rcp.rawhide"), "then a hide scraped into rawhide")
	await wait_work()
	check(count("rawhide") > raw0 and count("deer_hide") == 0, "rawhide: +%d (%s)" % [count("rawhide") - raw0, st.last.get("text", "")])
	set_count("brains", 0)
	set_count("cornmeal", 0)
	set_count("deer_hide", 1)
	check(not bool(st.menu_rows(player)[0].ok) and String(st.menu_rows(player)[0].detail).contains("brains or cornmeal"), "no brains, no cornmeal: it says so")
	# butchering a deer gives its brains
	check(int((WildlifeSpecies.DATA.deer.butcher as Dictionary).get("brains", 0)) == 1, "a deer's butchering gives its brains")
	# a buffalo robe dressed with the hair on: the rules' fur robe, put on (no fire needed: a robe is not smoked)
	var robe := CampStation.FUR_ROBE
	set_count("bison_robe", 1)
	set_count("brains", 1)
	var rr: Dictionary = st.menu_rows(player)[2]
	check(String(rr.id) == "rcp.dress_robe" and bool(rr.ok), "the robe row: '%s' (%s)" % [rr.text, rr.detail])
	var ins0 := float(SurvivalNeeds.env(b.core).ins_eff)
	for i in 5:
		set_count("bison_robe", 1)
		set_count("brains", 1)
		if not st.make(player, "rcp.dress_robe"):
			check(false, "the robe dressing starts")
			break
		check(count("bison_robe") == 0 or i > 0, "the robe and the brains on the frame")
		await wait_work()
		if SurvivalInventory.count(b.core, robe) >= 1.0:
			break
		print("    (try %d: %s)" % [i + 1, st.last.get("text", "")])
	check(SurvivalInventory.count(b.core, robe) >= 1.0 and b.core.state.worn.has(robe) and String(st.last.get("text", "")).ends_with("you wrap it round you"),
			"dressed and worn: '%s'" % st.last.get("text", ""))
	var ins1 := float(SurvivalNeeds.env(b.core).ins_eff)
	check(ins1 - ins0 >= 3.5, "the robe's warmth on: insulation %.1f -> %.1f" % [ins0, ins1])
	var bed0 := SurvivalCamp.bedding_insulation(b.core)
	SurvivalInventory.take_off(b.core, robe)
	check(SurvivalCamp.bedding_insulation(b.core) > bed0, "taken off, it is a bed by night: bedding %.1f -> %.1f" % [bed0, SurvivalCamp.bedding_insulation(b.core)])
	SurvivalInventory.wear(b.core, robe)


func _test_alchemy() -> void:
	var st := station("alchemy_table")
	if st == null:
		return
	await stoke(st.global_position + Vector3(0, 0, 1.2))
	set_count("plantain", 3)
	set_count("wintergreen", 2)
	set_count("ginseng", 1)
	var rows := st.menu_rows(player)
	# the first three from the herbs in hand; the three from the newer plants (willow, slippery elm, elderberry) listed,
	# wanting theirs
	check(rows.size() == Remedies.RECIPES.size() and rows.slice(0, 3).all(func(r): return bool(r.ok))
			and rows.slice(3).all(func(r): return not bool(r.ok)), "the table's menu: %s" % str(rows.map(func(r): return "%s (%s)" % [r.text, r.detail])))
	# stopped: the herbs come back
	check(st.make(player, "plantain_salve") and count("plantain") == 0, "grinding plantain")
	await frames(20)
	b.work.stop()
	await wait_work()
	check(count("plantain") == 3 and count("plantain_salve") == 0, "stopped: the plantain comes back")
	for id in ["plantain_salve", "wintergreen_tea", "ginseng_tonic"]:
		check(st.make(player, id), "making %s" % id)
		await wait_work()
		check(count(id) == 1, "%s in the pack" % InventoryState.name_of(id))
	check(count("plantain") == 0 and count("wintergreen") == 0 and count("ginseng") == 0, "the herbs used")
	# used from the pack
	var inv := InventoryState.from_player(player)
	player.health = 50.0
	var t1 := Remedies.use(player, "plantain_salve", inv)
	player.inventory_pack = inv.pack.duplicate(true)
	await frames(int(10.0 * Engine.physics_ticks_per_second))
	check(player.health > 60.0, "the salve heals: %.0f in 10 s (%s)" % [player.health, t1])
	await frames(int(21.0 * Engine.physics_ticks_per_second))
	b.core.state.needs["warmth"] = 40.0
	inv = InventoryState.from_player(player)
	var t2 := Remedies.use(player, "wintergreen_tea", inv)
	player.inventory_pack = inv.pack.duplicate(true)
	check(float(b.core.state.needs.warmth) >= 74.0, "the tea warms: %.0f (%s)" % [float(b.core.state.needs.warmth), t2])
	b.core.state.flags.erase("well_rested_until")
	# fed: hunger caps the boost (SurvivalBridge.REST_CAP_H)
	b.core.state.needs["stomach"] = 2600.0
	b.core.state.needs["reserve"] = 2500.0
	b.core.advance(1.0)
	inv = InventoryState.from_player(player)
	var t3 := Remedies.use(player, "ginseng_tonic", inv)
	player.inventory_pack = inv.pack.duplicate(true)
	check(b.is_well_rested() and absf(b.rested_hours_left() - 4.0) < 0.2, "the tonic: well rested %.1f h (%s)" % [b.rested_hours_left(), t3])
	# the tea wants a fire
	var cf: BuiltPiece = built.get("campfire")
	(cf.get_node("Campfire") as Campfire).smother()
	await settle(2)
	set_count("wintergreen", 2)
	check(not bool(st.menu_rows(player)[1].ok) and String(st.menu_rows(player)[1].detail).contains("campfire"), "no fire: no tea")


func _test_station_menu() -> void:
	var m := StationMenu.open(self, "Test", [{"text": "A", "detail": "a", "ok": true}, {"text": "B", "detail": "b", "ok": true}])
	await process_frame
	check(paused and m.buttons.size() == 2, "the menu pauses the game")
	m.buttons[1].pressed.emit()
	var i: int = await m.picked
	await process_frame
	check(i == 1 and not paused, "a row picked: %d, the game goes on" % i)


func _end() -> void:
	if fails.is_empty():
		print("CAMP STATIONS TEST OK (%d checks)" % checks)
	else:
		print("CAMP STATIONS TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
