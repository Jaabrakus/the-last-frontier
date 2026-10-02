extends SceneTree
## Two machines in one session (NetSession, phase P1), run as two processes on this machine:
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_pair.gd -- net=host
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_pair.gd -- net=join:127.0.0.1
##   join     the joiner reaches the host; each has one remote player, named and dressed by the other
##   follow   each puts its own player at a spot; the other machine's remote player gets there
##   move     the host's player runs (its move keys held): the joiner's remote holds the same keys and moves
##   leave    the joiner leaves: the host's remote player goes
## Each prints "NET PAIR <role> PASSED (<n> checks)" or "NET PAIR <role> FAILED (<f> of <n>)".
var checks := 0
var fails: Array[String] = []
var role := ""
var net: NetSession
var player: FrontierPlayer


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + "[%s] %s" % [role, what])
	if not ok:
		fails.append(what)


func _initialize() -> void:
	role = "host" if "net=host" in OS.get_cmdline_user_args() or "--net=host" in OS.get_cmdline_user_args() else "join"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _remote() -> FrontierPlayer:
	for id: int in net.remotes:
		return net.remotes[id]
	return null


## Waits up to `s` seconds for `cond`.
func _until(cond: Callable, s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)      # (real seconds: a headless run's frames go faster)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(30)
	net = NetSession.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(net != null and player != null, "the level has the session and the player")
	if net == null:
		_end()
		return
	player.ignore_mouse_capture = true
	_expect(net.in_session(), "the session is open (%s)" % net.status)
	var got := await _until(func() -> bool: return _remote() != null and not net.names.is_empty(), 120.0)
	_expect(got and net.remotes.size() == 1, "the other machine's player is here, named %s" % str(net.names.values()))
	if not got:
		_end()
		return
	var r := _remote()
	_expect(not r.is_local and not r.controls.from_input and r.camera != null and not r.camera.current, "it is a remote player: not this keyboard's, not the view")
	_expect(r.get_node_or_null("NameTag") is Label3D, "with a name over its head")
	# ---- follow: each puts its player on its own spot
	# (in the range lane north of the gate: open ground ahead, the player faces -Z)
	var mine := Vector3(6.0 if role == "host" else -6.0, 0.0, -40.0)
	var theirs := Vector3(-mine.x, 0.0, -40.0)
	mine.y = FrontierTerrain.height_at(mine.x, mine.z) + 0.1
	player.global_position = mine
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	var there := await _until(func() -> bool: return Vector2(r.global_position.x, r.global_position.z).distance_to(Vector2(theirs.x, theirs.z)) < 1.0, 10.0)
	_expect(there, "the remote player came to the other's spot (%s, wanted %s)" % [str(r.global_position), str(theirs)])
	await _frames(60)
	# ---- move: the host runs forward for two seconds
	if role == "host":
		player.controls = PlayerControls.new(false)
		player.controls.set_held(&"move_forward", true)
		await _frames(120)
		player.controls.set_held(&"move_forward", false)
		_expect(player.global_position.distance_to(mine) > 1.5, "the host ran (%.1f m)" % player.global_position.distance_to(mine))
		await _frames(180)
	else:
		var start := r.global_position
		var held := await _until(func() -> bool: return r.controls.pressed(&"move_forward"), 6.0)
		_expect(held, "the joiner's remote host holds the forward key the host holds")
		var moved := await _until(func() -> bool: return r.global_position.distance_to(start) > 1.5, 6.0)
		_expect(moved, "and runs with it (%.1f m)" % r.global_position.distance_to(start))
		var let_go := await _until(func() -> bool: return not r.controls.pressed(&"move_forward"), 6.0)
		_expect(let_go, "and lets go when the host does")
	# ---- leave
	if role == "join":
		await _frames(30)
		net.leave()
		_expect(not net.in_session() and net.remotes.is_empty(), "the joiner left: no session, no remote player")
	else:
		var gone := await _until(func() -> bool: return net.remotes.is_empty(), 15.0)
		_expect(gone, "the joiner left: its player is gone from the host")
	_end()


func _end() -> void:
	if fails.is_empty():
		print("NET PAIR %s PASSED (%d checks)" % [role, checks])
	else:
		print("NET PAIR %s FAILED (%d of %d)" % [role, fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
