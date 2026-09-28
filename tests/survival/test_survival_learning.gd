extends SceneTree
## Headless tests for the v4 systems (survival_gdd.md v4; redesign_skills.md, redesign_economy.md,
## multiplayer_readiness.md): knowledge states and the ways to learn (trial and clues, notices, examining, talk, lessons,
## watching), the trade window (NPC barter, valuation, the local cap, want quotas, escrow, player-to-player confirms,
## atomic and idempotent commits, carry and never-offers refusals), obligations (labour, promises, credit books),
## world objects (node stocks, caches, the drying rack, staged builds), clothing wear, firewood rations, named random
## streams, and save version 2 with its 1 -> 2 migration. The M2b gate's unit checks live here; the M2a gate's
## season runs are in test_survival_selfsuff.gd.
##
##   Godot --headless --path . -s tests/survival/test_survival_learning.gd [-- --only name]
##
## Each test builds its own SurvivalCore with a fixed seed. Failures are listed and the exit code is 1.

const HUNTER := "bg.backcountry_hunter"
const RANGER := "bg.provincial_ranger"
const OLD_HUNTER := "npc.woods.old_hunter"
const SOLDIER := "npc.fort.soldier_1"
const HUT := "poi.woods.hunters_hut"
const STORE := "poi.fort.sutler_store"
const CAMP := "poi.fort.woods_camp"

var failures := PackedStringArray()
var passes := 0
var current := ""


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and str(args[0]) == "--only":
		only = str(args[1])
	var names := []
	for m in get_script().get_script_method_list():
		if str(m.name).begins_with("test_"):
			names.append(str(m.name))
	names.sort()
	for name in names:
		if only != "" and not str(name).contains(only):
			continue
		current = name
		var n0 := failures.size()
		call(name)
		if failures.size() > n0:
			print("  %s: %d failed" % [name, failures.size() - n0])
	print("")
	print("survival learning and trade: %d checks passed, %d failed (%d ms)" % [passes, failures.size(), Time.get_ticks_msec() - t0])
	for f in failures:
		printerr("  FAIL " + f)
	quit(1 if not failures.is_empty() else 0)


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		failures.append("%s: %s" % [current, what])


func near(a: float, b: float, tol: float, what: String) -> void:
	ok(absf(a - b) <= tol, "%s (got %.4f, want %.4f +- %.4f)" % [what, a, b, tol])


func mk(bg: String = HUNTER, opts: Dictionary = {}) -> SurvivalCore:
	var o := {"seed": 4242}
	for k in opts.keys():
		o[k] = opts[k]
	return SurvivalCore.new_game(bg, o)


func sustain(core: SurvivalCore) -> void:
	core.state.needs["stomach"] = 2400.0
	core.state.needs["reserve"] = 2500.0
	core.state.needs["warmth"] = 100.0
	core.state.needs["fatigue"] = 10.0
	core.state.needs["health"] = 100.0
	core.state.needs["wetness"] = 0.0


func live(core: SurvivalCore, minutes: float) -> void:
	var left := minutes
	while left > 0.0 and not core.is_dead():
		sustain(core)
		var step := minf(360.0, left)
		core.advance(step)
		left -= step


## Forget a knowledge record, so the id is unknown again (for the notice and talk tests).
func forget(core: SurvivalCore, kid: String) -> void:
	SurvivalLearning._k(core).erase(kid)


func stack_count(core: SurvivalCore, item: String) -> float:
	return SurvivalInventory.count(core, item)


# ---------------------------------------------------------------- knowledge and trial
func test_knowledge_gating_and_trial() -> void:
	var h := mk()
	# The hunter knows fur mitts but not the wool pair; a recipe nobody told him of cannot be tried.
	ok(SurvivalLearning.state_of(h, "rcp.mitts") == "unknown", "the hunter does not know wool mitts")
	SurvivalInventory.add(h, "item.material.wool_scrap", 2.0)
	var p := h.preview("clothing.sew_mitts", {"recipe": "rcp.mitts"})
	ok(not bool(p.ok), "an unknown recipe cannot be attempted: %s" % str(p.get("reasons", [])))
	# Heard of: allowed, harder (D +15) and untried.
	var r := mk(RANGER)
	ok(SurvivalLearning.state_of(r, "rcp.rawhide") == "heard_of", "the ranger has heard of rawhide")
	SurvivalInventory.add(r, "item.material.green_hide", 1.0, {"green": true, "grade": "good"})
	var pk := mk(HUNTER)
	SurvivalInventory.add(pk, "item.material.green_hide", 1.0, {"green": true, "grade": "good"})
	var pr := r.preview("craft.dress_hide", {"recipe": "rcp.rawhide"})
	var ph := pk.preview("craft.dress_hide", {"recipe": "rcp.rawhide"})
	ok(bool(pr.ok), "heard of is enough to try: %s" % str(pr.get("reasons", [])))
	near(float(pr.D) - float(ph.D), 15.0, 0.001, "heard of: D +15 against a character who knows it")
	var has_untried := false
	for f in SurvivalUtil.arr(pr.get("factors")):
		if str(f.get("src", "")) == "mod.untried":
			has_untried = true
	ok(has_untried, "the untried modifier shows on the prompt")
	# Seen (fix round 1: the ranger has seen moccasins made in the rangers' camps): D +5.
	ok(SurvivalLearning.state_of(r, "rcp.moccasins") == "seen", "the ranger has seen moccasins made")
	SurvivalInventory.add(r, "item.skin.dressed_buckskin", 1.0)
	SurvivalInventory.add(r, "item.material.sinew", 2.0)
	SurvivalInventory.add(pk, "item.skin.dressed_buckskin", 1.0)
	var prm := r.preview("craft.moccasins", {"recipe": "rcp.moccasins"})
	var phm := pk.preview("craft.moccasins", {"recipe": "rcp.moccasins"})
	near(float(prm.D) - float(phm.D), 5.0, 0.001, "seen: D +5 against a character who knows it")
	# Trial: failures from heard of give a clue each; three clues make it known.
	for i in 2:
		SurvivalLearning.record_result(r, "rcp.rawhide", "failure")
	ok(SurvivalLearning.state_of(r, "rcp.rawhide") == "heard_of", "two clues: still heard of")
	SurvivalLearning.record_result(r, "rcp.rawhide", "failure")
	ok(SurvivalLearning.state_of(r, "rcp.rawhide") == "known", "the third clue works it out")
	# Seen gives two clues a failure; a success from seen is known at once.
	var s := mk(RANGER)
	ok(SurvivalLearning.state_of(s, "know.snowshoes") == "seen", "the ranger has seen snowshoes made")
	SurvivalLearning.record_result(s, "know.snowshoes", "failure")
	ok(int(SurvivalLearning.record(s, "know.snowshoes").clues) == 2, "a failure from seen gives two clues")
	SurvivalLearning.record_result(s, "know.snowshoes", "partial")
	ok(SurvivalLearning.state_of(s, "know.snowshoes") == "known", "a partial from seen: known")
	# Practised after five successes (then it can be taught to another player).
	for i in 5:
		SurvivalLearning.record_result(s, "know.snowshoes", "success")
	ok(SurvivalLearning.state_of(s, "know.snowshoes") == "practised", "five successes: practised")
	# Plain verbs and common knowledge are never gated.
	ok(SurvivalLearning.state_of(h, "fire.strike_flint_steel") == "known", "striking a fire is common knowledge")
	ok(not SurvivalLearning.gates_action(h, h.data.action("eat")), "eating is a plain verb")


func test_notices_examine_talk() -> void:
	var c := mk()
	forget(c, "trap.snare_set")
	SurvivalInventory.add(c, "item.material.cordage", 2.0)
	ok(SurvivalLearning.state_of(c, "trap.snare_set") == "unknown", "forgotten for the test")
	c.state.context["near"] = ["node.trail", "node.sapling_stand"]
	var got := SurvivalLearning.check_notices(c)
	ok(got.has("trap.snare_set"), "cordage carried near a trail: the snare is noticed (%s)" % str(got))
	ok(SurvivalLearning.state_of(c, "trap.snare_set") == "heard_of", "a notice makes it heard of")
	# The cache notice needs 15 lb of venison carried near saplings.
	var d := mk()
	forget(d, "preserve.cache_pit")
	d.state.context["near"] = ["node.sapling_stand"]
	ok(not SurvivalLearning.check_notices(d).has("preserve.cache_pit"), "no meat, no notice")
	SurvivalInventory.add(d, "item.food.venison_raw", 16.0)
	ok(SurvivalLearning.check_notices(d).has("preserve.cache_pit"), "meat to keep: the hung cache is noticed")
	# Examining a thing in hand makes the recipes that make it heard of.
	var e := mk()
	ok(SurvivalLearning.can_examine(e, "item.cloth.mitts"), "the hunter can examine the mitts he carries")
	var ex := SurvivalLearning.examine(e, "item.cloth.mitts")
	ok(ex.has("rcp.mitts") and SurvivalLearning.state_of(e, "rcp.mitts") == "heard_of", "examining mitts: the wool pair is heard of (%s)" % str(ex))
	ok(not ex.has("rcp.mitts_fur"), "what is known already is not lowered")
	# Talk: the farm family's talk of keeping food.
	var t := mk()
	forget(t, "rcp.jerky")
	var tk := SurvivalLearning.talk(t, "npc.valley.farm_family")
	ok(tk.has("rcp.jerky"), "their talk makes jerky heard of (%s)" % str(tk))
	# Recipe book: every live recipe and technique, unknown entries show no inputs.
	var book := t.recipe_book()
	ok(int(book.total) >= 12 and int(book.known) > 0, "the recipe book lists the live entries (%d, %d known)" % [int(book.total), int(book.known)])


