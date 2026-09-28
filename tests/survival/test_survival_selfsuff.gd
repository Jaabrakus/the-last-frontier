extends SceneTree
## The M2a gate (survival_gdd.md section 18.2): self-sufficiency first, barter optional, credit a choice. It plays the
## v4 harness policies over seeds for both slice backgrounds (Early September 1765 to Late May 1766, Woodsman) and
## measures the gate's targets as rates over the pooled seasons, and it checks the barter valuation's static targets
## (T6, T11) against the live data.
##
##   Godot --headless --path . -s tests/survival/test_survival_selfsuff.gd [-- --seeds 1,2,3,4,5,6 --strict --quick]
##
## Two kinds of checks:
##   - invariants (always fail the run): the no-money policies never spend coin (in the slice, the full year and every
##     start date); nobody gains more than 10 points in a game day; the barterer trades and the apprentice takes
##     lessons; at least 80% of careful no-money seasons are survived (a regression floor under T1's 95%); T6 and T11
##     hold at every tested day and partner, and a wanted good in season returns more than its rv at the partner who
##     wants it.
##   - gate targets T1-T5, T8, T9, T12 and, from fix round 1, T1y (the full game year), T1s (every start date the game
##     offers), T9t (Trade pace) and T9p (the first year's pacing), reported MET or UNMET; they fail the run only with
##     --strict, because the gate is a milestone to reach, not a regression test. On fewer than 40 seasons a background
##     a survival rate is marked provisional (the balance matrix, redesign_balance_review/, runs 40). T7 is static
##     (test_survival_data.gd); T10 is not measured by the harness yet (its day plan fills whatever time is left).
##   --quick skips the full-year and start-date runs (the slice only).
##
## The per-run numbers come from tests/survival/run_v4_matrix.gd (run_one/summarize), which prints the same lines.

const MATRIX := preload("res://tests/survival/run_v4_matrix.gd")
const BGS := ["bg.backcountry_hunter", "bg.provincial_ranger"]
const NO_COIN := ["self_sufficient", "barterer", "apprentice"]
## Day indexes from Early September (0): Late November is 8, Early January 12.
const LATE_NOV := 8
const EARLY_JAN := 12
## The full game year (Early September to Late August) and the other start dates a character can join on (a
## persistent world lets people join in any season), each run to Late May or for 26 game days (fix round 1, F2 and F3).
const YEAR_DAYS := 36
const START_DATES := [["oct_early", 23], ["dec_early", 17], ["mar_early", 26], ["jun_early", 26]]
const CHECK_NAMES := ["shelter 4", "spare moccasins", "mitts and cap", "20 meals", "hung cache", "6 cordage", "snowshoes"]

var failures := PackedStringArray()
var unmet := PackedStringArray()
var passes := 0
var notes := PackedStringArray()


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var seeds := [1, 2, 3, 4, 5, 6]
	var strict := false
	var quick := false
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if str(args[i]) == "--seeds" and i + 1 < args.size():
			seeds = []
			for s in str(args[i + 1]).split(","):
				seeds.append(s.to_int())
			i += 1
		elif str(args[i]) == "--strict":
			strict = true
		elif str(args[i]) == "--quick":
			quick = true
		i += 1
	_static_trade_targets()
	var rows := {}
	for bg in BGS:
		for pol in ["self_sufficient", "barterer", "apprentice", "trapper"]:
			var key: String = bg + "|" + pol
			rows[key] = []
			for sd in seeds:
				var r := MATRIX.run_one({"background": bg, "policy": pol, "days": 26, "seed": sd, "start_day": "sep_early", "preset": "woodsman"})
				rows[key].append(r)
				print(MATRIX.line_for(r))
	_gate(rows, seeds.size())
	if not quick:
		# The full game year (T1y, T9t, T9p) and the other start dates (T1s).
		var year := {}
		for bg in BGS:
			for pol in ["self_sufficient", "barterer", "apprentice"]:
				year[bg + "|" + pol] = []
				for sd in seeds:
					var r := MATRIX.run_one({"background": bg, "policy": pol, "days": YEAR_DAYS, "seed": sd, "start_day": "sep_early", "preset": "woodsman"})
					year[bg + "|" + pol].append(r)
					print("year  " + MATRIX.line_for(r))
		var starts := {}
		for pair in START_DATES:
			starts[str(pair[0])] = []
			for bg in BGS:
				for sd in seeds.slice(0, mini(3, seeds.size())):
					var r := MATRIX.run_one({"background": bg, "policy": "self_sufficient", "days": int(pair[1]), "seed": sd, "start_day": str(pair[0]), "preset": "woodsman"})
					starts[str(pair[0])].append(r)
					print("%-9s " % str(pair[0]) + MATRIX.line_for(r))
		_gate_year(year, starts)
	print("")
	for n in notes:
		print("  " + n)
	for u in unmet:
		print("  UNMET " + u)
	var fails := failures.size() + (unmet.size() if strict else 0)
	print("survival M2a gate: %d checks passed, %d invariant failures, %d gate targets unmet%s (%d ms)" % [passes, failures.size(),
			unmet.size(), " (strict)" if strict else "", Time.get_ticks_msec() - t0])
	for f in failures:
		printerr("  FAIL " + f)
	quit(1 if fails > 0 else 0)


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		failures.append(what)


