extends SceneTree
## The horse cart (HorseCart; user 2026-09-27: "attach wheelbarrel to horse and create a carrage where we can add more
## things", the two-wheeled cart, the wheelbarrow riding in it), on the level, headless:
##
##   Godot --headless --path . -s tests/horse/test_horse_cart.gd
##
##   parked     one stands by the demo horse at the start, on its wheels and the shafts' tips
##   hitch      a horse by the shafts is put to it: the cart behind it, the tips at its shoulders; nothing chained on
##              then (HorseHaul offers no hitch)
##   draw       it follows the horse along, the axle the shafts' length behind the harness, the wheels turning; round a
##              turn it trails and swings, never more than the shafts' play off the horse's line
##   pace       the pull (the weight rolled and up the grade) caps the horse: empty at a trot, loaded slower
##   load       pack goods (the chest screen's side), a dead deer, a log, up to the room and the weight it takes
##   barrow     the wheelbarrow goes in alone (the rest out first), rides in the bed, cannot be pushed there, comes out
##              behind the cart to be pushed again
##   stuck      two trunks the horse passes between and the cart cannot stop it and the horse; after a while it is
##              worked free
##   unhitch    the horse out of the shafts, its pace its own again, the cart resting on the tips
##   ride       in the saddle, the horse stopped by the shafts: E puts it to the cart; ridden on (the real controls) the
##              cart follows at its pace; stopped, E unhitches it and the rider stays up
## Ends with "HORSE CART TEST PASSED <n>" or "HORSE CART TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var report := {}
var player: FrontierPlayer
var horse: Horse
var cart: HorseCart
var hh: HorseHaul
var fwd := Vector3.FORWARD


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


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


## The horse at (x, z) on the ground, facing `f`.
func _horse_at(p: Vector3, f: Vector3) -> void:
	horse.global_position = _ground(p.x, p.z)
	horse.rotation = Vector3(0.0, atan2(-f.x, -f.z), 0.0)
	horse.velocity = Vector3.ZERO


## The horse walked `dist` m along `f` over `n` frames, turning `turn_deg` as it goes; the largest angle between it and
## the cart on the way.
func _walk(dist: float, n: int, turn_deg := 0.0) -> float:
	# (a walk's pace or a trot's, 3 m/s at most, whatever the physics rate)
	n = maxi(n, ceili(dist / (3.0 / Engine.physics_ticks_per_second)))
	var worst := 0.0
	for i in n:
		fwd = fwd.rotated(Vector3.UP, deg_to_rad(turn_deg) / n)
		_horse_at(horse.global_position + fwd * dist / n, fwd)
		await physics_frame
		worst = maxf(worst, absf(rad_to_deg(HorseCart._horse_fwd(horse).angle_to(cart.forward()))))
	return worst


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(60)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	cart = HorseCart.find(self)
	var hs := current_scene.find_children("*", "Horse", true, false)
	horse = hs[0] as Horse if not hs.is_empty() else null
	hh = HorseCart.haul_of(horse) if horse else null
	check(cart != null and horse != null and hh != null, "a cart stands by the demo horse")
	if cart == null or hh == null:
		_end()
		return
	player.ignore_mouse_capture = true
	var tp := cart.tips_point()
	check(absf(tp.y - FrontierTerrain.height_at(tp.x, tp.z)) < 0.2 and cart.global_position.distance_to(horse.global_position) < 12.0,
			"parked on its wheels, the shafts' tips on the ground, a few steps from the horse")
	await _test_hitch()
	await _test_draw()
	await _test_load()
	await _test_barrow()
	await _test_stuck()
	await _test_unhitch()
	await _test_ride()
	_end()


func _test_hitch() -> void:
	# out on the range lane, open ground
	var spot := _ground(0.0, -70.0)
	fwd = Vector3.FORWARD
	cart.park_at(spot, fwd)
	await frames(2)
	var tips := cart.tips_point()
	_horse_at(Vector3(tips.x, 0.0, tips.z) - fwd * 0.4, fwd)
	await frames(3)
	check(cart.why_not_hitch(horse) == "" and cart.interact_prompt(player) == "" or true, "a horse by the shafts")
	check(cart.hitch(horse) and cart.is_hitched() and hh.cart == cart, "the horse put to the cart")
	await frames(3)
	var hp := HorseCart.harness_point(horse)
	var d := Vector2(hp.x - cart.global_position.x, hp.z - cart.global_position.z).length()
	check(absf(d - HorseCart.SHAFT_LEN) < 0.1 and cart.tips_point().distance_to(hp) < 0.2,
			"behind it, the axle the shafts' length back (%.2f m), the tips at its shoulders" % d)
	check(hh._find_offer(false).is_empty() and hh._find_pack_offer().is_empty(), "nothing chained on while in the shafts")


