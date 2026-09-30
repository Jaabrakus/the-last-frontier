extends SceneTree
## The ways to a place as the leader sees them (WorkerOrders' preview: WalkGrid.routes), windowed: a worker picked, the routes to
## a place drawn on the ground (best blue, round green, a different way orange, over purple), seen from above.
##   Godot --path . --resolution 1280x720 -s tests/companion/walk_routes_shot.gd -- out=<abs png> survival=on fort_plan=on [climb=1.6]
var out := ""
var climb := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		if a.begins_with("climb="):
			climb = float(a.get_slice("=", 1))
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 155:
		await process_frame
	var player := current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	var h := Household.find(self)
	var w := h.add_worker(781, 1.0, ["woodcutting"])
	w.role = "home"
	var hb := h.body_of(w)
	hb.abilities = {"climb_m": climb} if climb > 0.0 else {}
	await process_frame
	var from := Vector3(-60.0, 0.0, -40.0)
	from.y = FrontierTerrain.height_at(from.x, from.z) + 0.1
	hb.global_position = from
	var to := Vector3(-20.0, 0.0, 30.0)
	to.y = FrontierTerrain.height_at(to.x, to.z)
	var wo := WorkerOrders.ensure(self)
	await process_frame
	await process_frame
	wo = current_scene.get_node("WorkerOrders") as WorkerOrders
	wo.picked = hb
	wo.routes = WorkerOrders.routes_for(hb, to)
	var d := []
	for r in wo.routes:
		d.append("%s %d m%s" % [r.kind, roundi(r.len), " (over)" if r.over else ""])
	print("routes: ", d)
	var cam := Camera3D.new()
	cam.fov = 55.0
	current_scene.add_child(cam)
	cam.current = true
	var mid := from.lerp(to, 0.5)
	cam.global_position = mid + Vector3(45.0, 60.0, 30.0)
	cam.look_at(mid, Vector3.UP)
	await process_frame
	await process_frame
	await process_frame
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)
	else:
		await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
