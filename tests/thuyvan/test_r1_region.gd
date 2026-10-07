extends SceneTree
## R1 as the game streams it (WorldRegion "r1": data/world/maps/r1/region.json, the packed ground under
## assets/thuyvan/terrain/r1/, ThuyVanTerrain, ThuyVanWater, ThuyVanDressing, scenes/thuyvan_r1.tscn). Headless:
##
##   Godot --headless --path . -s tests/thuyvan/test_r1_region.gd
##
##   region    r1 reads region.json (its squares.json is the baker's); the block names the packed ground, its origin
##             [0, -416] and the day-cycle look; the grid is the layout's twelve cells
##   ground    FrontierTerrain on the region: its twelve squares centred on the layout's cells; heights at the vista's
##             landmarks equal T4's bake (V1's lip 212.7, the village 176.9, the Two Heights' north plateau 295.8, the
##             gorge's floor); in_world inside and not past the edge; the collision built for every square
##   river     WorldRiver on the main channel's nodes: x and level at the Silent Reach as the layout's nodes, water there
##             and none on the lip, its z range the C column; S1 stills the reach (flow 0) and nothing outside it
##   water     ThuyVanWater: a ribbon per channel, every pound, the torrent's falls and the two wall falls; S1's still band
##   dressing  ThuyVanDressing: the rope bridge, the needle, the Two Heights, gorge modules down the walls, the karst
##             ranks (far towers on tv_rock_far with their fog step), the white stones, plants in MultiMesh tiles
##   level     scenes/thuyvan_r1.tscn loads: the player on the east bridge head with no firearms; F9 stills the river
## Ends with "R1 REGION TEST PASSED (<n> checks)" or "R1 REGION TEST FAILED (<f> of <n>)".

