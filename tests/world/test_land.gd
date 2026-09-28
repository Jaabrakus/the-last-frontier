extends SceneTree
## The ground as squares (FrontierTerrain; user 2026-09-27: "add another square map thats open planes with a river to
## a lake", "should we do procedure land?", "lets do that"): the fort's square and the open land east of it, baked from
## one world recipe (tools/environment/terrain/bake_terrain.py --square), set side by side. Headless:
##
##   Godot --headless --path . -s tests/world/test_land.gd
##
##   squares    the ground there is: the fort's square and the open land's (1, 0)
##   fort kept  the fort map's heights are as they were before there were squares, but for its outer rim toward the open
##              land (the rim rising toward its east edge, gone now the open land lies there): its west half and all
##              inside the old rim (the bake's rim measure under 290 m) to the millimetre; its east rim lowered
##   seam       the two squares meet without a step: heights, normals and forest along their shared edge
##   world      on the ground there is: both squares; not past the walls
##   open land  few trees and tall grass on the open land; the fort's woods dense
##   river      the river cut through the open land, its bed under its banks, falling north to south
##   walls      the walls stand where the ground ends: none between the squares, one past the open land
##   collision  rays down meet the ground on both sides of the seam, at the height it is drawn at
##   walk       the player walks east out of the fort's square onto the open land, on the ground all the way
## Ends with "LAND TEST PASSED (<n> checks)" or "LAND TEST FAILED (<f> of <n>)".

