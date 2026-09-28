class_name SurvivalLearning
extends RefCounted
## Recipe knowledge and the four ways to learn (skills.json knowledge_model; survival_gdd.md 7.5-7.6; redesign_skills.md
## sections 5-8): by doing (SurvivalSkills, growth model v4), by trying (a heard-of or seen recipe becomes known on a
## success, or after 3 clues), by being taught (a lesson from a mentor: M2b), and by watching (M2b). Examining a finished
## thing, talk, notices and tier notices make recipes heard of.
##
## States: unknown, heard_of, seen, known, practised, mastered. Only recipes (rcp.*), techniques (know.*) and actions
## flagged technique: true are gated; plain verbs never are. Knowledge is kept on the technique id where one covers the
## recipe. Every record is PER-PLAYER state (SurvivalState.players[player_id].knowledge and .learning), keyed by stable
## ids, so co-op and a persistent world keep one per character. Nothing here draws a random number.

const STATE_ORDER := ["unknown", "heard_of", "seen", "known", "practised", "mastered"]
const WHAT_SKILL_PREFIX := "skill:"


static func km(core: SurvivalCore) -> Dictionary:
	return core.data.knowledge_model()


static func _k(core: SurvivalCore) -> Dictionary:
	var p := core.player()
	if not p.has("knowledge"):
		p["knowledge"] = {}
	return p.knowledge


static func _l(core: SurvivalCore) -> Dictionary:
	var p := core.player()
	if not p.has("learning"):
		p["learning"] = {}
	var l: Dictionary = p.learning
	for key in ["pools", "recently_taught", "lessons_month", "second_try"]:
		if not l.has(key):
			l[key] = {}
	if not l.has("first_success"):
		l["first_success"] = []
	return l


static func rank(st: String) -> int:
	return maxi(0, STATE_ORDER.find(st))


# ---------------------------------------------------------------- ids, names and states
## Is an action gated by knowledge? technique: true, or a backlog row's requires.knowledge. Plain verbs never are.
static func gates_action(core: SurvivalCore, a: Dictionary) -> bool:
	return gates_action_row(core.data, a)


## The same, from the data alone (the save migration runs before a core exists).
static func gates_action_row(data: SurvivalData, a: Dictionary) -> bool:
	if bool(a.get("plain_verb", false)):
		return false
	if SurvivalUtil.arr(data.knowledge_model().get("plain_verbs")).has(str(a.get("id", ""))):
		return false
	return bool(a.get("technique", false)) or SurvivalUtil.dict(a.get("requires")).has("knowledge")


static func is_common(core: SurvivalCore, kid: String) -> bool:
	return SurvivalUtil.arr(km(core).get("common_knowledge")).has(kid)


## Community-held knowledge is taught by the community's choice only: no notices, no trial, no examining.
static func community_held(core: SurvivalCore, kid: String) -> bool:
	var row := SurvivalUtil.dict(core.data.knowledge.get(kid))
	if bool(row.get("community_held", false)):
		return true
	return bool(core.data.recipe(kid).get("community_held", false)) or bool(core.data.action(kid).get("community_held", false))


static func display_name(core: SurvivalCore, kid: String) -> String:
	var row := SurvivalUtil.dict(core.data.knowledge.get(kid))
	if not row.is_empty():
		return str(row.get("name", kid)).to_lower()
	var r := core.data.recipe(kid)
	if not r.is_empty():
		var outs := SurvivalUtil.dict(r.get("outputs")).keys()
		if not outs.is_empty():
			return core.data.item_name(str(outs[0])).to_lower()
	var a := core.data.action(kid)
	if not a.is_empty():
		return str(a.get("name", kid)).to_lower()
	return kid.get_slice(".", kid.get_slice_count(".") - 1).replace("_", " ")


static func state_of(core: SurvivalCore, kid: String) -> String:
	var rec := SurvivalUtil.dict(_k(core).get(kid))
	if not rec.is_empty():
		return str(rec.get("state", "unknown"))
	if is_common(core, kid):
		return "known"
	if SurvivalUtil.arr(km(core).get("common_heard_of")).has(kid):
		return "heard_of"
	return "unknown"


static func record(core: SurvivalCore, kid: String) -> Dictionary:
	var k := _k(core)
	if not k.has(kid):
		k[kid] = {"state": state_of(core, kid), "successes": 0, "excellent_good": 0, "clues": 0, "seen_from": [],
				"taught_by": [], "how": "common" if is_common(core, kid) else ""}
	return k[kid]


