extends SceneTree
## Headless tests for the sky tear (SkyTear, scripts/world/env/sky_tear.gd; the look: shaders/sky/wonder_sky.gdshaderinc
## sky_tear): the tear's clock drives the sky's uniforms over its time, the wonder starts at REVEAL_AT and is full as the
## tear ends, then the tear is put away; held, it only creeps (small and local, no wonder) until let go, then runs on;
## a hit's flash decays; a sky already open is left alone; pose holds a tear and puts the wonder where the clock would;
## the shader's tear is off by default and declared where the rig's sky uses it, drawn as a break (lips lit from behind,
## a dark rim, no hairline net, no flicker), not as lightning.
##
##   Godot --headless --path . -s tests/env/test_sky_tear.gd [-- --only <name>]
##
## The look itself needs a window: tools/environment/tear_shots.gd. Failures are listed and the exit code is 1.

const SKY_SHADER := "res://shaders/sky/frontier_sky_dynamic.gdshader"
const WONDER_INC := "res://shaders/sky/wonder_sky.gdshaderinc"
const DIR := Vector3(0.75, 0.56, -0.40)
const DT := 1.0 / 60.0

var failures := PackedStringArray()
var passes := 0
var current := ""


func _initialize() -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and str(args[0]) == "--only":
		only = str(args[1])
	for name in ["test_tear_over_time", "test_hold", "test_flash", "test_already_open", "test_pose", "test_shader"]:
		if only != "" and not name.contains(only):
			continue
		current = name
		var n0 := failures.size()
		await call(name)
		print("  %s %s" % ["ok  " if failures.size() == n0 else "FAIL", name])
	print("")
	print("sky tear: %d checks passed, %d failed (%d ms)" % [passes, failures.size(), Time.get_ticks_msec() - t0])
	for f in failures:
		printerr("  FAIL " + f)
	quit(1 if failures.size() > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures.append("%s: %s" % [current, what])


## A headless rig (a plain Environment and the sun, no sky material) and a dynamic sky material for the tear to drive.
func _rig() -> Array:
	var rig := EnvironmentRig.new()
	rig.name = "EnvironmentRig"
	root.add_child(rig)
	rig.build(WorldSettings.preset("low"))
	rig.set_process(false)   # stepped by hand below
	var mat := ShaderMaterial.new()
	mat.shader = load(SKY_SHADER)
	var tear := SkyTear.of(rig)
	tear.set_process(false)
	tear.material = mat
	return [rig, tear, mat]


## A float uniform as the material holds it (0 when never set).
func _f(mat: ShaderMaterial, uniform: StringName) -> float:
	var v: Variant = mat.get_shader_parameter(uniform)
	return 0.0 if v == null else float(v)


func _free(rig: Node) -> void:
	rig.queue_free()
	await process_frame


## Both clocks one step (the rig's wonder, the tear's).
func _step(rig: EnvironmentRig, tear: SkyTear, dt := DT) -> void:
	tear._process(dt)
	rig._process(dt)


func test_tear_over_time() -> void:
	var r := _rig()
	var rig: EnvironmentRig = r[0]
	var tear: SkyTear = r[1]
	var mat: ShaderMaterial = r[2]
	var secs := 6.0
	var opened := [false]
	tear.opened.connect(func() -> void: opened[0] = true)
	var t := SkyTear.begin(rig, DIR, secs, 2.0)
	check(t == tear, "begin uses the rig's one SkyTear")
	check(rig.get_node_or_null(SkyTear.NODE_NAME) == tear, "it lives under the rig as %s" % SkyTear.NODE_NAME)
	check(tear.running, "the tear is running")
	var td: Vector3 = mat.get_shader_parameter(&"tear_dir")
	check(td.is_equal_approx(DIR.normalized()), "tear_dir is the direction, normalised (%s)" % td)
	check(is_equal_approx(_f(mat, &"tear_seed"), 2.0), "tear_seed is the pattern")
	check(is_zero_approx(_f(mat, &"tear_amount")), "tear_amount starts at 0")
	var prev := -1.0
	var mono := true
	var wonder_early := 0.0
	var at_03 := -1.0
	var at_07 := -1.0
	var reveal_t := -1.0
	var n := int(ceil(secs / DT))
	for i in n:
		_step(rig, tear)
		var a := _f(mat, &"tear_amount")
		if tear.running:
			mono = mono and a >= prev
			prev = a
			if i % 60 == 0:
				check(is_equal_approx(a, tear.amount), "tear_amount is the tear's amount (%.3f, %.3f)" % [a, tear.amount])
		var time := (i + 1) * DT
		if at_03 < 0.0 and time >= 0.3 * secs:
			at_03 = a
		if at_07 < 0.0 and time >= 0.7 * secs:
			at_07 = a
		if tear.amount < SkyTear.REVEAL_AT - 0.02 and tear.running:
			wonder_early = maxf(wonder_early, rig.wonder)
		if reveal_t < 0.0 and tear.revealed:
			reveal_t = time
	check(mono, "tear_amount only grows while the tear runs")
	check(absf(at_03 - 0.3) < 0.02, "a third of the way: tear_amount ~0.3 (%.3f)" % at_03)
	check(absf(at_07 - 0.7) < 0.02, "0.7 of the way: tear_amount ~0.7 (%.3f)" % at_07)
	check(is_zero_approx(wonder_early), "no wonder before REVEAL_AT (%.3f)" % wonder_early)
	check(absf(reveal_t - SkyTear.REVEAL_AT * secs) < 0.05, "the reveal starts at REVEAL_AT of the time (%.2f s)" % reveal_t)
	check(rig.wonder > 0.9, "the wonder near full as the tear ends (%.3f)" % rig.wonder)
	# a few frames over (the rig's wonder lands on 1 on the step the tear ends, or the next)
	for i in 10:
		_step(rig, tear)
	check(is_equal_approx(rig.wonder, 1.0), "the reveal reached: wonder 1 (%.3f)" % rig.wonder)
	check(not tear.running, "the tear is done")
	check(opened[0], "opened emitted")
	check(is_zero_approx(_f(mat, &"tear_amount")), "tear_amount put back to 0 (the wonder holds the sky)")
	# through the tree's own clocks too: a short one ends by itself
	rig.set_wonder(0.0)
	rig.set_process(true)
	tear.set_process(true)
	opened[0] = false
	SkyTear.begin(rig, DIR, 0.6)
	var t0 := Time.get_ticks_msec()
	while not opened[0] and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	check(opened[0], "a 0.6 s tear opens the sky by itself (%d ms)" % (Time.get_ticks_msec() - t0))
	check(is_equal_approx(rig.wonder, 1.0), "... the wonder at 1")
	await _free(rig)


## Held (the story's: the cutter falling), the tear creeps out toward HOLD_TO and no further, the wonder not begun; let go,
## it runs on at 1 / seconds from where it was to the whole sky open; a hold never outlasts HOLD_MAX_S.
func test_hold() -> void:
	var r := _rig()
	var rig: EnvironmentRig = r[0]
	var tear: SkyTear = r[1]
	var mat: ShaderMaterial = r[2]
	var secs := 8.0
	var opened := [false]
	tear.opened.connect(func() -> void: opened[0] = true)
	SkyTear.begin(rig, DIR, secs, 1.0, true)
	check(tear.running and tear.held, "begun held")
	var at_1 := -1.0
	for i in int(12.0 / DT):
		_step(rig, tear)
		if at_1 < 0.0 and (i + 1) * DT >= 1.0:
			at_1 = tear.amount
	check(at_1 > 0.02 and at_1 < SkyTear.HOLD_TO, "a second in: the crack has begun (%.3f)" % at_1)
	check(tear.amount <= SkyTear.HOLD_TO + 1e-4 and tear.amount > 0.9 * SkyTear.HOLD_TO,
			"held 12 s: it crept to ~HOLD_TO and no further (%.3f)" % tear.amount)
	check(is_equal_approx(_f(mat, &"tear_amount"), tear.amount), "the sky draws the held tear (%.3f)" % _f(mat, &"tear_amount"))
	check(is_zero_approx(rig.wonder) and not tear.revealed, "held: no wonder yet")
	var a0 := tear.amount
	SkyTear.let_go(rig)
	check(not tear.held, "let_go: no longer held")
	for i in 60:
		_step(rig, tear)
	check(absf(tear.amount - (a0 + 1.0 / secs)) < 0.01, "let go, it runs on at 1 / seconds (%.3f after 1 s from %.3f)" % [tear.amount, a0])
	var t_left := (1.0 - a0) * secs
	var t := 1.0
	var reveal_t := -1.0
	while tear.running and t < t_left + 3.0:
		_step(rig, tear)
		t += DT
		if reveal_t < 0.0 and tear.revealed:
			reveal_t = t
	var want := (SkyTear.REVEAL_AT - a0) * secs
	check(absf(reveal_t - want) < 0.1, "the wonder begins at REVEAL_AT (%.2f s after the let-go, %.2f wanted)" % [reveal_t, want])
	check(not tear.running and opened[0] and is_equal_approx(rig.wonder, 1.0),
			"the sky open %.1f s after the let-go (%.1f wanted)" % [t, t_left])
	# a hold that is never let go lets itself go
	rig.set_wonder(0.0)
	SkyTear.begin(rig, DIR, 2.0, 1.0, true)
	for i in int((SkyTear.HOLD_MAX_S + 0.5) / DT):
		_step(rig, tear)
	check(not tear.held and tear.amount > SkyTear.HOLD_TO, "a hold never let go lets itself go after HOLD_MAX_S (%.2f)" % tear.amount)
	await _free(rig)


func test_flash() -> void:
	var r := _rig()
	var rig: EnvironmentRig = r[0]
	var tear: SkyTear = r[1]
	var mat: ShaderMaterial = r[2]
	check(is_zero_approx(tear.flash_amount), "no flash to begin with")
	SkyTear.flash(rig, 0.8, Vector3(0.0, 2.0, -2.0))
	check(is_equal_approx(_f(mat, &"impact_flash"), 0.8), "impact_flash set")
	var fd: Vector3 = mat.get_shader_parameter(&"impact_flash_dir")
	check(fd.is_equal_approx(Vector3(0.0, 1.0, -1.0).normalized()), "impact_flash_dir normalised (%s)" % fd)
	SkyTear.flash(rig, 0.3)
	check(is_equal_approx(tear.flash_amount, 0.8), "a weaker hit does not dim a stronger one")
	check(Vector3(mat.get_shader_parameter(&"impact_flash_dir")) == Vector3.ZERO, "no direction: the whole sky")
	tear._process(SkyTear.FLASH_HALF_LIFE)
	check(absf(_f(mat, &"impact_flash") - 0.4) < 0.01, "half gone after a half-life (%.3f)"
			% _f(mat, &"impact_flash"))
	for i in 60:
		tear._process(DT)
	check(is_zero_approx(_f(mat, &"impact_flash")), "gone within a second")
	check(not tear.running and is_zero_approx(_f(mat, &"tear_amount")), "a flash alone tears nothing")
	await _free(rig)


func test_already_open() -> void:
	var r := _rig()
	var rig: EnvironmentRig = r[0]
	var tear: SkyTear = r[1]
	var mat: ShaderMaterial = r[2]
	rig.set_wonder(1.0)
	SkyTear.begin(rig, DIR, 5.0)
	check(not tear.running, "a sky already open is left alone")
	for i in 30:
		_step(rig, tear)
	check(is_zero_approx(_f(mat, &"tear_amount")), "no tear drawn over it")
	check(is_equal_approx(rig.wonder, 1.0), "the wonder kept")
	await _free(rig)


func test_pose() -> void:
	var r := _rig()
	var rig: EnvironmentRig = r[0]
	var tear: SkyTear = r[1]
	var mat: ShaderMaterial = r[2]
	SkyTear.pose(rig, DIR, 0.3)
	check(is_equal_approx(_f(mat, &"tear_amount"), 0.3), "pose 0.3: tear_amount 0.3")
	check(is_zero_approx(rig.wonder), "pose 0.3: no wonder yet")
	check(not tear.running, "a pose holds (no clock)")
	var a := SkyTear.REVEAL_AT + 0.5 * (1.0 - SkyTear.REVEAL_AT)
	SkyTear.pose(rig, DIR, a)
	check(is_equal_approx(rig.wonder, 0.5), "pose half way through the reveal: the wonder eased to 0.5 (%.3f)" % rig.wonder)
	check(is_equal_approx(SkyTear.wonder_at(1.0), 1.0) and is_zero_approx(SkyTear.wonder_at(SkyTear.REVEAL_AT)),
			"wonder_at: 0 at REVEAL_AT, 1 at the end")
	await _free(rig)


func test_shader() -> void:
	var inc := FileAccess.get_file_as_string(WONDER_INC)
	var sky := FileAccess.get_file_as_string(SKY_SHADER)
	for u in ["uniform float tear_amount = 0.0;", "uniform vec3 tear_dir", "uniform float tear_seed",
			"uniform float impact_flash = 0.0;", "uniform vec3 impact_flash_dir"]:
		check(u in inc, "wonder_sky.gdshaderinc declares %s" % u)
	check("#include \"%s\"" % WONDER_INC in sky, "the dynamic sky includes the wonder sky")
	check(sky.count("if (tear_amount > 0.0") >= 1 and "tear = sky_tear(d, px, t_open, t_dark, t_in);" in sky,
			"the tear is drawn only while tear_amount > 0 (the frontier's sky untouched otherwise)")
	check("extra *= 1.0 - t_dark;" in sky and "tear_inner_bright * t_in" in sky,
			"the sky darkened at the cracks' rims, the etherium's own light poured in through them")
	check("if (impact_flash > 0.0)" in sky, "the flash only while impact_flash > 0")
	check("wl = max(wl, t_open);" in sky, "through the tear the wonder shows at full")
	# a hit flares the tear alike inside the cracks' reach and past it (else a flash shows the reach's edge as flat
	# lavender polygons in the sky: tear_shots flash=0.4, 2026-10-02)
	var body := inc.substr(inc.find("vec3 sky_tear("))
	check(body.count("return L * fade * boost;") == 2 and body.count("return L * fade;") == 0,
			"sky_tear's two returns both flare with the flash (boost)")
	# a break, not lightning (review 2026-10-02: "the tear reads as lightning"): no white-gold plasma, no hairline net,
	# no fast flicker, no hot tips
	check(not ("TEAR_M2" in inc) and not ("tear_core_color" in inc) and not ("sky_time * (17.0" in inc)
			and not ("hot = 1.0 + 6.0" in inc), "no hairline network, no white-gold core, no flicker, no burning tips")
	check("tear_rim_dark" in inc and "tear_lip_color" in inc, "the cracks' lips lit from behind and a dark rim outside them")
	var mat := ShaderMaterial.new()
	mat.shader = load(SKY_SHADER)
	check(mat.shader != null, "the dynamic sky loads")
	check(mat.get_shader_parameter(&"tear_amount") == null, "a fresh sky has no tear set")
