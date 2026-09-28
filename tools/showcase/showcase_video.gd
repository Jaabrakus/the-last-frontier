extends SceneTree
## Systems showcase video: the real game, played by this script through the real input actions, recorded frame by
## frame with captions naming each system (user 2026-09-26: "make a video showcasing our systems").
##
## Every segment loads nothing new: the one level, the one player, driven like a player would (Input actions for
## movement, aim, fire, E, T, B...; yaw and pitch set as the mouse would), with the game's own camera for gameplay
## and a script camera for the establishing shots. The HUD, prompts and menus are in the picture: every CanvasLayer
## is drawn into the off-window view (CanvasLayer.custom_viewport), laid out at the video's size.
##
##   Godot --path . --resolution 960x540 --fixed-fps 30 --write-movie <dir>/raw.avi \
##       -s tools/showcase/showcase_video.gd -- out=<dir> wildlife=on birdlife=on [size=1920x1080] [fps=30] \
##       [only=<id>,<id>] [stills=1] [jpg=0.93] [captions=0]
##   python3 tools/showcase/video_audio.py <dir>/raw.avi <dir>/frames.txt <dir>/audio.wav
##   swiftc -O tools/showcase/video_encode.swift -o <scratch>/video_encode
##   <scratch>/video_encode encode <dir>/frames 30 <film>.mp4 <dir>/audio.wav
##
## --fixed-fps must equal fps=: the game runs on the fixed frame step, so the video's time is exact however slow the
## render. Frames go to <out>/frames/f00000.jpg ... and <out>/frames.txt lists the engine frame each was rendered in
## (the movie writer's AVI is only used for its sound: video_audio.py cuts the recorded frames' sound out of it).
## stills=1: a look-check instead: one PNG a second of every segment and a contact sheet (<out>/stills/).
##
## See CREDITS.md for everything shown (the end card lists it).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

const BASE_DOY := 237.0            ## 25 August 1765, the game's default date
const XFADE_S := 0.5               ## the dissolve between segments
const FIRST_WARM := 240            ## the first segment's unrecorded frames (shader compiles, SDFGI, streaming)
const WARM := 40                   ## every other segment's unrecorded frames (TAA, exposure settle)
const SAVE_QUEUE := 8

## The segments in order (method seg_<id>); set=traversal films TRAVERSAL instead.
const TRAVERSAL := ["ttitle", "loco", "vault", "bale", "climb"]
const ORDER := ["title", "creator", "vault", "climb", "bow", "musket", "throw", "torch", "wheel", "gather", "build",
		"fort", "horse", "wildlife", "hunt", "forage", "weather", "night", "end"]

var args := {}
var out := ""
var fps := 30
var px := Vector2i(1920, 1080)
var ui := Vector2i(1920, 1080)       ## the size the UI is laid out at (ui=; the film: its own size)
var stills := false
var captions := true
var jpg_q := 0.93

var level: Node3D
var player: FrontierPlayer
var rig: EnvironmentRig
var dn: DayNight
var view: SubViewport
var driver: Node
var cine: Camera3D
var cam_fn := Callable()           ## the script camera's pose each frame: func(dt) -> [pos, look, fov]
var use_cine := false
## The script camera becomes the level's current camera (the film's audio listener and LOD centre). Off, only the
## picture comes from it: the game keeps aiming with the player's camera (E, the torch's throw use the current one).
var cine_takes_over := true

var recording := false
var seg_index := 0
var seg_count := 0
var seg_t := 0.0                   ## seconds recorded in the current segment
var seg_total := 0.0
var frame_no := 0
var frame_log := PackedStringArray()
var pending: Array = []
var last_image: Image
var xfade_left := 0
var still_imgs: Array[Image] = []
var cur_id := ""
var aim_target := Vector3.INF      ## the player turns toward this each frame (as a mouse would)
var aim_rate := 6.0

# overlay
var overlay: CanvasLayer
var fade_rect: TextureRect
var cap_box: Control
var kicker_label: Label
var title_label: Label
var detail_label: Label
var black_rect: ColorRect
var card_box: Control
var card_title: Label
var card_sub: Label
var card_small: Label
var cap_in := 0.4
var cap_out := INF
var readout_on := false            ## readout=1: the body's speed and the traversal move, top right
var readout: Label
var _ro_prev := Vector3.INF
var _ro_speed := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else "1"
	out = String(args.get("out", "user://showcase"))
	fps = int(args.get("fps", "30"))
	stills = args.get("stills", "0") == "1"
	captions = args.get("captions", "1") != "0"
	jpg_q = float(args.get("jpg", "0.93"))
	if args.has("size"):
		var sz := String(args.size).split("x")
		px = Vector2i(int(sz[0]), int(sz[1]))
	ui = px
	if args.has("ui"):
		var us := String(args.ui).split("x")
		ui = Vector2i(int(us[0]), int(us[1]))
	DirAccess.make_dir_recursive_absolute(out.path_join("stills" if stills else "frames"))
	if absf(Engine.physics_ticks_per_second / float(fps) - roundf(Engine.physics_ticks_per_second / float(fps))) > 0.01:
		push_warning("showcase: physics %d Hz is not a multiple of %d fps" % [Engine.physics_ticks_per_second, fps])
	_block_user_input()
	change_scene_to_file(String(args.get("scene", "res://scenes/main.tscn")))
	await process_frame
	await process_frame
	level = current_scene
	if not await _setup():
		quit(1)
		return
	var ids: Array = []
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	var order := _order()
	readout_on = args.get("readout", "1" if order == TRAVERSAL else "0") == "1"
	for id: String in order:
		if only.is_empty() or id in only:
			ids.append(id)
	seg_count = ids.size()
	print("SHOWCASE %d segments: %s" % [ids.size(), ", ".join(ids)])
	for i in ids.size():
		seg_index = i
		cur_id = ids[i]
		var t0 := Time.get_ticks_msec()
		var f0 := frame_no
		_begin_segment()
		await call("seg_" + String(ids[i]))
		await _end_segment()
		print("SHOWCASE seg %-12s %4d frames %5.1f s  %.0f ms/frame" % [cur_id, frame_no - f0, (frame_no - f0) / float(fps),
				(Time.get_ticks_msec() - t0) / float(maxi(frame_no - f0, 1))])
	await _flush()
	_write_log()
	if stills:
		_sheet(still_imgs, out.path_join("stills/sheet.png"), 4)
	print("SHOWCASE DONE frames=%d (%.1f s)" % [frame_no, frame_no / float(fps)])
	quit()


## The segments to record, in order (set=traversal: the traversal film).
func _order() -> Array:
	return TRAVERSAL if String(args.get("set", "")) == "traversal" else ORDER


## Before a segment's own script runs.
func _begin_segment() -> void:
	pass


# --- setup -----------------------------------------------------------------------------------------------------------

func _setup() -> bool:
	player = level.get_node_or_null("Player")
	rig = level.get_node_or_null("EnvironmentRig")
	if player == null or rig == null or rig.clock_driver == null:
		print("SHOWCASE: no player / DayNight (headless?)")
		return false
	dn = rig.clock_driver
	dn.clock.running = false
	dn.clock.set_date(BASE_DOY)
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# the UI is laid out at the video's size whatever the window's (canvas items stretch to the window)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = ui
	cine = Camera3D.new()
	cine.name = "ShowcaseCamera"
	cine.near = 0.05
	cine.far = 2500.0
	level.add_child(cine)
	view = OffscreenView.new()
	view.name = "ShowcaseView"
	root.add_child(view)
	view.setup(root, px)
	view.source = player.camera
	root.disable_3d = true
	_build_overlay()
	_clean_hud()
	# every CanvasLayer (the HUD, prompts, menus, now and later) draws into the view
	for n in root.find_children("*", "CanvasLayer", true, false):
		_redirect(n)
	node_added.connect(_on_node_added)
	# the late driver: after the player moved its camera this frame, the view copies it
	driver = Node.new()
	driver.name = "ShowcaseDriver"
	driver.process_priority = 100000
	driver.process_physics_priority = -100000
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	var ds := GDScript.new()
	ds.source_code = "extends Node\nvar tree\nfunc _process(d):\n\ttree.late(d)\nfunc _physics_process(d):\n\ttree.early_physics(d)\n"
	ds.reload()
	driver.set_script(ds)
	driver.set("tree", self)
	root.add_child(driver)
	# the player is fully built (rig on its worker thread, traversal baked)
	var tries := 0
	while (player.anim == null or player.traversal == null or not player.traversal.world_ready) and tries < 3000:
		await process_frame
		tries += 1
	print("SHOWCASE ready after %d frames" % tries)
	return true


