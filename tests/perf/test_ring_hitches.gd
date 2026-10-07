extends SceneTree
## The waits of Tidebreak's ring, measured (improvement round 1, PERF: "the first ring load takes 20-35 s with a window that
## looks frozen"; "a ~1 s freeze at each round restart"): the way a player comes in from the menu's Begin (MatchSetup
## asked for, LoadingScreen into scenes/ring.tscn), then a three-round match whose rounds are ended by the test (a round to
## each side, then the third: RingMode._end_round "territory" after FIGHT_S of fight; the round's pause skipped after
## OVER_S, as Space does). Each frame's wall time is taken (Time.get_ticks_usec between process frames: a shader or pipeline
## compiled while drawing shows there too) and put to the stretch it fell in:
##   pre        go() until the loading screen's first frame is drawn
##   load       from there until the first round's fight (the ring built under the loading screen, the effects warmed, the
##              loading screen's fade, the countdown)
##   restart<n> from round n-1's end until round n's fight (the round screen, the next round's set-up: the deck, the bot)
## Printed (greppable, tools read them):
##   PERF display=<server> load_screen_ms=<go to the loading screen drawn> to_ring_ms=<go to the loading screen gone>
##        to_fight_ms=<go to the first fight> load_longest_ms=<longest frame of "load"> load_frames=<n> warm_ms=<the
##        effects' warm-up>
##   PERF restart<n>_longest_ms=<ms> frames=<n>
##   PERF pipelines canvas=.. mesh=.. surface=.. draw=.. specialization=.. (compiled over the run; "draw" ones were compiled
##        while drawing: each is a stall)
##   PERF hitch <stretch> #<frame> <ms> (process, draw, physics, of it scripts, steps; pipelines) for each frame over
##        HITCH_US as it happens (Clock: where the frame went)
##   PERF slowest <stretch> #<frame> <ms> (the ten slowest frames)
## Run windowed through the lock (headless draws nothing: no shader stalls; its numbers are the CPU's alone), with the music
## and the quality as a player has them (the game's own default is medium: WorldSettings.GAME_QUALITY; a script run's is
## high):
##   Godot --path . -s tests/perf/test_ring_hitches.gd -- music=on quality=medium [load_ms=1000] [restart_ms=50] [foe=fire]
##         [frames_csv=<file>] [shots=<dir>] [diag=1]
##   Godot --headless --path . -s tests/perf/test_ring_hitches.gd -- [restart_ms=..]   (the restarts only: headless the ring
##         is built at once, not a part a frame, so the load's frame is reported, not judged)
## frames_csv writes every frame (stretch, frame, ms); shots saves the window at each line of the loading screen (a review
## run: the saves cost frames); diag prints, on a frame that compiled pipelines while drawing, the meshes added just before.
## The first and the second launch: a fresh user folder (an override.cfg beside project.godot with
## application/config/use_custom_user_dir and a new custom_user_dir_name; never committed) has an empty shader cache.
## Passes when the match was played to its end and the longest frames are within load_ms (after the loading screen shows)
## and restart_ms (each restart); a limit of 0 only reports. load_ms guards what the stepped build reached (its longest frame
## the player's own build: ~0.55-0.6 s windowed with the shader cache warm, ~3 s on a first launch); the round's aim of
## ~250 ms (LOAD_AIM_MS) is printed against it, not asserted, until FrontierPlayer._ready is built in steps too.
## In-test watchdog LIMIT_S. Last line "RING HITCHES PASSED" or
## "... FAILED"; exit 0 only on a pass.

const NAME := "RING HITCHES"
const LIMIT_S := 300.0
const OWN_CFG := "user://ring_hitches_test.cfg"
## s of fight before the test ends a round, and of the round's pause before it skips on.
const FIGHT_S := 1.5
const OVER_S := 1.5
## Who takes rounds 1, 2, 3 (a round each, then the match).
const WINNERS := [0, 1, 0]
## A frame longer than this (us) is printed as it happens ("PERF hitch <stretch> #<frame> <ms>"), among the level's lines.
const HITCH_US := 50000