## Raise a knowledge state (never lowers it). how: background, trial, clues, notice, tier, examine, talk, watched, taught.
static func set_state(core: SurvivalCore, kid: String, new_state: String, how: String, who: String = "", quiet: bool = false) -> bool:
	var rec := record(core, kid)
	var old := str(rec.get("state", "unknown"))
	if rank(new_state) <= rank(old):
		if who != "" and how == "taught" and not SurvivalUtil.arr(rec.taught_by).has(who):
			rec.taught_by.append(who)
		return false
	rec["state"] = new_state
	rec["how"] = how
	if who != "":
		var key := "taught_by" if how == "taught" else "seen_from"
		if not SurvivalUtil.arr(rec.get(key)).has(who):
			rec[key].append(who)
	if not quiet:
		var name := display_name(core, kid)
		var text := ""
		match new_state:
			"heard_of":
				text = "You have heard of %s." % name
			"seen":
				text = "You have seen how %s is done." % name
			"known":
				text = "You have worked out how to make %s." % name if how in ["trial", "clues"] else "You know %s now." % name
			"practised":
				text = "%s: practised (you could teach it)." % name.capitalize()
			"mastered":
				text = "%s: mastered." % name.capitalize()
		core.log_line(text, "knowledge")
	core._on_knowledge_changed(kid, old, new_state)
	return true


## The attempt terms for a knowledge id (knowledge_model.attempt): {state, allowed, d_add, untried_add, time_mult}.
static func attempt(core: SurvivalCore, kid: String) -> Dictionary:
	var st := state_of(core, kid)
	var row := SurvivalUtil.dict(SurvivalUtil.dict(km(core).get("attempt")).get(st))
	var add = row.get("add", 0.0)
	return {"state": st, "allowed": st != "unknown", "d_add": SurvivalUtil.num(row.get("d_add"), 0.0),
			"untried_add": SurvivalUtil.num(add, 0.0) if row.get("modifier", "") == "mod.untried" else 0.0,
			"time_mult": SurvivalUtil.num(row.get("time_mult"), 1.0)}


## The knowledge id a job works on: its recipe's, or the technique action's; "" when the action is not gated.
static func job_kid(core: SurvivalCore, a: Dictionary, res: Dictionary) -> String:
	var rid := str(res.get("recipe", ""))
	if rid != "":
		return core.data.recipe_knowledge_id(rid)
	if gates_action(core, a):
		return core.data.action_knowledge_id(str(a.get("id", "")))
	return ""


## A finished attempt: trial promotion (heard of or seen -> known on a success or partial; failures give clues), and
## counted successes toward practised and mastered.
static func record_result(core: SurvivalCore, kid: String, outcome: String, standard: String = "plain") -> void:
	if kid == "":
		return
	var rec := record(core, kid)
	var st := str(rec.get("state", "unknown"))
	var good := outcome in ["excellent", "success", "partial"]
	if st == "heard_of" or st == "seen":
		if good:
			set_state(core, kid, "known", "trial")
		else:
			var per := SurvivalUtil.dict(km(core).get("clues_per_failure"))
			rec["clues"] = int(SurvivalUtil.num(rec.get("clues"), 0.0)) + int(SurvivalUtil.num(per.get(st), 1.0))
			if int(rec.clues) >= int(SurvivalUtil.num(km(core).get("clues_needed"), 3.0)):
				set_state(core, kid, "known", "clues")
			else:
				core.log_line("%s: a clue (%d of %d)" % [display_name(core, kid).capitalize(), int(rec.clues),
						int(SurvivalUtil.num(km(core).get("clues_needed"), 3.0))], "knowledge")
		return
	if outcome == "excellent" or outcome == "success":
		rec["successes"] = int(SurvivalUtil.num(rec.get("successes"), 0.0)) + (2 if outcome == "excellent" else 1)
		if outcome == "excellent" and standard in ["good", "fine", "masterwork"]:
			rec["excellent_good"] = int(SurvivalUtil.num(rec.get("excellent_good"), 0.0)) + 1
	var pr := SurvivalUtil.dict(km(core).get("promote"))
	var to_p := SurvivalUtil.dict(pr.get("to_practised"))
	var to_m := SurvivalUtil.dict(pr.get("to_mastered"))
	if str(rec.state) == "known" and int(rec.successes) >= int(SurvivalUtil.num(to_p.get("successes"), 5.0)):
		set_state(core, kid, "practised", "practice")
	if str(rec.state) == "practised" and int(rec.successes) >= int(SurvivalUtil.num(to_m.get("successes"), 20.0)) \
			and int(rec.get("excellent_good", 0)) >= int(SurvivalUtil.num(to_m.get("excellent_at_good_or_better"), 3.0)):
		set_state(core, kid, "mastered", "practice")


