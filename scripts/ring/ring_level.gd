class_name RingLevel
extends Node3D
## The Tidebreak level (scenes/ring.tscn; the owner, 2026-10-04: the elemental ring sport "Tidebreak", 1v1 first, its team
## structure kept for 3v3; "switch to a elemental avatar the last airbender type of game"): a light scene, NOT the world.
## It builds only what a match needs (the lines of frontier_level.gd that matter here, nothing else):
##   EnvironmentRig   the sky, sun, fog and post (named "EnvironmentRig"), its clock held near noon (ring.json clock_hour)
##                    in clear weather
##   RingArena        the deck over its tank, the ropes, the grates, the stones in their sockets, the stands (RingArena)
##   the player       a FrontierPlayer with no demo horse or wheelbarrow, `arena` set BEFORE it enters the tree (the
##                    contract: player.gd's own arena switch, no guns or throwables, when it has one; a no-op until then),
##                    on spawn(0) (the demo's musket rack and spear barrel taken away: no guns in the arena game); no
##                    fall hurts here (fall_safe_m held high every physics frame, rules.json fall_safe_m: the tank is
##                    the fall, and a launch's landing never hurts)
##   the bending      SwayCaster.install_free, Bending.of(player) (its water meter: the grates are its pools)
##   sound            Sfx, the player's Footsteps (the deck's stone and wood); MusicDirector outside script runs (the
##                    match's own fight cue is RingMode's)
##   settings         GameSettings.apply_to(player) outside script runs (the mouse, the field of view, the volumes)
## WorldRiver.off is set while it stands (no river, and nothing that would read FrontierTerrain's baked data: its 19 MB
## never loads here) and put back as it leaves; FrontierTerrain.open_ground is false (the fort's flat zone is 0 under the
## ring at the origin, so any height_at asked here is 0 without the data).
## The match: MatchSetup.take() at the start (the menu's Begin, or the user arg mode=ring); when a match is asked for (or
## the scene is opened outside a script run) RingMode is installed (its RingRules and RingMenu with it) and the HUD set for
## the arena (FrontierHUD.set_arena, when it has it). A script run without mode=ring (tests/ring/test_ring.gd, the stills)
## gets the bare ring.
## The look (looks B and C, wired after wave 3): RingDressing (the stands, crowd, gates, scoreboard, braziers) and RingLook
## (the light: MatchSetup.light, "noon" by default, "golden" or "night") built at the load; the dressing's banners, flags,
## plaques and friezes in the two ends' elements each round, its scoreboard on the score, its crowd roaring on a knock-back
## and a ring-out. BendLooks.warm_up compiles every element effect behind the loading screen (the level's meta
## loading_hold, LoadingScreen waits on it), logged as "RING warm_ms=<ms> longest_frame_ms=<ms>".
## install_mode(node): the match (RingMode) put under the level. first_frame_ms: the time of the first frame (logged
## as "RING first_frame_ms=<ms>").
## THE LOAD (improvement round 1, PERF: "the first ring load takes 20-35 s with a window that looks frozen"): behind the
## loading screen in a window (LoadingScreen.covering() at _ready: the menu's Begin, the pause menu's restart) it is built a
## part a frame (_build: the sky, the deck, the dressing, its light, the player, his sound and bending, the match), drawn
## meanwhile through a camera where his will stand (_build_cam: each part's shaders compiled on its own frame, not all on
## his first), each part's files read beforehand on worker threads (PREFETCH) and his animation graph parsed on one
## (_graph_task); the loading screen's bar follows (metas loading_progress, loading_step: LOAD_STEPS). Measured windowed on
## the M4 at the game's medium quality (tests/perf/test_ring_hitches.gd): the longest frame after the loading screen shows
## 2.1-2.2 s -> 0.55-0.6 s with the shader cache warm (7.5 s -> 2.9 s on a first launch), its rest the player's own build
## (FrontierPlayer._ready, in one piece); the first fight 7.5 s -> 6.3-6.6 s after Begin (14.7 s -> 13.4 s first launch).
## Without a loading screen (a script's own change of scene, the editor's F6) or headless it is built at once in _ready, as
## before.

const DATA_PATH := RingArena.DATA_PATH
## The files each part of the build loads (data/ring/prefetch.json "phases", recorded by tools/perf/ring_prefetch_list.py):
## the stepped build asks for them all on worker threads at its start (_prefetch) and waits for a part's own before it
## builds it (_fetched), so its frame does not read them (the player's body, garments and clips were most of his).
const PREFETCH := "res://data/ring/prefetch.json"

