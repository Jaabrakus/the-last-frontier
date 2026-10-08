extends "res://tools/showcase/showcase_video.gd"
## A short Tidebreak film using normal matches and the existing expert input model.
## No damage, cooldowns, fighter poses or outcomes are changed. Between excerpts the
## normal match restart selects the next element. The game's camera and HUD stay on.
##
## GODOT_TIMEOUT=900 zsh tools/loop/godot_run.sh --path . --resolution 640x360 \
##   --fixed-fps 60 --write-movie /private/tmp/tidebreak-film/raw.avi \
##   -s tools/ring/gameplay_highlight.gd -- out=/private/tmp/tidebreak-film fps=60 \
##   size=1920x1080 quality=high upscale=off music=on captions=0 readout=0
## Then use tools/showcase/video_audio.py and video_encode.swift (see showcase_video.gd).
## Preview: stills=1 size=1280x720 only=water seconds=8
## fighter_panels=off hides only the two fighter plates; clock, events and bottom HUD remain.

const InputPlayer := preload("res://tools/ring/highlight_input.gd")
const CapturePercentBar := preload("res://tools/ring/capture_percent_bar.gd")
const OWN_CFG := "user://gameplay_highlight.cfg"
var mode: RingMode
var sim: Node
var events: Array = []
var _finish_at := INF
var _timing: FileAccess


func _initialize() -> void:
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._aim_help = "strong"
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "water"
	MatchSetup.foes = ["fire"]
	MatchSetup.difficulty = "normal"
	MatchSetup.light = "noon"
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	args.scene = "res://scenes/ring.tscn"
	args.captions = "0"
	args.readout = "0"
	super._initialize()


func _order() -> Array:
	return ["water", "fire", "earth", "air"]


func _block_user_input() -> void:
	# Keep the real key labels in the HUD; this tool's player has isolated controls.
	InputSetup.ensure()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_title("Video rendering — saved playback at normal speed")
	for action in InputMap.get_actions():
		Input.action_release(action)


func _setup() -> bool:
	_timing = FileAccess.open(out.path_join("timing.jsonl"), FileAccess.WRITE)
	player = level.get_node("Player")
	rig = level.get_node("EnvironmentRig")
	_configure_fighter_panels()
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = ui
	# CanvasLayers remain under the small host Window but draw into the full-size
	# view. Their fonts must not use the host's downscaled rasterization factor.
	root.oversampling_override = 1.0
	cine = Camera3D.new()
	level.add_child(cine)
	view = OffscreenView.new()
	view.name = "TidebreakFilmView"
	root.add_child(view)
	view.setup(root, px)
	view.oversampling_override = 1.0
	view.source = player.camera
	root.disable_3d = true
	_build_overlay()
	for n in root.find_children("*", "CanvasLayer", true, false):
		_redirect(n)
	node_added.connect(_on_node_added)
	driver = Node.new()
	driver.name = "TidebreakFilmCamera"
	driver.process_priority = 100000
	var ds := GDScript.new()
	ds.source_code = "extends Node\nvar tree\nfunc _process(d):\n\ttree.late(d)\n"
	ds.reload()
	driver.set_script(ds)
	driver.set("tree", self)
	root.add_child(driver)
	for i in 1800:
		mode = RingMode.find(self)
		if mode != null and mode.foe != null and mode.phase == "FIGHT" and not level.get_meta("loading_hold", false):
			break
		await _frame()
	if mode == null or mode.foe == null:
		return false
	player.controls = PlayerControls.new(false)
	mode.rules.ko.connect(_film_ko)
	mode.rules.launched.connect(_film_launch)
	return true


func _configure_fighter_panels() -> void:
	if args.get("fighter_panels", "on") != "off":
		return
	var hud: FrontierHUD = player.hud
	assert(hud != null and hud.percent_bar != null, "Capture needs the stock match HUD")
	var old: PercentBar = hud.percent_bar
	var parent := old.get_parent()
	var order := old.get_index()
	var match_owner := old.match_node()
	var saved := {}
	for key: String in ["layout_override", "_pl", "_event", "_event_t", "_pips_had", "_t", "visible"]:
		saved[key] = old.get(key)
	# Free the prior presentation node, disconnecting its RingRules signals. The
	# replacement hooks the same live rules/match and inherits clock/event drawing.
	parent.remove_child(old)
	old.free()
	var bar: PercentBar = CapturePercentBar.new()
	bar.name = "PercentBar"
	bar.player = player
	hud.percent_bar = bar
	parent.add_child(bar)
	parent.move_child(bar, order)
	if match_owner != null:
		bar._hook(match_owner)
	for key: String in saved:
		bar.set(key, saved[key])
	bar.queue_redraw()
	print("HIGHLIGHT HUD fighter_panels=off clock=on event=on bottom=on aim=on feedback=on")


