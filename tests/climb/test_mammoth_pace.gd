extends SceneTree
## The woolly mammoth's pacing and meals (StandInGiant; user 2026-09-27: "can you confirm if the mammoth is walking
## backwards or forwards", "lets do the mammoth add turns into blender for them", "eating and drinking clips as well",
## "eating uses trunk to pick up grass and leaves from tress and ground", "they use there trunk to blow water into there
## mouths", "mammoths also eats the herbs, so players are competing for the same resources"), on the climbing yard,
## headless:
##
##   Godot --headless --path . -s tests/climb/test_mammoth_pace.gd -- --no-capture
##
##   forward   pacing two beats: it only ever walks forward, and turns round at each end (the heading reversed)
##   planted   through a turn the feet on the ground stay where they are (the body turned as the clip's feet expect)
##   forage    forage near: it turns to it, walks there and eats it (the patch's food goes down: the player's loss)
##   drink     water where its trunk reaches: it drinks, blowing two squirts into its mouth a draw
##   browse    a tree before it: it browses its leaves (a spray torn off at each tug)
##   grass     nothing else: it eats grass
## Ends with "MAMMOTH PACE TEST PASSED (<n> checks)" or "MAMMOTH PACE TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var gi: StandInGiant


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	await _fr(30)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	gi = (current_scene.get("yard") as ClimbYard).giant
	# the player far off (its temper is off in a test run anyway)
	p.global_position = gi.where() + Vector3(0.0, 0.5, 80.0)
	await _forward()
	await _forage()
	await _drink()
	await _browse()
	await _grass()
	if fails.is_empty():
		print("MAMMOTH PACE TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("MAMMOTH PACE TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _bone(nm: String) -> Vector3:
	var sk := gi.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(nm)).origin


## The mammoth set down at `at` facing `dir`, its beat anew from there.
func _place(at: Vector3, dir: Vector3) -> void:
	gi.paces = false
	await _fr(2)
	at.y = FrontierTerrain.height_at(at.x, at.z)
	gi._home = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.z).normalized(), Vector3.UP), at)
	gi._pace_c = Vector3.INF
	gi.pace_state = "walk"
	gi._meal = ""
	gi._seek_t = -1e9
	await _fr(30)


func _forward() -> void:
	gi.graze_chance = 0.0
	gi._seek_t = -1e9
	gi.paces = true
	var back := 0
	var turns := 0
	var reversed := true
	var last := gi.where()
	var was := "walk"
	var h0 := gi.heading()
	var slide := {"front_toe.L": 0.0, "front_toe.R": 0.0, "toe.L": 0.0, "toe.R": 0.0}
	var prev := {}
	var t := 0.0
	while t < 75.0:
		await physics_frame
		t += 1.0 / 120.0
		var now := gi.where()
		var v := now - last
		v.y = 0.0
		last = now
		if v.length() > 0.0005 and v.normalized().dot(gi.heading()) < -0.2:
			back += 1
		if gi.pace_state == "turn":
			if was != "turn":
				h0 = gi.heading()
			for nm: String in slide:
				var at := _bone(nm)
				var g := FrontierTerrain.height_at(at.x, at.z)
				# (planted: the toe down at its standing height, 0.19 m, within 3 cm: not lifting or setting down)
				if prev.has(nm) and at.y - g < 0.22 and (prev[nm] as Vector3).y - g < 0.22:
					slide[nm] = float(slide[nm]) + Vector2(at.x - (prev[nm] as Vector3).x, at.z - (prev[nm] as Vector3).z).length()
				prev[nm] = at
		elif was == "turn":
			turns += 1
			reversed = reversed and gi.heading().dot(h0) < -0.98
			prev.clear()
		was = gi.pace_state
	_expect(back == 0, "forward: two beats and it never walks backward (%d backward steps)" % back)
	_expect(turns >= 2 and reversed, "forward: it turns round at each end (%d turns, each about-face)" % turns)
	var most := 0.0
	for nm: String in slide:
		most = maxf(most, float(slide[nm]) / maxf(turns, 1))
	_expect(most < 0.5, "planted: through a turn the feet on the ground stay put (the most any slid a turn: %.2f m)" % most)
	gi.paces = false


