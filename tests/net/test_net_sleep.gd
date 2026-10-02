extends SceneTree
## Sleep in a session (NetSession's clock, phase P4), run as two processes with the survival rules:
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_sleep.gd -- net=host survival=on
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_sleep.gd -- net=join:127.0.0.1 survival=on
##   alone    the host sleeps while the joiner is awake: its night passes for it, but the world's clock does not skip
##   all      both sleep: the world's clock skips on
## Each prints "NET SLEEP <role> PASSED (<n> checks)" or "NET SLEEP <role> FAILED (<f> of <n>)".
var checks := 0
var fails: Array[String] = []
var role := ""
var net: NetSession
var b: SurvivalBridge


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + "[%s] %s" % [role, what])
	if not ok:
		fails.append(what)


func _initialize() -> void:
	role = "host" if "net=host" in OS.get_cmdline_user_args() else "join"
	_run.call_deferred()


func _until(cond: Callable, s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _wait(s: float) -> void:
	await _until(func() -> bool: return false, s)


func _peer_sleeping() -> bool:
	for id: int in net._target:
		if bool((net._target[id] as Dictionary).get("s", false)):
			return true
	return false


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 30:
		await physics_frame
	net = NetSession.find(self)
	b = SurvivalBridge.find(self)
	var player := current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	_expect(net.in_session() and b != null, "in a session with the survival rules")
	await _until(func() -> bool: return not net.names.is_empty() and not net._target.is_empty(), 120.0)
	await _wait(3.0)
	if role == "host":
		# ---- alone
		var m0 := b.core.state.minutes
		var t0 := Time.get_ticks_msec()
		_expect(b.sleeper.start(), "the host lies down to sleep")
		await _until(func() -> bool: return not b.sleeper.sleeping, 40.0)
		await _wait(1.0)
		var real_min := float(Time.get_ticks_msec() - t0) / 1000.0 * SurvivalClock.game_minutes_per_real_second(b.core)
		_expect(b.core.state.minutes - m0 < real_min + 30.0, "asleep alone, it woke to the world's hour: %.0f game min on (the real time's %.0f)" % [b.core.state.minutes - m0, real_min])
		# ---- all: the joiner lies down when the host's first sleep is over
		var both := await _until(func() -> bool: return _peer_sleeping(), 40.0)
		_expect(both, "the joiner is asleep")
		var m1 := b.core.state.minutes
		var t1 := Time.get_ticks_msec()
		b.sleeper.start()
		await _until(func() -> bool: return not b.sleeper.sleeping, 40.0)
		await _wait(1.0)
		# (by day a sleep is a nap, and only the time both lay asleep skips: more than the real time gives, by a margin)
		var real1 := float(Time.get_ticks_msec() - t1) / 1000.0 * SurvivalClock.game_minutes_per_real_second(b.core)
		_expect(b.core.state.minutes - m1 > real1 + 15.0, "with everyone asleep the world's clock skipped on (%.0f game min; real time %.0f)" % [b.core.state.minutes - m1, real1])
		await _wait(4.0)
	else:
		# awake through the host's sleep alone
		var seen := await _until(func() -> bool: return _peer_sleeping(), 30.0)
		_expect(seen, "the host is asleep")
		var m0 := b.core.state.minutes
		await _until(func() -> bool: return not _peer_sleeping(), 40.0)
		await _wait(3.0)
		_expect(b.core.state.minutes - m0 < 60.0, "awake here, the clock did not skip with the host's sleep (%.0f game min)" % (b.core.state.minutes - m0))
		# now this one sleeps (and stays asleep a while: the host lies down too)
		_expect(b.sleeper.start(), "the joiner lies down")
		await _until(func() -> bool: return not b.sleeper.sleeping, 40.0)
		await _wait(8.0)
	_end()


func _end() -> void:
	if fails.is_empty():
		print("NET SLEEP %s PASSED (%d checks)" % [role, checks])
	else:
		print("NET SLEEP %s FAILED (%d of %d)" % [role, fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
