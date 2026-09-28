extends SceneTree
## Headless consistency and balance test for the LIVE survival data (data/survival/*.json), version 4.
##
## The live files hold only the vertical slice (milestones M1, M2a and M2b, survival_gdd.md section 18); later rows live
## in data/survival/backlog/*.json, which this test does not read (tests/survival/check_backlog_design.gd is advisory).
## Version 4 (the self-sufficiency, barter and learning redesign) changed these checks on purpose: milestones M1/M2a/M2b
## and the 14/42/46 action scope (fix round 1 moved casting balls and hook-and-line fishing live: was 40/44); the v4 growth model (variety, no background multipliers) instead of the v3 typical
## day; credit as a start variant (first outfit and dues read from start_variants); habits instead of perks; buyers only
## for livelihoods that sell; and new static gates: T7 (no coin on the critical path), knowledge routes, origin notes.
##
## Checks that every live file parses, ids are unique, every id-like reference resolves among LIVE ids, every row is M1
## or M2, and that the design's balance claims hold when computed from the data:
##   - a whole trapping season (Nov-Mar) with per-cell depletion, finite good sites, the day's time budget, unchecked
##     losses and snow, at 12, 24 and 48 traps: targets met and income plateaus past 24 traps
##   - hunting with the regional deer stock and the peace-time garrison meat cap
##   - the income ladder in cash-equivalent pence (barter x coin rate): skilled trapping >= 2x the best safe wage;
##     novice trapping and hunting >= 0.8 of a common wage
##   - the cheapest varied diet at every food market costs 0.25-0.5 of the cheapest cash wage
##   - credit (optional): the trader's first outfit 40-60% of a novice season's net and the outfit start variant within
##     it; a steel trap pays back in 5-15 game days
##   - every output of a livelihood that sells has a live buyer in its peak months; every debt, promise and obligation
##     falls due in the slice
##   - growth v4: variety beats repetition, the daily caps, no background multipliers, no tier unlocks, weapon skills
##     from use only
##   - T7: every critical output and technique is reachable for each background with no market step and no lesson;
##     T7b (fix round 1): what a critical path consumes or wears out has a no-market refill, or the kit covers the
##     slice's use of it (recipes.json critical.kit_consumables); musket hunting is not a critical path, and the balls it
##     uses have a no-market refill for the background that carries lead and a mould (craft.cast_balls)
##   - knowledge: every gated recipe and technique has two routes, one needing no coin and no background; mentors never
##     ask coin only; every technique and recipe carries an origin note
##   - drink gives no mechanical buff; the HUD warmth is true; every habit touches a live system; every slice
##     background's spike livelihood is live in the default era; the slice depicts no Native people; the start is legal
##
##   Godot --headless --path . -s tests/survival/test_survival_data.gd
##
## Design document: Player_Animation_Project/graph_analysis/survival/survival_gdd.md

const DIR := "res://data/survival/"
const FILES := ["skills", "backgrounds", "needs", "conditions", "items", "recipes", "actions",
		"seasons", "economy", "livelihoods", "npcs", "map_regions"]
const PREFIXES := ["item.", "cond.", "know.", "lang.", "rcp.", "anim.", "npc.", "faction.", "mkt.", "habit.", "start.", "tb.",
		"service.", "wage.", "job.", "liv.", "event.", "era.", "reg.", "node.", "poi.", "rt.", "world.",
		"bg.", "enc.", "fish_run.", "perk.", "drawback.", "focus.", "mod.", "goal.", "need.", "origin.", "tenure."]
## "later": a mentor's later lessons name backlog techniques on purpose.
const SKIP_KEYS := ["aliases", "retired", "later"]
const SLICE_MILESTONES := ["M1", "M2a", "M2b"]
const CLIP_METRICS := "res://animations/actor_b_clip_metrics.json"
const ROW_LISTS := {"actions": ["actions"], "items": ["items"], "conditions": ["conditions"], "backgrounds": ["backgrounds"],
		"npcs": ["archetypes", "individuals"], "economy": ["markets", "goods", "wages", "services"],
		"seasons": ["events", "eras"], "livelihoods": ["livelihoods", "jobs"], "recipes": ["recipes"]}

var data := {}
var known := {}
var failures := PackedStringArray()
var notes := PackedStringArray()
var id_rx := RegEx.new()
var actions_by_id := {}
var items_by_id := {}
var goods_by_item := {}
var markets_by_id := {}
var events_by_id := {}
var months_by_id := {}
var lines := {}
var hunt := {}


func _initialize() -> void:
	id_rx.compile("^[a-z_]+\\.[a-z0-9_.]+$")
	for f in FILES:
		var d = _load_json(DIR + f + ".json")
		if d == null:
			continue
		data[f] = d
		if not (d.has("schema") and d.has("version")):
			_fail("%s: missing schema/version header" % f)
		elif int(d.version) != 4:
			_fail("%s: version must be 4" % f)
	if failures.is_empty():
		_index()
		_collect_ids()
		_check_references()
		_check_milestones()
		_check_structure()
		_check_needs_targets()
		_check_trap_season()
		_check_hunting_and_ladder()
		_check_food()
		_check_credit_and_capital()
		_check_buyers_and_dues()
		_check_growth()
		_check_rules()
		_check_critical_path()
		_check_knowledge()
		_check_anim_hooks()
	for msg in notes:
		print("  ", msg)
	for msg in failures:
		printerr("FAIL: ", msg)
	if failures.is_empty():
		print("SURVIVAL DATA TEST PASSED (%d live ids)" % known.size())
		quit(0)
	else:
		print("SURVIVAL DATA TEST FAILED (%d problems)" % failures.size())
		quit(1)


func _fail(msg: String) -> void:
	if failures.size() < 200:
		failures.append(msg)


func _load_json(path: String):
	if not FileAccess.file_exists(path):
		_fail("missing file " + path)
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		_fail("cannot parse " + path)
		return null
	return parsed


func _index() -> void:
	for a in data.actions.actions:
		actions_by_id[a.id] = a
	for i in data.items.items:
		items_by_id[i.id] = i
	for g in data.economy.goods:
		goods_by_item[g.item] = g
	for m in data.economy.markets:
		markets_by_id[m.id] = m
	for e in data.seasons.events:
		events_by_id[e.id] = e
	for m in data.seasons.months:
		months_by_id[m.id] = m


func _add_ids(list: Array, what: String, key := "id") -> void:
	for e in list:
		var id := str(e[key])
		if known.has(id):
			_fail("duplicate id %s (%s)" % [id, what])
		known[id] = what


func _collect_ids() -> void:
	_add_ids(data.items.items, "item")
	_add_ids(data.skills.skills, "skill")
	_add_ids(data.skills.modifiers, "modifier")
	_add_ids(data.needs.needs, "need")
	_add_ids(data.conditions.conditions, "condition")
	_add_ids(data.actions.actions, "action")
	_add_ids(data.actions.anim_hooks, "anim hook")
	_add_ids(data.recipes.recipes, "recipe")
	_add_ids(data.npcs.archetypes, "archetype")
	_add_ids(data.npcs.factions, "faction")
	_add_ids(data.npcs.dialogue_topics, "topic")
	_add_ids(data.npcs.individuals, "npc")
	_add_ids(data.economy.markets, "market")
	_add_ids(data.economy.services, "service")
	_add_ids(data.economy.wages, "wage")
	_add_ids(data.livelihoods.jobs, "job")
	_add_ids(data.livelihoods.livelihoods, "livelihood")
	_add_ids(data.seasons.events, "event")
	_add_ids(data.seasons.eras, "era")
	_add_ids(data.map_regions.regions, "region")
	_add_ids(data.map_regions.resource_nodes, "resource node")
	_add_ids(data.backgrounds.backgrounds, "background")
	_add_ids(data.backgrounds.long_term_goals, "goal")
	for r in data.map_regions.regions:
		_add_ids(r.pois, "poi")
	for w in data.actions.world_objects.keys():
		known[w] = "world object"
	_add_ids(data.skills.get("knowledge", []), "knowledge")
	var tbs = data.npcs.get("trade_behaviours", {})
	for k in (tbs.keys() if typeof(tbs) == TYPE_DICTIONARY else []):
		if str(k).begins_with("tb."):
			known[str(k)] = "trade behaviour"
	_add_ids(data.backgrounds.get("habits", []), "habit")
	_add_ids(data.backgrounds.get("start_variants", []), "start variant")
	for b in data.backgrounds.backgrounds:
		if b.has("perk"):
			known[b.perk.id] = "perk"
		if b.has("drawback"):
			known[b.drawback.id] = "drawback"
		for v in b.get("variants", {}).values():
			for c in v.get("choose_one", []):
				if typeof(c) == TYPE_DICTIONARY:
					known[c.id] = "variant"


