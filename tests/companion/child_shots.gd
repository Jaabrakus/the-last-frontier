extends SceneTree
## Look-check of the children in the level, windowed: a toddler, a child and a teen (a junior worker, the same scaled rig with the head
## bigger) standing beside the mother, from the front and the side; then the toddler and child walking after a parent, and the height ratios.
##   Godot --path . --resolution 1280x720 -s tests/companion/child_shots.gd -- out=<abs dir> survival=on fort_plan=on
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


func _view(at: Vector3, from: Vector3) -> void:
	if cam == null:
		cam = Camera3D.new()
		current_scene.add_child(cam)
	cam.current = true
	cam.fov = 45.0
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


## The height of a body's head bone above its feet (metres), the ratio to the mother's.
func _head_height(sk: Skeleton3D, model_scale: float) -> float:
	var i := sk.find_bone("heada")
	return sk.get_bone_global_pose(i).origin.y * model_scale if i >= 0 else 0.0


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
	var g := h.growth
	var now := h.bridge.core.state.minutes
	var mk := func(id: int, stage: String, core := false) -> Dictionary:
		var c := Pregnancy.make_child(RandomNumberGenerator.new(), now - 300.0 * 1440.0, {"next_id": id, "mother": h.sc.name, "father": "player", "kind": "spouse"})
		Growth.normalize(c, now)
		Growth.to_stage(c, stage, now)
		c["mode"] = "stay"
		if core:
			for t: Dictionary in Teaching.topics():
				if bool(t.core):
					c.topics[String(t.id)] = 1
		return c
	var kids := [mk.call(1, "toddler"), mk.call(2, "child"), mk.call(3, "teen", true)]
	for c in kids:
		h.family.append(c)
	for wk: SpouseCore in h.workers():
		if wk.worker_id > 0:
			h.set_role("stay", wk)   # the junior worker stands for the photograph
	await _frames(400)
	var mother := h.body
	var mp := mother.global_position
	# a clear direction (nothing solid within 9 m at chest height): the family stands out along it, the camera looks back
	var fwd := Vector3.FORWARD
	var space := mother.get_world_3d().direct_space_state
	for k in 24:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(k) / 24.0)
		var q := PhysicsRayQueryParameters3D.create(mp + Vector3(0, 1.0, 0), mp + Vector3(0, 1.0, 0) + d * 9.0, 1, [mother.get_rid()])
		var q2 := PhysicsRayQueryParameters3D.create(mp + Vector3(0, 0.3, 0) + d * 3.0, mp + Vector3(0, 0.3, 0) + d * 9.0, 1, [mother.get_rid()])
		if space.intersect_ray(q).is_empty() and space.intersect_ray(q2).is_empty():
			fwd = d
			break
	var right := fwd.cross(Vector3.UP).normalized()
	print("clear direction ", fwd)
	print("bodies: ", g.bodies.keys(), " workers: ", h.workers().size())
	# line them up beside her, facing the camera
	var nodes: Array[Node3D] = []
	for c in kids:
		var n := g.child_node(c)
		if n == null:
			print("no body for ", c.name, " stage ", c.stage, " worker ", c.worker_id)
			continue
		nodes.append(n)
	for i in nodes.size():
		var p := mp + fwd * 2.0 + right * (0.75 * float(i) - 0.4)
		p.y = FrontierTerrain.height_at(p.x, p.z) + 0.05
		nodes[i].global_position = p
		nodes[i].velocity = Vector3.ZERO
		nodes[i].look_at(nodes[i].global_position - fwd, Vector3.UP)
		if nodes[i] is ChildBody:
			(nodes[i] as ChildBody)._face = nodes[i].rotation.y
			(nodes[i] as ChildBody)._mood = "idle"
			(nodes[i] as ChildBody)._mood_t = 9999.0
	await _frames(30)
	var mh := _head_height(mother.sk, 1.0)
	for c in kids:
		var n := g.child_node(c)
		if n is ChildBody:
			print(c.stage, " head height ", "%.2f" % _head_height((n as ChildBody).sk, (n as ChildBody).scale_now()), " of the mother's ", "%.2f" % mh)
		elif n is Spouse:
			print(c.stage, " (junior worker) model scale ", "%.2f" % (n as Spouse)._model.scale.x, " head ", "%.2f" % (Growth.num(c, "head", 1.0)))
	# the mother steps beside them
	mother.global_position = mp + fwd * 2.0 + right * (-1.3)
	await _frames(20)
	var mid := mp + fwd * 2.0 + right * 0.35
	print("mother ", mother.global_position, " mid ", mid, " cam-from ", mid + fwd * 4.6)
	for n in nodes:
		print("  node ", n.name, " at ", n.global_position, " clip ", (n as ChildBody)._clip if n is ChildBody else (n as Spouse)._clip)
	_view(mid + Vector3(0, 0.85, 0), mid + fwd * 4.6 + Vector3(0, 1.0, 0))
	await _shot("family_front")
	_view(mid + Vector3(0, 0.85, 0), mid + right * 4.6 + Vector3(0, 0.9, 0.0))
	await _shot("family_side")
	_view(mp + fwd * 2.0 + right * -0.4 + Vector3(0, 0.5, 0), mp + fwd * 2.0 + right * -0.4 + fwd * 1.9 + Vector3(0.3, 0.8, 0))
	await _shot("toddler_close")
	# close-ups of each child, front and side, for the body shape: flat and asexual until the teen, clothed (the others stepped away)
	for n in nodes:
		n.global_position += right * 0.0
	mother.global_position += right * -8.0
	for i in kids.size():
		var n := g.child_node(kids[i])
		if n == null:
			continue
		var h_m := 1.7 * (n.scale.x if n is ChildBody else 1.0) * Growth.num(kids[i], "scale", 1.0)
		var c0: Vector3 = n.global_position + Vector3(0, h_m * 0.55, 0)
		# the children were turned to face -fwd... the front is the camera on the side they face
		var face_dir: Vector3 = -n.global_basis.z
		face_dir.y = 0.0
		face_dir = face_dir.normalized()
		var side_dir := face_dir.cross(Vector3.UP).normalized()
		_view(c0, c0 + face_dir * (0.9 + h_m * 1.1) + Vector3(0, 0.05, 0))
		await _shot("close_%s_front" % kids[i].stage)
		_view(c0, c0 + side_dir * (0.9 + h_m * 1.1) + Vector3(0, 0.05, 0))
		await _shot("close_%s_side" % kids[i].stage)
	h.open(h.body, "family")
	await _frames(4)
	await _shot("family_tab")
	if h.screen != null:
		h.screen.family_child = String(kids[1].id)
		h.screen._show("family")
		await _frames(4)
		await _shot("family_teach_picker")
		h.screen.queue_free()
	await _frames(4)
	# walking after a parent: the player walks off, the children follow
	for c in kids:
		c["mode"] = "follow"
		c["with"] = "father"
	var far := mp + fwd * 14.0
	far.y = FrontierTerrain.height_at(far.x, far.z) + 1.0
	player.global_position = far
	player.velocity = Vector3.ZERO
	await _frames(100)
	var b0: Variant = g.child_node(kids[0])
	print("toddler clip: ", (b0 as ChildBody)._clip if b0 is ChildBody else "-", " speed ", (b0 as ChildBody).velocity.length() if b0 is ChildBody else 0.0)
	if b0 is ChildBody:
		_view((b0 as ChildBody).global_position + Vector3(0, 0.4, 0), (b0 as ChildBody).global_position + Vector3(2.4, 0.9, 1.6))
		await _shot("toddler_walking")
	await _frames(240)
	var b1: Variant = g.child_node(kids[1])
	for c in [b0, b1]:
		if c is ChildBody:
			print((c as ChildBody).child.name, " ", (c as ChildBody)._clip, " dist to player ", "%.1f" % (c as ChildBody).global_position.distance_to(player.global_position))
	# watching a parent at work: the mother forages (the toddler watches), with the child near
	print("CHILD SHOTS DONE ", out)
	quit()
