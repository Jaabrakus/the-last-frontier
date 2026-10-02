extends SceneTree
## One world for two machines (NetSession, phase P3), run as two processes with the survival rules:
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_world.gd -- net=host survival=on
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_world.gd -- net=join:127.0.0.1 survival=on
##   snapshot  what the host did before the join (a tree felled, a lean-to built) is in the joiner's world when it comes
##   live      the host fells a tree, builds a campfire, takes the lean-to down: the joiner's world follows; the joiner
##             fells one: the host's follows
##   clock     the joiner's time is the host's
## Each prints "NET WORLD <role> PASSED (<n> checks)" or "NET WORLD <role> FAILED (<f> of <n>)".
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


## Standing trees far from the fort, by index: the n-th of them (the same on both machines: one layout).
func _tree(n: int) -> int:
	var h := VegHarvest.find(self)
	var k := 0
	for i in h.lay.tree_pos.size():
		var p: Vector3 = h.lay.tree_pos[i]
		if Vector2(p.x, p.z).length() > 120.0 and Vector2(p.x, p.z).length() < 200.0 and h.describe("tree", "tree", i).size() > 0:
			if k == n:
				return i
			k += 1
	return -1


func _felled(i: int) -> bool:
	return VegHarvest.find(self).felled.has(i)


func _pieces(type: String) -> int:
	var w := BuildWorld.of(self, false)
	var n := 0
	if w:
		for p in w.pieces():
			if p.type == type:
				n += 1
	return n


func _fell(i: int) -> void:
	var h := VegHarvest.find(self)
	var at: Vector3 = h.lay.tree_pos[i]
	player.gather.fell_tree(i, at + Vector3(2, 0, 0), Vector3.FORWARD, false)


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
	var t0 := _tree(0)
	var t1 := _tree(1)
	var t2 := _tree(2)
	_expect(t0 >= 0 and t1 >= 0 and t2 >= 0, "three standing trees out in the woods (%d, %d, %d)" % [t0, t1, t2])
	var spot := Vector3(40.0, 0.0, 40.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	var w := BuildWorld.of(self, true)
	if role == "host":
		# ---- before anyone comes: a tree down and a lean-to up
		_fell(t0)
		w.add_piece("lean_to", Transform3D(Basis(), spot), true, -1)
		var lean_key := NetSession.piece_key(_find("lean_to"))
		_expect(_felled(t0) and _pieces("lean_to") >= 1, "the host felled a tree and built a lean-to (%s) before the join" % lean_key)
		var came := await _until(func() -> bool: return not net.names.is_empty(), 120.0)
		_expect(came, "the joiner came")
		# (the joiner takes the world and tells it has it)
		await _wait(8.0)
		# ---- live
		_fell(t1)
		w.add_piece("campfire", Transform3D(Basis(), spot + Vector3(5, 0, 0)), true, -1)
		await _wait(1.0)
		var lt := _find("lean_to")
		if lt:
			w.remove_piece(lt)
		var theirs := await _until(func() -> bool: return _felled(t2), 20.0)
		_expect(theirs, "the joiner's felling came down here too")
		var hb := SurvivalBridge.find(self)
		hb.core.state.minutes += 600.0                   # (ten hours on: the joiner's clock goes with it)
		await _wait(8.0)
	else:
		var ready := await _until(func() -> bool: return net.world_ready, 60.0)
		_expect(ready, "the host's world came in")
		_expect(_felled(t0), "the tree the host felled before the join is down here")
		_expect(_pieces("lean_to") >= 1, "and its lean-to stands here")
		var b := SurvivalBridge.find(self)
		var host_m := 0.0
		# ---- live
		var fell := await _until(func() -> bool: return _felled(t1), 20.0)
		_expect(fell, "the host's live felling came down here")
		var fire := await _until(func() -> bool: return _pieces("campfire") >= 1, 10.0)
		_expect(fire, "its campfire was built here")
		var gone := await _until(func() -> bool: return _pieces("lean_to") == 0, 10.0)
		_expect(gone, "and the lean-to it took down is gone here")
		_fell(t2)
		# ---- clock: the host's sends every 2 s; it jumps ten hours on
		host_m = b.core.state.minutes
		var jumped := await _until(func() -> bool: return b.core.state.minutes > host_m + 500.0, 12.0)
		_expect(jumped, "the joiner's clock went with the host's ten hours (%.0f -> %.0f)" % [host_m, b.core.state.minutes])
	_end()


func _find(type: String) -> BuiltPiece:
	var w := BuildWorld.of(self, false)
	if w:
		for p in w.pieces():
			if p.type == type:
				return p
	return null


func _end() -> void:
	if fails.is_empty():
		print("NET WORLD %s PASSED (%d checks)" % [role, checks])
	else:
		print("NET WORLD %s FAILED (%d of %d)" % [role, fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
