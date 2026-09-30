extends SceneTree
## Foliage in the plan (WalkGrid: the hazels, saplings, brush and ferns cost more, the understory under a thick canopy too),
## windowed so the plants are built: the same walks through the woods planned with the plants (blue) and without (red),
## seen from above.
##   Godot --path . --resolution 1280x720 -s tests/companion/walk_foliage_shot.gd -- out=<abs png> survival=on [at=x,z]
var out := ""
var at := Vector2(-30.0, 60.0)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		if a.begins_with("at="):
			var v := a.get_slice("=", 1).split(",")
			at = Vector2(float(v[0]), float(v[1]))
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 155:
		await process_frame
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	var g := WalkGrid.of(self)
	var legs := [[Vector2(-14, -14), Vector2(14, 14)], [Vector2(-16, 8), Vector2(16, -8)], [Vector2(0, -18), Vector2(0, 18)]]
	var n_on := 0.0
	var n_off := 0.0
	for l: Array in legs:
		var a := _ground(at + (l[0] as Vector2))
		var b := _ground(at + (l[1] as Vector2))
		g.foliage = true
		var p1 := g.plan(a, b, 0.3, WalkGrid.PERSON)
		var c1 := float(g.last.get("cost", 0.0))
		g.foliage = false
		var p0 := g.plan(a, b, 0.3, WalkGrid.PERSON)
		g.foliage = true
		_draw(p0, Color(0.95, 0.2, 0.15), 0.22)
		_draw(p1, Color(0.2, 0.55, 1.0), 0.3)
		n_on += WalkGrid._length(p1)
		n_off += WalkGrid._length(p0)
		print("leg: with plants %.1f m (cost %.1f), without %.1f m" % [WalkGrid._length(p1), c1, WalkGrid._length(p0)])
	var v := current_scene.get_node_or_null("Vegetation") as FrontierVegetation
	print("plants in the layout: %d; with %.1f m, without %.1f m" % [v.layout.plant_pos.size() if v and v.layout else -1, n_on, n_off])
	# (the crowns hidden: the bushes under them seen)
	for n in current_scene.get_node("Vegetation").find_children("Tree*", "", true, false):
		if n is Node3D:
			(n as Node3D).visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	current_scene.add_child(cam)
	cam.current = true
	var mid := _ground(at)
	cam.global_position = mid + Vector3(0.0, 46.0, 14.0)
	cam.look_at(mid, Vector3.UP)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.y), p.y)


## A path as a raised ribbon of boxes (seen through the grass and ferns).
func _draw(pts: PackedVector3Array, col: Color, wide: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := maxi(ceili(a.distance_to(b) / 1.0), 1)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			p.y = FrontierTerrain.height_at(p.x, p.z) + 0.6
			var mi := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(wide, 0.05, a.distance_to(b) / n + 0.05)
			bx.material = m
			mi.mesh = bx
			current_scene.add_child(mi)
			mi.global_position = p
			var d := b - a
			mi.rotation.y = atan2(d.x, d.z)
