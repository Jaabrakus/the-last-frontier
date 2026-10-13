extends SceneTree
## The element round the body while a move charges (BendCharge; the owner, 2026-10-12: "instead of the spell circle we need to
## animate like in avatar the element charging and bending around their body"), filmed for review: a Practice stage of `el`,
## the player's real locks as the game plays them (the key pressed, the aim held on the dummy, let go a while after full), key
## 2's move then key 1's, from a camera before the player, three quarters on, close. Every frame saved (a clip), and stills at
## the lock's start, half, full and the cast with a sheet. Windowed (a normal window, never on top):
##   zsh tools/loop/godot_run.sh --path . --resolution 1280x720 --fixed-fps 60 -s tools/fx/charge_shots.gd -- el=water out=<dir>
## Writes <dir>/frames/f00000.jpg ..., <dir>/<el>_<key>_<moment>.png, <dir>/<el>_sheet.png; prints CHARGE SHOTS DONE.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
## The keys cast in turn (their actions), how long the aim is held on past full, and the frames after the let-go.
const KEYS := [&"weapon_2", &"weapon_1"]
const HOLD_FULL_S := 1.1
const AFTER_S := 0.9
const CELL := Vector2i(480, 270)

var out := "user://charge_shots"
var el := "water"
var st: FxStage
var cam: Camera3D
var frame_n := 0
var recording := false
## "<key action>/<moment>" -> Image
var shots := {}


func _initialize() -> void:
	var a := CaptureKit.args({"out": out, "el": el})
	out = String(a["out"])
	el = String(a["el"])
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	st = FxStage.new(self)
	st.start(el)
	_run.call_deferred()


func _run() -> void:
	if not await st.wait_fight():
		print("CHARGE SHOTS FAILED (no fight)")
		quit(1)
		return
	await st.calibrate_pitch()
	await st.reset()
	st.hide_ui()
	st.aiming = true
	st.keeper = _keep
	cam = Camera3D.new()
	cam.fov = 30.0
	cam.far = 1500.0
	current_scene.add_child(cam)
	st.cam = cam
	_place_cam()
	await st.frames(20)
	recording = true
	for k: StringName in KEYS:
		if el == "earth":
			_scatter(5)                            # (broken pieces lying round him, as burst stones leave them: pulled in)
			await st.frames(20)
		await _cast(k)
		await st.frames(30)
	recording = false
	var rows: Array = []
	for k: StringName in KEYS:
		var row: Array = []
		for moment: String in ["start", "half", "full", "cast"]:
			var img: Image = shots.get("%s/%s" % [k, moment], null)
			if img == null:
				img = Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGB8)
			else:
				img = img.duplicate() as Image
				img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
			row.append(img)
		rows.append(row)
	await st.sheet(rows, [String(KEYS[0]).replace("weapon_", "key "), String(KEYS[1]).replace("weapon_", "key ")],
			["start", "half", "full", "cast"], CELL, out.path_join(el + "_sheet.png"))
	print("CHARGE SHOTS DONE frames=%d" % frame_n)
	quit(0)


## The camera before the player, three quarters on to its right, about 5.5 m off (past the effects' near fade, as a foe sees
## it), looking at the chest.
func _place_cam() -> void:
	var p := st.p
	var f := -p.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var side := f.cross(Vector3.UP).normalized()
	var eye := p.global_position + f * 4.6 + side * 2.9 + Vector3.UP * 1.7
	cam.global_transform = Transform3D(Basis.looking_at(p.global_position + Vector3.UP * 1.0 - eye, Vector3.UP), eye)


func _keep() -> void:
	if cam != null:
		_place_cam()
	if recording:
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(out.path_join("frames/f%05d.jpg" % frame_n), 0.9)
		frame_n += 1


## Key `k` pressed (its move readied), the aim held till full and HOLD_FULL_S past it, then let go: stills on the way.
func _cast(k: StringName) -> void:
	await _press(k)
	await st.frames(12)
	var sway := st.sway
	var move := ""
	sway.held_override = true
	var shot := {"start": false, "half": false, "full": false}
	var full_t := -1.0
	for i in 600:
		await st.frames(1)
		if move == "" and sway.state != SwayCaster.State.IDLE:
			move = sway.move
		if sway.state == SwayCaster.State.IDLE and move != "":
			break                                  # (it went off by itself)
		var f := sway.fill
		if not shot.start and f > 0.12:
			shot.start = true
			_still(k, "start")
		if not shot.half and f >= 0.5:
			shot.half = true
			_still(k, "half")
		if sway.state == SwayCaster.State.FULL:
			if full_t < 0.0:
				full_t = 0.0
			full_t += 1.0 / 60.0
			if not shot.full and full_t > 0.35:
				shot.full = true
				_still(k, "full")
			if full_t >= HOLD_FULL_S:
				break
	sway.held_override = false
	await st.frames(6)
	_still(k, "cast")
	await st.frames(int(AFTER_S * 60.0))
	sway.held_override = null
	print("CHARGE SHOTS %s %s move=%s" % [el, k, move])
	recording = false                              # (the reset between casts is not filmed)
	await st.reset()
	_place_cam()
	recording = true


func _still(k: StringName, moment: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out.path_join("%s_%s_%s.png" % [el, String(k).replace("weapon_", "key"), moment]))
	shots["%s/%s" % [k, moment]] = img


## `n` broken stone pieces lying on the deck 2-4.5 m round the player, as a burst stone leaves them (GustLift's chunks,
## RockDebris).
func _scatter(n: int) -> void:
	var deb := RockDebris.of(current_scene)
	var p := st.p
	for i in n:
		var m := MeshInstance3D.new()
		m.mesh = GustLift._chunk_mesh("stone", i)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		current_scene.add_child(m)
		var a := TAU * float(i) / float(n) + 0.4
		var d := 2.0 + 2.5 * float(i % 3) / 2.0
		m.global_position = p.global_position + Vector3(cos(a) * d, 0.06, sin(a) * d)
		m.rotation = Vector3(float(i) * 1.3, float(i) * 2.1, float(i) * 0.7)
		m.scale = Vector3.ONE * (1.2 + 0.3 * float(i % 3))
		deb.lay(m)


## Action `a` pressed and let go (as a key would be: the player's input hears it).
func _press(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)
		await st.frames(3)
