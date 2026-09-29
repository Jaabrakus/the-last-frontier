extends SceneTree
## Close-ups of every baby animation, windowed: the baby (BabyModel: the game's body made a newborn, assets/baby/baby_anims.res) plays each clip in front of a
## plain backdrop and is photographed at three moments, from close on the face and from the whole body. One contact sheet per
## clip (rows: the moments, columns: face, body), written as anim_<name>.png.
##   Godot --path . --resolution 1280x720 -s tests/companion/baby_anim_shots.gd -- out=<abs dir> [only=cry,suckle]
var out := ""
var only: PackedStringArray = []
var cam: Camera3D
var baby: BabyModel

const MOMENTS := [0.15, 0.45, 0.75]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("only="):
			only = a.get_slice("=", 1).split(",")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.66, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.78)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 32.0
	root.add_child(cam)
	cam.current = true


func _snap() -> Image:
	await _frames(2)
	await _frames(2)
	return root.get_viewport().get_texture().get_image()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	_scene()
	var child := {"id": "child.1", "name": "Hannah", "sex": 0.0, "born_at": 0.0, "seed": 5}
	baby = BabyModel.create(child, [0.25, 0.35])
	root.add_child(baby)
	baby.set_process(false)
	var anim: AnimationPlayer = baby._anim
	var names: Array = []
	if baby._bb != null:
		names = Array(baby._bb.ap.get_animation_library(BabyBody.LIB).get_animation_list())
		names.sort()
	if anim == null:
		print("BABY ANIM SHOTS: no glb rig")
		quit(1)
		return
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3, 3)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.5, 0.53, 0.56)
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	for n: String in names:
		if not only.is_empty() and not n in only:
			continue
		var ground := n in ["sit_wobble", "crawl", "toddle"]
		floor_mi.position.y = 0.0 if ground else -0.06
		baby.play(n, 0.0)
		anim.pause()
		var len_s := baby._bb.anim_length(n)
		var views: Array = _views(n, ground)
		var sheet := Image.create(1280, 360 * MOMENTS.size(), false, Image.FORMAT_RGB8)
		for r in MOMENTS.size():
			anim.seek(len_s * float(MOMENTS[r]), true)
			baby._t = len_s * float(MOMENTS[r])
			baby._face()
			for c in views.size():
				var v: Dictionary = views[c]
				cam.global_position = v.pos
				cam.look_at(v.at, v.up)
				var img := await _snap()
				img.resize(640, 360, Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(img, Rect2i(0, 0, 640, 360), Vector2i(640 * c, 360 * r))
		sheet.save_png(out.path_join("anim_" + n + ".png"))
		print("saved ", n, " (", "%.2f" % len_s, " s)")
	print("BABY ANIM SHOTS DONE ", out)
	quit()


## Two views: on the face, and the whole baby.
func _views(_n: String, ground: bool) -> Array:
	if not ground:      # lying on its back, head at +x, face up
		return [{"pos": Vector3(0.115, 0.34, 0.0), "at": Vector3(0.175, 0.03, 0.0), "up": Vector3(1, 0, 0)},
				{"pos": Vector3(0.0, 1.05, 0.0), "at": Vector3(-0.01, 0.0, 0.0), "up": Vector3(1, 0, 0)}]
	if _n == "crawl":   # walks toward +x, belly down
		return [{"pos": Vector3(0.75, 0.16, 0.12), "at": Vector3(0.24, 0.1, 0.0), "up": Vector3.UP},
				{"pos": Vector3(0.0, 0.16, 0.85), "at": Vector3(0.0, 0.1, 0.0), "up": Vector3.UP}]
	# upright, the front toward -x
	return [{"pos": Vector3(-0.62, 0.38, 0.1), "at": Vector3(-0.02, 0.33, 0.0), "up": Vector3.UP},
			{"pos": Vector3(-0.6, 0.25, 0.75), "at": Vector3(0.0, 0.2, 0.0), "up": Vector3.UP}]