func _forage() -> void:
	var ff := ForageField.find(self)
	if ff == null:
		_expect(false, "forage: the level has its forage")
		return
	var spots := ff.deer_spots(gi.spawn.origin, 120.0, 12)
	if spots.is_empty():
		_expect(false, "forage: food growing near the yard")
		return
	var s: Dictionary = spots[0]
	var at: Vector3 = s.pos
	var pi := int(s.patch)
	var food0 := ff.deer_food(pi)
	# the mammoth 13 m from it, looking away; its ground about there
	var from := at + Vector3(13.0, 0.0, 0.0)
	gi.spawn = Transform3D(Basis(), from)
	await _place(from, Vector3.RIGHT)
	gi.eaten = 0.0
	gi.graze_chance = 0.0
	gi.paces = true
	gi._seek_t = StandInGiant.SEEK_EVERY
	var sought := false
	var turned := false
	var t := 0.0
	while t < 70.0 and gi.eaten <= 0.0:
		await physics_frame
		t += 1.0 / 120.0
		sought = sought or gi.pace_state == "seek"
		turned = turned or (gi.pace_state == "seek" and gi.anim.current_animation in ["Turn_L", "Turn_R"])
	await _fr(int(3.0 * 120))
	var food1 := ff.deer_food(pi)
	_expect(sought and turned, "forage: food 13 m off behind it: it turns round to it (the turn clips) and goes")
	_expect(gi.eaten > 0.0 and food1 < food0, "forage: it eats the %s (%.2f eaten; the patch's food %.2f to %.2f)" %
			[String(s.kind), gi.eaten, food0, food1])
	gi.paces = false


class FakeWater extends Node:
	var at := Vector3.ZERO
	func _ready() -> void:
		add_to_group(TorchState.WATER_GROUP)
	func is_under_water(pos: Vector3) -> bool:
		return Vector2(pos.x - at.x, pos.z - at.z).length() < 2.5 and pos.y < at.y + 0.5


func _drink() -> void:
	var spot := gi.spawn.origin + Vector3(0.0, 0.0, 30.0)
	await _place(spot, Vector3.FORWARD)
	var w := FakeWater.new()
	w.at = gi.body.global_transform * StandInGiant.DRINK_REACH
	w.at.y = FrontierTerrain.height_at(w.at.x, w.at.z)
	current_scene.add_child(w)
	gi.squirts = 0
	gi.paces = true
	await _fr(2)
	var began := gi._begin_meal(true)
	var clip := gi._meal
	var t := 0.0
	while gi.pace_state == "graze" and t < 30.0:
		await physics_frame
		t += 1.0 / 120.0
	_expect(began and clip == "Drink" and gi.squirts == 2 * StandInGiant.GRAZE_BITES,
			"drink: water in reach: it drinks (%s), %d squirts blown into its mouth" % [clip, gi.squirts])
	gi.paces = false
	w.queue_free()
	await _fr(4)


func _browse() -> void:
	var vh := VegHarvest.find(self)
	var ff := ForageField.find(self)
	var found := false
	for c: Dictionary in (vh.near(gi.spawn.origin, 90.0) if vh else []):
		if String(c.get("type", "")) != "tree":
			continue
		var tp: Vector3 = c.pos
		var dir := Vector3(1.0, 0.0, 0.3).normalized()
		var at := tp - dir * 5.5
		if absf(FrontierTerrain.height_at(at.x, at.z) - FrontierTerrain.height_at(tp.x, tp.z)) > 1.0:
			continue
		await _place(at, dir)
		if ff and not ff.deer_spots(gi.body.global_transform * StandInGiant.EAT_REACH, 3.0, 1).is_empty():
			continue
		found = true
		break
	if not found:
		_expect(false, "browse: a tree to browse near the yard")
		return
	gi.leaf_sheds = 0
	gi.paces = true
	await _fr(2)
	var began := gi._begin_meal(true)
	var clip := gi._meal
	var t := 0.0
	# each tug with the trunk up in the tree (the clip plays again for the second bite, not held at rest)
	var sheds := 0
	var lowest := INF
	while gi.pace_state == "graze" and t < 30.0:
		await physics_frame
		t += 1.0 / 120.0
		if gi.leaf_sheds > sheds:
			sheds = gi.leaf_sheds
			lowest = minf(lowest, gi._trunk_tip().y - gi.where().y)
	_expect(began and clip == "Browse" and gi.leaf_sheds == StandInGiant.GRAZE_BITES and lowest > 3.0,
			"browse: a tree before it: it browses its leaves (%s, %d sprays torn off, each %.1f m up or more)" %
			[clip, gi.leaf_sheds, lowest])
	gi.paces = false


func _grass() -> void:
	# the range lane: open ground, no trees, no forage
	var spot := gi.spawn.origin
	await _place(spot + Vector3(0.0, 0.0, 12.0), Vector3.BACK)
	gi.paces = true
	await _fr(2)
	var began := gi._begin_meal(true)
	_expect(began and gi._meal == "Eat" and not gi._tree_ahead(), "grass: nothing else in reach: it eats grass (%s)" % gi._meal)
	gi.paces = false