func target(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		notes.append("MET   " + what)
	else:
		unmet.append(what)


func _frac(rows: Array, f: Callable) -> float:
	var n := 0
	for r in rows:
		if bool(f.call(r)):
			n += 1
	return float(n) / maxf(1.0, float(rows.size()))


func _median(vals: Array) -> float:
	if vals.is_empty():
		return -1.0
	var v := vals.duplicate()
	v.sort()
	return float(v[v.size() / 2]) if v.size() % 2 == 1 else (float(v[v.size() / 2 - 1]) + float(v[v.size() / 2])) / 2.0


func _mean(rows: Array, key: String) -> float:
	var t := 0.0
	for r in rows:
		t += float(r.get(key, 0.0))
	return t / maxf(1.0, float(rows.size()))


## A run's winter-ready day for the medians: never ready counts as the end of the slice (day 26).
func _ready_or_end(r: Dictionary) -> float:
	return float(r.ready_day) if int(r.ready_day) >= 0 else 26.0


func _gate(rows: Dictionary, n_seeds: int) -> void:
	var ss := []
	var bt := []
	for bg in BGS:
		ss.append_array(rows[bg + "|self_sufficient"])
		bt.append_array(rows[bg + "|barterer"])
	# Invariants.
	for bg in BGS:
		for pol in NO_COIN:
			for r in rows[bg + "|" + pol]:
				ok(float(r.coin_spent) == 0.0, "%s %s s%d spends no coin (spent %.0f)" % [bg, pol, int(r.seed), float(r.coin_spent)])
		for pol in ["self_sufficient", "barterer", "apprentice", "trapper"]:
			for r in rows[bg + "|" + pol]:
				ok(float(r.day_xp_max) <= 10.0001, "%s %s s%d: no game day above 10 points (%.2f)" % [bg, pol, int(r.seed), float(r.day_xp_max)])
		ok(_mean(rows[bg + "|barterer"], "trades") >= 5.0, "%s: the barterer trades (%.1f a season)" % [bg, _mean(rows[bg + "|barterer"], "trades")])
		ok(_mean(rows[bg + "|apprentice"], "lessons") >= 2.0, "%s: the apprentice takes lessons (%.1f a season)" % [bg, _mean(rows[bg + "|apprentice"], "lessons")])
	var surv := 1.0 - _frac(ss, func(r): return bool(r.died))
	ok(surv >= 0.8, "careful no-money seasons survived: %.0f%% (floor 80%%)" % (100.0 * surv))
	# T1: survive with no money.
	target(surv >= 0.95, "T1 survive with no money: %d of %d seasons (target 95%%, 38 of 40)%s" % [int(round(surv * ss.size())), ss.size(),
			_provisional(ss.size())])
	# T2: food security.
	var dusk := _frac(ss, func(r): return float(r.dusk_food_frac) >= 0.85)
	var starv := _frac(ss, func(r): return int(r.starving_days) > 0)
	var plain := _mean(ss, "plain_frac")
	var acorn := _mean(ss, "acorn_frac_of_plant")
	target(dusk >= 0.9 and starv == 0.0 and plain <= 0.4 and acorn <= 0.15,
			"T2 food: 6+ meals at 85%% of dusks in %.0f%% of seasons; Starving in %.0f%%; plain fare %.0f%% of days; acorn %.0f%% of plant food" % [100.0 * dusk, 100.0 * starv, 100.0 * plain, 100.0 * acorn])
	# T3: warmth.
	var cold := _mean(ss, "cold_h_winter")
	var cold_deaths := _frac(ss, func(r): return bool(r.died) and str(r.cause) in ["cold", "hypothermia"])
	target(cold <= 3.0 and cold_deaths == 0.0, "T3 warmth: %.1f game h at Cold or worse a winter (mean; target 3); cold deaths %.0f%%" % [cold, 100.0 * cold_deaths])
	# T4: winter-ready by Late November, snowshoes by Early January.
	var ready := _frac(ss, func(r): return int(r.ready_day) >= 0 and int(r.ready_day) <= LATE_NOV)
	var shoes := _frac(ss, func(r): return int(r.snowshoe_day) >= 0 and int(r.snowshoe_day) <= EARLY_JAN)
	target(ready >= 0.8 and shoes >= 0.8, "T4 winter-ready by Late November in %.0f%% of seasons; snowshoes by Early January in %.0f%%" % [100.0 * ready, 100.0 * shoes])
	var ready_any := []
	for r in ss:
		ready_any.append(_ready_or_end(r))
	notes.append("T4 detail: median winter-ready day %.0f (day 8 is Late November; 26 = never); at Late November %s" % [_median(ready_any), _checklist_rates(ss)])
	# T5: trade speeds things up but is not required.
	var ready_bt := []
	for r in bt:
		ready_bt.append(_ready_or_end(r))
	var m_ss := _median(ready_any)
	var m_bt := _median(ready_bt)
	var sooner := (m_ss - m_bt) / maxf(1.0, m_ss)
	var rv_ratio := _mean(bt, "rv_kit_end") / maxf(1.0, _mean(ss, "rv_kit_end"))
	var surv_bt := 1.0 - _frac(bt, func(r): return bool(r.died))
	# T5 restated in fix round 1 (redesign_balance_report.md F6): trade buys food security first, and must never cost
	# the player kit, readiness or survival. The barterer meets T2's food security; keeps at least the self-sufficient
	# player's kit and stores in rv; is winter-ready no later; and survives within 5 points (trade is never required).
	var dusk_bt := _frac(bt, func(r): return float(r.dusk_food_frac) >= 0.85)
	var starv_bt := _frac(bt, func(r): return int(r.starving_days) > 0)
	var plain_bt := _mean(bt, "plain_frac")
	target(dusk_bt >= 0.9 and starv_bt == 0.0 and plain_bt <= 0.4 and rv_ratio >= 1.0 and m_bt <= m_ss and absf(surv_bt - surv) <= 0.05,
			"T5 trade buys food security: the barterer is food-secure at dusk in %.0f%% of seasons, Starving in %.0f%%, plain fare %.0f%% of days; keeps %.2fx the kit rv (target 1.0x); winter-ready median day %.0f against %.0f; survives %+.0f points" % [
			100.0 * dusk_bt, 100.0 * starv_bt, 100.0 * plain_bt, rv_ratio, m_bt, m_ss, 100.0 * (surv_bt - surv)])
	var rv_all := (_mean(bt, "rv_kit_end") + _mean(bt, "rv_furs_end")) / maxf(1.0, _mean(ss, "rv_kit_end") + _mean(ss, "rv_furs_end"))
	notes.append("T5 detail (v4's first statement): winter-ready %.0f%% sooner (was 20-40%%), kit rv %.2fx (was 1.3x), kit and furs %.2fx" % [100.0 * sooner, rv_ratio, rv_all])
	# T8: credit is a choice (the trapper plays each background's credit start).
	var tr := []
	for bg in BGS:
		tr.append_array(rows[bg + "|trapper"])
	var rv8 := _mean(tr, "rv_kit_end") / maxf(1.0, _mean(ss, "rv_kit_end"))
	var surv_tr := 1.0 - _frac(tr, func(r): return bool(r.died))
	target(rv8 >= 1.4 and surv_tr <= surv + 0.0001, "T8 the credit start keeps %.2fx the self-sufficient rv (target 1.4x); careful survival %.0f%% vs %.0f%%" % [rv8, 100.0 * surv_tr, 100.0 * surv])
	# T9: growth from variety (the hunter).
	var hunter: Array = rows["bg.backcountry_hunter|self_sufficient"]
	var jour := _frac(hunter, func(r): return true)
	var g := {}
	for k in MATRIX.WORKING:
		var t := 0.0
		for r in hunter:
			t += float(r.gains[k])
		g[k] = t / maxf(1.0, float(hunter.size()))
	var starts := {"survival": 32.0, "hunting": 30.0, "trapping": 28.0}
	var reach := true
	for k in starts.keys():
		if float(starts[k]) + float(g[k]) < 40.0:
			reach = false
	target(reach and float(g.hidecraft) >= 15.0 and float(g.provisions) >= 8.0 and float(g.woodcraft) >= 8.0,
			"T9 the hunter's season: Survival +%.1f, Hunting +%.1f, Trapping +%.1f (Journeyman 40 wanted from 32/30/28); Hide +%.1f (15), Provisions +%.1f (8), Woodcraft +%.1f (8)" % [
			float(g.survival), float(g.hunting), float(g.trapping), float(g.hidecraft), float(g.provisions), float(g.woodcraft)])
	# T12: carry.
	var kg90 := []
	for r in ss:
		kg90.append(float(r.kg_p90))
	target(_median(kg90) <= 30.0, "T12 the pack at dusk: median of the seasons' 90th-percentile %.1f kg (target under 30; worn clothes and the long arm excluded)" % _median(kg90))
	notes.append("seasons per policy: %d seeds x %d backgrounds" % [n_seeds, BGS.size()])


## " (provisional: n seasons ...)" below 40 seasons a background (80 pooled).
func _provisional(n: int) -> String:
	return "" if n >= 80 else " (provisional: %d seasons; the target names 40 a background, measured by the balance matrix)" % n


## The Late November checklist, item by item: the share of seasons that had it.
func _checklist_rates(rows: Array) -> String:
	var parts := []
	for k in CHECK_NAMES.size():
		var n := 0
		for r in rows:
			var c := SurvivalUtil.arr(r.get("late_nov_checks"))
			if c.size() > k and bool(c[k]):
				n += 1
		parts.append("%s %.0f%%" % [CHECK_NAMES[k], 100.0 * float(n) / maxf(1.0, float(rows.size()))])
	return ", ".join(PackedStringArray(parts))


## The full game year and the other start dates (fix round 1): T1y, T1s, T9t, T9p.
func _gate_year(year: Dictionary, starts: Dictionary) -> void:
	var ss := []
	for bg in BGS:
		ss.append_array(year[bg + "|self_sufficient"])
	for key in year.keys():
		if str(key).ends_with("|trapper"):
			continue
		for r in year[key]:
			ok(float(r.coin_spent) == 0.0, "year %s s%d spends no coin (spent %.0f)" % [key, int(r.seed), float(r.coin_spent)])
			ok(float(r.day_xp_max) <= 10.0001, "year %s s%d: no game day above 10 points (%.2f)" % [key, int(r.seed), float(r.day_xp_max)])
	var surv := 1.0 - _frac(ss, func(r): return bool(r.died))
	var starv := _frac(ss, func(r): return int(r.starving_days) > 0)
	target(surv >= 0.95, "T1y the full game year (Early September to Late August) with no money: %d of %d seasons survived, %.0f%% ever Starving%s" % [
			int(round(surv * ss.size())), ss.size(), 100.0 * starv, _provisional(ss.size())])
	# T1s: every start date the game offers, self-sufficient on the Clear start (with its season kit).
	var all_s := []
	var per := []
	for sd in starts.keys():
		var rs: Array = starts[sd]
		all_s.append_array(rs)
		for r in rs:
			ok(float(r.coin_spent) == 0.0, "start %s %s s%d spends no coin" % [sd, str(r.bg), int(r.seed)])
		per.append("%s %d/%d" % [sd, rs.size() - int(round(_frac(rs, func(r): return bool(r.died)) * rs.size())), rs.size()])
	var surv_s := 1.0 - _frac(all_s, func(r): return bool(r.died))
	target(surv_s >= 0.9, "T1s every start date, self-sufficient: %s survived (%.0f%%, target 90%%)%s" % [", ".join(PackedStringArray(per)), 100.0 * surv_s, _provisional(all_s.size())])
	# T9t: Trade pace. A barter-heavy player (the apprentice: trades, haggles, works for and learns from neighbours)
	# gains at least half the way to Journeyman in the first game year, so Journeyman comes within about two.
	var app := []
	var bar := []
	for bg in BGS:
		app.append_array(year[bg + "|apprentice"])
		bar.append_array(year[bg + "|barterer"])
	var half := true
	var parts := []
	for r in app:
		var t0 := SurvivalUtil.num(SurvivalUtil.dict(r.skills_start).get("trade"), 0.0)
		var t1 := SurvivalUtil.num(SurvivalUtil.dict(r.skills_end).get("trade"), 0.0)
		if t1 - t0 < (40.0 - t0) / 2.0:
			half = false
	var tr_app := 0.0
	var tr_bar := 0.0
	for r in app:
		tr_app += SurvivalUtil.num(SurvivalUtil.dict(r.skills_end).get("trade"), 0.0) / maxf(1.0, float(app.size()))
	for r in bar:
		tr_bar += SurvivalUtil.num(SurvivalUtil.dict(r.skills_end).get("trade"), 0.0) / maxf(1.0, float(bar.size()))
	target(half, "T9t Trade pace: the apprentice ends the first game year at Trade %.1f (every season at least half way to Journeyman from 5-6); the barterer at %.1f" % [tr_app, tr_bar])
	# T9p: the first year's pacing (GDD 7.8, restated per skill in fix round 1): Journeyman in Survival, Hunting and
	# Trapping and Fishing from either background by the year's end; Provisions at least 35 (Journeyman early in the
	# second year until the M3 Provisions work is live).
	var ok_all := true
	var lines := []
	for bg in BGS:
		var rs: Array = year[bg + "|self_sufficient"]
		var m := {}
		for k in ["survival", "hunting", "trapping", "provisions"]:
			var t := 0.0
			for r in rs:
				t += SurvivalUtil.num(SurvivalUtil.dict(r.skills_end).get(k), 0.0) / maxf(1.0, float(rs.size()))
			m[k] = t
		if float(m.survival) < 40.0 or float(m.hunting) < 40.0 or float(m.trapping) < 40.0 or float(m.provisions) < 35.0:
			ok_all = false
		lines.append("%s Survival %.1f, Hunting %.1f, Trapping %.1f, Provisions %.1f" % [str(bg).trim_prefix("bg."), float(m.survival), float(m.hunting), float(m.trapping), float(m.provisions)])
	target(ok_all, "T9p the first game year, self-sufficient: %s (Journeyman 40; Provisions 35)" % "; ".join(PackedStringArray(lines)))


# ---------------------------------------------------------------- T6 and T11 (static, against the valuation)
## What one unit of a stack brings back from a partner, in rv of the goods it offers most cheaply (0 when it will not
## take the good or has nothing to give).
func _return_rv(c: SurvivalCore, p: String, st: Dictionary) -> float:
	var ui := float(SurvivalTrade.unit_in(c, p, st).v)
	if ui <= 0.0:
		return 0.0
	var best_ratio := INF
	for g in c.data.goods.keys():
		var r := SurvivalTrade.rv(c, str(g))
		var u := SurvivalTrade.unit_out(c, p, str(g))
		if r > 0.0 and u > 0.0:
			best_ratio = minf(best_ratio, u / r)
	if best_ratio == INF:
		return 0.0
	return ui / SurvivalTrade.terms(c, p) / best_ratio


## A character at the best terms it can reach: Trade 100, the best standing everywhere.
func _best_core(day: String, hour: float) -> SurvivalCore:
	var c := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 7, "start_day": day, "start_hour": hour})
	SurvivalSkills.set_level(c, "trade", 100.0)
	for f in c.data.factions.keys():
		SurvivalEconomy.add_standing(c, str(f), 100.0, "test")
	return c


