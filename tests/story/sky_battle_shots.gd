extends SceneTree
## The sky battle (SkyBattle) seen from the raiders' camp at night, beat by beat: each beat shot wide (the player's
## field of view) and through a long lens on the fight, the battle held still for the two frames; saved one by one and
## as a contact sheet (wide | long lens, a row a beat). Needs a window.
##   Godot --path . --resolution 1280x720 -s tests/story/sky_battle_shots.gd -- out=<dir> [speed=3] [hour=21] [doy=316]
##        [year=1757] (the scene's own night by default: 12 Nov 1757, 21 h, after m.tf.march's survive_until; the wide
##        shot at the player's FOV, FrontierPlayer.fov 52.5; the battle's sky mark the giant as it stands then)
##        [wonder=1] (wonder=1: the sky tears from tear_point and the wonder sky opens, SkyTear.begin over tear=<s> of
##        the battle's clock (default StorySlice.TEAR_S), held small until the cutter lands, its hits flashing the sky
##        (sky_flash -> SkyTear.flash), as the story wires it; without SkyTear, EnvironmentRig.reveal_wonder; after the
##        battle two more beats: the tear spreading, the sky open)

const CAMP := Vector3(835.0, 0.0, -265.0)
const CRASH := Vector3(1100.0, 0.0, -380.0)
const WIDE_FOV := 52.5
const LONG_FOV := 16.0

var args := {}
var out := ""
var sb: SkyBattle
var cam: Camera3D
var rig: Node
var beats: Array = []           ## [name, battle clock or -1, signal-relative: [signal, seconds after]]
var shots: Array[Image] = []
var names: Array[String] = []
var at_sig := {}
var tear: Node
var tear_secs := 32.0
const TEAR_SCRIPT := "res://scripts/world/env/sky_tear.gd"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = args.get("out", "user://sky_battle_shots")
	DirAccess.make_dir_recursive_absolute(out)
	OS.low_processor_usage_mode_sleep_usec = 0
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	var camp := CAMP
	camp.y = FrontierTerrain.height_at(camp.x, camp.z)
	player.global_position = camp + Vector3(0, 1.0, 6.0)    # (the land streams in round the player)
	player.set_physics_process(false)
	player.set_process_input(false)
	if player.hud:
		player.hud.visible = false
	rig = current_scene.get_node_or_null("EnvironmentRig")
	if rig and rig.clock_driver:
		var clock = rig.clock_driver.get("clock")
		if clock:
			clock.set_date(float(args.get("doy", "316")), int(args.get("year", "1757")))
			clock.set_time(float(args.get("hour", "21")))
		if rig.clock_driver.has_method("force_weather"):
			rig.clock_driver.force_weather("clear")
	cam = Camera3D.new()
	cam.fov = WIDE_FOV
	cam.far = 6000.0
	current_scene.add_child(cam)
	cam.make_current()
	cam.global_position = camp + Vector3.UP * 1.7
	if rig:
		rig.follow_camera = cam
		if rig.get_camera_attributes():
			rig.get_camera_attributes().auto_exposure_speed = 30.0
	await _frames(150)
	var spd := float(args.get("speed", "3"))
	var crash := CRASH
	crash.y = FrontierTerrain.height_at(crash.x, crash.z)
	sb = SkyBattle.begin(current_scene, camp, crash, {"heading": deg_to_rad(150.0), "speed": spd,
			"sky_mark": WonderLook.giant_dir(rig as EnvironmentRig)})
	for s: String in ["opened_fire", "cutter_hit", "hunter_gone"]:
		sb.connect(s, _mark.bind(s))
	var wonder: bool = args.get("wonder", "1") == "1" and rig != null
	var tear_s: Script = load(TEAR_SCRIPT) if ResourceLoader.exists(TEAR_SCRIPT) else null
	tear_secs = float(args.get("tear", str(StorySlice.TEAR_S))) / spd
	sb.tear_point.connect(func(d: Vector3) -> void:
		_mark("tear_point")
		if wonder and tear_s:
			tear = tear_s.call("begin", rig, d, tear_secs, -1.0, true)   # (held while the cutter falls, as the story has it)
		elif wonder and rig.has_method("reveal_wonder"):
			rig.reveal_wonder(20.0 / spd))
	if wonder and tear_s:
		sb.sky_flash.connect(func(a: float, d: Vector3) -> void: tear_s.call("flash", rig, a, d))
	sb.cutter_falling.connect(func(wf: WreckFall) -> void:
		_mark("cutter_falling")
		if wf:
			wf.landed.connect(func() -> void:
				_mark("landed")
				if tear != null and is_instance_valid(tear):
					tear.call("release")))
	# the beats: [name, after which signal (or "" from the start), seconds of battle clock after it]
	beats = [["1_chase", "", 4.5], ["2_circling", "", 13.0], ["3_volley", "", 20.0], ["4_sky_struck", "tear_point", 0.45],
			["5_struck", "cutter_hit", 1.6], ["6_falling", "cutter_falling", 5.0], ["7_down", "landed", 0.6],
			["8_hunter_climbs", "landed", 2.6]]
	var bi := 0
	var t0 := 0.0
	while bi < beats.size() and is_instance_valid(sb):
		await process_frame
		var b: Array = beats[bi]
		var sig := String(b[1])
		if sig != "" and not at_sig.has(sig):
			continue
		var due := float(b[2]) + (float(at_sig[sig]) if sig != "" else 0.0)
		if sb.clock < due:
			continue
		await _shoot(String(b[0]))
		bi += 1
	# the sky after the battle (real time: the tear runs on its own clock)
	if tear != null and is_instance_valid(tear):
		var look := sb.tear_at if is_instance_valid(sb) else Vector3.ZERO
		if look == Vector3.ZERO:
			look = cam.global_position + Vector3(0.6, 0.6, -0.5) * 500.0
		for b: Array in [["9_tear_spreading", 0.6], ["10_sky_open", 1.02]]:
			var waited := 0
			while float(tear.get("amount")) < float(b[1]) and bool(tear.get("running")) and waited < 3000:
				await process_frame
				waited += 1
			await _shoot(String(b[0]), look)
	_sheet()
	print("SKY BATTLE SHOTS DONE")
	quit()


