extends SceneTree
## The fish (FishSpecies, FishMesh, FishStock, FishLife; user 2026-09-27: "add a fish powerlevel with different types of
## fish", "we should have actual fish in the ponds and rivers with there own intelligence we mimic and try to catch").
## Headless, at a fixed rate:
##
##   Godot --headless --path . --fixed-fps 60 -s tests/wildlife/test_fish.gd
##
##   species     nine, each with a body and skin; each water its own (the river's eight, the marsh's pickerel)
##   numbers     runs by the month (salmon in the fall, sturgeon in May and June, none out of them); fished out, a
##               species comes back to its floor (never gone); catches make the water warier, which fades; saved
##   in water    at the river, its fish to the numbers (its share for the stretch near the player), all in the water
##               and under its top; the holders facing into the current
##   hatch       an evening in June the trout rise (rings); eels hidden by day, out at night
##   wary        a trout lets one standing still on the bank near it put it down, not one crouched as near, nor one
##               standing behind it (below it); bolting it hides; its school bolts with a perch put down
##   predator    a hungry pike strikes the perch in front of it, taking one off the numbers
##   salmon      a salmon in its run, set at the rapid above its pool, leaps it
##   bait        a worm drifting naturally to a hungry trout is taken; dragged across the current it is refused; the hook
##               set in time holds it, it fights and tires, and landed it is one fewer in the numbers; not set in time
##               it is spat out and the fish warier
## Ends with "FISH TEST PASSED (<n> checks)" or "FISH TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var life: FishLife


