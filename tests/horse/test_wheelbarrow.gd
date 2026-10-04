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
##   elbows   pushing it straight, turning, stopping and starting and over a ridge, every frame the elbows hold their
##            side (down and a little out), move only a little a frame, stay a little bent; the palms on the grips
##            (the user 2026-10-03: "also when we push the wheel barrow fix the elbows so they dont do a chicken dance")
##
## The animals are CC0 stand-in models; the barrow is the project's own.

var checks := 0
var fails: Array[String] = []
var report := {}
var player: FrontierPlayer
var it: PlayerInteractor
var w: Wheelbarrow
var palms := [Vector3.INF, Vector3.INF]
## Where the barrow stood at the start (its axle, its forward): the elbows' push goes out from there.
var barrow_start := []
## The elbows' push: a row a frame ({t, phase, l: {...}, r: {...}}; _elbow_row) and the phase being pushed.
var elbow_rows: Array = []
var elbow_phase := ""
var _elbow_t := 0.0


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
	barrow_start = [w.global_position, w.global_basis.z]
	await _test_push()
	await _test_deer()
	await _test_log()
	await _test_pack_and_save()
	await _test_jump()
	await _test_elbows()
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
	var grip_fwd := Vector2(INF, -INF)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in int(secs * 120.0):
		await physics_frame
		if i > 90:
			vmax = maxf(vmax, player.horizontal_speed())
			var fwd := -player.global_basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			# (where the player's arms hold the grips: before the feet, beside and over them; Wheelbarrow.ELBOW_BEND_DEG)
			var want := player.global_position + fwd * w.grip_fwd + fwd.cross(Vector3.UP) * w.grip_side + Vector3.UP * w.grip_h
			grip_err = maxf(grip_err, w.grips_point().distance_to(want))
			grip_fwd = Vector2(minf(grip_fwd.x, w.grip_fwd), maxf(grip_fwd.y, w.grip_fwd))
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
	return {"moved": Vector2(d.x, d.z).length(), "vmax": vmax, "sprinted": sprinted, "grip_err": grip_err, "palm_err": palm_err, "wheel_err": wheel_err,
			"grip_fwd": grip_fwd}


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
			"grip_err": snappedf(r.grip_err, 0.01), "palm_err": snappedf(r.palm_err, 0.01), "wheel_err": snappedf(r.wheel_err, 0.02),
			"grip_fwd": [snappedf(r.grip_fwd.x, 0.01), snappedf(r.grip_fwd.y, 0.01)]}
	check(r.moved > 4.0 and r.vmax <= w.cap + 0.15, "W pushes it at the empty pace (%.1f m in 3 s, at most %.2f m/s)" % [r.moved, r.vmax])
	check(not r.sprinted, "no sprint")
	check(r.grip_err < 0.05 and r.wheel_err < 0.12, "before the player: the grips at the hands' place, the wheel on the ground")
	check(r.grip_fwd.x >= Wheelbarrow.GRIP_FWD_MIN and r.grip_fwd.y <= Wheelbarrow.GRIP_FWD_MAX and r.grip_fwd.y > Wheelbarrow.GRIP_FWD + 0.1,
			"at the jog the grips go further before the feet, where the leaning arms reach them (%.2f-%.2f m)" % [r.grip_fwd.x, r.grip_fwd.y])
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


# --- The elbows while pushing --------------------------------------------------------------------------------

## The elbows (the user 2026-10-03: "also when we push the wheel barrow fix the elbows so they dont do a chicken dance";
## before, under the jog's free arm swing, the left elbow swung 14 cm sideways over the strides, up to 6 cm in a frame,
## and up over the shoulder -> hand line, to 125 deg; the arms bent 70-105 deg): from the barrow's first place out into
## the field at its jog, straight, turning both ways, stopping and starting, over a low ridge. Every frame, each elbow
## about its shoulder -> palm line (skeleton space, "down" toward the hip joint on its side): its side stays down and
## out (never in across the body nor up over the line) and turns only a little a frame; it moves sideways only a little
## a frame and within a few cm over the jog's strides; the arm a little bent, standing and jogging; both palms on the
## grips.
const ELBOW_SIDE_DEG := Vector2(-10.0, 85.0)     ## the side's band (0 down toward the hip, + out, 90 level out)
const ELBOW_TURN_DPS := 360.0                    ## its fastest turn about the line (deg/s; 6 a 60 Hz frame)
const ELBOW_SWAY_MPS := 0.9                      ## its fastest sideways move against the shoulder (m/s; 1.5 cm a frame)
const ELBOW_JOG_SWAY_M := 0.05                   ## its sideways range over the jog's strides
const ARM_BEND_DEG := Vector2(5.0, 50.0)         ## the arm's bend, standing and jogging (deg off straight)
const ELBOW_PALM_M := 0.04                       ## a palm off its grip at most


