extends SceneTree
## The raid, the march and Rook's walk staged (RaidStage, MarchStage, RookWalk; StoryActor, StoryWalker; docs/main_story.md
## 10.1 missions 9-10, 10.2 mission 12) on the real level, survival and wildlife on, the homestead east of the river:
##   Godot --headless --fixed-fps 60 --path . -s tests/story/test_raid_stage.gd -- survival=on wildlife=on
##   night    begin() at 1 a.m. moves the clock on to 3 a.m.; the persuaded count reads 0 with no story running
##   farms    the farms set alight (stand-in farmhouses where nothing there burns), a glow over each, real raiders at each
##            (French marines and Canadian militia, holding), the warned neighbours waiting crouched
##   run      the player near one, it follows him; both brought to the ford wade over to the far bank and are saved
##   capture  back in his clearing the party comes up from behind and stands round him; Leclerc says the line in French;
##            the player is taken (Captivity: bound, Leclerc the captor, his weapons held)
##   torch    the marine with the torch goes to the house the player built and it catches (the roof first)
##   march    the march (Leclerc and the two marines handed on) sets off once the house is alight, the guards keep their
##            places, Jost beside the player, the crust shared, the clock on with the metres; at the camp a campfire lit
##   cones    a guard sees the player before him in the firelight, not behind him; captive, nobody counts as having seen
##            him (StoryObjectives.seen_by); loose (break_free), the guard that sees him is alerted and seen_by finds it
##   resist   a scripted fighter struck by the player wakes (its own brain) and fights
##   rook     Rook (no shadow) walks the player on; three wolves come; he casts Gust (the cast's clips), they are blown
##            back and run; the walk goes on to its end
## Ends with "RAID STAGE TEST PASSED (<n> checks)" or "RAID STAGE TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var b: SurvivalBridge
var fire: FireSpread
var world: BuildWorld
var wild: WildlifeSpawner
var home := Vector3(1000.0, 0.0, 100.0)
var farms: Array = [Vector3(975.0, 0.0, 40.0), Vector3(1012.0, 0.0, 22.0)]
var ford := Vector3.ZERO
var roof: BuiltPiece
var got := {}


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


## Waits up to `limit` s for `cond`; the seconds it took (INF: never).
func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += dt
	return INF


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


func _put(p: Vector3) -> void:
	player.global_position = _ground(p) + Vector3.UP * 0.15
	player.velocity = Vector3.ZERO


## The player walked to `to` at `speed` (placed each tick, on the ground).
func _walk(to: Vector3, speed: float) -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var guard := 0
	while Vector2(to.x - player.global_position.x, to.z - player.global_position.z).length() > 0.3 and guard < 20000:
		var at := player.global_position
		var d := Vector3(to.x - at.x, 0.0, to.z - at.z)
		var step := minf(d.length(), speed * dt)
		_put(at + d.normalized() * step)        # (its velocity left at 0: the body's own step would move it on again)
		await physics_frame
		guard += 1


func _flat(a: Vector3, c: Vector3) -> float:
	return Vector2(a.x - c.x, a.z - c.z).length()