## A background's head start: known, seen and heard-of recipes and techniques (set quietly at creation).
static func init_from_background(core: SurvivalCore, bg: Dictionary) -> void:
	for pair in [["known", "known"], ["seen", "seen"], ["heard_of", "heard_of"]]:
		for kid in SurvivalUtil.arr(bg.get(pair[0])):
			set_state(core, str(kid), str(pair[1]), "background", "", true)


# ---------------------------------------------------------------- the day's learning bookkeeping
static func first_success_set(core: SurvivalCore) -> Array:
	return _l(core).first_success


static func note_failure(core: SurvivalCore, action_id: String) -> void:
	var st := SurvivalUtil.dict(SurvivalUtil.dict(core.data.growth_model().get("second_try")))
	_l(core).second_try[action_id] = core.state.minutes + SurvivalUtil.num(st.get("within_game_min"), 120.0)


static func second_try_active(core: SurvivalCore, action_id: String) -> bool:
	return SurvivalUtil.num(_l(core).second_try.get(action_id), -1.0) >= core.state.minutes


static func clear_second_try(core: SurvivalCore, action_id: String) -> void:
	_l(core).second_try.erase(action_id)


static func recently_taught(core: SurvivalCore, kid: String) -> bool:
	return kid != "" and SurvivalUtil.num(_l(core).recently_taught.get(kid), -1.0) >= core.state.minutes


## Lesson pools double practice in a skill for 3 game days until spent. Returns the extra points drawn for `pts`.
static func draw_pool(core: SurvivalCore, sk: String, pts: float) -> float:
	var pools: Dictionary = _l(core).pools
	var pool := SurvivalUtil.dict(pools.get(sk))
	if pool.is_empty():
		return 0.0
	if SurvivalUtil.num(pool.get("until"), -1.0) < core.state.minutes:
		pools.erase(sk)
		return 0.0
	var mult := SurvivalUtil.num(SurvivalUtil.dict(km(core).get("lesson")).get("pool_mult"), 2.0)
	var extra := minf(pts * (mult - 1.0), SurvivalUtil.num(pool.get("points"), 0.0))
	pool["points"] = SurvivalUtil.num(pool.get("points"), 0.0) - extra
	if float(pool.points) <= 0.0001:
		pools.erase(sk)
	return maxf(0.0, extra)


static func refund_pool(core: SurvivalCore, sk: String, pts: float) -> void:
	var pools: Dictionary = _l(core).pools
	if pools.has(sk):
		pools[sk]["points"] = SurvivalUtil.num(pools[sk].get("points"), 0.0) + pts
	else:
		var days := SurvivalUtil.num(SurvivalUtil.dict(km(core).get("lesson")).get("pool_game_days"), 3.0)
		pools[sk] = {"points": pts, "until": core.state.minutes + days * SurvivalClock.MIN_PER_DAY}


static func pool_left(core: SurvivalCore, sk: String) -> float:
	var pool := SurvivalUtil.dict(_l(core).pools.get(sk))
	if pool.is_empty() or SurvivalUtil.num(pool.get("until"), -1.0) < core.state.minutes:
		return 0.0
	return SurvivalUtil.num(pool.get("points"), 0.0)


# ---------------------------------------------------------------- discovery: notices, tiers, examining, talk
## Every notice in the data: recipes' routes.trial.notice and the actions' (knowledge_model.notices).
static func _notices(core: SurvivalCore) -> Array:
	var out := []
	for rid in SurvivalUtil.sorted_ids(core.data.recipes):
		var n := SurvivalUtil.dict(SurvivalUtil.dict(SurvivalUtil.dict(core.data.recipe(rid).get("routes")).get("trial")).get("notice"))
		if not n.is_empty():
			out.append([core.data.recipe_knowledge_id(rid), n])
	var an := SurvivalUtil.dict(km(core).get("notices"))
	for aid in an.keys():
		out.append([core.data.action_knowledge_id(str(aid)), SurvivalUtil.dict(an[aid])])
	return out


static func _notice_holds(core: SurvivalCore, n: Dictionary) -> bool:
	var mq := SurvivalUtil.dict(n.get("min_qty"))
	for it in SurvivalUtil.arr(n.get("carrying")):
		if SurvivalInventory.count_usable(core, str(it)) < SurvivalUtil.num(mq.get(str(it)), 1.0) - 0.0001:
			return false
	for tag in SurvivalUtil.arr(n.get("near")):
		if not SurvivalJobs._near_ok(core, str(tag), {}):
			return false
	var sm := SurvivalUtil.dict(n.get("skill_min"))
	for sk in sm.keys():
		if SurvivalSkills.level(core, str(sk)) < SurvivalUtil.num(sm[sk], 0.0):
			return false
	return true


