extends SceneTree
## Every guard's answers filmed for review (the owner, 2026-10-12: the parries loop "like a moon", the body turning with them;
## where two elements meet the return is made of both: earth and fire magma, earth and water mud, wind caught by earth pebbles and
## turned by water to ice spears, the wind sending anything back; the Air Beam, "instant cant be sent back only block"): a
## Practice stage of `el`, the player's own guard (BendZone, as E makes it) met on the beat by the dummy's shots, the real move
## specs (moves.json): a bolt launched from the dummy at the player's chest, a Boulder thrown at him (FormEffects.Throw), the Air
## Beam cast at him (BendEffects); earth's caught stone thrown back with E (BendZone.return_stone). A side camera holds both;
## then the guard's moons again from close by (the spin, the hand). Each shot's first frame and label in <dir>/shots.json.
## Windowed (a normal window, never on top):
##   zsh tools/loop/godot_run.sh --path . --resolution 1280x720 --fixed-fps 60 -s tools/fx/guard_shots.gd -- el=fire out=<dir>
## Writes <dir>/frames/f00000.jpg ... and prints GUARD SHOTS DONE.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const GUARD := {"earth": ["catch", "stone_catch", "catch"], "water": ["redirect", "water_redirect", "redirect"],
		"fire": ["parry", "fire_parry", "parry"], "air": ["air_shield", "air_shield", "shield"]}
## Each guard's shots: [label, shot] (shot: _shot's keys), then the close-ups' shots.
const SHOTS := {
	"fire": [["FIRE PARRY  ·  a Fireball: loops round, sent back", "fireball"],
			["FIRE PARRY  ·  an air Slice: sent back as fire", "slice"],
			["FIRE PARRY  ·  a stone: melted, sent back as a magma ball", "pebble"],
			["FIRE PARRY  ·  a Boulder: sent back as magma", "boulder"],
			["FIRE PARRY  ·  water: boiled to steam", "water"]],
	"air": [["WIND GUARD  ·  a Fireball: loops round, sent back", "fireball"],
			["WIND GUARD  ·  a stone: sent back", "pebble"],
			["WIND GUARD  ·  a Boulder: sent back", "boulder"],
			["WIND GUARD  ·  water: sent back", "water"],
			["AIR BEAM  ·  instant, straight from two fingers", "beam_hit"],
			["AIR BEAM  ·  a guard on the beat blocks it, nothing sent back", "beam"]],
	"water": [["WATER TURN  ·  water: swung round, sent back", "water"],
			["WATER TURN  ·  wind: sent back as mini ice spears", "ball"],
			["WATER TURN  ·  a stone: sent back as a mud spear (it slows)", "pebble"],
			["WATER TURN  ·  a Boulder: sent back as mud", "boulder"],
			["WATER TURN  ·  fire: doused", "fireball"]],
	"earth": [["EARTH CATCH  ·  a stone: caught and held, E throws it back", "pebble"],
			["EARTH CATCH  ·  wind: loops round sweeping up rocks, back as pebbles", "ball"],
			["EARTH CATCH  ·  fire: loops round, the rocks melted in, back as a magma ball", "fireball"],
			["EARTH CATCH  ·  water: swirls along the deck taking up rocks, out as a mud fissure (it slows)", "water"]],
}
## (small shots for the close-ups: a Fireball's flames hid the body turning in them)
const CLOSE := {"fire": [["FIRE PARRY  ·  close: the spin and the guiding hand (a Slice turned to fire)", "slice"],
			["FIRE PARRY  ·  close: a stone melted to magma as he turns", "pebble"]],
		"air": [["WIND GUARD  ·  close: the spin, both hands (a stone)", "pebble"]],
		"water": [["WATER TURN  ·  close: the spin, both hands (a water bolt)", "water"],
			["WATER TURN  ·  close: a stone swung round in muddy water", "pebble"]],
		"earth": [["EARTH CATCH  ·  close: a stone caught and held, no spin; E throws it", "pebble"],
			["EARTH CATCH  ·  close: water swirled along the deck, rocks swept in, out as a mud fissure", "water"]]}

