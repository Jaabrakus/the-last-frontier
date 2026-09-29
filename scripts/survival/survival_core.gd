class_name SurvivalCore
extends RefCounted
## The survival hub: one character's survival simulation in one world, logic only. In single-player it is the
## authority: the same code that will host co-op (multiplayer_readiness.md): commands come in through the calls below
## and events go out through the signals.
##
## Holds the read-only design data (SurvivalData), the saveable state (SurvivalState: the world records and one player's
## records, survival GDD v4), the shared random-number stream of the v3 systems and the named streams of the v4 ones
## (SurvivalStreams). The modules (SurvivalClock, SurvivalWeather, SurvivalNeeds, SurvivalConditions, SurvivalExposure,
## SurvivalSkills, SurvivalLearning, SurvivalInventory, SurvivalFood, SurvivalCamp, SurvivalCrafting, SurvivalNodes,
## SurvivalTrapLine, SurvivalJobs, SurvivalEconomy, SurvivalTrade, SurvivalAlmanac, SurvivalNpcs) are stateless function
## libraries over this object, so a save is just the state.
##
## Nothing here touches a node, the scene tree, animation, UI or Engine.time_scale. The game integrates later by:
##   - setting what is around the player:  set_context({location, near, fire_distance_m, in_shelter, indoors, cell, ...})
##   - telling it what the player does:    set_activity("walk"), report_kill(), report_weapon_event(), report_threat()
##   - driving time:                       update(real_seconds) each frame (or advance(game_minutes) in tools and tests)
##   - reading effects:                    get_modifiers(), get_weapon_modifiers("musket"), need_stages(), icons()
##   - running actions:                    preview(action_id) for the prompt, start_job(action_id, params), cancel_job()
##   - trading (the one trade window):     open_trade(partner), trade_lines(tr, lines) (your side), trade_request(tr,
##                                         lines) (an NPC partner's side), trade_confirm(tr, version), trade_view(tr),
##                                         barter(partner, give, take); obligations(), work_off(ob, minutes)
##   - learning:                           recipe_book(), lesson_offers(mentor), arrange_lesson(mentor, what, ask),
##                                         watchable(), examine via run_job("learn.examine", {item})
##   - listening to the signals below.
## Design: source/graph_analysis/survival/survival_gdd.md; API notes: survival_core_api.md there.

## Game minutes are simulated in steps of at most this size (needs, fires and conditions stay smooth) [D].
const STEP_MIN := 10.0
## The trap line's nightly roll happens as the clock passes dawn [D].
const DAWN_HOUR := 6.0
## Fatigue collapse: pass out 2-4 game hours where you stand (needs.json need.rest stages).
const COLLAPSE_H := [2.0, 4.0]
## Journal lines kept in the state.
const JOURNAL_CAP := 200
## POIs treated as indoors when no context says otherwise [D].
const INDOOR_POIS := ["poi.fort.sutler_store", "poi.fort.barracks", "poi.fort.officers_quarters", "poi.fort.headquarters"]
## The line camp has the manor woods' nodes at hand [D: the camp sits in the woods].
const CAMP_POIS := {"poi.fort.woods_camp": "poi.fort.woods"}
## Nodes every campsite in the woods has besides its POI's list [D: 12 sapling stands a square km,
## map_regions.json nodes_per_km2; lean-tos, stakes and stretching hoops are cut on the spot].
const CAMP_EXTRA_NODES := ["node.sapling_stand"]

## Game time moved on by one advance() or update() call.
signal time_advanced(game_minutes: float)
## A new game day began (abs_day counts from the base year; day_id is "oct_mid" and the like).
signal day_started(abs_day: int, day_id: String)
## A need's stage changed (need.food: "fed" -> "peckish").
signal need_stage_changed(need_id: String, old_stage: String, new_stage: String)
## The combined modifiers changed (the player and HUD read these; see conditions.json modifier_contract).
signal modifiers_changed(mods: Dictionary)
signal condition_added(id: String, stage: String)
signal condition_stage_changed(id: String, old_stage: String, new_stage: String)
signal condition_removed(id: String)
signal skill_changed(id: String, old_level: float, new_level: float)
signal skill_tier_reached(id: String, tier: String)
signal inventory_changed()
signal fire_changed(fire_id: String, fire_state: String)
signal trap_changed(trap_id: String, trap_state: String)
signal trap_caught(trap_id: String, species: String)
signal weather_changed(old_state: String, new_state: String)
## A calendar event opened (started = true) or closed.
signal calendar_event(event_id: String, started: bool)
signal money_changed(pence: int)
signal account_changed(creditor: String, balance_d: float)
signal standing_changed(faction: String, value: float)
signal settlement(creditor: String, grade: String, result: Dictionary)
## Jobs (SurvivalJobs): the anim hook to request is in job.anim.
signal job_started(job: Dictionary)
signal job_finished(result: Dictionary)
signal job_interrupted(job: Dictionary, reason: String)
signal passed_out(reason: String, hours: float)
signal woke(reason: String)
signal died(cause: String)
signal journal_line(entry: Dictionary)
## Emitted after sleep (the GDD's three rotating autosaves on sleep and quit); SurvivalRuntime or the game saves.
## It comes once the step (or the cancel) that ended the sleep has been fully applied, so the save is a whole state,
## and never for a character who died: what death does to saves is the game's call (the GDD's open death rule).
signal autosave_requested(reason: String)
## v4: a recipe or technique's knowledge state changed (unknown, heard_of, seen, known, practised, mastered).
signal knowledge_changed(id: String, old_state: String, new_state: String)
## A notice: simple work discovered blind ("the inner bark strips into long ribbons").
signal notice(id: String, text: String)
signal lesson_finished(teacher_id: String, what: String, result: Dictionary)
signal watched(action_id: String, performer_id: String)
## A trade session committed by the authority (the ledger entry: parties, lines, rv moved).
signal trade_committed(tr_id: String, entry: Dictionary)
signal obligation_changed(ob_id: String, status: String)
signal trust_changed(npc_id: String, value: float)
signal habit_earned(habit_id: String)

static var _data_cache := {}

