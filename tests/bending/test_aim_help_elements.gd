extends SceneTree
## The aim's help for water and air (the owner, 2026-10-16: "i notice the aim assist isnt good with water? maybe and air right?"),
## in a real ring with a foe standing in the crosshair's circle:
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_aim_help_elements.gd -- mode=ring practice=stand element=water foe=earth aim=strong
##   water   Flowing's steer bends a helped bolt toward the fighter the help took (steer_target), not toward the raw crosshair: with
##           the crosshair swung far off after the cast the bolt stays on him (turned < 3 deg, Classic's steer turned it 5 to 15);
##           a cast with no fighter in the circle keeps steering to the crosshair (tests/bending/test_r2_guards.gd's _steer)
##   air     the Gust (wind_wave) takes the aim's help as the Slice and the Ball do: its velocity points at the fighter the help
##           took within 2 deg; with the help off (aim=off) it flies the crosshair's own line
## Ends with "AIM HELP ELEMENTS PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "AIM HELP ELEMENTS TEST"
const LIMIT_S := 240.0

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var mode: RingMode
var foe: Node3D


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	if fails.is_empty() and checks > 0:
		print("AIM HELP ELEMENTS PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("AIM HELP ELEMENTS FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	for i in 12:
		await process_frame
	var lvl := current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	foe = mode.foe if mode != null else null
	_expect(player != null and mode != null and foe != null, "a practice ring with a standing foe")
	if player == null or foe == null:
		return _end()
	await _ticks(240)
	await _water()
	await _air()
	_end()


func _my_bolt() -> BendBolt:
	var b: BendBolt = null
	for n in get_nodes_in_group(BendBolt.GROUP):
		if (n as BendBolt).caster == player:
			b = n
	return b


## The crosshair put `off_deg` degrees to the side of the foe's chest (yaw and pitch searched by trying both signs of each step: the
## test needs no knowledge of the camera's conventions), the help's circle then holding him.
func _face_foe(off_deg := 0.0) -> void:
	var pbc := BendCaster.of(player)
	for it in 8:
		await _ticks(2)
		var cam := player.camera.global_position
		var want := NpcSenses.chest_of(foe) - cam
		var got := pbc.flight_point() - cam
		var err_yaw := Vector3(got.x, 0.0, got.z).signed_angle_to(Vector3(want.x, 0.0, want.z), Vector3.UP)
		var err_pit := asin(clampf(want.normalized().y, -1.0, 1.0)) - asin(clampf(got.normalized().y, -1.0, 1.0))
		player.yaw += err_yaw
		player.pitch += err_pit
		await _ticks(2)
		var got2 := pbc.flight_point() - cam
		var e2 := Vector3(got2.x, 0.0, got2.z).signed_angle_to(Vector3(want.x, 0.0, want.z), Vector3.UP)
		if absf(e2) > absf(err_yaw) * 0.5 and absf(err_yaw) > 1e-3:
			player.yaw -= 2.0 * err_yaw              # (the other way)
		var p2 := asin(clampf(want.normalized().y, -1.0, 1.0)) - asin(clampf((pbc.flight_point() - cam).normalized().y, -1.0, 1.0))
		if absf(p2) > absf(err_pit) * 0.5 and absf(err_pit) > 1e-3:
			player.pitch -= 2.0 * err_pit
	player.yaw += deg_to_rad(off_deg)
	await _ticks(3)


func _clear_bolts() -> void:
	for n in get_nodes_in_group(BendBolt.GROUP):
		if (n as BendBolt).caster == player:
			(n as BendBolt).queue_free()


func _water() -> void:
	Bending.of(player).element = "water"
	var pbc := BendCaster.of(player)
	var spec := {"kind": "water", "mps": 28.0, "gravity": 0.0, "damage": 1.0, "knock_mps": 0.0, "radius_m": 0.15, "range_m": 40.0}
	await _face_foe(2.0)
	var a := BendEffects.aim(pbc, spec)
	_expect(a.target == foe, "the aim's help takes the foe standing in the crosshair's circle (%s)" % [a.target])
	_clear_bolts()
	BendEffects.bolts(pbc, a, spec)
	var b := _my_bolt()
	_expect(b != null and b.steer_target == foe and b.steer_dps > 0.0, "a water bolt of a helped cast carries the fighter the help took and Flowing's steer")
	if b == null:
		return
	# (measured 0.1 s after the cast, the bolt still in flight: Flowing turns up to 45 deg/s, 4.5 deg in 0.1 s)
	var v0 := b.velocity
	player.yaw += deg_to_rad(25.0)               # (the crosshair swung far off the foe after the cast)
	await _ticks(6)
	var turned := rad_to_deg(v0.angle_to(b.velocity)) if is_instance_valid(b) else -1.0
	_expect(turned >= 0.0 and turned < 0.5, "the helped bolt stays on him when the crosshair swings away: turned %.2f deg" % turned)
	player.yaw -= deg_to_rad(25.0)
	_clear_bolts()
	await _ticks(20)
	# the control: the same cast with the help's target taken off the bolt turns toward the raw crosshair (Flowing before)
	var a1 := BendEffects.aim(pbc, spec)
	BendEffects.bolts(pbc, a1, spec)
	var bc := _my_bolt()
	if bc != null:
		bc.steer_target = null
		var vc := bc.velocity
		player.yaw += deg_to_rad(25.0)
		await _ticks(6)
		var tc := rad_to_deg(vc.angle_to(bc.velocity)) if is_instance_valid(bc) else -1.0
		_expect(tc > 1.5, "control: without the target the same bolt turns toward the crosshair (%.2f deg)" % tc)
		player.yaw -= deg_to_rad(25.0)
	_clear_bolts()
	await _ticks(20)
	# a cast with no fighter in the circle: the steer is the crosshair's, as Flowing was
	player.yaw += PI
	await _ticks(6)
	var a2 := BendEffects.aim(pbc, spec)
	_clear_bolts()
	BendEffects.bolts(pbc, a2, spec)
	var b2 := _my_bolt()
	_expect(a2.target == null and b2 != null and b2.steer_target == null, "with none in the circle the bolt keeps the crosshair's steer (no target)")
	player.yaw -= PI
	_clear_bolts()
	await _ticks(10)


func _air() -> void:
	Bending.of(player).element = "air"
	var pbc := BendCaster.of(player)
	await _ticks(20)
	var spec: Dictionary = (SwayMoves.move("air_gust").bend as Dictionary)["gust"]
	await _face_foe(2.0)
	var a := BendEffects.aim(pbc, spec)
	_expect(a.target == foe, "air: the aim's help takes the foe in the circle (%s)" % [a.target])
	_clear_bolts()
	var b := BendEffects.wind_wave(pbc, a, spec)
	var to := NpcSenses.chest_of(foe) - (a.from as Vector3)
	var off := rad_to_deg(b.velocity.angle_to(to)) if b != null else 99.0
	# (the aim's own led point, not his chest exactly: a standing foe has no lead)
	_expect(b != null and off < 2.0, "the Gust flies at the fighter the help took: %.2f deg off his chest" % off)
	_clear_bolts()
	await _ticks(10)
