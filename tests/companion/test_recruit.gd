extends SceneTree
## Recruiting, headless (Recruit, scripts/companion/recruit.gd; data/companion/recruit.json): candidates generated the same for
## the same seed, parties arriving and leaving on the clock, residents only with trust, the wants checked, the ask's odds and
## roll, housing capacity, food days, a candidate's own core (a hungry trapper fed), morale drifting down and a worker
## warning and leaving, and a save round trip (and an old save without recruiting).
##   Godot --headless --path . -s tests/companion/test_recruit.gd
var fails := 0


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	Sharpness.slips_on = false   # (exact planning and paths: no tired slips here; tests/companion/test_sharpness.gd has them)
	InputSetup.ensure()
	var main := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 7, "start_day": "sep_early", "start_hour": 8.0,
			"backlog_milestones": ["M2a", "M2b", "M3"], "settings": {"rest_need": false}})
	_generation(main)
	_arrivals(main)
	_housing_food(main)
	_ask(main)
	_own_core(main)
	_morale(main)
	_saving(main)
	print("RECRUIT TESTS %s (%d failed)" % ["PASSED" if fails == 0 else "FAILED", fails])
	quit(1 if fails else 0)


# ---------------------------------------------------------------- generation
func _generation(main: SurvivalCore) -> void:
	var a := Recruit.make_person("settler", 12345)
	var b := Recruit.make_person("settler", 12345)
	var c := Recruit.make_person("settler", 999)
	_expect(JSON.stringify(a) == JSON.stringify(b), "the same seed makes the same person (%s, %s)" % [a.name, a.people])
	_expect(JSON.stringify(a) != JSON.stringify(c), "another seed another person (%s, %s)" % [c.name, c.people])
	var region: Dictionary = Recruit.cfg().region_peoples
	_expect(region.has(String(a.people)) and not (a.look as Dictionary).is_empty() and String(a.look.people) == String(a.people),
			"a look from the region's peoples (%s)" % a.people)
	_expect(not region.has("lenape") and not region.has("haudenosaunee"), "no Native peoples in the slice's recruits (npcs.json representation)")
	_expect((a.traits as Array).size() == 2 and (a.wants as Array).size() >= 3, "two traits %s and the kind's wants" % str(a.traits))
	var fd := 0
	for w: Dictionary in a.wants:
		if String(w.kind) == "food_days":
			fd = int(w.days)
	_expect(fd >= 3 and fd <= 5, "the food wanted drawn in the kind's range (%d days)" % fd)
	var bg := Recruit.background_skills("bg.provincial_ranger")
	_expect(absf(float(a.skills.provisions) - (float(bg.provisions) + 12.0)) <= 4.01, "skills: the background's plus the kind's (provisions %.1f)" % float(a.skills.provisions))
	var teen := Recruit.make_person("widow_child", 77)
	var cap := float(Growth.junior_rules().get("skill_cap", 35.0))
	var hi := 0.0
	for k: String in teen.skills:
		hi = maxf(hi, float(teen.skills[k]))
	_expect(String(teen.age) == "teen" and hi <= cap, "a teen's skills under the junior cap (%.1f <= %.0f)" % [hi, cap])
	var tj := Recruit.job_prefs(teen)
	var junior: Array = Growth.junior_rules().get("jobs", [])
	_expect(not tj.is_empty() and tj.all(func(j: String) -> bool: return junior.has(j)), "a teen takes only junior jobs %s" % str(tj))
	var m := Recruit.make_person("trapper", 5)
	_expect(float(m.sex) >= 0.5 and bool(m.hungry) and Recruit.needs_help(m), "the lost trapper: a man in need, hungry")
	var hunter := Recruit.make_person("old_hunter", 5)
	_expect(String(hunter.name) == "Old hunter" and String(hunter.people) == "dutch", "a resident keeps his role title (%s)" % hunter.name)
	# two states on the same seed bring the same parties
	var s1 := Recruit.new_state(42, 0.0)
	var s2 := Recruit.new_state(42, 0.0)
	var p1 := Recruit.make_party(s1, 600.0, "", main)
	var p2 := Recruit.make_party(s2, 600.0, "", main)
	_expect(p1.size() == p2.size() and not p1.is_empty() and String(p1[0].name) == String(p2[0].name) and String(p1[0].party_kind) == String(p2[0].party_kind)
			and JSON.stringify(p1[0].look) == JSON.stringify(p2[0].look), "parties are deterministic by the state's seed (%s: %s)" % [p1[0].party_kind, p1[0].name])
	var widow := Recruit.make_party(Recruit.new_state(1, 0.0), 0.0, "widow", main)
	_expect(widow.size() == 2 and bool(widow[0].together) and String(widow[1].age) == "teen", "the widow comes with her teen child, together")


