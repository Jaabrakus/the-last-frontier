extends SceneTree
## Stills of fire's whole kit for the owner's eye (2026-10-16: the elements' effects redone in the cel style of 2D animation;
## fire's gather and casts): a Practice ring, the player as fire against a standing fire dummy 8 m off, every move cast
## through the player's own keys as the game plays it (the key pressed, the aim held until the lock fills, let go; the grown
## Fireball held on until it grows; key 3's Step by Shift and a direction, the Jets by the direction twice; the Parry's E
## held as the dummy's punch comes), the same frozen moments every run, so a "before" and an "after" line up:
##   lock 25%, lock full, let go +4 frames (the snap), +12 (the cast leaving), +30 (its flight, its hit at 8 m), +60 (what
##   it leaves: smoke, scorch, the wall standing), +90 (the Breath's cone: its strike comes late)
## from three cameras: close beside the player (the gather on the limb, the strike), wide across the deck (the flight and
## the hit, both in the picture), and the player's own camera. A strip of the Punch's and the Kick's gathers frame by frame
## (every 4 frames from the lock's start past the strike). Windowed (it draws; never on top: CaptureKit), 60 ticks a second:
##   zsh tools/loop/godot_run.sh --path . --resolution 1280x720 --fixed-fps 60 -s tools/bending/fire_review.gd -- \
##       out=<dir> tag=before|after [only=punch,kick] [views=close,wide,game] [light=noon|night]
## Writes <dir>/<take>_<view>_<moment>_<tag>.png, the sheets <dir>/fire_<view>_<tag>.png (a row a take, a column a moment)
## and <dir>/gather_strip_<tag>.png; prints FIRE REVIEW DONE. Nothing of the game's files is written.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
## [take, how, move, mode, grown] (how: "cast" the key and the aim held; "key3" Shift + a direction (tap 2: twice); "guard" E
## held against the dummy's punch)
const TAKES := [
	["embers", "direct", "fire_jab", "embers", false],
	["punch", "cast", "fire_blast", "punch", false],
	["fireball", "cast", "fire_blast", "punch", true],
	["kick", "cast", "fire_kick", "kick", false],
	["high_kick", "cast", "fire_kick", "high_kick", false],
	["breath", "cast", "fire_breath", "breath", false],
	["wall", "cast", "fire_wall", "wall", false],
	["step", "key3", "footwork", "step", false],
	["jets", "key3", "fire_jets", "jets", false],
	["parry", "guard", "fire_parry", "parry", false],
]
const LABELS := {"embers": "Embers (LMB)", "punch": "Punch (1)", "fireball": "Fireball (1 held)", "kick": "Kick (2)",
		"high_kick": "High Kick (2 x2)", "breath": "Breath (4 x2)", "wall": "Fire Wall (4)", "step": "Step (Shift+W)",
		"jets": "Jets (Shift+W x2)", "parry": "Parry (E)"}
## The moments: [name, when] (when: "lock25" the lock a quarter full, "full" the lock full, else frames after the release).
const MOMENTS := [["lock25", "lock25"], ["full", "full"], ["go4", 4], ["go12", 12], ["go30", 30], ["go60", 60], ["go90", 90]]
const MOMENT_LABELS := ["lock 25%", "lock full", "let go +4 f", "+12 f", "+30 f", "+60 f", "+90 f"]
## The gather strip's takes and its frame step.
const STRIP_TAKES := ["punch", "kick"]
const STRIP_EVERY := 4
const STRIP_N := 14
## A film's take runs this many frames past the release.
const FILM_TAIL := 100
const CELL := Vector2i(400, 225)
const STRIP_CELL := Vector2i(300, 169)
## The close camera: beside the player, this far across, this high over his feet, a little ahead of him.
const CLOSE_SIDE := 4.3
const CLOSE_UP := 1.25
const CLOSE_AHEAD := 1.0
## The wide camera: across the deck from the middle between the two, framing both.
const WIDE_SIDE := 6.0
const WIDE_UP := 1.5
const WIDE_FOV := 50.0

var out := "user://fire_review"
var tag := "now"
var only: Array = []
var views: Array = ["close", "wide", "game"]
var st: FxStage
var cam: Camera3D
var view := "close"
var _ctl: PlayerControls
var _shots := {}          ## "<take>_<view>_<moment>" -> Image
## film=<dir>: every frame of the recorded stretch of each take (the key pressed to 60 frames after the release) saved as a jpg
## there (the first view only), a caption naming the take over it: tools/bending/fire_film.sh encodes them.
var film_dir := ""
var _rec := false
var _n_film := 0
var _cap: Label
var _cap_layer: CanvasLayer
var _strip := {}          ## take -> Array[Image]


