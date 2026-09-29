extends SceneTree
## The spouse's logic (SpouseCore), headless: opposite sex, her own core on the player's clock, eating from the store,
## a home role cooking what is brought in, an outside role foraging and gathering firewood, a save round trip.
##   Godot --headless --path . -s tests/companion/test_spouse_core.gd
var fails := 0
var PILE_TRIP := int(JobBook.job("woodpile").feed.trip)


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	Sharpness.slips_on = false   # (exact planning and paths: no tired slips here; tests/companion/test_sharpness.gd has them)
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
	_fort_chores(main, male)
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


## The fort's chores (woodpile, smokehouse, rack, tanning frame, hoop) on fakes for the station nodes.
func _fort_chores(main: SurvivalCore, look: Dictionary) -> void:
	var v := SpouseCore.create(main, look, 21)
	v.role = "home"
	v.stock.put("jerky", 30)                      # something to eat
	v.stock.put("roast_venison", 40)              # and cooked food in hand (a shortage of it would pull the cook first)
	_skip_to_hour(main, v, 10.0)
	_expect(v.plan().is_empty(), "chores: no stations, nothing in the store to work: nothing planned (%s)" % str(v.plan()))
	for t in ["woodpile", "smoke", "jerky", "tan", "stretch"]:
		_expect(SpouseCore.TASKS.has(t) and SpouseCore.TASK_NAMES.has(t) and SpouseCore.TASK_ROLE[t] == "home" and v.enabled[t], "%s is a listed home task" % t)
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/companion/lines.json"))
	for t in SpouseCore.TASKS:
		_expect((lines.task as Dictionary).has(t) and not (lines.task[t] as Array).is_empty(), "lines.json has lines for %s" % t)
	# the woodpile
	var pile := FakePile.new()
	v.finders = {"pile": func() -> Object: return pile}
	v.stock.put("firewood", 2)
	_expect(v.plan().is_empty(), "woodpile: no wood to spare, nothing planned")
	v.stock.put("firewood", 7)
	_expect(v.plan().get("task", "") == "woodpile", "woodpile: a low pile and wood to spare plans stocking it (%s)" % str(v.plan()))
	_expect(v.begin("woodpile") and v.busy(), "stocking begins")
	v.cancel("test")
	_expect(not v.busy() and v.stock.count("firewood") == 9 and pile.wood == 0, "cancel changes nothing taken")
	v.begin("woodpile")
	main.advance(10.0)
	v.sync(main)
	_expect(not v.busy() and pile.wood == PILE_TRIP and v.stock.count("firewood") == 3, "she stacked %d sticks (pile %d, store %d)" % [PILE_TRIP, pile.wood, v.stock.count("firewood")])
	v.stock.take("firewood", 3)
	v.finders = {}
	# the smokehouse
	var smoke := FakeSmoke.new()
	v.finders = {"smoke": func() -> Object: return smoke}
	v.stock.put("venison", 2)
	v.stock.put("firewood", 9)
	_expect(v.plan().get("task", "") != "smoke", "smoke: only the venison kept for cooking: nothing to hang (%s)" % str(v.plan()))
	v.stock.put("venison", 4)
	_expect(v.plan().get("task", "") == "smoke", "smoke: venison to spare plans the smokehouse (%s)" % str(v.plan()))
	_expect(v.begin("smoke"), "smoking begins")
	main.advance(10.0)
	v.sync(main)
	_expect(not v.busy() and smoke.raw == 3 and v.stock.count("venison") == 3 and smoke.smudge > 0.0 and v.stock.count("firewood") == 6,
			"she hung 3 venison and fed the smudge (larder %d, smudge %.0f, store venison %d wood %d)" % [smoke.raw, smoke.smudge, v.stock.count("venison"), v.stock.count("firewood")])
	smoke.smudge = 600.0
	_expect(v.plan().get("task", "") != "smoke", "smoke: a full larder and a lit smudge need nothing (%s)" % str(v.plan()))
	v.finders = {}
	v.stock.take("venison", 99)
	v.stock.take("firewood", 99)
	# drying jerky on the rack (the core's own preserve.jerk_scaffold and rack record)
	var site := FakeSite.new()
	v.finders = {"rack": func() -> Object: return site}
	v.stock.put("venison", 6)
	_skip_to_hour(main, v, 10.0)
	_expect(v.plan().get("task", "") == "jerky", "jerky: venison to spare and a rack plans drying (%s)" % str(v.plan()))
	var began := v.begin("jerky")
	_expect(began and v.busy(), "drying begins (%s)" % str(v.journal.back() if not began else ""))
	if began:
		for i in 60:
			main.advance(15.0)
			v.sync(main)
			if not v.busy():
				break
		print("journal: ", v.journal.slice(-2))
		_expect(not v.busy() and v.stock.count("venison") == 4, "the batch used 2 venison from the store (%d left)" % v.stock.count("venison"))
		if v._rack_lb(false) > 0.0:
			_expect(v.plan().get("task", "") != "jerky", "jerky: a rack in use takes no second batch")
			for h in SurvivalUtil.arr(v._rack().get("hanging")):
				h["ready_at"] = v.core.state.minutes - 1.0            # (a day or two dry)
			v.stock.put("jerky", 4)
			_expect(v.plan().get("task", "") == "jerky" and v._jerky_mode() == "down", "jerky: dry strips plan taking down (%s)" % v._jerky_mode())
			var before := v.stock.count("jerky")
			v.begin("jerky")
			main.advance(4.0)
			v.sync(main)
			_expect(not v.busy() and v.stock.count("jerky") > before, "the dry jerky came into the store (%d -> %d)" % [before, v.stock.count("jerky")])
		else:
			print("(the strips spoiled on this seed: rack empty)")
	v.finders = {}
	v.stock.take("venison", 99)
	# tanning
	var frame := FakeSite.new()
	v.finders = {"frame": func() -> Object: return frame}
	_skip_to_hour(main, v, 10.0)
	v.stock.put("deer_hide", 1)
	_expect(v.plan().is_empty(), "tan: one hide and no brains: keeps the hide")
	v.stock.put("deer_hide", 1)
	_expect(v.plan().get("task", "") == "tan", "tan: two hides plan scraping rawhide (%s)" % str(v.plan()))
	began = v.begin("tan")
	_expect(began and v.busy(), "tanning begins")
	if began:
		v.cancel("test")
		_expect(v.stock.count("deer_hide") == 2 and not v.busy(), "cancel returns the hide (%d)" % v.stock.count("deer_hide"))
		v.begin("tan")
		for i in 60:
			main.advance(15.0)
			v.sync(main)
			if not v.busy():
				break
		_expect(not v.busy() and (v.stock.count("rawhide") > 0 or v.stock.count("deer_hide") == 2), "rawhide in the store, or the hide back (rawhide %d, hides %d)" % [v.stock.count("rawhide"), v.stock.count("deer_hide")])
	v.finders = {}
	v.stock.take("deer_hide", 9)
	# stretching pelts on the hoop
	var hoop := FakeSite.new()
	v.finders = {"hoop": func() -> Object: return hoop}
	_skip_to_hour(main, v, 10.0)
	v.stock.put("wolf_pelt", 1)
	_expect(v.plan().get("task", "") == "stretch", "stretch: a green pelt and a hoop plan stretching (%s)" % str(v.plan()))
	began = v.begin("stretch")
	_expect(began and v.busy(), "stretching begins")
	if began:
		for i in 60:
			main.advance(15.0)
			v.sync(main)
			if not v.busy():
				break
		_expect(not v.busy() and v.stock.count("wolf_pelt") == 0, "the pelt left the store")
		if v.hoop.size() == 1:
			var d: Dictionary = JSON.parse_string(JSON.stringify(v.to_dict()))
			_expect(SpouseCore.from_dict(d, main).hoop.size() == 1, "the hoop is saved")
			_expect(v.plan().is_empty(), "stretch: a drying pelt needs nothing yet")
			v.hoop[0].ready_at = v.core.state.minutes - 1.0          # (the days' drying, without starving the player's core)
			_expect(v.plan().get("task", "") == "stretch", "stretch: a dry pelt plans taking down (%s, dead %s, hour %.1f, cool %.0f, mode %s, min %.0f)" % [str(v.plan()), v.core.is_dead(), v.hour(), v._cool, v._stretch_mode(), v.core.state.minutes])
			v.begin("stretch")
			main.advance(4.0)
			v.sync(main)
			_expect(not v.busy() and v.stock.count("dried_wolf_pelt") == 1 and v.hoop.is_empty(), "the dried pelt is in the store")
		else:
			print("(the pelt tore in the lacing on this seed)")
	v.finders = {}
	# old saves lack the new tasks: they default on
	var old := {"name": "Old", "role": "home", "enabled": {"tend": false}, "core": v.core.state.to_dict()}
	var o := SpouseCore.from_dict(old, main)
	_expect(not o.enabled.tend and o.enabled.jerky and o.enabled.stretch and o.hoop.is_empty(), "an old save gets the new tasks on")


class FakePile extends RefCounted:
	var wood := 0
	var room := 12

	func wood_room() -> int:
		return room - wood

	func add_wood_units(n: int) -> int:
		var put := clampi(n, 0, wood_room())
		wood += put
		return put


class FakeSmoke extends RefCounted:
	var raw := 0
	var smudge := 0.0

	func larder_raw() -> int:
		return raw

	func smudge_min() -> float:
		return smudge

	func smudge_room() -> int:
		return floori((1440.0 - smudge) / 240.0)

	func add_venison(n: int) -> int:
		raw += n
		return n

	func add_wood_units(n: int) -> int:
		smudge += n * 240.0
		return n


## A station the body walks to (rack, frame, hoop): nothing to call.
class FakeSite extends RefCounted:
	pass


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
