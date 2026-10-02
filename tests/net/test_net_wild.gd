extends SceneTree
## The animals in a session (NetWildlife, phase P5), run as two processes:
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_wild.gd -- net=host survival=on wildlife=on
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_wild.gd -- net=join:127.0.0.1 survival=on wildlife=on
##   mirror   the joiner has no animals of its own; the host's near it are shown, and they move
##   hunt     the joiner's ball into one: the host's animal dies of it, and the joiner sees it fall
## Each prints "NET WILD <role> PASSED (<n> checks)" or "NET WILD <role> FAILED (<f> of <n>)".
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


func _animals(mirrored: bool) -> Array[WildAnimal]:
	var out: Array[WildAnimal] = []
	for n in get_nodes_in_group(&"wildlife"):
		var a := n as WildAnimal
		if a and a.mirrored == mirrored:
			out.append(a)
	return out


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(30)
	net = NetSession.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(net != null and player != null and net.in_session(), "in a session")
	if net == null:
		_end()
		return
	player.ignore_mouse_capture = true
	var sp := get_first_node_in_group(&"wildlife_spawner") as WildlifeSpawner
	_expect(sp != null, "the level has its spawner")
	if role == "host":
		_expect(not sp.mirror, "the host's spawner runs its own animals")
		await _until(func() -> bool: return not net.names.is_empty(), 120.0)
		var killed := await _until(func() -> bool:
			for a in _animals(false):
				if a.is_dead() and a.has_meta(&"net_id"):
					return true
			return false, 60.0)
		_expect(killed, "one of the host's animals was killed by the joiner's shot")
		await _wait(4.0)
	else:
		_expect(sp.mirror, "the joiner's spawner is a mirror")
		await _wait(3.0)
		_expect(_animals(false).is_empty(), "the joiner has no animals of its own")
		# stand by the range herd (at the lane's far end: the host's animals there are near this player)
		var at := WildlifeSpawner.RANGE_HERD_HOME + Vector3(0, 0, 40)
		at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
		player.global_position = at
		var seen := await _until(func() -> bool: return _animals(true).size() >= 1, 30.0)
		_expect(seen, "the host's animals near it are shown here (%d)" % _animals(true).size())
		if not seen:
			_end()
			return
		var a: WildAnimal = _animals(true)[0]
		var p0 := a.global_position
		await _wait(6.0)
		var moved := false
		for b in _animals(true):
			if b.get_meta(&"net_id") == a.get_meta(&"net_id") and b.global_position.distance_to(p0) > 0.05:
				moved = true
		_expect(moved or a._anim != "", "and they live: moving or playing their clips (%s, %s)" % [a.species, a._anim])
		# ---- the hunt: a ball at its chest from 10 m
		var target: WildAnimal = null
		for b in _animals(true):
			if not b.is_dead():
				target = b
				break
		player.global_position = target.global_position + Vector3(0, 0.2, 10)
		await _wait(0.5)
		var ok := false
		for i in 8:
			var from := player.global_position + Vector3(0, 1.4, 0)
			var to := target.global_position + Vector3(0, float(target.data.get("chest_h", 0.9)) * target.size, 0)
			var p := Projectile.new()
			p.kind = Projectile.Kind.BALL
			p.velocity = (to - from).normalized() * 300.0
			p.gravity = 0.0
			p.damage = 400.0
			p.exclude = [player.get_rid()]
			p.shooter = player
			current_scene.add_child(p)
			p.global_position = from
			ok = await _until(func() -> bool: return target.is_dead(), 2.0)
			if ok:
				break
		_expect(ok, "the joiner's shot killed it: its mirror fell here")
		await _wait(4.0)
	_end()


func _end() -> void:
	if fails.is_empty():
		print("NET WILD %s PASSED (%d checks)" % [role, checks])
	else:
		print("NET WILD %s FAILED (%d of %d)" % [role, fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
