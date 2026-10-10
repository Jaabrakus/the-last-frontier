extends SceneTree
## The rebuilt Spellbreak effects, windowed: the visual check against the Spellbreak FX browser and the draw-side perf
## (Spellbreak by Proletariat; provenance in assets/fx/spellbreak/SOURCE.md). Was the capture mode of
## tests/fx/test_cascade_runtime.gd, which keeps the headless checks.
##
## Capture (same scene, framing, seed and shot times as the browser's sweep, browser.gd _sweep_step):
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --fixed-fps 60 -s tools/fx/cascade_capture.gd -- \
##         capture=<abs dir> list=<browser rows, e.g. 112,111,78,516,204,12> [perf=on]
## writes <dir>/<row>_<k>.png (480x270, k = 0.12 / 0.45 / 1.1 s), like the browser's --sweep --list=... --out=<dir>. The wrapper
## adds --disable-vsync --max-fps 60 and never pins the window on top. perf=on then plays the test's 8-effect PERF_SET through
## SpellFx in this window and prints "PERF window ...": the step's CPU time and the whole frame's (a draw-side number the
## headless test cannot give; the wrapper's --max-fps 60 caps the frame figure at 60 fps).

const Test := preload("res://tests/fx/test_cascade_runtime.gd")
const SWEEP_SHOTS := [0.12, 0.45, 1.1]
const SWEEP_LEN := 1.6

var args := {}
var cam: Camera3D
var mover: Node3D
var move_t := 0.0
var moving := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "on"
	if DisplayServer.get_name() == "headless" or not args.has("capture"):
		push_error("cascade_capture: needs a window (not --headless) and capture=<abs dir>")
		quit(1)
		return
	_capture.call_deferred()


## Moves `mover` as the browser does for effects that need motion (back and forth along x at 15 m/s).
func _move(dt: float) -> void:
	if not moving:
		return
	move_t += dt
	var span := 12.0
	var x := fmod(move_t * Test.MOVE_SPEED, span * 2.0)
	var dir := 1.0 if x < span else -1.0
	var px := (x if x < span else span * 2.0 - x) - span * 0.5
	mover.position = Vector3(px, 1.2, 0)
	mover.basis = Basis() if dir > 0.0 else Basis(Vector3.UP, PI)


var cap_dir := ""
var cap_rows: Array = []
var cap_t := 0.0
var cap_bounds := AABB()
var fx: CascadeFx
var lib: CascadeMaterials


func _capture() -> void:
	cap_dir = String(args.capture)
	DirAccess.make_dir_recursive_absolute(cap_dir)
	var index: Dictionary = {}
	for id: String in SpellFx.catalogue():
		index[int(SpellFx.catalogue()[id].source_index)] = id
	for v in String(args.get("list", "112,111,78,516,204,12")).split(","):
		cap_rows.append(int(v))
	var stage := Node3D.new()
	root.add_child(stage)
	_world(stage)
	mover = Node3D.new()
	stage.add_child(mover)
	fx = CascadeFx.new()
	mover.add_child(fx)
	cam = Camera3D.new()
	cam.fov = 55
	stage.add_child(cam)
	cam.current = true
	lib = CascadeMaterials.shared()
	for row: int in cap_rows:
		var id: String = index.get(row, "")
		if id == "":
			print("  no imported effect at browser row %d" % row)
			continue
		# browser.gd _load: the same seed for an effect on every run, so both sides draw the same random sequence
		var sp := SpellFx.spec(id)
		moving = Test.needs_motion(sp)
		move_t = 0.0
		mover.position = Vector3(0, 1.2, 0)
		mover.basis = Basis()
		seed(hash(id))
		CascadeFx.rng.seed = hash(id)              # (the runtime's own dice: the same PCG sequence the browser's global seed gives)
		fx.setup(sp, lib, cam)
		fx.activate()
		cap_t = 0.0
		cap_bounds = AABB()
		while cap_t < SWEEP_LEN:
			await process_frame
			var dt := 1.0 / 60.0
			_move(dt)
			fx.step(dt)
			_sweep_step(dt, row)
		print("  captured %d %s" % [row, id.get_file()])
	if args.get("perf", "") == "on":
		await _window_perf()
	quit(0)


