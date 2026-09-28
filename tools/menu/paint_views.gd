extends SceneTree
## Paints the menu's and the loading screens' pictures from the game itself (user 2026-09-27: "oil paintings of that
## age ... instead of the godot"; "Both": these and a few public-domain period paintings): each view is staged in the
## level (the camera, the hour, a fire or torches where it wants them), rendered, and run twice through
## shaders/ui/oil_paint.gdshader (broad masses, then the smaller strokes with the canvas and the varnish). Windowed:
##
##   Godot --path . --resolution 1920x1080 -s tools/menu/paint_views.gd -- [out=<abs dir>] [only=a,b] [raw]
##
## Writes <name>.jpg (and <name>_raw.png with `raw`) to `out` (default assets/ui/paintings/). The level's player plays
## Actor_B animation data; the mammoth and the deer are CC0 models (their SOURCE.md files).

const OUT := "res://assets/ui/paintings/"
## The views: name, the hour, the camera and where it looks (world), and what the view sets up first.
const VIEWS := [
	{"name": "fort_evening", "hour": 18.5, "cam": Vector3(40.0, 1.9, -6.0), "look": Vector3(17.0, 3.5, 6.0), "setup": "horse"},
	{"name": "horse_evening", "hour": 18.4, "cam": Vector3(31.0, 1.7, 3.0), "look": Vector3(24.0, 1.3, 9.0), "setup": "horse"},
	{"name": "camp_night", "hour": 21.2, "cam": Vector3(28.0, 1.5, 15.0), "look": Vector3(24.0, 0.8, 12.0), "setup": "camp"},
	{"name": "palisade_torches", "hour": 21.0, "cam": Vector3(26.0, 1.7, 18.0), "look": Vector3(16.2, 2.2, 5.0), "setup": "torches"},
	{"name": "woods_morning", "hour": 8.0, "cam": Vector3(58.0, 1.7, -46.0), "look": Vector3(44.0, 3.0, -64.0), "setup": ""},
]

var out := ""
var only: Array = []
var keep_raw := false
var player: FrontierPlayer
var cam: Camera3D
var clock: WorldClock
var noises: Array = []


func _initialize() -> void:
	out = ProjectSettings.globalize_path(OUT)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("only="):
			only = Array(a.get_slice("=", 1).split(","))
		elif a == "raw":
			keep_raw = true
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)      # the desk's keys stay out of it
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	var rig := current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig
	clock = rig.clock_driver.clock if rig and rig.clock_driver else null
	if rig and rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	for i in 3:
		var fn := FastNoiseLite.new()
		fn.seed = 11 + i * 7
		fn.frequency = 0.02 if i < 2 else 0.09
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.noise = fn
		noises.append(nt)
	await _frames(90)
	cam = Camera3D.new()
	cam.fov = 55.0
	current_scene.add_child(cam)
	for v: Dictionary in VIEWS:
		if not only.is_empty() and not (String(v.name) in only):
			continue
		await _view(v)
	print("PAINT VIEWS DONE")
	quit(0)


func _hud(on: bool) -> void:
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = on


func _view(v: Dictionary) -> void:
	if clock:
		clock.set_time(float(v.hour))
	player.visible = false
	await _setup(String(v.setup))
	var at: Vector3 = v.cam
	at.y += FrontierTerrain.height_at(at.x, at.z)
	var look: Vector3 = v.look
	look.y += FrontierTerrain.height_at(look.x, look.z)
	cam.global_position = at
	cam.look_at(look, Vector3.UP)
	cam.current = true
	_hud(false)
	await _frames(90)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if keep_raw:
		img.save_png(out.path_join(String(v.name) + "_raw.png"))
	var painted := await _paint(img)
	painted.save_jpg(out.path_join(String(v.name) + ".jpg"), 0.9)
	print("  painted ", v.name, " ", painted.get_size())
	_hud(true)
	cam.current = false
	if player.camera:
		player.camera.current = true


## The two passes: broad masses (a wide brush, no finish), then the strokes, the canvas and the varnish.
func _paint(img: Image) -> Image:
	var tex := ImageTexture.create_from_image(img)
	var first := await _pass(tex, img.get_size(), 6, false)
	return await _pass(ImageTexture.create_from_image(first), img.get_size(), 3, true)


func _pass(tex: Texture2D, size: Vector2i, brush: int, finish: bool) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := TextureRect.new()
	rect.texture = tex
	rect.size = Vector2(size)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ui/oil_paint.gdshader")
	mat.set_shader_parameter("noise_a", noises[0])
	mat.set_shader_parameter("noise_b", noises[1])
	mat.set_shader_parameter("noise_c", noises[2])
	mat.set_shader_parameter("brush", brush)
	mat.set_shader_parameter("finish", finish)
	rect.material = mat
	vp.add_child(rect)
	root.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var out_img := vp.get_texture().get_image()
	vp.queue_free()
	return out_img


var _made := {}


## What a view wants in it: "camp" a lit campfire, "torches" torches wedged along the palisade, "horse" the horse.
func _setup(what: String) -> void:
	if what == "" or _made.has(what):
		return
	_made[what] = true
	match what:
		"camp":
			var inv := InventoryState.from_player(player)
			inv.add("stone", 6)
			inv.add("firewood", 6)
			player.inventory_pack = inv.pack.duplicate(true)
			var mode := player.get_node_or_null("BuildMode") as BuildMode
			if mode:
				var fire_at := _ground(Vector3(24.0, 0, 12.0))
				player.global_position = fire_at + Vector3(0, 0.1, 3.0)
				await _frames(4)
				mode.set_active(true)
				mode.select_type("campfire")
				mode.aim_at = fire_at
				await _frames(6)
				mode.refresh_placement()
				var fp := mode.place()
				mode.set_active(false)
				mode.aim_at = Vector3.INF
				var cf := fp.get_node_or_null("Campfire") as Campfire if fp else null
				if cf:
					cf.interact(player)
				# the player sits by it, seen
				player.global_position = fire_at + Vector3(1.3, 0.05, 0.9)
				player.visible = true
		"torches":
			for z: float in [2.0, 7.0, 12.0]:
				var q := PhysicsRayQueryParameters3D.create(_ground(Vector3(21.0, 0, z)) + Vector3.UP * 1.5,
						_ground(Vector3(21.0, 0, z)) + Vector3(-10, 1.5, 0))
				q.exclude = [player.get_rid()]
				var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
				if hit.is_empty():
					continue
				var p: Vector3 = hit.position
				var head := Vector3.UP * cos(0.6) + Vector3.RIGHT * sin(0.6)
				var b := Basis.looking_at(head, Vector3.BACK)      # (the torch's head is its -Z)
				var d := DroppedTorch.spawn(current_scene, Transform3D(b, p + head * TorchModels.GRIP_FROM_BUTT), Vector3.ZERO,
						Vector3.ZERO, TorchState.new())
				d.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
				d.freeze = true
				d.state.light()
		"horse":
			for h in current_scene.find_children("*", "Horse", true, false):
				(h as Horse).global_position = _ground(Vector3(24.0, 0, 9.0)) + Vector3.UP * 0.05
				(h as Horse).rotation.y = 0.9