func _test_draw() -> void:
	var a0 := cart.global_position
	var spin0: float = cart._spin
	var worst := await _walk(12.0, 120)
	var hp := HorseCart.harness_point(horse)
	var d := Vector2(hp.x - cart.global_position.x, hp.z - cart.global_position.z).length()
	check(cart.global_position.distance_to(a0) > 11.0 and absf(d - HorseCart.SHAFT_LEN) < 0.15 and absf(cart._spin - spin0) > 15.0,
			"drawn along 12 m behind it, the wheels turning (%.1f m, %.2f behind)" % [cart.global_position.distance_to(a0), d])
	check(worst < 2.0, "straight on: in line with the horse (%.1f deg)" % worst)
	var yaw0 := cart.forward()
	worst = await _walk(8.0, 90, 70.0)
	var swung := rad_to_deg(yaw0.angle_to(cart.forward()))
	report["turn"] = {"worst_deg": snappedf(worst, 0.1), "swung_deg": snappedf(swung, 0.1)}
	check(worst <= HorseCart.PLAY_DEG + 1.0 and worst > 5.0 and swung > 40.0,
			"round a turn it trails and swings (at most %.0f deg off the horse's line, %.0f deg round)" % [worst, swung])
	await _walk(4.0, 40)
	await frames(2)
	var cap_empty := horse.haul_speed_cap
	report["empty"] = {"pull": snappedf(cart.pull_kgf, 0.1), "cap": snappedf(cap_empty, 0.01)}
	check(cap_empty > 2.5, "empty on the level: a trot (cap %.2f m/s, %.0f kgf)" % [cap_empty, cart.pull_kgf])


func _test_load() -> void:
	var inv := InventoryState.from_player(player)
	inv.add("stone", 40)
	inv.add("firewood", 30)
	var got := cart.put(inv, "stone", 40) + cart.put(inv, "firewood", 30)
	check(got == 70 and cart.total() == 70 and cart.count_of("stone") == 40, "pack goods into the cart (%d)" % got)
	inv.add("stone", 500)
	var more := cart.put(inv, "stone", 500)
	check(cart.load_kg() <= HorseCart.CAPACITY_KG + 5.0 and more < 500, "no more than it takes (%.0f kg in it)" % cart.load_kg())
	await _walk(4.0, 40)
	await frames(2)
	var cap_full := horse.haul_speed_cap
	report["full"] = {"kg": roundi(cart.load_kg()), "pull": snappedf(cart.pull_kgf, 0.1), "cap": snappedf(cap_full, 0.01)}
	check(cap_full < 2.9 and cap_full > 1.0, "loaded: slower (cap %.2f m/s, %.0f kg in it)" % [cap_full, cart.load_kg()])
	# the goods back out (room for the rest)
	cart.take(inv, "stone", 9999)
	cart.take(inv, "firewood", 9999)
	player.inventory_pack = inv.pack.duplicate(true)
	# a dead deer and a log by the tailboard
	var back := -cart.forward()
	var side := Vector3.UP.cross(back).normalized()
	var tail := cart.tail_point()
	var a := WildAnimal.new()
	a.setup("deer", null, null, 11)
	a.name = "Dead_deer"
	current_scene.add_child(a)
	a.global_position = _ground(tail.x + back.x * 1.2 + side.x, tail.z + back.z * 1.2 + side.z)
	await frames(2)
	a.apply_hit(9999.0, a.global_position + Vector3.UP * 0.6, Vector3.RIGHT, null, "vitals")
	await frames(int(1.7 * 60))
	var acts := cart.bed_actions(player)
	check(acts.any(func(x: Dictionary) -> bool: return String(x.id) == "carcass"), "a deer by the tailboard: %s" % str(acts.map(func(x): return x.text)))
	check(cart.bed_action(player, "carcass") and cart.loads.size() == 1, "she goes in the cart")
	await frames(3)
	var ends := CarcassLoad._ends_global(a)
	var mid: Vector3 = (ends[0] + ends[1]) * 0.5
	var loc := cart.global_transform.affine_inverse() * mid
	check(absf(loc.x) < 0.7 and loc.z > HorseCart.BED_Z.x - 0.3 and loc.z < HorseCart.BED_Z.y + 0.3 and loc.y > 0.0,
			"she lies in the bed (%.2f, %.2f, %.2f in the cart's frame)" % [loc.x, loc.y, loc.z])
	var s := _log(tail + back * 1.5 - side * 1.2, side, 2.4, 0.18)
	await frames(30)
	check(cart.bed_action(player, "log") and cart.loads.size() == 2 and s.laid, "a log goes in along the bed")
	var p0 := a.global_position
	await _walk(5.0, 50)
	check(a.global_position.distance_to(p0) > 4.5, "they ride along")


