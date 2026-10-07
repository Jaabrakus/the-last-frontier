extends SceneTree
## Round 4 VIRAL's review images for the owner's eye (the Splash Cam, the highlight cards, the clashes, the callouts, photo
## mode) in the % ring (rules stock; earth against a water bot), 1280 x 720, windowed (it draws):
##   Godot --path . --resolution 1280x720 -s tools/ring/viral_shots.gd -- out=<dir>
## Writes <dir>/r4_viral_replay_strip.png (a fall's Splash Cam replay: 12 frames from its start to the splash, 4 x 3),
## r4_viral_replay_live.png (the same moment from the player's own camera, for comparison), r4_viral_cards.png (the match
## screen with its three highlight cards), r4_viral_clash_<a>_<b>.png (each clash pair a few frames in, with the moment
## before it), r4_viral_callouts.png (every callout, a sheet), r4_viral_photo_wordmark.png and r4_viral_photo_plain.png
## (photo mode's pictures as saved, with and without the wordmark). Ends with VIRAL SHOTS DONE.

const OWN_CFG := "user://viral_shots.cfg"

var out := ""
var lvl: RingLevel
var p: FrontierPlayer
var mode: RingMode
var rules: RingRules
var foe: NpcFighter
var ring: RingArena
var rp: RingReplay
var _cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup._aim_help = "strong"
	SwayCaster.free_override = true
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	MatchSetup.difficulty = "easy"
	RingRules.rule_set_override = "stock"
	RingReplay.force = "on"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _secs(s: float) -> void:
	for i in int(round(s * 60.0)):
		await physics_frame


func _grab() -> Image:
	for i in 2:
		RenderingServer.force_draw(true)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _save(img: Image, name: String) -> void:
	img.save_png(out.path_join(name + ".png"))
	print("  wrote %s.png" % name)


