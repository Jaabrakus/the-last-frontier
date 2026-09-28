class_name SurvivalNpcs
extends RefCounted
## Where each NPC is and what it is doing, from its archetype's schedule (npcs.json schedule_rules): the "record" tier
## of the NPC architecture, logic only. The world later places bodies where this says; nothing here spawns anything.
##
## Schedule keys, highest priority first: state:<role state> (sick, away_hunting, on_campaign, ...), event:<event id
## without the "event." prefix>, date:<day id>, season:<season>+weather:<state>, season:<season>, default. A key's
## value is a list of blocks [start "HH:MM", location, activity], or {inherit: key, replace: {activity: activity},
## outdoor_to: location} to reuse another key with changes. Locations: home, work, away, poi:<id>, spot:<tag>.
## In the slice every NPC goes by a role title (npcs.json release_rule); draft names are not shown.

const INDOOR_LOCATIONS := ["home"]


static func individual(core: SurvivalCore, npc_id: String) -> Dictionary:
	return SurvivalUtil.dict(core.data.individuals.get(npc_id))


static func archetype_of(core: SurvivalCore, npc_id: String) -> Dictionary:
	return SurvivalUtil.dict(core.data.archetypes.get(str(individual(core, npc_id).get("archetype", ""))))


## A role state that overrides the schedule (state:<role state> keys); "" clears it.
static func set_role_state(core: SurvivalCore, npc_id: String, role_state: String) -> void:
	if role_state == "":
		core.state.npc_states.erase(npc_id)
	else:
		core.state.npc_states[npc_id] = role_state


## The schedule key in force now for an archetype's schedule.
static func schedule_key(core: SurvivalCore, npc_id: String, sched: Dictionary) -> String:
	var rs := str(core.state.npc_states.get(npc_id, ""))
	if rs != "" and sched.has("state:" + rs):
		return "state:" + rs
	for k in sched.keys():
		var ks := str(k)
		if ks.begins_with("event:"):
			var ev := ks.trim_prefix("event:")
			if SurvivalClock.event_active(core, ev) or SurvivalClock.event_active(core, "event." + ev):
				return ks
	var day := "date:" + SurvivalClock.day_id(core)
	if sched.has(day):
		return day
	var season := SurvivalClock.season(core)
	var sw := "season:%s+weather:%s" % [season, SurvivalWeather.state_id(core)]
	if sched.has(sw):
		return sw
	if sched.has("season:" + season):
		return "season:" + season
	return "default"


## Resolve a key to its list of blocks (following inherit, replace and outdoor_to).
static func blocks_for(sched: Dictionary, key: String, depth: int = 0) -> Array:
	var v = sched.get(key, sched.get("default", []))
	if typeof(v) == TYPE_ARRAY:
		return v
	if typeof(v) != TYPE_DICTIONARY or depth > 4:
		return []
	var base := blocks_for(sched, str(v.get("inherit", "default")), depth + 1)
	var rep := SurvivalUtil.dict(v.get("replace"))
	var outdoor_to := str(v.get("outdoor_to", ""))
	var out := []
	for b in base:
		var nb: Array = SurvivalUtil.arr(b).duplicate()
		if nb.size() >= 3:
			if rep.has(str(nb[2])):
				nb[2] = rep[str(nb[2])]
			if outdoor_to != "" and not INDOOR_LOCATIONS.has(str(nb[1])) and str(nb[1]) != "away":
				nb[1] = outdoor_to
		out.append(nb)
	return out


static func _block_hour(b: Array) -> float:
	var t := str(b[0]).split(":")
	return float(t[0]) + (float(t[1]) / 60.0 if t.size() > 1 else 0.0)


## Where an NPC is now: {npc, title, key, location (a POI id, a spot tag, or "" when away), activity, anim, present,
## market, market_open}.
static func where(core: SurvivalCore, npc_id: String) -> Dictionary:
	var ind := individual(core, npc_id)
	var arch := archetype_of(core, npc_id)
	var out := {"npc": npc_id, "title": core.npc_title(npc_id), "key": "", "location": "", "activity": "", "anim": "",
			"present": false, "market": str(arch.get("market", "")), "market_open": false}
	if ind.is_empty() or arch.is_empty():
		return out
	var sched := SurvivalUtil.dict(arch.get("schedule"))
	var key := schedule_key(core, npc_id, sched)
	var blocks := blocks_for(sched, key)
	out.key = key
	if blocks.is_empty():
		return out
	var h := SurvivalClock.hour(core)
	var cur: Array = blocks[blocks.size() - 1]
	for b in blocks:
		if SurvivalUtil.arr(b).size() >= 3 and _block_hour(b) <= h + 0.0001:
			cur = b
	var loc := str(cur[1])
	match loc:
		"home":
			loc = str(ind.get("home", ""))
		"work":
			loc = str(ind.get("work", ""))
		"away":
			loc = ""
		_:
			if loc.begins_with("poi:"):
				loc = loc.trim_prefix("poi:")
			elif loc.begins_with("spot:"):
				loc = loc.trim_prefix("spot:")
	var act := str(cur[2])
	out.location = loc
	out.activity = act
	out.anim = str(SurvivalUtil.dict(core.data.section("npcs", "activities").get(act)).get("anim", ""))
	out.present = loc != ""
	if out.market != "":
		out.market_open = SurvivalEconomy.is_open(core, str(out.market)) and out.present
	return out


