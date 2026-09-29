extends SceneTree
## Balance gate over many seeds: the survival chain, the conditions and the credit year behave as the GDD intends when
## the slice is played carefully, and carelessness is punished in every season. It uses the balance harness
## (scripts/survival/sim/survival_sim_balance.gd: the base harness plus a careful cook) and checks rates over seeds rather
## than single seeds, so a change that only reshuffles the random trajectory does not flip it.
##
##   Godot --headless --path . -s tests/survival/test_survival_balance.gd
##
## The numbers behind the thresholds, and the scenario matrix they come from (both backgrounds, four season starts,
## careful and careless play, three presets), are in
## source/graph_analysis/survival/survival_balance_report.md. To rerun the matrix:
##   Godot --headless --path . -s tests/survival/run_balance_matrix.gd -- --bg bg.backcountry_hunter,bg.provincial_ranger \
##         --starts sep_early,dec_early,mar_early,jun_early --policies trapper,hunter,woodcutter,idle,careless --seeds 1,2,3,4

const SIM := preload("res://scripts/survival/sim/survival_sim_balance.gd")
const BGS := ["bg.backcountry_hunter", "bg.provincial_ranger"]
const SLICE_DAYS := 26
const SEEDS := [1, 2, 3, 4, 5, 6]

var failures := PackedStringArray()
var passes := 0
var notes := PackedStringArray()


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	_careful_credit_year()
	_careless_by_season()
	_winter_start()
	_settler_preset()
	_cut_rules()
	print("")
	for n in notes:
		print("  " + n)
	print("survival balance: %d checks passed, %d failed (%d ms)" % [passes, failures.size(), Time.get_ticks_msec() - t0])
	for f in failures:
		printerr("  FAIL " + f)
	quit(1 if not failures.is_empty() else 0)


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		failures.append(what)


func run(o: Dictionary) -> Dictionary:
	var sim = SIM.new()
	sim.setup(o)
	sim.simulate(int(o.get("days", SLICE_DAYS)))
	var rep: Dictionary = sim.report()
	var cut_days := 0
	for r in SurvivalUtil.arr(rep.day_rows):
		for c in SurvivalUtil.arr(r.conditions):
			if str(c).begins_with("injury.cut:"):
				cut_days += 1
	rep["cut_frac"] = float(cut_days) / maxf(1.0, float(rep.days))
	return rep


func _h(rep: Dictionary, key: String, stages: Array) -> float:
	var t := 0.0
	for s in stages:
		t += SurvivalUtil.num(SurvivalUtil.dict(rep.get(key)).get(s), 0.0)
	return t


func _rate(rep: Dictionary, action: String) -> Array:
	var row := SurvivalUtil.dict(SurvivalUtil.dict(rep.checks).get(action))
	return [int(SurvivalUtil.num(row.get("n"), 0.0)), SurvivalUtil.num(row.get("success_rate"), 0.0)]


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


## The spike of the slice: the trap line on credit, Early September to the close of the spring settlement, for both
## backgrounds over six seeds each.
func _careful_credit_year() -> void:
	var n := 0
	var dead := 0
	var paid := 0
	var hypo := 0
	var fur := []
	var cut := 0.0
	var fire_n := 0
	var fire_ok := 0.0
	var skin_n := 0
	var skin_ok := 0.0
	var gain := 0.0
	for bg in BGS:
		for s in SEEDS:
			var rep := run({"background": bg, "policy": "trapper", "days": SLICE_DAYS, "seed": s})
			n += 1
			if bool(rep.died):
				dead += 1
			# v4: each background's credit start variant has its own book (the hunter's trader outfit, the ranger's
			# sutler tally); the test asks that the variant's book is paid in full.
			for g in SurvivalUtil.arr(rep.settlements):
				if str(g).ends_with(":paid_in_full"):
					paid += 1
					break
			if _h(rep, "cold_stage_h", ["hypothermic", "freezing"]) > 0.0:
				hypo += 1
			fur.append(float(rep.income_ce_per_trapping_day))
			cut += float(rep.cut_frac)
			var fr := _rate(rep, "fire.strike_flint_steel")
			fire_n += int(fr[0])
			fire_ok += float(fr[0]) * float(fr[1])
			var sr := _rate(rep, "fur.skin")
			skin_n += int(sr[0])
			skin_ok += float(sr[0]) * float(sr[1])
			gain += float(rep.skills_end.survival) - float(rep.skills_start.survival)
	var fire := fire_ok / maxf(1.0, float(fire_n))
	var skin := skin_ok / maxf(1.0, float(skin_n))
	ok(dead <= 1, "careful trappers survive the slice (%d of %d died)" % [dead, n])
	ok(paid >= n - 2, "careful trappers pay the trader's book in full (%d of %d)" % [paid, n])
	ok(hypo <= 2, "a fire and a lean-to keep careful trappers out of hypothermia (%d of %d runs touched it)" % [hypo, n])
	var med := _median(fur)
	ok(med >= 55.0 and med <= 150.0, "fur income %.0f cash-equivalent d a trapping-season day (design: 74 at 12 traps, 117 at 24)" % med)
	ok(cut / float(n) < 0.6, "a cut is an episode, not a standing condition (present at %.0f%% of dusks)" % (100.0 * cut / float(n)))
	# The season's average includes punk and fungus (D 30) once the ten pieces of char cloth are gone.
	ok(fire >= 0.45, "fire-making succeeds at %.2f over the season" % fire)
	ok(skin >= 0.55, "skinning succeeds at %.2f over the season" % skin)
	ok(gain / float(n) >= 6.0, "Survival grows with use (+%.1f over the slice)" % (gain / float(n)))
	notes.append("credit year, %d runs: died %d, trader paid %d, hypothermic runs %d, fur %.0f ce/day (median), cut at %.0f%% of dusks, fire %.2f, skinning %.2f, Survival +%.1f" % [
			n, dead, paid, hypo, med, 100.0 * cut / float(n), fire, skin, gain / float(n)])


