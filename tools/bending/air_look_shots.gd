extends SceneTree
## Stills of air's looks in Tidebreak's ring, at the same frozen frames every run (the anime air, 2026-10-16; the owner judges
## by eye: a run at the base and a run after line up as before / after). A practice in scenes/ring.tscn: the air bot, held
## where it stands, is the caster (never the player: his own guard and walls are drawn thinner for his own eye), the player
## stands at the far end as what it casts at. Each look is made by its own call (BendCharge.make, BendBolt.launch,
## BendLooks.blast / beam / burst / carried, BendEffects.dash, BendZone.make) and snapped at fixed frames after it, at 60
## fixed fps so every frame is the same moment. Windowed (it draws), through the lock:
##   zsh tools/loop/godot_run.sh --path . --fixed-fps 60 -s tools/bending/air_look_shots.gd -- out=<dir> [tag=<name>]
##       [only=gather,palm,slice,ball,gust,lance,pull,leap,slip,guard,wall,carried] [light=noon|night]
##       [film=gather|kit]
## Writes <dir>/air_<shot>_<frame>_<tag>.png and <dir>/air_sheet_<tag>.png (four a row). Ends with "AIR SHOTS DONE".
## film=gather|kit instead records frames (30 a second, JPEG) of the caster's own casts (the bot's brain begins each lock, so
## the real clip, the real gather and the real release play) to <dir>/film_<tag>/f_00000.jpg ...; encode them with
## tools/showcase/video_encode.swift (see tools/bending/air_look_film.sh).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const W := 1280
const H := 720
const SHOTS := ["gather", "macro", "palm", "slice", "ball", "gust", "lance", "pull", "leap", "slip", "guard", "wall", "carried"]
## The caster and the target on the deck's long axis (m from its middle).
const C_S := -4.0
const T_S := 4.0

var view
var out := "user://air_shots"
var tag := "now"
var lvl: RingLevel
var rm: RingMode
var caster: NpcFighter
var target: FrontierPlayer
var axis := Vector3.FORWARD
var right := Vector3.RIGHT
var imgs: Array = []
var names: Array = []
var film := ""
var _macro_at := Vector3.INF
var rec := false
var rec_i := 0
var rec_dir := ""
var _tick := 0


func _initialize() -> void:
	var only: Array = SHOTS.duplicate()
	var light := "noon"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("tag="):
			tag = a.substr(4)
		elif a.begins_with("only="):
			only = Array(a.substr(5).split(","))
		elif a.begins_with("light="):
			light = a.substr(6)
		elif a.begins_with("film="):
			film = a.substr(5)
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "air"
	MatchSetup.set_practice("air", "stand")
	MatchSetup.light = light
	change_scene_to_file("res://scenes/ring.tscn")
	await process_frame
	await process_frame
	lvl = current_scene as RingLevel
	rm = RingMode.find(self)
	var waited := 0
	while waited < 60 * 40 and (rm == null or rm.phase != "FIGHT" or LoadingScreen.covering()):
		await process_frame
		waited += 1
		if rm == null:
			rm = RingMode.find(self)
	if rm == null or rm.foe == null:
		print("AIR SHOTS FAILED: no ring mode or no foe")
		quit(1)
		return
	caster = rm.foe
	target = lvl.player
	caster.held = true
	rm.rules.stale_off = true
	var ring := rm.ring
	axis = ring.axis()
	right = axis.cross(Vector3.UP).normalized()
	var c := ring.center()
	RingLevel.place(caster, Transform3D(Basis.looking_at(axis, Vector3.UP), c + axis * C_S + Vector3.UP * 0.05))
	RingLevel.place(target, Transform3D(Basis.looking_at(-axis, Vector3.UP), c + axis * T_S + Vector3.UP * 0.05))
	target.ignore_mouse_capture = true
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(W, H))
	root.disable_3d = true
	view.camera.far = 1500.0
	await _frames(90)
	if film != "":
		rec_dir = out.path_join("film_%s" % tag)
		DirAccess.make_dir_recursive_absolute(rec_dir)
		await call("_film_" + film)
		print("AIR FILM DONE ", tag, " ", rec_i, " frames")
		quit()
		return
	for sh: String in only:
		if sh in SHOTS:
			await call("_" + sh)
			await _clear()
	_sheet()
	print("AIR SHOTS DONE ", tag, " ", imgs.size())
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if rec:
			_grab()


func _grab() -> void:
	_tick += 1
	if _tick % 2 != 0:
		return
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(rec_dir.path_join("f_%05d.jpg" % rec_i), 0.93)
	rec_i += 1


## The caster's place now (his feet), his chest, his facing (flat) and the way across the deck.
func _feet() -> Vector3:
	return caster.global_position


func _chest() -> Vector3:
	return caster.global_position + Vector3.UP * 1.15


func _hand() -> Vector3:
	return caster.global_position + Vector3.UP * 1.2 + axis * 0.4 + right * 0.22


