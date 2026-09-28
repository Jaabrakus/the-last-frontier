extends SceneTree
## The land's wildlife numbers (WildlifeEcology; user 2026-09-27: "a global power level for animals if they keep eating
## without dying they populate more we take out there bar", "we need a max amount", "if we kill to many wolves then more
## deers grow if we kill to many deer the wolves begin to attack mammoth and humans more"; no bar: "No bar, only signs").
## Headless:
##
##   Godot --headless --path . -s tests/wildlife/test_ecology.gd -- wildlife=on
##
## The numbers alone:
##   settles     from the start the deer and wolves settle (deer 18-32, wolves 3-7) and stay
##   no wolves   the wolves shot out: more deer within days; the wolves wander back
##   few deer    the deer shot down: the wolves go hungry and thin; the deer come back; never under their floor
##   caps        never more than the land's most; a land full of deer strips its forage
##   wolf kills  a deer the wolves pulled down in the world counts against their hunting (not twice)
##   plants      the land's plants stripped (picked, dug, not let come back): the deer grow scarce and the wolves hungry;
##               let grow back, the deer return
##   never gone  every species shot out comes back (at least one), none has a floor under one
## In the game (the main level, its wildlife):
##   stocked     the numbers start as the woods were stocked
##   kills stay  a deer shot is one fewer: the restock does not bring it back
##   fill, thin  numbers above the woods: a herd comes in out of sight; below: one goes off out of sight
##   bold        by day the wolves are shy; the land short of deer: bold by day, their range drawn toward the fort, and back
##   days        the game's days run the numbers
##   save        the numbers kept in a save and back (the dead in it not counted twice)
##   mammoth     a mammoth killed is one fewer
##   plant level people picking and digging the land's plants lower its plant level, which the wildlife's numbers read
##   roots back  a ginseng patch dug out comes back ROOT_BACK_DAYS later, and shows; when it was dug is kept in a save
## Ends with "ECOLOGY TEST PASSED (<n> checks)" or "ECOLOGY TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var w: WildlifeSpawner
var p: FrontierPlayer


