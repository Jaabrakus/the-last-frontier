extends SceneTree
## Scenic look-dev screenshots of the Frontier level from fixed viewpoints. Needs a window
## (not --headless). Wrap it in a time limit, because a script error leaves the window open.
##
##   Godot --path . --resolution 1280x720 -s tools/environment/scenic_shots.gd -- --no-capture \
##       out=<dir> [prefix=<tag>_] [only=spawn_play,spawn_gate,...] [settle=90] [size=1280x720]
##       [quality=low|medium|high] [scene=res://...tscn]
##
## Saves <out>/<prefix><view>.png for every view in VIEWS and a 4x2 contact sheet
## <out>/<prefix>sheet.png (each view at half resolution). No HUD. `settle` is the number of
## frames rendered before each capture (TAA, auto exposure, SDFGI and volumetric fog need
## time to converge; the first view also waits 120 extra frames). `quality=` is read by the
## level (WorldSettings). `scene=` loads another level scene with the same node names (default
## res://scenes/main.tscn; package A's frozen testbed is
## res://tools/environment/lighting/testbed/testbed.tscn). Frames are rendered into an off-window SubViewport (see
## offscreen_view.gd), so the shots come out the same whether or not the window is visible,
## and every game action is unbound so stray key presses cannot move the player.
##
## The viewpoints stay fixed so before/after images compare 1:1. Cameras near the ground are
## lifted to stay 1.6 m above the terrain (see _place).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

## [name, camera position, look-at target, fov]. "spawn_play" is the gameplay camera.
const VIEWS := [
	["spawn_play", Vector3.ZERO, Vector3.ZERO, 70.0],
	["spawn_gate", Vector3(1.4, 1.7, 4.0), Vector3(0.0, 1.4, -45.0), 60.0],
	["firing_line", Vector3(-1.2, 1.7, -18.5), Vector3(0.0, 1.2, -110.0), 55.0],
	["range_lookback", Vector3(5.0, 1.7, -118.0), Vector3(0.0, 2.8, -16.0), 50.0],
	["walkway", Vector3(9.0, 5.0, -12.6), Vector3(-12.0, 1.0, -75.0), 65.0],
	["forest", Vector3(-58.0, 1.7, -62.0), Vector3(-22.0, 4.0, -18.0), 65.0],
	["parade", Vector3(7.0, 1.7, 11.0), Vector3(-8.0, 2.4, 3.0), 65.0],
	["aerial", Vector3(48.0, 30.0, 48.0), Vector3(0.0, 0.0, -22.0), 55.0],
]

var args := {}
var view: SubViewport


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://scenic")
	var prefix: String = args.get("prefix", "")
	var settle := int(args.get("settle", "90"))
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	DirAccess.make_dir_recursive_absolute(out)

	# A hidden window makes the main loop sleep 6.9 ms per frame (OS.add_frame_delay): off.
	OS.low_processor_usage_mode_sleep_usec = 0
	_block_user_input()
	change_scene_to_file(String(args.get("scene", "res://scenes/main.tscn")))
	await process_frame
	await process_frame
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_release_all()
	player.switch_weapon("musket")
	player.yaw = 0.0
	player.pitch = 0.0
	if player.hud:
		player.hud.visible = false

	var px := DisplayServer.window_get_size()   # --resolution; read after the first frames.
	if args.has("size"):
		px = Vector2i(int(String(args["size"]).get_slice("x", 0)), int(String(args["size"]).get_slice("x", 1)))
	view = OffscreenView.new()
	view.name = "ScenicView"
	root.add_child(view)
	view.setup(root, px)
	root.disable_3d = true                # Only the off-window view renders 3D.
	var cam: Camera3D = view.camera
	var rig := current_scene.get_node_or_null("EnvironmentRig")
	if rig and "follow_camera" in rig:
		rig.follow_camera = cam         # Dust motes stay around the capture camera.
	if rig and rig.has_method("get_camera_attributes") and rig.get_camera_attributes():
		# Auto exposure converges in a few frames, so every view shows its settled exposure no
		# matter which view came before (in game it adapts over ~2 s).
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	await _frames(120)

	var images: Array[Image] = []
	for v: Array in VIEWS:
		if not only.is_empty() and not String(v[0]) in only:
			continue
		if v[0] == "spawn_play":
			view.source = player.camera
		else:
			view.source = null
			cam.fov = v[3]
			_place(cam, v[1], v[2], player)
		await _frames(settle)
		view.sync_camera()
		RenderingServer.force_draw(false)
		var img: Image = view.get_texture().get_image()
		var path := out.path_join("%s%s.png" % [prefix, v[0]])
		img.save_png(path)
		print("saved ", path)
		images.append(img)
	if images.size() > 1:
		_sheet(images, out.path_join("%ssheet.png" % prefix))
	print("SCENIC SHOTS DONE")
	quit()


## Terrain may rise outside the flat zones: a camera below 10 m is kept at least 1.6 m
## above the collider under it, and its target is lifted by the same amount.
func _place(cam: Camera3D, p: Vector3, target: Vector3, player: Node3D) -> void:
	if p.y < 10.0:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 60.0)
		q.exclude = [(player as CollisionObject3D).get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit and p.y - hit.position.y < 1.6 and hit.position.y < p.y + 8.0:   # Not a tree top.
			var lift: float = hit.position.y + 1.6 - p.y
			p.y += lift
			target.y += lift
	cam.global_position = p
	cam.look_at(target)


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


## Runs n game frames. When the OS does not let the window draw (covered, other Space), the
## main loop skips rendering, so the frame is drawn explicitly (the SubViewport always renders).
func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)


## The window opens on the user's screen and takes keyboard focus for a moment: every game
## action is unbound before the level loads (InputSetup.ensure() first, so the player's own
## call adds nothing later), so stray key presses or clicks cannot move the player or fire.
## Input.action_press() (scripted input) still works without bindings.
func _block_user_input() -> void:
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	_release_all()


func _release_all() -> void:
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			Input.action_release(action)