# ---------------------------------------------------------------- arrivals
func _arrivals(main: SurvivalCore) -> void:
	var st := Recruit.new_state(9, 0.0)
	# residents come only with trust
	var ids := Recruit.eligible(st, main).map(func(p: Dictionary) -> String: return String(p.id))
	_expect(not ids.has("old_hunter") and not ids.has("farm_son") and ids.has("hand"), "no residents without trust (the hunter's %.1f) %s" % [SurvivalTrade.trust(main, "npc.woods.old_hunter"), str(ids)])
	SurvivalTrade.add_trust(main, "npc.woods.old_hunter", 4.0)
	ids = Recruit.eligible(st, main).map(func(p: Dictionary) -> String: return String(p.id))
	_expect(ids.has("old_hunter"), "the old hunter may come by once trust is high (trust %.1f)" % SurvivalTrade.trust(main, "npc.woods.old_hunter"))
	var oh := Recruit.make_party(st, 0.0, "old_hunter", main)
	ids = Recruit.eligible(st, main).map(func(p: Dictionary) -> String: return String(p.id))
	_expect(not ids.has("old_hunter"), "and not twice while he is about")
	_expect(Recruit.trust_of(main, oh[0]) >= 4.0, "a resident's trust counts the player's trust with him (%.1f)" % Recruit.trust_of(main, oh[0]))
	# the clock: a party comes when due by daylight, stays its days, then leaves
	st = Recruit.new_state(9, 0.0)
	var night := 2.0 * 60.0   # 02:00 of day 0 is past next_at (0.4 day = 09:36)? no: before it
	var evs := Recruit.tick(st, main, night)
	_expect(evs.is_empty(), "nobody comes before the first is due")
	var day1_night := 1440.0 + 23.0 * 60.0
	evs = Recruit.tick(st, main, day1_night)
	_expect(evs.is_empty(), "nobody comes by night even when due")
	var morning := 2.0 * 1440.0 + 9.0 * 60.0
	evs = Recruit.tick(st, main, morning)
	_expect(evs.size() == 1 and String(evs[0].ev) == "arrive" and Recruit.present(st).size() >= 1, "a party comes in the morning (%s)" % str(evs))
	_expect(float(st.next_at) >= morning + 2.0 * 1440.0 - 1.0, "the next is days away")
	var c: Dictionary = Recruit.present(st)[0]
	var leave_at := float(c.leave_at)
	_expect(leave_at >= morning + 2.0 * 1440.0 - 1.0 and leave_at <= morning + 4.0 * 1440.0 + 1.0, "they stay two to four days")
	evs = Recruit.tick(st, main, leave_at + 1.0)
	var left := evs.filter(func(e: Dictionary) -> bool: return String(e.ev) == "leave")
	_expect(not left.is_empty() and String(c.state) == "leaving", "and then take the road (%d leaving)" % left.size())
	c["state"] = "gone"
	Recruit.prune(st)
	_expect(Recruit.by_id(st, String(c.id)).is_empty() and (st.departures as Array).size() >= 1, "gone from the list, kept among departures")


# ---------------------------------------------------------------- housing and food
func _housing_food(main: SurvivalCore) -> void:
	var pieces := [{"type": "pole_bed"}, {"type": "bough_bed"}, {"type": "floor", "roofed": true}, {"type": "floor", "roofed": false},
			{"type": "lean_to"}, {"type": "workbench"}, {"type": "roof"}]
	_expect(Recruit.places_in(pieces) == 4, "places: two beds, a lean-to, a roofed floor bay (%d)" % Recruit.places_in(pieces))
	var store := HouseholdStock.new()
	var wife := SpouseCore.create(main, AppearanceStore.default_look(), 11)
	wife.join(store)
	var hand := SpouseCore.create_unit(main, 3)
	hand.join(store)
	var r1 := SpouseCore.create_unit(main, 4)
	r1.recruit = {"place": 1}
	r1.join(store)
	var r2 := SpouseCore.create_unit(main, 5)
	r2.recruit = {"place": 0}   # the second of a couple
	r2.join(store)
	var family := [{"id": "a", "stage": "teen", "worker_id": -1}, {"id": "b", "stage": "toddler", "worker_id": -1}, {"id": "c", "stage": "adult", "worker_id": 1}]
	var occ := Recruit.occupants(store.crew.workers, family)
	_expect(occ == 4, "occupants: you and the wife, a hand, a couple sharing, a teen child (%d)" % occ)
	_expect(Recruit.places_needed([{"party": "p1", "couple": true}, {"party": "p1", "couple": true}]) == 1
			and Recruit.places_needed([{"party": "p2"}, {"party": "p2"}]) == 2, "a couple needs one place, two hands two")
	var fd := Recruit.food_days({"jerky": 10, "firewood": 30}, wife.unit_kcal, 2)
	var want := 10.0 * wife.unit_kcal("jerky") / (2.0 * 2400.0)
	_expect(absf(fd - want) < 0.001 and fd > 0.0, "food days: the store's kcal for everyone (%.2f days)" % fd)