func _is_ref(s: String) -> bool:
	if s.contains(" "):
		return false
	for p in PREFIXES:
		if s.begins_with(p):
			return id_rx.search(s.split(":")[0]) != null
	return false


func _walk(v, path: String, file: String) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v.keys():
				if SKIP_KEYS.has(str(k)):
					continue
				if typeof(k) == TYPE_STRING and _is_ref(k):
					_resolve(k.split(":")[0], path + "/" + k, file)
				_walk(v[k], path + "/" + str(k), file)
		TYPE_ARRAY:
			for i in v.size():
				_walk(v[i], "%s[%d]" % [path, i], file)
		TYPE_STRING:
			if _is_ref(v):
				_resolve(v.split(":")[0], path, file)


func _resolve(id: String, path: String, file: String) -> void:
	if known.has(id) or (id.begins_with("item.") and id.ends_with("_min")):
		return
	_fail("%s: unresolved reference %s at %s (live data may reference only live ids)" % [file, id, path])


func _check_references() -> void:
	for f in data.keys():
		_walk(data[f], "", f)


# ---------------------------------------------------------------- milestones and scope
func _check_milestones() -> void:
	# v4 (survival_gdd.md section 18): the slice is M1, M2a (self-sufficiency and barter) and M2b (lessons, promises,
	# haggling). Rows from M3 on live in backlog/.
	var counts := {}
	for f in ROW_LISTS.keys():
		for sec in ROW_LISTS[f]:
			for row in data[f][sec]:
				var m := str(row.get("milestone", ""))
				var rid := str(row.get("id", row.get("item", "?")))
				if not SLICE_MILESTONES.has(m):
					_fail("%s/%s row %s: live rows are M1, M2a or M2b (got '%s'); later rows belong in backlog/" % [f, sec, rid, m])
				var key: String = sec + "_" + m
				counts[key] = int(counts.get(key, 0)) + 1
	var m1 := int(counts.get("actions_M1", 0))
	var m2a := int(counts.get("actions_M2a", 0))
	var m2b := int(counts.get("actions_M2b", 0))
	if m1 > 14:
		_fail("scope: M1 has %d actions (at most 14)" % m1)
	# Fix round 1 (redesign_balance_report.md F1-F3): casting balls and hook-and-line fishing are live, 42 at M2a and 46
	# in the slice (was 40 and 44).
	if m1 + m2a > 42:
		_fail("scope: M1 and M2a have %d actions (the M2a gate allows at most 42)" % (m1 + m2a))
	if m1 + m2a + m2b > 46:
		_fail("scope: the slice has %d actions (the M2b gate allows at most 46)" % (m1 + m2a + m2b))
	if int(counts.get("conditions_M1", 0)) != 6:
		_fail("scope: M1 has exactly six conditions (hunger, cold, wet, fatigue, a cut, a light drink)")
	var bgs := 0
	for k in counts.keys():
		if str(k).begins_with("backgrounds_"):
			bgs += int(counts[k])
	if int(counts.get("backgrounds_M1", 0)) != 1 or bgs != 2:
		_fail("scope: one background in M1 and one more in M2a")
	if data.map_regions.regions.size() != 1:
		_fail("scope: the slice is one region")
	if data.seasons.eras.size() != 1 or str(data.seasons.eras[0].id) != str(data.seasons.calendar.start_default.era):
		_fail("scope: the slice has only the default era")
	notes.append("slice rows: %s" % str(counts))


func _day_ok(w) -> bool:
	var days: Array = data.seasons.calendar.day_ids
	return typeof(w) == TYPE_ARRAY and w.size() == 2 and days.has(w[0]) and days.has(w[1])


func _check_structure() -> void:
	var cal = data.seasons.calendar
	if cal.day_ids.size() != int(cal.days_per_year) or int(cal.days_per_year) != int(cal.months.size()) * int(cal.phases.size()):
		_fail("calendar: days_per_year must equal months x phases and the day id count")
	if not _day_ok(cal.slice_span):
		_fail("calendar: bad slice span")
	var som = data.skills.skill_of_prefix
	for a in data.actions.actions:
		if str(a.skill) == "" and bool(a.get("no_skill", false)):
			pass
		elif not known.get(a.skill, "") == "skill":
			_fail("action %s: unknown skill %s" % [a.id, a.skill])
		# v4: every action id maps to its skill by prefix (skills.json skill_of_prefix, redesign_skills.md 3.3).
		var mapped := ""
		for pair in som.map:
			if str(a.id).begins_with(str(pair[0])):
				mapped = str(pair[1])
				break
		if mapped != str(a.skill):
			_fail("action %s: skill %s, but skill_of_prefix maps it to '%s'" % [a.id, a.skill, mapped])
		# v4: every action is a plain verb, a technique, or worked through recipes (redesign_skills.md 5).
		var has_recipe := false
		for r in data.recipes.recipes:
			if str(r.action) == str(a.id):
				has_recipe = true
				break
		if not (bool(a.get("plain_verb", false)) or bool(a.get("technique", false)) or has_recipe):
			_fail("action %s: neither a plain verb, a technique nor worked by a recipe" % a.id)
		if bool(a.get("technique", false)) and str(a.get("origin", "")).strip_edges() == "":
			_fail("action %s: a technique needs an origin note (GDD section 13, rule 9)" % a.id)
		if a.has("specialties"):
			_fail("action %s: no specialties in the slice" % a.id)
		if a.outcomes.has("mishap") and not a.has("hazard"):
			_fail("action %s: mishap without hazard" % a.id)
		if a.time_min.size() != 2 or float(a.time_min[0]) > float(a.time_min[1]):
			_fail("action %s: bad time_min" % a.id)
	for r in data.recipes.recipes:
		if not known.get(r.action, "") == "action":
			_fail("recipe %s: unknown action" % r.id)
		if str(r.get("origin", "")).strip_edges() == "":
			_fail("recipe %s: needs an origin note (GDD section 13, rule 9)" % r.id)
		var sk := str(actions_by_id.get(r.action, {}).get("skill", ""))
		if r.has("skill") and str(r.skill) != sk:
			_fail("recipe %s: skill %s differs from its action's %s" % [r.id, r.skill, sk])
	for g in data.seasons.gates.values():
		if g.has("window") and not _day_ok(g.window):
			_fail("gate: bad window %s" % str(g.window))
	for e in data.seasons.events:
		if typeof(e.when) == TYPE_ARRAY and not _day_ok(e.when):
			_fail("event %s: bad window" % e.id)
	for b in data.backgrounds.backgrounds:
		for pair in b.starting_kit:
			if not known.get(pair[0], "") == "item":
				_fail("background %s: unknown kit item %s" % [b.id, pair[0]])
		var tot := 0.0
		for v in b.skills.values():
			tot += float(v)
		var bud = data.backgrounds.skill_budget.target
		if tot < float(bud[0]) or tot > float(bud[1]):
			_fail("background %s: skill budget %.0f outside %s" % [b.id, tot, str(bud)])
		for k in b.skills.keys():
			if float(b.skills[k]) > float(data.backgrounds.skill_budget.max_start):
				_fail("background %s: %s starts at %.0f, above the %.0f cap" % [b.id, k, float(b.skills[k]), float(data.backgrounds.skill_budget.max_start)])
		if b.has("xp_mult") or JSON.stringify(b).contains("xp_mult"):
			_fail("background %s: v4 backgrounds are head starts, never experience multipliers" % b.id)
	var acts: Dictionary = data.npcs.activities
	for a in data.npcs.archetypes:
		for key in a.schedule.keys():
			for bl in a.schedule[key]:
				if not acts.has(bl[2]):
					_fail("archetype %s: unknown activity %s" % [a.id, bl[2]])
			if key.begins_with("event:") and not known.has("event." + key.substr(6)):
				_fail("archetype %s: unknown event key %s" % [a.id, key])
	for g in data.economy.goods:
		if not data.economy.price_profiles.has(g.profile):
			_fail("good %s: unknown price profile" % g.item)
		if float(g.cash_retail_d) <= 0.0:
			_fail("good %s: cash price must be positive" % g.item)
	for m in data.economy.markets:
		for s in m.sells:
			if not goods_by_item.has(s):
				_fail("market %s sells unpriced %s" % [m.id, s])
			elif str(m.price_layer) == "barter" and not goods_by_item[s].has("barter"):
				_fail("barter market %s sells %s which has no barter value" % [m.id, s])
	for season in data.seasons.weather.chains.keys():
		for state in data.seasons.weather.chains[season].keys():
			var total := 0.0
			for p in data.seasons.weather.chains[season][state].values():
				total += float(p)
			if absf(total - 1.0) > 0.02:
				_fail("weather row %s/%s sums to %.3f" % [season, state, total])
	for r in data.map_regions.regions:
		if not data.map_regions.institutions.has(str(r.institutions)):
			_fail("region %s: institutions unknown" % r.id)


