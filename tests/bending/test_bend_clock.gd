extends SceneTree
## Round 4 IMPACT: BendStatus.now(), the bend's clock, is GAME time (BendStatus' header: the round-2 soak caught 0 stones at
## ts 4 against 87 at ts 1 while it counted physics frames):
##   ts 1      over 2 s of physics frames it equals the old frame clock (frames / physics_ticks_per_second) to 1e-6 every
##             frame, and advances 1.0 per physics_ticks_per_second frames: no round-3 timer moves
##   ts 4      a 1.0 s BendStatus timer (an anchor) ends after 1.0 s of game time: physics_ticks_per_second / 4 frames (the
##             project's 120 ticks: 30; at 60 ticks it would be 15)
##   paused    while the tree is paused now() does not advance (30 frames)
##   no tree   with no SceneTree (BendStatus.no_tree: as a pure unit test sees it) the frame count, as before
## METRIC clock_ts4_ok, clock_paused_ok. Last line "BEND CLOCK PASSED" or "BEND CLOCK FAILED" (exit 0 only on a pass).
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_bend_clock.gd

const NAME := "BEND CLOCK"
const WATCHDOG_S := 60.0
const OWN_CFG := "user://bend_clock_test.cfg"

var checks := 0
var fails: Array[String] = []
var metrics := {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _frames_s() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


func _run() -> void:
	Engine.time_scale = 1.0
	BendStatus.now()                           # (the clock made)
	for i in 3:
		await physics_frame
	_expect(BendStatus.clock() != null and BendStatus.clock().is_inside_tree() and BendStatus.clock().get_parent() == root,
			"the clock node made on first use under the root")
	# ts 1: the old frame clock's value every frame
	var worst := 0.0
	var t0 := BendStatus.now()
	var tps := Engine.physics_ticks_per_second
	for i in tps * 2:
		await physics_frame
		worst = maxf(worst, absf(BendStatus.now() - _frames_s()))
		if i == tps - 1:
			_expect(absf(BendStatus.now() - t0 - 1.0) < 1e-9, "ts 1: 1.0 s per %d physics frames (%.9f)" % [tps, BendStatus.now() - t0])
	_expect(worst <= 1e-6, "ts 1: equal to the frame clock every frame over %d (worst %.2e)" % [tps * 2, worst])
	# ts 4: a 1.0 s timer ends after 1.0 s of game time (15 frames)
	Engine.time_scale = 4.0
	await physics_frame
	var n := Node3D.new()
	root.add_child(n)
	BendStatus.anchor(n, 1.0)
	var frames := 0
	var g0 := BendStatus.now()
	while BendStatus.until(n, &"bend_anchor") > 0.0 and frames < 200:
		await physics_frame
		frames += 1
	var game := BendStatus.now() - g0
	Engine.time_scale = 1.0
	var want := roundi(Engine.physics_ticks_per_second / 4.0)
	var ts4 := frames == want and absf(game - 1.0) < 1e-6
	_expect(ts4, "ts 4: a 1.0 s BendStatus timer ended after %d frames (want %d at %d ticks), %.4f s of game time"
			% [frames, want, Engine.physics_ticks_per_second, game])
	metrics["clock_ts4_ok"] = ts4
	n.queue_free()
	# paused: no advance
	await physics_frame
	paused = true
	var p0 := BendStatus.now()
	for i in 30:
		await physics_frame
	var p1 := BendStatus.now()
	paused = false
	await physics_frame
	var p2 := BendStatus.now()
	var pz := p1 == p0 and p2 > p1
	_expect(pz, "paused 30 frames: now() held (%.4f -> %.4f), and on again after (%.4f)" % [p0, p1, p2])
	metrics["clock_paused_ok"] = pz
	# no tree: the frame count
	BendStatus.no_tree = true
	var nt := BendStatus.now() == _frames_s()
	BendStatus.no_tree = false
	_expect(nt, "with no SceneTree: the frame count (%.4f)" % _frames_s())
	_end()


func _end() -> void:
	Engine.time_scale = 1.0
	paused = false
	for k: String in ["clock_ts4_ok", "clock_paused_ok"]:
		print("METRIC %s=%s" % [k, str(bool(metrics.get(k, false))).to_lower()])
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)