# ---------------------------------------------------------------- lessons and watching (M2b)
## The old hunter is at his hut from about 18:00 to 21:00 on some evenings; a 90-minute lesson must start early.
func hut_evening(bg: String = HUNTER) -> SurvivalCore:
	var c := mk(bg, {"start_day": "oct_mid", "start_hour": 18.3})
	c.go_to(HUT)
	return c


func test_lessons() -> void:
	var c := hut_evening()
	ok(SurvivalTrade.partner_present(c, OLD_HUNTER), "the old hunter is at his hut on an October evening")
	var offers := c.lesson_offers(OLD_HUNTER)
	ok(offers.size() >= 8, "he offers his lessons (%d)" % offers.size())
	var snow := {}
	for o in offers:
		if str(o.what) == "know.snowshoes":
			snow = o
		for a in SurvivalUtil.arr(o.asks):
			ok(not (SurvivalUtil.dict(a.ask).size() == 1 and SurvivalUtil.dict(a.ask).has("coin")), "no ask is coin only (%s)" % str(o.what))
	ok(bool(snow.get("ok", false)), "snowshoes can be taught: %s" % str(snow.get("reason", "")))
	ok(not bool(snow.asks[0].ok) and bool(snow.asks[1].ok), "trust 3 is not enough for friendship 5, but labour is always an ask")
	var r := c.arrange_lesson(OLD_HUNTER, "know.snowshoes", 1)
	ok(bool(r.get("ok", false)), "the lesson is agreed for four hours on his line: %s" % str(r.get("reason", "")))
	var owed := []
	for ob in c.obligations(true):
		if str(ob.kind) == "labour":
			owed.append(ob)
	ok(owed.size() == 1 and is_equal_approx(float(owed[0].what.hours), 4.0), "four hours of labour owed (%s)" % str(owed))
	var guard := 0
	while SurvivalJobs.is_running(c) and guard < 50:
		guard += 1
		sustain(c)
		c.advance(maxf(0.01, minf(60.0, SurvivalJobs.minutes_left(c))), true)
	ok(SurvivalLearning.state_of(c, "know.snowshoes") == "known", "taught: snowshoes are known (%s; %s)" % [SurvivalLearning.state_of(c, "know.snowshoes"), str(r).left(300)])
	ok(SurvivalLearning.recently_taught(c, "know.snowshoes"), "recently taught (+5% for three days)")
	ok(not bool(SurvivalLearning.lesson_check(c, OLD_HUNTER, "know.snowshoes").ok), "you know that already")
	# A skill lesson: immediate points and a practice pool; one a day per skill.
	var d := hut_evening(RANGER)
	SurvivalTrade.add_trust(d, OLD_HUNTER, 3.0, "test")
	var t0 := SurvivalSkills.level(d, "trapping")
	var give := SurvivalLearning.give_lesson(d, OLD_HUNTER, "skill:trapping")
	ok(float(give.points) > 0.5 and float(give.points) <= 2.0001, "a skill lesson gives up to 2 points now (%.2f)" % float(give.points))
	ok(float(give.pool) > 1.0 and SurvivalLearning.pool_left(d, "trapping") > 1.0, "and a practice pool (%.2f)" % float(give.pool))
	near(SurvivalSkills.level(d, "trapping") - t0, float(give.points), 0.0001, "the points are the skill's")
	ok(not bool(SurvivalLearning.lesson_check(d, OLD_HUNTER, "skill:trapping").ok), "one lesson a day in a skill")
	var before := SurvivalLearning.pool_left(d, "trapping")
	var g := SurvivalSkills.gain_from_check(d, d.data.action("trap.deadfall_set"), 30.0, "success", 0.0, 0.5)
	ok(g > 0.0 and SurvivalLearning.pool_left(d, "trapping") < before, "practice draws the pool down (doubled points)")
	# Teachers need a lead of 15.
	var e := hut_evening()
	SurvivalSkills.set_level(e, "trapping", 60.0)
	ok(not bool(SurvivalLearning.lesson_check(e, OLD_HUNTER, "skill:trapping").ok), "no lesson from a teacher less than 15 ahead")


func test_watching() -> void:
	# At 20:00 he is at his craft by the hut.
	var c := mk(RANGER, {"start_day": "oct_mid", "start_hour": 20.0})
	c.go_to(HUT)
	var w := c.watchable()
	var cord := {}
	for x in w:
		if str(x.action) == "craft.cordage":
			cord = x
	ok(not cord.is_empty(), "the old hunter at his craft can be watched (%s)" % str(w))
	# The ranger has only heard of hemp cordage (he has seen moccasins made since fix round 1).
	ok(SurvivalLearning.state_of(c, "rcp.cordage_hemp") == "heard_of", "the ranger has only heard of hemp cordage")
	var h0 := SurvivalSkills.level(c, "hidecraft")
	var r := c.run_job("learn.watch", {"performer": OLD_HUNTER, "action": "craft.cordage"})
	ok(r.has("outcome"), "watching runs as a job: %s" % str(r.get("reason", "")))
	ok(SurvivalLearning.state_of(c, "rcp.cordage_hemp") == "seen", "watched: seen (%s)" % SurvivalLearning.state_of(c, "rcp.cordage_hemp"))
	var gained := SurvivalSkills.level(c, "hidecraft") - h0
	ok(gained > 0.0 and gained <= 1.0001, "watching teaches a little, at most a point a day (%.3f)" % gained)


# ---------------------------------------------------------------- trade with NPCs
func store_evening(bg: String = HUNTER, day: String = "dec_early") -> SurvivalCore:
	var c := mk(bg, {"start_day": day, "start_hour": 19.5})
	c.go_to(STORE)
	return c


func test_npc_barter_and_valuation() -> void:
	var c := store_evening()
	ok(SurvivalTrade.partner_present(c, SOLDIER), "a soldier trades in the evening at the store")
	ok(not SurvivalTrade.partner_present(mk(HUNTER, {"start_day": "dec_early", "start_hour": 10.0}), SOLDIER), "not in the morning (on duty)")
	SurvivalInventory.add(c, "item.cloth.moccasins", 3.0)
	var moc := {"id": "item.cloth.moccasins", "qty": 1.0, "meta": {}}
	var dec_v := float(SurvivalTrade.unit_in(c, SOLDIER, moc).v)
	var sep := store_evening(HUNTER, "sep_mid")
	var sep_v := float(SurvivalTrade.unit_in(sep, SOLDIER, moc).v)
	ok(dec_v > sep_v, "moccasins are worth more to a soldier in December than September (%.0f vs %.0f)" % [dec_v, sep_v])
	ok(str(SurvivalTrade.want_tier(c, SOLDIER, "item.cloth.moccasins")) == "short_of", "in winter they are short of them")
	var q := SurvivalTrade.quote_units(c, SOLDIER, "item.cloth.moccasins", 1.0, "item.trade.tobacco")
	ok(q >= 1.0, "a pair of moccasins buys tobacco from a soldier (%.0f)" % q)
	var tob0 := stack_count(c, "item.trade.tobacco")
	var moc0 := stack_count(c, "item.cloth.moccasins")
	var committed := []
	c.trade_committed.connect(func(id, e): committed.append(id))
	var r := c.barter(SOLDIER, [["item.cloth.moccasins", 1.0]], [["item.trade.tobacco", 1.0]])
	ok(bool(r.get("ok", false)), "the barter commits: %s" % str(r.get("reason", "")))
	near(stack_count(c, "item.cloth.moccasins"), moc0 - 1.0, 0.0001, "the moccasins went")
	near(stack_count(c, "item.trade.tobacco"), tob0 + 1.0, 0.0001, "the tobacco came")
	ok(committed.size() == 1, "trade_committed fired once")
	ok(SurvivalUtil.arr(SurvivalTrade._t(c).ledger).size() == 1, "the ledger has the trade")
	ok(SurvivalUtil.num(c.state.stats.get("coin_spent"), 0.0) == 0.0, "no coin changed hands")
	# A good the partner has no use for is not worth rv to it.
	var nothing := {"id": "item.material.hide_scrap", "qty": 1.0, "meta": {}}
	ok(float(SurvivalTrade.unit_in(c, SOLDIER, nothing).v) <= 0.8 * SurvivalTrade.rv(c, "item.material.hide_scrap") + 0.001, "a good nobody wants: at most 0.8 of rv")
	# The local cap: a buyer's want is capped at 0.7 of what another partner present today asks for the good.
	var cap := SurvivalTrade.local_cap(c, SOLDIER, "item.trade.tobacco")
	var best := INF
	for p in SurvivalTrade.partners(c):
		if str(p) != SOLDIER and SurvivalTrade.present_today(c, str(p)):
			var u := SurvivalTrade.unit_out(c, str(p), "item.trade.tobacco")
			if u > 0.0:
				best = minf(best, u)
	if best < INF:
		near(cap, 0.7 * best / SurvivalTrade.rv(c, "item.trade.tobacco"), 0.001, "the cap is 0.7 x the lowest other offer today")
	else:
		ok(cap == INF, "no other offer: no cap")


