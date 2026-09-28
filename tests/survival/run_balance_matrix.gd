extends SceneTree
## Balance matrix: runs the simulation harness over many scenarios and writes one compact summary per run, so the
## survival chain, the conditions and the economy can be compared across backgrounds, season starts and careful or
## careless play (survival_gdd.md section 18, "telemetry for playtests"). By default it uses the balance harness
## (scripts/survival/sim/survival_sim_balance.gd: the base harness survival_sim.gd plus a careful cook); --base runs the
## base harness.
##
##   Godot --headless --path . -s tests/survival/run_balance_matrix.gd -- --bg bg.backcountry_hunter \
##         --starts sep_early,dec_early,mar_early,jun_early --policies trapper,careless --seeds 1,2,3 --days 36 \
##         --out /path/to/rows.jsonl
##   options: --bg a,b   --starts a,b   --policies a,b   --seeds 1,2   --days N   --preset woodsman   --backlog M3,M4
##            --line 16   --out file (JSON lines, appended)   --rows (keep the day rows in the output)
##            --data_dir /abs/path/ (trial a copy of the data: it stands in for res://data/survival/ in this process only)
##            --base (use the base harness SurvivalSim instead of the balance harness, which cooks raw meat first)
##
## It never changes game state outside the run and writes only the --out file. Findings from it are written up in
## Player_Animation_Project/graph_analysis/survival/survival_balance_report.md.

const SIM_BALANCE := preload("res://scripts/survival/sim/survival_sim_balance.gd")
const SEASON_OF := {"dec": "winter", "jan": "winter", "feb": "winter", "mar": "spring", "apr": "spring", "may": "spring",
		"jun": "summer", "jul": "summer", "aug": "summer", "sep": "autumn", "oct": "autumn", "nov": "autumn"}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var bgs := ["bg.backcountry_hunter"]
	var starts := ["sep_early"]
	var policies := ["trapper"]
	var seeds := [1]
	var days := 36
	var preset := "woodsman"
	var backlog := []
	var line := 16
	var out_path := ""
	var keep_rows := false
	var data_dir := ""
	var base := false
	var i := 0
	while i < args.size():
		var a := str(args[i])
		var v := str(args[i + 1]) if i + 1 < args.size() else ""
		match a:
			"--bg":
				bgs = Array(v.split(","))
				i += 1
			"--starts":
				starts = Array(v.split(","))
				i += 1
			"--policies":
				policies = Array(v.split(","))
				i += 1
			"--seeds":
				seeds = []
				for s in v.split(","):
					seeds.append(s.to_int())
				i += 1
			"--days":
				days = v.to_int()
				i += 1
			"--preset":
				preset = v
				i += 1
			"--backlog":
				backlog = Array(v.split(","))
				i += 1
			"--line":
				line = v.to_int()
				i += 1
			"--out":
				out_path = v
				i += 1
			"--rows":
				keep_rows = true
			"--data_dir":
				data_dir = v
				i += 1
			"--base":
				base = true
		i += 1
	if data_dir != "":
		# The harness loads the default directory; a trial copy is put in its place in the core's data cache.
		var key := SurvivalData.DEFAULT_DIR + "|" + ",".join(PackedStringArray(backlog))
		SurvivalCore._data_cache[key] = SurvivalData.load_dir(data_dir, {"backlog_milestones": backlog})
		if not SurvivalCore._data_cache[key].is_ok():
			printerr("data_dir %s: %s" % [data_dir, str(SurvivalCore._data_cache[key].errors)])
			quit(1)
			return
	var t_all := Time.get_ticks_msec()
	for bg in bgs:
		for st in starts:
			for pol in policies:
				for sd in seeds:
					var t0 := Time.get_ticks_msec()
					var o := {"background": bg, "policy": pol, "days": days, "seed": sd, "start_day": st, "preset": preset,
							"line_size": line}
					if not backlog.is_empty():
						o["backlog_milestones"] = backlog
					var sim: SurvivalSim = SurvivalSim.new() if base else SIM_BALANCE.new()
					sim.setup(o)
					sim.simulate(days)
					var rep := sim.report()
					var row := summarize(sim, rep, keep_rows)
					row["ms"] = Time.get_ticks_msec() - t0
					row["preset"] = preset
					row["backlog"] = backlog
					row["data_dir"] = data_dir
					row["harness"] = "base" if base else "balance"
					print(line_for(row))
					if out_path != "":
						var f := FileAccess.open(out_path, FileAccess.READ_WRITE if FileAccess.file_exists(out_path) else FileAccess.WRITE)
						if f != null:
							f.seek_end()
							f.store_line(JSON.stringify(row))
							f.close()
	print("matrix done (%d ms)" % (Time.get_ticks_msec() - t_all))
	quit(0)


