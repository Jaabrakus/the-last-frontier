extends SceneTree
## How a household hunter brings a kill home, windowed (HuntHaul): a deer shot dead `dist` m out from the fort (its death as
## the wildlife's own: WildAnimal._die), the hunter at it in the hunt's to_carcass phase with the household's musket slung;
## she chooses by her smarts what is free (the horse first), fetches it, brings the deer home and puts the transport back.
## A log of the steps, and shots of each.
##   Godot --path . --resolution 1280x720 -s tests/companion/hunt_haul_shots.gd -- out=<abs dir> survival=on fort_plan=on wildlife=on [way=horse|cart|barrow] [dist=90]
var out := ""
var way := ""
var dist := 90.0
var wolves := false
var cam: Camera3D
var taken := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		if a.begins_with("way="):
			way = a.get_slice("=", 1)
		if a == "wolves=on":
			wolves = true
		if a.begins_with("dist="):
			dist = float(a.get_slice("=", 1))
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
	if taken.has(name):
		return
	taken[name] = true
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _look(at: Vector3, from: Vector3) -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 55.0
		current_scene.add_child(cam)
	cam.current = true
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


func _frame_on(who: Node3D, toward: Vector3, back := 5.5, up := 2.4, side := 3.5) -> void:
	var p := who.global_position
	var d := toward - p
	d.y = 0.0
	d = d.normalized() if d.length() > 0.1 else -who.global_basis.z
	var right := d.cross(Vector3.UP).normalized()
	var from := p - d * back + right * side + Vector3.UP * up
	from.y = maxf(from.y, FrontierTerrain.height_at(from.x, from.z) + 1.0)
	_look(p + Vector3.UP * 0.8 + d * 2.0, from)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	var player := current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	await _frames(150)
	var h := Household.find(self)
	var core := h.bridge.core
	core.advance(fposmod(9.0 - SurvivalClock.hour(core), 24.0) * 60.0)
	await _frames(5)
	var hunter := h.add_worker(779, 1.0, ["hunt"])
	hunter.role = "outside"
	SurvivalSkills.set_level(hunter.core, "hunting", 70.0)
	SurvivalSkills.set_level(hunter.core, "woodcraft", 50.0)
	var hb := h.body_of(hunter)
	h.sc.role = "home"
	Engine.time_scale = 3.0
	for i in 12000:
		await process_frame
		if hunter.task == "hunt":
			break
	Engine.time_scale = 2.0
	var run := hb.get_node("HuntRun") as HuntRun
	# the other transport out of the way when one is asked for
	if way != "":
		for n in run.haul.horses() + [HorseCart.find(self)] + get_nodes_in_group(Wheelbarrow.GROUP):
			var kind := "horse" if n is Horse else ("cart" if n is HorseCart else "barrow")
			if kind != way and not (way == "cart" and kind == "horse"):
				n.set_meta(HuntHaul.META, 999)
	# a deer dead out in the woods, on the side of the fort she is on
	var sp := WildlifeSpawner.find(self)
	var deer: WildAnimal = null
	for a in sp.animals():
		if a.species == "deer" and not a.is_dead():
			deer = a
			break
	for wf in sp.wolves_now():
		var far := hb.hearth + Vector3(400.0, 0.0, 400.0)
		wf.global_position = Vector3(far.x, FrontierTerrain.height_at(far.x, far.z) + 0.3, far.z)
	var away := hb.global_position - hb.hearth

	away.y = 0.0
	away = away.normalized() if away.length() > 1.0 else Vector3(1, 0, 0)
	var dp := hb.hearth + away * dist
	dp.y = FrontierTerrain.height_at(dp.x, dp.z) + 0.2
	deer.global_position = dp
	deer.call("_die", "look-check")
	await _frames(120)
	if SurvivalJobs.is_running(hunter.core):
		hunter.core._suppress_signals = true
		hunter.core.cancel_job("look-check")
		hunter.core._suppress_signals = false
	hunter.hunt["quarry"] = deer
	hunter.hunt["species"] = "deer"
	var bp := dp - away * 1.5
	hb.global_position = Vector3(bp.x, FrontierTerrain.height_at(bp.x, bp.z) + 0.1, bp.z)
	HuntJob.set_phase(hunter, "to_carcass", "Going to the deer")
	print("deer dead %.0f m from the hearth; smart %.2f; free %s" % [dp.distance_to(hb.hearth), HuntHaul.smart(hunter), run.haul.available().keys()])
	hunter.said.connect(func(t: String) -> void: print("   hunter: ", t))
	var stood := {}
	for n in run.haul.horses() + [HorseCart.find(self)] + get_nodes_in_group(Wheelbarrow.GROUP):
		if n:
			stood[n] = (n as Node3D).global_position
	var last := ""
	var step_f := 0
	for i in 60000:
		await process_frame
		var ph := HuntJob.phase(hunter)
		if i % 30 == 0 and not wolves:
			for wf in sp.wolves_now():
				var far := hb.hearth + Vector3(400.0, 0.0, 400.0)
				wf.global_position = Vector3(far.x, FrontierTerrain.height_at(far.x, far.z) + 0.3, far.z)
		if ph in ["dress", "dress_home"]:
			core.advance(0.6)
		var tag := "%s/%s/%s" % [hunter.task, ph, run.haul.step_name]
		if tag != last:
			last = tag
			step_f = i
			var hd := hb.global_position.distance_to(run.haul.horse.global_position) if run.haul.horse else -1.0
			print("[%5.1fs] %s  %.0f m from the hearth, deer %.0f m from it, horse %.1f m off  (%s)" % [i / 60.0, tag,
					hb.global_position.distance_to(hb.hearth), deer.global_position.distance_to(hb.hearth) if is_instance_valid(deer) else -1.0, hd, hunter.task_text])
		if i - step_f == 400 and ph == "transport":
			_frame_on(hb, hb.global_position - hb.global_basis.z * 3.0)
			await _shot("haul_%s_%s" % [run.haul.kind, run.haul.step_name])
		if hunter.task == "" and last.begins_with("/"):
			break
	await _frames(30)
	if is_instance_valid(deer):
		var d2 := deer.global_position - hb.hearth
		d2.y = 0.0
		_look(deer.global_position + Vector3.UP * 0.3, deer.global_position + d2.normalized() * 4.0 + Vector3.UP * 3.0)
		await _shot("haul_z_home")
		print("deer %.0f m from the hearth, dress_step %d" % [deer.global_position.distance_to(hb.hearth), deer.dress_step])
	print("journal: ", hunter.journal.slice(-4))
	print("haul log: ", run.haul.log)
	for n: Node3D in stood:
		print("  %s %.1f m from where it stood, reserved by %s" % [n.name, n.global_position.distance_to(stood[n]), str(n.get_meta(HuntHaul.META, -1))])
	print("HAUL SHOTS DONE ", out)
	Engine.time_scale = 1.0
	quit()
