class_name SurvivalSkills
extends RefCounted
## Skills, the check and growth model v4 (skills.json; survival_gdd.md section 7; redesign_skills.md section 4).
##
##   p = clamp(0.55 + (S - D) / 60 + modifiers, 0.05, 0.97)
##   roll r: r < 0.1p excellent | r < p success | r < p + 0.20 partial | else failure (mishap if r > 0.97 on hazards)
##   gain = k * base_xp * C(p_task) * O(outcome) * L(S) * R(n)   (+ k * base_xp * 0.5 * L(S) once, on an action's first success)
##   C(p) = clamp((1 - p) / 0.45, 0.15, 1.5) * min(1, p / 0.25)     challenge, from the chance on the prompt
##   L(S) = 1 / (1 + (S / s50)^3), s50 = 45; 50 for a calling       R(n) = 1 / (1 + (n - 1) / 3), the n-th use today
## p_task is the chance with the task's own modifiers only (weather, dark, cold hands, damp tinder, untried, second try);
## impairments (drink, exhaustion, hunger, illness, injury) and hurrying never add learning. Caps: 5 points a day per skill
## and 10 a day across the working skills, whatever the source (checks, first-success bonuses, lessons, pool-doubled
## practice, watching). Callings: a character's three highest working skills at Journeyman or above. No background
## multipliers; weapon skills grow from use only (outside the daily total) and never roll from crafting.

## Weapon-skill experience per use event, in skill points (skills.json skills[].grows_from text).
const WEAPON_XP := {
	"marksmanship": {"reload_complete": 0.02, "reload_complete_no_threat": 0.01, "hit_beyond_30m": 0.05, "clean_kill": 0.1},
	"archery": {"full_draw_release": 0.01, "hit_beyond_20m": 0.05, "clean_kill": 0.1},
	"close_combat": {"landed": 0.03, "landed_sparring": 0.015},
}
## Trade grows from completed trades on one scale, the rv the player gives (barter lines, goods sold, labour, a lesson's
## ask): 1 base xp per 15 d of rv, at most 3 a partner a game day; a book settled in full gives 3; a kept promise or
## labour worked off 1. Haggling is a Trade check (actions.json trade.haggle base_xp 2). Fix round 1: was 240 d of rv
## (barter) or of pence received (sales, about twice the rv), which put Journeyman Trade over ten game years away and
## grew Trade faster on the money path (redesign_balance_report.md F7); 15 d puts a barter-heavy player at Journeyman
## in about two game years (GDD 7.8).
const TRADE_D_PER_XP := 15.0
const TRADE_MAX_XP_PER_VISIT := 3.0
const TRADE_SETTLED_XP := 3.0
const TRADE_PROMISE_KEPT_XP := 1.0
## A clean kill on an unaware animal gives Hunting base_xp 3 (skills.json hunting grows_from).
const HUNT_CLEAN_KILL_XP := 3.0
## Trapping and Fishing from the rod (FishingGear; user 2026-09-28: the skill "trained" by fishing): a strike that holds
## base_xp FISH_STRIKE_XP; a fish landed FISH_LANDED_XP and FISH_XP_PER_LB a pound more, at most FISH_LANDED_MAX.
const FISH_STRIKE_XP := 0.3
const FISH_LANDED_XP := 1.0
const FISH_XP_PER_LB := 0.4
const FISH_LANDED_MAX := 4.0


static func level(core: SurvivalCore, id: String) -> float:
	return SurvivalUtil.num(core.state.skills.get(id), 0.0)


static func set_level(core: SurvivalCore, id: String, v: float) -> void:
	var old := level(core, id)
	var nv := clampf(v, 0.0, 100.0)
	core.state.skills[id] = nv
	if absf(nv - old) > 0.00001:
		var t_old := tier_of_level(core, old)
		var t_new := tier_of_level(core, nv)
		core._on_skill_changed(id, old, nv)
		if t_new != t_old and nv > old:
			core._on_skill_tier(id, t_new)
			SurvivalLearning.tier_notices(core, id, t_new)