func _chance(S: float, D: float, mods := 0.0) -> float:
	var m = data.skills.check_model
	return clampf(float(m.base) + (S - D) / float(m.slope) + mods, float(m.floor), float(m.cap))


func _check_needs_targets() -> void:
	if absf(_chance(40, 40) - 0.55) > 0.001:
		_fail("check: S = D must give 55%")
	var clock = data.seasons.clock.real_min_per_game_h
	var real_per_h := (float(clock.day) * 16.0 + float(clock.night) * 8.0) / 24.0
	var needs := {}
	for n in data.needs.needs:
		needs[n.id] = n
	var food = needs["need.food"]
	var t = data.needs.real_time_targets_woodsman
	var hungry_real := float(food.stomach_capacity_kcal) * (1.0 - 0.35) / float(food.burn_kcal_per_game_h) * real_per_h
	if hungry_real < float(t.food_full_to_hungry_real_min[0]) or hungry_real > float(t.food_full_to_hungry_real_min[1]):
		_fail("food: full to hungry takes %.0f real min" % hungry_real)
	var w = needs["need.warmth"]
	var rate := (-15.0 + 6.0 * float(w.c_per_ins) - float(w.T_comfort_c)) * float(w.k)
	var to_cold := 50.0 / -rate * float(clock.night)
	if to_cold < float(t.warmth_winter_night_poor_kit_to_cold_real_min[0]) or to_cold > float(t.warmth_winter_night_poor_kit_to_cold_real_min[1]):
		_fail("warmth: poor kit reaches Cold in %.1f real min" % to_cold)
	var u = data.economy.currency.units
	if int(u.beaver_d) != 144 or absf(float(u.beaver_d) / float(u.buck_d) - 1.5) > 0.001:
		_fail("currency chain 1 beaver = 1.5 bucks = 144 d broken")
	if int(data.economy.currency.currencies.new_york.d_per_dollar) != 96:
		_fail("New York currency must be 96 d (8 s) to the dollar")
	var F := float(data.seasons.time.flow_factor)
	for i in data.items.items:
		if i.has("kcal_hist") and absf(float(i.kcal) - float(i.kcal_hist) / F) > 0.06:
			_fail("item %s: game kcal must be kcal_hist / flow factor" % i.id)
	if data.seasons.time.has("process_rule") or data.seasons.time.has("three_clocks"):
		_fail("time: one flow factor only (no process rule, no three clocks)")


# ---------------------------------------------------------------- the trapping season
func _days_in(window: Array) -> Array:
	var ids: Array = data.seasons.calendar.day_ids
	var a := ids.find(window[0])
	var b := ids.find(window[1])
	if a <= b:
		return ids.slice(a, b + 1)
	return ids.slice(a) + ids.slice(0, b + 1)


func _pelt_barter(species: String, month: String, grade: float) -> float:
	var item = null
	for i in data.items.items:
		if str(i.get("species", "")) == species and (str(i.cat) == "pelt" or str(i.cat) == "skin"):
			item = i
			break
	if item == null or not goods_by_item.has(item.id) or not goods_by_item[item.id].has("barter"):
		return 0.0
	var prime := 1.0
	if str(item.cat) == "pelt":
		var pb = data.seasons.pelt_prime_by_species
		prime = float(pb[species][month]) if pb.has(species) else float(pb["default"][month])
	return float(goods_by_item[item.id].barter.beaver) * float(data.economy.currency.units.beaver_d) * prime * grade \
			* float(data.actions.trap_model.season_sim.animal_condition)


func _time(action_id: String, tier: String) -> float:
	var a = actions_by_id[action_id]
	var frac := float(data.actions.trap_model.season_sim.tiers[tier].time_frac)
	return float(a.time_min[0]) + (float(a.time_min[1]) - float(a.time_min[0])) * frac