func test_want_quota_and_never_offers() -> void:
	var c := store_evening()
	SurvivalInventory.add(c, "item.cloth.moccasins", 6.0)
	var row := SurvivalTrade.want_row(c, SOLDIER, "item.cloth.moccasins")
	var quota := int(SurvivalUtil.num(row.get("quota"), 4.0))
	var took := 0
	for i in quota:
		var r := c.barter(SOLDIER, [["item.cloth.moccasins", 1.0]], [["coin", 1]])
		if bool(r.get("ok", false)):
			took += 1
	ok(took >= 1, "the soldiers take moccasins while short (%d)" % took)
	var tier_after := SurvivalTrade.want_tier(c, SOLDIER, "item.cloth.moccasins")
	ok(tier_after != "short_of" or took < quota, "once the month's quota is met, the want falls (%s after %d)" % [tier_after, took])
	# The old hunter never parts with his snowshoes.
	var h := mk(HUNTER, {"start_day": "oct_mid", "start_hour": 19.5})
	h.go_to(HUT)
	var o := h.open_trade(OLD_HUNTER)
	ok(bool(o.ok), "a trade window with the old hunter: %s" % str(o.get("reason", "")))
	var s := SurvivalTrade.set_lines(h, str(o.tr), OLD_HUNTER, [{"kind": "item", "item_id": "item.tool.snowshoes", "qty": 1.0}])
	ok(not bool(s.ok), "his snowshoes are never offered: %s" % str(s.get("reason", "")))
	SurvivalTrade.cancel(h, str(o.tr))


