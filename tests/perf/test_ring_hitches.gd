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
## falls=1 (improvement round 5, PERF: "stall pairs of ~1.2-3.9 s during a fight and at a restart, music on"): the games are
## decided by real falls instead (a 3-life game: the side WINNERS says loses is launched off the deck by the other, the
## playcheck's way, fall_wait_s of live fight before each launch, the bot fighting meanwhile), with the Splash Cam's replay of
## every fall (RingReplay.force on, as a player's game has it: Every fall), so the KO splash, the slow beat, the stingers,
## the crowd's ripple and the replay's ghosts are all met; the stretches fall<n> (the 3.5 s after a fall, its replay
## excepted) and replay<n> (a replay playing) are measured beside fight<n> and restart<n>, and fight_ms (default 100; 0 only
## reports) limits the longest frame of every fight, fall, replay and restart.
## Each hitch line also says where the rest went (late: after the scripts' process to the draw: tweens, timers, deferred
## calls, deletions; post: after the draw to the next frame's physics: the audio server's update, the window's events) and
## what changed in it (static memory MB, objects, resources and nodes made), and with diag=1 what happened in the frames
## before it (music cues and stingers started, phases, falls, replays; meshes added). frames_csv gets every frame's split.
## In-test watchdog LIMIT_S. Last line "RING HITCHES PASSED" or
## "... FAILED"; exit 0 only on a pass.

const NAME := "RING HITCHES"
const LIMIT_S := 400.0
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
## falls=1: the games decided by real falls (see the header); fall_wait_s of live fight before each launch.
var falls_mode := false
var fall_wait_s := 1.2
var fight_ms := 100.0
var _launching := false
var _ko_usec := -1
var kos := 0
var replays := 0
## What happened, frame by frame (diag): [frame, text].
var _events: Array = []
## The monitors last frame: static memory, objects, resources, nodes.
var _mon := PackedFloat64Array([0, 0, 0, 0])
var _md_started := 0
var _md_stings := 0


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
	## The first physics step of this frame began (or -1); the last draw ended.
	var _post0 := 0
	## The frame's moments in order (diag: a hitch's timeline): [tag, usec]; P a physics step began, p its scripts ended, x the
	## scripts' process ended, D the draw began, d it ended (RenderingServer's frame_post_draw).
	var marks: Array = []

	func _ready() -> void:
		process_priority = 1 << 30
		process_physics_priority = 1 << 30
		process_mode = Node.PROCESS_MODE_ALWAYS

	func physics_start() -> void:
		_s0 = Time.get_ticks_usec()
		marks.append(["P", _s0])
		if _f0 < 0:
			_f0 = _s0
			_post0 = _s0
		_steps += 1

	func _physics_process(_dt: float) -> void:
		var t := Time.get_ticks_usec()
		_scripts += t - _s0
		marks.append(["p", t])
		if fine:
			# (the rest of the physics frame cut up: q the deferred calls flushed, t the physics timers run, f the deletions
			# made; from there to the next P the physics server's own step)
			_q.call_deferred()
			get_tree().create_timer(0.0, true, true).timeout.connect(func() -> void: marks.append(["t", Time.get_ticks_usec()]))
			var doomed := Doomed.new()
			doomed.clock = self
			add_child(doomed)
			doomed.queue_free()

	func _q() -> void:
		marks.append(["q", Time.get_ticks_usec()])

	func _process(_dt: float) -> void:
		_p1 = Time.get_ticks_usec()
		marks.append(["x", _p1])
		if fine:
			_probe()

	## fine: the worker threads' wait, probed: a tiny high-priority task put on WorkerThreadPool each frame; how long it waited
	## for a thread (the pool's busy: the physics server's steps, the pipelines' compiles and the threaded loads all queue there).
	var fine := false
	var _probe_task := -1
	var _probe_at := 0
	var _probe_ran := [0]
	## The longest wait this frame (usec; a probe still waiting counts what it has waited).
	var pool_wait := 0

	func _probe() -> void:
		var now := Time.get_ticks_usec()
		if _probe_task >= 0:
			if not WorkerThreadPool.is_task_completed(_probe_task):
				pool_wait = maxi(pool_wait, now - _probe_at)
				return
			WorkerThreadPool.wait_for_task_completion(_probe_task)
			pool_wait = maxi(pool_wait, int(_probe_ran[0]) - _probe_at)
		var ran := _probe_ran
		_probe_at = now
		_probe_task = WorkerThreadPool.add_task(func() -> void: ran[0] = Time.get_ticks_usec(), true, "hitch probe")

	func _exit_tree() -> void:
		if _probe_task >= 0:
			WorkerThreadPool.wait_for_task_completion(_probe_task)
			_probe_task = -1

	func draw_start() -> void:
		_d0 = Time.get_ticks_usec()
		marks.append(["D", _d0])

	func draw_end() -> void:
		_d1 = Time.get_ticks_usec()
		marks.append(["d", _d1])

	## The marks since the last split as "tag+ms" from `t0` (usec), and cleared.
	func timeline(t0: int) -> String:
		var out := PackedStringArray()
		for m: Array in marks:
			out.append("%s%.0f" % [m[0], (int(m[1]) - t0) / 1000.0])
		marks.clear()
		if fine:
			out.append("pool_wait %.0f" % (pool_wait / 1000.0))
			pool_wait = 0
		return " ".join(out)

	## [process, draw, physics scripts, physics in all, physics steps, late (the scripts' process to the draw: tweens, timers,
	## deferred calls, deletions, the rendering's sync), post (the draw to this frame's physics or process: the audio server's
	## update, the window's events)]; the process clock started for the frame now beginning.
	func split() -> Array:
		var now := Time.get_ticks_usec()
		var post_end := _post0 if _f0 >= 0 else now
		var out := [maxf(_p1 - _p0, 0) / 1000.0, maxf(_d1 - _d0, 0) / 1000.0, _scripts / 1000.0,
				(now - _f0) / 1000.0 if _f0 >= 0 else 0.0, _steps,
				maxf(_d0 - _p1, 0) / 1000.0 if _d0 >= _p1 else 0.0, maxf(post_end - _d1, 0) / 1000.0 if _d1 >= _p1 else 0.0]
		_p0 = now
		_f0 = -1
		_scripts = 0
		_steps = 0
		return out


