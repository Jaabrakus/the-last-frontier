extends SceneTree
## The household's tool pool (ToolPool, scripts/companion/tool_pool.gd; data/companion/tools.json), headless: a worker's own
## kit is not hers, the start pool, checkout and return, reservations between two workers, required and optional tools, a job
## not planned without its tool, the survival action seeing the borrowed hatchet, consumables used up, wear and breaking, the
## end of her day, the save round trip and an old save's kits coming into the pool.
##   Godot --headless --path . -s tests/companion/test_tool_pool.gd
var fails := 0
var main: SurvivalCore
var crew: Array = []


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	InputSetup.ensure()
	main = SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 7, "start_day": "sep_early", "start_hour": 8.0,
			"backlog_milestones": ["M2a", "M2b", "M3"], "settings": {"rest_need": false}})
	_data()
	_kit_and_start()
	_checkout_return()
	_two_workers()
	_required_optional()
	_planning_and_the_rules()
	_consumables()
	_wear_break()
	_save_round_trip()
	_old_save()
	print("TOOL POOL TEST %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit(1 if fails else 0)


func _store() -> Array:
	var s := HouseholdStock.new()
	var p := ToolPool.install(s)
	p.rng.seed = 5
	return [s, p]


func _worker(s: HouseholdStock, seed_v: int, role := "outside") -> SpouseCore:
	var w := SpouseCore.create_unit(main, seed_v)
	w.join(s)
	w.role = role
	crew.append(w)
	return w


func _skip_to_hour(hr: float) -> void:
	var cur := fposmod(main.state.minutes, 1440.0) / 60.0
	main.advance(fposmod(hr - cur, 24.0) * 60.0)
	for w: SpouseCore in crew:
		w.sync(main)


func _only(w: SpouseCore, job: String) -> void:
	for id: String in JobBook.ids():
		w.enabled[id] = id == job


# ---------------------------------------------------------------- the data
func _data() -> void:
	var fw := ToolPool.needs_of("firewood")
	_expect((fw.need as Array).size() == 1 and (fw.need[0] as Array).has("hatchet") and (fw.need[0] as Array).has("axe"),
			"firewood needs an axe group, joined with wood.split_firewood's (%s)" % str(fw.need))
	var tan := ToolPool.needs_of("tan")
	_expect((tan.need as Array).size() == 1 and (tan.need[0] as Array)[0] == "trade_knife", "tanning needs a knife (the recipes' and the job's, once: %s)" % str(tan.need))
	var st := ToolPool.needs_of("stretch")
	_expect(not (st.need as Array).is_empty() and not (st.optional as Array).is_empty(), "stretching: a knife, an awl if free (%s)" % str(st))
	_expect((ToolPool.needs_of("cook").need as Array).is_empty(), "cooking needs no tool")
	_expect(ToolPool.resolve("felling_axe") == "axe" and ToolPool.resolve("skinning_knife") == "trade_knife", "the player's kinds name the pool's")
	_expect(ToolPool.is_rack("musket") and not ToolPool.is_rack("hatchet") and not ToolPool.is_rack("venison"), "muskets stand in the racks, hatchets lie in chests")
	_expect(StorageChest.can_store("hatchet") and StorageChest.can_store("trade_knife") and not StorageChest.can_store("felling_axe"),
			"a chest takes the household's tools, never the player's own felling axe")


# ---------------------------------------------------------------- her kit, the start
func _kit_and_start() -> void:
	var sp := _store()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	var w := _worker(s, 21)
	_expect(SurvivalInventory.has(w.core, "item.tool.hatchet") and SurvivalInventory.has(w.core, "item.weapon.musket"), "a new worker's core starts with the background's kit")
	ToolPool.tick(w)
	_expect(not SurvivalInventory.has(w.core, "item.tool.hatchet") and not SurvivalInventory.has(w.core, "item.weapon.musket")
			and not SurvivalInventory.has(w.core, "item.ammo.powder"), "joined to a household with a pool, the kit is gone from her core")
	_expect(not SurvivalInventory.by_cat(w.core, "clothing").is_empty(), "she keeps her clothes")
	_expect(p.owned("hatchet") == 0 and p.owned("musket") == 0, "a new worker brings nothing into the pool")
	p.seed_start(true)
	_expect(p.in_store("hatchet") == 2 and p.in_store("trade_knife") == 3 and p.in_store("flint_steel") == 2 and p.in_store("musket") == 1
			and p.in_store("spear_pair") == 2 and p.in_store("steel_trap") == 2 and p.in_store("powder") >= 1,
			"the start pool: hatchets, knives, flint and steel, a musket, spears, traps, powder (%s)" % str(p.counts().keys()))
	p.seed_start(true)
	_expect(p.in_store("hatchet") == 2, "the start pool is put in once")
	crew.erase(w)


func _checkout_return() -> void:
	var sp := _store()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	p.seed_start(true)
	var w := _worker(s, 22)
	var r := p.checkout(w, {"need": [["hatchet", "axe"]]})
	_expect(bool(r.ok) and int((r.items as Dictionary).get("hatchet", 0)) == 1, "checkout: a hatchet (%s)" % str(r))
	_expect(p.available("hatchet") == 1 and s.count("hatchet") == 1 and p.held_by(w) == {"hatchet": 1}, "it left the chest, she holds it")
	_expect(p.counts().hatchet.out == 1 and p.counts().hatchet.by.has(w.name), "counts say who has it out")
	r = p.checkout(w, {"need": [["hatchet", "axe"]]})
	_expect(bool(r.ok) and p.held_by(w) == {"hatchet": 1}, "checking out again uses the one she holds")
	_expect(p.return_all(w) == 1 and s.count("hatchet") == 2 and p.held_by(w).is_empty(), "return_all puts it back")
	# the hunt's source shape
	_expect(p.count("skinning_knife", w.worker_id) == 3 and p.take("musket", 1, w.worker_id) == 1 and p.available("musket") == 0,
			"HuntKit's shape: count by the player's kind, take a rack's musket")
	_expect(p.put_back("musket", 1, w.worker_id) == 1 and p.available("musket") == 1, "put_back stands it in again")
	s.put("jerky", 3)
	_expect(p.take("jerky", 2, w.worker_id) == 2 and s.count("jerky") == 1, "a kind the pool does not lend comes from the store")
	crew.erase(w)


func _two_workers() -> void:
	var sp := _store()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	p.add("hatchet", 1)
	var a := _worker(s, 23)
	var b := _worker(s, 24)
	_skip_to_hour(9.0)
	for w: SpouseCore in [a, b]:
		ToolPool.tick(w)
		_only(w, "firewood")
	var pa := a.plan()
	var pb := b.plan()
	_expect(String(pa.get("task", "")) == "firewood" and int((p.claims.get(a.worker_id, {}) as Dictionary).get("hatchet", 0)) == 1,
			"the first plans firewood and claims the hatchet (%s)" % str(pa))
	_expect(pb.is_empty() and String((p.blocked.get(b.worker_id, {}) as Dictionary).get("firewood", "")) == "no hatchet free",
			"the second cannot plan it: no hatchet free (%s)" % str(p.blocked))
	_expect(p.available("hatchet", b.worker_id) == 0 and p.available("hatchet", a.worker_id) == 1, "the claim keeps it for the first")
	p.add("hatchet", 1)
	pb = b.plan()
	_expect(String(pb.get("task", "")) == "firewood", "a second hatchet in the chest: the second worker plans firewood too")
	_expect(a.begin("firewood") and b.begin("firewood") and p.held_by(a) == {"hatchet": 1} and p.held_by(b) == {"hatchet": 1} and p.in_store("hatchet") == 0,
			"both at work, each with a hatchet of her own")
	a.cancel("test")
	b.cancel("test")
	p.return_all(a)
	p.return_all(b)
	_expect(p.in_store("hatchet") == 2, "both back")
	crew.erase(a)
	crew.erase(b)


func _required_optional() -> void:
	var sp := _store()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	p.add("trade_knife", 1)
	p.add("awl", 1)
	var w := _worker(s, 25)
	var needs := {"need": [["trade_knife", "flint_knife"]], "optional": [["awl", "bone_awl"]]}
	var r := p.checkout(w, needs)
	_expect(bool(r.ok) and (r.items as Dictionary).has("awl"), "an optional awl comes when free (%s)" % str(r.items))
	p.return_all(w)
	s.take("awl", 1)
	r = p.checkout(w, needs)
	_expect(bool(r.ok) and not (r.items as Dictionary).has("awl"), "without it the job still goes")
	p.return_all(w)
	s.take("trade_knife", 1)
	r = p.checkout(w, needs)
	_expect(not bool(r.ok) and String(r.reason) == "no knife free", "without a knife it does not (%s)" % String(r.reason))
	p.add("flint_knife", 1)
	r = p.checkout(w, needs)
	_expect(bool(r.ok) and (r.items as Dictionary).has("flint_knife"), "a flint knife serves the knife group")
	p.return_all(w)
	crew.erase(w)


# ---------------------------------------------------------------- planning, the survival action, the end of her day
func _planning_and_the_rules() -> void:
	var sp := _store()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	var w := _worker(s, 26)
	ToolPool.tick(w)
	_only(w, "firewood")
	_skip_to_hour(9.0)
	w.set_place("woods")
	var r := w.core.start_job("wood.split_firewood", {})
	_expect(not bool(r.get("ok", false)), "without a hatchet of her own the rules will not split wood (%s)" % str(r.get("reasons", [])))
	if SurvivalJobs.is_running(w.core):
		w.core.cancel_job("test")
	_expect(w.plan().is_empty() and (p.blocked.get(w.worker_id, {}) as Dictionary).has("firewood"), "firewood is not planned with no axe in the pool")
	_expect(not w.begin("firewood") and String(w.journal[-1]).contains("hatchet"), "asked straight, she says why (%s)" % String(w.journal[-1]))
	w._cool = 0.0
	p.add("hatchet", 1)
	var q := w.plan()
	_expect(String(q.get("task", "")) == "firewood" and not p.blocked.has(w.worker_id), "a hatchet in the chest: firewood is planned")
	_expect(w.begin("firewood"), "firewood begins")
	_expect(SurvivalInventory.has(w.core, "item.tool.hatchet") and p.in_store("hatchet") == 0, "the borrowed hatchet is in her core while she works")
	var fire0 := s.count("firewood")
	for i in 60:
		main.advance(10.0)
		w.sync(main)
		if not w.busy():
			break
	_expect(not w.busy() and s.count("firewood") > fire0, "she split and brought back firewood (%d)" % s.count("firewood"))
	_expect(not SurvivalInventory.has(w.core, "item.tool.hatchet") and p.held_by(w) == {"hatchet": 1}, "the hatchet is out of her core but still with her")
	var u: Dictionary = p.held[w.worker_id]["hatchet"][0]
	_expect(is_equal_approx(float(u.wear), 1.0), "a run wore it (%.1f)" % float(u.wear))
	q = w.plan()
	_expect(String(q.get("task", "")) == "firewood" and not p.claims.has(w.worker_id), "the next run of the same job keeps her hatchet")
	w.abandon_plan()
	# a job with no tools: what she holds is due back
	_only(w, "forage")
	q = w.plan()
	_expect(String(q.get("task", "")) == "forage" and p.held_by(w).is_empty() and p.in_store("hatchet") == 1,
			"switching job she puts the hatchet back (no body: at once)")
	_expect(p.stored_wear.get("hatchet", []) == [1.0], "its wear is kept in the chest")
	w.abandon_plan()
	# the end of her day
	_only(w, "firewood")
	_skip_to_hour(10.0)
	q = w.plan()
	_expect(w.begin(String(q.get("task", "firewood"))) and p.held_by(w) == {"hatchet": 1}, "morning: the hatchet again (%s)" % str(q))
	var hw := float(p.held[w.worker_id]["hatchet"][0].wear)
	_expect(is_equal_approx(hw, 1.0), "the same worn hatchet came out (%.1f)" % hw)
	w.cancel("test")
	_skip_to_hour(20.0)
	_expect(p.held_by(w).is_empty() and p.in_store("hatchet") == 1, "at dusk she has put it back")
	# a worker who leaves
	p.checkout(w, {"need": [["hatchet"]]})
	ToolPool.leave(w)
	_expect(p.in_store("hatchet") == 1 and p.held_by(w).is_empty(), "a worker who leaves returns what she held")
	# one who dies
	var d := _worker(s, 31)
	ToolPool.tick(d)
	p.checkout(d, {"need": [["hatchet"]]})
	d.core.state.flags["dead"] = true
	p.seeded = {"chest": true, "rack": true}
	p.tick_house(5.0)
	_expect(p.in_store("hatchet") == 1 and p.held_by(d).is_empty(), "a dead worker's things come home")
	crew.erase(d)
	crew.erase(w)


func _consumables() -> void:
	var sp := _store()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	p.add("powder", 5)
	var w := _worker(s, 27)
	ToolPool.tick(w)
	var r := p.checkout(w, {"use": {"powder": 2}})
	_expect(bool(r.ok) and p.held_by(w) == {"powder": 2} and s.count("powder") == 3, "two powder out for a run")
	ToolPool.load_core(w)
	_expect(is_equal_approx(SurvivalInventory.count(w.core, "item.ammo.powder"), 2.0), "in her core for the rules")
	SurvivalInventory.remove(w.core, "item.ammo.powder", 1.5)   # the run used a unit and a half
	ToolPool.run_ended(w)
	_expect(is_equal_approx(SurvivalInventory.count(w.core, "item.ammo.powder"), 0.0) and p.held_by(w).is_empty()
			and is_equal_approx(float(p.partial.get("powder", 0.0)), 0.5), "used up: none whole left, the half kept by the pool (%s)" % str(p.partial))
	r = p.checkout(w, {"use": {"powder": 1}})
	ToolPool.load_core(w)
	SurvivalInventory.remove(w.core, "item.ammo.powder", 0.5)
	ToolPool.run_ended(w)
	_expect(p.held_by(w) == {"powder": 1} and is_equal_approx(float(p.partial.get("powder", 0.0)), 0.0), "two halves make a whole one again")
	p.return_all(w)
	_expect(s.count("powder") == 3, "leftovers back in the store (%d)" % s.count("powder"))
	_expect(not bool(p.checkout(w, {"use": {"powder": 9}}).ok), "not more than there is")
	p.take("powder", 1, w.worker_id)
	_expect(p.spend(w, "powder", 1) == 1 and p.held_by(w).is_empty() and s.count("powder") == 2, "spend: a hunt's shot is gone")
	crew.erase(w)


func _wear_break() -> void:
	var sp := _store()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	p.add("hatchet", 1, [{"wear": ToolPool.durability("hatchet") - 1.0}])
	var w := _worker(s, 28)
	var r := p.checkout(w, {"need": [["hatchet"]]})
	_expect(bool(r.ok) and float(p.held[w.worker_id].hatchet[0].wear) >= ToolPool.durability("hatchet") - 1.0, "an old hatchet out, its wear with it")
	var br := p.wear(w, "firewood")
	_expect(br == ["hatchet"] and p.held_by(w).is_empty() and p.broken.size() == 1 and String(p.broken[0].by) == w.name,
			"worn out, it breaks in her hands (%s)" % str(p.broken))
	_expect(p.owned("hatchet") == 0 and not p.journal.is_empty(), "a broken tool is not owned any more; it is told (%s)" % str(p.journal))
	# rarely, a sound one: break_chance
	p.add("hatchet", 1)
	p.checkout(w, {"need": [["hatchet"]]})
	var n := 0
	for i in 400:
		if not p.wear(w, "firewood").is_empty():
			n += 1
			p.add("hatchet", 1)
			p.checkout(w, {"need": [["hatchet"]]})
		p.held[w.worker_id]["hatchet"][0]["wear"] = 0.0
	_expect(n >= 0 and n <= 6, "a sound hatchet breaks rarely (%d in 400 runs)" % n)
	crew.erase(w)


# ---------------------------------------------------------------- saving
func _save_round_trip() -> void:
	var sp := _store()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	p.seed_start(true)
	var w := _worker(s, 29)
	ToolPool.tick(w)
	p.checkout(w, {"need": [["hatchet"]], "use": {"powder": 1}})
	p.held[w.worker_id]["hatchet"][0]["wear"] = 12.0
	p.stored_wear["trade_knife"] = [3.0]
	p.partial["powder"] = 0.25
	p.broken.append({"kind": "awl", "name": "Awl", "by": w.name, "day": 2})
	var d: Variant = JSON.parse_string(JSON.stringify(p.save_data()))
	var s2 := HouseholdStock.new()
	s2.kinds = s.kinds.duplicate()
	var p2 := ToolPool.install(s2)
	var w2 := SpouseCore.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())), main)
	w2.join(s2)
	p2.load_data(d)
	_expect(p2.held_by(w2.worker_id) == {"hatchet": 1, "powder": 1} and is_equal_approx(float(p2.held[w2.worker_id].hatchet[0].wear), 12.0),
			"save round trip: who holds what, and its wear (%s)" % str(p2.held))
	_expect(p2.stored_wear.get("trade_knife", []) == [3.0] and is_equal_approx(float(p2.partial.get("powder", 0.0)), 0.25) and p2.broken.size() == 1,
			"the chests' wear, the part powder and the broken awl kept")
	_expect(String(p2.kits.get(w2.worker_id, "")) == "pooled" and bool(p2.seeded.chest), "her kit done, the start not put in twice")
	var had := SurvivalInventory.count(w2.core, "item.tool.knife")
	ToolPool.tick(w2)
	_expect(is_equal_approx(SurvivalInventory.count(w2.core, "item.tool.knife"), had) and p2.owned("trade_knife") == 3, "nothing brought in again")
	crew.erase(w)


