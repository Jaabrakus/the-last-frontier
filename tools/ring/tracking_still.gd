extends SceneTree
## The tracking meter for the owner's eye (2026-10-12: "geiser wind prison and column should be tracking meters"): the Lives ring,
## earth against a held fire bot 9 m off, the Column readied and its aim held, the player's own view. Windowed (never on top):
##   Godot --path . --resolution 1280x720 -s tools/ring/tracking_still.gd -- out=<dir>
## Writes tracking_off.png (the crosshair beside him: the meter filling dim, no lock), tracking_half.png (a second lock, beside
## him for its first 20%, then on him: bright what filled on him), tracking_full.png (full, 80% on him: locked, whitened) and
## tracking_sheet.png (the three round the crosshair, close). Ends with TRACKING STILL DONE.

const OWN_CFG := "user://tracking_still.cfg"

var out := ""
var p: FrontierPlayer
var c: SwayCaster
var mode: RingMode
var shots: Array[Image] = []
var look_off := false
var pitch_sign := 1.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	SwayCaster.free_override = true
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.light = "noon"
	MatchSetup.round_s = 600.0
	RingRules.rule_set_override = "stock"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _secs(s: float) -> void:
	for i in int(round(s * Engine.physics_ticks_per_second)):
		await physics_frame


func _aim() -> void:
	var foe: Node3D = mode.foe if mode != null else null
	if foe == null or not is_instance_valid(foe) or p.camera == null:
		return
	var right := (foe.global_position - p.global_position).cross(Vector3.UP).normalized()
	var at := NpcSenses.chest_of(foe) + (right * 3.0 if look_off else Vector3.ZERO)
	var d := (at - p.camera.global_position).normalized()
	p.yaw = atan2(-d.x, -d.z)
	p.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign


func _grab() -> Image:
	for i in 3:
		RenderingServer.force_draw(true)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _save(name: String) -> void:
	var img := await _grab()
	img.save_png(out.path_join(name + ".png"))
	shots.append(img)
	print("  wrote %s.png" % name)


func _run() -> void:
	for i in 20:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	if p == null or mode == null:
		print("TRACKING STILL DONE (no ring)")
		quit(1)
		return
	p.ignore_mouse_capture = true
	c = SwayCaster.of(p)
	while mode.phase != "FIGHT":
		await process_frame
	mode.foe.held = true
	await _secs(3.5)
	var foe := mode.foe
	var ar := mode.ring
	foe.global_position = ar.center() + ar.axis() * 4.5
	p.global_position = ar.center() - ar.axis() * 4.5
	p.pitch = 0.3
	await _secs(0.1)
	pitch_sign = 1.0 if (-p.camera.global_basis.z).y > 0.0 else -1.0
	physics_frame.connect(_aim)
	await _secs(0.4)
	p.hotbar.ready_move(1, "earth_shove", "column")
	await _secs(0.2)
	look_off = true
	c.held_override = true
	while c.fill < 0.6:
		await physics_frame
	await _save("tracking_off")
	c.held_override = false
	while c.state != SwayCaster.State.IDLE:
		await physics_frame
	await _secs(1.5)
	for w in get_nodes_in_group(FormRaised.GROUP):
		(w as Node).queue_free()
	p.hotbar.ready_move(1, "earth_shove", "column")
	await _secs(0.2)
	c.held_override = true
	while c.fill < 0.2:
		await physics_frame
	look_off = false
	while c.fill < 0.6:
		await physics_frame
	await _save("tracking_half")
	while c.state != SwayCaster.State.FULL:
		await physics_frame
	await _secs(0.1)
	await _save("tracking_full")
	c.held_override = false
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var r := Rect2i(w / 2 - 180, h / 2 - 120, 360, 240)
	var sheet := Image.create(r.size.x * 3, r.size.y, false, Image.FORMAT_RGB8)
	for i in shots.size():
		sheet.blit_rect(shots[i], r, Vector2i(r.size.x * i, 0))
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	sheet.save_png(out.path_join("tracking_sheet.png"))
	print("TRACKING STILL DONE")
	quit(0)
