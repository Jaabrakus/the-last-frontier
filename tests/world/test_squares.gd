extends SceneTree
## The world's squares, each a type with its own meters (WorldSquares, WildlifeLand; user 2026-09-27: "apply the
## settlers of catan functions so each tile has these power meters", "this one is dense with woods and these types of
## animals the next tile over could have more mammoths and open land and etc or one could be filled with clif walls
## where we can mine for stones and water"). Headless:
##
##   Godot --headless --path . -s tests/world/test_squares.gd -- wildlife=on
##
##   grid       3 x 3 squares of 832 m, the fort's the middle; where a place lies; the types as laid out; neighbours
##   types      after two months each square holds what its type does: the woods deer and no bison, the open land bison
##              and mammoths, the cliffs few deer and all stone, the lake its water
##   refill     a square shot out of wolves gets them back faster with its neighbours full than with them shot out too
##   spill      a square overfull of deer (its plants stripped) sends them on to the squares beside it
##   never gone every species shot out of every square comes back where it lives
##   bison prey the open land's wolves, the deer gone, have the bison: less hungry than the woods' with none
##   save       every square's numbers and meters kept and back; a save from before the squares goes to the fort's
## In the game (the main level):
##   fort       the level's numbers are the fort's square's; a deer shot there is one fewer there only
##   meters     trees felled and rock quarried in the fort's square lower its trees and stone
##   saved      the wildlife part keeps every square
## Ends with "SQUARES TEST PASSED (<n> checks)" or "SQUARES TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_grid()
	_types()
	_refill()
	_spill()
	_never_gone()
	_bison_prey()
	_save()
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await _fr(60)
	await _game()
	if fails.is_empty():
		print("SQUARES TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("SQUARES TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _grid() -> void:
	var sq := WorldSquares.squares()
	_expect(sq.size() == 9 and is_equal_approx(WorldSquares.size_m(), 832.0), "grid: %d squares of %.0f m" % [sq.size(), WorldSquares.size_m()])
	var at := [WorldSquares.square_at(Vector3.ZERO), WorldSquares.square_at(Vector3(500, 0, 0)), WorldSquares.square_at(Vector3(-500, 0, -500)),
			WorldSquares.square_at(Vector3(0, 0, 420)), WorldSquares.square_at(Vector3(0, 0, 410))]
	_expect(at == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(0, 1), Vector2i(0, 0)],
			"grid: the fort's middle is square (0, 0); 500 m along +X the next; 420 m along +Z over its edge, 410 m not (%s)" % str(at))
	var types := [WorldSquares.type_id(Vector2i(0, 0)), WorldSquares.type_id(Vector2i(1, 0)), WorldSquares.type_id(Vector2i(1, -1)),
			WorldSquares.type_id(Vector2i(1, 1)), WorldSquares.type_id(Vector2i(-1, 1)), WorldSquares.type_id(Vector2i(2, 0))]
	_expect(types == ["fort_woods", "open_land", "cliffs", "lake", "marsh", ""], "grid: the types as laid out (%s)" % str(types))
	_expect(WorldSquares.neighbours(Vector2i.ZERO).size() == 4 and WorldSquares.neighbours(Vector2i(1, 1)).size() == 2,
			"grid: the middle has four beside it, a corner two")


func _types() -> void:
	var l := WildlifeLand.new()
	l.advance(60.0)
	var woods := l.ecology(Vector2i(0, 0))
	var open := l.ecology(Vector2i(1, 0))
	var cliffs := l.ecology(Vector2i(1, -1))
	_expect(float(woods.pop.bison) == 0.0 and float(woods.pop.mammoth) <= 1.0 and float(woods.pop.deer) >= 15.0,
			"types: the woods hold deer (%.1f), a mammoth at most (%.1f), no bison" % [woods.pop.deer, woods.pop.mammoth])
	_expect(float(open.pop.bison) >= 15.0 and float(open.pop.mammoth) >= 2.0 and float(open.pop.deer) < float(woods.pop.deer),
			"types: the open land holds bison (%.1f) and mammoths (%.1f), fewer deer (%.1f)" % [open.pop.bison, open.pop.mammoth, open.pop.deer])
	_expect(float(cliffs.pop.deer) <= 8.0 and is_equal_approx(float(l.meters[Vector2i(1, -1)].stone), 1.0)
			and String(l.meters[Vector2i(1, -1)].water) == "spring" and String(l.meters[Vector2i(1, 1)].water) == "lake",
			"types: the cliffs few deer (%.1f), all stone, a spring; the lake its water" % cliffs.pop.deer)
	print(l.summary())


func _refill() -> void:
	var a := WildlifeLand.new()
	var b := WildlifeLand.new()
	a.advance(30.0)
	b.advance(30.0)
	a.ecology(Vector2i.ZERO).pop.wolf = 0.0
	b.ecology(Vector2i.ZERO).pop.wolf = 0.0
	for o in WorldSquares.neighbours(Vector2i.ZERO):
		b.ecology(o).pop.wolf = 0.0
	a.advance(4.0)
	b.advance(4.0)
	var wa := float(a.ecology(Vector2i.ZERO).pop.wolf)
	var wb := float(b.ecology(Vector2i.ZERO).pop.wolf)
	_expect(wa > wb + 0.3 and wb > 0.0, "refill: shot out of wolves, back faster with its neighbours full (%.1f in 4 days) than shot out too (%.1f)" % [wa, wb])