## Carelessness (no fire, no shelter, eating only when starving) kills in the winter: the cold. Hunger kills nobody and
## no longer makes the cold worse (user 2026-09-27: "starvation shouldn't be a thing", and hunger has no bodily effects),
## so a careless June or September is a hungry one, and only sometimes a cold death.
func _careless_by_season() -> void:
	for bg in BGS:
		for start in ["dec_early", "sep_early", "jun_early"]:
			var died := 0
			var days := []
			var causes := {}
			for s in [1, 2]:
				var rep := run({"background": bg, "policy": "careless", "days": 10, "seed": s, "start_day": start})
				if bool(rep.died):
					died += 1
					days.append(int(rep.days))
					causes[str(rep.death_cause)] = int(causes.get(str(rep.death_cause), 0)) + 1
			if start != "dec_early":
				ok(not causes.has("starvation"), "%s, careless from %s: hunger kills nobody (%d of 2 died: %s)" % [bg, start, died, str(causes)])
			else:
				ok(died == 2, "%s, careless from %s: dies within 10 game days (%d of 2)" % [bg, start, died])
			if start == "dec_early":
				ok(int(causes.get("cold", 0)) >= 1, "%s, careless in December: the cold kills first (%s)" % [bg, str(causes)])
			notes.append("careless %s from %s: died %d of 2 after %s days, %s" % [bg.trim_prefix("bg."), start, died, str(days), str(causes)])
	# The same December nights with a fire and a lean-to are safe.
	var careful := run({"background": "bg.backcountry_hunter", "policy": "idle", "days": 3, "seed": 3, "start_day": "dec_early"})
	ok(_h(careful, "cold_stage_h", ["very_cold", "hypothermic", "freezing"]) < 1.0, "a fire and a lean-to keep the December nights safe")


## A winter start: the trapper takes up the line in December and still closes the spring settlement (Early December to
## Early June). Over WINTER_SEEDS, at least half pay the book (the bar of "one of two seeds" it had, measured on more
## runs: with two seeds the check turned on which way their catches fell; once the core fed a fire from its stack, the
## hunter's seeds 2 and 3 both fell short while the rate stayed 6 of 8 over seeds 1-8, as before the fix).
const WINTER_SEEDS := [1, 2, 3, 4, 5, 6]


func _winter_start() -> void:
	for bg in BGS:
		var alive := 0
		var paid := 0
		var grades := []
		for s in WINTER_SEEDS:
			var rep := run({"background": bg, "policy": "trapper", "days": 18, "seed": s, "start_day": "dec_early"})
			if not bool(rep.died):
				alive += 1
			# v4: each background's credit start variant has its own book (the hunter's trader outfit, the ranger's
			# sutler tally); the test asks that the variant's book is paid in full.
			for g in SurvivalUtil.arr(rep.settlements):
				if str(g).ends_with(":paid_in_full"):
					paid += 1
					break
			grades.append(rep.settlements)
		ok(alive == WINTER_SEEDS.size(), "%s, trapper from Early December: survives the winter and the spring (%d of %d)" % [bg, alive, WINTER_SEEDS.size()])
		ok(paid * 2 >= WINTER_SEEDS.size(), "%s, trapper from Early December: the book can still be paid in the spring window (%d of %d)" % [bg, paid, WINTER_SEEDS.size()])
		notes.append("from December, %s: settlements %s" % [bg.trim_prefix("bg."), str(grades)])


## Settler (needs x0.6) is the gentle preset: careful play never starves or freezes.
func _settler_preset() -> void:
	for bg in BGS:
		var rep := run({"background": bg, "policy": "trapper", "days": SLICE_DAYS, "seed": 1, "preset": "settler"})
		ok(not bool(rep.died) and _h(rep, "food_stage_h", ["wasting"]) == 0.0, "%s on Settler: a careful trapper never wastes" % bg)


## conditions.json cond.injury.cut: the full zone penalty while bleeding, half once bound, healed in 1.5-2 game days.
func _cut_rules() -> void:
	var core := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 5})
	for id in core.state.conditions.keys().duplicate():
		if str(id).begins_with("cond.injury"):
			core.state.conditions.erase(id)
	core.invalidate_modifiers()
	SurvivalConditions.add(core, "cond.injury.cut", {"zone": "hand"})
	core.invalidate_modifiers()
	var bleeding := SurvivalUtil.num(core.get_modifiers().get("fine_work_mod"), 0.0)
	var heal_h := SurvivalUtil.num(SurvivalUtil.dict(core.state.conditions.get("cond.injury.cut")).get("heal_h"), 0.0)
	ok(bleeding <= -0.2 + 0.0001, "a bleeding hand cut: fine work %.2f" % bleeding)
	ok(heal_h >= 36.0 - 0.001 and heal_h <= 48.0 + 0.001, "a cut heals in 1.5-2 game days (%.1f game h)" % heal_h)
	# Bind it as physick.bind_wound does, then read the bound stage.
	core.state.conditions["cond.injury.cut"]["stage"] = "bound"
	core.invalidate_modifiers()
	var bound := SurvivalUtil.num(core.get_modifiers().get("fine_work_mod"), 0.0)
	ok(bound > bleeding + 0.05 and bound <= -0.05, "once bound the hand is stiff, not useless: fine work %.2f" % bound)