# ---------------------------------------------------------------- the ask
func _ask(main: SurvivalCore) -> void:
	var st := Recruit.new_state(3, 0.0)
	var party := Recruit.make_party(st, 0.0, "hand", main)
	var c: Dictionary = party[0]
	var ctx := {"free": 0, "food_days": 30.0, "trust": 2.0, "share": 1}
	var o := Recruit.odds(main, c, ctx, party, 0.0)
	_expect(String(o.blocked).begins_with("A place to sleep"), "no free place: they cannot be asked (%s)" % o.blocked)
	var r := Recruit.ask(main, st, c, ctx, 0.0, 0.0)
	_expect(String(r.outcome) == "blocked" and not bool(r.joined), "the ask is refused with the reason")
	ctx.free = 3
	o = Recruit.odds(main, c, ctx, party, 0.0)
	var sum := 0.0
	for m: Array in o.mods:
		sum += float(m[1])
	var p_model := SurvivalSkills.chance(main, SurvivalSkills.level(main, "trade"), float(c.difficulty), sum)
	_expect(String(o.blocked) == "" and absf(float(o.p) - p_model) < 0.0001, "odds by the skill model: %d%% (Trade %d vs %d; %s)" % [int(o.pct), int(o.S), int(o.D), Recruit.factors_text(o)])
	var ctx_short := ctx.duplicate()
	ctx_short.food_days = 1.0
	ctx_short.share = 0
	var o2 := Recruit.odds(main, c, ctx_short, party, 0.0)
	_expect(float(o2.p) < float(o.p) - 0.05, "wants not met lower the odds (%d%% -> %d%%: %s)" % [int(o.pct), int(o2.pct), Recruit.factors_text(o2)])
	var ctx_trust := ctx.duplicate()
	ctx_trust.trust = 7.0
	ctx_trust.share = 2
	var o3 := Recruit.odds(main, c, ctx_trust, party, 0.0)
	_expect(float(o3.p) > float(o.p), "trust and a generous share raise them (%d%%)" % int(o3.pct))
	var wv := Recruit.wants_view(c, ctx_short, party)
	var unmet := wv.filter(func(e: Dictionary) -> bool: return not bool(e.met)).map(func(e: Dictionary) -> String: return String(e.kind))
	_expect(unmet.has("food_days") and unmet.has("share") and not unmet.has("bed"), "the wants shown met or not %s" % str(unmet))
	# the roll: a low roll joins, a high one is refused (trust lost, a cooldown)
	var t0 := float(c.trust)
	var trade0 := SurvivalSkills.level(main, "trade")
	r = Recruit.ask(main, st, c, ctx, 0.0, 0.99)
	_expect(String(r.outcome) == "failure" and float(c.trust) < t0 and float(c.cd_until) > 0.0, "a failed ask: trust %.1f -> %.1f, no asking for a day" % [t0, float(c.trust)])
	_expect(SurvivalSkills.level(main, "trade") >= trade0, "asking practises Trade (%.2f -> %.2f)" % [trade0, SurvivalSkills.level(main, "trade")])
	o = Recruit.odds(main, c, ctx, party, 60.0)
	_expect(String(o.blocked).begins_with("They want time"), "during the cooldown: %s" % o.blocked)
	r = Recruit.ask(main, st, c, ctx, 2.0 * 1440.0, float(o.p) * 0.05)
	_expect(String(r.outcome) == "excellent" and bool(r.joined) and (r.ids as Array) == [String(c.id)], "a good roll: they join (%s)" % str(r.ids))
	# a together party is asked as one, through its first member; the promise want
	var wst := Recruit.new_state(4, 0.0)
	var wp := Recruit.make_party(wst, 0.0, "widow", main)
	var ctx_w := {"free": 2, "food_days": 30.0, "trust": 5.0, "share": 2}
	r = Recruit.ask(main, wst, wp[1], ctx_w, 0.0, 0.0)
	_expect(bool(r.joined) and (r.ids as Array).size() == 2, "asking the child asks the mother: both join %s" % str(r.ids))
	var ctx_one := ctx_w.duplicate()
	ctx_one.free = 1
	_expect(String(Recruit.odds(main, wp[0], ctx_one, Recruit.joining(wst, wp[0]), 0.0).blocked).contains("2 of us"), "one free place is not enough for two")
	var sv: Dictionary = Recruit.make_party(Recruit.new_state(5, 0.0), 0.0, "servant", main)[0]
	var wo := Recruit.odds(main, sv, ctx_w, [sv], 0.0)
	Recruit.promise(sv)
	var wo2 := Recruit.odds(main, sv, ctx_w, [sv], 0.0)
	_expect(float(wo2.p) > float(wo.p) + 0.2, "your word given to the servant (%d%% -> %d%%)" % [int(wo.pct), int(wo2.pct)])
	# talk and gifts
	var h := Recruit.make_person("hand", 8)
	var t1 := float(h.trust)
	_expect(Recruit.talk(h, 100.0) and not Recruit.talk(h, 200.0) and float(h.trust) > t1, "talking counts once a day (trust %.1f)" % float(h.trust))
	var got := []
	for i in 5:
		got.append(Recruit.gift(h, 300.0))
	_expect(got.count("ok") == 3 and got.count("cap") == 2, "gifts count up to the day's cap %s" % str(got))


