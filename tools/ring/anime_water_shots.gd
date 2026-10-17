extends SceneTree
## Stills of water's gather and casts for the anime-water pass (the owner, 2026-10-16: each element's effects "as close to
## Anime Style Avatar: The Last Airbender as possible"; he judges by eye): the ring in practice, water against a standing
## water dummy, the player set by a grate (the water's source) facing down the deck; each shot a move readied on the player's
## own hotbar, its lock held through his own caster and let go, captured at the same fills and the same ticks every run
## (--fixed-fps 60), so a "before" (the base) and an "after" line up frame for frame. Windowed (it draws), off-window
## (OffscreenView). Nothing of the game is changed: a tool run only.
##   Godot --path . --fixed-fps 60 -s tools/ring/anime_water_shots.gd -- out=<dir> tag=<before|after> [only=gather_lash,...]
##        [cam=side|front|wide] [film=<dir>]
## film=<dir>: the shots (only=) played back to back, each from its own camera (TAKE_CAMS) and every second physics frame
## (30 a second) saved to <dir>/frame_NNNNN.png, for tools/showcase/video_encode.swift (encode <dir> 30 <out.mp4>).
## Writes <dir>/<shot>_<nn>_<tag>.png per frame and <dir>/<shot>_strip_<tag>.png (its frames in a row, half size).
## Shots (SHOTS): gather_lash (key 1 held: the water drawn to the hands, the click, the Lash let go), gather_geyser (key 2's
## Geyser: the water run along the deck to its place, the column), splash (the jab), lash (the Lash in flight and its hit),
## wave (the Wave's front), spear (the Spear held and thrown), ice_wall (key 4), turn (E on the dummy's Lash), skate (Shift
## back: its water and puddles).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const W := 1280
const H := 720
## Each shot: the key readied (0-based hotbar slot; -1 the jab, -2 the guard, -3 Shift+back), the mode set on it ("" its first),
## the fills captured while the lock is held, the ticks after it is full, and the ticks after the release captured.
const SHOTS := {
	"gather_lash": {"key": 0, "mode": "", "fills": [0.2, 0.45, 0.7, 0.92], "full": [12], "after": [3, 8, 16, 30]},
	"gather_geyser": {"key": 1, "mode": "spout", "fills": [0.25, 0.5, 0.75, 0.95], "full": [12], "after": [4, 12, 26, 45, 70]},
	"splash": {"key": 0, "move": "water_jet", "mode": "splash", "fills": [0.9], "full": [4], "after": [6, 9, 11, 13, 15, 18, 22, 30]},
	"splash_hit": {"key": 0, "move": "water_jet", "mode": "splash", "fills": [], "full": [4], "rel": [-8, -4, -1, 1, 3, 6, 10, 16], "cam": "hit"},
	"lash": {"key": 0, "mode": "", "fills": [0.9], "full": [6], "after": [6, 9, 11, 13, 15, 18, 22, 28, 40]},
	"lash_hit": {"key": 0, "mode": "", "fills": [], "full": [6], "rel": [-8, -4, -1, 1, 3, 6, 10, 16], "cam": "hit"},
	"wave": {"key": 1, "mode": "", "fills": [0.9], "full": [6], "after": [4, 10, 18, 28, 40, 60]},
	"spear": {"key": 0, "taps": 2, "mode": "", "fills": [0.3, 0.7, 0.95], "full": [8], "after": [3, 8, 14, 24]},
	"spear_hit": {"key": 0, "taps": 2, "mode": "", "fills": [], "full": [8], "rel": [-8, -4, -1, 1, 3, 6, 10, 16], "cam": "hit"},
	"ice_wall": {"key": 3, "move": "water_shield", "mode": "ice_wall", "fills": [0.5], "full": [4], "after": [4, 10, 20, 40, 80]},
	"skate": {"key": -3, "mode": "", "fills": [], "full": [], "after": [4, 10, 18, 30, 50, 90]},
	"turn": {"key": -2, "mode": "", "fills": [], "full": [], "after": [2, 6, 10, 14, 18, 24, 32]},
}
## The camera each shot is filmed from in film mode (the stills' own: cam=).
const TAKE_CAMS := {"gather_lash": "side", "gather_geyser": "wide", "splash": "side", "splash_hit": "wide", "lash": "side",
		"lash_hit": "wide", "wave": "wide", "spear": "side", "spear_hit": "wide", "ice_wall": "wide", "skate": "wide", "turn": "front"}
const ORDER := ["gather_lash", "gather_geyser", "splash", "splash_hit", "lash", "lash_hit", "wave", "spear", "spear_hit", "ice_wall", "skate", "turn"]