## Simple, generic work is discovered blind: when a notice's context holds, an unknown recipe becomes heard of with a
## line of thought in the journal. Called after jobs and at dawn. Returns the ids noticed.
static func check_notices(core: SurvivalCore) -> Array:
	var got := []
	for pair in _notices(core):
		var kid := str(pair[0])
		if state_of(core, kid) != "unknown" or community_held(core, kid):
			continue
		var n: Dictionary = pair[1]
		if not _notice_holds(core, n):
			continue
		core.log_line(str(n.get("text", "")), "notice")
		set_state(core, kid, "heard_of", "notice", "", true)
		core._on_notice(kid, str(n.get("text", "")))
		got.append(kid)
	return got


## Reaching a tier makes its techniques heard of (skills.json tier_unlocks[].notices); nothing is locked by tier.
static func tier_notices(core: SurvivalCore, sk: String, tier_id: String) -> void:
	var row := SurvivalUtil.dict(SurvivalUtil.dict(core.data.skill(sk).get("tier_unlocks")).get(tier_id))
	for kid in SurvivalUtil.arr(row.get("notices")):
		if state_of(core, str(kid)) == "unknown" and not community_held(core, str(kid)):
			set_state(core, str(kid), "heard_of", "tier")


## The recipes that make an item, by knowledge id (community-held knowledge excluded).
static func examine_targets(core: SurvivalCore, item_id: String) -> Array:
	var out := []
	for rid in SurvivalUtil.arr(core.data.recipes_by_output.get(item_id)):
		var kid := core.data.recipe_knowledge_id(str(rid))
		if not community_held(core, kid) and not out.has(kid):
			out.append(kid)
	return out


## Can the player examine this item here? It must be carried or in reach (context.near "item:<id>").
static func can_examine(core: SurvivalCore, item_id: String) -> bool:
	if item_id == "" or core.data.item(item_id).is_empty():
		return false
	return SurvivalInventory.has(core, item_id, 0.0001) or SurvivalUtil.arr(core.state.context.get("near")).has("item:" + item_id)


## learn.examine: every unknown recipe that makes the item becomes heard of. Returns the ids that changed.
static func examine(core: SurvivalCore, item_id: String) -> Array:
	var got := []
	for kid in examine_targets(core, item_id):
		if state_of(core, str(kid)) == "unknown" and set_state(core, str(kid), "heard_of", "examine"):
			got.append(kid)
	return got


## Talk (the learn.ask_about topic): a partner's talk makes the recipes it names heard of.
static func talk(core: SurvivalCore, npc_id: String) -> Array:
	var got := []
	for kid in SurvivalUtil.arr(mentor(core, npc_id).get("talk_heard_of")):
		if state_of(core, str(kid)) == "unknown" and set_state(core, str(kid), "heard_of", "talk", npc_id):
			got.append(str(kid))
	return got


# ---------------------------------------------------------------- lessons (M2b)
static func mentor(core: SurvivalCore, npc_id: String) -> Dictionary:
	return SurvivalUtil.dict(SurvivalUtil.dict(core.data.individuals.get(npc_id)).get("mentor"))


static func teach_entry(core: SurvivalCore, npc_id: String, what: String) -> Dictionary:
	for e in SurvivalUtil.arr(mentor(core, npc_id).get("teaches")):
		if what.begins_with(WHAT_SKILL_PREFIX):
			if str(e.get("skill", "")) == what.trim_prefix(WHAT_SKILL_PREFIX):
				return e
		elif str(e.get("id", "")) == what:
			return e
	return {}


## The skill a lesson is in: a skill lesson's, else the recipe's or technique's.
static func lesson_skill(core: SurvivalCore, what: String) -> String:
	if what.begins_with(WHAT_SKILL_PREFIX):
		return what.trim_prefix(WHAT_SKILL_PREFIX)
	var kr := SurvivalUtil.dict(core.data.knowledge.get(what))
	if kr.has("skill"):
		return str(kr.skill)
	var r := core.data.recipe(what)
	if not r.is_empty():
		return str(r.get("skill", core.data.skill_of(str(r.get("action", "")))))
	return core.data.skill_of(what)


static func _lesson_cfg(core: SurvivalCore) -> Dictionary:
	return SurvivalUtil.dict(km(core).get("lesson"))


