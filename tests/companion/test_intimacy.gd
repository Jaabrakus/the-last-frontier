extends SceneTree
## The intimacy gauge (Intimacy), the yoga flow (YogaFlow) and the sex rule, headless: rates and caps, the gate and its
## reasons, who leads (the woman) for both player sexes, the offer -> accept / decline -> follow -> pose chosen -> session
## -> end state machine, the save round trip and an old spouse dict without `intimacy`.
##   Godot --headless --path . -s tests/companion/test_intimacy.gd
var fails := 0


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _m(a: Dictionary, b: Dictionary) -> Dictionary:
	return a.merged(b, true)


func _events(f: YogaFlow, kind: String) -> Array:
	var out := []
	for e: Dictionary in f.events:
		if String(e.do) == kind:
			out.append(e)
	return out


func _initialize() -> void:
	InputSetup.ensure()
	var main := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 7, "start_day": "sep_early", "start_hour": 8.0,
			"backlog_milestones": ["M2a", "M2b", "M3"], "settings": {"rest_need": false}})
	var male_look := AppearanceStore.default_look()
	var wife := SpouseCore.create(main, male_look, 11)
	var female_look: Dictionary = CharacterPeoples.preset_look("english_f_a") if not CharacterPeoples.preset("english_f_a").is_empty() else {"sex": 0.0}
	var husband := SpouseCore.create(main, female_look, 12)
	Intimacy.cfg_override = {"anytime": false}      # (these are the gauge's rules)
	var cfg := Intimacy.load_cfg()

	# ---- the sex rule: the woman leads
	_expect(not wife.is_male() and Intimacy.leader_for(wife.is_male()) == "spouse", "male player: his wife leads")
	_expect(husband.is_male() and Intimacy.leader_for(husband.is_male()) == "player", "female player: she leads, the husband joins")
	_expect(Intimacy.new(wife).leader() == "spouse" and Intimacy.new(husband).leader() == "player", "Intimacy.leader() follows the spouse's sex")

	# ---- defaults and saving
	_expect(is_equal_approx(wife.intimacy, float(cfg.start)), "a new spouse starts at the configured value (%.2f)" % wife.intimacy)
	var it := Intimacy.new(wife)
	wife.intimacy = 0.42
	wife.intimacy_cd = 300.0
	wife.intimacy_offer_cd = 100.0
	var back := SpouseCore.from_dict(wife.to_dict(), main)
	_expect(is_equal_approx(back.intimacy, 0.42) and is_equal_approx(back.intimacy_cd, 300.0) and is_equal_approx(back.intimacy_offer_cd, 100.0),
			"the gauge and its cooldowns survive a save round trip")
	var old := wife.to_dict()
	old.erase("intimacy")
	old.erase("intimacy_cd")
	old.erase("intimacy_offer_cd")
	var oldback := SpouseCore.from_dict(old, main)
	_expect(is_equal_approx(oldback.intimacy, 0.1) and oldback.intimacy_cd == 0.0, "an old save without intimacy loads at the default")
	wife.role = "follow"
	wife.role_saved = "home"
	_expect(String(wife.to_dict().role) == "home", "a borrowed yoga follow saves the real role")
	wife.role_saved = ""
	wife.role = "home"

	# ---- fill rates and caps
	wife.intimacy = 0.1
	wife.intimacy_cd = 0.0
	wife.intimacy_offer_cd = 0.0
	it = Intimacy.new(wife)
	it.tick(60.0, true, true, 480.0)
	_expect(is_equal_approx(wife.intimacy, 0.1 + 60.0 * float(cfg.together_per_min)), "an hour together fills %.3f (%.3f)" % [60.0 * float(cfg.together_per_min), wife.intimacy - 0.1])
	var before := wife.intimacy
	it.tick(60.0, true, false, 540.0)
	_expect(is_equal_approx(wife.intimacy, before), "no fill when one of you is asleep")
	it.tick(60.0, false, true, 600.0)
	_expect(is_equal_approx(wife.intimacy, before), "no fill when apart")
	wife.intimacy = 0.1
	it = Intimacy.new(wife)
	for i in 30:
		it.tick(60.0, true, true, 400.0 + float(i) * 10.0)   # thirty hours in one game day's window (the cap is per day)
	_expect(wife.intimacy <= 0.1 + float(cfg.together_day_cap) + 0.0001, "time together is capped per day (%.3f)" % wife.intimacy)
	# talk: once an hour
	wife.intimacy = 0.1
	it = Intimacy.new(wife)
	var g1 := it.on_talk(1000.0)
	var g2 := it.on_talk(1010.0)
	var g3 := it.on_talk(1000.0 + float(cfg.talk_cooldown_min) + 1.0)
	_expect(g1 > 0.0 and g2 == 0.0 and g3 > 0.0, "talk counts once per game hour (%.3f, %.3f, %.3f)" % [g1, g2, g3])
	# meals, gifts, jobs
	var m1 := it.on_meal(2000.0, false)
	var m2 := it.on_meal(3000.0, true)
	_expect(is_equal_approx(m1, float(cfg.meal_shared)) and is_equal_approx(m2, float(cfg.meal_shared) + float(cfg.meal_cooked_bonus)),
			"a shared meal fills; one she cooked fills more (%.3f, %.3f)" % [m1, m2])
	_expect(it.on_meal(3010.0, true) == 0.0, "meals have a cooldown")
	_expect(is_equal_approx(it.on_gift(5000.0), float(cfg.gift)) and it.on_gift(5001.0) == 0.0, "a gift to the store counts lightly, with a cooldown")
	wife.intimacy = 0.1
	it = Intimacy.new(wife)
	var jobs := 0.0
	for i in 20:
		jobs += it.on_job(7000.0 + float(i))
	_expect(is_equal_approx(jobs, float(cfg.job_day_cap)), "finished jobs are capped per day (%.3f)" % jobs)
	wife.intimacy = 0.1
	it = Intimacy.new(wife)
	var total := 0.0
	for i in 40:
		total += it.on_meal(144000.0 + float(i) * 30.0, true) + it.on_talk(144000.0 + float(i) * 30.0) + it.on_gift(144000.0 + float(i) * 30.0)
	_expect(total <= float(cfg.day_cap) + 0.0001, "the day's total gain is capped (%.3f <= %.2f)" % [total, float(cfg.day_cap)])
	wife.intimacy = 0.999
	it = Intimacy.new(wife)
	it.on_job(50000.0)
	_expect(wife.intimacy <= 1.0, "never above 1")

	# ---- drain: very slowly, only after days apart, never below the floor
	wife.intimacy = 0.6
	it = Intimacy.new(wife)
	it.tick(1440.0, false, true, 100.0)
	_expect(is_equal_approx(wife.intimacy, 0.6), "one day apart: no drain")
	it.tick(1440.0 * 3.0, false, true, 5000.0)
	_expect(wife.intimacy < 0.6 and wife.intimacy > 0.5, "days apart drain it slowly (%.3f)" % wife.intimacy)
	it.tick(1440.0 * 400.0, false, true, 900000.0)
	_expect(is_equal_approx(wife.intimacy, float(cfg.floor)), "the drain stops at the floor (%.3f)" % wife.intimacy)
	wife.intimacy = 0.6
	it = Intimacy.new(wife)
	it.tick(1440.0 * 3.0, false, true, 5000.0)
	var drained := wife.intimacy
	it.tick(10.0, true, true, 5010.0)
	it.tick(1440.0 * 1.0, false, true, 6450.0)
	_expect(wife.intimacy >= drained, "coming back resets the time apart")

	# ---- levels
	wife.intimacy = 0.05
	_expect(Intimacy.new(wife).level_index() == 0 and Intimacy.new(wife).level_word() == "Reserved", "level 0 word")
	wife.intimacy = 1.0
	_expect(Intimacy.new(wife).level_index() == cfg.levels.size() - 1 and Intimacy.new(wife).level_word() == "Inseparable", "top level word")
	var words := {}
	for i in 11:
		wife.intimacy = float(i) / 10.0
		words[Intimacy.new(wife).level_word()] = true
	_expect(words.size() == cfg.levels.size(), "every level has its word (%s)" % str(words.keys()))
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/companion/lines.json"))
	var il: Dictionary = lines.get("intimacy", {})
	_expect(il.has("level") and (il.level as Dictionary).size() >= cfg.levels.size(), "lines.json has a line per gauge level")
	var missing := []
	for r in Intimacy.REASONS:
		if not (il.get("ask", {}) as Dictionary).has(r) and r != "cooldown_x":
			missing.append(r)
		if not (cfg.reasons as Dictionary).has(r):
			missing.append("ui:" + r)
	_expect(missing.is_empty(), "every gate reason has a spoken line and a button reason (missing %s)" % str(missing))
	for k in ["offer", "offer_declined", "choose", "ask", "ended", "after"]:
		_expect(il.has(k), "lines.json intimacy.%s" % k)

	# ---- the gate
	wife.intimacy = 1.0
	wife.intimacy_cd = 0.0
	it = Intimacy.new(wife)
	var calm := {"hour": 12.0, "busy": false, "danger": false, "combat": false, "dist": 5.0, "alive": true}
	_expect(it.gate(calm) == "", "full and calm: yoga may be asked")
	wife.intimacy = 0.5
	_expect(it.gate(calm) == "not_full", "not full: refused")
	wife.intimacy = 1.0
	wife.intimacy_cd = 60.0
	_expect(it.gate(calm) == "cooldown", "in the cooldown after a session: refused")
	wife.intimacy_cd = 0.0
	_expect(it.gate(_m(calm, {"hour": 22.0})) == "" and it.gate(_m(calm, {"hour": 3.0})) == "", "night: allowed (only danger stops it)")
	_expect(it.gate(_m(calm, {"danger": true})) == "danger", "danger near: refused")
	_expect(it.gate(_m(calm, {"combat": true})) == "combat", "in combat: refused")
	_expect(it.gate(_m(calm, {"dist": 200.0})) == "far", "too far to call: refused")
	_expect(it.gate(_m(calm, {"busy": true})) == "busy", "a busy spouse: refused ...")
	_expect(it.gate(_m(calm, {"busy": true}), true) == "", "... unless the player asks and she puts the job down")
	_expect(it.gate(_m(calm, {"alive": false})) == "dead", "dead: refused")
	_expect(it.offer_ok(calm) and not it.offer_ok(_m(calm, {"busy": true})), "an offer is made only when she is free")
	_expect(not it.offer_ok(_m(calm, {"dist": 30.0})), "no offer from far away")
	it.on_declined()
	_expect(not it.offer_ok(calm), "no offer while the declined gauge is powering down")
	wife.intimacy_offer_cd = 0.0
	it.tick(10.0, true, true, 700.0)
	it.finish_session()
	_expect(is_equal_approx(wife.intimacy, float(cfg.after_session)) and wife.intimacy_cd == 0.0, "a session drops the gauge to %.2f (no cooldown: the gauge itself has to fill again)" % float(cfg.after_session))
	wife.intimacy = 0.2
	it.finish_session()
	_expect(is_equal_approx(wife.intimacy, 0.2), "a session never raises a lower gauge")
	it.tick(float(cfg.cooldown_hours) * 60.0 + 1.0, true, true, 800.0)
	_expect(wife.intimacy_cd == 0.0, "the cooldown runs down with game time")

	# ---- the flow: offer -> accept -> follow -> choose -> start -> session -> end (a wife leads)
	wife.intimacy = 1.0
	wife.intimacy_cd = 0.0
	wife.intimacy_offer_cd = 0.0
	it = Intimacy.new(wife)
	var f := YogaFlow.new(it)
	var far := _m(calm, {"dist": 8.0})
	f.idle_step(10.0, far)
	_expect(f.state == YogaFlow.S.OFFERED and _events(f, "offer").size() == 1, "calm and full: she offers")
	f.drain()
	f.answer(true)
	_expect(f.state == YogaFlow.S.FOLLOWING and _events(f, "follow").size() == 1, "accepted: she follows")
	var say: Array = _events(f, "say")
	_expect(say.size() == 1 and (say[0].path as Array) == ["intimacy", "ask", "accepted_spouse"], "the accepting line")
	f.drain()
	f.step(1.0, far)
	_expect(f.state == YogaFlow.S.FOLLOWING, "still following while she is far")
	f.step(1.0, _m(calm, {"dist": 2.0}))
	_expect(f.state == YogaFlow.S.FOLLOWING and _events(f, "choose").is_empty(), "beside the player she waits: the menu opens only when the player asks")
	f.request_pose()
	f.step(0.1, _m(calm, {"dist": 2.0}))
	_expect(f.state == YogaFlow.S.CHOOSING and _events(f, "choose").size() == 1, "asked, beside the player: the pose menu")
	f.drain()
	_expect(not f.choose("nonsense"), "an unknown pose is refused")
	_expect(f.choose("yoga") and f.state == YogaFlow.S.STARTING, "a pose picked")
	var st := _events(f, "start")
	_expect(st.size() == 1 and st[0].pose == "yoga" and st[0].leader == "spouse", "the wife leads Happy Baby")
	f.drain()
	f.step(1.0, _m(calm, {"dist": 2.0, "paired": false}))
	_expect(f.state == YogaFlow.S.STARTING, "waiting for the pair to be in the pose")
	f.step(1.0, _m(calm, {"dist": 1.0, "paired": true}))
	_expect(f.state == YogaFlow.S.SESSION, "in the session")
	f.step(1.0, _m(calm, {"dist": 1.0, "paired": true, "danger": true}))
	_expect(f.state == YogaFlow.S.SESSION, "a threat does not tear a running session apart")
	f.step(1.0, _m(calm, {"dist": 1.0, "paired": false}))
	_expect(f.state == YogaFlow.S.IDLE and _events(f, "end_follow").size() == 1 and not _events(f, "say").is_empty(), "the session ends: role back, an after line")
	_expect(is_equal_approx(wife.intimacy, float(cfg.after_session)) and wife.intimacy_cd == 0.0, "gauge dropped, no cooldown")
	f.drain()
	f.idle_step(10.0, far)
	_expect(f.state == YogaFlow.S.IDLE, "no new offer after a session (not full, cooldown)")

	# ---- a declined gauge powers down slowly (no cooldown, no block)
	wife.intimacy = 1.0
	wife.intimacy_cd = 0.0
	wife.intimacy_offer_cd = 0.0
	it = Intimacy.new(wife)
	it.on_declined()
	it.tick(60.0, false, true, 900.0)
	_expect(is_equal_approx(wife.intimacy, 1.0 - float(cfg.decline_drain_per_hour)), "an hour after a decline the gauge is down %.2f (%.3f)" % [float(cfg.decline_drain_per_hour), wife.intimacy])
	it.tick(60.0 * 20.0, false, true, 2100.0)
	_expect(is_equal_approx(wife.intimacy, 1.0 - float(cfg.decline_fade)) and wife.intimacy_offer_cd == 0.0,
			"it stops powering down after %.2f (%.3f)" % [float(cfg.decline_fade), wife.intimacy])
	_expect(not it.offer_ok(calm), "and she does not offer again until it is full")

	# ---- decline: the gauge is kept at first, then powers down
	wife.intimacy = 1.0
	wife.intimacy_cd = 0.0
	f = YogaFlow.new(Intimacy.new(wife))
	f.idle_step(10.0, far)
	f.drain()
	f.answer(false)
	_expect(f.state == YogaFlow.S.IDLE and wife.intimacy == 1.0 and wife.intimacy_offer_cd > 0.0, "declined: gauge kept at first, the power-down pending")
	_expect(not _events(f, "say").is_empty() and _events(f, "follow").is_empty(), "declined: a polite line, no follow")
	f.drain()
	f.idle_step(10.0, far)
	_expect(f.state == YogaFlow.S.IDLE, "not nagged again straight away")
	# but she can still be asked on the Talk tab
	_expect(f.ask(calm) == "" and f.state == YogaFlow.S.FOLLOWING, "asking on the Talk tab still works after a decline")

	# ---- ending: danger, combat, Esc in the menu, other orders, blocked start
	for case: Array in [["danger", {"danger": true}], ["combat", {"combat": true}]]:
		wife.intimacy = 1.0
		wife.intimacy_cd = 0.0
		f = YogaFlow.new(Intimacy.new(wife))
		f.ask(calm)
		f.drain()
		f.step(1.0, _m(far, case[1]))
		var e := f.drain()
		var said := e.filter(func(x: Dictionary) -> bool: return x.do == "say")
		_expect(f.state == YogaFlow.S.IDLE and e.any(func(x: Dictionary) -> bool: return x.do == "end_follow")
				and said.size() == 1 and (said[0].path as Array) == ["intimacy", "ended", case[0]], "follow ends with a line: %s" % case[0])
	wife.intimacy = 1.0
	f = YogaFlow.new(Intimacy.new(wife))
	f.ask(calm)
	f.step(1.0, _m(calm, {"dist": 1.0}))
	f.drain()
	f.cancel()
	_expect(f.state == YogaFlow.S.IDLE and not _events(f, "end_follow").is_empty(), "Esc in the pose menu ends yoga mode and gives her role back")
	f = YogaFlow.new(Intimacy.new(wife))
	f.ask(calm)
	f.drain()
	f.step(1.0, _m(far, {"role_changed": true}))
	_expect(f.state == YogaFlow.S.IDLE and _events(f, "say").is_empty(), "other orders end it quietly")
	f = YogaFlow.new(Intimacy.new(wife))
	f.ask(calm)
	f.drain()
	f.step(5000.0, far)
	_expect(f.state == YogaFlow.S.FOLLOWING, "a follow has no timeout: she keeps following")
	# an accepted offer: she follows until the player asks for the pose
	wife.intimacy = 1.0
	wife.intimacy_cd = 0.0
	wife.intimacy_offer_cd = 0.0
	f = YogaFlow.new(Intimacy.new(wife))
	f.idle_step(10.0, far)
	f.drain()
	f.answer(true)
	f.drain()
	f.step(1.0, _m(calm, {"dist": 1.0}))
	_expect(f.state == YogaFlow.S.FOLLOWING and _events(f, "choose").is_empty(), "accepted: she follows beside the player and no menu opens yet")
	f.step(600.0, _m(calm, {"dist": 1.0, "hour": 2.0}))
	_expect(f.state == YogaFlow.S.FOLLOWING, "still following at night (only danger ends it)")
	_expect(f.request_pose(), "the player asks for the pose")
	f.step(0.1, _m(calm, {"dist": 6.0}))
	_expect(f.state == YogaFlow.S.FOLLOWING, "the menu waits until she is beside the player")
	f.step(0.1, _m(calm, {"dist": 1.0}))
	_expect(f.state == YogaFlow.S.CHOOSING and _events(f, "choose").size() == 1, "then the pose menu opens")
	f.choose("crawl")
	_expect(f.state == YogaFlow.S.STARTING, "the pick starts the pose")
	f = YogaFlow.new(Intimacy.new(wife))
	_expect(not f.request_pose(), "asking for a pose when she is not following does nothing")
	f = YogaFlow.new(Intimacy.new(wife))
	f.ask(calm)
	f.step(1.0, _m(calm, {"dist": 1.0}))
	f.choose("crawl")
	f.drain()
	f.step(float(cfg.start_timeout_s) + 1.0, _m(calm, {"dist": 1.0, "paired": false}))
	_expect(f.state == YogaFlow.S.IDLE and not _events(f, "end_follow").is_empty(), "a pose that cannot start ends the follow")
	_expect(wife.intimacy == 1.0, "a pose that never started costs nothing")
	# refused asks
	wife.intimacy = 0.3
	f = YogaFlow.new(Intimacy.new(wife))
	_expect(f.ask(calm) == "not_full" and f.state == YogaFlow.S.IDLE, "asked before the gauge is full: refused with a reason")
	wife.intimacy = 1.0
	_expect(f.ask(_m(calm, {"hour": 23.0})) == "" and f.state == YogaFlow.S.FOLLOWING, "asked at night: she comes (no danger)")

	# ---- a husband: the woman player leads
	husband.intimacy = 1.0
	husband.intimacy_cd = 0.0
	f = YogaFlow.new(Intimacy.new(husband))
	f.ask(calm)
	f.drain()
	f.step(1.0, _m(calm, {"dist": 1.0}))
	f.drain()
	f.choose("crawl")
	st = _events(f, "start")
	_expect(st.size() == 1 and st[0].leader == "player" and st[0].pose == "crawl", "a female player leads the crawl and the husband joins")

	# ---- adults only: a child or teen is never offered intimacy or yoga
	wife.intimacy = 1.0
	wife.intimacy_cd = 0.0
	wife.intimacy_offer_cd = 0.0
	var it2 := Intimacy.new(wife)
	_expect(it2.gate(_m(calm, {"minor": true})) == "minor" and not it2.offer_ok(_m(calm, {"minor": true})), "a minor: refused and never offered")
	var f2 := YogaFlow.new(it2)
	f2.idle_step(10.0, _m(calm, {"minor": true, "dist": 8.0}))
	_expect(f2.state == YogaFlow.S.IDLE and f2.ask(_m(calm, {"minor": true})) == "minor", "no offer to or from a minor, and asking is refused")
	var fake_house := {"family": [{"worker_id": 7, "stage": "teen", "name": "T"}]}
	var teen := SpouseCore.new()
	teen.worker_id = 7
	var grown := SpouseCore.new()
	grown.worker_id = 8
	_expect(not AdultsOnly.is_adult(_HouseStub.new(fake_house.family), teen) and AdultsOnly.is_adult(_HouseStub.new(fake_house.family), grown),
			"a teen of the family is a minor, an unrelated adult worker is not")

	print("\n%s" % ("ALL INTIMACY CHECKS PASSED" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)


class _HouseStub extends Node:
	var family: Array = []

	func _init(f: Array) -> void:
		family = f
