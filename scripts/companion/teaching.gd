class_name Teaching
extends RefCounted
## Teaching a child to survive in the wilderness (user 2026-09-28), logic only; the curriculum is data/companion/growth.json
## ("curriculum": topics with a minimum stage, prerequisites, the skill the teaching parent needs, minutes and xp). The child has a
## SurvivalCore of its own (a learning core, GrowthLink makes it) that gets the knowledge and the skill points, through the survival
## model's own pieces: SurvivalLearning.set_state (known, taught by the parent), SurvivalSkills.add_points (the daily caps apply), and for
## watching the finish_watch model (a share of what doing it would teach, the watcher's own chance, a repeat curve, a daily cap per
## skill, only from a performer well above the watcher). The teacher is a parent's own core (the NPC parent's SpouseCore.core, or the
## player's main core): the parent must have the skill level and know the technique.
##
## Two routes: LESSONS (a timed lesson the parent gives; topic 'home' is the teach job at the hearth, topic 'field' is the parent's
## real job with the child along) and WATCHING (a child near and awake while a parent works: watch_step() adds game minutes, every
## watch_min a credit: give_watch()). Both count in the child's record (lessons, watched, topics) which the growth milestones read.
##   Teaching.check(child, topic, teacher_core, child_core, now) -> {ok, reason, ...}
##   Teaching.offers(...) -> [{topic, name, ok, reason, need, minutes}]      the topic picker
##   Teaching.give(...) / Teaching.give_watch(...) / Teaching.watch_step(...)

static func curriculum() -> Dictionary:
	return Growth.cfg().get("curriculum", {})


static func topics() -> Array:
	return curriculum().get("topics", [])


static func topic(id: String) -> Dictionary:
	for t: Dictionary in topics():
		if String(t.id) == id:
			return t
	return {}


static func name_of(id: String) -> String:
	return String(topic(id).get("name", id))


## The topic a household job demonstrates ("" none): the first topic whose `job` is it.
static func by_job(job_id: String) -> String:
	if job_id == "":
		return ""
	for t: Dictionary in topics():
		if String(t.get("job", "")) == job_id:
			return String(t.id)
	return ""


## The topic a survival action (the player's own work) demonstrates.
static func by_action(action_id: String) -> String:
	for t: Dictionary in topics():
		if (t.get("actions", []) as Array).has(action_id):
			return String(t.id)
	return ""


static func learned(child: Dictionary, topic_id: String) -> bool:
	return int((child.get("topics", {}) as Dictionary).get(topic_id, 0)) > 0


static func day_of(now: float) -> int:
	return floori(now / Growth.MIN_PER_DAY)


## Keeps a child's learning core on the household's clock (its skill log's day, the lesson caps) without living its needs.
static func sync_clock(child_core: SurvivalCore, main: SurvivalCore) -> void:
	child_core.state.minutes = main.state.minutes
	child_core.state.base_year = main.state.base_year


## A learning core for a child: on the household's data and clock, no skills, no knowledge but the common (SurvivalLearning counts
## the common knowledge as known: a child of the frontier knows what everybody knows).
static func make_core(main: SurvivalCore, seed_v: int) -> SurvivalCore:
	var opts := {"data": main.data, "seed": seed_v, "preset": main.state.preset,
			"backlog_milestones": SurvivalUtil.arr(main.state.settings.get("backlog_milestones", []))}
	var core := SurvivalCore.new_game(main.state.background_id, opts)
	var st := core.state
	st.settings = main.state.settings.duplicate(true)
	st.minutes = main.state.minutes
	st.base_year = main.state.base_year
	for k in st.skills.keys():
		st.skills[k] = 0.0
	var p := core.player()
	p["knowledge"] = {}
	p["learning"] = {}
	return core


# ---------------------------------------------------------------- can it be taught
static func _refuse(reason: String, extra := {}) -> Dictionary:
	var r := {"ok": false, "reason": reason, "need": ""}
	r.merge(extra, true)
	return r


static func _daily(child: Dictionary, now: float) -> Dictionary:
	var ll: Dictionary = child.get("last_lesson", {})
	if int(ll.get("day", -1)) != day_of(now):
		return {"day": day_of(now), "count": 0, "topics": {}}
	return ll


