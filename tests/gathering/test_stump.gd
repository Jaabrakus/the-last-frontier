extends SceneTree
## Stumps out (user 2026-10-01: "we need to be able to remove the tree stump"): a tree felled high leaves a tall stump; the axe at it
## offers "Chop out the stump"; held LMB chops it out: the stump goes, its wood comes (a log from a tall one), and the save keeps
## its height while it stands and keeps it gone once out.
##   Godot --headless --fixed-fps 120 --path . -s tests/gathering/test_stump.gd -- --no-capture
var fails := 0
var player: FrontierPlayer


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 120:
		await physics_frame
	player = current_scene.get_node_or_null("Player")
	player.ignore_mouse_capture = true
	var gt: GatherTools = player.gather
	var h := VegHarvest.find(self)
	# the nearest sturdy tree to the fort's north gate
	var best := -1
	var bd := INF
	for i in (current_scene.get("vegetation").layout as Object).get("tree_pos").size():
		var d := h.describe("tree", "tree", i)
		if d.is_empty() or float(d.radius) < 0.18:
			continue
		var dist: float = (d.pos as Vector3).distance_to(Vector3(0, 0, -30))
		if dist < bd:
			bd = dist
			best = i
	var tree := h.describe("tree", "tree", best)
	var pos: Vector3 = tree.pos
	gt.fell_tree(best, pos + Vector3(2, 0, 0), Vector3.FORWARD, true, pos.y + 1.5)
	await _frames(10)
	var stumps := current_scene.find_children("Stump_*", "StaticBody3D", false, false)
	_c(stumps.size() == 1 and absf(float(stumps[0].get_meta(&"height")) - 1.5) < 0.01, "felled at 1.5 m: a tall stump stands")
	var saved := SaveParts.save_vegetation(current_scene)
	_c(absf(float((saved.stump_h as Dictionary).get(str(best), (saved.stump_h as Dictionary).get(best, 0.0))) - 1.5) < 0.01, "the save keeps the stump's height")
	# the axe at it
	var d := Vector3(pos.x + 2.0, 0, pos.z) - pos
	var at := pos + d.normalized() * (float(tree.radius) + 0.9)
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.yaw = atan2(d.x, d.z)
	player.rotation.y = player.yaw
	player.pitch = -0.3
	Input.action_press(&"tool_axe")
	await _frames(3)
	Input.action_release(&"tool_axe")
	for i in 400:
		await physics_frame
		if gt.phase == GatherTools.Phase.READY:
			break
	await _frames(10)
	_c(String(gt.target.get("type", "")) == "stump" and gt.prompt().begins_with("Chop out the stump"), "the axe at it: %s" % gt.prompt())
	var logs0 := InventoryState.from_player(player).pack_count("log")
	Input.action_press(&"fire")
	var gone := false
	for i in 120 * 60:
		await physics_frame
		if current_scene.find_children("Stump_*", "StaticBody3D", false, false).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).is_empty():
			gone = true
			break
	Input.action_release(&"fire")
	await _frames(10)
	_c(gone, "held LMB chops the stump out")
	_c(InventoryState.from_player(player).pack_count("log") > logs0 or gt.get("_held_log") != null, "a tall stump gives a log")
	_c(h.stump_gone.has(best) and (SaveParts.save_vegetation(current_scene).stump_gone as Array).has(best), "the save keeps it gone")
	print("STUMP TEST ", "FAILED" if fails > 0 else "PASSED")
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _c(ok: bool, what: String) -> void:
	print("  ", "ok  " if ok else "FAIL", " ", what)
	if not ok:
		fails += 1