func _trap_season(tier: String, n_traps: int) -> Dictionary:
	var tm = data.actions.trap_model
	var ss = tm.season_sim
	var T = ss.tiers[tier]
	var sp: Dictionary = data.map_regions.fauna.trap_species
	var cells = data.map_regions.trapping_cells
	var F := float(data.seasons.time.flow_factor)
	var n_cells := int(cells.count)
	var steel := mini(n_traps, int(T.steel_traps))
	var good := roundi(n_cells * float(cells.sites_per_cell.good) * float(T.good_sites_read))
	var fair := n_cells * int(cells.sites_per_cell.fair) + (n_cells * int(cells.sites_per_cell.good) - good)
	var traps := []
	for k in n_traps:
		var ttype := "steel_land" if k < steel else "deadfall"
		var base := float(cells.site_quality.poor)
		if k < good:
			base = float(cells.site_quality.good)
		elif k < good + fair:
			base = float(cells.site_quality.fair)
		var pl := minf(float(tm.placement.max), base + float(tm.placement.sign_bonus) * float(T.sign_frac))
		traps.append({"type": ttype, "cell": k % n_cells, "pf": pl / 3.0, "held": {}, "held_n": 0.0, "active": 1.0})
	var stock0 := {}
	for s in sp.keys():
		stock0[s] = float(sp[s].stock_per_cell)
	var stock := []
	for c in n_cells:
		stock.append(stock0.duplicate())
	var days := _days_in(ss.window)
	var total_ce := 0.0
	var total_barter := 0.0
	var steel_barter := 0.0
	var budget := float(T.budget_min)
	var walk := float(ss.walk_min_per_trap)
	var t_check := _time("trap.check", tier)
	var t_proc := _time("fur.skin", tier) + _time("fur.stretch", tier)
	var coin := float(data.economy.settlement.coin_rate)
	var season_len := float(data.seasons.calendar.days_per_year) / 4.0
	for day in days:
		var m: String = day.split("_")[0]
		var snow_p := float(months_by_id[m].fresh_snow_night_frac)
		var want := []
		for c in n_cells:
			var z := {}
			for s in sp.keys():
				z[s] = 0.0
			want.append(z)
		var per_trap := []
		for t in traps:
			var fit: Dictionary = tm.trap_fit[t.type]
			var bait := float(T.bait[t.type])
			var comps := {}
			var lam := 0.0
			for s in fit.keys():
				var am: Dictionary = sp[s].activity
				var act := float(am.get(m, am.get("default", 1.0)))
				var cv: float = F * float(sp[s].nightly_rate) * float(fit[s]) * act * (float(stock[t.cell][s]) / float(stock0[s])) \
						* float(t.pf) * bait * float(T.set_quality)
				comps[s] = cv
				lam += cv
			var snow_mult := 1.0 - snow_p * float(tm.snow_reset[t.type].frac) * 0.5
			var cap := float(t.active) * maxf(0.0, 1.0 - float(t.held_n))
			var pc := cap * (1.0 - exp(-lam)) * snow_mult if lam > 0.0 else 0.0
			var e := {}
			for s in comps.keys():
				e[s] = pc * float(comps[s]) / lam if lam > 0.0 else 0.0
				want[t.cell][s] = float(want[t.cell][s]) + float(e[s])
			per_trap.append(e)
		var scale := []
		for c in n_cells:
			var z := {}
			for s in sp.keys():
				var wv := float(want[c][s])
				z[s] = minf(1.0, float(stock[c][s]) / wv) if wv > 1e-9 else 1.0
			scale.append(z)
		for i in traps.size():
			var t = traps[i]
			var e: Dictionary = per_trap[i]
			for s in e.keys():
				var v := float(e[s]) * float(scale[t.cell][s])
				t.held[s] = float(t.held.get(s, 0.0)) + v
				t.held_n = float(t.held_n) + v
				stock[t.cell][s] = float(stock[t.cell][s]) - v
		for t in traps:
			t.active = float(t.active) * (1.0 - snow_p * float(tm.snow_reset[t.type].frac))
		var held_catch := 0.0
		var pelts_held := 0.0
		var reset_need := 0.0
		for t in traps:
			held_catch += float(t.held_n)
			for s in t.held.keys():
				if bool(sp[s].pelt):
					pelts_held += float(t.held[s])
			reset_need += (1.0 - float(t.active)) * float(tm.snow_reset[t.type].min)
		var need := traps.size() * (walk + t_check) + held_catch * float(ss.reset_after_catch_min) + pelts_held * t_proc + reset_need
		var f := minf(1.0, budget / need) if need > 0.0 else 1.0
		var barter_day := 0.0
		for t in traps:
			var left := {}
			var left_n := 0.0
			for s in t.held.keys():
				var got := f * float(t.held[s])
				if bool(sp[s].pelt):
					var val := _pelt_barter(s, m, float(T.grade)) * got
					barter_day += val
					if t.type == "steel_land":
						steel_barter += val
				left[s] = (1.0 - f) * float(t.held[s]) * (1.0 - float(tm.unchecked.held_catch_loss_per_night))
				left_n += float(left[s])
			t.held = left
			t.held_n = left_n
			t.active = f + (1.0 - f) * float(t.active) * (1.0 - float(tm.unchecked.empty_sprung_per_night))
		total_barter += barter_day
		total_ce += barter_day * coin
		for c in n_cells:
			for s in sp.keys():
				var r := 1.0 - pow(1.0 - float(sp[s].recovery_per_season), 1.0 / season_len)
				stock[c][s] = float(stock[c][s]) + r * (float(stock0[s]) - float(stock[c][s]))
	var n := float(days.size())
	return {"ce": total_ce / n, "barter": total_barter / n, "season_barter": total_barter, "days": n,
			"steel_per_trap_day": steel_barter / n / float(steel) if steel > 0 else 0.0}


func _check_trap_season() -> void:
	var ss = data.actions.trap_model.season_sim
	for tier in ["novice", "skilled"]:
		for n in ss.line_sizes:
			lines["%s_%d" % [tier, int(n)]] = _trap_season(tier, int(n))
	var tg = ss.targets
	var nov := float(lines.novice_12.ce)
	var sk := float(lines.skilled_24.ce)
	if nov < float(tg.novice_12_ce[0]) or nov > float(tg.novice_12_ce[1]):
		_fail("traps: a novice's 12-trap season earns %.0f cash-eq d a game day (target %s)" % [nov, str(tg.novice_12_ce)])
	if sk < float(tg.skilled_24_ce[0]) or sk > float(tg.skilled_24_ce[1]):
		_fail("traps: a skilled 24-trap season earns %.0f cash-eq d a game day (target %s)" % [sk, str(tg.skilled_24_ce)])
	for tier in ["novice", "skilled"]:
		var r := float(lines[tier + "_48"].ce) / float(lines[tier + "_24"].ce)
		if r > 1.15:
			_fail("traps: %s income does not plateau: 48 traps earn %.2fx 24 traps" % [tier, r])
	if float(lines.novice_48.ce) >= 0.75 * sk:
		_fail("traps: a novice with 48 traps rivals a skilled trapper with 24")
	var parts := []
	for k in lines.keys():
		parts.append("%s %.0f" % [k, float(lines[k].ce)])
	notes.append("trap season (cash-eq d/game day): " + ", ".join(parts))


# ---------------------------------------------------------------- hunting and the ladder
func _hunting(tier: String) -> Dictionary:
	var hr = data.livelihoods.design.hunting_reference
	var T = hr.tiers[tier]
	var deer = data.map_regions.fauna.deer
	var meat = markets_by_id[hr.meat_market].buys.meat_channel
	var lb_cap := float(meat.caps_lb_per_game_day["item.food.venison_raw"]) * float(meat.cap_mult_by_era[data.seasons.calendar.start_default.era])
	var price := float(meat.price_d["item.food.venison_raw"])
	var cy = data.actions.carcass_yields.deer
	var lb_per_deer := float(cy.items["item.food.venison_raw"])
	var N0 := float(deer.stock)
	var N := N0
	var tot := 0.0
	var days := _days_in(hr.window)
	var coin := float(data.economy.settlement.coin_rate)
	for day in days:
		var m: String = day.split("_")[0]
		var taken := minf(N, float(T.deer_per_game_day_at_full_stock) * N / N0)
		N -= taken
		var skin_item: String = cy.skin_item_by_season.fall if cy.skin_item_by_season.fall_skin_months.has(m) else cy.skin_item_by_season.other
		var skin_b := float(goods_by_item[skin_item].barter.beaver) * float(data.economy.currency.units.beaver_d) * float(T.grade) \
				* float(data.actions.trap_model.season_sim.animal_condition)
		tot += taken * skin_b * coin + minf(lb_cap, taken * lb_per_deer * float(hr.meat_sold_frac)) * price
		N = minf(N0, N + float(deer.immigration_per_game_day))
	return {"ce": tot / float(days.size()), "days": float(days.size())}


func _check_hunting_and_ladder() -> void:
	hunt = {"novice": _hunting("novice"), "skilled": _hunting("skilled")}
	var livs := {}
	for l in data.livelihoods.livelihoods:
		livs[l.id] = l
	for tier in ["novice", "skilled"]:
		var target := float(livs["liv.market_hunting"].income_target_ce_per_game_day[tier])
		if absf(float(hunt[tier].ce) - target) / target > 0.3:
			_fail("hunting: %s earns %.0f cash-eq d a game day, target %.0f (meat cap applied)" % [tier, float(hunt[tier].ce), target])
	var lr = data.economy.wages_rule.ladder
	var skilled := float(lines["skilled_%d" % int(lr.reference_line)].ce)
	var novice := float(lines["novice_%d" % int(lr.novice_line)].ce)
	var cap := skilled * float(lr.max_safe_wage_frac_of_skilled_trapping)
	for w in data.economy.wages:
		var hi := float(w.cash_d_per_game_day[1]) + float(w.get("in_kind_d", 0))
		if hi > cap + 0.001:
			_fail("ladder: wage %s pays %.0f d a game day, above half of skilled trapping (%.0f cash-eq)" % [w.id, hi, cap])
	var floor_d := float(lr.reference_common_wage_d) * float(lr.min_novice_risky_frac_of_common_wage)
	if novice < floor_d:
		_fail("ladder: novice trapping %.0f cash-eq below %.0f" % [novice, floor_d])
	if float(hunt.novice.ce) < floor_d:
		_fail("ladder: novice hunting %.0f cash-eq below %.0f" % [float(hunt.novice.ce), floor_d])
	var bar := 0.0
	var cash := 0.0
	for it in data.economy.settlement.typical_basket.keys():
		var q := float(data.economy.settlement.typical_basket[it])
		bar += float(goods_by_item[it].barter.beaver) * float(data.economy.currency.units.beaver_d) * q
		cash += float(goods_by_item[it].cash_retail_d) * q
	if absf(float(data.economy.settlement.coin_rate) - cash / bar) > 0.05:
		_fail("settlement: coin rate %.2f is not near 1/overplus %.2f" % [float(data.economy.settlement.coin_rate), cash / bar])
	var band = data.economy.price_layers.overplus_band
	for g in data.economy.goods:
		if g.has("barter") and str(g.origin) == "import":
			var ratio := float(g.barter.beaver) * float(data.economy.currency.units.beaver_d) / float(g.cash_retail_d)
			if ratio < float(band[0]) or ratio > float(band[1]):
				_fail("prices: %s barter/cash overplus %.2f outside %s" % [g.item, ratio, str(band)])
	notes.append("hunting cash-eq: novice %.0f, skilled %.0f; ladder: skilled trapping %.0f vs safe cap %.0f" % [float(hunt.novice.ce), float(hunt.skilled.ce), skilled, cap])


