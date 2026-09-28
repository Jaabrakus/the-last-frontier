class_name SurvivalConditions
extends RefCounted
## Conditions and the modifier contract (conditions.json).
##
## Need-driven conditions (hunger, cold, wet, fatigue, thirst) follow their need's stage; drink follows its meter;
## injuries and illnesses run on explicit timers from their rows (heal_game_days, duration_game_h). Only the current
## stage's effects apply. compute_modifiers() gathers every active stage's effects plus the environment's (a wet lock,
## a damp bowstring, wet powder, load, deep snow, mud), combines each key by its contract rule (multiply, add, max, and,
## union), applies the stacking limit (at most the three strongest penalties per key) and clamps to bounds.
## Modifiers change sway, tremor, speed and timing only; the aim point is never moved (modifier_contract.aim_rule).

## Keys where a larger value is the penalty (everything else: a smaller value is the penalty).
const HIGHER_IS_WORSE := ["aim_sway_mult", "aim_tremor", "spread_mult", "hold_fatigue_mult", "misfire_add",
		"hangfire_mult", "health_drain_per_hour", "hunger_burn_mult", "warmth_loss_mult", "fatigue_rate_mult",
		"noise_mult", "vision_vignette", "blur", "trade_price_mult", "vomit_on_eat_chance", "drop_item_chance_per_min",
		"thirst_mult"]
## Conditions that follow a need's stage (the need's first stage means the condition is gone).
const DRIVEN := {"cond.hunger": "need.food", "cond.cold": "need.warmth", "cond.fatigue": "need.rest",
		"cond.wet": "need.wetness", "cond.thirst": "need.thirst"}
const CLEAR_STAGES := {"need.food": "fed", "need.warmth": "comfortable", "need.rest": "rested", "need.wetness": "dry",
		"need.thirst": "hydrated"}
## An unbound cut clots by itself after this many game hours and then heals at half speed. The data says "bleeding until
## bound"; without some floor a lost bandage would kill from a hand cut [D, listed as an open question].
const CUT_SELF_CLOT_H := 6.0
const SELF_CLOT_HEAL_MULT := 0.5
## Groggy after waking from senseless drink: check -0.2 for one game hour (needs.json time_safety).
const GROGGY_CHECK := -0.2
const GROGGY_MIN := 60.0
## Family weight for icon order (the HUD shows the three most severe).
const FAMILY_WEIGHT := {"injury": 0.6, "illness": 0.4, "exposure": 0.3, "need": 0.2, "intoxication": 0.1}


# ---------------------------------------------------------------- add, remove, stages
static func has(core: SurvivalCore, id: String) -> bool:
	return core.state.conditions.has(id)


static func stage_of(core: SurvivalCore, id: String) -> String:
	return str(SurvivalUtil.dict(core.state.conditions.get(id)).get("stage", ""))


static func _stage_names(core: SurvivalCore, id: String) -> Array:
	var out := []
	for s in SurvivalUtil.arr(core.data.condition(id).get("stages")):
		out.append(str(s.get("stage", "")))
	return out


static func _stage_row(core: SurvivalCore, id: String, stage: String) -> Dictionary:
	for s in SurvivalUtil.arr(core.data.condition(id).get("stages")):
		if str(s.get("stage", "")) == stage:
			return s
	return {}


