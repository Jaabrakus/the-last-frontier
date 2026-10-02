extends SceneTree
## Stills of the rigged bison (tools/wildlife/bison_rig.py) in its clips, from the side and three-quarters, on a plain
## ground in daylight (no text on the pictures):
##   Godot --path . -s tools/wildlife/bison_preview.gd -- out=<dir> [size=960x540] [model=res://...glb]
## One still per [clip, time]; the sheet is made from them outside.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
var MODEL := "res://assets/wildlife/bison/bison.glb"
const POSES := [["Idle", 0.5], ["Walk", 0.25], ["Walk", 0.6], ["Gallop", 0.2], ["Gallop", 0.45], ["Eating", 1.0],
		["Attack_Headbutt", 0.45], ["Idle_HitReact_Left", 0.3], ["Death", 3.0]]

var out := ""
var size := Vector2i(960, 540)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("model="):
			MODEL = a.substr(6)
		elif a.begins_with("size="):
			var wh := a.substr(5).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.72, 0.82)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40.0, 40.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.46, 0.5, 0.32)
	ground.material_override = gm
	world.add_child(ground)
	var bison := (load(MODEL) as PackedScene).instantiate() as Node3D
	world.add_child(bison)
	var ap := bison.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	print("BISON PREVIEW clips ", ap.get_animation_list())
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, size)
	root.disable_3d = true
	for i in 5:
		await process_frame
	var n := 0
	for pose: Array in POSES:
		var clip := String(pose[0])
		if not ap.has_animation(clip):
			print("BISON PREVIEW no clip ", clip)
			continue
		ap.play(clip, 0.0)
		ap.seek(float(pose[1]), true)
		ap.pause()
		for cam: Array in [[Vector3(5.2, 1.3, 0.0), "side"], [Vector3(3.6, 1.8, -3.6), "q"]]:
			view.camera.global_position = cam[0]
			view.camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)
			view.camera.fov = 45.0
			for i in 3:
				await process_frame
			var img: Image = view.get_texture().get_image()
			img.save_png(out.path_join("%02d_%s_%s.png" % [n, clip, cam[1]]))
		n += 1
	print("BISON PREVIEW DONE")
	quit()