var view
var out := "user://anime_water"
var tag := "now"
var cam_mode := "side"
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var rm: RingMode
var home := Transform3D.IDENTITY
var fwd := Vector3.FORWARD
var right := Vector3.RIGHT
var frames: Array[Image] = []
var shot := ""
var n := 0
var aiming := false
var pitch_sign := 1.0
var film := ""
var _film_n := 0
var _film_phys := 0


func _initialize() -> void:
	var only: Array = ORDER.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("tag="):
			tag = a.substr(4)
		elif a.begins_with("only="):
			only = Array(a.substr(5).split(","))
		elif a.begins_with("cam="):
			cam_mode = a.substr(4)
		elif a.begins_with("film="):
			film = a.substr(5)
	DirAccess.make_dir_recursive_absolute(out)
	if film != "":
		DirAccess.make_dir_recursive_absolute(film)
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "water"
	MatchSetup.light = "noon"
	MatchSetup.set_practice("water", "stand")
	RingReplay.force = "off"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred(only)


func _ticks(k: int) -> void:
	for i in k:
		await physics_frame
		_film_tick()


## Film mode: every second physics frame saved (30 a second).
func _film_tick() -> void:
	if film == "" or view == null:
		return
	_film_phys += 1
	if _film_phys % 2 != 0:
		return
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(film.path_join("frame_%05d.png" % _film_n))
	_film_n += 1


func _until(cond: Callable, s: float) -> bool:
	var left := int(s * 60.0)
	while left > 0:
		if cond.call():
			return true
		await physics_frame
		_film_tick()
		left -= 1
	return bool(cond.call())


func _action(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)
		await _ticks(2)


func _run(only: Array) -> void:
	for i in 20:
		await process_frame
	lvl = current_scene as RingLevel
	p = lvl.player
	p.ignore_mouse_capture = true
	c = SwayCaster.of(p)
	rm = RingMode.find(self)
	await _until(func() -> bool: return rm.phase == "FIGHT" and p.hotbar.spell != "" and not LoadingScreen.covering(), 30.0)
	if rm.foe != null:
		rm.foe.held = true
	var ring := rm.ring
	fwd = ring.axis()
	right = fwd.cross(Vector3.UP).normalized()
	# (the player by the first grate on his side: 1.6 m short of it, the grate ahead of him, the dummy down the deck)
	var g := ring.grates[0] as Node3D
	var gp := g.global_position
	var to_c := ring.center() - gp
	to_c.y = 0.0
	var dir := to_c.normalized()
	if dir.dot(fwd) < 0.0:
		fwd = -fwd
		right = -right
	home = Transform3D(Basis.looking_at(fwd, Vector3.UP), gp - fwd * 1.6 + Vector3.UP * (p.global_position.y - ring.top()) * 0.0)
	home.origin.y = ring.top()
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(W, H))
	root.disable_3d = true
	view.camera.fov = 48.0
	_place()
	await _ticks(30)
	p.pitch = 0.3
	await _ticks(3)
	pitch_sign = 1.0 if (-p.camera.global_basis.z).y > 0.0 else -1.0
	physics_frame.connect(_aim)
	for s: String in ORDER:
		if not s in only or not SHOTS.has(s):
			continue
		await _shot(s, SHOTS[s])
	print("ANIME WATER SHOTS DONE %s (%d film frames)" % [tag, _film_n])
	quit()


## A hit shot: the crosshair held on the dummy's chest (the tests' way: yaw and pitch from the camera to him).
func _aim() -> void:
	if not aiming or rm == null or rm.foe == null or not is_instance_valid(rm.foe) or p.camera == null:
		return
	var d := (NpcSenses.chest_of(rm.foe) - p.camera.global_position).normalized()
	p.yaw = atan2(-d.x, -d.z)
	p.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign


func _place() -> void:
	RingLevel.place(p, home)
	p.velocity = Vector3.ZERO
	_cam()


func _cam() -> void:
	var at := home.origin
	var eye: Vector3
	var look: Vector3
	match cam_mode:
		"front":
			eye = at + fwd * 3.6 + right * 1.2 + Vector3.UP * 1.5
			look = at + Vector3.UP * 1.0
		"wide":
			eye = at + right * 7.5 + fwd * 4.0 + Vector3.UP * 2.6
			look = at + fwd * 4.5 + Vector3.UP * 0.8
		"hit":
			# (the dummy 6.5 m down the line of fire, from before him and to one side)
			var tgt := at + fwd * 6.5
			eye = tgt - fwd * 3.4 + right * 3.8 + Vector3.UP * 1.6
			look = tgt + Vector3.UP * 1.0
		_:
			eye = at + right * 3.6 + fwd * 1.5 + Vector3.UP * 1.55
			look = at + fwd * 0.9 + Vector3.UP * 0.95
	view.camera.global_transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)


