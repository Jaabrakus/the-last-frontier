extends SceneTree
## Close-up look-dev shots of the fort structures (package D), rendered off-window like
## tools/environment/scenic_shots.gd. Loads the level through preview/preview_hook.gd (since
## 2026-09-25 that is the real level, which builds FrontierStructures, plus the structure
## switches). Needs a window.
##
##   Godot --path . --resolution 1280x720 -s tools/environment/structures/structure_shots.gd -- \
##       --no-capture out=<dir> [prefix=<tag>_] [only=a,b] [settle=60]
##       [structures=hide] [quality=low|medium|high]
##
## Saves <out>/<prefix><view>.png and <out>/<prefix>sheet.png. structures=hide hides the fort
## (the placeholder fort left the level with the integration). The lighting is the level's own.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

## [name, camera position, look-at target, fov]
const VIEWS := [
	["gate_outside", Vector3(4.0, 1.7, -25.0), Vector3(0.0, 2.6, -16.0), 60.0],
	["palisade_close", Vector3(-5.2, 1.5, -18.6), Vector3(-8.5, 2.2, -16.2), 55.0],
	["palisade_tips", Vector3(7.5, 2.6, -19.0), Vector3(7.0, 4.1, -16.0), 45.0],
	["cabin_south", Vector3(-2.5, 1.7, 14.0), Vector3(-7.8, 1.9, 8.5), 60.0],
	["cabin_north", Vector3(-5.2, 1.7, 0.2), Vector3(-9.0, 1.0, 4.2), 60.0],
	["blockhouse_nw", Vector3(-7.0, 1.8, -5.5), Vector3(-15.0, 3.6, -15.0), 60.0],
	["walkway_ramp", Vector3(9.5, 1.7, -6.5), Vector3(14.0, 1.6, -13.5), 60.0],
	["supplies", Vector3(2.8, 1.6, -1.2), Vector3(6.0, 0.6, -5.2), 55.0],
	["storehouse", Vector3(3.5, 1.7, 9.5), Vector3(9.0, 1.4, 4.0), 60.0],
	["dummy_10m", Vector3(-1.3, 1.6, -26.2), Vector3(-2.5, 1.25, -30.0), 45.0],
	["truss", Vector3(-3.2, 1.3, -32.2), Vector3(-5.0, 0.45, -35.0), 55.0],
	["flag", Vector3(-1.5, 6.5, 2.5), Vector3(-5.2, 9.0, -2.0), 45.0],
	["exterior_sw", Vector3(-30.0, 2.2, 26.0), Vector3(-9.0, 3.0, 7.0), 50.0],
	["aerial_fort", Vector3(26.0, 22.0, 30.0), Vector3(0.0, 0.0, 0.0), 50.0],
	["fire_pit", Vector3(6.2, 1.5, 12.8), Vector3(3.8, 0.2, 10.6), 55.0],
	["gate_inside", Vector3(-1.5, 1.8, -6.0), Vector3(0.5, 2.8, -16.0), 65.0],
	["chimney", Vector3(0.5, 2.0, 13.5), Vector3(-4.4, 5.4, 8.0), 50.0],
]

var args := {}
var view: SubViewport


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://structure_shots")
	var prefix: String = args.get("prefix", "")
	var settle := int(args.get("settle", "60"))
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	DirAccess.make_dir_recursive_absolute(out)
	OS.low_processor_usage_mode_sleep_usec = 0
	_block_user_input()
	preload("res://tools/environment/structures/preview/preview_hook.gd").install()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.switch_weapon("musket")
	if player.hud:
		player.hud.visible = false
	# The player stands at the spawn; move it out of the close-ups.
	player.global_position = Vector3(1.5, 0.1, 13.0)
	var px := DisplayServer.window_get_size()
	view = OffscreenView.new()
	view.name = "StructureView"
	root.add_child(view)
	view.setup(root, px)
	root.disable_3d = true
	await _frames(90)
	var images: Array[Image] = []
	for v: Array in VIEWS:
		if not only.is_empty() and not String(v[0]) in only:
			continue
		view.camera.fov = v[3]
		view.camera.global_position = v[1]
		view.camera.look_at(v[2])
		await _frames(settle)
		RenderingServer.force_draw(false)
		var img: Image = view.get_texture().get_image()
		var path := out.path_join("%s%s.png" % [prefix, v[0]])
		img.save_png(path)
		print("saved ", path)
		images.append(img)
	if images.size() > 1:
		_sheet(images, out.path_join("%ssheet.png" % prefix))
	print("STRUCTURE SHOTS DONE")
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


func _block_user_input() -> void:
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			Input.action_release(action)
