extends SceneTree
## A worker sent straight at a rock or a log too high to step on to (WorkerTraversal: the player's moves on her rig), headless:
## it finds one in the world that stands `lo`..`hi` m high, sends her at it from 7 m off with the route straight over it, and
## reports whether a move played (its name), how long it took and whether she got across.
##   Godot --headless --path . -s tests/companion/walk_vault_test.gd -- survival=on fort_plan=on [lo=0.8] [hi=1.3] [shots=<abs dir>]
var lo := 0.8
var hi := 1.3
var shots := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lo="):
			lo = float(a.get_slice("=", 1))
		if a.begins_with("hi="):
			hi = float(a.get_slice("=", 1))
		if a.begins_with("shots="):
			shots = a.get_slice("=", 1)
	if shots != "":
		InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 260:
		await physics_frame
	if shots != "":
		var player := current_scene.get_node("Player") as FrontierPlayer
		player.ignore_mouse_capture = true
		for c in root.find_children("*", "CharacterCreator", true, false):
			if c.has_method("close"):
				c.close()
	var h := Household.find(self)
	var w := h.add_worker(781, 1.0, ["woodcutting"])
	w.role = "home"
	var hb := h.body_of(w)
	await physics_frame
	var g := WalkGrid.of(self)
	var pick := {}
	var best := INF
	for sz in range(-2, 2):
		for sx in range(-2, 2):
			for o in g._obstacles(Vector2i(sx, sz)):
				if o.get("low", false) or not o.has("poly") or float(o.top) < lo or float(o.top) > hi:
					continue
				var poly: PackedVector2Array = o.poly
				var bb := Rect2(poly[0], Vector2.ZERO)
				for v in poly:
					bb = bb.expand(v)
				if bb.size.x > 4.0 or bb.size.y > 4.0:
					continue
				var c := bb.get_center()
				var d := c.distance_to(Vector2(0, 0))
				if d > 30.0 and d < best:
					best = d
					pick = {"c": c, "top": o.top, "size": bb.size}
	if pick.is_empty():
		print("NO ROCK between %.1f and %.1f m" % [lo, hi])
		quit()
		return
	var c: Vector2 = pick.c
	print("obstacle at %s, %.2f m high, %s m across" % [c.snappedf(0.1), pick.top, (pick.size as Vector2).snappedf(0.1)])
	var dir := Vector2(1, 0)
	var a2 := c - dir * 7.0
	var b2 := c + dir * 7.0
	var start := Vector3(a2.x, FrontierTerrain.height_at(a2.x, a2.y) + 0.1, a2.y)
	var goal := Vector3(b2.x, FrontierTerrain.height_at(b2.x, b2.y), b2.y)
	hb.global_position = start
	hb.velocity = Vector3.ZERO
	hb.set("_face", atan2(-dir.x, -dir.y))
	hb.rotation.y = hb.get("_face")
	await physics_frame
	hb.abilities = {"climb_m": 2.0}
	WorkerOrders.order(hb, goal, false, PackedVector3Array([start, goal]))
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	var trav := hb.trav
	print("traversal ready: ", trav != null, " world_ready ", trav.world_ready if trav else false)
	var t := 0.0
	var shot_n := 0
	var over_at := -1.0
	var last_showing := false
	for i in 60 * 40:
		await physics_frame
		t += 1.0 / 60.0
		var p := hb.global_position
		if trav.showing != last_showing:
			last_showing = trav.showing
			print("[%5.2fs] move %s at %s (x %.1f of %.1f, y %.2f)" % [t, "STARTS" if trav.showing else "ENDS (%s)" % trav.last_move, p.snappedf(0.1), p.x, c.x, p.y])
		if shots != "" and trav.showing and i % 8 == 0 and shot_n < 10:
			shot_n += 1
			var cam := current_scene.get_node_or_null("ShotCam") as Camera3D
			if cam == null:
				cam = Camera3D.new()
				cam.name = "ShotCam"
				cam.fov = 45.0
				current_scene.add_child(cam)
				cam.current = true
			cam.global_position = Vector3(c.x, p.y + 1.6, c.y - 6.0)
			cam.look_at(Vector3(c.x, p.y + 0.9, c.y), Vector3.UP)
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(shots.path_join("vault_%02d.png" % shot_n))
		if over_at < 0.0 and p.x > c.x + 1.5:
			over_at = t
		if hb.orders.is_empty():
			break
	print("RESULT: moves played %d, crossed %s (at %.1f s), now at %s, orders left %d" % [trav.moves, over_at > 0.0, over_at, hb.global_position.snappedf(0.1), hb.orders.size()])
	quit()