## Can this parent teach this topic to this child now? {ok, reason ("" ok; "topic", "stage", "known", "requires", "skill", "daily"), need}.
## `need` is the plain thing missing (the topic that comes first, the skill the parent lacks). Nothing costs anything to ask.
static func check(child: Dictionary, topic_id: String, teacher: SurvivalCore, now: float) -> Dictionary:
	var t := topic(topic_id)
	if t.is_empty():
		return _refuse("topic")
	if not Growth.can(child, "lesson") or not Growth.at_least(child, String(t.get("min_stage", "child"))):
		return _refuse("stage", {"need": String(Growth.stage_row(String(t.get("min_stage", "child"))).get("name", ""))})
	if learned(child, topic_id):
		return _refuse("known")
	for req: String in t.get("requires", []):
		if not learned(child, req):
			return _refuse("requires", {"need": name_of(req).to_lower()})
	var sk := String(t.get("skill", ""))
	var have := SurvivalSkills.level(teacher, sk) if sk != "" else 0.0
	var need := float(t.get("teacher_skill", 0.0))
	var kid := String(t.get("kid", ""))
	if have < need:
		return _refuse("skill", {"need": "%s %d" % [String(teacher.data.skill(sk).get("name", sk)), ceili(need)], "have": have})
	if kid != "" and SurvivalLearning.rank(SurvivalLearning.state_of(teacher, kid)) < SurvivalLearning.rank("known"):
		return _refuse("skill", {"need": SurvivalLearning.display_name(teacher, kid)})
	var d := _daily(child, now)
	var cfg := curriculum()
	if int(d.count) >= int(cfg.get("lesson_daily_max", 2)) or int((d.topics as Dictionary).get(topic_id, 0)) >= int(cfg.get("lesson_topic_daily_max", 1)):
		return _refuse("daily")
	return {"ok": true, "reason": "", "need": ""}


## The topic picker: every topic with whether it can be taught now and why not, [{topic, name, skill, ok, reason, need, minutes, learned,
## text}]. `text` says in a line what is wanted ("Survival 10 needed", "learn foraging first", ...).
static func offers(child: Dictionary, teacher: SurvivalCore, now: float) -> Array:
	var out := []
	for t: Dictionary in topics():
		var c := check(child, String(t.id), teacher, now)
		var text := ""
		match String(c.reason):
			"skill":
				text = "%s needs %s" % [teacher_word(), String(c.need)]
			"requires":
				text = "learn %s first" % String(c.need)
			"stage":
				text = "old enough at %s" % String(c.need).to_lower()
			"known":
				text = "learnt"
			"daily":
				text = "enough for today"
		out.append({"topic": String(t.id), "name": String(t.name), "skill": String(t.get("skill", "")), "ok": bool(c.ok),
				"reason": String(c.reason), "need": String(c.get("need", "")), "minutes": float(t.get("minutes", 30.0)),
				"learned": learned(child, String(t.id)), "text": text, "where": String(t.get("where", "home")), "core": bool(t.get("core", false))})
	return out


static func teacher_word() -> String:
	return "the teacher"


## The next topic a parent should teach: the first in the curriculum order that can be taught now ("" none). `where` limits it to
## 'home' or 'field' topics ("" either).
static func due(child: Dictionary, teacher: SurvivalCore, now: float, where := "") -> String:
	for o: Dictionary in offers(child, teacher, now):
		if bool(o.ok) and (where == "" or String(o.where) == where):
			return String(o.topic)
	return ""


static func minutes(topic_id: String) -> float:
	return float(topic(topic_id).get("minutes", 30.0))


# ---------------------------------------------------------------- lessons
## The lesson is given: the child's core learns the technique (known, taught by `teacher_name`) and gets the skill points (xp x the
## stage's lesson_mult, under the daily caps), the record counts it. {ok, reason, topic, points, kid}. Checks again first.
static func give(child: Dictionary, topic_id: String, teacher: SurvivalCore, teacher_name: String, learner: SurvivalCore, now: float) -> Dictionary:
	var c := check(child, topic_id, teacher, now)
	if not bool(c.ok):
		return c
	var t := topic(topic_id)
	var kid := String(t.get("kid", ""))
	var sk := String(t.get("skill", ""))
	var pts := 0.0
	if learner != null:
		if kid != "":
			SurvivalLearning.set_state(learner, kid, "known", "taught", teacher_name, true)
		if sk != "":
			pts = SurvivalSkills.add_points(learner, sk, float(t.get("xp", 1.0)) * Growth.num(child, "lesson_mult", 1.0))
	var topics_d: Dictionary = child.get("topics", {})
	child["topics"] = topics_d
	topics_d[topic_id] = int(topics_d.get(topic_id, 0)) + 1
	child["lessons"] = int(child.get("lessons", 0)) + 1
	var d := _daily(child, now)
	d["count"] = int(d.count) + 1
	(d.topics as Dictionary)[topic_id] = int((d.topics as Dictionary).get(topic_id, 0)) + 1
	child["last_lesson"] = d
	return {"ok": true, "reason": "", "topic": topic_id, "points": pts, "kid": kid, "skill": sk}