var data: SurvivalData
var state: SurvivalState
var rng := RandomNumberGenerator.new()
## While paused, update() does nothing (menus pause the clock: seasons.json clock.pause_in_menus).
var paused := false
var _mods := {}
var _mods_dirty := true
var _mods_key := ""
var _suppress_signals := false
var _autosave_reason := ""
## Named random streams in use (SurvivalStreams); their state is saved in state.world.streams.
var _streams := {}
## Signals queued while a trade commits (defer_signals).
var _defer_depth := 0
var _deferred := []


# ---------------------------------------------------------------- creation and loading
## Shared, read-only data per directory and backlog merge (loading the JSON once per run).
static func load_data(opts: Dictionary = {}) -> SurvivalData:
	var dir := str(opts.get("data_dir", SurvivalData.DEFAULT_DIR))
	var ms: Array = SurvivalUtil.arr(opts.get("backlog_milestones", []))
	var names := PackedStringArray()
	for m in ms:
		names.append(str(m))
	var key := dir + "|" + ",".join(names)
	if bool(opts.get("reload", false)) or not _data_cache.has(key):
		_data_cache[key] = SurvivalData.load_dir(dir, {"backlog_milestones": ms})
	return _data_cache[key]


## A new character. opts:
##   seed (int), preset ("settler" | "woodsman" | "hard_winter" | "ironman"), start_day ("sep_early"), start_year (1765),
##   start_hour (8.0), backlog_milestones (["M3"] merges later rows: fishing, frogs, foraging, ...), settings
##   (thirst_enabled, service_setting "historical" | "open", militia_role "men" | "women", service_variant, ledger_toggle),
##   start_variant ("start.clear" by default; "start.outfitted_on_credit", "start.sutler_tally", "start.promise"), data.
static func new_game(background_id: String = "", opts: Dictionary = {}) -> SurvivalCore:
	var core := SurvivalCore.new()
	var d = opts.get("data")
	core.data = d if d is SurvivalData else load_data(opts)
	core.state = SurvivalState.new()
	core._init_new(background_id, opts)
	return core


## Rebuild a core around a loaded state (SurvivalSave). The data merge recorded in the state is used again.
static func from_state(st: SurvivalState, opts: Dictionary = {}) -> SurvivalCore:
	var core := SurvivalCore.new()
	var d = opts.get("data")
	if d is SurvivalData:
		core.data = d
	else:
		var o := opts.duplicate()
		o["backlog_milestones"] = SurvivalUtil.arr(st.settings.get("backlog_milestones", []))
		core.data = load_data(o)
	core.state = st
	core.rng.seed = st.rng_seed
	core.rng.state = st.rng_state
	core._mods_dirty = true
	core._streams = {}
	return core


func is_ok() -> bool:
	return data != null and data.is_ok() and state != null


func _init_new(background_id: String, opts: Dictionary) -> void:
	var st := state
	var sr := data.section("backgrounds", "start_rules")
	if background_id == "":
		var m1 := SurvivalUtil.arr(SurvivalUtil.dict(sr.get("slice_backgrounds")).get("M1"))
		background_id = str(m1[0]) if not m1.is_empty() else str(data.backgrounds.keys()[0])
	var seed_v := int(opts.get("seed", 0))
	if seed_v == 0:
		seed_v = int(Time.get_ticks_usec()) ^ 0x5eed
	rng.seed = seed_v
	st.rng_seed = seed_v
	st.background_id = background_id
	st.preset = str(opts.get("preset", "woodsman"))
	var settings := {"thirst_enabled": false, "service_setting": "historical", "militia_role": "men",
			"night_compression": true, "backlog_milestones": SurvivalUtil.arr(opts.get("backlog_milestones", [])).duplicate()}
	for k in SurvivalUtil.dict(opts.get("settings")).keys():
		settings[k] = opts.settings[k]
	st.settings = settings
	var ds := SurvivalUtil.dict(sr.get("default_start"))
	var start_day := str(opts.get("start_day", ds.get("day", "sep_early")))
	st.base_year = int(opts.get("start_year", SurvivalUtil.num(ds.get("year"), 1765.0)))
	var doy := maxi(0, data.day_ids.find(start_day))
	var start_hour := float(opts.get("start_hour", 8.0))
	st.minutes = float(doy) * SurvivalClock.MIN_PER_DAY + start_hour * 60.0
	st.flags = {"last_abs_day": SurvivalClock.abs_day(self),
			"last_dawn_day": SurvivalClock.abs_day(self) - (0 if start_hour >= DAWN_HOUR else 1)}
	st.jobs = {"current": {}, "progress": {}}
	st.stats = {"days": 0, "checks": {}, "wakes": 0, "cold_stage_h": {}, "catches": 0}
	st.world = {"ids": {}, "nodes": {}, "trade": {}, "obligations": {}, "caches": {}, "racks": {}, "builds": {}, "streams": {},
			"clock_acc": 0.0}
	st.player_id = "pl.1"
	st.players = {"pl.1": {"id": "pl.1", "knowledge": {}, "learning": {}, "trust": {}, "habits": [], "counters": {}, "wear": {}}}
	var bg := background()
	var variant := _start_variant(background_id, str(opts.get("start_variant", "")))
	st.settings["start_variant"] = str(variant.get("id", "start.clear"))
	var start := SurvivalUtil.dict(bg.get("start"))
	var poi := str(start.get("poi", "poi.fort.woods_camp"))
	st.context = context_for_poi(poi)
	st.context["region"] = str(start.get("region", SurvivalClock.DEFAULT_REGION))
	_suppress_signals = true
	if bool(st.context.get("indoors", false)):
		SurvivalCamp.ensure_hearth(self, poi)
	SurvivalNeeds.init(self)
	SurvivalWeather.init(self)
	SurvivalTrapLine.init(self)
	for sk in data.skills.keys():
		st.skills[sk] = SurvivalUtil.num(SurvivalUtil.dict(bg.get("skills")).get(sk), 0.0)
	for pair in SurvivalUtil.arr(bg.get("starting_kit")) + SurvivalUtil.arr(variant.get("kit_add")):
		SurvivalInventory.add(self, str(pair[0]), SurvivalUtil.num(pair[1], 1.0))
	# A newcomer's kit for the season they arrive in (start.clear season_kit: provisions and hooks and line in winter).
	var sk := SurvivalUtil.dict(variant.get("season_kit"))
	if not sk.is_empty() and SurvivalClock.in_window(self, [str(sk.get("from", "")), str(sk.get("to", ""))]):
		var only := SurvivalUtil.arr(sk.get("only_if_missing"))
		for pair in SurvivalUtil.arr(sk.get("add")):
			if only.has(str(pair[0])) and SurvivalInventory.has(self, str(pair[0])):
				continue
			SurvivalInventory.add(self, str(pair[0]), SurvivalUtil.num(pair[1], 1.0))
	SurvivalInventory.wear_all_clothing(self)
	# A head start, never a lock (backgrounds.json rules): known recipes, people and a habit anyone can earn.
	SurvivalLearning.init_from_background(self, bg)
	for npc in SurvivalUtil.dict(bg.get("people")).keys():
		player().trust[str(npc)] = SurvivalUtil.num(bg.people[npc], 0.0)
	if str(bg.get("habit", "")) != "":
		player().habits.append(str(bg.habit))
	SurvivalEconomy.init(self, bg, variant)
	if variant.has("promise") and not data.action("social.ask_teach").is_empty():
		SurvivalTrade.add_start_promise(self, SurvivalUtil.dict(variant.promise))
	SurvivalConditions.update_driven(self)
	st.need_stages = SurvivalNeeds.stages(self)
	_suppress_signals = false
	log_line("%s: %s begins at %s" % [SurvivalClock.date_string(self), str(bg.get("name", background_id)),
			npc_title(poi)], "start")


