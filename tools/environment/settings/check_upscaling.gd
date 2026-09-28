extends SceneTree
## Check for the upscaling graphics setting (scripts/world/settings/). Wrap it in a time limit
## (a script error leaves Godot running):
##
##   Godot --headless --path . -s tools/environment/settings/check_upscaling.gd -- --no-capture [orig=<rig.gd>]
##   Godot --path . --resolution 1600x900 -s tools/environment/settings/check_upscaling.gd -- --no-capture \
##       graphics_panel=1 [level=1] [shots=<dir>] [orig=<rig.gd>]
##
## Headless: argument parsing, the settings file (round trip, other sections kept, tool runs
## skip it), the default (off), fallbacks without a GPU renderer, and that "off" leaves the
## viewport exactly as the quality preset sets it (low / medium / high).
## Windowed, additionally: what this renderer / GPU offers (RenderingDevice features, MetalFX
## scale limits), every mode and level applied to a viewport (scaling mode, scale, TAA), and with
## level=1 the real level: the Graphics panel is installed, F2 opens it, each mode is switched live
## on the window (checked on the root viewport) and back to off; shots=<dir> saves the panel.
##
## orig=<path>: a copy of environment_rig.gd from before the upscaling setting with its
## `class_name` line removed. "off" is then compared property by property against the
## original apply_viewport() for every preset.
##
## Prints "ok" / "FAIL" lines and ends with UPSCALING CHECK PASSED / FAILED (exit 0 / 1).

const Upscaling := preload("res://scripts/world/settings/upscaling.gd")
const GraphicsPanel := preload("res://scripts/world/settings/graphics_panel.gd")

## Viewport properties apply_viewport() touches (and the upscaler may change).
const VP_PROPS := ["msaa_3d", "screen_space_aa", "use_taa", "scaling_3d_mode", "scaling_3d_scale",
		"texture_mipmap_bias", "use_debanding", "anisotropic_filtering_level", "use_occlusion_culling",
		"fsr_sharpness", "mesh_lod_threshold"]

var args := {}
var failures := PackedStringArray()
var headless := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	headless = DisplayServer.get_name() == "headless"
	_check_parsing()
	_check_config()
	_check_defaults()
	_check_off_identity()
	if not headless:
		await _check_availability()
		if args.get("level", "0") == "1":
			await _check_level()
	if failures.is_empty():
		print("UPSCALING CHECK PASSED")
		quit(0)
	else:
		print("UPSCALING CHECK FAILED: ", ", ".join(failures))
		quit(1)


func _ok(name: String, cond: bool, detail := "") -> void:
	print("%s %-34s %s" % ["ok  " if cond else "FAIL", name, detail])
	if not cond:
		failures.append(name)


# --- Pure logic ----------------------------------------------------------------------------

func _check_parsing() -> void:
	var cases := {
		"off": ["off", "quality"], "auto": ["auto", "quality"], "auto,balanced": ["auto", "balanced"],
		"metalfx,performance": ["metalfx", "performance"], "FSR2,Q": ["fsr2", "quality"],
		"fsr:p": ["fsr1", "performance"], "native": ["off", "quality"], "on,b": ["auto", "balanced"],
		"bogus,balanced": ["off", "balanced"], "fsr1,bogus": ["fsr1", "quality"],
	}
	for k: String in cases:
		var got := Upscaling.parse_arg(k)
		_ok("parse upscale=" + k, got[0] == cases[k][0] and got[1] == cases[k][1], "-> %s,%s" % [got[0], got[1]])
	_ok("scales 0.77/0.67/0.5", is_equal_approx(Upscaling.SCALES.quality, 0.77)
			and is_equal_approx(Upscaling.SCALES.balanced, 0.67) and is_equal_approx(Upscaling.SCALES.performance, 0.5))