func _world(stage: Node3D) -> void:
	var env := Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.8
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.52, 0.78)
	sm.sky_horizon_color = Color(0.72, 0.8, 0.86)
	sm.ground_horizon_color = Color(0.6, 0.62, 0.6)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.42, 0.34)
	gm.roughness = 1.0
	ground.material_override = gm
	stage.add_child(ground)


func _sweep_bounds() -> AABB:
	var b := AABB()
	var first := true
	for e in fx.emitters:
		for p in e.particles:
			var w: Vector3 = e.world_pos(p)
			var r := maxf(p.size.x, p.size.y) * CascadeFx.CM * 0.5
			if e.s.type == "mesh" and e.mm_inst and e.mm_inst.multimesh.mesh:
				r = e.mm_inst.multimesh.mesh.get_aabb().size.length() * 0.5 * maxf(p.size.x, maxf(p.size.y, p.size.z))
			var bb := AABB(w - Vector3.ONE * r, Vector3.ONE * r * 2.0)
			b = bb if first else b.merge(bb)
			first = false
	return b


## browser.gd _sweep_step: frame the effect (stationary ones by their bounds, moving ones follow the mover) and save
## the frame drawn last tick at each shot time.
func _sweep_step(dt: float, row: int) -> void:
	cap_t += dt
	if fx.particle_count() > 0:
		var b := _sweep_bounds()
		cap_bounds = b if cap_bounds.size == Vector3.ZERO else cap_bounds.merge(b)
	var c := mover.global_position if moving else (cap_bounds.get_center() if cap_bounds.size != Vector3.ZERO else Vector3(0, 1.2, 0))
	var ext := clampf(cap_bounds.size.length() * 0.5, 0.5, 10.0) if not moving else 2.0
	var off := Vector3(sin(0.6), 0.3, cos(0.6)).normalized() * (ext * 1.5 + 0.8)
	cam.global_position = c + off
	cam.look_at(c, Vector3.UP)
	for k in SWEEP_SHOTS.size():
		var t: float = SWEEP_SHOTS[k]
		if cap_t >= t and cap_t - dt < t:
			var img := root.get_texture().get_image()
			if img:
				img.resize(480, 270)
				img.save_png(cap_dir.path_join("%04d_%d.png" % [row, k]))


## The 8-effect set through SpellFx in this window: the step's CPU time and the whole frame's.
func _window_perf() -> void:
	fx.clear()
	var player := SpellFx.of(root)
	await SpellFx.prewarm(Test.PERF_SET, cam)
	cam.global_position = Vector3(0, 4, 12)
	cam.look_at(Vector3(0, 1.2, -2), Vector3.UP)
	moving = true
	move_t = 0.0
	var handles: Array = []
	for i in Test.PERF_SET.size():
		handles.append(SpellFx.spawn(Test.PERF_SET[i], _perf_at(i)))
	var steps: Array[float] = []
	var frames: Array[float] = []
	var early_max := 0.0                 # the first 30 frames after prewarm: first draws of every effect
	var last := Time.get_ticks_usec()
	for f in 300:
		_move(1.0 / 60.0)
		await process_frame
		var now := Time.get_ticks_usec()
		if f >= 30 and f != 151:          # (frame 151 holds the screenshot's read-back and PNG save)
			steps.append(player.last_step_usec / 1000.0)
			frames.append((now - last) / 1000.0)
		elif f < 30:
			early_max = maxf(early_max, (now - last) / 1000.0)
		last = now
		for i in handles.size():
			if not (handles[i] as SpellFx.Handle).is_playing():
				handles[i] = SpellFx.spawn(Test.PERF_SET[i], _perf_at(i))
		if f == 150:
			var img := root.get_texture().get_image()
			if img:
				img.save_png(cap_dir.path_join("perf_8_effects.png"))
	var st: Dictionary = Test._stats(steps)
	var fr: Dictionary = Test._stats(frames)
	print("PERF window 8 effects: SpellFx step %.2f ms avg (p95 %.2f), frame %.2f ms avg (p95 %.2f, max %.2f); first 30 frames after prewarm max %.2f ms" % [
			st.avg, st.p95, fr.avg, fr.p95, fr.max, early_max])


## Where PERF_SET[i] plays: the first follows the mover, the rest stand along a row.
func _perf_at(i: int) -> Variant:
	return mover if i == 0 else Transform3D(Basis(), Vector3(-7.0 + 2.0 * i, 1.2, -3.0))