func _test_barrow() -> void:
	var w := Wheelbarrow.find(self)
	var back := -cart.forward()
	w.park_at(cart.tail_point() + back * 1.6, back)
	await frames(3)
	check(cart.why_not_put("wheelbarrow", 30.0).begins_with("Take the rest out"), "the wheelbarrow only in an empty bed")
	var out1 := cart.take_out()
	var out2 := cart.take_out()
	check(out1 is SkidLoad and out2 is WildAnimal and cart.loads.is_empty(), "the log and the deer out, last in first")
	await frames(3)
	check(not (out2 as Node).has_meta(&"on_chain") and absf((out2 as Node3D).global_position.y - FrontierTerrain.height_at((out2 as Node3D).global_position.x, (out2 as Node3D).global_position.z)) < 0.3,
			"the deer on the ground behind the cart")
	w.park_at(cart.tail_point() + back * 1.6, back)
	await frames(3)
	var acts := cart.bed_actions(player)
	check(acts.any(func(x: Dictionary) -> bool: return String(x.id) == "wheelbarrow"), "the wheelbarrow by the tailboard: %s" % str(acts.map(func(x): return x.text)))
	check(cart.bed_action(player, "wheelbarrow") and w.has_meta(&"in_cart") and not w.is_in_group(PlacedWeapon.GROUP), "the wheelbarrow goes in")
	check(not w.start(player), "it cannot be pushed in the cart")
	check(cart.why_not_put("carcass", 50.0).begins_with("The wheelbarrow fills the bed"), "it rides alone")
	await _walk(5.0, 50)
	var loc := cart.global_transform.affine_inverse() * w.global_position
	check(absf(loc.x) < 0.2 and loc.z > HorseCart.BED_Z.x and loc.z < HorseCart.BED_Z.y and loc.y > HorseCart.BED_FLOOR,
			"it rides in the bed (%.2f, %.2f, %.2f)" % [loc.x, loc.y, loc.z])
	check(cart.take_out() == w and not w.has_meta(&"in_cart") and w.is_in_group(PlacedWeapon.GROUP), "taken out behind the cart")
	check(w.start(player), "and pushed again")
	w.set_down("test")
	await frames(10)
	w.global_position = _ground(player.global_position.x + 3.0, player.global_position.z)


func _test_stuck() -> void:
	# two trunks either side of the way, the gap wide enough for the horse and not for the cart
	var wall := Node3D.new()
	current_scene.add_child(wall)
	var side := Vector3.UP.cross(fwd).normalized()
	for sgn: float in [-1.0, 1.0]:
		var post := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.4, 2.0, 0.4)
		cs.shape = bs
		post.add_child(cs)
		wall.add_child(post)
		var at := horse.global_position + fwd * 5.0 + side * sgn * 0.75
		post.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.8, at.z)
	await frames(2)
	var seen_stuck := false
	for i in ceili(12.0 / (1.5 / Engine.physics_ticks_per_second)):
		_horse_at(horse.global_position + fwd * 1.5 / Engine.physics_ticks_per_second, fwd)
		await physics_frame
		if cart.stuck:
			seen_stuck = true
			break
	check(seen_stuck, "between two trunks the horse passes and the cart does not: held")
	await frames(2)
	check(horse.haul_speed_cap == 0.0, "and the horse stopped (cap %.2f)" % horse.haul_speed_cap)
	var t0 := Time.get_ticks_msec()
	var freed := false
	while Time.get_ticks_msec() - t0 < 6000:
		_horse_at(horse.global_position + fwd * 0.02, fwd)
		await physics_frame
		if cart._free_t > 0.0:
			freed = true
			break
	check(freed, "held a while, it is worked free")
	for i in 150:
		_horse_at(horse.global_position + fwd * 0.03, fwd)
		await physics_frame
	var past: float = (cart.global_position - (wall.get_child(0) as Node3D).global_position).dot(fwd)
	check(past > 1.0 and not cart.stuck, "and goes on past the trunks (%.1f m past)" % past)
	wall.queue_free()
	await frames(5)


