extends SceneTree
## A fish fought on the rod, filmed from the game's own camera with its HUD (FishingGear, FishFightGauge; user
## 2026-09-28: the rod "where it can bend the pole", "a stamia gauge", "the user uses the mouse to pull the tension",
## "i want the user to be able to walk or move when fishing", "the user will pull the tip of the rod closer to them"):
## on the river's bank east of the fort, crouched, the rod out in both hands, the overhead cast and the float drifting,
## a hungry fish coming to the worm, the strike (standing), the fight (pulled too hard for a moment early on, the line
## coming tight, then the rod drawn back while the line is easy and lowered as it comes tight, the angler stepping back
## up the bank with it at a walk once it tires), and the tired fish landed. Windowed, fixed rate:
##
##   Godot --path . --resolution 1280x720 --fixed-fps 30 -s tools/fishing/fish_fight_film.gd -- out=<abs dir> \
##       [fish=brook_trout] [lb=1.4] [hour=9.5] [view=mix|game] survival=on survival_seed=7
##   view=mix (the default): the game's camera for the cast and the landing, a camera beside the angler for the fight
##   (the rod's bend, the line's tension dots, the HUD's gauge over it); game: the game's camera throughout
##   <dir>/frames/f00000.jpg ...; then: video_encode encode <dir>/frames 30 <film.mp4> (tools/showcase/video_encode.swift)
## Ends with FISH FIGHT FILM DONE (the frames, the fight's time, the most tension, and whether it was landed).
## The player is Actor_B animation data; the rod's poses and the cast's swings are the project's own clips
## (Frontier_Own.res).

var out := ""
var species := "brook_trout"
var lb := 1.4
var hour := 9.5
var view := "mix"
var side_cam: Camera3D
var p: FrontierPlayer
var g: FishingGear
var life: FishLife
var frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var k := a.get_slice("=", 0)
		var v := a.substr(a.find("=") + 1)
		match k:
			"out": out = v
			"fish": species = v
			"lb": lb = float(v)
			"hour": hour = float(v)
			"view": view = v
	InputSetup.ensure()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


## The camera beside the angler at the water's edge, over the bank's grass, the rod and the water before him in the
## picture.
func _side(on: bool) -> void:
	if view != "mix":
		return
	if side_cam == null:
		side_cam = Camera3D.new()
		side_cam.fov = 58.0
		current_scene.add_child(side_cam)
	if on:
		var b := p.global_basis
		var me := p.global_position
		side_cam.global_position = me + b.x * 6.8 - b.z * 1.2 + Vector3.UP * 2.2
		side_cam.look_at(me - b.z * 2.2 + Vector3.UP * 2.0, Vector3.UP)
		side_cam.current = true
	else:
		side_cam.current = false
		p.camera.current = true


func _shoot(n := 1) -> void:
	for i in n:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(out.path_join("frames/f%05d.jpg" % frame), 0.92)
		frame += 1


func _run() -> void:
	for i in 5:
		await process_frame
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in root.find_children("*", "CharacterCreator", true, false):
		c.queue_free()
	paused = false
	var rig := current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(hour)
	if rig and rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	life = FishLife.find(self)
	g = FishingGear.find(p)
	life.restock_on = false
	life.hour_override = 19.0
	life.month_override = 6
	for f in life.fish:
		f.gone = true
	life._sweep()
	# on the bank, the water to the west (-X), as tests/fishing/test_fishing.gd stands
	var z := -140.0
	var cx := WorldRiver.x_at(z)
	var o := 0.0
	while life.depth(cx + o + 0.25, z) > 0.0 and o < 14.0:
		o += 0.25
	var ex := cx + o
	var at := Vector3(ex + 1.2, 0.0, z)
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	p.global_position = at
	p.rotation.y = atan2(1.0, 0.0)
	p.yaw = p.rotation.y
	p.pitch = deg_to_rad(-14.0)
	# crouched on the bank, as an angler keeps low (a trout sees one standing this near and bolts)
	p.set_crouched(true)
	for i in 200:
		await process_frame
	g.give("fishing_rod")
	var ok := g.take_out("fishing_rod")
	for i in 10:
		await process_frame
	if not ok or g.gear != "fishing_rod":
		print("FISH FIGHT FILM FAILED: the rod is not out (take_out %s, gear '%s', hands free %s, switching %s, weapon %s)" % [
				ok, g.gear, p.hands_free, p.is_switching(), p.weapon_key])
		quit(1)
		return
	await _shoot(45)
	# the overhead cast, out a little upstream
	var landed := []
	g.cast_landed.connect(func(pos, wet): landed.append(wet))
	g.cast_override = "W"
	g.aim_override = Vector3(ex - 4.0, 0.0, z - 1.5)
	g.fire_override = 1
	await _shoot(27)
	g.fire_override = 0
	var t := 0
	while landed.is_empty() and t < 150:
		await _shoot()
		t += 1
	await _shoot(30)
	# a hungry fish a little below the float, facing up into the current
	var fz := g.float_pos.z + WorldRiver.flow_at(g.float_pos.z).z * 2.2
	var fx := g.float_pos.x + WorldRiver.flow_at(g.float_pos.z).x * 2.2
	var fish := life.spawn_fish(species, Vector3(fx, 0.0, fz))
	fish.lb = lb
	fish.pos.y = life.layer_y(fish, fx, fz)
	fish.lie = fish.pos
	fish.goal = fish.pos
	fish.state = FishLife.State.HOLD
	fish.base = FishLife.State.HOLD
	fish.hunger = 1.0
	t = 0
	while g.rod_state != FishingGear.Rod.BITE and t < 450 and g.bait != null:
		await _shoot()
		t += 1
	await _shoot(6)
	g.fire_override = 1
	await _shoot(3)
	g.fire_override = 0
	p.set_crouched(false)
	_side(true)
	var got := []
	var broke := []
	g.fish_landed.connect(func(info): got.append(info))
	g.line_broke.connect(func(): broke.append(true))
	var most := 0.0
	t = 0
	var walking := false
	var back_t := 0
	var hard := true
	while got.is_empty() and broke.is_empty() and t < 1500 and g.rod_state in [FishingGear.Rod.FIGHT, FishingGear.Rod.LAND]:
		if g.rod_state == FishingGear.Rod.FIGHT:
			# as one watching the line would: drawn back while it is easy, lowered as it comes tight; early on, pulled
			# too hard for a moment (the line going red), then given
			if hard and (g.tension > 0.97 or t > 75):
				hard = false
			if hard and t > 20:
				g.pull_by(1.4 / 30.0)
			else:
				g.pull_by((0.45 if g.tension < 0.5 else (-1.4 if g.tension > 0.78 else 0.0)) / 30.0)
			most = maxf(most, g.tension)
			# once it tires, a few steps back up the bank at a walk, the line and the fish coming along
			var want: bool = float(fish.stamina) < 0.45 and back_t < 75
			if want:
				back_t += 1
			if want != walking:
				walking = want
				if want:
					Input.action_press(&"walk")
					Input.action_press(&"move_back")
				else:
					Input.action_release(&"move_back")
					Input.action_release(&"walk")
		elif walking:
			walking = false
			Input.action_release(&"move_back")
			Input.action_release(&"walk")
		await _shoot()
		t += 1
	Input.action_release(&"move_back")
	Input.action_release(&"walk")
	_side(false)
	await _shoot(45)
	print("FISH FIGHT FILM DONE frames=%d fight=%.1fs most_tension=%.2f landed=%s broke=%s" % [
			frame, t / 30.0, most, not got.is_empty(), not broke.is_empty()])
	quit()