func _initialize() -> void:
	_numbers()
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await _fr(60)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	w = current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	_expect(w != null, "the level has its wildlife (wildlife=on)")
	if w:
		await _game()
	if fails.is_empty():
		print("ECOLOGY TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("ECOLOGY TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _settled() -> WildlifeEcology:
	var e := WildlifeEcology.new()
	e.advance(40.0)
	return e


# --- The numbers alone -----------------------------------------------------------------------------------------------

func _numbers() -> void:
	var e := WildlifeEcology.new()
	e.advance(30.0)
	var d30 := float(e.pop.deer)
	var w30 := float(e.pop.wolf)
	e.advance(10.0)
	_expect(d30 >= 18.0 and d30 <= 32.0 and w30 >= 3.0 and w30 <= 7.0 and absf(float(e.pop.deer) - d30) < 1.0 and absf(float(e.pop.wolf) - w30) < 0.5,
			"settles: %.1f deer, %.1f wolves at 30 days, and so at 40 (%s)" % [d30, w30, e.summary()])
	# the wolves shot out
	var base := _settled()
	var d0 := float(base.pop.deer)
	var nw := _settled()
	for i in int(ceil(float(nw.pop.wolf))):
		nw.on_death("wolf", "player")
	var w_after := float(nw.pop.wolf)
	nw.advance(6.0)
	var d6 := float(nw.pop.deer)
	var w6 := float(nw.pop.wolf)
	nw.advance(25.0)
	_expect(w_after < 0.5 and d6 >= d0 + 3.0, "no wolves: shot out, the deer climb from %.1f to %.1f in 6 days" % [d0, d6])
	_expect(w6 > 0.5 and float(nw.pop.wolf) >= 3.0, "no wolves: they wander back (%.1f in 6 days, %.1f in a month)" % [w6, nw.pop.wolf])
	# the deer shot down
	var fd := _settled()
	var w0 := float(fd.pop.wolf)
	while float(fd.pop.deer) > 3.0:
		fd.on_death("deer", "player")
	var hungry := fd.wolf_hunger()
	fd.advance(6.0)
	var wf := float(fd.pop.wolf)
	var lowest := float(fd.pop.deer)
	fd.advance(24.0)
	_expect(hungry > 0.4 and wf < w0 - 1.0, "few deer: the wolves go hungry (%.2f) and thin (%.1f to %.1f in 6 days)" % [hungry, w0, wf])
	_expect(lowest >= float(WildlifeEcology.SPEC.deer.floor) - 0.01 and float(fd.pop.deer) >= 15.0,
			"few deer: never under their floor (%.1f), and back to %.1f in a month" % [lowest, fd.pop.deer])
	# caps and the forage
	var cap := WildlifeEcology.new()
	cap.from_dict({"pop": {"deer": 1000.0, "wolf": 0.0}})
	var clamped := float(cap.pop.deer)
	var lowest_f := 1.0
	var most := 0.0
	for i in 15:
		cap.advance(1.0)
		lowest_f = minf(lowest_f, cap.forage)
		most = maxf(most, float(cap.pop.deer))
	var settled_f := _settled().forage
	_expect(is_equal_approx(clamped, float(WildlifeEcology.SPEC.deer.max)) and most <= float(WildlifeEcology.SPEC.deer.max)
			and lowest_f < settled_f - 0.05, "caps: never over the land's most (%.0f deer); a land full of them strips its forage (%.2f, settled %.2f)" %
			[clamped, lowest_f, settled_f])
	# wolf kills in the world count against theirs
	var a := _settled()
	var b := _settled()
	for i in 2:
		a.on_death("deer", "wolf")
		b.on_death("deer", "player")
	a.advance(1.0)
	b.advance(1.0)
	_expect(float(a.pop.deer) - float(b.pop.deer) > 1.5,
			"wolf kills: two the wolves pulled down count against their day's hunting (%.1f deer against %.1f)" % [a.pop.deer, b.pop.deer])
	var rt := WildlifeEcology.new()
	rt.from_dict(fd.to_dict())
	_expect(rt.to_dict() == fd.to_dict(), "the numbers come back from a save's dictionary")
	# the land's plants stripped: the deer grow scarce, the wolves hungry; let grow back, the deer return
	var pl := _settled()
	var dp0 := float(pl.pop.deer)
	pl.plants = 0.1
	pl.advance(7.0)
	var dp7 := float(pl.pop.deer)
	var hunger7 := pl.wolf_hunger()
	pl.plants = 1.0
	pl.advance(30.0)
	_expect(dp7 < 14.0 and hunger7 > 0.3, "plants: stripped, the deer grow scarce (%.1f to %.1f in a week), the wolves hungry (%.2f)" % [dp0, dp7, hunger7])
	_expect(float(pl.pop.deer) >= 20.0, "plants: let grow back, the deer return (%.1f in a month)" % pl.pop.deer)
	# never gone for good
	var ng := _settled()
	var floors_ok := true
	for sp: String in WildlifeEcology.SPEC:
		floors_ok = floors_ok and float(WildlifeEcology.SPEC[sp].floor) >= 1.0
		while float(ng.pop[sp]) > 0.0:
			ng.on_death(sp, "player")
	ng.advance(30.0)
	var back_ok := true
	var line := ""
	for sp: String in WildlifeEcology.SPEC:
		if ng.cap_of(sp) <= 0.0:
			continue                          # (not a beast of these woods: the bison)
		back_ok = back_ok and float(ng.pop[sp]) >= 0.99
		line += "%s %.1f " % [sp, ng.pop[sp]]
	_expect(floors_ok and back_ok, "never gone: every one shot out comes back within a month (%s)" % line.strip_edges())


# --- In the game -----------------------------------------------------------------------------------------------------

## The fort's woods' living deer (the squares beyond hold their own, to their own numbers: WildlifeSpawner).
func _deer_alive() -> Array[WildAnimal]:
	var out: Array[WildAnimal] = []
	for a in w.animals():
		if not a.is_dead() and WildlifeEcology.kind_of(a.species) == "deer" and a.home_sq == Vector2i.ZERO:
			out.append(a)
	return out


func _game() -> void:
	var live := w.live_counts(Vector2i.ZERO)
	_expect(int(round(float(w.ecology.pop.deer))) == int(live.get("deer", 0)) and int(round(float(w.ecology.pop.wolf))) == int(live.get("wolf", 0))
			and int(round(float(w.ecology.pop.fox))) == int(live.get("fox", 0)),
			"stocked: the numbers start as the woods were stocked (%s)" % str(live))
	# a deer shot: one fewer, and the restock leaves it so
	var deer := _deer_alive()
	var n0 := deer.size()
	var pop0 := float(w.ecology.pop.deer)
	deer[0]._die("player")
	for i in 3:
		w._restock()
	await _fr(2)
	_expect(is_equal_approx(float(w.ecology.pop.deer), pop0 - 1.0) and _deer_alive().size() == n0 - 1,
			"kills stay: a deer shot is one fewer (%.0f), the restock does not bring it back (%d alive)" % [w.ecology.pop.deer, _deer_alive().size()])
	# more in the land than in the woods: a herd comes in, out of sight
	var before := {}
	for a in _deer_alive():
		before[a] = true
	w.ecology.pop.deer = float(_deer_alive().size()) + 4.0
	w._restock()
	await _fr(2)
	var new_ones: Array[WildAnimal] = []
	for a in _deer_alive():
		if not before.has(a):
			new_ones.append(a)
	var far := true
	for a in new_ones:
		far = far and a.global_position.distance_to(p.global_position) >= WildlifeSpawner.RESPAWN_MIN_D
	_expect(new_ones.size() == 4 and far, "fill: 4 more deer in the land: a herd of %d comes in out of sight" % new_ones.size())
	# fewer: one goes off a restock, out of sight
	var m0 := _deer_alive().size()
	w.ecology.pop.deer = float(m0) - 2.0
	w._restock()
	await _fr(2)
	var m1 := _deer_alive().size()
	w._restock()
	await _fr(2)
	_expect(m1 == m0 - 1 and _deer_alive().size() == m0 - 2, "thin: 2 fewer in the land: one goes off a restock (%d, %d, %d)" % [m0, m1, _deer_alive().size()])
	# bold by day when the deer are short
	var rig := current_scene.get_node("EnvironmentRig") as EnvironmentRig
	var clock: WorldClock = rig.clock_driver.clock if rig and rig.clock_driver else null
	if clock:
		clock.running = false
		clock.set_time(12.5)
	w.ecology.pop.deer = 20.0
	w.ecology.pop.wolf = 4.0
	var shy := w.day_boldness()
	w.ecology.pop.deer = 2.0
	w.ecology.pop.wolf = 5.0
	var bold := w.day_boldness()
	_expect(shy < 0.4 and bold > 0.9, "bold: by day the wolves are shy (%.2f); the land short of deer, bold (%.2f)" % [shy, bold])
	# the pack's range drawn toward the fort, and back when fed
	var pack: WildGroup = null
	for e in w.groups:
		if String(e.kind) == "wolf_pack":
			pack = e.group
	if pack:
		# (its range 200 m off the fort, to see it drawn in)
		var out := Vector3(pack.home.x, 0.0, pack.home.z).normalized() * 200.0
		pack.home = Vector3(out.x, pack.home.y, out.z)
		pack.home0 = pack.home
		var h0 := Vector2(pack.home.x, pack.home.z).length()
		for i in 600:
			WildPlanner._drift(pack, w)
		var h1 := Vector2(pack.home.x, pack.home.z).length()
		w.ecology.pop.deer = 30.0
		w.ecology.pop.wolf = 4.0
		for i in 600:
			WildPlanner._drift(pack, w)
		var h2 := Vector2(pack.home.x, pack.home.z).length()
		_expect(h1 < h0 - 100.0 and h1 >= WildPlanner.FORT_RANGE - 0.5,
				"bold: hungry, the pack's range is drawn toward the fort (%.0f m to %.0f m from it; no nearer than %.0f)" % [h0, h1, WildPlanner.FORT_RANGE])
		_expect(h2 > h1 + 100.0, "bold: fed again, it goes back (%.0f m)" % h2)
	else:
		_expect(false, "bold: a wolf pack")
	# the game's days run the numbers (the world clock's; a headless run has none: the spawner's own over GAME_DAY_S)
	await _fr(300)
	var d0 := w.ecology.days
	if clock:
		clock.advance_hours(12.0)
	else:
		w.now += WildlifeSpawner.GAME_DAY_S * 0.5
	await _fr(300)
	_expect(absf(w.ecology.days - d0 - 0.5) < 0.05, "days: half a game day passes, the numbers run half a day (%.2f; %s)" %
			[w.ecology.days - d0, "the world clock" if clock else "no world clock"])
	# a save and back: the numbers as they were, the dead in it not counted again (a deer just shot: a carcass in it)
	_deer_alive()[0]._die("player")
	await _fr(2)
	w.ecology.pop.deer = 17.0
	w.ecology.pop.wolf = 3.0
	var saved := SaveParts.save_wildlife(current_scene)
	var had_dead := false
	for a in w.animals():
		had_dead = had_dead or a.is_dead()
	w.ecology.pop.deer = 5.0
	SaveParts.load_wildlife(current_scene, saved)
	await _fr(2)
	_expect(saved.has("ecology") and is_equal_approx(float(w.ecology.pop.deer), 17.0) and is_equal_approx(float(w.ecology.pop.wolf), 3.0) and had_dead,
			"save: the numbers kept and back (%.0f deer, %.0f wolves; a carcass in the save)" % [w.ecology.pop.deer, w.ecology.pop.wolf])
	# a mammoth killed: one fewer
	var m := float(w.ecology.pop.mammoth)
	var g2 := StandInGiant.new()
	g2.name = "Mammoth2"
	g2.player = p
	g2.paces = false
	current_scene.add_child(g2)
	var at := Vector3(40.0, 0.0, -120.0)
	at.y = FrontierTerrain.height_at(at.x, at.z)
	g2.build(Transform3D(Basis(), at))
	await _fr(4)
	g2.die("L")
	_expect(is_equal_approx(float(w.ecology.pop.mammoth), maxf(m - 1.0, 0.0)), "mammoth: one killed is one fewer (%.0f to %.0f)" % [m, w.ecology.pop.mammoth])
	await _plants_game()


## The land's plants: people's picking and digging lower their level, which the numbers read; dug roots come back.
func _plants_game() -> void:
	var ff := ForageField.find(self)
	if ff == null:
		_expect(false, "plant level: the level has its forage")
		return
	var l0 := ff.plant_level()
	# everything near the fort picked clean and the roots dug
	var took := 0
	for pi in ff.patches.size():
		var pa: Dictionary = ff.patches[pi]
		if Vector2((pa.pos as Vector3).x, (pa.pos as Vector3).z).length() > 250.0:
			continue
		for k in 40:
			if ff.stock_of(pi) <= 0.001:
				break
			if ff.take(pi, 0) > 0.0:
				took += 1
		for plx: Dictionary in pa.plants:
			if ff.data.plants[pa.kind].get("clip", "") == "ground" and float(ff.data.plants[pa.kind].get("stock", 1.0)) >= 1.0:
				plx.gone = true
				plx.dug_t = ff.now
	var l1 := ff.plant_level()
	w._plants_t = 0.0
	w._tick_ecology()
	_expect(took > 20 and l1 < l0 - 0.05 and is_equal_approx(w.ecology.plants, l1),
			"plant level: %d handfuls picked and the roots dug near the fort: %.2f to %.2f, and the wildlife reads it" % [took, l0, l1])
	# a ginseng patch dug out comes back
	var gi := -1
	for pi in ff.patches.size():
		if String(ff.patches[pi].kind) == "ginseng":
			gi = pi
			break
	if gi < 0:
		_expect(false, "roots back: a ginseng patch in the woods")
		return
	var ga: Dictionary = ff.patches[gi]
	var tries := 0
	while ff.stock_of(gi) > 0.001 and tries < 50:
		ff.take(gi, 0)
		tries += 1
	var all_gone := true
	for plx: Dictionary in ga.plants:
		all_gone = all_gone and plx.gone
	# kept in a save: when it was dug
	ff.now += 100.0
	var saved := SaveParts.save_forage(current_scene)
	var dug_ago := -1.0
	for plx: Dictionary in ga.plants:
		plx.dug_t = 0.0
	SaveParts.load_forage(current_scene, saved)
	dug_ago = ff.now - float(ga.plants[0].get("dug_t", -1.0))
	_expect(all_gone and absf(dug_ago - 100.0) < 1.0, "roots back: a ginseng patch dug out (%d plants); a save keeps when (%.0f s ago)" % [ga.plants.size(), dug_ago])
	ff.now += ForageField.ROOT_BACK_DAYS * float(ff.data.get("game_day_s", 3456.0))
	ff._grow(gi)
	var back := true
	var shown := true
	for plx: Dictionary in ga.plants:
		back = back and not plx.gone
		if plx.has("mm"):
			shown = shown and (plx.mm as MultiMesh).get_instance_transform(int(plx.i)).basis.get_scale().x > 0.001
	_expect(back and shown, "roots back: %d game days on, the ginseng is back%s" % [int(ForageField.ROOT_BACK_DAYS),
			", and shows" if ga.plants[0].has("mm") else " (no drawing in a headless run)"])