static func _month_key(core: SurvivalCore, npc_id: String) -> String:
	return "%s|%d|%s" % [npc_id, SurvivalClock.year(core), SurvivalClock.month_id(core)]


## The open lesson this mentor owes the player for `what` (agreed, not yet given), or {}.
static func open_lesson(core: SurvivalCore, npc_id: String, what: String) -> Dictionary:
	for ob in SurvivalTrade.obligations_of(core, core.state.player_id, true):
		if str(ob.kind) == "lesson" and str(ob.from) == npc_id and str(SurvivalUtil.dict(ob.what).get("what", "")) == what:
			return ob
	return {}


## Game minutes the lesson job will take for this learner (social.ask_teach's working time, no check).
static func lesson_minutes(core: SurvivalCore) -> float:
	var a := core.data.action("social.ask_teach")
	if a.is_empty():
		return 0.0
	return SurvivalJobs.work_minutes(core, a, SurvivalSkills.level(core, str(a.get("skill", ""))), SurvivalUtil.num(a.get("difficulty"), 0.0), false, {}, {})


## Can this mentor teach this now? {ok, reason, skill, T, S}. A refusal costs nothing and says why. A lesson already
## agreed and not yet given resumes without a new ask; any lesson must fit before the mentor leaves (fix round 1: a
## lesson cut short by the mentor's schedule was paid for and never given).
static func lesson_check(core: SurvivalCore, npc_id: String, what: String) -> Dictionary:
	var out := {"ok": false, "reason": "", "skill": lesson_skill(core, what)}
	var resuming := not open_lesson(core, npc_id, what).is_empty()
	if core.data.action("social.ask_teach").is_empty():
		out.reason = "lessons are not in this build (M2b)"
		return out
	var m := mentor(core, npc_id)
	var e := teach_entry(core, npc_id, what)
	if m.is_empty() or e.is_empty():
		out.reason = "that is not mine to teach"
		return out
	if not SurvivalTrade.partner_present(core, npc_id):
		out.reason = "%s is not here" % core.npc_title(npc_id)
		return out
	if SurvivalTrade.present_minutes(core, npc_id) < lesson_minutes(core) - 0.001:
		out.reason = "not enough time before %s has to leave: come back earlier" % core.npc_title(npc_id)
		return out
	if SurvivalConditions.stage_of(core, "cond.drunk") in ["tipsy", "drunk", "senseless"]:
		out.reason = "come back sober"
		return out
	if npc_id == "npc.fort.sutler" and SurvivalEconomy.is_open(core, "mkt.visiting_trader"):
		out.reason = "not while the trader is here: she is busy"
		return out
	if npc_id == "npc.fort.sutler" and SurvivalEconomy.standing(core, "faction.garrison") < 0.0:
		out.reason = "the garrison does not think well of you"
		return out
	var sk := str(out.skill)
	var T := SurvivalUtil.num(SurvivalUtil.dict(m.get("levels")).get(sk), 0.0)
	var S := SurvivalSkills.level(core, sk)
	out["T"] = T
	out["S"] = S
	var cfg := _lesson_cfg(core)
	if resuming:
		out.ok = true
		out["resumes"] = true
		return out
	if T - S < SurvivalUtil.num(cfg.get("teacher_min_lead"), 15.0):
		out.reason = "you know as much of it as I can show you"
		return out
	if not what.begins_with(WHAT_SKILL_PREFIX) and rank(state_of(core, what)) >= rank("known"):
		out.reason = "you know that already"
		return out
	var lessons: Dictionary = SurvivalSkills._log(core).lessons
	if int(SurvivalUtil.num(lessons.get(sk), 0.0)) >= int(SurvivalUtil.num(cfg.get("per_skill_per_game_day"), 1.0)):
		out.reason = "one lesson a day in a skill: practise what you learned"
		return out
	if int(SurvivalUtil.num(_l(core).lessons_month.get(_month_key(core, npc_id)), 0.0)) >= int(SurvivalUtil.num(cfg.get("per_mentor_per_pupil_per_game_month"), 3.0)):
		out.reason = "that is enough lessons for this month"
		return out
	out.ok = true
	return out