func _piece(type: String, at: Vector3, yaw := 0.0, lift := 0.0) -> BuiltPiece:
	var g := _ground(at)
	return world.add_piece(type, Transform3D(Basis(Vector3.UP, yaw), g + Vector3.UP * lift), true, -1)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await _ticks(60)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	b = SurvivalBridge.find(self)
	fire = FireSpread.find(self)
	world = BuildWorld.of(self)
	wild = current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	_expect(player != null and b != null and fire != null and world != null and wild != null,
			"the level has the player, the survival bridge, the fire, the building and the wildlife (survival=on wildlife=on)")
	if player == null or b == null or fire == null or world == null or wild == null:
		_end()
		return
	player.ignore_mouse_capture = true
	player.died.connect(func(_d: Vector2) -> void:
		var near := ""
		for f in NpcSenses.fighters:
			if is_instance_valid(f) and f.shots > 0:
				near += " %s(%s, %d shots, %.0f m)" % [f.name, f.state_name(), f.shots, _flat(f.global_position, player.global_position)]
		print("  (the player died at %s:%s)" % [str(player.global_position.round()), near]))
	NpcSenses.daylight_override = NpcSenses.NIGHT     # (headless has no sky clock: the fighters' night set by hand)
	player.max_health = 100000.0
	player.health = player.max_health          # (a stray ball or bite is no part of this test)
	for a in wild.animals():                   # (the land's own wolves away: the walk's are the only ones)
		if a.species == "wolf":
			wild.remove_animal(a)
	home = _ground(home)
	for i in farms.size():
		farms[i] = _ground(farms[i])
	ford = _ground(Vector3(WorldRiver.x_at(60.0), 0.0, 60.0))
	# the house the player built: a floor, four walls round it and a roof
	var c := home + Vector3(7.0, 0.0, 7.0)
	_piece("floor", c)
	_piece("wall", c + Vector3(0, 0, -1.5))
	_piece("wall", c + Vector3(0, 0, 1.5))
	_piece("wall", c + Vector3(-1.5, 0, 0), PI * 0.5)
	_piece("wall", c + Vector3(1.5, 0, 0), PI * 0.5)
	roof = _piece("roof", c, 0.0, 2.6)
	_put(home + Vector3(-3.0, 0.0, -2.0))
	b.core.state.minutes = SurvivalClock.minutes_at(b.core, "nov_mid", 1757, 1.0)
	await _ticks(10)
	var raid := await _night_and_farms()
	if raid == null:
		_end()
		return
	await _the_run(raid)
	await _capture(raid)
	var march := await _march(raid)
	if march != null:
		await _cones(march)
	await _resist()
	if march != null:
		march.queue_free()
	raid.queue_free()
	await _ticks(5)
	await _rook()
	_end()


# ---------------------------------------------------------------- the night and the farms
func _night_and_farms() -> RaidStage:
	_expect(RaidStage.persuaded(self) == 0, "with no story running nobody counts as warned")
	var raid := RaidStage.begin(current_scene, home, farms, {"neighbours": 2, "ford": ford})
	_expect(raid != null and RaidStage.find(self) == raid and raid.phase == "run", "the raid begins (the run)")
	if raid == null:
		return null
	raid.neighbour_saved.connect(func(_w: StoryWalker) -> void: got["saved"] = int(got.get("saved", 0)) + 1)
	raid.party_came.connect(func() -> void:
		got["party"] = true
		got["line"] = StoryBark.line_over(raid.leclerc)
		var far := 0.0
		for a in raid.party():
			far = maxf(far, _flat(a.global_position, player.global_position))
		got["party_far"] = far)
	raid.captured.connect(func() -> void: got["captured"] = true)
	raid.house_alight.connect(func(n: int) -> void: got["house"] = n)
	var h := SurvivalClock.hour(b.core)
	_expect(h >= 2.99 and h < 3.2, "the clock moved on to 3 a.m. (%s)" % SurvivalClock.time_string(b.core))
	await _ticks(20)
	var burning := 0
	for i in farms.size():
		var house := current_scene.get_node_or_null("RaidFarm_%d" % i)
		if house != null and fire.is_burning(house):
			burning += 1
	_expect(burning == farms.size() and raid.farm_fires >= farms.size(), "both farms alight (stand-in farmhouses: %d burning, %d caught)" % [burning, raid.farm_fires])
	var glow_ok := raid.glows.size() == farms.size()
	await _secs(2.0)
	for g in raid.glows:
		glow_ok = glow_ok and is_instance_valid(g) and (g.material_override as StandardMaterial3D).albedo_color.a > 0.0 \
				and (g.material_override as StandardMaterial3D).blend_mode == BaseMaterial3D.BLEND_MODE_ADD
	_expect(glow_ok, "an orange glow over each farm, fading in (additive)")
	var factions := {}
	var men := 0
	var holding := true
	for s in raid.squads:
		for f in s.fighters():
			factions[f.faction] = true
			men += 1
			holding = holding and f.order_kind == "hold" and f.tag == "raiders"
	_expect(factions.has("french_marine") and factions.has("canadian_militia") and men == 4 and holding,
			"real raiders at the farms, holding: %d men of %s" % [men, str(factions.keys())])
	var waiting := raid.neighbours_in("waiting")
	var crouched := true
	for e: Dictionary in raid.neighbours:
		var w := e.w as StoryWalker
		crouched = crouched and w.is_crouching and w.body != null and w.body.clip == "crouch" and w.is_in_group(RaidStage.NEIGHBOURS)
	_expect(waiting == 2 and crouched, "the two warned wait crouched in the fields (%d)" % waiting)
	_expect(raid.leclerc != null and raid.leclerc.label == RaidStage.LECLERC and raid.marines.size() == 2 and raid.leclerc.scripted,
			"the party waits out in the dark: %s and two marines, scripted" % (raid.leclerc.label if raid.leclerc else "none"))
	return raid


