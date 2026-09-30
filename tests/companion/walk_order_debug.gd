extends SceneTree
## The click-order walk without a window (WalkPath, WalkGrid), fast: a worker sent from beside the hearth out of the fort to
## the places `legs`; prints how each leg went and, when she makes no headway, what she is pushing against (her position, the
## plan, the point she steers for, the ray's hit, the bodies she touches).
##   Godot --headless --path . -s tests/companion/walk_order_debug.gd -- survival=on fort_plan=on [mover=old] [scale=6]
var old := false
var time_scale := 6.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "mover=old":
			old = true
		if a.begins_with("scale="):
			time_scale = float(a.get_slice("=", 1))
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 200:
		await physics_frame
	var h := Household.find(self)
	if h == null:
		print("NO HOUSEHOLD")
		quit()
		return
	var w := h.add_worker(781, 1.0, ["woodcutting"])
	w.role = "home"
	var hb := h.body_of(w)
	hb.order_grid = not old
	await physics_frame
	var start := hb.hearth + Vector3(2.0, 0.0, 3.0)
	hb.global_position = Vector3(start.x, FrontierTerrain.height_at(start.x, start.z) + 0.1, start.z)
	var legs := [Vector3(-40.0, 0.0, 6.0), Vector3(-78.0, 0.0, 28.0), hb.hearth + Vector3(-2.0, 0.0, 2.0)]
	for i in legs.size():
		legs[i].y = FrontierTerrain.height_at(legs[i].x, legs[i].z)
		WorkerOrders.order(hb, legs[i], i > 0)
	Engine.time_scale = time_scale
	print("mover: %s" % ("mesh (old)" if old else "grid + rays (new)"))
	var leg := 0
	var t := 0.0
	var walked := 0.0
	var turn := 0.0
	var stops := 0
	var still := 0.0
	var last := hb.global_position
	var last_yaw := hb.rotation.y
	var leg_from := hb.global_position
	var report_t := 0.0
	for i in 60 * 200:
		await physics_frame
		var dt := 1.0 / float(Engine.physics_ticks_per_second)
		t += dt
		var p := hb.global_position
		walked += Vector2(p.x - last.x, p.z - last.z).length()
		turn += absf(angle_difference(last_yaw, hb.rotation.y))
		last_yaw = hb.rotation.y
		last = p
		var sp := Vector2(hb.velocity.x, hb.velocity.z).length()
		if sp < 0.15:
			still += dt
			if still >= 0.3 and still - dt < 0.3:
				stops += 1
		else:
			still = 0.0
		report_t += dt
		if report_t > 8.0 and still > 3.0:
			report_t = 0.0
			var wp := hb.nav.walk if hb.nav else null
			var touch := []
			for ci in hb.get_slide_collision_count():
				var kc := hb.get_slide_collision(ci)
				var cn := kc.get_collider() as Node
				touch.append("%s@%s" % [cn.name if cn else "?", kc.get_position().snappedf(0.1)])
			var aim := WalkPath.carrot(wp.way, p, WalkPath.AHEAD_M) if wp and wp.way.size() >= 2 else Vector3.INF
			print("STUCK at %s leg %d: orders %d, plans %d detours %d, status %s, way %d pts, carrot %s, ray hit %s, touching %s, floor %s" % [
					p.snappedf(0.1), leg, hb.orders.size(), wp.plans if wp else -1, wp.detours if wp else -1, wp.status if wp else "-",
					wp.way.size() if wp else 0, aim.snappedf(0.1) if aim != Vector3.INF else "-", wp.last_hit.snappedf(0.1) if wp and wp.last_hit != Vector3.INF else "clear",
					touch, hb.is_on_floor()])
			if wp:
				var pts := []
				for q in wp.way:
					pts.append(q.snappedf(0.5))
				print("   way ", pts)
		if hb.orders.size() < legs.size() - leg:
			var straight := Vector2(p.x - leg_from.x, p.z - leg_from.z).length()
			var nav := hb.nav
			print("leg ", {"leg": leg, "s": snappedf(t, 0.1), "walked_m": snappedf(walked, 0.1), "straight_m": snappedf(straight, 0.1),
					"longer": snappedf(walked / maxf(straight, 0.1), 0.01), "turn_deg_per_m": snappedf(rad_to_deg(turn) / maxf(walked, 0.1), 0.1),
					"stops": stops, "plans": nav.walk.plans if nav and nav.walk else (nav.paths if nav else -1),
					"detours": nav.walk.detours if nav and nav.walk else -1})
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
	print("WALK DEBUG DONE")
	Engine.time_scale = 1.0
	quit()