## Whether the learner can meet one ask: {ok, reason}. Coin is never the only ask a mentor lists (tested in the data).
static func ask_ok(core: SurvivalCore, npc_id: String, ask: Dictionary) -> Dictionary:
	if ask.has("friendship"):
		var need := SurvivalUtil.num(ask.friendship, 0.0)
		if SurvivalTrade.trust(core, npc_id) < need - 0.0001:
			return {"ok": false, "reason": "not yet trusted (trust %d)" % int(need)}
		return {"ok": true}
	if ask.has("goods"):
		for it in SurvivalUtil.dict(ask.goods).keys():
			if SurvivalInventory.count_usable(core, str(it)) < SurvivalUtil.num(ask.goods[it], 1.0) - 0.0001:
				return {"ok": false, "reason": "needs %s" % core.data.item_name(str(it)).to_lower()}
		return {"ok": true}
	if ask.has("coin"):
		if SurvivalEconomy.money(core) < int(SurvivalUtil.num(ask.coin, 0.0)):
			return {"ok": false, "reason": "not enough coin"}
		return {"ok": true}
	if ask.has("labour") or ask.has("favour"):
		return {"ok": true}
	if ask.has("first_refusal"):
		for ob in SurvivalTrade.obligations_of(core, core.state.player_id, true):
			if str(ob.kind) == "first_refusal" and str(ob.to) == npc_id:
				return {"ok": false, "reason": "you already owe first refusal"}
		return {"ok": true}
	return {"ok": false, "reason": "unknown ask"}


## What a mentor offers now: [{what, skill, kind, ok, reason, asks: [{ask, ok, reason}]}] (the lesson dialog's list).
static func lesson_offers(core: SurvivalCore, npc_id: String) -> Array:
	var out := []
	for e in SurvivalUtil.arr(mentor(core, npc_id).get("teaches")):
		var what := (WHAT_SKILL_PREFIX + str(e.skill)) if e.has("skill") else str(e.get("id", ""))
		var chk := lesson_check(core, npc_id, what)
		var asks := []
		for a in SurvivalUtil.arr(e.get("asks")):
			var ao := ask_ok(core, npc_id, a)
			asks.append({"ask": a, "ok": bool(ao.ok), "reason": str(ao.get("reason", ""))})
		out.append({"what": what, "skill": str(chk.skill), "kind": "skill" if e.has("skill") else "recipe",
				"ok": bool(chk.ok), "reason": str(chk.reason), "asks": asks})
	return out


## Agree a lesson: the ask is paid through a trade session (SurvivalTrade) that both sides confirm and the authority
## commits, and the mentor's lesson becomes an obligation fulfilled by the social.ask_teach job. Returns
## {ok, reason, tr, ob, params} where params start the lesson job.
static func arrange_lesson(core: SurvivalCore, npc_id: String, what: String, ask_index: int = 0) -> Dictionary:
	var chk := lesson_check(core, npc_id, what)
	if not bool(chk.ok):
		return {"ok": false, "reason": str(chk.reason)}
	# Agreed before and cut short: the lesson resumes, with nothing more asked.
	var ob0 := open_lesson(core, npc_id, what)
	if not ob0.is_empty():
		return {"ok": true, "tr": str(ob0.get("tr", "")), "ob": str(ob0.id), "resumes": true,
				"params": {"mentor": npc_id, "what": what, "ob": str(ob0.id)}}
	var e := teach_entry(core, npc_id, what)
	var asks := SurvivalUtil.arr(e.get("asks"))
	if ask_index < 0 or ask_index >= asks.size():
		return {"ok": false, "reason": "no such ask"}
	var ask: Dictionary = asks[ask_index]
	var ao := ask_ok(core, npc_id, ask)
	if not bool(ao.ok):
		return {"ok": false, "reason": str(ao.reason)}
	var r := SurvivalTrade.lesson_trade(core, npc_id, what, ask)
	if not bool(r.get("ok", false)):
		return r
	return {"ok": true, "tr": str(r.get("tr", "")), "ob": str(r.get("lesson_ob", "")),
			"params": {"mentor": npc_id, "what": what, "ob": str(r.get("lesson_ob", ""))}}


