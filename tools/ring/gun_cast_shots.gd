extends SceneTree
## Stills of the gun-style casts (2026-10-11, the owner: Embers the pistol, the Ice Spear with the water spear in the hands;
## 2026-10-12 the Ice Spear on the game's own standing pistol aim, the Lightning Pistol twist gone): a Practice ring, the
## player against a standing dummy 8 m off, the crosshair on its chest. Each cast is played as the game plays it (the lock's
## looks, SwayCaster._began; its pose, SwayPose; the effect launched on the pose's strike, BendCast.cast), from beside the
## player and through his own camera: Lightning (the original), Embers and the Ice Spear. Windowed (a normal window, never on top):
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --fixed-fps 60 -s tools/ring/gun_cast_shots.gd -- out=<dir>
## Writes <dir>/<take>_<view>_<moment>.png and <dir>/gun_casts.png (the sheet), prints GUN SHOTS DONE.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
## [take, move, mode, element, worn nodes]
const TAKES := [["lightning", "fire_arc", "lightning", "fire", []], ["embers", "fire_jab", "embers", "fire", []],
		["spear", "ice", "spear", "water", []]]
const LABELS := {"lightning": "Lightning (original)", "embers": "Embers (pistol)", "spear": "Ice Spear (pistol aim)"}
const MOMENTS := ["lock 40%", "lock full", "strike", "after"]
const CELL := Vector2i(400, 225)

var out := "user://gun_cast_shots"
var st: FxStage
var side_cam: Camera3D
var view := "side"
var _struck := -1


func _initialize() -> void:
	var a := CaptureKit.args({"out": out})
	out = String(a["out"])
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("GUN SHOTS FAILED (watchdog)")
		quit(2))
	SbFx.force_on = false
	st = FxStage.new(self)
	st.keeper = _keep
	st.start("fire")
	_run.call_deferred()


## The camera of the view in force: beside the player (close, at his chest's height, a little ahead), or his own.
func _keep() -> void:
	var p := st.p
	if p == null:
		return
	if view == "side":
		if side_cam == null:
			side_cam = Camera3D.new()
			side_cam.fov = 50.0
			side_cam.far = 1500.0
			current_scene.add_child(side_cam)
		var side := Vector3.UP.cross(st.axis).normalized()
		var chest := p.global_position + Vector3.UP * 1.15
		var eye := chest + side * 3.3 + st.axis * 1.1 + Vector3.UP * 0.25
		side_cam.global_transform = Transform3D(Basis.looking_at(chest + st.axis * 0.7 - eye, Vector3.UP), eye)
		if root.get_camera_3d() != side_cam:
			side_cam.make_current()
	elif p.camera != null and root.get_camera_3d() != p.camera:
		p.camera.make_current()


func _run() -> void:
	if not await st.wait_fight():
		print("GUN SHOTS FAILED: no practice fight")
		quit(1)
		return
	await st.calibrate_pitch()
	var cells: Array = []
	var rows: Array = []
	for t: Array in TAKES:
		for v: String in ["side", "game"]:
			cells.append(await _take(t, v))
			rows.append("%s\n%s" % [LABELS[t[0]], "beside" if v == "side" else "your camera"])
	BendLoadout.clear(st.p)
	await st.sheet(cells, rows, MOMENTS, CELL, out.path_join("gun_casts.png"), [], 190)
	print("GUN SHOTS DONE -> ", out)
	quit(0)


func _on_struck(_m: String) -> void:
	if _struck < 0:
		_struck = st.frame


## One cast of take `t` seen from view `v`: its four moments as images.
func _take(t: Array, v: String) -> Array:
	var take := String(t[0])
	var m := String(t[1])
	var md := String(t[2])
	var el := String(t[3])
	var picks: Array = t[4]
	await st.reset()
	st.hide_ui()
	view = v
	st.aiming = true
	Bending.of(st.p).element = el
	if picks.is_empty():
		BendLoadout.clear(st.p)
	else:
		BendLoadout.wear(st.p, picks, "", el)
	await st.frames(30)                              # (the element's stance settles)
	var sway := st.sway
	var pose := sway.pose
	pose._clock += 10.0
	pose._last_key = ""
	sway.move = m
	sway._pin_id = m
	sway._pin_mode = md
	sway._pin_on = true
	sway._began()                                    # (the lock's looks: Lightning's charge, the Ice Spear's water spear)
	pose._on_started(m, null)
	var lock := sway._lock_time(m, null, 8.0, sway.range_of(m, null))
	var n := maxi(int(round(lock * 60.0)), 4)
	var imgs: Array = []
	for i in n:
		if sway.charge != null and is_instance_valid(sway.charge):
			sway.charge.set(&"level", clampf(float(i + 1) / float(n), 0.0, 1.0))
		await st.frames(1)
		if i == int(n * 0.4):
			imgs.append(_shot(take, v, "lock40"))
	imgs.append(_shot(take, v, "full"))
	sway._end_charge()                               # (the lock over, as at the cast: before the cast signal)
	sway.move = ""
	sway._pin_on = false
	_struck = -1
	pose.struck.connect(_on_struck, CONNECT_ONE_SHOT)
	pose._on_cast(m, null)
	var launched := false
	for i in 90:
		await st.frames(1)
		if _struck >= 0 and not launched:
			launched = true
			BendCast.cast(st.bc, m, md)              # (the move leaves on the pose's strike, as the game lands it)
			await st.frames(2)
			imgs.append(_shot(take, v, "strike"))
			await st.frames(int(0.4 * 60.0) if m == "fire_arc" else 9)
			imgs.append(_shot(take, v, "after"))
			if m == "fire_arc":
				await st.frames(12)
				var rec := BendEffects.last_of(st.bc)
				print("  %s %s: hit %s, sent back %s, flash %s s" % [take, v, rec.get("hit"), rec.get("redirected"),
						rec.get("flash_s")])
			break
	if pose.struck.is_connected(_on_struck):
		pose.struck.disconnect(_on_struck)
	while imgs.size() < MOMENTS.size():
		imgs.append(_shot(take, v, "missing"))
	for i in 90:
		if pose.phase == "":
			break
		await st.frames(1)
	print("  %s %s: lock %.2f s, struck %s" % [take, v, lock, launched])
	return imgs


func _shot(take: String, v: String, moment: String) -> Image:
	var img := st.snap(out.path_join("%s_%s_%s.png" % [take, v, moment]))
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	return img