# ---------------------------------------------------------------- watching
## Time passes (dm game minutes) with the child at a parent's work on `topic_id`: counts only while it is near and awake (and old enough
## to watch). Returns the watch credits earned by it (each `watch_min` of the topic).
static func watch_step(child: Dictionary, topic_id: String, dm: float, near: bool, awake: bool) -> int:
	if not near or not awake or dm <= 0.0 or not Growth.can(child, "watch"):
		return 0
	var t := topic(topic_id)
	if t.is_empty():
		return 0
	var w: Dictionary = child.get("watch", {})
	child["watch"] = w
	var need := maxf(float(t.get("watch_min", curriculum().get("watch", {}).get("credit_every_min", 30.0))), 1.0)
	w[topic_id] = float(w.get(topic_id, 0.0)) + dm
	var credits := 0
	while float(w[topic_id]) >= need:
		w[topic_id] = float(w[topic_id]) - need
		credits += 1
	return credits


## One watch credit is given: the work becomes seen for the child's core, and it gets a share of what doing it would teach (the model of
## SurvivalLearning.finish_watch, the parent's own level as the performer's), times the stage's watch_mult, at most daily_cap_per_skill
## a skill a day and only when the parent is `performer_min_lead` above the child. {ok, points, seen, reason}.
static func give_watch(child: Dictionary, topic_id: String, teacher: SurvivalCore, teacher_name: String, learner: SurvivalCore) -> Dictionary:
	var t := topic(topic_id)
	if t.is_empty() or not Growth.can(child, "watch"):
		return {"ok": false, "reason": "stage", "points": 0.0}
	var wcfg: Dictionary = curriculum().get("watch", {})
	var res := {"ok": true, "reason": "", "topic": topic_id, "points": 0.0, "seen": ""}
	child["watched"] = int(child.get("watched", 0)) + 1
	if learner == null:
		return res
	var kid := String(t.get("kid", ""))
	if kid != "" and not SurvivalLearning.community_held(learner, kid) \
			and SurvivalLearning.rank(SurvivalLearning.state_of(learner, kid)) < SurvivalLearning.rank("seen"):
		if SurvivalLearning.set_state(learner, kid, "seen", "watched", teacher_name, true):
			res.seen = kid
	var sk := String(t.get("skill", ""))
	if sk == "":
		return res
	var lead := SurvivalSkills.level(teacher, sk) - SurvivalSkills.level(learner, sk)
	if lead < float(wcfg.get("performer_min_lead", 10.0)):
		return res
	var a: Dictionary = {}
	for aid: String in t.get("actions", []):
		if not learner.data.action(aid).is_empty():
			a = learner.data.action(aid)
			break
	var base := 0.0
	if not a.is_empty():
		var S := SurvivalSkills.level(learner, sk)
		var D := SurvivalUtil.num(a.get("difficulty"), 0.0)
		var sl := SurvivalSkills._log(learner)
		var wu: Dictionary = sl.watch_uses
		var aid_s := String(a.get("id", ""))
		wu[aid_s] = int(SurvivalUtil.num(wu.get(aid_s), 0.0)) + 1
		base = SurvivalSkills.expected_gain(learner, a, D, SurvivalSkills.chance(learner, S, D, 0.0)) * SurvivalSkills.repeat_factor(learner, int(wu[aid_s]))
	else:
		base = 0.3   # a topic with no single action (hunting basics): a small fixed share
	var pts := float(wcfg.get("xp_frac", 0.3)) * base * Growth.num(child, "watch_mult", 1.0)
	var sl2 := SurvivalSkills._log(learner)
	var watched: Dictionary = sl2.watched
	var room := maxf(0.0, float(wcfg.get("daily_cap_per_skill", 1.0)) - SurvivalUtil.num(watched.get(sk), 0.0))
	var got := SurvivalSkills.add_points(learner, sk, minf(pts, room))
	watched[sk] = SurvivalUtil.num(watched.get(sk), 0.0) + got
	res.points = got
	return res


# ---------------------------------------------------------------- helping
## How much faster a parent's job goes with this child helping (a share, 0 for a toddler): the stage's helper_bonus.
static func helper_bonus(child: Dictionary) -> float:
	return Growth.num(child, "helper_bonus", 0.0)
