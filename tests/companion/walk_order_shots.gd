extends SceneTree
## Point-and-click orders for a worker (WorkerOrders, WalkPath, WalkGrid), windowed: she is sent from the hearth out of the
## fort to a place west of it, into the woods, and home, the places queued as the leader queues them. Each leg's walk is
## measured (its time, how much longer than the straight line it went, how much her heading wandered per metre, stops,
## plans and detours), shots of her with the plan drawn, and with frames=on a frame every other one for a video.
## mover=old walks the same legs on the mesh's paths (NavMover) for the comparison.
##   Godot --path . --resolution 1280x720 -s tests/companion/walk_order_shots.gd -- out=<abs dir> survival=on fort_plan=on [mover=old] [frames=on]
var out := ""
var old := false
var frames := false
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		if a == "mover=old":
			old = true
		if a == "frames=on":
			frames = true
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(path: String) -> void:
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)
	else:
		await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


## Behind and above her, a little to the side, clear of trunks and walls.
func _follow(who: Node3D, dt: float) -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 50.0
		current_scene.add_child(cam)
		cam.current = true
	var v := Vector3(who.get("velocity").x, 0.0, who.get("velocity").z) if who.get("velocity") != null else Vector3.ZERO
	var d := v.normalized() if v.length() > 0.3 else -who.global_basis.z
	d.y = 0.0
	d = d.normalized()
	var right := d.cross(Vector3.UP)
	var at := who.global_position + Vector3.UP * 0.9
	var want := at - d * 6.5 + right * 2.5 + Vector3.UP * 4.0
	var q := PhysicsRayQueryParameters3D.create(at, want)
	q.exclude = [(who as CollisionObject3D).get_rid()]
	var hit := who.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = at.lerp(hit.position, 0.85)
	cam.global_position = want if cam.global_position == Vector3.ZERO else cam.global_position.lerp(want, clampf(dt * 2.0, 0.0, 1.0))
	cam.look_at(at + d * 1.5, Vector3.UP)


func _run() -> void:
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	await _frames(5)
	var player := current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	await _frames(150)
	var h := Household.find(self)
	var core := h.bridge.core
	core.advance(fposmod(10.0 - SurvivalClock.hour(core), 24.0) * 60.0)
	var w := h.add_worker(781, 1.0, ["woodcutting"])
	w.role = "home"
	var hb := h.body_of(w)
	hb.nav.use_grid = not old
	await _frames(20)
	var start := hb.hearth + Vector3(2.0, 0.0, 3.0)
	hb.global_position = Vector3(start.x, FrontierTerrain.height_at(start.x, start.z) + 0.1, start.z)
	var legs := [Vector3(-40.0, 0.0, 6.0), Vector3(-78.0, 0.0, 28.0), hb.hearth + Vector3(-2.0, 0.0, 2.0)]
	for i in legs.size():
		legs[i].y = FrontierTerrain.height_at(legs[i].x, legs[i].z)
		WorkerOrders.order(hb, legs[i], i > 0)
	var wo := WorkerOrders.ensure(self)
	await _frames(2)
	wo = current_scene.get_node_or_null("WorkerOrders") as WorkerOrders
	if wo:
		wo.picked = hb
	print("mover: %s; legs %s" % ["mesh (old)" if old else "grid + rays (new)", legs])
	var leg := 0
	var t := 0.0
	var walked := 0.0
	var turn := 0.0
	var stops := 0
	var still_t := 0.0
	var last := hb.global_position
	var last_yaw := hb.rotation.y
	var leg_from := hb.global_position
	var f := 0
	var shots := 0
	var results := []
	for i in 60 * 240:
		await process_frame
		var dt := 1.0 / 60.0
		t += dt
		_follow(hb, dt)
		var p := hb.global_position
		var step := Vector2(p.x - last.x, p.z - last.z).length()
		walked += step
		var yaw := hb.rotation.y
		turn += absf(angle_difference(last_yaw, yaw))
		last_yaw = yaw
		var sp := Vector2(hb.velocity.x, hb.velocity.z).length()
		if sp < 0.15:
			still_t += dt
			if still_t >= 0.3 and still_t - dt < 0.3:
				stops += 1                     # (stood still 0.3 s on the way: a stop)
		else:
			still_t = 0.0
		last = p
		if frames and out != "" and f % 2 == 0:
			await _save(out.path_join("frames/%05d.png" % (f / 2)))
		f += 1
		if i % 240 == 120 and shots < 12 and out != "" and not frames:
			shots += 1
			await _save(out.path_join("walk_%s_%02d.png" % ["old" if old else "new", shots]))
		var n_left := hb.orders.size()
		if n_left < legs.size() - leg:
			var straight := Vector2(p.x - leg_from.x, p.z - leg_from.z).length()
			var nav := hb.nav
			var r := {"leg": leg, "s": snappedf(t, 0.1), "walked_m": snappedf(walked, 0.1), "straight_m": snappedf(straight, 0.1),
					"longer": snappedf(walked / maxf(straight, 0.1), 0.01), "turn_deg_per_m": snappedf(rad_to_deg(turn) / maxf(walked, 0.1), 0.1),
					"stops": stops, "plans": nav.walk.plans if nav and nav.walk else nav.paths if nav else -1,
					"detours": nav.walk.detours if nav and nav.walk else -1}
			print("leg ", r)
			results.append(r)
			leg += 1
			t = 0.0
			walked = 0.0
			turn = 0.0
			stops = 0
			leg_from = p
			if hb.nav and hb.nav.walk:
				hb.nav.walk.plans = 0
				hb.nav.walk.detours = 0
		if hb.orders.is_empty():
			break
	if not hb.orders.is_empty():
		print("NOT ARRIVED: %d places left, at %s" % [hb.orders.size(), hb.global_position])
	var g := WalkGrid.of(self)
	print("grid: plans %d, last %s" % [g.plans if g else 0, str(g.last.get("ms", -1)) + " ms" if g else "-"])
	print("WALK ORDERS DONE ", out)
	quit()