func _static_trade_targets() -> void:
	# T6: a wanted good in season returns 1.2-1.6x the coin route with the same partner.
	var c := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 7, "start_day": "dec_early", "start_hour": 19.5})
	c.go_to("poi.fort.sutler_store")
	var sol := "npc.fort.soldier_1"
	var moc := {"id": "item.cloth.moccasins", "qty": 1.0, "meta": {}}
	var vin := float(SurvivalTrade.unit_in(c, sol, moc).v)
	var tm := SurvivalTrade.terms(c, sol)
	var tb := SurvivalTrade.behaviour(c, sol)
	var take := "item.trade.tobacco"
	var goods_rv := vin / tm / maxf(0.01, SurvivalTrade.unit_out(c, sol, take, false)) * SurvivalTrade.rv(c, take)
	var coin := vin / (tm * SurvivalUtil.num(tb.get("coin_premium"), 1.0))
	var r6 := goods_rv / maxf(0.01, coin)
	ok(r6 >= 1.2 - 0.001 and r6 <= 1.6 + 0.001, "T6 moccasins to a soldier in December: goods return %.2fx the coin route (target 1.2-1.6)" % r6)
	# The best partner for a good returns at least 2x the worst that takes it. A return is what comes back, in rv: the
	# partner's value for the good, over its terms, taken in the goods it prices lowest against their rv.
	var vals := []
	for p in SurvivalTrade.partners(c):
		if not SurvivalTrade.present_today(c, str(p)):
			continue
		var ret := _return_rv(c, str(p), moc)
		if ret > 0.0:
			vals.append(snappedf(ret, 0.1))
	vals.sort()
	if vals.size() >= 2:
		ok(float(vals[vals.size() - 1]) >= 2.0 * float(vals[0]) - 0.001, "T6 the best partner for moccasins returns %.1f rv, the worst %.1f (target 2x)" % [float(vals[vals.size() - 1]), float(vals[0])])
	notes.append("T6: December moccasins to a soldier %.0f d (rv %.0f); goods %.2fx coin; partners' returns in rv %s" % [vin, SurvivalTrade.rv(c, "item.cloth.moccasins"), r6, str(vals)])
	# A wanted good in season comes back above its rv at the partner who wants it (fix round 1, F6).
	var ret_sol := _return_rv(c, sol, moc)
	ok(ret_sol > SurvivalTrade.rv(c, "item.cloth.moccasins"), "a wanted good in season returns above its rv: moccasins to a soldier in December return %.1f rv for an rv of %.0f" % [ret_sol, SurvivalTrade.rv(c, "item.cloth.moccasins")])
	for p in SurvivalTrade.partners(c):
		var u2 := float(SurvivalTrade.unit_in(c, str(p), {"id": "item.material.hide_scrap", "qty": 1.0, "meta": {}}).v)
		ok(u2 <= 0.8 * SurvivalTrade.rv(c, "item.material.hide_scrap") + 0.001, "T6 hide scraps (wanted by nobody) are worth at most 0.8 rv to %s (%.1f)" % [p, u2])
	# T11: buying from one partner and bartering it to another the same day returns at most 1.0 of the price paid,
	# at the best terms a character can reach (Trade 100, best standing, a full haggle).
	var worst := 0.0
	var worst_s := ""
	for day in ["sep_mid", "oct_mid", "nov_mid", "dec_early", "jan_mid", "feb_mid", "mar_mid", "apr_mid", "may_mid"]:
		var b := _best_core(day, 12.0)
		var ps := []
		for p in SurvivalTrade.partners(b):
			if SurvivalTrade.present_today(b, str(p)):
				ps.append(str(p))
		for g in b.data.goods.keys():
			var item := str(g)
			for seller in ps:
				var u_out := SurvivalTrade.unit_out(b, seller, item)
				if u_out <= 0.0:
					continue
				var paid := u_out * SurvivalTrade.terms(b, seller, 0.10)
				for buyer in ps:
					if buyer == seller:
						continue
					var ui := float(SurvivalTrade.unit_in(b, buyer, {"id": item, "qty": 1.0, "meta": {}}).v)
					if ui <= 0.0:
						continue
					var back := ui / maxf(0.01, SurvivalTrade.terms(b, buyer, 0.10))
					var ratio := back / maxf(0.01, paid)
					if ratio > worst:
						worst = ratio
						worst_s = "%s: %s from %s to %s" % [day, item, seller, buyer]
	ok(worst <= 1.0 + 0.001, "T11 arbitrage guard: the best same-day round trip returns %.2f of the price paid (%s)" % [worst, worst_s])
	notes.append("T11: best same-day round trip %.2f of the price paid (%s)" % [worst, worst_s])
