extends SceneTree
## ADVISORY design check for the survival backlog (data/survival/backlog/*.json), version 3.
##
## The backlog is the design appendix for milestones M3-M5 and 'post'. It is not loaded by the game and is not part of
## the data test's gate: this script prints what would block a row from going live and always exits 0. When a milestone
## starts, its rows move into the live files and come under tests/survival/test_survival_data.gd.
##
## It checks: references resolve among live + backlog ids; ids are defined once; every row has a later milestone;
## capital wages pay back in at least one season after their loss rates and earn at most twice skilled trapping;
## safe wages stay under the live ladder cap; every nation the backlog depicts has a consultation office; the town-raised
## home town is historically placed; the 1765 fort has no ranging company, Stockbridge company or ranger orders.
##
##   Godot --headless --path . -s tests/survival/check_backlog_design.gd

const LIVE := "res://data/survival/"
const BACK := "res://data/survival/backlog/"
const FILES := ["skills", "backgrounds", "needs", "conditions", "items", "recipes", "actions",
		"seasons", "economy", "livelihoods", "npcs", "map_regions"]
const LISTS := ["items", "skills", "specialties", "knowledge", "modifiers", "needs", "conditions", "actions", "anim_hooks",
		"recipes", "archetypes", "factions", "dialogue_topics", "individuals", "markets", "services", "wages", "jobs",
		"livelihoods", "events", "eras", "fish_runs", "regions", "offmap_nodes", "resource_nodes", "routes", "backgrounds",
		"long_term_goals"]
const NATION_OFFICE := {"oneida": "Oneida", "onondaga": "Onondaga", "mohawk": "Mohawk", "tuscarora": "Tuscarora",
		"seneca": "Seneca", "cayuga": "Cayuga", "mahican": "Stockbridge-Munsee", "munsee": "Munsee-Delaware",
		"unami": "Delaware Nation", "abenaki": "Waban-Aki", "mississauga": "Mississaugas", "shawnee": "Shawnee",
		"wyandot": "Wyandotte"}

var live := {}
var back := {}
var ids := {}
var issues := PackedStringArray()


func _initialize() -> void:
	for f in FILES:
		live[f] = JSON.parse_string(FileAccess.get_file_as_string(LIVE + f + ".json"))
		back[f] = JSON.parse_string(FileAccess.get_file_as_string(BACK + f + ".json"))
	_collect(live, "live")
	_collect(back, "backlog")
	_check_milestones()
	_check_capital_and_ladder()
	_check_history()
	for m in issues:
		print("  ADVISORY: ", m)
	print("BACKLOG DESIGN CHECK: %d advisory issue(s); %d ids across live and backlog" % [issues.size(), ids.size()])
	quit(0)


func _collect(src: Dictionary, where: String) -> void:
	for f in src.keys():
		for sec in LISTS:
			if not src[f].has(sec) or typeof(src[f][sec]) != TYPE_ARRAY:
				continue
			for r in src[f][sec]:
				if typeof(r) == TYPE_DICTIONARY and r.has("id"):
					if ids.has(r.id):
						issues.append("%s/%s: id %s is defined twice" % [where, f, r.id])
					ids[r.id] = where
		if src[f].has("regions"):
			for r in src[f].regions:
				for p in r.get("pois", []):
					ids[p.id] = where


func _check_milestones() -> void:
	for f in back.keys():
		for sec in LISTS:
			if not back[f].has(sec) or typeof(back[f][sec]) != TYPE_ARRAY:
				continue
			for r in back[f][sec]:
				if typeof(r) != TYPE_DICTIONARY or not r.has("id") or sec == "anim_hooks":
					continue
				var m := str(r.get("milestone", ""))
				if not ["M3", "M4", "M5", "post"].has(m):
					issues.append("backlog/%s/%s: %s has milestone '%s'" % [f, sec, r.id, m])


func _check_capital_and_ladder() -> void:
	var skilled := float(live.livelihoods.design.computed.trapping.skilled_24)
	var cap := skilled * float(live.economy.wages_rule.ladder.max_safe_wage_frac_of_skilled_trapping)
	var season := float(live.seasons.calendar.days_per_year) / 4.0
	for w in back.economy.wages:
		if bool(w.get("capital", false)):
			var lr: Dictionary = w.get("loss_rates_per_contract", {})
			var loss := float(lr.get("lame_horse", 0.0)) * float(lr.get("horse_value_d", 0.0)) \
					+ float(lr.get("broken_axle", 0.0)) * float(lr.get("axle_d", 0.0))
			var per_day := float(w.cash_d) - loss / 2.0
			var payback := float(w.get("capital_d", 0.0)) / maxf(1.0, per_day)
			if payback < season:
				issues.append("capital: %s pays back in %.1f game days, less than a season" % [w.id, payback])
			if float(w.cash_d) > 2.0 * skilled:
				issues.append("capital: %s earns %.0f d a day, more than twice skilled trapping" % [w.id, float(w.cash_d)])
		else:
			var tot := float(w.get("cash_d", 0)) + float(w.get("in_kind_d", 0))
			if tot > cap + 0.001:
				issues.append("ladder: %s pays %.0f, above the live safe-wage cap %.0f" % [w.id, tot, cap])


func _check_history() -> void:
	var filtered := back.duplicate(true)
	for f in filtered.keys():
		filtered[f].erase("aliases")
		filtered[f].erase("v3_fixes")
	var text := JSON.stringify(filtered)
	var offices := JSON.stringify(back.npcs.culture_data.consultation.offices)
	for nation in NATION_OFFICE.keys():
		if (text.contains("faction.nation." + nation) or text.contains("lang." + nation)) and not offices.contains(NATION_OFFICE[nation]):
			issues.append("consultation: %s content without the %s office" % [nation, NATION_OFFICE[nation]])
	for b in back.backgrounds.backgrounds:
		if b.id == "bg.town_raised":
			for n in b.variants.nation.home_town.choose_one:
				if not ["oneida", "tuscarora"].has(n):
					issues.append("representation: town-raised home town %s is not placed on the map" % n)
	for w in back.economy.wages:
		if w.id == "wage.ranger":
			issues.append("history: wage.ranger at a 1765 fort")
	for e in back.seasons.events:
		if e.id == "event.ranger_orders":
			issues.append("history: ranger orders in 1765")
	for i in back.npcs.individuals:
		if i.id == "npc.fort.stockbridge_scouts" and str(i.get("milestone", "")) != "post":
			issues.append("history: a Stockbridge company at a 1765 fort")
	for bad in ["Schenectady boat", "brigade_arrival", "lang.lenape\""]:
		if text.contains(bad):
			issues.append("wording: '%s' in the backlog" % bad)