## The run's numbers that matter for balance, grouped by the season each game day fell in.
func summarize(sim: SurvivalSim, rep: Dictionary, keep_rows: bool) -> Dictionary:
	var st: Dictionary = sim.core.state.stats
	var conds := {}
	for k in st.keys():
		if str(k).begins_with("cond_"):
			conds[str(k).trim_prefix("cond_")] = int(st[k])
	var by_season := {}
	var cond_days := {}
	var hungry_dusk := 0
	var min_meals := 999.0
	var death_day := -1
	for r in SurvivalUtil.arr(rep.day_rows):
		var season := str(SEASON_OF.get(str(r.month), "?"))
		if not by_season.has(season):
			by_season[season] = {"days": 0, "income_ce": 0.0, "cold_h": 0.0, "hungry_dusk": 0, "health_min": 100.0}
		var b: Dictionary = by_season[season]
		b.days = int(b.days) + 1
		b.income_ce = float(b.income_ce) + float(r.income_ce)
		b.cold_h = float(b.cold_h) + float(r.cold_h)
		b.health_min = minf(float(b.health_min), float(r.health))
		if str(r.food_stage) != "fed":
			b.hungry_dusk = int(b.hungry_dusk) + 1
			hungry_dusk += 1
		min_meals = minf(min_meals, float(r.meals))
		for c in SurvivalUtil.arr(r.conditions):
			var cid := str(c).get_slice(":", 0)
			cond_days[cid] = int(cond_days.get(cid, 0)) + 1
		if bool(r.get("dead", false)) and death_day < 0:
			death_day = int(r.day)
	var sk0 := SurvivalUtil.dict(rep.skills_start)
	var sk1 := SurvivalUtil.dict(rep.skills_end)
	var gains := {}
	for k in sk1.keys():
		gains[k] = snappedf(float(sk1[k]) - SurvivalUtil.num(sk0.get(k), 0.0), 0.01)
	var checks := {}
	for a in SurvivalUtil.dict(rep.checks).keys():
		var c: Dictionary = rep.checks[a]
		checks[a] = [int(c.n), float(c.success_rate), int(c.mishaps)]
	var out := {"bg": rep.background, "policy": rep.policy, "seed": rep.seed, "start": rep.start, "days": rep.days,
			"end_date": rep.end_date, "died": rep.died, "death_cause": rep.death_cause, "death_day": death_day,
			"health_min": rep.health_min, "cold_stage_h": rep.cold_stage_h, "food_stage_h": rep.food_stage_h,
			"hungry_dusk_days": hungry_dusk, "min_meals_dusk": min_meals, "cond_added": conds, "cond_days": cond_days,
			"meals_eaten": rep.meals_eaten, "vomits": int(SurvivalUtil.num(st.get("vomits"), 0.0)),
			"drams": int(SurvivalUtil.num(st.get("drams"), 0.0)), "passed_out": rep.passed_out, "wakes": rep.wakes,
			"interrupts": rep.interrupts, "fires_lit": int(SurvivalUtil.num(st.get("fires_lit"), 0.0)),
			"income_ce_total": rep.income_ce_total, "income_ce_by_cat": rep.income_ce_by_cat, "income_by_month": rep.income_by_month,
			"fur_ce_per_trapping_day": rep.income_ce_per_trapping_day, "trapping_days": rep.trapping_days,
			"wages_d": rep.wages_d, "cords": rep.cords, "catches": rep.catches, "scavenged": rep.scavenged,
			"steel_lost": int(SurvivalUtil.num(st.get("steel_traps_lost"), 0.0)), "deer": rep.deer,
			"meat_given_lb": rep.meat_given_lb, "money_end": rep.money_end, "trader_book_end": rep.trader_book_end,
			"sutler_tally_end": rep.sutler_tally_end, "settlements": rep.settlements, "standing": rep.standing,
			"skills_start": sk0, "skills_end": sk1, "skill_gain": gains, "checks": checks, "by_season": by_season,
			"obligations": SurvivalUtil.arr(sim.core.state.economy.get("obligations")).duplicate(true)}
	if keep_rows:
		out["day_rows"] = rep.day_rows
	return out


func line_for(r: Dictionary) -> String:
	var ch: Dictionary = r.cold_stage_h
	var severe := SurvivalUtil.num(ch.get("very_cold"), 0.0) + SurvivalUtil.num(ch.get("hypothermic"), 0.0) + SurvivalUtil.num(ch.get("freezing"), 0.0)
	var fh: Dictionary = r.food_stage_h
	var starving := SurvivalUtil.num(fh.get("starving"), 0.0) + SurvivalUtil.num(fh.get("wasting"), 0.0)
	return "%-22s %-10s %-9s s%d  %2dd %s hp%3.0f  vcold+ %5.1fh  starv %5.1fh  hungry@dusk %2d  ce %6.0f (%4.0f/d) wage %5.0f  catch %3d deer %2d  book %6.0f tally %5.0f $%4d  surv +%4.1f  %s  %dms" % [
			str(r.bg), str(r.policy), str(r.start), int(r.seed), int(r.days),
			("DIED:%s@%d" % [str(r.death_cause), int(r.death_day)]) if bool(r.died) else "alive", float(r.health_min), severe, starving,
			int(r.hungry_dusk_days), float(r.income_ce_total), float(r.income_ce_total) / maxf(1.0, float(r.days)), float(r.wages_d),
			int(r.catches), int(r.deer), float(r.trader_book_end), float(r.sutler_tally_end), int(r.money_end),
			SurvivalUtil.num(SurvivalUtil.dict(r.skill_gain).get("survival"), 0.0), str(r.settlements), int(r.ms)]
