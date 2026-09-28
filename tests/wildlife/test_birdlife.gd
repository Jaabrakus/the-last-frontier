extends SceneTree
## Birds and fireflies (scripts/wildlife: BirdLife, Owl, BirdFlock, Fireflies; AmbienceBed's calls by the hour) in the
## real level, headless (no clock headless: the sun's height is set through sun_override):
##
##   Godot --headless --fixed-fps 60 --path . -s tests/wildlife/test_birdlife.gd -- birdlife=on
##
## Ends with "BIRDLIFE TEST PASSED <n>" or "BIRDLIFE TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func seconds(t: float) -> void:
	for i in int(t * Engine.physics_ticks_per_second):
		await physics_frame


func _set_sun(el: float, birds: BirdLife, ff: Fireflies, amb: AmbienceBed) -> void:
	birds.sun_override = el
	ff.sun_override = el
	amb.sun_override = el


func _run() -> void:
	for i in 10:
		await process_frame
	var birds := current_scene.get_node_or_null("BirdLife") as BirdLife
	var ff := current_scene.get_node_or_null("Fireflies") as Fireflies
	var amb := current_scene.get_node_or_null("AmbienceBed") as AmbienceBed
	var player := current_scene.get_node("Player") as FrontierPlayer
	check(birds != null and ff != null and amb != null, "the level has BirdLife, Fireflies and the AmbienceBed")
	if birds == null or ff == null or amb == null:
		_end()
		return
	# the level's golden hour: the thrushes' hour, no fireflies yet, no owls
	check(amb.band() == "dusk", "at the golden hour the thrushes sing (band %s)" % amb.band())
	check(String(amb._pick_bird("dusk")).begins_with("bird_rec_"), "from the real recordings (%s)" % amb._pick_bird("dusk"))
	check(ff.target_presence() < 0.01, "no fireflies in the low sun (%.2f)" % ff.target_presence())
	# out into the woods, night
	var spot := Vector3(60.0, 0.0, 70.0)
	player.global_position = Vector3(spot.x, FrontierTerrain.height_at(spot.x, spot.z) + 0.1, spot.z)
	_set_sun(-14.0, birds, ff, amb)
	await seconds(3.0)
	check(amb.band() == "night", "night: the night calls")
	var night_ids := {}
	for i in 40:
		night_ids[amb._pick_bird("night")] = true
	check(night_ids.has("bird_rec_barred_owl") and night_ids.has("bird_rec_whip_poor_will"), "owls and the whip-poor-will call (%s)" % str(night_ids.keys()))
	check(ff.target_presence() > 0.3, "fireflies are out (%.2f)" % ff.target_presence())
	var owls := birds.owls()
	check(owls.size() == BirdLife.OWLS_AT_NIGHT, "owls perch round the player (%d)" % owls.size())
	var ok_perch := 0
	var lay = current_scene.get_node("Vegetation").layout
	for o in owls:
		var up := o.global_position.y - FrontierTerrain.height_at(o.global_position.x, o.global_position.z)
		var near_trunk := INF
		for t: Vector3 in lay.tree_pos:
			near_trunk = minf(near_trunk, Vector2(t.x - o.global_position.x, t.z - o.global_position.z).length())
		if up > 2.5 and near_trunk < 2.0:
			ok_perch += 1
	check(ok_perch == owls.size(), "each on a limb of a tree, up off the ground (%d/%d)" % [ok_perch, owls.size()])
	var dist_trunk := 0
	for o in owls:
		if Vector2(o.global_position.x - o.trunk.x, o.global_position.z - o.trunk.z).length() < 1.6:
			dist_trunk += 1
	check(dist_trunk == owls.size(), "its branch grows from the trunk it sits by")
	# an owl calls; a barred owl may be answered
	if not owls.is_empty():
		owls[0].call_in = 0.0
		await seconds(0.5)
		var called := false
		for e: Array in birds.sound_log:
			if String(e[0]) in ["bird_rec_barred_owl", "bird_rec_great_horned_owl"]:
				called = true
		check(called, "an owl calls")
		# the eyes shine in the dark
		var o := owls[0]
		check(o._eye_mat.emission_energy_multiplier > 1.0, "its yellow eyes shine in the dark (%.1f)" % o._eye_mat.emission_energy_multiplier)
		# the player walks up under it: it is suddenly gone, the bare branch left
		var was := o.global_position
		player.global_position = Vector3(was.x + 2.0, FrontierTerrain.height_at(was.x + 2.0, was.z) + 0.1, was.z)
		await seconds(0.5)
		check(o.mode == Owl.Mode.GONE and not o._bird.visible and o._branch.visible, "it vanishes when the player comes close (the branch stays)")
		# later it turns up on another tree
		player.global_position = Vector3(spot.x, FrontierTerrain.height_at(spot.x, spot.z) + 0.1, spot.z)
		o.gone_until = birds.now
		await seconds(3.0)
		check(o.mode == Owl.Mode.PERCH and o._bird.visible and o.global_position.distance_to(was) > 20.0,
				"it turns up again on another tree (%.0f m off)" % o.global_position.distance_to(was))
		# stared at: gone
		var o2 := owls[1] if owls.size() > 1 else o
		o2._stare = Owl.STARE_S + 0.1
		await seconds(0.2)
		check(o2.mode == Owl.Mode.GONE, "stared at too long, it vanishes")
	# day: the owls go, flocks cross, a shot flushes a flock
	_set_sun(35.0, birds, ff, amb)
	await seconds(1.0)
	check(amb.band() == "day", "day: the day birds")
	check(ff.target_presence() < 0.01, "no fireflies by day")
	birds._flock_in = 0.0
	await seconds(1.0)
	var flocks := current_scene.get_tree().get_nodes_in_group(&"flocks").size()
	check(flocks >= 1, "a flock crosses the sky (%d)" % flocks)
	await seconds(15.0)
	check(birds.owls().is_empty(), "the owls have gone at day (%d left)" % birds.owls().size())
	var before := current_scene.get_tree().get_nodes_in_group(&"flocks").size()
	for i in 6:
		birds.flush()
	check(current_scene.get_tree().get_nodes_in_group(&"flocks").size() > before, "a shot sends a flock up from the trees")
	_end()


func _end() -> void:
	if fails.is_empty():
		print("BIRDLIFE TEST PASSED %d" % checks)
	else:
		print("BIRDLIFE TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