func _old_save() -> void:
	# a worker saved before the pool: her background's kit is in her core; the save has no "tools" part
	var old := SpouseCore.create_unit(main, 30)
	var d: Dictionary = JSON.parse_string(JSON.stringify(old.to_dict()))
	var sp := _store()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	var w := SpouseCore.from_dict(d, main)
	w.join(s)
	crew.append(w)
	p.load_data(null)
	_expect(not w.tool_kit_new and SurvivalInventory.has(w.core, "item.tool.hatchet"), "an old save's worker has her kit")
	ToolPool.tick(w)
	_expect(not SurvivalInventory.has(w.core, "item.tool.hatchet") and not SurvivalInventory.has(w.core, "item.weapon.musket"),
			"on load her kit leaves her core ...")
	_expect(p.owned("hatchet") == 1 and p.owned("trade_knife") == 1 and p.owned("musket") == 1 and p.owned("flint_steel") == 1
			and p.owned("powder") == 2 and p.owned("musket_balls") == 12 and p.owned("awl") == 1,
			"... into the pool, once (%s)" % str(s.kinds))
	ToolPool.tick(w)
	_expect(p.owned("hatchet") == 1, "only once")
	_expect(bool(p.seeded.chest) and p.owned("spear_pair") == 0, "an old save's fort gets no start pool on top")
	crew.erase(w)