## The camera: "close" three-quarters before the caster (the gather), "cast" across the deck framing the caster and the flight
## (the film), "side" across the deck framing the flight (the stills), "wide" three-quarters a little back (the guard, the wall).
func _cam(kind: String) -> void:
	var eye := Vector3.ZERO
	var look := Vector3.ZERO
	var fov := 50.0
	match kind:
		"close":
			# (the game's own third-person distance or more: nearer than the near fade's 4 m the effects thin out)
			eye = _feet() + axis * 3.4 + right * 2.9 + Vector3.UP * 1.5
			look = _chest() + axis * 0.15
			fov = 30.0
		"macro":
			# (a long lens from the game's distance on the right palm: the ball and the strokes round the arm, close)
			var hand := (_macro_at if _macro_at.is_finite() else _hand())
			eye = hand + (axis * 0.5 + right * 0.9).normalized() * 4.6 + Vector3.UP * 0.25
			look = hand
			fov = 9.0
		"cast":
			eye = _feet() + axis * 4.2 + right * 4.8 + Vector3.UP * 1.6
			look = _feet() + axis * 2.4 + Vector3.UP * 1.1
			fov = 40.0
		"side":
			var mid := _feet() + axis * 3.2
			eye = mid + right * 7.5 + Vector3.UP * 1.7
			look = mid + Vector3.UP * 1.0
			fov = 40.0
		_:
			eye = _feet() + axis * 4.2 + right * 3.2 + Vector3.UP * 2.0
			look = _feet() + Vector3.UP * 1.0
			fov = 48.0
	view.camera.fov = fov
	view.camera.global_transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)


func _snap(name: String) -> void:
	await process_frame
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out.path_join("air_%s_%s.png" % [name, tag]))
	imgs.append(img)
	names.append(name)
	print("shot ", name)


## Everything the shot made gone, and time for its effects to fade.
func _clear(wait := 90) -> void:
	for b in get_nodes_in_group(BendBolt.GROUP):
		(b as BendBolt).end("shots")
	for z in get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind != "pool":
			bz.end("shots")
	for ch in get_nodes_in_group(BendCharge.GROUP):
		(ch as Node).queue_free()
	caster.velocity = Vector3.ZERO
	RingLevel.place(caster, Transform3D(Basis.looking_at(axis, Vector3.UP), rm.ring.center() + axis * C_S + Vector3.UP * 0.05))
	await _frames(wait)


func _spec(id: String, mode: String) -> Dictionary:
	var s: Dictionary = ((SwayMoves.move(id).get("bend", {}) as Dictionary).get(mode, {}) as Dictionary).duplicate(true)
	s.erase("grow")
	return s


# ---------------------------------------------------------------- the shots
## The gather: the lock a quarter, over half and nearly full, the click, and the release's snap.
func _gather() -> void:
	_cam("close")
	var ch := BendCharge.make(caster, "air")
	ch.limb_fn = func() -> String: return "r_palm"
	await _frames(4)
	for e: Array in [[0.25, "025"], [0.6, "060"], [0.95, "095"]]:
		ch.fill = float(e[0])
		await _frames(28)
		await _snap("gather_%s" % e[1])
	ch.fill = 1.0
	ch.full = true
	ch.flash()
	await _frames(5)
	await _snap("gather_full")
	await _frames(20)
	ch.end("cast")
	await _frames(4)
	await _snap("gather_snap")
	await _frames(8)
	await _snap("gather_gone")


## The ball and the strokes round the arm at 0.6 and full, from a long lens (a hand's close-up).
func _macro() -> void:
	var ch := BendCharge.make(caster, "air")
	ch.limb_fn = func() -> String: return "r_palm"
	await _frames(4)
	for e: Array in [[0.6, "060"], [1.0, "full"]]:
		ch.fill = float(e[0])
		ch.full = float(e[0]) >= 1.0
		await _frames(30)
		_macro_at = ch._tip("r_palm")
		_cam("macro")
		await _snap("macro_%s" % e[1])
		await _frames(7)
		await _snap("macro_%s_b" % e[1])
	ch.end("cast")
	await _frames(3)
	_macro_at = ch._tip("r_palm")
	await _snap("macro_snap")
	_macro_at = Vector3.INF


func _palm() -> void:
	_cam("side")
	BendLooks.blast(_hand(), axis, 40.0, 3.5, "air")
	await _frames(3)
	await _snap("palm_f03")
	await _frames(9)
	await _snap("palm_f12")


func _bolt_shots(name: String, spec: Dictionary, f1: int, f2: int) -> void:
	_cam("side")
	var b := BendBolt.launch(caster, _hand(), axis, spec)
	await _frames(f1)
	await _snap("%s_f%02d" % [name, f1])
	await _frames(f2 - f1)
	await _snap("%s_f%02d" % [name, f2])
	if is_instance_valid(b) and not b.spent:
		b.end("shots")


func _slice() -> void:
	await _bolt_shots("slice", _spec("air_blast", "slice"), 4, 9)


func _ball() -> void:
	await _bolt_shots("ball", _spec("air_blast", "ball"), 7, 15)


func _gust() -> void:
	var s := _spec("air_gust", "gust")
	s["kind"] = "air"
	s["long"] = true
	s["radius_m"] = float(s.get("width_m", 2.0)) * 0.5
	await _bolt_shots("gust", s, 10, 22)