# ---------------------------------------------------------------- food
func _check_food() -> void:
	var fc = data.needs.food
	var day := float(fc.game_kcal_per_game_day)
	var deer_days := float(data.actions.carcass_yields.deer.items["item.food.venison_raw"]) * float(items_by_id["item.food.venison_raw"].kcal) / day
	if deer_days < float(fc.targets.deer_feeds_game_days[0]) or deer_days > float(fc.targets.deer_feeds_game_days[1]):
		_fail("food: a deer feeds %.2f game days" % deer_days)
	var cheapest := 1.0e9
	for w in data.economy.wages:
		cheapest = minf(cheapest, float(w.cash_d_per_game_day[0]))
	var capshare := float(fc.plain_fare.max_share_one_group)
	var sold_food := 0
	for m in data.economy.markets:
		# v4: only cash markets have a markup; the barter and valuation partners are tested by the trade gates.
		if not m.has("markup"):
			continue
		var foods := []
		for it in m.sells:
			var row = items_by_id.get(it, {})
			if float(row.get("kcal", 0)) <= 0.0 or not row.has("food_group"):
				continue
			var price := float(goods_by_item[it].cash_retail_d) * float(m.markup) * (1.0 + float(m.spread))
			foods.append([price / float(row.kcal), it, str(row.food_group)])
		if foods.is_empty():
			continue
		sold_food += 1
		foods.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
		var left := day
		var cost := 0.0
		var used := {}
		for f in foods:
			var room := minf(left, capshare * day - float(used.get(f[2], 0.0)))
			if room <= 0.0:
				continue
			used[f[2]] = float(used.get(f[2], 0.0)) + room
			cost += room * float(f[0])
			left -= room
			if left <= 1e-9:
				break
		var frac := cost / cheapest
		var band = fc.targets.cheapest_varied_diet_vs_cheapest_cash_wage
		if left > 1e-6:
			_fail("food: %s cannot supply a varied diet" % m.id)
		elif frac < float(band[0]) or frac > float(band[1]):
			_fail("food: the cheapest varied diet at %s costs %.1f d = %.2f of the cheapest wage (target %s)" % [m.id, cost, frac, str(band)])
		notes.append("food: cheapest varied diet at %s %.1f d a game day (%.2f of %.0f d)" % [m.id, cost, frac, cheapest])
	if sold_food == 0:
		_fail("food: no live market sells food")


# ---------------------------------------------------------------- credit and capital
func _check_credit_and_capital() -> void:
	var cr = data.economy.credit
	var lr = data.economy.wages_rule.ladder
	var hr = data.livelihoods.design.hunting_reference
	var nov = lines["novice_%d" % int(lr.novice_line)]
	var fall_barter := float(hunt.novice.ce) / float(data.economy.settlement.coin_rate) * float(hunt.novice.days) * float(hr.fall_skin_share_of_ce)
	var net := float(nov.season_barter) + fall_barter - float(cr.season_consumables_barter_d)
	if not bool(cr.get("optional", false)):
		_fail("credit: v4 credit is optional (redesign_economy.md 7)")
	# v4: credit is a start variant, not the default; the trader's first outfit (a background's credit line) still sizes
	# at 40-60% of a novice season's net, and the outfit variant's debt fits inside it.
	var limits := {}
	for b in data.backgrounds.backgrounds:
		if not b.has("credit"):
			continue
		var frac := float(b.credit.first_outfit_limit_barter_d) / net
		limits[b.id] = float(b.credit.first_outfit_limit_barter_d)
		if frac < 0.4 or frac > 0.6:
			_fail("credit: %s's first outfit is %.2f of a novice season's net (target 0.4-0.6)" % [b.id, frac])
	var defaults := 0
	for v in data.backgrounds.start_variants:
		if bool(v.get("default", false)):
			defaults += 1
			if v.has("debt") or v.has("promise"):
				_fail("start: the default start (%s) must owe no one" % v.id)
		var d = v.get("debt", null)
		if d == null:
			continue
		for bid in v.backgrounds:
			var amt := float(d.get("amount_barter_d", d.get("amount_d", 0.0)))
			if str(d.get("layer", "")) == "barter" and limits.has(bid) and amt > float(limits[bid]):
				_fail("credit: %s's debt %.0f is above %s's first outfit limit" % [v.id, amt, bid])
			if amt <= 0.0:
				_fail("credit: %s has no debt amount" % v.id)
	if defaults != 1:
		_fail("start: exactly one default start variant (Clear)")
	if not bool(cr.collection.get("all_presets", false)):
		_fail("credit: collection runs on every preset")
	if cr.due_window.size() != 2 or not _day_ok(cr.due_window):
		_fail("credit: the due date is a window")
	var tm = data.actions.trap_model
	var line = lines["skilled_%d" % int(tm.season_sim.payback_line)]
	var per_trap := float(line.steel_per_trap_day) * (1.0 - float(tm.steel_trap_loss_per_game_day) * float(line.days) / 2.0)
	var price := float(goods_by_item["item.trap.steel"].barter.beaver) * float(data.economy.currency.units.beaver_d)
	var payback := price / per_trap if per_trap > 0.0 else 999.0
	var pb = tm.season_sim.payback_game_days
	if payback < float(pb[0]) or payback > float(pb[1]):
		_fail("capital: a steel trap pays back in %.1f game days (target %s)" % [payback, str(pb)])
	notes.append("credit: novice season net %.0f barter d; steel trap payback %.1f game days" % [net, payback])


# ---------------------------------------------------------------- buyers and due events
func _event_days(ev_id: String) -> Array:
	var w = events_by_id[ev_id].when
	return _days_in(w) if typeof(w) == TYPE_ARRAY else [w]


func _check_buyers_and_dues() -> void:
	for l in data.livelihoods.livelihoods:
		# v4: living from the woods and making for your own use need no buyer (buyers_required false).
		if not bool(l.get("buyers_required", true)):
			continue
		for out in l.outputs:
			var cat := str(items_by_id[out].cat)
			for mon in l.peak:
				var ok := false
				for m in data.economy.markets:
					var b = m.get("buys", {})
					if not (b.get("items", []).has(out) or b.get("categories", []).has(cat)):
						if str(m.get("price_layer", "")) != "valuation" or not _behaviour_wants(m, out):
							continue
					if typeof(m.open) == TYPE_STRING and m.open == "all_year":
						ok = true
					else:
						for ev in m.open:
							for d in _event_days(ev):
								if str(d).begins_with(mon + "_"):
									ok = true
					if ok:
						break
				if not ok:
					_fail("buyers: %s has no live buyer for %s in %s" % [l.id, out, mon])
	var span := _days_in(data.seasons.calendar.slice_span)
	var dues := []
	for b in data.backgrounds.backgrounds:
		if b.has("obligation"):
			dues.append([b.id + " obligation", str(b.obligation.get("due_event", ""))])
	for v in data.backgrounds.start_variants:
		if v.has("debt"):
			dues.append([v.id + " debt", str(v.debt.get("due_event", ""))])
		if v.has("promise"):
			var pr = v.promise
			if pr.has("due_day"):
				if not span.has(str(pr.due_day)):
					_fail("dues: %s's promise falls due outside the slice (%s)" % [v.id, pr.due_day])
			else:
				dues.append([v.id + " promise", str(pr.get("due_event", ""))])
	for pair in dues:
		var ev := str(pair[1])
		if not events_by_id.has(ev):
			_fail("dues: %s has no live due event" % pair[0])
			continue
		for day in _event_days(ev):
			if not span.has(day):
				_fail("dues: %s falls due outside the slice (%s)" % [pair[0], day])
	if not events_by_id.has(str(data.economy.credit.due_event)):
		_fail("dues: the outfit's due event is not live")