## The context the game (or the sim) passes for a POI when it has nothing better: indoors for fort buildings, the
## POI's resource nodes from map_regions.json, and the woods' nodes at the line camp.
func context_for_poi(poi: String) -> Dictionary:
	var ctx := {"location": poi, "near": [], "indoors": INDOOR_POIS.has(poi), "fire_distance_m": 1.5, "in_shelter": true}
	var nodes_from := str(CAMP_POIS.get(poi, poi))
	for r in data.regions.values():
		for p in SurvivalUtil.arr(r.get("pois")):
			if str(p.get("id", "")) == nodes_from:
				for n in SurvivalUtil.arr(p.get("nodes")):
					ctx.near.append(str(n))
	if CAMP_POIS.has(poi):
		for n in CAMP_EXTRA_NODES:
			if not ctx.near.has(n):
				ctx.near.append(n)
	if poi == "poi.fort.woodpile":
		ctx.near.append("world.woodpile")
		ctx.near.append("node.deadwood")
	return ctx


# ---------------------------------------------------------------- accessors used by the modules
func background() -> Dictionary:
	return data.background(state.background_id)


## A setting from state.settings (difficulty options, thirst, service setting, clock rates).
func setting(key: String, def = null):
	return state.settings.get(key, def)


## The start variant row for a background (backgrounds.json start_variants); the default variant when none is named.
func _start_variant(bg_id: String, vid: String) -> Dictionary:
	if vid == "":
		vid = str(data.section("backgrounds", "start_rules").get("default_variant", "start.clear"))
	var v := SurvivalUtil.dict(data.start_variants.get(vid))
	if v.is_empty():
		return {"id": "start.clear"}
	var allowed := SurvivalUtil.arr(v.get("backgrounds"))
	if not allowed.is_empty() and not allowed.has(bg_id):
		push_warning("start variant %s is not offered to %s; starting Clear" % [vid, bg_id])
		return SurvivalUtil.dict(data.start_variants.get("start.clear", {"id": "start.clear"}))
	return v


## The local player's own records (knowledge, learning, trust, habits, clothing wear): SurvivalState.players[player_id].
func player() -> Dictionary:
	var pid := state.player_id
	if not state.players.has(pid):
		state.players[pid] = {"id": pid, "knowledge": {}, "learning": {}, "trust": {}, "habits": [], "counters": {}, "wear": {}}
	var p: Dictionary = state.players[pid]
	for k in ["knowledge", "learning", "trust", "counters", "wear"]:
		if not p.has(k):
			p[k] = {}
	if not p.has("habits"):
		p["habits"] = []
	return p


## The world records (node stocks, trade sessions and ledger, obligations, caches, racks, builds, NPC stock, streams).
func world() -> Dictionary:
	return state.world


## A habit's effect value (backgrounds.json habits: the old perks), from every habit this character holds, or def.
## Habits are head starts anyone earns by doing; they touch time, warmth or carrying, never learning.
func perk_effect(key: String, def = null):
	for hid in SurvivalUtil.arr(player().get("habits")):
		var eff := SurvivalUtil.dict(SurvivalUtil.dict(data.habits.get(str(hid))).get("effects"))
		if eff.has(key):
			return eff[key]
	return def


func has_habit(habit_id: String) -> bool:
	return SurvivalUtil.arr(player().get("habits")).has(habit_id)


## Count toward the habits earned by doing (line checks, fireless nights); a habit is earned at its count.
func count_habit(counter: String, n: int = 1) -> void:
	var c: Dictionary = player().counters
	c[counter] = int(SurvivalUtil.num(c.get(counter), 0.0)) + n
	for hid in SurvivalUtil.sorted_ids(data.habits):
		var eb := SurvivalUtil.dict(data.habits[hid].get("earned_by"))
		if str(eb.get("counter", "")) == counter and int(c[counter]) >= int(SurvivalUtil.num(eb.get("count"), 1e9)) and not has_habit(str(hid)):
			player().habits.append(str(hid))
			log_line("habit earned: %s (%s)" % [str(data.habits[hid].get("name", hid)), str(data.habits[hid].get("text", ""))], "skill")
			if not _suppress_signals:
				habit_earned.emit(str(hid))


## A night slept: a fireless night outdoors counts toward the cold-camp habit.
func note_sleep(hours: float) -> void:
	if hours < 4.0 or bool(state.context.get("indoors", false)):
		return
	var f := SurvivalCamp.current_fire(self)
	if f.is_empty() or not (str(f.get("state", "")) in ["lit", "banked"]):
		count_habit("fireless_nights")