# ---------------------------------------------------------------- their own core
func _own_core(main: SurvivalCore) -> void:
	var tr := Recruit.make_person("trapper", 21)
	tr["id"] = "rc9_0"
	var w := Recruit.build_worker(main, tr)
	_expect(w.core != main and w.core.state.background_id == "bg.backcountry_hunter", "their own core on their background (%s)" % w.core.state.background_id)
	_expect(absf(float(w.core.state.skills.trapping) - float(tr.skills.trapping)) < 0.01, "their skills (trapping %.1f)" % float(w.core.state.skills.trapping))
	_expect(is_equal_approx(w.core.state.minutes, main.state.minutes), "on the player's clock")
	var stage := SurvivalNeeds.food_stage(w.core)
	_expect(stage in ["very_hungry", "hungry"], "the lost trapper is hungry (%s)" % stage)
	_expect(w.enabled.get("butcher", false) and not w.enabled.get("cook", true), "jobs by his likes (butcher on, cook off)")
	_expect(Recruit.gift(tr, 0.0) == "help" and bool(tr.fed), "the first food to him is help")
	w.stock.put("jerky", 3)
	w._eat_when_hungry()
	_expect(w.stock.count("jerky") < 3, "he eats what he was given (jerky left %d)" % w.stock.count("jerky"))
	var teen := Recruit.make_person("widow_child", 22)
	var tw := Recruit.build_worker(main, teen)
	_expect(String(tw.body_look.get("stage", "")) == "teen", "a teen is drawn at the teen's body")


