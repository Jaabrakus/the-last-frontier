extends SceneTree
## Package B look-dev shots: fixed viewpoints on the terrain, ground textures and grass (the
## shared tools/environment/scenic_shots.gd covers the gameplay views). Needs a window (not
## --headless); wrap it in a time limit. Works with the window covered (off-window capture).
##
##   Godot --path . --resolution 1280x720 -s tools/environment/terrain/terrain_shots.gd -- \
##       --no-capture out=<dir> [prefix=<tag>_] [only=a,b] [settle=60] [quality=low|medium|high]
##
## Camera and target heights are metres above FrontierTerrain.height_at(). Views:
##   meadow_eye     standing in the knee-high clearing meadow west of the fort (grass density,
##                  dry patches, forest edge)
##   grass_close    looking down into the meadow grass (tuft cards, colour, ground match)
##   shoulder       along the mowed range shoulder beside the lane strip (turf, dirt edge)
##   gate_ruts      low view over the gate throat ruts and the apron
##   fort_floor     over the parade ground: worn paths, wall-foot tufts
##   track_west     on the woodcutters' track through the forest (path, corridor, floor)
##   backstop       from the end of the lane toward the backstop hill
##   east_draw      down the east draw and its dry brook bed (mud layer)
##   ridge          from the ridge flank over outcrops (rock layer, triplanar)
##   tiling_20_80   forest floor and meadow at 20-80 m (anti-tiling check)
##   high_aerial    120 m up over the range (LOD seams and cracks, splat layout)
## Saves <out>/<prefix><view>.png and <prefix>sheet.png. Prints TERRAIN SHOTS DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

## [name, camera xz + height above ground, target xz + height above ground, fov]
const VIEWS := [
	["meadow_eye", Vector3(-24.0, 1.7, 4.0), Vector3(-60.0, 0.8, 22.0), 65.0],
	["grass_close", Vector3(-30.0, 1.4, 8.0), Vector3(-33.0, 0.0, 12.0), 60.0],
	["shoulder", Vector3(9.5, 1.6, -38.0), Vector3(8.0, 0.4, -95.0), 60.0],
	["gate_ruts", Vector3(2.5, 1.2, -11.0), Vector3(-0.5, 0.0, -24.0), 60.0],
	["fort_floor", Vector3(10.0, 3.2, 12.0), Vector3(-2.0, 0.0, -6.0), 60.0],
	["track_west", Vector3(-62.0, 1.7, -9.5), Vector3(-100.0, 1.0, -18.0), 65.0],
	["backstop", Vector3(0.0, 1.7, -165.0), Vector3(5.0, 8.0, -300.0), 55.0],
	["east_draw", Vector3(150.0, 3.0, 110.0), Vector3(172.0, 0.0, 30.0), 60.0],
	["ridge", Vector3(-140.0, 3.0, 60.0), Vector3(-190.0, 2.0, 40.0), 60.0],
	["tiling_20_80", Vector3(-45.0, 2.5, -40.0), Vector3(-90.0, 0.0, -90.0), 60.0],
	["high_aerial", Vector3(60.0, 120.0, 120.0), Vector3(0.0, 0.0, -90.0), 60.0],
]

var args := {}
var view: SubViewport


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://terrain_shots")
	var prefix: String = args.get("prefix", "")
	var settle := int(args.get("settle", "60"))
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	DirAccess.make_dir_recursive_absolute(out)
	OS.low_processor_usage_mode_sleep_usec = 0
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player: Node = current_scene.get_node("Player")
	player.set("ignore_mouse_capture", true)
	player.set_process(false)
	player.set_physics_process(false)
	if player.get("hud"):
		player.get("hud").visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var px := DisplayServer.window_get_size()
	view = OffscreenView.new()
	view.name = "TerrainShotView"
	root.add_child(view)
	view.setup(root, px)
	root.disable_3d = true
	var cam: Camera3D = view.camera
	var rig := current_scene.get_node_or_null("EnvironmentRig")
	if rig and "follow_camera" in rig:
		rig.follow_camera = cam
	if rig and rig.has_method("get_camera_attributes") and rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	await _frames(90)
	var images: Array[Image] = []
	for v: Array in VIEWS:
		if not only.is_empty() and not String(v[0]) in only:
			continue
		var p: Vector3 = v[1]
		var t: Vector3 = v[2]
		cam.fov = v[3]
		cam.global_position = Vector3(p.x, FrontierTerrain.height_at(p.x, p.z) + p.y, p.z)
		cam.look_at(Vector3(t.x, FrontierTerrain.height_at(t.x, t.z) + t.y, t.z))
		await _frames(settle)
		RenderingServer.force_draw(false)
		var img: Image = view.get_texture().get_image()
		var path := out.path_join("%s%s.png" % [prefix, v[0]])
		img.save_png(path)
		print("saved ", path)
		images.append(img)
	if images.size() > 1:
		_sheet(images, out.path_join("%ssheet.png" % prefix))
	print("TERRAIN SHOTS DONE")
	quit()


func _sheet(images: Array[Image], path: String) -> void:
	var w := images[0].get_width() / 2
	var h := images[0].get_height() / 2
	var cols := 4
	var rows := ceili(images.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im := images[i].duplicate() as Image
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(path)
	print("saved ", path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
