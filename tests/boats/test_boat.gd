extends SceneTree
## The small boats (Boat, WaterSurface, data/boats/boats.json; user 2026-09-29: "a rowboat and battle canoes"), headless on the
## river's numbers alone, no level:
##   Godot --headless --path . -s tests/boats/test_boat.gd
##   float      each boat put on the river sits at its surface, level along it
##   drift      unmanned, the current carries it downstream; faster in a rapid
##   stroke     the crew's strokes take it to about its max speed; the bigger crew of a war canoe is faster; backing water is slower
##   steer      steering turns it the right way; it turns while it has way on; astern the other way
##   ground     a boat run onto the bank is held by it and scraped in the shallows; it never leaves the water for the land
##   data       every boat in the data has what the physics reads
## Ends with "BOAT TEST PASSED (<n> checks)" or "BOAT TEST FAILED (<f> of <n>)".
var checks := 0
var fails: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


## A boat on the river's centre line at z, facing downstream.
func _on_river(id: String, z: float, crew := -1) -> Boat:
	var x := WorldRiver.x_at(z)
	var b := Boat.make(id, Vector3(x, 0.0, z), atan2(WorldRiver.flow_at(z).x, WorldRiver.flow_at(z).z))
	if crew > 0:
		b.crew_on = crew
	b.spec = Boat.spec_of(id)
	b.vel = WaterSurface.current_at(x, z)   # afloat, it goes with the water
	b._settle()
	return b


## Runs it `secs` keeping it in the river: steered at the centre line a little ahead of it.
func _follow(b: Boat, secs: float) -> void:
	for i in int(secs * 60.0):
		var ahead := b.position.z + 18.0
		var dx := WorldRiver.x_at(ahead) - b.position.x
		var want := atan2(dx, 18.0)
		var err := wrapf(want - b.rotation.y, -PI, PI)
		b.steer = clampf(err * 2.5, -1.0, 1.0)
		b.step(1.0 / 60.0)


func _run(b: Boat, secs: float) -> void:
	for i in int(secs * 60.0):
		b.step(1.0 / 60.0)