const Region := preload("res://scripts/world/world_region.gd")
const TerrainScript := preload("res://scripts/thuyvan/world/thuyvan_terrain.gd")
const WaterScript := preload("res://scripts/thuyvan/world/thuyvan_water.gd")
const DressingScript := preload("res://scripts/thuyvan/world/thuyvan_dressing.gd")
const SCENE := "res://scenes/thuyvan_r1.tscn"

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	# a script error stops the test where it is: never hold the shared lock past this
	create_timer(600.0).timeout.connect(func() -> void:
		print("R1 REGION TEST FAILED (watchdog: stopped after 600 s)")
		quit(3))
	Region.set_region("r1")
	_region()
	_ground()
	_river()
	await _built()
	WorldRiver.reach_state = ""
	InputSetup.ensure()
	change_scene_to_file(SCENE)
	await process_frame
	await process_frame
	for i in 30:
		await physics_frame
	await _level()
	WorldRiver.reach_state = ""
	if fails.is_empty():
		print("R1 REGION TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("R1 REGION TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _region() -> void:
	var info := Region.info()
	_expect(Region.squares_path() == "res://data/world/maps/r1/region.json", "region: r1 reads region.json")
	_expect(String(info.get("terrain_dir", "")) == "res://assets/thuyvan/terrain/r1/" and String(info.get("look", "")) == "cycle"
			and str(info.get("terrain_origin", [])) == str([0.0, -416.0]), "region: the block names the packed ground, origin and look")
	_expect(WorldSquares.squares().size() == 12 and WorldSquares.type_id(Vector2i(1, -1)) == "gorge"
			and WorldSquares.type_id(Vector2i(0, -1)) == "terraced_slope", "region: the grid is the layout's (C1 gorge, B1 terraces)")


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _ground() -> void:
	_expect(FrontierTerrain.data_loaded() and FrontierTerrain.origin == Vector2(0.0, -416.0), "ground: the packed data loads, origin (0, -416)")
	_expect(FrontierTerrain.squares().size() == 12, "ground: twelve squares (%d)" % FrontierTerrain.squares().size())
	_expect(FrontierTerrain.square_origin(Vector2i(1, -1)) == Vector3(832.0, 0.0, -1248.0)
			and FrontierTerrain.square_origin(Vector2i(-1, 2)) == Vector3(-832.0, 0.0, 1248.0), "ground: squares sit on the layout's cell centres")
	var v1 := FrontierTerrain.height_at(938.0, -1250.0)
	var vil := FrontierTerrain.height_at(0.0, -1248.0)
	var th := FrontierTerrain.height_at(-832.0, -545.0)
	_expect(_near(v1, 212.67, 0.05) and _near(vil, 176.85, 0.05) and _near(th, 295.75, 0.05),
			"ground: heights are the bake's (V1 lip %.2f, village %.2f, Two Heights north %.2f)" % [v1, vil, th])
	var floor_h := FrontierTerrain.height_at(820.0, -1300.0)
	_expect(floor_h < 136.0 and floor_h > 125.0, "ground: the gorge's floor at the Silent Reach (%.1f)" % floor_h)
	_expect(FrontierTerrain.in_world(938.0, -1250.0) and FrontierTerrain.in_world(-1100.0, 1500.0)
			and not FrontierTerrain.in_world(2000.0, 0.0) and not FrontierTerrain.in_world(0.0, -1800.0), "ground: in_world inside, not past the edge")
	_expect(FrontierTerrain.normal_at(790.0, -1300.0).y < 0.75 and FrontierTerrain.normal_at(938.0, -1250.0).y > 0.85,
			"ground: the gorge wall is steep, the lip is not")


func _river() -> void:
	_expect(WorldRiver.has_water() and WorldRiver.z_range() == Vector2(-1664.0, 1664.0), "river: on the C column (%s)" % WorldRiver.z_range())
	_expect(_near(WorldRiver.x_at(-1300.0), 820.0, 0.5) and _near(WorldRiver.level_at(-1300.0), 135.0, 0.05)
			and _near(WorldRiver.level_at(-1664.0), 142.0, 0.05), "river: the layout's nodes (x %.1f, level %.2f at z -1300)" % [
			WorldRiver.x_at(-1300.0), WorldRiver.level_at(-1300.0)])
	_expect(_near(WorldRiver.surface_at(820.0, -1300.0), 135.0, 0.05) and WorldRiver.depth_at(Vector3(820.0, 0.0, -1300.0)) > 0.5
			and WorldRiver.surface_at(938.0, -1250.0) == WorldRiver.NO_WATER, "river: water in the gorge, none on the lip")
	_expect(WorldRiver.dir_at(-1300.0).z > 0.9, "river: runs south")
	WorldRiver.reach_state = "S1"
	_expect(WorldRiver.flow_scale(-1300.0) < 0.01 and _near(WorldRiver.flow_scale(-800.0), 1.0, 0.001)
			and not WorldRiver.still_band().is_empty(), "river: S1 stills the Silent Reach, nothing past it")
	WorldRiver.reach_state = "S0"
	_expect(_near(WorldRiver.flow_scale(-1300.0), 1.0, 0.001), "river: S0 runs")


func _count(n: Node, cls: String, prefix := "") -> int:
	var c := 0
	if n.is_class(cls) and (prefix == "" or String(n.name).begins_with(prefix)):
		c += 1
	for k in n.get_children():
		c += _count(k, cls, prefix)
	return c


func _built() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var t: FrontierTerrain = TerrainScript.new()
	holder.add_child(t)
	t.build(WorldSettings.preset("medium"))
	var body := t.get_node_or_null("TerrainBody")
	_expect(body != null and body.get_child_count() == 12 * FrontierTerrain.CHUNK_COUNT * FrontierTerrain.CHUNK_COUNT,
			"ground: collision for every square (%d chunks)" % (body.get_child_count() if body else 0))
	var w: Node3D = WaterScript.new()
	holder.add_child(w)
	w.call("build", "res://data/world/maps/r1/water.json")
	_expect(_count(w, "MeshInstance3D", "Water_") == 2 and _count(w, "MeshInstance3D", "Pound_") >= 15,
			"water: a ribbon per channel (%d), the pounds (%d)" % [_count(w, "MeshInstance3D", "Water_"), _count(w, "MeshInstance3D", "Pound_")])
	_expect(_count(w, "Node3D", "Fall_") == 5, "water: the torrent's three falls and F1, F2 (%d)" % _count(w, "Node3D", "Fall_"))
	WorldRiver.reach_state = "S1"
	w.call("set_still_band", WorldRiver.still_band())
	var sb: Vector4 = (w.get("river_mat") as ShaderMaterial).get_shader_parameter("still_band")
	_expect(sb.w > 0.99 and _near(sb.x, -1500.0, 0.1), "water: S1's still band on the main channel")
	WorldRiver.reach_state = ""
	var d: Node3D = DressingScript.new()
	holder.add_child(d)
	var t0 := Time.get_ticks_msec()
	d.call("build", WorldSettings.preset("medium"))
	print("  (dressing built in %.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_expect(_has_piece(d, "rope_bridge_r1"), "dressing: the rope bridge")
	_expect(_has_piece(d, "bridge_needle") and _has_piece(d, "two_heights_bridge") and _has_piece(d, "two_heights_head_n"),
			"dressing: the needle, the Two Heights and a head")
	var walls := _pieces(d, "cliff_")
	_expect(walls >= 20, "dressing: gorge modules down the walls (%d)" % walls)
	var far := _pieces(d, "karst_far_")
	_expect(far >= 40 and _pieces(d, "karst_hero_") >= 8, "dressing: the karst ranks (%d far, %d hero)" % [far, _pieces(d, "karst_hero_")])
	_expect(_count(d, "MultiMeshInstance3D", "WhiteStones_") == 12, "dressing: the white stones (12 kinds)")
	var plants := 0
	for c in d.get_children():
		if c is MultiMeshInstance3D and String(c.name).begins_with("Near_"):
			plants += (c as MultiMeshInstance3D).multimesh.instance_count
	_expect(plants > 5000, "dressing: plants in MultiMesh tiles (%d near instances)" % plants)
	d.call("set_look", ThuyVanLook.resolve("jade_mist_morning"))
	var mist := d.get_node_or_null("Mist")
	_expect(mist != null and mist.get_child_count() > 30, "dressing: the morning's mist bands (%d cards)" % (mist.get_child_count() if mist else 0))
	holder.queue_free()
	await process_frame


func _has_piece(n: Node, piece: String) -> bool:
	return _pieces(n, piece) > 0


func _pieces(n: Node, prefix: String) -> int:
	var c := 0
	for k in n.get_children():
		if String(k.name).contains(prefix):
			c += 1
	return c


func _level() -> void:
	var lvl := current_scene
	_expect(lvl != null and lvl.get_script() != null and String(lvl.get_script().resource_path).ends_with("thuyvan_r1_level.gd"),
			"level: scenes/thuyvan_r1.tscn loads")
	if lvl == null:
		return
	var p: Node3D = lvl.get("player")
	_expect(p != null and bool(p.get("no_firearms")), "level: the player, no firearms")
	if p:
		var at := p.global_position
		_expect(Vector2(at.x, at.z).distance_to(Vector2(912.0, -1236.0)) < 2.0 and absf(at.y - FrontierTerrain.height_at(at.x, at.z)) < 3.0,
				"level: the player on the east bridge head (%.0f, %.1f, %.0f)" % [at.x, at.y, at.z])
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F9
	ev.pressed = true
	lvl.call("_input", ev)
	_expect(String(lvl.get("state")) == "S1" and WorldRiver.flow_scale(-1300.0) < 0.01, "level: F9 stills the river")