static func tier_of_level(core: SurvivalCore, lvl: float) -> String:
	var best := "novice"
	for t in SurvivalUtil.arr(core.data.raw.skills.get("tiers")):
		if lvl >= SurvivalUtil.num(t.get("min"), 0.0):
			best = str(t.id)
	return best


static func tier(core: SurvivalCore, id: String) -> String:
	return tier_of_level(core, level(core, id))


static func tier_min(core: SurvivalCore, tier_id: String) -> float:
	for t in SurvivalUtil.arr(core.data.raw.skills.get("tiers")):
		if str(t.id) == tier_id:
			return SurvivalUtil.num(t.get("min"), 0.0)
	return 0.0


## The value of a tier flag for a skill at its current level (later tiers override earlier ones), or `def`. Tiers give
## benefits (flags) and notices; they never lock an action (redesign_skills.md 5.5).
static func flag(core: SurvivalCore, skill_id: String, flag_name: String, def = null):
	var lvl := level(core, skill_id)
	var out = def
	var tu := SurvivalUtil.dict(core.data.skill(skill_id).get("tier_unlocks"))
	for t in SurvivalUtil.arr(core.data.raw.skills.get("tiers")):
		if lvl < SurvivalUtil.num(t.get("min"), 0.0):
			break
		var fl := SurvivalUtil.dict(SurvivalUtil.dict(tu.get(str(t.id))).get("flags"))
		if fl.has(flag_name):
			out = fl[flag_name]
	return out


## Techniques noticed through the tiers reached (skills.json tier_unlocks[].notices; they become heard of).
static func noticed_by_tiers(core: SurvivalCore) -> Array:
	var out := []
	for sk in core.data.skills.keys():
		var lvl := level(core, str(sk))
		var tu := SurvivalUtil.dict(core.data.skill(str(sk)).get("tier_unlocks"))
		for t in SurvivalUtil.arr(core.data.raw.skills.get("tiers")):
			if lvl >= SurvivalUtil.num(t.get("min"), 0.0):
				for a in SurvivalUtil.arr(SurvivalUtil.dict(tu.get(str(t.id))).get("notices")):
					out.append(str(a))
	return out


static func chance(core: SurvivalCore, S: float, D: float, mods_sum: float) -> float:
	var m := core.data.check_model()
	return clampf(SurvivalUtil.num(m.get("base"), 0.55) + (S - D) / SurvivalUtil.num(m.get("slope"), 60.0) + mods_sum,
			SurvivalUtil.num(m.get("floor"), 0.05), SurvivalUtil.num(m.get("cap"), 0.97))


## Roll an outcome tier for chance p. hazard: the action lists a hazard (mishaps possible). hurry lowers mishap_r.
static func roll(core: SurvivalCore, p: float, hazard: bool, hurry: bool = false) -> String:
	var orl := SurvivalUtil.dict(core.data.check_model().get("outcome_roll"))
	var r := core.rng.randf()
	if r < SurvivalUtil.num(orl.get("excellent_frac"), 0.1) * p:
		return "excellent"
	if r < p:
		return "success"
	if r < p + SurvivalUtil.num(orl.get("partial_band"), 0.2):
		return "partial"
	var mishap_r := SurvivalUtil.num(orl.get("mishap_r"), 0.97)
	if hurry:
		mishap_r = SurvivalUtil.num(SurvivalUtil.dict(core.data.section("actions", "job_runner").get("hurry")).get("mishap_r"), 0.94)
	if hazard and r > mishap_r:
		return "mishap"
	return "failure"


# ---------------------------------------------------------------- the day's bookkeeping (the local player's)
static func _log(core: SurvivalCore) -> Dictionary:
	var sl := core.state.skill_log
	var today := SurvivalClock.abs_day(core)
	if int(SurvivalUtil.num(sl.get("day"), -1.0)) != today:
		sl["day"] = today
		sl["uses"] = {}
		sl["xp"] = {}
		sl["total"] = 0.0
		sl["watched"] = {}
		sl["watch_uses"] = {}
		sl["lessons"] = {}
	if not sl.has("total"):
		sl["total"] = 0.0
	return sl


static func uses_today(core: SurvivalCore, action_id: String) -> int:
	return int(SurvivalUtil.num(SurvivalUtil.dict(_log(core).get("uses")).get(action_id), 0.0))