func _hide_hud() -> void:
	# Ring tips can be requested directly by recovery even with howto=off.
	# Keep clock, events, aim, hit feedback and the normal key strip visible.
	# Fighter score/percentage plates follow the capture-only fighter_panels option.
	var hints := player.get_node_or_null("HowTo") as CanvasLayer
	if hints != null:
		hints.visible = false
	var lessons := RingLessons.find(self)
	if lessons != null and lessons.card != null:
		lessons.card.visible = false


func seg_water() -> void:
	await _play("water", "fire", 2701)


func seg_fire() -> void:
	await _play("fire", "earth", 2711)


func seg_earth() -> void:
	await _play("earth", "air", 2719)


func seg_air() -> void:
	await _play("air", "water", 2729)


func _play(element: String, opponent: String, seed_n: int) -> void:
	recording = false
	_finish_at = INF
	if is_instance_valid(sim):
		sim._let_go()
		sim.free()
	MatchSetup.element = element
	MatchSetup.foes = [opponent]
	mode.restart()
	while mode.phase != "FIGHT":
		await _frame()
	sim = InputPlayer.new()
	sim.setup(player, mode, "expert", seed_n)
	sim.camera_aim = args.get("mouse", "camera") != "body"
	sim.m = sim.m.duplicate(true)
	level.add_child(sim)
	await _warm(int(float(args.get("lead_" + element, args.get("lead", "3.5"))) * fps))
	await _roll("", "", "", 0)
	# Hard cuts preserve the incoming match's first readable moment.
	xfade_left = 0
	for i in int(float(args.get("seconds_" + element, args.get("seconds", "75"))) * fps):
		await _frame()
		if seg_t >= _finish_at:
			break
	print("HIGHLIGHT %s casts=%d clicks=%d guards=%d hits=%s falls=%s" % [element,
		sim.casts, sim.clicks, sim.guards, mode.stats, mode.falls])
	recording = false
	FileAccess.open(out.path_join("events.json"), FileAccess.WRITE).store_string(JSON.stringify(events, "\t"))
	_write_log()


func _film_ko(body: Node3D, _by: Node, pct: float, tag: String, left: int) -> void:
	events.append({"kind": "ko", "element": cur_id, "time": seg_t if recording else -1.0,
		"who": "player" if body == player else "opponent", "pct": pct, "move": tag, "lives": left})
	print("HIGHLIGHT EVENT ", events.back())
	if recording and body != player:
		_finish_at = seg_t + 4.0


func _film_launch(body: Node3D, velocity: Vector3, stun: float, _by: Node, tag: String) -> void:
	if recording and velocity.length() >= 13.0:
		events.append({"kind": "launch", "element": cur_id, "time": seg_t,
			"who": "player" if body == player else "opponent", "speed": velocity.length(), "stun": stun, "move": tag})


func _frame() -> void:
	if args.get("probe", "0") != "1":
		await super._frame()
		return
	await process_frame
	if recording:
		seg_t += 1.0 / fps
		seg_total += 1.0 / fps
		if int(round(seg_t * fps)) % (fps * 10) == 0:
			print("HIGHLIGHT PROBE %s t=%.0f player=%.0f foe=%.0f casts=%d clicks=%d" % [cur_id, seg_t,
				mode.rules.pct_of(player), mode.rules.pct_of(mode.foe), sim.casts, sim.clicks])


func _save_frame(img: Image) -> void:
	super._save_frame(img)
	_timing.store_line(JSON.stringify({"frame": frame_no - 1, "engine_frame": Engine.get_process_frames() - 1,
		"physics_frame": Engine.get_physics_frames(), "element": cur_id, "video_s": seg_t,
		"phase": mode.phase, "phase_s": mode.phase_t, "process_delta_s": player.get_process_delta_time(),
		"time_scale": Engine.time_scale, "wall_usec": Time.get_ticks_usec(),
		"fighter_panels": args.get("fighter_panels", "on"),
		"clock": player.hud.percent_bar.clock_text()}))
	if frame_no % fps == 0:
		_timing.flush()
		_write_log()
