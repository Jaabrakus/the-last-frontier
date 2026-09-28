extends SceneTree
## The v4 matrix: runs the self_sufficient, barterer, apprentice and trapper (credit variant) policies over seeds and
## prints one line per run with the M2a gate's measures (survival_gdd.md section 18.2): survival and cause, coin spent,
## the winter-ready day and the snowshoe day (T4), dusk food security from Mid October (T2), hours at Cold or worse
## (T3), the rv kept at the end (T5, T8), skill gains (T9), the most carried at dusk (T12), trades, lessons and broken
## obligations, and real minutes per game day. It writes the rows as JSON lines when --out is given.
##
##   Godot --headless --path . -s tests/survival/run_v4_matrix.gd -- --policies self_sufficient,barterer --seeds 1,2,3
##   options: --bg a,b   --policies a,b   --seeds 1,2   --days 26   --preset woodsman   --start sep_early   --out file
##            --variant start.clear (force a start variant)   --base (the base harness instead of the balance harness)

const SIM_BALANCE := preload("res://scripts/survival/sim/survival_sim_balance.gd")
const WORKING := ["survival", "hunting", "trapping", "provisions", "hidecraft", "woodcraft", "trade"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var bgs := ["bg.backcountry_hunter", "bg.provincial_ranger"]
	var policies := ["self_sufficient"]
	var seeds := [1, 2, 3]
	var days := 26
	var preset := "woodsman"
	var start := "sep_early"
	var out_path := ""
	var variant := ""
	var base := false
	var i := 0
	while i < args.size():
		var a := str(args[i])
		var v := str(args[i + 1]) if i + 1 < args.size() else ""
		match a:
			"--bg":
				bgs = Array(v.split(","))
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
			"--start":
				start = v
				i += 1
			"--out":
				out_path = v
				i += 1
			"--variant":
				variant = v
				i += 1
			"--base":
				base = true
		i += 1
	var t_all := Time.get_ticks_msec()
	for bg in bgs:
		for pol in policies:
			for sd in seeds:
				var t0 := Time.get_ticks_msec()
				var o := {"background": bg, "policy": pol, "days": days, "seed": sd, "start_day": start, "preset": preset}
				if variant != "":
					o["start_variant"] = variant
				var row := run_one(o, base)
				row["ms"] = Time.get_ticks_msec() - t0
				print(line_for(row))
				if out_path != "":
					var f := FileAccess.open(out_path, FileAccess.READ_WRITE if FileAccess.file_exists(out_path) else FileAccess.WRITE)
					if f != null:
						f.seek_end()
						f.store_line(JSON.stringify(row))
						f.close()
	print("v4 matrix done (%d ms)" % (Time.get_ticks_msec() - t_all))
	quit(0)


## One run's gate measures (shared with tests/survival/test_survival_selfsuff.gd).
static func run_one(o: Dictionary, base: bool = false) -> Dictionary:
	var sim: SurvivalSim = SurvivalSim.new() if base else SIM_BALANCE.new()
	sim.setup(o)
	sim.simulate(int(o.get("days", 26)))
	var rep := sim.report()
	return summarize(sim, rep)


static func summarize(sim: SurvivalSim, rep: Dictionary) -> Dictionary:
	var rows := SurvivalUtil.arr(rep.day_rows)
	var dusk_ok := 0
	var dusk_n := 0
	var plain := 0
	var starving := 0
	var max_kg := 0.0
	var kgs := []
	var mid_oct := false
	var cold_h := 0.0
	for r in rows:
		if str(r.month) == "oct" and str(r.date).begins_with("Mid") or str(r.month) in ["nov", "dec", "jan", "feb", "mar", "apr", "may"]:
			mid_oct = true
		if mid_oct:
			dusk_n += 1
			if float(r.get("food_meals", 0.0)) >= 6.0:
				dusk_ok += 1
		if bool(r.get("plain_fare", false)):
			plain += 1
		if bool(r.get("starving", false)):
			starving += 1
		max_kg = maxf(max_kg, float(r.get("kg", 0.0)))
		kgs.append(float(r.get("pack_kg", r.get("kg", 0.0))))
		if str(r.month) in ["dec", "jan", "feb", "mar"]:
			cold_h += float(r.cold_h)
	var gains := {}
	var day_max := 0.0
	for k in WORKING:
		gains[k] = snappedf(SurvivalUtil.num(SurvivalUtil.dict(rep.skills_end).get(k), 0.0) - SurvivalUtil.num(SurvivalUtil.dict(rep.skills_start).get(k), 0.0), 0.1)
	for r in rows:
		day_max = maxf(day_max, float(r.get("xp_total", 0.0)))
	kgs.sort()
	var kg_p90: float = kgs[mini(kgs.size() - 1, int(floor(0.9 * float(kgs.size()))))] if not kgs.is_empty() else 0.0
	var over30 := 0
	for k in kgs:
		if float(k) > 30.0:
			over30 += 1
	var eaten := SurvivalUtil.dict(rep.get("eaten"))
	var plant := SurvivalUtil.num(eaten.get("plant"), 0.0)
	# The winter-ready checklist at Late November (T4's items, in the almanac's order), for the gate's detail line.
	var late_nov := []
	for r in rows:
		if str(r.month) == "nov" and str(r.date).begins_with("Late"):
			late_nov = SurvivalUtil.arr(r.get("ready_checks"))
	return {"bg": rep.background, "policy": rep.policy, "seed": rep.seed, "days": rep.days, "died": rep.died,
			"cause": rep.death_cause, "coin_spent": rep.coin_spent, "ready_day": rep.ready_day, "snowshoe_day": rep.snowshoe_day,
			"dusk_food_frac": float(dusk_ok) / maxf(1.0, float(dusk_n)), "plain_frac": float(plain) / maxf(1.0, float(rows.size())),
			"starving_days": starving, "cold_h_winter": snappedf(cold_h, 0.1), "cold_stage_h": rep.cold_stage_h,
			"rv_kit_end": rep.rv_kit_end, "gains": gains, "day_xp_max": snappedf(day_max, 0.01), "max_kg": snappedf(max_kg, 0.1), "kg_p90": snappedf(kg_p90, 0.1),
				"kg_over30_frac": float(over30) / maxf(1.0, float(kgs.size())), "rv_furs_end": rep.get("rv_furs_end", 0.0),
			"deer": rep.deer, "catches": rep.catches, "trades": rep.trades, "lessons": rep.lessons, "watched": rep.watched,
			"ob_kept": rep.obligations_kept, "ob_broken": rep.obligations_broken, "real_min_day": rep.real_min_per_game_day,
			"acorn_frac_of_plant": SurvivalUtil.num(eaten.get("acorn_meal"), 0.0) / maxf(1.0, plant), "eaten": eaten,
			"made": rep.made, "settlements": rep.settlements, "start_variant": rep.start_variant,
			"shelter_q_end": float(rows[rows.size() - 1].get("shelter_q", 0.0)) if not rows.is_empty() else 0.0,
			"worn_out": rep.worn_out, "late_nov_checks": late_nov, "skills_start": rep.skills_start,
			"skills_end": rep.skills_end, "start": str(rep.get("start", ""))}


static func line_for(r: Dictionary) -> String:
	var g: Dictionary = r.gains
	return "%-22s %-15s s%-2d %-18s coin %4.0f ready d%-3d shoes d%-3d dusk6 %3.0f%% plain %3.0f%% starv %d cold %4.1fh rv %5.0f+%4.0f  surv+%4.1f hunt+%4.1f trap+%4.1f prov+%4.1f hide+%4.1f wood+%4.1f trade+%4.1f dmax %4.1f  kg90 %4.1f >30 %2.0f%% deer %d trades %d lessons %d broken %d  %4.1f rmin/d  %dms" % [
			str(r.bg), str(r.policy), int(r.seed), ("DIED:" + str(r.cause)) if bool(r.died) else "alive", float(r.coin_spent),
			int(r.ready_day), int(r.snowshoe_day), 100.0 * float(r.dusk_food_frac), 100.0 * float(r.plain_frac), int(r.starving_days),
			float(r.cold_h_winter), float(r.rv_kit_end), float(r.rv_furs_end), float(g.survival), float(g.hunting), float(g.trapping), float(g.provisions),
			float(g.hidecraft), float(g.woodcraft), float(g.trade), float(r.day_xp_max), float(r.kg_p90), 100.0 * float(r.kg_over30_frac), int(r.deer), int(r.trades),
			int(r.lessons), int(r.ob_broken), float(r.real_min_day), int(r.get("ms", 0))]
