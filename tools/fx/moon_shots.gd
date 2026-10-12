extends SceneTree
## The moon counters filmed for review (the owner, 2026-10-12: "when put parry i want it to loop around like a moon before it
## fires back"; "Counter it"): a Practice stage of `el` (fire: the Parry; air: the Wind Guard), the player's own guard
## (BendZone, as E makes it) met on the beat by the dummy's shots: fire's Parry takes a grown Punch (the Fireball) and a
## Slice (air, sent back as fire); air's Wind Guard takes a Fireball (sent back as fire) and a Wind Ball. The real move specs
## (moves.json), the shots launched from the dummy at the player's chest. A side camera holds both. Every frame saved.
## Windowed (a normal window, never on top):
##   zsh tools/loop/godot_run.sh --path . --resolution 1280x720 --fixed-fps 60 -s tools/fx/moon_shots.gd -- el=fire out=<dir>
## Writes <dir>/frames/f00000.jpg ... and prints MOON SHOTS DONE.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const GUARD := {"fire": ["parry", "fire_parry", "parry"], "air": ["air_shield", "air_shield", "shield"]}

var out := "user://moon_shots"
var el := "fire"
var st: FxStage
var cam: Camera3D
var frame_n := 0
var recording := false


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
		print("MOON SHOTS FAILED (no fight)")
		quit(1)
		return
	await st.calibrate_pitch()
	await st.reset()
	st.hide_ui()
	st.aiming = true                                 # (his crosshair on the dummy's chest, as a player aims: the return goes there)
	cam = st.side_camera(46.0, 9.5, 2.6, 1.1)
	st.cam = cam
	st.keeper = _keep
	await st.frames(20)
	var punch: Dictionary = (SwayMoves.move("fire_blast").bend as Dictionary).punch
	var fireball := punch.duplicate(true)
	fireball.erase("grow")
	fireball.merge(punch.grow, true)                 # (the Fireball: the Punch grown)
	var shots: Array = []
	if el == "fire":
		shots = [fireball, (SwayMoves.move("air_blast").bend as Dictionary).slice]
	else:
		shots = [fireball, (SwayMoves.move("air_blast").bend as Dictionary).ball]
	recording = true
	for spec: Dictionary in shots:
		await _met(spec)
		await st.frames(70)
		recording = false
		await st.reset()
		recording = true
		await st.frames(10)
	recording = false
	print("MOON SHOTS DONE frames=%d" % frame_n)
	quit(0)


## The player's guard made as E makes it, then a shot of `spec` from the dummy arriving within its beat.
func _met(spec: Dictionary) -> void:
	var p := st.p
	var g: Array = GUARD[el]
	var gspec: Dictionary = (SwayMoves.move(String(g[1])).bend as Dictionary)[String(g[2])]
	var foe := st.mode.foe as Node3D
	var chest := p.global_position + Vector3.UP * 1.2
	var from := NpcSenses.chest_of(foe)
	var dir := (chest - from).normalized()
	var mps := float(spec.get("mps", 30.0))
	var dist := from.distance_to(chest)
	# (the guard up so the shot meets it 0.12 s into its beat: perfect)
	var fly_s := maxf(dist - float(gspec.get("radius_m", 2.2)), 0.5) / mps
	BendBolt.launch(foe, from + dir * 0.6, dir, spec)
	await st.frames(maxi(int((fly_s - 0.12) * 60.0), 1))
	BendZone.make(p, String(g[0]), p.global_position, gspec, BendCaster.of(p).facing())


func _keep() -> void:
	if recording:
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(out.path_join("frames/f%05d.jpg" % frame_n), 0.9)
		frame_n += 1
