extends SceneTree
## The horse cart through a save (SaveParts "cart"; user 2026-09-27: "lets merge and do this"), headless, the level with
## its saves and wildlife, saved to the quick slot and loaded (the level rebuilt, the save applied on top):
##
##   Godot --headless --path . -s tests/save/test_cart_save.gd -- save=on wildlife=on
##
##   hitched  the cart in the horse's shafts on open ground, swung a little off its line, goods, a dead deer and two
##            logs in it: after the load it stands where it stood, still in the horse's shafts, the goods, the deer and
##            the logs in the bed in the order they went in; the horse walks on and it all goes along
##   barrow   unhitched, the wheelbarrow in it with stones: after the load the cart rests where it stood, the wheelbarrow
##            in the bed with its stones, not to be pushed there
## Ends with "CART SAVE TEST PASSED <n>" or "CART SAVE TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var report := {}
var sg: SaveGame
var player: FrontierPlayer
var horse: Horse
var cart: HorseCart
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


func _grab() -> void:
	sg = SaveGame.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene else null
	cart = HorseCart.find(self)
	var hs := current_scene.find_children("*", "Horse", true, false) if current_scene else []
	horse = hs[0] as Horse if not hs.is_empty() else null
	if player:
		player.ignore_mouse_capture = true


func _horse_at(p: Vector3, f: Vector3) -> void:
	horse.global_position = _ground(p.x, p.z)
	horse.rotation = Vector3(0.0, atan2(-f.x, -f.z), 0.0)
	horse.velocity = Vector3.ZERO


## The horse walked `dist` m along `fwd` (turning `turn_deg` on the way), at a walk whatever the physics rate.
func _walk(dist: float, turn_deg := 0.0) -> void:
	var n := ceili(dist / (1.5 / Engine.physics_ticks_per_second))
	for i in n:
		fwd = fwd.rotated(Vector3.UP, deg_to_rad(turn_deg) / n)
		_horse_at(horse.global_position + fwd * dist / n, fwd)
		await physics_frame


## `p` in the cart's frame.
func _local(p: Vector3) -> Vector3:
	return cart.global_transform.affine_inverse() * p


func _in_bed(p: Vector3) -> bool:
	var l := _local(p)
	return absf(l.x) < 0.8 and l.z > HorseCart.BED_Z.x - 0.4 and l.z < HorseCart.BED_Z.y + 0.4 and l.y > 0.0 and l.y < 1.6


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(60)
	_grab()
	check(sg != null and cart != null and horse != null and current_scene.get_node_or_null("Wildlife") != null,
			"the level has its saves, the cart, the horse and the wildlife (save=on wildlife=on)")
	if sg == null or cart == null or horse == null:
		_end()
		return
	check("cart" in SaveGame.PARTS and SaveGame.PARTS.find("cart") > SaveGame.PARTS.find("wheelbarrow")
			and SaveGame.PARTS.find("cart") > SaveGame.PARTS.find("horse") and SaveGame.PARTS.find("cart") > SaveGame.PARTS.find("wildlife"),
			"the cart's part is saved, after the horse, the wildlife and the wheelbarrow")
	await _test_hitched()
	await _test_barrow()
	_end()


# --- Hitched, loaded ----------------------------------------------------------------------------------------

