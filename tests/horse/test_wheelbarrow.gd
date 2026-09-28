extends SceneTree
## Headless tests of the wheelbarrow (scripts/horse/wheelbarrow.gd; data/horse/haul.json "wheelbarrow"), in the real
## level with the real keys:
##
##   Godot --headless --path . -s tests/horse/test_wheelbarrow.gd
##
##   data     the pace falls with the load, never to a stand; a doe in it goes faster than a doe dragged
##   push     one stands by the fort; E at its handles: the gun on the back, both hands on the grips; W pushes it
##            before the player at the empty pace (no sprint), the wheel on the ground, the grips at the hands
##   stop     pushed into a trunk it stops there (it does not go through)
##   down     E sets it down on its wheel and legs, the gun back in the hands
##   deer     a doe by it: "Put the deer in the wheelbarrow"; pushed with her in it, faster than dragging her;
##            "Tip out the deer": on the ground beside it, to be skinned
##   log      a log length by it goes in, slower to push; tipped out it lies loose
##   pack     pack things go in (the chest screen's side) and show in the bed; the prompts say so; E with nothing by it
##            opens the screen; Unload everything / Load everything move it all at once
##   save     where it stands and what is in it come back
##   let go   a jump sets it down
##
## The animals are CC0 stand-in models; the barrow is the project's own.

var checks := 0
var fails: Array[String] = []
var report := {}
var player: FrontierPlayer
var it: PlayerInteractor
var w: Wheelbarrow
var palms := [Vector3.INF, Vector3.INF]


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	_test_data()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene else null
	if player == null:
		check(false, "the level has a player")
		_end()
		return
	player.ignore_mouse_capture = true
	it = player.interactor
	await frames(60)
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Horse).global_position = _ground(-60.0, 60.0)
	w = Wheelbarrow.find(self)
	check(w != null and w.global_position.distance_to(player.global_position) < 8.0, "a wheelbarrow stands by the start")
	if w == null:
		_end()
		return
	var sk := player.skeleton
	var lp := sk.find_bone("l_palm")
	var rp := sk.find_bone("r_palm")
	sk.skeleton_updated.connect(func() -> void:
		palms[0] = sk.global_transform * sk.get_bone_global_pose(lp).origin
		palms[1] = sk.global_transform * sk.get_bone_global_pose(rp).origin)
	await _test_push()
	await _test_deer()
	await _test_log()
	await _test_pack_and_save()
	await _test_jump()
	_end()