## Start (or worsen) a timed condition: injuries, illness, queasiness. opts: stage, zone, cause.
static func add(core: SurvivalCore, id: String, opts: Dictionary = {}) -> void:
	var row := core.data.condition(id)
	if row.is_empty():
		core.log_line("condition %s is not in the loaded data" % id, "warn")
		return
	var conds := core.state.conditions
	if conds.has(id):
		var rec: Dictionary = conds[id]
		match id:
			"cond.injury.crushed_fingers":
				# A second mishap doubles the healing time (conditions.json trade_off).
				rec["heal_h"] = SurvivalUtil.num(rec.get("heal_h"), 0.0) * 2.0
				rec["bound"] = false
				rec["heal_mult"] = 1.0
				core.log_line("crushed the same fingers again: healing takes twice as long", "cond")
			"cond.queasy":
				var old := str(rec.stage)
				rec["stage"] = "vomiting"
				rec["dur_h"] = maxf(SurvivalUtil.num(rec.get("dur_h"), 0.0), SurvivalUtil.rand_in(core.rng, row.get("duration_game_h"), 4.0))
				if old != "vomiting":
					core._on_condition_stage(id, old, "vomiting")
			"cond.injury.cut":
				if str(rec.stage) != "bleeding":
					var old2 := str(rec.stage)
					rec["stage"] = "bleeding"
					rec["bleed_h"] = 0.0
					rec["heal_h"] = SurvivalUtil.rand_in(core.rng, row.get("heal_game_days"), 3.0) * 24.0
					core._on_condition_stage(id, old2, "bleeding")
			_:
				var d := _duration_h(core, row)
				if d > 0.0:
					rec["dur_h"] = maxf(SurvivalUtil.num(rec.get("dur_h"), 0.0), d)
		return
	var names := _stage_names(core, id)
	var stage := str(opts.get("stage", names[0] if not names.is_empty() else "active"))
	var zones := SurvivalUtil.arr(row.get("zones"))
	var rec2 := {"stage": stage, "t_h": 0.0, "zone": str(opts.get("zone", zones[0] if not zones.is_empty() else "")),
			"cause": str(opts.get("cause", "")), "bound": false, "heal_mult": 1.0, "since": core.state.minutes}
	if row.has("heal_game_days"):
		rec2["heal_h"] = SurvivalUtil.rand_in(core.rng, row.heal_game_days, 3.0) * 24.0
	var dur := _duration_h(core, row)
	if dur > 0.0:
		rec2["dur_h"] = dur
	if id == "cond.injury.cut":
		rec2["bleed_h"] = 0.0
	if bool(opts.get("incubating", false)) and row.has("incubation_game_days"):
		rec2["incubating"] = true
		rec2["inc_h"] = SurvivalUtil.rand_in(core.rng, row.incubation_game_days, 3.0) * 24.0
	conds[id] = rec2
	core.state.stats["cond_" + id] = int(SurvivalUtil.num(core.state.stats.get("cond_" + id), 0.0)) + 1
	core._on_condition_added(id, stage)


static func _duration_h(core: SurvivalCore, row: Dictionary) -> float:
	if row.has("duration_game_h") and typeof(row.duration_game_h) != TYPE_DICTIONARY:
		return SurvivalUtil.rand_in(core.rng, row.duration_game_h, 4.0)
	if row.has("duration_game_days"):
		return SurvivalUtil.rand_in(core.rng, row.duration_game_days, 1.0) * 24.0
	return 0.0


static func remove(core: SurvivalCore, id: String) -> void:
	if core.state.conditions.has(id):
		core.state.conditions.erase(id)
		core._on_condition_removed(id)


static func _set_stage(core: SurvivalCore, id: String, stage: String) -> void:
	var conds := core.state.conditions
	if stage == "":
		remove(core, id)
		return
	if not conds.has(id):
		conds[id] = {"stage": stage, "t_h": 0.0, "since": core.state.minutes}
		core._on_condition_added(id, stage)
		return
	var old := str(conds[id].stage)
	if old != stage:
		conds[id]["stage"] = stage
		core._on_condition_stage(id, old, stage)


## Sync the need-driven conditions and drink with the current need stages and meter.
static func update_driven(core: SurvivalCore) -> void:
	for cid in DRIVEN.keys():
		if core.data.condition(cid).is_empty():
			continue
		var nid: String = DRIVEN[cid]
		if nid == "need.thirst" and not SurvivalNeeds.thirst_enabled(core):
			continue
		var st := ""
		match nid:
			"need.food": st = SurvivalNeeds.food_stage(core)
			"need.warmth": st = SurvivalNeeds.warmth_stage(core)
			"need.rest": st = SurvivalNeeds.rest_stage(core)
			"need.wetness": st = SurvivalNeeds.wet_stage(core)
			"need.thirst": st = SurvivalNeeds.thirst_stage(core)
		if st == str(CLEAR_STAGES.get(nid, "")):
			_set_stage(core, cid, "")
			continue
		var names := _stage_names(core, cid)
		if not names.has(st):
			if nid == "need.rest" and st == "collapse":
				st = "exhausted"
			elif not names.is_empty():
				st = names[names.size() - 1]
		_set_stage(core, cid, st)
	# Drink, by its meter.
	var drow := core.data.condition("cond.drunk")
	if drow.is_empty():
		return
	var meter := SurvivalUtil.num(core.state.needs.get("drunk"), 0.0)
	var best := ""
	for s in SurvivalUtil.arr(drow.get("stages")):
		if meter >= SurvivalUtil.num(s.get("min"), 999.0):
			best = str(s.stage)
	var before := stage_of(core, "cond.drunk")
	_set_stage(core, "cond.drunk", best)
	if best == "senseless" and before != "senseless" and not core.state.asleep:
		var ps := _stage_row(core, "cond.drunk", "senseless")
		var hrs := SurvivalUtil.rand_in(core.rng, SurvivalUtil.dict(ps.get("effects")).get("pass_out_game_h"), 3.0)
		core.pass_out("drink", hrs)
	if best == "" and before != "":
		_hangover(core)


