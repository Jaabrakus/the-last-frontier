extends SceneTree
## A household hunter aiming, close up (user 2026-09-29: "why does he aim the weapon not normal?"): a hand given the hunt takes
## the household's musket from the rack (slung on his back: WorkerGear), and is set 30-40 m from a deer standing still, in the
## hunt's aim phase: the musket off its sling in the aim clip's two-hand hold, the upper body turned to lay the barrel on the
## deer (HuntAim). Shots from the side and from behind, standing (in the open) and crouched (close in), and the log of the
## barrel's error to the deer's chest. The deer is held still (its brain off) so the frames compare.
##   Godot --path . --resolution 1280x720 -s tests/companion/hunt_aim_shots.gd -- out=<abs dir> survival=on fort_plan=on wildlife=on
var out := ""
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
		cam.fov = 50.0
		current_scene.add_child(cam)
	cam.current = true
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


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
	var hunter := h.add_worker(778, 1.0, ["hunt"])
	hunter.role = "outside"
	SurvivalSkills.set_level(hunter.core, "hunting", 70.0)
	SurvivalSkills.set_level(hunter.core, "marksmanship", 85.0)
	var hb := h.body_of(hunter)
	h.sc.role = "home"
	# out to hunt: to the rack for the musket, then off to read sign
	Engine.time_scale = 3.0
	for i in 12000:
		await process_frame
		if hunter.task == "hunt":
			break
	Engine.time_scale = 1.0
	print("hunting: ", hunter.task, " holds ", ToolPool.of(hunter).held_by(hunter))
	var sp := WildlifeSpawner.find(self)
	var deer: WildAnimal = null
	for a in sp.animals():
		if a.species in ["deer", "stag"] and not a.is_dead():
			deer = a
			break
	var run := hb.get_node("HuntRun") as HuntRun
	# (in the fort's yard, the open ground: the hunter by the hearth, the deer across the yard, the longest clear line)
	var at := hb.hearth + Vector3(2.0, 0.0, 2.0)
	var best := Vector3.FORWARD
	var bd := 0.0
	var space := hb.get_world_3d().direct_space_state
	for k in 16:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.UP + d * 60.0, 1, [hb.get_rid()]))
		var free := 60.0 if hit.is_empty() else at.distance_to(hit.position) - 1.0
		if free > bd:
			bd = free
			best = d
	print("clear line %.0f m" % bd)
	for pose: Array in [["stand", minf(34.0, bd - 3.0)], ["crouch", 15.0]]:
		# the deer held still in the open, the hunter set off it facing it, in the aim phase
		deer.set_physics_process(false)
		hb.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.1, at.z)
		var dp := at + best * float(pose[1])
		dp.y = FrontierTerrain.height_at(dp.x, dp.z)
		deer.global_position = dp
		if SurvivalJobs.is_running(hunter.core):
			hunter.core._suppress_signals = true
			hunter.core.cancel_job("look-check")
			hunter.core._suppress_signals = false
		hunter.hunt["quarry"] = deer
		hunter.hunt["species"] = String(deer.species)
		hunter.hunt["shots"] = 99                 # (she holds her fire: the frames are of the aim)
		SurvivalInventory.remove(hunter.core, "item.ammo.ball", 999.0)
		HuntJob.set_phase(hunter, "aim", "Taking aim")
		run.set("_ph", "")                        # (the phase's clock starts over: the stance is chosen again)
		for i in 90:
			await process_frame
		print("%s at %.0f m: stance %s, clip %s, aim weight %.2f, barrel off the chest %.1f deg" % [pose[0], float(pose[1]),
				run.get("_stance_now"), hb.idle_clip, run.aim.weight, run.aim.error_deg])
		var p := hb.global_position
		var to := (deer.global_position - p)
		to.y = 0.0
		to = to.normalized()
		var right := to.cross(Vector3.UP).normalized()
		_look(p + Vector3.UP * 1.2 + to * 0.5, p - right * 2.3 + Vector3.UP * 1.4 + to * 0.6)
		await _shot("aim_%s_side" % pose[0])
		_look(deer.global_position + Vector3.UP * 0.7, p - to * 1.4 + right * 0.45 + Vector3.UP * 1.65)
		await _shot("aim_%s_behind" % pose[0])
	print("AIM SHOTS DONE ", out)
	quit()