const FIXTURE := "res://tests/world/fixtures/fort_heights_before_squares.json"

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_squares()
	_fort_kept()
	_seam()
	_world()
	_open_land()
	_river()
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await _fr(30)
	_walls()
	_collision()
	await _walk()
	if fails.is_empty():
		print("LAND TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("LAND TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _squares() -> void:
	var sq := FrontierTerrain.squares()
	_expect(sq == [Vector2i(0, 0), Vector2i(1, 0)], "squares: the ground there is: %s" % str(sq))


func _fort_kept() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var worst := 0.0
	var kept := 0
	var lowered := 0
	var rim := 0
	for p: Array in d.points:
		var x := float(p[0])
		var z := float(p[1])
		var e := pow(pow(absf(x), 6.0) + pow(absf(z), 6.0), 1.0 / 6.0)     # the old rim's measure (bake_terrain.py)
		var dh := FrontierTerrain.height_at(x, z) - float(p[2])
		if x <= 0.0 or e < 290.0:
			worst = maxf(worst, absf(dh))
			kept += 1
		else:
			rim += 1
			if dh < -0.01:
				lowered += 1
	_expect(worst < 1e-3 and lowered > 0, "fort kept: as before the squares at %d points (off by at most %.5f m); its east rim lowered toward the open land at %d of %d there" %
			[kept, worst, lowered, rim])


func _seam() -> void:
	var step := 0.0
	var tilt := 1.0
	var fd := 0.0
	var z := -400.0
	while z <= 400.0:
		var a := FrontierTerrain.height_at(415.999, z)
		var b := FrontierTerrain.height_at(416.001, z)
		step = maxf(step, absf(a - b))
		tilt = minf(tilt, FrontierTerrain.normal_at(415.9, z).dot(FrontierTerrain.normal_at(416.1, z)))
		fd = maxf(fd, absf(FrontierTerrain.forest_density(415.9, z) - FrontierTerrain.forest_density(416.1, z)))
		z += 8.0
	_expect(step < 0.02 and tilt > 0.99 and fd < 0.05,
			"seam: along the shared edge no step (%.4f m), normals alike (%.4f), forest alike (%.3f)" % [step, tilt, fd])


func _world() -> void:
	var ins := [FrontierTerrain.in_world(0, 0), FrontierTerrain.in_world(1000, 0), FrontierTerrain.in_world(416, 300)]
	var outs := [FrontierTerrain.in_world(1300, 0), FrontierTerrain.in_world(-450, 0), FrontierTerrain.in_world(500, -500),
			FrontierTerrain.in_world(0, 450)]
	_expect(ins == [true, true, true] and outs == [false, false, false, false],
			"world: on the ground in both squares and across their edge; not past the walls (%s, %s)" % [str(ins), str(outs)])


func _open_land() -> void:
	var fo := 0.0
	var fw := 0.0
	var gh := 0.0
	var n := 0
	for i in 20:
		for j in 20:
			var ox := -300.0 + i * 30.0
			var oz := -300.0 + j * 30.0
			fo += FrontierTerrain.forest_density(832.0 + ox, oz)
			fw += FrontierTerrain.forest_density(ox, oz)
			gh += FrontierTerrain.grass_height_at(832.0 + ox, oz)
			n += 1
	fo /= n
	fw /= n
	gh /= n
	_expect(fo < 0.2 and fw > 0.6 and gh > 0.35,
			"open land: few trees (forest %.2f against the fort's woods %.2f), tall grass (%.2f m)" % [fo, fw, gh])


## The bake's river (bake_terrain.py river_x): through the open land, north to south.
func _river_x(z: float) -> float:
	return 832.0 + 70.0 * sin(z / 140.0 + 0.4) + 25.0 * sin(z / 47.0 + 1.3)


func _river() -> void:
	var cut := INF
	for z in [-250.0, -100.0, 0.0, 150.0, 300.0]:
		var rx := _river_x(z)
		var bed := FrontierTerrain.height_at(rx, z)
		var banks := minf(FrontierTerrain.height_at(rx - 40.0, z), FrontierTerrain.height_at(rx + 40.0, z))
		cut = minf(cut, banks - bed)
	var north := FrontierTerrain.height_at(_river_x(-300.0), -300.0)
	var south := FrontierTerrain.height_at(_river_x(300.0), 300.0)
	_expect(cut >= 2.0 and north > south + 1.0, "river: its bed at least %.1f m under its banks; falling from %.1f m in the north to %.1f m in the south" %
			[cut, north, south])


func _walls() -> void:
	var edge := current_scene.find_child("WorldEdge", true, false) as StaticBody3D
	if edge == null:
		_expect(false, "walls: the level has its WorldEdge")
		return
	var xs := []
	for c in edge.get_children():
		var cs := c as CollisionShape3D
		if cs and (cs.shape as BoxShape3D).size.x < 3.0:
			xs.append(roundi(cs.position.x))
	xs.sort()
	_expect(xs == [-411, 1243], "walls: west of the fort and east of the open land, none between them (%s)" % str(xs))


func _collision() -> void:
	var space: PhysicsDirectSpaceState3D = (current_scene as Node3D).get_world_3d().direct_space_state
	var worst := 0.0
	var hits := 0
	for x in [410.0, 415.5, 416.5, 422.0, 800.0]:
		for z in [-200.0, 0.0, 200.0]:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 200.0, z), Vector3(x, -200.0, z))
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			hits += 1
			worst = maxf(worst, absf((hit.position as Vector3).y - FrontierTerrain.collision_height_at(x, z)))
	_expect(hits == 15 and worst < 0.05, "collision: rays down meet the ground both sides of the seam (%d of 15, within %.3f m of it)" % [hits, worst])


func _walk() -> void:
	var p := current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	var start := Vector3(396.0, 0.0, 12.0)
	start.y = FrontierTerrain.height_at(start.x, start.z) + 0.1
	p.global_position = start
	p.velocity = Vector3.ZERO
	p.yaw = -PI * 0.5                 # facing +X
	p.rotation.y = p.yaw
	await _fr(30)
	Input.action_press(&"move_forward")
	var lowest := INF
	var t := 0.0
	while t < 30.0 and p.global_position.x < 440.0:
		await physics_frame
		t += 1.0 / 120.0
		lowest = minf(lowest, p.global_position.y - FrontierTerrain.height_at(p.global_position.x, p.global_position.z))
	Input.action_release(&"move_forward")
	_expect(p.global_position.x >= 440.0 and lowest > -0.3, "walk: out of the fort's square onto the open land (to x %.1f in %.1f s), on the ground all the way (%.2f m at the lowest)" %
			[p.global_position.x, t, lowest])