## The lesson's effect when the social.ask_teach job completes (redesign_skills.md 6.1): a recipe or technique becomes
## known with mod.recently_taught for 3 game days; a skill lesson gives immediate points and a practice pool. Both count
## toward the per-skill cap and the daily total.
static func give_lesson(core: SurvivalCore, npc_id: String, what: String) -> Dictionary:
	var cfg := _lesson_cfg(core)
	var sk := lesson_skill(core, what)
	var T := SurvivalUtil.num(SurvivalUtil.dict(mentor(core, npc_id).get("levels")).get(sk), 0.0)
	var S := SurvivalSkills.level(core, sk)
	var res := {"ok": true, "mentor": npc_id, "what": what, "skill": sk, "points": 0.0, "pool": 0.0}
	if what.begins_with(WHAT_SKILL_PREFIX):
		var ceiling := T - SurvivalUtil.num(cfg.get("ceiling_below_teacher"), 10.0)
		var imm := minf(SurvivalUtil.num(cfg.get("immediate_max"), 2.0),
				SurvivalUtil.num(cfg.get("immediate_base"), 0.5) + (T - S) / SurvivalUtil.num(cfg.get("immediate_per"), 20.0))
		imm = clampf(imm, 0.0, maxf(0.0, ceiling - S))
		res.points = SurvivalSkills.add_points(core, sk, imm)
		var pool := minf(SurvivalUtil.num(cfg.get("pool_max"), 4.0),
				SurvivalUtil.num(cfg.get("pool_base"), 1.0) + (T - S) / SurvivalUtil.num(cfg.get("pool_per"), 10.0))
		pool = clampf(pool, 0.0, maxf(0.0, ceiling - SurvivalSkills.level(core, sk)))
		if pool > 0.0:
			_l(core).pools[sk] = {"points": pool, "until": core.state.minutes + SurvivalUtil.num(cfg.get("pool_game_days"), 3.0) * SurvivalClock.MIN_PER_DAY}
		res.pool = pool
		core.log_line("%s showed you %s: +%.1f, and practice counts double for a while" % [core.npc_title(npc_id).capitalize(),
				str(core.data.skill(sk).get("name", sk)), float(res.points)], "lesson")
	else:
		set_state(core, what, "known", "taught", npc_id)
		_l(core).recently_taught[what] = core.state.minutes + SurvivalUtil.num(cfg.get("recently_taught_game_days"), 3.0) * SurvivalClock.MIN_PER_DAY
	var lessons: Dictionary = SurvivalSkills._log(core).lessons
	lessons[sk] = int(SurvivalUtil.num(lessons.get(sk), 0.0)) + 1
	var mk := _month_key(core, npc_id)
	_l(core).lessons_month[mk] = int(SurvivalUtil.num(_l(core).lessons_month.get(mk), 0.0)) + 1
	SurvivalTrade.add_trust(core, npc_id, SurvivalUtil.num(SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("npcs", "standing").get("trust")).get("sources")).get("lesson_taken"), 0.25), "lesson_taken")
	core.state.stats["lessons"] = int(SurvivalUtil.num(core.state.stats.get("lessons"), 0.0)) + 1
	core._on_lesson_finished(npc_id, what, res)
	return res


# ---------------------------------------------------------------- watching (M2b)
## Work being done here that the player can watch: [{performer, action, activity}] from the mentors' demonstrates
## lists and their schedules (players' jobs join this list in co-op, from their job events).
static func watchable(core: SurvivalCore) -> Array:
	var out := []
	var loc := str(core.state.context.get("location", ""))
	for npc_id in SurvivalUtil.sorted_ids(core.data.individuals):
		var m := mentor(core, str(npc_id))
		if m.is_empty():
			continue
		var w := SurvivalNpcs.where(core, str(npc_id))
		if not bool(w.present) or str(w.location) != loc:
			continue
		for aid in SurvivalUtil.arr(SurvivalUtil.dict(m.get("demonstrates")).get(str(w.activity))):
			if not core.data.action(str(aid)).is_empty():
				out.append({"performer": str(npc_id), "action": str(aid), "activity": str(w.activity)})
	return out


## The watched job's game minutes: the middle of the action's (or its first recipe's) working time.
static func watch_minutes(core: SurvivalCore, action_id: String) -> float:
	var a := core.data.action(action_id)
	var tm := SurvivalUtil.pair(a.get("time_min"), 10.0)
	var rs := SurvivalUtil.arr(a.get("recipes"))
	if not rs.is_empty() and core.data.recipe(str(rs[0])).has("time_min"):
		tm = SurvivalUtil.pair(core.data.recipe(str(rs[0])).get("time_min"), tm.x)
	return maxf(1.0, (tm.x + tm.y) / 2.0)


## The knowledge id watching an action shows: the technique, or the first of its recipes the watcher does not know yet.
static func watch_kid(core: SurvivalCore, action_id: String) -> String:
	var a := core.data.action(action_id)
	if gates_action(core, a):
		return core.data.action_knowledge_id(action_id)
	for rid in SurvivalUtil.arr(a.get("recipes")):
		var kid := core.data.recipe_knowledge_id(str(rid))
		if rank(state_of(core, kid)) < rank("seen"):
			return kid
	var rs := SurvivalUtil.arr(a.get("recipes"))
	return core.data.recipe_knowledge_id(str(rs[0])) if not rs.is_empty() else ""