## Images in a grid of `cols` (each scaled by `k`), one file.
func _sheet(imgs: Array, cols: int, k: float, name: String) -> void:
	if imgs.is_empty():
		return
	var w0 := int((imgs[0] as Image).get_width() * k)
	var h0 := int((imgs[0] as Image).get_height() * k)
	var rows := ceili(float(imgs.size()) / float(cols))
	var sheet := Image.create(cols * (w0 + 6) - 6, rows * (h0 + 6) - 6, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.09))
	for i in imgs.size():
		var s := (imgs[i] as Image).duplicate() as Image
		s.resize(w0, h0, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(s, Rect2i(0, 0, w0, h0), Vector2i((i % cols) * (w0 + 6), (i / cols) * (h0 + 6)))
	_save(sheet, name)


func _side(at: Vector3, look: Vector3) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 50.0
		_cam.environment = p.camera.environment
		_cam.attributes = p.camera.attributes
		current_scene.add_child(_cam)
	_cam.global_position = at
	_cam.look_at(look, Vector3.UP)
	_cam.make_current()


func _own_cam() -> void:
	p.camera.make_current()


## A deck place `s` m in from end `e`'s lip, `z` across, `y` over the deck's top.
func at_s(e: int, s: float, z := 0.0, y := 0.0) -> Vector3:
	return ring.to_global(Vector3(RingArena.side_sign(e) * (ring.half_l() - s), ring.top() + y, z))


func _run() -> void:
	await _frames(20)
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	p = lvl.player
	ring = lvl.ring
	p.ignore_mouse_capture = true
	for i in 900:
		if mode.phase == "FIGHT" and not LoadingScreen.covering():
			break
		await physics_frame
	await _secs(0.5)
	rules = RingRules.current()
	foe = mode.foe
	foe.held = true
	rp = RingReplay.install(mode)
	await _secs(1.0)
	await _replay()
	await _clashes()
	await _callouts()
	await _photo()
	await _cards()
	RingRules.rule_set_override = ""
	RingReplay.force = ""
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	print("VIRAL SHOTS DONE")
	quit(0)


func _place(b: Node3D, pos: Vector3, look: Vector3) -> void:
	var f := look - pos
	f.y = 0.0
	RingLevel.place(b, Transform3D(Basis.looking_at(f.normalized(), Vector3.UP), pos))
	if b == p:
		p.pitch = -0.12


## The player's Spike thrown for real (key 1 readied, the right button held until it casts) at the foe at 150% near the
## far edge; a stone bolt with the Spike's hit when the cast does not come.
func _throw_at_foe() -> void:
	var e := mode.player_end
	_place(p, at_s(1 - e, 12.0, 0.6), at_s(1 - e, 3.0))
	_place(foe, at_s(1 - e, 3.2, 0.0), p.global_position)
	await _secs(0.6)
	rules.reset_pct(foe, 150.0)
	var sc := SwayCaster.of(p)
	var cast := [false]
	sc.cast.connect(func(_m: String, _t: Node3D) -> void: cast[0] = true, CONNECT_ONE_SHOT)
	sc.ready_default()
	Input.action_press(&"aim")
	for i in 150:
		if cast[0]:
			break
		await physics_frame
	Input.action_release(&"aim")
	print("  the player's own cast: %s" % cast[0])
	if not cast[0]:
		var from := p.global_position + Vector3.UP * 1.4
		var way := (foe.global_position + Vector3.UP - from).normalized()
		BendBolt.launch(p, from, way, {"kind": "stone", "mps": 26.0, "radius_m": 0.28, "damage": 25.0, "knock_mps": 8.0,
				"_info": {"tag": "stone_form/spike", "from": from}})


func _replay() -> void:
	var kos := [0]
	rules.ko.connect(func(_b: Node3D, _by: Node, _p: float, _t: String, _l: int) -> void: kos[0] += 1)
	await _throw_at_foe()
	var live: Array = []
	for i in 240:
		if kos[0] > 0:
			break
		if i % 20 == 10 and live.size() < 4:
			live.append(await _grab())
		await physics_frame
	print("  the fall: %d" % kos[0])
	if not live.is_empty():
		_sheet(live, live.size(), 0.5, "r4_viral_replay_live")
	for i in 400:
		if rp.is_playing():
			break
		await process_frame
	if not rp.is_playing():
		print("  no replay started")
		return
	var c := rp.clip()
	var imgs: Array = []
	var last := float(mini(c.splash_t + 20, c.n - 1))
	for k in 12:
		rp.seek(last * float(k) / 11.0)
		imgs.append(await _grab())
	_sheet(imgs, 4, 0.5, "r4_viral_replay_strip")
	rp.skip()
	await _frames(5)
	await _secs(3.0)


func _clashes() -> void:
	var pairs := [["stone", "stone"], ["water", "fire"], ["fire", "ice"], ["air", "water"], ["stone", "fire"], ["air", "fire"]]
	var e := mode.player_end
	_place(p, at_s(e, 6.0, 7.0), at_s(1 - e, 6.0))
	_place(foe, at_s(1 - e, 6.0, -7.0), p.global_position)
	await _secs(0.4)
	var mid := ring.to_global(Vector3(0.0, ring.top() + 2.0, 0.0))
	_side(mid + ring.global_basis.z * 7.5 + Vector3.UP * 1.0, mid)
	for pr: Array in pairs:
		var a: String = pr[0]
		var b: String = pr[1]
		var pa := mid - ring.global_basis.x * 6.0
		var pb := mid + ring.global_basis.x * 6.0
		var d := (pb - pa).normalized()
		var c0 := BendClash.count
		var ba := BendBolt.launch(p, pa, d, {"kind": a, "mps": 18.0, "radius_m": 0.32, "damage": 5.0, "range_m": 30.0})
		var bb := BendBolt.launch(foe, pb, -d, {"kind": b, "mps": 18.0, "radius_m": 0.32, "damage": 5.0, "range_m": 30.0})
		var before: Image = null
		for i in 60:
			if BendClash.count > c0:
				break
			if is_instance_valid(ba) and is_instance_valid(bb) and ba.global_position.distance_to(bb.global_position) < 3.0 and before == null:
				before = await _grab()
			await physics_frame
		await _secs(0.05)
		var at := await _grab()
		await _secs(0.12)
		var later := await _grab()
		var imgs: Array = [at, later] if before == null else [before, at, later]
		_sheet(imgs, imgs.size(), 0.5, "r4_viral_clash_%s_%s" % [a, b])
		for bolt in [ba, bb]:
			if is_instance_valid(bolt) and not (bolt as BendBolt).spent:
				(bolt as BendBolt).end("shot")
		await _secs(1.0)
	_own_cam()


func _callouts() -> void:
	var co := Callouts.find(self)
	var e := mode.player_end
	_place(p, at_s(e, 8.0, 0.0), at_s(1 - e, 8.0))
	_place(foe, at_s(1 - e, 8.0, 0.0), p.global_position)
	_own_cam()
	await _secs(0.5)
	var imgs: Array = []
	var els := {"splash": "earth", "caught": "earth", "perfect": "earth", "rise": "earth", "clash": "fire", "comeback": "earth",
			"last_life": "none"}
	for k: String in ["splash", "caught", "perfect", "rise", "clash", "comeback", "last_life"]:
		await _secs(1.0)
		co.say(k, String(els[k]))
		await _secs(0.2)
		imgs.append(await _grab())
	# (and the other elements' colours on one word)
	for el: String in ["water", "fire", "air"]:
		await _secs(1.0)
		co.say("splash", el)
		await _secs(0.2)
		imgs.append(await _grab())
	_sheet(imgs, 4, 0.4, "r4_viral_callouts")
	await _secs(1.0)


func _photo() -> void:
	var pm := PhotoMode.find(self)
	var e := mode.player_end
	_place(p, at_s(1 - e, 9.0, 1.0), at_s(1 - e, 3.0))
	_place(foe, at_s(1 - e, 6.0, -1.0), p.global_position)
	await _secs(0.6)
	if not pm.enter():
		print("  photo mode did not enter")
		return
	pm.move(Vector3(1.0, 0.0, 0.4), 0.0, 3.0)
	pm.move(Vector3.ZERO, -1.0, 0.8)
	pm.look(Vector2(-260.0, 30.0))
	await _frames(4)
	PhotoMode.set_wordmark(true)
	var a := await pm.take()
	PhotoMode.set_wordmark(false)
	var b := await pm.take()
	PhotoMode.set_wordmark(true)
	pm.leave()
	for pair: Array in [[a, "r4_viral_photo_wordmark"], [b, "r4_viral_photo_plain"]]:
		if String(pair[0]) != "":
			var img := Image.load_from_file(String(pair[0]))
			if img != null:
				_save(img, String(pair[1]))
			DirAccess.remove_absolute(String(pair[0]))
	await _secs(0.5)


## A game played to its end (the foe on his last life, sent into the water) after a few plays, the match screen with its
## cards.
func _cards() -> void:
	var hl := RingHighlights.find(self)
	# (a perfect guard streak and a close catch of the player's, by the tracker's own entry: the guard matrix is the guards' tests')
	hl.offer("catch", 0.07, p, null)
	hl.offer("perfect", 3.0, p, null)
	RingReplay.force = "off"
	rules._sk(foe)["stocks"] = 1
	await _throw_at_foe()
	for i in 600:
		if mode.phase == "DONE":
			break
		await physics_frame
	await _secs(0.5)
	var ms := mode.match_screen as MatchScreen
	var hc := HighlightCards.make(mode)
	ms.get_node("Root").add_child(hc)
	hc.refresh()
	await _frames(6)
	_save(await _grab(), "r4_viral_cards")
	print("  cards: %s" % str(hc.shown.map(func(c: Dictionary) -> String: return "%s | %s | %s" % [c.title, c.line, c.num])))