# ---------------------------------------------------------------- the run
func _the_run(raid: RaidStage) -> void:
	var n0 := raid.neighbours[0].w as StoryWalker
	var n1 := raid.neighbours[1].w as StoryWalker
	var to_home := (home - n1.global_position).normalized()
	_put(n1.global_position + to_home * 4.0)
	await _ticks(10)
	_expect(String(raid.neighbours[1].state) == "following" and StoryBark.line_over(n1) == RaidStage.NEIGHBOUR_LINE,
			"the player near, a neighbour gets up and follows him (%s)" % String(raid.neighbours[1].state))
	await _walk(n0.global_position + (home - n0.global_position).normalized() * 4.0, 3.0)
	await _ticks(10)
	_expect(raid.neighbours_in("following") == 2, "the other too")
	var far := 0.0
	await _walk(ford + Vector3(6.0, 0.0, 0.0), 3.0)
	for e: Dictionary in raid.neighbours:
		far = maxf(far, _flat((e.w as StoryWalker).global_position, player.global_position))
	_expect(far < 9.0, "they kept up with him to the ford (the furthest %.1f m behind)" % far)
	var t := await _until(func() -> bool: return raid.saved >= 2, 40.0)
	_expect(t < INF and int(got.get("saved", 0)) == 2, "both wade over to the far bank and are saved (%d, %.1f s)" % [raid.saved, t])
	var west := true
	for e: Dictionary in raid.neighbours:
		var w := e.w as StoryWalker
		if is_instance_valid(w):
			west = west and w.global_position.x < WorldRiver.x_at(w.global_position.z) - 10.0
	_expect(west, "on the fort's side of the river")


# ---------------------------------------------------------------- the capture and the torch
func _capture(raid: RaidStage) -> void:
	_expect(raid.phase == "run", "still the run while he is away from his clearing")
	await _walk(home + Vector3(-4.0, 0.0, -6.0), 3.2)
	var t := await _until(func() -> bool: return got.has("captured"), 30.0)
	_expect(bool(got.get("party", false)) and float(got.get("party_far", 99.0)) < 4.0,
			"the party came up and stands round him (the furthest %.1f m off)" % float(got.get("party_far", -1.0)))
	_expect(String(got.get("line", "")) == RaidStage.LINE, "Leclerc says it in French: \"%s\"" % String(got.get("line", "")))
	var cap := Captivity.find(self)
	_expect(t < INF and cap != null and cap.is_active() and cap.bound and cap.captor == raid.leclerc and cap.holding("weapons"),
			"he is taken: bound, Leclerc his captor, his weapons held (%.1f s)" % t)
	_expect(raid.torch_bearer != null and raid.torch_bearer.holding_torch() and raid.torch_bearer.torch_fire != null,
			"a marine lights a torch")
	var th := await _until(func() -> bool: return got.has("house"), 45.0)
	_expect(th < INF and int(got.get("house", 0)) >= 1 and is_instance_valid(roof) and fire.is_burning(roof),
			"he takes it to the house: the roof catches (%d pieces, %.1f s)" % [int(got.get("house", 0)), th])