func _initialize() -> void:
	var a := CaptureKit.args({"out": out, "tag": tag, "only": "", "views": "close,wide,game", "light": "noon", "film": ""})
	film_dir = String(a.film)
	out = String(a.out)
	tag = String(a.tag)
	only = Array(String(a.only).split(",", false))
	views = Array(String(a.views).split(",", false))
	if not CaptureKit.begin(self, "FIRE REVIEW", out, true):
		return
	create_timer(1500.0, true, false, true).timeout.connect(func() -> void:
		print("FIRE REVIEW FAILED (watchdog)")
		quit(2))
	SbFx.force_on = false
	MatchSetup.light = String(a.light)
	st = FxStage.new(self)
	st.keeper = _keep
	st.start("fire")
	_run.call_deferred()


func _run() -> void:
	if not await st.wait_fight():
		print("FIRE REVIEW FAILED: no practice fight")
		quit(1)
		return
	await st.calibrate_pitch()
	_ctl = st.p.controls
	st.hide_ui()
	if film_dir != "":
		DirAccess.make_dir_recursive_absolute(film_dir)
		var layer := CanvasLayer.new()
		layer.layer = 120
		_cap_layer = layer
		_cap = Label.new()
		_cap.position = Vector2(24, 18)
		_cap.add_theme_font_size_override("font_size", 30)
		_cap.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		_cap.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
		_cap.add_theme_constant_override("outline_size", 8)
		layer.add_child(_cap)
		root.add_child(layer)
		views = [views[0]]
	for v: String in views:
		view = v
		var cells: Array = []
		var rows: Array = []
		for t: Array in TAKES:
			var take := String(t[0])
			if not only.is_empty() and not take in only:
				continue
			await _take(t)
			var row: Array = []
			for m: Array in MOMENTS:
				var key := "%s_%s_%s" % [take, v, m[0]]
				row.append(_small(_shots.get(key), CELL))
			cells.append(row)
			rows.append(String(LABELS.get(take, take)))
		if not cells.is_empty():
			await st.sheet(cells, rows, MOMENT_LABELS, CELL, out.path_join("fire_%s_%s.png" % [v, tag]), [], 170)
	if "close" in views:
		var cells2: Array = []
		var rows2: Array = []
		for take: String in STRIP_TAKES:
			if not _strip.has(take):
				continue
			var row: Array = []
			for img: Image in _strip[take]:
				row.append(_small(img, STRIP_CELL))
			cells2.append(row)
			rows2.append("%s gather" % String(LABELS.get(take, take)))
		if not cells2.is_empty():
			var cols: Array = []
			for i in STRIP_N:
				cols.append("f %d" % (i * STRIP_EVERY))
			await st.sheet(cells2, rows2, cols, STRIP_CELL, out.path_join("gather_strip_%s.png" % tag), [], 150)
	print("FIRE REVIEW DONE -> ", out)
	quit(0)


func _small(img: Image, cell: Vector2i) -> Image:
	if img == null:
		var blank := Image.create(cell.x, cell.y, false, Image.FORMAT_RGB8)
		blank.fill(Color(0.15, 0.1, 0.1))
		return blank
	var s := img.duplicate() as Image
	s.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
	return s


## The camera of the view in force, kept every frame: close beside the player, wide across the deck, or his own.
func _keep() -> void:
	var p := st.p
	if p == null:
		return
	if view == "game":
		if p.camera != null and root.get_camera_3d() != p.camera:
			p.camera.make_current()
		return
	if cam == null:
		cam = Camera3D.new()
		cam.far = 1500.0
		current_scene.add_child(cam)
	var side := Vector3.UP.cross(st.axis).normalized()
	if view == "close":
		cam.fov = 48.0
		var chest := p.global_position + Vector3.UP * 1.0
		var eye := chest + side * CLOSE_SIDE + st.axis * CLOSE_AHEAD + Vector3.UP * (CLOSE_UP - 1.0)
		cam.global_transform = Transform3D(Basis.looking_at(chest + st.axis * 0.9 - eye, Vector3.UP), eye)
	else:
		cam.fov = WIDE_FOV
		var mid := st.mid + Vector3.UP * 1.0
		var eye := mid + side * WIDE_SIDE + Vector3.UP * (WIDE_UP - 1.0) - st.axis * 0.5
		cam.global_transform = Transform3D(Basis.looking_at(mid - eye, Vector3.UP), eye)
	if root.get_camera_3d() != cam:
		cam.make_current()


