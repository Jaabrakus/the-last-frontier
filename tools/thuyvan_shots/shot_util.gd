extends RefCounted
## Shared by the greybox's shot tools (tools/thuyvan_shots/: mood_frames.gd, still_vs_running.gd, frame_probe.gd): the
## preview level loaded for a camera, the one camera at the still reach, the clock and the weather held, a frame saved,
## images laid side by side. Every tool needs a window (not --headless) and runs under the lock:
##   zsh PLAN/bin/godot_run.sh --path <lane> --resolution 1600x900 -s tools/thuyvan_shots/<tool>.gd -- out=<folder>

const SCENE := "res://scenes/thuyvan_preview.tscn"
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const VIEW_NAME := "ShotView"
## The camera: on the west bank below the reach's lower end and behind S1's rope and watchers (z_to + 14 m, 18 m west of
## the river's centre), a little over eye height, looking up the reach at a point on the water 55 m into it.
const CAM_BACK_M := 14.0
const CAM_SIDE_M := -18.0
const CAM_UP_M := 2.4
const LOOK_INTO_M := 55.0
const SETTLE_FRAMES := 45


## The user args as {key: value} (key=value ones).
static func args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			out[a.trim_prefix("--").get_slice("=", 0)] = a.get_slice("=", 1)
	return out


## The folder the images go to (out=..., default user://thuyvan_shots), made.
static func out_dir() -> String:
	var d := String(args().get("out", "user://thuyvan_shots"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d) if d.begins_with("user://") or d.begins_with("res://") else d)
	return d


## Loads the preview level into `tree` and waits for it: the level (null when it did not load). The player's HUD hidden,
## the clock stopped, nothing of the player's in front of the camera.
static func load_level(tree: SceneTree) -> Node:
	InputSetup.ensure()
	tree.change_scene_to_file(SCENE)
	await tree.process_frame
	await tree.process_frame
	for i in 30:
		await tree.physics_frame
	var lv := tree.current_scene
	if lv == null or not "player" in lv:
		return null
	var p: FrontierPlayer = lv.get("player")
	p.ignore_mouse_capture = true
	if p.hud:
		p.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var c: WorldClock = lv.call("clock")
	if c:
		c.running = false
	return lv


## The one camera at the still reach (added to the level, made current).
static func reach_camera(lv: Node) -> Camera3D:
	var r: Dictionary = WorldRiver.reaches()[0]
	var z := float(r.z_to) + CAM_BACK_M
	var at := Vector3(WorldRiver.x_at(z) + CAM_SIDE_M, 0.0, z)
	at.y = maxf(FrontierTerrain.height_at(at.x, at.z), WorldRiver.level_at(z)) + CAM_UP_M
	var lz := float(r.z_to) - LOOK_INTO_M
	var look := Vector3(WorldRiver.x_at(lz), WorldRiver.level_at(lz) + 0.6, lz)
	var cam := Camera3D.new()
	cam.name = "ShotCamera"
	cam.fov = 58.0
	cam.far = 1500.0
	lv.add_child(cam)
	cam.global_position = at
	cam.look_at(look)
	cam.current = true
	var rig: EnvironmentRig = lv.get("environment_rig")
	if rig:
		rig.follow_camera = cam
	# rendered off the window (OffscreenView: a covered or hidden window would give stale frames), the window mirroring it
	var tree := lv.get_tree()
	var view: SubViewport = OffscreenView.new()
	view.name = VIEW_NAME
	tree.root.add_child(view)
	view.call("setup", tree.root, DisplayServer.window_get_size())
	view.set("source", cam)
	tree.root.disable_3d = true
	return cam


## The hour and the weather held ("clear", "fair", "overcast", "storm_here" ...), then the frames to settle.
static func set_sky(lv: Node, hour: float, weather: String) -> void:
	var c: WorldClock = lv.call("clock")
	if c:
		c.set_time(hour)
	var rig: EnvironmentRig = lv.get("environment_rig")
	if rig and rig.clock_driver and weather != "":
		rig.clock_driver.force_weather(weather)


static func settle(tree: SceneTree, frames := SETTLE_FRAMES) -> void:
	for i in frames:
		await tree.process_frame


## The camera's frame (the off-window view's) as an image, saved as `name`.png in `dir`.
static func grab(tree: SceneTree, dir: String, name: String) -> Image:
	var view := tree.root.get_node_or_null(VIEW_NAME) as SubViewport
	for i in 2:
		RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var img := view.get_texture().get_image() if view else tree.root.get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("SHOT ", dir.path_join(name + ".png"))
	return img


## Images laid out `cols` to a row (each scaled to the first's size), a `gap` px dark gutter between them.
static func sheet(images: Array, cols: int, gap := 8) -> Image:
	var w := (images[0] as Image).get_width()
	var h := (images[0] as Image).get_height()
	var rows := int(ceil(float(images.size()) / float(cols)))
	var out := Image.create(cols * w + (cols - 1) * gap, rows * h + (rows - 1) * gap, false, Image.FORMAT_RGB8)
	out.fill(Color(0.06, 0.06, 0.06))
	for i in images.size():
		var im: Image = (images[i] as Image).duplicate()
		im.convert(Image.FORMAT_RGB8)
		if im.get_width() != w or im.get_height() != h:
			im.resize(w, h, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * (w + gap), (i / cols) * (h + gap)))
	return out
