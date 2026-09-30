extends SceneTree
## Look-check of the four boats as they lie, hull whole and paddles or oars inside, windowed:
##   Godot --path . --resolution 1200x600 -s tests/boats/boat_look.gd -- out=<abs dir>
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var root3 := Node3D.new()
	root.add_child(root3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.72, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.78)
	e.ambient_light_energy = 0.6
	env.environment = e
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	root3.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.46, 0.5)
	ground.material_override = gm
	root3.add_child(ground)
	var ids := Boat.ids()
	for i in ids.size():
		var b := Boat.make(ids[i], Vector3(-5.0 + float(i) * 3.6, 0.0, 0.0), 0.0)
		root3.add_child(b)
	var cam := Camera3D.new()
	cam.fov = 45
	root3.add_child(cam)
	var at := Vector3(-7.0, 9.0, -6.5)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0.6, 0.0, 0.0) - at, Vector3.UP), at)
	cam.current = true
	for i in 10:
		await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join("boats.png"))
	print("saved boats")
	quit()
