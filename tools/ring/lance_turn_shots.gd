extends SceneTree
## Stills of water's Turn taking the Air Lance (the owner, 2026-10-11: "lets have water be able to turn it or catch the lance
## and then turn it back as it wraps around the body for a ice lance"; "we can aim it anywhere not just return to sender"): a
## practice ring, the player water, the dummy across the deck throwing the Air Lance (the Gust's grown spec, BendBolt.launch);
## the player's Turn raised by the game's own guard input (SwayCaster.guard_override: its pose and its zone), the Lance let go
## so it arrives on the beat. Two takes: the crosshair on the thrower, then turned 40 deg aside (the ice lance leaves along the
## aim). A camera close beside the player. Windowed (a normal window, never on top):
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --fixed-fps 60 -s tools/ring/lance_turn_shots.gd -- out=<dir>
## Writes <dir>/turn_<take>_<moment>.png (catch, wrap, wrap2, leaves, flies) and prints LANCE TURN DONE.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")

var out := "user://lance_turn_shots"
var st: FxStage


func _initialize() -> void:
	var a := CaptureKit.args({"out": out})
	out = String(a["out"])
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("LANCE TURN FAILED (watchdog)")
		quit(2))
	st = FxStage.new(self)
	st.start("water")
	_run.call_deferred()


func _run() -> void:
	if not await st.wait_fight():
		print("LANCE TURN FAILED: no practice fight")
		quit(1)
		return
	await st.calibrate_pitch()
	for take: String in ["back", "aside"]:
		await st.reset()
		st.hide_ui()
		st.aiming = true
		await st.frames(4)
		if take == "aside":
			st.aiming = false
			st.p.yaw += deg_to_rad(40.0)                # (the crosshair turned 40 deg off the thrower)
			await st.frames(3)
		_camera()
		await st.frames(3)
		if not await _one(take):
			print("LANCE TURN FAILED: %s: the Lance was not turned" % take)
		st.sway.guard_override = false
		await st.frames(60)
	print("LANCE TURN DONE")
	quit(0)


## A camera beside the player at waist height, a little in front: the circle round his waist and the way the lance leaves.
func _camera() -> void:
	var p := st.p
	var side := Vector3.UP.cross(st.axis).normalized()
	var waist := p.global_position + Vector3.UP * 1.0
	var eye := waist + side * 4.2 + st.axis * 1.4 + Vector3.UP * 0.6
	var c := Camera3D.new()
	c.fov = 55.0
	current_scene.add_child(c)
	c.global_transform = Transform3D(Basis.looking_at(waist + st.axis * 0.8 - eye, Vector3.UP), eye)
	if st.cam != null and is_instance_valid(st.cam):
		st.cam.queue_free()
	st.cam = c


func _one(take: String) -> bool:
	var p := st.p
	var foe := st.mode.foe
	st.sway.guard_override = true                      # (E: the Turn, its pose and its zone, the game's own)
	var z: BendZone = null
	for i in 90:
		await st.frames(1)
		for n in get_nodes_in_group(BendZone.GROUP):
			var bz := n as BendZone
			if bz != null and bz.kind == "redirect" and bz.owner_node == p:
				z = bz
		if z != null:
			break
	if z == null:
		return false
	var chest := p.global_position + Vector3.UP * 1.2
	var from := NpcSenses.chest_of(foe)
	var dir := (chest - from).normalized()
	var g: Dictionary = ((SwayMoves.move("air_gust").bend as Dictionary).gust as Dictionary).duplicate(true)
	var grow: Dictionary = g.get("grow", {})
	g.erase("grow")
	g.merge(grow, true)
	g["_info"] = {"tag": "air_gust/gust.grown", "from": from}
	var b := BendBolt.launch(foe, from + dir * 0.8, dir, g)
	for i in 60:
		await st.frames(1)
		if not is_instance_valid(b) or b.swinging():
			break
	if not is_instance_valid(b) or not b.swinging():
		return false
	st.snap(out.path_join("turn_%s_catch.png" % take))
	await _secs(0.09)
	st.snap(out.path_join("turn_%s_wrap.png" % take))
	await _secs(0.09)
	st.snap(out.path_join("turn_%s_wrap2.png" % take))
	for i in 60:
		await st.frames(1)
		if not is_instance_valid(b) or not b.swinging():
			break
	await st.frames(2)
	st.snap(out.path_join("turn_%s_leaves.png" % take))
	await _secs(0.12)
	st.snap(out.path_join("turn_%s_flies.png" % take))
	print("  %s: %s, %s" % [take, b.kind if is_instance_valid(b) else "-", z.results])
	return true


func _secs(s: float) -> void:
	await st.frames(maxi(1, int(round(s * 60.0))))
