extends SceneTree
## A household hunter rides the horse out for the hunt (HuntRide, HuntRun._horse_first), windowed: the horse free at home, a
## deer grazing `dist` m out; she saddles up, rides out, leaves the horse out of the deer's sight, stalks on foot and shoots;
## back to the horse, rides it to the kill, lays the deer across the saddle (CarcassPack) and leads the horse home. A log of
## the hunt's phases and the haul's steps, and shots of each.
##   Godot --path . --resolution 1280x720 -s tests/companion/hunt_ride_shots.gd -- out=<abs dir> survival=on fort_plan=on wildlife=on [dist=190] [young=on]
var out := ""
var dist := 190.0
var young := false
## sure=on: the deer drops when she takes aim (the kill's way home is what is looked at)
var sure := false
var cam: Camera3D
var taken := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		if a.begins_with("dist="):
			dist = float(a.get_slice("=", 1))
		if a == "young=on":
			young = true
		if a == "sure=on":
			sure = true
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
	if taken.has(name) or out == "":
		return
	taken[name] = true
	await _frames(2)
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)
	else:
		await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _look(at: Vector3, from: Vector3) -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 50.0
		current_scene.add_child(cam)
	cam.current = true
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


## From beside and behind `who` (its right), looking the way it goes.
func _frame_on(who: Node3D, back := 6.0, up := 2.2, side := 4.0) -> void:
	var p := who.global_position
	var d := -who.global_basis.z
	d.y = 0.0
	d = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
	var right := d.cross(Vector3.UP).normalized()
	var at := p + Vector3.UP * 1.0 + d * 1.5
	# (the side with the clearest view: behind-right, behind-left, ahead-right, ahead-left; pulled in before a trunk)
	var best_from := Vector3.INF
	var best_len := -1.0
	for k: Vector2 in [Vector2(-1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(0, 1), Vector2(0, -1)]:
		var from := p + d * back * k.x + right * side * k.y + Vector3.UP * up
		from.y = maxf(from.y, FrontierTerrain.height_at(from.x, from.z) + 1.2)
		var q := PhysicsRayQueryParameters3D.create(at, from)
		q.exclude = [who.get_rid()] if who is CollisionObject3D else []
		var hit := who.get_world_3d().direct_space_state.intersect_ray(q)
		var len := at.distance_to(from) if hit.is_empty() else at.distance_to(hit.position) - 0.4
		if len > best_len + 0.5:
			best_len = len
			best_from = from if hit.is_empty() else at.lerp(from, len / at.distance_to(from))
	_look(at, best_from)


func _run() -> void:
	if out != "":
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
	core.advance(fposmod(8.5 - SurvivalClock.hour(core), 24.0) * 60.0)
	await _frames(5)
	var hunter := h.add_worker(779, 1.0, ["hunt"])
	hunter.role = "outside"
	SurvivalSkills.set_level(hunter.core, "hunting", 70.0)
	SurvivalSkills.set_level(hunter.core, "woodcraft", 50.0)
	SurvivalSkills.set_level(hunter.core, "marksmanship", 75.0)
	if young:
		hunter.body_look["stage"] = "junior"
	var hb := h.body_of(hunter)
	h.sc.role = "home"
	Engine.time_scale = 3.0
	for i in 12000:
		await process_frame
		if hunter.task == "hunt":
			break
	var run := hb.get_node("HuntRun") as HuntRun
	var sp := WildlifeSpawner.find(self)
	var horse: Horse = run.haul.available().get("horse")
	print("hunt begins; the horse %s, %.0f m from her" % [horse, horse.global_position.distance_to(hb.global_position) if horse else -1.0])
	var stood := horse.global_position if horse else Vector3.ZERO
	# a deer about `dist` m out (one grazing there, else one moved there with its land)
	var deer: WildAnimal = null
	var best := INF
	for a in sp.animals():
		if a.species != "deer" or a.is_dead():
			continue
		var dd := absf(a.global_position.distance_to(hb.hearth) - dist)
		if dd < best:
			best = dd
			deer = a
	if best > 25.0:
		var away := hb.global_position - hb.hearth
		away.y = 0.0
		away = away.normalized() if away.length() > 1.0 else Vector3(1, 0, 0)
		var dp := hb.hearth + away * dist
		dp.y = FrontierTerrain.height_at(dp.x, dp.z) + 0.2
		deer.global_position = dp
		deer.home_sq = WorldSquares.square_at(dp)
		if deer.group != null:
			deer.group.home = dp
	print("the deer %.0f m from the hearth; the way by the landmarks: %s" % [deer.global_position.distance_to(hb.hearth),
			NavLandmarks.route(self, hb.global_position, deer.global_position)])
	hunter.said.connect(func(t: String) -> void: print("   hunter: ", t))
	var last := ""
	var step_f := 0
	var riding_shots := 0
	for i in 90000:
		await process_frame
		var ph := HuntJob.phase(hunter)
		if i % 30 == 0:
			for wf in sp.wolves_now():
				var far := hb.hearth + Vector3(400.0, 0.0, 400.0)
				wf.global_position = Vector3(far.x, FrontierTerrain.height_at(far.x, far.z) + 0.3, far.z)
		if ph == "track" or (ph == "stalk" and hunter.hunt.get("quarry") == null):
			# (the sign read at once, and the deer she is sent after)
			if SurvivalJobs.is_running(hunter.core):
				hunter.core._suppress_signals = true
				hunter.core.cancel_job("look-check")
				hunter.core._suppress_signals = false
			if is_instance_valid(deer) and not deer.is_dead():
				hunter.hunt["quarry"] = deer
				hunter.hunt["species"] = "deer"
				HuntJob.set_phase(hunter, "stalk", "Stalking a deer")
		if ph in ["dress", "dress_home"]:
			core.advance(0.6)
		if sure and ph == "aim" and is_instance_valid(deer) and not deer.is_dead():
			deer.call("_die", "look-check")
			await _frames(100)
			HuntJob.set_phase(hunter, "to_carcass", "Going to the deer")
			ph = "to_carcass"
		var plan := String(hunter.hunt.get("horse_plan", ""))
		var tag := "%s/%s/%s/%s" % [hunter.task, ph, plan, run.haul.step_name]
		if tag != last:
			last = tag
			step_f = i
			var hr := run.haul.horse_out if run.haul.horse_out else run.haul.horse
			print("[%6.1fs] %s  her %.0f m from the hearth, deer %.0f m off her, horse %.1f m off her%s  (%s)" % [i / 60.0, tag,
					hb.global_position.distance_to(hb.hearth), hb.global_position.distance_to(deer.global_position) if is_instance_valid(deer) else -1.0,
					hb.global_position.distance_to(hr.global_position) if hr else -1.0, " riding" if run.ride.on else "", hunter.task_text])
		if i % 300 == 150:
			var hr2 := run.haul.horse_out if run.haul.horse_out else run.haul.horse
			print("   .. %s: her at %s, %.0f m from the deer, speed %.1f, horse %s%s" % [tag, hb.global_position.snappedf(0.1),
					hb.global_position.distance_to(deer.global_position) if is_instance_valid(deer) else -1.0,
					Vector2(hb.velocity.x, hb.velocity.z).length(), hr2.global_position.snappedf(0.1) if hr2 else "-",
					" feel %s" % str((hr2.get_node("Lead") as HorseLead).get("_feel")) if hr2 and run.ride.on else ""])
		var subj: Node3D = run.ride.horse if run.ride.on else hb
		if i - step_f == 90:
			_frame_on(subj)
			await _shot("%05d_%s" % [i, tag.replace("/", "_")])
		if run.ride.on and i % 600 == 300 and riding_shots < 6:
			riding_shots += 1
			_frame_on(subj, 5.0, 1.8, 4.5)
			await _shot("%05d_riding" % i)
		if run.haul.pack != null and i % 600 == 0:
			_frame_on(run.haul.horse, 4.0, 1.6, 3.5)
			await _shot("%05d_packed" % i)
		if hunter.task == "" and i > 200:
			break
	await _frames(30)
	if is_instance_valid(deer):
		var d2 := deer.global_position - hb.hearth
		d2.y = 0.0
		_look(deer.global_position + Vector3.UP * 0.3, deer.global_position + d2.normalized() * 4.0 + Vector3.UP * 3.0)
		await _shot("zz_home")
		print("deer %.0f m from the hearth, dead %s" % [deer.global_position.distance_to(hb.hearth), deer.is_dead()])
	print("journal: ", hunter.journal.slice(-6))
	print("haul log: ", run.haul.log)
	if horse:
		print("the horse %.1f m from where it stood, reserved by %s, left_by %s" % [horse.global_position.distance_to(stood),
				str(horse.get_meta(HuntHaul.META, -1)), str(horse.get_meta(&"left_by", {}))])
	print("RIDE SHOTS DONE ", out)
	Engine.time_scale = 1.0
	quit()