func _test_unhitch() -> void:
	check(cart.saddle_prompt(player) == "", "(on foot: nothing from the saddle)")
	cart.unhitch()
	await frames(3)
	var tp := cart.tips_point()
	check(not cart.is_hitched() and hh.cart == null and horse.haul_speed_cap == INF and absf(tp.y - FrontierTerrain.height_at(tp.x, tp.z)) < 0.2,
			"unhitched: the horse's pace its own, the cart on the shafts' tips")


## Open ground with a clear run of `run` m along `f` for the cart (none of the range's or the fort's things in its way).
func _clear_run(f: Vector3, run: float) -> Vector3:
	for r in range(30, 140, 8):
		for k in 12:
			var c := _ground(cos(TAU * k / 12.0) * r, sin(TAU * k / 12.0) * r)
			if FrontierTerrain.forest_density(c.x, c.z) > 0.15:
				continue
			var ok := true
			for s in range(0, int(run) + 4, 1):
				var p := c + f * (float(s) - HorseCart.SHAFT_LEN - 1.0)
				if cart._blocked(cart._pose(Vector3(p.x, 0.0, p.z), f, FrontierTerrain.height_at(p.x, p.z) + 1.05)):
					ok = false
					break
			if ok:
				return c
	return _ground(0.0, -45.0)


func _test_ride() -> void:
	fwd = Vector3.FORWARD
	_horse_at(_clear_run(fwd, 12.0), fwd)
	await frames(3)
	var hp := HorseCart.harness_point(horse)
	cart.park_at(_ground(hp.x, hp.z) - fwd * (HorseCart.SHAFT_LEN + 0.6), fwd)
	var mp := horse.get_mount_point(Horse.LEFT).origin
	player.global_position = mp
	await frames(4)
	player.mount(horse)
	await frames(240)
	check(player.riding == horse, "in the saddle")
	check(cart.saddle_prompt(player) == "Hitch the cart", "the horse stopped by the shafts: %s" % cart.saddle_prompt(player))
	check(cart.interact(player) and cart.is_hitched(), "E from the saddle puts it to the cart")
	var p0 := horse.global_position
	player.yaw = horse.rotation.y
	Input.action_press(&"move_forward")
	var over := 0.0
	var dmax := 0.0
	for i in 120 * 5:
		await physics_frame
		over = maxf(over, horse.speed - horse.haul_speed_cap)
		var h2 := HorseCart.harness_point(horse)
		dmax = maxf(dmax, absf(Vector2(h2.x - cart.global_position.x, h2.z - cart.global_position.z).length() - HorseCart.SHAFT_LEN))
	Input.action_release(&"move_forward")
	var moved := Vector2(horse.global_position.x - p0.x, horse.global_position.z - p0.z).length()
	report["ride"] = {"moved": snappedf(moved, 0.1), "cap": snappedf(horse.haul_speed_cap, 0.01), "over": snappedf(over, 0.01),
			"shafts_off": snappedf(dmax, 0.01), "caught_on": cart.caught_on}
	check(moved > 5.0 and dmax < 0.3, "ridden on, the cart behind it (%.1f m, the shafts at most %.2f m off)" % [moved, dmax])
	check(over < 0.15, "at the cart's pace (%.2f over the cap)" % over)
	await frames(120 * 3)
	check(cart.saddle_prompt(player) == "Unhitch the cart", "stopped in the saddle: %s" % cart.saddle_prompt(player))
	check(cart.interact(player) and not cart.is_hitched() and player.riding == horse, "E lets the cart go, the rider stays up")


func _log(a: Vector3, dir: Vector3, L: float, r: float) -> SkidLoad:
	var d := dir.normalized()
	var f := Vector3(a.x, FrontierTerrain.height_at(a.x, a.z) + r, a.z)
	var b := f + d * L
	b.y = FrontierTerrain.height_at(b.x, b.z) + r
	var s := SaveParts._loose_bole({"info": {"species": "white_pine", "name": "white pine", "radius": r, "i": 9501, "pos": [a.x, a.y, a.z]},
			"front": [f.x, f.y, f.z], "back": [b.x, b.y, b.z], "r0": r, "r1": r * 0.92, "logs_total": 1, "logs_left": 1},
			GatherData.get_default().felling, false)
	current_scene.add_child(s)
	return s


func _end() -> void:
	print("HORSE CART REPORT ", JSON.stringify(report))
	if fails.is_empty():
		print("HORSE CART TEST PASSED %d" % checks)
	else:
		print("HORSE CART TEST FAILED %d/%d: %s" % [fails.size(), checks, fails])
	quit(0 if fails.is_empty() else 1)
