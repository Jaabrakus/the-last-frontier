extends SceneTree
## Workers felling trees by command (RtsFell, RtsOrders; user 2026-09-30: "npcs ... cutting trees"), headless, in the level:
##
##   Godot --headless --fixed-fps 120 --path . -s tests/rts/test_rts_fell.gd -- survival=on fort_plan=on
##
##   pick     the ground under a tree is a tree to fell (RtsOrders.pick); empty ground is only a place
##   one      a worker told to fell a tree walks to it, takes the axe in hand and swings; the tree comes down (a FelledTree and a
##            stump, the trunk gone from VegHarvest) and she is done and puts the axe away
##   group    three told to fell the one tree take three trees (not one twice) round it; each comes down
##   stop     X stops one that is felling (the axe away, no more strokes)
## Ends with "RTS FELL TEST PASSED (<n> checks)" or "... FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var h: Household
var rts: RtsMode
var veg: VegHarvest


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _trees_near(at: Vector3, r: float, min_r := 0.18, max_r := 0.5) -> Array:
	var out: Array = []
	for d: Dictionary in veg.near(at, r):
		if String(d.type) == "tree" and float(d.radius) >= min_r and float(d.radius) <= max_r:
			out.append(d)
	return out


func _run() -> void:
	await _fr(20)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	for i in 600:
		await physics_frame
		h = Household.find(self)
		if h != null and h.body != null:
			break
	rts = p.rts
	veg = VegHarvest.find(self)
	_expect(h != null and rts != null and veg != null and p.gather != null, "the level has the household, the command mode and the trees")
	if veg == null or h == null:
		quit(1)
		return
	h.add_worker()
	h.add_worker()
	await _fr(60)
	var us := rts.units()
	# (the fort's yard is cleared: the workers stand by a stand of trees, as far as one reaches in a few seconds)
	var stand: Array = []
	for d: Dictionary in veg.near(us[0].global_position, 160.0):
		if String(d.type) == "tree" and float(d.radius) >= 0.18 and float(d.radius) <= 0.5 and veg.near(d.pos, 10.0).size() >= 8:
			stand = _trees_near(d.pos, 10.0)
			break
	_expect(stand.size() >= 5, "a stand of trees was found (%d)" % stand.size())
	if stand.size() < 5:
		quit(1)
		return
	var c0: Vector3 = (stand[0] as Dictionary).pos
	for k in us.size():
		var at := c0 + Vector3(5.0 + k, 0.0, 3.0)
		at.y = FrontierTerrain.height_at(at.x, at.z)
		us[k].global_position = at
		us[k].velocity = Vector3.ZERO
	await _fr(30)
	rts.set_active(true)
	rts.focus = c0
	await _fr(5)
	# pick
	var trees := _trees_near(us[0].global_position, 14.0)
	_expect(trees.size() >= 4, "there are trees near the workers (%d)" % trees.size())
	if trees.size() < 4:
		quit(1)
		return
	var t0: Dictionary = trees[0]
	var sp := rts.cam.unproject_position(t0.pos + Vector3.UP * 0.1)
	var got := RtsOrders.pick(rts, sp)
	print("   pick at a tree: ", got.get("kind", ""), " tree ", got.get("tree", {}).get("i", -1), " wanted ", t0.i)
	_expect(String(got.get("kind", "")) in ["tree", "ground"], "a click is read (%s)" % got.get("kind", ""))
	# one worker, one tree
	rts.select([us[0]])
	var n := RtsOrders.fell(rts, t0)
	_expect(n == 1 and us[0].rts_task.is_valid(), "the worker has the task")
	var gear := WorkerGear.of(us[0])
	var saw_axe := false
	var saw_chop := false
	var down := false
	for k in 70 * 120:
		await physics_frame
		var task := us[0].get_meta(&"rts_fell", null) as RtsFell
		if task != null and task.state == "chop":
			saw_chop = true
			saw_axe = saw_axe or (gear != null and gear.in_hand == "axe")
		if veg.felled.has(int(t0.i)):
			down = true
			break
	_expect(saw_chop, "she walked to the tree and began to chop")
	_expect(saw_axe, "with the felling axe in her hand")
	_expect(down, "the tree came down (VegHarvest has it felled)")
	var ft_n := get_nodes_in_group(FelledTree.GROUP).size()
	_expect(ft_n >= 1, "a felled tree lies where it fell (%d)" % ft_n)
	await _fr(60)
	_expect(not us[0].rts_task.is_valid() and (gear == null or gear.in_hand != "axe"), "done: the task ends and the axe is put away")
	# a group
	var ts := _trees_near(c0, 22.0)
	ts = ts.filter(func(d: Dictionary) -> bool: return not veg.felled.has(int(d.i)))
	var base: Dictionary = ts[0]
	for k in us.size():
		# (the others walked home when they had nothing to do: back to the trees)
		var at := (base.pos as Vector3) + Vector3(3.0 + k, 0.0, 2.0)
		at.y = FrontierTerrain.height_at(at.x, at.z)
		us[k].global_position = at
		us[k].velocity = Vector3.ZERO
	await _fr(30)
	rts.select(us)
	var m := RtsOrders.fell(rts, base)
	var picked := {}
	for w in us:
		var tk := w.get_meta(&"rts_fell", null) as RtsFell
		if tk != null:
			picked[tk.tree_index()] = true
	_expect(m == us.size() and picked.size() == us.size(), "%d told to fell: %d trees taken, none twice" % [m, picked.size()])
	var downs := 0
	for k in 90 * 120:
		await physics_frame
		downs = 0
		for i in picked:
			if veg.felled.has(int(i)):
				downs += 1
		if downs == picked.size():
			break
	for w in us:
		var tk := w.get_meta(&"rts_fell", null) as RtsFell
		print("   worker: task %s state %s tree %s dist-to-stand %.1f strokes %s need %.1f" % [w.rts_task.is_valid(),
				tk.state if tk else "-", tk.tree_index() if tk else -1,
				Vector2(w.global_position.x - tk._stand.x, w.global_position.z - tk._stand.z).length() if tk and tk._stand != Vector3.INF else -1.0,
				RtsFell.shared.get(tk.tree_index(), 0.0) if tk else 0.0, tk._need if tk else 0.0])
	for i in picked:
		if not veg.felled.has(int(i)):
			var d := veg.describe("tree", "tree", int(i))
			var wg := WalkGrid.of(self)
			for w in us:
				var way := wg.plan(w.global_position, d.pos, 0.3, w.abilities) if wg else PackedVector3Array()
				print("   unfelled tree %d at %s r %.2f: worker at %s, plan %d points, dist %.1f" % [int(i), d.pos, float(d.radius), w.global_position, way.size(), (w.global_position - d.pos).length()])
	_expect(downs == picked.size(), "all %d came down" % picked.size())
	# stop
	var more := _trees_near(us[0].global_position, 25.0).filter(func(d: Dictionary) -> bool: return not veg.felled.has(int(d.i)))
	if more.is_empty():
		print("   (no tree left within 25 m for the stop check)")
		print("RTS FELL TEST FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)
		return
	rts.select([us[0]])
	RtsOrders.fell(rts, more[0])
	await _fr(2 * 120)
	rts.stop()
	_expect(not us[0].rts_task.is_valid() and (gear == null or gear.in_hand != "axe"), "X stops her felling; the axe away")
	if fails.is_empty():
		print("RTS FELL TEST PASSED (%d checks)" % checks)
	else:
		print("RTS FELL TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