## The game HUD's panels are left out of the film (user 2026-09-27: "we have this like weird hud system of 12345"):
## the slot strip and its ammo line, the health panel, the compass and clock, the controls hint, the debug lines. The
## aim dot and hit markers, the hurt flash, the E prompts and the gathering toasts stay, and so do the menus (wheel,
## pack, creator, build panel). Applied every frame (the HUD shows some of them itself).
var _hud_keep: Array = []
var show_vitals := false        ## a segment that is about health or rest shows the health panel (bottom left)


func _clean_hud() -> void:
	var hud := player.hud
	if hud == null:
		return
	_hud_keep = []
	for k in ["_cross", "_pickup", "_toasts", "_edge"]:
		if hud.get(k) != null:
			_hud_keep.append(hud.get(k))


func _hide_hud() -> void:
	var hud := player.hud
	if hud == null or hud.get("_root") == null:
		return
	for c in (hud.get("_root") as Control).get_children():
		if not c is CanvasItem or c in _hud_keep:
			continue
		var want := show_vitals and c.name == "Vitals"
		if (c as CanvasItem).visible != want:
			(c as CanvasItem).visible = want


func _on_node_added(n: Node) -> void:
	if n is CanvasLayer:
		_redirect.call_deferred(n)


func _redirect(n: Node) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	if n == overlay or view.is_ancestor_of(n) or n.name == "OffscreenMirror":
		return
	var cl := n as CanvasLayer
	cl.custom_viewport = view
	if ui != px:
		cl.scale = Vector2(px) / Vector2(ui)


## The window opens on the user's screen: every game action is unbound (as scenic_shots.gd does), so stray key
## presses cannot reach the game; this script presses the actions itself.
func _block_user_input() -> void:
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)


# --- the frame loop --------------------------------------------------------------------------------------------------

## Called by the driver after every node's _process: the camera the view renders through.
func late(dt: float) -> void:
	if use_cine and cam_fn.is_valid():
		var r: Array = cam_fn.call(dt)
		cine.global_position = r[0]
		if (r[1] as Vector3).distance_to(r[0]) > 0.001:
			cine.look_at(r[1], Vector3.UP)
		if r.size() > 2:
			cine.fov = float(r[2])
	view.sync_camera()
	_hide_hud()


## Called before the player's physics each step: the mouse (yaw and pitch toward aim_target).
func early_physics(dt: float) -> void:
	if aim_target == Vector3.INF or player == null or player.camera == null:
		return
	var from := player.camera.global_position
	var d := aim_target - from
	var want_yaw := atan2(-d.x, -d.z)
	var want_pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var k := 1.0 - exp(-aim_rate * dt)
	player.yaw += wrapf(want_yaw - player.yaw, -PI, PI) * k
	player.pitch += (want_pitch - player.pitch) * k


## One video frame: the frame being built now is recorded if `recording`.
func _frame() -> void:
	var rec := recording
	if rec:
		_overlay(seg_t)
	await process_frame
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)
	if rec:
		var img := view.get_texture().get_image()
		if stills:
			if int(round(seg_t * fps)) % fps == 0:
				img.save_png(out.path_join("stills/%s_%02d.png" % [cur_id, int(round(seg_t))]))
				still_imgs.append(img)
		else:
			_save_frame(img)
		last_image = img
		seg_t += 1.0 / fps
		seg_total += 1.0 / fps
		if xfade_left > 0:
			xfade_left -= 1


func _sec(s: float) -> void:
	for i in maxi(int(round(s * fps)), 1):
		await _frame()


## Waits (recording if rolling) until cond is true or max_s passes. True when cond came true.
func _until(cond: Callable, max_s: float) -> bool:
	var n := int(round(max_s * fps))
	for i in n:
		if cond.call():
			return true
		await _frame()
	return cond.call()


## Unrecorded frames: the picture settles at the segment's first pose.
func _warm(n: int) -> void:
	var was := recording
	recording = false
	var attr := rig.get_camera_attributes()
	var speed := attr.auto_exposure_speed if attr else 0.0
	if attr:
		attr.auto_exposure_speed = 30.0
	for i in n:
		if attr and i == n - 10:
			attr.auto_exposure_speed = speed
		await _frame()
	recording = was


## Starts recording the segment (after its warm-up) with its caption.
func _roll(kicker: String, title: String, detail: String, warm := -1) -> void:
	await _warm(warm if warm >= 0 else (FIRST_WARM if frame_no == 0 else WARM))
	kicker_label.text = kicker.to_upper()
	title_label.text = title
	detail_label.text = detail
	cap_in = 0.35
	cap_out = INF
	seg_t = 0.0
	if last_image != null and not stills:
		fade_rect.texture = ImageTexture.create_from_image(last_image)
		xfade_left = int(round(XFADE_S * fps))
	recording = true


## Changes the caption (at a cut: the old one leaves with the dissolve, the new one fades in).
func _recaption(title: String, detail: String) -> void:
	title_label.text = title
	detail_label.text = detail
	cap_out = INF
	cap_in = seg_t + 0.15


func _end_segment() -> void:
	recording = false
	cap_out = INF
	aim_target = Vector3.INF
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint", "walk", "fire", "aim", "jump",
			"crouch", "reload", "interact"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	use_cine = false
	cam_fn = Callable()
	player.camera.current = true
	view.source = player.camera


func _save_frame(img: Image) -> void:
	var path := out.path_join("frames/f%05d.jpg" % frame_no)
	frame_log.append("%d %d %s %.4f" % [frame_no, Engine.get_process_frames() - 1, cur_id, seg_t])
	frame_no += 1
	while pending.size() >= SAVE_QUEUE:
		WorkerThreadPool.wait_for_task_completion(pending.pop_front())
	var q := jpg_q
	pending.append(WorkerThreadPool.add_task(func() -> void: img.save_jpg(path, q)))


func _flush() -> void:
	while not pending.is_empty():
		WorkerThreadPool.wait_for_task_completion(pending.pop_front())


func _write_log() -> void:
	if stills:
		return
	var f := FileAccess.open(out.path_join("frames.txt"), FileAccess.WRITE)
	f.store_line("# frame engine_frame shot t  (fps %d, size %dx%d, movie %s)" % [fps, px.x, px.y, Engine.get_write_movie_path()])
	for l in frame_log:
		f.store_line(l)
	f.store_line("# end engine_frame %d" % Engine.get_process_frames())
	f.close()