static func xp_today(core: SurvivalCore, skill_id: String) -> float:
	return SurvivalUtil.num(SurvivalUtil.dict(_log(core).get("xp")).get(skill_id), 0.0)


## Points gained today across the working skills (the daily total of 10).
static func total_today(core: SurvivalCore) -> float:
	return SurvivalUtil.num(_log(core).get("total"), 0.0)


static func is_working(core: SurvivalCore, sk: String) -> bool:
	return core.data.working_skills().has(sk)


## The three highest working skills at Journeyman or above (ties by id): they use the gentler level curve.
static func callings(core: SurvivalCore) -> Array:
	var gm := core.data.growth_model()
	var cfg := SurvivalUtil.dict(gm.get("callings"))
	var min_l := SurvivalUtil.num(cfg.get("min_level"), 40.0)
	var ranked := []
	for sk in core.data.working_skills():
		var l := level(core, str(sk))
		if l >= min_l:
			ranked.append([l, str(sk)])
	ranked.sort_custom(func(a, b): return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and str(a[1]) < str(b[1])))
	var out := []
	for r in ranked.slice(0, int(SurvivalUtil.num(cfg.get("count"), 3.0))):
		out.append(str(r[1]))
	return out


# ---------------------------------------------------------------- growth model v4
## C(p): how much a check at this chance teaches. 1.0 at a fair 55%, up to 1.5 for hard work, down to 0.15 for routine
## work, and lower again for work far beyond the character (below p_low).
static func challenge(core: SurvivalCore, p_task: float) -> float:
	var ch := SurvivalUtil.dict(core.data.growth_model().get("challenge"))
	var c := clampf((1.0 - p_task) / SurvivalUtil.num(ch.get("ref"), 0.45), SurvivalUtil.num(ch.get("min"), 0.15), SurvivalUtil.num(ch.get("max"), 1.5))
	return c * minf(1.0, p_task / maxf(0.0001, SurvivalUtil.num(ch.get("p_low"), 0.25)))


## L(S) = 1 / (1 + (S / s50)^b): near 1 for a novice, 0.5 at s50, a long tail toward mastery. A calling uses s50_calling.
static func level_factor(core: SurvivalCore, S: float, sk: String = "") -> float:
	var lc := SurvivalUtil.dict(core.data.growth_model().get("level_curve"))
	var s50 := SurvivalUtil.num(lc.get("s50"), 45.0)
	if sk != "" and callings(core).has(sk):
		s50 = SurvivalUtil.num(lc.get("s50_calling"), s50)
	return 1.0 / (1.0 + pow(maxf(S, 0.0) / s50, SurvivalUtil.num(lc.get("b"), 3.0)))


## R(n) = 1 / (1 + (n - 1) / h): the n-th use of the same action in a game day.
static func repeat_factor(core: SurvivalCore, n: int) -> float:
	var h := SurvivalUtil.num(SurvivalUtil.dict(core.data.growth_model().get("repeat_rule")).get("half_value_uses"), 3.0)
	return 1.0 / (1.0 + float(maxi(1, n) - 1) / h)


static func outcome_mult(core: SurvivalCore, outcome: String) -> float:
	return SurvivalUtil.num(SurvivalUtil.dict(core.data.growth_model().get("outcome_mult")).get(outcome), 0.7)