## The era of the current year (seasons.json eras), or the default start's era.
func era_id() -> String:
	var y := SurvivalClock.year(self)
	for e in data.eras.values():
		var yrs := SurvivalUtil.arr(e.get("years"))
		if yrs.size() >= 2 and y >= int(SurvivalUtil.num(yrs[0])) and y <= int(SurvivalUtil.num(yrs[1])):
			return str(e.id)
	return str(SurvivalUtil.dict(data.section("backgrounds", "start_rules").get("default_start")).get("era", "era.peace_1765_1767"))


## A role title for an NPC, market, POI or account id (the slice uses role titles, npcs.json release_rule).
func npc_title(id: String) -> String:
	var ind := SurvivalUtil.dict(data.individuals.get(id))
	if not ind.is_empty():
		return str(ind.get("role_title", id))
	var m := data.market(id)
	if not m.is_empty():
		return str(m.get("name", id))
	if id == SurvivalEconomy.COUNTY_ID:
		return "the county"
	return id.get_slice(".", id.get_slice_count(".") - 1).replace("_", " ")


func log_line(text: String, kind: String = "info") -> void:
	var e := {"t": state.minutes, "date": SurvivalClock.date_string(self), "time": SurvivalClock.time_string(self),
			"kind": kind, "text": text}
	state.journal.append(e)
	while state.journal.size() > JOURNAL_CAP:
		state.journal.remove_at(0)
	_sig(&"journal_line", [e])


func is_dead() -> bool:
	return bool(state.flags.get("dead", false))


func is_passed_out() -> bool:
	return state.flags.has("passed_out_until")


func health() -> float:
	return SurvivalUtil.num(state.needs.get("health"), 100.0)


func need_stages() -> Dictionary:
	return SurvivalNeeds.stages(self)


## The three most severe condition icons for the HUD (masked icons hidden; penalties never masked).
func icons() -> Array:
	return SurvivalConditions.icons(self, get_modifiers())


# ---------------------------------------------------------------- modifiers
## Every modifier-contract key, combined from conditions and the environment (conditions.json modifier_contract).
## Keys: aim_sway_mult, aim_tremor, spread_mult, draw_speed_mult, hold_fatigue_mult, reload_speed_mult, misfire_add,
## hangfire_mult, bow_power_mult, move_speed_mult, sprint_allowed, max_stamina_mult, stamina_regen_mult,
## health_drain_per_hour, check_mod, fine_work_mod, hunger_burn_mult, warmth_loss_mult, fatigue_rate_mult, noise_mult,
## vision_vignette, blur, hearing_mult, trade_price_mult, social_standing_add, dialogue_flags, vomit_on_eat_chance,
## drop_item_chance_per_min, tell_mask, hud_tags. The aim point is never moved.
func get_modifiers() -> Dictionary:
	if _mods_dirty or _mods.is_empty():
		_mods = SurvivalConditions.compute_modifiers(self)
		_mods_dirty = false
	return _mods


## Modifiers for one weapon kind ("musket", "pistol", "bow", "tomahawk", "spear", "saber"): the conditions' values times
## the skill's handling (capped at +-20%, level 0 = today's feel), clamped to the contract bounds.
func get_weapon_modifiers(kind: String) -> Dictionary:
	var out := get_modifiers().duplicate(true)
	var hand := SurvivalConditions.weapon_handling(self, kind)
	for k in hand.keys():
		var base = out.get(k, 1.0)
		var v := SurvivalUtil.num(base, 1.0) * float(hand[k])
		var kd: Dictionary = data.modifier_keys.get(k, {})
		var b = kd.get("bounds")
		if typeof(b) == TYPE_ARRAY and b.size() == 2:
			v = clampf(v, SurvivalUtil.num(b[0]), SurvivalUtil.num(b[1]))
		out[k] = v
	return out


func invalidate_modifiers() -> void:
	_mods_dirty = true


# ---------------------------------------------------------------- the game's inputs
## Merge what the world knows about the player's surroundings. Keys the modules read:
##   location (POI id or tag: camp records are kept per location), region, near (node ids and world tags in reach:
##   node.deadwood, node.sapling_stand, node.conifer, node.trail, world.woodpile, ...), indoors, fire_id,
##   fire_distance_m, shelter_id, in_shelter, bedding, cell (trapping cell 0-15), site (good | fair | poor),
##   camp_distance_m, sign_near, threat_m (nearest threat), lock_covered, string_covered, node_id (a node instance).
func set_context(ctx: Dictionary, replace: bool = false) -> void:
	if replace:
		var keep_region := str(state.context.get("region", SurvivalClock.DEFAULT_REGION))
		state.context = ctx.duplicate(true)
		if not state.context.has("region"):
			state.context["region"] = keep_region
	else:
		for k in ctx.keys():
			state.context[k] = ctx[k]
	_mods_dirty = true
	SurvivalTrade.check_sessions(self)


## Move to a POI with default context (the sim harness and quick tests); extra keys override.
func go_to(poi: String, extra: Dictionary = {}) -> void:
	var region := str(state.context.get("region", SurvivalClock.DEFAULT_REGION))
	var ctx := context_for_poi(poi)
	ctx["region"] = region
	for k in extra.keys():
		ctx[k] = extra[k]
	state.context = ctx
	if bool(ctx.get("indoors", false)):
		SurvivalCamp.ensure_hearth(self, poi)
	_mods_dirty = true
	SurvivalTrade.check_sessions(self)


## What the player's body is doing (needs.json activity keys): rest, walk, crouch, run, sprint, heavy_work, snowshoe,
## wading, paddling. A running job sets its own activity and restores this afterwards.
func set_activity(act: String) -> void:
	if SurvivalJobs.is_running(self):
		state.jobs.current["resume_activity"] = act
		return
	state.activity = act


## A threat was detected at this distance (an animal, a stranger): jobs stop within 25 m, sleep wakes within 60 m.
func report_threat(distance_m: float) -> void:
	state.context["threat_m"] = distance_m
	SurvivalJobs.check_threat(self)
	_flush_autosave()


func clear_threat() -> void:
	state.context.erase("threat_m")


