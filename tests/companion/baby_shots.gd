extends SceneTree
## Look-check of the baby and the hold poses in the level, windowed: the wife holding the baby in the cradle hold, the
## feeding hold and over the shoulder.
##   Godot --path . --resolution 1280x720 -s tests/companion/baby_shots.gd -- out=<abs dir> survival=on
var out := ""
var player: FrontierPlayer
var h: Household


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


var cam: Camera3D


func _view(low := 1.2) -> void:
	var b := h.body
	var f := b.global_basis.z
	var at := b.global_position + Vector3(0, low, 0)
	if cam == null:
		cam = Camera3D.new()
		current_scene.add_child(cam)
	cam.current = true
	cam.global_position = at - f * 1.9 - b.global_basis.x * 0.7 + Vector3(0, 0.25, 0)   # (the body's -Z is the way she faces)
	cam.look_at(at, Vector3.UP)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	await _frames(150)
	h = Household.find(self)
	h.set_role("stay", h.sc)
	var now := h.bridge.core.state.minutes
	var child := Pregnancy.make_child(RandomNumberGenerator.new(), now - 3.0 * 1440.0, {"next_id": 1, "mother": h.sc.name, "father": "player", "kind": "spouse"})
	h.family.append(child)
	await _frames(240)
	print("baby link: ", h.baby != null, " baby node: ", h.baby.baby != null if h.baby else false, " holder: ", h.baby.care.holder_of(h.baby.focus) if h.baby else "-")
	if h.baby == null or h.baby.baby == null:
		print("BABY SHOTS: no baby")
		quit(1)
		return
	for pose in ["cradle", "feed", "shoulder"]:
		h.baby._pose_for["spouse"] = pose
		for i in 90:
			h.baby.errand = {}            # no laying-down errand while the pose is photographed
			await process_frame
		_view()
		await _shot("hold_" + pose)
	# laying down: a cradle in front of her, the real lay errand, photographed on the way and after
	h.baby.errand = {}
	var fwd := -h.body.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var cr := Cradle.new()
	current_scene.add_child(cr)
	cr.global_position = h.body.global_position + fwd * 0.75
	cr.global_basis = Basis(Vector3.UP, atan2(-fwd.x, -fwd.z) + PI * 0.5)
	h.home = h.body.global_position
	h.baby._start_errand([{"do": "lay"}])
	for i in 40:
		await process_frame
	_view()
	await _shot("reach_low")
	for i in 60:
		await process_frame
	_view()
	await _shot("reach_mid")
	for i in 120:
		await process_frame
	_view()
	await _shot("reach_back")
	print("holder now: ", h.baby.care.holder_of(h.baby.focus))
	h.baby._start_errand([{"do": "take"}])
	for i in 200:
		await process_frame
	_view()
	await _shot("take_back")
	cr.queue_free()
	# the errands: sit to feed, kneel to change (frozen a few seconds in)
	h.baby.state()["hunger"] = 0.9
	h.baby.state()["asleep"] = false
	h.baby._start_errand([{"do": "sit", "kind": "sit"}, {"do": "care", "what": "feed", "minutes": 400.0}, {"do": "stand"}])
	for i in 200:
		await process_frame
	_view(0.75)
	await _shot("errand_feed")
	h.baby._stop_errand()
	for i in 90:
		await process_frame
	h.baby._start_errand([{"do": "sit", "kind": "kneel"}, {"do": "care", "what": "change", "minutes": 400.0}, {"do": "stand"}])
	for i in 200:
		await process_frame
	_view(0.75)
	await _shot("errand_change")
	h.baby._stop_errand()
	print("BABY SHOTS DONE ", out)
	quit()