var checks := 0
var fails: Array[String] = []
var load_ms := 1000.0
## The load's aim for its longest frame (improvement round 1, PERF), printed beside the measure.
const LOAD_AIM_MS := 250.0
var restart_ms := 50.0
## [stretch, frame number, ms] per frame.
var frames: Array = []
var stretch := "pre"
var mode: RingMode
var lvl: RingLevel
var t_go := 0
var t_shown := -1
var t_ring := -1
var t_fight := -1
var _done := false
var _ended_round := 0
## frames_csv=<path>: every frame written there (stretch, frame, ms), for a closer look.
var csv_path := ""
## shots=<dir>: the window saved there at each new line of the loading screen (load_<n>.png; a review run, not a measured one).
var shots_dir := ""
var _shot_line := ""
## diag=1: on a hitch whose frame compiled pipelines at draw time, the meshes added to the tree (or shown) in the frames
## before it.
var diag := false
var _added: Array = []
var _n := 0
var _shots := 0
## Pipelines compiled over the run: canvas, mesh, surface, draw, specialization.
var compiled := [0, 0, 0, 0, 0]
var _clock: Clock


## Where a frame goes (ms): the last frame's process (process_frame to the last _process) and draw (RenderingServer's pre to
## post draw), and this frame's physics steps: their scripts (each physics_frame to the last _physics_process) and the whole
## of them with the physics server's own stepping (the first physics_frame to this process_frame); split() gives the last of
## each and starts anew.
class Clock extends Node:
	var _p0 := 0
	var _p1 := 0
	var _d0 := 0
	var _d1 := 0
	var _f0 := -1
	var _s0 := 0
	var _scripts := 0
	var _steps := 0

	func _ready() -> void:
		process_priority = 1 << 30
		process_physics_priority = 1 << 30
		process_mode = Node.PROCESS_MODE_ALWAYS

	func physics_start() -> void:
		_s0 = Time.get_ticks_usec()
		if _f0 < 0:
			_f0 = _s0
		_steps += 1

	func _physics_process(_dt: float) -> void:
		_scripts += Time.get_ticks_usec() - _s0

	func _process(_dt: float) -> void:
		_p1 = Time.get_ticks_usec()

	func draw_start() -> void:
		_d0 = Time.get_ticks_usec()

	func draw_end() -> void:
		_d1 = Time.get_ticks_usec()

	## [process, draw, physics scripts, physics in all, physics steps]; the process clock started for the frame now beginning.
	func split() -> Array:
		var now := Time.get_ticks_usec()
		var out := [maxf(_p1 - _p0, 0) / 1000.0, maxf(_d1 - _d0, 0) / 1000.0, _scripts / 1000.0,
				(now - _f0) / 1000.0 if _f0 >= 0 else 0.0, _steps]
		_p0 = now
		_f0 = -1
		_scripts = 0
		_steps = 0
		return out


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "light"
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("  (watchdog: stretch %s, phase %s, round %s)" % [stretch, mode.phase if mode else "-", mode.round if mode else -1])
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var v := kv.get_slice("=", 1)
		match kv.get_slice("=", 0):
			"load_ms":
				if v.is_valid_float():
					load_ms = float(v)
			"restart_ms":
				if v.is_valid_float():
					restart_ms = float(v)
			"frames_csv":
				csv_path = v
			"shots":
				shots_dir = v
			"diag":
				diag = v in ["1", "on"]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	MatchSetup.reload_scheme()
	InputSetup.ensure()
	# (the menu's Begin: a best of three, earth against earth unless the args say otherwise; MatchSetup.take() applies them)
	MatchSetup.element = "earth"
	MatchSetup.foes = ["earth"]
	MatchSetup.rounds_to_win = 2
	MatchSetup.games_n = 3                       # (the merge: the % ring plays by default; its best of 3 is three games)
	MatchSetup.round_s = 60.0
	MatchSetup.kind = "match"
	MatchSetup.incoming = true
	_run.call_deferred()


