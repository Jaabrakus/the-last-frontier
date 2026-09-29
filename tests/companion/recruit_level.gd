extends SceneTree
## Recruiting in the level, headless (survival on): a party walks in and camps, one is fed and asked, the party joins and
## walks home to become workers with bodies, the household's save carries the candidates and the recruits' morale through
## a load, and a dismissed recruit walks away.
##   Godot --headless --path . -s tests/companion/recruit_level.gd -- survival=on fort_plan=on
var fails := 0


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await _frames(10)
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	await _frames(200)
	var h := Household.find(self)
	var link := RecruitLink.find(self)
	if h == null or link == null or h.body == null:
		print("RECRUIT LEVEL FAILED: no household")
		quit(1)
		return
	var main := link.main()
	main.state.minutes = floorf(main.state.minutes / 1440.0) * 1440.0 + 1440.0 + 10.0 * 60.0
	await _frames(5)
	link._ensure()
	link.st.next_at = 1e12
	for c: Dictionary in link.st.candidates:
		c["state"] = "gone"
	await _frames(5)
	_expect(link.places() >= 6, "places to sleep from the fort's beds (%d; %d taken)" % [link.places(), link.occupants()])
	h.stock.put("roast_venison", 40)
	var party := Recruit.make_party(link.st, main.state.minutes, "widow", main)
	for i in 60:
		await process_frame
		if link.bodies.has(String(party[1].id)):
			break
	var b0: RecruitBody = link.bodies.get(String(party[0].id))
	_expect(b0 != null and b0.mode == "walk", "the widow and her child walk in along the %s road" % party[0].road)
	# hurry them to the camp end of the road
	var road := link._road(String(party[0].road))
	for c: Dictionary in party:
		var b: RecruitBody = link.bodies.get(String(c.id))
		b.global_position = (road.back() as Vector3) + Vector3(0, 0.3, 0)
		b.walk([link.camp_spot(c)])
	for i in 900:
		await physics_frame
		if party.all(func(c: Dictionary) -> bool: return String(c.state) == "camped"):
			break
	_expect(party.all(func(c: Dictionary) -> bool: return String(c.state) == "camped"), "they reach the camp (%s)" % str(party.map(func(c: Dictionary) -> String: return String(c.state))))
	link.talk(party[0])
	link.gift(party[0])
	var o := link.odds(party[1])
	print("odds %d%%: %s; blocked '%s'" % [int(o.pct), Recruit.factors_text(o), o.blocked])
	var r := link.ask(party[1], 0.0)
	_expect(bool(r.joined) and (r.ids as Array).size() == 2, "asked, the two join (%s)" % String(r.line))
	var ws := h.workers().filter(func(w: SpouseCore) -> bool: return not w.recruit.is_empty())
	_expect(ws.size() == 2 and ws.all(func(w: SpouseCore) -> bool: return w.worker_id > 0), "two workers in the household (%s)" % str(ws.map(func(w: SpouseCore) -> String: return "%s #%d %s" % [w.name, w.worker_id, w.role])))
	var teen: SpouseCore = ws.filter(func(w: SpouseCore) -> bool: return String(w.recruit.age) == "teen")[0] if ws.size() == 2 else null
	_expect(teen != null and teen.enabled.values().count(true) <= (Growth.junior_rules().get("jobs", []) as Array).size(), "the teen has junior jobs only")
	_expect(link.homebound.size() == 2, "they walk home first")
	# hurry them home
	for w: SpouseCore in link.homebound.keys():
		var rb: RecruitBody = link.homebound[w]
		rb.global_position = h.home + Vector3(2.0, 0.5, 0.0)
		rb.route = [rb.route.back()]
	for i in 300:
		await physics_frame
		if link.homebound.is_empty():
			break
	_expect(link.homebound.is_empty() and ws.all(func(w: SpouseCore) -> bool: return h.body_of(w) != null), "home: they have Spouse bodies")
	if teen != null and h.body_of(teen) != null:
		_expect(absf(h.body_of(teen)._model.scale.x - float(Growth.stage_row("teen").get("scale", 0.93))) < 0.01, "the teen at the teen's size")
	# a second party camped, then save and load
	var p2 := Recruit.make_party(link.st, main.state.minutes, "lost_trapper", main)
	await _frames(20)
	link.gift(p2[0])
	ws[0].recruit["morale"] = 0.33
	var d := h.save_data()
	var text := JSON.stringify(d)
	_expect(d.has("recruit") and text.length() > 0, "the household save carries recruiting (%d bytes)" % text.length())
	h.load_data(JSON.parse_string(text))
	await _frames(30)
	var ws2 := h.workers().filter(func(w: SpouseCore) -> bool: return not w.recruit.is_empty())
	_expect(ws2.size() == 2 and absf(float(ws2[0].recruit.morale) - 0.33) < 0.01, "after the load: the recruits and their morale (%.2f)" % (float(ws2[0].recruit.morale) if not ws2.is_empty() else -1.0))
	var back := Recruit.by_id(link.st, String(p2[0].id))
	_expect(not back.is_empty() and bool(back.fed) and link.bodies.get(String(p2[0].id)) != null, "the camped trapper is back, fed, with a body")
	var nb := ws2.filter(func(w: SpouseCore) -> bool: return String(w.recruit.age) == "teen")
	if not nb.is_empty() and h.body_of(nb[0]) != null:
		_expect(absf(h.body_of(nb[0])._model.scale.x - float(Growth.stage_row("teen").get("scale", 0.93))) < 0.01, "the teen at the teen's size after the load")
	# an old save without recruiting
	var old := d.duplicate(true)
	old.erase("recruit")
	h.load_data(old)
	await _frames(5)
	_expect(link.st.has("candidates") and (link.st.candidates as Array).is_empty(), "an old save: recruiting starts fresh")
	# dismissed: walks away
	var gone: SpouseCore = h.workers().filter(func(w: SpouseCore) -> bool: return not w.recruit.is_empty())[0]
	var n0 := get_nodes_in_group(PlacedWeapon.GROUP).filter(func(n: Node) -> bool: return n is RecruitBody).size()
	h.remove_worker(gone)
	await _frames(5)
	var n1 := get_nodes_in_group(PlacedWeapon.GROUP).filter(func(n: Node) -> bool: return n is RecruitBody and (n as RecruitBody).mode == "leave").size()
	_expect(not h.workers().has(gone) and n1 >= 1, "dismissed, %s walks away by the road (%d walking)" % [gone.name, n1 - 0 * n0])
	print("RECRUIT LEVEL %s (%d failed)" % ["PASSED" if fails == 0 else "FAILED", fails])
	quit(1 if fails else 0)
