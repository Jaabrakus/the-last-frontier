extends SceneTree
## Fishing (FishingGear, FishCatch; user 2026-09-28: "for fishing have all those options"). Headless, fixed rate:
##
##   Godot --headless --path . --fixed-fps 60 -s tests/fishing/test_fishing.gd -- survival=on survival_seed=7
##
##   pack     a landed fish goes into the pack by the pound, its species' own kind (at least one)
##   gear     the rod comes out on the gear button's take_out, the hands free
##   cast     held and let go toward the river, the float lands in the water, a worm under it, drifting down
##   catch    a hungry trout below the float takes the worm; struck in time the hook holds; played as one watching
##            the line's tension would (the rod drawn back while the line is easy, lowered as it comes tight), the rod
##            bowed toward it, the line never breaking, it tires, is led in and landed into the pack (and one fewer in
##            the numbers)
##   snap     a fresh salmon hooked and the rod yanked back hard: the line snaps
##   aim      the cast held: its ring wide as the rod goes back, closing in held steady, wider on the move; a float
##            landing on a trout's head puts it down, one cast well above it does not
##   drink    on the bank the river offers a drink (E's prompt); with the rod out it does not, put away it does again
##   skill    Trapping and Fishing (the survival rules'): the trout landed raised it; at 100 the cast's ring is tighter
##            and the line takes more before it breaks
##   cook     the fire takes the fish first (CampCooking.raw_kind), roasting into roast fish
## Ends with "FISHING TEST PASSED (<n> checks)" or "FISHING TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var g: FishingGear
var life: FishLife


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await _fr(20)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	life = FishLife.find(self)
	g = FishingGear.find(p)
	_expect(life != null and g != null, "gear: the level has its fish and the fishing gear")
	if life and g:
		_pack()
		await _catch()
		_cook()
	if fails.is_empty():
		print("FISHING TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("FISHING TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await process_frame


func _count(kind: String) -> int:
	return InventoryState.from_player(p).pack_count(kind)


func _pack() -> void:
	var t0 := _count("brook_trout")
	var s0 := _count("salmon")
	FishCatch.to_pack(p, {"species": "brook_trout", "name": "brook trout", "length": 0.25, "lb": 0.3})
	FishCatch.to_pack(p, {"species": "salmon", "name": "Atlantic salmon", "length": 0.75, "lb": 8.4})
	_expect(_count("brook_trout") == t0 + 1 and _count("salmon") == s0 + 8,
			"pack: a small trout gives a pound, a salmon of 8.4 lb eight (%d, %d)" % [_count("brook_trout") - t0, _count("salmon") - s0])
	var inv := InventoryState.from_player(p)
	inv.take("brook_trout", 1)
	inv.take("salmon", 8)
	p.inventory_pack = inv.pack.duplicate(true)


func _edge(z: float, side: float) -> float:
	var cx := WorldRiver.x_at(z)
	var o := 0.0
	while life.depth(cx + side * (o + 0.25), z) > 0.0 and o < 14.0:
		o += 0.25
	return cx + side * o


func _catch() -> void:
	life.restock_on = false
	life.hour_override = 19.0
	life.month_override = 6
	for f in life.fish:
		f.gone = true
	life._sweep()
	var z := -140.0
	var ex := _edge(z, 1.0)
	var at := Vector3(ex + 1.0, 0.0, z)
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	p.global_position = at
	p.rotation.y = atan2(1.0, 0.0)
	p.yaw = p.rotation.y
	# crouched on the bank, as an angler keeps low (the trout would see one standing this near and bolt)
	p.set_crouched(true)
	await _fr(20)
	var river := current_scene.get_node_or_null("River") as RiverWater
	var drink_before := river.interact_prompt(p) if river else ""
	var core := SurvivalBridge.find(self).core if SurvivalBridge.find(self) else null
	var skill_before := SurvivalSkills.level(core, "trapping") if core else -1.0
	g.give("fishing_rod")
	var out := g.take_out("fishing_rod")
	await _fr(10)
	_expect(out and g.gear == "fishing_rod" and p.hands_free, "gear: the rod out, the hands free")
	var drink_out := river.interact_prompt(p) if river else "?"
	_expect(drink_before != "" and drink_out == "",
			"drink: on the bank the river offers '%s'; with the rod out, nothing ('%s')" % [drink_before, drink_out])
	# cast: held, let go, toward a point 5 m out, a little upstream
	var landed := []
	g.cast_landed.connect(func(pos, wet): landed.append(wet))
	var target := Vector3(ex - 4.0, 0.0, z - 2.0)
	g.aim_override = target
	g.fire_override = 1
	await _fr(40)
	g.fire_override = 0
	var t := 0.0
	while landed.is_empty() and t < 5.0:
		await process_frame
		t += 1.0 / 60.0
	_expect(not landed.is_empty() and landed[0] and g.rod_state == FishingGear.Rod.DRIFT and g.bait != null,
			"cast: the float lands in the water, the worm under it (%s)" % FishingGear.Rod.keys()[g.rod_state])
	if g.bait == null:
		return
	# a hungry trout a little below the float, facing up into the current
	var fz := g.float_pos.z + WorldRiver.flow_at(g.float_pos.z).z * 2.2
	var fx := g.float_pos.x + WorldRiver.flow_at(g.float_pos.z).x * 2.2
	var trout := life.spawn_fish("brook_trout", Vector3(fx, 0.0, fz))
	trout.pos.y = life.layer_y(trout, fx, fz)
	trout.lie = trout.pos
	trout.goal = trout.pos
	trout.state = FishLife.State.HOLD
	trout.base = FishLife.State.HOLD
	trout.hunger = 1.0
	var n0 := float(life._stock_here().pop.brook_trout)
	var p0 := _count("brook_trout")
	t = 0.0
	while g.rod_state != FishingGear.Rod.BITE and t < 20.0 and g.bait != null:
		await process_frame
		t += 1.0 / 60.0
	var bit := g.rod_state == FishingGear.Rod.BITE
	# strike
	var struck := []
	g.struck.connect(func(ok): struck.append(ok))
	g.fire_override = 1
	await _fr(3)
	_expect(bit and not struck.is_empty() and struck[0] and g.rod_state == FishingGear.Rod.FIGHT,
			"catch: the trout takes the drifting worm (%.1f s; trout %s, %.1f m from the angler), struck in time the hook holds" % [
			t, FishLife.State.keys()[trout.state], Vector2(trout.pos.x - p.global_position.x, trout.pos.z - p.global_position.z).length()])
	g.fire_override = 0
	# played: the rod drawn back while the line is easy, lowered toward the fish as it comes tight
	var got := []
	var broke := []
	g.fish_landed.connect(func(info): got.append(info))
	g.line_broke.connect(func(): broke.append(true))
	t = 0.0
	var most := 0.0
	var most_bend := 0.0
	while got.is_empty() and broke.is_empty() and t < 60.0 and g.rod_state in [FishingGear.Rod.FIGHT, FishingGear.Rod.LAND]:
		if g.rod_state == FishingGear.Rod.FIGHT:
			g.pull_by((0.5 if g.tension < 0.55 else (-1.2 if g.tension > 0.8 else 0.0)) / 60.0)
			most = maxf(most, g.tension)
			most_bend = maxf(most_bend, g.bend)
		await process_frame
		t += 1.0 / 60.0
	await _fr(5)
	_expect(broke.is_empty() and most_bend > 0.3,
			"catch: played on the rod, bowed toward the trout (most %.2f), the line held (most tension %.2f of its break)" % [most_bend, most])
	_expect(not got.is_empty() and _count("brook_trout") > p0 and float(life._stock_here().pop.brook_trout) == n0 - 1.0,
			"catch: led in and tired, landed into the pack (%d lb in %.0f s), one fewer in the numbers" % [_count("brook_trout") - p0, t])
	_expect(g.rod_state == FishingGear.Rod.READY and p.kneeling == null, "catch: up again, the rod ready")
	var skill_after := SurvivalSkills.level(core, "trapping") if core else -1.0
	_expect(core != null and skill_after > skill_before,
			"skill: the strike and the trout landed raised Trapping and Fishing (%.2f -> %.2f)" % [skill_before, skill_after])
	await _snap(ex, z)
	await _aim(ex, z)
	await _skill(ex, z)
	g.put_away()
	await _fr(10)
	var drink_after := river.interact_prompt(p) if river else ""
	_expect(drink_after != "", "drink: the rod put away, the river offers a drink again ('%s')" % drink_after)


## The cast's skill: steadiness closes its ring, moving opens it; its splash puts down a fish it lands on.
func _aim(ex: float, z: float) -> void:
	for f in life.fish:
		f.gone = true
	life._sweep()
	if g.rod_state != FishingGear.Rod.READY:
		g.fire_override = 1
		await _fr(3)
		g.fire_override = 0
		await _fr(30)
	var spot := Vector3(ex - 4.5, 0.0, z - 1.0)
	g.aim_override = spot
	g.fire_override = 1
	await _fr(9)
	var s0 := g.spread
	await _fr(60)
	var s1 := g.spread
	Input.action_press(&"move_back")
	await _fr(40)
	var s2 := g.spread
	Input.action_release(&"move_back")
	_expect(s1 < s0 * 0.6 and s2 > s1 * 1.3,
			"aim: the ring closes in held steady (%.2f m -> %.2f m) and opens on the move (%.2f m)" % [s0, s1, s2])
	g.fire_override = 0
	await _fr(60)
	# lift it out, then a trout where the next float comes down, and one cast well above another
	g.fire_override = 1
	await _fr(3)
	g.fire_override = 0
	await _fr(40)
	var put_down := []
	for pair in [[0.0, "on"], [4.0, "above"]]:
		var flow := WorldRiver.flow_at(spot.z)
		var fl := Vector2(flow.x, flow.z).normalized()
		var fx := spot.x + fl.x * float(pair[0])
		var fz := spot.z + fl.y * float(pair[0])
		var trout := life.spawn_fish("brook_trout", Vector3(fx, 0.0, fz))
		trout.pos.y = life.layer_y(trout, fx, fz)
		trout.lie = trout.pos
		trout.goal = trout.pos
		trout.state = FishLife.State.HOLD
		trout.base = FishLife.State.HOLD
		trout.hunger = 0.0
		await _fr(20)
		g.aim_override = spot
		g.fire_override = 1
		await _fr(70)
		g.fire_override = 0
		var t := 0.0
		while g.rod_state != FishingGear.Rod.DRIFT and t < 3.0:
			await process_frame
			t += 1.0 / 60.0
		await _fr(50)
		put_down.append(trout.state in [FishLife.State.FLEE, FishLife.State.HIDE])
		g.fire_override = 1
		await _fr(3)
		g.fire_override = 0
		await _fr(40)
		trout.gone = true
		life._sweep()
	_expect(put_down.size() == 2 and put_down[0] and not put_down[1],
			"aim: a float landing on a trout's head puts it down (%s), one cast 4 m above it does not (%s)" % [
			put_down[0] if put_down.size() > 0 else "-", put_down[1] if put_down.size() > 1 else "-"])


## Trapping and Fishing at 100 against a novice: the cast held as long, its ring tighter; the line stronger.
func _skill(ex: float, z: float) -> void:
	var rings := []
	for lvl in [0.0, 100.0]:
		g.skill_override = lvl
		if g.rod_state != FishingGear.Rod.READY:
			g.fire_override = 1
			await _fr(3)
			g.fire_override = 0
			await _fr(40)
		g.aim_override = Vector3(ex - 4.5, 0.0, z - 1.0)
		g.fire_override = 1
		await _fr(70)
		rings.append(g.spread)
		g.fire_override = 0
		await _fr(60)
	var strong := g.line_strength()
	g.skill_override = 0.0
	var weak := g.line_strength()
	g.skill_override = -1.0
	_expect(rings.size() == 2 and rings[1] < rings[0] * 0.6 and strong > weak * 1.3,
			"skill: at 100 the ring is tighter (%.2f m, a novice's %.2f m) and the line takes %.2f times as much" % [
			rings[1] if rings.size() > 1 else -1.0, rings[0] if rings.size() > 0 else -1.0, strong / weak])


## A fresh salmon on and the rod yanked back hard: the line goes.
func _snap(ex: float, z: float) -> void:
	var landed := []
	g.cast_landed.connect(func(pos, wet): landed.append(wet))
	g.aim_override = Vector3(ex - 4.0, 0.0, z - 2.0)
	g.fire_override = 1
	await _fr(40)
	g.fire_override = 0
	var t := 0.0
	while landed.is_empty() and t < 5.0:
		await process_frame
		t += 1.0 / 60.0
	if g.bait == null:
		_expect(false, "snap: cast again (%s)" % FishingGear.Rod.keys()[g.rod_state])
		return
	var fz := g.float_pos.z + WorldRiver.flow_at(g.float_pos.z).z * 2.2
	var fx := g.float_pos.x + WorldRiver.flow_at(g.float_pos.z).x * 2.2
	var salmon := life.spawn_fish("salmon", Vector3(fx, 0.0, fz))
	salmon.lb = 10.0
	salmon.pos.y = life.layer_y(salmon, fx, fz)
	salmon.lie = salmon.pos
	salmon.goal = salmon.pos
	salmon.state = FishLife.State.HOLD
	salmon.base = FishLife.State.HOLD
	salmon.hunger = 1.0
	# (it has the worm: a salmon's take is FishLife's, as the trout's above)
	salmon.bait = g.bait
	g.bait.fish = salmon
	salmon.state = FishLife.State.BITTEN
	salmon.t = 0.0
	g._on_bite(salmon, g.bait)
	g.fire_override = 1
	await _fr(3)
	g.fire_override = 0
	if g.rod_state != FishingGear.Rod.FIGHT or g.bait == null or g.bait.fish != salmon:
		_expect(false, "snap: a salmon on (%s, %.1f s)" % [FishingGear.Rod.keys()[g.rod_state], t])
		return
	var broke := []
	g.line_broke.connect(func(): broke.append(true))
	g.pull_by(1.0)
	t = 0.0
	var most := 0.0
	while broke.is_empty() and t < 4.0:
		most = maxf(most, g.tension)
		await process_frame
		t += 1.0 / 60.0
	_expect(not broke.is_empty() and g.rod_state == FishingGear.Rod.READY and g.bait == null,
			"snap: a fresh salmon (10 lb) yanked hard, the line snaps (in %.1f s, tension up to %.2f)" % [t, most])


func _cook() -> void:
	var b := SurvivalBridge.find(self)
	if b == null or b.cook == null:
		_expect(false, "cook: the survival bridge's cooking (run with survival=on)")
		return
	var inv := InventoryState.from_player(p)
	inv.add("venison", 1)
	inv.add("perch", 2)
	p.inventory_pack = inv.pack.duplicate(true)
	var k := b.cook.raw_kind(p)
	_expect(k == "perch" or FishCatch.is_fish(k), "cook: the fire takes the fish first (%s)" % k)
	_expect(String(CampCooking.COOKED.get("perch", {}).get("cooked", "")) == "roast_fish" and b.items.has("roast_fish"),
			"cook: fish roasts into roast fish, a pack kind of the core's cooked fish")