func _sheet(imgs: Array[Image], path: String, cols: int) -> void:
	if imgs.is_empty():
		return
	var w := 480
	var h := int(480.0 * px.y / px.x)
	var rows := ceili(imgs.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		var im := imgs[i].duplicate() as Image
		im.convert(Image.FORMAT_RGB8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(path)
	print("saved ", path)


# --- overlay ---------------------------------------------------------------------------------------------------------

func _build_overlay() -> void:
	var s := px.y / 1080.0
	overlay = CanvasLayer.new()
	overlay.name = "ShowcaseOverlay"
	overlay.layer = 100
	view.add_child(overlay)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Baskerville", "Georgia", "Times New Roman", "serif"])
	serif.font_weight = 500
	var sans := SystemFont.new()
	sans.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial", "sans-serif"])
	var sans_b := SystemFont.new()
	sans_b.font_names = sans.font_names
	sans_b.font_weight = 600

	fade_rect = TextureRect.new()
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.stretch_mode = TextureRect.STRETCH_SCALE
	fade_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade_rect.visible = false
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(fade_rect)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.04, 0.5)
	sb.set_corner_radius_all(int(6 * s))
	sb.border_width_left = int(4 * s)
	sb.border_color = Color(0.85, 0.62, 0.3, 0.95)
	sb.content_margin_left = 22 * s
	sb.content_margin_right = 26 * s
	sb.content_margin_top = 12 * s
	sb.content_margin_bottom = 14 * s
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 48 * s
	panel.offset_bottom = -64 * s
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(panel)
	cap_box = panel
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(2 * s))
	panel.add_child(vb)
	kicker_label = _label(sans_b, int(17 * s), Color(0.9, 0.7, 0.42))
	title_label = _label(serif, int(40 * s), Color(0.97, 0.94, 0.87))
	detail_label = _label(sans, int(21 * s), Color(0.86, 0.88, 0.9))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size.x = 620 * s
	vb.add_child(kicker_label)
	vb.add_child(title_label)
	vb.add_child(detail_label)
	cap_box.modulate.a = 0.0

	card_box = CenterContainer.new()
	card_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tp := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.03, 0.035, 0.04, 0.45)
	tsb.set_corner_radius_all(int(10 * s))
	tsb.content_margin_left = 60 * s
	tsb.content_margin_right = 60 * s
	tsb.content_margin_top = 20 * s
	tsb.content_margin_bottom = 28 * s
	tp.add_theme_stylebox_override("panel", tsb)
	card_box.add_child(tp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", int(8 * s))
	tp.add_child(tv)
	card_title = _label(serif, int(96 * s), Color(0.98, 0.95, 0.88))
	card_sub = _label(serif, int(30 * s), Color(0.92, 0.9, 0.86))
	card_small = _label(sans, int(18 * s), Color(0.8, 0.82, 0.84))
	for l in [card_title, card_sub, card_small]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tv.add_child(l)
	card_box.modulate.a = 0.0
	overlay.add_child(card_box)

	var ro_panel := PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.03, 0.035, 0.04, 0.55)
	rsb.set_corner_radius_all(int(5 * s))
	rsb.content_margin_left = 14 * s
	rsb.content_margin_right = 14 * s
	rsb.content_margin_top = 8 * s
	rsb.content_margin_bottom = 8 * s
	ro_panel.add_theme_stylebox_override("panel", rsb)
	ro_panel.anchor_left = 1.0
	ro_panel.anchor_right = 1.0
	ro_panel.offset_right = -40 * s
	ro_panel.offset_top = 36 * s
	ro_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ro_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "SF Mono", "Courier New", "monospace"])
	readout = _label(mono, int(20 * s), Color(0.92, 0.94, 0.9))
	ro_panel.add_child(readout)
	ro_panel.visible = false
	overlay.add_child(ro_panel)

	black_rect = ColorRect.new()
	black_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_rect.color = Color(0, 0, 0, 0)
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(black_rect)


func _label(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", maxi(1, size / 16))
	l.add_theme_constant_override("shadow_offset_y", maxi(1, size / 16))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _overlay(t: float) -> void:
	_update_readout()
	var a := smoothstep(cap_in, cap_in + 0.5, t) * (1.0 - smoothstep(cap_out, cap_out + 0.3, t))
	cap_box.modulate.a = a if captions and title_label.text != "" else 0.0
	if xfade_left > 0 and fade_rect.texture:
		var n := int(round(XFADE_S * fps))
		fade_rect.modulate.a = smoothstep(0.0, 1.0, float(xfade_left) / float(n + 1))
		fade_rect.visible = true
	else:
		fade_rect.visible = false


## Speed of the body over the ground (from its motion, so a traversal move's root motion counts), the gait, and the
## traversal move playing.
func _update_readout() -> void:
	var panel := readout.get_parent() as Control
	panel.visible = readout_on and player.visible and title_label.text != ""
	if not panel.visible:
		_ro_prev = Vector3.INF
		return
	var p := player.global_position
	if _ro_prev != Vector3.INF:
		var v := Vector2(p.x - _ro_prev.x, p.z - _ro_prev.z).length() * fps
		_ro_speed = lerpf(_ro_speed, v, 0.35) if v < 12.0 else _ro_speed
	_ro_prev = p
	var gait := "standing"
	if player.is_crouching:
		gait = "crouch"
	elif Input.is_action_pressed(&"sprint"):
		gait = "sprint"
	elif Input.is_action_pressed(&"walk"):
		gait = "walk"
	elif Input.is_action_pressed(&"move_forward"):
		gait = "run"
	var line2 := "on foot"
	if player.traversal and player.traversal.showing:
		var st: Dictionary = player.traversal.controller.anim_state()
		line2 = "move: %s" % String(st.get("move", st.get("mode", "")))
	readout.text = "%4.1f m/s   %s\n%s" % [_ro_speed, gait, line2]


func _card(title: String, sub: String, small: String) -> void:
	card_title.text = title
	card_sub.text = sub
	card_small.text = small
	card_small.visible = small != ""
	card_sub.visible = sub != ""


# --- player helpers --------------------------------------------------------------------------------------------------

func _ground(x: float, z: float) -> float:
	return FrontierTerrain.height_at(x, z)


## The player stands at (x, z) on the ground, facing `face` (a world point), everything stopped.
func _place(x: float, z: float, face: Vector3) -> void:
	player.global_position = Vector3(x, _ground(x, z) + 0.05, z)
	player.velocity = Vector3.ZERO
	var d := face - player.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-8.0)


func _press(action: StringName) -> void:
	Input.action_press(action)


func _release(action: StringName) -> void:
	Input.action_release(action)


## A key tap as an input event too (for the handlers that read events: weapon keys, E, T...).
func _tap(action: StringName, hold_s := 0.1) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _sec(hold_s)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)


func _equip(key: String) -> void:
	if player.weapon_key != key:
		player.switch_weapon(key)
	await _until(func() -> bool: return not player.is_switching(), 3.0)


func _clock(hour: float, weather := "fair", cover := -1.0) -> void:
	dn.clock.set_date(BASE_DOY)
	dn.clock.set_time(hour)
	dn.force_weather(weather)
	dn.weather.kind_duration = 1.0e6
	dn.force_cover = cover


## A script camera: pos/look given by a function of the segment time, or a fixed pair.
func _cam_path(keys: Array, dur: float, fov := 55.0) -> void:
	var pos: Array[Vector3] = []
	var look: Array[Vector3] = []
	for k: Array in keys:
		pos.append(k[0])
		look.append(k[1])
	var started := {"t": -1.0}
	cam_fn = func(_dt: float) -> Array:
		if started.t < 0.0:
			started.t = seg_t
		var s := _ease(clampf((seg_t - float(started.t)) / dur, 0.0, 1.0))
		return [_spline(pos, s), _spline(look, s), fov]
	use_cine = true
	cine.current = cine_takes_over
	view.source = cine


## Smootherstep: the camera starts and ends at rest.
static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _spline(pts: Array[Vector3], s: float) -> Vector3:
	if pts.size() == 1:
		return pts[0]
	var n := pts.size() - 1
	var x := clampf(s, 0.0, 1.0) * n
	var i := mini(int(floor(x)), n - 1)
	var u := x - i
	var p0 := pts[maxi(i - 1, 0)]
	var p1 := pts[i]
	var p2 := pts[i + 1]
	var p3 := pts[mini(i + 2, n)]
	if i == 0:
		p0 = p1 * 2.0 - p2
	if i + 2 > n:
		p3 = p2 * 2.0 - p1
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u \
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)


func _kick(n: int, name: String) -> String:
	return "%02d  ·  %s" % [n, name]


## A script camera riding with `node` (the player by default): rel_pos and rel_look in its heading's frame
## (x right, y up, z back), smoothed.
func _cam_rel(rel_pos: Vector3, rel_look: Vector3, fov := 50.0, smooth := 4.0, node: Node3D = null,
		heading := true) -> void:
	var tgt: Node3D = node if node else player
	var st := {"p": Vector3.INF, "l": Vector3.INF}
	cam_fn = func(dt: float) -> Array:
		var b := Basis(Vector3.UP, tgt.global_rotation.y) if heading else Basis()
		var base := tgt.global_position
		var wp := base + b * rel_pos
		var wl := base + b * rel_look
		if st.p == Vector3.INF:
			st.p = wp
			st.l = wl
		else:
			var k := 1.0 - exp(-smooth * dt)
			st.p = (st.p as Vector3).lerp(wp, k)
			st.l = (st.l as Vector3).lerp(wl, k)
		return [st.p, st.l, fov]
	use_cine = true
	cine.current = cine_takes_over
	view.source = cine


