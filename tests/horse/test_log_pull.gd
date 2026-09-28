extends SceneTree
## Headless tests of limbing a felled tree, pulling a log on foot and laying a log barricade (GatherTools' Limb,
## scripts/horse/log_pull.gd, SkidLoad.laid; data/horse/haul.json "foot_log"), in the real level with the real keys:
##
##   Godot --headless --path . -s tests/horse/test_log_pull.gd
##
##   data      the pace falls as the pull grows, never to a stand; a 2.4 m length of a middling pine at a crawl
##   limb      a tree felled, E at its crown ("Limb the ..."): strokes until its limbs are off, the crown's firewood
##             and branches in the pack, the trunk a bare log lying where the tree lay; along it the axe bucks a
##             length off as its own log (not into the pack), light enough to pull
##   heavy     a 1,000 kg log: "... very slow", and it is pulled at an extreme crawl
##   pull      E at a log's end ("Drag the ... log"): the gun on the back, both hands on it (take hold, then the pull
##             clips), S pulls it back at the pull's pace facing the log, A steps left (the left step clip)
##   lay       E ("Lay the log down"): straight and level on the ground, the player up with the gun again
##   stack     a second and third log pulled against it: "Stack the log on the barricade", three high; a fourth goes
##             on the ground; at the stack's end E offers the top log; the logs under it cannot be taken
##   cover     a shot at knee height is stopped by the barricade; one at a standing man's chest goes over it
##   save      the laid logs are saved laid, where they lie
##   let go    a jump lets go: the log lies loose
##
## The trees and logs are the project's own models.

var checks := 0
var fails: Array[String] = []
var report := {}
var player: FrontierPlayer
var lp: LogPull
var it: PlayerInteractor


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
	check(player != null and player.log_pull != null, "the player has a LogPull")
	if player == null or player.log_pull == null:
		_end()
		return
	player.ignore_mouse_capture = true
	lp = player.log_pull
	it = player.interactor
	await frames(60)
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Horse).global_position = _ground(-60.0, 60.0)
	await _test_limb()
	await _test_heavy()
	await _test_pull_lay_stack()
	await _test_jump()
	_end()