func _check_config() -> void:
	var saved_path := Upscaling.config_path
	var tmp := "user://upscaling_check_%d.cfg" % Time.get_ticks_usec()
	Upscaling.config_path = tmp
	var other := ConfigFile.new()
	other.set_value("audio", "master_db", -3.0)
	other.save(tmp)
	_ok("config missing section -> {}", Upscaling.load_saved().is_empty())
	var err := Upscaling.save("fsr2", "balanced")
	var back := Upscaling.load_saved()
	var cf := ConfigFile.new()
	cf.load(tmp)
	_ok("config round trip", err == OK and back.get("mode") == "fsr2" and back.get("level") == "balanced", str(back))
	_ok("config keeps other sections", is_equal_approx(float(cf.get_value("audio", "master_db", 0.0)), -3.0))
	# A tool run (this script) skips the saved file; the default stays off.
	var s := WorldSettings.new()
	Upscaling.read_startup(s)
	_ok("tool run ignores settings.cfg", Upscaling.is_tool_run() and s.upscaling == "off" and s.upscaling_source == "default",
			"%s/%s source=%s" % [s.upscaling, s.upscaling_quality, s.upscaling_source])
	# The game's own path (no -s): the saved file is used.
	var g := WorldSettings.new()
	Upscaling.read_startup(g, 1)
	var arg_given := false
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("upscale="):
			arg_given = true
	if not arg_given:
		_ok("game run reads settings.cfg", g.upscaling == "fsr2" and g.upscaling_quality == "balanced" and g.upscaling_source == "settings.cfg",
				"%s/%s source=%s" % [g.upscaling, g.upscaling_quality, g.upscaling_source])
	cf.set_value("graphics", "upscaling", "warp9")
	cf.save(tmp)
	_ok("config bad value -> off", Upscaling.load_saved().get("mode") == "off")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	Upscaling.config_path = saved_path


func _check_defaults() -> void:
	var s := WorldSettings.from_args()
	var arg_given := false
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("upscale="):
			arg_given = true
	if not arg_given:
		_ok("default upscaling off", s.upscaling == "off" and s.upscaling_quality == "quality", "%s/%s" % [s.upscaling, s.upscaling_quality])
	_ok("preset() default off", WorldSettings.preset("high").upscaling == "off")
	if headless:
		for m: String in Upscaling.MODES:
			var r := Upscaling.resolve(m, "balanced")
			_ok("headless %s -> off" % m, r.mode == "off" and is_equal_approx(r.scale, 1.0), r.note)


## "off" must leave the viewport exactly as the preset (and the original code) sets it.
func _check_off_identity() -> void:
	var orig_script: Script = null
	if args.has("orig"):
		orig_script = load(String(args["orig"]))
		_ok("orig rig loaded", orig_script != null, String(args["orig"]))
	for q: String in WorldSettings.QUALITIES:
		var ws := WorldSettings.preset(q)
		ws.upscaling = "off"
		var rig := EnvironmentRig.new()
		rig.settings = ws
		root.add_child(rig)
		var a := _fresh_view()
		rig.apply_viewport(a)
		var got := _props(a)
		# Expected from the preset alone (the original code path).
		var aa := ws.antialiasing
		if aa == "metalfx" and RenderingServer.get_current_rendering_driver_name() != "metal":
			aa = "taa"
		var want_mode := Viewport.SCALING_3D_MODE_METALFX_TEMPORAL if aa == "metalfx" else Viewport.SCALING_3D_MODE_BILINEAR
		_ok("off keeps preset %s" % q, got.use_taa == (aa == "taa") and got.scaling_3d_mode == want_mode
				and is_equal_approx(got.texture_mipmap_bias, -0.3 if aa == "taa" else 0.0), str(got))
		if orig_script:
			var orig: Node = orig_script.new()
			orig.set("settings", WorldSettings.preset(q))
			root.add_child(orig)
			var b := _fresh_view()
			orig.call("apply_viewport", b)
			var ref := _props(b)
			var diffs := PackedStringArray()
			for p: String in VP_PROPS:
				if str(got[p]) != str(ref[p]):
					diffs.append("%s %s!=%s" % [p, got[p], ref[p]])
			_ok("off == original rig (%s)" % q, diffs.is_empty(), "identical (%d props)" % VP_PROPS.size() if diffs.is_empty() else ", ".join(diffs))
			orig.free()
			b.free()
		rig.free()
		a.free()