func _test_elbows() -> void:
	if w.is_pushed():
		w.set_down("")
	for i in 600:                                 # (the jump's move off the body first: a move showing sets it down)
		if not (player.traversal and player.traversal.showing):
			break
		await physics_frame
	w.park_at(barrow_start[0], barrow_start[1])
	await frames(30)
	var fwd := w.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var g := w.grips_point()
	_put(g - fwd * 0.45, g + fwd * 2.0)
	await frames(8)
	w.start(player)                               # (taken directly: E's take is the push's check)
	for i in 400:
		if w.is_pushed():
			break
		await physics_frame
	await frames(20)
	check(w.is_pushed(), "taken for the elbows' push (%s)" % ("pushed" if w.is_pushed() else "set down: " + w.last_set_down))
	if not w.is_pushed():
		return
	player.yaw = atan2(-0.3, 1.0)                 # out into the field (open ground, as the push's)
	var sk := player.skeleton
	var ids := {}
	for s in ["l", "r"]:
		ids[s] = [sk.find_bone(s + "_shoulder"), sk.find_bone(s + "_elbow"), sk.find_bone(s + "_wrist"),
				sk.find_bone(s + "_palm"), sk.find_bone(s + "_upper_leg")]
	var rec := func() -> void:
		if elbow_phase != "" and w.is_pushed():
			_elbow_t += player.get_process_delta_time()
			elbow_rows.append({"t": _elbow_t, "phase": elbow_phase, "l": _elbow_row(sk, ids.l, "l"), "r": _elbow_row(sk, ids.r, "r")})
	sk.skeleton_updated.connect(rec)
	await frames(36)
	elbow_phase = "hold"
	await frames(72)
	elbow_phase = "straight"
	Input.action_press(&"move_forward")
	await frames(300)
	elbow_phase = "turn"
	for i in 288:
		player.yaw += deg_to_rad(70.0) / 120.0 * (1.0 if i < 144 else -1.0)
		await physics_frame
	elbow_phase = "stop"
	Input.action_release(&"move_forward")
	await frames(144)
	elbow_phase = "start"
	Input.action_press(&"move_forward")
	await frames(180)
	elbow_phase = "stop"
	Input.action_release(&"move_forward")
	await frames(72)
	# a low ridge across the way, 2.5 m before the wheel: the wheel and the feet go over it
	var f := -player.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var ridge := _ridge(w.global_position + f * 2.5, f)
	await frames(4)
	elbow_phase = "ridge"
	Input.action_press(&"move_forward")
	await frames(300)
	Input.action_release(&"move_forward")
	elbow_phase = ""
	sk.skeleton_updated.disconnect(rec)
	await frames(20)
	ridge.queue_free()
	_elbow_checks()


## A low ridge (0.14 m high, 1.1 m along the way, 2 m across) at `at` (on the ground) across `f`.
func _ridge(at: Vector3, f: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ElbowRidge"
	var cs := CollisionShape3D.new()
	var sh := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for x in [-1.0, 1.0]:
		pts.append_array([Vector3(x, -0.05, -0.55), Vector3(x, -0.05, 0.55), Vector3(x, 0.14, 0.0)])
	sh.points = pts
	cs.shape = sh
	body.add_child(cs)
	current_scene.add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, atan2(f.x, f.z)), Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z))
	return body


## One arm now (skeleton space: the rig faces +Z, its left is +X): the elbow's side about the shoulder -> palm line
## (deg; 0 toward the hip, + out), its sideways place against the shoulder (m, + out), the arm's bend (deg off straight)
## and the palm off its grip (m).
func _elbow_row(sk: Skeleton3D, b: Array, s: String) -> Dictionary:
	var sh := sk.get_bone_global_pose(b[0]).origin
	var el := sk.get_bone_global_pose(b[1]).origin
	var wr := sk.get_bone_global_pose(b[2]).origin
	var pa := sk.get_bone_global_pose(b[3]).origin
	var hip := sk.get_bone_global_pose(b[4]).origin
	var sgn := 1.0 if s == "l" else -1.0
	var d := (pa - sh).normalized()
	var off := (el - sh) - d * (el - sh).dot(d)
	var down := ((hip - sh) - d * (hip - sh).dot(d)).normalized()
	var out := d.cross(down)
	if out.x * sgn < 0.0:
		out = -out
	var grip := w.global_transform * Vector3(Wheelbarrow.GRIP_W * sgn, Wheelbarrow.GRIP_UP, -Wheelbarrow.GRIP_BACK)
	return {"side": rad_to_deg(atan2(off.dot(out), off.dot(down))), "x": (el.x - sh.x) * sgn,
			"bend": rad_to_deg((el - sh).angle_to(wr - el)), "palm": (sk.global_transform * pa).distance_to(grip)}


