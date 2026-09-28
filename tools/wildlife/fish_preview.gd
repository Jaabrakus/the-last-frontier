extends SceneTree
## A look at the fish (FishMesh): every species a metre long on a plain ground, from the side (sheet 1) and from above
## at a slant, as from the bank (sheet 2), 3 x 3 in the order of data/world/fish.json. Windowed (it renders):
##   Godot --path . -s tools/wildlife/fish_preview.gd -- out=<dir>
## Writes <dir>/fish_side.png and <dir>/fish_above.png.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const CELL := Vector2i(640, 360)

var out := "user://fish_preview"
var view


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.46, 0.52, 0.54)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.85)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -60.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 120.0, 0.0)
	fill.light_energy = 0.35
	world.add_child(fill)
	var ids := FishSpecies.ids()
	for i in ids.size():
		var mi := MeshInstance3D.new()
		mi.mesh = FishMesh.mesh(ids[i])
		mi.material_override = FishMesh.material(ids[i])
		mi.position = Vector3(0.0, 0.0, float(i) * 6.0)
		world.add_child(mi)
		var ground := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(6.0, 6.0)
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.55, 0.52, 0.45)
		pm.material = gm
		ground.mesh = pm
		ground.position = mi.position + Vector3(0.0, -0.16, 0.0)
		world.add_child(ground)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, CELL)
	root.disable_3d = true
	await process_frame
	for sheet in ["side", "above"]:
		var img := Image.create(CELL.x * 3, CELL.y * 3, false, Image.FORMAT_RGBA8)
		for i in ids.size():
			var at := Vector3(0.0, 0.0, float(i) * 6.0)
			var from := at + (Vector3(-3.4, 0.35, 0.0) if sheet == "side" else Vector3(-2.2, 2.6, 0.9))
			view.camera.fov = 12.0 if sheet == "side" else 15.0
			view.camera.global_transform = Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
			for f in 4:
				await process_frame
			var cell: Image = view.get_texture().get_image()
			cell.convert(Image.FORMAT_RGBA8)
			img.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % 3) * CELL.x, (i / 3) * CELL.y))
		img.save_png(out.path_join("fish_%s.png" % sheet))
	print("FISH PREVIEW DONE ", ids)
	quit()