## conditions.json cond.drunk hangover: after a peak of 40 or more, queasy for 4-6 game hours and +15 fatigue.
static func _hangover(core: SurvivalCore) -> void:
	var hv := SurvivalUtil.dict(core.data.condition("cond.drunk").get("hangover"))
	var peak := SurvivalUtil.num(core.state.needs.get("drunk_peak"), 0.0)
	core.state.needs["drunk_peak"] = 0.0
	if peak < SurvivalUtil.num(hv.get("when_peak_at_least"), 40.0):
		return
	var ow := SurvivalUtil.dict(hv.get("on_wake"))
	core.state.needs["fatigue"] = minf(100.0, SurvivalUtil.num(core.state.needs.get("fatigue"), 0.0) + SurvivalUtil.num(ow.get("fatigue"), 15.0))
	if not core.data.condition("cond.queasy").is_empty():
		add(core, "cond.queasy", {"cause": "hangover"})
		var rec: Dictionary = core.state.conditions.get("cond.queasy", {})
		if not rec.is_empty():
			rec["dur_h"] = SurvivalUtil.rand_in(core.rng, hv.get("duration_game_h"), 5.0)
	core.log_line("a sore head and a sour stomach: the morning after", "cond")


## Bind wounds (physick.bind_wound): cuts stop bleeding, crushed fingers are bound (heal x1.5 kept off the line).
static func bind(core: SurvivalCore, opts: Dictionary = {}) -> Array:
	var done := []
	var treats := SurvivalUtil.arr(core.data.action("physick.bind_wound").get("treats"))
	for cid in treats:
		if not has(core, str(cid)):
			continue
		var rec: Dictionary = core.state.conditions[cid]
		if str(cid) == "cond.injury.cut":
			if str(rec.stage) == "bleeding":
				var old := str(rec.stage)
				rec["stage"] = "bound"
				rec["bound"] = true
				rec["heal_mult"] = 1.0
				core._on_condition_stage(str(cid), old, "bound")
				done.append(cid)
		else:
			if not bool(rec.get("bound", false)):
				rec["bound"] = true
				rec["bound_at"] = core.state.minutes
				var hm := 1.0
				for c in SurvivalUtil.arr(core.data.condition(str(cid)).get("cures")):
					if str(SurvivalUtil.dict(c).get("action", "")) == "physick.bind_wound":
						hm = SurvivalUtil.num(c.get("heal_mult"), 1.0)
				rec["heal_mult"] = hm
				done.append(cid)
	return done


## Does any condition need binding right now?
static func needs_binding(core: SurvivalCore) -> bool:
	if stage_of(core, "cond.injury.cut") == "bleeding":
		return true
	var cf := SurvivalUtil.dict(core.state.conditions.get("cond.injury.crushed_fingers"))
	return not cf.is_empty() and not bool(cf.get("bound", false))


