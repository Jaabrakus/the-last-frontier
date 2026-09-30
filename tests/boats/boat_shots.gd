extends SceneTree
## Look-check of a boat growing on its stand (HullMesh), windowed:
##   Godot --path . --resolution 960x540 -s tests/boats/boat_shots.gd -- out=<abs dir>
## One picture per stage, and a contact sheet of all of them.
var out := ""
var hull: HullMesh
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var root3 := Node3D.new()
	root.add_child(root3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.72, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.78)
	e.ambient_light_energy = 0.55
	env.environment = e
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	root3.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.36, 0.28)
	gm.roughness = 1.0
	ground.material_override = gm
	root3.add_child(ground)
	hull = HullMesh.new()
	root3.add_child(hull)
	hull.setup((BoatBuild.plans().birchbark as Dictionary).hull)
	cam = Camera3D.new()
	cam.fov = 40
	root3.add_child(cam)
	var at := Vector3(2.5, 2.7, -3.5)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.3, 0.2) - at, Vector3.UP), at)
	cam.current = true
	var states := [
		["1_stakes_going_in", {"stakes": 0.5}],
		["2_bed_laid", {"stakes": 1.0}],
		["3_bark_going_on", {"stakes": 1.0, "skin": 0.55}],
		["4_skin_sewn", {"stakes": 1.0, "skin": 1.0}],
		["5_gunwales", {"stakes": 1.0, "skin": 1.0, "gunwales": 1.0}],
		["6_ribs_going_in", {"stakes": 1.0, "skin": 1.0, "gunwales": 1.0, "ribs": 0.5}],
		["7_ribs_set", {"stakes": 1.0, "skin": 1.0, "gunwales": 1.0, "ribs": 1.0}],
		["8_pitched_done", {"skin": 1.0, "gunwales": 1.0, "ribs": 1.0, "pitch": 1.0}],
	]
	var imgs: Array[Image] = []
	for s: Array in states:
		for id in ["stakes", "skin", "gunwales", "ribs", "pitch"]:
			hull.set_part(id, float((s[1] as Dictionary).get(id, 0.0)))
		for i in 4:
			await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.path_join(String(s[0]) + ".png"))
		imgs.append(img)
		print("saved ", s[0])
	var w := imgs[0].get_width() / 2
	var h := imgs[0].get_height() / 2
	var sheet := Image.create(w * 2, h * 4, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		var im := imgs[i].duplicate() as Image
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	sheet.save_png(out.path_join("sheet.png"))
	quit()
