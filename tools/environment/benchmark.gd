extends SceneTree
## Rendering benchmark for the Frontier level. Needs a window (not --headless). Wrap it in a
## time limit, because a script error leaves the window open.
##
##   Godot --path . --resolution 1600x900 -s tools/environment/benchmark.gd -- --no-capture \
##       [quality=high|low] [scale=1.0] [out=<summary.json>] [only=seg1,seg2] [probe=0]
##       [scene=res://...tscn]      (default res://scenes/main.tscn)
##
## WHY TWO MEASUREMENTS: on this Mac (Metal, windowed, 60 Hz display) presentation is paced
## by the compositor: even an empty scene with vsync disabled runs at exactly 60 fps, and
## Metal GPU timestamps read 0. So every segment is measured twice:
##
##  1. paced   -- the real game loop, as the player sees it. Frame times, avg/min fps and
##                hitches (frames > 25 ms, i.e. a missed refresh). avg_fps can never exceed
##                the display rate (60).
##  2. cost    -- the uncapped cost of a frame. At 6 poses along the segment the frame is
##                re-rendered 15 times with RenderingServer.force_draw(false) (no present,
##                so no vsync wait; the RenderingDevice frame queue still waits for the GPU,
##                so this is max(CPU render, GPU) per frame -- verified: 2x render scale
##                doubles it). render_ms is the mean over poses, render_max_ms the worst pose.
##                The probe renders an off-window SubViewport of the window's size with the
##                root viewport's settings (offscreen_view.gd; the root's 3D is off meanwhile),
##                so it is valid even when the OS hides the window.
##                logic_ms (scripts, animation, physics, audio at 60 fps with 120 Hz physics)
##                comes from Godot's own monitors during the paced player segments
##                (Performance.TIME_PROCESS + 2 x TIME_PHYSICS_PROCESS per 60 fps frame, the
##                95th percentile). The older estimate with the render loop off (_logic_ms)
##                is still printed as "logic_loop_ms": on 2026-09-24 it read ~10 ms because
##                the main loop idles at ~100 Hz without rendering, so it is no longer used.
##                est_fps = 1000 / (render_max_ms + logic_ms): a conservative, serial estimate.
##
## Per segment one greppable line:
##   BENCH seg=<name> G|F frames= avg_fps= min_fps= mean_ms= p99_ms= max_ms= hitches=
##         render_ms= render_max_ms= est_fps= draws= prims= objs=
## then "BENCH logic logic_ms=..." and three totals, each "... target60=PASS|FAIL":
##   BENCH total gameplay   the fort segments [G] (player in the fort looking down the range)
##   BENCH total forest     the player-driven forest segments [P] (walk, sprint, fast turns,
##                          looking across the forest from its edge) -- the playtest's "laggy
##                          forest" (2026-09-24)
##   BENCH total all        G + P: every place the player can go. PASS needs paced avg >= 59 fps
##                          (or the display's rate) with <= 1 % hitches, and est_fps >= 60 at
##                          the worst pose.
## Free-camera segments [F] are reported (worst render in "BENCH total free") but not judged.
## macOS stops drawing a hidden (occluded / other Space) window; such frames are counted as
## OCCLUDED, and if > 5 % of a total's frames were hidden only est_fps is judged.
## The run ends with BENCHMARK DONE. probe=0 skips the cost measurement (paced only).
##
## `quality=` is passed through untouched: the world scripts read it from the user args
## (WorldSettings, see the look-dev spec). The benchmark only reports it.
##
## Segments (G = gameplay camera, F = free camera):
##   fort_range_look  G  player at spawn (0,0.1,6), yaw sweeps +-22 deg around north
##   fort_range_aim   G  same, musket raised (RMB, zoomed FOV), yaw +-6 deg on the range
##   gate_fly         F  eye height from the parade ground out through the gate to z = -30
##   walkway_pan      F  standing on the east walkway, panning 120 deg over wall and forest
##   range_lookback   F  from the 120 m dummy looking back at the fort, slow dolly
##   forest_walk      F  walking through the forest west of the range, turning 360 deg
##   aerial_orbit     F  30 m high orbit around the fort (worst-case draw distance)
##   forest_walk_p    P  the player walks (Alt) through the forest on a trunk-free heading,
##                       with the real third-person camera, grass, footsteps and physics
##   forest_run_p     P  the player sprints (Shift) 55 m through the forest
##   forest_turn_p    P  the player stands in dense forest and turns 2 x 360 deg in 6 s
##   edge_look_p      P  the player at the forest edge west of the fort, looking across the
##                       clearing and the forest beyond, sweeping +-50 deg
## Player segments start from a fixed forest point and heading, chosen at startup by
## sweeping a 0.5 m sphere along candidate headings against the trunk / rock / log colliders
## (deterministic: same world, same path). The cost probe replays 6 camera poses recorded
## during the paced run.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