var settings: WorldSettings
var environment_rig: EnvironmentRig
var ring: RingArena
var player: FrontierPlayer
var music: Node
var mode: Node
var dressing: RingDressing
var look: RingLook
## The loading screen's line under its bar for each part of the build (_step; meta loading_step).
const LOAD_STEPS := {
	"sky": "Clearing the sky",
	"deck": "Raising the deck",
	"stands": "Filling the stands",
	"light": "Lighting the braziers",
	"competitors": "Calling the competitors",
	"crowd": "Hushing the crowd",
	"match": "Chalking the score",
	"elements": "Waking the elements",
}
## ms since the engine started when the first frame came (-1 until then).
var first_frame_ms := -1.0
## The element effects' warm-up: its length and its longest frame (ms; -1 until done).
var warm_ms := -1.0
var warm_frame_ms := -1.0
## The camera the stepped build is drawn through until the player's own stands (_build: without one nothing of the ring is
## drawn before the player, and every shader of the ring was compiled on his first frame, seconds long).
var _build_cam: Camera3D
## The Soft character look's shaders compiled during the stepped build (SoftLook.warm_up through _build_cam).
var _soft_warmed := false
## The prefetch's paths by the part that loads them, and those asked for on the worker threads (held until the build is up).
var _phases := {}
var _fetching: PackedStringArray = []
## The player's animation graph read on a worker thread meanwhile (AnimGraphData keeps the tables it parsed: its 7 MB graph
## was ~0.1 s of his frame); -1 none.
var _graph_task := -1


func _ready() -> void:
	StartupProfile.mark("boot")
	set_meta(&"loading_hold", true)           # (LoadingScreen waits for the effects' warm-up: _warm_looks)
	_step(0.0, "sky")
	_build(LoadingScreen.covering() and DisplayServer.get_name() != "headless")


## The level built in the order the header gives: when `steps` (a loading screen covers the window), a part a frame (the
## sky, the deck, the dressing, the player once his rig has loaded on its worker thread, his sound and bending, the match),
## each part's shaders compiled on the frame it is first drawn, so the loading screen's painting keeps moving between them;
## else all at once in this call (a script's own change of scene, the editor's F6: the tests read the level a frame later;
## and headless, where nothing is drawn and a test's fixed-step frames would race the rig's load on its worker thread).
func _build(steps: bool) -> void:
	var asked := MatchSetup.take()            # (the user args first: the light is the dressing's)
	process_physics_priority = -10            # (before the player: its fall is judged with the safe drop already raised)
	WorldRiver.off = true
	FrontierTerrain.open_ground = false
	BackgroundLoad.request(FrontierPlayer.CHARACTER_SCENE)
	if steps:
		_prefetch()
		_graph_task = WorkerThreadPool.add_task(func() -> void: AnimGraphData.load_files(), false, "ring: animation graph")
		await _fetched("environment")
		if not is_inside_tree():
			return                            # (the scene changed while it loaded)
	settings = WorldSettings.from_args()
	environment_rig = EnvironmentRig.new()
	environment_rig.name = "EnvironmentRig"
	add_child(environment_rig)
	environment_rig.build(settings)
	_hold_the_sky()
	StartupProfile.mark("environment")
	if steps:
		_build_cam = Camera3D.new()
		_build_cam.name = "BuildCamera"
		add_child(_build_cam)
		_build_cam.look_at_from_position(Vector3(0.0, 6.0, 24.0), Vector3.ZERO)
		_build_cam.make_current()
		await _step(0.15, "deck")
		await _fetched("structures")
		if not is_inside_tree():
			return
	ring = RingArena.make(self)
	StartupProfile.mark("structures")
	if _build_cam != null:
		# (where the player's camera will stand: behind him at his spawn, over his shoulder, toward the middle)
		var xf := ring.spawn(0)
		var fwd := -xf.basis.z
		_build_cam.look_at_from_position(xf.origin - fwd * 3.5 + Vector3.UP * 1.9, xf.origin + fwd * 10.0 + Vector3.UP * 1.2)
	if steps:
		await _step(0.3, "stands")
		await _fetched("dressing")
		if not is_inside_tree():
			return
	await _dress(steps)
	if not is_inside_tree():
		return
	StartupProfile.mark("dressing")
	if steps:
		await _step(0.45, "competitors")
		# (the Soft character look's shaders, SoftLook: each compiled on a frame of its own through the build camera before the
		# fighters are dressed, not all on the player's frame)
		await SoftLook.warm_up(_build_cam)
		_soft_warmed = true
		await _loaded(FrontierPlayer.CHARACTER_SCENE)
		await _fetched("player")
		while _graph_task >= 0 and not WorkerThreadPool.is_task_completed(_graph_task) and is_inside_tree():
			await get_tree().process_frame
		if _graph_task >= 0:                  # (_exit_tree waits on it itself when the level left meanwhile)
			WorkerThreadPool.wait_for_task_completion(_graph_task)
			_graph_task = -1
		if not is_inside_tree():
			return
	player = FrontierPlayer.new()
	player.name = "Player"
	player.demo_horse = false
	player.demo_wheelbarrow = false
	player.set(&"arena", true)                # (the contract with player.gd: before _ready builds the weapons)
	add_child(player)
	place(player, ring.spawn(0))
	_no_demo_props.call_deferred()
	if _build_cam != null:
		_build_cam.free()                     # (his camera the window's again)
		if player.camera != null and player.camera.is_inside_tree():
			player.camera.make_current()
	StartupProfile.mark("player")
	if steps:
		await _step(0.6, "crowd")
		await _fetched("audio")
		if not is_inside_tree():
			return
	environment_rig.track(player)
	_audio(player)
	StartupProfile.mark("audio")
	SwayCaster.install_free(player)
	Bending.of(player)
	if not SaveGame._is_script_run():
		GameSettings.apply_to(player)
	if steps:
		await _step(0.7, "match")
		await _fetched("first_frame")
		if not is_inside_tree():
			return
	if asked or not SaveGame._is_script_run():
		_follow(RingMode.install(self, player, ring))
	_release_fetched.call_deferred()
	StartupProfile.watch(self)
	_first_frame.call_deferred()
	_warm_looks.call_deferred()


