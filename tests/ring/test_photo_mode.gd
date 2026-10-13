extends SceneTree
## Round 4 VIRAL: photo mode (PhotoMode; data/ring/replay.json "photo") in the % ring (rules stock; earth against a water
## bot, held), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_photo_mode.gd -- mode=ring element=earth foe=water
##   enter   the tree held, the HUD and the ring's screens hidden, its own camera current where the player's camera was
##   move    WASD-style moves and Q/E (move()), the mouse's turn (look()) and the wheel's field of view (zoom()) move its
##           camera, never the player's; the match stands still under it
##   take    a PNG appears under user://photos/ (its path printed); the wordmark's toggle is kept (GameSettings)
##   leave   the player's camera current again with its transform and field of view as before, the screens back, the tree
##           going on, the competitors where they were
## Watchdog LIMIT_S; last line "PHOTO MODE PASSED" or "PHOTO MODE FAILED".

const NAME := "PHOTO MODE"
const LIMIT_S := 200.0
const OWN_CFG := "user://photo_mode_test.cfg"

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var mode: RingMode


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	RingReplay.force = "off"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await process_frame
		t += 1.0 / 60.0
	return INF


func _end() -> void:
	RingRules.rule_set_override = ""
	RingReplay.force = ""
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _run() -> void:
	for i in 10:
		await process_frame
	var lvl := current_scene as RingLevel
	player = lvl.player
	player.ignore_mouse_capture = true
	mode = RingMode.find(self)
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and mode.foe != null, 6.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	mode.foe.held = true
	RingReplay.install(mode)
	var pm := PhotoMode.find(self)
	_expect(pm != null and PhotoMode.row_text() != "", "photo mode installed, its Esc row \"%s\"" % PhotoMode.row_text())
	for i in 30:
		await physics_frame
	var cam0 := player.camera.global_transform
	var fov0 := player.camera.fov
	var p0 := player.global_transform
	var f0 := mode.foe.global_transform
	var hud_was := player.hud.visible
	_expect(pm.enter(), "enter")
	var pc := pm.camera()
	_expect(paused and pc != null and get_root().get_viewport().get_camera_3d() == pc and pc.global_transform.is_equal_approx(cam0)
			and not player.hud.visible and hud_was, "the tree held, the HUD hidden, its own camera current where the player's was")
	pm.move(Vector3(0.0, 0.0, -1.0), 0.0, 2.0)
	pm.move(Vector3.ZERO, 1.0, 1.0)
	pm.look(Vector2(120.0, -40.0))
	pm.zoom(-3.0)
	for i in 20:
		await process_frame
	var moved := pc.global_position.distance_to(cam0.origin)
	_expect(moved > 2.0 and not pc.global_basis.is_equal_approx(cam0.basis) and absf(pc.fov - (fov0 - 3.0 * PhotoMode.pnum("fov_step", 3.0))) < 0.01,
			"it flies (%.2f m), turns and zooms (fov %.1f)" % [moved, pc.fov])
	_expect(player.camera.global_transform.is_equal_approx(cam0) and player.global_transform.is_equal_approx(p0)
			and mode.foe.global_transform.is_equal_approx(f0), "the player's camera and the match stand still under it")
	var mark0 := PhotoMode.wordmark_on()
	var path := await pm.take()
	_expect(path != "" and FileAccess.file_exists(path) and path.get_extension() == "png", "take: a PNG appears (%s)" % path)
	var img := Image.load_from_file(path) if path != "" else null
	_expect(img != null and img.get_width() >= 2, "the picture loads (%dx%d)" % [img.get_width() if img else 0, img.get_height() if img else 0])
	var ev := InputEventKey.new()
	ev.physical_keycode = PhotoMode._key("wordmark")
	ev.keycode = ev.physical_keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame
	_expect(PhotoMode.wordmark_on() != mark0, "M toggles the wordmark, kept in the settings")
	PhotoMode.set_wordmark(true)
	pm.leave()
	_expect(not paused and get_root().get_viewport().get_camera_3d() == player.camera and player.camera.global_transform.is_equal_approx(cam0)
			and is_equal_approx(player.camera.fov, fov0) and player.hud.visible and pc.is_queued_for_deletion(),
			"leave: the player's camera current again exactly as it was, the HUD back, the tree going on, its camera let go")
	_expect(player.global_transform.is_equal_approx(p0) and mode.foe.global_transform.is_equal_approx(f0),
			"the competitors where they were")
	await process_frame
	await process_frame
	_expect(not is_instance_valid(pc) and not pm.is_active(), "its camera gone, photo mode off")
	if path != "":
		DirAccess.remove_absolute(path)
	_end()
