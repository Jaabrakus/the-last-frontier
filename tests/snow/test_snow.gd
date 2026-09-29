extends SceneTree
## Snow in the real level (scripts/snow): the test key's snowing January morning, the cover on the ground (the shader
## globals), the falling snow in place of the rain, the prints the player presses and their filling in, the footsteps'
## crunch, the shelter under the cabin's roof, the clear day after, the land's snow by region (the wind-swept plains
## east of the fort against the woods: scoured and drifted, the player's own depth to the core) and the river's ice,
## and back again.
##
##   Godot --path . -s tests/snow/test_snow.gd -- --no-creator survival=on [shots=<dir>]
##
## Windowed (the shaders compile and draw); shots=<dir> saves pictures.
var failures := PackedStringArray()
var player: FrontierPlayer
var snow: SnowCover

func _ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: failures.append(what)

func _frames(n: int) -> void:
	for i in n: await process_frame

func _secs(s: float) -> void:
	await create_timer(s).timeout

func _dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("shots="):
			return a.get_slice("=", 1)
	return ""

func _shot(name: String) -> void:
	if _dir() == "" or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir().path_join(name + ".png"))

func _walk(dir: Vector3, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	var key := KEY_W
	player.yaw = atan2(-dir.x, -dir.z)
	Input.action_press(&"move_forward")
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		await process_frame
	Input.action_release(&"move_forward")
	await _frames(10)

func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	await _frames(120)
	snow = SnowCover.find(self)
	var b := SurvivalBridge.find(self)
	_ok(snow != null and b != null and b.core != null, "the snow and the survival core are in the level")
	if snow == null or b == null or b.core == null:
		print("SNOW FAILED")
		quit(1)
		return
	var core := b.core
	print("   start: ", SurvivalClock.date_string(core), "  depth ", SurvivalWeather.snow_depth_cm(core), " cm")
	_ok(snow.cover == 0.0, "September: no snow on the ground")
	await _secs(1.0)
	_ok(snow.sheltered(Vector3(-8.0, 0.5, 6.0)), "the cabin's floor is under its roof (the shelter map)")
	_ok(not snow.sheltered(Vector3(0.0, 0.1, 6.0)), "the parade ground is open to the sky")
	# the test key: a snowing January morning
	print("   ", snow.test_cycle())
	await _secs(6.0)
	print("   now: ", SurvivalClock.date_string(core), "  depth ", snapped(SurvivalWeather.snow_depth_cm(core), 0.1), " cm  precip '",
			SurvivalWeather.precip(core), "'  air ", snapped(SurvivalClock.air_temp_c(core), 0.1), " C")
	_ok(SurvivalWeather.precip(core) == "snow", "January, the sky's drizzle falls as snow (the core)")
	_ok(snow.cover > 0.8, "the ground is white (snow_cover %.2f)" % snow.cover)
	_ok(snow.falling > 0.2 and snow.fall._p.emitting, "the snow falls round the camera (%.2f)" % snow.falling)
	var wfx: WeatherFx = null
	for c in get_first_node_in_group(&"weather").get_children():
		if c is WeatherFx: wfx = c
	_ok(wfx != null and wfx.snow_mix == 1.0 and not wfx._rain.emitting, "the rain streaks give way to the snow")
	await _shot("snow_falling")
	# prints
	player.global_position = Vector3(0.0, 0.2, 14.0)
	await _frames(20)
	var n0 := snow.prints.stamped
	await _walk(Vector3(1, 0, 0), 3.0)
	var n1 := snow.prints.stamped
	print("   prints pressed walking 3 s: ", n1 - n0)
	_ok(n1 - n0 >= 3, "walking the snow leaves prints")
	var last: Dictionary = snow.prints.records[-1]
	var p := snow.prints.pressed_at(Vector2(float(last.x), float(last.z)))
	_ok(p > 0.9, "a fresh print is pressed down (%.2f)" % p)
	_ok(not snow.prints.prints_near(player.global_position, 5.0, ["boot"]).is_empty(), "the prints are kept for tracking (prints_near)")
	_ok(player.get_node("Footsteps").surface() == "snow", "the footsteps crunch in the snow")
	_ok(Sfx.has(&"step_snow_walk") and Sfx.has(&"land_snow"), "the snow's footstep sounds are in the game")
	_ok(player.survival_speed_mult < 0.6, "38 cm of snow slows walking (x%.2f)" % player.survival_speed_mult)
	await _shot("snow_prints")
	# filling in: more snow falls on the prints
	snow.total_units += 70.0
	await _frames(3)
	_ok(snow.prints.pressed_at(Vector2(float(last.x), float(last.z))) == 0.0, "7 cm of new snow fills a print in")
	snow.total_units -= 70.0
	# the clear day
	print("   ", snow.test_cycle())
	await _secs(6.0)
	_ok(SurvivalWeather.precip(core) == "" and snow.cover > 0.8, "a clear winter day: no snowfall, the snow lying")
	await _shot("snow_clear")
	player.yaw = PI
	player.pitch = -0.2
	await _secs(1.0)
	await _shot("snow_fort")
	# the land: the open plains (the square east of the fort) against the deep woods west of the fort
	var woods := _depths(Vector2(-200.0, 150.0), 60.0)
	var plains := _depths(Vector2(640.0, 60.0), 160.0)
	print("   woods: mean %.2f m (min %.2f max %.2f); plains: mean %.2f m (min %.2f max %.2f)" % [woods[0], woods[1], woods[2],
			plains[0], plains[1], plains[2]])
	_ok(plains[0] < woods[0], "the wind-swept plains hold less snow than the woods")
	_ok(plains[1] < snow.depth_m * 0.5 and plains[2] > snow.depth_m * 1.15, "the plains are scoured thin in places and drifted deep in others")
	_ok(woods[2] - woods[1] < plains[2] - plains[1], "the woods' snow lies more evenly than the plains'")
	player.global_position = Vector3(640.0, FrontierTerrain.height_at(640.0, 60.0) + 0.1, 60.0)
	await _frames(10)
	var here := SurvivalUtil.num(core.state.context.get("snow_here_cm"), -1.0)
	_ok(absf(here - snow.depth_at(player.global_position) * 100.0) < 2.5, "the core knows the snow where the player stands (%.0f cm)" % here)
	_ok(snow.ice_m > 1.0, "January: the river is frozen over its slow water (ice over %.2f m of water)" % snow.ice_m)
	player.hud.visible = false
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.current = true
	cam.fov = 60.0
	cam.far = 3000.0
	var gy := FrontierTerrain.height_at(600.0, 40.0)
	cam.look_at_from_position(Vector3(600.0, gy + 2.2, 40.0), Vector3(720.0, gy - 2.0, -40.0), Vector3.UP)
	await _secs(2.0)
	await _shot("snow_plains")
	cam.look_at_from_position(Vector3(560.0, gy + 30.0, 140.0), Vector3(760.0, gy - 10.0, -60.0), Vector3.UP)
	await _secs(2.0)
	await _shot("snow_plains_high")
	var rz := 120.0
	var rx := WorldRiver.x_at(rz)
	var ry := WorldRiver.level_at(rz)
	cam.look_at_from_position(Vector3(rx - 26.0, ry + 7.0, rz + 18.0), Vector3(rx, ry, rz - 25.0), Vector3.UP)
	await _secs(2.0)
	await _shot("snow_river")
	cam.queue_free()
	player.hud.visible = true
	player.global_position = Vector3(0.0, 0.2, 14.0)
	await _frames(5)
	# back
	print("   ", snow.test_cycle())
	await _secs(8.0)
	_ok(SurvivalClock.day_id(core).begins_with("sep") and snow.cover < 0.05, "back to September: the snow gone (%.2f)" % snow.cover)
	print("SNOW ", "PASSED" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)


## The snow's depth (m) over a square round `c` of half side `half`, every 8 m: [mean, min, max].
func _depths(c: Vector2, half: float) -> Array:
	var sum := 0.0
	var lo := INF
	var hi := 0.0
	var n := 0
	var x := c.x - half
	while x <= c.x + half:
		var z := c.y - half
		while z <= c.y + half:
			var d := snow.depth_at(Vector3(x, FrontierTerrain.height_at(x, z) + 0.05, z))
			sum += d
			lo = minf(lo, d)
			hi = maxf(hi, d)
			n += 1
			z += 8.0
		x += 8.0
	return [sum / maxf(n, 1), lo, hi]