## The build's progress for the loading screen (meta loading_progress 0..1, loading_step a LOAD_STEPS key), then (a coroutine
## the build awaits) one frame drawn.
func _step(progress: float, what: String) -> void:
	set_meta(&"loading_progress", progress)
	set_meta(&"loading_step", String(LOAD_STEPS.get(what, "")))
	if is_inside_tree() and progress > 0.0:
		await get_tree().process_frame


## The prefetch list's paths asked for on the worker threads (not in a headless run, nor with the user arg ring_prefetch=0;
## a path gone or in the cache already is skipped).
func _prefetch() -> void:
	if DisplayServer.get_name() == "headless" or "ring_prefetch=0" in OS.get_cmdline_user_args() \
			or not FileAccess.file_exists(PREFETCH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFETCH))
	_phases = (d as Dictionary).get("phases", {}) if d is Dictionary else {}
	for ph: String in _phases:
		for p: String in _phases[ph]:
			if not ResourceLoader.has_cached(p) and ResourceLoader.exists(p) and ResourceLoader.load_threaded_request(p) == OK:
				_fetching.append(p)


## Frames drawn until the part `phase`'s prefetched files are loaded (at once when there are none).
func _fetched(phase: String) -> void:
	for p: String in _phases.get(phase, []):
		if p in _fetching:
			await _loaded(p)


## The prefetch's own hold on what it loaded let go (the level holds its own by now; called once the build is up).
func _release_fetched() -> void:
	for p in _fetching:
		if ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(p)
	_fetching.clear()


## Frames drawn until `path`'s load on its worker thread (BackgroundLoad.request) is through (at once when it was never asked
## for or is in the cache already: BackgroundLoad.take then gets it without a wait).
func _loaded(path: String) -> void:
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and is_inside_tree():
		await get_tree().process_frame


func _exit_tree() -> void:
	WorldRiver.off = false
	if _graph_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_graph_task)
		_graph_task = -1
	_release_fetched()                       # (a build left half way: the prefetch's hold let go)


func _physics_process(_dt: float) -> void:
	if player != null and is_instance_valid(player):
		player.fall_safe_m = RingRules.num("fall_safe_m", 100.0)


