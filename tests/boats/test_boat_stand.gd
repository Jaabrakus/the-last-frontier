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
var stand: BoatStand


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
	stand = BoatStand.attach(holder)
	stand.instant_work = true
	await process_frame
	_expect(stand.build != null and stand.build.stages().size() == 5, "the stand has the canoe's five stages")
	var core := b.core
	var g := player.gather
	# ---- the raw materials, from the trees
	TreeHarvest.used.clear()
	g.target = {"type": "tree", "species": "birch", "i": 1001, "pos": bank, "point": bank, "name_disp": "birch"}
	var acts := TreeHarvest.actions(g)
	_expect(acts.size() == 1 and acts[0].id == "peel", "a birch offers its bark (%s)" % str(acts))
	g.target = {"type": "tree", "species": "hemlock", "i": 1002, "pos": bank, "point": bank, "name_disp": "hemlock"}
	acts = TreeHarvest.actions(g)
	_expect(acts.size() == 1 and acts[0].id == "roots", "a hemlock offers its roots")
	g.target = {"type": "tree", "species": "oak", "i": 1003, "pos": bank, "point": bank, "name_disp": "oak"}
	_expect(TreeHarvest.actions(g).is_empty(), "an oak offers nothing for a canoe")
	g.target = {"type": "tree", "species": "birch", "i": 1001, "pos": bank, "point": bank, "name_disp": "birch"}
	var told := TreeHarvest.begin("peel", g, true)
	if not TreeHarvest.has_any(player, g, ["item.tool.knife", "gather:felling_axe"]):
		_expect(told.contains("You need"), "no knife or axe: it will not peel (%s)" % told)
		SurvivalInventory.add(core, "item.tool.knife", 1.0)
		told = TreeHarvest.begin("peel", g, true)
	_expect(TreeHarvest.pack_count(player, "birch_bark_sheet") == 1, "a knife, and a birch gives a sheet of bark to the pack (%s)" % told)
	told = TreeHarvest.begin("peel", g, true)
	_expect(TreeHarvest.pack_count(player, "birch_bark_sheet") == 1 and told.contains("peeled"), "the same birch gives no more (%s)" % told)
	for i in [1011, 1012]:
		g.target = {"type": "tree", "species": "birch", "i": i, "pos": bank, "point": bank, "name_disp": "birch"}
		TreeHarvest.begin("peel", g, true)
	_expect(TreeHarvest.pack_count(player, "birch_bark_sheet") == 3, "three birches, three sheets")
	for i in [2001, 2002, 2003, 2004]:
		g.target = {"type": "tree", "species": "white_pine" if i % 2 == 0 else "hemlock", "i": i, "pos": bank, "point": bank, "name_disp": "pine"}
		for k in 3:
			TreeHarvest.begin("roots", g, true)
	_expect(TreeHarvest.pack_count(player, "wattap") == 24, "four trees' roots dug three times: %d bundles of wattap, and a tree runs out after three" % TreeHarvest.pack_count(player, "wattap"))
	# the parts from poles at the stand
	stand.instant_work = true
	TreeHarvest.pack_add(player, "pole", 10)
	told = stand.make_part("canoe_stake")
	_expect(TreeHarvest.pack_count(player, "canoe_stake") == 3 and TreeHarvest.pack_count(player, "pole") == 9, "a pole cut into three stakes (%s)" % told)
	for i in 4:
		stand.make_part("canoe_stake")
	for i in 2:
		stand.make_part("canoe_strip")
	for i in 3:
		stand.make_part("canoe_rib")
	_expect(TreeHarvest.pack_count(player, "canoe_stake") == 15 and TreeHarvest.pack_count(player, "canoe_strip") == 4 and TreeHarvest.pack_count(player, "canoe_rib") == 18, "stakes, strips and ribs from the poles (%d, %d, %d)" % [TreeHarvest.pack_count(player, "canoe_stake"), TreeHarvest.pack_count(player, "canoe_strip"), TreeHarvest.pack_count(player, "canoe_rib")])
	_expect(stand.make_rows().size() == 3 and stand.make_part("canoe_rib") != "", "the stand lists the parts it makes")
	TreeHarvest.pack_add(player, "pine_pitch", 3)   # foraged from the pines already
	# ---- the build
	var msg := stand.pick("bed")
	_expect(int(stand.build.store.get("canoe_stake", 0)) == 14 and TreeHarvest.pack_count(player, "canoe_stake") == 1, "the stakes come out of the pack and go to the stand (%s)" % msg)
	var st0 := SurvivalLearning.state_of(core, "know.canoe_bed")
	msg = stand.pick("bed")
	if st0 == "unknown":
		_expect(msg.contains("do not know"), "not knowing how: it cannot be done (%s)" % msg)
		SurvivalLearning.set_state(core, "know.canoe_bed", "known", "taught", "the old hunter")
	msg = _stage("bed")
	_expect(stand.build.done.has("bed"), "taught, with a knife or axe, the bed is laid (%s)" % msg)
	_expect(float(stand.hull.frac["stakes"]) > 0.99, "the stakes stand on the ground")
	for id in ["know.bark_sewing", "know.canoe_gunwales", "know.pitching_seams"]:
		SurvivalLearning.set_state(core, id, "known", "taught", "the old hunter")
	SurvivalInventory.add(core, "item.tool.awl", 1.0)
	stand.pick("skin")   # the parts brought
	stand.pick("skin")   # begun and worked
	_expect(stand.build.waiting, "the skin's work is done: it waits for the fitting")
	msg = stand.pick("skin")
	_expect(stand.build.done.has("skin") and float(stand.hull.frac["skin"]) > 0.99, "fitted: the skin is on (%s)" % msg)
	_stage("gunwales")
	_expect(stand.build.done.has("gunwales") and float(stand.hull.frac["gunwales"]) > 0.99, "the gunwales are on")
	_stage("ribs")
	_expect(stand.build.done.has("ribs") and float(stand.hull.frac["ribs"]) > 0.99, "the ribs are set")
	_stage("seams")
	_expect(stand.build.is_complete(), "the seams are pitched: the canoe is built from what the woods gave")
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


## Picks a stage until it is done: bring the parts, begin it, its work, its puzzle (played for the builder, headless).
func _stage(sid: String) -> String:
	var msg := ""
	for i in 5:
		msg = stand.pick(sid)
		if stand.build.done.has(sid):
			break
	return msg


func _end() -> void:
	if fails.is_empty():
		print("BOAT STAND TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("BOAT STAND TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