## Timers: healing, durations, clotting, incubation and episodes.
static func tick(core: SurvivalCore, hours: float) -> void:
	var conds := core.state.conditions
	var ended := []
	for id in conds.keys():
		var rec: Dictionary = conds[id]
		var row := core.data.condition(str(id))
		rec["t_h"] = SurvivalUtil.num(rec.get("t_h"), 0.0) + hours
		if DRIVEN.has(id) or id == "cond.drunk":
			continue
		if bool(rec.get("incubating", false)):
			rec["inc_h"] = SurvivalUtil.num(rec.get("inc_h"), 0.0) - hours
			if float(rec.inc_h) <= 0.0:
				rec.erase("incubating")
				core.log_line("%s: it shows now" % str(row.get("name", id)), "cond")
				core._on_condition_stage(str(id), "incubating", str(rec.stage))
			continue
		match str(id):
			"cond.injury.cut":
				if str(rec.stage) == "bleeding":
					rec["bleed_h"] = SurvivalUtil.num(rec.get("bleed_h"), 0.0) + hours
					if float(rec.bleed_h) >= CUT_SELF_CLOT_H:
						rec["stage"] = "bound"
						rec["heal_mult"] = SELF_CLOT_HEAL_MULT
						core._on_condition_stage(str(id), "bleeding", "bound")
						core.log_line("the cut has clotted by itself; it will heal slowly unbound", "cond")
					continue
			"cond.injury.crushed_fingers":
				# Bound fingers heal x1.5 only while kept off the line.
				if bool(rec.get("bound", false)):
					var last_trap := SurvivalUtil.num(core.state.flags.get("last_trap_work_min"), -1e9)
					if last_trap > SurvivalUtil.num(rec.get("bound_at"), 0.0):
						rec["heal_mult"] = 1.0
			"cond.queasy":
				var rest_mult := 1.5 if (core.state.asleep or core.state.activity == "rest") else 1.0
				rec["dur_h"] = SurvivalUtil.num(rec.get("dur_h"), 0.0) - hours * (rest_mult - 1.0)
			"cond.worms":
				var nc := SurvivalUtil.num(SurvivalUtil.dict(row.get("natural_clearance")).get("chance_per_season"), 0.0)
				var season_h := SurvivalClock.days_per_year(core) / 4.0 * 24.0
				if nc > 0.0 and core.rng.randf() < 1.0 - pow(1.0 - nc, hours / season_h):
					ended.append(id)
					continue
				var ep := SurvivalUtil.num(SurvivalUtil.dict(row.get("episodes")).get("queasy_per_game_day"), 0.0)
				if ep > 0.0 and core.rng.randf() < ep * hours / 24.0:
					add(core, "cond.queasy", {"cause": "worms"})
		if rec.has("heal_h") and (str(id) != "cond.injury.cut" or str(rec.stage) != "bleeding"):
			rec["heal_h"] = SurvivalUtil.num(rec.get("heal_h"), 0.0) - hours * SurvivalUtil.num(rec.get("heal_mult"), 1.0)
			if float(rec.heal_h) <= 0.0:
				ended.append(id)
				continue
		if rec.has("dur_h"):
			rec["dur_h"] = SurvivalUtil.num(rec.get("dur_h"), 0.0) - hours
			if float(rec.dur_h) <= 0.0:
				ended.append(id)
	for id in ended:
		remove(core, str(id))
	var gu := SurvivalUtil.num(core.state.flags.get("groggy_until"), -1.0)
	if gu >= 0.0 and core.state.minutes >= gu:
		core.state.flags.erase("groggy_until")


## A severity score for ordering icons and for the wake rule "a condition gains a stage".
static func severity(core: SurvivalCore, id: String) -> float:
	var rec := SurvivalUtil.dict(core.state.conditions.get(id))
	if rec.is_empty():
		return 0.0
	var names := _stage_names(core, id)
	var i := names.find(str(rec.stage))
	var frac := float(i + 1) / float(maxi(1, names.size())) if i >= 0 else 0.5
	if id == "cond.injury.cut":
		frac = 1.0 if str(rec.stage) == "bleeding" else 0.3
	var fam := str(core.data.condition(id).get("family", ""))
	return frac + float(FAMILY_WEIGHT.get(fam, 0.0))


## Stage index per active condition (for the job runner's "a condition gains a stage" rule).
static func stage_snapshot(core: SurvivalCore) -> Dictionary:
	var out := {}
	for id in core.state.conditions.keys():
		var names := _stage_names(core, str(id))
		var st := str(core.state.conditions[id].stage)
		out[id] = names.find(st) + (10 if st == "bleeding" else 0)
	return out


# ---------------------------------------------------------------- modifiers
## Every source of modifiers: [{src, label, effects}] (conditions first, then the environment).
static func sources(core: SurvivalCore) -> Array:
	var out := []
	for id in core.state.conditions.keys():
		var rec: Dictionary = core.state.conditions[id]
		if bool(rec.get("incubating", false)):
			continue
		var row := core.data.condition(str(id))
		var eff := {}
		var sr := _stage_row(core, str(id), str(rec.stage))
		for k in SurvivalUtil.dict(sr.get("effects")).keys():
			eff[k] = sr.effects[k]
		var ebz := SurvivalUtil.dict(row.get("effects_by_zone"))
		if ebz.has(str(rec.get("zone", ""))):
			for k in SurvivalUtil.dict(ebz[rec.zone]).keys():
				eff[k] = ebz[rec.zone][k]
		# Stage-level zone effects (backlog frostbite).
		var sbz := SurvivalUtil.dict(sr.get("effects_by_zone"))
		if sbz.has(str(rec.get("zone", ""))):
			for k in SurvivalUtil.dict(sbz[rec.zone]).keys():
				eff[k] = sbz[rec.zone][k]
		# (mod.ill, queasy -0.05 / vomiting -0.15 on every check, is gone: user 2026-09-27, no skill penalty from
		# nausea; skills are the player's)
		out.append({"src": str(id), "label": str(row.get("name", id)).to_lower(), "effects": eff})
	var env := _env_sources(core)
	out.append_array(env)
	return out