func _spill() -> void:
	var c := WildlifeLand.new()
	var d := WildlifeLand.new()
	c.advance(30.0)
	d.advance(30.0)
	for l: WildlifeLand in [c, d]:
		l.ecology(Vector2i.ZERO).plants = 0.1
	c.ecology(Vector2i.ZERO).pop.deer = 40.0
	var o := Vector2i(-1, 0)
	var n0 := float(c.ecology(o).pop.deer)
	c.advance(3.0)
	d.advance(3.0)
	var nc := float(c.ecology(o).pop.deer)
	var nd := float(d.ecology(o).pop.deer)
	_expect(nc > nd + 1.0, "spill: the fort's square overfull of deer, its plants stripped: the deep woods beside it %.1f to %.1f (%.1f without)" % [n0, nc, nd])


func _never_gone() -> void:
	var l := WildlifeLand.new()
	for sq: Vector2i in l.squares:
		for s: String in WildlifeEcology.SPEC:
			l.ecology(sq).pop[s] = 0.0
	l.advance(60.0)
	var missing: Array[String] = []
	for sq: Vector2i in l.squares:
		var e := l.ecology(sq)
		for s: String in WildlifeEcology.SPEC:
			if e.cap_of(s) > 0.0 and float(e.pop[s]) < 0.99:
				missing.append("%s %s %.2f" % [WorldSquares.type_id(sq), s, e.pop[s]])
	_expect(missing.is_empty(), "never gone: every species shot out of every square is back in two months where it lives %s" % str(missing))


func _bison_prey() -> void:
	var l := WildlifeLand.new()
	l.advance(30.0)
	var open := l.ecology(Vector2i(1, 0))
	var woods := l.ecology(Vector2i(0, 0))
	open.pop.deer = 1.0
	woods.pop.deer = 1.0
	open.pop.wolf = 5.0
	woods.pop.wolf = 5.0
	_expect(open.wolf_hunger() < woods.wolf_hunger() - 0.2,
			"bison prey: the deer gone, the open land's wolves have the bison (hunger %.2f), the woods' none (%.2f)" % [open.wolf_hunger(), woods.wolf_hunger()])


func _save() -> void:
	var l := WildlifeLand.new()
	l.advance(10.0)
	l.ecology(Vector2i(1, 0)).pop.bison = 33.0
	l.meters[Vector2i(1, -1)].stone = 0.4
	var r := WildlifeLand.new()
	r.from_dict(l.to_dict())
	_expect(r.to_dict() == l.to_dict() and is_equal_approx(float(r.ecology(Vector2i(1, 0)).pop.bison), 33.0)
			and is_equal_approx(float(r.meters[Vector2i(1, -1)].stone), 0.4), "save: every square's numbers and meters kept and back")
	var old := WildlifeLand.new()
	old.from_dict({"pop": {"deer": 7.0, "wolf": 2.0}})
	_expect(is_equal_approx(float(old.ecology(Vector2i.ZERO).pop.deer), 7.0), "save: one from before the squares goes to the fort's")


func _game() -> void:
	var w := current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	_expect(w != null and w.ecology == w.land.ecology(Vector2i.ZERO), "fort: the level's numbers are the fort's square's (wildlife=on)")
	if w == null:
		return
	var open0 := float(w.land.ecology(Vector2i(1, 0)).pop.deer)
	var fort0 := float(w.ecology.pop.deer)
	for a in w.animals():
		if not a.is_dead() and WildlifeEcology.kind_of(a.species) == "deer":
			a._die("player")
			break
	_expect(is_equal_approx(float(w.ecology.pop.deer), fort0 - 1.0) and is_equal_approx(float(w.land.ecology(Vector2i(1, 0)).pop.deer), open0),
			"fort: a deer shot there is one fewer there (%.0f), none fewer in the open land" % w.ecology.pop.deer)
	# trees felled, rock quarried
	var vh := VegHarvest.find(self)
	if vh == null:
		_expect(false, "meters: the level's vegetation")
		return
	w._read_meters(vh)
	var m: Dictionary = w.land.meters[Vector2i.ZERO]
	var t0 := float(m.trees)
	var s0 := float(m.stone)
	var n_trees := (vh.lay.tree_pos as PackedVector3Array).size()
	for i in mini(n_trees / 4, n_trees):
		vh.felled[i] = true
	var rocks := 0
	for i in (vh.lay.prop_kind as Array).size():
		var k: int = vh.lay.prop_kind[i]
		if k >= VegHarvest.Assets.ROCK_FIRST and k <= VegHarvest.Assets.ROCK_LAST:
			vh.rock_size[i] = 0.0
			rocks += 1
			if rocks >= 40:
				break
	w._read_meters(vh)
	_expect(float(m.trees) < t0 - 0.2 and float(m.stone) < s0, "meters: a quarter of its trees felled and %d rocks quarried: trees %.2f to %.2f, stone %.2f to %.2f" %
			[rocks, t0, m.trees, s0, m.stone])
	var saved := SaveParts.save_wildlife(current_scene)
	var sq: Dictionary = (saved.get("ecology", {}) as Dictionary).get("squares", {})
	_expect(sq.size() == 9, "saved: the wildlife part keeps every square (%d)" % sq.size())