const SEGMENTS := [
	# [name, kind (G gameplay fort, P player in the forest, F free camera), seconds]
	["fort_range_look", "G", 8.0],
	["fort_range_aim", "G", 6.0],
	["gate_fly", "F", 6.0],
	["walkway_pan", "F", 6.0],
	["range_lookback", "F", 6.0],
	["forest_walk", "F", 8.0],
	["aerial_orbit", "F", 6.0],
	["forest_walk_p", "P", 10.0],
	["forest_run_p", "P", 10.0],
	["forest_turn_p", "P", 6.0],
	["edge_look_p", "P", 8.0],
]
## Forest starting points tried for the player segments (x, z), in order.
const FOREST_STARTS := [Vector2(-70.0, -55.0), Vector2(-85.0, 15.0), Vector2(60.0, 70.0), Vector2(75.0, -45.0),
		Vector2(-50.0, 75.0)]
const SETTLE := 0.4
const HITCH_MS := 25.0
const COST_POSES := 6
const COST_DRAWS := 15

var args := {}
var player: FrontierPlayer
var cam: Camera3D
var probe_view: SubViewport
var results := []
var logic_ms := 0.0
var logic_loop_ms := 0.0          ## Old estimate (render loop off); printed for comparison only.
var logic_hidden := 0             ## Frames of the logic probe with the window hidden.
var logic_samples := PackedFloat32Array()   ## Per-frame process + physics ms (P and G segments).
var forest_start := Vector3.ZERO  ## Player segments: start point (on the ground) and heading.
var forest_heading := Vector3.FORWARD
var forest_clear := 0.0
var turn_spot := Vector3.ZERO
var recorded := []                ## Camera poses recorded during a paced P segment.


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var scale := float(args.get("scale", "1.0"))
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	var probe: bool = args.get("probe", "1") != "0"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	# A hidden window makes the main loop sleep 6.9 ms per frame (OS.add_frame_delay): off.
	OS.low_processor_usage_mode_sleep_usec = 0
	_block_user_input()
	change_scene_to_file(String(args.get("scene", "res://scenes/main.tscn")))
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_release_all()
	player.switch_weapon("musket")

	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 1500.0
	current_scene.add_child(cam)
	probe_view = OffscreenView.new()
	probe_view.name = "BenchProbeView"
	root.add_child(probe_view)
	probe_view.setup(root, DisplayServer.window_get_size())
	probe_view.render_target_update_mode = SubViewport.UPDATE_DISABLED

	_print_header()
	# Warm-up: shader compilation, pipeline caches, shadow maps, GI cascades.
	var warm_max := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	while Time.get_ticks_usec() - t0 < 3_000_000:
		_pose(SEGMENTS[0][0], fmod((Time.get_ticks_usec() - t0) / 3e6, 1.0))
		await process_frame
		var now := Time.get_ticks_usec()
		warm_max = maxf(warm_max, (now - last) / 1000.0)
		last = now
	print("BENCH warmup max_ms=%.1f" % warm_max)

	if probe and args.get("logic_loop", "0") == "1":
		player.camera.current = true
		logic_loop_ms = await _logic_ms()
		print("BENCH logic_loop logic_loop_ms=%.2f (render loop off; see the header)" % logic_loop_ms)

	_find_forest_path()
	for seg: Array in SEGMENTS:
		if not only.is_empty() and not String(seg[0]) in only:
			continue
		results.append(await _run(seg[0], seg[1], seg[2] * scale, probe))

	# Game logic per 60 fps frame from the monitors (95th percentile over the G and P frames).
	if not logic_samples.is_empty():
		var ls := logic_samples.duplicate()
		ls.sort()
		logic_ms = ls[mini(ls.size() - 1, int(ls.size() * 0.95))]
		var mean := 0.0
		for v in ls:
			mean += v / ls.size()
		print("BENCH logic logic_ms=%.2f (p95; mean %.2f) = TIME_PROCESS + 2 x TIME_PHYSICS_PROCESS per 60 fps frame over %d player frames" % [
				logic_ms, mean, ls.size()])
	for r: Dictionary in results:
		if probe:
			r.est_fps = 1000.0 / (r.render_max_ms + logic_ms)
	_total("gameplay", results.filter(func(r: Dictionary) -> bool: return r.kind == "G"), probe, true)
	_total("forest", results.filter(func(r: Dictionary) -> bool: return r.kind == "P"), probe, true)
	_total("all", results.filter(func(r: Dictionary) -> bool: return r.kind != "F"), probe, true)
	_total("free", results.filter(func(r: Dictionary) -> bool: return r.kind == "F"), probe, false)
	if args.has("out"):
		var f := FileAccess.open(String(args["out"]), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"info": _info(), "logic_ms": logic_ms, "logic_loop_ms": logic_loop_ms,
					"forest_path": {"start": [forest_start.x, forest_start.y, forest_start.z],
						"heading": [forest_heading.x, forest_heading.z], "clear_m": forest_clear,
						"turn_spot": [turn_spot.x, turn_spot.y, turn_spot.z]},
					"segments": results}, "  "))
			f.close()
			print("BENCH wrote ", args["out"])
	print("BENCHMARK DONE")
	quit()


