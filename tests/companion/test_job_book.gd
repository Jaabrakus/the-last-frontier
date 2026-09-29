extends SceneTree
## The household's jobs as data (JobBook, data/companion/jobs.json): the book and its chain, the pull-based planner, the
## toggles, two workers sharing a store (reservations), and the save round trip (including the old single-spouse save).
##   Godot --headless --path . -s tests/companion/test_job_book.gd
var fails := 0
var main: SurvivalCore
var male := AppearanceStore.default_look()


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	Sharpness.slips_on = false   # (exact planning and paths: no tired slips here; tests/companion/test_sharpness.gd has them)
	InputSetup.ensure()
	main = SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 7, "start_day": "sep_early", "start_hour": 8.0,
			"backlog_milestones": ["M2a", "M2b", "M3"], "settings": {"rest_need": false}})
	_book()
	_chain()
	_pull()
	_toggles()
	_two_workers()
	_saving()
	print("JOB BOOK TEST %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit(1 if fails else 0)


# ---------------------------------------------------------------- the book
func _book() -> void:
	for id in ["tend", "cook", "butcher", "woodpile", "smoke", "jerky", "tan", "stretch", "forage", "firewood"]:
		_expect(JobBook.has(id) and SpouseCore.TASKS.has(id), "the book has %s" % id)
	var stages: Array = JobBook.book().stages
	var roles := {"tend": "home", "cook": "home", "butcher": "home", "forage": "outside", "firewood": "outside"}
	for id: String in roles:
		_expect(JobBook.role_of(id) == roles[id], "%s runs %s" % [id, roles[id]])
	var kinds := {}
	for t in ["items", "materials", "fuel"]:
		kinds.merge(SurvivalBridge.load_items(t))
	var fd := FarmField.load_data()   # FARM: the seed and the crops the beds take and give (the store's kinds, not a core's)
	for c: String in fd.crops:
		kinds[String(fd.crops[c].item)] = true
		kinds[String(fd.crops[c].seed)] = true
	for id: String in JobBook.ids():
		var j := JobBook.job(id)
		_expect(stages.has(j.stage) and String(j.name) != "" and j.has("needs") and j.has("how") and j.has("inputs") and j.has("outputs"),
				"%s is a whole entry (%s, %s, needs %s)" % [id, j.stage, j.where, j.needs])
		for k: String in JobBook.inputs_of(id) + JobBook.inputs_of(id, true) + JobBook.outputs_of(id):
			_expect(kinds.has(k) or k in ["smoked_venison", "carcass"], "%s: %s is a pack kind" % [id, k])   # HUNT: the carcass links the hunt to the butcher
		if String(j.how.get("type", "")) == "survival":
			_expect(not main.data.action(String(j.how.action)).is_empty(), "%s runs a real survival action (%s)" % [id, j.how.action])


# ---------------------------------------------------------------- the chain
func _chain() -> void:
	_expect(JobBook.upstream("cook").has("butcher"), "cook comes after the butcher (carcass > butcher > venison > cook)")
	_expect(JobBook.upstream("tan") == ["butcher"], "tanning is fed by the butcher alone")
	for d in ["cook", "smoke", "jerky", "tan", "stretch"]:
		_expect(JobBook.downstream("butcher").has(d), "butcher feeds %s" % d)
	_expect(JobBook.downstream("firewood").has("tend") and JobBook.downstream("firewood").has("woodpile"), "firewood feeds the fires and the pile")
	_expect(not JobBook.upstream("smoke").has("firewood") and JobBook.upstream("smoke", true).has("firewood"), "the smudge's wood is fuel, not a link")
	_expect(JobBook.upstream_all("cook") == ["butcher", "hunt", "hoe", "farm"] and JobBook.downstream_all("butcher").size() >= 5,
			"the whole way up and down (%s)" % str(JobBook.upstream_all("cook")))   # HUNT, FARM
	var c := JobBook.chain("cook")
	_expect(c[0] == "hunt" and c[1] == "butcher" and c.has("cook") and c.has("stretch") and not c.has("tend"), "cook's chain starts at the hunt, then the butcher (%s)" % str(c))   # HUNT
	var seen := {}
	var dup := false
	for ch: Dictionary in JobBook.chains():
		for id: String in ch.jobs:
			dup = dup or seen.has(id)
			seen[id] = true
	# (a chain for each source: the cook is in the hunt's and the fields'; user 2026-09-29: "hunt is a different supply chain
	# and farming is a different supply chain")
	var in_both := JobBook.chains().filter(func(ch: Dictionary) -> bool: return (ch.jobs as Array).has("cook")).map(func(ch: Dictionary) -> String: return String(ch.id))
	_expect(seen.size() == JobBook.ids().size() and in_both == ["hunt", "hoe"], "every job is in a chain; the cook in the hunt's and the fields' (%s)" % str(in_both))
	_expect(JobBook.chain("hoe") == ["hoe", "farm", "cook"] and JobBook.chain_of("hoe").name == "Farm: the beds to the table", "the fields' chain: the hoe, the sowing and harvest, the cook (%s)" % str(JobBook.chain("hoe")))
	_expect(JobBook.chain("firewood")[0] == "firewood" and JobBook.chain("forage") == ["forage"], "the wood chain starts at the woods; foraging stands alone")
	var cb := JobBook.cascade("butcher")
	_expect(not cb.has("cook") and cb.has("jerky") and cb.has("tan") and cb.has("stretch"), "switching the butcher off takes what only it feeds (not the cook: the fields feed it too)")
	_expect(JobBook.cascade("cook") == ["cook"], "cook feeds nothing")
	_expect(JobBook.cascade("firewood").has("tend") and JobBook.cascade("firewood").has("woodpile"), "firewood off takes the fires' feeding")


# ---------------------------------------------------------------- the planner
func _worker(seed_v := 31) -> SpouseCore:
	var w := SpouseCore.create(main, male, seed_v)
	w.role = "home"
	_skip_to_hour(w, 10.0)
	return w


func _pull() -> void:
	var w := _worker()
	_expect(w.plan().is_empty(), "nothing short of anything runnable and nothing to work: nothing planned (%s)" % str(w.plan()))
	var short := w.shortages()
	_expect(short.has("meals") and short.meals.size == 6 and short.has("firewood"), "the targets: 3 meals a person for two (%s)" % str(short.get("meals")))
	# a shortage of cooked food pulls the cook, ahead of the smokehouse
	var smoke := FakeSmoke.new()
	w.finders = {"smoke": func() -> Object: return smoke, "rack": func() -> Object: return FakeSite.new()}
	w.stock.put("venison", 6)
	w.stock.put("firewood", 9)
	w.stock.put("jerky", 20)
	_expect(w.plan().get("task", "") == "cook", "no cooked food: the shortage pulls the cook before smoking (%s)" % str(w.plan()))
	w.stock.put("roast_venison", 6)
	var p := w.plan()
	_expect(p.get("task", "") in ["smoke", "jerky"], "cooked food in hand: the venison goes to the preserving (%s)" % str(p))
	w.stock.take("roast_venison", 99)
	# butcher: only with a carcass, and after cooking what is in hand
	w.stock.take("venison", 99)
	w.finders = {}
	_expect(w.plan().get("task", "") != "butcher", "a shortage of venison pulls no butcher without a carcass (%s)" % str(w.plan()))
	var carcass := FakeCarcass.new()
	w.carcass_finder = func(skip := []) -> Object: return null if skip.has(carcass.get_instance_id()) else carcass
	_expect(w.plan().get("task", "") == "butcher", "a carcass: the butcher is planned (%s)" % str(w.plan()))
	w.stock.put("venison", 3)
	_expect(w.plan().get("task", "") == "cook", "meat in hand is cooked before a carcass is cut (%s)" % str(w.plan()))
	w.stock.take("venison", 99)
	w.carcass_finder = Callable()
	# gathering only on a shortage
	w.role = "outside"
	_skip_to_hour(w, 9.0)
	w.stock.put("firewood", 20)
	w.stock.put("blackberries", 20)
	w.stock.put("roast_venison", 20)
	_expect(w.plan().is_empty(), "outside with everything stocked: nothing planned (%s)" % str(w.plan()))
	w.stock.take("firewood", 99)
	_expect(w.plan().get("task", "") == "firewood", "a firewood shortage pulls the gathering (%s)" % str(w.plan()))
	w.stock.put("firewood", 20)
	w.focus = "forage"
	_expect(w.plan().get("task", "") == "forage", "asked for by name it goes first even when nothing is short")
	# the reserve: the venison kept for cooking is never preserved
	w.role = "home"
	w.focus = ""
	w.stock.take("roast_venison", 99)
	w.stock.put("roast_venison", 20)
	w.finders = {"smoke": func() -> Object: return smoke}
	w.stock.take("venison", 99)
	w.stock.put("venison", 2)
	_expect(w.plan().get("task", "") != "smoke", "the two kept back are not smoked")
	w.stock.put("venison", 2)
	_expect(w.offer("smoke").inputs.get("venison", 0) == 2, "only what is above the reserve is hung (%s)" % str(w.offer("smoke").inputs))


# ---------------------------------------------------------------- toggles
func _toggles() -> void:
	var w := _worker(32)
	var crew := w.stock.crew
	var smoke := FakeSmoke.new()
	w.finders = {"smoke": func() -> Object: return smoke}
	w.stock.put("roast_venison", 20)
	w.stock.put("venison", 8)
	_expect(w.plan().get("task", "") == "smoke", "smoke is planned (%s)" % str(w.plan()))
	crew.set_enabled(w, "smoke", false)
	_expect(w.plan().get("task", "") == "cook", "smoke off: the link is not planned, the next is (%s)" % str(w.plan()))
	crew.set_enabled(w, "cook", false)
	_expect(w.plan().is_empty(), "cook off too: nothing left to plan")
	crew.set_enabled(w, "cook", true)
	crew.set_enabled(w, "smoke", true)
	crew.set_enabled(w, "butcher", false, true)
	_expect(w.enabled.cook and not w.enabled.smoke and not w.enabled.jerky and not w.enabled.tan and w.enabled.tend and w.enabled.firewood,
			"the butcher off with what only it feeds (the cook stays: the fields feed it too); the wood chain untouched")
	_expect(w.plan().get("task", "") == "cook", "so the venison is not smoked or dried; the cook, still on, cooks it (%s)" % str(w.plan()))
	crew.set_enabled(w, "cook", true, true)
	_expect(w.enabled.cook and w.enabled.butcher, "cook on brings the link that feeds it")
	crew.set_chain(w, JobBook.chain_of("cook").id, false)
	_expect(w.enabled.cook and not w.enabled.butcher and not w.enabled.hunt and not w.enabled.stretch and w.enabled.firewood,
			"a chain off as a whole, the cook it shares with the fields left on")
	crew.set_chain(w, JobBook.chain_of("cook").id, true)
	# a job nobody does pulls nothing
	_expect(JobBook.pull("butcher", w.shortages(), func(_id: String) -> bool: return false) == 0.0, "no one doing the downstream: the butcher is not pulled")
	# a running job stopped by its toggle
	w.stock.put("firewood", 9)
	var pile := FakePile.new()
	w.finders = {"pile": func() -> Object: return pile}
	w.begin("woodpile")
	_expect(w.busy(), "stocking begins")
	crew.set_enabled(w, "woodpile", false)
	_expect(not w.busy() and w.stock.count("firewood") == 9, "switching a running job off stops it and takes nothing")


# ---------------------------------------------------------------- two workers
func _two_workers() -> void:
	var a := _worker(41)
	var b := SpouseCore.create_unit(main, 42)
	b.role = "home"
	b.join(a.stock)
	_skip_to_hour(b, 10.0)
	_expect(a.stock.crew.size() == 2 and a.worker_id != b.worker_id and a.stock.crew.people() == 3, "two workers in one household (ids %d, %d)" % [a.worker_id, b.worker_id])
	_expect(b.title() == "hand" or b.worker_id == 0, "a unit is a generic hand")
	a.stock.put("roast_venison", 30)
	a.stock.put("venison", 3)
	var p := a.plan()
	_expect(p.get("task", "") == "cook", "the first plans the cook (%s)" % str(p))
	_expect(b.plan().get("task", "") != "cook", "the second finds the venison spoken for (%s)" % str(b.plan()))
	_expect(not b.begin("cook") and b.stock.count("venison") == 3, "and cannot take it")
	_expect(a.begin("cook") and a.busy(), "the first cooks")
	_skip_time(a, b, 15.0)
	_expect(a.stock.count("venison") == 0, "the venison is in her pot")
	for i in 40:
		_skip_time(a, b, 15.0)
		if not a.busy():
			break
	_expect(not a.busy() and a.stock.count("roast_venison") + a.stock.count("charred_venison") > 30, "the roast came into the shared store")
	# one carcass: one worker
	var carcass := FakeCarcass.new()
	var finder := func(skip := []) -> Object: return null if skip.has(carcass.get_instance_id()) or carcass.meat_left <= 0.0 else carcass
	a.carcass_finder = finder
	b.carcass_finder = finder
	_expect(a.plan().get("task", "") == "butcher", "the first takes the carcass")
	_expect(b.plan().get("task", "") != "butcher" and not b.begin("butcher"), "the second cannot butcher the same one")
	a.cancel("test")
	a.stock.release(a.worker_id)
	# split the chain: she butchers, he cooks
	a.carcass_finder = finder
	b.carcass_finder = finder
	a.stock.crew.set_jobs(a, ["butcher"])
	a.stock.crew.set_jobs(b, ["cook"])
	a.stock.take("venison", 99)
	a.stock.take("roast_venison", 99)
	a.stock.take("charred_venison", 99)
	a.stock.crew.set_enabled(a, "tend", false)
	_expect(a.plan().get("task", "") == "butcher" and b.plan().is_empty(), "the chain is split: only the butcher works, the cook has nothing yet (%s)" % str(b.plan()))
	_expect(a.begin("butcher"), "she butchers")
	_skip_time(a, b, 90.0)
	_expect(not a.busy() and a.stock.count("venison") == 3, "the venison is in the store (%d)" % a.stock.count("venison"))
	_expect(b.plan().get("task", "") == "cook" and a.plan().is_empty(), "now the cook has work and she has none (%s)" % str(a.plan()))
	# a hoop is shared: two pelts at most in the household
	a.stock.crew.set_jobs(a, ["stretch"])
	a.stock.crew.set_jobs(b, ["stretch"])
	a.finders = {"hoop": func() -> Object: return null}
	a.hoop = [{"pelt": "wolf_pelt", "dried": "dried_wolf_pelt", "ready_at": 1e9}]
	b.hoop = [{"pelt": "fox_pelt", "dried": "dried_fox_pelt", "ready_at": 1e9}]
	var site := FakeSite.new()
	b.finders = {"hoop": func() -> Object: return site}
	b.stock.put("wolf_pelt", 1)
	_expect(b.plan().is_empty(), "the hoops are full between them")
	a.hoop = []
	_expect(b.plan().get("task", "") == "stretch", "one comes free (%s)" % str(b.plan()))


# ---------------------------------------------------------------- saving
func _saving() -> void:
	var a := _worker(51)
	var b := SpouseCore.create_unit(main, 52)
	b.join(a.stock)
	a.stock.crew.set_enabled(b, "cook", false)
	a.stock.crew.set_jobs(b, ["butcher", "cook", "tan"])
	a.stock.crew.set_enabled(b, "cook", false)
	var d: Dictionary = JSON.parse_string(JSON.stringify(a.stock.crew.to_dict([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])))
	var store := HouseholdStock.new()
	var crew := HouseholdCrew.new()
	store.crew = crew
	var ats := crew.load_dict(d, main, store)
	_expect(crew.size() == 2 and crew.workers[0].name == a.name and crew.workers[1].name == b.name, "both workers come back")
	_expect(crew.workers[1].worker_id == b.worker_id and crew.workers[0].worker_id == 0, "with their places")
	_expect(not crew.workers[1].enabled.cook and crew.workers[1].enabled.tan and not crew.workers[1].enabled.forage, "and what each does")
	_expect(crew.workers[0].stock == store and ats.size() == 2 and (ats[1] as Array)[2] == 6.0, "sharing the store, at their places")
	# the old save: one spouse
	var old := {"spouse": a.to_dict(), "home": [7.0, 8.0, 9.0], "at": [1.0, 2.0, 3.0]}
	old.spouse.erase("id")
	old.spouse.enabled = {"tend": false}
	var s2 := HouseholdStock.new()
	var c2 := HouseholdCrew.new()
	s2.crew = c2
	var ats2 := c2.load_dict(JSON.parse_string(JSON.stringify(old)), main, s2)
	_expect(c2.size() == 1 and c2.workers[0].worker_id == 0 and c2.workers[0].name == a.name, "an old single-spouse save loads as worker 0")
	_expect(not c2.workers[0].enabled.tend and c2.workers[0].enabled.cook and (ats2[0] as Array)[0] == 1.0, "with her jobs (new ones on) and her place")


# ---------------------------------------------------------------- helpers
func _skip_to_hour(w: SpouseCore, hr: float) -> void:
	var cur := fposmod(main.state.minutes, 1440.0) / 60.0
	main.advance(fposmod(hr - cur, 24.0) * 60.0)
	for o: SpouseCore in w.stock.crew.workers:
		o.sync(main)
	w.sync(main)


func _skip_time(a: SpouseCore, b: SpouseCore, minutes: float) -> void:
	main.advance(minutes)
	a.sync(main)
	b.sync(main)


class FakePile extends RefCounted:
	var wood := 0

	func wood_room() -> int:
		return 12 - wood

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


class FakeSite extends RefCounted:
	pass


## A carcass to butcher: dress_step, meat_left, and finish_dress giving 3 venison.
class FakeCarcass extends RefCounted:
	var dress_step := 1
	var meat_left := 1.0

	func finish_dress(_step: String, hands: Object) -> void:
		hands.inventory_pack = [{"kind": "venison", "count": 3}]
		meat_left = 0.0
