extends SceneTree
## The slice's review fixes, each on its own on the real level (survival on; tests/story/test_slice.gd plays them in the
## flow):
##   Godot --headless --fixed-fps 60 --path . -s tests/story/test_slice_fixes.gd -- survival=on
##   wood     the homestead's woodlot (VegWoodlots, data/world/woodlots.json): trees, saplings and rocks a short walk from
##            the homestead, its ground left open, the cache's fallen oak; a tree of it fells as the forest's do (VegHarvest),
##            the forest's own indices first (the wood appended after them)
##   raid     taken, the raid's raiders leave the farms (RaidStage.withdraw): no hostile fighter is left by the march's route
##            but the scripted party; the neighbours waiting are the families warned, in their names and looks
##   resume   RaidStage begun again as a load does it (resume, hour -1): the clock not moved on, the one over the ford not
##            waiting again; the player captive already: the party round him at once, Leclerc his captor again
##   lock     the wreck's spar with nothing granted, the crosshair put on it once and the aim held still: the camera stays,
##            the lock fills and casts (it broke and began again before); the Sway sets the spar down clear of the stranger,
##            and a load after it lays the spar there (StorySlice.set_spar_down)
##   walkers  a StoryWalker far off steps its clips seldom (WildlifeSpawner.anim_step_at), past VISIBLE_M is not drawn, and
##            one standing settled rests (its physics skipped); an order wakes it
## Ends with "SLICE FIXES TEST PASSED (<n> checks)" or "SLICE FIXES TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var b: SurvivalBridge
var home := Vector3(1000.0, 0.0, 100.0)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _g(x: float, z: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


func _flat(a: Vector3, c: Vector3) -> float:
	return Vector2(a.x - c.x, a.z - c.z).length()


func _put(p: Vector3) -> void:
	player.global_position = _g(p.x, p.z) + Vector3.UP * 0.15
	player.velocity = Vector3.ZERO


func _aim(p: Vector3) -> void:
	var d := p - player.camera.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await _ticks(60)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	b = SurvivalBridge.find(self)
	_expect(player != null and b != null, "the level, the player and the survival rules")
	if player == null or b == null:
		_end()
		return
	player.ignore_mouse_capture = true
	player.max_health = 100000.0
	player.health = player.max_health
	home = _g(1000.0, 100.0)
	var wild := current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	if wild != null:
		for a in wild.animals():
			wild.remove_animal(a)
	_wood()
	await _raid()
	await _lock()
	await _walkers()
	_end()


# ---------------------------------------------------------------- the homestead's wood
func _wood() -> void:
	var h := VegHarvest.find(self)
	_expect(h != null, "the level's vegetation")
	if h == null:
		return
	var n := {"tree": 0, "sapling": 0, "rock": 0}
	var nearest := INF
	for d: Dictionary in h.near(home, 90.0):
		n[String(d.type)] = int(n.get(String(d.type), 0)) + 1
		if String(d.type) == "tree":
			nearest = minf(nearest, _flat(d.pos, home))
	_expect(int(n.tree) >= 20 and int(n.sapling) >= 6 and int(n.rock) >= 3,
			"within 90 m of the homestead: %d trees, %d saplings, %d rocks (Clearing's trees, the lean-to's poles, the hearth's stone)"
			% [n.tree, n.sapling, n.rock])
	_expect(nearest >= 20.0 and nearest < 40.0, "its ground left open: the nearest tree %.1f m off" % nearest)
	var st: Dictionary = h.veg.stats.get("woodlots", {}) if h.veg != null else {}
	var log_ok := false
	for i in h.lay.prop_pos.size():
		if int(h.lay.prop_kind[i]) == VegHarvest.Assets.LOG and _flat(h.lay.prop_pos[i], _g(1016.0, 120.0)) < 5.0:
			log_ok = true
	_expect(log_ok and int(st.get("props", 0)) >= 1, "the cache's fallen oak by the cache (%s)" % str(st))
	# the wood after the forest: its first tree's index past the forest's last (the forest round the fort, within 400 m)
	var first := -1
	var last_forest := -1
	for i in h.lay.tree_pos.size():
		var p: Vector3 = h.lay.tree_pos[i]
		if absf(p.x) <= 400.0 and absf(p.z) <= 400.0:
			last_forest = i
		elif first < 0 and _flat(p, home) < 120.0:
			first = i
	_expect(first > last_forest and last_forest > 1000, "the wood's trees after the forest's (%d after %d): its indices kept" % [first, last_forest])
	# one of them felled as the forest's are
	var pick: Dictionary = {}
	for d: Dictionary in h.near(home, 90.0):
		if String(d.type) == "tree":
			pick = d
			break
	var desc := h.remove_tree(int(pick.get("i", -1))) if not pick.is_empty() else {}
	_expect(not desc.is_empty() and h.felled.has(int(pick.i)) and not h.has_trunk_collider(int(pick.i)) and h.describe("tree", "tree", int(pick.i)).is_empty(),
			"a tree of it felled: gone from the harvest, its trunk collider freed (%s)" % String(desc.get("species", "?")))


# ---------------------------------------------------------------- the raid
func _raid() -> void:
	b.core.state.minutes = SurvivalClock.minutes_at(b.core, "nov_mid", 1757, 2.5)
	NpcSenses.daylight_override = NpcSenses.NIGHT
	_put(home + Vector3(-3, 0, -2))
	await _ticks(10)
	var farms := [Vector3(930, 0, -45), Vector3(880, 0, -120), Vector3(860, 0, -200), Vector3(965, 0, 20)]
	var who := [{"name": "Konrad Brenner", "look": "palatine_m_a"}, {"name": "Barbara Wendel", "look": "dutch_f_a"}]
	var raid := RaidStage.begin(current_scene, home, farms, {"capture": "manual", "neighbours": 2, "who": who})
	await _ticks(5)
	var names: Array = []
	for e: Dictionary in raid.neighbours:
		names.append((e.w as StoryWalker).label)
	_expect(names == ["Konrad Brenner", "Barbara Wendel"], "the ones waiting are the families warned, by their farms: %s" % str(names))
	_expect(_flat((raid.neighbours[0].w as StoryWalker).global_position, raid.farms[0]) < 45.0, "Konrad Brenner waits by the Brenners' farm")
	var raiders := 0
	for s in raid.squads:
		raiders += s.alive_count()
	_expect(raiders == 8, "the raiders at the farms (%d)" % raiders)
	raid.capture_now()
	var cap: Captivity = null
	for i in Engine.physics_ticks_per_second * 30:
		await physics_frame
		cap = Captivity.find(self)
		if cap != null and cap.is_active() and raid.phase in ["torch", "done"]:
			break
	await _ticks(3)
	_expect(cap != null and cap.is_active() and cap.captor == raid.leclerc, "taken: bound, Leclerc the captor")
	var hostile: Array = []
	for f: NpcFighter in NpcSenses.fighters:
		if is_instance_valid(f) and not f.is_dead() and not f.is_queued_for_deletion() and not (f is StoryActor and (f as StoryActor).scripted):
			hostile.append(f.name)
	_expect(raid.squads.is_empty() and hostile.is_empty(), "taken, the raiders leave the farms: no fighter left but the scripted party (%s)" % str(hostile))
	# a load in the middle: RaidStage begun again as StorySlice does it then (the clock left; the record of the neighbours)
	var h0 := SurvivalClock.hour(b.core)
	var m0 := b.core.state.minutes
	var res := RaidStage.begin(current_scene, home, farms, {"capture": "now", "resume": true, "hour": -1.0, "neighbours": 2, "who": who})
	await _ticks(3)
	_expect(absf(b.core.state.minutes - m0) < 2.0, "loaded mid-raid: the clock left where it was (%.2f h, was %.2f h)" % [SurvivalClock.hour(b.core), h0])
	_expect(res.squads.is_empty() and res.neighbours.is_empty() and res.phase in ["torch", "done"] and cap.captor == res.leclerc
			and _flat(res.leclerc.global_position, player.global_position) < 4.0,
			"loaded taken: no raiders, no one waiting, the party round him at once, Leclerc his captor again (%s, %.1f m)"
			% [res.phase, _flat(res.leclerc.global_position, player.global_position)])
	cap.end(true)
	raid.queue_free()
	res.queue_free()
	await _ticks(3)
	# a load before the capture, one over the ford already (the story's record: StoryDirector's flag): he does not wait again
	var d := StoryDirector.find(self)
	if d != null:
		d.set_flag(RaidStage.WHO_FLAG, {"0": "over", "1": "following"})
		var r2 := RaidStage.begin(current_scene, home, farms, {"capture": "manual", "resume": true, "hour": -1.0, "neighbours": 2, "who": who})
		await _ticks(3)
		_expect(r2.saved == 1 and r2.neighbours_in("waiting") == 0 and r2.neighbours_in("following") == 1
				and int(d.flag(RaidStage.SAVED_FLAG)) == 1, "loaded on the run: the one over the ford saved, not waiting again; the one following follows (%d saved, %d following)"
				% [r2.saved, r2.neighbours_in("following")])
		d.set_flag(RaidStage.WHO_FLAG, null)
		r2.queue_free()
	NpcSenses.daylight_override = -1.0
	await _ticks(5)


# ---------------------------------------------------------------- the first lock
func _lock() -> void:
	var caster := SwayCaster.install(player)
	for i in 12:
		if player.hands_free:
			break
		if not player.is_switching():
			player.toggle_hands_free()
		await _ticks(15)
	var wf := WreckFall.place_wreck(current_scene, _g(1112.0, -387.0), deg_to_rad(150.0), 0.0)
	await _ticks(10)
	_expect(wf != null and wf.spar() != null and wf.rook() != null, "the wreck at its bench, the spar across the stranger")
	if wf == null or wf.spar() == null:
		return
	StorySlice._spar_meta(wf)
	var spar := wf.spar()
	var rook := wf.rook()
	var pelvis := rook.bone_pos("pelvis")
	var knee := (pelvis + rook.bone_pos("r_foot")) * 0.5
	var out := wf.frame.basis.x
	out.y = 0.0
	out = out.normalized()
	var sp := spar.global_position
	_put(sp + out * 6.0)
	caster.held_override = false
	await _ticks(30)
	for k in 30:                                   # the crosshair brought onto it once
		_aim(spar.global_position)
		await physics_frame
	var starts := [0]
	var breaks: Array = []
	var on_start := func(_m: String, _t: Node3D) -> void: starts[0] += 1
	var on_break := func(_m: String, _t: Node3D, why: String) -> void: breaks.append(why)
	caster.lock_started.connect(on_start)
	caster.lock_broken.connect(on_break)
	var cam0 := player.camera.global_position
	caster.held_override = true                    # then held, the mouse still
	var full := false
	var t_full := -1.0
	var hz := float(Engine.physics_ticks_per_second)
	for i in int(hz * 6.0):
		await physics_frame
		if caster.state == SwayCaster.State.FULL:
			full = true
			t_full = i / hz
			break
	var cam_moved := player.camera.global_position.distance_to(cam0)
	await _ticks(2)
	caster.held_override = false
	await _ticks(4)
	caster.held_override = null
	caster.lock_started.disconnect(on_start)
	caster.lock_broken.disconnect(on_break)
	_expect(full and starts[0] == 1 and breaks.is_empty() and cam_moved < 0.2,
			"nothing granted, the aim held still on the spar: one lock, full, unbroken, the camera still (%d begun, full at %.1f s, breaks %s, camera %.2f m)"
			% [starts[0], t_full, str(breaks), cam_moved])
	_expect(SwayCaster.cast_count("Spar", "first_lock") >= 1, "let go at the click: the first lock cast")
	await _secs(4.0)                               # (the lift: 1.8 s, then it falls and settles)
	var a := spar.global_position - spar.global_basis.x * WreckFall.SPAR_LEN * 0.5
	var c := spar.global_position + spar.global_basis.x * WreckFall.SPAR_LEN * 0.5
	var dp := _seg_dist(pelvis, a, c)
	var dk := _seg_dist(knee, a, c)
	_expect(dp > 0.6 and dk > 0.6, "the spar set down clear of him: %.2f m from where his hips lay, %.2f m from his knees" % [dp, dk])
	wf.queue_free()
	await _ticks(3)
	# a load after the lock (StorySlice.restore): the spar lying where the Sway set it, still; the stranger up
	var wf2 := WreckFall.place_wreck(current_scene, _g(1112.0, -387.0), deg_to_rad(150.0), 0.0)
	await _ticks(10)
	StorySlice._spar_meta(wf2)
	var pel2 := wf2.rook().bone_pos("pelvis")
	var want: Vector3 = wf2.spar().get_meta(&"sway_lift_to")
	StorySlice.set_spar_down(wf2)
	await _secs(1.0)
	var s2 := wf2.spar()
	var a2 := s2.global_position - s2.global_basis.x * WreckFall.SPAR_LEN * 0.5
	var c2 := s2.global_position + s2.global_basis.x * WreckFall.SPAR_LEN * 0.5
	_expect(s2.global_position.distance_to(want) < 0.05 and s2.freeze and _seg_dist(pel2, a2, c2) > 0.6 and s2.has_meta(&"cast"),
			"loaded after the lock: the spar lies where the Sway set it (%.2f m from his hips), the stranger let up" % _seg_dist(pel2, a2, c2))
	wf2.queue_free()
	await _ticks(3)


static func _seg_dist(p: Vector3, a: Vector3, c: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var c2 := Vector2(c.x, c.z)
	var ab := c2 - a2
	var t := clampf((p2 - a2).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p2.distance_to(a2 + ab * t)


# ---------------------------------------------------------------- the walkers' level of detail
func _walkers() -> void:
	_put(home)
	await _ticks(5)
	var near := StoryWalker.make(current_scene, home + Vector3(4, 0, 3), StoryWalker.settler_look("palatine_m_a"), {"tag": "near_one"})
	var mid := StoryWalker.make(current_scene, home + Vector3(120, 0, 0), StoryWalker.settler_look("palatine_f_a"), {"tag": "mid_one"})
	var far := StoryWalker.make(current_scene, _g(home.x - 140.0, home.z - 250.0), StoryWalker.settler_look("dutch_f_a"), {"tag": "far_one"})
	await _secs(2.0)
	_expect(is_zero_approx(near.body.anim_step) and mid.body.anim_step > 0.05 and far.body.anim_step > 0.1,
			"the clips stepped for the distance: near every frame, %.0f m off every %.2f s, %.0f m off every %.2f s"
			% [_flat(mid.global_position, player.camera.global_position), mid.body.anim_step,
			_flat(far.global_position, player.camera.global_position), far.body.anim_step])
	_expect(not far.body.visible and not far.body.animate and near.body.visible, "past %.0f m it is not drawn nor stepped" % NpcSenses.VISIBLE_M)
	_expect(near.resting and mid.resting, "standing settled they rest (no physics frame of their own)")
	var p0 := near.global_position
	near.go(home + Vector3(10, 0, 3), StoryWalker.WALK, 0.6)
	await _secs(2.0)
	_expect(not near.resting and _flat(near.global_position, p0) > 1.0, "an order wakes it: it walks (%.1f m)" % _flat(near.global_position, p0))
	for w in [near, mid, far]:
		w.queue_free()


func _end() -> void:
	NpcSenses.daylight_override = -1.0
	if fails.is_empty():
		print("SLICE FIXES TEST PASSED (%d checks)" % checks)
	else:
		print("SLICE FIXES TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
