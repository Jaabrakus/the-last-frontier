extends SceneTree
## Stills of the four binds (2026-10-11, the owner: "each element should have binds and finishers"; the feet only, as a skill
## tree twist; fire's a lightning shock): a Practice ring, the player 8 m from a standing dummy, the crosshair on its chest.
## Each twist is worn and its move cast as the game casts it (BendEffects.apply: the wearer's spec, the hit's bind_s), and seen
## at three moments (the cast's tell, the first frame the dummy's feet are held, 0.4 s into the hold) from two places (wide
## from beside the deck, close on the dummy's legs): Stone Grip, Frost Geyser, Static Shock, Tripwind. Windowed (a normal
## window, never on top):
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --fixed-fps 60 -s tools/ring/bind_shots.gd -- out=<dir>
## Writes <dir>/<take>_<view>_<moment>.png and <dir>/binds.png (the sheet), prints BIND SHOTS DONE.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
## [take, node, element, move, mode]
const TAKES := [["grip", "earth.column.grip", "earth", "earth_shove", "column"],
		["frost", "water.geyser.frost", "water", "wave", "spout"],
		["shock", "fire.lightning.shock", "fire", "fire_arc", "lightning"],
		["trip", "air.pull.trip", "air", "air_gust", "pull"]]
const LABELS := {"grip": "Stone Grip (earth)", "frost": "Frost Geyser (water)", "shock": "Static Shock (fire)",
		"trip": "Tripwind (air)"}
const MOMENTS := ["the tell", "held", "held 0.4 s"]
const CELL := Vector2i(400, 225)

var out := "user://bind_shots"
var st: FxStage
var cam: Camera3D
var view := "wide"
## The dummy of the take (kept: the stage's foe can be between bodies while Practice resets).
var dummy: Node3D


func _initialize() -> void:
	var a := CaptureKit.args({"out": out})
	out = String(a["out"])
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("BIND SHOTS FAILED (watchdog)")
		quit(2))
	SbFx.force_on = false
	st = FxStage.new(self)
	st.keeper = _keep
	st.start("fire")
	_run.call_deferred()


## The view's camera: wide from beside the deck (both in frame), or close on the dummy's legs.
func _keep() -> void:
	var d: Node3D = dummy if dummy != null and is_instance_valid(dummy) else (st.mode.foe if st.mode != null else null)
	if st.p == null or d == null or not is_instance_valid(d):
		return
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 50.0
		cam.far = 1500.0
		current_scene.add_child(cam)
	var side := Vector3.UP.cross(st.axis).normalized()
	var eye: Vector3
	var look: Vector3
	if view == "wide":
		var mid := (st.p.global_position + d.global_position) * 0.5
		look = mid + Vector3.UP * 0.9
		eye = look + side * 9.0 + Vector3.UP * 2.6
	else:
		# (4.3 m off: as far as the game's camera keeps a foe at the least, past the effects' near fade, 2.5-4 m)
		look = d.global_position + Vector3.UP * 0.5
		eye = look + side * 4.0 - st.axis * 1.2 + Vector3.UP * 0.9
	cam.global_transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
	if root.get_camera_3d() != cam:
		cam.make_current()


func _run() -> void:
	if not await st.wait_fight():
		print("BIND SHOTS FAILED: no practice fight")
		quit(1)
		return
	await st.calibrate_pitch()
	var cells: Array = []
	var rows: Array = []
	for t: Array in TAKES:
		for v: String in ["wide", "close"]:
			cells.append(await _take(t, v))
			rows.append("%s\n%s" % [LABELS[t[0]], "wide" if v == "wide" else "close on his feet"])
	BendLoadout.clear(st.p)
	await st.sheet(cells, rows, MOMENTS, CELL, out.path_join("binds.png"), [], 190)
	print("BIND SHOTS DONE -> ", out)
	quit(0)


## One cast of take `t` seen from view `v`: its moments as images.
func _take(t: Array, v: String) -> Array:
	var take := String(t[0])
	var id := String(t[1])
	var el := String(t[2])
	var m := String(t[3])
	var md := String(t[4])
	view = v
	await st.reset()
	st.hide_ui()
	st.aiming = true
	var d: NpcFighter = st.mode.foe
	dummy = d
	BendStatus.unbind(d)
	if d.has_meta(BendStatus.BIND_MEMO_META):
		d.remove_meta(BendStatus.BIND_MEMO_META)
	Bending.of(st.p).element = el
	BendLoadout.wear(st.p, [id], "", el)
	await st.frames(20)
	var imgs: Array = []
	BendEffects.apply(st.bc, m, md, SwayMoves.move(m).bend[md])
	await st.frames(6)
	imgs.append(_shot(take, v, "tell"))
	var held := false
	for i in 120:
		await st.frames(1)
		if BendStatus.bound(d):
			held = true
			break
	await st.frames(2)
	imgs.append(_shot(take, v, "held"))
	await st.frames(22)
	imgs.append(_shot(take, v, "held04"))
	print("  %s %s: held %s (%.2f s left)" % [take, v, held, BendStatus.until(d, &"bend_root")])
	await st.frames(40)
	return imgs


func _shot(take: String, v: String, moment: String) -> Image:
	var img := st.snap(out.path_join("%s_%s_%s.png" % [take, v, moment]))
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	return img