## An animal killed by the player's shot or blow: a carcass record to dress and skin. opts: weapon_fit, shot_quality,
## condition (1-3), clean (bool), unaware (bool), weapon ("musket" | "bow" | ...), location, cell.
## Returns the carcass id.
func report_kill(species: String, opts: Dictionary = {}) -> String:
	var o := opts.duplicate()
	o["source"] = "shot"
	var id := SurvivalCamp.add_carcass(self, species, o)
	if species == "deer":
		SurvivalTrapLine.take_deer(self)
	if o.has("cell"):
		SurvivalTrapLine.record_shot(self, int(o.cell))
	if bool(o.get("clean", false)) and bool(o.get("unaware", true)):
		SurvivalSkills.record_clean_kill(self)
		var w := str(o.get("weapon", "musket"))
		SurvivalSkills.record_weapon_event(self, "archery" if w == "bow" else "marksmanship", "clean_kill")
	state.stats["kills_" + species] = int(SurvivalUtil.num(state.stats.get("kills_" + species), 0.0)) + 1
	return id


## Weapon-skill growth from use: skill marksmanship | archery | close_combat, event from SurvivalSkills.WEAPON_XP.
func report_weapon_event(skill_id: String, event: String) -> float:
	return SurvivalSkills.record_weapon_event(self, skill_id, event)


## Wading or a fall through the ice (needs.json need.wetness events: wade_knee, wade_waist, fall_through_ice).
func report_wetting(event: String) -> void:
	var ev := SurvivalUtil.dict(data.need("need.wetness").get("events"))
	var add := SurvivalUtil.num(ev.get(event), 0.3)
	state.needs["wetness"] = clampf(SurvivalUtil.num(state.needs.get("wetness"), 0.0) + add, 0.0, 1.0)
	state.flags["feet_wet"] = true
	if event == "fall_through_ice" or event == "wade_waist":
		state.flags["powder_wet"] = true
	_mods_dirty = true
	SurvivalConditions.update_driven(self)
	_update_stages()


# ---------------------------------------------------------------- time
## Advance real time: the clock runs at 2.4 real minutes a game hour by day and 1.2 by night; a running job speeds the
## survival clock (never Engine.time_scale) so its game minutes pass in its screen seconds. Returns game minutes.
##
## The fixed-quantum driver (multiplayer_readiness.md refactor P0-1): real seconds build up game minutes in an
## accumulator (saved in state.world.clock_acc) and the core advances only in whole quanta, each ending at
## min(STEP_MIN, the running job's minutes left, the passed-out minutes left). The steps come from the state, never from
## the frame rate, so 30, 60 and 144 frames a second give bit-identical games, and a short job still ends within a frame
## of its screen time. When a job ends, the surplus built at the job's speed is re-expressed at the clock's rate.
func update(real_seconds: float) -> float:
	if real_seconds > 0.0:
		# The authority's real clock runs in menus too (the confirm lock between players is measured on it).
		state.world["real_s"] = SurvivalUtil.num(state.world.get("real_s"), 0.0) + real_seconds
	if paused or is_dead() or real_seconds <= 0.0:
		return 0.0
	var rate := maxf(SurvivalClock.game_minutes_per_real_second(self), SurvivalJobs.speed_game_min_per_real_s(self))
	var acc := SurvivalUtil.num(state.world.get("clock_acc"), 0.0) + real_seconds * rate
	var done := 0.0
	var guard := 0
	while guard < 100000 and not is_dead() and not paused:
		guard += 1
		var b := STEP_MIN
		var jl := SurvivalJobs.minutes_left(self)
		if SurvivalJobs.is_running(self) and jl > 0.00001:
			b = minf(b, jl)
		var po := SurvivalUtil.num(state.flags.get("passed_out_until"), -1.0)
		if po > state.minutes:
			b = minf(b, po - state.minutes)
		if acc < b - 0.000001:
			break
		var had := SurvivalJobs.is_running(self)
		acc -= b
		done += advance(b)
		if had and not SurvivalJobs.is_running(self):
			var new_rate := maxf(SurvivalClock.game_minutes_per_real_second(self), SurvivalJobs.speed_game_min_per_real_s(self))
			acc = acc / maxf(0.0001, rate) * new_rate
			rate = new_rate
	state.world["clock_acc"] = 0.0 if is_dead() else acc
	return done


## Advance game time by `minutes`, in steps. Jobs progress and finish inside this call; time-safety wake rules stop
## sleep and jobs. Returns the game minutes actually simulated (less than asked only after death).
## stop_on_job_end: return as soon as a job running at the start finishes or is interrupted (run_job, and update(), so
## the rest of an accelerated frame is not spent at the job's speed).
func advance(minutes: float, stop_on_job_end: bool = false) -> float:
	if minutes <= 0.0 or is_dead():
		return 0.0
	var left := minutes
	var done := 0.0
	var job_seq := int(SurvivalUtil.num(state.jobs.get("seq"), 0.0))
	var had_job := SurvivalJobs.is_running(self)
	while left > 0.00001 and not is_dead():
		var step := minf(STEP_MIN, left)
		var job_left := SurvivalJobs.minutes_left(self)
		if job_left > 0.00001 and job_left < step:
			step = job_left
		var po := SurvivalUtil.num(state.flags.get("passed_out_until"), -1.0)
		if po > state.minutes and po - state.minutes < step:
			step = po - state.minutes
		_step(step)
		left -= step
		done += step
		SurvivalJobs.after_step(self, step)
		if stop_on_job_end and had_job and int(SurvivalUtil.num(state.jobs.get("seq"), 0.0)) != job_seq:
			break
	_emit_modifier_changes()
	if not _suppress_signals and done > 0.0:
		time_advanced.emit(done)
	_flush_autosave()
	return done


## A sleep ended: ask for the autosave once the current step or call has finished (see autosave_requested).
func request_autosave(reason: String) -> void:
	_autosave_reason = reason


func _flush_autosave() -> void:
	if _autosave_reason == "":
		return
	var reason := _autosave_reason
	_autosave_reason = ""
	if not is_dead() and not _suppress_signals:
		autosave_requested.emit(reason)


