extends SceneTree
## Growing up (Growth, Teaching, Father, GrowthLink's rules), headless, no level: milestone gating (days AND care AND lessons AND
## watching), the record saved and loaded (an old save without stages), the curriculum's prerequisites and the parent's skill, a lesson
## moving skill points and knowledge on the child's own core, the teach job planned and run by a worker, watching (near and awake only),
## a teen taken on as a junior worker and the adult keeping everything, the NPC father's schedule, and a whole childhood through the
## household node with a fake bridge.
##   Godot --headless --path . -s tests/companion/test_growth.gd
var fails := 0
var main: SurvivalCore
var male := AppearanceStore.default_look()


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _main(seed_v := 7) -> SurvivalCore:
	return SurvivalCore.new_game("bg.backcountry_hunter", {"seed": seed_v, "start_day": "sep_early", "start_hour": 8.0,
			"backlog_milestones": ["M2a", "M2b", "M3"], "settings": {"rest_need": false}})


func _initialize() -> void:
	Sharpness.slips_on = false   # (exact planning and paths: no tired slips here; tests/companion/test_sharpness.gd has them)
	InputSetup.ensure()
	Growth.set_cfg({})
	main = _main()
	_data()
	_milestones()
	_care()
	_saving()
	_curriculum()
	_teaching()
	_watching()
	_job()
	_worker()
	_father()
	_looks()
	await _lifecycle()
	print("GROWTH TEST %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit(1 if fails else 0)


func _child(stage := "newborn", now := 0.0, over := {}) -> Dictionary:
	var c := {"id": "child.1", "name": "Ada", "sex": 0.0, "born_at": 0.0, "mother": "Hannah", "father": "player", "kind": "spouse", "seed": 77,
			"vigor": 1.0, "worker_id": -1, "stage": stage, "stage_at": now}
	c.merge(over, true)
	return Growth.normalize(c, now)


# ---------------------------------------------------------------- the data
func _data() -> void:
	var st := Growth.stages()
	var ids := []
	for r: Dictionary in st:
		ids.append(String(r.id))
	_expect(ids == ["newborn", "infant", "toddler", "child", "teen", "adult"], "the stages run newborn, infant, toddler, child, teen, adult (%s)" % str(ids))
	_expect(Growth.next_id("newborn") == "infant" and Growth.next_id("teen") == "adult" and Growth.next_id("adult") == "", "each has its next; adult has none")
	var scales := []
	for id in ["toddler", "child", "teen", "adult"]:
		scales.append(Growth.stage_row(id).scale)
	_expect(scales == [0.5, 0.7, 0.93, 1.0], "body scales grow with the stage (%s)" % str(scales))
	_expect(float(Growth.stage_row("toddler").head) > float(Growth.stage_row("child").head) and float(Growth.stage_row("child").head) > 1.0, "the head is bigger on the young")
	_expect(Growth.carried({"stage": "newborn"}) and Growth.carried({"stage": "infant"}) and not Growth.carried({"stage": "toddler"}), "newborn and infant are carried, a toddler walks")
	_expect(not Growth.has_body({"stage": "infant"}) and Growth.has_body({"stage": "toddler"}), "bodies from the toddler on")
	_expect(not Growth.can({"stage": "toddler"}, "work") and not Growth.can({"stage": "child"}, "work") and Growth.can({"stage": "teen"}, "work"), "only a teen works")
	_expect(Growth.can({"stage": "toddler"}, "watch") and not Growth.can({"stage": "toddler"}, "lesson") and Growth.can({"stage": "child"}, "lesson"), "a toddler watches, a child takes lessons")
	# the curriculum is sound: real actions, jobs, prerequisites, the core list
	var ids_t := {}
	for t: Dictionary in Teaching.topics():
		ids_t[String(t.id)] = true
	var sound := true
	for t: Dictionary in Teaching.topics():
		for r: String in t.requires:
			sound = sound and ids_t.has(r)
		for a: String in t.actions:
			sound = sound and not main.data.action(a).is_empty()
		if String(t.kid) != "":
			sound = sound and not main.data.action(String(t.kid)).is_empty()
		if String(t.job) != "":
			sound = sound and JobBook.has(String(t.job))
		if String(t.where) == "field":
			sound = sound and String(t.job) != ""
		sound = sound and main.data.skills.has(String(t.skill)) and Growth.stage_index(String(t.min_stage)) >= 0
	_expect(sound, "every topic names real actions, skills, jobs and prerequisites (%d topics)" % Teaching.topics().size())
	var cp := Growth.core_progress({"topics": {}})
	_expect(cp.y >= 4, "there is a core curriculum (%d topics)" % cp.y)
	_expect(JobBook.has("teach") and JobBook.role_of("teach") == "home" and String(JobBook.job("teach").offer) == "lesson", "the teach job is in the book")


# ---------------------------------------------------------------- milestones
func _milestones() -> void:
	var now := 0.0
	var c := _child("newborn", now)
	var p := Growth.progress(c, now)
	_expect(not bool(p.ready) and p.missing.has("min_days") and String(p.next) == "infant" and String(p.hint) != "", "a newborn is not ready on day 0: %s" % p.hint)
	now = 9.0 * 1440.0
	_expect(bool(Growth.progress(c, now).ready), "days alone can do it where care is not asked (newborn, 9 days)")
	_expect(Growth.advance(c, now).to == "infant" and Growth.stage_of(c) == "infant" and is_equal_approx(float(c.stage_at), now), "advance moves it to infant and marks the day")
	# infant: days AND care
	var ic := _child("infant", 0.0)
	ic["care_sum"] = 3.0
	ic["care_n"] = 10   # 0.3 care
	now = 23.0 * 1440.0
	var pi := Growth.progress(ic, now)
	_expect(not bool(pi.ready) and pi.missing == ["care"], "an infant with the days but poor care (30%%) waits: %s" % pi.hint)
	_expect(Growth.advance(ic, now).is_empty() and Growth.stage_of(ic) == "infant", "no advance without the care")
	ic["care_sum"] = 8.0
	_expect(bool(Growth.progress(ic, now).ready), "care 80% and 23 days: ready")
	_expect(Growth.progress(ic, 10.0 * 1440.0).missing == ["min_days"], "care without the days: not ready either")
	Growth.advance(ic, now)
	_expect(Growth.stage_of(ic) == "toddler" and int(ic.care_n) == 0, "toddler; the care samples start over")
	# toddler: watching
	var tc := _child("toddler", 0.0, {"care_sum": 9.0, "care_n": 10})
	now = 41.0 * 1440.0
	_expect(Growth.progress(tc, now).missing == ["watched"], "a toddler needs to have watched a parent work (%s)" % Growth.progress(tc, now).missing)
	tc["watched"] = 2
	_expect(bool(Growth.progress(tc, now).ready), "with two watch credits it grows")
	# child: lessons and topics
	var cc := _child("child", 0.0, {"care_sum": 9.0, "care_n": 10})
	now = 91.0 * 1440.0
	_expect("lessons" in Growth.progress(cc, now).missing and "topics" in Growth.progress(cc, now).missing, "a child needs lessons and things learnt")
	cc["lessons"] = 4
	cc["topics"] = {"fire": 1, "foraging": 1, "cooking": 1}
	_expect(bool(Growth.progress(cc, now).ready), "4 lessons, 3 topics, days, care: a teen")
	cc["lessons"] = 3
	_expect(not bool(Growth.progress(cc, now).ready), "one lesson short: not yet")
	# teen: the core curriculum
	var ec := _child("teen", 0.0, {"care_sum": 9.0, "care_n": 10, "lessons": 12, "topics": {"fire": 1, "foraging": 1, "cooking": 1, "trapping": 1, "hunting": 1, "tracking": 1}})
	now = 131.0 * 1440.0
	_expect("core" in Growth.progress(ec, now).missing, "six topics but not the core ones: a teen is not an adult (%s)" % Growth.progress(ec, now).hint)
	for t: Dictionary in Teaching.topics():
		if bool(t.core):
			ec.topics[String(t.id)] = 1
	_expect(bool(Growth.progress(ec, now).ready) and String(Growth.progress(ec, now).next) == "adult", "with the core done and the days: adult")
	Growth.advance(ec, now)
	_expect(Growth.stage_of(ec) == "adult" and Growth.progress(ec, now).hint == "Grown up." and Growth.stage_line(ec, "adult").contains("Ada"), "adult: the announcement line names her (%s)" % Growth.stage_line(ec, "adult"))
	_expect(Growth.stage_line(ec, "adult") != "" and Growth.stage_line({"name": "Bo"}, "toddler").contains("Bo"), "every stage has a line")


func _care() -> void:
	var c := _child("child", 0.0)
	Growth.note_care(c, 3.0 * 60.0, {"fed": true, "attended": true})
	_expect(int(c.care_n) == 3 and is_equal_approx(Growth.care_avg(c), 1.0), "one sample an hour: 3 hours, 3 samples at 100%")
	Growth.note_care(c, 4.0 * 60.0, {"fed": false, "attended": true})
	_expect(int(c.care_n) == 4 and is_equal_approx(Growth.care_avg(c), (3.0 + 0.4) / 4.0), "hungry: 0.4 (attended only): average %.2f" % Growth.care_avg(c))
	Growth.note_care(c, 5.0 * 60.0, {"content": 0.2})
	_expect(is_equal_approx(float(c.care_sum), 3.4 + 0.2), "a baby's sample is its contentment")
	var n0 := int(c.care_n)
	Growth.note_care(c, 5.0 * 60.0 + 30.0, {"fed": true})
	_expect(int(c.care_n) == n0, "no sample before the hour is up")
	var big := _child("child", 0.0)
	Growth.note_care(big, 400.0 * 60.0, {"fed": true, "attended": true})
	_expect(int(big.care_n) <= 48, "a long gap catches up at most %d samples (%d)" % [48, big.care_n])
	_expect(is_equal_approx(Growth.care_avg(_child("child", 0.0)), 0.6), "no samples: the prior")
	# meals: due after the hours, from a store, and hungry past the grace
	var m := _child("toddler", 0.0)
	_expect(not Growth.meal_due(m, 60.0) and Growth.meal_due(m, 8.0 * 60.0), "a meal is due after seven hours")
	var store := {"jerky": 2}
	var got := Growth.feed(m, 8.0 * 60.0, func(kinds: Array) -> String:
		for k: String in kinds:
			if int(store.get(k, 0)) > 0:
				store[k] -= 1
				return k
		return "")
	_expect(got == "jerky" and float(m.fed_at) == 8.0 * 60.0 and Growth.fed(m, 9.0 * 60.0), "it eats from the store and is fed")
	_expect(not Growth.fed(m, 8.0 * 60.0 + 7.0 * 60.0 * 1.7), "past the grace it has gone hungry")
	_expect(Growth.feed(m, 1.0, func(_k: Array) -> String: return "") == "" and float(m.fed_at) == 8.0 * 60.0, "an empty store feeds nobody")


# ---------------------------------------------------------------- saving
func _saving() -> void:
	var now := 100.0 * 1440.0
	var c := _child("child", now - 5.0 * 1440.0, {"born_at": 0.0})
	c["care_sum"] = 4.5
	c["care_n"] = 6
	c["lessons"] = 3
	c["topics"] = {"fire": 2}
	c["look"] = {"sex": 0.0}
	var json := JSON.stringify([c])
	var back := Pregnancy.family_from(JSON.parse_string(json))
	Growth.normalize_all(back, now)
	var b: Dictionary = back[0]
	_expect(Growth.stage_of(b) == "child" and int(b.lessons) == 3 and int((b.topics as Dictionary).fire) == 2 and float(b.care_sum) == 4.5, "stage, care and lessons survive a JSON round trip")
	_expect(is_equal_approx(float(b.stage_at), now - 5.0 * 1440.0), "and the day the stage began")
	# an old save: a record from before growth, placed by its age once
	var old := {"id": "child.2", "name": "Old", "sex": 1.0, "born_at": now - 40.0 * 1440.0, "mother": "H", "father": "player", "kind": "spouse", "seed": 5, "vigor": 1.0, "worker_id": -1}
	var fam := Pregnancy.family_from([old])
	Growth.normalize_all(fam, now)
	var o: Dictionary = fam[0]
	_expect(Growth.stage_of(o) == "toddler" and float(o.stage_at) <= now and o.has("topics") and int(o.lessons) == 0 and String(o.mode) == "follow", "an old record 40 days old is placed as a toddler (%s)" % Growth.stage_of(o))
	var young := Growth.normalize({"id": "x", "name": "Y", "sex": 0.0, "born_at": now - 2.0 * 1440.0}, now)
	_expect(Growth.stage_of(young) == "newborn", "a two-day-old old record is a newborn")
	var ancient := Growth.normalize({"id": "z", "name": "Z", "sex": 0.0, "born_at": now - 900.0 * 1440.0}, now)
	_expect(Growth.stage_of(ancient) == "teen" and not bool(Growth.progress(ancient, now).ready), "an old record is never placed as an adult: it has to earn it")
	Growth.normalize(o, now)
	var st_at := float(o.stage_at)
	Growth.normalize(o, now + 999.0)
	_expect(float(o.stage_at) == st_at, "normalizing again changes nothing")
	# BabyCare reads the growth stage for who is carried
	_expect(BabyCare.carried({"stage": "infant", "born_at": 0.0}, 9999.0 * 1440.0) and not BabyCare.carried({"stage": "toddler", "born_at": 0.0}, 0.0), "BabyLink's carried test follows the stage, not the age")
	_expect(BabyCare.carried({"born_at": 0.0}, 5.0 * 1440.0) and not BabyCare.carried({"born_at": 0.0}, 200.0 * 1440.0), "a record without a stage still goes by age")


# ---------------------------------------------------------------- the curriculum
func _teacher(over := {}) -> SurvivalCore:
	var t := _main(11)
	for k: String in over:
		t.state.skills[k] = float(over[k])
	return t


func _curriculum() -> void:
	var now := main.state.minutes
	var kid := _child("child", now)
	var t := _teacher()
	_expect(bool(Teaching.check(kid, "fire", t, now).ok), "a parent with survival 32 can teach a child fire")
	_expect(Teaching.check(_child("toddler", now), "fire", t, now).reason == "stage", "a toddler cannot take a lesson")
	var weak := _teacher({"survival": 3.0})
	var r := Teaching.check(kid, "fire", weak, now)
	_expect(r.reason == "skill" and String(r.need).contains("10"), "a parent who lacks the skill cannot (needs %s)" % r.need)
	var no_tech := _teacher()
	no_tech.player()["knowledge"] = {"wood.split_firewood": {"state": "heard_of", "successes": 0, "excellent_good": 0, "clues": 0, "seen_from": [], "taught_by": [], "how": ""}}
	_expect(Teaching.check(kid, "firewood", no_tech, now).reason == "skill", "a parent who has only heard of the technique cannot teach it")
	_expect(Teaching.check(kid, "trapping", t, now).reason == "stage", "trapping waits for a teen")
	var teen := _child("teen", now)
	_expect(Teaching.check(teen, "trapping", t, now).reason == "requires" and String(Teaching.check(teen, "trapping", t, now).need).contains("forag"), "trapping needs foraging first")
	teen.topics["foraging"] = 1
	_expect(bool(Teaching.check(teen, "trapping", t, now).ok), "after foraging, trapping can be taught")
	_expect(Teaching.check(teen, "tracking", t, now).reason == "requires", "tracking needs trapping")
	_expect(Teaching.check(teen, "hunting", t, now).reason == "requires", "hunting basics needs tracking")
	var weak2 := _teacher({"trapping": 10.0})
	_expect(Teaching.check(teen, "trapping", weak2, now).reason == "skill", "the topic's own skill: trapping 15 needed")
	var offers := Teaching.offers(kid, t, now)
	var by := {}
	for o: Dictionary in offers:
		by[String(o.topic)] = o
	_expect(bool(by.fire.ok) and not bool(by.trapping.ok) and String(by.trapping.text) != "" and offers.size() == Teaching.topics().size(), "the picker lists every topic with why not (%s)" % String(by.trapping.text))
	_expect(Teaching.due(kid, t, now) == "fire" and Teaching.due(kid, t, now, "field") == "foraging", "the next due topic is the first that fits (fire; field: foraging)")


# ---------------------------------------------------------------- lessons
func _teaching() -> void:
	var now := main.state.minutes
	var kid := _child("child", now)
	var t := _teacher()
	var lc := Teaching.make_core(main, 9)
	_expect(SurvivalSkills.level(lc, "survival") == 0.0 and lc.state.minutes == main.state.minutes, "a child's own core: no skills, on the household's clock")
	var before := SurvivalSkills.level(lc, "survival")
	var r := Teaching.give(kid, "fire", t, "Hannah", lc, now)
	_expect(bool(r.ok) and float(r.points) > 0.0, "the lesson gives skill points (%.2f)" % float(r.points))
	_expect(SurvivalSkills.level(lc, "survival") > before, "the child's core skill rose (%.2f)" % SurvivalSkills.level(lc, "survival"))
	_expect(SurvivalLearning.rank(SurvivalLearning.state_of(lc, "fire.strike_flint_steel")) >= SurvivalLearning.rank("known"), "and it knows the technique")
	_expect(SurvivalUtil.arr(SurvivalLearning.record(lc, "fire.strike_flint_steel").get("taught_by")).has("Hannah"), "taught by Hannah")
	_expect(int(kid.lessons) == 1 and Teaching.learned(kid, "fire") and int(kid.topics.fire) == 1, "the record counts the lesson and the topic")
	_expect(Teaching.check(kid, "fire", t, now).reason == "known", "the same lesson twice is refused")
	# more than the child's daily maximum
	var r2 := Teaching.give(kid, "foraging", t, "Hannah", lc, now)
	var r3 := Teaching.give(kid, "firewood", t, "Hannah", lc, now)
	_expect(bool(r2.ok) and not bool(r3.ok) and r3.reason == "daily", "two lessons a day, the third waits (%s)" % r3.reason)
	Teaching.sync_clock(lc, main)
	var tomorrow := now + 1440.0
	lc.state.minutes = tomorrow
	_expect(bool(Teaching.give(kid, "firewood", t, "Hannah", lc, tomorrow).ok), "the next day it may learn more")
	# the stage's lesson multiplier: a teen learns faster than a child
	var lc2 := Teaching.make_core(main, 10)
	var lc3 := Teaching.make_core(main, 10)
	var pc: float = Teaching.give(_child("child", now), "fire", t, "H", lc2, now).points
	var pt: float = Teaching.give(_child("teen", now), "fire", t, "H", lc3, now).points
	_expect(pt > pc, "a teen learns faster than a child (%.2f > %.2f)" % [pt, pc])
	# a parent's lesson to a teen with a skill lesson (hunting basics has no single action)
	var teen := _child("teen", now, {"topics": {"foraging": 1, "trapping": 1, "tracking": 1}})
	var lc4 := Teaching.make_core(main, 12)
	var rh := Teaching.give(teen, "hunting", t, "H", lc4, now)
	_expect(bool(rh.ok) and SurvivalSkills.level(lc4, "hunting") > 0.0, "hunting basics raises the hunting skill")
	# save the child's core and load it: it keeps what it learned
	var st := lc.state.to_dict()
	var back := SurvivalCore.from_state(SurvivalState.from_dict(st), {"data": main.data})
	_expect(is_equal_approx(SurvivalSkills.level(back, "survival"), SurvivalSkills.level(lc, "survival")), "the child's core survives a save")


func _watching() -> void:
	var now := main.state.minutes
	var kid := _child("toddler", now)
	# not near, or asleep: nothing
	_expect(Teaching.watch_step(kid, "fire", 60.0, false, true) == 0 and float(kid.watch.get("fire", 0.0)) == 0.0, "not near: nothing counts")
	_expect(Teaching.watch_step(kid, "fire", 60.0, true, false) == 0 and float(kid.watch.get("fire", 0.0)) == 0.0, "asleep: nothing counts")
	_expect(Teaching.watch_step(_child("infant", now), "fire", 60.0, true, true) == 0, "a baby does not watch")
	_expect(Teaching.watch_step(kid, "fire", 10.0, true, true) == 0 and is_equal_approx(float(kid.watch.fire), 10.0), "near and awake: the minutes add up (10 of 25)")
	_expect(Teaching.watch_step(kid, "fire", 20.0, true, true) == 1 and is_equal_approx(float(kid.watch.fire), 5.0), "past 25 minutes: a credit, the rest kept")
	var t := _teacher()
	var lc := Teaching.make_core(main, 14)
	var r := Teaching.give_watch(kid, "fire", t, "Hannah", lc)
	_expect(bool(r.ok) and int(kid.watched) == 1, "the credit counts as a watch")
	_expect(float(r.points) > 0.0 and SurvivalSkills.level(lc, "survival") > 0.0, "and gives skill points (%.3f)" % float(r.points))
	_expect(SurvivalLearning.rank(SurvivalLearning.state_of(lc, "fire.strike_flint_steel")) >= SurvivalLearning.rank("seen"), "the work is at least seen")
	# a daily cap of one point a skill from watching
	var total := float(r.points)
	for i in 30:
		total += float(Teaching.give_watch(kid, "fire", t, "Hannah", lc).points)
	_expect(total <= 1.0001, "watching gives at most one point a skill a day (%.2f)" % total)
	# the performer must be well above the watcher
	var peer := _teacher({"survival": 12.0})
	var lc2 := Teaching.make_core(main, 15)
	lc2.state.skills["survival"] = 10.0
	_expect(float(Teaching.give_watch(_child("toddler", now), "fire", peer, "H", lc2).points) == 0.0, "a parent barely ahead teaches nothing by being watched")
	# the stage multiplier: a child gets more from watching than a toddler
	var lca := Teaching.make_core(main, 16)
	var lcb := Teaching.make_core(main, 16)
	var pa: float = Teaching.give_watch(_child("toddler", now), "cooking", t, "H", lca).points
	var pb: float = Teaching.give_watch(_child("child", now), "cooking", t, "H", lcb).points
	_expect(pb > pa and pa > 0.0, "a child learns more from watching than a toddler (%.3f > %.3f)" % [pb, pa])
	_expect(Teaching.by_job("cook") == "cooking" and Teaching.by_job("forage") == "foraging" and Teaching.by_action("fire.nurse") == "fire" and Teaching.by_job("stretch") == "", "jobs and actions map to their topics")
	_expect(Teaching.helper_bonus(_child("toddler", now)) == 0.0 and Teaching.helper_bonus(_child("child", now)) > 0.0 \
			and Teaching.helper_bonus(_child("teen", now)) > Teaching.helper_bonus(_child("child", now)), "a child helps a little, a teen more, a toddler not at all")


# ---------------------------------------------------------------- the teach job
func _skip_to_hour(m: SurvivalCore, w: SpouseCore, hr: float) -> void:
	var cur := fposmod(m.state.minutes, 1440.0) / 60.0
	m.advance(fposmod(hr - cur, 24.0) * 60.0)
	w.sync(m)


func _job() -> void:
	var m := _main(21)
	var w := SpouseCore.create(m, male, 5)
	w.role = "home"
	_skip_to_hour(m, w, 10.0)
	var kid := _child("child", m.state.minutes)
	var lc := Teaching.make_core(m, 3)
	var told := []
	# no source: the job has nothing to offer
	_expect(w.offer("teach").is_empty() and w.plan().get("task", "") != "teach", "with nobody to teach the job is not planned")
	w.lesson_source = func(worker: SpouseCore) -> Dictionary:
		var topic := Teaching.due(kid, worker.core, worker.core.state.minutes, "home")
		if topic == "":
			return {}
		return {"child": String(kid.id), "topic": topic, "minutes": Teaching.minutes(topic), "text": "Teaching %s %s" % [kid.name, Teaching.name_of(topic).to_lower()]}
	w.lesson_done = func(worker: SpouseCore, d: Dictionary) -> String:
		var r := Teaching.give(kid, String(d.topic), worker.core, worker.name, lc, worker.core.state.minutes)
		told.append(String(d.topic))
		return "%s taught %s" % [worker.name, d.topic] if bool(r.ok) else "no"
	var o := w.offer("teach")
	_expect(not o.is_empty() and float(o.minutes) == Teaching.minutes(String(o.lesson.topic)) and String(o.text).begins_with("Teaching"), "a child due a lesson makes the job offer (%s, %d min)" % [o.get("text", ""), o.get("minutes", 0)])
	var p := w.plan()
	_expect(p.get("task", "") == "teach" and p.get("site", "") == "home", "she plans the lesson, at the hearth: %s" % str(p))
	_expect(w.begin("teach") and w.busy() and w.task_text.begins_with("Teaching") and w.minutes_left > 0.0, "the lesson begins and takes her time")
	for i in 80:
		m.advance(10.0)
		w.sync(m)
		if not w.busy():
			break
	_expect(not w.busy() and told.size() == 1 and int(kid.lessons) == 1, "when it is over the child has had its lesson (%s)" % str(told))
	_expect(SurvivalSkills.level(lc, "survival") > 0.0 and String(w.journal.back()).contains("taught"), "and she says so (%s)" % w.journal.back())
	# a worker off in her own work keeps the job out of the way of urgent things? the focus goes first
	var w2 := SpouseCore.create(m, male, 6)
	w2.lesson_source = w.lesson_source
	w2.lesson_done = w.lesson_done
	w2.role = "home"
	w2.focus = "teach"
	_skip_to_hour(m, w2, 11.0)
	Growth.normalize(kid, m.state.minutes)
	var p2 := w2.plan()
	_expect(p2.get("task", "") == "teach", "asked to teach, she teaches first (%s)" % str(p2))
	w2.cancel("test")
	# a job the household does not need does not steal the day: cooking wins over routine teaching when the store is short
	var w3 := SpouseCore.create(m, male, 7)
	w3.lesson_source = w.lesson_source
	w3.role = "home"
	w3.stock.put("venison", 6)
	_skip_to_hour(m, w3, 12.0)
	var p3 := w3.plan()
	_expect(p3.get("task", "") in ["cook", "teach"], "with food to cook and a lesson due she does one of them (%s)" % p3.get("task", ""))
	# the job is in the household's chain view and can be switched off
	var crew := HouseholdCrew.new()
	_expect(crew.chain_view().any(func(c: Dictionary) -> bool: return (c.links as Array).any(func(l: Dictionary) -> bool: return String(l.job) == "teach")), "the teach job shows in the chain view")
	crew.set_enabled(w, "teach", false)
	_expect(not bool(w.enabled.teach) and w.offer("teach").size() >= 0, "a worker's teaching can be switched off")


# ---------------------------------------------------------------- the worker
func _worker() -> void:
	var m := _main(31)
	var t := _teacher()
	var now := m.state.minutes
	var kid := _child("teen", now, {"born_at": 0.0, "vigor": 1.1, "look": {"sex": 0.0, "people": "english"}})
	var lc := Teaching.make_core(m, 5)
	_expect(not Growth.worker_ready(kid), "a teen who has not done the core curriculum is not ready to work")
	var day := 0
	for topic: Dictionary in Teaching.topics():
		if not bool(topic.core):
			continue
		var when := now + float(day) * 1440.0
		lc.state.minutes = when
		Teaching.give(kid, String(topic.id), t, "Hannah", lc, when)
		day += 1
		if day % 2 == 0:
			pass
	_expect(Growth.worker_ready(kid), "with the core lessons taught the teen is ready to be taken on")
	var w := Growth.make_worker(m, kid, lc)
	_expect(w.name == "Ada" and w.is_male() == false and String(w.look.get("people", "")) == "english", "the worker has the child's name and look (her sex stays hers)")
	_expect(not w.body_look.is_empty() and float(w.body_look.bust) == -1.0 and float(w.body_look.genital) == 0.0, "a new teen worker is drawn with the flat child body")
	_expect(SpouseCore.from_dict(w.to_dict(), m).body_look == w.body_look, "and the drawn look is saved with her")
	var learnt := SurvivalSkills.level(lc, "survival")
	_expect(is_equal_approx(SurvivalSkills.level(w.core, "survival"), maxf(learnt, 4.0 * 1.1)), "her skills are what the child learned (survival %.1f)" % SurvivalSkills.level(w.core, "survival"))
	_expect(SurvivalSkills.level(w.core, "archery") >= 4.4 - 0.001 and SurvivalSkills.level(w.core, "hunting") < SurvivalSkills.level(m, "hunting"), "a floor of baseline x vigor, not the parent's skills")
	_expect(SurvivalLearning.rank(SurvivalLearning.state_of(w.core, "fire.strike_flint_steel")) >= SurvivalLearning.rank("known") \
			and SurvivalUtil.arr(SurvivalLearning.record(w.core, "fire.strike_flint_steel").get("taught_by")).has("Hannah"), "and the knowledge, with who taught it")
	_expect(w.core != m and w.core.state != m.state, "she has a core of her own")
	# the junior rules
	var jobs := Growth.allowed_jobs(kid)
	_expect(jobs.has("cook") and jobs.has("forage") and not jobs.has("butcher") and not jobs.has("teach"), "a teen may take the light jobs (%s)" % str(jobs))
	var store := HouseholdStock.new()
	w.join(store)
	store.crew.set_jobs(w, jobs)
	_expect(bool(w.enabled.cook) and not bool(w.enabled.butcher), "the job book toggles are set for her")
	w.core.state.skills["survival"] = 80.0
	_expect(Growth.enforce_cap(w, kid) >= 1 and SurvivalSkills.level(w.core, "survival") == 35.0, "a junior's skills are held at the cap (35)")
	kid["stage"] = "adult"
	_expect(Growth.allowed_jobs(kid).size() == JobBook.ids().size() and Growth.skill_cap(kid) == 100.0, "an adult may do every job, no cap")
	w.core.state.skills["survival"] = 80.0
	_expect(Growth.enforce_cap(w, kid) == 0 and SurvivalSkills.level(w.core, "survival") == 80.0, "the cap comes off at adulthood: everything is kept")
	# a child that never had a core still becomes a worker
	var w2 := Growth.make_worker(m, _child("teen", now, {"seed": 3}), null)
	_expect(w2 != null and w2.name != "", "even a child with no learning core makes a worker")


# ---------------------------------------------------------------- the father
func _father() -> void:
	var kids := [{"id": "a", "stage": "child", "due": true, "with": "mother", "mode": "follow"}, {"id": "b", "stage": "toddler", "due": false, "with": "mother", "mode": "follow"},
			{"id": "c", "stage": "infant", "due": false, "with": "mother", "mode": "follow"}]
	var d := Father.decide({"hour": 7.5, "children": kids})
	_expect(d.act == "teach" and d.role == "teacher" and d.teach == "a" and d.sc_role == "home", "mornings he teaches the child who is due (%s)" % d.act)
	var none := kids.duplicate(true)
	none[0].due = false
	d = Father.decide({"hour": 7.5, "children": none})
	_expect(d.act == "work" and d.role == "provider" and d.sc_role == "outside", "no child due: he goes to work")
	d = Father.decide({"hour": 12.0, "children": kids})
	_expect(d.act == "work" and d.sc_role == "outside" and d.take.has("a") and d.take.has("b") and not d.take.has("c"), "days he works and takes the children who walk along, not the baby (%s)" % str(d.take))
	var stay := kids.duplicate(true)
	stay[1].mode = "stay"
	d = Father.decide({"hour": 12.0, "children": stay})
	_expect(not d.take.has("b") and d.take.has("a"), "a child told to stay is not taken")
	var along := kids.duplicate(true)
	along[0].with = "father"
	d = Father.decide({"hour": 19.0, "children": along})
	_expect(d.act == "home" and d.role == "protector" and d.sc_role == "home" and d.take.is_empty() and d.release.has("a"), "evenings he is home and gives the children back to their mother")
	d = Father.decide({"hour": 23.0, "children": kids})
	_expect(d.act == "rest" and d.sc_role == "home", "at night he rests at home")
	d = Father.decide({"hour": 2.0, "children": kids})
	_expect(d.act == "rest", "the block that wraps midnight holds (2 o'clock)")
	d = Father.decide({"hour": 12.0, "danger": true, "children": kids})
	_expect(d.act == "gather" and d.keep_together and d.sc_role == "home" and d.take.has("a") and d.take.has("b"), "in danger he keeps the family together at home")
	d = Father.decide({"hour": 12.0, "children": kids, "baby": {"present": true, "holder": "player"}, "mother_busy": true})
	_expect(bool(d.carry_baby), "the mother busy with the baby in her arms: he carries it")
	d = Father.decide({"hour": 12.0, "children": kids, "baby": {"present": true, "holder": "spouse"}, "mother_busy": true})
	_expect(not bool(d.carry_baby), "he does not take a baby he already holds")
	d = Father.decide({"hour": 12.0, "children": kids, "baby": {"present": true, "holder": "player"}, "mother_busy": false})
	_expect(not bool(d.carry_baby), "the mother free: she keeps the baby")
	_expect(Father.block(6.0).id == "teach" and Father.block(9.4).id == "teach" and Father.block(9.5).id == "work" and Father.block(21.5).id == "rest", "the blocks meet at their edges")


# ---------------------------------------------------------------- looks
func _looks() -> void:
	var mo := SpouseCore.look_for(0.0, "english", 4)
	var fa := SpouseCore.look_for(1.0, "haudenosaunee", 5)
	var c := _child("toddler", 0.0, {"seed": 4242})
	var l1 := Growth.mix_look(c, mo, fa)
	var l2 := Growth.mix_look(c, mo, fa)
	_expect(l1.hash() == l2.hash() and float(l1.sex) == 0.0, "the same child, the same look")
	var lo := minf(float(mo.get("melanin", 0.3)), float(fa.get("melanin", 0.3)))
	var hi := maxf(float(mo.get("melanin", 0.3)), float(fa.get("melanin", 0.3)))
	_expect(float(l1.melanin) >= lo - 0.06 and float(l1.melanin) <= hi + 0.06, "the skin is between the parents' (%.2f in %.2f..%.2f)" % [l1.melanin, lo, hi])
	c["seed"] = 4243
	_expect(Growth.mix_look(c, mo, fa).hash() != l1.hash(), "another child, another face")
	_expect((l1.face as Dictionary).size() > 0 and String(l1.get("people", "")) in [String(mo.get("people", "")), String(fa.get("people", ""))], "the face comes from the two parents through the face engine (%d features, %s)" % [(l1.face as Dictionary).size(), l1.get("people", "")])
	_expect(float(l1.stubble) == 0.0 and float(l1.genital) == 0.0, "a girl's inherited look has no stubble and no genital shape")
	# the body drawn at each stage: flat and asexual until the teen, then only a modest change, the adult's own at adulthood
	mo["bust"] = 0.5
	var girl := _child("toddler", 0.0, {"seed": 4242, "look": Growth.mix_look(c, mo, fa)})
	var neutral := ChildLook.body_for_stage(girl.look, "child")
	for st in ["toddler", "child"]:
		girl["stage"] = st
		var bl := Growth.body_look(girl, 1.0)
		_expect(Growth.shape_of(girl, 1.0) == "neutral" and float(bl.bust) == -1.0 and float(bl.genital) == 0.0 and float(bl.sex) == float(neutral.sex) and float(bl.get("body_hair", 0.0)) == 0.0, "a %s has the flat asexual child body (bust %.1f, sex fit %.2f)" % [st, bl.bust, bl.sex])
	girl["stage"] = "teen"
	girl["stage_at"] = 0.0
	_expect(Growth.shape_of(girl, 10.0 * 1440.0) == "neutral" and float(Growth.body_look(girl, 10.0 * 1440.0).bust) == -1.0, "a new teen keeps the child body for a while")
	var tb := Growth.body_look(girl, 60.0 * 1440.0)
	var adult_look: Dictionary = girl.look
	_expect(Growth.shape_of(girl, 60.0 * 1440.0) == "teen" and float(tb.bust) <= 0.05 and float(tb.genital) == 0.0 and float(tb.sex) > float(neutral.sex) - 0.0001 or float(tb.sex) < float(neutral.sex) + 1.0, "then only a modest teen change (bust %.2f of the adult's %.2f, sex fit %.2f)" % [tb.bust, adult_look.bust, tb.sex])
	_expect(float(tb.bust) < float(adult_look.bust) and float(tb.get("body_hair", 0.0)) == 0.0 and float(tb.stubble) == 0.0, "well short of the adult body, no body hair")
	girl["stage"] = "adult"
	_expect(Growth.shape_of(girl, 1.0) == "adult" and float(Growth.body_look(girl, 1.0).bust) == float(adult_look.bust), "an adult has the look's own body (the inherited bust %.2f)" % adult_look.bust)
	var boy := Growth.mix_look(_child("toddler", 0.0, {"seed": 9, "sex": 1.0}), mo, fa)
	_expect(float(boy.bust) == 0.0 and float(boy.stubble) > 0.0, "a boy's adult look: no bust, some stubble")
	var validated := AppearanceStore.validate(l1)
	_expect(validated.has("hair") and validated.has("outfit"), "and it validates for dressing")


# ---------------------------------------------------------------- a whole childhood through the household node
class FakeBridge extends SurvivalBridge:
	pass


## The household store without chests: a dictionary.
class TestStock extends ChestStock:
	var goods := {}

	func count(kind: String) -> int:
		return int(goods.get(kind, 0))

	func all() -> Dictionary:
		return goods.duplicate()

	func take(kind: String, n: int) -> int:
		var got := mini(n, int(goods.get(kind, 0)))
		goods[kind] = int(goods.get(kind, 0)) - got
		return got

	func put(kind: String, n: int) -> int:
		goods[kind] = int(goods.get(kind, 0)) + n
		return n


func _lifecycle() -> void:
	var m := _main(41)
	var h := Household.new()
	h.name = "Household"
	var br := FakeBridge.new()
	br.core = m
	h.bridge = br
	root.add_child(br)
	root.add_child(h)
	await process_frame
	h.stock = TestStock.new()
	var w := SpouseCore.create(m, male, 9)
	w.role = "home"
	w.worker_id = 0
	w.join(h.stock)
	h.sc = w
	h.stock.home = Vector3.ZERO
	h.stock.put("johnnycake", 3000)
	h.stock.put("jerky", 3000)
	var g := h.growth
	_expect(g != null and g.house == h, "the household has its growth link")
	var now := m.state.minutes
	var child := Pregnancy.make_child(RandomNumberGenerator.new(), now, {"next_id": 1, "mother": w.name, "father": "player", "kind": "spouse"})
	h.family.append(child)
	g.tick(0.0)
	_expect(Growth.stage_of(child) == "newborn" and child.has("topics") and child.has("stage_at"), "a birth becomes a newborn with a growth record")
	var log := {}
	var hours := 0
	var lessons_given := 0
	var watch_left := 0
	var t_end := 0
	for hour in 24 * 420:
		m.state.needs["stomach"] = 2000.0   # the player (a fake) is kept alive: only the family is under test
		m.state.needs["health"] = 100.0
		m.advance(60.0)
		w.sync(m)
		g.tick(60.0)
		hours += 1
		var st := Growth.stage_of(child)
		if not log.has(st):
			log[st] = (hour + 1) / 24
		# a real parent teaches when a lesson is due, at most twice a day
		if hour % 24 == 9 and Growth.has_body(child) and Growth.stage_of(child) != "adult":
			var topic := Teaching.due(child, w.core, m.state.minutes)
			if topic != "":
				var d := {"child": String(child.id), "topic": topic}
				g.lesson_done(w, d)
				lessons_given += 1
		if hour % 24 == 10 and Growth.can(child, "watch") and int(child.worker_id) < 0 and watch_left < 3 and int(child.watched) < 2:
			Teaching.give_watch(child, "fire", w.core, w.name, g.core_of(child))
		if st == "adult":
			t_end = (hour + 1) / 24
			break
	_expect(log.has("infant") and log.has("toddler") and log.has("child") and log.has("teen") and log.has("adult"), "the child went through every stage (%s)" % str(log))
	_expect(int(log.get("infant", 0)) >= 8 and int(log.get("toddler", 0)) >= 30 and int(log.get("child", 0)) >= 70 and int(log.get("teen", 0)) >= 160 and int(log.get("adult", 0)) >= 290, "and never before the days allowed (%s)" % str(log))
	_expect(lessons_given >= 9 and Teaching.learned(child, "fire") and Growth.core_progress(child).x == Growth.core_progress(child).y, "with the lessons taken it learnt the core (%d lessons)" % lessons_given)
	_expect(int(child.worker_id) >= 0, "the teen was taken on as a worker (id %d) and is one at adulthood" % int(child.worker_id))
	var wk := h.crew().by_id(int(child.worker_id))
	_expect(wk != null and wk.name == String(child.name) and h.crew().size() == 2, "the household has a second worker: %s" % (wk.name if wk else "-"))
	_expect(wk != null and bool(wk.enabled.get("cook", false)) and bool(wk.enabled.get("butcher", false)), "an adult has every job (the cap and the junior set are gone)")
	_expect(wk != null and SurvivalSkills.level(wk.core, "survival") > 4.0, "and what she learnt (survival %.1f)" % (SurvivalSkills.level(wk.core, "survival") if wk else 0.0))
	_expect(g.last_lines.any(func(l: String) -> bool: return l.contains("has grown up")), "the adult announcement was made (%s)" % str(g.last_lines.filter(func(l: String) -> bool: return l.contains("grown"))))
	_expect(t_end > 250, "it took a childhood: %d game days" % t_end)
	# the family rows, and the record saved and loaded through the household
	var rows := g.rows()
	_expect(rows.size() == 1 and String(rows[0].stage) == "adult" and bool(rows[0].worker), "the family tab row says grown up, working")
	var saved := h.save_data()
	_expect((saved.family as Array).size() == 1 and (saved.family[0] as Dictionary).has("core") and String(saved.family[0].stage) == "adult", "the household saves the stage and the learning core")
	var fam2 := Pregnancy.family_from(JSON.parse_string(JSON.stringify(saved.family)))
	_expect(String((fam2[0] as Dictionary).stage) == "adult" and (fam2[0] as Dictionary).has("topics"), "and it loads back")
	# the toddler row: hint and who it is with
	var kid2 := Pregnancy.make_child(RandomNumberGenerator.new(), m.state.minutes, {"next_id": 2, "mother": w.name, "father": "player", "kind": "spouse"})
	Growth.to_stage(Growth.normalize(kid2, m.state.minutes), "toddler", m.state.minutes)
	h.family.append(kid2)
	g.tick(0.0)
	var row: Dictionary = g.rows()[1]
	_expect(String(row.stage) == "toddler" and String(row.hint).begins_with("Towards child") and String(row["with"]).begins_with("with "), "a toddler's row shows the milestone hint (%s) and who it is with (%s)" % [row.hint, row["with"]])
	# commands: follow me, stay
	g.follow_me(String(kid2.id))
	_expect(String(kid2.with) == "father" and String(kid2.mode) == "follow", "'follow me' puts the child with the player (the father here)")
	g.stay(String(kid2.id))
	_expect(String(kid2.mode) == "stay", "'stay' keeps it put")
	var acts := g.actions_for(kid2)
	_expect(acts[0].id == "follow" and acts.any(func(a: Dictionary) -> bool: return a.id == "teach") and acts.any(func(a: Dictionary) -> bool: return a.id == "family"), "E on it offers take along, teach, household")
	# a lesson asked of the NPC parent, and the player's own lesson
	var older := Pregnancy.make_child(RandomNumberGenerator.new(), m.state.minutes, {"next_id": 3, "mother": w.name, "father": "player", "kind": "spouse"})
	Growth.to_stage(Growth.normalize(older, m.state.minutes), "child", m.state.minutes)
	older["mode"] = "follow"
	h.family.append(older)
	var line := g.ask_teach(String(older.id), "fire")
	_expect(line.contains("will teach") and g.lesson_request.has(0) and w.focus == "teach", "asking her to teach a hearth topic sets the teach job first (%s)" % line)
	var bad := g.ask_teach(String(older.id), "trapping")
	_expect(bad.contains("too young") or bad.contains("not") or bad != "", "an unfit topic is refused in words (%s)" % bad)
	var src := g.lesson_source(w)
	_skip_to_hour(m, w, 10.0)
	src = g.lesson_source(w)
	_expect(String(src.get("topic", "")) == "fire" and String(src.child) == String(older.id), "the teach job's source hands her the asked lesson (%s)" % str(src))
	var pl := g.teach(String(older.id), "foraging")
	_expect(pl.begins_with("You sit with") and not g.session.is_empty(), "the player's own lesson begins (%s)" % pl)
	g.tick(30.0)
	_expect(not g.session.is_empty(), "it takes the minutes (not done in 30 of %d)" % roundi(Teaching.minutes("foraging")))
	g.tick(30.0)
	_expect(g.session.is_empty() and Teaching.learned(older, "foraging"), "and the lesson is given at the end")
	# a field lesson: the parent's real job ends with the child near: the lesson is given, and she goes back to her role
	w.role = "outside"
	w.cancel("test")
	g.pending_field[w.worker_id] = {"child": String(older.id), "topic": "firewood", "job": "firewood", "role_before": "home", "at": m.state.minutes}
	g._on_task_finished(w, "forage")   # another job's end changes nothing
	_expect(g.pending_field.has(w.worker_id) and not Teaching.learned(older, "firewood"), "the end of a different job is not the lesson")
	g._on_task_finished(w, "firewood")
	_expect(Teaching.learned(older, "firewood") and g.pending_field.is_empty() and w.role == "home", "the parent's job ends: the field lesson is given, she goes back to keeping house")
	# a field lesson that never got its job started is given up, and the hearth teaches the topic
	var lost := Pregnancy.make_child(RandomNumberGenerator.new(), m.state.minutes, {"next_id": 4, "mother": w.name, "father": "player", "kind": "spouse"})
	Growth.to_stage(Growth.normalize(lost, m.state.minutes), "child", m.state.minutes)
	lost["topics"] = {"fire": 1, "cooking": 1, "shelter": 1}
	h.family = [lost]
	w.role = "outside"
	w.cancel("test")
	g.pending_field[w.worker_id] = {"child": String(lost.id), "topic": "foraging", "job": "forage", "role_before": "home", "at": m.state.minutes - GrowthLink.FIELD_START_MIN - 5.0}
	g.tick(1.0)
	_expect(g.pending_field.is_empty() and g._field_failed.has("foraging") and w.role == "home", "a field lesson whose job never began is given up (she is back home)")
	_skip_to_hour(m, w, 10.0)
	var fb := g.lesson_source(w)
	_expect(String(fb.get("topic", "")) == "foraging" and String(fb.child) == String(lost.id), "and the teach job gives that topic at the hearth meanwhile (%s)" % str(fb.get("topic", "")))
	h.family = [older, kid2, child]
	# the father NPC's schedule through the node: a husband
	var hh := SpouseCore.create(m, CharacterPeoples.preset_look("english_f_a") if not CharacterPeoples.preset("english_f_a").is_empty() else {"sex": 0.0}, 12)
	_expect(hh.is_male(), "a woman player has a husband")
	h.sc = hh
	hh.join(h.stock)
	hh.worker_id = 0
	hh.role = "home"
	older["kind"] = "player"
	_skip_to_hour(m, hh, 12.0)
	g.tick(1.0)
	_expect(String(g.last_father.get("act", "")) == "work" and hh.role == "outside" and String(older.with) == "father", "at noon the husband goes out to work and takes the child (%s, role %s)" % [g.last_father.get("act", ""), hh.role])
	_skip_to_hour(m, hh, 19.0)
	hh.cancel("test")
	g.tick(1.0)
	_expect(String(g.last_father.get("act", "")) == "home" and hh.role == "home" and String(older.with) == "mother", "in the evening he is home and the child is back with its mother")
	hh.role = "follow"
	_skip_to_hour(m, hh, 12.0)
	g.tick(1.0)
	_expect(hh.role == "follow", "the player's own order to him stands through the block")
	h.queue_free()
	br.queue_free()