func _run(seg_name: String, kind: String, seconds: float, probe: bool) -> Dictionary:
	var gameplay := kind != "F"
	if gameplay:
		player.camera.current = true
		if player.hud:
			player.hud.visible = true
	else:
		cam.current = true
		if player.hud:
			player.hud.visible = false
	if kind == "G":
		_teleport(Vector3(0, 0.1, 6), 0.0)
	if seg_name == "fort_range_aim":
		Input.action_press("aim")
	if kind == "P":
		_start_player_segment(seg_name)
	recorded.clear()
	var frame_ms := PackedFloat32Array()
	var draws := 0.0
	var prims := 0.0
	var objs := 0.0
	var occluded := 0                 ## Frames the OS did not let the window draw.
	var start := Time.get_ticks_usec()
	var last := start
	var measured_us := 0
	while true:
		var el := (Time.get_ticks_usec() - start) / 1e6
		if el >= seconds + SETTLE:
			break
		_pose(seg_name, clampf((el - SETTLE) / seconds, 0.0, 1.0))
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		last = now
		if el >= SETTLE:
			if not DisplayServer.window_can_draw():
				occluded += 1
			frame_ms.append(dt)
			measured_us += int(dt * 1000.0)
			if gameplay:
				logic_samples.append(1000.0 * (Performance.get_monitor(Performance.TIME_PROCESS)
						+ 2.0 * Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)))
			if kind == "P":
				var prog := clampf((el - SETTLE) / seconds, 0.0, 1.0)
				if recorded.size() < COST_POSES and prog >= (recorded.size() + 0.5) / COST_POSES:
					var c3 := root.get_camera_3d()
					recorded.append([c3.global_transform, c3.fov])
			draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			objs += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)

	if kind == "P":
		_release_all()
	# Uncapped cost at fixed poses along the same path (P: the recorded camera poses).
	var render := PackedFloat32Array()
	if probe:
		for i in COST_POSES:
			if kind == "P":
				if i >= recorded.size():
					break
				render.append(await _force_draw_pose_ms(recorded[i][0], recorded[i][1]))
				continue
			_pose(seg_name, (i + 0.5) / COST_POSES)
			for k in 3:
				await process_frame
			render.append(_force_draw_ms())
	if seg_name == "fort_range_aim":
		Input.action_release("aim")

	var n := frame_ms.size()
	var sorted := frame_ms.duplicate()
	sorted.sort()
	var hitches := 0
	for v in frame_ms:
		if v > HITCH_MS:
			hitches += 1
	var r_mean := 0.0
	var r_max := 0.0
	for v in render:
		r_mean += v / render.size()
		r_max = maxf(r_max, v)
	var mean_ms := (measured_us / 1000.0) / n
	var stutter := 0                   ## Frames over 1.5x the segment's median (pacing spikes).
	for v in frame_ms:
		if v > 1.5 * sorted[n / 2] and v > 12.0:
			stutter += 1
	var r := {
		"segment": seg_name,
		"kind": kind,
		"gameplay": gameplay,
		"stutter": stutter,
		"median_ms": sorted[n / 2],
		"frames": n,
		"avg_fps": n / (measured_us / 1e6),
		"min_fps": 1000.0 / sorted[n - 1],
		"mean_ms": mean_ms,
		"p95_ms": sorted[int(n * 0.95)],
		"p99_ms": sorted[mini(n - 1, int(n * 0.99))],
		"max_ms": sorted[n - 1],
		"hitches": hitches,
		"occluded": occluded,
		"render_ms": r_mean,
		"render_max_ms": r_max,
		"render_poses": Array(render),
		"est_fps": 1000.0 / (r_max + logic_ms) if probe else 0.0,
		"draws": draws / n,
		"prims": prims / n,
		"objs": objs / n,
	}
	print("BENCH seg=%-16s %s frames=%5d avg_fps=%5.1f min_fps=%5.1f mean_ms=%5.2f p99_ms=%5.2f max_ms=%6.2f hitches=%3d stutter=%3d render_ms=%5.2f render_max_ms=%5.2f render_fps=%4.0f draws=%5d prims=%8d objs=%5d%s" % [
			seg_name, kind, n, r.avg_fps, r.min_fps, r.mean_ms, r.p99_ms,
			r.max_ms, hitches, stutter, r_mean, r_max, 1000.0 / maxf(r_max, 0.01), int(r.draws), int(r.prims), int(r.objs),
			"" if occluded == 0 else " OCCLUDED=%d (paced numbers invalid: window hidden)" % occluded])
	return r