## A valuation partner (soldiers, the farm family) buys what its trade behaviour wants.
func _behaviour_wants(m: Dictionary, item: String) -> bool:
	var tbs = data.npcs.get("trade_behaviours", {})
	for tb in tbs.values():
		if typeof(tb) != TYPE_DICTIONARY:
			continue
		var w = tb.get("wants", {})
		if typeof(w) == TYPE_DICTIONARY and w.has(item):
			return true
		if typeof(w) == TYPE_ARRAY:
			for row in w:
				if typeof(row) == TYPE_DICTIONARY and (str(row.get("item", "")) == item or row.get("items", []).has(item)):
					return true
	return false


# ---------------------------------------------------------------- growth (v4, redesign_skills.md 4)
## Expected outcome multiplier at chance p.
func _expected_outcome(p: float) -> float:
	var om = data.skills.growth_model.outcome_mult
	var pa := minf(1.0, p + float(data.skills.check_model.outcome_roll.partial_band)) - p
	var ex := float(data.skills.check_model.outcome_roll.excellent_frac) * p
	return ex * float(om.excellent) + (p - ex) * float(om.success) + pa * float(om.partial) + (1.0 - p - pa) * float(om.failure)


## The v4 gain of one use: k * base_xp * C(p) * E[O] * L(S) * R(n) (no first-success bonus).
func _gain_v4(S: float, D: float, base_xp: float, n: int, mods := 0.0, calling := false) -> float:
	var gm = data.skills.growth_model
	if base_xp <= 0.0 or D < S - float(gm.trivial_below):
		return 0.0
	var p := _chance(S, D, mods)
	var ch = gm.challenge
	var C := clampf((1.0 - p) / float(ch.ref), float(ch.min), float(ch.max)) * minf(1.0, p / float(ch.p_low))
	var lc = gm.level_curve
	var s50 := float(lc.s50_calling) if calling else float(lc.s50)
	var L := 1.0 / (1.0 + pow(S / s50, float(lc.b)))
	var R := 1.0 / (1.0 + float(n - 1) / float(gm.repeat_rule.half_value_uses))
	return float(gm.k_skill) * base_xp * C * _expected_outcome(p) * L * R


## One day's gain in a skill: `plan` is a list of [D, base_xp, minutes] uses in order, until the waking minutes run
## out; repeats of the same D count as the same action.
func _day_v4(S: float, plan: Array, minutes: float) -> float:
	var total := 0.0
	var uses := {}
	var t := 0.0
	var i := 0
	while t < minutes and i < 200:
		var u = plan[i % plan.size()]
		i += 1
		t += float(u[2])
		var key := str(u[0]) + "/" + str(u[1])
		uses[key] = int(uses.get(key, 0)) + 1
		total += _gain_v4(S, float(u[0]), float(u[1]), int(uses[key]))
	return total


func _days_to(from: float, to: float, minutes: float) -> int:
	var s := from
	var days := 0
	while s < to and days < 400:
		s += minf(float(data.skills.growth_model.daily_cap.skill), _day_v4(s, [[s + 5.0, 4.0, 60.0], [s + 10.0, 5.0, 60.0], [s, 3.0, 60.0], [s + 15.0, 6.0, 60.0]], minutes))
		days += 1
	return days


func _check_growth() -> void:
	var gm = data.skills.growth_model
	if int(gm.get("version", 0)) != 4:
		_fail("growth: the live model is v4")
	var cap := float(gm.daily_cap.skill)
	var total_cap := float(gm.daily_cap.total_working_skills)
	# T9's "no game day above 10 points": the daily total across working skills is at most 10.
	if total_cap > 10.0 or cap > total_cap:
		_fail("growth: the daily caps must be at most 5 a skill and 10 in all (got %.1f / %.1f)" % [cap, total_cap])
	if JSON.stringify(data.backgrounds).contains("xp_mult") or JSON.stringify(data.skills.skills).contains("xp_mult"):
		_fail("growth: no experience multipliers anywhere (backgrounds are head starts)")
	# No tier unlocks: reaching a tier only makes things heard of (notices) or sets a flag; nothing is locked by tier.
	for sk in data.skills.skills:
		for tier in sk.get("tier_unlocks", {}).keys():
			var row = sk.tier_unlocks[tier]
			for k in row.keys():
				if not ["text", "flags", "notices"].has(str(k)):
					_fail("growth: %s's %s tier has '%s' (v4 tiers give flags and notices only)" % [sk.id, tier, k])
	# L(S) falls with level; a calling keeps more.
	if _gain_v4(60.0, 70.0, 4.0, 1) >= _gain_v4(30.0, 40.0, 4.0, 1):
		_fail("growth: the level curve must slow growth at higher levels")
	if _gain_v4(60.0, 70.0, 4.0, 1, 0.0, true) <= _gain_v4(60.0, 70.0, 4.0, 1):
		_fail("growth: a calling (s50 50) must keep more of the gain than a non-calling skill")
	if _gain_v4(60.0, 20.0, 4.0, 1) > 0.0:
		_fail("growth: work more than 35 below the level teaches nothing")
	# Variety beats repetition (the anti-grind rule): at each anti-grind level, a day of varied work at the edge of
	# ability earns more than one action repeated, which earns more than easy work, before the caps.
	var waking := 600.0
	for S in gm.anti_grind.levels:
		var lv := float(S)
		var varied := _day_v4(lv, [[lv + 5.0, 4.0, 60.0], [lv + 10.0, 5.0, 60.0], [lv, 3.0, 60.0], [lv + 15.0, 6.0, 60.0]], waking)
		var repeated := _day_v4(lv, [[lv + 5.0, 4.0, 60.0]], waking)
		var easy := _day_v4(lv, [[lv - 20.0, 4.0, 60.0]], waking)
		if not (varied > repeated and repeated > easy):
			_fail("growth: at S %d varied %.2f, repeated %.2f, easy %.2f (want varied > repeated > easy)" % [int(lv), varied, repeated, easy])
		notes.append("growth v4 at S %d: varied day %.2f, one action repeated %.2f, easy work %.2f (cap %.0f)" % [int(lv), varied, repeated, easy, cap])
	# Journeyman from 20: an engaged player gives a specialty about a quarter of the waking day (150 of 600 game
	# minutes) of varied work at the edge of ability; that pace sits in the engaged-specialty band. Grinding the
	# specialty all day is held to the 5-a-day cap (reported, not a target).
	var band = gm.pacing_targets.engaged_specialty_journeyman_game_days
	var days := _days_to(20.0, 40.0, 150.0)
	var grind := _days_to(20.0, 40.0, 600.0)
	if days < int(band[0]) or days > int(band[1]):
		_fail("growth: Journeyman from 20 takes %d engaged game days (target %s)" % [days, str(band)])
	if grind < int(ceil(20.0 / cap)):
		_fail("growth: grinding reaches Journeyman in %d days, faster than the daily cap allows" % grind)
	notes.append("growth v4: Journeyman from 20 in %d engaged game days (target %s); %d grinding all day (the cap binds)" % [days, str(band), grind])
	for aid in gm.no_xp_actions:
		if actions_by_id.has(aid) and float(actions_by_id[aid].base_xp) > 0.0:
			_fail("growth: %s must give no experience" % aid)
	for a in data.actions.actions:
		if str(a.skill) == "marksmanship" or str(a.skill) == "archery":
			_fail("growth: weapon skills grow from use only, but action %s rolls one" % a.id)


