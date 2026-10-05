extends SceneTree
## HowTo on the real level (scripts/ui/how_to.gd): off under a script unless asked; Getting around comes up on its own,
## its steps tick off as their keys are pressed and it goes once all are done; build mode brings up Building, which goes
## when build mode ends and never comes up again; the seen topics are kept (a test file, not the player's).
##
##   Godot --headless --fixed-fps 120 --path . -s tests/ui/test_how_to.gd [-- shots=<dir>]
## shots=<dir> (not headless): a picture of the panel up (basics.png, with W held; build.png).

const TEST_CFG := "user://how_to_test.cfg"

var failures := PackedStringArray()
var checks := 0
var player: FrontierPlayer
var how: HowTo
var shots := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shots = a.get_slice("=", 1)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") if current_scene else null
	_check(player != null, "level loads with a player")
	if player:
		player.ignore_mouse_capture = true
		how = player.get_node_or_null("HowTo") as HowTo
		_check(how != null, "the player has HowTo")
		if how:
			await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	if failures.is_empty():
		print("HOW TO TEST PASSED (%d checks)" % checks)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("HOW TO TEST FAILED (%d of %d checks)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	checks += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, secs: float) -> bool:
	for i in int(secs * 120.0):
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _tap(action: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(3)


func _shot(name: String) -> void:
	if shots == "":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shots)
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _run() -> void:
	_check(not how.enabled, "under a test script it is off unless howto=on")
	how.cfg_path = TEST_CFG
	how.reset()
	how.enabled = true
	_check(await _until(func() -> bool: return how.current == "basics", 4.0), "Getting around comes up on its own (%s)" % how.current)
	await _frames(60)
	_check(how._panel.visible and how._panel.modulate.a > 0.9, "its panel is up")
	_check(how._steps.size() == 6 and not how._steps.any(func(st: Dictionary) -> bool: return st.done), "six steps, none done")
	await _tap(&"move_forward")
	await _frames(2)
	if shots != "":
		Input.action_press(&"sprint")
		await _frames(2)
		await _shot("basics")
		Input.action_release(&"sprint")
	_check(not how._steps[0].done, "W alone does not finish Move (A, S, D still to press)")
	for a: StringName in [&"move_left", &"move_back", &"move_right"]:
		await _tap(a)
	await _frames(2)
	_check(how._steps[0].done and not how._steps[1].done, "W A S D: Move is done, Sprint is next")
	for a: StringName in [&"sprint", &"jump", &"crouch", &"crouch", &"interact"]:
		await _tap(a)
	await _frames(2)
	_check(not how._steps[5].done, "the wheel's step waits for Q")
	await _tap(&"equip_wheel")
	_check(await _until(func() -> bool: return how.current != "basics", HowTo.DONE_S + HowTo.FADE_S + 1.0),
			"every step done: the panel goes (%s)" % how.current)
	_check(how.seen.has("basics"), "Getting around is seen")
	# build mode: Building comes up, and goes when build mode ends
	await _until(func() -> bool: return how.current == "", 6.0)
	player.building.set_active(true)
	_check(await _until(func() -> bool: return how.current == "build", 2.0), "build mode brings up Building (%s)" % how.current)
	await _frames(60)
	await _shot("build")
	player.building.set_active(false)
	_check(await _until(func() -> bool: return how.current == "", HowTo.GONE_S + HowTo.FADE_S + 1.0),
			"out of build mode the panel goes (%s; build mode %s, gone %.1f s, t %.1f)" % [how.current, player.building.active, how._gone_t, how._t])
	player.building.set_active(true)
	await _frames(120)
	_check(how.current != "build", "a second time Building does not come up")
	player.building.set_active(false)
	var c := ConfigFile.new()
	_check(c.load(TEST_CFG) == OK and c.has_section_key("seen", "basics") and c.has_section_key("seen", "build"),
			"the seen topics are kept in the file")
	_ring_topics()


## The ring's first-time panels, one per control scheme (round 2 of the skills, skills_r2 spec §2, §6): each holds the
## guard on E ("on the beat it's yours"), the hold-and-let-go and the floor and air rule; every [key] in them a cap the
## panel knows (CAP_ACTIONS); the moves topic of each scheme ("simple" read as first moves).
func _ring_topics() -> void:
	var missing: Array = []
	var bad_caps: Array = []
	for s: String in ["keys", "first_moves", "direction", "radial"]:
		var id := String(HowTo.SCHEME_TOPICS.get(s, ""))
		if id == "" or not HowTo.TOPICS.has(id) or not id in HowTo.ARENA_TOPICS:
			missing.append(s)
			continue
		var all := "\n".join(PackedStringArray(HowTo.TOPICS[id].steps))
		if not (all.contains("[E]  Guard: on the beat it's yours") and all.contains("let go") and all.contains("Fire along the floor? [Space]  Jump")):
			missing.append(id)
		for mt in RegEx.create_from_string("\\[([^\\]]+)\\]").search_all(all):
			if not HowTo.CAP_ACTIONS.has(mt.get_string(1)):
				bad_caps.append(mt.get_string(1))
	_check(missing.is_empty() and bad_caps.is_empty(), "a first-time panel per scheme with the guard, the hold and the floor rule (%s; caps %s)"
			% [missing, bad_caps])
	_check(String(HowTo.SCHEME_TOPICS.get(KitWords.scheme_id("simple"), "")) == "elements_first_moves"
			and (HowTo.CAP_ACTIONS["E"] as Array).has(&"bend_guard"), "the old simple scheme reads as first moves; [E] lights for the guard")
