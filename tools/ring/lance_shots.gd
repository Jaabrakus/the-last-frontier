extends SceneTree
## Stills of the Air Lance's throw (the owner, 2026-10-10: "we can use our spear animation for the lance right"): a practice
## ring, air against a standing air dummy, a camera close beside the player; key 2 (the Gust) held through its lock and on
## until it grows into the Lance (SwayCaster.grew: SwayPose winds up into the pose's grown clip, the overhand spear throw),
## then let go. Real input (the hotbar's key and the held right button), so the lock, the grow and the release are the
## game's own. Windowed (a normal window, never on top):
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --fixed-fps 60 -s tools/ring/lance_shots.gd -- out=<dir>
## Writes <dir>/lance_<n>_<moment>.png: full (the Gust's hold), grown (the spear's wind-up), throw_0..2 (after the release)
## and lance_sheet.png. Ends with LANCE SHOTS DONE.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")

var out := "user://lance_shots"
var st: FxStage
var shots: Array = []


func _initialize() -> void:
	var a := CaptureKit.args({"out": out})
	out = String(a["out"])
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("LANCE SHOTS FAILED (watchdog)")
		quit(2))
	st = FxStage.new(self)
	st.start("air")
	_run.call_deferred()


func _run() -> void:
	if not await st.wait_fight():
		print("LANCE SHOTS FAILED: no practice fight")
		quit(1)
		return
	await st.calibrate_pitch()
	await st.reset()
	st.hide_ui()
	st.aiming = true
	# (close beside the player, at chest height, a little in front: the arm's swing across the frame)
	var side := Vector3.UP.cross(st.axis).normalized()
	var chest := st.p.global_position + Vector3.UP * 1.25
	var eye := chest + side * 3.0 + st.axis * 1.2 + Vector3.UP * 0.15
	var c := Camera3D.new()
	c.fov = 50.0
	current_scene.add_child(c)
	c.global_transform = Transform3D(Basis.looking_at(chest + st.axis * 0.6 - eye, Vector3.UP), eye)
	st.cam = c
	await st.frames(4)
	for i in 2:                                      # (twice: the right hand, then the other (the combo's alt))
		await _one(i)
		await st.frames(70)
	_sheet()
	print("LANCE SHOTS DONE")
	quit(0)


func _one(n: int) -> void:
	_key(&"weapon_2")
	await st.frames(3)
	st.p.controls.set_held(&"aim", true)
	var t := 0
	while st.sway.state not in [SwayCaster.State.FULL, SwayCaster.State.HOLDING] and t < 180:
		await st.frames(1)
		t += 1
	await st.frames(4)
	var row: Array = [_shot(n, "full")]
	t = 0
	while not st.sway.grown and t < 180:
		await st.frames(1)
		t += 1
	await st.frames(10)
	row.append(_shot(n, "grown"))
	st.p.controls.set_held(&"aim", false)
	for k in [3, 5, 6]:
		await st.frames(k)
		row.append(_shot(n, "throw_%d" % (row.size() - 2)))
	print("  lance %d: pose %s, grown %s" % [n, st.sway.get_node_or_null("SwayPose").get("anim_name") if st.sway.get_node_or_null("SwayPose") != null else "-", st.sway.grown])
	shots.append(row)


func _shot(n: int, moment: String) -> Image:
	return st.snap(out.path_join("lance_%d_%s.png" % [n, moment]))


## A number key pressed and let go (an event, as the hotbar reads them).
func _key(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)


func _sheet() -> void:
	var cells: Array = []
	for row: Array in shots:
		cells.append(row)
	st.sheet(cells, ["right hand", "left hand"], ["Gust full", "grown: Lance", "thrown", "", ""], Vector2i(480, 270),
			out.path_join("lance_sheet.png"))