## A script camera standing at `pos`, turning to follow `look` (a function giving a world point), smoothed.
func _cam_at(pos: Vector3, look: Callable, fov := 50.0, smooth := 5.0) -> void:
	var st := {"l": Vector3.INF}
	cam_fn = func(dt: float) -> Array:
		var l: Vector3 = look.call()
		if st.l == Vector3.INF:
			st.l = l
		else:
			st.l = (st.l as Vector3).lerp(l, 1.0 - exp(-smooth * dt))
		return [pos, st.l, fov]
	use_cine = true
	cine.current = cine_takes_over
	view.source = cine


func _cam_game() -> void:
	use_cine = false
	cam_fn = Callable()
	player.camera.current = true
	view.source = player.camera


## A cut inside a segment: unrecorded frames settle the new shot, then it dissolves in from the last frame; the
## caption stays.
func _cut(warm := 24) -> void:
	await _warm(warm)
	if last_image != null and not stills:
		fade_rect.texture = ImageTexture.create_from_image(last_image)
		xfade_left = int(round(XFADE_S * fps))


## Game time passes unrendered (the view's updates off): the wildlife settles, a storm builds.
func _skip(s: float) -> void:
	var was := recording
	recording = false
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for i in int(round(s * fps)):
		await process_frame
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	recording = was


func _herd(kind: String) -> WildGroup:
	var w := level.get_node_or_null("Wildlife") as WildlifeSpawner
	if w == null:
		return null
	for e: Dictionary in w.groups:
		if e.kind == kind and (e.group as WildGroup).alive().size() > 0:
			return e.group
	return null


## Moves a group to `spot`: its destination, every member at its place round it, busy with `act`.
func _move_group(g: WildGroup, spot: Vector3, act: WildGroup.Activity) -> void:
	var w := level.get_node_or_null("Wildlife") as WildlifeSpawner
	g.dest = spot
	g.dest_set = true
	g.activity = act
	g.activity_since = w.now if w else 0.0
	for a in g.alive():
		var p := spot
		if not g.is_leader(a):
			var slot := g.slot_of(a)
			var ang := float(slot) * 2.2 + 0.7
			p += Vector3(cos(ang), 0.0, sin(ang)) * (3.0 + float(slot % 3) * 2.0)
		a.global_position = Vector3(p.x, _ground(p.x, p.z) + 0.02, p.z)
		a.awareness = 0.0
		a.set_active(true)


## The storm front's leading edge `km` from `at` (> 0 still coming); lightning when `strike`.
func _storm_at(km: float, at: Vector3, strike := false) -> void:
	var w := dn.weather
	var f: CloudField = w.field
	var d2 := Vector2(f.front.x, f.front.y)
	var c2 := Vector2(at.x, at.z)
	var a := c2.dot(Vector2(-d2.y, d2.x))
	f.front.z = c2.dot(d2) + 5000.0 * sin(a * 2.2e-5 + 0.7) - km * 1000.0
	if strike:
		w.set("_next_strike", 0.0)


## A tree at the edge of the fort's clearing, clear of the range lane, 13 m+ tall and 18-42 cm in radius
## (felling_shots.gd's pick).
func _pick_tree(h: VegHarvest) -> int:
	var best := -1
	var bs := INF
	for i in h.lay.tree_pos.size():
		if int(h.lay.tree_kind[i]) >= VegHarvest.Assets.CANOPY_COUNT or h.lay.tree_collider[i] == 0:
			continue
		var p: Vector3 = h.lay.tree_pos[i]
		var rad := Vector2(p.x, p.z).length()
		if rad < 26.0 or rad > 60.0 or (absf(p.x) < 10.0 and p.z < 0.0):
			continue
		var d := h.describe("tree", "tree", i)
		if float(d.height) < 13.0 or float(d.radius) > 0.3 or float(d.radius) < 0.16:
			continue
		var score := absf(rad - 34.0) + (0.0 if p.z > 0.0 else 8.0)
		if score < bs:
			bs = score
			best = i
	return best


# --- segments --------------------------------------------------------------------------------------------------------

func seg_title() -> void:
	_clock(7.4, "fair", 0.18)
	_place(0.0, 6.0, Vector3(0, 0, -40))
	_cam_path([[Vector3(-26.0, 30.0, 40.0), Vector3(0.0, 2.0, -6.0)],
			[Vector3(-12.0, 18.0, 28.0), Vector3(0.0, 1.5, -2.0)],
			[Vector3(-2.5, 6.5, 16.0), Vector3(0.0, 1.6, 4.0)]], 9.0, 55.0)
	await _roll("", "", "")
	_card("Frontier", "The upper Mohawk Valley, 1765", "A tour of the game's systems, recorded in the game")
	for i in int(9.0 * fps):
		var t := seg_t
		card_box.modulate.a = smoothstep(0.6, 1.6, t) * (1.0 - smoothstep(6.4, 7.4, t))
		black_rect.color.a = 1.0 - smoothstep(0.0, 1.0, t)
		await _frame()
	card_box.modulate.a = 0.0


func seg_creator() -> void:
	_clock(10.0, "fair", 0.2)
	var c := CharacterCreator.open(player.appearance)
	await _warm(20)
	c._set_focus("people")
	await _roll(_kick(1, "Characters"), "Character creator",
			"The peoples of the 1760s frontier, both body types; faces, skin, eyes, hair and markings, in a painted or a realistic style.", 60)
	await _sec(1.4)
	for i in 2:
		c._step("people", 1)
		await _sec(1.3)
	c._set_focus("face")
	await _sec(1.2)
	for i in 3:
		c._step("people", 1)
		await _sec(1.2)
	c._randomize()
	await _sec(1.3)
	c.close(false)
	await _warm(4)


func seg_climb() -> void:
	_clock(15.2, "fair", 0.2)
	await _equip("musket")
	# the firing step: Space at its edge climbs onto the boards
	_place(8.0, -10.8, Vector3(8.0, 0, -40))
	player.traversal.controller.teleported()
	_cam_rel(Vector3(2.6, 1.5, 3.2), Vector3(-0.2, 1.6, -1.5), 52.0, 5.0)
	await _roll(_kick(4, "Climbing"), "Climbing and ladders",
			"Space at a ledge climbs it; ladders up to the fort's firing step, climbed hand over hand.")
	await _sec(0.4)
	_press(&"move_forward")
	await _until(func() -> bool: return player.global_position.z <= -13.55, 3.0)
	_press(&"jump")
	await _sec(0.15)
	_release(&"jump")
	await _sec(3.6)
	_release(&"move_forward")
	await _sec(0.6)
	# the ladder by the gate
	_release(&"move_forward")
	_place(-5.1, -11.6, Vector3(-5.1, 0, -40))
	player.traversal.controller.teleported()
	_cam_at(Vector3(-9.6, _ground(-9.6, -8.4) + 3.0, -8.4), func() -> Vector3: return player.global_position + Vector3(0, 1.1, 0), 52.0, 3.0)
	await _cut(30)
	_press(&"move_forward")
	await _until(func() -> bool: return player.global_position.y > 2.1 and not player.traversal.showing, 9.0)
	await _sec(0.6)
	_release(&"move_forward")
	await _sec(0.6)


func seg_bow() -> void:
	_clock(8.2, "fair", 0.2)
	_place(-1.0, FrontierStructures.FIRING_LINE_Z - 1.3, Vector3(0.0, 1.2, -45.0))
	await _equip("bow")
	aim_target = Vector3(0.0, 1.3, -45.0)
	aim_rate = 5.0
	await _roll(_kick(3, "Weapons"), "Hunting bow",
			"Hold to draw, release to loose. The arrow is nocked on the string; draw strength sets its speed and its drop.")
	await _sec(0.7)
	for shot in 2:
		_press(&"fire")
		await _sec(1.7)
		_release(&"fire")
		await _sec(1.5)


func seg_musket() -> void:
	_clock(8.6, "fair", 0.2)
	_place(1.0, FrontierStructures.FIRING_LINE_Z - 1.3, Vector3(2.5, 1.2, -70.0))
	await _equip("musket")
	aim_target = Vector3(2.5, 1.25, -70.0)
	aim_rate = 5.0
	_cam_rel(Vector3(-2.3, 1.65, 1.6), Vector3(0.4, 1.35, -3.0), 50.0, 4.0)
	await _roll(_kick(3, "Weapons"), "Flintlock musket",
			"Hold to shoulder, release to fire: the pan flashes, a hang-fire, then the shot and its smoke. A five-stage reload.")
	await _sec(0.7)
	_press(&"fire")
	await _sec(1.3)
	_release(&"fire")
	await _sec(2.0)
	await _tap(&"reload")
	await _sec(3.4)