# ---------------------------------------------------------------- rules
func _check_rules() -> void:
	for c in data.conditions.conditions:
		for st in c.stages:
			var eff: Dictionary = st.get("effects", {})
			for bad in ["fatigue_penalty_mask", "pain_mask", "felt_warmth_offset", "courage_add"]:
				if eff.has(bad):
					_fail("drink: %s stage %s uses %s (masks may hide icons and tells only)" % [c.id, st.stage, bad])
		for a in c.get("trade_off_actions", []):
			if not known.get(a, "") == "action":
				_fail("conditions: %s's trade-off points at %s, which is not a live action" % [c.id, a])
	for k in data.conditions.modifier_contract["keys"]:
		if str(k.key) == "felt_warmth_offset":
			_fail("drink: the HUD must show the true warmth stage")
	var wakes := JSON.stringify(data.needs.time_safety.sleep_and_jobs.wake_or_interrupt_when)
	if not wakes.contains("senseless"):
		_fail("time safety: the wake rules must apply while senseless from drink")
	if not data.actions.job_runner.has("hurry"):
		_fail("actions: the hurry toggle is missing")
	var era := str(data.seasons.calendar.start_default.era)
	for b in data.backgrounds.backgrounds:
		if not known.get(b.spike, "") == "livelihood":
			_fail("backgrounds: %s's spike %s is not a live livelihood" % [b.id, b.spike])
		# v4: a background's habit (earned by doing, not a perk bought at creation) touches live systems.
		var hab := {}
		for h in data.backgrounds.habits:
			if str(h.id) == str(b.get("habit", "")):
				hab = h
		if hab.is_empty():
			_fail("backgrounds: %s's habit %s is not live" % [b.id, str(b.get("habit", ""))])
			continue
		for t in hab.get("touches", []):
			if not known.has(t):
				_fail("backgrounds: %s's habit touches %s, which is not in the slice" % [b.id, t])
		if hab.get("touches", []).is_empty():
			_fail("backgrounds: %s's habit must list the slice systems it touches" % b.id)
		if not (hab.has("earned_by") and int(hab.earned_by.get("count", 0)) > 0):
			_fail("backgrounds: habit %s must be earned by a counted practice" % hab.id)
		if not bool(b.start.get("legal", false)):
			_fail("backgrounds: %s's start must be legal and say why" % b.id)
	if data.seasons.eras.size() > 0 and str(data.seasons.eras[0].id) != era:
		_fail("start: the default era must be the live era")
	if int(data.seasons.calendar.start_default.year) != 1765:
		_fail("start: the default start is 1765")
	for f in data.npcs.factions:
		if str(f.id).begins_with("faction.nation.") or str(f.id).begins_with("faction.town.") or str(f.id) == "faction.haudenosaunee":
			_fail("representation: %s in the slice before consultation sign-off" % f.id)
	if data.npcs.has("culture_data"):
		_fail("representation: culture data ships only after sign-off (backlog)")
	for r in data.map_regions.regions:
		for z in r.land_status.values():
			if not data.map_regions.land_status.has(z):
				_fail("map: region %s uses unknown land status %s" % [r.id, z])
	for m in data.economy.markets:
		if str(m.get("rum_policy", "")) == "open":
			_fail("rum: no open rum selling at the post")
	if float(goods_by_item["item.tool.axe"].cash_retail_d) <= float(goods_by_item["item.tool.hatchet"].cash_retail_d):
		_fail("prices: a felling axe must cost more than a hatchet")
	if data.items.pelt_rules.prime_applies_to_cats != ["pelt"]:
		_fail("pelts: the prime factor applies to fur pelts only")
	var d2 := data.duplicate(true)
	for f in d2.keys():
		d2[f].erase("aliases")
	var text := JSON.stringify(d2)
	for bad in ["Schenectady boat", "brigade_arrival", "made beaver", "Trichinosis ("]:
		if text.contains(bad):
			_fail("wording: '%s' does not belong in 1765 live data" % bad)


# ---------------------------------------------------------------- T7: no coin on the critical path
## Knowledge a background starts with (known, seen, heard of) plus common knowledge, notices and mentors' talk: the
## routes that need no coin and no lesson.
func _reachable_knowledge(b: Dictionary) -> Dictionary:
	var km = data.skills.knowledge_model
	var out := {}
	for key in ["known", "seen", "heard_of"]:
		for k in b.get(key, []):
			out[str(k)] = key
	for k in km.common_knowledge:
		out[str(k)] = "common"
	for k in km.common_heard_of:
		if not out.has(str(k)):
			out[str(k)] = "heard_of"
	for k in km.get("notices", {}).keys():
		if not out.has(str(k)):
			out[str(k)] = "notice"
	for n in data.npcs.individuals:
		for k in n.get("mentor", {}).get("talk_heard_of", []):
			if not out.has(str(k)):
				out[str(k)] = "talk"
	return out


func _recipe_kid(r: Dictionary) -> String:
	return str(r.get("knowledge", r.id))


func _check_critical_path() -> void:
	var crit = data.recipes.get("critical", {})
	if crit.is_empty():
		_fail("T7: recipes.json has no critical list")
		return
	# Items the land gives with no market step: node yields, forage rows, carcass yields, and action outcomes that
	# give items (the snare's catch, the ice hole's fish).
	var base := {}
	for n in data.map_regions.resource_nodes:
		for g in n.get("gives", []):
			base[str(g)] = true
	for f in data.seasons.get("forage", []):
		base[str(f.item)] = true
	for k in data.actions.carcass_yields.keys():
		var cy = data.actions.carcass_yields[k]
		if typeof(cy) == TYPE_DICTIONARY:
			for it in cy.get("items", {}).keys():
				base[str(it)] = true
	for sp in data.actions.trap_model.get("species", {}).values():
		if typeof(sp) == TYPE_DICTIONARY and sp.has("pelt"):
			base[str(sp.pelt)] = true
	for a in data.actions.actions:
		for o in a.get("outcomes", {}).values():
			if typeof(o) != TYPE_DICTIONARY:
				continue
			for key in ["give", "give_from_node", "collect"]:
				var g = o.get(key, null)
				if typeof(g) == TYPE_DICTIONARY:
					for it in g.keys():
						if items_by_id.has(str(it)):
							base[str(it)] = true
	for b in data.backgrounds.backgrounds:
		var kn := _reachable_knowledge(b)
		var have := base.duplicate()
		for pair in b.starting_kit:
			have[str(pair[0])] = true
		# Fixpoint over the recipes this background can reach without a lesson.
		var changed := true
		var guard := 0
		while changed and guard < 20:
			changed = false
			guard += 1
			for r in data.recipes.recipes:
				if not kn.has(_recipe_kid(r)):
					continue
				var ok := true
				for it in r.get("inputs", {}).keys():
					if not have.has(str(it)):
						ok = false
				for grp in r.get("inputs_any", []):
					var any := false
					for it in grp:
						if have.has(str(it)):
							any = true
					ok = ok and any
				for grp in r.get("tools", []):
					var anyt := false
					for it in grp:
						if have.has(str(it)):
							anyt = true
					ok = ok and anyt
				if not ok:
					continue
				for it in r.get("outputs", {}).keys():
					if not have.has(str(it)):
						have[str(it)] = true
						changed = true
		for it in crit.outputs.keys():
			if not have.has(str(it)):
				_fail("T7: %s cannot make %s (%s) without a market step or a lesson" % [b.id, it, crit.outputs[it]])
		for t in crit.techniques.keys():
			if not kn.has(str(t)):
				_fail("T7: %s has no no-coin, no-lesson route to %s (%s)" % [b.id, t, crit.techniques[t]])
		notes.append("T7: %s reaches %d critical outputs and %d critical techniques with no market step" % [b.id, crit.outputs.size(), crit.techniques.size()])
		_check_consumables(b, have, kn, crit)