## `body` (the player, or anyone with a yaw) stood at `xf`: on the deck, facing as it faces, still.
static func place(body: Node3D, xf: Transform3D) -> void:
	body.global_position = xf.origin + Vector3.UP * 0.1
	var rm := RingMoves.of(body)
	if rm != null:
		rm.placed()                               # (round 3, the % ring: a deliberate placing clears its moves at once)
	var f := -xf.basis.z
	var yaw := atan2(-f.x, -f.z)
	if body is FrontierPlayer:
		var p := body as FrontierPlayer
		p.velocity = Vector3.ZERO
		p.yaw = yaw
		p.rotation.y = yaw
		p.pitch = 0.0
	else:
		body.rotation.y = yaw
		if body is CharacterBody3D:
			(body as CharacterBody3D).velocity = Vector3.ZERO


## The match (RingMode) under the level; the one before it, if any, taken away.
func install_mode(node: Node) -> void:
	if mode != null and is_instance_valid(mode) and mode != node:
		mode.queue_free()
	mode = node
	if node.get_parent() == null:
		add_child(node)


## Noon, clear (ring.json clock_hour): the clock stopped there (DayNight, when drawn; headless has no clock).
func _hold_the_sky() -> void:
	if environment_rig == null or environment_rig.clock_driver == null:
		return
	var clock: WorldClock = environment_rig.clock_driver.clock
	if clock != null:
		clock.running = false
		clock.set_time(RingArena.num("clock_hour", 12.25))
	if environment_rig.clock_driver.has_method(&"force_weather"):
		environment_rig.clock_driver.force_weather("clear")


## The arena dressed (RingDressing) in the setup's light (RingLook, after a frame when `steps`), the two sides' elements on it
## until a match says which end is whose.
func _dress(steps := false) -> void:
	dressing = RingDressing.build(self, MatchSetup.light)
	if dressing != null:
		var f := MatchSetup.foe()
		dressing.set_sides(MatchSetup.element, f if f in Bending.ELEMENTS else "fire")
	if steps:
		await _step(0.38, "light")
		if not is_inside_tree():
			return
	look = RingLook.apply(self, MatchSetup.light)


## The dressing follows match `m`: each round the ends' elements and the score (side 0 the ring's end 0, the end the
## player's side holds swapping each round), the crowd roaring on a knock-back and more on a ring-out (the classic rules).
## Under the stock rules (round 4 SHOW) the stands follow the % match's moments instead (RingDressing.react: seen and
## heard): a launch of crowd.json launch_mps or more an ooh, every fall the ripple from its end (RingRules' own record of the
## fall says which end: the only thing about where anyone is the stands are told), a side's last life starting half of
## them up, sudden death half up clapping on the score's beat, all sat down again at the next countdown.
func _follow(m: RingMode) -> void:
	if m == null or dressing == null:
		return
	var sudden_seen := [false]
	m.phase_changed.connect(func(ph: String) -> void:
		if ph == "COUNTDOWN" or ph == "DONE":
			_show_match(m)
		if ph == "COUNTDOWN" and is_instance_valid(dressing):
			sudden_seen[0] = false
			dressing.react("calm"))
	m.round_over.connect(func(_r: String, _why: String) -> void: _show_match(m))
	m.knocked_back.connect(func(_w: Node3D, _a: int, _b: int) -> void: cheer(0.75, 1.6))
	m.rang_out.connect(func(_w: Node3D, _by: Node) -> void:
		if not m.stock():
			cheer(1.0, 3.5))
	if not m.new_ring() or m.rules == null:
		return
	var rules := m.rules
	rules.launched.connect(func(_b: Node3D, v: Vector3, _hs: float, _by: Node, _tag: String) -> void:
		var mps := RingCrowd.react_num("launch_mps", 12.0)
		if v.length() >= mps and is_instance_valid(dressing):
			dressing.react("launch", -1, clampf(v.length() / (2.0 * mps), 0.5, 1.0)))
	rules.ko.connect(func(_b: Node3D, _by: Node, _pct: float, _tag: String, _left: int) -> void:
		if is_instance_valid(dressing):
			dressing.react("fall", fall_end(rules), 1.0))
	rules.respawned.connect(func(b: Node3D) -> void:
		if rules.lives_on and rules.stocks_of(b) == 1 and not rules.sudden and is_instance_valid(dressing):
			dressing.react("last_life", -1, 1.0))
	rules.pct_changed.connect(func(_b: Node3D, _p: float, _d: float) -> void:
		if rules.sudden and not sudden_seen[0] and is_instance_valid(dressing):
			sudden_seen[0] = true
			dressing.react("sudden", -1, 1.0))


