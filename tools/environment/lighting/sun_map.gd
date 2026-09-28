extends SceneTree
## Top-down view of the fort and the range head in the level's own lighting, to see where the sun
## reaches the ground at the default time of day (look-dev spec 2.1 rules 1-2 and 3.2). Windowed:
##
##   Godot --path . --resolution 1280x720 -s tools/environment/lighting/sun_map.gd -- out=<png> \
##       [scene=res://...tscn] [size=90] [center=0,-10]
##
## Renders an orthographic camera looking straight down (north up) over `size` metres around
## `center` (x, z) with the level's sky, sun, shadows and post (auto exposure off, HUD hidden),
## saves it, renders it again with the sun's shadows off and saves the ratio as
## <out>_shadow.png (white = full sun). Prints how many ground probes are sunlit (ratio > 0.7):
## the fort floor (1 m grid, |x|, |z| <= 15, buildings included), the spawn patch, the firing
## line and the ground beside each dummy. Needs the center/size to include the points (the
## defaults cover the fort and the range to the 120 m dummy only with size >= 300).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	OS.low_processor_usage_mode_sleep_usec = 0
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file(String(args.get("scene", "res://scenes/main.tscn")))
	await process_frame
	await process_frame
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	if player.hud:
		player.hud.visible = false
	var size := float(args.get("size", "90"))
	var c := String(args.get("center", "0,-10")).split(",")
	var center := Vector3(float(c[0]), 0.0, float(c[1]))
	var view := OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(720, 720))
	root.disable_3d = true
	var rig := current_scene.get_node_or_null("EnvironmentRig")
	if rig and rig.has_method("get_camera_attributes") and rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_enabled = false
	var cam: Camera3D = view.camera
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	cam.far = 400.0
	cam.global_position = center + Vector3(0, 150, 0)
	cam.look_at(center, Vector3.FORWARD)
	for i in 150:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
	RenderingServer.force_draw(false)
	var img := view.get_texture().get_image()
	var out: String = args.get("out", "user://sun_map.png")
	img.save_png(out)
	print("saved ", out)
	# The same view with the sun's shadows off: the per-pixel ratio is the sun's shadow factor
	# (albedo, ambient and fog cancel out), so "sunlit" does not depend on the materials.
	var sun: DirectionalLight3D = rig.get_sun() if rig and rig.has_method("get_sun") else null
	if sun == null:
		quit()
		return
	sun.shadow_enabled = false
	for i in 60:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
	RenderingServer.force_draw(false)
	var noshadow := view.get_texture().get_image()
	var px_per_m := 720.0 / size
	var mask := Image.create(720, 720, false, Image.FORMAT_RGB8)
	for y in 720:
		for x in 720:
			mask.set_pixel(x, y, Color.WHITE * clampf(_ratio(img, noshadow, Vector2i(x, y)), 0.0, 1.0))
	mask.save_png(out.get_basename() + "_shadow.png")
	var groups := {
		"fort_floor": [], "spawn": [], "firing_line": [], "dummies": [],
	}
	for z in range(-15, 16):
		for x in range(-15, 16):
			groups.fort_floor.append(Vector2(x, z))
	for z in range(4, 9):
		for x in range(-2, 3):
			groups.spawn.append(Vector2(x, z))
	for x in range(-4, 5):
		groups.firing_line.append(Vector2(x, -20.6))
	for d in [Vector2(-2.5, -30), Vector2(0, -45), Vector2(2.5, -70), Vector2(-2.5, -95), Vector2(0, -120), Vector2(2.5, -140)]:
		groups.dummies.append(d + Vector2(0.6, 0.4))     # Ground just beside the post.
	var line := "SUNMAP"
	for g in groups:
		var lit := 0
		var n := 0
		for w: Vector2 in groups[g]:
			var p := Vector2i(int(360 + (w.x - center.x) * px_per_m), int(360 + (w.y - center.z) * px_per_m))
			if p.x < 0 or p.y < 0 or p.x >= 720 or p.y >= 720:
				continue
			n += 1
			if _ratio(img, noshadow, p) > 0.7:
				lit += 1
		line += "  %s %d/%d sunlit" % [g, lit, n]
	print(line)
	quit()


## Brightness with shadows / without, at pixel p (1 = full sun, ~0.3 = in shadow).
func _ratio(a: Image, b: Image, p: Vector2i) -> float:
	var la := a.get_pixelv(p).srgb_to_linear().get_luminance()
	var lb := b.get_pixelv(p).srgb_to_linear().get_luminance()
	return la / maxf(lb, 1e-4)