## A node made and queue_freed each physics step (Clock.fine): its deletion marks when the delete queue was flushed.
class Doomed extends Node:
	var clock: Clock

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and clock != null and is_instance_valid(clock):
			clock.marks.append(["f", Time.get_ticks_usec()])


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
			"falls":
				falls_mode = v in ["1", "on"]
			"fall_wait_s":
				if v.is_valid_float():
					fall_wait_s = float(v)
			"fight_ms":
				if v.is_valid_float():
					fight_ms = float(v)
	if falls_mode:
		RingReplay.force = "on"                  # (a player's game: Every fall; a script run plays none unless asked)
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
	RingReplay.force = ""
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
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_clock = Clock.new()
	_clock.name = "HitchClock"
	_clock.fine = diag
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
		var split := _clock.split()
		var st := _label(now)
		var mon := _monitors()
		var dm := PackedFloat64Array([mon[0] - _mon[0], mon[1] - _mon[1], mon[2] - _mon[2], mon[3] - _mon[3]])
		_mon = mon
		_note_music(n)
		frames.append([st, n, (now - last) / 1000.0, split, dm])
		var tl := _clock.timeline(last)
		var p2 := _pipelines()
		var made := PackedInt32Array()
		for i in p2.size():
			made.append(p2[i] - pipes[i])
			compiled[i] += p2[i] - pipes[i]
		pipes = p2
		if now - last > HITCH_US:
			# (where it went: the last frame's process and draw, this frame's physics steps (ms; Clock), and the pipelines
			# compiled meanwhile: canvas, mesh, surface, draw (at draw time: a stall), specialization)
			print(("PERF hitch %s #%d %.1f ms (process %.0f draw %.0f physics %.0f of it scripts %.0f x%d late %.0f post %.0f; " +
					"pipelines %s; mem %+.1f MB objects %+d resources %+d nodes %+d)") % [
					st, n, (now - last) / 1000.0, split[0], split[1], split[3], split[2], split[4], split[5], split[6], made,
					dm[0] / 1048576.0, int(dm[1]), int(dm[2]), int(dm[3])])
			var vp := root.get_viewport_rid()
			print("PERF   timeline %s x%.0f at %.2f (render cpu %.1f gpu %.1f setup %.1f ms)" % [tl, (now - last) / 1000.0,
					Time.get_unix_time_from_system(),
					RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp),
					RenderingServer.get_frame_setup_time_cpu()])
			if diag:
				for e: Array in _events:
					if int(e[0]) >= n - 3:
						print("PERF   at #%d %s" % [e[0], e[1]])
				var shown := 0
				for a: Array in _added:
					if int(a[0]) >= n - 3 and is_instance_valid(a[1]) and shown < 12:
						shown += 1
						print("PERF   new #%d %s" % [a[0], _what(a[1] as Node)])
		if diag:
			_added = _added.filter(func(a: Array) -> bool: return int(a[0]) >= n - 3)
			_events = _events.filter(func(a: Array) -> bool: return int(a[0]) >= n - 3)
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
			mode.rules.ko.connect(func(b: Node3D, _by: Node, _p: float, _t: String, left: int) -> void:
				kos += 1
				_ko_usec = Time.get_ticks_usec()
				if mode.foe != null and b == mode.foe:
					mode.foe.held = false
				_events.append([_n, "fall of %s (%d left)" % [b.name, left]]))
			var rp := RingReplay.find(self)
			if rp != null:
				rp.started.connect(func(_c: Variant) -> void:
					replays += 1
					_events.append([_n, "replay started"]))
				rp.finished.connect(func(_s: bool) -> void: _events.append([_n, "replay finished"]))
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
			if falls_mode:
				if not _launching and mode.phase_t >= fall_wait_s and not paused and not RingMoment.busy():
					var rp := RingReplay.find(self)
					var loser := _loser()
					if (rp == null or (rp.pending() == 0 and not rp.is_playing())) and loser != null \
							and not mode.rules.is_away(loser) and (_ko_usec < 0 or now - _ko_usec > int(fall_wait_s * 1e6) + 3000000):
						_launch(loser)
				return
			if mode.phase_t >= FIGHT_S and _ended_round < mode.round:
				_ended_round = mode.round
				mode._end_round(int(WINNERS[mini(mode.round - 1, WINNERS.size() - 1)]), "territory")
		"OVER":
			if mode.phase_t >= OVER_S:
				mode._skip = true
		"DONE":
			_done = true