func _test_hitched() -> void:
	# out on the range lane, open ground, in the shafts, drawn on a few metres round a gentle turn
	fwd = Vector3.FORWARD
	cart.park_at(_ground(0.0, -70.0), fwd)
	await frames(2)
	var tips := cart.tips_point()
	_horse_at(Vector3(tips.x, 0.0, tips.z) - fwd * 0.4, fwd)
	await frames(3)
	check(cart.hitch(horse), "the horse put to the cart")
	await _walk(6.0, 20.0)
	await frames(4)
	# goods
	var inv := InventoryState.from_player(player)
	inv.add("stone", 10)
	inv.add("firewood", 5)
	cart.put(inv, "stone", 10)
	cart.put(inv, "firewood", 5)
	# a deer of the spawner's, brought behind the tailboard and shot (the wolves far off)
	var sp := current_scene.get_node("Wildlife") as WildlifeSpawner
	var deer: WildAnimal = null
	for a in sp.animals():
		if a.species == "wolf":
			a.global_position = _ground(285.0, 285.0)
			a.awareness = 0.0
		elif a.species == "deer" and deer == null and not a.is_dead():
			deer = a
	check(deer != null, "a deer from the spawner")
	if deer == null:
		return
	var back := -cart.forward()
	var side := Vector3.UP.cross(back).normalized()
	var tail := cart.tail_point()
	deer.global_position = _ground(tail.x + back.x * 1.4 + side.x, tail.z + back.z * 1.4 + side.z)
	deer.set_active(true)
	await frames(2)
	deer.apply_hit(9999.0, deer.global_position + Vector3.UP * 0.6, Vector3.RIGHT, player, "vitals")
	await frames(int(2.5 * Engine.physics_ticks_per_second))
	check(cart.put_carcass(deer), "the deer goes in the cart")
	# two logs by the tailboard, in
	for k in 2:
		var s := _log(cart.tail_point() + back * 1.5 - side * (1.2 + 0.6 * k), side, 2.4, 0.16, 9601 + k)
		await frames(20)
		check(cart.put_log(s), "a log goes in (%d)" % (k + 1))
	await frames(int(1.0 * Engine.physics_ticks_per_second))
	var want := {"at": cart.global_position, "yaw_off": rad_to_deg(HorseCart._horse_fwd(horse).angle_to(cart.forward())),
			"kinds": cart.loads.map(func(l: Dictionary) -> String: return String(l.kind)), "kg": cart.load_kg()}
	report["saved"] = {"yaw_off": snappedf(float(want.yaw_off), 0.1), "kinds": want.kinds, "kg": roundi(float(want.kg))}
	check(float(want.yaw_off) > 3.0, "swung off the horse's line before the save (%.1f deg)" % float(want.yaw_off))
	check(sg.save_game("quick") == OK, "saved (quick)")
	var d: Dictionary = (SaveGame.read_slot("quick").get("parts", {}) as Dictionary).get("cart", {})
	check(bool(d.get("hitched", false)) and (d.get("loads", []) as Array).size() == 3 and (d.get("items", []) as Array).size() == 2,
			"the save has the cart: in the shafts, three things in the bed, two kinds of goods")
	await _load()
	check(cart != null and horse != null, "a new level, its cart and horse")
	if cart == null or horse == null:
		return
	check(cart.global_position.distance_to(want.at) < 0.1, "the cart where it stood (%.2f m off)" % cart.global_position.distance_to(want.at))
	check(cart.is_hitched() and cart.horse == horse and HorseCart.haul_of(horse).cart == cart, "still in the horse's shafts")
	var yaw_off := rad_to_deg(HorseCart._horse_fwd(horse).angle_to(cart.forward()))
	check(absf(yaw_off - float(want.yaw_off)) < 1.5, "swung as it was (%.1f deg, was %.1f)" % [yaw_off, float(want.yaw_off)])
	check(cart.count_of("stone") == 10 and cart.count_of("firewood") == 5, "the goods in it (%d stone, %d firewood)" % [cart.count_of("stone"), cart.count_of("firewood")])
	var kinds: Array = cart.loads.map(func(l: Dictionary) -> String: return String(l.kind))
	check(kinds == want.kinds, "the deer and the logs back in the bed, in the order they went in (%s)" % str(kinds))
	check(absf(cart.load_kg() - float(want.kg)) < 2.0, "the same load (%.0f kg, was %.0f)" % [cart.load_kg(), float(want.kg)])
	# (a reloaded deer lies as it fell, WildAnimal.lie_dead: in the bed at once)
	await frames(10)
	var ok_bed := true
	for l: Dictionary in cart.loads:
		var n := l.node as Node3D
		var p := (n as SkidLoad).mid() if n is SkidLoad else n.global_position
		if String(l.kind) == "carcass":
			var ends := CarcassLoad._ends_global(n)
			p = (ends[0] + ends[1]) * 0.5
		ok_bed = ok_bed and _in_bed(p)
		report["bed_" + String(l.kind) + "_" + str(cart.loads.find(l))] = str(_local(p).snapped(Vector3.ONE * 0.01))
	check(ok_bed, "each lies in the bed")
	check(cart.loads.all(func(l: Dictionary) -> bool: return (l.node as Node).has_meta(&"on_chain") or (l.node as Node).has_meta(&"in_barrow")),
			"none offered to the axe, a chain or a pull while it rides")
	var deer2 := cart.loads[0].node as Node3D
	var p0 := deer2.global_position
	var c0 := cart.global_position
	await _walk(5.0)
	await frames(3)
	check(cart.global_position.distance_to(c0) > 4.0 and deer2.global_position.distance_to(p0) > 4.0,
			"the horse walks on: the cart and the deer go along (%.1f m)" % cart.global_position.distance_to(c0))