func _initialize() -> void:
	# a stretch clear of the rapids (at z = -250, 60, 300)
	var z0 := -120.0
	_expect(WaterSurface.NO_WATER == -INF, "the water is there to float on")
	_expect(WorldRiver.has_water(), "the river has water")
	for id in Boat.ids():
		var sp := Boat.spec_of(id)
		var ok := true
		for k in ["length", "beam", "draft", "mass_kg", "crew", "stroke_n", "stroke_s", "max_mps", "turn_dps", "drag", "side_drag", "ground_drag"]:
			ok = ok and sp.has(k)
		_expect(ok, "%s has all of its numbers" % id)
		var b := _on_river(id, z0)
		var lvl := WaterSurface.surface_at(b.position.x, b.position.z)
		_expect(lvl != WaterSurface.NO_WATER and absf(b.position.y - (lvl - float(sp.draft) * 0.3)) < 0.06, "%s floats at the surface (y %.2f, water %.2f)" % [id, b.position.y, lvl])
		b.free()
	# drift
	var d := _on_river("rowboat", z0)
	var z_before := d.position.z
	_run(d, 20.0)
	var down := d.position.z - z_before
	_expect(down > 5.0 and down < 14.0, "unmanned it drifts downstream with the current (%.1f m in 20 s)" % down)
	_expect(absf(d.position.x - WorldRiver.x_at(d.position.z)) < 14.0, "and stays in the river")
	var rz := -250.0
	var r := _on_river("birchbark", rz - 45.0)
	var r_before := r.position.z
	_run(r, 8.0)
	var slow_run := r.position.z - r_before
	var r2 := _on_river("birchbark", z0)
	var r2_before := r2.position.z
	_run(r2, 8.0)
	_expect(WaterSurface.current_at(r.position.x, rz).length() > WaterSurface.current_at(r2.position.x, z0).length() * 2.0, "the current is faster in a rapid (%.2f against %.2f m/s)" % [WaterSurface.current_at(WorldRiver.x_at(rz), rz).length(), WaterSurface.current_at(WorldRiver.x_at(z0), z0).length()])
	_expect(is_finite(slow_run) and is_finite(r2.position.z - r2_before), "a boat set on either stretch runs without trouble")
	# stroking
	var row := _on_river("rowboat", z0, 2)
	row.drive(1.0, 0.0)
	_follow(row, 40.0)
	var rv := row.vel.length()
	_expect(rv > row.num("max_mps") * 0.7 and rv < row.num("max_mps") * 1.25, "a rowboat with two at the oars comes to about its top speed (%.2f m/s, max %.1f)" % [rv, row.num("max_mps")])
	var war := _on_river("war_canoe", z0, 10)
	war.drive(1.0, 0.0)
	_follow(war, 40.0)
	var wv := war.vel.length()
	_expect(wv > rv, "a war canoe with ten paddling is faster (%.2f m/s)" % wv)
	var solo := _on_river("war_canoe", z0, 1)
	solo.drive(1.0, 0.0)
	_follow(solo, 40.0)
	_expect(solo.vel.length() < wv * 0.6, "one paddler alone in it barely moves it (%.2f m/s)" % solo.vel.length())
	var back := _on_river("rowboat", z0, 2)
	back.drive(-1.0, 0.0)
	_run(back, 12.0)
	_expect(back.speed() < 0.0 and absf(back.speed()) < rv, "backing water is slower than pulling ahead (%.2f, astern %.2f)" % [rv, back.speed()])
	# steering
	var st := _on_river("birchbark", z0, 4)
	st.drive(1.0, 0.0)
	_follow(st, 8.0)
	var y0 := st.rotation.y
	st.drive(1.0, 1.0)
	_run(st, 2.0)
	var turned := wrapf(st.rotation.y - y0, -PI, PI)
	_expect(turned > 0.2, "steering right turns it to the right (%.0f deg in 2 s)" % rad_to_deg(turned))
	st.drive(1.0, -1.0)
	_run(st, 4.0)
	_expect(wrapf(st.rotation.y - y0, -PI, PI) < turned, "and left brings it back")
	var still := _on_river("war_canoe", z0, 10)
	still.throttle = 0.0
	still.steer = 1.0
	_run(still, 2.0)
	_expect(absf(still.yaw_rate) < deg_to_rad(still.num("turn_dps")) * 0.5, "with no way on, a big boat turns slowly (%.0f deg/s)" % rad_to_deg(still.yaw_rate))
	# it does not slip sideways
	var sl := _on_river("birchbark", z0, 4)
	sl.drive(1.0, 0.0)
	_follow(sl, 10.0)
	var rel := sl.vel - WaterSurface.current_at(sl.position.x, sl.position.z)
	_expect(absf(rel.dot(sl.right())) < 0.3, "the keel holds it from slipping across the water (%.2f m/s across)" % rel.dot(sl.right()))
	# the bank
	var bank := _on_river("rowboat", z0, 2)
	bank.rotation.y = PI * 0.5   # facing +X, across the river
	bank.drive(1.0, 0.0)
	_run(bank, 60.0)
	var off := absf(bank.position.x - WorldRiver.x_at(bank.position.z))
	_expect(off < 20.0, "run at the bank it stops at the shore (%.1f m from the middle)" % off)
	_expect(bank.grounded > 0.0 or bank.vel.length() < 0.6, "and is held there (aground %.2f, %.2f m/s)" % [bank.grounded, bank.vel.length()])
	# the shallows of a rapid scrape it
	var rap := _on_river("war_canoe", rz, 10)
	_run(rap, 0.1)
	_expect(rap.grounded > 0.1, "a deep war canoe scrapes the rapid's shallows (%.2f)" % rap.grounded)
	var deep := _on_river("birchbark", z0, 4)
	_run(deep, 0.1)
	_expect(deep.grounded < 0.05, "and floats free in the deep water (%.2f)" % deep.grounded)
	if fails.is_empty():
		print("BOAT TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("BOAT TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