func _step(m: float) -> void:
	var h := m / 60.0
	var before_day := SurvivalClock.abs_day(self)
	var watch := watch_snapshot() if is_passed_out() else {}
	state.minutes += m
	SurvivalWeather.tick(self, h)
	var mods := get_modifiers()
	SurvivalNeeds.tick(self, h, mods)
	var air := SurvivalClock.air_temp_c(self)
	SurvivalCamp.tick(self, h)
	SurvivalCamp.tick_carcasses(self, h, air)
	SurvivalInventory.tick(self, h, air, _pelts_exposed_to_rain())
	SurvivalInventory.tick_wear(self, h)
	SurvivalConditions.tick(self, h)
	SurvivalExposure.tick(self, h)
	SurvivalConditions.update_driven(self)
	_mods_dirty = true
	_tally_stage_hours(h)
	# Fatigue collapse.
	if SurvivalUtil.num(state.needs.get("fatigue"), 0.0) >= 100.0 and not state.asleep:
		pass_out("exhaustion", rng.randf_range(COLLAPSE_H[0], COLLAPSE_H[1]))
	# Passed out: the timer, and the wake rules (the player wakes groggy).
	if is_passed_out():
		var why := ""
		if state.minutes >= SurvivalUtil.num(state.flags.get("passed_out_until"), 0.0) - 0.001:
			why = "came to"
		elif not watch.is_empty():
			why = watch_triggers(watch, SurvivalJobs.SLEEP_THREAT_M)
		if why != "":
			_come_to(why)
	# Day and dawn boundaries.
	var today := SurvivalClock.abs_day(self)
	for d in range(before_day + 1, today + 1):
		_new_day(d)
	if SurvivalClock.hour(self) >= DAWN_HOUR and int(SurvivalUtil.num(state.flags.get("last_dawn_day"), -99.0)) < today:
		state.flags["last_dawn_day"] = today
		SurvivalTrapLine.dawn_roll(self)
		SurvivalLearning.check_notices(self)
	_update_stages()
	# Death: the survival-side health pool is empty.
	if health() <= 0.0 and not is_dead():
		_die()
	# Open trade windows close when a party has gone, the day has turned or the window sat idle (SurvivalTrade).
	SurvivalTrade.check_sessions(self)


func _pelts_exposed_to_rain() -> bool:
	if bool(state.context.get("indoors", false)):
		return false
	var sh := SurvivalCamp.current_shelter(self)
	if not sh.is_empty() and SurvivalUtil.num(sh.get("quality"), 0.0) >= 3.0:
		return false
	return SurvivalWeather.is_wet(self)


func _tally_stage_hours(h: float) -> void:
	var ws := SurvivalNeeds.warmth_stage(self)
	var cs: Dictionary = state.stats.get("cold_stage_h", {})
	cs[ws] = SurvivalUtil.num(cs.get(ws), 0.0) + h
	state.stats["cold_stage_h"] = cs
	var hs := SurvivalNeeds.food_stage(self)
	var fs: Dictionary = state.stats.get("food_stage_h", {})
	fs[hs] = SurvivalUtil.num(fs.get(hs), 0.0) + h
	state.stats["food_stage_h"] = fs
	state.stats["health_min"] = minf(SurvivalUtil.num(state.stats.get("health_min"), 100.0), health())


func _new_day(d: int) -> void:
	state.flags["last_abs_day"] = d
	state.stats["days"] = int(SurvivalUtil.num(state.stats.get("days"), 0.0)) + 1
	SurvivalEconomy.on_day_started(self, SurvivalClock.day_of_year(self))
	SurvivalTrapLine.daily_recovery(self)
	SurvivalNodes.on_day_started(self)
	SurvivalTrade.on_day_started(self)
	SurvivalCamp.tick_caches(self)
	if not _suppress_signals:
		day_started.emit(d, SurvivalClock.day_id(self))


func _update_stages() -> void:
	var now := SurvivalNeeds.stages(self)
	var old := state.need_stages
	for k in now.keys():
		var o := str(old.get(k, ""))
		if o != str(now[k]):
			if not _suppress_signals and o != "":
				need_stage_changed.emit(str(k), o, str(now[k]))
	state.need_stages = now


func _die() -> void:
	state.flags["dead"] = true
	var cause := "wounds"
	# no starving to death (user 2026-09-27: people can fast for days; conditions.json cond.hunger design_note): hunger
	# drains no health, so it is never the cause
	if SurvivalNeeds.warmth_stage(self) == "freezing":
		cause = "cold"
	elif SurvivalConditions.stage_of(self, "cond.injury.cut") == "bleeding":
		cause = "bleeding"
	state.flags["death_cause"] = cause
	SurvivalJobs.interrupt(self, "death")
	SurvivalTrade.check_sessions(self)
	log_line("died of %s" % cause, "death")
	if not _suppress_signals:
		died.emit(cause)


## Pass out where you stand (senseless from drink, fatigue collapse). Wake rules still apply: the player wakes groggy.
func pass_out(reason: String, hours: float) -> void:
	if is_passed_out():
		return
	SurvivalJobs.interrupt(self, "passed out")
	state.asleep = true
	state.flags["passed_out_until"] = state.minutes + hours * 60.0
	state.flags["passed_out_reason"] = reason
	state.stats["passed_out"] = int(SurvivalUtil.num(state.stats.get("passed_out"), 0.0)) + 1
	log_line("passed out (%s)" % reason, "cond")
	if not _suppress_signals:
		passed_out.emit(reason, hours)


func _come_to(why: String) -> void:
	var reason := str(state.flags.get("passed_out_reason", ""))
	state.flags.erase("passed_out_until")
	state.flags.erase("passed_out_reason")
	state.asleep = false
	if reason == "drink" or why != "came to":
		state.flags["groggy_until"] = state.minutes + SurvivalConditions.GROGGY_MIN
	if why != "came to":
		state.stats["wakes"] = int(SurvivalUtil.num(state.stats.get("wakes"), 0.0)) + 1
	log_line("came to (%s)" % why, "cond")
	_mods_dirty = true
	if not _suppress_signals:
		woke.emit(why)