func _end() -> void:
	print("REPORT ", JSON.stringify(report))
	if fails.is_empty():
		print("WHEELBARROW TEST PASSED %d" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("WHEELBARROW TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


func _test_data() -> void:
	var last := INF
	var mono := true
	for i in 60:
		var c := Wheelbarrow.pace_for(float(i) * 20.0)
		mono = mono and c <= last + 1e-6 and c > 0.0
		last = c
	check(mono and Wheelbarrow.pace_for(0.0) > 2.0, "the pace falls with the load, never to a stand")
	check(Wheelbarrow.pace_for(55.0) > FootDrag.cap_for(55.0 * 0.5) + 0.3, "a doe in the barrow (%.2f m/s) goes faster than dragged (%.2f)" % [Wheelbarrow.pace_for(55.0), FootDrag.cap_for(27.5)])


func _put(at: Vector3, look: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	var d := look - at
	d.y = 0.0
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-18.0)


func _tap(action: StringName, n := 4) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)
	await frames(3)


## To the handles, looking along the barrow, and E; waits for the gun to go on the back.
func _take() -> void:
	for i in 360:
		if not player.is_switching():
			break
		await physics_frame
	var fwd := w.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var g := w.grips_point()
	_put(g - fwd * 0.45, g + fwd * 2.0)
	await frames(8)
	await _tap(&"interact")
	for i in 200:
		if w.is_pushed():
			break
		await physics_frame
	await frames(20)


## Beside the bed looking at it.
func _at_bed(side := 1.0) -> void:
	var b := w.bed_point()
	var s := -w.global_basis.x * side
	s.y = 0.0
	_put(b + s.normalized() * 1.1, b)
	await frames(8)


func _walk(secs: float) -> Dictionary:
	var p0 := player.global_position
	var vmax := 0.0
	var sprinted := false
	var grip_err := 0.0
	var palm_err := 0.0
	var wheel_err := 0.0
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in int(secs * 120.0):
		await physics_frame
		if i > 90:
			vmax = maxf(vmax, player.horizontal_speed())
			var fwd := -player.global_basis.z
			fwd.y = 0.0
			var want := player.global_position + fwd.normalized() * Wheelbarrow.GRIP_FWD + Vector3.UP * Wheelbarrow.GRIP_H
			grip_err = maxf(grip_err, w.grips_point().distance_to(want))
			var ax := w.global_position
			wheel_err = maxf(wheel_err, absf(ax.y - Wheelbarrow.WHEEL_R - FrontierTerrain.height_at(ax.x, ax.z)))
			if i % 30 == 0 and palms[0] != Vector3.INF:
				var gl := w.global_transform * Vector3(Wheelbarrow.GRIP_W, Wheelbarrow.GRIP_UP, -Wheelbarrow.GRIP_BACK)
				var gr := w.global_transform * Vector3(-Wheelbarrow.GRIP_W, Wheelbarrow.GRIP_UP, -Wheelbarrow.GRIP_BACK)
				palm_err = maxf(palm_err, maxf(palms[0].distance_to(gl), palms[1].distance_to(gr)))
		sprinted = sprinted or player.is_sprinting
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	await frames(20)
	var d := player.global_position - p0
	return {"moved": Vector2(d.x, d.z).length(), "vmax": vmax, "sprinted": sprinted, "grip_err": grip_err, "palm_err": palm_err, "wheel_err": wheel_err}


func _test_push() -> void:
	var fwd := w.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var g := w.grips_point()
	_put(g - fwd * 0.45, g + fwd * 2.0)
	await frames(8)
	check(it.target == w and it._label.text.ends_with("Push the wheelbarrow"), "at its handles: %s" % it._label.text)
	check(not player.hands_free, "the musket in the hands")
	await _tap(&"interact")
	for i in 200:
		if w.is_pushed():
			break
		await physics_frame
	await frames(20)
	check(w.is_pushed() and player.pushing == w and player.hands_free, "E: both hands on it, the musket on the back")
	check(it.target == w and it._label.text.ends_with("Set the wheelbarrow down"), "pushing, E says: %s" % it._label.text)
	# out into the field north-east of the start (open ground)
	player.yaw = atan2(-0.3, 1.0)
	var r := await _walk(3.0)
	report["push_empty"] = {"moved": snappedf(r.moved, 0.1), "vmax": snappedf(r.vmax, 0.01), "cap": snappedf(w.cap, 0.01),
			"grip_err": snappedf(r.grip_err, 0.01), "palm_err": snappedf(r.palm_err, 0.01), "wheel_err": snappedf(r.wheel_err, 0.02)}
	check(r.moved > 4.0 and r.vmax <= w.cap + 0.15, "W pushes it at the empty pace (%.1f m in 3 s, at most %.2f m/s)" % [r.moved, r.vmax])
	check(not r.sprinted, "no sprint")
	check(r.grip_err < 0.05 and r.wheel_err < 0.12, "before the player: the grips at the hands' place, the wheel on the ground")
	check(r.palm_err < 0.12, "both palms on the grips (%.2f m off at most)" % r.palm_err)
	# into a trunk: it stops there
	var open_at := w.global_position
	var open_fwd := w.global_basis.z
	var tree := _near_tree(player.global_position, 150.0)
	check(tree != Vector3.INF, "a standing tree to push into")
	if tree != Vector3.INF:
		var to := tree - player.global_position
		to.y = 0.0
		_put(tree - to.normalized() * 4.5, tree)
		await frames(10)
		var rt := await _walk(4.0)
		var ax := w.global_position
		var d := Vector2(ax.x - tree.x, ax.z - tree.z).length()
		report["trunk"] = {"axle_to_trunk": snappedf(d, 0.02), "walked": snappedf(rt.moved, 0.1)}
		check(rt.moved < 3.5 and d > 0.15, "pushed into a trunk it stops (the axle %.2f m from its middle; %.1f m walked)" % [d, rt.moved])
	await _tap(&"interact")
	await frames(20)
	check(not w.is_pushed() and player.pushing == null and w.last_set_down == "e", "E sets it down")
	w.park_at(open_at, open_fwd)                 # back out in the open for the rest
	var legs := w.global_transform * Vector3(0.0, -Wheelbarrow.WHEEL_R, Wheelbarrow.LEG_Z)
	check(absf(legs.y - FrontierTerrain.height_at(legs.x, legs.z)) < 0.12, "on its wheel and legs")
	for i in 360:
		if not player.hands_free and not player.is_switching():
			break
		await physics_frame
	check(not player.hands_free, "the musket back in the hands")


func _near_tree(p: Vector3, r: float) -> Vector3:
	var vh := VegHarvest.find(self)
	var best := Vector3.INF
	var bd := INF
	for i in vh.lay.tree_pos.size():
		if vh.lay.tree_collider[i] == 0:
			continue
		var t: Vector3 = vh.lay.tree_pos[i]
		var d := Vector2(t.x - p.x, t.z - p.z).length()
		if d < r and d > 6.0 and d < bd:
			bd = d
			best = t
	return best


func _dead(species: String, at: Vector3) -> WildAnimal:
	var a := WildAnimal.new()
	a.setup(species, null, null, 11)
	a.name = "Dead_%s" % species
	current_scene.add_child(a)
	a.global_position = at
	await frames(2)
	a.apply_hit(9999.0, a.global_position + Vector3.UP * 0.6, Vector3.RIGHT, null, "vitals")
	await frames(int(1.7 * 120))
	return a


func _test_deer() -> void:
	var side := -w.global_basis.x
	side.y = 0.0
	var doe := await _dead("deer", _ground(w.bed_point().x, w.bed_point().z) + side.normalized() * 1.4)
	await _at_bed(-1.0)                   # the other side from her, looking at the bed
	check(it.target == w.bed and it._label.text.ends_with("Put the deer in the wheelbarrow"), "a doe by it: %s" % it._label.text)
	await _tap(&"interact")
	await frames(10)
	check(w.load_kind == "carcass" and w.load_node == doe and doe.get_meta(&"on_chain", false), "E puts her in the bed")
	# her body (between the neck and the rump, as she lies) over the bed, not her feet' point; the rump short of the hands
	var ends := CarcassLoad._ends_global(doe)
	var mid: Vector3 = (ends[0] + ends[1]) * 0.5
	var rump_z := (w.global_transform.affine_inverse() * ends[1]).z
	var neck_z := (w.global_transform.affine_inverse() * ends[0]).z
	check(mid.distance_to(w.bed_point()) < 0.7 and neck_z > rump_z, "she lies in the bed, her head toward the wheel (%.2f m off its middle)" % mid.distance_to(w.bed_point()))
	check(rump_z > -Wheelbarrow.GRIP_BACK + 0.2, "her rump short of the hands on the grips (%.2f; the grips at %.2f)" % [rump_z, -Wheelbarrow.GRIP_BACK])
	await _take()
	check(w.is_pushed(), "pushed with her in it")
	var p0 := doe.global_position
	var r := await _walk(3.0)
	var moved := Vector2(doe.global_position.x - p0.x, doe.global_position.z - p0.z).length()
	report["push_doe"] = {"moved": snappedf(moved, 0.1), "cap": snappedf(w.cap, 0.01), "drag_cap": snappedf(FootDrag.cap_for(27.5), 0.01)}
	check(moved > 3.0 and w.cap > FootDrag.cap_for(27.5) + 0.3, "she goes with it, faster than dragged (%.1f m in 3 s; %.2f vs %.2f m/s)" % [moved, w.cap, FootDrag.cap_for(27.5)])
	await _tap(&"interact")
	await frames(20)
	await _at_bed()
	check(it.target == w.bed and it._label.text.ends_with("Tip out the deer"), "at the bed: %s" % it._label.text)
	await _tap(&"interact")
	await frames(10)
	var gy := FrontierTerrain.height_at(doe.global_position.x, doe.global_position.z)
	check(w.load_node == null and not doe.get_meta(&"on_chain", false) and doe.is_in_group(PlacedWeapon.GROUP) and absf(doe.global_position.y - gy) < 0.2,
			"tipped out: on the ground beside it, to be skinned")
	doe.queue_free()
	await frames(5)


func _log(a: Vector3, dir: Vector3, L: float, r: float) -> SkidLoad:
	var d := dir.normalized()
	var f := Vector3(a.x, FrontierTerrain.height_at(a.x, a.z) + r, a.z)
	var b := f + d * L
	b.y = FrontierTerrain.height_at(b.x, b.z) + r
	var s := SaveParts._loose_bole({"info": {"species": "white_pine", "name": "white pine", "radius": r, "i": 9500, "pos": [a.x, a.y, a.z]},
			"front": [f.x, f.y, f.z], "back": [b.x, b.y, b.z], "r0": r, "r1": r * 0.92, "logs_total": 1, "logs_left": 1},
			GatherData.get_default().felling, false)
	current_scene.add_child(s)
	return s


func _test_log() -> void:
	var side := -w.global_basis.x
	side.y = 0.0
	side = side.normalized()
	var fwd := w.global_basis.z
	fwd.y = 0.0
	var s := _log(w.bed_point() + side * 1.4 - fwd.normalized() * 1.2, fwd, 2.4, 0.2)
	await frames(60)
	await _at_bed(-1.0)
	check(it.target == w.bed and it._label.text.ends_with("Put the log in the wheelbarrow"), "a log length by it: %s" % it._label.text)
	await _tap(&"interact")
	await frames(10)
	check(w.load_kind == "log" and w.load_node == s and s.laid, "E puts it in the bed")
	await _take()
	var r := await _walk(2.0)
	report["push_log"] = {"kg": roundi(s.mass_kg), "cap": snappedf(w.cap, 0.01), "moved": snappedf(r.moved, 0.1)}
	check(w.cap < Wheelbarrow.pace_for(55.0) and r.moved > 1.0, "slower with the log (%.2f m/s, %.1f m in 2 s)" % [w.cap, r.moved])
	await _tap(&"interact")
	await frames(20)
	await _at_bed()
	await _tap(&"interact")
	await frames(60)
	check(w.load_node == null and not s.laid and s.front.distance_to(w.bed_point()) < 3.5, "tipped out it lies loose beside it")
	s.queue_free()
	await frames(5)


func _test_pack_and_save() -> void:
	var inv := InventoryState.from_player(player)
	inv.add("stone", 5)
	player.inventory_pack = inv.pack.duplicate(true)
	inv = InventoryState.from_player(player)
	var got := w.put(inv, "stone", 5)
	player.inventory_pack = inv.pack.duplicate(true)
	check(got == 5 and w.count_of("stone") == 5 and not w.accepts("felling_axe"), "pack things go in (5 stone); the tools stay in the pack")
	await _at_bed()
	check(it._label.text.ends_with("Load the wheelbarrow (5 things in it)"), "at the bed: %s" % it._label.text)
	await _tap(&"interact")
	await process_frame
	var screens := root.find_children("*", "ChestScreen", true, false)
	check(screens.size() == 1 and (screens[0] as ChestScreen).chest == w, "E opens the chest screen on it")
	check(w.goods_shown == 5, "the stones show in the bed (%d)" % w.goods_shown)
	if screens.size() == 1:
		var sc := screens[0] as ChestScreen
		var stone0 := InventoryState.from_player(player).pack_count("stone")
		var out_n := sc.move_all(false)
		check(out_n == 5 and w.items.is_empty() and InventoryState.from_player(player).pack_count("stone") == stone0 + 5 and w.goods_shown == 0,
				"Unload everything: all of it back in the pack (%d)" % out_n)
		inv = InventoryState.from_player(player)
		inv.add("firewood", 3)
		player.inventory_pack = inv.pack.duplicate(true)
		var in_n := sc.move_all(true)
		check(w.count_of("stone") >= 5 and w.count_of("firewood") == 3 and InventoryState.from_player(player).pack_count("stone") == 0,
				"Load everything: all that goes in, in (%d)" % in_n)
		# back to the five stones for the save
		sc.move_all(false)
		inv = InventoryState.from_player(player)
		w.put(inv, "stone", 5)
		player.inventory_pack = inv.pack.duplicate(true)
	for sc in screens:
		sc.queue_free()
	paused = false
	await frames(5)
	check(absf(w.load_kg() - 25.0) < 0.01, "its load: 25 kg of stone")
	var d := SaveParts.save_wheelbarrow(current_scene)
	var at0 := w.global_position
	w.items.clear()
	w.park_at(at0 + Vector3(5.0, 0.0, 5.0), Vector3.FORWARD)
	SaveParts.load_wheelbarrow(current_scene, d)
	check(w.global_position.distance_to(at0) < 0.1 and w.count_of("stone") == 5, "saved: where it stood and what is in it")
	w.items.clear()


func _test_jump() -> void:
	await _take()
	check(w.is_pushed(), "taken again")
	await _tap(&"jump")
	await frames(5)
	check(not w.is_pushed() and w.last_set_down == "jump", "a jump sets it down (%s)" % w.last_set_down)
