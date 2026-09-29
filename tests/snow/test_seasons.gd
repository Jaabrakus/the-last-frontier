extends SceneTree
## The broadleaves' year in the real level (SeasonLeaves, leaf_season.gdshaderinc): the season value through the
## calendar, the first lasting snow stripping the last leaves (and a thaw not bringing them back), the woods under the
## bare crowns opening to the sky in winter (canopy_leaves, CanopyMap), and (shots=<dir>) the same two views of the
## woods in each season (by the gate and over the hills): late summer, the turning, autumn colour, the fall, winter bare
## under snow, spring's buds, summer again.
##
##   Godot --path . -s tests/snow/test_seasons.gd -- --no-creator survival=on [shots=<dir>]
var failures := PackedStringArray()

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

func _initialize() -> void:
	# the calendar alone
	_ok(SeasonLeaves.at_day(22.0) == 0.0, "August: green (0)")
	_ok(absf(SeasonLeaves.at_day(28.0) - 1.0) < 0.01, "mid October: full colour (1)")
	_ok(SeasonLeaves.at_day(30.0) > 1.2 and SeasonLeaves.at_day(30.0) < 1.8, "early November: falling")
	_ok(SeasonLeaves.at_day(4.0) == 2.0, "February: bare (2)")
	_ok(SeasonLeaves.at_day(11.0) > 2.3 and SeasonLeaves.at_day(11.0) < 2.8, "late April: budding")
	_ok(SeasonLeaves.at_day(18.0) == 0.0, "late June: full leaf (0)")
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	await _frames(120)
	var snow := SnowCover.find(self)
	var core := SurvivalBridge.find(self).core
	player.hud.visible = false
	var dn := get_first_node_in_group(&"weather")
	dn.call(&"force_weather", "clear")
	# a view over the fort's gate to the woods to the north
	player.global_position = Vector3(0.0, 0.2, 2.0)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.current = true
	cam.fov = 55.0
	cam.far = 4000.0
	var y := SurvivalClock.year(core)
	var canopy := preload("res://scripts/world/vegetation/canopy_map.gd")
	var summer_cover := _mean_cover(canopy)
	# the first lasting snow strips the last leaves; a thaw does not put them back
	core.state.minutes = SurvivalClock.minutes_at(core, "nov_early", y, 11.0)
	core.state.weather["snow_depth_cm"] = 0.0
	await _frames(3)
	var before := snow.season.value
	core.state.weather["snow_depth_cm"] = 12.0
	await _frames(3)
	var after := snow.season.value
	core.state.weather["snow_depth_cm"] = 0.0
	await _frames(3)
	_ok(before > 1.1 and before < 1.8 and after >= 1.99, "November's first lasting snow strips the trees (%.2f -> %.2f)" % [before, after])
	_ok(snow.season.value >= 1.99, "and the thaw after does not put the leaves back (%.2f)" % snow.season.value)
	for step: Array in [["sep_early", "1_late_summer"], ["sep_late", "2_turning"], ["oct_mid", "3_autumn"], ["nov_early", "4_falling"],
			["jan_mid", "5_winter"], ["apr_late", "6_spring"], ["jun_late", "7_summer"]]:
		var m := SurvivalClock.minutes_at(core, String(step[0]), y + (1 if String(step[0]) in ["jan_mid", "apr_late", "jun_late"] else 0), 11.0)
		core.state.minutes = m
		if String(step[0]) == "jan_mid":
			core.state.weather["snow_depth_cm"] = SurvivalWeather.normal_snow_depth(core)
		else:
			core.state.weather["snow_depth_cm"] = 0.0
		snow.season.stripped = 0.0
		dn.call(&"force_weather", "clear")
		cam.look_at_from_position(Vector3(-6.0, 6.5, -12.0), Vector3(-30.0, 4.0, -60.0), Vector3.UP)
		await _secs(4.0)
		print("   %s: leaf_season %.2f, canopy_leaves %.2f, snow %.2f" % [SurvivalClock.date_string(core), snow.season.value,
				snow.season.leaves, snow.cover])
		await _shot(String(step[1]))
		cam.look_at_from_position(Vector3(0.0, 40.0, 20.0), Vector3(-80.0, 0.0, -400.0), Vector3.UP)
		await _secs(1.5)
		await _shot(String(step[1]) + "_hills")
		if String(step[0]) == "jan_mid":
			var winter_cover := _mean_cover(canopy)
			_ok(snow.season.leaves < 0.3, "winter: the broadleaves' crowns are off the canopy (canopy_leaves %.2f)" % snow.season.leaves)
			_ok(winter_cover < summer_cover * 0.85, "the woods open to the sky under the bare trees (cover %.2f in summer, %.2f now)" % [summer_cover, winter_cover])
	_ok(snow.season.value == 0.0, "back in summer, the leaves are green")
	print("SEASONS ", "PASSED" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)


## The canopy's mean sky cover over the woods round the fort (a 300 m square, every 6 m).
func _mean_cover(canopy: GDScript) -> float:
	var sum := 0.0
	var n := 0
	for i in 50:
		for j in 50:
			sum += canopy.cover_at(-150.0 + i * 6.0, -150.0 + j * 6.0)
			n += 1
	return sum / n