## Experience from one completed check. Records the use and returns the points gained. task_mods: the check's task
## modifiers only (the job stores them next to mods_sum); null uses mods_sum (tools and old saves).
static func gain_from_check(core: SurvivalCore, a: Dictionary, D: float, outcome: String, mods_sum: float, p: float, task_mods = null) -> float:
	var sk := str(a.get("skill", ""))
	var aid := str(a.get("id", ""))
	var sl := _log(core)
	var uses: Dictionary = sl.uses
	uses[aid] = int(SurvivalUtil.num(uses.get(aid), 0.0)) + 1
	var gm := core.data.growth_model()
	if sk == "" or SurvivalUtil.arr(gm.get("no_xp_actions")).has(aid):
		return 0.0
	if WEAPON_XP.has(sk):
		return 0.0
	var base_xp := SurvivalUtil.num(a.get("base_xp"), 0.0)
	var S := level(core, sk)
	if base_xp <= 0.0 or D < S - SurvivalUtil.num(gm.get("trivial_below"), 35.0):
		return 0.0
	var tmods: float = mods_sum if task_mods == null else float(task_mods)
	var p_task := chance(core, S, D, tmods)
	var k := SurvivalUtil.num(gm.get("k_skill"), 0.4)
	var lf := level_factor(core, S, sk)
	var pts := k * base_xp * challenge(core, p_task) * outcome_mult(core, outcome) * lf * repeat_factor(core, int(uses[aid]))
	# The first success (or partial) of an action by this character teaches the most, once.
	if outcome != "failure" and outcome != "mishap":
		var done := SurvivalLearning.first_success_set(core)
		if not done.has(aid):
			done.append(aid)
			pts += k * base_xp * SurvivalUtil.num(gm.get("first_success_bonus"), 0.5) * lf
	return practice(core, sk, pts)


## Practice points: doubled by an active lesson pool for the skill until the pool is spent (redesign_skills.md 6.1).
static func practice(core: SurvivalCore, sk: String, pts: float) -> float:
	if pts <= 0.0:
		return 0.0
	# the game's growth multiplier (SurvivalBridge.skill_mult: well rested faster, wasted slower); 1 without the game
	pts *= SurvivalUtil.num(core.state.flags.get("skill_growth_mult"), 1.0)
	var extra := SurvivalLearning.draw_pool(core, sk, pts)
	return _apply(core, sk, pts + extra, extra)


## What one check of this action would teach this character at the chance on the prompt (watching gives a share of it).
static func expected_gain(core: SurvivalCore, a: Dictionary, D: float, p_task: float) -> float:
	var sk := str(a.get("skill", ""))
	var gm := core.data.growth_model()
	var S := level(core, sk)
	var base_xp := SurvivalUtil.num(a.get("base_xp"), 0.0)
	if sk == "" or WEAPON_XP.has(sk) or base_xp <= 0.0 or D < S - SurvivalUtil.num(gm.get("trivial_below"), 35.0):
		return 0.0
	var band := SurvivalUtil.num(SurvivalUtil.dict(core.data.check_model().get("outcome_roll")).get("partial_band"), 0.2)
	var pa := minf(1.0, p_task + band) - p_task
	var om := p_task * outcome_mult(core, "success") + pa * outcome_mult(core, "partial") + (1.0 - p_task - pa) * outcome_mult(core, "failure")
	return SurvivalUtil.num(gm.get("k_skill"), 0.4) * base_xp * challenge(core, p_task) * om * level_factor(core, S, sk)


## Add points to a skill under the per-skill cap and, for working skills, the daily total. Returns the points added.
## pool_part: the share of pts that came from a lesson pool; what the caps cut from it goes back into the pool.
static func _apply(core: SurvivalCore, sk: String, pts: float, pool_part: float = 0.0) -> float:
	if pts <= 0.0:
		return 0.0
	var sl := _log(core)
	var xp: Dictionary = sl.xp
	var dc := SurvivalUtil.dict(core.data.growth_model().get("daily_cap"))
	var room := maxf(0.0, SurvivalUtil.num(dc.get("skill"), 5.0) - SurvivalUtil.num(xp.get(sk), 0.0))
	var working := is_working(core, sk)
	if working:
		room = minf(room, maxf(0.0, SurvivalUtil.num(dc.get("total_working_skills"), 10.0) - total_today(core)))
	var got := minf(pts, room)
	var cut := pts - got
	if pool_part > 0.0 and cut > 0.0:
		SurvivalLearning.refund_pool(core, sk, minf(pool_part, cut))
	if got <= 0.0:
		return 0.0
	xp[sk] = SurvivalUtil.num(xp.get(sk), 0.0) + got
	if working:
		sl["total"] = total_today(core) + got
	set_level(core, sk, level(core, sk) + got)
	return got


## Points from a lesson or from watching, under the same caps (redesign_skills.md 4.1).
static func add_points(core: SurvivalCore, sk: String, pts: float) -> float:
	return _apply(core, sk, pts)