## T7b (fix round 1, redesign_balance_report.md F1): a path that runs on a traded consumable counts as a market step
## unless it has a no-market refill. For each critical technique and each recipe making a critical output, every item it
## consumes, and every tool it wears out (outcome "wear"), is either producible with no market step (a node, forage, a
## carcass or a known recipe), or a kit consumable whose kit supply covers the slice (recipes.json
## critical.kit_consumables: {item: {uses_needed, why}}; the kit's count x the item's uses must reach uses_needed). And a
## background that carries a musket, bar lead and a mould can refill its balls with no market step.
func _check_consumables(b: Dictionary, have: Dictionary, kn: Dictionary, crit: Dictionary) -> void:
	var kitq := {}
	for pair in b.starting_kit:
		kitq[str(pair[0])] = float(kitq.get(str(pair[0]), 0.0)) + float(pair[1])
	var kc = crit.get("kit_consumables", {})
	var needs := {}
	for t in crit.techniques.keys():
		var a := _action_row(str(t))
		if a.is_empty():
			continue
		for it in a.get("consumes", {}).keys():
			needs[str(it)] = "%s consumes it" % t
		for o in a.get("outcomes", {}).values():
			if typeof(o) == TYPE_DICTIONARY:
				for it in o.get("wear", {}).keys():
					needs[str(it)] = "%s wears it out" % t
	# Each critical output needs one recipe the background can reach whose inputs all refill with no market step (a wool
	# pair may need traded scraps while the fur or deerskin pair does not).
	for out_id in crit.outputs.keys():
		var any_free := false
		var why := []
		for r in data.recipes.recipes:
			if not r.get("outputs", {}).has(str(out_id)) or not kn.has(_recipe_kid(r)):
				continue
			var free := true
			for it in r.get("inputs", {}).keys():
				if not (have.has(str(it)) and _made_without_market(str(it), kn)) and not kc.has(str(it)):
					free = false
					why.append("%s needs %s" % [r.id, it])
			if free:
				any_free = true
		if not any_free:
			_fail("T7b: %s: every recipe for %s runs on a traded input (%s)" % [b.id, out_id, ", ".join(PackedStringArray(why))])
	var checked := 0
	for it in needs.keys():
		var tag := str(it)
		if tag in ["tinder", "flame_tinder", "fuel"] or tag.begins_with("item.fuel.") or tag.begins_with("item.tinder."):
			continue
		checked += 1
		if have.has(tag) and _made_without_market(tag, kn):
			continue
		var row = kc.get(tag, null)
		if row == null:
			_fail("T7b: %s: %s (%s) has no no-market refill and is not a listed kit consumable" % [b.id, tag, needs[tag]])
			continue
		var uses := float(items_by_id.get(tag, {}).get("uses", 1.0))
		var supply := float(kitq.get(tag, 0.0)) * maxf(1.0, uses)
		if supply < float(row.uses_needed) - 0.001:
			_fail("T7b: %s carries %.0f uses of %s; the slice needs %.0f (%s)" % [b.id, supply, tag, float(row.uses_needed), str(row.get("why", ""))])
	# Musket hunting is not a critical path; where a background carries lead and a mould, its balls refill by hand.
	if kitq.has("item.weapon.musket") and kitq.has("item.ammo.lead") and kitq.has("item.tool.bullet_mould"):
		var cast := false
		for r in data.recipes.recipes:
			if r.get("outputs", {}).has("item.ammo.ball") and kn.has(_recipe_kid(r)):
				cast = true
		if not cast:
			_fail("T7b: %s carries lead and a mould but cannot cast balls with no market step" % b.id)
		else:
			notes.append("T7b: %s refills musket balls from its own lead (craft.cast_balls)" % b.id)
	notes.append("T7b: %s's critical paths consume or wear %d items; each has a no-market refill or the kit covers the slice" % [b.id, checked])


## An item some live source gives with no market step: a node, forage, a carcass, or a recipe the background can reach.
func _made_without_market(item: String, kn: Dictionary) -> bool:
	for n in data.map_regions.resource_nodes:
		if n.get("gives", []).has(item):
			return true
	for f in data.seasons.get("forage", []):
		if str(f.item) == item:
			return true
	for k in data.actions.carcass_yields.keys():
		var cy = data.actions.carcass_yields[k]
		if typeof(cy) == TYPE_DICTIONARY and cy.get("items", {}).has(item):
			return true
	for r in data.recipes.recipes:
		if r.get("outputs", {}).has(item) and kn.has(_recipe_kid(r)):
			return true
	return false


func _action_row(id: String) -> Dictionary:
	for a in data.actions.actions:
		if str(a.id) == id:
			return a
	return {}


# ---------------------------------------------------------------- knowledge routes (rule L2) and mentors
func _check_knowledge() -> void:
	var km = data.skills.knowledge_model
	var common := {}
	for k in km.common_knowledge:
		common[str(k)] = true
	var taught := {}
	for n in data.npcs.individuals:
		var m = n.get("mentor", {})
		for t in m.get("teaches", []):
			if t.has("id"):
				taught[str(t.id)] = true
			var asks = t.get("asks", [])
			var non_coin := false
			for a in asks:
				if typeof(a) == TYPE_DICTIONARY and not (a.size() == 1 and a.has("coin")):
					non_coin = true
			if not asks.is_empty() and not non_coin:
				_fail("mentors: %s asks only coin for %s (redesign_skills.md 6: always a non-coin way)" % [n.id, str(t.get("id", t.get("skill", "?")))])
	var know_rows := {}
	for k in data.skills.get("knowledge", []):
		know_rows[str(k.id)] = k
	var gated := []
	for r in data.recipes.recipes:
		if not r.has("knowledge"):
			gated.append([str(r.id), r.get("routes", {})])
	for k in know_rows.keys():
		gated.append([k, know_rows[k].get("routes", {})])
	for a in data.actions.actions:
		if bool(a.get("technique", false)) and not common.has(str(a.id)):
			gated.append([str(a.id), a.get("routes", {})])
	var no_coin := ["common", "watch", "examine", "trial", "notice"]
	for g in gated:
		var kid := str(g[0])
		var routes := {}
		for k in g[1].keys():
			routes[str(k)] = true
		if taught.has(kid):
			routes["taught_by"] = true
		if km.get("notices", {}).has(kid):
			routes["notice"] = true
		if common.has(kid):
			routes["common"] = true
		if not kid.begins_with("rcp.") and not kid.begins_with("know."):
			routes["trial"] = true
		var free := false
		for r in no_coin:
			if routes.has(r):
				free = true
		if routes.size() < 2 and not routes.has("common"):
			_fail("knowledge: %s has %d route(s) %s; rule L2 wants two" % [kid, routes.size(), str(routes.keys())])
		if not free:
			_fail("knowledge: %s has no route needing no coin and no background" % kid)


func _check_anim_hooks() -> void:
	var lib := {}
	var metrics = _load_json(CLIP_METRICS)
	if metrics != null:
		for k in metrics.clips.keys():
			lib[k] = true
	var used := {}
	for a in data.actions.actions:
		used[a.anim] = true
	for act in data.npcs.activities.values():
		if act.anim != null:
			used[act.anim] = true
	var hooks := {}
	for h in data.actions.anim_hooks:
		hooks[h.id] = h
	for h in data.actions.anim_hooks:
		for c in h.clips:
			if str(c.asset_id).is_empty():
				_fail("anim hook %s: clip %s has no asset id" % [h.id, c.clip])
			if bool(c.in_frontier_library) and not lib.is_empty() and not lib.has(c.clip):
				_fail("anim hook %s: %s is flagged as in the Frontier library but is missing" % [h.id, c.clip])
		if not bool(h.get("ready_now", true)) and not h.has("fallback_hook") and h.clips.size() > 0:
			_fail("anim hook %s is not ready and has no fallback hook" % h.id)
		if h.has("fallback_hook") and not hooks.has(h.fallback_hook):
			_fail("anim hook %s: unknown fallback %s" % [h.id, h.fallback_hook])
	for id in used.keys():
		if not known.get(id, "") == "anim hook":
			_fail("unknown anim hook %s" % id)
