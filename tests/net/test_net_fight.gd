extends SceneTree
## Shots between two machines (NetSession, phase P2), run as two processes:
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_fight.gd -- net=host squad=1
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_fight.gd -- net=join:127.0.0.1 squad=2
##   hit      the host's ball at the joiner's player: the joiner's machine takes it (health down), and sees a ghost of it
##   squad    with the joiner taken into the host's squad, the same shot does nothing (co-op)
##   kill     balls high in the body kill; the host sees the joiner's player fall, and stand again at its respawn
## Each prints "NET FIGHT <role> PASSED (<n> checks)" or "NET FIGHT <role> FAILED (<f> of <n>)".
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
	role = "host" if "net=host" in OS.get_cmdline_user_args() else "join"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _wait(s: float) -> void:
	await _until(func() -> bool: return false, s)


func _remote() -> FrontierPlayer:
	for id: int in net.remotes:
		return net.remotes[id]
	return null


## The host's ball at the remote player, `h` m over its feet (1.25 the chest, 1.62 the head).
func _shoot(r: FrontierPlayer, h: float) -> void:
	var from := player.global_position + Vector3(0, 1.4, 0)
	var at := r.global_position + Vector3(0, h, 0)
	var p := Projectile.new()
	p.kind = Projectile.Kind.BALL
	p.velocity = (at - from).normalized() * 300.0
	p.gravity = 0.0
	p.damage = 60.0
	p.exclude = [player.get_rid()]
	p.shooter = player
	current_scene.add_child(p)
	p.global_position = from
	NetSession.shot(player, p, false)


func _ghosts() -> int:
	var n := 0
	for c in current_scene.get_children():
		if c is Projectile and (c as Projectile).ghost:
			n += 1
	return n


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(30)
	net = NetSession.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(net != null and player != null and net.in_session(), "in a session (%s), squad %d" % [net.status if net else "", net.squad if net else 0])
	if net == null:
		_end()
		return
	player.ignore_mouse_capture = true
	var got := await _until(func() -> bool: return _remote() != null and not net.squads.is_empty(), 120.0)
	_expect(got, "the other player is here, squad %s" % str(net.squads.values()))
	if not got:
		_end()
		return
	var r := _remote()
	var mine := Vector3(10.0, 0.0, -40.0 if role == "host" else -55.0)     # (beside the range lane's dummies)
	mine.y = FrontierTerrain.height_at(mine.x, mine.z) + 0.1
	player.global_position = mine
	player.velocity = Vector3.ZERO
	player.yaw = 0.0 if role == "host" else PI
	var there := await _until(func() -> bool: return absf(r.global_position.z - (-55.0 if role == "host" else -40.0)) < 0.6, 15.0)
	_expect(there, "each stands on its spot on the other's screen")
	await _wait(2.0)
	if role == "host":
		# ---- hit (other squads)
		_expect(int(net.squads.values()[0]) != net.squad, "the joiner is another squad")
		_shoot(r, 1.25)
		await _wait(5.0)
		# ---- squad: the same shot at a squadmate
		var id: int = net.remotes.keys()[0]
		net.squads[id] = net.squad
		_shoot(r, 1.25)
		await _wait(5.0)
		net.squads[id] = net.squad + 1
		# ---- kill
		var fell := false
		for i in 10:                                 # (shots high in the body until it falls: the head, the neck)
			_shoot(r, 1.5)
			fell = await _until(func() -> bool: return r.is_dead, 1.5)
			if fell:
				break
		_expect(fell, "the joiner's player fell on the host's screen")
		var stood := await _until(func() -> bool: return not r.is_dead, 15.0)
		_expect(stood, "and stood again when it respawned")
		await _wait(2.0)
	else:
		var h0 := player.health
		var hit := await _until(func() -> bool: return net.hits_taken >= 1, 10.0)
		_expect(hit and player.health < h0, "the host's ball landed here: %d hit, health %.0f -> %.0f" % [net.hits_taken, h0, player.health])
		_expect(_ghosts() >= 1 or hit, "and its ghost flew here")
		var before := net.hits_taken
		await _wait(5.0)
		_expect(net.hits_taken == before, "taken into the host's squad, the second shot did nothing (co-op)")
		var died := await _until(func() -> bool: return player.is_dead, 10.0)
		_expect(died, "the head shot killed (%s)" % net.status)
		_expect(net.status.begins_with("Killed by") or net.status.contains("killed"), "and said who did it: %s" % net.status)
		await _wait(2.0)
		player.respawn()
		await _wait(6.0)
	_end()


func _end() -> void:
	if fails.is_empty():
		print("NET FIGHT %s PASSED (%d checks)" % [role, checks])
	else:
		print("NET FIGHT %s FAILED (%d of %d)" % [role, fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