# --- The wheelbarrow in it ------------------------------------------------------------------------------------

func _test_barrow() -> void:
	cart.unhitch()
	while cart.take_out() != null:
		pass
	cart.items.clear()
	cart._refresh_goods()
	await frames(3)
	var w := Wheelbarrow.find(self)
	var back := -cart.forward()
	w.park_at(cart.tail_point() + back * 1.6, back)
	await frames(3)
	var inv := InventoryState.from_player(player)
	inv.add("stone", 5)
	w.put(inv, "stone", 5)
	check(cart.put_barrow(w), "unhitched, the wheelbarrow goes in with 5 stones")
	await frames(10)
	var at := cart.global_position
	check(sg.save_game("quick") == OK, "saved (quick)")
	await _load()
	w = Wheelbarrow.find(self)
	check(cart != null and w != null, "a new level, its cart and wheelbarrow")
	if cart == null or w == null:
		return
	check(cart.global_position.distance_to(at) < 0.1 and not cart.is_hitched() and HorseCart.haul_of(horse).cart == null,
			"the cart where it stood, resting, no horse in it (%.2f m off)" % cart.global_position.distance_to(at))
	await frames(10)
	check(cart.has_barrow() and w.has_meta(&"in_cart") and _in_bed(w.global_position), "the wheelbarrow in the bed")
	check(w.count_of("stone") == 5, "with its stones (%d)" % w.count_of("stone"))
	check(not w.start(player) and not w.is_in_group(PlacedWeapon.GROUP), "not to be pushed there")


# --- Save / load ----------------------------------------------------------------------------------------------

## load_slot("quick") and wait for the new level with the save applied (as tests/save/test_save_game.gd).
func _load() -> void:
	var old := sg
	check(sg.load_slot("quick"), "load_slot starts the load")
	for i in 60 * 10:
		await process_frame
		var s2 := SaveGame.find(self)
		if s2 != null and s2 != old and not s2.loading and s2.level != null and s2.level.is_inside_tree():
			await frames(12)
			break
	_grab()
	await frames(5)
	check(sg != null and sg != old and not sg.loading, "a new level with the save applied")


func _log(a: Vector3, dir: Vector3, L: float, r: float, id: int) -> SkidLoad:
	var d := dir.normalized()
	var f := Vector3(a.x, FrontierTerrain.height_at(a.x, a.z) + r, a.z)
	var b := f + d * L
	b.y = FrontierTerrain.height_at(b.x, b.z) + r
	var s := SaveParts._loose_bole({"info": {"species": "white_pine", "name": "white pine", "radius": r, "i": id, "pos": [a.x, a.y, a.z]},
			"front": [f.x, f.y, f.z], "back": [b.x, b.y, b.z], "r0": r, "r1": r * 0.92, "logs_total": 1, "logs_left": 1},
			GatherData.get_default().felling, false)
	current_scene.add_child(s)
	return s


func _end() -> void:
	# the test's saves (in SaveGame.TEST_DIR, never the player's) go with it
	if SaveGame.dir() == SaveGame.TEST_DIR:
		for s in SaveGame.SLOTS:
			DirAccess.remove_absolute(SaveGame.dir() + String(s) + ".json")
	print("CART SAVE REPORT ", JSON.stringify(report))
	if fails.is_empty():
		print("CART SAVE TEST PASSED %d" % checks)
	else:
		print("CART SAVE TEST FAILED %d/%d: %s" % [fails.size(), checks, fails])
	quit(0 if fails.is_empty() else 1)