## One total line over `rs`: paced avg / min fps, hitches, worst render pose, est_fps, PASS/FAIL.
func _total(label: String, rs: Array, probe: bool, judged: bool) -> void:
	if rs.is_empty():
		return
	var frames := 0
	var ms := 0.0
	var mn := INF
	var hitches := 0
	var stutter := 0
	var est := INF
	var render := 0.0
	var worst := ""
	var occluded := 0
	for r: Dictionary in rs:
		occluded += r.occluded
		frames += r.frames
		ms += r.mean_ms * r.frames
		mn = minf(mn, r.min_fps)
		hitches += r.hitches
		stutter += r.stutter
		if probe:
			est = minf(est, r.est_fps)
		if r.render_max_ms > render:
			render = r.render_max_ms
			worst = r.segment
	var avg := 1000.0 / (ms / frames)
	var target_fps := minf(59.0, DisplayServer.screen_get_refresh_rate() - 1.0)
	var paced_ok := occluded > frames / 20 or (avg >= target_fps and hitches <= frames / 100)
	var ok := paced_ok and (not probe or est >= 60.0)
	print("BENCH total %s avg_fps=%.1f min_fps=%.1f hitches=%d/%d stutter=%d render_max_ms=%.2f (%s) logic_ms=%.2f est_fps=%.0f%s%s" % [
			label, avg, mn, hitches, frames, stutter, render, worst, logic_ms, est if probe else 0.0,
			(" target60=%s" % ("PASS" if ok else "FAIL")) if judged else " (not judged)",
			"" if occluded == 0 else " (window hidden for %d frames: judged on est_fps only)" % occluded])


## Places the player (feet at p) facing yaw (radians, 0 = north).
func _teleport(p: Vector3, yaw: float) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	player.yaw = yaw
	player.pitch = 0.0


func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _start_player_segment(seg: String) -> void:
	_release_all()
	match seg:
		"forest_walk_p", "forest_run_p":
			_teleport(forest_start + Vector3.UP * 0.1, _yaw_of(forest_heading))
			Input.action_press("move_forward")
			Input.action_press("walk" if seg == "forest_walk_p" else "sprint")
		"forest_turn_p":
			_teleport(turn_spot + Vector3.UP * 0.1, 0.0)
		"edge_look_p":
			var p := Vector3(-44.0, 0.0, 2.0)
			p.y = FrontierTerrain.height_at(p.x, p.z) + 0.1
			_teleport(p, _yaw_of(Vector3(1, 0, 0)))