func seg_throw() -> void:
	_clock(8.9, "fair", 0.2)
	for k in ["tomahawk", "spear"]:
		if not player.is_carried(k):
			player.set_carried(k, true)
	_place(-2.2, FrontierStructures.FIRING_LINE_Z - 1.5, Vector3(-2.5, 1.0, -30.0))
	for k in ["tomahawk", "spear"]:
		var tw := player.weapons.get(k) as Throwable
		if tw:
			for f in ["spread_base", "spread_move", "spread_undercharge", "fire_bloom", "spread_air", "spread_fatigue", "spread"]:
				tw.set(f, 0.0)
	await _equip("tomahawk")
	aim_target = Vector3(-2.5, 1.35, -30.0)
	aim_rate = 5.0
	await _roll(_kick(3, "Weapons"), "Thrown weapons",
			"Tomahawk, spear and atlatl: wind up and the arc shows where it will land; they stick in wood, straw and soft ground.")
	await _sec(0.5)
	_press(&"fire")
	await _sec(1.1)
	_release(&"fire")
	await _sec(1.6)
	_report_throws("tomahawk")
	await _equip("spear")
	aim_target = Vector3(0.0, 1.15, -45.0)
	await _sec(0.6)
	_press(&"fire")
	await _sec(1.3)
	_release(&"fire")
	await _sec(1.6)
	_report_throws("spear")
	aim_target = Vector3.INF
	await _target_close(Vector3(-2.5, 0.0, -30.0), 1.8)
	await _target_close(Vector3(0.0, 0.0, -45.0), 1.8)


func seg_torch() -> void:
	_clock(20.35, "clear", 0.0)
	await _equip("musket")
	_place(-6.0, 7.0, Vector3(-6.0, 0, -10.0))
	_cam_rel(Vector3(-1.4, 1.55, -3.2), Vector3(0.1, 1.15, 0.0), 50.0, 3.0)
	await _roll(_kick(4, "Night"), "Pine-knot torch",
			"T lights one: the torch in the right hand, the musket carried in the left at its balance point. Hold T to raise it.", 50)
	await _sec(0.6)
	await _tap(&"torch")
	await _sec(1.8)
	_press(&"walk")
	_press(&"move_forward")
	await _sec(2.2)
	_press(&"torch")
	await _sec(2.0)
	_release(&"torch")
	await _sec(0.8)
	_release(&"move_forward")
	_release(&"walk")
	await _sec(0.8)
	# aiming tosses the torch ahead; it keeps burning where it lands
	aim_target = player.global_position + Vector3(0, 1.2, -12.0)
	_press(&"aim")
	await _sec(2.2)
	_release(&"aim")
	await _sec(0.6)


func seg_wheel() -> void:
	_clock(11.0, "fair", 0.22)
	await _equip("musket")
	_place(2.0, 4.0, Vector3(2.0, 0, -30.0))
	await _roll(_kick(5, "Gear"), "Equip wheel and pack",
			"Hold Q for the wheel: weapons, tools, the torch, empty hands. Tab opens the pack, a grid of what you carry.")
	await _sec(0.6)
	var wheel: EquipWheel = player.equip_wheel
	_press(EquipWheel.ACTION)
	await _sec(0.5)
	if wheel and wheel.is_open:
		var n := wheel.slots.size()
		for i in n + 1:
			var ang := TAU * float(i % n) / float(n)
			wheel.pick_toward(Vector2(sin(ang), -cos(ang)) * 200.0)
			await _sec(0.28)
		var bi := -1
		for i in n:
			if String(wheel.slots[i].id) == "w:bow":
				bi = i
		if bi >= 0:
			var ang := TAU * float(bi) / float(n)
			wheel.pick_toward(Vector2(sin(ang), -cos(ang)) * 200.0)
		await _sec(0.6)
	_release(EquipWheel.ACTION)
	await _sec(1.6)
	await _tap(&"inventory")
	await _sec(3.6)
	for n in root.get_children():
		if n is InventoryScreen:
			(n as InventoryScreen).close()
	await _sec(0.5)


func seg_gather() -> void:
	_clock(10.5, "fair", 0.2)
	var h := VegHarvest.find(self)
	var i := _pick_tree(h)
	if i < 0:
		print("SHOWCASE: no tree to fell")
		return
	var tree := h.describe("tree", "tree", i)
	var tp: Vector3 = tree.pos
	var outward := Vector3(tp.x, 0, tp.z).normalized()
	var tangent := outward.cross(Vector3.UP).normalized()
	var from := tp - tangent * 5.0
	var d := Vector3(tp.x - from.x, 0.0, tp.z - from.z).normalized()
	var at := tp - d * (float(tree.radius) + 1.0)
	_place(at.x, at.z, tp)
	player.pitch = deg_to_rad(4.0)
	var gt: GatherTools = player.gather
	if gt.skills:
		gt.skills.set_points("woodcutting", 45.0)
	_cam_at(tp - outward * 13.0 - d * 6.0 + Vector3.UP * 2.0, func() -> Vector3: return tp + d * 3.0 + Vector3.UP * 3.5, 55.0)
	await _roll(_kick(6, "Gathering"), "Felling and bucking",
			"The felling axe and the mattock: strokes by the trunk's size, the wood's hardness and your Woodcutting skill. The tree falls away from you.")
	await _tap(&"tool_axe")
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 3.0)
	var felled := [null]
	gt.felled.connect(func(ft: FelledTree) -> void: felled[0] = ft, CONNECT_ONE_SHOT)
	_press(&"fire")
	await _until(func() -> bool: return felled[0] != null, 14.0)
	_release(&"fire")
	var ft: FelledTree = felled[0]
	if ft:
		await _until(func() -> bool: return ft.is_down(), 6.0)
	await _sec(1.4)


func seg_build() -> void:
	_clock(12.5, "fair", 0.25)
	var cabin := Vector3(21.0, 0.0, 6.0)
	var mode: BuildMode = player.building
	var inv := InventoryState.from_player(player)
	inv.add("log", 300)
	inv.add("stone", 200)
	player.inventory_pack = inv.pack.duplicate(true)
	_place(cabin.x + 4.0, cabin.z + 3.5, cabin)
	var c := cabin + Vector3(0, _ground(cabin.x, cabin.z), 0)
	var st := {"a": 0.0}
	cam_fn = func(dt: float) -> Array:
		st.a = float(st.a) + dt * 0.16
		var a := float(st.a) + 0.5
		return [c + Vector3(sin(a) * 11.0, 5.2, cos(a) * 11.0), c + Vector3(0, 1.4, 0), 50.0]
	use_cine = true
	cine.current = cine_takes_over
	view.source = cine
	mode.set_active(true)
	await _roll(_kick(6, "Building"), "Log cabins and palisades",
			"B for build mode: pieces snap as 3 m modules, a green ghost where one can go. Floors, notched walls, gables, a roof and a chimney.")
	await _sec(0.4)
	var G := BuildGeometry
	var fl := await _build_piece(mode, "floor", c)
	if fl:
		var fo := fl.global_position
		var top := float(G.FLOOR_H)
		var walls := {}
		for s: Array in [["wall", Vector3(1.3, 0, 0)], ["wall_window", Vector3(-1.3, 0, 0)], ["wall_door", Vector3(0, 0, 1.3)],
				["wall", Vector3(0, 0, -1.3)]]:
			walls[s[1]] = await _build_piece(mode, String(s[0]), fo + (s[1] as Vector3) + Vector3(0, top, 0))
		for k: Vector3 in [Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0)]:
			var w: BuiltPiece = walls.get(k)
			if w:
				await _build_piece(mode, "gable", w.global_transform * Vector3(0, float(G.WALL_H) + 0.01, 0))
		await _build_piece(mode, "roof", fo + Vector3(0, top, 0))
		await _build_piece(mode, "hearth", fo + Vector3(2.3, 0, 0))
		var door: BuiltPiece = walls.get(Vector3(0, 0, 1.3))
		if door and door.door:
			door.door.set_open(true)
	mode.aim_at = Vector3.INF
	await _sec(1.2)
	mode.set_active(false)
	await _sec(0.6)