func _fresh_view() -> SubViewport:
	var v := SubViewport.new()
	v.size = Vector2i(320, 180)
	v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(v)
	return v


func _props(v: Viewport) -> Dictionary:
	var d := {}
	for p: String in VP_PROPS:
		d[p] = v.get(p)
	return d


# --- Windowed ------------------------------------------------------------------------------

func _check_availability() -> void:
	var rd := RenderingServer.get_rendering_device()
	var driver := RenderingServer.get_current_rendering_driver_name()
	var method := RenderingServer.get_current_rendering_method()
	var line := "UPSCALING platform=%s driver=%s method=%s adapter=%s" % [OS.get_name(), driver, method, RenderingServer.get_video_adapter_name()]
	if rd:
		line += " metalfx_temporal=%s metalfx_spatial=%s" % [rd.has_feature(RenderingDevice.SUPPORTS_METALFX_TEMPORAL),
				rd.has_feature(RenderingDevice.SUPPORTS_METALFX_SPATIAL)]
		if rd.has_feature(RenderingDevice.SUPPORTS_METALFX_TEMPORAL):
			line += " metalfx_scale=%.3f-%.3f" % [rd.limit_get(RenderingDevice.LIMIT_METALFX_TEMPORAL_SCALER_MIN_SCALE) / 1e6,
					rd.limit_get(RenderingDevice.LIMIT_METALFX_TEMPORAL_SCALER_MAX_SCALE) / 1e6]
	print(line)
	for m: String in ["metalfx", "fsr2", "fsr1"]:
		var why := Upscaling.unavailable_reason(m)
		print("UPSCALING available %-8s %s" % [m, "yes" if why == "" else "no: " + why])
	var auto := Upscaling.resolve("auto", "quality")
	var want_auto := "off"
	if method == "forward_plus" and rd:
		want_auto = "metalfx" if rd.has_feature(RenderingDevice.SUPPORTS_METALFX_TEMPORAL) else "fsr2"
	_ok("auto picks %s" % want_auto, auto.mode == want_auto, auto.note)
	# Every mode and level on a viewport.
	var ws := WorldSettings.preset("high")
	var rig := EnvironmentRig.new()
	rig.settings = ws
	root.add_child(rig)
	var v := _fresh_view()
	for m: String in Upscaling.MODES:
		for l: String in Upscaling.LEVELS:
			ws.upscaling = m
			ws.upscaling_quality = l
			rig.apply_viewport(v)
			var r := Upscaling.resolve(m, l)
			var want_mode: int = {"off": Viewport.SCALING_3D_MODE_BILINEAR, "metalfx": Viewport.SCALING_3D_MODE_METALFX_TEMPORAL,
					"fsr2": Viewport.SCALING_3D_MODE_FSR2, "fsr1": Viewport.SCALING_3D_MODE_FSR}[r.mode]
			var want_taa: bool = r.mode == "off" or r.mode == "fsr1"
			var want_scale: float = 1.0 if r.mode == "off" else Upscaling.SCALES[l]
			_ok("apply %s/%s" % [m, l], v.scaling_3d_mode == want_mode and is_equal_approx(v.scaling_3d_scale, want_scale)
					and v.use_taa == want_taa, "-> %s scale=%.2f taa=%s %s" % [r.mode, v.scaling_3d_scale, v.use_taa, r.note])
			if m == "off":
				break   # Level does not matter for off.
	# Back to off restores the preset exactly: every property equals a fresh viewport's.
	ws.upscaling = "off"
	rig.apply_viewport(v)
	var fresh := _fresh_view()
	rig.apply_viewport(fresh)
	var d := PackedStringArray()
	for p: String in VP_PROPS:
		if str(v.get(p)) != str(fresh.get(p)):
			d.append("%s %s!=%s" % [p, v.get(p), fresh.get(p)])
	_ok("switch back to off", d.is_empty() and v.use_taa and v.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR,
			"identical to a fresh viewport" if d.is_empty() else ", ".join(d))
	fresh.free()
	for i in 3:
		await process_frame
	rig.free()
	v.free()


