extends SceneTree
## Render cost of the dynamic sky and its clouds (cloud engine, 2026-09-26). Windowed; wrap it in a time limit:
##
##   Godot --path . --resolution 1600x900 -s tools/environment/sky/sky_cost.gd -- --no-capture \
##       [reps=2] [weathers=clear,fair,overcast,storm] [hour=15] [shots=<dir>] [poses=fort,open_zenith]
##       [set=cloud_steps:32,cloud_light_steps:3]   (sky material uniforms held at these values)
##
## The same measurement as tools/environment/perf/forest_probe.gd: RenderingServer.force_draw(false) into an
## off-window SubViewport of the window's size (max(CPU render, GPU) per frame, valid with the window covered).
## For each weather (the WeatherSystem forced to it; "now" = whatever the level starts with) and pose it renders
## the level with the dynamic sky and again with the sky shader replaced by an empty one, so
##   SKYCOST <weather> <pose> full=<ms> nosky=<ms> sky=<ms>
## is the whole sky's cost (atmosphere, clouds, stars, radiance cubemap). Other Godot processes on the machine add
## noise; the full / nosky pairs are rendered back to back so the difference is robust. Ends with SKY COST DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const DRAWS := 15

## [name, camera xz, eye height above ground, look target (world) or direction (flag)].
const POSES := [
	["open_horizon", Vector3(3.0, 1.7, -130.0), Vector3(0.3, 0.12, -1.0), true],
	["open_zenith", Vector3(3.0, 1.7, -130.0), Vector3(0.2, 1.4, -1.0), true],
	["fort", Vector3(0.9, 2.2, 9.5), Vector3(0.0, 1.6, -40.0), false],
	["forest_in", Vector3(-58.0, 1.7, -62.0), Vector3(-22.0, 4.0, -18.0), false],
]

var args := {}
var view: SubViewport
var rig: Node
var level: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var reps := int(args.get("reps", "2"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode_sleep_usec = 0
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	level = current_scene
	var player: Node = level.get_node("Player")
	player.set("ignore_mouse_capture", true)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = player.get("hud")
	if hud:
		hud.visible = false
	rig = level.get_node("EnvironmentRig")
	var dn: Node = rig.get("clock_driver")
	if dn and dn.get("clock"):
		dn.clock.running = false
		dn.clock.set_time(float(args.get("hour", "15")))
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.disable_3d = true
	if "follow_camera" in rig:
		rig.follow_camera = view.camera
	var grass := level.get_node_or_null("Terrain/Grass")
	if grass and "follow" in grass:
		grass.set("follow", view.camera)
	await _frames(60)
	var env: Environment = rig.get_environment()
	var sky_mat := env.sky.sky_material as ShaderMaterial
	var sky_shader: Shader = sky_mat.shader
	var empty := Shader.new()
	empty.code = "shader_type sky;\nvoid sky() { COLOR = vec3(0.05, 0.06, 0.08); }\n"
	var weathers: PackedStringArray = String(args.get("weathers", "now")).split(",", false)
	var pose_filter: PackedStringArray = String(args.get("poses", "")).split(",", false)
	var sets := {}
	for kv in String(args.get("set", "")).split(",", false):
		sets[kv.get_slice(":", 0)] = float(kv.get_slice(":", 1))
	var totals := {}
	for rep in reps:
		for w in weathers:
			_force_weather(dn, w)
			await _frames(30)
			for key in sets:
				var v: float = sets[key]
				sky_mat.set_shader_parameter(StringName(key), int(v) if key.ends_with("steps") else v)
				if key == "cloud_steps" and dn.get("field"):
					dn.field.cloud_steps = int(v)   # DayNight uploads the field's step count every frame
			for p: Array in POSES:
				if not pose_filter.is_empty() and not String(p[0]) in pose_filter:
					continue
				_place(p)
				sky_mat.shader = sky_shader
				await _frames(12)
				var full := _cost()
				if args.has("shots") and rep == 0:
					DirAccess.make_dir_recursive_absolute(String(args["shots"]))
					view.get_texture().get_image().save_png(String(args["shots"]).path_join("cost_%s_%s.png" % [w, p[0]]))
				sky_mat.shader = empty
				await _frames(12)
				var nosky := _cost()
				sky_mat.shader = sky_shader
				print("SKYCOST rep%d %-9s %-13s full=%6.2f nosky=%6.2f sky=%5.2f" % [rep, w, p[0], full, nosky, full - nosky])
				var k := "%s %s" % [w, p[0]]
				if not totals.has(k):
					totals[k] = [0.0, 0.0, 0]
				totals[k][0] += full
				totals[k][1] += nosky
				totals[k][2] += 1
	for k: String in totals:
		var t: Array = totals[k]
		print("SKYCOST mean %-24s full=%6.2f nosky=%6.2f sky=%5.2f  (fps %.1f vs %.1f)" % [k, t[0] / t[2], t[1] / t[2],
				(t[0] - t[1]) / t[2], 1000.0 * t[2] / t[0], 1000.0 * t[2] / t[1]])
	print("SKY COST DONE")
	quit()


## Forces the weather when the level has a WeatherSystem (the cloud engine); "now" keeps it.
func _force_weather(dn: Node, w: String) -> void:
	if w == "now" or dn == null:
		return
	if dn.has_method("force_weather"):
		dn.force_weather(w)
		dn.call("_apply", 0.0)


func _place(p: Array) -> void:
	var pos: Vector3 = p[1]
	var ground := FrontierTerrain.height_at(pos.x, pos.z)
	var eye := Vector3(pos.x, ground + pos.y, pos.z)
	var target: Vector3 = p[2]
	if p[3]:
		target = eye + target
	elif target.y < 10.0:
		target.y += FrontierTerrain.height_at(target.x, target.z)
	view.camera.global_position = eye
	view.camera.look_at(target)
	view.camera.fov = 70.0


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