## Shows the piece's ghost at `p` for a moment, then builds it (build mode's own snapping and checks).
func _build_piece(mode: BuildMode, type: String, p: Vector3) -> BuiltPiece:
	mode.select_type(type)
	mode.aim_at = p
	mode.aim_from = Vector3.INF
	await _sec(0.55)
	var piece := mode.place()
	await _sec(0.25)
	return piece


func seg_fort() -> void:
	_clock(13.2, "fair", 0.25)
	var gate := FortGate.find(self)
	if gate:
		gate.set_open(false, true)
	_place(1.2, -12.2, Vector3(0.0, 1.5, -16.0))
	_cam_rel(Vector3(1.8, 1.9, 3.4), Vector3(-0.4, 1.8, -3.0), 55.0, 4.0)
	await _roll(_kick(7, "The fort"), "Gate, walls and axe work",
			"E opens the gate's leaves. The felling axe chops a piece out of the palisade where it aims: a loophole, a window, a way through.")
	await _sec(0.6)
	if gate:
		gate.interact(player)
	await _sec(2.4)
	# chopping a window through the east wall
	_place(14.7, 2.0, Vector3(16.0, 1.4, 2.0))
	player.pitch = deg_to_rad(-2.0)
	var gt: GatherTools = player.gather
	if gt.skills:
		gt.skills.set_points("woodcutting", 70.0)
	_cam_rel(Vector3(-2.2, 1.3, 1.4), Vector3(0.4, 1.3, -1.6), 55.0, 4.0)
	await _cut(20)
	await _tap(&"tool_axe")
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 3.0)
	aim_target = Vector3(16.0, 1.45, 2.0)
	aim_rate = 6.0
	await _sec(0.3)
	_press(&"fire")
	await _sec(6.5)
	_release(&"fire")
	await _sec(1.2)
	await _tap(&"tool_axe")
	await _sec(0.4)


## A cut to a close look at the range dummy standing at `d` (what the shots left in it).
func _target_close(d: Vector3, s: float) -> void:
	var g := _ground(d.x, d.z)
	var c := Vector3(d.x + 1.6, g + 1.5, d.z + 2.6)
	_cam_path([[c, Vector3(d.x, g + 1.2, d.z)], [c + Vector3(-0.5, -0.1, -0.4), Vector3(d.x, g + 1.15, d.z)]], s, 40.0)
	await _cut(14)
	await _sec(s)


## Where the thrown weapons are now (a debug line in the log).
func _report_throws(tag: String) -> void:
	for n in level.find_children("*", "ThrownProjectile", true, false):
		var t := n as Node3D
		print("SHOWCASE throw %s: %s at %s phase %s" % [tag, t.name, t.global_position, t.get("phase")])


## A straight line `length` m long with nothing on it or on the camera's side (the walker's right, 8 m): no tree,
## undergrowth or prop of the vegetation layout, off the fort and the range lane, on gentle ground (the camera rides
## on the walker's right, the morning sun behind it). Returns
## [start (ground), direction]; the candidate nearest `near` wins.
func _clear_line(length: float, near: Vector3) -> Array:
	var h := VegHarvest.find(self)
	var pts := PackedVector3Array()
	if h and h.lay:
		for arr: PackedVector3Array in [h.lay.tree_pos, h.lay.plant_pos, h.lay.prop_pos]:
			for q in arr:
				if absf(q.x - near.x) < 90.0 and absf(q.z - near.z) < 90.0:
					pts.append(q)
	var best := [near, Vector3(1, 0, 0)]
	var best_s := INF
	for gx in range(-16, 17):
		for gz in range(-16, 17):
			var st := near + Vector3(gx * 4.0, 0.0, gz * 4.0)
			for dir: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
				var en := st + dir * length
				if not _line_off_structures(st, en):
					continue
				var right := Vector3(-dir.z, 0.0, dir.x)
				var ok := true
				for q in pts:
					var d := q - st
					var along := d.x * dir.x + d.z * dir.z
					var side := d.x * right.x + d.z * right.z
					if along > -4.0 and along < length + 4.0 and side > -3.0 and side < 8.0:
						ok = false
						break
				if not ok:
					continue
				var lo := INF
				var hi := -INF
				for k in 10:
					var p := st.lerp(en, k / 9.0)
					var g := _ground(p.x, p.z)
					lo = minf(lo, g)
					hi = maxf(hi, g)
				if hi - lo > 1.2:
					continue
				var sc := Vector2(st.x - near.x, st.z - near.z).length()
				if sc < best_s:
					best_s = sc
					best = [Vector3(st.x, _ground(st.x, st.z), st.z), dir]
	if best_s == INF:
		push_warning("showcase: no clear line near %s" % near)
	return best


## The line and the camera's side of it stay off the fort (32 m square) and the range lane (dummies, trusses, rail).
static func _line_off_structures(a: Vector3, b: Vector3) -> bool:
	for k in 12:
		var p := a.lerp(b, k / 11.0)
		if absf(p.x) < 26.0 and absf(p.z) < 26.0:
			return false
		if absf(p.x) < 16.0 and p.z < -14.0 and p.z > -160.0:
			return false
	return true


func _horse() -> Horse:
	var hs := level.find_children("*", "Horse", true, false)
	return hs[0] as Horse if not hs.is_empty() else null


func seg_horse() -> void:
	_clock(15.5, "fair", 0.25)
	var horse := _horse()
	if horse == null:
		print("SHOWCASE: no horse")
		return
	var lead := horse.get_node_or_null("Lead")
	if lead and lead.has_method("stop"):
		lead.stop()
	var hp := Vector3(-9.0, 0.0, -24.0)
	hp.y = _ground(hp.x, hp.z)
	horse.global_position = hp
	horse.look_at(hp + Vector3(0, 0, -1), Vector3.UP)
	horse.speed = 0.0
	await _warm(10)
	_place(hp.x + 1.3, hp.z + 0.3, hp + Vector3(0, 0, -4))
	_cam_rel(Vector3(4.2, 1.6, 2.5), Vector3(0.0, 1.4, -1.5), 50.0, 3.0, horse)
	await _roll(_kick(8, "Horses"), "Riding",
			"A stocky 14.1-hand colonial saddle horse: E at the saddle mounts. Shift spurs it up a gait, Space jumps from a canter.")
	await _sec(0.4)
	player.mount(horse)
	await _sec(2.4)
	player.yaw = horse.global_rotation.y
	_press(&"move_forward")
	await _sec(1.4)
	await _tap(&"sprint")
	await _sec(1.4)
	await _tap(&"sprint")
	await _sec(3.4)
	_release(&"move_forward")
	await _sec(1.8)
	player.dismount()
	await _warm(30)
	# hauling game: a stag roped by the neck and dragged home
	var w := level.get_node_or_null("Wildlife") as WildlifeSpawner
	var a: WildAnimal = null
	if w:
		for x in w.animals():
			if x.species == "stag" and not x.is_dead():
				a = x
				break
	var haul: HorseHaul = horse.get_node_or_null("Haul")
	if a == null or haul == null:
		return
	var sp := Vector3(-9.0, 0.0, -60.0)
	sp.y = _ground(sp.x, sp.z)
	horse.global_position = sp
	horse.look_at(sp + Vector3(0, 0, 1), Vector3.UP)
	horse.speed = 0.0
	await _warm(10)
	var back := Vector3(0, 0, -1)
	var at := horse.get_hitch_point() + back * 2.6
	at.y = _ground(at.x, at.z)
	a.global_position = at
	a.rotation.y = atan2(back.x, back.z)
	a._yaw = a.rotation.y
	a.set_active(true)
	await _warm(2)
	a.apply_hit(9999.0, a.global_position + Vector3.UP * 0.6, Vector3.RIGHT, player, "vitals")
	await _skip(2.0)
	var load := haul.hitch_carcass(a)
	if load == null:
		return
	player.mount(horse)
	await _skip(2.4)
	player.yaw = horse.global_rotation.y
	_cam_rel(Vector3(5.0, 1.8, 3.8), Vector3(0.0, 0.7, 1.6), 50.0, 3.0, horse)
	_recaption("Hauling", "Rope a carcass by the neck, or chain a felled trunk to the singletree, and drag it home.")
	_press(&"move_forward")
	await _cut(20)
	await _sec(5.0)
	_release(&"move_forward")
	await _sec(1.0)
	haul.unhitch()
	player.dismount()
	await _warm(10)