# ---------------------------------------------------------------- time safety (the wake rules)
## What the wake rules compare against: need stage severities, condition stages, the fire's state and the weather.
func watch_snapshot() -> Dictionary:
	var needs := {}
	var st := SurvivalNeeds.stages(self)
	for k in st.keys():
		needs[k] = SurvivalNeeds.stage_severity(self, str(k), str(st[k]))
	var f := SurvivalCamp.current_fire(self)
	return {"needs": needs, "conds": SurvivalConditions.stage_snapshot(self), "fire_id": str(f.get("id", "")),
			"fire_state": str(f.get("state", "")), "weather": SurvivalWeather.state_id(self)}


## The first wake reason since the snapshot, or "" (needs.json time_safety.sleep_and_jobs.wake_or_interrupt_when).
## Fatigue does not wake a sleeper (it only falls while asleep).
func watch_triggers(snap: Dictionary, threat_radius_m: float) -> String:
	var now := SurvivalNeeds.stages(self)
	var sev0 := SurvivalUtil.dict(snap.get("needs"))
	for k in now.keys():
		if str(k) == "need.rest" and state.asleep:
			continue
		var sv := SurvivalNeeds.stage_severity(self, str(k), str(now[k]))
		if sv > int(SurvivalUtil.num(sev0.get(k), 0.0)):
			return "%s worse: %s" % [str(k).trim_prefix("need."), str(now[k])]
	var fid := str(snap.get("fire_id", ""))
	if fid != "" and str(snap.get("fire_state", "")) in ["lit", "banked"]:
		var f := SurvivalCamp.fire(self, fid)
		var fs := str(f.get("state", "out"))
		if fs == "out" or fs == "smouldering":
			return "the fire is %s" % ("out" if fs == "out" else "smouldering")
	var c0 := SurvivalUtil.dict(snap.get("conds"))
	var c1 := SurvivalConditions.stage_snapshot(self)
	for k in c1.keys():
		if not c0.has(k) or int(c1[k]) > int(c0[k]):
			if str(k) == "cond.drunk" and not c0.has(k) and not is_passed_out():
				continue
			return "%s: %s" % [str(data.condition(str(k)).get("name", k)).to_lower(), SurvivalConditions.stage_of(self, str(k))]
	var w0 := str(snap.get("weather", ""))
	var w1 := SurvivalWeather.state_id(self)
	if w1 != w0 and SurvivalWeather.is_storm(self):
		return "the weather turned to %s" % w1
	var t := SurvivalUtil.num(state.context.get("threat_m"), 9999.0)
	if t <= threat_radius_m:
		return "a threat at %d m" % int(t)
	return ""


# ---------------------------------------------------------------- jobs (thin wrappers over SurvivalJobs)
## The prompt for an action: {ok, reasons, pct, chance, factors, hint, materials_at_risk, time_min, anim, prompt}.
func preview(action_id: String, params: Dictionary = {}) -> Dictionary:
	return SurvivalJobs.preview(self, action_id, params)


## Start a timed job. params: hurry (bool), item, qty, tinder, fuel, recipe, trap_id, carcass_id, stack filters,
## hours (sleep, wait), cell, site, bait, basket (take_credit). Returns {ok, reason, job}.
func start_job(action_id: String, params: Dictionary = {}) -> Dictionary:
	var r := SurvivalJobs.start(self, action_id, params)
	_emit_modifier_changes()
	return r


## Start a job and advance time until it finishes or is interrupted (tools, the sim harness and tests).
func run_job(action_id: String, params: Dictionary = {}) -> Dictionary:
	return SurvivalJobs.run(self, action_id, params)


## Movement cancels a job (keeping its progress unless the action loses it), or the game cancels it for its own reasons.
func cancel_job(reason: String = "moved") -> void:
	SurvivalJobs.interrupt(self, reason)
	_flush_autosave()


func current_job() -> Dictionary:
	return SurvivalUtil.dict(state.jobs.get("current"))


## Actions whose requirements are met here and now (for the verb menus).
func available_actions() -> Array:
	return SurvivalJobs.available(self)


# ---------------------------------------------------------------- module callbacks -> signals
func _on_inventory_changed() -> void:
	_mods_dirty = true
	_sig(&"inventory_changed")


func _on_condition_added(id: String, stage: String) -> void:
	_mods_dirty = true
	if not _suppress_signals:
		condition_added.emit(id, stage)


func _on_condition_stage(id: String, old_stage: String, new_stage: String) -> void:
	_mods_dirty = true
	if not _suppress_signals:
		condition_stage_changed.emit(id, old_stage, new_stage)


func _on_condition_removed(id: String) -> void:
	_mods_dirty = true
	if not _suppress_signals:
		condition_removed.emit(id)


func _on_skill_changed(id: String, old_level: float, new_level: float) -> void:
	_sig(&"skill_changed", [id, old_level, new_level])


func _on_skill_tier(id: String, tier: String) -> void:
	log_line("%s: %s" % [str(data.skill(id).get("name", id)), tier.capitalize()], "skill")
	_sig(&"skill_tier_reached", [id, tier])


func _on_fire_changed(id: String, fire_state: String) -> void:
	_mods_dirty = true
	if not _suppress_signals:
		fire_changed.emit(id, fire_state)


func _on_trap_changed(id: String, trap_state: String) -> void:
	if not _suppress_signals:
		trap_changed.emit(id, trap_state)


func _on_trap_caught(id: String, species: String) -> void:
	if not _suppress_signals:
		trap_caught.emit(id, species)


func _on_weather_changed(old_state: String, new_state: String) -> void:
	_mods_dirty = true
	if not _suppress_signals:
		weather_changed.emit(old_state, new_state)


func _on_event(id: String, started: bool) -> void:
	log_line("%s %s" % [str(SurvivalUtil.dict(data.events.get(id)).get("name", id)), "begins" if started else "ends"], "event")
	if not _suppress_signals:
		calendar_event.emit(id, started)


func _on_money_changed(pence: int) -> void:
	_sig(&"money_changed", [pence])


func _on_account_changed(creditor: String, balance_d: float) -> void:
	_sig(&"account_changed", [creditor, balance_d])