## A trunk-free heading into the forest for the walk / sprint segments: from each FOREST_STARTS
## point, headings every 10 deg are swept with a 0.5 m sphere at 1 m above the ground (1 m steps,
## terrain ignored); the first start with a clear run of >= 60 m wins (else the longest). Also
## picks the densest nearby spot for the turn segment (most trunks within 12 m).
func _find_forest_path() -> void:
	var space := player.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.exclude = [player.get_rid()]
	var best := -1.0
	for s2: Vector2 in FOREST_STARTS:
		var start := Vector3(s2.x, FrontierTerrain.height_at(s2.x, s2.y), s2.y)
		var outward := Vector3(s2.x, 0, s2.y).normalized()
		for k in 36:
			var a := k * TAU / 36.0
			var dir := Vector3(sin(a), 0.0, -cos(a))
			if dir.dot(outward) < 0.2:
				continue
			var clear := 0.0
			for step in 70:
				var p := start + dir * float(step)
				p.y = FrontierTerrain.height_at(p.x, p.z) + 1.0
				q.transform = Transform3D(Basis(), p)
				var blocked := false
				for hit in space.intersect_shape(q, 8):
					var col: Object = hit.get("collider")
					if col and not (col as Node).is_in_group(&"terrain"):
						blocked = true
						break
				if blocked:
					break
				clear = float(step)
			if clear > best:
				best = clear
				forest_start = start
				forest_heading = dir
		if best >= 60.0:
			break
	forest_clear = best
	# Turn spot: 20 m along the path, nudged to the densest point nearby (most trees in the view).
	turn_spot = forest_start + forest_heading * minf(20.0, best * 0.5)
	turn_spot.y = FrontierTerrain.height_at(turn_spot.x, turn_spot.z)
	var n := 0
	for t in current_scene.get_tree().get_nodes_in_group(&"trees"):
		for cs in (t as Node).get_children():
			if cs is CollisionShape3D and (cs as Node3D).global_position.distance_to(turn_spot) < 12.0:
				n += 1
	print("BENCH forest_path start=(%.1f, %.1f, %.1f) heading=(%.2f, %.2f) clear=%.0f m turn_spot=(%.1f, %.1f) trunks_within_12m=%d" % [
			forest_start.x, forest_start.y, forest_start.z, forest_heading.x, forest_heading.z, best,
			turn_spot.x, turn_spot.z, n])


## Cost of the view from a recorded camera pose (P segments).
func _force_draw_pose_ms(xf: Transform3D, fov: float) -> float:
	cam.global_transform = xf
	cam.fov = fov
	cam.current = true
	for k in 3:
		await process_frame
	var ms := _force_draw_ms()
	player.camera.current = true
	return ms


## Mean ms of one frame of the current camera's view, rendered off-window without
## presenting (see the header).
func _force_draw_ms() -> float:
	probe_view.source = root.get_camera_3d()
	probe_view.sync_camera()
	probe_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.disable_3d = true
	for k in 8:
		RenderingServer.force_draw(false)
	var t := Time.get_ticks_usec()
	for k in COST_DRAWS:
		RenderingServer.force_draw(false)
	var ms := (Time.get_ticks_usec() - t) / 1000.0 / COST_DRAWS
	root.disable_3d = false
	probe_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return ms


## CPU cost of everything but rendering for one 60 fps frame (two 120 Hz physics ticks).
## With the render loop off the main loop runs free, so busy time T = F * c_frame + P * c_tick
## (F frames, P physics ticks). Two runs at different tick rates give c_frame and c_tick.
func _logic_ms() -> float:
	var hz := Engine.physics_ticks_per_second
	var runs := []
	RenderingServer.render_loop_enabled = false
	for rate: int in [hz, maxi(hz / 4, 15)]:
		Engine.physics_ticks_per_second = rate
		for i in 20:
			await process_frame
		var ticks := [0]
		var count := func() -> void: ticks[0] += 1
		physics_frame.connect(count)
		var t := Time.get_ticks_usec()
		var frames := 0
		while Time.get_ticks_usec() - t < 1_500_000:
			await process_frame
			frames += 1
			if not DisplayServer.window_can_draw():
				logic_hidden += 1
		var busy := (Time.get_ticks_usec() - t) / 1000.0
		physics_frame.disconnect(count)
		runs.append([float(frames), float(ticks[0]), busy])
	Engine.physics_ticks_per_second = hz
	RenderingServer.render_loop_enabled = true
	for i in 5:
		await process_frame
	# Solve [F1 P1; F2 P2] [c_frame c_tick]^T = [T1 T2]^T.
	var f1: float = runs[0][0]
	var p1: float = runs[0][1]
	var t1: float = runs[0][2]
	var f2: float = runs[1][0]
	var p2: float = runs[1][1]
	var t2: float = runs[1][2]
	var det := f1 * p2 - f2 * p1
	var c_frame := t1 / f1
	var c_tick := 0.0
	if absf(det) > 1e-6:
		c_frame = maxf((t1 * p2 - t2 * p1) / det, 0.0)
		c_tick = maxf((f1 * t2 - f2 * t1) / det, 0.0)
	print("BENCH logic_runs %s c_frame_ms=%.3f c_tick_ms=%.3f" % [str(runs), c_frame, c_tick])
	return c_frame + c_tick * hz / 60.0