func _check_level() -> void:
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_") and action != GraphicsPanel.ACTION:
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var level := current_scene
	var player: Node = level.get_node("Player")
	player.set("ignore_mouse_capture", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rig: EnvironmentRig = level.get_node("EnvironmentRig")
	var panel: Node = rig.get_node_or_null(GraphicsPanel.NODE_NAME)
	_ok("panel installed", panel != null)
	_ok("panel action bound", InputMap.has_action(GraphicsPanel.ACTION) and not InputMap.action_get_events(GraphicsPanel.ACTION).is_empty(),
			str(panel.get("key_label")) if panel else "")
	var clash := PackedStringArray()
	var key := GraphicsPanel.ensure_action()
	for action in InputMap.get_actions():
		if action == GraphicsPanel.ACTION:
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and ((e as InputEventKey).physical_keycode == key or (e as InputEventKey).keycode == key):
				clash.append(action)
	# InputSetup's own table (the bindings were erased above so stray keys cannot move the player).
	for table: Dictionary in [InputSetup.KEYS, InputSetup.DEBUG_KEYS]:
		for action: String in table:
			if key in table[action]:
				clash.append(action)
	_ok("panel key not used by the game", clash.is_empty(), OS.get_keycode_string(key) + (" clashes: " + ", ".join(clash) if not clash.is_empty() else ""))
	var rootvp := root
	_ok("startup is off", rig.upscaling_state.get("mode", "?") == "off" or args.has("upscale"), str(rig.upscaling_state))
	if panel == null:
		return
	# F2 opens it.
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.keycode = key
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	_ok("F2 opens the panel", panel.get("visible") == true)
	# Every mode live on the window, then back to off.
	for m: String in ["auto", "metalfx", "fsr2", "fsr1", "off"]:
		for l: String in (["quality", "balanced", "performance"] if m != "off" else ["quality"]):
			panel.call("set_upscaling", m, l, false)
			for i in 20:
				await process_frame
			var st: Dictionary = rig.upscaling_state
			var want_mode: int = {"off": Viewport.SCALING_3D_MODE_BILINEAR, "metalfx": Viewport.SCALING_3D_MODE_METALFX_TEMPORAL,
					"fsr2": Viewport.SCALING_3D_MODE_FSR2, "fsr1": Viewport.SCALING_3D_MODE_FSR}[st.mode]
			_ok("live %s/%s" % [m, l], rootvp.scaling_3d_mode == want_mode and is_equal_approx(rootvp.scaling_3d_scale, st.scale),
					"-> %s %.2f fps=%d" % [st.mode, rootvp.scaling_3d_scale, Engine.get_frames_per_second()])
			if args.has("shots") and l == "balanced" and m == "auto":
				await _shot(String(args["shots"]), "panel_auto_balanced")
	_ok("live back to off", rootvp.use_taa and rootvp.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR
			and is_equal_approx(rootvp.scaling_3d_scale, 1.0) and is_equal_approx(rootvp.texture_mipmap_bias, -0.3))
	if args.has("shots"):
		await _shot(String(args["shots"]), "panel_off")
	panel.call("set_open", false)
	await process_frame
	_ok("panel closes", panel.get("visible") == false)


func _shot(dir: String, name: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 30:
		await process_frame
	RenderingServer.force_draw(false)
	var img := root.get_texture().get_image()
	var path := dir.path_join(name + ".png")
	img.save_png(path)
	print("saved ", path)
