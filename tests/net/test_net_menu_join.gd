extends SceneTree
## Joining from the main menu (NetSession.join_from_menu, phase P6): connect first, the host's world comes, the game
## loads into it. Run as two processes:
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_menu_join.gd -- net=host survival=on
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_net_menu_join.gd -- role=join survival=on
##   host     starts its level hosting, fells a tree and builds a lean-to, waits for the joiner
##   join     starts with no level (as the menu), joins: the level loads, the host's world is in it (the tree, the lean-to)
##   pause    the joiner's game does not stop under a menu while others are in it
## Each prints "NET MENU <role> PASSED (<n> checks)" or "NET MENU <role> FAILED (<f> of <n>)".
var checks := 0
var fails: Array[String] = []
var role := ""


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
		await process_frame
	return bool(cond.call())


func _tree_far() -> int:
	var h := VegHarvest.find(self)
	for i in h.lay.tree_pos.size():
		var p: Vector3 = h.lay.tree_pos[i]
		if Vector2(p.x, p.z).length() > 150.0 and h.describe("tree", "tree", i).size() > 0:
			return i
	return -1


func _run() -> void:
	if role == "host":
		change_scene_to_file("res://scenes/main.tscn")
		await _until(func() -> bool: return NetSession.find(self) != null and current_scene.get_node_or_null("Player") != null, 60.0)
		for i in 30:
			await process_frame
		var net := NetSession.find(self)
		var p := current_scene.get_node("Player") as FrontierPlayer
		var t := _tree_far()
		p.gather.fell_tree(t, VegHarvest.find(self).lay.tree_pos[t] + Vector3(2, 0, 0), Vector3.FORWARD, false)
		var spot := Vector3(-40, 0, 40)
		spot.y = FrontierTerrain.height_at(spot.x, spot.z)
		BuildWorld.of(self, true).add_piece("lean_to", Transform3D(Basis(), spot), true, -1)
		_expect(net.in_session(), "hosting; tree %d felled and a lean-to built" % t)
		var came := await _until(func() -> bool: return not net.names.is_empty(), 120.0)
		_expect(came, "the joiner came")
		await _until(func() -> bool: return false, 25.0)
	else:
		# (no level: as at the main menu)
		var net := NetSession.join_from_menu(self, "127.0.0.1", 1)
		var loaded := await _until(func() -> bool: return net.world_ready, 120.0)
		_expect(loaded, "joined from the menu: the level loaded and the host's world came in")
		if loaded:
			var t := _tree_far()
			var h := VegHarvest.find(self)
			var any_felled := not h.felled.is_empty()
			_expect(any_felled, "the host's felled tree is down here (%s)" % str(h.felled.keys()))
			var leans := 0
			for pc in BuildWorld.of(self, false).pieces():
				if pc.type == "lean_to":
					leans += 1
			_expect(leans == 1, "the host's lean-to stands here")
			_expect(net.player != null and net.player.is_inside_tree(), "this machine's player is in it")
			paused = true
			await _until(func() -> bool: return false, 0.5)
			_expect(not paused, "a menu does not stop the shared world")
			_expect(t >= 0, "")
		await _until(func() -> bool: return false, 3.0)
	_end()


func _end() -> void:
	if fails.is_empty():
		print("NET MENU %s PASSED (%d checks)" % [role, checks])
	else:
		print("NET MENU %s FAILED (%d of %d)" % [role, fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