## Camera / player pose for segment `seg` at progress t in [0, 1].
func _pose(seg: String, t: float) -> void:
	var s := sin(t * TAU)
	match seg:
		"forest_walk_p", "forest_run_p":
			# Steer along the clear heading, glancing left and right like a player does.
			player.yaw = _yaw_of(forest_heading) + deg_to_rad(18.0) * sin(t * TAU * 1.5)
			player.pitch = deg_to_rad(-3.0 + 5.0 * sin(t * TAU * 2.3))
		"forest_turn_p":
			player.yaw = t * TAU * 2.0
			player.pitch = deg_to_rad(8.0 * sin(t * TAU * 3.0))
		"edge_look_p":
			player.yaw = _yaw_of(Vector3(1, 0, 0)) + deg_to_rad(50.0) * s
			player.pitch = deg_to_rad(2.0)
		"fort_range_look":
			player.yaw = deg_to_rad(22.0 * s)
			player.pitch = deg_to_rad(-2.0 + 4.0 * sin(t * TAU * 2.0))
		"fort_range_aim":
			player.yaw = deg_to_rad(6.0 * s)
			player.pitch = deg_to_rad(1.0)
		"gate_fly":
			var p := Vector3(0.6 * s, 2.0, lerpf(9.0, -30.0, t))
			_look(p, Vector3(0.0, 1.4, -70.0))
		"walkway_pan":
			var yaw := deg_to_rad(lerpf(60.0, -60.0, t))
			var p := Vector3(9.0, 4.8, -13.2)   # Third-person camera height on the walkway.
			_look(p, p + Vector3(-sin(yaw), -0.12, -cos(yaw)))
		"range_lookback":
			var p := Vector3(lerpf(-6.0, 6.0, t), 1.7, -140.0)
			_look(p, Vector3(0.0, 3.0, -16.0))
		"forest_walk":
			var p := Vector3(-40.0 - 30.0 * t, 1.7, -40.0 - 25.0 * t)
			var yaw := t * TAU
			_look(p, p + Vector3(-sin(yaw), -0.05, -cos(yaw)))
		"aerial_orbit":
			var a := deg_to_rad(45.0) + t * deg_to_rad(90.0)
			var p := Vector3(55.0 * sin(a), 30.0, 55.0 * cos(a))
			_look(p, Vector3(0.0, 0.0, -25.0))


## Free-camera placement. Terrain may rise outside the flat zones, so a camera near the
## ground is kept at least 1.6 m above whatever is below it (a ray against the colliders).
func _look(p: Vector3, target: Vector3) -> void:
	if p.y < 10.0:
		var space := cam.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 60.0)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit and p.y - hit.position.y < 1.6 and hit.position.y < p.y + 8.0:   # Not a tree top.
			var lift: float = hit.position.y + 1.6 - p.y
			p.y += lift
			target.y += lift
	cam.global_position = p
	cam.look_at(target)


func _info() -> Dictionary:
	var rd := RenderingServer.get_rendering_device()
	return {
		"godot": Engine.get_version_info().string,
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"method": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"device": rd.get_device_name() if rd else "",
		"window": DisplayServer.window_get_size(),
		"viewport": root.get_visible_rect().size,
		"scale_factor": DisplayServer.screen_get_scale(),
		"refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"vsync": DisplayServer.window_get_vsync_mode(),
		"quality_arg": args.get("quality", "(default)"),
		"cpu": OS.get_processor_name(),
	}


func _print_header() -> void:
	var i := _info()
	print("BENCH info godot=%s driver=%s method=%s adapter=%s window=%s viewport=%s scale=%s refresh=%.0f vsync=%s quality=%s" % [
			i.godot, i.driver, i.method, i.adapter, i.window, i.viewport, i.scale_factor,
			i.refresh_hz, i.vsync, i.quality_arg])


## The window opens on the user's screen and takes keyboard focus for a moment: every game
## action is unbound before the level loads (InputSetup.ensure() first, so the player's own
## call adds nothing later), so stray key presses or clicks cannot move the player or fire.
## Input.action_press() (the scripted segments) still works without bindings.
func _block_user_input() -> void:
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	_release_all()


func _release_all() -> void:
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			Input.action_release(action)
