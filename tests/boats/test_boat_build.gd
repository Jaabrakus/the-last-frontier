extends SceneTree
## BoatBuild (scripts/boats/boat_build.gd, data/boats/plans.json), headless: the parts are brought and attached stage by stage, what
## the builder knows caps the grades, out of order spoils, the grades become the boat's numbers, a saved build carries on.
##   Godot --headless --path . -s tests/boats/test_boat_build.gd
var checks := 0
var fails: Array[String] = []
var kn := {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fresh(state := "known") -> BoatBuild:
	var b := BoatBuild.make("birchbark")
	kn = {"know.canoe_bed": state, "know.bark_sewing": state, "know.canoe_gunwales": state, "know.pitching_seams": state}
	b.know = func(k: String) -> String: return String(kn.get(k, "unknown"))
	b.has_tool = func(_t: Array) -> bool: return true
	return b


func _stock(b: BoatBuild) -> void:
	for s: Dictionary in b.stages():
		for k: String in s.needs:
			b.deliver(k, int(s.needs[k]))


func _initialize() -> void:
	var b := _fresh()
	_expect(b.stages().size() == 5 and b.next_id() == "bed", "the birchbark canoe has five stages, the bed first")
	var ids := []
	for s: Dictionary in b.stages():
		ids.append(String(s.id))
	_expect(ids == ["bed", "skin", "gunwales", "ribs", "seams"], "in the craft's own order, inside-out: bed, skin, gunwales, ribs, seams (%s)" % ",".join(ids))
	var w := 0.0
	for s: Dictionary in b.stages():
		w += float(s.weight)
	_expect(is_equal_approx(w, 1.0), "the stages' weights make one (%.2f)" % w)
	_expect(b.can_start("bed").reason == "parts" and b.missing("bed").size() == 1, "no parts at the stand: it cannot be started (needs %s)" % str(b.missing("bed")))
	b.deliver("item.material.canoe_stake", 14)
	_expect(bool(b.can_start("bed").ok), "with its stakes brought it can")
	b.has_tool = func(_t: Array) -> bool: return false
	_expect(b.can_start("bed").reason == "tool", "and no tool: it cannot")
	b.has_tool = func(_t: Array) -> bool: return true
	_expect(b.start("bed") and int(b.store.get("item.material.canoe_stake", 0)) == 0, "starting attaches the parts (out of the store)")
	_expect(b.work(20.0) == "" and b.progress == 20.0, "work goes on by the minute")
	_expect(b.work(30.0) == "done" and b.done.has("bed") and b.current == "", "and finishes on its own where there is no puzzle")
	_expect(b.grade_of("bed") > 0.5, "a plain job by skill gives a middling grade (%.2f)" % b.grade_of("bed"))
	# the skin has a puzzle
	_stock(b)
	_expect(b.start("skin"), "the skin next")
	_expect(b.work(100.0) == "" and b.work(60.0) == "puzzle" and b.waiting, "its work done it waits for its puzzle")
	_expect(b.work(10.0) == "" and b.current == "skin", "and goes no further until it is played")
	var g := b.finish(0.92)
	_expect(is_equal_approx(g, 0.92) and b.done.has("skin") and not b.waiting, "the puzzle's score is the grade (%.2f)" % g)
	# knowledge
	var u := _fresh("unknown")
	_stock(u)
	_expect(u.can_start("bed").reason == "unknown", "unknown technique: it cannot be done at all")
	var h := _fresh("heard_of")
	_stock(h)
	h.start("skin")
	h.work(999.0)
	var gh := h.finish(1.0)
	_expect(gh < 0.6 and not h.current_ordered, "heard of only: a perfect puzzle is capped (%.2f), and the skin before the bed is out of order" % gh)
	var oo := h.stats()
	_expect(bool(oo.out_of_order) and float(oo.watertight) < 0.3, "the build remembers it was out of order (watertight %.2f)" % float(oo.watertight))
	var m := _fresh("mastered")
	_stock(m)
	for sid in ["bed", "skin", "gunwales", "ribs", "seams"]:
		_expect(m.start(sid), "%s can be started in order" % sid)
		var r := m.work(999.0, 1.0, 1.0)
		if r == "puzzle":
			m.finish(0.95)
	var st := m.stats()
	_expect(m.is_complete() and float(st.quality) > 0.9 and not bool(st.out_of_order), "a mastered builder's canoe is fine (%.2f, %s)" % [float(st.quality), st.word])
	_expect(float(st.speed_mult) > 1.0 and float(st.leak_l_per_h) < 2.0 and float(st.wear_mult) < 1.0, "quick (x%.2f), dry (%.1f l/h) and lasting (wear x%.2f)" % [float(st.speed_mult), float(st.leak_l_per_h), float(st.wear_mult)])
	var rough := _fresh("seen")
	_stock(rough)
	for sid in ["bed", "skin", "gunwales", "ribs", "seams"]:
		rough.start(sid)
		if rough.work(999.0, 1.0, 0.0) == "puzzle":
			rough.finish(0.5)
	var sr := rough.stats()
	_expect(float(sr.quality) < float(st.quality) and float(sr.leak_l_per_h) > float(st.leak_l_per_h), "a rough one is slower and leakier (%.2f, %.1f l/h against %.1f)" % [float(sr.quality), float(sr.leak_l_per_h), float(st.leak_l_per_h)])
	_expect(rough.worker_grade(1.0) <= 0.7 and rough.worker_grade(0.0) < rough.worker_grade(1.0), "a worker's job at a puzzle stage is middling at best (%.2f)" % rough.worker_grade(1.0))
	# a save carries on
	var p := _fresh()
	_stock(p)
	p.start("bed")
	p.work(30.0)
	var q := BoatBuild.from_dict(p.to_dict())
	q.know = p.know
	q.has_tool = p.has_tool
	_expect(q.current == "bed" and is_equal_approx(q.progress, 30.0) and q.store == p.store, "a saved build carries on where it was")
	if fails.is_empty():
		print("BOAT BUILD TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("BOAT BUILD TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