func _end() -> void:
	print("REPORT ", JSON.stringify(report))
	if fails.is_empty():
		print("LOG PULL TEST PASSED %d" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("LOG PULL TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


func _test_data() -> void:
	var last := INF
	var mono := true
	for i in 220:
		var c := LogPull.cap_for(float(i))
		mono = mono and c <= last + 1e-6
		last = c
	check(mono and LogPull.cap_for(0.0) > 0.5 and LogPull.cap_for(400.0) > 0.0 and LogPull.cap_for(2000.0) <= 0.051,
			"the pace falls as the pull grows, never to a stand: an extreme crawl (%.2f m/s at 400 kgf)" % LogPull.cap_for(400.0))
	check(not LogPull.very_heavy(150.0) and not LogPull.very_heavy(400.0) and LogPull.very_heavy(500.0), "a 2.4 m length of a middling pine (about 400 kg) at a crawl, 500 kg very slowly")


func _put(at: Vector3, look: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	var d := look - at
	d.y = 0.0
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-15.0)


func _tap(action: StringName, n := 4) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)
	await frames(3)


func _pack(kind: String) -> int:
	return InventoryState.from_player(player).pack_count(kind)


## A log of `L` m and radius `r` (white pine) lying from `a` toward `dir`.
func _log(a: Vector3, dir: Vector3, L: float, r: float) -> SkidLoad:
	var d := dir.normalized()
	var f := Vector3(a.x, FrontierTerrain.height_at(a.x, a.z) + r, a.z)
	var b := f + d * L
	b.y = FrontierTerrain.height_at(b.x, b.z) + r
	var s := SaveParts._loose_bole({"info": {"species": "white_pine", "name": "white pine", "radius": r, "i": 9000 + randi() % 1000,
			"pos": [a.x, a.y, a.z]}, "front": [f.x, f.y, f.z], "back": [b.x, b.y, b.z], "r0": r, "r1": r * 0.9,
			"logs_total": maxi(1, roundi(L / 2.4)), "logs_left": maxi(1, roundi(L / 2.4))}, GatherData.get_default().felling, false)
	current_scene.add_child(s)
	return s


# --- Limbing -------------------------------------------------------------------------------------------------

func _fell_one() -> FelledTree:
	var vh := VegHarvest.find(self)
	var best := -1
	var bd := INF
	for i in vh.lay.tree_pos.size():
		if int(vh.lay.tree_kind[i]) >= VegHarvest.Assets.CANOPY_COUNT or vh.lay.tree_collider[i] == 0:
			continue
		var p: Vector3 = vh.lay.tree_pos[i]
		if absf(p.x) < 35.0 and absf(p.z) < 35.0:
			continue
		var d := vh.describe("tree", "tree", i)
		if d.is_empty() or float(d.radius) > 0.25:
			continue
		var dist := Vector2(p.x, p.z).length()
		if dist < bd:
			bd = dist
			best = i
	var desc := vh.describe("tree", "tree", best)
	var got := [null]
	var cb := func(ft: FelledTree) -> void: got[0] = ft
	player.gather.felled.connect(cb)
	player.global_position = desc.pos + Vector3(1.3, 0.1, 0.3)
	await frames(2)
	player.gather._fell(desc)
	player.gather.felled.disconnect(cb)
	var ft: FelledTree = got[0]
	for k in 120 * 10:
		await physics_frame
		if ft.is_down():
			break
	return ft


func _test_limb() -> void:
	var ft := await _fell_one()
	check(ft != null and ft.is_down(), "a tree is down")
	if ft == null:
		return
	var nm := ft.species_name()
	var hinge := ft.hinge
	var cr := float(ft.info.get("crown_radius", 3.0))
	# stand in its crown, beside the stem
	var mid_crown := ft.hinge + ft.axis() * (float(ft.info.get("crown_bottom", ft.length * 0.4)) + ft.length) * 0.5
	var side := ft.axis().cross(Vector3.UP).normalized()
	_put(mid_crown + side * minf(cr * 0.5, 1.5), mid_crown)
	await frames(10)
	check(String(player.gather.target.get("type", "")) == "crown", "in its crown the axe's target is its limbs (%s)" % player.gather.target.get("type", ""))
	check(it._label.text.contains("Limb the %s" % nm), "E says: %s" % it._label.text)
	var need := player.gather.limb_work(ft)
	var fw0 := _pack("firewood")
	var br0 := _pack("branches")
	var got := [null]
	var cb := func(s: SkidLoad) -> void: got[0] = s
	player.gather.limbed.connect(cb)
	var strokes := 0
	for i in 30:
		if got[0] != null:
			break
		await _tap(&"interact")
		strokes += 1
		for k in 240:                    # the axe out (a draw first), the swing played out
			await physics_frame
			if k > 20 and player.gather._swing.is_empty() and player.gather.in_hand() == "felling_axe":
				break
	player.gather.limbed.disconnect(cb)
	var s: SkidLoad = got[0]
	report["limb"] = {"strokes": strokes, "crown_r": snappedf(cr, 0.1), "work": snappedf(need, 0.1)}
	check(s != null, "E by E its limbs come off (%d strokes)" % strokes)
	if s == null:
		return
	await frames(10)
	check(not is_instance_valid(ft), "the felled tree is gone")
	check(_pack("firewood") > fw0 and _pack("branches") > br0, "its firewood and branches in the pack (+%d, +%d)" % [_pack("firewood") - fw0, _pack("branches") - br0])
	check(s.species_name() == nm and s.front.distance_to(hinge) < 1.0 and not s.laid and not s.hitched, "a bare %s log lies where it fell" % nm)
	report["limbed_log"] = {"kg": roundi(s.mass_kg), "m": snappedf(s.length, 0.1), "r": snappedf(s.r_front, 0.01), "lengths": s.logs_left}
	await frames(60)
	# the axe along it: a length bucked off lies as its own log
	if s.logs_left >= 2:
		var bm := s.front + (s.back - s.front) * 0.5
		var sd := (s.back - s.front).cross(Vector3.UP).normalized()
		_put(bm + sd * 1.0, bm)
		await frames(10)
		check(it._label.text.contains("Buck a log off the %s" % nm), "along the log E says: %s" % it._label.text)
		var n0 := get_nodes_in_group(FelledTree.GROUP).size()
		var L0 := s.length
		var logs0 := _pack("log")
		var res := s.buck(s.cut_work + 0.01)
		var cut: Array = res.get("cut_off", [])
		await frames(30)
		check(cut.size() == 1 and get_nodes_in_group(FelledTree.GROUP).size() == n0 + 1 and absf(s.length - (L0 - 2.4)) < 0.01,
				"a length bucked off lies as its own log (%.1f -> %.1f m)" % [L0, s.length])
		check(_pack("log") == logs0, "not into the pack")
		if not cut.is_empty():
			var piece := cut[0] as SkidLoad
			report["bucked_length"] = {"kg": roundi(piece.mass_kg), "m": snappedf(piece.length, 0.1)}
			check(piece.logs_left == 1 and absf(piece.length - 2.34) < 0.1 and not LogPull.very_heavy(piece.mass_kg),
					"a 2.4 m log of %d kg, one can pull it" % roundi(piece.mass_kg))
			piece.queue_free()
	s.queue_free()


func _test_heavy() -> void:
	var s := _log(_ground(40.0, -60.0), Vector3(1, 0, 0), 7.0, 0.3)
	await frames(60)
	_put(s.front + Vector3(-1.2, 0, 0.2), s.front)
	await frames(8)
	check(it.target == lp and it._label.text.contains("very slow"), "a %d kg log: %s" % [roundi(s.mass_kg), it._label.text])
	await _tap(&"interact")
	await frames(130)
	check(lp.load == s, "and it can be taken")
	var p0 := s.mid()
	var pp0 := player.global_position
	player.yaw = player.rotation.y
	var w := await _hold(&"move_back", 8.0)
	var moved := Vector2(s.mid().x - p0.x, s.mid().z - p0.z).length()
	var walked := Vector2(player.global_position.x - pp0.x, player.global_position.z - pp0.z).length()
	report["heavy"] = {"kg": roundi(s.mass_kg), "cap": snappedf(lp.cap, 0.01), "moved": snappedf(moved, 0.01), "walked": snappedf(walked, 0.01), "stretch": snappedf(s.stretch, 0.01), "hits": s.obstacle_hits, "chain": snappedf(s.chain_len, 0.01), "hp_front": snappedf(lp.hitch_point().distance_to(s.front), 0.01), "pull_kgf": roundi(s.pull_kgf), "hitched": s.hitched}
	check(lp.cap > 0.0 and lp.cap <= 0.12 and moved > 0.15, "pulled at an extreme crawl (%.2f m/s: %.2f m in 8 s)" % [lp.cap, moved])
	await _tap(&"interact")
	await frames(120)
	for i in 360:
		if player.kneeling == null and not player.is_switching():
			break
		await physics_frame
	s.queue_free()
	await frames(5)


## Takes log `s` by its front end from `back_m` behind it with E.
func _take(s: SkidLoad) -> void:
	var ax := (s.back - s.front)
	ax.y = 0.0
	ax = ax.normalized()
	_put(s.front - ax * 1.0, s.front)
	await frames(8)
	await _tap(&"interact")
	await frames(10)


func _hold(action: StringName, secs: float) -> Dictionary:
	var vmax := 0.0
	var face := 0.0
	var curve := 0.0
	var clip := ""
	Input.action_press(action)
	for i in int(secs * 120.0):
		await physics_frame
		if i > 90:
			vmax = maxf(vmax, player.horizontal_speed())
		if i == int(secs * 120.0) - 2 and lp.load:
			var d := lp.load.front - player.global_position
			d.y = 0.0
			var bf := -player.global_basis.z
			bf.y = 0.0
			face = rad_to_deg(bf.angle_to(d))
			clip = lp._blender.active_clip() if lp._blender else ""
			curve = lp._blender.active_curve() if lp._blender else 0.0
	Input.action_release(action)
	await frames(10)
	return {"vmax": vmax, "face": face, "clip": clip, "curve": curve}


func _test_pull_lay_stack() -> void:
	var at := _ground(30.0, -44.0)
	var dir := Vector3(0.0, 0.0, -1.0)
	var a := _log(at, dir, 3.2, 0.15)
	# the axe from the limbing away, the musket in the hands
	player.gather.drop_now()
	if player.hands_free:
		player.toggle_hands_free()
	await frames(90)
	check(not player.hands_free and player.weapon_key == "musket", "the musket in the hands")
	report["log_a"] = {"kg": roundi(a.mass_kg), "m": snappedf(a.length, 0.1)}
	_put(a.front - dir * 1.0, a.front)
	await frames(8)
	check(it.target == lp and it._label.text.contains("Drag the white pine log"), "at its end: %s" % it._label.text)
	await _tap(&"interact")
	await frames(10)
	check(lp.load == a and player.kneeling == lp and player.hands_free, "E: both hands on it, the gun on the back")
	check(lp._blender != null and lp._blender.active_clip() == LogPull.CLIP_TAKE, "taking hold (%s)" % (lp._blender.active_clip() if lp._blender else ""))
	await frames(120)
	check(lp.phase == "pull" and it._label.text.ends_with("Lay the log down"), "holding it, E says: %s" % it._label.text)
	var p0 := a.mid()
	# S: the camera looks along the log from the player (the default: the body faces it), so back is S
	player.yaw = player.rotation.y
	var w := await _hold(&"move_back", 5.0)
	var moved := Vector2(a.mid().x - p0.x, a.mid().z - p0.z).length()
	report["pull"] = {"moved": snappedf(moved, 0.1), "vmax": snappedf(w.vmax, 0.02), "cap": snappedf(lp.cap, 0.02), "pull_kgf": snappedf(a.pull_kgf, 0.1), "face_deg": snappedf(w.face, 1.0)}
	check(moved > 1.2, "S pulls it back (%.1f m in 5 s)" % moved)
	check(w.clip == LogPull.CLIP_PULL, "on the pull clip (%s)" % w.clip)
	check(w.vmax <= lp.cap + 0.1 and lp.cap > 0.2, "at the pull's pace: at most %.2f m/s under %.2f" % [w.vmax, lp.cap])
	check(w.face < 30.0, "facing the log (%.0f deg off)" % w.face)
	var wl := await _hold(&"move_left", 2.0)
	check(wl.curve > 0.5 and lp.moving.length() < 0.01, "A steps left (curve %.2f)" % wl.curve)
	# E lays it down, level
	await _tap(&"interact")
	await frames(90)
	check(a.laid and lp.load == null and lp.last_let_go == "lay", "E lays it down (%s)" % lp.last_let_go)
	var gf := FrontierTerrain.height_at(a.front.x, a.front.z) + a.r_front
	var gb := FrontierTerrain.height_at(a.back.x, a.back.z) + a.r_back
	check(absf(a.front.y - gf) < 0.08 and absf(a.back.y - gb) < 0.08, "on the ground (%.2f, %.2f m off)" % [a.front.y - gf, a.back.y - gb])
	for i in 360:
		if player.kneeling == null and not player.hands_free and not player.is_switching():
			break
		await physics_frame
	check(player.kneeling == null and not player.hands_free, "up again, the gun in the hands")
	var fa := a.front
	await frames(120)
	check(a.front.distance_to(fa) < 0.005, "a laid log stays put")
	# a second and a third log pulled against it: stacked
	var ax := (a.back - a.front)
	ax.y = 0.0
	var side := ax.normalized().cross(Vector3.UP).normalized()
	var logs: Array[SkidLoad] = [a]
	for k in 3:
		var n := _log(a.front + side * 0.55, ax, 3.2, 0.16)
		await frames(90)
		await _take(n)
		await frames(130)
		var prompt := it._label.text
		await _tap(&"interact")
		await frames(90)
		if k < 2:
			check(prompt.ends_with("Stack the log on the barricade") and n.laid and n.rests_on() == logs[-1] and n.stack_level() == k + 2,
					"log %d: '%s', on the barricade (course %d)" % [k + 2, prompt, n.stack_level()])
		else:
			check(prompt.ends_with("Lay the log down") and n.laid and n.stack_level() == 1, "a fourth goes on the ground: '%s' (course %d)" % [prompt, n.stack_level()])
		logs.append(n)
	var top := logs[2]
	report["barricade_top_m"] = snappedf(top.mid().y + top.mean_radius() - FrontierTerrain.height_at(top.mid().x, top.mid().z), 0.01)
	# at the stack's end E offers the top log; one with logs on it cannot be taken
	var aa := (a.back - a.front).normalized()
	_put(a.front - Vector3(aa.x, 0, aa.z).normalized() * 0.9, a.front)
	await frames(8)
	check(it.target == lp and lp._offer.get("log") == top and it._label.text.contains("Drag the"), "at the stack's end, the top log: %s" % it._label.text)
	check(not lp.start(a) and not lp.start(logs[1]), "a log with logs on it cannot be taken")
	check(a.laid and logs[1].laid and top.laid, "and the stack stands")
	# cover: a shot at knee height stops in it, one at a standing chest goes over (the three-high stack)
	var space := player.get_world_3d().direct_space_state
	var mid := top.mid()
	var gy := FrontierTerrain.height_at(mid.x, mid.z)
	var ex: Array[RID] = [player.get_rid()]
	var low := PhysicsRayQueryParameters3D.create(Vector3(mid.x, gy + 0.45, mid.z) + side * 3.0, Vector3(mid.x, gy + 0.45, mid.z) - side * 3.0)
	low.exclude = ex
	var hit_low := space.intersect_ray(low)
	check(not hit_low.is_empty() and hit_low.collider.get_parent() is SkidLoad, "a shot at knee height is stopped by the barricade")
	var high := PhysicsRayQueryParameters3D.create(Vector3(mid.x, gy + 1.45, mid.z) + side * 3.0, Vector3(mid.x, gy + 1.45, mid.z) - side * 3.0)
	high.exclude = ex
	var hit_high := space.intersect_ray(high)
	check(hit_high.is_empty() or not (hit_high.collider.get_parent() is SkidLoad), "one at a standing man's chest goes over it")
	# saved laid
	var veg := SaveParts.save_vegetation(current_scene)
	var laid := (veg.get("loose", []) as Array).filter(func(e: Dictionary) -> bool: return bool(e.get("laid", false)))
	check(laid.size() == 4, "the save has the four laid logs (%d)" % laid.size())
	if not laid.is_empty():
		var back := SaveParts._loose_bole(laid[0], GatherData.get_default().felling, false)
		check(back.laid and back.front.distance_to(SaveParts.to_v3(laid[0].front)) < 0.001, "and loads them laid, where they lay")
		back.free()
	for s in logs:
		s.queue_free()
	await frames(10)


func _test_jump() -> void:
	var s := _log(_ground(36.0, -50.0), Vector3(1, 0, 0), 3.0, 0.15)
	await frames(90)
	await _take(s)
	await frames(130)
	check(lp.load == s, "taken again")
	await _tap(&"jump")
	await frames(90)
	check(lp.load == null and lp.last_let_go == "jump" and not s.laid and player.kneeling == null, "a jump lets go: it lies loose (%s)" % lp.last_let_go)
	s.queue_free()
