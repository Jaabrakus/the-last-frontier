extends SceneTree
## Captures of the dynamic sky and the cloud engine (2026-09-26). Windowed; wrap it in a time limit:
##
##   Godot --path . --resolution 1280x720 -s tools/environment/sky/sky_shots.gd -- --no-capture out=<dir> \
##       [weathers=clear,fair,overcast,storm,storm_near,storm_here] [hours=15] [views=sun,away,up,upwind,ground]
##       [seq=storm] [seq_shots=10] [seq_step_h=0.3] [date=237] [settle=40] [height=1.7] [repeat=1]
##
## Per weather, hour and view it saves <out>/<weather>_h<hour>_<view>.png and prints the weather (SHOT lines).
## Views (from the open range, 130 m north of the fort, camera `height` m up, 1.7 by default; 60: over the trees): sun (toward the sun, 10 deg up), away
## (opposite, 12 deg up), up (60 deg up, toward the sun's side), upwind (where the fronts come from, 6 deg up),
## ground (away from the sun, 4 deg down: the light on the ground). seq=storm: a front forced on the upwind horizon,
## then seq_shots captures looking upwind with the clock advanced seq_step_h game hours between them (the storm
## coming in, arriving, passing; the clock stays at the hour so only the weather changes). The GPU / CPU mirror of the
## clouds is checked (calibrated: linear tonemap, sky only) by tests/env/weather_mirror_check.gd. Ends with SKY SHOTS
## DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const EYE := Vector3(3.0, 1.7, -130.0)

var args := {}
var view: SubViewport
var level: Node
var dn: Node
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = String(args.get("out", "user://sky_shots"))
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	level = current_scene
	var player: Node3D = level.get_node("Player")
	player.set("ignore_mouse_capture", true)
	player.global_position = Vector3(EYE.x, FrontierTerrain.height_at(EYE.x, EYE.z) + 0.1, EYE.z)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	var hud = player.get("hud")
	if hud:
		hud.visible = false
	var rig: Node = level.get_node("EnvironmentRig")
	dn = rig.get("clock_driver")
	if dn == null:
		print("SKY SHOTS: no DayNight (headless?)")
		quit(1)
		return
	dn.clock.running = false
	if args.has("date"):
		dn.clock.set_date(float(args["date"]))
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	root.disable_3d = true
	rig.follow_camera = view.camera
	view.camera.current = true
	var grass := level.get_node_or_null("Terrain/Grass")
	if grass and "follow" in grass:
		grass.set("follow", view.camera)
	await _frames(30)
	var settle := int(args.get("settle", "40"))
	var hours: PackedStringArray = String(args.get("hours", "15")).split(",", false)
	var views: PackedStringArray = String(args.get("views", "sun,away,up,upwind,ground")).split(",", false)
	if args.get("seq", "") == "storm":
		await _storm_sequence(float(hours[0]), settle)
	else:
		for w in String(args.get("weathers", "fair")).split(",", false):
			for h in hours:
				dn.clock.set_time(float(h))
				await _frames(2)
				dn.force_weather(w)
				await _frames(settle)
				print("SHOT %s h%s %s sun_tr=%.2f sun_energy=%.2f" % [w, h, dn.weather.describe(), dn._key_tr, dn.sun.light_energy])
				for r in int(args.get("repeat", "1")):
					for v in views:
						_aim(v)
						await _frames(settle / 2)
						var tag := "%s_h%s_%s" % [w, h, v] + ("_%02d" % r if r > 0 else "")
						_save(tag)
						print("  %s sun_tr=%.2f sun_energy=%.2f" % [tag, dn._key_tr, dn.sun.light_energy])
				if args.get("flash", "0") == "1":
					await _flash_shot(w, h)
	print("SKY SHOTS DONE")
	quit()