func _grab(what: String) -> void:
	if film != "":
		return
	await process_frame
	await process_frame
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out.path_join("%s_%02d_%s_%s.png" % [shot, n, what, tag]))
	frames.append(img)
	n += 1


func _strip() -> void:
	if frames.is_empty():
		return
	var hw := W / 2
	var hh := H / 2
	var sheet := Image.create(hw * frames.size(), hh, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var small := frames[i].duplicate() as Image
		small.resize(hw, hh, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(small, Rect2i(0, 0, hw, hh), Vector2i(i * hw, 0))
	sheet.save_png(out.path_join("%s_strip_%s.png" % [shot, tag]))
	frames.clear()


## Hit shots: every tick after the release recorded, the moment the bolts are gone (the hit) found, and the frames at `rel` ticks
## from it saved (m = before, p = after: m04, p00, p06).
func _rel_frames(rel: Array) -> void:
	var buf: Array[Image] = []
	var hit := -1
	var had := false
	for i in 90:
		await physics_frame
		_film_tick()
		var img: Image = view.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		buf.append(img)
		var n_bolts := get_nodes_in_group(&"bend_bolts").size()
		if n_bolts > 0:
			had = true
		elif had and hit < 0:
			hit = i
		if hit >= 0 and i >= hit + int(rel[rel.size() - 1]):
			break
	if hit < 0:
		print("ANIME WATER no hit seen in %s" % shot)
		hit = buf.size() / 2
	for off: int in rel:
		var j := clampi(hit + off, 0, buf.size() - 1)
		var label := "%s%02d" % ["m" if off < 0 else "p", absi(off)]
		buf[j].save_png(out.path_join("%s_%02d_%s_%s.png" % [shot, n, label, tag]))
		frames.append(buf[j])
		n += 1


func _shot(name: String, d: Dictionary) -> void:
	shot = name
	n = 0
	if film != "":
		cam_mode = String(TAKE_CAMS.get(name, cam_mode))
	elif d.has("cam"):
		cam_mode = String(d.cam)
	else:
		cam_mode = "side"
	_place()
	c.held_override = null
	aiming = name.ends_with("_hit")
	if name.ends_with("_hit") and rm.foe != null and is_instance_valid(rm.foe):
		# (the dummy on the line of fire, 6.5 m down the deck, facing him: the hit is seen)
		rm.foe.global_position = Vector3(home.origin.x, home.origin.y, home.origin.z) + fwd * 6.5
		rm.foe.velocity = Vector3.ZERO
		rm.foe.face_point(p.global_position)
	await _ticks(20)
	var key := int(d.key)
	if key >= 0:
		if d.has("move"):
			p.hotbar.ready_move(key, String(d.move), String(d.mode))
		else:
			for t in int(d.get("taps", 1)):
				p.hotbar.select(key)
				await _ticks(2)
		await _ticks(2)
		if String(d.mode) != "" and not d.has("move"):
			c.set_mode(p.hotbar.spell, String(d.mode))
		await _ticks(4)
		c.held_override = true
		for f: float in d.fills:
			await _until(func() -> bool: return c.fill >= f or c.state == SwayCaster.State.FULL, 4.0)
			await _grab("fill%02d" % int(round(f * 100.0)))
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 4.0)
		var t := 0
		for k: int in d.full:
			await _ticks(k - t)
			t = k
			await _grab("full%02d" % k)
		c.held_override = false
	elif key == -1:
		await _action(&"fire")
	elif key == -2:
		# (the Turn: the dummy told to throw its Lash (its lock, then the flight), E pressed as it comes)
		var bend: Variant = rm._foe_bending()
		if rm.practice_ctl != null and bend != null:
			rm.practice_ctl._dummy_cast(bend, "water_whip/whip")
		await _ticks(30)
		await _action(InputSetup.GUARD_ACTION)
	else:
		# (Shift + back: the Skate)
		Input.action_press(&"move_back")
		await _action(&"sprint")
		await _ticks(2)
		Input.action_release(&"move_back")
	if d.has("rel"):
		await _rel_frames(d.rel)
	var t2 := 0
	for k: int in d.get("after", []):
		await _ticks(k - t2)
		t2 = k
		await _grab("after%02d" % k)
	c.held_override = null
	await _ticks(40 if film != "" else 90)
	_strip()
	print("ANIME WATER SHOT %s %d frames" % [name, n])