## The stretch a frame falls in: a replay playing (replay<n>), the 3.5 s after a fall (fall<n>), else the phase's.
func _label(now: int) -> String:
	if mode == null or not is_instance_valid(mode):
		return stretch
	if RingReplay.playing_now() != null:
		return "replay%d" % mode.round
	if _ko_usec >= 0 and now - _ko_usec < 3500000 and not stretch.begins_with("restart"):
		return "fall%d" % mode.round
	return stretch


## Static memory (bytes), objects, resources, nodes (Performance's monitors).
func _monitors() -> PackedFloat64Array:
	return PackedFloat64Array([Performance.get_monitor(Performance.MEMORY_STATIC), Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])


## The music cues and stingers MusicDirector started since last frame, as events (diag).
func _note_music(n: int) -> void:
	var md := get_first_node_in_group(MusicDirector.GROUP) as MusicDirector
	if md == null:
		return
	while _md_started < md.started.size():
		_events.append([n, "music cue %s" % md.started[_md_started]])
		_md_started += 1
	while _md_stings < md.ring_stings.size():
		_events.append([n, "music sting %s" % md.ring_stings[_md_stings]])
		_md_stings += 1


## The side WINNERS says loses this game: its competitor (the foe, or the player).
func _loser() -> Node3D:
	var w := int(WINNERS[mini(mode.round - 1, WINNERS.size() - 1)])
	var b: Node3D = mode.foe if w == 0 else mode.player
	return b if b != null and is_instance_valid(b) else null


