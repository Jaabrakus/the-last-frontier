extends SceneTree
## Stills of earth's gather (the owner, 2026-10-16: "as close to Anime Style Avatar: The Last Airbender as possible"; BendCharge's
## earth section): a practice ring, earth against a standing earth dummy, our own camera close beside the player (every
## CanvasLayer hidden), time slowed so a still falls on the fill asked for. The real locks, held as a player holds them:
## key 2 (the Fissure's, slabs torn from the deck and channelled to the hand) at fills 0.06, 0.2, 0.34, 0.55, 0.85 and full, key 1
## (the Spike: the stone raised at 0.6 and built from the slabs), key 1 twice (the Boulder), and the Boulder held on until it grows.
## Windowed (a normal window, never on top):
##   zsh tools/loop/godot_run.sh --path . --resolution 1280x720 -s tools/ring/earth_gather_shots.gd -- out=<dir> [tag=after] [light=noon]
## Writes <dir>/gather_<moment>_<tag>.png and <dir>/gather_sheet_<tag>.png. Ends with EARTH GATHER SHOTS DONE.
## film=1: no stills; the same locks played at normal speed for the movie writer (--fixed-fps 60 --write-movie <dir>/raw.avi),
## each cast to the end with its caption, the Fissure again at 0.3 speed; cam=near (beside him) or cam=wide (behind and aside,
## the dummy in front). Then: ffmpeg -i raw.avi -c:v libx264 -pix_fmt yuv420p gather_<tag>.mp4. Ends with EARTH GATHER FILM DONE.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OWN_CFG := "user://earth_gather_shots.cfg"
const SLOW := 0.05

var out := "user://earth_gather"
var tag := "after"
var p: FrontierPlayer
var c: SwayCaster
var cam: Camera3D
var shots: Array[Image] = []
var film := false
var cam_kind := "near"
var caption: Label


func _initialize() -> void:
	var a := CaptureKit.args({"out": out, "tag": tag, "light": "noon", "film": "off", "cam": "near", "public": "on"})
	film = String(a["film"]) in ["1", "on", "true"]
	if String(a.get("public", "on")) == "on":
		SbFx.force_on = false                      # (our own effects only: the Fissure's Spellbreak shockwave off, as the posts'; public=off keeps it)
	cam_kind = String(a["cam"])
	out = String(a["out"])
	tag = String(a["tag"])
	CaptureKit.window()
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	InputSetup.ensure()
	SwayCaster.free_override = true
	RingReplay.force = "off"
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "earth"
	MatchSetup.light = String(a["light"])
	MatchSetup._aim_help = "off"
	MatchSetup.set_practice("earth", "stand")
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 4:
		await process_frame
	var lvl := current_scene as RingLevel
	var loaded: bool = lvl != null and await CaptureKit.wait_loaded(self, lvl)
	var mode := RingMode.find(self)
	p = lvl.player if lvl != null else null
	if not loaded or mode == null or mode.foe == null or p == null:
		print("EARTH GATHER SHOTS FAILED: no practice")
		return _quit(1)
	c = SwayCaster.of(p)
	p.ignore_mouse_capture = true
	await CaptureKit.secs(self, 2.0)
	var foe := mode.foe
	foe.held = true
	var away := (p.global_position - foe.global_position) * Vector3(1, 0, 1)
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	var at := foe.global_position + away * 8.0
	at.y = p.global_position.y
	RingLevel.place(p, Transform3D(Basis.looking_at(-away, Vector3.UP), at))
	p.yaw = atan2(away.x, away.z)
	await CaptureKit.secs(self, 0.6)
	# (our own camera: close beside him, a little in front, looking at his chest, so the slabs and the hand are in it)
	var toward := -away
	var right := toward.cross(Vector3.UP).normalized()
	cam = Camera3D.new()
	cam.fov = 34.0
	cam.far = 400.0
	current_scene.add_child(cam)
	var eye := at + right * 5.6 + toward * 0.2 + Vector3.UP * 1.5
	var look := at + Vector3.UP * 1.0 + toward * 0.9
	if cam_kind == "wide":
		cam.fov = 48.0
		eye = at + right * 6.5 - toward * 2.5 + Vector3.UP * 2.2
		look = at + toward * 3.5 + Vector3.UP * 1.0
	cam.global_transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
	cam.current = true
	if film:
		await _film(foe)
		return
	Engine.time_scale = SLOW
	# ---- the Fissure's lock (key 2): torn slabs, channelled to the hand
	await _key(&"weapon_2")
	c.held_override = true
	for pair: Array in [["a_crack", 0.06], ["b_snap", 0.17], ["c_up", 0.3], ["d_orbit", 0.55], ["e_channel", 0.85]]:
		await CaptureKit.until(self, func() -> bool: return c.fill >= float(pair[1]) or c.state == SwayCaster.State.FULL, 6.0)
		await _shot("fissure_" + String(pair[0]))
	await CaptureKit.until(self, func() -> bool: return c.state == SwayCaster.State.FULL, 6.0)
	await _shot("fissure_f_full")
	c.held_override = false
	await CaptureKit.secs(self, 0.5)
	await CaptureKit.frames(self, 30)
	# ---- the Spike (key 1)
	await _key(&"weapon_1")
	c.held_override = true
	await CaptureKit.until(self, func() -> bool: return c.fill >= 0.7, 6.0)
	_report("spike")
	await _shot("spike_a_building")
	await CaptureKit.until(self, func() -> bool: return c.state == SwayCaster.State.FULL, 6.0)
	await _shot("spike_b_full")
	c.held_override = false
	await CaptureKit.frames(self, 90)
	# ---- the Boulder (key 1 twice), then held on until it grows
	await _key(&"weapon_1")
	await _key(&"weapon_1")
	c.held_override = true
	await CaptureKit.until(self, func() -> bool: return c.fill >= 0.7, 6.0)
	_report("boulder")
	await _shot("boulder_a_building")
	await CaptureKit.until(self, func() -> bool: return c.state == SwayCaster.State.FULL, 6.0)
	await _shot("boulder_b_full")
	var th := FormEffects.raised_of(p)
	if th != null:
		FormEffects.grow_raised(th, "stone_form", "cannonball")
		await CaptureKit.secs(self, 0.12)
		await _shot("boulder_c_grow")
		await CaptureKit.secs(self, 0.5)
		await _shot("boulder_d_grown")
	c.held_override = false
	Engine.time_scale = 1.0
	_sheet()
	print("EARTH GATHER SHOTS DONE")
	_quit(0)