static func _env_sources(core: SurvivalCore) -> Array:
	var out := []
	var ctx := core.state.context
	var outdoors := not bool(ctx.get("indoors", false))
	var wet_row := core.data.condition("cond.wet")
	var extra := SurvivalUtil.dict(wet_row.get("extra"))
	var wrow := SurvivalWeather.row(core)
	if outdoors:
		var pr := SurvivalWeather.precip(core)
		if pr != "" and not bool(ctx.get("lock_covered", false)):
			var eff := {"misfire_add": SurvivalUtil.num(wrow.get("misfire_add_uncovered"), 0.0)}
			if pr == "rain":
				eff["hangfire_mult"] = SurvivalUtil.num(SurvivalUtil.dict(SurvivalUtil.dict(extra.get("lock_wet_in_rain")).get("effects")).get("hangfire_mult"), 1.5)
			out.append({"src": "env.wet_lock", "label": "wet lock", "effects": eff})
		if bool(wrow.get("bowstring_damp", false)) and not bool(ctx.get("string_covered", false)):
			out.append({"src": "env.damp_string", "label": "damp bowstring",
					"effects": SurvivalUtil.dict(SurvivalUtil.dict(extra.get("bowstring_damp")).get("effects")).duplicate()})
		var gates := core.data.section("seasons", "gates")
		if SurvivalClock.gate_active(core, "deep_snow"):
			var ge := SurvivalUtil.dict(SurvivalUtil.dict(gates.get("deep_snow")).get("effects"))
			var shoes := SurvivalInventory.has(core, "item.tool.snowshoes")
			var m := SurvivalUtil.num(ge.get("walk_mult_with_snowshoes" if shoes else "walk_mult_without_snowshoes"), 1.0)
			out.append({"src": "env.deep_snow", "label": "deep snow", "effects": {"move_speed_mult": m}})
		elif SurvivalClock.gate_active(core, "mud_season"):
			var me := SurvivalUtil.dict(SurvivalUtil.dict(gates.get("mud_season")).get("effects"))
			out.append({"src": "env.mud", "label": "mud", "effects": {"move_speed_mult": SurvivalUtil.num(me.get("foot_mult"), 0.7)}})
	if bool(core.state.flags.get("powder_wet", false)):
		out.append({"src": "env.powder_wet", "label": "wet powder",
				"effects": SurvivalUtil.dict(SurvivalUtil.dict(extra.get("powder_dunked")).get("effects")).duplicate()})
	var ls := SurvivalInventory.load_stage(core)
	if ls != "normal":
		var ld := core.data.section("needs", "load")
		var le := SurvivalUtil.dict(ld.get("heavy_effects" if ls == "heavy" else "overloaded_effects")).duplicate()
		out.append({"src": "env.load_" + ls, "label": "heavy load" if ls == "heavy" else "overloaded", "effects": le})
	if core.state.flags.has("groggy_until"):
		out.append({"src": "env.groggy", "label": "groggy", "effects": {"check_mod": GROGGY_CHECK}})
	return out


static func _key_def(core: SurvivalCore, key: String) -> Dictionary:
	if core.data.modifier_keys.has(key):
		return core.data.modifier_keys[key]
	return {"key": key, "combine": "multiply" if key.ends_with("_mult") else "add", "bounds": null}


static func neutral(combine: String):
	match combine:
		"multiply":
			return 1.0
		"and":
			return true
		"union":
			return []
	return 0.0


static func _is_penalty(key: String, combine: String, v) -> bool:
	match combine:
		"and":
			return not bool(v)
		"union":
			return false
		"multiply":
			return float(v) > 1.0 if HIGHER_IS_WORSE.has(key) else float(v) < 1.0
	return float(v) > 0.0 if HIGHER_IS_WORSE.has(key) else float(v) < 0.0


static func _strength(combine: String, v) -> float:
	match combine:
		"multiply":
			return absf(log(maxf(0.0001, float(v))))
		"and":
			return 1.0 if not bool(v) else 0.0
		"union":
			return 0.0
	return absf(float(v))