## learn.watch finished: the work becomes seen, and 0.3 of what the watcher would gain doing it (the watcher's own
## chance, a repeat curve of its own, at most 1 point a day per skill; only from a performer at least 10 above).
static func finish_watch(core: SurvivalCore, npc_id: String, action_id: String) -> Dictionary:
	var wcfg := SurvivalUtil.dict(km(core).get("watch"))
	var a := core.data.action(action_id)
	var res := {"ok": true, "performer": npc_id, "action": action_id, "points": 0.0, "seen": ""}
	var kid := watch_kid(core, action_id)
	if kid != "" and not community_held(core, kid) and rank(state_of(core, kid)) < rank("seen"):
		if set_state(core, kid, "seen", "watched", npc_id):
			res.seen = kid
	var sk := str(a.get("skill", ""))
	var T := SurvivalUtil.num(SurvivalUtil.dict(mentor(core, npc_id).get("levels")).get(sk), 0.0)
	var S := SurvivalSkills.level(core, sk)
	if sk != "" and T - S >= SurvivalUtil.num(wcfg.get("performer_min_lead"), 10.0):
		var D := SurvivalUtil.num(a.get("difficulty"), 0.0)
		var rs := SurvivalUtil.arr(a.get("recipes"))
		if not rs.is_empty() and core.data.recipe(str(rs[0])).has("difficulty"):
			D = SurvivalUtil.num(core.data.recipe(str(rs[0])).get("difficulty"), D)
		var sl := SurvivalSkills._log(core)
		var wu: Dictionary = sl.watch_uses
		wu[action_id] = int(SurvivalUtil.num(wu.get(action_id), 0.0)) + 1
		var pts := SurvivalUtil.num(wcfg.get("xp_frac"), 0.3) * SurvivalSkills.expected_gain(core, a, D, SurvivalSkills.chance(core, S, D, 0.0)) \
				* SurvivalSkills.repeat_factor(core, int(wu[action_id]))
		var watched: Dictionary = sl.watched
		var room := maxf(0.0, SurvivalUtil.num(wcfg.get("daily_cap_per_skill"), 1.0) - SurvivalUtil.num(watched.get(sk), 0.0))
		var got := SurvivalSkills.add_points(core, sk, minf(pts, room))
		watched[sk] = SurvivalUtil.num(watched.get(sk), 0.0) + got
		res.points = got
	core.state.stats["watched"] = int(SurvivalUtil.num(core.state.stats.get("watched"), 0.0)) + 1
	core._on_watched(action_id, npc_id)
	return res


# ---------------------------------------------------------------- the recipe book
## The recipe book (a journal page): every live recipe and technique with its state, counts, teachers known, where it
## was seen and its origin note; unknown entries show no inputs. {entries, known, total}.
static func recipe_book(core: SurvivalCore) -> Dictionary:
	var entries := []
	var known := 0
	var ids := SurvivalUtil.sorted_ids(core.data.knowledge_ids)
	for kid in ids:
		var st := state_of(core, str(kid))
		var rec := SurvivalUtil.dict(_k(core).get(kid))
		var e := {"id": str(kid), "name": display_name(core, str(kid)), "state": st,
				"successes": int(SurvivalUtil.num(rec.get("successes"), 0.0)), "clues": int(SurvivalUtil.num(rec.get("clues"), 0.0)),
				"seen_from": SurvivalUtil.arr(rec.get("seen_from")).duplicate(), "taught_by": SurvivalUtil.arr(rec.get("taught_by")).duplicate(),
				"origin": _origin(core, str(kid)), "teachers": _teachers(core, str(kid))}
		if st != "unknown":
			var r := core.data.recipe(str(kid))
			if not r.is_empty():
				e["inputs"] = SurvivalUtil.dict(r.get("inputs")).duplicate()
		if rank(st) >= rank("known"):
			known += 1
		entries.append(e)
	return {"entries": entries, "known": known, "total": ids.size()}


static func _origin(core: SurvivalCore, kid: String) -> String:
	for src in [core.data.knowledge.get(kid, {}), core.data.recipe(kid), core.data.action(kid)]:
		if typeof(src) == TYPE_DICTIONARY and str(src.get("origin", "")) != "":
			return str(src.origin)
	return ""


static func _teachers(core: SurvivalCore, kid: String) -> Array:
	var out := []
	for npc_id in SurvivalUtil.sorted_ids(core.data.individuals):
		if not teach_entry(core, str(npc_id), kid).is_empty():
			out.append(str(npc_id))
	return out
