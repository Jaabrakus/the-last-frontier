extends SceneTree
## Fireflies in the world (scripts/wildlife/fireflies.gd; user 2026-09-27: "i dont want the fireflies around me i want
## them to be in the world"), on the level, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/wildlife/test_fireflies.gd -- birdlife=on
##
## The patches are set once over meadows and forest edges (open ground, woods round it), apart, out of the fort; at
## night the nearest few glow and none by day; they stay where they are when the player walks off, and the ones near
## the player's new place light instead. Ends with "FIREFLIES TEST OK (<n> checks)" or "FIREFLIES TEST FAILED ...".

const CanopyMap := preload("res://scripts/world/vegetation/canopy_map.gd")

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await frames(30)
	var ff := current_scene.get_node_or_null("Fireflies") as Fireflies
	var player := current_scene.get_node_or_null("Player") as Node3D
	check(ff != null and player != null, "the level has its fireflies (birdlife=on)")
	if ff == null:
		_end()
		return
	if CanopyMap.image == null:
		# headless the vegetation builds no visuals and bakes no canopy map (the game does): bake it here
		var veg := current_scene.get_node_or_null("Vegetation")
		if veg == null:
			for c in current_scene.find_children("*", "", true, false):
				if c.get("layout") != null and c.get("layout") is RefCounted and (c.get("layout") as Object).get("tree_pos") != null:
					veg = c
					break
		CanopyMap.bake(veg.get("layout"))
		await frames(2)
	check(ff.patches.size() >= 12, "patches set over the land: %d" % ff.patches.size())
	var open := 0
	var edge := 0
	var gap := INF
	var in_fort := false
	for i in ff.patches.size():
		var p: Vector3 = ff.patches[i]
		if CanopyMap.cover_around(p.x, p.z, 6.0) < 0.12:
			open += 1
		if CanopyMap.cover_around(p.x, p.z, 28.0) > 0.12:
			edge += 1
		if absf(p.x) < Fireflies.FORT_HALF and absf(p.z) < Fireflies.FORT_HALF:
			in_fort = true
		for j in range(i + 1, ff.patches.size()):
			gap = minf(gap, Vector2(p.x - ff.patches[j].x, p.z - ff.patches[j].z).length())
	check(open == ff.patches.size() and edge == ff.patches.size(), "each on open ground with woods round it (%d, %d)" % [open, edge])
	check(gap >= Fireflies.PATCH_GAP - 0.1 and not in_fort, "apart (%.0f m at the least), none in the fort" % gap)
	var near_fort := 0
	for q in ff.patches:
		if Vector2(q.x, q.z).length() < 200.0:
			near_fort += 1
	check(near_fort >= 6, "%d patches within 200 m of the fort" % near_fort)
	print("    patches: ", ff.patches.slice(0, 8))
	# night: the nearest glow
	ff.sun_override = -10.0
	var near: Vector3 = ff.patches[0]
	player.global_position = Vector3(near.x + 20.0, FrontierTerrain.height_at(near.x + 20.0, near.z) + 0.2, near.z)
	await frames(int(3.0 * Engine.physics_ticks_per_second))
	var on := ff.active()
	check(ff.presence > 0.3 and on.has(0) and on.size() <= Fireflies.ACTIVE, "night: the patch by the player glows, %d at most (%s)" % [Fireflies.ACTIVE, str(on)])
	var s0: GPUParticles3D = ff.swarms[0]
	var at0 := s0.global_position if s0 else Vector3.INF
	check(s0 != null and Vector2(at0.x - near.x, at0.z - near.z).length() < 0.1, "its swarm stands over the patch")
	# the player walks off to the farthest patch
	var far_i := 0
	var far_d := 0.0
	for i in ff.patches.size():
		var d := near.distance_to(ff.patches[i])
		if d > far_d:
			far_d = d
			far_i = i
	var far: Vector3 = ff.patches[far_i]
	player.global_position = Vector3(far.x + 15.0, FrontierTerrain.height_at(far.x + 15.0, far.z) + 0.2, far.z)
	await frames(int(3.0 * Engine.physics_ticks_per_second))
	on = ff.active()
	check(on.has(far_i) and not on.has(0), "walked %.0f m off: the patch there glows, the first is dark (%s)" % [far_d, str(on)])
	check(ff.swarms[0] == null or not (ff.swarms[0] as GPUParticles3D).emitting, "the first swarm did not follow")
	# by day none
	ff.sun_override = 30.0
	await frames(int(12.0 * Engine.physics_ticks_per_second))
	check(ff.active().is_empty() and ff.presence < 0.05, "by day: none (%.2f)" % ff.presence)
	_end()


func _end() -> void:
	if fails.is_empty():
		print("FIREFLIES TEST OK (%d checks)" % checks)
	else:
		print("FIREFLIES TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