## The end of the deck the last fall happened at (0 the -X end, 1 the +X end): RingRules' record of it (falls[-1].pos).
func fall_end(rules: RingRules) -> int:
	if rules == null or rules.falls.is_empty() or ring == null:
		return 0
	var at: Variant = (rules.falls[-1] as Dictionary).get("pos")
	return 0 if not (at is Vector3) or ring.to_local(at).x < 0.0 else 1


func _show_match(m: RingMode) -> void:
	if dressing == null or not is_instance_valid(m):
		return
	var mine_at_0 := m.player_end == 0
	dressing.set_sides(m.element if mine_at_0 else m.foe_element, m.foe_element if mine_at_0 else m.element)
	dressing.set_score(m.score.x if mine_at_0 else m.score.y, m.score.y if mine_at_0 else m.score.x)


## The crowd at `v` (0..1) for `hold_s`, then back to the mood's own murmur.
func cheer(v: float, hold_s: float) -> void:
	if dressing == null:
		return
	dressing.set_cheer(v)
	get_tree().create_timer(hold_s, false).timeout.connect(func() -> void:
		if is_instance_valid(dressing):
			dressing.set_cheer(float((RingDressing.MOODS.get(dressing.mood, {}) as Dictionary).get("cheer", 0.25))))


## Every element effect compiled once while the loading screen still covers the ring (BendLooks.warm_up; without it the
## first fire wall or tornado froze a frame for seconds), timed; then the loading screen may go.
func _warm_looks() -> void:
	await get_tree().process_frame
	_step(0.8, "elements")
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null and BendLooks.live():
		var t0 := Time.get_ticks_usec()
		var last := t0
		var longest := 0
		var done := [false]
		var run := func() -> void:
			# (the Soft character look's shaders, SoftLook, when the build had no camera of its own: each drawn once here)
			if not _soft_warmed:
				var t_soft := Time.get_ticks_usec()
				await SoftLook.warm_up(cam)
				WebPerf.note("warm soft look: %.0f ms" % ((Time.get_ticks_usec() - t_soft) / 1000.0))
			await BendLooks.warm_up(cam, func(f: float) -> void: set_meta(&"loading_progress", 0.8 + 0.2 * f))
			# Draw the large fall effects only behind the loading screen. Direct scene launches
			# must not cover the live competitors in a warm-up splash.
			if ring.water != null and LoadingScreen.covering():
				ring.water.ko_splash(player.global_position, 20.0, 2.0, true)
				await get_tree().create_timer(3.3).timeout
			done[0] = true
		run.call()
		while not done[0]:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			longest = maxi(longest, now - last)
			last = now
		warm_ms = (Time.get_ticks_usec() - t0) / 1000.0
		warm_frame_ms = longest / 1000.0
		print("RING warm_ms=%.0f longest_frame_ms=%.0f" % [warm_ms, warm_frame_ms])
		WebPerf.note("warm total %.0f ms, longest frame %.0f ms" % [warm_ms, warm_frame_ms])
	set_meta(&"loading_progress", 1.0)
	set_meta(&"loading_hold", false)


## Sound (scripts/audio/): the buses and voices, the player's footsteps, the music outside script runs (or with music=on).
func _audio(p: FrontierPlayer) -> void:
	Sfx.setup(self)
	if not SaveGame._is_script_run() or "music=on" in OS.get_cmdline_user_args():
		var md := MusicDirector.new()
		md.name = "MusicDirector"
		md.player = p
		add_child(md)
		music = md
	var steps := Footsteps.new()
	steps.name = "Footsteps"
	steps.player = p
	p.add_child(steps)
	if BendLooks.live():
		BendSounds.warm()                    # (the ring's own sounds held from here, none read from disk mid-fight: ~0.1 s in
		                                     # this frame; not in PREFETCH: read on the workers they slowed his frame ~0.6 s)


## No guns in the arena game (the owner, 2026-10-04): the demo's musket rack and spear barrel the player's interactor sets
## beside a spawn (PlayerInteractor._ensure_demo_props, deferred from the player's _ready, so this comes after it) taken
## away with what stands in them.
func _no_demo_props() -> void:
	for n: Node in get_children():
		if (n is WeaponRack and String(n.name).begins_with("Demo")) or n is PlacedWeapon:
			n.queue_free()


func _first_frame() -> void:
	await get_tree().process_frame
	first_frame_ms = Time.get_ticks_usec() / 1000.0
	print("RING first_frame_ms=%.0f" % first_frame_ms)