## Game minutes from now until an NPC leaves `loc` or stops being available there (asleep, away, elsewhere), on today's
## schedule; at most until midnight. 0 when it is not there now.
static func minutes_until_leaves(core: SurvivalCore, npc_id: String, loc: String) -> float:
	var w := where(core, npc_id)
	if not bool(w.present) or str(w.location) != loc or str(w.activity) == "sleep":
		return 0.0
	var ind := individual(core, npc_id)
	var sched := SurvivalUtil.dict(archetype_of(core, npc_id).get("schedule"))
	var blocks := blocks_for(sched, schedule_key(core, npc_id, sched))
	var h := SurvivalClock.hour(core)
	var end_h := 24.0
	for b in blocks:
		if SurvivalUtil.arr(b).size() < 3 or _block_hour(b) <= h + 0.0001:
			continue
		var bl := str(b[1])
		match bl:
			"home":
				bl = str(ind.get("home", ""))
			"work":
				bl = str(ind.get("work", ""))
			"away":
				bl = ""
			_:
				bl = bl.trim_prefix("poi:").trim_prefix("spot:")
		if bl != loc or str(b[2]) == "sleep":
			end_h = minf(end_h, _block_hour(b))
			break
	return maxf(0.0, (end_h - h) * 60.0)


## Every NPC at a POI now.
static func present_at(core: SurvivalCore, poi: String) -> Array:
	var out := []
	for id in core.data.individuals.keys():
		var w := where(core, str(id))
		if bool(w.present) and str(w.location) == poi:
			out.append(w)
	return out


## Dialogue topics an NPC offers now (npcs.json dialogue_topics), with what each opens.
static func topics(core: SurvivalCore, npc_id: String) -> Array:
	var out := []
	var arch := archetype_of(core, npc_id)
	var rows := {}
	for t in SurvivalUtil.arr(core.data.raw.npcs.get("dialogue_topics")):
		rows[str(t.get("id", ""))] = t
	for tid in SurvivalUtil.arr(arch.get("topics")):
		var row := SurvivalUtil.dict(rows.get(str(tid)))
		var ok := true
		match str(tid):
			"request.firewood":
				ok = SurvivalEconomy.contract_open(core)
			"trade.offer", "trade.credit", "trade.needs", "work.offer":
				ok = SurvivalTrade.partner_present(core, npc_id) or (str(arch.get("market", "")) != "" and SurvivalEconomy.is_open(core, str(arch.market)))
			"learn.ask":
				ok = not SurvivalLearning.mentor(core, npc_id).is_empty() and not core.data.action("social.ask_teach").is_empty()
			"learn.ask_about":
				ok = not SurvivalUtil.arr(SurvivalLearning.mentor(core, npc_id).get("talk_heard_of")).is_empty()
		out.append({"id": str(tid), "cat": str(row.get("cat", "")), "available": ok, "effects": SurvivalUtil.arr(row.get("effects"))})
	return out


## Is an NPC about at some time today (not away all day)? The local price cap compares what the partners present that
## day offer (economy.json barter.local_cap).
static func present_today(core: SurvivalCore, npc_id: String) -> bool:
	var arch := archetype_of(core, npc_id)
	if arch.is_empty():
		return false
	var sched := SurvivalUtil.dict(arch.get("schedule"))
	var blocks := blocks_for(sched, schedule_key(core, npc_id, sched))
	for b in blocks:
		if SurvivalUtil.arr(b).size() >= 3 and str(b[1]) != "away":
			var loc := str(b[1])
			if loc == "home" and str(individual(core, npc_id).get("home", "")) == "":
				continue
			return true
	return false


## Trade and lesson partners at the player's location now (market, job and lesson menus).
static func partners_here(core: SurvivalCore) -> Array:
	return SurvivalTrade.partners_here(core)
