extends SceneTree
## The spouse's logic (SpouseCore), headless: opposite sex, her own core on the player's clock, eating from the store,
## a home role cooking what is brought in, an outside role foraging and gathering firewood, a save round trip.
##   Godot --headless --path . -s tests/companion/test_spouse_core.gd
var fails := 0


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	InputSetup.ensure()
	var main := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 7, "start_day": "sep_early", "start_hour": 8.0,
			"backlog_milestones": ["M2a", "M2b", "M3"], "settings": {"rest_need": false}})
	var male := AppearanceStore.default_look()
	var w := SpouseCore.create(main, male, 11)
	_expect(not w.is_male() and w.title() == "wife", "a male player gets a wife (%s)" % w.name)
	var f: Dictionary = CharacterPeoples.preset_look("english_f_a") if not CharacterPeoples.preset("english_f_a").is_empty() else {"sex": 0.0}
	var h := SpouseCore.create(main, f, 12)
	_expect(h.is_male() and h.title() == "husband", "a female player gets a husband (%s)" % h.name)
	_expect(w.core != main and w.core.state != main.state, "she has a survival core of her own")
	_expect(is_equal_approx(w.core.state.minutes, main.state.minutes), "on the player's clock")
	_expect(w.core.state.skills.hidecraft == main.state.skills.hidecraft, "the player's skills")
	# time passes: she gets hungry, and eats from the store
	w.stock.put("jerky", 10)
	main.advance(60.0 * 9.0)
	w.sync(main)
	_expect(is_equal_approx(w.core.state.minutes, main.state.minutes), "sync keeps her on the clock (%.0f)" % w.core.state.minutes)
	var stage := SurvivalNeeds.food_stage(w.core)
	_expect(w.stock.count("jerky") < 10, "she ate from the store when hungry (jerky left %d, stage %s)" % [w.stock.count("jerky"), stage])
	# home role: raw food brought in gets cooked
	w.role = "home"
	w.core.state.minutes = fposmod(w.core.state.minutes, 1440.0) + floorf(w.core.state.minutes / 1440.0) * 1440.0
	_skip_to_hour(main, w, 10.0)
	w.stock.put("venison", 6)
	var p := w.plan()
	_expect(p.get("task", "") == "cook", "home: brought venison plans a cook (%s)" % str(p))
	var got := w.begin("cook")
	_expect(got and w.busy(), "cooking begins")
	for i in 40:
		main.advance(15.0)
		w.sync(main)
		if not w.busy():
			break
	_expect(not w.busy() and (w.stock.count("roast_venison") + w.stock.count("charred_venison")) > 0,
			"the roast finished into the store (roast %d, charred %d, raw %d)" % [w.stock.count("roast_venison"), w.stock.count("charred_venison"), w.stock.count("venison")])
	# home role: a lit fire low on wood gets firewood from the store
	var fire := FakeFire.new()
	w.fire_finder = func() -> Object: return fire
	w.stock.put("firewood", 5)
	_skip_to_hour(main, w, 11.0)
	p = w.plan()
	_expect(p.get("task", "") == "tend", "home: a fire low on wood plans tending (%s)" % str(p))
	_expect(w.begin("tend"), "tending begins")
	main.advance(10.0)
	w.sync(main)
	_expect(not w.busy() and fire.wood == 3 and w.stock.count("firewood") == 2, "she laid 3 sticks (fire %d, store %d)" % [fire.wood, w.stock.count("firewood")])
	w.fire_finder = Callable()
	# outside role
	w.role = "outside"
	_skip_to_hour(main, w, 9.0)
	var q := w.plan()
	_expect(q.has("task"), "outside: plans a task in daylight (%s)" % str(q))
	var done := 0
	for round in 4:
		q = w.plan()
		if q.is_empty():
			main.advance(50.0)
			w.sync(main)
			continue
		if not w.begin(String(q.task)):
			main.advance(50.0)
			w.sync(main)
			continue
		for i in 60:
			main.advance(15.0)
			w.sync(main)
			if not w.busy():
				break
		done += 1
	print("journal: ", w.journal)
	_expect(done > 0, "outside tasks ran (%d)" % done)
	# night: nothing
	_skip_to_hour(main, w, 23.0)
	_expect(w.plan().is_empty(), "no work at night")
	# follow / stay: nothing
	_skip_to_hour(main, w, 10.0)
	w.role = "follow"
	_expect(w.plan().is_empty(), "following: no task")
	# save round trip
	var d: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict()))
	var back := SpouseCore.from_dict(d, main)
	_expect(back.name == w.name and back.role == w.role and is_equal_approx(back.core.state.minutes, w.core.state.minutes), "save round trip")
	print("SPOUSE CORE TEST %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit(1 if fails else 0)


class FakeFire extends RefCounted:
	var wood := 0

	func add_wood_units(n: int) -> int:
		wood += n
		return n


func _skip_to_hour(main: SurvivalCore, w: SpouseCore, hr: float) -> void:
	var cur := fposmod(main.state.minutes, 1440.0) / 60.0
	var dh := fposmod(hr - cur, 24.0)
	main.advance(dh * 60.0)
	w.sync(main)