# ---------------------------------------------------------------- morale
func _morale(main: SurvivalCore) -> void:
	var rec := Recruit.make_person("hand", 31)
	rec["traits"] = []
	rec["id"] = "rc1_0"
	rec["party"] = "p1"
	var w := Recruit.build_worker(main, rec)
	var now := main.state.minutes
	w.recruit = Recruit.recruit_record(rec, now)
	w.recruit["trust"] = 1.0
	var m0 := float(w.recruit.morale)
	# starving and with no place to sleep, day after day
	w.core.state.needs["stomach"] = 0.0
	var evs := []
	var t := now
	for i in 12 * 24:
		t += 60.0
		w.core.state.needs["stomach"] = 0.0
		evs.append_array(Recruit.morale_tick(w, 60.0, false, t))
		if evs.any(func(e: Dictionary) -> bool: return String(e.ev) == "leave"):
			break
	var kinds := evs.map(func(e: Dictionary) -> String: return "%s%d" % [e.ev, int(e.days)])
	_expect(float(w.recruit.morale) < m0 - 0.2, "hungry and unhoused, morale falls (%.2f -> %.2f, %s)" % [m0, float(w.recruit.morale), Recruit.morale_word(float(w.recruit.morale))])
	_expect(kinds.has("warn1") and kinds.has("warn2") and kinds.has("leave3"), "they warn and then leave %s" % str(kinds))
	_expect(w.work_mult < 0.8, "and work slower (pace %.2f)" % w.work_mult)
	var job := JobBook.job("tend")
	var slow := w._minutes(job, {"how": job.how})
	w.work_mult = 1.0
	var norm := w._minutes(job, {"how": job.how})
	_expect(slow > norm + 0.01 or norm <= 0.0, "a timed job takes longer at a low pace (%.1f vs %.1f min)" % [slow, norm])
	# fed and housed, it climbs back; the low days reset
	var m1 := float(w.recruit.morale)
	var cap := float(SurvivalNeeds.need_row(w.core, "need.food").get("stomach_capacity_kcal", 3000.0))
	for i in 4 * 24:
		t += 60.0
		w.core.state.needs["stomach"] = cap * 0.9
		Recruit.morale_tick(w, 60.0, true, t)
	_expect(float(w.recruit.morale) > m1 + 0.2 and int(w.recruit.low_days) == 0, "fed and housed, it recovers (%.2f, %s)" % [float(w.recruit.morale), Recruit.morale_word(float(w.recruit.morale))])
	_expect(float(w.recruit.trust) > 1.0, "and trust grows a little each day (%.2f)" % float(w.recruit.trust))
	# overwork: many hours at work lower the rested part
	w.recruit["busy_h_prev"] = 15.0
	_expect(float(Recruit.morale_target(w, true).parts.rested) < 0.01, "fifteen hours at work: not rested")


# ---------------------------------------------------------------- saving
func _saving(main: SurvivalCore) -> void:
	var st := Recruit.new_state(77, 0.0)
	var party := Recruit.make_party(st, 0.0, "settler_couple", main)
	Recruit.talk(party[0], 10.0)
	party[0]["share"] = 2
	party[1]["pos"] = [1.0, 2.0, 3.0]
	var w := Recruit.build_worker(main, party[0])
	party[0]["unit"] = w.to_dict()
	var text := JSON.stringify(st)
	var back := Recruit.normalize_state(JSON.parse_string(text), 1, 0.0)
	_expect((back.candidates as Array).size() == 2 and int(back.seq) == 1 and int(back.seed) == 77, "the state comes back (%d candidates)" % (back.candidates as Array).size())
	var c0: Dictionary = back.candidates[0]
	_expect(int(c0.share) == 2 and absf(float(c0.trust) - float(party[0].trust)) < 0.001 and String(c0.name) == String(party[0].name)
			and String(c0.look.people) == String(party[0].look.people) and (c0.look.face as Dictionary).size() == (party[0].look.face as Dictionary).size(), "trust, share, name and look kept (%s, trust %.1f)" % [c0.name, float(c0.trust)])
	var w2 := SpouseCore.from_dict(c0.unit, main)
	_expect(w2.name == w.name and absf(float(w2.core.state.skills.provisions) - float(w.core.state.skills.provisions)) < 0.01, "their own core comes back")
	# a joined worker's recruit record and morale
	w.recruit = Recruit.recruit_record(party[0], 0.0)
	w.recruit["morale"] = 0.42
	w.recruit["low_days"] = 1
	var w3 := SpouseCore.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())), main)
	_expect(absf(float(w3.recruit.morale) - 0.42) < 0.001 and int(w3.recruit.low_days) == 1 and (w3.recruit.traits as Array) == (w.recruit.traits as Array),
			"a worker's morale, low days and traits are saved")
	# old saves
	var old_unit := w.to_dict()
	old_unit.erase("recruit")
	_expect(SpouseCore.from_dict(old_unit, main).recruit.is_empty(), "an old worker has no recruit record")
	var fresh := Recruit.normalize_state(null, 5, 100.0)
	_expect((fresh.candidates as Array).is_empty() and float(fresh.next_at) > 100.0, "an old save without recruiting: a new state")
	var partial := Recruit.normalize_state({"candidates": [{"id": "rc1_0", "name": "Ann"}], "seq": 3}, 5, 0.0)
	_expect((partial.candidates as Array).size() == 1 and String(partial.candidates[0].state) == "camped" and partial.has("departures"),
			"a partial record is made whole")