# ---------------------------------------------------------------- the march
func _march(raid: RaidStage) -> MarchStage:
	var cap := Captivity.find(self)
	var start := player.global_position
	var route := MarchStage.east_bank(start, start + Vector3(12.0, 0.0, -48.0), 18.0, 40.0)
	_expect(route.size() >= 3 and route.back().x > WorldRiver.x_at(route.back().z) + 39.0, "a route up the east bank (%d points)" % route.size())
	var kit0 := SurvivalInventory.count(b.core, "item.food.biscuit")
	var min0 := b.core.state.minutes
	var march := MarchStage.begin(current_scene, route, {"leclerc": raid.leclerc, "guards": raid.guards(), "jost": true, "march_hours": 2.0})
	march.arrived.connect(func() -> void: got["arrived"] = true)
	march.crust_shared.connect(func() -> void: got["crust"] = true)
	march.seen.connect(func(g: StoryActor) -> void: got["seen_by"] = g)
	await _ticks(2)
	_expect(march.phase == "march" and march.leclerc == raid.leclerc and raid.leclerc.get_parent() == march and march.guards.size() == 2,
			"the march sets off with Leclerc and the marines handed on (%s)" % march.phase)
	_expect(march.jost != null and march.jost.size < 0.8 and march.jost.tag == "jost", "Jost beside the player")
	_expect(cap.marching and cap.captor == raid.leclerc, "Leclerc leads the forced march")
	# the player keeps up: a little behind Leclerc each tick
	var behind_max := 0.0
	var jost_max := 0.0
	var guard_max := 0.0
	var ticks := 0
	while not got.has("arrived") and ticks < 60 * 120:
		var l := march.leclerc
		var back := player.global_position - l.global_position
		back.y = 0.0
		back = back.normalized() if back.length() > 0.1 else Vector3.BACK
		_put(l.global_position + back * 1.8)
		await physics_frame
		ticks += 1
		if ticks > 240:
			behind_max = maxf(behind_max, _flat(player.global_position, l.global_position))
			jost_max = maxf(jost_max, _flat(player.global_position, march.jost.global_position))
			for g in march.guards:
				guard_max = maxf(guard_max, _flat(player.global_position, g.global_position))
	_expect(got.has("arrived"), "the march reaches the camp (%.0f s)" % (float(ticks) / 60.0))
	_expect(jost_max < 4.5 and guard_max < 12.0, "Jost kept beside him (%.1f m at most), the guards their places (%.1f m)" % [jost_max, guard_max])
	_expect(got.has("crust") and SurvivalInventory.count(b.core, "item.food.biscuit") > kit0 and raid.leclerc.last_bark == MarchStage.CRUST_LINE,
			"on the way Leclerc shares a crust (\"%s\")" % raid.leclerc.last_bark)
	var hours := (b.core.state.minutes - min0) / 60.0
	_expect(hours >= 1.95 and hours < 4.0, "the clock went on with the march: its 2 h over the metres (%.2f h with the clock's own run)" % hours)
	_expect(march.camp_fire != null and march.camp_fire.is_lit() and _flat(march.camp_fire.global_position, route.back()) < 6.0,
			"at the camp a campfire is lit")
	await _secs(5.0)
	var sat := march.guards[0].is_crouching
	_expect(sat and march.jost.is_crouching, "a guard sits at the fire, Jost too")
	return march


# ---------------------------------------------------------------- the cones
func _cones(march: MarchStage) -> void:
	var cap := Captivity.find(self)
	var g := march.guards[1]
	var fwd := g.forward()
	_put(g.global_position + fwd * 5.0)
	await _secs(0.5)
	_expect(g.sees_player() and march.guard_sees_player(), "the watch sees the player 5 m before him (lit by the fire: %s)" %
			str(StoryActor.lit_at(self, player.global_position)))
	_expect(StoryObjectives.seen_by(self) == null, "captive, nobody counts as having seen him")
	_put(g.global_position - fwd * 5.0)
	await _secs(0.5)
	_expect(not g.sees_player(), "nor behind him")
	var dummy := Node3D.new()
	current_scene.add_child(dummy)
	dummy.global_position = _ground(march.camp_fire.global_position + Vector3(60.0, 0.0, 0.0))
	var dark := g.sight_m(dummy)
	dummy.global_position = _ground(march.camp_fire.global_position + Vector3(1.5, 0.0, 0.0))
	var by_fire := g.sight_m(dummy)
	dummy.queue_free()
	_expect(is_equal_approx(dark, StoryActor.CONE_M * StoryActor.NIGHT_SHARE) and is_equal_approx(by_fire, StoryActor.CONE_M),
			"a cone reaches %.1f m into the night, %.1f m by the fire" % [dark, by_fire])
	cap.break_free()
	_put(g.global_position + fwd * 6.0)
	var t := await _until(func() -> bool: return got.has("seen_by"), 3.0)
	var by: Variant = got.get("seen_by")
	_expect(t < INF and by is StoryActor and (by as StoryActor).alerted and march.guards.has(by) and StoryObjectives.seen_by(self) is StoryActor,
			"loose, the guard that sees him is alerted and counts as having seen him")
	cap.end()
	await _ticks(2)