func seg_wildlife() -> void:
	_clock(9.8, "fair", 0.22)
	var w := level.get_node_or_null("Wildlife") as WildlifeSpawner
	if w == null:
		print("SHOWCASE: no wildlife (wildlife=on)")
		return
	# the range herd from the firing line, a long lens
	_place(0.0, -14.0, Vector3(0, 0, -60))
	var herd := _herd("deer_herd")
	if herd:
		var hs := WildlifeSpawner.RANGE_HERD_HOME + Vector3(-6.0, 0.0, 30.0)
		_move_group(herd, hs, WildGroup.Activity.FEED)
		await _skip(4.0)
		_cam_at(Vector3(1.0, _ground(1.0, -19.0) + 1.7, -19.0), func() -> Vector3: return herd.centroid() + Vector3.UP * 0.8, 14.0, 2.0)
	await _roll(_kick(9, "Wildlife"), "Deer, wolves, foxes, ravens",
			"Herds feed and bed by hunger, hour and nerves, with a sentry; they read you by sight, sound and your scent on the wind.")
	await _sec(5.0)
	# the food chain: a wolf pack at a kill, ravens coming in
	var prey: WildAnimal = null
	for a in w.animals():
		if a.species == "deer" and not a.is_dead() and (herd == null or a.group != herd):
			prey = a
			break
	var pk := _herd("wolf_pack")
	if prey and pk:
		var cpos := Vector3(34.0, 0.0, -70.0)
		cpos.y = _ground(cpos.x, cpos.z)
		prey.global_position = cpos
		prey.set_active(true)
		prey.apply_hit(500.0, prey.global_position + Vector3.UP * 0.6, Vector3(1, 0, 0), null, "body")
		var i := 0
		for m in pk.alive():
			var q := cpos + Vector3(cos(i * 1.7), 0.0, sin(i * 1.7)) * 1.6
			m.global_position = Vector3(q.x, _ground(q.x, q.z) + 0.02, q.z)
			m.hunger = 1.0
			m.set_active(true)
			i += 1
		pk.carcass = prey
		pk.activity = WildGroup.Activity.EAT
		pk.dest = cpos
		pk.dest_set = true
		prey.set_meta("died_at", w.now - 60.0)
		_place(cpos.x - 40.0, cpos.z + 40.0, cpos)
		await _skip(22.0)
		var cp := cpos + Vector3(7.0, 0.0, 5.5)
		cp.y = _ground(cp.x, cp.z) + 1.9
		_cam_at(cp, func() -> Vector3: return cpos + Vector3.UP * 0.5, 45.0)
		_recaption("The food chain", "Wolves hunt the deer, kill and guard their kill; ravens come for what is left, and the remains stay until the bones.")
		await _cut(24)
		await _sec(6.0)


func seg_hunt() -> void:
	_clock(17.4, "fair", 0.15)
	var herd := _herd("deer_herd")
	if herd == null:
		print("SHOWCASE: no deer herd")
		return
	var spot := Vector3(10.0, 0.0, -104.0)
	_move_group(herd, spot, WildGroup.Activity.FEED)
	await _equip("bow")
	_place(6.0, -82.0, spot)
	await _tap(&"crouch")
	await _skip(3.0)
	var prey: WildAnimal = herd.leader()
	for a in herd.alive():
		if a.species == "deer" and a.global_position.distance_to(player.global_position) < 26.0:
			prey = a
	var vit := prey.get_node_or_null("Hit_vitals") as Node3D
	aim_target = (vit.global_position if vit else prey.global_position + Vector3.UP * 0.8)
	aim_rate = 4.0
	await _roll(_kick(10, "Hunting"), "The hunt",
			"Crouched and downwind with the bow: a clean shot through the vitals. A wounded animal runs and leaves a blood trail to follow.")
	for k in int(1.2 * fps):
		for a in herd.alive():
			a.awareness = 0.0
		aim_target = (vit.global_position if vit else prey.global_position + Vector3.UP * 0.8)
		await _frame()
	_press(&"fire")
	for k in int(1.8 * fps):
		for a in herd.alive():
			a.awareness = 0.0
		aim_target = (vit.global_position if vit else prey.global_position + Vector3.UP * 0.8)
		await _frame()
	_release(&"fire")
	await _sec(1.0)
	if not prey.is_dead() and vit:
		Hit.deliver(vit as StaticBody3D, 150.0, vit.global_position, Vector3(1, 0, 0), player)
	aim_target = Vector3.INF
	await _sec(2.4)
	# field dressing: E at the carcass, the player kneels, skins, then butchers
	var side := (-prey.global_basis.z).cross(Vector3.UP).normalized()
	var at := prey.global_position + side * 1.3
	await _tap(&"crouch")
	_place(at.x, at.z, prey.global_position)
	await _skip(1.0)
	prey.interact(player)
	_cam_rel(Vector3(-1.6, 1.7, 2.4), Vector3(0.3, 0.4, -1.2), 50.0, 3.0)
	_recaption("Field dressing", "E with the skinning knife: skin, then butcher. Hide, venison and antler go into the pack.")
	await _cut(20)
	await _sec(5.5)


func seg_forage() -> void:
	_clock(11.5, "fair", 0.2)
	var f := ForageField.find(self)
	if f == null:
		return
	var best := -1
	var bd := INF
	for i in f.patches.size():
		if f.patches[i].kind != "blackberry":
			continue
		var dd := Vector2(f.patches[i].pos.x, f.patches[i].pos.z).length()
		if dd < bd:
			bd = dd
			best = i
	if best < 0:
		return
	var pl: Dictionary = f.patches[best].plants[0]
	for q in f.patches[best].plants:
		if float(q.stock) > 0.0:
			pl = q
			break
	var p: Vector3 = pl.pos
	var out_dir := Vector3(-p.x, 0.0, -p.z).normalized()
	var at := p + out_dir * 1.1
	_place(at.x, at.z, p)
	player.pitch = deg_to_rad(-18.0)
	var side := out_dir.cross(Vector3.UP).normalized()
	_cam_at(at + side * 2.6 + out_dir * 1.4 + Vector3.UP * 1.4, func() -> Vector3: return (at + p) * 0.5 + Vector3.UP * 0.7, 45.0)
	await _warm(10)
	await _roll(_kick(11, "Foraging"), "Wild food and herbs",
			"Blackberries, strawberries, plantain, wintergreen, ginseng, acorns, hazelnuts, each in its habitat and season. Deer feed on them too.")
	await _sec(0.8)
	if not f._offer.is_empty() and bool(f._offer.get("can", false)):
		f.interact(player)
	else:
		await _tap(&"interact")
	await _sec(4.2)


func seg_weather() -> void:
	_clock(14.2, "fair", 0.3)
	var w := dn.weather
	dn.force_weather("storm")
	w.field.front.w = 1.0
	w.set("_front_strength", 1.0)
	w.kind_duration = 1.0e6
	_place(6.0, -58.0, Vector3(-40.0, 0.0, -100.0))
	var pos := player.global_position
	_storm_at(16.0, pos)
	await _skip(1.0)
	_cam_rel(Vector3(0.8, 2.0, 4.2), Vector3(-0.2, 4.0, -12.0), 60.0, 3.0)
	await _warm(40)
	await _roll(_kick(12, "Sky and weather"), "Storms you can see coming",
			"A cloud engine with real cloud types: a front builds on the horizon, the wind rises as it brews, then the gust front, rain and lightning.")
	var dur := 11.0
	var n := int(dur * fps)
	var strikes := [4.0, 5.8, 7.2, 8.4, 9.6, 10.4]
	for f in n:
		var t := float(f) / fps
		var km := lerpf(14.0, -3.0, pow(t / dur, 1.3))
		var strike := false
		for s: float in strikes:
			if t >= s and t - 1.0 / fps < s:
				strike = true
		_storm_at(km, pos, strike)
		await _frame()
	dn.force_weather("fair")


