extends SceneTree
## A/B render cost of each lighting feature (package A). Windowed; wrap it in a time limit:
##
##   Godot --path . --resolution 1600x900 -s tools/environment/lighting/feature_costs.gd -- \
##       [quality=high] [scene=res://...tscn] [reps=2] [only=REF,no_sdfgi,...]
##
## Loads the level, then for every variant toggles one thing on the live EnvironmentRig (or the
## viewport / RenderingServer), lets it settle and measures the uncapped cost of a frame at three
## poses (fort gameplay view, range look-back, forest) the same way benchmark.gd does:
## RenderingServer.force_draw(false) into an off-window SubViewport of the window's size, so the
## numbers are max(CPU render, GPU) per frame and valid even when the window is covered.
## Prints "FEAT rep<k> <variant> fort= lookback= forest= avg= delta_vs_REF=" lines.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const POSES := [
	["fort", Vector3(0.9, 2.2, 9.5), Vector3(0.0, 1.6, -40.0)],
	["lookback", Vector3(3.0, 1.7, -130.0), Vector3(0.0, 3.0, -16.0)],
	["forest", Vector3(-55.0, 1.7, -55.0), Vector3(-20.0, 3.0, -15.0)],
]
const DRAWS := 20

var args := {}
var view: SubViewport
var rig: Node
var env: Environment
var sun: DirectionalLight3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var reps := int(args.get("reps", "2"))
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
	rig = current_scene.get_node("EnvironmentRig")
	env = rig.get_environment()
	sun = rig.get_sun()
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.disable_3d = true
	if "follow_camera" in rig:
		rig.follow_camera = view.camera
	await _frames(120)

	var variants := _variants()
	var ref := 0.0
	for rep in reps:
		for v: Array in variants:
			var vname: String = v[0]
			if not only.is_empty() and not vname in only and vname != "REF":
				continue
			var undo: Callable = (v[1] as Callable).call()
			await _frames(30)
			var ms := []
			for p: Array in POSES:
				view.camera.global_position = p[1]
				view.camera.look_at(p[2])
				await _frames(12)
				ms.append(_cost())
			var avg: float = (ms[0] + ms[1] + ms[2]) / 3.0
			if vname == "REF":
				ref = avg
			print("FEAT rep%d %-16s fort=%6.2f lookback=%6.2f forest=%6.2f avg=%6.2f delta_vs_REF=%+.2f" % [
					rep, vname, ms[0], ms[1], ms[2], avg, avg - ref])
			if undo.is_valid():
				undo.call()
			await _frames(10)
	print("FEATURE COSTS DONE")
	quit()


func _cost() -> float:
	for k in 5:
		RenderingServer.force_draw(false)
	var t := Time.get_ticks_usec()
	for k in DRAWS:
		RenderingServer.force_draw(false)
	return (Time.get_ticks_usec() - t) / 1000.0 / DRAWS


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)


## [name, Callable that applies the variant and returns a Callable that undoes it].
func _variants() -> Array:
	var sky: Sky = env.sky
	return [
		["REF", func() -> Callable: return Callable()],
		["no_sdfgi", func() -> Callable:
			env.sdfgi_enabled = false
			return func() -> void: env.sdfgi_enabled = true],
		["no_volfog", func() -> Callable:
			env.volumetric_fog_enabled = false
			return func() -> void: env.volumetric_fog_enabled = true],
		["no_pcss", func() -> Callable:
			var a := sun.light_angular_distance
			sun.light_angular_distance = 0.0
			return func() -> void: sun.light_angular_distance = a],
		["soft_q1", func() -> Callable:
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
			return func() -> void: RenderingServer.directional_soft_shadow_filter_set_quality(rig.settings.soft_shadow_quality)],
		["no_shadow", func() -> Callable:
			sun.shadow_enabled = false
			return func() -> void: sun.shadow_enabled = true],
		["no_ssao", func() -> Callable:
			env.ssao_enabled = false
			return func() -> void: env.ssao_enabled = true],
		["no_glow", func() -> Callable:
			env.glow_enabled = false
			return func() -> void: env.glow_enabled = true],
		["no_lut", func() -> Callable:
			env.adjustment_enabled = false
			return func() -> void: env.adjustment_enabled = true],
		["no_fog", func() -> Callable:
			env.fog_enabled = false
			return func() -> void: env.fog_enabled = true],
		["no_dust", func() -> Callable:
			var m: Node = rig.get_node_or_null("DustMotes")
			if m:
				m.visible = false
			return func() -> void:
				if m:
					m.visible = true],
		["no_ae", func() -> Callable:
			var ca: CameraAttributesPractical = rig.get_camera_attributes()
			ca.auto_exposure_enabled = false
			return func() -> void: ca.auto_exposure_enabled = true],
		["sky_bg_color", func() -> Callable:
			env.background_mode = Environment.BG_COLOR
			return func() -> void: env.background_mode = Environment.BG_SKY],
		["sky_realtime", func() -> Callable:
			sky.process_mode = Sky.PROCESS_MODE_REALTIME
			return func() -> void: sky.process_mode = Sky.PROCESS_MODE_QUALITY],
		["no_taa", func() -> Callable:
			view.use_taa = false
			return func() -> void: view.use_taa = true],
		["atlas2048", func() -> Callable:
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			return func() -> void: RenderingServer.directional_shadow_atlas_set_size(rig.settings.shadow_atlas_size, true)],
	]
