extends SceneTree
## The household's hunter in the level, windowed (survival, the fort and the wildlife on): a hand given only the hunt walks to
## the rack for the household's musket (the tool pool), goes out, reads sign (kneeling), stalks a deer crouched, shoots it (a
## real ray through its hit zones, the report heard by the herd), brings it home with the household's transport (the horse,
## the cart or the wheelbarrow: HuntHaul; by hand when nothing is free), puts the transport back and the musket on the rack.
## Game time is pushed on by hand while a timed job runs (the reading of sign, the dressing). Shots of each step, and a log.
##   Godot --path . --resolution 1280x720 -s tests/companion/hunt_shots.gd -- out=<abs dir> survival=on fort_plan=on wildlife=on
var out := ""
var player: FrontierPlayer
var h: Household
var cam: Camera3D
var taken := {}


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


## A view of `who` from its side and behind, `back` m off, looking a little toward `toward`.
func _frame_on(who: Node3D, toward: Vector3, back := 4.5, up := 1.9, side := 2.2) -> void:
	var p := who.global_position
	var d := toward - p
	d.y = 0.0
	d = d.normalized() if d.length() > 0.1 else -who.global_basis.z
	var right := d.cross(Vector3.UP).normalized()
	var from := p - d * back + right * side + Vector3.UP * up
	from.y = maxf(from.y, FrontierTerrain.height_at(from.x, from.z) + 0.8)
	_look(p + Vector3.UP * 0.9 + d * 2.0, from)


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
	var core := h.bridge.core
	# a morning
	var hr := SurvivalClock.hour(core)
	core.advance(fposmod(8.0 - hr, 24.0) * 60.0)
	await _frames(5)
	var hunter := h.add_worker(777, 1.0, ["hunt"])
	hunter.role = "outside"
	SurvivalSkills.set_level(hunter.core, "hunting", 70.0)
	SurvivalSkills.set_level(hunter.core, "marksmanship", 95.0)
	SurvivalSkills.set_level(hunter.core, "woodcraft", 50.0)
	Engine.time_scale = 2.0                 # (the walks at twice the pace: the film is long)
	h.sc.role = "home"
	var hb := h.body_of(hunter)
	var wb := h.body
	await _frames(10)
	var sp := WildlifeSpawner.find(self)
	print("hour ", SurvivalClock.hour(core), " home ", h.home, " hearth ", hb.hearth, " shortages ", hunter.shortages().keys())
	print("store: ", h.stock.all())
	# the deer round home
	var deer: Array = []
	for a in sp.animals():
		if a.species in ["deer", "stag"] and not a.is_dead():
			deer.append(a)
	deer.sort_custom(func(a: WildAnimal, b: WildAnimal) -> bool: return a.global_position.distance_to(h.home) < b.global_position.distance_to(h.home))
	for a: WildAnimal in deer.slice(0, 6):
		print("  %s at %.0f m (%s)" % [a.species, a.global_position.distance_to(h.home), WildAnimal.State.keys()[a.state]])
	if deer.is_empty() or (deer[0] as WildAnimal).global_position.distance_to(h.home) > 150.0:
		# (a herd brought within reach: the nearest group set down ~110 m out, away from the fort's middle)
		var g: WildGroup = (deer[0] as WildAnimal).group if not deer.is_empty() else null
		var dir := (h.home - Vector3.ZERO)
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 1.0 else Vector3(1, 0, 0)
		var at := h.home + dir * 110.0
		var i := 0
		for a: WildAnimal in deer:
			if a.group != g:
				continue
			var p := at + Vector3(randf_range(-6, 6), 0.0, randf_range(-6, 6))
			p.y = FrontierTerrain.height_at(p.x, p.z) + 0.2
			a.global_position = p
			i += 1
		if g:
			g.home = at
			g.dest_set = false
		print("moved ", i, " deer to ", at, " (", at.distance_to(h.home), " m from home)")
	hunter.said.connect(func(t: String) -> void: print("   hunter: ", t))
	h.sc.said.connect(func(t: String) -> void: print("   wife: ", t))
	var pool := ToolPool.of(hunter)
	print("pool: musket %d on the racks, powder %d, balls %d; smart %.2f" % [pool.available("musket"), pool.available("powder"),
			pool.available("musket_balls"), HuntHaul.smart(hunter)])
	var run0 := hb.get_node("HuntRun") as HuntRun
	run0.rng.randomize()                       # (her rolls seeded by her name repeat run after run; a fresh day's luck)
	for tr: Node3D in run0.haul.horses() + [HorseCart.find(self)] + get_nodes_in_group(Wheelbarrow.GROUP):
		if tr:
			print("  transport %s at %.0f m from the hearth (%s)" % [tr.name, tr.global_position.distance_to(hb.hearth),
					run0.haul.why_not_horse(tr) if tr is Horse else (run0.haul.why_not_cart(tr) if tr is HorseCart else run0.haul.why_not_barrow(tr))])
	print("  free at home: ", run0.haul.available().keys())
	var last := ""
	var q_seen: WildAnimal = null
	var t_f := -1
	var done := false
	for i in 40000:
		await process_frame
		var ph := HuntJob.phase(hunter)
		var run := hb.get_node("HuntRun") as HuntRun
		# game time pushed on while a timed job runs (the sign, the dressing)
		if SurvivalJobs.is_running(hunter.core) or ph in ["dress", "dress_home"]:
			core.advance(0.6)
		var q: Variant = hunter.hunt.get("quarry") if not hunter.hunt.is_empty() else null
		if is_instance_valid(q) and q is WildAnimal:
			q_seen = q
		var held := pool.held_by(hunter)
		var tag := "%s/%s/%s" % [hunter.task, ph, run.haul.step_name]
		if tag != last:
			last = tag
			var qd := hb.global_position.distance_to(q_seen.global_position) if is_instance_valid(q_seen) else -1.0
			print("[%5.1fs] hunter %s  at %.0f m from home, quarry %.0f m %s  (%s) holds %s" % [i / 60.0, tag, hb.global_position.distance_to(hb.hearth), qd,
					WildAnimal.State.keys()[q_seen.state] if is_instance_valid(q_seen) else "-", hunter.task_text, held])
		# her weapon from the rack: the first frame she holds it, not yet out
		if hunter.task == "" and held.has("musket") and not taken.has("hunt_0_from_the_rack"):
			await _frames(20)
			_frame_on(hb, hb.global_position + (-hb.global_basis.z) * 3.0, 3.2, 1.6, 2.4)
			await _shot("hunt_0_from_the_rack")
			taken["_walk_f"] = i
		if taken.has("_walk_f") and i - int(taken["_walk_f"]) >= 150 and not taken.has("hunt_0b_walking_out") \
				and Vector2(hb.velocity.x, hb.velocity.z).length() > 0.5:
			# (from her side and a little behind: the musket on her back, the knife on her hip)
			_frame_on(hb, hb.global_position + (-hb.global_basis.z) * 3.0, 2.2, 1.3, 2.2)
			await _shot("hunt_0b_walking_out")
		match ph:
			"stalk":
				if q_seen and hb.global_position.distance_to(q_seen.global_position) < 70.0 and run._gun and run._gun.visible:
					_frame_on(hb, q_seen.global_position, 3.0, 1.4, 1.8)
					await _shot("hunt_1_stalking")
			"aim":
				if run and run._t > 1.6 and q_seen:
					_frame_on(hb, q_seen.global_position, 2.4, 1.2, 1.6)
					await _shot("hunt_1b_aiming")
			"after":
				if not taken.has("_shot_%d" % int(hunter.hunt.get("shots", 0))):
					taken["_shot_%d" % int(hunter.hunt.get("shots", 0))] = true
					print("     the shot: ", run._last_shot, " aim error %.1f deg, muzzle %s" % [run.aim.error_deg if run.aim else -1.0,
							run._muzzle().snapped(Vector3.ONE * 0.01)])
				if q_seen and run and run._t > 0.2 and run._t < 0.4:
					_frame_on(hb, q_seen.global_position, 3.0, 1.5, 2.0)
					await _shot("hunt_2_the_shot")
			"transport":
				if t_f < 0:
					t_f = i
				var st := run.haul.step_name
				if st == "to_carcass" and i - t_f > 200:
					_frame_on(hb, hb.global_position + (-hb.global_basis.z) * 4.0, 5.5, 2.4, 3.5)
					await _shot("hunt_3_fetching_%s" % run.haul.kind)
				if st == "to_drop":
					if not taken.has("_drop_t"):
						taken["_drop_t"] = i
					if i - int(taken["_drop_t"]) == 360:
						_frame_on(hb, hb.global_position + (-hb.global_basis.z) * 4.0, 6.0, 2.6, 4.0)
						await _shot("hunt_4_bringing_home")
			"haul":
				if not taken.has("_haul_t"):
					taken["_haul_t"] = i
				if i - int(taken["_haul_t"]) == 300:
					_frame_on(hb, hb.global_position + (-hb.global_basis.z) * 4.0, 5.0, 2.2, 3.5)
					await _shot("hunt_4_dragging")
		if hunter.task == "" and is_instance_valid(q_seen) and taken.has("hunt_2_the_shot") and not done:
			done = true
			await _frames(20)
			var away := q_seen.global_position - hb.hearth
			away.y = 0.0
			away = away.normalized() if away.length() > 0.1 else Vector3.BACK
			_look(q_seen.global_position + Vector3.UP * 0.4, q_seen.global_position + away * 5.0 + Vector3.UP * 3.0 + away.cross(Vector3.UP) * 2.0)
			await _shot("hunt_5_home")
			print("carcass %.0f m from the hearth; haul log %s" % [q_seen.global_position.distance_to(hb.hearth), run.haul.log])
		if done and pool.held_by(hunter).is_empty() and not pool.due.has(hunter.worker_id):
			print("[%5.1fs] everything back: musket on the racks %d" % [i / 60.0, pool.available("musket")])
			_frame_on(hb, hb.global_position + (-hb.global_basis.z) * 3.0, 3.2, 1.6, 2.4)
			await _shot("hunt_6_back_on_the_rack")
			break
		if not hunter.busy() and taken.has("hunt_0_from_the_rack") and not is_instance_valid(q_seen) and hunter.journal.size() > 0 \
				and String(hunter.journal.back()).contains("comes home"):
			print("came home with nothing: ", hunter.journal.back())
			break
	Engine.time_scale = 1.0
	print("hunter journal: ", hunter.journal)
	print("wife journal: ", h.sc.journal.slice(-6))
	print("store: ", h.stock.all())
	if is_instance_valid(q_seen):
		print("carcass: dress_step %d, %.0f m from the hearth, killed_by %s, wound %s" % [q_seen.dress_step,
				q_seen.global_position.distance_to(hb.hearth), q_seen.killed_by, q_seen.last_wound])
	var pl := ToolPool.of(hunter)
	print("pool after: musket on the racks %d, held by her %s, powder %d (part %.2f), balls %d" % [pl.available("musket"),
			pl.held_by(hunter), pl.available("powder"), float(pl.partial.get("powder", 0.0)), pl.available("musket_balls")])
	print("HUNT SHOTS %s %s" % ["DONE" if taken.has("hunt_5_home") else "NOT DONE", out])
	quit()
