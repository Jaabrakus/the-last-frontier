extends SceneTree
## The scavengers and the carcass clean-up (user 2026-09-27: "it should go for left animals 10 min timer if nothing goes
## for it it gets removed from the bored", "real time", "start with the scavangers"), on the climbing yard with its
## wildlife, headless:
##
##   Godot --headless --path . -s tests/wildlife/test_scavengers.gd -- wildlife=on
##
##   clean-up  single player: a carcass left alone stays, however long (user 2026-09-28: "for single player yes save it
##             but multiplayer we do that"); in multiplayer (force_cleanup) one left alone UNTOUCHED_S (10 min of the
##             spawner's real-time clock) is removed; one a scavenger fed at lately stays, its clock started over;
##             picked-clean bones go BONES_S after the last touch
##   mammoth   the dead mammoth is a carcass (its meat in deer: the flanks, legs, trunk); scavengers eat the flank lying
##             up first (the player's cuts fewer, a last cut smaller, the flank eaten away with its hide), then the legs
##             lying up; a leg chopped off takes what is left on it
##   limb      the chopped-off leg is a carcass too: eaten down it thins; the axe gets what is left; picked clean, bones
##   wolves    a hungry pack near goes to the mammoth's meat and eats it, at its side, not inside it
##   ravens    ravens come to the mammoth
##   gone      while the wolves feed it stays, long dead as it is; left alone 10 minutes, the whole mammoth is gone
## Ends with "SCAVENGERS TEST PASSED (<n> checks)" or "SCAVENGERS TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var gi: StandInGiant
var w: WildlifeSpawner


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	await _fr(30)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	gi = (current_scene.get("yard") as ClimbYard).giant
	gi.paces = false
	w = current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	_expect(w != null, "the level has its wildlife (wildlife=on)")
	if w == null:
		_end()
		return
	# the player 70 m off the mammoth: near enough that the wildlife there thinks (ACTIVE_D) and the ravens come, too far
	# for the wolves to hunt by day or the ravens to shy
	var at := gi.where() + Vector3(-70.0, 0.0, 0.0)
	p.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.1, at.z)
	p.velocity = Vector3.ZERO
	await _fr(60)
	await _cleanup()
	await _mammoth()
	await _wolves()
	await _ravens()
	await _gone()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("SCAVENGERS TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("SCAVENGERS TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _gone_node(n: Variant) -> bool:
	return n == null or not is_instance_valid(n) or (n as Node).is_queued_for_deletion()


func _pack(kind: String) -> int:
	return InventoryState.from_player(p).pack_count(kind)


## Two deer carcasses: the clock's rules on them.
func _cleanup() -> void:
	var deer: Array[WildAnimal] = []
	for a in w.animals():
		if a.species == "deer" and not a.is_dead():
			deer.append(a)
		if deer.size() >= 2:
			break
	if deer.size() < 2:
		_expect(false, "clean-up: two deer in the woods")
		return
	var d1 := deer[0]
	var d2 := deer[1]
	d1._die("test")
	d2._die("test")
	await _fr(2)
	var u := WildlifeSpawner.UNTOUCHED_S
	_expect(is_equal_approx(u, 600.0), "clean-up: the untouched limit is 10 minutes (%.0f s)" % u)
	# single player: left alone twice that, it stays
	w.force_cleanup = false
	d1.set_meta("died_at", w.now - 2.0 * u)
	await _fr(90)
	_expect(not _gone_node(d1) and not w.cleanup_untouched(), "clean-up: single player, left alone 20 minutes it stays")
	# saved while on a rope (dragged, hauled), it comes back as let go at the save: its clock starts over
	d1.set_meta(&"on_chain", true)
	var saved := SaveParts._animal(d1)
	d1.remove_meta(&"on_chain")
	_expect(bool(saved.get("dead", false)) and is_equal_approx(float(saved.get("hauled_at", -1.0)), w.now),
			"clean-up: saved while dragged, it is kept as let go at the save (hauled_at)")
	# multiplayer: left alone just under 10 minutes: it stays; just over: gone
	w.force_cleanup = true
	d1.set_meta("died_at", w.now - (u - 20.0))
	await _fr(90)
	var stayed := not _gone_node(d1)
	d1.set_meta("died_at", w.now - (u + 5.0))
	await _fr(90)
	_expect(stayed and _gone_node(d1), "clean-up: left alone 9 min 40 s it stays; 10 min and it is gone")
	# long dead, but a scavenger fed at it a minute ago: it stays; a bite now starts its clock over
	d2.set_meta("died_at", w.now - 2.0 * u)
	d2.set_meta(&"touched_at", w.now - 60.0)
	await _fr(90)
	var kept := not _gone_node(d2)
	d2.eat(0.01)
	await _fr(90)
	_expect(kept and not _gone_node(d2) and w.now - float(d2.get_meta(&"touched_at", -INF)) < 1.5,
			"clean-up: long dead, a scavenger at it lately: it stays, and a bite starts its clock over")
	# picked clean: bones go BONES_S after the last touch
	d2.eat(10.0)
	d2.set_meta("bones_at", w.now - WildlifeSpawner.BONES_S - 5.0)
	d2.set_meta(&"touched_at", w.now - 10.0)
	d2.remove_meta(&"touched")
	await _fr(90)
	var bones_kept := not _gone_node(d2)
	d2.set_meta(&"touched_at", w.now - WildlifeSpawner.BONES_S - 5.0)
	await _fr(90)
	_expect(bones_kept and _gone_node(d2), "clean-up: its bones stay while touched lately, and go %.0f s after" % WildlifeSpawner.BONES_S)


## The dead mammoth: a carcass whose meat the scavengers and the player share.
func _mammoth() -> void:
	gi.die("L")
	await _fr(int(3.5 * 120))
	var b := gi.butchery
	if b == null or b.carcass == null:
		_expect(false, "mammoth: dead, a butchery and its carcass")
		return
	var c := b.carcass
	var flat := Vector2(c.global_position.x - gi.torso.global_position.x, c.global_position.z - gi.torso.global_position.z).length()
	_expect(c.is_in_group(&"carcasses") and is_equal_approx(c.meat_left, 21.5) and flat < 0.3,
			"mammoth: dead, a carcass under its middle (%.2f m) with %.1f deer of meat" % [flat, c.meat_left])
	_expect(w.nearest_carcass(c.global_position + Vector3(30.0, 0.0, 0.0), 100.0, "wolf") == c,
			"mammoth: the wolves' nose finds it (nearest_carcass)")
	# on its left side: its right flank lies up, eaten first
	var st: Dictionary = b.state
	c.eat(1.5)
	_expect(is_equal_approx(float(b.pool.meat_r), 2.5) and int(st.meat_r.left) == 3 and is_equal_approx(float(b.pool.meat_l), 4.0),
			"mammoth: scavengers eat the flank lying up (right: %.1f left, %d cuts; left %.1f)" % [b.pool.meat_r, st.meat_r.left, b.pool.meat_l])
	# the player's cuts: skinned, a whole cut, then (the scavengers at it again) a smaller last one
	b._take("hide_r")
	var vn := _pack("venison")
	var cut1 := b.axe_strike({"key": "meat_r"}, 100.0)
	var got1 := _pack("venison") - vn
	c.eat(1.0)
	var left_after := int(st.meat_r.left)
	vn = _pack("venison")
	var cut2 := b.axe_strike({"key": "meat_r"}, 100.0)
	var got2 := _pack("venison") - vn
	_expect(cut1 >= 1.0 and got1 == 4 and left_after == 1 and cut2 >= 1.0 and got2 == 2 and bool(st.meat_r.done),
			"mammoth: a cut gives %d meat; eaten at, 1 cut left, and it gives %d; the flank done" % [got1, got2])
	# then the legs lying up: the front one first
	c.eat(1.0)
	_expect(is_equal_approx(float(b.pool.foreleg_r), 2.0), "mammoth: then the leg lying up (%.1f of 3 left on it)" % b.pool.foreleg_r)
	var cut3 := b.axe_strike({"key": "foreleg_r"}, 100.0)
	var limb: LimbCarcass = b.dropped.get("foreleg_r")
	_expect(cut3 >= 1.0 and limb != null and is_equal_approx(limb.meat_left, 2.0) and is_equal_approx(float(b.pool.foreleg_r), 0.0)
			and limb.is_in_group(&"carcasses"), "mammoth: chopped off, the leg takes what is left on it (%.1f)" %
			(limb.meat_left if limb else -1.0))
	await _fr(90)
	if limb:
		await _limb(limb)


## The dropped leg as a carcass: eaten down it thins; the axe's meat is what is left; picked clean, bones.
func _limb(limb: LimbCarcass) -> void:
	limb.eat(1.0)
	var thin := limb.model.scale.x < 0.9
	# another leg, half eaten, for the axe
	var b := gi.butchery
	b.pool.hindleg_r = 1.5
	b.axe_strike({"key": "hindleg_r"}, 100.0)
	var l2: LimbCarcass = b.dropped.get("hindleg_r")
	await _fr(90)
	if l2 == null:
		_expect(false, "limb: the other leg dropped")
		return
	var vn := _pack("venison")
	var sn := _pack("sinew")
	var share := l2.meat_left / l2.meat_full
	l2.axe_strike({}, 100.0)
	await _fr(4)
	var want := maxi(int(round(5 * share)), 1)
	_expect(thin and _pack("venison") - vn == want and _pack("sinew") - sn == 2,
			"limb: eaten at it thins; a half-eaten leg butchered gives %d meat (a whole one 5), the sinew all the same" % (_pack("venison") - vn))
	limb.eat(10.0)
	_expect(limb.get_meta("bones", false) and not limb.is_in_group(&"axe_work") and limb.axe_strike({}, 100.0) == 0.0,
			"limb: picked clean, bones: nothing more for the axe")


## A hungry pack near the dead mammoth: it goes to it and eats at its side.
func _wolves() -> void:
	var b := gi.butchery
	if b == null:
		return
	var c := b.carcass
	var pack: WildGroup = null
	for e in w.groups:
		if String(e.kind) == "wolf_pack" and not (e.group as WildGroup).alive().is_empty():
			pack = e.group
	if pack == null:
		_expect(false, "wolves: a pack")
		return
	# the pack 35 m off, hungry; the ravens and the other carcasses out of the way
	var i := 0
	for a in pack.alive():
		var q := c.global_position + Vector3(35.0 + i * 1.5, 0.0, 6.0 + i * 1.5)
		a.global_position = Vector3(q.x, FrontierTerrain.height_at(q.x, q.z) + 0.02, q.z)
		a.hunger = 0.95
		i += 1
	var meat0 := b.meat_total()
	var went := false
	var ate := false
	var inside := 99.0
	var closest := 99.0
	var t := 0.0
	while t < 90.0 and not (went and ate):
		await physics_frame
		t += 1.0 / 120.0
		if pack.activity == WildGroup.Activity.EAT and (pack.carcass == c or pack.carcass is LimbCarcass):
			went = true
		ate = b.meat_total() < meat0 - 0.01 or ate
		for a in pack.alive():
			if a.state == WildAnimal.State.EAT and pack.carcass == c:
				var d := Vector2(a.global_position.x - c.global_position.x, a.global_position.z - c.global_position.z).length()
				inside = minf(inside, d)
	for a in pack.alive():
		closest = minf(closest, a.global_position.distance_to(c.global_position))
	_expect(went, "wolves: hungry, the pack goes for the mammoth's meat (%s, %.0f s)" % [
			"the carcass" if pack.carcass == c else str(pack.carcass), t])
	_expect(ate, "wolves: and eats it (%.2f -> %.2f deer)" % [meat0, b.meat_total()])
	_expect(inside >= c.eat_radius, "wolves: at its side, not inside it (the nearest eating %.1f m from its middle)" % inside)


func _ravens() -> void:
	var b := gi.butchery
	if b == null:
		return
	var c := b.carcass
	var t := 0.0
	var n := 0
	while t < 40.0 and n == 0:
		await _fr(60)
		t += 0.5
		for r in get_nodes_in_group(&"ravens"):
			if (r as Raven).carcass == c:
				n += 1
	_expect(n >= 1, "ravens: they come to the dead mammoth (%d, %.0f s)" % [n, t])


## While the wolves feed it stays; left alone 10 minutes, the whole mammoth goes (and a leg left alone with it).
func _gone() -> void:
	var b := gi.butchery
	if b == null:
		return
	var c := b.carcass
	var u := WildlifeSpawner.UNTOUCHED_S
	c.set_meta("died_at", w.now - 2.0 * u)
	c.set_meta(&"touched_at", w.now - 2.0 * u)
	await _fr(120)
	var fed := not _gone_node(gi) and w.now - float(c.get_meta(&"touched_at", -INF)) < 2.0
	_expect(fed, "gone: long dead, but the wolves feeding: it stays")
	if not fed:
		return
	# the wolves and the ravens gone; nobody at it for 10 minutes
	for a in w.wolves_now():
		w.remove_animal(a)
	for r in get_nodes_in_group(&"ravens"):
		(r as Node).queue_free()
	await _fr(10)
	var leg: LimbCarcass = b.dropped.get("foreleg_r")          # (picked clean: bones)
	c.set_meta(&"touched_at", w.now - u - 5.0)
	c.remove_meta(&"touched")
	if leg and is_instance_valid(leg):
		leg.set_meta("died_at", w.now - u - 5.0)
		leg.set_meta("bones_at", w.now - u - 5.0)
		leg.set_meta(&"touched_at", w.now - u - 5.0)
		leg.remove_meta(&"touched")
	await _fr(120)
	var yard := current_scene.get("yard") as ClimbYard
	_expect(_gone_node(gi) and (leg == null or _gone_node(leg)), "gone: left alone 10 minutes, the whole mammoth is gone%s" %
			(" and the leg's bones" if leg else ""))
	_expect(yard != null, "gone: the yard goes on without it")
