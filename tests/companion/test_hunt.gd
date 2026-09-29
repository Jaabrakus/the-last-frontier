extends SceneTree
## The household's hunting job, logic only (HuntJob, data/companion/hunt.json, jobs.json "hunt"): the planner pulls it on a meat
## shortage along the chain (hunt > butcher > cook ...), a weapon and a shot are required (her kit or the store), the shot's
## odds by distance, skill and what the animal is doing, the ammunition it spends, the sign (the core's hunt.track) finding
## the quarry, the kill's way home (hauled for the butcher at home, or dressed and carried: deposited), and the refusals
## (night, wolves); the kit out of the household's TOOL POOL (the weapon she is best at with shot for it, none: no hunt,
## the shot spent as it is fired, the rest back after), and how the kill comes home (HuntHaul: her smarts, its weight, the
## distance, the horse > the cart > the wheelbarrow when free and reserved while hers, else dragged or quartered). The ground
## (the level's wildlife) is a fake here; the level run is tests/companion/hunt_shots.gd.
##   Godot --headless --path . -s tests/companion/test_hunt.gd
var fails := 0
var main: SurvivalCore
var male := AppearanceStore.default_look()


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	InputSetup.ensure()
	main = SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 11, "start_day": "sep_early", "start_hour": 8.0,
			"backlog_milestones": ["M2a", "M2b", "M3"], "settings": {"rest_need": false}})
	_chain()
	_planning()
	_weapon_and_ammo()
	_odds()
	_fire()
	_sign()
	_kill_home()
	_refusals()
	_father()
	_pool_kit()
	_pool_two_hunters()
	_pool_bow_and_spears()
	_transport_choice()
	_gear_loadout()
	await process_frame                        # (the scene tree is up: the level's transport in a small world)
	_transport_free()
	print("HUNT TEST %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit(1 if fails else 0)


func _worker(seed_v := 41, role := "outside") -> SpouseCore:
	var w := SpouseCore.create(main, male, seed_v)
	w.role = role
	_skip_to_hour(w, 9.0)
	return w


func _skip_to_hour(w: SpouseCore, hr: float) -> void:
	var cur := fposmod(main.state.minutes, 1440.0) / 60.0
	main.advance(fposmod(hr - cur, 24.0) * 60.0)
	for o: SpouseCore in w.stock.crew.workers:
		o.sync(main)


## Everything but meat in hand: the pantry, firewood, furs full; no cooked food, jerky or leather (the meat and hide shortages).
func _stock_but_meat(w: SpouseCore) -> void:
	w.stock.put("blackberries", 20)
	w.stock.put("firewood", 20)
	w.stock.put("dried_wolf_pelt", 4)


func _game(w: SpouseCore) -> FakeGround:
	var g := FakeGround.new()
	g.quarry = FakeDeer.new()
	w.finders["game"] = func() -> Object: return g
	return g


# ---------------------------------------------------------------- the chain
func _chain() -> void:
	_expect(JobBook.has("hunt") and JobBook.role_of("hunt") == "outside" and JobBook.stage_of("hunt") == "gather", "the book has the hunt: outside, gathering")
	_expect(JobBook.upstream("butcher") == ["hunt"] and JobBook.downstream("hunt") == ["butcher"], "the hunt feeds the butcher")
	var c := JobBook.chain("hunt")
	_expect(c[0] == "hunt" and c[1] == "butcher" and c.has("cook") and c.has("tan"), "the game chain: hunt, butcher, cook ... (%s)" % str(c))
	_expect(JobBook.chain_of("hunt").name == "Game: the hunt to the table", "the chain is named for the hunt")
	_expect(not JobBook.cascade("hunt").has("butcher"), "the hunt off leaves the butcher on (the player's kills) (%s)" % str(JobBook.cascade("hunt")))
	var w := _worker()
	var view := w.stock.crew.chain_view()
	var found := false
	for ch: Dictionary in view:
		var ids := []
		for l: Dictionary in ch.links:
			ids.append(String(l.job))
		if ids.size() >= 2 and ids[0] == "hunt" and ids[1] == "butcher":
			found = true
	_expect(found, "the household's chain view shows the hunt feeding the butcher")
	var short := w.shortages()
	_expect(short.has("meals") and JobBook.pull("hunt", short) > 0.3, "an empty store's meal shortage pulls the hunt through the butcher (%.2f)" % JobBook.pull("hunt", short))


# ---------------------------------------------------------------- planning
func _planning() -> void:
	var w := _worker(43)
	_stock_but_meat(w)
	_expect(SurvivalInventory.has(w.core, "item.weapon.musket") and HuntJob.kit_shots(w, HuntJob.weapon_cfg("musket")) > 0,
			"the hunter's kit has the musket and shot (%d)" % HuntJob.kit_shots(w, HuntJob.weapon_cfg("musket")))
	_expect(w.plan().get("task", "") != "hunt", "no game about (no ground): no hunt (%s)" % str(w.plan()))
	w.abandon_plan()
	_game(w)
	var p := w.plan()
	_expect(p.get("task", "") == "hunt" and p.get("site", "") == "woods", "a meat shortage and game about: the hunt is planned, in the woods (%s)" % str(p))
	w.abandon_plan()
	# everything in hand: nothing pulls it
	w.stock.put("roast_venison", 20)
	w.stock.put("jerky", 20)
	w.stock.put("buckskin", 6)
	_expect(w.plan().get("task", "") != "hunt", "meat, jerky and leather in hand: no hunt (%s)" % str(w.plan()))
	w.abandon_plan()
	# a designated hunter hunts on the shortage even with the pantry short (the wife at home butchers)
	var h := _worker(45)
	_game(h)
	var wife := SpouseCore.create_unit(main, 46, 0.0)
	wife.worker_id = 1
	wife.role = "home"
	wife.join(h.stock)
	h.stock.crew.set_jobs(h, ["hunt"])
	_expect(h.plan().get("task", "") == "hunt", "a worker given only the hunt hunts when meat is short (%s)" % str(h.plan()))
	h.abandon_plan()
	# asked for by name
	var f := _worker(47)
	_game(f)
	f.stock.put("roast_venison", 20)
	f.stock.put("jerky", 20)
	f.stock.put("buckskin", 6)
	f.focus = "hunt"
	_expect(f.plan().get("task", "") == "hunt", "asked to hunt, she hunts with nothing short")
	f.abandon_plan()
	# a home worker never hunts
	var hm := _worker(49, "home")
	_game(hm)
	_expect(hm.plan().get("task", "") != "hunt", "a home worker does not hunt")
	hm.abandon_plan()


# ---------------------------------------------------------------- weapon and ammunition
func _weapon_and_ammo() -> void:
	var w := _worker(51)
	_game(w)
	var mus := HuntJob.weapon_cfg("musket")
	SurvivalInventory.remove(w.core, "item.weapon.musket", 9.0)
	SurvivalInventory.remove(w.core, "item.weapon.bow", 9.0)
	_expect(HuntJob.refusal(w) == HuntJob.line("no_kit") and HuntJob.offer(w).is_empty(), "no weapon: no hunt (%s)" % HuntJob.refusal(w))
	w.stock.put("musket", 1)
	var o := HuntJob.offer(w)
	_expect(o.get("weapon", "") == "musket" and o.get("weapon_from", "") == "musket", "a musket in the store: she borrows it (%s)" % str(o))
	_expect(w.begin("hunt") and w.stock.count("musket") == 0 and int((w.hunt.get("kit", {}) as Dictionary).get("musket", 0)) == 1,
			"out hunting, the store's musket is with her (%s)" % str(w.hunt.get("kit")))
	w.cancel("test")
	_expect(w.stock.count("musket") == 1 and w.hunt.is_empty() and not w.busy(), "the hunt over, the musket is back in the store")
	# no shot: none in her kit, none in the store
	SurvivalInventory.remove(w.core, "item.ammo.ball", 999.0)
	_expect(HuntJob.shots_available(w, mus) == 0 and HuntJob.offer(w).is_empty(), "no balls: no hunt")
	w.stock.put("musket_balls", 10)
	w.stock.put("powder", 1)
	_expect(HuntJob.shots_available(w, mus) >= 4 and not HuntJob.offer(w).is_empty(), "balls in the store: she can hunt (%d shots)" % HuntJob.shots_available(w, mus))
	_expect(w.begin("hunt"), "she goes out")
	var kit := HuntJob.kit_shots(w, mus)
	_expect(kit == int(HuntJob.cfg().carry_shots) and w.stock.count("musket_balls") == 10 - int(HuntJob.cfg().carry_shots),
			"her pouch topped up from the store to %d shots (store balls %d)" % [kit, w.stock.count("musket_balls")])
	w.cancel("test")
	# the bow when that is what she has
	var b := _worker(53)
	_game(b)
	SurvivalInventory.remove(b.core, "item.weapon.musket", 9.0)
	b.stock.put("bow", 1)
	b.stock.put("arrows", 6)
	var ob := HuntJob.offer(b)
	_expect(ob.get("weapon", "") == "bow", "no musket, a bow and arrows in the store: she hunts with the bow (%s)" % str(ob))


# ---------------------------------------------------------------- the odds
func _odds() -> void:
	var mus := HuntJob.weapon_cfg("musket")
	var bow := HuntJob.weapon_cfg("bow")
	var near := HuntJob.shot_odds(50.0, 30.0, mus)
	var mid := HuntJob.shot_odds(50.0, 60.0, mus)
	var far := HuntJob.shot_odds(50.0, 100.0, mus)
	print("musket, skill 50: 30 m %s, 60 m %s, 100 m %s" % [near, mid, far])
	_expect(near.hit > mid.hit and mid.hit > far.hit and near.vital > far.vital, "the odds fall with the distance")
	_expect(HuntJob.shot_odds(50.0, 130.0, mus).hit == 0.0, "past the weapon's reach: no shot")
	var lo := HuntJob.shot_odds(10.0, 50.0, mus)
	var hi := HuntJob.shot_odds(80.0, 50.0, mus)
	_expect(hi.hit > lo.hit + 0.15 and hi.clean > lo.clean * 1.5, "skill: %.2f clean at 80 against %.2f at 10" % [hi.clean, lo.clean])
	var run := HuntJob.shot_odds(50.0, 40.0, mus, "running")
	var still := HuntJob.shot_odds(50.0, 40.0, mus, "unaware")
	_expect(still.hit > run.hit + 0.3 and HuntJob.shot_odds(50.0, 40.0, mus, "alert").hit < still.hit, "an unaware animal is the easy shot, a running one hard")
	_expect(HuntJob.shot_odds(50.0, 40.0, bow).hit < HuntJob.shot_odds(50.0, 40.0, mus).hit and HuntJob.shot_odds(50.0, 20.0, bow).hit > 0.6,
			"the bow wants a close shot")
	var sa := HuntJob.animal_state(null)
	_expect(sa == "unaware", "an animal with no state is taken as unaware")


# ---------------------------------------------------------------- firing: ammunition and the roll
func _fire() -> void:
	var w := _worker(55)
	_game(w)
	_expect(w.begin("hunt"), "out hunting")
	var mus := HuntJob.weapon_cfg("musket")
	var balls := SurvivalInventory.count(w.core, "item.ammo.ball")
	var powder := SurvivalInventory.count(w.core, "item.ammo.powder")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var r := HuntJob.fire(w, 40.0, "unaware", rng)
	_expect(bool(r.ok) and bool(r.loud), "the shot is fired (%s)" % str(r))
	_expect(is_equal_approx(SurvivalInventory.count(w.core, "item.ammo.ball"), balls - 1.0)
			and is_equal_approx(SurvivalInventory.count(w.core, "item.ammo.powder"), powder - 0.025), "a ball and a charge of powder spent")
	_expect(int(w.hunt.shots) == 1, "the shot is counted")
	# the roll follows the odds: many shots at 40 m and at 100 m
	SurvivalInventory.add(w.core, "item.ammo.ball", 800.0)
	SurvivalInventory.add(w.core, "item.ammo.powder", 20.0)
	var hits := [0, 0]
	for i in 300:
		hits[0] += 1 if bool(HuntJob.fire(w, 40.0, "unaware", rng).hit) else 0
		hits[1] += 1 if bool(HuntJob.fire(w, 100.0, "unaware", rng).hit) else 0
	var o40 := HuntJob.shot_odds(HuntJob.shot_skill(w, mus), 40.0, mus)
	print("hits of 300: 40 m %d (odds %.2f), 100 m %d" % [hits[0], o40.hit, hits[1]])
	_expect(absf(hits[0] / 300.0 - o40.hit) < 0.08 and hits[0] > hits[1] + 30, "the hits follow the odds and fall with the distance")
	SurvivalInventory.remove(w.core, "item.ammo.ball", 9999.0)
	_expect(not bool(HuntJob.fire(w, 40.0, "unaware", rng).ok), "out of balls: no shot")
	w.cancel("test")


# ---------------------------------------------------------------- the sign
func _sign() -> void:
	var w := _worker(57)
	_stock_but_meat(w)
	var g := _game(w)
	_expect(w.begin("hunt") and HuntJob.phase(w) == "track" and SurvivalJobs.is_running(w.core), "she begins reading sign (the core's hunt.track)")
	for i in 20:
		main.advance(5.0)
		w.sync(main)
		if HuntJob.phase(w) != "track":
			break
	var ph := HuntJob.phase(w)
	_expect(ph == "stalk" and w.hunt.quarry == g.quarry or ph == "track", "the sign read: stalking the deer, or reading more sign (%s)" % ph)
	# the outcomes' reach
	var v := _worker(59)
	var gv := _game(v)
	_expect(v.begin("hunt"), "out again")
	gv.need_r = 100.0
	HuntJob.tracked(v, {"outcome": "success"})
	_expect(HuntJob.phase(v) == "stalk" and v.task_text.begins_with("Stalking"), "a good reading finds the deer further off (%s)" % v.task_text)
	v.hunt["phase"] = "track"
	_drop_job(v)
	HuntJob.tracked(v, {"outcome": "failure"})
	_expect(HuntJob.phase(v) == "track" and int(v.hunt.tracks) == 2, "no sign: she reads sign again")
	v.hunt["tracks"] = 9
	_drop_job(v)
	HuntJob.tracked(v, {"outcome": "failure"})
	_expect(HuntJob.phase(v) == "home" and String(v.hunt.end_text).contains("no sign"), "no sign after her tries: she comes home (%s)" % v.hunt.end_text)
	HuntJob.finish(v)
	_expect(not v.busy() and v.journal.back().contains("no sign"), "home: the hunt ends (%s)" % v.journal.back())


# ---------------------------------------------------------------- the kill: hauled or dressed, into the store
func _kill_home() -> void:
	_expect(HuntJob.after_kill(80.0, 55.0) == "haul", "a doe 80 m from home is hauled home whole")
	_expect(HuntJob.after_kill(400.0, 55.0) == "dress", "far out it is dressed where it fell")
	_expect(HuntJob.after_kill(80.0, 300.0) == "dress", "too heavy to drag: dressed where it fell")
	var w := _worker(61)
	_game(w)
	_expect(not HuntJob.home_butcher(w), "alone: nobody at home to butcher")
	var wife := SpouseCore.create_unit(main, 63, 0.0)
	wife.worker_id = 1
	wife.role = "home"
	wife.join(w.stock)
	_expect(HuntJob.home_butcher(w), "a worker at home with the butcher on takes the carcass")
	w.stock.crew.set_enabled(wife, "butcher", false)
	_expect(not HuntJob.home_butcher(w), "with the butcher off she does not")
	# dressed in the field: the skin and the meat carried home into the store
	_expect(w.begin("hunt"), "out hunting")
	var deer := FakeDeer.new()
	var got := HuntJob.dress(w, deer)
	_expect(got.size() == 2 and deer.dress_step == 2, "skinned and butchered: %s" % str(got))
	var mins := HuntJob.dress_minutes(w)
	_expect(mins > 30.0 and mins < 100.0, "the dressing takes %d game minutes" % roundi(mins))
	var v0 := w.stock.count("venison")
	var h0 := w.stock.count("deer_hide")
	HuntJob.finish(w, HuntJob.line("dressed") % [w.name, "deer", HuntJob.carry_text(w)])
	_expect(w.stock.count("venison") == v0 + 4 and w.stock.count("deer_hide") == h0 + 1 and not w.busy(),
			"home: 4 venison and the hide in the store (%s)" % w.journal.back())
	# called off with meat on her back: it is put by all the same
	_expect(w.begin("hunt"), "out again")
	HuntJob.dress(w, FakeDeer.new())
	w.cancel("told to stop")
	_expect(w.stock.count("venison") == v0 + 8, "a hunt called off: what she carried goes into the store")
	# the butcher at home takes a hauled carcass (the existing job: a carcass near home)
	var carcass := FakeDeer.new()
	wife.carcass_finder = func(skip := []) -> Object: return null if skip.has(carcass.get_instance_id()) else carcass
	w.stock.crew.set_enabled(wife, "butcher", true)
	_skip_to_hour(wife, 10.0)
	wife.stock.put("roast_venison", 20)
	var p := wife.plan()
	_expect(p.get("task", "") == "butcher", "the carcass hauled home: the butcher at home is planned (%s)" % str(p))


# ---------------------------------------------------------------- night and danger
func _refusals() -> void:
	var w := _worker(65)
	_stock_but_meat(w)
	var g := _game(w)
	_skip_to_hour(w, 18.0)
	_expect(HuntJob.refusal(w) == "too late in the day" and w.plan().get("task", "") != "hunt", "late in the day: no hunt")
	_skip_to_hour(w, 23.0)
	_expect(w.plan().is_empty(), "at night: nothing outside")
	_skip_to_hour(w, 9.0)
	g.wolves = true
	_expect(HuntJob.refusal(w) == "wolves about" and w.plan().get("task", "") != "hunt", "wolves about: no hunt")
	g.wolves = false
	w.stock.put("jerky", 8)                    # (fed: a starving hunter's reading of sign is stopped by her core)
	for i in 6:
		main.advance(10.0)
		w.sync(main)
	_expect(w.begin("hunt"), "out hunting")
	_expect(HuntJob.must_stop(w) == "", "by day, no wolves: the hunt goes on")
	g.wolves = true
	_expect(HuntJob.must_stop(w) == "wolves", "wolves come near: she must come home")
	g.wolves = false
	# (out stalking, no core job running: the weather's own interruptions of a reading of sign are the core's business)
	_drop_job(w)
	HuntJob.set_phase(w, "stalk")
	while w.hour() < 18.9:
		main.advance(20.0)
		w.sync(main)
	_expect(HuntJob.must_stop(w) == "dusk", "dusk: she must come home")
	HuntJob.go_home(w, HuntJob.line("dusk") % [w.name, ""])
	HuntJob.finish(w)
	_expect(not w.busy() and w.journal.back().contains("dusk"), "home at dusk (%s)" % w.journal.back())
	var n := _worker(67)
	SurvivalSkills.set_level(n.core, "hunting", 2.0)
	_game(n)
	_expect(HuntJob.refusal(n) == "no hunter", "no Hunting skill: no hunt")


# ---------------------------------------------------------------- the father
func _father() -> void:
	var d := Father.decide({"hour": 11.0, "children": [], "baby": {}})
	_expect(d.role == "provider" and d.sc_role == "outside", "the father's work block: a provider, outside")
	var w := SpouseCore.create_unit(main, 69, 1.0)
	w.role = String(d.sc_role)
	_stock_but_meat(w)
	_game(w)
	_expect(w.is_male() and w.plan().get("task", "") == "hunt", "the provider hunts when the household is short of meat (%s)" % str(w.plan()))
	w.abandon_plan()


# ---------------------------------------------------------------- the kit out of the household's tool pool
func _pool_home() -> Array:
	var s := HouseholdStock.new()
	var p := ToolPool.install(s)
	p.rng.seed = 3
	return [s, p]


func _pool_worker(s: HouseholdStock, seed_v: int, id: int) -> SpouseCore:
	var w := SpouseCore.create_unit(main, seed_v, 1.0)
	w.worker_id = id
	w.join(s)
	w.role = "outside"
	SurvivalSkills.set_level(w.core, "hunting", 50.0)
	var cur := fposmod(main.state.minutes, 1440.0) / 60.0
	main.advance(fposmod(9.0 - cur, 24.0) * 60.0)
	w.sync(main)                               # (ToolPool.tick: her background's kit is not hers)
	return w


func _pool_kit() -> void:
	var sp := _pool_home()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	var w := _pool_worker(s, 71, 20)
	_game(w)
	_expect(not SurvivalInventory.has(w.core, "item.weapon.musket", 1.0) and not SurvivalInventory.has(w.core, "item.ammo.ball", 1.0),
			"with a pool her background's musket and shot are not hers")
	_expect(HuntJob.offer(w).is_empty() and HuntJob.refusal(w) == HuntJob.line("no_kit")
			and String((p.blocked.get(w.worker_id, {}) as Dictionary).get("hunt", "")) == HuntJob.line("no_kit"),
			"nothing on the racks: no hunt, and the Tasks tab says why (%s)" % str(p.blocked))
	s.put("musket", 1)
	_expect(HuntJob.offer(w).is_empty(), "a musket and no shot for it: still no hunt")
	s.put("musket_balls", 10)
	s.put("powder", 2)
	s.put("bow", 1)
	s.put("trade_knife", 1)
	s.put("jerky", 3)
	SurvivalSkills.set_level(w.core, "marksmanship", 60.0)
	SurvivalSkills.set_level(w.core, "archery", 85.0)
	var o := HuntJob.offer(w)
	_expect(o.get("weapon", "") == "musket" and o.get("weapon_from", "") == "musket" and not p.blocked.has(w.worker_id),
			"a better archer, but no arrows: the musket, which has shot (%s)" % str(o))
	s.put("arrows", 12)
	_expect(HuntJob.offer(w).get("weapon", "") == "bow", "arrows in the chest: the bow, the weapon she is best at")
	SurvivalSkills.set_level(w.core, "archery", 20.0)
	# planned: her weapon claimed (her body would walk to the rack for it)
	w.focus = "hunt"
	var pl := w.plan()
	_expect(pl.get("task", "") == "hunt" and int((p.claims.get(w.worker_id, {}) as Dictionary).get("musket", 0)) == 1
			and not (p.claims.get(w.worker_id, {}) as Dictionary).has("bow"), "the plan claims her musket, not the rack's first weapon (%s)" % str(p.claims))
	w.abandon_plan()
	_expect(w.begin("hunt"), "out hunting")
	var h := p.held_by(w)
	_expect(int(h.get("musket", 0)) == 1 and int(h.get("trade_knife", 0)) == 1 and int(h.get("musket_balls", 0)) == 4 and int(h.get("powder", 0)) == 1
			and not h.has("bow"), "she holds the musket, a knife and the trip's shot: 4 balls and a pound of powder (%s)" % str(h))
	_expect(s.count("musket") == 0 and s.count("musket_balls") == 6 and s.count("powder") == 1 and s.count("jerky") == 2,
			"out of the rack and the chests, and a meal from the store (%s)" % str(s.all()))
	_expect(HuntJob.kit_shots(w, HuntJob.weapon_cfg("musket")) == 4, "four shots in her pouch")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	_expect(bool(HuntJob.fire(w, 40.0, "unaware", rng).ok) and int(p.held_by(w).get("musket_balls", 0)) == 3
			and int(p.held_by(w).get("powder", 0)) == 1, "a shot: the ball spent from the pool; a charge is not a pound (%s)" % str(p.held_by(w)))
	HuntJob.fire(w, 40.0, "unaware", rng)
	_expect(int(p.held_by(w).get("musket_balls", 0)) == 2, "two shots, two balls spent")
	w.cancel("test")
	_expect(p.held_by(w).is_empty() and s.count("musket") == 1 and s.count("trade_knife") == 1 and s.count("musket_balls") == 8,
			"the hunt over: the musket, the knife and the unfired balls back (%s)" % str(s.all()))
	_expect(s.count("powder") == 1 and float(p.partial.get("powder", 0.0)) > 0.9, "the pound she broke into is spent, its rest kept as a part (%.2f)" % float(p.partial.get("powder", 0.0)))
	_expect(s.count("jerky") == 3, "the uneaten meal back in the store")
	_expect(not SurvivalInventory.has(w.core, "item.ammo.ball", 0.5) and not SurvivalInventory.has(w.core, "item.weapon.musket", 1.0),
			"nothing of the pool's left in her core")


func _pool_two_hunters() -> void:
	var sp := _pool_home()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	var a := _pool_worker(s, 73, 21)
	var b := _pool_worker(s, 75, 22)
	_game(a)
	_game(b)
	s.put("musket", 1)
	s.put("musket_balls", 10)
	s.put("powder", 2)
	a.focus = "hunt"
	b.focus = "hunt"
	_expect(a.plan().get("task", "") == "hunt", "the first hunter plans the hunt")
	_expect(HuntJob.offer(b).is_empty() and b.plan().get("task", "") != "hunt", "the only musket is hers: the second has nothing to hunt with")
	b.abandon_plan()
	s.put("bow", 1)
	s.put("arrows", 6)
	_expect(HuntJob.offer(b).get("weapon", "") == "bow", "a bow on the rack: the second hunter takes that (%s)" % str(HuntJob.offer(b)))
	a.abandon_plan()
	_expect(p.available("musket", b.worker_id) == 1, "a plan given up lets the musket go")


func _pool_bow_and_spears() -> void:
	var sp := _pool_home()
	var s: HouseholdStock = sp[0]
	var p: ToolPool = sp[1]
	var w := _pool_worker(s, 77, 23)
	_game(w)
	s.put("bow", 1)
	s.put("arrows", 10)
	SurvivalSkills.set_level(w.core, "archery", 60.0)
	_expect(w.begin("hunt") and String(w.hunt.weapon) == "bow" and int(p.held_by(w).get("arrows", 0)) == 8, "the bow and the trip's 8 arrows")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	HuntJob.fire(w, 20.0, "unaware", rng)
	_expect(int(p.held_by(w).get("arrows", 0)) == 8, "an arrow loosed is not spent until it is looked for")
	var lost := 0
	for i in 6:
		HuntJob.fire(w, 20.0, "unaware", rng)
		if not HuntJob.settle(w, rng, "wounded"):
			lost += 1
	HuntJob.settle(w, rng, "miss")
	var left := int(p.held_by(w).get("arrows", 0))
	_expect(lost > 0 and left < 8 and left >= 1, "arrows gone with a wounded deer are spent (%d lost of 6, she holds %d)" % [lost, left])
	w.cancel("test")
	_expect(s.count("arrows") == 2 + left and p.held_by(w).is_empty(), "the arrows she still has back in the chest (%d)" % s.count("arrows"))
	# the spears: a close-combat hand with only the throwing spears
	var v := _pool_worker(s, 79, 24)
	_game(v)
	s.take_for(-1, "bow", 1)
	s.put("spear_pair", 1)
	SurvivalSkills.set_level(v.core, "close_combat", 70.0)
	SurvivalSkills.set_level(v.core, "archery", 0.0)
	_expect(v.begin("hunt") and String(v.hunt.weapon) == "spear" and int(v.hunt.throws) == 2, "the throwing spears: two throws")
	var d := HuntJob.shot_distance(v)
	_expect(d >= 10.0 and d <= 15.0, "she stalks to %.1f m to throw (10-15)" % d)
	var wts := HuntJob.quarry_weights(v)
	_expect(float(wts.get("fox", 0.0)) > float(wts.get("deer", 0.0)), "the spears look for small game first")
	var sp_odds := HuntJob.shot_odds(HuntJob.shot_skill(v, HuntJob.weapon_cfg("spear")), 12.0, HuntJob.weapon_cfg("spear"))
	var mu_odds := HuntJob.shot_odds(HuntJob.shot_skill(v, HuntJob.weapon_cfg("spear")), 12.0, HuntJob.weapon_cfg("musket"))
	_expect(sp_odds.clean < mu_odds.clean, "a spear is a weaker shot than a ball at the same skill (%.2f against %.2f)" % [sp_odds.clean, mu_odds.clean])
	for i in 2:
		HuntJob.fire(v, 12.0, "unaware", rng)
		v.hunt["loose"] = 1
		v.hunt["weapon_kind"] = "spear_pair"
		HuntJob.settle(v, RandomNumberGenerator.new() if false else _never(), "wounded")
	_expect(int(v.hunt.throws) == 0 and not p.held_by(v).has("spear_pair"), "both spears lost: the pair is spent (%s)" % str(p.held_by(v)))
	v.cancel("test")


## An rng that never finds anything (randf() near 1).
func _never() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	for sd in range(1, 400):
		r.seed = sd
		var st := r.state
		if r.randf() > 0.99:
			r.state = st
			return r
	return r


# ---------------------------------------------------------------- how the kill comes home
func _transport_choice() -> void:
	var sp := _pool_home()
	var s: HouseholdStock = sp[0]
	var nov := _pool_worker(s, 81, 30)
	SurvivalSkills.set_level(nov.core, "hunting", 15.0)
	SurvivalSkills.set_level(nov.core, "woodcraft", 5.0)
	var pro := _pool_worker(s, 83, 31)
	SurvivalSkills.set_level(pro.core, "hunting", 75.0)
	SurvivalSkills.set_level(pro.core, "woodcraft", 50.0)
	var sn := HuntHaul.smart(nov)
	var spro := HuntHaul.smart(pro)
	print("smart: novice %.2f, practised %.2f" % [sn, spro])
	_expect(sn < float(HuntHaul.tcfg().smart_min) and spro >= float(HuntHaul.tcfg().plan_barrow), "a novice is not smart about it; a practised hunter is")
	pro.core.state.flags["hunt_kills"] = 0
	pro.recruit = {"traits": ["woodswise"]}
	_expect(HuntHaul.smart(pro) > spro, "a woodswise recruit is smarter still")
	nov.core.state.flags["hunt_kills"] = 10
	_expect(HuntHaul.smart(nov) > sn, "kills made teach it")
	var all := {"horse": true, "cart": true, "barrow": true}
	var deer := HuntHaul.kg_of("deer")
	var bison := HuntHaul.kg_of("bison")
	_expect(HuntHaul.choose(spro, deer, 150.0, all) == "horse", "all free: the horse drags the deer home")
	_expect(HuntHaul.choose(spro, deer, 150.0, {"cart": true, "barrow": true}) == "cart", "the horse taken: the cart")
	_expect(HuntHaul.choose(spro, deer, 150.0, {"barrow": true}) == "barrow", "only the wheelbarrow: the deer in the barrow")
	_expect(HuntHaul.choose(spro, deer, 150.0, {"barrow_out": true}) == "barrow", "the barrow she took out: the deer in it")
	_expect(HuntHaul.choose(spro, bison, 150.0, {"barrow": true}) == "quarter", "a bison does not go in a barrow: quartered and carried")
	_expect(HuntHaul.choose(spro, bison, 150.0, {"cart": true, "barrow": true}) == "cart", "a bison with the cart free: the cart")
	_expect(HuntHaul.choose(spro, bison, 150.0, all) == "horse", "a bison behind the horse")
	_expect(HuntHaul.choose(spro, deer, 150.0, {}) == "drag", "nothing free: dragged by hand")
	_expect(HuntHaul.choose(sn, deer, 150.0, all) == "drag", "a novice drags it by hand with the horse standing at home")
	_expect(HuntHaul.choose(spro, deer, 400.0, all) == "dress", "far out, too far to fetch the horse: dressed and carried")
	_expect(HuntHaul.choose(spro, deer, 400.0, {"barrow_out": true}) == "barrow", "far out with the barrow she brought: the barrow")
	_expect(HuntHaul.dress_trips(bison) == 4 and HuntHaul.dress_trips(deer) == 1, "a bison is carried in quarters (%d trips), a deer in one" % HuntHaul.dress_trips(bison))
	_expect(HuntJob.after_kill(80.0, 55.0) == "haul" and HuntJob.after_kill(400.0, 55.0) == "dress", "(the old rule stands for a hunter with nothing)")


## The level's own horse, cart and wheelbarrow: what is free, reserved while hers, let go after.
func _transport_free() -> void:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	current_scene = world
	var sp := _pool_home()
	var s: HouseholdStock = sp[0]
	var w := _pool_worker(s, 85, 40)
	var v := _pool_worker(s, 87, 41)
	var at := Vector3(10.0, 0.0, 10.0)
	at.y = FrontierTerrain.height_at(at.x, at.z)
	var bw := Spouse.spawn(world, w, null, at)
	var bv := Spouse.spawn(world, v, null, at + Vector3(2, 0, 0))
	var hw := bw.get_node("HuntRun").get("haul") as HuntHaul
	var hv := bv.get_node("HuntRun").get("haul") as HuntHaul
	var horse := Horse.new()
	horse.name = "Horse"
	world.add_child(horse)
	horse.global_position = at + Vector3(6, 0, 0)
	HorseMount.attach_to(horse)
	var cart := HorseCart.new()
	world.add_child(cart)
	cart.park_at(at + Vector3(0, 0, 9), Vector3.RIGHT)
	var barrow := Wheelbarrow.new()
	world.add_child(barrow)
	barrow.park_at(at + Vector3(-5, 0, 3), Vector3.FORWARD)
	var far := Wheelbarrow.new()
	world.add_child(far)
	far.park_at(at + Vector3(-120, 0, 0), Vector3.FORWARD)
	var av := hw.available()
	_expect(av.get("horse") == horse and av.get("cart") == cart and av.get("barrow") == barrow, "at home: the horse, the cart (a free horse to draw it) and the near barrow (%s)" % str(av.keys()))
	var carcass := Node3D.new()
	world.add_child(carcass)
	_expect(hw.begin("horse", carcass, av) and int(horse.get_meta(HuntHaul.META, -1)) == w.worker_id, "she takes the horse: it is hers while she has it")
	var bav := hv.available()
	_expect(not bav.has("horse") and not bav.has("cart") and bav.get("barrow") == barrow, "the other hunter finds the horse taken, and so the cart (%s)" % str(bav.keys()))
	_expect(HuntHaul.choose(0.8, 55.0, 100.0, HuntHaul.flags(bav)) == "barrow", "so she takes the barrow")
	_expect(hv.begin("barrow", carcass, bav) and hw.why_not_barrow(barrow) == "another worker's", "the barrow is hers now")
	hw.abort("test")
	_expect(not horse.has_meta(HuntHaul.META) and hv.available().has("horse"), "let go: the horse is free again")
	hv.abort("test")
	_expect(not barrow.has_meta(HuntHaul.META), "and the barrow")
	horse.player_input = true
	_expect(hw.why_not_horse(horse) == "ridden" and not hw.available().has("horse"), "the player on the horse: not free")
	horse.player_input = false
	var lead := horse.get_node("Lead") as HorseLead
	lead.start(bv)
	_expect(hw.why_not_horse(horse) == "led", "led by someone else: not free")
	lead.stop()
	# the barrow taken out for the stalk, and brought back
	_expect(hw.take_barrow_out(barrow) and hw.barrow_out == barrow and hw.available().get("barrow_out") == barrow
			and not hv.available().has("barrow"), "the barrow out with her is hers, for her kill")
	_expect(hw.begin_return() and hw.steps.has("to_barrow_place") and hw.steps.back() == "set_down", "a return trip puts it back where it stood (%s)" % str(hw.steps))
	hw.abort("test")
	for n in [horse, cart, barrow, far, bw, bv, carcass]:
		n.queue_free()
	world.queue_free()



# ---------------------------------------------------------------- what she carries, worn (WorkerGear)
func _gear_loadout() -> void:
	var slots := {"shirt": "shirt_linen"}
	var lo := WorkerGear.loadout_for({"musket": 1, "powder": 1, "musket_balls": 4, "trade_knife": 1}, slots)
	var mus := lo.first_of_kind("musket")
	_expect(not mus.is_empty() and String((mus.points as Array)[0]).begins_with("long_") and lo.gear.has("horn_strap")
			and lo.gear.has("back_slings"), "the musket slung on the back, the horn on its strap (%s, %s)" % [str(mus.get("points")), str(lo.gear)])
	_expect(LoadoutRules.validate(lo).is_empty(), "a loadout the rules pass (%s)" % str(LoadoutRules.validate(lo)))
	var lb := WorkerGear.loadout_for({"bow": 1, "arrows": 7, "hatchet": 1, "pistol": 1}, slots)
	_expect(lb.has_kind("bow") and int(lb.first_of_kind("quiver").get("state", {}).get("arrows", 0)) == 7,
			"the bow slung with its quiver, her 7 arrows in it")
	_expect(lb.has_kind("tomahawk") and lb.has_kind("pistol"), "the hatchet on the belt as a tomahawk rides, the pistol on its hook (%s)" % str(lb.point_kinds()))
	var ls := WorkerGear.loadout_for({"spear_pair": 1}, slots)
	_expect(int(ls.first_of_kind("spear_pair").get("count", 0)) == 2, "the throwing spears: a pair on the back")
	_expect(WorkerGear.loadout_for({"axe": 1, "trade_knife": 1}, slots).items.is_empty(), "a felling axe and a knife: nothing on the slings (the knife has its sheath)")


## The core's running job dropped without telling her (the test stands in for its finish).
func _drop_job(w: SpouseCore) -> void:
	w.core._suppress_signals = true
	w.core.cancel_job("test")
	w.core._suppress_signals = false


# ---------------------------------------------------------------- fakes
## The "game" site: the quarry within need_r of the reading, wolves or not.
class FakeGround extends RefCounted:
	var quarry: Object
	var wolves := false
	var need_r := 0.0

	func pick_quarry(radius: float, _weights: Dictionary) -> Object:
		return quarry if radius >= need_r and radius > 0.0 else null

	func danger() -> bool:
		return wolves


## A deer carcass: skinned gives a hide, butchered 4 venison.
class FakeDeer extends RefCounted:
	var species := "deer"
	var dress_step := 0
	var meat_left := 1.0

	func finish_dress(step: String, hands: Object) -> void:
		if step == "skin":
			hands.inventory_pack = [{"kind": "deer_hide", "count": 1}]
			dress_step = 1
		else:
			hands.inventory_pack = [{"kind": "venison", "count": 4}]
			dress_step = 2
			meat_left = 0.3