## One take: its cast through the keys, its moments and (a strip take, the close view) its strip saved.
func _take(t: Array) -> void:
	var take := String(t[0])
	var how := String(t[1])
	var m := String(t[2])
	var md := String(t[3])
	var grown := bool(t[4])
	await st.reset()
	st.hide_ui()
	st.aiming = true
	var sc := st.sway
	sc.held_override = null
	sc.drop_all()
	await st.frames(30)
	_rec = film_dir != ""
	if _cap_layer != null:
		_cap_layer.visible = true                  # (st.hide_ui hid every layer, the caption's too)
	if _cap != null:
		_cap.text = String(LABELS.get(take, take))
	var strip := take in STRIP_TAKES and view == "close"
	var frames_in: Array = []
	var got := {}
	var f0 := st.frame
	match how:
		"cast":
			# (a move with no key of its own (Embers, the jab) is readied over key 1, the hotbar put back there first: a later
			# camera's pass came after the Fire Wall's key, and the aim held cast the wall)
			var act := &"aim"
			await _ready_move(sc, m, md)
			_ctl.set_held(act, true)
			f0 = st.frame
			var seen25 := false
			var n := 0
			while n < 240:
				await _f(1)
				n += 1
				if strip and (st.frame - f0) % STRIP_EVERY == 0 and frames_in.size() < STRIP_N:
					frames_in.append(_grab())
				if not seen25 and sc.fill >= 0.25:
					seen25 = true
					got["lock25"] = _grab()
				if sc.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING]:
					break
			await _f(2)
			got["full"] = _grab()
			if grown:
				var g := 0
				while g < 200 and not sc.grown:
					await _f(1)
					g += 1
				await _f(9)
			_ctl.set_held(act, false)
		"direct":
			# (Embers: the jab has no key of its own and the aim hold casts the hotbar's key (the Punch), so it is cast as the game lands
			# a move, BendCast.cast with the crosshair on the dummy; its look is the effect's, no gather)
			got["lock25"] = _grab()
			await _f(4)
			got["full"] = _grab()
			if film_dir != "":
				await _f(8)
			BendCast.cast(st.bc, m, md)
		"key3":
			# (Step and Jets cast as the game lands a dash: BendCast.cast with the direction held; the keys' chord (Shift + W) is
			# the player's way, tools/ring/move_reel.gd, and its timing did not reach the dash here)
			got["lock25"] = _grab()
			_ctl.set_held(&"move_forward", true)
			await _f(3)
			got["full"] = _grab()
			BendCast.cast(st.bc, m, md)
			await _f(20)
			_ctl.set_held(&"move_forward", false)
		"guard":
			got["lock25"] = _grab()
			_ctl.set_held(InputSetup.GUARD_ACTION, true)
			await _f(3)
			got["full"] = _grab()
			# (the dummy's punch at his chest as the guard stands, 8 m at 32 m/s: it meets the Parry in its beat)
			var foe: Node3D = st.mode.foe
			if foe != null and is_instance_valid(foe):
				var spec: Dictionary = ((SwayMoves.move("fire_blast").get("bend", {}) as Dictionary).get("punch", {}) as Dictionary).duplicate(true)
				var from := foe.global_position + Vector3.UP * 1.2
				var to := st.p.global_position + Vector3.UP * 1.1
				BendBolt.launch(foe, from, to - from, spec)
	var f1 := st.frame
	var k := 0
	var last := 0
	for mm: Array in MOMENTS:
		if mm[1] is int:
			last = maxi(last, int(mm[1]))
	if film_dir != "":
		last = maxi(last, FILM_TAIL)               # (a film runs on to the Breath's cone, its strike comes late)
	while k <= last:
		await _f(1)
		k = st.frame - f1
		if strip and (st.frame - f0) % STRIP_EVERY == 0 and frames_in.size() < STRIP_N:
			frames_in.append(_grab())
		for mm: Array in MOMENTS:
			if mm[1] is int and int(mm[1]) == k:
				got[String(mm[0])] = _grab()
		if how == "guard" and k == 30:
			_ctl.set_held(InputSetup.GUARD_ACTION, false)
	for mm: Array in MOMENTS:
		var key := "%s_%s_%s" % [take, view, mm[0]]
		var img: Image = got.get(String(mm[0]))
		if img != null:
			img.save_png(out.path_join("%s_%s.png" % [key, tag]))
			_shots[key] = img
	if strip:
		_strip[take] = frames_in
	_rec = false
	_ctl.release_all()
	sc.held_override = null
	print("FIRE REVIEW take %s (%s): %d moments%s" % [take, view, got.size(), ", strip %d" % frames_in.size() if strip else ""])
	await st.frames(30)


## The move readied through its key (its key's other move or mode by a second press), as the move reel does.
func _ready_move(sc: SwayCaster, id: String, md: String) -> void:
	var el := "fire"
	var k := Bending.key_of(el, id)
	if k < 0 and not id in Bending.key3(el):
		await _key(&"weapon_1")
	if id in Bending.key3(el):
		await _key(&"weapon_3")
	elif k >= 0:
		var a := StringName("weapon_%d" % (k + 1))
		await _key(a)
		var first := Bending.first_of(Bending.keys(el)[k])
		if String(first.get("id", "")) != id or (md != "" and String(first.get("mode", "")) != md):
			await _key(a)
	if sc.readied_spell != id:
		sc.ready_spell(id)
	if md != "" and sc.mode_of(id) != md:
		sc.set_mode(id, md)
	await st.frames(6)


func _key(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)
		await st.frames(1)


## `n` frames waited (the kept camera and aim as st.frames does), each saved as a film frame while recording.
func _f(n: int) -> void:
	for i in n:
		await st.frames(1)
		if _rec and film_dir != "":
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_jpg(film_dir.path_join("f%05d.jpg" % _n_film), 0.92)
			_n_film += 1


func _grab() -> Image:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img