func _end() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	MatchSetup.reload_scheme()
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _run() -> void:
	await process_frame
	t_go = Time.get_ticks_usec()
	LoadingScreen.go(self, LoadingScreen.RING_SCENE)
	if diag:
		node_added.connect(func(nd: Node) -> void:
			if nd is GeometryInstance3D or nd is GPUParticles3D:
				_added.append([_n, nd])
				(nd as Node3D).visibility_changed.connect(func() -> void:
					if is_instance_valid(nd) and (nd as Node3D).is_visible_in_tree():
						_added.append([_n, nd])))
	_clock = Clock.new()
	_clock.name = "HitchClock"
	root.add_child(_clock)
	physics_frame.connect(_clock.physics_start)
	RenderingServer.frame_pre_draw.connect(_clock.draw_start)
	RenderingServer.frame_post_draw.connect(_clock.draw_end)
	var last := Time.get_ticks_usec()
	var n := 0
	var pipes := _pipelines()
	while not _done:
		await process_frame
		var now := Time.get_ticks_usec()
		n += 1
		_n = n
		frames.append([stretch, n, (now - last) / 1000.0])
		var split := _clock.split()
		var p2 := _pipelines()
		var made := PackedInt32Array()
		for i in p2.size():
			made.append(p2[i] - pipes[i])
			compiled[i] += p2[i] - pipes[i]
		pipes = p2
		if now - last > HITCH_US:
			# (where it went: the last frame's process and draw, this frame's physics steps (ms; Clock), and the pipelines
			# compiled meanwhile: canvas, mesh, surface, draw (at draw time: a stall), specialization)
			print("PERF hitch %s #%d %.1f ms (process %.0f draw %.0f physics %.0f of it scripts %.0f x%d; pipelines %s)" % [
					stretch, n, (now - last) / 1000.0, split[0], split[1], split[3], split[2], split[4], made])
			if diag and made[3] > 0:
				for a: Array in _added:
					if int(a[0]) >= n - 3 and is_instance_valid(a[1]):
						print("PERF   new #%d %s" % [a[0], _what(a[1] as Node)])
		if diag:
			_added = _added.filter(func(a: Array) -> bool: return int(a[0]) >= n - 3)
		last = now
		_step(now)
	_report()
	_end()


## The stretch moved on, and the match driven: each round ended after FIGHT_S, each pause skipped after OVER_S.
func _step(now: int) -> void:
	if stretch == "pre":
		t_shown = now                        # (the frame just measured drew the loading screen)
		stretch = "load"
		return
	if mode == null:
		lvl = current_scene as RingLevel
		mode = RingMode.find(self)
		if mode != null:
			mode.phase_changed.connect(_on_phase)
	if shots_dir != "":
		_shoot()
	if t_ring < 0 and mode != null and not LoadingScreen.covering():
		t_ring = now
	if mode == null:
		return
	match mode.phase:
		"FIGHT":
			if t_fight < 0:
				t_fight = now
			if mode.phase_t >= FIGHT_S and _ended_round < mode.round:
				_ended_round = mode.round
				mode._end_round(int(WINNERS[mini(mode.round - 1, WINNERS.size() - 1)]), "territory")
		"OVER":
			if mode.phase_t >= OVER_S:
				mode._skip = true
		"DONE":
			_done = true


## A mesh or emitter as diag prints it: its path, class and its first material's shader (or material class).
func _what(nd: Node) -> String:
	var m: Material = null
	if nd is GeometryInstance3D:
		m = (nd as GeometryInstance3D).material_override
		if m == null and nd is MeshInstance3D and (nd as MeshInstance3D).mesh != null and (nd as MeshInstance3D).mesh.get_surface_count() > 0:
			m = (nd as MeshInstance3D).get_active_material(0)
	if nd is GPUParticles3D and m == null:
		m = (nd as GPUParticles3D).process_material
	var ms := "-"
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		ms = (m as ShaderMaterial).shader.resource_path
		if ms == "":
			ms = "shader:%s" % (m as ShaderMaterial).shader.code.substr(0, 60).replace("\n", " ")
	elif m != null:
		ms = m.get_class()
	return "%s (%s) %s" % [nd.get_path(), nd.get_class(), ms]