func test_escrow_cancel_and_versions() -> void:
	var c := store_evening()
	SurvivalInventory.add(c, "item.cloth.moccasins", 2.0)
	var n0 := stack_count(c, "item.cloth.moccasins")
	var uid0 := str(SurvivalInventory.best_stack(c, "item.cloth.moccasins").get("uid", ""))
	var o := c.open_trade(SOLDIER)
	ok(bool(o.ok), "the window opens")
	var tr := str(o.tr)
	var o_b := c.open_trade("npc.fort.soldier_2")
	ok(not bool(o_b.get("ok", true)) and str(o_b.get("reason", "")).begins_with("you are already trading"), "one window at a time per party: %s" % str(o_b.get("reason", "")))
	var s := c.trade_lines(tr, [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": 2.0}])
	ok(bool(s.ok), "offered: %s" % str(s.get("reason", "")))
	near(stack_count(c, "item.cloth.moccasins"), n0 - 2.0, 0.0001, "offered goods leave the pack for escrow")
	var v := int(SurvivalTrade.session(c, tr).version)
	var stale := c.trade_confirm(tr, v - 1)
	ok(not bool(stale.ok), "a stale version cannot be confirmed")
	var cancel := SurvivalTrade.cancel(c, tr)
	ok(bool(cancel.ok), "cancelled")
	near(stack_count(c, "item.cloth.moccasins"), n0, 0.0001, "cancelling returns the escrow")
	ok(uid0 == "" or not SurvivalInventory.find_uid(c, uid0).is_empty(), "the stack keeps its uid through escrow")
	# A save cancels open windows and returns their escrow.
	var o2 := c.open_trade(SOLDIER)
	c.trade_lines(str(o2.tr), [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": 1.0}])
	var doc := SurvivalSave.to_document(c)
	near(stack_count(c, "item.cloth.moccasins"), n0, 0.0001, "saving returns escrowed goods")
	ok(SurvivalUtil.dict(SurvivalUtil.dict(doc.state.world.get("trade")).get("sessions")).is_empty(), "no open window is saved")


## The authority's real clock moves on (2.5 real seconds, with the game paused: no game time passes).
func real_wait(c: SurvivalCore, secs: float = 2.5) -> void:
	var was := c.paused
	c.paused = true
	c.update(secs)
	c.paused = was


func test_player_to_player() -> void:
	var c := store_evening()
	SurvivalTrade.add_guest_player(c, "pl.2", {"location": STORE, "items": [["item.food.cornmeal", 10.0]], "money_d": 30})
	SurvivalInventory.add(c, "item.cloth.moccasins", 1.0)
	var o := SurvivalTrade.open(c, "pl.1", "pl.2")
	ok(bool(o.ok), "two players open a window: %s" % str(o.get("reason", "")))
	var tr := str(o.tr)
	SurvivalTrade.set_lines(c, tr, "pl.1", [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": 1.0}])
	SurvivalTrade.set_lines(c, tr, "pl.2", [{"kind": "item", "item_id": "item.food.cornmeal", "qty": 6.0}])
	var v := int(SurvivalTrade.session(c, tr).version)
	var locked := SurvivalTrade.confirm(c, tr, "pl.1", v)
	ok(not bool(locked.ok) and str(locked.get("reason", "")).contains("wait"), "confirm is locked for 2 real seconds after an edit, on the authority's clock (%s)" % str(locked.get("reason", "")))
	ok(not bool(SurvivalTrade.confirm(c, tr, "pl.9", v).get("ok", true)), "a stranger to the trade cannot confirm it")
	ok(not SurvivalTrade.session(c, tr).confirmed.has("pl.9"), "and leaves no confirmation behind")
	real_wait(c)
	var c1 := SurvivalTrade.confirm(c, tr, "pl.1", v)
	ok(bool(c1.ok) and not bool(c1.get("committed", false)), "one confirm does not commit")
	# An edit bumps the version and clears both confirmations.
	SurvivalTrade.set_lines(c, tr, "pl.2", [{"kind": "item", "item_id": "item.food.cornmeal", "qty": 5.0}])
	var v2 := int(SurvivalTrade.session(c, tr).version)
	ok(v2 > v and int(SurvivalTrade.session(c, tr).confirmed["pl.1"]) == -1, "an edit clears the confirmations")
	real_wait(c)
	var corn0 := stack_count(c, "item.food.cornmeal")
	# Signals: trade_committed comes first, and a handler of the module signals sees the session already committed.
	var order := []
	var seen_open := [false]
	c.trade_committed.connect(func(_id, _e): order.append("trade_committed"))
	var on_inv := func():
		order.append("inventory_changed")
		if str(SurvivalTrade.session(c, tr).get("state", "")) == "open":
			seen_open[0] = true
	c.inventory_changed.connect(on_inv)
	SurvivalTrade.confirm(c, tr, "pl.2", v2)
	var done := SurvivalTrade.confirm(c, tr, "pl.1", v2)
	ok(bool(done.get("committed", false)), "both confirm the same version: committed")
	ok(not order.is_empty() and str(order[0]) == "trade_committed", "trade_committed is the first signal after a commit (%s)" % str(order))
	ok(order.count("inventory_changed") == 1, "the queued inventory_changed fires once (%s)" % str(order))
	ok(not seen_open[0], "no handler sees a half-applied session")
	near(stack_count(c, "item.food.cornmeal"), corn0 + 5.0, 0.0001, "the cornmeal is the local player's")
	var guest_moc := SurvivalInventory.count_usable_in(c, c.state.players["pl.2"].inventory, "item.cloth.moccasins")
	near(guest_moc, 1.0, 0.0001, "and the moccasins the guest's")
	var again := SurvivalTrade.commit(c, tr)
	ok(bool(again.ok) and (bool(again.get("already", false)) or SurvivalTrade.session(c, tr).is_empty()), "a second commit changes nothing")
	near(stack_count(c, "item.food.cornmeal"), corn0 + 5.0, 0.0001, "nothing moved twice")
	# Carry: a trade that would load a player past 60 kg is refused at commit and reopened.
	SurvivalTrade.add_guest_player(c, "pl.3", {"location": STORE, "items": [["item.ammo.lead", 200.0]]})
	var o3 := SurvivalTrade.open(c, "pl.1", "pl.3")
	SurvivalTrade.set_lines(c, str(o3.tr), "pl.3", [{"kind": "item", "item_id": "item.ammo.lead", "qty": 200.0}])
	SurvivalTrade.set_lines(c, str(o3.tr), "pl.1", [{"kind": "coin", "pence": 1}])
	var v3 := int(SurvivalTrade.session(c, str(o3.tr)).version)
	real_wait(c)
	SurvivalTrade.confirm(c, str(o3.tr), "pl.3", v3)
	var heavy := SurvivalTrade.confirm(c, str(o3.tr), "pl.1", v3)
	ok(not bool(heavy.get("committed", false)) and str(heavy.get("reason", "")).contains("carry"), "too heavy to carry: refused (%s)" % str(heavy.get("reason", "")))
	var view := SurvivalTrade.view(c, str(o3.tr), "pl.1")
	ok(float(SurvivalUtil.dict(view.get("load_after_kg")).get("pl.1", 0.0)) > 60.0, "the window shows the load after the trade (%s)" % str(view.get("load_after_kg")))
	SurvivalTrade.cancel(c, str(o3.tr))
	# A guest elsewhere cannot trade; a guest cannot trade with NPCs until co-op gives it its own records.
	SurvivalTrade.add_guest_player(c, "pl.4", {"location": CAMP})
	ok(not bool(SurvivalTrade.open(c, "pl.1", "pl.4").ok), "a player who is not here cannot trade")
	var gn := SurvivalTrade.open(c, "pl.2", SOLDIER)
	ok(not bool(gn.ok), "a guest's trade with an NPC waits for co-op (%s)" % str(gn.get("reason", "")))
	# Per-player trust: a guest's record is its own.
	SurvivalTrade.add_trust(c, SOLDIER, 4.0, "test", "pl.2")
	near(SurvivalTrade.trust(c, SOLDIER, "pl.2"), 4.0, 0.0001, "the guest's trust is its own")
	ok(SurvivalTrade.trust(c, SOLDIER) < 4.0, "and not the host's")


# ---------------------------------------------------------------- obligations
func test_obligations() -> void:
	var c := store_evening()
	SurvivalInventory.add(c, "item.food.venison_raw", 4.0)
	# Labour as payment: owed, worked off, kept (trust and standing rise).
	var r := c.barter(SOLDIER, [["labour", 2.0, "job.landing_hand"]], [["item.trade.tobacco", 1.0]])
	ok(bool(r.get("ok", false)), "two hours of labour buy tobacco from a soldier: %s" % str(r.get("reason", "")))
	var obs := c.obligations(true)
	var lab := {}
	for ob in obs:
		if str(ob.kind) == "labour":
			lab = ob
	ok(not lab.is_empty(), "the labour is owed")
	var t0 := c.trust(SOLDIER)
	sustain(c)
	var w := c.work_off(str(lab.get("id", "")), 180.0)
	ok(bool(w.get("done", false)), "worked off")
	ok(str(SurvivalTrade.obligation(c, str(lab.id)).status) == "kept", "kept")
	ok(c.trust(SOLDIER) > t0, "keeping it earns trust (%.1f -> %.1f)" % [t0, c.trust(SOLDIER)])
	# Labour not given in three days is broken.
	var d := store_evening()
	SurvivalTrade.add_trust(d, SOLDIER, 3.0, "test")
	d.barter(SOLDIER, [["labour", 2.0, "job.landing_hand"]], [["item.trade.tobacco", 1.0]])
	var t1 := d.trust(SOLDIER)
	live(d, 4.0 * 1440.0)
	var broken := 0
	for ob in d.obligations():
		if str(ob.kind) == "labour" and str(ob.status) == "broken":
			broken += 1
	ok(broken == 1, "not worked in three days: broken")
	ok(d.trust(SOLDIER) < t1, "a broken promise costs trust")
	# The promise start: 60 lb of venison to the sutler by Late February.
	var p := mk(HUNTER, {"start_variant": "start.promise"})
	var prom := {}
	for ob in p.obligations(true):
		if str(ob.kind) == "promise":
			prom = ob
	ok(not prom.is_empty(), "the promise start owes the sutler")
	p.go_to(STORE)
	p.state.minutes = SurvivalClock.minutes_at(p, "sep_early", SurvivalClock.year(p), 10.0)
	SurvivalInventory.add(p, "item.food.venison_raw", 60.0)
	var dl := SurvivalTrade.deliver(p, str(prom.get("id", "")))
	ok(bool(dl.get("ok", false)), "delivered: %s" % str(dl.get("reason", "")))
	# Credit books are obligations too, kept in step with the account.
	var oc := mk(HUNTER, {"start_variant": "start.outfitted_on_credit"})
	var cr := {}
	for ob in oc.obligations(true):
		if str(ob.kind) == "credit":
			cr = ob
	ok(not cr.is_empty() and is_equal_approx(float(cr.what.balance_d), 715.0), "the outfit's book is on the ledger (%s)" % str(cr))
	ok(float(cr.get("due_min", 0.0)) < 0.0, "a credit book has no due minute (graded by the settlement)")


# ---------------------------------------------------------------- world objects
func test_nodes_caches_racks_builds() -> void:
	var c := mk()
	var nuts := SurvivalNodes.available(c, "node.nut_grove", "item.food.nuts")
	ok(nuts > 0.0 and nuts < 1.0e8, "the nut groves hold a season's mast (%.0f)" % nuts)
	near(SurvivalNodes.take(c, "node.nut_grove", "item.food.nuts", 10.0), 10.0, 0.0001, "a search takes from it")
	near(SurvivalNodes.available(c, "node.nut_grove", "item.food.nuts"), nuts - 10.0, 0.0001, "and it is less")
	ok(SurvivalNodes.available(c, "node.deadwood", "item.fuel.bundle") > 1.0e8, "M1 nodes have no stock")
	# A hung cache.
	var cid := SurvivalCamp.create_cache(c, CAMP, "hung", "good")
	ok(not SurvivalCamp.cache_at(c, CAMP).is_empty(), "the cache stands at the camp")
	SurvivalInventory.add(c, "item.food.jerky", 10.0)
	var m0 := SurvivalAlmanac.food_meals(c)
	near(SurvivalCamp.cache_store(c, cid, "item.food.jerky", 8.0), 8.0, 0.0001, "stored")
	near(SurvivalAlmanac.food_meals(c), m0, 0.001, "food in the cache still counts as stored food")
	near(SurvivalCamp.cache_take(c, cid, "item.food.jerky", 3.0), 3.0, 0.0001, "taken back")
	c.go_to(STORE)
	near(SurvivalCamp.cache_take(c, cid, "item.food.jerky", 1.0), 0.0, 0.0001, "a cache is used where it stands")
	# Pilferage is a world stream: two worlds with the same seed lose the same.
	var a := mk()
	var b := mk()
	for x in [a, b]:
		var id := SurvivalCamp.create_cache(x, CAMP, "hung", "fair")
		SurvivalInventory.add(x, "item.food.nuts", 30.0)
		SurvivalCamp.cache_store(x, id, "item.food.nuts", 30.0)
		SurvivalStreams.player(x, "craft").randf()
	SurvivalStreams.player(a, "craft").randf()
	for x in [a, b]:
		for i in 5:
			SurvivalCamp.tick_caches(x)
	near(SurvivalCamp.cache_meals(a), SurvivalCamp.cache_meals(b), 0.000001, "pilferage does not depend on other streams' draws")
	ok(SurvivalCamp.cache_meals(a) < 30.0 * 0.95 * 1.0e9, "something is lost over five days")
	# The drying rack.
	var r := mk()
	SurvivalCamp.rack_hang(r, "item.food.jerky", 5.0, {}, 1.0)
	ok(SurvivalCamp.rack_take_ready(r).is_empty(), "not cured yet")
	live(r, 1441.0)
	var got := SurvivalCamp.rack_take_ready(r)
	near(float(got.get("item.food.jerky", 0.0)), 5.0, 0.0001, "cured: taken down")
	# The half-faced camp's three stages; a partial stage leaves gaps that chinking closes.
	var h := mk()
	var spec := SurvivalUtil.dict(h.data.action("shelter.half_faced_camp").get("build"))
	SurvivalCamp.build_stage(h, spec, 0.0)
	SurvivalCamp.build_stage(h, spec, -0.34)
	var fin := SurvivalCamp.build_stage(h, spec, 0.0)
	ok(bool(fin.done), "three stages: built")
	var sh := SurvivalCamp.shelter_at(h, CAMP)
	near(float(sh.quality), 3.5, 0.001, "a partial stage: quality 3.5")
	SurvivalCamp.add_wind(h, 1.0)
	near(float(SurvivalCamp.shelter_at(h, CAMP).quality), 4.0, 0.001, "chinked: quality 4")
	ok(SurvivalUtil.num(SurvivalCamp.shelter_at(h, CAMP).get("wind_add"), 0.0) > 0.0, "and what is left of the work is wind protection")


func test_clothing_wear_and_mending() -> void:
	var c := mk()
	var n0 := stack_count(c, "item.cloth.moccasins")
	c.set_activity("walk")
	SurvivalInventory.tick_wear(c, 16.0)
	near(SurvivalInventory.wear_of(c, "item.cloth.moccasins"), 0.5, 0.001, "16 hours' walking: half a pair's life")
	c.set_activity("heavy_work")
	SurvivalInventory.tick_wear(c, 8.0)
	near(SurvivalInventory.wear_of(c, "item.cloth.moccasins"), 0.625, 0.001, "standing work wears at half the rate")
	var mended := SurvivalInventory.mend(c, ["item.cloth.moccasins"], 0.3)
	ok(mended == "item.cloth.moccasins", "mended")
	near(SurvivalInventory.wear_of(c, "item.cloth.moccasins"), 0.325, 0.001, "mending takes wear off")
	c.set_activity("walk")
	SurvivalInventory.tick_wear(c, 22.0)
	near(stack_count(c, "item.cloth.moccasins"), n0 - 1.0, 0.0001, "worn out: the pair is gone")
	ok(c.state.worn.has("item.cloth.moccasins") == (n0 > 1.0), "the spare pair goes on")


func test_firewood_rations() -> void:
	var c := mk(RANGER, {"start_day": "nov_mid", "start_hour": 10.0})
	c.go_to("poi.fort.woodpile")
	SurvivalInventory.add(c, "item.fuel.split_wood", 64.0)
	var money0 := SurvivalEconomy.money(c)
	var r := SurvivalEconomy.deliver_firewood(c, 64.0, "rations")
	ok(bool(r.get("ok", false)) and int(r.get("cords", 0)) >= 1, "cords delivered: %s" % str(r))
	ok(SurvivalEconomy.money(c) == money0, "paid in rations, not coin")
	ok(float(SurvivalUtil.dict(r.get("rations")).get("item.food.flour", 0.0)) > 0.0, "flour and salt pork (%s)" % str(r.get("rations")))
	ok(int(r.get("cords", 0)) <= 5, "at most a day's cords from one man")


# ---------------------------------------------------------------- streams and saves
func test_streams() -> void:
	var a := mk()
	var b := mk()
	var xa := SurvivalStreams.world(a, "caches").randf()
	SurvivalStreams.player(b, "craft").randf()
	SurvivalStreams.player(b, "craft").randf()
	var xb := SurvivalStreams.world(b, "caches").randf()
	near(xa, xb, 0.0, "a named stream does not depend on draws from another")
	ok(SurvivalStreams.seed_for(1, "w.caches") != SurvivalStreams.seed_for(1, "w.nodes"), "different names, different seeds")
	# A loaded game continues each stream exactly.
	SurvivalStreams.world(a, "caches").randf()
	var doc := SurvivalSave.to_json(a)
	var l := SurvivalSave.from_json(doc)
	near(SurvivalStreams.world(l, "caches").randf(), SurvivalStreams.world(a, "caches").randf(), 0.0, "the stream continues after a load")


func test_save_v2_and_migration() -> void:
	var c := mk()
	SurvivalCamp.create_cache(c, CAMP, "hung", "good")
	SurvivalTrade.add_trust(c, OLD_HUNTER, 1.0, "test")
	var txt := SurvivalSave.to_json(c)
	var parsed = JSON.parse_string(txt)
	ok(int(parsed.meta.save_version) == 2, "save version 2")
	ok(int(parsed.meta.data_schema) == 4, "data schema 4")
	var state_txt := JSON.stringify(parsed.state)
	ok(not state_txt.contains("1e99999") and not state_txt.contains("inf"), "no infinities in the save text")
	ok(str(parsed.get("state_bin", "")) != "", "the save carries the bit-exact binary copy")
	var l := SurvivalSave.from_json(txt)
	ok(l != null and not SurvivalCamp.cache_at(l, CAMP).is_empty(), "world records survive a load")
	near(l.trust(OLD_HUNTER), c.trust(OLD_HUNTER), 0.0001, "player records survive a load")
	ok(l.has_habit("habit.line_hand"), "habits survive a load")
	# A version-1 (v3) save: flags.knowledge, no world or players, the v3 skill roster.
	var d := c.to_dict()
	d.erase("world")
	d.erase("players")
	d.erase("player_id")
	d["flags"]["knowledge"] = ["rcp.jerky", "trap.snare_set"]
	d["flags"]["actions_done"] = ["fire.gather"]
	d["skills"].erase("trapping")
	d["skills"].erase("provisions")
	d["skills"].erase("hidecraft")
	d["skills"]["survival"] = 40.0
	d["skills"]["hunting"] = 36.0
	d["version"] = 1
	var old := SurvivalSave.from_document({"meta": {"save_version": 1}, "state": d})
	ok(old != null, "a version-1 save loads")
	if old != null:
		ok(str(old.state.player_id) == "pl.1" and old.state.players.has("pl.1"), "migrated: the local player record")
		ok(SurvivalLearning.state_of(old, "rcp.jerky") == "known", "old knowledge is known")
		near(SurvivalSkills.level(old, "trapping"), 40.0, 0.0001, "Trapping = the old Survival")
		near(SurvivalSkills.level(old, "provisions"), 12.0 + (40.0 - 32.0) / 2.0, 0.0001, "Provisions = start + half the Survival grown")
		near(SurvivalSkills.level(old, "hidecraft"), 15.0 + (36.0 - 30.0) / 2.0, 0.0001, "Hide and Needle = start + half the Hunting grown")
		ok(old.has_habit("habit.line_hand"), "the perk becomes the habit")
		ok(SurvivalLearning.first_success_set(old).has("fire.gather"), "done actions keep their first success")
	# A save from a newer game is refused.
	ok(SurvivalSave.from_document({"meta": {"save_version": 99}, "state": c.to_dict()}) == null, "a newer save is refused")


# ---------------------------------------------------------------- fix round 1: the code review's trade and save cases
func _labour_ob(c: SurvivalCore) -> Dictionary:
	for ob in c.obligations(true):
		if str(ob.kind) == "labour":
			return ob
	return {}


## work_off: no zero-minute keeping, the job's place, no work while busy, kept only when every hour is worked.
func test_work_off_rules() -> void:
	var c := store_evening()
	var r := c.barter(SOLDIER, [["labour", 2.0, "job.landing_hand"]], [["item.trade.tobacco", 1.0]])
	ok(bool(r.get("ok", false)), "labour buys tobacco: %s" % str(r.get("reason", "")))
	var lab := _labour_ob(c)
	var t0 := c.trust(SOLDIER)
	var m0 := c.state.minutes
	var z := c.work_off(str(lab.id), 0.0)
	ok(not bool(z.ok) and str(SurvivalTrade.obligation(c, str(lab.id)).status) == "open", "work_off(0) keeps nothing (%s)" % str(z.get("reason", "")))
	near(c.state.minutes, m0, 0.0001, "and no game time passes")
	near(c.trust(SOLDIER), t0, 0.0001, "and no trust is earned")
	c.go_to(CAMP)
	var away := c.work_off(str(lab.id), 120.0)
	ok(not bool(away.ok) and str(away.get("reason", "")).contains("the work is done at"), "labour is worked at the job's place (%s)" % str(away.get("reason", "")))
	c.go_to(STORE)
	sustain(c)
	var j := c.start_job("rest.sleep", {"hours": 1.0})
	if bool(j.get("ok", false)):
		ok(not bool(c.work_off(str(lab.id), 60.0).ok), "no work while another job runs (or asleep)")
		c.cancel_job("test")
	sustain(c)
	var half := c.work_off(str(lab.id), 60.0)
	ok(bool(half.ok) and not bool(half.done) and str(SurvivalTrade.obligation(c, str(lab.id)).status) == "open", "an hour of two: still owed")
	near(c.trust(SOLDIER), t0, 0.0001, "no trust for half the work")
	var rest := c.work_off(str(lab.id), 600.0)
	ok(bool(rest.done) and str(SurvivalTrade.obligation(c, str(lab.id)).status) == "kept", "the second hour keeps it")
	near(float(rest.worked_min), 60.0, 0.5, "only what was still owed is worked")
	ok(c.trust(SOLDIER) > t0, "kept labour earns trust")


## A lesson must fit before the mentor leaves; one cut short resumes; one never given voids the trade and returns the ask.
func test_lesson_schedule_and_void() -> void:
	# At 20:30 the old hunter turns in at 21:00: no lesson of 60-120 minutes can be agreed, and nothing is owed.
	var late := mk(HUNTER, {"start_day": "oct_mid", "start_hour": 20.5})
	late.go_to(HUT)
	var r := late.arrange_lesson(OLD_HUNTER, "know.snowshoes", 1)
	ok(not bool(r.get("ok", false)) and str(r.get("reason", "")).contains("not enough time"), "too late in his evening: refused (%s)" % str(r.get("reason", "")))
	ok(_labour_ob(late).is_empty(), "and no labour is owed")
	# Agreed at 18:20, cut short: the lesson resumes the next evening without a second ask.
	var c := hut_evening()
	var a := c.arrange_lesson(OLD_HUNTER, "know.snowshoes", 1)
	ok(bool(a.get("ok", false)), "agreed at 18:20: %s" % str(a.get("reason", "")))
	c.advance(20.0)
	c.cancel_job("moved")
	ok(SurvivalLearning.state_of(c, "know.snowshoes") != "known", "cut short: not yet taught")
	var lesson := SurvivalLearning.open_lesson(c, OLD_HUNTER, "know.snowshoes")
	ok(not lesson.is_empty(), "the lesson stays owed")
	sustain(c)
	c.go_to(CAMP)
	live(c, maxf(0.0, SurvivalClock.minutes_at(c, "oct_late", SurvivalClock.year(c), 18.3) - c.state.minutes))
	c.go_to(HUT)
	var n_lab := 0
	for ob in c.obligations(true):
		if str(ob.kind) == "labour":
			n_lab += 1
	var b := c.arrange_lesson(OLD_HUNTER, "know.snowshoes", 1)
	ok(bool(b.get("ok", false)) and bool(SurvivalUtil.dict(b.get("lesson")).get("resumes", false)), "the next evening it resumes: %s" % str(b.get("reason", b.get("lesson", ""))))
	var n_lab2 := 0
	for ob in c.obligations(true):
		if str(ob.kind) == "labour":
			n_lab2 += 1
	ok(n_lab2 == n_lab, "no second ask (%d labour owed, was %d)" % [n_lab2, n_lab])
	var g := 0
	while SurvivalJobs.is_running(c) and g < 50:
		g += 1
		sustain(c)
		c.advance(maxf(0.01, minf(60.0, SurvivalJobs.minutes_left(c))), true)
	ok(SurvivalLearning.state_of(c, "know.snowshoes") == "known", "resumed and taught (%s)" % SurvivalLearning.state_of(c, "know.snowshoes"))
	# Never given: the goods asked come back, and labour asked is void, not broken.
	var d := hut_evening(RANGER)
	SurvivalInventory.add(d, "item.trade.tobacco", 1.0)
	var tob0 := stack_count(d, "item.trade.tobacco")
	var e := d.arrange_lesson(OLD_HUNTER, "trap.snare_set", 1)
	ok(bool(e.get("ok", false)), "the snare lesson for a twist of tobacco: %s" % str(e.get("reason", "")))
	near(stack_count(d, "item.trade.tobacco"), tob0 - 1.0, 0.0001, "the tobacco went with the agreement")
	d.advance(10.0)
	d.cancel_job("moved")
	var t0 := d.trust(OLD_HUNTER)
	d.go_to(CAMP)
	live(d, 4.0 * 1440.0)
	near(stack_count(d, "item.trade.tobacco"), tob0, 0.0001, "never given: the tobacco came back")
	var voided := false
	for ob in d.obligations():
		if str(ob.kind) == "lesson" and str(ob.status) == "void":
			voided = true
	ok(voided, "the lesson is void, not broken")
	ok(d.trust(OLD_HUNTER) >= t0 - 0.0001, "and nobody's trust fell")
	var f := hut_evening(RANGER)
	var lab_l := f.arrange_lesson(OLD_HUNTER, "trap.snare_set", 0)
	ok(bool(lab_l.get("ok", false)), "the snare lesson for three hours on his line: %s" % str(lab_l.get("reason", "")))
	f.advance(10.0)
	f.cancel_job("moved")
	f.go_to(CAMP)
	live(f, 4.0 * 1440.0)
	var lab_status := ""
	for ob in f.obligations():
		if str(ob.kind) == "labour":
			lab_status = str(ob.status)
	ok(lab_status == "void", "the labour asked for a lesson never given is void (%s)" % lab_status)


## The trade.barter and trade.haggle jobs act on the version the player saw when they started.
func test_trade_jobs_pin_the_version() -> void:
	var c := store_evening()
	SurvivalTrade.add_guest_player(c, "pl.2", {"location": STORE, "items": [["item.food.cornmeal", 10.0]]})
	SurvivalInventory.add(c, "item.cloth.moccasins", 1.0)
	var o := SurvivalTrade.open(c, "pl.1", "pl.2")
	var tr := str(o.tr)
	SurvivalTrade.set_lines(c, tr, "pl.1", [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": 1.0}])
	SurvivalTrade.set_lines(c, tr, "pl.2", [{"kind": "item", "item_id": "item.food.cornmeal", "qty": 6.0}])
	real_wait(c)
	var corn0 := stack_count(c, "item.food.cornmeal")
	var j := c.start_job("trade.barter", {"tr": tr})
	ok(bool(j.get("ok", false)), "the trade job starts: %s" % str(j.get("reason", "")))
	ok(int(SurvivalUtil.dict(SurvivalUtil.dict(j.get("job")).get("params")).get("version", -1)) == int(SurvivalTrade.session(c, tr).version), "it pins the version on the screen")
	# The other player cuts the offer and confirms while the job runs.
	SurvivalTrade.set_lines(c, tr, "pl.2", [{"kind": "item", "item_id": "item.food.cornmeal", "qty": 1.0}])
	real_wait(c)
	SurvivalTrade.confirm(c, tr, "pl.2", int(SurvivalTrade.session(c, tr).version))
	var g := 0
	while SurvivalJobs.is_running(c) and g < 20:
		g += 1
		sustain(c)
		c.advance(maxf(0.01, SurvivalJobs.minutes_left(c)), true)
	var last := SurvivalUtil.dict(c.state.jobs.get("last_result"))
	ok(str(last.get("interrupted", "")).contains("offer changed"), "the job ends on 'the offer changed' (%s)" % str(last))
	near(stack_count(c, "item.food.cornmeal"), corn0, 0.0001, "nothing was committed on the version never seen")
	ok(str(SurvivalTrade.session(c, tr).get("state", "")) == "open", "the window is still open to look again")
	SurvivalTrade.cancel(c, tr)
	# The same job without an edit commits an NPC trade.
	var n := store_evening()
	SurvivalInventory.add(n, "item.cloth.moccasins", 2.0)
	var on := n.open_trade(SOLDIER)
	n.trade_lines(str(on.tr), [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": 1.0}])
	n.trade_request(str(on.tr), [{"kind": "item", "item_id": "item.trade.tobacco", "qty": 1.0}])
	var tob0 := stack_count(n, "item.trade.tobacco")
	var rj := n.run_job("trade.barter", {"tr": str(on.tr)})
	ok(bool(SurvivalUtil.dict(rj.get("trade")).get("committed", false)), "an unchanged offer commits through the job (%s)" % str(rj).left(200))
	near(stack_count(n, "item.trade.tobacco"), tob0 + 1.0, 0.0001, "the tobacco came")
	# A haggle press on an offer edited while talking does not count.
	var h := store_evening()
	SurvivalInventory.add(h, "item.cloth.moccasins", 4.0)
	var oh := h.open_trade(SOLDIER)
	h.trade_lines(str(oh.tr), [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": 3.0}])
	h.trade_request(str(oh.tr), [{"kind": "item", "item_id": "item.trade.tobacco", "qty": 2.0}])
	var jh := h.start_job("trade.haggle", {"tr": str(oh.tr)})
	ok(bool(jh.get("ok", false)), "a haggle starts: %s" % str(jh.get("reason", "")))
	h.trade_lines(str(oh.tr), [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": 2.0}])
	var gh := 0
	while SurvivalJobs.is_running(h) and gh < 20:
		gh += 1
		sustain(h)
		h.advance(maxf(0.01, SurvivalJobs.minutes_left(h)), true)
	ok(SurvivalTrade.haggle_presses(h, str(oh.tr)) == 0, "the press on the old offer does not count")
	SurvivalTrade.cancel(h, str(oh.tr))


## A line naming a stack by uid is what that stack is, never what the client labels it.
func test_uid_lines_are_checked() -> void:
	var c := store_evening()
	SurvivalTrade.add_guest_player(c, "pl.2", {"location": STORE, "items": [["item.food.cornmeal", 10.0]]})
	SurvivalInventory.add(c, "item.material.cordage", 3.0)
	var cord_uid := str(SurvivalInventory.best_stack(c, "item.material.cordage").get("uid", ""))
	var o := SurvivalTrade.open(c, "pl.1", "pl.2")
	var tr := str(o.tr)
	var bad := SurvivalTrade.set_lines(c, tr, "pl.1", [{"kind": "item", "uid": cord_uid, "item_id": "item.tool.snowshoes", "qty": 1.0}])
	ok(not bool(bad.ok) and str(bad.get("reason", "")).contains("does not match"), "a mislabelled uid is refused (%s)" % str(bad.get("reason", "")))
	near(stack_count(c, "item.material.cordage"), 3.0, 0.0001, "nothing went into escrow")
	var good := SurvivalTrade.set_lines(c, tr, "pl.1", [{"kind": "item", "uid": cord_uid, "qty": 2.0}])
	ok(bool(good.ok), "a uid line takes its item from the stack: %s" % str(good.get("reason", "")))
	var v := SurvivalTrade.view(c, tr, "pl.2")
	var l0 := SurvivalUtil.dict(SurvivalUtil.arr(SurvivalUtil.dict(v.lines).get("pl.1"))[0])
	ok(str(l0.get("item_id", "")) == "item.material.cordage" and is_equal_approx(float(l0.qty), 2.0), "the other side sees what is really offered (%s)" % str(l0))
	# A curing stack cannot be offered by its uid; nor can an untradeable good.
	SurvivalInventory.add(c, "item.skin.dressed_buckskin", 1.0, {"curing": true, "cure_until": c.state.minutes + 1440.0})
	var cur_uid := ""
	for st in c.state.inventory:
		if str(st.id) == "item.skin.dressed_buckskin" and bool(SurvivalUtil.dict(st.meta).get("curing", false)):
			cur_uid = str(st.uid)
	var cur := SurvivalTrade.set_lines(c, tr, "pl.1", [{"kind": "item", "uid": cur_uid, "qty": 1.0}])
	ok(not bool(cur.ok) and str(cur.get("reason", "")).contains("curing"), "a curing stack stays out of trade (%s)" % str(cur.get("reason", "")))
	var row := c.data.item("item.material.hide_scrap")
	row["tradeable"] = false
	SurvivalInventory.add(c, "item.material.hide_scrap", 1.0)
	var sc_uid := str(SurvivalInventory.best_stack(c, "item.material.hide_scrap").get("uid", ""))
	var nt := SurvivalTrade.set_lines(c, tr, "pl.1", [{"kind": "item", "uid": sc_uid, "qty": 1.0}])
	row.erase("tradeable")
	ok(not bool(nt.ok) and str(nt.get("reason", "")).contains("cannot be traded"), "an untradeable good by uid is refused (%s)" % str(nt.get("reason", "")))
	SurvivalTrade.cancel(c, tr)


## The NPC evaluates after either side's edit, in either order, and on the player's confirm.
func test_npc_side_edits() -> void:
	for order in ["player_first", "npc_first"]:
		var c := store_evening()
		SurvivalInventory.add(c, "item.cloth.moccasins", 2.0)
		var o := c.open_trade(SOLDIER)
		var tr := str(o.tr)
		var mine := [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": 1.0}]
		var theirs := [{"kind": "item", "item_id": "item.trade.tobacco", "qty": 1.0}]
		if order == "player_first":
			c.trade_lines(tr, mine)
			c.trade_request(tr, theirs)
		else:
			c.trade_request(tr, theirs)
			c.trade_lines(tr, mine)
		var v := int(SurvivalTrade.session(c, tr).version)
		ok(int(SurvivalTrade.session(c, tr).confirmed[SOLDIER]) == v, "%s: the soldier confirms the deal as it stands" % order)
		var r := c.trade_confirm(tr, v)
		ok(bool(r.get("committed", false)), "%s: the player's confirm commits (%s)" % [order, str(r.get("reason", ""))])
	# A deal the NPC will not take says why on the confirm.
	var d := store_evening()
	SurvivalInventory.add(d, "item.material.hide_scrap", 1.0)
	var od := d.open_trade(SOLDIER)
	d.trade_request(str(od.tr), [{"kind": "item", "item_id": "item.trade.tobacco", "qty": 3.0}])
	d.trade_lines(str(od.tr), [{"kind": "item", "item_id": "item.material.hide_scrap", "qty": 1.0}])
	var rd := d.trade_confirm(str(od.tr), int(SurvivalTrade.session(d, str(od.tr)).version))
	ok(not bool(rd.get("committed", false)) and str(rd.get("reason", "")) != "", "an unfair deal is not committed, with a reason (%s)" % str(rd.get("reason", "")))
	SurvivalTrade.cancel(d, str(od.tr))


## The authority closes windows when a party goes, the day turns or the window sits idle; worn garments stay on.
func test_session_lifecycle() -> void:
	var c := store_evening()
	SurvivalInventory.add(c, "item.cloth.moccasins", 1.0)
	var n0 := stack_count(c, "item.cloth.moccasins")
	var o := c.open_trade(SOLDIER)
	c.trade_lines(str(o.tr), [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": 1.0}])
	c.go_to(CAMP)
	ok(SurvivalTrade.session(c, str(o.tr)).is_empty(), "walking away closes the window")
	near(stack_count(c, "item.cloth.moccasins"), n0, 0.0001, "and the escrow comes back")
	var day := mk(HUNTER, {"start_day": "dec_early", "start_hour": 10.0})
	day.go_to(STORE)
	var o2 := day.open_trade("npc.fort.sutler")
	ok(bool(o2.ok), "a window with the sutler opens: %s" % str(o2.get("reason", "")))
	sustain(day)
	day.advance(30.0)
	ok(not SurvivalTrade.session(day, str(o2.tr)).is_empty(), "half an hour: still open")
	sustain(day)
	day.advance(100.0)
	ok(SurvivalTrade.session(day, str(o2.tr)).is_empty(), "a window left idle for two hours is closed")
	# A worn garment cannot be escrowed: all the moccasins would take the pair off his feet.
	var w := store_evening()
	var o3 := w.open_trade(SOLDIER)
	var all_moc := stack_count(w, "item.cloth.moccasins")
	var r := w.trade_lines(str(o3.tr), [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": all_moc}])
	ok(not bool(r.ok) and str(r.get("reason", "")).contains("take it off first"), "the pair on his feet stays on (%s)" % str(r.get("reason", "")))
	ok(w.state.worn.has("item.cloth.moccasins"), "still worn")
	SurvivalTrade.cancel(w, str(o3.tr))
	# A save to a resource cancels open windows too.
	var sv := store_evening()
	var o4 := sv.open_trade(SOLDIER)
	sv.trade_lines(str(o4.tr), [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": 1.0}])
	var path := "user://test_fix1_state.res"
	SurvivalSave.save_resource(sv, path)
	ok(SurvivalTrade.session(sv, str(o4.tr)).is_empty(), "save_resource closes open windows")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# A persistent-world save keeps the window with its escrow.
	var pw := store_evening()
	var o5 := pw.open_trade(SOLDIER)
	pw.trade_lines(str(o5.tr), [{"kind": "item", "item_id": "item.cloth.moccasins", "qty": 1.0}])
	var doc := SurvivalSave.to_document(pw, {"keep_trades": true})
	ok(not SurvivalUtil.dict(SurvivalUtil.dict(doc.state.world.get("trade")).get("sessions")).is_empty(), "keep_trades saves the open window")
	var l := SurvivalSave.from_document(doc)
	var ls := SurvivalTrade.session(l, str(o5.tr))
	ok(str(ls.get("state", "")) == "open" and not SurvivalUtil.arr(SurvivalUtil.dict(ls.escrow).get("pl.1", {}).get("stacks")).is_empty(), "loaded with its escrow")
	# The day turning closes a window.
	var nd := mk(HUNTER, {"start_day": "dec_early", "start_hour": 20.9})
	nd.go_to(STORE)
	var o6 := nd.open_trade(SOLDIER)
	if bool(o6.get("ok", false)):
		sustain(nd)
		nd.advance(200.0)
		ok(SurvivalTrade.session(nd, str(o6.tr)).is_empty(), "the soldiers leave and the day turns: closed")


## First refusal and favours are real obligations; guide lines wait for M4; promised coin counts as coin spent.
func test_asks_and_services() -> void:
	var r := hut_evening(RANGER)
	var ft := SurvivalTrade.lesson_trade(r, OLD_HUNTER, "trap.snare_set", {"favour": true})
	ok(bool(ft.get("ok", false)), "a favour agrees a lesson: %s" % str(ft.get("reason", "")))
	var fav := {}
	for ob in r.obligations(true):
		if str(ob.kind) == "labour":
			fav = ob
	ok(not fav.is_empty() and is_equal_approx(float(fav.what.hours), 2.0), "a favour is two hours of his chores (%s)" % str(fav))
	var c := store_evening()
	var o := c.open_trade(SOLDIER)
	var g := c.trade_lines(str(o.tr), [{"kind": "service", "service": "guide", "terms": {"days": 1}}])
	ok(not bool(g.ok), "a guide line is not live before M4 (%s)" % str(g.get("reason", "")))
	SurvivalTrade.cancel(c, str(o.tr))
	var p := mk(HUNTER, {"start_day": "dec_early", "start_hour": 12.0})
	p.go_to(STORE)
	var ob_id := SurvivalTrade.add_obligation(p, "pl.1", "npc.fort.sutler", "promise", {"owes": {"pence": 10}, "due": {"days": 3}})
	var spent0 := SurvivalUtil.num(p.state.stats.get("coin_spent"), 0.0)
	var dl := SurvivalTrade.deliver(p, ob_id)
	ok(bool(dl.ok), "promised coin delivered: %s" % str(dl.get("reason", "")))
	near(SurvivalUtil.num(p.state.stats.get("coin_spent"), 0.0), spent0 + 10.0, 0.0001, "promised coin paid out is coin spent")
	# First refusal: owed to the trader until a pelt is brought to him (unit check of the obligation's rule).
	var t := mk(HUNTER, {"start_day": "sep_mid", "start_hour": 11.0})
	t.go_to(STORE)
	var fr := SurvivalTrade.add_obligation(t, "pl.1", "npc.post.trader", "first_refusal", {"terms": {"what": "first refusal on prime pelts"}, "due": {"days": 12}})
	ok(not bool(SurvivalLearning.ask_ok(t, "npc.post.trader", {"first_refusal": true}).ok), "one first refusal at a time")
	if SurvivalTrade.partner_present(t, "npc.post.trader"):
		SurvivalInventory.add(t, "item.pelt.fox", 1.0, {"grade": "good", "prime": 1.0, "condition": 1.0, "dried": true, "species": "fox"})
		var br := t.barter("npc.post.trader", [["item.pelt.fox", 1.0]], [["item.ammo.ball", 5.0]])
		ok(bool(br.get("ok", false)), "a fox pelt to the trader: %s" % str(br.get("reason", "")))
		ok(str(SurvivalTrade.obligation(t, fr).status) == "kept", "first refusal kept by bringing him the pelt")


## A curing buckskin never goes into a cache; whole things are lost whole.
func test_cache_rules() -> void:
	var c := mk()
	var cid := SurvivalCamp.create_cache(c, CAMP, "hung", "fair")
	SurvivalInventory.add(c, "item.skin.dressed_buckskin", 1.0, {"curing": true, "cure_until": c.state.minutes + 1440.0})
	near(SurvivalCamp.cache_store(c, cid, "item.skin.dressed_buckskin", 1.0), 0.0, 0.0001, "a curing buckskin stays in the pack")
	ok(c.state.worn.has("item.cloth.mitts"), "the hunter wears his mitts")
	near(SurvivalCamp.cache_store(c, cid, "item.cloth.mitts", 1.0), 0.0, 0.0001, "and a worn pair is never cached")
	SurvivalInventory.add(c, "item.pelt.raccoon", 6.0, {"grade": "good", "dried": true, "species": "raccoon"})
	SurvivalCamp.cache_store(c, cid, "item.pelt.raccoon", 6.0)
	for i in 30:
		SurvivalCamp.tick_caches(c)
	var left := 0.0
	for st in SurvivalCamp.cache_at(c, CAMP).items:
		if str(st.id) == "item.pelt.raccoon":
			left += float(st.qty)
	ok(is_equal_approx(left, roundf(left)), "pelts are lost whole (%.3f left)" % left)
	ok(not SurvivalCamp.cache_panel(c).is_empty(), "the cache panel lists what hangs there")


## The carry rule counts what a player gives: a trade that lightens an overloaded pack is allowed.
func test_carry_rule() -> void:
	var c := store_evening()
	SurvivalTrade.add_guest_player(c, "pl.2", {"location": STORE, "items": [["item.food.cornmeal", 5.0]]})
	SurvivalInventory.add(c, "item.ammo.lead", 150.0)
	ok(SurvivalInventory.weight_kg(c) > 60.0, "overloaded (%.0f kg)" % SurvivalInventory.weight_kg(c))
	var o := SurvivalTrade.open(c, "pl.1", "pl.2")
	SurvivalTrade.set_lines(c, str(o.tr), "pl.1", [{"kind": "item", "item_id": "item.ammo.lead", "qty": 60.0}])
	SurvivalTrade.set_lines(c, str(o.tr), "pl.2", [{"kind": "item", "item_id": "item.food.cornmeal", "qty": 2.0}])
	real_wait(c)
	var v := int(SurvivalTrade.session(c, str(o.tr)).version)
	SurvivalTrade.confirm(c, str(o.tr), "pl.2", v)
	var r := SurvivalTrade.confirm(c, str(o.tr), "pl.1", v)
	ok(bool(r.get("committed", false)), "giving 27 kg of lead for 1 kg of meal lightens the pack: allowed (%s)" % str(r.get("reason", "")))


## A real version-1 save, written by the archived v3 code (tests/survival/fixtures/v3_save_hunter.json: the backcountry
## hunter on the old trapper path in Late November 1765, 1,152 d on the trader's book, 15 traps set).
func test_v3_save_fixture() -> void:
	var l := SurvivalSave.load_file("res://tests/survival/fixtures/v3_save_hunter.json")
	ok(l != null, "the v3 save loads")
	if l == null:
		return
	for kid in ["trap.steel_land_set", "trap.snare_set", "rcp.moccasins", "know.hide_dressing", "rcp.jerky", "preserve.cache_pit", "rcp.rawhide", "rcp.mitts_fur"]:
		ok(SurvivalLearning.rank(SurvivalLearning.state_of(l, kid)) >= SurvivalLearning.rank("known"), "migrated: %s known (%s)" % [kid, SurvivalLearning.state_of(l, kid)])
	ok(SurvivalLearning.state_of(l, "know.snowshoes") == "heard_of", "and the background's heard-of entries")
	var pv := l.preview("trap.steel_land_set")
	var knows := true
	for why in SurvivalUtil.arr(pv.get("reasons")):
		if str(why).contains("do not know"):
			knows = false
	ok(knows, "a v3 trapper can still set his steel traps (%s)" % str(pv.get("reasons", [])))
	var credit := {}
	for ob in l.obligations(true):
		if str(ob.kind) == "credit":
			credit = ob
	ok(not credit.is_empty() and is_equal_approx(float(credit.what.balance_d), SurvivalEconomy.balance(l, "npc.post.trader")), "the trader's book is on the ledger at once (%s)" % str(credit))
	var no_uid := 0
	for st in l.state.inventory:
		if str(st.get("uid", "")) == "":
			no_uid += 1
	ok(no_uid == 0, "every migrated stack has a uid")
	ok(l.has_habit("habit.line_hand"), "the perk became the habit")
	sustain(l)
	l.advance(1440.0)
	ok(not l.is_dead(), "the migrated game plays on")


## JSON saves carry a bit-exact copy: a game saved and loaded is the same state to the last bit.
func test_save_is_bit_exact() -> void:
	var c := mk(HUNTER, {"start_day": "nov_early", "start_hour": 9.0})
	c.go_to(CAMP)
	for i in 6:
		sustain(c)
		c.run_job("fire.gather")
		c.advance(137.3)
	var txt := SurvivalSave.to_json(c)
	var l := SurvivalSave.from_json(txt)
	ok(var_to_bytes(l.to_dict()) == var_to_bytes(c.to_dict()), "the loaded state is bit-identical")
	var doc = JSON.parse_string(txt)
	doc.erase("state_bin")
	ok(SurvivalSave.from_document(doc) != null, "a document without the binary copy still loads from its text")


## Made garments go on when their slot is empty; deerskin makes mittens; the eat prompt shows the food's weight.
func test_made_clothing_goes_on() -> void:
	var r := mk(RANGER)
	ok(not r.state.worn.has("item.cloth.mitts"), "the ranger starts without mitts")
	SurvivalLearning.set_state(r, "rcp.mitts_fur", "known", "test", "", true)
	SurvivalInventory.add(r, "item.skin.deer_fall", 1.0, {"grade": "good", "dried": true})
	SurvivalInventory.add(r, "item.material.sinew", 1.0)
	var res := SurvivalCrafting.apply(r, "rcp.mitts_fur", "success")
	ok(bool(res.ok) and SurvivalInventory.has(r, "item.cloth.mitts"), "a dried deerskin makes mittens (%s)" % str(res.get("consumed")))
	ok(r.state.worn.has("item.cloth.mitts"), "and they go on at once")
	var h := mk()
	SurvivalInventory.add(h, "item.pelt.fox", 1.0, {"grade": "good", "dried": true})
	SurvivalInventory.add(h, "item.material.sinew", 1.0)
	SurvivalCrafting.apply(h, "rcp.mitts_fur", "success")
	ok(h.state.worn.count("item.cloth.mitts") == 1, "a second pair is the spare, not worn over the first")
	ok(h.put_on("item.cloth.fur_cap") == false or h.state.worn.has("item.cloth.fur_cap"), "put_on answers")
	ok(SurvivalAlmanac.winter_ready_checks(r)[1] == true, "two carried pairs of moccasins are the spare pair")
	var pv := h.preview("eat")
	ok(pv.has("food_kg"), "the eat prompt shows the food's weight (%s)" % str(pv.get("food_kg", "")))


## Casting balls and hook-and-line fishing (live from fix round 1); a winter newcomer's kit.
func test_casting_fishing_and_season_kit() -> void:
	var h := mk(HUNTER, {"start_day": "oct_early", "start_hour": 10.0})
	h.go_to(CAMP)
	ok(SurvivalInventory.has(h, "item.tool.bullet_mould"), "the hunter carries his mould")
	var p0 := h.preview("craft.cast_balls", {"recipe": "rcp.cast_balls"})
	ok(not bool(p0.ok), "casting needs a lit fire (%s)" % str(p0.get("reasons", [])))
	SurvivalCamp.create_fire(h, CAMP, "lit", 120.0)
	var p1 := h.preview("craft.cast_balls", {"recipe": "rcp.cast_balls"})
	ok(bool(p1.ok), "at the fire he can cast (%s)" % str(p1.get("reasons", [])))
	var b0 := SurvivalInventory.count(h, "item.ammo.ball")
	var l0 := SurvivalInventory.count(h, "item.ammo.lead")
	SurvivalCrafting.apply(h, "rcp.cast_balls", "success")
	near(SurvivalInventory.count(h, "item.ammo.ball"), b0 + 16.0, 0.0001, "a pound of lead casts 16 balls")
	near(SurvivalInventory.count(h, "item.ammo.lead"), l0 - 1.0, 0.0001, "from his own bar lead")
	var may := mk(HUNTER, {"start_day": "may_early", "start_hour": 10.0})
	may.go_to("poi.fort.brook")
	var pf := may.preview("fish.hook_line")
	ok(bool(pf.ok), "hook and line in May's open water (%s)" % str(pf.get("reasons", [])))
	var jan := mk(HUNTER, {"start_day": "jan_mid", "start_hour": 10.0})
	jan.go_to("poi.fort.brook")
	ok(not bool(jan.preview("fish.hook_line").ok), "not through January's ice (that is fish.ice_hole)")
	var w := mk(RANGER, {"start_day": "dec_early"})
	ok(SurvivalInventory.has(w, "item.tool.hooks_line"), "a winter newcomer brings hooks and line")
	ok(SurvivalInventory.count(w, "item.food.cornmeal") >= 20.0 - 0.0001, "and provisions")
	var s := mk(RANGER, {"start_day": "sep_early"})
	ok(SurvivalInventory.count(s, "item.food.cornmeal") < 20.0 - 0.0001, "an autumn arrival brings no winter provisions")
	# Both backgrounds carry a line and hooks from fix round 1 (the ranger knows ice fishing), so the season kit's
	# hooks are added only when missing.
	ok(SurvivalInventory.count(w, "item.tool.hooks_line") <= 1.0 + 0.0001, "hooks and line only when missing")


## Board for work (economy.json service.board_for_labour): four hours' labour buy meals at the sutler in any month, with
## no coin (a no-money safety net; not hospitality, which in this design is a gift that cannot be farmed).
func test_board_for_labour() -> void:
	for day in ["oct_mid", "dec_early", "feb_mid", "apr_mid"]:
		var c := mk(RANGER, {"start_day": day, "start_hour": 11.0})
		c.go_to(STORE)
		c.state.economy["money_d"] = 0
		var r := c.barter("npc.fort.sutler", [["labour", 4.0, "job.sutler_wood"]], [["item.food.cornmeal", 8.0]])
		ok(bool(r.get("ok", false)), "%s: four hours' labour buy 8 lb of cornmeal (3 meals) at the sutler's: %s" % [day, str(r.get("reason", ""))])


## Trade grows on one scale for sales and barter, capped per partner a day; haggling is a check that teaches.
func test_trade_growth_one_scale() -> void:
	var a := mk(HUNTER, {"start_day": "dec_early", "start_hour": 12.0})
	var t0 := SurvivalSkills.level(a, "trade")
	SurvivalSkills.record_trade(a, 60.0, false, "npc.fort.sutler")
	var one := SurvivalSkills.level(a, "trade") - t0
	ok(one > 0.3, "60 d of rv traded teaches Trade (%.2f)" % one)
	var t1 := SurvivalSkills.level(a, "trade")
	SurvivalSkills.record_trade(a, 300.0, false, "npc.fort.sutler")
	SurvivalSkills.record_trade(a, 300.0, false, "npc.fort.sutler")
	var capped := SurvivalSkills.level(a, "trade") - t1
	ok(capped < 0.4 * 3.0 * 1.0 + 0.0001, "at most 3 base xp from one partner a day (%.2f more)" % capped)
	ok(float(a.data.action("trade.haggle").get("base_xp", 0.0)) >= 2.0 and not SurvivalUtil.arr(a.data.growth_model().get("no_xp_actions")).has("trade.haggle"), "haggling is a Trade check that teaches")
	# A sale and a barter of the same goods teach the same.
	var s := mk(HUNTER, {"start_day": "dec_early", "start_hour": 12.0})
	s.go_to(STORE)
	SurvivalInventory.add(s, "item.pelt.fox", 1.0, {"grade": "good", "prime": 1.0, "condition": 1.0, "dried": true, "species": "fox"})
	var ts0 := SurvivalSkills.level(s, "trade")
	SurvivalEconomy.sell(s, "mkt.fort_sutler", "item.pelt.fox", 1.0, "coin")
	var sold := SurvivalSkills.level(s, "trade") - ts0
	var b := mk(HUNTER, {"start_day": "dec_early", "start_hour": 12.0})
	var tb0 := SurvivalSkills.level(b, "trade")
	SurvivalSkills.record_trade(b, SurvivalTrade.rv(b, "item.pelt.fox"), false, "npc.fort.soldier_1")
	near(sold, SurvivalSkills.level(b, "trade") - tb0, 0.0001, "a sale counts the rv sold, as a barter counts the rv given")