# ---------------------------------------------------------------- a scripted fighter struck
func _resist() -> void:
	var a := StoryActor.make(current_scene, "french_marine", player.global_position + Vector3(4.0, 0.0, 0.0), {"tag": "resist_test"})
	var woke := [false]
	a.woke.connect(func(_x: StoryActor, _by: Node) -> void: woke[0] = true)
	await _ticks(5)
	NpcSenses.noise(player.global_position, 50.0, player)
	await _ticks(10)
	_expect(a.scripted and a.state_name() == "IDLE", "a scripted marine hears a shot and stays as he was (%s)" % a.state_name())
	a.apply_hit(20.0, a.global_position + Vector3.UP * 1.2, Vector3(-1, 0, 0), player, "body")
	await _ticks(20)
	_expect(woke[0] and not a.scripted and a.state_name() == "COMBAT", "struck by the player he wakes and fights (%s)" % a.state_name())
	a.queue_free()
	await _ticks(2)


# ---------------------------------------------------------------- Rook's walk
func _rook() -> void:
	var from := player.global_position
	var toward := _ground(from + Vector3(-30.0, 0.0, 45.0))
	var walk := RookWalk.begin(current_scene, null, toward, {"wolves_after_s": 3.0})
	walk.wolves_came.connect(func(w: Array) -> void: got["wolves"] = w.size())
	walk.gust.connect(func(_t: Node3D) -> void: got["gust"] = true)
	walk.wolves_fled.connect(func() -> void: got["fled"] = true)
	walk.done.connect(func() -> void: got["done"] = true)
	await _ticks(10)
	var rook := walk.rook as StoryWalker
	_expect(rook != null and rook.tag == "rook" and not rook.casts_shadow(), "Rook walks beside him, and casts no shadow")
	var near_before := INF
	var pushed := false
	var fled_states := true
	var ticks := 0
	var gust_at := -1
	var d_at_gust := {}
	while not got.has("done") and ticks < 60 * 150:
		var side := (toward - rook.global_position).normalized().cross(Vector3.UP)
		_put(rook.global_position + side * 1.5 - (toward - rook.global_position).normalized() * 0.8)
		await physics_frame
		ticks += 1
		if got.has("gust") and gust_at < 0:
			gust_at = ticks
			for a in walk.live_wolves():
				d_at_gust[a.get_instance_id()] = _flat(a.global_position, rook.global_position)
		if gust_at > 0 and ticks == gust_at + 45:
			for a in walk.live_wolves():
				fled_states = fled_states and a.state == WildAnimal.State.FLEE
				pushed = pushed or _flat(a.global_position, rook.global_position) > float(d_at_gust.get(a.get_instance_id(), INF)) + 1.0
		if not got.has("gust"):
			for a in walk.live_wolves():
				near_before = minf(near_before, minf(_flat(a.global_position, player.global_position), _flat(a.global_position, rook.global_position)))

	_expect(int(got.get("wolves", 0)) == 3, "three wolves come (%d)" % int(got.get("wolves", 0)))
	_expect(got.has("gust") and walk.casts >= 1 and near_before <= RookWalk.GUST_AT_M + 1.0,
			"they close in (%.1f m) and Rook casts Gust (%d)" % [near_before, walk.casts])
	_expect(fled_states and pushed, "blown back, they run")
	_expect(got.has("fled"), "the pack is driven off")
	_expect(got.has("done") and _flat(rook.global_position, toward) <= RookWalk.ARRIVE_M + 1.0,
			"and the walk goes on to its end (%.0f s)" % (float(ticks) / 60.0))
	walk.queue_free()


func _end() -> void:
	NpcSenses.daylight_override = -1.0
	if fails.is_empty():
		print("RAID STAGE TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("RAID STAGE TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