func _mark(s: String) -> void:
	at_sig[s] = sb.clock if is_instance_valid(sb) else 0.0


## Two frames of the battle held still: wide toward the fight (or `at`), and through the long lens on it.
func _shoot(nm: String, at := Vector3.ZERO) -> void:
	var live := is_instance_valid(sb)
	var focus := at if at != Vector3.ZERO or not live else sb.focus()
	if live:
		sb.process_mode = Node.PROCESS_MODE_DISABLED
	var wf := WreckFall.find(self)
	if wf:
		wf.process_mode = Node.PROCESS_MODE_DISABLED
	for fov: float in [WIDE_FOV, LONG_FOV]:
		cam.fov = fov
		var d := focus - cam.global_position
		var flat := Vector3(d.x, 0.0, d.z).normalized()
		var e := atan2(d.y, Vector2(d.x, d.z).length()) * (0.62 if fov == WIDE_FOV else 1.0)   # (wide: the land in frame too)
		cam.look_at(cam.global_position + flat * cos(e) + Vector3.UP * sin(e))
		await _frames(3)
		RenderingServer.force_draw(false)
		var img := root.get_texture().get_image()
		shots.append(img)
		var path := out.path_join("%s_%s.png" % [nm, "wide" if fov == WIDE_FOV else "long"])
		img.save_png(path)
		print("saved ", path, "  (clock %.1f, focus %s, %d shots in flight, tear %.2f)" % [sb.clock if live else -1.0,
				str(focus.round()), sb.shot_nodes() / 2 if live else 0, float(tear.get("amount")) if tear else 0.0])
	names.append(nm)
	if live:
		sb.process_mode = Node.PROCESS_MODE_INHERIT
	if wf and is_instance_valid(wf):
		wf.process_mode = Node.PROCESS_MODE_INHERIT


## Every beat a row: wide on the left, the long lens on the right, at half size.
func _sheet() -> void:
	if shots.is_empty():
		return
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var rows := shots.size() / 2
	var sheet := Image.create(w * 2, h * rows, false, shots[0].get_format())
	for i in shots.size():
		var im := shots[i].duplicate() as Image
		im.resize(w, h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	var path := out.path_join("sky_battle_sheet.png")
	sheet.save_png(path)
	print("saved ", path, " rows: ", names)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