func seg_night() -> void:
	_clock(20.15, "clear", 0.0)
	var m := Vector3(20.0, 0.0, -110.0)
	_place(m.x, m.z, Vector3(24.0, 0.0, -125.0))
	await _skip(3.0)
	var cam := Vector3(18.0, _ground(18.0, -100.0) + 1.5, -100.0)
	_cam_path([[cam, Vector3(24.0, cam.y - 0.3, -125.0)], [cam + Vector3(2.0, 0.2, -1.0), Vector3(20.0, cam.y + 0.4, -128.0)]], 6.0, 60.0)
	await _roll(_kick(13, "Night"), "Dusk and dark",
			"Fireflies over the meadow in summer; the sun and moon cross the sky with the moon's phases, and the stars turn.", 60)
	await _sec(5.5)
	var birds := level.get_node_or_null("BirdLife") as BirdLife
	if birds:
		dn.clock.set_time(19.4)
		birds.sun_override = -8.0
		await _skip(2.0)
		var owls := birds.owls()
		if not owls.is_empty():
			var o := owls[0]
			var to := o.global_position - player.global_position
			to.y = 0.0
			var c := o.global_position - to.normalized() * 1.7
			c.y = o.global_position.y + 0.35
			var far := o.global_position - to.normalized() * 30.0
			_place(far.x, far.z, o.global_position)
			birds.sun_override = -16.0
			_cam_path([[c, o.global_position + Vector3.UP * 0.32], [c + Vector3(0, 0.05, 0) - to.normalized() * 0.4, o.global_position + Vector3.UP * 0.32]], 5.0, 40.0)
			_recaption("Owls", "Great horned owls in the trees at night, eyes shining yellow in the dark; stare too long and they are gone.")
			await _cut(30)
			await _sec(5.0)
		birds.sun_override = INF


func seg_end() -> void:
	_clock(19.1, "fair", 0.3)
	_place(0.0, 6.0, Vector3(0, 0, -40))
	_cam_path([[Vector3(10.0, 6.0, 22.0), Vector3(0.0, 4.0, -10.0)], [Vector3(-6.0, 12.0, 26.0), Vector3(0.0, 5.0, -20.0)]], 9.0, 55.0)
	await _roll("", "", "")
	_card("Frontier", "In development",
			"Wildlife stand-ins: Quaternius (CC0). Great horned owl: Poly by Google (CC-BY 3.0).\n"
			+ "Textures: Poly Haven (CC0). Sounds: Kenney, kheetor, rubberduck (CC0); National Park Service,\n"
			+ "U.S. Fish and Wildlife Service and Wikimedia Commons recordings (public domain / CC0).")
	for i in int(9.0 * fps):
		var t := seg_t
		card_box.modulate.a = smoothstep(0.4, 1.4, t)
		black_rect.color.a = smoothstep(7.6, 9.0, t)
		await _frame()


# --- traversal film (set=traversal) ----------------------------------------------------------------------------------

func seg_ttitle() -> void:
	_clock(9.0, "fair", 0.2)
	_place(0.0, -9.0, Vector3(0, 0, -60))
	_cam_path([[Vector3(9.0, 7.0, -30.0), Vector3(0.0, 1.0, -22.0)], [Vector3(6.0, 5.0, -34.0), Vector3(-2.0, 0.8, -30.0)]], 5.0, 50.0)
	await _roll("", "", "")
	_card("Movement and traversal", "How it plays today", "Speed and the traversal move are shown top right")
	for i in int(5.0 * fps):
		var t := seg_t
		card_box.modulate.a = smoothstep(0.2, 0.9, t) * (1.0 - smoothstep(3.9, 4.7, t))
		black_rect.color.a = 1.0 - smoothstep(0.0, 0.7, t)
		await _frame()
	card_box.modulate.a = 0.0


## Walk, run, sprint, crouch-walk and a running jump along a clear line in the meadows (side view).
func seg_loco() -> void:
	_clock(9.2, "fair", 0.2)
	await _equip("musket")
	var ln := _clear_line(38.0, Vector3(20.0, 0.0, -80.0))
	var a: Vector3 = ln[0]
	var dir: Vector3 = ln[1]
	print("SHOWCASE loco line from %s toward %s" % [a, dir])
	_place(a.x, a.z, a + dir * 50.0)
	player.traversal.controller.teleported()
	_cam_rel(Vector3(5.5, 1.3, 1.2), Vector3(0.0, 1.0, -1.0), 50.0, 3.0)
	await _roll(_kick(1, "Movement"), "Walk, run, sprint, crouch",
			"Alt walks, the stick runs, Shift sprints; C crouches. A running jump at the end.")
	await _sec(0.5)
	_press(&"walk")
	_press(&"move_forward")
	await _sec(2.2)
	_release(&"walk")
	await _sec(2.2)
	_press(&"sprint")
	await _sec(2.6)
	_release(&"sprint")
	await _sec(0.6)
	await _tap(&"crouch")
	await _sec(2.4)
	await _tap(&"crouch")
	await _sec(1.0)
	await _tap(&"jump")
	await _sec(1.4)
	_release(&"move_forward")
	await _sec(1.0)


## The firing line's rail: at a sprint (it vaults by itself), then at a run with Space.
func seg_vault() -> void:
	_clock(9.0, "fair", 0.2)
	await _equip("musket")
	_place(0.0, -9.0, Vector3(0, 0, -60))
	var cam := Vector3(8.5, _ground(8.5, -24.5) + 1.3, -24.5)
	_cam_at(cam, func() -> Vector3: return player.global_position + Vector3(0, 0.9, -0.6), 45.0, 6.0)
	await _roll(_kick(2, "Vaulting"), "The fence at a sprint, then at a run",
			"A sprint vaults the rail by itself; at a run, Space at the rail.")
	await _sec(0.5)
	_press(&"move_forward")
	_press(&"sprint")
	await _until(func() -> bool: return player.global_position.z < -27.0, 6.0)
	_release(&"sprint")
	await _sec(0.5)
	_release(&"move_forward")
	await _sec(0.8)
	# at a run
	_place(2.0, -13.0, Vector3(2.0, 0, -60))
	player.traversal.controller.teleported()
	await _cut(20)
	_press(&"move_forward")
	await _until(func() -> bool: return player.global_position.z <= -19.1, 4.0)
	await _tap(&"jump")
	await _until(func() -> bool: return player.global_position.z < -26.0, 4.0)
	_release(&"move_forward")
	await _sec(1.0)


## The range's straw trusses (0.9 m tall, 0.9 m deep): at a sprint, then at a run with Space.
func seg_bale() -> void:
	_clock(9.6, "fair", 0.2)
	await _equip("musket")
	var b := Vector3(-5.0, 0.0, -35.0)
	_place(b.x, b.z + 10.0, b + Vector3(0, 0, -20))
	player.traversal.controller.teleported()
	var cam := Vector3(b.x - 7.0, _ground(b.x - 7.0, b.z + 1.0) + 1.3, b.z + 1.0)
	_cam_at(cam, func() -> Vector3: return player.global_position + Vector3(0, 0.9, -0.8), 42.0, 6.0)
	await _roll(_kick(3, "Hay bales"), "A straw truss at a sprint",
			"0.9 m tall and 0.9 m deep: watch the speed through the move.")
	await _sec(0.5)
	_press(&"move_forward")
	_press(&"sprint")
	await _until(func() -> bool: return player.global_position.z < b.z - 7.0, 7.0)
	_release(&"sprint")
	await _sec(0.4)
	_release(&"move_forward")
	await _sec(1.0)
	# at a run, Space at the truss
	var b2 := Vector3(5.0, 0.0, -50.0)
	_place(b2.x, b2.z + 8.0, b2 + Vector3(0, 0, -20))
	player.traversal.controller.teleported()
	var cam2 := Vector3(b2.x + 7.0, _ground(b2.x + 7.0, b2.z + 1.0) + 1.3, b2.z + 1.0)
	_cam_at(cam2, func() -> Vector3: return player.global_position + Vector3(0, 0.9, -0.8), 42.0, 6.0)
	_recaption("A straw truss at a run", "Space at the truss.")
	await _cut(20)
	_press(&"move_forward")
	await _until(func() -> bool: return player.global_position.z <= b2.z + 1.5, 4.0)
	await _tap(&"jump")
	await _until(func() -> bool: return player.global_position.z < b2.z - 6.0, 7.0)
	_release(&"move_forward")
	await _sec(1.0)
