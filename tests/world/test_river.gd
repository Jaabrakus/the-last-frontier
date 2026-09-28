extends SceneTree
## The river's water (WorldRiver, RiverWater; user 2026-09-27: the open land "with a river", "i know theres some
## realistic peformance based water tech right?"). Headless:
##
##   Godot --headless --path . -s tests/world/test_river.gd
##
##   line       the river's water sits in the bed the bake cut: over its centre about 1.2 m deep, none on its banks
##   flow       its level falls southward; the way it runs follows its bends
##   extent     water only where it has ground (the open land's length), none past it
##   water      the level has its River, in the water group: under its surface is under water (a torch put out),
##              the bank is not
##   wading     walking up the river the player is slowed by it, splashing; out on the bank, the cap let go
##   drinking   at the water's edge E offers a drink; the player kneels, drinks, gets up
##   mammoth    a mammoth at the bank facing the river drinks from it (its trunk in the water)
##   rapids     three rapids: white water in the middle of each (rapid_at 1) and none between; shallow there, the
##              surface dropping its drop along it; boulders breaking the water; wading there slower still
##   sound      the running water heard from the river's point nearest the player; a roar at each rapid
## Ends with "RIVER TEST PASSED (<n> checks)" or "RIVER TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var river: RiverWater


func _initialize() -> void:
	_line()
	_flow()
	_extent()
	_rapids()
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await _fr(30)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	river = current_scene.get_node_or_null("River") as RiverWater
	_water()
	if river:
		await _wading()
		await _drinking()
		await _mammoth()
		await _sound()
		await _rapid_wading()
	if fails.is_empty():
		print("RIVER TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("RIVER TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _line() -> void:
	var lo := INF
	var hi := -INF
	var banks_dry := true
	for z in [-380.0, -150.0, 0.0, 190.0, 370.0]:
		var cx := WorldRiver.x_at(z)
		var d := WorldRiver.depth_at(Vector3(cx, 0.0, z))
		lo = minf(lo, d)
		hi = maxf(hi, d)
		for s in [-13.0, 13.0]:
			banks_dry = banks_dry and WorldRiver.surface_at(cx + s, z) == WorldRiver.NO_WATER
	_expect(lo > 0.9 and hi < 1.6 and banks_dry, "line: over its centre %.2f-%.2f m deep; its banks dry" % [lo, hi])


func _flow() -> void:
	var ok := WorldRiver.level_at(-400.0) > WorldRiver.level_at(400.0) + 3.0
	var bends := true
	for z in [-300.0, -120.0, 60.0, 250.0]:
		var f := WorldRiver.flow_at(z)
		var num := Vector3(WorldRiver.x_at(z + 0.5) - WorldRiver.x_at(z - 0.5), 0.0, 1.0).normalized()
		bends = bends and f.dot(num) > 0.999 and f.z > 0.0
	_expect(ok and bends, "flow: its level falls southward (%.2f m to %.2f m); it runs along its bends" % [WorldRiver.level_at(-400.0), WorldRiver.level_at(400.0)])


func _extent() -> void:
	var zr := WorldRiver.z_range()
	var past := WorldRiver.surface_at(WorldRiver.x_at(500.0), 500.0)
	_expect(zr == Vector2(-416.0, 416.0) and past == WorldRiver.NO_WATER and WorldRiver.has_water(),
			"extent: water along the open land's length (%s), none past it" % str(zr))


func _rapids() -> void:
	var rs := WorldRiver.rapids()
	var mids := true
	var between := WorldRiver.rapid_at(-100.0) == 0.0 and WorldRiver.rapid_at(200.0) == 0.0
	var shallow := true
	var drops := true
	var broken := 0
	var worst := ""
	for r: Dictionary in rs:
		var z := float(r.z)
		mids = mids and is_equal_approx(WorldRiver.rapid_at(z), 1.0)
		# how deep at its middle (a few points across, the boulders aside)
		var deps: Array[float] = []
		for dx in [-3.0, -1.5, 0.0, 1.5, 3.0]:
			var d := WorldRiver.depth_at(Vector3(WorldRiver.x_at(z) + dx, 0.0, z))
			if d > 0.0:
				deps.append(d)
		deps.sort()
		var med: float = deps[deps.size() / 2] if not deps.is_empty() else 0.0
		shallow = shallow and med > 0.2 and med < 0.75
		var half := float(r.length) * 0.5 + 14.0
		var fell := WorldRiver.level_at(z - half) - WorldRiver.level_at(z + half)
		var want := float(r.drop) + float(WorldRiver.data().fall) * half * 2.0
		drops = drops and absf(fell - want) < 0.05
		if absf(fell - want) >= 0.05:
			worst = "fell %.2f want %.2f" % [fell, want]
		# boulders: ground over the water in the channel somewhere along it
		var zz := z - float(r.length) * 0.5
		while zz <= z + float(r.length) * 0.5:
			for dx in range(-7, 8):
				var x := WorldRiver.x_at(zz) + dx
				if FrontierTerrain.height_at(x, zz) > WorldRiver.level_at(zz) + 0.02:
					broken += 1
			zz += 1.0
	_expect(rs.size() == 3 and mids and between, "rapids: three, white water along each and none between (%d)" % rs.size())
	_expect(shallow and drops, "rapids: shallow in the middle; the surface falls its drop along each %s" % worst)
	_expect(broken > 20, "rapids: boulders breaking the water (%d points of rock over it in their channels)" % broken)


func _sound() -> void:
	await _fr(10)
	var fv := river.flow_voice
	var near := false
	if fv:
		var cam := (current_scene as Node3D).get_viewport().get_camera_3d()
		var at: Vector3 = cam.global_position if cam else p.global_position
		var z := clampf(at.z, -416.0, 416.0)
		near = fv.global_position.distance_to(Vector3(WorldRiver.x_at(z), WorldRiver.level_at(z) + 0.3, z)) < 1.0
	var roars := 0
	for v in river.rapid_voices:
		if v.playing:
			roars += 1
	_expect(fv != null and fv.playing and near, "sound: the running water playing from the river's point nearest the listener")
	_expect(roars == 3, "sound: a roar playing at each rapid (%d)" % roars)


func _rapid_wading() -> void:
	# up the river through the first rapid's middle: slowed more than in the pool below it (at the same depth)
	var r: Dictionary = WorldRiver.rapids()[1]
	var z := float(r.z)
	_put(Vector3(WorldRiver.x_at(z), 0.0, z), -WorldRiver.flow_at(z))
	await _fr(20)
	var depth := WorldRiver.surface_at(p.global_position.x, p.global_position.z) - p.global_position.y
	var k := clampf((depth - RiverWater.WADE_DEPTH.x) / (RiverWater.WADE_DEPTH.y - RiverWater.WADE_DEPTH.x), 0.0, 1.0)
	var pool_cap := float(p.run_speed) * lerpf(RiverWater.WADE_SLOW.x, RiverWater.WADE_SLOW.y, k)
	_expect(p.drag_speed_cap < pool_cap - 0.1, "rapids: wading there the current slows the player more (%.2f m/s against %.2f in still water as deep)" % [p.drag_speed_cap, pool_cap])
	_put(Vector3(WorldRiver.x_at(z) + 25.0, 0.0, z), Vector3.RIGHT)
	await _fr(5)


func _water() -> void:
	_expect(river != null and river.is_in_group(TorchState.WATER_GROUP), "water: the level has its River, in the water group")
	if river == null:
		return
	var z := 40.0
	var cx := WorldRiver.x_at(z)
	var lv := WorldRiver.level_at(z)
	var world := (current_scene as Node3D).get_world_3d()
	var wet := TorchState.under_water(world, self, Vector3(cx, lv - 0.3, z))
	var bank := TorchState.under_water(world, self, Vector3(cx + 16.0, FrontierTerrain.height_at(cx + 16.0, z) + 0.2, z))
	var above := TorchState.under_water(world, self, Vector3(cx, lv + 0.3, z))
	_expect(wet and not bank and not above, "water: under its surface is under water (a torch goes out there); the bank and above it are not")


func _put(at: Vector3, facing: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.yaw = atan2(-facing.x, -facing.z)
	p.rotation.y = p.yaw


func _wading() -> void:
	# up the river's middle, against its flow, then out onto the bank
	var z := 0.0
	_put(Vector3(WorldRiver.x_at(z), 0.0, z), -WorldRiver.flow_at(z))
	await _fr(30)
	var s0 := river.splashes
	Input.action_press(&"move_forward")
	var fastest := 0.0
	var capped := false
	for i in 120 * 4:
		await physics_frame
		fastest = maxf(fastest, Vector2(p.velocity.x, p.velocity.z).length())
		capped = capped or p.drag_speed_cap < p.run_speed
		# keep to the river's middle
		var f := -WorldRiver.flow_at(p.global_position.z)
		p.yaw = atan2(-f.x, -f.z)
		p.rotation.y = p.yaw
	Input.action_release(&"move_forward")
	_expect(capped and fastest < float(p.run_speed) * 0.75 and river.splashes > s0,
			"wading: up the river the player is slowed (at most %.1f m/s, a run %.1f), splashing (%d)" % [fastest, p.run_speed, river.splashes - s0])
	var bz := p.global_position.z
	_put(Vector3(WorldRiver.x_at(bz) + 20.0, 0.0, bz), Vector3.RIGHT)
	await _fr(10)
	_expect(p.drag_speed_cap == INF, "wading: out on the bank, the cap let go")


func _drinking() -> void:
	var z := -60.0
	var cx := WorldRiver.x_at(z)
	# on the bank, a step from the water's edge, facing it
	var edge := 0.0
	while WorldRiver.surface_at(cx + edge + 0.5, z) != WorldRiver.NO_WATER:
		edge += 0.5
	_put(Vector3(cx + edge + 1.2, 0.0, z), Vector3.LEFT)
	await _fr(20)
	var prompt := river.interact_prompt(p)
	_expect(prompt == "Drink from the river" and river.distance_from(p.global_position) < RiverWater.DRINK_REACH,
			"drinking: at the water's edge E offers \"%s\"" % prompt)
	var d0 := river.drinks
	var began := river.interact(p)
	var knelt := p.kneeling == river
	var t := 0.0
	while river.drinking and t < 12.0:
		await physics_frame
		t += 1.0 / 120.0
	_expect(began and knelt and river.drinks == d0 + 1 and p.kneeling == null,
			"drinking: the player kneels, drinks and gets up (%.1f s)" % t)


func _mammoth() -> void:
	var z := 120.0
	var cx := WorldRiver.x_at(z)
	var g := StandInGiant.new()
	g.name = "RiverMammoth"
	g.player = p
	g.paces = false
	current_scene.add_child(g)
	# 7 m from the river's middle, facing it: its trunk's reach (DRINK_REACH, 5 m ahead) in the water
	var at := Vector3(cx + 7.0, 0.0, z)
	at.y = FrontierTerrain.height_at(at.x, at.z)
	g.build(Transform3D(Basis.looking_at(Vector3.LEFT, Vector3.UP), at))
	await _fr(10)
	g.paces = true
	var began := g._begin_meal(true)
	_expect(began and g._meal == "Drink", "mammoth: at the bank facing the river it drinks from it (%s)" % g._meal)
	g.paces = false
