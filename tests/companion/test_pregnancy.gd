extends SceneTree
## Conception, gestation and birth (Pregnancy, SpouseCore's record, PregnancyLink's rules), headless, no level.
##   Godot --headless --path . -s tests/companion/test_pregnancy.gd
var fails := 0


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _main(seed_v := 7) -> SurvivalCore:
	return SurvivalCore.new_game("bg.backcountry_hunter", {"seed": seed_v, "start_day": "sep_early", "start_hour": 8.0,
			"backlog_milestones": ["M2a", "M2b", "M3"], "settings": {"rest_need": false}})


func _initialize() -> void:
	InputSetup.ensure()
	Pregnancy.set_cfg({})
	var c := Pregnancy.cfg()
	_expect(bool(c.enabled) and String(c.player_setting) != "" and float(c.gestation_days) > 0.0, "the json loads (%d days, setting %s)" % [int(c.gestation_days), c.player_setting])

	# the roll uses the check model and depends on health and food
	var core := _main()
	var rec := Pregnancy.new_record()
	var ck := Pregnancy.check(rec, core, core.state.minutes)
	_expect(is_equal_approx(float(ck.p), SurvivalSkills.chance(core, float(ck.S), float(ck.D), float(ck.cond))), "p is SurvivalSkills.chance(S, D, mods) (S %.0f, D %.0f, p %.2f)" % [ck.S, ck.D, ck.p])
	_expect(float(ck.final) > float(c.chance_floor) and float(ck.final) <= float(c.chance_cap), "a healthy fed woman has a real chance (%.2f)" % ck.final)
	var hurt := _main()
	hurt.state.needs["health"] = 25.0
	var ckh := Pregnancy.check(Pregnancy.new_record(), hurt, hurt.state.minutes)
	_expect(float(ckh.final) < float(ck.final) and float(ckh.S) < float(ck.S), "low health lowers the chance (%.2f < %.2f)" % [ckh.final, ck.final])
	var hungry := _main()
	hungry.state.needs["stomach"] = 0.0
	var ckf := Pregnancy.check(Pregnancy.new_record(), hungry, hungry.state.minutes)
	_expect(float(ckf.final) < float(ck.final), "hunger lowers the chance (%.2f < %.2f, stage %s)" % [ckf.final, ck.final, SurvivalNeeds.food_stage(hungry)])
	_expect(float(ckh.final) >= float(c.chance_floor) - 0.0001, "never below the floor, early attempts are not hopeless")

	# per-day limit, repeat sessions at reduced chance
	var lim := _main(3)
	var lr := Pregnancy.new_record()
	Pregnancy.set_cfg(_with({"base_chance": 0.0001, "chance_floor": 0.0001, "chance_cap": 0.0001}))
	var a1 := Pregnancy.attempt(lr, lim, lim.state.minutes)
	var a2 := Pregnancy.attempt(lr, lim, lim.state.minutes)
	var a3 := Pregnancy.attempt(lr, lim, lim.state.minutes)
	_expect(a1.status == "no" and a2.status == "no" and a3.status == "limit", "two rolls a day, the third is refused (%s %s %s)" % [a1.status, a2.status, a3.status])
	_expect(float(a2.mult) < 1.0 and is_equal_approx(float(a2.final), float(a2.chance) * float(c.repeat_mult)), "the repeat roll is at reduced chance (x%.2f)" % a2.mult)
	lim.advance(24.0 * 60.0)
	_expect(Pregnancy.attempt(lr, lim, lim.state.minutes).status == "no", "the next day rolls again")
	Pregnancy.set_cfg({})

	# determinism: the named stream (same seed = same result), and it is saved with the core
	var res1 := _run_sessions(_main(21), 6)
	var res2 := _run_sessions(_main(21), 6)
	_expect(res1 == res2, "same seed, same results (%s)" % str(res1))
	var res3 := _run_sessions(_main(22), 6)
	_expect(res1 != res3 or true, "a different seed may differ (%s)" % str(res3))
	# a stream saved and loaded continues exactly
	var m1 := _main(31)
	var w1 := SpouseCore.create(m1, AppearanceStore.default_look(), 5)
	var straight := []
	var r1 := Pregnancy.new_record()
	for i in 4:
		w1.core.advance(1440.0)
		straight.append(Pregnancy.attempt(r1, w1.core, w1.core.state.minutes, true).get("r", -1.0))
	var m2 := _main(31)
	var w2 := SpouseCore.create(m2, AppearanceStore.default_look(), 5)
	var r2 := Pregnancy.new_record()
	var split := []
	for i in 2:
		w2.core.advance(1440.0)
		split.append(Pregnancy.attempt(r2, w2.core, w2.core.state.minutes, true).get("r", -1.0))
	w2.pregnancy = r2
	var back := SpouseCore.from_dict(JSON.parse_string(JSON.stringify(w2.to_dict())), m2)
	for i in 2:
		back.core.advance(1440.0)
		split.append(Pregnancy.attempt(back.pregnancy, back.core, back.core.state.minutes, true).get("r", -1.0))
	_expect(straight == split, "a save between the rolls changes nothing (%s vs %s)" % [str(straight), str(split)])

	# who: the woman only
	_expect(Pregnancy.woman_kind(true) == Pregnancy.KIND_SPOUSE, "a male player: the wife conceives")
	_expect(Pregnancy.woman_kind(false) == Pregnancy.KIND_PLAYER, "a female player: the player conceives")
	var pm := _main(41)
	var wife := SpouseCore.create(pm, AppearanceStore.default_look(), 9)
	_expect(not wife.is_male(), "the wife of a male player is a woman")
	var prec := Pregnancy.player_record(pm)
	_expect(not Pregnancy.is_pregnant(prec) and pm.state.players[pm.state.player_id].has("pregnancy"), "the player's record lives in players[player_id]")

	# conception through to gestation, stages, the due date, the player's kcal invariants
	Pregnancy.set_cfg(_with({"base_chance": 1.0, "chance_floor": 1.0, "chance_cap": 1.0}))
	var g := _main(51)
	var gw := SpouseCore.create(g, AppearanceStore.default_look(), 3)
	var t0 := gw.core.state.minutes
	var got := Pregnancy.attempt(gw.pregnancy, gw.core, t0, true)
	_expect(got.status == "conceived" and Pregnancy.is_pregnant(gw.pregnancy), "a sure chance conceives")
	_expect(is_equal_approx(float(gw.pregnancy.due_at), t0 + float(c.gestation_days) * 1440.0), "the due date is %d days on" % int(c.gestation_days))
	_expect(Pregnancy.attempt(gw.pregnancy, gw.core, t0, true).status == "pregnant", "no new roll while pregnant")
	var seen := {}
	var family := []
	var burned := 0.0
	for day in 30:
		var before := SurvivalUtil.num(gw.core.state.needs.stomach, 0.0) + SurvivalUtil.num(gw.core.state.needs.reserve, 0.0)
		gw.core.advance(1440.0)
		gw.core.state.needs["stomach"] = 2500.0   # she eats
		var evs := Pregnancy.advance(gw.pregnancy, gw.core, gw.core.state.minutes, {"mother": gw.name, "father": "player", "kind": "spouse", "next_id": family.size() + 1})
		for e: Dictionary in evs:
			seen[String(e.do) + ":" + String(e.get("stage", ""))] = day
			if e.do == "birth":
				family.append(e.child)
		var st := SurvivalUtil.num(gw.core.state.needs.stomach, 0.0)
		var rs := SurvivalUtil.num(gw.core.state.needs.reserve, 0.0)
		if st < 0.0 or rs < 0.0 or gw.core.state.needs.fatigue > 100.0:
			fails += 1
			print("FAIL invariants broke on day %d" % day)
		burned += before
	_expect(seen.has("notice:early") and seen.has("stage:middle") and seen.has("stage:late") and seen.has("stage:near_term"), "notice and the three later stages come in order (%s)" % str(seen))
	_expect(int(seen.get("notice:early", 99)) < int(seen.get("stage:middle", 0)) and int(seen.get("stage:middle", 99)) < int(seen.get("stage:late", 0)) and int(seen.get("stage:late", 99)) < int(seen.get("stage:near_term", 0)), "stage days ascend")
	_expect(family.size() == 1 and int(gw.pregnancy.births) == 1 and not Pregnancy.is_pregnant(gw.pregnancy), "the birth makes exactly one child record")
	var ch: Dictionary = family[0]
	_expect(String(ch.name) != "" and ch.has("born_at") and ch.has("seed") and ch.mother == gw.name and ch.father == "player" and int(ch.worker_id) == -1, "the record has name, birth, seed, parents (%s)" % str(ch))
	_expect(float(ch.sex) < 0.5 and SpouseCore.NAMES_F.has(ch.name) or float(ch.sex) >= 0.5 and SpouseCore.NAMES_M.has(ch.name), "the name comes from the pool of its sex")
	_expect(Pregnancy.heavy_blocked(gw.pregnancy, gw.core.state.minutes) and Pregnancy.resting(gw.pregnancy, gw.core.state.minutes), "she rests after the birth (no heavy jobs)")
	_expect(Pregnancy.attempt(gw.pregnancy, gw.core, gw.core.state.minutes, true).status == "resting", "no conception while she rests")
	_expect(Pregnancy.age_text(ch, ch.born_at) == "newborn" and Pregnancy.age_text(ch, ch.born_at + 5.0 * 1440.0) == "5 days" and Pregnancy.age_text(ch, ch.born_at + 40.0 * 1440.0) == "1 year, 4 days", "age is computed from the clock")

	# heavy jobs and stages
	var hp := Pregnancy.new_record()
	hp["conceived_at"] = 0.0
	hp["due_at"] = 27.0 * 1440.0
	_expect(Pregnancy.stage_of(hp, 1.0 * 1440.0) == "early" and Pregnancy.stage_of(hp, 10.0 * 1440.0) == "middle" and Pregnancy.stage_of(hp, 20.0 * 1440.0) == "late" and Pregnancy.stage_of(hp, 26.0 * 1440.0) == "near_term", "stage boundaries")
	_expect(not Pregnancy.heavy_blocked(hp, 10.0 * 1440.0) and Pregnancy.heavy_blocked(hp, 20.0 * 1440.0), "heavy work is blocked in the late stage only")
	_expect(Pregnancy.speed_mult(hp, 26.0 * 1440.0) < Pregnancy.speed_mult(hp, 1.0 * 1440.0), "she is slower near term")
	var late := SpouseCore.create(_main(61), AppearanceStore.default_look(), 4)
	late.pregnancy = hp.duplicate()
	late.core.state.minutes = 20.0 * 1440.0
	var heavy := 0
	for id: String in JobBook.ids():
		if (JobBook.job(id).tags as Array).has("heavy"):
			heavy += 1
			if late.heavy_ok(JobBook.job(id)):
				fails += 1
				print("FAIL %s not blocked" % id)
	_expect(heavy >= 3 and late.heavy_ok(JobBook.job("cook")), "jobs tagged heavy (%d) are blocked, cooking is not" % heavy)

	# the player as the mother: same logic on the main core, saved with its state
	var pl := _main(71)
	var pr := Pregnancy.player_record(pl)
	_expect(Pregnancy.attempt(pr, pl, pl.state.minutes, true).status == "conceived", "the player can conceive (a sure chance)")
	var st2 := SurvivalState.from_dict(JSON.parse_string(JSON.stringify(pl.state.to_dict())))
	var rl := Pregnancy.normalize(SurvivalUtil.dict(st2.players.get(st2.player_id)).get("pregnancy"))
	_expect(Pregnancy.is_pregnant(rl) and is_equal_approx(float(rl.due_at), float(pr.due_at)), "the player's record survives the state's save")
	var burn0 := SurvivalUtil.num(pl.state.needs.stomach, 0.0)
	pl.advance(4320.0)
	var evp := Pregnancy.advance(pr, pl, pl.state.minutes)
	_expect(evp.size() == 1 and evp[0].do == "notice", "she notices after three days (%s)" % str(evp))

	# old saves, and the switch
	var old := SpouseCore.from_dict(_old_dict(SpouseCore.create(_main(81), AppearanceStore.default_look(), 6)), _main(81))
	_expect(not Pregnancy.is_pregnant(old.pregnancy) and int(old.pregnancy.births) == 0, "an old-format worker loads with no pregnancy")
	_expect(Pregnancy.family_from(null).is_empty() and Pregnancy.family_from([{"name": "Ruth", "born_at": 5}, 3]).size() == 1, "an old save has no family; odd entries are dropped")
	_expect(not Pregnancy.is_pregnant(Pregnancy.normalize("junk")), "a junk record normalises")
	Pregnancy.set_cfg(_with({"enabled": false, "base_chance": 1.0, "chance_floor": 1.0, "chance_cap": 1.0}))
	var off := _main(91)
	var orec := Pregnancy.new_record()
	var never := true
	for i in 10:
		off.advance(1440.0)
		never = never and Pregnancy.attempt(orec, off, off.state.minutes, true).status == "off"
	_expect(never and not Pregnancy.is_pregnant(orec) and not Pregnancy.enabled(off), "enabled=false never conceives")
	Pregnancy.set_cfg({})
	var setoff := _main(92)
	setoff.state.settings["pregnancy"] = false
	_expect(not Pregnancy.enabled(setoff) and Pregnancy.attempt(Pregnancy.new_record(), setoff, 0.0, Pregnancy.enabled(setoff)).status == "off", "the per-playthrough setting turns it off")
	Pregnancy.set_cfg({})

	print("%s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


func _with(over: Dictionary) -> Dictionary:
	var d := Pregnancy.cfg().duplicate(true)
	if d.is_empty():
		Pregnancy.set_cfg({})
		d = Pregnancy.cfg().duplicate(true)
	for k in over:
		d[k] = over[k]
	return d


## Six sessions, one a day: the statuses and rolls.
func _run_sessions(core: SurvivalCore, n: int) -> Array:
	var rec := Pregnancy.new_record()
	var out := []
	for i in n:
		core.advance(1440.0)
		var r := Pregnancy.attempt(rec, core, core.state.minutes, true)
		out.append([r.status, snappedf(float(r.get("r", -1.0)), 0.0001)])
		if r.status == "conceived":
			break
	return out


## A worker dict as an old save wrote it: no pregnancy key.
func _old_dict(w: SpouseCore) -> Dictionary:
	var d := w.to_dict()
	d.erase("pregnancy")
	return JSON.parse_string(JSON.stringify(d))
