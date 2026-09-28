extends SceneTree
## Auto-exposure calibration and drift check (look-dev spec 4.5 and 2.3, package A). Windowed:
##
##   Godot --path . --resolution 1280x720 -s tools/environment/lighting/calibrate_exposure.gd -- \
##       [quality=high|medium] [scene=res://...tscn] [mode=calibrate|verify] [views=a,b,..]
##
## Godot's auto exposure multiplies the exposure by auto_exposure_scale / L, where L is the frame's
## mean HDR luminance clamped to the [min, max] sensitivity bounds (x 0.00125). L itself cannot be
## read back, so for each scenic view this tool renders the converged auto-exposed frame, then
## searches the fixed exposure (auto exposure off) that gives the same image, which yields the
## effective auto-exposure factor f and, with wide bounds (mode=calibrate), the view's L.
##
## mode=calibrate  wide bounds; prints L per view and the constants that put every outdoor gameplay
##                 view (spawn_play, spawn_gate, firing_line, parade) at the base exposure:
##                 scale = max bound = min L of those views, min bound = that / 2^0.7.
## mode=verify     the rig's own bounds; prints f in EV per view and the spawn_play / firing_line
##                 drift (spec 2.3: <= 0.15 EV). Ends with EXPOSURE CHECK PASSED / FAILED.
## Auto-exposure speed is raised while measuring so each view converges in a few frames.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const SCENIC := preload("res://tools/environment/scenic_shots.gd")
const OUTDOOR := ["spawn_play", "spawn_gate", "firing_line", "parade"]

var args := {}
var view: SubViewport
var env: Environment
var attrs: CameraAttributesPractical


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var mode: String = args.get("mode", "verify")
	var only: PackedStringArray = String(args.get("views", "")).split(",", false)
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.switch_weapon("musket")
	player.yaw = 0.0
	player.pitch = 0.0
	if player.hud:
		player.hud.visible = false
	var rig := current_scene.get_node("EnvironmentRig")
	env = rig.get_environment()
	attrs = rig.get_camera_attributes()
	if attrs == null or not attrs.auto_exposure_enabled:
		print("EXPOSURE auto exposure is off for this preset: nothing to calibrate")
		print("EXPOSURE CHECK PASSED")
		quit()
		return
	var base := env.tonemap_exposure
	var scale := attrs.auto_exposure_scale
	var min_s := attrs.auto_exposure_min_sensitivity
	var max_s := attrs.auto_exposure_max_sensitivity
	print("EXPOSURE rig: base %.3f scale %.4f bounds L %.4f..%.4f (sensitivity %.1f..%.1f)" % [base, scale, min_s * 0.00125, max_s * 0.00125, min_s, max_s])
	if mode == "calibrate":
		attrs.auto_exposure_min_sensitivity = 0.01
		attrs.auto_exposure_max_sensitivity = 1e6
	attrs.auto_exposure_speed = 30.0

	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(640, 360))
	root.disable_3d = true
	if "follow_camera" in rig:
		rig.follow_camera = view.camera
	await _frames(120)

	var results := {}
	for v: Array in SCENIC.VIEWS:
		var vname: String = v[0]
		if not only.is_empty() and not vname in only:
			continue
		if vname == "spawn_play":
			view.source = player.camera
		else:
			view.source = null
			view.camera.fov = v[3]
			view.camera.global_position = v[1]
			view.camera.look_at(v[2])
		attrs.auto_exposure_enabled = true
		await _frames(45)
		var target := _mean()
		attrs.auto_exposure_enabled = false
		# Fixed exposure giving the same image (monotonic): bisection in log2 space.
		var lo := -4.0
		var hi := 4.0
		for i in 14:
			var mid := (lo + hi) * 0.5
			env.tonemap_exposure = base * pow(2.0, mid)
			await _frames(3)
			if _mean() < target:
				lo = mid
			else:
				hi = mid
		env.tonemap_exposure = base
		var ev := (lo + hi) * 0.5
		var lum := scale / pow(2.0, ev)
		results[vname] = {"ev": ev, "L": lum, "mean": target}
		print("EXPOSURE view %-15s f = %+.3f EV  (L = %.4f)  mean %.3f" % [vname, ev, lum, target])
	attrs.auto_exposure_enabled = true

	if mode == "calibrate":
		var lmin := INF
		for k in OUTDOOR:
			if results.has(k):
				lmin = minf(lmin, results[k].L)
		print("EXPOSURE recommend AE_REFERENCE_LUMINANCE = %.4f  (min L over %s); bounds %.4f..%.4f" % [
				lmin, ", ".join(OUTDOOR), lmin * pow(2.0, -0.7), lmin])
		print("EXPOSURE CALIBRATED")
	else:
		var ok := true
		if results.has("spawn_play") and results.has("firing_line"):
			var drift := absf(results.spawn_play.ev - results.firing_line.ev)
			ok = drift <= 0.15
			print("EXPOSURE drift spawn_play / firing_line %.3f EV (<= 0.15)" % drift)
		for k in OUTDOOR:
			if results.has(k) and absf(results[k].ev) > 0.15:
				print("EXPOSURE note: outdoor view %s is %+.2f EV off the base" % [k, results[k].ev])
		print("EXPOSURE CHECK PASSED" if ok else "EXPOSURE CHECK FAILED")
	quit()


func _mean() -> float:
	RenderingServer.force_draw(false)
	var img := view.get_texture().get_image()
	img.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var s := 0.0
	for y in 90:
		for x in 160:
			var c := img.get_pixel(x, y)
			s += c.r + c.g + c.b
	return s / (160.0 * 90.0 * 3.0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