## A real launch off the deck (the playcheck's way): `b` stood near its end, the other close behind, then knocked over the lip
## into the water by him.
func _launch(b: Node3D) -> void:
	_launching = true
	var other: Node3D = mode.player if b == mode.foe else mode.foe
	var ring := mode.ring as RingArena
	var foe_was := mode.foe.held if mode.foe != null else false
	if mode.foe != null:
		mode.foe.held = true
	var kn := BendKnock.of(b)
	kn.reset()
	if b is CharacterBody3D:
		(b as CharacterBody3D).velocity = Vector3.ZERO
	var end := mode.player_end if b == mode.player else 1 - mode.player_end
	var side := RingArena.side_sign(end) if end in [0, 1] else 1.0
	b.global_position = ring.to_global(Vector3(side * (ring.half_l() - 2.5), ring.top() + 0.05, 0.0))
	other.global_position = ring.to_global(Vector3(side * (ring.half_l() - 7.0), ring.top() + 0.05, 1.0))
	for i in 10:
		await physics_frame
	if mode == null or mode.phase != "FIGHT":
		_launching = false
		return
	mode.rules.reset_pct(b, 120.0)
	var v := ring.global_basis * Vector3(16.0 * side, 7.0, 0.0)
	mode.rules.launched.emit(b, v, 0.8, other, "stone_form/spike")
	kn.knock(Vector3.ZERO, other, {"_launch": {"v": v, "hitstun_s": 0.8, "tumble": true}})
	if mode.foe != null and b != mode.foe:
		mode.foe.held = foe_was
	_events.append([_n, "launch of %s" % b.name])
	# (the flight given its time to end in the water: no other launch meanwhile)
	var k0 := kos
	var t0 := Time.get_ticks_msec()
	while kos == k0 and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	if kos == k0:
		print("PERF launch of %s did not end in the water (round %d)" % [b.name, mode.round])
	_launching = false


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
	_events.append([_n, "phase %s round %d" % [ph, mode.round]])
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
	if falls_mode:
		print("PERF falls=%d replays=%d" % [kos, replays])
		_expect(kos >= 6 and replays >= 6, "falls decided the games, each with its replay (%d falls, %d replays)" % [kos, replays])
	for kind in ["fight", "fall", "replay", "restart"]:
		var worst := [0.0, -1, ""]
		var count := 0
		for f: Array in frames:
			if String(f[0]).begins_with(kind):
				count += 1
				if float(f[2]) > float(worst[0]):
					worst = [float(f[2]), int(f[1]), String(f[0])]
		print("PERF %s_longest_ms=%.1f frames=%d (%s #%d)" % [kind, worst[0], count, worst[2], worst[1]])
		if fight_ms > 0.0 and count > 0 and (falls_mode or kind in ["fight", "restart"]):
			_expect(float(worst[0]) <= fight_ms, "every %s's longest frame: %.1f ms (%s #%d; at most %.0f)" % [kind, worst[0], worst[2],
					worst[1], fight_ms])
	if csv_path != "":
		var f := FileAccess.open(csv_path, FileAccess.WRITE)
		if f != null:
			f.store_line("stretch,frame,ms,process,draw,scripts,physics,steps,late,post,mem_mb,objects,resources,nodes")
			for fr: Array in frames:
				var sp: Array = fr[3]
				var d: PackedFloat64Array = fr[4]
				f.store_line("%s,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%.2f,%.2f,%.2f,%d,%d,%d" % [fr[0], fr[1], fr[2], sp[0], sp[1], sp[2],
						sp[3], sp[4], sp[5], sp[6], d[0] / 1048576.0, int(d[1]), int(d[2]), int(d[3])])
	var sorted := frames.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) > float(b[2]))
	for f: Array in sorted.slice(0, 10):
		print("PERF slowest %s #%d %.1f" % [f[0], f[1], f[2]])
