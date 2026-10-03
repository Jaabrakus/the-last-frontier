extends SceneTree
## A look at the raid's pieces on screen (scripts/npc fighters, scripts/fire): French marines and Canadian militia come at
## the fort's gate, the valley militia hold it, and the storehouse is set alight; frames from a few cameras as it plays.
## Needs a window.
##   Godot --path . --resolution 1280x720 -s tools/showcase/raid_preview.gd -- out=<dir> [hour=16]

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://raid")
	DirAccess.make_dir_recursive_absolute(out)
	OS.low_processor_usage_mode_sleep_usec = 0
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	player.set_process_input(false)
	if player.hud:
		player.hud.visible = false
	var rig: EnvironmentRig = current_scene.get_node("EnvironmentRig")
	var dn = rig.clock_driver
	dn.clock.running = false
	dn.clock.set_time(float(args.get("hour", "16")))
	dn.force_weather("clear")
	player.global_position = Vector3(-30, FrontierTerrain.height_at(-30, -40) + 1.0, -40)   # out of the fight
	var cam := Camera3D.new()
	cam.fov = 60.0
	current_scene.add_child(cam)
	cam.make_current()
	rig.follow_camera = cam
	if rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	await _frames(30)
	var gate := Vector3(0.0, 0.0, 18.0)
	var raiders := NpcSquad.spawn(current_scene, "french_marine", 4, Vector3(10.0, 0.0, 60.0), {"attack": gate, "tag": "raiders"})
	var canadians := NpcSquad.spawn(current_scene, "canadian_militia", 3, Vector3(-12.0, 0.0, 64.0), {"attack": gate, "tag": "raiders"})
	var militia := NpcSquad.spawn(current_scene, "militia", 4, Vector3(0.0, 0.0, 14.0), {"hold": Vector3(0.0, 0.0, 16.0), "tag": "militia"})
	print("SQUADS ", raiders != null, canadians != null, militia != null)
	var fire := FireSpread.find(self)
	var shots := [
		[2.0, Vector3(14.0, 3.0, 40.0), Vector3(0.0, 1.5, 55.0), "approach"],
		[10.0, Vector3(-16.0, 2.2, 30.0), Vector3(2.0, 1.5, 22.0), "gate"],
		[18.0, Vector3(20.0, 4.0, 34.0), Vector3(0.0, 1.5, 20.0), "fight"],
	]
	var t := 0.0
	for s: Array in shots:
		while t < float(s[0]):
			await process_frame
			t += 1.0 / 60.0
		cam.global_position = Vector3(s[1].x, FrontierTerrain.height_at(s[1].x, s[1].z) + s[1].y, s[1].z)
		cam.look_at(Vector3(s[2].x, FrontierTerrain.height_at(s[2].x, s[2].z) + s[2].y, s[2].z))
		await _frames(2)
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(out.path_join("raid_%s.png" % s[3]))
		print("saved ", s[3], " raiders alive ", raiders.alive_count() + canadians.alive_count(), " militia alive ", militia.alive_count())
	# the storehouse alight
	if fire:
		print("IGNITED ", fire.ignite_area(Vector3(-6.0, 1.0, 6.0), 9.0))
	await _frames(600)
	cam.global_position = Vector3(10.0, FrontierTerrain.height_at(10, 30) + 3.0, 30.0)
	cam.look_at(Vector3(-8.0, 3.0, 8.0))
	await _frames(2)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join("raid_fire.png"))
	dn.clock.set_time(21.0)
	await _frames(240)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join("raid_fire_night.png"))
	print("RAID PREVIEW DONE")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