func _on_standing_changed(faction: String, value: float) -> void:
	_sig(&"standing_changed", [faction, value])


func _on_settlement(creditor: String, grade: String, result: Dictionary) -> void:
	if not _suppress_signals:
		settlement.emit(creditor, grade, result)


func _on_knowledge_changed(id: String, old_state: String, new_state: String) -> void:
	_sig(&"knowledge_changed", [id, old_state, new_state])


func _on_notice(id: String, text: String) -> void:
	if not _suppress_signals:
		notice.emit(id, text)


func _on_lesson_finished(teacher_id: String, what: String, result: Dictionary) -> void:
	if not _suppress_signals:
		lesson_finished.emit(teacher_id, what, result)


func _on_watched(action_id: String, performer_id: String) -> void:
	if not _suppress_signals:
		watched.emit(action_id, performer_id)


## trade_committed is never deferred: it is the first signal after a commit, and the queued module signals follow it.
func _on_trade_committed(tr_id: String, entry: Dictionary) -> void:
	_mods_dirty = true
	if not _suppress_signals:
		trade_committed.emit(tr_id, entry)


func _on_obligation_changed(ob_id: String, status: String) -> void:
	_sig(&"obligation_changed", [ob_id, status])


func _on_trust_changed(npc_id: String, value: float) -> void:
	_sig(&"trust_changed", [npc_id, value])


## Queue module signals while the authority applies a trade (SurvivalTrade.commit), so no handler sees a half-applied
## session; defer_signals(false) emits the queue in order (inventory_changed once).
func defer_signals(on: bool) -> void:
	if on:
		_defer_depth += 1
		return
	_defer_depth = maxi(0, _defer_depth - 1)
	if _defer_depth > 0:
		return
	var q := _deferred
	_deferred = []
	for e in q:
		if not _suppress_signals:
			callv("emit_signal", [e[0]] + SurvivalUtil.arr(e[1]))


func _sig(sig_name: StringName, args: Array = []) -> void:
	if _suppress_signals:
		return
	if _defer_depth > 0:
		if args.is_empty():
			for e in _deferred:
				if e[0] == sig_name and SurvivalUtil.arr(e[1]).is_empty():
					return
		_deferred.append([sig_name, args])
		return
	callv("emit_signal", [sig_name] + args)


# ---------------------------------------------------------------- trade and learning (commands in, events out)
## Open the trade window with a partner here (an NPC id, or a player id later). Returns {ok, tr, reason}.
func open_trade(partner: String) -> Dictionary:
	return SurvivalTrade.open(self, state.player_id, partner)


## Set your own lines in an open trade (see SurvivalTrade for the line kinds). Returns {ok, version, evaluation}.
func trade_lines(tr_id: String, lines: Array) -> Dictionary:
	return SurvivalTrade.set_lines(self, tr_id, state.player_id, lines)


## Ask an NPC partner for goods: set the NPC's side of the window (what you want from them). The NPC evaluates the
## whole deal at once and confirms or counter-offers. Between players each edits only their own lines.
func trade_request(tr_id: String, lines: Array) -> Dictionary:
	var s := SurvivalTrade.session(self, tr_id)
	var npc := str(s.get("npc", ""))
	if s.is_empty() or npc == "":
		return {"ok": false, "reason": "no open trade with a partner here"}
	return SurvivalTrade.set_lines(self, tr_id, npc, lines)


## Confirm the offer as it stands (the version the window shows). Both confirming commits it.
func trade_confirm(tr_id: String, version: int) -> Dictionary:
	return SurvivalTrade.confirm(self, tr_id, state.player_id, version)


## What the trade window may show you: lines, cues, each side's load, numbers only from Adept or the ledger toggle.
func trade_view(tr_id: String) -> Dictionary:
	return SurvivalTrade.view(self, tr_id, state.player_id)


## Barter in one step: give [[item, qty] | ["coin", pence] | ["labour", hours, job]] for take [[item, qty]].
func barter(partner: String, give: Array, take: Array) -> Dictionary:
	return SurvivalTrade.barter(self, partner, give, take)


## The ledger page: every obligation naming you (labour, lessons, loans, promises, credit books).
func obligations(only_open: bool = false) -> Array:
	return SurvivalTrade.obligations_of(self, state.player_id, only_open)


func work_off(ob_id: String, minutes: float) -> Dictionary:
	return SurvivalTrade.work_off(self, ob_id, minutes)


func trust(npc_id: String) -> float:
	return SurvivalTrade.trust(self, npc_id)


func recipe_book() -> Dictionary:
	return SurvivalLearning.recipe_book(self)


func lesson_offers(mentor_id: String) -> Array:
	return SurvivalLearning.lesson_offers(self, mentor_id)


## Agree a lesson and start it (a social.ask_teach job of 60-120 game minutes). Returns the job's start result.
func arrange_lesson(mentor_id: String, what: String, ask_index: int = 0) -> Dictionary:
	var r := SurvivalLearning.arrange_lesson(self, mentor_id, what, ask_index)
	if not bool(r.get("ok", false)):
		return r
	var j := start_job("social.ask_teach", SurvivalUtil.dict(r.params))
	j["lesson"] = r
	return j


func watchable() -> Array:
	return SurvivalLearning.watchable(self)


## Put on or take off a carried garment (the wear UI). A garment made goes on by itself when its slot is empty.
func put_on(item_id: String) -> bool:
	return SurvivalInventory.wear(self, item_id)


func take_off(item_id: String) -> bool:
	return SurvivalInventory.take_off(self, item_id)


func _emit_modifier_changes() -> void:
	var m := get_modifiers()
	var key := SurvivalUtil.stable_key(m)
	if key != _mods_key:
		_mods_key = key
		if not _suppress_signals:
			modifiers_changed.emit(m)


# ---------------------------------------------------------------- saving
## The state with the random-number stream synced into it (call before saving or comparing).
func snapshot_state() -> SurvivalState:
	state.rng_seed = rng.seed
	state.rng_state = rng.state
	SurvivalStreams.sync(self)
	return state


## A plain-data copy of everything that is saved.
func to_dict() -> Dictionary:
	return snapshot_state().to_dict()