## The film: each lock held to full and cast at the dummy, at normal speed, the Fissure again slowed; captions on.
func _film(foe: Node3D) -> void:
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(24, 18)
	caption.add_theme_font_size_override("font_size", 30)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(caption)
	await _gsecs(1.0)
	await _film_fissure("KEY 2  ·  Fissure  ·  the gather", 1.0)
	await _film_spike("KEY 1  ·  Spike  ·  built from the slabs")
	await _film_boulder("KEY 1 twice  ·  Boulder  ·  held on until it grows")
	await _film_fissure("Fissure again, slowed to 0.3", 0.3)
	caption.text = ""
	Engine.time_scale = 1.0
	await _gsecs(0.5)
	print("EARTH GATHER FILM DONE")
	_quit(0)


func _hold_to_full(t: float) -> void:
	c.held_override = true
	var n := 0
	while c.state != SwayCaster.State.FULL and n < 1500:
		await process_frame
		n += 1
	await _gsecs(t)


func _film_fissure(text: String, speed: float) -> void:
	caption.text = text
	Engine.time_scale = speed
	await _key(&"weapon_2")
	await _hold_to_full(0.15)
	c.held_override = false
	await _gsecs(1.8)
	Engine.time_scale = 1.0
	await _gsecs(0.4)


func _film_spike(text: String) -> void:
	caption.text = text
	await _key(&"weapon_1")
	await _hold_to_full(0.2)
	c.held_override = false
	await _gsecs(2.2)


func _film_boulder(text: String) -> void:
	caption.text = text
	await _key(&"weapon_1")
	await _key(&"weapon_1")
	await _hold_to_full(0.1)
	var th := FormEffects.raised_of(p)
	if th != null:
		FormEffects.grow_raised(th, "stone_form", "cannonball")
	await _gsecs(0.9)
	c.held_override = false
	await _gsecs(2.4)


## `s` seconds of game time, counted in frames (the movie writer's frames are fixed steps, wall time means nothing).
func _gsecs(s: float) -> void:
	var n := int(ceil(s * 60.0 / maxf(Engine.time_scale, 0.05)))
	for i in n:
		await process_frame


## The raised stone's state, printed (a shot with no stone in it: was one raised, where, how big).
func _report(what: String) -> void:
	var th := FormEffects.raised_of(p)
	var st: FormStone = th.stone if th != null else null
	print("  ", what, " move ", c.move, " raised ", th != null, " stone ", (st.kind + " at " + str(st.global_position) + " scale " + str(st.mesh_instance.scale)) if st != null else "none")


func _key(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)
		for i in 3:
			await physics_frame


func _shot(moment: String) -> void:
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	await CaptureKit.drawn(self)
	var img := root.get_texture().get_image()
	print("  shot ", CaptureKit.save(img, out, "gather_%s_%s" % [moment, tag]), "  fill %.2f" % (c.fill if c != null else -1.0))
	shots.append(img)


## The stills three across, small: one sheet to look at.
func _sheet() -> void:
	if shots.is_empty():
		return
	var cols := 3
	var w := 640
	var h := 360
	var rows := ceili(shots.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		var small := shots[i].duplicate() as Image
		small.convert(Image.FORMAT_RGB8)
		small.resize(w, h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(small, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(out.path_join("gather_sheet_%s.png" % tag))


func _quit(code: int) -> void:
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	quit(code)