## The window saved when the loading screen's line changes (and once as the ring shows).
func _shoot() -> void:
	var scn := current_scene
	var line := String(scn.get_meta(&"loading_step", "")) if scn != null else ""
	if not LoadingScreen.covering():
		line = "(the ring)"
	if line == _shot_line or line == "":
		return
	_shot_line = line
	_shots += 1
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png(shots_dir.path_join("load_%d.png" % _shots))
		print("PERF shot load_%d.png: %s" % [_shots, line])


## The pipelines compiled so far: canvas, mesh, surface, draw, specialization (Performance's monitors).
func _pipelines() -> PackedInt32Array:
	return PackedInt32Array([Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)])


func _on_phase(ph: String) -> void:
	match ph:
		"FIGHT":
			stretch = "fight%d" % mode.round
		"OVER":
			stretch = "restart%d" % (mode.round + 1)
		"DONE":
			stretch = "done"


func _longest(name: String) -> Array:
	var worst := [0.0, -1]
	var count := 0
	for f: Array in frames:
		if f[0] == name:
			count += 1
			if float(f[2]) > float(worst[0]):
				worst = [float(f[2]), int(f[1])]
	return [worst[0], worst[1], count]


func _report() -> void:
	var lw := _longest("load")
	print("PERF display=%s load_screen_ms=%.0f to_ring_ms=%.0f to_fight_ms=%.0f load_longest_ms=%.0f load_frames=%d warm_ms=%.0f" % [
			DisplayServer.get_name(), (t_shown - t_go) / 1000.0, (t_ring - t_go) / 1000.0, (t_fight - t_go) / 1000.0,
			lw[0], lw[2], lvl.warm_ms if lvl != null else -1.0])
	print("PERF pipelines canvas=%d mesh=%d surface=%d draw=%d specialization=%d" % compiled)
	_expect(mode != null and mode.phase == "DONE" and mode.rounds_played == 3, "the match played to its end in three rounds (%s)" % [
			mode.score if mode != null else "-"])
	_expect(t_fight > t_go, "the first fight reached (%.1f s after the Begin)" % ((t_fight - t_go) / 1.0e6))
	print("PERF load_longest_ms=%.0f aim=%.0f %s" % [lw[0], LOAD_AIM_MS, "met" if lw[0] <= LOAD_AIM_MS else "not met"])
	if load_ms > 0.0 and DisplayServer.get_name() != "headless":    # (headless the ring is built at once: RingLevel._build)
		_expect(lw[0] <= load_ms, "the load's longest frame after the loading screen shows: %.0f ms (frame #%d; at most %.0f)" % [
				lw[0], lw[1], load_ms])
	for r in [2, 3]:
		var rw := _longest("restart%d" % r)
		print("PERF restart%d_longest_ms=%.1f frames=%d" % [r, rw[0], rw[2]])
		if restart_ms > 0.0:
			_expect(rw[2] > 0 and rw[0] <= restart_ms, "round %d's restart's longest frame: %.1f ms (frame #%d; at most %.0f)" % [
					r, rw[0], rw[1], restart_ms])
	if csv_path != "":
		var f := FileAccess.open(csv_path, FileAccess.WRITE)
		if f != null:
			for fr: Array in frames:
				f.store_line("%s,%d,%.2f" % [fr[0], fr[1], fr[2]])
	var sorted := frames.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) > float(b[2]))
	for f: Array in sorted.slice(0, 10):
		print("PERF slowest %s #%d %.1f" % [f[0], f[1], f[2]])