var out := "user://guard_shots"
var el := "fire"
var st: FxStage
var side_cam: Camera3D
var close_cam: Camera3D
var frame_n := 0
var recording := false
var marks: Array = []


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
		print("GUARD SHOTS FAILED (no fight)")
		quit(1)
		return
	await st.calibrate_pitch()
	await st.reset()
	st.hide_ui()
	st.aiming = true                                 # (his crosshair on the dummy's chest, as a player aims: the return goes there)
	side_cam = st.side_camera(46.0, 9.5, 2.6, 1.1)
	st.cam = side_cam
	st.keeper = _keep
	(st.mode.foe as NpcFighter).held = true
	var fbc := BendCaster.of(st.mode.foe)
	if fbc != null:
		fbc.set(&"target", st.p)
	await st.frames(20)
	for s: Array in SHOTS[el]:
		await _take(String(s[0]), String(s[1]), side_cam)
	for s: Array in CLOSE[el]:
		if close_cam == null:
			close_cam = _close_camera()
		await _take(String(s[0]), String(s[1]), close_cam)
	recording = false
	var f := FileAccess.open(out.path_join("shots.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"el": el, "frames": frame_n, "shots": marks}))
	f.close()
	print("GUARD SHOTS DONE frames=%d shots=%d" % [frame_n, marks.size()])
	quit(0)


## One shot: the stage reset, the camera `cam`, its label marked at this frame, the shot met, the aftermath held.
func _take(label: String, shot: String, cam: Camera3D) -> void:
	await st.reset()
	st.cam = cam
	await st.frames(4)
	marks.append({"frame": frame_n, "label": label})
	recording = true
	await st.frames(14)
	await _shot(shot, shot != "beam_hit")
	await st.frames(100 if el != "earth" else 40)
	recording = false


## A camera near the guard, three quarters before him, on his chest: the spin and the hands.
func _close_camera() -> Camera3D:
	var c := Camera3D.new()
	c.fov = 44.0
	c.far = 1500.0
	current_scene.add_child(c)
	var at := st.p.global_position
	var fwd := st.axis
	var side := Vector3.UP.cross(fwd).normalized()
	# (far enough that the whole lap round him, MOON_R out, stays in the picture)
	var eye := at + fwd * 3.3 + side * 3.6 + Vector3.UP * 2.0
	c.global_transform = Transform3D(Basis.looking_at(at + Vector3.UP * 1.0 + fwd * 0.4 - eye, Vector3.UP), eye)
	return c


## Shot `what` from the dummy at the player, met by his guard on the beat when `guard` (see SHOTS).
func _shot(what: String, guard: bool) -> void:
	var p := st.p
	var foe := st.mode.foe as Node3D
	var g: Array = GUARD[el]
	var gspec: Dictionary = (SwayMoves.move(String(g[1])).bend as Dictionary)[String(g[2])]
	var chest := p.global_position + Vector3.UP * 1.2
	var from := NpcSenses.chest_of(foe)
	var dir := (chest - from).normalized()
	match what:
		"boulder":
			var fbc := BendCaster.of(foe)
			var s := FormStone.ball(current_scene, from + dir * 1.2 - Vector3.UP * 0.4, {"radius_m": 0.32, "mass_kg": 30.0, "rise_s": 0.01,
					"life_s": 30.0}, 7, "stone")
			s.state = FormStone.State.RESTING
			var td: Dictionary = (SwayMoves.move("stone_form").get("throw", {}) as Dictionary).duplicate(true)
			td["rise_s"] = 0.05
			var th := FormEffects.Throw.start(fbc, s, td, chest)
			var reach := float(gspec.get("radius_m", 2.2)) + 2.5
			for i in 120:
				await st.frames(1)
				if th == null or not is_instance_valid(th.lift) or th.lift.stone.global_position.distance_to(chest) < reach:
					break
			_guard(gspec)
		"beam", "beam_hit":
			var gust: Dictionary = ((SwayMoves.move("air_gust").bend as Dictionary).gust as Dictionary).duplicate(true)
			var grow: Dictionary = gust.get("grow", {})
			gust.erase("grow")
			gust.merge(grow, true)
			if guard:
				_guard(gspec)
				await st.frames(2)
			BendEffects.apply(BendCaster.of(foe), "air_gust", "gust", gust)
		_:
			var spec := _spec(what)
			var mps := float(spec.get("mps", 30.0))
			var dist := from.distance_to(chest)
			# (the guard up so the shot meets it 0.12 s into its beat: perfect)
			var fly_s := maxf(dist - float(gspec.get("radius_m", 2.2)), 0.5) / mps
			BendBolt.launch(foe, from + dir * 0.6, dir, spec)
			await st.frames(maxi(int((fly_s - 0.12) * 60.0), 1))
			_guard(gspec)
	if el == "earth":
		# (E again: the caught stone thrown back along his aim)
		for i in 60:
			await st.frames(1)
			if BendZone.held_stone(p) != null:
				break
		await st.frames(36)
		var held := BendZone.held_stone(p)
		if held != null:
			BendZone.return_stone(BendCaster.of(p), held)
		await st.frames(70)


func _guard(gspec: Dictionary) -> void:
	var g: Array = GUARD[el]
	BendZone.make(st.p, String(g[0]), st.p.global_position, gspec, BendCaster.of(st.p).facing())


## The real spec of shot `what` (moves.json; a volley's one stone).
func _spec(what: String) -> Dictionary:
	match what:
		"fireball":
			var punch: Dictionary = (SwayMoves.move("fire_blast").bend as Dictionary).punch
			var fb := punch.duplicate(true)
			fb.erase("grow")
			fb.merge(punch.grow, true)
			return fb
		"slice":
			return ((SwayMoves.move("air_blast").bend as Dictionary).slice as Dictionary).duplicate(true)
		"ball":
			return ((SwayMoves.move("air_blast").bend as Dictionary).ball as Dictionary).duplicate(true)
		"pebble":
			var pb: Dictionary = ((SwayMoves.move("rock_jab").bend as Dictionary).pebbles as Dictionary).duplicate(true)
			pb["count"] = 1
			pb["radius_m"] = 0.16
			return pb
		"water":
			return ((SwayMoves.move("water_jet").bend as Dictionary).splash as Dictionary).duplicate(true)
	return {}


func _keep() -> void:
	if recording:
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(out.path_join("frames/f%05d.jpg" % frame_n), 0.9)
		frame_n += 1