func _storm_sequence(hour: float, settle: int) -> void:
	dn.clock.set_time(hour)
	await _frames(2)
	dn.force_weather("storm")
	await _frames(settle)
	var n := int(args.get("seq_shots", "10"))
	var step := float(args.get("seq_step_h", "0.3"))
	for i in n:
		_aim("upwind")
		await _frames(settle / 2)
		print("SEQ %02d t=+%.2fh %s sun_tr=%.2f sun_energy=%.2f" % [i, i * step, dn.weather.describe(), dn._key_tr, dn.sun.light_energy])
		_save("storm_seq_%02d" % i)
		if args.get("seq_views", "") != "":
			for v in String(args["seq_views"]).split(",", false):
				_aim(v)
				await _frames(settle / 2)
				_save("storm_seq_%02d_%s" % [i, v])
		# the weather moves on, the clock stays (the light does not change along the sequence)
		dn.weather.update(0.0, step, view.camera.global_position, hour, WorldClock.month_of(dn.clock.day_of_year))
		await _frames(4)


## flash=1: a lightning stroke flash_km (12) upwind held on the sky (the weather frozen): the channel below the base, the
## flash inside the tower, the sky lit. <weather>_h<hour>_flash.png next to <weather>_h<hour>_noflash.png.
func _flash_shot(w: String, h: String) -> void:
	_aim("upwind")
	await _frames(20)
	_save("%s_h%s_noflash" % [w, h])
	dn.set_process(false)
	var up_h: Vector2 = -(dn.weather.wind_to() as Vector2)
	var cam: Vector3 = view.camera.global_position
	var at := Vector2(cam.x, cam.z) + up_h * float(args.get("flash_km", "12")) * 1000.0 + Vector2(-up_h.y, up_h.x) * 2500.0
	dn.sky_mat.set_shader_parameter(&"flash", Vector4(at.x, 4500.0, at.y, 5.0))
	dn.sky_mat.set_shader_parameter(&"bolt", Vector4(at.x, at.y, 17.0, 2.5))
	dn.sky_mat.set_shader_parameter(&"lightning", 0.3)
	await _frames(3)
	_save("%s_h%s_flash" % [w, h])
	dn.set_process(true)


func _aim(v: String) -> void:
	var eye := Vector3(EYE.x, FrontierTerrain.height_at(EYE.x, EYE.z) + float(args.get("height", EYE.y)), EYE.z)
	var cam: Camera3D = view.camera
	cam.global_position = eye
	cam.fov = 70.0
	var sd: Vector3 = dn.clock.sun_direction()
	var sun_h := Vector2(sd.x, sd.z).normalized()
	var up_h: Vector2 = -(dn.weather.wind_to() as Vector2)
	var dir := Vector3.FORWARD
	match v:
		"sun":
			dir = Vector3(sun_h.x, 0.0, sun_h.y) * cos(deg_to_rad(10.0)) + Vector3.UP * sin(deg_to_rad(10.0))
		"away":
			dir = Vector3(-sun_h.x, 0.0, -sun_h.y) * cos(deg_to_rad(12.0)) + Vector3.UP * sin(deg_to_rad(12.0))
		"up":
			dir = Vector3(sun_h.x, 0.0, sun_h.y) * cos(deg_to_rad(60.0)) + Vector3.UP * sin(deg_to_rad(60.0))
		"zenith":
			dir = Vector3(0.05, 1.0, 0.0)
		"upwind":
			dir = Vector3(up_h.x, 0.0, up_h.y) * cos(deg_to_rad(6.0)) + Vector3.UP * sin(deg_to_rad(6.0))
		"downwind":
			dir = Vector3(-up_h.x, 0.0, -up_h.y) * cos(deg_to_rad(8.0)) + Vector3.UP * sin(deg_to_rad(8.0))
		"ground":
			dir = Vector3(-sun_h.x, 0.0, -sun_h.y) * cos(deg_to_rad(-4.0)) + Vector3.UP * sin(deg_to_rad(-4.0))
		"north":
			var n: Vector3 = WorldClock.enu_to_world(Vector3(0, 1, 0))
			dir = n * cos(deg_to_rad(43.0)) + Vector3.UP * sin(deg_to_rad(43.0))
	cam.look_at(eye + dir.normalized())


func _save(name: String) -> void:
	var img: Image = view.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
