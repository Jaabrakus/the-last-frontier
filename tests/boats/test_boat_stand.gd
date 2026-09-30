extends SceneTree
## The boat stand in the level (BoatStand, BoatBuild, HullMesh, Boat; user 2026-09-29: "a boat stand by the river, they bring materials
## to it and attach to it and see it grow into something real"), survival on:
##   Godot --headless --fixed-fps 60 --path . -s tests/boats/test_boat_stand.gd -- survival=on
##   place    a boat stand is a building piece: it needs the water near, and its costs are in the menu
##   parts    the stages want their parts; they come out of the kit and go to the stand
##   know     a technique the builder does not know cannot be done; taught, it can
##   grow     the hull's parts grow as the stages are done; the bed comes away when the boat is finished
##   launch   the finished canoe goes onto the water with the grades' numbers, and it floats there
## Ends with "BOAT STAND TEST PASSED (<n> checks)" or "BOAT STAND TEST FAILED (<f> of <n>)".
var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	for i in 20:
		await process_frame
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(b != null and player != null, "the level has the bridge and the player")
	if b == null:
		_end()
		return
	player.ignore_mouse_capture = true
	var z0 := -120.0
	var bank := Vector3(WorldRiver.x_at(z0) - 9.0, 0.0, z0)
	bank.y = FrontierTerrain.height_at(bank.x, bank.z)
	# the piece
	var d := BuildData.get_default()
	_expect(d.has("boat_stand") and d.name_of("boat_stand") == "Boat stand" and d.group_of("boat_stand") == "Crafting" and d.free_standing("boat_stand"), "the boat stand is a free-standing building piece (%s)" % str(d.cost("boat_stand")))
	_expect(BuildSnap._water_near(bank), "the water is near the bank spot")
	_expect(not BuildSnap._water_near(Vector3(0.0, 0.0, 0.0)), "and not at the fort")
	var holder := Node3D.new()
	current_scene.add_child(holder)
	holder.global_position = bank
	var stand := BoatStand.attach(holder)
	stand.instant_work = true
	await process_frame
	_expect(stand.build != null and stand.build.stages().size() == 5, "the stand has the canoe's five stages")
	var core := b.core
	# no parts, no knowledge
	var msg := stand.pick("bed")
	_expect(msg.contains("not all here") or msg.contains("Not"), "no parts brought: it says what is missing (%s)" % msg)
	for id in ["item.material.canoe_stake"]:
		SurvivalInventory.add(core, id, 14.0)
	msg = stand.pick("bed")
	_expect(int(stand.build.store.get("item.material.canoe_stake", 0)) == 14 and SurvivalInventory.count(core, "item.material.canoe_stake") < 0.5, "the stakes come out of the kit and go to the stand (%s)" % msg)
	var st0 := SurvivalLearning.state_of(core, "know.canoe_bed")
	msg = stand.pick("bed")
	if st0 == "unknown":
		_expect(msg.contains("do not know"), "not knowing how: it cannot be done (%s)" % msg)
		SurvivalLearning.set_state(core, "know.canoe_bed", "known", "taught", "the old hunter")
	else:
		_expect(true, "the builder knows the bed (%s)" % st0)
	SurvivalInventory.add(core, "item.tool.hatchet", 1.0)
	msg = stand.pick("bed")
	_expect(stand.build.done.has("bed"), "taught, with a hatchet, the bed is laid (%s)" % msg)
	_expect(float(stand.hull.frac["stakes"]) > 0.99, "the stakes stand on the ground")
	# the skin: out of order for the wrong pick, then in order
	for id in ["know.bark_sewing", "know.canoe_gunwales", "know.pitching_seams"]:
		SurvivalLearning.set_state(core, id, "known", "taught", "the old hunter")
	SurvivalInventory.add(core, "item.tool.awl", 1.0)
	SurvivalInventory.add(core, "item.material.birch_bark_sheet", 3.0)
	SurvivalInventory.add(core, "item.material.spruce_root", 14.0)
	stand.pick("skin")
	stand.pick("skin")
	_expect(stand.build.waiting or stand.build.done.has("skin"), "the skin's work is done: it waits for the fitting")
	msg = stand.pick("skin")
	_expect(stand.build.done.has("skin") and float(stand.hull.frac["skin"]) > 0.99, "fitted: the skin is on (%s)" % msg)
	SurvivalInventory.add(core, "item.material.cedar_strip", 4.0)
	stand.pick("gunwales")
	stand.pick("gunwales")
	_expect(stand.build.done.has("gunwales") and float(stand.hull.frac["gunwales"]) > 0.99, "the gunwales are on")
	SurvivalInventory.add(core, "item.material.cedar_rib", 18.0)
	stand.pick("ribs")
	stand.pick("ribs")
	_expect(stand.build.done.has("ribs") and float(stand.hull.frac["ribs"]) > 0.99, "the ribs are set")
	SurvivalInventory.add(core, "item.material.spruce_pitch", 3.0)
	stand.pick("seams")
	stand.pick("seams")
	stand.pick("seams")
	_expect(stand.build.is_complete(), "the seams are pitched: the canoe is built")
	_expect(float(stand.hull.frac["stakes"]) < 0.01 and float(stand.hull.frac["pitch"]) > 0.99, "the bed comes away and the pitch shows")
	var st := stand.build.stats()
	_expect(float(st.quality) > 0.4, "it has a grade (%.2f, %s)" % [float(st.quality), st.word])
	var rows := stand.rows()
	_expect(rows.size() == 5 and String(rows[0].text).begins_with("Done"), "the list shows the stages done")
	# launch
	var boat := stand.launch()
	_expect(boat != null, "the finished canoe is launched")
	if boat != null:
		var s := WaterSurface.surface_at(boat.position.x, boat.position.z)
		_expect(s != WaterSurface.NO_WATER and WaterSurface.depth_at(boat.position.x, boat.position.z) >= 0.5, "onto deep enough water (%.1f m from the stand)" % boat.position.distance_to(bank))
		_expect(boat.id == "birchbark" and not boat.grade.is_empty() and is_equal_approx(float(boat.grade.speed_mult), float(st.speed_mult)), "with the grades' numbers (speed x%.2f)" % float(boat.grade.speed_mult))
		for i in 30:
			await process_frame
		var w := WaterSurface.surface_at(boat.position.x, boat.position.z)
		_expect(w != WaterSurface.NO_WATER and boat.position.y < w and boat.position.y > w - 0.5, "and floats there (y %.2f, water %.2f)" % [boat.position.y, w])
	_expect(stand.build.next_id() == "bed" and stand.build.done.is_empty(), "the stand is bare for the next boat")
	_end()


func _end() -> void:
	if fails.is_empty():
		print("BOAT STAND TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("BOAT STAND TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