## Combine sources by the contract. Returns every contract key (neutral when nothing touches it) plus any extra key
## a stage uses (health_regen_mult, thirst_mult).
static func combine(core: SurvivalCore, srcs: Array) -> Dictionary:
	var per_key := {}
	for s in srcs:
		var eff: Dictionary = s.effects
		for k in eff.keys():
			if str(k) == "pass_out_game_h":
				continue
			if not per_key.has(k):
				per_key[k] = []
			per_key[k].append(eff[k])
	var out := {}
	for k in core.data.modifier_keys.keys():
		out[k] = neutral(str(core.data.modifier_keys[k].combine))
	var limit := int(SurvivalUtil.num(SurvivalUtil.dict(core.data.section("conditions", "modifier_contract").get("stacking_limit")).get("max_penalty_sources_per_key"), 3.0))
	for k in per_key.keys():
		var kd := _key_def(core, str(k))
		var comb := str(kd.get("combine", "add"))
		var vals: Array = per_key[k]
		if comb != "union":
			var pens := []
			var goods := []
			for v in vals:
				if _is_penalty(str(k), comb, v):
					pens.append(v)
				else:
					goods.append(v)
			if pens.size() > limit:
				pens.sort_custom(func(a, b): return _strength(comb, a) > _strength(comb, b))
				pens = pens.slice(0, limit)
			vals = pens + goods
		var acc = neutral(comb)
		for v in vals:
			match comb:
				"multiply":
					acc = float(acc) * SurvivalUtil.num(v, 1.0)
				"add":
					acc = float(acc) + SurvivalUtil.num(v, 0.0)
				"max":
					acc = maxf(float(acc), SurvivalUtil.num(v, 0.0))
				"and":
					acc = bool(acc) and bool(v)
				"union":
					for e in SurvivalUtil.arr(v):
						if not acc.has(e):
							acc.append(e)
		var b = kd.get("bounds")
		if typeof(b) == TYPE_ARRAY and b.size() == 2 and (comb == "multiply" or comb == "add" or comb == "max"):
			acc = clampf(float(acc), SurvivalUtil.num(b[0]), SurvivalUtil.num(b[1]))
		out[k] = acc
	return out


static func compute_modifiers(core: SurvivalCore) -> Dictionary:
	return combine(core, sources(core))


## Skill handling for a weapon kind: "firearm" (Marksmanship), "bow" (Archery), "melee" or "thrown" (Close Combat).
## Linear from level 0 (x1.0, today's feel) to the skill's at_100 values, capped at +-20% (skills.json handling_cap).
static func weapon_handling(core: SurvivalCore, kind: String) -> Dictionary:
	var sk := ""
	match kind:
		"firearm", "musket", "pistol":
			sk = "marksmanship"
		"bow":
			sk = "archery"
		"melee", "thrown", "tomahawk", "spear", "saber":
			sk = "close_combat"
	var out := {}
	if sk == "":
		return out
	var h := SurvivalUtil.dict(core.data.skill(sk).get("handling"))
	var at := SurvivalUtil.dict(h.get("at_100"))
	var cap := SurvivalUtil.num(core.data.section("skills", "handling_cap").get("max_abs_effect"), 0.2)
	var lvl := clampf(SurvivalSkills.level(core, sk) / 100.0, 0.0, 1.0)
	for k in at.keys():
		var v := 1.0 + (SurvivalUtil.num(at[k], 1.0) - 1.0) * lvl
		out[k] = clampf(v, 1.0 - cap, 1.0 + cap)
	return out


## Conditions for the HUD: the three most severe, with masked icons hidden (tell_mask hides icons and body tells only).
static func icons(core: SurvivalCore, mods: Dictionary = {}) -> Array:
	if mods.is_empty():
		mods = core.get_modifiers()
	var masked: Array = SurvivalUtil.arr(mods.get("tell_mask"))
	var list := []
	for id in core.state.conditions.keys():
		if masked.has(id) or bool(core.state.conditions[id].get("incubating", false)):
			continue
		var row := core.data.condition(str(id))
		list.append({"id": str(id), "stage": str(core.state.conditions[id].stage), "icon": str(row.get("icon", "")),
				"name": str(row.get("name", id)), "severity": severity(core, str(id))})
	list.sort_custom(func(a, b): return float(a.severity) > float(b.severity))
	var n := int(SurvivalUtil.num(SurvivalUtil.dict(core.data.section("conditions", "modifier_contract").get("stacking_limit")).get("max_icons_shown"), 3.0))
	return list.slice(0, n)