func _pull() -> void:
	var s := _spec("air_gust", "pull")
	s["kind"] = "air"
	s["long"] = true
	s["radius_m"] = float(s.get("width_m", 2.0)) * 0.5
	await _bolt_shots("pull", s, 10, 22)


func _lance() -> void:
	_cam("side")
	BendLooks.beam_flash(caster, _hand(), "air")
	await _frames(3)
	await _snap("lance_f03")
	BendLooks.beam(_hand(), target.global_position + Vector3.UP * 1.1, "air")
	await _frames(2)
	await _snap("lance_f05")
	await _frames(7)
	await _snap("lance_f12")


func _dash_shots(name: String, spec: Dictionary, f1: int, f2: int) -> void:
	_cam("wide")
	var bc := BendCaster.wrap(caster)
	caster.held = false
	BendEffects.dash(bc, axis, spec)
	await _frames(f1)
	await _snap("%s_f%02d" % [name, f1])
	await _frames(f2 - f1)
	await _snap("%s_f%02d" % [name, f2])
	await _frames(60)
	caster.held = true


func _leap() -> void:
	await _dash_shots("leap", _spec("air_jump", "leap"), 4, 14)


func _slip() -> void:
	var s := _spec("evade", "slip")
	s.erase("dir")                                 # (a held direction: none here; forward)
	await _dash_shots("slip", s, 4, 12)


func _guard() -> void:
	_cam("wide")
	var z := BendZone.make(caster, "air_shield", caster.global_position, {"radius_m": 2.2, "window_s": 0.8}, axis)
	await _frames(8)
	await _snap("guard_f08")
	await _frames(22)
	await _snap("guard_f30")
	if is_instance_valid(z):
		z.end("shots")
	await _frames(5)
	await _snap("guard_end")


func _wall() -> void:
	_cam("wide")
	var at := caster.global_position + axis * 3.0
	BendZone.make(caster, "wind_wall", at, {"width_m": 3.0, "height_m": 2.0, "thick_m": 0.6, "life_s": 4.0}, axis)
	await _frames(12)
	await _snap("wall_f12")
	await _frames(40)
	await _snap("wall_f52")


func _carried() -> void:
	_cam("wide")
	BendLooks.carried(caster)
	await _frames(3)
	await _snap("carried_f03")
	await _frames(10)
	await _snap("carried_f13")


func _sheet() -> void:
	if imgs.is_empty():
		return
	var cols := 4
	var rows := ceili(imgs.size() / float(cols))
	var hw := W / 2
	var hh := H / 2
	var sheet := Image.create(hw * cols, hh * rows, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		var small := (imgs[i] as Image).duplicate() as Image
		small.resize(hw, hh, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(small, Rect2i(0, 0, hw, hh), Vector2i((i % cols) * hw, (i / cols) * hh))
	sheet.save_png(out.path_join("air_sheet_%s.png" % tag))
	FileAccess.open(out.path_join("air_sheet_%s.txt" % tag), FileAccess.WRITE).store_string("\n".join(PackedStringArray(names)))


# ---------------------------------------------------------------- films
## The caster's own cast of `id`/`md` (the bot's brain begins the lock: the real clip, gather and release), held on `tail`
## frames after it leaves; `slow` the game's speed meanwhile. Waits for the lock to end (at most `cap` s of game time).
func _cast(id: String, md: String, tail := 50, slow := 1.0, cap := 3.0) -> void:
	var nb: NpcBending = caster.brain.bending if caster.brain != null else null
	if nb == null:
		return
	Engine.time_scale = slow
	nb.begin(id, md)
	var t := 0.0
	while nb.casting != "" and t < cap:
		await _frames(1)
		t += 1.0 / 60.0 * slow
	await _frames(tail)
	Engine.time_scale = 1.0
	for b in get_nodes_in_group(BendBolt.GROUP):
		(b as BendBolt).end("film")


func _film_gather() -> void:
	rec = true
	_cam("close")
	await _frames(20)
	await _cast("air_blast", "slice", 30, 0.35)         # (the Slice at a third of the speed: the gather and its snap)
	await _clear(20)
	_cam("close")
	await _cast("air_blast", "ball", 40, 0.35)
	await _clear(20)
	_cam("cast")
	await _cast("air_blast", "slice", 45)               # (as played)
	await _clear(20)
	_cam("cast")
	await _cast("air_blast", "ball", 55)
	await _clear(20)
	_cam("cast")
	await _cast("air_palm", "palm", 40)
	await _clear(20)
	_cam("cast")
	await _cast("air_gust", "gust", 60)
	rec = false


func _film_kit() -> void:
	rec = true
	for e: Array in [["air_palm", "palm", 40], ["air_blast", "slice", 45], ["air_blast", "ball", 60], ["air_gust", "gust", 70],
			["air_gust", "pull", 70]]:
		_cam("cast")
		await _frames(15)
		await _cast(String(e[0]), String(e[1]), int(e[2]))
		await _clear(12)
	rec = false