## Use-based growth for weapon skills (the player's shots, reloads and blows). event: a WEAPON_XP key.
static func record_weapon_event(core: SurvivalCore, sk: String, event: String) -> float:
	var t := SurvivalUtil.dict(WEAPON_XP.get(sk))
	if not t.has(event):
		return 0.0
	return _apply(core, sk, float(t[event]))


## Trade grows from completed trades and settled accounts, never from clicking gift. amount_rv: the rv the player gave;
## partner: who it was with (at most TRADE_MAX_XP_PER_VISIT base xp from one partner in a game day).
static func record_trade(core: SurvivalCore, amount_rv: float, settled_in_full: bool = false, partner: String = "") -> float:
	var base := minf(TRADE_MAX_XP_PER_VISIT, maxf(0.0, amount_rv) / TRADE_D_PER_XP)
	if partner != "" and base > 0.0:
		var c: Dictionary = core.player().counters
		var key := "trade_xp|%s" % partner
		var rec := SurvivalUtil.dict(c.get(key))
		var today := SurvivalClock.abs_day(core)
		var used := SurvivalUtil.num(rec.get("xp"), 0.0) if int(SurvivalUtil.num(rec.get("day"), -1.0)) == today else 0.0
		base = minf(base, maxf(0.0, TRADE_MAX_XP_PER_VISIT - used))
		c[key] = {"day": today, "xp": used + base}
	if settled_in_full:
		base += TRADE_SETTLED_XP
	return _generic_gain(core, "trade", base)


## Labour worked off for another party (a service kept) teaches Trade like a kept promise.
static func record_labour_kept(core: SurvivalCore) -> float:
	return _generic_gain(core, "trade", TRADE_PROMISE_KEPT_XP)


static func record_promise_kept(core: SurvivalCore) -> float:
	return _generic_gain(core, "trade", TRADE_PROMISE_KEPT_XP)


## Hunting grows from a clean kill on an unaware animal (base_xp 3).
static func record_clean_kill(core: SurvivalCore) -> float:
	return _generic_gain(core, "hunting", HUNT_CLEAN_KILL_XP)


## Trapping and Fishing grows from the rod: event "strike" (the hook held) or "landed" (a fish of `lb` pounds taken).
static func record_fish(core: SurvivalCore, event: String, lb := 0.0) -> float:
	var base := 0.0
	match event:
		"strike":
			base = FISH_STRIKE_XP
		"landed":
			base = minf(FISH_LANDED_XP + FISH_XP_PER_LB * maxf(lb, 0.0), FISH_LANDED_MAX)
	return _generic_gain(core, "trapping", base)


static func _generic_gain(core: SurvivalCore, sk: String, base_xp: float) -> float:
	if base_xp <= 0.0 or not core.data.skills.has(sk):
		return 0.0
	var gm := core.data.growth_model()
	return practice(core, sk, SurvivalUtil.num(gm.get("k_skill"), 0.4) * base_xp * level_factor(core, level(core, sk), sk))


## Passive handling benefits that are not weapon-specific (Hunting: animal detection radius; Trade: spread).
static func passive_effects(core: SurvivalCore) -> Dictionary:
	var out := {}
	for sk in ["hunting", "trade"]:
		var at := SurvivalUtil.dict(SurvivalUtil.dict(core.data.skill(sk).get("handling")).get("at_100"))
		var lvl := clampf(level(core, sk) / 100.0, 0.0, 1.0)
		for k in at.keys():
			var v := SurvivalUtil.num(at[k], 1.0)
			out[k] = (1.0 + (v - 1.0) * lvl) if str(k).ends_with("_mult") else v * lvl
	return out


## A readable summary for UI: [{id, name, level, tier, calling, today, working}].
static func listing(core: SurvivalCore) -> Array:
	var out := []
	var calls := callings(core)
	for sk in core.data.skills.keys():
		out.append({"id": str(sk), "name": str(core.data.skill(str(sk)).get("name", sk)), "level": level(core, str(sk)),
				"tier": tier(core, str(sk)), "calling": calls.has(str(sk)), "today": xp_today(core, str(sk)),
				"working": is_working(core, str(sk))})
	return out
