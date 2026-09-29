extends SceneTree
## Teaching in the level, windowed (survival on): a child of the household with the wife keeping house. The teach job is planned by
## the wife (she walks to the hearth with the child following, and gives the lesson standing, turned to it), then a 'field' lesson (she
## goes out foraging with the child along and the lesson is given when the job finishes with the child near). Game time is pushed on by hand.
##   Godot --path . --resolution 1280x720 -s tests/companion/growth_work.gd -- out=<abs dir> survival=on fort_plan=on
var out := ""
var player: FrontierPlayer
var h: Household
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _look(at: Vector3, from: Vector3) -> void:
	if cam == null:
		cam = Camera3D.new()
		current_scene.add_child(cam)
	cam.current = true
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	await _frames(150)
	h = Household.find(self)
	var sc := h.sc
	var core := h.bridge.core
	var now := core.state.minutes
	var mk := func(id: int, learnt: Array) -> Dictionary:
		var c := Pregnancy.make_child(RandomNumberGenerator.new(), now - 200.0 * 1440.0, {"next_id": id, "mother": sc.name, "father": "player", "kind": "spouse"})
		Growth.normalize(c, now)
		Growth.to_stage(c, "child", now)
		for t: String in learnt:
			c.topics[t] = 1
		return c
	h.stock.put("johnnycake", 12)
	print(h.set_role("home"))
	var g := h.growth
	var step := 0.05   # game minutes a frame: slow enough for her walk to the woods to fit in the day (a frame is 1/60 s of walking)
	# A: the hearth lesson (the teach job): fire, the field topics already learnt
	var kid: Dictionary = mk.call(1, ["foraging", "firewood"])
	h.family.append(kid)
	var only_b := OS.get_cmdline_user_args().has("b_only")
	var shot_lesson := false
	var taught_home := false
	for i in (0 if only_b else 3000):
		await process_frame
		core.advance(step)
		var body := g.child_node(kid)
		if i % 300 == 0:
			print("A frame ", i, " hour ", "%.1f" % (fposmod(core.state.minutes, 1440.0) / 60.0), " task ", sc.task, " role ", sc.role, " lessons ", kid.lessons, " topics ", kid.topics.keys())
		if sc.task == "teach" and h.body._phase == "lesson" and not shot_lesson and body != null:
			shot_lesson = true
			print("lesson begins at frame ", i, ": ", sc.task_text, ", child ", "%.1f" % body.global_position.distance_to(h.body.global_position), " m away")
			await _frames(30)
			var mid := (h.body.global_position + body.global_position) * 0.5
			_look(mid + Vector3(0, 0.8, 0), mid + Vector3(2.4, 1.3, 2.4))
			await _shot("lesson_home")
		if Teaching.learned(kid, "fire"):
			taught_home = true
			print("fire taught at frame ", i, ": lessons ", kid.lessons, ", journal ", sc.journal.slice(-1))
			break
	# B: a field lesson: foraging, with the hearth topics already learnt
	h.family.erase(kid)
	var kid2: Dictionary = mk.call(2, ["fire", "cooking", "shelter"])
	h.family.append(kid2)
	print("B: ", Teaching.due(kid2, sc.core, core.state.minutes, "field"))
	var taught_field := false
	var shot_field := false
	var teleported := false
	for i in 7000:
		await process_frame
		core.advance(step)
		var body2 := g.child_node(kid2)
		if i % 500 == 0:
			print("B frame ", i, " hour ", "%.1f" % (fposmod(core.state.minutes, 1440.0) / 60.0), " task ", sc.task, " role ", sc.role, " pending ", g.pending_field.size(), " topics ", kid2.topics.keys(),
					" | her plan ", h.body._plan.get("task", "-"), " goal ", h.body._goal.distance_to(h.body.global_position), " m off, stuck ", "%.1f" % h.body._stuck_t, " cool ", "%.0f" % sc._cool, " focus ", sc.focus, " left ", "%.1f" % sc.minutes_left, " run ", sc._run.get("job", sc._run.get("id", "")), " lesson ", (sc._run.get("lesson", {}) as Dictionary).get("topic", "-"), " from home ", "%.0f" % h.body.global_position.distance_to(h.home))
		if not teleported and h.body._plan.get("task", "") == "forage" and i > 400:
			# (her walk to a random woods spot is the body's own and can end against a tree: bring her the last of the way)
			teleported = true
			var goal: Vector3 = h.body._goal
			goal.y = FrontierTerrain.height_at(goal.x, goal.z) + 0.3
			h.body.global_position = goal
			print("she is brought to her spot ", "%.0f" % goal.distance_to(h.home), " m from home")
		if g.pending_field.size() > 0 and sc.busy() and not shot_field and body2 != null:
			shot_field = true
			var p: Dictionary = g.pending_field.values()[0]
			print("field lesson at work: ", p.topic, " job ", sc.task, ", child ", "%.1f" % body2.global_position.distance_to(h.body.global_position), " m from her, ", "%.0f" % h.body.global_position.distance_to(h.home), " m from home")
			await _frames(30)
			var mid2 := (h.body.global_position + body2.global_position) * 0.5
			_look(mid2 + Vector3(0, 0.6, 0), mid2 + Vector3(3.0, 1.6, 3.0))
			await _shot("lesson_field")
		if Teaching.learned(kid2, "foraging"):
			taught_field = true
			print("foraging taught at frame ", i, ": lessons ", kid2.lessons, ", watched ", kid2.watched, ", journal ", sc.journal.slice(-2))
			break
	print("child 2: topics ", kid2.topics, ", watch minutes ", kid2.watch, ", watch credits ", kid2.watched, ", its survival skill ", g.core_of(kid2).state.skills.get("survival", 0.0))
	print("GROWTH WORK ", "ok" if taught_home and taught_field else "INCOMPLETE", " ", out)
	quit()