func _initialize() -> void:
	_species()
	_numbers()
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await _fr(20)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	life = current_scene.get_node_or_null("Fish") as FishLife
	_expect(life != null, "in water: the level has its fish")
	if life:
		life.hour_override = 12.0
		life.month_override = 9
		await _in_water()
		await _hatch()
		life.restock_on = false
		await _wary()
		await _predator()
		await _salmon()
		await _bait()
	if fails.is_empty():
		print("FISH TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("FISH TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await process_frame


func _secs(s: float) -> void:
	await _fr(int(s * 60.0))


func _species() -> void:
	var ids := FishSpecies.ids()
	var built := 0
	for id in ids:
		var m := FishMesh.mesh(id)
		var mat := FishMesh.material(id)
		if m and m.get_surface_count() > 0 and m.surface_get_array_len(0) > 1000 and mat and mat.get_shader_parameter("albedo_tex") != null:
			built += 1
	var river := FishSpecies.water_caps("river")
	_expect(ids.size() == 9 and built == 9, "species: nine, each with a body and skin (%d of %d)" % [built, ids.size()])
	_expect(river.size() == 8 and FishSpecies.water_caps("marsh").has("pickerel") and not river.has("pickerel"),
			"species: each water its own (the river's %d; pickerel in the marsh only)" % river.size())


func _numbers() -> void:
	var s := FishStock.new("river", 9)
	var sal_sep := s.cap_now("salmon", 10)
	var sal_jan := s.cap_now("salmon", 1)
	var stu_may := s.cap_now("sturgeon", 5)
	var stu_aug := s.cap_now("sturgeon", 8)
	_expect(sal_sep > 60.0 and sal_jan < 6.0 and stu_may > 7.0 and stu_aug == 0.0,
			"numbers: runs by the month (salmon Oct %.0f, Jan %.1f; sturgeon May %.0f, Aug %.0f)" % [sal_sep, sal_jan, stu_may, stu_aug])
	# fished out
	for i in 200:
		s.take("brook_trout")
	var none := float(s.pop.brook_trout)
	var w := s.wary
	s.advance(10.0, 7)
	var back := float(s.pop.brook_trout)
	s.advance(50.0, 7)
	var later := float(s.pop.brook_trout)
	_expect(none == 0.0 and back > 2.0 and later >= s.floor_of("brook_trout", 7) - 0.01,
			"numbers: the trout fished out (%.0f) come back (%.1f in ten days, %.1f in sixty: their floor), never gone" % [none, back, later])
	_expect(w >= 0.99 and s.wary < w and int(s.caught.brook_trout) == 200,
			"numbers: catches make the water warier (%.2f), fading with the days (%.2f)" % [w, s.wary])
	# out of the run, the salmon go
	var r := FishStock.new("river", 10)
	var before := float(r.pop.salmon)
	r.advance(40.0, 1)
	_expect(before > 55.0 and float(r.pop.salmon) < 8.0, "numbers: the salmon leave after their run (%.0f to %.1f)" % [before, float(r.pop.salmon)])
	# saved with the land
	var land := WildlifeLand.new()
	var sq := Vector2i(1, 0)
	var fs: FishStock = land.fish.get(sq)
	var ok := fs != null
	if fs:
		fs.pop.perch = 12.5
		fs.wary = 0.4
		var land2 := WildlifeLand.new()
		land2.from_dict(land.to_dict())
		var f2: FishStock = land2.fish.get(sq)
		ok = f2 != null and is_equal_approx(float(f2.pop.perch), 12.5) and is_equal_approx(f2.wary, 0.4)
	_expect(ok and land.fish.size() >= 5, "numbers: every square with fish water has its numbers (%d), saved with the land" % land.fish.size())


func _put(at: Vector3, facing := Vector3.FORWARD) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.yaw = atan2(-facing.x, -facing.z)
	p.rotation.y = p.yaw


func _in_water() -> void:
	# on the bank at z 0: the stretch fills
	var z := 0.0
	_put(Vector3(WorldRiver.x_at(z) + 16.0, 0.0, z))
	await _secs(3.0)
	var st := life._stock_here()
	var zr := WorldRiver.z_range()
	var share := (minf(z + FishLife.NEAR_M, zr.y) - maxf(z - FishLife.NEAR_M, zr.x)) / (zr.y - zr.x)
	var want := 0.0
	for s: String in st.caps:
		want += round(float(st.pop[s]) * share)
	var kinds := {}
	var wet := 0
	for f in life.fish:
		kinds[f.sp] = true
		var d := life.depth(f.pos.x, f.pos.z)
		if (d > 0.1 and f.pos.y < life.surface(f.pos.z) and f.pos.y > life.bed(f.pos.x, f.pos.z)) or f.hidden:
			wet += 1
	_expect(absf(life.fish.size() - want) <= 4.0 and kinds.size() >= 5,
			"in water: the fish to the numbers (%d for %.0f), %d species" % [life.fish.size(), want, kinds.size()])
	_expect(wet == life.fish.size(), "in water: all in the water, under its top (%d of %d)" % [wet, life.fish.size()])
	await _secs(4.0)
	var holders := 0
	var upstream := 0
	for f in life.fish:
		if f.state == FishLife.State.HOLD:
			holders += 1
			if f.forward().dot(-WorldRiver.flow_at(f.pos.z)) > 0.7:
				upstream += 1
	_expect(holders > 0 and upstream >= int(holders * 0.8), "in water: the holders face into the current (%d of %d)" % [upstream, holders])


func _hatch() -> void:
	life.hour_override = 19.5
	life.month_override = 6
	var r0 := life.rises
	await _secs(25.0)
	_expect(life.rises > r0 and life.rings.size() > 0 or life.rises > r0 + 2,
			"hatch: an evening in June the trout rise (%d rises, %d bugs on the water)" % [life.rises - r0, life.bugs.size()])
	life.hour_override = 12.0
	await _secs(2.0)
	await _secs(25.0)
	var eels := 0
	var hid := 0
	for f in life.fish:
		if f.sp == "eel":
			eels += 1
			if f.hidden:
				hid += 1
	life.hour_override = 23.5
	await _secs(3.0)
	var out := 0
	for f in life.fish:
		if f.sp == "eel" and not f.hidden:
			out += 1
	_expect(eels > 0 and hid == eels and out > 0, "hatch: eels hidden by day (%d of %d), out at night (%d)" % [hid, eels, out])
	life.hour_override = 12.0
	life.month_override = 9


## Only the given fish in the water.
func _clear() -> void:
	for f in life.fish:
		f.gone = true
	life._sweep()
	life._alarms.clear()


func _trout_at(z: float, dx := 2.0) -> FishLife.Fish:
	var x := WorldRiver.x_at(z) + dx
	var f := life.spawn_fish("brook_trout", Vector3(x, 0.0, z))
	f.pos.y = life.layer_y(f, x, z)
	f.lie = f.pos
	f.goal = f.pos
	f.state = FishLife.State.HOLD
	f.base = FishLife.State.HOLD
	f.hunger = 0.2
	return f


## Where the water ends going out from the river's middle at z to one side (+1 / -1).
func _edge(z: float, side: float) -> float:
	var cx := WorldRiver.x_at(z)
	var o := 0.0
	while life.depth(cx + side * (o + 0.25), z) > 0.0 and o < 14.0:
		o += 0.25
	return cx + side * o


func _wary() -> void:
	_clear()
	var z := -60.0
	var up := -WorldRiver.flow_at(z)
	# a trout 4 m in from the water's edge; one on the bank beside it, half a metre from the edge, standing still
	var ex := _edge(z, 1.0)
	var f := _trout_at(z, ex - 4.0 - WorldRiver.x_at(z))
	var at := Vector3(ex + 0.5, 0.0, z)
	_put(at)
	p.set_crouched(false)
	await _secs(1.0)
	var stood := f.state == FishLife.State.FLEE or f.state == FishLife.State.HIDE
	# the same, crouched
	_clear()
	_put(Vector3(at.x + 40.0, 0.0, at.z))
	await _fr(5)
	var g := _trout_at(z, ex - 4.0 - WorldRiver.x_at(z))
	p.set_crouched(true)
	await _fr(5)
	_put(at)
	await _secs(1.5)
	var crouched := g.state == FishLife.State.FLEE or g.state == FishLife.State.HIDE
	p.set_crouched(false)
	# a trout near the edge; one standing on the bank 4 m below it (behind it), then 4 m above it (in front)
	_clear()
	_put(Vector3(at.x + 40.0, 0.0, at.z))
	await _fr(5)
	var h := _trout_at(z, ex - 1.6 - WorldRiver.x_at(z))
	var zb := z - up.z * 4.0
	_put(Vector3(_edge(zb, 1.0) + 0.5, 0.0, zb))
	await _secs(1.5)
	var from_behind := h.state == FishLife.State.FLEE or h.state == FishLife.State.HIDE
	var zf := z + up.z * 4.0
	_put(Vector3(_edge(zf, 1.0) + 0.5, 0.0, zf))
	await _secs(1.5)
	var from_front := h.state == FishLife.State.FLEE or h.state == FishLife.State.HIDE
	_expect(stood and not crouched, "wary: a trout bolts from one standing on the bank %.1f m off, not from one crouched there" % Vector2(at.x - f.lie.x, at.z - f.lie.z).length())
	_expect(not from_behind and from_front, "wary: nor from one standing 4 m below it (behind it); from one 4 m above it, yes")
	var hid := h.state == FishLife.State.HIDE or h.state == FishLife.State.FLEE
	await _secs(2.0)
	_expect(hid and h.state == FishLife.State.HIDE and h.wary > 0.5, "wary: bolted, it hides (%s)" % FishLife.State.keys()[h.state])
	# a school goes with one of it
	_clear()
	_put(Vector3(WorldRiver.x_at(z) + 60.0, 0.0, z))
	await _fr(5)
	var n := life.spawn_school("perch", 6, z, 10.0)
	await _secs(1.0)
	var school: Array = []
	for o in life.fish:
		if o.sp == "perch":
			school.append(o)
	life._spook(school[0], (school[0] as FishLife.Fish).pos + Vector3(1.0, 0.0, 0.0))
	await _secs(0.6)
	var gone := 0
	for o: FishLife.Fish in school:
		if o.state == FishLife.State.FLEE or o.state == FishLife.State.HIDE:
			gone += 1
	_expect(n >= 4 and gone == school.size(), "wary: a perch put down, its school bolts with it (%d of %d)" % [gone, school.size()])


func _predator() -> void:
	_clear()
	life.hour_override = 7.0
	var z := 150.0
	_put(Vector3(WorldRiver.x_at(z) + 60.0, 0.0, z))
	var x := WorldRiver.x_at(z) + 3.0
	var pike := life.spawn_fish("pike", Vector3(x, 0.0, z))
	pike.pos.y = life.layer_y(pike, x, z)
	pike.lie = pike.pos
	pike.goal = pike.pos
	pike.length = 0.8
	pike.hunger = 1.0
	pike.state = FishLife.State.AMBUSH
	pike.base = FishLife.State.AMBUSH
	var st := life._stock_here()
	var perch0 := float(st.pop.perch)
	var k0 := life.kills
	var t := 0.0
	while life.kills == k0 and t < 40.0:
		# perch come by in front of it
		var n := 0
		for o in life.fish:
			if o.sp == "perch":
				n += 1
		if n == 0:
			var fw := pike.forward()
			for i in 3:
				var at := pike.pos + fw * (0.9 + 0.2 * i) + Vector3(0.1 * i, 0.0, 0.0)
				var o := life.spawn_fish("perch", Vector3(at.x, pike.pos.y, at.z))
				if o:
					o.state = FishLife.State.HOLD
					o.base = FishLife.State.HOLD
					o.lie = o.pos
					o.goal = o.pos
					o.length = 0.2
		pike.hunger = 1.0
		await _fr(6)
		t += 0.1
	_expect(life.kills > k0 and float(st.pop.perch) < perch0, "predator: a hungry pike strikes the perch in front of it (%.0f s), one fewer in the numbers (%.1f to %.1f)" % [t, perch0, float(st.pop.perch)])
	life.hour_override = 12.0


func _salmon() -> void:
	_clear()
	life.month_override = 10
	var r: Dictionary = WorldRiver.rapids()[1]
	var z := float(r.z) + float(r.length) * 0.5 + 10.0
	_put(Vector3(WorldRiver.x_at(z) + 60.0, 0.0, z))
	var x := WorldRiver.x_at(z)
	var s := life.spawn_fish("salmon", Vector3(x, 0.0, z))
	s.pos.y = life.layer_y(s, x, z)
	s.lie = s.pos
	s.goal = s.pos
	s.state = FishLife.State.HOLD
	var ran := life._start_run(s)
	var l0 := life.leaps
	var t := 0.0
	var high := -INF
	while life.leaps == l0 and t < 45.0:
		await _fr(6)
		t += 0.1
	var t2 := 0.0
	while t2 < 1.5:
		high = maxf(high, s.pos.y - life.surface(s.pos.z))
		await process_frame
		t2 += 1.0 / 60.0
	_expect(ran and life.leaps > l0 and high > 0.2, "salmon: in its run, set at the rapid above its pool, it leaps it (%.0f s, %.2f m clear)" % [t, high])
	life.month_override = 9


func _bait() -> void:
	_clear()
	life.hour_override = 19.0
	life.month_override = 6
	var z := -150.0
	_put(Vector3(WorldRiver.x_at(z) + 60.0, 0.0, z))
	await _fr(5)
	var st := life._stock_here()
	# a natural drift
	var f := _trout_at(z, 1.0)
	f.hunger = 1.0
	var bitten := []
	var cb := func(fish, bait): bitten.append([fish, bait])
	life.bite.connect(cb)
	var b := FishLife.Bait.new()
	b.kind = "worm"
	b.natural = 1.0
	b.pos = f.pos + (-WorldRiver.flow_at(z)) * 3.0 + Vector3(0.0, 0.05, 0.0)
	life.add_bait(b)
	var t := 0.0
	while bitten.is_empty() and t < 12.0:
		if b.fish == null:
			b.pos += life.current_at(b.pos) / 60.0 * 6.0
		await _fr(6)
		t += 0.1
	var took: bool = not bitten.is_empty() and bitten[0][0] == f
	_expect(took, "bait: a worm drifting down naturally to a hungry trout is taken (%.1f s)" % t)
	# struck in time: hooked, fights, tires, landed
	var hooked := life.set_hook(b)
	var s0 := f.stamina
	var fought := false
	t = 0.0
	var angler := Vector3(WorldRiver.x_at(z) + 6.0, f.pos.y, z)
	while f.stamina > 0.05 and t < 40.0:
		b.pull = (angler - f.pos).normalized() * 0.5
		if b.tension > 0.1:
			fought = true
		await _fr(6)
		t += 0.1
	var trout0 := float(st.pop.brook_trout)
	var caught := life.land_fish(b)
	_expect(hooked and fought and s0 == 1.0 and f.stamina <= 0.05, "bait: the hook set in time holds it; it fights, and tires (%.0f s)" % t)
	_expect(caught.get("species", "") == "brook_trout" and float(st.pop.brook_trout) == trout0 - 1.0 and not life.fish.has(f),
			"bait: landed (%s, %.2f m, %.1f lb), one fewer in the numbers" % [caught.get("name", "?"), float(caught.get("length", 0.0)), float(caught.get("lb", 0.0))])
	life.remove_bait(b)
	# dragged across the current
	_clear()
	var g := _trout_at(z + 20.0, 1.0)
	g.hunger = 1.0
	bitten.clear()
	var d := FishLife.Bait.new()
	d.kind = "worm"
	d.natural = 0.15
	d.pos = g.pos + (-WorldRiver.flow_at(z)) * 1.5
	life.add_bait(d)
	var r0 := life.refusals
	t = 0.0
	var side := Vector3(-WorldRiver.flow_at(z).z, 0.0, WorldRiver.flow_at(z).x)
	while t < 10.0:
		d.pos = g.pos + (-WorldRiver.flow_at(z)) * 1.5 + side * sin(t * 2.0) * 1.5
		await _fr(6)
		t += 0.1
	_expect(bitten.is_empty() and life.refusals > r0, "bait: dragged across the current, it is refused (%d refusals, no take)" % (life.refusals - r0))
	life.remove_bait(d)
	# not struck: spat out
	_clear()
	var h := _trout_at(z + 40.0, 1.0)
	h.hunger = 1.0
	bitten.clear()
	var e := FishLife.Bait.new()
	e.kind = "worm"
	e.pos = h.pos + (-WorldRiver.flow_at(z)) * 3.0
	life.add_bait(e)
	t = 0.0
	while bitten.is_empty() and t < 12.0:
		if e.fish == null:
			e.pos += life.current_at(e.pos) / 60.0 * 6.0
		await _fr(6)
		t += 0.1
	await _secs(1.5)
	_expect(not bitten.is_empty() and e.fish == null and h.wary > 0.5 and h.refused >= 1,
			"bait: taken and not struck in time, it is spat out, the trout warier (%.2f)" % h.wary)
	life.remove_bait(e)
	life.bite.disconnect(cb)
