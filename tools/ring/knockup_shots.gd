extends SceneTree
## Stills of the knock-ups and today's twists (2026-10-11): a Practice ring, the player 8 m from a standing dummy, the crosshair on
## its chest, each take as the game plays it (BendEffects.apply for the casts, the wearer's spec), from beside the deck:
##   column   the Column cast at the dummy: its pillar lifts him, its throw sends him up off its top, the float near the top
##   kick     the tapped Kick's floor wave: the same float
##   prison   the dummy floating after a Column hit, the Wind Prison twist's own wall (worn: 4.5 m) raised under him: caught,
##            held
##   soak     Drenching Wave worn, the Wave on the dummy: the water dripping off him
##   blast    the High Kick, now a straight blast
##   fireball the Flare Kick: the player held in the air, the left button (the game's own press): the drop kick throws a
##            fireball from its foot (its moments from the button's let-go)
## Windowed (a normal window, never on top):
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --fixed-fps 60 -s tools/ring/knockup_shots.gd -- out=<dir>
## Writes <dir>/<take>_<moment>.png and <dir>/knockups.png (the sheet), prints KNOCKUP SHOTS DONE.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const TAKES := ["column", "kick", "prison", "soak", "blast", "fireball"]
const LABELS := {"column": "Column: knock-up + float", "kick": "Kick (tapped): knock-up + float",
		"prison": "Wind Prison (twist)", "soak": "Drenching Wave (twist)", "blast": "High Kick: speedy blast",
		"fireball": "Flare Kick: fireball from the kick"}
## Seconds after the cast for each take's three moments.
const AT := {"column": [0.3, 0.75, 1.3], "kick": [0.6, 1.0, 1.5], "prison": [0.3, 0.6, 1.0], "soak": [0.3, 0.7, 1.2],
		"blast": [0.08, 0.16, 0.24], "fireball": [0.06, 0.14, 0.24]}
const CELL := Vector2i(400, 225)

var out := "user://knockup_shots"
var st: FxStage
var cam: Camera3D
## The player's height held while finite (the fireball take: in the air).
var hover_y := INF
## The camera's look height over the deck and its distance (the Column's take higher and wider: its man goes 5.5 m up).
var look_up := 1.6
var cam_m := 9.0


func _initialize() -> void:
	var a := CaptureKit.args({"out": out})
	out = String(a["out"])
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("KNOCKUP SHOTS FAILED (watchdog)")
		quit(2))
	SbFx.force_on = false
	st = FxStage.new(self)
	st.keeper = _keep
	st.start("fire")
	_run.call_deferred()


## Beside the deck, both in frame, high enough to see a knock-up's top.
func _keep() -> void:
	if st.p == null:
		return
	if hover_y < INF:
		st.p.global_position.y = hover_y
		st.p.velocity.y = 0.0
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 50.0
		cam.far = 1500.0
		current_scene.add_child(cam)
	var side := Vector3.UP.cross(st.axis).normalized()
	var look := st.mid + Vector3.UP * look_up + st.axis * 1.5
	var eye := look + side * cam_m + Vector3.UP * 1.2
	cam.global_transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
	if root.get_camera_3d() != cam:
		cam.make_current()


func _run() -> void:
	if not await st.wait_fight():
		print("KNOCKUP SHOTS FAILED: no practice fight")
		quit(1)
		return
	await st.calibrate_pitch()
	var cells: Array = []
	var rows: Array = []
	for t: String in TAKES:
		cells.append(await _take(t))
		rows.append(LABELS[t])
	BendLoadout.clear(st.p)
	await st.sheet(cells, rows, ["", "", ""], CELL, out.path_join("knockups.png"), [], 220)
	print("KNOCKUP SHOTS DONE -> ", out)
	quit(0)


func _take(t: String) -> Array:
	await st.reset()
	st.hide_ui()
	st.aiming = true
	var d: NpcFighter = st.mode.foe
	for k: StringName in [BendStatus.FLOAT_META, BendStatus.FLOAT_MEMO_META, &"bend_drench", &"bend_drench_memo"]:
		if d.has_meta(k):
			d.remove_meta(k)
	BendLoadout.clear(st.p)
	look_up = 3.4 if t == "column" else 1.6
	cam_m = 12.0 if t == "column" else 9.0
	await st.frames(15)
	match t:
		"column":
			Bending.of(st.p).element = "earth"
			BendEffects.apply(st.bc, "earth_shove", "column", SwayMoves.move("earth_shove").bend.column)
		"kick":
			Bending.of(st.p).element = "fire"
			BendEffects.apply(st.bc, "fire_kick", "kick", SwayMoves.move("fire_kick").bend.kick)
		"prison":
			Bending.of(st.p).element = "air"
			BendLoadout.wear(st.p, ["air.wall.prison"], "", "air")
			var ws := BendLoadout.spec(st.p, "air_wall", "wall", SwayMoves.move("air_wall").bend.wall)
			BendR3.deliver(d, 10.0, d.global_position + Vector3.UP, Vector3.UP, st.p, 0.5, Vector3.UP * 11.0,
					{"tag": "earth_shove/column", "move": "earth_shove", "mode": "column", "from": d.global_position})
			await st.frames(30)                                    # (near the top of the launch: floating)
			var way := d.global_position - st.p.global_position
			way.y = 0.0
			BendZone.make(st.p, "wind_wall", FormEffects.ground_at(d, d.global_position), ws, way.normalized())
		"soak":
			Bending.of(st.p).element = "water"
			BendLoadout.wear(st.p, ["water.wave.drench"], "", "water")
			BendEffects.apply(st.bc, "wave", "push", SwayMoves.move("wave").bend.push)
		"blast":
			Bending.of(st.p).element = "fire"
			BendEffects.apply(st.bc, "fire_kick", "high_kick", SwayMoves.move("fire_kick").bend.high_kick)
		"fireball":
			Bending.of(st.p).element = "fire"
			st.sway._quick["fire"] = MatchSetup.jab_of("fire")     # (the left button the jab)
			hover_y = st.p.global_position.y + 2.0
			await st.frames(8)
			st.sway.quick_override = true                         # (pressed, held till full, let go: the cast)
			for i in 90:
				await st.frames(1)
				if st.sway.state == SwayCaster.State.FULL:
					break
			st.sway.quick_override = false
	var imgs: Array = []
	var t0 := st.frame
	for i in 3:
		var s: float = (AT[t] as Array)[i]
		while float(st.frame - t0) / 60.0 < s:
			await st.frames(1)
		imgs.append(_shot(t, i))
	print("  %s: floating %s, drenched %.2f s" % [t, BendStatus.floating(d), BendStatus.drench_left(d)])
	await st.frames(60)
	hover_y = INF
	st.sway.quick_override = null
	return imgs


func _shot(t: String, i: int) -> Image:
	var img := st.snap(out.path_join("%s_%d.png" % [t, i]))
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	return img