func _elbow_checks() -> void:
	var side := Vector2(INF, -INF)
	var turn := 0.0
	var sway := 0.0
	var jog_x := {"l": Vector2(INF, -INF), "r": Vector2(INF, -INF)}
	var bend_jog := Vector2(INF, -INF)
	var bend_still := Vector2(INF, -INF)
	var palm := 0.0
	var t_phase := 0.0
	var phase := ""
	var anchor := {}
	for row: Dictionary in elbow_rows:
		if String(row.phase) != phase:
			phase = String(row.phase)
			t_phase = float(row.t)
			anchor = {}
		var since := float(row.t) - t_phase
		for s in ["l", "r"]:
			var a: Dictionary = row[s]
			side = Vector2(minf(side.x, a.side), maxf(side.y, a.side))
			palm = maxf(palm, a.palm)
			if (phase == "straight" and since > 1.2) or phase == "turn":
				jog_x[s] = Vector2(minf(jog_x[s].x, a.x), maxf(jog_x[s].y, a.x))
				bend_jog = Vector2(minf(bend_jog.x, a.bend), maxf(bend_jog.y, a.bend))
			if (phase == "hold" and since > 0.3) or (phase == "stop" and since > 0.9):
				bend_still = Vector2(minf(bend_still.x, a.bend), maxf(bend_still.y, a.bend))
		# rates over at least a 60 Hz frame's time (whatever the frame rate)
		if anchor.is_empty():
			anchor = row
		elif float(row.t) - float(anchor.t) >= 1.0 / 60.0 - 1e-4:
			var dt := float(row.t) - float(anchor.t)
			for s in ["l", "r"]:
				turn = maxf(turn, absf(wrapf(float(row[s].side) - float(anchor[s].side), -180.0, 180.0)) / dt)
				sway = maxf(sway, absf(float(row[s].x) - float(anchor[s].x)) / dt)
			anchor = row
	var jog_sway := maxf(jog_x.l.y - jog_x.l.x, jog_x.r.y - jog_x.r.x)
	report["elbows"] = {"frames": elbow_rows.size(), "side_deg": [snappedf(side.x, 0.1), snappedf(side.y, 0.1)],
			"turn_dps": snappedf(turn, 1.0), "sway_mps": snappedf(sway, 0.01), "jog_sway_cm": snappedf(jog_sway * 100.0, 0.1),
			"bend_jog_deg": [snappedf(bend_jog.x, 0.1), snappedf(bend_jog.y, 0.1)],
			"bend_still_deg": [snappedf(bend_still.x, 0.1), snappedf(bend_still.y, 0.1)], "palm_cm": snappedf(palm * 100.0, 0.1)}
	check(elbow_rows.size() > 300, "the elbows' push measured (%d frames)" % elbow_rows.size())
	check(side.x >= ELBOW_SIDE_DEG.x and side.y <= ELBOW_SIDE_DEG.y,
			"the elbows keep their side, down and out: never in across the body nor up over the line (%.0f..%.0f deg)" % [side.x, side.y])
	check(turn <= ELBOW_TURN_DPS, "the elbows' side turns only a little a frame (%.0f deg/s at most)" % turn)
	check(sway <= ELBOW_SWAY_MPS, "the elbows move sideways only a little a frame (%.2f m/s at most)" % sway)
	check(jog_sway <= ELBOW_JOG_SWAY_M, "over the jog's strides the elbows keep their place (%.1f cm sideways at most)" % (jog_sway * 100.0))
	check(bend_jog.x >= ARM_BEND_DEG.x and bend_jog.y <= ARM_BEND_DEG.y and bend_still.x >= ARM_BEND_DEG.x
			and bend_still.y <= ARM_BEND_DEG.y, "the arms a little bent: jogging %.0f-%.0f deg, standing %.0f-%.0f deg"
			% [bend_jog.x, bend_jog.y, bend_still.x, bend_still.y])
	check(palm <= ELBOW_PALM_M, "both palms on the grips throughout (%.1f cm off at most)" % (palm * 100.0))
